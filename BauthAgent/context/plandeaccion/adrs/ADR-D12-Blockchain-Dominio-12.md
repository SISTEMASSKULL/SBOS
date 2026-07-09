# ADR-D12 — Incorporación de Blockchain como Dominio de Soberanía 12

**Estado:** Aceptado · **Fecha:** 2026-06-21

---

## Contexto

SBOS opera 11 dominios de soberanía (D1–D11) que cubren identidad, autorización y auditoría. El dominio D11 (Auditoría) provee registros inmutables WORM a nivel de base de datos, pero tiene un límite preciso: no ofrece **verificabilidad por un tercero que no confía en la infraestructura de SBOS**. Si un regulador, banco corresponsal o auditor externo necesitan confirmar la integridad de los registros sin depender de la palabra de SBOS, D11 llega a su techo natural.

Adicionalmente, el modelo de negocio del proyecto contempla liquidación entre múltiples entidades (comercios, agentes, sucursales) que no confían entre sí y que se beneficiarían de un mecanismo de liquidación verificable sin banco corresponsal en cada operación.

## Decisión

**Incorporar un dominio de soberanía número 12 (D12 — Blockchain) con dos variantes complementarias:**

### Variante A — Ancla de Auditoría (obligatoria)

Publicar periódicamente el Merkle root de lotes de eventos de `bauth_audit_events` en una blockchain pública (Arbitrum One, capa 2 de Ethereum). Esto permite que cualquier tercero verifique matemáticamente que un registro de auditoría no fue alterado después de su fecha, sin depender de SBOS.

- **Stack:** Arbitrum One (L2), Hyperledger Besu (cliente), `ethers-rs` (Rust), Merkle tree RFC 6962 con Keccak-256
- **Frecuencia:** Gold tier (cada 1 hora, estándar VCP v1.1)
- **Costo:** ~$0.15/mes en gas
- **Impacto en latencia:** Ninguno — operación asíncrona, no bloquea el hot path
- **Smart contract:** `AuditAnchor.sol` (Solidity 0.8.26) — solo almacena Merkle roots

### Variante B — Motor de Liquidación (condicionada a madurez del negocio)

Operar una red permisionada Hyperledger Besu con consenso QBFT para liquidación on-chain entre entidades del consorcio que no confían entre sí.

- **Stack:** Hyperledger Besu QBFT (red permisionada), 4-7 validadores, `SettlementEngine.sol`
- **Finalidad:** 1 bloque = 2 segundos (QBFT finalidad inmediata)
- **Costo:** ~$260/mes en VPS (sin HSM), ~$800/mes con HSM FIPS
- **Custodia:** Gestionada (nunca auto-custodia) — Vault + SoftHSM2/HSM vía PKCS#11

### Variante C — Reemplazar BitMask (descartada)

No recomendada. El BitMask Fast-Path resuelve autorización en < 0.5ns; reemplazarlo por verificación en cadena reintroduciría latencia de segundos donde se requieren nanosegundos.

## Alternativas

| Alternativa | Problema |
|------------|---------|
| No incorporar blockchain | Sin verificabilidad externa. D11 solo es inmutable para quien confía en SBOS |
| OpenTimestamps (Bitcoin) | Sin smart contracts. Sin capacidad de liquidación (Var B) |
| Cadena propia pública con token | Riesgo regulatorio máximo. Complejidad innecesaria |
| Cosmos SDK | Complejidad de SDK. Ecosistema más pequeño que EVM |
| Ripple/XRP Ledger | Propietario. Sin permisos para red propia |

## Consecuencias

**Positivas:**
- Verificabilidad externa sin confianza (propiedad única vs Okta/Auth0/Entra ID)
- Cumplimiento regulatorio: el reglamento ETF Bolivia reconoce "blockchain" como categoría explícita
- Diferenciación competitiva: 4 productos vendibles (Compliance-in-a-Box, Billetera White-Label, IAM Soberano, Trust Layer)
- Stack 100% open source (Apache 2.0, MIT, MPL 2.0)
- Sin vendor lock-in: cada componente implementa un estándar abierto

**Negativas:**
- Nueva dependencia operativa: RPC de Arbitrum (Var A), red Besu QBFT (Var B)
- Complejidad adicional: ~164h de desarrollo para ambas variantes
- Regulatorio: requiere declarar "blockchain" en carta de intención ETF
- El gas de Arbitrum, aunque mínimo ($0.15/mes), requiere monitoreo

## Referencias

- `SBOS-MANUAL-BAUTH-D12-BLOCKCHAIN-WALLET-CONTROL.md` v2.1 — Tesis completa de arquitectura + productos
- `SBOS-BAUTH-EVALUACION-INTEGRAL-v2.2.md` — Evaluación integral con 47 gaps + soluciones + presupuesto
- `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md` — DDL `bos_blockchain` (Apéndice D)
- RFC 6962 — Certificate Transparency (Merkle tree specification)
- VCP v1.1 — VeritasChain Protocol (tier system for anchoring frequency)
- Hyperledger Besu Documentation — QBFT consensus, permissioning, PKCS#11 HSM
- Reglamento ETF Bolivia (2025) — Categoría "blockchain"
- NIST SP 800-57 — Key Management
