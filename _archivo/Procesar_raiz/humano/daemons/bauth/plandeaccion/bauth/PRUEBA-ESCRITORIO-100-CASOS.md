# PRUEBA DE ESCRITORIO — 100 CASOS COMPLEJOS vs DDL v3.0
## SKULL · SBOS · Junio 2026

**Objetivo:** Validar que la DDL (`001_bauth_init.sql` v2.0 + `001_bauth_init_v3.sql`) soporta todos los flujos definidos en el REGISTRO-ESTADO v7.4 (470+ átomos, 38 gates) usando patrones reales de la industria.

**Metodología:** Cada caso describe una operación real, lista las tablas requeridas, y verifica:
- ✅ = tabla/columna existe en DDL
- ⚠️ = existe pero requiere ajuste
- ❌ = no existe (gap)

---

## BLOQUE 1: RBAC + ABAC — Patrones de Control de Acceso (Casos 1-15)

Basado en patrones reales de: eko/authz, OpenFGA, Casbin, ERP-grade authorization.

### Caso 1: Crear átomo de permiso "Comprobantes.nuevo" en dominio D3
```
INSERT INTO bos_privilege.bos_atom_catalog (atom_code, app_code, group_code, domain_code, verb_code, atom_name, atom_slug, atom_position, contextual_mask, logical_mask)
VALUES (1, 1, 2, 3, 1, 'Tryton.Comprobantes.nuevo', 'comprobantes.nuevo', 0,
  bos_privilege.bos_build_atom_bitmask(3, 1, 2, 1, 0));
```
- bos_atom_catalog ✅ · bos_build_atom_bitmask ✅ · bos_domain ✅ · bos_verb ✅ · bos_group ✅ · bos_application ✅
- **Veredicto: ✅ COMPLETO**

### Caso 2: Asignar átomo a rol "Contador Senior"
```
INSERT INTO bos_privilege.bos_role_atom (role_id, app_code, group_code, atom_code, atom_position, allowed)
VALUES ('rol-uuid', 1, 2, 1, 0, TRUE);
```
- bos_role ✅ · bos_role_atom ✅ · atom_position=0 ✅
- **Veredicto: ✅ COMPLETO**

### Caso 3: Computar Rol BitMask efectivo (herencia DAG)
```sql
SELECT atom_position FROM bos_privilege.bos_role_bitmask_view WHERE role_slug = 'contador_senior';
-- + closure table para herencia
SELECT * FROM bauth.rol_closure WHERE ancestro_id = 'ROL-SYS-ADMIN-BOS';
```
- bos_role_bitmask_view ✅ · rol_closure ✅
- **Veredicto: ✅ COMPLETO**

### Caso 4: Verificar permiso Fast-Path (<0.5ns)
```
bit_test(rol_bitmask, atom_position=0) → TRUE/FALSE
```
- bos_role_atom (fuente del Rol Bitmask) ✅
- **Veredicto: ✅ COMPLETO** (cálculo en Rust, no SQL)

### Caso 5: Evaluar política D3 (límite financiero)
```sql
SELECT * FROM bauth.bos_financial_limit WHERE role_id = ?;
SELECT * FROM bauth.bos_financial_decision_matrix WHERE role_slug = 'cajero';
```
- bos_financial_limit ✅ · bos_financial_decision_matrix ✅
- **Veredicto: ✅ COMPLETO**

### Caso 6: Resolver política encadenada D4 (horario)
```sql
SELECT * FROM bos_privilege.bos_atom_policy 
WHERE atom_code = 1 AND app_code = 0 AND policy_domain = 4;
-- POL-D4-HORARIO encadenada a sistema.sesion.ingresar
```
- bos_atom_policy ✅
- **Veredicto: ✅ COMPLETO**

### Caso 7: ABAC condition — "editor can write only own drafts"
```sql
-- Política ABAC almacenada como JSONB
SELECT * FROM bos_privilege.bos_atom_policy 
WHERE policy_slug = 'POL-D1-OWN-DOCUMENTS'
  AND policy_params->>'conditions' @> '{"operator":"AND","conditions":[{"attribute":"subject.role","op":"in","value":["editor"]},{"attribute":"resource.created_by","op":"eq","value":"${user.id}"}]}';
```
- bos_atom_policy (policy_params JSONB) ✅ · GIN index sobre JSONB ⚠️ (no definido en el DDL actual)
- **Veredicto: ⚠️ REQUIERE GIN INDEX** sobre `bos_atom_policy.policy_params`

### Caso 8: Conflict Matrix — verificar SoD antes de asignar rol
```sql
SELECT * FROM bauth.bos_sod_conflict_matrix 
WHERE (atom_a = 3 AND atom_b = 14) OR (atom_a = 14 AND atom_b = 3);
-- 3=FINANCIAL_CREATE, 14=FINANCIAL_APPROVE → conflicto ALTO
```
- bos_sod_conflict_matrix ✅
- **Veredicto: ✅ COMPLETO**

### Caso 9: Multi-tenant isolation — usuario tenant A no ve datos tenant B
```sql
-- RLS o WHERE tenant_id = current_setting('app.current_tenant_id')
SELECT * FROM bos_privilege.bos_role WHERE tenant_id = current_setting('app.current_tenant_id')::UUID;
```
- bos_role (tenant_id UUID) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 10: DomainConfig — desactivar D6 (Geoespacial) para PyME
```sql
INSERT INTO bauth.bos_domain_config (tenant_id, domain_code, active) VALUES (?, 6, FALSE);
```
- bos_domain_config ✅ · bos_domain ✅
- **Veredicto: ✅ COMPLETO**

### Caso 11: DomainShortCircuit — D3 deniega → no evaluar D2,D4,D6
```
DomainRegistry.evaluate_all() → D8→D9→D1→D3(DENEGADO) → STOP
```
- Lógica en Rust, no tablas requeridas ✅
- **Veredicto: ✅ COMPLETO**

### Caso 12: Herencia multinivel — SU hereda de Admin BOS → bos-agent
```sql
SELECT * FROM bauth.rol_closure WHERE ancestro_id = 'ROL-SYS-SUPERUSUARIO' AND profundidad <= 3;
```
- rol_closure (ancestro_id, descendiente_id, profundidad) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 13: Dynamic SoD — activar Cajero y Auditor en misma sesión
```
check_dynamic_sod(['ROL-CAJERO', 'ROL-AUDITOR']) → CONFLICT → DENEGAR
```
- Lógica en Rust, sin tablas específicas ✅ (los átomos incompatibles están en bos_sod_conflict_matrix)
- **Veredicto: ✅ COMPLETO**

### Caso 14: Permission Cache — TTL 30s con invalidación
```sql
-- Redis DB3: GET perm:{user_id}:{atom_position}
-- Cache miss → consultar bos_role_atom → almacenar en Redis
```
- Redis (externo) ✅ · bos_role_atom ✅
- **Veredicto: ✅ COMPLETO**

### Caso 15: EffectiveRoleResolver — resolver Rol BitMask con herencia + delegación
```sql
-- 1. Roles directos
SELECT atom_position FROM bos_privilege.bos_role_bitmask_view WHERE role_slug = 'cajero';
-- 2. Herencia DAG
SELECT descendiente_id FROM bauth.rol_closure WHERE ancestro_id = 'ROL-CAJERO';
-- 3. Delegaciones activas
SELECT atom_positions FROM bauth.bos_delegation_log WHERE to_user_uuid = ? AND status = 'ACTIVE';
-- 4. OR de todos los atom_positions
```
- bos_role_bitmask_view ✅ · rol_closure ✅ · bos_delegation_log ✅ · atom_positions ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**

---

## BLOQUE 2: FINANCIERO — Doble Firma y Límites (Casos 16-25)

### Caso 16: Crear transacción que requiere doble firma ($5,000 > umbral $1,000)
```sql
-- 1. Verificar límite
SELECT max_transaction FROM bauth.bos_financial_limit WHERE role_id = ?;
-- 5000 ≤ 10000 → OK
-- 2. Verificar umbral dual-approval
SELECT requires_dual_approval_above FROM bauth.bos_financial_decision_matrix WHERE role_slug = 'cajero';
-- 1000. 5000 > 1000 → requiere doble firma
-- 3. Crear solicitud pendiente
INSERT INTO bauth.bos_financial_approval (tenant_id, tipo_transaccion, referencia, monto, solicitante_uuid, nivel_total, ctx_id_creator)
VALUES (?, 'PAGO', 'FAC-12345', 5000, ?, 2, 'ctx_abc');
```
- bos_financial_limit ✅ · bos_financial_decision_matrix ✅ · bos_financial_approval ✅ · ctx_id_creator ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**

### Caso 17: Aprobar transacción (segundo firmante)
```sql
UPDATE bauth.bos_financial_approval 
SET decision = 'APROBADO', aprobador_uuid = ?, decision_fecha = NOW(), ctx_id_approver = 'ctx_def'
WHERE approval_id = ? AND estado = 'PENDIENTE';
```
- bos_financial_approval ✅ · ctx_id_approver ✅ (v3.0)
- SoD check: aprobador != solicitante → validación en Rust ✅
- **Veredicto: ✅ COMPLETO**

### Caso 18: Escalamiento — aprobador no responde en 30min
```sql
UPDATE bauth.bos_financial_approval 
SET estado = 'ESCALADO', escalado_a_uuid = ?, escalado_fecha = NOW(), nivel_actual = 2
WHERE approval_id = ? AND decision_fecha IS NULL AND solicitud_fecha < NOW() - INTERVAL '30 minutes';
```
- bos_financial_approval (escalado_a_uuid, escalado_fecha, nivel_actual) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 19: Velocity check — >10 transacciones en 5min → alerta
```sql
SELECT COUNT(*) FROM bauth.bos_financial_approval 
WHERE solicitante_uuid = ? AND solicitud_fecha > NOW() - INTERVAL '5 minutes';
```
- bos_financial_approval ✅
- **Veredicto: ✅ COMPLETO**

### Caso 20: Liquidación on-chain D12-B ($5,000 entre cuentas)
```sql
-- 1. Verificar balance en caché local
SELECT balance_local FROM bos_blockchain.bos_onchain_account WHERE account_id = ?;
-- 2. Ejecutar liquidación en Besu QBFT (externo)
-- 3. Registrar
INSERT INTO bos_blockchain.bos_onchain_settlement (from_account_id, to_account_id, amount, currency, onchain_tx_hash, block_number, ctx_id_creator, ctx_id_approver, dual_approval_id)
VALUES (?, ?, 5000, 'BOB', '0xabc...', 12345, 'ctx_abc', 'ctx_def', ?);
-- 4. Actualizar caché local
UPDATE bos_blockchain.bos_onchain_account SET balance_local = balance_derived WHERE account_id IN (?, ?);
```
- bos_onchain_account ✅ · bos_onchain_settlement ✅ · dual_approval_id (FK a bos_financial_approval) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 21: Reconciliación on-chain ↔ PostgreSQL (cada 15min)
```sql
-- Leer balance on-chain (externo: SettlementEngine.balanceOf)
-- Comparar con balance_local
INSERT INTO bos_blockchain.bos_reconciliation_log (account_id, balance_onchain, balance_local, difference, block_number, status)
VALUES (?, 5000, 4999.99, 0.01, 12345, 0);  -- status=0 → matched (diff < umbral)
```
- bos_reconciliation_log ✅
- **Veredicto: ✅ COMPLETO**

### Caso 22: Currency control — $5,000 USD vs límite BOB
```sql
SELECT * FROM bauth.bos_financial_limit 
WHERE role_id = ? AND currency = 'USD';
-- Si no hay fila USD → usar BOB con tipo de cambio
SELECT * FROM bauth.bos_moneda WHERE codice_iso = 'USD';
```
- bos_financial_limit (currency field) ⚠️ ¿tiene campo currency?
- bos_moneda ✅
- **Veredicto: ⚠️ VERIFICAR** schema de bos_financial_limit

### Caso 23: Structuring detection — transacciones bajo umbral repetidas
```sql
SELECT COUNT(*), SUM(monto) FROM bauth.bos_financial_approval
WHERE solicitante_uuid = ? AND monto < 1000 AND solicitud_fecha > NOW() - INTERVAL '24 hours'
HAVING COUNT(*) > 5;
```
- bos_financial_approval ✅
- **Veredicto: ✅ COMPLETO**

### Caso 24: Migración de saldos Fase 1 (doble contabilidad)
```sql
-- PostgreSQL (fuente) → Besu (réplica)
UPDATE bos_blockchain.bos_onchain_account SET balance_local = ? WHERE account_id = ?;
-- Besu: SettlementEngine.registerAccount(addr, balance)
```
- bos_onchain_account ✅
- **Veredicto: ✅ COMPLETO**

### Caso 25: Forensic replay — reconstruir saldo desde eventos on-chain
```sql
SELECT * FROM bos_blockchain.bos_onchain_settlement 
WHERE (from_account_id = ? OR to_account_id = ?) AND block_number > ?
ORDER BY block_number;
```
- bos_onchain_settlement ✅
- **Veredicto: ✅ COMPLETO**

---

## BLOQUE 3: BLOCKCHAIN — Anclaje y Verificación (Casos 26-35)

### Caso 26: Sellar lote Merkle de auditoría
```sql
UPDATE bos_blockchain.bos_merkle_batch 
SET status = 1, merkle_root = '0xabc...', sealed_at = NOW()
WHERE batch_id = ?;
```
- bos_merkle_batch ✅
- **Veredicto: ✅ COMPLETO**

### Caso 27: Insertar hoja Merkle por evento de auditoría
```sql
INSERT INTO bos_blockchain.bos_merkle_leaf (batch_id, leaf_index, event_audit_id, event_hash)
VALUES (?, 0, 'audit-uuid', '0xleaf_hash...');
```
- bos_merkle_leaf ✅
- **Veredicto: ✅ COMPLETO**

### Caso 28: Anclar lote en Arbitrum One
```sql
-- Enviar tx a Arbitrum → esperar confirmación
INSERT INTO bos_blockchain.bos_blockchain_anchor_log (batch_id, tx_hash, block_number, block_timestamp, network, contract_address, gas_used, status)
VALUES (?, '0xtx...', 19500000, NOW(), 'arbitrum', '0xContractAddr', 45000, 1);
UPDATE bos_blockchain.bos_merkle_batch SET status = 2, onchain_tx_hash = '0xtx...', anchored_at = NOW() WHERE batch_id = ?;
```
- bos_blockchain_anchor_log ✅ · bos_merkle_batch ✅
- **Veredicto: ✅ COMPLETO**

### Caso 29: Trazabilidad bidireccional — ctx_id → anclaje
```sql
SELECT a.audit_id, a.ctx_id, b.merkle_root, l.tx_hash, l.block_number
FROM bos_privilege.bos_atom_audit a
JOIN bos_blockchain.bos_merkle_batch b ON a.merkle_batch_id = b.batch_id
JOIN bos_blockchain.bos_blockchain_anchor_log l ON b.batch_id = l.batch_id
WHERE a.ctx_id = 'ctx_abc';
```
- bos_atom_audit (merkle_batch_id) ✅ · bos_merkle_batch ✅ · bos_blockchain_anchor_log ✅
- **Veredicto: ✅ COMPLETO**

### Caso 30: Verificador externo — Merkle proof sin confianza
```bash
bos-verify offline --events events.json --proof batch-42.proof.json --expected-root 0xabc...
```
- bos_merkle_leaf (merkle_proof) ✅ · bos_merkle_batch (merkle_root) ✅
- **Veredicto: ✅ COMPLETO** (CLI, no SQL)

### Caso 31: Gas balance monitoring
```sql
-- Check balance del contrato AnchorClient
-- Alerta si < 0.005 ETH
-- No requiere tabla local (monitoreo externo)
```
- **Veredicto: ✅ COMPLETO** (externo: Arbitrum RPC)

### Caso 32: Retry con exponential backoff
```sql
UPDATE bos_blockchain.bos_merkle_batch 
SET retry_count = retry_count + 1, last_error = 'RPC timeout'
WHERE batch_id = ?;
```
- bos_merkle_batch (retry_count, last_error) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 33: Validator key rotation (Besu QBFT)
```sql
UPDATE bauth.bos_key_inventory 
SET state = 'DEACTIVATED' WHERE key_type = 'VALIDATOR_SIGNING' AND key_id = ?;
INSERT INTO bauth.bos_key_inventory (...) VALUES (...);  -- nueva llave
INSERT INTO bauth.bos_key_rotation_log (key_id, rotation_type, overlap_start, overlap_end) VALUES (?, 'SCHEDULED', NOW(), NOW() + INTERVAL '7 days');
```
- bos_key_inventory ✅ · bos_key_rotation_log ✅
- **Veredicto: ✅ COMPLETO**

### Caso 34: Smart contract deployment tracking
```sql
-- AuditAnchor desplegado en Arbitrum → registrar en metadata
UPDATE bos_blockchain.bos_blockchain_anchor_log 
SET contract_address = '0xNewAddr' WHERE network = 'arbitrum' AND status = 1;
```
- bos_blockchain_anchor_log ✅
- **Veredicto: ✅ COMPLETO**

### Caso 35: Merkle root verification SQL
```sql
SELECT bos_blockchain.merkle_root_from_batch('batch-uuid');
-- Comparar con merkle_root almacenado
```
- merkle_root_from_batch() ✅
- **Veredicto: ✅ COMPLETO**

---

## BLOQUE 4: TOKENS Y MFA — Ciclo de Vida (Casos 36-50)

### Caso 36: Enroll TOTP — generar secret + QR
```sql
INSERT INTO bauth.bauth_mfa_enrollments (user_uuid, method, secret_encrypted, status, created_at)
VALUES (?, 'TOTP', pgp_sym_encrypt('JBSWY3DPEHPK3PXP', 'vault-key'), 'PENDING_VERIFICATION', NOW());
```
- bauth_mfa_enrollments ✅
- **Veredicto: ✅ COMPLETO**

### Caso 37: Verificar TOTP enrollment
```sql
UPDATE bauth.bauth_mfa_enrollments SET status = 'ACTIVE', verified_at = NOW() WHERE enrollment_id = ?;
```
- bauth_mfa_enrollments ✅
- **Veredicto: ✅ COMPLETO**

### Caso 38: Registrar entrega de token NFC físico
```sql
INSERT INTO bauth.bos_token_delivery_log (token_id, token_type, user_id, delivery_channel, delivered_by, recipient_signature)
VALUES (?, 'NFC', ?, 'presencial', ?, 'firma_ed25519_base64...');
```
- bos_token_delivery_log ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**

### Caso 39: Rotar TOTP (teléfono nuevo)
```sql
-- 1. Ambos secrets válidos 24h
UPDATE bauth.bauth_mfa_enrollments SET status = 'ROTATING' WHERE enrollment_id = ?;
INSERT INTO bauth.bauth_mfa_enrollments (user_uuid, method, secret_encrypted, status, previous_enrollment_id)
VALUES (?, 'TOTP', pgp_sym_encrypt('NUEVOSECRETO', 'vault-key'), 'PENDING_VERIFICATION', ?);
-- 2. Verificar nuevo → activar → revocar viejo
UPDATE bauth.bauth_mfa_enrollments SET status = 'REVOKED', revoked_at = NOW() WHERE enrollment_id = ?;
```
- bauth_mfa_enrollments ⚠️ ¿tiene previous_enrollment_id?
- **Veredicto: ⚠️ REQUIERE** previous_enrollment_id para tracking de rotación

### Caso 40: Revocar token (pérdida de teléfono)
```sql
UPDATE bauth.bauth_mfa_enrollments SET status = 'REVOKED', revoked_at = NOW(), revoke_reason = 'perdida_dispositivo' WHERE enrollment_id = ?;
INSERT INTO bauth.bos_key_recovery_log (recovery_type, result, ctx_id) VALUES ('USER_RECOVERY', 'SUCCESS', ?);
```
- bauth_mfa_enrollments ⚠️ ¿revoke_reason?
- bos_key_recovery_log ✅ (v3.0)
- **Veredicto: ⚠️ REQUIERE** revoke_reason en bauth_mfa_enrollments

### Caso 41: Registrar uso de recovery code (SHA-256)
```sql
UPDATE bauth.bauth_mfa_enrollments 
SET recovery_codes_used = recovery_codes_used + 1
WHERE enrollment_id = ? AND 'hashed_input' = ANY(recovery_code_hashes);
```
- bauth_mfa_enrollments ⚠️ ¿tiene recovery_code_hashes y recovery_codes_used?
- **Veredicto: ⚠️ REQUIERE** columnas recovery_code_hashes TEXT[], recovery_codes_used INTEGER

### Caso 42: MFA fatigue detection — >3 push rechazados en 5min
```sql
SELECT COUNT(*) FROM bauth.bauth_audit_events
WHERE user_uuid = ? AND event_type = 'push_rejected' AND created_at > NOW() - INTERVAL '5 minutes';
```
- bauth_audit_events (event_type=push_rejected) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 43: AAL enforcement — bloquear SMS para transacción >$10K
```
required_aal = 3 (FIDO2), method_used = SMS (AAL1) → DENEGAR
```
- Lógica en Rust (B35.T09), sin tablas ✅
- **Veredicto: ✅ COMPLETO**

### Caso 44: FIDO2 Enterprise Attestation — verificar certificado durante enrollment
```
FIDO2 registration → verify attestation certificate chain → Enterprise Root CA
```
- Procesado en SPI Java (B23), sin tablas específicas ✅
- **Veredicto: ✅ COMPLETO**

### Caso 45: Token inventory — listar métodos activos de un usuario
```sql
SELECT method, status, created_at, last_used_at FROM bauth.bauth_mfa_enrollments WHERE user_uuid = ? AND status = 'ACTIVE';
SELECT token_type, delivered_at FROM bauth.bos_token_delivery_log WHERE user_id = ?;
```
- bauth_mfa_enrollments ✅ · bos_token_delivery_log ✅
- **Veredicto: ✅ COMPLETO**

### Caso 46: Conditional Access — device + location + behavior
```
IF device.compliant AND location.boundary AND risk_score < 70 THEN passwordless ELSE step_up
```
- Lógica en Rust (B35.T11), sin tablas específicas ✅
- **Veredicto: ✅ COMPLETO**

### Caso 47: Migración SMS → TOTP — batch processing
```sql
-- 1. Identificar usuarios con SMS activo
SELECT user_uuid FROM bauth.bauth_mfa_enrollments WHERE method = 'SMS' AND status = 'ACTIVE';
-- 2. Para cada uno: crear enrollment TOTP, notificar, deadline
UPDATE bauth.bauth_mfa_enrollments SET status = 'DEPRECATED', deprecated_at = NOW() WHERE method = 'SMS' AND status = 'ACTIVE';
```
- bauth_mfa_enrollments ⚠️ ¿tiene deprecated_at?
- **Veredicto: ⚠️ REQUIERE** deprecated_at, migration_deadline

### Caso 48: Enrollment audit log
```sql
INSERT INTO bauth.bos_auth_method_enrollment_log (user_id, method_type, step, status, ctx_id)
VALUES (?, 'TOTP', 'generate_credential', 'COMPLETED', ?);
```
- bos_auth_method_enrollment_log ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**

### Caso 49: AuthMethodRegistry — listar métodos disponibles
```sql
-- Catálogo en código Rust, no en BD. Parámetros de configuración en:
SELECT * FROM bauth.bos_policy_history WHERE policy_slug LIKE 'auth_method_%';
```
- bos_policy_history ✅
- **Veredicto: ✅ COMPLETO**

### Caso 50: Password screening — HIBP k-anonymity
```sql
-- Range query: SELECT prefix FROM HIBP API WHERE prefix = 'ABC12'
-- Local check: comparar suffixes
INSERT INTO bauth.bauth_password_history (user_uuid, password_hash, created_at) VALUES (?, ?, NOW());
```
- bauth_password_history ✅
- **Veredicto: ✅ COMPLETO**

---

## BLOQUE 5: IGA — Identidad y Gobernanza (Casos 51-70)

### Caso 51: Joiner — onboarding desde OrangeHRM
```sql
-- Webhook recibido: employee.hired
INSERT INTO bauth.bos_user_template (uuid, username, email, tenant_id, status, created_at)
VALUES (gen_random_uuid(), 'juan.perez', 'juan@acme.com', ?, 'PENDING_ONBOARDING', NOW());
-- B11.T17-T21: flujo completo
```
- bos_user_template ✅
- **Veredicto: ✅ COMPLETO**

### Caso 52: Mover — cambio de departamento
```sql
UPDATE bauth.bos_user_role_assignment SET active = FALSE WHERE user_id = ? AND assignment_type = 'DIRECT';
INSERT INTO bauth.bos_user_role_assignment (user_id, role_id, assignment_type, assigned_by) VALUES (?, ?, 'DIRECT', ?);
-- Recalcular Rol BitMask
```
- bos_user_role_assignment ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**

### Caso 53: Leaver — offboarding en <30min
```sql
-- 1. Revocar sesiones KC (externo: Keycloak Admin API)
-- 2. Invalidar ctx_id
UPDATE bauth.context_sessions SET state = 'INVALIDATED' WHERE user_uuid = ? AND state = 'ACTIVE';
-- 3. Desactivar usuario
UPDATE bauth.bos_user_template SET status = 'TERMINATED', terminated_at = NOW() WHERE uuid = ?;
-- 4. Archivar PII (10 años fiscal)
-- 5. Auditoría
INSERT INTO bauth.bauth_audit_events (event_type, user_uuid, action, outcome, ctx_id) VALUES ('user_terminated', ?, 'offboard', 'SUCCESS', ?);
```
- context_sessions (state) ✅ (v3.0) · bos_user_template ✅ · bauth_audit_events ✅
- **Veredicto: ✅ COMPLETO**

### Caso 54: Access recertification — campaña trimestral
```sql
-- 1. Identificar roles a revisar (SU, N1, D3)
SELECT role_id, role_name FROM bos_privilege.bos_role WHERE role_code IN (1, 2, 3, 4, 5);
-- 2. Para cada usuario con esos roles, crear tarea de revisión
INSERT INTO bauth.bauth_access_reviews (user_uuid, role_id, reviewer_uuid, review_cycle, status, due_date)
SELECT ura.user_id, ura.role_id, u.manager_uuid, 'Q3-2026', 'PENDING', NOW() + INTERVAL '14 days'
FROM bauth.bos_user_role_assignment ura
JOIN bauth.bos_user_template u ON ura.user_id = u.uuid
WHERE ura.role_id IN (SELECT role_id FROM bos_privilege.bos_role WHERE role_code <= 5);
```
- bauth_access_reviews ✅ · bos_user_role_assignment ✅ · bos_role ✅
- **Veredicto: ✅ COMPLETO**

### Caso 55: Privilege creep — detectar roles >90 días sin uso
```sql
SELECT ura.user_id, ura.role_id, ura.last_used
FROM bauth.bos_user_role_assignment ura
WHERE ura.active = TRUE AND ura.last_used < NOW() - INTERVAL '90 days';
```
- bos_user_role_assignment (last_used) ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**

### Caso 56: Ghost account — detectar usuario activo en KC pero inactivo en HR
```sql
SELECT u.uuid, u.username FROM bauth.bos_user_template u
WHERE u.status = 'ACTIVE' 
AND u.uuid NOT IN (SELECT employee_id FROM orangehrm.employees WHERE active = TRUE);
-- OrangeHRM es externo → integración vía API/B36.T07
```
- bos_user_template ✅
- **Veredicto: ✅ COMPLETO** (OrangeHRM externo)

### Caso 57: Registrar ghost account detectada
```sql
INSERT INTO bauth.bauth_ghost_accounts (user_uuid, detected_at, resolved, resolution)
VALUES (?, NOW(), FALSE, NULL);
```
- bauth_ghost_accounts ✅
- **Veredicto: ✅ COMPLETO**

### Caso 58: Continuous SoD — verificar violaciones semanalmente
```sql
SELECT ura1.user_id, ura1.role_id as role_a, ura2.role_id as role_b
FROM bauth.bos_user_role_assignment ura1
JOIN bauth.bos_user_role_assignment ura2 ON ura1.user_id = ura2.user_id AND ura1.role_id < ura2.role_id
JOIN bauth.bos_sod_conflict_matrix sod ON (ura1.role_id = sod.role_a AND ura2.role_id = sod.role_b)
WHERE ura1.active = TRUE AND ura2.active = TRUE;
```
- bos_user_role_assignment ✅ · bos_sod_conflict_matrix ✅
- **Veredicto: ✅ COMPLETO**

### Caso 59: NHI lifecycle — service account sin owner
```sql
SELECT * FROM bauth.bos_user_template 
WHERE user_type = 'SERVICE_ACCOUNT' AND owner_uuid IS NULL;
```
- bos_user_template ⚠️ ¿tiene user_type y owner_uuid?
- **Veredicto: ⚠️ REQUIERE** user_type, owner_uuid en bos_user_template

### Caso 60: NHI expiry — service account con fecha vencida
```sql
UPDATE bauth.bos_user_template SET status = 'EXPIRED' 
WHERE user_type = 'SERVICE_ACCOUNT' AND expires_at < NOW() AND status = 'ACTIVE';
```
- bos_user_template ⚠️ ¿tiene expires_at?
- **Veredicto: ⚠️ REQUIERE** expires_at en bos_user_template

### Caso 61: Access request — usuario solicita rol
```sql
INSERT INTO bauth.bauth_access_reviews (user_uuid, role_id, reviewer_uuid, review_cycle, status, request_reason, due_date)
VALUES (?, ?, (SELECT manager_uuid FROM bauth.bos_user_template WHERE uuid = ?), 'ADHOC', 'PENDING', 'Necesito acceso para cierre mensual', NOW() + INTERVAL '5 days');
```
- bauth_access_reviews ⚠️ ¿tiene request_reason y review_cycle = 'ADHOC'?
- **Veredicto: ⚠️ REQUIERE** request_reason en bauth_access_reviews

### Caso 62: Role mining — descubrir clústeres de permisos
```sql
SELECT role_id, array_agg(DISTINCT atom_position ORDER BY atom_position) as atoms, COUNT(DISTINCT user_id) as user_count
FROM bauth.bos_user_role_assignment ura
JOIN bos_privilege.bos_role_atom ra ON ura.role_id = ra.role_id
WHERE ura.active = TRUE AND ra.allowed = TRUE
GROUP BY role_id HAVING COUNT(DISTINCT user_id) >= 3
ORDER BY user_count DESC;
```
- bos_user_role_assignment ✅ · bos_role_atom ✅
- **Veredicto: ✅ COMPLETO**

### Caso 63: SoD simulator — ¿asignar rol X al usuario Y viola SoD?
```sql
SELECT sod.role_a, sod.role_b, sod.severity
FROM bauth.bos_sod_conflict_matrix sod
WHERE (sod.role_a = ? AND sod.role_b IN (SELECT role_id FROM bauth.bos_user_role_assignment WHERE user_id = ? AND active = TRUE))
   OR (sod.role_b = ? AND sod.role_a IN (SELECT role_id FROM bauth.bos_user_role_assignment WHERE user_id = ? AND active = TRUE));
```
- bos_sod_conflict_matrix ✅ · bos_user_role_assignment ✅
- **Veredicto: ✅ COMPLETO**

### Caso 64: User merge — fusionar cuentas duplicadas
```sql
BEGIN;
-- Migrar role assignments
UPDATE bauth.bos_user_role_assignment SET user_id = 'primary-uuid' WHERE user_id = 'secondary-uuid';
-- Migrar delegations
UPDATE bauth.bos_delegation_log SET to_user_uuid = 'primary-uuid' WHERE to_user_uuid = 'secondary-uuid';
UPDATE bauth.bos_delegation_log SET from_user_uuid = 'primary-uuid' WHERE from_user_uuid = 'secondary-uuid';
-- Migrar audit events
UPDATE bauth.bauth_audit_events SET user_uuid = 'primary-uuid' WHERE user_uuid = 'secondary-uuid';
-- Desactivar secondary
UPDATE bauth.bos_user_template SET status = 'MERGED', merged_into = 'primary-uuid' WHERE uuid = 'secondary-uuid';
COMMIT;
```
- bos_user_role_assignment ✅ · bos_delegation_log ✅ · bauth_audit_events ✅ · bos_user_template ⚠️ ¿merged_into?
- **Veredicto: ⚠️ REQUIERE** merged_into en bos_user_template

### Caso 65: GDPR consent — registrar consentimiento
```sql
INSERT INTO bauth.bos_user_consent (user_id, consent_type, status, ip_address, user_agent)
VALUES (?, 'data_processing', 'granted', '192.168.1.1', 'Mozilla/5.0...');
```
- bos_user_consent ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**

### Caso 66: GDPR consent withdrawal — iniciar borrado de datos
```sql
UPDATE bauth.bos_user_consent SET status = 'withdrawn', withdrawn_at = NOW() WHERE user_id = ? AND consent_type = 'data_processing';
-- Disparar proceso de eliminación de PII (B17.T24)
```
- bos_user_consent ✅
- **Veredicto: ✅ COMPLETO**

### Caso 67: User suspension — vacaciones 2 semanas
```sql
UPDATE bauth.bos_user_template SET status = 'SUSPENDED', suspended_at = NOW(), suspension_until = NOW() + INTERVAL '14 days', suspension_reason = 'vacaciones'
WHERE uuid = ?;
UPDATE bauth.context_sessions SET state = 'INVALIDATED' WHERE user_uuid = ? AND state = 'ACTIVE';
```
- bos_user_template ⚠️ ¿suspended_at, suspension_until, suspension_reason?
- **Veredicto: ⚠️ REQUIERE** campos de suspensión en bos_user_template

### Caso 68: User activity audit — historial de logins
```sql
SELECT event_type, outcome, created_at, source_ip
FROM bauth.bauth_audit_events
WHERE user_uuid = ? AND event_type IN ('login_success', 'login_failed', 'logout', 'session_expired')
ORDER BY created_at DESC LIMIT 100;
```
- bauth_audit_events ✅
- **Veredicto: ✅ COMPLETO**

### Caso 69: Bulk user import — CSV con 500 usuarios
```sql
BEGIN;
-- Para cada fila: validar → INSERT bos_user_template → assign roles → sync KC
-- Si falla una fila → ROLLBACK
COMMIT;
```
- bos_user_template ✅ · bos_user_role_assignment ✅
- **Veredicto: ✅ COMPLETO**

### Caso 70: IGA Dashboard — KPIs de gobernanza
```sql
-- Onboarded este mes
SELECT COUNT(*) FROM bauth.bos_user_template WHERE created_at > NOW() - INTERVAL '30 days';
-- Offboarded este mes
SELECT COUNT(*) FROM bauth.bos_user_template WHERE status = 'TERMINATED' AND terminated_at > NOW() - INTERVAL '30 days';
-- Ghost accounts pendientes
SELECT COUNT(*) FROM bauth.bauth_ghost_accounts WHERE resolved = FALSE;
-- Recertificaciones on-time
SELECT COUNT(*) FILTER (WHERE status = 'COMPLETED' AND completed_at <= due_date) * 100.0 / COUNT(*) 
FROM bauth.bauth_access_reviews WHERE review_cycle = 'Q3-2026';
```
- bos_user_template ✅ · bauth_ghost_accounts ✅ · bauth_access_reviews ⚠️ ¿completed_at?
- **Veredicto: ⚠️ REQUIERE** completed_at en bauth_access_reviews

---

## BLOQUE 6: CONTEXTO Y SESIÓN (Casos 71-80)

### Caso 71: Crear dctx_id (device context pre-auth)
```sql
INSERT INTO bauth.context_sessions (ctx_id, dctx_id, tenant_id, empresa_id, device_id, device_hostname, device_ip, state, nonce)
VALUES ('dctx_001', NULL, ?, ?, 'DEVICE-991', 'terminal-caja-03', '10.0.0.50', 'PENDING', gen_random_uuid());
```
- context_sessions (state, nonce) ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**

### Caso 72: Promover dctx_id → ctx_id post-login
```sql
UPDATE bauth.context_sessions 
SET state = 'ACTIVE', session_kc = 'kc-session-id', user_uuid = ?, ruta_canonica = '/dist/skull/emp/acme/suc/central/pos/03', created_at = NOW(), expires_at = NOW() + INTERVAL '8 hours'
WHERE ctx_id = 'dctx_001';
INSERT INTO bauth.context_sessions (ctx_id, dctx_id, ...) VALUES ('ctx_001', 'dctx_001', ...);  -- nuevo ctx_id promovido
```
- context_sessions (state, created_at, expires_at) ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**

### Caso 73: Validar ctx_id — Policy Decision Point
```sql
SELECT state, expires_at, user_uuid, tenant_id, sequence, terminal_fingerprint
FROM bauth.context_sessions WHERE ctx_id = 'ctx_001';
-- state = ACTIVE? expires_at > NOW()? → válido
```
- context_sessions ✅
- **Veredicto: ✅ COMPLETO**

### Caso 74: Anti-replay — nonce + sequence
```sql
-- 1. Verificar nonce no usado antes (Redis SETNX ctx:ctx_001:nonce:uuid-v4)
-- 2. Verificar sequence > última registrada
UPDATE bauth.context_sessions SET sequence = sequence + 1 WHERE ctx_id = 'ctx_001' AND sequence = ?;
```
- context_sessions (nonce, sequence) ✅ (v3.0)
- Redis: externo ✅
- **Veredicto: ✅ COMPLETO**

### Caso 75: Session hijacking detection — terminal_fingerprint mismatch
```sql
SELECT terminal_fingerprint FROM bauth.context_sessions WHERE ctx_id = 'ctx_001';
-- Comparar con fingerprint del request actual
-- Si no coincide → ALERTA P1 + invalidar ctx_id
UPDATE bauth.context_sessions SET state = 'INVALIDATED' WHERE ctx_id = 'ctx_001';
```
- context_sessions (terminal_fingerprint) ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**

### Caso 76: Invalidate ctx_id — logout
```sql
UPDATE bauth.context_sessions SET state = 'INVALIDATED' WHERE ctx_id = 'ctx_001';
-- Redis: DEL ctx:ctx_001
-- Kong: cache invalidation
```
- context_sessions ✅
- **Veredicto: ✅ COMPLETO**

### Caso 77: W3C Trace Context propagation
```sql
-- Header: traceparent: 00-{trace_id}-{span_id}-01
-- Header: tracestate: sbos={tenant_id}
-- Baggage: ctx_id,user_id
SELECT ctx_id, traceparent FROM bauth.context_sessions WHERE ctx_id = 'ctx_001';
```
- context_sessions ✅ (traceparent ya existe en v2.0)
- **Veredicto: ✅ COMPLETO**

### Caso 78: Context switch — usuario cambia de empresa/sucursal
```sql
INSERT INTO bauth.context_switches (from_ctx_id, to_ctx_id, switched_at, reason)
VALUES ('ctx_001', 'ctx_002', NOW(), 'cambio_sucursal');
```
- context_switches ✅
- **Veredicto: ✅ COMPLETO**

### Caso 79: Session expiry — TTL agotado
```sql
UPDATE bauth.context_sessions SET state = 'EXPIRED' WHERE state = 'ACTIVE' AND expires_at < NOW();
```
- context_sessions (expires_at) ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**

### Caso 80: Roaming profile — usuario se mueve a otro terminal
```sql
-- 1. Verificar sesión activa en terminal A
SELECT * FROM bauth.context_sessions WHERE user_uuid = ? AND state = 'ACTIVE';
-- 2. Bloquear terminal A (LOCK, no LOGOUT)
-- 3. Crear nuevo ctx_id en terminal B (nuevo terminal_fingerprint)
INSERT INTO bauth.context_sessions (...) VALUES (...);
-- 4. Cargar VDI profile
SELECT * FROM bauth.bauth_vdi_profiles WHERE user_id = ?;
```
- context_sessions ✅ · bauth_vdi_profiles ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**

---

## BLOQUE 7: LLAVES — Ciclo de Vida Criptográfico (Casos 81-90)

### Caso 81: Registrar nueva llave JWT signing
```sql
INSERT INTO bauth.bos_key_inventory (key_type, algorithm, rotation_interval, storage_backend, state, owner)
VALUES ('JWT_SIGNING', 'EdDSA_Ed25519', INTERVAL '24 hours', 'VAULT_TRANSIT', 'ACTIVE', 'bAuth JWT Signer');
```
- bos_key_inventory ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**

### Caso 82: Dual-credential rotation — JWT signing key
```sql
-- Fase 1: nueva llave
INSERT INTO bauth.bos_key_inventory (key_type, algorithm, storage_backend, state) VALUES ('JWT_SIGNING', 'EdDSA', 'VAULT_TRANSIT', 'PRE_ACTIVE');
-- Fase 2: overlap
INSERT INTO bauth.bos_key_rotation_log (key_id, rotation_type, overlap_start, overlap_end, status)
VALUES ('new-key-uuid', 'SCHEDULED', NOW(), NOW() + INTERVAL '24 hours', 'IN_PROGRESS');
UPDATE bauth.bos_key_inventory SET state = 'ACTIVE' WHERE key_id = 'new-key-uuid';
-- Fase 3: limpieza
UPDATE bauth.bos_key_inventory SET state = 'DEACTIVATED' WHERE key_id = 'old-key-uuid';
UPDATE bauth.bos_key_rotation_log SET status = 'COMPLETED' WHERE rotation_id = ?;
```
- bos_key_inventory ✅ · bos_key_rotation_log ✅
- **Veredicto: ✅ COMPLETO**

### Caso 83: Key compromise — respuesta automatizada
```sql
UPDATE bauth.bos_key_inventory SET state = 'COMPROMISED' WHERE key_id = ?;
INSERT INTO bauth.bos_key_recovery_log (key_id, recovery_type, result, ctx_id) VALUES (?, 'COMPROMISE', 'SUCCESS', ?);
-- Rotar todas las llaves del mismo tipo
INSERT INTO bauth.bos_key_rotation_log (key_id, rotation_type, status) 
SELECT key_id, 'EMERGENCY', 'IN_PROGRESS' FROM bauth.bos_key_inventory WHERE key_type = (SELECT key_type FROM bauth.bos_key_inventory WHERE key_id = ?);
```
- bos_key_inventory ✅ · bos_key_recovery_log ✅ · bos_key_rotation_log ✅
- **Veredicto: ✅ COMPLETO**

### Caso 84: Key validation — JWKS consistency check
```sql
-- Verificar que JWKS endpoint contiene las llaves esperadas
SELECT key_id FROM bauth.bos_key_inventory WHERE key_type = 'JWT_SIGNING' AND state = 'ACTIVE';
-- Comparar con /.well-known/jwks.json (externo)
```
- bos_key_inventory ✅
- **Veredicto: ✅ COMPLETO**

### Caso 85: Key backup — metadata a MinIO
```sql
INSERT INTO bauth.bos_backup_log (backup_type, file_path, file_hash, file_size_bytes, status)
VALUES ('key_inventory', 's01/backups/keys/2026-06-21/keys.json.gz', 'sha256...', 1024000, 'COMPLETED');
```
- bos_backup_log ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**

### Caso 86: Key destruction — zeroize
```sql
UPDATE bauth.bos_key_inventory SET state = 'DESTROYED', metadata = metadata || '{"destroyed_at": "2026-06-21T12:00:00Z", "method": "PKCS11_C_DestroyObject", "witness": "S003"}' WHERE key_id = ?;
-- HSM: C_DestroyObject (externo)
-- Rust: zeroize crate
```
- bos_key_inventory (metadata JSONB) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 87: Certificate expiry alert — <24h
```sql
SELECT key_id, key_type, expires_at FROM bauth.bos_key_inventory 
WHERE state = 'ACTIVE' AND expires_at < NOW() + INTERVAL '24 hours' AND expires_at > NOW();
```
- bos_key_inventory ✅
- **Veredicto: ✅ COMPLETO**

### Caso 88: Root CA ceremony — registro de evento
```sql
INSERT INTO bauth.bos_key_recovery_log (key_id, recovery_type, approved_by, result, ctx_id, notes)
VALUES (?, 'BREAK_GLASS', ARRAY['uuid-s002','uuid-s003','uuid-s004'], 'SUCCESS', 'ctx_ceremony', 'Root CA generation ceremony. 2-of-3 Shamir. Video recorded.');
```
- bos_key_recovery_log (approved_by UUID[]) ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**

### Caso 89: ADSIB certificate lifecycle — renovación
```sql
UPDATE bauth.bos_key_inventory SET state = 'DEACTIVATED' WHERE key_type = 'ADSIB_CERT' AND state = 'ACTIVE';
INSERT INTO bauth.bos_key_inventory (key_type, algorithm, rotation_interval, storage_backend, state, expires_at)
VALUES ('ADSIB_CERT', 'RSA-4096-SHA256', INTERVAL '2 years', 'VAULT_KV2', 'ACTIVE', NOW() + INTERVAL '2 years');
INSERT INTO bauth.bos_key_rotation_log (key_id, rotation_type, overlap_start, overlap_end, status) VALUES ('new-cert-uuid', 'SCHEDULED', NOW(), NOW() + INTERVAL '24 hours', 'COMPLETED');
```
- bos_key_inventory ✅ · bos_key_rotation_log ✅
- **Veredicto: ⚠️ ¿key_type='ADSIB_CERT' en CHECK constraint?** La constraint actual solo lista 10 tipos. Falta ADSIB_CERT.
- **Veredicto: ⚠️ REQUIERE** ADSIB_CERT en ck_key_type

### Caso 90: Key dashboard — inventario completo
```sql
SELECT key_type, COUNT(*) FILTER (WHERE state='ACTIVE') as active, COUNT(*) FILTER (WHERE state='COMPROMISED') as compromised, MIN(expires_at) as next_expiry
FROM bauth.bos_key_inventory GROUP BY key_type;
```
- bos_key_inventory ✅
- **Veredicto: ✅ COMPLETO**

---

## BLOQUE 8: DISPOSITIVOS Y HARDWARE (Casos 91-100)

### Caso 91: Registrar banexus agent
```sql
INSERT INTO bauth.bos_device_registry (node_id, device_type, serial_number, firmware_version, hardware_model, tenant_id, status, mac_address)
VALUES ('terminal-caja-03', 'banexus_agent', 'SN-2026-001', '2.1.0', 'Dell OptiPlex 7080', ?, 'active', 'aa:bb:cc:dd:ee:ff');
```
- bos_device_registry ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**

### Caso 92: Emitir certificado mTLS para banexus
```sql
-- Vault PKI: vault write pki/issue/banexus common_name="terminal-caja-03" ttl=24h
UPDATE bauth.bos_device_registry SET certificate_serial = 'serial-from-vault' WHERE node_id = 'terminal-caja-03';
```
- bos_device_registry (certificate_serial) ✅ (v3.0)
- Vault PKI: externo ✅
- **Veredicto: ✅ COMPLETO**

### Caso 93: Device heartbeat — actualizar last_seen
```sql
UPDATE bauth.bos_device_registry SET last_seen = NOW(), firmware_version = '2.1.1' WHERE node_id = 'terminal-caja-03';
```
- bos_device_registry (last_seen) ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**

### Caso 94: Device offline alert — >2min sin heartbeat
```sql
SELECT node_id, device_type, last_seen FROM bauth.bos_device_registry 
WHERE status = 'active' AND last_seen < NOW() - INTERVAL '2 minutes';
```
- bos_device_registry ✅
- **Veredicto: ✅ COMPLETO**

### Caso 95: Decommission device
```sql
UPDATE bauth.bos_device_registry SET status = 'decommissioned', metadata = metadata || '{"decommissioned_at": "2026-06-21", "reason": "reemplazo"}'
WHERE device_id = ?;
-- Revocar certificado mTLS (Vault PKI)
-- Wipe credentials (factory reset via WebSocket)
```
- bos_device_registry ✅
- **Veredicto: ✅ COMPLETO**

### Caso 96: Device group management
```sql
-- Agrupar dispositivos por zona
SELECT * FROM bauth.bos_device_registry WHERE zone_id = ? AND status = 'active';
```
- bos_device_registry (zone_id) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 97: Firmware update push
```sql
UPDATE bauth.bos_device_registry SET firmware_version = '2.2.0', metadata = metadata || '{"last_fw_update": "2026-06-21T12:00:00Z", "fw_checksum": "sha256..."}' WHERE node_id = 'terminal-caja-03';
```
- bos_device_registry (metadata JSONB) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 98: Device audit trail — ciclo de vida completo
```sql
SELECT * FROM bauth.bauth_audit_events 
WHERE details->>'device_id' = 'device-uuid'
ORDER BY created_at;
```
- bauth_audit_events (details JSONB) ✅
- **Veredicto: ✅ COMPLETO**

### Caso 99: OSDP reader — CredentialEvent normalizado
```sql
-- OSDP reader → bhnexus → CredentialEvent → bAuth
-- bAuth consulta:
SELECT * FROM bos_privilege.bos_role_bitmask_view WHERE role_slug = ?;
-- Verificar átomo D2 (zonas físicas)
-- Registrar en auditoría
INSERT INTO bos_privilege.bos_atom_audit (ctx_id, tenant_id, role_id, app_code, group_code, atom_code, atom_position, bitmask_atom, policy_state, result, evaluator, domain_code)
VALUES (?, ?, ?, 0, 0, 1, 5, 0x..., 0, 1, 'bhnexus', 2);
```
- bos_role_bitmask_view ✅ · bos_atom_audit ✅
- **Veredicto: ✅ COMPLETO**

### Caso 100: Terminal fingerprint binding — anti session hijacking
```sql
-- Al crear ctx_id, calcular fingerprint
-- terminal_fingerprint = hash(mac + tpm_ek_cert + hostname)
UPDATE bauth.context_sessions SET terminal_fingerprint = 'hash_value' WHERE ctx_id = 'ctx_001';
-- En cada validación, comparar fingerprint del request con el almacenado
```
- context_sessions (terminal_fingerprint) ✅ (v3.0)
- **Veredicto: ✅ COMPLETO**
