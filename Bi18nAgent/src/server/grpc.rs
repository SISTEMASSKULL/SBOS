/// server/grpc.rs — Servidor gRPC de bi18n + HealthService + FormatService.
/// Propósito: arranca el servidor gRPC sobre Unix socket (Interface Triple C11 — Vía 3).
///   - grpc_validate.rs: ValidateService + MaskService + LocaleService
///   - grpc_attr.rs:     AttrService + EnumService + helpers de conversión proto
/// Dependencias: tonic, tokio-stream (UnixListenerStream), crate::generated
use std::path::PathBuf;
use tokio::net::UnixListener;
use tokio_stream::wrappers::UnixListenerStream;
use tonic::{transport::Server, Request, Response, Status};

use crate::{
    error::Bi18nError,
    generated::bi18n_v1::{
        attr_service_server::AttrServiceServer,
        enum_service_server::EnumServiceServer,
        format_service_server::{FormatService, FormatServiceServer},
        health_service_server::{HealthService, HealthServiceServer},
        locale_service_server::LocaleServiceServer,
        mask_service_server::MaskServiceServer,
        validate_service_server::ValidateServiceServer,
        *,
    },
    server::{context::ServerContext, handlers},
};

/// Inicia el servidor gRPC y lo mantiene activo hasta que `shutdown` señalice.
pub async fn iniciar_grpc(
    socket_path: PathBuf,
    ctx: ServerContext,
    mut shutdown: tokio::sync::watch::Receiver<bool>,
) -> Result<(), Bi18nError> {
    let _ = tokio::fs::remove_file(&socket_path).await;

    let listener = UnixListener::bind(&socket_path)
        .map_err(|e| Bi18nError::SocketBind { path: socket_path.clone(), causa: e.to_string() })?;

    use std::os::unix::fs::PermissionsExt;
    tokio::fs::set_permissions(
        &socket_path,
        std::fs::Permissions::from_mode(0o660),
    ).await.map_err(|e| Bi18nError::SocketPermisos { path: socket_path.clone(), causa: e.to_string() })?;

    tracing::info!("gRPC escuchando en {:?} (Interface Triple C11 — sin TCP)", socket_path);

    Server::builder()
        .add_service(HealthServiceServer::new(ctx.clone()))
        .add_service(FormatServiceServer::new(ctx.clone()))
        .add_service(ValidateServiceServer::new(ctx.clone()))
        .add_service(MaskServiceServer::new(ctx.clone()))
        .add_service(LocaleServiceServer::new(ctx.clone()))
        .add_service(AttrServiceServer::new(ctx.clone()))
        .add_service(EnumServiceServer::new(ctx))
        .serve_with_incoming_shutdown(
            UnixListenerStream::new(listener),
            async move { let _ = shutdown.changed().await; },
        )
        .await
        .map_err(|e| Bi18nError::GrpcServer { causa: e.to_string() })
}

// ── HealthService ─────────────────────────────────────────────────────────────

#[tonic::async_trait]
impl HealthService for ServerContext {
    async fn check(
        &self,
        req: Request<HealthCheckRequest>,
    ) -> Result<Response<HealthCheckResponse>, Status> {
        let _ctx_id = req.into_inner().ctx_id;
        let r = handlers::health::verificar(self).await
            .map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(HealthCheckResponse {
            status: r.status.to_string(),
            version: r.version.to_string(),
            paises_cargados: r.paises_cargados,
            mensaje: r.mensaje,
        }))
    }
}

// ── FormatService ─────────────────────────────────────────────────────────────

#[tonic::async_trait]
impl FormatService for ServerContext {
    async fn format_date(&self, req: Request<FormatDateRequest>) -> Result<Response<FormatDateResponse>, Status> {
        let inner = req.into_inner();
        let regional = crate::server::grpc_attr::resolver_regional(self, inner.ctx.as_ref()).await?;
        let granularidad = crate::server::grpc_attr::proto_granularidad(inner.granularity);
        let r = handlers::format::format_date(self, &inner.iso_datetime, granularidad, &regional)
            .await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(FormatDateResponse { display: r.display }))
    }

    async fn format_number(&self, req: Request<FormatNumberRequest>) -> Result<Response<FormatNumberResponse>, Status> {
        let inner = req.into_inner();
        let regional = crate::server::grpc_attr::resolver_regional(self, inner.ctx.as_ref()).await?;
        let r = handlers::format::format_number(self, &inner.value, inner.decimal_places, &regional)
            .await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(FormatNumberResponse { display: r.display }))
    }

    async fn format_money(&self, req: Request<FormatMoneyRequest>) -> Result<Response<FormatMoneyResponse>, Status> {
        let inner = req.into_inner();
        let regional = crate::server::grpc_attr::resolver_regional(self, inner.ctx.as_ref()).await?;
        let r = handlers::format::format_money(self, &inner.amount, &inner.currency_code, &regional)
            .await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(FormatMoneyResponse { display: r.display, symbol_local: r.symbol_local }))
    }

    async fn format_address(&self, _req: Request<FormatAddressRequest>) -> Result<Response<FormatAddressResponse>, Status> {
        Err(Status::unimplemented("FormatAddress disponible en Fase Post-MVP"))
    }
}
