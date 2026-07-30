# A.65.03.01.08 — Informe de Completitud: D07 Seguridad de Red

**Versión:** 1.0.0 · **Fecha:** 2026-07-28
**Tipo:** Informe de completitud de dominio
**SSOT bloques:** `bauth.idn_roles_template` — VPS SBOSDB (path `skull.D07.*`)
**Estado de D07:** ❌ SIN IMPLEMENTAR — 0/8 bloques con tablas propias · 7 tablas propuestas (T-320..T-326)

> **T-code range:** T-320..T-339 (prefijo `idn_red_*`)

---

## 1. Estado global de D07

**Dominio:** Seguridad de Red (mTLS, Zero Trust, micro-segmentación, DPoP, rate-limiting)
**Total bloques:** 8 | **Tablas propias:** 0 | **Átomos:** 0

| Bloque | Slug | Nombre | Estado | T-code propuesto |
|--------|------|--------|--------|-----------------|
| B01 | `connection` | Conexión mTLS / CIDR | ❌ FALTANTE | T-320 |
| B02 | `tokens` | Tokens DPoP / PKCE | ❌ FALTANTE | T-321 |
| B03 | `rate` | Limitación de Velocidad | ❌ FALTANTE | T-322 |
| B04 | `posture` | Postura de Red | ❌ FALTANTE | T-323 |
| B05 | `segmentation` | Micro-segmentación | ❌ FALTANTE | T-324 |
| B06 | `inspection` | Inspección DPI / DLP | ❌ FALTANTE | T-325 |
| B07 | `propagation` | Propagación de Contexto | ❌ FALTANTE | T-326 |
| B08 | `business_zone` | Registro de Zona de Negocio (Red) | árbol ✅ | — |

---

## 2. Análisis de bloques

### B01 — `connection` · Conexión mTLS / CIDR

**Normas:** RFC 8705 §2 (mTLS) · NIST SP 800-52 R2 (TLS) · SBOS-050 Port Catalog

**Propósito:** Políticas de conexión de red — qué CIDRs pueden acceder a qué servicios, y si se requiere mTLS para la conexión. Kong PEP aplica estas políticas antes de pasar el request al daemon.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_red_conexion_policy (
    policy_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    nombre          TEXT NOT NULL,
    cidr_permitidos TEXT[] NOT NULL DEFAULT '{}',   -- CIDRs que pueden conectar
    cidr_bloqueados TEXT[] NOT NULL DEFAULT '{}',
    requiere_mtls   BOOLEAN NOT NULL DEFAULT TRUE,
    tls_version_min TEXT NOT NULL DEFAULT 'TLS_1_3'
        CONSTRAINT chk_idrcp_tls CHECK (tls_version_min IN ('TLS_1_2','TLS_1_3')),
    cipher_suite    TEXT[] NULL,                    -- suite de cifrado permitida
    servicio_destino TEXT NOT NULL,                 -- ej: 'bauth.sock', 'kong', 'biedata.sock'
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_red_conexion_policy IS
  '[T-320] [D07-B01] [RFC 8705 §2] [NIST SP 800-52 R2] [SBOS-050]
   Políticas de conexión de red: CIDRs, mTLS, TLS version mínima por servicio.';
```

### B02 — `tokens` · Tokens DPoP / PKCE

**Normas:** RFC 9449 DPoP §4 · RFC 7636 PKCE §4 · OAuth 2.0 RFC 6749

**Propósito:** Catálogo de tokens DPoP activos y sus JWK Thumbprints. Cuando un cliente presenta un token DPoP, bAuth verifica el binding (`dpop_jkt` en el JWT). Esta tabla registra los bindings activos para verificación rápida sin ir a Vault.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_red_dpop_binding (
    binding_id      UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    session_id      UUID NULL REFERENCES bauth.ses_session_log(session_id),
    -- JWK Thumbprint (RFC 7638) de la clave pública DPoP
    dpop_jkt        TEXT NOT NULL,
    -- Algoritmo de la clave (ES256, RS256)
    algoritmo       TEXT NOT NULL DEFAULT 'ES256'
        CONSTRAINT chk_idrd_alg CHECK (algoritmo IN ('ES256','ES384','ES512','RS256','PS256')),
    -- Nonces usados (para prevenir replay)
    nonces_usados   TEXT[] NOT NULL DEFAULT '{}',
    estado          TEXT NOT NULL DEFAULT 'ACTIVO'
        CONSTRAINT chk_idrd_est CHECK (estado IN ('ACTIVO','ROTADO','REVOCADO','EXPIRADO')),
    valid_from      TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until     TIMESTAMPTZ NOT NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    UNIQUE (actor_id, dpop_jkt, estado)
);
COMMENT ON TABLE bauth.idn_red_dpop_binding IS
  '[T-321] [D07-B02] [RFC 9449 DPoP §4] [RFC 7636 PKCE §4]
   Bindings DPoP activos por actor+sesión. Verificación rápida sin Vault.';
```

### B03 — `rate` · Limitación de Velocidad

**Normas:** OWASP API Security 2023 §6 · RFC 6585 §4

**Propósito:** Políticas de rate limiting por actor, rol, endpoint o IP. Kong aplica estas políticas en el PEP. bAuth define las reglas; Kong las consume vía JSON-RPC.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_red_rate_policy (
    policy_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    scope           TEXT NOT NULL DEFAULT 'ACTOR'
        CONSTRAINT chk_idrrp_sc CHECK (scope IN ('ACTOR','ROL','ENDPOINT','IP','TENANT')),
    scope_ref       TEXT NULL,               -- actor_id, role_code, endpoint, CIDR según scope
    endpoint_patron TEXT NULL,               -- regex del endpoint (ej: '^/api/bauth/.*')
    -- Límites
    max_req_seg     INTEGER NULL,            -- requests por segundo
    max_req_min     INTEGER NULL,            -- requests por minuto
    max_req_hora    INTEGER NULL,            -- requests por hora
    -- Acción al exceder
    accion          TEXT NOT NULL DEFAULT 'HTTP_429'
        CONSTRAINT chk_idrrp_acc CHECK (accion IN ('HTTP_429','CAEP_ALERT','BLOQUEO_TEMP')),
    duracion_bloqueo INTERVAL NULL DEFAULT '5 minutes',
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_red_rate_policy IS
  '[T-322] [D07-B03] [OWASP API Security 2023 §6] [RFC 6585 §4]
   Políticas de rate limiting por actor/rol/endpoint/IP. Kong PEP las consume.';
```

### B04 — `posture` · Postura de Red

**Normas:** NIST SP 800-207 §3.3 · CIS Controls v8 §13

**Propósito:** Evaluación de la postura de red del cliente — ¿la conexión viene de una red corporativa, de una VPN, de internet público? Esta información enriquece el score de riesgo del contexto (D08).

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_red_postura_policy (
    policy_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    tipo_red        TEXT NOT NULL DEFAULT 'CORPORATIVA'
        CONSTRAINT chk_idrnp_tipo CHECK (tipo_red IN
            ('CORPORATIVA','VPN','DMZ','INTERNET','ZERO_TRUST_SEGMENT')),
    cidr_rango      TEXT[] NOT NULL DEFAULT '{}',   -- CIDRs que identifican este tipo de red
    score_confianza INTEGER NOT NULL DEFAULT 50      -- 0=no confiable, 100=máxima confianza
        CONSTRAINT chk_idrnp_score CHECK (score_confianza BETWEEN 0 AND 100),
    loa_max         TEXT NULL CONSTRAINT chk_idrnp_loa CHECK (loa_max IS NULL OR loa_max IN ('AAL1','AAL2','AAL3')),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_red_postura_policy IS
  '[T-323] [D07-B04] [NIST SP 800-207 §3.3] [CIS Controls v8 §13]
   Postura de red por CIDR: score de confianza y LoA máxima alcanzable.';
```

### B05 — `segmentation` · Micro-segmentación

**Normas:** NIST SP 800-207 §2.1 · ISO 27001 A.8.22

**Propósito:** Define los segmentos de red y las políticas de flujo entre ellos. Implementa el principio de "nunca confiar, siempre verificar" entre segmentos internos.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_red_segmento (
    segmento_id     UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    nombre          TEXT NOT NULL,
    tipo            TEXT NOT NULL CONSTRAINT chk_idrs_tipo CHECK (tipo IN
        ('PRODUCCION','DESARROLLO','DMZ','BACKUP','MGMT','DATOS')),
    cidr            TEXT NOT NULL,
    nivel_confianza TEXT NOT NULL DEFAULT 'MEDIO'
        CONSTRAINT chk_idrs_confianza CHECK (nivel_confianza IN ('BAJO','MEDIO','ALTO','CRITICO')),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, cidr)
);
COMMENT ON TABLE bauth.idn_red_segmento IS
  '[T-324] [D07-B05] [NIST SP 800-207 §2.1] [ISO 27001 A.8.22]
   Catálogo de segmentos de red con nivel de confianza para micro-segmentación ZTA.';
```

### B06 — `inspection` · Inspección DPI / DLP

**Normas:** NIST SP 800-53 R5 SI-3 · ISO 27001 A.8.12

**Propósito:** Políticas de inspección profunda de paquetes (DPI) y prevención de pérdida de datos (DLP). bAuth registra qué tipos de contenido están prohibidos en requests/responses para actores de ciertos roles.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_red_dlp_policy (
    policy_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    nombre          TEXT NOT NULL,
    tipo_contenido_prohibido TEXT[] NOT NULL DEFAULT '{}',   -- MIME types, patrones regex
    patron_regex    TEXT[] NULL,                             -- patrones de datos prohibidos (ej: CI, tarjeta)
    aplica_a_roles  TEXT[] NULL,                             -- role_codes; NULL = todos
    accion          TEXT NOT NULL DEFAULT 'BLOQUEO'
        CONSTRAINT chk_idrdlp_acc CHECK (accion IN ('BLOQUEO','ALERTA','ENMASCARAR')),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_red_dlp_policy IS
  '[T-325] [D07-B06] [NIST SP 800-53 R5 SI-3] [ISO 27001 A.8.12]
   Políticas DLP: patrones de datos prohibidos en tráfico de red por rol.';
```

### B07 — `propagation` · Propagación de Contexto

**Normas:** W3C Trace Context v2 · OpenTelemetry §5 · SBOS-049

**Propósito:** Registro de la configuración de propagación de contexto (traceparent, tracestate, baggage) entre servicios SBOS. Define qué headers propaga cada daemon y cuáles son obligatorios.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_red_contexto_propagacion (
    config_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    daemon          TEXT NOT NULL,           -- bauth, biedata, bkernel, bsearch, etc.
    headers_obligatorios TEXT[] NOT NULL DEFAULT '{"traceparent","ctx_id"}',
    headers_opcionales   TEXT[] NOT NULL DEFAULT '{"tracestate","baggage"}',
    propaga_hacia   TEXT[] NOT NULL DEFAULT '{}',   -- daemons destino
    version_w3c     TEXT NOT NULL DEFAULT 'v2' CONSTRAINT chk_idncp_ver CHECK (version_w3c IN ('v1','v2')),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (daemon)
);
COMMENT ON TABLE bauth.idn_red_contexto_propagacion IS
  '[T-326] [D07-B07] [W3C Trace Context v2] [OpenTelemetry §5] [SBOS-049]
   Configuración de propagación de ctx_id y W3C Trace Context entre daemons SBOS.';
```

---

## 3. Checklist de completitud

- [ ] `idn_red_conexion_policy` (T-320) ❌ PENDIENTE
- [ ] `idn_red_dpop_binding` (T-321) ❌ PENDIENTE
- [ ] `idn_red_rate_policy` (T-322) ❌ PENDIENTE
- [ ] `idn_red_postura_policy` (T-323) ❌ PENDIENTE
- [ ] `idn_red_segmento` (T-324) ❌ PENDIENTE
- [ ] `idn_red_dlp_policy` (T-325) ❌ PENDIENTE
- [ ] `idn_red_contexto_propagacion` (T-326) ❌ PENDIENTE
- [ ] Seeds: políticas de rate limiting por defecto por tier
- [ ] Seeds: segmentos de red SBOS (producción, desarrollo, mgmt)
- [ ] Seeds: propagación de contexto para los 7 daemons
- [ ] Átomos D07: `skull.D07.{connection,tokens,rate,posture,segmentation,inspection,propagation}.*`

---

## 4. Análisis IAM Enterprise — D07

| Pilar IAM Enterprise | Criterio D07 | Estado |
|---|---|:---:|
| **I AuthEngine** | DPoP binding + mTLS en PDP | ❌ L0 |
| **IV Machine Identity** | mTLS para comunicación daemon-daemon | ❌ L0 |
| **VI Standards** | RFC 9449 DPoP / RFC 8705 mTLS / NIST 800-207 | ❌ L0 |
| **VII Advanced** | Zero Trust Network Access (ZTNA) | ❌ L0 |

**Gaps:**

| Gap | Prioridad | Acción |
|-----|-----------|--------|
| GAP-D07-01 — DPoP binding sin tabla | 🔴 P1 | CREATE T-321 |
| GAP-D07-02 — mTLS sin política | 🔴 P1 | CREATE T-320 |
| GAP-D07-03 — Rate limiting sin reglas | 🟠 P2 | CREATE T-322 |
| GAP-D07-04 — Micro-segmentación ZTA sin datos | 🟠 P2 | CREATE T-324 |
| GAP-D07-05 — Propagación ctx_id sin config | 🟠 P2 | CREATE T-326 + seeds |
| GAP-D07-06 — Átomos D07 | 🟡 P3 | INSERT ~25 átomos |

**Veredicto: D07 L0 global** — DPoP binding (T-321) es crítico para seguridad de tokens; sin él, los tokens no están ligados a clave. T-326 es crítico para SBOS-049.

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-28 | Versión inicial. 7/8 bloques sin implementación. DDL propuesto T-320..T-326. 6 gaps IAM Enterprise. Madurez D07: L0. |
