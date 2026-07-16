/// bin/i18nctl.rs — CLI de administración del daemon bi18n.
/// Propósito: interfaz de línea de comandos para operadores y scripts.
///   - Se comunica con bi18nd por el mismo Unix socket (JSON-RPC 2.0).
///   - No necesita socket propio — es un cliente del daemon activo.
///   - Fase 5: comandos avanzados con rat-input y clipass_rs.
/// Líneas: ≤ 50 (DOC-SBOS-001 N3).
use clap::{Parser, Subcommand};

/// i18nctl — CLI del daemon bi18n (SBOS i18n-orchestrator).
#[derive(Parser, Debug)]
#[command(name = "i18nctl", about = "Administra el daemon bi18n del ecosistema SBOS")]
struct Cli {
    /// Ruta al socket Unix del daemon (por defecto: /run/bos/bi18n.sock).
    #[arg(long, default_value = "/run/bos/bi18n.sock")]
    socket: String,

    #[command(subcommand)]
    comando: Comando,
}

#[derive(Subcommand, Debug)]
enum Comando {
    /// Verifica que el daemon está activo y responde.
    Estado,
    /// Solicita recarga de los country-rules TOML (equivale a SIGHUP).
    Recargar,
    /// Formatea una fecha en el locale del tenant.
    FormatFecha {
        #[arg(help = "Timestamp ISO 8601")]
        fecha: String,
        #[arg(long, default_value = "es-BO")]
        locale: String,
    },
    /// Valida y normaliza un documento de identidad.
    ValidarId {
        #[arg(help = "Valor del documento")]
        valor: String,
        #[arg(long, default_value = "CI", help = "Tipo: CI|NIT|DNI|CPF|CNPJ|CUIT|PASSPORT")]
        tipo: String,
        #[arg(long, default_value = "BO")]
        pais: String,
    },
}

fn main() {
    let cli = Cli::parse();
    // La ejecución real de comandos requiere bi18nd activo.
    // El despacho por socket se implementa en Fase 5.
    eprintln!("[i18nctl] socket: {} — comando: {:?}", cli.socket, cli.comando);
    eprintln!("[i18nctl] Fase 5 pendiente: comunicación con bi18nd por JSON-RPC sobre {:?}", cli.socket);
}
