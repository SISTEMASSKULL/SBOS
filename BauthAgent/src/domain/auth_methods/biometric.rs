// ============================================================
// bauth::domain::auth_methods::biometric — Verificación Biométrica
//
// ARQUITECTURA (NIST SP 800-63B §5.2.3 · NIST SP 800-63-4 §8 · ISO/IEC 30107-3):
//   bhnexus (motor de borde) captura la muestra, realiza el PAD y ejecuta la
//   comparación template vs muestra. bAuth recibe SOLO el resultado estructurado
//   (BiometricMatchResult). El binario biométrico NUNCA entra a bAuth.
//
//   bAuth verifica:
//     1. Integridad del template (template_hash vs T-568)
//     2. Revocación del template
//     3. Tipo biométrico compatible
//     4. Liveness / PAD superado (ISO/IEC 30107-3)
//     5. FMR ≤ umbral NIST (0.001 AAL2 / 0.00001 AAL3)
//     6. Calidad de captura ≥ umbral cfg_policy_library
//     7. Límite de intentos (≤ 10 per NIST 800-63B §5.2.3)
//     8. Score de coincidencia aceptable
//
// Módulo puro: SIN I/O, SIN DB, SIN HTTP. DOC-SBOS-001 N3.
// T-568 · cfg_policy_library · ADR-010
// ============================================================

use super::{AuthMethod, AuthMethodError, EnrollResult, ValidateResult};
use async_trait::async_trait;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// ── §1 Tipos de biometría y nivel PAD ────────────────────────

/// Modalidad biométrica — sincronizada con CHECK de T-568.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum BiometricType {
    Fingerprint,
    Face,
    Iris,
    Voice,
    Vein,
    Palm,
}

impl BiometricType {
    /// Representación como string para logs y auditoría.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Fingerprint => "FINGERPRINT",
            Self::Face        => "FACE",
            Self::Iris        => "IRIS",
            Self::Voice       => "VOICE",
            Self::Vein        => "VEIN",
            Self::Palm        => "PALM",
        }
    }
}

/// Nivel de detección de ataque de presentación (ISO/IEC 30107-3).
/// - A: sin certificación PAD (solo indicativo)
/// - B: anti-spoofing certificado (NIST 800-63B AAL2 mínimo)
/// - C: alta seguridad, certificado contra especies específicas (AAL3)
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum PadLevel {
    A,
    B,
    C,
}

// ── §2 Tipos de datos de entrada/salida ──────────────────────

/// Resultado que bhnexus envía a bAuth tras comparar muestra vs template.
/// bhnexus realiza la comparación real; bAuth valida este struct.
#[derive(Debug, Clone, Deserialize)]
pub struct BiometricMatchResult {
    /// UUID del template en T-568 (para buscar el registro en la BD).
    pub template_id: Uuid,
    /// Tipo biométrico que bhnexus usó para la comparación.
    pub biometric_type: BiometricType,
    /// Puntuación de similitud normalizada: 0.0 (ninguna coincidencia) — 1.0 (idéntico).
    pub match_score: f32,
    /// False Match Rate calculada por el matcher de bhnexus.
    pub fmr: f64,
    /// Indica si la prueba de vida (PAD) fue superada.
    pub liveness_passed: bool,
    /// Puntuación de liveness: 0.0-1.0 (opcional según sensor).
    pub liveness_score: Option<f32>,
    /// Nivel PAD alcanzado por el sensor/matcher.
    pub pad_level: PadLevel,
    /// SHA-256 del template que bhnexus usó para comparar.
    /// bAuth verifica que coincida con template_hash en T-568.
    pub template_hash_from_edge: String,
    /// Fabricante del sensor (para auditoría).
    pub sensor_make: Option<String>,
    /// Modelo del sensor (para auditoría).
    pub sensor_model: Option<String>,
    /// Calidad de la muestra capturada (0.0-100.0, ISO/IEC 19795-1).
    pub quality_score: f32,
    /// Identificador de contexto de la operación (SBOS-049).
    pub ctx_id: String,
}

/// Registro del template almacenado en T-568 que la capa de BD carga para bAuth.
#[derive(Debug, Clone, Deserialize)]
pub struct BiometricTemplateRecord {
    /// UUID primario de T-568.
    pub template_id: Uuid,
    /// FK a auth_credential.
    pub credential_id: Uuid,
    /// Tipo biométrico registrado.
    pub biometric_type: BiometricType,
    /// SHA-256 del template procesado (nunca el template en claro).
    pub template_hash: String,
    /// Ruta en Vault transit donde vive el template cifrado AES-256-GCM.
    pub vault_path: String,
    /// Versión de la clave Vault (para re-cifrado rotatorio).
    pub vault_key_version: i32,
    /// Calidad del template en el enrolamiento (0.0-100.0).
    pub quality_score: Option<f32>,
    /// Si está presente, el template fue revocado en esta fecha.
    pub revoked_at: Option<DateTime<Utc>>,
}

/// Política de verificación biométrica (cargada desde cfg_policy_library).
#[derive(Debug, Clone)]
pub struct BiometricPolicy {
    /// Calidad mínima de captura (default 70.0, umbral NIST IQF).
    pub min_quality_score: f32,
    /// FMR máxima permitida (0.001 para AAL2, 0.00001 para AAL3).
    pub max_fmr: f64,
    /// Máximo de intentos fallidos antes de bloquear (NIST 800-63B §5.2.3: 10).
    pub max_attempts: u32,
    /// Liveness/PAD obligatorio (true siempre para AAL2+).
    pub require_liveness: bool,
    /// Nivel AAL exigido por la política del tenant.
    pub aal_required: u8,
}

impl Default for BiometricPolicy {
    /// Configuración por defecto — AAL2 según NIST 800-63B §5.2.3.
    fn default() -> Self {
        Self {
            min_quality_score: 70.0,
            max_fmr: 0.001,
            max_attempts: 10,
            require_liveness: true,
            aal_required: 2,
        }
    }
}

/// Resultado de una verificación biométrica exitosa.
#[derive(Debug, Clone, Serialize)]
pub struct BiometricVerifyResult {
    /// Verificación aprobada.
    pub verificado: bool,
    /// UUID del template en T-568.
    pub template_id: Uuid,
    /// Tipo biométrico verificado.
    pub biometric_type: BiometricType,
    /// Score de coincidencia del matcher.
    pub match_score: f32,
    /// FMR efectiva de la comparación.
    pub fmr: f64,
    /// AAL satisfecho por esta verificación.
    pub aal_satisfecho: u8,
    /// Liveness superado.
    pub liveness_passed: bool,
    /// Nivel PAD alcanzado.
    pub pad_level: PadLevel,
    /// ctx_id de la operación (SBOS-049).
    pub ctx_id: String,
}

/// Registro de enrolamiento para persistir en T-568 (lo devuelve validar_enrolamiento).
#[derive(Debug, Clone, Serialize)]
pub struct EnrollRecord {
    /// Tipo biométrico a registrar.
    pub biometric_type: BiometricType,
    /// SHA-256 del template procesado (recibido de bhnexus).
    pub template_hash: String,
    /// Ruta Vault transit (recibida de bhnexus).
    pub vault_path: String,
    /// Calidad validada del template.
    pub quality_score: f32,
}

// ── §3 Errores de verificación biométrica ────────────────────

/// Errores específicos de la verificación biométrica, en español.
#[derive(Debug, thiserror::Error)]
pub enum BiometricError {
    #[error("template {template_id} revocado — no se permite verificar")]
    TemplateRevocado { template_id: Uuid },

    #[error("tipo incompatible — esperado={esperado} recibido={recibido}")]
    TipoIncompatible { esperado: String, recibido: String },

    #[error("integridad comprometida — hash del edge no coincide con T-568")]
    HashIncompatible,

    #[error("hash inválido — debe ser SHA-256 (64 caracteres hex)")]
    HashInvalido,

    #[error("vault_path vacío — el template no tiene ruta Vault válida")]
    VaultPathVacio,

    #[error("límite de intentos excedido ({intentos}/{maximo})")]
    LimiteIntentosExcedido { intentos: u32, maximo: u32 },

    #[error("calidad de captura insuficiente ({score:.1} < mínimo {minimo:.1})")]
    CalidadInsuficiente { score: f32, minimo: f32 },

    #[error("prueba de vida (liveness/PAD) no superada")]
    LivenessFallido,

    #[error("FMR demasiado alto ({fmr:.6} > máximo permitido {maximo:.6})")]
    FmrExcedido { fmr: f64, maximo: f64 },

    #[error("sin coincidencia — score={score:.3} por debajo del umbral mínimo")]
    SinCoincidencia { score: f32 },
}

// ── §4 Verificación — lógica pura ────────────────────────────

/// Verifica el resultado que bhnexus envió contra la política y el template en T-568.
///
/// Parámetros:
///   result           — resultado del matcher de bhnexus
///   template         — registro cargado de T-568 (template_hash, revoked_at, etc.)
///   policy           — política activa del tenant (de cfg_policy_library)
///   current_attempts — intentos fallidos acumulados en la sesión actual
///
/// Retorna BiometricVerifyResult si todos los controles pasan, o BiometricError en caso contrario.
pub fn verify(
    result: &BiometricMatchResult,
    template: &BiometricTemplateRecord,
    policy: &BiometricPolicy,
    current_attempts: u32,
) -> Result<BiometricVerifyResult, BiometricError> {
    verificar_template_activo(template)?;
    verificar_tipo_compatible(result, template)?;
    verificar_integridad_hash(result, template)?;
    verificar_limite_intentos(current_attempts, policy)?;
    verificar_calidad(result.quality_score, policy)?;
    verificar_liveness(result.liveness_passed, policy)?;
    verificar_fmr(result.fmr, policy)?;
    verificar_score(result.match_score)?;

    Ok(BiometricVerifyResult {
        verificado: true,
        template_id: template.template_id,
        biometric_type: result.biometric_type.clone(),
        match_score: result.match_score,
        fmr: result.fmr,
        aal_satisfecho: policy.aal_required,
        liveness_passed: result.liveness_passed,
        pad_level: result.pad_level.clone(),
        ctx_id: result.ctx_id.clone(),
    })
}

/// El template no debe estar revocado (revoked_at presente).
fn verificar_template_activo(template: &BiometricTemplateRecord) -> Result<(), BiometricError> {
    if template.revoked_at.is_some() {
        return Err(BiometricError::TemplateRevocado { template_id: template.template_id });
    }
    Ok(())
}

/// El tipo biométrico del resultado debe coincidir con el del template registrado.
fn verificar_tipo_compatible(
    result: &BiometricMatchResult,
    template: &BiometricTemplateRecord,
) -> Result<(), BiometricError> {
    if result.biometric_type != template.biometric_type {
        return Err(BiometricError::TipoIncompatible {
            esperado: template.biometric_type.as_str().to_string(),
            recibido: result.biometric_type.as_str().to_string(),
        });
    }
    Ok(())
}

/// Verifica integridad: el hash que bhnexus usó debe coincidir con el almacenado en T-568.
/// Esto asegura que bhnexus comparó contra el template correcto y no fue alterado.
fn verificar_integridad_hash(
    result: &BiometricMatchResult,
    template: &BiometricTemplateRecord,
) -> Result<(), BiometricError> {
    if result.template_hash_from_edge != template.template_hash {
        return Err(BiometricError::HashIncompatible);
    }
    Ok(())
}

/// NIST 800-63B §5.2.3: no más de `policy.max_attempts` intentos fallidos consecutivos.
fn verificar_limite_intentos(current_attempts: u32, policy: &BiometricPolicy) -> Result<(), BiometricError> {
    if current_attempts >= policy.max_attempts {
        return Err(BiometricError::LimiteIntentosExcedido {
            intentos: current_attempts,
            maximo: policy.max_attempts,
        });
    }
    Ok(())
}

/// Calidad de la muestra capturada debe superar el umbral de cfg_policy_library.
fn verificar_calidad(quality_score: f32, policy: &BiometricPolicy) -> Result<(), BiometricError> {
    if quality_score < policy.min_quality_score {
        return Err(BiometricError::CalidadInsuficiente {
            score: quality_score,
            minimo: policy.min_quality_score,
        });
    }
    Ok(())
}

/// ISO/IEC 30107-3: la prueba de vida es obligatoria para AAL2+ (require_liveness=true).
fn verificar_liveness(liveness_passed: bool, policy: &BiometricPolicy) -> Result<(), BiometricError> {
    if policy.require_liveness && !liveness_passed {
        return Err(BiometricError::LivenessFallido);
    }
    Ok(())
}

/// NIST 800-63B §5.2.3: FMR ≤ 0.001 (AAL2) o ≤ 0.00001 (AAL3).
fn verificar_fmr(fmr: f64, policy: &BiometricPolicy) -> Result<(), BiometricError> {
    if fmr > policy.max_fmr {
        return Err(BiometricError::FmrExcedido { fmr, maximo: policy.max_fmr });
    }
    Ok(())
}

/// Score de coincidencia debe ser ≥ 0.5 (umbral mínimo conservador; el FMR ya garantiza el umbral real).
fn verificar_score(match_score: f32) -> Result<(), BiometricError> {
    if match_score < 0.5 {
        return Err(BiometricError::SinCoincidencia { score: match_score });
    }
    Ok(())
}

// ── §5 Enrolamiento — lógica pura ────────────────────────────

/// Valida los datos de un nuevo enrolamiento biométrico antes de persistir en T-568.
///
/// bhnexus envía: biometric_type + template_hash + vault_path + quality_score.
/// bAuth valida y retorna EnrollRecord para que la capa DB lo inserte en T-568.
///
/// Retorna EnrollRecord si la validación pasa, o BiometricError en caso contrario.
pub fn validar_enrolamiento(
    biometric_type: BiometricType,
    template_hash: &str,
    vault_path: &str,
    quality_score: f32,
    policy: &BiometricPolicy,
) -> Result<EnrollRecord, BiometricError> {
    verificar_calidad(quality_score, policy)?;
    verificar_template_hash_formato(template_hash)?;
    verificar_vault_path(vault_path)?;

    Ok(EnrollRecord {
        biometric_type,
        template_hash: template_hash.to_string(),
        vault_path: vault_path.to_string(),
        quality_score,
    })
}

/// El hash del template debe ser SHA-256: exactamente 64 caracteres hexadecimales.
fn verificar_template_hash_formato(template_hash: &str) -> Result<(), BiometricError> {
    if template_hash.len() != 64 || !template_hash.chars().all(|c| c.is_ascii_hexdigit()) {
        return Err(BiometricError::HashInvalido);
    }
    Ok(())
}

/// El vault_path no puede estar vacío.
fn verificar_vault_path(vault_path: &str) -> Result<(), BiometricError> {
    if vault_path.trim().is_empty() {
        return Err(BiometricError::VaultPathVacio);
    }
    Ok(())
}

// ── §6 AuthMethod trait ──────────────────────────────────────

/// Método de autenticación biométrico — implementa el trait AuthMethod.
///
/// El input de validate() es JSON con dos claves:
///   - "match_result": BiometricMatchResult (enviado por bhnexus)
///   - "template_record": BiometricTemplateRecord (cargado de T-568 por la capa DB)
///   - "current_attempts": número de intentos fallidos en la sesión actual
pub struct BiometricAuthMethod {
    policy: BiometricPolicy,
}

impl BiometricAuthMethod {
    /// Crea el método con la política indicada (cargada desde cfg_policy_library).
    pub fn new(policy: BiometricPolicy) -> Self {
        Self { policy }
    }

    /// Crea el método con la política por defecto (AAL2, FMR ≤ 0.001).
    pub fn with_default_policy() -> Self {
        Self { policy: BiometricPolicy::default() }
    }
}

#[async_trait]
impl AuthMethod for BiometricAuthMethod {
    fn method_id(&self) -> &str { "BAUTH_BIOMETRIC" }

    fn method_name(&self) -> &str { "Biometría (Huella/Rostro/Iris/Voz/Vena/Palma)" }

    /// AAL base = 2 (FMR ≤ 0.001 + liveness). La política puede exigir AAL3.
    fn aal_level(&self) -> u8 { self.policy.aal_required }

    fn standard_ref(&self) -> &str {
        "NIST SP 800-63B §5.2.3 · NIST SP 800-63-4 §8 · ISO/IEC 30107-3 · T-568"
    }

    /// Valida el resultado enviado por bhnexus.
    /// input esperado: { "match_result": {...}, "template_record": {...}, "current_attempts": N }
    async fn validate(&self, input: &serde_json::Value) -> Result<ValidateResult, AuthMethodError> {
        let match_result: BiometricMatchResult = serde_json::from_value(
            input["match_result"].clone(),
        ).map_err(|e| AuthMethodError::MissingParam {
            method: "BAUTH_BIOMETRIC".into(),
            param: format!("match_result inválido: {e}"),
        })?;

        let template: BiometricTemplateRecord = serde_json::from_value(
            input["template_record"].clone(),
        ).map_err(|e| AuthMethodError::MissingParam {
            method: "BAUTH_BIOMETRIC".into(),
            param: format!("template_record inválido: {e}"),
        })?;

        let attempts = input["current_attempts"].as_u64().unwrap_or(0) as u32;

        match verify(&match_result, &template, &self.policy, attempts) {
            Ok(r) => Ok(ValidateResult {
                valid: true,
                method_id: "BAUTH_BIOMETRIC".into(),
                message: format!(
                    "biometría {} verificada — score={:.3} FMR={:.6} AAL{}",
                    r.biometric_type.as_str(), r.match_score, r.fmr, r.aal_satisfecho
                ),
                aal_satisfied: r.aal_satisfecho,
            }),
            Err(e) => Err(AuthMethodError::InvalidCredentials {
                method: format!("BAUTH_BIOMETRIC: {e}"),
            }),
        }
    }

    /// Valida los datos de enrolamiento recibidos de bhnexus antes de persistir en T-568.
    /// params esperado: { "biometric_type": "FINGERPRINT", "template_hash": "...", "vault_path": "...", "quality_score": 85.0 }
    async fn enroll(
        &self,
        user_uuid: &str,
        params: &serde_json::Value,
    ) -> Result<EnrollResult, AuthMethodError> {
        let biometric_type: BiometricType = serde_json::from_value(
            params["biometric_type"].clone(),
        ).map_err(|e| AuthMethodError::MissingParam {
            method: "BAUTH_BIOMETRIC".into(),
            param: format!("biometric_type inválido: {e}"),
        })?;

        let template_hash = params["template_hash"].as_str()
            .ok_or_else(|| AuthMethodError::MissingParam {
                method: "BAUTH_BIOMETRIC".into(),
                param: "template_hash".into(),
            })?;

        let vault_path = params["vault_path"].as_str()
            .ok_or_else(|| AuthMethodError::MissingParam {
                method: "BAUTH_BIOMETRIC".into(),
                param: "vault_path".into(),
            })?;

        let quality_score = params["quality_score"].as_f64()
            .ok_or_else(|| AuthMethodError::MissingParam {
                method: "BAUTH_BIOMETRIC".into(),
                param: "quality_score".into(),
            })? as f32;

        validar_enrolamiento(biometric_type, template_hash, vault_path, quality_score, &self.policy)
            .map_err(|e| AuthMethodError::Internal {
                method: "BAUTH_BIOMETRIC".into(),
                message: e.to_string(),
            })?;

        Ok(EnrollResult {
            enrolled: true,
            method_id: "BAUTH_BIOMETRIC".into(),
            instance_id: user_uuid.to_string(),
            secret_preview: None,
            message: format!("template biométrico validado — vault_path={vault_path}"),
        })
    }

    async fn revoke(&self, _user_uuid: &str, _method_instance_id: &str) -> Result<(), AuthMethodError> {
        // La revocación actualiza revoked_at en T-568 — operación de la capa DB.
        // El dominio acepta siempre la solicitud (la persistencia es responsabilidad del servicio).
        Ok(())
    }

    async fn health_check(&self) -> bool { true }
}

// ── §7 Tests ─────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    /// Construye un BiometricMatchResult válido para tests.
    fn match_result_valido() -> BiometricMatchResult {
        BiometricMatchResult {
            template_id: Uuid::new_v4(),
            biometric_type: BiometricType::Fingerprint,
            match_score: 0.92,
            fmr: 0.0003,
            liveness_passed: true,
            liveness_score: Some(0.98),
            pad_level: PadLevel::B,
            template_hash_from_edge: "a".repeat(64),
            sensor_make: Some("TestSensor".into()),
            sensor_model: Some("TS-100".into()),
            quality_score: 85.0,
            ctx_id: "ctx-test-001".into(),
        }
    }

    /// Construye un BiometricTemplateRecord activo para tests.
    fn template_activo() -> BiometricTemplateRecord {
        BiometricTemplateRecord {
            template_id: Uuid::new_v4(),
            credential_id: Uuid::new_v4(),
            biometric_type: BiometricType::Fingerprint,
            template_hash: "a".repeat(64),
            vault_path: "bauth/biometric/fingerprint/usr-001".into(),
            vault_key_version: 1,
            quality_score: Some(85.0),
            revoked_at: None,
        }
    }

    #[test]
    fn test_verificacion_exitosa() {
        let result = match_result_valido();
        let template = template_activo();
        let policy = BiometricPolicy::default();
        assert!(verify(&result, &template, &policy, 0).is_ok());
    }

    #[test]
    fn test_template_revocado_rechaza() {
        let result = match_result_valido();
        let mut template = template_activo();
        template.revoked_at = Some(Utc::now());
        let policy = BiometricPolicy::default();
        assert!(matches!(
            verify(&result, &template, &policy, 0),
            Err(BiometricError::TemplateRevocado { .. })
        ));
    }

    #[test]
    fn test_tipo_incompatible_rechaza() {
        let mut result = match_result_valido();
        result.biometric_type = BiometricType::Face;
        let template = template_activo(); // template es FINGERPRINT
        let policy = BiometricPolicy::default();
        assert!(matches!(
            verify(&result, &template, &policy, 0),
            Err(BiometricError::TipoIncompatible { .. })
        ));
    }

    #[test]
    fn test_hash_incompatible_rechaza() {
        let mut result = match_result_valido();
        result.template_hash_from_edge = "b".repeat(64); // diferente al template
        let template = template_activo(); // template tiene "a" * 64
        let policy = BiometricPolicy::default();
        assert!(matches!(
            verify(&result, &template, &policy, 0),
            Err(BiometricError::HashIncompatible)
        ));
    }

    #[test]
    fn test_limite_intentos_rechaza() {
        let result = match_result_valido();
        let template = template_activo();
        let policy = BiometricPolicy::default(); // max_attempts = 10
        assert!(matches!(
            verify(&result, &template, &policy, 10),
            Err(BiometricError::LimiteIntentosExcedido { .. })
        ));
    }

    #[test]
    fn test_calidad_insuficiente_rechaza() {
        let mut result = match_result_valido();
        result.quality_score = 50.0;
        let template = template_activo();
        let policy = BiometricPolicy::default(); // min_quality_score = 70.0
        assert!(matches!(
            verify(&result, &template, &policy, 0),
            Err(BiometricError::CalidadInsuficiente { .. })
        ));
    }

    #[test]
    fn test_liveness_fallido_rechaza() {
        let mut result = match_result_valido();
        result.liveness_passed = false;
        let template = template_activo();
        let policy = BiometricPolicy::default(); // require_liveness = true
        assert!(matches!(
            verify(&result, &template, &policy, 0),
            Err(BiometricError::LivenessFallido)
        ));
    }

    #[test]
    fn test_fmr_excedido_rechaza() {
        let mut result = match_result_valido();
        result.fmr = 0.005; // > 0.001 (AAL2 máximo)
        let template = template_activo();
        let policy = BiometricPolicy::default();
        assert!(matches!(
            verify(&result, &template, &policy, 0),
            Err(BiometricError::FmrExcedido { .. })
        ));
    }

    #[test]
    fn test_score_bajo_rechaza() {
        let mut result = match_result_valido();
        result.match_score = 0.3;
        let template = template_activo();
        let policy = BiometricPolicy::default();
        assert!(matches!(
            verify(&result, &template, &policy, 0),
            Err(BiometricError::SinCoincidencia { .. })
        ));
    }

    #[test]
    fn test_fmr_aal3_mas_estricto() {
        let mut result = match_result_valido();
        result.fmr = 0.00005; // pasa AAL2 (0.001) pero falla AAL3 (0.00001)
        let template = template_activo();
        let policy = BiometricPolicy { max_fmr: 0.00001, aal_required: 3, ..Default::default() };
        assert!(matches!(
            verify(&result, &template, &policy, 0),
            Err(BiometricError::FmrExcedido { .. })
        ));
    }

    #[test]
    fn test_enrolamiento_valido() {
        let policy = BiometricPolicy::default();
        let result = validar_enrolamiento(
            BiometricType::Iris,
            &"c".repeat(64),
            "bauth/biometric/iris/usr-002",
            80.0,
            &policy,
        );
        assert!(result.is_ok());
        assert_eq!(result.unwrap().biometric_type, BiometricType::Iris);
    }

    #[test]
    fn test_enrolamiento_hash_corto_falla() {
        let policy = BiometricPolicy::default();
        assert!(matches!(
            validar_enrolamiento(BiometricType::Face, "abc123", "vault/path", 85.0, &policy),
            Err(BiometricError::HashInvalido)
        ));
    }

    #[test]
    fn test_enrolamiento_vault_vacio_falla() {
        let policy = BiometricPolicy::default();
        assert!(matches!(
            validar_enrolamiento(BiometricType::Face, &"d".repeat(64), "  ", 85.0, &policy),
            Err(BiometricError::VaultPathVacio)
        ));
    }

    #[test]
    fn test_biometric_type_as_str() {
        assert_eq!(BiometricType::Fingerprint.as_str(), "FINGERPRINT");
        assert_eq!(BiometricType::Face.as_str(), "FACE");
        assert_eq!(BiometricType::Iris.as_str(), "IRIS");
        assert_eq!(BiometricType::Voice.as_str(), "VOICE");
        assert_eq!(BiometricType::Vein.as_str(), "VEIN");
        assert_eq!(BiometricType::Palm.as_str(), "PALM");
    }

    #[test]
    fn test_policy_default() {
        let p = BiometricPolicy::default();
        assert_eq!(p.max_attempts, 10);
        assert!((p.max_fmr - 0.001).abs() < f64::EPSILON);
        assert!((p.min_quality_score - 70.0).abs() < f32::EPSILON);
        assert!(p.require_liveness);
        assert_eq!(p.aal_required, 2);
    }
}
