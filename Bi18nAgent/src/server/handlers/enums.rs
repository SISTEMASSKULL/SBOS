/// server/handlers/enums.rs — Handler de traducción de enums de negocio.
/// Propósito: traduce valores de enum canónicos a etiquetas localizadas.
///   - Los catálogos se cargan desde country-rules TOML (sección [enums]).
///   - Si no se encuentra: retorna el valor original como fallback.
///   - Ejemplo: ("gender", "M", es-BO) → "Masculino"
/// Dependencias: crate::server::context, crate::domain, crate::error
use crate::{error::Resultado, server::context::ServerContext};

/// Resultado de la traducción de enum.
#[derive(Debug)]
pub struct EnumDisplayResult {
    pub label: String,
    pub found: bool,
    pub fallback: String,
}

/// Traduce un valor de enum de negocio a su etiqueta localizada.
pub async fn display(
    _ctx: &ServerContext,
    enum_name: &str,
    valor: &str,
    locale: &str,
) -> Resultado<EnumDisplayResult> {
    // Catálogo embebido para los enums más frecuentes (Fase 2: desde TOML).
    let label = buscar_en_catalogo_embebido(enum_name, valor, locale);

    match label {
        Some(etiqueta) => Ok(EnumDisplayResult {
            label: etiqueta,
            found: true,
            fallback: String::new(),
        }),
        None => Ok(EnumDisplayResult {
            label: valor.to_string(),
            found: false,
            fallback: valor.to_string(),
        }),
    }
}

/// Busca la etiqueta en el catálogo embebido (MVP).
/// En Fase 2 se reemplaza por lectura desde los TOML de country-rules.
fn buscar_en_catalogo_embebido(enum_name: &str, valor: &str, locale: &str) -> Option<String> {
    let es = locale.starts_with("es");

    match (enum_name, valor) {
        ("gender", "M") | ("genero", "M")  => Some(if es { "Masculino" } else { "Male" }.to_string()),
        ("gender", "F") | ("genero", "F")  => Some(if es { "Femenino" } else { "Female" }.to_string()),
        ("gender", "O") | ("genero", "O")  => Some(if es { "Otro" } else { "Other" }.to_string()),

        ("marital_status", "SINGLE")   => Some(if es { "Soltero/a" } else { "Single" }.to_string()),
        ("marital_status", "MARRIED")  => Some(if es { "Casado/a" } else { "Married" }.to_string()),
        ("marital_status", "DIVORCED") => Some(if es { "Divorciado/a" } else { "Divorced" }.to_string()),
        ("marital_status", "WIDOWED")  => Some(if es { "Viudo/a" } else { "Widowed" }.to_string()),

        ("employment_type", "FULL_TIME")  => Some(if es { "Tiempo completo" } else { "Full-time" }.to_string()),
        ("employment_type", "PART_TIME")  => Some(if es { "Medio tiempo" } else { "Part-time" }.to_string()),
        ("employment_type", "FREELANCE")  => Some(if es { "Independiente" } else { "Freelance" }.to_string()),
        ("employment_type", "UNEMPLOYED") => Some(if es { "Desempleado/a" } else { "Unemployed" }.to_string()),

        ("status", "ACTIVE")    => Some(if es { "Activo" } else { "Active" }.to_string()),
        ("status", "INACTIVE")  => Some(if es { "Inactivo" } else { "Inactive" }.to_string()),
        ("status", "PENDING")   => Some(if es { "Pendiente" } else { "Pending" }.to_string()),
        ("status", "BLOCKED")   => Some(if es { "Bloqueado" } else { "Blocked" }.to_string()),
        ("status", "SUSPENDED") => Some(if es { "Suspendido" } else { "Suspended" }.to_string()),
        ("status", "ARCHIVED")  => Some(if es { "Archivado" } else { "Archived" }.to_string()),

        // ── Decisión XACML 3.0 §7.3 ────────────────────────────────────────────
        ("xacml_decision", "Permit") | ("decision", "Permit") => Some("Permit".to_string()),
        ("xacml_decision", "Deny")   | ("decision", "Deny")   => Some("Deny".to_string()),

        // ── Algoritmo de combinación XACML 3.0 §7.14 ───────────────────────────
        ("combining_algorithm", "deny-overrides")     => Some(if es { "Denegar prevalece" } else { "deny-overrides" }.to_string()),
        ("combining_algorithm", "permit-overrides")   => Some(if es { "Permitir prevalece" } else { "permit-overrides" }.to_string()),
        ("combining_algorithm", "first-applicable")   => Some(if es { "Primero aplicable" } else { "first-applicable" }.to_string()),
        ("combining_algorithm", "only-one-applicable")=> Some(if es { "Solo uno aplicable" } else { "only-one-applicable" }.to_string()),
        ("combining_algorithm", "deny-unless-permit") => Some(if es { "Denegar por defecto" } else { "deny-unless-permit" }.to_string()),
        ("combining_algorithm", "permit-unless-deny") => Some(if es { "Permitir por defecto" } else { "permit-unless-deny" }.to_string()),
        ("combining_algorithm", "aggregate-strictest")=> Some(if es { "Más estricto (bAuth)" } else { "aggregate-strictest" }.to_string()),

        // ── Operadores lógicos AtomLang ─────────────────────────────────────────
        ("op_logico", "AND")             => Some(if es { "Y (todos)" } else { "AND" }.to_string()),
        ("op_logico", "OR")              => Some(if es { "O (alguno)" } else { "OR" }.to_string()),
        ("op_logico", "NOT")             => Some(if es { "No (negación)" } else { "NOT" }.to_string()),
        ("op_logico", "MATCH_ALL")       => Some(if es { "Coincidencia total" } else { "MATCH_ALL" }.to_string()),
        ("op_logico", "FIRST_APPLICABLE")=> Some(if es { "Primero aplicable" } else { "FIRST_APPLICABLE" }.to_string()),

        // ── Operadores de comparación AtomLang ──────────────────────────────────
        ("operador", "==")             => Some("Igual a".to_string()),
        ("operador", "!=")             => Some("Distinto de".to_string()),
        ("operador", ">")              => Some("Mayor que".to_string()),
        ("operador", "<")              => Some("Menor que".to_string()),
        ("operador", ">=")             => Some("Mayor o igual".to_string()),
        ("operador", "<=")             => Some("Menor o igual".to_string()),
        ("operador", "IN")             => Some(if es { "Contenido en" } else { "In" }.to_string()),
        ("operador", "NOT_IN")         => Some(if es { "No contenido en" } else { "Not in" }.to_string()),
        ("operador", "BETWEEN")        => Some(if es { "Entre" } else { "Between" }.to_string()),
        ("operador", "SUBSET_OF")      => Some(if es { "Subconjunto de" } else { "Subset of" }.to_string()),
        ("operador", "INTERSECT")      => Some(if es { "Intersección con" } else { "Intersects" }.to_string()),
        ("operador", "INCLUDES_ALL")   => Some(if es { "Incluye todos" } else { "Includes all" }.to_string()),
        ("operador", "NOT_INCLUDES_ALL")=> Some(if es { "No incluye todos" } else { "Not includes all" }.to_string()),
        ("operador", "STARTS_WITH")    => Some(if es { "Comienza con" } else { "Starts with" }.to_string()),
        ("operador", "IS_SET")         => Some(if es { "Está definido" } else { "Is set" }.to_string()),
        ("operador", "visible_to_role")=> Some(if es { "Visible al rol" } else { "Visible to role" }.to_string()),
        ("operador", "max_access")     => Some(if es { "Acceso máximo" } else { "Max access" }.to_string()),

        // ── Verbos XACML (Action) ───────────────────────────────────────────────
        ("verbo", "read")      => Some(if es { "Leer" } else { "Read" }.to_string()),
        ("verbo", "write")     => Some(if es { "Escribir" } else { "Write" }.to_string()),
        ("verbo", "create")    => Some(if es { "Crear" } else { "Create" }.to_string()),
        ("verbo", "delete")    => Some(if es { "Eliminar" } else { "Delete" }.to_string()),
        ("verbo", "approve")   => Some(if es { "Aprobar" } else { "Approve" }.to_string()),
        ("verbo", "execute")   => Some(if es { "Ejecutar" } else { "Execute" }.to_string()),
        ("verbo", "export")    => Some(if es { "Exportar" } else { "Export" }.to_string()),
        ("verbo", "delegate")  => Some(if es { "Delegar" } else { "Delegate" }.to_string()),
        ("verbo", "configure") => Some(if es { "Configurar" } else { "Configure" }.to_string()),
        ("verbo", "audit")     => Some(if es { "Auditar" } else { "Audit" }.to_string()),
        ("verbo", "login")     => Some(if es { "Iniciar sesión" } else { "Login" }.to_string()),
        ("verbo", "emit")      => Some(if es { "Emitir" } else { "Emit" }.to_string()),
        ("verbo", "void")      => Some(if es { "Anular" } else { "Void" }.to_string()),
        ("verbo", "ANY")       => Some(if es { "Cualquier acción" } else { "Any action" }.to_string()),

        // ── LoA — Level of Assurance (NIST 800-63) ─────────────────────────────
        ("loa", "1") | ("level_of_assurance", "1") => Some(if es { "LoA 1 — Básico" } else { "LoA 1 — Low" }.to_string()),
        ("loa", "2") | ("level_of_assurance", "2") => Some(if es { "LoA 2 — Sustancial" } else { "LoA 2 — Moderate" }.to_string()),
        ("loa", "3") | ("level_of_assurance", "3") => Some(if es { "LoA 3 — Alto" } else { "LoA 3 — High" }.to_string()),
        ("loa", "4") | ("level_of_assurance", "4") => Some(if es { "LoA 4 — Muy alto" } else { "LoA 4 — Very high" }.to_string()),

        // ── Clasificación de datos (ISO 27001 A.5.12) ──────────────────────────
        ("classification", "PUBLIC")       => Some(if es { "Pública" } else { "Public" }.to_string()),
        ("classification", "INTERNAL")     => Some(if es { "Interna" } else { "Internal" }.to_string()),
        ("classification", "CONFIDENTIAL") => Some(if es { "Confidencial" } else { "Confidential" }.to_string()),
        ("classification", "SECRET")       => Some(if es { "Secreta" } else { "Secret" }.to_string()),
        ("classification", "TOP_SECRET")   => Some(if es { "Alto secreto" } else { "Top Secret" }.to_string()),

        // ── Impacto de seguridad ────────────────────────────────────────────────
        ("security_impact", "LOW")      => Some(if es { "Bajo" } else { "Low" }.to_string()),
        ("security_impact", "MEDIUM")   => Some(if es { "Medio" } else { "Medium" }.to_string()),
        ("security_impact", "HIGH")     => Some(if es { "Alto" } else { "High" }.to_string()),
        ("security_impact", "CRITICAL") => Some(if es { "Crítico" } else { "Critical" }.to_string()),

        // ── Tier de rol bAuth ───────────────────────────────────────────────────
        ("tier", "SU")        => Some("Super Usuario".to_string()),
        ("tier", "SYS")       => Some("Sistema".to_string()),
        ("tier", "BIZ_N1")    => Some("Negocio N1 — Operativo".to_string()),
        ("tier", "BIZ_N2")    => Some("Negocio N2 — Supervisión".to_string()),
        ("tier", "BIZ_N3")    => Some("Negocio N3 — Gerencial".to_string()),
        ("tier", "BIZ_N4")    => Some("Negocio N4 — Directivo".to_string()),
        ("tier", "BIZ_N5")    => Some("Negocio N5 — Ejecutivo".to_string()),
        ("tier", "EXT_N0")    => Some("Externo N0 — Certificado".to_string()),
        ("tier", "M2M")       => Some("Máquina a Máquina".to_string()),
        ("tier", "VISITANTE") => Some("Visitante".to_string()),

        // ── Algoritmo de firma digital ──────────────────────────────────────────
        ("algorithm", "EdDSA_Ed25519") => Some("EdDSA Ed25519 (Vault interno)".to_string()),
        ("algorithm", "EdDSA_Ed448")   => Some("EdDSA Ed448 (alta seguridad)".to_string()),
        ("algorithm", "RSA_SHA256")    => Some("RSA-SHA256 (ADSIB Bolivia)".to_string()),
        ("algorithm", "ECDSA_P256")    => Some("ECDSA P-256".to_string()),

        // ── AMR — Authentication Method Reference (RFC 8176) ───────────────────
        ("amr", "pwd")  => Some(if es { "Contraseña" } else { "Password" }.to_string()),
        ("amr", "otp")  => Some("OTP (TOTP/HOTP)".to_string()),
        ("amr", "mfa")  => Some(if es { "Multi-factor" } else { "Multi-factor" }.to_string()),
        ("amr", "fpt")  => Some(if es { "Biométrico (huella)" } else { "Fingerprint" }.to_string()),
        ("amr", "hwk")  => Some(if es { "Llave de hardware" } else { "Hardware key" }.to_string()),
        ("amr", "sc")   => Some(if es { "Tarjeta inteligente" } else { "Smart card" }.to_string()),
        ("amr", "pin")  => Some("PIN".to_string()),
        ("amr", "sms")  => Some("SMS OTP".to_string()),
        ("amr", "face") => Some(if es { "Reconocimiento facial" } else { "Face recognition" }.to_string()),
        ("amr", "iris") => Some(if es { "Iris" } else { "Iris scan" }.to_string()),
        ("amr", "push") => Some(if es { "Notificación push" } else { "Push notification" }.to_string()),

        // ── Requisito FIDO2 (resident_key / user_verification / authenticator) ──
        ("fido_requirement", "required")    | ("resident_key", "required")
        | ("user_verification", "required") => Some(if es { "Requerido" } else { "Required" }.to_string()),

        ("fido_requirement", "preferred")    | ("resident_key", "preferred")
        | ("user_verification", "preferred") => Some(if es { "Preferido" } else { "Preferred" }.to_string()),

        ("fido_requirement", "discouraged")    | ("resident_key", "discouraged")
        | ("user_verification", "discouraged") => Some(if es { "No recomendado" } else { "Discouraged" }.to_string()),

        // ── Adjunto de autenticador FIDO2 ──────────────────────────────────────
        ("authenticator_attachment", "platform")       => Some(if es { "Plataforma (biométrico)" } else { "Platform" }.to_string()),
        ("authenticator_attachment", "cross-platform") => Some(if es { "Multiplataforma (USB/NFC)" } else { "Cross-platform" }.to_string()),

        // ── Attestation FIDO2 ───────────────────────────────────────────────────
        ("attestation", "direct")   => Some(if es { "Directa" } else { "Direct" }.to_string()),
        ("attestation", "indirect") => Some(if es { "Indirecta" } else { "Indirect" }.to_string()),
        ("attestation", "none")     => Some(if es { "Sin attestation" } else { "None" }.to_string()),

        _ => None,
    }
}
