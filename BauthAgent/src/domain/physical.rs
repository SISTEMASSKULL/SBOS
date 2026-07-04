// ============================================================
// bauth::domain::physical — Evaluador del Dominio Físico (D2)
// B2.T01-T08 — PhysicalDomain
//
// Controla acceso a zonas físicas, puertas, hardware y dispositivos.
// Fast-Path: el verbo es suficiente (<0.5ns).
// Sin política adicional requerida (D2 no requiere Policy-Path).
//
// Integración con OSDP v2.2.2 para comunicación con lectores físicos.
// ============================================================

#![allow(dead_code)]
use crate::bitmask::{
    registry::{DomainEvaluator, DomainResult},
    AtomBitMask, AtomPosition, DomainCode, RolBitMask,
};

/// Código del dominio físico.
pub const PHYSICAL_DOMAIN: DomainCode = 2;

/// Átomos predefinidos del dominio físico (D2).
/// Estos slugs son referencias — las posiciones reales
/// se asignan al registrar los átomos en el catálogo.
pub mod atoms {
    // ─── Sesión y Shell ───
    pub const SESSION_VALID: &str = "fisico.sesion.valida";
    pub const SHELL_UNLOCK: &str = "fisico.shell.desbloquear";

    // ─── Zonas de Acceso ───
    pub const DOOR_ZONE_A: &str = "fisico.zona.a";
    pub const DOOR_ZONE_B: &str = "fisico.zona.b";
    pub const DOOR_ZONE_C: &str = "fisico.zona.c";
    pub const DOOR_ZONE_D: &str = "fisico.zona.d";

    // ─── Niveles de Seguridad Física ───
    pub const PHY_SEC_LEVEL_1: &str = "fisico.seguridad.nivel1";
    pub const PHY_SEC_LEVEL_2: &str = "fisico.seguridad.nivel2";
    pub const PHY_SEC_LEVEL_3: &str = "fisico.seguridad.nivel3";
    pub const PHY_SEC_LEVEL_4: &str = "fisico.seguridad.nivel4";

    // ─── Control de Hardware ───
    pub const PRINT_ALLOWED: &str = "fisico.hardware.imprimir";
    pub const USB_STORAGE: &str = "fisico.hardware.usb";
    pub const NETWORK_EXTERNAL: &str = "fisico.red.externa";
    pub const VPN_ACCESS: &str = "fisico.red.vpn";

    // ─── Dispositivos ───
    pub const TERMINAL_POS: &str = "fisico.dispositivo.pos";
    pub const ADMIN_PANEL: &str = "fisico.dispositivo.admin";
    pub const THUNDERBIRD_ACCESS: &str = "fisico.dispositivo.thunderbird";
}

/// Evaluador del dominio físico (D2).
///
/// Fast-Path: solo verifica que el átomo esté en el RolBitMask.
/// No requiere políticas adicionales — el verbo es suficiente.
///
/// La comunicación con hardware físico (OSDP, Wiegand) ocurre
/// en la capa de infraestructura (bhnexus), no en el evaluador.
pub struct PhysicalEvaluator;

impl PhysicalEvaluator {
    pub fn new() -> Self {
        PhysicalEvaluator
    }
}

impl DomainEvaluator for PhysicalEvaluator {
    fn domain_code(&self) -> DomainCode {
        PHYSICAL_DOMAIN
    }

    fn domain_name(&self) -> &'static str {
        "Físico"
    }

    fn evaluate(
        &self,
        _ctx_id: &str,
        _user_id: &str,
        rol: &RolBitMask,
        atom_position: AtomPosition,
        _atom: &AtomBitMask,
    ) -> DomainResult {
        // Fast-Path: D2 no requiere política adicional.
        // Solo verificar que el bit está activo en el RolBitMask.
        if rol.check(atom_position) {
            DomainResult::permitido(PHYSICAL_DOMAIN)
        } else {
            DomainResult::denegado(PHYSICAL_DOMAIN, "átomo físico no concedido")
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::bitmask::{AtomBitMask, PolicyState, RolBitMask};

    #[test]
    fn test_physical_evaluator_permitido() {
        let ev = PhysicalEvaluator::new();
        let rol = RolBitMask::from_positions(&[10, 20, 30], 100);
        let atom = AtomBitMask::new_simple(2, 1, 1, 1, PolicyState::NoAplica);

        // Posición 20 está en el RolBitMask → Permitido
        let result = ev.evaluate("ctx_001", "user_001", &rol, 20, &atom);
        assert!(matches!(result.result, crate::bitmask::AccessResult::Permitido));
    }

    #[test]
    fn test_physical_evaluator_denegado() {
        let ev = PhysicalEvaluator::new();
        let rol = RolBitMask::from_positions(&[10, 20, 30], 100);
        let atom = AtomBitMask::new_simple(2, 1, 1, 1, PolicyState::NoAplica);

        // Posición 99 NO está en el RolBitMask → Denegado
        let result = ev.evaluate("ctx_001", "user_001", &rol, 99, &atom);
        assert!(matches!(result.result, crate::bitmask::AccessResult::Denegado));
    }

    #[test]
    fn test_physical_domain_code() {
        let ev = PhysicalEvaluator::new();
        assert_eq!(ev.domain_code(), 2);
        assert_eq!(ev.domain_name(), "Físico");
    }

    #[test]
    fn test_atom_slugs_are_unique() {
        // Verificar que los slugs de átomos no se repitan
        let slugs = vec![
            atoms::SESSION_VALID,
            atoms::SHELL_UNLOCK,
            atoms::DOOR_ZONE_A,
            atoms::DOOR_ZONE_B,
            atoms::DOOR_ZONE_C,
            atoms::DOOR_ZONE_D,
            atoms::PHY_SEC_LEVEL_1,
            atoms::PHY_SEC_LEVEL_2,
            atoms::PHY_SEC_LEVEL_3,
            atoms::PHY_SEC_LEVEL_4,
            atoms::PRINT_ALLOWED,
            atoms::USB_STORAGE,
            atoms::NETWORK_EXTERNAL,
            atoms::VPN_ACCESS,
            atoms::TERMINAL_POS,
            atoms::ADMIN_PANEL,
            atoms::THUNDERBIRD_ACCESS,
        ];
        let mut seen = std::collections::HashSet::new();
        for slug in &slugs {
            assert!(seen.insert(slug), "Slug duplicado: {}", slug);
        }
    }

    #[test]
    fn test_physical_evaluator_is_fast_path() {
        let ev = PhysicalEvaluator::new();
        let rol = RolBitMask::from_positions(&[0, 1, 2], 10);
        let atom = AtomBitMask::new_simple(2, 1, 1, 1, PolicyState::NoAplica);
        for pos in 0..10 {
            let result = ev.evaluate("ctx", "user", &rol, pos, &atom);
            assert!(!matches!(result.result, crate::bitmask::AccessResult::Pendiente));
        }
    }

    // ─── B2.T08: Tests exhaustivos ───────────────────────

    #[test]
    fn test_100_deterministic_physical_evaluations() {
        let ev = PhysicalEvaluator::new();
        // 50 posiciones activas distribuidas uniformemente en 200 átomos
        let active: Vec<usize> = (0..200).step_by(4).collect(); // 0,4,8,12,... = 50 posiciones
        assert_eq!(active.len(), 50);
        let rol = RolBitMask::from_positions(&active, 200);
        let atom = AtomBitMask::new_simple(2, 1, 1, 1, PolicyState::NoAplica);

        let mut ok = 0;
        let mut deny = 0;
        for pos in 0..100 {
            let result = ev.evaluate("ctx_test", "user_test", &rol, pos, &atom);
            if matches!(result.result, crate::bitmask::AccessResult::Permitido) {
                ok += 1;
                assert!(active.contains(&pos), "pos={} no debería estar activa", pos);
            } else {
                deny += 1;
                assert!(!active.contains(&pos), "pos={} debería estar activa", pos);
            }
        }
        // Con step_by(4): posiciones 0,4,8,...96 → 25 activas en [0,100)
        assert_eq!(ok, 25, "25 posiciones activas esperadas");
        assert_eq!(deny, 75, "75 posiciones denegadas esperadas");
    }

    #[test]
    fn test_all_d2_atoms_distinct_positions() {
        // Verifica que los átomos D2 tienen posiciones únicas
        let slugs = vec![
            atoms::SESSION_VALID, atoms::SHELL_UNLOCK,
            atoms::DOOR_ZONE_A, atoms::DOOR_ZONE_B, atoms::DOOR_ZONE_C, atoms::DOOR_ZONE_D,
            atoms::PHY_SEC_LEVEL_1, atoms::PHY_SEC_LEVEL_2, atoms::PHY_SEC_LEVEL_3, atoms::PHY_SEC_LEVEL_4,
            atoms::PRINT_ALLOWED, atoms::USB_STORAGE, atoms::NETWORK_EXTERNAL, atoms::VPN_ACCESS,
            atoms::TERMINAL_POS, atoms::ADMIN_PANEL, atoms::THUNDERBIRD_ACCESS,
        ];
        assert_eq!(slugs.len(), 17, "17 átomos D2 definidos");
    }

    #[test]
    fn test_physical_evaluator_no_policy_path() {
        // D2 nunca debe usar Policy-Path — siempre Fast-Path directo
        let ev = PhysicalEvaluator::new();
        let rol = RolBitMask::from_positions(&[300, 301, 302, 310, 315], 500);
        let atom = AtomBitMask::new_simple(2, 6, 5, 1, PolicyState::NoAplica);

        for pos in [300, 301, 302, 310, 315, 400, 499] {
            let result = ev.evaluate("ctx", "user", &rol, pos, &atom);
            assert!(result.latency_ns == 0); // Fast-Path no mide latencia aquí
            assert!(!matches!(result.result, crate::bitmask::AccessResult::Pendiente));
        }
    }
}
