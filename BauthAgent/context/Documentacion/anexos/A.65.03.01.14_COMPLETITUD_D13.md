# A.65.03.01.14 — Informe de Completitud: D13 Firma Digital Externa

**Versión:** 1.0.0 · **Fecha:** 2026-07-28
**Tipo:** Informe de completitud de dominio
**SSOT bloques:** `bauth.idn_roles_template` — VPS SBOSDB (path `skull.D13.*`)
**Estado de D13:** ❌ SIN IMPLEMENTAR — 0/8 bloques con tablas propias · 7 tablas propuestas (T-440..T-446)

> **Contexto:** bAuth implementa el doble motor de firma: interno (Vault Ed25519) y externo (ADSIB RSA-SHA256 + Ley 164 Bolivia). D13 cubre el motor externo. Ver SSOT: `SBOS-BAUTH-DIGITAL-SIGNATURE-ENGINES.md` v1.0.
> **T-code range:** T-440..T-459 (prefijo `idn_firma_*`)

---

## 1. Estado global de D13

**Dominio:** Firma Digital Externa (PAdES · CAdES · XAdES · ADSIB Bolivia · eIDAS 2.0 · TSA)
**Total bloques:** 8 | **Tablas propias:** 0 | **Átomos:** 0

| Bloque | Slug | Nombre | Estado | T-code propuesto |
|--------|------|--------|--------|-----------------|
| B01 | `signing` | Firma de Documentos | ❌ FALTANTE | T-440 |
| B02 | `certification` | Cadena de Certificación CA | ❌ FALTANTE | T-441 |
| B03 | `timestamping` | Autoridad de Sello de Tiempo (TSA) | ❌ FALTANTE | T-442 |
| B04 | `verification` | Verificación de Firma Digital | ❌ FALTANTE | T-443 |
| B05 | `revocation` | Revocación por OCSP / CRL | ❌ FALTANTE | T-444 |
| B06 | `long_term` | Validación a Largo Plazo (LTV) | ❌ FALTANTE | T-445 |
| B07 | `eudi_wallet` | Cartera de Identidad Digital Europea | ❌ FALTANTE | T-446 |
| B08 | `business_zone` | Registro de Zona de Negocio (Firma Digital) | árbol ✅ | — |

---

## 2. Análisis de bloques

### B01 — `signing` · Firma de Documentos

**Normas:** PAdES EN 319 132 · CAdES EN 319 122 · XAdES EN 319 132 · Ley 164 Bolivia Art. 9

**Propósito:** Registro del ciclo de vida de solicitudes de firma de documentos. El actor solicita que bAuth firme un documento con el certificado ADSIB del tenant. bAuth aplica la firma (PAdES/CAdES/XAdES) y registra la operación.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_firma_solicitud (
    solicitud_id    UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    solicitante_id  UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    tipo_firma      TEXT NOT NULL CONSTRAINT chk_idfs_tipo CHECK (tipo_firma IN
        ('PADES_B','PADES_T','PADES_LT','PADES_LTA','CADES_B','CADES_T','XADES_B','XADES_T')),
    -- Documento
    documento_hash  TEXT NOT NULL,           -- SHA-256 del documento original
    documento_nombre TEXT NOT NULL,
    documento_mime  TEXT NOT NULL DEFAULT 'application/pdf',
    -- Certificado usado
    cert_id         UUID NULL REFERENCES bauth.idn_credencial_certificado(cert_id),
    -- Resultado
    firma_hash      TEXT NULL,               -- SHA-256 del documento firmado
    firma_vault_ref TEXT NULL,               -- referencia en Vault al documento firmado
    estado          TEXT NOT NULL DEFAULT 'PENDIENTE'
        CONSTRAINT chk_idfs_est CHECK (estado IN ('PENDIENTE','FIRMADO','ERROR','REVOCADO')),
    -- Timestamps
    solicitado_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    firmado_at      TIMESTAMPTZ NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system'
);
COMMENT ON TABLE bauth.idn_firma_solicitud IS
  '[T-440] [D13-B01] [PAdES EN 319 132] [CAdES EN 319 122] [Ley 164 Bolivia Art. 9]
   Solicitudes de firma digital. Documento original y firmado referenciados por hash + Vault.';
```

### B02 — `certification` · Cadena de Certificación CA

**Normas:** RFC 5280 §6 · ETSI EN 319 412 · ADSIB-FD-POLT-015 v2.3

**Propósito:** Registro de la cadena de certificación CA que respalda las firmas del tenant (Root CA ADSIB → CA Intermedia → Certificado de firma). La cadena se valida antes de cada firma.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_firma_cadena_ca (
    cadena_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    nombre          TEXT NOT NULL,           -- ej: 'Cadena ADSIB Bolivia 2025'
    root_ca_dn      TEXT NOT NULL,           -- Subject DN de la Root CA
    root_ca_fingerprint TEXT NOT NULL,
    intermedia_ca_dn TEXT NULL,
    intermedia_ca_fingerprint TEXT NULL,
    cert_firma_fingerprint TEXT NOT NULL,    -- fingerprint del cert de firma del tenant
    -- Referencias en Vault
    vault_chain_path TEXT NOT NULL,          -- PEM completo de la cadena
    algoritmo       TEXT NOT NULL DEFAULT 'RSA_SHA256'
        CONSTRAINT chk_idfcca_alg CHECK (algoritmo IN ('RSA_SHA256','ECDSA_SHA256','ECDSA_SHA384','ED25519')),
    estado          TEXT NOT NULL DEFAULT 'ACTIVO'
        CONSTRAINT chk_idfcca_est CHECK (estado IN ('ACTIVO','EXPIRADO','REVOCADO')),
    valid_from      TIMESTAMPTZ NOT NULL,
    valid_until     TIMESTAMPTZ NOT NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_firma_cadena_ca IS
  '[T-441] [D13-B02] [RFC 5280 §6] [ETSI EN 319 412] [ADSIB-FD-POLT-015 v2.3]
   Cadenas de certificación CA del tenant. La cadena completa vive en Vault.';
```

### B03 — `timestamping` · Autoridad de Sello de Tiempo (TSA)

**Normas:** RFC 3161 §2 · ETSI EN 319 421 · Ley 164 Bolivia Art. 20

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_firma_timestamp (
    ts_id           UUID PRIMARY KEY DEFAULT uuidv7(),
    solicitud_id    UUID NOT NULL REFERENCES bauth.idn_firma_solicitud(solicitud_id),
    tsa_url         TEXT NOT NULL,           -- URL de la TSA
    tsa_nombre      TEXT NOT NULL,           -- nombre de la TSA (ADSIB, Certisign, etc.)
    hash_algoritmo  TEXT NOT NULL DEFAULT 'SHA256',
    token_tsr       TEXT NOT NULL,           -- Token TSR en base64 (RFC 3161)
    ts_serial       TEXT NOT NULL,
    ts_generado_at  TIMESTAMPTZ NOT NULL,    -- timestamp de la TSA (en el token)
    verificado_ok   BOOLEAN NOT NULL DEFAULT FALSE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    registrado_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_firma_timestamp IS
  '[T-442] [D13-B03] [RFC 3161 §2] [ETSI EN 319 421] [Ley 164 Bolivia Art. 20]
   Tokens de sello de tiempo (TSA) vinculados a cada firma. Habilita PAdES-T y validación LTV.';
```

### B04 — `verification` · Verificación de Firma Digital

**Normas:** ETSI EN 319 102-1 §5 · RFC 5280

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_firma_verificacion_log (
    log_id          UUID PRIMARY KEY DEFAULT uuidv7(),
    solicitud_id    UUID NULL REFERENCES bauth.idn_firma_solicitud(solicitud_id),
    documento_hash  TEXT NOT NULL,           -- hash del documento verificado
    firma_tipo      TEXT NOT NULL,           -- PAdES, CAdES, XAdES
    verificado_por  UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    resultado       TEXT NOT NULL CONSTRAINT chk_idfvl_res CHECK (resultado IN
        ('VALIDA','INVALIDA','CADUCADA','REVOCADA','CADENA_ROTA','NO_CONFIABLE')),
    detalles        JSONB NULL,              -- información técnica de la verificación
    verificado_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT NOT NULL DEFAULT 'system'
);
COMMENT ON TABLE bauth.idn_firma_verificacion_log IS
  '[T-443] [D13-B04] [ETSI EN 319 102-1 §5] [RFC 5280]
   Log de verificaciones de firma digital con resultado detallado.';
```

### B05 — `revocation` · Revocación por OCSP / CRL

**Normas:** RFC 6960 §2 (OCSP) · RFC 5280 §5 (CRL)

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_firma_revocacion_cache (
    cache_id        UUID PRIMARY KEY DEFAULT uuidv7(),
    cert_fingerprint TEXT NOT NULL,
    issuer_dn       TEXT NOT NULL,
    metodo          TEXT NOT NULL CONSTRAINT chk_idfrc_met CHECK (metodo IN ('OCSP','CRL')),
    estado          TEXT NOT NULL CONSTRAINT chk_idfrc_est CHECK (estado IN ('ACTIVO','REVOCADO','SUSPENDIDO','DESCONOCIDO')),
    ocsp_response   TEXT NULL,              -- respuesta OCSP en base64
    crl_url         TEXT NULL,
    -- Validez del cache
    verificado_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    next_update     TIMESTAMPTZ NULL,       -- cuando vence el cache
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    UNIQUE (cert_fingerprint, issuer_dn, metodo)
);
COMMENT ON TABLE bauth.idn_firma_revocacion_cache IS
  '[T-444] [D13-B05] [RFC 6960 §2 OCSP] [RFC 5280 §5 CRL]
   Cache de estado de revocación OCSP/CRL. Evita llamadas externas en cada verificación.';
```

### B06 — `long_term` · Validación a Largo Plazo (LTV)

**Normas:** ETSI EN 319 102-2 §5.6 · RFC 3161 §3

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_firma_ltv_evidencia (
    ltv_id          UUID PRIMARY KEY DEFAULT uuidv7(),
    solicitud_id    UUID NOT NULL REFERENCES bauth.idn_firma_solicitud(solicitud_id),
    tipo_evidencia  TEXT NOT NULL CONSTRAINT chk_idfltv_tipo CHECK (tipo_evidencia IN
        ('CADENA_CERT','ESTADO_REVOCACION','TIMESTAMP_EXTENDIDO','ARCHIVE_TIMESTAMP')),
    evidencia_hash  TEXT NOT NULL,
    evidencia_data  TEXT NULL,              -- base64 del material de evidencia
    vault_path      TEXT NULL,              -- si es grande, va a Vault
    generado_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT NOT NULL DEFAULT 'system'
);
COMMENT ON TABLE bauth.idn_firma_ltv_evidencia IS
  '[T-445] [D13-B06] [ETSI EN 319 102-2 §5.6] [RFC 3161 §3]
   Evidencias LTV (Long-Term Validation) para verificar firmas cuando los certificados expiran.';
```

### B07 — `eudi_wallet` · Cartera de Identidad Digital Europea (eIDAS 2.0)

**Normas:** UE 2024/1183 §5a · ARF 1.4 (Architecture Reference Framework)

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_firma_eudi_wallet (
    wallet_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    -- Instance attestation
    wallet_instance_id TEXT NOT NULL,       -- EUDIW instance ID
    wallet_provider TEXT NOT NULL,          -- proveedor de la wallet
    wallet_attestation TEXT NULL,           -- attestation JWT en base64
    pid_ref         UUID NULL REFERENCES bauth.idn_identidad_vc(vc_id),  -- PID (Personal ID Document)
    estado          TEXT NOT NULL DEFAULT 'ACTIVO'
        CONSTRAINT chk_idfew_est CHECK (estado IN ('ACTIVO','SUSPENDIDO','REVOCADO')),
    registrado_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    UNIQUE (actor_id, wallet_instance_id)
);
COMMENT ON TABLE bauth.idn_firma_eudi_wallet IS
  '[T-446] [D13-B07] [UE 2024/1183 §5a] [ARF 1.4]
   Wallets EUDI (European Digital Identity Wallet) vinculadas a actores del tenant.
   Soporte eIDAS 2.0 para casos de uso con ciudadanos europeos.';
```

---

## 3. Checklist de completitud

- [ ] `idn_firma_solicitud` (T-440) ❌ PENDIENTE
- [ ] `idn_firma_cadena_ca` (T-441) ❌ PENDIENTE
- [ ] `idn_firma_timestamp` (T-442) ❌ PENDIENTE
- [ ] `idn_firma_verificacion_log` (T-443) ❌ PENDIENTE
- [ ] `idn_firma_revocacion_cache` (T-444) ❌ PENDIENTE
- [ ] `idn_firma_ltv_evidencia` (T-445) ❌ PENDIENTE
- [ ] `idn_firma_eudi_wallet` (T-446) ❌ PENDIENTE
- [ ] Seeds: TSA Bolivia ADSIB + TSA internacional (Certisign)
- [ ] Seeds: cadena CA ADSIB Bolivia (raíz + intermedia + endpoint)
- [ ] Job: renovar cache OCSP/CRL (cada hora para certs activos)
- [ ] Átomos D13: `skull.D13.{signing,certification,timestamping,verification,revocation,long_term,eudi_wallet}.*`

---

## 4. Análisis IAM Enterprise — D13

| Pilar IAM Enterprise | Criterio D13 | Estado |
|---|---|:---:|
| **I AuthEngine** | Firma digital como factor AAL3 | ❌ L0 |
| **VI Standards** | PAdES/CAdES/XAdES ETSI EN 319 | ❌ L0 |
| **VI Standards** | Ley 164 Bolivia / ADSIB | ❌ L0 |
| **VI Standards** | eIDAS 2.0 ARF 1.4 | ❌ L0 |
| **VII Advanced** | LTV (validez post-expiración) | ❌ L0 |

**Gaps:**

| Gap | Prioridad | Acción |
|-----|-----------|--------|
| GAP-D13-01 — Motor de firma sin tablas | 🔴 P1 | CREATE T-440 + T-441 |
| GAP-D13-02 — TSA sin integración | 🔴 P1 | CREATE T-442 + seeds TSA ADSIB |
| GAP-D13-03 — OCSP cache sin tabla | 🟠 P2 | CREATE T-444 |
| GAP-D13-04 — LTV sin evidencias | 🟠 P2 | CREATE T-445 |
| GAP-D13-05 — EUDI wallet | 🟡 P3 | CREATE T-446 |
| GAP-D13-06 — Átomos D13 | 🟡 P3 | INSERT ~25 átomos |

**Veredicto: D13 L0** — el SSOT `SBOS-BAUTH-DIGITAL-SIGNATURE-ENGINES.md` define la arquitectura; las tablas de soporte son todas pendientes. T-440 + T-441 son bloqueantes para Ley 164.

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-28 | Versión inicial. 0/8 bloques con tablas propias. DDL propuesto T-440..T-446. 6 gaps. Madurez D13: L0. |
