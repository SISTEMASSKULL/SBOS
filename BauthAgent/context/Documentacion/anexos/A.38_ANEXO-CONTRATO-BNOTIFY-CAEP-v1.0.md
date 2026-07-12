# Anexo A.38 — El contrato bAuth↔bNotify (CAEP) en código: el cliente real verificado
## Documento de respaldo de sustentación: qué emite bAuth hacia bNotify y qué falta del lazo

**Tipo:** ANEXO — respaldo de sustentación (tipo **D** verificación de código + **B** industria)
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Respalda a:** MANUAL-BAUTH-BNOTIFY (4.01) · A.16 (gRPC selectivo) · A.26 (riesgo — el lazo de entrada faltante)
**Verificación de código:** `src/engine/caep_client.rs` (260 líneas) + `Cargo.toml` (tonic/prost) — leída 2026-07-11
**Normas base:** OpenID CAEP 1.0 · SSF (Shared Signals Framework) · gRPC · contrato C-BAUTH-004/C-BNOTIFY-001

---

## 1. Propósito

Verificar el estado real del contrato de eventos CAEP hacia bNotify. **Cómo citarlo:** `A.38 §2`.

## 2. El estado real — cliente CAEP implementado (verificado)

| Capacidad | Evidencia | Estado |
|---|---|---|
| Cliente gRPC hacia bNotify | `caep_client.rs` (260 líneas) | ✅ **real** — commit `409095b` |
| Método del contrato | `/bnotify.v1.NotifyDispatcher/ReceiveCaepEvent` (RUTA_METODO) | ✅ |
| Mensaje `CaepEvent` (tags 1-6) | `CaepEventWire` con `#[prost]` derive manual (sin protoc — A.16) | ✅ |
| Transporte | gRPC sobre Unix socket (tonic + tower service_fn) | ✅ — coherente con A.16 (gRPC selectivo inter-daemon) |
| Reintentos | `fn intento()` con lógica de reintento | ✅ |
| Conversión de eventos | `From<&EventoCaep> for CaepEventWire` | ✅ |

**Veredicto:** el contrato de SALIDA (bAuth EMITE señales CAEP hacia bNotify) está
**implementado y funcional** — es de los componentes más completos. bAuth genera las señales
(session-revoked, credential-change…) y las despacha por gRPC.

## 3. Lo que FALTA — el lazo de ENTRADA

| # | Brecha | Exigencia | Prioridad |
|---|---|---|:---:|
| N1 | **Sin lazo de entrada CAEP** — bAuth EMITE señales pero no las CONSUME para su propio scoring (A.26-R3) | Evaluación continua (CAEP bidireccional) | P2 |
| N2 | **Verificar cobertura de los event types** — que los 4 de CAEP 1.0 (session-revoked, credential-change, device-compliance-change, assurance-level-change) se emitan todos | OpenID CAEP 1.0 (verificados en A.02 U6) | P2 |
| N3 | Confirmar el contrato bilateral C-BAUTH/C-BNOTIFY respondido y firmado | El protocolo de contratos | P3 (ya respondido — memoria) |

## 4. Verificación de completitud

| Verificación | Resultado |
|---|---|
| Cliente CAEP (salida) | ✅ real (260 líneas, gRPC/Unix socket) |
| Lazo de entrada | ❌ no existe (N1 — conecta con A.26 riesgo) |
| Coherencia con A.16 | ✅ gRPC selectivo inter-daemon, no JSON-RPC |

## 5. Referencias e historial

**Del código:** `src/engine/caep_client.rs` · `Cargo.toml` (tonic/prost). **Del proyecto:** 4.01 · A.16 · A.26 · contratos C-BAUTH/C-BNOTIFY.
**Industria:** [OpenID CAEP 1.0](https://openid.net/specs/openid-caep-1_0-final.html) · [Shared Signals Framework](https://openid.net/specs/openid-sharedsignals-framework-1_0-final.html)

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Anexo inicial (tipo D+B): el cliente CAEP de SALIDA verificado y real (`caep_client.rs` 260 líneas — gRPC sobre Unix socket con prost manual, reintentos, conversión de eventos; commit 409095b) — de los componentes más completos. Brechas: N1 sin lazo de ENTRADA (bAuth emite pero no consume CAEP para su scoring — conecta con A.26-R3), N2 verificar los 4 event types, N3 contrato bilateral. |
