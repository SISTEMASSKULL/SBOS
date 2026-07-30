// ==================================================================
// bauth::domain::versioning::policy — Lectura de política B3
//
// Lee la configuración de quórum/SLA para cambios MAJOR desde:
//   1. b3_defaults.toml  → valores base del sistema
//   2. metadata_b1 JSONB  → override por rol (clave "b3_override")
//
// Estructura metadata_b1.b3_override (opcional, anula defaults):
//   {
//     "required_approvers": 3,
//     "sla_horas": 72,
//     "escalation_horas": 120,
//     "approver_roles": ["biz.director"],
//     "escalation_to": ["bauth.admin"]
//   }
//
// NIST SP 800-53 AC-5 · CM-3 · ISO 27001:2022 A.5.3
// Sin I/O en tiempo de request — cargado una vez al inicio.
// ==================================================================

#![allow(dead_code)]

use super::VersioningError;
use chrono::{DateTime, Duration, Utc};
use serde::Deserialize;
use serde_json::Value;

/// Ruta por defecto de los defaults B3.
pub const RUTA_DEFAULT_B3: &str = "/etc/bos/b3_defaults.toml";

/// Parámetros de quórum y SLA del bloque B3 para cambios MAJOR.
#[derive(Debug, Clone)]
pub struct ConfigB3 {
    /// Número mínimo de votos de aprobación para alcanzar quórum.
    pub required_approvers: i32,
    /// Roles que pueden emitir votos válidos (AC-5 — aprobadores autorizados).
    pub approver_roles: Vec<String>,
    /// Horas hasta expiración del SLA de aprobación (CM-3).
    pub sla_horas: i64,
    /// Horas adicionales antes de escalado (None = sin escalado automático).
    pub escalation_horas: Option<i64>,
    /// Roles al que escala cuando supera el deadline de escalado.
    pub escalation_to: Vec<String>,
}

impl ConfigB3 {
    /// Carga los defaults desde un archivo TOML.
    pub fn desde_toml(ruta: &str) -> Result<Self, VersioningError> {
        let contenido = std::fs::read_to_string(ruta).map_err(|e| {
            VersioningError::Configuracion(format!("no se pudo leer '{ruta}': {e}"))
        })?;
        Self::desde_str(&contenido)
    }

    /// Parsea desde un string TOML (útil para tests).
    pub fn desde_str(toml_str: &str) -> Result<Self, VersioningError> {
        let raw: ConfigB3Cruda = toml::from_str(toml_str).map_err(|e| {
            VersioningError::Configuracion(format!("TOML inválido en b3_defaults: {e}"))
        })?;
        if raw.required_approvers < 1 {
            return Err(VersioningError::Configuracion(
                "required_approvers debe ser ≥ 1".into()
            ));
        }
        if raw.sla_horas < 1 {
            return Err(VersioningError::Configuracion(
                "sla_horas debe ser ≥ 1".into()
            ));
        }
        Ok(ConfigB3 {
            required_approvers: raw.required_approvers,
            approver_roles: raw.approver_roles,
            sla_horas: raw.sla_horas,
            escalation_horas: raw.escalation_horas,
            escalation_to: raw.escalation_to,
        })
    }

    /// Aplica overrides opcionales del campo `b3_override` en metadata_b1.
    ///
    /// Solo los campos presentes en el JSON sobreescriben los defaults.
    pub fn con_override(mut self, metadata_b1: &Value) -> Self {
        let Some(ovr) = metadata_b1.get("b3_override") else { return self; };

        if let Some(v) = ovr.get("required_approvers").and_then(|x| x.as_i64()) {
            if v >= 1 { self.required_approvers = v as i32; }
        }
        if let Some(v) = ovr.get("sla_horas").and_then(|x| x.as_i64()) {
            if v >= 1 { self.sla_horas = v; }
        }
        if let Some(v) = ovr.get("escalation_horas").and_then(|x| x.as_i64()) {
            self.escalation_horas = Some(v);
        }
        if let Some(arr) = ovr.get("approver_roles").and_then(|x| x.as_array()) {
            let roles: Vec<String> = arr.iter()
                .filter_map(|x| x.as_str().map(String::from))
                .collect();
            if !roles.is_empty() { self.approver_roles = roles; }
        }
        if let Some(arr) = ovr.get("escalation_to").and_then(|x| x.as_array()) {
            let roles: Vec<String> = arr.iter()
                .filter_map(|x| x.as_str().map(String::from))
                .collect();
            if !roles.is_empty() { self.escalation_to = roles; }
        }
        self
    }

    /// Calcula el timestamp de deadline SLA desde `now`.
    pub fn sla_deadline(&self, now: DateTime<Utc>) -> DateTime<Utc> {
        now + Duration::hours(self.sla_horas)
    }
}

// ── Estructura de deserialización TOML ──────────────────────────

#[derive(Debug, Deserialize)]
struct ConfigB3Cruda {
    required_approvers: i32,
    approver_roles: Vec<String>,
    sla_horas: i64,
    escalation_horas: Option<i64>,
    #[serde(default)]
    escalation_to: Vec<String>,
}

// ── TESTS ────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn toml_valido() -> &'static str {
        r#"
required_approvers = 2
sla_horas = 48
escalation_horas = 96
approver_roles = ["bauth.admin"]
escalation_to = ["bauth.superuser"]
        "#
    }

    #[test]
    fn carga_defaults_ok() {
        let c = ConfigB3::desde_str(toml_valido()).unwrap();
        assert_eq!(c.required_approvers, 2);
        assert_eq!(c.sla_horas, 48);
        assert_eq!(c.escalation_horas, Some(96));
    }

    #[test]
    fn override_de_metadata_b1() {
        let c = ConfigB3::desde_str(toml_valido()).unwrap();
        let meta = json!({"b3_override": {"required_approvers": 3, "sla_horas": 72}});
        let c2 = c.con_override(&meta);
        assert_eq!(c2.required_approvers, 3);
        assert_eq!(c2.sla_horas, 72);
        // escalation_horas no cambia
        assert_eq!(c2.escalation_horas, Some(96));
    }

    #[test]
    fn override_invalido_ignorado() {
        let c = ConfigB3::desde_str(toml_valido()).unwrap();
        let meta = json!({"b3_override": {"required_approvers": 0}});
        let c2 = c.con_override(&meta);
        assert_eq!(c2.required_approvers, 2); // 0 ignorado, se mantiene el default
    }

    #[test]
    fn sla_deadline_calcula_correctamente() {
        let c = ConfigB3::desde_str(toml_valido()).unwrap();
        let now = Utc::now();
        let deadline = c.sla_deadline(now);
        let diff = deadline - now;
        assert_eq!(diff.num_hours(), 48);
    }
}
