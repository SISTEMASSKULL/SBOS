/// bin/i18nctl.rs — CLI de administración del daemon bi18n (binario: bi18nctl).
/// Propósito: cliente JSON-RPC sobre Unix socket para operadores y scripts.
///   - Comunica con bi18nd por /run/bos/bi18n.sock (JSON-RPC 2.0, línea por conexión).
///   - Flags transversales: --json (JSON crudo), --quiet (solo exit code), --ctx-id.
///   - Exit codes: 0=ok, 1=respuesta inválida del dominio, 2=error daemon/conexión.
///   - ctx_id generado automáticamente (UUID v4) si no se pasa explícitamente (SBOS-049).
///   - Subcomandos locales (sin daemon): `translations check-parity`.
///   - Subcomando protegido: `admin` — lee contraseña con clipass_rs (A.08.17).
/// Dependencias: clap, serde_json, uuid, clipass_rs, std::os::unix::net
use clipass_rs::CliPass;
use std::{
    collections::HashSet,
    fs,
    io::{BufRead, BufReader, Write},
    os::unix::net::UnixStream,
    path::PathBuf,
    process::ExitCode,
    time::Duration,
};
use clap::{Parser, Subcommand};
use serde_json::{json, Value};
use uuid::Uuid;

// ────────────────────────────────────────────────────────────────────────────
// Definición CLI (clap derive)
// ────────────────────────────────────────────────────────────────────────────

/// bi18nctl — administra el daemon bi18n del ecosistema SBOS.
#[derive(Parser, Debug)]
#[command(name = "bi18nctl", about = "CLI de administración del daemon bi18n (SBOS i18n-orchestrator)")]
struct Cli {
    /// Ruta al socket Unix del daemon (por defecto: /run/bos/bi18n.sock).
    #[arg(long, global = true, default_value = "/run/bos/bi18n.sock")]
    socket: String,

    /// Imprime el resultado JSON crudo (útil para scripts y CI/CD).
    #[arg(long, global = true)]
    json: bool,

    /// Solo exit code: 0=ok, 1=inválido, 2=error daemon. Sin output.
    #[arg(long, global = true)]
    quiet: bool,

    /// ctx_id explícito para SBOS-049 Context Plane. Por defecto: UUID v4 generado.
    #[arg(long, global = true)]
    ctx_id: Option<String>,

    #[command(subcommand)]
    comando: Comando,
}

/// Subcomandos disponibles en i18nctl.
#[derive(Subcommand, Debug)]
enum Comando {
    /// Verifica que el daemon está activo y muestra su estado.
    Estado,

    /// Recarga country-rules y mensajes Fluent sin reiniciar el daemon.
    Recargar,

    /// Recarga solo las traducciones FTL sin recargar country-rules (Bloque 11.2).
    /// Swap atómico — el daemon sigue sirviendo durante la recarga.
    RecargarTraducciones,

    /// Formatea una fecha/hora según el locale del tenant.
    FormatFecha {
        #[arg(help = "Timestamp ISO 8601 (ej: 2026-07-16T14:30:00Z)")]
        fecha: String,
        #[arg(long, default_value = "es-BO", help = "Locale BCP 47")]
        locale: String,
        #[arg(long, default_value = "SoloFecha",
              help = "SoloFecha|FechaHora|MesAnio|SoloAnio|SoloHora")]
        granularidad: String,
        #[arg(long, default_value = "America/La_Paz", help = "Zona horaria IANA")]
        timezone: String,
    },

    /// Formatea un número con separadores según el locale.
    FormatNumero {
        #[arg(help = "Valor numérico (ej: 1234567.89)")]
        valor: f64,
        #[arg(long, default_value = "2", help = "Decimales a mostrar")]
        decimales: u32,
        #[arg(long, default_value = "es-BO", help = "Locale BCP 47")]
        locale: String,
    },

    /// Formatea un monto monetario con símbolo y separadores.
    FormatMonto {
        #[arg(help = "Monto (ej: 1234.56)")]
        monto: f64,
        #[arg(long, default_value = "BOB", help = "Código ISO 4217 de moneda")]
        moneda: String,
        #[arg(long, default_value = "es-BO", help = "Locale BCP 47")]
        locale: String,
    },

    /// Valida y normaliza un documento de identidad nacional.
    ValidarId {
        #[arg(help = "Valor del documento (ej: 7654321-LP)")]
        valor: String,
        #[arg(long, default_value = "CI",
              help = "Tipo: CI | NIT | DNI | CPF | CNPJ | CUIT | PASSPORT")]
        tipo: String,
        #[arg(long, default_value = "BO", help = "Código ISO 3166-1 alpha-2 del país")]
        pais: String,
    },

    /// Valida una dirección de correo electrónico (RFC 5321).
    ValidarEmail {
        #[arg(help = "Dirección de email a validar")]
        valor: String,
    },

    /// Valida un número de teléfono E.164.
    ValidarTelefono {
        #[arg(help = "Número de teléfono (ej: +59171234567)")]
        valor: String,
        #[arg(long, default_value = "BO", help = "Código ISO 3166-1 alpha-2 del país")]
        pais: String,
    },

    /// Enmascara un valor de atributo según la estrategia indicada.
    MaskValor {
        #[arg(help = "Valor a enmascarar")]
        valor: String,
        #[arg(long, default_value = "parcial",
              help = "Estrategia: parcial | total | email | telefono")]
        estrategia: String,
    },

    /// Enmascara datos PII en texto libre.
    MaskPii {
        #[arg(help = "Texto con datos PII a enmascarar")]
        texto: String,
    },

    /// Resuelve el locale efectivo para un tenant/branch/usuario.
    LocaleResolver {
        #[arg(long, default_value = "default", help = "ID del tenant")]
        tenant: String,
        #[arg(long, help = "Branch organizacional (opcional)")]
        branch: Option<String>,
        #[arg(long, help = "ID del usuario (opcional)")]
        usuario: Option<String>,
    },

    /// Obtiene el display localizado de un valor de enum.
    EnumDisplay {
        #[arg(help = "Nombre del enum (ej: ESTADO_CIVIL)")]
        r#enum: String,
        #[arg(help = "Valor del enum (ej: CASADO)")]
        valor: String,
        #[arg(long, default_value = "es-BO", help = "Locale BCP 47")]
        locale: String,
    },

    /// Obtiene el snapshot de configuración regional completo de un tenant.
    Snapshot {
        #[arg(long, default_value = "default", help = "ID del tenant")]
        tenant: String,
    },

    /// Ejecuta el pipeline completo de un atributo (validar + formatear + enmascarar).
    AttrPipeline {
        #[arg(help = "Clave del atributo (ej: ci_numero)")]
        clave: String,
        #[arg(help = "Valor del atributo")]
        valor: String,
        #[arg(long, default_value = "default", help = "ID del tenant")]
        tenant: String,
    },

    /// Gestión de traducciones (operaciones locales — no requieren daemon activo).
    Translations {
        #[command(subcommand)]
        subcomando: ComandoTranslations,
    },

    /// Operaciones administrativas protegidas (requieren contraseña admin).
    /// Lee la contraseña de forma segura con clipass_rs y la envía como hash SHA256 (A.08.17).
    Admin {
        #[command(subcommand)]
        operacion: ComandoAdmin,
    },
}

/// Subcomandos administrativos protegidos por contraseña.
#[derive(clap::Subcommand, Debug)]
enum ComandoAdmin {
    /// Recarga country-rules y traducciones Fluent (operación protegida).
    Recargar,
    /// Recarga solo traducciones FTL, sin recargar country-rules (operación protegida).
    RecargarTraducciones,
    /// Verifica el estado interno del daemon con privilegios admin.
    Estado,
}

/// Subcomandos de gestión de traducciones.
#[derive(clap::Subcommand, Debug)]
enum ComandoTranslations {
    /// Verifica que todos los locales tienen las mismas claves que el locale de referencia.
    /// Sale con código 1 si falta alguna clave; no requiere que bi18nd esté activo.
    CheckParity {
        /// Locale de referencia — fuente de verdad de claves FTL.
        #[arg(long, default_value = "es-BO")]
        reference: String,
        /// Directorio raíz de locales. Relativo al CWD o ruta absoluta.
        #[arg(long, default_value = "locales")]
        locales_dir: String,
        /// Retorna exit code 1 si hay claves faltantes (para CI/CD).
        #[arg(long)]
        fail_on_missing: bool,
    },
}

// ────────────────────────────────────────────────────────────────────────────
// Cliente JSON-RPC 2.0 sobre Unix domain socket (síncrono)
// ────────────────────────────────────────────────────────────────────────────

/// Envía una solicitud JSON-RPC al daemon y devuelve el campo `result`.
/// Retorna `Err(String)` si la conexión falla o el daemon retorna error.
fn enviar_jsonrpc(socket_path: &str, method: &str, params: Value) -> Result<Value, String> {
    let mut stream = UnixStream::connect(socket_path)
        .map_err(|e| format!("no se pudo conectar a '{}': {}", socket_path, e))?;

    stream.set_read_timeout(Some(Duration::from_secs(10)))
        .map_err(|e| format!("set_read_timeout: {}", e))?;
    stream.set_write_timeout(Some(Duration::from_secs(5)))
        .map_err(|e| format!("set_write_timeout: {}", e))?;

    let request = json!({
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
        "params": params,
    });

    let mut payload = serde_json::to_string(&request)
        .map_err(|e| format!("serialización de solicitud: {}", e))?;
    payload.push('\n');

    stream.write_all(payload.as_bytes())
        .map_err(|e| format!("escritura al socket: {}", e))?;

    let lector = BufReader::new(stream);
    let linea = lector.lines().next()
        .ok_or_else(|| "el daemon cerró la conexión sin responder".to_string())?
        .map_err(|e| format!("lectura del socket: {}", e))?;

    let respuesta: Value = serde_json::from_str(&linea)
        .map_err(|e| format!("JSON inválido del daemon: {} — raw: {}", e, &linea[..linea.len().min(200)]))?;

    if let Some(error) = respuesta.get("error") {
        let codigo  = error.get("code").and_then(|v| v.as_i64()).unwrap_or(-1);
        let mensaje = error.get("message").and_then(|v| v.as_str()).unwrap_or("error desconocido");
        return Err(format!("error del daemon [{}]: {}", codigo, mensaje));
    }

    respuesta.get("result").cloned()
        .ok_or_else(|| "respuesta sin campo 'result'".to_string())
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers de salida en terminal
// ────────────────────────────────────────────────────────────────────────────

/// Imprime el resultado y retorna ExitCode::SUCCESS.
fn imprimir_ok(resultado: &Value, json_mode: bool, quiet_mode: bool) -> ExitCode {
    if quiet_mode { return ExitCode::SUCCESS; }
    if json_mode {
        println!("{}", serde_json::to_string_pretty(resultado)
            .unwrap_or_else(|_| resultado.to_string()));
    } else {
        match resultado {
            Value::Object(_) | Value::Array(_) =>
                println!("{}", serde_json::to_string_pretty(resultado)
                    .unwrap_or_else(|_| resultado.to_string())),
            Value::String(s) => println!("{}", s),
            otro => println!("{}", otro),
        }
    }
    ExitCode::SUCCESS
}

/// Imprime el error en stderr y retorna ExitCode(2).
fn imprimir_error(mensaje: &str, quiet_mode: bool, json_mode: bool) -> ExitCode {
    if !quiet_mode {
        if json_mode {
            eprintln!("{}", json!({ "error": mensaje }));
        } else {
            eprintln!("[i18nctl] error: {}", mensaje);
        }
    }
    ExitCode::from(2)
}

// ────────────────────────────────────────────────────────────────────────────
// Despachador de subcomandos
// ────────────────────────────────────────────────────────────────────────────

/// Construye el par (método JSON-RPC, params) para cada subcomando.
fn construir_llamada(comando: &Comando, ctx_id: &str) -> (&'static str, Value) {
    match comando {
        Comando::Estado => (
            "bi18n.health.check",
            json!({ "ctx_id": ctx_id }),
        ),
        Comando::Recargar => (
            "bi18n.admin.reload",
            json!({ "ctx_id": ctx_id }),
        ),
        Comando::RecargarTraducciones => (
            "bi18n.admin.reload_translations",
            json!({ "ctx_id": ctx_id }),
        ),
        Comando::FormatFecha { fecha, locale, granularidad, timezone } => (
            "bi18n.format.date",
            json!({
                "ctx_id": ctx_id,
                "iso_datetime": fecha,
                "locale": locale,
                "granularidad": granularidad,
                "timezone": timezone,
            }),
        ),
        Comando::FormatNumero { valor, decimales, locale } => (
            "bi18n.format.number",
            json!({
                "ctx_id": ctx_id,
                "valor": valor,
                "decimales": decimales,
                "locale": locale,
            }),
        ),
        Comando::FormatMonto { monto, moneda, locale } => (
            "bi18n.format.money",
            json!({
                "ctx_id": ctx_id,
                "monto": monto,
                "moneda": moneda,
                "locale": locale,
            }),
        ),
        Comando::ValidarId { valor, tipo, pais } => (
            "bi18n.validate.national_id",
            json!({
                "ctx_id": ctx_id,
                "valor": valor,
                "tipo": tipo,
                "pais": pais,
            }),
        ),
        Comando::ValidarEmail { valor } => (
            "bi18n.validate.email",
            json!({ "ctx_id": ctx_id, "valor": valor }),
        ),
        Comando::ValidarTelefono { valor, pais } => (
            "bi18n.validate.phone",
            json!({ "ctx_id": ctx_id, "valor": valor, "pais": pais }),
        ),
        Comando::MaskValor { valor, estrategia } => (
            "bi18n.mask.value",
            json!({ "ctx_id": ctx_id, "valor": valor, "estrategia": estrategia }),
        ),
        Comando::MaskPii { texto } => (
            "bi18n.mask.pii",
            json!({ "ctx_id": ctx_id, "texto": texto }),
        ),
        Comando::LocaleResolver { tenant, branch, usuario } => (
            "bi18n.locale.resolve",
            json!({
                "ctx_id": ctx_id,
                "tenant": tenant,
                "branch": branch,
                "usuario": usuario,
            }),
        ),
        Comando::EnumDisplay { r#enum, valor, locale } => (
            "bi18n.enum.display",
            json!({
                "ctx_id": ctx_id,
                "enum": r#enum,
                "valor": valor,
                "locale": locale,
            }),
        ),
        Comando::Snapshot { tenant } => (
            "bi18n.regional.snapshot",
            json!({ "ctx_id": ctx_id, "tenant": tenant }),
        ),
        Comando::AttrPipeline { clave, valor, tenant } => (
            "bi18n.attr.pipeline",
            json!({
                "ctx_id": ctx_id,
                "clave": clave,
                "valor": valor,
                "tenant": tenant,
            }),
        ),
        // Translations y Admin se ejecutan localmente en main() — nunca llegan aquí.
        Comando::Translations { .. } => unreachable!("traducciones son operaciones locales"),
        Comando::Admin { .. } => unreachable!("admin se procesa antes en main()"),
    }
}

// ────────────────────────────────────────────────────────────────────────────
// Admin — operaciones protegidas por contraseña (A.08.17 clipass_rs)
// ────────────────────────────────────────────────────────────────────────────

/// Autentica al operador con clipass_rs y envía la operación admin al daemon.
/// El hash SHA256 de la contraseña se envía como `admin_token` al daemon.
/// El daemon verifica el hash contra ServidorConfig.admin_hash (nunca en texto plano).
fn ejecutar_admin(
    operacion: &ComandoAdmin,
    socket: &str,
    ctx_id_arg: &Option<String>,
    json_mode: bool,
    quiet: bool,
) -> ExitCode {
    // Leer contraseña de forma segura con clipass_rs — oculta con '*'
    let mut session = CliPass::new();
    session.set_prompt_label("Contraseña admin bi18n: ");
    session.set_no_visibility();
    session.set_prompt_mask_token('*');

    if session.launch_prompt().is_err() {
        return imprimir_error("no se pudo leer la contraseña", quiet, json_mode);
    }

    let admin_token = session.hash_sha256_internal();
    let ctx_id = ctx_id_arg.clone()
        .unwrap_or_else(|| Uuid::new_v4().to_string());

    let (method, params) = match operacion {
        ComandoAdmin::Recargar => (
            "bi18n.admin.reload",
            json!({ "ctx_id": ctx_id, "admin_token": admin_token }),
        ),
        ComandoAdmin::RecargarTraducciones => (
            "bi18n.admin.reload_translations",
            json!({ "ctx_id": ctx_id, "admin_token": admin_token }),
        ),
        ComandoAdmin::Estado => (
            "bi18n.health.check",
            json!({ "ctx_id": ctx_id, "admin_token": admin_token }),
        ),
    };

    match enviar_jsonrpc(socket, method, params) {
        Ok(resultado) => imprimir_ok(&resultado, json_mode, quiet),
        Err(e)        => imprimir_error(&e, quiet, json_mode),
    }
}

// ────────────────────────────────────────────────────────────────────────────
// Entry point
// ────────────────────────────────────────────────────────────────────────────

fn main() -> ExitCode {
    let cli = Cli::parse();

    // Subcomandos locales: operan sobre el sistema de archivos sin conectar al daemon.
    if let Comando::Translations { subcomando } = &cli.comando {
        return ejecutar_translations(subcomando, cli.quiet, cli.json);
    }

    // Subcomandos admin: requieren autenticación con contraseña antes de enviar al daemon.
    if let Comando::Admin { operacion } = &cli.comando {
        return ejecutar_admin(operacion, &cli.socket, &cli.ctx_id, cli.json, cli.quiet);
    }

    let ctx_id = cli.ctx_id.clone()
        .unwrap_or_else(|| Uuid::new_v4().to_string());

    let (method, params) = construir_llamada(&cli.comando, &ctx_id);

    match enviar_jsonrpc(&cli.socket, method, params) {
        Ok(resultado) => imprimir_ok(&resultado, cli.json, cli.quiet),
        Err(e)        => imprimir_error(&e, cli.quiet, cli.json),
    }
}

// ────────────────────────────────────────────────────────────────────────────
// Traducciones — operaciones locales (10.3)
// ────────────────────────────────────────────────────────────────────────────

/// Despacha subcomandos de translations (todos locales — sin daemon).
fn ejecutar_translations(
    subcomando: &ComandoTranslations,
    quiet: bool,
    json_mode: bool,
) -> ExitCode {
    match subcomando {
        ComandoTranslations::CheckParity { reference, locales_dir, fail_on_missing } =>
            verificar_paridad_claves(reference, locales_dir, *fail_on_missing, quiet, json_mode),
    }
}

/// Extrae los IDs de mensajes top-level de un archivo FTL.
/// Solo considera líneas que empiezan en columna 0 con un identificador seguido de '='.
/// Ignora: comentarios (#), términos (-), atributos (.attr), continuaciones (sangría).
fn extraer_claves_ftl(contenido: &str) -> HashSet<String> {
    let mut claves = HashSet::new();
    for linea in contenido.lines() {
        if linea.is_empty()
            || linea.starts_with('#')
            || linea.starts_with('-')
            || linea.starts_with(' ')
            || linea.starts_with('\t')
        {
            continue;
        }
        if let Some(pos) = linea.find('=') {
            let clave = linea[..pos].trim_end();
            // Solo IDs Fluent válidos: alfanumérico ASCII, guion y guion bajo
            if !clave.is_empty()
                && clave.chars().all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_')
            {
                claves.insert(clave.to_string());
            }
        }
    }
    claves
}

/// Compara claves FTL de todos los locales contra el locale de referencia.
/// Reporta claves faltantes por locale y retorna ExitCode::FAILURE si `fail_on_missing`.
fn verificar_paridad_claves(
    referencia: &str,
    directorio: &str,
    fail_on_missing: bool,
    quiet: bool,
    json_mode: bool,
) -> ExitCode {
    let archivo_ref = PathBuf::from(directorio).join(referencia).join("main.ftl");
    let contenido_ref = match fs::read_to_string(&archivo_ref) {
        Ok(c) => c,
        Err(e) => {
            if !quiet {
                eprintln!("[i18nctl] error: no se pudo leer '{}': {}", archivo_ref.display(), e);
            }
            return ExitCode::FAILURE;
        }
    };
    let claves_ref = extraer_claves_ftl(&contenido_ref);

    let entradas = match fs::read_dir(directorio) {
        Ok(e) => e,
        Err(e) => {
            if !quiet {
                eprintln!("[i18nctl] error: no se pudo leer directorio '{}': {}", directorio, e);
            }
            return ExitCode::FAILURE;
        }
    };

    let mut faltantes: Vec<(String, Vec<String>)> = Vec::new();
    for entrada in entradas.flatten() {
        let nombre = entrada.file_name().to_string_lossy().to_string();
        if nombre == referencia { continue; }
        if !entrada.file_type().map(|t| t.is_dir()).unwrap_or(false) { continue; }

        let archivo = entrada.path().join("main.ftl");
        if !archivo.exists() { continue; }

        let contenido = match fs::read_to_string(&archivo) {
            Ok(c) => c,
            Err(_) => continue,
        };
        let claves_locale = extraer_claves_ftl(&contenido);
        let mut ausentes: Vec<String> = claves_ref.difference(&claves_locale).cloned().collect();

        if !ausentes.is_empty() {
            ausentes.sort();
            faltantes.push((nombre, ausentes));
        }
    }

    if json_mode {
        let resultado = if faltantes.is_empty() {
            json!({ "ok": true, "referencia": referencia, "faltantes": {} })
        } else {
            let mapa: serde_json::Map<String, Value> = faltantes.iter()
                .map(|(locale, claves)| (locale.clone(), json!(claves)))
                .collect();
            json!({ "ok": false, "referencia": referencia, "faltantes": mapa })
        };
        println!("{}", serde_json::to_string_pretty(&resultado).unwrap_or_default());
    } else if !quiet {
        if faltantes.is_empty() {
            println!("paridad correcta — todos los locales tienen las mismas claves que '{}'", referencia);
        } else {
            eprintln!("claves faltantes respecto a '{}':", referencia);
            for (locale, claves) in &faltantes {
                eprintln!("  {} ({} clave(s)): {}", locale, claves.len(), claves.join(", "));
            }
        }
    }

    if !faltantes.is_empty() && fail_on_missing {
        ExitCode::FAILURE
    } else {
        ExitCode::SUCCESS
    }
}
