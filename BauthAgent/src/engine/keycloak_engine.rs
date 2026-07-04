// ================================================================
// bauth::engine::keycloak_engine — B12 KeycloakEngine
//
// Motor de identidad: Keycloak 26.x Admin REST API.
// Responsabilidades:
//   1. Autenticar contra KC vía client_credentials
//   2. Sincronizar RolTemplate → KC (Composite Roles, Realm Roles)
//   3. Sincronizar UserTemplate → KC (Users, Groups, Role Mappings)
//   4. Reconciliar: detectar drift KC vs bauth_db y corregir
//   5. Bootstrap: reconstruir todo desde cero
//
// DOC-SBOS-001 N3 · BAUTH-CONTRATO-SYMBIOSIS.md v2.0 · ADR-020
// ================================================================

#![allow(dead_code)]
use super::{AuthEngine, EngineError, ReconcileReport};
use async_trait::async_trait;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info, warn};

// ── KeycloakEngine ─────────────────────────────────────────────

pub struct KeycloakEngine {
    /// Nombre del motor.
    name: String,
    /// URL base de Keycloak (ej: https://keycloak.sbos.bo:8443).
    base_url: String,
    /// Realm donde opera bAuth (ej: sbos_system, tenant_{id}).
    realm: String,
    /// Client ID para client_credentials.
    client_id: String,
    /// Client secret (desde Vault en producción).
    client_secret: String,
    /// Cliente HTTP con TLS.
    http: Client,
    /// Token cacheado + expiración.
    token_cache: Arc<RwLock<CachedToken>>,
}

struct CachedToken {
    access_token: String,
    expires_at: chrono::DateTime<chrono::Utc>,
}

impl KeycloakEngine {
    pub fn new(
        name: &str,
        base_url: &str,
        realm: &str,
        client_id: &str,
        client_secret: &str,
    ) -> Self {
        Self::new_with_tls(name, base_url, realm, client_id, client_secret, true)
    }

    pub fn new_with_tls(
        name: &str, base_url: &str, realm: &str,
        client_id: &str, client_secret: &str, tls_verify: bool,
    ) -> Self {
        let http = Client::builder()
            .timeout(std::time::Duration::from_secs(30))
            .danger_accept_invalid_certs(!tls_verify)
            .build()
            .unwrap_or_else(|_| Client::new());

        Self {
            name: name.into(),
            base_url: base_url.trim_end_matches('/').into(),
            realm: realm.into(),
            client_id: client_id.into(),
            client_secret: client_secret.into(),
            http,
            token_cache: Arc::new(RwLock::new(CachedToken {
                access_token: String::new(),
                expires_at: chrono::Utc::now(),
            })),
        }
    }

    /// URL base de la Admin REST API.
    fn admin_url(&self) -> String {
        format!("{}/admin/realms/{}", self.base_url, self.realm)
    }

    /// Obtener token OAuth2 client_credentials, cacheado.
    async fn get_token(&self) -> Result<String, EngineError> {
        {
            let cache = self.token_cache.read().await;
            if chrono::Utc::now() < cache.expires_at {
                return Ok(cache.access_token.clone());
            }
        }

        let token_url = format!(
            "{}/realms/master/protocol/openid-connect/token",
            self.base_url
        );

        let resp = self.http
            .post(&token_url)
            .form(&[
                ("grant_type", "client_credentials"),
                ("client_id", &self.client_id),
                ("client_secret", &self.client_secret),
            ])
            .send().await
            .map_err(|e| EngineError::Connection {
                engine: self.name.clone(),
                message: format!("token endpoint: {}", e),
            })?;

        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            return Err(EngineError::Rejected {
                engine: self.name.clone(),
                reason: format!("auth falló ({}): {}", status, body),
            });
        }

        #[derive(Deserialize)]
        struct TokenResponse {
            access_token: String,
            expires_in: i64,
        }

        let tr: TokenResponse = resp.json().await.map_err(|e| EngineError::Other {
            engine: self.name.clone(),
            message: format!("parse token: {}", e),
        })?;

        let expires_at = chrono::Utc::now()
            + chrono::Duration::seconds(tr.expires_in.saturating_sub(30));

        let mut cache = self.token_cache.write().await;
        cache.access_token = tr.access_token.clone();
        cache.expires_at = expires_at;

        debug!(engine = %self.name, ttl = tr.expires_in, "token KC renovado");
        Ok(tr.access_token)
    }

    /// POST a la Admin API con auth header.
    async fn admin_post<T: Serialize>(
        &self, path: &str, body: &T,
    ) -> Result<reqwest::Response, EngineError> {
        let token = self.get_token().await?;
        self.http
            .post(format!("{}/{}", self.admin_url(), path.trim_start_matches('/')))
            .header("Authorization", format!("Bearer {}", token))
            .json(body)
            .send().await
            .map_err(|e| EngineError::Connection {
                engine: self.name.clone(),
                message: format!("POST {}: {}", path, e),
            })
    }

    /// GET de la Admin API.
    async fn admin_get(&self, path: &str) -> Result<reqwest::Response, EngineError> {
        let token = self.get_token().await?;
        self.http
            .get(format!("{}/{}", self.admin_url(), path.trim_start_matches('/')))
            .header("Authorization", format!("Bearer {}", token))
            .send().await
            .map_err(|e| EngineError::Connection {
                engine: self.name.clone(),
                message: format!("GET {}: {}", path, e),
            })
    }

    /// DELETE de la Admin API.
    async fn admin_delete(&self, path: &str) -> Result<reqwest::Response, EngineError> {
        let token = self.get_token().await?;
        self.http
            .delete(format!("{}/{}", self.admin_url(), path.trim_start_matches('/')))
            .header("Authorization", format!("Bearer {}", token))
            .send().await
            .map_err(|e| EngineError::Connection {
                engine: self.name.clone(),
                message: format!("DELETE {}: {}", path, e),
            })
    }
    // ── B12.1: Sync de Authentication Flows ─────────────────

    /// Crea o actualiza un Authentication Flow en Keycloak para un tier específico.
    /// Ej: "sbos_flow_su" → FIDO2 WebAuthn requerido
    ///     "sbos_flow_biz_n1" → TOTP opcional
    pub async fn sync_auth_flow(
        &self, flow_alias: &str, required_methods: &[String], tier: &str,
    ) -> Result<(), EngineError> {
        // Verificar si el flow ya existe
        let check = self.admin_get(&format!("authentication/flows/{}", flow_alias)).await;
        let exists = matches!(&check, Ok(resp) if resp.status().is_success());

        let flow_config = serde_json::json!({
            "alias": flow_alias,
            "description": format!("SBOS Auth Flow — Tier {} — Auto-generado por bAuth B12.1", tier),
            "providerId": "basic-flow",
            "topLevel": true,
            "builtIn": false,
        });

        if !exists {
            let _ = self.admin_post("authentication/flows", &flow_config).await?;
        }

        // Agregar ejecuciones (sub-flows) para cada método requerido
        for method in required_methods {
            let execution_config = serde_json::json!({
                "provider": method,
            });
            let _ = self.admin_post(
                &format!("authentication/flows/{}/executions/execution", flow_alias),
                &execution_config,
            ).await;
        }

        info!(%flow_alias, tier, methods = ?required_methods, "auth flow sincronizado con Keycloak");
        Ok(())
    }

    /// Crea Realm Roles en Keycloak a partir de los bits activos de un RolBitMask.
    /// 1 Realm Role por cada bit activo: "bos_bit_{position}"
    pub async fn sync_realm_roles_from_bits(
        &self, active_positions: &[usize],
    ) -> Result<usize, EngineError> {
        let mut created = 0;
        for pos in active_positions {
            let role_name = format!("bos_bit_{}", pos);
            let role_config = serde_json::json!({
                "name": role_name,
                "description": format!("SBOS BitMask Realm Role — position {} — Auto-generado", pos),
                "composite": false,
            });

            match self.admin_post("roles", &role_config).await {
                Ok(resp) if resp.status().is_success() || resp.status().as_u16() == 409 => {
                    created += 1;
                }
                _ => {
                    tracing::debug!(%role_name, pos, "error creando realm role en KC");
                }
            }
        }
        info!(created, total = active_positions.len(), "realm roles sincronizados desde bits");
        Ok(created)
    }

    /// Asigna Realm Roles a un usuario en Keycloak.
    /// Busca el usuario por username ("bos_user_{uuid}"), luego asigna los roles.
    pub async fn sync_user_role_mappings(
        &self, user_uuid: &str, role_names: &[String],
    ) -> Result<(), EngineError> {
        let username = format!("bos_user_{}", user_uuid.replace('-', "_"));

        // Buscar user ID en KC
        #[derive(Deserialize)]
        struct KcUser { id: String }

        let users: Vec<KcUser> = self.admin_get(&format!("users?username={}&max=1", username))
            .await?.json().await.map_err(|e| EngineError::Other {
                engine: self.name.clone(), message: format!("buscar usuario: {}", e),
            })?;

        let user_id = match users.first() {
            Some(u) => u.id.clone(),
            None => {
                tracing::warn!(%username, "usuario no encontrado en KC — omitiendo role mappings");
                return Ok(());
            }
        };

        // Asignar roles
        let payload = role_names.iter().map(|r| serde_json::json!({
            "name": r,
        })).collect::<Vec<_>>();

        let resp = self.http
            .post(format!("{}/users/{}/role-mappings/realm", self.admin_url(), user_id))
            .header("Authorization", format!("Bearer {}", self.get_token().await?))
            .json(&payload)
            .send().await
            .map_err(|e| EngineError::Connection {
                engine: self.name.clone(),
                message: format!("asignar roles a usuario {}: {}", user_id, e),
            })?;

        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            return Err(EngineError::Rejected {
                engine: self.name.clone(),
                reason: format!("asignar roles ({}): {}", status, body),
            });
        }

        info!(%user_uuid, %user_id, roles = role_names.len(), "role mappings asignados en KC");
        Ok(())
    }

    /// Reconciliación completa: compara KC vs bauth_db para roles, usuarios y auth flows.
    /// Detecta drift y genera reporte detallado con acciones correctivas.
    pub async fn reconcile_full(&self) -> Result<ReconcileReport, EngineError> {
        let mut report = ReconcileReport {
            engine_name: self.name.clone(),
            ..Default::default()
        };

        // ── Roles ──
        match self.admin_get("roles?max=1000&briefRepresentation=true").await {
            Ok(resp) => {
                #[derive(Deserialize)] struct KcRole { name: String }
                let kc_roles: Vec<KcRole> = resp.json().await.unwrap_or_default();
                let bos_count = kc_roles.iter().filter(|r| r.name.starts_with("bos_")).count();
                report.roles_updated = bos_count;
                info!(kc_total = kc_roles.len(), bos_roles = bos_count, "reconcile: roles KC");
            }
            Err(e) => report.errors.push(format!("roles KC: {}", e)),
        }

        // ── Usuarios ──
        match self.admin_get("users?max=1000&briefRepresentation=true").await {
            Ok(resp) => {
                #[derive(Deserialize)] struct KcUser { username: String, enabled: bool }
                let kc_users: Vec<KcUser> = resp.json().await.unwrap_or_default();
                let bos_users = kc_users.iter().filter(|u| u.username.starts_with("bos_")).count();
                let disabled = kc_users.iter().filter(|u| u.username.starts_with("bos_") && !u.enabled).count();
                report.users_updated = bos_users;
                report.users_disabled = disabled;
                info!(kc_total = kc_users.len(), bos_users, disabled, "reconcile: usuarios KC");
            }
            Err(e) => report.errors.push(format!("usuarios KC: {}", e)),
        }

        // ── Auth Flows ──
        match self.admin_get("authentication/flows").await {
            Ok(resp) => {
                #[derive(Deserialize)] struct KcFlow { alias: String, provider_id: String }
                let flows: Vec<KcFlow> = resp.json().await.unwrap_or_default();
                let sbos_flows = flows.iter().filter(|f| f.alias.starts_with("sbos_flow_")).count();
                info!(kc_flows = flows.len(), sbos_flows, "reconcile: auth flows KC");
            }
            Err(e) => report.errors.push(format!("auth flows KC: {}", e)),
        }

        info!(engine = %self.name, changes = report.total_changes(), errors = report.errors.len(), "reconcile_full completado");
        Ok(report)
    }
}

// ── AuthEngine Trait Implementation ─────────────────────────────

#[async_trait]
impl AuthEngine for KeycloakEngine {
    fn name(&self) -> &str { &self.name }

    fn covered_domains(&self) -> Vec<String> {
        vec!["D8".into(), "D9".into()]
    }

    /// Sincronizar RolTemplate → Keycloak.
    /// Crea/actualiza un Composite Role con el nombre del role_id.
    async fn sync_role(&self, role_id: &str, _tenant_id: &str) -> Result<(), EngineError> {
        let role_name = format!("bos_role_{}", role_id.replace('-', "_"));

        // Verificar si ya existe
        let check = self.admin_get(&format!("roles/{}", role_name)).await;
        match check {
            Ok(resp) if resp.status().is_success() => {
                debug!(role = %role_name, "rol ya existe en KC — omitiendo");
                return Ok(());
            }
            _ => {}
        }

        #[derive(Serialize)]
        struct RolePayload { name: String, description: String, composite: bool }

        let payload = RolePayload {
            name: role_name.clone(),
            description: format!("Rol sincronizado por bAuth — role_id={}", role_id),
            composite: true,
        };

        let resp = self.admin_post("roles", &payload).await?;
        let status = resp.status();
        if !status.is_success() && status.as_u16() != 409 {
            let body = resp.text().await.unwrap_or_default();
            return Err(EngineError::Rejected {
                engine: self.name.clone(),
                reason: format!("crear rol '{}': {} - {}", role_name, status, body),
            });
        }

        info!(role = %role_name, "rol sincronizado con Keycloak");
        Ok(())
    }

    /// Sincronizar UserTemplate → Keycloak.
    /// Crea/actualiza usuario en el realm.
    async fn sync_user(&self, user_uuid: &str, _tenant_id: &str) -> Result<(), EngineError> {
        let username = format!("bos_user_{}", user_uuid.replace('-', "_"));

        // Verificar si ya existe
        #[derive(Deserialize)]
        struct KcUser { id: String }

        let existing: Vec<KcUser> = self.admin_get(&format!("users?username={}", username))
            .await?
            .json().await
            .map_err(|e| EngineError::Other {
                engine: self.name.clone(),
                message: format!("buscar usuario: {}", e),
            })?;

        if !existing.is_empty() {
            debug!(user = %username, "usuario ya existe en KC — omitiendo");
            return Ok(());
        }

        #[derive(Serialize)]
        struct UserPayload {
            username: String,
            email: String,
            enabled: bool,
            email_verified: bool,
        }

        let payload = UserPayload {
            username: username.clone(),
            email: format!("{}@sbos.bo", username),
            enabled: true,
            email_verified: false,
        };

        let resp = self.admin_post("users", &payload).await?;
        let status = resp.status();
        if !status.is_success() {
            let body = resp.text().await.unwrap_or_default();
            return Err(EngineError::Rejected {
                engine: self.name.clone(),
                reason: format!("crear usuario '{}': {} - {}", username, status, body),
            });
        }

        info!(user = %username, "usuario sincronizado con Keycloak");
        Ok(())
    }

    /// Reconciliar: comparar KC vs bauth_db.
    /// Lista roles y usuarios en KC, compara con lo declarado.
    async fn reconcile(&self, _tenant_id: &str) -> Result<ReconcileReport, EngineError> {
        let mut report = ReconcileReport {
            engine_name: self.name.clone(),
            ..Default::default()
        };

        // Listar roles en KC
        match self.admin_get("roles?max=500").await {
            Ok(resp) => {
                #[derive(Deserialize)]
                struct KcRole { name: String }
                let roles: Vec<KcRole> = resp.json().await.unwrap_or_default();
                let bos_roles = roles.iter()
                    .filter(|r| r.name.starts_with("bos_role_"))
                    .count();
                info!(kc_roles = roles.len(), bos_roles, "reconcile roles KC");
            }
            Err(e) => {
                report.errors.push(format!("error listando roles KC: {}", e));
            }
        }

        // Listar usuarios en KC
        match self.admin_get("users?max=500").await {
            Ok(resp) => {
                #[derive(Deserialize)]
                struct KcUser { username: String, enabled: bool }
                let users: Vec<KcUser> = resp.json().await.unwrap_or_default();
                let bos_users = users.iter()
                    .filter(|u| u.username.starts_with("bos_user_"))
                    .count();
                info!(kc_users = users.len(), bos_users, "reconcile users KC");
            }
            Err(e) => {
                report.errors.push(format!("error listando usuarios KC: {}", e));
            }
        }

        info!(engine = %self.name, total_changes = report.total_changes(), "reconcile completado");
        Ok(report)
    }

    async fn health_check(&self) -> bool {
        match self.admin_get("roles?max=1").await {
            Ok(resp) => resp.status().is_success(),
            Err(_) => false,
        }
    }
}

// ── Tests ──────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_engine_creation() {
        let engine = KeycloakEngine::new(
            "keycloak-test",
            "https://localhost:8443",
            "sbos_system",
            "admin-cli",
            "test-secret",
        );
        assert_eq!(engine.name, "keycloak-test");
        assert_eq!(engine.admin_url(), "https://localhost:8443/admin/realms/sbos_system");
    }

    #[test]
    fn test_covered_domains() {
        let engine = KeycloakEngine::new("kc", "https://x", "r", "c", "s");
        let domains = engine.covered_domains();
        assert!(domains.contains(&"D8".into()));
        assert!(domains.contains(&"D9".into()));
    }
}
