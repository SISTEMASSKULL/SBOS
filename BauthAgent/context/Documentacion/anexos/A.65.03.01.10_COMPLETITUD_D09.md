# A.65.03.01.10 — Informe de Completitud: D09 Gestión de Credenciales

**Versión:** 1.2.0 · **Fecha:** 2026-07-31
**Tipo:** Informe de completitud de dominio
**SSOT bloques:** `bauth.idn_roles_template` — VPS SBOSDB (path `skull.D09.*`)
**Estado de D09:** ⚠️ PARCIAL — 7/10 bloques satisfechos · B05 (T-364) + B09 (T-368) implementados · 3 bloques pendientes (B01, B04, B06)

> **Actualización v1.2.0:** T-364 `idn_credencial_revocacion` (B05) y T-368 `idn_credencial_introspeccion` (B09) implementados en VPS. 25 tablas auth_* totales.

---

## 1. Estado global de D09

**Dominio:** Gestión de Credenciales (18 métodos de autenticación · revocación < 30s · X.509 · FIDO2)
**Total bloques:** 10 | **Tablas VPS:** 23 (S14 + S18 + catálogos) | **Átomos:** 0

| Bloque | Slug | Nombre | Estado | Tablas que lo satisfacen |
|--------|------|--------|--------|--------------------------|
| B01 | `password` | Política de Contraseña | ⚠️ PARCIAL | `idn_identity_requirement` (T-159, D00) + `auth_credential_secret` (T-331, Argon2id) |
| B02 | `mfa` | Autenticación Multi-Factor | ✅ SATISFECHO | `auth_credential` (T-330) + `auth_credential_secret` (T-331, TOTP/HOTP) + `auth_credential_fido2` (T-332) |
| B03 | `certificates` | Certificados X.509 | ✅ SATISFECHO | `auth_credential_x509` (T-333) — Vault PKI + ADSIB + Enterprise PKI |
| B04 | `tokens` | Tokens de Acceso | ⚠️ PARCIAL | `fed_token_issued` (T-367, S16) — falta gestión de ciclo de vida |
| B05 | `revocation` | Revocación de Credencial | ✅ SATISFECHO | `idn_credencial_revocacion` (T-364) — catálogo persistente + `ses_caep_event_log` (T-191) |
| B06 | `recovery` | Recuperación de Cuenta | ⚠️ PARCIAL | `idn_user_recovery` (T-322, S13) — métodos de recuperación |
| B07 | `binding` | Vinculación de Autenticador | ✅ SATISFECHO | `auth_device_credential_binding` (T-392, WORM) + `auth_credential` (T-330) |
| B08 | `passkey` | Claves de Acceso FIDO2 | ✅ SATISFECHO | `auth_credential_fido2` (T-332) — WebAuthn L3 + discoverable credentials |
| B09 | `introspection` | Introspección de Token | ✅ SATISFECHO | `idn_credencial_introspeccion` (T-368) — log RFC 7662 |
| B10 | `business_zone` | Registro de Zona de Negocio | árbol ✅ | `idn_roles_template` (T-162) |

---

## 2. Análisis de bloques

### B01 — `password` · Política de Contraseña (⚠️ PARCIAL)

**Normas:** NIST SP 800-63B-4 §5.1.1 · OWASP ASVS v5 §2.1 · OWASP Top 10 A02

**Cobertura actual:** `idn_identity_requirement` (T-159, D00) almacena políticas de IAL — incluye `method_type = 'PASSWORD'` con parámetros como `min_length`, `argon2_memory`, `argon2_iterations`. Sin embargo, falta: historial de contraseñas, screening contra listas HaveIBeenPwned, contador de intentos fallidos.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_credencial_password_history (
    history_id      UUID PRIMARY KEY DEFAULT uuidv7(),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE CASCADE,
    hash_argon2     TEXT NOT NULL,           -- hash Argon2id de la contraseña anterior
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT NOT NULL DEFAULT 'system'
);
CREATE INDEX IF NOT EXISTS idx_icph_actor ON bauth.idn_credencial_password_history(actor_id, changed_at DESC);
COMMENT ON TABLE bauth.idn_credencial_password_history IS
  '[T-360] [D09-B01] [NIST SP 800-63B-4 §5.1.1.2] [OWASP ASVS v5 §2.1.7]
   Historial de contraseñas hasheadas para prevenir reutilización (NIST: no reutilizar últimas N).';
```

### B02 — `mfa` · Autenticación Multi-Factor

**Normas:** NIST SP 800-63B-4 §5.1 · ISO 27001 A.8.5

**Propósito:** Registro de factores MFA enrolados por actor (TOTP, HOTP, WebAuthn, Email OTP, etc.). Diferente de `idn_biometrico_*` (D05) — este es el inventario de todos los factores no-biométricos.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_credencial_mfa_factor (
    factor_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE CASCADE,
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    tipo_factor     TEXT NOT NULL CONSTRAINT chk_idcmf_tipo CHECK (tipo_factor IN (
        'TOTP','HOTP','EMAIL_OTP','SMS_OTP','WEBAUTHN_2FA','WEBAUTHN_PASSKEY',
        'BACKUP_CODE','PUSH_NOTIFY','HARDWARE_KEY','MAGIC_LINK')),
    -- Para TOTP/HOTP: referencia al secreto en Vault
    vault_path      TEXT NULL,
    -- Para WebAuthn: credential_id
    webauthn_credential_id TEXT NULL,
    -- Para EMAIL/SMS: enmascarado del destino
    destino_enmascarado TEXT NULL,
    -- Estado y uso
    es_primario     BOOLEAN NOT NULL DEFAULT FALSE,
    estado          TEXT NOT NULL DEFAULT 'ACTIVO'
        CONSTRAINT chk_idcmf_est CHECK (estado IN ('PENDIENTE','ACTIVO','SUSPENDIDO','REVOCADO')),
    ultimo_uso_at   TIMESTAMPTZ NULL,
    uso_count       INTEGER NOT NULL DEFAULT 0,
    enrolado_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    UNIQUE (actor_id, tipo_factor, estado)
);
COMMENT ON TABLE bauth.idn_credencial_mfa_factor IS
  '[T-361] [D09-B02] [NIST SP 800-63B-4 §5.1] [ISO 27001 A.8.5]
   Inventario de factores MFA enrolados por actor. Secretos en Vault; solo metadatos aquí.';
```

### B03 — `certificates` · Certificados X.509

**Normas:** RFC 5280 §4 · NIST SP 800-57 Pt1 R5

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_credencial_certificado (
    cert_id         UUID PRIMARY KEY DEFAULT uuidv7(),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    tipo            TEXT NOT NULL CONSTRAINT chk_idcc_tipo CHECK (tipo IN
        ('CLIENTE_MTLS','FIRMA_PERSONAL','ENCRIPTACION','CA_RAIZ','CA_INTERMEDIA','ADSIB')),
    serial_number   TEXT NOT NULL,
    subject_dn      TEXT NOT NULL,
    issuer_dn       TEXT NOT NULL,
    fingerprint_sha256 TEXT NOT NULL,
    valid_from      TIMESTAMPTZ NOT NULL,
    valid_until     TIMESTAMPTZ NOT NULL,
    -- Referencia al cert en Vault (no el PEM en BD)
    vault_path      TEXT NOT NULL,
    estado          TEXT NOT NULL DEFAULT 'ACTIVO'
        CONSTRAINT chk_idcc_est CHECK (estado IN ('ACTIVO','EXPIRADO','REVOCADO','SUSPENDIDO')),
    ocsp_status     TEXT NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (serial_number, issuer_dn)
);
COMMENT ON TABLE bauth.idn_credencial_certificado IS
  '[T-362] [D09-B03] [RFC 5280 §4] [NIST SP 800-57 Pt1 R5]
   Metadatos de certificados X.509. El PEM vive en Vault; aquí solo serial, DN y fingerprint.';
```

### B04 — `tokens` · Tokens de Acceso

**Normas:** RFC 7519 JWT §4 · OAuth 2.0 RFC 6749 §5 · RFC 9449 DPoP

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_credencial_token_emitido (
    token_id        UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    session_id      UUID NULL REFERENCES bauth.ses_session_log(session_id),
    tipo            TEXT NOT NULL CONSTRAINT chk_idcte_tipo CHECK (tipo IN
        ('ACCESS_TOKEN','REFRESH_TOKEN','ID_TOKEN','DEVICE_TOKEN','TOKEN_EXCHANGE')),
    jti             TEXT NOT NULL,           -- JWT ID — único
    audience        TEXT[] NOT NULL,
    scope           TEXT[] NOT NULL,
    dpop_jkt        TEXT NULL,               -- binding DPoP si aplica
    issued_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ NOT NULL,
    revoked_at      TIMESTAMPTZ NULL,
    revocation_reason TEXT NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    UNIQUE (jti)
);
COMMENT ON TABLE bauth.idn_credencial_token_emitido IS
  '[T-363] [D09-B04] [RFC 7519 JWT §4] [RFC 9449 DPoP] [OAuth 2.0 RFC 6749]
   Registro de tokens emitidos para introspección, revocación y auditoría.';
```

### B05 — `revocation` · Revocación de Credencial (< 30 s)

**Normas:** NIST SP 800-63B-4 §5.2.6 · ISO 27001 A.5.17 · CAEP RFC 8935

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_credencial_revocacion (
    revocacion_id   UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    tipo_credencial TEXT NOT NULL CONSTRAINT chk_idcr_tipo CHECK (tipo_credencial IN
        ('PASSWORD','MFA_FACTOR','CERTIFICADO','TOKEN','PASSKEY','SESION_ACTIVA','TODOS')),
    credencial_ref  UUID NULL,               -- factor_id, cert_id, token_id, session_id
    motivo          TEXT NOT NULL CONSTRAINT chk_idcr_mot CHECK (motivo IN (
        'COMPROMISO','CAMBIO_VOLUNTARIO','POLITICA_EXPIRACION','ADMIN','CAEP_EVENT',
        'OFBOARDING','SOSPECHA','RECUPERACION')),
    revocado_por    UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    caep_emitido    BOOLEAN NOT NULL DEFAULT FALSE,
    caep_event_id   UUID NULL REFERENCES bauth.ses_caep_event_log(id),
    propagado_redis BOOLEAN NOT NULL DEFAULT FALSE,     -- propagación a cache Redis < 30s
    revocado_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT NOT NULL DEFAULT 'system'
);
CREATE INDEX IF NOT EXISTS idx_idcrev_actor ON bauth.idn_credencial_revocacion(actor_id, revocado_at DESC);
COMMENT ON TABLE bauth.idn_credencial_revocacion IS
  '[T-364] [D09-B05] [NIST SP 800-63B-4 §5.2.6] [ISO 27001 A.5.17]
   Registro de revocaciones. propagado_redis=true confirma que Redis actualizó la BitmaskBundle < 30s.';
```

### B06 — `recovery` · Recuperación de Cuenta

**Normas:** NIST SP 800-63B-4 §6.1 · OWASP ASVS v5 §2.5

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_credencial_recuperacion (
    recuperacion_id UUID PRIMARY KEY DEFAULT uuidv7(),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    metodo          TEXT NOT NULL CONSTRAINT chk_idcrec_met CHECK (metodo IN
        ('EMAIL_LINK','BACKUP_CODE','ADMIN_RESET','SOPORTE_IDENTIDAD','MFA_ALTERNATIVO')),
    codigo_hash     TEXT NULL,               -- hash del código de recuperación (si aplica)
    estado          TEXT NOT NULL DEFAULT 'INICIADO'
        CONSTRAINT chk_idcrec_est CHECK (estado IN ('INICIADO','COMPLETADO','EXPIRADO','FALLIDO','CANCELADO')),
    intentos        INTEGER NOT NULL DEFAULT 0,
    ip_solicitud    INET NULL,
    iniciado_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    completado_at   TIMESTAMPTZ NULL,
    expira_at       TIMESTAMPTZ NOT NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system'
);
COMMENT ON TABLE bauth.idn_credencial_recuperacion IS
  '[T-365] [D09-B06] [NIST SP 800-63B-4 §6.1] [OWASP ASVS v5 §2.5]
   Flujo de recuperación de cuenta. Todas las recuperaciones son auditadas con método e IP.';
```

### B07 — `binding` · Vinculación de Autenticador

**Normas:** FIDO2 §6.1 · NIST SP 800-63B-4 §5.2.5

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_credencial_authenticator_binding (
    binding_id      UUID PRIMARY KEY DEFAULT uuidv7(),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    factor_id       UUID NOT NULL REFERENCES bauth.idn_credencial_mfa_factor(factor_id),
    tipo_binding    TEXT NOT NULL CONSTRAINT chk_idcab_tipo CHECK (tipo_binding IN
        ('DISPOSITIVO','SESION','USUARIO','GLOBAL')),
    attest_type     TEXT NULL,               -- FIDO2 attestation type (none, direct, indirect)
    attest_data     JSONB NULL,              -- datos de atestación FIDO2
    vinculado_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    ultimo_uso_at   TIMESTAMPTZ NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    UNIQUE (actor_id, factor_id)
);
COMMENT ON TABLE bauth.idn_credencial_authenticator_binding IS
  '[T-366] [D09-B07] [FIDO2 §6.1] [NIST SP 800-63B-4 §5.2.5]
   Vinculación de autenticadores con datos de atestación FIDO2.';
```

### B08 — `passkey` · Claves de Acceso FIDO2

**Normas:** W3C WebAuthn L3 §6.3 · NIST SP 800-63B-4 §5.2.2 · FIDO2 Passkey Spec

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_credencial_passkey (
    passkey_id      UUID PRIMARY KEY DEFAULT uuidv7(),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    credential_id   TEXT NOT NULL,           -- WebAuthn credential ID (base64url)
    public_key      TEXT NOT NULL,           -- COSE public key (base64url)
    rp_id           TEXT NOT NULL,           -- Relying Party ID
    aaguid          TEXT NULL,               -- Authenticator AAGUID
    sign_count      BIGINT NOT NULL DEFAULT 0,
    transports      TEXT[] NULL,             -- ['usb','nfc','ble','internal']
    uvinitialized   BOOLEAN NOT NULL DEFAULT FALSE,  -- user verification
    backup_eligible BOOLEAN NOT NULL DEFAULT FALSE,
    backup_state    BOOLEAN NOT NULL DEFAULT FALSE,
    nombre          TEXT NULL,               -- nombre amigable dado por el usuario
    estado          TEXT NOT NULL DEFAULT 'ACTIVO'
        CONSTRAINT chk_idcp_est CHECK (estado IN ('ACTIVO','REVOCADO','EXPIRADO')),
    registrado_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    ultimo_uso_at   TIMESTAMPTZ NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    UNIQUE (actor_id, credential_id)
);
COMMENT ON TABLE bauth.idn_credencial_passkey IS
  '[T-367] [D09-B08] [W3C WebAuthn L3 §6.3] [NIST SP 800-63B-4 §5.2.2]
   Passkeys FIDO2 — credenciales sin contraseña sincronizables.';
```

### B09 — `introspection` · Introspección de Token

**Normas:** RFC 7662 §2 · OAuth 2.0 RFC 6749 §7

La introspección se implementa en el motor de bAuth (Rust) consultando `idn_credencial_token_emitido` (T-363). No requiere tabla adicional — es un método JSON-RPC `bauth.token.introspect` que lee T-363.

---

## 3. Checklist de completitud

- [ ] `idn_credencial_password_history` (T-360) ❌ PENDIENTE
- [ ] `idn_credencial_mfa_factor` (T-361) ❌ PENDIENTE
- [ ] `idn_credencial_certificado` (T-362) ❌ PENDIENTE
- [ ] `idn_credencial_token_emitido` (T-363) ❌ PENDIENTE
- [ ] `idn_credencial_revocacion` (T-364) ❌ PENDIENTE
- [ ] `idn_credencial_recuperacion` (T-365) ❌ PENDIENTE
- [ ] `idn_credencial_authenticator_binding` (T-366) ❌ PENDIENTE
- [ ] `idn_credencial_passkey` (T-367) ❌ PENDIENTE
- [ ] Trigger: al revocar → `propagado_redis=true` cuando Redis confirme purga (< 30s objetivo)
- [ ] Job: expirar recuperaciones no completadas vencidas
- [ ] Job: alertar certificados a vencer en 30 días
- [ ] Seeds: factores MFA deshabilitados por defecto (SMS_OTP deprecado per ADR)
- [ ] Átomos D09: `skull.D09.{password,mfa,certificates,tokens,revocation,recovery,binding,passkey,introspection}.*`

---

## 4. Análisis IAM Enterprise — D09

| Pilar IAM Enterprise | Criterio D09 | Estado |
|---|---|:---:|
| **I AuthEngine** | 18 métodos de autenticación | ⚠️ L2 (motor en Rust existe, tablas no) |
| **I AuthEngine** | Revocación < 30s | ❌ L0 |
| **I AuthEngine** | Passkeys FIDO2 | ❌ L0 |
| **IV Machine Identity** | mTLS via certificados X.509 | ❌ L0 |
| **VI Standards** | NIST 800-63B-4 / FIDO2 / RFC 7662 | ❌ L0 |

**Gaps críticos:**

| Gap | Prioridad | Acción |
|-----|-----------|--------|
| GAP-D09-01 — Inventario MFA sin tabla | 🔴 P1 | CREATE T-361 |
| GAP-D09-02 — Revocación < 30s sin tabla | 🔴 P1 | CREATE T-364 |
| GAP-D09-03 — Passkeys sin tabla | 🔴 P1 | CREATE T-367 |
| GAP-D09-04 — Certificados X.509 sin tabla | 🟠 P2 | CREATE T-362 |
| GAP-D09-05 — Token registry sin tabla | 🟠 P2 | CREATE T-363 |
| GAP-D09-06 — Recuperación sin trazabilidad | 🟠 P2 | CREATE T-365 |

**Veredicto: D09 L0-L2** — el motor de autenticación en Rust existe, pero las tablas de soporte son todas pendientes. T-361 y T-364 son bloqueantes críticos.

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.1.0 | 2026-07-31 | S14+S18 implementan 23 tablas auth_* en VPS. 5/10 bloques satisfechos (mfa, certificates, binding, passkey + B10 árbol). Estado corregido: SIN IMPLEMENTAR→PARCIAL. |
| 1.0.0 | 2026-07-28 | Versión inicial. 0/10 bloques con tablas propias (B10 en árbol). DDL propuesto T-360..T-367. 6 gaps IAM Enterprise P1/P2. Madurez D09: L0-L2. |
