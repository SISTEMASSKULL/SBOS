# Manual de Desarrollo — bKernel (Data Kernel)
## bKernel: Listener CDC Soberano · Motor de Escucha y Enrutamiento de Tareas
## Manual del Desarrollador · v1.0 · Junio 2026
### SKULL · SBOS · Rust 1.85+
### Redactado por biblio-dev (Bibliotecario de Desarrollo)

---

## Prefacio — Lo que este manual CORRIGE del documento canónico

Este manual operacionaliza la construcción de `bkernel`. Recoge **decisiones de
gobierno tomadas por el HITL (2026-06-01)** que **corrigen** el documento
`BKERNEL-DEFINICION-CANONICA.md` (v3.0, mayo 2026). Aquel documento se escribió
sin experiencia operativa; con la experiencia acumulada, estas decisiones lo
perfeccionan. **Donde este manual y el canónico difieran, manda este manual.**

> **Las 3 correcciones al canónico:**
>
> 1. **bKernel NO escribe en bases de datos de negocio.** El canónico §5/§8 muestra
>    `task_catalog.sh` ejecutando `call_jsonrpc tryton`, `call_rest_api keycloak`,
>    `execute_sql_pg saleor_db` directamente. **Eso queda superado.** bKernel solo
>    **escucha** y **delega toda escritura en biedata** vía JSON-RPC sobre Unix socket.
>
> 2. **Los eventos sin ficha NO se descartan en silencio.** El canónico §12 dice
>    "descartar + log debug". **Eso queda superado.** Toda escucha nueva o divergente
>    se **registra y retiene** en un catálogo de conocimiento en `bkernel_db`.
>
> 3. **bKernel queda EXCEPTUADO de la Interface Dual (ADR-020).** Como nadie lo llama
>    (cero superficie de ataque, Frontera F1), no expone JSON-RPC entrante. Su control
>    es por `bosctl`. La Interface Dual aplica a biedata y bSearch, no a bKernel.

**Lo que del canónico SIGUE intacto:** los 4 archivos maestros del Core, el modelo
de fichas declarativas, el binario Rust 1.85+, los mecanismos CDC por motor, el
loop prevention nativo, la gestión de secretos en Vault, y las Fronteras F1-F11.

---

## 1. Identidad del Daemon

| Campo | Valor |
|---|---|
| Nombre | bKernel — Data Kernel · Listener CDC Soberano |
| Daemon | `bkernel` |
| Servicio | `bkernel.service` |
| Lenguaje | **Rust 1.85+ (MUSL estático, LTO, tokio)** |
| Rol | **Solo escucha** (CDC multi-motor) + enruta tareas a biedata + publica a bSearch |
| **Superficie entrante** | **Cero** — sin puerto, sin socket entrante, sin API. **Nadie lo llama.** |
| Control | `bosctl bkernel ...` (CLI del IAM Installer; sin API propia) |
| Salida hacia biedata | **JSON-RPC 2.0 sobre Unix socket `/run/bos/biedata.sock`** (ADR-012) |
| Salida hacia bSearch | Redis Stream `bkernel:index_queue` (XADD) |
| Unidad declarativa | **Ficha** (`source.yml` + `transform.yml` + `task_catalog.sh` + `setup.sh`) |
| Directorio fichas | `/etc/bos/blibs/bkernel/servers/<servidor>/<app>/` |
| Config | `/etc/bos/blibs/bkernel/bkernel.toml` |
| BD propia | `bkernel_db` (estado operacional + **catálogo de escuchas** — nunca datos de negocio) |
| Métricas | `:9105` (Prometheus) — único puerto, solo salida de métricas |
| Servidor lógico | S01 (junto a PostgreSQL) |

---

## 2. Qué es bKernel — en una línea (corregido)

> **bKernel escucha los cambios de las bases de datos del ecosistema y, ante cada
> cambio relevante, le ordena a biedata la tarea correspondiente. No escribe nada
> de negocio. Nadie interactúa con él.**

Es un motor reactivo puro: entra un evento por CDC, sale una orden de trabajo hacia
biedata (escritura) y/o un evento hacia bSearch (indexación). El binario Rust no sabe
qué apps existen — toda la inteligencia vive en las fichas.

```
                    WAL / Binlog / CDC native
       (PostgreSQL pgoutput · MySQL Binlog ROW · SQLServer CDC · Mongo Change Streams)
                              │
        ┌─────────────────────▼──────────────────────┐
        │              bKernel (Rust)                 │
        │                                             │
        │  Listeners (1 tokio task por motor activo)  │
        │        │  BkernelEvent normalizado          │
        │        ▼                                     │
        │  00_MASTER_BKERNEL  → consulta arquitectura  │
        │        │  ¿hay ficha para esta escucha?      │
        │        ├── NO → CATÁLOGO DE ESCUCHAS (§7)    │  ← CORRECCIÓN 2
        │        │        registra + retiene + alerta  │
        │        └── SÍ → 00_EVENT_ENGINE (transform)  │
        │                  │                           │
        │                  ▼                           │
        │          task_catalog.sh (ficha)             │
        │          · call_biedata "metodo.rpc"  ───────┼──▶ /run/bos/biedata.sock
        │          · publish_redis index_queue  ───────┼──▶ bkernel:index_queue
        │          · save_checkpoint (bkernel_db) ─────┼──▶ (directo, estado propio)
        └─────────────────────────────────────────────┘
```

---

## 3. Objetivos del daemon

| # | Objetivo | Verificación |
|---|---|---|
| O1 | **Escuchar CDC de múltiples motores sin invasión** | Las apps no saben que existe; cero ALTER TABLE de negocio salvo loop-prevention en setup |
| O2 | **Cero superficie entrante** | `ss -tlnp` no muestra puerto de servicio; no hay socket entrante |
| O3 | **Delegar toda escritura en biedata** | `task_catalog.sh` nunca ejecuta SQL/JSON-RPC de negocio; solo `call_biedata` |
| O4 | **No perder ningún evento** | Backpressure + checkpoint solo avanza tras éxito; at-least-once a bSearch |
| O5 | **Registrar toda escucha nueva/divergente** | Catálogo en `bkernel_db`; nada se descarta en silencio |
| O6 | **Loop prevention irrompible** | bKernel ignora escrituras `origin='biedata'`/`origin='bkernel'` |
| O7 | **Latencia determinista** | p99 WAL→acción < 50ms (Rust sin GC) |
| O8 | **Publicar el evento canónico a bSearch** | Contrato bKernel↔bSearch cumplido (texto_plano para no-PostgreSQL) |

---

## 4. Arquitectura interna — los 4 archivos maestros del Core (intacto)

El patrón del IAM Installer, replicado. **El binario Rust nunca nombra una app concreta.**

```
/etc/bos/blibs/bkernel/
├── 00_MASTER_BKERNEL.sh        ← recibe BkernelEvent, consulta arquitectura, ejecuta ficha
├── 00_TASK_CATALOG_BKERNEL.sh  ← funciones genéricas (ver §5) — NUNCA nombra apps
├── 00_EVENT_ENGINE_BKERNEL.sh  ← intérprete: lee source.yml + transform.yml
├── 00_ARCHITECTURE_BKERNEL.yml ← registro: (motor,app,tabla,op) → ficha + función
├── bkernel.toml                ← rutas Vault, pools, backpressure, métricas
└── servers/dataserver/<app>/   ← fichas (una por app)
```

### Mecanismo CDC por motor (intacto)

| Motor | Mecanismo | Checkpoint |
|---|---|---|
| PostgreSQL | WAL lógico (`pgoutput`) | LSN |
| MySQL/MariaDB | Binary Log ROW (`binlog_row_image=FULL`) | BinlogPos + GTID |
| SQL Server | CDC nativo (`sys.sp_cdc_*`) | LSN propio |
| MongoDB | Change Streams (ReplicaSet) | Resume Token |

---

## 5. Funciones genéricas del Core — CORREGIDAS

`00_TASK_CATALOG_BKERNEL.sh` ofrece la biblioteca genérica. **Cambio clave:** las
funciones de escritura de negocio (`execute_sql_pg`, `call_jsonrpc`, `call_rest_api`)
**se retiran del uso de negocio** y se reemplazan por **`call_biedata`**.

| Grupo | Función | Estado |
|---|---|---|
| **Escritura de negocio** | **`call_biedata <method> <params_json>`** | ✅ **ÚNICA vía de escritura — JSON-RPC sobre /run/bos/biedata.sock** |
| Mensajería | `publish_redis <stream> <payload>` | ✅ a bSearch / fanout |
| Estado propio | `save_checkpoint <key> <value>` / `get_checkpoint <key>` | ✅ directo a bkernel_db |
| Estado propio | `update_entity_crossref` / `get_crossref_id` | ✅ directo a bkernel_db |
| Catálogo | `registrar_escucha_nueva` / `registrar_divergencia` | ✅ **nuevo — §7** |
| Auditoría | `log_audit_event <tipo> <id> <ctx_id> <trace_id>` | ✅ directo a bkernel_db |
| Errores | `send_to_dlq <motivo> <ref>` | ✅ |
| Secretos | `get_secret <vault_path>` | ✅ Vault (credenciales de LECTURA CDC) |
| ~~`execute_sql_pg`~~ | ~~SQL directo a BD de negocio~~ | ❌ **RETIRADA para negocio** (solo bkernel_db propia) |
| ~~`call_jsonrpc <app>`~~ | ~~JSON-RPC directo a Tryton~~ | ❌ **RETIRADA — ahora va por biedata** |
| ~~`call_rest_api <app>`~~ | ~~REST directo a Keycloak~~ | ❌ **RETIRADA — ahora va por biedata** |

### `call_biedata` — la nueva función troncal

```bash
# En 00_TASK_CATALOG_BKERNEL.sh — genérica, no nombra apps:
call_biedata() {
    local method="$1" params="$2"
    if [ "${DRY_RUN:-0}" = "1" ]; then
        echo "[DRY_RUN] biedata $method $params" >&2; return 0
    fi
    # JSON-RPC 2.0 sobre Unix socket (ADR-012: HTTP vetado entre daemons)
    local req="{\"jsonrpc\":\"2.0\",\"id\":\"$EVENTO_ID\",\"method\":\"$method\",\"params\":$params}"
    local resp
    resp=$(printf '%s' "$req" | socat - UNIX-CONNECT:/run/bos/biedata.sock) || return 1
    # Si biedata responde error (-32000/-32010) → el caller decide retry/DLQ
    echo "$resp" | jq -e '.error == null' >/dev/null || return 1
    log_audit_event "biedata_call:$method" "$EVENTO_ID" "$CTX_ID" "$TRACE_ID"
}
```

---

## 6. Las fichas de bKernel — el puente hacia biedata

> **Cambio de mentalidad:** la ficha de bKernel ya no contiene la lógica de *cómo*
> se escribe en una BD. Contiene la lógica de *qué tarea de biedata disparar* ante
> cada evento. Es el lugar donde el desarrollador **programa la relación bKernel→biedata.**

```
servers/dataserver/tryton/
├── source.yml        ← QUÉ escuchar (motor, conexión Vault, tablas, checkpoint, loop prevention)
├── transform.yml     ← CÓMO normalizar campos + bsearch_template (contrato con bSearch)
├── task_catalog.sh   ← QUÉ tarea pedirle a biedata (call_biedata) + qué publicar a bSearch
└── setup.sh          ← cómo preparar el motor (lo ejecuta el IAM Installer, no bKernel)
```

### task_catalog.sh — modelo CORREGIDO

```bash
# servers/dataserver/tryton/task_catalog.sh
# Motor origen: PostgreSQL (WAL pgoutput).
# bKernel NO escribe: ordena la tarea a biedata.

on_invoice_posted() {
    local invoice_id="$1" pais="$2"

    # CORRECCIÓN: antes era execute_sql_pg / publish a stream fiscal.
    # Ahora: una sola orden de trabajo a biedata, que valida y escribe.
    call_biedata "fiscal.factura.emision_completa.v1" \
        "{\"invoice_id\":\"$invoice_id\",\"pais\":\"$pais\",\"ctx_id\":\"$CTX_ID\"}" \
        || { send_to_dlq "biedata_emision_fallo" "$invoice_id"; return 1; }

    # Notificar a bSearch para indexar (esto NO cambia — sigue directo a Redis)
    publish_redis "bkernel:index_queue" "$EVENTO_CANONICO"

    log_audit_event "invoice_posted" "$invoice_id" "$CTX_ID" "$TRACE_ID"
}
```

```bash
# servers/dataserver/orangehrm/task_catalog.sh  (MySQL/Binlog)
on_employee_created() {
    local nombre="$1" email="$2" dept="$3"
    # Antes: call_jsonrpc tryton + call_rest_api keycloak (DIRECTO).
    # Ahora: biedata orquesta ambas escrituras como un pipeline/saga.
    call_biedata "rrhh.empleado.alta_completa.v1" \
        "{\"nombre\":\"$nombre\",\"email\":\"$email\",\"dept\":\"$dept\"}" \
        || { send_to_dlq "biedata_alta_fallo" "$email"; return 1; }
    publish_redis "bkernel:index_queue" "$EVENTO_CANONICO"
    log_audit_event "employee_created" "$email" "$CTX_ID" "$TRACE_ID"
}
```

---

## 7. Catálogo de Conocimiento de Escuchas (CORRECCIÓN 2 — gobierno)

> **Requisito del HITL:** nada que bKernel escuche se pierde en silencio. Toda escucha
> nueva o divergente queda registrada para ser encontrada, evaluada y tratada.

### 7.1 Qué es una "escucha"

Una **escucha** = la tupla `(motor, app, tabla, operación)` + un **fingerprint** del
esquema del payload (hash de los campos y sus tipos). El fingerprint permite detectar
cuándo una escucha conocida **cambió de forma**.

### 7.2 Tres estados

| Estado | Significado | Acción |
|---|---|---|
| `conocida` | Tiene ficha asignada y se procesa | Procesar normal; refrescar `ultima_vez_en` |
| `pendiente_revision` | **Escucha NUEVA** — ninguna ficha la atiende | Registrar + **retener eventos** + alertar. NO descartar. |
| `requiere_revision` | **Escucha DIVERGENTE** — fingerprint cambió | Registrar divergencia + alertar + aplicar política de drift |

### 7.3 DDL en `bkernel_db`

```sql
-- Catálogo de escuchas
CREATE TABLE escucha_catalogo (
    id              BIGSERIAL PRIMARY KEY,
    motor           TEXT NOT NULL,
    app             TEXT NOT NULL,
    tabla           TEXT NOT NULL,
    operacion       TEXT NOT NULL,          -- INSERT | UPDATE | DELETE
    ficha_asignada  TEXT,                   -- NULL si es escucha nueva
    fingerprint     TEXT NOT NULL,          -- hash del esquema del evento
    estado          TEXT NOT NULL DEFAULT 'conocida'
                    CHECK (estado IN ('conocida','pendiente_revision','requiere_revision','descartada')),
    muestra_payload JSONB,                  -- ejemplo para evaluar
    primera_vez_en  TIMESTAMPTZ NOT NULL DEFAULT now(),
    ultima_vez_en   TIMESTAMPTZ NOT NULL DEFAULT now(),
    veces_vista     BIGINT NOT NULL DEFAULT 1,
    UNIQUE (motor, app, tabla, operacion)
);

-- Eventos retenidos de escuchas nuevas (EFÍMEROS — se purgan al resolverse)
CREATE TABLE escucha_evento_retenido (
    id            BIGSERIAL PRIMARY KEY,
    escucha_id    BIGINT NOT NULL REFERENCES escucha_catalogo(id),
    evento_json   JSONB NOT NULL,           -- el BkernelEvent completo
    checkpoint    TEXT NOT NULL,            -- para reproceso ordenado
    retenido_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Historial de divergencias
CREATE TABLE escucha_divergencia (
    id                BIGSERIAL PRIMARY KEY,
    escucha_id        BIGINT NOT NULL REFERENCES escucha_catalogo(id),
    fingerprint_antes TEXT NOT NULL,
    fingerprint_nuevo TEXT NOT NULL,
    campos_afectados  JSONB,
    detectada_en      TIMESTAMPTZ NOT NULL DEFAULT now(),
    estado            TEXT NOT NULL DEFAULT 'requiere_revision'
                      CHECK (estado IN ('requiere_revision','aprobada','rechazada')),
    revisada_por      TEXT,
    revisada_en       TIMESTAMPTZ
);

-- Alertas (PERMANENTES — toda alerta resguardada)
CREATE TABLE escucha_alerta (
    id            BIGSERIAL PRIMARY KEY,
    escucha_id    BIGINT REFERENCES escucha_catalogo(id),
    tipo          TEXT NOT NULL,            -- 'escucha_nueva' | 'divergencia'
    detalle       JSONB NOT NULL,
    emitida_en    TIMESTAMPTZ NOT NULL DEFAULT now(),
    resuelta_en   TIMESTAMPTZ,
    ficha_solucion TEXT                     -- con qué ficha se resolvió
);
```

### 7.4 Ciclo de vida — DOS políticas de retención

```
1) Escucha NUEVA llega (sin ficha)
   ├─ INSERT escucha_alerta (tipo='escucha_nueva')   → RESGUARDADA (permanente)
   ├─ INSERT/UPSERT escucha_catalogo estado='pendiente_revision'
   └─ INSERT escucha_evento_retenido (cada evento)    → RETENIDO (no descartar)

2) Se crea la ficha que la atiende
   ├─ los eventos de escucha_evento_retenido se REPROCESAN en orden de checkpoint
   └─ esos mismos eventos sirven como DATOS DE PRUEBA (casos BATS) de la ficha
      → el evento real capturado ES el fixture de su propia ficha (GAP-06)

3) Escucha atendida y resuelta
   ├─ DELETE de escucha_evento_retenido          → EFÍMERO: ya no relevante, se purga
   ├─ UPDATE escucha_catalogo estado='conocida', ficha_asignada=<nueva>
   └─ UPDATE escucha_alerta SET resuelta_en=now(), ficha_solucion=<nueva>
                                                  → la ALERTA queda RESGUARDADA
```

| Qué | Retención | Por qué |
|---|---|---|
| `escucha_evento_retenido` (el dato) | **Efímera** — se purga al resolverse | Ya cumplió: reproceso + prueba |
| `escucha_alerta` (gobierno) | **Permanente** — toda alerta resguardada | Trazabilidad: qué apareció, cuándo, con qué ficha se resolvió |

### 7.5 El loop principal CORREGIDO

```
Evento CDC normalizado → BkernelEvent (con TRACE_ID, CTX_ID)
  1. calcular fingerprint del esquema del evento
  2. ¿(motor,app,tabla,op) en escucha_catalogo?
       NO  → registrar_escucha_nueva()  [alerta + retener + estado pendiente_revision]
             → CONTINUAR (no crash, no descartar silencioso)
       SÍ  → ¿fingerprint == guardado?
               SÍ → procesar: 00_EVENT_ENGINE → task_catalog.sh → call_biedata / publish_redis
               NO → registrar_divergencia() [alerta + escucha_divergencia]
                    → aplicar política de drift de source.yml (continuar | pausar ficha)
  3. save_checkpoint  (solo si el procesamiento fue OK)
```

### 7.6 Control por bosctl (sin API entrante)

```bash
bosctl bkernel escuchas pendientes        # escuchas nuevas sin ficha
bosctl bkernel escuchas divergentes       # escuchas conocidas que cambiaron
bosctl bkernel escucha reprocesar <id>    # reprocesa eventos retenidos con la ficha nueva
bosctl bkernel escucha test <id>          # usa eventos retenidos como casos BATS
bosctl bkernel alertas                    # historial permanente de alertas
```

Alertas también vía Prometheus/Alertmanager: `BKERNEL_ESCUCHA_NUEVA`, `BKERNEL_ESCUCHA_DIVERGENTE`.

---

## 8. Estado propio de bKernel — escritura directa permitida (bien documentada)

bKernel **sí escribe directamente** en dos sitios, porque es **estado operacional
propio, no datos de negocio**. Esto está permitido y debe quedar documentado:

| Destino | Qué escribe | Por qué directo |
|---|---|---|
| `bkernel_db` | checkpoints, crossref, audit_events, catálogo de escuchas, DLQ | Es su propia BD operacional; biedata no la gobierna |
| Redis `bkernel:index_queue` | evento canónico para bSearch | Fanout asíncrono; bSearch consume con consumer group |

`bkernel_db` (tablas operacionales clásicas, intactas): `checkpoint_state`,
`entity_crossref`, `audit_events` (ISO 27001, append-only, particionado mensual),
`bkernel_dlq`, `sync_log`, `schema_drift_log` — **más** las 4 tablas del catálogo de
escuchas (§7.3).

---

## 9. Resiliencia (intacto del canónico §18)

| GAP | Solución |
|---|---|
| Backpressure bKernel↔Redis | Bounded channel 50.000 eventos, high/low watermark 80/20, checkpoint solo tras XADD OK |
| Re-snapshot al expirar Binlog/WAL | Plan 4 niveles; `bkernel_db` gobernador; `bosctl bkernel resync --source` |
| Orden causal entre motores | Disuelto por mínima invasión (un hecho = un evento en un motor) |
| Vault lease expirado | Vault Agent sidecar; bKernel solo lee archivo tmpfs |
| Versioning de fichas | Evolución aditiva + `ficha_version` SemVer |
| Test harness | BATS + DRY_RUN + mocks — **alimentado por eventos retenidos del catálogo (§7.4)** |
| Loop prevention | Nativo por motor: `pg_replication_origin` / campo `_origen` |

---

## 10. Criterios de aceptación

| # | Criterio | Evidencia |
|---|---|---|
| C-01 | Compila estático MUSL (LTO) sin warnings | log `build-rust.sh` + SHA256 |
| C-02 | **Cero superficie entrante** (`ss -tlnp` sin puerto de servicio) | captura de sockets |
| C-03 | Listener PostgreSQL reanuda desde LSN tras reinicio | prueba de reinicio |
| C-04 | **Ninguna escritura de negocio directa** (`task_catalog.sh` solo `call_biedata`) | grep + revisión de fichas |
| C-05 | `call_biedata` llega a `/run/bos/biedata.sock` y procesa la respuesta | log de integración bKernel→biedata |
| C-06 | **Escucha nueva se registra y retiene** (no se descarta) | evento sin ficha → fila en catálogo + retenido + alerta |
| C-07 | **Escucha divergente se detecta por fingerprint** y alerta | cambio de esquema → `escucha_divergencia` |
| C-08 | Reproceso de eventos retenidos con ficha nueva | `bosctl bkernel escucha reprocesar` |
| C-09 | Alertas permanentes; eventos retenidos efímeros (purga al resolver) | verificación de ambas tablas |
| C-10 | Loop prevention: ignora `origin='biedata'`/`origin='bkernel'` | prueba de no-eco |
| C-11 | Publica evento canónico válido a bSearch (texto_plano si motor≠PG) | inspección del stream |
| C-12 | Backpressure pausa/reanuda listener en watermarks | prueba de carga |
| C-13 | Métricas en `:9105`; sin otro puerto | scrape Prometheus |

**Evidencia (ADR-030, AA-1):** log bash real en disco + SHA256 por criterio.

---

## 11. Plan de desarrollo (fases)

> Base existente en `desarrollo/sbos/BkernelAgent/` (Cargo.toml, src, tests).
> Comparte `bkernel-common` por path (ORQUESTA-045: nunca copiar, referenciar).
> PGE obligatorio (ADR-026), MAX_ITER=5 para código de dominio.

### Fase A — Núcleo de escucha (depende de que biedata exponga el socket)
1. Tipos Rust: `BkernelEvent`, `Checkpoint`, `Fingerprint`, config.
2. Listener PostgreSQL (WAL pgoutput) con `tokio-postgres`/`pgwire-replication`.
3. Bounded channel + backpressure + watermarks.
4. `00_MASTER_BKERNEL` + `00_ARCHITECTURE_BKERNEL.yml` + `00_EVENT_ENGINE`.
5. Checkpoint persistence en `bkernel_db`.

### Fase B — Catálogo de escuchas (gobierno)
6. Cálculo de fingerprint del esquema del evento.
7. Tablas `escucha_*` + funciones `registrar_escucha_nueva` / `registrar_divergencia`.
8. Loop principal corregido (§7.5): nada se descarta.
9. Retención de eventos + reproceso + alimentación de BATS.
10. `bosctl bkernel escuchas/alertas/reprocesar`.

### Fase C — Delegación a biedata y fanout a bSearch
11. `call_biedata` (JSON-RPC sobre Unix socket) + manejo de error/DLQ.
12. Migrar fichas: retirar `call_jsonrpc/call_rest_api/execute_sql_pg` de negocio.
13. `publish_redis` evento canónico (contrato bKernel↔bSearch) con `texto_plano`/`payload_navegacion`.

### Fase D — Multi-motor, resiliencia y certificación
14. Listeners MySQL/SQLServer/MongoDB.
15. Re-snapshot 4 niveles + schema drift.
16. Vault Agent sidecar + loop prevention por motor.
17. Métricas `:9105`, audit ISO 27001, certificación C-01..C-13.

---

## 12. Coordinación entre los 3 daemons de datos

> **Sección espejo en los 3 manuales — contrato de coordinación común.**

### 12.1 El modelo corregido (decisión HITL, jun 2026)

```
        WAL / Binlog / CDC
                 │
                 ▼
      ┌────────────────────┐   bKernel SOLO ESCUCHA
      │      bKernel        │   · cero superficie entrante · NADIE lo llama
      └─────┬─────────┬─────┘
   ESCRIBIR │         │ INDEXAR
 (JSON-RPC  │         │ (Redis Stream
  Unix sock)│         │  bkernel:index_queue)
            ▼         ▼
   ┌────────────────┐  ┌────────────────────┐
   │   biedata      │  │     bSearch        │
   │ ÚNICO escritor │  │ consume + indexa   │
   └───────┬────────┘  └────────────────────┘
           ▼
  Tryton / Keycloak / Saleor / OrangeHRM...
```

### 12.2 Reparto de responsabilidades

| Daemon | Su ficha programa… | ¿Toca BD de negocio? | Interface entrante |
|---|---|---|---|
| **bKernel** | *cuándo* y *qué tarea de biedata* disparar ante cada evento CDC | ❌ nunca | **ninguna** (cero superficie) |
| **biedata** | *cómo* ejecutar la tarea (validar + escribir) | ✅ único escritor | `:9470` externo + Unix socket interno + CLI |
| **bSearch** | *cómo* indexar lo que bKernel publica | ❌ solo `busqueda_universal` | WebSocket `wss://` |

### 12.3 Dos capas de fichas

| Capa | Vive en | Define |
|---|---|---|
| Ficha **bKernel** | `bkernel/servers/<srv>/<app>/` | el puente: evento CDC → qué método de biedata invocar |
| Ficha **biedata** | `biedata/fichas/<in\|out>/<nombre>/` | la ejecución real: validar + pipeline + escribir |

### 12.4 Por qué bKernel no necesita Interface Dual

ADR-020 exige Interface Dual a todos los daemons **que reciben llamadas**. A bKernel
**nadie lo llama** (es un sumidero de eventos CDC, no un servicio). Su única "entrada"
es el flujo CDC de los motores; su control administrativo es por `bosctl` (parte del
IAM Installer). Por eso bKernel es la **excepción explícita** a ADR-020.

### 12.5 Contrato con bSearch (Redis)

bKernel publica el **evento canónico** en `bkernel:index_queue` (ver
`CONTRATO-BKERNEL-BSEARCH.md`): incluye `texto_plano` obligatorio para motores
no-PostgreSQL, `payload_navegacion` con deep-link, `tenant_id`, `event_id` único,
`_meta.contrato_version`. bSearch deduplica por `event_id` y hace UPSERT idempotente.

---

## 13. Fronteras inviolables (intacto + reforzado)

| # | bKernel NUNCA |
|---|---|
| F1 | Expone un puerto/socket/API entrante (cero superficie) |
| F2 | Modifica el esquema de una app (ALTER TABLE de negocio) |
| F3 | Guarda datos de negocio en `bkernel_db` |
| F4 | Nombra apps concretas en el binario o los 4 archivos maestros |
| **F5'** | **Escribe en una BD de negocio (Tryton/Keycloak/Saleor/...) — toda escritura va por biedata** |
| F6 | Almacena credenciales en disco (Vault siempre) |
| F7 | Usa loop prevention distinto al nativo de cada motor |
| F8 | Indexa directamente en bSearch (solo publica a Redis) |
| **F12** | **Descarta un evento sin registrarlo en el catálogo de escuchas** |

---

## 14. Trazabilidad

| Sección | Fuente |
|---|---|
| Core, fichas, CDC, GAPs, fronteras | `BKERNEL-DEFINICION-CANONICA.md` (con correcciones de este manual) |
| Contrato con bSearch | `CONTRATO-BKERNEL-BSEARCH.md` + `DDL-COMPARTIDA-BKERNEL-BSEARCH.md` |
| DDL Guardian | `BKERNEL-DDL-GUARDIAN.md` |
| **bKernel solo escucha / usa biedata** | **Decisión HITL 2026-06-01 (corrige §5/§8 canónico)** |
| **Catálogo de escuchas** | **Decisión HITL 2026-06-01 (corrige §12 canónico)** |
| **Excepción a Interface Dual** | **ADR-020 + decisión HITL** |
| JSON-RPC, Unix socket, errores | ORQUESTA-043 (Partes 1, 5, 6) |

---

_SKULL · SBOS · MANUAL-DESARROLLO-BKERNEL · v1.0 · Junio 2026 · biblio-dev_
_bKernel solo escucha · usa biedata para escribir · nadie lo llama · nada se descarta en silencio_
