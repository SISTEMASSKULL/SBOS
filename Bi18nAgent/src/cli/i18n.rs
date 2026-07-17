/// cli/i18n.rs — Subcomandos bi18n.i18n.* (A.08.02 rust-i18n, 4 métodos).
use clap::Subcommand;
use serde_json::{json, Value};

#[derive(Subcommand, Debug)]
pub enum I18n {
    /// Establece el locale activo del daemon (BCP 47).
    SetLocale {
        #[arg(long)] locale: String,
    },
    /// Devuelve el locale activo actual del daemon.
    LocaleActivo,
    /// Lista los locales disponibles compilados en el daemon.
    AvailableLocales,
    /// Establece el locale buscando por código de idioma (ej: "en").
    SetLocaleByLang {
        #[arg(long)] lang: String,
    },
}

pub fn construir_llamada(sub: &I18n, ctx_id: &str) -> (&'static str, Value) {
    match sub {
        I18n::SetLocale { locale } => (
            "bi18n.i18n.set_locale",
            json!({ "ctx_id": ctx_id, "locale": locale }),
        ),
        I18n::LocaleActivo => (
            "bi18n.i18n.locale_activo",
            json!({ "ctx_id": ctx_id }),
        ),
        I18n::AvailableLocales => (
            "bi18n.i18n.available_locales",
            json!({ "ctx_id": ctx_id }),
        ),
        I18n::SetLocaleByLang { lang } => (
            "bi18n.i18n.set_locale_by_lang",
            json!({ "ctx_id": ctx_id, "lang": lang }),
        ),
    }
}
