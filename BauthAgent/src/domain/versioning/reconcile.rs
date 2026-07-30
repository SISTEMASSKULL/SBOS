// ==================================================================
// bauth::domain::versioning::reconcile — Loop B02 como tokio task
//
// ⚠️  EXCEPCIÓN DOCUMENTADA a la regla de dominio puro:
//     Este módulo tiene acceso a BD (sqlx::PgPool) porque implementa
//     el loop de reconciliación que reemplazará el CronJob K8s.
//     Justificación: el reconcile es un servicio de dominio orquestador
//     que coordina lectura-evaluación-escritura como unidad atómica.
//     No puede separarse en capas sin perder la atomicidad de cada ciclo.
//
// Reemplaza: CronJob K8s `bauth-b02-reconcile` en `sbos-security`
//            (ver A.70 — hasta que bAuth corra como pod en K8s)
//
// NIST SP 800-53 AC-2 · ISO 27001:2022 A.5.15
// ==================================================================

#![allow(dead_code)]

use super::lifecycle::{calcular_estado_vigencia, construir_validity_snapshot, EstadoVigencia};
use super::{RolStatusDb, TriggerType};
use chrono::{NaiveDate, Utc};
use sqlx::PgPool;
use std::time::Duration;
use uuid::Uuid;

/// Resultado de un ciclo de reconciliación B02.
#[derive(Debug, Default)]
pub struct ResultadoReconcile {
    /// Número de roles deprecados en este ciclo.
    pub deprecados: u32,
    /// Número de roles que fallaron al intentar deprecarlos.
    pub errores: u32,
    /// Timestamp de inicio del ciclo.
    pub inicio: chrono::DateTime<Utc>,
    /// Timestamp de fin del ciclo.
    pub fin: Option<chrono::DateTime<Utc>>,
}

/// Fila de rol expirado leída desde BD.
#[derive(Debug, sqlx::FromRow)]
struct FilaRolExpirado {
    id: Uuid,
    status: String,
    valid_until: NaiveDate,
    validity_type: String,
    valid_from: Option<NaiveDate>,
    duration_interval: Option<String>,
}

/// Ejecuta un ciclo de reconciliación de expiración B02.
///
/// Lógica (espejo Rust de `bauth.fn_b02_reconcile_expiry()`):
/// 1. Busca roles con `valid_until <= hoy` y estado no terminal
/// 2. Evalúa cada uno con `calcular_estado_vigencia()` (lógica de dominio)
/// 3. Actualiza el status a DEPRECATED en T-041
/// 4. Registra el evento en T-B02L vía INSERT
///
/// Garantías:
/// - `FOR UPDATE SKIP LOCKED`: no colisiona con el trigger `trg_irrh_b02_validity`
/// - Idempotente: re-ejecución no duplica eventos (el UPDATE afecta 0 filas si ya deprecated)
pub async fn ejecutar_ciclo_reconcile(
    pg: &PgPool,
    ctx_id: &str,
) -> Result<ResultadoReconcile, sqlx::Error> {
    let mut resultado = ResultadoReconcile {
        inicio: Utc::now(),
        ..Default::default()
    };

    let hoy = Utc::now().date_naive();

    let filas: Vec<FilaRolExpirado> = sqlx::query_as(
        r#"
        SELECT id, status::text, valid_until, validity_type::text,
               valid_from, duration_interval
        FROM bauth.idn_roles_rol_hierarchical
        WHERE valid_until IS NOT NULL
          AND valid_until <= $1
          AND status NOT IN ('DEPRECATED','ARCHIVED','INACTIVE')
        ORDER BY valid_until
        FOR UPDATE SKIP LOCKED
        "#,
    )
    .bind(hoy)
    .fetch_all(pg)
    .await?;

    for fila in filas {
        let status_actual: RolStatusDb = match fila.status.parse() {
            Ok(s) => s,
            Err(_) => {
                resultado.errores += 1;
                continue;
            }
        };

        let vigencia = super::lifecycle::VigenciaRol {
            validity_type: fila.validity_type.clone(),
            valid_from: fila.valid_from,
            valid_until: Some(fila.valid_until),
            duration_interval: fila.duration_interval.clone(),
            status_actual,
        };

        if calcular_estado_vigencia(&vigencia, hoy) != EstadoVigencia::Expirado {
            continue;
        }

        let ok = deprecar_rol(pg, fila.id, &vigencia, ctx_id).await;
        match ok {
            Ok(true) => resultado.deprecados += 1,
            Ok(false) => {} // ya estaba deprecado — carrera benigna
            Err(e) => {
                tracing::warn!(rol_id = %fila.id, error = %e, "reconcile: fallo al deprecar");
                resultado.errores += 1;
            }
        }
    }

    // B03: expirar propuestas PENDING cuyo SLA venció
    match crate::db::approval::expirar_sla_vencidos(pg).await {
        Ok(n) if n > 0 => tracing::info!(
            expiradas = n, %ctx_id,
            "reconcile B03: {} propuesta(s) PENDING expirada(s) por SLA vencido", n
        ),
        Ok(_) => {}
        Err(e) => tracing::warn!(error = %e, "reconcile B03: fallo al expirar SLAs vencidos"),
    }

    resultado.fin = Some(Utc::now());
    Ok(resultado)
}

/// Depreca un rol individual y registra el evento en T-B02L.
/// Retorna `true` si se actualizó alguna fila (false = carrera benigna).
async fn deprecar_rol(
    pg: &PgPool,
    rol_id: Uuid,
    vigencia: &super::lifecycle::VigenciaRol,
    ctx_id: &str,
) -> Result<bool, sqlx::Error> {
    let (afectadas,): (u64,) = {
        let res = sqlx::query(
            r#"
            UPDATE bauth.idn_roles_rol_hierarchical
            SET status = 'DEPRECATED'
            WHERE id = $1 AND status NOT IN ('DEPRECATED','ARCHIVED','INACTIVE')
            "#,
        )
        .bind(rol_id)
        .execute(pg)
        .await?;
        (res.rows_affected(),)
    };

    if afectadas == 0 {
        return Ok(false);
    }

    let snapshot = construir_validity_snapshot(vigencia, Utc::now());
    let razon = format!(
        "Vigencia expirada. valid_until={}. Detectado por reconcile loop Rust.",
        vigencia.valid_until.map(|d| d.to_string()).unwrap_or_default()
    );

    sqlx::query(
        r#"
        INSERT INTO bauth.idn_roles_rol_lifecycle_event
            (role_id, from_status, to_status, trigger_type,
             reason, validity_snapshot, ctx_id)
        VALUES
            ($1,
             $2::rol_status_enum,
             'DEPRECATED'::rol_status_enum,
             $3,
             $4,
             $5::jsonb,
             $6)
        "#,
    )
    .bind(rol_id)
    .bind(vigencia.status_actual.as_str())
    .bind(TriggerType::Reconcile.as_str())
    .bind(razon)
    .bind(snapshot)
    .bind(ctx_id)
    .execute(pg)
    .await?;

    Ok(true)
}

/// Inicia el loop de reconciliación B02 como tokio background task.
///
/// Se ejecuta cada `intervalo` segundos hasta que el token de parada
/// `stop_rx` reciba señal. Al arrancar el daemon bAuth, llamar:
///
/// ```rust,no_run
/// let (stop_tx, stop_rx) = tokio::sync::oneshot::channel();
/// tokio::spawn(iniciar_loop_reconcile(pool.clone(), stop_rx));
/// // ... para parar: stop_tx.send(()).ok();
/// ```
pub async fn iniciar_loop_reconcile(
    pg: PgPool,
    mut stop_rx: tokio::sync::oneshot::Receiver<()>,
    intervalo: Duration,
) {
    let ctx_id_base = "system.b02.reconcile.rust-loop";
    tracing::info!(intervalo_seg = intervalo.as_secs(), "reconcile B02: loop iniciado");

    loop {
        tokio::select! {
            _ = &mut stop_rx => {
                tracing::info!("reconcile B02: señal de parada recibida");
                break;
            }
            _ = tokio::time::sleep(intervalo) => {
                let ctx_id = format!("{}.{}", ctx_id_base, Utc::now().timestamp());
                match ejecutar_ciclo_reconcile(&pg, &ctx_id).await {
                    Ok(r) => tracing::info!(
                        deprecados = r.deprecados,
                        errores = r.errores,
                        "reconcile B02: ciclo completado"
                    ),
                    Err(e) => tracing::error!(error = %e, "reconcile B02: ciclo fallido"),
                }
            }
        }
    }
}
