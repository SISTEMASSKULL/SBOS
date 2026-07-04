// ============================================================
// bauth::saga::actions::hibp — H-11 HIBP k-anonymity Screening
//
// Verifica passwords contra Have I Been Pwned usando k-anonymity.
// NIST SP 800-63B Rev.4 §5.1.1.2 obligatorio.
//
// Algoritmo:
//   1. SHA1(password) → hash hex uppercase
//   2. Enviar solo los primeros 5 chars a api.pwnedpasswords.com
//   3. El servidor devuelve sufijos + conteos
//   4. Comparar suffix localmente — la API NUNCA ve el password completo
// ============================================================
#![allow(dead_code)]
use sha1::{Sha1, Digest};
use tracing::warn;

/// Resultado del screening HIBP.
#[derive(Debug, Clone)]
pub struct HibpResult {
    pub breached: bool,
    pub count: Option<u64>,
    pub hash_prefix: String,
}

/// Verifica password contra HIBP usando k-anonymity.
/// `api_url` y `timeout_secs` provienen de `config::HibpConfig` (M-01).
pub async fn check_hibp(password: &str, api_url: &str, timeout_secs: u64) -> Result<HibpResult, String> {
    let hash = Sha1::digest(password.as_bytes());
    let hash_hex = hex::encode(hash).to_uppercase();
    let (prefix, suffix) = hash_hex.split_at(5);

    let url = format!("{}/{}", api_url, prefix);
    let client = reqwest::Client::builder()
        .user_agent(concat!("sbos-bauth-v", env!("CARGO_PKG_VERSION")))
        .timeout(std::time::Duration::from_secs(timeout_secs))
        .build()
        .map_err(|e| format!("error al crear cliente HTTP: {}", e))?;

    let response = client.get(&url).send().await
        .map_err(|e| format!("error de red al consultar HIBP: {}", e))?;

    let body = response.text().await
        .map_err(|e| format!("error al leer respuesta HIBP: {}", e))?;

    // Buscar suffix en la respuesta (formato: SUFFIX:COUNT por línea)
    let breached = body.lines().find_map(|line| {
        let parts: Vec<&str> = line.split(':').collect();
        if parts.len() == 2 && parts[0] == suffix {
            parts[1].trim().parse::<u64>().ok()
        } else {
            None
        }
    });

    match breached {
        Some(count) => {
            warn!(hash_prefix = %prefix, count, "password encontrado en base de datos de brechas");
            Ok(HibpResult { breached: true, count: Some(count), hash_prefix: prefix.to_string() })
        }
        None => Ok(HibpResult { breached: false, count: None, hash_prefix: prefix.to_string() }),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    #[ignore = "requiere conexión a internet (api.pwnedpasswords.com). Ejecutar con --ignored."]
    async fn test_common_password_is_breached() {
        // "password123" es uno de los passwords más comunes
        let cfg = crate::config::HibpConfig::default();
        let result = check_hibp("password123", &cfg.api_url, cfg.timeout_secs).await;
        // Si no hay conexión, el test no falla — es un test de integración opcional
        if let Ok(r) = result {
            assert!(r.breached, "password123 debería estar brechado");
        }
    }

    #[test]
    fn test_hash_format() {
        let hash = Sha1::digest(b"test");
        let hex_str = hex::encode(&hash).to_uppercase();
        assert_eq!(hex_str.len(), 40); // SHA1 produce 160 bits = 40 hex chars
    }
}
