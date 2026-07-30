# A.65.03.01.13 — Informe de Completitud: D12 Anclaje Blockchain

**Versión:** 1.0.0 · **Fecha:** 2026-07-28
**Tipo:** Informe de completitud de dominio
**SSOT bloques:** `bauth.idn_roles_template` — VPS SBOSDB (path `skull.D12.*`)
**Estado de D12:** ❌ SIN IMPLEMENTAR — 0/7 bloques con tablas propias · 6 tablas propuestas (T-420..T-425)

> **Contexto:** bAuth usa Hyperledger Besu (QBFT) para anclaje de hashes de identidad. El nodo Besu vive en la infraestructura K8s del tenant; bAuth solo registra los metadatos del anclaje en SBOSDB y el wallet de firma ECDSA.
> **T-code range:** T-420..T-439 (prefijo `idn_blockchain_*`)

---

## 1. Estado global de D12

**Dominio:** Anclaje Blockchain (Hyperledger Besu QBFT · EIP-712 · W3C DID · Merkle)
**Total bloques:** 7 | **Tablas propias:** 0 | **Átomos:** 0

| Bloque | Slug | Nombre | Estado | T-code propuesto |
|--------|------|--------|--------|-----------------|
| B01 | `anchoring` | Anclaje Hash Merkle | ❌ FALTANTE | T-420 |
| B02 | `transactions` | Transacciones Besu | ❌ FALTANTE | T-421 |
| B03 | `wallet` | Gestión de Cartera Blockchain | ❌ FALTANTE | T-422 |
| B04 | `merkle` | Pruebas de Inclusión Merkle | ❌ FALTANTE | T-423 |
| B05 | `did` | Identidades Descentralizadas (DID) | ⚠️ PARCIAL | `idn_did_document` (T-169, D00) |
| B06 | `consensus` | Consenso QBFT | ❌ FALTANTE | T-424 |
| B07 | `business_zone` | Registro de Zona de Negocio (Blockchain) | árbol ✅ | — |

---

## 2. Análisis de bloques

### B05 — `did` (⚠️ PARCIAL)

`idn_did_document` (T-169, GAP-D00-05) existe y cubre DID resolver cache. Sin embargo, falta la tabla de resolución DID propiamente dicha para D12: los DIDs anclados en Besu (`did:besu:`) con sus DID Documents y sus actualizaciones.

### B01 — `anchoring` · Anclaje Hash Merkle

**Normas:** RFC 6962 §2.1 · EIP-712 · NIST SP 800-208

**Propósito:** Registro de cada operación de anclaje — qué hash se ancló, en qué bloque de Besu, con qué transaction hash. Permite verificar que un evento IAM (login, grant, revocación) fue anclado en la cadena.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_blockchain_anclaje (
    anclaje_id      UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    -- Qué se ancló
    tipo_objeto     TEXT NOT NULL CONSTRAINT chk_idba_tipo CHECK (tipo_objeto IN (
        'IDENTIDAD','GRANT','REVOCACION','AUDITORIA','VC','DID_DOCUMENT','FIRMA_DIGITAL')),
    objeto_id       UUID NOT NULL,           -- ID del objeto en SBOSDB
    objeto_hash     TEXT NOT NULL,           -- SHA-256 del estado del objeto
    -- Merkle tree
    merkle_root     TEXT NULL,               -- raíz del árbol Merkle del batch
    merkle_leaf     TEXT NOT NULL,           -- hoja específica de este objeto
    batch_id        UUID NULL,               -- lote de anclajes (si se batchea)
    -- Besu
    besu_tx_hash    TEXT NULL,               -- transaction hash en Besu
    besu_block      BIGINT NULL,             -- número de bloque
    besu_network_id TEXT NOT NULL DEFAULT 'sbos-mainnet',
    -- Estado
    estado          TEXT NOT NULL DEFAULT 'PENDIENTE'
        CONSTRAINT chk_idba_est CHECK (estado IN ('PENDIENTE','ENVIADO','CONFIRMADO','FALLIDO')),
    confirmaciones  INTEGER NOT NULL DEFAULT 0,
    anclado_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    confirmado_at   TIMESTAMPTZ NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system'
);
CREATE INDEX IF NOT EXISTS idx_idba_objeto ON bauth.idn_blockchain_anclaje(tipo_objeto, objeto_id);
CREATE INDEX IF NOT EXISTS idx_idba_tx     ON bauth.idn_blockchain_anclaje(besu_tx_hash) WHERE besu_tx_hash IS NOT NULL;
COMMENT ON TABLE bauth.idn_blockchain_anclaje IS
  '[T-420] [D12-B01] [RFC 6962 §2.1] [EIP-712] [NIST SP 800-208]
   Registro de anclajes hash en Hyperledger Besu. Permite verificar integridad sin ir a la cadena.';
```

### B02 — `transactions` · Transacciones Besu

**Normas:** Hyperledger Besu §6 · EIP-1559 · EIP-712

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_blockchain_transaccion (
    tx_id           UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    tipo            TEXT NOT NULL CONSTRAINT chk_idbt_tipo CHECK (tipo IN (
        'ANCHORING','DID_CREATE','DID_UPDATE','DID_DEACTIVATE','CREDENTIAL_ISSUE','REVOCATION')),
    tx_hash         TEXT NULL UNIQUE,
    from_address    TEXT NOT NULL,           -- dirección Ethereum del wallet
    to_address      TEXT NULL,               -- contrato destino
    payload_hash    TEXT NOT NULL,           -- SHA-256 del payload enviado
    gas_usado       BIGINT NULL,
    bloque          BIGINT NULL,
    estado          TEXT NOT NULL DEFAULT 'PENDIENTE'
        CONSTRAINT chk_idbt_est CHECK (estado IN ('PENDIENTE','MINADO','REVERTIDO','FALLIDO')),
    enviado_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    minado_at       TIMESTAMPTZ NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system'
);
COMMENT ON TABLE bauth.idn_blockchain_transaccion IS
  '[T-421] [D12-B02] [Hyperledger Besu §6] [EIP-1559] [EIP-712]
   Registro de transacciones Besu enviadas por bAuth (anclajes, DIDs, revocaciones).';
```

### B03 — `wallet` · Gestión de Cartera Blockchain

**Normas:** BIP-32/39/44 · EIP-712 · NIST SP 800-208

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_blockchain_wallet (
    wallet_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    tipo            TEXT NOT NULL DEFAULT 'SISTEMA'
        CONSTRAINT chk_idbw_tipo CHECK (tipo IN ('SISTEMA','TENANT','ACTOR')),
    actor_id        UUID NULL REFERENCES bauth.idn_identity_entity(entity_id),
    -- Dirección pública (el private key está en Vault)
    address_eth     TEXT NOT NULL,           -- checksum address EIP-55
    public_key_hex  TEXT NOT NULL,           -- clave pública ECDSA secp256k1
    vault_path      TEXT NOT NULL,           -- ruta al private key en Vault
    -- BIP-44: m/44'/60'/account'/change/index
    derivacion_path TEXT NULL,
    estado          TEXT NOT NULL DEFAULT 'ACTIVO'
        CONSTRAINT chk_idbw_est CHECK (estado IN ('ACTIVO','SUSPENDIDO','REVOCADO')),
    saldo_wei       NUMERIC(40,0) NULL,      -- saldo de gas (wei)
    ultimo_nonce    BIGINT NOT NULL DEFAULT 0,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, address_eth)
);
COMMENT ON TABLE bauth.idn_blockchain_wallet IS
  '[T-422] [D12-B03] [BIP-32/39/44] [EIP-712]
   Metadatos de wallets Ethereum. El private key vive en Vault. Dirección pública + nonce aquí.';
```

### B04 — `merkle` · Pruebas de Inclusión Merkle

**Normas:** RFC 6962 §2.1.1 · NIST SP 800-208 §3

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_blockchain_merkle_proof (
    proof_id        UUID PRIMARY KEY DEFAULT uuidv7(),
    anclaje_id      UUID NOT NULL REFERENCES bauth.idn_blockchain_anclaje(anclaje_id),
    merkle_root     TEXT NOT NULL,
    merkle_path     TEXT[] NOT NULL,         -- array de hashes del camino hasta la raíz
    merkle_index    INTEGER NOT NULL,        -- índice de la hoja
    verificado_at   TIMESTAMPTZ NULL,
    verificacion_ok BOOLEAN NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    generado_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_blockchain_merkle_proof IS
  '[T-423] [D12-B04] [RFC 6962 §2.1.1] [NIST SP 800-208 §3]
   Pruebas de inclusión Merkle para verificación offline de anclajes.';
```

### B06 — `consensus` · Consenso QBFT

**Normas:** Hyperledger Besu §4 · EIP-225

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_blockchain_nodo (
    nodo_id         UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    nombre          TEXT NOT NULL,
    enode_url       TEXT NOT NULL,           -- enode://pubkey@ip:port
    validator       BOOLEAN NOT NULL DEFAULT FALSE,
    estado          TEXT NOT NULL DEFAULT 'ACTIVO'
        CONSTRAINT chk_idbn_est CHECK (estado IN ('ACTIVO','INACTIVO','SINCRONIZANDO','FALLA')),
    ultimo_bloque   BIGINT NULL,
    ultimo_ping_at  TIMESTAMPTZ NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, enode_url)
);
COMMENT ON TABLE bauth.idn_blockchain_nodo IS
  '[T-424] [D12-B06] [Hyperledger Besu §4] [EIP-225]
   Inventario de nodos Besu QBFT del tenant. bAuth monitorea liveness y bloque más reciente.';
```

---

## 3. Checklist de completitud

- [ ] `idn_blockchain_anclaje` (T-420) ❌ PENDIENTE
- [ ] `idn_blockchain_transaccion` (T-421) ❌ PENDIENTE
- [ ] `idn_blockchain_wallet` (T-422) ❌ PENDIENTE (wallet de sistema al menos)
- [ ] `idn_blockchain_merkle_proof` (T-423) ❌ PENDIENTE
- [ ] `idn_blockchain_nodo` (T-424) ❌ PENDIENTE
- [x] `idn_did_document` (T-169) — B05 DID ⚠️ parcial ✅ en VPS
- [ ] Seeds: wallet de sistema `SBOS_SYSTEM` + nodo Besu por defecto
- [ ] Job: confirmar anclajes pendientes (query periódica al nodo Besu)
- [ ] Job: alertar nodo Besu con `ultimo_bloque` estancado > 5 min
- [ ] Átomos D12: `skull.D12.{anchoring,transactions,wallet,merkle,did,consensus}.*`

---

## 4. Análisis IAM Enterprise — D12

| Pilar IAM Enterprise | Criterio D12 | Estado |
|---|---|:---:|
| **VII Advanced** | Anclaje blockchain de identidad | ❌ L0 |
| **VII Advanced** | DID:Besu + W3C DID Core | ⚠️ L1 (T-169 existe) |
| **VI Standards** | NIST SP 800-208 / RFC 6962 / EIP-712 | ❌ L0 |
| **IV Machine Identity** | Wallets para identidades NHI | ❌ L0 |

**Gaps:**

| Gap | Prioridad | Acción |
|-----|-----------|--------|
| GAP-D12-01 — Sin motor de anclaje | 🟠 P2 | CREATE T-420 + T-421 |
| GAP-D12-02 — Wallet sistema sin tabla | 🟠 P2 | CREATE T-422 + seed sistema |
| GAP-D12-03 — Pruebas Merkle sin tabla | 🟡 P3 | CREATE T-423 |
| GAP-D12-04 — Inventario nodos Besu | 🟡 P3 | CREATE T-424 |
| GAP-D12-05 — Átomos D12 | 🟡 P3 | INSERT ~25 átomos |

**Veredicto: D12 L0-L1** — T-169 (DID) da L1 parcial. El motor de anclaje completo es trabajo P2.

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-28 | Versión inicial. 1/7 bloques parcial (B05 via T-169). DDL propuesto T-420..T-424. 5 gaps. Madurez D12: L0-L1. |
