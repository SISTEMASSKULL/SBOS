# ESPECIFICACIÓN — Modales de Políticas y Configuraciones por Dominio

**Versión:** 1.1.0 · **Fecha:** 2026-06-29 · **VPS verificada:** 13.140.128.230:15432 · **Autor:** sbos-coordinador
**Proyecto:** bAuthDEV + bAuth Desktop — Modales de selección/creación de políticas y configuraciones
**Objetivo:** Especificar los modales que alimentan las ramas de Política y Configuración
  en el árbol jerárquico D1-D12 del Editor de Rol
**DDL verificada:** `DDL_skSBOS_db.sql` líneas 4271-4336 · Seeds: `seed_ath_policy_d1-d12.sql`,
  `seed_ath_config_d1-d12.sql` · Biblioteca: `cfg_policy_library` (9,142 normas)

---

## 0bis. DATOS REALES — VPS 13.140.128.230:15432 (Verificado 2026-06-29)

### Conteos reales

| Tabla | Registros | Notas |
|-------|:---:|------|
| `cfg_policy_library` | **9,142** | 629 políticas + 5,496 configs + 16 secciones |
| `framework_raw` | 16 | Fuentes JSON: NIST, ISO, PCI, FIDO2, OAuth, etc. |
| `ath_policy_d1..d12` (suma) | **194** | Políticas asignadas a dominios |
| `ath_policy_d9` (Credenciales) | **40** | 14 pre-diseñadas + 26 desde biblioteca |
| `ath_policy_d3` (Financiero) | ~7 | Pre-diseñadas: dual_approval, sod, limits |
| `privilege_atom` | **5,808** | Átomos en el catálogo global |
| `privilege_verb` | 50 | CRUD base (1-4) + negocio (5-29) + extendidos (30-50) |
| `privilege_application` | 12 | Tryton, Keycloak, Kong, Vault, etc. |
| `privilege_group` | 48 | 10 Tryton + 5 Keycloak + 4 Kong + ... |
| `log_zone` | 29 | Zonas lógicas |
| `zone_application_map` | 8 | Mapeos zona↔app |
| `idn_role_template` | 31 | Roles definidos |
| `idn_user_template` | 9 | Usuarios (test_cajero, test_gerente, etc.) |
| `idn_tenant` | 1 | skull |
| `org_empresa` | 1 | Sistemas SKULL SRL |
| `org_sucursal` | 1 | skull-central |
| `org_pos_logico` | 0 | Sin POS configurados |

### Dos fuentes de políticas (descubierto en VPS)

Las políticas en `ath_policy_dN` provienen de **DOS fuentes** distintas:

```
Fuente A — PRE-DISEÑADAS (manual)
  policy_code: PWD_MIN_LENGTH_12, MFA_AAL2_REQUIRED, DUAL_APPROVAL_ABOVE_5000...
  Código corto, legible. Creadas manualmente por el admin.
  ~80 en total entre los 12 dominios.

Fuente B — DESDE BIBLIOTECA (cfg_policy_library)
  policy_code: LIB-nist_sp_800_63b_rev4.password_policy_rev4.blocklist...
  Prefijo "LIB-{source}.{json_path}". Cargadas automáticamente desde la biblioteca.
  ~114 en total entre los 12 dominios.
  El config JSONB se obtiene de cfg_policy_library.content_en.
```

### Ejemplo real D9 (40 políticas = 14 pre-diseñadas + 26 biblioteca)

```
Pre-diseñadas:
  PWD_MIN_LENGTH_12     → {"rule":"min_length","value":12}
  MFA_AAL2_REQUIRED     → {"rule":"mfa_required","aal":"AAL2","factors":2,...}
  LOCKOUT_PROGRESSIVE   → {"rule":"progressive_lockout","levels":[...]}

Desde biblioteca (prefijo LIB-):
  LIB-nist_sp_800_63b_rev4.password_policy_rev4.blocklist_screening.sources
  LIB-iso_27001_2022.iso_27001_2022_authentication_controls.key_controls.a_8_5.requirements
  LIB-oauth_2_1.oauth_2_1.surviving_flows
  LIB-industry_enterprise...google_beyondcorp.device_trust_factors
```

### 16 fuentes en framework_raw → cfg_policy_library

| Fuente | Tamaño | Dominios |
|--------|:---:|------|
| authenticationFramework | 127 KB | D1,D5,D7,D8,D9,D11,D12,SEC |
| policiesAuthenticationFramework | 29 KB | D1,D2,D5,D7,D8,D9,D11,D12,SEC |
| nist_sp_800_63b_rev4 | 2 KB | D9,D5,D8 |
| fido2_ctap_2.2 | 3 KB | D5,D7 |
| nist_pqc_2025 | 1 KB | SEC |
| oauth_2_1 | 2 KB | D7,D9 |
| zero_trust_nsa_2026 | 2 KB | D7,D1,D2 |
| iso_27001_2022 | 3 KB | D11,D9 |
| industry_enterprise | 4 KB | D5,D9,D7 |
| pci_dss_4_0_financial | 2 KB | D3 |
| time_based_access_d4 | 3 KB | D4 |
| geo_location_d6 | 3 KB | D6 |
| delegation_authority_d10 | 3 KB | D10 |
| cis_kubernetes_1_8 | 3 KB | D7 |
| aws_iam_best_practices | 3 KB | D7,D9 |
| soc2_type_ii | 3 KB | D11 |

---

## 0. MODELO DE DATOS REAL

### Jerarquía de almacenamiento

```
Dominio (D1-D12)
  │
  ├── Políticas (ath_policy_dN) — 12 tablas, una por dominio
  │     policy_id       UUID PK
  │     policy_code     TEXT UNIQUE    ← ej: 'DUAL_APPROVAL_ABOVE_5000'
  │     policy_name     TEXT           ← ej: 'Aprobación dual > 5.000 BOB'
  │     description     TEXT           ← ej: 'Transacciones > 5.000 requieren 2 aprobadores'
  │     standard_ref    TEXT[]         ← ej: {'SOX §404','COSO 2013','NIST SP 800-53 AC-5'}
  │     config          JSONB          ← LA REGLA (Rule)
  │     └── {"rule":"dual_approval","threshold":5000,"currency":"BOB",
  │          "approvers_required":2,"sod_check":"creator_neq_approver"}
  │     is_active        BOOLEAN
  │
  └── Configuraciones (ath_config_dN) — 12 tablas, una por dominio
        config_id        UUID PK
        config_key       TEXT UNIQUE    ← ej: 'currency_default'
        config_value     JSONB          ← LA REGLA (Rule values)
        └── {"currency":"BOB","decimal_places":2,"symbol":"Bs."}
        description      TEXT
        standard_ref     TEXT[]         ← ej: {'ISO 4217','PCI DSS 4.0'}
        is_active        BOOLEAN
```

### Biblioteca de referencia (fuente de configuraciones)

```
cfg_policy_library
  ├── 9,142 normas ISO/NIST/COBIT/PCI/FIDO2 organizadas por:
  │     domain_map     TEXT[]     ← ej: {'D1','D3','D8'}
  │     depth           INTEGER    ← nivel de anidamiento (1-5)
  │     section_name    TEXT       ← nombre de la sección
  │     content_en      JSONB      ← contenido en formato JSON estructurado
  │     compliance_ref  TEXT[]     ← referencias normativas
  │
  └── Las configuraciones (ath_config_dN) se cargan desde aquí con:
        WHERE domain_map @> ARRAY['D3'] AND depth <= 4
```

### Datos reales (desde seeds)

**Políticas por dominio (total ~80 políticas pre-diseñadas):**

| Dominio | Cantidad | Ejemplos |
|---------|:---:|------|
| D1 Lógico | 6 | SCOPE_BRANCH, SCOPE_REGIONAL, MAX_RECORDS_200, DATA_CLASS_INTERNAL, HIDE_FINANCIAL_FIELDS, RECORD_RULE_REGION |
| D2 Físico | ~5 | anti_passback, escort_required, two_person_rule, mantrap_required |
| D3 Financiero | ~7 | DUAL_APPROVAL_ABOVE_5000, SOD_CREATOR_APPROVER, LIMIT_DAILY_10000, LIMIT_MONTHLY_50000, SIN_COMPLIANCE |
| D4 Temporal | ~6 | shift_standard, holiday_blocked, overtime_disabled, break_60min |
| D5 Biométrico | ~4 | liveness_required, fmr_1_10000, enrollment_supervised |
| D6 Geoespacial | ~5 | country_allowlist_BO, velocity_900kmh, geofence_500m |
| D7 Red | ~6 | device_trust_70, cidr_corporate, vpn_required, mtls_required |
| D8 Contexto | ~5 | ctx_id_required, session_ttl_8h, anti_replay, caep_enabled |
| D9 Credenciales | **14** | PWD_MIN_LENGTH_12, PWD_NO_COMPLEXITY, PWD_HIBP_CHECK, MFA_AAL2_REQUIRED, PR_PHISH_FIDO2, LOCKOUT_PROGRESSIVE, SESSION_TIMEOUT_8H |
| D10 Delegación | ~4 | max_duration_7d, auto_revoke, chain_depth_1 |
| D11 Auditoría | ~5 | retention_2555d, hash_chain_sha256, review_quarterly |
| D12 Blockchain | ~4 | anchor_1h, gas_limit_100k, merkle_keccak256 |

---

## 1. FLUJO DE INTERACCIÓN

```
ÁRBOL D3 (Editor de Rol — Dominio Financiero)
  │
  ├── ▶ Tipos de Transacción
  │
  ├── ▶ Políticas ✏ [➕ Agregar Política]
  │     │
  │     ├── [➕]  ──→  MODAL SELECCIÓN DE POLÍTICAS (D3)
  │     │     ├── Lista políticas pre-diseñadas (7 disponibles)
  │     │     ├── Cada una muestra: código, nombre, estándares, regla JSONB
  │     │     ├── [Seleccionar] → política se asigna al rol para D3
  │     │     └── [Crear nueva] → MODAL CREAR POLÍTICA
  │     │
  │     └── 📋 DUAL_APPROVAL_ABOVE_5000 (seleccionada)
  │           └── Config: {"rule":"dual_approval","threshold":5000,...}
  │
  └── ▶ Configuraciones ✏ [➕ Agregar Configuración]
        │
        ├── [➕]  ──→  MODAL SELECCIÓN DE CONFIGURACIONES (D3)
        │     ├── Lista desde cfg_policy_library (20 disponibles)
        │     ├── [Seleccionar] → configuración se aplica al rol
        │     └── [Crear nueva] → MODAL CREAR CONFIGURACIÓN
        │
        └── ⚙ currency_default
              └── Value: {"currency":"BOB","decimal_places":2}
```

---

## 2. MODAL — SELECCIÓN DE POLÍTICA (por dominio)

### 2.1 Lista de Políticas

```
┌── 📋 SELECCIONAR POLÍTICA — D3 Financiero · 7 disponibles ──────────┐
│                                                                       │
│  🔍 [Buscar política...___________________________________________]   │
│  ──────────────────────────────────────────────────────────────────  │
│                                                                       │
│  ○ DUAL_APPROVAL_ABOVE_5000                                          │
│    Aprobación dual > 5.000 BOB                                        │
│    Estándares: SOX §404 · COSO 2013 · NIST SP 800-53 AC-5            │
│    ┌── REGLA ──────────────────────────────────────────────────────┐ │
│    │ { "rule":"dual_approval", "threshold":5000, "currency":"BOB", │ │
│    │   "approvers_required":2, "sod_check":"creator_neq_approver" }│ │
│    └───────────────────────────────────────────────────────────────┘ │
│                                                                       │
│  ○ SOD_CREATOR_APPROVER                                               │
│    SoD: Creador ≠ Aprobador                                          │
│    Estándares: SOX §404 · NIST SP 800-53 AC-5 · ISACA COBIT 2019     │
│    ┌── REGLA ──────────────────────────────────────────────────────┐ │
│    │ { "rule":"sod", "type":"creator_neq_approver",                │ │
│    │   "severity":"CRITICAL", "mitigation":"DENY" }                 │ │
│    └───────────────────────────────────────────────────────────────┘ │
│                                                                       │
│  ○ LIMIT_DAILY_10000                                                  │
│    Límite diario 10.000 BOB                                           │
│    Estándares: PCI DSS 4.0.1 Req.7 · COSO 2013                       │
│    ┌── REGLA ──────────────────────────────────────────────────────┐ │
│    │ { "rule":"daily_limit", "amount":10000, "currency":"BOB",     │ │
│    │   "aggregation":"SUM_ALL_TRANSACTIONS" }                       │ │
│    └───────────────────────────────────────────────────────────────┘ │
│                                                                       │
│  ○ SIN_COMPLIANCE                                                     │
│    Cumplimiento fiscal SIN Bolivia                                    │
│    Estándares: SIN RND 102100000011 · Ley 164 · ADSIB-FD-POLT-015    │
│    ┌── REGLA ──────────────────────────────────────────────────────┐ │
│    │ { "rule":"sin_compliance", "country":"BO",                    │ │
│    │   "tax_authority":"SIN", "signature_algorithm":"EDDSA_ED25519",│ │
│    │   "cufd_renewal":"daily_00_05", "cuf_algorithm":"mod11_base16"}│ │
│    └───────────────────────────────────────────────────────────────┘ │
│                                                                       │
│  ─── 7 políticas ─────────────────────────────────────────────────── │
│                                                                       │
│  [CANCELAR]                     [➕ CREAR NUEVA] [SELECCIONAR]       │
└───────────────────────────────────────────────────────────────────────┘
```

### 2.2 Formulario — Crear Política

```
┌── 📋 NUEVA POLÍTICA — D3 Financiero ─────────────────────────────┐
│                                                                   │
│  Código *                                                         │
│  [___MY_CUSTOM_LIMIT_500_______________________________________]  │
│  ⓘ Único en ath_policy_d3. Usar UPPER_SNAKE_CASE.                │
│                                                                   │
│  Nombre *                                                         │
│  [___Límite personalizado 500 BOB______________________________]  │
│                                                                   │
│  Descripción                                                      │
│  [___Límite de transacción personalizado para cajeros junior____]  │
│                                                                   │
│  ─── REGLA (config JSONB) * ───────────────────────────────────  │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │ {                                                             │  │
│  │   "rule": "custom_limit",                                     │  │
│  │   "amount": [500______],                                      │  │
│  │   "currency": "BOB",                                          │  │
│  │   "aggregation": "PER_TRANSACTION"                            │  │
│  │ }                                                             │  │
│  └─────────────────────────────────────────────────────────────┘  │
│  ⓘ La regla define QUÉ hace la política. Campos obligatorios:    │
│    "rule" (string). El resto según el tipo de regla.             │
│                                                                   │
│  ─── ESTÁNDARES DE REFERENCIA ──────────────────────────────────  │
│  ☑ NIST SP 800-53 AC-7                                            │
│  ☑ PCI DSS 4.0 Req 7                                              │
│  ☐ SOX §404                                                       │
│  ☐ COSO 2013                                                      │
│  ☐ COBIT 2019                                                     │
│  [➕ Agregar otro estándar]  ⓘ Busca en cfg_policy_library        │
│                                                                   │
│  ⚠ La política será válida SOLO para el dominio D3.              │
│    Si necesitas la misma regla en otro dominio, créala allí.     │
│                                                                   │
│  [CANCELAR]                    [📋 CREAR POLÍTICA]                │
└───────────────────────────────────────────────────────────────────┘

CAMPOS (según DDL ath_policy_dN):
┌──────────────────────┬──────────────┬───────┬────────────────────────────────┐
│ Campo                │ Tipo         │ Req   │ Validación                     │
├──────────────────────┼──────────────┼───────┼────────────────────────────────┤
│ policy_code          │ text         │ SI    │ UPPER_SNAKE_CASE, ÚNICO        │
│ policy_name          │ text         │ SI    │ max 200 chars                  │
│ description          │ textarea     │ NO    │ max 500 chars                  │
│ config               │ JSONB editor │ SI    │ debe tener "rule" (string)     │
│ standard_ref         │ multiselect  │ NO    │ TEXT[], buscar en cfg_policy_   │
│                      │              │       │ library o escribir libre        │
│ is_active            │ checkbox     │ —     │ default: ☑                     │
│ domain_code          │ hidden       │ —     │ heredado del contexto           │
└──────────────────────┴──────────────┴───────┴────────────────────────────────┘
```

---

## 3. MODAL — SELECCIÓN DE CONFIGURACIÓN (por dominio)

### 3.1 Lista de Configuraciones (desde cfg_policy_library)

```
┌── ⚙ SELECCIONAR CONFIGURACIÓN — D3 Financiero · 20 disponibles ──────┐
│                                                                        │
│  🔍 [Buscar configuración..._______________________________________]   │
│  ───────────────────────────────────────────────────────────────────  │
│                                                                        │
│  ○ currency_default                                                    │
│    Moneda por defecto para transacciones                               │
│    Estándares: ISO 4217                                                │
│    ┌── VALOR ───────────────────────────────────────────────────────┐ │
│    │ { "currency":"BOB", "decimal_places":2, "symbol":"Bs." }       │ │
│    └────────────────────────────────────────────────────────────────┘ │
│                                                                        │
│  ○ approval_timeout_hours                                              │
│    Tiempo máximo para aprobación antes de escalar                      │
│    Estándares: SOX §404 · COSO 2013 Control Activities                │
│    ┌── VALOR ───────────────────────────────────────────────────────┐ │
│    │ { "timeout_hours":48, "escalation_hours":24 }                  │ │
│    └────────────────────────────────────────────────────────────────┘ │
│                                                                        │
│  ○ max_approval_tiers                                                 │
│    Niveles máximos en cadena de aprobación                             │
│    Estándares: COSO 2013 · NIST SP 800-53 AC-5                        │
│    ┌── VALOR ───────────────────────────────────────────────────────┐ │
│    │ { "max_tiers":4, "min_approvers_per_tier":1 }                  │ │
│    └────────────────────────────────────────────────────────────────┘ │
│                                                                        │
│  ○ sin_environment                                                    │
│    Ambiente del Servicio de Impuestos Nacionales                       │
│    Estándares: SIN RND 102100000011                                   │
│    ┌── VALOR ───────────────────────────────────────────────────────┐ │
│    │ { "environment":"PRODUCCION", "wsdl_url":"https://siat...",    │ │
│    │   "timeout_seconds":30, "max_retries":3 }                       │ │
│    └────────────────────────────────────────────────────────────────┘ │
│                                                                        │
│  ─── 20 configuraciones ───────────────────────────────────────────── │
│                                                                        │
│  [CANCELAR]                    [➕ CREAR NUEVA] [SELECCIONAR]         │
└────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Formulario — Crear Configuración

```
┌── ⚙ NUEVA CONFIGURACIÓN — D3 Financiero ──────────────────────────┐
│                                                                    │
│  Clave *                                                           │
│  [___my_custom_setting__________________________________________]  │
│  ⓘ Único en ath_config_d3. Usar snake_case.                       │
│                                                                    │
│  Valor (config_value JSONB) *                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ {                                                              │  │
│  │   "param1": "value1",                                          │  │
│  │   "threshold": 500,                                            │  │
│  │   "enabled": true                                              │  │
│  │ }                                                              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│  ⓘ JSON válido. Define los valores de configuración.              │
│                                                                    │
│  Descripción                                                       │
│  [___Configuración personalizada para límite de cajeros junior___] │
│                                                                    │
│  ─── ESTÁNDARES ─────────────────────────────────────────────────  │
│  ☑ NIST SP 800-53 CM-6                                             │
│  [➕ Agregar otro]  ⓘ Busca en cfg_policy_library                  │
│                                                                    │
│  [CANCELAR]                  [⚙ CREAR CONFIGURACIÓN]              │
└────────────────────────────────────────────────────────────────────┘

CAMPOS (según DDL ath_config_dN):
┌──────────────────────┬──────────────┬───────┬────────────────────────────────┐
│ Campo                │ Tipo         │ Req   │ Validación                     │
├──────────────────────┼──────────────┼───────┼────────────────────────────────┤
│ config_key           │ text         │ SI    │ snake_case, ÚNICO              │
│ config_value         │ JSONB editor │ SI    │ JSON válido                    │
│ description          │ textarea     │ NO    │ max 500 chars                  │
│ standard_ref         │ multiselect  │ NO    │ TEXT[], buscar en cfg_policy_   │
│                      │              │       │ library o escribir libre        │
│ is_active            │ checkbox     │ —     │ default: ☑                     │
│ domain_code          │ hidden       │ —     │ heredado del contexto           │
└──────────────────────┴──────────────┴───────┴────────────────────────────────┘
```

---

## 4. MODAL — VISUALIZACIÓN DE REGLA (Click en política/config ya asignada)

```
┌── 📋 DETALLE DE REGLA — DUAL_APPROVAL_ABOVE_5000 ──────────────────┐
│                                                                      │
│  Política asignada al rol CAJERO (BIZ_N3)                            │
│  ──────────────────────────────────────────────────────────────────  │
│                                                                      │
│  Código:    DUAL_APPROVAL_ABOVE_5000                                 │
│  Nombre:    Aprobación dual > 5.000 BOB                              │
│  Desc:      Transacciones > 5.000 BOB requieren 2 aprobadores        │
│                                                                      │
│  ─── REGLA ───────────────────────────────────────────────────────  │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │ {                                                               │  │
│  │   "rule":                "dual_approval",                       │  │
│  │   "threshold":           5000,                                  │  │
│  │   "currency":            "BOB",                                 │  │
│  │   "approvers_required":  2,                                     │  │
│  │   "sod_check":           "creator_neq_approver"                 │  │
│  │ }                                                               │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ─── ESTÁNDARES DE REFERENCIA ────────────────────────────────────  │
│  📜 SOX §404 — Sarbanes-Oxley Sección 404                           │
│  📜 COSO 2013 — Control Activities                                  │
│  📜 NIST SP 800-53 AC-5 — Separation of Duties                      │
│                                                                      │
│  ─── APLICADO A ──────────────────────────────────────────────────  │
│  🏢 3 empresas usan esta política                                    │
│  👤 47 usuarios afectados                                            │
│  📊 12,345 evaluaciones este mes                                     │
│                                                                      │
│  [✏ EDITAR REGLA]  [📋 COPIAR A OTRO DOMINIO]  [🗑 REMOVER]       │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 5. REGLAS DE NEGOCIO

| # | Regla | Detalle |
|---|-------|---------|
| R1 | **Políticas son por dominio** | Cada política pertenece a UN solo dominio (ath_policy_dN). No hay políticas cross-domain. |
| R2 | **Config JSONB = la Rule** | El campo `config` de ath_policy_dN ES la regla. Debe contener al menos `"rule"` (string). |
| R3 | **Estándares desde biblioteca** | `standard_ref` se selecciona del catálogo `cfg_policy_library` (9,142 normas). También se permite texto libre. |
| R4 | **Configuraciones desde biblioteca** | `ath_config_dN` se puebla desde `cfg_policy_library` filtrando por `domain_map` y `depth`. |
| R5 | **Políticas inmutables post-asignación** | Si una política está asignada a un rol PUBLICADO, no se puede modificar. Solo desactivar. |
| R6 | **Validación de reglas** | El JSONB `config` se valida contra el esquema esperado para el tipo de regla (`rule` field). |
| R7 | **Herencia de políticas** | Un rol hijo hereda las políticas del rol padre. No se pueden remover — solo sobrescribir con una política más restrictiva. |
| R8 | **Catálogo de 9,142 estándares** | `cfg_policy_library` contiene todas las normas ISO, NIST, PCI, SOX, COBIT, FIDO2, OWASP referenciables. |
| R9 | **Cada regla es un objeto JSONB** | Estructura canónica: `{"rule":"tipo_regla", ...params específicos...}`. El campo `rule` es obligatorio. |
| R10 | **Audit trail** | Toda creación/modificación de política genera `aud_event` con ctx_id del administrador (ISO 27001 A.8.15). |

---

## 6. RESUMEN DE REGLAS POR DOMINIO (catálogo real)

### D1 — Lógico
| Código | Regla | Estándares |
|--------|-------|-----------|
| SCOPE_BRANCH | `{"rule":"scope","level":"BRANCH","auto_record_rule":true}` | NIST 800-53 AC-3, ANSI INCITS 359-2004 |
| SCOPE_REGIONAL | `{"rule":"scope","level":"REGIONAL","auto_record_rule":true}` | NIST 800-53 AC-3 |
| MAX_RECORDS_200 | `{"rule":"max_records","value":200}` | NIST 800-53 AC-6 |
| DATA_CLASS_INTERNAL | `{"rule":"data_classification","allowed":["PUBLIC","INTERNAL"],"restricted":["CONFIDENTIAL","RESTRICTED","SECRET"]}` | NIST 800-53 AC-3 |
| HIDE_FINANCIAL_FIELDS | `{"rule":"field_restriction","fields":{"margin":"hidden","cost_price":"hidden","commission_rate":"hidden","credit_limit":"readonly"}}` | NIST 800-53 AC-3 |
| RECORD_RULE_REGION | `{"rule":"record_filter","type":"region","auto_apply":true}` | ANSI INCITS 359-2004 |

### D3 — Financiero
| Código | Regla | Estándares |
|--------|-------|-----------|
| DUAL_APPROVAL_ABOVE_5000 | `{"rule":"dual_approval","threshold":5000,"currency":"BOB","approvers_required":2,"sod_check":"creator_neq_approver"}` | SOX §404, COSO 2013, NIST SP 800-53 AC-5 |
| SOD_CREATOR_APPROVER | `{"rule":"sod","type":"creator_neq_approver","severity":"CRITICAL","mitigation":"DENY"}` | SOX §404, NIST SP 800-53 AC-5, ISACA COBIT 2019 |
| SOD_CASHIER_RECONCILE | `{"rule":"sod","type":"cashier_neq_reconciler","severity":"CRITICAL","mitigation":"DENY"}` | SOX §404, COSO 2013 §8 |
| LIMIT_DAILY_10000 | `{"rule":"daily_limit","amount":10000,"currency":"BOB","aggregation":"SUM_ALL_TRANSACTIONS"}` | PCI DSS 4.0.1 Req.7, COSO 2013 |
| LIMIT_MONTHLY_50000 | `{"rule":"monthly_limit","amount":50000,"currency":"BOB"}` | PCI DSS 4.0.1 Req.7 |
| SIN_COMPLIANCE | `{"rule":"sin_compliance","country":"BO","tax_authority":"SIN","signature_algorithm":"EDDSA_ED25519","cufd_renewal":"daily_00_05","cuf_algorithm":"mod11_base16"}` | SIN RND 102100000011, Ley 164, ADSIB-FD-POLT-015 v2.3 |

### D9 — Credenciales
| Código | Regla | Estándares |
|--------|-------|-----------|
| PWD_MIN_LENGTH_12 | `{"rule":"min_length","value":12}` | NIST SP 800-63B-4 §5.1.1.2, OWASP ASVS V2.1.1 |
| PWD_NO_COMPLEXITY | `{"rule":"no_complexity_rules"}` | NIST SP 800-63B-4 §5.1.1.2 |
| PWD_NO_ROTATION | `{"rule":"no_periodic_rotation"}` | NIST SP 800-63B-4 §5.1.1.2 |
| PWD_HIBP_CHECK | `{"rule":"hibp_check","required":true,"method":"k_anonymity"}` | NIST SP 800-63B-4 §5.1.1.2, OWASP ASVS V2.1.7 |
| PWD_ARGON2ID | `{"rule":"hash_algorithm","algorithm":"Argon2id","params":{"time_cost":3,"memory_mb":64,"parallelism":2}}` | OWASP ASVS V2.4.3, NIST SP 800-63B-4 |
| MFA_AAL2_REQUIRED | `{"rule":"mfa_required","aal":"AAL2","factors":2,"phishing_resistant_option_required":true}` | NIST SP 800-63B-4 §4.2, FIDO2 Level 2 |
| MFA_AAL3_HARDWARE | `{"rule":"mfa_hardware","aal":"AAL3","device_bound":true,"syncable_prohibited":true}` | NIST SP 800-63B-4 §4.3, FIPS 140-3 |
| PR_PHISH_FIDO2 | `{"rule":"phishing_resistance","required_aal2_plus":true,"syncable_allowed_aal2":true,"device_bound_required_aal3":true}` | NIST SP 800-63B-4 Final §4.2, FIDO2 Level 3 |
| LOCKOUT_PROGRESSIVE | `{"rule":"progressive_lockout","levels":[...],"permanent_lock":50}` | NIST SP 800-53 AC-7, OWASP ASVS V2.1.2, PCI DSS 4.0 Req 8.3.4 |
| SESSION_TIMEOUT_8H | `{"rule":"session_timeout","max_seconds":28800,"idle_seconds":900,"reauth_seconds":14400}` | NIST SP 800-63B-4 §7, OWASP ASVS V3.3 |

---

## 7. GUÍA PARA CLAUDE DESIGN — Cómo NO confundirse

> **⚠️ LEE ESTO PRIMERO.** Claude Design tiende a olvidar partes de especificaciones complejas.
> Esta sección existe específicamente para prevenir eso. Es la sección más importante
> del documento.

### 7.1 Lo que Claude Design DEBE recordar (checklist de verificación)

Antes de generar cualquier HTML, verifica que tu diseño incluye:

- [ ] El modal tiene exactamente **DOS botones** en el footer: [Seleccionar] + [Crear nuevo]
- [ ] El botón [Seleccionar] está a la derecha (acción primaria)
- [ ] El botón [Crear nuevo] está a la izquierda del [Seleccionar] (acción secundaria)
- [ ] CADA política en la lista muestra sus **4 atributos**: código, nombre, estándares, CONFIG (la regla JSONB)
- [ ] El config JSONB se muestra en un **bloque de código con fondo oscuro**, no como texto plano
- [ ] Los estándares de referencia se muestran como **badges/tags** pequeños, no como texto largo
- [ ] La lista distingue visualmente las políticas **pre-diseñadas** de las políticas desde **biblioteca** (prefijo LIB-)
- [ ] El formulario de creación tiene un **editor JSON** para el campo `config`, no un simple textarea
- [ ] El formulario de creación tiene un **selector múltiple** para `standard_ref`, no un input de texto libre
- [ ] La vista de detalle de regla muestra el JSONB formateado con resaltado de sintaxis
- [ ] La vista de detalle muestra los estándares como enlaces/badges
- [ ] La vista de detalle muestra métricas de impacto (empresas, usuarios, evaluaciones)
- [ ] El modal de configuración es DISTINTO del modal de política (diferente título, diferente estructura)

### 7.2 Jerarquía visual — Lo que NUNCA debe mezclarse

```
DOMINIO (D1-D12) — esto es el CONTEXTO, no una entidad seleccionable
  │
  ├── POLÍTICA (ath_policy_dN) — esto es lo que se SELECCIONA
  │     │
  │     └── REGLA (config JSONB) — esto está DENTRO de la política
  │           │
  │           └── {"rule": "...", ...params...}
  │
  └── CONFIGURACIÓN (ath_config_dN) — esto es DISTINTO de la política
        │
        └── VALOR (config_value JSONB) — esto está DENTRO de la configuración
              │
              └── {"param": value, ...}
```

**REGLAS DE ORO:**
1. NUNCA muestres políticas y configuraciones en la misma lista
2. NUNCA uses el mismo color para el modal de política y el modal de configuración
3. SIEMPRE muestra el dominio actual en el título del modal
4. SIEMPRE muestra el contador "X disponibles" en el título

### 7.3 Do's and Don'ts

| ✅ DO | ❌ DON'T |
|------|---------|
| Usar `--color-bg-secondary` para el fondo del modal | Usar blanco puro o negro puro |
| Mostrar el config JSONB en `<pre><code>` con resaltado | Mostrar el JSON como texto inline |
| Usar badges para los estándares (`.badge-standard`) | Mostrar estándares como texto separado por comas |
| Diferenciar políticas pre-diseñadas de biblioteca con un badge `📚 Biblioteca` vs `✏ Manual` | Mezclarlas sin distinción visual |
| Incluir contador "X disponibles" en el header | Omitir el contador |
| Usar radio buttons para selección única | Usar checkboxes (solo se puede seleccionar UNA política a la vez) |
| Mostrar el código de la política en monoespaciado | Usar fuente normal para códigos |
| Validar que el config JSONB tenga el campo `"rule"` antes de permitir guardar | Permitir guardar JSON inválido |
| El modal de crear debe tener un editor JSON con al menos 5 líneas de altura | Usar un input de una sola línea para el JSON |

### 7.4 Prompt Guide — Cómo pedirle a Claude Design que genere esto

```
1. PRIMERO genera el modal de SELECCIÓN DE POLÍTICA con:
   - Título: "Seleccionar Política — D3 Financiero · 7 disponibles"
   - Lista de 7 políticas pre-diseñadas (NO incluir las de biblioteca aún)
   - Cada item con: radio button, código monoespaciado, nombre, badges de estándares, bloque JSON
   - Footer: [Cancelar] [➕ Crear nueva] [Seleccionar]

2. LUEGO genera el modal de CREAR POLÍTICA con:
   - Formulario: policy_code, policy_name, description, config (editor JSON), standard_ref (multi-select)
   - El editor JSON debe tener al menos 8 líneas de altura
   - El campo config debe mostrar un placeholder: {"rule": "", ...}

3. DESPUÉS genera el modal de DETALLE DE REGLA con:
   - Misma estructura que la lista pero en modo lectura
   - Agregar sección "Aplicado a" con métricas

4. FINALMENTE genera el modal de CONFIGURACIÓN (DIFERENTE al de política):
   - Título: "Seleccionar Configuración — D3 Financiero"
   - Misma estructura de lista pero con config_key + config_value
   - El valor se muestra como JSON inline (es más corto que una regla)
```

### 7.5 Lo que causa confusión (y cómo evitarlo)

| Confusión común | Causa | Solución |
|------|------|------|
| "¿Esto es una política o una regla?" | Usé los términos indistintamente | **Política** = fila en ath_policy_dN. **Regla** = el JSONB dentro de `config`. NUNCA usar "regla" para referirse a la política completa. |
| "¿Dónde va el JSON?" | No especifiqué el contenedor | El JSON de la regla va en `<pre><code class="language-json">` SIEMPRE. |
| "Me olvidé de los estándares" | Los puse como texto secundario | Los estándares son TAN importantes como el código. Van en badges visibles. |
| "Generé un solo modal" | No diferencié política de configuración | Son DOS modales distintos. La configuración NO tiene campo "rule", la política SÍ. |
| "No puse el botón de crear" | Lo omití por simplicidad | SIEMPRE hay dos botones: [Seleccionar] y [Crear nuevo]. NUNCA solo uno. |

### 7.6 Ubicación en la UI — Dónde va esta funcionalidad

> **⚠️ IMPORTANTE PARA CLAUDE DESIGN:** Las Políticas se acceden desde la sección
> **Templates** del menú lateral izquierdo, como una opción adicional.

```
Menú Lateral Izquierdo (Left Sidebar):
  │
  ├── 📊 Dashboard
  ├── 👥 Roles
  ├── 👤 Usuarios
  ├── 📋 Templates              ← SECCIÓN CONTENEDORA
  │     ├── 📄 Roles             ← Templates de Rol (14 secciones por dominio)
  │     ├── 📄 Usuarios          ← Templates de Usuario (16 secciones)
  │     └── 🛡️ Políticas         ← ★ AQUÍ se agrega esta opción
  ├── 🔄 Sincronización
  ├── 📊 Auditoría
  └── ...
```

**Comportamiento al hacer click en "Templates → Políticas":**
1. Se abre una vista con **12 tabs/pestañas**, una por dominio (D1-D12)
2. El tab activo por defecto es **D9 (Credenciales)** por ser el que más políticas tiene
3. Cada tab muestra la lista de políticas de ese dominio (pre-diseñadas + biblioteca)
4. Desde esta vista se puede:
   - [➕ Agregar Política] → abre el modal de SELECCIÓN DE POLÍTICA para ese dominio
   - Click en una política existente → abre el modal de DETALLE DE REGLA
   - [✏ Editar] / [🗑 Remover] en cada política listada

```
┌──────────────────────────────────────────────────────────────────┐
│  📋 Templates > 🛡️ Políticas                                     │
│  ─────────────────────────────────────────────────────────────── │
│                                                                  │
│  [D1 Lógico] [D2 Físico] [D3 Financiero] [D4 Temporal] ...      │
│  ─────────────────────────────────────────────────────────────── │
│                                                                  │
│  Dominio actual: D9 — Credenciales · 40 políticas                │
│                                                                  │
│  🔍 [Buscar política...]  Fuente: [Todas ▼]  [➕ AGREGAR POLÍTICA]│
│  ─────────────────────────────────────────────────────────────── │
│                                                                  │
│  ┌── PWD_MIN_LENGTH_12 ──────────────────────────────────────┐  │
│  │  Longitud Mínima 12 caracteres    ✏ Manual                │  │
│  │  📜 NIST SP 800-63B-4 · OWASP ASVS V2.1.1                │  │
│  │  { "rule": "min_length", "value": 12 }                    │  │
│  │  [✏ Editar] [📋 Copiar] [🗑 Remover]                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ...                                                             │
└──────────────────────────────────────────────────────────────────┘
```

**Regla para Claude Design:**
- El menú lateral IZQUIERDO debe incluir "Templates" como sección colapsable
- Dentro de Templates hay 3 sub-opciones: Roles, Usuarios, y **Políticas** (esta última es NUEVA)
- NO poner Políticas como item independiente del menú principal — va DENTRO de Templates
- La vista de Políticas usa tabs horizontales para los 12 dominios
- El tab activo tiene un indicador visual (borde inferior accent)

---

*ESPECIFICACION-MODALES-POLITICAS-CONFIGURACIONES.md v2.0.0 · 2026-06-29 · SKULL · SBOS*
*DDL verificada: DDL_skSBOS_db.sql líneas 4271-4336 · Seeds: seed_ath_policy_d1-d12.sql (80+ políticas) · cfg_policy_library (9,142 normas) · VPS: 13.140.128.230:15432*
*Formato Claude Design: incluye Do's/Don'ts + Prompt Guide + Checklist de verificación*
