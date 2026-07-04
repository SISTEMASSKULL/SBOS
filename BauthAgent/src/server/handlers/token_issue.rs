// ============================================================
// bauth::server::handlers::token_issue — B48.T03
//
// Handler: bauth.token.issue
// Emite un JWT de bAuth con todos los claims del Identity Control Plane.
//
// Pipeline:
//   1. Resolver user_uuid → RolBitMask (privilege_role_atom)
//   2. Resolver atom_slug → AtomBitMask (privilege_atom)
//   3. Construir claims con JwtBuilder
//   4. Firmar con Ed25519 (Vault PKI, B48.T02 pendiente)
//   5. Retornar JWT + metadata
//
// DOC-SBOS-001 N3 · BAUTH-VISION.md · RFC 7519
// ============================================================

#![allow(dead_code)]
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;
use std::collections::HashSet;
use tokio::sync::Mutex as TokioMutex;
use uuid::Uuid;

/// Cache de jti usados para anti-replay con TTL (RFC 8725bis).
/// Limpieza por timestamp, no clear() total.
static JTI_CACHE: std::sync::LazyLock<std::sync::Mutex<HashSet<(String, i64)>>> =
    std::sync::LazyLock::new(|| std::sync::Mutex::new(HashSet::new()));

/// Estado de la hash-chain forense (ISO 27001 A.8.15).
///
/// `last_hash` y `next_seq` viven juntos bajo un único TokioMutex.
/// Garantiza tres invariantes simultáneas:
///   I-1. Monotonicidad — next_seq siempre refleja el orden real de firma, no de llegada.
///   I-2. Sin bifurcaciones — ningún par de tokens puede compartir el mismo prev_hash.
///   I-3. Sin gaps — si sign() falla, el estado NO se actualiza; sin números de secuencia huérfanos.
///
/// Usar dos variables separadas (AtomicU64 + Mutex<Option<String>>) rompe I-1 e I-3:
///   - AtomicU64 se incrementa antes del lock → tarea B puede obtener seq=2 pero entrar
///     primero al lock, dejando a tarea A con seq=1 apuntando al hash de B (I-1 violada).
///   - Si sign() falla después del fetch_add, el seq queda consumido sin token (I-3 violada).
struct ChainState {
    last_hash: Option<String>,
    next_seq: u64,
}

static CHAIN_STATE: std::sync::LazyLock<TokioMutex<ChainState>> =
    std::sync::LazyLock::new(|| TokioMutex::new(ChainState { last_hash: None, next_seq: 1 }));

pub struct TokenIssueHandler {
    pub pg_pool: Option<sqlx::PgPool>,
    pub signer: std::sync::Arc<crate::domain::jwt_signer::JwtSigner>,
    pub jwt_cfg: crate::config::JwtConfig,
}

#[async_trait::async_trait]
impl JsonRpcHandler for TokenIssueHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError {
            code: -32000, message: "base de datos no disponible".into(), data: None,
        })?;

        let user_uuid = params.get("user_uuid").and_then(|v| v.as_str())
            .ok_or_else(|| JsonRpcError {
                code: -32602, message: "user_uuid requerido".into(), data: None,
            })?;

        let atom_slug = params.get("atom_slug").and_then(|v| v.as_str())
            .unwrap_or("sistema.sesion.activa");

        let audience: Option<Vec<String>> = params.get("audience")
            .and_then(|v| v.as_array())
            .map(|arr| arr.iter().filter_map(|v| v.as_str().map(String::from)).collect());

        let scope_str = params.get("scope").and_then(|v| v.as_str()).map(String::from);
        let client_id = params.get("client_id").and_then(|v| v.as_str()).map(String::from);
        let source_ip = params.get("source_ip").and_then(|v| v.as_str()).map(String::from);
        let source_mac = params.get("source_mac").and_then(|v| v.as_str()).map(String::from);
        let source_hostname = params.get("source_hostname").and_then(|v| v.as_str()).map(String::from);
        let network_zone = params.get("network_zone").and_then(|v| v.as_str()).map(String::from);
        let user_agent = params.get("user_agent").and_then(|v| v.as_str()).map(String::from);
        let dpop_proof = params.get("dpop").and_then(|v| v.as_str()).map(String::from);
        let _prev_jti = params.get("prev_jti").and_then(|v| v.as_str()).map(String::from);
        let encrypt_jwe = params.get("encrypt").and_then(|v| v.as_bool()).unwrap_or(false);

        // ── PASO 1: Cargar usuario + tenant juntos ───────────
        // Mejor práctica: tenant_id viene del registro del usuario, no de query global.
        let user_uuid_parsed = uuid::Uuid::parse_str(user_uuid).unwrap_or_else(|_| uuid::Uuid::nil());
        #[derive(sqlx::FromRow)]
        struct UserTenantRow {
            tenant_id: Option<String>,
            rol_bitmask_base64: Option<String>,
            rol_ids: Option<Vec<String>>,
        }
        let user_row = sqlx::query_as::<_, UserTenantRow>(
            "SELECT tenant_id, rol_bitmask_base64, rol_ids FROM bauth.idn_user_template WHERE uuid = $1"
        ).bind(user_uuid_parsed).fetch_optional(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error buscando usuario: {}", e), data: None,
        })?;

        let tenant_id = user_row.as_ref()
            .and_then(|u| u.tenant_id.clone())
            .filter(|t| !t.is_empty() && t != "*")
            .ok_or_else(|| JsonRpcError {
                code: -32000, message: "usuario sin tenant_id asignado".into(), data: None,
            })?;

        // ── PASO 2: Resolver RolBitMask del usuario ──────────
        // Reusar user_row del PASO 1 (misma consulta, sin duplicar)
        let (rol_base64, active_positions) = if let Some(ref um) = user_row {
            if let Some(ref b64) = um.rol_bitmask_base64 {
                if !b64.is_empty() && b64.len() > 2 {
                    // Usar bitmask precomputado desde idn_user_template
                    let mask = crate::bitmask::RolBitMask::from_base64(b64, 5808)
                        .unwrap_or_else(|_| crate::bitmask::RolBitMask::with_capacity(5808));
                    let positions: Vec<usize> = mask.active_positions().collect();
                    (b64.clone(), positions)
                } else {
                    // Sin bitmask: intentar computar desde los roles del usuario
                    compute_user_rolmask(pg, &um.rol_ids).await?
                }
            } else {
                compute_user_rolmask(pg, &um.rol_ids).await?
            }
        } else {
            // Usuario no encontrado en idn_user_template: fallback a computar por role_id directo
            let role_id = uuid::Uuid::parse_str(user_uuid).unwrap_or_else(|_| Uuid::nil());
            let rol_mask = crate::bitmask::resolver::compute_rol_bitmask(pg, role_id)
                .await
                .map_err(|e| JsonRpcError {
                    code: -32000, message: format!("error computando RolBitMask: {}", e), data: None,
                })?;
            let b64 = rol_mask.to_base64();
            let positions: Vec<usize> = rol_mask.active_positions().collect();
            (b64, positions)
        };

        // ── PASO 3: Resolver AtomBitMask ─────────────────────
        #[derive(sqlx::FromRow)]
        struct AtomRow { atom_position: i32, contextual_mask: i32, logical_mask: i32, atom_name: String }

        let atom: AtomRow = sqlx::query_as(
            "SELECT atom_position, contextual_mask, logical_mask, atom_name
             FROM bauth.privilege_atom WHERE atom_slug = $1"
        ).bind(atom_slug).fetch_optional(pg).await.map_err(|e| JsonRpcError {
            code: -32000, message: format!("error buscando átomo: {}", e), data: None,
        })?.unwrap_or(AtomRow {
            atom_position: 0, contextual_mask: 0, logical_mask: 0,
            atom_name: "sistema.sesion.activa".into(),
        });

        let atom_code: u64 = ((atom.contextual_mask as u64) << 32) | (atom.logical_mask as u64);
        let _atom_hex = format!("0x{:016x}", atom_code);

        // ── PASO 4: Construir claims con JwtBuilder ──────────
        // R16-001/002/003 FIX: defaults desde JwtConfig, override via params
        let issuer = params.get("issuer").and_then(|v| v.as_str()).unwrap_or(&self.jwt_cfg.issuer);
        let ttl = params.get("ttl_seconds").and_then(|v| v.as_i64()).unwrap_or(self.jwt_cfg.default_ttl_seconds);
        let loa = params.get("loa").and_then(|v| v.as_i64()).unwrap_or(self.jwt_cfg.default_loa as i64) as i32;

        let builder = crate::domain::jwt_builder::JwtBuilder::new(issuer, ttl);

        // Token liviano: sin RolBitMask ni AtomBitMask.
        // Permisos evaluados server-side vía access.evaluate(atom_slug, ctx_id).
        let ctx_id = format!("ctx-{}", Uuid::new_v4());
        let mut claims = builder.build_claims(
            user_uuid,
            &tenant_id,
            &ctx_id,
            loa,
            audience,
        );

        // ── PASO 5: Contexto de auth desde params ───────────
        let methods: Vec<String> = params.get("auth_methods")
            .and_then(|v| v.as_array())
            .map(|arr| arr.iter().filter_map(|v| v.as_str().map(String::from)).collect())
            .unwrap_or_else(|| vec!["password".into()]);
        let device_trust = params.get("device_trust").and_then(|v| v.as_str()).map(String::from);
        claims = crate::domain::jwt_builder::JwtBuilder::with_auth_context(
            claims,
            methods,
            device_trust,
            Some(Uuid::new_v4().to_string()),
            None,  // risk_score calculado por RiskEngine, no hardcodeado
        );

        // ── PASO 5b: Trazabilidad forense completa ──────────
        claims = crate::domain::jwt_builder::JwtBuilder::with_traceability(
            claims,
            source_ip, source_mac, source_hostname, network_zone,
            None, None, None, // geo, device_id, device_category (poblados por bhnexus)
            user_agent,
        );

        // ── PASO 5d: W3C Trace Context ──────────────────────
        let trace_id = hex::encode(&Uuid::new_v4().as_bytes()[..16]);
        let span_id = hex::encode(&Uuid::new_v4().as_bytes()[..8]);
        claims = crate::domain::jwt_builder::JwtBuilder::with_w3c_trace(
            claims, &trace_id, &span_id, true,
        );

        // ── PASO 5e: Cadena de autenticación desde params ──
        let auth_steps: Vec<crate::domain::jwt_builder::AuthStep> = params.get("auth_steps")
            .and_then(|v| v.as_array())
            .map(|arr| arr.iter().filter_map(|step| {
                Some(crate::domain::jwt_builder::AuthStep {
                    method: step.get("method")?.as_str()?.to_string(),
                    result: step.get("result")?.as_str()?.to_string(),
                    timestamp: chrono::Utc::now().to_rfc3339(),
                    loa_achieved: step.get("loa_achieved").and_then(|v| v.as_i64()).map(|v| v as i32),
                })
            }).collect())
            .unwrap_or_else(|| vec![crate::domain::jwt_builder::AuthStep {
                method: "password".into(), result: "PASS".into(),
                timestamp: chrono::Utc::now().to_rfc3339(), loa_achieved: Some(1),
            }]);
        claims = crate::domain::jwt_builder::JwtBuilder::with_auth_chain(claims, auth_steps);

        // ── PASO 5f: Compatibilidad OAuth2 ──────────────────
        claims = crate::domain::jwt_builder::JwtBuilder::with_oauth2_scope(
            claims,
            scope_str,
            client_id,
        );

        // ── PASOS 6-9: Sección crítica de hash-chain — mínima, atómica, sin I/O ──────
        //
        // Un único TokioMutex<ChainState> garantiza las tres invariantes (I-1, I-2, I-3).
        //
        // Qué entra en la sección crítica (todo síncrono, sin .await):
        //   - Leer prev_hash y seq
        //   - Aplicar claims hash-chain + DPoP
        //   - Firmar con Ed25519 via ring (~50 µs)
        //   - Computar SHA-256 del JWT firmado (~1 µs)
        //   - Escribir nuevo estado
        //
        // Qué queda FUERA (no bloquea emisiones concurrentes):
        //   - jti anti-replay (JTI_CACHE, std::Mutex instantáneo)
        //   - INSERT auditoría (.await sobre PostgreSQL)
        //   - Cifrado JWE opcional
        //   - Serialización de la respuesta JSON-RPC
        let (token_seq, signed, token_hash_bytes) = {
            let mut chain = CHAIN_STATE.lock().await;

            // I-1: seq y prev_hash leídos atómicamente — orden de firma = orden de chain
            let seq = chain.next_seq;
            let prev_hash = chain.last_hash.clone();

            claims = crate::domain::jwt_builder::JwtBuilder::with_hash_chain(
                claims, prev_hash, seq,
            );

            // DPoP: dpop_bound va en la respuesta JSON-RPC (línea ~360), no en claims del JWT

            // Firma síncrona Ed25519 (~50 µs con ring) — sin .await, seguro bajo el guard
            let signed = self.signer.sign(&claims).map_err(|e| JsonRpcError {
                code: -32000, message: format!("error firmando token: {}", e), data: None,
            })?;
            // I-3: si sign() propaga `?`, chain NO se actualiza → sin gap en seq ni en hash

            let hash_bytes: [u8; 32] = ring::digest::digest(
                &ring::digest::SHA256, signed.jwt.as_bytes()
            ).as_ref().try_into().unwrap_or([0u8; 32]);

            // I-2 + I-1: actualizar estado solo tras éxito completo de sign + hash
            chain.last_hash = Some(hex::encode(hash_bytes));
            chain.next_seq = seq + 1;

            (seq, signed, hash_bytes)
        }; // ← chain guard libera aquí — cadena lineal, siguiente emisión puede comenzar

        // ── PASO 8: jti anti-replay con TTL (RFC 8725bis) ──────────────────────────
        // Fuera del chain guard: no serializa emisiones concurrentes.
        // Si se detecta replay (UUID v4 collision ≈ 1 en 2^122), el hash ya fue commiteado
        // al chain — el intento queda trazado como eslabón sin token emitido correspondiente.
        {
            let mut cache = JTI_CACHE.lock().unwrap();
            let now_ts = chrono::Utc::now().timestamp();
            cache.retain(|(_, exp_ts)| *exp_ts > now_ts);
            if cache.iter().any(|(jti, _)| jti == &claims.jwt_id) {
                return Err(JsonRpcError {
                    code: -32009, message: "jti replay detectado — token ya fue emitido".into(),
                    data: None,
                });
            }
            cache.insert((claims.jwt_id.clone(), claims.expiration));
        }


        // El Merkle leaf se calcula y retorna. La persistencia en blk_merkle_batch/leaf
        // y el anclaje on-chain son responsabilidad del AnchorClient (B29),
        // que toma los hashes generados y los procesa en lote.
        let merkle_leaf = crate::domain::merkle::leaf_hash(&token_hash_bytes);

        // ── PASO 10: Vincular aud_event (ISO 27001 A.8.15) ────
        let _ = sqlx::query(
            "INSERT INTO bauth.aud_event (event_type, resource_type, resource_id, outcome, details, ctx_id)
             VALUES ('TOKEN_ISSUE', 'jwt', $1, 'SUCCESS', $2, $3)"
        )
        .bind(&claims.jwt_id)
        .bind(serde_json::json!({
            "sub": claims.subject,
            "scope": claims.scope,
            "client_id": claims.client_id,
            "token_seq": token_seq,
            "source_ip": claims.source_ip,
        }).to_string())
        .bind(&claims.ctx_id)
        .execute(pg)
        .await;

        // ── PASO 11: Serializar claims ────────────────────────
        let _claims_json = serde_json::to_value(&claims).map_err(|e| JsonRpcError {
            code: -32000, message: format!("error serializando claims: {}", e), data: None,
        })?;

        // ── PASO 11b: Cifrado JWE opcional (RFC 7516) ──
        let (token_value, _token_format, jwe_header) = if encrypt_jwe {
            let encryptor = crate::domain::jwe_encrypt::JweEncryptor::new_random();
            let jwe = encryptor.encrypt_jwt(&signed.jwt)
                .map_err(|e| JsonRpcError {
                    code: -32000, message: format!("error JWE: {}", e), data: None,
                })?;
            (jwe.compact, "JWE", Some(jwe.header_b64))
        } else {
            (signed.jwt, "JWT", None)
        };

        // ── CAPA 2: RolBitMask (opcional, para offline/contingencia) ──
        let rolbitmask_response = if params.get("include_mask").and_then(|v| v.as_bool()).unwrap_or(false) {
            Some(serde_json::json!({
                "base64": rol_base64,
                "active_positions": active_positions,
                "active_count": active_positions.len(),
            }))
        } else {
            None
        };

        Ok(serde_json::json!({
            "jwt": token_value,
            "jwt_size_chars": token_value.len(),
            "algorithm": signed.algorithm,
            "kid": signed.kid,
            "public_key_hex": self.signer.public_key_hex(),
            "header_b64": signed.header_b64,
            "payload_b64": signed.payload_b64,
            "signature_b64": signed.signature_b64,
            "issued_at": claims.issued_at,
            "expires_at": claims.expiration,
            "not_before": claims.not_before,
            "jti": claims.jwt_id,
            "token_seq": token_seq,
            "prev_hash": claims.prev_hash,
            "dpop_bound": dpop_proof.is_some(),
            "ttl_seconds": ttl,
            "subject": claims.subject,
            "issuer": claims.issuer,
            "ctx_id": claims.ctx_id,
            "loa": claims.level_of_assurance,
            "rolbitmask": rolbitmask_response,
            "merkle_leaf_keccak256": hex::encode(merkle_leaf),
            "token_sha256": hex::encode(token_hash_bytes),
            "jwe": jwe_header,
            "token_type": if encrypt_jwe { "JWE" } else { "JWT" },
        }))
    }
}

/// Computa el RolBitMask para un usuario a partir de sus rol_ids.
/// Busca cada rol en privilege_role y hace OR de los átomos asignados.
async fn compute_user_rolmask(
    pg: &sqlx::PgPool,
    rol_ids: &Option<Vec<String>>,
) -> Result<(String, Vec<usize>), JsonRpcError> {
    let ids = match rol_ids {
        Some(ids) if !ids.is_empty() => ids,
        _ => {
            let empty = crate::bitmask::RolBitMask::with_capacity(5808);
            return Ok((empty.to_base64(), vec![]));
        }
    };

    // Buscar cada rol en privilege_role por role_slug
    let mut masks: Vec<crate::bitmask::RolBitMask> = Vec::new();
    for slug in ids {
        #[derive(sqlx::FromRow)]
        struct RoleIdRow { role_id: uuid::Uuid }
        if let Ok(Some(row)) = sqlx::query_as::<_, RoleIdRow>(
            "SELECT role_id FROM bauth.privilege_role WHERE role_slug = $1"
        ).bind(slug).fetch_optional(pg).await {
            if let Ok(mask) = crate::bitmask::resolver::compute_rol_bitmask(pg, row.role_id).await {
                if mask.count_active() > 0 {
                    masks.push(mask);
                }
            }
        }
    }

    if masks.is_empty() {
        let empty = crate::bitmask::RolBitMask::with_capacity(5808);
        return Ok((empty.to_base64(), vec![]));
    }

    let refs: Vec<&crate::bitmask::RolBitMask> = masks.iter().collect();
    let merged = crate::bitmask::RolBitMask::merge(&refs)
        .unwrap_or_else(|| crate::bitmask::RolBitMask::with_capacity(5808));
    let positions: Vec<usize> = merged.active_positions().collect();
    Ok((merged.to_base64(), positions))
}
