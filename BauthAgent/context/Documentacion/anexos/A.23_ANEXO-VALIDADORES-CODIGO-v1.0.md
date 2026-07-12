# Anexo A.23 — Los validadores de templates en código: cobertura real de reglas
## Documento de respaldo de sustentación: qué valida el código de los contratos Rol/User, qué falta

**Tipo:** ANEXO — respaldo de sustentación (tipo **D** verificación de código)
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Respalda a:** MANUAL-ROLES (1.09 §11) · MANUAL-USER-TEMPLATE (1.08 §8) · A.01 §18 · A.02 §20
**Verificación de código:** `roltemplate_validator.rs` (279 líneas) + `usertemplate_validator.rs` (495 líneas) — leída 2026-07-11

---

## 1. Propósito

Verificar qué reglas de los contratos valida el código real vs las declaradas (A.01 §18 / A.02
§20). **Cómo citarlo:** `A.23 §2`.

## 2. El estado real — validadores sustanciales

| Validador | Líneas | Lectura |
|---|:---:|---|
| `roltemplate_validator.rs` | 279 | **Real** — valida la estructura del RolTemplate |
| `usertemplate_validator.rs` | 495 | **Real y el más extenso** — las 15 secciones del UserTemplate (1.08 §4) |

**Veredicto:** ambos validadores existen y son sustanciales (774 líneas) — L2-L3. No son stubs.
El `usertemplate_validator` verifica las 15 secciones (1.08 §4.1); el `roltemplate_validator`
aplica las reglas de esquema y semánticas (A.01 §18).

## 3. Lo que FALTA — específico

| # | Brecha | Exigencia | Prioridad |
|---|---|---|:---:|
| V1 | **Auditar cobertura regla-por-regla** — las 6 de esquema + 4 semánticas de cada contrato (A.01 §18 / A.02 §20): confirmar que TODAS están implementadas y con test | Ninguna regla declarada sin código | P2 |
| V2 | **`identity_proofing` (A.02 U1)** — cuando se añada al UserTemplate, el validador debe verificar el IAL | 800-63A | P2 (tras materializar U1) |
| V3 | **Validación de firma del contrato** (digital_signature) — verificar que el validador comprueba integridad | Ley 164 · A.08 | P2 |
| V4 | Alinear el validador a los bloques nuevos B15–B20 (rol) cuando se materialicen | A.01 §17 | P3 |

## 4. Verificación de completitud

| Verificación | Resultado |
|---|---|
| Validadores existen y son reales | ✅ 774 líneas |
| Cobertura regla-por-regla | ⚠️ por auditar (V1) |
| Coherencia con A.01/A.02 | ✅ base; deltas en V2-V4 |

## 5. Referencias e historial

**Del código:** `src/domain/{roltemplate,usertemplate}_validator.rs`. **Del proyecto:** 1.08 §8 · 1.09 §11 · A.01 §18 · A.02 §20.

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Anexo inicial (tipo D): los validadores reales (roltemplate 279 + usertemplate 495 = 774 líneas, L2-L3, no stubs) y 4 brechas (V1 auditar cobertura regla-por-regla, V2 identity_proofing tras U1, V3 validación de firma, V4 bloques nuevos). |
