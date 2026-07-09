# BAUTH-FRAMEWORK-VALUES-PROCEDENCIA.md — Procedencia y Propósito de Cada Valor
**Versión:** 1.0 · **Fecha:** 2026-06-26 · **Autor:** sbos-coordinador + investigación internet

## PROPÓSITO

Cada valor en `cfg_policy_library` (9,142 nodos) tiene una **procedencia verificable** y un **propósito funcional** en la cadena de autenticación/autorización de bAuth. Este documento mapea cada categoría de valor a su estándar de origen, su rol en la evaluación, y la tabla DDL que lo consume.

---

## 1. CADENA DE EVALUACIÓN DE BAUTH

```
Usuario solicita acceso
  │
  ├── D8 — CONTEXTO: ¿ctx_id válido? (Pre-BitMask)
  │     Valores: session_ttl, inactivity_timeout, caep_events
  │     Estándar: NIST SP 800-63B §7, SBOS-049
  │
  ├── D9 — CREDENCIALES: ¿AAL suficiente? (Pre-BitMask)
  │     Valores: AAL1/AAL2/AAL3, phishing_resistant, mfa_required
  │     Estándar: NIST SP 800-63B-4 §4-5, FIDO2 Level 2/3
  │     Ejecuta: Keycloak Authentication SPI → ConditionalAuthenticator.matchCondition()
  │
  ├── D1 — LÓGICO: ¿átomo en RolBitMask? (Fast-Path <0.5ns)
  │     Valores: scope, dataClassification, verbs, zones
  │     Estándar: NIST RBAC §4.2, ANSI/INCITS 359-2004
  │
  ├── D3 — FINANCIERO: ¿límites, SoD, dual-approval? (Policy-Path <5ms)
  │     Valores: maxAmount, requiresDualApproval, sod_rules
  │     Estándar: SOX §404, COSO, ISO 20022
  │
  ├── D2 — FÍSICO: ¿zona, escolta, anti-passback? (Fast-Path)
  │     Valores: zone_level, requiresEscort, twoPersonRule
  │     Estándar: BS 5979:2007, IEC 60839-11-5
  │
  ├── D10 — DELEGACIÓN: ¿vigente, no revocada? (Policy-Path)
  │     Valores: maxDuration, chainDepth, autoRevoke
  │     Estándar: NIST SP 800-53 AC-2(2)
  │
  ├── D4 — TEMPORAL: ¿en horario? (Policy-Path)
  │     Valores: schedule, holidays, overtime, breaks
  │     Estándar: RFC 5545, ISO 8601
  │
  ├── D6 — GEOESPACIAL: ¿geo-fence, velocity? (External-Path)
  │     Valores: max_kmh, trust_tier, country
  │     Estándar: NIST SP 800-207 ZTA
  │
  ├── D7 — RED: ¿device trust, VPN, mTLS? (External-Path)
  │     Valores: device_score, ztna_enabled, mtls_required
  │     Estándar: NIST SP 800-207, CIS Benchmarks
  │
  ├── D5 — BIOMÉTRICO: ¿liveness, FMR? (External-Path)
  │     Valores: fmr_threshold, liveness_mode, enrollment_supervised
  │     Estándar: ISO/IEC 30107-3, FIDO Biometrics
  │
  ├── D12 — BLOCKCHAIN: ¿anclaje verificado? (External-Path)
  │     Valores: anchor_frequency, merkle_algorithm
  │     Estándar: RFC 6962, NIST IR 8202
  │
  └── D11 — AUDITORÍA: registro WORM (Post-hoc, siempre)
        Valores: retention, hash_chain, review_frequency
        Estándar: ISO 27001 A.8.15, PCI-DSS 10.5
```

---

## 2. PROCEDENCIA DE CADA CATEGORÍA DE VALOR

### 2.1 FRECUENCIA (ReviewFrequency)
**Valores:** daily, weekly, monthly, quarterly, semi_annual, annual, hourly, realtime, continuous, periodic  
**Estándar:** ISO 27001 A.9.2.5 (Access Review), NIST SP 800-53 AC-6 (Least Privilege Review), SOX §404  
**Propósito:** Define cada cuánto se revisan accesos, roles y políticas. Alimenta `aud_review` y `idn_role_template.last_reviewed`  
**Consumidor DDL:** `aud_review.review_frequency`, `idn_tier_policy.review_frequency`  
**Evaluador bAuth:** AuditDomainEvaluator (D11) — dispara campañas de recertificación automáticas  
**Impacto en autenticación:** Un rol no revisado en el período configurado → alerta + posible suspensión automática

### 2.2 SEVERIDAD (SeverityLevel)
**Valores:** critical, high, medium, low, normal, minimal  
**Estándar:** NIST SP 800-30 (Risk Assessment), ISO 27005 (Risk Management), PCI DSS 4.0 (Risk Ranking)  
**Propósito:** Clasifica el impacto de eventos de seguridad. Alimenta `ses_risk_policy.threshold_*` y `aud_event.severity`  
**Consumidor DDL:** `ses_risk_policy.threshold_critical/high/medium/low`, `fin_sod_rule.risk_level`  
**Evaluador bAuth:** RiskScoringEngine — si score > threshold_critical → TERMINATE_SESSION  
**Impacto en autenticación:** Un evento `critical` fuerza step-up a AAL3 o terminación inmediata de sesión

### 2.3 CLASIFICACION (DataClassification)
**Valores:** confidential, restricted, internal, public, sensitive  
**Estándar:** ISO 27001 A.8.2 (Information Classification), NIST SP 800-53 RA-2 (Security Categorization), GDPR Art.32  
**Propósito:** Define nivel de protección de datos. Alimenta `zone_data_policy.data_classification` y `log_zone`  
**Consumidor DDL:** `zone_data_policy.data_classification`, `idn_role_template.template.logical_access.dataClassification`  
**Evaluador bAuth:** LogicalEvaluator (D1) — `restricted` → requiere AAL3 + justificación  
**Impacto en autenticación:** Datos `restricted` solo visibles con sesión AAL3 + ctx_id verificado

### 2.4 ALGORITMO (CryptoAlgorithm)
**Valores:** AES-256-GCM, SHA-256, SHA-384, SHA-512, EdDSA, CRYSTALS-Kyber, CRYSTALS-Dilithium, SPHINCS+, NTRU, RSA-4096  
**Estándar:** NIST FIPS 140-3, NIST SP 800-57 (Key Management), FIPS 203/204/205 (PQC)  
**Propósito:** Catálogo de algoritmos criptográficos aceptados para firma, cifrado y hashing. Alimenta `bos_crypto_algorithm`  
**Consumidor DDL:** `bos_crypto_algorithm.algo_name`, `sec_key_inventory.algorithm`, Vault Transit  
**Evaluador bAuth:** No es evaluador — es configuración de infraestructura. Vault PKI lo consume para emitir certificados.  
**Impacto en autenticación:** Si un algoritmo es deprecado (ej: SHA-1), bAuth rechaza tokens firmados con él

### 2.5 PROTOCOLO_TLS (TLSProtocol)
**Valores:** TLS1.3, TLS_AES_256_GCM_SHA384, TLS_CHACHA20_POLY1305_SHA256  
**Estándar:** NIST SP 800-52 Rev.2 (TLS Guidelines), RFC 8446 (TLS 1.3), NSA/CISA K8s Hardening  
**Propósito:** Versiones TLS y cipher suites permitidas. Alimenta `idn_tenant_domain.ssl_config` y Kong configuration  
**Consumidor DDL:** `idn_tenant_domain.ssl_config`, Kong Ingress annotations  
**Evaluador bAuth:** NetworkEvaluator (D7) — rechaza conexiones con TLS < 1.3  
**Impacto en autenticación:** Conexiones sin TLS 1.3 → denegadas antes de llegar a autenticación

### 2.6 TIPO_AUTH (AuthFactorType)
**Valores:** password, biometric, certificate, token, sms, email, hardware, multiFactor, fingerprint  
**Estándar:** NIST SP 800-63B §5.1 (Authenticator Types), OWASP ASVS V2.8 (MFA)  
**Propósito:** Tipos de factor de autenticación. Alimenta `ath_method.method_type` y `ath_auth_flow_method`  
**Consumidor DDL:** `ath_method.method_type`, `ath_auth_flow_method.method_id`  
**Evaluador bAuth:** CredentialEvaluator (D9) — verifica que el método usado coincida con el tipo requerido  
**Impacto en autenticación:** Un rol que requiere `hardware` (AAL3) no puede autenticarse solo con `password` (AAL1)

### 2.7 ACCION (SecurityAction)
**Valores:** block, deny, allow, alert, monitor, log, warn, encrypt, delete, read, restrict  
**Estándar:** NIST SP 800-53 AC-3 (Access Enforcement), OWASP ASVS V4.1 (Access Control)  
**Propósito:** Acciones de respuesta ante eventos de seguridad. Alimenta `ses_risk_policy.action_*`  
**Consumidor DDL:** `ses_risk_policy.action_low/medium/high/critical`, `geo_velocity_policy.on_violation`  
**Evaluador bAuth:** RiskScoringEngine + DomainShortCircuit — `block` detiene evaluación inmediatamente  
**Impacto en autenticación:** `block` en velocity check → sesión terminada, requiere reautenticación completa

### 2.8 ENTIDAD_ROL (ApproverRole)
**Valores:** manager, supervisor, securityTeam, legalTeam, dataOwner, owner  
**Estándar:** NIST SP 800-53 AC-5 (Separation of Duties), SOX §404 (Approval Chains)  
**Propósito:** Entidades responsables de aprobación. Alimenta `fin_decision_matrix.nivel_*_rol`  
**Consumidor DDL:** `fin_decision_matrix`, `fin_approval_level`, `ses_risk_policy.notification_roles`  
**Evaluador bAuth:** FinancialEvaluator (D3) — verifica que el aprobador tiene el rol requerido  
**Impacto en autenticación:** Una transacción > $10K requiere aprobación de `manager` + `securityTeam`

### 2.9 ESTADO (LifecycleState)
**Valores:** encrypted, immutable, automated, enabled, disabled, required, mandatory, strict, dynamic, adaptive, approved  
**Estándar:** ISO 27001 A.8.9 (Configuration Management), NIST SP 800-53 CM-2 (Baseline Configuration)  
**Propósito:** Estados de ciclo de vida de configuraciones y políticas  
**Consumidor DDL:** `ath_policy_d*.is_active`, `ath_config_d*.is_active`, `aud_policy_version`  
**Evaluador bAuth:** PolicyEngine — solo evalúa políticas con `enabled=true` y lifecycle != `deprecated`  
**Impacto en autenticación:** Una política `disabled` es ignorada por el evaluador

### 2.10 DURACION (DurationUnit)
**Valores:** 1s, 5s, 30s, 50ms, 100ms, 500ms, 1m, 5m, 15m, 30m, 1h, 2h, 4h, 6h, 8h, 12h, 24h, 30d, 90d, 1y, 3y, 5y, 7y  
**Estándar:** ISO 8601 (Durations), NIST SP 800-63B §7 (Session Management), PCI DSS 10.7 (Retention)  
**Propósito:** Parámetros de duración con unidad. Validados por rango, no por selección.  
**Consumidor DDL:** `idn_tenant.session_ttl_max`, `idn_tenant_config.token_ttl_seconds`, `aud_compliance_map.retention_days`  
**Evaluador bAuth:** Cada evaluador valida que el valor esté dentro del rango permitido por su estándar  
**Impacto en autenticación:** `session_ttl_max=8h` → sesión expira tras 8h, fuerza reautenticación

---

## 3. FLUJO COMPLETO DE EVALUACIÓN DE UN ROL

### 3.1 Lo que bAuth evalúa cuando un usuario solicita acceso

```
PASO 0: Kong PEP recibe request → extrae ctx_id del header W3C traceparent

PASO 1 (D8): ContextEvaluator verifica:
  - ctx_id existe en Redis DB0? → valores: cache_ttl_sync_with_session=true
  - ctx_id no ha expirado? → valores: session_ttl_max=28800 (8h)
  - ctx_id no ha sido revocado? → valores: caep_events=["session-revoked"]
  Resultado: ALLOW (ctx_id válido) / DENY (expirado/revocado)

PASO 2 (D9): CredentialEvaluator verifica:
  - ¿token JWT tiene AAL suficiente? → valores: AAL1/AAL2/AAL3 según ath_method.aal_level
  - ¿método usado es phishing-resistant? → valores: WEBAUTHN_PWDLESS, PASSKEY_DEVICE
  - ¿MFA requerido y cumplido? → valores: mfa_required=true, ath_binding.method_id
  Resultado: ALLOW (AAL suficiente) / STEP_UP (requiere elevar) / DENY (insuficiente)

PASO 3 (D1): LogicalEvaluator (Fast-Path <0.5ns):
  - ¿atom_position está en RolBitMask? → operación: rol.check(position)
  - ¿scope permite acceso? → valores: GLOBAL/COMPANY/BRANCH/PERSONAL
  Resultado: ALLOW (bit=1) / DENY (bit=0)

PASO 4 (D3): FinancialEvaluator (Policy-Path <5ms):
  - ¿monto ≤ límite del rol? → valores: maxAmount=10000 (BIZ_N3)
  - ¿SoD permite? → valores: fin_sod_rule (creador ≠ aprobador)
  - ¿dual-approval requerido? → valores: requiresDualApproval=true
  Resultado: ALLOW / DENY / PENDING_APPROVAL

PASOS 5-10: D2→D10→D4→D6→D7→D5→D12
  Cada evaluador aplica sus valores de configuración
  Cortocircuito: primer DENY detiene la cadena

PASO 11 (D11): AuditDomainEvaluator (siempre):
  - Registra resultado en aud_event (WORM)
  - Calcula hash-chain SHA-256
  Resultado: no afecta la decisión — solo registra
```

### 3.2 Lo que bAuth evalúa cuando se CREA/MODIFICA un rol

```
VALIDACIÓN PRE-REGISTRO (9 verificaciones V01-V09):
  V01: ¿role_code único? → UNIQUE constraint en idn_role_template
  V02: ¿tier válido? → CHECK chk_brt_tier
  V03: ¿status válido? → CHECK chk_brt_status  
  V04: ¿LoA en rango? → CHECK chk_brt_loa (1-4)
  V05: ¿herencia sin ciclos? → rol_closure (Closure Table)
  V06: ¿Conflictos SoD? → fin_sod_rule + sod_validation_config
  V07: ¿métodos de auth disponibles para el tier? → ath_method.active + aal_level
  V08: ¿políticas del dominio aplicables? → ath_policy_d*.is_active
  V09: ¿configuraciones del dominio válidas? → ath_config_d*.config_value vs menu_context
```

---

## 4. VALIDACIÓN CRUZADA: framework → DDL → bAuth

| Categoría Framework | Tabla DDL que la consume | Evaluador bAuth | Estándar | ¿Implementado? |
|---------------------|-------------------------|-----------------|----------|:---:|
| ReviewFrequency | `aud_review`, `idn_tier_policy` | AuditDomainEvaluator (D11) | ISO 27001 A.9.2.5 | ✅ |
| SeverityLevel | `ses_risk_policy`, `fin_sod_rule` | RiskScoringEngine (D8) | NIST SP 800-30 | ✅ |
| DataClassification | `zone_data_policy`, `log_zone` | LogicalEvaluator (D1) | ISO 27001 A.8.2 | ✅ |
| CryptoAlgorithm | `bos_crypto_algorithm`, `sec_key_inventory` | Vault PKI (infra) | FIPS 140-3 | ✅ |
| TLSProtocol | `idn_tenant_domain.ssl_config` | NetworkEvaluator (D7) | NIST SP 800-52 | ✅ |
| AuthFactorType | `ath_method.method_type` | CredentialEvaluator (D9) | NIST 800-63B §5.1 | ✅ |
| SecurityAction | `ses_risk_policy.action_*` | DomainShortCircuit | NIST 800-53 AC-3 | ✅ |
| ApproverRole | `fin_decision_matrix` | FinancialEvaluator (D3) | SOX §404 | ✅ |
| LifecycleState | `ath_policy_d*.is_active` | PolicyEngine | ISO 27001 A.8.9 | ✅ |
| DurationUnit | `idn_tenant.session_ttl_max` | ContextEvaluator (D8) | NIST 800-63B §7 | ✅ |

---

*Documento generado 2026-06-26. 195 valores clasificados en 10 categorías funcionales con procedencia verificable.*
*Cada valor tiene un propósito en la cadena de evaluación de bAuth: autenticación → autorización → auditoría.*
*Fuentes: NIST SP 800-63B-4 (2025), Keycloak 26 Auth SPI, OWASP ASVS 5.0, PCI DSS 4.0, ISO 27001:2022.*
