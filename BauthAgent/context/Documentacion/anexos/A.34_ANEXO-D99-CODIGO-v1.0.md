# Anexo A.34 — D99 Administrativo Global: el piso irrenunciable en código
## Documento de respaldo de sustentación (tipo D+B)

**Versión:** 1.0.0 · **Fecha:** 2026-07-11 · **Respalda a:** MANUAL-D99 (2.06) · A.01 §B13 (retención) · A.27 (auditoría)
**Verificación de código:** búsqueda D99/piso de retención/garante en `src/` y `DDLs/` — leída 2026-07-11
**Normas:** ISO 27001 A.8.15/A.5.33 · el piso ≥365 días irrenunciable

## 1. El estado real — D99 como garante
D99 es el dominio **fuera del BitMask** (2.06): el garante del sistema (auditoría global piso
≥365 días, no desactivable). El manual 1.13 lo materializa como CHECK (`chk_vr_piso_d99
retention_total >= 365 days`) en la especificación del motor de versionado. En auditoría, es el
piso que ningún tenant puede bajar (A.01 §B13, 5.01 §9).

## 2. Lo que FALTA — específico
| # | Brecha | Exigencia | Prioridad |
|---|---|---|:---:|
| D1 | **Enforcement del piso ≥365d en código** — verificar que ninguna operación de retención/purga puede ir bajo el piso (hoy es doctrina + el CHECK propuesto del motor 1.13, no aplicado) | ISO A.5.33 · 2.06 §3 | P2 (con el motor 1.13) |
| D2 | El garante D99 como evaluador post-hoc que impone el piso independientemente del tenant | 2.06 | P2 |

## 3. Verificación de completitud
D99 doctrina ✅ · CHECK del piso especificado en 1.13 (📐 L1) · enforcement en código ⏳ (depende del motor de versionado y del emisor de auditoría A.27).

**Industria:** [ISO 27001 A.5.33](https://www.iso.org/standard/27001) · NIST AU-11

| Ver. | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-11 | D99: el garante fuera del BitMask, piso ≥365d irrenunciable (doctrina + CHECK propuesto en el motor 1.13 chk_vr_piso_d99, L1); brechas D1 enforcement en código, D2 evaluador garante. Depende del motor de versionado y del emisor de auditoría. |
