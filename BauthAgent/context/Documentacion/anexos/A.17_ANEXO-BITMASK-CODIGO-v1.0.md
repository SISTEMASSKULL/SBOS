# Anexo A.17 — El BitMask Dual en código: qué existe, qué es cascarón y qué falta completar ESPECÍFICAMENTE
## Documento de respaldo de sustentación: el motor de privilegios verificado módulo a módulo

**Tipo:** ANEXO — respaldo de sustentación (tipo **D** verificación de código + **B** industria)
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Respalda a:** MANUAL-BITMASK (1.04 — todas sus secciones; corrige §14.2 sobre el cache) · MANUAL-ATOMOS (1.03) · A.03 §6 (el modelo) · A.05 (el catálogo por sembrar)
**Verificación de código:** `src/bitmask/` (11 módulos, 2.640 líneas) + `src/domain/{bitmask,inheritance,sod}` (shims) + `Cargo.toml` — leída 2026-07-11
**Normas base:** ANSI INCITS 359 · NIST RBAC §4.2 · ADR-009 (BitMask Dual) · OpenID AuthZEN 1.0

---

## 1. Propósito

Decir con evidencia **qué del motor de privilegios ya está implementado, qué módulos son
cascarones/shims, y qué falta completar específicamente** — la lista definitiva para
desarrollar sin fricciones. **Cómo citarlo:** `A.17 §2` (lo que existe) · `A.17 §4` (lo que
falta).

## 2. Lo que EXISTE — el motor real verificado (`src/bitmask/`, 2.640 líneas)

| Módulo | Líneas | Qué implementa (API pública verificada) |
|---|:---:|---|
| `atom.rs` | ~230 | **AtomBitMask 64-bit (label encoding)**: `new/new_simple`, `from_u64/to_u64`, extracción de campos (`device_categories()`, `min_trust()`, `token_binding()`) — la identificación estructurada |
| `rol.rs` | 291 | **RolBitMask N-bit one-hot** (`bitvec`): la combinación OR/AND-NOT entre roles |
| `resolver.rs` | 333 | La resolución (PolicyChain — el encadenamiento D4/D6 a átomos D1) |
| `registry.rs` | 356 | **DomainRegistry — el pipeline de evaluación** (el orden Pre-BitMask→FastPath→Policy→External→D11 de 1.01 §5) |
| `fastpath.rs` | 132 | El FastPath (evaluación bit pura) |
| `closure.rs` / `conflict.rs` | ~ | Closure de herencia · matriz de conflictos SoD |
| `catalog.rs` | ~180 | Registro de átomos con validación (`register`, `validate_seeds`, posiciones) |
| `serializer.rs` | 158 | Serialización (Base64 del RolBitMask — 1.09 §7) |

**El shim con la lección:** `domain/bitmask.rs` (23 líneas) está **DEPRECADO y documentado en
el propio código**: *"el modelo viejo (SAM-128, OR directo sobre códigos) producía escalamiento
silencioso: nuevo(1) OR editar(2) = 3 = eliminar 🚨"* — re-exporta `crate::bitmask`. Los
`domain/{inheritance,sod}` (8 y 3 líneas) son también shims: la implementación real vive en
`bitmask/{closure,conflict}.rs`. **Implicación editorial:** la ARQUITECTURA MODULAR del CLAUDE
(que ubica el motor en `domain/`) describe la época previa — el módulo real es `src/bitmask/`.

## 3. Corrección al manual (verificada)

1.04 §14.2 afirma *"evaluación sin red ni BD (RolBitMask en Redis local)"* — **el código dice
otra cosa:** Redis está DESACTIVADO (`Cargo.toml` H-019, dependencia comentada). Hoy el bundle
no tiene cache distribuido: la evaluación opera con lo cargado en memoria del proceso +
PostgreSQL. La afirmación es del diseño objetivo, no del estado real — corrección enrutada a
1.04 (misma familia que A.15-B4).

## 4. Lo que FALTA completar — específico, verificado y priorizado

| # | Falta ESPECÍFICAMENTE | Evidencia | Qué exige | Resolución |
|---|---|---|---|---|
| **C1** | **El catálogo de átomos de dominios NO está sembrado**: el motor evalúa sobre los átomos existentes (D1 generativo + D00), pero D2–D12 (~72 átomos de elemento) y **D13 (36 átomos, posiciones 5929–5964)** no tienen seed | A.05 §4 (estado DISEÑO, HITL) · 1.04 §14.4 P1 | Sin catálogo sembrado, los planos External del pipeline no tienen bits que evaluar | Los seeds del plan A.05 §4 (7 pasos, prerequisito `atom_type`) — P1 |
| **C2** | **SAM-128 / B9 del contrato: CERO presencia en código** (`grep sam128 src/ → 0 archivos`) — los `*_domain_mask_hex` del RolTemplate son decorativos | G-B09 (✗ no calculado) · grep verificado | El B9 declara la representación binaria del rol — o se computa o se retira del contrato | Decisión de la revisión del contrato: computar los cuadrantes desde el RolBitMask real, o deprecar B9 en favor del RolBitMask Base64 (1.09 §7) que SÍ existe |
| **C3** | **Cache distribuido del bundle (H-019)**: Redis comentado → sin invalidación entre instancias ni FastPath compartido | Cargo.toml · §3 | El diseño del FastPath (1.04 §9) y la invalidación post-cambio (1.13 §9.3-9) | Activar `redis 0.28` cuando la infra esté; mientras: documentado como no-operativo (riesgo conocido) |
| **C4** | **Decision log sin grano de decisión**: `aud_event` registra el resultado, no QUÉ política/átomo decidió (el replay forense exige el camino) | 1.04 §14.1 | AU-3 (origen del evento) · la industria registra el decision path | `privilege_atom_audit` ya tiene el grano por átomo (5.01) — falta poblarlo desde el registry en cada evaluación |
| **C5** | **Simulación what-if inexistente** | 1.04 §14.1 ❌ | La industria lo trae de serie (test bench / check con contexto) | Handler `bauth.bitmask.simulate` (P2 — 1.04 §14.4): evaluar un RolBitMask hipotético sin persistir |
| **C6** | **Interop AuthZEN ausente** | 1.04 §14.1 ❌ | OpenID AuthZEN 1.0 (2026) — el estándar de interoperabilidad PDP/PEP | Exponer la evaluación con el shape AuthZEN sobre el socket (P2) — un adaptador, no un motor nuevo |
| **C7** | **ReBAC por recurso no modelado** (owner/shared-with) | 1.04 §14.1 ❌ | La expresividad relacional de la industria | Decisión de arquitectura consciente (el DAG organizacional cubre el caso de uso actual) — se reevalúa si el producto lo exige; NO es deuda, es alcance |

## 5. El balance (lo que el lector debe saber)

- **El motor dual EXISTE y es real** (2.640 líneas, con el pipeline, el closure, la matriz SoD
  y la validación de seeds) — la corrección del escalamiento silencioso está implementada y
  hasta documentada en el shim deprecado.
- **Lo que falta no es el motor: es su ALIMENTO y su OBSERVABILIDAD** — los seeds de átomos
  D2–D13 (C1), el cómputo o retiro de B9 (C2), el cache (C3) y el grano de decisión (C4).
- Las capacidades de conveniencia de la industria (what-if, AuthZEN) son adaptadores P2 sobre
  el motor existente — no reescrituras.

## 6. Referencias e historial

**Del código:** `src/bitmask/*` · `src/domain/{bitmask,inheritance}.rs` (shims) · `Cargo.toml`.
**Del corpus:** 1.04 (§9, §10, §14) · A.03 §6 · A.05 · G-B09 · ADR-009.
**Industria:** [OpenID AuthZEN](https://openid.net/specs/authorization-api-1_0.html) · comparativa 1.04 §14.2.

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Anexo inicial (tipo D+B): el motor real verificado módulo a módulo (src/bitmask/ 2.640 líneas — atom/rol/resolver/regist