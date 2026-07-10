// ============================================================
// bauth::domain::caep — Eventos CAEP (Shared Signals Framework)
//
// Propósito: tipos PUROS de los eventos de continuidad de acceso
//   que bAuth emite como SSF Transmitter hacia bNotify (Receiver),
//   según el contrato C-BAUTH-004 (context/contracts/BAUTH-BNOTIFY-CONTRATOS.md).
// Entradas: datos de la sesión afectada (ctx_id, usuario, tenant, instante).
// Salidas: `EventoCaep` con `event_id` determinista (idempotencia C-BNOTIFY-002 §3).
// Dependencias: sha2 + hex (hash) — SIN I/O, SIN red, SIN base de datos.
// Estándar: OpenID Shared Signals Framework / CAEP 1.0 · NIST SP 800-207
//   (respuesta en tiempo real) · SBOS-049 (ctx_id obligatorio).
// ============================================================
#![allow(dead_code)]

use sha2::{Digest, Sha256};
use std::collections::BTreeMap;

/// Los 5 tipos de evento CAEP que bAuth emite hacia bNotify (C-BAUTH-004).
///
/// El texto de alambre (`como_texto`) es EXACTO al contrato — bNotify
/// enruta por ese string y cualquier variación rompería el receptor.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TipoEventoCaep {
    /// Sesión revocada (offboarding, suspensión, violación, expiración).
    SesionRevocada,
    /// Cambio de credencial (password nuevo, MFA registrado).
    CambioCredencial,
    /// Cambio de nivel de aseguramiento (promoción KYC T0→T1→T2).
    CambioNivelAseguramiento,
    /// Dispositivo fuera de cumplimiento (jailbreak, MDM).
    CambioCumplimientoDispositivo,
    /// El Risk Engine detectó un cambio de nivel de riesgo.
    CambioNivelRiesgo,
}

impl TipoEventoCaep {
    /// Nombre de alambre del contrato C-BAUTH-004 (kebab-case, inmutable).
    pub fn como_texto(&self) -> &'static str {
        match self {
            TipoEventoCaep::SesionRevocada => "session-revoked",
            TipoEventoCaep::CambioCredencial => "credential-change",
            TipoEventoCaep::CambioNivelAseguramiento => "assurance-level-change",
            TipoEventoCaep::CambioCumplimientoDispositivo => "device-compliance-change",
            TipoEventoCaep::CambioNivelRiesgo => "risk-level-change",
        }
    }
}

/// Evento CAEP de dominio — la unidad que bAuth transmite a bNotify.
///
/// Campos según el proto del contrato (CaepEvent, tags 1..6):
/// `event_type`, `subject_ctx_id`, `subject_user_id`, `tenant_id`,
/// `occurred_at` (RFC3339 UTC) y `event_data` (metadatos, incluye
/// el `event_id` de idempotencia).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EventoCaep {
    /// Tipo del evento (uno de los 5 del contrato).
    pub tipo: TipoEventoCaep,
    /// ctx_id de la sesión afectada (SBOS-049).
    pub subject_ctx_id: String,
    /// UUID bAuth del usuario afectado (vacío si no aplica).
    pub subject_user_id: String,
    /// Tenant al que pertenece la sesión (vacío si no aplica).
    pub tenant_id: String,
    /// Instante del hecho en RFC3339 UTC (ej. "2026-07-10T21:00:00Z").
    /// DEBE ser estable entre re-lecturas: participa del event_id.
    pub occurred_at: String,
    /// Metadatos adicionales del evento (ordenados — determinista).
    pub event_data: BTreeMap<String, String>,
}

impl EventoCaep {
    /// Construye un evento `session-revoked` para una sesión invalidada.
    ///
    /// Parámetros: `ctx_id` de la sesión, `user_id` (UUID bAuth),
    /// `tenant_id`, `occurred_at` (RFC3339 UTC del `invalidated_at`),
    /// y `origen` (quién detectó: "reconcile", "handler", …).
    pub fn sesion_revocada(
        ctx_id: &str,
        user_id: &str,
        tenant_id: &str,
        occurred_at: &str,
        origen: &str,
    ) -> Self {
        let mut event_data = BTreeMap::new();
        event_data.insert("origen".to_string(), origen.to_string());
        Self {
            tipo: TipoEventoCaep::SesionRevocada,
            subject_ctx_id: ctx_id.to_string(),
            subject_user_id: user_id.to_string(),
            tenant_id: tenant_id.to_string(),
            occurred_at: occurred_at.to_string(),
            event_data,
        }
    }

    /// Identificador determinista del evento (idempotencia C-BNOTIFY-002 §3).
    ///
    /// SHA-256 sobre `tipo|ctx_id|occurred_at`, truncado a 16 bytes (32 hex).
    /// El mismo hecho produce SIEMPRE el mismo id — si bAuth se reinicia y
    /// re-lee la misma sesión revocada, bNotify deduplica por este id.
    /// No incluye `event_data`: agregar metadatos no cambia la identidad.
    pub fn event_id(&self) -> String {
        let mut hasher = Sha256::new();
        hasher.update(self.tipo.como_texto().as_bytes());
        hasher.update(b"|");
        hasher.update(self.subject_ctx_id.as_bytes());
        hasher.update(b"|");
        hasher.update(self.occurred_at.as_bytes());
        let hash = hasher.finalize();
        hex::encode(&hash[..16])
    }
}

// ── TESTS ───────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_texto_de_alambre_exacto_al_contrato() {
        // Los strings son parte del contrato C-BAUTH-004 — no pueden variar.
        assert_eq!(TipoEventoCaep::SesionRevocada.como_texto(), "session-revoked");
        assert_eq!(TipoEventoCaep::CambioCredencial.como_texto(), "credential-change");
        assert_eq!(TipoEventoCaep::CambioNivelAseguramiento.como_texto(), "assurance-level-change");
        assert_eq!(TipoEventoCaep::CambioCumplimientoDispositivo.como_texto(), "device-compliance-change");
        assert_eq!(TipoEventoCaep::CambioNivelRiesgo.como_texto(), "risk-level-change");
    }

    #[test]
    fn test_event_id_es_determinista() {
        let a = EventoCaep::sesion_revocada("ctx-1", "u-1", "t-1", "2026-07-10T21:00:00Z", "reconcile");
        let b = EventoCaep::sesion_revocada("ctx-1", "u-1", "t-1", "2026-07-10T21:00:00Z", "reconcile");
        assert_eq!(a.event_id(), b.event_id());
        assert_eq!(a.event_id().len(), 32); // 16 bytes en hex
    }

    #[test]
    fn test_event_id_distingue_hechos_distintos() {
        let a = EventoCaep::sesion_revocada("ctx-1", "u-1", "t-1", "2026-07-10T21:00:00Z", "reconcile");
        let b = EventoCaep::sesion_revocada("ctx-2", "u-1", "t-1", "2026-07-10T21:00:00Z", "reconcile");
        let c = EventoCaep::sesion_revocada("ctx-1", "u-1", "t-1", "2026-07-10T21:00:01Z", "reconcile");
        assert_ne!(a.event_id(), b.event_id()); // otra sesión
        assert_ne!(a.event_id(), c.event_id()); // otro instante
    }

    #[test]
    fn test_metadatos_no_cambian_la_identidad() {
        let a = EventoCaep::sesion_revocada("ctx-1", "u-1", "t-1", "2026-07-10T21:00:00Z", "reconcile");
        let mut b = a.clone();
        b.event_data.insert("extra".into(), "dato".into());
        assert_eq!(a.event_id(), b.event_id());
    }
}
