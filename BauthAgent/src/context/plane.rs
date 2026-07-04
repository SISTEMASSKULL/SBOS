// ============================================================
// bauth::context::plane — B16 Context Plane (SBOS-049)
//
// ARQUITECTURA:
//   BOS (IAM Installer) → CREA ctx_id (governor del ciclo de vida)
//   bAuth (Identity Core) → VALIDA + INYECTA tenant/user/role
//   Kong (API Gateway) → ENFORCE vía PEP (X-SBOS-Context header)
//   Todos los daemons → PROPAGAN vía W3C traceparent + OTel Baggage
//
// PATRÓN LOBBY — Tenant 0 como portal de entrada (C-BAUTH-004, 2026-06-28):
//   Dispositivo NUEVO → sin tenant → BOS asigna TENANT_0 (skull)
//     → ctx.create(tenant_0, empresa_default, null, "LOBBY")
//     → dctx_id en lobby, LoA=0, sin bitmask, sin privilegios
//     → Usuario autentica → promote al tenant/empresa/sucursal REAL
//     → Dispositivo enrutado definitivamente
//
// Formato canónico del ctx_id (SBOS-049 §3):
//   tenant_id:empresa_id:sucursal_id:pos_logico:user_id:traceparent
//
// Referencias:
//   W3C Trace Context Level 2 (2025)
//   OpenTelemetry Baggage
//   NIST SP 800-207 Zero Trust (PDP + PEP)
//   ISO 27001:2022 A.8.15 (Logging)
// ============================================================
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Contexto operativo completo — 6 campos canónicos (SBOS-049 §3).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CtxPlane {
    /// Tenant SBOS (UUID v4)
    pub tenant_id: Uuid,
    /// Empresa dentro del tenant (UUID v4)
    pub empresa_id: Uuid,
    /// Sucursal física o lógica (UUID v4, opcional)
    pub sucursal_id: Option<Uuid>,
    /// Punto de operación lógico (ej: "POS-01", "BACKOFFICE")
    pub pos_logico: String,
    /// Usuario autenticado (UUID v4)
    pub user_id: Uuid,
    /// W3C Trace Context: version-traceid-spanid-flags
    pub traceparent: String,
    /// Nonce único anti-replay (UUID v7)
    pub nonce: Uuid,
    /// Timestamp de creación (UTC)
    pub created_at: chrono::DateTime<chrono::Utc>,
    /// Número de secuencia incremental por operación
    pub sequence: u64,
    /// TTL en segundos desde created_at
    pub ttl_seconds: u64,
}

/// Estados del ctx_id en su ciclo de vida.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum CtxState {
    /// Pre-autenticación: BOS lo crea, usuario aún no autenticado
    Pending,
    /// Post-autenticación: bAuth promovió, bitmask asignado
    Active,
    /// Logout o timeout: contexto invalidado
    Invalidated,
    /// Anomalía detectada: requiere investigación
    Quarantined,
}

impl CtxPlane {
    /// Crea un nuevo contexto pre-autenticación (dctx_id).
    /// Llamado por BOS cuando el dispositivo arranca.
    pub fn new_pending(
        tenant_id: Uuid,
        empresa_id: Uuid,
        sucursal_id: Option<Uuid>,
        pos_logico: &str,
        ttl_seconds: u64,
    ) -> Self {
        CtxPlane {
            tenant_id,
            empresa_id,
            sucursal_id,
            pos_logico: pos_logico.to_string(),
            user_id: Uuid::nil(),       // Sin usuario aún (pre-auth)
            traceparent: Self::generate_traceparent(),
            nonce: Uuid::new_v4(),
            created_at: chrono::Utc::now(),
            sequence: 0,
            ttl_seconds,
        }
    }

    /// Promueve de dctx_id → ctx_id: asigna usuario y bitmask.
    /// Llamado por bAuth después de autenticación exitosa.
    pub fn promote(&mut self, user_id: Uuid) {
        self.user_id = user_id;
        self.nonce = Uuid::new_v4();     // Nuevo nonce post-auth
        self.sequence = 1;               // Reiniciar secuencia
        self.traceparent = Self::generate_traceparent(); // Nuevo trace
    }

    /// Genera un W3C traceparent: 00-{trace_id}-{span_id}-01
    pub fn generate_traceparent() -> String {
        let trace_id = Uuid::new_v4().to_string().replace('-', "");
        let span_id = &Uuid::new_v4().to_string().replace('-', "")[..16];
        format!("00-{}-{}-01", trace_id, span_id)
    }

    /// Serializa al formato canónico para headers HTTP.
    pub fn to_header(&self) -> String {
        format!(
            "{}:{}:{}:{}:{}:{}",
            self.tenant_id,
            self.empresa_id,
            self.sucursal_id.map_or("null".into(), |id| id.to_string()),
            self.pos_logico,
            self.user_id,
            self.traceparent
        )
    }

    /// Parsea desde el formato canónico.
    pub fn from_header(header: &str) -> Result<Self, String> {
        let parts: Vec<&str> = header.split(':').collect();
        if parts.len() < 6 {
            return Err(format!("ctx_id inválido: {} campos (mín 6)", parts.len()));
        }

        let tenant_id = Uuid::parse_str(parts[0]).map_err(|e| format!("tenant_id: {}", e))?;
        let empresa_id = Uuid::parse_str(parts[1]).map_err(|e| format!("empresa_id: {}", e))?;
        let sucursal_id = if parts[2] == "null" || parts[2].is_empty() {
            None
        } else {
            Some(Uuid::parse_str(parts[2]).map_err(|e| format!("sucursal_id: {}", e))?)
        };
        let pos_logico = parts[3].to_string();
        let user_id = Uuid::parse_str(parts[4]).map_err(|e| format!("user_id: {}", e))?;

        // Validar traceparent W3C
        let tp = parts[5];
        if !tp.starts_with("00-") || tp.len() < 35 {
            return Err("traceparent inválido: debe ser 00-{trace_id}-{span_id}-01".into());
        }

        Ok(CtxPlane {
            tenant_id,
            empresa_id,
            sucursal_id,
            pos_logico,
            user_id,
            traceparent: tp.to_string(),
            nonce: Uuid::new_v4(),
            created_at: chrono::Utc::now(),
            sequence: 0,
            ttl_seconds: 3600, // default 1h
        })
    }

    /// Verifica si el contexto ha expirado.
    pub fn is_expired(&self) -> bool {
        let elapsed = chrono::Utc::now()
            .signed_duration_since(self.created_at)
            .num_seconds() as u64;
        elapsed > self.ttl_seconds
    }

    /// True si es pre-auth (sin usuario asignado).
    pub fn is_pending(&self) -> bool {
        self.user_id.is_nil()
    }

    /// True si está activo (usuario asignado, no expirado).
    pub fn is_active(&self) -> bool {
        !self.user_id.is_nil() && !self.is_expired()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_pending_has_nil_user() {
        let ctx = CtxPlane::new_pending(
            Uuid::new_v4(), Uuid::new_v4(), None, "POS-01", 3600,
        );
        assert!(ctx.is_pending());
        assert_eq!(ctx.sequence, 0);
        assert!(ctx.traceparent.starts_with("00-"));
    }

    #[test]
    fn test_promote_activates_context() {
        let mut ctx = CtxPlane::new_pending(
            Uuid::new_v4(), Uuid::new_v4(), None, "POS-01", 3600,
        );
        let user_id = Uuid::new_v4();
        ctx.promote(user_id);
        assert!(ctx.is_active());
        assert_eq!(ctx.user_id, user_id);
        assert_eq!(ctx.sequence, 1);
        assert!(!ctx.is_pending());
    }

    #[test]
    fn test_header_roundtrip() {
        let ctx = CtxPlane {
            tenant_id: Uuid::parse_str("4c697f66-d204-45a5-ac36-c104f07c7046").unwrap(),
            empresa_id: Uuid::parse_str("a1b2c3d4-e5f6-7890-abcd-ef1234567890").unwrap(),
            sucursal_id: Some(Uuid::parse_str("f9e8d7c6-b5a4-3210-fedc-ba9876543210").unwrap()),
            pos_logico: "POS-01".into(),
            user_id: Uuid::parse_str("11111111-2222-3333-4444-555555555555").unwrap(),
            traceparent: "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01".into(),
            nonce: Uuid::new_v4(),
            created_at: chrono::Utc::now(),
            sequence: 42,
            ttl_seconds: 3600,
        };

        let header = ctx.to_header();
        let restored = CtxPlane::from_header(&header).unwrap();

        assert_eq!(restored.tenant_id, ctx.tenant_id);
        assert_eq!(restored.empresa_id, ctx.empresa_id);
        assert_eq!(restored.sucursal_id, ctx.sucursal_id);
        assert_eq!(restored.pos_logico, ctx.pos_logico);
        assert_eq!(restored.user_id, ctx.user_id);
        assert_eq!(restored.traceparent, ctx.traceparent);
    }

    #[test]
    fn test_expiry() {
        let ctx = CtxPlane {
            tenant_id: Uuid::new_v4(), empresa_id: Uuid::new_v4(),
            sucursal_id: None, pos_logico: "TEST".into(),
            user_id: Uuid::new_v4(),
            traceparent: CtxPlane::generate_traceparent(),
            nonce: Uuid::new_v4(),
            created_at: chrono::Utc::now() - chrono::Duration::hours(2),
            sequence: 1, ttl_seconds: 3600,
        };
        assert!(ctx.is_expired());
    }

    #[test]
    fn test_w3c_traceparent_format() {
        let tp = CtxPlane::generate_traceparent();
        assert!(tp.starts_with("00-"), "debe empezar con 00-");
        assert!(tp.ends_with("-01"), "flags=01 (sampled)");
        let parts: Vec<&str> = tp.split('-').collect();
        assert_eq!(parts.len(), 4, "formato: version-traceid-spanid-flags");
        assert_eq!(parts[0], "00");
        assert_eq!(parts[1].len(), 32, "trace_id = 32 hex chars");
        assert_eq!(parts[2].len(), 16, "span_id = 16 hex chars");
        assert_eq!(parts[3], "01");
    }
}
