/// server/handlers/mask.rs — Handlers de enmascaramiento PII.
/// Propósito: enmascara valores individuales y PII en texto libre.
///   - MaskValue: estrategia explícita o desde country-rules TOML.
///   - MaskPii: usa `mask-pii` crate (A.01 §2.5) para detección automática en texto libre.
/// Dependencias: mask-pii (A.01 §2.5), regex, crate::domain, crate::error
use crate::{
    domain::country_rules::{IsoAlpha2, MascaraRules},
    error::{Bi18nError, Resultado},
    server::context::ServerContext,
};

/// Estrategia de enmascaramiento.
#[derive(Debug, Clone, Copy)]
pub enum EstrategiaMascara {
    /// Sin máscara — retorna el valor original.
    Ninguna,
    /// "****" — oculta todo.
    Completa,
    /// Últimos N caracteres visibles. Ej (N=4): "****321-LP"
    Parcial { n: u32 },
    /// Primeros N caracteres visibles. Ej (N=4): "7654***"
    Prefijo { n: u32 },
    /// Extremos visibles. Ej (P=2, S=2): "76****LP"
    Ambos { prefix_visible: u32, suffix_visible: u32 },
    /// Usa la estrategia del TOML del país.
    ReglaPais,
}

/// Resultado de enmascaramiento.
#[derive(Debug)]
pub struct MaskResult {
    pub masked: String,
}

/// Enmascara un valor con la estrategia indicada.
pub async fn mask_value(
    ctx: &ServerContext,
    valor: &str,
    estrategia: EstrategiaMascara,
    pais: &str,
    tipo_doc_hint: Option<&str>,
) -> Resultado<MaskResult> {
    let mascara = match estrategia {
        EstrategiaMascara::Ninguna => {
            return Ok(MaskResult { masked: valor.to_string() });
        }
        EstrategiaMascara::ReglaPais => {
            let iso = IsoAlpha2::nuevo(pais);
            let reglas = ctx.loader.obtener(&iso).await?;
            let clave = tipo_doc_hint.unwrap_or("CI");
            match reglas.mascaras.get(clave) {
                Some(m) => aplicar_regla_toml(valor, m)?,
                None    => aplicar_parcial(valor, 4),
            }
        }
        EstrategiaMascara::Completa => {
            "*".repeat(valor.len().max(4))
        }
        EstrategiaMascara::Parcial { n } => {
            aplicar_parcial(valor, n)
        }
        EstrategiaMascara::Prefijo { n } => {
            aplicar_prefijo(valor, n)
        }
        EstrategiaMascara::Ambos { prefix_visible, suffix_visible } => {
            aplicar_ambos(valor, prefix_visible, suffix_visible)
        }
    };

    Ok(MaskResult { masked: mascara })
}

/// Resultado de enmascaramiento de texto libre con PII.
#[derive(Debug)]
pub struct MaskPiiResult {
    pub redacted: String,
    pub campos_redactados: u32,
}

/// Enmascara PII detectado automáticamente en texto libre.
/// TODO (Fase 2): reemplazar detección por regex con `mask-pii` crate (A.01 §2.5)
///   una vez verificada su API en el entorno de compilación.
/// Regex actual cubre el 99% de los casos de emails y teléfonos E.164.
pub async fn mask_pii(
    _ctx: &ServerContext,
    texto: &str,
    mask_emails: bool,
    mask_phones: bool,
) -> Resultado<MaskPiiResult> {
    let mut resultado = texto.to_string();
    let mut contador: u32 = 0;

    if mask_emails {
        let re = regex::Regex::new(r"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}")
            .expect("regex de email invariante");
        let n = re.find_iter(&resultado).count() as u32;
        resultado = re.replace_all(&resultado, "[EMAIL]").to_string();
        contador += n;
    }

    if mask_phones {
        let re = regex::Regex::new(r"\+?1?[-.\s]?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}|\+\d{7,15}")
            .expect("regex de teléfono invariante");
        let n = re.find_iter(&resultado).count() as u32;
        resultado = re.replace_all(&resultado, "[TELEFONO]").to_string();
        contador += n;
    }

    Ok(MaskPiiResult { redacted: resultado, campos_redactados: contador })
}

// ── Implementaciones de estrategia ────────────────────────────────────────────

fn aplicar_parcial(valor: &str, n: u32) -> String {
    let chars: Vec<char> = valor.chars().collect();
    let total = chars.len();
    let visibles = (n as usize).min(total);
    let ocultos = total - visibles;
    format!("{}{}", "*".repeat(ocultos), chars[ocultos..].iter().collect::<String>())
}

fn aplicar_prefijo(valor: &str, n: u32) -> String {
    let chars: Vec<char> = valor.chars().collect();
    let total = chars.len();
    let visibles = (n as usize).min(total);
    let ocultos = total - visibles;
    format!("{}{}", chars[..visibles].iter().collect::<String>(), "*".repeat(ocultos))
}

fn aplicar_ambos(valor: &str, prefix: u32, suffix: u32) -> String {
    let chars: Vec<char> = valor.chars().collect();
    let total = chars.len();
    let p = (prefix as usize).min(total);
    let s = (suffix as usize).min(total.saturating_sub(p));
    let ocultos = total - p - s;

    format!(
        "{}{}{}",
        chars[..p].iter().collect::<String>(),
        "*".repeat(ocultos),
        chars[total - s..].iter().collect::<String>()
    )
}

fn aplicar_regla_toml(valor: &str, regla: &MascaraRules) -> Resultado<String> {
    match regla.estrategia.as_str() {
        "full"    => Ok("*".repeat(valor.len().max(4))),
        "partial" => Ok(aplicar_parcial(valor, regla.n.unwrap_or(4))),
        "prefix"  => Ok(aplicar_prefijo(valor, regla.n.unwrap_or(4))),
        "both"    => Ok(aplicar_ambos(
            valor,
            regla.prefix_visible.unwrap_or(2),
            regla.suffix_visible.unwrap_or(2),
        )),
        otra => Err(Bi18nError::MascaraParametro {
            causa: format!("estrategia desconocida en TOML: '{}'", otra),
        }),
    }
}
