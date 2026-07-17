# A.56 — Diseño de Base de Datos del Sistema de Identidad
## Por qué dos tablas, por qué cada campo, cómo se resuelven las búsquedas, cómo escala

**Versión:** 2.0.0
**Fecha:** 2026-07-15
**Tipo de anexo:** A (traslado de SSOT) + C (justificación de decisión técnica)
**Respalda a:** [1.06 D00 Identidad v2.1.0](../1.06_MANUAL-D00-IDENTIDAD-v2.0.md) · [1.07 Atributos v2.0](../1.07_MANUAL-ATRIBUTOS-v2.0.md)
**Normas base:** PostgreSQL 14+ particionamiento · pg_trgm · unaccent · Snowball Spanish

---

## §1 El problema que resuelve este diseño

### 1.1 Antipatrón 1: Una tabla por tipo de entidad

Si creamos `personas`, `empresas`, `vehiculos`, `productos`, `servidores`... cada tabla
requiere DDL, migración, struct Rust, handlers, tests, seeds, documentación. Agregar un
atributo nuevo (whatsapp, certificación ISO) requiere ALTER TABLE. Con 37 dominios de
identidad y 8 tipos de entidad, el sistema colapsa en complejidad.

**Lección del proyecto:** las tablas `org_contacto`, `org_documento`, `org_direccion`
fueron diseñadas y DESCARTADAS antes de nacer. Ese camino es insostenible.

### 1.2 Antipatrón 2: Una tabla con columnas fijas para todos

Una sola tabla con 300+ columnas. 99% de valores NULL. Un farol tiene 8 atributos,
una persona tiene 60. Las columnas del farol están vacías para personas, y viceversa.
Agregar un atributo nuevo = ALTER TABLE + bloqueo + migración.

### 1.3 Antipatrón 3: EAV sin índices de búsqueda (el error de Magento)

Magento (Adobe Commerce) usa EAV para su catálogo de productos. Pero NO incluyó índices
de búsqueda en su diseño inicial. El resultado: con 100K productos × 100 atributos,
las búsquedas tomaban **4 a 8 segundos**. Una eternidad para búsquedas de inventario.

**Lección de Magento:** el EAV sin índices GIN es inusable. Con índices GIN, las mismas
consultas bajan a <100ms. La diferencia está en el DDL inicial, no en parches posteriores.

### 1.4 La solución: 3 tablas + 7 índices + particionamiento + trazabilidad

| Componente | Qué resuelve |
|---|---|
| `idn_identidad_entidad` (adjacency list) | Jerarquía de 5 niveles. Sin closure table. Sin ltree. CTE recursiva estándar. |
| `idn_identidad_atributo` (EAV) | Atributos actuales. Sin ALTER TABLE. Cada entidad define sus propios campos. |
| `idn_identidad_atributo_history` (append-only) | Trazabilidad total. Cada cambio registrado: quién, cuándo, valor anterior/nuevo, ctx_id. Particionado por mes. ISO 27001, PCI DSS, GDPR. |
| `idn_identidad_requisito` (completitud) | Grado mínimo de atributos por tipo de entidad y nivel (1=funcional, 2=verificado, 3=completo). NIST 800-63A IAL1/IAL2 aplicado a cualquier entidad. |
| Sistema de identidad como poblador exclusivo | `idn_tenant`, `org_empresa`, `org_sucursal`, `org_pos_logico` se pueblan SOLO desde el sistema de identidad. Nadie más escribe. |
| 2 columnas generadas (`value_normalized`, `value_search`) | `value_normalized`: fuzzy (<100ms). `value_search`: full-text con sinónimos + stemming español (<50ms). Calculadas al INSERT. |
| 7 índices (3 B-tree + 4 GIN) | Búsquedas puntuales <1ms, fuzzy <100ms, full-text <50ms. Sin índices: 4-8s. |
| Partición por HASH(`tenant_id`) en `idn_identidad_atributo` + RANGE mensual en `idn_identidad_atributo_history` | 165M filas operativas divididas por tenant. Historial dividido por mes. |

---

## §2 `idn_identidad_entidad` — la jerarquía

### 2.1 Por qué adjacency list y no ltree o nested sets

**ltree** requiere la extensión `ltree` de PostgreSQL. Introduce un tipo de dato no
estándar. Cada vez que se mueve un nodo, hay que recalcular el path de todos sus
descendientes. Para ~10,000 entidades por tenant, es overkill.

**Nested sets** (left/right) permite consultar subárboles en O(1), pero insertar un nodo
requiere actualizar los boundaries de todos los nodos a la derecha. Para inserciones
frecuentes, es lento.

**Adjacency list** (`parent_id`) es el modelo más simple. `WITH RECURSIVE` resuelve la
navegación. Insertar un nodo es un INSERT. Mover un nodo es un UPDATE de `parent_id`.
No requiere extensiones. PostgreSQL optimiza CTE desde la versión 8.4.

### 2.2 Por qué UUID v7 y no SERIAL ni UUID v4

Los tenants externos crean entidades sin coordinación central. DESARROLLADOR-X inserta
un bdomain sin consultar a SKULL. UUID garantiza unicidad global sin secuencia compartida.
Un SERIAL requeriría una secuencia central o colisiones entre tenants.

**Por qué v7 y no v4:** UUID v4 es puramente aleatorio. Cada INSERT genera un valor
impredecible. El índice B-tree de la PRIMARY KEY sufre **fragmentación de páginas**:
cada nueva fila puede insertarse en cualquier página del índice, partiendo páginas
llenas y desperdiciando espacio.

UUID v7 (RFC 9562, mayo 2024) resuelve esto: los primeros 48 bits son un timestamp Unix
en milisegundos. Los inserts son **temporalmente ordenados**. El B-tree crece de forma
secuencial. Sin fragmentación. Sin páginas partidas. Mejor uso de cache.

```
UUID v4: 0a1b2c3d-... (aleatorio) → índice fragmentado, 30-40% menos rendimiento
UUID v7: 01932cba-... (timestamp)  → índice ordenado, mismo rendimiento que SERIAL
```

**Especificación para el DDL:** todas las PKs de `idn_identidad_entidad` e `idn_identidad_atributo` usan
`DEFAULT uuidv7()`. PostgreSQL 17+ tiene soporte nativo. Para versiones anteriores, se
usa la extensión `pg_uuidv7`.

### 2.3 Por qué `nivel` es ENUM y `tipo` es TEXT

`nivel` son los 5 niveles del árbol D00 (`tenant`, `bdomain`, `bsubdomain`, `pos`,
`actor`). Son el CONTRATO del Context Plane (SBOS-049 §5.3). El ctx_id tiene 6 segmentos
fijos. Si un nivel cambia, el ctx_id se rompe. No es extensible — es una constante
arquitectónica.

`tipo` ES extensible. Nuevos sectores (salud, educación, logística) agregan nuevos tipos
sin tocar el DDL. D93 gobierna qué tipos son válidos mediante políticas AtomLang. Si
fuera ENUM, cada nuevo tipo requeriría `ALTER TYPE`. Con TEXT + D93, agregar "dron" es
agregar el valor a la regla de validación.

### 2.4 Por qué `slug` — el identificador del ctx_id

El ctx_id es un string legible: `interno.skull.skull-corp.norte.caja-01.jperez`.
Si usáramos UUIDs, sería `interno.4c697f66.d204-45a5.ac36-c104f07c7046...` — ilegible.
El slug es único dentro del padre. `skull-corp` solo hay uno dentro de `skull`.

---

## §3 `idn_identidad_atributo` — los atributos

### 3.1 La estructura EAV con 5 niveles de clasificación

Cada atributo se clasifica con `category` → `attr_key` → `type` → `value`. Los tres
primeros son columnas separadas, no un path concatenado. Esto permite:

- `WHERE category = 'contacto'` usa índice B-tree, no `LIKE 'contacto.%'`
- `WHERE attr_key = 'email'` filtra por tipo de atributo sin parsear strings
- `WHERE type = 'work'` distingue email laboral del personal

### 3.2 `value_text` + `value_data` — simple vs complejo

El 80% de los atributos son texto simple: `"jperez@gmail.com"`, `"+591-7-1234567"`,
`"1234567 LP"`. Para esos, `value_text TEXT` es más rápido que JSONB — no requiere
parseo. Se lee directamente.

El 20% son estructuras complejas: `{nivel:"B2", certificacion:"TOEFL", score:95}`.
Para esos, `value_data JSONB` permite estructura anidada sin columnas adicionales.

### 3.3 `atom_code` — el puente con el BitMask

`NULL` = atributo libre. Cualquiera puede verlo. Gobernado por categoría.
`NOT NULL` = atributo controlado. Solo actores con ese átomo en su UserBitMask acceden.
Es `INT` (FK a `privilege_atom.atom_code`), no TEXT. El UserBitMask es un array de bits:
`UserBitMask[atom_code] == 1`. Con INT, es un lookup de array. Con TEXT, sería un JOIN.

### 3.4 `dominio_origen` — qué capa agregó este atributo

Cada atributo sabe de qué dominio viene: `'civil'`, `'laboral'`, `'autenticacion'`,
`'comercial'`, `'salud'`, `'propiedad'`, etc. Esto permite:

- `WHERE dominio_origen = 'laboral'` → solo atributos del historial laboral
- `WHERE dominio_origen = 'salud'` → solo historia clínica
- Auditoría: ¿qué dominio agregó qué atributo a qué entidad?

### 3.5 `idn_identidad_atributo_history` — trazabilidad y auditoría (tabla separada)

`idn_identidad_atributo` guarda el estado ACTUAL de cada atributo. Pero cada cambio debe ser
trazable: quién modificó, cuándo, cuál era el valor anterior, cuál es el nuevo.
Esto es obligatorio para ISO 27001 A.8.15, PCI DSS 10.3.2, y GDPR Art. 30.

**Por qué tabla separada y no una columna `estado` en `idn_identidad_atributo`:**

- `idn_identidad_atributo` con 165M filas YA tiene bastantes. Agregarle historial la duplica.
- Las consultas operativas ("dame el email actual de Juan") no compiten con consultas
  de auditoría ("¿quién cambió el email de Juan en 2019?").
- El historial es **append-only** (solo INSERT, nunca UPDATE ni DELETE). Ideal para
  particionar por fecha. Las consultas de auditoría tocan una partición específica.
- La tabla principal se mantiene pequeña y rápida. La histórica crece pero no frena
  las operaciones del día a día.

**Estructura:**

```sql
CREATE TABLE bauth.idn_identidad_atributo_history (
    history_id    BIGSERIAL,
    entidad_id    UUID NOT NULL,
    attr_key      TEXT NOT NULL,
    type          TEXT,
    tenant_id     UUID NOT NULL,
    old_value     TEXT,                -- NULL en INSERT (no había valor anterior)
    new_value     TEXT,                -- NULL en DELETE (se eliminó el atributo)
    changed_by    UUID NOT NULL,       -- ctx_id del actor que hizo el cambio
    change_type   TEXT NOT NULL        -- 'INSERT', 'UPDATE', 'DELETE'
                  CHECK (change_type IN ('INSERT', 'UPDATE', 'DELETE')),
    changed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id        TEXT NOT NULL,       -- SBOS-049: contexto completo de la operación
    PRIMARY KEY (history_id, changed_at)
) PARTITION BY RANGE (changed_at);

-- Particiones mensuales (se crean automáticamente con pg_partman o cron)
CREATE TABLE idn_identidad_atributo_history2026_07
    PARTITION OF bauth.idn_identidad_atributo_history
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
```

**Trigger que puebla el historial:**

```sql
CREATE OR REPLACE FUNCTION bauth.track_attribute_history()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO bauth.idn_identidad_atributo_history
            (entidad_id, attr_key, type, tenant_id,
             old_value, new_value, changed_by, change_type, ctx_id)
        VALUES (NEW.entidad_id, NEW.attr_key, NEW.type, NEW.tenant_id,
                NULL, NEW.value_text,
                current_setting('bauth.actor_id')::uuid,
                'INSERT', current_setting('bauth.ctx_id'));
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO bauth.idn_identidad_atributo_history
            (entidad_id, attr_key, type, tenant_id,
             old_value, new_value, changed_by, change_type, ctx_id)
        VALUES (NEW.entidad_id, NEW.attr_key, NEW.type, NEW.tenant_id,
                OLD.value_text, NEW.value_text,
                current_setting('bauth.actor_id')::uuid,
                'UPDATE', current_setting('bauth.ctx_id'));
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO bauth.idn_identidad_atributo_history
            (entidad_id, attr_key, type, tenant_id,
             old_value, new_value, changed_by, change_type, ctx_id)
        VALUES (OLD.entidad_id, OLD.attr_key, OLD.type, OLD.tenant_id,
                OLD.value_text, NULL,
                current_setting('bauth.actor_id')::uuid,
                'DELETE', current_setting('bauth.ctx_id'));
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_atributo_history
    AFTER INSERT OR UPDATE OR DELETE ON bauth.idn_identidad_atributo
    FOR EACH ROW EXECUTE FUNCTION bauth.track_attribute_history();
```

**Qué resuelve:**

- **Trazabilidad completa**: cada cambio de cada atributo de cada entidad queda
  registrado con quién, cuándo, valor anterior y nuevo, y ctx_id.
- **Auditoría por entidad**: `SELECT * FROM idn_identidad_atributo_history WHERE entidad_id = 'act-jperez' ORDER BY changed_at` → historial completo de cambios de Juan Pérez.
- **Auditoría por fecha**: `WHERE changed_at BETWEEN '2024-01-01' AND '2024-12-31'` → solo toca las 12 particiones de 2024.
- **Cumplimiento normativo**: ISO 27001 A.8.15 (logging), PCI DSS 10.3.2 (trazabilidad de cambios), GDPR Art. 30 (registro de actividades de tratamiento).
- **Reversión**: si un admin modifica un NIT por error, el historial tiene el valor anterior para restaurar.
- **Detección de anomalías**: cambios masivos en un corto período → posible ataque o error.

### 3.6 `idn_identidad_requisito` — grado de completitud mínimo por tipo de entidad

Sin requisitos mínimos, cualquiera crea una PERSONA solo con nombre y el sistema se llena
de basura. Cada tipo de entidad necesita un **grado de completitud mínimo** que el motor
de identidad verifica ANTES de crear la entidad. Esto es el equivalente a IAL1/IAL2 de
NIST SP 800-63A, pero aplicado a cualquier tipo de entidad, no solo personas.

**Estructura:**

```sql
CREATE TABLE bauth.idn_identidad_requisito (
    id            BIGSERIAL PRIMARY KEY,
    tipo_entidad  TEXT NOT NULL,        -- PERSONA, ORGANIZACION, VEHICULO, DISPOSITIVO...
    nivel         INT NOT NULL DEFAULT 1, -- 1=mínimo funcional, 2=verificado, 3=completo
    attr_key      TEXT NOT NULL,        -- attr_key requerido ('nombre','email','CI'...)
    requerido     BOOLEAN NOT NULL DEFAULT true,
    min_instances INT NOT NULL DEFAULT 1, -- cuántas instancias mínimo (1 email, 1 teléfono)
    max_instances INT,                  -- NULL = sin límite
    display_order INT NOT NULL DEFAULT 0,
    UNIQUE (tipo_entidad, nivel, attr_key)
);
```

**Datos de ejemplo:**

```sql
-- PERSONA nivel 1 (mínimo funcional, IAL1 equivalente)
INSERT INTO bauth.idn_identidad_requisito VALUES
  ('PERSONA', 1, 'nombre', true, 1, NULL, 1),
  ('PERSONA', 1, 'email', true, 1, NULL, 2);

-- PERSONA nivel 2 (verificado, IAL2 equivalente)
INSERT INTO bauth.idn_identidad_requisito VALUES
  ('PERSONA', 2, 'id_nacional', true, 1, 1, 1),
  ('PERSONA', 2, 'birth_date', true, 1, 1, 2),
  ('PERSONA', 2, 'direccion', true, 1, NULL, 3),
  ('PERSONA', 2, 'telefono', true, 1, 3, 4);   -- al menos 1, máximo 3

-- ORGANIZACION nivel 1
INSERT INTO bauth.idn_identidad_requisito VALUES
  ('ORGANIZACION', 1, 'nombre', true, 1, NULL, 1),
  ('ORGANIZACION', 1, 'email', true, 1, NULL, 2);

-- ORGANIZACION nivel 2
INSERT INTO bauth.idn_identidad_requisito VALUES
  ('ORGANIZACION', 2, 'razon_social', true, 1, 1, 1),
  ('ORGANIZACION', 2, 'NIT', true, 1, 1, 2),
  ('ORGANIZACION', 2, 'direccion_fiscal', true, 1, 1, 3),
  ('ORGANIZACION', 2, 'pais', true, 1, 1, 4);

-- VEHICULO nivel 1
INSERT INTO bauth.idn_identidad_requisito VALUES
  ('VEHICULO', 1, 'marca', true, 1, 1, 1),
  ('VEHICULO', 1, 'modelo', true, 1, 1, 2),
  ('VEHICULO', 1, 'anio', true, 1, 1, 3);

-- VEHICULO nivel 2
INSERT INTO bauth.idn_identidad_requisito VALUES
  ('VEHICULO', 2, 'placa', true, 1, 1, 1),
  ('VEHICULO', 2, 'dueño', true, 1, 1, 2),
  ('VEHICULO', 2, 'seguro', true, 1, 1, 3);

-- DISPOSITIVO nivel 1
INSERT INTO bauth.idn_identidad_requisito VALUES
  ('DISPOSITIVO', 1, 'marca', true, 1, 1, 1),
  ('DISPOSITIVO', 1, 'modelo', true, 1, 1, 2),
  ('DISPOSITIVO', 1, 'serial', true, 1, 1, 3);
```

**Cómo funciona al crear una entidad:**

```
bauth.entidad.create('PERSONA', 'Juan Pérez')

1. Motor de identidad consulta idn_identidad_requisito:
   SELECT attr_key, min_instances, max_instances
   FROM idn_identidad_requisito
   WHERE tipo_entidad = 'PERSONA' AND nivel = 1 AND requerido = true;
   → nombre (1), email (1)

2. Verifica que el request incluya al menos esos atributos:
   ✅ nombre: "Juan Pérez" (1 instancia, >= min_instances)
   ❌ email: NO INCLUIDO (0 instancias, < min_instances)

3. RECHAZA: "PERSONA nivel 1 requiere al menos: nombre, email. Falta: email."
   La entidad NO se crea hasta que se completen los requisitos mínimos.
```

**Por qué niveles y no una sola lista plana:** un desarrollador externo que solo necesita
autenticación (IAL1) no debería estar obligado a proporcionar CI y dirección fiscal. Pero
una empresa que factura (IAL2) sí. Los niveles permiten entrada progresiva: crear la
entidad con lo mínimo, luego completar más atributos para subir de nivel.

### 3.7 El sistema de identidad como poblador exclusivo de tablas de gobierno

`idn_tenant`, `org_empresa`, `org_sucursal`, `org_pos_logico` son tablas de gobierno.
Tienen FKs, índices y constraints que otras 50+ tablas del sistema referencian. Borrarlas
rompe el sistema. Pero tampoco pueden poblarse desde múltiples interfaces — eso genera
inconsistencia.

**Decisión arquitectónica: el sistema de identidad es el POBLADOR EXCLUSIVO.**

```
Dashboard de identidad (única interfaz)
  │
  ▼
Sistema de identidad (bauth.entidad.create)
  │
  ├── INSERT en idn_identidad_entidad (registro de identidad)
  ├── INSERT en idn_identidad_atributo (atributos extensibles)
  │
  └── HOOK DE SINCRONIZACIÓN (poblador exclusivo)
        │
        ├── INSERT/UPDATE en idn_tenant (tabla raíz de gobierno)
        ├── INSERT/UPDATE en org_empresa (bdomain tipo empresa)
        ├── INSERT/UPDATE en org_sucursal (bsubdomain tipo sucursal)
        ├── INSERT/UPDATE en org_pos_logico (pos)
        └── INSERT/UPDATE en idn_user_template (actor HUMAN)
```

**Qué columnas se sincronizan a cada tabla de gobierno:**

| Tabla de gobierno | Columnas pobladas por identidad | Columnas NO tocadas (otro sistema) |
|---|---|---|
| `idn_tenant` | tenant_id, tenant_slug, tenant_name, tenant_type, status, country, legal_name, tax_id, registration_number, legal_contact_email | realm_kc, namespace_k8s, vault_path (BOS), mfa_required, password_policy (D8/D9), plan_tier (admin) |
| `org_empresa` | uuid, tenant_id, nombre, tipo, slug, NIT, direccion, email, telefono | metadata JSONB (ERP) |
| `org_sucursal` | uuid, tenant_id, empresa_id, nombre, tipo, slug, direccion | — |
| `org_pos_logico` | uuid, tenant_id, sucursal_id, nombre, tipo, slug | device_config (BOS) |
| `idn_user_template` | uuid, username, tenant_id, empresa_id, sucursal_id, pos_id, account_type, status | rol_bitmask_base64 (BitMask), credenciales (auth_method) |

**Garantía de integridad:**

- Nadie más escribe en estas tablas. La interfaz de usuario no tiene acceso directo a SQL.
- Solo `bauth.entidad.create()` y `bauth.entidad.update()` pueden modificarlas.
- Si una tabla de gobierno tiene un campo que la identidad no llena, lo llena el sistema
  responsable (BOS para infraestructura, auth_method para credenciales, BitMask para permisos).
- La tabla de gobierno es el CONTRATO de existencia. Lo que está en `idn_tenant` EXISTE.
  Lo que no está, no existe. La identidad es la fuente de verdad.

### 3.8 bi18n — el servicio que interpreta y aplica los metadatos

Las tablas de este diseño almacenan los 25 metadatos del modelo de características
([Manual 1.07 §4.0](../1.07_MANUAL-ATRIBUTOS-v2.0.md)) como columnas en disco. Pero
un metadato como `mask: "partial(4)"` o `display_format: "ID_BO"` no se aplica solo por
estar guardado — necesita un servicio que lo interprete y lo transforme en comportamiento.

**El daemon `bi18n` ([i18n-orchestrator](../i18n-orchestrator-rust.md) §12) es ese servicio.**
El Motor de Identidad (PDP de bAuth) lo invoca en dos momentos del ciclo de vida del dato:

| Momento | Dónde actúa bi18n | Qué valida/ejecuta |
|---|---|---|
| **Escritura** | Antes del INSERT/UPDATE en `idn_identidad_atributo` | `mask` (sintaxis de estrategia), `display_format` (registrado en `format_map`), `canonicalValues` (no duplicados), `pattern` (regex compila y es segura), `input_mask` (caracteres válidos), `classification` (ISO 27001) |
| **Lectura** | Después del SELECT, antes de devolver al consumidor | `mask_value()` (PII), `format_value()` (ICU4X), `validate_enum()` (pertenencia a canonicalValues), `format_date()` (granularidad + locale del tenant) |

Sin bi18n, `mask: "cualquier_cosa"` se persiste sin error y falla en runtime. Con bi18n,
el valor se rechaza al guardar — el metadata nunca está corrupto. La integración completa
está documentada en [Manual 2.13 §5.4](../2.13_MANUAL-ATOMLANG-LENGUAJE-v2.0.md).

---

### 4.1 El error de Magento (y cómo no repetirlo)

Magento almacena atributos de productos en EAV. Una búsqueda como "zapatos rojos talla
42" requería JOINs entre 5 tablas de valores y la tabla de productos, sin índices
adecuados para búsqueda textual.

**Resultado:** 4-8 segundos por búsqueda. Tuvieron que agregar índices compuestos y
"flat tables" (tablas desnormalizadas) con downtime en producción.

**bAuth NO repite este error.** Las columnas generadas y los índices GIN van en el DDL
inicial. No hay parches posteriores. No hay ALTER TABLE de emergencia en producción.

### 4.2 Cómo funciona la búsqueda fuzzy: `value_normalized`

```sql
-- Columna generada STORED. Se calcula UNA VEZ al INSERT/UPDATE.
-- "TOYOTÁ" → "toyota". "TOLOTA" → "tolota".
-- "Freno Delantero" → "freno delantero".
value_normalized TEXT GENERATED ALWAYS AS (
    lower(unaccent(COALESCE(value_text, '')))
) STORED;
```

**Por qué STORED y no VIRTUAL:** una columna VIRTUAL se calcula en cada query. Con
165M filas, `lower(unaccent())` en runtime suma 0.5-1ms por fila escaneada. Eso es
fatal. Una columna STORED se calcula UNA VEZ al INSERT/UPDATE. Ocupa ~20% más espacio
en disco. Pero las consultas solo LEE el valor precalculado. Diferencia: <100ms vs 4-8s.

**Qué resuelve:** `WHERE value_normalized % 'tolota'` encuentra TOYOTA (0.667),
TOYOTÁ (0.667), TOLOTA (1.0). Sin esta columna, TOYOTÁ no aparecería porque el
acento rompe la comparación. Sin el índice GIN, la comparación escanearía 165M filas.

### 4.3 Sinónimos, abreviaturas y variaciones regionales

`lower(unaccent())` resuelve acentos. `pg_trgm` resuelve typos ("tolota" → "toyota").
Pero no resuelven que "coche", "auto", "carro" y "vehículo" son el mismo concepto. O
que "farol" (Bolivia) = "foco" (México) = "óptica" (Argentina). O que "del" significa
"delantero", "tras" significa "trasero", "izq" significa "izquierdo". O que la gente
busca "TYT" y el producto está registrado como "Toyota". O que "pastilla" y "pastillas"
deben normalizarse al mismo término de búsqueda.

PostgreSQL ofrece **diccionarios de sinónimos** (`.syn`) y **diccionarios de tesauro**
(`.ths`) que se integran con `to_tsvector()` y `to_tsquery()`. Las palabras se
normalizan ANTES de indexar y ANTES de buscar.

```sql
-- /etc/postgresql/spanish_synonyms.syn
auto        coche  carro  vehículo  automóvil
farol       foco  óptica  luz_delantera  faro
delantero   del  frontal
trasero     tras  posterior
izquierdo   izq  izquierda
derecho     der  derecha
freno       frenos  pastilla  pastillas
bujía       bujia  bujías  bujias  spark_plug
toyota      tyt  toy
batería     bateria  pila  acumulador
```

```sql
-- Configuración en PostgreSQL
CREATE TEXT SEARCH DICTIONARY spanish_syn (
    TEMPLATE = synonym,
    SYNONYMS = spanish_synonyms
);
CREATE TEXT SEARCH CONFIGURATION spanish_search (COPY = 'spanish');
ALTER TEXT SEARCH CONFIGURATION spanish_search
    ALTER MAPPING FOR asciiword, word WITH spanish_syn, spanish_stem;

-- La columna generada usa esta configuración con sinónimos + stemming
value_search TSVECTOR GENERATED ALWAYS AS (
    to_tsvector('spanish_search', lower(unaccent(COALESCE(value_text, ''))))
) STORED;
```

**Qué resuelve esto:**
- "foco del izq" → sinónimos expanden a `'farol' & 'delantero' & 'izquierdo'` → encuentra "Farol Delantero Izquierdo"
- "pastilla freno" → sinónimos normalizan a `'freno'` → encuentra "Pastillas de Freno" y "Freno Delantero"
- "TYT carina" → expande a `'toyota' & 'carina'` → encuentra todos los productos Toyota Carina
- "carro bateria" → expande a `'auto' & 'batería'` → compatible con búsquedas de México, Argentina, Bolivia
- "bujia" sin tilde → `unaccent` + sinónimo → encuentra "bujía", "bujías", "spark plug"

### 4.3.1 Administración de sinónimos por tenant, país e industria (Opción B)

Los sinónimos SON DATOS DE NEGOCIO. Un repuestero en Bolivia busca "farol", uno en México
busca "foco", uno en Argentina busca "óptica". Un mecánico busca "bujía", un electricista
busca "spark plug". No pueden vivir en archivos estáticos del filesystem que requieren
acceso SSH al servidor para editarse.

**Solución: la base de datos ES la fuente de verdad. Los archivos `.syn` son generados.**

```
DASHBOARD (admin edita)          BASE DE DATOS               POSTGRESQL
─────────────────────────       ───────────────              ──────────

1. Admin edita sinónimos    →   2. INSERT/UPDATE/DELETE
   en el panel D93                en bauth.idn_identidad_sinonimo
                                                             
                                 3. Trigger o cron detecta   →  4. Genera archivos .syn
                                    cambios (updated_at >        en $SHAREDIR/tsearch_data/
                                    last_sync)                   desde la tabla
                                                             
                                                             5. ALTER TEXT SEARCH
                                                                DICTIONARY (dummy)
                                                                → recarga sin restart
                                                             
                                 6. last_sync = now()            6. Cambios INMEDIATOS
                                    La tabla manda.              para todas las sesiones
                                    Los archivos obedecen.        activas.
```

Los sinónimos se editan y guardan en el dashboard (dominio D93). La tabla
`bauth.idn_identidad_sinonimo` es la **fuente de verdad**. Los archivos `.syn` que PostgreSQL lee
son **generados** desde la tabla, nunca editados a mano. Si hay cambios en la tabla (el
trigger detecta `updated_at > last_sync`), el proceso regenera los archivos y recarga.

**Estructura de la tabla (fuente de verdad):**

```sql
CREATE TABLE bauth.idn_identidad_sinonimo (
    id          BIGSERIAL PRIMARY KEY,
    tenant_id   UUID,                    -- NULL = global, NOT NULL = específico del tenant
    pais        TEXT,                    -- 'BO', 'MX', 'AR', NULL = todos los países
    industria   TEXT,                    -- 'autopartes', 'farmacia', NULL = todas
    tipo        TEXT NOT NULL DEFAULT 'sinonimo',  -- 'sinonimo' | 'abreviatura'
    palabra     TEXT NOT NULL,           -- palabra normalizada (a la que se expande)
    terminos    TEXT[] NOT NULL,         -- sinónimos o abreviaturas que expanden a "palabra"
    activo      BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);
```

**Sinónimos (regionales — organizados por país):**

```sql
INSERT INTO bauth.idn_identidad_sinonimo (tenant_id, pais, industria, tipo, palabra, terminos) VALUES
  -- Bolivia: "farol" es la palabra estándar
  (NULL, 'BO', 'autopartes', 'sinonimo', 'farol',   ARRAY['foco', 'óptica', 'luz_delantera']),
  -- México: "foco" es más común que "farol"
  (NULL, 'MX', 'autopartes', 'sinonimo', 'farol',   ARRAY['foco', 'luz_delantera', 'faro']),
  -- Argentina: "óptica" es el término dominante
  (NULL, 'AR', 'autopartes', 'sinonimo', 'farol',   ARRAY['óptica', 'luz', 'foco']),
  -- Global: cualquier país hispanohablante entiende estos
  (NULL, NULL, 'autopartes', 'sinonimo', 'auto',    ARRAY['coche', 'carro', 'vehículo', 'automóvil']),
  (NULL, NULL, NULL,         'sinonimo', 'batería', ARRAY['bateria', 'pila', 'acumulador']);
```

**Abreviaturas (universales o por industria — NO dependen del país):**

```sql
INSERT INTO bauth.idn_identidad_sinonimo (tenant_id, pais, industria, tipo, palabra, terminos) VALUES
  -- Abreviaturas universales de autopartes (cualquier país)
  (NULL, NULL, 'autopartes', 'abreviatura', 'delantero',  ARRAY['del', 'delant', 'frontal']),
  (NULL, NULL, 'autopartes', 'abreviatura', 'trasero',    ARRAY['tras', 'post', 'posterior']),
  (NULL, NULL, 'autopartes', 'abreviatura', 'izquierdo',  ARRAY['izq', 'izquierda']),
  (NULL, NULL, 'autopartes', 'abreviatura', 'derecho',    ARRAY['der', 'derecha']),
  -- Abreviaturas de marcas (universales)
  (NULL, NULL, 'autopartes', 'abreviatura', 'toyota',     ARRAY['tyt', 'toy']),
  (NULL, NULL, 'autopartes', 'abreviatura', 'volkswagen', ARRAY['vw', 'volks']),
  -- Abreviaturas específicas de un tenant (Maya Representaciones)
  ('t-maya', NULL, NULL,    'abreviatura', 'bujía',       ARRAY['spark_plug', 'sparkplug']);
```

**La diferencia entre sinónimos y abreviaturas:**

| | Sinónimos | Abreviaturas |
|---|---|---|
| **Dependen del país** | ✅ "farol" en BO, "foco" en MX, "óptica" en AR | ❌ "del" = "delantero" en todos los países |
| **Dependen de la industria** | Parcialmente (autopartes vs farmacia) | ✅ "spark_plug" solo en autopartes |
| **Organización** | `pais` + `industria` | `industria` (pais = NULL) |
| **Ejemplo** | `pais='BO'`: farol→foco | `pais=NULL`: delantero→del |
| **Archivo generado** | `syn_bauth_BO_autopartes.syn` | `syn_bauth_autopartes.syn` (sin país) |

Ambos viven en la MISMA tabla. El campo `tipo` los distingue. El campo `pais` determina
si es regional o universal. La misma infraestructura de sincronización los maneja a ambos.
Al generar los archivos, las abreviaturas (`pais = NULL`) van a archivos globales que
aplican a todos los tenants de esa industria. Los sinónimos (`pais = 'BO'`) van a archivos
específicos que solo aplican a tenants de ese país.

**Resolución de sinónimos por precedencia (de más específico a más general):**

```
1. tenant_id = 't-maya' AND pais = 'BO' AND industria = 'autopartes'  → mayor precedencia
2. tenant_id = 't-maya' AND pais = 'BO'                                → específico del tenant
3. tenant_id = 't-maya'                                                → genérico del tenant
4. pais = 'BO' AND industria = 'autopartes'                            → global por país+industria
5. pais = 'BO'                                                         → global por país
6. tenant_id IS NULL AND pais IS NULL AND industria IS NULL            → default global
```

**Proceso de sincronización (trigger + builder):**

```sql
-- Tabla de control de sincronización
CREATE TABLE bauth.idn_identidad_sinonimo_sync (
    id              INT PRIMARY KEY DEFAULT 1,
    last_sync_at    TIMESTAMPTZ NOT NULL DEFAULT '2000-01-01',
    archivos_regenerados INT DEFAULT 0,
    ultimo_error    TEXT
);

-- Función que detecta cambios y regenera archivos
-- Se ejecuta vía trigger AFTER INSERT/UPDATE/DELETE o vía cron cada 5 min
CREATE OR REPLACE FUNCTION bauth.sync_synonym_files()
RETURNS void AS $$
DECLARE
    rec RECORD;
    file_path TEXT;
    file_content TEXT;
BEGIN
    -- Solo actúa si hay cambios desde la última sync
    IF NOT EXISTS (
        SELECT 1 FROM bauth.idn_identidad_sinonimo
        WHERE updated_at > (SELECT last_sync_at FROM bauth.idn_identidad_sinonimo_sync)
    ) THEN RETURN; END IF;

    -- Para cada combinación única de (tenant_id, pais, industria)
    FOR rec IN
        SELECT tenant_id, pais, industria,
               string_agg(palabra || ' ' || array_to_string(sinonimos, ' '), E'\n') AS contenido
        FROM bauth.idn_identidad_sinonimo WHERE activo = true
        GROUP BY tenant_id, pais, industria
    LOOP
        file_path := CASE
            WHEN rec.tenant_id IS NOT NULL THEN 'syn_bauth_' || rec.tenant_id
            WHEN rec.pais IS NOT NULL AND rec.industria IS NOT NULL
                THEN 'syn_bauth_' || rec.pais || '_' || rec.industria
            WHEN rec.pais IS NOT NULL THEN 'syn_bauth_' || rec.pais
            ELSE 'syn_bauth_global'
        END || '.syn';

        -- Escribe el archivo .syn desde la tabla
        EXECUTE format('COPY (SELECT unnest(string_to_array($1, E''\n''))) TO %L',
                       '/var/lib/postgresql/data/tsearch_data/' || file_path)
        USING rec.contenido;
    END LOOP;

    -- Recarga sin restart
    ALTER TEXT SEARCH DICTIONARY spanish_syn (dummy);

    -- Marca sync completada
    UPDATE bauth.idn_identidad_sinonimo_sync
    SET last_sync_at = now(), archivos_regenerados = archivos_regenerados + 1;

    RAISE NOTICE 'Synonym sync: archivos regenerados y recargados a las %', now();
END;
$$ LANGUAGE plpgsql;
```

**Cuándo se dispara la sincronización:**

1. **Al guardar en el dashboard**: el handler `bauth.synonym.save()` ejecuta `sync_synonym_files()` inmediatamente después del INSERT/UPDATE/DELETE.
2. **Cron de respaldo**: cada 5 minutos por si hubo cambios directos en la BD.
3. **Al iniciar bAuth**: para asegurar que los archivos reflejan el estado de la tabla.

La tabla ES la fuente de verdad. Los archivos se regeneran desde ella. Si los archivos
se borran o corrompen, se regeneran desde la tabla. Si la tabla cambia, los archivos
se actualizan y PostgreSQL recarga sin restart.

**Ventajas de la Opción B sobre la Opción A (archivos estáticos):**

| | Opción A (archivos) | Opción B (tabla + generación) |
|---|---|---|
| Editar sinónimos | Requiere SSH al servidor | Desde el dashboard (D93) |
| Por tenant | No (un solo archivo global) | Sí (columna tenant_id) |
| Por país | Archivos separados manualmente | Columna pais, generación automática |
| Por industria | Archivos separados manualmente | Columna industria |
| Auditoría | No (el archivo no tiene trazabilidad) | Sí (created_at, updated_at, quién cambió) |
| Recarga sin restart | `ALTER ... (dummy)` manual | Automático en el proceso de sync |
| Rollback | Manual (backup del archivo) | Soft-delete (activo=false) |

**Referencias:**
- [PostgreSQL ALTER TEXT SEARCH DICTIONARY — recarga sin restart](https://www.postgresql.org/docs/current/sql-altertsdictionary.html)
- [PostgreSQL Synonym Dictionary — estructura y configuración](https://www.postgresql.org/docs/current/textsearch-dictionaries.html#TEXTSEARCH-SYNONYM-DICTIONARY)

### 4.4 Cómo funciona la búsqueda full-text con todo integrado

`value_search` combina tres capas de normalización en una sola columna generada:

```
value_text = "Foco Del. Izq. TYT Carina 92"
  ↓ unaccent()
  "Foco Del. Izq. TYT Carina 92"
  ↓ lower()
  "foco del. izq. tyt carina 92"
  ↓ to_tsvector('spanish_search', ...)
  ┌─ spanish_syn expande:
  │   "foco" → "farol"
  │   "del" → "delantero"
  │   "izq" → "izquierdo"
  │   "tyt" → "toyota"
  └─ spanish_stem aplica stemming:
      "farol" "delanter" "izquierd" "toyot" "carin" "92"

  → tsquery 'farol & delantero & izquierdo & toyota & carina'
  → Encuentra: "Farol Delantero Izquierdo Toyota Carina 92"
```

Una sola columna generada. Cuatro operaciones (unaccent, lower, sinónimos, stemming).
Calculadas una vez al INSERT. Índice GIN encima. <50ms por búsqueda.

### 4.4 Los 7 índices y qué problema resuelve cada uno

| Índice | Tipo | Columnas | Qué resuelve | Tiempo |
|---|---|---|---|---|
| `ix_atributo_entidad` | B-tree | `(entidad_id, category, attr_key)` | "Atributos de la entidad X" | <1ms |
| `ix_atributo_atom` | B-tree parcial | `(atom_code) WHERE atom_code IS NOT NULL` | "Atributos controlados por BitMask" | <1ms |
| `ix_atributo_exact` | B-tree | `(tenant_id, attr_key, value_normalized)` | "¿De quién es este email?" | <1ms |
| `ix_atributo_fuzzy` | GIN | `(value_normalized gin_trgm_ops)` | "tolota" → TOYOTA/TOLOTA/TOYOTÁ | <100ms |
| `ix_atributo_fts` | GIN | `(value_search)` | "foco del izq carina" → encuentra "Farol Del. Izq. Toyota" (sinónimos + stemming) | <50ms |
| `ix_atributo_data` | GIN | `(value_data)` | `value_data @> '{"certificacion":"TOEFL"}'` | <10ms |
| `ix_atributo_cat` | GIN | `(category gin_trgm_ops)` | "Todas las categorías que contengan 'contacto'" | <5ms |

`ix_atributo_fts` es el más potente. Combina 4 operaciones en una columna generada:
`unaccent()` → `lower()` → sinónimos (`.syn`) → stemming (Snowball Spanish). Una
búsqueda como "foco del izq TYT carina 92" se normaliza a los mismos lexemas que
"Farol Delantero Izquierdo Toyota Carina 1992". Y como es STORED, se calcula una
sola vez al INSERT. Con GIN, <50ms.

### 4.5 El flujo de una búsqueda real (con sinónimos)

```
Usuario (México) escribe: "foco del izq tyt carina 92"

1. Dashboard envía la consulta
2. bAuth normaliza la búsqueda con los mismos diccionarios:
   lower(unaccent('foco del izq tyt carina 92'))
   → spanish_syn: 'foco'→'farol', 'del'→'delantero', 'izq'→'izquierdo', 'tyt'→'toyota'
   → spanish_stem: 'farol' & 'delanter' & 'izquierd' & 'toyot' & 'carin' & '92'

3. bAuth ejecuta:
   SELECT e.nombre, a_marca.value_text, a_cod.value_text,
          ts_rank(s.value_search, query) AS rank
   FROM idn_identidad_atributo s
   JOIN idn_identidad_entidad e ON s.entidad_id = e.id AND e.tenant_id = 't-maya'
   JOIN idn_identidad_atributo a_tipo ON e.id = a_tipo.entidad_id
       AND a_tipo.attr_key = 'tipo' AND a_tipo.value_text = 'farol',
        to_tsquery('spanish_search', 'foco & del & izq & tyt & carina & 92') AS query
   WHERE s.tenant_id = 't-maya'
     AND s.value_search @@ query              -- usa ix_atributo_fts (GIN)
   ORDER BY rank DESC;

4. Resultados:
   Farol Delantero Izquierdo TOYOTA Carina 92    rank: 0.95
   Farol Delantero Izquierdo TOLOTA Carina 92    rank: 0.88
   Farol Delantero Izquierdo DEPO Carina 92      rank: 0.88

5. Tiempo total: <50ms para 165M filas totales
```

---

## §5 Particionamiento y escalabilidad

### 5.1 Por qué particionar por `tenant_id`

Con 1,000 empresas, `idn_identidad_atributo` tendrá ~165M filas. Sin particionamiento, cada
query escanea (o el índice escanea) todas. Con particionamiento HASH por `tenant_id`,
cada query solo toca UNA partición. 16 particiones × ~10M filas cada una.

### 5.2 Control de crecimiento

| Escala | Particiones | Filas por partición | Búsqueda fuzzy | Búsqueda exacta |
|---|---|---|---|---|
| 1-100 tenants | 4 | ~4M | <50ms | <1ms |
| 100-500 tenants | 8 | ~10M | <80ms | <1ms |
| 500-2,000 tenants | 16 | ~10M | <100ms | <1ms |
| 2,000-10,000 tenants | 32 | ~10M | <150ms | <2ms |

Cuando una partición supera ~15M filas, se redistribuye con más particiones.
PostgreSQL 14+ permite `DETACH PARTITION` + `ATTACH PARTITION` sin bloquear lecturas.

### 5.3 El costo del almacenamiento

| Componente | Tamaño estimado (1,000 tenants) |
|---|---|
| `idn_identidad_entidad` (7M filas) | ~2 GB |
| `idn_identidad_atributo` datos (165M filas) | ~30 GB |
| `value_normalized` (columna generada) | ~5 GB |
| `value_search` (columna generada) | ~8 GB |
| Índices B-tree (3) | ~8 GB |
| Índices GIN (4) | ~15 GB |
| **Total** | **~68 GB** |

Para 10,000 tenants (~1.7B filas): ~680 GB. PostgreSQL maneja esto con particionamiento
y tablespaces en SSD. El costo de almacenamiento es el precio de la flexibilidad infinita.

---

## §6 Evidencia de la industria

Magento (Adobe Commerce) usa el mismo modelo EAV en producción. Millones de tiendas.
La lección aprendida y documentada:

- **100K productos × 100 atributos = ~10M filas** en `catalog_product_entity_varchar`.
  Sin índices compuestos: categorías en 4-8 segundos.
- **Con índices compuestos y GIN**: categorías en 1.4 segundos. Búsquedas en 0.6s.
- **bAuth va un paso más allá**: columnas generadas STORED + índices GIN en el DDL
  inicial. Sin parches. Sin flat tables. Sin downtime.

**Fuentes:**
- [Magento 2 EAV Performance Deep Dive](https://dev.to/magevanta/magento-2-eav-performance-deep-dive-optimizing-the-entity-attribute-value-model-od9)
- [Magento 2 Large Catalog Performance: Scaling Beyond 100K Products](https://dev.to/magevanta/magento-2-large-catalog-performance-scaling-beyond-100k-products-1472)
- [PostgreSQL FTS + trigram + unaccent (2GB instance, 1M+ rows)](https://dev.to/sartois/full-text-search-on-a-2-gb-postgresql-instance-337j)
- [pg_trgm strict_word_similarity](https://github.com/neondatabase/website/blob/f0877b9838219465283c3b8508c405647256a166/content/docs/extensions/pg_trgm.md)

---

## §7 Resumen: por qué este diseño sobrevive sin nosotros

1. **Tres tablas.** `idn_identidad_entidad` (jerarquía) + `idn_identidad_atributo` (atributos actuales) + `idn_identidad_atributo_history` (trazabilidad, append-only, particionado por mes). PKs UUID v7 (RFC 9562).
2. **Columnas generadas STORED.** `value_normalized` (fuzzy <100ms) + `value_search` (full-text <50ms). Sinónimos y abreviaturas administrables desde D93, generan archivos `.syn`, recarga sin restart.
3. **Siete índices en el DDL inicial.** 3 B-tree para exactas, 4 GIN para fuzzy/full-text/JSONB/categoría.
4. **Partición por tenant.** Cada empresa en su espacio físico. Escala horizontal a 10,000 tenants.
5. **Sin ALTER TABLE.** Solo INSERT para nuevos atributos. Gobernado por D93.
6. **Seguridad en profundidad.** RLS para aislamiento, pgcrypto+Vault para cifrado de columnas sensibles, TLS 1.3+mTLS en tránsito, Kong como único punto de entrada.
7. **Compartición externa controlada.** Logical Replication con filtro por tenant. El desarrollador recibe copia local de solo lectura. bAuth retiene la gobernanza.


---

## §8 Seguridad de los datos de identidad

### 8.1 Brechas actuales de bAuth que afectan al sistema de identidad

| Brecha | Severidad | Impacto en identidad | Solución |
|---|---|---|---|
| **Row-Level Security ausente** | P2 | Si un handler olvida `WHERE tenant_id`, expone catálogos de todos los tenants entre sí | Activar RLS en `idn_identidad_entidad` e `idn_identidad_atributo` |
| **Field-level encryption ausente** | P2 | NIT, CI, datos tributarios en claro en PostgreSQL | pgcrypto + Vault para claves |
| **DPoP es un stub** | P1 | Token robado = lectura de datos de identidad sin restricción | Implementar DPoP real (RFC 9449) |
| **Sin Gestor de Canales** | P1 | Seguridad de transporte no uniforme | Centralizar TLS/mTLS en `src/transport/` |

### 8.2 Solución 1: Row-Level Security (RLS)

PostgreSQL permite políticas de seguridad a nivel de fila. Se activan UNA VEZ en el DDL
y PostgreSQL las fuerza en cada query, incluso si la aplicación olvida el WHERE.

```sql
-- Activar RLS en las tablas de identidad
ALTER TABLE bauth.idn_identidad_entidad ENABLE ROW LEVEL SECURITY;
ALTER TABLE bauth.idn_identidad_atributo ENABLE ROW LEVEL SECURITY;

-- Política: cada tenant solo ve sus propias entidades
CREATE POLICY tenant_isolacion_entidad ON bauth.idn_identidad_entidad
    FOR ALL
    USING (tenant_id = current_setting('bauth.tenant_id')::uuid);

CREATE POLICY tenant_isolacion_atributo ON bauth.idn_identidad_atributo
    FOR ALL
    USING (tenant_id = current_setting('bauth.tenant_id')::uuid);

-- bAuth establece el tenant al iniciar la sesión
-- SET bauth.tenant_id = 't-maya';
-- Después de eso, TODAS las consultas se filtran automáticamente.
-- Incluso si un handler olvida el WHERE, PostgreSQL lo fuerza.
```

**Qué resuelve:** si un handler olvida `WHERE tenant_id`, RLS lo aplica de todos modos.
Toyota NUNCA ve los datos de DEPO. La Tiendita NUNCA ve los datos de Toyota. Es una
capa de seguridad adicional a nivel de base de datos, no solo de aplicación.

### 8.3 Solución 2: Field-level encryption (pgcrypto)

Columnas sensibles (NIT, CI, datos tributarios, número de pasaporte) se cifran a nivel
de campo. La clave de cifrado vive en Vault, nunca en PostgreSQL.

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Los datos sensibles se almacenan como BYTEA cifrado
-- La clave de cifrado se obtiene de Vault al iniciar bAuth
-- Nunca se escribe en consultas SQL (evita fuga por logs)

-- Ejemplo de inserción con cifrado (la clave viene de Vault)
-- INSERT INTO idn_identidad_atributo (value_text_encrypted)
-- VALUES (pgp_sym_encrypt('12345678901234', :vault_key));

-- La aplicación desencripta al leer:
-- SELECT pgp_sym_decrypt(value_text_encrypted, :vault_key) FROM idn_identidad_atributo;
```

**Qué resuelve:** un atacante con acceso directo a la BD (volcado, backup robado) ve
bytes cifrados, no NITs ni CIs en texto plano. Combinado con RLS, la defensa es en
profundidad: RLS limita qué filas se ven, pgcrypto limita qué se lee de esas filas.

### 8.4 Solución 3: Compartición de datos con desarrolladores externos

Un desarrollador externo necesita los códigos de Toyota, los usuarios, los átomos y
los roles asignados en su propia base de datos. Como **imágenes de solo lectura** que
puede consultar y relacionar con sus tablas como si fueran propias. Pero bAuth retiene
la gobernanza total.

Hay tres escenarios, cada uno con su solución:

#### Escenario A: El desarrollador usa PostgreSQL

**Solución: Foreign Data Wrapper (`postgres_fdw`) + tablas virtuales de solo lectura.**

El desarrollador NO recibe una copia física. Ve las tablas de bAuth como **tablas
virtuales** en su propia BD. Las consulta como si fueran locales. PostgreSQL envía
las queries al servidor de bAuth (query pushdown). Los datos nunca salen de bAuth
excepto como resultados de queries autorizadas.

```
DESARROLLADOR (PostgreSQL)                    bAuth (PostgreSQL)
────────────────────────────                  ──────────────────

1. CREATE SERVER bauth_server                 3. Usuario readonly_toyota
   FOREIGN DATA WRAPPER postgres_fdw             solo tiene SELECT sobre
   OPTIONS (host 'bauth.internal',               tablas de Toyota
            dbname 'bauth_db',
            updatable 'false');               4. bAuth controla:
                                                • Qué tablas ve (solo Toyota)
2. CREATE USER MAPPING FOR dev_user              • Qué columnas ve (no PII)
   SERVER bauth_server                          • Qué filas ve (tenant_id)
   OPTIONS (user 'readonly_toyota',
            password '***');

3. IMPORT FOREIGN SCHEMA public
   LIMIT TO (idn_identidad_entidad, idn_identidad_atributo)
   FROM SERVER bauth_server
   INTO ext_bauth;

4. El desarrollador consulta:
   SELECT e.nombre, a.value_text AS codigo
   FROM ext_bauth.idn_identidad_entidad e
   JOIN ext_bauth.idn_identidad_atributo a ON e.entidad_id = a.entidad_id
   JOIN mi_inventario.productos p ON a.value_text = p.codigo_toyota
   WHERE a.attr_key = 'codigo';
   -- PostgreSQL hace pushdown del JOIN a bAuth
   -- Solo viajan los resultados, no toda la tabla
```

**Ventajas:** datos siempre en bAuth, cero latencia de sincronización, queries en
tiempo real, el desarrollador ve exactamente lo que bAuth quiere que vea.
**Desventaja:** requiere conectividad de red al servidor bAuth. Latencia de red
en cada query. No funciona offline.

#### Escenario B: El desarrollador usa MySQL, SQLite u otra BD

**Solución: `pg2any` — CDC con logical replication hacia cualquier destino.**

bAuth publica los cambios vía logical replication. `pg2any` (herramienta open source)
consume el stream de WAL y lo replica a MySQL, SQLite, SQL Server o Kafka. El
desarrollador recibe una **copia física de solo lectura** que se mantiene sincronizada
en tiempo real.

```
bAuth (PostgreSQL)                    pg2any                     Desarrollador (MySQL)
──────────────────                    ──────                     ─────────────────────

1. CREATE PUBLICATION pub_toyota      2. CDC consumer:           3. Tablas locales:
   FOR TABLE idn_identidad_entidad,               Lee WAL de bAuth           idn_identidad_entidad (readonly)
   idn_identidad_atributo                         Convierte a SQL            idn_identidad_atributo (readonly)
   WHERE (tenant_id = 't-toyota')       del destino
                                                               4. El desarrollador:
                                        → INSERT/UPDATE/DELETE     JOIN con sus tablas
                                          en MySQL                 Consultas a máxima
                                                                   velocidad local
                                                                   Cero latencia de red
                                                                   Sin dependencia de
                                                                   conectividad a bAuth
```

**Ventajas:** máxima velocidad (datos locales), funciona offline, compatible con
cualquier BD. **Desventaja:** los datos salen físicamente de bAuth. Hay que confiar
en que el desarrollador no los copie. La gobernanza se ejerce cortando la publicación.

#### Escenario C: Solo necesita datos de referencia (usuarios, roles, átomos)

**Solución: Materialized View remota + refresh periódico.**

Para datos que cambian poco (catálogo de roles, lista de átomos, registro de usuarios),
una vista materializada que se refresca cada N minutos es suficiente. Más simple que
CDC. Menos carga que FDW en tiempo real.

```sql
-- En bAuth:
CREATE MATERIALIZED VIEW mv_toyota_catalog AS
SELECT e.entidad_id, e.nombre, e.tipo,
       a.attr_key, a.type, a.value_text, a.value_normalized
FROM idn_identidad_entidad e
JOIN idn_identidad_atributo a ON e.entidad_id = a.entidad_id
WHERE e.tenant_id = 't-toyota';

-- El desarrollador consulta esta vista vía API REST (Kong)
-- GET https://bauth.api/toyota/catalog
-- Respuesta: JSON con todo el catálogo Toyota
-- Cache: 5 min en Redis, 24h en el cliente
```

#### Recomendación por caso de uso

| Caso de uso | Solución | Por qué |
|---|---|---|
| Desarrollador PostgreSQL, consultas frecuentes, datos cambian | FDW (tablas virtuales) | Datos siempre en bAuth. Sin copia física. |
| Desarrollador MySQL/SQLite, catálogo grande, necesita velocidad local | pg2any (CDC) | Copia local, máxima velocidad, cualquier BD |
| Datos de referencia (roles, átomos, usuarios), cambian poco | Materialized View + API | Simple, cacheable, no requiere infraestructura extra |
| Desarrollador externo sin acceso directo a red de bAuth | API REST via Kong | Solo acceso HTTP, seguro, controlado |

### 8.5 Resumen de capas de seguridad para el sistema de identidad

| Capa | Tecnología | Qué protege |
|---|---|---|
| **Aislamiento multi-tenant** | RLS + `tenant_id` en queries | Cada tenant solo ve sus datos |
| **Cifrado en reposo (columnas)** | pgcrypto + Vault | NIT, CI, pasaporte cifrados en disco |
| **Cifrado en reposo (volumen)** | K8s Persistent Volume encryption | Todo el volumen de PostgreSQL |
| **Cifrado en tránsito** | TLS 1.3 + mTLS | Datos entre daemons y hacia Kong |
| **Control de acceso** | BitMask + ctx_id + JWT | Quién puede ver/editar cada atributo |
| **Compartición externa** | Logical Replication con filtro | Solo datos autorizados, solo lectura |
| **Auditoría** | pgAudit + WORM + blockchain | Quién accedió a qué, cuándo, desde dónde |
