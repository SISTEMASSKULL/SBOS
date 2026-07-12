# Anexo A.26 — El Risk Engine en código: escrito pero SIN CABLEAR (`#![allow(dead_code)]`)
## Documento de respaldo de sustentación: el estado crudo del motor de riesgo y los modelos de la industria

**Tipo:** ANEXO — respaldo de sustentación (tipo **D** verificación de código + **B** industria)
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Respalda a:** MANUAL-RIESGO-ADAPTATIVO (3.01) · A.01 §17.2-B17 (contexto adaptativo del rol) · A.02 §B13 (perfil de riesgo del usuario)
**Verificación de código:** `src/domain/risk.rs` (95 líneas) + búsqueda de invocación en el pipeline — leída 2026-07-11
**Normas base:** NIST SP 800-207 §4 (evaluación continua) · OpenID CAEP · UEBA · RFC 9470 (step-up por riesgo)

---

## 1. Propósito

Estado crudo del motor de riesgo (ITDR): qué existe en código y por qué NO opera todavía.
**Cómo citarlo:** `A.26 §2` (el estado crudo) · `A.26 §4` (los modelos de la industria).

## 2. El estado crudo — escrito pero código muerto (evidencia dura)

`src/domain/risk.rs` (95 líneas — "H-12 Risk Scoring Engine · NIST SP 800-207") **existe y está
diseñado**: define `RiskContext` (user, IP, device_fingerprint, hora, known_device/location,
VPN, Tor, intentos/hora) y `RiskScore` (total + identity/device/network/behavioral + flags).

**Pero la línea 3 del archivo lo dice todo:**

```rust
#![allow(dead_code)]      // ← el compilador confirma: nadie lo llama
```

**Verificación de invocación:** `risk_score` aparece solo como (a) claim OPCIONAL del JWT
(`jwt_builder.rs` — siempre `None` por defecto) y (b) campo evaluable en tests de política. **El
motor `risk.rs` NO se invoca desde el pipeline** (`registry.rs`/`logical.rs` — 0 menciones). Es
un motor completo, escrito, y **desconectado** — la clase de brecha "tabla/motor existe ✅,
integrado/operativo ❌" que la carta rectora (0.00 §6) señala como el patrón recurrente de bAuth.

## 3. La consecuencia — el pilar ITDR es L2, no L3

| Capa | Estado |
|---|---|
| El motor de scoring (4 factores) | ✅ escrito (`risk.rs`) — L2 |
| Invocación desde el pipeline | ❌ **no cableado** (`dead_code`) |
| Evaluación continua (post-login) | ❌ no existe |
| Señales CAEP consumidas (el cliente CAEP emite hacia bNotify, pero no hay lazo de entrada) | ❌ |
| El JWT lleva `risk_score` | ⚠️ el claim existe, siempre `None` — sin fuente |

Coincide con la carta rectora (0.00 §8 pilar IV ITDR): *"Cablear el motor, evaluación
continua/CAE, conductual, feeds"* — la brecha declarada, aquí confirmada con `#![allow(dead_code)]`.

## 4. Los modelos de la industria (lo que el scoring debe hacer)

| Modelo | Qué aporta |
|---|---|
| **Reglas + umbrales** (lo que `risk.rs` ya tiene) | Score 0-1 por factores; umbral dispara step-up/block — el mínimo viable |
| **UEBA (behavioral)** | Baseline de comportamiento (horarios, IPs, velocidad) → desviación = riesgo; el `A.02 §B13` lo modela en el UserTemplate |
| **CAEP / evaluación continua** | Señales en tiempo real (session-revoked, device-compliance-change) reevalúan el acceso post-login — bAuth ya EMITE CAEP (A.38) pero no CONSUME para su propio scoring |
| **Feeds de amenazas** | IPs/dispositivos maliciosos externos | 

## 5. Lo que FALTA — específico

| # | Brecha | Exigencia | Prioridad |
|---|---|---|:---:|
| **R1** | **Cablear `risk.rs` al pipeline** — quitar `dead_code`, invocar en D8 (contexto) | NIST 800-207 §4 · el propio diseño | **P1** (es EL paso L2→L3 de ITDR) |
| R2 | **Poblar el `risk_score` del JWT** desde el motor (hoy siempre None) | El claim ya existe, sin fuente | P1 |
| R3 | **Evaluación continua post-login** (reevaluar con señales CAEP entrantes) | 800-207 §4 · CAEP | P2 |
| R4 | **Baseline UEBA** conectado al B13 del UserTemplate | A.02 §B13 | P2 |
| R5 | **Feeds de amenazas** | ITDR maduro | P3 |

## 6. Verificación de completitud

| Verificación | Resultado |
|---|---|
| Motor escrito | ✅ `risk.rs` (4 factores + flags) |
| Cableado | ❌ **`#![allow(dead_code)]`** — hallazgo crudo confirmado |
| Coherencia con 0.00 §8 pilar IV | ✅ confirma la brecha declarada con evidencia |
| Coherencia con A.01/A.02 | ✅ B17 (rol) y B13 (usuario) esperan este motor operativo |

## 7. Referencias e historial

**Del código:** `src/domain/risk.rs` · `src/domain/jwt_builder.rs`. **Del proyecto:** 3.01 · 0.00 §8 · A.01 §B17 · A.02 §B13.
**Industria:** [NIST SP 800-207 §4](https://csrc.nist.gov/pubs/sp/800/207/final) · [OpenID CAEP](https://openid.net/specs/openid-caep-1_0-final.html) · UEBA · RFC 9470.

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Anexo inicial (tipo D+B): el estado crudo del Risk Engine — `risk.rs` (95 líneas, 4 factores + flags) **existe pero marcado `#![allow(dead_code)]`**: escrito y desconectado del pipeline (0 invocaciones en registry.rs/logical.rs; el `risk_score` del JWT siempre None). Confirma con evidencia dura la brecha declarada del pilar ITDR (0.00 §8: "cablear el motor"). Los modelos de industria (reglas+umbrales/UEBA/CAEP/feeds) y 5 brechas (R1 cablear = P1 el paso L2→L3, R2 poblar el claim, R3 evaluación continua, R4 UEBA, R5 feeds). |
