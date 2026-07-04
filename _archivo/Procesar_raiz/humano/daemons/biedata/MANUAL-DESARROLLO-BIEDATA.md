# Manual de Desarrollo — biedata (Data Gateway)
## SBOS Data Gateway: Sovereign Data Exchange Engine
## Manual del Desarrollador · v1.0 · Junio 2026
### SKULL · SBOS · Rust 1.85+ · Prioridad G7-ALTA
### Redactado por biblio-dev (Bibliotecario de Desarrollo)

---

## Prefacio — Cómo leer este manual

Este es el **manual de desarrollo** del daemon `biedata`. No reemplaza la
documentación conceptual (`DAEMON-BIEDATA-00..08`) — la **operacionaliza**: dice
qué construir, en qué orden, con qué criterios de aceptación, y cómo se coordina
con `bkernel` y `bsearch`.

> **biedata es uno de los 3 daemons de datos del SBOS y el de mayor prioridad (G7-ALTA).**
> Es el **único componente del ecosistema autorizado a escribir en las bases de datos
> de negocio.** bKernel escucha pero no escribe: delega en biedata. Por eso biedata
> es el chokepoint de validación, auditoría y escritura.

**Documentos fuente que este manual sintetiza:**

| Documento | Aporta |
|---|---|
| `DAEMON-BIEDATA-00-MAESTRO` | Filosofía "el RPC siempre hace algo", identidad, posición en SBOS |
| `DAEMON-BIEDATA-01-PROTOCOLO-RPC` | Mensajes JSON-RPC, pipeline, directiva de entrega, seguridad |
| `DAEMON-BIEDATA-02-FICHAS` | Modelo de fichas (manifest + validation + task_catalog), SIGUSR1 |
| `DAEMON-BIEDATA-03-FLUJOS` | Flujos completos, escenarios fiscales y multi-dominio |
| `DAEMON-BIEDATA-04-GOBIERNO` | Seguridad, auditoría biedata_db, fronteras, versionado/tiers |
| `DAEMON-BIEDATA-05-INFRA` | Stack Rust, systemd, biedata.toml, ficha SBOS |
| `DAEMON-BIEDATA-06-RESILIENCIA` | Idempotencia, Saga + compensación, circuit breaker |
| `DAEMON-BIEDATA-07-OBSERVABILIDAD` | OTel, métricas, spans, alertas, dashboard |
| `DAEMON-BIEDATA-08-DESCUBRIMIENTO` | manifest como contrato, `biedata.describe`, `dry_run` |
| **CLAUDE.md raíz + ADR-020** | **Interface Dual obligatoria (decisión de gobierno, jun 2026)** |

---

## 1. Identidad del Daemon

| Campo | Valor |
|---|---|
| Nombre | SBOS Data Gateway: Sovereign Data Exchange Engine |
| Daemon | `biedata` |
| Servicio | `biedata.service` |
| Lenguaje | **Rust 1.85+ (Edition 2024, MUSL estático, LTO)** |
| Protocolo | **JSON-RPC 2.0 exclusivamente** |
| Unidad declarativa | **Ficha** (`manifest.yml` + `validation.yml` + `task_catalog.sh`) |
| Directorio fichas | `/etc/bos/blibs/biedata/fichas/<inbound\|outbound>/<nombre>/` |
| Config | `/etc/bos/blibs/biedata/biedata.toml` |
| BD propia | `biedata_db` (auditoría de operaciones — **nunca** datos de negocio) |
| Puerto API externo | `:9470` (`POST /rpc`, HTTPS detrás de Kong) |
| **Socket interno** | **`/run/bos/biedata.sock` (JSON-RPC 2.0 — Interface Dual ADR-020)** |
| Puerto métricas | `:9471` (`GET /metrics`) |
| Puerto healthcheck | `:9472` (`GET /health`) |
| Servidor lógico | S01 (dataserver) |
| Namespace RPC | `biedata.*` (métodos de negocio: `dominio.modelo.accion.vN`) |

---

## 2. La Filosofía Central — El RPC siempre hace algo

**Esta es la idea que gobierna todo el diseño de biedata.**

```
Un paquete JSON-RPC no transporta datos. EJECUTA UNA ACCIÓN.
El paquete no es un sobre. Es una orden de trabajo.
```

El `method` no describe datos: **ordena una tarea**. Cada método es una ficha;
las fichas se encadenan en pipelines; el resultado se acumula a medida que el
pipeline avanza; el caller recibe el paquete final compuesto.

```json
{
  "jsonrpc": "2.0",
  "id":      "req-001",
  "method":  "inventario.producto.insertar.v1",   // QUÉ HACER
  "params":  { "codigo": "CEM-50", ... },          // CON QUÉ DATOS
  "delivery": { "format": "json-rpc" }             // CÓMO ENTREGAR
}
```

biedata es **el Tryton JSON-RPC de TODO el ecosistema**: cualquier sistema que
quiera escribir un dato no toca la BD — invoca un método de biedata, que valida,
ejecuta el pipeline y responde.

---

## 3. Objetivos del daemon

### Objetivo primario

Ser la **aduana soberana de datos**: el único punto por el que entra o sale
cualquier dato de negocio del ecosistema SBOS, validado, auditado y trazado.

### Objetivos verificables

| # | Objetivo | Cómo se verifica |
|---|---|---|
| O1 | **Único escritor de BDs de negocio** | Ninguna otra pieza (ni bKernel) ejecuta SQL/JSON-RPC de escritura contra Tryton/Keycloak/Saleor/OrangeHRM. Todo pasa por `POST /rpc` o el socket. |
| O2 | **Validación previa inviolable** | Un request que no cumple `validation.yml` se rechaza con detalle exacto. Nunca ejecuta tarea con datos inválidos. |
| O3 | **Idempotencia** | El mismo request con la misma `idempotency_key` produce el mismo resultado, sin doble efecto. |
| O4 | **Auditoría ISO 27001** | Toda operación queda en `biedata_db.operations` con `ctx_id`, `trace_id`, resultado. |
| O5 | **Interface Dual (ADR-020)** | Expone CLI + JSON-RPC 2.0 por Unix socket además del `:9470` externo. |
| O6 | **`origin='biedata'` en cada escritura** | bKernel detecta el cambio por WAL sin loops; biedata nunca re-emite escrituras de `origin='bkernel'`. |
| O7 | **Versionado por esquema + tier** | `.v1/.v2` (esquema) y tiers contratados por tenant; el alias sin sufijo resuelve al tier del contrato. |
| O8 | **Pipelines y sagas** | Una llamada puede encadenar tareas multi-dominio con compensación si una falla. |

---

## 4. Interface Dual obligatoria (ADR-020)

> **ADR-020 (jun 2026): todos los daemons y Smarts exponen Interface Dual —
> CLI + JSON-RPC 2.0 sobre Unix socket.** biedata ya hablaba JSON-RPC por HTTP;
> ahora **añade** el socket interno y la CLI. No se elimina nada: se complementa.

### 4.1 Las dos bocas de biedata

```
┌──────────────────── biedata (Rust) ─────────────────────┐
│                                                          │
│  BOCA EXTERNA (gateway)        BOCA INTERNA (ADR-020)     │
│  ───────────────────────       ────────────────────────  │
│  POST /rpc  :9470 (HTTPS)      /run/bos/biedata.sock      │
│  detrás de Kong                JSON-RPC 2.0 sobre         │
│  callers: btax, Core UI,       Unix socket                │
│  bancos, SIAT, ERPs legacy     callers: bKernel, bosctl,  │
│                                otros daemons intra-host    │
│         │                              │                  │
│         └──────────┬───────────────────┘                  │
│                    ▼                                       │
│           Dispatcher JSON-RPC único                       │
│           (Domain / RPC / Transport — ORQUESTA-043 P5)    │
└──────────────────────────────────────────────────────────┘
```

**Regla de oro (ADR-012 + ADR-020):** las llamadas **entre daemons del mismo host
NO usan HTTP** — usan el Unix socket. Cuando **bKernel** necesita que biedata
escriba, llama a `/run/bos/biedata.sock`, nunca al `:9470` vía Kong.

### 4.2 La boca CLI (`bosctl biedata` / `biedata`)

La CLI es la cara humana del mismo dispatcher. Todo método RPC tiene su equivalente CLI:

```bash
biedata describe                          # → biedata.describe (lista fichas y contratos)
biedata call fiscal.factura.emision_completa.v1 --params @factura.json
biedata reload                            # SIGUSR1 — recarga fichas sin reiniciar
biedata health                            # → estado, fichas cargadas, BDs
bosctl biedata contract set --tenant=maya --method=ventas.pedido.generar --tier=v2
bosctl biedata logs --follow
```

**Regla de implementación:** CLI y RPC comparten el **mismo dispatcher y el mismo
modelo de dominio**. La CLI parsea argumentos → arma un mensaje JSON-RPC interno →
lo entrega al dispatcher → formatea la respuesta para humano. **Cero lógica de
negocio duplicada entre CLI y RPC.**

### 4.3 Errores — protocolo vs aplicación (ORQUESTA-043 P6)

JSON-RPC siempre responde **HTTP 200** (o éxito de socket). El error vive en el cuerpo:

| Código | Significado | Origen |
|---|---|---|
| `-32700/-32600/-32601/-32602` | Parse / request inválido / método inexistente / params inválidos | **Protocolo** |
| `-32000` | Error de validación de negocio (`validation.yml` falló) | **Aplicación** |
| `-32002` | Forbidden — tier no contratado / BitMask insuficiente | Aplicación |
| `-32010` | Pipeline falló, saga compensada | Aplicación |

Nunca mezclar: un fallo de validación es `-32000` con HTTP 200, **no** un HTTP 400.

---

## 5. Stack tecnológico

| Componente | Crate / Tecnología | Propósito |
|---|---|---|
| Lenguaje | Rust 1.85+ (Edition 2024) | Daemon principal |
| Async runtime | tokio 1.x | Concurrencia I/O |
| HTTP framework | axum 0.8 | Endpoint `POST /rpc` (boca externa) |
| **Unix socket** | **tokio `UnixListener`** | **Boca interna JSON-RPC (ADR-020)** |
| JSON-RPC | serde_json + tipos propios | Parseo y validación del protocolo |
| CLI | clap 4 | Boca CLI (Interface Dual) |
| PostgreSQL | deadpool-postgres + tokio-postgres | Pools async (`biedata_rw` + `biedata_ro`) |
| Redis | redis-rs (tokio) | Verificación `ctx_id` en Context Registry |
| TLS | rustls 0.23 | HTTPS de la boca externa |
| YAML | serde_yaml | Lectura de fichas (`manifest.yml` + `validation.yml`) |
| Shell | std::process::Command | Ejecución de `task_catalog.sh` |
| Logging | tracing (OTel compatible) | Audit trail con `ctx_id` |
| Config | toml + serde | `biedata.toml` |
| Build | `cargo --release` (MUSL) | Binario estático |

**Versiones (ADR-017):** versión estable verificada, nunca `latest`/beta/RC.

---

## 6. Anatomía de una ficha biedata

Una ficha = un método RPC = una tarea. Tres archivos:

```
/etc/bos/blibs/biedata/fichas/inbound/fiscal_factura_emision/
├── manifest.yml      ← identidad del método, params, pipeline, delivery, tier, Vault
├── validation.yml    ← reglas de aduana (qué se acepta, qué se rechaza)
└── task_catalog.sh   ← la lógica concreta (escribe en la BD de negocio)
```

### 6.1 manifest.yml — el contrato del método (`biedata.describe` lo expone)

```yaml
method:
  name:        "fiscal.factura.emision_completa"
  schema:      "v1"                  # versión de esquema
  description: "Emite una factura completa: lee, valida NIT, registra, devuelve CUF"
  direction:   inbound              # inbound (escribe en el stack) | outbound (exporta)

params:
  invoice_id: { type: string, required: true }
  pais:       { type: string, required: true, enum: ["BO","MX","AR"] }

pipeline:                            # tareas encadenadas; el resultado se acumula
  - step: leer_factura     fn: read_invoice
  - step: leer_cliente     fn: read_party
  - step: validar_nit      fn: validate_nit
  - step: registrar        fn: post_invoice
  - step: libro_ventas     fn: register_sales_book

delivery:
  formats: ["json-rpc", "pdf", "xlsx"]   # cómo puede entregar el resultado

tiers:                              # capacidades/precio/SLA por contrato
  v1: { max_lineas: 50,  sla_ms: 2000 }

vault:
  paths:
    - "secret/tenants/{realm}/biedata/db_rw"

idempotency:
  key_from: ["invoice_id", "pais"]   # de qué params se deriva la clave
```

### 6.2 validation.yml — la aduana

```yaml
rules:
  - field: invoice_id
    must:  exists_in    args: { db: tryton, table: account_invoice, col: id }
    on_fail: "-32000 factura inexistente"
  - field: pais
    must:  in           args: ["BO","MX","AR"]
    on_fail: "-32602 país no soportado"
  - field: monto_total
    must:  gt           args: 0
    on_fail: "-32000 monto inválido"
```

### 6.3 task_catalog.sh — la lógica que escribe

```bash
# fichas/inbound/fiscal_factura_emision/task_catalog.sh
# biedata es el ÚNICO que escribe en tryton_db.

post_invoice() {
    local invoice_id="$1"
    # SIEMPRE estampa origin='biedata' para que bKernel detecte por WAL sin loop
    execute_sql_pg tryton_rw \
      "UPDATE account_invoice SET state='posted', origin='biedata', updated_at=NOW()
       WHERE id='$invoice_id'"
    log_audit_op "fiscal.factura.emision_completa" "$invoice_id" "$CTX_ID" "$TRACE_ID" "ok"
}
```

### 6.4 Recarga sin reiniciar

```bash
kill -SIGUSR1 $(pgrep biedata)      # o: biedata reload
```

biedata revalida todas las fichas en memoria secundaria y reemplaza atómicamente
si la validación pasa. Si falla, mantiene el estado anterior + alerta.

---

## 7. Resiliencia (DAEMON-BIEDATA-06)

| Mecanismo | Qué garantiza |
|---|---|
| **Idempotencia** | `idempotency_key` derivada de params. Repetición → mismo resultado, sin doble efecto. Tabla `biedata_db.idempotency_keys`. |
| **Saga + compensación** | Si el paso N del pipeline falla, se ejecutan las compensaciones de los pasos 1..N-1 en orden inverso (ORQUESTA-043 P9 SAGA). |
| **Circuit breaker** | Si una BD destino falla repetidamente, el breaker abre y rechaza rápido con `-32010` en vez de colgar. |
| **Timeouts** | `request_timeout_ms` por operación; `max_pipeline_steps` acota la profundidad. |
| **dry_run** | `delivery.dry_run=true` ejecuta validación + plan del pipeline sin escribir — para pruebas. |

---

## 8. Seguridad y gobierno (DAEMON-BIEDATA-04)

- **Keycloak único IdP.** biedata no autentica: lee el JWT que Kong inyecta y valida la BitMask 64-bit (bAuth) antes de ejecutar.
- **ctx_id obligatorio** (SBOS-049): `X-SBOS-CtxId` se adjunta a logs, spans y `operations`.
- **Secrets en Vault** (Vault Agent sidecar): ninguna credencial en disco.
- **Fronteras inviolables:**

| # | biedata NUNCA |
|---|---|
| F1 | Guarda datos de negocio en `biedata_db` (solo auditoría) |
| F2 | Ejecuta una tarea con datos que no pasaron `validation.yml` |
| F3 | Llama a otro daemon por HTTP (usa Unix socket — ADR-012) |
| F4 | Re-emite escrituras de `origin='bkernel'` (evita loops) |
| F5 | Expone un tier no contratado a un tenant |
| F6 | Escribe sin estampar `origin='biedata'` |

---

## 9. Observabilidad (DAEMON-BIEDATA-07)

- `/metrics` en `:9471`: `biedata_rpc_requests_total{method,result}`, `biedata_pipeline_duration_ms`, `biedata_validation_rejections_total`, `biedata_saga_compensations_total`.
- Spans OTel con `traceparent` heredado de Kong; `ctx_id` como atributo.
- Logs JSON con `ctx_id` obligatorio.
- `resources/dashboard.json` y `resources/alerts.yml` obligatorios en la ficha SBOS.

---

## 10. Criterios de aceptación

El daemon se considera **certificado** cuando cumple C-01 a C-12:

| # | Criterio | Evidencia |
|---|---|---|
| C-01 | Compila estático MUSL sin warnings | `build-rust.sh ... --release` log con SHA256 |
| C-02 | `POST /rpc :9470` responde JSON-RPC 2.0 válido | request/response capturado |
| C-03 | **Unix socket `/run/bos/biedata.sock` responde el mismo dispatcher** | llamada por socket = misma respuesta que HTTP |
| C-04 | CLI `biedata describe/call/health/reload` operativa | salida en español |
| C-05 | Validación rechaza datos inválidos con `-32000` y HTTP 200 | caso negativo |
| C-06 | Escritura estampa `origin='biedata'` | fila en tryton_db con origin correcto |
| C-07 | Idempotencia: doble request = un solo efecto | `idempotency_keys` + verificación de BD |
| C-08 | Pipeline multi-paso con saga compensa al fallar | traza de compensación |
| C-09 | Auditoría completa en `biedata_db.operations` con `ctx_id`+`trace_id` | SELECT de auditoría |
| C-10 | `/metrics`, `/health`, dashboard y alerts presentes | scrape + archivos |
| C-11 | SIGUSR1 recarga fichas sin perder requests en vuelo | prueba de recarga bajo carga |
| C-12 | **bKernel escribe a través de biedata por el socket** (prueba de integración) | log de llamada bKernel→socket→escritura |

**Evidencia (ADR-030, AA-1):** todo criterio se prueba con log bash real en disco + SHA256.

---

## 11. Plan de desarrollo (fases)

> biedata ya tiene base en `desarrollo/sbos/BiedataAgent/` (Cargo.toml, src). El plan
> parte de ahí. PGE obligatorio (ADR-026): Planner→Generator→Evaluator, MAX_ITER=5 para código de dominio.

### Fase A — Esqueleto e Interface Dual (desbloquea a bKernel)
1. Tipos Rust: `ficha`, `manifest`, `validation`, `RpcRequest`, `RpcResponse`, `RpcError`.
2. Dispatcher único (Domain/RPC/Transport, ORQUESTA-043 P5).
3. **Boca externa** `axum POST /rpc :9470` → dispatcher.
4. **Boca interna** `UnixListener /run/bos/biedata.sock` → mismo dispatcher.
5. **CLI** `clap` → arma mensaje interno → dispatcher.
6. `biedata.toml` + carga de config + Vault paths.
7. `biedata.describe` y `health`.

### Fase B — Motor de fichas y ejecución
8. Loader de fichas (`inbound`/`outbound`), validación de manifest.
9. Motor de `validation.yml` (aduana).
10. Ejecutor de `task_catalog.sh` con variables `$CTX_ID`/`$TRACE_ID`/`$EVENTO_ID`.
11. Motor de pipeline (encadenado + acumulación de resultado).
12. SIGUSR1 reload atómico.

### Fase C — Gobierno, resiliencia y entrega
13. Idempotencia (`idempotency_keys`).
14. Saga + compensación + circuit breaker.
15. Auditoría `biedata_db.operations`.
16. Tiers/contratos por tenant + resolución de alias.
17. Directivas de entrega (json-rpc/pdf/xlsx/csv/xml) + `dry_run`.

### Fase D — Observabilidad y empaquetado
18. `/metrics`, spans OTel, logs JSON con ctx_id.
19. Ficha SBOS (`manifest.yml`, `yaml_engine.yml`, `task_catalog.sh`, `resources/`).
20. Pruebas de integración con bKernel (C-12) y certificación C-01..C-12.

---

## 12. Coordinación entre los 3 daemons de datos

> **Esta sección es idéntica (en el modelo) en los 3 manuales. Es el contrato de coordinación.**

### 12.1 El modelo corregido (decisión HITL, jun 2026)

```
        WAL / Binlog / CDC
   (Postgres, MySQL, SQLServer, Mongo)
                 │
                 ▼
      ┌────────────────────┐   bKernel SOLO ESCUCHA
      │      bKernel        │   · cero superficie: sin puerto/socket/API entrante
      │  (listener+router)  │   · NADIE lo llama
      └─────┬─────────┬─────┘
            │         │
   ESCRIBIR │         │ INDEXAR
 (JSON-RPC  │         │ (Redis Stream
  Unix sock)│         │  bkernel:index_queue)
            ▼         ▼
   ┌────────────────┐  ┌────────────────────┐
   │   biedata      │  │     bSearch        │
   │ ÚNICO escritor │  │ consume + indexa   │
   │ (esta aduana)  │  │ busqueda_universal │
   └───────┬────────┘  └────────────────────┘
           ▼
  Tryton / Keycloak / Saleor / OrangeHRM...
```

### 12.2 Reparto de responsabilidades

| Daemon | Su ficha programa… | ¿Toca BD de negocio? | Interface entrante |
|---|---|---|---|
| **bKernel** | *cuándo* y *qué tarea de biedata* disparar ante cada evento CDC | ❌ nunca | ninguna (cero superficie) |
| **biedata** | *cómo* ejecutar la tarea (validar + escribir) | ✅ **único escritor** | `:9470` (externo) + Unix socket (interno) + CLI |
| **bSearch** | *cómo* indexar lo que bKernel publica | ❌ solo su `busqueda_universal` | WebSocket `wss://` |

### 12.3 Cómo bKernel llama a biedata (lo que biedata debe ofrecer)

bKernel, en el `task_catalog.sh` de su ficha, **no escribe directo**: invoca a biedata
por el **Unix socket** `/run/bos/biedata.sock`:

```bash
# En la ficha de bKernel (NO en biedata):
call_biedata "fiscal.factura.emision_completa.v1" \
  "{ \"invoice_id\": \"$id\", \"pais\": \"$pais\" }"
#   → JSON-RPC 2.0 sobre /run/bos/biedata.sock
```

**Lo que biedata debe garantizar para este flujo:**
- El socket acepta el mismo `method` que la boca externa.
- La respuesta incluye el resultado o el error (`-32000`/`-32010`) para que bKernel decida (reintento, DLQ).
- La escritura estampa `origin='biedata'` → bKernel verá el cambio por WAL pero **no lo re-emitirá** (loop prevention nativo + la regla F4 de biedata).

### 12.4 Dos capas de fichas

| Capa | Vive en | Define |
|---|---|---|
| Ficha **bKernel** | `/etc/bos/blibs/bkernel/servers/<srv>/<app>/` | el puente: evento CDC → qué método de biedata invocar |
| Ficha **biedata** | `/etc/bos/blibs/biedata/fichas/<in\|out>/<nombre>/` | la ejecución real: validar + pipeline + escribir |

### 12.5 Contrato con bSearch (indirecto)

biedata **no habla directamente con bSearch**. biedata escribe en la BD → bKernel
detecta el cambio por WAL → bKernel publica el evento canónico en `bkernel:index_queue`
→ bSearch indexa. biedata solo debe asegurar `origin='biedata'` y datos consistentes
para que el ciclo CDC funcione.

---

## 13. Checklist de acoplamiento al SBOS

| Check | |
|---|---|
| Delega auth a Keycloak — lee JWT de Kong | ✓ |
| Consume BitMask del JWT para autorización | ✓ |
| Lee `X-SBOS-CtxId` y lo adjunta a logs y operaciones | ✓ |
| BD es PostgreSQL (`biedata_db`, solo auditoría) | ✓ |
| Secrets en Vault — ninguna credencial en texto claro | ✓ |
| **No se comunica con otros daemons por HTTP** (Unix socket) | ✓ |
| **Expone Interface Dual: `:9470` + `/run/bos/biedata.sock` + CLL** | ✓ |
| `/metrics` en `:9471`, `/health` en `:9472` | ✓ |
| `resources/dashboard.json` + `resources/alerts.yml` | ✓ |
| Imagen/binario firmado Ed25519 | ✓ |
| Logs JSON con `ctx_id` obligatorio | ✓ |
| Escribe con `origin='biedata'`; ignora `origin='bkernel'` | ✓ |

---

## 14. Trazabilidad

| Sección | Fuente |
|---|---|
| Filosofía e identidad | `DAEMON-BIEDATA-00-MAESTRO` |
| Protocolo RPC, pipeline, entrega | `DAEMON-BIEDATA-01-PROTOCOLO-RPC` |
| Fichas | `DAEMON-BIEDATA-02-FICHAS` |
| Gobierno, tiers, fronteras | `DAEMON-BIEDATA-04-GOBIERNO` |
| Stack, systemd, toml | `DAEMON-BIEDATA-05-INFRA` |
| Resiliencia/saga | `DAEMON-BIEDATA-06-RESILIENCIA` |
| **Interface Dual** | **ADR-020 (CLAUDE.md raíz, jun 2026)** |
| **bKernel→biedata único escritor** | **Decisión HITL 2026-06-01 (corrige docs canónicos)** |
| JSON-RPC servidor/errores/saga | ORQUESTA-043 (Partes 5, 6, 9) |

---

_SKULL · SBOS · MANUAL-DESARROLLO-BIEDATA · v1.0 · Junio 2026 · biblio-dev_
_Prioridad G7-ALTA · biedata es el único escritor de datos de negocio del ecosistema_
