# Anexo A.25 — El subsistema de calidad/cumplimiento: DDL sin código de población
## Documento de respaldo de sustentación (tipo D+B)

**Versión:** 1.0.0 · **Fecha:** 2026-07-11 · **Respalda a:** MANUAL-CALIDAD (7.02) · MANUAL-NORMAS (7.03) · A.06/A.07
**Verificación de código:** `DDLs/migrations/bauth_30__compliance_qa.sql` + búsqueda `compliance_test` en `src/` — leída 2026-07-11
**Normas:** ISO 27001 A.8.5/A.8.9 · ISO 9001 §9.2 · OWASP ASVS · vectores oficiales RFC

## 1. El estado crudo — subsistema en DDL, sin emisor de resultados en código
| Capa | Estado |
|---|---|
| `bauth_30__compliance_qa.sql` (5 tablas + score + certificados) | ✅ DDL (7.03 §3) — compliance como dato |
| 16 marcos `bauth_fw_01..16` sembrados | ✅ seeds |
| **Código Rust que ejecuta tests y puebla `compliance_test_result`** | ❌ **0 archivos** qa/compliance en `src/` (grep) |

**Traducción cruda:** existe el mejor sustrato de compliance (tablas con estado-máquina
not_started→certified, resultados WORM, certificados Ed25519) pero **casi ningún código que lo
llene con vectores de prueba reales**. Los requisitos están como estructura, no poblados con
estado verificado (7.03 §9.1: "requisitos poblados con datos reales — por verificar").

## 2. Lo que FALTA — específico
| # | Brecha | Exigencia | Prioridad |
|---|---|---|:---:|
| Q1 | **Poblar `compliance_requirement`** con las secciones reales de los 16 marcos | ISO A.8.5 | P1 |
| Q2 | **Cargar vectores oficiales RFC** en `compliance_test_case` (RFC 6238 TOTP, WebAuthn, JOSE — A.15-B5) | Vectores oficiales | P1 |
| Q3 | **Emisor de resultados** — código que corre los tests y escribe `compliance_test_result` (WORM) | ISO A.8.9 | P1 |
| Q4 | Reporte de cumplimiento autogenerado (`GROUP BY iso_control`) | ISO 9001 §9.2 | P2 |
| Q5 | Marcos EU 2026 (NIS2/DORA/AI Act) como `fw_17..19` | Convergencia regulatoria | P2 |

## 3. Verificación de completitud
DDL ✅ superior · marcos ✅ 16 sembrados · emisor/población ❌ (Q1-Q3, P1) — el patrón "esquema existe, motor falta" (como A.27 auditoría).

**Industria:** [ISO 27001 A.8.5](https://www.iso.org/standard/27001) · [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/) · continuous compliance (NIS2/DORA)

| Ver. | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-11 | Subsistema compliance: DDL superior (bauth_30, 5 tablas + 16 marcos) pero **sin código de población** (0 archivos qa en src/); requisitos sin poblar, vectores RFC sin cargar, emisor ausente (Q1-Q3 P1). Mismo patrón esquema-sin-motor que A.27. |
