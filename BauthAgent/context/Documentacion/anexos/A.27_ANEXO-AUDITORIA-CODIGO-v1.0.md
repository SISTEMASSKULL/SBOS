# Anexo A.27 — La auditoría en código: DDL superior a la industria, emisor central en esqueleto
## Documento de respaldo de sustentación: el estado crudo de la trazabilidad — la paradoja verificada

**Tipo:** ANEXO — respaldo de sustentación (tipo **D** verificación de código + **B** industria)
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Respalda a:** MANUAL-AUDITORIA (5.01 §3, §10-§11) · A.14 (ctx_id) · MANUAL-MOTOR-VERSIONADO (1.13 — la otra mitad C2)
**Verificación de código:** `src/audit/` (solo `mod.rs`, 94 líneas) + `DDLs/migrations/bauth_44` (WORM) — leída 2026-07-11
**Normas base:** ISO 27001 A.8.15/A.5.33 · NIST AU-2/3/9/12 · PCI DSS 10 · RFC 6962 (Merkle)

---

## 1. Propósito

Estado crudo de la auditoría — el componente que el axioma (5.01 §2.1) declara central. **Cómo
citarlo:** `A.27 §2` (la paradoja) · `A.27 §4` (brechas).

## 2. La paradoja verificada — sustrato superior, emisor ausente

5.01 §11.1 declara una "paradoja central honesta"; el código la confirma cruda:

| Capa | Estado crudo (verificado) |
|---|---|
| **El DDL de auditoría** | ✅ **Superior a la industria** — `aud_event` (24 col, 30 tipos, `iso_control[]` en origen, hash-chain, particionado mensual) + `privilege_atom_audit` (grano por átomo + 3 columnas Merkle) — 5.01 §3 |
| **El WORM (hash-chain)** | ✅ **escrito** — `bauth_44__gap04_worm_hash_chain.sql`: `fn_worm_hash_chain()` SECURITY DEFINER + `aud_chain_head` + REVOKE UPDATE/DELETE en 10 tablas — **pendiente de APLICAR en VPS** (GAP-04) |
| **El Merkle Engine** | ✅ código — `merkle.rs` (RFC 6962, Keccak-256, 1M eventos, proof offline) |
| **El emisor central de eventos** | ❌ **ESQUELETO** — `src/audit/` contiene **solo `mod.rs` (94 líneas)**; no hay el módulo emisor que 5.01 §10 describe (`audit/siem.rs`, `audit_event.rs` no existen) |

**Traducción cruda:** bAuth tiene el **mejor sustrato de auditoría** documentable (un DDL que la
industria no iguala) y **casi ningún emisor que lo llene**. Los INSERT a `aud_event` que hacen
los handlers van directos, sin un emisor central que garantice el `iso_control[]`, la severidad
y la salida SIEM de forma uniforme. Es el reverso del pipeline de dominios (A.21): allí el motor
existe y el catálogo falta; aquí el esquema existe y el emisor falta.

## 3. El agravante de GAP-04 (verificado en A.15/tracking)

El hash-chain WORM (`bauth_44`) está **escrito pero pendiente de aplicar en VPS**, y —hallazgo
del propio GAP-04— **ningún trigger ni código Rust poblaba `entry_hash`** antes de la migración:
la columna es `NOT NULL` y los INSERT del daemon no la enviaban → esos INSERT violan el esquema
canónico. La migración `bauth_44` lo sana (el trigger BEFORE INSERT llena la columna), pero
hasta aplicarla, la inmutabilidad WORM está **declarada, no aplicada** (5.01 §11.1).

## 4. Lo que FALTA — específico

| # | Brecha | Exigencia | Prioridad |
|---|---|---|:---:|
| **AU1** | **Emisor central de auditoría** — `src/audit/` es solo `mod.rs`; faltan `audit_event.rs` (emisor uniforme con `iso_control[]`) y `siem.rs` (salida Wazuh) | NIST AU-12 (generación) · 5.01 §10 | **P1** |
| **AU2** | **Aplicar `bauth_44` en VPS** — el WORM (TRIGGER + REVOKE) está escrito, sin evidencia de aplicado | ISO A.5.33 (inmutabilidad) · GAP-04 | **P1** (Testeador) |
| AU3 | **Salida SIEM (Wazuh) operativa** — depende de AU1 | NIST 800-92 | P2 |
| AU4 | **Firma de bloques de eventos** (NIST AU-9) — el motor interno INT-LT ya está diseñado (A.08) | AU-9 | P2 |
| AU5 | **Reporte de auditoría autogenerado** (hoy consulta manual) | ISO 9001 §9.2 | P3 |
| AU6 | **Verificador de la hash-chain expuesto** (`chain_verify`) | Integridad demostrable | P2 |

## 5. La relación con el Motor de Versionado (1.13)

La auditoría (C3, "qué ocurrió") es una mitad; el versionado (C2, "cómo era/quedó") la otra
(5.01 §2.1). **Ambas dependen del mismo WORM** (`fn_worm_hash_chain` de `bauth_44`) — que el
motor 1.13 reutiliza para `ver_history` (1.13 §14). Aplicar `bauth_44` (AU2) desbloquea las dos.

## 6. Verificación de completitud

| Verificación | Resultado |
|---|---|
| DDL de auditoría | ✅ superior (30 tipos, iso_control[], Merkle) |
| Merkle Engine | ✅ código |
| WORM | ⚠️ escrito, **sin aplicar** (AU2) |
| Emisor central | ❌ **esqueleto** — `src/audit/mod.rs` solo (AU1) |
| Coherencia con 5.01 §11.1 (la paradoja) | ✅ confirmada cruda |

## 7. Referencias e historial

**Del código:** `src/audit/mod.rs` · `src/domain/merkle.rs` · `DDLs/migrations/bauth_44`. **Del proyecto:** 5.01 · 1.13 · A.08 · A.14.
**Industria:** [OCSF](https://schema.ocsf.io/) · [RFC 6962 Merkle/CT](https://datatracker.ietf.org/doc/html/rfc6962) · NIST AU-9/AU-12 · [ISO 27001 A.8.15](https://www.iso.org/standard/27001).

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Anexo inicial (tipo D+B): la paradoja de auditoría verificada cruda — **DDL superior a la industria** (aud_event 30 tipos + iso_control[] + Merkle) frente al **emisor central en ESQUELETO** (`src/audit/` = solo mod.rs 94 líneas; sin audit_event.rs/siem.rs). El WORM (bauth_44) escrito pero pendiente de aplicar + el agravante GAP-04 (entry_hash NOT NULL que nadie poblaba). 6 brechas (AU1 emisor central P1, AU2 aplicar bauth_44 P1, AU3 SIEM, AU4 firma AU-9, AU5 reporte auto, AU6 verificador de cadena) y la relación con el Motor de Versionado (mismo WORM). |
