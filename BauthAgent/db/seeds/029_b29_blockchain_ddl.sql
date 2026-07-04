-- B29.T01: Schema bos_blockchain — DDL 6 tablas para Variante A + B de D12
CREATE SCHEMA IF NOT EXISTS bos_blockchain;

-- Tabla de lotes Merkle anclados
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_merkle_batch (
    batch_id        BIGSERIAL PRIMARY KEY,
    merkle_root     BYTEA NOT NULL,
    batch_size      INTEGER NOT NULL CHECK (batch_size > 0),
    first_event_id  UUID NOT NULL,
    last_event_id   UUID NOT NULL,
    txn_hash        TEXT,
    block_number    BIGINT,
    anchored_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla de hojas Merkle individuales
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_merkle_leaf (
    leaf_id         BIGSERIAL PRIMARY KEY,
    batch_id        BIGINT NOT NULL REFERENCES bos_blockchain.bos_merkle_batch(batch_id),
    event_id        UUID NOT NULL,
    leaf_index      INTEGER NOT NULL,
    leaf_hash       BYTEA NOT NULL,
    proof_data      JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Log de anclajes blockchain
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_blockchain_anchor_log (
    anchor_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id        BIGINT NOT NULL REFERENCES bos_blockchain.bos_merkle_batch(batch_id),
    chain           TEXT NOT NULL DEFAULT 'arbitrum_sepolia',
    contract_addr   TEXT NOT NULL,
    txn_hash        TEXT NOT NULL,
    block_number    BIGINT,
    gas_used        BIGINT,
    status          TEXT NOT NULL CHECK (status IN ('pending','confirmed','failed')),
    confirmed_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Cuentas on-chain (Variante B: liquidación)
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_onchain_account (
    account_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL,
    address         TEXT NOT NULL UNIQUE,
    balance_local   NUMERIC(38,18) NOT NULL DEFAULT 0,
    balance_onchain NUMERIC(38,18),
    frozen          BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Liquidaciones on-chain
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_onchain_settlement (
    settlement_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_address    TEXT NOT NULL,
    to_address      TEXT NOT NULL,
    amount          NUMERIC(38,18) NOT NULL,
    txn_hash        TEXT,
    block_number    BIGINT,
    status          TEXT NOT NULL CHECK (status IN ('pending','submitted','confirmed','failed')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    confirmed_at    TIMESTAMPTZ
);

-- Reconciliación on-chain ↔ PostgreSQL
CREATE TABLE IF NOT EXISTS bos_blockchain.bos_reconciliation_log (
    reconciliation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id        UUID NOT NULL REFERENCES bos_blockchain.bos_onchain_account(account_id),
    balance_local     NUMERIC(38,18) NOT NULL,
    balance_onchain   NUMERIC(38,18) NOT NULL,
    diff              NUMERIC(38,18) NOT NULL,
    status            TEXT NOT NULL CHECK (status IN ('ok','drift_detected','corrected')),
    executed_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Función SQL: calcular Merkle root desde un lote (referencia)
CREATE OR REPLACE FUNCTION bos_blockchain.merkle_root_from_batch(p_batch_id BIGINT)
RETURNS BYTEA AS $$
DECLARE
    result BYTEA;
BEGIN
    SELECT merkle_root INTO result FROM bos_blockchain.bos_merkle_batch WHERE batch_id = p_batch_id;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Índices
CREATE INDEX IF NOT EXISTS idx_merkle_leaf_batch ON bos_blockchain.bos_merkle_leaf(batch_id);
CREATE INDEX IF NOT EXISTS idx_merkle_leaf_event ON bos_blockchain.bos_merkle_leaf(event_id);
CREATE INDEX IF NOT EXISTS idx_anchor_log_batch ON bos_blockchain.bos_blockchain_anchor_log(batch_id);
CREATE INDEX IF NOT EXISTS idx_anchor_log_status ON bos_blockchain.bos_blockchain_anchor_log(status);
CREATE INDEX IF NOT EXISTS idx_onchain_account_user ON bos_blockchain.bos_onchain_account(user_id);
CREATE INDEX IF NOT EXISTS idx_settlement_status ON bos_blockchain.bos_onchain_settlement(status);
CREATE INDEX IF NOT EXISTS idx_reconciliation_account ON bos_blockchain.bos_reconciliation_log(account_id);

SELECT 'bos_blockchain' as schema_name, count(*) as tables FROM information_schema.tables WHERE table_schema = 'bos_blockchain';
