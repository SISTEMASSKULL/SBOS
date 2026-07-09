# SBOS — Normas y Estándares de Trazabilidad para Sistemas de Autenticación con Blockchain
## Investigación Profesional para D12 — Dominio de Soberanía 12
### SKULL · SBOS · Junio 2026 · v1.0

**Propósito:** Este documento compila los estándares internacionales, regulaciones y mejores prácticas aplicables a la trazabilidad y auditoría en sistemas de autenticación con blockchain como dominio de soberanía (D12). Sirve como referencia normativa para el cumplimiento de D12 en SBOS.

**Código:** SBOS-BAUTH-D12-NORMAS-TRAZABILIDAD-v1.0
**Complementa:** `SBOS-MANUAL-BAUTH-D12-BLOCKCHAIN-WALLET-CONTROL.md` v2.1, `SBOS-BAUTH-EVALUACION-INTEGRAL-v2.2.md`

---

## ÍNDICE

1. [IETF — SCITT (RFC 9943) + Anclaje Temporal Externo](#1-ietf--scitt-rfc-9943--anclaje-temporal-externo)
2. [ETSI — eIDAS 2: Qualified Electronic Registers](#2-etsi--eidas-2-qualified-electronic-registers)
3. [W3C — DIDs + Verifiable Credentials](#3-w3c--dids--verifiable-credentials)
4. [FATF — Travel Rule (Recommendation 16, Junio 2025)](#4-fatf--travel-rule-recommendation-16-junio-2025)
5. [ISO/TC 307 — Blockchain y Tecnologías de Registro Distribuido](#5-isotc-307--blockchain-y-tecnologías-de-registro-distribuido)
6. [NIST — Control de Acceso, Auditoría y Blockchain](#6-nist--control-de-acceso-auditoría-y-blockchain)
7. [VCP v1.1 — Protocolo de Cadena de Veritas](#7-vcp-v11--protocolo-de-cadena-de-veritas)
8. [PCI-DSS 4.0.1 — Trazabilidad en Datos de Pago](#8-pci-dss-401--trazabilidad-en-datos-de-pago)
9. [Regulación LATAM / Bolivia](#9-regulación-latam--bolivia)
10. [Matriz de Conformidad — SBOS D12 vs Estándares](#10-matriz-de-conformidad--sbos-d12-vs-estándares)
11. [Referencias](#11-referencias)

---

## 1. IETF — SCITT (RFC 9943) + Anclaje Temporal Externo

### 1.1 RFC 9943 — SCITT Architecture (Abril 2026)

**Supply Chain Integrity, Transparency, and Trust (SCITT)** es el estándar IETF para transparencia verificable en cadenas de suministro digital. Define una arquitectura genérica para **registros inmutables con verificación independiente** usando Verifiable Data Structures (VDSs) y recibos CBOR/COSE.

**Elementos clave aplicables a D12:**

| Elemento SCITT | Equivalente D12 en SBOS |
|----------------|------------------------|
| **Issuer** (emisor de statements) | bAuth emite eventos de auditoría (`bauth_audit_events`) |
| **Transparency Service** (servicio de transparencia) | `AuditAnchor.sol` en Arbitrum One — almacena Merkle roots |
| **Verifiable Data Structure (VDS)** | Árbol Merkle RFC 6962 con Keccak-256 (B29.T06) |
| **Receipt** (recibo verificable) | Merkle proof + block number + tx_hash (B29.T19) |
| **Auditor** (verificador externo) | `bos-verify` CLI + Panel de Verificación Pública (B29.T08, T20) |

**Principio fundamental SCITT:** "El registro es append-only. Cualquier tercero puede verificar afirmaciones sin confiar en el emisor ni en el Transparency Service." D12 cumple este principio mediante el anclaje en Arbitrum One.

### 1.2 draft-fassbender-scitt-time-anchor (Abril 2026)

Propuesta activa de estándar IETF para anclaje temporal externo de operaciones SCITT en la blockchain de **Bitcoin** vía OpenTimestamps. Define:

- **VERIFY-ANCHOR algorithm:** cómo un verificador externo confirma que un statement fue anclado sin confiar en el Transparency Service.
- **Proof Bundle:** formato de prueba autocontenido (Merkle proof + block header + tx).
- **Median Time Past (BIP113):** cota inferior conservadora para el tiempo del bloque.
- **6-block confirmation depth:** `k >= 6` confirmaciones antes de promover un proof de "pending" a "anchored".

**Aplicación en D12:** El modelo de verificación de D12 (GA-04, GA-10) sigue el mismo patrón que SCITT time-anchor, adaptado a Arbitrum One (2 segundos de confirmación, finalidad inmediata en L2). La propiedad de "verificación sin confianza" es idéntica.

### 1.3 SCRAPI (draft-ietf-scitt-scrapi-10, Mayo 2026)

Define la API REST estándar para servicios SCITT:
- `POST /entries` — registrar un statement
- `GET /entries/{id}` — recuperar statement + receipt
- `GET /entries/{id}/receipt` — recuperar solo el recibo verificable

D12 puede alinearse con esta API para interoperabilidad futura con auditores que usen SCITT.

---

## 2. ETSI — eIDAS 2: Qualified Electronic Registers

### 2.1 Reglamento eIDAS 2 (Regulation (EU) 2024/1183)

En vigor desde **mayo 2024**. Introduce los **Qualified Electronic Registers (registros electrónicos cualificados)** como nuevo tipo de servicio de confianza. Un blockchain/DLT puede ser cualificado como registro electrónico si cumple:

**Requisitos técnicos (ETSI TS 119 535):**

| Requisito | Implementación D12 |
|-----------|-------------------|
| **Inmutabilidad** — mecanismos para prevenir modificación retroactiva | WORM a nivel PostgreSQL + Merkle root en Arbitrum One |
| **Time-stamping seguro** — anclaje temporal fiable | `block.timestamp` en Arbitrum + block number verificable |
| **Log trazable y verificable** — auditoría completa de operaciones | `bauth_audit_events` con ctx_id obligatorio |
| **Integridad demostrable sin depender de terceros** | Verificación contra Arbitrum One sin login en SBOS |
| **Prueba matemática de consistencia** | RFC 6962 Merkle tree + Keccak-256 |
| **Preservación a largo plazo** | Retención 10 años (B17.T24) + anclajes inmutables en Arbitrum |
| **Gobernanza controlada** | Documentado en ADR-D12 + runbook de operaciones |

**Estándares ETSI aplicables:**

| Estándar | Propósito |
|----------|-----------|
| **ETSI TS 119 535** | Requisitos específicos para Qualified Electronic Registries |
| **ETSI TS 119 536** | Criterios de evaluación y métodos de auditoría para registros cualificados |
| **ETSI EN 319 401** | Requisitos generales para todos los servicios de confianza |
| **ETSI EN 319 422** | Qualified time-stamping (base para anclaje temporal) |

### 2.2 ETSI GR PDL 017 — Aplicación a eIDAS 2

Mapea las propiedades de Permissioned Distributed Ledgers (PDL) a los requisitos de Qualified Electronic Ledger de eIDAS 2:

- **Inmutabilidad** → PDL: immutability, sequence integrity
- **Transparencia** → PDL: verifiable data structures, audit trails
- **Gobernanza** → PDL: permissioning, validator identity, consensus rules

### 2.3 ETSI GS PDL 013 — Gestión de Datos Distribuidos

Define **tamper-proof shared logs** y **off-chain data anchoring via hashes**. Directamente aplicable al patrón de anclaje Merkle de D12: datos reales en PostgreSQL, solo hashes en blockchain.

### 2.4 ETSI GR PDL 014 — Non-Repudiation Techniques (2025-2026)

En desarrollo. Captura de evidencia tamper-evident para acciones, decisiones y aprobaciones. Clave para probar **quién hizo qué, cuándo y bajo qué política**. D12 lo implementa mediante ctx_id + Merkle proof + on-chain timestamp.

---

## 3. W3C — DIDs + Verifiable Credentials

### 3.1 W3C DID Core 1.1 (Candidate Recommendation, Marzo 2026)

Define identificadores descentralizados (DIDs) verificables criptográficamente sin depender de un proveedor central. SBOS debe adoptar DIDs para interoperabilidad con ecosistemas externos.

**Métodos DID recomendados para SBOS:**

| Método | Uso en SBOS |
|--------|------------|
| `did:web` | Identidad institucional (tenants, empresas). HTTPS-based, simple. |
| `did:ion` | Anclaje en Bitcoin (complementa D12-A en Arbitrum). Máxima confianza. |
| `did:key` | Identidades efímeras (sesiones, dispositivos). |

### 3.2 W3C VC Data Model 2.0 (2025)

Define credenciales verificables (VCs) firmadas criptográficamente, verificables sin contactar al emisor original. D9 (credenciales) debe evolucionar hacia VCs para verificabilidad externa.

**Aplicación en D12:** Las VCs permiten que un auditor externo verifique atributos de identidad (ej: "este usuario estaba autorizado a las 15:00 del 21-jun-2026") sin acceder a la base de datos de SBOS. Complementa D12-A: Merkle root prueba integridad de auditoría; VC prueba identidad del actor.

### 3.3 W3C CCG — DID Methods Working Group (2025-2026)

Esfuerzo multi-organizacional para estandarizar un subconjunto de los 200+ métodos DID. Criterios: privacidad, escalabilidad, sostenibilidad, costo económico. `did:ion` (Bitcoin-anchored) y `did:web` (HTTPS) son los mejor posicionados.

---

## 4. FATF — Travel Rule (Recommendation 16, Junio 2025)

### 4.1 Revisión de Junio 2025

El **18 de junio de 2025**, FATF revisó la Recomendación 16 con cambios sustanciales:

| Cambio | Impacto en D12 |
|--------|---------------|
| **Confirmation of Payee (CoP)** obligatorio | D3 debe verificar identidad del beneficiario antes de liquidar |
| **Alineación con ISO 20022** | Datos de originador/beneficiario estructurados |
| **Detección de fraude** como requisito explícito | Travel Rule data debe monitorearse para señales de fraude |
| **Cadena de responsabilidad** clarificada | Cada VASP en la cadena de pago es responsable |
| **Campos estandarizados** para transferencias > USD/EUR 1,000 | nombre, dirección, fecha de nacimiento |

**Implicación para D12-B (liquidación):** Los metadatos de liquidación on-chain deben incluir los campos Travel Rule. El contrato `SettlementEngine.sol` debe soportar `bytes calldata travelRuleData` en el evento `SettlementExecuted`.

### 4.2 Umbrales por Jurisdicción

| Jurisdicción | Umbral Travel Rule |
|---|---|
| FATF (global) | USD/EUR 1,000 |
| UE (TFR Reg. 2023/1113) | Sin mínimo (cero-threshold) |
| EE.UU. (FinCEN) | USD 3,000 |
| Bolivia | Alineado con estándares GAFILAT (en evolución) |

### 4.3 Plazo de Implementación

- **2030:** Plazo global para implementar la Recomendación 16 revisada.
- **Diciembre 2024:** TFR europeo ya en vigor (más estricto que FATF).
- Bolivia, como miembro de GAFILAT, está en proceso de adopción progresiva.

---

## 5. ISO/TC 307 — Blockchain y Tecnologías de Registro Distribuido

### 5.1 Estándares Publicados

| Estándar | Título | Aplicación en D12 |
|----------|--------|-------------------|
| **ISO 22739:2024** | Blockchain and DLT — Vocabulary | Terminología estándar para documentación y compliance |
| **ISO/TR 23244:2020** | Privacy and PII protection considerations | Nunca datos personales en blockchain — solo hashes |
| **ISO/TR 23455:2019** | Overview of smart contracts | Referencia para `AuditAnchor.sol` y `SettlementEngine.sol` |
| **ISO/TR 23249:2020** | DLT for identity management | DIDs + VCs + blockchain anchoring |
| **ISO/TS 23635:2022** | Guidelines for governance | Gobernanza de red Besu QBFT |

### 5.2 En Desarrollo (2025-2026)

| Proyecto | Título | Relevancia |
|----------|--------|-----------|
| **ISO/NP TS 26691** | Blockchain — Traceability | Trazabilidad de eventos en cadenas de bloques |
| **ISO/NP 26692** | Blockchain — Audit | Auditoría de sistemas blockchain |
| **ISO/CD 24876** | Smart contract security | Seguridad de contratos inteligentes |

---

## 6. NIST — Control de Acceso, Auditoría y Blockchain

### 6.1 NIST SP 800-53 Rev.5 — Security Controls

| Control | Requisito | Implementación D12 |
|---------|----------|-------------------|
| **AC-2** | Account Management | B10 (roles), B11 (usuarios), B10.T80 (temporal) |
| **AC-5** | Separation of Duties | B1.T16 (static SoD), B17.T20 (dynamic SoD) |
| **AC-6** | Least Privilege | B17.T17 (AND delegation), Rol BitMask one-hot |
| **AU-3** | Content of Audit Records | B17.T23 (ctx_id, atom_position, domain_code, policy_state) |
| **AU-4** | Audit Storage Capacity | Particionado por mes, retención 10 años (B17.T24) |
| **AU-9** | Protection of Audit Information | WORM (REVOKE UPDATE/DELETE), hash chain SHA-256 (B17.T26) |
| **AU-10** | Non-Repudiation | ctx_id + Merkle proof + on-chain anchoring |
| **AU-11** | Audit Record Retention | 10 años fiscal (Bolivia), 12 meses auth (B17.T24) |

### 6.2 NIST SP 800-63B Rev.4 — Digital Identity

- **AAL2/AAL3** para roles financieros (D3)
- **Session Management:** max 8h, inactivity 15min (B9.T19)
- **Rate Limiting:** 5 intentos → lockout 15min (B11.T30)

### 6.3 NIST SP 800-207 — Zero Trust

- **Continuous Verification:** re-evaluar cada 300s máximo (B17.T22)
- **ctx_id válido obligatorio** en cada request (B16.T03, T15-T17)
- **Sin confianza por IP, red o ubicación** (B8, B7)

### 6.4 NIST SP 800-57 — Key Management

- Rotación de claves criptográficas cada 90-180 días (B29.T16)
- HSM FIPS 140-2/3 para claves de validador y firma blockchain
- PKCS#11 como interfaz estándar (B29.T05, T16)

---

## 7. VCP v1.1 — Protocolo de Cadena de Veritas

### 7.1 Visión General (Enero 2026)

Protocolo específico para **registros de auditoría verificables en trading algorítmico**, desarrollado como perfil SCITT. Define 3 capas de integridad:

| Capa | Propósito | D12 Equivalente |
|------|----------|----------------|
| **Layer 1 — Event Integrity** | Hash individual de cada evento (SHA-256/Keccak-256) | `bauth_audit_events` + hash por evento |
| **Layer 2 — Collection Integrity** | Merkle tree que agrupa eventos en lotes | B29.T06 (RFC 6962 + Keccak-256) |
| **Layer 3 — External Verifiability** | Anclaje blockchain para verificación externa | B29.T03-T05 (Arbitrum One) |

### 7.2 VCP Tier System (Frecuencia de Anclaje)

| Tier | Frecuencia | Aplica a |
|------|-----------|----------|
| **Platinum** | Cada 10 minutos | Transacciones > $10,000 |
| **Gold** | Cada 1 hora | Transacciones estándar — **SBOS D12 adopta Gold** |
| **Silver** | Cada 24 horas | Eventos de baja criticidad (lectura) |

### 7.3 VCP-XREF (Cross-Reference, v1.1)

Mecanismo de registro dual entre partes: permite que dos entidades mantengan registros criptográficamente vinculados con detección de discrepancias. Aplicable a D12-B (liquidación multi-entidad): cada participante del consorcio puede verificar independientemente sus liquidaciones contra el Merkle root compartido.

---

## 8. PCI-DSS 4.0.1 — Trazabilidad en Datos de Pago

### 8.1 Requisitos Aplicables

| Requisito | Descripción | Implementación D12 |
|-----------|------------|-------------------|
| **Req. 10.2** | Audit trails for all access to cardholder data | `bauth_audit_events` con ctx_id por cada acceso |
| **Req. 10.3** | Audit trail fields (user, type, date, origin) | B17.T23 (audit_id, ctx_id, user_id, event_type, evaluated_at) |
| **Req. 10.5** | Secure audit trails (immutable) | WORM + hash chain SHA-256 (B17.T26) + Merkle anchoring (B29) |
| **Req. 10.7** | Retain audit history for 12 months | B17.T24 (12 meses auth, 10 años fiscal) |
| **Req. 11.5** | Change detection mechanisms | B17.T26 (AuditIntegritySelfCheck: hash chain verification) |

---

## 9. Regulación LATAM / Bolivia

### 9.1 Bolivia — ETF (Empresas de Tecnología Financiera)

Reglamento vigente desde 2025. Reconoce **5 categorías de operación**, una de ellas explícitamente **"blockchain"**.

**Ruta de cumplimiento para D12:**

1. **Carta de intención** al regulador declarando categorías: "plataformas de pago" + "blockchain"
2. **Entorno Controlado de Pruebas (ECP):** 12 meses (prorrogable a 36), con montos limitados
3. **Depósito reembolsable** de monto modesto
4. **Reportes periódicos** demostrando:
   - Integridad de datos (Merkle proofs)
   - Inmutabilidad de auditoría (anclajes on-chain)
   - Protección de datos personales (solo hashes en blockchain)
   - Custodia gestionada (no auto-custodia)
   - KYC/AML integrado

### 9.2 GAFILAT — Grupo de Acción Financiera de Latinoamérica

Bolivia es miembro. GAFILAT sigue las recomendaciones FATF. La revisión de Recomendación 16 (Junio 2025) será adoptada progresivamente en la región.

### 9.3 Bolivia — Ley 164 de Firma Digital

Reconoce firma digital con validez jurídica plena. D12 debe integrarse con ADSIB (Agencia para el Desarrollo de la Sociedad de la Información en Bolivia) para certificados de firma digital. Ver B25 (Motores de Firma Digital).

---

## 10. Matriz de Conformidad — SBOS D12 vs Estándares

| # | Estándar | Requisito Clave | Átomo(s) SBOS | Estado |
|---|----------|----------------|---------------|--------|
| E01 | **RFC 9943 (SCITT)** | Verifiable Data Structure | B29.T06 (Merkle tree RFC 6962 + Keccak-256) | 🔴 |
| E02 | **draft-fassbender-scitt-time-anchor** | Anclaje externo verificable sin confianza | B29.T03-T05 (Arbitrum One anchoring) | 🔴 |
| E03 | **draft-ietf-scitt-scrapi** | API REST para transparencia | B29.T08 (Panel de Verificación Pública) | 🔴 |
| E04 | **ETSI TS 119 535** | Inmutabilidad del registro | B17.T23 (WORM) + B29 (Merkle anchoring) | 🔴 |
| E05 | **ETSI TS 119 535** | Time-stamping seguro | B29.T04 (`block.timestamp` en Arbitrum) | 🔴 |
| E06 | **ETSI TS 119 535** | Prueba matemática de consistencia | B17.T26 (hash chain) + B29.T19 (bos-verify) | 🔴 |
| E07 | **ETSI TS 119 535** | Trazabilidad completa de operaciones | B16 (ctx_id) + B1.T20 (DomainEvaluationAudit) | 🔴 |
| E08 | **ETSI GR PDL 017** | Mapeo PDL → eIDAS 2 Qualified Ledger | ADR-D12 + Metodología D12 v2.1 | 📄 |
| E09 | **W3C DID Core 1.1** | Identificadores descentralizados | B9.T05 (planeado para release futuro) | 📄 |
| E10 | **W3C VC Data Model 2.0** | Credenciales verificables | B9.T06 (planeado para release futuro) | 📄 |
| E11 | **FATF Rec.16 (Junio 2025)** | Travel Rule para virtual assets | D12-B: `travelRuleData` en SettlementExecuted | 🔴 |
| E12 | **FATF Rec.16 (Junio 2025)** | Confirmation of Payee (CoP) | B29.T11 (D3 ↔ liquidación) | 🔴 |
| E13 | **ISO 22739:2024** | Terminología blockchain | Documentación SBOS alineada | ✅ |
| E14 | **ISO/TR 23244:2020** | Privacidad — nunca datos personales en blockchain | Solo hashes en Arbitrum. PII en PostgreSQL | ✅ |
| E15 | **NIST SP 800-53 AU-3** | Contenido de registros de auditoría | B17.T23 (DDL bauth_audit_events) | 🔴 |
| E16 | **NIST SP 800-53 AU-9** | Protección de información de auditoría | WORM + hash chain SHA-256 + Merkle anchoring | 🔴 |
| E17 | **NIST SP 800-53 AU-10** | No repudio | ctx_id + Merkle proof + on-chain tx | 🔴 |
| E18 | **NIST SP 800-57** | Gestión de claves criptográficas | B29.T16 (HSM PKCS#11, rotación 180d) | 🔴 |
| E19 | **NIST SP 800-207** | Zero Trust — verificación continua | B16 (Context Plane) + B17.T22 (cache 30s) | 🔴 |
| E20 | **VCP v1.1** | 3 capas de integridad + tier system | Gold tier (1h), Layer 1-2-3 completas | 🔴 |
| E21 | **VCP v1.1** | XREF — verificación dual entre partes | B29.T12 (reconciliación on-chain↔PostgreSQL) | 🔴 |
| E22 | **PCI-DSS 4.0.1 Req.10** | Audit trail seguro e inmutable | B17 (Auditoría WORM + hash chain) | 🔴 |
| E23 | **PCI-DSS 4.0.1 Req.11.5** | Detección de cambios no autorizados | B17.T26 (AuditIntegritySelfCheck) | 🔴 |
| E24 | **ETF Bolivia (2025)** | Categoría "blockchain" reconocida | D12 documentado en carta de intención | 📝 |
| E25 | **Ley 164 Bolivia** | Firma digital con validez jurídica | B25 (Motores de Firma Digital) | 🔴 |

**Leyenda:** ✅ Completo · 🔴 Implementación pendiente · 📄 Diseño completo · 📝 Trámite pendiente

**Conformidad global:** 20% ✅/📄/📝, 80% 🔴 (pendiente de implementación — diseño completo)

---

## 11. Referencias

### 11.1 Estándares IETF
- [RFC 9943 — SCITT Architecture](https://www.rfc-editor.org/authors/rfc9943.html) (Abril 2026)
- [draft-fassbender-scitt-time-anchor-01](https://datatracker.ietf.org/doc/draft-fassbender-scitt-time-anchor/) — External Temporal Anchoring (Abril 2026)
- [draft-ietf-scitt-scrapi-10](https://datatracker.ietf.org/doc/draft-ietf-scitt-scrapi/) — SCITT Reference APIs (Mayo 2026)
- [draft-kamimura-scitt-vcp-02](https://datatracker.ietf.org/doc/draft-kamimura-scitt-vcp/) — VCP Profile (Enero 2026)
- [RFC 6962](https://www.rfc-editor.org/info/rfc6962) — Certificate Transparency (Merkle Tree)

### 11.2 Estándares ETSI
- [ETSI TS 119 535](https://www.etsi.org/standards-search) — Qualified Electronic Registries Requirements
- [ETSI TS 119 536](https://www.etsi.org/standards-search) — Auditing Qualified Registries
- [ETSI EN 319 401](https://www.etsi.org/standards-search) — General Trust Service Requirements
- [ETSI GR PDL 017](https://www.etsi.org/deliver/etsi_gr/PDL/001_099/017/01.01.01_60/gr_PDL017v010101p.pdf) — PDL for eIDAS 2
- [ETSI GS PDL 027](https://www.etsi.org/standards-search) — SSI / User-Centric Digital ID
- [ETSI GR PDL 034](https://www.antpedia.com/standard/1171896077.html) — Trustworthy Data Spaces (Sept 2025)

### 11.3 Estándares W3C
- [W3C DID Core 1.1](https://www.w3.org/TR/did-core/) — Candidate Recommendation (Marzo 2026)
- [W3C VC Data Model 2.0](https://www.w3.org/TR/vc-data-model-2.0/) — Ratified 2025
- [W3C CCG — DID Methods Working Group](https://lists.w3.org/Archives/Public/public-credentials/2025Aug/0004.html) (Julio 2025)

### 11.4 Regulaciones
- [eIDAS 2.0 — Regulation (EU) 2024/1183](https://eur-lex.europa.eu/eli/reg/2024/1183)
- [FATF Recommendation 16 (revised June 2025)](https://www.fatf-gafi.org/en/publications/Fatfrecommendations/update-Recommendation-16-payment-transparency-june-2025.html)
- [Reglamento ETF Bolivia (2025)](https://www.asfi.gob.bo/)
- [Ley 164 Bolivia — Firma Digital](https://www.adsib.gob.bo/)

### 11.5 Estándares ISO
- [ISO/TC 307 — Blockchain and DLT](https://www.iso.org/committee/6266604.html)
- [ISO 22739:2024 — Blockchain Vocabulary](https://www.iso.org/standard/82271.html)

### 11.6 Estándares NIST
- [NIST SP 800-53 Rev.5](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final) — Security Controls
- [NIST SP 800-63B Rev.4](https://csrc.nist.gov/pubs/sp/800/63/b/final) — Digital Identity
- [NIST SP 800-207](https://csrc.nist.gov/publications/detail/sp/800-207/final) — Zero Trust
- [NIST SP 800-57](https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev/5/final) — Key Management

### 11.7 Protocolos de Industria
- [VCP v1.1 — VeritasChain Protocol](https://dev.to/veritaschain/building-tamper-evident-audit-trails-for-trading-systems-a-vcp-v11-implementation-guide-3b2d)
- [OpenTimestamps](https://github.com/opentimestamps/opentimestamps-client)
- [Hyperledger Besu — QBFT Documentation](https://besu.hyperledger.org/private-networks/tutorials/qbft)

---

*SKULL · SBOS · SBOS-BAUTH-D12-NORMAS-TRAZABILIDAD-v1.0 · Junio 2026*
*Confidencial — Propiedad de SKULL Desarrollo de Software*
