# REPARACION-IDN-ROLE-TEMPLATE — Plan Maestro de Reparación del Sistema de Roles
## v2.1 · 2026-07-08 · bauth-developer

---

## 1. Contexto y Alcance

Este documento coordina la reparación completa del sistema de plantillas de roles en bAuth.
El trabajo toca la tabla central `bauth.idn_role_template`, su DDL, la arquitectura de
almacenamiento de templates, y la carga de los 368 roles del catálogo oficial.

**VPS de pruebas:** `13.140.128.230`
**Acceso BD:** pod `postgresql-0` · namespace `sbos-data` · BD `SBOS_db`
**Usuario:** `postgres` · **Contraseña:** `sbos_bootstrap_pass`
**Schema:** `bauth`

---

## 2. Tabla principal y su estado actual

```
bauth.idn_role_template  —  31 filas de datos falsos, columna template JSONB de 86 KB por fila
```

**Estado verificado 2026-07-08:**
- 31 registros insertados por agente anterior sin base en el catálogo oficial
- 19 registros son `ROL-ORG-*` inventados (CEO, CFO, DIR-FIN...) — no existen en el catálogo
- El campo `template jsonb` monolítico de ~86 KB por fila es el problema de arquitectura central
- Las columnas planas (tier, hierarchy_level, parent_id, status, sam128_*, loa_required...) son correctas y se conservan

**Tablas relacionadas que se ven afectadas:**
- `bauth.idn_role_closure` — DAG de herencia (FK a idn_role_template)
- `bauth.idn_user_role` — asignación usuario-rol (FK a idn_role_template)

---

## 3. Documentos de referencia obligatoria

Leer en este orden antes de ejecutar cualquier fase:

| Documento | Ruta | Qué aporta |
|-----------|------|-----------|
| **Catálogo de roles** | `REPARACIONBAUTH/BAUTH-CATALOGO-ROLES-EMPRESARIALES.md` | 368 roles: 48 sistémicos (S001-S048) + 174 internos + 146 externos CAEB. Fuente de verdad de QUÉ roles existen. |
| **RolTemplate v6.0** | `REPARACIONBAUTH/SBOS-ROLTEMPLATE-v5_0.md` | Estructura canónica de 14 bloques (B01-B14) + pendientes (B15-B21). Fuente de verdad del CONTENIDO de cada template. |
| **Cadenas de jerarquía** | `REPARACIONBAUTH/BAUTH-CADENAS-JERARQUIA.md` | 186 aristas del DAG. Define parent_id y qué bloques se heredan entre roles. |
| **Informe normativo** | `REPARACIONBAUTH/BAUTH-ORIGEN-NORMATIVO-ROLTEMPLATE-2026-07-08.md` | 85 códigos gap (G-B01-01…G-B21-03). Qué norma exige qué campo en cada bloque. |
| **Demo visual** | `demos/rol-template-builder.html` | Editor/visor HTML de templates. Panel izquierdo = árbol de roles. Panel central = bloques del template. |
| **DDL base** | `DDLs/` — archivos bauth_*.sql activos en VPS | DDL actual. Toda modificación va aquí, nunca ALTER TABLE directo en la VPS. |

---

## 4. Fase 1 — Limpiar los datos falsos

**Sin backup.** Los 31 registros actuales no tienen valor — son datos de prueba sin base en el
catálogo. Se eliminan directamente con CASCADE para que `idn_role_closure` e `idn_user_role`
queden limpias automáticamente.

```sql
-- Eliminar todo — CASCADE limpia closure y user_role
TRUNCATE bauth.idn_role_template CASCADE;

-- Verificar que quedó vacío
SELECT COUNT(*) FROM bauth.idn_role_template;   -- debe retornar 0
SELECT COUNT(*) FROM bauth.idn_role_closure;     -- debe retornar 0
SELECT COUNT(*) FROM bauth.idn_user_role;        -- debe retornar 0
```

**⚠ HITL — Esperar aprobación de Iván antes de ejecutar.**

---

## 5. Fase 2 — Rediseño de arquitectura: del JSONB monolítico al modelo relacional ordenado

### 5.1 Por qué el JSONB monolítico es el problema, no la solución

La columna `template jsonb NOT NULL` de ~86 KB en `idn_role_template` falla en cuatro
dimensiones que el catálogo exige:

| Requisito | Con JSONB monolítico | Con modelo relacional |
|-----------|---------------------|-----------------------|
| Ordenar secciones | Imposible sin reescribir el blob | `ORDER BY seq` en tabla de definiciones |
| Ordenar items dentro de sección | Imposible | `ORDER BY item_seq` en tabla de items |
| Agregar nueva sección sin schema change | Aparente, pero rompe parsers | Insertar fila en `template_block_def` |
| Métodos auth con orden + requisitos propios | Serializado y opaco | Tabla `role_block_item` con `parent_item` |
| Herencia real (CEO → CFO → DIR-FIN) | Copiar 86 KB y editar a mano | Solo almacenar el delta, merge en query |
| Reproducir roles similares | Duplicar blob completo | Nuevo rol apunta a base + inserta solo el delta |
| Consultar "todos los roles con D3 activo" | `WHERE template->'d3'->>'enabled'='true'` lento | `WHERE rb.block_code='B08' AND rb.block_data->>'enabled'='true'` con índice |
| Renderizado HTML por bloque | Deserializa 86 KB para mostrar 1 bloque | Lee solo la fila del bloque que se muestra |

### 5.2 Diseño relacional propuesto

El diseño tiene cuatro tablas nuevas + modificación de `idn_role_template`.
**El JSONB se usa solo donde tiene sentido: en campos escalares heterogéneos de un bloque.**
Los datos ordenados y los items de listas van en tablas relacionales puras.

---

#### TABLA 1 — `bauth.template_block_def` — Catálogo de definiciones de bloques

Define QUÉ bloques existen, en qué orden se presentan, y qué dominio representan.
Esta tabla es la que hace que el sistema sea extensible: agregar un bloque nuevo = insertar una fila aquí.
El orden (`block_seq`) se puede cambiar sin tocar ningún dato de rol.

```sql
CREATE TABLE bauth.template_block_def (
    block_code      text        PRIMARY KEY,          -- 'B01', 'B02', ... extensible
    block_name      text        NOT NULL,
    block_seq       numeric(10,4) NOT NULL,           -- orden de presentación; decimal para insertar entre bloques sin reindexar
    domain_code     integer,                          -- qué dominio D0-D12 corresponde
    domain_label    text,                             -- 'D0 Organizacional', 'D1 Lógico', etc.
    is_readonly     boolean     NOT NULL DEFAULT false, -- B09 SAM-128, B14 Sync = readonly
    is_active       boolean     NOT NULL DEFAULT true,
    block_schema    jsonb,                            -- JSON Schema del bloque para validación
    description     text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

-- Índice para renderizado ordenado
CREATE INDEX idx_tbd_seq ON bauth.template_block_def (block_seq) WHERE is_active = true;
```

**Orden inicial de los 21 bloques (block_seq en múltiplos de 10 — deja espacio para insertar):**

| block_code | block_seq | block_name | domain | readonly |
|------------|-----------|-----------|--------|---------|
| B01 | 10 | Identificación y Metadatos | D0 Organizacional | false |
| B02 | 20 | Vigencia y Ciclo de Vida | D4 Temporal | false |
| B03 | 30 | Flujo de Aprobación | Gobernanza | false |
| B04 | 40 | D1 Autenticación Lógica | D1 Lógico | false |
| B05 | 50 | D2 Acceso Físico | D2 Físico | false |
| B06 | 60 | Zonas de Negocio | D1→Aplicaciones | false |
| B07 | 70 | Privilegios Tryton 5 Capas | ERP | false |
| B08 | 80 | D3 Financiero | D3 Financiero | false |
| B09 | 90 | SAM-128 + BitMask Dual | Engine interno | **true** |
| B10 | 100 | D10 Delegación | D10 Delegación | false |
| B11 | 110 | Grupos H-RBAC | Jerarquía | false |
| B12 | 120 | SoD Conflictos | Gobernanza | false |
| B13 | 130 | D11 Auditoría | D11 Auditoría | false |
| B14 | 140 | Sync State | Engine interno | **true** |
| B15 | 150 | D4 Temporal | D4 Temporal | false |
| B16 | 160 | D5 Biométrico | D5 Biométrico | false |
| B17 | 170 | D6 Geoespacial | D6 Geoespacial | false |
| B18 | 180 | D7 Red y NAC | D7 Red | false |
| B19 | 190 | D8 Contexto Adaptativo | D8 Contexto | false |
| B20 | 200 | D9 Credenciales | D9 Credenciales | false |
| B21 | 210 | D12 Blockchain | D12 Blockchain | false |

*Para insertar un nuevo bloque entre B08 y B09: block_seq = 85. Sin reindexar nada.*

---

#### TABLA 2 — `bauth.template_base` — Plantillas madre por tier y sector

Define los valores por defecto de cada bloque para un tier y sector CAEB.
Cuando se crea un rol nuevo, hereda desde su base. Solo almacena el delta.

```sql
CREATE TABLE bauth.template_base (
    base_id         text        NOT NULL,             -- 'BASE-SU', 'BASE-BIZ-N1', 'BASE-EXT-CAEB-G'
    block_code      text        NOT NULL REFERENCES bauth.template_block_def(block_code),
    tier            text        NOT NULL,
    sector_caeb     text,                             -- NULL = aplica a todos los sectores del tier
    base_name       text        NOT NULL,
    block_data      jsonb       NOT NULL DEFAULT '{}', -- valores escalares por defecto del bloque
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (base_id, block_code)
);
```

---

#### TABLA 3 — `bauth.role_block` — Bloques propios o sobreescritos de un rol

Un rol solo tiene filas aquí para los bloques que DIFIEREN de su padre o de su base.
El 90% de los roles tendrán 2-4 filas en esta tabla, no 14-21.

```sql
CREATE TABLE bauth.role_block (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id         text        NOT NULL REFERENCES bauth.idn_role_template(id) ON DELETE CASCADE,
    block_code      text        NOT NULL REFERENCES bauth.template_block_def(block_code),
    block_data      jsonb       NOT NULL DEFAULT '{}', -- campos escalares del bloque (solo los que cambia)
    inherited_from  text        REFERENCES bauth.idn_role_template(id), -- NULL = es propio de este rol
    is_override     boolean     NOT NULL DEFAULT false, -- true = sobreescribe al padre
    seq_override    numeric(10,4),                     -- si este rol reordena el bloque (NULL = hereda orden de template_block_def)
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (role_id, block_code)
);

CREATE INDEX idx_rb_role ON bauth.role_block (role_id);
CREATE INDEX idx_rb_block ON bauth.role_block (block_code);
CREATE INDEX idx_rb_data  ON bauth.role_block USING gin (block_data); -- para queries cross-rol
```

---

#### TABLA 4 — `bauth.role_block_item` — Items ordenados dentro de un bloque

Esta tabla maneja TODO lo que tiene orden dentro de un bloque:
- Métodos de autenticación (B04): cada método es un item con seq
- Requisitos de un método: sub-items con parent_item FK
- Zonas físicas (B05), zonas de negocio (B06), reglas SoD (B12), eventos de auditoría (B13)
- Señales CAEP (B19), métodos de credencial (B20), contratos de blockchain (B21)

**El `parent_item` permite anidar sin límite de profundidad.**
El `item_seq` con tipo `numeric(10,4)` permite insertar entre items sin reindexar (fractal indexing).

```sql
CREATE TABLE bauth.role_block_item (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id         text        NOT NULL REFERENCES bauth.idn_role_template(id) ON DELETE CASCADE,
    block_code      text        NOT NULL REFERENCES bauth.template_block_def(block_code),
    parent_item     uuid        REFERENCES bauth.role_block_item(id) ON DELETE CASCADE, -- NULL = item raíz del bloque
    item_key        text        NOT NULL,   -- 'am1', 'am2', 'req_phone', 'zone_A', 'sod_001'
    item_label      text,
    item_seq        numeric(10,4) NOT NULL DEFAULT 0, -- orden dentro del bloque o dentro del parent_item
    -- Datos del item
    item_data       jsonb       NOT NULL DEFAULT '{}', -- propiedades del item
    -- Flags de comportamiento
    is_required     boolean     NOT NULL DEFAULT false, -- para métodos auth: ¿obligatorio?
    is_active       boolean     NOT NULL DEFAULT true,
    -- Herencia
    inherited_from  uuid        REFERENCES bauth.role_block_item(id),
    is_override     boolean     NOT NULL DEFAULT false,
    -- Auditoría
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (role_id, block_code, parent_item, item_key)
);

CREATE INDEX idx_rbi_role_block ON bauth.role_block_item (role_id, block_code);
CREATE INDEX idx_rbi_parent     ON bauth.role_block_item (parent_item) WHERE parent_item IS NOT NULL;
CREATE INDEX idx_rbi_seq        ON bauth.role_block_item (role_id, block_code, item_seq);
```

---

### 5.3 Cómo se modelan los métodos de autenticación (caso B04)

Este es el caso más complejo: un método tiene orden, flag de requerido, condiciones de activación,
y requisitos previos del usuario — todo ordenado.

```
B04 — D1 Autenticación
│
├── item_key='am1'  item_seq=10  is_required=true
│   item_data = { "method_id": 1, "method_name": "Password", "aal": 1, "protocol": "LDAP" }
│   │
│   ├── [parent=am1] item_key='cond_1'  item_seq=10
│   │   item_data = { "type": "condition", "expr": "session.new == true" }
│   │
│   ├── [parent=am1] item_key='req_1'  item_seq=10
│   │   item_data = { "type": "requirement", "label": "Contraseña configurada", "check": "credential.password.exists" }
│   │
│   └── [parent=am1] item_key='req_2'  item_seq=20
│       item_data = { "type": "requirement", "label": "No en lista negra HIBP", "check": "credential.password.hibp_clean" }
│
├── item_key='am2'  item_seq=20  is_required=false
│   item_data = { "method_id": 2, "method_name": "TOTP", "aal": 2, "protocol": "RFC6238" }
│   │
│   ├── [parent=am2] item_key='cond_1'  item_seq=10
│   │   item_data = { "type": "condition", "expr": "role.tier IN ('BIZ_N1','BIZ_N2')" }
│   │
│   └── [parent=am2] item_key='req_1'  item_seq=10
│       item_data = { "type": "requirement", "label": "Dispositivo TOTP enrolado", "check": "credential.totp.enrolled" }
│
└── item_key='am4'  item_seq=30  is_required=false
    item_data = { "method_id": 4, "method_name": "WebAuthn Passwordless", "aal": 2, "protocol": "FIDO2" }
    │
    ├── [parent=am4] item_key='req_1'  item_seq=10
    │   item_data = { "type": "requirement", "label": "Dispositivo FIDO2 registrado", "check": "credential.webauthn.registered" }
    │
    └── [parent=am4] item_key='req_2'  item_seq=20
        item_data = { "type": "requirement", "label": "Usuario verificado IAL2", "check": "identity.ial >= 2" }
```

**Para reordenar:** cambiar `item_seq` de 'am2' a 15 → pasa entre am1 (10) y am4 (30). Sin tocar otros registros.
**Para agregar requisito nuevo a am2:** insertar con `item_seq=20` entre req_1(10) y cualquier futuro item.
**Para agregar nuevo método al rol:** insertar con `item_seq=35`. El bloque B04 en `role_block` ni se toca.

---

### 5.4 Principio de herencia delta (cómo funciona)

```
CEO  →  template_base['BASE-BIZ-N1']  →  B01-B21 completos (plantilla madre del tier)
        role_block: 0 filas propias        role_block_item: 0 filas propias
        render_template(CEO) = base completa

CFO  →  parent_id = CEO
        role_block:  1 fila  (B08 — D3 financiero: límites mayores al de CEO)
        role_block_item: 3 filas (B04 — agrega requisito de aprobación para loa>=3)
        render_template(CFO) = base CEO + delta CFO

DIR-FIN → parent_id = CFO
        role_block:  1 fila  (B08 — D3: límites intermedios)
        render_template(DIR-FIN) = base CEO + delta CFO + delta DIR-FIN

CONT-SENIOR → parent_id = DIR-FIN
        role_block:  1 fila  (B07 — Tryton: solo módulo contabilidad)
        role_block_item: 2 filas (B04 — un método menos que DIR-FIN)
        render_template(CONT-SENIOR) = base CEO + delta CFO + delta DIR-FIN + delta CONT-SENIOR
```

Para crear ROL-CAJERO-RETAIL (sector G, comercio):
- Hereda de `template_base['BASE-BIZ-N5']` (tier operativo)
- Solo agrega `role_block` para B06 (zonas negocio: módulo POS) y B07 (Tryton: módulo ventas)
- Dos filas en `role_block`, sin tocar los 19 bloques restantes

Para crear ROL-CAJERO-SALUD (sector Q, salud):
- Misma estructura que ROL-CAJERO-RETAIL
- Solo cambia B06 (zonas negocio: módulo clínica) y B05 (acceso físico: zona farmacia)
- Los demás bloques idénticos se heredan de la base sin duplicar datos

---

### 5.5 Función de renderizado

```sql
CREATE OR REPLACE FUNCTION bauth.render_template(p_role_id text)
RETURNS TABLE (
    block_code   text,
    block_seq    numeric,
    block_name   text,
    block_data   jsonb,
    items        jsonb,
    is_inherited boolean
)
LANGUAGE sql STABLE AS $$
    WITH RECURSIVE role_chain AS (
        -- Construir la cadena de herencia del rol hacia arriba
        SELECT id, parent_id, 0 AS depth
        FROM bauth.idn_role_template
        WHERE id = p_role_id
        UNION ALL
        SELECT r.id, r.parent_id, rc.depth + 1
        FROM bauth.idn_role_template r
        JOIN role_chain rc ON r.id = rc.parent_id
    ),
    effective_blocks AS (
        -- Para cada bloque, tomar el valor del rol más cercano en la cadena (menor depth)
        SELECT DISTINCT ON (rb.block_code)
               rb.block_code,
               rb.block_data,
               rb.role_id != p_role_id AS is_inherited,
               COALESCE(rb.seq_override, bd.block_seq) AS effective_seq,
               bd.block_name
        FROM role_chain rc
        JOIN bauth.role_block rb ON rb.role_id = rc.id
        JOIN bauth.template_block_def bd ON bd.block_code = rb.block_code
        ORDER BY rb.block_code, rc.depth ASC  -- menor depth = más cercano al rol = gana
    )
    SELECT
        eb.block_code,
        eb.effective_seq,
        eb.block_name,
        eb.block_data,
        (
            -- Items del bloque: recursivo para sub-items
            SELECT jsonb_agg(
                jsonb_build_object(
                    'key', item_key,
                    'label', item_label,
                    'seq', item_seq,
                    'required', is_required,
                    'data', item_data,
                    'children', (
                        SELECT jsonb_agg(
                            jsonb_build_object('key', c.item_key, 'seq', c.item_seq, 'data', c.item_data)
                            ORDER BY c.item_seq
                        )
                        FROM bauth.role_block_item c
                        WHERE c.parent_item = rbi.id
                    )
                ) ORDER BY item_seq
            )
            FROM bauth.role_block_item rbi
            WHERE rbi.role_id = p_role_id  -- items siempre del rol concreto (ya con herencia aplicada)
              AND rbi.block_code = eb.block_code
              AND rbi.parent_item IS NULL
        ) AS items,
        eb.is_inherited
    FROM effective_blocks eb
    ORDER BY eb.effective_seq;
$$;
```

**El HTML llama esta función bloque a bloque, no carga el template completo de una vez.**
Cada bloque es una query independiente. Panel central muestra B04 → consulta solo las filas de B04.

---

### 5.6 Modificación a `idn_role_template`

Se elimina la columna monolítica y se agrega referencia a la plantilla base:

```sql
-- Agregar referencia a plantilla base
ALTER TABLE bauth.idn_role_template
    ADD COLUMN base_template_id text REFERENCES bauth.template_base(base_id);

-- Eliminar columna JSONB monolítica (después de migrar datos a role_block)
ALTER TABLE bauth.idn_role_template
    DROP COLUMN template,
    DROP COLUMN template_version;
```

**⚠ HITL — Todo el DDL de esta sección requiere aprobación de Iván antes de ejecutar en VPS.**

---

## 6. Fase 3 — Carga de roles desde el catálogo

### 6.1 Orden de carga (respeta FK parent_id)

```
1. template_block_def  — 21 bloques B01-B21
2. template_base       — plantillas madre por tier/sector
3. Roles SU            — S001 (sin parent_id)
4. Roles SYS N1        — S002-S005 (parent: S001)
5. Roles SYS N2        — S006-S015 (parent: N1 correspondiente)
6. Roles SYS N3        — S016-S019 (parent: N2 correspondiente)
7. Roles M2M           — S020-S048 (parent: N2 o sin parent)
8. Roles internos §3   — 174 roles (BIZ_N1-N5, jerarquía por sector)
9. Actores externos §4 — 146 roles (EXT_N0/VISITANTE, por sector CAEB)
```

### 6.2 Resumen de roles a cargar

| Sección catálogo | Cantidad | Tier | Códigos de muestra |
|-----------------|----------|------|--------------------|
| §2.1 Superusuario | 1 | SU | ROL-SYS-SUPERUSUARIO |
| §2.2 Plataforma N1 | 4 | SYS | ROL-SYS-ADMIN-PROYECTO, -SEGURIDAD, -INFRA, -SRE |
| §2.3 Módulo N2 | 10 | SYS | ROL-SYS-ADMIN-BAUTH, -BKERNEL, -BOS, -VAULT… |
| §2.4 Tenant N3 | 4 | SYS | ROL-SYS-ADMIN-TENANT, -SUCURSAL… |
| §2.5 Bootstrap M2M | 29 | M2M | ROL-SYS-BAUTH-DAEMON, ROL-SYS-BOS-AGENT… |
| §3 Internos negocio | 174 | BIZ_N1-N5 | ROL-CAJERO, ROL-VENDEDOR, ROL-GERENTE-GENERAL… |
| §4 Externos CAEB | 146 | EXT_N0/VIS | ROL-EXT-CLIENTE-MINORISTA, ROL-EXT-PACIENTE-AMBULATORIO… |
| **TOTAL** | **368** | | |

### 6.3 Plantillas base requeridas

| base_id | tier | sector_caeb | Bloques activos | Descripción |
|---------|------|-------------|-----------------|-------------|
| BASE-SU | SU | NULL | B01-B21 | Superusuario: acceso total, todos los bloques |
| BASE-SYS-N1 | SYS | NULL | B01-B14 | Plataforma global |
| BASE-SYS-N2 | SYS | NULL | B01-B13 | Módulo/Daemon |
| BASE-SYS-M2M | M2M | NULL | B01,B04,B09,B13 | Mínimo para M2M: identidad, auth, bitmask, audit |
| BASE-BIZ-N1 | BIZ_N1 | NULL | B01-B14 | Dirección ejecutiva |
| BASE-BIZ-N2 | BIZ_N2 | NULL | B01-B13 | Técnico/Profesional |
| BASE-BIZ-N3 | BIZ_N3 | NULL | B01-B12 | Supervisión |
| BASE-BIZ-N4 | BIZ_N4 | NULL | B01-B10 | Gerencia media |
| BASE-BIZ-N5 | BIZ_N5 | NULL | B01-B07 | Operativo básico |
| BASE-EXT-N0 | EXT_N0 | NULL | B01,B04,B13 | Externo básico (cross-sector) |
| BASE-CAEB-G | EXT_N0 | G | B01,B04,B06,B08,B13 | Comercio: agrega zonas negocio y financiero |
| BASE-CAEB-Q | EXT_N0 | Q | B01,B04,B05,B13 | Salud: agrega acceso físico (zona clínica) |
| BASE-CAEB-P | EXT_N0 | P | B01,B04,B13 | Educación: básico con audit |
| BASE-CAEB-K | EXT_N0 | K | B01,B04,B08,B13 | Financiero: agrega D3 con límites |
| BASE-CAEB-O | EXT_N0 | O | B01,B04,B13 | Administración Pública: ciudadano |
| BASE-VISITANTE | VISITANTE | NULL | B01,B02,B05,B13 | Acceso físico temporal |

---

## 7. Fase 4 — Actualización del demo HTML

Una vez que la DDL y los datos estén correctos, el demo HTML se actualiza para:

1. **Panel izquierdo:** leer árbol desde `idn_role_template` (jerarquía por parent_id, tier, hierarchy_level).
2. **Panel central:** llamar `bauth.render_template(role_id)` — carga bloque a bloque, no el documento completo.
3. **Indicador de herencia:** cada bloque muestra si es `inherited` (del padre), `override` (sobreescrito), o `propio`.
4. **Editor de items ordenados:** arrastrar y soltar para cambiar `item_seq`. Solo actualiza la fila afectada.
5. **Agregar bloque nuevo al sistema:** insertar en `template_block_def` — aparece en todos los roles automáticamente.
6. **Agregar método de auth con requisitos:** insertar item en `role_block_item` + sub-items con `parent_item`.

---

## 8. Secuencia de ejecución y HITL

| # | Fase | Acción | HITL |
|---|------|--------|------|
| 1 | Limpieza | `TRUNCATE bauth.idn_role_template CASCADE` | ✅ Sí |
| 2a | DDL | Crear `template_block_def` | ✅ Sí |
| 2b | DDL | Crear `template_base` | ✅ Sí |
| 2c | DDL | Crear `role_block` | ✅ Sí |
| 2d | DDL | Crear `role_block_item` | ✅ Sí |
| 2e | DDL | Crear función `render_template` | ✅ Sí |
| 2f | DDL | `ALTER TABLE idn_role_template DROP COLUMN template` | ✅ Sí |
| 3a | Seeds | Insertar 21 bloques en `template_block_def` | ✅ Sí |
| 3b | Seeds | Insertar 16 plantillas base en `template_base` | ✅ Sí |
| 3c | Seeds | Cargar 48 roles sistémicos S001-S048 | ✅ Sí |
| 3d | Seeds | Cargar 174 roles internos §3 | ✅ Sí |
| 3e | Seeds | Cargar 146 actores externos §4 | ✅ Sí |
| 4 | HTML | Actualizar demo para leer de BD | No |

---

## 9. Preguntas abiertas — requieren decisión de Iván

| # | Pregunta | Opciones | Impacto |
|---|----------|----------|---------|
| P1 | ¿Los roles internos §3 son genéricos cross-sector o instanciados por sector CAEB? | A) 174 genéricos · B) 174 × sectores aplicables | Define volumen: 174 vs ~600 seeds |
| P2 | ¿`role_block.block_data` (JSONB de escalares) se tipifica por bloque con tabla propia, o JSONB es suficiente para los escalares? | A) JSONB libre · B) Tabla tipada por bloque | Más tipado = más tablas pero validación nativa de BD |
| P3 | ¿Los bloques readonly (B09 SAM-128, B14 Sync) van en `role_block` o en columnas planas de `idn_role_template`? | A) role_block con is_readonly flag · B) columnas planas (actual) | Hoy ya existen como columnas planas (sam128_*, sync_status) — probablemente conservar |
| P4 | ¿`item_data` de `role_block_item` necesita ser consultado cross-rol? | A) JSONB con GIN index · B) columnas tipadas | Si se consulta "todos los roles que tienen método WebAuthn" → necesita GIN o columna |

---

## 10. Archivos que se modificarán

| Archivo | Cambio |
|---------|--------|
| `DDLs/` → nuevo `bauth_40__template_blocks.sql` | DDL de las 4 tablas nuevas + función |
| `DDLs/seeds/bauth_70__template_block_def.sql` | Seeds: 21 bloques B01-B21 |
| `DDLs/seeds/bauth_71__template_base.sql` | Seeds: 16 plantillas base |
| `DDLs/seeds/bauth_72__roles_sistemicos.sql` | Seeds: 48 roles S001-S048 |
| `DDLs/seeds/bauth_73__roles_internos.sql` | Seeds: 174 roles §3 |
| `DDLs/seeds/bauth_74__roles_externos.sql` | Seeds: 146 actores externos §4 |
| DDL existente de `idn_role_template` | DROP COLUMN template, DROP COLUMN template_version, ADD COLUMN base_template_id |
| `context/demos/rol-template-builder.html` | Actualizar renderizado para usar render_template() |

---

*v2.1 · 2026-07-08 · bauth-developer · Revisión pendiente: Iván (HITL para todas las fases DDL)*

---

## 11. Inventario de fuentes de datos por bloque del RolTemplate

Verificado en VPS `13.140.128.230` · schema `bauth` · 172 tablas totales · 2026-07-08

Leyenda: **✅ EXISTE Y POBLADA** · **⚠ EXISTE INCOMPLETA O SIN CONECTAR** · **✗ NO EXISTE — CREAR**

---

### B01 — Identificación y Metadatos del Rol

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| id, tier, hierarchy_level, parent_id, status, version | `bauth.idn_role_template` (columnas planas) | ✅ | 31 (falsos) | Columnas correctas, datos a reemplazar |
| metadata.classification (ISO 27001 A.5.12) | — | ✗ | — | No existe columna ni tabla. Agregar columna `classification` a `idn_role_template` |
| digital_signature.algorithm | `bauth.bos_crypto_algorithm` | ⚠ | — | Existe el catálogo de algoritmos, falta conectar FK al rol |
| Historial de versiones del rol | `bauth.bos_rol_template_history` | ⚠ | — | Existe la tabla de historial pero sin datos |

---

### B02 — Vigencia y Ciclo de Vida

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| start_time, expiry_time | `bauth.idn_role_template` (columnas planas) | ✅ | — | Ya existen como columnas |
| review_date, renewal_settings | — | ✗ | — | No existe. Agregar columnas a `idn_role_template` o a `role_block` B02 |
| Calendario laboral / schedule | `bauth.idn_calendar_assignment` | ⚠ | — | Existe para usuarios, no para roles |
| Políticas de vigencia (max_renewals, rotation) | `bauth.ath_policy_d4` | ⚠ | — | Existe tabla de políticas D4, no conectada al template del rol |
| Configuración temporal D4 | `bauth.ath_config_d4` | ⚠ | — | Existe, sin conectar al template del rol |

---

### B03 — Flujo de Aprobación

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| required_approvers, approver_roles[] | — | ✗ | — | No existe tabla de workflow de aprobación para roles. `fin_approval_chain` es solo para finanzas |
| sla_hours, escalation | `bauth.idn_tier_policy` | ⚠ | — | Existe tabla de política por tier pero no cubre el workflow de aprobación de activación del rol |
| Cadena de aprobación financiera (referencia) | `bauth.fin_approval_chain` | ✅ | — | Útil como referencia de diseño. No aplica directamente a B03 |

**Acción requerida:** crear tabla `bauth.role_approval_workflow` o cubrir con `role_block_item` de B03.

---

### B04 — D1 Autenticación Lógica

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| **Catálogo de métodos** (32 métodos) | `bauth.ath_method` | ✅ | **32** | Completo: method_id, method_name, method_type, aal_level, applies_to[], config JSONB, domain_classification |
| **Flujos de autenticación** | `bauth.ath_auth_flow` | ✅ | — | Flujos definidos |
| **Método en flujo** (con orden) | `bauth.ath_auth_flow_method` | ⚠ | — | Existe, pero el ORDEN de métodos por ROL no está formalizado — va en `role_block_item` |
| **Step-up rules** | `bauth.ath_step_up_rule` | ✅ | **8** | 8 reglas definidas con trigger, acr_target, max_age |
| **Configuración D1 por política** | `bauth.ath_config_d1` | ✅ | — | Configuración del dominio D1 |
| **Políticas D1** | `bauth.ath_policy_d1` | ✅ | — | Políticas CFG_POLICY_LIB para D1 |
| **Biblioteca de políticas** | `bauth.cfg_policy_library` | ✅ | **9,874** | Árbol completo de políticas con section_id, json_path, depth, order_index, content JSONB |
| **Atributos D1** (email, phone, ci) | `bauth.idn_user_template` | ⚠ | **9** | Solo 9 plantillas de usuario; atributos de ROL no formalizados |
| **Link rol → métodos con orden y requisitos** | — | ✗ | — | Esta es la brecha: `role_block_item` B04 que se propone en §5.3 no existe aún |

**Métodos disponibles en `ath_method`:** PASSWORD, TOTP, HOTP, WEBAUTHN_PWDLESS, WEBAUTHN_2FA, PASSKEY_DEVICE, PASSKEY_SYNCED, SMARTCARD_X509, FACE_ID, TOUCH_ID, ANDROID_BIOMETRIC, WINDOWS_HELLO, YUBIKEY_FIDO2, YUBIKEY_OTP, NITROKEY_FIDO2, PUSH_NOTIFICATION, EMAIL_OTP, EMAIL_OTP_2FA, CIBA, OAUTH2_AUTH_CODE, OIDC_HYBRID, SAML2_POST, TOKEN_EXCHANGE, CLIENT_CREDENTIALS, RISK_BASED_AUTH, STEP_UP_CONDITIONAL, BACKUP_CODES, RECOVERY_EMAIL, SMS_OTP (deprecated), BASIC_AUTH (deprecated), BEARER_TOKEN_STATIC (deprecated), WHATSAPP_OTP.

---

### B05 — D2 Acceso Físico

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| Zonas físicas (edificios, pisos, salas) | `bauth.fis_location` | ✅ | — | location_type, security_zone, coordinates, country_code |
| Zonas de acceso agrupadas | `bauth.fis_access_zone` | ✅ | — | Zonas nombradas con nivel de seguridad |
| Miembros de zona | `bauth.fis_zone_member` | ✅ | — | FK zona → entidad |
| Requisito de método por zona | `bauth.fis_zone_method_requirement` | ✅ | — | Qué método de auth exige cada zona |
| Dispositivos PACS (lectores, cámaras) | `bauth.fis_device` | ✅ | — | device_type, protocol (OSDP/WIEGAND/ONVIF) |
| Controladores de acceso | `bauth.fis_controller` | ✅ | — | |
| Configuración de área | `bauth.fis_area_config` | ✅ | — | |
| Emergencia / anti-passback | `bauth.fis_emergency_config` | ✅ | — | |
| Configuración D2 / Políticas D2 | `bauth.ath_config_d2` / `ath_policy_d2` | ✅ | — | |
| **Link rol → zonas permitidas con schedule** | `bauth.idn_role_d2` | ⚠ | — | Existe la tabla (role_id, domain_code, config JSONB) pero sin datos de roles reales. Necesita poblar. |
| Enrolamiento biométrico por zona | `bauth.ath_config_d5` / `ath_policy_d5` | ✅ | — | Ya existe — no crear tablas nuevas bio_* |

---

### B06 — Zonas de Negocio (Aplicaciones)

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| Mapeo zona → aplicación | `bauth.zone_application_map` | ✅ | — | zona_id, app_code, permisos |
| Política de datos por zona | `bauth.zone_data_policy` | ✅ | — | pii_access, classification |
| Permisos lógicos | `bauth.bos_permiso_logico` | ✅ | — | |
| Configuración D1 zonas | `bauth.ath_config_d1` | ✅ | — | |
| **Link rol → zonas negocio ordenadas** | `bauth.idn_role_d1` | ⚠ | — | Existe (role_id, config JSONB) pero sin datos de roles reales. Es el conector que necesita poblar. |
| scope (REGIONAL/NACIONAL), pii_access flag | — | ✗ | — | No hay columna explícita en idn_role_d1. Agregar a `role_block` B06 |

---

### B07 — Privilegios Tryton 5 Capas

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| Capa 1: ir.model.access (CRUD) | `bauth.privilege_atom` | ✅ | **5,808** | 5808 átomos que incluyen los permisos CRUD de Tryton |
| Capa 2: ir.action.groups (menús) | `bauth.tryton_action_visibility` | ✅ | — | Visibilidad de acciones por rol |
| Capa 3: ir.model.field (campos) | `bauth.zone_field_restriction` | ✅ | — | Restricciones de campo |
| Capa 4: ir.model.button (PYSON) | `bauth.zone_button_rule` | ✅ | — | Reglas de botón con PYSON |
| Capa 5: ir.rule (filtros SQL) | `bauth.zone_record_rule` | ✅ | — | Reglas de registro por zona |
| **Link rol → átomos Tryton** | `bauth.privilege_role_atom` | ⚠ | — | Existe la tabla de mapeo rol-átomo pero sin datos de roles reales |
| Políticas Tryton | `bauth.privilege_atom_policy` | ✅ | **2,376 KB** | Muy completa |

---

### B08 — D3 Financiero

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| Límites de transacción | `bauth.fin_limit` | ✅ | — | max_amount, currency, period |
| Tipos de transacción | `bauth.fin_transaction_type` | ✅ | — | |
| Cadena de aprobación financiera | `bauth.fin_approval_chain` | ✅ | — | |
| Niveles de aprobación | `bauth.fin_approval_level` | ✅ | — | |
| Matriz de decisión | `bauth.fin_decision_matrix` | ✅ | — | approval_required_above, dual_control |
| Permisos financieros por rol | `bauth.fin_role_permission` | ✅ | — | |
| Configuración D3 / Políticas D3 | `bauth.ath_config_d3` / `ath_policy_d3` | ✅ | — | |
| **Link rol → límites financieros** | `bauth.idn_role_d3` | ⚠ | — | Existe (role_id, config JSONB), sin datos de roles reales |
| currency ISO 4217, modalidad SIN, firma Ley 164 | `bauth.ath_config_d3` | ⚠ | — | Probablemente cubierto en config JSONB — verificar antes de crear campos nuevos |

---

### B09 — SAM-128 + BitMask Dual (READONLY)

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| sam128_physical/logical/financial/governance | `bauth.idn_role_template` (columnas planas) | ✅ | — | Ya existen como columnas `numeric(20,0)` — **conservar como columnas planas, no mover a role_block** |
| rol_bitmask_base64 | `bauth.idn_role_template` (columna plana) | ✅ | — | Ya existe — conservar |
| Algoritmo de cálculo | `bauth.privilege_atom` + PrivilegeEngine (Rust) | ✅ | — | Se calcula, no se almacena manualmente |

---

### B10 — D10 Delegación

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| Delegaciones activas | `bauth.dlg_delegation` | ✅ | — | delegante, delegado, scope, expiry |
| Configuración D10 / Políticas D10 | `bauth.ath_config_d10` / `ath_policy_d10` | ✅ | — | |
| **Link rol → reglas de delegación** | `bauth.idn_role_d10` | ⚠ | — | Existe, sin datos de roles reales |
| can_delegate, delegation_depth, max_duration | — | ✗ | — | No existen como campos propios del rol. Van en `role_block` B10 o en columnas de idn_role_d10 |
| Token Exchange RFC 8693 config | `bauth.ath_federation_protocol` | ⚠ | — | Existe tabla de protocolos de federación — verificar si cubre Token Exchange |

---

### B11 — Grupos H-RBAC

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| DAG de herencia de roles | `bauth.idn_role_closure` | ✅ | — | Closure table para el DAG — correcta y lista |
| Jerarquía parent_id | `bauth.idn_role_template` (columna) | ✅ | — | |
| path_ids[] | `bauth.idn_role_template` (columna) | ✅ | — | |
| **Grupos funcionales con quórum** | — | ✗ | — | No existe tabla de grupos con quórum (k-de-n). Crear `bauth.role_group` y `bauth.role_group_member` |

---

### B12 — SoD Conflictos

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| Reglas SoD financieras | `bauth.fin_sod_rule` | ✅ | **6** | 6 reglas, cubren SoD financiero |
| Configuración de validación SoD | `bauth.sod_validation_config` | ✅ | — | |
| Política de conflicto de interés | `bauth.conflict_interest_policy` | ✅ | — | |
| **incompatible_roles[] por rol** | — | ✗ | — | No hay tabla que vincule un ROL con sus roles incompatibles. Crear `bauth.role_sod_constraint` o cubrir con `role_block_item` B12 |
| max_concurrent_roles_per_user (DSC) | — | ✗ | — | No existe. Campo en `role_block` B12 |
| Proceso de excepción SoD (SOX) | — | ✗ | — | No existe. Campo en `role_block` B12 |

---

### B13 — D11 Auditoría

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| Eventos de auditoría (particionada) | `bauth.aud_event` / `aud_event_2026_07` | ✅ | — | 23 columnas, particionada por mes |
| Mapeo de cumplimiento normativo | `bauth.aud_compliance_map` | ✅ | — | |
| Versiones de política | `bauth.aud_policy_version` | ✅ | — | |
| Revisiones periódicas | `bauth.aud_review` | ✅ | — | |
| Cuentas fantasma / privilege creep | `bauth.aud_ghost_account` | ✅ | — | |
| Cambios de política | `bauth.aud_policy_change` | ✅ | — | |
| Estándares de cumplimiento | `bauth.compliance_standard` / `compliance_requirement` | ✅ | — | |
| Configuración D11 / Políticas D11 | `bauth.ath_config_d11` / `ath_policy_d11` | ✅ | — | La más grande: 240 KB en políticas |
| **Qué eventos audita ESTE ROL** | `bauth.idn_role_d11` | ⚠ | — | Existe la tabla, sin datos de roles reales. Poblar. |
| review_frequency, retention_days por rol | — | ✗ | — | No existe campo específico por rol. Van en `role_block` B13 |

---

### B14 — Sync State (READONLY)

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| sync_status, sync_error, last_sync_at | `bauth.idn_role_template` (columnas planas) | ✅ | — | Ya existen — **conservar como columnas planas** |
| Log de sincronización | `bauth.sync_log` | ✅ | — | |

---

### B15 — D4 Temporal

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| Configuración D4 | `bauth.ath_config_d4` | ✅ | — | |
| Políticas D4 | `bauth.ath_policy_d4` | ✅ | — | |
| Asignación de calendarios | `bauth.idn_calendar_assignment` | ✅ | — | Existe para usuarios; conectar a roles |
| **Link rol → restricciones temporales** | `bauth.idn_role_d4` | ⚠ | — | Existe, sin datos. timezone, work_schedule_id van aquí |
| token_max_age_s, session_idle_timeout_s | `bauth.idn_role_template` (`session_timeout` columna) | ⚠ | — | `session_timeout` existe pero `token_max_age_s` diferente — revisar |

---

### B16 — D5 Biométrico

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| Configuración D5 (liveness, quality) | `bauth.ath_config_d5` | ✅ | — | **YA EXISTE con patrón JSONB correcto** — no crear tablas nuevas |
| Políticas D5 (PAD, GDPR) | `bauth.ath_policy_d5` | ✅ | — | **YA EXISTE** |
| Log de enrolamiento | `bauth.ath_enrollment_log` | ✅ | — | |
| Enrolamiento MFA (biométrico) | `bauth.ath_mfa_enrollment` | ✅ | — | |
| Atestación de dispositivo | `bauth.device_attestation_log` | ✅ | — | |
| **Link rol → requisitos biométricos** | `bauth.idn_role_d5` | ⚠ | — | Existe, sin datos. Poblar con liveness_level, gdpr_legal_basis |

---

### B17 — D6 Geoespacial

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| Geofences | `bauth.geo_fence` | ✅ | — | allowed_countries, radius, coordinates |
| Tiers de confianza geográfica | `bauth.geo_trust_tier` | ✅ | — | |
| Política de velocidad imposible | `bauth.geo_velocity_policy` | ✅ | — | impossible_travel_detection |
| Log de evaluación geográfica | `bauth.geo_evaluation_log` | ✅ | — | |
| Configuración D6 / Políticas D6 | `bauth.ath_config_d6` / `ath_policy_d6` | ✅ | — | |
| **Link rol → política geoespacial** | `bauth.idn_role_d6` | ⚠ | — | Existe, sin datos. allowed_regions[], require_vpn_outside, block_tor van aquí |

---

### B18 — D7 Red y NAC

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| Dispositivos de red | `bauth.net_device` | ✅ | — | 19 columnas |
| Políticas ZTNA | `bauth.net_ztna_policy` | ✅ | — | |
| Configuración D7 / Políticas D7 | `bauth.ath_config_d7` / `ath_policy_d7` | ✅ | **328 KB** | La más grande en políticas — bien cubierta |
| Configuración de certificados (mTLS) | `bauth.certificate_pin_config` / `certification_certificate` | ✅ | — | |
| **Link rol → política de red** | `bauth.idn_role_d7` | ⚠ | **152 KB** | La más grande de las idn_role_d*. Existe, datos de prueba. Necesita roles reales. |
| allowed_cidr[], block_cidr[], rate_limit_rpm | Probablemente en `idn_role_d7.config` JSONB | ⚠ | — | Verificar estructura antes de crear campos nuevos |

---

### B19 — D8 Contexto Adaptativo

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| Configuración CAEP | `bauth.ses_caep_config` | ✅ | — | signals_enabled[], revoke_on_anomaly |
| Políticas de riesgo | `bauth.ses_risk_policy` | ✅ | — | risk_engine_provider, thresholds |
| Contexto de sesión | `bauth.ses_context` | ✅ | — | 28 columnas, muy completo |
| Cambios de contexto | `bauth.ses_context_switch` | ✅ | — | |
| Configuración D8 / Políticas D8 | `bauth.ath_config_d8` / `ath_policy_d8` | ✅ | — | |
| **Link rol → señales CAEP y acciones** | `bauth.idn_role_d8` | ⚠ | — | Existe, sin datos. Señales (session_revoked, impossible_travel…) con su acción ordenada van en `role_block_item` B19 |
| emergency_access_allowed por rol | `bauth.emergency_override_policy` | ⚠ | — | Existe la política global, falta conectar al rol específico |

---

### B20 — D9 Credenciales

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| Políticas de credenciales (rotación, HIBP) | `bauth.ath_credential_policy` | ✅ | **20 cols** | Completa: rotation_trigger, revocation_channels, recovery_ial, max_age_days |
| Historial de passwords | `bauth.ath_password_history` | ✅ | — | |
| Cribado HIBP | `bauth.ath_password_screening` | ✅ | — | |
| Revocación | `bauth.ath_revocation` | ✅ | — | |
| Log de rotación | `bauth.ath_rotation_log` | ✅ | — | |
| Métodos de recuperación | `bauth.ath_recovery_method` | ✅ | — | |
| Desafíos de recuperación | `bauth.ath_recovery_challenge` | ✅ | — | |
| Inventario de claves | `bauth.sec_key_inventory` / `sec_key_rotation` / `sec_key_recovery` | ✅ | — | |
| Configuración D9 / Políticas D9 | `bauth.ath_config_d9` / `ath_policy_d9` | ✅ | — | |
| **Link rol → ciclo vida credencial por método** | `bauth.idn_role_d9` | ⚠ | — | Existe. Cada método (PASSWORD, TOTP, WEBAUTHN…) con su rotation/revocation/recovery ordenados van en `role_block_item` B20 |

---

### B21 — D12 Blockchain

| Dato del bloque | Tabla fuente | Estado | Filas | Observación |
|----------------|-------------|--------|-------|-------------|
| Cuentas blockchain (wallet) | `bauth.blk_account` | ✅ | — | wallet_address, chain_id, signing_algo |
| Anclas de auditoría | `bauth.blk_anchor` | ✅ | — | |
| Lotes Merkle | `bauth.blk_merkle_batch` / `blk_merkle_leaf` | ✅ | — | |
| Reconciliación blockchain | `bauth.blk_reconciliation` | ✅ | — | |
| Algoritmos criptográficos | `bauth.bos_crypto_algorithm` | ✅ | — | Ed25519, RSA-SHA256, ECDSA secp256k1 |
| Configuración D12 / Políticas D12 | `bauth.ath_config_d12` / `ath_policy_d12` | ✅ | — | |
| **Link rol → config blockchain** | `bauth.idn_role_d12` | ⚠ | — | Existe. blockchain_enabled, chain_id, ley164_compliance van aquí |
| adsib_cert_serial, adsib_cert_expiry | `bauth.certification_certificate` | ✅ | — | |

---

## 12. Resumen consolidado del inventario

### Qué ya existe y está poblado (fuentes listas para usar)

| Categoría | Tablas | Filas clave |
|-----------|--------|-------------|
| Catálogo de métodos de autenticación | `ath_method` | 32 métodos |
| Átomos de privilegio | `privilege_atom`, `privilege_domain`, `privilege_verb` | 5,808 átomos · 12 dominios · 50 verbos |
| Biblioteca de políticas | `cfg_policy_library` | 9,874 entradas |
| Políticas por dominio D1-D12 | `ath_policy_d1` … `ath_policy_d12` | 12 tablas |
| Configuración por dominio D1-D12 | `ath_config_d1` … `ath_config_d12` | 12 tablas |
| Infraestructura física D2 | `fis_location`, `fis_device`, `fis_zone_member` | Completa |
| Finanzas D3 | `fin_limit`, `fin_decision_matrix`, `fin_approval_chain` | Completa |
| Geoespacial D6 | `geo_fence`, `geo_velocity_policy`, `geo_trust_tier` | Completa |
| Contexto D8 | `ses_caep_config`, `ses_risk_policy`, `ses_context` | Completa |
| Credenciales D9 | `ath_credential_policy`, `ath_revocation`, `ath_rotation_log` | Completa |
| Auditoría D11 | `aud_event`, `aud_compliance_map`, `aud_review` | Completa |
| Blockchain D12 | `blk_account`, `blk_anchor`, `bos_crypto_algorithm` | Completa |
| Tryton 5 capas | `zone_*`, `tryton_action_visibility` | Completa |
| Step-up rules | `ath_step_up_rule` | 8 reglas |
| DAG herencia roles | `idn_role_closure` | Lista |

### Qué existe pero no está conectado al template del rol (idn_role_d1…d12)

**Estas 12 tablas son el puente entre `idn_role_template` y las fuentes de datos.**
Todas existen, todas tienen la estructura correcta (`role_id`, `domain_code`, `config JSONB`),
pero ninguna tiene datos de roles reales porque los roles mismos son falsos.
**Al cargar los 368 roles reales, estas tablas se pueblan en cascada.**

| Tabla | Dominio | Contenido esperado |
|-------|---------|-------------------|
| `idn_role_d1` | D1 Lógico | Métodos permitidos, LoA, step-up, zonas de negocio |
| `idn_role_d2` | D2 Físico | Zonas permitidas, schedule, anti-passback |
| `idn_role_d3` | D3 Financiero | Límites, currency, modalidad SIN, firma Ley 164 |
| `idn_role_d4` | D4 Temporal | Timezone, calendario laboral, token TTL |
| `idn_role_d5` | D5 Biométrico | Liveness_level, quality_threshold, GDPR basis |
| `idn_role_d6` | D6 Geoespacial | Allowed_regions, block_tor, velocity_policy |
| `idn_role_d7` | D7 Red | Allowed_CIDR, mTLS, rate_limit_rpm |
| `idn_role_d8` | D8 Contexto | CAEP signals + acciones, risk_engine, emergency |
| `idn_role_d9` | D9 Credenciales | Ciclo vida por método (rotation, revocation, recovery) |
| `idn_role_d10` | D10 Delegación | can_delegate, depth, max_duration, allowed_to[] |
| `idn_role_d11` | D11 Auditoría | audit_events[], review_frequency, retention_days |
| `idn_role_d12` | D12 Blockchain | blockchain_enabled, chain_id, ley164, smart_contract_perms |

### Qué falta crear (tablas nuevas — HITL requerido)

| Tabla nueva | Para qué bloque | Qué cubre |
|-------------|----------------|-----------|
| `bauth.template_block_def` | Definición sistema | Catálogo de bloques B01-B21, orden extensible |
| `bauth.template_base` | Bases por tier | Plantillas madre por tier/sector CAEB |
| `bauth.role_block` | Todos los bloques | Delta del template por rol |
| `bauth.role_block_item` | B04,B05,B06,B07,B12,B13,B19,B20 | Items ordenados con sub-items (métodos, zonas, señales) |
| `bauth.role_approval_workflow` | B03 | Flujo de aprobación de activación del rol |
| `bauth.role_group` + `role_group_member` | B11 | Grupos funcionales con quórum k-de-n |
| `bauth.role_sod_constraint` | B12 | Pares de roles mutuamente excluyentes (o usar role_block_item) |

### Campos que faltan en tablas existentes

| Tabla | Campo faltante | Bloque | Norma |
|-------|---------------|--------|-------|
| `idn_role_template` | `classification` (PUBLIC/INTERNAL/CONFIDENTIAL/RESTRICTED) | B01 | ISO 27001 A.5.12 |
| `idn_role_template` | `base_template_id FK → template_base` | Sistema | Propuesta §5.6 |
| `idn_role_template` | DROP COLUMN `template` (monolítico) | Sistema | Propuesta §5.6 |
| `idn_role_d10` | `can_delegate`, `delegation_depth`, `max_duration_hours` | B10 | NIST AC-6(3) |
| `idn_role_d11` | `review_frequency_days`, `retention_days` | B13 | PCI DSS Req 10.7 |
