# BAUTH-PLAN-IMPLEMENTACION-GAPS.md — Lo que bAuth Debe Completar

**Versión:** 1.0.0 · **Fecha:** 2026-06-21 · **Autor:** sbos-coordinador + bauth  
**Propósito:** Documentar TODO lo que bAuth implementará para cubrir los gaps que
Keycloak 26.6.2 y Tryton no cubren, completando así el Authentication Framework.

---

## 1. Visión General

```
┌─────────────────────────────────────────────────────────────────┐
│              STACK COMPLETO DE AUTENTICACIÓN SBOS                 │
├──────────────┬──────────────────────────────────────────────────┤
│ Keycloak     │ Métodos (15) + Protocolos (10) + Federación      │
│ 26.6.2       │ + Tokens + Realms + MFA + Passkeys               │
│              │ ✅ YA OPERATIVO — 80% del framework              │
├──────────────┼──────────────────────────────────────────────────┤
│ Tryton       │ Fuente de verdad de identidad de negocio         │
│              │ res_users, res_company, res_branch, res_dept     │
│              │ ✅ YA OPERATIVO — fuente de datos               │
├──────────────┼──────────────────────────────────────────────────┤
│ bAuth        │ 🔧 LO QUE DEBEMOS CONSTRUIR NOSOTROS              │
│ (Rust)       │ Sagas + HIBP + Risk + SoD + PQC + Domain Reg.   │
│              │ + JSON-RPC CRUD + Sync + Offline Auth            │
│              │ 📋 15% del framework — ESTE DOCUMENTO           │
├──────────────┼──────────────────────────────────────────────────┤
│ Vault 2.0.1  │ Secretos, PKI, cifrado, Shamir unseal            │
│ Redis 8.6.2  │ Rate limiting, anti-replay, session cache        │
│ Kong 3.9.x   │ API Gateway, OIDC plugin, rate limiting edge     │
│ PostgreSQL   │ Framework tables (7 tablas declarativas)          │
│              │ ✅ YA OPERATIVO                                 │
├──────────────┼──────────────────────────────────────────────────┤
│ Externo      │ Teleport Community (PAM session recording)       │
│              │ api.pwnedpasswords.com (HIBP screening)          │
│              │ crates.io pqcrypto (post-quantum crypto)          │
│              │ 📋 5% del framework                             │
└──────────────┴──────────────────────────────────────────────────┘
```

---

## 2. Módulos a Implementar — 8 Fases

### FASE A: Motor de Sagas (src/saga/) — SEMANA 1-2

**Gap:** Keycloak no tiene orquestación de flujos de autenticación con compensación.
Tryton no tiene sagas.

**Qué construiremos — 8 archivos Rust (~1,340 líneas):**

| Archivo | Contenido | Estado |
|---------|-----------|--------|
| `src/saga/step.rs` | SagaOp (10 ops), SagaStep, StepCondition, StepDetail | 📋 |
| `src/saga/action.rs` | SagaAction, SequenceOp, CompensationStrategy, SagaResult | 📋 |
| `src/saga/executor.rs` | `exec_step()` + `execute()` + compensación inversa | 📋 |
| `src/saga/validator.rs` | `validate_saga()` — detección de ciclos DFS, 7 reglas | 📋 |
| `src/saga/resolver.rs` | `resolve_step_deps()` + topological sort | 📋 |
| `src/saga/catalog.rs` | `build_catalog()` — 12 sagas registradas desde BD | 📋 |
| `src/saga/mod.rs` | SagaOrchestrator + trait AuthenticationSaga | 📋 |
| `src/saga/tests.rs` | Tests de ejecución + compensación + ciclos | 📋 |

**Integración:**
```rust
// main.rs — Fase 2.5
let saga_catalog = db::load_all_sagas(&pg_pool).await?;
let orchestrator = Arc::new(SagaOrchestrator::from_catalog(saga_catalog));

// server/jsonrpc.rs — Nuevo handler
dispatcher.register("bauth.saga.execute", 
    Arc::new(SagaExecuteHandler { orchestrator: orchestrator.clone() }));
```

**JSON-RPC resultante:**
```json
// Invocación
{"method": "bauth.saga.execute", "params": {"saga": "auth.password.login", ...}}

// Respuesta
{"result": {"status": "completed", "steps_completed": 6, "output": {...}}}
```

---

### FASE B: HIBP k-anonymity Screening (S1 paso 2) — SEMANA 1

**Gap:** Ni Keycloak ni Tryton verifican passwords contra bases de datos de brechas.
NIST 800-63B Rev.4 lo exige como obligatorio.

**Qué construiremos:**

```rust
// src/saga/actions/hibp.rs
use sha1::{Sha1, Digest};
use reqwest::Client;

/// Verifica password contra Have I Been Pwned usando k-anonymity.
/// Solo envía los primeros 5 caracteres del hash SHA-1.
/// La comparación final es local — el servidor nunca ve el password.
pub async fn check_hibp_k_anon(password: &str) -> Result<HibpResult, HibpError> {
    let hash = Sha1::digest(password.as_bytes());
    let hash_hex = hex::encode(&hash).to_uppercase();
    let (prefix, suffix) = hash_hex.split_at(5);

    let client = Client::builder()
        .user_agent("sbos-bauth-v3.0.0")
        .build()?;

    let url = format!("https://api.pwnedpasswords.com/range/{}", prefix);
    let response = client.get(&url).send().await?;
    let body = response.text().await?;

    // Buscar suffix en la respuesta (formato: SUFFIX:COUNT)
    let breached = body.lines().any(|line| {
        line.starts_with(suffix)
    });

    Ok(HibpResult {
        breached,
        hash_prefix: prefix.to_string(),
        checked_at: chrono::Utc::now(),
    })
}
```

**Dependencia Cargo.toml:** `sha1 = "0.10"`, `hex = "0.4"` (ya existentes), `reqwest = { version = "0.12", features = ["rustls-tls"] }`

---

### FASE C: Motor de Risk Scoring Continuo (S1 paso 3, S11) — SEMANA 2-3

**Gap:** Keycloak tiene Conditional Authenticator pero no calcula risk scores numéricos
basados en múltiples factores ponderados. Tryton no tiene risk scoring.

**Qué construiremos:**

```rust
// src/domain/risk.rs — Risk Scoring Engine (Zero Trust NIST 800-207)

pub struct RiskContext {
    pub user_id: String,
    pub client_ip: String,
    pub device_fingerprint: String,
    pub geo_location: Option<(f64, f64)>,
    pub time_of_day: chrono::NaiveTime,
    pub login_history: Vec<LoginRecord>,
    pub known_device: bool,
    pub known_location: bool,
    pub vpn_detected: bool,
    pub tor_exit_node: bool,
}

pub struct RiskScore {
    pub total: f64,              // 0.0 (seguro) → 100.0 (crítico)
    pub identity_score: f64,     // 30% peso — ¿es quien dice ser?
    pub device_score: f64,       // 30% peso — ¿es su dispositivo habitual?
    pub network_score: f64,      // 20% peso — ¿IP conocida?, ¿VPN/Tor?
    pub behavioral_score: f64,   // 20% peso — ¿hora habitual?, ¿velocidad?
    pub flags: Vec<RiskFlag>,
}

#[derive(Debug)]
pub enum RiskFlag {
    NewDevice,
    NewLocation,
    ImpossibleTravel { from: String, distance_km: f64 },
    OutsideBusinessHours,
    TorExitNode,
    VpnDetected,
    HighVelocityAttempts,
    KnownCompromisedIp,
}

impl RiskScore {
    pub fn compute(ctx: &RiskContext) -> Self {
        let identity = Self::identity_factor(ctx);    // Redis lookup
        let device = Self::device_factor(ctx);         // fingerprint match
        let network = Self::network_factor(ctx);       // IP reputation
        let behavioral = Self::behavioral_factor(ctx); // time + velocity

        let total = identity * 0.30 + device * 0.30 
                  + network * 0.20 + behavioral * 0.20;

        RiskScore { total, identity_score: identity, 
                    device_score: device, network_score: network, 
                    behavioral_score: behavioral, flags: vec![] }
    }

    pub fn action(&self) -> RiskAction {
        match self.total {
            x if x < 25.0 => RiskAction::Allow,
            x if x < 50.0 => RiskAction::MfaRecommended,
            x if x < 75.0 => RiskAction::MfaRequired,
            _             => RiskAction::Deny,
        }
    }
}
```

**Almacenamiento:** Redis sliding window para velocity tracking + PostgreSQL para
historial de logins. Las IPs de Tor se validan contra lista local actualizable.

---

### FASE D: SoD Conflict Matrix (B1.T16) — SEMANA 3

**Gap:** Keycloak tiene roles pero no Separación de Funciones (SoD) estática ni dinámica.
NIST SP 800-53 Rev.5 AC-5 lo requiere.

**Qué construiremos:**

```rust
// src/domain/sod.rs — Separation of Duties Engine

/// Matriz de conflictos SoD estática (no pueden coexistir en mismo usuario).
const STATIC_SOD_CONFLICTS: &[(&str, &str)] = &[
    ("ROL-COMPRADOR",           "ROL-AUDITOR-INTERNO"),
    ("ROL-ENCARGADO-FACTURACION","ROL-REVISOR-FISCAL"),
    ("ROL-SYS-ADMIN-PROYECTO",  "ROL-SYS-ADMIN-SEGURIDAD"),
    ("ROL-JEFE-CONTABILIDAD",   "ROL-AUDITOR-EXTERNO-CONTABLE"),
    ("ROL-CAJERO",              "ROL-AUDITOR-INVENTARIO"),
    ("ROL-SUPERVISOR-FACT-COBRANZA","ROL-COBRADOR"),
];

/// Conflictos SoD dinámicos (no pueden activarse en la misma sesión).
const DYNAMIC_SOD_CONFLICTS: &[(&str, &str)] = &[
    ("ROL-CAJERO",              "ROL-AUDITOR-INVENTARIO"),
    ("ROL-SUPERVISOR-FACT-COBRANZA","ROL-COBRADOR"),
];

pub struct SodEngine;

impl SodEngine {
    /// Verifica que `new_role` no entre en conflicto con los roles
    /// existentes del usuario (estático) ni con la sesión activa (dinámico).
    pub fn validate(
        user_roles: &[String],
        session_roles: &[String],
        new_role: &str,
    ) -> Result<(), Vec<SodConflict>> {
        let mut conflicts = vec![];

        // SoD estática: no puede asignarse al mismo usuario
        for (a, b) in STATIC_SOD_CONFLICTS {
            if (new_role == *a && user_roles.contains(&b.to_string()))
            || (new_role == *b && user_roles.contains(&a.to_string()))
            {
                conflicts.push(SodConflict {
                    conflict_type: SodType::Static,
                    role_a: a.to_string(),
                    role_b: b.to_string(),
                    message: format!("{} y {} no pueden coexistir en el mismo usuario", a, b),
                });
            }
        }

        // SoD dinámica: no pueden estar activos en la misma sesión
        for (a, b) in DYNAMIC_SOD_CONFLICTS {
            if (new_role == *a && session_roles.contains(&b.to_string()))
            || (new_role == *b && session_roles.contains(&a.to_string()))
            {
                conflicts.push(SodConflict {
                    conflict_type: SodType::Dynamic,
                    role_a: a.to_string(),
                    role_b: b.to_string(),
                    message: format!("{} y {} no pueden activarse en la misma sesión", a, b),
                });
            }
        }

        if conflicts.is_empty() { Ok(()) } else { Err(conflicts) }
    }
}
```

---

### FASE E: Post-Quantum Crypto Wrappers (src/crypto/) — SEMANA 4-5

**Gap:** Keycloak no soporta algoritmos post-cuánticos. Tryton tampoco. FIPS 203/204/205
son obligatorios para sistemas gubernamentales y financieros a partir de 2026-2027.

**Qué construiremos — wrappers Rust sobre crates existentes:**

```rust
// src/crypto/pqc.rs — Post-Quantum Cryptography Wrappers
//
// Envolvemos crates de crates.io verificados:
//   - pqc_kyber (FIPS 203 — ML-KEM)
//   - pqc_dilithium (FIPS 204 — ML-DSA)
//   - pqc_sphincsplus (FIPS 205 — SLH-DSA)
//
// NO implementamos criptografía — solo exponemos interfaces seguras.

use pqcrypto::kem::kyber1024::{KeyPair, PublicKey, SecretKey, 
                                 encapsulate, decapsulate};
use pqcrypto::sign::dilithium5::{sign, verify, KeyPair as SigKeyPair};

/// Key encapsulation mechanism (KEM) para intercambio de claves PQ.
pub struct PqcKem;

impl PqcKem {
    /// Genera par de claves Kyber-1024 (FIPS 203).
    pub fn generate_keypair() -> PqcKeyPair { /* ... */ }

    /// Encapsula un shared secret de 32 bytes.
    pub fn encapsulate(pk: &[u8]) -> (Vec<u8>, Vec<u8>) {
        let (shared_secret, ciphertext) = encapsulate(pk);
        (shared_secret.to_vec(), ciphertext.to_vec())
    }

    /// Desencapsula el shared secret.
    pub fn decapsulate(ct: &[u8], sk: &[u8]) -> Vec<u8> {
        decapsulate(ct, sk).to_vec()
    }
}

/// Digital signature algorithm (DSA) para firmas PQ.
pub struct PqcDsa;

impl PqcDsa {
    /// Firma con Dilithium-5 (FIPS 204).
    pub fn sign(message: &[u8], sk: &[u8]) -> Vec<u8> {
        sign(message, sk).to_vec()
    }

    /// Verifica firma Dilithium-5.
    pub fn verify(message: &[u8], signature: &[u8], pk: &[u8]) -> bool {
        verify(signature, message, pk).is_ok()
    }
}

/// Modo híbrido: clásico + post-cuántico (NIST recommended).
pub struct HybridCrypto;

impl HybridCrypto {
    /// Intercambio de claves híbrido: ECDH P-521 ⊕ Kyber-1024.
    /// Si cualquiera de los dos es seguro, el shared secret es seguro.
    pub fn hybrid_key_exchange(pk_ecdh: &[u8], pk_pqc: &[u8]) -> Vec<u8> {
        let classical_secret = ecdh_p521(pk_ecdh);
        let pq_secret = PqcKem::encapsulate(pk_pqc).0;
        // XOR de ambos — seguridad clásica + cuántica
        xor_bytes(&classical_secret, &pq_secret)
    }
}
```

**Dependencia Cargo.toml:**
```toml
pqcrypto = "0.3"          # KYBER + DILITHIUM + SPHINCS+
pqcrypto-kyber = "0.8"    # ML-KEM FIPS 203
pqcrypto-dilithium = "0.6"# ML-DSA FIPS 204
pqcrypto-sphincsplus = "0.4" # SLH-DSA FIPS 205
```

---

### FASE F: JSON-RPC CRUD para 7 Tablas — SEMANA 3-4

**Gap:** Las 7 tablas del framework existen en BD pero no tienen handlers JSON-RPC
para administrarlas en runtime. Solo `bauth.saga.execute` está definido.

**Qué construiremos — 21 handlers nuevos (3 por tabla × 7 tablas):**

```rust
// src/server/jsonrpc_framework.rs

// ─── auth_method ──────────────────────────────────────
dispatcher.register("bauth.method.list",   Arc::new(MethodListHandler { pg }));
dispatcher.register("bauth.method.read",   Arc::new(MethodReadHandler { pg }));
dispatcher.register("bauth.method.update", Arc::new(MethodUpdateHandler { pg }));

// ─── auth_policy ──────────────────────────────────────
dispatcher.register("bauth.policy.list",   Arc::new(PolicyListHandler { pg }));
dispatcher.register("bauth.policy.read",   Arc::new(PolicyReadHandler { pg }));
dispatcher.register("bauth.policy.update", Arc::new(PolicyUpdateHandler { pg }));

// ─── auth_config ──────────────────────────────────────
dispatcher.register("bauth.config.list",   Arc::new(ConfigListHandler { pg }));
dispatcher.register("bauth.config.read",   Arc::new(ConfigReadHandler { pg }));
dispatcher.register("bauth.config.update", Arc::new(ConfigUpdateHandler { pg }));

// ─── crypto_algorithm ─────────────────────────────────
dispatcher.register("bauth.crypto.list",   Arc::new(CryptoListHandler { pg }));
dispatcher.register("bauth.crypto.read",   Arc::new(CryptoReadHandler { pg }));
dispatcher.register("bauth.crypto.update", Arc::new(CryptoUpdateHandler { pg }));

// ─── federation_protocol ──────────────────────────────
dispatcher.register("bauth.federation.list",   Arc::new(FedListHandler { pg }));
dispatcher.register("bauth.federation.read",   Arc::new(FedReadHandler { pg }));
dispatcher.register("bauth.federation.update", Arc::new(FedUpdateHandler { pg }));

// ─── saga_catalog + saga_step ───────────────────────
dispatcher.register("bauth.saga.list",     Arc::new(SagaListHandler { pg }));
dispatcher.register("bauth.saga.read",     Arc::new(SagaReadHandler { pg }));
dispatcher.register("bauth.saga.validate", Arc::new(SagaValidateHandler { pg }));

// ─── compliance_map ──────────────────────────────────
dispatcher.register("bauth.compliance.list",  Arc::new(CompListHandler { pg }));
dispatcher.register("bauth.compliance.read",  Arc::new(CompReadHandler { pg }));
dispatcher.register("bauth.compliance.update", Arc::new(CompUpdateHandler { pg }));
```

**Ejemplo de handler:**
```json
// Request
{"method": "bauth.method.list", "params": {"filter": {"aal_level": "AAL3"}}}

// Response  
{"result": {"methods": [{"method_id": "KC_WEBAUTHN_PASSWORDLESS", ...}, 
                        {"method_id": "KC_X509", ...}], "count": 2}}
```

---

### FASE G: Reconciler Tryton → Keycloak (B12+) — SEMANA 5-6

**Gap:** Tryton tiene los datos de identidad (empleados, departamentos, roles de
negocio) pero no los sincroniza con Keycloak. El reconciler corre cada 60s.

**Qué construiremos:**

```rust
// src/sync/tryton_reconciler.rs

/// Bucle de reconciliación Tryton → Keycloak cada 60 segundos.
/// 
/// Entidades sincronizadas:
///   res_users       → Keycloak users (User Storage SPI)
///   res_company     → Keycloak groups (org:company_name)
///   res_branch      → Keycloak groups (org:branch_name)
///   res_department  → Keycloak groups (org:dept_name)
///   res_groups      → bos_role assignment (via bAuth reconciler)
pub struct TrytonReconciler {
    pub tryton_client: TrytonJsonRpcClient,
    pub kc_admin: KeycloakAdminClient,
    pub pg_pool: sqlx::PgPool,
    pub interval_secs: u64,
}

impl TrytonReconciler {
    pub async fn run_loop(&self, drain: DrainManager) {
        let mut interval = tokio::time::interval(
            std::time::Duration::from_secs(self.interval_secs)
        );

        loop {
            tokio::select! {
                _ = interval.tick() => {
                    if let Err(e) = self.reconcile_all().await {
                        warn!(error = %e, "error en ciclo de reconciliación");
                    }
                }
                _ = drain.wait() => {
                    info!("reconciler detenido");
                    break;
                }
            }
        }
    }

    async fn reconcile_all(&self) -> Result<(), DbError> {
        // 1. Obtener usuarios de Tryton (solo activos)
        // 2. Para cada usuario: crear/actualizar en Keycloak
        // 3. Mapear company/branch/dept a grupos Keycloak
        // 4. Mapear res_groups a bos_role
        // 5. Registrar cambios en audit log
        Ok(())
    }
}
```

---

### FASE H: PCI DSS 8.5.1 — No Factor Disclosure — SEMANA 4

**Gap:** Keycloak revela cuál factor falló (ej: "invalid password" vs "invalid TOTP").
PCI DSS 4.0.1 Req 8.5.1 exige que **todos los factores se validen antes de revelar
el resultado** — el sistema no debe indicar qué factor falló.

**Qué construiremos:**

```rust
// src/saga/actions/pci_compliant_auth.rs

/// Autenticación PCI DSS 8.5.1 compliant:
/// Valida TODOS los factores antes de emitir cualquier fallo.
/// Si cualquiera falla → mensaje genérico "autenticación fallida".
/// Solo si TODOS pasan → acceso concedido.
pub async fn pci_compliant_multifactor(
    password: &str,
    totp_code: Option<&str>,
    webauthn_assertion: Option<WebAuthnAssertion>,
    ctx: &mut SagaEvalContext,
) -> Result<PciAuthResult, PciAuthError> {
    let mut results = Vec::new();

    // Factor 1: Password (validar pero NO reportar fallo aún)
    let pw_ok = verify_argon2id(&ctx.params["username"], password).await;
    results.push(("password", pw_ok));

    // Factor 2: MFA (si aplica al tier)
    if let Some(code) = totp_code {
        let mfa_ok = verify_totp(&ctx.params["username"], code).await;
        results.push(("totp", mfa_ok));
    }

    if let Some(assertion) = webauthn_assertion {
        let webauthn_ok = verify_webauthn_assertion(assertion).await;
        results.push(("webauthn", webauthn_ok));
    }

    // PCI DSS 8.5.1: evaluar TODOS los factores juntos
    let all_passed = results.iter().all(|(_, ok)| *ok);
    let failed_count = results.iter().filter(|(_, ok)| !*ok).count();

    // Mensaje genérico — NUNCA decir cuál factor falló
    match (all_passed, failed_count) {
        (true, _) => Ok(PciAuthResult::Success),
        (false, _) => {
            // Registrar internamente cuál falló (para auditoría)
            // pero NUNCA exponerlo al cliente
            audit_log_pci_failure(&results).await;
            
            Err(PciAuthError::AuthenticationFailed {
                message: "autenticación fallida".to_string(),
                // Interno: results contiene el detalle para SIEM
            })
        }
    }
}
```

---

## 3. Resumen de Archivos a Crear/Modificar

| # | Archivo | Fase | Tipo | Contenido |
|---|---------|------|------|-----------|
| 1 | `src/saga/mod.rs` | A | NUEVO | Motor de sagas + SagaOrchestrator |
| 2 | `src/saga/step.rs` | A | NUEVO | SagaOp, SagaStep, StepDetail |
| 3 | `src/saga/action.rs` | A | NUEVO | SagaAction, CompensationStrategy |
| 4 | `src/saga/executor.rs` | A | NUEVO | execute() + compensación inversa |
| 5 | `src/saga/validator.rs` | A | NUEVO | validate_saga() + detección ciclos |
| 6 | `src/saga/resolver.rs` | A | NUEVO | resolve_deps() + topological sort |
| 7 | `src/saga/catalog.rs` | A | NUEVO | build_catalog() desde BD |
| 8 | `src/saga/tests.rs` | A | NUEVO | Tests de ejecución + compensación |
| 9 | `src/saga/actions/hibp.rs` | B | NUEVO | check_hibp_k_anon() |
| 10 | `src/saga/actions/mfa.rs` | F | NUEVO | verify_totp() + verify_webauthn() |
| 11 | `src/saga/actions/token.rs` | F | NUEVO | emit_jwt() + revoke_token() |
| 12 | `src/saga/actions/pci_compliant.rs` | H | NUEVO | pci_compliant_multifactor() |
| 13 | `src/domain/risk.rs` | C | NUEVO | RiskScore + RiskAction engine |
| 14 | `src/domain/sod.rs` | D | NUEVO | SodEngine + conflict matrix |
| 15 | `src/crypto/pqc.rs` | E | NUEVO | Wrappers Kyber/Dilithium/SPHINCS+ |
| 16 | `src/crypto/hybrid.rs` | E | NUEVO | ECDH ⊕ Kyber modo híbrido |
| 17 | `src/sync/tryton_reconciler.rs` | G | NUEVO | Bucle sync Tryton → KC cada 60s |
| 18 | `src/server/jsonrpc_framework.rs` | F | NUEVO | 21 handlers CRUD para 7 tablas |
| 19 | `src/server/jsonrpc.rs` | F | MODIFICAR | +SagaExecuteHandler + imports |
| 20 | `src/db/mod.rs` | F | MODIFICAR | +queries saga + framework tables |
| 21 | `src/main.rs` | F | MODIFICAR | +registry de sagas y handlers |
| 22 | `Cargo.toml` | E | MODIFICAR | +pqcrypto + reqwest + sha1 |
| 23 | `db/seeds/019_auth_framework_complete.sql` | — | EXISTENTE | 7 tablas declarativas |
| 24 | `db/seeds/020_saga_actions_seed.sql` | G | NUEVO | Registry de action_ref functions |

---

## 4. Plan de Trabajo — 6 Semanas

| Semana | Fase | Entregable | Hito |
|--------|------|-----------|------|
| **1** | A + B | `src/saga/` completo + HIBP screening | `bauth.saga.execute` funcional con S1 |
| **2** | C | Risk scoring engine + Redis sliding window | Risk scores en S1 paso 3 |
| **3** | D + F | SoD matrix + JSON-RPC CRUD para 7 tablas | Administración runtime del framework |
| **4** | E + H | Post-quantum wrappers + PCI DSS 8.5.1 | Criptografía PQ + auth compliant |
| **5** | G | Reconciler Tryton → Keycloak | Sincronización automática cada 60s |
| **6** | — | Tests integrales + deploy staging | Framework completo operativo |

---

## 5. Impacto en Otros Módulos

| Módulo | Cómo usa lo que construimos | Cuándo |
|--------|---------------------------|--------|
| **biedata** | Invoca `bauth.saga.execute` para autenticar en sagas de negocio | Semana 2+ |
| **bkernel** | Consume eventos de `saga_execution` vía Redis Stream | Semana 3+ |
| **bSearch** | Consulta `compliance_map` para filtros de búsqueda segura | Semana 4+ |
| **Kong** | Lee `federation_protocol` para configurar plugins | Semana 3+ |
| **Vault** | Lee `crypto_algorithm` para PKI engine | Semana 4+ |
| **NEXUS** | Usa `risk.rs` para impossible travel detection | Semana 3+ |
| **bcommand** | Invoca `bauth.method.list` para mostrar métodos disponibles | Semana 4+ |
| **Operador** | `bauth.saga.validate` para dry-run de sagas en staging | Semana 3+ |
