# Motor de Políticas (PDP) — *autorizar / decidir*

**Verbo:** autorizar · **Frontera:** `src/policy/` *(a crear)* · **Estado:** 🔄 partido + **fail-open** · **Rige:** ADR-013 · **Contrato:** BA3/A.21 · 2.05

---

## 1. Propósito
Punto **único** de decisión de acceso (**PDP** — Policy Decision Point, XACML 3.0 / NIST 800-162
ABAC). Recibe un intento (sujeto + recurso/átomo + contexto), evalúa **todos los dominios** y las
políticas encadenadas, y emite **una** decisión `PERMITIDO | DENEGADO`. bAuth acude aquí para toda
autorización.

## 2. El contrato del motor
- **Trait:** `DomainEvaluator` (`bitmask/registry.rs:83`) — `evaluate() → DomainResult`.
- **Registro:** `DomainRegistry` + `evaluate_all()` (`registry.rs:130/169`) — evalúa los 12 dominios.
- **Cadena de políticas:** `PolicyChainResolver` (`domain/policy_chain.rs`) + `PolicyEngine` (`bitmask/policy.rs`) — resuelve `PolicyRule` por átomo (ABAC/XACML).
- **Fail-closed:** ⚠️ **HOY ES FAIL-OPEN** — `registry.rs`: `None ⇒ DomainResult::permitido`. **Debe ser `⇒ denegado`.** Es el defecto #1 a reparar.

## 3. Los códigos que se juntan (frontera destino: `src/policy/` — hoy DISPERSO)
| Archivo actual | Rol | Acción |
|----------------|-----|:------:|
| `src/bitmask/registry.rs` | `DomainRegistry` + `DomainEvaluator` + `evaluate_all` | **mover** a `src/policy/` |
| `src/bitmask/policy.rs` | `PolicyEngine` + `PolicyRule` | **mover** a `src/policy/` |
| `src/domain/policy_chain.rs` | resolución de cadena | **mover** a `src/policy/` |
| `src/domain/` → `logical` `physical` `geospatial` `financial` `temporal` `network` `delegation` `blockchain` `context` `biometric` `audit_domain` `credential` | los **12 evaluadores de dominio** | **reunir** bajo `src/policy/domains/` |

> El PDP está **partido** entre `src/bitmask/` (registro) y `src/domain/` (evaluadores). Unificarlo en
> `src/policy/` es el corazón de la reparación de este motor.

## 4. Manuales de referencia (leer antes de tocar)
- **2.05** Políticas — **madre** · **1.01** Dominios (los 12) · **2.06** D99 · **2.07** D4-calendario
- **2.08** Menú contextual · **3.01** Riesgo adaptativo (PIP) · **5.02** Blockchain D12 · **7.01** Gobernanza IGA

## 5. Anexos y contratos
- **A.21** — pipeline **fail-open** (el bug: `None ⇒ permitido`). **Crítico.**
- **A.42 §3 (BA3)** — el arreglo fail-closed exacto (1 línea + test).
- **A.26** — Risk Engine `risk.rs` (dead_code, sin cablear).
- **A.43** — dominios como evaluadores; pilar de autorización.

## 6. Estado real (verificado en código)
- ✅ `DomainRegistry` + `DomainEvaluator` + `evaluate_all` (el PDP existe y orquesta).
- ✅ `PolicyChainResolver`/`PolicyEngine` (ABAC/XACML por átomo).
- 🔄 **partido** en dos módulos (`bitmask/` + `domain/`); evaluadores dispersos.
- 🔴 **fail-open** (concede acceso si falta evaluador) — viola fail-closed.
- ⚫ Risk Engine escrito pero sin invocar (A.26).

## 7. Plan para completarlo (orden — es el motor #1 a reparar)
1. **fail-closed** — `registry.rs`: `None ⇒ denegado + alerta + test` (BA3/A.42 §3, 1 línea).
2. Crear `src/policy/` y **mover** `registry.rs` + `policy.rs` + `policy_chain.rs` + los 12 evaluadores.
3. **Cablear** el Risk Engine (A.26) como PIP/dominio de contexto.
4. Verificar RLS (defensa en profundidad, A.22) como complemento del PDP.

*Portada de motor · ADR-013 · 2026-07-12*
