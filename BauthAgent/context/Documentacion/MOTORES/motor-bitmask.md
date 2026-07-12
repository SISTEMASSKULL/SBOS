# Motor BitMask — *calcular privilegios*

**Verbo:** calcular privilegios · **Frontera:** `src/bitmask/` · **Estado:** ✅ robusto (~2.640 líneas) · **Rige:** ADR-013 · **Decisión:** ADR-009

---

## 1. Propósito
Punto **único** del cálculo algebraico de privilegios: BitMask Dual 64-bit (label + one-hot),
herencia por DAG con closure table, SoD (conflictos), evaluación < 0.5 ns. Es el motor que dice
**qué puede hacer** un rol sobre un átomo; el Motor de Políticas lo consulta al decidir.

## 2. El contrato del motor
- **Núcleo:** `RolBitMask` / `AtomBitMask` (`atom.rs`, `rol.rs`) · resolución (`resolver.rs`, `fastpath.rs`).
- **Herencia:** closure table (`closure.rs`) — DAG OR.
- **SoD:** matriz de conflictos (`conflict.rs`).
- **Fail-closed:** bit no presente ⇒ sin privilegio (deny por ausencia).

## 3. Los códigos que se juntan (frontera: `src/bitmask/`)
| Archivo | Rol | Nota |
|---------|-----|------|
| `atom.rs` `rol.rs` `resolver.rs` `fastpath.rs` `closure.rs` `conflict.rs` `catalog.rs` `serializer.rs` `mod.rs` | motor de privilegios | ✅ en frontera |
| ⚠️ `registry.rs` `policy.rs` | **son del Motor de Políticas** (DomainRegistry, PolicyEngine) | **mover** a `src/policy/` (limpiar frontera — ver motor-politicas) |

> Único ajuste: `registry.rs` y `policy.rs` viven aquí por historia, pero pertenecen al **Motor de
> Políticas**. Moverlos deja cada motor en su frontera (ADR-013).

## 4. Manuales de referencia
- **1.04** BitMask — **madre** · **1.02** Verbos · **1.03** Átomos · **1.01** Dominios
- **1.06** Identidad D00 · **1.07** Atributos · **1.08** UserTemplate · **1.09** Roles · **1.10** Aplicaciones

## 5. Anexos y contratos
- **A.03** BitMask (la decisión ADR-009, materialización) · **A.01** RolTemplate · **A.02** UserTemplate · **A.05** Átomos.

## 6. Estado real (verificado en código)
- ✅ Motor vivo y robusto: ~2.640 líneas, ~34 importadores, ~62 tests. Lo mejor construido de bAuth.
- 🔄 Único pendiente estructural: extraer `registry.rs`/`policy.rs` al Motor de Políticas.

## 7. Plan
1. Mantener (es referencia de calidad).
2. Al reparar Políticas, **mover** `registry.rs` + `policy.rs` a `src/policy/` (deja BitMask puro).

*Portada de motor · ADR-013 · 2026-07-12*
