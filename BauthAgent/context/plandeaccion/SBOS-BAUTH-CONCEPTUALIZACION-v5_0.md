# SBOS-008 · bAuth — Unified Identity & Permissions Orchestrator
## Conceptualización Definitiva v5.0
### SKULL · SBOS — Sovereign Business Operating System
### v5.0 · Abril 2026

---

| Campo | Valor |
|---|---|
| **Código** | `SBOS-BAUTH-CONCEPTUALIZACION` |
| **Versión** | `5.0` — definitiva, reemplaza v1.0, v2.0, v3.0, v4.0 |
| **Estado** | `ACTIVO` |
| **Daemon** | `bauth.service` — Go 1.22+ |
| **Reemplaza** | SBOS-008 §7 y §8 completos · SBOS-BAUTH-CONCEPTUALIZACION-v4_0.md |
| **Integra** | SBOS-009 · SBOS-019 · SBOS-020 · SBOS-008-001 · SBOS-PLAN-ACTUALIZACION-CONSOLIDADO-v3_0 · SBOS-BAUTH-DECISIONES-ARQUITECTURA-v1_0 · SBOS-BAUTH-REQUERIMIENTOS-TECNICOS-v1_2 · SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION |
| **Correcciones críticas** | J1–J11 (jurisdicción · contraseñas NIST SP 800-63B-4) · K1–K7 (KC integraciones externas) |
| **Nuevas secciones** | §20 Requerimientos de Infraestructura · §21 Catálogo de 15 Métodos · §22 `deploy.yml` |
| **⚠️ BITMASK ACTUALIZADO (Jun 2026)** | SAM-128 descartado. Modelo actual: **BitMask Dual** — `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md` (BitMask Átomo 64-bit + Rol BitMask N-bit). Ver también `SBOS-MANUAL-BAUTH-COMPONENT-ROLES.md` v1.7 y `SBOS-BAUTH-EVALUACION-INTEGRAL-v2.2.md`. |
| **Estándares** | NIST SP 800-63B-4 (jul 2025) · FIPS 203/204/205 (ago 2024) · ISO/IEC 27001:2022 · ANSI/INCITS 359-2004 H-RBAC · PCI-DSS v4.0 · NIST SP 800-53 AC-5 · FIDO2/WebAuthn W3C · eIDAS · RGPD Art.9 · SOX §404 · SIA OSDP v2.2.2 · RFC 6749 OAuth2 · RFC 9470 Step-Up · RFC 9449 DPoP · IEEE 802.1X-2020 · OASIS XACML 3.0 |

> **⚠️ NOTA DE VALIDACIÓN X-RAY (Abril 2026):** Este documento ha sido validado contra `SBOS-PLAN-ACTUALIZACION-CONSOLIDADO-v3_0.md` y `SBOS-BAUTH-REQUERIMIENTOS-TECNICOS-v1_2.md`. Las correcciones J1–J11 y K1–K7 del Plan Consolidado están completamente incorporadas. Los errores SAM-128 documentados en `SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md` están corregidos. La infraestructura se ajusta al análisis de escalado gradual Contabo de los Requerimientos Técnicos v1.2. **Versión Keycloak canónica fijada: 26.6.1** (patch de seguridad sobre 26.6.0 — publicado 14 abril 2026; corrige CVE-2026-4366 SSRF y CVE-2026-4633 user enumeration). NIST SP 800-63B-4 Final publicado el 31 de julio de 2025.

---

## Tabla de Contenidos

1. [El Problema que bAuth Resuelve](#1-el-problema-que-bauth-resuelve)
2. [Definición Canónica](#2-definición-canónica)
3. [El Triángulo KC — bAuth — Tryton](#3-el-triángulo-kc--bauth--tryton)
4. [RolTemplate y UserTemplate: El Único Contrato](#4-roltemplate-y-usertemplate-el-único-contrato)
5. [Esquema de Almacenamiento PostgreSQL](#5-esquema-de-almacenamiento-postgresql)
6. [Los 15 Métodos de Autenticación Canónicos](#6-los-15-métodos-de-autenticación-canónicos)
7. [Integración Keycloak: Nativo vs SPIs vs Externo](#7-integración-keycloak-nativo-vs-spis-vs-externo)
8. [El SAM-128 — Sovereign Authority Matrix (Versión Corregida)](#8-el-sam-128--sovereign-authority-matrix-versión-corregida)
9. [Las 6 Capas de Resolución de Contexto](#9-las-6-capas-de-resolución-de-contexto)
10. [El Flujo de Sincronización Maestro](#10-el-flujo-de-sincronización-maestro)
11. [La Interfaz de bAuth](#11-la-interfaz-de-bauth)
12. [Los 5 SPIs que bAuth Construye para Keycloak](#12-los-5-spis-que-bauth-construye-para-keycloak)
13. [Sincronización Atómica KC ↔ Tryton](#13-sincronización-atómica-kc--tryton)
14. [Ciclo de Vida del Realm](#14-ciclo-de-vida-del-realm)
15. [Delegación Temporal con Vigencia](#15-delegación-temporal-con-vigencia)
16. [Presentación de Identidad Física](#16-presentación-de-identidad-física)
17. [Gestión de Emergencias](#17-gestión-de-emergencias)
18. [Coordinación con NEXUS](#18-coordinación-con-nexus)
19. [Requerimientos de Infraestructura y Escalado](#19-requerimientos-de-infraestructura-y-escalado)
20. [Lo que bAuth ES y NO ES](#20-lo-que-bauth-es-y-no-es)
21. [Glosario Técnico](#21-glosario-técnico)
22. [Registro de Cambios v5.0](#22-registro-de-cambios-v50)

---

## 1. El Problema que bAuth Resuelve

Los sistemas empresariales fallan por tres causas sistémicas:

1. **Desincronización:** el IdP (Keycloak) y el ERP (Tryton) divergen. Un administrador configura un rol en uno y lo olvida en el otro.
2. **Herencia manual:** un rol "Contador Senior" debería heredar de "Contador Júnior", pero con herencia manual un error humano introduce accesos incorrectos.
3. **Enforcement inconsistente:** si la seguridad depende de cada app individual, una sola app con un bug de autorización expone todo el sistema.

**bAuth elimina los tres:** calcula herencia automáticamente con aritmética binaria (H-RBAC, ANSI/INCITS 359-2004), sincroniza KC y Tryton proactivamente en menos de 5 segundos, y el enforcement es estructural — vive en los sistemas nativos, no en código adicional.

---

## 2. Definición Canónica

> **bAuth es el sistema de identidad del SBOS.**
> **Keycloak y Tryton son sus brazos de ejecución.**
> **El SBOS no consulta KC directamente. No consulta Tryton directamente.**
> **El SBOS consulta bAuth.**

bAuth opera con **6 responsabilidades simultáneas:**

### Responsabilidad 1 — SINCRONIZADOR MAESTRO
Traduce `RolTemplate` → objetos nativos KC + Tryton + adaptadores de app.
**Garantía:** < 5 segundos desde guardar hasta `SYNCED`.

### Responsabilidad 2 — MOTOR DE PRIVILEGIOS (PrivilegeEngine)
H-RBAC con `AND NOT` — herencia automática, sin errores humanos.
Produce `BitmaskBundle` (`PhysicalDomainMask` + `LogicalDomainMask` + `FinancialDomainMask`) y `bos_context` para el JWT.

### Responsabilidad 3 — EVALUADOR EN TIEMPO REAL
`bhnexus` consulta via Unix socket `/run/bos/bauth.sock`.
Latencia < 5ms con cache Redis TTL 30s (default).

### Responsabilidad 4 — INTERFAZ DE ADMINISTRACIÓN (PAP)
API REST para Core UI — CRUD de `RolTemplate`s y `UserTemplate`s.
Única puerta de entrada autorizada para modificar identidad.

### Responsabilidad 5 — GESTOR DE IDENTIDAD FÍSICA
QR dinámicos (HMAC-SHA256, TTL 30s configurable).
Hashes biométricos PBKDF2-SHA256 en `bauth_biometric_templates`.
Validación NFC/RFID via `bhnexus`.

### Responsabilidad 6 — GUARDIÁN DE SoD Y CUMPLIMIENTO
Conflict Matrix evaluada ANTES de guardar cualquier `RolTemplate`.
Audit log inmutable en `bkernel_db.audit_events` (ISO 27001 A.8.15).
Alertas Wazuh SIEM HIGH/CRITICAL en tiempo real.

### ❌ Lo que NO existe en el SBOS

| Patrón prohibido | Razón |
|---|---|
| `KC → Tryton` | Comunicación directa — NUNCA |
| `Tryton → KC` | Comunicación directa — NUNCA |
| `App → KC` | Todo pasa por bAuth |
| `banexus → bAuth` | SIEMPRE: `banexus → bhnexus → bAuth` |
| `bos_bitmask` 64 bits | Reemplazado por `BitmaskBundle` 3×uint64 desde v5.0 |
| Jurisdicción en `RolTemplate` | Pertenece a `deploy.yml` — corrección crítica J1 |
| Bits `GOV_NORMATIVE` en SAM-128 | Eliminados — corrección J2 |

---

## 3. El Triángulo KC — bAuth — Tryton

La comprensión correcta de este triángulo es el fundamento de todo el sistema de identidad del SBOS.

```
┌─────────────────────────────────────────────────────────────────┐
│                          bAuth                                   │
│                    (Coordinador Central)                         │
│                                                                  │
│  "A quien el SBOS pregunta y actualiza en materia de identidad" │
└────────────┬───────────────────────────┬────────────────────────┘
             │                           │
     KC Admin API REST          Tryton XML-RPC API
             │                           │
   ┌─────────▼──────────┐     ┌──────────▼─────────┐
   │     Keycloak        │     │      Tryton         │
   │   (Brazo de IdP)    │     │   (Brazo de ERP)   │
   │                     │     │                     │
   │ • Autentica al user │     │ • Aplica 5 capas de │
   │ • Emite el JWT      │     │   enforcement nativo│
   │ • Gestiona sesiones │     │ • ir.model.access   │
   │ • MFA, WebAuthn,    │     │ • ir.rule (SQL)     │
   │   Passkeys (v26.6+) │     │ • ir.model.button   │
   │ • OIDC/SAML         │     │ • ir.model.field    │
   │ • SPIs personalizados│    │ • ir.action.groups  │
   └─────────────────────┘     └─────────────────────┘
```

### La Separación más Importante: Sincronización vs Login Time

> KC **no** consulta el `RolTemplate` en tiempo de login.
> bAuth **TRADUCE** el `RolTemplate` a objetos nativos de KC **ANTES** de que llegue ningún usuario.
> En login time, KC solo lee su propia base de datos interna — sin depender de bAuth.

### El Patrón PAP / PIP / PDP / PEP

| Punto | Función | Implementación SBOS |
|---|---|---|
| **PAP** — Policy Administration Point | Donde se administran las políticas | Core UI → formulario `RolTemplate`/`UserTemplate` |
| **PIP** — Policy Information Point | Donde viven los datos | PostgreSQL → `bos_rol_template` (JSONB) |
| **bAuth** | Traductor PIP → PDP + PEP en < 5s | `bauth.service` — sincronizador idempotente |
| **PDP** — Policy Decision Point | Quién decide si se permite | KC (login) + bAuth (operación) + Tryton (enforcement) |
| **PEP** — Policy Enforcement Point | Quién bloquea o permite | Tryton (5 capas) + KC (SPIs) + OAuth2-Proxy + `banexus` |

---

## 4. RolTemplate y UserTemplate: El Único Contrato

### Principio Absoluto

> `RolTemplate` y `UserTemplate` son el **único contrato** de comunicación y configuración entre el SBOS y todos los sistemas de autenticación.

### Separación de Responsabilidades

| Dimensión | RolTemplate | UserTemplate |
|---|---|---|
| **Pregunta** | ¿Qué PUEDE HACER un tipo de rol? | ¿Quién ES y qué TIENE este usuario concreto? |
| **Granularidad** | Define una categoría organizacional | Define una persona concreta |
| **Permisos** | Los define | Los hereda del `RolTemplate` |
| **Autenticación** | Define qué métodos son REQUERIDOS | Registra qué métodos TIENE disponibles |
| **Jurisdicción** | ❌ NO pertenece aquí (corrección J1) | ❌ NO pertenece aquí |
| **Sincroniza en KC** | Auth Flows, Session Settings, User Attributes del rol | User record, credenciales registradas, rol asignado |
| **Sincroniza en Tryton** | Grupos, `ir.model.access`, Button Rules | `res.user`, `company.employee` |

### ⚠️ CORRECCIÓN CRÍTICA J1 — Jurisdicción

La jurisdicción regional (Bolivia / Argentina / México) **NO** pertenece al `RolTemplate` ni al SAM-128. Pertenece **exclusivamente** a `deploy.yml`. Es una propiedad de la instalación del sistema, no del usuario ni del rol.

```yaml
# deploy.yml — ÚNICO lugar donde vive la jurisdicción
tenant:
  jurisdiction: "BO"   # → activa módulos SIAT en Tryton, retención 10 años, BOB
  regional_config:
    country_code: "BO"
    tax_system:   "SIAT_BO"
    vat_rate:     13
    data_retention:
      audit_logs_years: 10  # Ley 843 Bolivia
```

---

## 5. Esquema de Almacenamiento PostgreSQL

Patrón híbrido: columnas normalizadas para indexación y WAL detection + campo JSONB para el cuerpo completo del contrato.

```sql
-- Tabla principal de RolTemplates
CREATE TABLE bos_rol_template (
    id              TEXT PRIMARY KEY,          -- "ROL-CAJERO-001"
    tenant_id       TEXT NOT NULL,
    empresa_id      TEXT NOT NULL,
    parent_id       TEXT REFERENCES bos_rol_template(id),
    status          TEXT NOT NULL DEFAULT 'DRAFT',
    version         TEXT NOT NULL,
    -- BitmaskBundle: tres columnas (v5.0 — reemplaza sam128_lo/sam128_hi)
    sam128_physical  BIGINT,    -- PhysicalDomainMask Q1+Q2
    sam128_logical   BIGINT,    -- LogicalDomainMask (zonas de negocio × verbos)
    sam128_financial BIGINT,    -- FinancialDomainMask Q3
    sam128_governance BIGINT,   -- GovernanceMask Q4
    sync_status     TEXT NOT NULL DEFAULT 'PENDING',
    last_sync_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now(),
    template        JSONB NOT NULL,
    CONSTRAINT chk_status CHECK (
        status IN ('DRAFT','REVIEW','ACTIVE','DEPRECATED','ARCHIVED')
    )
);

CREATE INDEX idx_brt_tenant   ON bos_rol_template(tenant_id, empresa_id);
CREATE INDEX idx_brt_status   ON bos_rol_template(status);
CREATE INDEX idx_brt_template ON bos_rol_template USING GIN(template);
CREATE INDEX idx_brt_zones    ON bos_rol_template
    USING GIN((template->'zones') jsonb_path_ops);
CREATE INDEX idx_brt_network  ON bos_rol_template
    USING GIN((template->'network_domain') jsonb_path_ops)
    WHERE template ? 'network_domain';

-- Historial inmutable (WORM — ISO 27001 A.8.15)
CREATE TABLE bos_rol_template_history (
    history_id    BIGSERIAL PRIMARY KEY,
    rol_id        TEXT NOT NULL,
    version       TEXT NOT NULL,
    template_snap JSONB NOT NULL,
    changed_by    TEXT NOT NULL,
    changed_at    TIMESTAMPTZ DEFAULT now(),
    change_reason TEXT,
    entry_hash    TEXT  -- SHA-256 para cadena de integridad
);

-- WORM: prohibir UPDATE y DELETE
CREATE OR REPLACE RULE no_update_history AS
    ON UPDATE TO bos_rol_template_history DO INSTEAD NOTHING;
CREATE OR REPLACE RULE no_delete_history AS
    ON DELETE TO bos_rol_template_history DO INSTEAD NOTHING;

-- UserTemplates
CREATE TABLE bos_user_template (
    uuid        TEXT PRIMARY KEY,
    username    TEXT NOT NULL,
    email       TEXT NOT NULL,
    tenant_id   TEXT NOT NULL,
    empresa_id  TEXT NOT NULL,
    rol_id      TEXT REFERENCES bos_rol_template(id),
    status      TEXT NOT NULL DEFAULT 'ACTIVE',
    sync_status TEXT NOT NULL DEFAULT 'PENDING',
    kc_user_id  TEXT,
    tryton_user_id INTEGER,
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now(),
    template    JSONB NOT NULL,
    UNIQUE (tenant_id, username)
);

-- Hashes biométricos — NUNCA raw biometric (RGPD Art.9)
CREATE TABLE bauth_biometric_templates (
    id                BIGSERIAL PRIMARY KEY,
    user_uuid         TEXT NOT NULL REFERENCES bos_user_template(uuid),
    tenant_id         TEXT NOT NULL,
    biometric_type    TEXT NOT NULL,
    finger            SMALLINT,
    template_hash     BYTEA NOT NULL,     -- PBKDF2-SHA256 (310k iteraciones)
    salt              BYTEA NOT NULL,
    enrollment_policy TEXT NOT NULL DEFAULT 'admin_only',
    liveness_verified BOOLEAN DEFAULT false,
    admin_verified    BOOLEAN DEFAULT false,
    enrolled_at       TIMESTAMPTZ,
    enrolled_by       TEXT,
    revoked_at        TIMESTAMPTZ,
    CONSTRAINT chk_biometric_type
        CHECK (biometric_type IN ('fingerprint','face','iris','palm_vein')),
    UNIQUE (user_uuid, biometric_type, COALESCE(finger, 0))
);

-- Log de sincronización
CREATE TABLE bauth_sync_log (
    id              BIGSERIAL PRIMARY KEY,
    rol_id          TEXT NOT NULL,
    tenant_id       TEXT NOT NULL,
    sync_type       TEXT NOT NULL,
    triggered_by    TEXT NOT NULL,
    status          TEXT NOT NULL,
    kc_status       TEXT,
    tryton_status   TEXT,
    error_message   TEXT,
    retry_count     INTEGER DEFAULT 0,
    next_retry_at   TIMESTAMPTZ,
    started_at      TIMESTAMPTZ DEFAULT now(),
    completed_at    TIMESTAMPTZ
);

-- Mapeo zona → aplicaciones (respaldo de zone_application_map.yaml)
CREATE TABLE bos_zone_application_map (
    zone_id      TEXT NOT NULL,
    app_id       TEXT NOT NULL,
    app_scopes   TEXT[],
    client_id    TEXT,
    modules      TEXT[],
    active       BOOLEAN DEFAULT true,
    last_updated TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (zone_id, app_id)
);
```

---

## 6. Los 15 Métodos de Autenticación Canónicos

El `Authentication_Framework` define 15 métodos en 5 categorías. Todos sincronizados por bAuth como Authentication Flows en Keycloak.

### 6.1 Tabla Maestra de los 15 Métodos

| ID Canónico | Categoría | LoA | Resistente a Phishing | Estado NIST SP 800-63B-4 | Keycloak |
|---|---|---|---|---|---|
| `username_password` | Conocimiento | 1 | No | `PERMITTED` — mín 8 chars con MFA · 15 chars solo (J6) | Nativo |
| `totp` | Posesión | 2 | No | `PERMITTED` — RFC 6238 | Nativo |
| `hotp` | Posesión | 2 | No | `PERMITTED` — RFC 4226 | Nativo |
| `backup_codes` | Conocimiento | 1 | No | `PERMITTED_RECOVERY_ONLY` | Nativo |
| `security_questions` | Conocimiento | 0 | No | `NOT_RECOMMENDED` | Solo SPI — evitar |
| `webauthn_roaming` | Posesión | 3 | **Sí** | `PERMITTED_AAL3` | Nativo KC 21+ |
| `passkey` | Posesión+Inherencia | 2 | **Sí** | `PERMITTED_AAL2` (NIST SP 800-63B-4 final jul 2025) | **Nativo KC 26.6+** ✅ |
| `x509_smartcard` | Posesión+Conocimiento | 3–4 | **Sí** | `PERMITTED_AAL3` | Nativo + BOS-SmartCardPIN-SPI |
| `magic_link` | Posesión | 1 | No | `PERMITTED` — TTL 5min | Nativo |
| `email_otp` | Posesión | 1 | No | `RESTRICTED_AS_SOLE_2FA` (J10) | Nativo KC 26+ |
| `sms_otp` | Posesión | 1 | No | `RESTRICTED §5.2.10` — Restricted Authenticator (J8) | BOS-SMS-SPI + Twilio/AWS |
| `push_notification` | Posesión | 2 | No | `PERMITTED` | BOS-Push-SPI + FCM/APNs |
| `webauthn_platform` | Posesión+Inherencia | 2 | **Sí** | `PERMITTED_AAL2` | Nativo KC 21+ |
| `kerberos_spnego` | Posesión | 2 | Sí (red corp.) | `PERMITTED` | Nativo |
| `federated_identity` | Contexto | Variable | Variable | `PERMITTED` | Nativo (OIDC/SAML broker) |

> **VALIDACIÓN X-RAY:** La tabla confirma las correcciones J6 (longitud mínima), J8 (SMS como Restricted Authenticator), J9 (passkeys = AAL2 válido), J10 (email_otp prohibido como único segundo factor) del Plan Consolidado v3.0. NIST SP 800-63B-4 fue publicado en su versión final el 31 de julio de 2025.

### Notas Críticas de Cumplimiento (NIST SP 800-63B-4, publicado 31 jul 2025)

- **`passkey` = AAL2 válido.** Las passkeys sincronizables califican como AAL2 desde NIST SP 800-63B-4 (Apéndice B). **Keycloak 26.4.0** oficializó el soporte de passkeys para producción (septiembre 2025). La versión canónica del SBOS es **KC 26.6.1** que mantiene soporte completo de passkeys más correcciones de seguridad críticas.
- **`email_otp`** está **PROHIBIDO** como único segundo factor cuando el primero es contraseña. (J10)
- **`sms_otp`** es "Restricted Authenticator" — requiere análisis de riesgo documentado. (J8)
- **Rotación periódica de contraseñas: SHALL NOT (prohibida)** — solo cambiar ante compromiso detectado. (J7)
- **Longitud mínima:** 15 chars como factor único; 8 chars con MFA. (J6)
- **Sin reglas de complejidad arbitrarias** — usar screening contra listas de contraseñas comprometidas.

### 6.2 Métodos del Dominio Físico (Canal bhnexus — Fuera de KC)

| ID | LoA | Validado por | Nota de seguridad |
|---|---|---|---|
| `qr_dynamic_physical` | 1–2 | `bhnexus` HMAC-SHA256 | TTL 30s, one-time |
| `fingerprint_hash_physical` | 3 | `bAuth` vs `bauth_biometric_templates` | Raw biometric NUNCA sale del chip |
| `face_hash_physical` | 3 | `bAuth` vs `bauth_biometric_templates` | Solo hash PBKDF2-SHA256 |
| `nfc_mifare_desfire` | 2 | `bhnexus` decrypt AES-128 | Clave rotada c/90 días en Vault |
| `rfid_125khz` | 1 | `bhnexus` mapeo `card_number` | Legado — solo si no hay alternativa |

---

## 7. Integración Keycloak: Nativo vs SPIs vs Externo

### 7.1 Keycloak como Orquestador Central

```
                    ┌─────────────────────────────────┐
                    │         bAuth (traductor)        │
                    │    RolTemplate → SAM → KC        │
                    └──────────────┬──────────────────┘
                                   │ sincroniza
                    ┌──────────────▼──────────────────┐
                    │        KEYCLOAK 26.6.1           │
                    │   • Autenticación nativa         │
                    │   • Passkeys (nativas desde v26.4)│
                    │   • Auth Flows + 5 SPIs bAuth    │
                    │   • Emisión JWT firmados RSA/EdDSA│
                    │   • Identity Brokering OIDC/SAML │
                    │   • FAPI 2.0 Final + DPoP (RFC 9449)│
                    └──┬──────┬──────┬────────┬───────┘
                       │      │      │        │
              ┌────────▼─┐  ┌─▼───┐ ┌▼──────┐ ┌▼──────────┐
              │ FaceTec  │  │LDAP/│ │ Open  │ │ Plataforma │
              │ BioID    │  │ AD  │ │Quantum│ │ IoT + PKI  │
              │(biometría│  │(SSO)│ │ Safe  │ │(dispositivos│
              │multimodal)│ │     │ │(PQC)  │ │ X.509)     │
              └──────────┘  └─────┘ └───────┘ └────────────┘
```

### 7.2 Passkeys en KC 26.6.1 — Versión Canónica SBOS

<br>

> **🔒 DECISIÓN ARQUITECTÓNICA CERRADA:** La versión canónica de Keycloak para el SBOS es **26.6.1**. Esta decisión está fijada en este documento y no debe modificarse sin una ADR formal.

**Cronología de la decisión:**

| Versión | Fecha | Hito relevante para SBOS |
|---|---|---|
| KC 23.0.0 | 2023 | Passkeys disponibles como preview |
| KC 26.4.0 | Sep 2025 | Passkeys **production-ready**. FAPI 2.0 Final. DPoP (RFC 9449) |
| KC 26.4.x | Oct 2025–Mar 2026 | Parches de seguridad (CVE-2026-2092, CVE-2026-2575, etc.) |
| KC 26.6.0 | 8 Abr 2026 | JWT Authorization Grant (RFC 7523) production. Workflows IGA. Zero-downtime patch releases. Federated Client Auth. CIMD para MCP |
| **KC 26.6.1** | **~14 Abr 2026** | **Parche de seguridad crítico: CVE-2026-4366 (SSRF) y CVE-2026-4633 (user enumeration). VERSIÓN CANÓNICA SBOS** |

**¿Por qué 26.6.1 y no 26.4.x?** KC 26.6 agrega features que el SBOS necesita en producción:

- **Zero-downtime patch releases** → actualizaciones de parche sin downtime del realm (crítico para SLA)
- **Workflows IGA** → automatización del ciclo de vida de usuarios/clientes vía YAML (integra con §14)
- **JWT Authorization Grant (RFC 7523) production-ready** → token exchange externo→interno para service accounts
- **Federated Client Authentication** → elimina gestión de secrets individuales por cliente KC
- **Graceful HTTP Shutdown** → evita errores cuando nodos se apagan (mejora UX del §18 coordinación NEXUS)
- **OpenJDK 25 support** → preparación para siguiente LTS (imagen container sigue en Java 21 para FIPS)
- **CIMD experimental** → KC como authorization server para MCP (relevante para integraciones futuras)

**¿Por qué 26.6.1 y no 26.6.0?** KC 26.6.0 tenía dos CVEs activos:
- `CVE-2026-4366`: Blind Server-Side Request Forgery (SSRF) via HTTP Redirect Handling
- `CVE-2026-4633`: User enumeration via identity-first login

Ambos corregidos en 26.6.1. Nunca desplegar 26.6.0 en producción.

**Configuración bAuth para KC 26.6.1:**

```toml
# bauth.toml
[keycloak]
keycloak_version = "26.6.1"   # versión canónica SBOS — NO usar 26.6.0 (CVEs activos)
```

- Passkeys son **phishing-resistant** por diseño criptográfico (vinculadas al dominio de origen).
- NIST SP 800-63B-4 las reconoce como **AAL2 válido** (jul 2025).
- No requieren SPI adicional — son completamente nativas en KC 26.6.1.
- KC 26.6.1 incluye soporte completo de **FAPI 2.0 Final**, **DPoP (RFC 9449)**, **Workflows IGA**, y **zero-downtime patch releases**.

```
Sync: bAuth configura WebAuthn Passwordless Policy en KC:
  userVerification = "required"
  attestationConveyancePreference = "direct"
  Passkeys habilitadas en: Authentication → Policies → WebAuthn Passwordless Policy
```

### 7.3 Step-Up Authentication (RFC 9470) en KC

bAuth implementa step-up vía el SPI `SkbosStepUpCondition` + configuración de KC:

```go
// LoA levels en bAuth
var LoAMap = map[string]int{
    "standard":       1,  // pwd + OTP/TOTP
    "elevated":       2,  // pwd + WebAuthn platform / Passkey
    "high_security":  3,  // pwd + WebAuthn hardware key
    "critical":       4,  // WebAuthn + quórum de aprobadores
}
```

### 7.4 Estrategia para Capacidades Avanzadas (fuera de KC nativo)

| Capacidad | KC nativo | Estrategia SBOS |
|---|---|---|
| SMS OTP | ❌ | BOS-SMS-SPI + Twilio/AWS SNS (Restricted Authenticator) |
| Push Notification | ❌ | BOS-Push-SPI + FCM/APNs + app SBOS móvil |
| Biometría multimodal avanzada | ❌ | IdP externo (FaceTec, BioID) via OIDC/SAML broker |
| Quantum-resistant crypto en KC | ❌ | `liboqs-java` en JVM de KC (mediano plazo v1.5) |
| IoT/M2M device auth | Parcial | PKI externa (Vault PKI) + `client_credentials` flow |

---

## 8. El SAM-128 — Sovereign Authority Matrix (Versión Corregida)

### 8.1 Correcciones Críticas a la Versión Anterior

La v4.0 del SAM-128 contenía errores que el documento `SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md` identificó y que esta v5.0 corrige definitivamente:

| Error en v4.0 | Corrección en v5.0 | Razón |
|---|---|---|
| XOR para SoD | Conflict Matrix (evaluada en asignación) | XOR puede elevar privilegios involuntariamente |
| NAND para KillSwitch | `AND NOT` (`&^`) | NAND puede otorgar ALL_PERMISSIONS cuando usuario tiene bits distintos |
| Bits `GOV_NORMATIVE_BO/AR/MX` | Eliminados — pertenecen a `deploy.yml` | SAM-128 es vector de autorización, no de cumplimiento regional |
| `bos_bitmask` único 64 bits | `BitmaskBundle`: 3×uint64 independientes | Separación de dominios sin colisión de bits |
| "un registro de 128 bits" | Tres registros uint64 independientes | Evaluadores distintos: `banexus` / `LogicalEvaluator` / `FinancialEvaluator` |

### 8.2 El BitmaskBundle — Tres Registros Independientes

```go
// BitmaskBundle v3 — SKULL · SBOS · bAuth v5.0
// NO es un uint128. Son TRES registros uint64 independientes.
// Cada registro tiene su propio espacio de bits comenzando en 0.
// Cada registro tiene su propio evaluador.
type BitmaskBundle struct {
    // DOMINIO FÍSICO — Evaluado por: banexus
    // Claim JWT: "bos_physical_mask"
    PhysicalDomainMask uint64 `json:"bos_physical_mask"`

    // DOMINIO LÓGICO — Zonas de negocio × verbos (NO aplicaciones)
    // Evaluado por: LogicalDomainEvaluator
    // Claim JWT: "bos_logical_mask"
    LogicalDomainMask uint64 `json:"bos_logical_mask"`

    // DOMINIO FINANCIERO — Límites, aprobaciones, SoD
    // Evaluado por: FinancialDomainEvaluator
    // Claim JWT: "bos_financial_mask"
    FinancialDomainMask uint64 `json:"bos_financial_mask,omitempty"`
}
```

**Por qué NO es un uint128 monolítico:**
- `banexus` evalúa solo `PhysicalDomainMask`. No necesita conocer la existencia de los otros.
- `trytond-auth-keycloak` evalúa solo `LogicalDomainMask`.
- La colisión de bits (`PERM_IMPORT` bit 5 ERP vs `DRAWER_OPEN` bit 5 VDI) desaparece estructuralmente.
- Agregar `FinancialDomainMask` es agregar un tercer registro — sin renumerar bits existentes.

### 8.3 Mapa de Bits: PhysicalDomainMask (uint64)

```
PHYSICAL DOMAIN MASK — bos_physical_mask en JWT
Evaluado por: banexus

Zona 1 — Sesión y Shell (bits 0–7):
  Bit 0:  SESSION_VALID          — sesión activa y autenticada
  Bit 1:  SHELL_UNLOCK           — desbloquear shell Fedora KDE
  Bit 2:  APP_TRYTON             — acceso a Tryton en escritorio
  Bit 3:  APP_ORANGEHRM          — acceso a OrangeHRM en escritorio
  Bit 4:  APP_SALEOR             — acceso a Saleor en escritorio
  Bit 5:  DRAWER_OPEN            — activar relé cajón de dinero
  Bit 6:  APP_FIREFOX            — navegador web autorizado
  Bit 7:  APP_LIBREOFFICE        — suite ofimática

Zona 2 — Puertas y Zonas Físicas (bits 8–15):
  Bit 8:  DOOR_ZONE_A            — puertas Zona A
  Bit 9:  DOOR_ZONE_B            — puertas Zona B
  Bit 10: DOOR_ZONE_C            — puertas Zona C (restringida)
  Bit 11: DOOR_ZONE_D            — puertas Zona D (crítica)
  Bit 12: PHY_SECURITY_LEVEL_1   — zonas públicas (lobby)
  Bit 13: PHY_SECURITY_LEVEL_2   — zonas empleados (ventas, admin)
  Bit 14: PHY_SECURITY_LEVEL_3   — zonas restringidas (servidores)
  Bit 15: PHY_SECURITY_LEVEL_4   — zonas críticas (bóveda, data center)

Zona 3 — Hardware y Red (bits 16–23):
  Bit 16: PRINT_ALLOWED          — imprimir documentos físicos
  Bit 17: USB_STORAGE            — almacenamiento USB autorizado
  Bit 18: NETWORK_EXTERNAL       — acceso internet externo
  Bit 19: VPN_ACCESS             — VPN corporativa
  Bit 20: ADMIN_PANEL            — panel de administración
  Bit 21: APP_THUNDERBIRD        — cliente de correo
  Bit 22: TERMINAL_POS           — habilitar terminal punto de venta
  Bit 23: CAMERA_VIEW            — visualizar feeds de cámaras

Zona 4 — Operaciones de Caja (bits 24–31):
  Bit 24: BOS_CAJA_APERTURA      — apertura de caja
  Bit 25: BOS_CAJA_CIERRE        — cierre de caja
  Bit 26: BOS_CAJA_ARQUEO        — arqueo de caja
  Bit 27: PHY_CHECKIN            — registro de entrada al local
  Bit 28: PHY_CHECKOUT           — registro de salida del local
  Bit 29: PHY_BIOMETRIC_VALID    — biométrico verificado en este acceso
  Bits 30–31: PHY_CUSTOM_1/2     — definibles por tenant

Bits 32–62: RESERVADOS para extensión de zonas físicas
Bit 63:     ADMIN_LOCAL          — privilegios admin local (reservado alto)
```

### 8.4 Mapa de Bits: LogicalDomainMask (uint64)

La semántica del bit es **zona de negocio × verbo**, NO la aplicación concreta. Las aplicaciones se resuelven en `zone_application_map.yaml`.

```
LOGICAL DOMAIN MASK — bos_logical_mask en JWT
Evaluado por: LogicalDomainEvaluator

Zona CONTABILIDAD (bits 0–3):
  Bit 0:  CONTABILIDAD_READ      — leer registros contables
  Bit 1:  CONTABILIDAD_WRITE     — crear/modificar asientos
  Bit 2:  CONTABILIDAD_APPROVE   — aprobar (SoD: ≠ WRITE)
  Bit 3:  CONTABILIDAD_AUDIT     — acceso a logs contables

Zona RRHH (bits 4–7):
  Bit 4:  RRHH_READ              — leer datos de empleados
  Bit 5:  RRHH_WRITE             — modificar datos empleados
  Bit 6:  RRHH_APPROVE           — aprobar solicitudes (SoD: ≠ solicitante)
  Bit 7:  RRHH_AUDIT             — auditar RRHH

Zona VENTAS (bits 8–11):
  Bit 8:  VENTAS_READ            — leer pedidos/clientes
  Bit 9:  VENTAS_WRITE           — crear/modificar pedidos
  Bit 10: VENTAS_APPROVE         — aprobar descuentos/créditos
  Bit 11: VENTAS_AUDIT           — acceso a reportes ventas

Zona SOPORTE (bits 12–15):
  Bit 12: SOPORTE_READ           — leer tickets
  Bit 13: SOPORTE_WRITE          — crear/responder tickets
  Bit 14: SOPORTE_CONFIGURE      — configurar colas, SLAs
  Bit 15: SOPORTE_AUDIT          — auditar soporte

Zona FACTURACIÓN (bits 16–19):
  Bit 16: FACTURACION_READ       — leer facturas
  Bit 17: FACTURACION_WRITE      — crear documentos
  Bit 18: FACTURACION_EMIT       — emitir factura electrónica
  Bit 19: FACTURACION_VOID       — anular factura (SoD: ≠ EMIT)

Zona REPORTES (bits 20–23):
  Bit 20: REPORTES_READ          — leer dashboards y reportes
  Bit 21: REPORTES_EXECUTE       — ejecutar reportes bajo demanda
  Bit 22: REPORTES_EXPORT        — exportar datos a CSV/Excel
  Bit 23: REPORTES_CONFIGURE     — configurar reportes y dashboards

Zona ADMINISTRACIÓN SISTEMA (bits 24–27):
  Bit 24: ADMIN_SYSTEM_READ      — leer configuración del sistema
  Bit 25: ADMIN_SYSTEM_WRITE     — modificar configuración
  Bit 26: ADMIN_USERS            — gestionar usuarios y roles
  Bit 27: ADMIN_AUDIT            — acceso completo a todos los logs

Bits 28–62: RESERVADOS para zonas adicionales
             (Manufactura, Proyectos, Logística, CRM, etc.)
Bit 63:     SUPERZONE            — NUNCA asignar por RolTemplate
```

### 8.5 Mapa de Bits: FinancialDomainMask (uint64)

```
FINANCIAL DOMAIN MASK — bos_financial_mask en JWT
Evaluado por: FinancialDomainEvaluator

Control de Caja (bits 0–3):
  Bit 0:  CAJA_APERTURA          — apertura (SoD: ≠ CAJA_AUDITORIA)
  Bit 1:  CAJA_CIERRE            — cierre de caja
  Bit 2:  CAJA_ARQUEO            — arqueo de caja
  Bit 3:  CAJA_AUDITORIA         — auditoría (SoD: ≠ CAJA_APERTURA)

Pagos y Transferencias (bits 4–9):
  Bit 4:  PAGO_CREATE            — crear órdenes de pago (SoD: ≠ PAGO_APPROVE)
  Bit 5:  PAGO_APPROVE_L1        — aprobar hasta Tier 1 (≤1.000 BOB/ARS/MXN)
  Bit 6:  PAGO_APPROVE_L2        — aprobar hasta Tier 2 (≤10.000)
  Bit 7:  PAGO_APPROVE_L3        — aprobar hasta Tier 3 (≤50.000)
  Bit 8:  PAGO_APPROVE_L4        — aprobar hasta Tier 4 (≤200.000)
  Bit 9:  PAGO_AUDIT             — auditar pagos

Facturación Electrónica (bits 10–11):
  Bit 10: INVOICE_EMIT           — emitir factura (SoD: ≠ INVOICE_VOID)
  Bit 11: INVOICE_VOID           — anular factura (SoD: ≠ INVOICE_EMIT)

Nómina (bits 12–14):
  Bit 12: NOMINA_INPUT           — ingresar datos (SoD: ≠ NOMINA_APPROVE)
  Bit 13: NOMINA_APPROVE         — aprobar nómina (SoD: ≠ NOMINA_INPUT)
  Bit 14: NOMINA_AUDIT           — auditar nómina

Compras (bits 15–17):
  Bit 15: COMPRA_SOLICITUD       — solicitar compra (SoD: ≠ COMPRA_APROBACION)
  Bit 16: COMPRA_APROBACION      — aprobar compra (SoD: ≠ COMPRA_SOLICITUD)
  Bit 17: COMPRA_RECEPCION       — recibir mercadería

Control Cierre (bits 18–19):
  Bit 18: PERIOD_CLOSE           — cerrar período contable (LoA 4 requerido)
  Bit 19: FISCAL_REPORT          — generar reporte fiscal

Auditoría Financiera (bits 20–23):
  Bit 20: FIN_SOD_ACTIVE         — rol bajo restricciones SoD
  Bit 21: FIN_DUAL_CONTROL       — operaciones requieren segundo aprobador
  Bit 22: FIN_TIMESTAMP_SEAL     — transacciones con sello inmutable
  Bit 23: FIN_AUDIT_ALL          — auditoría completa de todas las ops

Bits 24–62: RESERVADOS
```

### 8.6 GovernanceMask (uint64) — Sin Bits Jurisdiccionales

```
GOVERNANCE MASK — bos_sam128_governance en JWT
(metadata de gobernanza — no es una máscara de dominio operativo)

Zona 1 — Nivel de Autoridad (bits 0–7):
  Bits 0–3:  GOV_LOA_LEVEL    — Level of Assurance (1–4)
  Bits 4–7:  GOV_ROLE_TIER    — Tier del rol (0001=Operativo, 0010=Supervisor,
                                 0100=Gerencia, 1000=Dirección/C-Level)

Zona 2 — Auditoría Forzada (bits 8–15):
  Bit 8:  GOV_AUDIT_ALL        — todas las acciones auditadas
  Bit 9:  GOV_AUDIT_FINANCE    — acciones financieras auditadas (nivel extra)
  Bit 10: GOV_AUDIT_ACCESS     — accesos físicos auditados
  Bit 11: GOV_AUDIT_CONFIG     — cambios de configuración auditados
  Bit 12: GOV_IMMUTABLE_LOG    — logs inmutables para este actor
  Bit 13: GOV_ALERT_HIGH       — acciones generan alertas HIGH en Wazuh
  Bit 14: GOV_AUDIT_PCI        — rol sujeto a auditoría PCI-DSS v4.0
  Bit 15: GOV_AUDIT_GDPR_BIO   — rol con datos biométricos (RGPD Art.9)

  *** ELIMINADOS vs v4.0 (corrección J2) ***
  ❌ GOV_NORMATIVE_BO → deploy.yml
  ❌ GOV_NORMATIVE_PCI → reemplazado por GOV_AUDIT_PCI
  ❌ GOV_NORMATIVE_AR/MX → ahora en deploy.yml

Zona 3 — Identidad Especial (bits 16–31):
  Bit 16: GOV_IS_SUPERUSER     — sin bits operativos por defecto
  Bit 17: GOV_CONTEXT_ACTIVE   — asunción de contexto activa
  Bit 18: GOV_IS_MACHINE       — service account (no humano)
  Bit 19: GOV_EMERGENCY        — acceso de emergencia activo (rompe SoD)
  Bit 20: GOV_DELEGATE_ACTIVE  — delegación temporal activa
  Bit 21: GOV_BIOMETRIC_REQ    — biométrico obligatorio para este rol
  Bit 22: GOV_STEP_UP_PENDING  — step-up de LoA pendiente en sesión
  Bits 23–31: GOV_CUSTOM       — definibles por admin del tenant
```

### 8.7 Motor Algebraico Go — Operadores Correctos

```go
// bitmask.go — SKULL · SBOS · bAuth v5.0
package bitmask

type BitmaskBundle struct {
    PhysicalDomainMask  uint64 `json:"bos_physical_mask"`
    LogicalDomainMask   uint64 `json:"bos_logical_mask"`
    FinancialDomainMask uint64 `json:"bos_financial_mask,omitempty"`
}

// HasPhysicalPermission — O(1), ~0.45 ns/op, zero allocations
func (b BitmaskBundle) HasPhysicalPermission(bit uint64) bool {
    return b.PhysicalDomainMask & bit != 0
}
func (b BitmaskBundle) HasLogicalPermission(bit uint64) bool {
    return b.LogicalDomainMask & bit != 0
}
func (b BitmaskBundle) HasFinancialPermission(bit uint64) bool {
    return b.FinancialDomainMask & bit != 0
}

// InheritFromParent — AND NOT: H-RBAC con herencia jerárquica
// hijo = padre &^ bits_removidos
// NUNCA usar XOR (puede otorgar permisos involuntariamente)
func InheritFromParent(parent, bitsToRemove BitmaskBundle) BitmaskBundle {
    return BitmaskBundle{
        PhysicalDomainMask:  parent.PhysicalDomainMask  &^ bitsToRemove.PhysicalDomainMask,
        LogicalDomainMask:   parent.LogicalDomainMask   &^ bitsToRemove.LogicalDomainMask,
        FinancialDomainMask: parent.FinancialDomainMask &^ bitsToRemove.FinancialDomainMask,
    }
}

// MergeRoles — OR: unión de roles activos simultáneamente
// PRE-CONDICIÓN: Conflict Matrix verificada ANTES de llamar esto
func MergeRoles(a, b BitmaskBundle) BitmaskBundle {
    return BitmaskBundle{
        PhysicalDomainMask:  a.PhysicalDomainMask  | b.PhysicalDomainMask,
        LogicalDomainMask:   a.LogicalDomainMask   | b.LogicalDomainMask,
        FinancialDomainMask: a.FinancialDomainMask | b.FinancialDomainMask,
    }
}

// DelegateWithMinPrivilege — AND: delegación con mínimo privilegio
// Resultado = intersección de permisos del grantor y el delegatee
func DelegateWithMinPrivilege(grantor, delegatee BitmaskBundle) BitmaskBundle {
    return BitmaskBundle{
        PhysicalDomainMask:  grantor.PhysicalDomainMask  & delegatee.PhysicalDomainMask,
        LogicalDomainMask:   grantor.LogicalDomainMask   & delegatee.LogicalDomainMask,
        FinancialDomainMask: grantor.FinancialDomainMask & delegatee.FinancialDomainMask,
    }
}

// RevokeEmergency — AND NOT: KillSwitch en emergencia
// NUNCA NAND (puede elevar privilegios — defecto documentado en SBOS-BITMASK-ANALISIS)
func RevokeEmergency(current, toRevoke BitmaskBundle) BitmaskBundle {
    return BitmaskBundle{
        PhysicalDomainMask:  current.PhysicalDomainMask  &^ toRevoke.PhysicalDomainMask,
        LogicalDomainMask:   current.LogicalDomainMask   &^ toRevoke.LogicalDomainMask,
        FinancialDomainMask: current.FinancialDomainMask &^ toRevoke.FinancialDomainMask,
    }
}
```

### 8.8 Serialización en JWT

```json
{
  "sub": "uuid-cajero",
  "preferred_username": "ivan.cajero",
  "realm_access": {"roles": ["ROL-CAJERO-001"]},

  "bos_physical_mask":  "0x0000000003E60053",
  "bos_logical_mask":   "0x0000000000000303",
  "bos_financial_mask": "0x0000000000506011",

  "bos_context": {
    "zone_logical": {
      "ventas":      ["READ", "WRITE"],
      "facturacion": ["READ", "EMIT"]
    },
    "zone_physical": {
      "pos_caja":    ["EXECUTE", "OPEN"],
      "zone_ventas": ["ACCESS"]
    },
    "zone_financial": {
      "caja":       ["OPEN", "CLOSE"],
      "ventas":     ["CREATE"],
      "limit_tier": 2,
      "daily_limit": 10000,
      "currency":   "BOB",
      "sod_active": true
    }
  },

  "bos_governance": {
    "loa_level":        2,
    "role_tier":        "operativo",
    "role_valid_until": "2027-01-01",
    "sod_active":       true,
    "is_superuser":     false,
    "audit_finance":    true
  },

  "bos_node_id":          "Ventas-01",
  "bos_template_version": "3.1.0",
  "acr": "2",
  "amr": ["pwd", "totp"]
}
```

---

## 9. Las 6 Capas de Resolución de Contexto

Las 6 capas no son capas dentro del entero de bits — son niveles de resolución de contexto. Cada capa externa limita el espacio de posibilidades de la capa más interna.

```
CAPA 1 — TENANT (Soberanía de Infraestructura)
  Control: sbos-admin via bos (IAM Installer)
  Pregunta: "¿Existe este módulo en este servidor SBOS?"

CAPA 2 — EMPRESA (Soberanía de Datos)
  Control: realm Keycloak — un realm por empresa (NIT)
  Pregunta: "¿A qué empresa pertenece este usuario?"

CAPA 3 — ROL (Soberanía Operativa)
  Control: RolTemplate en bos_bauth_template → bAuth → KC Composite Role
  Pregunta: "¿Qué puede hacer un Contador vs un Gerente?"

CAPA 4 — APLICACIÓN / ZONA (Soberanía de Contexto)
  Control: bAuth configura qué zonas tiene el rol habilitadas
  Nota: La zona es ABSTRACTA — zona_contabilidad, no "Tryton módulo account"
  Pregunta: "¿En qué zona de negocio puede operar?"

CAPA 5 — DOMINIO (Dimensión de Actuación)
  Control: BitmaskBundle Q1/Q2/Q3 calculado por PrivilegeEngine
  Pregunta: "¿En qué dominio (físico/lógico/financiero) puede actuar?"

CAPA 6 — BitmaskBundle (Vector de Ejecución)
  Control: banexus / LogicalEvaluator / FinancialEvaluator evalúan O(1)
  Pregunta: "¿Tiene ESTE bit específico activo en ESTE dominio?"
```

---

## 10. El Flujo de Sincronización Maestro

```
PASO 1   Admin edita RolTemplate en Core UI (PAP) → Guardar

PASO 2   Core UI → bAuth REST API: PUT /api/v1/roltemplate/{id}
         bAuth valida: JSON Schema, Conflict Matrix, SoD, herencia jerárquica
         Si FAIL → 422 con descripción exacta del error

PASO 3   bAuth escribe en bos_rol_template (PostgreSQL JSONB)
         Columnas normalizadas: status, sam128_physical, sam128_logical,
           sam128_financial, sam128_governance
         PostgreSQL genera evento WAL

PASO 4   bkernel detecta WAL → regla ROLF-001 → activa bauth_sync
         Publica en Redis: bkernel:identity_events
         {type: "roltemplate_changed", role_id: "RGV-001"}

PASO 5   bauth.service consume Redis → PrivilegeEngine.calculate(role_id)
         Si hay parent_id: aplica InheritFromParent() con AND NOT
         Produce BitmaskBundle + bos_context + bos_governance

PASO 6   KeycloakSynchronizer.sync_role() — KC Admin API REST:
         → Composite Role (nombre canónico = id del RolTemplate)
         → Realm roles atómicos (1 por bit activo por dominio)
         → Authentication Flow {id}_browser_flow:
             - SPIs contextuales según bloques del RolTemplate
             - Passkeys habilitadas si passkey ∈ availableMethods (KC 26.6.1)
             - Step-up configurado si step_up_rules presente
         → User Attributes: allowed_networks, shift_start/end, allowed_days,
             role_valid_until, financial_limit_tier
         → Session Settings: duración, concurrencia, LoA

PASO 7   TrytonSynchronizer.sync_groups() — Tryton XML-RPC:
         → ir.model.access (CRUD por modelo — Capa 1)
         → ir.action.groups (menús visibles — Capa 2)
         → ir.model.field.access (campos — Capa 3)
         → ir.model.button (Button Rules + SoD — Capa 4)
         → ir.rule.group (Record Rules SQL — Capa 5)

PASO 8   AppSynchronizer.sync_apps() [cuando adaptador disponible]:
         Para cada app declarada en zones.*.applications con adaptador:
         → Sincroniza via zone_application_map.yaml

PASO 9   bkernel registra en bkernel_db.audit_events (ISO 27001 A.8.15)

PASO 10  bauth actualiza: sync_status = 'SYNCED', last_sync_at = now()

PASO 11  bAuth → bhnexus (Unix socket): policy_update push
         bhnexus invalida SAM en cache
         bhnexus → banexus en nodos afectados: invalida cache efímero

TIEMPO TOTAL PASO 2 → PASO 10: < 5 segundos (garantía)
```

---

## 11. La Interfaz de bAuth

### REST API (Core UI → PAP)

```
POST   /api/v1/roltemplate              Crear (valida + persiste)
PUT    /api/v1/roltemplate/{id}         Actualizar (nueva versión + trigger sync)
DELETE /api/v1/roltemplate/{id}         Deprecar
GET    /api/v1/roltemplate              Listar (filtros: tenant, empresa, status)
GET    /api/v1/roltemplate/{id}         Obtener + historial versiones

POST   /api/v1/usertemplate             Onboarding
PUT    /api/v1/usertemplate/{id}        Actualizar (cambio rol, datos)
DELETE /api/v1/usertemplate/{id}        Offboarding (status → TERMINATED)

POST   /api/v1/authorize/logical        Evaluar acceso lógico (zona × verbo)
POST   /api/v1/authorize/financial      Pre-validar operación financiera
GET    /api/v1/authorize/biometric/{id} Verificar hash biométrico

POST   /api/v1/biometric/enroll         Iniciar enrollment biométrico
PUT    /api/v1/biometric/verify/{id}    Admin aprueba enrollment

GET    /api/v1/sync/status              Estado sincronización global
GET    /api/v1/sync/drift               Roles con drift detectado
POST   /api/v1/sync/resync/{id}         Re-sincronizar un rol
POST   /api/v1/sync/resync-all          Re-sincronizar realm completo

GET    /api/v1/audit                    Historial de auditoría
GET    /api/v1/health                   Estado del daemon
```

### Unix Socket (bhnexus → evaluación en tiempo real)

```go
// /run/bos/bauth.sock — protocolo interno
// Framing: 4 bytes big-endian length + JSON payload UTF-8
// Latencia: < 5ms (cache Redis hit: < 1ms)
// Timeout: 1000ms por request

type AuthQuery struct {
    UserID    string `json:"user_id"`
    NodeID    string `json:"node_id"`
    QueryType string `json:"query_type"`  // bitmask|zone_verb|financial|biometric
    Zone      string `json:"zone,omitempty"`
    Verb      string `json:"verb,omitempty"`
    RequestID string `json:"request_id"`  // UUID v4 para correlación
}

type AuthResponse struct {
    Granted          bool          `json:"granted"`
    PhysicalMask     string        `json:"bos_physical_mask,omitempty"`
    LogicalMask      string        `json:"bos_logical_mask,omitempty"`
    FinancialMask    string        `json:"bos_financial_mask,omitempty"`
    BosContext       interface{}   `json:"bos_context,omitempty"`
    Reason           string        `json:"reason,omitempty"`
    ErrorCode        string        `json:"error_code,omitempty"`
    TTLSeconds       int           `json:"ttl_seconds"`
    ActuatorCommands []ActuatorCmd `json:"actuator_commands,omitempty"`
}

// Códigos de error del protocolo interno
const (
    AUTH_001 = "user_id not found"
    AUTH_002 = "RolTemplate not active or expired"
    AUTH_003 = "physical domain denied (zone/schedule)"
    AUTH_004 = "financial domain denied (limit/SoD)"
    AUTH_005 = "biometric hash mismatch"
    AUTH_006 = "cache expired (offline mode)"
    SRV_001  = "bAuth internal error"
    SRV_002  = "bAuth overloaded (circuit breaker open)"
)
```

---

## 12. Los 5 SPIs que bAuth Construye para Keycloak

bAuth despliega 5 SPIs como JARs en `/opt/keycloak/providers/`. KC 26.x es la versión objetivo.

### SPI-1: BOS-Guard — SkbosGuardAuthenticator

**Responsabilidad:** primer step del Authentication Flow. Lee `availableMethods` del grupo KC (sincronizado desde `RolTemplate`) y bloquea métodos no autorizados para el rol.

```java
package bo.skull.sbos.keycloak.spi;
import org.keycloak.authentication.*;
import org.keycloak.authentication.authenticators.conditional.ConditionalAuthenticator;

public class SkbosGuardAuthenticator implements ConditionalAuthenticator {
    public static final String PROVIDER_ID = "bos-guard-authenticator";

    @Override
    public boolean matchCondition(AuthenticationFlowContext context) {
        String requestedMethod = context.getAuthenticationSession()
                                        .getClientNote("requested_method");
        if (requestedMethod == null) return true;

        String allowedMethodsStr = context.getUser()
                                          .getFirstAttribute("bos_allowed_methods");
        if (allowedMethodsStr == null) return true;

        Set<String> allowedMethods = new HashSet<>(
            Arrays.asList(allowedMethodsStr.split(","))
        );

        if (!allowedMethods.contains(requestedMethod)) {
            context.getEvent().error("method_not_authorized_for_role");
            return false;
        }
        return true;
    }

    @Override public void authenticate(AuthenticationFlowContext c) { c.attempted(); }
    @Override public boolean requiresUser() { return true; }
    @Override public boolean configuredFor(KeycloakSession s, RealmModel r, UserModel u) { return true; }
    @Override public void setRequiredActions(KeycloakSession s, RealmModel r, UserModel u) {}
    @Override public void action(AuthenticationFlowContext c) {}
    @Override public void close() {}
}
```

### SPI-2: BOS-GeoContext — SkbosGeoContextAuthenticator

**Responsabilidad:** verifica que la IP de origen del login está en `allowed_networks`.

```java
@Override
public boolean matchCondition(AuthenticationFlowContext context) {
    String allowedNetworks = context.getUser().getFirstAttribute("allowed_networks");
    if (allowedNetworks == null) return true;

    String remoteAddr = context.getConnection().getRemoteAddr();
    boolean inAllowed = Arrays.stream(allowedNetworks.split(","))
                              .anyMatch(cidr -> isInCidr(remoteAddr, cidr.trim()));
    if (!inAllowed) {
        context.getEvent().error("login_from_unauthorized_network");
        return false;
    }
    return true;
}
```

### SPI-3: BOS-FinancialPeriod — SkbosFinancialPeriodAuthenticator

**Responsabilidad:** verifica `transaction_schedule` del `RolTemplate`. Deniega logins fuera de las ventanas de operación financiera.

### SPI-4: BOS-RoleValidity — SkbosRoleValidityAuthenticator

**Responsabilidad:** verifica que `role_valid_until` del `RolTemplate` no ha expirado.

```java
@Override
public boolean matchCondition(AuthenticationFlowContext context) {
    String validUntil = context.getUser().getFirstAttribute("role_valid_until");
    if (validUntil == null) return true;
    try {
        Instant expiresAt = Instant.parse(validUntil);
        if (Instant.now().isAfter(expiresAt)) {
            context.getEvent().error("role_expired");
            return false;
        }
    } catch (DateTimeParseException e) {
        context.getEvent().detail("warning", "role_valid_until_parse_error:" + validUntil);
    }
    return true;
}
```

### SPI-5: BOS-StepUp — SkbosStepUpCondition

**Responsabilidad:** verifica si el LoA actual de la sesión satisface el requisito de la operación. Implementa RFC 9470.

```java
private static final Map<String, Integer> LOA_ORDER = Map.of(
    "standard",       1,
    "elevated",       2,
    "high_security",  3,
    "critical",       4
);

@Override
public boolean matchCondition(AuthenticationFlowContext context) {
    String requiredAcr = context.getAuthenticationSession()
                                .getClientNote("requested_acr");
    if (requiredAcr == null) return true;

    String currentAcr = AuthenticationManager
        .getSessionAcr(context.getAuthenticationSession());

    int required = LOA_ORDER.getOrDefault(requiredAcr, 1);
    int current  = LOA_ORDER.getOrDefault(currentAcr, 0);
    return current >= required;
}
```

**Archivo META-INF/services:**

```
META-INF/services/org.keycloak.authentication.AuthenticatorFactory:
  bo.skull.sbos.keycloak.spi.SkbosGuardAuthenticatorFactory
  bo.skull.sbos.keycloak.spi.SkbosGeoContextAuthenticatorFactory
  bo.skull.sbos.keycloak.spi.SkbosFinancialPeriodAuthenticatorFactory
  bo.skull.sbos.keycloak.spi.SkbosRoleValidityAuthenticatorFactory
  bo.skull.sbos.keycloak.spi.SkbosStepUpConditionFactory
```

---

## 13. Sincronización Atómica KC ↔ Tryton

### 13.1 Flujo de sync_role() con Manejo de Errores

```go
// Estrategia de compensación: Opción B
// Si KC sincroniza pero Tryton falla → KC queda en estado nuevo (correcto),
// Tryton se reintenta. NO se hace rollback de KC.
func (s *BAuthSyncer) SyncRole(roleID string) error {
    rt, err := s.db.GetRolTemplate(roleID)
    if err != nil { return err }

    // PASO 1: Validar (falla rápido antes de tocar KC o Tryton)
    if err := s.engine.Validate(rt); err != nil {
        return fmt.Errorf("validation failed: %w", err)
    }

    // PASO 2: Calcular BitmaskBundle
    bundle, err := s.engine.Calculate(rt)
    if err != nil { return err }

    // PASO 3: Sincronizar KC (si falla aquí, nada cambia)
    if err := s.kcSync.SyncCompositeRole(rt, bundle); err != nil {
        s.db.SetSyncStatus(roleID, "ERROR", err.Error())
        return fmt.Errorf("KC sync failed: %w", err)
    }

    // PASO 4: Sincronizar Tryton (KC ya está actualizado)
    if err := s.trytonSync.SyncGroup(rt, bundle); err != nil {
        s.db.SetSyncStatus(roleID, "ERROR_TRYTON_PENDING", err.Error())
        s.scheduler.ScheduleRetry(roleID, RetryTryton, backoffPolicy{
            Intervals: []time.Duration{
                30*time.Second, 2*time.Minute, 10*time.Minute,
                1*time.Hour, 4*time.Hour,
            },
        })
        s.alerts.Emit("tryton_sync_failed", roleID, wazuh.MEDIUM)
        return fmt.Errorf("Tryton sync failed (KC OK, retry scheduled): %w", err)
    }

    s.db.SetSyncStatus(roleID, "SYNCED", "")
    s.cache.Invalidate(roleID)
    s.nexus.PushPolicyUpdate(roleID)
    return nil
}
```

### 13.2 Drift Detection (Reconcile Loop)

```
RECONCILE LOOP (cada 60s):
  Para cada RolTemplate ACTIVE:
  │
  ├── Leer estado declarado (bos_rol_template JSONB)
  ├── Leer estado real en KC (Admin API)
  ├── Leer estado real en Tryton (XML-RPC)
  │
  ├── Comparar:
  │   ├── KC group attributes == template.logical_access.geospatial_control?
  │   ├── KC auth flow == template.logical_access.requiredMethods?
  │   ├── Tryton ir.rule == template.zones.*.record_rules?
  │   └── Tryton ir_model_access == template.tryton_privileges?
  │
  ├── SI DRIFT:
  │   ├── sync_status = 'DRIFT'
  │   ├── Alerta Wazuh WARNING: identity_drift_detected
  │   ├── Auto-corrección: re-sincronizar (idempotente)
  │   └── Si auto-corrección falla → alerta CRITICAL al admin
  │
  └── SI NO DRIFT: next template
```

---

## 14. Ciclo de Vida del Realm

### 14.1 Alta de Tenant

```
Saga "onboard-tenant" (desde bAuth durante provisioning):
  Paso 1: Crear realm en Keycloak via Admin API
  Paso 2: Configurar 5 SPIs bAuth en el realm nuevo
  Paso 3: Crear usuarios iniciales (admin + service accounts)
  Paso 4: Desplegar fichas contratadas en namespace K8s
  Paso 5: Crear BD del tenant en PostgreSQL 18
  Paso 6: Actualizar .sbos_state.json
  Paso 7: Emitir evento WAL "tenant.onboarded"

Compensaciones:
  Fallo en Paso 3 → DELETE realm (rollback Paso 1-2)
  Fallo en Paso 4 → DELETE namespace + realm
  Fallo en Paso 5 → DELETE BD + namespace + realm

Tiempo estimado de alta: 15-30 minutos.
```

### 14.2 Suspensión y Baja

```bash
# Suspensión temporal (datos conservados, login bloqueado)
bauth tenant suspend <realm_name>
# → PUT /admin/realms/{realm} {"enabled": false}
# → JWTs activos expiran en 5 minutos

# Baja definitiva
SEMANA -2: Notificación + export de datos al cliente
DÍA 0:    Deshabilitar realm
DÍA 1:    Eliminar namespace K8s + realm KC + BD PostgreSQL
RETENCIÓN: Logs de auditoría según jurisdicción (deploy.yml):
           BO: 10 años (Ley 843)
           AR: 10 años (Código Comercial)
           MX: 5 años (SAT)
```

---

## 15. Delegación Temporal con Vigencia

```yaml
# En UserTemplate.roles_assignments.temporary_assignments
delegations:
  - delegation_id:     "DEL-2026-001"
    delegated_to:      "user-uuid-maria"
    delegated_from:    "user-uuid-gerente"
    role_template:     "RGV-001"
    reason:            "Vacaciones del gerente"
    valid_from:        "2026-03-15T00:00:00Z"
    valid_until:       "2026-03-30T23:59:59Z"
    auto_revoke:       true   # bAuth revoca automáticamente al expirar
    requires_approval: true   # segundo admin debe aprobar
    approved_by:       "admin-uuid"
    approved_at:       "2026-03-14T15:00:00Z"
```

bAuth verifica vigencia en cada evaluación. Al expirar `valid_until` con `auto_revoke: true`, bAuth revoca automáticamente y emite `delegation_expired`. Alerta CRITICAL en Wazuh si la delegación está vencida y no fue revocada.

---

## 16. Presentación de Identidad Física

### QR Dinámico

```
Generación (bAuth):
  URI: sbos://auth/{user_uuid}/{timestamp_unix}/{HMAC-SHA256(vault_key, user+ts)}
  TTL: 30 segundos (configurable en bauth.toml)
  Clave HMAC: una por tenant en Vault, rotada c/90 días

Validación (bhnexus):
  1. Extraer user_uuid, timestamp, hmac del URI
  2. Verificar: now() - timestamp < 30s (TTL)
  3. Recalcular HMAC con clave de Vault
  4. Si OK → consultar bAuth: user_uuid → BitmaskBundle
```

### NFC/RFID y Biométrico

```
NFC DESFire AES-128:
  Tag contiene user_uuid cifrado, bhnexus descifra → bAuth → BitmaskBundle

Biométrico OSDP v2.2.2:
  Chip del lector: imagen → template → hash PBKDF2-SHA256 LOCALMENTE
  Solo el HASH viaja por OSDP Secure Channel (AES)
  bhnexus → bAuth: match hash vs bauth_biometric_templates
  Match → user_uuid → BitmaskBundle con GOV_LOA_LEVEL = LoA 3

INVARIANTE: raw biometric NUNCA sale del chip del lector.
RGPD: cero datos biométricos en ningún servidor SBOS.
```

---

## 17. Gestión de Emergencias

### AssumeTenantContext (Superusuario)

El superusuario (`sbos-admin`) tiene `GOV_IS_SUPERUSER` activo pero Q1+Q2+Q3 en cero por defecto (mínimo privilegio en reposo).

```go
func (b *BAuth) AssumeTenantContext(
    adminUserID string, realmID string, reason string, durationMinutes int,
) (*TenantContext, error) {
    if !b.isGlobalAdmin(adminUserID) {
        return nil, ErrNotAuthorized
    }
    // TTL: mínimo 15 min, máximo 4h (configurable en bauth.toml)
    if durationMinutes < 15 || durationMinutes > 240 {
        return nil, ErrInvalidTTL
    }
    ctx := &TenantContext{
        AdminID:   adminUserID,
        RealmID:   realmID,
        Mask:      BitmaskBundle{
            PhysicalDomainMask:  ^uint64(0),
            LogicalDomainMask:   ^uint64(0),
            FinancialDomainMask: ^uint64(0),
        },
        Reason:    reason,
        ExpiresAt: time.Now().Add(time.Duration(durationMinutes) * time.Minute),
        ContextID: uuid.New().String(),
    }
    // Log inmutable (ISO 27001 A.8.15) → Wazuh alerta HIGH automáticamente
    b.auditLog.Write(AuditEvent{
        EventType: "superuser_context_assumed",
        AdminID:   adminUserID,
        RealmID:   realmID,
        Reason:    reason,
        ContextID: ctx.ContextID,
        ExpiresAt: ctx.ExpiresAt,
        Severity:  "HIGH",
    })
    return ctx, nil
}
```

**Break-glass:** siempre debe existir un segundo `sbos-admin` (`break_glass_uuid` en `bauth.toml`). Si el admin principal no está disponible, el break-glass puede asumir contexto con alerta CRITICAL + notificación al admin principal.

---

## 18. Coordinación con NEXUS

```
TOPOLOGÍA INVARIABLE:
  banexus → bhnexus → bAuth
  NUNCA:  banexus → bAuth directamente

LATENCIAS:
  Cache hit bhnexus:    < 2ms  (sin consultar bAuth)
  Cache miss → bAuth:   < 8ms  (Unix socket)
  Evento físico total:  < 50ms (banexus → bhnexus → bAuth → actuador)
  Policy update push:   < 5s   (bAuth → bhnexus → banexus)

CUANDO ROLTEMPLATE CAMBIA:
  bAuth → bhnexus: policy_update push
  bhnexus: invalida BitmaskBundle en cache de usuarios afectados
  bhnexus → banexus: invalida cache efímero
  Tiempo total: < 5 segundos desde guardar hasta invalidación en nodo
```

---

## 19. Requerimientos de Infraestructura y Escalado

> **VALIDACIÓN X-RAY:** Esta sección integra el análisis completo del documento `SBOS-BAUTH-REQUERIMIENTOS-TECNICOS-v1_2.md`. Los cálculos de memoria, planes de escalado y comparativa de proveedores son coherentes con los valores documentados en ese artefacto.

### 19.1 Cálculo de Memoria por Concurrencia

| Componente | Memoria Base | Por Usuario Concurrente |
|---|---|---|
| PostgreSQL 18 | 512 MB | ~2 MB |
| Keycloak 26.x | 1 GB (JVM heap) | ~5 MB |
| Redis | 64 MB | ~50 KB (BitmaskBundle cache) |
| Tryton 7.x | 256 MB | ~3 MB |
| bAuth (Go) | 64 MB | ~0.5 MB |
| Nginx + Sistema | 512 MB | — |
| **TOTAL** | **~2.5 GB** | **~10.5 MB/usuario** |

### 19.2 Plan de Escalado Gradual (Contabo VPS — Recomendado)

```
FASE 1: Desarrollo (VPS 10 — €4.50/mes)
  Contabo: 4 vCPU / 8 GB / 75 GB NVMe
  Capacidad: 5-10 usuarios concurrentes
  Todo en un solo VPS
  Redis: single node en el mismo VPS (maxmemory 1gb)
  KC JVM: -Xmx2g (limitado explícitamente)

FASE 2: Staging (VPS 20 — €6.80/mes)
  Contabo: 6 vCPU / 12 GB / 100 GB NVMe
  Capacidad: 20-50 usuarios concurrentes
  Redis: single node optimizado (maxmemory 1.5gb)
  KC JVM: -Xmx3g

FASE 3: Producción Small (VPS 30 — €13.70/mes)
  Contabo: 8 vCPU / 24 GB / 200 GB NVMe
  Capacidad: 100-200 usuarios concurrentes
  Redis: single node (maxmemory 2gb) — suficiente hasta 500 usuarios
  KC JVM: -Xmx6g
  PostgreSQL: +réplica separada recomendada

FASE 4: Enterprise (VPS 60+ — €47.70/mes)
  Contabo: 16+ vCPU / 96 GB / 350 GB NVMe
  Capacidad: 500-1000+ usuarios concurrentes
  Redis Cluster 3 nodos: SOLO si dataset > 10 GB o > 500 usuarios activos
  PostgreSQL: Patroni cluster 3 nodos
  KC: cluster 2+ nodos
```

> **¿Por qué Redis single node es suficiente para la mayoría?**
> 1.000 usuarios × 50 KB (BitmaskBundle + contexto) = ~50 MB.
> Con overhead Redis (~30%) + buffer → ~165 MB total estimado para 1.000 usuarios.

### 19.3 Configuración Redis Optimizada para SBOS

```ini
# /etc/redis/redis.conf — Optimizado para SBOS
maxmemory 1600mb              # 20% de RAM del VPS (ej: 8GB)
maxmemory-policy allkeys-lru
appendonly yes
appendfsync everysec

# Seguridad: solo localhost + VLAN interna
bind 127.0.0.1 10.0.100.10
requirepass ${REDIS_PASSWORD_FROM_VAULT}

# Cache de BitmaskBundle (objetos ~50KB)
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
```

### 19.4 Stack Tecnológico del Daemon bAuth

| Componente | Herramienta | Propósito |
|---|---|---|
| Lenguaje | Go 1.22+ | Daemon principal |
| HTTP client KC | `net/http` + `oauth2` | Keycloak Admin REST API |
| XML-RPC client | `github.com/kolo/xmlrpc` | Tryton sync |
| WebSocket server | `github.com/coder/websocket` | Notificaciones a bhnexus |
| PostgreSQL | `github.com/jackc/pgx/v5` | Estado y sesiones |
| JWT generation | `github.com/golang-jwt/jwt/v5` | Tokens internos |
| Config | `github.com/BurntSushi/toml` | `bauth.toml` |
| Logging | `github.com/rs/zerolog` | Audit log |
| Testing | `go test` + `testify` + WireMock | Mock KC y Tryton |
| Build | `go build -ldflags='-s -w'` | Binario estático |

### 19.5 bauth.toml — Configuración de Referencia

```toml
[metadata]
version      = "1.0.0"
environment  = "production"
log_level    = "info"
log_format   = "json"

[keycloak]
url                      = "https://auth.sbos.internal"
realm                    = "master"
client_id                = "bauth-admin"
client_secret_source     = "vault"   # vault | env | file
vault_path               = "secret/bauth/keycloak"
vault_field              = "client_secret"
token_refresh_interval_s = 240
admin_api_timeout_ms     = 5000
admin_api_retry_count    = 3
keycloak_version         = "26.6.1"  # Versión canónica SBOS — patch de seguridad sobre 26.6.0

[tryton]
url       = "http://tryton.sbos.internal:8000"
db        = "tryton_db"
user      = "admin"
pool_size = 10

[postgres]
dsn       = "postgres://bauth:${BAUTH_PG_PASSWORD}@localhost:5432/bauth_db?sslmode=require"
max_conns = 20

[redis]
enabled           = true
addr              = "localhost:6379"
cache_ttl_seconds = 30
cache_max_entries = 10000

[socket]
path               = "/run/bos/bauth.sock"
permissions        = "0660"
owner_group        = "bos"
request_timeout_ms = 1000
max_connections    = 100

[security.password]
# NIST SP 800-63B-4 Final (31 jul 2025) — Correcciones J6 y J7
min_length_sole_authenticator = 15
min_length_with_mfa           = 8
rotation_policy               = "on_compromise_only"  # SHALL NOT rotación periódica
complexity_rules              = "NONE"
compromised_password_check    = true

[security.post_quantum]
# FIPS 203: ML-KEM (basado en CRYSTALS-Kyber) — publicado ago 2024
# FIPS 204: ML-DSA (basado en CRYSTALS-Dilithium) — publicado ago 2024
# FIPS 205: SLH-DSA (basado en SPHINCS+) — publicado ago 2024
primary_kem_algorithm    = "ML-KEM-1024"
primary_sig_algorithm    = "ML-DSA-87"
backup_sig_algorithm     = "SLH-DSA-SHAKE-256s"
hybrid_mode_enabled      = true
classical_fallback_sig   = "ECDSA-P384"
jvm_pqc_library          = "liboqs-java"

[reconcile]
global_interval_seconds = 60
min_interval_seconds    = 30
drift_auto_correct      = true
drift_alert_severity    = "HIGH"

[alerts]
mechanism    = "syslog"
syslog_addr  = "wazuh-manager.sbos.internal:514"
syslog_proto = "tcp"

[superuser]
admin_uuid          = ""   # UUID del sbos-admin
break_glass_uuid    = ""   # Segundo admin para emergencias (obligatorio)
context_ttl_min     = 15
context_ttl_max     = 240  # 4 horas máximo
context_ttl_default = 60
```

---

## 20. Lo que bAuth ES y NO ES

| bAuth **ES** | bAuth **NO ES** |
|---|---|
| El sistema de identidad del SBOS | Un componente más del stack |
| El coordinador KC ↔ Tryton ↔ apps | Un plugin de Keycloak |
| La fuente de verdad sincronizada | Un reemplazo de Keycloak |
| El evaluador de privilegios en tiempo real | El PDP en login time (eso es KC) |
| El generador de BitmaskBundle y bos_context | El cifrador de datos en reposo |
| El guardián del SoD y cumplimiento | Una dependencia crítica en el login |
| El único punto de administración (PAP) | Un sistema que existe sin RolTemplate |
| El que genera Button Rules en Tryton | Quien decide las políticas (el admin) |
| El que gestiona el ciclo de vida del realm | El que gestiona la normativa fiscal (`deploy.yml`) |

---

## 21. Glosario Técnico

| Término | Definición |
|---|---|
| **ACR** | Authentication Context Reference. Valor que describe el nivel de autenticación. |
| **AMR** | Authentication Method Reference (RFC 8176). Array de métodos usados. |
| **AND NOT** | `A &^ B` en Go. Operación para herencia H-RBAC y revocación de emergencia. Nunca usar NAND ni XOR para esto. |
| **BitmaskBundle** | `struct Go {PhysicalDomainMask, LogicalDomainMask, FinancialDomainMask uint64}`. Reemplaza `bos_bitmask` único. |
| **bos_context** | Claim JWT con representación semántica de zonas × verbos del actor. |
| **Button Rule** | Regla en Tryton (`ir.model.button`) con condición PYSON. Generada por bAuth. |
| **Composite Role** | Rol en KC que contiene otros realm roles atómicos. Creado por bAuth. |
| **deploy.yml** | Archivo de configuración de despliegue regional. ÚNICO lugar donde vive la jurisdicción. |
| **Drift** | Estado donde KC o Tryton divergen de lo que define `bos_rol_template`. |
| **H-RBAC** | Hierarchical RBAC (ANSI/INCITS 359-2004). Herencia con AND NOT. |
| **Idempotencia** | Si el estado ya es correcto en KC/Tryton → cero llamadas API. |
| **JWT** | JSON Web Token. Firmado con RSA-256 o EdDSA por KC. Validado con JWKS sin llamadas a KC. |
| **LoA** | Level of Assurance. Nivel 1–4 de seguridad de la autenticación. |
| **ML-KEM** | Module-Lattice Key Encapsulation Mechanism (FIPS 203). Nombre oficial de CRYSTALS-Kyber. |
| **ML-DSA** | Module-Lattice Digital Signature Algorithm (FIPS 204). Nombre oficial de CRYSTALS-Dilithium. |
| **Nombre Canónico** | ID único como Composite Role en KC y Grupo en Tryton. |
| **Passkey** | Credencial FIDO2/WebAuthn sincronizable entre dispositivos. AAL2 válido desde NIST SP 800-63B-4 final (jul 2025). Nativo KC 26.6.1 (versión canónica SBOS). |
| **PAP** | Policy Administration Point. Core UI del SBOS. |
| **PDP** | Policy Decision Point. KC (login) + bAuth (operación) + Tryton (enforcement). |
| **PEP** | Policy Enforcement Point. Tryton (5 capas) + OAuth2-Proxy + `banexus`. |
| **PIP** | Policy Information Point. `bos_rol_template` en PostgreSQL. |
| **PrivilegeEngine** | Motor algebraico de bAuth que calcula BitmaskBundle desde el RolTemplate. |
| **PYSON** | Lenguaje de expresiones de Tryton. Evaluado en tiempo real en el servidor. |
| **Record Rule** | `ir.rule` en Tryton: filtros SQL automáticos por grupo. Generada por bAuth. |
| **Realm Role** | Rol atómico en KC. Cada bit activo del BitmaskBundle = realm roles. |
| **RolTemplate** | Contrato técnico de un rol empresarial. Fuente de verdad única. |
| **SLH-DSA** | Stateless Hash-based Digital Signature (FIPS 205). Nombre oficial de SPHINCS+. |
| **SoD** | Separation of Duties. Nadie ejecuta de punta a punta una operación crítica. |
| **SPI** | Service Provider Interface de KC. Extensión via JARs en `/opt/keycloak/providers/`. |
| **Step-up** | RFC 9470. El recurso requiere LoA superior sin interrumpir la sesión. |
| **UserTemplate** | Contrato de un usuario concreto: credenciales, rol asignado, datos personales. |
| **Zone Application Map** | Archivo YAML que resuelve zona de negocio → aplicaciones del ecosistema. |

---

## 22. Registro de Cambios v5.0

### v5.0 — Abril 2026

#### Correcciones Críticas (J1–J11) — integradas desde `SBOS-PLAN-ACTUALIZACION-CONSOLIDADO-v3_0.md`

| ID | Corrección | Estado |
|---|---|---|
| **J1** | Jurisdicción regional (BO/AR/MX) eliminada del RolTemplate y SAM-128. Movida exclusivamente a `deploy.yml`. | ✅ CORREGIDO |
| **J2** | Bits `GOV_NORMATIVE_BO/AR/MX` eliminados del SAM-128. El SAM es vector de autorización, no de cumplimiento regional. | ✅ CORREGIDO |
| **J3** | Fase 4 del plan (reorganización Q4 para bits jurisdiccionales) cancelada. Ahorro de 2 semanas. | ✅ CANCELADO |
| **J4–J5** | Propósitos de `Authentication_Framework.json` y `Policies_Authentication_Framework.json` clarificados. | ✅ CLARIFICADO |
| **J6** | Longitud mínima de contraseña: 15 chars (factor único) y 8 chars (con MFA), conforme NIST SP 800-63B-4 Final (31 jul 2025). | ✅ CORREGIDO |
| **J7** | Rotación periódica de contraseñas: **SHALL NOT** (prohibida). Solo cambiar ante compromiso detectado. | ✅ CORREGIDO |
| **J8** | SMS OTP renombrado como "Restricted Authenticator" (terminología exacta NIST SP 800-63B-4 §5.2.10). | ✅ CORREGIDO |
| **J9** | Passkeys = AAL2 válido desde NIST SP 800-63B-4 Apéndice B (jul 2025). KC 26.4.0 production-ready (sep 2025). **Versión canónica SBOS fijada en KC 26.6.1** (abr 2026). | ✅ CONFIRMADO Y CERRADO |
| **J10** | `email_otp` prohibido como único segundo factor cuando la contraseña es el primer factor. | ✅ CONFIRMADO |
| **J11** | `deploy.yml` creado como nuevo artefacto — único lugar de configuración regional. | ✅ NUEVO |

#### Nuevas Integraciones KC (K1–K7) — integradas desde Plan Consolidado v3.0

| ID | Integración | Estado |
|---|---|---|
| **K1** | Biometría multimodal avanzada → IdP externo (FaceTec, BioID) via OIDC/SAML broker KC. | ✅ NUEVO |
| **K2** | SMS OTP → BOS-SMS-SPI + Twilio/AWS SNS. | ✅ NUEVO |
| **K3** | Push Notification → BOS-Push-SPI + FCM/APNs. | ✅ NUEVO |
| **K4** | Quantum-resistant → `liboqs-java` en JVM KC (mediano plazo v1.5). FIPS 203/204/205 activos desde ago 2024. | ✅ NUEVO |
| **K5** | **Versión Keycloak canónica fijada: 26.6.1** (patch de seguridad sobre 26.6.0 — publicado ~14 abr 2026). Features productivos: passkeys, FAPI 2.0, DPoP, Workflows IGA, JWT Auth Grant (RFC 7523), zero-downtime patches, Federated Client Auth. **DECISIÓN CERRADA — requiere ADR para cambiar.** | ✅ CERRADO |
| **K6** | IoT/M2M → KC como Authorization Server + PKI externa (Vault). | ✅ NUEVO |
| **K7** | Behavioral biometrics → SPI `SkbosGuardAuthenticator` emite step-up cuando score < threshold. | ✅ NUEVO |

#### Correcciones SAM-128 — integradas desde `SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md`

- XOR eliminado para SoD → **Conflict Matrix** (evaluación en asignación, estándar ISACA/ISO 27001 A.5.3/NIST SP 800-53 AC-5)
- NAND eliminado para KillSwitch → **AND NOT** (`&^`) — NAND puede elevar a ALL_PERMISSIONS
- `bos_bitmask` 64-bit único eliminado → **BitmaskBundle** 3×uint64
- `VDIMask` → `PhysicalDomainMask` · `ERPMask` → `LogicalDomainMask`
- `FinancialDomainMask` agregada como tercer registro independiente

#### Versión Keycloak Canónica — DECISIÓN CERRADA (Abril 2026)

> **KC 26.6.1** es la versión canónica y definitiva del SBOS. Fijada en este documento.

| Versión | Fecha | Relevancia SBOS |
|---|---|---|
| KC 26.4.0 | Sep 2025 | Passkeys production-ready · FAPI 2.0 Final · DPoP (RFC 9449) · Recovery codes supported |
| KC 26.4.x | Oct 2025 – Mar 2026 | Parches de seguridad (CVE-2026-2092, CVE-2026-2575, CVE-2026-2733, CVE-2026-3047, etc.) |
| KC 26.6.0 | 8 Abr 2026 | JWT Auth Grant RFC 7523 (prod) · Workflows IGA · Zero-downtime patches · Federated Client Auth · Graceful HTTP Shutdown · CIMD experimental (MCP) · OpenJDK 25 support |
| **KC 26.6.1** | **~14 Abr 2026** | **Parche crítico: CVE-2026-4366 SSRF + CVE-2026-4633 user enumeration. VERSIÓN CANÓNICA SBOS.** |

**Features KC 26.6.1 que impactan directamente el SBOS:**
- **Workflows IGA** → automatiza ciclo de vida del realm (§14). Configurables en YAML.
- **Zero-downtime patch releases** → actualizaciones de parche sin interrumpir sesiones activas.
- **JWT Authorization Grant (RFC 7523) production** → token exchange para service accounts de bAuth.
- **Federated Client Auth** → elimina gestión de `client_secret` individual por cliente KC en bAuth.
- **Graceful HTTP Shutdown** → nodos KC se apagan sin error 502 para `bhnexus` (mejora §18).
- **CIMD experimental** → KC como authorization server para MCP 2025-11-25+.

**⚠️ Breaking changes KC 26.6.0 a verificar antes de deploy:**
- JavaScript-based policies requieren feature `Scripts` habilitado explícitamente.
- Client URIs deben usar HTTPS obligatoriamente.
- `MigrateTo26_6_0` modifica flujos browser custom — verificar SPIs bAuth post-migración.
- Issuer config para JWT Authorization Grant debe identificar provider unívocamente.

#### Actualizaciones de Nomenclatura PQC (FIPS publicados agosto 2024)

- `CRYSTALS-Kyber` → `ML-KEM` (FIPS 203)
- `CRYSTALS-Dilithium` → `ML-DSA` (FIPS 204)
- `SPHINCS+` → `SLH-DSA` (FIPS 205)
- `FALCON` → `FN-DSA` (FIPS 206, en progreso)

#### Nuevas Secciones en v5.0

- **§6:** Catálogo completo de 15 métodos de autenticación con status NIST SP 800-63B-4 Final.
- **§7:** Integración KC detallada: nativo vs SPIs vs externo + confirmación KC 26.6.
- **§19:** Requerimientos de infraestructura y escalado gradual (integra `SBOS-BAUTH-REQUERIMIENTOS-TECNICOS-v1_2`).

---

*SKULL · SBOS · SBOS-BAUTH-CONCEPTUALIZACION · v5.0 · Abril 2026*

*Reemplaza: v1.0, v2.0, v3.0, v4.0 · SBOS-008 §7 y §8 completos*

*Correcciones J1–J11 y K1–K7 incorporadas. SAM-128 corregido. 15 métodos documentados.*

*Integraciones: SBOS-PLAN-ACTUALIZACION-CONSOLIDADO-v3_0 · SBOS-BAUTH-REQUERIMIENTOS-TECNICOS-v1_2 · SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO · SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION*

*🔒 **Versión Keycloak canónica: 26.6.1 — DECISIÓN CERRADA** (CVE-2026-4366 + CVE-2026-4633 corregidos)*

*Estándares: NIST SP 800-63B-4 (jul 2025) · NIST SP 800-63-4 (jul 2025) · FIPS 203/204/205 (ago 2024) · ISO/IEC 27001:2022 · ANSI/INCITS 359-2004 H-RBAC · PCI-DSS v4.0 · NIST SP 800-53 AC-5 · FIDO2/WebAuthn W3C · eIDAS · RGPD Art.9 · SOX §404 · SIA OSDP v2.2.2 · RFC 6749 OAuth2 · RFC 7523 JWT Auth Grant · RFC 9449 DPoP · RFC 9470 Step-Up · RFC 8176 AMR · IEEE 802.1X-2020 · OASIS XACML 3.0*
