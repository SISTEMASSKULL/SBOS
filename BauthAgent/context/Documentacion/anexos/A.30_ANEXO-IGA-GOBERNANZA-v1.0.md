# Anexo A.30 — IGA: cómo la industria ejecuta certificación, role mining y JML — y qué falta
## Documento de respaldo de sustentación (tipo B+D)

**Versión:** 1.0.0 · **Fecha:** 2026-07-11 · **Respalda a:** MANUAL-GOBERNANZA-IGA (7.01) · A.10 (revocación) · MANUAL-ROLES (1.09 §14)
**Verificación de código:** `DDLs/` (aud_review, aud_ghost_account) + `src/sync/` — leída 2026-07-11
**Normas:** NIST AC-2(j) · ISO 27001 A.5.18 · SOX §404 · SailPoint/Saviynt (industria IGA)

## 1. El estado real — tablas sí, motores no
| Capacidad IGA | Estado |
|---|---|
| Tablas de certificación/revisión (`aud_review`) + huérfanas (`aud_ghost_account`) | ✅ DDL (5.01) |
| SoD nativo O(1) (matriz de conflictos) | ✅ código (A.17 conflict.rs) |
| **Motor de campañas de certificación** | ❌ no existe |
| **Barrido de cuentas huérfanas** (motor) | ❌ (tabla sí, proceso no) |
| **Role mining** | ❌ |
| **JML automatizado desde RRHH** | ⚠️ diseñado (biedata→bAuth, 1.08 §7) — `src/sync/` a verificar |

**Traducción cruda:** el pilar IGA (II) tiene el sustrato (tablas + SoD) pero **los motores que
lo encienden faltan** — el patrón recurrente. 0.00 §8 pilar II: "motores: campañas, barrido,
role mining, JML automatizado".

## 2. Cómo la industria lo hace (SailPoint/Saviynt/Omada)
- **Campañas de certificación:** el revisor recibe su lote de accesos, aprueba/revoca/escala con SLA; sin respuesta → auto-acción (A.10 §5).
- **Role mining:** analítica sobre asignaciones reales → sugiere roles óptimos (reduce el long-tail de permisos, 70-80% del riesgo).
- **JML automatizado:** el sistema de RRHH es la fuente autoritativa; joiner/mover/leaver disparados por eventos, no manuales.
- **2026:** certificación asistida por IA (Harbor Pilot/MCP) — consulta en lenguaje natural.

## 3. Lo que FALTA — específico
| # | Brecha | Prioridad |
|---|---|:---:|
| IG1 | Motor de campañas de certificación (sobre `aud_review`) | P1 |
| IG2 | Barrido de cuentas huérfanas (sobre `aud_ghost_account`) | P1 |
| IG3 | JML automatizado end-to-end (verificar `src/sync/`) | P1 |
| IG4 | Role mining | P2 |

**Industria:** [SailPoint IGA](https://uberether.com/identity-governance-and-administration-sailpoint/) · [IGA 2026](https://www.decryptiondigest.com/blog/identity-governance-administration-iga) · NIST AC-2(j)

| Ver. | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-11 | IGA: sustrato presente (tablas aud_review/ghost + SoD O(1)) pero motores ausentes (campañas, barrido, role mining, JML); cómo lo hace la industria; brechas IG1-IG4 (P1 los motores). |
