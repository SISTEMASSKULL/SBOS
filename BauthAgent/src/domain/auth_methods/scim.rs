// ============================================================
// bauth::domain::auth_methods::scim — Método SCIM (E13)
//
// SCIM 2.0 Client Authentication — RFC 7644 §2, RFC 7643 §8.
// Valida que un cliente SCIM 2.0 está autorizado a provisionar
// identidades en bAuth. El cliente se autentica mediante:
//   - Bearer token OAuth 2.0 (modo normal): el token es un JWT
//     emitido por bAuth con scope='scim:provision' y un rol M2M.
//   - mTLS X.509 (modo avanzado): certificado del proveedor SCIM
//     verificado contra auth_credential_x509. Se delega a mtls.rs.
//
// Este método valida el bearer token y verifica el claim de scope.
// No enrolla usuarios finales — enrolla proveedores SCIM (M2M).
//
// Columnas canónicas DDL v2.12.0:
//   bauth.auth_credential     — registro M2M del proveedor SCIM
//   bauth.idn_scim_attribute_map — mapeo de atributos SCIM→bAuth
//
// DOC-SBOS-001 N3 · RFC 7644 §2 · RFC 7643 §8 · NIST SP 800-63-4 §6 (FAL)
// ============================================================

#![allow(dead_code)]

use super::{AuthMethod, AuthMethodError, EnrollResult, ValidateResult};
use async_trait::async_trait;
use serde_json::Value;
use sqlx::PgPool;
use std::sync::Arc;

/// Firmador JWT para verificar bearer tokens de clientes SCIM.
/// Reutiliza el mismo JwtSigner que el sistema de tokens bAuth.
type JwtSigner = crate::domain::jwt_signer::JwtSigner;

// ── ScimMethod ────────────────────────────────────────────────

/// Método de autenticación para proveedores SCIM 2.0 (M2M).
///
/// Valida el bearer token del cliente SCIM verificando:
///   - Firma Ed25519 (JwtSigner::verify)
///   - Claim `scope` contiene 'scim:provision'
///   - Claim `client_type` = 'SCIM_PROVIDER' o rol M2M activo
pub struct ScimMethod {
    pg:     PgPool,
    signer: Arc<JwtSigner>,
}

impl ScimMethod {
    /// Crea una nueva instancia del método SCIM.
    pub fn new(pg: PgPool, signer: Arc<JwtSigner>) -> Self {
        Self { pg, signer }
    }
}

#[async_trait]
impl AuthMethod for ScimMethod {
    fn method_id(&self) -> &str { "SCIM_BEARER" }

    fn method_name(&self) -> &str { "SCIM 2.0 Bearer Token" }

    fn aal_level(&self) -> u8 { 2 }

    fn standard_ref(&self) -> &str { "RFC 7644 §2 · RFC 7643 §8 · NIST SP 800-63-4 §6" }

    /// Valida el bearer token de un cliente SCIM.
    ///
    /// Entrada esperada:
    /// ```json
    /// {
    ///   "bearer_token":  "<JWT emitido por bAuth con scope='scim:provision'>",
    ///   "tenant_id":     "<UUID del tenant>",
    ///   "scim_endpoint": "/scim/v2/Users" (informativo)
    /// }
    /// ```
    async fn validate(&self, input: &Value) -> Result<ValidateResult, AuthMethodError> {
        let bearer = input.get("bearer_token").and_then(|v| v.as_str())
            .ok_or_else(|| AuthMethodError::MissingParam {
                method: "SCIM_BEARER".into(), param: "bearer_token".into(),
            })?;

        let tenant_id_str = input.get("tenant_id").and_then(|v| v.as_str())
            .ok_or_else(|| AuthMethodError::MissingParam {
                method: "SCIM_BEARER".into(), param: "tenant_id".into(),
            })?;
        let tenant_id = uuid::Uuid::parse_str(tenant_id_str)
            .map_err(|_| AuthMethodError::Internal {
                method: "SCIM_BEARER".into(), message: "tenant_id inválido".into(),
            })?;

        // ── Verificar firma del bearer token ──────────────────────────────
        let claims = self.signer.verify(bearer).map_err(|e| {
            AuthMethodError::InvalidCredentials {
                method: format!("SCIM_BEARER: firma inválida — {}", e),
            }
        })?;

        // ── Verificar expiración ───────────────────────────────────────────
        let exp = claims.get("exp").and_then(|v| v.as_i64()).unwrap_or(0);
        if exp > 0 && exp < chrono::Utc::now().timestamp() {
            return Err(AuthMethodError::Expired {
                method: "SCIM_BEARER".into(),
                ttl_secs: 0,
            });
        }

        // ── Verificar scope='scim:provision' ──────────────────────────────
        let scope = claims.get("scope").and_then(|v| v.as_str()).unwrap_or("");
        if !scope.contains("scim:provision") {
            return Err(AuthMethodError::InvalidCredentials {
                method: "SCIM_BEARER: scope insuficiente — se requiere 'scim:provision'".into(),
            });
        }

        // ── Verificar tenant del token coincide con tenant solicitado ──────
        let token_tenant = claims.get("tenant").and_then(|v| v.as_str()).unwrap_or("");
        if !token_tenant.is_empty() {
            let token_tenant_id = uuid::Uuid::parse_str(token_tenant).unwrap_or_default();
            if token_tenant_id != tenant_id && token_tenant != "GLOBAL" {
                return Err(AuthMethodError::InvalidCredentials {
                    method: "SCIM_BEARER: tenant no coincide".into(),
                });
            }
        }

        // ── Verificar que el cliente SCIM tiene credencial activa en BD ───
        let subject_str = claims.get("sub").and_then(|v| v.as_str()).unwrap_or("");
        let client_activo: Option<(i64,)> = sqlx::query_as(
            "SELECT COUNT(*) FROM bauth.auth_credential
             WHERE user_id::text = $1
               AND method_code = 'SCIM_BEARER'
               AND status = 'ACTIVE'
               AND (valid_until IS NULL OR valid_until > now())"
        )
        .bind(subject_str)
        .fetch_optional(&self.pg)
        .await
        .unwrap_or(None);

        let n = client_activo.map(|(c,)| c).unwrap_or(0);
        if n == 0 {
            return Err(AuthMethodError::NotEnrolled { method: "SCIM_BEARER".into() });
        }

        let scim_endpoint = input.get("scim_endpoint").and_then(|v| v.as_str())
            .unwrap_or("/scim/v2");

        tracing::info!(
            %subject_str, %tenant_id, scim_endpoint,
            "scim.validate — cliente SCIM autenticado"
        );

        Ok(ValidateResult {
            valid:         true,
            method_id:     "SCIM_BEARER".into(),
            message:       format!("cliente SCIM autorizado para tenant {}", tenant_id),
            aal_satisfied: 2,
        })
    }

    /// Registra un nuevo proveedor SCIM como cliente M2M.
    ///
    /// Entrada esperada:
    /// ```json
    /// {
    ///   "client_id":   "<UUID del usuario M2M>",
    ///   "tenant_id":   "<UUID del tenant>",
    ///   "provider_name": "Nombre del proveedor SCIM"
    /// }
    /// ```
    async fn enroll(&self, user_uuid: &str, params: &Value) -> Result<EnrollResult, AuthMethodError> {
        let user_id = uuid::Uuid::parse_str(user_uuid)
            .map_err(|_| AuthMethodError::Internal {
                method: "SCIM_BEARER".into(), message: "user_uuid inválido".into(),
            })?;

        let tenant_id_str = params.get("tenant_id").and_then(|v| v.as_str())
            .ok_or_else(|| AuthMethodError::MissingParam {
                method: "SCIM_BEARER".into(), param: "tenant_id".into(),
            })?;
        let tenant_id = uuid::Uuid::parse_str(tenant_id_str)
            .map_err(|_| AuthMethodError::Internal {
                method: "SCIM_BEARER".into(), message: "tenant_id inválido".into(),
            })?;

        let ctx_id = params.get("ctx_id").and_then(|v| v.as_str()).unwrap_or("system");

        // Desactivar credencial SCIM anterior si existe
        let _ = sqlx::query(
            "UPDATE bauth.auth_credential SET status = 'SUSPENDED'
             WHERE user_id = $1 AND method_code = 'SCIM_BEARER' AND status = 'ACTIVE'"
        )
        .bind(user_id)
        .execute(&self.pg)
        .await;

        // Registrar nueva credencial SCIM M2M
        let credential_id: uuid::Uuid = sqlx::query_scalar(
            "INSERT INTO bauth.auth_credential
                (user_id, tenant_id, method_code, status, loa_provided,
                 is_primary, is_phishing_resistant, ctx_id)
             VALUES ($1, $2, 'SCIM_BEARER', 'ACTIVE', 'AAL2', TRUE, FALSE, $3)
             RETURNING credential_id"
        )
        .bind(user_id)
        .bind(tenant_id)
        .bind(ctx_id)
        .fetch_one(&self.pg)
        .await
        .map_err(|e| AuthMethodError::Internal {
            method: "SCIM_BEARER".into(),
            message: format!("error registrando cliente SCIM: {}", e),
        })?;

        tracing::info!(%user_id, %credential_id, "scim.enroll — proveedor SCIM registrado");

        Ok(EnrollResult {
            enrolled:       true,
            method_id:      "SCIM_BEARER".into(),
            instance_id:    credential_id.to_string(),
            secret_preview: None,
            message:        "proveedor SCIM registrado correctamente".into(),
        })
    }

    /// Revoca la credencial SCIM del proveedor.
    async fn revoke(&self, user_uuid: &str, method_instance_id: &str) -> Result<(), AuthMethodError> {
        let user_id = uuid::Uuid::parse_str(user_uuid)
            .map_err(|_| AuthMethodError::Internal {
                method: "SCIM_BEARER".into(), message: "user_uuid inválido".into(),
            })?;
        let cred_id = uuid::Uuid::parse_str(method_instance_id)
            .map_err(|_| AuthMethodError::Internal {
                method: "SCIM_BEARER".into(), message: "credential_id inválido".into(),
            })?;

        let filas = sqlx::query(
            "UPDATE bauth.auth_credential
             SET status = 'REVOKED', revoked_at = now(),
                 revocation_reason = 'ADMIN_REVOKE'
             WHERE credential_id = $1 AND user_id = $2 AND status = 'ACTIVE'"
        )
        .bind(cred_id)
        .bind(user_id)
        .execute(&self.pg)
        .await
        .map_err(|e| AuthMethodError::Internal {
            method: "SCIM_BEARER".into(),
            message: format!("error revocando credencial SCIM: {}", e),
        })?
        .rows_affected();

        if filas == 0 {
            return Err(AuthMethodError::NotEnrolled { method: "SCIM_BEARER".into() });
        }

        tracing::info!(%user_id, %cred_id, "scim.revoke — credencial SCIM revocada");
        Ok(())
    }

    async fn health_check(&self) -> bool {
        sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*) FROM bauth.idn_scim_attribute_map LIMIT 1"
        )
        .fetch_one(&self.pg)
        .await
        .is_ok()
    }
}
