# MAPA-CODIGO.md — BauthAgent

> Índice exhaustivo del código implementado. **Consultar aquí antes de escribir código nuevo.**
> Última actualización: 2026-06-28 · Total: ~12,640 LOC · 115 archivos .rs

---

## 1. CATÁLOGO COMPLETO DE MÉTODOS JSON-RPC

Todos registrados en `src/main.rs` sobre el socket `/tmp/bauth/bauth.sock`.

### Salud y metadatos

| Método | Handler | Archivo |
|--------|---------|---------|
| `bauth.health.check` | `HealthHandler` | `server/handlers/health.rs` |
| `bauth.health.metrics` | `HealthMetricsHandler` | `server/handlers/health.rs` |
| `bauth.method.list` | `MethodListHandler` | `server/handlers/mod.rs` |
| `bauth.debug.methods` | (inline en main.rs) | `main.rs:378` |

### Token JWT

| Método | Handler | Archivo |
|--------|---------|---------|
| `bauth.token.issue` | `TokenIssueHandler` | `server/handlers/token_issue.rs` |
| `bauth.token.validate` | `TokenValidateHandler` | `server/handlers/token_validate.rs` |
| `bauth.token.jwks` | `TokenJwksHandler` | `server/handlers/token_jwks.rs` |
| `bauth.sign.internal` | `SignInternalHandler` | `server/handlers/sign_internal.rs` |

### BitMask / Roles

| Método | Handler | Archivo |
|--------|---------|---------|
| `bauth.role.compute_mask` | `RoleComputeMaskHandler` | `server/handlers/role_compute_mask.rs` |
| `bauth.role.template.list` | `RoleTemplateListHandler` | `server/handlers/role_template.rs` |
| `bauth.role.template.get` | `RoleTemplateGetHandler` | `server/handlers/role_template.rs` |
| `bauth.role.template.validate` | `RoleTemplateValidateHandler` | `server/handlers/role_template.rs` |
| `bauth.role.list` | `RoleListHandler` | `server/handlers/role_list.rs` |
| `bauth.role.merge` | `MergeRoleTemplatesHandler` | `server/handlers/merge_templates.rs` |

### Acceso y evaluación

| Método | Handler | Archivo |
|--------|---------|---------|
| `bauth.access.evaluate` | `AccessEvaluateHandler` | `server/handlers/access_evaluate.rs` |
| `bauth.inheritance.compute` | `InheritanceEvaluateHandler` | `server/handlers/inheritance_evaluate.rs` |
| `bauth.inheritance.check` | `InheritanceCheckHandler` | `server/handlers/inheritance_evaluate.rs` |
| `bauth.sod.check` | `SodCheckHandler` | `server/handlers/sod_check.rs` |
| `bauth.context.evaluate` | `ContextEvaluateHandler` | `server/handlers/context_evaluate.rs` |

### PolicyEngine (dos capas distintas)

| Método | Handler | Tabla origen | Archivo |
|--------|---------|-------------|---------|
| `bauth.policy.evaluate` | `PolicyEvaluateHandler` | `bos_atom_policy` (XACML format) | `server/handlers/policy_evaluate.rs` |
| `bauth.policy.domain.evaluate` | `PolicyDomainEvalHandler` | `ath_policy_dN` D1-D12 (simple `{"rule":"X"}`) | `server/handlers/policy_domain.rs` |
| `bauth.policy.domain.list` | `PolicyDomainListHandler` | `ath_policy_dN` D1-D12 | `server/handlers/policy_domain.rs` |
| `bauth.policy.library.search` | `PolicyLibrarySearchHandler` | `cfg_policy_library` (9,142 normas) | `server/handlers/policy_domain.rs` |
| `bauth.policy.fw.list` | `PolicyFwListHandler` | `cfg_validation_rule` (261 reglas de campo) | `server/handlers/framework_crud.rs` |
| `bauth.template.validate` | *(via rule_engine)* | `cfg_validation_rule` | `server/handlers/template_validate.rs` |

### Validación de plantillas

| Método | Handler | Archivo |
|--------|---------|---------|
| `bauth.template.validate` | `TemplateValidateHandler` | `server/handlers/template_validate.rs` |

### Contexto distribuido (SBOS-049)

| Método | Handler | Archivo |
|--------|---------|---------|
| `bauth.ctx.create` | `CtxCreateHandler` | `server/handlers/context_plane.rs` |
| `bauth.ctx.validate` | `CtxValidateHandler` | `server/handlers/ctx_validate.rs` |
| `bauth.ctx.promote` | `CtxPromoteHandler` | `server/handlers/context_plane.rs` |
| `bauth.ctx.invalidate` | `CtxInvalidateHandler` | `server/handlers/context_plane.rs` |
| `bauth.ctx.propagate` | `CtxPropagateHandler` | `server/handlers/context_plane.rs` |

### Sagas de autenticación

| Método | Handler | Archivo |
|--------|---------|---------|
| `bauth.saga.list` | `SagaListHandler` | `server/handlers/saga_list.rs` |
| `bauth.saga.execute` | `SagaExecuteHandler` | `server/handlers/saga_execute.rs` |

### Usuarios y tenants

| Método | Handler | Archivo |
|--------|---------|---------|
| `bauth.user.list` | `UserListHandler` | `server/handlers/user_list.rs` |
| `bauth.tenant.list` | `TenantListHandler` | `server/handlers/tenant_list.rs` |

### Sincronización KC↔Tryton

| Método | Handler | Archivo |
|--------|---------|---------|
| `bauth.sync.reconcile` | `SyncReconcileHandler` | `server/handlers/sync_reconcile.rs` |
| `bauth.sync.status` | `SyncStatusHandler` | `server/handlers/sync_status.rs` |

### Dominios D1-D12 (list por dominio)

| Método | Handler | Archivo |
|--------|---------|---------|
| `bauth.domain.logical.list` | `DomainLogicalListHandler` | `server/handlers/domain_logical.rs` |
| `bauth.domain.physical.list` | `DomainPhysicalListHandler` | `server/handlers/domain_physical.rs` |
| `bauth.domain.financial.list` | `DomainFinancialListHandler` | `server/handlers/domain_financial.rs` |
| `bauth.domain.biometric.list` | `DomainBiometricListHandler` | `server/handlers/domain_biometric.rs` |
| `bauth.domain.temporal.list` | `DomainTemporalListHandler` | `server/handlers/domain_temporal.rs` |
| `bauth.domain.geospatial.list` | `DomainGeospatialListHandler` | `server/handlers/domain_geospatial.rs` |
| `bauth.domain.network.list` | `DomainNetworkListHandler` | `server/handlers/domain_network.rs` |
| `bauth.domain.audit` | `DomainAuditHandler` | `server/handlers/domain_audit.rs` |
| `bauth.domain.config.list` | *(domain_remaining)* | `server/handlers/domain_remaining.rs` |
| D8-D12 evaluación directa | via `bauth.policy.domain.evaluate` | `server/handlers/policy_domain.rs` |

### Blockchain D12 (Hyperledger Besu)

| Método | Handler | Archivo |
|--------|---------|---------|
| `bauth.blockchain.batch.list` | `BlockchainBatchListHandler` | `server/handlers/blockchain_panel.rs` |
| `bauth.blockchain.batch.detail` | `BlockchainBatchDetailHandler` | `server/handlers/blockchain_panel.rs` |
| `bauth.blockchain.verify` | `BlockchainVerifyHandler` | `server/handlers/blockchain_panel.rs` |
| `bauth.blockchain.recent` | `BlockchainRecentHandler` | `server/handlers/blockchain_panel.rs` |
| `bauth.blockchain.status` | `BlockchainStatusHandler` | `server/handlers/blockchain_panel.rs` |
| `bauth.blockchain.settlement.list` | `BlockchainSettlementListHandler` | `server/handlers/blockchain_panel.rs` |

### Comercial / Producto (IDP externo)

| Método | Handler | Archivo |
|--------|---------|---------|
| `bauth.product.compliance` | `ProductComplianceHandler` | `server/handlers/commercial.rs` |
| `bauth.product.iam` | `ProductIamHandler` | `server/handlers/commercial.rs` |
| `bauth.product.trust` | `ProductTrustHandler` | `server/handlers/commercial.rs` |
| `bauth.product.pricing` | `ProductPricingHandler` | `server/handlers/commercial.rs` |
| `bauth.idp.discovery/isolation/federation/portal/billing/sla/saml/scim/branding/admin/compliance/residency` | múltiples handlers | `server/handlers/idp_external.rs` |

### Configuración y criptografía

| Método | Handler | Archivo |
|--------|---------|---------|
| `bauth.config.list` | `ConfigListHandler` | `server/handlers/mod.rs` |
| `bauth.crypto.list` | `CryptoListHandler` | `server/handlers/mod.rs` |
| `bauth.federation.list` | `FederationListHandler` | `server/handlers/mod.rs` |
| `bauth.compliance.list` | `ComplianceListHandler` | `server/handlers/mod.rs` |

---

## 2. MÓDULOS DE DOMINIO

### `domain/policy/` — Motor de Políticas XACML 3.0

> **ADVERTENCIA**: Este módulo tiene DOS capas de evaluación distintas.

| Archivo | Qué hace | Cuándo usar |
|---------|---------|------------|
| `rule.rs` | Tipos: `PolicyRule`, `PolicyResult`, `PolicyData`, `LogicOp` | Siempre — son los tipos base |
| `condition.rs` | `PolicyCondition`, `CompareOp` (17 variantes), `ConditionDetail` | Para construir condiciones |
| `evaluate.rs` | `eval_condition()`, `eval_rule()`, `evaluate(rules, ctx)` | Motor de evaluación principal |
| `resolver.rs` | `resolve_value()`, `resolve_conditions()`, `haversine_km()`, `simple_cidr_match()`, `ip_to_u32()` | Resolver valores y operaciones especiales |
| `parser.rs` | `validate_policy_schema()`, `parse_policy_data()`, `from_policy_data()`, `load_from_json()`, `detect_conflicts()` | Para políticas en formato XACML `bos_policy_v1` |
| `ath_converter.rs` | `convert(slug, name, config, priority, domain)` → `Option<PolicyRule>` | **B9.T24**: convierte `{"rule":"X",...}` de `ath_policy_dN` → `PolicyRule` |
| `ath_loader.rs` | `load_domain(pg, domain)`, `load_all(pg)` | **B9.T24**: carga `ath_policy_dN` D1-D12 desde PostgreSQL |
| `mod.rs` | `PolicyEngine` struct + `EvalContext = HashMap<String, Value>`, `PolicyState` | Punto de entrada |

**Dos fuentes de políticas evaluables en runtime:**
- `bos_atom_policy` → `parser.rs` → `bauth.policy.evaluate` (formato XACML complejo)
- `ath_policy_dN` → `ath_converter.rs` → `bauth.policy.domain.evaluate` (formato `{"rule":"X"}`)

**Tabla NO evaluable en runtime** (solo referencia normativa):
- `cfg_policy_library` (9,142 entradas): consultable vía `bauth.policy.library.search`
- `cfg_validation_rule` (261 reglas de campo): usada por `RuleEngine` para validar plantillas

### `domain/bitmask.rs` + `bitmask/` — BitMask Dual 64-bit

| Archivo | Qué hace |
|---------|---------|
| `bitmask/atom.rs` | `AtomBitMask(u64)`, `AtomPosition`, `TrustLevel`, `TokenBinding`, `DeviceCategories` |
| `bitmask/catalog.rs` | `AtomCatalog`, `AtomRecord` — catálogo en memoria de todos los átomos; `validate_seeds()` |
| `bitmask/registry.rs` | `DomainRegistry`, `DomainConfig`, `DomainEvaluator` trait, `DomainResult` — orquesta D1-D12 |
| `bitmask/rol.rs` | `RolBitMask` — el BitMask de rol `u64` (átomos) + segundo `u64` (contexto) |
| `bitmask/resolver.rs` | `compute_rol_bitmask()`, `inherit_from_parents()`, `AtomPositionResolver`, serializar/deserializar |
| `bitmask/closure.rs` | `ClosureTableEngine`, `ClosureEdge` — cierre transitivo de herencia de roles |
| `bitmask/conflict.rs` | `ConflictMatrix`, `SodConflict`, `merge_roles_with_sod()`, `MergeResult` |
| `bitmask/serializer.rs` | `BosJwtClaims` — claims del JWT bAuth incluyendo `rol_bitmask` Base64 |
| `bitmask/fastpath.rs` | `fastpath_check(rol, position)`, `benchmark_check()` — verificación O(1) sin BD |
| `bitmask/policy.rs` | `PolicyState` enum: `Aprobado`, `Rechazado`, `Pendiente`, `NoAplica` |

### `domain/` — Evaluadores D1-D12

Todos implementan el trait `DomainEvaluator` de `bitmask/registry.rs`.

| Archivo | Dominio | Evaluador |
|---------|---------|----------|
| `domain/logical.rs` | D1 Lógico | `LogicalEvaluator` — scope, max_records, data_clearance |
| `domain/physical.rs` | D2 Físico | `PhysicalEvaluator` — device_trust, NFC, OSDP |
| `domain/financial.rs` | D3 Financiero | `FinancialEvaluator` — dual_approval, SoD, daily/monthly limits |
| `domain/temporal.rs` | D4 Temporal | `TemporalEvaluator` — schedule, session TTL, reauth |
| `domain/biometric.rs` | D5 Biométrico | `BiometricEvaluator` — liveness, score mínimo |
| `domain/geospatial.rs` | D6 Geoespacial | `GeospatialEvaluator` — geofence, country_allow, velocity |
| `domain/network.rs` | D7 Red | `NetworkEvaluator` — mTLS, VPN, rate limit, CIDR |
| `domain/context.rs` | D8 Contexto | `ContextEvaluator` — ctx_id, session_age, reauth_interval |
| `domain/credential.rs` | D9 Credenciales | `CredentialEvaluator` — MFA, HIBP, password policy, LoA |
| `domain/delegation.rs` | D10 Delegación | `DelegationEvaluator` — scopes delegados, tiempo |
| `domain/audit_domain.rs` | D11 Auditoría | `AuditDomainEvaluator` — audit_trail, retención |
| `domain/blockchain.rs` | D12 Blockchain | `BlockchainEvaluator` — on-chain audit, Besu ECDSA |

### `domain/` — Infraestructura de token y firma

| Archivo | Qué hace |
|---------|---------|
| `domain/jwt_builder.rs` | `JwtBuilder`, `BauthClaims`, `GeoClaim`, `AuthStep` — construye claims del JWT unificado |
| `domain/jwt_signer.rs` | `JwtSigner`, `SignedToken` — firma con Vault Ed25519 o ADSIB RS256 |
| `domain/jwe_encrypt.rs` | `JweEncryptor`, `JweToken` — cifra payload sensible (A256GCM) |
| `domain/merkle.rs` | `MerkleTree`, `MerkleProof`, `leaf_hash()`, `node_hash()` — árbol Merkle SHA-256 de claims D12 |
| `domain/policy_chain.rs` | `PolicyChainResolver`, `PolicyChainError` — aplica cadena PAP→PIP→PDP→PEP |
| `domain/rule_engine.rs` | `RuleEngine`, `ValidationRule`, `ValidationResult`, `ValidationReport` — valida campos JSONB contra `cfg_validation_rule` |
| `domain/merge.rs` | `merge_role_templates()`, `validate_merge_no_conflicts()`, `MergeResult` — fusiona 12 templates de rol |
| `domain/inheritance.rs` | Herencia de permisos entre roles (closure table) |
| `domain/sod/mod.rs` | SoD (Segregación de Funciones) — verifica conflictos antes de asignar |
| `domain/risk.rs` | `RiskContext`, `RiskScore`, `RiskFlag`, `RiskAction` — puntuación de riesgo contextual |
| `domain/health.rs` | Health checks de los subsistemas (PG, KC, Vault, Redis) |
| `domain/lifecycle.rs` | Ciclo de vida de usuario (activar, suspender, revocar) |
| `domain/config.rs` | Configuración de dominio por tenant |
| `domain/startup.rs` | Inicialización de catálogos al arranque |
| `domain/bitmask.rs` | Inicialización del BitMask (adapta `bitmask/` para uso en `domain/`) |
| `domain/password/mod.rs` | Políticas de contraseña (min_length, argon2id, historial) |

---

## 3. MÓDULO SAGAS — `saga/`

Sagas con compensación para flujos de autenticación multi-paso.

| Archivo | Tipos / Funciones principales |
|---------|------------------------------|
| `saga/action.rs` | `SagaAction`, `SagaResult`, `SagaStatus`, `SagaEvalContext`, `SequenceOp`, `CompensationStrategy` |
| `saga/step.rs` | `SagaStep`, `SagaOp`, `StepCondition`, `ConditionOp`, `StepDetail`, `StepStatus` |
| `saga/executor.rs` | `eval_condition()`, `validate_preconditions()`, `exec_step()`, `execute(saga, ctx)` |
| `saga/registry.rs` | `ActionRegistry`, `default_registry(pg, hibp_cfg)` — acciones disponibles por nombre |
| `saga/catalog.rs` | `load_all_sagas(pg)` — carga sagas desde `bauth.bos_saga` |
| `saga/validator.rs` | `validate_saga(action)` — valida schema antes de ejecutar |
| `saga/actions/hibp.rs` | `check_hibp(password, api_url, timeout_secs)`, `HibpResult` — verifica contraseñas comprometidas |
| `saga/actions/login.rs` | `verify_argon2id(hash, password)`, `record_failed_attempt(pg, user_id)` |
| `saga/actions/mod.rs` | Registro de acciones disponibles para el executor |

---

## 4. MÓDULO CONTEXTO — `context/`

Implementa el Plano de Contexto SBOS-049 (ctx_id W3C + OTel Baggage).

| Archivo | Tipos / Funciones principales |
|---------|------------------------------|
| `context/plane.rs` | `CtxPlane`, `CtxState` — estado de un ctx_id activo |
| `context/engine.rs` | `CtxEngine`, `CtxResult` — crea, valida, promovey propaga ctx_id |
| `context/mod.rs` | Re-exporta lo anterior |

---

## 5. MÓDULO BLOCKCHAIN — `blockchain/`

Integración con Hyperledger Besu para D12.

| Archivo | Tipos / Funciones principales |
|---------|------------------------------|
| `blockchain/anchor.rs` | `PureAnchor`, `AnchorReceipt` — ancla hash de evento en Besu |
| `blockchain/settlement.rs` | `SettlementClient`, `ReconciliationEngine`, `CustodyEngine`, `Settlement`, `SettlementStatus` — liquidación y custodia |
| `blockchain/mod.rs` | Re-exporta ambos módulos |

---

## 6. SERVIDOR — `server/`

| Archivo | Qué hace |
|---------|---------|
| `server/jsonrpc.rs` | `JsonRpcDispatcher`, trait `JsonRpcHandler` — despacha métodos a handlers |
| `server/unix_socket.rs` | Escucha en `/tmp/bauth/bauth.sock`, acepta conexiones |
| `server/websocket.rs` | Vía 1 WebSocket RPC para bauthctl CLI y Core UI |
| `server/mod.rs` | Inicializa el servidor completo |
| `server/handlers/mod.rs` | Declara todos los sub-módulos de handlers |

### Archivo huérfano (NO registrado en mod.rs ni main.rs)

| Archivo | Contenido | Acción para activar |
|---------|----------|---------------------|
| `server/handlers/domain_remaining.rs` | `CredentialAtomsHandler`, `DelegationAtomsHandler`, `AuditAtomsHandler`, `BlockchainAtomsHandler` — lista átomos de `privilege_atom` para D9-D12 | Agregar `pub mod domain_remaining;` en `mod.rs` y registrar en `main.rs`. Útil para `bauth.domain.credential.list` (átomos), distinto de `bauth.policy.domain.evaluate` (políticas D9-D12). |

---

## 7. INFRAESTRUCTURA — `bitmask/`, `catalog/`, `config/`, `db/`, `context/`

| Archivo | Qué hace |
|---------|---------|
| `config/mod.rs` | `BauthConfig`, `JwtConfig`, `HibpConfig`, `VaultConfig` — carga `bauth.toml` |
| `db/mod.rs` | `DbContext` — pool de conexiones sqlx a PostgreSQL |
| `catalog/startup.rs` | `load_catalogs()` — precarga catálogos en memoria al arranque |
| `engine/mod.rs` | `AuthEngine` — orquestador principal: recibe request, aplica cadena D1-D12 |
| `audit/mod.rs` | Registra eventos en `bauth.audit_log` |
| `sync/mod.rs` | Loop de reconciliación KC↔Tryton cada 60s |
| `preflight.rs` | `run_preflight()` — verifica PG, KC, Vault, Redis antes de iniciar |
| `signal.rs` | Manejo de SIGTERM/SIGINT/SIGHUP para shutdown limpio |
| `util/mod.rs` | Utilidades (UUIDv7, timestamps, hex encoding) |

---

## 8. BINARIOS AUXILIARES — `bin/`

| Binario | Propósito |
|---------|----------|
| `bin/bauthctl.rs` | CLI de administración — llama JSON-RPC sobre el socket |
| `bin/verify_policies.rs` | Valida políticas en `bos_atom_policy` contra el schema XACML |
| `bin/bos_verify.rs` | Verificación de integridad del binario (Ed25519) |

---

## 9. TABLAS DE BASE DE DATOS (referencia rápida)

| Tabla | Módulo que la usa | Propósito |
|-------|-------------------|----------|
| `bauth.ath_policy_d1..d12` | `ath_loader.rs` + `policy_domain.rs` | Políticas operativas por dominio (`{"rule":"X"}`) |
| `bauth.cfg_policy_library` | `policy_domain.rs` (library.search) | 9,142 normas ISO/NIST/COBIT (solo consulta) |
| `bauth.cfg_validation_rule` | `rule_engine.rs` + `template_validate.rs` | 261 reglas de validación de campos JSONB |
| `bauth.bos_atom_policy` | `parser.rs` + `policy_evaluate.rs` | Políticas XACML `bos_policy_v1` sobre átomos |
| `bauth.idn_rol_template` | `role_template.rs` + `merge.rs` | Contratos de rol (14 secciones JSONB) |
| `bauth.idn_user_template` | `user_list.rs` + `token_issue.rs` | Contratos de usuario (15 secciones JSONB) |
| `bauth.bos_saga` | `catalog.rs` (saga) | Sagas de autenticación registradas |
| `bauth.audit_log` | `audit/mod.rs` | Registro de eventos de seguridad |
| `bauth.ctx_registry` | `context/engine.rs` | Contextos activos (ctx_id) |
| `bos.blockchain_batch` | `blockchain_panel.rs` | Lotes de eventos anclados en Besu |

---

## 10. REGLAS PARA NO DUPLICAR CÓDIGO

1. **Antes de crear un evaluador de dominio**: verificar sección 2 — los 12 `XxxEvaluator` ya existen.
2. **Antes de crear validación de campos**: usar `RuleEngine` + `cfg_validation_rule`, no lógica ad-hoc.
3. **Antes de crear evaluación de políticas**: definir si es `ath_policy_dN` (→ `ath_converter/loader`) o `bos_atom_policy` (→ `parser.rs`).
4. **Antes de firmar un JWT**: usar `JwtSigner` + `JwtBuilder`, no reinventar claims.
5. **Antes de verificar HIBP**: usar `saga/actions/hibp.rs::check_hibp()`.
6. **Antes de hash de contraseña**: usar `saga/actions/login.rs::verify_argon2id()`.
7. **Antes de ctx_id**: usar `context/engine.rs::CtxEngine`, no generar UUID libre.
8. **Antes de acceso O(1) al BitMask**: usar `bitmask/fastpath.rs::fastpath_check()`.
9. **Antes de SoD**: usar `bitmask/conflict.rs::ConflictMatrix` + `merge_roles_with_sod()`.
10. **Todo handler nuevo**: registrar en `main.rs` + declarar en `server/handlers/mod.rs`.
