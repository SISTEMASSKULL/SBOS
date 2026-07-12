# Anexo A.16 — Protocolos: por qué JSON-RPC 2.0 + WebSocket sobre Unix socket — y NO REST, gRPC ni GraphQL
## Documento de respaldo de sustentación: la decisión justificada contra la industria, verificada en el código real

**Tipo:** ANEXO — respaldo de sustentación (tipo **C** justificación de decisión + **B** industria + **D** verificación de código)
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Respalda a:** MANUAL-REFERENCIA-API (9.02 §2-§3, §16-§17) · ADR-002/ADR-020 (A.13) · CLAUDE del daemon (Interface Dual) · MANUAL-SEGURIDAD (2.09)
**Verificación de código:** `src/server/{unix_socket,websocket,jsonrpc}.rs` (555 líneas) + `src/main.rs` (registro de métodos) + `Cargo.toml` — leída 2026-07-11
**Normas/especificaciones:** JSON-RPC 2.0 · OpenRPC · RFC 6455 (WebSocket) · SBOS-050 P9 · SBOS-049 · ADR-020

---

## 1. Propósito

Dar el **justificativo completo** — el que faltaba documentado — de la decisión de protocolo de
bAuth: por qué la superficie es JSON-RPC 2.0 + WebSocket sobre Unix socket y no API REST, gRPC
o GraphQL; con la comparativa de industria, la verificación de lo implementado y las brechas.
**Cómo citarlo:** `A.16 §3` (la comparativa) · `A.16 §5` (verificación de código).

## 2. Los requisitos que gobiernan la decisión (antes de comparar)

Una comparación de protocolos sin requisitos es opinión. Los de bAuth son:

| # | Requisito | Fuente |
|---|---|---|
| R-1 | **HTTP/TCP está VETADO entre daemons** — solo Unix socket o WebSocket | SBOS-050 P9 (norma irrenunciable del ecosistema) |
| R-2 | **Dos consumidores heterogéneos** sobre la misma superficie: humanos (CLI `bauthctl`, UI — interactivo) y daemons/agentes IA (programático) | ADR-002 |
| R-3 | Los **agentes IA son consumidores de primera clase**: el protocolo debe ser legible/generable sin toolchain de compilación | ADR-002 (explícito) |
| R-4 | **Soberanía y superficie mínima**: sin puertos TCP adicionales, sin exposición de red interna | 2.09 · SBOS-050 |
| R-5 | Comandos **imperativos de control plane** (issue/validate/revoke/evaluate) — no navegación de recursos ni consultas de grafos de datos | La naturaleza de la superficie (9.02 §5-§13) |
| R-6 | `ctx_id` en toda operación y errores estructurados en español | SBOS-049 · DOC-SBOS-001 |

## 3. La comparativa — contra la industria (verificada 2026-07-11)

| Criterio | REST (OpenAPI) | gRPC (protobuf/HTTP2) | GraphQL | **JSON-RPC 2.0 (elegido)** |
|---|---|---|---|---|
| Transporte | **HTTP — vetado por R-1** | HTTP/2 (adaptable a UDS con esfuerzo) | HTTP — vetado R-1 | **Transport-agnostic por especificación** (sockets, in-process, HTTP) — encaja Unix socket nativo |
| Naturaleza | Recursos/verbos HTTP — impedance mismatch con comandos (R-5) | RPC ✅ | Consultas de grafos de datos — para frontends data-driven, no control plane | RPC puro ✅ — el modelo mental exacto de la superficie |
| Consumidor humano/CLI | curl-able pero vetado | ❌ exige protobuf toolchain — inapropiado para CLI humana | ❌ query language | ✅ un `printf` a `nc -U` (9.02 §3) — depurable a mano |
| Consumidor agente IA (R-3) | JSON ✅ pero HTTP | ❌ binario, esquemas compilados | parcial | ✅ **JSON puro: legible y generable por un LLM sin toolchain** |
| Rendimiento local | HTTP localhost ~0.1–1 ms | El más rápido EN RED (5–10× vs REST, benchmarks 2026) | overhead de parsing | **Unix socket ~0.01–0.05 ms** — al eliminar la pila de red (R-4), la ventaja de gRPC se disuelve para IPC local |
| Especificación machine-readable | OpenAPI 3.1 | .proto | SDL | **OpenRPC** (el OpenAPI de JSON-RPC) — ver brecha §6-F1 |
| Veredicto de la industria | "para APIs públicas" | "para microservicios internos EN RED cuando controlas ambos extremos" | "para necesidades de datos del cliente" | La industria coincide: para APIs internas, RPC > REST; y el transporte local anula el argumento de rendimiento de gRPC |

**La decisión, en una frase:** con HTTP vetado (R-1), el rendimiento resuelto por el transporte
(Unix socket) y dos consumidores donde uno es humano y otro es un agente IA (R-2/R-3), JSON-RPC
2.0 es el único candidato que cumple TODOS los requisitos; gRPC y REST fallan R-1/R-3, GraphQL
falla R-5.

**Y la prueba de que no es dogma:** bAuth SÍ usa gRPC donde sus fortalezas aplican — el cliente
CAEP hacia bNotify (`tonic`+`prost` en Cargo.toml, sobre Unix socket) para el contrato binario
inter-daemon de eventos (C-BAUTH-004). La decisión es por-caso contra requisitos: JSON-RPC para
la superficie de control; gRPC para el stream de señales tipado entre daemons.

## 4. La Interface Dual — la pieza que ningún protocolo único daba

El requisito R-2 se resuelve con **un solo socket que multiplexa dos vías** (ADR-002/ADR-020):
WebSocket RPC (humanos — interactivo, RFC 6455) y JSON-RPC 2.0 crudo (daemons/agentes), ambos
sobre `/run/bos/bauth.sock` (0660, grupo `bosagent`). Un punto de administración, cero puertos.

## 5. Verificación de código — lo que bAuth HACE hoy (evidencia)

| Capacidad | Evidencia real |
|---|---|
| **Discriminación de protocolo por primer byte** | `unix_socket.rs:10-12` — `'G'` → WebSocket (HTTP GET upgrade) · `'{'` → JSON-RPC crudo; conexión unificada (H-018) |
| Anti-DoS en el socket | Buffer con límite configurable `ctx.max_request_bytes` (M-03) — `unix_socket.rs:94` |
| Servidor completo | 555 líneas: `unix_socket.rs` (207) + `websocket.rs` (208) + `jsonrpc.rs` (115, dispatcher) |
| **Superficie registrada ≈151 métodos** | 114 inline (`grep -c 'dispatcher.register("'` = 114) + 37 por 6 lotes (`all_{scim,self,device,role_lifecycle,protocol,kong}_handlers` — main.rs 610-634) |
| Errores JSON-RPC estructurados en español | -32600/-32601/-32602/-32603 (9.02 §16) — DOC-SBOS-001 |
| SDK sin promesas rotas | `sdk/mod.rs` → todos sus métodos existen registrados (9.02 §15) |
| gRPC selectivo | `caep_client.rs` — tonic sobre Unix socket, mensajes prost a mano (sin protoc) |

## 6. Lo PARCIAL y lo que FALTA — pero la industria y las normas exigen

| # | Estado | Brecha específica | Qué exige la industria | Resolución |
|---|:---:|---|---|---|
| F1 | ❌ | **Sin especificación OpenRPC** — el esquema params/result por método solo existe implícito en el código | La industria publica su superficie machine-readable (OpenAPI/OpenRPC): validación automática, clientes generados, try-it | **P1** (9.02 §17-R1): generar `openrpc.json` de los ≈151 métodos — es EL paso de categoría de la superficie |
| F2 | ⚠️ | **Colisión `bauth.token.validate`** — registrado dos veces (inline + lote kong); el segundo pisa al primero EN SILENCIO | Un registro de superficie con dueño único por método; detección de colisiones en el arranque | P2 (9.02 §17-R3): decidir dueño + hacer que `dispatcher.register` falle ruidosamente ante duplicado (fail-closed) |
| F3 | ⚠️ | `domain_remaining.rs` (3 consultas BD) **sin registro** — código sin puerta (último huérfano) | Ejecución sin superficie = código muerto o brecha de gobierno | Confirmar naturaleza y montar o retirar (9.02 §14) |
| F4 | ⚠️ | `bauth.debug.methods` sin gate — discovery abierto | El discovery en producción se protege (enumeración de superficie) | P2 (R4): exigir átomo de administración |
| F5 | 📄 | Params/result de los ~30 métodos más usados sin documentar (mientras llega F1) | Documentación de referencia por método | P3 (R5) — anexo de 9.02 |

## 7. Referencias e historial

**Del proyecto:** ADR-002/ADR-020 (íntegros en A.13) · 9.02 §2-§3/§14-§18 · SBOS-050 P9 · `src/server/` · `Cargo.toml`.
**Industria (2026-07-11):** [JSON-RPC 2.0 spec](https://www.jsonrpc.org/specification) (transport-agnostic) · [OpenRPC](https://spec.open-rpc.org/) · [gRPC vs REST vs GraphQL — benchmarks 2026](https://oneuptime.com/blog/post/2026-02-06-grpc-rest-graphql-performance-otel-benchmarks/view) · [Comparativa de arquitecturas 2026](https://dasroot.net/posts/2026/04/graphql-vs-rest-vs-grpc-api-architecture-comparison-2026/) · [RPC para APIs internas](https://www.tatethurston.com/articles/rest-vs-graphql-vs-rpc) · [Unix domain sockets — rendimiento IPC](https://www.baeldung.com/linux/ipc-performance-comparison) · [UDS para microservicios](https://medium.com/@sanathshetty444/beyond-http-unleashing-the-power-of-unix-domain-sockets-for-high-performance-microservices-252eee7b96ad)

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Anexo inicial (tipo C+B+D): los 6 requisitos que gobiernan la decisión (HTTP vetado SBOS-050 P9, dos consumidores con agentes IA de primera clase, soberanía, control plane imperativo), la comparativa completa REST/gRPC/GraphQL/JSON-RPC contra esos requisitos con respaldo de industria (el transporte Unix socket ~0.01–0.05 ms disuelve la ventaja de gRPC local; JSON-RPC transport-agnostic por especificación), la prueba de no-dogma (gRPC selectivo para CAEP), la Interface Dual verificada en código (discriminación por primer byte + anti-DoS + 555 líneas + ≈151 métodos) y las 5 brechas con exigencia y prioridad (OpenRPC P1, colisión token.validate con registro fail-closed, huérfano restante, gate de discovery, docs por método). |
