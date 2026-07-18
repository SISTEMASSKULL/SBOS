/// server/handlers/sdk.rs — Handlers de nivel SDK: ligadura de campos UI (A.19).
/// Propósito: implementa bi18n.validate.field, bi18n.format.value, bi18n.mask.pattern.
///   Cada método parsea el DSL tipo y delega al handler especializado ya existente.
///   Esta capa es el contrato entre el Bi18nSdk (TypeScript/Dart/Python) y el daemon.
/// Dependencias: handlers/validate, handlers/format, dispatcher_helpers, error
use crate::{
    domain::regional_config::RegionalConfig,
    error::{Bi18nError, Resultado},
    server::{
        context::ServerContext,
        dispatcher_helpers::parsear_tipo_documento,
        handlers::{format as fmt, validate},
    },
};
use serde_json::{json, Value};

// ── Tipos de resultado ────────────────────────────────────────────────────────

/// Respuesta unificada de validación de campo SDK.
pub struct ValidateFieldResult {
    pub valido: bool,
    pub errores: Vec<String>,
    pub valor_normalizado: String,
    pub metadata: Value,
}

/// Respuesta de formateo de valor SDK.
pub struct FormatValueResult {
    pub formateado: String,
}

/// Patrón de máscara de entrada para un tipo DSL.
pub struct MaskPatternResult {
    /// Tipo de motor IMask: "Pattern", "Number", "Date", "none"
    pub motor: &'static str,
    /// Patrón posicional (solo motor Pattern y Date)
    pub patron: Option<String>,
    /// Opciones adicionales del motor
    pub opciones: Value,
    /// Placeholder visual (solo motor Pattern)
    pub placeholder: Option<String>,
    /// false = no aplicar máscara de entrada (email, texto libre, password)
    pub usar_mascara: bool,
}

// ── Parseo del DSL tipo ───────────────────────────────────────────────────────

fn segs(tipo: &str) -> Vec<&str> {
    tipo.split(':').collect()
}

// ── bi18n.validate.field ──────────────────────────────────────────────────────

/// Valida un valor según el DSL tipo del campo.
/// Enruta al handler especializado correspondiente y devuelve respuesta unificada.
/// Parámetros:
///   ctx      — contexto del servidor (Fluent, loader de country-rules)
///   tipo     — DSL tipo, p.ej. "CI:BO", "email", "date:hoy-18a:hoy", "money:BOB:0:50000"
///   valor    — valor crudo del campo (string del frontend)
///   requerido — si true y valor vacío → error de campo requerido
pub async fn validate_field(
    ctx: &ServerContext,
    tipo: &str,
    valor: &str,
    requerido: bool,
) -> Resultado<ValidateFieldResult> {
    let s = segs(tipo);

    // Verificar campo requerido
    if requerido && valor.trim().is_empty() {
        let msg = ctx.fluent.traducir("campo-requerido", None);
        let msg = if msg == "campo-requerido" { "Este campo es requerido.".to_string() } else { msg };
        return Ok(ValidateFieldResult {
            valido: false,
            errores: vec![msg],
            valor_normalizado: String::new(),
            metadata: json!({}),
        });
    }
    if valor.trim().is_empty() {
        return Ok(ValidateFieldResult {
            valido: true,
            errores: vec![],
            valor_normalizado: String::new(),
            metadata: json!({}),
        });
    }

    match s[0] {
        // Documentos de identidad: CI, NIT, DNI, PASSPORT, CPF, CNPJ, CUIT
        "CI" | "NIT" | "DNI" | "PASSPORT" | "CPF" | "CNPJ" | "CUIT" => {
            let pais = s.get(1).copied().unwrap_or("BO");
            let tipo_doc = parsear_tipo_documento(s[0]);
            let r = validate::validate_national_id(ctx, tipo_doc, valor, pais).await?;
            Ok(ValidateFieldResult {
                valido: r.valid,
                errores: r.errores,
                valor_normalizado: r.normalized,
                metadata: json!({ "pais": pais, "tipo_doc": s[0] }),
            })
        }

        "email" => {
            let r = validate::validate_email(ctx, valor).await?;
            Ok(ValidateFieldResult {
                valido: r.valid,
                errores: r.errores,
                valor_normalizado: r.normalized,
                metadata: json!({}),
            })
        }

        "phone" => {
            let pais = s.get(1).copied().unwrap_or("BO");
            let pais_hint = if pais == "E164" { "" } else { pais };
            let r = validate::validate_phone(ctx, valor, pais_hint).await?;
            Ok(ValidateFieldResult {
                valido: r.valid,
                errores: r.errores,
                valor_normalizado: r.e164.clone(),
                metadata: json!({ "e164": r.e164 }),
            })
        }

        "date" => {
            let min = s.get(1).copied().unwrap_or("");
            let max = s.get(2).copied().unwrap_or("");
            validar_fecha(ctx, valor, min, max)
        }

        "money" => {
            let min = s.get(2).copied().unwrap_or("");
            let max = s.get(3).copied().unwrap_or("");
            validar_numero(valor, "decimal", 2, min, max)
        }

        "number" => {
            let subtipo   = s.get(1).copied().unwrap_or("integer");
            let decimales = s.get(2).and_then(|v| v.parse().ok()).unwrap_or(0u32);
            let min       = s.get(3).copied().unwrap_or("");
            let max       = s.get(4).copied().unwrap_or("");
            validar_numero(valor, subtipo, decimales, min, max)
        }

        "text" => validar_texto(valor, &s),

        "enum" => {
            let catalogo = s.get(1).copied().unwrap_or("default");
            // s[2] lleva opciones inline codificadas como "v1|v2|v3" por el dispatcher
            let inline_ops: Vec<&str> = s.get(2)
                .map(|enc| enc.split('|').collect())
                .unwrap_or_default();
            validar_enum(ctx, valor, catalogo, &inline_ops).await
        }

        // ── Tipos semánticos del árbol bAuth ─────────────────────────────────
        "slug"       => validar_slug(valor),
        "semver"     => validar_semver(valor),
        "cidr"       => validar_cidr(valor),
        "uuid"       => validar_uuid(valor),
        "hex"        => {
            let bits = s.get(1).and_then(|v| v.parse::<u32>().ok()).unwrap_or(64);
            validar_hex(valor, bits)
        }
        "datetime"   => validar_datetime(ctx, valor),
        "json_array" => validar_json_array(valor),
        "role_id"    => validar_role_id(valor),

        "password" => validar_password(ctx, valor),

        "bool" => {
            let v = valor.to_lowercase();
            let valido = matches!(v.as_str(), "true" | "false" | "1" | "0" | "si" | "no");
            if valido {
                Ok(ValidateFieldResult {
                    valido: true, errores: vec![],
                    valor_normalizado: v, metadata: json!({}),
                })
            } else {
                Ok(ValidateFieldResult {
                    valido: false,
                    errores: vec!["El valor debe ser verdadero o falso.".to_string()],
                    valor_normalizado: String::new(), metadata: json!({}),
                })
            }
        }

        otro => Err(Bi18nError::FormatoDesconocido {
            codigo: format!("DSL tipo no reconocido: '{}'", otro),
        }),
    }
}

// ── Helpers de validación síncronos ──────────────────────────────────────────

/// Valida una fecha. Acepta "YYYY-MM-DD" o "DD/MM/YYYY" (con máscara de entrada).
fn validar_fecha(
    ctx: &ServerContext,
    valor: &str,
    min: &str,
    max: &str,
) -> Resultado<ValidateFieldResult> {
    // Normalizar a ISO YYYY-MM-DD
    let iso = if valor.len() == 10 && valor.chars().nth(4) == Some('-') {
        valor.to_string()
    } else if valor.len() == 10 && valor.chars().nth(2) == Some('/') {
        // DD/MM/YYYY → YYYY-MM-DD
        let p: Vec<&str> = valor.split('/').collect();
        if p.len() == 3 { format!("{}-{}-{}", p[2], p[1], p[0]) }
        else { return err_fecha(ctx) }
    } else {
        return err_fecha(ctx);
    };

    // Verificar que los componentes sean válidos
    let partes: Vec<u32> = iso.split('-').filter_map(|s| s.parse().ok()).collect();
    if partes.len() != 3 { return err_fecha(ctx); }
    let (year, month, day) = (partes[0], partes[1], partes[2]);
    if month < 1 || month > 12 || day < 1 || day > dias_en_mes(year, month) {
        return err_fecha(ctx);
    }

    // Validar rango si viene especificado (comparación lexicográfica de ISO es válida)
    if !min.is_empty() && iso.as_str() < min {
        return Ok(ValidateFieldResult {
            valido: false,
            errores: vec![format!("La fecha debe ser igual o posterior a {}.", min)],
            valor_normalizado: String::new(), metadata: json!({}),
        });
    }
    if !max.is_empty() && iso.as_str() > max {
        return Ok(ValidateFieldResult {
            valido: false,
            errores: vec![format!("La fecha debe ser igual o anterior a {}.", max)],
            valor_normalizado: String::new(), metadata: json!({}),
        });
    }

    Ok(ValidateFieldResult {
        valido: true, errores: vec![],
        valor_normalizado: iso, metadata: json!({}),
    })
}

fn err_fecha(ctx: &ServerContext) -> Resultado<ValidateFieldResult> {
    let msg = ctx.fluent.traducir("error-fecha-invalida", None);
    let msg = if msg == "error-fecha-invalida" {
        "Fecha inválida. Use el formato DD/MM/AAAA.".to_string()
    } else { msg };
    Ok(ValidateFieldResult {
        valido: false, errores: vec![msg],
        valor_normalizado: String::new(), metadata: json!({}),
    })
}

/// Valida un número (entero, decimal, porcentaje) con rango opcional.
fn validar_numero(
    valor: &str,
    subtipo: &str,
    decimales: u32,
    min: &str,
    max: &str,
) -> Resultado<ValidateFieldResult> {
    // Normalizar: coma decimal → punto, quitar símbolo de moneda
    let limpio = valor.replace(',', ".").replace("Bs.", "").replace('$', "");
    let limpio = limpio.trim().to_string();
    let num: f64 = limpio.parse().map_err(|_| Bi18nError::FormatoDesconocido {
        codigo: format!("'{}' no es un número válido", valor),
    })?;

    if subtipo == "integer" && limpio.contains('.') {
        return Ok(ValidateFieldResult {
            valido: false,
            errores: vec!["El valor debe ser un número entero.".to_string()],
            valor_normalizado: String::new(), metadata: json!({}),
        });
    }
    if subtipo == "percent" && !(0.0..=100.0).contains(&num) {
        return Ok(ValidateFieldResult {
            valido: false,
            errores: vec!["El porcentaje debe estar entre 0 y 100.".to_string()],
            valor_normalizado: String::new(), metadata: json!({}),
        });
    }
    if !min.is_empty() {
        if let Ok(mn) = min.parse::<f64>() {
            if num < mn {
                return Ok(ValidateFieldResult {
                    valido: false,
                    errores: vec![format!("El valor debe ser mayor o igual a {}.", min)],
                    valor_normalizado: String::new(), metadata: json!({}),
                });
            }
        }
    }
    if !max.is_empty() {
        if let Ok(mx) = max.parse::<f64>() {
            if num > mx {
                return Ok(ValidateFieldResult {
                    valido: false,
                    errores: vec![format!("El valor debe ser menor o igual a {}.", max)],
                    valor_normalizado: String::new(), metadata: json!({}),
                });
            }
        }
    }

    let normalizado = format!("{:.prec$}", num, prec = decimales as usize);
    Ok(ValidateFieldResult {
        valido: true, errores: vec![],
        valor_normalizado: normalizado,
        metadata: json!({ "numerico": num }),
    })
}

/// Valida texto según modificador: libre, alpha, alphanumeric, o rango de longitud.
fn validar_texto(valor: &str, s: &[&str]) -> Resultado<ValidateFieldResult> {
    let mod1 = s.get(1).copied().unwrap_or("");
    match mod1 {
        "alpha" => {
            if !valor.chars().all(|c| c.is_alphabetic() || c == ' ') {
                return Ok(ValidateFieldResult {
                    valido: false,
                    errores: vec!["El campo solo puede contener letras.".to_string()],
                    valor_normalizado: String::new(), metadata: json!({}),
                });
            }
        }
        "alphanumeric" => {
            if !valor.chars().all(|c| c.is_alphanumeric() || c == ' ') {
                return Ok(ValidateFieldResult {
                    valido: false,
                    errores: vec!["El campo solo puede contener letras y números.".to_string()],
                    valor_normalizado: String::new(), metadata: json!({}),
                });
            }
        }
        m if m.parse::<usize>().is_ok() => {
            let mn: usize = m.parse().unwrap_or(0);
            let mx: usize = s.get(2).and_then(|v| v.parse().ok()).unwrap_or(usize::MAX);
            let len = valor.chars().count();
            if len < mn {
                return Ok(ValidateFieldResult {
                    valido: false,
                    errores: vec![format!("El campo debe tener al menos {} caracteres.", mn)],
                    valor_normalizado: String::new(), metadata: json!({}),
                });
            }
            if len > mx {
                return Ok(ValidateFieldResult {
                    valido: false,
                    errores: vec![format!("El campo no puede exceder {} caracteres.", mx)],
                    valor_normalizado: String::new(), metadata: json!({}),
                });
            }
        }
        _ => {} // texto libre — válido siempre
    }

    Ok(ValidateFieldResult {
        valido: true, errores: vec![],
        valor_normalizado: valor.to_string(), metadata: json!({}),
    })
}

/// Valida contraseña según NIST 800-63B Rev.4: ≥8 caracteres Unicode, sin lista negra básica.
fn validar_password(ctx: &ServerContext, valor: &str) -> Resultado<ValidateFieldResult> {
    if valor.chars().count() < 8 {
        let msg = ctx.fluent.traducir("error-password-corto", None);
        let msg = if msg == "error-password-corto" {
            "La contraseña debe tener al menos 8 caracteres.".to_string()
        } else { msg };
        return Ok(ValidateFieldResult {
            valido: false, errores: vec![msg],
            valor_normalizado: String::new(), metadata: json!({}),
        });
    }
    // Lista negra NIST (muestra — producción: 100k+ contraseñas comunes)
    const COMUNES: &[&str] = &[
        "12345678", "password", "qwerty123", "abcd1234",
        "contraseña", "12345678901", "password1",
    ];
    if COMUNES.contains(&valor.to_lowercase().as_str()) {
        return Ok(ValidateFieldResult {
            valido: false,
            errores: vec!["Esta contraseña es demasiado común. Elija una diferente.".to_string()],
            valor_normalizado: String::new(), metadata: json!({}),
        });
    }
    Ok(ValidateFieldResult {
        valido: true, errores: vec![],
        valor_normalizado: String::new(), // no devolver la contraseña
        metadata: json!({ "longitud": valor.chars().count() }),
    })
}

/// Valida un valor de enum contra opciones inline o catálogo de servidor.
/// inline_ops: opciones codificadas por el dispatcher desde tipo_cfg["opciones"].
///   Si no está vacío → validación local (sin RPC al servidor de catálogos).
///   Si está vacío → delegar al catálogo embebido de enums.rs.
async fn validar_enum(
    ctx: &ServerContext,
    valor: &str,
    catalogo: &str,
    inline_ops: &[&str],
) -> Resultado<ValidateFieldResult> {
    use crate::server::handlers::enums;

    // Ruta rápida: opciones pasadas inline por el árbol (evita round-trip de catálogo)
    if !inline_ops.is_empty() {
        if inline_ops.contains(&valor) {
            return Ok(ValidateFieldResult {
                valido: true, errores: vec![],
                valor_normalizado: valor.to_string(),
                metadata: json!({ "catalogo": catalogo }),
            });
        }
        return Ok(ValidateFieldResult {
            valido: false,
            errores: vec![format!(
                "El valor '{}' no está en las opciones válidas para '{}'.", valor, catalogo
            )],
            valor_normalizado: String::new(),
            metadata: json!({ "catalogo": catalogo }),
        });
    }

    // Catálogos de servidor conocidos — validación estricta
    const CATALOGOS_CONOCIDOS: &[&str] = &[
        "gender", "genero", "marital_status", "employment_type", "status",
        "combining_algorithm", "xacml_decision", "decision",
        "op_logico", "operador", "verbo",
        "loa", "level_of_assurance",
        "security_impact", "classification",
        "tier", "algorithm", "amr",
        "fido_requirement", "resident_key", "user_verification",
        "attestation", "authenticator_attachment",
    ];

    let r = enums::display(ctx, catalogo, valor, "es").await?;

    if r.found {
        return Ok(ValidateFieldResult {
            valido: true, errores: vec![],
            valor_normalizado: valor.to_string(),
            metadata: json!({ "catalogo": catalogo, "label": r.label }),
        });
    }

    if CATALOGOS_CONOCIDOS.contains(&catalogo) {
        return Ok(ValidateFieldResult {
            valido: false,
            errores: vec![format!(
                "El valor '{}' no es válido para el catálogo '{}'.", valor, catalogo
            )],
            valor_normalizado: String::new(),
            metadata: json!({ "catalogo": catalogo }),
        });
    }

    // Catálogo desconocido — aceptar con nota de cobertura parcial
    Ok(ValidateFieldResult {
        valido: true, errores: vec![],
        valor_normalizado: valor.to_string(),
        metadata: json!({ "catalogo": catalogo, "en_catalogo": false }),
    })
}

// ── Tipos semánticos del árbol bAuth ─────────────────────────────────────────

/// Valida un slug: letras minúsculas, dígitos, guiones y guiones bajos.
/// Normaliza a minúsculas automáticamente.
fn validar_slug(valor: &str) -> Resultado<ValidateFieldResult> {
    let norm = valor.to_lowercase();
    let primer_ok = norm.chars().next().map(|c| c.is_ascii_lowercase()).unwrap_or(false);
    let resto_ok  = norm.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_' || c == '-');
    if primer_ok && resto_ok {
        return Ok(ValidateFieldResult { valido: true, errores: vec![], valor_normalizado: norm, metadata: json!({}) });
    }
    Ok(ValidateFieldResult {
        valido: false,
        errores: vec!["El slug solo puede contener letras minúsculas, dígitos, _ y -, y debe comenzar con letra.".to_string()],
        valor_normalizado: String::new(), metadata: json!({}),
    })
}

/// Valida versión semántica MAJOR.MINOR.PATCH según SemVer.
fn validar_semver(valor: &str) -> Resultado<ValidateFieldResult> {
    let partes: Vec<&str> = valor.split('.').collect();
    if partes.len() == 3 && partes.iter().all(|p| p.parse::<u64>().is_ok()) {
        return Ok(ValidateFieldResult { valido: true, errores: vec![], valor_normalizado: valor.to_string(), metadata: json!({}) });
    }
    Ok(ValidateFieldResult {
        valido: false,
        errores: vec!["Versión inválida. Use SemVer: MAJOR.MINOR.PATCH (ej: 1.0.0).".to_string()],
        valor_normalizado: String::new(), metadata: json!({}),
    })
}

/// Valida notación CIDR IPv4 (ej: 192.168.1.0/24) o la cadena literal "any".
fn validar_cidr(valor: &str) -> Resultado<ValidateFieldResult> {
    let v = valor.trim();
    if v == "any" {
        return Ok(ValidateFieldResult { valido: true, errores: vec![], valor_normalizado: v.to_string(), metadata: json!({ "any": true }) });
    }
    let partes: Vec<&str> = v.split('/').collect();
    if partes.len() != 2 { return Ok(err_cidr()); }
    let prefijo: u8 = match partes[1].parse::<u8>() {
        Ok(p) if p <= 32 => p,
        _ => return Ok(err_cidr()),
    };
    let octetos: Vec<u8> = partes[0].split('.').filter_map(|o| o.parse().ok()).collect();
    if octetos.len() != 4 { return Ok(err_cidr()); }
    Ok(ValidateFieldResult { valido: true, errores: vec![], valor_normalizado: v.to_string(), metadata: json!({ "prefijo": prefijo }) })
}
fn err_cidr() -> ValidateFieldResult {
    ValidateFieldResult {
        valido: false,
        errores: vec!["CIDR inválido. Use IP/prefijo (ej: 192.168.1.0/24) o 'any'.".to_string()],
        valor_normalizado: String::new(), metadata: json!({}),
    }
}

/// Valida UUID (cualquier versión). Normaliza a minúsculas con guiones.
fn validar_uuid(valor: &str) -> Resultado<ValidateFieldResult> {
    match uuid::Uuid::parse_str(valor) {
        Ok(id) => Ok(ValidateFieldResult {
            valido: true, errores: vec![],
            valor_normalizado: id.hyphenated().to_string(),
            metadata: json!({ "version": id.get_version_num() }),
        }),
        Err(_) => Ok(ValidateFieldResult {
            valido: false,
            errores: vec!["UUID inválido. Formato: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.".to_string()],
            valor_normalizado: String::new(), metadata: json!({}),
        }),
    }
}

/// Valida un valor hexadecimal con ancho de bits opcional.
/// Normaliza a mayúsculas con prefijo 0x.
fn validar_hex(valor: &str, bits: u32) -> Resultado<ValidateFieldResult> {
    let limpio = valor.trim().trim_start_matches("0x").trim_start_matches("0X");
    if limpio.is_empty() || !limpio.chars().all(|c| c.is_ascii_hexdigit()) {
        return Ok(ValidateFieldResult {
            valido: false,
            errores: vec!["Valor hexadecimal inválido. Use dígitos 0-9 y letras A-F.".to_string()],
            valor_normalizado: String::new(), metadata: json!({}),
        });
    }
    if bits > 0 {
        let max_chars = (bits / 4) as usize;
        if limpio.len() > max_chars {
            return Ok(ValidateFieldResult {
                valido: false,
                errores: vec![format!("El valor supera {} bits ({} dígitos hex máx.).", bits, max_chars)],
                valor_normalizado: String::new(), metadata: json!({}),
            });
        }
    }
    let norm = format!("0x{}", limpio.to_uppercase());
    Ok(ValidateFieldResult { valido: true, errores: vec![], valor_normalizado: norm, metadata: json!({ "bits": bits }) })
}

/// Valida fecha/hora ISO 8601 (ej: 2024-01-01T00:00:00Z).
/// Usa jiff::Timestamp para parseo estricto.
fn validar_datetime(ctx: &ServerContext, valor: &str) -> Resultado<ValidateFieldResult> {
    match valor.parse::<jiff::Timestamp>() {
        Ok(_) => Ok(ValidateFieldResult {
            valido: true, errores: vec![],
            valor_normalizado: valor.to_string(), metadata: json!({ "datetime": true }),
        }),
        Err(_) => {
            let msg = ctx.fluent.traducir("error-datetime-invalido", None);
            let msg = if msg == "error-datetime-invalido" {
                "Fecha/hora inválida. Use formato ISO 8601: 2024-01-01T00:00:00Z.".to_string()
            } else { msg };
            Ok(ValidateFieldResult { valido: false, errores: vec![msg], valor_normalizado: String::new(), metadata: json!({}) })
        }
    }
}

/// Valida que el valor sea un array JSON (ej: ["ITEM_A","ITEM_B"]).
fn validar_json_array(valor: &str) -> Resultado<ValidateFieldResult> {
    match serde_json::from_str::<Vec<serde_json::Value>>(valor) {
        Ok(arr) => Ok(ValidateFieldResult {
            valido: true, errores: vec![],
            valor_normalizado: valor.to_string(),
            metadata: json!({ "items": arr.len() }),
        }),
        Err(_) => Ok(ValidateFieldResult {
            valido: false,
            errores: vec!["Valor JSON inválido. Debe ser array, ej: [\"ITEM_A\",\"ITEM_B\"].".to_string()],
            valor_normalizado: String::new(), metadata: json!({}),
        }),
    }
}

/// Valida ID de rol con formato SIGLA-NNN (segmentos alfanuméricos, último ≥ 3 dígitos).
/// Normaliza a mayúsculas.
fn validar_role_id(valor: &str) -> Resultado<ValidateFieldResult> {
    let norm = valor.trim().to_uppercase();
    let segs: Vec<&str> = norm.split('-').collect();
    if segs.len() >= 2 {
        let ultimo     = segs.last().unwrap();
        let num_ok     = ultimo.len() >= 3 && ultimo.chars().all(|c| c.is_ascii_digit());
        let prefijo_ok = segs[..segs.len()-1].iter()
            .all(|s| !s.is_empty() && s.chars().all(|c| c.is_ascii_uppercase() || c.is_ascii_digit()));
        if num_ok && prefijo_ok {
            return Ok(ValidateFieldResult { valido: true, errores: vec![], valor_normalizado: norm, metadata: json!({}) });
        }
    }
    Ok(ValidateFieldResult {
        valido: false,
        errores: vec!["ID de rol inválido. Formato: SIGLA-NNN (ej: RGV-001).".to_string()],
        valor_normalizado: String::new(), metadata: json!({}),
    })
}

// ── bi18n.format.value ────────────────────────────────────────────────────────

/// Formatea un valor según el token del SDK.
/// Parámetros:
///   formato  — token DSL, p.ej. "date:medium", "money:BOB", "number:decimal:2", "phone:national"
///   valor    — valor crudo o normalizado a formatear
///   regional — configuración regional del tenant (locale, timezone, currency, country)
pub async fn format_value(
    ctx: &ServerContext,
    formato: &str,
    valor: &str,
    regional: &RegionalConfig,
) -> Resultado<FormatValueResult> {
    let s = segs(formato);
    match s[0] {
        "date" => {
            let gran = match s.get(1).copied().unwrap_or("medium") {
                "time"  => fmt::GranularidadFecha::SoloHora,
                "month" => fmt::GranularidadFecha::MesAnio,
                "year"  => fmt::GranularidadFecha::SoloAnio,
                _       => fmt::GranularidadFecha::SoloFecha,
            };
            let r = fmt::format_fecha_o_ahora(ctx, Some(valor), gran, regional).await?;
            Ok(FormatValueResult { formateado: r.display })
        }

        "datetime" => {
            let r = fmt::format_fecha_o_ahora(
                ctx, Some(valor), fmt::GranularidadFecha::FechaHora, regional,
            ).await?;
            Ok(FormatValueResult { formateado: r.display })
        }

        "time" => {
            let r = fmt::format_fecha_o_ahora(
                ctx, Some(valor), fmt::GranularidadFecha::SoloHora, regional,
            ).await?;
            Ok(FormatValueResult { formateado: r.display })
        }

        "money" => {
            let moneda = s.get(1).copied().unwrap_or(regional.currency.as_str());
            let r = fmt::format_money(ctx, valor, moneda, regional).await?;
            Ok(FormatValueResult { formateado: r.display })
        }

        "number" => {
            let subtipo  = s.get(1).copied().unwrap_or("decimal");
            let dec: u32 = s.get(2).and_then(|v| v.parse().ok()).unwrap_or(2);
            let r = fmt::format_number(ctx, valor, dec, regional).await?;
            let display = if subtipo == "percent" { format!("{} %", r.display) } else { r.display };
            Ok(FormatValueResult { formateado: display })
        }

        "phone" => {
            use phonenumber::Mode;
            use phonenumber::country::Id;
            let modo_str = s.get(1).copied().unwrap_or("national");
            let pais     = s.get(2).copied().unwrap_or(regional.country.as_str());
            let region: Option<Id> = pais.parse().ok();
            let num = phonenumber::parse(region, valor).map_err(|e| Bi18nError::TelefonoInvalido {
                valor: valor.to_string(),
                causa: e.to_string(),
            })?;
            let modo = match modo_str { "e164" => Mode::E164, "rfc3966" => Mode::Rfc3966, _ => Mode::National };
            Ok(FormatValueResult { formateado: num.format().mode(modo).to_string() })
        }

        otro => Err(Bi18nError::FormatoDesconocido {
            codigo: format!("Token de formato no reconocido: '{}'", otro),
        }),
    }
}

// ── bi18n.mask.pattern ────────────────────────────────────────────────────────

/// Devuelve la configuración de máscara de entrada IMask.js para el DSL tipo dado.
/// El cliente JS/TS aplica este objeto directamente con `IMask(element, resultado)`.
/// Nota: función pura — sin I/O, sin async. Mapa estático del DSL al contrato IMask.
pub fn mask_pattern(tipo: &str) -> MaskPatternResult {
    let s = segs(tipo);
    match s[0] {
        "CI" => MaskPatternResult {
            motor: "Pattern",
            patron: Some("0000000-aA".to_string()),
            opciones: json!({
                "definitions": { "0": "[0-9]", "a": "[a-zA-Z]", "A": "[a-zA-Z]" }
            }),
            placeholder: Some("_______-__".to_string()),
            usar_mascara: true,
        },
        "NIT" => MaskPatternResult {
            motor: "Pattern",
            patron: Some("000000000-0".to_string()),
            opciones: json!({ "definitions": { "0": "[0-9]" } }),
            placeholder: Some("_________-_".to_string()),
            usar_mascara: true,
        },
        "DNI" => MaskPatternResult {
            motor: "Pattern",
            patron: Some("00000000".to_string()),
            opciones: json!({ "definitions": { "0": "[0-9]" } }),
            placeholder: Some("________".to_string()),
            usar_mascara: true,
        },
        "CUIT" => MaskPatternResult {
            motor: "Pattern",
            patron: Some("00-00000000-0".to_string()),
            opciones: json!({ "definitions": { "0": "[0-9]" } }),
            placeholder: Some("__-________-_".to_string()),
            usar_mascara: true,
        },
        "phone" => {
            let pais = s.get(1).copied().unwrap_or("BO");
            let (patron, placeholder) = match pais {
                "AR" => ("0 0000-0000", "_ ____-____"),
                "BR" => ("(00) 00000-0000", "(__) _____-____"),
                _    => ("0 000-0000", "_ ___-____"),
            };
            MaskPatternResult {
                motor: "Pattern",
                patron: Some(patron.to_string()),
                opciones: json!({ "definitions": { "0": "[0-9]" } }),
                placeholder: Some(placeholder.to_string()),
                usar_mascara: true,
            }
        }
        "date" => MaskPatternResult {
            motor: "Date",
            patron: Some("DD/MM/YYYY".to_string()),
            opciones: json!({
                "blocks": {
                    "DD":   { "mask": "MaskedRange", "from": 1,    "to": 31,   "maxLength": 2 },
                    "MM":   { "mask": "MaskedRange", "from": 1,    "to": 12,   "maxLength": 2 },
                    "YYYY": { "mask": "MaskedRange", "from": 1900, "to": 2100, "maxLength": 4 }
                },
                "autofix": true,
                "lazy": false
            }),
            placeholder: Some("dd/mm/aaaa".to_string()),
            usar_mascara: true,
        },
        "money" => {
            let moneda = s.get(1).copied().unwrap_or("BOB");
            let (sep_miles, sep_decimal) = if moneda == "USD" { (",", ".") } else { (".", ",") };
            MaskPatternResult {
                motor: "Number",
                patron: None,
                opciones: json!({
                    "scale":              2,
                    "signed":             false,
                    "thousandsSeparator": sep_miles,
                    "radix":              sep_decimal,
                    "padFractionalZeros": true,
                    "normalizeZeros":     true,
                    "min":                0
                }),
                placeholder: None,
                usar_mascara: true,
            }
        }
        "number" => {
            let subtipo  = s.get(1).copied().unwrap_or("integer");
            let scale: u32 = s.get(2).and_then(|v| v.parse().ok()).unwrap_or(0);
            let scale = if subtipo == "integer" { 0 } else { scale };
            MaskPatternResult {
                motor: "Number",
                patron: None,
                opciones: json!({
                    "scale":              scale,
                    "signed":             subtipo == "decimal",
                    "thousandsSeparator": ".",
                    "radix":              ",",
                    "min": if subtipo == "percent" { Some(0) } else { None::<i32> },
                    "max": if subtipo == "percent" { Some(100) } else { None::<i32> }
                }),
                placeholder: None,
                usar_mascara: true,
            }
        }
        // uuid → máscara de 32 hex dígitos con guiones (8-4-4-4-12)
        "uuid" => MaskPatternResult {
            motor: "Pattern",
            patron: Some("HHHHHHHH-HHHH-HHHH-HHHH-HHHHHHHHHHHH".to_string()),
            opciones: json!({ "definitions": { "H": "[0-9a-fA-F]" } }),
            placeholder: Some("________-____-____-____-____________".to_string()),
            usar_mascara: true,
        },
        // hex → máscara de ancho fijo según bits (default 64 bits = 16 hex chars)
        "hex" => {
            let bits = s.get(1).and_then(|v| v.parse::<u32>().ok()).unwrap_or(64);
            let n = (bits / 4) as usize;
            MaskPatternResult {
                motor: "Pattern",
                patron: Some(format!("0x{}", "H".repeat(n))),
                opciones: json!({ "definitions": { "H": "[0-9a-fA-F]" } }),
                placeholder: Some(format!("0x{}", "_".repeat(n))),
                usar_mascara: true,
            }
        }
        // email, text, password, slug, semver, cidr, datetime, json_array, role_id → sin máscara
        _ => MaskPatternResult {
            motor: "none",
            patron: None,
            opciones: json!({}),
            placeholder: None,
            usar_mascara: false,
        },
    }
}

// ── Utilidades internas ───────────────────────────────────────────────────────

/// Días válidos en un mes del calendario gregoriano.
fn dias_en_mes(year: u32, month: u32) -> u32 {
    match month {
        1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
        4 | 6 | 9 | 11 => 30,
        2 if year % 400 == 0 || (year % 4 == 0 && year % 100 != 0) => 29,
        2 => 28,
        _ => 0,
    }
}
