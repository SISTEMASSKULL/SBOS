/// server/grpc_validate.rs — ValidateService + MaskService + LocaleService (gRPC).
/// Propósito: implementaciones de los servicios de validación, máscara y locale.
///   - Todas delegan en server/handlers/*.rs (paridad con JSON-RPC).
///   - Parte del split de grpc.rs (DOC-SBOS-001 N3: ≤200 líneas por módulo).
/// Dependencias: tonic, crate::generated, crate::server
use tonic::{Request, Response, Status};

use crate::{
    generated::bi18n_v1::{
        locale_service_server::LocaleService,
        mask_service_server::MaskService,
        validate_service_server::ValidateService,
        *,
    },
    server::{context::ServerContext, grpc_attr, handlers},
};

// ── ValidateService ───────────────────────────────────────────────────────────

#[tonic::async_trait]
impl ValidateService for ServerContext {
    async fn validate_national_id(
        &self,
        req: Request<ValidateNationalIdRequest>,
    ) -> Result<Response<ValidateNationalIdResponse>, Status> {
        let inner = req.into_inner();
        let regional = grpc_attr::resolver_regional(self, inner.ctx.as_ref()).await?;
        let tipo = grpc_attr::proto_tipo_doc(inner.kind);
        let r = handlers::validate::validate_national_id(self, tipo, &inner.value, &regional.country)
            .await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(ValidateNationalIdResponse {
            valid: r.valid, normalized: r.normalized, errores: r.errores,
        }))
    }

    async fn validate_phone(
        &self,
        req: Request<ValidatePhoneRequest>,
    ) -> Result<Response<ValidatePhoneResponse>, Status> {
        let inner = req.into_inner();
        let regional = grpc_attr::resolver_regional(self, inner.ctx.as_ref()).await?;
        let hint = if inner.country_hint.is_empty() { regional.country.clone() } else { inner.country_hint.clone() };
        let r = handlers::validate::validate_phone(self, &inner.value, &hint)
            .await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(ValidatePhoneResponse { valid: r.valid, e164: r.e164, errores: r.errores }))
    }

    async fn validate_email(
        &self,
        req: Request<ValidateEmailRequest>,
    ) -> Result<Response<ValidateEmailResponse>, Status> {
        let inner = req.into_inner();
        let r = handlers::validate::validate_email(self, &inner.value)
            .await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(ValidateEmailResponse { valid: r.valid, normalized: r.normalized, errores: r.errores }))
    }
}

// ── MaskService ───────────────────────────────────────────────────────────────

#[tonic::async_trait]
impl MaskService for ServerContext {
    async fn mask_value(
        &self,
        req: Request<MaskValueRequest>,
    ) -> Result<Response<MaskValueResponse>, Status> {
        let inner = req.into_inner();
        let regional = grpc_attr::resolver_regional(self, inner.ctx.as_ref()).await?;
        let estrategia = grpc_attr::proto_estrategia(inner.strategy, inner.n, inner.prefix_visible, inner.suffix_visible);
        let r = handlers::mask::mask_value(self, &inner.value, estrategia, &regional.country, None)
            .await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(MaskValueResponse { masked: r.masked }))
    }

    async fn mask_pii(
        &self,
        req: Request<MaskPiiRequest>,
    ) -> Result<Response<MaskPiiResponse>, Status> {
        let inner = req.into_inner();
        let r = handlers::mask::mask_pii(self, &inner.text, inner.mask_emails, inner.mask_phones)
            .await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(MaskPiiResponse { redacted: r.redacted, campos_redactados: r.campos_redactados }))
    }
}

// ── LocaleService ─────────────────────────────────────────────────────────────

#[tonic::async_trait]
impl LocaleService for ServerContext {
    async fn resolve_locale(
        &self,
        req: Request<ResolveLocaleRequest>,
    ) -> Result<Response<ResolveLocaleResponse>, Status> {
        let inner = req.into_inner();
        let r = handlers::locale::resolver_locale(self, &inner.tenant_id, &inner.branch_id, &inner.user_id)
            .await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(ResolveLocaleResponse {
            config: Some(RegionalConfig {
                locale: r.config.locale,
                timezone: r.config.timezone,
                currency: r.config.currency,
                country: r.config.country,
            }),
            fuente: r.fuente.to_string(),
        }))
    }
}
