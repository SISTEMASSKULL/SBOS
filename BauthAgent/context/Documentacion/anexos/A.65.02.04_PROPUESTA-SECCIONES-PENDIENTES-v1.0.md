# A.65.02.04 — Propuesta DDL Secciones Pendientes
## USUARIOS · AUTENTICACIÓN · FIRMA DIGITAL · BLOCKCHAIN D12 · FEDERACIÓN/OIDC · BILLETERA DIGITAL

**Versión:** 2.2.0 · **Fecha:** 2026-07-30  
**Estado:** PROPUESTA — pendiente de aprobación HITL para incorporar a DDL.sql y DDL_MANUAL.md  
**Referencia:** A.65.02_ANEXO-NUEVA-DDL-v1.0.md §USUARIOS, §AUTENTICACIÓN, §FIRMA DIGITAL, §FEDERACIÓN/OIDC, §BLOCKCHAIN D12  
**Cambio v2.1.0:** naming unificado a inglés para todos los identificadores SQL (tablas · columnas · constraints · índices); documentación interna en español. +T-357 sig_document_policy (política motores de firma). T-368..T-374 migradas a A.65.02.05.  
**Cambio v2.2.0:** T-339..T-341 reasignados a T-384..T-386. Motivo: T-320..T-359 está reservado para los dominios D07 (`idn_red_*`) y D08 (`idn_sesion_*`) según el esquema de rangos canónico (A.65.03.01.01). Los catálogos del MethodRegistry (`auth_federation_protocol`, `auth_saga_catalog`, `auth_compliance_map`) son infraestructura de S14, no de dominio específico, y se ubican a continuación de T-383.

---

## Convención de naming (aplicada en este documento)

| Elemento | Idioma | Ejemplo |
|---|---|---|
| Nombre de tabla | Inglés | `sig_key`, `auth_credential`, `wallet` |
| Nombre de columna | Inglés | `status`, `engine`, `signed_at` |
| Nombre de constraint | Inglés | `chk_sk_engine`, `uq_ac_user_method` |
| Nombre de índice | Inglés | `idx_sk_tenant_active`, `idx_ac_user` |
| `COMMENT ON TABLE` | Español | `'T-350 · Referencias a llaves...'` |
| `COMMENT ON COLUMN` | Español | (selectivo en columnas no obvias) |
| Comentario inline `--` | Español | `-- el secreto NUNCA sale de Vault` |
| Valores en CHECK | Inglés | `'ACTIVE'`, `'REVOKED'`, `'INTERNAL_VAULT'` |
| Prefijo de dominio 3–4 chars | Inglés | `idn_`, `auth_`, `sig_`, `blk_`, `fed_`, `wallet_` |
| Términos técnicos de protocolo | Inglés (propio nombre) | `tenant_id`, `ctx_id`, `traceparent`, `DID`, `VC`, `JWT`, `FIDO2`, `X.509`, `CRL`, `PEM`, `DER` |

---

## 0. Modelo de dominio — cuatro dimensiones transversales

### 0.1 Tres capas NIST SP 800-63-4 §3

```
CAPA 1 — IDENTIDAD ORGANIZACIONAL (existe · T-156)
  idn_identity_entity — ¿QUIÉN ES el actor en el mundo?
        │
        │ 1:N (un actor → N cuentas, una por tenant)
        ▼
CAPA 2 — SUBSCRIBER ACCOUNT (pendiente · T-320)
  idn_user — ¿PUEDE AUTENTICARSE? cuenta digital por tenant
        │
        │ 1:N (una cuenta → N autenticadores)
        ▼
CAPA 3 — AUTHENTICATOR (pendiente · T-330)
  auth_credential — ¿CÓMO PRUEBA SU IDENTIDAD? secreto/dispositivo/certificado
```

### 0.2 Context Plane — el ctx_id como dimensión transversal (SBOS-049)

El `ctx_id` NO es un string libre — es un identificador compuesto de **6 capas canónicas**:

```
tenant_id : empresa_id : sucursal_id : pos_logico : user_id : traceparent
    │            │             │            │            │          │
 UUID v4       UUID v4      UUID|null    string      UUID v4    W3C Trace Context
 (SBOS-049)   (D00 nivel2) (D00 nivel3) (D00 nivel4) (post-auth) 00-{32hex}-{16hex}-01
```

Reforma pendiente D00 §9.1 (P1): `ctx_id = interno.{tenant_id}.{bdomain_id}.{bsubdomain_id}`  
**Regla en toda tabla nueva:** `ctx_id TEXT NOT NULL DEFAULT 'system'` — compatible con representación compacta vigente.

### 0.3 Clasificación de tenants

| Tipo | Significado |
|---|---|
| `STANDARD` | Cliente ordinario (99% de tenants) |
| `REGULATED` | Financiero/salud/educación con cumplimiento especial |
| `HIGH_SENSITIVITY` | Estado, infraestructura crítica |
| `INTERNAL` | El propio SBOS y sus daemons (NHI) |
| `PARTNER_FEDERATED` | IdP externo federado que delega autenticación |

### 0.4 Firma digital — dos motores, propósitos distintos (Ley 164 Bolivia Art. 82)

Bolivia distingue dos categorías legalmente distintas:

| Categoría legal | Motor SBOS | Quién emite | Validez | Cuándo se usa |
|---|---|---|---|---|
| **Firma digital** | Externo ADSIB (RSA-SHA256) | Certificadora habilitada por el Estado (ADSIB/ATT) | Jurídica = equivalente a firma manuscrita ante Estado y terceros | Facturas SIN, contratos, actas notariales, documentos con efectos jurídicos externos |
| **Firma electrónica** | Interno Vault (Ed25519) | PKI propia SBOS (Root CA → Internal Sub-CA) | Empresarial = control de integridad interno sin efectos jurídicos externos | JWTs, estados de saga, auditoría, signing de binarios, trámites internos |

**Ambos motores en el mismo documento** es válido y necesario para documentos que tienen efectos internos Y jurídicos (contratos laborales, actas de directorio, expedientes RRHH). Son dos actos de firma independientes sobre el mismo hash — una garantiza integridad del proceso, la otra otorga validez jurídica. La selección de motores requeridos por tipo de documento vive en T-357 `sig_document_policy`.

**El motor externo ADSIB aplica a TODOS los tenants** (interno, estándar, regulado) cuando el documento tiene efectos jurídicos — es una norma de Estado, no de categoría de tenant.

### 0.5 Las tres capas de evidencia

```
NIVEL 1 — FIRMA (D13)
  Motor Interno Vault Ed25519  |  Motor Externo ADSIB RSA-SHA256 (Ley 164)
        │
        ▼
NIVEL 2 — HASH-CHAIN (D11)
  WORM append-only encadenado con SHA-256 del registro anterior:
  idn_user_history · auth_attempt_log · sig_operation_log
        │
        ▼
NIVEL 3 — BLOCKCHAIN ANCHOR (D12 — Forma A)
  Anclaje Merkle en Arbitrum L2 (pública) — verificable offline con bos-verify.
  Keccak-256, RFC 6962 (Certificate Transparency), hasta 1M hojas por lote.
```

### 0.6 Billetera digital — cuatro capas

```
CAPA A — Credenciales de identidad (W3C VCs + FIDO2 + X.509 + DID)
  T-380 wallet · T-381 wallet_item → apunta a T-167/T-332/T-333/T-169/T-351

CAPA B — Firma digital (D13)
  T-350..T-357 sig_*  →  certificados ADSIB + operaciones de firma

CAPA C — Anclaje blockchain (D12)
  T-358..T-362 blk_*  →  ancla Merkle + liquidación Besu

CAPA D — Financiera (D3) — fuera de alcance de esta sección; D3 la gestiona

Estándares: W3C VCDM 2.0 · OpenID4VP · OpenID4VCI · W3C DID Core 1.0 ·
EUDI Wallet eIDAS 2.0 Art. 5a · ISO 18013-5 (mDL) · SD-JWT VC · Ley 164 Bolivia
```

---

## 1. Sección USUARIOS — S13 (T-320..T-322)

### 1.1 T-320 `bauth.idn_user` — Cuenta de suscriptor (Subscriber Account)

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_user (
    user_id              UUID         NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id            UUID         NOT NULL
                                      REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    entity_id            UUID         NOT NULL
                                      REFERENCES bauth.idn_identity_entity(entity_id),

    -- Identificador de login
    username             TEXT         NOT NULL,

    -- Ciclo de vida (NIST SP 800-63-4 §3 · ISO/IEC 24760-2:2025 §6.2)
    status               TEXT         NOT NULL DEFAULT 'PENDING_ACTIVATION'
                                      CONSTRAINT chk_iu_status CHECK (status IN (
                                          'PENDING_ACTIVATION','ACTIVE','LOCKED',
                                          'SUSPENDED','DEACTIVATED','ARCHIVED')),
    registration_method  TEXT         NOT NULL DEFAULT 'ADMIN'
                                      CONSTRAINT chk_iu_reg_method CHECK (registration_method IN (
                                          'ADMIN','SELF_SERVICE','PROVISIONED','FEDERATED')),

    -- Niveles de aseguramiento (NIST SP 800-63-4)
    ial_achieved         TEXT         NULL
                                      CONSTRAINT chk_iu_ial CHECK (ial_achieved IN ('IAL1','IAL2','IAL3')),
    loa_min              TEXT         NOT NULL DEFAULT 'AAL1'
                                      CONSTRAINT chk_iu_loa CHECK (loa_min IN ('AAL1','AAL2','AAL3')),

    -- Control de lockout (NIST SP 800-63B-4 §5.2.2)
    failed_attempts      INT          NOT NULL DEFAULT 0,
    lockout_until        TIMESTAMPTZ  NULL,

    -- Estado de contraseña
    password_changed_at  TIMESTAMPTZ  NULL,
    must_change_password BOOLEAN      NOT NULL DEFAULT FALSE,

    -- Métricas de uso
    last_login_at        TIMESTAMPTZ  NULL,
    last_login_ip        INET         NULL,

    -- SCIM 2.0 (RFC 7643 §4.1) — id externo del proveedor de provisioning
    scim_external_id     TEXT         NULL,

    -- Billetera digital — FK lógica a T-380 wallet (nula hasta activación)
    wallet_id            UUID         NULL,

    -- Context Plane
    ctx_id               TEXT         NOT NULL DEFAULT 'system',

    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uq_iu_username_tenant UNIQUE (tenant_id, username),
    CONSTRAINT uq_iu_entity_tenant   UNIQUE (tenant_id, entity_id)
    -- Un actor = una cuenta por tenant. Decisión HITL D-US-01.
);

CREATE INDEX IF NOT EXISTS idx_iu_status  ON bauth.idn_user (tenant_id, status) WHERE status IN ('ACTIVE','LOCKED');
CREATE INDEX IF NOT EXISTS idx_iu_entity  ON bauth.idn_user (entity_id);
CREATE INDEX IF NOT EXISTS idx_iu_lockout ON bauth.idn_user (lockout_until) WHERE lockout_until IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_iu_wallet  ON bauth.idn_user (wallet_id) WHERE wallet_id IS NOT NULL;

COMMENT ON TABLE bauth.idn_user IS
    'T-320 · Subscriber Account (NIST SP 800-63-4 §3): cuenta digital de login por tenant. '
    'Capa 2 del modelo de identidad — separada de la identidad organizacional (T-156) y '
    'de los autenticadores (T-330). Primer filtro del PDP: status != ACTIVE → rechaza '
    'sin evaluar métodos. Un mismo entity_id puede tener cuentas en distintos tenants; '
    'UNIQUE(tenant_id, entity_id) garantiza una cuenta por tenant.';
```

### 1.2 T-321 `bauth.idn_user_history` — Historial WORM de la cuenta

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_user_history (
    history_id  UUID         NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    user_id     UUID         NOT NULL REFERENCES bauth.idn_user(user_id) ON DELETE CASCADE,
    tenant_id   UUID         NOT NULL,
    field       TEXT         NOT NULL,
    old_value   JSONB        NULL,
    new_value   JSONB        NOT NULL,
    changed_by  UUID         NULL,          -- NULL = cambio automático del daemon
    reason      TEXT         NULL,
    ctx_id      TEXT         NOT NULL DEFAULT 'system',
    changed_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    prev_hash   TEXT         NULL           -- SHA-256 de la fila anterior → cadena WORM
);

REVOKE UPDATE, DELETE ON bauth.idn_user_history FROM bauth_app_role;
CREATE INDEX IF NOT EXISTS idx_iuh_user ON bauth.idn_user_history (user_id, changed_at DESC);

COMMENT ON TABLE bauth.idn_user_history IS
    'T-321 · WORM hash-chain. Historial de cambios en T-320 (status, lockout, ial_achieved, '
    'loa_min, must_change_password). prev_hash encadena filas para detectar manipulación. '
    'ISO 27001 A.8.15. REVOKE UPDATE/DELETE.';
```

### 1.3 T-322 `bauth.idn_user_recovery` — Métodos de recuperación de cuenta

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_user_recovery (
    recovery_id UUID         NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    user_id     UUID         NOT NULL REFERENCES bauth.idn_user(user_id) ON DELETE CASCADE,
    tenant_id   UUID         NOT NULL,
    type        TEXT         NOT NULL
                             CONSTRAINT chk_iur_type CHECK (type IN (
                                 'BACKUP_EMAIL','BACKUP_PHONE','TRUSTED_CONTACT','ADMIN_OVERRIDE')),
    value_hash  TEXT         NULL,          -- SHA-256 del email/teléfono — NUNCA en claro
    status      TEXT         NOT NULL DEFAULT 'ACTIVE'
                             CONSTRAINT chk_iur_status CHECK (status IN ('ACTIVE','USED','REVOKED')),
    valid_until TIMESTAMPTZ  NULL,
    used_at     TIMESTAMPTZ  NULL,
    ctx_id      TEXT         NOT NULL DEFAULT 'system',
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iur_user_active ON bauth.idn_user_recovery (user_id, type) WHERE status = 'ACTIVE';

COMMENT ON TABLE bauth.idn_user_recovery IS
    'T-322 · Métodos de recuperación de cuenta (≠ autenticadores MFA). '
    'value_hash es SHA-256 del dato de contacto — NUNCA en claro. OWASP ASVS v5.0 §2.5.';
```

---

## 2. Sección AUTENTICACIÓN — S14 (T-330..T-338 · T-384..T-386)

### 2.1 T-330 `bauth.auth_credential` — Binding autenticador↔cuenta (PIP)

```sql
CREATE TABLE IF NOT EXISTS bauth.auth_credential (
    credential_id         UUID         NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    user_id               UUID         NOT NULL REFERENCES bauth.idn_user(user_id) ON DELETE CASCADE,
    tenant_id             UUID         NOT NULL,
    method_code           TEXT         NOT NULL,  -- referencia lógica a T-335 auth_method.code
    status                TEXT         NOT NULL DEFAULT 'ACTIVE'
                                        CONSTRAINT chk_ac_status CHECK (status IN (
                                            'PENDING_ACTIVATION','ACTIVE','SUSPENDED','REVOKED','EXPIRED')),
    loa_provided          TEXT         NOT NULL
                                        CONSTRAINT chk_ac_loa CHECK (loa_provided IN ('AAL1','AAL2','AAL3')),
    is_primary            BOOLEAN      NOT NULL DEFAULT FALSE,
    is_phishing_resistant BOOLEAN      NOT NULL DEFAULT FALSE,
    enrolled_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    valid_from            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    valid_until           TIMESTAMPTZ  NULL,
    last_used_at          TIMESTAMPTZ  NULL,
    revoked_at            TIMESTAMPTZ  NULL,
    revocation_reason     TEXT         NULL,
    ctx_id                TEXT         NOT NULL DEFAULT 'system',
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ac_user_active ON bauth.auth_credential (user_id, method_code) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_ac_valid_until ON bauth.auth_credential (valid_until) WHERE valid_until IS NOT NULL AND status = 'ACTIVE';

COMMENT ON TABLE bauth.auth_credential IS
    'T-330 · Capa 3 (Authenticator — NIST SP 800-63-4 §5): binding autenticador↔cuenta. '
    'PIP: el PDP consulta loa_provided para determinar LoA disponible y si requiere '
    'step-up (RFC 9470). Secretos NUNCA aquí: T-331 (KDF/TOTP) · T-332 (FIDO2) · T-333 (X.509). '
    'method_code sin FK nativa — T-334 debe poder registrar method_codes desconocidos.';
```

### 2.2 T-331 `bauth.auth_credential_secret` — Secretos cifrados (Vault transit)

```sql
CREATE TABLE IF NOT EXISTS bauth.auth_credential_secret (
    secret_id         UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    credential_id     UUID    NOT NULL UNIQUE REFERENCES bauth.auth_credential(credential_id) ON DELETE CASCADE,
    type              TEXT    NOT NULL CONSTRAINT chk_acs_type CHECK (type IN (
                               'ARGON2ID_HASH',       -- contraseña (NIST SP 800-63B-4 §5.1.1)
                               'TOTP_SEED_ENC',       -- semilla TOTP AES-256-GCM (RFC 6238)
                               'HOTP_SEED_ENC',       -- semilla HOTP AES-256-GCM (RFC 4226)
                               'RECOVERY_CODE_HASH',  -- códigos de recuperación SHA-256
                               'PUSH_PUBKEY_ED25519'  -- clave pública para push MFA
                              )),
    secret            TEXT    NOT NULL,                -- Vault transit ciphertext — NUNCA en claro en disco
    algorithm         TEXT    NOT NULL,                -- 'argon2id', 'AES-256-GCM', 'ed25519'
    params            JSONB   NOT NULL DEFAULT '{}',
    -- Argon2id params: {"memory_kib":65536,"iterations":3,"parallelism":4,"saltlen":16}
    -- AES-256-GCM params: {"iv_len":12,"tag_len":16}
    vault_key_version INT     NOT NULL DEFAULT 1,
    rotated_at        TIMESTAMPTZ NULL,
    ctx_id            TEXT    NOT NULL DEFAULT 'system',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Rotación = INSERT nueva fila + status=REVOKED en T-330; NUNCA UPDATE del secreto
REVOKE UPDATE (secret) ON bauth.auth_credential_secret FROM bauth_app_role;
```

### 2.3 T-332 `bauth.auth_credential_fido2` — FIDO2/Passkey/WebAuthn Level 3

```sql
CREATE TABLE IF NOT EXISTS bauth.auth_credential_fido2 (
    fido2_id             UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    credential_id        UUID    NOT NULL UNIQUE REFERENCES bauth.auth_credential(credential_id) ON DELETE CASCADE,
    credential_id_bytes  BYTEA   NOT NULL,   -- credentialId asignado por el autenticador FIDO2
    public_key_cose      BYTEA   NOT NULL,   -- clave pública en formato COSE
    aaguid               UUID    NOT NULL,
    attestation_fmt      TEXT    NOT NULL CONSTRAINT chk_af2_fmt CHECK (attestation_fmt IN (
                                     'packed','tpm','fido-u2f','none','apple',
                                     'android-safetynet','android-key')),
    attestation_data     JSONB   NOT NULL DEFAULT '{}',
    sign_count           BIGINT  NOT NULL DEFAULT 0,   -- anti-replay (FIDO2 spec §6.1)
    is_discoverable      BOOLEAN NOT NULL DEFAULT FALSE,
    is_cross_platform    BOOLEAN NOT NULL DEFAULT FALSE,
    backup_eligible      BOOLEAN NOT NULL DEFAULT FALSE,
    backup_state         BOOLEAN NOT NULL DEFAULT FALSE,
    transports           TEXT[]  NOT NULL DEFAULT '{}',  -- usb|nfc|ble|internal|hybrid|smart-card
    device_name          TEXT    NULL,
    ctx_id               TEXT    NOT NULL DEFAULT 'system',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 2.4 T-333 `bauth.auth_credential_x509` — X.509 mTLS (Vault PKI interno + ADSIB Bolivia)

```sql
CREATE TABLE IF NOT EXISTS bauth.auth_credential_x509 (
    x509_id             UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    credential_id       UUID    NOT NULL UNIQUE REFERENCES bauth.auth_credential(credential_id) ON DELETE CASCADE,
    origin              TEXT    NOT NULL CONSTRAINT chk_ax509_origin CHECK (origin IN (
                                    'VAULT_INTERNAL',  -- SBOS Root CA → Internal Sub-CA
                                    'ADSIB_EXTERNA',   -- ATT → ADSIB (Ley 164 Bolivia)
                                    'ENTERPRISE_PKI',  -- PKI empresarial del tenant
                                    'SELF_SIGNED')),   -- solo para desarrollo
    subject_dn          TEXT    NOT NULL,
    issuer_dn           TEXT    NOT NULL,
    serial_number       TEXT    NOT NULL,
    fingerprint_sha256  TEXT    NOT NULL UNIQUE,
    not_before          TIMESTAMPTZ NOT NULL,
    not_after           TIMESTAMPTZ NOT NULL,
    san                 TEXT[]  NULL,
    key_usage           TEXT[]  NOT NULL DEFAULT '{}',
    extended_key_usage  TEXT[]  NOT NULL DEFAULT '{}',
    -- Bolivia — Ley 164
    oid_adsib           TEXT    NULL,
    is_adsib_qualified  BOOLEAN NOT NULL DEFAULT FALSE,
    vault_path          TEXT    NULL,       -- ruta en Vault si origin=VAULT_INTERNAL
    -- Revocación
    ocsp_url            TEXT    NULL,
    revoked_by_ca_at    TIMESTAMPTZ NULL,
    revocation_reason   TEXT    NULL,
    ctx_id              TEXT    NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ax509_fingerprint ON bauth.auth_credential_x509 (fingerprint_sha256);
CREATE INDEX IF NOT EXISTS idx_ax509_not_after   ON bauth.auth_credential_x509 (not_after) WHERE revoked_by_ca_at IS NULL;
```

### 2.5 T-334 `bauth.auth_attempt_log` — Log WORM de intentos (ITDR)

```sql
CREATE TABLE IF NOT EXISTS bauth.auth_attempt_log (
    attempt_id       UUID         NOT NULL DEFAULT uuidv7(),
    tenant_id        UUID         NOT NULL,
    user_id          UUID         NULL,   -- NULL si el usuario no existe (credential stuffing)
    username_tried   TEXT         NULL,
    method_code      TEXT         NOT NULL,
    outcome          TEXT         NOT NULL CONSTRAINT chk_aal_outcome CHECK (outcome IN (
                                      'SUCCESS','FAILURE','LOCKED','STEP_UP_REQUIRED',
                                      'EXPIRED','INVALID_USER','REVOKED_CREDENTIAL')),
    failure_reason   TEXT         NULL,
    loa_requested    TEXT         NULL,
    loa_achieved     TEXT         NULL,
    ip_address       INET         NOT NULL,
    user_agent       TEXT         NULL,
    device_id        UUID         NULL,   -- FK lógica a tabla DISPOSITIVOS (sección futura)
    session_id       UUID         NULL,   -- FK lógica a T-181 ses_session_log
    ctx_id           TEXT         NOT NULL DEFAULT 'system',
    traceparent      TEXT         NULL,
    attempted_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
) PARTITION BY RANGE (attempted_at);

CREATE TABLE IF NOT EXISTS bauth.auth_attempt_log_2026_07
    PARTITION OF bauth.auth_attempt_log
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.auth_attempt_log_2026_08
    PARTITION OF bauth.auth_attempt_log
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

REVOKE UPDATE, DELETE ON bauth.auth_attempt_log FROM bauth_app_role;

CREATE INDEX IF NOT EXISTS idx_aal_ip_failed   ON bauth.auth_attempt_log (ip_address, attempted_at DESC) WHERE outcome IN ('FAILURE','INVALID_USER');
CREATE INDEX IF NOT EXISTS idx_aal_user_failed ON bauth.auth_attempt_log (user_id, attempted_at DESC) WHERE outcome = 'FAILURE';

COMMENT ON TABLE bauth.auth_attempt_log IS
    'T-334 · WORM particionado por mes. Log forense de todos los intentos de autenticación. '
    'Fuente ITDR: brute-force detection, impossible travel, credential stuffing. '
    'user_id NULL para usuarios inexistentes — registrar el intento es obligatorio para no '
    'cegar la detección de amenazas. PCI DSS 4.0 Req 8.2.8. NIST SP 800-63B-4 §5.2.2.';
```

### 2.6 Framework declarativo (T-335..T-338 · T-384..T-386) — catálogos del MethodRegistry

```sql
-- T-335: bauth.auth_method — catálogo maestro de métodos de autenticación
CREATE TABLE IF NOT EXISTS bauth.auth_method (
    method_id             UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    code                  TEXT    NOT NULL UNIQUE,
    category              TEXT    NOT NULL CONSTRAINT chk_am_cat CHECK (category IN (
                                      'A',  -- conocimiento (contraseña, PIN)
                                      'B',  -- posesión (TOTP, HOTP, passkey, smart card)
                                      'C',  -- inherencia (biométrico)
                                      'D',  -- federación (OIDC, SAML, brokering)
                                      'E',  -- especiales (CIBA, device auth, step-up)
                                      'F'   -- descentralizada (DID, VC)
                                  )),
    name                  JSONB   NOT NULL,   -- {"es":"...","en":"..."}
    description           JSONB   NOT NULL,
    loa_provided          TEXT    NOT NULL CONSTRAINT chk_am_loa CHECK (loa_provided IN ('AAL1','AAL2','AAL3')),
    is_phishing_resistant BOOLEAN NOT NULL DEFAULT FALSE,
    is_mfa_component      BOOLEAN NOT NULL DEFAULT FALSE,
    status                TEXT    NOT NULL DEFAULT 'PLANNED'
                                   CONSTRAINT chk_am_status CHECK (status IN ('IMPLEMENTED','PLANNED','DEPRECATED','REMOVED')),
    standards             TEXT[]  NOT NULL DEFAULT '{}',
    sort_order            INT     NOT NULL DEFAULT 0
);

-- T-336: bauth.auth_policy — políticas de autenticación por contexto (complementa T-042 por tier)
CREATE TABLE IF NOT EXISTS bauth.auth_policy (
    policy_id        UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id        UUID    NULL REFERENCES bauth.idn_tenant(tenant_id),  -- NULL = global
    name             TEXT    NOT NULL,
    description      TEXT    NOT NULL,
    loa_required     TEXT    NOT NULL CONSTRAINT chk_ap_loa CHECK (loa_required IN ('AAL1','AAL2','AAL3')),
    allowed_methods  TEXT[]  NOT NULL DEFAULT '{}',
    required_methods TEXT[]  NOT NULL DEFAULT '{}',
    max_session_secs INT     NULL,
    step_up_trigger  JSONB   NULL,   -- condición para step-up (RFC 9470)
    active           BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id           TEXT    NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- T-337: bauth.auth_config — parámetros técnicos del motor sin hardcode
CREATE TABLE IF NOT EXISTS bauth.auth_config (
    config_id    UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id    UUID    NULL REFERENCES bauth.idn_tenant(tenant_id),
    key          TEXT    NOT NULL,   -- 'lockout.max_attempts', 'argon2id.memory_kib', ...
    value        JSONB   NOT NULL,
    description  TEXT    NOT NULL,
    effective_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id       TEXT    NOT NULL DEFAULT 'system',
    CONSTRAINT uq_auth_config_key UNIQUE (tenant_id, key)
);

-- T-338: bauth.auth_crypto_algorithm — algoritmos criptográficos aprobados por el sistema
CREATE TABLE IF NOT EXISTS bauth.auth_crypto_algorithm (
    algo_id       UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    code          TEXT    NOT NULL UNIQUE,
    type          TEXT    NOT NULL CONSTRAINT chk_aca_type CHECK (type IN (
                              'KDF','SYMMETRIC','ASYMMETRIC_SIG','ASYMMETRIC_KEM','HASH','PQC')),
    is_pqc        BOOLEAN NOT NULL DEFAULT FALSE,
    default_params JSONB  NOT NULL DEFAULT '{}',
    status        TEXT    NOT NULL DEFAULT 'APPROVED'
                           CONSTRAINT chk_aca_status CHECK (status IN ('APPROVED','DEPRECATED','FORBIDDEN')),
    nist_ref      TEXT    NULL,   -- 'FIPS 205', 'FIPS 206', 'SP 800-132'
    deprecated_at TIMESTAMPTZ NULL
    -- Seeds APPROVED: ARGON2ID · AES-256-GCM · ED25519 · ECDSA-P384 · ML-KEM-768 · ML-DSA-65 · SHA-256 · SHA3-256 · BLAKE3
    -- Seeds FORBIDDEN: MD5 · SHA-1 · RSA-1024 · DES · 3DES
);

-- T-384..T-386: catálogos declarativos (bosquejo — desarrollo en sesión siguiente)
-- NOTA: T-339..T-341 reservados para D07 (idn_red_*) y D08 (idn_sesion_*) — reasignados
-- T-384 bauth.auth_federation_protocol  — OIDC · SAML2 · OAUTH2 · WS_FED
-- T-385 bauth.auth_saga_catalog         — flujos multi-paso por AAL
-- T-386 bauth.auth_compliance_map       — método → estándar → control_ref
```

---

## 3. Sección FIRMA DIGITAL — S15 (T-350..T-357)

Esta sección es el plano de control de **D13 — Firma Digital** (36 átomos: 5929–5964,
módulos `chain`/`did`/`legalsg`, `blockchain_anchored=1`). Gestiona el doble motor de firma
y la política de cuándo usar cada uno.

### 3.1 T-350 `bauth.sig_key` — Referencias a llaves criptográficas en Vault

```sql
CREATE TABLE IF NOT EXISTS bauth.sig_key (
    key_id         UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id      UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    engine         TEXT    NOT NULL CONSTRAINT chk_sk_engine CHECK (engine IN (
                               'INTERNAL_VAULT',  -- Ed25519, gestionado por Vault PKI
                               'EXTERNAL_ADSIB'   -- RSA-SHA256, certificado ADSIB Bolivia
                           )),
    vault_path     TEXT    NOT NULL,   -- ruta en Vault (ej: 'pki/roles/daemon-cert')
    vault_key_version INT  NOT NULL DEFAULT 1,
    algorithm      TEXT    NOT NULL,   -- 'ed25519', 'rsa-sha256', 'ecdsa-p384'
    purpose        TEXT    NOT NULL CONSTRAINT chk_sk_purpose CHECK (purpose IN (
                               'JWT_SIGNING',      -- firma de JWTs internos
                               'DOCUMENT_SIGNING', -- firma de documentos (D13)
                               'CODE_SIGNING',     -- binarios SBOS
                               'TLS_CLIENT',       -- certificados cliente mTLS
                               'ADSIB_BILLING',    -- firma facturas SIN (Ley 164)
                               'ADSIB_CONTRACTS'   -- firma contratos externos
                           )),
    -- Jerarquía de la CA
    -- Interna: SBOS Root CA (10yr offline) → Internal Sub-CA (5yr) → {Daemon 24h / Service 90d / Admin 180d / App 365d}
    -- Externa: ATT Root (20yr) → ADSIB CA (10yr) → Persona Natural/Jurídica (1yr RSA 2048/4096)
    root_ca_fingerprint TEXT NULL,
    status         TEXT    NOT NULL DEFAULT 'ACTIVE' CONSTRAINT chk_sk_status CHECK (
                               status IN ('ACTIVE','ROTATING','SUSPENDED','REVOKED')),
    active_since   TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at     TIMESTAMPTZ NULL,
    next_rotation  TIMESTAMPTZ NULL,
    rotated_at     TIMESTAMPTZ NULL,
    ctx_id         TEXT    NOT NULL DEFAULT 'system',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sk_tenant_active ON bauth.sig_key (tenant_id, engine, purpose) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_sk_rotation      ON bauth.sig_key (next_rotation) WHERE status = 'ACTIVE' AND next_rotation IS NOT NULL;

COMMENT ON TABLE bauth.sig_key IS
    'T-350 · Referencias a llaves criptográficas en Vault — NUNCA contiene la clave privada. '
    'Motor interno: Vault PKI Ed25519, TTL 24h-365d según perfil de uso. '
    'Motor externo ADSIB: RSA-SHA256, 1 año, máx. 4 reemisiones, HSM FIPS 140-2. '
    'Prefijo Vault para ADSIB: secret/adsib/{tenant_id}/. '
    'Aplica a TODOS los tenants cuando el documento requiere validez jurídica (Ley 164).';
```

### 3.2 T-351 `bauth.sig_certificate` — Catálogo de certificados X.509 del tenant

```sql
CREATE TABLE IF NOT EXISTS bauth.sig_certificate (
    cert_id             UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    key_id              UUID    NOT NULL REFERENCES bauth.sig_key(key_id) ON DELETE CASCADE,
    tenant_id           UUID    NOT NULL,
    engine              TEXT    NOT NULL CONSTRAINT chk_sc_engine CHECK (engine IN (
                                    'INTERNAL_VAULT','EXTERNAL_ADSIB','ENTERPRISE_PKI')),
    subject_dn          TEXT    NOT NULL,
    issuer_dn           TEXT    NOT NULL,
    serial_number       TEXT    NOT NULL,
    fingerprint_sha256  TEXT    NOT NULL UNIQUE,
    not_before          TIMESTAMPTZ NOT NULL,
    not_after           TIMESTAMPTZ NOT NULL,
    san                 TEXT[]  NULL,
    key_usage           TEXT[]  NOT NULL DEFAULT '{}',
    cert_pem            TEXT    NOT NULL,   -- PEM público solamente — sin clave privada
    -- Bolivia — Ley 164
    adsib_type          TEXT    NULL CONSTRAINT chk_sc_adsib CHECK (adsib_type IN (
                            'PERSONA_NATURAL','PERSONA_JURIDICA','FIRMA_AUTOMATICA')),
    issuer_nit          TEXT    NULL,       -- NIT de la empresa (certificado persona jurídica)
    -- Estado
    status              TEXT    NOT NULL DEFAULT 'ACTIVE' CONSTRAINT chk_sc_status CHECK (
                            status IN ('ACTIVE','EXPIRED','REVOKED','SUSPENDED')),
    revoked_by_ca_at    TIMESTAMPTZ NULL,
    ocsp_url            TEXT    NULL,
    ocsp_verified_at    TIMESTAMPTZ NULL,
    ctx_id              TEXT    NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sc_tenant_active ON bauth.sig_certificate (tenant_id, engine) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_sc_expiry        ON bauth.sig_certificate (not_after) WHERE status = 'ACTIVE';
-- Job semanal: 30d → alerta Admin Tenant · 15d → alerta Admin bAuth · 7d → auto-renovación

COMMENT ON TABLE bauth.sig_certificate IS
    'T-351 · Catálogo de certificados X.509 — PEM público solamente. '
    'Motor interno: SBOS Root CA → Internal Sub-CA → perfil {Daemon/Service/Admin/App}. '
    'Motor externo: ATT Root → ADSIB CA → Persona Natural/Jurídica/Firma Automática.';
```

### 3.3 T-352 `bauth.sig_crl` — Listas de revocación (CRL) activas

```sql
CREATE TABLE IF NOT EXISTS bauth.sig_crl (
    crl_id        UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    issuer_dn     TEXT    NOT NULL,
    engine        TEXT    NOT NULL CONSTRAINT chk_scrl_engine CHECK (engine IN ('INTERNAL_VAULT','EXTERNAL_ADSIB')),
    crl_der       BYTEA   NOT NULL,      -- CRL en formato DER
    next_update   TIMESTAMPTZ NOT NULL,  -- próxima actualización obligatoria
    downloaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id        TEXT    NOT NULL DEFAULT 'system'
);

CREATE INDEX IF NOT EXISTS idx_scrl_next_update ON bauth.sig_crl (next_update);
-- Job: ADSIB CRL cada hora · Vault CRL cada 24h
```

### 3.4 T-353 `bauth.sig_operation_log` — Log WORM de operaciones de firma

```sql
CREATE TABLE IF NOT EXISTS bauth.sig_operation_log (
    operation_id     UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id        UUID    NOT NULL,
    key_id           UUID    NOT NULL REFERENCES bauth.sig_key(key_id),
    cert_id          UUID    NULL     REFERENCES bauth.sig_certificate(cert_id),
    engine           TEXT    NOT NULL CONSTRAINT chk_sol_engine CHECK (engine IN ('INTERNAL_VAULT','EXTERNAL_ADSIB')),
    -- Qué se firmó
    document_hash    TEXT    NOT NULL,  -- SHA-256 del documento en claro
    document_type    TEXT    NOT NULL,  -- ver T-357 sig_document_policy para valores válidos
    signature_format TEXT    NOT NULL,  -- 'JWS','XAdES-BES','PAdES-B','CAdES-B','INT-T','INT-LT','EXT-LTA'
    -- Quién firmó
    signed_by        UUID    NOT NULL,  -- user_id o NHI id
    signer_type      TEXT    NOT NULL CONSTRAINT chk_sol_stype CHECK (signer_type IN ('HUMAN','NHI','DAEMON')),
    purpose          TEXT    NOT NULL,  -- 'SAGA_INSTALL','BILLING_SIN','CONTRACT','VC_ISSUANCE','AUDIT_ANCHOR'
    -- Resultado
    outcome          TEXT    NOT NULL CONSTRAINT chk_sol_outcome CHECK (
                         outcome IN ('SUCCESS','FAILURE','CERT_EXPIRED','CERT_REVOKED')),
    signature_ref    TEXT    NULL,  -- referencia al resultado (hash del JWS, URI del doc, etc.)
    error_msg        TEXT    NULL,
    -- Anclaje blockchain (D12 Forma A — si aplica según T-357)
    merkle_batch_id  UUID    NULL,  -- FK lógica a T-359 blk_merkle_batch
    onchain_tx_hash  TEXT    NULL,  -- tx hash en Arbitrum una vez anclado
    -- Context Plane
    ctx_id           TEXT    NOT NULL DEFAULT 'system',
    traceparent      TEXT    NULL,
    signed_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

REVOKE UPDATE, DELETE ON bauth.sig_operation_log FROM bauth_app_role;

CREATE INDEX IF NOT EXISTS idx_sol_tenant_at ON bauth.sig_operation_log (tenant_id, signed_at DESC);
CREATE INDEX IF NOT EXISTS idx_sol_doc_hash  ON bauth.sig_operation_log (document_hash);
CREATE INDEX IF NOT EXISTS idx_sol_batch     ON bauth.sig_operation_log (merkle_batch_id) WHERE merkle_batch_id IS NOT NULL;

COMMENT ON TABLE bauth.sig_operation_log IS
    'T-353 · WORM. Log forense de cada acto de firma — interno (Vault Ed25519) o externo '
    '(ADSIB RSA-SHA256, Ley 164). Un documento que requiere ambos motores (T-357 engine_required=BOTH) '
    'produce 2 filas con el mismo document_hash y engines distintos. '
    'merkle_batch_id conecta con D12 Forma A para verificabilidad externa offline.';
```

### 3.5 T-354 `bauth.sig_document_hash` — Registro de documentos firmados

```sql
CREATE TABLE IF NOT EXISTS bauth.sig_document_hash (
    document_id         UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id           UUID    NOT NULL,
    operation_id        UUID    NOT NULL REFERENCES bauth.sig_operation_log(operation_id),
    -- Integridad del documento
    hash_sha256         TEXT    NOT NULL UNIQUE,
    hash_sha3_256       TEXT    NULL,       -- hash adicional para defensa post-cuántica
    document_type       TEXT    NOT NULL,
    title               TEXT    NULL,
    -- Firma y timestamp calificado
    signature_format    TEXT    NOT NULL,
    timestamp_id        UUID    NULL REFERENCES bauth.sig_timestamp(timestamp_id),
    -- Anclaje blockchain D12 Forma A
    blockchain_anchored BOOLEAN NOT NULL DEFAULT FALSE,
    merkle_batch_id     UUID    NULL,
    onchain_tx_hash     TEXT    NULL,
    -- Retención (Ley 164: 8 años para facturas SIN · ISO 27001: 7 años para auditoría)
    retention_years     INT     NOT NULL DEFAULT 7,
    purge_after         TIMESTAMPTZ NOT NULL,
    ctx_id              TEXT    NOT NULL DEFAULT 'system',
    signed_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

REVOKE UPDATE, DELETE ON bauth.sig_document_hash FROM bauth_app_role;
CREATE INDEX IF NOT EXISTS idx_sdh_hash  ON bauth.sig_document_hash (hash_sha256);
CREATE INDEX IF NOT EXISTS idx_sdh_purge ON bauth.sig_document_hash (purge_after);
```

### 3.6 T-355 `bauth.sig_timestamp` — Timestamps calificados (RFC 3161)

```sql
CREATE TABLE IF NOT EXISTS bauth.sig_timestamp (
    timestamp_id     UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tsa_url          TEXT    NOT NULL,       -- URL de la TSA
    document_hash    TEXT    NOT NULL,       -- hash del documento o firma sellada
    tsa_response_der BYTEA   NOT NULL,       -- TSTInfo en DER
    tsa_serial       TEXT    NOT NULL,
    gen_time         TIMESTAMPTZ NOT NULL,   -- tiempo generado por la TSA
    policy_oid       TEXT    NULL,
    ctx_id           TEXT    NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

REVOKE UPDATE, DELETE ON bauth.sig_timestamp FROM bauth_app_role;

COMMENT ON TABLE bauth.sig_timestamp IS
    'T-355 · Timestamps calificados RFC 3161. '
    'Vault Timestamp (interno) para perfiles INT-T/LT. '
    'TSA ADSIB (externo) para perfiles EXT-T/LT/LTA con validez legal Ley 164.';
```

### 3.7 T-356 `bauth.sig_adsib_lifecycle` — Ciclo de vida del certificado ADSIB

```sql
CREATE TABLE IF NOT EXISTS bauth.sig_adsib_lifecycle (
    lifecycle_id   UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id      UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    cert_id        UUID    NOT NULL REFERENCES bauth.sig_certificate(cert_id),
    event          TEXT    NOT NULL CONSTRAINT chk_sal_event CHECK (event IN (
                       'ISSUED',        -- certificado nuevo recibido de ADSIB
                       'ACTIVATED',     -- en uso activo
                       'ALERT_30D',     -- 30 días → alerta Admin Tenant
                       'ALERT_15D',     -- 15 días → alerta Admin bAuth
                       'ALERT_7D',      -- 7 días → auto-renovación si configurado
                       'RENEWAL_CSR',   -- generado CSR de renovación
                       'RENEWED',       -- certificado renovado (solapamiento 7d)
                       'EXPIRED',       -- expiró sin renovar → BLOQUEO firma externa
                       'REVOKED_BY_CA', -- revocado por ADSIB → BLOQUEO INMEDIATO
                       'REISSUED')),    -- máximo 4 reemisiones (política ADSIB)
    description    TEXT    NULL,
    reissue_number INT     NULL CHECK (reissue_number <= 4),
    ctx_id         TEXT    NOT NULL DEFAULT 'system',
    event_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

REVOKE UPDATE, DELETE ON bauth.sig_adsib_lifecycle FROM bauth_app_role;
CREATE INDEX IF NOT EXISTS idx_sal_tenant ON bauth.sig_adsib_lifecycle (tenant_id, event_at DESC);
```

### 3.8 T-357 `bauth.sig_document_policy` — Política de motores por tipo de documento

```sql
CREATE TABLE IF NOT EXISTS bauth.sig_document_policy (
    policy_id                  UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id                  UUID    NULL REFERENCES bauth.idn_tenant(tenant_id),  -- NULL = global
    document_type              TEXT    NOT NULL,
    -- Motor requerido (Ley 164 Art. 82 determina si se necesita ADSIB, Vault, o ambos)
    engine_required            TEXT    NOT NULL CONSTRAINT chk_sdp_eng CHECK (engine_required IN (
                                   'INTERNAL_VAULT',  -- firma electrónica: control interno (SBOS)
                                   'EXTERNAL_ADSIB',  -- firma digital: validez jurídica (Ley 164)
                                   'BOTH'             -- ambos: integridad interna + validez jurídica
                               )),
    legal_basis                TEXT    NOT NULL,   -- referencia legal o norma empresarial
    internal_profile           TEXT    NULL CONSTRAINT chk_sdp_int CHECK (internal_profile IN ('JWS','INT-B','INT-T','INT-LT')),
    external_profile           TEXT    NULL CONSTRAINT chk_sdp_ext CHECK (external_profile IN ('XAdES-BES','EXT-B','EXT-T','EXT-LT','EXT-LTA')),
    min_retention_years        INT     NOT NULL DEFAULT 7,
    requires_timestamp         BOOLEAN NOT NULL DEFAULT FALSE,
    requires_blockchain_anchor BOOLEAN NOT NULL DEFAULT FALSE,
    active                     BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id                     TEXT    NOT NULL DEFAULT 'system',
    created_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_sdp_type_tenant UNIQUE (tenant_id, document_type)
);

CREATE INDEX IF NOT EXISTS idx_sdp_active ON bauth.sig_document_policy (document_type) WHERE active = TRUE;

COMMENT ON TABLE bauth.sig_document_policy IS
    'T-357 · Política de motores de firma por tipo de documento. '
    'Ley 164 Bolivia Art. 82: firma digital (ADSIB) = validez jurídica ante el Estado; '
    'firma electrónica (Vault) = control de integridad interno. '
    'BOTH cuando el documento tiene efectos internos Y jurídicos. '
    'engine_required=EXTERNAL_ADSIB aplica a cualquier tenant cuando el documento '
    'lo requiere — no es exclusivo de tenants REGULATED o HIGH_SENSITIVITY.';

-- Seeds orientativos (valores definitivos son decisión HITL D-FD-03):
-- FACTURA_SIN        → EXTERNAL_ADSIB · XAdES-BES · 8 años · timestamp=true
-- CONTRATO_CIVIL     → BOTH · INT-LT + EXT-LT · 10 años · timestamp=true
-- EXPEDIENTE_RRHH    → BOTH · INT-B + EXT-B · 7 años
-- ACTA_DIRECTORIO    → BOTH · INT-LT + EXT-B · 10 años
-- JWT_INTERNAL       → INTERNAL_VAULT · JWS · 0 años (no retener)
-- SAGA_STATE         → INTERNAL_VAULT · JWS · 1 año
-- BINARY_RELEASE     → INTERNAL_VAULT · JWS · 3 años (code signing)
-- AUDIT_EVENT_BATCH  → INTERNAL_VAULT · INT-B · 7 años · anchor=true
```

---

## 4. Sección BLOCKCHAIN D12 — Naming canónico (T-358..T-362)

Las 5 tablas `blk_*` existen en el DDL legacy y están verificadas en VPS.
Esta sección les asigna T-codes canónicos en el schema `bauth`.

### 4.1 T-358 `bauth.blk_anchor` — Anclajes en cadena pública o privada

```sql
CREATE TABLE IF NOT EXISTS bauth.blk_anchor (
    anchor_id    UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    batch_id     UUID    NOT NULL,   -- FK a T-359 blk_merkle_batch
    merkle_root  TEXT    NOT NULL,   -- Keccak-256 del lote (RFC 6962)
    chain        TEXT    NOT NULL CONSTRAINT chk_ba_chain CHECK (chain IN (
                     'ARBITRUM_ONE',  -- Forma A: Arbitrum L2 público (evidencia externa)
                     'BESU_QBFT'      -- Forma B: Besu privado QBFT (liquidación financiera)
                 )),
    tx_hash      TEXT    NULL,
    block_number BIGINT  NULL,
    status       TEXT    NOT NULL DEFAULT 'PENDING' CONSTRAINT chk_ba_status CHECK (
                     status IN ('PENDING','SENT','ANCHORED','FAILED')),
    gas_used     BIGINT  NULL,
    error_msg    TEXT    NULL,
    ctx_id       TEXT    NOT NULL DEFAULT 'system',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    anchored_at  TIMESTAMPTZ NULL
);

REVOKE UPDATE, DELETE ON bauth.blk_anchor FROM bauth_app_role;
CREATE INDEX IF NOT EXISTS idx_ba_pending ON bauth.blk_anchor (status, created_at) WHERE status IN ('PENDING','SENT');
```

### 4.2 T-359 `bauth.blk_merkle_batch` — Lote de eventos para árbol Merkle

```sql
CREATE TABLE IF NOT EXISTS bauth.blk_merkle_batch (
    batch_id     UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    merkle_root  TEXT    NULL,             -- calculado por merkle.rs tras cerrar el lote
    event_from   UUID    NOT NULL,         -- primer evento del lote
    event_to     UUID    NOT NULL,         -- último evento del lote
    total_leaves INT     NOT NULL,
    status       TEXT    NOT NULL DEFAULT 'OPEN' CONSTRAINT chk_bmb_status CHECK (
                     status IN ('OPEN','CLOSED','COMPUTING','ANCHORED','FAILED')),
    closed_at    TIMESTAMPTZ NULL,
    ctx_id       TEXT    NOT NULL DEFAULT 'system',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 4.3 T-360 `bauth.blk_merkle_leaf` — Hojas del árbol Merkle

```sql
CREATE TABLE IF NOT EXISTS bauth.blk_merkle_leaf (
    leaf_id      UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    batch_id     UUID    NOT NULL REFERENCES bauth.blk_merkle_batch(batch_id),
    leaf_index   INT     NOT NULL,
    event_id     UUID    NOT NULL,    -- FK lógica al evento de auditoría
    leaf_hash    TEXT    NOT NULL,    -- Keccak-256, domain separation RFC 6962 (0x00||data)
    merkle_proof TEXT[]  NULL         -- proof de inclusión para verificación offline
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_bml_batch_index ON bauth.blk_merkle_leaf (batch_id, leaf_index);
CREATE INDEX        IF NOT EXISTS idx_bml_event       ON bauth.blk_merkle_leaf (event_id);
REVOKE UPDATE, DELETE ON bauth.blk_merkle_leaf FROM bauth_app_role;
```

### 4.4 T-361 `bauth.blk_account` — Cuentas de liquidación Besu QBFT

```sql
CREATE TABLE IF NOT EXISTS bauth.blk_account (
    account_id    UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id     UUID    NOT NULL,
    entity_id     UUID    NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    eth_address   TEXT    NOT NULL UNIQUE,   -- dirección Ethereum en Besu (chainId 1337)
    status        TEXT    NOT NULL DEFAULT 'ACTIVE' CONSTRAINT chk_bac_status CHECK (
                      status IN ('ACTIVE','FROZEN','CLOSED')),
    -- El saldo REAL vive en SettlementEngine.sol on-chain — esto es CACHE de consulta UI
    balance_cache NUMERIC(20,8) NULL,
    cache_at      TIMESTAMPTZ NULL,
    ctx_id        TEXT    NOT NULL DEFAULT 'system',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE bauth.blk_account IS
    'T-361 · Cuentas Besu QBFT (Forma B D12). balance_cache es CACHE — fuente de verdad '
    'es el contrato SettlementEngine.sol (probado en VPS 2026-06-22, bloques #38-42). '
    'Si status=FROZEN, settle() en el contrato REVIERTE (anti-fraude D3).';
```

### 4.5 T-362 `bauth.blk_reconciliation` — Conciliación on-chain ↔ PostgreSQL

```sql
CREATE TABLE IF NOT EXISTS bauth.blk_reconciliation (
    rec_id          UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    account_id      UUID    NOT NULL REFERENCES bauth.blk_account(account_id),
    balance_onchain NUMERIC(20,8) NOT NULL,
    balance_prev    NUMERIC(20,8) NULL,
    delta           NUMERIC(20,8) NOT NULL,
    status          TEXT    NOT NULL CONSTRAINT chk_br_status CHECK (
                        status IN ('OK','DISCREPANCY','CORRECTED')),
    ctx_id          TEXT    NOT NULL DEFAULT 'system',
    verified_at     TIMESTAMPTZ NOT NULL DEFAULT now()
    -- Job cada 15 min: Besu → balanceOf(address) → insert reconciliation row
);
```

---

## 5. Sección FEDERACIÓN / OIDC — S16 (T-365..T-367 principales · T-368..T-374 en A.65.02.05)

### 5.1 T-365 `bauth.fed_client` — Clientes OAuth2/OIDC registrados

```sql
CREATE TABLE IF NOT EXISTS bauth.fed_client (
    client_id         UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id         UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    client_key        TEXT    NOT NULL UNIQUE,   -- client_id público OAuth2
    name              TEXT    NOT NULL,
    type              TEXT    NOT NULL CONSTRAINT chk_fc_type CHECK (type IN (
                          'CONFIDENTIAL',  -- server-side, client_secret en Vault
                          'PUBLIC',        -- SPA/mobile, solo PKCE
                          'M2M'            -- client_credentials, machine-to-machine
                      )),
    redirect_uris     TEXT[]  NOT NULL DEFAULT '{}',
    allowed_scopes    TEXT[]  NOT NULL DEFAULT '{}',
    grant_types       TEXT[]  NOT NULL DEFAULT '{}',
    -- Seguridad
    pkce_required     BOOLEAN NOT NULL DEFAULT TRUE,
    dpop_required     BOOLEAN NOT NULL DEFAULT FALSE,   -- RFC 9449
    mtls_required     BOOLEAN NOT NULL DEFAULT FALSE,   -- RFC 8705
    fapi_profile      TEXT    NULL CONSTRAINT chk_fc_fapi CHECK (fapi_profile IN ('BASELINE','ADVANCED','FAPI2')),
    -- Tokens
    at_ttl_seconds    INT     NOT NULL DEFAULT 3600,
    rt_ttl_seconds    INT     NULL,
    id_token_ttl      INT     NOT NULL DEFAULT 600,
    status            TEXT    NOT NULL DEFAULT 'ACTIVE' CONSTRAINT chk_fc_status CHECK (
                          status IN ('ACTIVE','SUSPENDED','REVOKED')),
    vault_secret_path TEXT    NULL,   -- ruta Vault del client_secret (solo CONFIDENTIAL)
    ctx_id            TEXT    NOT NULL DEFAULT 'system',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fc_client_key ON bauth.fed_client (client_key);
COMMENT ON TABLE bauth.fed_client IS 'T-365 · Clientes OAuth2/OIDC (RFC 6749). client_secret NUNCA aquí — en Vault.';
```

### 5.2 T-366 `bauth.fed_provider_ext` — Proveedores de identidad externos federados

```sql
CREATE TABLE IF NOT EXISTS bauth.fed_provider_ext (
    provider_id       UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id         UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    name              TEXT    NOT NULL,
    protocol          TEXT    NOT NULL CONSTRAINT chk_fpe_proto CHECK (protocol IN (
                          'OIDC','SAML2','GOOGLE','GITHUB','LINKEDIN','MICROSOFT_ENTRA')),
    -- OIDC
    issuer_url        TEXT    NULL,
    discovery_url     TEXT    NULL,
    jwks_uri          TEXT    NULL,
    -- SAML2
    metadata_url      TEXT    NULL,
    entity_id         TEXT    NULL,
    sso_url           TEXT    NULL,
    -- Mapeo de atributos del IdP externo → atributos D00 bAuth
    attr_mapping      JSONB   NOT NULL DEFAULT '{}',
    -- Federation Assurance Level (NIST SP 800-63-4 §6)
    fal               TEXT    NOT NULL DEFAULT 'FAL1' CONSTRAINT chk_fpe_fal CHECK (fal IN ('FAL1','FAL2','FAL3')),
    status            TEXT    NOT NULL DEFAULT 'ACTIVE',
    vault_secret_path TEXT    NULL,
    ctx_id            TEXT    NOT NULL DEFAULT 'system',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 5.3 T-367 `bauth.fed_token_issued` — Tokens emitidos (hash SHA-256, nunca el valor)

```sql
CREATE TABLE IF NOT EXISTS bauth.fed_token_issued (
    token_id          UUID         NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id         UUID         NOT NULL,
    client_id         UUID         NOT NULL REFERENCES bauth.fed_client(client_id),
    user_id           UUID         NULL REFERENCES bauth.idn_user(user_id),
    type              TEXT         NOT NULL CONSTRAINT chk_fti_type CHECK (type IN (
                                       'ACCESS_TOKEN','REFRESH_TOKEN','ID_TOKEN','EXCHANGE_TOKEN')),
    token_hash        TEXT         NOT NULL UNIQUE,   -- SHA-256 — NUNCA el valor en claro
    scopes            TEXT[]       NOT NULL DEFAULT '{}',
    loa_at_issuance   TEXT         NULL CONSTRAINT chk_fti_loa CHECK (loa_at_issuance IN ('AAL1','AAL2','AAL3')),
    -- DPoP binding (RFC 9449) — previene token theft
    dpop_jkt          TEXT         NULL,   -- JWK Thumbprint de la clave DPoP
    -- mTLS binding (RFC 8705) — previene token replay en otro cliente
    mtls_cert_fp      TEXT         NULL,   -- SHA-256 del cert cliente mTLS
    -- Ciclo de vida
    issued_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    expires_at        TIMESTAMPTZ  NOT NULL,
    revoked_at        TIMESTAMPTZ  NULL,
    revocation_reason TEXT         NULL,
    session_id        UUID         NULL,
    ctx_id            TEXT         NOT NULL DEFAULT 'system'
) PARTITION BY RANGE (issued_at);

CREATE TABLE IF NOT EXISTS bauth.fed_token_issued_2026_07
    PARTITION OF bauth.fed_token_issued
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bauth.fed_token_issued_2026_08
    PARTITION OF bauth.fed_token_issued
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

REVOKE UPDATE (token_hash) ON bauth.fed_token_issued FROM bauth_app_role;
CREATE INDEX IF NOT EXISTS idx_fti_hash    ON bauth.fed_token_issued (token_hash);
CREATE INDEX IF NOT EXISTS idx_fti_expires ON bauth.fed_token_issued (expires_at) WHERE revoked_at IS NULL;

COMMENT ON TABLE bauth.fed_token_issued IS
    'T-367 · Tokens emitidos: SHA-256 solamente — NUNCA el valor en claro. '
    'Particionado por mes. DPoP (RFC 9449) y mTLS (RFC 8705) previenen explotación '
    'de tokens robados. Decisión HITL D-OI-01: PG vs Redis.';
```

**T-368..T-374:** desarrolladas en documento separado `A.65.02.05_PROPUESTA-OIDC-COMPLETO`.

---

## 6. Sección BILLETERA DIGITAL — S17 (T-380..T-383)

### 6.1 T-380 `bauth.wallet` — Contenedor de billetera por entidad

```sql
CREATE TABLE IF NOT EXISTS bauth.wallet (
    wallet_id        UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id        UUID    NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    entity_id        UUID    NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    -- DID de la billetera (W3C DID Core 1.0)
    did              TEXT    NOT NULL UNIQUE,   -- did:sbos:{tenant_id}:{entity_id}
    status           TEXT    NOT NULL DEFAULT 'ACTIVE' CONSTRAINT chk_w_status CHECK (
                         status IN ('ACTIVE','SUSPENDED','REVOKED','ARCHIVED')),
    -- Backup y portabilidad
    backup_enabled   BOOLEAN NOT NULL DEFAULT FALSE,
    backup_method    TEXT    NULL CONSTRAINT chk_w_backup CHECK (backup_method IN ('NONE','ENCRYPTED_CLOUD')),
    -- Anclaje del DID Document en D12 Forma A
    did_anchored     BOOLEAN NOT NULL DEFAULT FALSE,
    did_tx_hash      TEXT    NULL,
    -- Métricas de uso
    total_presentations  INT NOT NULL DEFAULT 0,
    last_presentation_at TIMESTAMPTZ NULL,
    ctx_id           TEXT    NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_wallet_entity_tenant UNIQUE (tenant_id, entity_id)
);

CREATE INDEX IF NOT EXISTS idx_w_entity ON bauth.wallet (entity_id);
CREATE INDEX IF NOT EXISTS idx_w_did    ON bauth.wallet (did);

COMMENT ON TABLE bauth.wallet IS
    'T-380 · Billetera digital soberana por entidad. Patrón EUDI Wallet (eIDAS 2.0 Art. 5a). '
    'DID propio: did:sbos:{tenant}:{entity} (W3C DID Core 1.0). '
    'DID Document en T-169 (idn_did_document). Custodia gestionada — no autocustodia. '
    'Los ítems de la billetera están en T-381 wallet_item.';
```

### 6.2 T-381 `bauth.wallet_item` — Ítems de la billetera

```sql
CREATE TABLE IF NOT EXISTS bauth.wallet_item (
    item_id       UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    wallet_id     UUID    NOT NULL REFERENCES bauth.wallet(wallet_id) ON DELETE CASCADE,
    tenant_id     UUID    NOT NULL,
    -- Tipo de ítem y tabla fuente (la billetera NO duplica datos — apunta a la fuente)
    type          TEXT    NOT NULL CONSTRAINT chk_wi_type CHECK (type IN (
                      'VC',           -- Verifiable Credential → T-167 idn_identity_vc
                      'FIDO2',        -- Passkey/WebAuthn → T-332 auth_credential_fido2
                      'X509_CERT',    -- Certificado cliente → T-333 auth_credential_x509
                      'DID_DOC',      -- DID Document → T-169 idn_did_document
                      'SIG_CERT',     -- Certificado firma → T-351 sig_certificate
                      'NATIONAL_ID',  -- CI/NIT Bolivia → T-157 + T-165
                      'LICENSE',      -- Licencia profesional (VC emitida)
                      'PHYSICAL_PASS' -- Credencial acceso físico → T-228 (si D02 aprobado)
                  )),
    ref_id        UUID    NOT NULL,     -- PK de la tabla fuente
    display_name  TEXT    NOT NULL,
    status        TEXT    NOT NULL DEFAULT 'ACTIVE' CONSTRAINT chk_wi_status CHECK (
                      status IN ('ACTIVE','EXPIRED','REVOKED','HIDDEN')),
    -- Selective disclosure (SD-JWT VC — draft-ietf-oauth-sd-jwt-vc)
    sd_enabled    BOOLEAN NOT NULL DEFAULT FALSE,
    public_attrs  TEXT[]  NULL,         -- atributos revelados por defecto si sd_enabled=true
    added_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until   TIMESTAMPTZ NULL,
    ctx_id        TEXT    NOT NULL DEFAULT 'system'
);

CREATE INDEX IF NOT EXISTS idx_wi_wallet ON bauth.wallet_item (wallet_id, type);
CREATE INDEX IF NOT EXISTS idx_wi_ref    ON bauth.wallet_item (ref_id);
CREATE INDEX IF NOT EXISTS idx_wi_valid  ON bauth.wallet_item (valid_until) WHERE status = 'ACTIVE';

COMMENT ON TABLE bauth.wallet_item IS
    'T-381 · Ítems de la billetera digital. Apunta a la fuente de verdad por tipo — '
    'NUNCA duplica datos. sd_enabled = selective disclosure (SD-JWT VC). '
    'Fuentes: T-167 (VCs W3C VCDM 2.0) · T-332 (passkeys FIDO2) · T-333 (X.509 mTLS) · '
    'T-169 (DID docs) · T-351 (certs firma ADSIB). '
    'ISO 18013-5 (mDL) se modela como VC con type=LICENSE.';
```

### 6.3 T-382 `bauth.wallet_presentation_log` — Log WORM de presentaciones (OpenID4VP)

```sql
CREATE TABLE IF NOT EXISTS bauth.wallet_presentation_log (
    presentation_id  UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    wallet_id        UUID    NOT NULL REFERENCES bauth.wallet(wallet_id),
    tenant_id        UUID    NOT NULL,
    presented_items  UUID[]  NOT NULL,   -- IDs de wallet_item presentados
    -- Verificador
    verifier_client_id UUID  NULL REFERENCES bauth.fed_client(client_id),
    verifier_name    TEXT    NOT NULL,
    verifier_did     TEXT    NULL,
    -- Protocolo
    protocol         TEXT    NOT NULL CONSTRAINT chk_wpl_proto CHECK (protocol IN (
                         'OPENID4VP',      -- OpenID for Verifiable Presentations
                         'SAML_ASSERTION', -- vía SAML IdP
                         'DIRECT_API'      -- bauth.credential.present
                     )),
    revealed_attrs   TEXT[]  NULL,
    outcome          TEXT    NOT NULL CONSTRAINT chk_wpl_outcome CHECK (
                         outcome IN ('ACCEPTED','REJECTED','PARTIAL')),
    rejection_reason TEXT    NULL,
    ctx_id           TEXT    NOT NULL DEFAULT 'system',
    traceparent      TEXT    NULL,
    presented_at     TIMESTAMPTZ NOT NULL DEFAULT now()
) PARTITION BY RANGE (presented_at);

REVOKE UPDATE, DELETE ON bauth.wallet_presentation_log FROM bauth_app_role;

COMMENT ON TABLE bauth.wallet_presentation_log IS
    'T-382 · WORM. Log de presentaciones VP. '
    'GDPR Art. 7.3: permite auditar qué compartió el sujeto con qué verificador y cuándo. '
    'Anclable en D12 Forma A para cadena de confianza externa verificable.';
```

### 6.4 T-383 `bauth.wallet_issuance_log` — Log WORM de emisión VCs (OpenID4VCI)

```sql
CREATE TABLE IF NOT EXISTS bauth.wallet_issuance_log (
    issuance_id     UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    wallet_id       UUID    NOT NULL REFERENCES bauth.wallet(wallet_id),
    tenant_id       UUID    NOT NULL,
    vc_id           UUID    NOT NULL REFERENCES bauth.idn_identity_vc(vc_id),
    issuer_did      TEXT    NOT NULL,
    credential_type TEXT    NOT NULL,
    protocol        TEXT    NOT NULL CONSTRAINT chk_wil_proto CHECK (protocol IN (
                        'OPENID4VCI',   -- OpenID for Verifiable Credential Issuance
                        'DIRECT_ISSUE', -- emisión directa por admin bAuth
                        'IMPORTED'      -- importada desde IdP externo
                    )),
    outcome         TEXT    NOT NULL CONSTRAINT chk_wil_outcome CHECK (
                        outcome IN ('ISSUED','REJECTED','PENDING')),
    ctx_id          TEXT    NOT NULL DEFAULT 'system',
    issued_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

REVOKE UPDATE, DELETE ON bauth.wallet_issuance_log FROM bauth_app_role;
```

---

## 7. Integridad referencial cruzada

```
bauth.idn_tenant (T-005)
  ├── idn_user (T-320)
  │       ├── idn_user_history (T-321) [WORM hash-chain]
  │       ├── idn_user_recovery (T-322)
  │       └── auth_credential (T-330)
  │               ├── auth_credential_secret (T-331) — Vault transit
  │               ├── auth_credential_fido2  (T-332) — FIDO2/passkey
  │               └── auth_credential_x509   (T-333) — mTLS
  │
  ├── sig_key (T-350) → sig_certificate (T-351) → sig_adsib_lifecycle (T-356) [WORM]
  ├── sig_document_policy (T-357) — política de motores global o por tenant
  │
  ├── wallet (T-380) [FK a idn_identity_entity T-156]
  │       ├── wallet_item (T-381) → [T-167 VC · T-332 FIDO2 · T-333 X509 · T-169 DID · T-351 sig_cert]
  │       ├── wallet_presentation_log (T-382) [WORM] → fed_client (T-365)
  │       └── wallet_issuance_log (T-383) [WORM] → idn_identity_vc (T-167)
  │
  └── fed_client (T-365) → fed_token_issued (T-367) [particionado]
                          → fed_provider_ext (T-366)

sig_operation_log (T-353) [WORM]
  tenant_id → idn_tenant · key_id → sig_key · cert_id → sig_certificate
  document_hash → sig_document_hash (T-354) [WORM] → sig_timestamp (T-355) [WORM]
  merkle_batch_id → blk_merkle_batch (T-359) → blk_anchor (T-358) → Arbitrum / Besu

blk_account (T-361) → blk_reconciliation (T-362) ↔ SettlementEngine.sol (Besu QBFT)
blk_merkle_leaf (T-360) → event_id en privilege_atom_audit (T-170b) [columnas Merkle — D-BK-02]

auth_attempt_log (T-334) [WORM particionado]
  user_id NULL-able (usuarios inexistentes) · method_code sin FK nativa (diseño intencional)
```

---

## 8. Resumen de tablas propuestas

| Sección | T-Code | Tabla | Estado |
|---------|--------|-------|--------|
| S13 USUARIOS | T-320 | `bauth.idn_user` | Propuesta |
| S13 USUARIOS | T-321 | `bauth.idn_user_history` | Propuesta |
| S13 USUARIOS | T-322 | `bauth.idn_user_recovery` | Propuesta |
| S14 AUTENTICACIÓN | T-330 | `bauth.auth_credential` | Propuesta |
| S14 AUTENTICACIÓN | T-331 | `bauth.auth_credential_secret` | Propuesta |
| S14 AUTENTICACIÓN | T-332 | `bauth.auth_credential_fido2` | Propuesta |
| S14 AUTENTICACIÓN | T-333 | `bauth.auth_credential_x509` | Propuesta |
| S14 AUTENTICACIÓN | T-334 | `bauth.auth_attempt_log` | Propuesta |
| S14 AUTENTICACIÓN | T-335 | `bauth.auth_method` | Propuesta |
| S14 AUTENTICACIÓN | T-336 | `bauth.auth_policy` | Propuesta |
| S14 AUTENTICACIÓN | T-337 | `bauth.auth_config` | Propuesta |
| S14 AUTENTICACIÓN | T-338 | `bauth.auth_crypto_algorithm` | Propuesta |
| S14 AUTENTICACIÓN | T-384..386 | `auth_federation_protocol`, `auth_saga_catalog`, `auth_compliance_map` | Bosquejo |
| S15 FIRMA DIGITAL | T-350 | `bauth.sig_key` | Propuesta |
| S15 FIRMA DIGITAL | T-351 | `bauth.sig_certificate` | Propuesta |
| S15 FIRMA DIGITAL | T-352 | `bauth.sig_crl` | Propuesta |
| S15 FIRMA DIGITAL | T-353 | `bauth.sig_operation_log` | Propuesta |
| S15 FIRMA DIGITAL | T-354 | `bauth.sig_document_hash` | Propuesta |
| S15 FIRMA DIGITAL | T-355 | `bauth.sig_timestamp` | Propuesta |
| S15 FIRMA DIGITAL | T-356 | `bauth.sig_adsib_lifecycle` | Propuesta |
| S15 FIRMA DIGITAL | T-357 | `bauth.sig_document_policy` | Propuesta (nueva v2.1.0) |
| D12 BLOCKCHAIN | T-358 | `bauth.blk_anchor` | Naming canónico |
| D12 BLOCKCHAIN | T-359 | `bauth.blk_merkle_batch` | Naming canónico |
| D12 BLOCKCHAIN | T-360 | `bauth.blk_merkle_leaf` | Naming canónico |
| D12 BLOCKCHAIN | T-361 | `bauth.blk_account` | Naming canónico |
| D12 BLOCKCHAIN | T-362 | `bauth.blk_reconciliation` | Naming canónico |
| S16 FEDERACIÓN/OIDC | T-365 | `bauth.fed_client` | Propuesta |
| S16 FEDERACIÓN/OIDC | T-366 | `bauth.fed_provider_ext` | Propuesta |
| S16 FEDERACIÓN/OIDC | T-367 | `bauth.fed_token_issued` | Propuesta |
| S16 FEDERACIÓN/OIDC | T-368..374 | `fed_device_code`, `fed_jwks_key`, `fed_par_request`, `fed_discovery_cfg`, `fed_logout_session`, `fed_token_exchange_log` | → A.65.02.05 |
| S17 BILLETERA DIGITAL | T-380 | `bauth.wallet` | Propuesta |
| S17 BILLETERA DIGITAL | T-381 | `bauth.wallet_item` | Propuesta |
| S17 BILLETERA DIGITAL | T-382 | `bauth.wallet_presentation_log` | Propuesta |
| S17 BILLETERA DIGITAL | T-383 | `bauth.wallet_issuance_log` | Propuesta |

**Total: 38 tablas** (22 propuesta completa · 3 bosquejo · 6 en A.65.02.05 · 5 naming canónico D12 · 1 stub D02)

---

## 9. Decisiones HITL pendientes

| # | Categoría | Decisión | Opciones |
|---|-----------|----------|----------|
| D-US-01 | USUARIOS | ¿1 cuenta o N cuentas por actor por tenant? | A: UNIQUE(tenant,entity) — 1 cuenta (propuesta) · B: N cuentas con diferenciador |
| D-AU-01 | AUTENTICACIÓN | ¿Seeds T-335..T-338 + T-384..T-386 en SQL o YAML bootstrap? | A: Seeds SQL (propuesta) · B: YAML cargado por daemon |
| D-AU-02 | AUTENTICACIÓN | ¿T-336 y T-042 coexisten o se fusionan? | A: Separadas (propuesta) · B: T-042 extendida |
| D-FD-01 | FIRMA DIGITAL | ¿`sig_document_hash` guarda el PEM o solo el hash? | A: Solo hash (propuesta — WORM ligero) · B: PEM completo |
| D-FD-02 | FIRMA DIGITAL | ¿`sig_adsib_lifecycle` tabla separada o eventos en `sig_certificate`? | A: Separada (propuesta) · B: Columnas adicionales |
| D-FD-03 | FIRMA DIGITAL | ¿Seeds de `sig_document_policy` en SQL o solo tabla vacía? | A: Seeds SQL comentados (propuesta) · B: Tabla vacía, seeds via API |
| D-BK-01 | BLOCKCHAIN | ¿Las 5 blk_* migran del DDL legacy o se crean desde cero? | A: Migrar con naming canónico · B: Crear con INSERT SELECT |
| D-BK-02 | BLOCKCHAIN | ¿`privilege_atom_audit` ya tiene columnas Merkle en VPS? | Verificar: `\d bauth.privilege_atom_audit` en SBOSDB |
| D-OI-01 | OIDC | ¿`fed_token_issued` hash en PG o referencia Redis? | A: PG hash (trazabilidad — propuesta) · B: Redis (performance), bloqueado H-019 |
| D-WL-01 | BILLETERA | ¿Billetera financiera D3 va en S17 o en D3 separado? | A: D3 separado (propuesta — SRP) · B: Extender wallet con balance |
| D-CTX-01 | CTX_PLANE | ¿`is_internal` como prefijo en ctx_id o derivado del tenant? | A: Derivar (propuesta) · B: Prefijo explícito `interno.` |
