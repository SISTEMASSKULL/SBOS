// ============================================================
// bauth::domain::policy::condition — Operadores y condiciones
//
// Tipos atómicos del intérprete de políticas.
// CompareOp: 17 operadores de comparación (NIST ABAC / XACML 3.0).
// PolicyCondition: "campo operador valor".
// ============================================================

#![allow(dead_code)]
/// Operadores de comparación soportados por el intérprete.
#[derive(Debug, Clone, PartialEq)]
pub enum CompareOp {
    Eq,              // == igualdad exacta
    Ne,              // != distinto
    Gt,              // >  mayor que (numérico)
    Gte,             // >= mayor o igual (numérico)
    Lt,              // <  menor que (numérico)
    Lte,             // <= menor o igual (numérico)
    In,              // valor en lista
    NotIn,           // valor NO en lista
    Contains,        // string contiene substring
    Regex,           // match expresión regular
    Exists,          // campo existe en el contexto (no nulo)
    NotExists,       // campo NO existe en el contexto
    CidrMatch,       // IP dentro de rango CIDR
    GeoDistance,     // distancia geo < umbral (km)
    TimeBetween,     // hora actual entre [start, end]
    IpInRange,       // alias de CidrMatch
    StringLen,       // longitud de string >= valor
}

impl CompareOp {
    /// Convierte desde representación string (JSONB `op` field).
    /// Retorna error si el operador no es reconocido — no hay default silencioso.
    pub fn from_str(s: &str) -> Result<Self, String> {
        match s.to_lowercase().as_str() {
            "eq" | "==" | "equals"                 => Ok(CompareOp::Eq),
            "ne" | "neq" | "!=" | "not_equals"     => Ok(CompareOp::Ne),
            "gt" | ">"                             => Ok(CompareOp::Gt),
            "gte" | ">="                           => Ok(CompareOp::Gte),
            "lt" | "<"                             => Ok(CompareOp::Lt),
            "lte" | "<="                           => Ok(CompareOp::Lte),
            "in"                                   => Ok(CompareOp::In),
            "not_in" | "notin"                     => Ok(CompareOp::NotIn),
            "contains"                             => Ok(CompareOp::Contains),
            "regex" | "matches"                    => Ok(CompareOp::Regex),
            "exists"                               => Ok(CompareOp::Exists),
            "not_exists" | "notexists" | "missing" => Ok(CompareOp::NotExists),
            "cidr_match" | "cidrmatch" | "ip_in_range" | "ipinrange" => Ok(CompareOp::CidrMatch),
            "geo_distance" | "geodistance"         => Ok(CompareOp::GeoDistance),
            "time_between" | "timebetween"         => Ok(CompareOp::TimeBetween),
            "string_len" | "strlen" | "length"     => Ok(CompareOp::StringLen),
            other => {
                tracing::warn!(operator = %other, "operador desconocido — rechazando evaluación");
                Err(format!("operador desconocido: '{}'", other))
            }
        }
    }
}

/// Una condición atómica: "campo operador valor".
#[derive(Debug, Clone)]
pub struct PolicyCondition {
    /// Campo del contexto a evaluar (ej: "amount", "country", "now_hour").
    pub field: String,
    /// Operador de comparación.
    pub op: CompareOp,
    /// Valor de referencia. Puede contener referencias ${params.key}.
    pub raw_value: serde_json::Value,
}

/// Detalle de una condición evaluada (para auditoría).
#[derive(Debug, Clone)]
pub struct ConditionDetail {
    pub field: String,
    pub op: String,
    pub expected: serde_json::Value,
    pub actual: serde_json::Value,
    pub matched: bool,
}
