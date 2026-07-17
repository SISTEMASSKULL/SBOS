/// cli/admin_traducciones.rs — Subcomandos bi18n.admin.* para edición de traducciones (P4).
/// Requieren admin_token — se solicita contraseña al invocar desde i18nctl Admin.
use clap::Subcommand;
use serde_json::{json, Value};

#[derive(Subcommand, Debug)]
pub enum AdminTraducciones {
    /// Lista los locales disponibles en el fluent_dir del daemon.
    ListLocales,
    /// Lista todos los mensajes (id + texto) de un locale.
    ListMessages {
        #[arg(long, default_value = "es-BO")] locale: String,
    },
    /// Obtiene el texto de un ID de mensaje en un locale.
    GetMessage {
        #[arg(long, default_value = "es-BO")] locale: String,
        #[arg(long)] id: String,
    },
    /// Actualiza el texto de un ID en el FTL y recarga atómicamente.
    UpdateMessage {
        #[arg(long, default_value = "es-BO")] locale: String,
        #[arg(long)] id: String,
        #[arg(long)] text: String,
    },
}

/// Construye la llamada JSON-RPC incluyendo el admin_token (ya hasheado).
pub fn construir_llamada_con_token(
    sub: &AdminTraducciones,
    ctx_id: &str,
    admin_token: &str,
) -> (&'static str, Value) {
    match sub {
        AdminTraducciones::ListLocales => (
            "bi18n.admin.list_locales",
            json!({ "ctx_id": ctx_id }),
        ),
        AdminTraducciones::ListMessages { locale } => (
            "bi18n.admin.list_messages",
            json!({ "ctx_id": ctx_id, "locale": locale }),
        ),
        AdminTraducciones::GetMessage { locale, id } => (
            "bi18n.admin.get_message",
            json!({ "ctx_id": ctx_id, "locale": locale, "id": id }),
        ),
        AdminTraducciones::UpdateMessage { locale, id, text } => (
            "bi18n.admin.update_message",
            json!({
                "ctx_id": ctx_id,
                "locale": locale,
                "id": id,
                "text": text,
                "admin_token": admin_token,
            }),
        ),
    }
}
