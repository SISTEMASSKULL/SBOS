# BAUTH-FASES-ROBUSTEZ — Especificación de Robustez D12, D13, Token, Autenticación, Context Plane
## bAuth Identity Core v3.0 · REPARACIONBAUTH · FASES 7–11

**Versión:** 1.0.0 · **Fecha:** 2026-07-01 · **Clasificación:** CRÍTICO
**Propósito:** Especificación atómica y profesional para robustecer las capacidades
de bAuth ya operativo. Toda tarea es verificable en VPS con pods K8s reales.
**Estado de bAuth:** Funcionando en VPS — 94 handlers JSON-RPC · 9 validadores nativos ·
328 tests · 5.2MB MUSL estático · Keycloak independiente · D12 operativo.
**Premisa:** Ninguna prueba fuera de pods K8s. Todo en ambiente real certificado.

---

## MAPA DE FASES

| Fase | Dominio | Tareas | Normas principales | Estado |
|------|---------|:------:|-------------------|:------:|
| FASE 7 | D12 Blockchain — Consolidación y certificación formal | 14 | EIP-712, RFC 6962, NIST IR 8202, ISO 22739:2020 | ⏳ |
| FASE 8 | D13 Wallet + DID + ADSIB/SIN — Implementación completa | 18 | EIP-55, EIP-712, W3C DID Core 1.0, Ley 164 Bolivia, RFC 5652 | ⏳ |
| FASE 9 | Token Generation — Robustez del JWT canónico | 12 | RFC 7519, RFC 7636, RFC 9449, EdDSA Ed25519, NIST FIPS 186-5 | ⏳ |
| FASE 10 | Métodos de Autenticación — Certificación formal catálogo completo | 16 | NIST SP 800-63B-4, OWASP ASVS 5.0, RFC 6238, RFC 4226, W3C WebAuthn L2 | ⏳ |
| FASE 11 | ctx_id y Context Plane — Integración robusta con BOS | 12 | SBOS-049, W3C Trace Context, OpenTelemetry Baggage, NIST SP 800-207, CAEP 1.0 | ⏳ |

---

## REGLAS ABSOLUTAS DE IMPLEMENTACIÓN

| Regla | Descripción |
|-------|-------------|
| **R1** | Toda prueba en pods K8s reales. Sin mocks, sin simulación local. |
| **R2** | Toda tarea referencia la norma o estándar exacto que valida. |
| **R3** | Toda tarea tiene SQL o comando verificable antes de marcarse completada. |
| **R4** | Ninguna tarea se ejecuta sin estar en REGISTRO-ESTADO-REDISEÑO.md con estado ⏳. |
| **R5** | ctx_id obligatorio en CADA audit_event. Sin ctx_id = tarea rechazada. |
| **R6** | Código ≤ 200 líneas por módulo, ≤ 50 líneas por función (DOC-SBOS-001 N3). |
| **R7** | DDL pendiente de aprobación humana antes de aplicar (feedback DDL). |
| **R8** | Todo commit en español. Formato: `[FASE-X.ID] descripción en español`. |

---

## FASE 7 — D12 Blockchain: Consolidación y Certificación Formal

**Estado D12 actual:**
- `blockchain/anchor.rs` — 6,025 líneas — Forma A (Merkle + Arbitrum/Besu) ✅ en VPS
- `blockchain/settlement.rs` — 12,317 líneas — Forma B (liquidación on-chain) ✅ en VPS
- Besu QBFT 24.12.0 en pod K8s, puerto 8545 ClusterIP
- 42/42 JSON-RPC handlers pasando en VPS

**Objetivo:** No reimplementar — VERIFICAR cumplimiento formal de normas y corregir gaps.

### GRUPO F7.A — Verificación de normas criptográficas

**F7.A1 — Verificar cumplimiento EIP-712 en signed_data (campos + domainSeparator)**
- Archivo: `src/domain/blockchain/anchor.rs`
- Verificar: cada `typed_data` generado sigue exactamente `hashStruct(TypedData) = keccak256(encodeData(TypedData))`
- EIP-712 §2.1: el `domainSeparator` debe incluir: `chainId`, `name`, `version`, `verifyingContract`
- Estructura esperada:
  ```
  domainSeparator = keccak256(encode(
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
    keccak256("SBOS"), keccak256("1.0"), chainId, verifyingContract
  ))
  ```
- Test: `cargo test blockchain::anchor::test_domain_separator_eip712 -- --nocapture`
- Verificación SQL: `SELECT tx_hash, block_number FROM bauth.blk_anchor_log WHERE anchored_at > now()-interval '1h' LIMIT 5;` → todas tienen `tx_hash` no nulo
- **Si falla:** corregir el hash del domainSeparator en `anchor.rs` línea que construye `domain_separator_hash`

**F7.A2 — Verificar cadena criptográfica prev_hash + token_seq en cada anchor**
- La cadena de custodia bAuth implementa:
  ```
  anchor_n.prev_hash = sha256(anchor_{n-1}.tx_hash || anchor_{n-1}.merkle_root)
  anchor_n.token_seq = anchor_{n-1}.token_seq + 1
  ```
- Verificar que ningún `anchor_log` tiene `prev_hash = null` salvo el genesis (seq=0)
- Verificación SQL:
  ```sql
  SELECT COUNT(*) FROM bauth.blk_anchor_log
  WHERE prev_hash IS NULL AND batch_number > 0;
  ```
  → debe retornar `0`
- Test: `cargo test blockchain::anchor::test_chain_integrity -- --nocapture`
- **Norma:** NIST IR 8202 §4.1.2 (immutability via cryptographic chaining)

**F7.A3 — Verificar Keccak-256 (FIPS 202 SHA3) en hojas Merkle**
- Cada hoja: `leaf_hash = keccak256(event_id || event_type || timestamp || ctx_id)`
- Los vectores de test DEBEN usar los vectores oficiales de FIPS 202 Appendix B
- Test con vector conocido: `keccak256("") = 0xc5d2460186...e21d4fa09b37` (64 hex chars)
- Archivo de test: `tests/blockchain/merkle_vectors_fips202.rs`
- Verificación:
  ```bash
  cargo test --test merkle_vectors_fips202 -- --nocapture
  ```
  → TODOS los vectores FIPS 202 deben pasar
- **Norma:** NIST FIPS 202 (SHA-3 Standard, agosto 2015) + EIP-3 (Keccak-256 en Ethereum)

**F7.A4 — Verificar RFC 6962 Merkle consistency proofs**
- Forma A construye árboles Merkle binarios. RFC 6962 §2.1 define:
  - Hoja: `HASH(0x00 || leaf_data)`
  - Nodo interno: `HASH(0x01 || left_hash || right_hash)`
- El prefijo `0x00`/`0x01` previene ataques de second preimage
- Verificación: leer función que construye el árbol en `anchor.rs` y confirmar prefijos
- Test con árbol de 8 hojas (valor conocido): `cargo test blockchain::merkle::test_tree_8_leaves`
- **Norma:** RFC 6962 §2.1 (Certificate Transparency — Merkle Hash Trees)

### GRUPO F7.B — Verificación de conformidad normativa

**F7.B1 — Verificar NIST IR 8202 §4 — Inmutabilidad y Trazabilidad**
- NIST IR 8202 define 10 propiedades de blockchain. Las críticas para D12:
  - P1: Distributed/Decentralized — Besu QBFT con ≥ 4 validadores
  - P4: Immutability — `blk_anchor_log` es append-only (sin UPDATE, sin DELETE)
  - P5: Finality — QBFT ofrece finality determinística (no probabilística como PoW)
  - P8: Auditability — cada operación registra `ctx_id`, `anchored_at`, `tx_hash`
- Verificación SQL: confirmar que no existe ningún trigger UPDATE/DELETE en `blk_anchor_log`
  ```sql
  SELECT trigger_name FROM information_schema.triggers
  WHERE event_object_table = 'blk_anchor_log'
  AND event_manipulation IN ('UPDATE','DELETE');
  ```
  → `0 filas`
- Verificar pod Besu con 4 validadores activos:
  ```bash
  kubectl get pods -n sbos-blockchain -l app=besu-validator
  ```
  → 4 pods en estado `Running`
- **Norma:** NIST IR 8202 (Blockchain Technology Overview, 2018)

**F7.B2 — Verificar ISO 22739:2020 terminología en código y documentación**
- ISO 22739:2020 define terminología normativa de blockchain. Verificar que el código usa:
  - "distributed ledger" (no "blockchain" en contextos donde el término correcto es DLT)
  - "smart contract" (no "chaincode" que es terminología Fabric, no Besu/Ethereum)
  - "consensus mechanism" (no "mining" — QBFT es BFT, no PoW)
- Verificar en comentarios del código:
  ```bash
  grep -n "chaincode\|mining\|miner" src/domain/blockchain/
  ```
  → sin resultados (términos incorrectos para Besu QBFT)
- **Norma:** ISO 22739:2020 (Blockchain and distributed ledger technologies — Vocabulary)

**F7.B3 — Resolver conflicto GDPR right-to-forget vs. inmutabilidad blockchain**
- GDPR Art. 17 (right to erasure) vs. blockchain inmutable = conflicto arquitectónico conocido
- Resolución técnica implementada en SBOS (o que debe implementarse):
  - **No anclar PII directamente** — anclar únicamente hashes de eventos
  - **Patrón "hash, don't store":** el anchor contiene `sha256(event_id)`, no el event_id real
  - Si se elimina el registro de PII en PostgreSQL → el hash queda en blockchain (correcto)
  - El hash sin el preimage no constituye dato personal (GDPR Recital 26)
- Verificación SQL:
  ```sql
  SELECT column_name FROM information_schema.columns
  WHERE table_name = 'blk_anchor_log'
  AND column_name IN ('user_name','email','national_id','phone');
  ```
  → `0 filas` (ninguna PII directa en la tabla de anclas)
- **Normas:** GDPR Art.4(1) + Art.17 + Recital 26 + ENISA Guidelines on Blockchain (2019)

**F7.B4 — Verificar NetworkPolicy K8s aislamiento de pods Besu**
- Solo los daemons bAuth (puerto 9450) y bKernel (puerto 9460) pueden conectar a Besu RPC (8545 ClusterIP)
- Verificar la NetworkPolicy existe y está activa:
  ```bash
  kubectl get networkpolicy besu-ingress-policy -n sbos-blockchain -o yaml
  ```
  → debe listar `from.podSelector` con `app: bauth` y `app: bkernel` únicamente
- Test desde pod no autorizado:
  ```bash
  kubectl run test-unauthorized --image=curlimages/curl -it --rm -- curl http://besu-rpc:8545
  ```
  → `connection refused` o timeout (NetworkPolicy bloqueando)
- **Norma:** NSA/CISA Kubernetes Hardening Guide §5 (Network Isolation), SBOS-050 P9

### GRUPO F7.C — Trazabilidad, auditoría y Context Plane en D12

**F7.C1 — Verificar ctx_id en CADA evento D12 (ISO 27001 A.8.15)**
- Toda operación de D12 (anclar, liquidar, verificar proof) DEBE registrar el `ctx_id` activo
- Verificación SQL en `blk_anchor_log`:
  ```sql
  SELECT COUNT(*) FROM bauth.blk_anchor_log WHERE ctx_id IS NULL;
  ```
  → `0` (sin eventos sin ctx_id)
- Verificación SQL en `blk_settlement`:
  ```sql
  SELECT COUNT(*) FROM bauth.blk_settlement WHERE ctx_id IS NULL;
  ```
  → `0`
- Si hay nulos: agregar `ctx_id NOT NULL DEFAULT 'system'` vía ALTER (requiere aprobación DDL)
- **Norma:** ISO 27001:2022 A.8.15 (Logging), SBOS-049 (ctx_id obligatorio en toda operación)

**F7.C2 — Verificar output de auditoría a Wazuh syslog (siem.rs)**
- Archivo: `src/audit/siem.rs`
- Cada evento D12 debe emitir a syslog formato JSON:
  ```json
  {"event_type":"D12_ANCHOR","ctx_id":"...","tx_hash":"...","merkle_root":"...","severity":"INFO"}
  ```
- Test: ejecutar `bauth.blockchain.anchor.submit` y verificar que aparece en syslog:
  ```bash
  journalctl -u bauth -n 50 --no-pager | grep D12_ANCHOR
  ```
  → al menos 1 entrada con `D12_ANCHOR`
- **Norma:** ISO 27001:2022 A.8.15 + PCI DSS 4.0 Req 10.3.2 (audit trail integrity)

**F7.C3 — Verificar reconciliación on-chain ↔ PostgreSQL cada 15 minutos**
- El reconcile loop de bAuth ejecuta cada 60s para KC+Tryton. D12 tiene loop cada 15min
- Verificar que el job está activo:
  ```bash
  kubectl get cronjob blockchain-reconcile -n sbos-blockchain
  ```
  → `ACTIVE`, `SCHEDULE: */15 * * * *`
- Verificar última ejecución exitosa:
  ```sql
  SELECT last_reconcile_at, status FROM bauth.blk_anchor_reconciliation
  ORDER BY last_reconcile_at DESC LIMIT 1;
  ```
  → `status = 'OK'` y `last_reconcile_at < now() - interval '15 min'`
- **Norma:** NIST IR 8202 §4 (P8 Auditability), ISO 27001 A.8.9 (configuration management)

**F7.C4 — Verificar backup de cadena Besu a MinIO S01 (bos-preflight manifest)**
- Según ADR-016 (backups): `backups/S12/besu/` en estructura canónica
- Verificar que el CronJob de backup existe:
  ```bash
  kubectl get cronjob besu-backup -n sbos-blockchain
  ```
  → `SCHEDULE: 0 3 * * *` (3am diario)
- Verificar último backup en MinIO:
  ```bash
  mc ls sbos/backups/S12/besu/ | tail -5
  ```
  → archivos con timestamp del último día

---

## FASE 8 — D13 Wallet + DID + ADSIB/SIN Bolivia: Implementación desde Cero

**Estado D13 actual:** Solo diseño (BAUTH-DOMINIO-D13-BLOCKCHAIN.md). NINGÚN código implementado.
**Arquitectura:** 36 átomos nuevos (posiciones 5929–5964) + 3 apps (chain, did, legalsg)
**Depende de:** FASE 7 completada + FASE 3 (DDL D13 átomos) aprobada + fichas BOS D13

### GRUPO F8.A — Preparación de infraestructura

**F8.A1 — Fichas BOS requeridas para D13 (crear en `servers/S12/`)**
- Responsable de crear fichas: agente bos (pane 1)
- bAuth reporta requisitos via `BOS-BAUTH-CONTRATOS.md` (nuevo contrato C-BAUTH-D13)
- Fichas necesarias:
  | Ficha | Propósito | Pod destino |
  |-------|----------|-------------|
  | `besu-wallet` | Gestión de wallets secp256k1 con PKCS#11/Vault | S12/besu-wallet |
  | `besu-did-resolver` | Resolución de DID Documents (did:ethr, did:sbos) | S12/besu-did |
  | `adsib-connector` | Proxy al servicio ADSIB Bolivia para firma RSA-SHA256 | S06/adsib |
  | `sin-connector` | Conector SIN Bolivia para facturación electrónica | S06/sin |
- Verificar que BOS tiene contratos abiertos para estas fichas:
  ```bash
  grep "C-BAUTH-D13\|besu-wallet\|adsib-connector" BOS-BAUTH-CONTRATOS.md
  ```

**F8.A2 — Nuevo módulo `src/domain/blockchain_d13.rs`**
- Crear archivo: `/opt/skull/.../BauthAgent/src/domain/blockchain_d13.rs`
- Estructura del módulo (≤ 200 líneas — DOC-SBOS-001 N3):
  ```rust
  //! Dominio D13 — Blockchain identidad descentralizada y firma digital
  //! Cubre: wallets EIP-55, DID W3C, firma ADSIB/SIN Bolivia
  //! Normas: EIP-55, EIP-155, EIP-712, W3C DID Core 1.0, Ley 164 Bolivia
  pub mod wallet;      // wallet_view, tx_sign, typed_data_sign, contract_execute, multi_sig
  pub mod did;         // did_manage, vc_issue
  pub mod legal_sign;  // legal_sign_doc, invoice_sign
  ```
- Verificación: `cargo check` sin errores en el módulo nuevo

**F8.A3 — Seed D13: 36 átomos en `privilege_atom` (posiciones 5929–5964)**
- Archivo nuevo: `seeds/seed_d13_atoms.sql`
- Cada átomo con:
  ```sql
  INSERT INTO bauth.privilege_atom
    (atom_id, atom_code, domain_code, app_code, module_code, verb_code, bitmask_position,
     display_name, description, standard_ref, active, created_at)
  VALUES
    -- D13.001: D13.chain.wallet_view.C
    (gen_random_uuid(), 'D13.chain.wallet_view.C', 13, 14, 'wallet_view', 'C', 5929,
     'Crear wallet Ethereum', 'Registrar dirección wallet secp256k1 con checksum EIP-55',
     'EIP-55,EIP-712', true, now()),
    ...
  ```
- Total: 36 INSERTs (D13.001–D13.036 = posiciones 5929–5964)
- Verificación SQL:
  ```sql
  SELECT COUNT(*) FROM bauth.privilege_atom WHERE domain_code = 13;
  ```
  → `36`
- Bloqueado por: aprobación DDL FASE 3

### GRUPO F8.B — Aplicación `chain`: wallets y transacciones Ethereum

**F8.B1 — Módulo `src/domain/blockchain_d13/wallet.rs` — Wallet View (D13.001–D13.004)**
- Implementar CRUD para wallets EIP-55
- Archivo: `src/domain/blockchain_d13/wallet.rs` (≤ 200 líneas)
- Función `create_wallet(tenant_id: TenantId, ctx_id: CtxId) -> Result<WalletRecord, BauthError>`:
  - Generar keypair secp256k1 via Vault Transit (no hardcoded, no en disco)
  - Computar dirección con checksum EIP-55: `keccak256(pub_key)[12:]` con upper/lower case
  - Almacenar en `bauth.blk_account` (tabla D12 existente): `address`, `vault_key_id`, `tenant_id`, `ctx_id`
- EIP-55 test vector: `0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAd` (mixedcase checksum correcto)
- Test: `cargo test domain::blockchain_d13::wallet::test_eip55_checksum`
- Verificación SQL: `SELECT address FROM bauth.blk_account WHERE LENGTH(address) = 42 LIMIT 5` → todos 42 chars con `0x` prefix
- **Norma:** EIP-55 (Checksum Address Encoding, 2016)

**F8.B2 — Módulo `tx_sign.rs` — Firmar transacciones (D13.005–D13.008)**
- Implementar firma de transacciones EIP-1559 (type 2)
- Archivo: `src/domain/blockchain_d13/tx_sign.rs` (≤ 200 líneas)
- Struct `Eip1559Tx { chain_id: u64, nonce: u64, max_priority_fee: u128, max_fee: u128, gas_limit: u64, to: H160, value: U256, data: Bytes }`
- Firmar con clave del Vault (Vault Transit `sign` endpoint) — NO con clave local
- Producir: `rlp_encode([chain_id, nonce, max_priority_fee, max_fee, gas_limit, to, value, data, access_list, v, r, s])`
- Test con chain_id=42161 (Arbitrum One) y chain_id=1337 (Besu local):
  `cargo test domain::blockchain_d13::tx_sign::test_eip1559_rlp_encoding`
- Verificación en VPS: enviar tx al pod Besu:
  ```bash
  curl -s http://besu-rpc:8545 -X POST -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"eth_sendRawTransaction","params":["0x<tx_hex>"],"id":1}'
  ```
  → `{"result":"0x<tx_hash>"}` (sin error)
- **Normas:** EIP-155 (Replay Attack Protection), EIP-1559 (Fee Market)

**F8.B3 — Módulo `typed_data_sign.rs` — Firma EIP-712 (D13.009–D13.012)**
- Implementar `sign_typed_data(domain: Eip712Domain, types: TypeMap, primary: String, message: JsonValue, key_id: VaultKeyId) -> Result<Eip712Signature, BauthError>`
- El hash final: `keccak256(0x19 || 0x01 || domainSeparator || hashStruct(message))`
- Prefijo `0x1901` es obligatorio por EIP-712 §3
- Usar para firmar: auditoría de eventos críticos, liquidaciones D3, certificados internos
- Test con domainSeparator y mensaje conocido (vector del repositorio EIP-712 oficial):
  `cargo test domain::blockchain_d13::typed_data_sign::test_eip712_hash_vector`
- Verificación: el resultado debe coincidir con el vector del EIP-712 test suite oficial
- **Norma:** EIP-712 (Typed structured data hashing and signing)

**F8.B4 — Módulo `contract_execute.rs` — Llamadas a smart contracts (D13.013–D13.016)**
- Implementar `call_contract(contract: H160, abi: ContractAbi, fn_name: &str, args: Vec<Token>) -> Result<Bytes, BauthError>`
- Usar codificación ABI Ethereum: `keccak256(fn_signature)[0:4] || encode(args)`
- Solo para: `AuditAnchor.sol` (Forma A) y `SettlementEngine.sol` (Forma B)
- Dos modos: `call` (lectura, sin gas) y `send_transaction` (escritura, con gas estimado)
- Test: `cargo test domain::blockchain_d13::contract_execute::test_abi_encoding_anchor`
- Verificación en VPS: llamar `AuditAnchor.getRoot()` en pod Besu → retorna bytes32
- **Norma:** Ethereum ABI Specification (Solidity docs §ABIencode), EIP-155

**F8.B5 — Módulo `multi_sig.rs` — Multi-firma (D13.017–D13.020)**
- Implementar participación en transacciones multi-sig (patrón Gnosis Safe)
- Struct `MultiSigProposal { safe_address: H160, tx_hash: Bytes32, signatures: Vec<Eip712Signature>, threshold: u8, approvals: u8 }`
- Verificar que el actor tiene átomo `D13.chain.multi_sig_participate.C` antes de agregar firma
- Almacenar propuestas en `bauth.blk_settlement` (tabla existente D12)
- Ejecutar cuando `approvals >= threshold`
- Test: `cargo test domain::blockchain_d13::multi_sig::test_threshold_enforcement`
- Verificación SQL: `SELECT safe_address, threshold, approvals FROM bauth.blk_settlement WHERE type = 'MULTI_SIG' LIMIT 5` → `approvals <= threshold` en todo momento

### GRUPO F8.C — Aplicación `did`: Identidad Descentralizada W3C

**F8.C1 — Módulo `src/domain/blockchain_d13/did.rs` — DID Manage (D13.021–D13.024)**
- Implementar gestión de DID Documents W3C DID Core 1.0
- DID method para SBOS: `did:sbos:<tenant_id>:<uuid>` (custom DID method)
- También soportar: `did:ethr:<address>` (usando la dirección wallet D13.B1)
- Struct `DidDocument { id: String, controller: Vec<String>, verification_method: Vec<VerificationMethod>, authentication: Vec<String>, assertion_method: Vec<String>, service: Vec<Service> }`
- Almacenar en nueva tabla `bauth.did_document` (DDL pendiente aprobación)
- CREATE (D13.021): generar DID + publicar DID Document en Besu (tx tipo EIP-1559)
- READ (D13.022): resolver DID Document (primero cache Redis TTL 300s, luego Besu)
- UPDATE (D13.023): rotation de clave verificación → nueva `verificationMethod` + `updated` timestamp
- DELETE (D13.024): marcar DID como `deactivated: true` en DID Document (no se borra — es inmutable)
- Test: `cargo test domain::blockchain_d13::did::test_did_document_roundtrip`
- Verificación: publicar DID en Besu local y resolver con `bauth.d13.did.resolve`:
  ```bash
  curl -s -X POST /run/bos/bauth.sock '{"method":"bauth.d13.did.resolve","params":{"did":"did:sbos:acme:uuid"}}'
  ```
  → DID Document JSON válido según W3C DID Core 1.0
- **Normas:** W3C DID Core 1.0 (2022), W3C DID Resolution (2023)

**F8.C2 — Módulo `vc_issue.rs` — Verifiable Credentials W3C (D13.025–D13.028)**
- Implementar emisión de Verifiable Credentials (VCs) firmadas con Ed25519 (Vault)
- Struct `VerifiableCredential { @context: Vec<String>, id: String, type: Vec<String>, issuer: String, issuance_date: DateTime<Utc>, expiration_date: Option<DateTime<Utc>>, credential_subject: JsonValue, proof: LinkedDataProof }`
- Proof: `DataIntegrityProof` con `cryptosuite: eddsa-2022` (W3C VC Data Integrity 2022)
- Casos de uso en SBOS:
  - VC de identidad empleado: `CredentialType = EmployeeCredential`
  - VC de habilitación SIN: `CredentialType = FiscalCredential` (para facturación)
  - VC de acceso físico: `CredentialType = PhysicalAccessCredential`
- Verificar (D13.026): resolver DID del issuer → obtener verificationMethod → verificar firma
- Revocar (D13.028): publicar StatusList2021 en `bauth.did_revocation_list` (BitString)
- Test: `cargo test domain::blockchain_d13::vc_issue::test_vc_roundtrip_ed25519`
- Verificación SQL: `SELECT credential_type, status FROM bauth.did_credential WHERE issued_at > now()-interval '1h' LIMIT 5` → `status = 'ACTIVE'`
- **Normas:** W3C Verifiable Credentials 2.0 (2024), W3C VC Data Integrity (EdDSA-2022), StatusList2021

### GRUPO F8.D — Aplicación `legalsg`: Firma Digital con Validez Legal Bolivia

**F8.D1 — Módulo `src/domain/blockchain_d13/legal_sign.rs` — Firma ADSIB (D13.029–D13.032)**
- Implementar firma digital con certificado ADSIB Bolivia (RSA-SHA256)
- El certificado ADSIB vive en Vault PKI (NO en disco) — acceso vía Vault API
- Proceso de firma (Ley 164 + ADSIB-FD-POLT-015 v2.3):
  1. Obtener documento a firmar (hash SHA-256 del PDF/XML)
  2. Obtener clave privada RSA del Vault Transit
  3. Firmar con PKCS#1 v1.5 (RSA-SHA256) — NO OAEP, el SIN requiere v1.5
  4. Construir CMS SignedData (RFC 5652 §5.1) con el certificado ADSIB incluso
  5. Producir firma en formato PAdES (PDF) o XAdES (XML) según tipo de documento
  6. Registrar en `bauth.blk_anchor_log` con `document_hash` + `signature_ref` + `ctx_id`
- Struct `LegalSignature { document_hash: [u8;32], cms_signed_data: Vec<u8>, certificate_serial: String, signed_at: DateTime<Utc>, valid_until: DateTime<Utc>, adsib_timestamp: Option<Vec<u8>>, ctx_id: String }`
- Test de redondeo: `cargo test domain::blockchain_d13::legal_sign::test_rsa_sha256_sign_verify`
- Verificación: validar firma producida con OpenSSL:
  ```bash
  openssl smime -verify -inform DER -in signature.p7s -content document.pdf -CAfile adsib_root.pem
  ```
  → `Verification successful`
- **Normas:** Ley 164 Bolivia (2011) Arts. 1-15, ADSIB-FD-POLT-015 v2.3, RFC 5652 (CMS), ETSI EN 319 102-1 (AdES baseline)

**F8.D2 — Módulo `invoice_sign.rs` — Firma Facturas SIN Bolivia (D13.033–D13.036)**
- Implementar firma de facturas electrónicas según SIN RND 10-0025-15
- El XML de factura SIN sigue formato CUFD/CUIS definido por SIN Bolivia
- Firma: XAdES-EPES (XML Advanced Electronic Signatures) con certificado ADSIB
- Proceso:
  1. Construir XML de factura según schema XSD del SIN
  2. Canonicalizar con C14N (W3C Canonical XML 1.1)
  3. Calcular digest SHA-256 del XML canonicalizado
  4. Firmar con RSA-SHA256 + certificado ADSIB
  5. Construir elemento `<ds:Signature>` y embeber en el XML
  6. Enviar al web service del SIN Bolivia (SOAP/HTTP — canal externo)
- Struct `InvoiceSignResult { invoice_id: Uuid, cufd: String, xml_signed: String, cuf: String, sin_response_code: u32, sin_timestamp: DateTime<Utc>, ctx_id: String }`
- Test: `cargo test domain::blockchain_d13::invoice_sign::test_xades_epes_structure`
- Verificación: validar que el XML firmado cumple el schema XSD del SIN:
  ```bash
  xmllint --schema sin-factura-v3.xsd factura-firmada.xml --noout
  ```
  → `validates`
- **Normas:** SIN Bolivia RND 10-0025-15, RND 102100000011, W3C C14N 1.1, ETSI EN 319 132-1 (XAdES)

### GRUPO F8.E — Handlers JSON-RPC para D13

**F8.E1 — Agregar 9 handlers D13 en `server/handlers/mod.rs`**
- Handlers nuevos (namespace `bauth.d13.*`):
  ```
  bauth.d13.wallet.create   → F8.B1 domain::wallet::create_wallet
  bauth.d13.wallet.get      → F8.B1 domain::wallet::read_wallet
  bauth.d13.tx.sign         → F8.B2 domain::tx_sign::sign_eip1559
  bauth.d13.data.sign       → F8.B3 domain::typed_data_sign::sign_typed_data
  bauth.d13.did.create      → F8.C1 domain::did::create_did_document
  bauth.d13.did.resolve     → F8.C1 domain::did::resolve_did
  bauth.d13.vc.issue        → F8.C2 domain::vc_issue::issue_vc
  bauth.d13.legal.sign      → F8.D1 domain::legal_sign::sign_with_adsib
  bauth.d13.invoice.sign    → F8.D2 domain::invoice_sign::sign_invoice_sin
  ```
- Cada handler verifica que el actor tiene el átomo D13 correspondiente ANTES de ejecutar:
  ```rust
  privilege_engine.check_atom(&ctx, "D13.chain.wallet_view.C")?;
  ```
- Test de integración: `cargo test --test d13_integration_handlers -- --nocapture`
- Verificación en VPS (pod bAuth): todos los métodos responden con `{"result": ...}` o `{"error": ...}` JSON-RPC válido

---

## FASE 9 — Token Generation: Robustez del JWT Canónico

**Estado actual:** Keycloak emite JWT. bAuth configura claims vía Admin API. 94 handlers activos.
**Objetivo:** Verificar y garantizar que el token cumple 100% los estándares y es infalible.

### GRUPO F9.A — Estructura canónica del JWT

**F9.A1 — Verificar claims canónicos obligatorios en CADA JWT emitido**
- El JWT de bAuth DEBE contener EXACTAMENTE estos claims (sin omisiones):
  ```json
  {
    "iss": "https://auth.sbos.app/realms/<tenant_id>",
    "sub": "<user_uuid>",
    "aud": ["<app_slug>"],
    "exp": <unix_timestamp>,
    "iat": <unix_timestamp>,
    "jti": "<uuid_v7>",
    "ctx_id": "<ctx_id>",
    "tenant_id": "<tenant_id>",
    "empresa_id": "<empresa_id>",
    "sucursal_id": "<sucursal_id>",
    "pos_logico": "<pos_id>",
    "loa": 1|2|3,
    "acr": "sbos_aal1"|"sbos_aal2"|"sbos_aal3",
    "amr": ["pwd"]|["pwd","totp"]|["pwd","hwk"],
    "bitmask_d1": "<hex_64bit>",
    "bitmask_d2": "<hex_64bit>",
    "bitmask_d3": "<hex_64bit>",
    "zones": ["AREA-CAJA"],
    "scope": "BRANCH"|"COMPANY"|"GLOBAL",
    "token_seq": <incremental_int>,
    "prev_hash": "<sha256_hex>"
  }
  ```
- Verificar en VPS:
  ```bash
  curl -s -X POST /run/bos/bauth.sock '{"method":"bauth.oidc.token","params":{"grant_type":"password","username":"test","password":"test"}}' \
    | python3 -c "import sys,json,base64; t=json.load(sys.stdin)['result']['access_token'].split('.')[1]; print(json.dumps(json.loads(base64.urlsafe_b64decode(t+'==').decode()),indent=2))"
  ```
  → todos los claims listados presentes
- **Normas:** RFC 7519 (JWT), OIDC Core §2 (ID Token)

**F9.A2 — Verificar `jti` como UUIDv7 (monotónico, ordenable por tiempo)**
- El `jti` claim DEBE ser UUIDv7 (RFC 9562, abril 2024) para ordenación temporal sin base de datos
- UUIDv7 = 48 bits timestamp ms + 12 bits secuencia + 62 bits random
- Verificar en código: función que genera el `jti` usa `Uuid::now_v7()` (crate `uuid` v1.7+)
- Grep en código: `grep -n "jti\|Uuid::new_v4\|Uuid::now_v7" src/server/handlers/`
- Si existe `Uuid::new_v4()` para `jti` → cambiar a `Uuid::now_v7()` (UUIDv7 monotónico)
- Test: `cargo test token::generation::test_jti_is_uuidv7 -- --nocapture`
- Verificación: 1000 JTIs consecutivos deben ser ordenables lexicográficamente
- **Norma:** RFC 9562 §5.7 (UUID Version 7, Time-Ordered UUIDs)

**F9.A3 — Verificar BitMask en token: todos los dominios D1-D12 presentes**
- El token debe llevar el BitMask compacto (no todos los átomos — solo el resumen por dominio)
- Formato: `"bitmask_d<N>": "0x<hex_64bit>"` para cada dominio activo
- Verificar que el BitMask en el token coincide con `rol_bitmask_base64` en `idn_user_template`
- Test de consistencia:
  ```sql
  WITH token_bitmask AS (
    SELECT (template->'roles_assignments'->>'effective_bitmask')::text AS bitmask
    FROM bauth.idn_user_template WHERE username = 'test_user'
  )
  SELECT bitmask FROM token_bitmask;
  ```
  → valor idéntico al `bitmask_d1` del JWT decodificado
- **Norma:** ANSI/INCITS 359-2004 §3.1 (RBAC enforcement), SBOS-021 §BitMask

**F9.A4 — Verificar `amr` (Authentication Methods References) correcto por método**
- RFC 8176 define los valores estándar de `amr`:
  | Método bAuth | amr value | RFC |
  |---|---|---|
  | Password | `["pwd"]` | RFC 8176 §2 |
  | Password + TOTP | `["pwd","otp"]` | RFC 8176 §2 |
  | WebAuthn (platform) | `["face","fpt"]` or `["hwk"]` | RFC 8176 §2 |
  | WebAuthn (security key) | `["hwk"]` | RFC 8176 §2 |
  | mTLS/X.509 | `["mca"]` (multiple-channel auth) | RFC 8176 §2 |
  | Passkey | `["pop"]` (proof-of-possession) + `["hwk"]` | RFC 8176 §2 |
- Grep en código: `grep -n "amr" src/server/handlers/` → verificar que se asigna correctamente
- Test: `cargo test token::claims::test_amr_per_auth_method -- --nocapture`
- **Norma:** RFC 8176 (Authentication Method Reference Values)

### GRUPO F9.B — Firma y criptografía del token

**F9.B1 — Verificar firma EdDSA Ed25519 (Vault Transit) — Motor de firma interno**
- bAuth firma tokens con EdDSA Ed25519 vía Vault Transit (nunca clave en disco)
- Algoritmo en header JWT: `{"alg":"EdDSA","crv":"Ed25519","kid":"<vault_key_id>"}`
- JWKS endpoint expone la clave pública para verificación:
  ```bash
  curl -s -X POST /run/bos/bauth.sock '{"method":"bauth.oidc.discovery","params":{}}' \
    | grep jwks_uri
  ```
  → URI del JWKS endpoint
- Test de verificación cruzada: tomar un JWT → extraer `kid` → obtener clave pública del JWKS → verificar firma
  ```bash
  python3 -c "
  import jwt, requests
  token = '<jwt_aqui>'
  kid = jwt.get_unverified_header(token)['kid']
  # obtener JWKS y verificar
  jwks = requests.get('http://bauth/jwks').json()
  key = next(k for k in jwks['keys'] if k['kid'] == kid)
  payload = jwt.decode(token, jwt.algorithms.OKPAlgorithm.from_jwk(key), algorithms=['EdDSA'])
  print(payload)
  "
  ```
  → decodifica correctamente sin excepciones
- **Normas:** RFC 8037 (COSE/JWK Key Representation for OKP, Ed25519/X25519), RFC 8032 (EdDSA), NIST FIPS 186-5

**F9.B2 — Verificar PKCE RFC 7636 en flujo authorization_code**
- Flujo: `code_verifier` (43-128 random chars) → `code_challenge = BASE64URL(SHA256(code_verifier))`
- Verificar que el handler `bauth.oidc.token` con `grant_type=authorization_code`:
  1. Rechaza petición sin `code_verifier` si el client fue registrado con PKCE
  2. Verifica que `code_challenge = BASE64URL(SHA256(code_verifier))`
  3. Retorna error `invalid_grant` si el challenge no coincide
- Test: `cargo test oidc::pkce::test_code_challenge_s256 -- --nocapture`
- Verificación en VPS: intentar obtener token con `code_verifier` incorrecto → `{"error":"invalid_grant"}`
- **Norma:** RFC 7636 (PKCE for OAuth Public Clients)

**F9.B3 — Verificar DPoP (RFC 9449) binding del token al cliente**
- DPoP (Demonstrating Proof of Possession) ata el token a la clave pública del cliente
- Header `DPoP` contiene un JWT firmado con clave del cliente (EC/RSA)
- bAuth verifica: `jti` único (anti-replay), `htm` (HTTP method), `htu` (URL), `iat` < 5min
- El token de acceso incluye el claim `cnf: {"jkt": "<SHA256_JWK_thumbprint>"}` (RFC 7638)
- Test: `cargo test oidc::dpop::test_dpop_proof_validation -- --nocapture`
- Verificación: token con DPoP válido → acepta. Token sin DPoP (si DPoP obligatorio) → `{"error":"invalid_dpop_proof"}`
- **Norma:** RFC 9449 (OAuth 2.0 Demonstrating Proof of Possession)

**F9.B4 — Verificar cadena Merkle en el token (token_seq + prev_hash)**
- Cada JWT emitido se encadena al anterior criptográficamente:
  - `token_seq_n = token_seq_{n-1} + 1`
  - `prev_hash_n = sha256(jti_{n-1} || exp_{n-1} || bitmask_{n-1})`
- Esto hace imposible falsificar un token sin romper la cadena
- Verificar en código: función que genera claims incluye `token_seq` y `prev_hash`
- Verificar consistencia en BD:
  ```sql
  SELECT jti, token_seq, prev_hash
  FROM bauth.aud_token_log
  WHERE user_uuid = (SELECT uuid FROM bauth.idn_user_template WHERE username='test_user')
  ORDER BY token_seq DESC LIMIT 5;
  ```
  → `token_seq` incrementa de 1 en 1, `prev_hash` no nulo salvo el primero (seq=0)
- **Norma:** NIST IR 8202 §4 (cryptographic chaining), ISO 27001 A.8.15

**F9.B5 — Verificar revocación de token en < 30 segundos**
- Al revocar acceso (offboarding, cambio de rol, lockout): el token existente debe invalidarse
- Mecanismo: bAuth publica en Redis Stream `bauth:token_revoked` el `jti` a invalidar
- Kong consume el stream y actualiza su caché de tokens revocados (TTL máx = TTL del token)
- Besu recibe evento y lo ancla en `blk_anchor_log` con `event_type = TOKEN_REVOKED`
- Test de tiempo: ejecutar revocación → medir tiempo hasta que `/userinfo` retorna 401:
  ```bash
  time (curl -s -H "Authorization: Bearer <token>" http://bauth/oidc/userinfo | grep -c '"error"')
  ```
  → resultado `1` en < 30 segundos
- **Norma:** SBOS-021 §Revocación < 30s, CAEP 1.0 (OpenID SSF session-revoked event)

---

## FASE 10 — Métodos de Autenticación: Certificación Formal del Catálogo Completo

**Estado actual:** 9 validadores nativos · 50 tests unitarios · 15 métodos en `ath_method`
**Objetivo:** Certificar formalmente con vectores RFC oficiales + agregar métodos faltantes 2026

El catálogo bAuth tiene 7 tablas declarativas (110+ registros en BD). Los "métodos de
autenticación" que el usuario denomina incluyen métodos base + sus políticas + configuraciones
por tier = catálogo total del framework de autenticación.

### GRUPO F10.A — Certificación formal de validadores nativos Rust

**F10.A1 — Certificar Password/Argon2id con vectores NIST SP 800-63B-4**
- Archivo: `src/domain/password_policy.rs`
- Verificar que usa exactamente: `Argon2id` (NO Argon2i, NO Argon2d para auth)
- Parámetros obligatorios NIST SP 800-63B-4 §3.1.1.3:
  - `memory_cost >= 19456` KiB (19 MiB — OWASP ASVS 5.0 §2.4.5)
  - `time_cost >= 2` (iteraciones)
  - `parallelism = 1`
  - `output_length = 32` bytes (256 bits)
- Test con vector oficial RFC 9106 §5.3 (Argon2id test vector):
  ```
  Password: "password", Salt: "somesalt", Iterations: 1, Memory: 65536, Parallelism: 4
  Expected output: 09316115d5cf24ed0a58d5baef8d5f25a4e0b8bdcfe55d6eb1f19db6a78b5cf...
  ```
- Test: `cargo test domain::password_policy::test_argon2id_rfc9106_vector -- --nocapture`
- Verificación de cribado HIBP:
  ```bash
  echo -n "Password1" | sha1sum | head -c 5 | tr '[:lower:]' '[:upper:]' | \
    xargs -I{} curl -s https://api.pwnedpasswords.com/range/{} | grep -c "."
  ```
  → si > 0, la contraseña está comprometida — bAuth debe rechazarla
- **Normas:** RFC 9106 (Argon2), NIST SP 800-63B-4 §3.1.1, OWASP ASVS 5.0 §2.4.5

**F10.A2 — Certificar TOTP con 18 vectores RFC 6238 Appendix B**
- Archivo: `src/domain/auth_methods/totp.rs`
- Los 18 vectores del RFC 6238 Appendix B cubren: SHA1, SHA256, SHA512 × 6 timestamps
- Verificar que todos los 18 vectores pasan:
  ```bash
  cargo test domain::auth_methods::totp::test_rfc6238_appendix_b -- --nocapture
  ```
  → `test_rfc6238_appendix_b: ok` (18/18 vectores)
- Verificar tolerancia de drift temporal: ±1 ventana (±30s) para desfase de reloj
- Verificar que SHA-256 es el algoritmo por defecto (no SHA-1 — obsoleto)
- Grep: `grep -n "SHA1\|Algorithm::Sha1" src/domain/auth_methods/totp.rs` → sin resultados para el default
- **Norma:** RFC 6238 (TOTP: Time-Based One-Time Password Algorithm)

**F10.A3 — Certificar HOTP con 10 vectores RFC 4226 Appendix D**
- Archivo: `src/domain/auth_methods/hotp.rs`
- Los 10 vectores del RFC 4226 Appendix D: secret=`0x3132...6162`, counter=0 a 9
- Test: `cargo test domain::auth_methods::hotp::test_rfc4226_appendix_d -- --nocapture`
- Verificar anti-replay: cada código HOTP solo puede usarse una vez (counter monotónico)
- Verificar look-ahead window: máx 3 (buscar en counter+0, counter+1, counter+2)
- Verificación SQL: `SELECT counter FROM bauth.bauth_mfa_enrollments WHERE method_id = 'hotp' LIMIT 5` → counter solo incrementa, nunca retrocede
- **Norma:** RFC 4226 (HOTP: An HMAC-Based One-Time Password Algorithm)

**F10.A4 — Certificar WebAuthn/FIDO2 con RP ID binding y User Presence**
- Archivo: `src/domain/auth_methods/webauthn.rs`
- Verificaciones obligatorias según W3C WebAuthn §7.2:
  1. `rpId` del assertion == `rpId` registrado (anti-phishing crítico)
  2. `origin` en `clientDataJSON` coincide con el origin del servidor
  3. `userPresent` flag = 1 (UP bit en `flags`)
  4. Si AAL3: `userVerified` flag = 1 (UV bit en `flags`)
  5. `signCount` mayor al registrado en BD (anti-replay de dispositivo)
  6. Firma ECDSA P-256 o Ed25519 válida sobre `authData || clientDataHash`
- Test con credencial real desde Authenticator (no mock):
  ```bash
  cargo test --test webauthn_integration -- --nocapture
  ```
- Grep anti-phishing: `grep -n "rpId\|rp_id\|origin" src/domain/auth_methods/webauthn.rs` → comprobación presente
- Verificación: intentar autenticar con RP ID incorrecto → `{"error":"invalid_rp_id"}`
- **Normas:** W3C WebAuthn Level 2 (2021) §7.2, FIDO Alliance CTAP2.1 (2022), NIST SP 800-63B-4 §5.1.8

**F10.A5 — Certificar mTLS/X.509 con cadena de certificados real**
- Archivo: `src/domain/auth_methods/mtls.rs`
- Verificaciones obligatorias RFC 8705:
  1. Certificado cliente firmado por CA interna (Vault PKI)
  2. `certificate_thumbprint` en token == `SHA256(cert_DER)` (RFC 8705 §3)
  3. Verificar CRL o OCSP para revocación (Vault CRL endpoint)
  4. Verificar `NotBefore` y `NotAfter` del certificado
  5. El claim `cnf.x5t#S256` en el token contiene el thumbprint
- Test con certificado de prueba generado por Vault:
  ```bash
  vault write pki/issue/sbos-internal common_name=test.sbos.internal ttl=1h \
    | tee /tmp/test_cert.json
  cargo test --test mtls_integration -- --nocapture
  ```
- Verificación: token con mTLS válido → `cnf.x5t#S256` presente en JWT
- **Normas:** RFC 8705 (OAuth 2.0 Mutual-TLS Client Authentication), RFC 5280 (X.509 PKI)

**F10.A6 — Verificar policies phishing-resistant para AAL3 (NIST SP 800-63B-4 MANDATORIO)**
- NIST SP 800-63B-4 (Final, Julio 2025) hace OBLIGATORIO que AAL3 use SOLO métodos
  phishing-resistant: WebAuthn (hardware security key), passkey device-bound, mTLS
- Verificar que la tabla `ath_policy` tiene constraint para tiers SU/SYS:
  ```sql
  SELECT policy_code, allowed_methods, phishing_resistant_required
  FROM bauth.ath_policy
  WHERE tier IN ('SU','SYS','BIZ_N1') AND aal_required = 3;
  ```
  → `phishing_resistant_required = true` para todos los tiers AAL3
- Verificar que bAuth RECHAZA autenticación con TOTP/Password en contextos AAL3:
  ```bash
  # Intentar auth con TOTP para usuario tier SU
  curl -s -X POST /run/bos/bauth.sock '{"method":"bauth.auth.login","params":{"username":"su_admin","method":"totp","otp":"123456","target_loa":3}}'
  ```
  → `{"error":"insufficient_method","detail":"AAL3 requires phishing-resistant authenticator"}`
- **Norma:** NIST SP 800-63B-4 §4.3 (AAL3 requirements, julio 2025 Final)

### GRUPO F10.B — Métodos faltantes del estado del arte 2026

**F10.B1 — Registrar SMS OTP como método `restricted` (solo registro, no implementar)**
- NIST SP 800-63B-4 deprecó SMS OTP. Debe estar en el catálogo como `restricted`
  para poder aplicar política de PROHIBICIÓN en tiers altos y PERMITIRLO solo en EXT_N0
- INSERT en `bauth.ath_method` (no es DDL — es seed modificación):
  ```sql
  INSERT INTO bauth.ath_method
    (method_id, method_name, method_type, aal_level, nist_status, active, risk_level)
  VALUES
    ('sms_otp', 'SMS OTP', 'out_of_band', 1, 'restricted', true, 'HIGH')
  ON CONFLICT (method_id) DO NOTHING;
  ```
- Política que lo restringe a EXT_N0:
  ```sql
  INSERT INTO bauth.ath_policy
    (policy_code, tier, aal_required, allowed_methods, phishing_resistant_required, sms_allowed)
  VALUES
    ('EXT_N0_OTP', 'EXT_N0', 1, ARRAY['password','sms_otp','email_otp'], false, true)
  ON CONFLICT (policy_code) DO NOTHING;
  ```
- **Norma:** NIST SP 800-63B-4 §5.1.3.3 (OOB restricted authenticators)

**F10.B2 — Registrar Synced Passkey como método independiente**
- W3C WebAuthn L2 + FIDO2 CTAP2.1 distinguen Synced Passkey (menor seguridad) de
  Platform Authenticator + Hardware Security Key (mayor seguridad)
- INSERT en `bauth.ath_method`:
  ```sql
  INSERT INTO bauth.ath_method
    (method_id, method_name, method_type, aal_level, nist_status, active)
  VALUES
    ('passkey_synced', 'Synced Passkey (Cloud)', 'fido2_synced', 2, 'permitted', true)
  ON CONFLICT (method_id) DO NOTHING;
  ```
- Política: Synced Passkey → AAL2 pero NO phishing-resistant para AAL3
- **Norma:** W3C WebAuthn §4 (definitions: resident credential, synced), FIDO2 CTAP2.1 §4

**F10.B3 — Registrar Risk-Based/Adaptive Authentication como método de orquestación**
- Adaptive Auth no es un método de factor — es una capa de orquestación que evalúa
  riesgo y decide si pedir step-up. Debe estar en el catálogo para poder referenciarlo en políticas
- INSERT en `bauth.ath_method`:
  ```sql
  INSERT INTO bauth.ath_method
    (method_id, method_name, method_type, aal_level, nist_status, active, risk_engine)
  VALUES
    ('adaptive_auth', 'Risk-Based Adaptive Authentication', 'orchestration', 0, 'permitted', true, true)
  ON CONFLICT (method_id) DO NOTHING;
  ```
- El motor de riesgo evalúa: IP score, device fingerprint, behavioral biometrics, time-of-day
- Si score > threshold → Step-Up RFC 9470 (`insufficient_user_authentication`)
- **Norma:** NIST SP 800-63B-4 §5.1.4 (Risk-based decisions), OWASP ASVS 5.0 §2.2.6

**F10.B4 — Actualizar nomenclatura PQC (Post-Quantum Cryptography)**
- NIST finalizó en agosto 2024 los estándares PQC:
  - FIPS 203: ML-KEM (antes CRYSTALS-Kyber) — encapsulamiento de clave
  - FIPS 204: ML-DSA (antes CRYSTALS-Dilithium) — firma digital
  - FIPS 205: SLH-DSA (antes SPHINCS+) — firma digital alternativa
- En `bauth.crypto_algorithm` y en el campo `digital_signature.post_quantum_planned`
  del UserTemplate, cambiar "CRYSTALS-Dilithium" → "ML-DSA (FIPS 204)"
- Grep en BD:
  ```sql
  UPDATE bauth.crypto_algorithm
  SET algorithm_name = 'ML-KEM (FIPS 203)', standard_ref = 'NIST FIPS 203'
  WHERE algorithm_name = 'CRYSTALS-Kyber';

  UPDATE bauth.crypto_algorithm
  SET algorithm_name = 'ML-DSA (FIPS 204)', standard_ref = 'NIST FIPS 204'
  WHERE algorithm_name = 'CRYSTALS-Dilithium';
  ```
- **Normas:** NIST FIPS 203 (ML-KEM, agosto 2024), FIPS 204 (ML-DSA), FIPS 205 (SLH-DSA)

**F10.B5 — Verificar OAuth 2.1 draft (draft-ietf-oauth-v2-1-15, marzo 2026)**
- OAuth 2.1 consolida OAuth 2.0 + PKCE + BCP Security + DPoP como obligatorios
- Los cambios críticos vs OAuth 2.0:
  - PKCE OBLIGATORIO para todos los clientes (ya implementado F9.B2)
  - Implicit flow ELIMINADO (ya eliminado)
  - Resource Owner Password Credentials ELIMINADO
  - Redirect URI DEBE ser exacto (sin wildcards)
- Verificar que bAuth no soporta implicit flow ni ROPC:
  ```bash
  curl -s -X POST /run/bos/bauth.sock '{"method":"bauth.oidc.token","params":{"grant_type":"implicit",...}}' \
    | grep error
  ```
  → `{"error":"unsupported_grant_type"}`
- **Norma:** draft-ietf-oauth-v2-1-15 (OAuth 2.1, marzo 2026)

**F10.B6 — Certificar OWASP ASVS 5.0 V6 — 8 categorías de autenticación**
- OWASP ASVS 5.0 (lanzado mayo 2025) V6 cubre 8 categorías de autenticación:
  | Cat | Descripción | Verificación |
  |-----|-------------|-------------|
  | V6.1 | Knowledge-based auth | Test brute force protection (rate limit 5 intentos) |
  | V6.2 | Lookup secret verifiers | Test recovery codes de un solo uso |
  | V6.3 | OTP verifiers | Test TOTP anti-replay, ventana de 1 período |
  | V6.4 | Cryptographic (FIDO2) | Test RP ID binding (F10.A4) |
  | V6.5 | Single-factor OOB | Test SMS/email OTP TTL < 10min |
  | V6.6 | Multi-factor | Test que AAL2 requiere 2 factores distintos |
  | V6.7 | Cryptographic keys | Test Vault key rotation funcional |
  | V6.8 | Service credentials | Test M2M con Client Credentials + mTLS |
- Ejecutar suite de verificación: `cargo test --test asvs_v5_v6 -- --nocapture`
- **Norma:** OWASP ASVS 5.0.0 §V6 (Authentication Verification Requirements)

---

## FASE 11 — ctx_id y Context Plane: Integración Robusta con BOS

**Estado actual:** ctx_id implementado con 18 tests pasando. W3C Trace Context operativo.
**Objetivo:** Verificar robustez total — 6 capas, propagación, BOS contrato, CAEP, invalidación.

### GRUPO F11.A — Estructura y ciclo de vida del ctx_id

**F11.A1 — Verificar dctx_id pre-autenticación (TTL 30min, bAuth lo crea)**
- `dctx_id` = "dispositivo-ctx": identifica la sesión de dispositivo ANTES de que el usuario
  se autentique. TTL 30 minutos, renovable mientras el usuario interactúa con la UI.
- Estructura del dctx_id:
  ```json
  {
    "dctx_id": "<uuid_v7>",
    "tenant_id": "<tenant>",
    "pos_logico": "<pos>",
    "device_fingerprint": "<hash_128bit>",
    "created_at": "<iso8601>",
    "expires_at": "<iso8601>",
    "traceparent": "00-<trace_id>-<span_id>-01",
    "status": "PRE_AUTH"
  }
  ```
- Verificar que al recibir `bauth.auth.init_session`, bAuth crea dctx_id y lo almacena en Redis con TTL 30min:
  ```bash
  redis-cli GET "dctx:<uuid>" | python3 -m json.tool | grep expires_at
  ```
  → `expires_at` = ahora + 30min
- Test: `cargo test context_plane::test_dctx_creation_and_ttl -- --nocapture`
- **Norma:** SBOS-049 §dctx_id, W3C Trace Context Level 2 §3

**F11.A2 — Verificar ctx_id post-autenticación: 6 capas obligatorias**
- Al completarse la autenticación, el dctx_id se eleva a ctx_id con las 6 capas:
  ```
  ctx_id = "<tenant_id>:<empresa_id>:<sucursal_id>:<pos_logico>:<user_uuid>:<traceparent>"
  ```
- Verificar que NINGUNA capa puede ser `null` o vacía en el ctx_id final:
  ```bash
  curl -s -X POST /run/bos/bauth.sock '{"method":"bauth.context.get","params":{"ctx_id":"<ctx_id>"}}' \
    | python3 -m json.tool
  ```
  → los 6 campos presentes y no nulos
- Verificar que el ctx_id está en Redis como sesión activa:
  ```bash
  redis-cli GET "ctx:<ctx_id>" | python3 -m json.tool | grep status
  ```
  → `"status": "ACTIVE"`
- **Norma:** SBOS-049 §ctx_id 6 capas, NIST SP 800-207 §3.1 (ZTA identity-based access)

**F11.A3 — Verificar propagación W3C en Unix socket entre daemons**
- Todos los mensajes entre daemons (bAuth → biedata, bAuth → bKernel, etc.) sobre
  Unix socket DEBEN incluir los 3 headers W3C como campos del JSON-RPC:
  ```json
  {
    "jsonrpc": "2.0",
    "method": "biedata.fiscal.factura.obtener_datos",
    "params": {...},
    "ctx": {
      "traceparent": "00-<trace_id>-<span_id>-01",
      "tracestate": "sbos=<tenant_id>",
      "baggage": "ctx_id=<ctx_id>,user_id=<uuid>,tier=BIZ_N1"
    },
    "id": 1
  }
  ```
- Verificar en código: grep en handlers de salida:
  ```bash
  grep -rn "traceparent\|tracestate\|baggage" src/engine/
  ```
  → todos los clientes de otros daemons incluyen el objeto `ctx`
- **Norma:** W3C Trace Context Recommendation (2025), OpenTelemetry Baggage §4, SBOS-049 §Propagación

**F11.A4 — Verificar validación de ctx_id en Kong PEP (X-SBOS-Context header)**
- Kong recibe requests HTTP externos con header `X-SBOS-Context: <ctx_id>`
- Kong hace una validación rápida (in-memory cache TTL 30s) o llama a bAuth:
  ```bash
  bauth.context.validate(ctx_id) → {valid: true, user_uuid: "...", loa: 2}
  ```
- Test de ctx_id expirado: usar un ctx_id con TTL vencido en Kong → Kong retorna 401
- Test de ctx_id inexistente: → 401
- Test de ctx_id activo: → 200 + headers enriquecidos (`X-User-ID`, `X-Tenant-ID`, `X-LOA`)
- Verificar en Kong logs:
  ```bash
  kubectl logs deployment/kong -n sbos-platform | grep "ctx_id_validation" | tail -20
  ```
  → entradas de validación con `valid=true`/`valid=false`
- **Norma:** NIST SP 800-207 §3.3 (PEP enforcement), SBOS-049 §Kong PEP

### GRUPO F11.B — Contrato BOS ↔ bAuth y métodos JSON-RPC ctx_id

**F11.B1 — Verificar método `bos.ctx.create` del contrato BOS (ADR-019)**
- El contrato BOS define `bos.ctx.create` para que bAuth le pida a BOS crear un ctx_id
- Verificar que el contrato `C-BOS-CTX-001` está en `BOS-BAUTH-CONTRATOS.md` como `CERRADO`:
  ```bash
  grep "C-BOS-CTX-001\|bos.ctx.create" BOS-BAUTH-CONTRATOS.md
  ```
  → entrada con `✅ CERRADO`
- Verificar que bAuth implementa la llamada:
  ```bash
  grep -rn "bos.ctx.create\|bos_ctx_create" src/
  ```
  → función que llama al socket `/run/bos/bos.sock` con el método
- **Norma:** ADR-019 (BOS Interface Dual), ADR-020 (Interface Dual obligatoria), SBOS-049 §BOS

**F11.B2 — Verificar método `bos.ctx.validate` del contrato BOS**
- `bos.ctx.validate` permite a cualquier daemon verificar que un ctx_id está activo
- Verificar que bAuth expone `bauth.context.validate` y a su vez usa `bos.ctx.validate`:
  ```bash
  grep -rn "bos.ctx.validate\|bos_ctx_validate" src/server/handlers/
  ```
  → manejador presente en el dispatcher
- Test: `cargo test server::handlers::test_ctx_validate_active -- --nocapture`
- Verificación en VPS: llamar con ctx_id activo → `{"valid":true}`, con expirado → `{"valid":false,"reason":"expired"}`
- **Norma:** ADR-019, SBOS-049 §Validación

**F11.B3 — Verificar CAEP session-revoked (OpenID SSF/CAEP 1.0 Final, septiembre 2025)**
- CAEP 1.0 (Continuous Access Evaluation Profile) define eventos de seguridad en tiempo real
- Cuando bAuth revoca una sesión (ctx_id invalidado), DEBE emitir un SET (Security Event Token)
  con claim `events.https://schemas.openid.net/secevent/caep/event-type/session-revoked`
- El SET se envía a los RP (Relying Parties) registrados vía WebPush o polling endpoint
- Estructura del SET:
  ```json
  {
    "iss": "https://auth.sbos.app/realms/<tenant>",
    "jti": "<uuid_v7>",
    "iat": <unix_timestamp>,
    "aud": ["tryton","bhnexus"],
    "events": {
      "https://schemas.openid.net/secevent/caep/event-type/session-revoked": {
        "subject": {"format":"iss_sub","iss":"<iss>","sub":"<user_uuid>"},
        "reason_admin": {"en": "Offboarding completado"},
        "event_timestamp": <unix_ms>
      }
    }
  }
  ```
- Test: `cargo test caep::test_session_revoked_set_structure -- --nocapture`
- Verificación: ejecutar revocación → grep en logs de Kong y Tryton por el SET recibido
- **Norma:** OpenID CAEP 1.0 Final (sept 2025), OpenID SSF 1.0 Final (sept 2025)

**F11.B4 — Verificar invalidación en cascada de tokens al invalidar ctx_id**
- Al invalidar un ctx_id: TODOS los tokens que lo referencian quedan inválidos
- Mecanismo en Redis:
  1. `DEL ctx:<ctx_id>` — elimina la sesión
  2. `PUBLISH bauth:events '{"type":"ctx_revoked","ctx_id":"<id>","jti":"<jti>"}'`
  3. Kong consumer escucha el canal y actualiza blacklist de tokens
  4. bhnexus consumer invalida sesiones físicas del dispositivo
- Verificar que la invalidación en cascada ocurre < 30 segundos:
  ```bash
  # 1. Obtener un token activo
  TOKEN=$(curl -s -X POST /run/bos/bauth.sock '{"method":"bauth.oidc.token",...}' | jq -r '.result.access_token')
  CTX_ID=$(python3 -c "import jwt,base64; p=jwt.decode('$TOKEN',options={'verify_signature':False}); print(p['ctx_id'])")

  # 2. Revocar el ctx_id
  curl -s -X POST /run/bos/bauth.sock "{\"method\":\"bauth.context.invalidate\",\"params\":{\"ctx_id\":\"$CTX_ID\"}}"

  # 3. Medir tiempo hasta que el token se rechaza en Kong
  time (until curl -s -H "Authorization: Bearer $TOKEN" http://kong/api/health | grep -q '"error"'; do sleep 0.5; done)
  ```
  → tiempo total < 30 segundos
- **Norma:** SBOS-021 §Revocación < 30s, CAEP 1.0 §session-revoked

**F11.B5 — Verificar ctx_id en CADA audit_event de todo bAuth (ISO 27001 A.8.15)**
- El Context Plane define que NINGUNA operación puede tener trazabilidad sin ctx_id
- Verificar en la tabla de auditoría central:
  ```sql
  SELECT COUNT(*) FROM bauth.aud_event WHERE ctx_id IS NULL;
  ```
  → `0` (absolutamente ningún evento sin ctx_id)
- Verificar que el código Rust en `src/audit/audit_event.rs` tiene:
  ```rust
  pub struct AuditEvent {
      ctx_id: CtxId,  // NO Option<CtxId> — es obligatorio
      ...
  }
  ```
  Si existe `Option<CtxId>` → cambiar a `CtxId` y proveer el ctx_id `"system"` como fallback
- Grep: `grep -n "Option<CtxId>\|ctx_id: Option" src/audit/` → sin resultados
- **Normas:** ISO 27001:2022 A.8.15, SBOS-049 §Obligatoriedad, PCI DSS 4.0 Req 10.3.2

**F11.B6 — Verificar OpenTelemetry Baggage: whitelist de keys, límite 8192 chars**
- El baggage que bAuth propaga no puede contener PII (GDPR Recital 26)
- Whitelist permitida: `ctx_id`, `user_id`, `tier`, `tenant_id`, `loa`, `traceparent`
- Prohibido en baggage: `email`, `name`, `phone`, `national_id`, cualquier PII
- Verificar que el código tiene la whitelist:
  ```bash
  grep -n "baggage.*whitelist\|allowed_baggage\|BAGGAGE_KEYS" src/
  ```
  → constante con las 6 keys permitidas
- Verificar límite de 8192 chars (W3C Baggage spec):
  ```bash
  cargo test context_plane::test_baggage_size_limit -- --nocapture
  ```
  → baggage truncado o rechazado si > 8192 chars
- **Norma:** W3C Baggage §5 (size limits), GDPR Art. 4(1) + Recital 26 (pseudonymisation)

---

## APÉNDICE: TABLA RESUMEN DE VERIFICACIONES POR FASE

| Fase | Tareas | Normas clave | Bloqueos |
|------|:------:|-------------|---------|
| F7 — D12 Consolidación | 14 | EIP-712, RFC 6962, NIST IR 8202, GDPR Art.17 | FASE 7 completada (base D12) |
| F8 — D13 Implementación | 18 | EIP-55, EIP-712, W3C DID Core 1.0, Ley 164, RFC 5652 | FASE 3 DDL D13 aprobada + fichas BOS |
| F9 — Token Robustez | 12 | RFC 7519, RFC 9562, RFC 8176, RFC 7636, RFC 9449, CAEP 1.0 | Ninguno — mejora incremental |
| F10 — Auth Certificación | 16 | NIST 800-63B-4, OWASP ASVS 5.0, RFC 6238, RFC 4226, WebAuthn L2 | Ninguno — mejora incremental |
| F11 — Context Plane | 12 | SBOS-049, W3C Trace Context, OTel Baggage, NIST 800-207, CAEP 1.0 | BOS contratos C-BOS-CTX-001 cerrado |

**Total FASES 7-11: 72 tareas atómicas**
**Total FASE 0.S: 83 tareas atómicas**
**Total FASES 1-6 (REGISTRO previo): 47 tareas atómicas**
**TOTAL GENERAL REPARACIONBAUTH: 202 tareas atómicas**

---

*Documento canónico de especificación de robustez — actualizar estado tarea por tarea.*
*Ver: REGISTRO-ESTADO-REDISEÑO.md para seguimiento de ejecución.*
*Todo cambio DDL requiere aprobación humana explícita antes de aplicar.*
