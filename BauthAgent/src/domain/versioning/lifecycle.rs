// ==================================================================
// bauth::domain::versioning::lifecycle — Lógica pura de ciclo de vida B02
//
// Construcción de payloads para T-B02L (idn_roles_rol_lifecycle_event).
// Cálculo del estado efectivo de un rol por su vigencia.
// Sin I/O, sin DB, sin HTTP.
//
// ANSI INCITS 359-2004 §4.3 · NIST SP 800-53 AC-2(g)
// ISO 27001:2022 A.5.15 · B02 §lifecycle
// ==================================================================

use super::{RolStatusDb, TriggerType};
use chrono::NaiveDate;
use serde_json::{json, Value};

/// Datos de vigencia de un rol extraídos de T-041 (B02 columns).
#[derive(Debug, Clone)]
pub struct VigenciaRol {
    /// Tipo de vigencia: INDEFINITE / FIXED_TERM / TEMPORARY / SEASONAL / EMERGENCY.
    pub validity_type: String,
    /// Fecha de inicio de vigencia (None = desde siempre).
    pub valid_from: Option<NaiveDate>,
    /// Fecha de fin de vigencia (None = indefinido).
    pub valid_until: Option<NaiveDate>,
    /// Intervalo de duración en formato ISO 8601 (ej: "P30D").
    pub duration_interval: Option<String>,
    /// Estado actual del rol en BD.
    pub status_actual: RolStatusDb,
}

/// Estado de vigencia calculado para un rol en una fecha dada.
#[derive(Debug, PartialEq, Eq)]
pub enum EstadoVigencia {
    /// El rol está dentro de su período de vigencia.
    Vigente,
    /// El rol aún no ha comenzado su período (valid_from > hoy).
    Prematuro,
    /// El rol ha superado su valid_until — debe expirar.
    Expirado,
    /// El rol es de tipo INDEFINITE: sin restricción temporal.
    Indefinido,
}

/// Calcula el estado de vigencia de un rol para una fecha dada.
///
/// Retorna `Expirado` cuando `valid_until <= fecha_ref` y el tipo
/// de vigencia no es INDEFINITE.
pub fn calcular_estado_vigencia(vigencia: &VigenciaRol, fecha_ref: NaiveDate) -> EstadoVigencia {
    if vigencia.validity_type == "INDEFINITE" {
        return EstadoVigencia::Indefinido;
    }

    if let Some(valid_until) = vigencia.valid_until {
        if valid_until <= fecha_ref {
            return EstadoVigencia::Expirado;
        }
    }

    if let Some(valid_from) = vigencia.valid_from {
        if valid_from > fecha_ref {
            return EstadoVigencia::Prematuro;
        }
    }

    EstadoVigencia::Vigente
}

/// Determina si un rol debe ser deprecado automáticamente.
///
/// Retorna true si el estado de vigencia es `Expirado` y el estado
/// actual del rol no es ya DEPRECATED, ARCHIVED o INACTIVE.
pub fn debe_expirar(vigencia: &VigenciaRol, fecha_ref: NaiveDate) -> bool {
    if calcular_estado_vigencia(vigencia, fecha_ref) != EstadoVigencia::Expirado {
        return false;
    }
    !matches!(
        vigencia.status_actual,
        RolStatusDb::Deprecated | RolStatusDb::Archived | RolStatusDb::Inactive
    )
}

/// Construye el JSONB `validity_snapshot` para registrar en T-B02L.
///
/// Captura el estado de los campos B02 en el momento exacto del evento
/// para auditoría posterior (ISO 27001:2022 A.8.15).
pub fn construir_validity_snapshot(vigencia: &VigenciaRol, detected_at: chrono::DateTime<chrono::Utc>) -> Value {
    json!({
        "validity_type":      vigencia.validity_type,
        "valid_from":         vigencia.valid_from.map(|d| d.to_string()),
        "valid_until":        vigencia.valid_until.map(|d| d.to_string()),
        "duration_interval":  vigencia.duration_interval,
        "detected_at":        detected_at.to_rfc3339(),
    })
}

/// Infiere el `TriggerType` apropiado según el contexto del cambio.
///
/// Regla:
/// - Si viene de un actor UUID → Manual
/// - Si `ctx_id` contiene "reconcile" → Reconcile
/// - Si `ctx_id` contiene "bootstrap" → Bootstrap
/// - Si `ctx_id` contiene "iga" → IgaReview
/// - Si `ctx_id` contiene "breakglass" → Breakglass
/// - Por defecto → AutoExpiry (disparado por trigger de BD)
pub fn inferir_trigger_type(actor_id: Option<&str>, ctx_id: &str) -> TriggerType {
    if actor_id.is_some() {
        return TriggerType::Manual;
    }
    let lower = ctx_id.to_lowercase();
    if lower.contains("reconcile") {
        TriggerType::Reconcile
    } else if lower.contains("bootstrap") {
        TriggerType::Bootstrap
    } else if lower.contains("iga") {
        TriggerType::IgaReview
    } else if lower.contains("breakglass") {
        TriggerType::Breakglass
    } else {
        TriggerType::AutoExpiry
    }
}

// ── TESTS ────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn vigencia_base(validity_type: &str, valid_until: Option<NaiveDate>) -> VigenciaRol {
        VigenciaRol {
            validity_type: validity_type.to_string(),
            valid_from: None,
            valid_until,
            duration_interval: None,
            status_actual: RolStatusDb::Active,
        }
    }

    #[test]
    fn test_indefinite_nunca_expira() {
        let v = vigencia_base("INDEFINITE", Some(NaiveDate::from_ymd_opt(2020, 1, 1).unwrap()));
        assert_eq!(
            calcular_estado_vigencia(&v, NaiveDate::from_ymd_opt(2026, 7, 25).unwrap()),
            EstadoVigencia::Indefinido
        );
    }

    #[test]
    fn test_expirado_cuando_valid_until_en_pasado() {
        let v = vigencia_base(
            "FIXED_TERM",
            Some(NaiveDate::from_ymd_opt(2026, 1, 1).unwrap()),
        );
        assert_eq!(
            calcular_estado_vigencia(&v, NaiveDate::from_ymd_opt(2026, 7, 25).unwrap()),
            EstadoVigencia::Expirado
        );
    }

    #[test]
    fn test_vigente_cuando_valid_until_en_futuro() {
        let v = vigencia_base(
            "FIXED_TERM",
            Some(NaiveDate::from_ymd_opt(2027, 1, 1).unwrap()),
        );
        assert_eq!(
            calcular_estado_vigencia(&v, NaiveDate::from_ymd_opt(2026, 7, 25).unwrap()),
            EstadoVigencia::Vigente
        );
    }

    #[test]
    fn test_debe_expirar_activo_vencido() {
        let v = vigencia_base(
            "TEMPORARY",
            Some(NaiveDate::from_ymd_opt(2026, 1, 1).unwrap()),
        );
        assert!(debe_expirar(&v, NaiveDate::from_ymd_opt(2026, 7, 25).unwrap()));
    }

    #[test]
    fn test_no_debe_expirar_si_ya_deprecated() {
        let mut v = vigencia_base(
            "TEMPORARY",
            Some(NaiveDate::from_ymd_opt(2026, 1, 1).unwrap()),
        );
        v.status_actual = RolStatusDb::Deprecated;
        assert!(!debe_expirar(&v, NaiveDate::from_ymd_opt(2026, 7, 25).unwrap()));
    }

    #[test]
    fn test_inferir_trigger_con_actor_es_manual() {
        assert_eq!(
            inferir_trigger_type(Some("user-uuid"), "ctx.b02.expiry"),
            TriggerType::Manual
        );
    }

    #[test]
    fn test_inferir_trigger_reconcile_por_ctx_id() {
        assert_eq!(
            inferir_trigger_type(None, "system.b02.reconcile.cronjob"),
            TriggerType::Reconcile
        );
    }

    #[test]
    fn test_inferir_trigger_default_es_auto_expiry() {
        assert_eq!(
            inferir_trigger_type(None, "system.b02.trigger"),
            TriggerType::AutoExpiry
        );
    }
}
