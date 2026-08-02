// ============================================================
// bauth::server::handlers::sync_reconcile — bauth.sync.reconcile
//
// Dispara una verificación de drift en tiempo real.
// Compara el estado declarado (roles, átomos, sesiones) contra
// la proyección actual en BD y detecta inconsistencias.
//
// Checks implementados:
//   1. Átomos sin posición asignada (atom_position NULL)
//   2. Sesiones activas con usuario inactivo/revocado
//   3. Grants sin atom_path válido en idn_roles_template
//   4. Credenciales expiradas aún en status=ACTIVE
//
// DOC-SBOS-001 N3 · NIST SP 800-53 Rev.5 AC-2 · ISO 27001 A.9.2
// ============================================================

#![allow(dead_code)]
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::{json, Value};

pub struct SyncReconcileHandler {
    pub pg_pool: Option<sqlx::PgPool>,
}

#[async_trait::async_trait]
impl JsonRpcHandler for SyncReconcileHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code:    -32000,
            message: "base de datos no disponible".into(),
            data:    None,
        })?;

        let inicio = chrono::Utc::now();
        let mut hallazgos: Vec<Value> = Vec::new();

        // ── Check 1: Átomos sin posición asignada ─────────────────────────
        if let Ok(Some((n,))) = sqlx::query_as::<_, (i64,)>(
            "SELECT COUNT(*) FROM bauth.idn_roles_template
             WHERE node_type = 'atom' AND is_active = TRUE AND atom_position IS NULL"
        )
        .fetch_optional(pg)
        .await
        {
            if n > 0 {
                hallazgos.push(json!({
                    "check":    "atomos_sin_posicion",
                    "severity": "ALTA",
                    "count":    n,
                    "accion":   "Asignar atom_position desde desktop antes de evaluar bitmask",
                }));
            }
        }

        // ── Check 2: Sesiones activas con usuario no ACTIVE ───────────────
        if let Ok(Some((n,))) = sqlx::query_as::<_, (i64,)>(
            "SELECT COUNT(*) FROM bauth.ses_session_log sl
             JOIN bauth.idn_user u ON u.user_id = sl.user_id
             WHERE sl.terminated_at IS NULL
               AND u.status::text != 'ACTIVE'"
        )
        .fetch_optional(pg)
        .await
        {
            if n > 0 {
                hallazgos.push(json!({
                    "check":    "sesiones_usuario_inactivo",
                    "severity": "CRITICA",
                    "count":    n,
                    "accion":   "Terminar sesiones de usuarios suspendidos/revocados",
                }));
            }
        }

        // ── Check 3: Credenciales ACTIVE con valid_until expirado ─────────
        if let Ok(Some((n,))) = sqlx::query_as::<_, (i64,)>(
            "SELECT COUNT(*) FROM bauth.auth_credential
             WHERE status = 'ACTIVE'
               AND valid_until IS NOT NULL
               AND valid_until < now()"
        )
        .fetch_optional(pg)
        .await
        {
            if n > 0 {
                hallazgos.push(json!({
                    "check":    "credenciales_expiradas_activas",
                    "severity": "ALTA",
                    "count":    n,
                    "accion":   "UPDATE auth_credential SET status='EXPIRED' WHERE valid_until < now()",
                }));
            }
        }

        // ── Check 4: Grants con atom_path sin nodo activo en template ─────
        if let Ok(Some((n,))) = sqlx::query_as::<_, (i64,)>(
            "SELECT COUNT(*) FROM bauth.privilege_atom_grant pag
             WHERE NOT EXISTS (
                 SELECT 1 FROM bauth.idn_roles_template irt
                 WHERE irt.path = pag.atom_path
                   AND irt.node_type = 'atom'
                   AND irt.is_active = TRUE
             )
             AND (pag.expires_at IS NULL OR pag.expires_at > now())"
        )
        .fetch_optional(pg)
        .await
        {
            if n > 0 {
                hallazgos.push(json!({
                    "check":    "grants_atom_path_invalido",
                    "severity": "ALTA",
                    "count":    n,
                    "accion":   "Revisar privilege_atom_grant — atom_path no referencia átomo activo",
                }));
            }
        }

        let duracion_ms = chrono::Utc::now()
            .signed_duration_since(inicio)
            .num_milliseconds();

        let estado = if hallazgos.is_empty() { "LIMPIO" } else { "DRIFT_DETECTADO" };

        tracing::info!(
            estado, hallazgos = hallazgos.len(), duracion_ms,
            "sync.reconcile — verificación completada"
        );

        Ok(json!({
            "status":          estado,
            "executed_at":     inicio.to_rfc3339(),
            "duration_ms":     duracion_ms,
            "checks_executed": 4,
            "hallazgos":       hallazgos,
            "hallazgos_count": hallazgos.len(),
            "message": if hallazgos.is_empty() {
                "Sin drift detectado — estado coherente"
            } else {
                "Drift detectado — revisar hallazgos y ejecutar acciones de remediación"
            },
        }))
    }
}
