/// domain/format_map.rs — Mapa estático de especificaciones de formato (GAP-04 resuelto).
/// Propósito: 18 códigos canónicos de display_format → FormatSpec.
///   - Inicializado una sola vez en el primer acceso (OnceLock).
///   - Los patrones son fijos en código (no CLDR dinámico — ICU4X solo para valores).
///   - ICU4X sigue usándose para FormatDate/FormatMoney; NOT para extracción de patrones.
/// Dependencias: std::sync::OnceLock (stdlib, sin deps externas)
use std::{collections::HashMap, sync::OnceLock};

/// Especificación de formato para un campo de datos.
#[derive(Debug, Clone)]
pub struct FormatSpec {
    /// Código único del formato. Ejemplo: "ID_BO", "E164", "TAX_BO"
    pub codigo: &'static str,
    /// Patrón de máscara con dígitos representados por '9' y letras por 'A'.
    /// Ejemplo: "9999999-AA" para CI boliviana.
    pub patron: &'static str,
    /// Expresión regular de validación del valor YA formateado.
    /// Vacía si la validación usa el país-specific (country-rules TOML).
    pub regex_validacion: &'static str,
    /// Descripción en español para mensajes de error.
    pub descripcion: &'static str,
}

/// Mapa global: código → FormatSpec. Inicializado una sola vez.
static FORMAT_MAP: OnceLock<HashMap<&'static str, FormatSpec>> = OnceLock::new();

/// Retorna referencia al mapa estático. Inicializa en el primer llamado.
pub fn mapa() -> &'static HashMap<&'static str, FormatSpec> {
    FORMAT_MAP.get_or_init(inicializar)
}

/// Obtiene la especificación de formato por código.
/// Retorna None si el código no está registrado.
pub fn obtener(codigo: &str) -> Option<&'static FormatSpec> {
    mapa().get(codigo)
}

/// Construye el mapa con los 18 formatos canónicos de bi18n.
fn inicializar() -> HashMap<&'static str, FormatSpec> {
    let mut m = HashMap::new();

    // ── Teléfonos ─────────────────────────────────────────────────────────
    insertar(&mut m, FormatSpec {
        codigo: "E164",
        patron: "+999 99 9999999",
        regex_validacion: r"^\+[1-9]\d{6,14}$",
        descripcion: "Número de teléfono internacional E.164",
    });
    insertar(&mut m, FormatSpec {
        codigo: "PHONE_LOCAL",
        patron: "99999999",
        regex_validacion: r"^\d{7,8}$",
        descripcion: "Número de teléfono local (sin código de país)",
    });

    // ── Documentos Bolivia ────────────────────────────────────────────────
    insertar(&mut m, FormatSpec {
        codigo: "ID_BO",
        patron: "9999999-AA",
        regex_validacion: r"^\d{5,8}-[A-Z]{2}$",
        descripcion: "Cédula de identidad boliviana (CI)",
    });
    insertar(&mut m, FormatSpec {
        codigo: "TAX_BO",
        patron: "9999-999999-999-99",
        regex_validacion: r"^\d{4}-\d{6}-\d{3}-\d{2}$",
        descripcion: "NIT boliviano (Número de Identificación Tributaria)",
    });

    // ── Documentos Argentina ──────────────────────────────────────────────
    insertar(&mut m, FormatSpec {
        codigo: "DNI_AR",
        patron: "99.999.999",
        regex_validacion: r"^\d{7,8}$",
        descripcion: "DNI argentino (Documento Nacional de Identidad)",
    });
    insertar(&mut m, FormatSpec {
        codigo: "CUIT_AR",
        patron: "99-99999999-9",
        regex_validacion: r"^\d{2}-\d{8}-\d{1}$",
        descripcion: "CUIT argentino (Clave Única de Identificación Tributaria)",
    });

    // ── Documentos Brasil ─────────────────────────────────────────────────
    insertar(&mut m, FormatSpec {
        codigo: "CPF_BR",
        patron: "999.999.999-99",
        regex_validacion: r"^\d{3}\.\d{3}\.\d{3}-\d{2}$",
        descripcion: "CPF brasileño (Cadastro de Pessoas Físicas)",
    });
    insertar(&mut m, FormatSpec {
        codigo: "CNPJ_BR",
        patron: "99.999.999/9999-99",
        regex_validacion: r"^\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}$",
        descripcion: "CNPJ brasileño (Cadastro Nacional da Pessoa Jurídica)",
    });

    // ── Pasaporte ─────────────────────────────────────────────────────────
    insertar(&mut m, FormatSpec {
        codigo: "PASSPORT",
        patron: "AA9999999",
        regex_validacion: r"^[A-Z]{1,2}\d{6,7}$",
        descripcion: "Pasaporte ICAO (formato general)",
    });

    // ── Fechas ────────────────────────────────────────────────────────────
    insertar(&mut m, FormatSpec {
        codigo: "DATE_ISO",
        patron: "9999-99-99",
        regex_validacion: r"^\d{4}-\d{2}-\d{2}$",
        descripcion: "Fecha en formato ISO 8601 (AAAA-MM-DD)",
    });
    insertar(&mut m, FormatSpec {
        codigo: "DATE_LOCAL_BO",
        patron: "99/99/9999",
        regex_validacion: r"^\d{2}/\d{2}/\d{4}$",
        descripcion: "Fecha en formato local boliviano (DD/MM/AAAA)",
    });

    // ── Moneda Bolivia ────────────────────────────────────────────────────
    insertar(&mut m, FormatSpec {
        codigo: "MONEY_BOB",
        patron: "Bs. 9.999,99",
        regex_validacion: "",
        descripcion: "Monto en Bolivianos (BOB)",
    });
    insertar(&mut m, FormatSpec {
        codigo: "MONEY_USD",
        patron: "$9,999.99",
        regex_validacion: "",
        descripcion: "Monto en Dólares americanos (USD)",
    });

    // ── Correo electrónico ────────────────────────────────────────────────
    insertar(&mut m, FormatSpec {
        codigo: "EMAIL",
        patron: "usuario@dominio.tld",
        regex_validacion: r"^[^@\s]+@[^@\s]+\.[^@\s]+$",
        descripcion: "Dirección de correo electrónico RFC 5321",
    });

    // ── Coordenadas GPS ───────────────────────────────────────────────────
    insertar(&mut m, FormatSpec {
        codigo: "GPS_LAT",
        patron: "-99.999999",
        regex_validacion: r"^-?\d{1,2}\.\d{1,6}$",
        descripcion: "Latitud GPS decimal",
    });
    insertar(&mut m, FormatSpec {
        codigo: "GPS_LON",
        patron: "-999.999999",
        regex_validacion: r"^-?\d{1,3}\.\d{1,6}$",
        descripcion: "Longitud GPS decimal",
    });

    // ── Código postal ─────────────────────────────────────────────────────
    insertar(&mut m, FormatSpec {
        codigo: "ZIP_BO",
        patron: "9999",
        regex_validacion: r"^\d{4}$",
        descripcion: "Código postal boliviano (4 dígitos)",
    });

    // ── Número general ────────────────────────────────────────────────────
    insertar(&mut m, FormatSpec {
        codigo: "INTEGER",
        patron: "9999999999",
        regex_validacion: r"^\d+$",
        descripcion: "Número entero positivo",
    });

    m
}

fn insertar(m: &mut HashMap<&'static str, FormatSpec>, spec: FormatSpec) {
    m.insert(spec.codigo, spec);
}
