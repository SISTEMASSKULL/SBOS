# A.65.03.01.18 — Informe de Completitud: D99 Administración Global

**Versión:** 1.0.0 · **Fecha:** 2026-07-28
**Tipo:** Informe de completitud de dominio
**SSOT bloques:** `bauth.idn_roles_template` — VPS SBOSDB (path `skull.D99.*`)
**Estado de D99:** ❌ SIN IMPLEMENTAR — 0/7 bloques con tablas propias · 6 tablas propuestas (T-510..T-515)

> **Propósito de D99:** Dominio transversal de administración global de bAuth — parámetros criptográficos del ecosistema, cumplimiento regulatorio cross-dominio, excepciones HITL, notificaciones del sistema, cadena de suministro de software (SBOM) y gestión de usuarios globales del sistema. D99 es el "panel de control" del operador soberano.
> **T-code range:** T-510..T-519

---

## 1. Estado global de D99

**Dominio:** Administración Global (Cross-domain admin · Crypto params · SBOM · Excepciones HITL)
**Total bloques:** 7 | **Tablas propias:** 0 | **Átomos:** 0

| Bloque | Slug | Nombre | Estado | T-code propuesto |
|--------|------|--------|--------|-----------------|
| B01 | `users` | Usuarios Globales del Sistema | ❌ FALTANTE | T-510 |
| B02 | `notifications` | Notificaciones Globales del Sistema | ❌ FALTANTE | T-511 |
| B03 | `exceptions` | Excepciones con Supervisión Humana (HITL) | ❌ FALTANTE | T-512 |
| B04 | `cryptography` | Parámetros Criptográficos Globales | ❌ FALTANTE | T-513 |
| B05 | `compliance` | Mapa de Cumplimiento Regulatorio | ❌ FALTANTE | T-514 |
| B06 | `supply_chain` | Cadena de Suministro de Software (SBOM) | ❌ FALTANTE | T-515 |
| B07 | `business_zone` | Registro de Zona de Negocio (Admin Global) | árbol ✅ | — |

---

## 2. Análisis de bloques

### B01 — `users` · Usuarios Globales del Sistema

**Normas:** NIST SP 800-53 R5 AC-2 · ISO 27001 A.5.16

**Propósito:** Registro de los actores con privilegios de administración global de bAuth (operadores del sistema soberano SKULL, administradores de tenant). Diferente de `idn_identity_entity` (que registra a todos los usuarios) — este es el catálogo de administradores del sistema con su nivel de acceso global.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_global_admin (
    admin_id        UUID PRIMARY KEY DEFAULT uuidv7(),
    entity_id      UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE CASCADE,
    tenant_id       UUID NULL REFERENCES bauth.idn_tenant(tenant_id),  -- NULL = admin global
    nivel           TEXT NOT NULL DEFAULT 'TENANT_ADMIN'
        CONSTRAINT chk_idga_nivel CHECK (nivel IN
            ('SISTEMA_OPERADOR','PLATAFORMA_ADMIN','TENANT_ADMIN','SOPORTE_L1','SOPORTE_L2','SOPORTE_L3')),
    scope_tenants   UUID[] NOT NULL DEFAULT '{}',  -- tenants que puede administrar (vacío = todos)
    requiere_mfa    BOOLEAN NOT NULL DEFAULT TRUE,
    loa_minima      TEXT NOT NULL DEFAULT 'AAL3'
        CONSTRAINT chk_idga_loa CHECK (loa_minima IN ('AAL2','AAL3')),
    estado          TEXT NOT NULL DEFAULT 'ACTIVO'
        CONSTRAINT chk_idga_est CHECK (estado IN ('ACTIVO','SUSPENDIDO','REVOCADO')),
    asignado_por    UUID NULL REFERENCES bauth.idn_identity_entity(entity_id),
    valid_from      TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until     TIMESTAMPTZ NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (entity_id, nivel, tenant_id)
);
COMMENT ON TABLE bauth.idn_global_admin IS
  '[T-510] [D99-B01] [NIST SP 800-53 R5 AC-2] [ISO 27001 A.5.16]
   Administradores globales de bAuth con nivel de privilegio y scope de tenants.
   Todos los adminsitradores requieren AAL3 mínimo.';
```

### B02 — `notifications` · Notificaciones Globales del Sistema

**Normas:** NIST SP 800-53 R5 SI-12 · ISO 27001 A.5.2

**Propósito:** Canal de notificaciones del sistema para operadores (distintas a las notificaciones de usuario de bNotify). Cuando bAuth detecta un evento crítico (expiración de cert raíz, umbral de disk, fallo de Besu), envía notificaciones a este canal para que los operadores actúen.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_global_notificacion (
    notif_id        UUID PRIMARY KEY DEFAULT uuidv7(),
    tipo            TEXT NOT NULL CONSTRAINT chk_idgn_tipo CHECK (tipo IN (
        'CERT_EXPIRY','CRIT_THRESHOLD','BESU_FALLO','VAULT_FALLO','ROTACION_REQUERIDA',
        'AUDITORIA_VENCE','COMPLIANCE_VIOL','SISTEMA_ALERTA','SCHEDULED_MAINT')),
    severidad       TEXT NOT NULL CONSTRAINT chk_idgn_sev CHECK (severidad IN ('INFO','WARN','ERROR','CRITICO')),
    titulo          TEXT NOT NULL,
    cuerpo          TEXT NOT NULL,
    destinatarios   UUID[] NOT NULL,         -- admin_ids a notificar
    canal           TEXT NOT NULL DEFAULT 'SISTEMA'
        CONSTRAINT chk_idgn_canal CHECK (canal IN ('SISTEMA','EMAIL','PUSH','SIEM','WEBHOOK')),
    estado          TEXT NOT NULL DEFAULT 'PENDIENTE'
        CONSTRAINT chk_idgn_est CHECK (estado IN ('PENDIENTE','ENVIADO','LEIDO','ARCHIVADO')),
    accionado_por   UUID NULL REFERENCES bauth.idn_identity_entity(entity_id),
    accionado_at    TIMESTAMPTZ NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    creado_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_global_notificacion IS
  '[T-511] [D99-B02] [NIST SP 800-53 R5 SI-12] [ISO 27001 A.5.2]
   Notificaciones del sistema para operadores de bAuth. Eventos críticos que requieren acción humana.';
```

### B03 — `exceptions` · Excepciones con Supervisión Humana (HITL)

**Normas:** NIST AI RMF 1.0 §3.6 · ISO 27001 A.5.29 · SBOS-HITL-001

**Propósito:** Excepciones que requieren decisión humana (Human-In-The-Loop). Cuando el PDP no puede resolver una decisión automáticamente (ambigüedad de política, caso no contemplado, riesgo extremo), eleva a HITL. El operador decide y el sistema registra la decisión para aprendizaje.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_global_hitl_excepcion (
    excepcion_id    UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NULL REFERENCES bauth.idn_tenant(tenant_id),
    tipo            TEXT NOT NULL CONSTRAINT chk_idghe_tipo CHECK (tipo IN (
        'DECISION_PDP','POLITICA_AMBIGUA','CASO_BORDE','RIESGO_EXTREMO',
        'CONFLICTO_SOD','BRECHA_COMPLIANCE','ALERTA_IA','EMERGENCIA')),
    descripcion     TEXT NOT NULL,
    datos_contexto  JSONB NOT NULL,          -- contexto técnico completo para el operador
    actor_afectado  UUID NULL REFERENCES bauth.idn_identity_entity(entity_id),
    decision_propuesta TEXT NULL,            -- lo que el sistema habría decidido sin HITL
    -- HITL
    asignado_a      UUID NULL REFERENCES bauth.idn_global_admin(admin_id),
    decision_hitl   TEXT NULL CONSTRAINT chk_idghe_dec CHECK (decision_hitl IS NULL OR decision_hitl IN
        ('APROBAR','DENEGAR','ESCALAR','DIFERIR','POLITICA_NUEVA')),
    justificacion_hitl TEXT NULL,
    decidido_at     TIMESTAMPTZ NULL,
    -- Estado y urgencia
    estado          TEXT NOT NULL DEFAULT 'PENDIENTE'
        CONSTRAINT chk_idghe_est CHECK (estado IN ('PENDIENTE','EN_REVISION','DECIDIDO','EXPIRADO','CANCELADO')),
    urgencia        TEXT NOT NULL DEFAULT 'MEDIA'
        CONSTRAINT chk_idghe_urg CHECK (urgencia IN ('BAJA','MEDIA','ALTA','CRITICA')),
    expira_at       TIMESTAMPTZ NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    creado_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_global_hitl_excepcion IS
  '[T-512] [D99-B03] [NIST AI RMF 1.0 §3.6] [ISO 27001 A.5.29]
   Excepciones que requieren decisión humana (HITL). El PDP las eleva cuando no puede decidir solo.
   Base para el aprendizaje continuo de políticas.';
```

### B04 — `cryptography` · Parámetros Criptográficos Globales

**Normas:** NIST SP 800-131A R2 §3 · ISO 27001 A.8.24 · NIST SP 800-57 Pt1 R5

**Propósito:** Catálogo de algoritmos criptográficos aprobados para uso en bAuth. Cuando se agrega un algoritmo nuevo o se depreca uno existente (ej.: migración de RSA-2048 a RSA-4096), esta tabla es la fuente de verdad. Todos los módulos de bAuth consultan aquí antes de usar un algoritmo.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_global_crypto_params (
    param_id        UUID PRIMARY KEY DEFAULT uuidv7(),
    algoritmo       TEXT NOT NULL,           -- ej: 'RSA-4096', 'ECDSA-P384', 'Ed25519', 'AES-256-GCM'
    familia         TEXT NOT NULL CONSTRAINT chk_idgcp_fam CHECK (familia IN
        ('FIRMA_ASIMETRICA','CIFRADO_SIMETRICO','HASH','KDF','MAC','ACUERDO_CLAVE','ECDH')),
    nivel_seguridad_bits INTEGER NOT NULL,   -- bits de seguridad (ej: 128, 192, 256)
    estado          TEXT NOT NULL DEFAULT 'APROBADO'
        CONSTRAINT chk_idgcp_est CHECK (estado IN ('PROPUESTO','APROBADO','DEPRECADO','PROHIBIDO')),
    nist_ref        TEXT NULL,               -- ej: 'NIST SP 800-131A R2 §3 Table 1'
    iso_ref         TEXT NULL,
    -- Vigencia
    aprobado_desde  DATE NOT NULL,
    prohibido_desde DATE NULL,               -- fecha en que se prohíbe (NULL = sin fecha)
    -- Uso
    casos_uso_permitidos TEXT[] NOT NULL DEFAULT '{}',  -- FIRMA_JWT, CIFRADO_DB, TLS, VAULT, etc.
    casos_uso_prohibidos TEXT[] NOT NULL DEFAULT '{}',
    nota            TEXT NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (algoritmo, estado)
);
COMMENT ON TABLE bauth.idn_global_crypto_params IS
  '[T-513] [D99-B04] [NIST SP 800-131A R2 §3] [ISO 27001 A.8.24]
   Catálogo de algoritmos criptográficos aprobados/prohibidos para bAuth.
   Todos los módulos consultan aquí antes de seleccionar un algoritmo.';
```

### B05 — `compliance` · Mapa de Cumplimiento Regulatorio

**Normas:** ISO 19600:2014 §6 · NIST SP 800-53 R5 CA-2

**Propósito:** Mapa de qué controles normativos cubre bAuth y cuál es su estado de implementación. Permite generar informes de cumplimiento automáticos para auditores ISO 27001, PCI DSS, GDPR, SOX, etc.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_global_compliance_control (
    control_id      UUID PRIMARY KEY DEFAULT uuidv7(),
    marco           TEXT NOT NULL CONSTRAINT chk_idgcc_marco CHECK (marco IN (
        'ISO_27001_2022','NIST_SP_800_53','PCI_DSS_4','GDPR','SOX','NIST_800_63B',
        'LEY_164_BO','LEY_1174_BO','OWASP_ASVS_5','FIPS_140_3')),
    control_id_ref  TEXT NOT NULL,           -- ej: 'A.9.4.1', 'AC-3(7)', 'Req 7.2.1'
    titulo          TEXT NOT NULL,
    descripcion     TEXT NOT NULL,
    -- Implementación en bAuth
    dominio_bauth   TEXT NULL,               -- D01, D02, etc.
    tabla_ref       TEXT NULL,               -- tabla que implementa el control
    metodo_ref      TEXT NULL,               -- método RPC que implementa el control
    estado          TEXT NOT NULL DEFAULT 'NO_IMPLEMENTADO'
        CONSTRAINT chk_idgcc_est CHECK (estado IN (
            'NO_IMPLEMENTADO','PARCIAL','IMPLEMENTADO','AUDITADO','EXENTO')),
    nivel_madurez   TEXT NULL CONSTRAINT chk_idgcc_mad CHECK (nivel_madurez IS NULL OR nivel_madurez IN
        ('L0','L1','L2','L3','L4')),
    evidencia       TEXT NULL,               -- referencia a evidencia de implementación
    ultima_auditoria DATE NULL,
    proxima_revision DATE NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (marco, control_id_ref)
);
COMMENT ON TABLE bauth.idn_global_compliance_control IS
  '[T-514] [D99-B05] [ISO 19600:2014 §6] [NIST SP 800-53 R5 CA-2]
   Mapa de cumplimiento regulatorio — qué controles implementa bAuth y con qué madurez.
   Base para informes de auditoría automáticos.';
```

### B06 — `supply_chain` · Cadena de Suministro de Software (SBOM)

**Normas:** NTIA SBOM 2021 · NIST SP 800-53 R5 SA-12 · EO 14028 (US)

**Propósito:** SBOM (Software Bill of Materials) de bAuth — registro de todas las dependencias del binario (crates Rust) con versión, licencia y estado de vulnerabilidades. Actualizado en cada build CI/CD.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_global_sbom (
    sbom_id         UUID PRIMARY KEY DEFAULT uuidv7(),
    -- Versión del binario bAuth
    version_bauth   TEXT NOT NULL,           -- ej: '3.0.0'
    build_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    build_hash      TEXT NOT NULL,           -- SHA-256 del binario
    rust_version    TEXT NOT NULL,           -- ej: '1.85.0'
    -- SBOM
    formato         TEXT NOT NULL DEFAULT 'SPDX_2_3'
        CONSTRAINT chk_idgs_fmt CHECK (formato IN ('SPDX_2_3','CYCLONEDX_1_5','CUSTOM')),
    total_deps      INTEGER NOT NULL,
    deps_con_cve    INTEGER NOT NULL DEFAULT 0,
    deps_licencia_no_ok INTEGER NOT NULL DEFAULT 0,
    sbom_hash       TEXT NOT NULL,           -- SHA-256 del SBOM completo
    vault_path      TEXT NOT NULL,           -- SBOM completo en Vault (puede ser grande)
    estado          TEXT NOT NULL DEFAULT 'VERIFICADO'
        CONSTRAINT chk_idgs_est CHECK (estado IN ('PENDIENTE','VERIFICADO','CON_ALERTAS','BLOQUEADO')),
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    UNIQUE (version_bauth, build_at)
);
COMMENT ON TABLE bauth.idn_global_sbom IS
  '[T-515] [D99-B06] [NTIA SBOM 2021] [NIST SP 800-53 R5 SA-12]
   SBOM de bAuth por versión de build. SBOM completo en Vault; resumen + hash aquí.
   deps_con_cve > 0 dispara alerta CRITICA a D99.notifications.';
```

---

## 3. Checklist de completitud

- [ ] `idn_global_admin` (T-510) ❌ PENDIENTE
- [ ] `idn_global_notificacion` (T-511) ❌ PENDIENTE
- [ ] `idn_global_hitl_excepcion` (T-512) ❌ PENDIENTE
- [ ] `idn_global_crypto_params` (T-513) ❌ PENDIENTE
- [ ] `idn_global_compliance_control` (T-514) ❌ PENDIENTE
- [ ] `idn_global_sbom` (T-515) ❌ PENDIENTE
- [ ] Seeds T-513: algoritmos criptográficos NIST SP 800-131A R2 aprobados (Ed25519, ECDSA-P384, AES-256-GCM, Argon2id, SHA-256, SHA-384)
- [ ] Seeds T-513: algoritmos prohibidos (MD5, SHA-1, RSA-1024, DES, 3DES)
- [ ] Seeds T-514: mapa completo ISO 27001:2022 + NIST SP 800-53 + GDPR (principales controles)
- [ ] Seeds T-510: actor BAUTH_SYSTEM como admin global (nivel=SISTEMA_OPERADOR)
- [ ] Trigger: al crear `idn_global_notificacion` con `severidad=CRITICO`, auto-crear entrada en `idn_global_hitl_excepcion` si no existe
- [ ] Job: chequear SBOM pendiente de verificación (cada build CI/CD)
- [ ] Átomos D99: `skull.D99.{users,notifications,exceptions,cryptography,compliance,supply_chain}.*`

---

## 4. Análisis IAM Enterprise — D99

### 4.1 Cobertura de pilares

| Pilar IAM Enterprise | Criterio D99 | Estado |
|---|---|:---:|
| **VI Standards** | Mapa de cumplimiento cross-framework | ❌ L0 |
| **VI Standards** | Parámetros criptográficos NIST 800-131A | ❌ L0 |
| **VII Advanced** | HITL para decisiones PDP ambiguas | ❌ L0 |
| **VII Advanced** | SBOM (EO 14028 / NTIA) | ❌ L0 |
| **II IGA** | Administradores globales con scope | ❌ L0 |

### 4.2 Gaps IAM Enterprise D99

| Gap | Prioridad | Acción |
|-----|-----------|--------|
| GAP-D99-01 — Admins globales sin tabla | 🔴 P1 | CREATE T-510 + seed BAUTH_SYSTEM |
| GAP-D99-02 — Crypto params sin catálogo | 🔴 P1 | CREATE T-513 + seeds NIST |
| GAP-D99-03 — HITL sin tabla | 🟠 P2 | CREATE T-512 |
| GAP-D99-04 — Mapa compliance sin datos | 🟠 P2 | CREATE T-514 + seeds ISO/NIST/GDPR |
| GAP-D99-05 — SBOM sin registro | 🟠 P2 | CREATE T-515 + integración CI/CD |
| GAP-D99-06 — Átomos D99 | 🟡 P3 | INSERT ~25 átomos |

### 4.3 Veredicto IAM Enterprise

**D99 L0 global** — el dominio de administración soberana no tiene implementación. GAP-D99-01 (admins globales) y GAP-D99-02 (crypto params) son los más críticos: sin T-513, no hay garantía de que todos los módulos de bAuth usen algoritmos aprobados; sin T-510, no hay control formal de quién administra el sistema.

---

## 5. Vista consolidada de los 18 dominios

| Dominio | Nombre | Bloques | Tablas OK | Estado |
|---------|--------|---------|-----------|--------|
| D00 | Identidad Organizacional | 9 | 12 | ✅ 100% L3 |
| D01 | Control de Acceso Lógico | 9 | 14 | ⚠️ L2-L3 (B04, B05 faltan) |
| D02 | Control de Acceso Físico | 8 | 0 | ❌ L0 |
| D03 | Controles Financieros | 9 | 0 | ❌ L0 |
| D04 | Acceso Temporal | 6 | 0 | ❌ L0 |
| D05 | Autenticación Biométrica | 7 | 0 | ❌ L0 |
| D06 | Acceso Geoespacial | 6 | 0 | ❌ L0 |
| D07 | Seguridad de Red | 8 | 0 | ❌ L0 |
| D08 | Contexto y Sesión | 7 | 5 | ⚠️ L2-L3 (B04, B06 faltan) |
| D09 | Gestión de Credenciales | 10 | 0 | ❌ L0 |
| D10 | Delegación e Impersonación | 7 | 0 | ❌ L0 |
| D11 | Auditoría y Cumplimiento | 7 | 2 | ⚠️ L2 (IGA L3, SIEM L0) |
| D12 | Anclaje Blockchain | 7 | 0 (T-169 parcial) | ❌ L0-L1 |
| D13 | Firma Digital Externa | 8 | 0 | ❌ L0 |
| D14 | PAM | 7 | 6 | ⚠️ L2-L3 (JIT L3, inventario L0) |
| D15 | Identidad No Humana | 8 | 4 | ⚠️ L2-L3 (NHI más maduro) |
| D98 | Registro Estructural | 4 | 0 | ❌ L0 |
| D99 | Administración Global | 7 | 0 | ❌ L0 |

**Núcleo operativo (L2-L3):** D00, D01, D08, D11, D14, D15 — 6/18 dominios con implementación parcial-alta.
**Trabajo pendiente:** D02-D07, D09-D10, D12-D13, D98-D99 — 12/18 dominios en L0.

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-28 | Versión inicial. 0/7 bloques con tablas propias. DDL propuesto T-510..T-515. 6 gaps. Madurez D99: L0. Vista consolidada de los 18 dominios. |
