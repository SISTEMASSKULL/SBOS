-- seed_ath_policy_d12.sql — Políticas D12 Blockchain/Trazabilidad
-- IDEMPOTENTE: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: NIST IR 8202 · W3C DID Core 1.0 · EIP-712 · ERC-725/735
SET lock_timeout = '5s';
TRUNCATE TABLE bauth.ath_policy_d12 RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.ath_policy_d12;

INSERT INTO bauth.ath_policy_d12 (policy_code, policy_name, description, standard_ref, config) VALUES
('MERKLE_ANCHOR_HOURLY',   'Anclaje Merkle cada hora',     'Lotes de eventos sellados y anclados a Arbitrum One cada 1 hora. Hash-chain inmutable.', '{NIST IR 8202}', '{"rule":"merkle_anchor","frequency":"hourly","network":"arbitrum_one","algorithm":"Keccak256"}'),
('MERKLE_PROOF_VERIFIABLE', 'Proof verificable independiente','Cada hoja Merkle incluye proof para verificación sin acceso a BD completa.', '{NIST IR 8202}', '{"rule":"merkle_proof","verifiable":true,"algorithm":"Keccak256"}'),
('DID_W3C_REGISTRY',        'Identidad Descentralizada W3C', 'Registro de DID método did:web y did:ethr. Resolución universal.', '{W3C DID Core 1.0,ERC-725}', '{"rule":"did_registry","methods":["did:web","did:ethr"],"resolution":"universal"}'),
('DID_VC_SIGNED',           'Credenciales Verificables',     'Emisión y verificación de Verifiable Credentials W3C. JWT+LD sobre Besu.', '{W3C VC 1.0,ERC-735}', '{"rule":"verifiable_credentials","format":"jwt_ld","verify_issuer":true}'),
('SMART_CONTRACT_AUDIT',    'Auditoría de Smart Contracts',  'Todo deploy/interacción crítica requiere verificación de bytecode previa.', '{EIP-712,ISO 27001 A.8.15}', '{"rule":"contract_audit","verify_bytecode":true,"require_multisig":true}'),
('TX_VALIDATE_CONSENSUS',   'Validación por consenso IBFT',  'Transacciones críticas requieren confirmación de 2/3 de validadores QBFT.', '{NIST IR 8202}', '{"rule":"consensus","algorithm":"qbft","min_validators":4,"required_majority":true}');
