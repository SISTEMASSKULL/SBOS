# SBOS-0XX — Consistencia de Grants, WORM y Propagación de Revocación en bAuth IAM

**Estado:** Propuesto
**Dominio:** bAuth · IAM · PolicySet→Policy→Rule→Atom
**Tablas afectadas:** `bauth.privilege_atom_grant`, `bauth.idn_roles_template`, `bauth.privilege_atom_audit` (nueva)
**Autor:** Ivan (SKULL) · Documentado con asistencia de Claude
**Relacionado con:** BAUTH-AUTHENTICATION-FRAMEWORK.md, arquitectura Context Plane, especificación AtomLang

---

## 1. Problema original (el gap que dispara este documento)

Cuando un admin modifica una asignación de privilegio (INSERT/UPDATE en `privilege_atom_grant`), el sistema necesita garantizar **tres efectos simultáneos**:

1. Escribir la entrada correspondiente en el hash-chain WORM (evidencia forense, ISO 27001 A.8.15).
2. Invalidar el RolBitMask cacheado en Redis para todos los usuarios afectados por el cambio.
3. Emitir un evento CAEP `token_claims_change` hacia Kong, para que los JWTs activos dejen de considerarse válidos con los claims viejos.

**El síntoma:** un developer (o un script, una migración, un hotfix) que haga solo el `INSERT`/`UPDATE` en base de datos, sin pasar por el código de aplicación que "recuerda" disparar los otros dos efectos, deja JWTs activos circulando con permisos desactualizados. La revocación de un permiso no se propaga.

**El diagnóstico de fondo:** delegar una invariante de sistema (síncrona en su parte crítica, eventual en el resto) a disciplina de código de aplicación es una garantía que se rompe la primera vez que alguien toca la tabla por un camino no previsto. La solución correcta mueve la garantía a un nivel donde no se pueda evitar: la base de datos (para la parte transaccional) y el WAL (para la parte de propagación externa).

Durante el diseño de esta solución surgieron **tres gaps adicionales**, no vistos originalmente, que se descubrieron al inspeccionar el DDL real de las tablas involucradas. Este documento cubre los cuatro gaps y sus soluciones, en el orden en que se descubrieron.

---

## 2. Gap 1 — WORM embebido en una tabla mutable

### 2.1 Estado original

```sql
CREATE TABLE bauth.privilege_atom_grant (
    id             UUID PRIMARY KEY,
    id_atom        UUID NOT NULL,
    atom_position  INT  NOT NULL,
    bitmask_value  BIGINT NOT NULL,
    user_id        UUID,
    access         BOOLEAN NOT NULL,
    status         TEXT NOT NULL,       -- ACTIVE / DELETED / INACTIVE / SUSPENDED
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    hash_chain     BYTEA                -- WORM embebido
);
```

La columna `hash_chain` vivía en la misma fila que se actualiza cuando cambia `status`. Esto es contradictorio: WORM significa *write-once*, pero la tabla permite `UPDATE`.

### 2.2 Por qué es un problema real, no cosmético

Con el hash embebido, cualquiera de las dos alternativas falla:

- **No recalcular el hash en el UPDATE** → la columna representa el estado de creación, no el estado actual. Deja de ser evidencia de integridad de "lo que hay ahora".
- **Recalcularlo en cada UPDATE** → se rompe la cadena, porque el hash anterior fue calculado sobre un `NEW` que ya no existe. Se pierde la prueba forense del estado previo — justo lo que un auditor pide: *"¿qué decía antes del cambio?"*.

Además, un proceso con permiso de `UPDATE` sobre la tabla operacional tiene, por construcción, permiso de alterar su propia evidencia de auditoría. Esto viola directamente:

- **ISO 27001 A.8.15** — espera que los logs de auditoría estén protegidos contra alteración, incluso por quienes tienen acceso a los datos operacionales.
- **NIST SP 800-53, AU-9** — exige separación de privilegios entre el subsistema de auditoría y el subsistema operacional.
- **ETSI/eIDAS** (ya usado en bSign) — exige *non-repudiation* con evidencia que sobreviva independientemente del sistema que la generó.

### 2.3 Solución adoptada

Separar el WORM en una tabla propia, append-only real, con privilegios de escritura revocados al rol de aplicación:

```sql
CREATE TABLE bauth.privilege_atom_audit (
    id           UUID PRIMARY KEY,
    grant_id     UUID NOT NULL REFERENCES bauth.privilege_atom_grant(id),
    operation    TEXT NOT NULL,             -- INSERT / UPDATE
    before_row   JSONB,                     -- NULL si es INSERT
    after_row    JSONB NOT NULL,
    prev_hash    BYTEA,
    hash_chain   BYTEA NOT NULL,            -- sha256(prev_hash || after_row || created_at)
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

REVOKE UPDATE, DELETE ON bauth.privilege_atom_audit FROM bauth_app_role;
```

Poblada por trigger `AFTER INSERT OR UPDATE` sobre `privilege_atom_grant`, en la misma transacción que el write original (garantía transaccional real, no eventual):

```sql
CREATE OR REPLACE FUNCTION bauth.fn_worm_append() RETURNS trigger AS $$
DECLARE
    v_prev_hash BYTEA;
BEGIN
    -- Serializa el acceso a la cadena para evitar bifurcación entre transacciones concurrentes
    PERFORM pg_advisory_xact_lock(hashtext('privilege_atom_audit_chain'));

    SELECT hash_chain INTO v_prev_hash
    FROM bauth.privilege_atom_audit
    ORDER BY created_at DESC
    LIMIT 1;

    INSERT INTO bauth.privilege_atom_audit (id, grant_id, operation, before_row, after_row, prev_hash, hash_chain, created_at)
    VALUES (
        gen_random_uuid(),
        NEW.id,
        TG_OP,
        CASE WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD) ELSE NULL END,
        to_jsonb(NEW),
        v_prev_hash,
        digest(coalesce(v_prev_hash, ''::bytea) || to_jsonb(NEW)::text::bytea, 'sha256'),
        now()
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_t170_worm
AFTER INSERT OR UPDATE ON bauth.privilege_atom_grant
FOR EACH ROW EXECUTE FUNCTION bauth.fn_worm_append();
```

El `pg_advisory_xact_lock` serializa el cálculo de `prev_hash` entre transacciones concurrentes — sin esto, dos INSERT/UPDATE simultáneos podrían leer el mismo `prev_hash` y bifurcar la cadena, invalidando toda la evidencia forense posterior.

**Efecto de esta decisión:** es físicamente imposible que exista un cambio en `privilege_atom_grant` sin su entrada correspondiente en el hash-chain, sin importar si el write vino del servicio de aplicación, de un `psql` manual, de una migración, o de un hotfix a las 2am. El gap del WORM queda cerrado de forma absoluta (transaccional), no eventual.

---

## 3. Gap 2 — `atom_position` con `UNIQUE` global rompía con el segundo usuario

### 3.1 Estado original

```sql
ALTER TABLE bauth.privilege_atom_grant
    ADD CONSTRAINT uq_atom_position UNIQUE (atom_position);
```

### 3.2 Por qué es un bug, no una preferencia de diseño

Se estableció (R-1) que `id_atom` identifica al átomo y `atom_position` es la posición de bit — fija, inmutable, nunca reciclada. Bajo ese modelo, la misma `atom_position` se repite necesariamente en **todas** las filas donde ese átomo se le otorga a distintos usuarios: el átomo "leer_factura" tiene `atom_position = 42` fijo, y aparece 500 veces si se le otorga a 500 usuarios.

El `UNIQUE(atom_position)` global rompe en el segundo usuario que reciba cualquier átomo — no es un edge case, es el caso normal de operación.

### 3.3 Intento intermedio descartado: `UNIQUE(user_id, id_atom, atom_position)`

Se evaluó agregar `atom_position` a una clave compuesta con `user_id` e `id_atom`. Se descartó por dos razones:

1. **Redundante:** `atom_position` es dependiente funcional de `id_atom` (un átomo siempre tiene la misma posición). Si dos filas ya coinciden en `(user_id, id_atom)`, van a coincidir también en `atom_position` — el tercer campo no filtra ningún caso adicional.
2. **Peligroso:** si por un bug `atom_position` llegara a estar desincronizado del `id_atom` real (catálogo corrupto, race condition), esta clave compuesta **no lo detecta** — lo deja pasar como si fuera una fila legítima distinta. Con `UNIQUE(user_id, id_atom)` solo, ese mismo escenario sí es detectado (INSERT falla, error visible, se corrige en el momento).

### 3.4 Solución adoptada

Separar dos garantías distintas que no deben vivir en el mismo constraint:

- **No duplicar la asignación** → clave única de negocio en `privilege_atom_grant`, sin `atom_position`.
- **Garantizar que la posición corresponda al átomo real** → FK compuesta contra la fuente de verdad del catálogo (ver Gap 3).

```sql
ALTER TABLE bauth.privilege_atom_grant
    DROP CONSTRAINT uq_atom_position;

CREATE UNIQUE INDEX uq_pag_user_grant
    ON bauth.privilege_atom_grant (id_atom, user_id)
    WHERE user_id IS NOT NULL AND status = 'ACTIVE';

CREATE UNIQUE INDEX uq_pag_general_grant
    ON bauth.privilege_atom_grant (id_atom)
    WHERE user_id IS NULL AND status = 'ACTIVE';
```

---

## 4. Gap 3 — no existía una fuente de verdad para `id_atom → atom_position`

### 4.1 Estado original

`atom_position` nacía dentro de la misma `privilege_atom_grant`, en el momento del primer grant de cada átomo — sin ninguna tabla catálogo que fijara la relación de antemano.

### 4.2 Por qué esto es una falla estructural

Sin una tabla que sea la única fuente de verdad, la única forma de saber "qué posición le corresponde al átomo A" es buscar entre las filas ya existentes de `privilege_atom_grant`. Esto expone dos fallas:

1. **Race condition en el nacimiento del átomo.** Bajo el nivel de aislamiento por defecto de Postgres (READ COMMITTED), dos transacciones concurrentes que intenten otorgar el mismo átomo nuevo a dos usuarios distintos no se ven entre sí hasta el COMMIT. Ambas pueden calcular la misma "próxima posición libre" y terminar insertando el mismo átomo con dos `atom_position` distintos:
   ```
   id_atom=A, atom_position=42, user_id=X   -- primera asignación
   id_atom=A, atom_position=43, user_id=Y   -- debería ser 42, colisión de cálculo
   ```
2. **No hay forma declarativa de expresar la invariante.** Postgres no permite un `CHECK` que mire otras filas, ni un `UNIQUE` que permita repetición condicionada a "siempre el mismo valor". La única forma correcta es fijar la relación una vez, en un lugar único, con un mecanismo atómico (`SEQUENCE`).

Se evaluó también si el nacimiento del átomo ocurre de forma asíncrona (vía cola/worker) respecto al grant. Se confirmó que **no existe tal cola** — el flujo se está diseñando desde cero — por lo que no aplica el escenario de sincronización diferida ni el manejo de FK-violation-por-orden-de-llegada que ese escenario hubiera requerido.

Se investigó además dónde vive realmente el catálogo de átomos. La tabla `bos_atom_catalog` mencionada en discusiones previas **no existe**; el catálogo real de la jerarquía completa (dominios, bloques, políticas, reglas, átomos) es `bauth.idn_roles_template`, un árbol EAV genérico donde el átomo corresponde a los nodos con `tipo = 'evaluacion'`.

Se confirmó también que **no hay archivo externo (`rol_template_datos.dart`) actuando como fuente de verdad compitiendo con la base de datos** — el comentario original de la tabla que sugería esto describe una arquitectura que aún no se ha implementado. Se establece explícitamente, como parte de esta decisión, que la base de datos es la única fuente canónica.

### 4.3 Solución adoptada

Agregar `atom_position` como columna propia de `idn_roles_template`, restringida a los nodos átomo, con unicidad real y una secuencia atómica de asignación:

```sql
-- Columna nueva, restringida a átomos
ALTER TABLE bauth.idn_roles_template
    ADD COLUMN atom_position INT NULL;

ALTER TABLE bauth.idn_roles_template
    ADD CONSTRAINT chk_irt_atom_position_solo_evaluacion
    CHECK (
        (tipo = 'evaluacion' AND atom_position IS NOT NULL)
        OR
        (tipo != 'evaluacion' AND atom_position IS NULL)
    );

CREATE UNIQUE INDEX uq_irt_atom_position
    ON bauth.idn_roles_template (atom_position)
    WHERE tipo = 'evaluacion';

-- Secuencia — mecanismo atómico de asignación, sin colisión bajo concurrencia
CREATE SEQUENCE bauth.atom_position_seq;
```

El `CHECK` compuesto evita que un nodo `dominio`, `bloque` o `politica` reciba accidentalmente una posición de bit — lo que crearía un bit "fantasma" ocupando espacio en el RolBitMask sin ser un átomo evaluable real.

**Nacimiento de un átomo** (evento único, atómico, vía `SEQUENCE`):

```sql
INSERT INTO bauth.idn_roles_template
    (id, parent_id, clave, tipo, valor, atom_position, created_by, ctx_id)
VALUES
    (uuidv7(), $parent, $clave, 'evaluacion', $valor,
     nextval('bauth.atom_position_seq'), $user, $ctx);
```

**Otorgamiento a un usuario** (N veces, siempre leyendo la posición ya fijada, nunca recalculándola):

```sql
INSERT INTO bauth.privilege_atom_grant (id, id_atom, atom_position, bitmask_value, user_id, access, status)
SELECT gen_random_uuid(), r.id, r.atom_position, $bitmask, $user_id, $access, 'ACTIVE'
FROM bauth.idn_roles_template r
WHERE r.id = $id_atom AND r.tipo = 'evaluacion';
```

**FK compuesta que blinda la consistencia** entre el grant y el catálogo:

```sql
ALTER TABLE bauth.privilege_atom_grant
    ADD CONSTRAINT fk_pag_position
    FOREIGN KEY (id_atom, atom_position)
    REFERENCES bauth.idn_roles_template (id, atom_position);
```

Con esta FK, cualquier INSERT/UPDATE en `privilege_atom_grant` que traiga una combinación `(id_atom, atom_position)` inconsistente con el catálogo se rechaza automáticamente por Postgres — la garantía de integridad ya no depende de que la aplicación "recuerde" consultar la posición correcta.

### 4.4 Actualización de documentación del schema

Se actualiza el comentario de la tabla para reflejar la arquitectura real decidida:

```sql
COMMENT ON TABLE bauth.idn_roles_template IS
    'Árbol de configuración del sistema bAuth. Cada fila es un nodo del árbol '
    '(dominio D0-D13 + D98 + D99, bloques, políticas, reglas, átomos tipo evaluacion). '
    'FUENTE CANÓNICA en esta tabla — atom_position se asigna aquí vía SEQUENCE, '
    'nunca recalculado externamente. Cualquier export (ej. hacia Flutter) es de '
    'solo lectura, nunca la fuente de sincronización. '
    'READONLY para B9 y B14 (calculados por PrivilegeEngine).';
```

---

## 5. Gap 4 — propagación de Redis y CAEP sin depender de la aplicación

### 5.1 Por qué WORM, Redis y CAEP no deben tratarse igual

Los tres efectos requeridos por el problema original no tienen la misma naturaleza:

| Efecto | Naturaleza | Requisito de consistencia |
|---|---|---|
| WORM hash-chain | Interno a Postgres | Atomicidad transaccional (todo o nada junto con el write) |
| Invalidación Redis | I/O externo | At-least-once + idempotencia |
| Evento CAEP → Kong | I/O externo | At-least-once + idempotencia |

Tratar los tres como si requirieran lo mismo ("todo dentro de la transacción de aplicación") es la causa raíz del gap original.

### 5.2 Solución adoptada

**WORM** ya queda resuelto de forma síncrona y transaccional por el trigger del Gap 1 (Sección 2.3).

**Redis + CAEP** se resuelven mediante logical decoding del WAL, no mediante llamadas HTTP/Redis embebidas en un trigger de Postgres (frágil: un timeout de Redis colgaría el INSERT del admin).

Requisito de la tabla:

```sql
ALTER TABLE bauth.privilege_atom_grant REPLICA IDENTITY FULL;
```

Sin esto, el WAL de un `UPDATE` solo entrega la clave primaria del `OLD`, no el resto de columnas — y el daemon consumidor necesita el diff completo (`OLD.status` vs `NEW.status`) para decidir si el cambio amerita invalidación real.

**Flujo del daemon consumidor** (extensión de `bkernel`, o daemon nuevo tipo `bauth-reactor`), sobre un replication slot dedicado a `privilege_atom_grant`:

```
para cada evento del slot de replicación:
    if operation == INSERT or (operation == UPDATE and OLD.status != NEW.status):

        if NEW.user_id is not NULL:
            usuarios_afectados = [NEW.user_id]
        else:
            # grant general (átomo sin usuario específico) — resolver
            # vía jerarquía Subject↔Rol (dominio D98), no vía privilege_atom_grant
            usuarios_afectados = resolver_usuarios_por_id_atom(NEW.id_atom)

        for u in usuarios_afectados:
            redis.del(f"rolbitmask:{u}")
            emitir_caep_token_claims_change(u, kong_transmitter_endpoint)

        confirmar_lsn()   # solo avanza el slot si Redis y Kong tuvieron éxito;
                          # si falla, reintenta sin perder el evento
```

Garantías que este diseño provee:

- **No hay forma de evitarlo.** Cualquier INSERT/UPDATE en la tabla genera WAL, sin importar quién o qué lo haya escrito — la garantía deja de depender de que la aplicación llame a Redis/Kong explícitamente.
- **At-least-once con idempotencia.** El slot no avanza el LSN hasta confirmar éxito en Redis y Kong; ante fallo, reintenta sin perder el evento. La invalidación de Redis (`DEL`) y la emisión CAEP son naturalmente idempotentes.
- **Defensa en profundidad.** Aunque el evento CAEP tarde en propagarse, el TTL corto del JWT limita la ventana de exposición a permisos desactualizados.

### 5.3 Decisiones operativas pendientes de definir

1. **Idempotencia del consumidor:** deduplicar por LSN o por `(id, updated_at)` de `privilege_atom_grant`, para tolerar reintentos.
2. **Orden de procesamiento:** el WAL entrega orden por LSN; el consumidor debe procesar secuencialmente (o particionar de forma segura por usuario/Subject) para no invalidar Redis en un orden distinto al que reflejan los cambios reales.
3. **Comportamiento ante caída de Kong o Redis:** decidir entre bloquear el slot indefinidamente (garantía fuerte, riesgo de acumulación de WAL) o usar una dead-letter queue + alerta y avanzar igual (garantía débil, pero no compromete la replicación). Esta es una decisión de modelo de amenazas, no puramente técnica.

---

## 6. DDL consolidado final

```sql
-- ============================================================
-- 1. Catálogo de átomos: idn_roles_template
-- ============================================================
ALTER TABLE bauth.idn_roles_template
    ADD COLUMN atom_position INT NULL;

ALTER TABLE bauth.idn_roles_template
    ADD CONSTRAINT chk_irt_atom_position_solo_evaluacion
    CHECK (
        (tipo = 'evaluacion' AND atom_position IS NOT NULL)
        OR
        (tipo != 'evaluacion' AND atom_position IS NULL)
    );

CREATE UNIQUE INDEX uq_irt_atom_position
    ON bauth.idn_roles_template (atom_position)
    WHERE tipo = 'evaluacion';

CREATE SEQUENCE bauth.atom_position_seq;

COMMENT ON TABLE bauth.idn_roles_template IS
    'Árbol de configuración del sistema bAuth. Cada fila es un nodo del árbol '
    '(dominio D0-D13 + D98 + D99, bloques, políticas, reglas, átomos tipo evaluacion). '
    'FUENTE CANÓNICA en esta tabla — atom_position se asigna aquí vía SEQUENCE, '
    'nunca recalculado externamente. Cualquier export (ej. hacia Flutter) es de '
    'solo lectura, nunca la fuente de sincronización. '
    'READONLY para B9 y B14 (calculados por PrivilegeEngine).';

-- ============================================================
-- 2. Tabla operacional: privilege_atom_grant (T-170)
-- ============================================================
ALTER TABLE bauth.privilege_atom_grant
    DROP CONSTRAINT IF EXISTS uq_atom_position;

CREATE UNIQUE INDEX uq_pag_user_grant
    ON bauth.privilege_atom_grant (id_atom, user_id)
    WHERE user_id IS NOT NULL AND status = 'ACTIVE';

CREATE UNIQUE INDEX uq_pag_general_grant
    ON bauth.privilege_atom_grant (id_atom)
    WHERE user_id IS NULL AND status = 'ACTIVE';

ALTER TABLE bauth.privilege_atom_grant
    ADD CONSTRAINT fk_pag_position
    FOREIGN KEY (id_atom, atom_position)
    REFERENCES bauth.idn_roles_template (id, atom_position);

ALTER TABLE bauth.privilege_atom_grant REPLICA IDENTITY FULL;

-- ============================================================
-- 3. Tabla WORM: privilege_atom_audit (nueva, separada, append-only)
-- ============================================================
CREATE TABLE bauth.privilege_atom_audit (
    id           UUID PRIMARY KEY,
    grant_id     UUID NOT NULL REFERENCES bauth.privilege_atom_grant(id),
    operation    TEXT NOT NULL,
    before_row   JSONB,
    after_row    JSONB NOT NULL,
    prev_hash    BYTEA,
    hash_chain   BYTEA NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

REVOKE UPDATE, DELETE ON bauth.privilege_atom_audit FROM bauth_app_role;

CREATE OR REPLACE FUNCTION bauth.fn_worm_append() RETURNS trigger AS $$
DECLARE
    v_prev_hash BYTEA;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext('privilege_atom_audit_chain'));

    SELECT hash_chain INTO v_prev_hash
    FROM bauth.privilege_atom_audit
    ORDER BY created_at DESC
    LIMIT 1;

    INSERT INTO bauth.privilege_atom_audit (id, grant_id, operation, before_row, after_row, prev_hash, hash_chain, created_at)
    VALUES (
        gen_random_uuid(),
        NEW.id,
        TG_OP,
        CASE WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD) ELSE NULL END,
        to_jsonb(NEW),
        v_prev_hash,
        digest(coalesce(v_prev_hash, ''::bytea) || to_jsonb(NEW)::text::bytea, 'sha256'),
        now()
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_t170_worm
AFTER INSERT OR UPDATE ON bauth.privilege_atom_grant
FOR EACH ROW EXECUTE FUNCTION bauth.fn_worm_append();
```

---

## 7. Flujo operativo end-to-end (resumen)

```
1. NACE UN ÁTOMO (una vez)
   INSERT idn_roles_template (tipo='evaluacion', atom_position = nextval(seq))
   → posición fijada de forma atómica, única en todo el sistema

2. SE OTORGA A UN USUARIO (N veces, en cualquier momento posterior)
   INSERT privilege_atom_grant (id_atom, atom_position ← leído del catálogo, user_id, ...)
   → FK fk_pag_position rechaza cualquier posición inconsistente con el catálogo
   → TRIGGER trg_t170_worm escribe, en la misma transacción, la entrada WORM en privilege_atom_audit
   → COMMIT

3. PROPAGACIÓN ASÍNCRONA (garantizada por WAL, no por la aplicación)
   WAL logical decoding detecta el INSERT/UPDATE
   → daemon consumidor resuelve usuarios afectados
   → invalida RolBitMask en Redis
   → emite evento CAEP token_claims_change a Kong
   → confirma LSN solo si ambos pasos tuvieron éxito
```

## 8. Garantías resultantes

| Gap original | Mecanismo que lo cierra | Tipo de garantía |
|---|---|---|
| WORM podía omitirse o corromperse | Trigger transaccional + tabla separada con privilegios revocados | Transaccional, absoluta |
| `atom_position` colisionaba con >1 usuario por átomo | Constraints únicos parciales sobre `(id_atom, user_id)` | Declarativa, absoluta |
| Posición de bit podía asignarse de forma inconsistente bajo concurrencia | `SEQUENCE` en el nacimiento del átomo + `UNIQUE WHERE tipo='evaluacion'` | Atómica, absoluta |
| Grant podía referenciar una posición inválida o desincronizada | FK compuesta `(id_atom, atom_position)` contra el catálogo | Declarativa, absoluta |
| Redis/CAEP podían omitirse si el developer no los llamaba explícitamente | WAL logical decoding + daemon idempotente | Eventual, at-least-once |

## 9. Pendiente para el siguiente documento

- Diseño detallado de `resolver_usuarios_por_id_atom()` para el caso de grant general (`user_id IS NULL`), vía jerarquía Subject↔Rol de dominio D98.
- Definición del comportamiento del daemon ante caída prolongada de Kong o Redis (bloqueo del slot vs. dead-letter queue).
- Especificación formal del daemon `bauth-reactor` (o extensión de `bkernel`) como nuevo componente de la Fábrica SBOS.
