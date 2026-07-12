# Anexo A.21 — El pipeline de evaluación de dominios en código: orden real, cobertura y un fail-open
## Documento de respaldo de sustentación: qué planos evalúan de verdad, cuáles son delgados, y un hallazgo de seguridad

**Tipo:** ANEXO — respaldo de sustentación (tipo **D** verificación de código + **B** industria)
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Respalda a:** MANUAL-DOMINIOS (1.01 §4-§5) · A.05 (los átomos) · A.17 (el BitMask que alimenta) · MANUAL-SEGURIDAD (2.09 — fail-closed)
**Verificación de código:** `src/bitmask/registry.rs` (356 líneas — el pipeline) + `src/domain/{12 dominios}.rs` (1.319 líneas) — leída 2026-07-11
**Normas base:** NIST SP 800-207 (pipeline ZT) · fail-closed (principio de diseño seguro) · 1.01 §5

---

## 1. Propósito

Verificar contra el código el pipeline de evaluación de los 12 dominios: si el orden real
coincide con 1.01 §5.1, qué dominios evalúan de verdad y cuáles son delgados, y un **hallazgo de
seguridad** que faltaba documentar. **Cómo citarlo:** `A.21 §4` (el fail-open) · `A.21 §3`
(cobertura por dominio).

## 2. El orden del pipeline — coincide EXACTAMENTE con 1.01 §5.1 (verificado)

`registry.rs:evaluate_all()` define `EVAL_ORDER` — y coincide bit a bit con el manual:

```
Pre-BitMask:  D8 (ctx_id válido) → D9 (credenciales/LoA)
Fast-Path:    D1 (lógico) → D3 (financiero) → D2 (físico) → D10 (delegación) → D4 (temporal)
External:     D6 (geo) → D7 (red) → D5 (biométrico) → D12 (blockchain)
Siempre:      D11 (auditoría) — post-hoc, NO afecta la decisión
```

Y el **cortocircuito** está implementado (`denied = true` detiene la cadena salvo D11) — el
orden de menor a mayor costo del manual (§5.1) es real: nadie paga biometría si el ctx expiró.

## 3. Cobertura por dominio — verificado por tamaño y madurez

| Dominio | Módulo | Líneas | Lectura |
|---|---|:---:|---|
| D1 Lógico | `logical.rs` | 195 | **Real** — el Fast-Path principal |
| D2 Físico | `physical.rs` | 222 | **Real** — el más extenso (PACS, zonas) |
| D3 Financiero | `financial.rs` | 262 | **Real** — el más desarrollado (límites, SoD, schedule) |
| D4 Temporal | `temporal.rs` | 104 | Medio — horarios/vigencia |
| D5 Biométrico | `biometric.rs` | 80 | Delgado |
| D6 Geoespacial | `geospatial.rs` | 90 | Delgado |
| D7 Red | `network.rs` | 63 | **Muy delgado** — coherente con "D7 ausente/parcial" (A.01 §17) |
| D8 Contexto | `context.rs` | 59 | **Muy delgado** — pero es Pre-BitMask (crítico) |
| D9 Credenciales | `credential.rs` | 61 | Muy delgado — Pre-BitMask (crítico) |
| D10 Delegación | `delegation.rs` | 61 | Delgado |
| D11 Auditoría | `audit_domain.rs` | 60 | Post-hoc (registra, no decide) |
| D12 Blockchain | `blockchain.rs` | 62 | Delgado |

**Los 12 dominios existen como módulos** (1.319 líneas) — ninguno está ausente. Pero hay un
gradiente claro: **D1/D2/D3 son motores reales; D5–D12 son delgados** (59–104 líneas cada uno).
Los dos Pre-BitMask (D8/D9) siendo delgados es lo más delicado — son los que deciden ANTES de
mirar un bit (fail-closed depende de ellos).

## 4. ⚠️ HALLAZGO DE SEGURIDAD — el pipeline hace FAIL-OPEN cuando falta un evaluador

En `registry.rs:evaluate_all()`, cuando no hay evaluador registrado para un dominio del
`EVAL_ORDER`:

```rust
let domain_result = match evaluator {
    Some(ev) => ev.evaluate(ctx_id, user_id, rol, atom_position, atom),
    None => {
        // Si no hay evaluador registrado, permitir por defecto
        DomainResult::permitido(domain)      // ← FAIL-OPEN
    }
};
```

**El problema:** si un dominio está en el orden de evaluación pero su evaluador no está
registrado en `self.evaluators`, el sistema **PERMITE por defecto**. Esto contradice el
principio **fail-closed** — invariante de seguridad del sistema (2.09 · CLAUDE del agente §8:
*"El fallo siempre debe ser denegatorio, nunca permisivo"*). Un dominio no cableado no debe
conceder acceso: debe negarlo o, al menos, no participar.

**Matiz atenuante (verificado):** el bucle salta los dominios inactivos por tenant
(`is_domain_active` → `continue`), así que el fail-open solo dispara para un dominio **activo
pero sin evaluador** — una inconsistencia de configuración, no el caso normal. Aun así, la
combinación "dominio activo + evaluador ausente → permitido" es exactamente el escenario que
fail-closed prohíbe.

**Resolución recomendada (P1 de seguridad):** cambiar el `None =>` a `DomainResult::denegado`
(o a un resultado neutro que no cuente como permiso), y **alertar** (un dominio activo sin
evaluador es un error de arranque que debe ser ruidoso, no silencioso). Test obligatorio:
"dominio activo sin evaluador → acceso denegado".

## 5. Lo que FALTA — específico

| # | Brecha | Exigencia | Prioridad |
|---|---|---|:---:|
| **P1-sec** | **Fail-open en evaluador ausente** (§4) | fail-closed (2.09 · CLAUDE §8) | **P1 seguridad** |
| P2 | **D8/D9 delgados** (Pre-BitMask, 59-61 líneas) — son los guardianes que deciden antes del BitMask | El pipeline ZT depende de ellos (1.01 §5.1) | P1 |
| P3 | **D5–D12 delgados** (60–90 líneas) — evaluación parcial de external-path | Los bloques B15–B19 del rol (A.01 §17) necesitan estos evaluadores completos | P2 |
| P4 | **D4/D6 sin átomos propios** — se encadenan a D1 (1.01 §5.2); verificar que el encadenamiento (PolicyChainResolver) está cableado | 1.01 §5.2 | P2 |

## 6. Verificación de completitud

| Verificación | Resultado |
|---|---|
| Orden del pipeline vs 1.01 §5.1 | ✅ **coincide exactamente** (verificado en `EVAL_ORDER`) |
| Cortocircuito | ✅ implementado (`denied`) |
| D11 post-hoc siempre | ✅ (excepción explícita en el bucle) |
| Los 12 dominios existen | ✅ como módulos (1.319 líneas) |
| Fail-closed | ❌ **fail-OPEN en evaluador ausente** (§4) — hallazgo P1 |
| Madurez | D1/D2/D3 reales (L3); D5–D12 delgados (L2 parcial) |

## 7. Referencias e historial

**Del código:** `src/bitmask/registry.rs` · `src/domain/{12 dominios}.rs`.
**Del proyecto:** 1.01 §4-§5 · A.05 · A.17 · 2.09 (fail-closed).
**Industria:** [NIST SP 800-207 §2 (Policy Engine/pipeline)](https://csrc.nist.gov/pubs/sp/800/207/final) · principio fail-closed (OWASP secure design).

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Anexo inicial (tipo D+B): el orden del pipeline verificado coincide EXACTAMENTE con 1.01 §5.1 (Pre-BitMask D8/D9 → Fast-Path → Policy-Path → External → D11 post-hoc, con cortocircuito real), la cobertura por dominio (los 12 existen, 1.319 líneas; D1/D2/D3 reales, D5–D12 delgados), y **un hallazgo de seguridad P1: el pipeline hace FAIL-OPEN** (`None => permitido`) cuando un dominio activo carece de evaluador — contradice fail-closed (2.09/CLAUDE §8); resolución: cambiar a denegado + alerta + test. Brechas: D8/D9 Pre-BitMask delgados (P1), D5–D12 parciales (P2), encadenamiento D4/D6 por verificar. |
