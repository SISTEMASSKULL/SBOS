// ============================================================
// bauth::server::handlers::sync_status — bauth.sync.status
//
// Retorna métricas del estado actual de bAuth en BD:
//   - Conteo de roles, átomos, usuarios, sesiones, credenciales
//   - Conteo de algoritmos criptográficos por estado
//   - Conteo de intentos de autenticación recientes
//
// DOC-SBOS-001 N3 · NIST SP 800-53 Rev.5 CA-7 (Continuous Monitoring)
// ============================================================

#![allow(dead_code)]
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::{json, Value};

pub struct SyncStatusHandler {
    pub pg_pool: Option<sqlx::PgPool>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for SyncStatusHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code:    -32000,
            message: "base de datos no disponible".into(),
            data:    None,
        })?;

        // Consultas en paralelo — cada una retorna 0 en caso de error
        let (roles, atomos, usuarios_activos, sesiones_activas,
             creds_activas, algoritmos_approved, intentos_1h) = tokio::join!(
            contar(pg, "SELECT COUNT(*) FROM bauth.idn_roles_rol_hierarchical"),
            contar(pg, "SELECT COUNT(*) FROM bauth.idn_roles_template WHERE node_type='atom' AND is_active=TRUE"),
            contar(pg, "SELECT COUNT(*) FROM bauth.idn_user WHERE status='ACTIVE'"),
            contar(pg, "SELECT COUNT(*) FROM bauth.ses_session_log WHERE terminated_at IS NULL"),
            contar(pg, "SELECT COUNT(*) FROM bauth.auth_credential WHERE status='ACTIVE'"),
            contar(pg, "SELECT COUNT(*) FROM bauth.auth_crypto_algorithm WHERE status='APPROVED'"),
            contar(pg, "SELECT COUNT(*) FROM bauth.auth_attempt_log WHERE attempted_at > now() - interval '1 hour'"),
        );

        // Átomos con posición vs sin posición
        let atomos_con_pos = contar(
            pg,
            "SELECT COUNT(*) FROM bauth.idn_roles_template WHERE node_type='atom' AND is_active=TRUE AND atom_position IS NOT NULL"
        ).await;

        Ok(json!({
            "status":     "OPERATIONAL",
            "timestamp":  chrono::Utc::now().to_rfc3339(),
            "identidad": {
                "roles_total":        roles,
                "atomos_activos":     atomos,
                "atomos_con_posicion": atomos_con_pos,
                "usuarios_activos":   usuarios_activos,
            },
            "sesiones": {
                "activas":            sesiones_activas,
                "credenciales_activas": creds_activas,
                "intentos_ultima_hora": intentos_1h,
            },
            "criptografia": {
                "algoritmos_aprobados": algoritmos_approved,
            },
            "reconciler": {
                "nombre":      "reconcile_loop",
                "intervalo_s": 60,
                "estado":      "PLANIFICADO",
                "nota":        "Reconciler automático activado cuando bitmask desktop esté poblado",
            },
        }))
    }
}

/// Ejecuta un COUNT(*) y retorna 0 en caso de error.
async fn contar(pg: &sqlx::PgPool, sql: &str) -> i64 {
    sqlx::query_scalar::<_, i64>(sql)
        .fetch_one(pg)
        .await
        .unwrap_or(0)
}
