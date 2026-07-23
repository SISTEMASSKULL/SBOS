# A.65.02.01 — Operación de Tablas: Decisiones de Diseño DDL

**Versión:** 1.7.0  
**Fecha:** 2026-07-23  
**Estado:** DISEÑO APROBADO  
**Referencia:** A.65.02 § PRIVILEGIOS · Manual BitMask 1.04 v1.1.0 · A.67 Zona de Negocios  
**Estándares base:** XACML 3.0 · NIST SP 800-207 · ANSI INCITS 359-2004 · RFC 9068 · OpenID AuthZEN 1.0 · NGAC INCITS 565-2020 · SABSA SCF · ISO/IEC 27001:2022 A.5.15

---

## 1. Propósito

Este documento registra las decisiones arquitectónicas que determinan el diseño de las tablas de la sección PRIVILEGIOS de la nueva DDL (`A.65.02`). Cubre dos grupos de decisiones interrelacionadas:

1. **Motor BitMask** — cómo se estructuran los átomos, dónde vive la posición de bit, cómo resuelve Kong, qué necesita persistirse y qué no.
2. **Zona de Negocios y Aplicaciones** — por qué el árbol T-162 reemplaza tablas de definición de aplicaciones, cómo se llama el bloque canónico, qué estructura es válida dentro de él, qué sí necesita tablas y por qué.

Son decisiones no triviales que resultaron de analizar el motor BitMask Dual (`src/bitmask/`, manual `1.04`), la estructura del árbol RolTemplate (T-162), los requisitos de Kong como PEP enterprise, y la separación de dominios en el árbol de política.

Estas decisiones NO deben perderse: forman la doctrina de diseño de todo lo que interactúa con privilegios y aplicaciones en bAuth.

---

## 2. El átomo — identidad y estructura

### 2.1 El átomo no es un registro plano

Un átomo en bAuth NO es una cadena como `D01.tryton.sale.read`. Es un **nodo específico en el árbol RolTemplate (T-162)** con una posición jerárquica exacta de 5 niveles:

```
D01 · ACCESO LÓGICO              ← TipoNodo.dominio
  └── B6 · Zona de Negocios      ← TipoNodo.bloque
        └── zona_logical_tryton  ← TipoNodo.politica
              └── model          ← TipoNodo.bloque  (módulo funcional)
                    └── tryton.sale.read  ← TipoNodo.evaluacion  ← EL ÁTOMO
                          ├── verbo:      'read'
                          ├── propiedad:  'subject'
                          ├── operador:   'IN'
                          ├── valor:      'bauth.role/cajero'
                          └── effect:
                                ├── decision:    'Permit'
                                ├── obligation:  { required_loa: 'AAL2' }
                                └── advice:      'SSO bAuth → Tryton'
```

La **identidad completa del átomo** es ese nodo `tryton.sale.read` más su cadena de ancestros. El nodo tiene un **UUIDv7** asignado al nacer en T-162. Ese UUID es su identidad permanente.

### 2.2 El átomo como fachada multi-dominio

El átomo no es un permiso simple. Es una **fachada** que compacta decisiones de múltiples dominios. Cuando el PDP evalúa `tryton.sale.read`, considera:

- **D01** (lógico): ¿tiene acceso a Tryton?
- **D04** (temporal): ¿está dentro de la ventana horaria válida?
- **D06** (geoespacial): ¿está en la ubicación autorizada?
- **D08** (contexto): ¿el `ctx_id` es válido en Redis?
- **D09** (credenciales): ¿el LoA alcanzado es suficiente (AAL2)?

El resultado de esta evaluación multi-dominio se compacta en UN BIT del `RolBitMask`. Eso es lo que significa "fachada": el bit resume toda la decisión cruzada.

---

## 3. El motor BitMask Dual — dos estructuras distintas

**Regla más importante del sistema:** existen DOS estructuras con propósitos completamente diferentes. Confundirlas rompe la arquitectura.

### 3.1 AtomBitMask (u64) — etiqueta de identidad del átomo

```
 63                              32 31                               0
 ┌──────────────────────────────────┬──────────────────────────────────┐
 │  [8 device][4 domain][9 app][11g]│ [3 trust][2 bind][1 blk][2 pol][24 verb] │
 └──────────────────────────────────┴──────────────────────────────────┘
```

- Codifica la **identidad** del átomo: dominio + app + grupo + verbo + contexto de dispositivo
- Se almacena en `privilege_atom_grant.bitmask_value` (BIGINT)
- **NUNCA** se opera OR/AND/XOR entre dos AtomBitMask — el resultado no es ningún átomo válido
- Se usa para: identificación, comparación, lookup, auditoría

### 3.2 RolBitMask (BitVec N-bit one-hot) — permisos de un rol

```
pos 0 → D1.tryton.comprobantes.nuevo
pos 1 → D1.tryton.comprobantes.editar
pos 2 → D1.tryton.comprobantes.ver
pos 3 → D3.finanzas.pago.nuevo
...
pos N → último átomo registrado

RolBitMask "Cajero":    [1 1 1 0 ...]
                         ↑ ↑ ↑
                         nuevo, editar, ver — sin acceso financiero
```

- Vector de N bits donde N = total de átomos en el catálogo (~6000 en VPS)
- **SÍ** se opera OR (unión), AND (mínimo privilegio), AND NOT (revocación), XOR (delta)
- Se serializa como `rol_bitmask_base64` en el JWT y se cachea en Redis (TTL 30s)
- La verificación FastPath: `rol_bitmask[atom_position] == 1` → < 0.5 ns

### 3.3 atom_position — el índice de bit (no la identidad)

`atom_position` es el **índice** del átomo en el vector RolBitMask. Es un entero secuencial asignado una vez. No es una propiedad intrínseca del átomo — es su número de registro en el catálogo.

**Regla de oro (Manual 1.04 §13 regla 3):** las posiciones son INMUTABLES una vez asignadas. Si se reasignara una posición, todos los RolBitMasks en BD y Redis quedarían corrompidos.

---

## 4. Decisión central: dónde vive la atom_position

### 4.1 Corrección arquitectónica (SBOS-0XX)

La decisión inicial ubicaba `atom_position` en `privilege_atom_grant`. Esa decisión fue revertida por una falla estructural detectada al analizar la concurrencia:

**El problema con privilege_atom_grant como fuente de posición:** si dos transacciones concurrentes otorgan el mismo átomo nuevo a dos usuarios distintos, ambas calculan la "próxima posición libre" con `MAX(atom_position) + 1` bajo `READ COMMITTED`. Como no se ven entre sí hasta el COMMIT, ambas pueden calcular la misma posición y asignarla a dos filas distintas del mismo átomo. El catálogo queda corrupto — el mismo átomo aparece con dos posiciones distintas según a qué usuario se pregunte.

**La solución correcta:** `atom_position` vive en **`idn_roles_template` (T-162)**, como columna propia de los nodos `tipo = 'evaluacion'`, asignada una única vez al nacer el átomo mediante una secuencia PostgreSQL atómica.

### 4.2 La decisión vigente

**`atom_position` nace en T-162 junto con el nodo átomo. Nunca se recalcula.**

Cuando un átomo nace en T-162:
1. El nodo se crea con `tipo = 'evaluacion'` y su UUIDv7
2. `atom_position = nextval('bauth.roles_atom_position_sequential')` — atómico, sin posibilidad de colisión
3. Un `CHECK` compuesto garantiza que solo los nodos `evaluacion` tienen posición; cualquier otro tipo tiene NULL
4. Un índice `UNIQUE` parcial sobre `(atom_position) WHERE tipo = 'evaluacion'` es la fuente de verdad única

Cuando `privilege_atom_grant` necesita registrar el otorgamiento del átomo a un usuario:
- Lee `atom_position` de T-162 (nunca lo recalcula)
- Una FK compuesta `(id_atom, atom_position) → idn_roles_template(id, atom_position)` garantiza en BD que el grant nunca puede referenciar una posición inventada o desincronizada

Cuando un átomo es marcado inactivo en T-162 (`activo = false`):
- La fila en T-162 persiste — la `atom_position` sigue fijada en la secuencia
- Los grants existentes en `privilege_atom_grant` mantienen su `status`
- Los JWTs con ese bit activo se invalidan vía CAEP (§7)
- La posición **nunca se recicla** — la secuencia solo avanza

### 4.3 La secuencia

**Nombre canónico:** `bauth.roles_atom_position_sequential`  
**Traducción:** "roles atom position sequential" — secuencia global de posiciones de bit para el catálogo de átomos del sistema de roles.  
**Scope:** una sola secuencia para todos los átomos de todos los dominios D01-D13/D98/D99. No cíclica: la posición solo avanza, nunca se recicla.  
**DDL:** definido en §6.1 junto con el CREATE TABLE de `idn_roles_template`.

---

## 5. Tres categorías de átomos

### 5.1 Átomos generales

Átomos registrados en `privilege_atom_grant` sin `user_id` asignado. Pertenecen implícitamente a **todos los roles y todos los usuarios** del sistema. Son el piso universal de acceso.

**Fórmula:** `atomos_generales = privilege_atom_grant WHERE user_id IS NULL AND access = PERMIT AND status = ACTIVE`

### 5.2 Átomos seteados (asignados)

Átomos con `user_id` presente → asignados a un rol o usuario específico con decisión PERMIT o DENY.

**Fórmula de átomos efectivos para un rol:**
```
atomos_efectivos(rol) =
    (átomos generales)
    UNION
    (privilege_atom_grant WHERE user_id = rol AND access = PERMIT AND status = ACTIVE)
    MINUS
    (privilege_atom_grant WHERE user_id = rol AND access = DENY AND status = ACTIVE)
```

Lo mismo aplica para usuarios (herencia de roles + asignaciones directas de usuario).

### 5.3 Átomos UNSET (DENY explícito)

Átomos que existen en el sistema pero han sido explícitamente revocados para un rol/usuario. Fila en `privilege_atom_grant` con `access = DENY`.

Un DENY explícito tiene precedencia sobre los átomos generales — si un átomo general es DENY para un rol específico, ese rol no lo tiene.

---

## 6. Tablas DDL del grupo PRIVILEGIOS — definiciones CREATE

Las tablas de esta sección son nuevas (no migración de esquema existente). Se definen como `CREATE TABLE` completo sin `ALTER TABLE`. El orden de creación respeta las FK entre tablas.

### 6.1 idn_roles_template (T-162) — árbol de políticas + columna atom_position

T-162 es la tabla preexistente del árbol de políticas. Se incluye aquí su definición completa porque incorpora la columna `atom_position` que es la decisión arquitectónica central de esta sección.

```sql
CREATE TABLE bauth.idn_roles_template (
    id              uuid        NOT NULL DEFAULT gen_random_uuid(),
    -- tenant_id: el árbol es per-tenant (decisión G-06).
    -- Cada tenant tiene su propia instancia del árbol inicializada desde el tenant plantilla.
    -- El tenant plantilla (bootstrap) contiene toda la estructura general; cada empresa
    -- hereda esa estructura y agrega sus propias zonas de negocio y átomos.
    -- SU usa un UUID de tenant reservado del sistema — nunca NULL.
    -- La SEQUENCE roles_atom_position_sequential es GLOBAL: atom_position es único
    -- en todo el sistema, independientemente del tenant (el bit N identifica el mismo
    -- átomo sin ambigüedad en cualquier tenant).
    tenant_id       uuid        NOT NULL,
    parent_id       uuid        NULL REFERENCES bauth.idn_roles_template(id) ON DELETE CASCADE,
    clave           text        NOT NULL,
    tipo            text        NOT NULL,
    valor           text        NULL,
    help            text        NULL,
    opciones        text[]      NULL DEFAULT '{}',
    orden           integer     NOT NULL DEFAULT 0,
    -- atom_position: solo para nodos tipo='evaluacion'. Asignada UNA VEZ al nacer el nodo,
    -- vía nextval('bauth.roles_atom_position_sequential'). INMUTABLE una vez asignada.
    atom_position   integer     NULL,
    -- verb_id: solo para nodos tipo='evaluacion'. FK a privilege_verb — el verbo debe
    -- existir en el catálogo antes de poder usarse en el árbol. SOLO PARA VALIDACIÓN:
    -- no estructures átomos a partir de esta FK ni la consultes en runtime.
    verb_id         text        NULL REFERENCES bauth.privilege_verb(verb_id),
    activo          boolean     NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    created_by      text        NOT NULL,
    ctx_id          text        NOT NULL,
    CONSTRAINT idn_roles_template_pkey PRIMARY KEY (id),
    -- tipo solo acepta los 10 valores canónicos del árbol bAuth
    CONSTRAINT chk_irt_tipo CHECK (tipo IN (
        'dominio','bloque','objeto','lista','politica',
        'regla','evaluacion','atributo','enumerado','diagnostico'
    )),
    -- invariante: SOLO los nodos evaluacion tienen atom_position asignada
    CONSTRAINT chk_irt_atom_position_solo_evaluacion CHECK (
        (tipo = 'evaluacion' AND atom_position IS NOT NULL)
        OR (tipo <> 'evaluacion' AND atom_position IS NULL)
    ),
    -- invariante: SOLO los nodos evaluacion tienen verb_id asignado
    CONSTRAINT chk_irt_verb_solo_evaluacion CHECK (
        (tipo = 'evaluacion' AND verb_id IS NOT NULL)
        OR (tipo <> 'evaluacion' AND verb_id IS NULL)
    ),
    -- unicidad por tenant: dos tenants distintos pueden tener la misma clave
    -- en el mismo nivel sin colisión (cada uno tiene su propio árbol)
    CONSTRAINT uq_irt_clave_parent UNIQUE (tenant_id, parent_id, clave)
);

-- ─── REGLA DE BOOTSTRAP (G-06) ───────────────────────────────────────────────
-- Al inicializar un tenant nuevo desde el tenant plantilla se copian TODOS los
-- nodos EXCEPTO tipo='evaluacion'. Esto incluye la estructura de zonas de negocio
-- (bloque, objeto, lista, politica, regla) pero sin los átomos específicos.
-- Ejemplo: el nuevo tenant recibe zona_logical_tryton estructurada y vacía de átomos;
-- el administrador de la empresa define qué puede hacer cada rol dentro de esa zona.
-- Los nodos tipo='evaluacion' NO se copian: cada empresa define sus propios átomos.
-- Los parent_id se remapean a los UUIDs de la nueva copia del árbol.
-- ─────────────────────────────────────────────────────────────────────────────

-- Secuencia global — una única fuente de posiciones para todos los átomos del catálogo
CREATE SEQUENCE bauth.roles_atom_position_sequential
    START WITH 1
    INCREMENT BY 1
    NO CYCLE;

-- Índice parcial: la combinación (atom_position) debe ser única entre nodos evaluacion
-- Este es el índice que el Rust engine consulta para resolver id_atom → atom_position
CREATE UNIQUE INDEX uq_irt_atom_position
    ON bauth.idn_roles_template (atom_position)
    WHERE tipo = 'evaluacion';
```

### 6.2 privilege_atom_grant (T-170) — grants con FK compuesta a T-162

Propósito dual: (1) registrar que un átomo tiene grants activos (persistencia), (2) asignaciones rol/usuario PERMIT/DENY. `atom_position` se lee de T-162 vía FK — **nunca se calcula aquí**.

```sql
CREATE TABLE bauth.privilege_atom_grant (
    id             uuid        NOT NULL DEFAULT gen_random_uuid(),
    -- id_atom + atom_position forman FK compuesta a T-162
    -- Garantía: un grant nunca puede referenciar una posición inventada
    id_atom        uuid        NOT NULL,
    atom_position  integer     NOT NULL,
    bitmask_value  bigint      NOT NULL,    -- AtomBitMask(u64) pre-calculado — etiqueta de identidad
    -- tenant_id NOT NULL (G-06): árbol per-tenant. SU usa UUID reservado del sistema,
    -- no NULL. Garantiza aislamiento: un PERMIT del tenant ABC nunca afecta al tenant XYZ.
    tenant_id      uuid        NOT NULL,
    -- user_id NULL = grant tenant-wide (aplica a todos los usuarios del tenant para este átomo)
    -- user_id NOT NULL = grant para un usuario específico (caso más frecuente, ver G-09)
    user_id        uuid        NULL,
    access         boolean     NOT NULL,    -- true = PERMIT · false = DENY
    status         text        NOT NULL,    -- ACTIVE / DELETED / INACTIVE / SUSPENDED
    valid_from     timestamptz NULL,        -- acceso temporal JIT (NIST AC-2(6)) — NULL = sin límite inicio
    valid_until    timestamptz NULL,        -- acceso temporal JIT (NIST AC-2(6)) — NULL = sin límite fin
    created_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT privilege_atom_grant_pkey PRIMARY KEY (id),
    -- FK compuesta: atom_position debe venir de T-162 — el motor no inventa posiciones
    CONSTRAINT fk_pag_atom_position
        FOREIGN KEY (id_atom, atom_position)
        REFERENCES bauth.idn_roles_template (id, atom_position)
        DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT chk_pag_status
        CHECK (status IN ('ACTIVE','DELETED','INACTIVE','SUSPENDED')),
    -- valid_from y valid_until solo tienen sentido juntos o ambos NULL
    CONSTRAINT chk_pag_valid_range
        CHECK (valid_from IS NULL OR valid_until IS NULL OR valid_from < valid_until)
);

-- Índice para grants de usuario específico (lectura por (átomo, usuario))
CREATE UNIQUE INDEX uq_pag_user_grant
    ON bauth.privilege_atom_grant (id_atom, tenant_id, user_id)
    WHERE user_id IS NOT NULL AND status = 'ACTIVE';

-- Índice para átomos generales (user_id IS NULL — aplican a todos)
CREATE UNIQUE INDEX uq_pag_general_grant
    ON bauth.privilege_atom_grant (id_atom, tenant_id)
    WHERE user_id IS NULL AND status = 'ACTIVE';

-- ─── ÍNDICES IGA (G-09) ──────────────────────────────────────────────────────
-- Modelo per-user: cada fila es UN grant para UN usuario específico.
-- Los grants NO son a nivel de rol. Cuando AtomLang asigna un átomo a un SET de
-- usuarios, se insertan N filas — una por usuario. Cuando aplica UNSET a un
-- usuario individual, solo cambia el access/status de LA FILA de ese usuario,
-- sin tocar las filas del resto. Esta granularidad es la que habilita las
-- operaciones IGA sin efectos colaterales sobre otros usuarios.
-- ─────────────────────────────────────────────────────────────────────────────

-- IGA Dirección 1 — átomo → usuarios (what-if y access certification):
--   "¿quién tiene activo el átomo X?" · "dame la lista para firmar la certificación"
--   Cubierta por este índice. Cubre también what-if: "si revoco X, ¿a quién afecta?"
CREATE INDEX idx_pag_atom_access
    ON bauth.privilege_atom_grant (id_atom, access, status);

-- IGA Dirección 2 — usuario → sus átomos (offboarding / revisión de entitlements):
--   "María Flores terminó contrato — lista todos sus grants para revocarlos"
--   "¿qué accesos tiene activos Juan?" → revisión de acceso periódica NIST AC-2
--   atom_position incluida: el motor puede reconstruir el RolBitMask desde aquí
--   sin join adicional a T-162.
CREATE INDEX idx_pag_user_entitlement
    ON bauth.privilege_atom_grant (user_id, atom_position)
    WHERE user_id IS NOT NULL AND access = true AND status = 'ACTIVE';

-- IGA Dirección 3 — tenant → todos sus grants activos (campaña de certificación):
--   "Muéstrame todos los accesos activos de todos los empleados de la empresa ABC
--    para que los jefes de área revisen y firmen la recertificación trimestral"
--   user_id incluido: permite agrupar por usuario dentro del tenant para la UI
--   de certificación sin un segundo nivel de join.
CREATE INDEX idx_pag_tenant_sweep
    ON bauth.privilege_atom_grant (tenant_id, user_id)
    WHERE access = true AND status = 'ACTIVE';

-- IGA Dirección 4 — grants temporales próximos a vencer (NIST AC-2(6)):
--   "El consultor Carlos Méndez tiene acceso hasta el 31-jul. Alertar 7 días antes."
--   Índice parcial: excluye el ~95% de grants sin valid_until (accesos permanentes).
--   Job periódico de expiración: WHERE valid_until BETWEEN now() AND now() + '7 days'
--   Sin este índice el job hace seq-scan completo — grants temporales no revocados
--   a tiempo son exactamente la brecha que NIST AC-2(6) obliga a cerrar.
CREATE INDEX idx_pag_valid_until
    ON bauth.privilege_atom_grant (valid_until)
    WHERE valid_until IS NOT NULL AND status = 'ACTIVE';

-- REPLICA IDENTITY FULL: el daemon WAL (bauth-reactor) recibe la fila OLD completa en UPDATE.
-- Sin esto, el WAL solo propaga columnas PK — Redis no sabe qué posiciones invalidar.
ALTER TABLE bauth.privilege_atom_grant REPLICA IDENTITY FULL;
```

**Nota sobre tenant_id (G-06):** `NOT NULL` — el árbol es per-tenant y SU usa un UUID de tenant reservado del sistema. El aislamiento multi-tenant está garantizado: cada grant pertenece a exactamente un tenant y nunca cruza a otro. El tier SU accede a otros tenants por lógica de autorización, no por NULL en tenant_id.

**Nota sobre REPLICA IDENTITY FULL:** el `ALTER TABLE` que habilita REPLICA IDENTITY FULL es la única sentencia que no puede ser parte del `CREATE TABLE` — es un parámetro de WAL que PostgreSQL solo acepta como instrucción separada. Es necesario para que el daemon `bauth-reactor` reciba la fila `OLD` completa en eventos `UPDATE`, lo que le permite construir el diff de posiciones de bit a invalidar en Redis.

### 6.3 privilege_atom_audit (tabla WORM independiente — T-170b)

La cadena hash-chain vive en una tabla **separada e inmutable** de `privilege_atom_grant`. Esta separación es obligatoria: un campo `hash_chain` en una tabla con permisos UPDATE violaría ISO 27001 A.8.15 y NIST AU-9 (integridad del registro de auditoría).

```sql
-- Tabla append-only: nunca UPDATE, nunca DELETE
CREATE TABLE bauth.privilege_atom_audit (
    id           uuid        NOT NULL DEFAULT gen_random_uuid(),
    grant_id     uuid        NOT NULL REFERENCES bauth.privilege_atom_grant(id),
    operation    text        NOT NULL,   -- INSERT / UPDATE
    before_row   jsonb       NULL,       -- NULL en INSERT; snapshot del estado anterior en UPDATE
    after_row    jsonb       NOT NULL,   -- snapshot del estado posterior (TG_OP = NEW)
    prev_hash    bytea       NULL,       -- hash del registro anterior — NULL en el primer registro
    hash_chain   bytea       NOT NULL,   -- SHA-256(prev_hash || after_row::text)
    created_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT privilege_atom_audit_pkey PRIMARY KEY (id),
    CONSTRAINT chk_baa_operation CHECK (operation IN ('INSERT','UPDATE'))
);

-- Denegar UPDATE y DELETE al rol de aplicación — el trigger escribe, la app no puede borrar
REVOKE UPDATE, DELETE ON bauth.privilege_atom_audit FROM bauth_app_role;

-- Índice de verificación de cadena: lectura del último hash para calcular el siguiente
CREATE INDEX idx_baa_grant_created ON bauth.privilege_atom_audit (grant_id, created_at DESC);
```

#### Trigger WORM — función y activación

El trigger se dispara en `privilege_atom_grant` y escribe en `privilege_atom_audit`. El lock advisory serializa la escritura del hash-chain bajo concurrencia: dos transacciones simultáneas no pueden calcular el mismo `prev_hash`.

```sql
CREATE OR REPLACE FUNCTION bauth.fn_worm_append()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_prev_hash bytea;
BEGIN
    -- Serializar el cálculo de hash bajo concurrencia dentro de la misma transacción
    PERFORM pg_advisory_xact_lock(hashtext('privilege_atom_audit_chain'));

    SELECT hash_chain
    INTO v_prev_hash
    FROM bauth.privilege_atom_audit
    ORDER BY created_at DESC
    LIMIT 1;

    INSERT INTO bauth.privilege_atom_audit (
        id, grant_id, operation,
        before_row, after_row,
        prev_hash, hash_chain,
        created_at
    )
    VALUES (
        gen_random_uuid(),
        NEW.id,
        TG_OP,
        CASE WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD) ELSE NULL END,
        to_jsonb(NEW),
        v_prev_hash,
        digest(
            coalesce(v_prev_hash, ''::bytea)
            || to_jsonb(NEW)::text::bytea,
            'sha256'
        ),
        now()
    );

    RETURN NEW;
END;
$$;

-- Activar el trigger en privilege_atom_grant para INSERT y UPDATE
CREATE TRIGGER trg_t170_worm
    AFTER INSERT OR UPDATE
    ON bauth.privilege_atom_grant
    FOR EACH ROW
    EXECUTE FUNCTION bauth.fn_worm_append();
```

**Requisito:** `pgcrypto` debe estar habilitado en `bauth_db` (`CREATE EXTENSION IF NOT EXISTS pgcrypto`).

### 6.4 Propagación WAL → Redis + CAEP (daemon bauth-reactor)

La invalidación del caché Redis y la emisión de eventos CAEP **no ocurren en el trigger** — ocurren en el daemon `bauth-reactor` que consume el WAL de PostgreSQL vía logical decoding.

```
privilege_atom_grant
    INSERT / UPDATE
        │
        ├── [trigger SQL] → privilege_atom_audit (hash-chain WORM)
        │                     [dentro de la misma transacción BD]
        │
        └── [WAL logical decoding] → bauth-reactor (daemon Rust)
                │  (stream del plugin pgoutput — slot replication)
                │
                ├── Redis INVALIDATION
                │     DEL bitmask:{tenant_id}:{user_id}
                │     DEL bitmask:{tenant_id}:rol:{rol_id}
                │     (fuerza reconstrucción en la próxima autenticación)
                │
                └── CAEP token_claims_change
                      → Kong (vía gRPC sobre Unix socket /run/bos/bauth.sock)
                      → Kong invalida JWT activos que contenían el bit modificado
```

**Por qué NO en el trigger:** si Redis está caído cuando el trigger ejecuta, el trigger falla → la transacción de BD hace rollback → el grant no se persiste aunque el admin lo aprobó. El WAL garantiza que la propagación es best-effort y desacoplada: el dato se persiste en BD siempre; la invalidación Redis/CAEP ocurre después, fuera de la transacción.

**Nota:** `bauth-reactor` requiere un slot de replicación lógica (`pg_create_logical_replication_slot`) y que `bauth_db` tenga `wal_level = logical`.

---

### 6.5 privilege_delegation (T-172) — registro de auditoría de asignaciones de rol temporal

**Propósito exclusivo: auditoría y trazabilidad.** Esta tabla NO valida ni controla la delegación.
La validación real ocurre en tres lugares independientes de esta tabla:

1. **T-170 `privilege_atom_grant`**: los átomos del rol temporal asignados al usuario con `valid_from`/`valid_until`
2. **Admin que ejecuta la asignación**: el control de acceso es la autoridad del administrador
3. **merge_roles del engine Rust**: resuelve el BitMask resultante de los roles combinados (AND/OR según configuración)

Esta tabla responde una sola pregunta: *"¿por qué tiene este usuario este rol temporal y quién lo autorizó?"*

**Doctrina de diseño (G-08):** el problema original de "cadenas de delegación ilimitadas" no existe en bAuth porque la delegación es en realidad una **asignación de rol auxiliar** por un administrador. Los roles auxiliares son roles reales del catálogo (mismo tier o adyacente — un cajero puede recibir un rol auxiliar de contabilidad del mismo rango, no el rol de gerente general). En la práctica, un usuario ejerce máximo dos roles simultáneamente, lo que hace el merge trivial para el engine. La profundidad ilimitada es imposible porque solo el admin puede asignar roles — el usuario que recibe no puede re-propagar.

```sql
-- ─────────────────────────────────────────────────────────────────────────────
-- SOLO AUDITORÍA — no modificar para agregar validaciones.
-- Las validaciones de delegación viven en T-170, en el admin y en merge_roles.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE bauth.privilege_delegation (
    id              uuid        NOT NULL DEFAULT gen_random_uuid(),
    -- Siempre dentro de un tenant (G-06)
    tenant_id       uuid        NOT NULL,
    -- Rol auxiliar asignado temporalmente (mismo tier o adyacente en el catálogo)
    role_id         uuid        NOT NULL,
    -- Usuario que recibe la asignación temporal
    assignee_id     uuid        NOT NULL,
    -- Admin que autorizó la asignación — trazabilidad de quién tomó la decisión
    assigned_by     uuid        NOT NULL,
    -- Justificación obligatoria: sin motivo documentado no hay asignación válida
    reason          text        NOT NULL,
    -- Período informativo: la vigencia real está en los átomos del rol en T-170
    valid_from      timestamptz NOT NULL DEFAULT now(),
    valid_until     timestamptz NOT NULL,
    status          text        NOT NULL DEFAULT 'ACTIVE',
    ctx_id          text        NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT privilege_delegation_pkey PRIMARY KEY (id),
    CONSTRAINT chk_pd_status CHECK (status IN ('ACTIVE','EXPIRED','REVOKED')),
    CONSTRAINT chk_pd_valid  CHECK (valid_from < valid_until)
);
-- Consultas por usuario: "¿qué asignaciones temporales tiene activas este usuario?"
CREATE INDEX idx_pd_assignee
    ON bauth.privilege_delegation (assignee_id, tenant_id)
    WHERE status = 'ACTIVE';
-- Job de expiración: asignaciones próximas a vencer
CREATE INDEX idx_pd_valid_until
    ON bauth.privilege_delegation (valid_until)
    WHERE status = 'ACTIVE';
```

> **Observación — widget de delegación en bAuth Desktop (pendiente):**
> Las asignaciones temporales de rol deben originarse desde el Dashboard de bAuth, no desde scripts manuales.
> Se debe agregar un **widget de delegación de roles a usuarios** en el Desktop que permita al admin:
> seleccionar usuario destinatario, elegir el rol auxiliar, definir el período, ingresar la justificación,
> y confirmar la asignación. El widget es el punto de entrada que garantiza que cada asignación
> genere su registro en T-172 (auditoría) y sus átomos correspondientes en T-170 (grants reales).
> Sin el widget, la trazabilidad queda incompleta — los grants existirían en T-170 sin el registro
> de contexto en T-172.

---

### 6.6 privilege_override (T-173) — excepciones DENY→PERMIT con quórum

Conversión temporal de DENY a PERMIT (o de PERMIT a DENY) para un usuario específico, aprobada por un administrador con quórum. Siempre acotada en el tiempo y con justificación obligatoria. Destinada a casos de emergencia o excepción documentada — no a gestión ordinaria de accesos.

```sql
CREATE TABLE bauth.privilege_override (
    id              uuid        NOT NULL DEFAULT gen_random_uuid(),
    -- Override siempre dentro de un tenant (G-06)
    tenant_id       uuid        NOT NULL,
    -- Átomo sobre el que aplica el override — FK compuesta
    id_atom         uuid        NOT NULL,
    atom_position   integer     NOT NULL,
    -- Usuario afectado
    user_id         uuid        NOT NULL,
    -- Dirección del override:
    -- DENY_TO_PERMIT: el usuario tenía DENY (o sin grant), se le concede acceso excepcional
    -- PERMIT_TO_DENY: el usuario tenía PERMIT, se le bloquea temporalmente (ej: incidente)
    override_type   text        NOT NULL,
    -- Quórum: al menos un aprobador con autoridad registrada
    approver_id     uuid        NOT NULL,
    -- Justificación obligatoria — ISO 27001 A.8.2 least privilege + trazabilidad forense
    reason          text        NOT NULL,
    -- Referencia al evento de auditoría de la aprobación (forense cruzado)
    audit_event_id  uuid        NULL,
    -- Override siempre temporal: el acceso de emergencia no puede ser indefinido
    valid_from      timestamptz NOT NULL DEFAULT now(),
    valid_until     timestamptz NOT NULL,
    status          text        NOT NULL DEFAULT 'ACTIVE',
    created_by      text        NOT NULL,
    ctx_id          text        NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT privilege_override_pkey PRIMARY KEY (id),
    CONSTRAINT fk_po_atom_position
        FOREIGN KEY (id_atom, atom_position)
        REFERENCES bauth.idn_roles_template (id, atom_position)
        DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT chk_po_status        CHECK (status IN ('ACTIVE','EXPIRED','REVOKED')),
    CONSTRAINT chk_po_valid         CHECK (valid_from < valid_until),
    CONSTRAINT chk_po_override_type CHECK (override_type IN ('DENY_TO_PERMIT','PERMIT_TO_DENY'))
);
-- Un solo override activo del mismo tipo por (tenant, átomo, usuario)
CREATE UNIQUE INDEX uq_po_active_override
    ON bauth.privilege_override (tenant_id, id_atom, user_id, override_type)
    WHERE status = 'ACTIVE';
-- Consultas por usuario: "¿qué overrides activos tiene este usuario?"
CREATE INDEX idx_po_user
    ON bauth.privilege_override (user_id, tenant_id)
    WHERE status = 'ACTIVE';
-- Job de expiración: overrides próximos a vencer
CREATE INDEX idx_po_valid_until
    ON bauth.privilege_override (valid_until)
    WHERE status = 'ACTIVE';
```

---

## 7. Evaluación del BitMask — flujo correcto

```
NACIMIENTO DEL ÁTOMO (una sola vez al crear el nodo en T-162):
  INSERT INTO idn_roles_template (tipo='evaluacion', ...)
    atom_position = nextval('bauth.roles_atom_position_sequential')
    — la posición queda fijada PARA SIEMPRE en T-162

AUTENTICACIÓN (cada vez que un usuario se autentica):
  T-162          → evalúa política: qué átomos corresponden al rol/usuario
                   (lectura del árbol de políticas por AtomLang)
        ↓
  idn_roles_template → atom_position ya está ahí para cada nodo evaluacion
  privilege_atom_grant → resuelve grants activos (PERMIT/DENY) por id_atom + tenant_id
                          FK compuesta garantiza que atom_position = el de T-162
        ↓
  Fórmula §5.2   → (generales + rol_PERMIT) - rol_DENY
        ↓
  RolBitMask     → vector N-bit: activar atom_position de cada átomo efectivo
                   cacheado en Redis con TTL 30s (clave: bitmask:{tenant_id}:{user_id})
        ↓
  JWT            → lleva rol_bitmask_base64 (BitVec serializado en base64)
        ↓

VERIFICACIÓN EN KONG (PEP — por cada solicitud entrante):
  Solicitud entrante (WS-RPC / JSON-RPC / gRPC / HTTP_EXT⁽¹⁾)
        ↓
  kong_route          → privilege_resource_atom → id_atom
                         (lookup por tipo_protocolo + recurso + operación — tabla en caché Kong)
        ↓
  id_atom             → idn_roles_template.atom_position
                         (Kong mantiene su propio caché id_atom→atom_position; recarga via CAEP)
        ↓
  rol_bitmask[atom_position] == 1?
        ├── SÍ D1/D2  → FastPath: PERMIT inmediato (< 0.5 ns, sin llamada a bAuth)
        └── SÍ D3-D13 → PolicyPath: Kong consulta bAuth vía JSON-RPC sobre Unix socket
                         → bAuth PDP evalúa y responde PERMIT/DENY

INVALIDACIÓN (cuando privilege_atom_grant cambia):
  trigger trg_t170_worm → privilege_atom_audit (hash-chain WORM, dentro de la misma tx)
  WAL logical decoding  → bauth-reactor daemon:
                            DEL Redis bitmask:{tenant_id}:{user_id}
                            CAEP token_claims_change → Kong (invalida JWTs activos)

⁽¹⁾ HTTP_EXT solo para clientes externos sin soporte de otro protocolo — nunca entre daemons SBOS (SBOS-050 P9).
```

---

## 8. Estructura de privilege_resource_atom (tabla PAP para Kong)

Permite a Kong resolver `(tipo_protocolo + recurso + operación) → id_atom` sin consultar bAuth en cada request.

**Protocolos válidos (SBOS-050 P9):** WebSocket RPC · JSON-RPC 2.0 · gRPC · Unix socket. HTTP/REST se admite exclusivamente para solicitudes de clientes externos que no soporten otro protocolo — nunca entre daemons SBOS.

```sql
CREATE TABLE bauth.privilege_resource_atom (
    id               UUID PRIMARY KEY,   -- uuidv7
    -- tenant_id NOT NULL (G-06): el mapeo recurso→átomo es per-tenant.
    -- El mismo endpoint puede mapear a átomos distintos para distintos tenants
    -- porque cada tenant tiene su propio árbol T-162.
    tenant_id        UUID NOT NULL,
    tipo_protocolo   TEXT NOT NULL,      -- WS_RPC / JSON_RPC / GRPC / UNIX_SOCKET / HTTP_EXT
                                         -- HTTP_EXT = solo clientes externos sin soporte de otro protocolo
    recurso          TEXT NOT NULL,      -- identifica el recurso según protocolo:
                                         --   WS_RPC:      "bauth.token.validate"
                                         --   JSON_RPC:    "biedata.rpc/sale.create"
                                         --   GRPC:        "/bauth.AuthService/Evaluate"
                                         --   UNIX_SOCKET: "/run/bos/bauth.sock#session.open"
                                         --   HTTP_EXT:    "/api/v1/auth/login"  ← solo entrada externa
    operacion        TEXT NOT NULL,      -- nombre del método / evento / acción:
                                         --   JSON_RPC:  nombre del método ("bauth.token.validate")
                                         --   GRPC:      nombre del procedimiento ("Evaluate")
                                         --   WS_RPC:    nombre del comando ("session.open")
                                         --   HTTP_EXT:  verbo HTTP ("POST","GET") — solo cuando aplica
    id_atom          UUID NOT NULL,      -- FK → privilege_atom_grant.id_atom
    domain_code      SMALLINT NOT NULL,  -- D01-D13: determina FastPath o PolicyPath
    evaluation_path  TEXT NOT NULL,      -- FAST / POLICY / EXTERNAL / PRECONDITION
    tenant_scope     TEXT NOT NULL,      -- GLOBAL / TENANT_SPECIFIC
    status           TEXT NOT NULL DEFAULT 'ACTIVE',
    -- Obligación de contexto del recurso (decisión G-04 · SBOS-0XX-G04-LOA-AAL-OBLIGACIONES.md §3).
    -- NULL = sin obligación; bit=1 en el JWT es suficiente para conceder acceso.
    -- NOT NULL = Kong (PEP) debe verificar la condición contra la sesión activa (Redis/Context Plane)
    --            antes de conceder acceso, aunque el bit esté activo.
    -- El bit=1 en el JWT NO implica autorización final cuando obligation IS NOT NULL.
    -- Evaluado ÚNICAMENTE por Kong en runtime — bAuth NO consulta este campo al emitir el JWT.
    -- Estructura válida: {"required_loa": "AAL1"|"AAL2"|"AAL3"}
    obligation       JSONB    NULL,
    CONSTRAINT chk_pra_obligation_schema CHECK (
        obligation IS NULL
        OR (
            jsonb_typeof(obligation) = 'object'
            AND obligation ? 'required_loa'
            AND (obligation->>'required_loa') IN ('AAL1','AAL2','AAL3')
        )
    ),
    -- Unicidad per-tenant: el mismo recurso+operación puede existir en dos tenants
    -- apuntando a átomos distintos (cada tenant tiene su propio árbol T-162)
    CONSTRAINT uq_pra_tenant_resource UNIQUE (tenant_id, tipo_protocolo, recurso, operacion)
);
```

Kong carga esta tabla al arrancar. La recarga cuando bAuth emite evento CAEP `catalog_change` vía gRPC sobre Unix socket — nunca por HTTP.

---

## 9. Modelo XACML 3.0 — roles de cada componente

| Rol XACML | Componente en bAuth | Qué hace |
|-----------|--------------------|---------:|
| **PAP** (Policy Administration Point) | Dashboard bAuth + `privilege_resource_atom` | Admin configura qué recurso requiere qué átomo |
| **PDP** (Policy Decision Point) | bAuth BitMask engine | Evalúa `RolBitMask[atom_position] == 1` + PolicyEngine XACML 3.0 para D3-D13 |
| **PEP** (Policy Enforcement Point) | Kong | Intercepta solicitudes entrantes, verifica bit en JWT; para PolicyPath consulta bAuth vía JSON-RPC sobre Unix socket (`/run/bos/bauth.sock`) — nunca HTTP interno |
| **PIP** (Policy Information Point) | Redis + `privilege_atom_grant` | Provee RolBitMask del usuario (Redis cache) y posiciones de bit (BD) |

---

## 10. Estándares que esta arquitectura cumple

| Estándar | Requisito | Cómo se cumple |
|----------|-----------|----------------|
| XACML 3.0 §7.1 | Separación PAP/PDP/PEP/PIP | `privilege_resource_atom` (PAP) · bAuth engine (PDP) · Kong (PEP) · Redis+BD (PIP) |
| NIST SP 800-207 §3.3 | Todo recurso debe tener política explícita — sin acceso implícito | `privilege_resource_atom` mapea cada recurso a un átomo; sin mapeo = DENY por defecto |
| NIST SP 800-53 AC-3 | El sistema aplica autorizaciones aprobadas | Kong (PEP) verifica bit antes de procesar cualquier request |
| NIST SP 800-53 AC-6 | Mínimo privilegio | AND en delegación (D10) · átomos DENY explícito · átomos generales como piso mínimo |
| ANSI INCITS 359-2004 §4 | RBAC N3 Constrained | Herencia DAG (T-162 + closure) · SoD (conflict.rs) · asignaciones en privilege_atom_grant |
| RFC 9068 | JWT como portador de autorización | `rol_bitmask_base64` claim en JWT — bitfield compacto (~1 KB para ~6000 átomos) |
| ISO 27001 A.8.15 | Audit logging inmutable | `privilege_atom_audit` tabla append-only con hash-chain SHA-256 · REVOKE UPDATE/DELETE en `bauth_app_role` · trigger `trg_t170_worm` en privilege_atom_grant |
| OpenID AuthZEN 1.0 | Semántica estándar PEP↔PDP | Gap P2 — semántica AuthZEN (`subject/resource/action/context`) a implementar sobre JSON-RPC en Unix socket, no sobre HTTP (SBOS-050 P9) |

---

## 11. Tablas del grupo PRIVILEGIOS — resumen definitivo

| Código | Tabla | Propósito resumido |
|--------|-------|--------------------|
| T-162 | `bauth.idn_roles_template` | Árbol de políticas. Los nodos `tipo='evaluacion'` son los átomos. Columna `atom_position` asignada vía `roles_atom_position_sequential` — fuente de verdad de la posición de bit. |
| T-170 | `bauth.privilege_atom_grant` | Asignaciones rol/usuario PERMIT/DENY con FK compuesta a T-162. `atom_position` se lee de T-162, nunca se auto-genera aquí. Con soporte JIT (`valid_from`/`valid_until`) y aislamiento `tenant_id`. |
| T-170b | `bauth.privilege_atom_audit` | Tabla WORM append-only: hash-chain SHA-256 de cada INSERT/UPDATE en T-170. REVOKE UPDATE/DELETE en `bauth_app_role`. Cumple ISO 27001 A.8.15. |
| T-171 | `bauth.privilege_resource_atom` | Tabla PAP: (tipo_protocolo + recurso + operacion) → id_atom. Columna `obligation JSONB NULL` (G-04): cuando NOT NULL, Kong verifica `required_loa` contra la sesión activa antes de PERMIT. `bit=1` en JWT indica que el grant existe, no autorización final. Kong la carga al arrancar. Sin esta tabla Kong no puede ser PEP enterprise. |
| T-172 | `bauth.privilege_delegation` | Delegaciones D10 runtime — AND reduction. Estado operacional, no existe en T-162. WITH OVERLAPS PG18. |
| T-173 | `bauth.privilege_override` | Excepciones DENY→PERMIT aprobadas por admin con quórum. Vigencia acotada + audit trail. |
| T-174 | `bauth.privilege_verb` | Catálogo de verbos válidos. **Solo validación** — no estructura átomos, no participa en BitMask ni autenticación. FK referenciada por `idn_roles_template.verb_id`. |
| T-175 | `bauth.privilege_verb_conflict` | Matriz de conflictividad entre pares de verbos (SOD_ESTATICO / SOD_DINAMICO / AFINIDAD). **Solo validación** — consultada únicamente por el trigger SoD en `privilege_atom_grant` y por el compilador AtomLang. Almacena cada par una sola vez (verb_a < verb_b). |
| T-176 | `bauth.privilege_assurance_audit` | Auditoría de evaluación de obligaciones LoA (G-04). Poblada por Kong (PEP), nunca por bAuth. Registra cada evaluación de `obligation` en T-171 contra la sesión activa: `grant_id`, `resource_id`, `required_loa`, `presented_loa`, `outcome`, `session_id`. Separada de T-170b: esta tabla crece por request, no por cambio de grant. Candidata a particionamiento por fecha. |

### DDL — T-176: privilege_assurance_audit

```sql
-- ─────────────────────────────────────────────────────────────────────────────
-- PROPÓSITO: registrar cada evaluación de obligación de LoA realizada por Kong (PEP).
--
-- Separación de responsabilidades respecto a privilege_atom_audit (T-170b):
--   · T-170b audita QUÉ SE OTORGÓ y cuándo cambió el grant (bAuth escribe).
--   · T-176 audita CÓMO SE EJERCIÓ lo otorgado en runtime (Kong escribe).
--
-- Esta tabla NO la escribe bAuth. Kong inserta una fila en cada evaluación de
-- un recurso cuya T-171.obligation IS NOT NULL.
--
-- VOLUMEN: crece con cada request evaluado — a diferencia de T-170b que crece
-- solo cuando cambia un grant. Por eso se recomienda particionamiento por fecha
-- (PARTITION BY RANGE created_at) y política de retención propia.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE bauth.privilege_assurance_audit (
    id             uuid        NOT NULL DEFAULT gen_random_uuid(),
    grant_id       uuid        NOT NULL REFERENCES bauth.privilege_atom_grant(id),
    resource_id    text        NOT NULL,
    required_loa   text        NOT NULL CHECK (required_loa IN ('AAL1','AAL2','AAL3')),
    presented_loa  text        NOT NULL CHECK (presented_loa IN ('AAL1','AAL2','AAL3')),
    outcome        text        NOT NULL CHECK (outcome IN ('PERMIT','STEP_UP_REQUIRED','DENIED')),
    session_id     uuid        NOT NULL,
    evaluated_by   text        NOT NULL DEFAULT 'kong-pep',
    created_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT privilege_assurance_audit_pkey PRIMARY KEY (id)
);
-- Índice por grant_id para correlacionar con T-170 y T-170b en forensia
CREATE INDEX idx_paa_grant   ON bauth.privilege_assurance_audit (grant_id);
-- Índice por session_id para reconstruir el timeline de step-up de una sesión
CREATE INDEX idx_paa_session ON bauth.privilege_assurance_audit (session_id);
-- Índice por fecha para soportar particionamiento y retención
CREATE INDEX idx_paa_created ON bauth.privilege_assurance_audit (created_at);
-- Kong no puede modificar ni borrar registros — solo insertar
REVOKE UPDATE, DELETE ON bauth.privilege_assurance_audit FROM bauth_app_role;
```

---

## 12. Lo que NO necesita tablas en PRIVILEGIOS

| Concepto | Por qué no necesita tabla |
|----------|--------------------------|
| Catálogo de dominios D01-D13 | `src/bitmask/catalog.rs:SEED_DOMAINS` — son seeds inmutables, no datos mutables |
| Jerarquía domain→app→group | Vive en T-162 (el árbol) — se consulta ahí, no se duplica en tablas planas |
| Asignación rol→átomo en tiempo de auth | Computado por AtomLang desde T-162 + privilege_atom_grant en nanosegundos — no se persiste el resultado |
| RolBitMask por rol | Computado al autenticar, cacheado en Redis (TTL 30s) — no en PostgreSQL |
| `atom_position` como cálculo en tiempo de autenticación | `atom_position` vive en `idn_roles_template` (T-162) y se asigna UNA vez vía `roles_atom_position_sequential`. El cálculo en runtime sería un `MAX() + 1` con race condition bajo concurrencia — no se puede delegar a la aplicación |

---

## 13. Zona de Negocios — decisión de nomenclatura y estructura

### 13.1 Por qué se llama "Zona de Negocios" y no "Registro de Aplicaciones"

El nombre **Zona de Negocios** (Business Zone) tiene origen normativo directo en los principales marcos de seguridad empresarial. No es una elección estética: es el término que los estándares usan para este concepto.

| Estándar | Término | Qué define |
|----------|---------|------------|
| **NGAC INCITS 565-2020 §4** | Policy Class (PC) | Contenedor de nodos bajo un conjunto de políticas. Una zona = un PC con su perímetro de control. |
| **SABSA SCF** | Business Zone | Agrupación de activos de negocio bajo controles de seguridad comunes. Cada zona tiene su propia política. |
| **ISO/IEC 27001:2022 A.5.15** | Access Control — Segregación | Las zonas de negocio son la unidad de segregación de acceso. Un activo pertenece a una zona. |
| **NIST SP 800-207 §3.3** | Recursos empresariales — protección individual | En ZTA no existe perímetro de red de confianza: cada recurso se protege individualmente bajo su propia política. El PDP evalúa cada solicitud por atributos del recurso, del sujeto y del contexto — no por ubicación de red. La Zona de Negocios materializa este principio: un perímetro lógico por aplicación. |
| **XACML 3.0 §5.2** | PolicySet con Target | Cada zona es un PolicySet con un Target que delimita su alcance. Solo políticas compatibles son válidas dentro. |

**Conclusión:** el nombre "Zona de Negocios" es el que usan los estándares internacionales para este contenedor. "Registro de Aplicaciones" describía la implementación; "Zona de Negocios" describe el concepto de seguridad. La nomenclatura canónica sigue la norma.

### 13.2 Regla global — todos los dominios tienen exactamente una Zona de Negocios

**Todo dominio del árbol RolTemplate** (D01 a D13, D98, D99) contiene exactamente **un** bloque `Zona de Negocios`. Este bloque está presente aunque el dominio no tenga aplicaciones registradas aún — existe vacío, listo para recibir configuraciones.

El nombre interno del nodo en el árbol sigue el prefijo del dominio:

| Dominio | Bloque | Prefijo zona-app |
|---------|--------|------------------|
| D01 · ACCESO LÓGICO | `B6 · Zona de Negocios` | `zona_logical_*` |
| D02 · ACCESO FÍSICO | `Zona de Negocios` | `zona_fisica_*` |
| D03 · FINANCIERO | `Zona de Negocios` | `zona_financial_*` |
| D04 · TEMPORAL | `Zona de Negocios` | `zona_temporal_*` |
| D06 · GEOESPACIAL | `Zona de Negocios` | `zona_geo_*` |
| D07 · RED | `Zona de Negocios` | `zona_network_*` |
| D08 · CONTEXTO | `Zona de Negocios` | `zona_context_*` |
| D09 · CREDENCIALES | `Zona de Negocios` | `zona_credential_*` |
| D10 · DELEGACIÓN | `Zona de Negocios` | `zona_delegation_*` |
| D11 · AUDITORÍA | `Zona de Negocios` | `zona_audit_*` |
| D12 · BLOCKCHAIN | `Zona de Negocios` | `zona_blockchain_*` |
| D13 · FIRMA DIGITAL | `Zona de Negocios` | `zona_signature_*` |

### 13.3 Lo que el bloque acepta y lo que rechaza

El bloque Zona de Negocios **solo acepta nodos de tipo `politica`** que representen aplicaciones concretas — cada uno con un bloque **Z0 · Identidad** obligatorio.

**No acepta:**
- Áreas de negocio abstractas como `zona_ventas`, `zona_clientes`, `zona_rrhh`
- Nodos de tipo `dominio`, `bloque` o `evaluacion` como hijo directo
- Aplicaciones sin bloque Z0 · Identidad
- Zonas con prefijo de otro dominio (ej: `zona_financial_*` dentro de D01)

**El validador del árbol rechaza** cualquier nodo que viole estas reglas antes de permitir compilación.

---

## 14. Las aplicaciones — por qué no necesitan tablas de definición

### 14.1 El árbol T-162 ES la definición de la aplicación

Esta fue una de las decisiones de diseño más importantes del ciclo de análisis. La pregunta inicial era: ¿necesitamos tablas para definir las aplicaciones (verbo por verbo, campo por campo)?

La respuesta es **no**. Y la razón es el árbol.

T-162 ya contiene, para cada aplicación registrada en una Zona de Negocios:
- Su identidad completa (Z0 · Identidad: `app_code`, `vendor`, `loa_required`, `sod_enforced`, `clasificacion`)
- Su jerarquía interna (módulos → sub-módulos)
- Sus átomos (los nodos `evaluacion` con verbo + efecto + condiciones)
- Sus políticas (quién puede qué, bajo qué condiciones)

AtomLang compila todo esto en **nanosegundos** al momento de autenticar. No hay por qué duplicar en tablas relacionales lo que el árbol ya expresa de forma más rica y tipada.

### 14.2 Qué hubiera ocurrido con tablas de definición

Si se hubieran creado tablas como `privilege_application`, `privilege_application_verb`, `privilege_application_field`, etc., el resultado sería:

1. **Duplicación**: la misma información en dos lugares (árbol + tablas). Cualquier cambio requiere actualizarse en ambos.
2. **Superficie de desincronización**: si el árbol dice una cosa y la tabla dice otra, ¿cuál gana? La pregunta no tiene respuesta limpia.
3. **Pérdida del contexto rico**: la tabla almacena `verbo=read`, pero el árbol almacena `verbo=read + subject=IN cajero + obligation=AAL2 + advice=SSO`. La tabla es una degradación del árbol.
4. **Complejidad sin beneficio**: tablas que nadie consulta directamente (Kong no las necesita, bAuth no las necesita en runtime) porque todo pasa por el árbol.

### 14.3 Para qué SÍ existen tablas relacionadas a aplicaciones

Las tablas que existen en el esquema bAuth para las aplicaciones tienen UN propósito específico: **auditoría, trazabilidad y persistencia de autenticación**. No definen la aplicación; registran eventos sobre ella.

| Propósito | Tabla | Qué registra |
|-----------|-------|--------------|
| Trazabilidad de acceso | `aud_event` | Cada acceso a cada aplicación, con ctx_id, user_id, decision, timestamp |
| Persistencia de sesión | tablas de SESIÓN (T-180+) | Qué aplicaciones están activas en la sesión actual |
| Mapeo PAP para Kong | `privilege_resource_atom` (T-171) | Qué recurso HTTP requiere qué átomo — cargado por Kong al arrancar |
| Catálogo seed | seeds de aplicaciones | Lista de aplicaciones conocidas para bootstrap — no estructura de verbo |

La regla es: **si la tabla define QUÉ ES la aplicación o QUÉ PUEDE HACER → no necesita tabla (vive en el árbol). Si la tabla registra QUÉ PASÓ con la aplicación → necesita tabla (auditoría/sesión).**

---

## 15. Separación de dominios — a qué dominio pertenece cada átomo

### 15.1 La misma app puede aparecer en múltiples dominios

Una aplicación (ej: Tryton ERP) registra átomos en diferentes dominios según la naturaleza del control:

```
Tryton ERP en D01 · ACCESO LÓGICO:
  zona_logical_tryton
    ├── model  → tryton.sale.read, tryton.sale.create       ← control de acceso a módulos ERP
    ├── actions → tryton.menu.sale_dashboard.open          ← menús y vistas
    ├── field  → tryton.party.vat.view                      ← campos individuales (PII)
    ├── button → tryton.invoice.validate.click              ← botones de acción
    └── record_rule → tryton.invoice.own_records            ← filtros sobre registros

Tryton ERP en D03 · FINANCIERO:
  zona_financial_tryton
    ├── model  → D03.tryton.account.confirm                 ← control sobre operaciones contables
    ├── field  → D03.tryton.payment.amount.view             ← visibilidad de importes
    └── button → D03.tryton.payment.validate                ← autorizar pagos
```

**Regla:** el dominio del átomo es el dominio del TIPO DE CONTROL, no el dominio de la aplicación. Tryton es una app lógica, pero sus módulos financieros imponen controles financieros — entonces esos átomos viven en D03.

### 15.2 Dónde van los controles transversales

| Tipo de control | Dominio correcto | Razón |
|-----------------|-----------------|--------|
| Acceso a módulos, menús, campos, botones, filtros de registro | **D01** (Acceso Lógico) | Control de acceso a recursos del sistema de información |
| Importes, aprobaciones financieras, validación de pagos | **D03** (Financiero) | El control es sobre una operación financiera, no solo sobre un recurso |
| Restricciones horarias (ventanas de operación) | **D04** (Temporal) | La restricción es temporal, no de recurso |
| Restricciones geográficas (país, ciudad, geofence) | **D06** (Geoespacial) | La restricción es de ubicación |
| Filtros de territorio y jurisdicción | **D06** (Geoespacial) | Incluso si aplican a datos contables — el control es geoespacial |
| Segmentos de red, IPs autorizadas | **D07** (Red) | La restricción es de conectividad |
| Verificación biométrica requerida | **D05** (Biométrico) | La restricción es de método de autenticación |
| Firma digital requerida | **D13** (Firma Digital Externa) | La restricción es de integridad y validez jurídica |

### 15.3 Por qué esta separación es correcta

Cuando el PDP evalúa si un usuario puede confirmar una factura de $50.000, necesita:
- D01: ¿tiene acceso al módulo de facturación?
- D03: ¿su rol autoriza montos superiores a $10.000? ¿requiere doble firma?
- D04: ¿está dentro del horario de operación bancaria?
- D09: ¿el LoA alcanzado es AAL2 o superior?

Si todos estos átomos vivieran en D01, el dominio financiero sería indiferenciable del acceso lógico básico. La separación hace que cada evaluador de dominio tenga su responsabilidad clara y el AtomBitMask refleje exactamente de qué tipo de control se trata.

---

## 16. B7 eliminado — Z0 · Identidad absorbe el control de acceso a la aplicación

### 16.1 Decisión

El bloque **B7** que existía dentro de D01 · ACCESO LÓGICO fue eliminado del árbol. Su función fue redistribuida a donde conceptualmente pertenece.

### 16.2 El problema que B7 pretendía resolver

B7 intentaba modelar "el control de acceso a la aplicación como tal" — es decir, si un usuario puede siquiera abrir/usar la aplicación, independientemente de qué puede hacer dentro de ella.

Ejemplo: ¿puede el usuario `juan` acceder a Tryton ERP? (no qué puede hacer dentro, sino si puede entrar)

### 16.3 La solución correcta

Este control vive en **Z0 · Identidad** dentro de la zona-app correspondiente:

```
D01 · ACCESO LÓGICO
  └── B6 · Zona de Negocios
        └── zona_logical_tryton
              └── Z0 · Identidad      ← AQUÍ vive el control de acceso a la app
                    ├── app_code:     'tryton_erp'
                    ├── loa_required: 'AAL2'           ← LoA mínimo para entrar
                    ├── sod_enforced: true
                    ├── clasificacion: 'CONFIDENTIAL'
                    └── (átomos de acceso a la app):
                          └── tryton.app.access        ← átomo: "puede usar Tryton"
                                ├── verbo:    'access'
                                ├── propiedad: 'subject'
                                ├── operador:  'IN'
                                └── valor:     'bauth.role/empleado,bauth.role/supervisor'
```

**Ventaja sobre B7:** el átomo `tryton.app.access` es un átomo regular del árbol. Se evalúa con el mismo motor BitMask que todos los demás átomos, tiene su posición en el RolBitMask, y Kong lo verifica en el mismo FastPath. No necesita una capa adicional ni un bloque separado.

### 16.4 Por qué B7 no debe volver

B7 creaba un nivel adicional de indirección: el árbol tenía una capa para "¿puede entrar?" y otra para "¿qué puede hacer dentro?". Esta separación requería dos evaluaciones diferentes con lógica diferente.

Con Z0 · Identidad + átomos de acceso dentro de la zona-app, **todo es un átomo**. La evaluación es uniforme: el motor BitMask verifica el bit, Kong verifica el bit, el JWT lleva el bit. No hay caso especial para "acceso a la aplicación" — es un átomo como cualquier otro.

---

## 17. Resumen de decisiones de diseño — tabla maestra

| # | Decisión | Alternativa descartada | Razón |
|---|----------|------------------------|-------|
| D-01 | `atom_position` vive en `idn_roles_template` (T-162), asignada vía `roles_atom_position_sequential` | Calculada en `privilege_atom_grant` con `MAX(atom_position)+1` | Race condition bajo `READ COMMITTED`: dos transacciones concurrentes calculan la misma posición para el mismo átomo. La SEQUENCE de PostgreSQL es atómica — no hay colisión posible. El átomo inactivo persiste en T-162 con `activo=false`; el bit queda reservado para siempre |
| D-01b | hash-chain WORM en tabla separada `privilege_atom_audit`, no en `privilege_atom_grant` | Columna `hash_chain BYTEA` en T-170 | ISO 27001 A.8.15 requiere registros inmutables. Una tabla con permisos UPDATE no puede ser WORM aunque tenga un campo hash. La separación es la única forma de garantizar inmutabilidad: `REVOKE UPDATE/DELETE` en tabla diferente |
| D-02 | AtomBitMask(u64) y RolBitMask(N-bit) son estructuras separadas | Un solo campo u64 para todo | AtomBitMask es etiqueta (no se opera); RolBitMask es vector de permisos (sí se opera) — confundirlos rompe el motor |
| D-03 | UUIDv7 como identidad permanente del átomo | Auto-increment secuencial | Los UUIDv7 son únicos globalmente y ordenados en el tiempo; un átomo eliminado y re-creado tiene un UUID diferente, nunca el mismo |
| D-04 | El bloque se llama "Zona de Negocios" | "Registro de Aplicaciones Lógicas" | "Zona de Negocios" es el término de los estándares (NGAC, SABSA, ISO 27001, NIST 800-207, XACML 3.0) para este contenedor |
| D-05 | Todos los dominios D01-D13/D98/D99 tienen una Zona de Negocios | Solo D01 tiene el bloque | El bloque es una estructura de seguridad universal — cada dominio controla sus recursos a través de él |
| D-06 | La Zona de Negocios solo acepta nodos `politica` (zona-app) | Acepta cualquier tipo de nodo | El bloque es un contenedor de aplicaciones, no de categorías o áreas temáticas abstractas |
| D-07 | Las aplicaciones no necesitan tablas de definición | Tablas `privilege_application`, `privilege_verb`, etc. | El árbol T-162 ya contiene la definición completa con contexto rico; duplicarla en tablas crea desincronización sin beneficio |
| D-08 | Las tablas de aplicación existen solo para auditoría/persistencia | Para definir la estructura de la app | La definición vive en el árbol; las tablas registran lo que OCURRIÓ (auditoría, sesión, mapeo PAP) |
| D-09 | Los átomos financieros de Tryton van a D03, no a D01 | Todos los átomos de Tryton en D01 | El dominio del átomo es el tipo de control, no la app que lo genera — un control financiero es D03 aunque la app sea Tryton |
| D-10 | B7 eliminado; el control de acceso a la app vive en Z0 · Identidad | Bloque B7 separado para acceso a app | Un átomo en Z0 es evaluado por el mismo motor BitMask que el resto — no hay caso especial ni lógica adicional |
| D-11 | `privilege_atom_grant.user_id` cubre roles y usuarios (entidades D00) | Tablas separadas rol_atom y user_atom | Roles y usuarios son entidades en el modelo D00 — un solo campo FK es suficiente y simplifica la fórmula de resolución |
| D-12 | Átomos eliminados de T-162 persisten en `privilege_atom_grant` con `status=DELETED` | Borrar la fila de privilege_atom_grant | Si se borra la fila, la posición queda disponible para reciclarse — un bit reciclado corrompe todos los RolBitMasks existentes |

---

## 19. Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.7.0 | 2026-07-23 | **Corrección cita NIST SP 800-207 §3.3 en §13:** eliminado el término "Enterprise Resource Zone" (no existe en el documento NIST). Corregido en tabla de base normativa: reemplazado por descripción exacta del principio ZTA (protección individual de recursos, PDP evalúa por atributos, no por perímetro de red). Sincronizada versión de encabezado con historial (estaba en 1.2.0, debía ser 1.6.0). |
| 1.6.0 | 2026-07-20 | **G-08 rediseño T-172:** eliminados `depth_limit`, `chain_root`, `delegator_id`, `delegatee_id`, FK a átomos. T-172 queda como tabla de auditoría y trazabilidad exclusiva: `role_id` (rol auxiliar asignado), `assignee_id`, `assigned_by`, `reason` (obligatorio), `valid_from`/`valid_until` informativos. La delegación real es asignación de rol auxiliar por admin → T-170 + merge_roles Rust. Doctrina: problema de cadenas ilimitadas no existe porque solo el admin puede asignar roles. Observación pendiente: widget de delegación en bAuth Desktop para garantizar escritura atómica en T-172 + T-170. |
| 1.5.0 | 2026-07-20 | **G-06 árbol per-tenant:** `tenant_id uuid NOT NULL` agregado a T-162, T-170, T-171, T-172, T-173. T-162 UNIQUE actualizado de `(parent_id, clave)` a `(tenant_id, parent_id, clave)`. T-170 tenant_id pasa de NULL a NOT NULL (SU usa UUID reservado de sistema). T-171 agrega tenant_id + `CONSTRAINT uq_pra_tenant_resource UNIQUE (tenant_id, tipo_protocolo, recurso, operacion)`. Regla de bootstrap documentada: copia toda la estructura del árbol (tipos dominio/bloque/objeto/lista/politica/regla/atributo/enumerado/diagnostico) EXCEPTO tipo='evaluacion'. Zonas de negocio copiadas vacías de átomos. DDL completo nuevo para T-172 (§6.5, delegaciones temporales, depth_limit, chain_root, 3 índices) y T-173 (§6.6, overrides con quórum y justificación, partial unique activos, 2 índices). |
| 1.4.0 | 2026-07-20 | **G-09 IGA indexes:** doctrina per-user documentada en §6.2 — modelo: una fila por usuario por átomo, sin filas de rol; SET materializa N filas, UNSET modifica solo la fila del usuario excluido. Tres índices parciales nuevos en T-170: `idx_pag_user_entitlement (user_id, atom_position) WHERE user_id IS NOT NULL AND access=true AND status='ACTIVE'` (offboarding/revisión), `idx_pag_tenant_sweep (tenant_id, user_id) WHERE access=true AND status='ACTIVE'` (certificación trimestral), `idx_pag_valid_until (valid_until) WHERE valid_until IS NOT NULL AND status='ACTIVE'` (expiración NIST AC-2(6)). Índice existente `idx_pag_atom_access` documentado como Dirección 1 (átomo→usuarios). |
| 1.3.0 | 2026-07-20 | **G-04 step-up (RFC 9470):** `obligation JSONB NULL` agregado al CREATE TABLE de T-171 (`privilege_resource_atom`) con CHECK de schema (`required_loa` ∈ AAL1/AAL2/AAL3). T-176 `privilege_assurance_audit` — nueva tabla DDL completo: auditoría de evaluaciones de obligación poblada por Kong (no bAuth), REVOKE UPDATE/DELETE, 3 índices (grant_id, session_id, created_at). §11 tabla resumen ampliada con T-176. Decisión de diseño: `current_loa` vive en Redis keyed por `session_id`, nunca en el JWT. Ver doctrina completa en `SBOS-0XX-G04-LOA-AAL-OBLIGACIONES.md`. |
| 1.2.0 | 2026-07-20 | **Corrección arquitectónica crítica (SBOS-0XX):** §4 revertido — `atom_position` pasa de `privilege_atom_grant` a `idn_roles_template` (T-162) vía SEQUENCE `bauth.roles_atom_position_sequential` (race condition imposible). §6 reescrito completamente como CREATE TABLE (sin ALTER TABLE): §6.1 DDL de T-162 con columna `atom_position` + CHECK invariante + índice parcial; §6.2 DDL de T-170 con FK compuesta (id_atom, atom_position) → T-162, sin hash_chain, sin UNIQUE(atom_position), con partial indexes, con tenant_id y valid_from/valid_until JIT; §6.3 DDL de privilege_atom_audit (T-170b): tabla WORM append-only con hash-chain SHA-256, REVOKE UPDATE/DELETE, trigger fn_worm_append con pg_advisory_xact_lock; §6.4 propagación WAL (bauth-reactor): Redis invalidación + CAEP fuera de la transacción BD. §7 flujo actualizado para reflejar nacimiento del átomo en T-162, canalización via FK, y ciclo de invalidación. §10 ISO 27001 A.8.15 actualizado a privilege_atom_audit. §11 tabla resumen ampliada con T-162 y T-170b. §12 corrección: eliminada fila errónea. §17 D-01 invertido + nuevo D-01b WORM separado. |
| 1.1.0 | 2026-07-20 | Ampliación: §13 Zona de Negocios (nomenclatura normativa NGAC/SABSA/ISO 27001, regla global todos los dominios, restricción solo zona-app con Z0). §14 por qué las aplicaciones no necesitan tablas de definición (el árbol T-162 es la definición; tablas solo para auditoría/sesión/PAP). §15 separación de dominios (Tryton ERP en D01 vs D03, filtros geo en D06, montos en D03). §16 eliminación de B7 (control de acceso a la app vive en Z0·Identidad como átomo regular). §17 tabla maestra de 12 decisiones de diseño con alternativa descartada y razón. |
| 1.0.0 | 2026-07-20 | Creación. Documenta las decisiones de diseño surgidas del análisis del motor BitMask (src/bitmask/, Manual 1.04 v1.1.0) y el árbol RolTemplate (T-162). Cubre: identidad del átomo como nodo T-162 con UUIDv7, separación de responsabilidades T-162 vs privilege_atom_grant, inmutabilidad de atom_position, tres categorías de átomos (general/set/UNSET), flujo completo de evaluación BitMask, rol de Kong como PEP enterprise con privilege_resource_atom, y cumplimiento de estándares IAM enterprise (XACML 3.0, NIST SP 800-207, RFC 9068, AuthZEN 1.0). |
