# BAUTH-DOMINIO-D13-BLOCKCHAIN — Dominio D13 Blockchain / Firma Digital Externa
## bAuth Identity Core v3.0 · Diseño — NO IMPLEMENTADO, pendiente aprobación DDL

**Versión:** 1.0.0 · **Fecha:** 2026-07-01 · **Estado:** DISEÑO — DDL PENDIENTE

**Propósito:** Definir el dominio D13 para control de acceso a operaciones blockchain,
firma digital externa (ADSIB/SIN Bolivia), e identidad descentralizada (DID).

**Estándares base:**
- Ethereum/Besu: EIP-155, EIP-1559, EIP-712 (typed data signing), EIP-2098
- W3C DID Core 1.0 (2022) — Decentralized Identifiers
- W3C Verifiable Credentials 2.0 (2024)
- ADSIB-FD-POLT-015 v2.3 — Certificación digital Bolivia (Ley 164)
- SIN Bolivia RND 10-0025-15 — Facturación electrónica con firma digital
- RFC 5652 — Cryptographic Message Syntax (CMS) para firma RSA-SHA256
- NIST FIPS 186-5 — Digital Signature Standard (DSS)
- ISO/IEC 14888-3:2018 — Mecanismos de firma digital

---

## Motivación del dominio D13

bAuth implementa un **doble motor de firmas:**
1. **Interno (Vault Ed25519):** firma tokens JWT, credenciales internas. Controlado por D1-D12.
2. **Externo (ADSIB RSA-SHA256):** firma documentos con validez jurídica Bolivia (Ley 164).
   Además: transacciones Ethereum/Besu para trazabilidad de eventos críticos.

D13 cubre exclusivamente el motor externo: identidad en blockchain y firma con validez legal externa.

---

## Posición en la arquitectura

| Dominio | Responsabilidad |
|---------|----------------|
| D1 — Auth | Autenticar al actor (quién eres) |
| D2 — RBAC | Evaluar permisos (qué puedes hacer) |
| **D13 — Blockchain** | **Operar en cadena y firmar documentos legales (cómo se certifica)** |

---

## Nomenclatura de átomos D13

```
D13.{app}.{modulo}_{campo}.{VERBO}

Apps:
  chain   = operaciones en Ethereum/Hyperledger Besu
  did     = identidad descentralizada W3C DID
  legalsg = firma digital con validez legal (ADSIB/SIN Bolivia)
```

**Posición BD:** D13 se agrega después de D12. Posición global sugerida: 5929-6200.
(D00 CRUD usa 5809-5928. D13 continúa desde 5929.)

---

## Aplicación: chain (Ethereum / Hyperledger Besu)

### Campo: wallet_view (ver wallet y balance)

| Átomo | CRUD | Posición D13 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D13.chain.wallet_view.C` | CREATE | D13.001 | Crear/registrar wallet Ethereum (secp256k1) | EIP-55 (checksum address) |
| `D13.chain.wallet_view.R` | READ   | D13.002 | Ver dirección wallet y balance | EIP-55 · EIP-1559 |
| `D13.chain.wallet_view.U` | UPDATE | D13.003 | Actualizar metadatos de wallet | EIP-55 |
| `D13.chain.wallet_view.D` | DELETE | D13.004 | Desregistrar wallet del sistema | EIP-55 |

> Dirección: 20 bytes hex con checksum EIP-55. Ej: `0x742d35Cc6634C0532925a3b8D4C9C3dA5e6F7A8`

### Campo: tx_sign (firmar transacciones)

| Átomo | CRUD | Posición D13 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D13.chain.tx_sign.C` | CREATE | D13.005 | Crear y firmar transacción Ethereum | EIP-155 · EIP-1559 |
| `D13.chain.tx_sign.R` | READ   | D13.006 | Ver transacciones firmadas | EIP-1559 |
| `D13.chain.tx_sign.U` | UPDATE | D13.007 | Reemplazar transacción pendiente (EIP-1559 bump) | EIP-1559 §5.1 |
| `D13.chain.tx_sign.D` | DELETE | D13.008 | Cancelar transacción pendiente (nonce override) | EIP-1559 |

### Campo: typed_data_sign (firma de datos estructurados EIP-712)

| Átomo | CRUD | Posición D13 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D13.chain.typed_data_sign.C` | CREATE | D13.009 | Firmar datos estructurados (hash + domainSeparator) | EIP-712 |
| `D13.chain.typed_data_sign.R` | READ   | D13.010 | Ver firmas tipadas registradas | EIP-712 |
| `D13.chain.typed_data_sign.U` | UPDATE | D13.011 | N/A — firmas son inmutables en cadena | EIP-712 |
| `D13.chain.typed_data_sign.D` | DELETE | D13.012 | Revocar capacidad de firma tipada | EIP-712 |

### Campo: contract_execute (ejecutar smart contracts)

| Átomo | CRUD | Posición D13 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D13.chain.contract_execute.C` | CREATE | D13.013 | Llamar función de escritura en smart contract | EIP-155 · Solidity ABI |
| `D13.chain.contract_execute.R` | READ   | D13.014 | Llamar función de solo lectura (call, no gas) | Solidity ABI |
| `D13.chain.contract_execute.U` | UPDATE | D13.015 | Modificar parámetros de llamada | Solidity ABI |
| `D13.chain.contract_execute.D` | DELETE | D13.016 | Revocar capacidad de ejecución de contrato | EIP-155 |

### Campo: multi_sig_participate (participar en multi-firma)

| Átomo | CRUD | Posición D13 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D13.chain.multi_sig_participate.C` | CREATE | D13.017 | Agregar firma a transacción multi-sig | EIP-712 · Gnosis Safe |
| `D13.chain.multi_sig_participate.R` | READ   | D13.018 | Ver transacciones multi-sig pendientes | EIP-712 |
| `D13.chain.multi_sig_participate.U` | UPDATE | D13.019 | Modificar firma pendiente | EIP-712 |
| `D13.chain.multi_sig_participate.D` | DELETE | D13.020 | Revocar firma de transacción multi-sig | EIP-712 |

---

## Aplicación: did (W3C Decentralized Identifiers)

### Campo: did_manage (gestionar identidad DID)

| Átomo | CRUD | Posición D13 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D13.did.did_manage.C` | CREATE | D13.021 | Crear DID Document (did:ethr o did:sbos) | W3C DID Core 1.0 §7.1 |
| `D13.did.did_manage.R` | READ   | D13.022 | Resolver DID Document | W3C DID Core 1.0 §7.2 |
| `D13.did.did_manage.U` | UPDATE | D13.023 | Actualizar DID Document (rotation de claves) | W3C DID Core 1.0 §7.3 |
| `D13.did.did_manage.D` | DELETE | D13.024 | Desactivar DID | W3C DID Core 1.0 §7.4 |

### Campo: vc_issue (emitir Verifiable Credentials)

| Átomo | CRUD | Posición D13 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D13.did.vc_issue.C` | CREATE | D13.025 | Emitir credencial verificable firmada | W3C VC 2.0 §4 |
| `D13.did.vc_issue.R` | READ   | D13.026 | Ver credenciales emitidas | W3C VC 2.0 §4 |
| `D13.did.vc_issue.U` | UPDATE | D13.027 | Reemitir credencial (refresh) | W3C VC 2.0 §5 |
| `D13.did.vc_issue.D` | DELETE | D13.028 | Revocar credencial verificable | W3C VC 2.0 §5.5 |

---

## Aplicación: legalsg (firma digital con validez legal Bolivia)

### Campo: legal_sign_doc (firmar documentos con certificado ADSIB)

| Átomo | CRUD | Posición D13 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D13.legalsg.legal_sign_doc.C` | CREATE | D13.029 | Firmar documento con cert ADSIB RSA-SHA256 | Ley 164 Bolivia · ADSIB-FD-POLT-015 v2.3 |
| `D13.legalsg.legal_sign_doc.R` | READ   | D13.030 | Ver documentos firmados | ADSIB-FD-POLT-015 v2.3 |
| `D13.legalsg.legal_sign_doc.U` | UPDATE | D13.031 | Re-firmar documento (nueva versión) | Ley 164 Bolivia |
| `D13.legalsg.legal_sign_doc.D` | DELETE | D13.032 | Revocar firma (dentro de ventana legal) | Ley 164 Bolivia |

### Campo: invoice_sign (firmar facturas SIN con cert digital)

| Átomo | CRUD | Posición D13 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D13.legalsg.invoice_sign.C` | CREATE | D13.033 | Firmar factura electrónica con cert ADSIB | SIN Bolivia RND 10-0025-15 · RFC 5652 |
| `D13.legalsg.invoice_sign.R` | READ   | D13.034 | Ver facturas firmadas digitalmente | SIN Bolivia RND 10-0025-15 |
| `D13.legalsg.invoice_sign.U` | UPDATE | D13.035 | Anular/corregir factura firmada | SIN Bolivia RND 10-0025-15 |
| `D13.legalsg.invoice_sign.D` | DELETE | D13.036 | Revocar capacidad de firma de facturas | SIN Bolivia RND 10-0025-15 |

---

## Resumen D13

| Aplicación | Campos | Átomos | Posiciones |
|:----------:|:------:|:------:|:----------:|
| chain | 5 | 20 | D13.001–D13.020 |
| did | 2 | 8 | D13.021–D13.028 |
| legalsg | 2 | 8 | D13.029–D13.036 |
| **TOTAL D13** | **9** | **36** | **D13.001–D13.036** |

**Posiciones globales sugeridas:** 5929–5964

---

## Integración con bAuth

| Componente | Relación con D13 |
|-----------|-----------------|
| Vault PKI (Ed25519) | Motor interno — NO usa D13. Firma tokens JWT internos. |
| ADSIB Bolivia | Motor externo — D13.legalsg controla quién puede usar el certificado ADSIB |
| Hyperledger Besu | Nodo blockchain — D13.chain controla operaciones on-chain |
| Keycloak | No directamente — D13 opera en capa de aplicación, no en IDP |
| bAuth reconcile loop | Verifica estado de certs ADSIB (expiración, revocación CRL) cada 60s |

---

*Documento de diseño — pendiente aprobación DDL antes de implementar.*
*Ver: `BAUTH-ARQUITECTURA-ATOMICA-FINAL.md` · `BAUTH-CATALOGO-ATOMOS-D4-D12.md`*
