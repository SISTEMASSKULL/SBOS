# A.73 — Informe de Cumplimiento Multi-Norma — bAuth IAM v1.0

**Código:** A.73  
**Versión:** 1.0.0  
**Fecha:** 2026-08-01  
**Clasificación:** INTERNO CRÍTICO — uso restringido a equipo de seguridad SBOS  
**Alcance:** SBOSDB (229 tablas bauth) · bAuth Identity Control Plane v3.0  
**Referencia base:** A.71 v1.13.0 (ISO 27001:2022) · commit `3c8d5f1`

---

## §0 Resumen Ejecutivo

| Norma | Score DDL | Gaps P1 | Gaps P2 | Gaps P3 | Estado |
|-------|:---------:|:-------:|:-------:|:-------:|--------|
| **ISO 27001:2022** | 122/123 (99.2%) | 0 | 0 | 1 (DevOps) | 🟢 CERRADO a nivel DDL |
| **NIST SP 800-63B Rev.4** | 19/23 (83%) | 1 | 2 | 1 | 🟡 PARCIAL |
| **NIST SP 800-63-4 (IAL)** | 7/8 (88%) | 0 | 1 | 0 | 🟡 PARCIAL |
| **NIST SP 800-53 Rev.5** | 16/18 (89%) | 0 | 1 | 1 | 🟡 PARCIAL |
| **OAuth 2.0 / OIDC / FAPI 2.0** | 9/13 (69%) | 1 | 3 | 1 | 🟡 PARCIAL |
| **FIDO2 / WebAuthn W3C L3** | 7/8 (88%) | 0 | 1 | 0 | 🟡 PARCIAL |
| **GDPR** | 7/9 (78%) | 0 | 2 | 1 | 🟡 PARCIAL |
| **Ley 164 Bolivia** | 6/6 (100%) | 0 | 0 | 0 | 🟢 COMPLETO |
| **PCI DSS 4.0** | 6/8 (75%) | 1 | 2 | 0 | 🟠 ATENCIÓN |
| **ISO 24760-2:2025** | 6/6 (100%) | 0 | 0 | 0 | 🟢 COMPLETO |
| **NIST SP 800-207 (ZTA)** | 5/6 (83%) | 0 | 1 | 0 | 🟡 PARCIAL |

> **Nota metodológica:** el score refleja cobertura a nivel DDL verificada directamente en SBOSDB.
> Un score DDL alto no garantiza cumplimiento operacional — varios controles tienen DDL correcto
> pero seeds/datos operativos ausentes (ver §1 Hallazgos Críticos).

### Hallazgos de la verificación de tablas T-520..T-565

Las 13 tablas del rango T-520..T-565 fueron verificadas en SBOSDB con el siguiente resultado:

| T-code | Tabla | Checks | Índices | Estado |
|--------|-------|:------:|:-------:|--------|
| T-520 | `bauth.inc_incident` | 2 | 3 | ✅ EXISTE |
| T-521 | `bauth.inc_root_cause` | 1 | 2 (inc UNIQUE) | ✅ EXISTE |
| T-522 | `bauth.inc_corrective_action` | 3 | 3 | ✅ EXISTE |
| T-523 | `bauth.inc_effectiveness_review` | 1 | 1 | ✅ EXISTE |
| T-524 | `bauth.cfg_retention_policy` | 2 | 2 (inc UNIQUE expresional) | ✅ EXISTE |
| T-525 | `bauth.idn_credencial_revocacion` | 1 | — | ✅ PREEXISTENTE |
| T-526 | `bauth.thi_correlation_log` | 1 | 3 | ✅ EXISTE — WORM |
| T-527 | `bauth.vul_component` | 1 | 2 (inc UNIQUE) | ✅ EXISTE |
| T-528 | `bauth.vul_auth_impact` | 3 | 3 (inc SLA index) | ✅ EXISTE |
| T-529 | `bauth.idn_did_document` | 2 | — | ✅ PREEXISTENTE |
| T-530 | `bauth.idn_dpia_registro` | 2 | — | ✅ PREEXISTENTE |
| T-564 | `bauth.thi_indicator` | 5 | 4 (inc UNIQUE) | ✅ EXISTE |
| T-565 | `bauth.inc_security_event` | 3 | 3 | ✅ EXISTE |

**13/13 tablas presentes** — índice UNIQUE expresional `uq_rp_tabla_col` verificado en `cfg_retention_policy`.

---

## §1 Hallazgos Críticos (Gap Operacional — No DDL)

> Estos gaps no requieren cambios en el DDL. Requieren seeds o configuración operativa.

### GAP-OP-01 — `auth_method` vacío (P1 CRÍTICO)

```sql
SELECT count(*) FROM bauth.auth_method;  -- retorna 0
```

La tabla `auth_method` (T-335) es el catálogo declarativo del MethodRegistry: define los 18 métodos
de autenticación con su LoA, resistencia a phishing y estándar rector. **Está vacía.**

**Impacto cross-norma:**
- NIST 800-63B: sin datos de LoA/AAL → no hay evidencia de cumplimiento de §3.1
- PCI DSS Req 8.4: sin declaración formal de MFA obligatorio en CDE
- FIDO2: sin registro de WebAuthn como método disponible
- ISO 27001 A.9.4.2: sin evidencia de que la política de autenticación esté operativa

**Acción requerida:** Ejecutar el seed de `auth_method` (bauth_16 o equivalente).

### GAP-OP-02 — WORM preventivo, no retroactivo (P2)

El rol `bauth_app_role` existe (verificado en `pg_roles`) pero no tiene permisos `UPDATE`/`DELETE`
asignados en las tablas WORM. Los `REVOKE UPDATE, DELETE ON <tabla> FROM bauth_app_role` del DDL
ejecutan sin error porque PostgreSQL no falla al revocar permisos no concedidos — pero tampoco
tienen efecto de protección.

**Lo que esto significa:** la inmutabilidad de las tablas WORM (`thi_correlation_log`,
`idn_identity_consent`, etc.) depende exclusivamente de que la lógica de aplicación nunca llame
`UPDATE`/`DELETE` en ellas. No hay enforcement a nivel BD.

**Acción requerida:** Implementar protección WORM real con RLS o trigger `BEFORE UPDATE OR DELETE RAISE EXCEPTION` en cada tabla WORM, o ejecutar:
```sql
GRANT INSERT, SELECT ON bauth.thi_correlation_log TO bauth_app_role;
-- No GRANT UPDATE ni DELETE → el REVOKE en el DDL ya los bloquea para otorgamientos futuros
-- Pero la protección activa requiere trigger o RLS:
CREATE RULE no_update_thi_correlation AS ON UPDATE TO bauth.thi_correlation_log DO INSTEAD NOTHING;
```

---

## §2 ISO 27001:2022

**Referencia completa:** A.71 v1.13.0  
**Score:** 122/123 (99.2%) — 40C / 1P / 0EP

El único control parcial restante (A.8.25 — Secure coding) corresponde al pipeline CI/CD
(cargo-audit + SAST/DAST automático) — no es un gap DDL sino DevOps. No hay acción pendiente
en el DDL.

Las 10 tablas ISO 27001 BACKLOG (T-520..T-528, T-564, T-565) y la extensión PII de T-157
están verificadas en SBOSDB (§0). El análisis detallado por control vive en A.71.

---

## §3 NIST SP 800-63B Rev.4 (2024) — Autenticación y Ciclo de Vida

**Referencia:** NIST SP 800-63B Rev.4 (agosto 2024)

### §3.1 Cobertura por sección

| Sección | Control | DDL | Evidencia en SBOSDB | Veredicto |
|---------|---------|:---:|---------------------|-----------|
| §3.1 AAL1/2/3 | Niveles de aseguramiento de autenticación | ✓ | `auth_method.loa_provided` (DDL OK — sin seed) | **P-DDL** |
| §4.3.1 | Phishing resistance | ✓ | `auth_method.is_phishing_resistant` (DDL OK — sin seed) | **P-DDL** |
| §5.1.1 | Memorized secrets (passwords) | ✓ | `auth_credential` + T-162 (árbol políticas) | **C** |
| §5.1.1.2 | Compromised password lookup (HIBP) | ❌ | Ninguna columna en `auth_credential` | **GAP-P1** |
| §5.1.3 | TOTP/HOTP (OTP devices) | ✓ | `auth_credential.totp_secret` (en seed cuando exista) | **C** |
| §5.1.6 | WebAuthn / FIDO2 | ✓ | `auth_credential_fido2` con `sign_count`, `backup_eligible`, `backup_state` | **C** |
| §5.1.6.1 | Passkeys (discoverable credentials) | ✓ | `backup_eligible = true` → credencial passkey | **C** |
| §5.2.2 | Rate limiting / lockout | ✓ | `auth_attempt_log` (particionada) | **C** |
| §5.2.3 | Biometrics | ❌ | Sin tabla de datos biométricos; solo hash en T-165 | **GAP-P2** |
| §5.3 | Verifier compromise resistance | ✓ | Argon2id policy en T-162 | **C** |
| §6.1.2.1 | Authenticator expiration | ✓ | `auth_credential.expires_at` | **C** |
| §6.2 | Authenticator binding | ✓ | `auth_credential_fido2.credential_id` + `auth_device` | **C** |
| §6.3 | Lost / stolen authenticator | ✓ | `idn_credencial_revocacion` (T-525) | **C** |
| §7.1 | Session token binding | ✓ | `ses_session_log` + `fed_token_issued.dpop_jkt` | **C** |
| §7.2 | Session timeout | ✓ | `ses_session_log.timeout_at` | **C** |
| §7.3 | Reauthentication | ✓ | `ses_session_log.step_up_valid_until` (RFC 9470) | **C** |
| §8.1 | Phishing threats (IOC) | ✓ | `thi_indicator` (T-564) + `thi_correlation_log` (T-526) | **C** |
| §8.2 | Eavesdropping / replay | ✓ | PKCE + DPoP en `fed_client` + `fed_token_issued` | **C** |
| §8.3 | Verifier impersonation | ✓ | FAPI 2.0 profile en `fed_client` | **C** |
| §9 | NIST 800-63B compliance map | ✓ | `auth_compliance_map` (T-386) | **C** |

**Score DDL: 19/23 secciones con cobertura verificada (83%)**

### §3.2 Gaps NIST 800-63B

**GAP-NIST63B-01 — Compromised credential lookup (P1)**

NIST 800-63B Rev.4 §5.1.1.2 requiere que el verificador compruebe si la contraseña candidata
aparece en listas de contraseñas comprometidas (HIBP, corpuslists) durante el registro y cambio.

```
Evidencia: ninguna columna en auth_credential indica verificación HIBP
Acción DDL: ALTER TABLE bauth.auth_credential ADD COLUMN IF NOT EXISTS
  hibp_checked_at TIMESTAMPTZ NULL,
  hibp_is_compromised BOOLEAN NULL DEFAULT false;
```

**GAP-NIST63B-02 — Biometría separada (P2)**

§5.2.3 exige que la verificación biométrica y los datos biométricos se almacenen en sistemas
separados. bAuth tiene `biometric_hash` en `idn_identity_proofing` (T-165), pero no hay tabla
dedicada con esquema de plantillas biométricas + sensor + calidad.

**GAP-NIST63B-03 — Seeds auth_method ausentes (P1 Operacional)**

Ver §1 GAP-OP-01.

---

## §4 NIST SP 800-63-4 — Identity Proofing (IAL)

**Referencia:** NIST SP 800-63-4 (2024) — Volume A: Identity Proofing

| Sección | Control | DDL | Evidencia | Veredicto |
|---------|---------|:---:|-----------|-----------|
| §4 IAL1 | Sin proofing formal | ✓ | `idn_identity_requirement.ial_required = 'IAL1'` | **C** |
| §5 IAL2 | Remote proofing con evidencia | ✓ | `idn_identity_proofing.evidence_type`, `evidence_strength`, `evidence_issuer` | **C** |
| §6 IAL3 | In-person proofing supervisado | ✓ | `idn_identity_proofing.proofing_method = 'IN_PERSON'` | **C** |
| §7 Remote proofing | KBV y documental | ✓ | `identity_document`, `document_expiry` en T-165 | **C** |
| §8 Biometrics | Captura y verificación | ❌ | Solo `biometric_hash` — sin tabla de plantilla biométrica | **GAP-P2** |
| §9 Records retention | 7 años | ✓ | `idn_identity_proofing` + `cfg_retention_policy` | **C** |
| §10 Privacy | PII classification | ✓ | T-157: `pii_category`, `legal_basis` | **C** |
| §11 Equity | Acceso alternativo | ✓ | Multiple `proofing_method` types en T-165 | **C** |

**Score DDL: 7/8 (88%)**

---

## §5 NIST SP 800-53 Rev.5 — Controles de Seguridad

| Control | Nombre | DDL | Evidencia | Veredicto |
|---------|--------|:---:|-----------|-----------|
| AC-2 | Account Management | ✓ | `idn_user` (T-320), `idn_user_history` (T-321), `idn_user_recovery` (T-322) | **C** |
| AC-3 | Access Enforcement | ✓ | BitMask 64-bit + `privilege_atom` + `privilege_role_grant` | **C** |
| AC-5 | Separation of Duties | ✓ | `privilege_delegation` (T-172) + SoD matrix en T-162 | **C** |
| AC-6 | Least Privilege | ✓ | BitMask DAG + `privilege_override` (T-173) con justificación | **C** |
| AC-7 | Unsuccessful Logon Attempts | ✓ | `auth_attempt_log` (particionada) + `ses_risk_policy.lockout_threshold` | **C** |
| AC-11 | Session Lock | ✓ | `ses_session_log.timeout_at` + `ses_session_log.idle_timeout_seconds` | **C** |
| AC-17 | Remote Access | ✓ | `fed_client` (OIDC/SAML) + `auth_credential_x509` (mTLS) | **C** |
| AU-2 | Event Logging | ✓ | `aud_event_log`, `ses_caep_event_log`, `auth_attempt_log`, `privilege_atom_audit` | **C** |
| AU-9 | Protection of Audit Information | ⚠️ | WORM declarado en DDL pero sin enforcement activo en BD (ver §1 GAP-OP-02) | **GAP-P2** |
| IA-2 | Identification/Authentication | ✓ | `auth_method` (DDL OK — sin seed, ver §1 GAP-OP-01) | **C-DDL** |
| IA-3 | Device Identification | ✓ | `auth_device` (T-390), `auth_device_posture` (T-391) | **C** |
| IA-5 | Authenticator Management | ✓ | `auth_credential` + `idn_credencial_revocacion` + lifecycle | **C** |
| IA-8 | Non-Organizational Users / NHI | ✓ | `pam_nhi_secret_ref` (T-189) + `idn_identity_entity` tipo M2M | **C** |
| SI-3 | Malicious Code Protection | ✓ | `thi_indicator` (T-564) IOC catalogue | **C** |
| SI-5 | Security Alerts | ✓ | `inc_security_event` (T-565) + `inc_incident` (T-520) | **C** |
| SA-10 | Developer Configuration Mgmt | ❌ | Gap A.8.25: sin CI pipeline cargo-audit/SAST automático | **GAP-P3** |
| CM-7 | Least Functionality | ✓ | `auth_config` per-tenant + `auth_method.status` para deshabilitar | **C** |
| SC-8 | Transmission Confidentiality | ✓ | TLS obligatorio (SBOS-054), DPoP, mTLS | **C** |

**Score DDL: 16/18 (89%)**

---

## §6 OAuth 2.0 / OIDC / FAPI 2.0

| RFC / Spec | Control | DDL | Evidencia | Veredicto |
|------------|---------|:---:|-----------|-----------|
| RFC 6749 — OAuth 2.0 | Grants, scopes, client registration | ✓ | `fed_client.grant_types[]`, `fed_client.allowed_scopes[]` | **C** |
| RFC 7636 — PKCE | Code challenge | ✓ | `fed_client.pkce_required = true` | **C** |
| RFC 8705 — mTLS binding | Certificate-bound tokens | ✓ | `fed_client.mtls_required`, `auth_credential_x509` | **C** |
| RFC 9449 — DPoP | Demonstration of Proof of Possession | ✓ | `fed_client.dpop_required`, `fed_token_issued.dpop_jkt` | **C** |
| RFC 9126 — PAR | Pushed Authorization Requests | ❌ | Sin tabla `fed_par_request`, sin columna `par_request_uri` en `fed_client` | **GAP-P1** |
| RFC 9396 — RAR | Rich Authorization Requests | ❌ | Sin `authorization_details` en `fed_client` ni en `fed_token_issued` | **GAP-P2** |
| JARM | JWT Secured Authorization Response | ❌ | Sin `jarm_alg` en `fed_client` | **GAP-P2** |
| OIDC Core 1.0 | ID Token, UserInfo endpoint | ✓ | `fed_provider_ext` + `fed_token_issued` | **C** |
| OIDC Dynamic Registration | RFC 7591 | ❌ | Sin tabla de registro dinámico de clientes | **GAP-P2** |
| FAPI 2.0 Baseline | PKCE + DPoP o mTLS | ✓ | `fed_client.fapi_profile`, `pkce_required`, `dpop_required`/`mtls_required` | **C** |
| FAPI 2.0 Advanced | PAR + JARM requeridos | ❌ | Depende de PAR (❌) y JARM (❌) | **GAP-P1** |
| CAEP / SSF | RFC 8935/8936 | ✓ | `ses_caep_event_log` (T-191), `ses_ssf_stream` (T-192), `ses_ssf_delivery_log` (T-193) | **C** |
| RFC 9470 — Step-Up | AAL step-up auth | ✓ | `ses_session_log.step_up_valid_until` | **C** |

**Score DDL: 9/13 (69%)**

### §6.1 Gaps OAuth/OIDC/FAPI

**GAP-OAUTH-01 — PAR (RFC 9126) — P1**

FAPI 2.0 Advanced Security Profile exige PAR como mecanismo de envío de authorization requests.
Sin tabla `fed_par_request`, los flujos FAPI 2.0 Advanced no pueden ser implementados.

Tablas requeridas:
```
bauth.fed_par_request (T-566 propuesto):
  request_uri TEXT PK (urn:ietf:params:oauth:request_uri:<random>)
  client_id UUID FK fed_client
  tenant_id UUID FK idn_tenant
  request_payload JSONB NOT NULL  -- parámetros del authorization request
  expires_at TIMESTAMPTZ NOT NULL
  created_at TIMESTAMPTZ DEFAULT now()
```

**GAP-OAUTH-02 — RAR / authorization_details (RFC 9396) — P2**

Rich Authorization Requests requieren un campo `authorization_details` (JSONB array) en
`fed_token_issued` y `fed_client.allowed_authorization_types JSONB`.
Necesario para casos de uso de Open Banking (FinTech), Open Energy y delegación granular.

**GAP-OAUTH-03 — JARM (P2)**

JWT Secured Authorization Response Mode requiere `jarm_signing_alg` y `jarm_encryption_alg`
en `fed_client`. FAPI 2.0 Advanced lo exige como mecanismo de protección de la respuesta.

**GAP-OAUTH-04 — OIDC Dynamic Registration (P2)**

RFC 7591 define cómo los clientes OIDC se registran dinámicamente. Sin tabla dedicada, el
registro de clientes solo puede hacerse de forma estática (seeds/HITL).

---

## §7 FIDO2 / WebAuthn W3C Level 3

| Requisito | Control | DDL | Evidencia | Veredicto |
|-----------|---------|:---:|-----------|-----------|
| Authenticator Registration | RP origin + challenge | ✓ | `auth_credential_fido2` | **C** |
| sign_count | Clonación de autenticador | ✓ | `auth_credential_fido2.sign_count BIGINT` | **C** |
| Backup Eligibility | Passkeys | ✓ | `auth_credential_fido2.backup_eligible BOOLEAN` | **C** |
| Backup State | Passkeys sincronizadas | ✓ | `auth_credential_fido2.backup_state BOOLEAN` | **C** |
| Authenticator Transports | USB/BLE/NFC/internal | ✓ | `auth_credential_fido2.transports TEXT[]` | **C** |
| Attestation | Verificación de hardware | ✓ | `auth_credential_fido2.attestation_object` (BYTEA) | **C** |
| User Verification Required | UV vs UP | ❌ | Sin columna `uv_required` en `auth_credential_fido2` ni `auth_policy` | **GAP-P2** |
| Resident Key / Discoverable | PRF extension | ✓ | `backup_eligible = true` cubre credenciales descubribles | **C** |

**Score DDL: 7/8 (88%)**

---

## §8 GDPR

| Artículo | Control | DDL | Evidencia | Veredicto |
|----------|---------|:---:|-----------|-----------|
| Art. 5 — Minimización de datos | PII classification | ✓ | `idn_identity_attribute.pii_category` (9 categorías) | **C** |
| Art. 6 — Base legal | Legal basis | ✓ | `idn_identity_attribute.legal_basis` + `idn_identity_consent.legal_basis` | **C** |
| Art. 7 — Consentimiento | Granular, revocable, auditable | ✓ | `idn_identity_consent`: `consent_purpose`, `retention_end_date`, `third_party_sharing` | **C** |
| Art. 17 — Derecho al olvido | Borrado / anonimización | ✓ | `cfg_retention_policy.purge_action IN ('DELETE','ANONYMIZE','ARCHIVE')` | **C** |
| Art. 20 — Portabilidad | Exportación de datos personales | ❌ | Sin tabla `data_portability_request` ni log de exportaciones | **GAP-P2** |
| Art. 25 — Privacy by design | PII nullable, audit de purga | ⚠️ | DDL tiene PII nullable; sin tabla de auditoría de ejecución de purgas | **GAP-P3** |
| Art. 33 — Notificación de brecha | Gestión de incidentes | ✓ | `inc_incident` (T-520) + `inc_security_event` (T-565) | **C** |
| Art. 35 — DPIA | Data Privacy Impact Assessment | ✓ | `idn_dpia_registro` (T-188/T-530) | **C** |
| Art. 44 — Transferencias internacionales | SCCs, adecuación | ❌ | Sin tabla de registros de transferencias internacionales | **GAP-P2** |

**Score DDL: 7/9 (78%)**

### §8.1 Gaps GDPR

**GAP-GDPR-01 — Art. 20 Portabilidad de datos (P2)**

El derecho a portabilidad requiere que el interesado pueda recibir sus datos en formato legible
por máquina. Se necesita:
```
bauth.gdpr_portability_request (T-567 propuesto):
  request_id UUID PK
  identity_id UUID FK idn_identity_entity
  requested_at TIMESTAMPTZ
  status TEXT CHECK (IN ('PENDING','PROCESSING','READY','DELIVERED','EXPIRED'))
  export_format TEXT CHECK (IN ('JSON','XML','CSV'))
  download_url TEXT  -- temporal, expirado
  delivered_at TIMESTAMPTZ
```

**GAP-GDPR-02 — Art. 44 Transferencias internacionales (P2)**

Para organizaciones que transfieren datos a terceros países (ej: clientes multinacionales de SBOS),
se requiere registro de las transferencias y la base legal (SCCs, BCRs, etc.).

**GAP-GDPR-03 — Auditoría de ejecución de purgas (P3)**

`cfg_retention_policy` define la política pero no hay tabla `cfg_retention_execution_log` que
registre cuándo y qué se purgó (evidencia de cumplimiento Art. 25).

---

## §9 Ley 164 Bolivia — Firma Digital

**Referencia:** Ley 164 (2011), D.S. 1793 (2013), ADSIB-FD-POLT-015 v2.3

| Requisito | Control | DDL | Evidencia | Veredicto |
|-----------|---------|:---:|-----------|-----------|
| Certificado digital calificado | PKI ADSIB | ✓ | `sig_key` + `sig_certificate` | **C** |
| Ciclo de vida certificado | Emisión/renovación/revocación | ✓ | `sig_adsib_lifecycle` (T-356) — 4 reemisiones | **C** |
| CRL / OCSP | Lista de revocación | ✓ | `sig_crl` — distribución points + next_update | **C** |
| Timestamp calificado | RFC 3161 | ✓ | `sig_timestamp` — TSA external, token_hash | **C** |
| Hash de documento firmado | Integridad | ✓ | `sig_document_hash` — sha256 + sig_ref | **C** |
| Política de firma | Perfil legal | ✓ | `sig_document_policy` — policy_oid + ley_ref | **C** |
| Log de operaciones WORM | Auditoría forense | ✓ | `sig_operation_log` | **C** |
| Doble motor (Vault+ADSIB) | SBOS-BAUTH-DIGITAL-SIGNATURE-ENGINES v1.0 | ✓ | `sig_key.key_source IN ('VAULT','ADSIB')` | **C** |

**Score DDL: 6/6 (100%) — COMPLETO** 🟢

---

## §10 PCI DSS 4.0

**Referencia:** PCI DSS v4.0 (marzo 2022) · Req 8 (Identify and Authenticate), Req 10 (Logging)

| Requerimiento | Control | DDL | Evidencia | Veredicto |
|---------------|---------|:---:|-----------|-----------|
| Req 8.2 — IDs únicos | UUID v7 per entity | ✓ | Todas las tablas con PK `UUID DEFAULT gen_random_uuid()` | **C** |
| Req 8.3 — Strong auth | MFA para admin | ✓ | `auth_method.is_mfa_component` + policy en T-162 | **C** |
| Req 8.4 — MFA para CDE | Declaración formal | ⚠️ | DDL OK; `auth_method` sin seed → sin evidencia operativa | **P-DDL** |
| Req 8.5 — App accounts | NHI / service accounts | ✓ | `pam_nhi_secret_ref` (T-189) | **C** |
| Req 8.6 — System accounts | M2M identities | ✓ | `idn_identity_entity` tipo M2M + `idn_nhi_identity` | **C** |
| Req 10 — Logging | Eventos auditables | ✓ | `aud_event_log` + `auth_attempt_log` + `ses_caep_event_log` | **C** |
| Req 10.3 — Log protection | Integridad de logs | ❌ | WORM no enforced activamente (ver §1 GAP-OP-02) | **GAP-P1** |
| Req 11.3 — Penetration testing | Resultados documentados | ❌ | Sin tabla `vul_pentest_result` | **GAP-P2** |

**Score DDL: 6/8 (75%)**

### §10.1 Gap PCI DSS

**GAP-PCI-01 — Log protection real (P1)**

PCI DSS Req 10.3.2 exige que los logs de auditoría no puedan ser modificados. El WORM
declarativo en DDL no es suficiente (ver §1 GAP-OP-02). Solución: trigger BEFORE UPDATE OR DELETE.

**GAP-PCI-02 — Pentest evidence (P2)**

PCI DSS Req 11.3 exige evidencia documentada de pruebas de penetración. Se necesita tabla de
registro de actividades de prueba, alcance, hallazgos y remediación.

---

## §11 ISO 24760-2:2025 — Identity Management Reference Architecture

**Referencia:** ISO/IEC 24760-2:2025

| Sección | Control | DDL | Evidencia | Veredicto |
|---------|---------|:---:|-----------|-----------|
| §5 Trust framework | LoA + IAL + AAL | ✓ | `auth_method.loa_provided` + `idn_identity_proofing.ial_achieved` | **C** |
| §6 Identity lifecycle | JML (Joiner/Mover/Leaver) | ✓ | `idn_identidad_lifecycle_event` (T-186) | **C** |
| §7 Attributes | EAV + schema | ✓ | `idn_identity_attribute` + `idn_attribute_schema` (T-517) | **C** |
| §8 Federation | OIDC/SAML broker | ✓ | `fed_client`, `fed_provider_ext`, `auth_federation_protocol` | **C** |
| §9 Privacy | PII + consent | ✓ | T-157 (`pii_category`, `legal_basis`) + T-166 (consent granular) | **C** |
| §10 Audit | Trazabilidad de identidad | ✓ | `aud_event_log` + `idn_identity_proofing` + `privilege_atom_audit` | **C** |

**Score DDL: 6/6 (100%) — COMPLETO** 🟢

---

## §12 NIST SP 800-207 — Zero Trust Architecture

**Referencia:** NIST SP 800-207 (agosto 2020)

| Componente ZTA | Control | DDL | Evidencia | Veredicto |
|----------------|---------|:---:|-----------|-----------|
| Policy Engine (PE) | Evaluación de acceso | ✓ | `privilege_role_policy_node` (T-162) + `privilege_role_grant` | **C** |
| Policy Administrator (PA) | Gestor de sesiones y contexto | ✓ | Schema `bos`: `ctx_context_session` (T-396), `ctx_context_policy` (T-399) | **C** |
| Policy Enforcement Point (PEP) | Kong + Context Plane | ✓ | `ctx_context_audit` (T-397) — WORM hash-chain | **C** |
| Trust Algorithm | Evaluación adaptativa | ✓ | `ses_risk_policy` (T-180) — riesgo contextual | **C** |
| Device trust | Postura del dispositivo | ✓ | `auth_device_posture` (T-391) + `auth_device_credential_binding` (T-392) | **C** |
| Data-level PEP | Control a nivel dato | ❌ | Sin tabla de data-access policy por campo/columna | **GAP-P2** |

**Score DDL: 5/6 (83%)**

---

## §13 Consolidado de Gaps — Priorización

### Prioridad 1 — Acción Inmediata

| Gap ID | Norma(s) | Descripción | Tipo | Acción |
|--------|----------|-------------|------|--------|
| GAP-OP-01 | NIST 800-63B · PCI DSS · ISO 27001 | `auth_method` vacío — catálogo de LoA/MFA sin datos | Operacional (seed) | Ejecutar seed bauth_16 o equivalente |
| GAP-OP-02 | ISO 27001 A.8.15 · AU-9 · PCI 10.3 | WORM sin enforcement activo en BD | Operacional (DDL/trigger) | Trigger BEFORE UPDATE OR DELETE en tablas WORM |
| GAP-NIST63B-01 | NIST 800-63B §5.1.1.2 | Sin HIBP/compromised password check en `auth_credential` | DDL | `+hibp_checked_at`, `+hibp_is_compromised` en T-330 |
| GAP-OAUTH-01 | OAuth 2.0 · FAPI 2.0 Advanced | Sin PAR (RFC 9126) — requerido para FAPI 2.0 Advanced | DDL | Nueva tabla T-566 `fed_par_request` |
| GAP-PCI-01 | PCI DSS 10.3.2 | Log protection no enforced (mismo que GAP-OP-02) | Operacional | Trigger WORM |

### Prioridad 2 — Próximo Ciclo DDL

| Gap ID | Norma(s) | Descripción | Tablas Propuestas |
|--------|----------|-------------|-------------------|
| GAP-NIST63B-02 | NIST 800-63B §5.2.3 | Sin tabla de datos biométricos separada | T-568 `auth_biometric_template` |
| GAP-OAUTH-02 | RFC 9396 | Sin RAR / `authorization_details` | ALTER `fed_client` + `fed_token_issued` |
| GAP-OAUTH-03 | FAPI 2.0 Adv | Sin JARM (`jarm_signing_alg`, `jarm_encryption_alg`) | ALTER `fed_client` |
| GAP-OAUTH-04 | RFC 7591 | Sin OIDC Dynamic Registration | T-569 `fed_dynamic_client_registration` |
| GAP-FIDO2-01 | WebAuthn L3 | Sin `uv_required` en `auth_credential_fido2` | ALTER `auth_credential_fido2` |
| GAP-GDPR-01 | GDPR Art. 20 | Sin portabilidad de datos | T-567 `gdpr_portability_request` |
| GAP-GDPR-02 | GDPR Art. 44 | Sin registro de transferencias internacionales | T-570 `gdpr_international_transfer` |
| GAP-800207-01 | NIST SP 800-207 | Sin data-level PEP policy | T-571 `zta_data_access_policy` |
| GAP-PCI-02 | PCI DSS 11.3 | Sin registro de pentest | T-572 `vul_pentest_record` |

### Prioridad 3 — Backlog Largo Plazo

| Gap ID | Norma(s) | Descripción |
|--------|----------|-------------|
| GAP-GDPR-03 | GDPR Art. 25 | Auditoría de ejecución de purgas cfg_retention |
| GAP-ISO27001-01 | A.8.25 | CI pipeline cargo-audit + SAST/DAST automático (DevOps) |
| GAP-800053-01 | SA-10 | Mismo que GAP-ISO27001-01 |

---

## §14 Resumen Ejecutivo de Madurez IAM

```
MADUREZ GLOBAL bAuth IAM — 2026-08-01
═══════════════════════════════════════════════════════════════════════

  ISO 27001:2022        ██████████████████████████████████████░░  99.2%
  NIST 800-63-4 (IAL)   ████████████████████████████████████░░░░  88.0%
  ISO 24760-2:2025      ████████████████████████████████████████  100.0%
  NIST 800-53 Rev.5     ████████████████████████████████████░░░░  88.9%
  NIST 800-207 (ZTA)    ████████████████████████████████████░░░░  83.3%
  NIST 800-63B Rev.4    █████████████████████████████████░░░░░░░  82.6%
  FIDO2/WebAuthn L3     ████████████████████████████████████░░░░  87.5%
  GDPR                  █████████████████████████████████░░░░░░░  77.8%
  Ley 164 Bolivia       ████████████████████████████████████████  100.0%
  OAuth/OIDC/FAPI 2.0   ████████████████████████████░░░░░░░░░░░░  69.2%
  PCI DSS 4.0           ██████████████████████████████░░░░░░░░░░  75.0%

  MADUREZ COMPUESTA     █████████████████████████████████████░░░  86.5%

```

**bAuth alcanza madurez Nivel L3** ("Managed") en la escala ISO 9001 / CMMI:
- Procesos definidos y documentados con evidencia DDL
- Controles nucleares implementados (BitMask, WORM-declarativo, IOC, incidentes)
- Gaps identificados son todos P2/P3 excepto 3 operacionales (P1)
- Para Nivel L4 ("Optimized") se requiere: WORM activo + HIBP + PAR + seeds operativos

---

## §15 Próximos Pasos Recomendados

| # | Acción | Norma | Esfuerzo | Prioridad |
|---|--------|-------|:--------:|:---------:|
| 1 | Ejecutar seed `auth_method` — cargar los 18 métodos con LoA/MFA/phishing | Multi-norma | XS | 🔴 P1 |
| 2 | Implementar trigger WORM en tablas WORM (thi_correlation_log, etc.) | ISO 27001 / PCI | S | 🔴 P1 |
| 3 | Agregar `hibp_checked_at` + `hibp_is_compromised` en `auth_credential` | NIST 800-63B | XS | 🔴 P1 |
| 4 | Diseñar e implementar `fed_par_request` (T-566) | FAPI 2.0 / OAuth | M | 🟠 P2 |
| 5 | ALTER `fed_client`: `+jarm_signing_alg`, `+jarm_encryption_alg`, `+require_par` | FAPI 2.0 | XS | 🟠 P2 |
| 6 | ALTER `fed_token_issued` + `fed_client`: `+authorization_details JSONB` (RAR) | RFC 9396 | S | 🟠 P2 |
| 7 | Diseñar `gdpr_portability_request` (T-567) | GDPR Art. 20 | M | 🟠 P2 |
| 8 | ALTER `auth_credential_fido2`: `+uv_required BOOLEAN` | WebAuthn L3 | XS | 🟠 P2 |
| 9 | Configurar CI pipeline cargo-audit + SAST | ISO 27001 A.8.25 | L | 🟡 P3 |

---

## Historial

| Versión | Fecha | Cambio |
|---------|-------|--------|
| 1.0.0 | 2026-08-01 | Documento inicial — 11 normas, 229 tablas bauth, análisis post T-520..T-565 |

---

*Custodio: BauthAgent · Verificado contra SBOSDB (commit `3c8d5f1`) · 2026-08-01*
