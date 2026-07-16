/// domain/input_mask.rs — Derivación de máscaras de formulario desde locale BCP 47.
/// Propósito: traduce el patrón de fecha/hora CLDR implícito del locale a una
///   máscara de input compatible con los widgets del frontend (manual 1.01 §7.2).
///   Los patrones CLDR varían por familia de locale (es-*, en-US, ja-*, etc.).
///   La máscara resultante (ej: "99/99/9999") se expone vía bi18n.attr.config.
/// Dependencias: sin I/O, sin HTTP, sin DB — solo lógica de mapeo

/// Patrón de máscara de formulario para un campo de fecha.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InputMask {
    /// Máscara para widgets de formulario (99=dígito, A=letra, *=cualquiera).
    pub patron: &'static str,
    /// Orden de los componentes (para validación de rangos).
    pub orden: OrdenFecha,
}

/// Orden de presentación de los componentes de fecha en la máscara.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OrdenFecha {
    DiaMesAnio,
    MesDiaAnio,
    AnisMesDia,
}

/// Retorna la máscara de formulario para una fecha completa (dd/MM/yyyy o equivalente)
/// según el locale BCP 47. Usa la familia de locale para determinar el patrón CLDR.
///
/// Tabla de mapeo (basada en CLDR UTS #35 — locales principales de América Latina):
/// - `es-*`, `pt-*`, `fr-*`, `de-*`, `it-*` → "99/99/9999" (DMY)
/// - `en-US`                                 → "99/99/9999" (MDY)
/// - `en-CA`, `en-AU`, `en-GB`, `en-*`      → "99/99/9999" (DMY)
/// - `ja-*`, `zh-*`, `ko-*`                 → "9999/99/99" (YMD)
/// - default / ISO                           → "9999-99-99" (ISO 8601)
pub fn mascara_fecha(locale: &str) -> InputMask {
    let lang = locale.split('-').next().unwrap_or("und");
    let tag  = locale;

    // Familias con orden ISO (CLDR confirma: año primero)
    if matches!(lang, "ja" | "zh" | "ko" | "mn" | "hu") {
        return InputMask { patron: "9999/99/99", orden: OrdenFecha::AnisMesDia };
    }

    // en-US usa mes/día/año
    if tag == "en-US" {
        return InputMask { patron: "99/99/9999", orden: OrdenFecha::MesDiaAnio };
    }

    // Familias con día/mes/año (CLDR: español, portugués, francés, alemán, etc.)
    if matches!(lang, "es" | "pt" | "fr" | "de" | "it" | "nl" | "pl"
                    | "ru" | "uk" | "ar" | "tr" | "id" | "ms" | "vi")
    {
        return InputMask { patron: "99/99/9999", orden: OrdenFecha::DiaMesAnio };
    }

    // en-* y resto — día/mes/año (CLDR: la mayoría de locales fuera de en-US)
    if lang == "en" {
        return InputMask { patron: "99/99/9999", orden: OrdenFecha::DiaMesAnio };
    }

    // Fallback ISO 8601 (seguro para cualquier locale desconocido)
    InputMask { patron: "9999-99-99", orden: OrdenFecha::AnisMesDia }
}

/// Máscara de formulario para hora (HH:MM).
pub fn mascara_hora(_locale: &str) -> &'static str {
    "99:99"
}

/// Máscara de formulario para fecha+hora (date + " " + time).
pub fn mascara_fecha_hora(locale: &str) -> String {
    format!("{} {}", mascara_fecha(locale).patron, mascara_hora(locale))
}

/// Máscara de formulario para mes+año ("MM/yyyy" — mismo separador que fecha del locale).
pub fn mascara_mes_anio(locale: &str) -> &'static str {
    let lang = locale.split('-').next().unwrap_or("und");
    if matches!(lang, "ja" | "zh" | "ko" | "mn" | "hu") {
        "9999/99"
    } else {
        "99/9999"
    }
}

/// Máscara de formulario para solo año.
pub fn mascara_anio(_locale: &str) -> &'static str {
    "9999"
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mascara_fecha_bolivia() {
        let m = mascara_fecha("es-BO");
        assert_eq!(m.patron, "99/99/9999");
        assert_eq!(m.orden, OrdenFecha::DiaMesAnio);
    }

    #[test]
    fn test_mascara_fecha_eeuu() {
        let m = mascara_fecha("en-US");
        assert_eq!(m.patron, "99/99/9999");
        assert_eq!(m.orden, OrdenFecha::MesDiaAnio);
    }

    #[test]
    fn test_mascara_fecha_japon() {
        let m = mascara_fecha("ja-JP");
        assert_eq!(m.patron, "9999/99/99");
        assert_eq!(m.orden, OrdenFecha::AnisMesDia);
    }
}
