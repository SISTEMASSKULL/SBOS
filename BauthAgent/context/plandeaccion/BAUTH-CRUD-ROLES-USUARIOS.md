# BAUTH-CRUD-ROLES-USUARIOS.md — Proceso CRUD de Roles y Usuarios

**Versión:** 3.0 · **Fecha:** 2026-06-25 · **Autor:** sbos-coordinador + humano
**Diseño:** Árbol jerárquico expandible/colapsable para gestionar combinaciones masivas de datos.
**Analogía:** Explorador de archivos — el admin navega el árbol, expande nodos, marca checkboxes.
**DDL:** 177 tablas, 0 errores

---

## PRINCIPIO DE DISEÑO

> **El admin NO llena formularios planos. Navega un ÁRBOL JERÁRQUICO.**
> Cada dominio es una rama. Cada rama tiene sub-ramas. Cada sub-rama tiene hojas.
> El admin expande lo que necesita, colapsa lo que no.
> Las combinaciones son infinitas — el árbol las hace manejables.

```
ÁRBOL DEL ROL
────────────
ROL-ORG-CAJ (raíz)
├── 🏢 IDENTIDAD (cabecera)
├── 🌐 D1 — ACCESO LÓGICO
│   ├── Zona: AREA-CAJA
│   │   ├── App: Tryton
│   │   │   ├── Módulo: sale_pos
│   │   │   │   ├── Verbo: READ ☑
│   │   │   │   ├── Verbo: WRITE ☑
│   │   │   │   └── Verbo: EXECUTE ☑
│   │   │   ├── Módulo: account_invoice
│   │   │   │   ├── Verbo: READ ☑
│   │   │   │   └── Verbo: WRITE ☐
│   │   │   └── Módulo: account_payment
│   │   ├── App: Superset
│   │   │   └── Dashboard: caja_diaria
│   │   └── App: Mattermost
│   │       └── Canal: #cajas
│   └── Zona: AREA-VENT (colapsado)
├── 🚪 D2 — ACCESO FÍSICO
│   ├── Edificio: HQ Central
│   │   ├── Piso: Planta Baja
│   │   │   ├── Área: Piso de Ventas
│   │   │   └── Área: Cajas y Valores
│   │   └── Piso: 4 (colapsado)
│   └── Edificio: Sucursal Norte (colapsado)
├── 💰 D3 — FINANCIERO
│   ├── Tipo: FAC_EMITIR
│   │   ├── Límite: $2,000
│   │   ├── Aprobación: Nivel 1
│   │   └── SoD: No auto-aprobar
│   ├── Tipo: COBRO_RECIBIR
│   └── Tipo: CIERRE_CAJA
├── 🕐 D4 — TEMPORAL (colapsado)
├── 🔐 D9 — CREDENCIALES
│   ├── Disponibles
│   │   ├── PASSWORD
│   │   ├── TOTP
│   │   └── WEBAUTHN_PWDLESS
│   ├── Flujo: standard_login
│   │   ├── [1] PASSWORD ☑ obligatorio
│   │   └── [2] TOTP ☑ obligatorio
│   ├── Flujo: elevated_login
│   ├── Alternativas (3)
│   └── Políticas (14)
├── ... (más dominios colapsados)
└── 📋 PUBLICAR
```

---

## PARTE 1 — LA PANTALLA: EXPLORADOR DE ROL

```
┌──────────────────────────────────────────────────────────────────────┐
│  SBOS ADMIN — Editor de Roles                          [💾] [📋] [⚙] │
│  ────────────────────────────────────────────────────────────────── │
│                                                                      │
│  ┌─── ÁRBOL DE DOMINIOS ─────────────────────────────────────────┐  │
│  │                                                                │  │
│  │  🔍 Filtrar nodos: [___________________________]               │  │
│  │                                                                │  │
│  │  ┌─ 🏢 ROL-ORG-CAJ — Cajero ─────────────────────────────┐   │  │
│  │  │  ▶ IDENTIDAD (cabecera)                       CONFIG  │   │  │
│  │  │                                                        │   │  │
│  │  │  ▼ 🌐 D1 — ACCESO LÓGICO (12 apps, 2 zonas)          │   │  │
│  │  │  │                                                    │   │  │
│  │  │  │  ▼ 📍 Zona: AREA-CAJA — Caja y Cobranzas         │   │  │
│  │  │  │  │  Scope: BRANCH │ MaxReg: 200 │ Clasif: INTERNAL │   │  │
│  │  │  │  │                                                 │   │  │
│  │  │  │  │  └─ 📦 App: Tryton ─────────────────────────┐  │   │  │
│  │  │  │  │     │  Módulos: 4 asignados                 │  │   │  │
│  │  │  │  │     │  ☑ sale_pos                           │  │   │  │
│  │  │  │  │     │    └─ Verbos: ☑ READ ☑ WRITE ☑ EXECUTE│  │   │  │
│  │  │  │  │     │       ├─ Átomo: tryton.sale_pos.read   │  │   │  │
│  │  │  │  │     │       ├─ Átomo: tryton.sale_pos.write  │  │   │  │
│  │  │  │  │     │       └─ Átomo: tryton.sale_pos.exec   │  │   │  │
│  │  │  │  │     │  ☑ account_invoice                    │  │   │  │
│  │  │  │  │     │    └─ Verbos: ☑ READ ☐ WRITE          │  │   │  │
│  │  │  │  │     │  ☑ account_payment                    │  │   │  │
│  │  │  │  │     │    └─ Verbos: ☑ READ ☑ WRITE          │  │   │  │
│  │  │  │  │     │  ☑ party                              │  │   │  │
│  │  │  │  │     │    └─ Verbos: ☑ READ                 │  │   │  │
│  │  │  │  │     │  Campos ocultos: margin, cost_price   │  │   │  │
│  │  │  │  │     │  Botones: confirm(≤5000)              │  │   │  │
│  │  │  │  │     │  [➕ Agregar módulo]                  │  │   │  │
│  │  │  │  │     └──────────────────────────────────────┘  │   │  │
│  │  │  │  │                                                 │   │  │
│  │  │  │  │  └─ 📦 App: Superset ──────────────────────┐  │   │  │
│  │  │  │  │     │  ☑ caja_diaria                       │  │   │  │
│  │  │  │  │     │  ☑ ventas_sucursal                   │  │   │  │
│  │  │  │  │     └──────────────────────────────────────┘  │   │  │
│  │  │  │  │                                                 │   │  │
│  │  │  │  │  └─ 📦 App: Mattermost ────────────────────┐  │   │  │
│  │  │  │  │     │  ☑ #cajas                            │  │   │  │
│  │  │  │  │     │  ☑ #sucursal-central                 │  │   │  │
│  │  │  │  │     └──────────────────────────────────────┘  │   │  │
│  │  │  │  │                                                 │   │  │
│  │  │  │  │  └─ 📦 App: Paperless ─────────────────────┐  │   │  │
│  │  │  │  │     │  Tags: factura, nota_credito          │  │   │  │
│  │  │  │  │     └──────────────────────────────────────┘  │   │  │
│  │  │  │  │                                                 │   │  │
│  │  │  │  │  [➕ Agregar aplicación a esta zona]           │   │  │
│  │  │  │  │                                                 │   │  │
│  │  │  │  ▶ 📍 Zona: AREA-VENT (colapsada — 3 apps)       │   │  │
│  │  │  │                                                    │   │  │
│  │  │  │  [➕ Agregar zona de negocio]                      │   │  │
│  │  │  │                                                    │   │  │
│  │  │  ▶ 🚪 D2 — ACCESO FÍSICO (2 edificios)              │   │  │
│  │  │  │                                                    │   │  │
│  │  │  │  ▼ 🏗 Edificio: HQ Central — La Paz              │   │  │
│  │  │  │  │                                                │   │  │
│  │  │  │  │  ▼ 📐 Piso: Planta Baja                       │   │  │
│  │  │  │  │  │                                           │   │  │
│  │  │  │  │  │  └─ 🚪 PHY_ZONE_VENTAS — Piso de Ventas   │   │  │
│  │  │  │  │  │     Nivel: 2 │ Acceso: FULL                │   │  │
│  │  │  │  │  │     Puntos: AP-VENTAS-01, AP-VENTAS-02    │   │  │
│  │  │  │  │  │     Métodos: ☑ NFC ☑ QR ☑ Huella         │   │  │
│  │  │  │  │  │     Horario: business_hours                │   │  │
│  │  │  │  │  │                                           │   │  │
│  │  │  │  │  │  └─ 🚪 PHY_ZONE_CAJA — Cajas y Valores   │   │  │
│  │  │  │  │  │     Nivel: 3 │ Acceso: FULL                │   │  │
│  │  │  │  │  │     ⚠ Alarmas: TAILGATING, FORCED_ENTRY   │   │  │
│  │  │  │  │  │                                           │   │  │
│  │  │  │  │  ▶ 📐 Piso: 4 — Oficinas (colapsado)         │   │  │
│  │  │  │  │                                                │   │  │
│  │  │  │  ▶ 🏗 Edificio: Sucursal Norte (colapsado)       │   │  │
│  │  │  │                                                    │   │  │
│  │  │  ▶ 💰 D3 — FINANCIERO (5 tipos, 3 SoD)              │   │  │
│  │  │  │                                                    │   │  │
│  │  │  │  ▼ FAC_EMITIR — Emitir Factura                   │   │  │
│  │  │  │  │  Límite: $2,000/día │ Dual: No                │   │  │
│  │  │  │  │  └─ ⛓ SoD: Creador ≠ Aprobador (CRÍTICO)     │   │  │
│  │  │  │  │                                              │   │  │
│  │  │  │  ▼ COBRO_RECIBIR — Recibir Cobro                │   │  │
│  │  │  │  │  Límite: $5,000 │ Efectivo máx: $50,000      │   │  │
│  │  │  │  │                                              │   │  │
│  │  │  │  ▼ CIERRE_CAJA — Cerrar Caja                    │   │  │
│  │  │  │  │  ☑ Cuadre obligatorio │ Máx dif: $100        │   │  │
│  │  │  │  │  ☑ Depósito banco en 24h                      │   │  │
│  │  │  │  │                                              │   │  │
│  │  │  │  ▶ APERTURA_CAJA (colapsado)                     │   │  │
│  │  │  │  ▶ NC_EMITIR (colapsado)                         │   │  │
│  │  │  │                                                    │   │  │
│  │  │  │  └─ ⛓ REGLAS SoD ACTIVAS (3)                     │   │  │
│  │  │  │                                                    │   │  │
│  │  │  ▶ 🕐 D4 — TEMPORAL (Lun-Vie 8-18, feriados ❌)     │   │  │
│  │  │  │                                                    │   │  │
│  │  │  │  ▼ Horario Base                                   │   │  │
│  │  │  │  │  Lun 8-12/14-18 │ Mar 8-12/14-18              │   │  │
│  │  │  │  │  Mié 8-12/14-18 │ Jue 8-12/14-18              │   │  │
│  │  │  │  │  Vie 8-15                                         │   │  │
│  │  │  │  │                                                │   │  │
│  │  │  │  ▶ Horas Extra (no autorizado)                    │   │  │
│  │  │  │  ▶ Descansos (almuerzo 60min + 2 breaks 15min)   │   │  │
│  │  │  │                                                    │   │  │
│  │  │  ▶ 🌍 D6 — GEOESPACIAL (Bolivia, HIGH trust)        │   │  │
│  │  │  ▶ 🌐 D7 — RED (2 CIDRs, score 70, ZTA)             │   │  │
│  │  │  ▶ 🧠 D8 — CONTEXTO (ctx_id, 8h, CAEP)              │   │  │
│  │  │  │                                                    │   │  │
│  │  │  ▼ 🔐 D9 — CREDENCIALES (3 flujos, 3 alternativas,  │   │  │
│  │  │  │        14 políticas)                               │   │  │
│  │  │  │                                                    │   │  │
│  │  │  │  ▼ 📋 MÉTODOS DISPONIBLES (4 de 12)              │   │  │
│  │  │  │  │  ☑ PASSWORD                                   │   │  │
│  │  │  │  │  ☑ TOTP                                       │   │  │
│  │  │  │  │  ☑ WEBAUTHN_PWDLESS                           │   │  │
│  │  │  │  │  ☑ BACKUP_CODES                              │   │  │
│  │  │  │  │  ☐ HOTP  ☐ PASSKEY_DEVICE  ☐ SMARTCARD_X509 │   │  │
│  │  │  │  │  ☐ CIBA  ☐ MAGIC_LINK  ☐ EMAIL_OTP          │   │  │
│  │  │  │  │  [Mostrar todos los 12 métodos...]            │   │  │
│  │  │  │  │                                                │   │  │
│  │  │  │  ▼ 🔄 FLUJOS DE AUTENTICACIÓN (3 configurados)  │   │  │
│  │  │  │  │                                                │   │  │
│  │  │  │  │  └─ standard_login (AAL2)                    │   │  │
│  │  │  │  │     ├─ [1] PASSWORD ☑ obligatorio            │   │  │
│  │  │  │  │     └─ [2] TOTP ☑ obligatorio               │   │  │
│  │  │  │  │                                                │   │  │
│  │  │  │  │  └─ elevated_login (AAL2+ phishing-resistant)│   │  │
│  │  │  │  │     ├─ [1] PASSWORD ☑ obligatorio            │   │  │
│  │  │  │  │     └─ [2] WEBAUTHN_PWDLESS ☑ obligatorio   │   │  │
│  │  │  │  │                                                │   │  │
│  │  │  │  │  └─ financial_high_value (AAL3, 3 factores)  │   │  │
│  │  │  │  │     ├─ [1] WEBAUTHN_PWDLESS ☑ obligatorio    │   │  │
│  │  │  │  │     └─ [2] TOTP ☑ obligatorio               │   │  │
│  │  │  │  │                                                │   │  │
│  │  │  │  │  [➕ Agregar flujo desde plantilla]           │   │  │
│  │  │  │  │                                                │   │  │
│  │  │  │  ▼ 🔀 ALTERNATIVAS (3 configuradas)             │   │  │
│  │  │  │  │  TOTP → BACKUP_CODES (requiere aprobación)   │   │  │
│  │  │  │  │  WEBAUTHN → WEBAUTHN_2FA (automático)        │   │  │
│  │  │  │  │  PASSWORD → MAGIC_LINK (máx 5/día)           │   │  │
│  │  │  │  │                                                │   │  │
│  │  │  │  ▼ 📜 POLÍTICAS (14 seleccionadas)              │   │  │
│  │  │  │     Password (7): ☑ MIN_LENGTH ☑ HIBP ☑ NO_ROT │   │  │
│  │  │  │     MFA (3): ☑ AAL2_REQUIRED ☑ PHISH_FIDO2     │   │  │
│  │  │  │     Lockout (1): ☑ PROGRESSIVE                  │   │  │
│  │  │  │     Sesión (2): ☑ TIMEOUT_8H ☑ CONCURRENT_1    │   │  │
│  │  │  │     Recovery (1): ☑ RECOVERY_MFA                │   │  │
│  │  │  │                                                    │   │  │
│  │  │  ▶ 🔄 D10 — DELEGACIÓN (7 días, 2 roles destino)    │   │  │
│  │  │  ▶ 📊 D11 — AUDITORÍA (basic, 2555d, quarterly)     │   │  │
│  │  │  ▶ ⛓ D12 — BLOCKCHAIN (no configurado)              │   │  │
│  │  │  ▶ ⚠ D14 — CONFLICTOS (2 roles bloqueados)          │   │  │
│  │  └──────────────────────────────────────────────────────┘   │  │
│  │                                                            │  │
│  │  [➕ Agregar sección de dominio]  [📋 Vista previa JSONB] │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌─── PANEL LATERAL: RESUMEN ────────────────────────────────┐  │
│  │                                                             │  │
│  │  Secciones configuradas: 11/14                              │  │
│  │  ─────────────────────────                                  │  │
│  │  ✅ D1 Lógico       (2 zonas, 4 apps, 12 átomos)           │  │
│  │  ✅ D2 Físico       (1 edificio, 2 zonas)                  │  │
│  │  ✅ D3 Financiero   (5 tipos, 3 SoD)                       │  │
│  │  ✅ D4 Temporal     (Lun-Vie 8-18)                         │  │
│  │  ⬜ D5 Biométrico    (no configurado)                       │  │
│  │  ✅ D6 Geoespacial  (Bolivia, HIGH trust)                  │  │
│  │  ✅ D7 Red          (2 CIDRs, score 70)                    │  │
│  │  ✅ D8 Contexto     (ctx_id, 8h sesión)                    │  │
│  │  ✅ D9 Credenciales (4 métodos, 3 flujos, 14 políticas)    │  │
│  │  ✅ D10 Delegación  (7 días)                               │  │
│  │  ✅ D11 Auditoría   (basic, quarterly)                     │  │
│  │  ⬜ D12 Blockchain   (no configurado)                       │  │
│  │  ✅ D14 Conflictos  (2 roles bloqueados)                   │  │
│  │                                                             │  │
│  │  [📋 PUBLICAR ROL]  [💾 GUARDAR BORRADOR]                  │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

---

## PARTE 2 — LA JERARQUÍA DEL ÁRBOL

### 2.1 Estructura del árbol por dominio

```
RAÍZ: Rol
│
├── 🏢 IDENTIDAD (hoja — datos planos)
│
├── 🌐 D1 — LÓGICO
│   └── Zona (log_zone) ── repetible por cada zona
│       └── Aplicación (privilege_application) ── repetible por cada app
│           └── Módulo (zone_application_map.modules) ── repetible
│               └── Verbo (privilege_verb) ── repetible
│                   └── Átomo (privilege_atom) ── hoja
│
├── 🚪 D2 — FÍSICO
│   └── Edificio (fis_location WHERE type=BUILDING)
│       └── Piso (fis_location WHERE type=FLOOR)
│           └── Área/Zona (fis_access_zone)
│               └── Punto de Acceso (fis_location WHERE type=DOOR)
│                   └── Dispositivo (fis_device) ── hoja
│
├── 💰 D3 — FINANCIERO
│   └── Tipo de Transacción (fin_transaction_type)
│       ├── Límites (fin_limit)
│       ├── Cadena de Aprobación (fin_approval_chain)
│       └── Regla SoD (fin_sod_rule) ── hoja
│
├── 🕐 D4 — TEMPORAL
│   └── Día (cal_schedule.days_of_week)
│       └── Turno (cal_schedule.shifts) ── hoja
│
├── 🌍 D6 — GEOESPACIAL
│   └── País (global_country)
│       └── Geo-fence (geo_fence) ── hoja
│
├── 🌐 D7 — RED
│   └── CIDR (idn_tenant_network)
│       └── Señal de Confianza (net_ztna_policy) ── hoja
│
├── 🔐 D9 — CREDENCIALES
│   ├── Método (ath_method)
│   ├── Flujo (ath_auth_flow)
│   │   └── Paso (ath_auth_flow_method) ── hoja
│   ├── Alternativa ── hoja
│   └── Política (ath_policy_d9) ── hoja
│
├── 🔄 D10 — DELEGACIÓN
│   └── Rol Destino (idn_role_template) ── hoja
│
├── 📊 D11 — AUDITORÍA
│   └── Marco Regulatorio (aud_compliance_map) ── hoja
│
└── ... (D5, D8, D12, D14 — similares)
```

### 2.2 Reglas de interacción del árbol

| Acción | Comportamiento |
|--------|---------------|
| **Expandir nodo** | Click en ▶ → muestra hijos. Carga datos del catálogo correspondiente (query a tabla seed) |
| **Colapsar nodo** | Click en ▼ → oculta hijos. No pierde la configuración ya realizada. |
| **Marcar checkbox** | ☐ → ☑. Activa ese ítem para el rol. Si es un nodo padre, propaga a hijos (opcional). |
| **Desmarcar checkbox** | ☑ → ☐. Desactiva. Si es padre, desactiva todos los hijos. |
| **Agregar ítem** | Botón [+]. Abre modal con catálogo disponible filtrado. |
| **Quitar ítem** | Botón [🗑] en hover. Quita el ítem y sus hijos del rol. |
| **Editar valor** | Click en valor numérico/texto → se vuelve editable inline. |
| **Filtrar árbol** | La barra de búsqueda filtra nodos visibles. Ej: "factura" → muestra solo nodos que contengan "factura". |
| **Arrastrar orden** | En flujos D9, drag & drop para reordenar pasos. |

### 2.3 De dónde sale cada nivel del árbol

| Nivel del árbol | Fuente de datos (catálogo) | Tabla seed | Query |
|-----------------|---------------------------|------------|-------|
| Zona de negocio | `log_zone` | ✅ 29 zonas | `SELECT * FROM log_zone WHERE activo=true` |
| Aplicación | `privilege_application` | ✅ 12 apps | `SELECT * FROM zone_application_map WHERE zone_id=$zona` |
| Módulo | `zone_application_map.modules` | ✅ | Del campo TEXT[] |
| Verbo | `privilege_verb` | ✅ 50 verbos | `SELECT * FROM privilege_verb` |
| Átomo | `privilege_atom` | ✅ 5808 átomos | `SELECT * FROM privilege_atom WHERE app_code=$app AND verb_code=$verb` |
| Edificio/Piso | `fis_location` | — | `SELECT * FROM fis_location WHERE location_type='BUILDING'` |
| Zona física | `fis_access_zone` | — | `SELECT * FROM fis_access_zone` |
| Dispositivo | `fis_device` | — | `SELECT * FROM fis_device WHERE location_id=$loc` |
| Tipo transacción | `fin_transaction_type` | ✅ 20 tipos | `SELECT * FROM fin_transaction_type WHERE is_active=true` |
| Método auth | `ath_method` | ✅ 32 métodos | `SELECT * FROM ath_method WHERE domain_classification->>'D9'='true'` |
| Flujo auth | `ath_auth_flow` | ✅ 8 flujos | `SELECT * FROM ath_auth_flow WHERE is_active=true` |
| Política | `ath_policy_d{n}` | ✅/🟡 | `SELECT * FROM ath_policy_d{n} WHERE is_active=true` |
| País | `global_country` | ✅ 196 países | `SELECT * FROM global_country` |
| Marco regulatorio | `aud_compliance_map` | 🔴 | `SELECT * FROM aud_compliance_map` |

---

## PARTE 3 — FLUJO COMPLETO DEL CRUD

```
PASO 1 — Crear cabecera
  → POST /bauth/role  {template_code: "OPERADOR_CAJA", domain: "D1"}
  ← 201 {role_id: "ROL-ORG-CAJ-NORTE", template: {role: {...}}}

PASO 2 — Expandir dominio D1
  → GET /bauth/role/catalog/D1
  ← 200 {zones: [...], apps: [...], verbs: [...]}
  → El admin navega el árbol, marca checkboxes

PASO 3 — Guardar sección D1
  → PUT /bauth/role/{id}/section/D1  {section_data: {...}}
  ← 200 {template: {..., logical_access: {...}}}

PASO 4 — Repetir PASO 2-3 para D2, D3, D4, D6, D7, D9, D10, D11
  → Cada sección se guarda independientemente
  → El árbol se actualiza mostrando ✅ en secciones configuradas

PASO 5 — Vista previa
  → GET /bauth/role/{id}/preview
  ← 200 {template: {14 secciones JSONB}}

PASO 6 — Publicar
  → POST /bauth/role/{id}/publish
  ← 202 {sync_id, status: "SYNCING"}
  → bAuth sync engine → Keycloak + Tryton
```

---

---

## PARTE 4 — PATRÓN DE INTERACCIÓN: POPUPS + MENÚ CONTEXTUAL

### 4.1 Popup de selección (Catálogo → Árbol)

Cuando el admin hace click en **[➕ Agregar]** en cualquier nivel del árbol,
se abre un POPUP MODAL que muestra el catálogo disponible filtrado.
El admin selecciona uno o varios ítems y estos se INTEGRAN al árbol.

```
┌──────────────────────────────────────────────────────────────────┐
│  AGREGAR POLÍTICA — D9 Credenciales                     [✕]      │
│  ─────────────────────────────────────────────────────────────  │
│                                                                  │
│  🔍 Buscar política: [________________________________]          │
│  Filtrar por: [▼ Todas las categorías         ]                  │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ ☐ PWD_MIN_LENGTH_12                                       │  │
│  │   Longitud Mínima 12 caracteres                            │  │
│  │   📎 NIST SP 800-63B-4 §5.1.1.2                           │  │
│  │   ┌─────────────────────────────────────────────────────┐  │  │
│  │   │ {"rule":"min_length","value":12}                    │  │  │
│  │   └─────────────────────────────────────────────────────┘  │  │
│  │                                                            │  │
│  │ ☑ PWD_HIBP_CHECK                                          │  │
│  │   Verificación HIBP obligatoria                            │  │
│  │   📎 NIST SP 800-63B-4 §5.1.1.2 · OWASP ASVS V2.1.7      │  │
│  │   ┌─────────────────────────────────────────────────────┐  │  │
│  │   │ {"rule":"hibp_check","required":true,"method":"k_an"}│  │  │
│  │   └─────────────────────────────────────────────────────┘  │  │
│  │                                                            │  │
│  │ ☑ PWD_NO_ROTATION                                         │  │
│  │   Sin Rotación Periódica Forzada                           │  │
│  │   📎 NIST SP 800-63B-4 Final (2025)                        │  │
│  │                                                            │  │
│  │ ☐ MFA_AAL3_HARDWARE                                       │  │
│  │   MFA AAL3 — Solo Device-Bound                             │  │
│  │   📎 FIPS 140-3 · NIST SP 800-63B-4 AAL3                   │  │
│  │   ⚠ Requiere: PASSKEY_DEVICE o SMARTCARD_X509              │  │
│  │                                                            │  │
│  │ ☐ PR_PHISH_FIDO2                                           │  │
│  │   Phishing-Resistant Obligatorio AAL2+                      │  │
│  │   📎 NIST SP 800-63B-4 Final §4.2                           │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Seleccionados: 2 políticas                                      │
│                                                                  │
│  [🎯 AGREGAR SELECCIONADAS]  [📋 CANCELAR]                      │
└──────────────────────────────────────────────────────────────────┘
```

### 4.2 El mismo patrón aplica para TODOS los catálogos

| Nivel del árbol | Popup muestra | Fuente |
|-----------------|--------------|--------|
| Agregar Zona | Lista de 29 zonas de negocio | `log_zone` |
| Agregar App a Zona | Apps disponibles para esa zona | `zone_application_map` |
| Agregar Módulo | Módulos de la app | `zone_application_map.modules` |
| Agregar Verbo | 50 verbos del vocabulario | `privilege_verb` |
| Agregar Zona Física | Árbol de ubicaciones físicas | `fis_location` + `fis_access_zone` |
| Agregar Tipo Transacción | 20 tipos financieros | `fin_transaction_type` |
| Agregar Método Auth | 32 métodos con ficha técnica | `ath_method` |
| Agregar Flujo | 8 flujos predefinidos | `ath_auth_flow` |
| Agregar Paso a Flujo | Métodos del rol + orden | `ath_method` + `ath_auth_flow_method` |
| Agregar Alternativa | Métodos disponibles como reemplazo | `ath_method` |
| **Agregar Política** | **Políticas pre-diseñadas del dominio** | **`ath_policy_d{n}`** |
| **Agregar Configuración** | **Configuraciones default del dominio** | **`ath_config_d{n}`** |
| Agregar País | 196 países ISO 3166-1 | `global_country` |
| Agregar Geo-fence | Geo-cercas existentes + Nuevo desde mapa | `geo_fence` |
| Agregar CIDR | Redes del tenant | `idn_tenant_network` |
| Agregar Rol Destino (delegación) | Roles existentes | `idn_role_template` |
| Agregar Marco Regulatorio | 34 controles normativos | `aud_compliance_map` |
| Agregar Conflicto SoD | Reglas SoD existentes | `fin_sod_rule` |

### 4.3 Menú contextual (click derecho)

```
Click derecho en cualquier nodo del árbol:

┌─────────────────────────────┐
│  ✏ Editar                   │
│  📋 Duplicar                │
│  🗑 Eliminar                │
│  ─────────────────────────  │
│  🔍 Ver JSONB               │
│  📎 Copiar configuración    │
│  ─────────────────────────  │
│  ⬆ Expandir todo            │
│  ⬇ Colapsar todo            │
│  ─────────────────────────  │
│  ✅ Marcar todos los hijos  │
│  ☐ Desmarcar todos          │
│  ─────────────────────────  │
│  ⚠ Validar conflictos SoD  │
│  📊 Ver impacto en BitMask  │
└─────────────────────────────┘
```

---

## PARTE 5 — ÁRBOL DE USUARIO

```
┌──────────────────────────────────────────────────────────────────────┐
│  SBOS ADMIN — Editor de Usuarios                        [💾] [📋] [⚙]│
│  ────────────────────────────────────────────────────────────────── │
│                                                                      │
│  ┌─── ÁRBOL DE USUARIO ──────────────────────────────────────────┐  │
│  │                                                                │  │
│  │  ┌─ 👤 maria.garcia — María García López ───────────────┐     │  │
│  │  │                                                        │     │  │
│  │  │  ▼ 🆔 IDENTIDAD                                     │     │  │
│  │  │  │  Username: maria.garcia │ Email: maria@...       │     │  │
│  │  │  │  Tipo: HUMAN │ Status: ACTIVE                    │     │  │
│  │  │  │  Tenant: acme │ Empresa: ACME │ Sucursal: Central│     │  │
│  │  │  │  [✏ Editar]                                       │     │  │
│  │  │  │                                                    │     │  │
│  │  │  ▼ 👤 DATOS PERSONALES (PII · CONFIDENTIAL)         │     │  │
│  │  │  │  Nombre: María Elena García López                │     │  │
│  │  │  │  Nacimiento: 1985-06-15 │ Género: F              │     │  │
│  │  │  │  Nacionalidad: BOL │ Estado civil: MARRIED       │     │  │
│  │  │  │  Documento: DNI ****5678Z                         │     │  │
│  │  │  │  └─ 📧 Emails (2)                                 │     │  │
│  │  │  │     ├─ maria.garcia@empresa.com (trabajo) ✅      │     │  │
│  │  │  │     └─ maria.garcia@gmail.com (personal) ✅       │     │  │
│  │  │  │  └─ 📱 Teléfonos (2)                              │     │  │
│  │  │  │     ├─ +591 70012345 (móvil) ✅                   │     │  │
│  │  │  │     └─ +591 22345678 (oficina) ✅                 │     │  │
│  │  │  │  └─ 🏠 Direcciones (2)                             │     │  │
│  │  │  │  └─ 🚨 Contactos emergencia (2)                    │     │  │
│  │  │  │  [✏ Editar]                                       │     │  │
│  │  │  │                                                    │     │  │
│  │  │  ▼ 💼 DATOS PROFESIONALES                           │     │  │
│  │  │  │  Código: EMP789456 │ Cargo: Gerente Regional     │     │  │
│  │  │  │  Depto: Ventas │ División: Comercial             │     │  │
│  │  │  │  Centro costo: VEN-NORTE │ Tipo: FULL_TIME       │     │  │
│  │  │  │  Manager: carlos.ruiz (Carlos Ruiz)              │     │  │
│  │  │  │  Contratación: 2024-01-15 │ Oficina: Piso 4     │     │  │
│  │  │  │  └─ 📜 Certificaciones (2)                        │     │  │
│  │  │  │     ├─ SALES_CERT_A ✅ (expira 2025-06-01)       │     │  │
│  │  │  │     └─ MANAGEMENT_CERT_B ✅ (expira 2027-09-01)  │     │  │
│  │  │  │  [✏ Editar]                                       │     │  │
│  │  │  │                                                    │     │  │
│  │  │  ▼ 🔑 ROLES ASIGNADOS (2 activos)                  │     │  │
│  │  │  │                                                    │     │  │
│  │  │  │  └─ ROL-ORG-GER-VENT — Gerente Regional Ventas  │     │  │
│  │  │  │     Asignado: 2026-01-15 │ Status: ACTIVE        │     │  │
│  │  │  │     Vigencia: indefinida                          │     │  │
│  │  │  │     ├─ 🔄 Excepciones temporales (1)              │     │  │
│  │  │  │     │  └─ 2026-06-20: extendido hasta 22:00      │     │  │
│  │  │  │     ├─ 🌐 Excepciones de red (1)                  │     │  │
│  │  │  │     └─ 💰 Override financiero (1)                 │     │  │
│  │  │  │                                                    │     │  │
│  │  │  │  └─ ROL-ORG-CAJ — Cajero (heredado, inactivo)    │     │  │
│  │  │  │     Asignado: 2024-01 │ Removido: 2026-01         │     │  │
│  │  │  │                                                    │     │  │
│  │  │  │  [➕ Asignar nuevo rol] — abre popup de selección │     │  │
│  │  │  │                                                    │     │  │
│  │  │  ▼ 📱 DISPOSITIVOS VINCULADOS (2)                   │     │  │
│  │  │  │  ├─ iPhone 15 Pro (iOS 18.3) · Trust: 98 · 1º    │     │  │
│  │  │  │  │  Passkey: synced_icloud · FACE_ID              │     │  │
│  │  │  │  │  Last seen: 2026-06-24 14:30                   │     │  │
│  │  │  │  └─ MacBook Pro 16 (macOS 15.2) · Trust: 95      │     │  │
│  │  │  │     Passkey: device_bound · TOUCH_ID              │     │  │
│  │  │  │  [➕ Vincular dispositivo]                         │     │  │
│  │  │  │                                                    │     │  │
│  │  │  ▼ 🔐 CREDENCIALES (solo lectura — desde KC)        │     │  │
│  │  │  │  ├─ PASSWORD: ✅ (score 87, última cambio 2026-01)│     │  │
│  │  │  │  ├─ TOTP: ✅ (Google Auth — iPhone 15)            │     │  │
│  │  │  │  ├─ WEBAUTHN: ✅ (2 dispositivos)                 │     │  │
│  │  │  │  ├─ BACKUP_CODES: ✅ (8/10 disponibles)           │     │  │
│  │  │  │  └─ Compliance: ✅ cubre todos los requiredMethods│     │  │
│  │  │  │  [🔄 Sincronizar desde Keycloak]                   │     │  │
│  │  │  │                                                    │     │  │
│  │  │  ▼ 🌍 PERFIL DE UBICACIÓN                           │     │  │
│  │  │  │  Trabajo: La Paz, Av. Camacho 1234 (HIGH)        │     │  │
│  │  │  │  Casa: La Paz, Zona Sur (LOW)                     │     │  │
│  │  │  │  Última ubicación: -16.5, -68.12 (GPS, 10m)      │     │  │
│  │  │  │  Historial: 2 ubicaciones hoy                     │     │  │
│  │  │  │                                                    │     │  │
│  │  │  ▼ 🕐 PERFIL TEMPORAL                               │     │  │
│  │  │  │  Horario: Oficina (Lun-Vie 8-18)                  │     │  │
│  │  │  │  Hoy: clock-in 08:00 │ esperado out: 18:00        │     │  │
│  │  │  │  Almuerzo: 12:30-13:30 │ Status: PRESENT         │     │  │
│  │  │  │                                                    │     │  │
│  │  │  ▶ 🌐 PERFIL DE RED (colapsado)                     │     │  │
│  │  │  ▶ 📊 PERFIL DE AUDITORÍA (colapsado)               │     │  │
│  │  │  ▶ 🔗 SERVICIOS EXTERNOS (colapsado — 2 consentidos)│     │  │
│  │  │  ▶ ⚖ COMPLIANCE (colapsado)                         │     │  │
│  │  │  ▶ 🔄 CICLO DE VIDA (colapsado)                     │     │  │
│  │  └──────────────────────────────────────────────────────┘     │  │
│  │                                                                │  │
│  │  [➕ Agregar sección]  [📋 Vista previa JSONB]               │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌─── PANEL LATERAL: RESUMEN USUARIO ───────────────────────────┐  │
│  │  Secciones: 10/15                                            │  │
│  │  Roles: 2 (1 activo) │ Dispositivos: 2                       │  │
│  │  Credenciales: ✅ compliant │ SoD: ✅ sin conflictos          │  │
│  │  Último acceso: hoy 08:00 │ Sesión: activa (4.5h restantes)  │  │
│  │  Sync KC: SYNCED │ Sync Tryton: SYNCED                       │  │
│  │  [📋 PUBLICAR CAMBIOS]  [🔄 FORZAR SYNC]                     │  │
│  └──────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

---

## PARTE 6 — SINCRONIZACIÓN: bAuth → Keycloak + Tryton + Apps

### 6.1 ¿Qué se sincroniza y a dónde?

```
ROL CONFIGURADO (árbol completo)
│
├── 🔐 KEYCLOAK
│   ├── Composite Role (id = rol.id)
│   ├── Auth Flow (basado en D9 credential_policy.flujos)
│   ├── User Attributes (logical_access.zones, scope, step_up_rules)
│   ├── MFA Policies (basado en D9 applied_policies)
│   └── Session Settings (TTL, concurrent, reauth)
│
├── 💼 TRYTON
│   ├── Grupo (res.group = rol.id)
│   ├── ir.model.access (basado en D1 zone_application_map)
│   ├── ir.rule — Record Rules (basado en D1 zone_record_rule)
│   ├── ir.model.button — Button Rules (basado en D1 zone_button_rule)
│   └── ir.action.groups — Menús visibles (basado en D1 zone_application_map)
│
├── 🌐 APLICACIONES EXTERNAS (vía OIDC/SAML)
│   ├── idp_client → token de acceso con claims del rol
│   ├── idp_client_policy → métodos requeridos, AAL
│   └── idp_token_config → JWT con custom claims
│
└── 🚪 ACCESO FÍSICO (vía bhnexus)
    ├── fis_access_zone → zonas permitidas
    ├── fis_zone_method_requirement → métodos requeridos
    └── fis_area_config → controles de seguridad
```

### 6.2 Flujo de sincronización

```
┌─────────────────────────────────────────────────────────────────┐
│  ADMIN GUARDA CAMBIOS EN EL ROL                                  │
│  ─────────────────────────────                                   │
│  PUT /bauth/role/{id}/section/D9                                 │
│  → bAuth guarda en idn_role_template.template (JSONB)           │
│  → sync_status = PENDING                                         │
│  → reconcile loop (60s) detecta PENDING                         │
│                                                                  │
│  ┌─ SYNC ENGINE ────────────────────────────────────────────┐   │
│  │                                                           │   │
│  │  1️⃣ KEYCLOAK                                              │   │
│  │     POST /admin/realms/{realm}/roles                      │   │
│  │     Body: {name: "ROL-ORG-CAJ", composite: true}          │   │
│  │     → Crea/actualiza Composite Role                       │   │
│  │                                                           │   │
│  │     PUT /admin/realms/{realm}/authentication/flows        │   │
│  │     Body: {alias: "sbos-webauthn-2fa", ...}              │   │
│  │     → Crea/actualiza Auth Flow según D9                   │   │
│  │                                                           │   │
│  │     PUT /admin/realms/{realm}/users/{id}/groups           │   │
│  │     → Asigna grupos según rol                              │   │
│  │                                                           │   │
│  │  2️⃣ TRYTON                                                │   │
│  │     PUT /tryton/model/res.group                           │   │
│  │     → Crea/actualiza grupo con nombre = rol.id            │   │
│  │                                                           │   │
│  │     PUT /tryton/model/ir.model.access                     │   │
│  │     → Crea/actualiza permisos CRUD por modelo             │   │
│  │                                                           │   │
│  │     PUT /tryton/model/ir.rule                             │   │
│  │     → Crea reglas de registro (domain PYSON)              │   │
│  │                                                           │   │
│  │  3️⃣ VERIFICACIÓN                                          │   │
│  │     GET  /admin/realms/{realm}/roles/{name}               │   │
│  │     ← 200 → KC sincronizado ✅                             │   │
│  │     GET  /tryton/model/res.group/{id}                     │   │
│  │     ← 200 → Tryton sincronizado ✅                         │   │
│  │                                                           │   │
│  │  4️⃣ REGISTRO                                              │   │
│  │     INSERT INTO sync_log (rol_id, engine, status,         │   │
│  │       kc_status, tryton_status, duration_ms)              │   │
│  │     → sync_status = SYNCED                                │   │
│  └───────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 6.3 El resultado final: `bos.GetContext()`

Cuando el rol y el usuario están completamente configurados y sincronizados,
el Context Plane entrega todo en una sola llamada:

```json
{
  "user": "maria.garcia",
  "tenant": "acme",
  "branch": "central",
  "trust": "biometric",
  "permissions": [
    "tryton.sale_pos.read",
    "tryton.sale_pos.write", 
    "tryton.sale_pos.exec",
    "tryton.account_invoice.read",
    "superset.caja_diaria.read"
  ],
  "zones_physical": ["PHY_ZONE_VENTAS", "PHY_ZONE_CAJA"],
  "schedule": {"in_shift": true, "remaining_hours": 4.5},
  "location": {"country": "BO", "geo_fence": "inside", "trust_tier": "HIGH"},
  "device": {"id": "iPhone-15", "trust_score": 98},
  "session": {"ttl": 28800, "remaining": 16200, "loa": 2},
  "sync_status": "SYNCED"
}
```

---

*Documento v3.0 generado 2026-06-25.*
*Parte 1-3: Árbol de Rol · Parte 4: Popups + Menú contextual · Parte 5: Árbol de Usuario*
*Parte 6: Sincronización bAuth → KC + Tryton + Apps externas.*
*El admin configura el árbol, el Popup provee los catálogos, bAuth sincroniza todo.*
