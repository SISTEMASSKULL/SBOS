// ============================================================
// bauth::saga::actions::login — Acciones reales de autenticación
// B35 — Implementaciones contra el DDL canónico v2.12.0
//
// Tablas canónicas:
//   bauth.idn_user              — usuario (D03, reemplaza idn_user_template)
//   bauth.auth_credential       — credenciales enrolladas (method_code, status)
//   bauth.auth_credential_secret — hash Argon2id (reemplaza ath_password_history)
//   bauth.auth_attempt_log      — intentos fallidos (reemplaza ath_login_attempt)
//
// DOC-SBOS-001 N3 · NIST SP 800-63B-4 §5.1.1.2
// ============================================================

use serde_json::Value;
use argon2::{
    password_hash::{PasswordHash, PasswordVerifier},
    Argon2,
};

/// Verifica un password contra su hash Argon2id almacenado en la BD.
///
/// Busca en `auth_credential_secret` el hash activo del usuario indicado.
/// La credencial de tipo PASSWORD activa con hash ARGON2ID_HASH.
///
/// # Parámetros
/// - `pg`       — pool de conexiones a SBOSDB
/// - `username` — nombre de usuario (único por tenant)
///
/// # Retorno
/// JSON con `verified: bool` y `reason` si falló.
pub async fn verify_argon2id(
    pg: &sqlx::PgPool,
    username: &str,
    password: &str,
) -> Result<Value, String> {
    #[derive(sqlx::FromRow)]
    struct HashRow {
        password_hash: String,
    }

    // Buscar hash Argon2id activo del usuario — unión auth_credential + auth_credential_secret
    let row: Option<HashRow> = sqlx::query_as(
        r#"
        SELECT acs.secret AS password_hash
        FROM bauth.auth_credential_secret acs
        JOIN bauth.auth_credential ac ON ac.credential_id = acs.credential_id
        JOIN bauth.idn_user u         ON u.user_id = ac.user_id
        WHERE u.username   = $1
          AND ac.method_code = 'PASSWORD'
          AND ac.status      = 'ACTIVE'
          AND acs.type       = 'ARGON2ID_HASH'
        ORDER BY acs.created_at DESC
        LIMIT 1
        "#,
    )
    .bind(username)
    .fetch_optional(pg)
    .await
    .map_err(|e| format!("error consultando hash: {}", e))?;

    let hash = match row {
        Some(r) => r.password_hash,
        None => return Ok(serde_json::json!({
            "verified": false,
            "reason": "usuario sin credencial PASSWORD activa",
        })),
    };

    let parsed_hash = PasswordHash::new(&hash)
        .map_err(|e| format!("hash inválido en BD: {}", e))?;

    let argon2 = Argon2::default();
    match argon2.verify_password(password.as_bytes(), &parsed_hash) {
        Ok(()) => Ok(serde_json::json!({
            "verified": true,
            "username": username,
        })),
        Err(_) => Ok(serde_json::json!({
            "verified": false,
            "reason": "password incorrecto",
        })),
    }
}

/// Registra un intento de login fallido en `auth_attempt_log` (WORM particionada).
///
/// # Parámetros
/// - `pg`             — pool de conexiones a SBOSDB
/// - `tenant_id`      — UUID del tenant donde ocurrió el intento
/// - `user_id`        — UUID del usuario si fue identificado; `None` si no se encontró
/// - `username_tried` — username presentado en el intento
/// - `method_code`    — código del método autenticación (ej. `"PASSWORD"`)
/// - `ip_address`     — IP de origen del intento
/// - `failure_reason` — descripción textual del motivo de fallo, o `None`
/// - `ctx_id`         — identificador de contexto trazable (SBOS-049)
pub async fn record_failed_attempt(
    pg: &sqlx::PgPool,
    tenant_id: uuid::Uuid,
    user_id: Option<uuid::Uuid>,
    username_tried: &str,
    method_code: &str,
    ip_address: &str,
    failure_reason: Option<&str>,
    ctx_id: &str,
) -> Result<Value, String> {
    sqlx::query(
        r#"
        INSERT INTO bauth.auth_attempt_log
            (tenant_id, user_id, username_tried, method_code, outcome,
             failure_reason, ip_address, ctx_id)
        VALUES ($1, $2, $3, $4, 'FAILURE', $5, $6::inet, $7)
        "#,
    )
    .bind(tenant_id)
    .bind(user_id)
    .bind(username_tried)
    .bind(method_code)
    .bind(failure_reason)
    .bind(ip_address)
    .bind(ctx_id)
    .execute(pg)
    .await
    .map_err(|e| format!("error registrando intento fallido: {}", e))?;

    Ok(Value::String("attempt_recorded".into()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_argon2id_hash_verification() {
        use argon2::password_hash::{SaltString, PasswordHasher};
        use rand::rngs::OsRng;

        let password = "correct_password";
        let salt = SaltString::generate(&mut OsRng);
        let argon2 = Argon2::default();
        let hash = argon2.hash_password(password.as_bytes(), &salt)
            .expect("fallo al generar hash");

        let hash_str = hash.to_string();
        let parsed = PasswordHash::new(&hash_str).unwrap();
        assert!(argon2.verify_password(password.as_bytes(), &parsed).is_ok());
        assert!(argon2.verify_password("wrong_password".as_bytes(), &parsed).is_err());
    }
}
