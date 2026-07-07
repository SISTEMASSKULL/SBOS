-- =============================================================================
-- bauth_75__lib_d12_blockchain.sql — Políticas blockchain D12 (incremento)
-- =============================================================================
-- Propósito  : Agregar políticas del dominio blockchain directamente a
--              cfg_policy_library (sin depender de JSON fuente).
-- Normas     : Hyperledger Besu 24.x — Enterprise Ethereum
--              EIP-712 (2017, final 2022) — Typed structured data signing
--              EIP-1193 (2021) — Ethereum provider JavaScript API
--              EIP-4361 (2022) — Sign In With Ethereum (SIWE)
--              EIP-3668 (2023) — CCIP Read (Cross-Chain Interoperability)
--              Ethereum Yellow Paper §11 — Cryptographic functions
--              OWASP Smart Contract Top 10:2023
--              Bolivia Ley 164 Art.75 — Firma digital con validez jurídica
--              ADSIB-FD-POLT-015 v2.3 — Certificación digital Bolivia
--              NIST SP 800-57 Part 1 Rev.5 — Elliptic curve key management
--              ISO/IEC 27033-1:2015 — Network security (blockchain nodes)
-- Fuente     : Investigación 2025-2026 (normas vigentes hasta 2026)
-- Idempotente: Sí — ON CONFLICT (json_path) DO NOTHING
-- =============================================================================
SET lock_timeout = '5s';

INSERT INTO bauth.cfg_policy_library (
  section_name, parent_path, json_path, depth, array_index, node_type,
  semantic_type, domain_map, source, standard_ref, compliance_ref,
  content, content_en, content_es,
  enforcement, risk_level, lifecycle,
  assurance_level, mfa_required, phishing_resistant
) VALUES

-- 1. Hyperledger Besu — Autenticación de nodos y permisos
(
  'hyperledger_besu_node_authentication', NULL, 'd12_blockchain_ext.hyperledger_besu_node_authentication',
  1, 0, 'policy', 'standard', ARRAY['D12','D7'], 'd12_blockchain_ext',
  'Hyperledger Besu 24.x', ARRAY['Hyperledger Besu Docs §Permissioning', 'EEA Client Spec 1.0.0 §7', 'Ethereum Yellow Paper §11'],
  '{"title":"Hyperledger Besu Node Authentication","description":"SBOS uses Hyperledger Besu as its enterprise Ethereum blockchain. Node authentication and permissioning requirements: (1) IBFT 2.0 consensus — only permissioned validators can produce blocks, (2) Node permissioning via on-chain smart contract (NodePermissioningContract) — whitelist of allowed enodeURLs, (3) Account permissioning via on-chain smart contract (AccountPermissioningContract), (4) Each Besu node authenticated with ECDSA secp256k1 node key (unique per node), (5) TLS between nodes: required for enterprise deployment (Besu TLS configuration), (6) JWT for JSON-RPC API authentication (Besu EthAuthentication), (7) Admin RPC restricted to localhost or VPN, (8) Node key rotation: maximum 1 year, HSM storage mandatory for validator keys.","consensus":"IBFT_2.0","permissioning":{"node":"on_chain_contract","account":"on_chain_contract"},"tls_inter_node":true,"jwt_rpc_auth":true,"validator_key_storage":"HSM","key_rotation_days":365,"admin_rpc":"localhost_or_vpn_only"}',
  '{"title":"Hyperledger Besu Node Authentication","description":"SBOS Besu: IBFT 2.0 consensus, on-chain node/account permissioning, TLS inter-node, JWT for RPC, HSM for validator keys, 1-year key rotation.","consensus":"IBFT_2.0","permissioning":{"node":"on_chain_contract","account":"on_chain_contract"}}',
  '{"titulo":"Autenticación Nodos Hyperledger Besu","descripcion":"Besu SBOS: consenso IBFT 2.0, permisos nodo/cuenta en cadena, TLS entre nodos, JWT para RPC, HSM para claves validadoras, rotación clave 1 año.","consenso":"IBFT_2.0","permisos":{"nodo":"contrato_en_cadena","cuenta":"contrato_en_cadena"}}',
  'mandatory', 'critical', 'active', 'AAL3', true, true
),

-- 2. EIP-712 — Firma estructurada de datos para autorización
(
  'eip712_typed_structured_signing', NULL, 'd12_blockchain_ext.eip712_typed_structured_signing',
  1, 0, 'policy', 'standard', ARRAY['D12'], 'd12_blockchain_ext',
  'EIP-712 (2022)', ARRAY['EIP-712 final (2022-08-26)', 'EIP-191 §1.4', 'OWASP SC Top 10:2023 SC06'],
  '{"title":"EIP-712 Typed Structured Data Signing","description":"SBOS uses EIP-712 for typed structured data signing in blockchain operations requiring human-readable authorization. Requirements: (1) All off-chain authorization messages (delegation, approval, permit) must use EIP-712 domain separation to prevent cross-domain replay attacks, (2) Domain separator must include: name (contract name), version, chainId (Besu private network chain ID), verifyingContract address, (3) Typed data schemas must be pre-registered and version-controlled in SBOS, (4) Signature verification performed in bAuth before submitting to chain, (5) EIP-712 signatures valid for maximum 1 hour (timestamp included in signed message), (6) Phishing-resistant: user wallet must display human-readable EIP-712 form before signing, (7) EIP-712 MUST NOT be used with wallet_signTypedData_v1 (deprecated) — use eth_signTypedData_v4 only.","domain_separator":{"name":"required","version":"required","chainId":"required","verifyingContract":"required"},"signature_validity_minutes":60,"phishing_resistant_display":true,"deprecated_methods":["wallet_signTypedData_v1","eth_signTypedData_v3"],"approved_method":"eth_signTypedData_v4"}',
  '{"title":"EIP-712 Typed Structured Data Signing","description":"EIP-712 typed signing for SBOS blockchain auth. Domain separator: name+version+chainId+contract. Max 1h validity. eth_signTypedData_v4 only. v1/v3 deprecated. Human-readable display required.","domain_separator":{"name":"required","version":"required","chainId":"required","verifyingContract":"required"}}',
  '{"titulo":"Firma Datos Estructurados EIP-712","descripcion":"Firma tipada EIP-712 para auth blockchain SBOS. Separador dominio: nombre+versión+chainId+contrato. Validez máx 1h. Solo eth_signTypedData_v4. v1/v3 obsoletos. Visualización legible por humanos requerida.","separador_dominio":{"nombre":"requerido","version":"requerida","chainId":"requerido","contratoVerificador":"requerido"}}',
  'mandatory', 'critical', 'active', 'AAL2', true, true
),

-- 3. Gestión de claves privadas Ethereum
(
  'ethereum_private_key_management', NULL, 'd12_blockchain_ext.ethereum_private_key_management',
  1, 0, 'policy', 'standard', ARRAY['D12'], 'd12_blockchain_ext',
  'NIST SP 800-57 Part 1 Rev.5', ARRAY['NIST SP 800-57 Part 1 Rev.5 §5.6.4', 'NIST SP 800-186 §3.1 (secp256k1)', 'Ethereum Yellow Paper §3', 'Bolivia Ley 164 Art.80'],
  '{"title":"Ethereum Private Key Management Policy","description":"Ethereum private keys (secp256k1 ECDSA) used in SBOS for blockchain operations require strict lifecycle management. Requirements: (1) Private keys NEVER stored unencrypted on disk or transmitted in plaintext, (2) Storage: Vault Transit engine for application keys, HSM for validator keys, (3) Key generation: using CSPRNG, never from low-entropy sources, (4) BIP-32/BIP-44 hierarchical deterministic wallets (derivation path: m/44h/60h/0h/0/index — BIP-44 hardened), (5) Mnemonic phrases (BIP-39): 24 words minimum, Vault sealed storage, never in code, (6) Key rotation: on compromise, personnel change, or every 2 years, (7) Multisig required for keys controlling >$10,000, (8) Key recovery: Shamir Secret Sharing 3-of-5.","storage":{"application_keys":"vault_transit","validator_keys":"HSM"},"key_generation":"CSPRNG","hd_wallet":{"bip_standard":"BIP-32/BIP-44","derivation_path":"m/44h/60h/0h/0/index"},"multisig_threshold_usd":10000,"recovery":"SSS_3_of_5","rotation_years":2}',
  '{"title":"Ethereum Private Key Management","description":"secp256k1 keys: Vault Transit for apps, HSM for validators. CSPRNG generation, BIP-44 HD wallets (m/44h/60h/0h/0/index), BIP-39 24-word mnemonics. Multisig >$10k. SSS 3-of-5 recovery. 2-year rotation.","storage":{"application_keys":"vault_transit","validator_keys":"HSM"}}',
  '{"titulo":"Gestión Claves Privadas Ethereum","descripcion":"Claves secp256k1: Vault Transit para aplicaciones, HSM para validadores. Generación CSPRNG, wallets HD BIP-44 (m/44h/60h/0h/0/index), mnemónicos BIP-39 24 palabras. Multisig >$10k. Recuperación SSS 3-de-5. Rotación 2 años.","almacenamiento":{"claves_aplicacion":"vault_transit","claves_validador":"HSM"}}',
  'mandatory', 'critical', 'active', 'AAL3', true, true
),

-- 4. OWASP Smart Contract Top 10 — Seguridad de contratos inteligentes
(
  'owasp_smart_contract_security', NULL, 'd12_blockchain_ext.owasp_smart_contract_security',
  1, 0, 'policy', 'standard', ARRAY['D12'], 'd12_blockchain_ext',
  'OWASP Smart Contract Top 10:2023', ARRAY['OWASP SC-01 Reentrancy', 'OWASP SC-02 Integer Overflow', 'OWASP SC-04 Access Control', 'OWASP SC-06 Unprotected Self-Destruct'],
  '{"title":"OWASP Smart Contract Top 10:2023 Security Policy","description":"Smart contracts deployed on SBOS Besu must comply with OWASP Smart Contract Top 10:2023. Required mitigations: (1) SC-01 Reentrancy: use Checks-Effects-Interactions pattern + ReentrancyGuard (OpenZeppelin), (2) SC-02 Integer Overflow: use Solidity 0.8+ built-in overflow checks or SafeMath, (3) SC-03 Timestamp Dependence: never rely on block.timestamp for critical logic (±900s miner manipulation), (4) SC-04 Access Control: use OpenZeppelin AccessControl/Ownable, all state-changing functions require caller validation, (5) SC-05 Front-Running: use commit-reveal pattern for sensitive operations, (6) SC-06 Unprotected Self-Destruct: prohibit selfdestruct unless behind multisig, (7) SC-07 Gas Griefing: limit external calls, avoid unbounded loops, (8) Mandatory security audit before production deployment (Slither + Mythril + manual review), (9) All contracts must be verified on Besu explorer.","required_mitigations":{"SC_01":"ReentrancyGuard","SC_02":"Solidity_0.8_overflow","SC_03":"no_timestamp_critical","SC_04":"AccessControl_OpenZeppelin","SC_05":"commit_reveal","SC_06":"multisig_selfdestruct","SC_07":"bounded_loops"},"mandatory_audit":true,"audit_tools":["Slither","Mythril"],"contract_verification":true}',
  '{"title":"OWASP Smart Contract Top 10:2023","description":"Required: ReentrancyGuard, Solidity 0.8+ overflow, AccessControl, commit-reveal, no timestamp for critical, multisig for selfdestruct. Mandatory Slither+Mythril audit before deployment.","required_mitigations":{"SC_01":"ReentrancyGuard","SC_04":"AccessControl_OpenZeppelin"}}',
  '{"titulo":"OWASP Smart Contract Top 10:2023","descripcion":"Obligatorio: ReentrancyGuard, overflow Solidity 0.8+, AccessControl, commit-reveal, sin timestamp para crítico, multisig para selfdestruct. Auditoría obligatoria Slither+Mythril antes del despliegue.","mitigaciones_requeridas":{"SC_01":"ReentrancyGuard","SC_04":"AccessControl_OpenZeppelin"}}',
  'mandatory', 'critical', 'active', 'AAL2', true, false
),

-- 5. EIP-4361 SIWE — Sign In With Ethereum como autenticador
(
  'eip4361_siwe_authentication', NULL, 'd12_blockchain_ext.eip4361_siwe_authentication',
  1, 0, 'policy', 'standard', ARRAY['D12','D9'], 'd12_blockchain_ext',
  'EIP-4361 (2022)', ARRAY['EIP-4361 final (2022)', 'EIP-55 (checksum address)', 'RFC 3339 (ISO 8601 timestamps)'],
  '{"title":"EIP-4361 Sign In With Ethereum (SIWE) Authentication","description":"SBOS supports Sign In With Ethereum (SIWE) per EIP-4361 as an authentication method for blockchain-native users. Policy: (1) SIWE message must include: domain (current SBOS domain), address (Ethereum checksummed per EIP-55), statement, URI, version, chainId, nonce, issuedAt, expirationTime, (2) Nonce: minimum 8 alphanumeric chars, single-use (Redis TTL 10min), (3) expirationTime: maximum 10 minutes from issuedAt, (4) chainId must match SBOS Besu private network chain ID (configured, not trusting client), (5) Domain binding: SIWE domain must exactly match SBOS domain (prevents phishing), (6) SIWE provides AAL2 when combined with hardware wallet (Ledger/Trezor), AAL1 with software wallet, (7) Replay attack prevention: nonce invalidated after first successful verification.","required_fields":["domain","address","statement","uri","version","chainId","nonce","issuedAt","expirationTime"],"nonce_min_length":8,"nonce_ttl_minutes":10,"expiration_max_minutes":10,"chainId_server_enforced":true,"hardware_wallet":"AAL2","software_wallet":"AAL1"}',
  '{"title":"EIP-4361 SIWE Authentication","description":"SIWE per EIP-4361: required fields include domain+address+nonce+expiry. Nonce 8+ chars, 10min TTL. expiry max 10min. Domain binding prevents phishing. Hardware wallet=AAL2, software=AAL1.","required_fields":["domain","address","nonce","issuedAt","expirationTime"]}',
  '{"titulo":"Autenticación EIP-4361 SIWE","descripcion":"SIWE según EIP-4361: campos requeridos incluyen dominio+dirección+nonce+expiración. Nonce 8+ chars, TTL 10min. expiración máx 10min. Vinculación de dominio previene phishing. Wallet hardware=AAL2, software=AAL1.","campos_requeridos":["dominio","direccion","nonce","emitidoEn","tiempoExpiracion"]}',
  'mandatory', 'high', 'active', 'AAL2', false, true
),

-- 6. Bolivia Ley 164 — Firma digital blockchain con validez jurídica
(
  'bolivia_blockchain_digital_signature_legal', NULL, 'd12_blockchain_ext.bolivia_blockchain_digital_signature_legal',
  1, 0, 'policy', 'standard', ARRAY['D12'], 'd12_blockchain_ext',
  'Bolivia Ley 164 Art.75', ARRAY['Bolivia Ley 164 Art.75-80', 'ADSIB-FD-POLT-015 v2.3', 'Bolivia DS 1793 Art.16', 'SIN RND 102100000011 §8'],
  '{"title":"Bolivia Ley 164 — Blockchain Digital Signature with Legal Validity","description":"Bolivia Ley 164 establishes legal validity for electronic signatures. For blockchain transactions in SBOS to have legal validity under Bolivian law: (1) Ethereum ECDSA signatures (secp256k1) alone do NOT constitute firma digital válida under Ley 164 — they are electronic signatures (firma electrónica), (2) For legal validity (firma digital), the Ethereum address must be linked to a certified ADSIB certificate via a registration attestation stored on-chain, (3) The ADSIB-to-Ethereum address binding registry must be maintained in SBOS blockchain (immutable, auditable), (4) Transactions requiring firma digital válida: contracts, financial authorizations, regulatory filings, (5) Transaction for non-legal-validity (firma electrónica): general platform operations, (6) The distinction must be enforced at the access control level — operations requiring firma digital must verify ADSIB-Ethereum binding.","signature_types":{"firma_digital_valida":{"requires":"ADSIB_certificate_binding","use_cases":["contracts","financial_auth","regulatory_filings"]},"firma_electronica":{"ethereum_ecdsa_only":true,"use_cases":["general_operations"]}},"adsib_binding_registry":"on_chain","adsib_authority":"ADSIB Bolivia"}',
  '{"title":"Bolivia Ley 164 Blockchain Digital Signature","description":"Ethereum ECDSA = firma electrónica only. For firma digital con validez legal: ADSIB certificate must be bound to Ethereum address via on-chain registry. Contracts/financial auth/regulatory require firma digital.","signature_types":{"firma_digital":{"requires":"ADSIB_binding"},"firma_electronica":{"ethereum_only":true}}}',
  '{"titulo":"Firma Digital Blockchain Bolivia Ley 164","descripcion":"ECDSA Ethereum = solo firma electrónica. Para firma digital con validez legal: certificado ADSIB debe vincularse a dirección Ethereum vía registro en cadena. Contratos/autorización financiera/regulatoria requieren firma digital.","tipos_firma":{"firma_digital":{"requiere":"vinculo_ADSIB"},"firma_electronica":{"solo_ethereum":true}}}',
  'mandatory', 'critical', 'active', 'AAL3', true, true
),

-- 7. Verificación de inmutabilidad de registros en cadena
(
  'blockchain_immutability_audit_verification', NULL, 'd12_blockchain_ext.blockchain_immutability_audit_verification',
  1, 0, 'policy', 'policy', ARRAY['D12','D11'], 'd12_blockchain_ext',
  'ISO/IEC 27033-1:2015', ARRAY['ISO/IEC 27033-1:2015 §8.4', 'NIST SP 800-53 Rev.5 AU-10', 'NIST SP 800-57 Part 1 §5.7'],
  '{"title":"Blockchain Immutability Audit Verification Policy","description":"SBOS uses the Besu private blockchain as an immutable audit trail for critical authentication events. Policy: (1) Critical events anchored to blockchain: privilege escalations, financial authorizations, identity changes, delegation grants, (2) Each event hash (SHA3-256 / keccak256) stored on-chain with Ethereum transaction, (3) Periodic Merkle root checkpoint: every 1000 events or 24 hours, (4) Off-chain events verifiable against on-chain Merkle root at any time, (5) Blockchain audit log must not be the only copy — parallel storage in PostgreSQL aud_event table, (6) Block reorganization protection: wait minimum 12 block confirmations (IBFT 2.0 finality) before considering event immutable, (7) Annual blockchain audit: verify chain integrity from genesis block.","anchored_events":["privilege_escalation","financial_authorization","identity_change","delegation_grant"],"hash_function":"keccak256","merkle_checkpoint":{"events":1000,"hours":24},"finality_blocks":12,"dual_storage":["blockchain","postgresql_aud_event"],"annual_integrity_audit":true}',
  '{"title":"Blockchain Immutability Audit Verification","description":"Critical events (privilege escalation, financial auth, identity change, delegation) anchored to Besu blockchain via keccak256 hash. Merkle checkpoint every 1000 events/24h. IBFT 2.0 finality=12 blocks. Dual storage blockchain+PostgreSQL.","anchored_events":["privilege_escalation","financial_authorization"],"finality_blocks":12}',
  '{"titulo":"Verificación Inmutabilidad Auditoría Blockchain","descripcion":"Eventos críticos (escalada privilegios, autorización financiera, cambio identidad, delegación) anclados a blockchain Besu vía hash keccak256. Checkpoint Merkle cada 1000 eventos/24h. Finalidad IBFT 2.0=12 bloques. Almacenamiento dual blockchain+PostgreSQL.","eventos_anclados":["escalada_privilegios","autorizacion_financiera"],"bloques_finalidad":12}',
  'mandatory', 'critical', 'active', 'AAL2', true, false
),

-- 8. Gestión de gas y prevención de ataques de denegación en Besu
(
  'besu_gas_management_dos_prevention', NULL, 'd12_blockchain_ext.besu_gas_management_dos_prevention',
  1, 0, 'policy', 'policy', ARRAY['D12','D7'], 'd12_blockchain_ext',
  'Hyperledger Besu 24.x', ARRAY['Hyperledger Besu Transaction Pool Docs', 'EIP-1559 (2021)', 'OWASP SC-07 (Gas Griefing)'],
  '{"title":"Besu Gas Management and DoS Prevention Policy","description":"Ethereum gas mechanics in SBOS Besu must be configured to prevent Denial-of-Service attacks via gas exhaustion. Policy: (1) EIP-1559 transaction type 2 mandatory for all SBOS smart contract calls (dynamic fee market), (2) Gas limit per transaction: maximum 10,000,000 units (configurable per contract), (3) Transaction pool (txpool) configuration: max_transactions_per_sender=100, max_pool_size=8192, (4) Gas price floor: 1 gwei minimum to prevent spam, (5) Smart contracts must not have unbounded loops (gas exhaustion risk), (6) Contract function gas cost profiled before deployment (Hardhat gas reporter), (7) Rate limiting at bAuth level: max 100 blockchain transactions per user per minute, (8) Emergency pause: all blockchain transactions can be halted by admin for incident response (OpenZeppelin Pausable pattern).","eip1559":true,"max_gas_per_tx":10000000,"txpool":{"max_per_sender":100,"max_pool_size":8192},"gas_floor_gwei":1,"rate_limit_per_min":100,"emergency_pause":true,"gas_profiling_required":true}',
  '{"title":"Besu Gas Management DoS Prevention","description":"EIP-1559 mandatory. Max gas 10M/tx. txpool: 100 per sender, 8192 total. 1 gwei floor. Rate limit: 100 tx/user/min. Unbounded loops prohibited. Emergency pause via OpenZeppelin Pausable.","eip1559":true,"max_gas_per_tx":10000000,"rate_limit_per_min":100}',
  '{"titulo":"Gestión Gas Besu y Prevención DoS","descripcion":"EIP-1559 obligatorio. Gas máx 10M/tx. txpool: 100 por emisor, 8192 total. Piso 1 gwei. Límite de tasa: 100 tx/usuario/min. Bucles ilimitados prohibidos. Pausa de emergencia vía OpenZeppelin Pausable.","eip1559":true,"gas_max_por_tx":10000000,"limite_tasa_por_min":100}',
  'mandatory', 'high', 'active', 'AAL2', true, false
)

ON CONFLICT (json_path) DO NOTHING;

SELECT COUNT(*) AS politicas_d12_incremento_insertadas FROM bauth.cfg_policy_library WHERE source = 'd12_blockchain_ext';
