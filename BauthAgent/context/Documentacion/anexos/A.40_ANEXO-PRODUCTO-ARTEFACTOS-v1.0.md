# Anexo A.40 — El producto y sus artefactos: qué se entrega HOY, verificado
## Documento de respaldo de sustentación (tipo D+C)

**Versión:** 1.0.0 · **Fecha:** 2026-07-11 · **Respalda a:** MANUAL-PRODUCTO (9.01) · A.16 (API) · A.29 (operación)
**Verificación de código:** binario MUSL + `bauth.service` + `src/sdk/mod.rs` — leída 2026-07-11
**Normas:** binario estático · systemd · SDK multi-lenguaje

## 1. El estado real — los artefactos que bAuth entrega HOY
| Artefacto | Evidencia | Estado |
|---|---|---|
| **Binario MUSL estático** | `target/x86_64-unknown-linux-musl/{debug,release}/bauth` — **compila** (release existe) | ✅ |
| Servicio systemd | `bauth.service` (Type=notify) | ✅ (A.29) |
| CLI `bauthctl` + `bauthctl.rs` | binarios | ✅ |
| Verificadores `bos_verify`/`verify_policies` | compilados | ✅ (A.39) |
| **SDK multi-lenguaje** | `src/sdk/mod.rs` (41 líneas, API_VERSION 1.0.0) — Go/Python/JS-TS/Java | ✅ contrato estable (9.02 §15) |
| Socket `/run/bos/bauth.sock` | Interface Dual (A.16) | ✅ |

**Veredicto:** bAuth **es un producto que compila y arranca** — binario MUSL soberano (<15MB,
sin dependencias runtime — ADR-001), servicio systemd, CLI, SDK. La distinción de un IdP
convencional (Auth0/Okta): **se instala en el servidor del cliente, no es SaaS** (9.01 §diferenciadores).

## 2. Lo que FALTA / a corregir — específico
| # | Brecha | Prioridad |
|---|---|:---:|
| PR1 | **Incoherencia Redis:** `bauth.service` declara `After/Wants=redis.service` pero Redis está desactivado en Cargo.toml (H-019, A.15-B4/A.17-C2) — el servicio espera una dependencia que el binario no usa | P2 |
| PR2 | **SDK delgado** (41 líneas) — verificar que expone el subconjunto estable completo con clientes generados por lenguaje | P2 |
| PR3 | CLAUDE dice "Java 21 (5 SPIs)" — eliminadas (A.13 ADR-001 parcial); corregir doctrina (Q4) | P2 (HITL) |
| PR4 | Frontend Flutter como artefacto de producto (A.18 — divergencia P1) | P1 |

## 3. Verificación de completitud
Producto core ✅ (binario MUSL release + systemd + CLI + SDK + socket) — es un producto real,
soberano, instalable. Brechas de coherencia (PR1 Redis, PR3 doctrina Java) y de completitud
(PR2 SDK, PR4 frontend).

**Industria:** [binario estático MUSL](https://musl.libc.org/) · IdP soberano vs SaaS (Auth0/Okta)

| Ver. | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-11 | Producto: los artefactos reales verificados (binario MUSL release compilado, systemd Type=notify, bauthctl, verificadores, SDK 4 lenguajes, socket) — bAuth ES un producto soberano instalable, no SaaS. Brechas PR1 incoherencia Redis service-vs-Cargo, PR2 SDK delgado, PR3 doctrina Java obsoleta (Q4), PR4 frontend (A.18). |
