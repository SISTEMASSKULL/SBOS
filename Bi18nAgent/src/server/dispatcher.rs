/// server/dispatcher.rs — Dispatcher de todos los métodos JSON-RPC de bi18n.
/// Propósito: match único method→handler; separado de unix_socket.rs (DOC-SBOS-001 N3).
///   - Fase 1 (18): health, locale, validate(3), mask(2), format(3), enum, snapshot,
///     attr(4), admin.reload, admin.reload_translations.
///   - Fase 2 A.08.01 (6): translate.{has_message,message,message_with_args,batch,list_messages,attribute}.
///   - SBOS-049: ctx_id obligatorio — ausente o vacío → error -32602.
///   - Paridad C11: mismos handlers que gRPC (Vía 3) — transporte transparente.
///   - admin.reload_translations: NO exponer en ruta pública de Kong (solo socket Unix/CI).
/// Dependencias: serde_json, crate::server::handlers, crate::server::dispatcher_helpers
use serde_json::Value;
use crate::{
    error::Bi18nError,
    server::{context::ServerContext, handlers},
};
use super::dispatcher_helpers as helpers;

/// Valida ctx_id y despacha al handler correspondiente.
pub async fn ejecutar_metodo(
    method: &str,
    params: Value,
    ctx: &ServerContext,
) -> Result<Value, Bi18nError> {
    // SBOS-049: ctx_id obligatorio en toda operación.
    match params.get("ctx_id").and_then(|v| v.as_str()) {
        Some(id) if !id.is_empty() => {}
        _ => return Err(Bi18nError::CtxIdAusente),
    }

    match method {
        // ── Estado y locale ────────────────────────────────────────────────
        "bi18n.health.check" => {
            let r = handlers::health::verificar(ctx).await?;
            Ok(serde_json::json!({
                "status": r.status, "version": r.version,
                "paises_cargados": r.paises_cargados, "mensaje": r.mensaje,
            }))
        }

        "bi18n.locale.resolve" => {
            let tenant_id = params["tenant_id"].as_str().unwrap_or("");
            let branch_id = params["branch_id"].as_str().unwrap_or("");
            let user_id   = params["user_id"].as_str().unwrap_or("");
            let r = handlers::locale::resolver_locale(ctx, tenant_id, branch_id, user_id).await?;
            Ok(serde_json::json!({
                "locale": r.config.locale, "timezone": r.config.timezone,
                "currency": r.config.currency, "country": r.config.country, "fuente": r.fuente,
                "text_direction": handlers::locale::detectar_direccion_texto(&r.config.locale),
            }))
        }

        // ── Validación ─────────────────────────────────────────────────────
        "bi18n.validate.email" => {
            let valor = params["value"].as_str().unwrap_or("");
            let r = handlers::validate::validate_email(ctx, valor).await?;
            Ok(serde_json::json!({ "valid": r.valid, "normalized": r.normalized, "errores": r.errores }))
        }

        "bi18n.validate.phone" => {
            let valor     = params["value"].as_str().unwrap_or("");
            let pais_hint = params["country_hint"].as_str().unwrap_or("BO");
            let r = handlers::validate::validate_phone(ctx, valor, pais_hint).await?;
            Ok(serde_json::json!({ "valid": r.valid, "e164": r.e164, "errores": r.errores }))
        }

        "bi18n.validate.national_id" => {
            let valor = params["value"].as_str().unwrap_or("");
            let kind  = params["kind"].as_str().unwrap_or("CI");
            let pais  = params["country"].as_str().unwrap_or("BO");
            let tipo  = helpers::parsear_tipo_documento(kind);
            let r = handlers::validate::validate_national_id(ctx, tipo, valor, pais).await?;
            Ok(serde_json::json!({ "valid": r.valid, "normalized": r.normalized, "errores": r.errores }))
        }

        // ── Enmascaramiento ────────────────────────────────────────────────
        "bi18n.mask.value" => {
            let valor     = params["value"].as_str().unwrap_or("");
            let mask_str  = params["strategy"].as_str().unwrap_or("none");
            let pais      = params["country"].as_str().unwrap_or("BO");
            let tipo_hint = params["kind"].as_str();
            let estrategia = helpers::parsear_estrategia_mascara(mask_str);
            let r = handlers::mask::mask_value(ctx, valor, estrategia, pais, tipo_hint).await?;
            Ok(serde_json::json!({ "masked": r.masked }))
        }

        "bi18n.mask.pii" => {
            let texto       = params["text"].as_str().unwrap_or("");
            let mask_emails = params["mask_emails"].as_bool().unwrap_or(true);
            let mask_phones = params["mask_phones"].as_bool().unwrap_or(true);
            let r = handlers::mask::mask_pii(ctx, texto, mask_emails, mask_phones).await?;
            Ok(serde_json::json!({ "redacted": r.redacted, "campos_redactados": r.campos_redactados }))
        }

        // ── Formateo ───────────────────────────────────────────────────────
        "bi18n.format.date" => {
            let regional = helpers::regional_desde_params(&params, ctx).await?;
            let gran = match params["granularity"].as_str() {
                Some("solo_fecha") => handlers::format::GranularidadFecha::SoloFecha,
                Some("solo_hora")  => handlers::format::GranularidadFecha::SoloHora,
                Some("mes_anio")   => handlers::format::GranularidadFecha::MesAnio,
                Some("solo_anio")  => handlers::format::GranularidadFecha::SoloAnio,
                _                  => handlers::format::GranularidadFecha::FechaHora,
            };
            let ts = params["iso_datetime"].as_str();
            let r  = handlers::format::format_fecha_o_ahora(ctx, ts, gran, &regional).await?;
            Ok(serde_json::json!({ "display": r.display, "timezone": regional.timezone, "locale": regional.locale }))
        }

        "bi18n.format.number" => {
            let valor    = params["value"].as_str().unwrap_or("0");
            let decimals = params["decimales"].as_u64().unwrap_or(2) as u32;
            let regional = helpers::regional_desde_params(&params, ctx).await?;
            let r = handlers::format::format_number(ctx, valor, decimals, &regional).await?;
            Ok(serde_json::json!({ "display": r.display }))
        }

        "bi18n.format.money" => {
            let monto    = params["amount"].as_str().unwrap_or("0");
            let moneda   = params["currency_code"].as_str().unwrap_or("");
            let regional = helpers::regional_desde_params(&params, ctx).await?;
            let r = handlers::format::format_money(ctx, monto, moneda, &regional).await?;
            Ok(serde_json::json!({ "display": r.display, "symbol_local": r.symbol_local }))
        }

        // ── Enums y snapshot ──────────────────────────────────────────────
        "bi18n.enum.display" => {
            let enum_name = params["enum_name"].as_str().unwrap_or("");
            let value     = params["value"].as_str().unwrap_or("");
            let locale    = params["locale"].as_str().unwrap_or("es-BO");
            let r = handlers::enums::display(ctx, enum_name, value, locale).await?;
            Ok(serde_json::json!({ "label": r.label, "found": r.found, "fallback": r.fallback }))
        }

        "bi18n.regional.snapshot" => {
            let tenant_id = params["tenant_id"].as_str().unwrap_or("");
            let branch_id = params["branch_id"].as_str();
            let user_id   = params["user_id"].as_str();
            let r = handlers::snapshot::regional_snapshot(ctx, tenant_id, branch_id, user_id).await?;
            Ok(r.payload)
        }

        // ── Pipeline de atributos ──────────────────────────────────────────
        "bi18n.attr.pipeline" => {
            // Aliases del contrato A.04 §3 (agnóstico de plataforma):
            //   field_id       → key
            //   validator_profile → validate_format (y format_code si no viene explícito)
            let key = params["field_id"].as_str()
                .or_else(|| params["key"].as_str())
                .unwrap_or("");
            let valor = params["value"].as_str().unwrap_or("");
            let validator_profile = params["validator_profile"].as_str().unwrap_or("");
            let validate_format = params["validate_format"].as_str()
                .unwrap_or(validator_profile);
            let format_code = params["format_code"].as_str()
                .unwrap_or(validator_profile);
            let mask_str     = params["mask"].as_str().unwrap_or("none");
            let transforms   = helpers::parsear_transformaciones(&params["transforms"]);
            let regional     = helpers::regional_desde_params(&params, ctx).await?;
            let mascara      = helpers::parsear_estrategia_mascara(mask_str);
            let (mn, mp, ms) = helpers::extraer_params_mascara(&mascara);
            let r = handlers::attr::pipeline(
                ctx, key, valor, validate_format, &transforms,
                format_code, mascara, mn, mp, ms, &regional,
            ).await?;
            Ok(serde_json::json!({
                "raw": r.raw, "valid": r.valid, "transformed": r.transformed,
                "display": r.display, "masked": r.masked,
                "validation_errors": r.errores_validacion,
            }))
        }

        "bi18n.attr.build" => {
            let key        = params["key"].as_str().unwrap_or("");
            let valor      = params["value"].as_str().unwrap_or("");
            let format_code = params["format_code"].as_str().unwrap_or("");
            let mask_str   = params["mask"].as_str().unwrap_or("none");
            let regional   = helpers::regional_desde_params(&params, ctx).await?;
            let mascara    = helpers::parsear_estrategia_mascara(mask_str);
            let (mn, mp, ms) = helpers::extraer_params_mascara(&mascara);
            // Build = pipeline sin validación (validate_format vacío).
            let r = handlers::attr::pipeline(
                ctx, key, valor, "", &[], format_code, mascara, mn, mp, ms, &regional,
            ).await?;
            Ok(serde_json::json!({
                "raw": r.raw, "display": r.display, "masked": r.masked,
            }))
        }

        "bi18n.attr.config" => {
            let display_format = params["display_format"].as_str().unwrap_or("");
            let locale         = params["locale"].as_str().unwrap_or("es-BO");
            let r = handlers::attr::config(display_format, locale);
            Ok(serde_json::json!({
                "display_format":    r.display_format,
                "validator_profile": r.validator_profile,
                "mask_pattern":      r.mask_pattern,
                "input_mask":        r.input_mask,
                "masks_pii":         r.masks_pii,
            }))
        }

        "bi18n.attr.config_batch" => {
            // 9.3: resolver locale UNA SOLA VEZ antes de iterar campos.
            // Si llegan tenant_id/branch_id/user_id → resolver por jerarquía (§8 de 1.01).
            // Si llega locale explícito → usarlo directamente (sin resolver de nuevo).
            let (locale, country) = if params["tenant_id"].as_str().is_some() {
                let tenant_id = params["tenant_id"].as_str().unwrap_or("");
                let branch_id = params["branch_id"].as_str().unwrap_or("");
                let user_id   = params["user_id"].as_str().unwrap_or("");
                let r = handlers::locale::resolver_locale(ctx, tenant_id, branch_id, user_id).await?;
                tracing::debug!("config_batch: locale resuelto por tenant '{}' → {}", tenant_id, r.config.locale);
                (r.config.locale, r.config.country)
            } else {
                (
                    params["locale"].as_str().unwrap_or("es-BO").to_string(),
                    params["country"].as_str().unwrap_or("BO").to_string(),
                )
            };
            let text_direction = handlers::locale::detectar_direccion_texto(&locale);
            let campos = handlers::attr::config_batch_desde_json(&params["fields"], &locale, &country);
            Ok(serde_json::json!({ "campos": campos, "locale": locale, "country": country, "text_direction": text_direction }))
        }

        // ── ICU locale BCP-47 (A.08.04) ──────────────────────────────────
        "bi18n.locale.parse_bcp47" => {
            handlers::lib_icu_locale::locale_parse_bcp47(ctx, &params).await
        }
        "bi18n.locale.canonicalize" => {
            handlers::lib_icu_locale::locale_canonicalize(ctx, &params).await
        }
        "bi18n.locale.negotiate" => {
            handlers::lib_icu_locale::locale_negotiate(ctx, &params).await
        }
        "bi18n.locale.subtags" => {
            handlers::lib_icu_locale::locale_subtags(ctx, &params).await
        }

        // ── ICU datetime format (A.08.03) ────────────────────────────────
        "bi18n.format.datetime_icu" => {
            handlers::lib_icu_datetime::format_datetime_icu(ctx, &params).await
        }
        "bi18n.format.date_icu" => {
            handlers::lib_icu_datetime::format_date_icu(ctx, &params).await
        }
        "bi18n.format.time_icu" => {
            handlers::lib_icu_datetime::format_time_icu(ctx, &params).await
        }
        "bi18n.format.weekday_name" => {
            handlers::lib_icu_datetime::format_weekday_name(ctx, &params).await
        }
        "bi18n.format.month_name" => {
            handlers::lib_icu_datetime::format_month_name(ctx, &params).await
        }
        "bi18n.format.datetime_with_time" => {
            handlers::lib_icu_datetime::format_datetime_with_time(ctx, &params).await
        }

        // ── rust-i18n runtime (A.08.02) ──────────────────────────────────
        "bi18n.i18n.locale_activo" => {
            handlers::lib_rust_i18n::i18n_locale_activo(ctx, &params).await
        }
        "bi18n.i18n.set_locale" => {
            handlers::lib_rust_i18n::i18n_set_locale(ctx, &params).await
        }
        "bi18n.i18n.available_locales" => {
            handlers::lib_rust_i18n::i18n_available_locales(ctx, &params).await
        }
        "bi18n.i18n.translate" => {
            handlers::lib_rust_i18n::i18n_translate(ctx, &params).await
        }

        // ── Traducción Fluent (A.08.01) ───────────────────────────────────
        "bi18n.translate.has_message" => {
            handlers::lib_fluent::translate_has_message(ctx, &params).await
        }
        "bi18n.translate.message" => {
            handlers::lib_fluent::translate_message(ctx, &params).await
        }
        "bi18n.translate.message_with_args" => {
            handlers::lib_fluent::translate_message_with_args(ctx, &params).await
        }
        "bi18n.translate.batch" => {
            handlers::lib_fluent::translate_batch(ctx, &params).await
        }
        "bi18n.translate.list_messages" => {
            handlers::lib_fluent::translate_list_messages(ctx, &params).await
        }
        "bi18n.translate.attribute" => {
            handlers::lib_fluent::translate_attribute(ctx, &params).await
        }

        // ── Administración ────────────────────────────────────────────────
        "bi18n.admin.reload" => {
            let (n, ok_rules) = match ctx.loader.recargar().await {
                Ok(n)  => { tracing::info!("admin.reload: {} países recargados", n); (n, true) }
                Err(e) => { tracing::error!("admin.reload: country-rules falló: {}", e); (0, false) }
            };
            let ok_fluent = match ctx.fluent.recargar(&ctx.config.rutas.fluent_dir) {
                Ok(()) => { tracing::info!("admin.reload: Fluent recargado"); true }
                Err(e) => { tracing::warn!("admin.reload: Fluent falló: {}", e); false }
            };
            Ok(serde_json::json!({
                "recargado": ok_rules || ok_fluent,
                "paises_cargados": n,
                "country_rules": if ok_rules { "ok" } else { "error" },
                "fluent": if ok_fluent { "ok" } else { "error" },
            }))
        }

        // Solo traducciones FTL (sin recargar country-rules).
        // NOTA: no exponer en ruta pública de Kong — solo CI/deploy via socket Unix.
        "bi18n.admin.reload_translations" => {
            let dir = &ctx.config.rutas.fluent_dir;
            let ok = match ctx.fluent.recargar(dir) {
                Ok(()) => {
                    tracing::info!("reload_translations: swap atómico completado ({})", ctx.config.regional.locale);
                    true
                }
                Err(e) => {
                    tracing::error!("reload_translations: error — versión anterior activa: {}", e);
                    false
                }
            };
            Ok(serde_json::json!({
                "recargado": ok,
                "locale": ctx.config.regional.locale,
                "mensaje": if ok {
                    "traducciones recargadas sin interrupción de servicio"
                } else {
                    "error en recarga — versión anterior activa (rollback implícito)"
                },
            }))
        }

        metodo => Err(Bi18nError::MetodoNoEncontrado { metodo: metodo.to_string() }),
    }
}
