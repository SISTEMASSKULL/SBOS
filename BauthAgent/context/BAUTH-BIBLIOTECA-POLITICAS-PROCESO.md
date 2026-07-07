# BAUTH — Biblioteca de Políticas: Proceso y Arquitectura
**Versión:** 1.0 · **Fecha:** 2026-07-07 · **Autor:** bauth-developer
**Estándares:** NIST SP 800-207 · XACML 3.0 · ISO 27001:2022

---

## 1. ¿Qué es `cfg_policy_library`?

`cfg_policy_library` es el **catálogo canónico de ingredientes normativos** de bAuth.
Contiene 9,874 nodos organizados en un árbol jerárquico alineado con XACML 3.0 y NIST SP 800-207.

Su propósito: el SU (Super Usuario) compone roles y usuarios seleccionando
**RULES de esta biblioteca** — en lugar de editar valores libres. Esto garantiza
*compliance by design*: todo valor disponible viene de un estándar (NIST SP 800-63B, ISO 27001,
FIDO2, RFC 6749, etc.).

**Distinción crítica — tres tablas, tres responsabilidades:**

```
cfg_policy_library   =  CATÁLOGO      ¿qué CAN configurarse?   Normativo · inmutable en runtime
cfg_tenant_config    =  COMPOSICIÓN   ¿qué IS configurado?     El SU elige de la biblioteca
cfg_rule_evaluation  =  EVALUACIÓN    ¿qué SE APLICA?          PDP evalúa en runtime
```

`cfg_policy_library` nunca cambia en runtime. Solo cambia mediante migraciones SQL auditadas (HITL).

---

## 2. Jerarquía XACML 3.0

```
FRAMEWORK  →  DOMAIN  →  POLICY_SET  →  POLICY  →  RULE  →  PROPERTY
```

| level_type   | node_type  | Nodos | Descripción |
|---|---|---|---|
| FRAMEWORK    | `section`  |    59 | Raíz de árbol — fuente de datos |
| DOMAIN       | `group`    |   157 | Agrupación temática (D1–D12, D99) |
| POLICY_SET   | `group`    |   680 | Contenedor de sub-políticas (XACML PolicySet) |
| POLICY       | `policy`   |   661 | Política evaluable — contiene RULES directamente |
| RULE         | `group`    | 2,449 | Regla atómica: condición + efecto |
| PROPERTY     | `config`   | 5,868 | Atributo con valor: tipo + default + opciones |
| **Total**    |            | **9,874** | |

El campo `node_type` acepta solo: `'section'`, `'group'`, `'policy'`, `'config'`.

### Tipos de valor en PROPERTY

| value_type | Count | Widget UI recomendado |
|---|---|---|
| TEXT       | 3,623 | TextInput o Dropdown (si tiene enum_options) |
| BOOLEAN    | 1,620 | Toggle |
| INTEGER    |   448 | NumberInput (entero) |
| FLOAT      |   127 | NumberInput (decimal) |
| ENUM       |    46 | Dropdown (enum_options obligatorio) |

---

## 3. Origen de los datos — fuentes históricas

La biblioteca se construyó en cuatro migraciones a partir de tres fuentes distintas:

```
Fuente 1: Authentication_Framework.json     (603 KB · v2.0.0 · 36 grupos)
Fuente 2: Policies_Authentication_Framework_v4.json (104 KB · v4.0.0 · 27 grupos)
                    │
                    │  bauth_fw_01..bauth_fw_16 (parseo inicial)
                    ▼
Fuente 3: ath_config_d1..d12  (174 filas · configuraciones por dominio)
          ath_policy_d1..d12  (884 filas · políticas por dominio)
                    │
                    │  bauth_43__cfg_policy_library_seeds_from_ath.sql
                    ▼
                 cfg_policy_library
                  9,874 nodos · árbol ltree completo
```

### Migraciones estructurales (una sola vez en instalación nueva)

| Migración | Acción | Resultado |
|---|---|---|
| `bauth_40__cfg_policy_library_ltree.sql` | Agrega columna `path ltree` + 6 columnas operacionales + 4 índices | Tabla estructurada con `path` |
| `bauth_41__cfg_policy_library_level_type.sql` | Clasifica todos los nodos con `level_type` · corrige `value_type` · puebla `default_value` | 9,184 nodos clasificados |
| `bauth_42__policy_set_split_and_compose.sql` | Separa POLICY_SET vs POLICY (XACML 3.0) · crea funciones · crea vista | `fn_compose_tree`, `fn_decompose_tree`, `v_policy_tree` |
| `bauth_43__cfg_policy_library_seeds_from_ath.sql` | Consolida 690 nodos de ath_config/policy_dN + 19 políticas extendidas + 415 enum_options | 9,874 nodos totales |

---

## 4. ¿Siguen haciendo falta los archivos JSON?

**No para operación ni instalación.** Los datos de los JSON están completamente importados en la
base de datos. Los archivos originales se conservan como **referencia archivada** en:

```
context/plandeaccion/Authentication_Framework.json         ← archivo fuente original
context/plandeaccion/Authentication_Framework_v3.json      ← versión intermedia
context/plandeaccion/Policies_Authentication_Framework_v4.json ← archivo fuente original
```

Estos archivos **no deben eliminarse** (son la fuente de verdad conceptual), pero **no son
necesarios para instalar ni operar bAuth**. La base de datos es ahora la fuente de verdad
operacional.

---

## 5. Proceso de instalación — flujo con seed

### Instalación fresca (recomendado — sin migraciones intermedias)

```bash
# 1. Crear la base de datos con estructura
psql -U postgres -d SBOS_db -f DDLs/sbos_00__esquema_base.sql
psql -U postgres -d SBOS_db -f DDLs/seeds/bauth_76__cfg_policy_library_master.sql  # DDL bauth

# 2. Cargar el seed canónico — REEMPLAZA los pasos bauth_40..43
psql -U postgres -d SBOS_db -f DDLs/seeds/bauth_76__cfg_policy_library_master.sql

# Resultado: 9,874 nodos listos sin necesidad de los archivos JSON ni de ath_config/policy_dN
```

### Actualización de instalación existente (ya tenía datos)

```bash
# Aplicar las migraciones estructurales en orden
psql -U postgres -d SBOS_db -f DDLs/migrations/bauth_40__cfg_policy_library_ltree.sql
psql -U postgres -d SBOS_db -f DDLs/migrations/bauth_41__cfg_policy_library_level_type.sql
psql -U postgres -d SBOS_db -f DDLs/migrations/bauth_42__policy_set_split_and_compose.sql
psql -U postgres -d SBOS_db -f DDLs/migrations/bauth_43__cfg_policy_library_seeds_from_ath.sql
```

### El seed `bauth_76__cfg_policy_library_master.sql` (versiones)

| Versión | Fecha | Nodos | Cambio |
|---|---|---|---|
| v1.0.0 | 2026-07-07 | 9,184 | Importación inicial de los dos JSON files |
| v2.0.0 | 2026-07-07 | 9,874 | +690 nodos de ath_config/policy_dN + enum_options |

**El seed v2.0 (bauth_76 actualizado) es la fuente de instalación canónica.**
Para reinstalar desde cero: ejecutar bauth_76 → hace TRUNCATE CASCADE + COPY de 9,874 filas.

---

## 6. Cómo añadir nuevas políticas

Hay dos caminos según la naturaleza del cambio:

### Camino A — Nueva política puntual (pocos nodos)

```sql
-- En una migración bauth_NN__nueva_politica.sql:
INSERT INTO bauth.cfg_policy_library (
    section_name, parent_path, json_path, path, depth, order_index,
    node_type, level_type, source, domain_map, is_required,
    content, content_en, content_es
) VALUES (
    'nueva_politica',
    'sbosSeeds.D3',
    'sbosSeeds.D3.nueva_politica',
    'sbosSeeds.D3.nueva_politica'::ltree,
    3, 99,
    'policy', 'POLICY', 'manual_v1', ARRAY['D3'], false,
    '{}'::jsonb, '{}'::jsonb, '{}'::jsonb
);
-- Luego actualizar bauth_76 con el nuevo estado completo del seed
```

### Camino B — Importar un documento JSON/YAML completo

```sql
-- Usar fn_decompose_tree() para descomponer el árbol desde JSONB:
SELECT bauth.fn_decompose_tree(
    '{ "nueva_politica": { "propiedad": { "_type": "BOOLEAN", "_value": "true" } } }'::jsonb,
    'sbosSeeds.D3'::ltree,
    'importacion_manual_v1'
);
```

### Regla de oro: actualizar el seed después de cualquier cambio

Después de cada cambio aprobado (HITL), regenerar bauth_76 desde la VPS:
```bash
pg_dump -U postgres -d SBOS_db --data-only --table=bauth.cfg_policy_library \
  --no-privileges --no-tablespaces > DDLs/seeds/bauth_76__cfg_policy_library_master.sql
```
Luego agregar el encabezado canónico (ver §7) y committer.

---

## 7. Encabezado canónico del seed (bauth_76)

Todo seed de `cfg_policy_library` debe llevar este encabezado antes del bloque COPY:

```sql
-- SEED: bauth_76__cfg_policy_library_master.sql
-- Versión      : 2.0.0
-- Fecha        : YYYY-MM-DD
-- Filas        : N
-- Origen       : Exportado desde VPS (sbos-data/postgresql-0 · SBOS_db)
--                después de migraciones bauth_40..bauth_43
-- Uso          : TRUNCATE CASCADE + COPY — para instalación fresca o restauración
-- Normas       : NIST RBAC N3, NIST SP 800-63B Rev.4, ISO 27001:2022,
--                PCI DSS 4.0, FIDO2/WebAuthn, Bolivia Ley 164, RFC 7519/6238/8693
-- Aprobado por : [nombre] (HITL — fecha)
```

---

## 8. Los `enum_options` y la UI

Los nodos PROPERTY con `value_type = 'TEXT'` o `'ENUM'` pueden tener un vocabulario controlado
en la columna `enum_options TEXT[]`. La UI usa este campo para mostrar un **dropdown** en lugar
de un campo de texto libre.

```sql
-- Ver propiedades con vocabulario controlado
SELECT section_name, value_type, default_value, enum_options
FROM bauth.cfg_policy_library
WHERE enum_options IS NOT NULL AND level_type = 'PROPERTY'
ORDER BY path
LIMIT 20;
```

Distribución actual: **1,090 propiedades** con `enum_options` (la mayoría TEXT con vocabulario
restringido, 46 son tipo ENUM formalmente declarado).

**Grupos de vocabulario representados (30 grupos temáticos):**
`aal`, `action`, `algorithm`, `auth_factor`, `biometric_type`, `chain_standard`,
`classification`, `compliance_framework`, `conditional`, `consistency`, `curve`,
`delegation_type`, `hash`, `ial`, `key_exchange`, `lifecycle`, `logging`, `mode`,
`network`, `record_type`, `retention`, `rotation`, `step_up`, `tier`, `token_type`,
`type`, `updateFrequency`, `user_verification`, `wallet_type`, `webauthn_type`

---

## 9. D99 — Dominio Administrativo Global

D99 es el único dominio que **no entra al BitMask 64-bit**. Contiene las configuraciones
globales de seguridad que bAuth emite a todos los daemons del ecosistema.

```
D1–D12  →  "¿Quién puede hacer qué?"  →  BitMask evaluado por rol/usuario
D99     →  "¿Cómo opera el sistema?"  →  Config global que reciben todos los daemons
```

bAuth actúa como PAP/PIP (NIST SP 800-207): los daemons llaman
`bauth.config.global_get` al arrancar y reciben el árbol D99 compuesto.

**447 nodos D99** en la biblioteca — ver `BAUTH-D99-DOMINIO-GLOBAL.md`.

---

## 10. Herramientas SQL disponibles en la base de datos

### Funciones de composición

```sql
-- Serializar un subárbol como JSONB anidado
SELECT bauth.fn_compose_tree(
    'policiesAuthenticationFramework.PoliciesAuthenticationFramework.modern_authentication_policies.webauthn_fido2'::ltree,
    NULL  -- max_depth (NULL = sin límite)
);

-- Deserializar JSONB → filas en cfg_policy_library
SELECT bauth.fn_decompose_tree(
    '{ "nueva_regla": { "enabled": { "_type": "BOOLEAN", "_value": "true" } } }'::jsonb,
    'sbosSeeds.D1'::ltree,
    'manual_import_v1'  -- source tag
);
```

### Vista de navegación

```sql
-- Árbol indentado en DFS (ORDER BY path = depth-first)
SELECT depth, nodo, level_type, value_type, default_value
FROM bauth.v_policy_tree
WHERE path <@ 'sbosSeeds.D3'::ltree;
```

### Queries por dominio (índice GIN — eficiente con miles de nodos)

```sql
-- Todos los nodos de un dominio
SELECT path, level_type, value_type, default_value
FROM bauth.cfg_policy_library
WHERE domain_map @> ARRAY['D7']
ORDER BY path;

-- Propiedades con enum_options en un dominio
SELECT section_name, default_value, enum_options
FROM bauth.cfg_policy_library
WHERE domain_map @> ARRAY['D1'] AND enum_options IS NOT NULL;
```

---

## 11. Próximos pasos (HITL pendientes)

| # | Tarea | Estado |
|---|---|---|
| H14 | Aprobar deprecación de 25 tablas `ath_config/policy_dN` → reemplazar por `cfg_tenant_config` + `cfg_rule_evaluation` | **Pendiente HITL** |
| H15 | Diseñar `cfg_tenant_config` — tabla de composición del tenant (SU selecciona de biblioteca) | Bloqueado por H14 |
| H16 | Diseñar `cfg_rule_evaluation` — caché PDP (no persistente, solo runtime) | Bloqueado por H14 |
| — | Implementar handler Rust `handle_config_global_get()` en `server/jsonrpc.rs` | Listo para implementar |
| — | Formalizar contrato `BAUTH-SBOS-GLOBAL-CONFIG-CONTRATO.md` en `context/contracts/` | Pendiente aprobación |
| — | Conectar `bos_rol_template` e `idn_user_template` a `cfg_policy_library` | Bloqueado por H15 |

---

## 12. Resumen de la arquitectura de datos

```
FUENTES HISTÓRICAS (archivadas)
  Authentication_Framework.json
  Policies_Authentication_Framework_v4.json
  ath_config_d1..d12  (174 filas)
  ath_policy_d1..d12  (884 filas)
          │
          │  Migraciones bauth_40..43 (solo para actualizar instalaciones existentes)
          ▼
  cfg_policy_library (9,874 nodos · árbol ltree · SSOT operacional)
          │
          │  pg_dump --data-only → encabezado canónico
          ▼
  bauth_76__cfg_policy_library_master.sql (v2.0 · seed de instalación)
          │
          │  psql -f bauth_76 (instalación fresca)
          ▼
  SBOS_db.bauth.cfg_policy_library (instancia en producción)
          │
          ├──► cfg_tenant_config   (SU compone roles eligiendo RULES)   [pendiente]
          └──► cfg_rule_evaluation (PDP evalúa en runtime)              [pendiente]
```
