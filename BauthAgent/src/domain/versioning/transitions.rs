// ==================================================================
// bauth::domain::versioning::transitions — Validación de transiciones
//
// Mapeo bidireccional LifecycleState ↔ RolStatusDb.
// Validación pura de transiciones de estado de rol (sin I/O).
//
// NIST SP 800-53 AC-2(g) · ISO 27001:2022 A.5.15
// ANSI INCITS 359-2004 §4.3 (Role Activation)
// ==================================================================

use super::{RolStatusDb, VersioningError};
use crate::domain::lifecycle::LifecycleState;

/// Convierte el estado de ciclo de vida del dominio al estado de BD.
///
/// Mapping:
/// - Definido     → INACTIVE (documentado, sin desplegar)
/// - Desarrollado → INACTIVE (en desarrollo, no disponible)
/// - Revisado     → IN_REVIEW (bajo proceso de aprobación)
/// - Autorizado   → INACTIVE (aprobado, pendiente de publicación)
/// - Publicado    → ACTIVE   (operativo y asignable a usuarios)
/// - Deprecado    → DEPRECATED (no asignable a nuevos, activo para existentes)
/// - Retirado     → ARCHIVED (solo en logs de auditoría)
pub fn lifecycle_a_db(state: &LifecycleState) -> RolStatusDb {
    match state {
        LifecycleState::Definido => RolStatusDb::Inactive,
        LifecycleState::Desarrollado => RolStatusDb::Inactive,
        LifecycleState::Revisado => RolStatusDb::InReview,
        LifecycleState::Autorizado => RolStatusDb::Inactive,
        LifecycleState::Publicado => RolStatusDb::Active,
        LifecycleState::Deprecado => RolStatusDb::Deprecated,
        LifecycleState::Retirado => RolStatusDb::Archived,
    }
}

/// Convierte el estado de BD al estado de ciclo de vida del dominio.
///
/// Nota: INACTIVE y SUSPENDED mapean al estado más conservador porque
/// el mapping no es biyectivo (varios LifecycleState comparten el mismo
/// RolStatusDb). Para la dirección inversa precisa, usar la columna
/// `lifecycle_state` del registro en BD, no esta función.
pub fn db_a_lifecycle(status: RolStatusDb) -> LifecycleState {
    match status {
        RolStatusDb::Inactive => LifecycleState::Definido,
        RolStatusDb::Suspended => LifecycleState::Revisado,
        RolStatusDb::InReview => LifecycleState::Revisado,
        RolStatusDb::Active => LifecycleState::Publicado,
        RolStatusDb::Deprecated => LifecycleState::Deprecado,
        RolStatusDb::Archived => LifecycleState::Retirado,
    }
}

/// Valida que la transición entre dos estados de BD esté permitida.
///
/// Reglas de dominio bAuth (B02 §lifecycle):
/// - ACTIVE: puede ir a DEPRECATED o SUSPENDED
/// - INACTIVE: puede ir a ACTIVE, ARCHIVED o IN_REVIEW
/// - SUSPENDED: puede ir a ACTIVE o ARCHIVED
/// - IN_REVIEW: puede ir a INACTIVE, ACTIVE o ARCHIVED
/// - DEPRECATED: puede restaurarse a ACTIVE o progresar a ARCHIVED
/// - ARCHIVED: estado terminal, sin transiciones de salida
pub fn validar_transicion(
    desde: RolStatusDb,
    hacia: RolStatusDb,
) -> Result<(), VersioningError> {
    let permitidos: &[RolStatusDb] = match desde {
        RolStatusDb::Active => &[RolStatusDb::Deprecated, RolStatusDb::Suspended],
        RolStatusDb::Inactive => &[
            RolStatusDb::Active,
            RolStatusDb::Archived,
            RolStatusDb::InReview,
        ],
        RolStatusDb::Suspended => &[RolStatusDb::Active, RolStatusDb::Archived],
        RolStatusDb::InReview => &[
            RolStatusDb::Inactive,
            RolStatusDb::Active,
            RolStatusDb::Archived,
        ],
        RolStatusDb::Deprecated => &[RolStatusDb::Archived, RolStatusDb::Active],
        RolStatusDb::Archived => &[], // estado terminal
    };

    if permitidos.contains(&hacia) {
        Ok(())
    } else {
        Err(VersioningError::TransicionNoPermitida(
            desde.to_string(),
            hacia.to_string(),
        ))
    }
}

// ── TESTS ────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_lifecycle_a_db_estados_principales() {
        assert_eq!(lifecycle_a_db(&LifecycleState::Publicado), RolStatusDb::Active);
        assert_eq!(lifecycle_a_db(&LifecycleState::Deprecado), RolStatusDb::Deprecated);
        assert_eq!(lifecycle_a_db(&LifecycleState::Retirado), RolStatusDb::Archived);
        assert_eq!(lifecycle_a_db(&LifecycleState::Revisado), RolStatusDb::InReview);
        assert_eq!(lifecycle_a_db(&LifecycleState::Definido), RolStatusDb::Inactive);
    }

    #[test]
    fn test_transicion_activo_puede_deprecar() {
        assert!(validar_transicion(RolStatusDb::Active, RolStatusDb::Deprecated).is_ok());
    }

    #[test]
    fn test_transicion_activo_puede_suspender() {
        assert!(validar_transicion(RolStatusDb::Active, RolStatusDb::Suspended).is_ok());
    }

    #[test]
    fn test_transicion_activo_no_puede_archivar_directamente() {
        // ACTIVE → ARCHIVED requiere pasar por DEPRECATED primero
        assert!(validar_transicion(RolStatusDb::Active, RolStatusDb::Archived).is_err());
    }

    #[test]
    fn test_archived_es_terminal() {
        assert!(validar_transicion(RolStatusDb::Archived, RolStatusDb::Active).is_err());
        assert!(validar_transicion(RolStatusDb::Archived, RolStatusDb::Inactive).is_err());
        assert!(validar_transicion(RolStatusDb::Archived, RolStatusDb::Deprecated).is_err());
    }

    #[test]
    fn test_deprecated_puede_restaurarse() {
        assert!(validar_transicion(RolStatusDb::Deprecated, RolStatusDb::Active).is_ok());
    }

    #[test]
    fn test_deprecated_puede_archivarse() {
        assert!(validar_transicion(RolStatusDb::Deprecated, RolStatusDb::Archived).is_ok());
    }

    #[test]
    fn test_in_review_puede_aprobar_o_rechazar() {
        assert!(validar_transicion(RolStatusDb::InReview, RolStatusDb::Active).is_ok());
        assert!(validar_transicion(RolStatusDb::InReview, RolStatusDb::Inactive).is_ok());
        assert!(validar_transicion(RolStatusDb::InReview, RolStatusDb::Archived).is_ok());
    }

    #[test]
    fn test_error_transicion_invalida_contiene_estados() {
        let err = validar_transicion(RolStatusDb::Archived, RolStatusDb::Active)
            .unwrap_err()
            .to_string();
        assert!(err.contains("ARCHIVED"), "debe mencionar estado origen");
        assert!(err.contains("ACTIVE"), "debe mencionar estado destino");
    }
}
