# JSON-RPC — Resumen Ejecutivo del Manual Completo
## 9 documentos sintetizados para consulta rápida del agente

**Versión del manual:** 2.0
**Aplicación en SBOS:** protocolo de comunicación del daemon `bos` — todos los
métodos `bos.*` en `internal/server/jsonrpc.go` siguen este estándar.
**Documentos fuente:** JSON-RPC-01.md … JSON-RPC-09.md (en esta misma carpeta)

---

## Parte 1 — Fundamentos del protocolo

JSON-RPC es un protocolo de llamada a procedimientos remotos que usa JSON como serialización. El cliente invoca **procedimientos**, no accede a recursos. En lugar de `GET /ventas/42/confirmar`, el cliente llama `model.venta.confirmar` con el ID como parámetro.

**Estructura del mensaje de petición:**
```json
{
  "id": 1,
  "method": "model.venta.confirmar",
  "params": [42, {"company": 1, "lang": "es"}]
}
```

**Estructura de respuesta exitosa:**
```json
{"id": 1, "result": true, "error": null}
```

**Estructura de respuesta con error:**
```json
{"id": 1, "result": null, "error": {"code": -32000, "name": "ValidationError", "message": "Stock insuficiente"}}
```

**Convenciones de nomenclatura del bos:**
```
bos.<modulo>.<recurso>.<accion>
bos.ficha.repair          → reparar una ficha
bos.k8s.node.cordon       → aislar un nodo
bos.ctx.device.register   → registrar dispositivo en Context Plane
bos.query.system          → saga de consulta del sistema completo
```

**Transporte:** HTTP POST a `/rpc/` o socket Unix en `/run/bos/bos.sock`. El daemon bos acepta ambos.

---

## Parte 2 — Autenticación y sesiones

El flujo de sesión tiene tres pasos: login → llamadas autenticadas → logout.

**Login:**
```json
Request:  {"id":1, "method":"common.auth.login", "params":["usuario",{"password":"clave"}]}
Response: {"id":1, "result":[7, "a3f8c2d1e9b4567890abcdef12345678"], "error":null}
          ─ user_id=7  ─ session_token="a3f8c2..."
```

**Header de autorización para llamadas autenticadas:**
```
Authorization: Basic base64(username:user_id:session_token)
```

En el daemon bos, el token proviene del ctx_id del Context Plane (F5.x). Los métodos de la categoría 2 y 3 del `action_catalog.yml` requieren token válido; los de categoría 1 (lectura) no.

**Timeout de sesión:** 8 horas para DeviceContext, 12 horas para SessionContext (ISO 27001 A.9.4.2).

---

## Parte 3 — Contexto de ejecución y CRUD

El **contexto** es el último elemento del array `params` en toda llamada autenticada:
```json
{"method": "model.X.read", "params": [[1,2,3], ["campo1","campo2"], {"company": 1, "lang": "es"}]}
```

**Los 6 métodos base de cualquier modelo:**

| Método | Firma | Retorna |
|---|---|---|
| `model.X.create` | `([{valores}], ctx)` | `[ids]` |
| `model.X.read` | `([ids], [campos], ctx)` | `[{...}]` |
| `model.X.write` | `([ids], {valores}, ctx)` | `true` |
| `model.X.delete` | `([ids], ctx)` | `true` |
| `model.X.search` | `(dominio, offset, limit, order, ctx)` | `[ids]` |
| `model.X.search_read` | `(dominio, [campos], offset, limit, order, ctx)` | `[{...}]` |

En el daemon bos, los métodos `bos.*` no siguen el patrón CRUD sino el patrón de **sagas y comandos**, pero el contexto siempre va al final del array de params.

---

## Parte 4 — Cadena de eventos y máquinas de estado

Una **cadena de eventos** es una secuencia de llamadas RPC donde el resultado de cada llamada habilita la siguiente. Las transiciones de estado tienen nombres verbales:

```
borrador → confirmar() → confirmado → facturar() → facturado → pagar() → pagado
```

En el daemon bos, la máquina de estados de las fichas (18 estados en `internal/state/manager.go`) sigue este patrón. Los métodos JSON-RPC `bos.ficha.*` disparan transiciones:

```
PENDIENTE → bos.ficha.install → INSTALANDO → (ok) → INSTALADA
INSTALADA → bos.ficha.repair  → REPARANDO  → (ok) → INSTALADA
INSTALADA → bos.ficha.upgrade → ACTUALIZANDO → (ok) → INSTALADA
```

**Wizards (operaciones multi-paso):**
```json
wizard.X.create → wizard.X.execute(paso1) → wizard.X.execute(paso2) → wizard.X.delete
```

---

## Parte 5 — Arquitectura del servidor

El servidor JSON-RPC tiene 4 capas:

```
HTTP/Socket → Dispatcher → Dominio → Store
                │
                ├── Parsear JSON
                ├── Autenticar (verificar token)
                ├── Autorizar (verificar permisos del rol)
                ├── Resolver método → función handler
                └── Llamar handler(params, ctx)
```

**Registro de métodos en Go** (patrón de `internal/server/jsonrpc.go`):
```go
type Handler func(params []json.RawMessage, ctx RPCContext) (interface{}, error)

func (s *Server) Register(method string, h Handler) {
    s.handlers[method] = h
}

// Uso:
s.Register("bos.ficha.repair", s.rpcFichaRepair)
s.Register("bos.query.system", s.rpcQuerySystem)
```

**Principio de capas:** la lógica de negocio no importa nada de HTTP o JSON. Los handlers del dispatcher reciben parámetros tipados y devuelven valores Go — el marshaling JSON es responsabilidad del dispatcher.

---

## Parte 6 — Errores en producción

**Códigos de error estándar del bos:**

| Código | Nombre | Cuándo usarlo |
|---|---|---|
| -32700 | ParseError | JSON inválido |
| -32600 | InvalidRequest / Unauthorized | Sin token válido |
| -32601 | MethodNotFound | Método no registrado |
| -32602 | InvalidParams | Parámetros incorrectos |
| -32000 | ApplicationError | Error de negocio genérico |
| -32001 | ContextExpired | ctx_id expirado (F5.x) |
| -32002 | FichaNotFound | ficha_id no existe |

**Regla crítica:** los errores de negocio retornan HTTP 200 con `error` en el body — nunca 4xx/5xx. Los stack traces nunca llegan al cliente.

**Errores con contexto** (ADR-003 R2):
```go
// Nunca:
return nil, err
// Siempre:
return nil, fmt.Errorf("bos.ficha.repair: ficha %s: %w", fichaID, err)
```

**Logging estructurado** (ISO 27001 A.8.15):
```json
{"event":"rpc_call","method":"bos.ficha.repair","user_id":7,"duration_ms":4523,"error":null,"traceparent":"00-4bf9..."}
```

---

## Parte 7 — Arquitectura híbrida e integraciones

El daemon bos actúa como servidor JSON-RPC **y** como cliente de otros servicios. El patrón adaptador permite integrar servicios que no hablan JSON-RPC nativamente:

```
bosctl → [JSON-RPC] → daemon bos → [JSON-RPC] → Tryton/bCompass
                                 → [HTTP REST] → Keycloak
                                 → [K8s API]   → kubectl equivalente
                                 → [Socket]    → PostgreSQL
```

Para el bos específicamente: `internal/server/jsonrpc.go` es el servidor (acepta llamadas de bosctl), y `internal/domain/`, `internal/k8s/`, `internal/context/` son los clientes hacia los subsistemas.

---

## Parte 8 — Ecosistema y estrategia de adopción

Tres categorías de integración:

| Categoría | Descripción | Ejemplo |
|---|---|---|
| A — Nativo | Ya habla JSON-RPC | Tryton, bCompass |
| B — Nuevo | Se construye bajo el estándar | Todo código nuevo del bos |
| C — Legado | Envolver con Fachada-RPC | OrangeHRM, sistemas bancarios |

**Guardia de dominio** (crítico para biaos): el daemon bos es Categoría B para infraestructura (`bos.*`). Los módulos de negocio (`tryton.*`, `bcompass.*`) son Categoría A — biaos no los toca.

---

## Parte 9 — Orquestación multi-motor y sagas

El **orquestador** ejecuta flujos que involucran múltiples motores JSON-RPC en secuencia, con compensación automática en caso de fallo.

**Formato de saga YAML** (análogo a `action_catalog.yml`):
```yaml
id: repair-ficha
pasos:
  - id: pre-diagnose
    motor: bos
    metodo: bos.query.repair
    params: {ficha_id: "{{ficha_id}}"}
    guardar_como: diagnosis

  - id: execute-repair
    motor: bos
    metodo: bos.ficha.repair
    params: {ficha_id: "{{ficha_id}}"}
    compensar:
      metodo: bos.ficha.state.reset
      params: {ficha_id: "{{ficha_id}}", target: "DEGRADADA"}

  - id: verify-recovery
    motor: bos
    metodo: bos.health.ficha.probe
    params: {ficha_id: "{{ficha_id}}"}
```

**Principios de las sagas en el bos** (de `internal/installer/saga.go` y `internal/installer/compensator.go`):
- Los pasos sin `depende_de` se ejecutan en paralelo
- La compensación se ejecuta en **orden inverso** al fallo
- El SagaEngine persiste en `/var/lib/bos/ai/sagas/` para recovery ante crash
- El `traceparent` W3C se propaga a cada llamada del saga

**Checklist de producción para sagas:**
```
[ ] Toda saga tiene timeout explícito por paso
[ ] Los pasos de notificación tienen on_failure: continue
[ ] Las compensaciones están probadas con TestSagaEngine_CompensatesOnCrash
[ ] El traceparent se propaga en cada llamada RPC de la saga
```

---

## Referencia rápida — Métodos del daemon bos implementados

### Ya implementados (`internal/server/jsonrpc.go` actual)

```
bos.ficha.install      bos.ficha.update      bos.ficha.remove
bos.ficha.repair       bos.ficha.probe       bos.ficha.events
bos.state.read         bos.state.transition  bos.release.check
bos.health.check       bos.bootstrap.status  bos.ai.ask
```

### A implementar en Fase 6 del plan

```
bos.ficha.scale        bos.ficha.pause       bos.ficha.state.reset
bos.ficha.upgrade      bos.k8s.node.cordon   bos.k8s.node.drain
bos.k8s.node.uncordon  bos.k8s.pod.restart   bos.k8s.rollout.undo
bos.maintenance.start  bos.maintenance.cancel bos.ctx.device.register
bos.ctx.promote        bos.ctx.invalidate    bos.ctx.list
bos.ctx.stats          bos.query.system      bos.query.repair
bos.query.vdi          bos.query.tenant      bos.query.node
bos.query.context      bos.ai.diagnose       bos.ai.explain
```

---

## Dónde leer más

| Necesidad | Documento |
|---|---|
| Implementar un nuevo método RPC | JSON-RPC-05 (dispatcher) + JSON-RPC-06 (errores) |
| Agregar autenticación a un método | JSON-RPC-02 (auth) + ADR-006 (RBAC) |
| Implementar una saga nueva | JSON-RPC-09 (orquestación) + internal/installer/saga.go |
| Integrar un servicio externo | JSON-RPC-07 (híbrida) + JSON-RPC-08 (ecosistema) |
| Agregar al action_catalog.yml | action_catalog.yml + INFORME-CIERRE-F10.0 |

---

*JSON-RPC-RESUMEN-EJECUTIVO.md v1.0 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
*Fuente: JSON-RPC-01..09.md — Manual completo en esta misma carpeta*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
