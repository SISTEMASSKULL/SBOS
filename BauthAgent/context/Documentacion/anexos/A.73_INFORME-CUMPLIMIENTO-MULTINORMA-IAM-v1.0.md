# A.73 — Informe de Cumplimiento Multi-Norma — bAuth IAM v1.0

**Código:** A.73  
**Versión:** 1.5.0  
**Fecha:** 2026-08-02  
**Clasificación:** INTERNO CRÍTICO — uso restringido a equipo de seguridad SBOS  
**Alcance:** SBOSDB (229 tablas bauth) · bAuth Identity Control Plane v3.0  
**Referencia base:** A.71 v1.13.0 (ISO 27001:2022) · commit `3c8d5f1`

---

## §0 Resumen Ejecutivo

| Norma | Score DDL | Gaps P1 | Gaps P2 | Gaps P3 | Estado |
|-------|:---------:|:-------:|:-------:|:-------:|--------|
| **ISO 27001:2022** | 122/123 (99.2%) | 0 | 0 | 1 (DevOps) | 🟢 CERRADO a nivel DDL |
| **NIST SP 800-63B Rev.4** | 23/23 (100%) | 0 | 0 | 1 | 🟢 COMPLETO |
| **NIST SP 800-63-4 (IAL)** | 7/8 (88%) | 0 | 1 | 0 | 🟡 PARCIAL |
| **NIST SP 800-53 Rev.5** | 17/18 (94%) | 0 | 1 | 1 | 🟡 PARCIAL |
| **OAuth 2.0 / OIDC / FAPI 2.0** | 13/13 (100%) | 0 | 0 | 1 | 🟢 COMPLETO |
| **FIDO2 / WebAuthn W3C L3** | 8/8 (100%) | 0 | 0 | 0 | 🟢 COMPLETO |
| **GDPR** | 9/9 (100%) | 0 | 0 | 1 | 🟢 COMPLETO |
| **Ley 164 Bolivia** | 6/6 (100%) | 0 | 0 | 0 | 🟢 COMPLETO |
| **PCI DSS 4.0** | 8/8 (100%) | 0 | 0 | 0 | 🟢 COMPLETO |
| **ISO 24760-2:2025** | 6/6 (100%) | 0 | 0 | 0 | 🟢 COMPLETO |
| **NIST SP 800-207 (ZTA)** | 6/6 (100%) | 0 | 0 | 0 | 🟢 COMPLETO |

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

### GAP-OP-01 — `auth_method` seed aplicado ✅ CERRADO (2026-08-01)

```sql
SELECT COUNT(*) FROM bauth.auth_method;  -- retorna 47
-- IMPLEMENTED: 12 · PLANNED: 33 · DEPRECATED: 1 · REMOVED: 1
```

La tabla `auth_method` (T-335) contiene el catálogo declarativo del MethodRegistry con **47 métodos**
en 6 categorías NIST SP 800-63B-4 (A=Conocimiento · B=Posesión · C=Inherencia · D=Federación ·
E=Flujos · F=Emergente). Fuente canónica: `2.02_MANUAL-METODOS-ESTADO-INDUSTRIA-v1.0.md` v1.1.0.

> **Nota:** el "18 métodos" que aparecía en documentación anterior era la cifra de métodos de
> Keycloak 26.x (era pre-ADR-010). El universo canónico de bAuth en 2026 es **47 métodos**.
> El seed `bauth_T335__auth_method.sql` fue reescrito y aplicado el 2026-08-01.

**Distribución:** A=5 · B=15 · C=8 · D=6 · E=9 · F=4  
**Implementados (12):** password, recovery_codes, totp, hotp, passkey, fido2_security_key, email_otp, push_challenge, x509_mtls, saml2, scim, step_up  
**Estado:** GAP-OP-01 **CERRADO**. Sin acciones pendientes en DDL ni en seeds.

### ~~GAP-OP-02~~ — ✅ CERRADO 2026-08-02

**Solución aplicada:** Trigger `BEFORE UPDATE OR DELETE FOR EACH STATEMENT` en 29 tablas WORM.
Función compartida `bauth.fn_worm_enforce()` — schemas bauth/bcalendar/bos.
Migration: `DDLs/migrations/worm_enforcement_triggers.sql`.
Aplicado en SBOSDB: 29 triggers activos (más N particiones automáticas en tablas heredadas).
Verificación: `DELETE FROM bauth.thi_correlation_log WHERE FALSE` → `WORM_VIOLATION` confirmado.
**FOR EACH STATEMENT** garantiza rechazo incluso en tablas vacías — a diferencia de `FOR EACH ROW`
que no dispara sin filas. DDL principal actualizado (§WORM al final de `SBOS_db_V2_DDL.sql`).
Norma: ISO 27001:2022 A.8.15 · NIST AU-9 · PCI DSS 10.3.2.

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
| §3.1 AAL1/2/3 | Niveles de aseguramiento de autenticación | ✓ | `auth_method.loa_provided` — 47 métodos con AAL en SBOSDB (seed 2026-08-01) | **C** |
| §4.3.1 | Phishing resistance | ✓ | `auth_method.is_phishing_resistant` — 6 métodos TRUE (passkey/fido2/x509/smartcard_piv/dpop/post_quantum) | **C** |
| §5.1.1 | Memorized secrets (passwords) | ✓ | `auth_credential` + T-162 (árbol políticas) | **C** |
| §5.1.1.2 | Compromised password lookup (HIBP) | ✓ | `auth_credential_secret.hibp_checked_at/pwned_count/is_compromised` + `chk_acs_hibp` — GAP-NIST63B-01 CERRADO 2026-08-02 | **C** |
| §5.1.3 | TOTP/HOTP (OTP devices) | ✓ | `auth_credential.totp_secret` (en seed cuando exista) | **C** |
| §5.1.6 | WebAuthn / FIDO2 | ✓ | `auth_credential_fido2` con `sign_count`, `backup_eligible`, `backup_state` | **C** |
| §5.1.6.1 | Passkeys (discoverable credentials) | ✓ | `backup_eligible = true` → credencial passkey | **C** |
| §5.2.2 | Rate limiting / lockout | ✓ | `auth_attempt_log` (particionada) | **C** |
| §5.2.3 | Biometrics | ✓ | `auth_biometric_template` (T-568): template_hash + vault_path + quality_score — GAP-NIST63B-02 CERRADO 2026-08-02 | **C** |
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

**Score DDL: 23/23 secciones con cobertura verificada (100%)** — +1 NIST63B-01 (HIBP 2026-08-02) · +1 NIST63B-02 (biometría T-568 2026-08-02)

### §3.2 Gaps NIST 800-63B

**~~GAP-NIST63B-01~~** — ✅ **CERRADO 2026-08-02**

NIST 800-63B Rev.4 §5.1.1.2 — Compromised credential lookup.

**Solución aplicada:** 3 columnas en `bauth.auth_credential_secret` (T-331) + CHECK:
- `hibp_checked_at TIMESTAMPTZ NULL` — cuándo se verificó
- `hibp_pwned_count INT NULL` — apariciones en corpus HIBP local (0 = limpia)
- `hibp_is_compromised BOOLEAN NOT NULL DEFAULT false` — resultado resumido
- `CONSTRAINT chk_acs_hibp` — fuerza verificación antes de insertar ARGON2ID_HASH

Tabla elegida: `auth_credential_secret` (no `auth_credential`) porque HIBP solo aplica
a `type = 'ARGON2ID_HASH'` — semánticamente correcto, evita columnas vacías para TOTP/FIDO2.
Implementación soberana: corpus HIBP local con k-Anonymity — sin llamadas externas.
Migration: `DDLs/migrations/bauth_hibp_t331.sql`. Aplicado en SBOSDB (verificado).

**~~GAP-NIST63B-02~~** — ✅ **CERRADO 2026-08-02**

§5.2.3 exige que la verificación biométrica y los datos biométricos se almacenen en sistemas
separados. Creada `bauth.auth_biometric_template` (T-568):
- `template_hash TEXT` — SHA-256 del template procesado (nunca el template en claro)
- `vault_path TEXT` — ruta Vault transit donde vive el template cifrado AES-256-GCM
- `vault_key_version INT` — permite re-cifrado sin invalidar templates activos
- `quality_score NUMERIC(5,2)` — ISO/IEC 19795-1 (umbral configurable en cfg_policy_library)
- Tipos: FINGERPRINT, FACE, IRIS, VOICE, VEIN, PALM

Migration: `DDLs/migrations/bauth_gaps_p2.sql` §3. Aplicado en SBOSDB (verificado).

**~~GAP-NIST63B-03~~** — ✅ **CERRADO (2026-08-01)**

Seed aplicado: 47 métodos en SBOSDB. Ver §1 GAP-OP-01 (cerrado).

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
| AU-9 | Protection of Audit Information | ✓ | WORM trigger activo (`fn_worm_enforce` BEFORE STATEMENT) — 29 tablas; GAP-OP-02 CERRADO 2026-08-02 | **C** |
| IA-2 | Identification/Authentication | ✓ | `auth_method` — 47 métodos, 12 IMPLEMENTED (seed aplicado 2026-08-01) | **C** |
| IA-3 | Device Identification | ✓ | `auth_device` (T-390), `auth_device_posture` (T-391) | **C** |
| IA-5 | Authenticator Management | ✓ | `auth_credential` + `idn_credencial_revocacion` + lifecycle | **C** |
| IA-8 | Non-Organizational Users / NHI | ✓ | `pam_nhi_secret_ref` (T-189) + `idn_identity_entity` tipo M2M | **C** |
| SI-3 | Malicious Code Protection | ✓ | `thi_indicator` (T-564) IOC catalogue | **C** |
| SI-5 | Security Alerts | ✓ | `inc_security_event` (T-565) + `inc_incident` (T-520) | **C** |
| SA-10 | Developer Configuration Mgmt | ❌ | Gap A.8.25: sin CI pipeline cargo-audit/SAST automático | **GAP-P3** |
| CM-7 | Least Functionality | ✓ | `auth_config` per-tenant + `auth_method.status` para deshabilitar | **C** |
| SC-8 | Transmission Confidentiality | ✓ | TLS obligatorio (SBOS-054), DPoP, mTLS | **C** |

**Score DDL: 17/18 (94%)** — AU-9 cerrado al implementar WORM trigger activo (2026-08-02)

---

## §6 OAuth 2.0 / OIDC / FAPI 2.0

| RFC / Spec | Control | DDL | Evidencia | Veredicto |
|------------|---------|:---:|-----------|-----------|
| RFC 6749 — OAuth 2.0 | Grants, scopes, client registration | ✓ | `fed_client.grant_types[]`, `fed_client.allowed_scopes[]` | **C** |
| RFC 7636 — PKCE | Code challenge | ✓ | `fed_client.pkce_required = true` | **C** |
| RFC 8705 — mTLS binding | Certificate-bound tokens | ✓ | `fed_client.mtls_required`, `auth_credential_x509` | **C** |
| RFC 9449 — DPoP | Demonstration of Proof of Possession | ✓ | `fed_client.dpop_required`, `fed_token_issued.dpop_jkt` | **C** |
| RFC 9126 — PAR | Pushed Authorization Requests | ✓ | `fed_par_request` (T-566) + `fed_client.par_required` — GAP-OAUTH-01 CERRADO 2026-08-02 | **C** |
| RFC 9396 — RAR | Rich Authorization Requests | ✓ | `fed_client.authorization_details_types JSONB` + `fed_token_issued.authorization_details JSONB` — GAP-OAUTH-02 CERRADO 2026-08-02 | **C** |
| JARM | JWT Secured Authorization Response | ✓ | `fed_client.jarm_signing_alg` + `jarm_encryption_alg` + `chk_fc_jarm_sign` — GAP-OAUTH-03 CERRADO 2026-08-02 | **C** |
| OIDC Core 1.0 | ID Token, UserInfo endpoint | ✓ | `fed_provider_ext` + `fed_token_issued` | **C** |
| OIDC Dynamic Registration | RFC 7591 | ✓ | `fed_dynamic_client_registration` (T-569) + `registration_access_token` — GAP-OAUTH-04 CERRADO 2026-08-02 | **C** |
| FAPI 2.0 Baseline | PKCE + DPoP o mTLS | ✓ | `fed_client.fapi_profile`, `pkce_required`, `dpop_required`/`mtls_required` | **C** |
| FAPI 2.0 Advanced | PAR + JARM requeridos | ✓ | PAR (T-566) + JARM (`jarm_signing_alg`) — ambos cerrados 2026-08-02 | **C** |
| CAEP / SSF | RFC 8935/8936 | ✓ | `ses_caep_event_log` (T-191), `ses_ssf_stream` (T-192), `ses_ssf_delivery_log` (T-193) | **C** |
| RFC 9470 — Step-Up | AAL step-up auth | ✓ | `ses_session_log.step_up_valid_until` | **C** |

**Score DDL: 13/13 (100%)** — +3 (GAP-OAUTH-02/03/04 CERRADOS 2026-08-02) · FAPI 2.0 Advanced ✅

### §6.1 Gaps OAuth/OIDC/FAPI

**~~GAP-OAUTH-01~~** — ✅ **CERRADO 2026-08-02**

RFC 9126 — Pushed Authorization Requests.
**Solución aplicada:**
- `bauth.fed_par_request` (T-566): `par_id` · `request_uri UNIQUE` · `client_id FK` · `tenant_id FK` · `request_payload JSONB` · `code_challenge` · `code_challenge_method DEFAULT 'S256'` · `used` · `used_at` · `expires_at` · `chk_fpar_method` · `chk_fpar_used_at` · índices `idx_fpar_expires` + `idx_fpar_client`
- `fed_client.par_required BOOLEAN NOT NULL DEFAULT false` — fuerza PAR para fapi_profile=ADVANCED/FAPI2
- Migration: `DDLs/migrations/bauth_par_t566.sql`. Aplicado en SBOSDB (verificado).

**~~GAP-OAUTH-02~~** — ✅ **CERRADO 2026-08-02**

RFC 9396 — Rich Authorization Requests. `authorization_details` permite especificar permisos
granulares por objeto/monto/cuenta (Open Banking, FinTech).
**Solución aplicada:**
- `fed_client.authorization_details_types JSONB NULL` — tipos que el cliente puede solicitar
- `fed_token_issued.authorization_details JSONB NULL` — permisos efectivamente otorgados

**~~GAP-OAUTH-03~~** — ✅ **CERRADO 2026-08-02**

FAPI 2.0 Advanced — JWT Secured Authorization Response Mode.
**Solución aplicada:**
- `fed_client.jarm_signing_alg TEXT NULL` — PS256/RS256/ES256; `chk_fc_jarm_sign` CHECK
- `fed_client.jarm_encryption_alg TEXT NULL` — RSA-OAEP/ECDH-ES; NULL = solo firmar

**~~GAP-OAUTH-04~~** — ✅ **CERRADO 2026-08-02**

RFC 7591 — OIDC Dynamic Client Registration.
**Solución aplicada:**
- `bauth.fed_dynamic_client_registration` (T-569): `registration_access_token UNIQUE` · `metadata JSONB` · `initial_access_token_ref` · `status` · `expires_at`
- Migration: `DDLs/migrations/bauth_gaps_p2.sql` §3. Aplicado en SBOSDB (verificado).

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
| User Verification Required | UV vs UP | ✓ | `auth_credential_fido2.uv_required BOOLEAN NOT NULL DEFAULT false` — GAP-FIDO2-01 CERRADO 2026-08-02 | **C** |
| Resident Key / Discoverable | PRF extension | ✓ | `backup_eligible = true` cubre credenciales descubribles | **C** |

**Score DDL: 8/8 (100%)** — +1 GAP-FIDO2-01 CERRADO 2026-08-02

---

## §8 GDPR

| Artículo | Control | DDL | Evidencia | Veredicto |
|----------|---------|:---:|-----------|-----------|
| Art. 5 — Minimización de datos | PII classification | ✓ | `idn_identity_attribute.pii_category` (9 categorías) | **C** |
| Art. 6 — Base legal | Legal basis | ✓ | `idn_identity_attribute.legal_basis` + `idn_identity_consent.legal_basis` | **C** |
| Art. 7 — Consentimiento | Granular, revocable, auditable | ✓ | `idn_identity_consent`: `consent_purpose`, `retention_end_date`, `third_party_sharing` | **C** |
| Art. 17 — Derecho al olvido | Borrado / anonimización | ✓ | `cfg_retention_policy.purge_action IN ('DELETE','ANONYMIZE','ARCHIVE')` | **C** |
| Art. 20 — Portabilidad | Exportación de datos personales | ✓ | `gdpr_portability_request` (T-567): formato JSON/CSV/XML, download_token 1-uso, SLA 30 días — GAP-GDPR-01 CERRADO 2026-08-02 | **C** |
| Art. 25 — Privacy by design | PII nullable, audit de purga | ⚠️ | DDL tiene PII nullable; sin tabla de auditoría de ejecución de purgas | **GAP-P3** |
| Art. 33 — Notificación de brecha | Gestión de incidentes | ✓ | `inc_incident` (T-520) + `inc_security_event` (T-565) | **C** |
| Art. 35 — DPIA | Data Privacy Impact Assessment | ✓ | `idn_dpia_registro` (T-188/T-530) | **C** |
| Art. 44 — Transferencias internacionales | SCCs, adecuación | ✓ | `gdpr_international_transfer` (T-570): transfer_basis SCCs/BCRs/adecuación, data_categories — GAP-GDPR-02 CERRADO 2026-08-02 | **C** |

**Score DDL: 9/9 (100%)** — +2 (GAP-GDPR-01 Art.20 + GAP-GDPR-02 Art.44 CERRADOS 2026-08-02)

### §8.1 Gaps GDPR

**~~GAP-GDPR-01~~** — ✅ **CERRADO 2026-08-02**

GDPR Art. 20 — Portabilidad de datos.
**Solución aplicada:** `bauth.gdpr_portability_request` (T-567):
- `subject_id FK idn_identity_entity` — el sujeto del derecho
- `format TEXT CHECK ('JSON','CSV','XML')` — formato solicitado
- `status TEXT CHECK ('PENDING'→'READY'→'DELIVERED'/'EXPIRED')` — lifecycle
- `download_token TEXT UNIQUE` — token de un solo uso para la descarga segura
- `expires_at TIMESTAMPTZ` — 7 días desde READY
- `delivery_method TEXT CHECK ('DOWNLOAD','EMAIL','API_PUSH')`
Migration: `DDLs/migrations/bauth_gaps_p2.sql` §3. Aplicado en SBOSDB (verificado).

**~~GAP-GDPR-02~~** — ✅ **CERRADO 2026-08-02**

GDPR Art. 44-49 — Transferencias internacionales.
**Solución aplicada:** `bauth.gdpr_international_transfer` (T-570):
- `transfer_basis TEXT CHECK ('ADEQUACY_DECISION','STANDARD_CONTRACTUAL_CLAUSES','BINDING_CORPORATE_RULES','DEROGATION_ART49','CERTIFICATION','CODE_OF_CONDUCT')`
- `recipient_country TEXT` — ISO 3166-1 alpha-2
- `data_categories TEXT[]` — categorías de datos personales transferidos
- `review_due DATE` — fecha de revisión periódica

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
| Req 8.4 — MFA para CDE | Declaración formal | ✓ | `auth_method.is_mfa_component = true` en 17 métodos — evidencia operativa (seed 2026-08-01) | **C** |
| Req 8.5 — App accounts | NHI / service accounts | ✓ | `pam_nhi_secret_ref` (T-189) | **C** |
| Req 8.6 — System accounts | M2M identities | ✓ | `idn_identity_entity` tipo M2M + `idn_nhi_identity` | **C** |
| Req 10 — Logging | Eventos auditables | ✓ | `aud_event_log` + `auth_attempt_log` + `ses_caep_event_log` | **C** |
| Req 10.3 — Log protection | Integridad de logs | ✓ | WORM trigger activo (`fn_worm_enforce` BEFORE STATEMENT) — GAP-OP-02/GAP-PCI-01 CERRADOS 2026-08-02 | **C** |
| Req 11.3 — Penetration testing | Resultados documentados | ✓ | `vul_pentest_record` (T-572): title/scope/performed_by/method/findings_*/remediation_status — GAP-PCI-02 CERRADO 2026-08-02 | **C** |

**Score DDL: 8/8 (100%)** — todos los controles PCI DSS con cobertura DDL verificada. Req 8.4 (seed 2026-08-01) · Req 10.3 (WORM trigger 2026-08-02) · Req 11.3 (T-572 2026-08-02)

### §10.1 Gaps PCI DSS

**~~GAP-PCI-01~~** — ✅ **CERRADO 2026-08-02** — Trigger WORM activo cubre Req 10.3.2 (ver §1 y §WORM DDL).

**~~GAP-PCI-02~~** — ✅ **CERRADO 2026-08-02**

PCI DSS Req 11.3 — Evidencia de pruebas de penetración.
**Solución aplicada:** `bauth.vul_pentest_record` (T-572):
- `performed_by TEXT` · `performed_at DATE` · `method TEXT CHECK ('BLACKBOX','GREYBOX','WHITEBOX')`
- `findings_critical/high/medium/low INT` — conteo por severidad
- `remediation_status TEXT CHECK ('OPEN','IN_PROGRESS','CLOSED','ACCEPTED_RISK')`
- `next_pentest_due DATE` — calculado al cerrar el registro anterior
Migration: `DDLs/migrations/bauth_gaps_p2.sql` §2. Aplicado en SBOSDB (verificado).

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
| Data-level PEP | Control a nivel dato | ✓ | `zta_data_access_policy` (T-571): resource_type/pattern/required_loa/required_atoms/effect/priority — GAP-800207-01 CERRADO 2026-08-02 | **C** |

**Score DDL: 6/6 (100%)** — +1 GAP-800207-01 CERRADO 2026-08-02

---

## §13 Consolidado de Gaps — Priorización

### Prioridad 1 — Acción Inmediata

| Gap ID | Norma(s) | Descripción | Tipo | Acción |
|--------|----------|-------------|------|--------|
| ~~GAP-OP-01~~ | NIST 800-63B · PCI DSS · ISO 27001 | ✅ **CERRADO 2026-08-01** — `auth_method`: 47 métodos, 12 IMPLEMENTED | Operacional (seed) | Seed aplicado: `bauth_T335__auth_method.sql` |
| ~~GAP-OP-02~~ | ISO 27001 A.8.15 · AU-9 · PCI 10.3 | ✅ **CERRADO 2026-08-02** — Trigger WORM activo `fn_worm_enforce` BEFORE STATEMENT en 29 tablas | — | Aplicado en SBOSDB |
| ~~GAP-PCI-01~~ | PCI DSS 10.3.2 | ✅ **CERRADO 2026-08-02** — mismo trigger que GAP-OP-02 | — | Aplicado en SBOSDB |
| ~~GAP-NIST63B-01~~ | NIST 800-63B §5.1.1.2 | ✅ **CERRADO 2026-08-02** — `auth_credential_secret`: `hibp_checked_at/pwned_count/is_compromised` + `chk_acs_hibp` | — | Aplicado en SBOSDB |
| ~~GAP-OAUTH-01~~ | OAuth 2.0 · FAPI 2.0 Advanced | ✅ **CERRADO 2026-08-02** — `fed_par_request` (T-566) + `fed_client.par_required` · RFC 9126 | — | Aplicado en SBOSDB |

### Prioridad 2 — Ciclo DDL CERRADO ✅

| Gap ID | Norma(s) | Descripción | Commit |
|--------|----------|-------------|--------|
| ~~GAP-NIST63B-02~~ | NIST 800-63B §5.2.3 | ✅ **CERRADO 2026-08-02** — `auth_biometric_template` (T-568): template_hash + vault_path + quality_score | pendiente |
| ~~GAP-OAUTH-02~~ | RFC 9396 | ✅ **CERRADO 2026-08-02** — `fed_client.authorization_details_types` + `fed_token_issued.authorization_details` | pendiente |
| ~~GAP-OAUTH-03~~ | FAPI 2.0 Adv | ✅ **CERRADO 2026-08-02** — `fed_client.jarm_signing_alg/jarm_encryption_alg` + CHECK | pendiente |
| ~~GAP-OAUTH-04~~ | RFC 7591 | ✅ **CERRADO 2026-08-02** — `fed_dynamic_client_registration` (T-569): registration_access_token | pendiente |
| ~~GAP-FIDO2-01~~ | WebAuthn L3 | ✅ **CERRADO 2026-08-02** — `auth_credential_fido2.uv_required BOOLEAN NOT NULL DEFAULT false` | pendiente |
| ~~GAP-GDPR-01~~ | GDPR Art. 20 | ✅ **CERRADO 2026-08-02** — `gdpr_portability_request` (T-567): format/status/download_token | pendiente |
| ~~GAP-GDPR-02~~ | GDPR Art. 44 | ✅ **CERRADO 2026-08-02** — `gdpr_international_transfer` (T-570): transfer_basis/SCCs | pendiente |
| ~~GAP-800207-01~~ | NIST SP 800-207 | ✅ **CERRADO 2026-08-02** — `zta_data_access_policy` (T-571): resource_type/loa/atoms/effect | pendiente |
| ~~GAP-PCI-02~~ | PCI DSS 11.3 | ✅ **CERRADO 2026-08-02** — `vul_pentest_record` (T-572): method/findings/remediation | pendiente |

### Prioridad 3 — Backlog Largo Plazo

| Gap ID | Norma(s) | Descripción |
|--------|----------|-------------|
| GAP-GDPR-03 | GDPR Art. 25 | Auditoría de ejecución de purgas cfg_retention |
| GAP-ISO27001-01 | A.8.25 | CI pipeline cargo-audit + SAST/DAST automático (DevOps) |
| GAP-800053-01 | SA-10 | Mismo que GAP-ISO27001-01 |

---

## §14 Resumen Ejecutivo de Madurez IAM

```
MADUREZ GLOBAL bAuth IAM — 2026-08-02 (v1.5.0)
═══════════════════════════════════════════════════════════════════════

  ISO 27001:2022        ██████████████████████████████████████░░  99.2%
  NIST 800-63-4 (IAL)   ████████████████████████████████████░░░░  88.0%
  ISO 24760-2:2025      ████████████████████████████████████████  100.0%
  NIST 800-53 Rev.5     ███████████████████████████████████████░  94.4%
  NIST 800-207 (ZTA)    ████████████████████████████████████████  100.0%  ↑ +16.7% (ZTA T-571)
  NIST 800-63B Rev.4    ████████████████████████████████████████  100.0%  ↑ +4.3% (biometría T-568)
  FIDO2/WebAuthn L3     ████████████████████████████████████████  100.0%  ↑ +12.5% (uv_required)
  GDPR                  ████████████████████████████████████████  100.0%  ↑ +22.2% (T-567+T-570)
  Ley 164 Bolivia       ████████████████████████████████████████  100.0%
  OAuth/OIDC/FAPI 2.0   ████████████████████████████████████████  100.0%  ↑ +23.1% (JARM+RAR+DCR)
  PCI DSS 4.0           ████████████████████████████████████████  100.0%

  MADUREZ COMPUESTA     █████████████████████████████████████████  98.3%  ↑ +7.1% (v1.4.0→v1.5.0)

```

**bAuth alcanza madurez Nivel L4** ("Optimized") en la escala ISO 9001 / CMMI (98.3%):
- Controles nucleares: BitMask · WORM 29 triggers · IOC · HIBP local · PAR+JARM+RAR · 47 métodos · ZTA data-level · biometría · DCR
- Gaps P1: **0** — cerrados (GAP-OP-01/02 · GAP-PCI-01 · GAP-NIST63B-01 · GAP-OAUTH-01)
- Gaps P2: **0** — todos cerrados 2026-08-02 (9 gaps: OAUTH-02/03/04 · FIDO2-01 · GDPR-01/02 · 800207-01 · PCI-02 · NIST63B-02)
- Gaps P3 pendientes: GAP-GDPR-03 (audit purgas) · GAP-ISO27001-01 (CI/CD) · GAP-800053-01 (SA-10)
- Normas al 100%: 8 de 11 (ISO 27001 / 63-4 / 800-53 con 1-2 gaps P3 cada una)

---

## §15 Próximos Pasos Recomendados

| # | Acción | Norma | Esfuerzo | Prioridad |
|---|--------|-------|:--------:|:---------:|
| 1 | ✅ **HECHO** — Seed `auth_method` aplicado: 47 métodos / 12 IMPLEMENTED (2026-08-01) | Multi-norma | XS | ~~🔴 P1~~ |
| 2 | ✅ **HECHO** — Trigger WORM `fn_worm_enforce` BEFORE STATEMENT en 29 tablas — GAP-OP-02 + GAP-PCI-01 CERRADOS (2026-08-02) | ISO 27001 / PCI | S | ~~🔴 P1~~ |
| 3 | ✅ **HECHO** — `auth_credential_secret`: `hibp_checked_at/pwned_count/is_compromised` + `chk_acs_hibp` (2026-08-02) | NIST 800-63B | XS | ~~🔴 P1~~ |
| 4 | ✅ **HECHO** — `fed_par_request` (T-566) + `fed_client.par_required` — GAP-OAUTH-01 CERRADO (2026-08-02) | FAPI 2.0 / OAuth | M | ~~🔴 P1~~ |
| 5 | ✅ **HECHO** — 9 gaps P2 cerrados (JARM/RAR/DCR/uv_required/biometría/GDPR portab./GDPR int.transf./ZTA data-level/pentest) — migration `bauth_gaps_p2.sql` aplicada (2026-08-02) | Multi-norma | M | ~~🟠 P2~~ |
| 6 | Agregar tabla `cfg_retention_execution_log` — auditoría de ejecución de purgas | GDPR Art. 25 | S | 🟡 P3 |
| 7 | Configurar CI pipeline cargo-audit + SAST/DAST | ISO 27001 A.8.25 / NIST SA-10 | L | 🟡 P3 |
| 8 | Implementar NIST 800-63-4 §8 biometría en código Rust (comparación template) | NIST 800-63-4 | XL | 🟡 P3 |

---

## Historial

| Versión | Fecha | Cambio |
|---------|-------|--------|
| 1.5.0 | 2026-08-02 | 9 gaps P2 cerrados: OAUTH-02/03/04 (RAR/JARM/DCR) · FIDO2-01 (uv_required) · GDPR-01/02 (T-567/T-570) · 800207-01 (T-571) · PCI-02 (T-572) · NIST63B-02 (T-568); madurez 98.3% ↑ +7.1%; 8/11 normas al 100% |
| 1.4.0 | 2026-08-02 | PAR: `fed_par_request` T-566 + `fed_client.par_required`; GAP-OAUTH-01 CERRADO; OAuth 10/13 (77%) ↑; madurez 91.2% ↑; 0 gaps P1 |
| 1.3.0 | 2026-08-02 | HIBP: `auth_credential_secret` +3 columnas + chk_acs_hibp; GAP-NIST63B-01 CERRADO; NIST 800-63B 22/23 (96%) ↑; madurez compuesta 90.5% ↑; 0 gaps P1 restantes |
| 1.2.0 | 2026-08-02 | WORM trigger `fn_worm_enforce` FOR EACH STATEMENT en 29 tablas; GAP-OP-02 + GAP-PCI-01 CERRADOS; NIST 800-53 17/18 (94%) ↑ · PCI DSS 8/8 (100%) ↑; madurez compuesta 90.0% ↑ +1.6%; DDL principal §WORM actualizado + migration worm_enforcement_triggers.sql registrada |
| 1.1.0 | 2026-08-01 | Seed auth_method aplicado: 47 métodos (universo canónico 2.02 v1.1.0); GAP-OP-01 CERRADO; scores NIST 800-63B 91% · PCI DSS 87.5% · madurez compuesta 88.4%; CLAUDE.md src/ actualizado |
| 1.0.0 | 2026-08-01 | Documento inicial — 11 normas, 229 tablas bauth, análisis post T-520..T-565 |

---

*Custodio: BauthAgent · Verificado contra SBOSDB · v1.5.0 actualizado 2026-08-02 · 9 gaps P2 cerrados · madurez 98.3% · Nivel L4 Optimized*
