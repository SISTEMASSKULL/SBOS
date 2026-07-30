# A.65.02.05 — Propuesta DDL Sección FEDERACIÓN/OIDC Completo
## fed_device_code · fed_jwks_key · fed_par_request · fed_discovery_cfg · fed_logout_session · fed_token_exchange_log · fed_consent

**Versión:** 1.0.0 · **Fecha:** 2026-07-30  
**Estado:** PROPUESTA — pendiente de aprobación HITL para incorporar a DDL.sql y DDL_MANUAL.md  
**Precondición:** A.65.02.04 aprobado (T-365..T-367 ya definidos ahí)  
**Convención de naming:** inglés para identificadores SQL · español para documentación interna (igual que A.65.02.04)

---

## 0. Contexto del OIDC Provider de bAuth

bAuth es el **único OIDC Provider soberano del ecosistema** (ADR-010). Esta sección completa
la implementación del Authorization Server con las tablas de infraestructura necesarias para
cumplir con los RFC y specs relevantes:

| RFC / Spec | Tablas que lo implementan |
|---|---|
| RFC 8628 — Device Authorization Grant | T-368 `fed_device_code` |
| RFC 7517 / OIDC Core — JWKs | T-369 `fed_jwks_key` |
| RFC 9126 — Pushed Authorization Request (PAR) | T-370 `fed_par_request` |
| OIDC Discovery 1.0 — .well-known | T-371 `fed_discovery_cfg` |
| OIDC Session Management + Back-Channel Logout | T-372 `fed_logout_session` |
| RFC 8693 — Token Exchange | T-373 `fed_token_exchange_log` |
| OIDC Core §3.1.3.7 — Consent | T-374 `fed_consent` |

---

## 1. T-368 `bauth.fed_device_code` — Device Authorization Grant (RFC 8628)

Flujo para dispositivos sin browser (TV, IoT, CLI): el dispositivo obtiene un `device_code`
y el usuario autentica en un dispositivo secundario con el `user_code`.

```sql
CREATE TABLE IF NOT EXISTS bauth.fed_device_code (
    device_code_id   UUID         NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id        UUID         NOT NULL,
    client_id        UUID         NOT NULL REFERENCES bauth.fed_client(client_id) ON DELETE CASCADE,
    -- Codes
    device_code_hash TEXT         NOT NULL UNIQUE,  -- SHA-256 del device_code real — NUNCA en claro
    user_code        TEXT         NOT NULL UNIQUE,  -- código de 8 chars que el usuario tipea (en claro — es público)
    -- Configuración del poll
    verification_uri TEXT         NOT NULL,  -- URL donde el usuario ingresa el user_code
    verification_uri_complete TEXT NULL,     -- URI con user_code embebido (para QR)
    interval_seconds INT          NOT NULL DEFAULT 5,   -- segundos entre polls del dispositivo
    -- Scopes solicitados
    scopes           TEXT[]       NOT NULL DEFAULT '{}',
    -- Estado
    status           TEXT         NOT NULL DEFAULT 'PENDING'
                                  CONSTRAINT chk_fdc_status CHECK (status IN (
                                      'PENDING',   -- esperando que el usuario autorice
                                      'AUTHORIZED',-- usuario autorizó — token listo
                                      'DECLINED',  -- usuario rechazó
                                      'EXPIRED'    -- TTL expirado
                                  )),
    user_id          UUID         NULL REFERENCES bauth.idn_user(user_id),  -- llenado al autorizar
    -- Ciclo de vida
    expires_at       TIMESTAMPTZ  NOT NULL,          -- RFC 8628 §3.5: device_code_lifetime
    last_poll_at     TIMESTAMPTZ  NULL,
    poll_count       INT          NOT NULL DEFAULT 0,
    ctx_id           TEXT         NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fdc_user_code   ON bauth.fed_device_code (user_code) WHERE status = 'PENDING';
CREATE INDEX IF NOT EXISTS idx_fdc_expires     ON bauth.fed_device_code (expires_at) WHERE status = 'PENDING';

COMMENT ON TABLE bauth.fed_device_code IS
    'T-368 · Device Authorization Grant (RFC 8628). '
    'device_code almacenado como SHA-256 (el dispositivo lo tiene en claro). '
    'user_code en claro: es un código efímero público que el usuario escribe en la UI. '
    'El job de limpieza archiva filas EXPIRED con más de 24h. '
    'last_poll_at detecta slow-down: si el dispositivo hace poll más rápido que interval_seconds, '
    'responde con error=slow_down (RFC 8628 §3.5).';
```

---

## 2. T-369 `bauth.fed_jwks_key` — JWKs públicos activos por tenant

bAuth expone `/bauth/{tenant_id}/.well-known/jwks.json` — esta tabla es la fuente de verdad
de las claves públicas publicadas para verificación de tokens.

```sql
CREATE TABLE IF NOT EXISTS bauth.fed_jwks_key (
    jwks_key_id   UUID    NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id     UUID    NULL REFERENCES bauth.idn_tenant(tenant_id),  -- NULL = global (todos los tenants)
    kid           TEXT    NOT NULL,   -- Key ID (identificador único en el JWKS)
    key_type      TEXT    NOT NULL CONSTRAINT chk_fjk_kty CHECK (key_type IN (
                              'EC',   -- ECDSA P-256 / P-384
                              'RSA',  -- RSA 2048+ (solo para compat. con clientes legacy)
                              'OKP'   -- Ed25519 (Edwards Curve — principal)
                          )),
    algorithm     TEXT    NOT NULL,   -- 'EdDSA', 'ES256', 'ES384', 'RS256', 'PS256'
    use           TEXT    NOT NULL CONSTRAINT chk_fjk_use CHECK (use IN (
                              'sig',  -- firma de JWTs
                              'enc'   -- cifrado de ID tokens (si se usa JWE)
                          )),
    public_key_jwk JSONB  NOT NULL,  -- clave pública en formato JWK (sin 'd' — NUNCA la privada)
    -- Ciclo de vida
    status        TEXT    NOT NULL DEFAULT 'ACTIVE' CONSTRAINT chk_fjk_status CHECK (
                      status IN ('ACTIVE','DEPRECATED','REVOKED')),
    active_since  TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at    TIMESTAMPTZ NULL,       -- rotación periódica (recomendado cada 90 días para JWT signing)
    -- Vínculo con Vault (donde vive la clave privada)
    vault_key_ref TEXT    NULL,           -- referencia a Vault transit key (sin la clave privada)
    ctx_id        TEXT    NOT NULL DEFAULT 'system',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_fjk_kid_tenant UNIQUE (tenant_id, kid)
);

CREATE INDEX IF NOT EXISTS idx_fjk_active ON bauth.fed_jwks_key (tenant_id, status) WHERE status = 'ACTIVE';

COMMENT ON TABLE bauth.fed_jwks_key IS
    'T-369 · JWKs públicos para verificación de tokens JWT. '
    'public_key_jwk contiene SOLO la parte pública (sin campo "d"). '
    'La clave privada NUNCA sale de Vault — aquí solo se guarda la referencia vault_key_ref. '
    'kid se incluye en el header de todos los JWTs para facilitar la rotación: '
    'el verificador usa el kid para buscar la clave correcta sin invalidar tokens activos. '
    'DEPRECATE → sigue siendo consultable pero no genera nuevos tokens. '
    'REVOKE → fuera del JWKS inmediatamente — todos los tokens con ese kid son inválidos.';
```

---

## 3. T-370 `bauth.fed_par_request` — Pushed Authorization Request (RFC 9126)

PAR mejora la seguridad del flujo de autorización enviando los parámetros directamente al
servidor antes de redirigir al usuario. Previene manipulación de parámetros en la URL.

```sql
CREATE TABLE IF NOT EXISTS bauth.fed_par_request (
    par_id         UUID         NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id      UUID         NOT NULL,
    client_id      UUID         NOT NULL REFERENCES bauth.fed_client(client_id),
    -- request_uri devuelto al cliente (ej: urn:bauth:par:{uuid})
    request_uri    TEXT         NOT NULL UNIQUE,
    -- Payload completo del authorization request
    request_params JSONB        NOT NULL,
    -- response_type, code_challenge, code_challenge_method, scope, redirect_uri, state, nonce, etc.
    -- PKCE
    code_challenge       TEXT   NOT NULL,   -- S256 del code_verifier
    code_challenge_method TEXT  NOT NULL DEFAULT 'S256',
    -- Estado
    status         TEXT         NOT NULL DEFAULT 'PENDING'
                                CONSTRAINT chk_fpar_status CHECK (status IN (
                                    'PENDING',  -- creado, esperando que el cliente lo use en /authorize
                                    'USED',     -- ya fue consumido en /authorize (no se puede reusar)
                                    'EXPIRED'
                                )),
    used_at        TIMESTAMPTZ  NULL,
    expires_at     TIMESTAMPTZ  NOT NULL,   -- RFC 9126 §2.2: TTL de 90 segundos recomendado
    ctx_id         TEXT         NOT NULL DEFAULT 'system',
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fpar_request_uri ON bauth.fed_par_request (request_uri) WHERE status = 'PENDING';
CREATE INDEX IF NOT EXISTS idx_fpar_expires     ON bauth.fed_par_request (expires_at) WHERE status = 'PENDING';

COMMENT ON TABLE bauth.fed_par_request IS
    'T-370 · Pushed Authorization Request (RFC 9126). '
    'El cliente hace POST /par con los parámetros → recibe request_uri → '
    'redirige al usuario a /authorize?request_uri=urn:bauth:par:{id}. '
    'Esto previene que un atacante manipule los parámetros en la URL de redirección. '
    'status=USED tras consumo — la misma request_uri no puede reutilizarse. '
    'TTL recomendado RFC 9126 §2.2: 60-90 segundos.';
```

---

## 4. T-371 `bauth.fed_discovery_cfg` — Discovery por tenant (.well-known/openid-configuration)

Cada tenant tiene su propio Discovery endpoint. Esta tabla es el origen del JSON que sirve
bAuth en `GET /bauth/{tenant_id}/.well-known/openid-configuration`.

```sql
CREATE TABLE IF NOT EXISTS bauth.fed_discovery_cfg (
    discovery_id    UUID         NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id       UUID         NOT NULL UNIQUE REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    -- Configuración del OIDC Provider por tenant
    issuer          TEXT         NOT NULL,   -- URL base del issuer (ej: https://bauth.sbos.bo/t/{tenant_id})
    -- Endpoints publicados
    authorization_endpoint  TEXT NOT NULL,
    token_endpoint          TEXT NOT NULL,
    userinfo_endpoint       TEXT NULL,
    jwks_uri                TEXT NOT NULL,
    registration_endpoint   TEXT NULL,   -- Dynamic Client Registration (RFC 7591)
    introspection_endpoint  TEXT NULL,   -- RFC 7662
    revocation_endpoint     TEXT NULL,   -- RFC 7009
    par_endpoint            TEXT NULL,   -- RFC 9126
    device_authorization_endpoint TEXT NULL,  -- RFC 8628
    -- Capacidades declaradas
    response_types_supported    TEXT[] NOT NULL DEFAULT '{}',
    grant_types_supported       TEXT[] NOT NULL DEFAULT '{}',
    scopes_supported            TEXT[] NOT NULL DEFAULT '{}',
    token_endpoint_auth_methods TEXT[] NOT NULL DEFAULT '{}',
    subject_types_supported     TEXT[] NOT NULL DEFAULT '{public}',
    id_token_signing_alg_values TEXT[] NOT NULL DEFAULT '{EdDSA}',
    -- Claims publicados
    claims_supported            TEXT[] NOT NULL DEFAULT '{}',
    claims_parameter_supported  BOOLEAN NOT NULL DEFAULT FALSE,
    request_parameter_supported BOOLEAN NOT NULL DEFAULT FALSE,
    request_uri_parameter_supported BOOLEAN NOT NULL DEFAULT TRUE,  -- PAR
    -- DPoP
    dpop_signing_alg_values_supported TEXT[] NOT NULL DEFAULT '{}',
    -- Última actualización (el config no se regenera en cada request — se cachea aquí)
    last_updated    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    ctx_id          TEXT         NOT NULL DEFAULT 'system'
);

COMMENT ON TABLE bauth.fed_discovery_cfg IS
    'T-371 · Configuración del OIDC Discovery por tenant. '
    'Fuente del JSON que sirve bAuth en /.well-known/openid-configuration. '
    'Se precalcula y cachea aquí — solo se regenera cuando cambia la configuración del tenant. '
    'El daemon escucha CDC (bkernel) en idn_tenant y fed_discovery_cfg para invalidar el cache. '
    'OIDC Discovery 1.0 §3 define todos los campos obligatorios y opcionales.';
```

---

## 5. T-372 `bauth.fed_logout_session` — Logout OIDC (Front-Channel / Back-Channel)

OIDC Session Management y Back-Channel Logout permiten que bAuth notifique a los clientes
cuando una sesión termina, coordinando el logout en múltiples aplicaciones.

```sql
CREATE TABLE IF NOT EXISTS bauth.fed_logout_session (
    logout_id       UUID         NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id       UUID         NOT NULL,
    session_id      UUID         NOT NULL,   -- FK lógica a ses_session_log (T-181)
    user_id         UUID         NOT NULL REFERENCES bauth.idn_user(user_id),
    -- Clientes que deben recibir notificación de logout
    clients_to_notify UUID[]     NOT NULL DEFAULT '{}',   -- fed_client.client_id[]
    -- Estado del proceso de logout
    status          TEXT         NOT NULL DEFAULT 'INITIATED'
                                 CONSTRAINT chk_fls_status CHECK (status IN (
                                     'INITIATED',    -- logout iniciado por el usuario o admin
                                     'NOTIFYING',    -- enviando notificaciones a los clientes
                                     'PARTIAL',      -- algunos clientes notificados, otros fallaron
                                     'COMPLETE',     -- todos los clientes notificados
                                     'FAILED'        -- error crítico, requiere revisión manual
                                 )),
    -- Tipo de logout
    logout_type     TEXT         NOT NULL CONSTRAINT chk_fls_type CHECK (logout_type IN (
                                     'USER_INITIATED',   -- el usuario hizo logout
                                     'ADMIN_FORCED',     -- admin revocó la sesión
                                     'SESSION_EXPIRED',  -- TTL de sesión expiró
                                     'TOKEN_REVOCATION', -- token revocado que invalida la sesión
                                     'SECURITY_EVENT'    -- CAEP/SSE — evento de seguridad
                                 )),
    -- Resultados por cliente (mapa client_id → {status, notified_at, error})
    notification_results JSONB   NOT NULL DEFAULT '{}',
    initiated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ  NULL,
    ctx_id          TEXT         NOT NULL DEFAULT 'system'
);

CREATE INDEX IF NOT EXISTS idx_fls_session ON bauth.fed_logout_session (session_id);
CREATE INDEX IF NOT EXISTS idx_fls_pending ON bauth.fed_logout_session (status) WHERE status IN ('INITIATED','NOTIFYING','PARTIAL');

COMMENT ON TABLE bauth.fed_logout_session IS
    'T-372 · Coordinación de logout OIDC multi-cliente. '
    'Back-Channel Logout (OIDC BL spec §2): bAuth hace POST a logout_uri de cada cliente '
    'con un logout_token firmado. notification_results registra el estado de cada POST. '
    'Front-Channel Logout: se maneja via redireccionamiento — sin estado aquí. '
    'CAEP (Continuous Access Evaluation Protocol) usa logout_type=SECURITY_EVENT para '
    'propagar revocación por evento de seguridad a todos los RP del tenant.';
```

---

## 6. T-373 `bauth.fed_token_exchange_log` — Token Exchange (RFC 8693)

Token Exchange permite intercambiar un token existente por otro con diferentes claims, scope,
o subject. Usado para impersonación delegada, narrowing de scopes y federación de identidad.

```sql
CREATE TABLE IF NOT EXISTS bauth.fed_token_exchange_log (
    exchange_id         UUID         NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id           UUID         NOT NULL,
    client_id           UUID         NOT NULL REFERENCES bauth.fed_client(client_id),
    -- Token sujeto del exchange (el que se intercambia)
    subject_token_hash  TEXT         NOT NULL,    -- SHA-256 del subject_token
    subject_token_type  TEXT         NOT NULL CONSTRAINT chk_fte_stt CHECK (subject_token_type IN (
                                          'ACCESS_TOKEN', 'REFRESH_TOKEN', 'ID_TOKEN',
                                          'JWT',          -- JWT genérico
                                          'SAML2'         -- aserción SAML 2.0
                                      )),
    -- Token actor (para delegación — RFC 8693 §2.1 actor claim)
    actor_token_hash    TEXT         NULL,
    actor_token_type    TEXT         NULL,
    -- Qué se solicitó
    requested_token_type TEXT        NOT NULL CONSTRAINT chk_fte_rtt CHECK (requested_token_type IN (
                                          'ACCESS_TOKEN','REFRESH_TOKEN','ID_TOKEN','JWT','SAML2'
                                      )),
    requested_scopes    TEXT[]       NOT NULL DEFAULT '{}',
    -- Token resultante
    issued_token_hash   TEXT         NULL,         -- SHA-256 del token emitido (NULL si falló)
    -- Tipo de exchange
    exchange_type       TEXT         NOT NULL CONSTRAINT chk_fte_type CHECK (exchange_type IN (
                                          'DELEGATION',       -- actor actúa en nombre del subject
                                          'IMPERSONATION',    -- actor se convierte en subject (con restricciones)
                                          'SCOPE_NARROWING',  -- reducir scopes (sin delegación)
                                          'FEDERATION'        -- token de IdP externo → token interno bAuth
                                      )),
    -- Resultado
    outcome             TEXT         NOT NULL CONSTRAINT chk_fte_outcome CHECK (outcome IN (
                                          'ISSUED', 'DENIED', 'ERROR'
                                      )),
    deny_reason         TEXT         NULL,
    -- Context Plane
    ctx_id              TEXT         NOT NULL DEFAULT 'system',
    traceparent         TEXT         NULL,
    exchanged_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

REVOKE UPDATE, DELETE ON bauth.fed_token_exchange_log FROM bauth_app_role;
CREATE INDEX IF NOT EXISTS idx_fte_subject ON bauth.fed_token_exchange_log (subject_token_hash);
CREATE INDEX IF NOT EXISTS idx_fte_tenant  ON bauth.fed_token_exchange_log (tenant_id, exchanged_at DESC);

COMMENT ON TABLE bauth.fed_token_exchange_log IS
    'T-373 · WORM. Log de Token Exchange (RFC 8693). '
    'Casos de uso: '
    '(1) Microservicio A delega a microservicio B usando el token del usuario (DELEGATION). '
    '(2) Admin impersona a usuario para soporte (IMPERSONATION — requiere átomo especial D14). '
    '(3) Token externo (SAML, Google OIDC) → token interno bAuth (FEDERATION). '
    '(4) Narrowing de scopes para principio de menor privilegio (SCOPE_NARROWING). '
    'Los hashes de los tokens activos se cruzan contra fed_token_issued (T-367).';
```

---

## 7. T-374 `bauth.fed_consent` — Consentimiento del usuario por cliente y scopes

Cuando un usuario autoriza por primera vez a una aplicación, da su consentimiento a los scopes
solicitados. Esta tabla persiste ese consentimiento para no mostrar el prompt en cada login.

```sql
CREATE TABLE IF NOT EXISTS bauth.fed_consent (
    consent_id      UUID         NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id       UUID         NOT NULL,
    user_id         UUID         NOT NULL REFERENCES bauth.idn_user(user_id) ON DELETE CASCADE,
    client_id       UUID         NOT NULL REFERENCES bauth.fed_client(client_id) ON DELETE CASCADE,
    -- Scopes consentidos
    granted_scopes  TEXT[]       NOT NULL DEFAULT '{}',
    denied_scopes   TEXT[]       NOT NULL DEFAULT '{}',
    -- Recuerdos de consentimiento (GDPR Art. 7: el consentimiento debe ser registrado y revocable)
    consent_version INT          NOT NULL DEFAULT 1,   -- incrementa si el cliente cambia sus scopes
    -- Estado
    status          TEXT         NOT NULL DEFAULT 'ACTIVE'
                                 CONSTRAINT chk_fco_status CHECK (status IN (
                                     'ACTIVE',   -- consentimiento vigente
                                     'REVOKED',  -- revocado por el usuario (GDPR Art. 7.3)
                                     'EXPIRED'   -- si el cliente define TTL de consentimiento
                                 )),
    -- Trazabilidad GDPR
    consented_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    revoked_at      TIMESTAMPTZ  NULL,
    revocation_reason TEXT       NULL,
    ip_at_consent   INET         NOT NULL,
    user_agent_at_consent TEXT   NULL,
    -- Temporalidad
    valid_until     TIMESTAMPTZ  NULL,    -- NULL = indefinido hasta revocación
    ctx_id          TEXT         NOT NULL DEFAULT 'system',
    CONSTRAINT uq_fco_user_client UNIQUE (tenant_id, user_id, client_id)
);

CREATE INDEX IF NOT EXISTS idx_fco_user_active ON bauth.fed_consent (user_id, client_id) WHERE status = 'ACTIVE';

COMMENT ON TABLE bauth.fed_consent IS
    'T-374 · Consentimiento del usuario por cliente y scopes. '
    'GDPR Art. 7: consentimiento debe ser libre, específico, informado y unívoco. '
    'GDPR Art. 7.3: el usuario puede revocar su consentimiento en cualquier momento. '
    'Cuando el cliente solicita nuevos scopes no consentidos, se muestra el prompt. '
    'consent_version permite detectar cambios en los scopes del cliente que '
    'requieren un nuevo consentimiento explícito. '
    'revoked_at + revocation_reason = evidencia de ejercicio del derecho de revocación.';
```

---

## 8. Integridad referencial OIDC completo

```
bauth.idn_tenant (T-005)
  └── fed_discovery_cfg (T-371) — configuración por tenant

bauth.fed_client (T-365)
  ├── fed_device_code (T-368) — flujo device auth
  ├── fed_par_request (T-370) — PAR
  ├── fed_logout_session (T-372) → session_id en ses_session_log (T-181)
  ├── fed_token_exchange_log (T-373) [WORM]
  └── fed_consent (T-374)

bauth.idn_user (T-320)
  ├── fed_device_code (T-368) — user_id llenado al autorizar
  ├── fed_logout_session (T-372) — user_id del sujeto del logout
  └── fed_consent (T-374) — UNIQUE(tenant, user, client)

bauth.fed_jwks_key (T-369) — autónoma, sirve al endpoint JWKS
  vault_key_ref → Vault transit (clave privada NUNCA aquí)

bauth.fed_token_issued (T-367) — cross-referenciada por hash:
  fed_token_exchange_log.subject_token_hash ↔ fed_token_issued.token_hash
  fed_token_exchange_log.issued_token_hash  ↔ fed_token_issued.token_hash
```

---

## 9. Resumen de tablas T-368..T-374

| T-Code | Tabla | RFC / Spec | Estado |
|--------|-------|-----------|--------|
| T-368 | `bauth.fed_device_code` | RFC 8628 | Propuesta |
| T-369 | `bauth.fed_jwks_key` | RFC 7517 / OIDC Core | Propuesta |
| T-370 | `bauth.fed_par_request` | RFC 9126 | Propuesta |
| T-371 | `bauth.fed_discovery_cfg` | OIDC Discovery 1.0 | Propuesta |
| T-372 | `bauth.fed_logout_session` | OIDC BL / CAEP | Propuesta |
| T-373 | `bauth.fed_token_exchange_log` | RFC 8693 | Propuesta |
| T-374 | `bauth.fed_consent` | OIDC Core §3.1.2.1 / GDPR Art. 7 | Propuesta |

**Total este documento: 7 tablas** — todas propuesta completa.

---

## 10. Decisiones HITL pendientes (específicas de este documento)

| # | Decisión | Opciones |
|---|----------|----------|
| D-OI-02 | ¿`fed_jwks_key` tiene TTL de 90 días para rotación de JWT signing keys? | A: 90d (propuesta) · B: Configurable en auth_config (T-337) key='jwks.signing.rotation_days' |
| D-OI-03 | ¿`fed_discovery_cfg` se actualiza manualmente o via trigger/CDC? | A: CDC bkernel (propuesta — consistencia automática) · B: API admin explícita |
| D-OI-04 | ¿`fed_consent` tiene TTL o es indefinido hasta revocación? | A: Indefinido (propuesta — GDPR: el usuario decide cuándo revocar) · B: TTL configurable por cliente |
| D-OI-05 | ¿Token Exchange para impersonación (T-373 IMPERSONATION) requiere aprobación doble? | A: Sí — requiere átomo PAM D14 + aprobación secundaria (propuesta — seguridad) · B: Solo átomo D14 |
| D-OI-06 | ¿`fed_logout_session` debe coordinarse con CAEP para eventos de seguridad cross-tenant? | A: Sí — CAEP evento SECURITY_EVENT via bnotify (propuesta) · B: Solo logout local por tenant |
