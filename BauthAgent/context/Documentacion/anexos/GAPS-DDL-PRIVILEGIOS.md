# GAPS DDL — Resolución en curso

**Uso:** cada gap se responde aquí; al cerrar todos se borra el contenido y el archivo queda listo para la siguiente ronda.

---

## G-01 · Contrato de transacción atómica en privilege_atom_grant ✅ CERRADO

**Problema:** cuando un admin cambia una asignación (INSERT/UPDATE en T-170), deben ocurrir TRES efectos simultáneos: escribir el WORM hash-chain, invalidar el RolBitMask en Redis para todos los usuarios afectados, y emitir evento CAEP `token_claims_change` a Kong. Un developer que haga solo el INSERT en BD deja JWTs activos que no reflejan el cambio.

**Respuesta (SBOS-0XX · A.65.02.01 §6.3 y §6.4 v1.2.0):**

Los tres efectos son responsabilidad de dos mecanismos separados por diseño:

1. **Trigger SQL `trg_t170_worm`** (dentro de la misma transacción BD): escribe la fila en `privilege_atom_audit` con hash-chain SHA-256. Si la transacción hace rollback, el audit también. Si el audit falla, la transacción falla → el dato no se persiste en estado inconsistente con el audit.

2. **Daemon `bauth-reactor`** (WAL logical decoding, fuera de la transacción): consume el WAL de `privilege_atom_grant`, ejecuta `DEL Redis bitmask:{tenant_id}:{user_id}` y emite CAEP `token_claims_change` a Kong. Este efecto es best-effort y desacoplado: el dato ya fue persistido en BD independientemente de si Redis está disponible.

**Razón de la separación:** meter Redis/CAEP en el trigger hace que un fallo de Redis provoque rollback del INSERT en BD — el grant no se persiste aunque el admin lo aprobó. El WAL garantiza entrega-al-menos-una-vez fuera de la transacción.

---

## G-02 · Cadena de precedencia DENY ✅ CERRADO

**Problema original:** cuatro fuentes de DENY pueden competir sobre el mismo átomo para el mismo usuario sin una regla de resolución definida.

**Respuesta: la resolución es responsabilidad de AtomLang, no del DDL.**

El DDL no codifica reglas de precedencia. AtomLang resuelve los conflictos a través de su `combining_algorithm` y la jerarquía de `Subject` kinds. El árbol `idn_roles_template` hace todo visible — la organización del árbol hace que los conflictos sean adyacentes y fácilmente identificables por el operador.

### Algoritmo de resolución de conflictos AtomLang (G-02)

Cuando AtomLang encuentra dos átomos que comparten la misma clave estructural (mismo `atom_id` + misma `condition`), aplica un proceso de normalización en dos pasos:

```
PASO 1 — Normalización por estructura (strip effect + strip set/userset)
  Átomo A: tryton.ventas.pagar · monto<1000 · set(cajero)   · effect=NO
  Átomo B: tryton.ventas.pagar · monto<1000 · userset(juan) · effect=SI

  Clave normalizada A: "tryton.ventas.pagar · monto<1000"
  Clave normalizada B: "tryton.ventas.pagar · monto<1000"

  clave(A) AND clave(B) == misma clave → mismo átomo en distinto contexto de sujeto

PASO 2 — Resolución por jerarquía de Subject (strip effect, mantener sujeto)
  ¿Existe USERSET o USER para el usuario actual?
    SÍ → ese effect es el resultado final (sujeto usuario gana sobre sujeto rol)
    NO → ¿Existe SET o ROL para algún rol del usuario actual?
           SÍ → ese effect es el resultado
           NO → effect del sujeto ANY (general)
```

**Jerarquía de Subject kinds (de mayor a menor precedencia):**

| Prioridad | Kind | Descripción |
|-----------|------|-------------|
| 1 | `userunset: Vec<String>` | Usuario explícitamente excluido de un USERSET. Veto absoluto. |
| 2 | `unset: Vec<String>` | Rol explícitamente excluido de un SET. Veto sobre el SET. |
| 3 | `USER { user_id }` | Override directo para un usuario específico |
| 4 | `USERSET { user_set_id }` | Aplica a un conjunto de usuarios |
| 5 | `SET { set_id }` | Aplica a un conjunto de roles |
| 6 | `ROL { role_id }` | Aplica a un rol específico |
| 7 | `ANY` | General — sin restricción de sujeto (piso base) |

**Nota:** `unset` y `userunset` son exclusiones, no efectos — no llevan `effect`. Solo indican que ese rol/usuario queda fuera del SET/USERSET aunque pertenezca a él.

### Caso G-02a — mismo átomo, mismo usuario, efectos contradictorios

```
Átomo A: tryton.ventas.pagar · monto<1000 · userset(juan) · effect=SI
Átomo B: tryton.ventas.pagar · monto<1000 · userset(juan) · effect=NO
```

Paso 1: misma clave normalizada → mismo átomo  
Paso 2: ambos tienen `USER/USERSET` para juan → **colisión en el mismo nivel**

Resolución: AtomLang emite error de compilación `ATOMC-E-CON-001: átomo duplicado con efectos contradictorios para el mismo sujeto`. El árbol visual hace que los dos nodos sean adyacentes (mismo nivel, mismo propósito) — el operador los identifica de inmediato y resuelve cuál es la intención correcta.

### Por qué G-02b no es gap

Condiciones distintas = `atom_id` distinto = `atom_position` distinta = bits distintos en el RolBitMask. Nunca colisionan por definición. `monto<1000` y `monto<1000·dia=LUN` son átomos independientes con posiciones independientes.

### Por qué G-02c no es gap

Si dos átomos `ANY` tienen la misma clave normalizada y efectos opuestos, el `combining_algorithm` del `RawPolicy` los resuelve (DenyOverrides / PermitOverrides / etc.). No hay ambigüedad — la política declara su algoritmo de combinación.

### Por qué G-02d no es gap

AtomLang distingue sujeto de rol (`ROL`, `SET`, `unset`) de sujeto de usuario (`USER`, `USERSET`, `userunset`). La jerarquía de la tabla anterior define quién gana. **Ver especificación de extensión:** `A.65.02.02_ATOMLANG-EXTENSION-USER-SUBJECT.md`

---

## G-03 · Punto de enforcement de SoD ✅ CERRADO

**Problema original:** ¿en qué momento se detecta que dos átomos son mutuamente excluyentes?

**Respuesta: el enforcement es en la BD en tiempo de INSERT (PAP), a través de dos tablas de validación — catálogo de verbos y matriz de conflictividad — consultadas por un trigger en `privilege_atom_grant`.**

### Doctrina de las dos tablas

El SoD no se codifica como lógica de aplicación ni como regla hardcodeada. Se expresa como **datos** en dos tablas de catálogo. Ambas son tablas de **validación exclusivamente** — no estructuran átomos, no participan en la construcción del RolBitMask, no son consultadas en runtime de autenticación.

> **ADVERTENCIA PARA EL PROGRAMADOR:**
> `privilege_verb` y `privilege_verb_conflict` existen únicamente como guardianes de integridad.
> Su único rol es responder: "¿es válido usar este verbo?" y "¿pueden coexistir estos dos verbos
> para el mismo usuario?".
> NO son el origen de la estructura de un átomo. La estructura del átomo viene del árbol
> `idn_roles_template`. NO vincules estas tablas al motor de evaluación BitMask ni al PDP.

### DDL — Tabla 1: privilege_verb (catálogo de verbos válidos)

```sql
-- ─────────────────────────────────────────────────────────────────────────────
-- PROPÓSITO ÚNICO: registrar qué verbos existen y son válidos en el sistema.
--
-- Esta tabla es una LISTA DE VALIDACIÓN — no define la estructura de un átomo,
-- no participa en la construcción del RolBitMask, no se consulta en runtime
-- de autenticación ni en el PDP. Su único rol es responder: "¿existe este verbo?"
--
-- CUÁNDO SE CONSULTA:
--   · CRUD de idn_roles_template: FK verb_id impide usar un verbo no registrado.
--   · CRUD de privilege_verb_conflict: FK verb_a/verb_b impiden referenciar
--     verbos inexistentes en la tabla de conflictos.
--
-- CUÁNDO NO SE CONSULTA:
--   · En autenticación, en el PDP, en Kong, en el motor BitMask.
--   · Nunca en runtime — solo en operaciones de administración del árbol.
--
-- QUIÉN LA MANTIENE:
--   · Seeds del sistema: verbos base universales (create, read, update, delete,
--     validate, approve, execute, export, archive, assign, delegate, certify...).
--   · El operador agrega verbos de dominio (ej: "facturar", "despachar") aquí
--     primero. Sin registro previo → no puede usarse en ningún átomo del árbol.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE bauth.privilege_verb (
    verb_id     text        NOT NULL,
    description text        NOT NULL,
    is_active   boolean     NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  text        NOT NULL,
    CONSTRAINT privilege_verb_pkey PRIMARY KEY (verb_id),
    -- snake_case obligatorio: letras minúsculas, números, guion bajo
    CONSTRAINT chk_pv_verb_id_format CHECK (verb_id ~ '^[a-z][a-z0-9_]*$')
);
```

### DDL — Tabla 2: privilege_verb_conflict (matriz de conflictividad entre verbos)

```sql
-- ─────────────────────────────────────────────────────────────────────────────
-- PROPÓSITO ÚNICO: declarar qué pares de verbos son mutuamente excluyentes
-- (SoD) o afines para el mismo usuario.
--
-- Esta tabla es la MATRIZ DE VALIDACIÓN DE SoD — no define ni estructura
-- átomos, no participa en el BitMask, no se consulta en autenticación.
-- Su único rol es responder: "¿pueden coexistir estos dos verbos para
-- el mismo usuario?"
--
-- La relación es SIMÉTRICA por diseño: si (create, validate) es conflicto,
-- no hace falta registrar (validate, create) — el CHECK (verb_a < verb_b)
-- garantiza que cada par se almacena una sola vez en orden alfabético.
-- El trigger de SoD consulta en ambas direcciones.
--
-- CUÁNDO SE CONSULTA:
--   · Trigger fn_check_sod_on_grant: en cada INSERT en privilege_atom_grant,
--     verifica que el verbo del nuevo átomo no conflictúe con verbos que
--     el usuario ya tiene activos.
--   · AtomLang (compilador): puede consultarla en tiempo de compilación
--     del árbol para advertir conflictos potenciales antes del INSERT.
--
-- CUÁNDO NO SE CONSULTA:
--   · En autenticación, PDP, Kong, BitMask engine — nunca en runtime.
--
-- TIPOS DE RELACIÓN:
--   SOD_ESTATICO  → conflicto siempre prohibido (ej: crear + aprobar)
--   SOD_DINAMICO  → conflicto prohibido solo en el mismo objeto/instancia
--   AFINIDAD      → verbos que típicamente se asignan juntos (no conflicto,
--                   solo sugerencia al admin — no genera rechazo)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE bauth.privilege_verb_conflict (
    verb_a      text        NOT NULL REFERENCES bauth.privilege_verb(verb_id),
    verb_b      text        NOT NULL REFERENCES bauth.privilege_verb(verb_id),
    conflict_type text      NOT NULL,
    description text        NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  text        NOT NULL,
    CONSTRAINT privilege_verb_conflict_pkey PRIMARY KEY (verb_a, verb_b),
    -- Un verbo no puede conflictuar consigo mismo
    CONSTRAINT chk_pvc_no_self_conflict CHECK (verb_a <> verb_b),
    -- Almacenar siempre en orden alfabético: elimina duplicados (A,B) y (B,A)
    CONSTRAINT chk_pvc_orden_alfabetico CHECK (verb_a < verb_b),
    CONSTRAINT chk_pvc_tipo CHECK (tipo IN ('SOD_ESTATICO','SOD_DINAMICO','AFINIDAD'))
);
```

### DDL — Tabla 2: enforcement en idn_roles_template (FK de validación)

```sql
-- El verb_id en nodos tipo='evaluacion' de idn_roles_template debe existir
-- en privilege_verb. Esta FK es el punto de control en el CRUD del árbol.
--
-- Un operador NO puede crear un átomo con verbo desconocido.
-- Si necesita un verbo nuevo, primero lo registra en privilege_verb.
-- Esta es la única relación entre privilege_verb e idn_roles_template.
-- No implica ninguna otra dependencia estructural entre ambas tablas.

-- Agregar columna verb_id al CREATE TABLE de idn_roles_template (§6.1 de A.65.02.01):
--
--   verb_id  text  NULL  REFERENCES bauth.privilege_verb(verb_id),
--   CONSTRAINT chk_irt_verb_solo_evaluacion CHECK (
--       (tipo = 'evaluacion' AND verb_id IS NOT NULL)
--       OR (tipo <> 'evaluacion' AND verb_id IS NULL)
--   )
--
-- Solo los nodos tipo='evaluacion' tienen verb_id.
-- Los demás tipos (dominio, bloque, objeto, etc.) tienen verb_id = NULL.
```

### DDL — Trigger SoD en privilege_atom_grant

```sql
-- Cuando se intenta asignar un átomo a un usuario (INSERT en T-170),
-- este trigger verifica que el verbo del nuevo átomo no conflictúe
-- con verbos que el usuario ya tiene asignados y activos.
--
-- Si hay conflicto → ROLLBACK con mensaje descriptivo al admin.
-- Si no hay conflicto → el INSERT procede normalmente.

CREATE OR REPLACE FUNCTION bauth.fn_check_sod_on_grant()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_verb_nuevo        text;
    v_verb_existente    text;
    v_atom_existente    text;
BEGIN
    -- Solo verificar en asignaciones PERMIT activas con usuario específico
    IF NEW.access = false OR NEW.user_id IS NULL OR NEW.status <> 'ACTIVE' THEN
        RETURN NEW;
    END IF;

    -- Obtener el verbo del átomo que se está asignando
    SELECT verb_id INTO v_verb_nuevo
    FROM bauth.idn_roles_template
    WHERE id = NEW.id_atom AND tipo = 'evaluacion';

    -- Si el átomo no tiene verbo registrado, no hay SoD que verificar
    IF v_verb_nuevo IS NULL THEN
        RETURN NEW;
    END IF;

    -- Buscar si el usuario ya tiene activo algún átomo cuyo verbo
    -- esté declarado como conflicto del verbo nuevo
    SELECT irt.verb_id, irt.clave
    INTO v_verb_existente, v_atom_existente
    FROM bauth.privilege_atom_grant pag
    JOIN bauth.idn_roles_template irt ON irt.id = pag.id_atom
    WHERE pag.user_id    = NEW.user_id
      AND pag.tenant_id  = NEW.tenant_id
      AND pag.access     = true
      AND pag.status     = 'ACTIVE'
      AND irt.tipo       = 'evaluacion'
      AND irt.verb_id IS NOT NULL
      AND EXISTS (
          -- Consultar privilege_verb_conflict en ambas direcciones
          -- (la tabla almacena solo verb_a < verb_b en orden alfabético)
          SELECT 1 FROM bauth.privilege_verb_conflict pvc
          WHERE tipo IN ('SOD_ESTATICO','SOD_DINAMICO')
            AND (
                (pvc.verb_a = LEAST(v_verb_nuevo, irt.verb_id)
                 AND pvc.verb_b = GREATEST(v_verb_nuevo, irt.verb_id))
            )
      )
    LIMIT 1;

    IF FOUND THEN
        RAISE EXCEPTION
            'Violación SoD: el verbo "%" del átomo a asignar conflictúa con el verbo "%" '
            'del átomo "%" que el usuario ya tiene activo. '
            'Revise la matriz de conflictos en privilege_verb.',
            v_verb_nuevo, v_verb_existente, v_atom_existente;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_t170_sod_check
    BEFORE INSERT
    ON bauth.privilege_atom_grant
    FOR EACH ROW
    EXECUTE FUNCTION bauth.fn_check_sod_on_grant();
```

### Resumen de la solución

| Pregunta | Respuesta |
|----------|-----------|
| ¿Cuándo se verifica SoD? | En el INSERT de `privilege_atom_grant` (PAP — tiempo de asignación) |
| ¿Dónde vive la matriz de conflictos? | En `privilege_verb_conflict` (tabla relacional, FK nativas a `privilege_verb`) |
| ¿Cómo se evita el conflicto consigo mismo? | `CHECK (verb_a <> verb_b)` en `privilege_verb_conflict` |
| ¿Quién ejecuta el SoD? | Trigger `fn_check_sod_on_grant` en `privilege_atom_grant` |
| ¿`privilege_verb` participa en la construcción del BitMask? | **NO** — solo validación de escritura |
| ¿`privilege_verb` es consultada en autenticación? | **NO** — solo en CRUD del árbol y asignación de grants |
| ¿Cómo se agrega un verbo nuevo al sistema? | `INSERT INTO privilege_verb` primero, luego se puede usar en el árbol |

---

## G-04 · Obligaciones y step-up (RFC 9470) ✅ CERRADO

**Problema:** el átomo tiene `obligation: { required_loa: 'AAL2' }`. Dos diseños posibles e incompatibles:
- **Opción A:** el bit SE EMITE en el JWT con LoA actual; Kong ejecuta step-up antes de permitir el acceso si el LoA es insuficiente.
- **Opción B:** el bit NO SE EMITE hasta que el usuario alcance AAL2; tras re-autenticación se emite un JWT nuevo con el bit activo.

**Respuesta (Opción A — decisión completa en `SBOS-0XX-G04-LOA-AAL-OBLIGACIONES.md`):**

### Decisión: Opción A — bit se emite, Kong custodia la obligación

**El argumento decisivo no es de separación PAP/PDP/PEP** sino de *staleness del token*: la Opción B obliga a re-emitir el JWT completo en cada cambio de LoA, lo que puede producir dos JWTs válidos simultáneos con distintos "snapshots" de entitlement durante la ventana de transición. La Opción A separa correctamente: el bit es un hecho estático (¿existe el grant?), la obligación es una condición dinámica de contexto (¿se cumple el LoA ahora?).

**Principio clave: `current_loa` no puede vivir en el JWT.** Vive en la sesión activa (Redis, keyed por `session_id` — no por `user_id` — para soportar sesiones concurrentes del mismo usuario en distintos niveles). Kong lo consulta en cada request. bAuth nunca emite un claim `loa` / `acr` / `assurance_level` en el JWT — el schema del token prohíbe esos campos.

### Impacto DDL

**T-171 `privilege_resource_atom`** — nueva columna `obligation JSONB NULL`:
```sql
-- NULL = sin obligación; bit=1 es suficiente.
-- NOT NULL = Kong verifica obligation.required_loa contra sesión antes de PERMIT.
-- bit=1 en JWT NO implica autorización final cuando obligation IS NOT NULL.
obligation   JSONB    NULL,
CONSTRAINT chk_pra_obligation_schema CHECK (
    obligation IS NULL
    OR (
        jsonb_typeof(obligation) = 'object'
        AND obligation ? 'required_loa'
        AND (obligation->>'required_loa') IN ('AAL1','AAL2','AAL3')
    )
)
```
DDL completo en `A.65.02.01_ANEXO-OPERACION-TABLAS-DECISIONES-v1.0.md` §8 (v1.2.0+).

**T-176 `bauth.privilege_assurance_audit`** — nueva tabla, poblada por Kong:
```sql
CREATE TABLE bauth.privilege_assurance_audit (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    grant_id       UUID NOT NULL REFERENCES bauth.privilege_atom_grant(id),
    resource_id    TEXT NOT NULL,
    required_loa   TEXT NOT NULL,
    presented_loa  TEXT NOT NULL,
    outcome        TEXT NOT NULL CHECK (outcome IN ('PERMIT','STEP_UP_REQUIRED','DENIED')),
    session_id     UUID NOT NULL,
    evaluated_by   TEXT NOT NULL DEFAULT 'kong-pep',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_paa_grant   ON bauth.privilege_assurance_audit (grant_id);
CREATE INDEX idx_paa_session ON bauth.privilege_assurance_audit (session_id);
```
Separación limpia: T-170b audita *qué se otorgó y cuándo cambió*; T-176 audita *cómo se ejerció lo otorgado* (volumen por request, no por cambio de grant → candidata a particionamiento por fecha).

### Flujo operativo completo
```
1. Grant en T-170: access=true, status=ACTIVE
2. JWT emitido (AAL1): bit N = 1  [grant existe, LoA no importa en emisión]
3. Kong (PEP) intercepta request al recurso:
   a. Bit N = 1 en RolBitMask → grant existe ✓
   b. T-171.obligation = {"required_loa": "AAL2"}
   c. Redis[session_id].current_loa = "AAL1"
   d. AAL1 < AAL2 → insertar T-176 (outcome=STEP_UP_REQUIRED) → redirect step-up
4. Usuario completa 2FA → Redis actualiza current_loa = "AAL2" (mismo JWT, sin re-emisión)
5. Kong re-evalúa: bit N = 1, current_loa = AAL2 ≥ AAL2 → T-176 (outcome=PERMIT) → PASS
```

### Riesgos y mitigaciones (ver §4 del documento de decisión)

| Riesgo | Mitigación |
|--------|-----------|
| `current_loa` se introduce en el JWT por comodidad | Schema del JWT prohibe claims de LoA; test de contrato en CI falla el build si aparecen |
| Servicio de SBOS lee bit directamente sin pasar por Kong | Linkerd NetworkPolicy: solo Kong puede alcanzar recursos con `obligation IS NOT NULL` |
| SDK expone `hasPermission()` que confunde bit con autorización final | SDK devuelve "grant existe", no "permitido"; excluye veredicto binario para átomos con obligación |
| Bypass no detectado pese a capas 1–3 | Job periódico cruza T-176 vs logs del recurso: accesos sin evaluación Kong → alerta |

### Trabajo de diseño abierto (§5 del documento de decisión)

7 ítems especificados en `SBOS-0XX-G04-LOA-AAL-OBLIGACIONES.md §5` — pendientes de addenda al mismo documento: diseño Kong plugin, evento CAEP step-up, NetworkPolicy Linkerd, contrato SDK, lint CI, job de auditoría cruzada, política de retención T-176.

---

## G-05 · Secuencia de arranque (bootstrap) ✅ CERRADO

**Problema:** el orden de inicialización debe ser exacto para no corromper el catálogo de átomos. El gap era: ¿dónde vive el contador `next_position`?

**Respuesta (SBOS-0XX · A.65.02.01 §4.3 y §6.1 v1.2.0):**

El contador vive en la SEQUENCE PostgreSQL `bauth.roles_atom_position_sequential`. No hay `MAX() + 1` manual.

Flujo de bootstrap corregido:
1. Leer semillas del catálogo de átomos (YAML/JSON)
2. Para cada átomo por registrar: `INSERT INTO idn_roles_template (..., atom_position = nextval('bauth.roles_atom_position_sequential'))` con `ON CONFLICT (parent_id, clave) DO NOTHING`
   - Si el nodo ya existe → `DO NOTHING` (la posición ya está fijada en T-162; no se recalcula)
   - Si es nuevo → la SEQUENCE asigna la siguiente posición de forma atómica
3. Construir HashMap en memoria `id_atom → atom_position` leyendo T-162 `WHERE tipo='evaluacion' AND activo=true`
4. Cargar privilege_resource_atom en el plugin Kong

**No hay `MAX() + 1`:** la SEQUENCE garantiza unicidad bajo cualquier nivel de concurrencia. El código de bootstrap nunca toca la generación de posiciones — solo hace `nextval()` via SQL.

---

## G-06 · `tenant_id` y aislamiento multi-tenant ✅ CERRADO

**Problema original:** T-162 se asumía global. Sin `tenant_id`, un PERMIT del tenant A podría afectar al tenant B.

**Respuesta:**

### Decisión arquitectónica — el árbol es per-tenant

T-162 (`idn_roles_template`) **no es global** — es per-tenant. Cada empresa tiene su propio árbol. Esto hace que el aislamiento sea estructural: un átomo del tenant ABC es una fila con `tenant_id=UUID-abc` en T-162; el mismo átomo en el tenant XYZ es una fila distinta con `tenant_id=UUID-xyz`. No pueden mezclarse por construcción.

### Regla de bootstrap

Al crear un tenant nuevo se copia el árbol del tenant plantilla con esta regla:

| Tipo de nodo | ¿Se copia? | Resultado |
|---|---|---|
| `dominio`, `bloque`, `objeto`, `lista`, `politica`, `regla`, `atributo`, `enumerado`, `diagnostico` | ✅ SÍ | La empresa recibe la estructura completa incluyendo zonas de negocio (ej: `zona_logical_tryton`) |
| `evaluacion` | ❌ NO | Sin átomos pre-cargados — la empresa define los suyos |

El administrador de cada empresa encuentra las zonas de negocio listas (la estructura de Tryton, la de RRHH, la de Finanzas) pero vacías de permisos. Llena los átomos según sus propios procesos y roles.

Los `parent_id` se remapean a los UUIDs de la nueva copia del árbol durante el bootstrap.

### SU — tenant reservado del sistema

El tier SU no usa `tenant_id = NULL`. Usa un UUID de tenant reservado del sistema fijo de bootstrap. Su capacidad de cruzar tenants es una propiedad de su autorización, no un NULL en la base de datos.

### Tablas afectadas (5)

| Tabla | Cambio | Razón |
|---|---|---|
| T-162 `idn_roles_template` | `tenant_id uuid NOT NULL` · UNIQUE `(tenant_id, parent_id, clave)` | El árbol es per-tenant; sin tenant_id los nodos raíz colisionan |
| T-170 `privilege_atom_grant` | `tenant_id uuid NULL` → `NOT NULL` | SU usa UUID reservado, no NULL |
| T-171 `privilege_resource_atom` | `tenant_id uuid NOT NULL` · UNIQUE `(tenant_id, tipo_protocolo, recurso, operacion)` | El mismo endpoint puede mapear a átomos distintos por tenant |
| T-172 `privilege_delegation` | `tenant_id uuid NOT NULL` | Delegaciones siempre dentro de un tenant |
| T-173 `privilege_override` | `tenant_id uuid NOT NULL` | Overrides siempre dentro de un tenant |

### Por qué T-174, T-175, T-170b y T-176 no necesitan tenant_id

- **T-174 `privilege_verb`** y **T-175 `privilege_verb_conflict`**: catálogos globales — los verbos son universales como un diccionario
- **T-170b `privilege_atom_audit`** y **T-176 `privilege_assurance_audit`**: alcanzan el tenant a través de `grant_id → T-170.tenant_id`; no necesitan desnormalizar

DDL completo en `A.65.02.01_ANEXO-OPERACION-TABLAS-DECISIONES-v1.0.md` v1.5.0 (§6.1 T-162, §6.2 T-170, §6.5 T-172, §6.6 T-173, §8 T-171).

---

## G-07 · Asignaciones temporales ✅ CERRADO

**Problema original:** T-170 no tenía `valid_from`/`valid_until` para acceso temporal JIT.

**Respuesta:**

### Resolución — separación BD / dominio temporal

Las columnas ya existen en T-170 desde su DDL canónico:

```sql
valid_from     timestamptz NULL,   -- NULL = sin límite de inicio
valid_until    timestamptz NULL,   -- NULL = sin límite de fin
CONSTRAINT chk_pag_valid_range
    CHECK (valid_from IS NULL OR valid_until IS NULL OR valid_from < valid_until)
```

El índice de expiración (G-09) ya cubre el job de alertas:
```sql
CREATE INDEX idx_pag_valid_until ON privilege_atom_grant (valid_until)
WHERE valid_until IS NOT NULL AND status = 'ACTIVE';
```

La evaluación de si un grant es válido **ahora** — incluyendo solapamientos, pre-agendado, cobertura de vacaciones y elevated access JIT — es responsabilidad del **dominio temporal del PolicyEngine**, no de constraints de BD. Duplicarlo como EXCLUDE GIST en la BD crearía una segunda fuente de verdad que puede contradecir al dominio y bloquear casos que el evaluador temporal sí permite.

| Responsabilidad | Quién la cumple |
|---|---|
| Almacenar rango de validez | T-170 `valid_from` / `valid_until` ✅ |
| Prevenir rango inconsistente (from > until) | `chk_pag_valid_range` CHECK ✅ |
| Evaluar si el grant es válido ahora | Dominio temporal del PolicyEngine |
| Pre-agendado, solapamientos, cobertura | Dominio temporal del PolicyEngine |

La restricción `WITHOUT OVERLAPS` de PG18 **no se implementa** — es innecesaria dado que el dominio temporal ya maneja esa lógica.

### Observación — integración con bloque de Calendario (contrato especificado, implementación futura)

La validación temporal completa de un grant requiere más que `now() BETWEEN valid_from AND valid_until`. En contextos empresariales es necesario verificar contra:

- **Horarios laborales**: un grant "válido lunes a viernes 08:00-18:00" no puede evaluarse solo con timestamps
- **Feriados nacionales/regionales**: acceso bloqueado en días no laborables aunque esté dentro del rango
- **Calendarios de empresa**: feriados internos, periodos de cierre, turnos especiales

Esta lógica vive en el **bloque de Calendario** (`bcalendar` — daemon SBOS con su propio Unix socket `/run/bos/bcalendar.sock`). La integración es **trabajo futuro activado cuando bcalendar esté desplegado**, pero su contrato queda especificado aquí para que el dominio temporal de bAuth lo implemente sin decisiones arquitectónicas adicionales.

#### Contrato de integración bAuth ↔ bcalendar

El dominio temporal de bAuth invoca dos métodos JSON-RPC de bcalendar **antes de emitir el veredicto temporal** de un grant:

```
bAuth temporal domain evaluation:
  1. now() BETWEEN valid_from AND valid_until         → si false → DENY (ya existente)
  2. bcalendar.is_working_time(tenant_id, now(), schedule_id)
     → {working: bool, next_window: timestamp | null}
     Si working = false → DENY temporal (fuera de horario laboral)
  3. bcalendar.is_holiday(tenant_id, today(), calendar_id)
     → {holiday: bool, holiday_name: string | null}
     Si holiday = true → DENY temporal (feriado)
  4. Todos los checks pasan → PERMIT temporal
```

**Métodos JSON-RPC de bcalendar (contrato desde bAuth):**

```json
// Verifica si el timestamp está dentro del horario laboral de un schedule
{
  "jsonrpc": "2.0",
  "method": "bcalendar.is_working_time",
  "params": {
    "tenant_id":   "uuid del tenant",
    "timestamp":   "2026-07-20T14:30:00Z",
    "schedule_id": "uuid del schedule laboral del tenant"
  },
  "id": "ctx-id-aqui"
}
// Respuesta:
{
  "result": {
    "working":      true,
    "next_window":  "2026-07-21T08:00:00Z"  // próxima apertura si working=false
  }
}

// Verifica si la fecha es feriado en el calendario del tenant
{
  "jsonrpc": "2.0",
  "method": "bcalendar.is_holiday",
  "params": {
    "tenant_id":   "uuid del tenant",
    "date":        "2026-07-20",
    "calendar_id": "uuid del calendario de feriados del tenant"
  },
  "id": "ctx-id-aqui"
}
// Respuesta:
{
  "result": {
    "holiday":      false,
    "holiday_name": null
  }
}
```

#### DDL: columna `schedule_id` en T-170 (a agregar al integrar bcalendar)

Cuando bcalendar esté disponible, T-170 (`privilege_atom_grant`) recibe una columna opcional
que vincula el grant a un schedule laboral y a un calendario de feriados:

```sql
-- Agregar al CREATE TABLE bauth.privilege_atom_grant:
schedule_id  uuid  NULL,
-- REFERENCES bcalendar.schedules(id) — FK cross-schema, activada al integrar bcalendar
-- NULL = sin restricción de horario (solo valid_from/valid_until)
-- NOT NULL = el grant solo es válido dentro del horario del schedule referenciado
```

El `calendar_id` (feriados) se lee del schedule referenciado — no es un campo separado en
T-170. Un schedule encapsula tanto los horarios como el calendario de feriados del tenant.

#### Comportamiento ante fallo de bcalendar (contingencia)

El dominio temporal aplica **fail-secure**: si bcalendar no está disponible (timeout, socket
cerrado), el veredicto temporal es DENY por defecto para grants con `schedule_id IS NOT NULL`.
Grants sin `schedule_id` no se ven afectados — solo evalúan el rango de timestamps.

```rust
match bcalendar_client.is_working_time(...).await {
    Ok(resp)  => resp.working,
    Err(_)    => false,  // fail-secure: DENY si bcalendar no responde
}
```

#### Impacto en DDL de esta sesión

Ninguno — la columna `schedule_id` y la FK a bcalendar se agregan cuando bcalendar esté
desplegado. El contrato de integración queda especificado aquí para guiar esa implementación
sin necesidad de nueva toma de decisiones arquitectónicas.

---

## G-08 · Límite de profundidad en delegación (T-172) ✅ CERRADO

**Problema original:** sin `depth_limit` y `chain_root`, una cadena A→B→C→D ilimitada permite escalada de privilegios indirecta.

**Respuesta:**

### El problema no existe en el modelo real de bAuth

El problema de cadenas ilimitadas asumía un modelo de "delegación entre usuarios" — A delega directamente a B, B puede re-delegar a C. En bAuth la delegación no funciona así.

**La delegación en bAuth es asignación de rol auxiliar por un administrador:**

```
A (gerente) se va de vacaciones
→ Admin asigna a B el rol auxiliar "aprobador_pagos" (mismo tier o adyacente)
  con valid_from/valid_until en T-170
→ El engine merge_roles combina roles de B + rol auxiliar (AND/OR según config)
→ RolBitMask resultante activo durante el período
→ B no puede re-propagar — no tiene autoridad de admin
```

**Por qué la cadena ilimitada es imposible:**
- Solo el admin puede asignar roles — el usuario que recibe no puede re-propagar
- Los roles auxiliares son del mismo tier o adyacente — el portero no recibe el rol de gerente general
- En la práctica un usuario ejerce máximo 2 roles simultáneos → merge trivial para el engine

### Rediseño de T-172 — solo auditoría y trazabilidad

T-172 se redesigna completamente: eliminados `depth_limit`, `chain_root`, `delegator_id`, `delegatee_id`, FK a átomos. Queda como registro liviano de contexto:

| Campo | Propósito |
|---|---|
| `tenant_id` | Ámbito (G-06) |
| `role_id` | Rol auxiliar asignado |
| `assignee_id` | Usuario que recibe |
| `assigned_by` | Admin que autorizó |
| `reason` | Justificación obligatoria |
| `valid_from` / `valid_until` | Período informativo |
| `status` | ACTIVE / EXPIRED / REVOKED |

La vigencia real está en los átomos del rol en T-170 — T-172 solo responde "¿por qué y quién autorizó esta asignación temporal?"

DDL completo en `A.65.02.01_ANEXO-OPERACION-TABLAS-DECISIONES-v1.0.md` §6.5.

### Observación — widget de delegación en bAuth Desktop (contrato especificado, implementación futura)

Las asignaciones temporales de rol deben originarse desde el Dashboard de bAuth para garantizar que cada asignación genere simultáneamente:
- Su registro de auditoría en T-172 (`privilege_delegation`): quién, a quién, por qué, hasta cuándo
- Sus grants reales en T-170 (`privilege_atom_grant`): un row por átomo del rol asignado con `valid_from`/`valid_until`

Sin el widget, ambos registros pueden quedar desincronizados. El contrato completo queda especificado aquí.

#### Método JSON-RPC del backend

```json
// bAuth expone el siguiente método para la delegación atómica:
{
  "jsonrpc": "2.0",
  "method": "bauth.role.delegate_to_user",
  "params": {
    "tenant_id":   "uuid",
    "role_id":     "uuid del rol auxiliar a asignar",
    "assignee_id": "uuid del usuario destinatario",
    "reason":      "Texto obligatorio — justificación de la delegación (mín. 20 chars)",
    "valid_from":  "2026-07-20T08:00:00Z",
    "valid_until": "2026-07-27T18:00:00Z",
    "ctx_id":      "ctx-id-de-la-sesión-del-admin"
  },
  "id": "req-id"
}

// Respuesta exitosa:
{
  "result": {
    "delegation_id": "uuid de T-172",
    "atoms_granted": 12,
    "valid_from":    "2026-07-20T08:00:00Z",
    "valid_until":   "2026-07-27T18:00:00Z"
  }
}
```

El método ejecuta en una **sola transacción PostgreSQL**:
1. Valida que el caller es admin del tenant (tier SYS o BIZ_N1)
2. Valida compatibilidad de tier del rol auxiliar (mismo tier o adyacente — no escala privilegios)
3. `INSERT INTO bauth.privilege_delegation` (T-172) con `reason` obligatorio
4. Por cada átomo del rol: `INSERT INTO bauth.privilege_atom_grant` (T-170) con `valid_from`/`valid_until`
5. `COMMIT` → WAL → CAEP `token_claims_change` al usuario asignado → JWT invalidado

Si algún paso falla, la transacción completa hace `ROLLBACK` — nunca quedan T-172 y T-170 parcialmente escritos.

#### Componentes del widget en bAuth Desktop (Flutter/shadcn_flutter)

```
Pantalla: "Delegación de Rol a Usuario"
│
├── UserSearchField      — búsqueda por nombre/email; autocomplete contra bauth.idn_user
│                          muestra avatar, nombre completo y tier actual
├── RoleSelector         — dropdown de roles auxiliares disponibles
│                          filtrado: solo roles del mismo tier o adyacente al usuario destino
│                          muestra: nombre del rol, tier, cantidad de átomos
├── DateRangePicker      — valid_from (default: ahora) / valid_until (obligatorio, futuro)
│                          límite máximo: 90 días (configurable por tenant en idn_tier_policy)
├── ReasonTextArea       — campo obligatorio, mínimo 20 caracteres
│                          placeholder: "Describe por qué se realiza esta delegación temporal"
└── ConfirmButton        — activo solo cuando todos los campos son válidos
                           llama a bauth.role.delegate_to_user
                           muestra spinner durante la transacción
                           al éxito: SuccessDialog con delegation_id y resumen
                           en error: ErrorDialog con mensaje descriptivo en español
```

#### Ubicación en el árbol de navegación del Desktop

```
Dashboard bAuth
└── Gestión de Identidades
    └── Delegación de Roles  ← nueva pantalla
        ├── Delegaciones activas (tabla con valid_until countdown)
        └── Nueva delegación (el widget descrito)
```

#### Regla de negocio en el widget

El widget no permite delegación de roles de tier superior al del usuario destinatario. La validación ocurre en el frontend (deshabilita opciones inválidas en `RoleSelector`) **y** en el backend (el método JSON-RPC rechaza con error si la regla se viola). La doble validación evita bypass por llamada directa al socket.

---

## G-09 · Índices para access certification y análisis what-if (IGA) ✅ CERRADO

**Problema original:** T-170 carecía de índices para las operaciones IGA más frecuentes en un sistema IAM Enterprise.

**Respuesta:**

### Principio arquitectónico — modelo per-user (no por rol)

`privilege_atom_grant` tiene **una fila por usuario por átomo** — no existen filas "de rol" que cubran a grupos de usuarios. Cuando AtomLang asigna un átomo a un SET de usuarios, la operación PAP crea N filas individuales, una por usuario:

```sql
-- SET cajero = { María, Juan, Carlos } → asignar átomo tryton.ventas.aprobar

INSERT INTO privilege_atom_grant (id_atom, atom_position, user_id, access, status, ...)
VALUES
  ('UUID-atomo', 7, 'UUID-maria',  true, 'ACTIVE', ...),
  ('UUID-atomo', 7, 'UUID-juan',   true, 'ACTIVE', ...),
  ('UUID-atomo', 7, 'UUID-carlos', true, 'ACTIVE', ...);
```

Cuando se aplica **UNSET** a un usuario individual (excluirlo sin tocar al resto):

```sql
-- unset Juan del SET cajero para el átomo X → solo cambia la fila de Juan

UPDATE privilege_atom_grant
   SET access = false          -- o status = 'INACTIVE' según la semántica del caso
WHERE id_atom = 'UUID-atomo'
  AND user_id = 'UUID-juan';
-- Las filas de María y Carlos no se tocan
```

Esta granularidad es la que hace que SET/UNSET no tenga efectos colaterales: cada usuario tiene su propia fila, y modificar una no afecta a las demás. El modelo es deliberadamente explícito — no hay "herencia implícita de rol" en T-170; todo está materializado como grants individuales.

### Las cuatro direcciones de consulta IGA

| # | Dirección | Caso real | Estado |
|---|-----------|-----------|--------|
| 1 | Átomo → usuarios | "¿quién tiene activo el átomo X?" · what-if antes de revocar · lista para certificación | ✅ `idx_pag_atom_access` (ya existía) |
| 2 | Usuario → sus átomos | Offboarding de María Flores: listar todos sus grants para revocarlos · revisión NIST AC-2 | ✅ `idx_pag_user_entitlement` (nuevo) |
| 3 | Tenant → todos sus grants | Campaña de recertificación trimestral ISO 27001: todos los accesos de todos los usuarios del tenant ABC para firmar aprobación | ✅ `idx_pag_tenant_sweep` (nuevo) |
| 4 | Grants temporales próximos a vencer | Consultor externo con acceso hasta el 31-jul · job de alerta 7 días antes · NIST AC-2(6) | ✅ `idx_pag_valid_until` (nuevo) |

### DDL — índices nuevos en T-170

```sql
-- Dirección 2: usuario → todos sus átomos activos
-- atom_position incluida para reconstruir RolBitMask sin join adicional a T-162
CREATE INDEX idx_pag_user_entitlement
    ON bauth.privilege_atom_grant (user_id, atom_position)
    WHERE user_id IS NOT NULL AND access = true AND status = 'ACTIVE';

-- Dirección 3: tenant → todos sus grants activos (campaña de certificación)
-- user_id incluido para agrupar por usuario en la UI sin segundo join
CREATE INDEX idx_pag_tenant_sweep
    ON bauth.privilege_atom_grant (tenant_id, user_id)
    WHERE access = true AND status = 'ACTIVE';

-- Dirección 4: grants temporales próximos a vencer (NIST AC-2(6))
-- Índice parcial: excluye ~95% de grants permanentes (valid_until IS NULL)
CREATE INDEX idx_pag_valid_until
    ON bauth.privilege_atom_grant (valid_until)
    WHERE valid_until IS NOT NULL AND status = 'ACTIVE';
```

Los tres son **índices parciales** (`WHERE` clause): solo indexan el subconjunto relevante de filas activas, no el historial de DELETED/INACTIVE/SUSPENDED. Esto mantiene su tamaño reducido incluso cuando T-170 crece con el historial de cambios de grants.

### Corrección al análisis previo

En el análisis inicial de G-09 se asumió erróneamente que los grants eran mayoritariamente a nivel de rol (`user_id IS NULL`). La realidad del modelo es la opuesta: **todos los grants operacionales tienen `user_id` asignado**. El `user_id IS NULL` aplica únicamente a átomos de los tiers `SU` y `EMERGENCY` que son genuinamente cross-tenant. La operación SET/UNSET de AtomLang no crea grants "de grupo" — materializa grants individuales por usuario, que es precisamente lo que hace al modelo auditable y a las operaciones IGA predecibles.

DDL completo en `A.65.02.01_ANEXO-OPERACION-TABLAS-DECISIONES-v1.0.md` §6.2.

### § Suplemento G-09-A — Flujo de evaluación y actualización de índices (modelo 5 columnas)

El modelo de 5 columnas (`effect`, `general`, `local`, `access`, `reassess`) definido en G-12
reemplaza el modelo de 3 estados (access=NULL). Esto actualiza la semántica de los índices
de G-09 y simplifica la reconstrucción del BitMask al eliminar el JOIN a T-162.

---

#### Flujo de evaluación del PDP para un grant

```
ENTRADA: una fila de privilege_atom_grant con las 5 columnas del modelo

PASO 1 — Determinar quién manda (¿árbol o grant?)
  si grant.general = true  (local = false):
      valor_activo = grant.effect    ← árbol decide (efecto sincronizado por trigger)
  sino (general = false, local = true):
      valor_activo = grant.access    ← grant decide (valor editado por el operador)

PASO 2 — Evaluar efecto final del átomo
  si valor_is_active = false  → DENY — fin. reassess irrelevante.
  si valor_is_active = true   → PERMIT — continuar al Paso 3.

PASO 3 — Evaluar elegibilidad reactiva (forma compacta)
  si local = false:   evaluar:  effect AND reassess
  si local = true:    evaluar:  access AND reassess

  En ambos casos valor_is_active = true ya (Paso 2),
  por lo que el AND resulta directamente en grant.reassess
  (o tenant_default si reassess IS NULL).
```

El AND del Paso 3 **activa la reevaluación CAEP** únicamente cuando el valor activo
es `true` y `reassess` es `true`. Si el resultado es DENY, el AND es irrelevante —
la reevaluación nunca se ejecuta sobre un veto activo.

---

#### Reconstrucción del BitMask (consulta SQL unificada)

Con el modelo 5 columnas **no hay JOIN a T-162** — la columna `effect` ya contiene el
valor del árbol sincronizado por trigger desde `idn_roles_template`. La reconstrucción
es una sola query sin join adicional:

```sql
-- Reconstrucción del RolBitMask para un usuario
-- Incluye todos los grants donde el resultado final del átomo es PERMIT
SELECT atom_position
FROM   bauth.privilege_atom_grant
WHERE  user_id   = $1
  AND  tenant_id = $2
  AND  status    = 'ACTIVE'
  AND  (
      (general = true  AND effect = true)   -- árbol dice PERMIT
      OR
      (general = false AND access = true)   -- grant dice PERMIT
  )
ORDER BY atom_position;
```

Los grants con `general=false AND access=false` (DENY explícito del operador) no entran
al BitMask. Su efecto es negar el bit, implícito por ausencia en el modelo AND del bitmask.

---

#### Índices existentes — semántica actualizada

| Índice | Antes (modelo 3 estados) | Ahora (modelo 5 columnas) |
|--------|--------------------------|--------------------------|
| `idx_pag_atom_access` | Filtraba `access=true/false/NULL` | Reemplazar por filtro compuesto `(general=true AND effect=true) OR (general=false AND access=true)` |
| `idx_pag_user_entitlement` | `access = true AND status='ACTIVE'` | Filtro compuesto — ver DDL actualizado |
| `idx_pag_tenant_sweep` | `access = true AND status='ACTIVE'` | Filtro compuesto — ver DDL actualizado |
| `idx_pag_valid_until` | `valid_until IS NOT NULL` | Sin cambio — independiente del modelo de evaluación |
| `idx_pag_user_deferred` | `access IS NULL` (diferidos al árbol) | **Eliminado** — `access` siempre es NOT NULL en el nuevo modelo |

---

#### DDL — índices actualizados para el modelo 5 columnas

```sql
-- Dirección 2 actualizada: usuario → sus átomos con resultado PERMIT
-- Cubre árbol-manda (general=true, effect=true) y grant-manda (general=false, access=true)
DROP INDEX IF EXISTS bauth.idx_pag_user_entitlement;

CREATE INDEX idx_pag_user_entitlement
    ON bauth.privilege_atom_grant (user_id, atom_position)
    WHERE user_id IS NOT NULL
      AND status  = 'ACTIVE'
      AND (
          (general = true  AND effect = true)
          OR
          (general = false AND access = true)
      );

COMMENT ON INDEX bauth.idx_pag_user_entitlement IS
    'Dirección 2 IGA: usuario → átomos activos con resultado PERMIT. '
    'Cubre modo árbol-manda y grant-manda. '
    'Usado en offboarding, revisión NIST AC-2 y reconstrucción BitMask.';

-- Dirección 3 actualizada: tenant → todos sus grants PERMIT (campaña de certificación)
DROP INDEX IF EXISTS bauth.idx_pag_tenant_sweep;

CREATE INDEX idx_pag_tenant_sweep
    ON bauth.privilege_atom_grant (tenant_id, user_id)
    WHERE status = 'ACTIVE'
      AND (
          (general = true  AND effect = true)
          OR
          (general = false AND access = true)
      );

COMMENT ON INDEX bauth.idx_pag_tenant_sweep IS
    'Dirección 3 IGA: tenant → todos los grants activos con resultado PERMIT. '
    'Campaña de recertificación trimestral ISO 27001.';

-- Dirección 4: idx_pag_valid_until — sin cambio.

-- Dirección 5: idx_pag_reassess_eligible — definido en G-12 § 5.
-- Su filtro también usa el patrón compuesto (general=true AND effect=true) OR (...).

-- idx_pag_user_deferred: ELIMINADO.
-- En el modelo 5 columnas access siempre es NOT NULL.
-- El estado "árbol manda" se expresa con general=true, capturado
-- por idx_pag_user_entitlement cuando effect=true.
DROP INDEX IF EXISTS bauth.idx_pag_user_deferred;
```

---

#### Nota de impacto en el trigger SoD (G-03)

El trigger `fn_check_sod_on_grant` en G-03 incluye salida temprana con
`IF NEW.access = false OR ...`. En el nuevo modelo `access=false` solo ocurre
con `general=false` (DENY explícito del operador); con `general=true` el trigger
de G-12 fuerza `access=true`. La condición de salida temprana debe actualizarse:

```sql
-- Condición de salida temprana actualizada para fn_check_sod_on_grant
-- El SoD solo aplica cuando el resultado del grant es PERMIT
IF  (NEW.general = true  AND NEW.effect = false)    -- árbol dice DENY
    OR (NEW.general = false AND NEW.access = false)  -- grant dice DENY
    OR NEW.user_id  IS NULL
    OR NEW.status  <> 'ACTIVE'
THEN
    RETURN NEW;
END IF;
```

**Pendiente:** formalizar este cambio en G-03 al aplicar el DDL de G-12.

---

## G-10 · Contrato JWT/BitMask — arquitectura de evaluación y compatibilidad ✅ CERRADO

**Enunciado original (replanteado):** el gap describía el problema como "Kong intenta verificar
el bit N+1 → fuera de rango". Este enunciado era incorrecto. El análisis completo reveló que
la premisa era equivocada en múltiples dimensiones. A continuación la doctrina correcta.

---

### § 1 · Corrección del enunciado original

El enunciado asumía que el JWT porta un **vector de bits del bitmask completo** y que Kong
evalúa posiciones individuales de ese vector. Ambas premisas son falsas.

**Realidad 1 — el JWT no porta el bitmask completo.**
El catálogo de átomos puede contener miles de átomos (5808 en VPS a 2026-07-20). Portar ese
vector en el JWT lo haría crecer a 726 bytes solo en esa parte, violando las mejores prácticas
de OAuth 2.0 y los límites de cabeceras HTTP (Nginx por defecto: 8 KB total de cabeceras).
Las buenas prácticas establecen que el JWT debe tener entre 100 y 300 bytes; tokens de más de
500 bytes requieren revisión crítica. El bitmask completo no viaja en el JWT.

**Realidad 2 — Kong no evalúa átomos individuales.**
Kong es un PEP (Policy Enforcement Point), no un PDP (Policy Decision Point). Su rol es
verificar y hacer cumplir una decisión ya tomada, no re-evaluar política. Cargar a Kong con la
evaluación de miles de átomos individuales violaría la separación PDP/PEP que establece NIST
SP 800-207 y la arquitectura XACML.

---

### § 2 · Arquitectura real: qué viaja en el JWT y qué viaja en la cookie

| Canal | Contenido | Propósito |
|---|---|---|
| **JWT** (cabecera HTTP) | **Resultado AND del bitmask** — un valor compacto de bits generales | Enforcement rápido en Kong; verificación sin latencia perceptible |
| **Cookie** (HttpOnly, Secure) | **Bitmask completo** del usuario (todos sus átomos evaluados) | Consulta local por la aplicación · contingencia sin conexión a bAuth |

El JWT lleva el **resultado de aplicar el operador AND** sobre todos los átomos relevantes para
el contexto del usuario. El resultado es un conjunto mínimo de bits generales — no el vector
completo — que Kong puede verificar en tiempo constante.

```
Átomos del usuario evaluados:
  átomo_1 = 1, átomo_2 = 1, átomo_3 = 1, átomo_4 = 0, átomo_5 = 1
  AND → 0  →  JWT lleva resultado = 0  (usuario bloqueado por algún átomo)

  átomo_1 = 1, átomo_2 = 1, átomo_3 = 1, átomo_4 = 1, átomo_5 = 1
  AND → 1  →  JWT lleva resultado = 1  (usuario autenticado y autorizado)
```

Un resultado AND = 0 indica que **algún átomo en el conjunto evaluado no está concedido** o
está en estado 0. No es necesario que Kong sepa cuál — solo que el resultado global es negativo.

---

### § 3 · División de responsabilidades PDP / PEP

```
┌─────────────────────────────────────────────────────────────┐
│  bAuth — PDP (Policy Decision Point)                        │
│  ─────────────────────────────────────────────────────────  │
│  · Lee átomos del usuario desde T-170 (privilege_atom_grant)│
│  · Evalúa todos los átomos relevantes para el ctx_id        │
│  · Aplica AND sobre el conjunto evaluado                    │
│  · Emite JWT con resultado compacto + cookie con bitmask    │
│  · Recomputa en nanosegundos por usuario afectado           │
│  · Emite CAEP token_claims_change cuando el resultado cambia│
└────────────────────────────┬────────────────────────────────┘
                             │  JWT (resultado AND compacto)
                             ▼
┌─────────────────────────────────────────────────────────────┐
│  Kong — PEP (Policy Enforcement Point)                      │
│  ─────────────────────────────────────────────────────────  │
│  · Verifica firma del JWT (Vault Ed25519)                   │
│  · Lee bits generales del resultado                         │
│  · Aplica lógica: resultado = 1 → PERMIT / 0 → DENY        │
│  · Evalúa obligaciones LoA si T-171 las define (§ G-04)    │
│  · NO evalúa átomos individuales — no conoce el catálogo   │
└─────────────────────────────────────────────────────────────┘
```

Esta separación está alineada con:
- **NIST SP 800-207** Zero Trust Architecture: PDP decide, PEP enforcea.
- **XACML** Reference Architecture: PDP evalúa políticas, PEP aplica la decisión.
- **OpenID AuthZEN Authorization API 1.0**: separa explícitamente la decisión de la enforcement.

---

### § 4 · Motor BitMask — velocidad de recomputo como garantía del contrato

El motor BitMask de bAuth opera en **nanosegundos** por usuario. Esta velocidad es la clave
que elimina el riesgo de JWT obsoleto ante cambios en el catálogo de átomos:

```
Evento: átomo K cambia estado para usuario X
    ↓  nanosegundos
Motor recomputa AND para usuario X únicamente (no masivo)
    ↓  nanosegundos
Resultado nuevo disponible en bAuth
    ↓  WAL → bauth-reactor → CAEP (milisegundos — única latencia real)
Kong recibe token_claims_change → invalida JWT de usuario X
    ↓
Usuario X re-autentica → JWT con resultado actualizado
```

**El recomputo es por usuario afectado, nunca masivo.** La concurrencia es mínima por diseño:
bAuth está pensado para ser administrado por una persona por tenant. Los cambios de estado de
átomos son eventos discretos y de baja frecuencia — incluso cuando el dominio temporal genera
actualizaciones continuas, el motor los absorbe sin bloqueo gracias a su velocidad de evaluación.

No existe "ventana peligrosa" de JWT obsoleto con resultado incorrecto, porque el tiempo de
recomputo (nanosegundos) es despreciable frente a la latencia de propagación CAEP (milisegundos).

---

### § 5 · Por qué WAL y no notificación directa desde la aplicación

El WAL (Write-Ahead Log de PostgreSQL) garantiza que bauth-reactor **nunca pierda un cambio**
en T-170, incluso ante fallos del sistema:

```
Enfoque INCORRECTO — notificación directa:
  bAuth escribe en T-170  →  OK
  bAuth notifica a bauth-reactor  →  CRASH aquí → Kong no se entera → JWT obsoleto activo

Enfoque CORRECTO — WAL:
  BEGIN;
    INSERT INTO privilege_atom_grant ...  →  WAL record escrito como parte de la transacción
  COMMIT;                                 →  WAL flushed a disco — atómico con el dato
  bauth-reactor lee WAL post-commit      →  garantía de entrega, orden preservado
```

La notificación directa introduce un gap de dos fases (escritura + notificación) que puede
quedar inconsistente ante un crash entre ambas. El WAL hace que la notificación sea una
consecuencia implícita e infalible del commit, no un paso adicional que puede fallar.

---

### § 6 · Cookie del bitmask — uso correcto

La cookie (HttpOnly, Secure) lleva el bitmask completo del usuario. Sus casos de uso son:

| Caso | Descripción |
|---|---|
| **Consulta local** | La aplicación cliente necesita evaluar permisos de UI (mostrar/ocultar elementos) sin llamar a bAuth |
| **Contingencia** | Pérdida temporal de conectividad con bAuth; la aplicación puede continuar operando en modo degradado con el último bitmask conocido |
| **Auditoría del cliente** | El usuario o la aplicación puede inspeccionar su propio bitmask para diagnóstico |

La cookie NO reemplaza al JWT para la enforcement en Kong. Kong solo evalúa el JWT.
La cookie NO viaja a Kong. Es un canal separado para el cliente.

---

### § 7 · Validación normativa

La arquitectura descrita está alineada con los siguientes estándares y especificaciones:

| Estándar | Versión | Alineación |
|---|---|---|
| **NIST SP 800-207** | Publicado | PDP (bAuth) evalúa; PEP (Kong) enforcea. Zero Trust sin inspección de política en el gateway. |
| **CAEP** (Continuous Access Evaluation Profile) | **Final — 2 sep 2025** | `token_claims_change` es el evento estándar que bAuth emite cuando el AND del usuario cambia. Aprobado por OpenID Foundation como especificación final. |
| **OpenID SSF** (Shared Signals Framework) | Final — 2 sep 2025 | Marco que contiene CAEP. bAuth actúa como SSF Transmitter; Kong como SSF Receiver. |
| **OAuth 2.0 JWT Best Practices** | RFC 9068 + community | JWT debe ser compacto (100-300 bytes ideales); no debe convertirse en perfil portable de permisos. El resultado AND compacto cumple esta regla. |
| **XACML Reference Architecture** | OASIS | PDP evalúa y produce decisión; PEP aplica decisión. Ningún componente actúa en ambos roles. |
| **OpenID AuthZEN Authorization API 1.0** | Draft / OpenID | Separa explícitamente la decisión de autorización (bAuth/PDP) de la enforcement (Kong/PEP). |

> Referencia de investigación: [OpenID CAEP 1.0 Final](https://openid.net/specs/openid-caep-1_0-final.html) ·
> [NIST SP 800-207](https://nvlpubs.nist.gov/nistpubs/specialpublications/NIST.SP.800-207.pdf) ·
> [JWT Best Practices — Curity](https://curity.io/resources/learn/jwt-best-practices/) ·
> [AuthZEN Deep Dive](https://dev.to/kanywst/authzen-authorization-api-10-deep-dive-the-standard-api-that-separates-authorization-decisions-1m2a) ·
> [PDP/PEP Oracle Zero Trust](https://docs.oracle.com/en/solutions/pdp-pep-zero-trust-arch-oci/index.html)

---

### § 8 · Contrato definitivo (decisiones cerradas)

| # | Decisión | Valor |
|---|---|---|
| C-01 | ¿Qué lleva el JWT? | Resultado AND compacto (bits generales) — NO el bitmask vectorial completo |
| C-02 | ¿Qué evalúa Kong? | Solo los bits generales del JWT; sin conocimiento de átomos individuales |
| C-03 | ¿Cómo se actualiza el resultado? | Motor BitMask recomputa por usuario afectado en nanosegundos |
| C-04 | ¿Cómo se invalida el JWT obsoleto? | CAEP `token_claims_change` — estándar OpenID Final sep 2025 |
| C-05 | ¿Por qué WAL y no notificación directa? | Atomicidad garantizada; la notificación es consecuencia implícita del commit |
| C-06 | ¿Re-emisión global ante cambio de catálogo? | NO — solo por usuario afectado; concurrencia mínima por diseño |
| C-07 | ¿Qué lleva la cookie? | Bitmask completo para consulta local y contingencia; no viaja a Kong |
| C-08 | ¿Techo del catálogo de átomos? | 64 posiciones por capa de bitmask (u64); más de 64 requiere migración a u128 o bitmask segmentado — deuda técnica futura |

---

### § 9 · Impacto en DDL

Este gap no genera tablas nuevas. Los únicos cambios documentales son comentarios en el DDL:

```sql
-- T-162 · idn_roles_template
-- NOTA ARQUITECTÓNICA: atom_position CHECK (BETWEEN 1 AND 64) refleja el límite físico
-- del u64 usado en el RolBitMask. El catálogo puede crecer hasta 64 átomos por capa.
-- Superar 64 átomos requiere migración a bitmask segmentado (u128 o dos claims u64 en JWT).
-- Esta restricción es conocida y aceptada. Ver GAPS-DDL-PRIVILEGIOS.md §G-10 C-08.

-- T-170 · privilege_atom_grant
-- El resultado AND del conjunto de átomos del usuario es lo que viaja en el JWT
-- (compacto, en bits generales). Este tabla materializa los grants individuales que
-- el motor BitMask lee para calcular ese resultado. La cookie lleva el bitmask completo.
-- Kong nunca lee T-170 directamente; solo verifica el resultado JWT emitido por bAuth.
```

DDL con estos comentarios: `A.65.02.01_ANEXO-OPERACION-TABLAS-DECISIONES-v1.0.md` §6.1 y §6.2.

---

**Cerrado:** 2026-07-20 · **Versión doctrina:** 1.0


---

## G-11 · Mapa de conversión de tipos de nodo: Dart → T-162 ✅ CERRADO

**Problema:** el árbol RolTemplate existe en tres representaciones con nombres distintos para
el mismo concepto. Al subir el árbol Dart a la tabla `idn_roles_template` (T-162), cada
`TipoNodo` debe convertirse al valor canónico de la columna `tipo`. Sin este mapa documentado,
cada implementador inventa su propio mapeo y el catálogo queda inconsistente.

---

### § 1 · Los tres sistemas de nombres

| Sistema | Dónde vive | Nombre del "átomo" |
|---|---|---|
| **AtomLang** (fuente `.atm.yaml`) | Archivos fuente del árbol · vocabulario `atomlang_datos.dart` | `atomo` |
| **Dart** (`TipoNodo` enum) | `src/desktop/lib/datos/rol_template_datos.dart` | `evaluacion` |
| **T-162** (columna `tipo`) | `bauth.idn_roles_template` · CHECK constraint | `'evaluacion'` |
| **AST Rust** (`atomc`) | `tools/atomc/src/parser/ast.rs` | `Atom` (≡ Rule XACML) |

La única renombrado crítico en toda la cadena es:
**`atomo` (AtomLang) → `evaluacion` (Dart + T-162)**.
Todos los demás tipos tienen el mismo nombre en los tres sistemas.

---

### § 2 · Tabla de conversión Dart → T-162

Al cargar el árbol Dart en T-162 se aplica esta conversión campo a campo para la columna `tipo`:

| `TipoNodo` (Dart enum) | `tipo` en T-162 | ¿Se inserta? | Restricciones adicionales |
|---|---|---|---|
| `dominio` | `'dominio'` | ✅ Sí | — |
| `bloque` | `'bloque'` | ✅ Sí | — |
| `objeto` | `'objeto'` | ✅ Sí | — |
| `lista` | `'lista'` | ✅ Sí | — |
| `politica` | `'politica'` | ✅ Sí | — |
| `regla` | `'regla'` | ✅ Sí | — |
| `evaluacion` | `'evaluacion'` | ✅ Sí | **`atom_position` asignado por SEQUENCE** · `verb_id` obligatorio |
| `atributo` | `'atributo'` | ✅ Sí | `atom_position = NULL` (CHECK constraint lo exige) |
| `enumerado` | `'enumerado'` | ✅ Sí | `atom_position = NULL` |
| `diagnostico` | — | ❌ **NO** | Nodo efímero del validador Dart — solo existe en memoria |

### Regla crítica: `diagnostico` nunca toca la base de datos

Los nodos `TipoNodo.diagnostico` son inyectados por el validador AtomLang (`atomlang_validador_datos.dart`) como anotaciones inline sobre el árbol en memoria para señalar violaciones de reglas. No representan estructura del árbol de negocio — son diagnósticos del linter. **El cargador a T-162 debe filtrarlos antes de cualquier INSERT.**

```dart
// Filtro obligatorio antes de insertar en T-162
final nodosSinDiagnosticos = nodosArbol
    .where((n) => n.tipo != TipoNodo.diagnostico)
    .toList();
```

---

### § 3 · Tabla de conversión AtomLang (.atm.yaml) → T-162

El compilador `atomc` (Rust) transforma el árbol fuente al IR compilado. La columna `tipo`
en T-162 se deriva del nodo fuente según este mapa:

| Nombre en `.atm.yaml` (AtomLang fuente) | AST Rust (`ast.rs`) | `tipo` en T-162 |
|---|---|---|
| `atomo:` | `Atom` (≡ `Rule` XACML) | `'evaluacion'` |
| `dominio:` con badge `[DOMAIN]` | `PolicySet { badge: Domain }` | `'dominio'` |
| `bloque:` con badge `[POLICYSET]` | `PolicySet { badge: PolicySet }` | `'bloque'` |
| `bloque:` con badge `[POLICY]` | `Policy` | `'bloque'` |
| `politica:` | `Policy` | `'politica'` |
| `regla:` | `Policy` con patrón eval→op→eval→efecto | `'regla'` |

**Nota:** `Policy` en XACML puede mapear a `'bloque'`, `'politica'` o `'regla'` dependiendo
del badge y la estructura de hijos. El compilador resuelve la ambigüedad en Fase 2.

---

### § 4 · Invariantes de T-162 que el cargador debe respetar

```sql
-- Solo nodos evaluacion tienen atom_position (asignada por SEQUENCE, nunca manual)
CONSTRAINT chk_irt_atom_position_solo_evaluacion CHECK (
    (tipo = 'evaluacion' AND atom_position IS NOT NULL)
    OR (tipo <> 'evaluacion' AND atom_position IS NULL)
)

-- Solo nodos evaluacion tienen verb_id (FK a privilege_verb)
CONSTRAINT chk_irt_verb_id_solo_evaluacion CHECK (
    (tipo = 'evaluacion' AND verb_id IS NOT NULL)
    OR (tipo <> 'evaluacion' AND verb_id IS NULL)
)
```

El cargador **no debe asignar `atom_position` manualmente** — debe llamar a
`nextval('bauth.roles_atom_position_sequential')` y dejar que PostgreSQL asigne la posición.
Ver G-05 (bootstrap) para el flujo completo de inicialización.

---

### § 5 · Pseudocódigo del cargador Dart → T-162

```rust
// Función de conversión TipoNodo → tipo SQL (Rust / cargador)
fn tipo_nodo_a_sql(tipo: &str) -> Option<&'static str> {
    match tipo {
        "dominio"    => Some("dominio"),
        "bloque"     => Some("bloque"),
        "objeto"     => Some("objeto"),
        "lista"      => Some("lista"),
        "politica"   => Some("politica"),
        "regla"      => Some("regla"),
        "evaluacion" => Some("evaluacion"),   // ← el "atomo" en AtomLang
        "atributo"   => Some("atributo"),
        "enumerado"  => Some("enumerado"),
        "diagnostico"=> None,                 // ← filtrar, nunca insertar
        _            => None,                 // ← tipo desconocido = error
    }
}
```

---

**Cerrado:** 2026-07-20 · **Documenta:** `rol_template_datos.dart` TipoNodo enum · T-162 CHECK · mapa AtomLang → DB

---

## G-12 · Modelo de evaluación de grants — 5 columnas en T-170 ⚠️ ABIERTO

**Versión del modelo:** 2.0 — reemplaza el modelo de 3 estados (access=NULL como señal de
precedencia) por el modelo de precedencia explícita con columnas dedicadas.

**Problema original:** `access boolean NOT NULL` en T-170 solo permite dos estados (PERMIT / DENY).
El modelo de 3 estados (access=NULL=diferido al árbol) resuelve la precedencia pero introduce
ambigüedad visual: un operador que ve `access=NULL` no puede distinguir entre "no configurado"
y "diferido intencionalmente". Además, la columna `reassess` no existe aún en T-170.

**Solución:** 5 columnas con semántica explícita. `access` siempre NOT NULL.
La precedencia (¿quién manda: árbol o grant?) se declara en la columna `general`.

---

### § 1 · Las 5 columnas del modelo de precedencia

| Columna | Tipo DDL | Control | Semántica |
|---------|----------|---------|-----------|
| `effect` | `boolean NOT NULL` | **Bloqueado** — trigger auto-sync desde T-162 | Espejo del Effect del nodo `evaluacion` en `idn_roles_template`. Se actualiza automáticamente cuando el árbol cambia. El operador nunca lo edita directamente. |
| `general` | `boolean NOT NULL DEFAULT true` | **Editable** por el administrador | `true` = árbol manda (`effect` prevalece). `false` = grant manda (`access` prevalece). Al crear el grant: siempre nace en `true`. |
| `local` | `boolean GENERATED ALWAYS AS (NOT general) STORED` | **Calculada** (columna generada PostgreSQL) | Inverso de `general`. Existe únicamente para legibilidad visual en la tabla. `local=true` cuando el grant tiene control local; `local=false` cuando el árbol tiene el control. |
| `access` | `boolean NOT NULL DEFAULT true` | **Auto-forzado** a `true` cuando `general=true`; **editable** cuando `general=false` | Valor de override del grant. Forzado a `true` por trigger cuando `general=true` (consistencia visual). Editable libremente cuando `general=false`. |
| `reassess` | `boolean NULL` | **Editable** | Elegibilidad para reevaluación reactiva CAEP / risk engine. Evaluado como segundo operando junto al valor activo: `effect AND reassess` o `access AND reassess` según `local`. |

**Invariante:** `access=false` solo puede ocurrir cuando `general=false`. El trigger garantiza `general=true → access=true` siempre.

---

### § 2 · Las capas de evaluación

```
┌─────────────────────────────────────────────────────────────────────┐
│  ÁRBOL (idn_roles_template · T-162)                          FUENTE  │
│  ─────────────────────────────────────────────────────────────────  │
│  El nodo evaluacion define su Effect en el árbol compilado por       │
│  AtomLang. Este Effect se copia en privilege_atom_grant.effect       │
│  automáticamente por trigger. Siempre visible en el grant.           │
└───────────────────────────────┬─────────────────────────────────────┘
                                │ sincronizado → columna effect
┌───────────────────────────────▼─────────────────────────────────────┐
│  COLUMNA `general` — controlador de precedencia                      │
│  ─────────────────────────────────────────────────────────────────  │
│  general = true  (local = false)  →  effect PREVALECE sobre access  │
│      El árbol tiene el control. access es informativo (= true).      │
│                                                                     │
│  general = false (local = true)   →  access PREVALECE sobre effect  │
│      El grant tiene el control. access es operativo (editable).      │
└───────────────────────────────┬─────────────────────────────────────┘
                                │ el valor activo es effect o access
┌───────────────────────────────▼─────────────────────────────────────┐
│  COLUMNA `reassess` — elegibilidad reactiva                          │
│  ─────────────────────────────────────────────────────────────────  │
│  Se evalúa junto al valor activo (forma compacta):                   │
│    local = false  →  evaluar:  effect AND reassess                   │
│    local = true   →  evaluar:  access AND reassess                   │
│                                                                     │
│  El AND activa la reevaluación CAEP solo cuando ambos son true.     │
│  Si el valor activo es false (DENY), reassess es irrelevante.        │
└─────────────────────────────────────────────────────────────────────┘
```

---

### § 3 · Regla de evaluación del PDP (pseudocódigo)

```
fn evaluar_atomo(grant) -> (EfectoFinal, ReassessActivo):

  ── Paso 1: determinar quién manda ────────────────────────────────────
  si grant.local = false:       # general=true → árbol manda
      valor_activo = grant.effect
  sino:                         # local=true, general=false → grant manda
      valor_activo = grant.access

  ── Paso 2: evaluar efecto del átomo ──────────────────────────────────
  si valor_is_active = false:
      return (DENY, false)      # DENY: reassess nunca se evalúa

  ── Paso 3: evaluar elegibilidad reactiva ─────────────────────────────
  # valor_is_active = true ya (PERMIT) — evaluar reassess junto a él
  si grant.local = false:
      cond = grant.effect AND grant.reassess    # = true AND grant.reassess
  sino:
      cond = grant.access AND grant.reassess    # = true AND grant.reassess
  # En ambos casos cond = grant.reassess (valor_activo=true)

  si grant.reassess IS NULL:
      reassess_activo = tenant_default(tenant_id)
  sino:
      reassess_activo = grant.reassess

  return (PERMIT, reassess_activo)
```

**Forma compacta (regla de evaluación):**
```
si local = false:  evaluar  effect AND reassess
si local = true:   evaluar  access AND reassess
```

El AND activa la reevaluación CAEP. Cuando el resultado es DENY (primer operando = false),
el AND es false y la reevaluación no se ejecuta — independientemente de `reassess`.

---

### § 4 · Tabla de estados

| `general` | `local` | `effect` | `access` | `reassess` | Resultado | CAEP |
|-----------|---------|----------|----------|-----------|-----------|------|
| true | false | true | true ¹ | NULL | PERMIT | default tenant |
| true | false | true | true ¹ | true | PERMIT | **activo** |
| true | false | true | true ¹ | false | PERMIT | inactivo |
| true | false | false | true ¹ | * | **DENY** | n/a |
| false | true | (any) | true | NULL | PERMIT | default tenant |
| false | true | (any) | true | true | PERMIT | **activo** |
| false | true | (any) | true | false | PERMIT | inactivo |
| false | true | (any) | false | NULL | DENY | n/a |
| false | true | (any) | false | false | DENY | n/a |
| false | true | (any) | false | true | **INVÁLIDO** | — |

¹ `access` forzado a `true` por trigger cuando `general=true`. El operador no puede editarlo.

**Fila inválida:** `general=false AND access=false AND reassess=true`. El CHECK constraint lo rechaza.
No tiene sentido marcar como elegible para reevaluación un DENY explícito del operador.

---

### § 5 · DDL — cambios en T-170

```sql
-- ─────────────────────────────────────────────────────────────────────
-- CAMBIO 1: Nueva columna effect — espejo bloqueado del árbol
-- El operador nunca edita esta columna directamente.
-- Su valor viene del trigger trg_t162_sync_effect_to_grants.
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE bauth.privilege_atom_grant
    ADD COLUMN effect boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN bauth.privilege_atom_grant.effect IS
    'Espejo del Effect del nodo evaluacion en idn_roles_template. '
    'Sincronizado automáticamente por trigger. NUNCA editar manualmente. '
    'true = árbol dice PERMIT; false = árbol dice DENY.';

-- ─────────────────────────────────────────────────────────────────────
-- CAMBIO 2: Nueva columna general — controlador de precedencia
-- true (default): árbol manda → effect prevalece
-- false: grant manda → access prevalece
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE bauth.privilege_atom_grant
    ADD COLUMN general boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN bauth.privilege_atom_grant.general IS
    'Controla qué valor tiene precedencia en la evaluación del átomo. '
    'true (default al crear) = árbol manda: effect prevalece sobre access. '
    'false = grant manda: access prevalece sobre effect. '
    'El administrador cambia este valor para activar el control local del grant.';

-- ─────────────────────────────────────────────────────────────────────
-- CAMBIO 3: Nueva columna local — generada, visual
-- local = NOT general. Sin semántica propia adicional.
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE bauth.privilege_atom_grant
    ADD COLUMN local boolean GENERATED ALWAYS AS (NOT general) STORED;

COMMENT ON COLUMN bauth.privilege_atom_grant.local IS
    'Derivado: local = NOT general. Columna generada por PostgreSQL. '
    'true = el grant tiene control local (access manda). '
    'false = el árbol tiene el control (effect manda). '
    'No editar directamente — se actualiza automáticamente con general.';

-- ─────────────────────────────────────────────────────────────────────
-- CAMBIO 4: access pasa a NOT NULL DEFAULT true
-- Cuando general=true, el trigger lo fuerza a true.
-- Cuando general=false, el administrador lo edita libremente.
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE bauth.privilege_atom_grant
    ALTER COLUMN access SET NOT NULL,
    ALTER COLUMN access SET DEFAULT true;

COMMENT ON COLUMN bauth.privilege_atom_grant.access IS
    'Valor de override del grant. '
    'Cuando general=true: forzado automáticamente a true por trigger (consistencia visual). '
    'Cuando general=false: editable — true=PERMIT explícito, false=DENY explícito. '
    'La precedencia la determina la columna general, no este campo.';

-- ─────────────────────────────────────────────────────────────────────
-- CAMBIO 5: Nueva columna reassess boolean NULL
-- Evaluada junto al valor activo: (effect AND reassess) o (access AND reassess).
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE bauth.privilege_atom_grant
    ADD COLUMN reassess boolean NULL;

COMMENT ON COLUMN bauth.privilege_atom_grant.reassess IS
    'Elegibilidad para reevaluación reactiva CAEP / risk engine / scheduler. '
    'Evaluado junto al valor activo del grant: '
    '  local=false → effect AND reassess '
    '  local=true  → access AND reassess '
    'NULL = comportamiento default del tenant (idn_tier_policy). '
    'true = elegible: CAEP puede reevaluar este grant reactivamente. '
    'false = estático: inmune a señales CAEP (break-glass, cuentas críticas).';

-- ─────────────────────────────────────────────────────────────────────
-- CAMBIO 6: CHECK constraint — incoherencia DENY explícito + reassess elegible
-- Solo aplica cuando general=false y access=false.
-- Con general=true el trigger garantiza access=true, por lo que
-- esta condición es imposible en ese caso.
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE bauth.privilege_atom_grant
    ADD CONSTRAINT chk_pag_reassess_coherencia
        CHECK (NOT (access = false AND reassess = true));

COMMENT ON CONSTRAINT chk_pag_reassess_coherencia
    ON bauth.privilege_atom_grant IS
    'Rechaza: general=false AND access=false AND reassess=true. '
    'Un DENY explícito del operador no puede ser elegible para reassess.';

-- ─────────────────────────────────────────────────────────────────────
-- CAMBIO 7: Trigger — forzar access=true cuando general=true
-- Garantiza consistencia visual: cuando el árbol manda, access=true
-- indica "no vetando nada" — el árbol (effect) es el que decide.
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION bauth.fn_sync_access_to_general()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.general = true THEN
        NEW.access := true;
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION bauth.fn_sync_access_to_general() IS
    'Fuerza access=true cuando general=true. '
    'Previene que access=false quede como falso visual de DENY '
    'cuando en realidad el árbol tiene el control del efecto.';

CREATE TRIGGER trg_t170_sync_access_general
    BEFORE INSERT OR UPDATE ON bauth.privilege_atom_grant
    FOR EACH ROW
    EXECUTE FUNCTION bauth.fn_sync_access_to_general();

-- ─────────────────────────────────────────────────────────────────────
-- CAMBIO 8: Trigger en T-162 — sincronizar effect hacia T-170
-- Cuando el árbol cambia el Effect de un nodo evaluacion,
-- todos los grants activos de ese átomo actualizan su columna effect.
--
-- NOTA: 'effect_value' es el nombre referencial de la columna de efecto
-- en idn_roles_template. El implementador debe verificar el nombre
-- exacto contra el DDL canónico de T-162.
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION bauth.fn_sync_effect_from_tree()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.effect_value IS DISTINCT FROM NEW.effect_value THEN
        UPDATE bauth.privilege_atom_grant
           SET effect = NEW.effect_value
         WHERE id_atom = NEW.id
           AND status IN ('ACTIVE', 'SUSPENDED');
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION bauth.fn_sync_effect_from_tree() IS
    'Trigger en idn_roles_template: cuando cambia el Effect de un nodo evaluacion, '
    'actualiza la columna effect en todos los grants activos de ese átomo. '
    'Mantiene effect sincronizado sin JOIN adicional en el PDP.';

CREATE TRIGGER trg_t162_sync_effect_to_grants
    AFTER UPDATE ON bauth.idn_roles_template
    FOR EACH ROW
    WHEN (OLD.effect_value IS DISTINCT FROM NEW.effect_value
          AND NEW.tipo = 'evaluacion')
    EXECUTE FUNCTION bauth.fn_sync_effect_from_tree();

-- ─────────────────────────────────────────────────────────────────────
-- Índice para grants elegibles para reassess (Dirección 5 de IGA)
-- Solo filas con resultado PERMIT (árbol o grant) Y reassess elegible.
-- ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_pag_reassess_eligible
    ON bauth.privilege_atom_grant (tenant_id, user_id)
    WHERE reassess = true
      AND status   = 'ACTIVE'
      AND (
          (general = true  AND effect = true)
          OR
          (general = false AND access = true)
      );

COMMENT ON INDEX bauth.idx_pag_reassess_eligible IS
    'Grants elegibles para reevaluación reactiva (CAEP/risk/scheduler). '
    'Solo incluye filas con resultado PERMIT y reassess=true. '
    'El CAEP receiver consulta este índice al recibir eventos de contexto '
    '(DeviceComplianceChange, RiskLevelChange, AssuranceLevelChange, etc.).';
```

---

### § 6 · Comportamiento de Kong PEP

Kong recibe el JWT con el resultado AND compacto del bitmask (G-10). El bit que viaja al JWT
es el `efecto_final` resultante de la evaluación del PDP:

| `general` | `effect` | `access` | Bit en JWT |
|-----------|----------|----------|------------|
| true | true | true ¹ | **1** (PERMIT) |
| true | false | true ¹ | **0** (DENY) |
| false | (any) | true | **1** (PERMIT) |
| false | (any) | false | **0** (DENY) |

¹ `access` forzado a `true` por trigger.

**Kong nunca ve `general`, `local`, `effect`, `access`, ni `reassess` directamente.**
Solo evalúa el bit en el JWT. La columna `reassess` es exclusivamente un contrato
interno entre el PDP de bAuth y el bAuth CAEP receiver.

---

### § 7 · Comportamiento del CAEP receiver

Cuando bAuth recibe un evento CAEP externo (ej: `DeviceComplianceChange`):

```
1. Identificar usuario afectado desde el evento CAEP

2. Consultar grants elegibles (idx_pag_reassess_eligible):
   SELECT pag.id, pag.id_atom, pag.general, pag.effect,
          pag.access, pag.atom_position
   FROM   bauth.privilege_atom_grant pag
   WHERE  pag.user_id   = $usuario_afectado
     AND  pag.tenant_id = $tenant_id
     AND  pag.reassess  = true
     AND  pag.status    = 'ACTIVE'
     AND  (
         (pag.general = true  AND pag.effect = true)
         OR
         (pag.general = false AND pag.access = true)
     )

3. Para cada grant elegible:
   a. Re-evaluar el átomo con el nuevo contexto (device posture, risk score, etc.)
   b. Si el nuevo resultado es DENY:
      → UPDATE privilege_atom_grant SET status = 'SUSPENDED' WHERE id = $grant_id
      → Invalidar RolBitMask en Redis para el usuario
      → Emitir CAEP 'Session Revoked' o 'Assurance Level Change' según el átomo
   c. Si el nuevo resultado sigue siendo PERMIT:
      → No action — mantener grant activo

4. Si algún grant fue suspendido:
   → Recomputar BitMask del usuario (G-10)
   → CAEP token_claims_change → Kong invalida JWT activo (G-01)
```

Los grants con `reassess=false` o `reassess=NULL` **no son consultados** — excluidos por
el índice. Cuentas break-glass y de sistema críticas son inmunes al CAEP receiver por diseño.

---

### § 8 · Impacto en seeds y bootstrap

Al crear un tenant nuevo, los átomos generales se insertan con `general=true` (árbol manda
por defecto). El trigger fuerza automáticamente `access=true`:

```sql
-- Átomo general — árbol controla, sin monitoreo CAEP por defecto
INSERT INTO bauth.privilege_atom_grant
    (id_atom, atom_position, bitmask_value, tenant_id, user_id,
     effect, general, access, reassess, status)
VALUES
    ($id_atom, $pos, $bitmask, $tenant_id, NULL,
     $effect_del_arbol,   -- sincronizado desde T-162 al insertar
     true,                -- árbol manda (default)
     true,                -- forzado por trigger (consistencia visual)
     NULL,                -- default del tenant
     'ACTIVE');
```

Los átomos con verbo `reassess` (ej: `d08.session.reassess`) se insertan con
`general=false, access=true, reassess=true` — grants de control local con CAEP activo.

---

### § 9 · Diferencias con el modelo previo (v1.0)

| Aspecto | Modelo v1.0 (3 estados, access=NULL) | Modelo v2.0 (5 columnas) |
|---------|--------------------------------------|--------------------------|
| Señal de "árbol manda" | `access IS NULL` | `general = true` (columna explícita) |
| `access` nullable | Sí — NULL=diferido al árbol | No — siempre NOT NULL |
| Effect del árbol en el grant | Requiere JOIN a T-162 | Columna `effect` en la misma fila (trigger-synced) |
| Confusión operacional | `access=NULL` puede leerse como "sin configurar" | `general/local` son inequívocos |
| `idx_pag_user_deferred` | Necesario (`access IS NULL`) | **Eliminado** — no hay NULL en `access` |

---

### § 10 · Por qué `reassess` tiene el mismo nombre en el verbo, la columna y el proceso

| Capa | `reassess` significa |
|------|---------------------|
| Verbo en dirección de átomo (`d08.session.reassess`) | Este sujeto tiene **autoridad** para disparar la reevaluación |
| Columna en T-170 (`grant.reassess = true`) | Este grant es **elegible** para ser reevaluado |
| Proceso en bAuth reactor | La **operación** de reevaluación reactiva en curso |

Los tres apuntan a la misma operación. El contexto (dirección de átomo / columna de
grant / proceso del reactor) resuelve sin ambigüedad en cuál de las tres capas se opera.
Idéntico al patrón de `access` — concepto, columna y estado en el mismo sistema sin colisión.

---

**Abierto:** 2026-07-21 · Versión modelo: 2.0 · **Tablas afectadas:** T-170 `privilege_atom_grant`, trigger en T-162 `idn_roles_template`
