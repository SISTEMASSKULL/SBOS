# Motor de Auditoría — *auditar (WORM)*

**Verbo:** auditar · **Frontera:** `src/audit/` · **Estado:** 🔄 esqueleto · **Rige:** ADR-013 · **Contrato:** BA11 (A.42 §8)

---

## 1. Propósito
Punto **único** de emisión de eventos de auditoría forense (append-only / **WORM**). Toda operación
que cambia estado (login, emisión/revocación, decisión de acceso, cambio de rol) deja un evento
inmutable, encadenado por hash. NIST AU-3/AU-12 · ISO 27001 A.8.15.

## 2. El contrato del motor
- **Emisor único:** `emitir_evento(EventoAuditoria) → ()` — todo evento pasa por aquí.
- **WORM:** `bauth.audit_event` append-only + **hash-chain** (cada fila encadena el hash de la anterior).
- **Frontera:** `src/audit/` — nadie escribe la tabla de auditoría por fuera.
- **Fail-closed:** si el evento crítico no puede emitirse, la operación **no se confirma** (no hay acción sin rastro).

## 3. Los códigos que se juntan (frontera: `src/audit/`)
| Archivo actual | Rol | Acción |
|----------------|-----|:------:|
| `src/audit/mod.rs` (~94 líneas) | esqueleto | **desarrollar** el emisor |
| **(falta)** poblador de `audit_event` + hash-chain | quien llena la tabla | ⬜ crear (hoy la tabla existe sin quien la llene) |
| `src/domain/audit_domain.rs` | evaluador de dominio auditoría | coordinar con el Motor de Políticas |

## 4. Manuales de referencia
- **5.01** Auditoría y Trazabilidad — **madre** (§ estructura del `audit_event`, hash-chain, WORM).
- **7.03** Normas (AU-3/AU-12, ISO A.8.15/A.8.17).

## 5. Anexos y contratos
- **A.27** — auditoría: el emisor es un **esqueleto**; `bauth_44` (WORM hash-chain) **sin aplicar** (bloquea el motor de versionado).
- **A.42 §8 (BA11)** — ficha `emitir_evento_auditoria` (firma + cuerpo AU-3, campos forenses, fail-closed).
- **DDL** `bauth_44__gap04_worm_hash_chain.sql` — la migración WORM.

## 6. Estado real (verificado en código)
- 🔄 `src/audit/mod.rs` existe pero es esqueleto (~94 líneas); la tabla superior no tiene quien la llene.
- ⬜ `bauth_44` (WORM hash-chain) **sin aplicar** en la VPS.
- ⚠️ Sin este motor cableado, operaciones críticas ocurren **sin rastro** (riesgo forense).

## 7. Plan para completarlo
1. **Aplicar** `bauth_44` (WORM hash-chain) en la VPS (desbloquea auditoría y el motor de versionado).
2. Desarrollar el **emisor** (`emitir_evento`, BA11/A.42 §8) — fail-closed.
3. Cablear el emisor en cada punto de cambio de estado (login, tokens, decisiones del PDP).

*Portada de motor · ADR-013 · 2026-07-12*
