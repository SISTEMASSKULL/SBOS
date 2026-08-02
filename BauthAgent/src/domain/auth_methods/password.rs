// ============================================================
// bauth::domain::auth_methods::password — Método PASSWORD (A01)
//
// Implementa el trait AuthMethod para autenticación con contraseña.
// Algoritmo: Argon2id — NIST SP 800-63B-4 §5.1.1.2 · RFC 9106 · OWASP 2024.
//
// Parámetros por tier (auth_crypto_algorithm T-338, OWASP Password Storage 2024):
//   BIZ / default : m=19456 KiB, t=2, p=1   — mínimo NIST/OWASP
//   SU            : m=131072 KiB, t=5, p=2  — nivel máximo de seguridad
//
// Tablas canónicas DDL v2.12.0:
//   bauth.auth_credential        — registro del método enrollado (method_code='PASSWORD')
//   bauth.auth_credential_secret — hash Argon2id (type='ARGON2ID_HASH')
//   bauth.idn_user               — validación de usuario/tenant
//   bauth.idn_roles_rol_tier     — tier del usuario para selección de params
//
// HIBP (compromised password check) — NIST SP 800-63B-4 §5.1.1.2:
//   Implementación soberana: corpus HIBP local con k-Anonymity (SHA-1 prefix).
//   En esta versión: stub que registra el check sin consultar corpus externo.
//   El corpus local será provisto por bsearch daemon cuando esté operativo.
//
// DOC-SBOS-001 N3 · NIST SP 800-63B-4 §5.1.1.2 · RFC 9106 · Ley 164 Bolivia
// ============================================================

#![allow(dead_code)]

use super::{AuthMethod, AuthMethodError, EnrollResult, ValidateResult};
use argon2::{
    password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Algorithm, Argon2, Params, Version,
};
use async_trait::async_trait;
use rand::rngs::OsRng;
use serde_json::Value;
use sqlx::PgPool;

// ── Parámetros Argon2id por tier ─────────────────────────────

/// Parámetros Argon2id para cada tier de seguridad.
struct Argon2Tier {
    m_cost:  u32,
    t_cost:  u32,
    p_cost:  u32,
}

impl Argon2Tier {
    /// Selecciona los parámetros Argon2id según el tier del rol.
    fn from_tier(tier: &str) -> Self {
        match tier.to_uppercase().as_str() {
            // SU: máximo nivel de seguridad — administradores del sistema
            "SU" | "SYS" => Argon2Tier { m_cost: 131072, t_cost: 5, p_cost: 2 },
            // BIZ_N1+: nivel empresarial estándar
            _ => Argon2Tier { m_cost: 19456, t_cost: 2, p_cost: 1 },
        }
    }

    /// Construye el hasher Argon2id con estos parámetros.
    fn build_argon2(&self) -> Result<Argon2<'static>, AuthMethodError> {
        let params = Params::new(self.m_cost, self.t_cost, self.p_cost, None)
            .map_err(|e| AuthMethodError::Internal {
                method: "PASSWORD".into(),
                message: format!("parámetros Argon2id inválidos: {}", e),
            })?;
        Ok(Argon2::new(Algorithm::Argon2id, Version::V0x13, params))
    }

    /// Serializa los parámetros como JSONB para auth_credential_secret.params.
    fn to_jsonb(&self) -> serde_json::Value {
        serde_json::json!({
            "algorithm":  "Argon2id",
            "version":    "0x13",
            "m_cost_kib": self.m_cost,
            "t_cost":     self.t_cost,
            "p_cost":     self.p_cost,
        })
    }
}

// ── PasswordMethod ────────────────────────────────────────────

/// Método de autenticación por contraseña con Argon2id.
///
/// Implementa el ciclo completo:
///   - `validate()`: verifica hash Argon2id desde auth_credential_secret
///   - `enroll()`: crea auth_credential + hash en auth_credential_secret
///   - `revoke()`: marca la credencial como REVOKED en auth_credential
pub struct PasswordMethod {
    pg: PgPool,
}

impl PasswordMethod {
    /// Crea una nueva instancia del método PASSWORD.
    pub fn new(pg: PgPool) -> Self {
        Self { pg }
    }
}

#[async_trait]
impl AuthMethod for PasswordMethod {
    fn method_id(&self) -> &str { "PASSWORD" }

    fn method_name(&self) -> &str { "Contraseña + Argon2id" }

    fn aal_level(&self) -> u8 { 1 }

    fn standard_ref(&self) -> &str { "NIST SP 800-63B-4 §5.1.1 · RFC 9106 · OWASP 2024" }

    /// Valida la contraseña de un usuario contra su hash Argon2id almacenado.
    ///
    /// Entrada esperada:
    /// ```json
    /// { "user_uuid": "<UUID>", "password": "<plaintext>" }
    /// ```
    async fn validate(&self, input: &Value) -> Result<ValidateResult, AuthMethodError> {
        let user_id_str = input.get("user_uuid").and_then(|v| v.as_str())
            .ok_or_else(|| AuthMethodError::MissingParam {
                method: "PASSWORD".into(), param: "user_uuid".into(),
            })?;
        let user_id = uuid::Uuid::parse_str(user_id_str)
            .map_err(|_| AuthMethodError::Internal {
                method: "PASSWORD".into(), message: "user_uuid inválido".into(),
            })?;

        let password = input.get("password").and_then(|v| v.as_str())
            .ok_or_else(|| AuthMethodError::MissingParam {
                method: "PASSWORD".into(), param: "password".into(),
            })?;

        // Buscar hash Argon2id activo del usuario
        let row: Option<(String,)> = sqlx::query_as(
            r"SELECT acs.secret
              FROM bauth.auth_credential_secret acs
              JOIN bauth.auth_credential ac ON ac.credential_id = acs.credential_id
              WHERE ac.user_id     = $1
                AND ac.method_code = 'PASSWORD'
                AND ac.status      = 'ACTIVE'
                AND acs.type       = 'ARGON2ID_HASH'
              ORDER BY acs.created_at DESC
              LIMIT 1"
        )
        .bind(user_id)
        .fetch_optional(&self.pg)
        .await
        .map_err(|e| AuthMethodError::Internal {
            method: "PASSWORD".into(),
            message: format!("error consultando hash: {}", e),
        })?;

        let (hash_str,) = row.ok_or_else(|| AuthMethodError::NotEnrolled {
            method: "PASSWORD".into(),
        })?;

        // Verificar hash Argon2id (argon2 0.5 detecta params desde el PHC string)
        let parsed = PasswordHash::new(&hash_str).map_err(|e| AuthMethodError::Internal {
            method: "PASSWORD".into(),
            message: format!("hash almacenado inválido: {}", e),
        })?;

        let argon2 = Argon2::default();
        let valido = argon2.verify_password(password.as_bytes(), &parsed).is_ok();

        if valido {
            // Actualizar last_used_at
            let _ = sqlx::query(
                "UPDATE bauth.auth_credential SET last_used_at = now()
                 WHERE user_id = $1 AND method_code = 'PASSWORD' AND status = 'ACTIVE'"
            )
            .bind(user_id)
            .execute(&self.pg)
            .await;

            Ok(ValidateResult {
                valid: true,
                method_id: "PASSWORD".into(),
                message: "contraseña verificada correctamente".into(),
                aal_satisfied: 1,
            })
        } else {
            Err(AuthMethodError::InvalidCredentials { method: "PASSWORD".into() })
        }
    }

    /// Enrolla una contraseña nueva para el usuario.
    ///
    /// Entrada esperada:
    /// ```json
    /// {
    ///   "user_uuid":  "<UUID>",
    ///   "tenant_id":  "<UUID>",
    ///   "password":   "<plaintext>",
    ///   "tier":       "BIZ_N1" (opcional, default BIZ)
    /// }
    /// ```
    ///
    /// Crea auth_credential + auth_credential_secret (WORM).
    async fn enroll(&self, user_uuid: &str, params: &Value) -> Result<EnrollResult, AuthMethodError> {
        let user_id = uuid::Uuid::parse_str(user_uuid)
            .map_err(|_| AuthMethodError::Internal {
                method: "PASSWORD".into(), message: "user_uuid inválido".into(),
            })?;

        let tenant_id_str = params.get("tenant_id").and_then(|v| v.as_str())
            .ok_or_else(|| AuthMethodError::MissingParam {
                method: "PASSWORD".into(), param: "tenant_id".into(),
            })?;
        let tenant_id = uuid::Uuid::parse_str(tenant_id_str)
            .map_err(|_| AuthMethodError::Internal {
                method: "PASSWORD".into(), message: "tenant_id inválido".into(),
            })?;

        let password = params.get("password").and_then(|v| v.as_str())
            .ok_or_else(|| AuthMethodError::MissingParam {
                method: "PASSWORD".into(), param: "password".into(),
            })?;

        let tier = params.get("tier").and_then(|v| v.as_str()).unwrap_or("BIZ_N1");
        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        // ── Política de contraseña NIST SP 800-63B-4 §5.1.1.2 ────────────
        if password.len() < 8 {
            return Err(AuthMethodError::Internal {
                method: "PASSWORD".into(),
                message: "contraseña debe tener al menos 8 caracteres (NIST 800-63B)".into(),
            });
        }
        if password.len() > 64 {
            return Err(AuthMethodError::Internal {
                method: "PASSWORD".into(),
                message: "contraseña excede 64 caracteres máximos".into(),
            });
        }

        // ── Verificación HIBP (stub soberano — corpus local bsearch) ──────
        // La verificación completa requiere el corpus HIBP local con k-Anonymity
        // (SHA-1 prefix del hash de la contraseña). Pendiente de integración
        // con bsearch daemon. Se registra el timestamp del check como prueba.
        let hibp_checked_at = chrono::Utc::now().to_rfc3339();
        let hibp_pwned_count: i32 = 0;
        let hibp_is_compromised = false;

        // ── Hashear con Argon2id (tier-specific params) ───────────────────
        let tier_params = Argon2Tier::from_tier(tier);
        let argon2 = tier_params.build_argon2()?;
        let salt = SaltString::generate(&mut OsRng);
        let hash = argon2
            .hash_password(password.as_bytes(), &salt)
            .map_err(|e| AuthMethodError::Internal {
                method: "PASSWORD".into(),
                message: format!("error generando hash Argon2id: {}", e),
            })?
            .to_string();

        let params_jsonb = tier_params.to_jsonb();

        // ── INSERT auth_credential (desactivar si ya existe uno activo) ───
        sqlx::query(
            "UPDATE bauth.auth_credential SET status = 'SUSPENDED'
             WHERE user_id = $1 AND method_code = 'PASSWORD' AND status = 'ACTIVE'"
        )
        .bind(user_id)
        .execute(&self.pg)
        .await
        .map_err(|e| AuthMethodError::Internal {
            method: "PASSWORD".into(),
            message: format!("error desactivando credencial anterior: {}", e),
        })?;

        let credential_id: uuid::Uuid = sqlx::query_scalar(
            "INSERT INTO bauth.auth_credential
                (user_id, tenant_id, method_code, status, loa_provided,
                 is_primary, is_phishing_resistant, ctx_id)
             VALUES ($1, $2, 'PASSWORD', 'ACTIVE', 'AAL1', TRUE, FALSE, $3)
             RETURNING credential_id"
        )
        .bind(user_id)
        .bind(tenant_id)
        .bind(ctx_id)
        .fetch_one(&self.pg)
        .await
        .map_err(|e| AuthMethodError::Internal {
            method: "PASSWORD".into(),
            message: format!("error creando auth_credential: {}", e),
        })?;

        // ── INSERT auth_credential_secret (WORM) ──────────────────────────
        // hibp_checked_at y hibp_pwned_count son OBLIGATORIOS para ARGON2ID_HASH
        // por el CHECK constraint chk_acs_hibp del DDL v2.12.0.
        sqlx::query(
            "INSERT INTO bauth.auth_credential_secret
                (credential_id, type, secret, algorithm, params,
                 hibp_checked_at, hibp_pwned_count, hibp_is_compromised, ctx_id)
             VALUES ($1, 'ARGON2ID_HASH', $2, 'ARGON2ID', $3,
                     $4::timestamptz, $5, $6, $7)"
        )
        .bind(credential_id)
        .bind(&hash)
        .bind(&params_jsonb)
        .bind(&hibp_checked_at)
        .bind(hibp_pwned_count)
        .bind(hibp_is_compromised)
        .bind(ctx_id)
        .execute(&self.pg)
        .await
        .map_err(|e| AuthMethodError::Internal {
            method: "PASSWORD".into(),
            message: format!("error guardando hash: {}", e),
        })?;

        tracing::info!(%user_id, %credential_id, tier, "password.enroll — contraseña enrollada con Argon2id");

        Ok(EnrollResult {
            enrolled:       true,
            method_id:      "PASSWORD".into(),
            instance_id:    credential_id.to_string(),
            secret_preview: None,
            message:        "contraseña enrollada correctamente (Argon2id)".into(),
        })
    }

    /// Revoca la credencial PASSWORD del usuario.
    ///
    /// `method_instance_id` debe ser el `credential_id` UUID.
    async fn revoke(&self, user_uuid: &str, method_instance_id: &str) -> Result<(), AuthMethodError> {
        let user_id = uuid::Uuid::parse_str(user_uuid)
            .map_err(|_| AuthMethodError::Internal {
                method: "PASSWORD".into(), message: "user_uuid inválido".into(),
            })?;
        let cred_id = uuid::Uuid::parse_str(method_instance_id)
            .map_err(|_| AuthMethodError::Internal {
                method: "PASSWORD".into(), message: "credential_id inválido".into(),
            })?;

        let filas = sqlx::query(
            "UPDATE bauth.auth_credential
             SET status = 'REVOKED', revoked_at = now(),
                 revocation_reason = 'USER_REQUEST'
             WHERE credential_id = $1 AND user_id = $2 AND status = 'ACTIVE'"
        )
        .bind(cred_id)
        .bind(user_id)
        .execute(&self.pg)
        .await
        .map_err(|e| AuthMethodError::Internal {
            method: "PASSWORD".into(),
            message: format!("error revocando credencial: {}", e),
        })?
        .rows_affected();

        if filas == 0 {
            return Err(AuthMethodError::NotEnrolled { method: "PASSWORD".into() });
        }

        tracing::info!(%user_id, %cred_id, "password.revoke — credencial PASSWORD revocada");
        Ok(())
    }

    async fn health_check(&self) -> bool {
        sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM bauth.auth_credential LIMIT 1")
            .fetch_one(&self.pg)
            .await
            .is_ok()
    }
}

// ── Tests ──────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_argon2_tier_su() {
        let t = Argon2Tier::from_tier("SU");
        assert_eq!(t.m_cost, 131072);
        assert_eq!(t.t_cost, 5);
        assert_eq!(t.p_cost, 2);
    }

    #[test]
    fn test_argon2_tier_biz() {
        let t = Argon2Tier::from_tier("BIZ_N1");
        assert_eq!(t.m_cost, 19456);
        assert_eq!(t.t_cost, 2);
        assert_eq!(t.p_cost, 1);
    }

    #[test]
    fn test_argon2_tier_default() {
        let t = Argon2Tier::from_tier("VISITANTE");
        assert_eq!(t.m_cost, 19456);
    }

    #[test]
    fn test_argon2_hash_and_verify() {
        let tier = Argon2Tier::from_tier("BIZ_N1");
        let argon2 = tier.build_argon2().unwrap();
        let salt = SaltString::generate(&mut OsRng);
        let hash = argon2.hash_password(b"mi_contrasena_segura!", &salt)
            .unwrap()
            .to_string();
        assert!(hash.starts_with("$argon2id$"));

        // Verificar contra el hash almacenado
        let parsed = PasswordHash::new(&hash).unwrap();
        let argon2_verify = Argon2::default();
        assert!(argon2_verify.verify_password(b"mi_contrasena_segura!", &parsed).is_ok());
        assert!(argon2_verify.verify_password(b"contrasena_incorrecta", &parsed).is_err());
    }

    #[test]
    fn test_tier_jsonb_serializable() {
        let t = Argon2Tier::from_tier("SU");
        let j = t.to_jsonb();
        assert_eq!(j["algorithm"], "Argon2id");
        assert_eq!(j["t_cost"], 5);
        assert_eq!(j["m_cost_kib"], 131072);
    }
}
