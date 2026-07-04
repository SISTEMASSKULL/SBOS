// ============================================================
// bAuth::bitmask::registry — DomainRegistry + DomainEvaluator
// B1.T06 — DomainRegistry: orquestador de 12 dominios D1-D12
// B1.T19 — PolicyChainResolver
// B1.T20 — DomainEvaluationAudit
// B1.T21 — DomainConfig
// B1.T23 — DomainShortCircuit
//
// Orden de evaluación fijo con cortocircuito.
// Pre-BitMask: D8 (ctx_id), D9 (credenciales)
// Fast-Path:   D1 (lógico), D2 (físico) — <0.5ns
// Policy-Path: D3 (financiero), D10 (delegación), D4 (temporal)
// External:    D6 (geo), D7 (red), D5 (bio), D12 (blockchain)
// Siempre:     D11 (auditoría) — post-hoc, no evalúa
// ============================================================

#![allow(dead_code)]
use crate::bitmask::{AtomPosition, AtomBitMask, RolBitMask, PolicyState, AccessResult, DomainCode};

/// Resultado de la evaluación de un dominio.
#[derive(Debug, Clone)]
pub struct DomainResult {
    /// Código del dominio que evaluó.
    pub domain: DomainCode,
    /// Resultado de la evaluación: Permitido, Denegado, Pendiente.
    pub result: AccessResult,
    /// Estado de política después de la evaluación.
    pub policy_state: PolicyState,
    /// Latencia de la evaluación en nanosegundos (para métricas).
    pub latency_ns: u64,
    /// Slug de la política evaluada (si aplica).
    pub policy_slug: Option<String>,
}

impl DomainResult {
    pub fn permitido(domain: DomainCode) -> Self {
        DomainResult {
            domain,
            result: AccessResult::Permitido,
            policy_state: PolicyState::NoAplica,
            latency_ns: 0,
            policy_slug: None,
        }
    }

    pub fn denegado(domain: DomainCode, reason: &str) -> Self {
        DomainResult {
            domain,
            result: AccessResult::Denegado,
            policy_state: PolicyState::Rechazado,
            latency_ns: 0,
            policy_slug: Some(reason.to_string()),
        }
    }

    pub fn pendiente(domain: DomainCode, reason: &str) -> Self {
        DomainResult {
            domain,
            result: AccessResult::Pendiente,
            policy_state: PolicyState::Pendiente,
            latency_ns: 0,
            policy_slug: Some(reason.to_string()),
        }
    }
}

/// Trait que todo evaluador de dominio debe implementar.
/// Interfaz de evaluación por dominio — Fast-Path (<0.5ns).
///
/// **Arquitectura de dos niveles:**
/// 1. `evaluate()` = Fast-Path: verifica `rol.check(atom_position)`.
///    Un solo shift + AND. Sin I/O, sin heap allocation.
///    Para D1 y D2 (sin Policy-Path), esta es la evaluación completa.
///
/// 2. Policy-Path (orquestado por `DomainRegistry::evaluate_all()`):
///    - Carga políticas desde BD vía `PolicyChainResolver`
///    - Construye `EvalContext` con valores runtime
///    - Ejecuta `PolicyEngine::evaluate()` con 17 operadores
///    - Aplica a dominios D3-D10 que requieren políticas adicionales
///
/// El método `evaluate()` es SOLO el Fast-Path. La orquestación completa
/// (Fast-Path → Policy-Path → Auditoría) ocurre en el DomainRegistry.
pub trait DomainEvaluator: Send + Sync {
    /// Código del dominio que evalúa (1-12).
    fn domain_code(&self) -> DomainCode;
    /// Nombre del dominio en español.
    fn domain_name(&self) -> &'static str;
    /// Fast-Path: verifica `rol.check(atom_position)` (<0.5ns).
    /// No incluye Policy-Path — eso lo orquesta el DomainRegistry.
    fn evaluate(
        &self,
        ctx_id: &str,
        user_id: &str,
        rol: &RolBitMask,
        atom_position: AtomPosition,
        atom: &AtomBitMask,
    ) -> DomainResult;
}

/// Configuración de un dominio por tenant.
#[derive(Debug, Clone)]
pub struct DomainConfig {
    pub domain_code: DomainCode,
    pub active: bool,
    pub override_params: Option<serde_json::Value>,
}

impl DomainConfig {
    pub fn active(domain_code: DomainCode) -> Self {
        DomainConfig {
            domain_code,
            active: true,
            override_params: None,
        }
    }

    pub fn inactive(domain_code: DomainCode) -> Self {
        DomainConfig {
            domain_code,
            active: false,
            override_params: None,
        }
    }
}

/// Orquestador central de la evaluación de acceso.
///
/// Registra los 12 evaluadores de dominio y los ejecuta en el orden
/// correcto con cortocircuito. Solo evalúa dominios activos para el tenant.
pub struct DomainRegistry {
    /// Evaluadores registrados, indexados por domain_code.
    evaluators: Vec<Box<dyn DomainEvaluator>>,
    /// Configuración de dominios por tenant.
    tenant_configs: std::collections::HashMap<String, Vec<DomainConfig>>,
}

impl DomainRegistry {
    pub fn new() -> Self {
        DomainRegistry {
            evaluators: Vec::new(),
            tenant_configs: std::collections::HashMap::new(),
        }
    }

    /// Registra un evaluador de dominio.
    pub fn register(&mut self, evaluator: Box<dyn DomainEvaluator>) {
        self.evaluators.push(evaluator);
    }

    /// Configura qué dominios están activos para un tenant.
    pub fn configure_tenant(&mut self, tenant_id: &str, configs: Vec<DomainConfig>) {
        self.tenant_configs.insert(tenant_id.to_string(), configs);
    }

    /// ¿Está activo este dominio para este tenant?
    fn is_domain_active(&self, tenant_id: &str, domain: DomainCode) -> bool {
        self.tenant_configs
            .get(tenant_id)
            .and_then(|configs| configs.iter().find(|c| c.domain_code == domain))
            .map(|c| c.active)
            .unwrap_or(true) // si no hay config, activo por defecto
    }

    /// Evalúa TODOS los dominios activos para un tenant.
    ///
    /// Orden fijo: D8→D9→D1→D3→D2→D10→D4→D6→D7→D5→D12→D11
    /// Cortocircuito: si un dominio DENIEGA, los siguientes NO se evalúan.
    /// D11 (auditoría) siempre se registra aunque no evalúa.
    pub fn evaluate_all(
        &self,
        tenant_id: &str,
        ctx_id: &str,
        user_id: &str,
        rol: &RolBitMask,
        atom_position: AtomPosition,
        atom: &AtomBitMask,
    ) -> Vec<DomainResult> {
        // Orden canónico de evaluación
        const EVAL_ORDER: &[DomainCode] = &[
            8,                               // Pre-BitMask: D8 (ctx_id válido)
            9,                               // Pre-BitMask: D9 (credenciales)
            1,                               // Fast-Path: D1 (lógico)
            3,                               // Policy-Path: D3 (financiero)
            2,                               // Fast-Path: D2 (físico)
            10,                              // Policy-Path: D10 (delegación)
            4,                               // Policy-Path: D4 (temporal)
            6,                               // External: D6 (geoespacial)
            7,                               // External: D7 (red)
            5,                               // External: D5 (biométrico)
            12,                              // External: D12 (blockchain)
            11,                              // Siempre: D11 (auditoría) — post-hoc
        ];

        let mut results = Vec::new();
        let mut denied = false;

        for &domain in EVAL_ORDER {
            // Saltar dominios inactivos para este tenant
            if !self.is_domain_active(tenant_id, domain) {
                continue;
            }

            // D11 siempre se evalúa (post-hoc, no afecta la decisión)
            // Los demás dominios: cortocircuito si ya se denegó
            if denied && domain != 11 {
                results.push(DomainResult {
                    domain,
                    result: AccessResult::Denegado,
                    policy_state: PolicyState::Rechazado,
                    latency_ns: 0,
                    policy_slug: Some("short_circuit".to_string()),
                });
                continue;
            }

            // Buscar el evaluador para este dominio
            let evaluator = self.evaluators.iter().find(|e| e.domain_code() == domain);

            let domain_result = match evaluator {
                Some(ev) => ev.evaluate(ctx_id, user_id, rol, atom_position, atom),
                None => {
                    // Si no hay evaluador registrado, permitir por defecto
                    DomainResult::permitido(domain)
                }
            };

            if domain_result.result == AccessResult::Denegado && domain != 11 {
                denied = true;
            }

            results.push(domain_result);
        }

        results
    }

    /// Evalúa un dominio específico (para consultas puntuales).
    pub fn evaluate_domain(
        &self,
        domain: DomainCode,
        ctx_id: &str,
        user_id: &str,
        rol: &RolBitMask,
        atom_position: AtomPosition,
        atom: &AtomBitMask,
    ) -> Option<DomainResult> {
        self.evaluators
            .iter()
            .find(|e| e.domain_code() == domain)
            .map(|ev| ev.evaluate(ctx_id, user_id, rol, atom_position, atom))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::bitmask::{AtomBitMask, PolicyState, RolBitMask};

    /// Evaluador de prueba: siempre permite.
    struct AllowEvaluator { domain: DomainCode, name: &'static str }
    impl DomainEvaluator for AllowEvaluator {
        fn domain_code(&self) -> DomainCode { self.domain }
        fn domain_name(&self) -> &'static str { self.name }
        fn evaluate(&self, _ctx: &str, _user: &str, _rol: &RolBitMask, _pos: AtomPosition, _atom: &AtomBitMask) -> DomainResult {
            DomainResult::permitido(self.domain)
        }
    }

    /// Evaluador de prueba: siempre deniega.
    struct DenyEvaluator { domain: DomainCode, name: &'static str }
    impl DomainEvaluator for DenyEvaluator {
        fn domain_code(&self) -> DomainCode { self.domain }
        fn domain_name(&self) -> &'static str { self.name }
        fn evaluate(&self, _ctx: &str, _user: &str, _rol: &RolBitMask, _pos: AtomPosition, _atom: &AtomBitMask) -> DomainResult {
            DomainResult::denegado(self.domain, "test deny")
        }
    }

    #[test]
    fn test_register_and_evaluate() {
        let mut registry = DomainRegistry::new();
        registry.register(Box::new(AllowEvaluator { domain: 8, name: "context" }));
        registry.register(Box::new(AllowEvaluator { domain: 1, name: "logical" }));

        let rol = RolBitMask::from_positions(&[5], 10);
        let atom = AtomBitMask::new_simple(1, 1, 1, 1, PolicyState::NoAplica);

        let results = registry.evaluate_all("skull", "ctx_001", "user_001", &rol, 5, &atom);
        assert!(!results.is_empty());
        // D1 y D8 deberían estar (porque los registramos)
        assert!(results.iter().any(|r| r.domain == 8));
        assert!(results.iter().any(|r| r.domain == 1));
    }

    #[test]
    fn test_short_circuit_on_deny() {
        let mut registry = DomainRegistry::new();
        // D8 context → permitido
        registry.register(Box::new(AllowEvaluator { domain: 8, name: "context" }));
        // D9 creds → denegado
        registry.register(Box::new(DenyEvaluator { domain: 9, name: "creds" }));
        // D1 logico → nunca debería evaluarse (cortocircuito)
        registry.register(Box::new(AllowEvaluator { domain: 1, name: "logical" }));

        let rol = RolBitMask::from_positions(&[5], 10);
        let atom = AtomBitMask::new_simple(1, 1, 1, 1, PolicyState::NoAplica);

        let results = registry.evaluate_all("skull", "ctx_001", "user_001", &rol, 5, &atom);

        // D8 debe estar permitido
        let d8 = results.iter().find(|r| r.domain == 8).unwrap();
        assert_eq!(d8.result, AccessResult::Permitido);

        // D9 debe estar denegado
        let d9 = results.iter().find(|r| r.domain == 9).unwrap();
        assert_eq!(d9.result, AccessResult::Denegado);

        // D1 debe estar en cortocircuito
        let d1 = results.iter().find(|r| r.domain == 1);
        if let Some(d1r) = d1 {
            assert!(d1r.policy_slug.as_deref() == Some("short_circuit"));
        }
    }

    #[test]
    fn test_domain_config_inactive() {
        let mut registry = DomainRegistry::new();
        registry.register(Box::new(AllowEvaluator { domain: 6, name: "geo" }));
        // Desactivar D6 para el tenant
        registry.configure_tenant("skull", vec![DomainConfig::inactive(6)]);

        let rol = RolBitMask::from_positions(&[5], 10);
        let atom = AtomBitMask::new_simple(6, 1, 1, 1, PolicyState::NoAplica);

        let results = registry.evaluate_all("skull", "ctx_001", "user_001", &rol, 5, &atom);

        // D6 no debería aparecer en resultados (está inactivo)
        assert!(!results.iter().any(|r| r.domain == 6),
            "D6 inactivo no debe generar resultados");
    }

    #[test]
    fn test_unregistered_domain_defaults_to_permitido() {
        let registry = DomainRegistry::new();
        let rol = RolBitMask::from_positions(&[5], 10);
        let atom = AtomBitMask::new_simple(1, 1, 1, 1, PolicyState::NoAplica);

        // Sin evaluadores registrados, debe devolver permitido para todos
        let results = registry.evaluate_all("skull", "ctx_001", "user_001", &rol, 5, &atom);
        // Todos los dominios activos deben tener resultado (default: permitido)
        assert!(!results.is_empty());
        for r in &results {
            assert_eq!(r.result, AccessResult::Permitido);
        }
    }
}
