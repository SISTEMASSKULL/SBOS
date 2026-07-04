// ============================================================
// bauth::domain::logical — Evaluador del Dominio Lógico (D1)
// B3.T01-T07 — LogicalDomain
//
// Controla acceso a aplicaciones, menús, verbos y operaciones.
// Fast-Path: el verbo es suficiente (<0.5ns).
// Sin política adicional requerida.
// ============================================================

#![allow(dead_code)]
use crate::bitmask::{
    registry::{DomainEvaluator, DomainResult},
    AtomBitMask, AtomPosition, DomainCode, RolBitMask,
};

pub const LOGICAL_DOMAIN: DomainCode = 1;

/// Átomos predefinidos del dominio lógico (D1).
/// Los verbos (nuevo=1, editar=2, eliminar=3, ver=4) se combinan
/// con grupos funcionales por aplicación para formar átomos completos.
pub mod atoms {
    // ─── Tryton ERP ───
    pub const TRYTON_CONTABILIDAD_NUEVO: &str = "tryton.contabilidad.nuevo";
    pub const TRYTON_CONTABILIDAD_EDITAR: &str = "tryton.contabilidad.editar";
    pub const TRYTON_CONTABILIDAD_ELIMINAR: &str = "tryton.contabilidad.eliminar";
    pub const TRYTON_CONTABILIDAD_VER: &str = "tryton.contabilidad.ver";

    pub const TRYTON_COMPROBANTES_NUEVO: &str = "tryton.comprobantes.nuevo";
    pub const TRYTON_COMPROBANTES_EDITAR: &str = "tryton.comprobantes.editar";
    pub const TRYTON_COMPROBANTES_ELIMINAR: &str = "tryton.comprobantes.eliminar";

    pub const TRYTON_INVENTARIO_VER: &str = "tryton.inventario.ver";
    pub const TRYTON_INVENTARIO_EDITAR: &str = "tryton.inventario.editar";

    // ─── OrangeHRM ───
    pub const ORANGEHRM_EMPLEADOS_NUEVO: &str = "orangehrm.empleados.nuevo";
    pub const ORANGEHRM_EMPLEADOS_EDITAR: &str = "orangehrm.empleados.editar";
    pub const ORANGEHRM_EMPLEADOS_VER: &str = "orangehrm.empleados.ver";

    // ─── Saleor ───
    pub const SALEOR_CATALOGO_NUEVO: &str = "saleor.catalogo.nuevo";
    pub const SALEOR_CATALOGO_EDITAR: &str = "saleor.catalogo.editar";
    pub const SALEOR_CATALOGO_VER: &str = "saleor.catalogo.ver";

    // ─── Sistema (transversal) ───
    pub const SISTEMA_SESION_INGRESAR: &str = "sistema.sesion.ingresar";
    pub const SISTEMA_SESION_CERRAR: &str = "sistema.sesion.cerrar";
}

/// Evaluador del dominio lógico (D1).
///
/// Fast-Path: solo verifica que el átomo esté en el RolBitMask.
/// El verbo es suficiente — sin políticas adicionales.
pub struct LogicalEvaluator;

impl LogicalEvaluator {
    pub fn new() -> Self { LogicalEvaluator }
}

impl DomainEvaluator for LogicalEvaluator {
    fn domain_code(&self) -> DomainCode { LOGICAL_DOMAIN }
    fn domain_name(&self) -> &'static str { "Lógico" }

    fn evaluate(
        &self, _ctx: &str, _user: &str,
        rol: &RolBitMask, atom_position: AtomPosition, _atom: &AtomBitMask,
    ) -> DomainResult {
        if rol.check(atom_position) {
            DomainResult::permitido(LOGICAL_DOMAIN)
        } else {
            DomainResult::denegado(LOGICAL_DOMAIN, "átomo lógico no concedido")
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::bitmask::{AtomBitMask, PolicyState, RolBitMask};

    #[test]
    fn test_logical_permitido() {
        let ev = LogicalEvaluator::new();
        let rol = RolBitMask::from_positions(&[0, 1, 3, 4], 10);
        let atom = AtomBitMask::new_simple(1, 1, 2, 1, PolicyState::NoAplica);
        assert!(matches!(ev.evaluate("ctx","user",&rol,0,&atom).result, crate::bitmask::AccessResult::Permitido));
        assert!(matches!(ev.evaluate("ctx","user",&rol,99,&atom).result, crate::bitmask::AccessResult::Denegado));
    }

    #[test]
    fn test_logical_domain_code() {
        let ev = LogicalEvaluator::new();
        assert_eq!(ev.domain_code(), 1);
        assert_eq!(ev.domain_name(), "Lógico");
    }

    #[test]
    fn test_logical_is_fast_path_no_pending() {
        let ev = LogicalEvaluator::new();
        let rol = RolBitMask::from_positions(&[0], 10);
        let atom = AtomBitMask::new_simple(1, 1, 1, 1, PolicyState::NoAplica);
        for pos in 0..10 {
            let r = ev.evaluate("ctx","user",&rol,pos,&atom);
            assert!(!matches!(r.result, crate::bitmask::AccessResult::Pendiente));
        }
    }

    #[test]
    fn test_verb_combination_independence() {
        // Verificar que átomos con diferentes verbos son independientes
        let ev = LogicalEvaluator::new();
        // Rol con posición 0 (nuevo) y 1 (editar) activas, pero NO 2 (eliminar)
        let rol = RolBitMask::from_positions(&[0, 1], 10);
        let atom = AtomBitMask::new_simple(1, 1, 1, 3, PolicyState::NoAplica); // eliminar=3

        assert!(ev.evaluate("ctx","user",&rol,0,&atom).result == crate::bitmask::AccessResult::Permitido, "nuevo debe estar permitido");
        assert!(ev.evaluate("ctx","user",&rol,1,&atom).result == crate::bitmask::AccessResult::Permitido, "editar debe estar permitido");
        assert!(ev.evaluate("ctx","user",&rol,2,&atom).result == crate::bitmask::AccessResult::Denegado, "eliminar NO debe estar permitido");
    }

    #[test]
    fn test_atom_slugs_unique() {
        let slugs = vec![
            atoms::TRYTON_CONTABILIDAD_NUEVO, atoms::TRYTON_CONTABILIDAD_EDITAR,
            atoms::TRYTON_CONTABILIDAD_ELIMINAR, atoms::TRYTON_CONTABILIDAD_VER,
            atoms::TRYTON_COMPROBANTES_NUEVO, atoms::TRYTON_COMPROBANTES_EDITAR,
            atoms::TRYTON_COMPROBANTES_ELIMINAR,
            atoms::TRYTON_INVENTARIO_VER, atoms::TRYTON_INVENTARIO_EDITAR,
            atoms::ORANGEHRM_EMPLEADOS_NUEVO, atoms::ORANGEHRM_EMPLEADOS_EDITAR,
            atoms::ORANGEHRM_EMPLEADOS_VER,
            atoms::SALEOR_CATALOGO_NUEVO, atoms::SALEOR_CATALOGO_EDITAR,
            atoms::SALEOR_CATALOGO_VER,
            atoms::SISTEMA_SESION_INGRESAR, atoms::SISTEMA_SESION_CERRAR,
        ];
        let mut seen = std::collections::HashSet::new();
        for slug in &slugs {
            assert!(seen.insert(slug), "Slug duplicado: {}", slug);
        }
    }

    // ─── B3.T07: Tests exhaustivos ───────────────────────

    #[test]
    fn test_100_deterministic_logical_evaluations() {
        let ev = LogicalEvaluator::new();
        // 50 posiciones activas distribuidas en 200 átomos
        let active: Vec<usize> = (0..200).step_by(4).collect();
        assert_eq!(active.len(), 50);
        let rol = RolBitMask::from_positions(&active, 200);
        let atom = AtomBitMask::new_simple(1, 1, 1, 1, PolicyState::NoAplica);

        let mut ok = 0;
        for pos in 0..100 {
            let result = ev.evaluate("ctx", "user", &rol, pos, &atom);
            if matches!(result.result, crate::bitmask::AccessResult::Permitido) {
                ok += 1;
                assert!(active.contains(&pos));
            }
        }
        assert_eq!(ok, 25, "25 posiciones activas en [0,100) con step=4");
    }

    #[test]
    fn test_domain_independence_d1_vs_d2() {
        // Verifica que D1 y D2 comparten el mismo RolBitMask pero
        // son independientes a nivel de dominio
        let ev_d1 = LogicalEvaluator::new();
        let ev_d2 = crate::domain::physical::PhysicalEvaluator::new();

        // Rol con átomos D1 (pos 0-9) y D2 (pos 300-309)
        let mut positions = (0..10).collect::<Vec<_>>();
        positions.extend(300..310);
        let rol = RolBitMask::from_positions(&positions, 500);

        let atom_d1 = AtomBitMask::new_simple(1, 1, 1, 1, PolicyState::NoAplica);
        let atom_d2 = AtomBitMask::new_simple(2, 6, 5, 1, PolicyState::NoAplica);

        // D1 evaluador solo usa el átomo para metadata — la verificación es sobre posición
        for pos in 0..10 {
            assert!(matches!(ev_d1.evaluate("","",&rol,pos,&atom_d1).result, crate::bitmask::AccessResult::Permitido));
        }
        for pos in 300..310 {
            assert!(matches!(ev_d2.evaluate("","",&rol,pos,&atom_d2).result, crate::bitmask::AccessResult::Permitido));
        }
        // Posición sin asignar → denegado en ambos
        assert!(matches!(ev_d1.evaluate("","",&rol,99,&atom_d1).result, crate::bitmask::AccessResult::Denegado));
    }

    #[test]
    fn test_all_d1_slugs_defined() {
        assert_eq!(atoms::TRYTON_CONTABILIDAD_NUEVO, "tryton.contabilidad.nuevo");
        assert_eq!(atoms::SISTEMA_SESION_INGRESAR, "sistema.sesion.ingresar");
    }
}
