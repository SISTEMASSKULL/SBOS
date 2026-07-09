# BAUTH — CLASIFICACIÓN FUNCIONAL DEL SISTEMA
## Arquitectura por Secciones Bien Definidas · 2026-06-30

**Versión:** 1.1 · **Autor:** sbos-coordinador · **Fuente:** Análisis de 108 handlers, 100+ archivos Rust, 25,171 LOC Rust + 646 LOC Dart (bAuthDEV) + 5,298 LOC docs desktop

> Este documento reorganiza bAuth en **secciones funcionales** independientes del orden de
> desarrollo (gates B0-B48). Cada sección describe QUÉ hace, CÓMO se implementa, y QUÉ
> estándares aplica. El objetivo es que cualquier desarrollador nuevo entienda bAuth
> en 15 minutos leyendo este documento.

---

## ÍNDICE DE SECCIONES

| # | Sección | Propósito | Handlers | Estado |
|:--:|------|------|:---:|:---:|
| **S1** | [Motor de Dominios (D1-D12)](#s1--motor-de-dominios-d1-d12) | Evaluar acceso en 12 dimensiones | 19 | ✅ |
| **S2** | [Motor de Privilegios (BitMask Dual)](#s2--motor-de-privilegios-bitmask-dual) | Cálculo y verificación O(1) de permisos | 6 | ✅ |
| **S3** | [Motor de Métodos de Autenticación](#s3--motor-de-métodos-de-autenticación) | Validar credenciales por 8+ métodos nativos | 4 | ✅ |
| **S4** | [Motor de Políticas (XACML 3.0)](#s4--motor-de-políticas-xacml-30) | Evaluar reglas condicionales multi-capa | 12 | ✅ |
| **S5** | [Motor de Identidad (Tokens JWT)](#s5--motor-de-identidad-tokens-jwt) | Emitir, validar y rotar tokens de identidad | 8 | ✅ |
| **S6** | [Motor de Roles (RolTemplate)](#s6--motor-de-roles-roltemplate) | CRUD de roles + 66 plantillas base | 12 | ⚠️ |
| **S7** | [Motor de Usuarios (UserTemplate)](#s7--motor-de-usuarios-usertemplate) | CRUD de usuarios + ciclo de vida | 8 | ⚠️ |
| **S8** | [Motor de Contexto (Context Plane)](#s8--motor-de-contexto-context-plane) | ctx_id W3C + sesiones + propagación | 8 | ✅ |
| **S9** | [Orquestador de Motores Externos](#s9--orquestador-de-motores-externos) | bAuth orquesta KC, Vault, Kong, Besu; reconcile loop 60s | 8 | ⚠️ |
| **S10** | [Motor de Sagas (Flujos Multi-Paso)](#s10--motor-de-sagas-flujos-multi-paso) | Ejecutar flujos con compensación | 2 | ⚠️ |
| **S11** | [Motor de Firmas Digitales](#s11--motor-de-firmas-digitales) | Firma Ed25519 interna + RSA-SHA256 externa (ADSIB) | 1 | ⚠️ |
| **S12** | [Motor de Blockchain (D12)](#s12--motor-de-blockchain-d12) | Anclaje Merkle + Liquidación Besu/Arbitrum | 6 | ✅ |
| **S13** | [Motor de Notificaciones](#s13--motor-de-notificaciones) | Calendario → Alarma → bnotify → Mattermost | 3 | ✅ |
| **S14** | [Motor de Dispositivos (Identity Hub)](#s14--motor-de-dispositivos-identity-hub) | Registro, atestación, transferencia multi-dispositivo | 4 | ✅ |
| **S15** | [Proveedor de Identidad Externo (IdP-as-a-Service)](#s15--proveedor-de-identidad-externo-idp-as-a-service) | OIDC Discovery, SCIM, SAML, Tenant Isolation | 16 | ⚠️ |
| **S16** | [Infraestructura y Operaciones](#s16--infraestructura-y-operaciones) | Self-service, Kong PEP, DR, Threat Model | 18 | ⚠️ |
| **S17** | [bAuthDEV — RPC Tester para Desarrolladores](#s17--bauthdev--rpc-tester-para-desarrolladores) | Postman-like, WebSocket + JSON-RPC 2.0 sobre Unix socket | — | ⚠️ |
| **S18** | [Dashboard Soberano de Administración](#s18--dashboard-soberano-de-administración) | PAP visual + 10 handlers backend · 13 paneles · WebSocket + JSON-RPC 2.0 | 10 | ⚠️ |

> **Leyenda:** ✅ Código completo · ⚠️ Diseño completo, código parcial o pendiente

---

## S1 — Motor de Dominios (D1-D12)

**Propósito:** Evaluar cada solicitud de acceso en 12 dimensiones independientes con cortocircuito.
Cada dominio es un evaluador que implementa `DomainEvaluator`.

**Arquitectura:**
```
Solicitud de acceso (user_uuid + atom_slug + request_data)
  │
  ├── Fast-Path (< 0.5ns): verificar RolBitMask[N] == 1 para atom_position
  │
  └── Policy-Path (< 5ms): para cada dominio D1→D12:
        ├── domain.evaluate(ctx) → ALLOW / DENY / STEP_UP
        └── Si DENY → cortocircuito (no evaluar dominios restantes)
```

### Tablas de dominio (12 × 3 = 36 tablas)

| Dominio | Políticas (`ath_policy_d*`) | Configuraciones (`ath_config_d*`) | Templates (`idn_role_d*`) |
|---------|----------|------------|----------|
| **D1** — Lógico | 6 políticas (record_rules, field_rules, button_rules, scope, data_classification, zone_access) | 6 configs (token_ttl, rate_limit, max_records, session_ttl, audit_verbosity, zone_defaults) | 4 roles (OPERADOR_CAJA, GERENTE_REGIONAL, AUDITOR, VISOR_BASICO) |
| **D2** — Físico | 7 políticas (anti_passback, escort, two_person, mantrap, biometric_enrollment, emergency_override, visitor_access) | 6 configs (door_relay_ms, anti_passback_reset_h, duress_timeout, max_access_points, osdp_secure_channel, visitor_badge_ttl) | 4 roles (EMPLEADO_STANDARD, VISITANTE, TECNICO, SUPERVISOR_SEGURIDAD) |
| **D3** — Financiero | 10 políticas (dual_approval, sod, transaction_limits, approval_chain, sin_compliance, currency_control, reconciliation, audit_trail, fraud_detection, blockchain_settlement) | 7 configs (currency_default, sin_environment, approval_timeout_h, max_tiers, transaction_idempotency, reconciliation_tolerance, cufd_renewal) | 4 roles (CAJERO, APROBADOR_N1, APROBADOR_N2, AUDITOR_FINANCIERO) |
| **D4** — Temporal | 6 políticas (schedules, holidays, overtime, breaks, session_expiry, attendance) | 6 configs (timezone_default, shift_duration_max, overtime_rate, break_duration, schedule_grace_period, holiday_country) | 3 roles (HORARIO_OFICINA, TURNO_ROTATIVO, GUARDIA_24X7) |
| **D5** — Biométrico | 5 políticas (liveness, fmr_threshold, enrollment, gdpr_consent, device_attestation) | 6 configs (fmr_default, liveness_method, argon2_params, template_retention_days, quality_threshold, gdpr_biometric_consent) | 3 roles (HUELLA_DACTILAR, RECONOCIMIENTO_FACIAL, SIN_BIOMETRIA) |
| **D6** — Geoespacial | 5 políticas (geo_fence, velocity, location_trust, jurisdiction, ip_range) | 6 configs (velocity_max_kmh, tolerance_km, fence_radius_default, location_history, trust_tier_thresholds, jurisdiction_block) | 3 roles (LOCAL_BOLIVIA, REGIONAL_LATAM, RESTRINGIDO_SUCURSAL) |
| **D7** — Red | 6 políticas (device_trust, cidr, vpn, mtls, ztna, continuous_verification) | 7 configs (device_score_min, verification_interval_s, grace_period_s, mtls_config, vpn_required, ztna_mode, network_policy_default) | 3 roles (CORPORATIVO, VPN, REMOTO_SEGURO) |
| **D8** — Contexto | 5 políticas (ctx_id, session_ttl, context_switching, caep_events, ctx_promotion) | 7 configs (session_ttl_max, inactivity_timeout, reauth_timeout, max_contexts, ctx_id_format, caep_config, dctx_ttl) | 4 roles (SESION_8H, SESION_EXTENDIDA, BREAK_GLASS, READ_ONLY) |
| **D9** — Credenciales | 11 políticas (password, mfa, recovery, lockout, rotation, phishing_resistance, step_up, m2m_credentials, ciba, token_binding, auth_flow) | 9 configs (password_min_length, hibp_enabled, lockout_levels, rotation_days, mfa_grace_period, recovery_codes, step_up_max_duration, argon2id_params, token_binding) | 4 roles (AAL1_BASICO, AAL2_MFA, AAL3_HARDWARE, M2M_MTLS) |
| **D10** — Delegación | 4 políticas (max_duration, non_delegable, chain_depth, auto_revoke) | 5 configs (max_duration_h, max_concurrent, auto_revoke, non_delegable_list, chain_depth_max) | 3 roles (SIN_DELEGACION, DELEGACION_BASICA, DELEGACION_SUPERVISOR) |
| **D11** — Auditoría | 4 políticas (retention, hash_chain, review_frequency, regulatory_mapping) | 6 configs (retention_days_default, hash_chain_default, review_frequency_default, worm_enforcement, compliance_frameworks, purge_policy) | 4 roles (BASICO, COMPLETO, SOX, GDPR) |
| **D12** — Blockchain | 6 políticas (merkle_anchor, did_method, proof_types, smart_contract, settlement, reconciliation) | 7 configs (anchor_frequency, gas_limit, network, contract_address, merkle_tree, besu_validators, reconciliation) | 3 roles (SIN_ANCLAJE, ANCLAJE_MERKLE, DID_BASICO) |

### Código fuente

| Capa | Archivos | Descripción |
|------|---------|------------|
| **Evaluadores** | `domain/logical.rs`, `physical.rs`, `financial.rs`, `temporal.rs`, `biometric.rs`, `geospatial.rs`, `network.rs`, `context.rs`, `credential.rs`, `delegation.rs`, `audit_domain.rs`, `blockchain.rs` | 12 implementaciones de `DomainEvaluator` |
| **Registro** | `bitmask/registry.rs` | `DomainRegistry`: orquesta los 12 evaluadores con cortocircuito |
| **Handlers** | `server/handlers/context_evaluate.rs`, `server/handlers/domain_*.rs` | `bauth.context.evaluate`, `bauth.domain.{d}.list` |
| **Catálogo** | `bitmask/catalog.rs` | `AtomCatalog`: 5,808 átomos cargados en memoria |

### Estándares de referencia
NIST SP 800-207 (Zero Trust), NIST SP 800-162 (ABAC), NIST SP 800-53 (Security Controls), ISO 27001:2022 A.8.9, ANSI/INCITS 359-2004 (RBAC)

---

## S2 — Motor de Privilegios (BitMask Dual)

**Propósito:** Calcular y verificar permisos en O(1) usando dos máscaras de bits complementarias.
Sin este motor, cada verificación requeriría consultas SQL.

**Modelo BitMask Dual:**
```
BitMask Átomo (64-bit, label encoding):         RolBitMask (N-bit, one-hot encoding):
┌─────────────────────────────────────┐       ┌──────────────────────────┐
│ device_allowed │ domain │ app │ ... │       │ posición 0: átomo "app.leer"       │
│ 4 bits         │ 4 bits │ 6   │     │       │ posición 1: átomo "app.escribir"    │
│                                   │       │ posición 2: átomo "factura.emitir" │
│ Contextual: identifica QUÉ átomo   │       │ ...                                   │
│ se está solicitando               │       │ posición N: átomo "admin.config"     │
└─────────────────────────────────────┘       └──────────────────────────┘
                                              Herencia DAG: OR transitivo
                                              sobre posiciones independientes
```

**Verificación O(1):**
```rust
// Fast-Path (< 0.5ns)
fn fastpath_check(rol: &RolBitMask, position: AtomPosition) -> bool {
    rol.0[position.0 as usize]  // acceso directo al bit N
}
```

### Código fuente

| Archivo | Responsabilidad |
|---------|----------------|
| `bitmask/atom.rs` | `AtomBitMask(u64)`: 10 campos codificados en 64 bits (device_allowed, domain, app, group, min_trust, token_binding, blk_anch, policy, reserved, verb) |
| `bitmask/rol.rs` | `RolBitMask(BitVec)`: N bits one-hot, OR transitivo vía DAG |
| `bitmask/catalog.rs` | `AtomCatalog`: 5,808 átomos precargados desde `privilege_atom` |
| `bitmask/closure.rs` | `ClosureTableEngine`: cierre transitivo de herencia de roles |
| `bitmask/conflict.rs` | `ConflictMatrix`: detección de conflictos SoD |
| `bitmask/resolver.rs` | `AtomPositionResolver`: resuelve átomo → posición en RolBitMask |
| `bitmask/serializer.rs` | `BosJwtClaims`: serializa RolBitMask en Base64 para JWT |
| `bitmask/fastpath.rs` | `FastPathStats`: estadísticas de verificaciones O(1) |
| `domain/bitmask.rs` | Adaptador para usar `bitmask/` desde `domain/` |

### Handlers JSON-RPC

| Método | Handler | Propósito |
|--------|---------|-----------|
| `bauth.role.compute_mask` | RoleComputeMaskHandler | Calcular RolBitMask desde átomos de rol |
| `bauth.access.evaluate` | AccessEvaluateHandler | Evaluación completa (FastPath + PolicyPath) |
| `bauth.inheritance.compute` | InheritanceComputeHandler | Calcular herencia DAG |
| `bauth.inheritance.check` | InheritanceCheckHandler | Verificar si rol A hereda de B |
| `bauth.sod.check` | SodCheckHandler | Verificar conflictos SoD |
| `bauth.role.merge` | MergeTemplatesHandler | Fusionar 12 templates con SoD |

---

## S3 — Motor de Métodos de Autenticación

**Propósito:** Validar credenciales de usuarios usando 8+ métodos nativos implementados en Rust
(sin dependencia de Keycloak para la validación). Cada método implementa el trait `AuthMethod`.

**Catálogo de métodos:**

| Método | Validador | Estándar | LoA | Phishing-Resistant |
|--------|-----------|----------|:---:|:---:|
| **PASSWORD** | (Argon2id en `saga/actions/login.rs`) | NIST SP 800-63B §5.1.1 | AAL1 | ❌ |
| **TOTP** | `TotpValidator` (`auth_methods/totp.rs`) | RFC 6238 | AAL2 | ❌ |
| **HOTP** | `HotpValidator` (`auth_methods/hotp.rs`) | RFC 4226 | AAL2 | ❌ |
| **WEBAUTHN_PWDLESS** | `WebAuthnValidator` (`auth_methods/webauthn.rs`) | FIDO2, W3C WebAuthn | AAL2 | ✅ |
| **PASSKEY** | `WebAuthnValidator` (mismo) | FIDO2 CTAP 2.2 | AAL3 | ✅ |
| **X.509 mTLS** | `MtlsValidator` (`auth_methods/mtls.rs`) | RFC 5280 | AAL2 | ✅ |
| **SAML 2.0** | `SamlValidator` (`auth_methods/saml.rs`) | SAML 2.0, XML-DSig | AAL2 | ❌ |
| **RECOVERY_CODES** | `RecoveryValidator` (`auth_methods/recovery.rs`) | NIST SP 800-63B §5.3 | AAL1 | ❌ |
| **EMAIL_OTP** | `EmailOtpValidator` (`auth_methods/email_otp.rs`) | NIST SP 800-63B §5.1.4 | AAL1 | ❌ |
| **PUSH** | `PushValidator` (`auth_methods/push.rs`) | Ed25519 challenge-response | AAL2 | ✅ |

### Flujo de validación

```
Usuario presenta credenciales
  │
  ├── MethodRegistry.resolve(method_id) → AuthMethod
  │
  ├── method.validate(challenge, stored_credential) → ValidateResult
  │     ├── SUCCESS → continuar
  │     ├── FAILURE → registrar intento fallido
  │     └── STEP_UP_REQUIRED → elevar LoA
  │
  └── Si AAL requerido > 1 → validar segundo factor
```

### Código fuente

| Archivo | Responsabilidad |
|---------|----------------|
| `domain/auth_methods/mod.rs` | `MethodRegistry` + trait `AuthMethod` (8 métodos registrados) |
| `domain/auth_methods/totp.rs` | TOTP: HMAC-SHA1/256/512, ventana de 30s, ±1 paso |
| `domain/auth_methods/hotp.rs` | HOTP: HMAC-SHA1, contador, resincronización |
| `domain/auth_methods/webauthn.rs` | WebAuthn/FIDO2 nativo (webauthn-rs) |
| `domain/auth_methods/saml.rs` | SAML 2.0 + verificación XML-DSig |
| `domain/auth_methods/mtls.rs` | Validación de certificados X.509 |
| `domain/auth_methods/push.rs` | Challenge-response Ed25519 |
| `domain/auth_methods/recovery.rs` | Recovery codes SHA-256 |
| `domain/auth_methods/email_otp.rs` | OTP por email |
| `saga/actions/hibp.rs` | HIBP k-anonymity: verifica contraseñas comprometidas |
| `saga/actions/login.rs` | Login flow: verify_argon2id + record_failed_attempt |
| `domain/password/mod.rs` | Políticas de contraseña (Argon2id, historial) |

---

## S4 — Motor de Políticas (XACML 3.0)

**Propósito:** Evaluar reglas condicionales sobre el contexto de acceso usando un motor
compatible con XACML 3.0 y NIST ABAC (SP 800-162). **Dos capas de evaluación distintas.**

### Capa A — Políticas XACML complejas (`bos_atom_policy`)

Formato: `bos_policy_v1` con condiciones, targets, reglas, obligaciones.

```
PolicyRule {
  effect: Permit | Deny,
  target: { subject, resource, action, environment },
  condition: PolicyCondition {
    operator: And | Or | Not | Eq | Gt | Lt | In | Contains | Between | Regex | TimeInRange | GeoDistance | CidrMatch,
    operands: [PolicyValue, ...]
  }
}
```

### Capa B — Políticas simples por dominio (`ath_policy_d1..d12`)

Formato: `{"rule": "X", "config": {...}}` — cada dominio define sus reglas operativas en
su propia tabla. Convertidas a `PolicyRule` vía `ath_converter.rs`.

**62 rule types** implementados en `ath_converter.rs` cubriendo D1-D12.

### Código fuente

| Archivo | Responsabilidad |
|---------|----------------|
| `domain/policy/mod.rs` | `PolicyEngine`: punto de entrada, orquesta evaluación |
| `domain/policy/evaluate.rs` | `eval_condition()`, `eval_rule()`, `evaluate()`: motor compartido |
| `domain/policy/condition.rs` | 17 operadores de comparación (Eq, Gt, Lt, In, Contains, Between, Regex, GeoDistance, CidrMatch...) |
| `domain/policy/rule.rs` | Tipos: `PolicyRule`, `PolicyResult`, `PolicyData`, `LogicOp`, `EvaluateBlock`, `EvalContext` |
| `domain/policy/resolver.rs` | `resolve_value()`, `haversine_km()`, `simple_cidr_match()`, `ip_to_u32()` |
| `domain/policy/parser.rs` | `validate_policy_schema()`, `parse_policy_data()`, `load_from_json()` — Capa A |
| `domain/policy/ath_converter.rs` | Convierte `{"rule":"X"}` → `PolicyRule` — Capa B |
| `domain/policy/ath_loader.rs` | `load_domain(pg, domain)`, `load_all(pg)` — carga políticas D1-D12 |
| `domain/policy/conflict.rs` | Detector de conflictos entre políticas |
| `domain/rule_engine.rs` | `RuleEngine`: validación de campos contra `cfg_validation_rule` (261 reglas) |

### Handlers JSON-RPC

| Método | Handler | Propósito |
|--------|---------|-----------|
| `bauth.policy.evaluate` | PolicyEvaluateHandler | Evaluar política XACML (Capa A) |
| `bauth.policy.domain.evaluate` | PolicyDomainEvalHandler | Evaluar política por dominio (Capa B) |
| `bauth.policy.domain.list` | PolicyDomainListHandler | Listar políticas de un dominio |
| `bauth.policy.library.search` | PolicyLibrarySearchHandler | Buscar en biblioteca de 9,142 normas |
| `bauth.policy.create` | PolicyCreateHandler | Crear política |
| `bauth.policy.update` | PolicyUpdateHandler | Actualizar política |
| `bauth.policy.delete` | PolicyDeleteHandler | Eliminar política |
| `bauth.policy.validate` | PolicyValidateHandler | Validar schema de política |
| `bauth.policy.list` | PolicyListHandler | Listar políticas |
| `bauth.policy.check_conflicts` | PolicyCheckConflictsHandler | Detectar conflictos |
| `bauth.policy.simulate` | PolicySimulateHandler | Simular evaluación |
| `bauth.policy.audit` | PolicyAuditHandler | Auditoría de políticas |

---

## S5 — Motor de Identidad (Tokens JWT)

**Propósito:** Emitir, validar, refrescar y rotar tokens JWT que contienen la identidad
completa del usuario: RolBitMask, DomainResults, ctx_id, LoA, device_trust.

**Estructura del JWT de bAuth (4-capas):**
```
JWT {
  Header:  { "alg": "EdDSA", "kid": "vault-key-id" }
  Payload: {
    sub, iss, aud, exp, iat,                    // RFC 7519 estándar
    ctx_id: "uuid-v7",                          // Contexto SBOS-049
    bos_rol_bitmask: "base64...",               // RolBitMask N-bit
    bos_atom_bitmask: "0x1A2B...",              // AtomBitMask 64-bit
    bos_domain_results: { "D1": "ALLOW", ... }, // Resultados 12 dominios
    tenant_id, empresa_id, sucursal_id, pos_logico,
    loa: 2,                                     // NIST AAL 1-3
    auth_methods: ["TOTP", "WEBAUTHN_PWDLESS"],
    device_trust: 85,
    risk_score: 12
  }
  Signature: Ed25519 (Vault PKI) o RSA-SHA256 (ADSIB Bolivia)
}
```

### Flujo de emisión

```
bauth.token.issue(user_uuid, atom_slug)
  │
  ├── 1. Autenticar usuario vía EngineRegistry
  ├── 2. Resolver RolBitMask desde idn_role_template
  ├── 3. Evaluar 12 dominios con DomainRegistry
  ├── 4. Construir JWT con JwtBuilder
  ├── 5. Firmar con JwtSigner (Ed25519 via Vault)
  └── 6. Retornar token (~1.1 KB)
```

### Código fuente

| Archivo | Responsabilidad |
|---------|----------------|
| `domain/jwt_builder.rs` | `JwtBuilder`: construye claims (sub, iss, aud, exp, ctx_id, bos_rol_bitmask, bos_atom_bitmask, bos_domain_results, tenant_id, empresa_id, sucursal_id, pos_logico, loa, auth_methods, device_trust, risk_score) |
| `domain/jwt_signer.rs` | `JwtSigner`: firma Ed25519 (Vault) + RSA-SHA256 (ADSIB externo) |
| `domain/jwe_encrypt.rs` | `JweEncryptor`: cifra payload sensible con AES-256-GCM (RFC 7516) |
| `domain/merkle.rs` | `MerkleTree`: árbol Merkle SHA-256 para claims D12 |

### Handlers JSON-RPC

| Método | Handler | Propósito |
|--------|---------|-----------|
| `bauth.token.issue` | TokenIssueHandler | Emitir JWT con RolBitMask + ctx_id |
| `bauth.token.validate` | TokenValidateHandler | Validar firma Ed25519 + claims |
| `bauth.token.refresh` | TokenRefreshHandler | Rotar token con re-evaluación |
| `bauth.token.jwks` | TokenJwksHandler | Publicar JWKS para validación offline |
| `bauth.token.exchange` | TokenExchangeHandler | RFC 8693: delegación de token |
| `bauth.token.dpop` | DpopHandler | RFC 9449: proof-of-possession |
| `bauth.token.introspect` | TokenIntrospectHandler | RFC 7662: Resource Server consulta |
| `bauth.sign.internal` | SignInternalHandler | Firma digital interna Ed25519 |

---

## S6 — Motor de Roles (RolTemplate)

**Propósito:** CRUD completo de roles con 66 plantillas base, 7 estados de ciclo de vida,
herencia DAG, y sincronización automática a Keycloak.

**Modelo de dos niveles:**
```
Plantilla base (is_template=TRUE, 66 predefinidas)
  │  NO se sincroniza a KC. Solo existe en BD.
  │
  └── CLONAR + MODIFICAR ──→ Rol oficial (is_template=FALSE)
       │  SÍ se sincroniza a KC + Tryton.
       │
       └── CLONAR ──→ Otro rol oficial (misma empresa, otra sucursal)
```

**Ciclo de vida (7 estados):**
```
DEFINIDO → DESARROLLADO → REVISADO → AUTORIZADO → PUBLICADO → DEPRECADO → RETIRADO
```

### Validación (16 bloques JSONB)

Cada RolTemplate se valida contra 16 bloques con campos obligatorios según el seed `seed_idn_role_template_data.sql`:

| Bloque | Campos clave | Tablas fuente |
|--------|-------------|---------------|
| `role` | id, type_id, tier, status, loa_required, mfa_required | DDL idn_role_template |
| `logical_access` | availableZones, selectedZones, availableApplications, availableVerbs, scope, dataClassification | log_zone, privilege_application, privilege_verb |
| `physical_access` | availableZones, zoneMethods, maxSecurityZone, requiresEscort | fis_access_zone, fis_zone_method_requirement |
| `financial` | availableTransactionTypes, limits, requiresDualApproval, maxApprovalAmount, activeSoDRules | fin_transaction_type, fin_sod_rule |
| `temporal` | availableSchedules, holidays, overtimePolicy, breakPolicy, allowOvertime | cal_schedule, cal_holiday |
| `biometric` | availableMethods, fmrThreshold, livenessRequired, enrollmentSupervised | ath_method (bio), ath_policy_d5 |
| `geospatial` | availableGeoFences, trustTiers, velocityPolicy, allowedCountries | geo_fence, geo_trust_tier |
| `network` | availableNetworks, ztnaPolicy, vpnRequired, mTLSRequired, deviceTrustMin | idn_tenant_network, net_ztna_policy |
| `context` | sessionTtlSeconds, inactivityTimeout, maxContexts, caepEvents, riskPolicy | ses_risk_policy, ses_caep_config |
| `credentials` | availableMethods, requiredMethods, appliedPolicies, stepUpRules, minAal | ath_method, ath_policy_d9, idn_tier_policy |
| `delegation` | enabled, maxDurationDays, maxChainDepth, autoRevokeOnExpiry | dlg_delegation |
| `audit` | level, retentionDays, hashChainRequired, reviewFrequency, complianceControls | aud_compliance_map |
| `blockchain` | enabled, variant, anchorFrequency, network, merkleAlgorithm, batchSize | blk_merkle_batch |
| `security` | keyInventory, cryptoAlgorithms, sodValidation, securityZone | sec_key_inventory, sod_validation_config |
| `compliance` | frameworks, gdprConsent, dataSubjectRights, complianceStatus | aud_compliance_map |
| `sync` | kcCompositeRole, kcAuthFlow, trytonGroup, syncStatus | — |

### Código fuente

| Archivo | Responsabilidad |
|---------|----------------|
| `domain/roltemplate_validator.rs` | Validación de 16 bloques con campos exactos del seed |
| `domain/merge.rs` | `merge_role_templates()`: fusiona 12 `idn_role_d*` en JSONB |
| `domain/lifecycle.rs` | Máquina de estados de 7 pasos con transiciones SoD |
| `domain/inheritance.rs` | Herencia DAG entre roles |
| `domain/policy_chain.rs` | `PolicyChainResolver`: aplica cadena PAP→PIP→PDP→PEP |
| `server/handlers/role_template.rs` | CRUD handlers (list, get, create, update, delete) |
| `server/handlers/role_lifecycle.rs` | Lifecycle, impacto, búsqueda, bulk, rollback, batch |
| `server/handlers/merge_templates.rs` | `bauth.role.merge` |
| `server/handlers/role_list.rs` | `bauth.role.list` |
| `server/handlers/template_validate.rs` | `bauth.role.template.validate` |
| `db/seeds/seed_idn_role_template_data.sql` | Seed maestro: genera JSONB para TODOS los roles |
| `db/seeds/seed_b10_all_templates.sql` | 48 plantillas base insertadas |

---

## S7 — Motor de Usuarios (UserTemplate)

**Propósito:** CRUD de usuarios con 15 secciones JSONB, ciclo de vida (6 estados),
asignación de roles, credenciales y dispositivos vinculados.

**Ciclo de vida (6 estados):**
```
PENDING → ACTIVE → INACTIVE → SUSPENDED → TERMINATED → LOCKED
```

### Validación (15 secciones)

| # | Sección | Campos clave validados |
|:--:|------|------|
| 0 | `identity` | username, email, tenant_id, empresa_id, accountType (HUMAN/SERVICE/MACHINE/GUEST) |
| 1 | `personal_info` | first_name, last_name, document_type (9 tipos), document_number, date_of_birth |
| 2 | `professional` | department, job_title, employee_id, sucursal_id |
| 3 | `roles` | assigned_roles, primary_role |
| 4 | `keycloak_credentials` | enrolled_methods (15 métodos), aal_level (1-3), last_password_change |
| 5 | `physical_credentials` | access_cards, biometric_templates (8 tipos) |
| 6 | `device_registry` | bound_devices (10 categorías), max_devices |
| 7 | `session_state` | max_concurrent_sessions, session_ttl_seconds, inactivity_timeout, active_sessions |
| 8 | `location` | country_code (ISO 3166-1), latitud, longitud, preferred_timezone |
| 9 | `temporal` | work_schedule, vacation_days_remaining |
| 10 | `network` | vpn_profile_id, mtls_certificate_id, allowed_ips, ztna_policy_id |
| 11 | `audit` | audit_enabled, retention_days, audited_events (9 tipos) |
| 12 | `external_services` | linked_services, federation_protocols |
| 13 | `compliance` | data_classification (6 niveles), gdpr_consent, applicable_frameworks (10 tipos) |
| 14 | `lifecycle` | status (6 estados), created_at, account_expires_at |

### Código fuente

| Archivo | Responsabilidad |
|---------|----------------|
| `domain/usertemplate_validator.rs` | Validación de 15 secciones con 6 tests |
| `server/handlers/user_template.rs` | CRUD handlers (get, create, update, delete, assign_role, revoke_role) |
| `server/handlers/user_list.rs` | `bauth.user.list` |
| `domain/validate.rs` | Validación de datos (email, phone, date, text) |

---

## S8 — Motor de Contexto (Context Plane)

**Propósito:** Implementar el Context Plane SBOS-049: creación, validación, promoción,
invalidación y propagación de ctx_id según W3C Trace Context + OpenTelemetry Baggage.

**Estructura del ctx_id (6 capas):**
```
ctx_id = {
  tenant_id, empresa_id, sucursal_id, pos_logico,
  user_id, traceparent (W3C)
}
```

### Flujo del Context Plane

```
BOS crea ctx_id (UUIDv7)
  │
  ├── bAuth almacena en ses_context (PostgreSQL)
  ├── bAuth cachea en Redis DB0 (TTL 8h)
  │
  ├── Cada request: validar ctx_id en Redis → PostgreSQL
  ├── Step-Up: promover LoA vía bauth.ctx.promote
  ├── Transferencia: propagar ctx_id entre dispositivos
  └── Invalidate: logout, timeout, compromiso
```

### Código fuente

| Archivo | Responsabilidad |
|---------|----------------|
| `context/plane.rs` | `CtxPlane`: estado de un ctx_id activo |
| `context/engine.rs` | `CtxEngine`: crea, valida, promueve, propaga ctx_id |
| `server/handlers/context_plane.rs` | 6 handlers: create, validate, promote, invalidate, propagate, get_session |
| `server/handlers/ctx_validate.rs` | Validador de contexto |
| `server/handlers/context_evaluate.rs` | `bauth.context.evaluate`: evaluación completa 12 dominios |
| `sync/mod.rs` | Reconcile loop 60s: invalida sesiones expiradas, emite CAEP |

### Handlers JSON-RPC

| Método | Handler | Propósito |
|--------|---------|-----------|
| `bauth.ctx.create` | CtxCreateHandler | Crear ctx_id |
| `bauth.ctx.validate` | CtxValidateEnhancedHandler | Validar ctx_id activo |
| `bauth.ctx.promote` | CtxPromoteHandler | Elevar LoA (Step-Up RFC 9470) |
| `bauth.ctx.invalidate` | CtxInvalidateHandler | Invalidar sesión |
| `bauth.ctx.propagate` | CtxPropagateHandler | Propagar entre dispositivos |
| `bauth.ctx.get_session` | CtxGetSessionHandler | Obtener sesión activa |
| `bauth.context.evaluate` | ContextEvaluateHandler | Evaluar 12 dominios |
| `bauth.ctx.transfer` | CtxTransferHandler | Transferencia universal QR/NFC/BLE/UWB |

---

## S9 — Orquestador de Motores Externos

**Propósito:** bAuth es el **orquestador central de identidad**. No autentica directamente —
recibe credenciales, las enruta al motor correcto, recibe resultados, aplica sus propias
reglas (BitMask Dual + 12 dominios + PolicyChain + SoD + DAG), y emite el JWT final.
**Cada 60s, el reconcile loop verifica que todos los motores reflejen el estado deseado.**

**bAuth NO es un wrapper de Keycloak.** bAuth tiene su propio OIDC Provider nativo
(`oidc_provider.rs`), sus propios validadores de métodos (TOTP, WebAuthn, SAML, mTLS),
y su propio PolicyEngine XACML 3.0. KC es solo UNO de los motores que bAuth orquesta.

### Motores orquestados por bAuth

```
                          ┌──────────────────────────┐
                          │     bAuth — ORQUESTADOR   │
                          │     (fuente de verdad)    │
                          │     bauth_db PostgreSQL   │
                          └──────────┬───────────────┘
                                     │
         ┌───────────────────────────┼───────────────────────────┐
         │                           │                           │
         ▼                           ▼                           ▼
┌─────────────────┐    ┌─────────────────────┐    ┌──────────────────────┐
│   Keycloak      │    │   HashiCorp Vault   │    │   Kong API Gateway   │
│   (identidad)   │    │   (PKI + secretos)  │    │   (PEP enforcement)  │
│                 │    │                     │    │                      │
│ • Autenticación │    │ • Ed25519 signing   │    │ • JWT validation     │
│ • User federation│   │ • X.509 certs       │    │ • Rate limiting      │
│ • Social login  │    │ • Transit encrypt   │    │ • mTLS termination   │
│ • SAML broker   │    │ • Dynamic creds     │    │ • Header injection   │
└────────┬────────┘    └──────────┬──────────┘    └──────────┬───────────┘
         │                        │                          │
         └────────────────────────┼──────────────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
          ┌──────────────────┐    ┌──────────────────────────┐
          │  Besu / Arbitrum │    │  bnotify (sbos-notifier) │
          │  (blockchain D12)│    │  (notificaciones)        │
          │                  │    │                          │
          │ • Merkle anchor  │    │ • Apprise 100+ providers │
          │ • Settlement     │    │ • Centrifugo WebSocket   │
          │ • DID registry   │    │ • Mattermost #seguridad  │
          └──────────────────┘    └──────────────────────────┘
```

### Reconcile Loop (60s) — El corazón del runtime

```
bauth_db (fuente de verdad)
  │
  └── Reconcile loop (cada 60s):
        ├── check_policy_drift(): compara cfg_policy_library vs ath_policy_d1..d12
        ├── reevaluate_active_contexts(): invalida sesiones cuyo RolBitMask cambió
        ├── invalidate_expired_sessions(): marca EXPIRED en ses_context
        ├── emit_caep_events(): session-revoked, assurance-level-change
        └── Si KC está configurado:
              ├── sync_roles(): RolTemplate → KC Composite Roles + Realm Roles
              ├── sync_users(): UserTemplate → KC User Attributes + Groups
              └── reconcile(): detecta drift en KC → revierte a verdad de bauth_db
```

### Principio de Soberanía

> **`bauth_db` es la ÚNICA fuente de verdad.** Ni Keycloak ni Vault ni Kong tienen
> autoridad para modificar la identidad. Si un motor tiene estado que no coincide
> con `bauth_db`, es **drift** — bAuth lo revierte automáticamente.

### Código fuente

| Archivo | Responsabilidad |
|---------|----------------|
| `engine/mod.rs` | Trait `AuthEngine` + `EngineRegistry`: registro de motores externos |
| `engine/keycloak_engine.rs` | Cliente Admin REST API Keycloak 26.x (532 líneas) — **UNO de los motores** |
| `engine/vault_engine.rs` | Vault PKI client: emisión/revocación de certificados X.509 |
| `sync/mod.rs` | `reconcile_loop()`: 4 verificaciones cada 60s, independiente de KC |
| `server/handlers/keycloak_sync.rs` | 6 handlers: status, sync, reconcile, sync_flow, sync_roles, reconcile_full |
| `server/handlers/oidc_provider.rs` | **OIDC Provider nativo de bAuth** — independiente de Keycloak |
| `server/handlers/kong_oauth.rs` | Kong PEP + OAuth2-Proxy: bAuth como backend de validación |
| `domain/auth_methods/` | 8+ validadores nativos — bAuth valida credenciales sin depender de KC |

---

## S10 — Motor de Sagas (Flujos Multi-Paso)

**Propósito:** Ejecutar flujos de autenticación multi-paso con compensación atómica.
Si un paso falla, se ejecutan las compensaciones en orden inverso.

**Sagas implementadas:**
- Login Saga: verify_argon2id → check_hibp → record_attempt → issue_token
- Recovery Saga: verify_identity → send_code → verify_code → reset_password

### Código fuente

| Archivo | Responsabilidad |
|---------|----------------|
| `saga/action.rs` | `SagaAction`, `SagaResult`, `SagaStatus` |
| `saga/step.rs` | `SagaStep`, `SagaOp` (10 operaciones) |
| `saga/executor.rs` | Motor de ejecución con timeout y compensación |
| `saga/registry.rs` | `ActionRegistry`: catálogo de acciones disponibles |
| `saga/catalog.rs` | Carga sagas desde `bauth.bos_saga` |
| `saga/validator.rs` | Validador de pre/post condiciones |
| `saga/actions/hibp.rs` | HIBP k-anonymity (NIST SP 800-63B §5.1.1.2) |
| `saga/actions/login.rs` | Login flow: Argon2id + registro de intentos |

---

## S11 — Motor de Firmas Digitales

**Propósito:** Doble motor de firmas: interno (Vault Ed25519 para operaciones SBOS) +
externo (ADSIB Bolivia RSA-SHA256 para facturación SIN, Ley 164).

### Código fuente

| Archivo | Responsabilidad |
|---------|----------------|
| `domain/jwt_signer.rs` | `JwtSigner`: firma Ed25519 (Vault PKI) + RSA-SHA256 (ADSIB) |
| `server/handlers/sign_internal.rs` | `bauth.sign.internal`: firma digital interna |
| `engine/vault_engine.rs` | `VaultPkiClient`: emisión/revocación de certificados X.509 |

---

## S12 — Motor de Blockchain (D12)

**Propósito:** Anclaje Merkle de eventos de auditoría en Arbitrum One (Variante A) +
liquidación financiera en Hyperledger Besu QBFT (Variante B).

### Código fuente

| Archivo | Responsabilidad |
|---------|----------------|
| `blockchain/anchor.rs` | `PureAnchor`: ancla hash de evento en AuditAnchor.sol |
| `blockchain/settlement.rs` | `SettlementClient`, `ReconciliationEngine`, `CustodyEngine` |
| `domain/blockchain.rs` | `BlockchainEvaluator` (D12) |
| `domain/merkle.rs` | `MerkleTree`: construye árbol Merkle SHA-256 (RFC 6962 + Keccak-256) |
| `server/handlers/blockchain_panel.rs` | 6 handlers: batch.list, batch.detail, verify, recent, status, settlement.list |

---

## S13 — Motor de Notificaciones

**Propósito:** Sistema de notificaciones jerárquico: calendario → alarma → bnotify → Mattermost/email/SMS.

**Flujo completo:**
```
cal_alarm (next_trigger_at <= NOW())
  │
  ├── AlarmPoller (60s): consulta cal_alarm JOIN cal_event
  ├── Expande RRULE (RFC 5545) vía rrule_plpgsql.expand()
  ├── Construye payload JSON-RPC para bnotify.trigger
  ├── Invoca bnotify sobre /run/bos/bnotify.sock
  ├── INSERT en cal_notification_log (WORM)
  └── UPDATE cal_alarm.next_trigger_at
```

### Código fuente

| Archivo | Responsabilidad |
|---------|----------------|
| `domain/calendar_alarm.rs` | `AlarmPoller`: cron job 60s consultando cal_alarm |
| `domain/notify.rs` | `NotifyClient`: trait + `SbOsNotifierClient` (Unix socket) |
| `domain/notify_config.rs` | `NotifyConfig`: Mattermost URL/token, bnotify socket |
| `domain/security_notify.rs` | Alertas automáticas de seguridad → Mattermost #seguridad |
| `domain/hierarchical_notify.rs` | Notificación jerárquica: tenant → empresa → sucursal → usuario |
| `domain/user_notify.rs` | Notificaciones personales → DM al usuario |

---

## S14 — Motor de Dispositivos (Identity Hub)

**Propósito:** bAuth como Identity Hub agnóstico de dispositivo. Celular, anillo, reloj,
chip PUF, implante — cualquier dispositivo porta el ctx_id del usuario.

**8 categorías de dispositivos:**
MOBILE, WATCH, RING, IMPLANT, CARD, WEARABLE, IOT, CHIP

### Código fuente

| Archivo | Responsabilidad |
|---------|----------------|
| `server/handlers/device_identity.rs` | 4 handlers: register, attest, transfer, trust_score |
| `domain/notify.rs` | `send_push_challenge()` para MFA en dispositivo |

---

## S15 — Proveedor de Identidad Externo (IdP-as-a-Service)

**Propósito:** bAuth como proveedor de identidad multi-tenant para aplicaciones externas.
OIDC Discovery, SCIM v2, SAML, Tenant Isolation, Portal, Billing.

### Código fuente

| Archivo | Responsabilidad |
|---------|----------------|
| `server/handlers/idp_external.rs` | 12 handlers: discovery, isolation, federation, portal, billing, sla, saml, scim, branding, admin, compliance, residency |
| `server/handlers/commercial.rs` | 4 handlers: product.compliance, iam, trust, pricing |
| `server/handlers/oidc_provider.rs` | OIDC Provider nativo: discovery, token, introspect, userinfo |
| `server/handlers/scim_server.rs` | SCIM v2 server: Users, Groups, SPConfig, ResourceTypes, Schemas |

---

## S16 — Infraestructura y Operaciones

**Propósito:** Servicios de infraestructura: self-service para usuarios, Kong PEP,
OAuth2-Proxy, rate-limiting, DR, threat model, SDKS multi-lenguaje.
**Transporte:** JSON-RPC 2.0 sobre Unix socket `/run/bos/bauth.sock` (ADR-020 obligatorio).

### Código fuente

| Archivo | Responsabilidad |
|---------|----------------|
| `server/handlers/self_service.rs` | 5 handlers: password.change, mfa.enroll, recovery.initiate, session.list, session.revoke |
| `server/handlers/kong_oauth.rs` | 3 handlers: Kong PEP, OAuth2-Proxy config, rate-limiting por tier |
| `server/handlers/token_protocols.rs` | Token Exchange RFC 8693, DPoP RFC 9449, Introspection RFC 7662 |
| `sdk/mod.rs` | Contratos de API multi-lenguaje (Go, Python, JS/TS, Java) |
| `config/mod.rs` | Configuración TOML completa (454 líneas) |
| `db/mod.rs` | Acceso a PostgreSQL vía sqlx |
| `preflight.rs` | Verificación pre-arranque |
| `signal.rs` | Manejo de señales Unix |
| `server/unix_socket.rs` | Servidor Unix socket `/run/bos/bauth.sock` |
| `server/jsonrpc.rs` | Tipos JSON-RPC 2.0 + Dispatcher |
| `bin/bauthctl.rs` | CLI del daemon (9 subcomandos, 35 operaciones) |
| `bin/verify_policies.rs` | Verificador de políticas |
| `bin/bos_verify.rs` | Verificador Merkle Proof |
| `audit/mod.rs` | Auditoría WORM (ISO 27001 A.8.15) |

---

## S17 — bAuthDEV (RPC Tester para Desarrolladores)

**Propósito:** Plataforma de desarrollo para que programadores externos integren bAuth como
proveedor de autenticación en sus aplicaciones. Equivalente a Postman + Stripe Dashboard
para el ecosistema SBOS. **El desarrollador NUNCA escribe código de auth — solo consulta
`bos.GetContext()` y `bos.AccessEvaluate()`.**

**Stack:** Flutter 3.44+ + Material 3 · Dart ≥3.12 · Windows/Linux/macOS
**Carpeta:** `BauthAgent/src/bAuthDEV/`
**Transporte:** JSON-RPC 2.0 sobre Unix socket `/run/bos/bauth.sock` (ADR-020)

### Modelo de negocio: Dos fases

```
FASE 1 — TRIAL GRATUITO
  🆓 Sin costo. Tenant de prueba limitado:
  • 3 roles máximo, 50 usuarios, 3 dominios (D1, D3, D9)
  • 1 empresa, 1 sucursal, sin blockchain, sin firma ADSIB
  • Tokens con marca "TRIAL"

FASE 2 — CONTRATA PLAN
  💰 BASIC / PRO / ENTERPRISE
  • Tenant de producción completo
  • 12 dominios, blockchain D12, firma ADSIB
  • Soporte, SLAs, facturación
```

### Arquitectura de la aplicación

```
┌──────────────────────────────────────────────────────────┐
│  UI LAYER — Material 3 + tf_shadcn_flutter                │
│  Pantallas: Catálogo · Editor RPC · Resultados            │
├──────────────────────────────────────────────────────────┤
│  SERVICE LAYER                                            │
│  JsonRpcClient (Unix socket) · MethodCatalog              │
├──────────────────────────────────────────────────────────┤
│  TRANSPORT — WebSocket + JSON-RPC 2.0                     │
│  ws://unix:/run/bos/bauth.sock                            │
└──────────────────────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│  BAUTH DAEMON (Rust, host)                                │
│  108 handlers JSON-RPC · 12 dominios · PostgreSQL 18.4    │
└──────────────────────────────────────────────────────────┘
```

### Funcionalidades principales

| Funcionalidad | Descripción | Pantalla/Widget |
|--------------|------------|-----------------|
| **Explorador de Catálogo** | Navegar 108+ métodos JSON-RPC agrupados por dominio | `catalogo_screen.dart` |
| **Cinta de Bloques** | Construir llamadas RPC arrastrando bloques (método + params) | `cinta_bloques.dart` |
| **Editor RPC** | Editar y ejecutar llamadas JSON-RPC manualmente | `editor_rpc.dart` |
| **Cliente JSON-RPC** | Cliente WebSocket que habla con `/run/bos/bauth.sock` | `rpc_client.dart` |
| **Catálogo de Métodos** | Metadata de 108+ métodos con descripciones, params, ejemplos | `method_catalog.dart` |
| **Barra de Estado** | Estado de conexión, tenant activo, rate limits | `status_bar.dart` |
| **Tenant de Prueba** | Entorno sandbox con límites para desarrolladores | Configuración inicial |
| **Snippets de Código** | Generar snippets Go/Python/JS para cada llamada RPC | (planeado) |

### El flujo del desarrollador

```
1. Descarga bAuthDEV → instala → ejecuta
2. Se conecta al tenant de prueba (automático)
3. Explora el catálogo de métodos RPC
4. Arma sus primeras llamadas: health.check → token.issue → access.evaluate
5. Ve respuestas en tiempo real con syntax highlighting
6. Copia el snippet de código generado a su proyecto
7. FASE 2: Contrata plan → recibe tenant de producción → migra su integración
```

### Código fuente

| Archivo | Líneas | Responsabilidad |
|---------|:---:|---------|
| `bAuthDEV/lib/main.dart` | 30 | Entry point, tema, ruteo inicial |
| `bAuthDEV/lib/app.dart` | 40 | Configuración de la app, providers |
| `bAuthDEV/lib/services/rpc_client.dart` | 90 | Cliente JSON-RPC 2.0 sobre WebSocket Unix socket |
| `bAuthDEV/lib/services/method_catalog.dart` | 50 | Catálogo de métodos con metadata (nombre, params, ejemplo, dominio) |
| `bAuthDEV/lib/screens/catalogo/catalogo_screen.dart` | 55 | Pantalla de exploración del catálogo RPC |
| `bAuthDEV/lib/widgets/cinta_bloques.dart` | 161 | Constructor visual de llamadas RPC (bloques arrastrables) |
| `bAuthDEV/lib/widgets/editor_rpc.dart` | 151 | Editor JSON-RPC manual con syntax highlighting |
| `bAuthDEV/lib/widgets/status_bar.dart` | 32 | Barra de estado: conexión, tenant, latency |

### Documentos de diseño

| Documento | Líneas | Contenido |
|-----------|:---:|------|
| `desktop/PLAN-BAUTHDEV-RPC-TESTER.md` | ~600 | Plan maestro: propósito, arquitectura, modelo de negocio, funcionalidades |
| `desktop/DESIGN-BAUTHDEV.md` | 3,317 | Diseño detallado: wireframes, flujos de usuario, componentes UI, especificaciones |

### Integración con el ecosistema

```
DESARROLLADOR EXTERNO               SBOS (nuestra infraestructura)
─────────────────────               ─────────────────────────────
Su app → bAuthDEV (pruebas)         bAuthDEV → /run/bos/bauth.sock → bAuth daemon
Su app → SDK (Go/Python/JS)         SDK → JSON-RPC → bAuth daemon
Su app → Kong API Gateway           Kong → valida JWT con bAuth → permite/deniega
```

---

## S18 — Dashboard Soberano de Administración (PAP)

**Propósito:** PAP (Policy Administration Point) del ecosistema. Dashboard completo
con **backend Rust** (10 handlers JSON-RPC) + **frontend Flutter** (13 paneles visuales).
Único lugar donde un administrador puede crear, editar, publicar y sincronizar Roles
y Usuarios sobre los 12 dominios de control.

**Transporte:** WebSocket + JSON-RPC 2.0 sobre Unix socket `/run/bos/bauth.sock` (ADR-020 obligatorio).
Tanto el backend (Rust handlers) como el frontend (Flutter) usan el MISMO socket.
**Sin HTTP, sin REST, sin SSH tunnel.** Todo vía RPC sobre el socket.

**Stack frontend:** Flutter 3.44+ + tf_shadcn_flutter + fl_chart + pluto_grid · Dart ≥3.4.0
**Stack backend:** Rust handlers JSON-RPC en `server/handlers/dashboard_panels.rs`
**Carpeta frontend:** `BauthAgent/src/desktop/`
**Plataformas:** Windows, Linux, macOS (primarias) · Android/iOS (pospuesto)

### Reglas irrenunciables

| # | Regla | Detalle |
|---|-------|---------|
| R1 | **Navegación total por teclado** | Toda función accesible sin mouse: `Tab`, `↑↓←→`, `Enter`, `Esc`, `Space` + atajos |
| R2 | **Conexión directa WebSocket** | Sin HTTP, sin REST, sin SSH tunnel. WebSocket puro al daemon |
| R3 | **Instalador autocontenido** | Descargar → ejecutar → conectado. Cero dependencias externas |
| R4 | **No ejecuta operaciones** | Toda mutación va vía JSON-RPC al daemon Rust. El desktop es solo renderizado |
| R5 | **Árbol jerárquico obligatorio** | Componente de árbol para dependencias, herencia DAG, y navegación de dominios |

### Arquitectura 4-capas

```
┌────────────────────────────────────────────────────────────┐
│              UI LAYER (Flutter)                              │
│  Pantallas · Widgets · Árboles · Formularios · Gráficos     │
├────────────────────────────────────────────────────────────┤
│           STATE LAYER (Riverpod)                             │
│  Providers · Notifiers · AsyncValue · Cache TTL              │
├────────────────────────────────────────────────────────────┤
│          SERVICE LAYER (Dart)                                │
│  JsonRpcClient (Unix socket) · DomainTreeBuilder             │
│  AtomCatalogResolver · RolePublisher                         │
├────────────────────────────────────────────────────────────┤
│         TRANSPORT LAYER (WebSocket)                          │
│  ws://unix:/run/bos/bauth.sock → JSON-RPC 2.0               │
└────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌────────────────────────────────────────────────────────────┐
│         BAUTH DAEMON (Rust, systemd host)                    │
│  108 handlers JSON-RPC · BitMask Dual · 12 dominios          │
│  PostgreSQL 18.4 · Redis 8.6.2                               │
└────────────────────────────────────────────────────────────┘
```

### Decisiones de arquitectura

| Decisión | Elección | Justificación |
|----------|----------|---------------|
| **Framework UI** | `tf_shadcn_flutter` ^0.0.53+1 | 84+ componentes, árbol nativo (`TreeNodeData`), desktop-first, responsive |
| **State management** | Riverpod 2.x | Providers declarativos, `AsyncValue` para loading/error/data, cache |
| **Tablas avanzadas** | `pluto_grid` | Sort, filtro, paginación, columnas ocultables |
| **Gráficos** | `fl_chart` | MIT license, liviano, sin dependencia Material |
| **Tema visual** | **ForUI SSOT** (tokens) → `ShadThemeData` | Gobernanza SBOS-010 |
| **Ruteo** | `go_router` | Navegación declarativa, deep links, breadcrumbs |

### Backend — Handlers JSON-RPC (10 handlers en Rust)

El Dashboard NO consulta la DB directamente. Cada panel invoca su handler JSON-RPC
sobre `/run/bos/bauth.sock`. El handler ejecuta queries SQL y retorna JSON al frontend.

| Handler | Método JSON-RPC | Archivo | Widgets |
|---------|----------------|---------|---------|
| Panel1Handler | `bauth.dashboard.panel1` | `dashboard_panels.rs` | Login attempts 1h, MFA rate, active sessions, failures 5min |
| Panel1bHandler | `bauth.dashboard.panel1b` | `dashboard_panels.rs` | 13 KPIs: MFA coverage, orphan accounts, SoD, machine identities |
| Panel4Handler | `bauth.dashboard.panel4` | `dashboard_panels.rs` | 12 tabs D1-D12: políticas activas + configs + estándares |
| Panel78Handler | `bauth.dashboard.panel78` | `dashboard_panels.rs` | Sync log 50 últimas, ctx_count activos, menu_tree 200 ítems |
| Panel9Handler | `bauth.dashboard.panel9` | `dashboard_panels.rs` | Timeline UNION ALL (login+session+audit) por ctx_id, búsqueda por usuario |
| Panel9bHandler | `bauth.dashboard.panel9b` | `dashboard_panels.rs` | Hash-chain verification + Merkle proof desde blk_merkle_leaf |
| Panel10Handler | `bauth.dashboard.panel10` | `dashboard_panels.rs` | Dispositivos físicos (net_device) + user_client_device por usuario |
| Panel11Handler | `bauth.dashboard.panel11` | `dashboard_panels.rs` | 5,808 átomos por dominio + roles con bitmask |
| Panel12Handler | `bauth.dashboard.panel12` | `dashboard_panels.rs` | Políticas activas 12 dominios + evaluation layers |
| Panel13Handler | `bauth.dashboard.panel13` | `dashboard_panels.rs` | Últimos 20 anclajes + estado reconciliación on-chain |

### Paneles del Dashboard (13 paneles)

| Panel | Propósito | Backend handler |
|-------|---------|----------------|
| **Panel 1** — KPIs Tiempo Real | Login attempts, MFA rate, active sessions, failures (refresh 10-300s) | `bauth.dashboard.panel1` |
| **Panel 1b** — Zero Trust | 13 KPIs: MFA coverage, orphan accounts, SoD violations, machine identities | `bauth.dashboard.panel1b` |
| **Panel 2** — Catálogo de Roles | 66 plantillas base + roles oficiales con árbol de herencia DAG | `bauth.role.template.*` |
| **Panel 3** — Catálogo de Usuarios | Usuarios con filtros por tenant/empresa/sucursal/rol/estado | `bauth.user.*` |
| **Panel 4** — Biblioteca Políticas | 12 tabs D1-D12 con políticas, configs, estándares | `bauth.dashboard.panel4` |
| **Panel 5** — Auditoría | Eventos de seguridad, timeline, filtros por ctx_id/usuario/IP | `bauth.domain.audit` |
| **Panel 6** — Firmas Digitales | Emitir/verificar firmas Ed25519 (interna) + ADSIB (externa) | `bauth.sign.internal` |
| **Panel 7** — Sync Status | Estado sync KC+Tryton, delta drift, último timestamp | `bauth.sync.*` |
| **Panel 8** — Context Plane | Sesiones activas, ctx_id, transferencias, editor de menús | `bauth.ctx.*` |
| **Panel 9** — Trazabilidad Forense | Reconstruir TODO de un ctx_id: timeline unificado UNION ALL 5+ tablas | `bauth.dashboard.panel9` |
| **Panel 10** — Dispositivos | Mapa jerárquico edificio→piso→área→dispositivo, OSDP, atestaciones | `bauth.dashboard.panel10` |
| **Panel 11** — Motor BitMask | Visor 5,808 átomos, simulador, editor asignación átomo↔rol, XOR diff | `bauth.dashboard.panel11` |
| **Panel 12** — Motor Evaluación | Simulador con trace 3-capas (Fast/Policy/External), step-up editor | `bauth.dashboard.panel12` |
| **Panel 13** — Blockchain D12 | Anclajes, Merkle proof, reconciliación, Arbiscan link | `bauth.dashboard.panel13` |

### Flujo de administración de Roles (ejemplo)

```
1. Admin abre Dashboard → Panel 2 (Catálogo de Roles)
2. Expande árbol D1-D12 → selecciona dominio → ve políticas/configs/templates
3. "Nuevo Rol" → popup con 66 plantillas base → selecciona "Cajero Genérico"
4. Clona → ajusta: límite diario, horario, sucursal, métodos MFA
5. Valida → Conflict Matrix muestra 0 conflictos SoD
6. Publica → Dashboard invoca bauth.role.template.create → bAuth sync a KC
7. Panel 7 muestra sync_status = SYNCED en < 5s
```

### Código fuente

| Archivo | Líneas | Responsabilidad |
|---------|:---:|---------|
| `desktop/DESIGN-DESKTOP-BAUTH.md` | 1,981 | Diseño detallado: wireframes, componentes, flujos de usuario |
| `desktop/DESIGN-BAUTHDEV.md` | 3,317 | Diseño compartido con bAuthDEV: tema, componentes base, RPC client |
| `desktop/PLAN-DESKTOP-BAUTH.md` | ~600 | Plan maestro: arquitectura, stack, reglas, paneles |
| `desktop/PLAN-BAUTHDEV-RPC-TESTER.md` | ~600 | Plan del RPC tester: propósito, modelo de negocio, funcionalidades |
| `desktop/ESPECIFICACION-MODALES-APP-MODULO-VERBO.md` | — | Especificación de modales para apps, módulos y verbos |
| `desktop/ESPECIFICACION-MODALES-POLITICAS-CONFIGURACIONES.md` | — | Especificación de modales para políticas y configuraciones |
| `desktop/bAuth Desktop.html` | — | Prototipo HTML del dashboard con diseño visual |

### Relación entre Dashboard y bAuthDEV

```
bAuthDEV (S18)                        Dashboard (S19)
─────────────────                     ─────────────────
Para: DESARROLLADORES externos        Para: ADMINISTRADORES del SBOS
Objetivo: Integrar bAuth en su app    Objetivo: Gestionar identidad completa
Alcance: Pruebas, snippets, trial     Alcance: CRUD roles/usuarios, sync, auditoría
Tenant: Prueba (limitado)             Tenant: Producción (completo)
Stack: Mismo (Flutter + JSON-RPC)     Stack: Mismo (Flutter + JSON-RPC)
Transporte: /run/bos/bauth.sock       Transporte: /run/bos/bauth.sock
```

Ambos comparten el mismo cliente JSON-RPC, tema ForUI, y componentes base.
La diferencia es el **propósito**: uno es para integrar, el otro para administrar.

---

## RESUMEN — 18 Secciones Funcionales

| # | Sección | Handlers | Archivos | Estado |
|:--:|------|:---:|:---:|:---:|
| S1 | Motor de Dominios | 19 | 15 .rs | ✅ |
| S2 | Motor de Privilegios (BitMask) | 6 | 11 .rs | ✅ |
| S3 | Motor de Métodos | 4 | 12 .rs | ✅ |
| S4 | Motor de Políticas (XACML) | 12 | 10 .rs | ✅ |
| S5 | Motor de Identidad (JWT) | 8 | 4 .rs | ✅ |
| S6 | Motor de Roles | 12 | 10 .rs | ⚠️ 87 átomos V2 |
| S7 | Motor de Usuarios | 8 | 4 .rs | ⚠️ 32 átomos V2 |
| S8 | Motor de Contexto | 8 | 5 .rs | ✅ |
| S9 | Orquestador de Motores Externos | 8 | 8 .rs | ⚠️ 20 átomos V2 |
| S10 | Motor de Sagas | 2 | 8 .rs | ⚠️ 26 átomos V2 |
| S11 | Motor de Firmas | 1 | 2 .rs | ⚠️ 17 átomos V2 |
| S12 | Motor de Blockchain | 6 | 4 .rs | ✅ |
| S13 | Motor de Notificaciones | 3 | 5 .rs | ✅ |
| S14 | Motor de Dispositivos | 4 | 2 .rs | ✅ |
| S15 | IdP Externo | 16 | 5 .rs | ⚠️ 12 átomos V2 |
| S16 | Infraestructura | 18 | 14 .rs | ⚠️ varios gates |
| **S17** | **bAuthDEV (RPC Tester)** | — | **8 .dart** | ⚠️ Flutter, 646 LOC |
| **S18** | **Dashboard Soberano (PAP)** | **10** | **1 .rs + 7 docs** | ⚠️ backend ✅, frontend diseño |

---

**Documento generado a partir del análisis de 25,171 LOC Rust + 646 LOC Dart + 5,298 LOC docs.**
**108+ handlers JSON-RPC · 61 archivos handler · 18 secciones funcionales.**
**Referencia cruzada con REGISTRO-ESTADOV2.md para átomos pendientes.**

*BAUTH-CLASIFICACION-FUNCIONAL.md v1.2 · 2026-06-30*
