// ============================================================
// bauth::server::handlers::blockchain_panel — B29.T20 Panel Blockchain
//
// Operaciones del panel de blockchain vía JSON-RPC:
//   listar lotes, ver detalle, verificar proof, publicar, eliminar
// Mismas operaciones que un botón en UI — todo por JSON-RPC.
// ============================================================
#![allow(dead_code)]
use crate::server::jsonrpc::{JsonRpcError, JsonRpcHandler};
use serde_json::Value;

// ─── Listar lotes de anclaje ─────────────────────────────────

pub struct AnchorBatchListHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for AnchorBatchListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError { code: -32000, message: "BD no disponible".into(), data: None })?;
        let limit = params.get("limit").and_then(|v| v.as_i64()).unwrap_or(50);
        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { batch_id: uuid::Uuid, merkle_root: Option<String>, event_count: i32, onchain_tx_hash: Option<String>, onchain_block_number: Option<i64>, anchored_at: Option<chrono::DateTime<chrono::Utc>>, created_at: chrono::DateTime<chrono::Utc>, status: i16 }
        let rows: Vec<Row> = sqlx::query_as("SELECT batch_id, merkle_root, event_count, onchain_tx_hash, onchain_block_number, anchored_at, created_at, status FROM bauth.blk_merkle_batch ORDER BY created_at DESC LIMIT $1")
            .bind(limit).fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        let list: Vec<Value> = rows.iter().map(|r| serde_json::json!({
            "batch_id": r.batch_id, "event_count": r.event_count, "status": r.status,
            "merkle_root": r.merkle_root,
            "txn_hash": r.onchain_tx_hash, "block_number": r.onchain_block_number,
            "anchored_at": r.anchored_at, "created_at": r.created_at
        })).collect();
        Ok(serde_json::json!({"batches": list, "count": list.len()}))
    }
}

// ─── Ver detalle de un lote ──────────────────────────────────

pub struct AnchorBatchDetailHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for AnchorBatchDetailHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError { code: -32000, message: "BD no disponible".into(), data: None })?;
        let batch_id = params.get("batch_id").and_then(|v| v.as_str())
            .and_then(|s| s.parse::<uuid::Uuid>().ok())
            .unwrap_or(uuid::Uuid::nil());
        #[derive(sqlx::FromRow, serde::Serialize)]
        struct LeafRow { leaf_index: i32, event_audit_id: uuid::Uuid, event_hash: Option<Vec<u8>>, merkle_proof: Option<Value> }
        let leaves: Vec<LeafRow> = sqlx::query_as("SELECT leaf_index, event_audit_id, event_hash, merkle_proof FROM bauth.blk_merkle_leaf WHERE batch_id = $1 ORDER BY leaf_index")
            .bind(batch_id).fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({
            "batch_id": batch_id,
            "total_leaves": leaves.len(),
            "leaves": leaves.iter().map(|l| serde_json::json!({
                "leaf_index": l.leaf_index, "event_id": l.event_audit_id,
                "leaf_hash": l.event_hash.as_ref().map(hex::encode),
                "has_proof": l.merkle_proof.is_some()
            })).collect::<Vec<_>>()
        }))
    }
}

// ─── Verificar un proof Merkle ───────────────────────────────

pub struct AnchorVerifyHandler;
#[async_trait::async_trait]
impl JsonRpcHandler for AnchorVerifyHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let merkle_root = params.get("merkle_root").and_then(|v| v.as_str()).unwrap_or("");
        let leaf_hash = params.get("leaf_hash").and_then(|v| v.as_str()).unwrap_or("");
        let proof_hashes: Vec<String> = params.get("proof_hashes").and_then(|v| v.as_array())
            .map(|arr| arr.iter().filter_map(|v| v.as_str().map(|s| s.to_string())).collect())
            .unwrap_or_default();

        if merkle_root.is_empty() || leaf_hash.is_empty() {
            return Ok(serde_json::json!({"verified": false, "reason": "merkle_root y leaf_hash requeridos"}));
        }

        // Reconstruir raíz Merkle (mismo algoritmo que bos-verify)
        let leaf_bytes = hex::decode(leaf_hash.strip_prefix("0x").unwrap_or(leaf_hash))
            .unwrap_or_default();
        if leaf_bytes.len() != 32 {
            return Ok(serde_json::json!({"verified": false, "reason": "leaf_hash debe ser 32 bytes"}));
        }
        let mut current = [0u8; 32];
        current.copy_from_slice(&leaf_bytes);

        for hash_hex in &proof_hashes {
            let sibling = hex::decode(hash_hex.strip_prefix("0x").unwrap_or(hash_hex)).unwrap_or_default();
            if sibling.len() == 32 {
                let mut sb = [0u8; 32]; sb.copy_from_slice(&sibling);
                use sha3::{Digest, Keccak256};
                let mut hasher = Keccak256::new();
                hasher.update([0x01u8]);
                if current < sb { hasher.update(current); hasher.update(sb); }
                else { hasher.update(sb); hasher.update(current); }
                current = hasher.finalize().into();
            }
        }

        let computed = format!("0x{}", hex::encode(current));
        let verified = computed == merkle_root.to_lowercase();
        Ok(serde_json::json!({"verified": verified, "computed_root": computed, "expected_root": merkle_root, "proof_depth": proof_hashes.len()}))
    }
}

// ─── Anclajes recientes (últimas 24h) ────────────────────────

pub struct AnchorRecentHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for AnchorRecentHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError { code: -32000, message: "BD no disponible".into(), data: None })?;
        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { batch_id: uuid::Uuid, event_count: i32, onchain_tx_hash: Option<String>, anchored_at: Option<chrono::DateTime<chrono::Utc>> }
        let rows: Vec<Row> = sqlx::query_as("SELECT batch_id, event_count, onchain_tx_hash, anchored_at FROM bauth.blk_merkle_batch WHERE anchored_at > now() - interval '24 hours' ORDER BY anchored_at DESC LIMIT 24")
            .fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({
            "ultimas_24h": rows.len(),
            "anclajes": rows.iter().map(|r| serde_json::json!({
                "batch_id": r.batch_id, "event_count": r.event_count,
                "txn_hash": r.onchain_tx_hash, "anchored_at": r.anchored_at
            })).collect::<Vec<_>>()
        }))
    }
}

// ─── Estado de la red blockchain ─────────────────────────────

pub struct BlockchainStatusHandler;
#[async_trait::async_trait]
impl JsonRpcHandler for BlockchainStatusHandler {
    async fn handle(&self, _params: Value) -> Result<Value, JsonRpcError> {
        Ok(serde_json::json!({
            "redes": {
                "arbitrum_one": {
                    "tipo": "anclaje",
                    "chain_id": 42161,
                    "rpc": "https://arb1.arbitrum.io/rpc",
                    "explorer": "https://arbiscan.io",
                    "estado": "operativo"
                },
                "arbitrum_sepolia": {
                    "tipo": "anclaje_testnet",
                    "chain_id": 421614,
                    "estado": "operativo"
                },
                "besu_qbft": {
                    "tipo": "liquidacion",
                    "validadores": 4,
                    "block_time_sec": 2,
                    "consenso": "QBFT",
                    "estado": "planificado"
                }
            },
            "smart_contracts": {
                "AuditAnchor": {"red": "arbitrum_one", "funciones": ["anchor(bytes32,uint256,uint256)","verify(uint256,bytes32)"], "gas_estimado": 45000},
                "SettlementEngine": {"red": "besu_qbft", "funciones": ["registerAccount()","settle(bytes32,address,address,uint256,bytes32)","freezeAccount()","balanceOf()"], "estado": "planificado"}
            }
        }))
    }
}

// ─── Liquidaciones recientes ────────────────────────────────

pub struct SettlementListHandler { pub pg_pool: Option<sqlx::PgPool> }
#[async_trait::async_trait]
impl JsonRpcHandler for SettlementListHandler {
    async fn handle(&self, params: Value) -> Result<Value, JsonRpcError> {
        let pg = self.pg_pool.as_ref().ok_or_else(|| JsonRpcError { code: -32000, message: "BD no disponible".into(), data: None })?;
        let limit = params.get("limit").and_then(|v| v.as_i64()).unwrap_or(50);
        #[derive(sqlx::FromRow, serde::Serialize)]
        struct Row { account_id: uuid::Uuid, tenant_id: uuid::Uuid, onchain_address: String, account_type: String, balance_derived: Option<serde_json::Value>, balance_local: Option<serde_json::Value>, is_frozen: bool, last_reconciled_at: Option<chrono::DateTime<chrono::Utc>>, created_at: chrono::DateTime<chrono::Utc> }
        let rows: Vec<Row> = sqlx::query_as("SELECT account_id, tenant_id, onchain_address, account_type, balance_derived, balance_local, is_frozen, last_reconciled_at, created_at FROM bauth.blk_account ORDER BY created_at DESC LIMIT $1")
            .bind(limit).fetch_all(pg).await.map_err(|e| JsonRpcError { code: -32000, message: e.to_string(), data: None })?;
        Ok(serde_json::json!({
            "accounts": rows.iter().map(|r| serde_json::json!({
                "account_id": r.account_id, "tenant_id": r.tenant_id,
                "address": r.onchain_address, "account_type": r.account_type,
                "balance_derived": r.balance_derived, "balance_local": r.balance_local,
                "is_frozen": r.is_frozen, "last_reconciled_at": r.last_reconciled_at,
                "created_at": r.created_at
            })).collect::<Vec<_>>(),
            "count": rows.len()
        }))
    }
}

// BigDecimal es un alias para sqlx::types::BigDecimal
