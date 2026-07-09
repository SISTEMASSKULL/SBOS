# PRUEBA DE ESCRITORIO — 50 CASOS BLOCKCHAIN (D12)
## SKULL · SBOS · Junio 2026

**Objetivo:** Validar la DDL contra 50 casos complejos específicos del dominio D12 Blockchain — Variante A (anclaje Merkle), Variante B (liquidación on-chain), y transversales.

**Schemas verificados:** `bos_blockchain` (6 tablas), `bos_privilege` (9 tablas), `bauth` (varias)

---

## VARIANTE A: Anclaje Merkle (Casos 1-25)

### Caso 1: Recolectar eventos de auditoría para nuevo lote
```sql
SELECT audit_id, ctx_id, tenant_id, role_id, atom_position, bitmask_atom, policy_state, result, evaluated_at
FROM bos_privilege.bos_atom_audit
WHERE merkle_batch_id IS NULL
  AND evaluated_at >= NOW() - INTERVAL '1 hour'
ORDER BY evaluated_at
LIMIT 10000;
```
- bos_atom_audit (merkle_batch_id) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 2: Crear lote Merkle vacío (sin eventos — no debería ocurrir, pero manejar)
```sql
-- Gold tier: si no hay eventos, no crear lote
SELECT COUNT(*) FROM bos_privilege.bos_atom_audit WHERE merkle_batch_id IS NULL;
-- Si count = 0 → skip anchor cycle, log "no events to anchor"
```
- bos_atom_audit ✅
- **Veredicto: ✅ COMPLETO** (lógica en Rust)

### Caso 3: Crear lote Merkle con 5,000 eventos
```sql
BEGIN;
INSERT INTO bos_blockchain.bos_merkle_batch (batch_number, batch_start, batch_end, event_count, merkle_root, status)
VALUES (nextval('bos_merkle_batch_number_seq'), NOW() - INTERVAL '1 hour', NOW(), 5000, 'PENDING_ROOT', 0);
-- Obtener batch_id
-- INSERT 5000 filas en bos_merkle_leaf
INSERT INTO bos_blockchain.bos_merkle_leaf (batch_id, leaf_index, event_audit_id, event_hash)
SELECT 'new-batch-uuid', ROW_NUMBER() OVER (ORDER BY evaluated_at) - 1, audit_id, encode(digest(audit_id::text || ctx_id || evaluated_at::text, 'keccak256'), 'hex')
FROM bos_privilege.bos_atom_audit WHERE merkle_batch_id IS NULL LIMIT 5000;
COMMIT;
```
- bos_merkle_batch ✅ · bos_merkle_leaf ✅
- **Veredicto: ✅ COMPLETO**

### Caso 4: Construir Merkle tree con número IMPAR de hojas (última se duplica)
```sql
-- 5001 eventos → k = 4096 (potencia de 2 más cercana)
-- Última hoja (leaf_index=5000) se duplica para balancear
SELECT bos_blockchain.merkle_root_from_batch('batch-uuid');
```
- merkle_root_from_batch() ✅ (maneja impares duplicando)
- **Veredicto: ✅ COMPLETO**

### Caso 5: Sellar lote — calcular Merkle root final
```sql
UPDATE bos_blockchain.bos_merkle_batch 
SET merkle_root = bos_blockchain.merkle_root_from_batch(batch_id),
    status = 1,
    sealed_at = NOW()
WHERE batch_id = ? AND status = 0;
```
- bos_merkle_batch ✅ · merkle_root_from_batch() ✅
- **Veredicto: ✅ COMPLETO**

### Caso 6: Enviar transacción de anclaje a Arbitrum One
```sql
-- ethers-rs: enviar tx a AuditAnchor.anchor(merkle_root, batch_id, event_count)
-- Esperar confirmación (1 bloque ~250ms en Arbitrum)
-- Al recibir receipt:
INSERT INTO bos_blockchain.bos_blockchain_anchor_log (batch_id, tx_hash, block_number, block_timestamp, network, contract_address, gas_used, gas_price_gwei, total_cost_usd, status)
VALUES ('batch-uuid', '0xabc123...', 19500000, NOW(), 'arbitrum', '0xContractAddr', 45000, 0.01, 0.0002, 1);
UPDATE bos_blockchain.bos_merkle_batch SET status = 2, onchain_tx_hash = '0xabc123...', onchain_block_number = 19500000, onchain_timestamp = NOW(), anchored_at = NOW()
WHERE batch_id = 'batch-uuid';
```
- bos_blockchain_anchor_log ✅ · bos_merkle_batch (status, onchain_tx_hash, anchored_at) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 7: Anclaje fallido — reintento con exponential backoff
```sql
-- Intento 1: RPC timeout
UPDATE bos_blockchain.bos_merkle_batch SET retry_count = 1, last_error = 'RPC timeout after 30s' WHERE batch_id = ?;
-- Intento 2 (2s después): RPC timeout again
UPDATE bos_blockchain.bos_merkle_batch SET retry_count = 2, last_error = 'RPC timeout' WHERE batch_id = ?;
-- Intento 5 (32s después): agotados reintentos → dead letter
UPDATE bos_blockchain.bos_merkle_batch SET status = 3, last_error = 'Max retries (5) exhausted' WHERE batch_id = ?;
-- Alerta P1: "Anchor batch #42 FAILED after 5 retries"
```
- bos_merkle_batch (retry_count, last_error, status=3) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 8: Reanudar lote fallido después de intervención manual
```sql
-- Admin investiga, resuelve problema de RPC, re-intenta
UPDATE bos_blockchain.bos_merkle_batch SET status = 1, retry_count = 0, last_error = NULL WHERE batch_id = ? AND status = 3;
-- Re-ejecutar anclaje (Caso 6)
```
- bos_merkle_batch ✅
- **Veredicto: ✅ COMPLETO**

### Caso 9: Verificar anclaje — dado ctx_id, encontrar prueba blockchain
```sql
SELECT a.audit_id, a.ctx_id, a.evaluated_at, a.result,
       b.batch_number, b.merkle_root, b.onchain_tx_hash, b.onchain_block_number,
       l.leaf_index, l.merkle_proof,
       al.tx_hash as anchor_tx, al.block_number, al.block_timestamp, al.network
FROM bos_privilege.bos_atom_audit a
JOIN bos_blockchain.bos_merkle_leaf l ON a.audit_id = l.event_audit_id
JOIN bos_blockchain.bos_merkle_batch b ON l.batch_id = b.batch_id
JOIN bos_blockchain.bos_blockchain_anchor_log al ON b.batch_id = al.batch_id
WHERE a.ctx_id = 'ctx_abc123'
ORDER BY a.evaluated_at;
```
- bos_atom_audit ✅ · bos_merkle_leaf ✅ · bos_merkle_batch ✅ · bos_blockchain_anchor_log ✅
- **Veredicto: ✅ COMPLETO**

### Caso 10: Verificador externo — reconstruir Merkle root desde proof
```bash
# Sin acceso a la BD de SBOS. Solo con:
# 1. JSON del evento
# 2. Merkle proof (array de hashes)
# 3. Número de bloque en Arbitrum
bos-verify onchain --rpc https://arb1.arbitrum.io/rpc --contract 0xSBOSContract --batch-id 42 --merkle-root 0xroot
# Verifica:
# 1. Recalcula leaf hash = Keccak256(0x00 || serialize(event))
# 2. Recorre merkle_proof → reconstruye root
# 3. Consulta AuditAnchor.verify(batchId, merkleRoot) en Arbitrum
# 4. Retorna: ✅ VERIFIED — Block #19500000, 2026-06-21T15:00:00Z
```
- bos_merkle_leaf (merkle_proof) ✅ · bos_merkle_batch (merkle_root, onchain_block_number) ✅
- AuditAnchor contract (externo Arbitrum) ✅
- **Veredicto: ✅ COMPLETO** (verificación externa, no requiere acceso a BD)

### Caso 11: Lote de tamaño máximo — 100,000 eventos
```sql
-- Gold tier: si el lote alcanza 100K eventos antes de 1h, sellar anticipadamente
SELECT COUNT(*) FROM bos_blockchain.bos_merkle_leaf WHERE batch_id = ?;
-- Si count >= 100000 → sellar y anclar
```
- bos_merkle_leaf ✅
- **Veredicto: ✅ COMPLETO**

### Caso 12: Métricas de anclaje — Prometheus
```sql
-- anchor_success_total (counter)
SELECT COUNT(*) FROM bos_blockchain.bos_blockchain_anchor_log WHERE status = 1 AND created_at > NOW() - INTERVAL '24 hours';
-- anchor_latency_seconds (histogram)
SELECT AVG(EXTRACT(EPOCH FROM (anchored_at - sealed_at))) FROM bos_blockchain.bos_merkle_batch WHERE status = 2 AND anchored_at > NOW() - INTERVAL '24 hours';
-- anchor_gas_used_total (counter)
SELECT SUM(gas_used) FROM bos_blockchain.bos_blockchain_anchor_log WHERE created_at > NOW() - INTERVAL '24 hours';
-- eventos pendientes sin anclar
SELECT COUNT(*) FROM bos_privilege.bos_atom_audit WHERE merkle_batch_id IS NULL;
```
- bos_blockchain_anchor_log ✅ · bos_merkle_batch ✅ · bos_atom_audit ✅
- **Veredicto: ✅ COMPLETO**

### Caso 13: Multi-red — cambiar de Arbitrum a otra L2 (ej: Base)
```sql
-- Nuevos anclajes van a Base
INSERT INTO bos_blockchain.bos_blockchain_anchor_log (batch_id, tx_hash, block_number, block_timestamp, network, contract_address, status)
VALUES (?, '0xBaseTx...', 25000000, NOW(), 'base', '0xBaseContractAddr', 1);
-- Anclajes históricos en Arbitrum permanecen verificables
SELECT network, COUNT(*) FROM bos_blockchain.bos_blockchain_anchor_log GROUP BY network;
```
- bos_blockchain_anchor_log (network) ✅
- **Veredicto: ✅ COMPLETO** (network field permite múltiples L2)

### Caso 14: Gas cost tracking — presupuesto mensual
```sql
SELECT DATE_TRUNC('month', created_at) as mes,
       COUNT(*) as anchors,
       SUM(gas_used) as total_gas,
       SUM(total_cost_usd) as total_cost_usd
FROM bos_blockchain.bos_blockchain_anchor_log
WHERE created_at > NOW() - INTERVAL '12 months'
GROUP BY mes ORDER BY mes;
```
- bos_blockchain_anchor_log (total_cost_usd) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 15: Merkle proof verification — batch consistency check
```sql
-- Verificar que todas las hojas de un lote producen el Merkle root almacenado
SELECT b.batch_id, b.merkle_root, bos_blockchain.merkle_root_from_batch(b.batch_id) as recalculated_root
FROM bos_blockchain.bos_merkle_batch b
WHERE b.status IN (1, 2)
  AND b.merkle_root != bos_blockchain.merkle_root_from_batch(b.batch_id);
-- Si devuelve filas → inconsistencia → alerta P1
```
- merkle_root_from_batch() ✅ · bos_merkle_batch ✅
- **Veredicto: ✅ COMPLETO**

### Caso 16: Batch re-processing — re-sellar lote después de corrección de datos
```sql
-- Evento de auditoría fue corregido (ej: cambió policy_state de 01 a 10)
-- Reconstruir lote completo
DELETE FROM bos_blockchain.bos_merkle_leaf WHERE batch_id = ?;
-- Re-insertar hojas con hashes actualizados
-- Re-calcular Merkle root
-- Re-anclar (nuevo anclaje, el anterior queda como histórico)
```
- bos_merkle_leaf ✅ · bos_merkle_batch ✅
- **Veredicto: ⚠️ ¿Se permite DELETE en bos_merkle_leaf?** La tabla es operacional, no WORM.
- **Veredicto: ✅ COMPLETO** (operación administrativa válida)

### Caso 17: Anclaje Platinum tier — cada 10 minutos para transacciones >$10K
```sql
INSERT INTO bos_blockchain.bos_merkle_batch (batch_number, batch_start, batch_end, event_count, merkle_root, status)
VALUES (nextval('bos_merkle_batch_number_seq'), NOW() - INTERVAL '10 minutes', NOW(), 150, 'PENDING_ROOT', 0);
-- Solo eventos con severity='CRITICAL' o monto > $10K
```
- bos_merkle_batch ✅
- **Veredicto: ✅ COMPLETO** (configurable vía POL-D12-ANCHOR)

### Caso 18: Silver tier — diario para eventos de baja criticidad
```sql
INSERT INTO bos_blockchain.bos_merkle_batch (batch_number, batch_start, batch_end, event_count, merkle_root, status)
VALUES (nextval('bos_merkle_batch_number_seq'), NOW() - INTERVAL '24 hours', NOW(), 50000, 'PENDING_ROOT', 0);
```
- bos_merkle_batch ✅
- **Veredicto: ✅ COMPLETO**

### Caso 19: Anclaje multi-tenant — tenant isolation en lotes
```sql
-- Un lote por tenant (opcional)
SELECT tenant_id, COUNT(*) FROM bos_privilege.bos_atom_audit WHERE merkle_batch_id IS NULL GROUP BY tenant_id;
-- Crear lote por tenant si > 1000 eventos
```
- bos_atom_audit (tenant_id) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 20: Prueba de inclusión — demostrar que un evento está en el lote
```sql
SELECT l.leaf_index, l.merkle_proof, b.merkle_root, b.onchain_tx_hash, b.onchain_block_number
FROM bos_blockchain.bos_merkle_leaf l
JOIN bos_blockchain.bos_merkle_batch b ON l.batch_id = b.batch_id
WHERE l.event_audit_id = 'specific-audit-uuid';
-- El merkle_proof permite verificar sin revelar los otros eventos
```
- bos_merkle_leaf (merkle_proof) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 21: Prueba de exclusión — demostrar que un evento NO está en el lote
```sql
-- Si event_audit_id no aparece en bos_merkle_leaf para ese batch → no está
SELECT COUNT(*) FROM bos_blockchain.bos_merkle_leaf 
WHERE batch_id = ? AND event_audit_id = 'specific-audit-uuid';
-- Si count = 0 → el evento NO fue anclado en ese lote
```
- bos_merkle_leaf ✅
- **Veredicto: ✅ COMPLETO**

### Caso 22: Anclaje cross-chain — mismo lote en Arbitrum + Bitcoin (OpenTimestamps)
```sql
-- Arbitrum: anchor principal (rápido, ~$0.0002)
INSERT INTO bos_blockchain.bos_blockchain_anchor_log (batch_id, tx_hash, block_number, network, contract_address, status)
VALUES (?, '0xArbTx...', 19500000, 'arbitrum', '0xArbContract', 1);
-- Bitcoin OTS: anchor secundario (lento, gratuito, máxima seguridad)
INSERT INTO bos_blockchain.bos_blockchain_anchor_log (batch_id, tx_hash, block_number, network, contract_address, status)
VALUES (?, '0xBtcTx...', 935777, 'bitcoin-ots', 'N/A', 1);
-- Ambos son verificables independientemente
```
- bos_blockchain_anchor_log (network permite múltiples) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 23: Lote vacío después de sellado — error de integridad
```sql
-- Verificar que un lote sellado (status=1) tiene al menos 1 hoja
SELECT b.batch_id, COUNT(l.leaf_id) as leaf_count
FROM bos_blockchain.bos_merkle_batch b
LEFT JOIN bos_blockchain.bos_merkle_leaf l ON b.batch_id = l.batch_id
WHERE b.status IN (1, 2)
GROUP BY b.batch_id
HAVING COUNT(l.leaf_id) = 0;
-- Si hay lotes sellados sin hojas → error → alerta P1
```
- bos_merkle_batch ✅ · bos_merkle_leaf ✅
- **Veredicto: ✅ COMPLETO**

### Caso 24: Reconciliación de anclajes — comparar DB local vs Arbitrum
```sql
-- Para cada lote anclado (status=2), verificar que el Merkle root en Arbitrum coincide
-- (requiere consulta externa a Arbitrum RPC)
-- Si divergencia → registrar
INSERT INTO bos_blockchain.bos_reconciliation_log (account_id, balance_onchain, balance_local, difference, block_number, status, notes)
VALUES ('00000000-0000-0000-0000-000000000000', 0, 0, 0, 0, 1, 'Anchor batch #42: DB root 0xroot1 != Arbitrum root 0xroot2');
```
- bos_reconciliation_log ⚠️ no está diseñada para reconciliación de anclajes (es para cuentas on-chain)
- **Veredicto: ⚠️ REQUIERE** `bos_anchor_reconciliation_log` o usar metadata en bos_merkle_batch

### Caso 25: Auditoría forense — reconstruir timeline completo desde blockchain
```sql
-- Dado un rango de fechas, recuperar todos los anclajes
SELECT al.block_number, al.block_timestamp, al.tx_hash, b.batch_number, b.event_count, b.merkle_root
FROM bos_blockchain.bos_blockchain_anchor_log al
JOIN bos_blockchain.bos_merkle_batch b ON al.batch_id = b.batch_id
WHERE al.block_timestamp BETWEEN '2026-06-01' AND '2026-06-30'
ORDER BY al.block_number;
-- Cada lote → recuperar eventos → reconstruir timeline completo
```
- bos_blockchain_anchor_log ✅ · bos_merkle_batch ✅
- **Veredicto: ✅ COMPLETO**

---

## VARIANTE B: Liquidación On-Chain (Casos 26-45)

### Caso 26: Registrar cuenta on-chain para tenant
```sql
INSERT INTO bos_blockchain.bos_onchain_account (tenant_id, onchain_address, account_type, balance_derived, balance_local)
VALUES (?, '0xAcmeCorpAddress...', 1, 1000000.00, 1000000.00);
```
- bos_onchain_account ✅
- **Veredicto: ✅ COMPLETO**

### Caso 27: Ejecutar liquidación on-chain — flujo completo con doble firma
```sql
-- 1. Fast-Path: verificar Rol BitMask (bos_role_atom)
-- 2. Policy-Path D3: verificar límites (bos_financial_limit, bos_financial_decision_matrix)
-- 3. Dual-approval: crear solicitud (bos_financial_approval)
-- 4. Segundo firmante aprueba
-- 5. Enviar tx a Besu QBFT: SettlementEngine.settle(settlementId, from, to, amount, dualApprovalId)
-- 6. Esperar 1 confirmación (2s en QBFT)
-- 7. Registrar:
INSERT INTO bos_blockchain.bos_onchain_settlement (from_account_id, to_account_id, amount, currency, onchain_tx_hash, block_number, block_confirmations, status, dual_approval_id, ctx_id_creator, ctx_id_approver)
VALUES (?, ?, 5000, 'BOB', '0xBesuTxHash...', 12345, 1, 1, ?, 'ctx_creator', 'ctx_approver');
-- 8. Actualizar balances locales
UPDATE bos_blockchain.bos_onchain_account SET balance_local = balance_local - 5000 WHERE account_id = ?;
UPDATE bos_blockchain.bos_onchain_account SET balance_local = balance_local + 5000 WHERE account_id = ?;
-- 9. Auditoría
INSERT INTO bos_privilege.bos_atom_audit (ctx_id, tenant_id, role_id, app_code, group_code, atom_code, atom_position, bitmask_atom, policy_state, result, evaluator, domain_code)
VALUES ('ctx_creator', ?, ?, 0, 0, 3, 100, 0x..., 2, 1, 'bauth', 12);
```
- bos_onchain_account ✅ · bos_onchain_settlement ✅ · bos_financial_approval (dual_approval_id FK) ✅ · bos_atom_audit ✅
- **Veredicto: ✅ COMPLETO**

### Caso 28: Liquidación pendiente — esperando confirmaciones
```sql
-- Tx enviada a Besu, esperando confirmaciones
INSERT INTO bos_blockchain.bos_onchain_settlement (from_account_id, to_account_id, amount, currency, onchain_tx_hash, block_number, block_confirmations, status, dual_approval_id, ctx_id_creator)
VALUES (?, ?, 5000, 'BOB', '0xPendingTx...', 12345, 0, 0, ?, 'ctx_creator');
-- Job de monitoreo: cada 2s verificar confirmaciones
UPDATE bos_blockchain.bos_onchain_settlement SET block_confirmations = 1, status = 1, confirmed_at = NOW()
WHERE settlement_id = ? AND block_confirmations = 0;
```
- bos_onchain_settlement (block_confirmations, status=0→1) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 29: Liquidación fallida — tx revertida en Besu
```sql
UPDATE bos_blockchain.bos_onchain_settlement SET status = 2
WHERE settlement_id = ?;
-- Revertir balances locales
UPDATE bos_blockchain.bos_onchain_account SET balance_local = balance_local + 5000 WHERE account_id = ?;
UPDATE bos_blockchain.bos_onchain_account SET balance_local = balance_local - 5000 WHERE account_id = ?;
-- Notificar al creador
-- Auditoría
```
- bos_onchain_settlement (status=2) ✅ · bos_onchain_account ✅
- **Veredicto: ✅ COMPLETO**

### Caso 30: Reconciliación periódica on-chain ↔ PostgreSQL
```sql
-- Para cada cuenta activa:
SELECT account_id, onchain_address FROM bos_blockchain.bos_onchain_account WHERE is_frozen = FALSE;
-- Consultar SettlementEngine.balanceOf(address) → balance_onchain
-- Comparar con balance_local
INSERT INTO bos_blockchain.bos_reconciliation_log (account_id, balance_onchain, balance_local, difference, block_number, status)
VALUES (?, 5000.00, 4999.99, 0.01, 12345, 0);  -- diff < umbral → matched
-- Si diff > umbral → forensic replay
```
- bos_reconciliation_log ✅
- **Veredicto: ✅ COMPLETO**

### Caso 31: Forensic replay — reconstruir saldo desde eventos on-chain
```sql
-- Si diff > umbral en reconciliación, reconstruir saldo desde SettlementExecuted events
SELECT SUM(CASE WHEN to_account_id = ? THEN amount ELSE -amount END) as reconstructed_balance
FROM bos_blockchain.bos_onchain_settlement
WHERE (from_account_id = ? OR to_account_id = ?) AND status = 1 AND block_number > ?
ORDER BY block_number;
-- Comparar con balance_onchain y balance_local
-- Identificar transacción faltante/sobrante
```
- bos_onchain_settlement ✅
- **Veredicto: ✅ COMPLETO**

### Caso 32: Congelar cuenta — emergencia
```sql
UPDATE bos_blockchain.bos_onchain_account SET is_frozen = TRUE WHERE account_id = ?;
-- Enviar tx a Besu: SettlementEngine.freezeAccount(address, "Actividad sospechosa detectada")
INSERT INTO bauth.bauth_audit_events (event_type, severity, action, resource_type, resource_id, outcome, details, ctx_id)
VALUES ('account_frozen', 'HIGH', 'freeze', 'onchain_account', ?, 'SUCCESS', '{"reason": "Actividad sospechosa detectada", "frozen_by": "S003"}', ?);
```
- bos_onchain_account (is_frozen) ✅ · bauth_audit_events ✅
- **Veredicto: ✅ COMPLETO**

### Caso 33: Descongelar cuenta — después de investigación
```sql
UPDATE bos_blockchain.bos_onchain_account SET is_frozen = FALSE WHERE account_id = ?;
-- Besu: SettlementEngine.unfreezeAccount(address)
INSERT INTO bauth.bauth_audit_events (event_type, severity, action, resource_type, resource_id, outcome, details, ctx_id)
VALUES ('account_unfrozen', 'HIGH', 'unfreeze', 'onchain_account', ?, 'SUCCESS', '{"reason": "Investigación completada - sin hallazgos", "unfrozen_by": "S003"}', ?);
```
- bos_onchain_account ✅
- **Veredicto: ✅ COMPLETO**

### Caso 34: Double-spend prevention — settlementId anti-replay
```sql
-- Antes de enviar tx a Besu, verificar que settlementId no fue usado
SELECT COUNT(*) FROM bos_blockchain.bos_onchain_settlement WHERE onchain_tx_hash IS NOT NULL AND onchain_tx_hash = '0xTxHash...';
-- Si count > 0 → posible replay → alerta P1
-- El contrato SettlementEngine también verifica executedSettlements[settlementId]
```
- bos_onchain_settlement ✅ · SettlementEngine (externo) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 35: Migración Fase 1 — doble contabilidad PostgreSQL + Besu
```sql
-- Cada operación escribe en AMBOS sistemas
-- 1. PostgreSQL (fuente de verdad durante Fase 1)
UPDATE bos_blockchain.bos_onchain_account SET balance_local = balance_local - 5000 WHERE account_id = ?;
-- 2. Besu (réplica)
-- SettlementEngine.settle(...) → on-chain
-- 3. Verificar consistencia
INSERT INTO bos_blockchain.bos_reconciliation_log (account_id, balance_onchain, balance_local, difference, block_number, status)
VALUES (?, 5000, 5000, 0, 12345, 0);  -- matched
```
- bos_onchain_account ✅ · bos_onchain_settlement ✅ · bos_reconciliation_log ✅
- **Veredicto: ✅ COMPLETO**

### Caso 36: Migración Fase 2 — Besu como fuente, PostgreSQL caché
```sql
-- Besu se convierte en fuente de verdad
-- PostgreSQL se actualiza después (eventual consistency)
-- Leer balance de Besu: SettlementEngine.balanceOf(address)
-- Actualizar caché local:
UPDATE bos_blockchain.bos_onchain_account 
SET balance_derived = ?, balance_local = ?, last_reconciled_at = NOW(), last_reconciled_block = ?
WHERE account_id = ?;
```
- bos_onchain_account (balance_derived, balance_local, last_reconciled_at, last_reconciled_block) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 37: Rollback de migración — revertir a Fase 0
```sql
-- Si se detectan divergencias no explicables > 0.1%
-- Ignorar Besu temporalmente, PostgreSQL vuelve a ser fuente
-- No se pierden datos: Besu es inmutable, PostgreSQL se puede reconstruir
UPDATE bos_blockchain.bos_onchain_account SET balance_local = balance_derived WHERE account_id IN (SELECT account_id FROM bos_blockchain.bos_reconciliation_log WHERE status = 1 AND reconciled_at > NOW() - INTERVAL '24 hours');
```
- bos_onchain_account ✅ · bos_reconciliation_log ✅
- **Veredicto: ✅ COMPLETO**

### Caso 38: Validator governance — añadir nuevo validador
```sql
-- Votación QBFT: ≥⅔ votan TRUE → nuevo validador activo
-- Registrar en metadatos
UPDATE bos_blockchain.bos_onchain_account 
SET metadata = metadata || '{"validator_added": {"address": "0xNewValidator", "voted_at_block": 12345, "votes_for": 3, "votes_against": 0}}'
WHERE account_type = 4;  -- 4 = emisor/operador
```
- bos_onchain_account (metadata JSONB) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 39: Validator removal — remover validador comprometido
```sql
UPDATE bos_blockchain.bos_onchain_account 
SET metadata = metadata || '{"validator_removed": {"address": "0xCompromisedValidator", "reason": "security_incident", "removed_at_block": 13000}}'
WHERE account_type = 4;
-- Registrar en auditoría
INSERT INTO bauth.bauth_audit_events (event_type, severity, action, resource_type, outcome, details, ctx_id)
VALUES ('validator_removed', 'CRITICAL', 'remove_validator', 'besu_network', 'SUCCESS', '{"address": "0xCompromisedValidator", "reason": "security_incident"}', ?);
```
- bos_onchain_account ✅ · bauth_audit_events ✅
- **Veredicto: ✅ COMPLETO**

### Caso 40: Emergency validator transition — sin quorum (genesis update)
```sql
-- Si la red no puede alcanzar quorum, usar qbft_transitions en genesis.json
-- Forzar cambio de validadores con acceso físico a ≥⅔ nodos
INSERT INTO bauth.bauth_audit_events (event_type, severity, action, resource_type, outcome, details, ctx_id)
VALUES ('validator_emergency_transition', 'CRITICAL', 'emergency_transition', 'besu_network', 'SUCCESS', '{"new_validators": ["0xA","0xB","0xC","0xD"], "reason": "quorum_loss"}', ?);
```
- bauth_audit_events ✅
- **Veredicto: ✅ COMPLETO**

### Caso 41: Besu validator snapshot — backup cada 6h
```sql
-- Snapshot del ledger de cada validador
INSERT INTO bauth.bos_backup_log (backup_type, file_path, file_hash, file_size_bytes, status, executed_at)
VALUES ('blockchain', 's01/backups/besu/validator-1/snapshot-2026-06-21T12:00:00Z.tar.gz', 'sha256...', 524288000, 'COMPLETED', NOW());
```
- bos_backup_log ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**

### Caso 42: Besu network metrics — altura de bloque
```sql
-- Prometheus: besu_blockchain_height
-- No requiere tabla SQL (métrica externa de Besu)
SELECT MAX(block_number) FROM bos_blockchain.bos_onchain_settlement;
```
- bos_onchain_settlement ✅
- **Veredicto: ✅ COMPLETO**

### Caso 43: Managed custody — usuario solicita transacción
```sql
-- Usuario NUNCA ve su clave privada
-- 1. D3 Policy-Path: límites + SoD + dual-approval
-- 2. biedata construye tx
-- 3. Vault firma dentro de HSM (PKCS#11)
-- 4. Tx se envía a Besu
-- 5. Registrar sin exponer clave
INSERT INTO bos_blockchain.bos_onchain_settlement (from_account_id, to_account_id, amount, currency, onchain_tx_hash, block_number, status, dual_approval_id, ctx_id_creator)
VALUES (?, ?, 5000, 'BOB', '0xSignedTxHash...', 12345, 1, ?, ?);
```
- bos_onchain_settlement ✅
- **Veredicto: ✅ COMPLETO** (clave nunca en BD — en HSM vía Vault)

### Caso 44: MFA para custodia — montos altos requieren FIDO2
```sql
-- $5,000 > $1,000 (TOTP) pero < $10,000 → TOTP suficiente
-- $15,000 > $10,000 → FIDO2 + dual-approval requerido
-- La verificación MFA ocurre en bAuth (B35.T09 AALEnforcement), no en la BD
-- Se registra el método usado en auditoría
INSERT INTO bos_privilege.bos_atom_audit (ctx_id, tenant_id, role_id, atom_position, bitmask_atom, policy_state, result, evaluator, domain_code)
VALUES (?, ?, ?, 3, 0x..., 2, 1, 'bauth', 12);
```
- bos_atom_audit ✅
- **Veredicto: ✅ COMPLETO**

### Caso 45: Break-glass recovery — acceso de emergencia a cuenta on-chain
```sql
-- SU break-glass: Vault 2-of-3 unseal
-- Acceso temporal (máx 4h)
-- Auditoría completa
INSERT INTO bauth.bos_key_recovery_log (key_id, recovery_type, approved_by, session_duration, result, ctx_id, notes)
VALUES (?, 'BREAK_GLASS', ARRAY['uuid-s002','uuid-s003','uuid-s004'], INTERVAL '4 hours', 'SUCCESS', ?, 'SU break-glass para recuperar acceso a cuenta on-chain congelada por error');
INSERT INTO bauth.bauth_superuser_contexts (ctx_id, user_uuid, activated_at, reason, audit_level)
VALUES (?, ?, NOW(), 'Recuperación cuenta on-chain', 'full');
```
- bos_key_recovery_log ✅ (v3.0) · bauth_superuser_contexts ✅
- **Veredicto: ✅ COMPLETO**

---

## TRANSVERSALES: D12 ↔ Otros Dominios (Casos 46-50)

### Caso 46: ctx_id en Merkle leaf — trazabilidad D12 ↔ D8
```sql
-- Cada Merkle leaf incluye ctx_id en el hash
-- event_hash = Keccak256(ctx_id || audit_id || tenant_id || role_id || atom_position || result || evaluated_at)
-- Esto permite trazabilidad bidireccional:
-- Dado ctx_id → encontrar anclaje
-- Dado Merkle root → reconstruir todos los ctx_id del lote
SELECT a.ctx_id, l.event_hash, b.merkle_root, b.onchain_block_number
FROM bos_privilege.bos_atom_audit a
JOIN bos_blockchain.bos_merkle_leaf l ON a.audit_id = l.event_audit_id
JOIN bos_blockchain.bos_merkle_batch b ON l.batch_id = b.batch_id
WHERE a.ctx_id = ?;
```
- bos_atom_audit (ctx_id) ✅ · bos_merkle_leaf (event_hash) ✅ · bos_merkle_batch ✅
- **Veredicto: ✅ COMPLETO**

### Caso 47: Dominio D12 en bos_domain_config — activar/desactivar por tenant
```sql
INSERT INTO bauth.bos_domain_config (tenant_id, domain_code, active, override_params)
VALUES (?, 12, TRUE, '{"anchor_tier": "gold", "anchor_network": "arbitrum", "settlement_enabled": false}');
```
- bos_domain_config ✅ (v3.0) · bos_domain (domain_code=12) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 48: Política D12 — POL-D12-ANCHOR en bos_atom_policy
```sql
SELECT * FROM bos_privilege.bos_atom_policy WHERE policy_domain = 12 AND policy_slug = 'POL-D12-ANCHOR';
-- Retorna: {"tier": "gold", "batch_interval_seconds": 3600, "min_batch_size": 1, "max_batch_delay_seconds": 7200, "network": "arbitrum"}
```
- bos_atom_policy (policy_domain=12) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 49: Auditoría de dominio D12 — registro de decisiones blockchain
```sql
INSERT INTO bos_privilege.bos_atom_audit (ctx_id, tenant_id, role_id, app_code, group_code, atom_code, atom_position, bitmask_atom, policy_state, result, evaluator, domain_code)
VALUES (?, ?, ?, 0, 0, 1, 200, 0x..., 2, 1, 'biedata', 12);
-- domain_code=12 para trazabilidad de decisiones D12
```
- bos_atom_audit (domain_code) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 50: Backup de estado blockchain — snapshot completo
```sql
-- Backup diario de todos los datos blockchain
INSERT INTO bauth.bos_backup_log (backup_type, file_path, file_hash, file_size_bytes, status)
VALUES ('blockchain', 's01/backups/blockchain/2026-06-21/full.tar.gz', 'sha256...', 1073741824, 'COMPLETED');
-- Incluye: bos_merkle_batch, bos_merkle_leaf, bos_blockchain_anchor_log, bos_onchain_account, bos_onchain_settlement, bos_reconciliation_log
-- Verificar integridad contra Arbitrum One (Merkle roots inmutables)
```
- bos_backup_log ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**
