// ==================================================================
// bauth::domain::versioning::audit — Lógica pura de auditoría B01
//
// Validación de precondiciones para T-152 (idn_roles_ver_b01_audit_log).
// Clasificación semántica de cambios (MAJOR/MINOR/PATCH).
// Sin I/O, sin DB, sin HTTP.
//
// NIST SP 800-53 AU-9 · ISO 27001:2022 A.8.15
// MVU 1.13 §8.3 — contratos de versión cerrada
// ==================================================================

use super::{ChangeType, VersioningError};
use serde_json::Value;

/// Resultado de la validación de un snapshot de auditoría.
#[derive(Debug)]
pub struct ValidacionAuditoria {
    /// El snapshot cumple todas las precondiciones del DDL.
    pub es_valido: bool,
    /// Lista de violaciones encontradas (vacía si es_valido = true).
    pub violaciones: Vec<String>,
}

/// Campos mínimos para clasificar un cambio sin necesidad del struct completo.
pub struct CambioResumen<'a> {
    /// Tipo de cambio asignado por el emisor.
    pub change_type: ChangeType,
    /// Razón del cambio (texto libre).
    pub change_reason: Option<&'a str>,
    /// Si el registro es un anchor de versión major.
    pub is_anchor: bool,
    /// Snapshot del estado completo (None = no incluido).
    pub snapshot: Option<&'a Value>,
    /// Período de vigencia cerrado (fin necesario).
    pub sys_period_valido: bool,
}

/// Valida las precondiciones del DDL antes de persistir en T-152.
///
/// Reglas de CHECK constraints del DDL (evitar roundtrip a BD con error):
/// - MAJOR requiere `change_reason IS NOT NULL` (chk_irvb01al_mjr_rsn)
/// - MAJOR requiere `is_anchor = true` (chk_irvb01al_mjr_anc)
/// - anchor requiere `snapshot IS NOT NULL` (chk_irvb01al_anc_snap)
/// - `sys_period` debe ser cerrado (chk_irvb01al_closed)
pub fn validar_precondiciones(cambio: &CambioResumen<'_>) -> ValidacionAuditoria {
    let mut violaciones = Vec::new();

    if cambio.change_type == ChangeType::Major {
        if cambio.change_reason.map(|s| s.trim().is_empty()).unwrap_or(true) {
            violaciones.push(
                "cambio MAJOR requiere change_reason no vacío (chk_irvb01al_mjr_rsn)".into(),
            );
        }
        if !cambio.is_anchor {
            violaciones.push(
                "cambio MAJOR requiere is_anchor = true (chk_irvb01al_mjr_anc)".into(),
            );
        }
    }

    if cambio.is_anchor && cambio.snapshot.is_none() {
        violaciones.push(
            "is_anchor = true requiere snapshot no nulo (chk_irvb01al_anc_snap)".into(),
        );
    }

    if !cambio.sys_period_valido {
        violaciones.push(
            "sys_period debe ser cerrado: upper(sys_period) ≠ infinity (chk_irvb01al_closed)".into(),
        );
    }

    ValidacionAuditoria {
        es_valido: violaciones.is_empty(),
        violaciones,
    }
}

/// Devuelve el mismo resultado como `Result` para integración fácil con `?`.
pub fn validar_o_error(cambio: &CambioResumen<'_>) -> Result<(), VersioningError> {
    let res = validar_precondiciones(cambio);
    if res.es_valido {
        Ok(())
    } else {
        Err(VersioningError::RequisitosIncompletos)
    }
}

/// Clasifica semánticamente un cambio comparando dos snapshots JSONB.
///
/// Criterios (heurísticos — la clasificación definitiva la hace el emisor):
/// - MAJOR: cambiaron `tier`, `bitmask_l1`, `sod_constraints` o `privilege_atoms`
/// - MINOR: cambiaron `policies`, `conditions`, `validity_type` o `metadata`
/// - PATCH: solo cambiaron campos de documentación o referencias
pub fn clasificar_cambio(antes: &Value, despues: &Value) -> ChangeType {
    let campos_major = ["tier", "bitmask_l1", "sod_constraints", "privilege_atoms"];
    let campos_minor = ["policies", "conditions", "validity_type", "metadata"];

    for campo in &campos_major {
        if antes.get(campo) != despues.get(campo) {
            return ChangeType::Major;
        }
    }

    for campo in &campos_minor {
        if antes.get(campo) != despues.get(campo) {
            return ChangeType::Minor;
        }
    }

    ChangeType::Patch
}

// ── TESTS ────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn cambio_mayor_valido<'a>(snapshot: &'a Value) -> CambioResumen<'a> {
        CambioResumen {
            change_type: ChangeType::Major,
            change_reason: Some("Reestructura de átomos de privilegio — B01 §8.3"),
            is_anchor: true,
            snapshot: Some(snapshot),
            sys_period_valido: true,
        }
    }

    #[test]
    fn test_major_valido_pasa() {
        let snap = json!({"tier": "BIZ_N1"});
        let res = validar_precondiciones(&cambio_mayor_valido(&snap));
        assert!(res.es_valido);
        assert!(res.violaciones.is_empty());
    }

    #[test]
    fn test_major_sin_razon_falla() {
        let snap = json!({});
        let cambio = CambioResumen {
            change_type: ChangeType::Major,
            change_reason: None,
            is_anchor: true,
            snapshot: Some(&snap),
            sys_period_valido: true,
        };
        let res = validar_precondiciones(&cambio);
        assert!(!res.es_valido);
        assert!(res.violaciones.iter().any(|v| v.contains("change_reason")));
    }

    #[test]
    fn test_anchor_sin_snapshot_falla() {
        let cambio = CambioResumen {
            change_type: ChangeType::Minor,
            change_reason: None,
            is_anchor: true,
            snapshot: None,
            sys_period_valido: true,
        };
        let res = validar_precondiciones(&cambio);
        assert!(!res.es_valido);
        assert!(res.violaciones.iter().any(|v| v.contains("snapshot")));
    }

    #[test]
    fn test_patch_sin_anchor_es_valido() {
        let cambio = CambioResumen {
            change_type: ChangeType::Patch,
            change_reason: None,
            is_anchor: false,
            snapshot: None,
            sys_period_valido: true,
        };
        assert!(validar_precondiciones(&cambio).es_valido);
    }

    #[test]
    fn test_clasificar_cambio_tier_es_major() {
        let antes = json!({"tier": "BIZ_N1", "policies": []});
        let despues = json!({"tier": "BIZ_N2", "policies": []});
        assert_eq!(clasificar_cambio(&antes, &despues), ChangeType::Major);
    }

    #[test]
    fn test_clasificar_cambio_policies_es_minor() {
        let antes = json!({"tier": "BIZ_N1", "policies": []});
        let despues = json!({"tier": "BIZ_N1", "policies": ["P01"]});
        assert_eq!(clasificar_cambio(&antes, &despues), ChangeType::Minor);
    }

    #[test]
    fn test_clasificar_cambio_descripcion_es_patch() {
        let antes = json!({"tier": "BIZ_N1", "descripcion": "v1"});
        let despues = json!({"tier": "BIZ_N1", "descripcion": "v2"});
        assert_eq!(clasificar_cambio(&antes, &despues), ChangeType::Patch);
    }
}
