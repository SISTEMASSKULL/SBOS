/// bin/i18nctl.rs — CLI de administración del daemon bi18n.
/// Propósito: cliente JSON-RPC sobre Unix socket para operadores y scripts.
///   - Comunica con bi18nd por /run/bos/bi18n.sock (JSON-RPC 2.0, línea por conexión).
///   - Flags transversales: --json (JSON crudo), --quiet (solo exit code), --ctx-id.
///   - Exit codes: 0=ok, 1=respuesta inválida del dominio, 2=error daemon/conexión.
///   - ctx_id generado automáticamente (UUID v4) si no se pasa explícitamente (SBOS-049).
/// Dependencias: clap (CLI), serde_json (JSON-RPC), uuid (ctx_id), std::os::unix::net
use std::{
    io::{BufRead, BufReader, Write},
    os::unix::net::UnixStream,
    process::ExitCode,
    time::Duration,
};
use clap::{Parser, Subcommand};
use serde_json::{json, Value};
use uuid::Uuid;

// ────────────────────────────────────────────────────────────────────────────
// Definición CLI (clap derive)
// ────────────────────────────────────────────────────────────────────────────

/// i18nctl — administra el daemon bi18n del ecosistema SBOS.
#[derive(Parser, Debug)]
#[command(name = "i18nctl", about = "CLI de administración del daemon bi18n (SBOS i18n-orchestrator)")]
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
    }
}

// ────────────────────────────────────────────────────────────────────────────
// Entry point
// ────────────────────────────────────────────────────────────────────────────

fn main() -> ExitCode {
    let cli = Cli::parse();

    let ctx_id = cli.ctx_id.clone()
        .unwrap_or_else(|| Uuid::new_v4().to_string());

    let (method, params) = construir_llamada(&cli.comando, &ctx_id);

    match enviar_jsonrpc(&cli.socket, method, params) {
        Ok(resultado) => imprimir_ok(&resultado, cli.json, cli.quiet),
        Err(e)        => imprimir_error(&e, cli.quiet, cli.json),
    }
}
