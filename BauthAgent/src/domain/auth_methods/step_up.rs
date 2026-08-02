// ============================================================
// bauth::domain::auth_methods::step_up — Método STEP_UP (E12)
//
// Step-Up Authentication — RFC 9470.
// Evalúa si la sesión activa tiene un Level of Assurance (LoA) suficiente
// para una operación que requiere LoA mayor al original.
//
// Flujo RFC 9470:
//   1. El PDP evalúa que el recurso solicitado requiere AAL2/AAL3
//   2. Este método consulta ses_session_log.loa_peak de la sesión activa
//   3. Si loa_peak >= loa_required → PERMITIDO (ValidateResult::valid=true)
//   4. Si loa_peak < loa_required → DESAFÍO (retorna los métodos disponibles
//      para elevar el LoA — el cliente debe re-autenticarse con uno de ellos)
//
// Columnas canónicas DDL v2.12.0:
//   bauth.ses_session_log.loa_peak   — nivel actual alcanzado en la sesión
//   bauth.auth_method                — métodos disponibles por categoría de LoA
//
// El step-up NO tiene fase de enrolamiento — es una evaluación de sesión.
// La elevación real ocurre cuando el usuario completa un método de mayor LoA
// y el servidor llama bauth.token.refresh con el nuevo loa_peak.
//
// DOC-SBOS-001 N3 · RFC 9470 · NIST SP 800-63B-4 §4 (AAL)
// ============================================================

#![allow(dead_code)]

use super::{AuthMethod, AuthMethodError, EnrollResult, ValidateResult};
use async_trait::async_trait;
use serde_json::Value;
use sqlx::PgPool;

// ── Conversión LoA TEXT ↔ nivel numérico ─────────────────────

/// Convierte la representación textual AAL1/AAL2/AAL3 a nivel numérico (1-3).
fn aal_a_nivel(aal: &str) -> u8 {
    match aal.to_uppercase().as_str() {
        "AAL1" | "1" => 1,
        "AAL2" | "2" => 2,
        "AAL3" | "3" => 3,
        _ => 1,
    }
}

/// Convierte nivel numérico (1-3) a representación textual AAL.
fn nivel_a_aal(nivel: u8) -> &'static str {
    match nivel {
        3 => "AAL3",
        2 => "AAL2",
        _ => "AAL1",
    }
}

// ── StepUpMethod ──────────────────────────────────────────────

/// Método de Step-Up Authentication (RFC 9470).
///
/// Evalúa si la sesión activa satisface el LoA requerido por la operación.
/// No enrolla usuarios — es una evaluación de estado de sesión.
pub struct StepUpMethod {
    pg: PgPool,
}

impl StepUpMethod {
    /// Crea una nueva instancia del evaluador de Step-Up.
    pub fn new(pg: PgPool) -> Self {
        Self { pg }
    }

    /// Obtiene el loa_peak actual de la sesión identificada por ctx_id.
    async fn loa_peak_sesion(
        &self,
        ctx_id: &str,
        user_id: uuid::Uuid,
    ) -> Result<u8, AuthMethodError> {
        let row: Option<(String,)> = sqlx::query_as(
            "SELECT loa_peak FROM bauth.ses_session_log
             WHERE ctx_id = $1 AND user_id = $2 AND terminated_at IS NULL
             ORDER BY started_at DESC LIMIT 1"
        )
        .bind(ctx_id)
        .bind(user_id)
        .fetch_optional(&self.pg)
        .await
        .map_err(|e| AuthMethodError::Internal {
            method: "STEP_UP".into(),
            message: format!("error consultando sesión: {}", e),
        })?;

        Ok(row.map(|(loa,)| aal_a_nivel(&loa)).unwrap_or(1))
    }

    /// Lista los métodos disponibles para elevar al LoA requerido.
    async fn metodos_para_elevar(&self, loa_required: u8) -> Vec<Value> {
        let loa_text = nivel_a_aal(loa_required);

        let rows: Vec<(String, String)> = sqlx::query_as(
            "SELECT method_id::text, name->>'es'
             FROM bauth.auth_method
             WHERE loa_provided = $1 AND status = 'IMPLEMENTED'
             ORDER BY sort_order"
        )
        .bind(loa_text)
        .fetch_all(&self.pg)
        .await
        .unwrap_or_default();

        rows.iter().map(|(id, name)| serde_json::json!({
            "method_id": id,
            "method_name": name,
            "loa_provided": loa_text,
        })).collect()
    }
}

#[async_trait]
impl AuthMethod for StepUpMethod {
    fn method_id(&self) -> &str { "STEP_UP" }

    fn method_name(&self) -> &str { "Step-Up Authentication" }

    fn aal_level(&self) -> u8 { 2 }

    fn standard_ref(&self) -> &str { "RFC 9470 · NIST SP 800-63B-4 §4" }

    /// Evalúa si la sesión activa cumple el LoA requerido.
    ///
    /// Entrada esperada:
    /// ```json
    /// {
    ///   "user_uuid":    "<UUID>",
    ///   "ctx_id":       "<ctx_id de la sesión activa>",
    ///   "required_loa": 2
    /// }
    /// ```
    async fn validate(&self, input: &Value) -> Result<ValidateResult, AuthMethodError> {
        let user_id_str = input.get("user_uuid").and_then(|v| v.as_str())
            .ok_or_else(|| AuthMethodError::MissingParam {
                method: "STEP_UP".into(), param: "user_uuid".into(),
            })?;
        let user_id = uuid::Uuid::parse_str(user_id_str)
            .map_err(|_| AuthMethodError::Internal {
                method: "STEP_UP".into(), message: "user_uuid inválido".into(),
            })?;

        let ctx_id = input.get("ctx_id").and_then(|v| v.as_str())
            .ok_or_else(|| AuthMethodError::MissingParam {
                method: "STEP_UP".into(), param: "ctx_id".into(),
            })?;

        let required_loa = input.get("required_loa")
            .and_then(|v| v.as_u64())
            .map(|v| v as u8)
            .unwrap_or(2);

        // Consultar LoA actual de la sesión
        let current_loa = self.loa_peak_sesion(ctx_id, user_id).await?;

        if current_loa >= required_loa {
            tracing::info!(
                %user_id, ctx_id, current_loa, required_loa,
                "step_up.validate — LoA suficiente"
            );
            Ok(ValidateResult {
                valid:         true,
                method_id:     "STEP_UP".into(),
                message:       format!("sesión en AAL{} satisface AAL{} requerido",
                               current_loa, required_loa),
                aal_satisfied: required_loa,
            })
        } else {
            // Obtener métodos disponibles para elevar el LoA
            let metodos = self.metodos_para_elevar(required_loa).await;

            tracing::info!(
                %user_id, ctx_id, current_loa, required_loa, "step_up.validate — step-up requerido"
            );

            Err(AuthMethodError::Internal {
                method: "STEP_UP".into(),
                message: serde_json::json!({
                    "step_up_required": true,
                    "current_loa":      current_loa,
                    "required_loa":     required_loa,
                    "available_methods": metodos,
                    "rfc":              "RFC 9470",
                }).to_string(),
            })
        }
    }

    /// El Step-Up no tiene fase de enrolamiento — siempre retorna éxito.
    async fn enroll(&self, _user_uuid: &str, _params: &Value) -> Result<EnrollResult, AuthMethodError> {
        Ok(EnrollResult {
            enrolled:       true,
            method_id:      "STEP_UP".into(),
            instance_id:    "N/A".into(),
            secret_preview: None,
            message:        "STEP_UP no requiere enrolamiento — evaluación de sesión activa".into(),
        })
    }

    /// El Step-Up no tiene credenciales revocables.
    async fn revoke(&self, _user_uuid: &str, _method_instance_id: &str) -> Result<(), AuthMethodError> {
        Ok(())
    }

    async fn health_check(&self) -> bool {
        sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM bauth.ses_session_log LIMIT 1")
            .fetch_one(&self.pg)
            .await
            .is_ok()
    }
}

// ── Tests ──────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_aal_conversion() {
        assert_eq!(aal_a_nivel("AAL1"), 1);
        assert_eq!(aal_a_nivel("AAL2"), 2);
        assert_eq!(aal_a_nivel("AAL3"), 3);
        assert_eq!(aal_a_nivel("DESCONOCIDO"), 1);
    }

    #[test]
    fn test_nivel_a_aal() {
        assert_eq!(nivel_a_aal(1), "AAL1");
        assert_eq!(nivel_a_aal(2), "AAL2");
        assert_eq!(nivel_a_aal(3), "AAL3");
        assert_eq!(nivel_a_aal(0), "AAL1");
    }
}
