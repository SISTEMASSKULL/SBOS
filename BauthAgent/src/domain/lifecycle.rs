// ================================================================
// bauth::domain::lifecycle — Ciclo de vida del rol (7 estados)
//
// Estados: DEFINIDO → DESARROLLADO → REVISADO → AUTORIZADO →
//           PUBLICADO → DEPRECADO → RETIRADO
//
// Cada transición tiene un responsable y SoD asociado.
//
// Referencias:
//   BAUTH-CATALOGO-ROLES-EMPRESARIALES.md v2.0 §7.3
//   NIST SP 800-53 AC-5 (SoD)
//   ISO 27001:2022 A.8.2 (Privileged Access)
// ================================================================

#![allow(dead_code)]
use serde::{Deserialize, Serialize};

/// Estado del ciclo de vida de un RolTemplate.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Default)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum LifecycleState {
    #[default]
    /// Rol documentado en catálogo, listo para desarrollo.
    Definido,
    /// RolTemplate implementado en código.
    Desarrollado,
    /// Verificado por revisor (SoD: revisor ≠ desarrollador).
    Revisado,
    /// Aprobado por autorizador (SoD: autorizador ≠ revisor).
    Autorizado,
    /// En producción, asignable a usuarios.
    Publicado,
    /// Ya no se asigna a nuevos usuarios. Los existentes conservan el rol.
    Deprecado,
    /// Eliminado del sistema. Solo en logs de auditoría.
    Retirado,
}

impl LifecycleState {
    /// Lista de estados válidos con sus transiciones permitidas.
    pub fn allowed_transitions(&self) -> &[LifecycleState] {
        match self {
            LifecycleState::Definido => &[LifecycleState::Desarrollado],
            LifecycleState::Desarrollado => &[LifecycleState::Revisado, LifecycleState::Definido],
            LifecycleState::Revisado => &[LifecycleState::Autorizado, LifecycleState::Desarrollado],
            LifecycleState::Autorizado => &[LifecycleState::Publicado, LifecycleState::Revisado],
            LifecycleState::Publicado => &[LifecycleState::Deprecado, LifecycleState::Definido],
            LifecycleState::Deprecado => &[LifecycleState::Retirado, LifecycleState::Publicado],
            LifecycleState::Retirado => &[], // Estado terminal
        }
    }

    /// ¿Esta transición es válida?
    pub fn can_transition_to(&self, target: &LifecycleState) -> bool {
        self.allowed_transitions().contains(target)
    }

    /// ¿El estado permite asignar este rol a usuarios?
    pub fn is_assignable(&self) -> bool {
        matches!(self, LifecycleState::Publicado)
    }

    /// ¿El estado es operativo (el rol puede usarse en sesiones activas)?
    pub fn is_operative(&self) -> bool {
        matches!(self, LifecycleState::Publicado | LifecycleState::Deprecado)
    }
}

impl std::fmt::Display for LifecycleState {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s = match self {
            LifecycleState::Definido => "DEFINIDO",
            LifecycleState::Desarrollado => "DESARROLLADO",
            LifecycleState::Revisado => "REVISADO",
            LifecycleState::Autorizado => "AUTORIZADO",
            LifecycleState::Publicado => "PUBLICADO",
            LifecycleState::Deprecado => "DEPRECADO",
            LifecycleState::Retirado => "RETIRADO",
        };
        write!(f, "{s}")
    }
}

// ── TESTS ───────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_normal_flow() {
        let flow = vec![
            LifecycleState::Definido,
            LifecycleState::Desarrollado,
            LifecycleState::Revisado,
            LifecycleState::Autorizado,
            LifecycleState::Publicado,
            LifecycleState::Deprecado,
            LifecycleState::Retirado,
        ];
        for window in flow.windows(2) {
            assert!(window[0].can_transition_to(&window[1]),
                "transición inválida: {} → {}", window[0], window[1]);
        }
    }

    #[test]
    fn test_forbidden_jump() {
        // No se puede saltar de Definido a Publicado directamente
        assert!(!LifecycleState::Definido.can_transition_to(&LifecycleState::Publicado));
    }

    #[test]
    fn test_retirado_terminal() {
        assert!(LifecycleState::Retirado.allowed_transitions().is_empty());
    }

    #[test]
    fn test_assignable() {
        assert!(!LifecycleState::Definido.is_assignable());
        assert!(!LifecycleState::Desarrollado.is_assignable());
        assert!(LifecycleState::Publicado.is_assignable());
        assert!(!LifecycleState::Deprecado.is_assignable()); // No se asignan nuevos
    }

    #[test]
    fn test_operative() {
        assert!(LifecycleState::Publicado.is_operative());
        assert!(LifecycleState::Deprecado.is_operative()); // Sigue funcionando para existentes
        assert!(!LifecycleState::Retirado.is_operative());
    }
}
