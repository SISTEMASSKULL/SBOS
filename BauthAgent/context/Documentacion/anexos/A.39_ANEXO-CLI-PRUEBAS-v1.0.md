# Anexo A.39 — La CLI de pruebas externas: bos_verify y verify_policies reales
## Documento de respaldo de sustentación (tipo D)

**Versión:** 1.0.0 · **Fecha:** 2026-07-11 · **Respalda a:** MANUAL-CLI-PRUEBAS (7.04) · A.16 (la superficie que prueban)
**Verificación de código:** `src/bin/{bos_verify,verify_policies,bauthctl}.rs` — leída 2026-07-11
**Normas:** verificación empírica · AA-1 (evidencia)

## 1. El estado real — herramientas de verificación reales
| Herramienta | Líneas | Qué hace |
|---|:---:|---|
| `bauthctl.rs` | — | CLI de administración (WebSocket RPC — A.16) |
| `bos_verify.rs` | 256 | Verificación externa (bloques, integridad) |
| `verify_policies.rs` | 380 | Verificación de políticas — **binario compilado** (target/…/verify_policies) |

**Veredicto:** las herramientas de prueba externa existen y son reales (636 líneas), compiladas.
Sustrato de verificación empírica presente (7.04).

## 2. Lo que FALTA — específico
| # | Brecha | Prioridad |
|---|---|:---:|
| CL1 | Cobertura de verificación — qué % de la superficie ≈151 y de los dominios cubre `bos_verify` | P2 |
| CL2 | Integración con AA-1 (`verificar_afirmacion.sh`) para evidencia firmada | P2 |
| CL3 | Q2 del informe: `bos_verify` cabecera declara "Arbitrum" — corregir a Besu soberano (HITL doctrina) | P2 |

## 3. Verificación de completitud
CLI de pruebas ✅ real (bos_verify + verify_policies compilados) · cobertura por medir (CL1) · nota de doctrina Q2 (CL3).

| Ver. | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-11 | CLI de pruebas: bauthctl + bos_verify (256) + verify_policies (380, binario compilado) reales; brechas CL1 cobertura, CL2 AA-1, CL3 nota Q2 (Arbitrum→Besu, doctrina). |
