/// server/grpc_attr.rs — AttrService + EnumService + helpers de conversión proto→dominio.
/// Propósito: pipeline de atributos, enums localizados y funciones de conversión.
///   - Las funciones `proto_*` son pub(crate) para ser usadas por grpc.rs y grpc_validate.rs.
///   - Parte del split de grpc.rs (DOC-SBOS-001 N3: ≤200 líneas por módulo).
/// Dependencias: tonic, crate::generated, crate::server, crate::domain
use tonic::{Request, Response, Status};

use crate::{
    domain::regional_config::RegionalConfig as DomainRegionalConfig,
    generated::bi18n_v1::{
        attr_service_server::AttrService,
        enum_service_server::EnumService,
        *,
    },
    server::{context::ServerContext, handlers},
};

// ── AttrService ───────────────────────────────────────────────────────────────

#[tonic::async_trait]
impl AttrService for ServerContext {
    async fn pipeline(
        &self,
        req: Request<AttrPipelineRequest>,
    ) -> Result<Response<AttrPipelineResponse>, Status> {
        let inner = req.into_inner();
        let regional = resolver_regional(self, inner.ctx.as_ref()).await?;
        let transforms: Vec<_> = inner.transforms.iter().filter_map(|&t| proto_transform(t)).collect();
        let mascara = proto_estrategia(inner.mask_strategy, inner.mask_n, inner.mask_prefix_visible, inner.mask_suffix_visible);
        let r = handlers::attr::pipeline(
            self, &inner.key, &inner.value, &inner.validate_format, &transforms,
            &inner.format_code, mascara, inner.mask_n, inner.mask_prefix_visible, inner.mask_suffix_visible, &regional,
        ).await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(AttrPipelineResponse {
            raw: r.raw, valid: r.valid, transformed: r.transformed,
            display: r.display, masked: r.masked, enum_label: r.enum_label,
            errores_validacion: r.errores_validacion,
        }))
    }

    async fn build(
        &self,
        req: Request<AttrBuildRequest>,
    ) -> Result<Response<AttrBuildResponse>, Status> {
        let inner = req.into_inner();
        let regional = resolver_regional(self, inner.ctx.as_ref()).await?;
        let transforms: Vec<_> = inner.transforms.iter().filter_map(|&t| proto_transform(t)).collect();
        let mascara = proto_estrategia(inner.mask_strategy, inner.mask_n, inner.mask_prefix_visible, inner.mask_suffix_visible);
        let vf = if inner.ejecutar_validate { inner.validate_format.as_str() } else { "" };
        let fc = if inner.ejecutar_format { inner.format_code.as_str() } else { "" };
        let t  = if inner.ejecutar_transforms { &transforms[..] } else { &[] };
        let m  = if inner.ejecutar_mask { mascara } else { handlers::mask::EstrategiaMascara::Ninguna };
        let r = handlers::attr::pipeline(
            self, &inner.key, &inner.value, vf, t, fc,
            m, inner.mask_n, inner.mask_prefix_visible, inner.mask_suffix_visible, &regional,
        ).await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(AttrBuildResponse {
            result: Some(AttrPipelineResponse {
                raw: r.raw, valid: r.valid, transformed: r.transformed,
                display: r.display, masked: r.masked, enum_label: r.enum_label,
                errores_validacion: r.errores_validacion,
            }),
        }))
    }
}

// ── EnumService ───────────────────────────────────────────────────────────────

#[tonic::async_trait]
impl EnumService for ServerContext {
    async fn display(
        &self,
        req: Request<EnumDisplayRequest>,
    ) -> Result<Response<EnumDisplayResponse>, Status> {
        let inner = req.into_inner();
        let regional = resolver_regional(self, inner.ctx.as_ref()).await?;
        let r = handlers::enums::display(self, &inner.enum_name, &inner.value, &regional.locale)
            .await.map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(EnumDisplayResponse { label: r.label, found: r.found, fallback: r.fallback }))
    }
}

// ── Helpers pub(crate) de conversión proto → dominio ─────────────────────────

/// Resuelve RegionalConfig desde el OperationContext del request o el resolver estático.
pub(crate) async fn resolver_regional(
    ctx: &ServerContext,
    op_ctx: Option<&OperationContext>,
) -> Result<DomainRegionalConfig, Status> {
    let (tenant_id, proto_rc) = match op_ctx {
        Some(c) => (c.tenant_id.as_str(), c.regional.clone()),
        None    => ("", None),
    };
    let request_rc = proto_rc.map(|r| DomainRegionalConfig {
        locale: r.locale, timezone: r.timezone, currency: r.currency, country: r.country,
    });
    crate::domain::regional_config::resolver_desde_request(request_rc, ctx.resolver.as_ref(), tenant_id)
        .await
        .map_err(|e| Status::internal(e.to_string()))
}

pub(crate) fn proto_granularidad(g: i32) -> handlers::format::GranularidadFecha {
    match g {
        1 => handlers::format::GranularidadFecha::FechaHora,
        2 => handlers::format::GranularidadFecha::SoloFecha,
        3 => handlers::format::GranularidadFecha::MesAnio,
        4 => handlers::format::GranularidadFecha::SoloAnio,
        5 => handlers::format::GranularidadFecha::SoloHora,
        _ => handlers::format::GranularidadFecha::SoloFecha,
    }
}

pub(crate) fn proto_tipo_doc(k: i32) -> handlers::validate::TipoDocumento {
    match k {
        2 => handlers::validate::TipoDocumento::Nit,
        3 => handlers::validate::TipoDocumento::Cpf,
        4 => handlers::validate::TipoDocumento::Cnpj,
        5 => handlers::validate::TipoDocumento::Dni,
        6 => handlers::validate::TipoDocumento::Cuit,
        7 => handlers::validate::TipoDocumento::Passport,
        _ => handlers::validate::TipoDocumento::Ci,
    }
}

pub(crate) fn proto_estrategia(s: i32, n: u32, p: u32, sf: u32) -> handlers::mask::EstrategiaMascara {
    match s {
        1 => handlers::mask::EstrategiaMascara::Completa,
        2 => handlers::mask::EstrategiaMascara::Parcial { n },
        3 => handlers::mask::EstrategiaMascara::Prefijo { n },
        4 => handlers::mask::EstrategiaMascara::Ambos { prefix_visible: p, suffix_visible: sf },
        5 => handlers::mask::EstrategiaMascara::ReglaPais,
        _ => handlers::mask::EstrategiaMascara::Ninguna,
    }
}

pub(crate) fn proto_transform(t: i32) -> Option<handlers::attr::Transformacion> {
    match t {
        1  => Some(handlers::attr::Transformacion::Mayusculas),
        2  => Some(handlers::attr::Transformacion::Minusculas),
        3  => Some(handlers::attr::Transformacion::TituloCase),
        4  => Some(handlers::attr::Transformacion::Trim),
        5  => Some(handlers::attr::Transformacion::QuitarGuiones),
        6  => Some(handlers::attr::Transformacion::QuitarEspacios),
        7  => Some(handlers::attr::Transformacion::QuitarAcentos),
        8  => Some(handlers::attr::Transformacion::SoloDigitos),
        9  => Some(handlers::attr::Transformacion::SoloLetras),
        10 => Some(handlers::attr::Transformacion::RellenarIzquierda { largo: 10, caracter: '0' }),
        11 => Some(handlers::attr::Transformacion::RellenarDerecha { largo: 10, caracter: ' ' }),
        _  => None,
    }
}
