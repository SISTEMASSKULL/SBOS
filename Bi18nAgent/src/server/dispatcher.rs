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

        // ── ICU decimal format (A.08.05) ─────────────────────────────────
        "bi18n.format.number_icu" => {
            handlers::lib_icu_decimal::format_number_icu(ctx, &params).await
        }
        "bi18n.format.number_no_grouping" => {
            handlers::lib_icu_decimal::format_number_no_grouping(ctx, &params).await
        }
        "bi18n.format.number_grouping_always" => {
            handlers::lib_icu_decimal::format_number_grouping_always(ctx, &params).await
        }
        "bi18n.format.number_grouping_min2" => {
            handlers::lib_icu_decimal::format_number_grouping_min2(ctx, &params).await
        }

        // ── Validación de tipos y formatos (A.08.06) ──────────────────────
        "bi18n.validate.email_html5" => {
            handlers::lib_validator::validate_email_html5(ctx, &params).await
        }
        "bi18n.validate.url" => {
            handlers::lib_validator::validate_url(ctx, &params).await
        }
        "bi18n.validate.ip" => {
            handlers::lib_validator::validate_ip(ctx, &params).await
        }
        "bi18n.validate.ipv4" => {
            handlers::lib_validator::validate_ipv4(ctx, &params).await
        }
        "bi18n.validate.ipv6" => {
            handlers::lib_validator::validate_ipv6(ctx, &params).await
        }
        "bi18n.validate.length" => {
            handlers::lib_validator::validate_length(ctx, &params).await
        }
        "bi18n.validate.range" => {
            handlers::lib_validator::validate_range(ctx, &params).await
        }
        "bi18n.validate.contains" => {
            handlers::lib_validator::validate_contains(ctx, &params).await
        }
        "bi18n.validate.not_contains" => {
            handlers::lib_validator::validate_not_contains(ctx, &params).await
        }
        "bi18n.validate.required" => {
            handlers::lib_validator::validate_required(ctx, &params).await
        }
        "bi18n.validate.credit_card" => {
            handlers::lib_validator::validate_credit_card(ctx, &params).await
        }
        "bi18n.validate.must_match" => {
            handlers::lib_validator::validate_must_match_fields(ctx, &params).await
        }

        // ── Formateo RFC3339/RFC2822/strftime chrono (A.08.11) ───────────
        "bi18n.datetime.chrono_parse_rfc3339" => {
            handlers::lib_chrono::chrono_parse_rfc3339(ctx, &params).await
        }
        "bi18n.datetime.chrono_parse_rfc2822" => {
            handlers::lib_chrono::chrono_parse_rfc2822(ctx, &params).await
        }
        "bi18n.datetime.chrono_to_rfc3339" => {
            handlers::lib_chrono::chrono_to_rfc3339(ctx, &params).await
        }
        "bi18n.datetime.chrono_to_rfc2822" => {
            handlers::lib_chrono::chrono_to_rfc2822(ctx, &params).await
        }
        "bi18n.datetime.chrono_format" => {
            handlers::lib_chrono::chrono_format(ctx, &params).await
        }
        "bi18n.datetime.chrono_format_localized" => {
            handlers::lib_chrono::chrono_format_localized(ctx, &params).await
        }
        "bi18n.datetime.chrono_to_unix" => {
            handlers::lib_chrono::chrono_to_unix(ctx, &params).await
        }
        "bi18n.datetime.chrono_leap_year" => {
            handlers::lib_chrono::chrono_leap_year(ctx, &params).await
        }
        "bi18n.datetime.chrono_naive_parse" => {
            handlers::lib_chrono::chrono_naive_parse(ctx, &params).await
        }
        "bi18n.datetime.chrono_timedelta_total" => {
            handlers::lib_chrono::chrono_timedelta_total(ctx, &params).await
        }

        // ── Guardas / Precondiciones prism3-core (A.08.14) ───────────────
        "bi18n.guard.check_bounds" => {
            handlers::lib_prism3::guard_check_bounds(ctx, &params).await
        }
        "bi18n.guard.check_element_index" => {
            handlers::lib_prism3::guard_check_element_index(ctx, &params).await
        }
        "bi18n.guard.check_position_index" => {
            handlers::lib_prism3::guard_check_position_index(ctx, &params).await
        }
        "bi18n.guard.num_compare" => {
            handlers::lib_prism3::guard_num_compare(ctx, &params).await
        }
        "bi18n.guard.num_positive" => {
            handlers::lib_prism3::guard_num_positive(ctx, &params).await
        }
        "bi18n.guard.num_non_negative" => {
            handlers::lib_prism3::guard_num_non_negative(ctx, &params).await
        }
        "bi18n.guard.num_in_range" => {
            handlers::lib_prism3::guard_num_in_range(ctx, &params).await
        }
        "bi18n.guard.str_non_blank" => {
            handlers::lib_prism3::guard_str_non_blank(ctx, &params).await
        }
        "bi18n.guard.str_length_range" => {
            handlers::lib_prism3::guard_str_length_range(ctx, &params).await
        }
        "bi18n.guard.str_match" => {
            handlers::lib_prism3::guard_str_match(ctx, &params).await
        }
        "bi18n.guard.col_non_empty" => {
            handlers::lib_prism3::guard_col_non_empty(ctx, &params).await
        }
        "bi18n.guard.col_length_range" => {
            handlers::lib_prism3::guard_col_length_range(ctx, &params).await
        }

        // ── Teléfonos internacionales (A.08.13) ──────────────────────────
        "bi18n.phone.parse_e164" => {
            handlers::lib_phonenumber::phone_parse_e164(ctx, &params).await
        }
        "bi18n.phone.format" => {
            handlers::lib_phonenumber::phone_format(ctx, &params).await
        }
        "bi18n.phone.type" => {
            handlers::lib_phonenumber::phone_type(ctx, &params).await
        }
        "bi18n.phone.is_viable" => {
            handlers::lib_phonenumber::phone_is_viable(ctx, &params).await
        }
        "bi18n.phone.info" => {
            handlers::lib_phonenumber::phone_info(ctx, &params).await
        }
        "bi18n.phone.parse_national" => {
            handlers::lib_phonenumber::phone_parse_national(ctx, &params).await
        }
        "bi18n.phone.parse_rfc3966" => {
            handlers::lib_phonenumber::phone_parse_rfc3966(ctx, &params).await
        }
        "bi18n.phone.country_code" => {
            handlers::lib_phonenumber::phone_country_code(ctx, &params).await
        }

        // ── Expresiones regulares sobre texto libre (A.08.12) ────────────
        "bi18n.text.regex_match" => {
            handlers::lib_regex::regex_match(ctx, &params).await
        }
        "bi18n.text.regex_extract" => {
            handlers::lib_regex::regex_extract(ctx, &params).await
        }
        "bi18n.text.regex_extract_all" => {
            handlers::lib_regex::regex_extract_all(ctx, &params).await
        }
        "bi18n.text.regex_replace" => {
            handlers::lib_regex::regex_replace(ctx, &params).await
        }
        "bi18n.text.regex_split" => {
            handlers::lib_regex::regex_split(ctx, &params).await
        }
        "bi18n.text.regex_match_set" => {
            handlers::lib_regex::regex_match_set(ctx, &params).await
        }

        // ── Operaciones temporales jiff (A.08.10) ────────────────────────
        "bi18n.datetime.now_utc" => {
            handlers::lib_jiff::now_utc(ctx, &params).await
        }
        "bi18n.datetime.now_tz" => {
            handlers::lib_jiff::now_tz(ctx, &params).await
        }
        "bi18n.datetime.parse_jiff" => {
            handlers::lib_jiff::parse_jiff(ctx, &params).await
        }
        "bi18n.datetime.from_unix" => {
            handlers::lib_jiff::from_unix(ctx, &params).await
        }
        "bi18n.datetime.format_jiff" => {
            handlers::lib_jiff::format_jiff(ctx, &params).await
        }
        "bi18n.datetime.series" => {
            handlers::lib_jiff::series(ctx, &params).await
        }
        "bi18n.datetime.add_span" => {
            handlers::lib_jiff::add_span(ctx, &params).await
        }
        "bi18n.datetime.sub_span" => {
            handlers::lib_jiff::sub_span(ctx, &params).await
        }
        "bi18n.datetime.diff_span" => {
            handlers::lib_jiff::diff_span(ctx, &params).await
        }
        "bi18n.datetime.convert_tz" => {
            handlers::lib_jiff::convert_tz(ctx, &params).await
        }
        "bi18n.datetime.round" => {
            handlers::lib_jiff::round(ctx, &params).await
        }
        "bi18n.datetime.weekday_of_date" => {
            handlers::lib_jiff::weekday_of_date(ctx, &params).await
        }
        "bi18n.datetime.days_in_month" => {
            handlers::lib_jiff::days_in_month(ctx, &params).await
        }
        "bi18n.datetime.is_leap_year" => {
            handlers::lib_jiff::is_leap_year(ctx, &params).await
        }
        "bi18n.datetime.nth_weekday" => {
            handlers::lib_jiff::nth_weekday(ctx, &params).await
        }
        "bi18n.datetime.span_total" => {
            handlers::lib_jiff::span_total(ctx, &params).await
        }
        "bi18n.datetime.tz_info" => {
            handlers::lib_jiff::tz_info(ctx, &params).await
        }

        // ── Máscaras estructurales posicionales (A.08.09) ────────────────
        "bi18n.format.structural_mask" => {
            handlers::lib_universal_mask::format_structural_mask(ctx, &params).await
        }
        "bi18n.format.mask_cnpj" => {
            handlers::lib_universal_mask::format_mask_cnpj(ctx, &params).await
        }
        "bi18n.format.mask_cpf" => {
            handlers::lib_universal_mask::format_mask_cpf(ctx, &params).await
        }
        "bi18n.format.mask_card" => {
            handlers::lib_universal_mask::format_mask_card(ctx, &params).await
        }
        "bi18n.format.mask_ci_bo" => {
            handlers::lib_universal_mask::format_mask_ci_bo(ctx, &params).await
        }

        // ── Enmascaramiento PII en texto libre (A.08.08) ─────────────────
        "bi18n.mask.email_in_text" => {
            handlers::lib_mask_pii::mask_email_in_text(ctx, &params).await
        }
        "bi18n.mask.phone_in_text" => {
            handlers::lib_mask_pii::mask_phone_in_text(ctx, &params).await
        }
        "bi18n.mask.pii_with_char" => {
            handlers::lib_mask_pii::mask_pii_with_char(ctx, &params).await
        }

        // ── Validación de formatos especiales (A.08.07) ───────────────────
        "bi18n.validate.uuid" => {
            handlers::lib_scrutiny::validate_uuid(ctx, &params).await
        }
        "bi18n.validate.ulid" => {
            handlers::lib_scrutiny::validate_ulid(ctx, &params).await
        }
        "bi18n.validate.mac_address" => {
            handlers::lib_scrutiny::validate_mac_address(ctx, &params).await
        }
        "bi18n.validate.hex_color" => {
            handlers::lib_scrutiny::validate_hex_color(ctx, &params).await
        }
        "bi18n.validate.timezone" => {
            handlers::lib_scrutiny::validate_timezone(ctx, &params).await
        }
        "bi18n.validate.is_json" => {
            handlers::lib_scrutiny::validate_is_json(ctx, &params).await
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
        // A.09 §7.2: nombre canónico locales_disponibles (alias backward-compat: available_locales)
        "bi18n.i18n.locales_disponibles" | "bi18n.i18n.available_locales" => {
            handlers::lib_rust_i18n::i18n_available_locales(ctx, &params).await
        }
        // A.09 §7.2: nombre canónico t (alias backward-compat: translate)
        "bi18n.i18n.t" | "bi18n.i18n.translate" => {
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
        // A.09 §7.1: nombre canónico message_attribute (alias backward-compat: attribute)
        "bi18n.translate.message_attribute" | "bi18n.translate.attribute" => {
            handlers::lib_fluent::translate_attribute(ctx, &params).await
        }
        // Descarga el bundle completo de un namespace (Bundle Prefetch — A.09 §12).
        "bi18n.translate.bundle" => {
            handlers::lib_fluent::translate_bundle(ctx, &params).await
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
            if ok_fluent {
                ctx.emitir_traducciones_actualizadas("*", &ctx.config.regional.locale);
            }
            Ok(serde_json::json!({
                "recargado": ok_rules || ok_fluent,
                "paises_cargados": n,
                "country_rules": if ok_rules { "ok" } else { "error" },
                "fluent": if ok_fluent { "ok" } else { "error" },
            }))
        }

        // Edición de traducciones FTL en runtime (P4 — bi18n.admin.*).
        // NOTA: no exponer en ruta pública de Kong — solo acceso autenticado via bi18nctl.
        "bi18n.admin.list_locales" => {
            handlers::lib_admin_traducciones::admin_list_locales(ctx, &params).await
        }
        "bi18n.admin.list_messages" => {
            handlers::lib_admin_traducciones::admin_list_messages(ctx, &params).await
        }
        "bi18n.admin.get_message" => {
            handlers::lib_admin_traducciones::admin_get_message(ctx, &params).await
        }
        "bi18n.admin.update_message" => {
            handlers::lib_admin_traducciones::admin_update_message(ctx, &params).await
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
            if ok {
                ctx.emitir_traducciones_actualizadas("*", &ctx.config.regional.locale);
            }
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

        // ── SDK de vínculo de campos UI (A.19 v2.0.0) ───────────────────────
        // Acepta: "tipo" como string DSL (compat) o JSON config { base, pais, moneda, ... }
        "bi18n.validate.field" => {
            let tipo_cfg = &params["tipo"];
            let dsl      = sdk_config_a_dsl(tipo_cfg);
            let valor    = params["value"].as_str().unwrap_or("");
            // requerido: del JSON config o del param top-level
            let required = tipo_cfg["requerido"].as_bool()
                .or_else(|| params["required"].as_bool())
                .unwrap_or(false);

            let mut r = handlers::sdk::validate_field(ctx, &dsl, valor, required).await?;

            // Validaciones cruzadas — el SDK resolvió los selectores y envió los valores
            if r.valido {
                let msg_error = tipo_cfg["msgError"].as_str()
                    .unwrap_or("Los valores no coinciden");

                // confirmar: el valor debe coincidir con el campo de referencia
                if let Some(cv) = params["confirmar_valor"].as_str() {
                    if valor.trim() != cv.trim() {
                        r = handlers::sdk::ValidateFieldResult {
                            valido: false,
                            errores: vec![msg_error.to_string()],
                            valor_normalizado: String::new(),
                            metadata: serde_json::json!({}),
                        };
                    }
                }
                // distinto: el valor NO debe coincidir con el campo de referencia
                if r.valido {
                    if let Some(dv) = params["distinto_valor"].as_str() {
                        if valor.trim() == dv.trim() {
                            r = handlers::sdk::ValidateFieldResult {
                                valido: false,
                                errores: vec![msg_error.to_string()],
                                valor_normalizado: String::new(),
                                metadata: serde_json::json!({}),
                            };
                        }
                    }
                }
            }

            Ok(serde_json::json!({
                "valido": r.valido,
                "errores": r.errores,
                "valor_normalizado": r.valor_normalizado,
                "metadata": r.metadata,
            }))
        }

        // bi18n.format.value — sin cambios
        "bi18n.format.value" => {
            let formato  = params["formato"].as_str().unwrap_or("text");
            let valor    = params["value"].as_str().unwrap_or("");
            let regional = helpers::regional_desde_params(&params, ctx).await?;
            let r = handlers::sdk::format_value(ctx, formato, valor, &regional).await?;
            Ok(serde_json::json!({ "formateado": r.formateado }))
        }

        // bi18n.mask.pattern — extrae tipo.base del JSON config v2.0.0
        "bi18n.mask.pattern" => {
            let tipo_cfg  = &params["tipo"];
            let tipo_base = sdk_mask_dsl(tipo_cfg);
            let r = handlers::sdk::mask_pattern(&tipo_base);
            Ok(serde_json::json!({
                "motor":        r.motor,
                "patron":       r.patron,
                "opciones":     r.opciones,
                "placeholder":  r.placeholder,
                "usar_mascara": r.usar_mascara,
            }))
        }

        metodo => Err(Bi18nError::MetodoNoEncontrado { metodo: metodo.to_string() }),
    }
}

// ── Helpers de JSON config → DSL (A.19 v2.0.0) ───────────────────────────────

/// Convierte JSON config { base, pais, moneda, ... } al DSL interno de validate_field.
/// También acepta string legacy "CI:BO" sin cambios.
fn sdk_config_a_dsl(v: &Value) -> String {
    if let Some(s) = v.as_str() {
        return s.to_string();
    }
    let base    = v["base"].as_str().unwrap_or("text");
    let pais    = v["pais"].as_str().unwrap_or("");
    let moneda  = v["moneda"].as_str().unwrap_or("");
    let subtipo = v["subtipo"].as_str().unwrap_or("integer");
    let dec     = v["decimales"].as_u64().unwrap_or(0);
    let min_n   = v["min"].as_f64().map(|n| n.to_string()).unwrap_or_default();
    let max_n   = v["max"].as_f64().map(|n| n.to_string()).unwrap_or_default();
    let min_f   = v["min_fecha"].as_str().map(sdk_resolver_fecha).unwrap_or_default();
    let max_f   = v["max_fecha"].as_str().map(sdk_resolver_fecha).unwrap_or_default();
    let min_ch  = v["min_chars"].as_u64().map(|n| n.to_string()).unwrap_or_default();
    let max_ch  = v["max_chars"].as_u64().map(|n| n.to_string()).unwrap_or_default();

    match base {
        "CI" | "NIT" | "DNI" | "PASSPORT" | "CPF" | "CNPJ" | "CUIT" =>
            format!("{}:{}", base, if pais.is_empty() { "BO" } else { pais }),
        "phone" =>
            format!("phone:{}", if pais.is_empty() { "BO" } else { pais }),
        "email"    => "email".to_string(),
        "password" => "password".to_string(),
        "bool"     => "bool".to_string(),
        "date"     => format!("date:{}:{}", min_f, max_f),
        "money"    => format!("money:{}:{}:{}", moneda, min_n, max_n),
        "number"   => format!("number:{}:{}:{}:{}", subtipo, dec, min_n, max_n),
        "text"     => format!("text:{}:{}", min_ch, max_ch),
        other      => other.to_string(),
    }
}

/// Extrae el DSL simplificado para mask.pattern (solo base:pais/moneda).
fn sdk_mask_dsl(v: &Value) -> String {
    if let Some(s) = v.as_str() { return s.to_string(); }
    let base   = v["base"].as_str().unwrap_or("text");
    let pais   = v["pais"].as_str().unwrap_or("");
    let moneda = v["moneda"].as_str().unwrap_or("");
    match base {
        "CI" | "NIT" | "phone" if !pais.is_empty() => format!("{}:{}", base, pais),
        "money" if !moneda.is_empty()               => format!("money:{}", moneda),
        "date"                                      => "date".to_string(),
        other                                       => other.to_string(),
    }
}

/// Resuelve expresiones de fecha relativa a ISO YYYY-MM-DD usando jiff.
/// Expresiones: "hoy", "hoy-Na" (N años), "hoy-Nd" (N días), "hoy+Nd".
/// Si la expresión no se reconoce, la retorna tal cual (puede ser ISO literal).
fn sdk_resolver_fecha(expr: &str) -> String {
    use jiff::{Timestamp, tz::TimeZone, Span};

    let hoy = Timestamp::now()
        .to_zoned(TimeZone::UTC)
        .date();

    if expr == "hoy" {
        return format!("{}", hoy);
    }

    let (signo, rest) = if let Some(r) = expr.strip_prefix("hoy-") {
        (-1i32, r)
    } else if let Some(r) = expr.strip_prefix("hoy+") {
        (1i32, r)
    } else {
        return expr.to_string(); // ISO literal u otra expresión
    };

    if let Some(ns) = rest.strip_suffix('a') {
        if let Ok(n) = ns.parse::<i32>() {
            let anios = (signo * n) as i64;
            if let Ok(fecha) = hoy.checked_add(Span::new().years(anios)) {
                return format!("{}", fecha);
            }
        }
    }
    if let Some(ns) = rest.strip_suffix('d') {
        if let Ok(n) = ns.parse::<i32>() {
            let dias = (signo * n) as i64;
            if let Ok(fecha) = hoy.checked_add(Span::new().days(dias)) {
                return format!("{}", fecha);
            }
        }
    }

    expr.to_string()
}
