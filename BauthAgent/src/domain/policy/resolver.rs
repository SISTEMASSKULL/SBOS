// ============================================================
// bauth::domain::policy::resolver — Resolución de referencias y helpers
//
// resolve_value(): reemplaza ${params.key} en valores JSON.
// resolve_conditions(): aplica resolución a un vector de condiciones.
// Helpers geo/red: haversine_km(), simple_cidr_match(), ip_to_u32().
// ============================================================

#![allow(dead_code)]
use super::condition::PolicyCondition;
use regex::Regex;
use std::collections::HashMap;

/// Resuelve referencias ${params.key} en un valor JSON.
///
/// Soporta:
///   - "${params.limit}" → valor directo del bloque params (string, número, array)
///   - Valores compuestos como "El límite es ${params.limit} BOB"
pub fn resolve_value(
    raw: &serde_json::Value,
    params: &HashMap<String, serde_json::Value>,
) -> serde_json::Value {
    match raw {
        serde_json::Value::String(s) => {
            let re = Regex::new(r"\$\{params\.([^}]+)\}").unwrap();
            if !re.is_match(s) {
                return raw.clone();
            }
            // Si el string COMPLETO es una referencia, devolver el valor resuelto (preservando tipo)
            if let Some(caps) = re.captures(s) {
                if caps.get(0).unwrap().as_str() == s.as_str() {
                    let key = caps.get(1).unwrap().as_str();
                    return params.get(key).cloned().unwrap_or(raw.clone());
                }
            }
            // Referencia parcial: reemplazar inline (solo strings)
            let resolved = re.replace_all(s, |caps: &regex::Captures| {
                let key = caps.get(1).unwrap().as_str();
                params
                    .get(key)
                    .and_then(|v| v.as_str().map(|s| s.to_string()))
                    .unwrap_or_else(|| caps.get(0).unwrap().as_str().to_string())
            });
            serde_json::Value::String(resolved.to_string())
        }
        _ => raw.clone(),
    }
}

/// Resuelve todas las referencias ${params.*} en un vector de condiciones.
pub fn resolve_conditions(
    conditions: &[PolicyCondition],
    params: &HashMap<String, serde_json::Value>,
) -> Vec<PolicyCondition> {
    conditions
        .iter()
        .map(|c| PolicyCondition {
            field: c.field.clone(),
            op: c.op.clone(),
            raw_value: resolve_value(&c.raw_value, params),
        })
        .collect()
}

// ─── Helpers numéricos y geo/red ────────────────────────────

/// Comparación numérica genérica. Intenta f64, luego parse desde string.
pub fn compare_numeric<F>(a: &serde_json::Value, b: &serde_json::Value, cmp: F) -> bool
where
    F: Fn(f64, f64) -> bool,
{
    let va = a.as_f64()
        .or_else(|| a.as_str().and_then(|s| s.parse().ok()))
        .unwrap_or(0.0);
    let vb = b.as_f64()
        .or_else(|| b.as_str().and_then(|s| s.parse().ok()))
        .unwrap_or(0.0);
    cmp(va, vb)
}

/// Distancia Haversine en kilómetros entre dos puntos (lat, lon) en grados.
pub fn haversine_km(lat1: f64, lon1: f64, lat2: f64, lon2: f64) -> f64 {
    const R: f64 = 6371.0;
    let dlat = (lat2 - lat1).to_radians();
    let dlon = (lon2 - lon1).to_radians();
    let a = (dlat / 2.0).sin().powi(2)
        + lat1.to_radians().cos() * lat2.to_radians().cos() * (dlon / 2.0).sin().powi(2);
    let c = 2.0 * a.sqrt().asin();
    R * c
}

/// Verificación CIDR simplificada (sin crate ipnet).
pub fn simple_cidr_match(ip_str: &str, cidr_str: &str) -> bool {
    let parts: Vec<&str> = cidr_str.split('/').collect();
    if parts.len() != 2 { return false; }
    let prefix_len: u8 = match parts[1].parse() {
        Ok(v) if v <= 32 => v,
        _ => return false,
    };
    let ip_int = ip_to_u32(ip_str);
    let net_int = ip_to_u32(parts[0]);
    if prefix_len == 0 { return true; }
    let mask = !0u32 << (32 - prefix_len);
    (ip_int & mask) == (net_int & mask)
}

pub fn ip_to_u32(ip: &str) -> u32 {
    let octets: Vec<u32> = ip.split('.').filter_map(|o| o.parse().ok()).collect();
    if octets.len() != 4 { return 0; }
    (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3]
}
