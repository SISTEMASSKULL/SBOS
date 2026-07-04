// ============================================================
// bauth::saga::actions::login — Acciones reales de autenticación
// B35 — Reemplaza simulate_action() con implementaciones reales
//
// Acciones:
//   bauth.login.verify_argon2id — verificar password contra hash Argon2id
//   bauth.login.record_failed  — registrar intento fallido en ath_login_attempt
//
// DOC-SBOS-001 N3 · NIST SP 800-63B-4 §5.1.1.2
// ============================================================

use serde_json::Value;
use argon2::{
    password_hash::{PasswordHash, PasswordVerifier},
    Argon2,
};

/// Verifica un password contra su hash Argon2id almacenado en la BD.
/// Busca en `ath_password_history` el hash más reciente del usuario.
pub async fn verify_argon2id(
    pg: &sqlx::PgPool,
    username: &str,
    password: &str,
) -> Result<Value, String> {
    // Buscar el hash más reciente del usuario
    #[derive(sqlx::FromRow)]
    struct HashRow {
        password_hash: String,
    }

    let row: Option<HashRow> = sqlx::query_as(
        "SELECT password_hash FROM bauth.ath_password_history
         WHERE user_uuid = (SELECT uuid FROM bauth.idn_user_template WHERE username = $1 LIMIT 1)
         ORDER BY created_at DESC LIMIT 1"
    )
    .bind(username)
    .fetch_optional(pg)
    .await
    .map_err(|e| format!("error consultando hash: {}", e))?;

    let hash = match row {
        Some(r) => r.password_hash,
        None => return Ok(serde_json::json!({
            "verified": false,
            "reason": "usuario sin password registrado",
        })),
    };

    // Verificar con Argon2id
    let parsed_hash = PasswordHash::new(&hash)
        .map_err(|e| format!("hash inválido: {}", e))?;

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

/// Registra un intento de login fallido.
pub async fn record_failed_attempt(
    pg: &sqlx::PgPool,
    username: &str,
    source_ip: &str,
) -> Result<Value, String> {
    sqlx::query(
        "INSERT INTO bauth.ath_login_attempt (username, source_ip, result, attempt_at)
         VALUES ($1, $2::inet, 'FAILED', now())"
    )
    .bind(username)
    .bind(source_ip)
    .execute(pg)
    .await
    .map_err(|e| format!("error registrando intento: {}", e))?;

    Ok(Value::String("attempt_recorded".into()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_argon2id_hash_verification() {
        // Generar un hash Argon2id para testing
        use argon2::password_hash::{SaltString, PasswordHasher};
        use rand::rngs::OsRng;

        let password = "correct_password";
        let salt = SaltString::generate(&mut OsRng);
        let argon2 = Argon2::default();
        let hash = argon2.hash_password(password.as_bytes(), &salt)
            .expect("hash generation failed");

        // Verificar con el password correcto
        let hash_str = hash.to_string();
        let parsed = PasswordHash::new(&hash_str).unwrap();
        assert!(argon2.verify_password(password.as_bytes(), &parsed).is_ok());

        // Verificar con password incorrecto
        assert!(argon2.verify_password("wrong_password".as_bytes(), &parsed).is_err());
    }
}
