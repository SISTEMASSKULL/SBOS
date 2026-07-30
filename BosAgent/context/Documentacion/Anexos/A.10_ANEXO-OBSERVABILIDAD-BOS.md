# Anexo A.10 — Información Nativa del BOS y su Organización para Control
## Qué emite el BOS por sí mismo (sin herramientas externas) y cómo se organiza con Prometheus + Grafana + Loki para un dashboard profesional

**Versión:** 1.0.0 · **Fecha:** 2026-07-18 · **Autor:** bos-developer — SBOS
**Fortalece a:** TODOS los motores, especialmente ② SO Observable y ⑤ Dashboard
**Referencia:** [0.00 — Directrices BOS](../0.00_MANUAL-DIRECTRICES-BOS-CONTROL-PLANE.md)

---

## PARTE A — LO QUE EL BOS EMITE NATIVAMENTE (sin herramientas externas)

El BOS es un daemon Go que genera información por sí mismo. No necesita Prometheus, Grafana
ni Loki para producir datos. Lo que sí necesita es que sus **monitores internos** expongan
información procesable para que un operador —o un dashboard— entienda qué está pasando en
el sistema en este preciso momento.

---

### MONITOR 1 — Estado de Fichas, Pods y Procesos del BOS

**Qué responde:** ¿qué fichas están vivas? ¿cuáles están degradadas? ¿qué está haciendo el
BOS AHORA MISMO para repararlas? ¿hay una saga en curso?

Este es el monitor más importante. Le da al operador visibilidad completa de la salud del
stack y de la actividad del BOS como remediador autónomo.

```
MONITOR DE FICHAS Y PODS — bosctl ficha list

  FICHA          SERVIDOR  ESTADO       HEALTH   UPTIME   BOS ACCIÓN
  ─────────────  ────────  ───────────  ──────   ──────   ──────────────────────
  postgresql     S01       INSTALADA    🟢 OK    72h      —
  redis          S01       INSTALADA    🟢 OK    72h      —
  vault          S02       INSTALADA    🟢 OK    71h      —
  keycloak       S03       INSTALADA    🟢 OK    70h      —
  kong           S02       INSTALADA    🟢 OK    69h      —
  nextcloud      S11       DEGRADADA    🔴 FAIL  2h       🔄 REPARANDO (intento 2/3)
  guacamole      S11       REPARANDO    🟡 PROBE 5min    🔄 ejecutando ficha_repair()
  website-engine S16       INSTALANDO   ⏳ WAIT  30s      ▶ saga install paso 3/5
        S01       ERROR_FISICO ❌ OOM   1h       ⚠️ HITL REQUERIDO (3/3 fallos)
```

**Qué significa cada columna:**
- **ESTADO:** el estado ADR-021 real de la ficha en este momento
- **HEALTH:** resultado del último health check (OK, FAIL, PROBE pendiente)
- **BOS ACCIÓN:** lo que el BOS está haciendo AHORA MISMO sobre esa ficha — reparando,
  instalando, actualizando, esperando aprobación HITL, o nada (—)
- Si una ficha está DEGRADADA y el BOS no está haciendo nada, hay un problema
- Si una ficha está REPARANDO, el operador sabe que el BOS ya lo detectó y está actuando

**Detalle de una ficha específica:**
```bash
bosctl ficha status postgresql

  Estado:           INSTALADA (desde 2026-07-15T10:00:00Z)
  Versión:          18.4
  Health:           🟢 OK (pg_isready: accepting connections)
  Pod:              postgresql-0 (Running, 45% CPU, 3.2GB/8GB RAM)
  Dependientes:     keycloak, vault, kong, bauth (5 fichas)
  Último evento:    HEALTH_OK (2026-07-18T14:30:00Z)
  Último repair:    2026-07-10T02:15:00Z (OOMKilled → memoria escalada a 8Gi)
  Drift:            No detectado
  BOS Acción:       — (sin actividad en curso)
```

---

### MONITOR 2 — Actividad de Contextos (ctx_id en tiempo real)

**Qué responde:** ¿cuántos usuarios hay activos? ¿dónde están operando? ¿qué acaba de pasar
con los contextos — alguien hizo login? ¿logout? ¿cambió de sucursal? ¿hay sesiones
expiradas? ¿hay actividad anómala?

Este monitor es el "panel de control de la actividad empresarial". Sin él, el operador no
sabe si el sistema está vivo o muerto a nivel de negocio.

```
MONITOR DE CONTEXTOS ACTIVOS — bosctl ctx list --tenant=skull

  CTX_ID          USUARIO      BDOMAIN     BSUBDOMAIN  POS       ESTADO   TTL
  ─────────────── ──────────── ─────────── ─────────── ───────── ─────── ──────
  ctx-88291-a4f9  juan-perez   SKULL-CORP  Norte       CAJA-01   ACTIVO   3h12m
  ctx-7a3b2c-91d  maria-lopez  SKULL-CORP  Sur         CAJA-03   ACTIVO   5h45m
  ctx-f1e2d3-c8a  pedro-gomez  Juan-Perez  Oficina     Desarro   ACTIVO   1h20m
  ctx-1a2b3c-4d5  ana-ruiz     Almacen-Cen Deposito-A  Estante   ACTIVO   6h10m
  ctx-9f8e7d-6c5  camion-001   Flota-Norte Patio-Centr Estac-01  ACTIVO   2h30m
  ─────────────── ──────────── ─────────── ─────────── ───────── ─────── ──────
  Total: 47 activos | 3 expirados (última hora) | 2 promovidos (última hora) | 0 inválidos
```

**Eventos de contexto en tiempo real (últimos 5 minutos):**
```
[14:32:00] ctx.promoted    dctx-device-991 → ctx-88291-a4f9  (juan-perez, CAJA-01, Norte)
[14:32:15] ctx.switched    ctx-7a3b2c-91d → Sur/CAJA-03      (maria-lopez cambió de sucursal)
[14:33:02] ctx.created     ctx-f1e2d3-c8a                     (nuevo login, pedro-gomez)
[14:35:47] ctx.invalidated ctx-abc-def-123                    (logout, ana-ruiz)
[14:38:10] ctx.expired     ctx-111-222-333                    (TTL agotado, sin heartbeat)
[14:40:00] ctx.heartbeat   dctx-device-991                    (dispositivo renovó TTL)
```

**Anomalías detectadas (últimas 24h):**
```
[09:15:22] 3 invalidaciones desde misma IP en < 1min → posible ataque de enumeración
[11:42:00] cross-tenant bloqueado: ctx_id tenant=skull intentó acceder a tenant=maya
[22:05:33] 12 sesiones expiradas simultáneas → posible caída de Redis DB1
```

---

### MONITOR 3 — Procesos del BOS en ejecución

**Qué responde:** ¿qué está haciendo el BOS AHORA MISMO? ¿hay una saga corriendo? ¿un
reconcile loop? ¿un health check masivo? ¿el watchdog detectó algo?

El BOS es un daemon autónomo que ejecuta procesos constantemente. Sin este monitor, el
operador no sabe si el BOS está ocupado o muerto.

```
MONITOR DE PROCESOS BOS — bosctl status --processes

  PROCESO                ESTADO     INICIO      DURACIÓN   DETALLE
  ────────────────────── ─────────  ──────────  ────────   ──────────────────────────
  Watchdog (tick 30s)    ✅ OK      14:30:00    0.8s       3 capas verificadas, sin novedad
  Reconciler (tick 15m)  🔄 ACTIVO  14:30:00    4.2s       comparando 24 fichas (12/24)
  Observer (tick 5s)     ✅ OK      14:30:05    0.2s       sin cambios de estado
  Saga: deploy skull     ▶ PASO 5   14:28:00    2m30s      instalando fichas DAG (3/8)
  Saga: repair nextcloud 🔄 INT 2/3  14:25:00    5m10s      ficha_repair() en ejecución
  Health Check (tick 60s) ✅ OK      14:30:00    1.5s       24/24 fichas verificadas
  Collector (tick 60s)   ✅ OK      14:30:00    0.9s       30 métricas recolectadas
  ─────────────────────────────────────────────────────────────────────────────────────
  Cola de tareas: 0 pendientes | Último error: — | BOS uptime: 72h 14m
```

**Qué revela este monitor:**
- Si el Watchdog no aparece en el último minuto → el BOS está caído
- Si el Reconciler lleva > 60s → hay un problema de rendimiento con K8s API
- Si hay 3 sagas simultáneas → el sistema está bajo carga de reparación
- Si la cola de tareas crece → el BOS no da abasto

---

### MONITOR 4 — Tráfico del Context Plane (ctx_id lookups)

**Qué responde:** ¿cuántos requests está validando Kong por segundo? ¿qué latencia tiene
el lookup en Redis? ¿hay errores? ¿está Redis respondiendo o estamos en slow-path (PG)?

Sin este monitor, el operador no sabe si el sistema está sirviendo requests normalmente
o si hay una degradación silenciosa.

```
MONITOR DE TRÁFICO CONTEXT PLANE — bosctl ctx stats

  Lookups/segundo:  847 (último minuto)
  Latencia:         P50 0.8ms | P95 2.1ms | P99 4.3ms | SLO < 5ms ✅
  Cache hits:       98.7% (Redis O(1))
  Slow-path (PG):   1.3% (11 lookups/min — por encima del 1% habitual ⚠️)
  Errores:          0 invalid | 0 expired | 3 not_found (OK)
  Rate limited:     0 requests bloqueados

  Redis DB1:        512MB usado | 1.2GB total | 42% utilización ✅
  Redis conexiones: 12 activas | 50 máx | sin errores de conexión
```

---

### MONITOR 5 — Actividad de Tenants

**Qué responde:** ¿qué tenants están activos? ¿alguno está siendo provisionado ahora?
¿alguno suspendido? ¿cuánto tardó el último deploy?

```
MONITOR DE TENANTS — bosctl tenant list

  TENANT   TIPO      ESTADO       SESIONES  FICHAS  ÚLTIMO DEPLOY    DURACIÓN
  ──────── ────────  ───────────  ────────  ──────  ───────────────  ───────
  skull    INTERNO   ACTIVO       23        12      2026-07-15T10    22s ✅
  maya     INTERNO   ACTIVO       12        10      2026-07-14T08    28s ✅
  inka     EXTERNO   ACTIVO        8         6      2026-07-12T14    31s ✅
  azteca   EXTERNO   PROVISIONANDO 0         0      2026-07-18T14    (paso 4/7)
  tolteca  EXTERNO   SUSPENDIDO    0         6      2026-06-01T09    25s ✅
  ─────────────────────────────────────────────────────────────────────────────
  Total: 5 tenants | 3 activos | 1 provisionando | 1 suspendido
  SLO deploy < 30s: 97.8% este mes (45/46 ✅)
```

---

### MONITOR 6 — Recursos del Host correlacionados con actividad BOS

**Qué responde:** ¿hay suficiente CPU/RAM/disco? ¿el consumo actual es normal o hay un
pico? ¿ese pico coincide con alguna actividad del BOS?

A diferencia de `top` o `htop`, este monitor CORRELACIONA el uso de recursos con lo que
el BOS está haciendo. No es solo "CPU al 85%" — es "CPU al 85% porque el Reconciler está
comparando 24 fichas contra K8s".

```
MONITOR DE RECURSOS — bosctl status --resources

  CPU:     45% (normal: 30-50%)  ██████████░░░░░░░░░░
  RAM:     6.5GB / 11GB (59%)    ████████████░░░░░░░░
  DISCO:   89GB / 387GB (23%)    █████░░░░░░░░░░░░░░░
  PSI CPU: 2.1% (some) — normal
  PSI MEM: 0.0% — normal
  PSI IO:  0.5% (some) — normal

  Proceso BOS que más consume: Reconciler (12% CPU, 4.2s duración)
  Proceso que más RAM usa:     Context Plane (1.2GB Redis DB1)

  Picos anómalos (últimas 24h):
  [02:00] CPU 92% — pg_dump programado (backup diario, normal)
  [09:15] RAM 94% — 3 sagas de repair simultáneas (nextcloud+guacamole+website-engine)
  [14:25] CPU 78% — Reconciler comparando 24 fichas (normal, tick 15min)
```

---

### A.8 — Resumen: los 6 monitores nativos del BOS

| Monitor | Pregunta que responde | Comando | Sin herramientas externas |
|---------|----------------------|---------|:-------------------------:|
| **Fichas y Procesos** | ¿Qué está haciendo el BOS ahora? | `bosctl ficha list` / `bosctl ficha status` | ✅ |
| **Contextos Activos** | ¿Dónde están operando los usuarios? | `bosctl ctx list --tenant=X` | ✅ |
| **Procesos BOS** | ¿Qué procesos internos están corriendo? | `bosctl status --processes` | ✅ |
| **Tráfico Context Plane** | ¿A qué ritmo valida Kong ctx_ids? | `bosctl ctx stats` | ✅ |
| **Actividad Tenants** | ¿Qué tenants están vivos? | `bosctl tenant list` | ✅ |
| **Recursos Correlacionados** | ¿El consumo es normal o hay un pico? | `bosctl status --resources` | ✅ |

---

## FUNDAMENTOS DE INDUSTRIA — Cómo se diseñan los paneles de control profesionales

Antes de definir cómo se organiza la información del BOS con herramientas, es necesario
entender cómo la industria diseña paneles de control para operadores de infraestructura
crítica. Estos patrones vienen de centrales eléctricas, refinerías, centros de datos y
plataformas Kubernetes. El BOS es el panel de control del sistema operativo empresarial —
debe aplicar los mismos principios.

### Principio 1 — Conciencia situacional, no datos crudos

El estándar **ANSI/ISA-101.01** (HMI Design) y la norma **ISO 11064** (Control Room Design)
establecen que un panel de control debe responder tres preguntas de un vistazo:

1. **¿Cuál es el estado actual?** (situación)
2. **¿Está dentro de los límites normales?** (comparación)
3. **¿Hacia dónde va?** (trayectoria)

No se trata de mostrar todos los datos disponibles — se trata de mostrar solo los que
permiten decidir. Un operador no necesita ver 47 sesiones activas; necesita saber si 47
es normal para un martes a las 14:30 o si deberían ser 120.

### Principio 2 — Jerarquía de 4 niveles (ISA-101)

```
NIVEL 1 — VISIÓN GENERAL (1 pantalla)
  Responde: ¿el sistema está sano?
  Muestra: semáforos R/Y/G, KPIs clave, alertas activas.
  No muestra: detalles, tablas, logs.
  El operador mira esto 90% del tiempo.

NIVEL 2 — CONTROL DE UNIDAD (1 clic desde N1)
  Responde: ¿qué está pasando en este subsistema?
  Muestra: estado detallado de fichas, tenants, contexto.
  El operador navega aquí cuando algo está amarillo o rojo.

NIVEL 3 — DETALLE (1 clic desde N2)
  Responde: ¿qué causó este evento específico?
  Muestra: historial de una ficha, ciclo de vida de un ctx_id, logs.
  El operador investiga un incidente.

NIVEL 4 — DIAGNÓSTICO (1 clic desde N3)
  Responde: ¿cómo se resolvió? ¿qué aprendimos?
  Muestra: runbooks, post-mortems, trazas completas.
  El operador documenta la resolución.
```

**Regla de diseño:** alcanzar cualquier pantalla en máximo 3 clics desde el Nivel 1.
La información sigue el principio de **divulgación progresiva**: resumen primero,
detalle bajo demanda.

### Principio 3 — Carga cognitiva y "glanceability"

El operador humano tiene recursos cognitivos finitos. El diseño debe respetar eso:

- **Fondo neutro (gris oscuro) en operación normal.** El color brillante (rojo, amarillo)
  se reserva EXCLUSIVAMENTE para estados anormales y alarmas.
- **Sin "árbol de navidad".** Si todo está verde, nada debería parpadear.
- **Indicadores analógicos** (barras, medidores, sparklines) en vez de números crudos.
  Un medidor que muestra 59% con una aguja en la zona verde se interpreta en milisegundos.
  Un número "59" requiere leer, comparar, decidir.
- **Agrupación por significado, no por fuente.** "Salud del stack" agrupa fichas, pods
  y health checks — aunque vengan de fuentes distintas (K8s API, PostgreSQL, Redis).

### Principio 4 — Gestión inteligente de alarmas

El estándar **EEMUA 191** (Alarm Management) establece:

- Si un evento anormal genera 20 alarmas pero solo 2 requieren acción, 18 fueron ruido.
- **Suprimir y deduplicar.** Si postgresql está caído, no alertar también por keycloak
  caído, kong caído, y nextcloud caído — todos dependen de PG. Una sola alarma: "PG Down".
- **Priorizar con señales visuales:** crítica (rojo + ícono + borde parpadeante), alta
  (naranja), media (amarillo), informativa (azul).
- **Cada alarma debe responder:** ¿qué acción debe tomar el operador?

### Principio 5 — Diseño de 3 regiones

El panel de control profesional sigue un layout de 3 zonas:

```
┌──────────┬────────────────────────────────┬──────────┐
│          │                                │          │
│  BARRA   │       CONTENIDO PRINCIPAL      │  PANEL   │
│  LATERAL │                                │  DETALLE │
│          │  (métricas, tablas, gráficos)  │          │
│  (naveg  │                                │  (inspe- │
│   ación) │                                │  cción)  │
│          │                                │          │
└──────────┴────────────────────────────────┴──────────┘
```

- **Barra lateral** (izquierda): navegación entre monitores, siempre visible
- **Contenido principal** (centro): la información del monitor activo
- **Panel de detalle** (derecha): al hacer clic en un elemento, muestra su detalle sin
  perder el contexto principal

### Principio 6 — Stats blocks (tarjetas de estado)

Patrón estándar de la industria para el Nivel 1:

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│                 │  │                 │  │                 │
│   FICHAS OK     │  │   SESIONES      │  │   ERROR BUDGET  │
│   22 / 24       │  │   47            │  │   87.5%         │
│   🟢            │  │   🟢            │  │   🟢            │
│   ▁▂▃▄▅▆▇ (24h) │  │   ▁▂▃▄▅▆▇ (24h)  │  │   ▆▆▅▄▃▂▁ (30d) │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

Cada tarjeta tiene: número grande (valor actual), etiqueta (qué mide), indicador de
color (estado), sparkline (tendencia 24h). Se interpreta en < 1 segundo.

---

## PARTE B — ORGANIZACIÓN CON HERRAMIENTAS (Prometheus + Grafana + Loki)

Las herramientas del servidor S12-monitorserver (parte del stack SBOS, instaladas como fichas
por el BOS) toman los datos nativos de la Parte A y los organizan para control profesional.

---

### B.1 — Prometheus (S12-monitorserver, ficha `prometheus`)

**Qué hace:** recolecta las métricas que el BOS expone en `:9090/metrics` cada 15 segundos.
Las almacena como series temporales. Evalúa reglas de alerta.

**Qué métricas del BOS consume:**
- `bos_ctx_sessions_active` — sesiones activas (gauge)
- `bos_ficha_state{id,state}` — estado de cada ficha (gauge, 1 = está en ese estado)
- `bos_host_cpu_pct`, `bos_host_ram_used_mb` — recursos del host
- `bos_k8s_nodes_ready`, `bos_k8s_pods_running` — salud K8s
- `bos_ctx_lookup_duration_seconds` — latencia del Context API (histograma)

**Qué produce:** series temporales para Grafana, alertas para Alertmanager.

### B.2 — Grafana (S12-monitorserver, ficha `grafana`)

**Qué hace:** visualiza las series temporales de Prometheus en dashboards.

**Paneles recomendados para el dashboard de control del BOS:**

```
FILA 1 — SALUD GENERAL (semáforo):
  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌──────────────┐
  │ Fichas OK   │ │ Sesiones    │ │ Error Budget│ │ Uptime       │
  │    22/24    │ │    47       │ │   87.5%     │ │   72h 14m    │
  │    🟢       │ │    🟢       │ │    🟢       │ │    🟢        │
  └─────────────┘ └─────────────┘ └─────────────┘ └──────────────┘

FILA 2 — RECURSOS (time series 24h):
  ┌─ CPU % ─────────────────────────────────────────────────────┐
  └──────────────────────────────────────────────────────────────┘
  ┌─ RAM used / total ──────────────────────────────────────────┐
  └──────────────────────────────────────────────────────────────┘

FILA 3 — FICHAS (tabla de estados):
  ┌────────────┬──────────┬────────┬────────┬──────────┐
  │ Ficha      │ Estado   │ Versión│ Health │ Uptime   │
  ├────────────┼──────────┼────────┼────────┼──────────┤
  │ postgresql │ INSTALADA│ 18.4   │ 🟢 OK  │ 72h      │
  │ redis      │ INSTALADA│ 8.6.2  │ 🟢 OK  │ 72h      │
  │ vault      │ INSTALADA│ 2.0.1  │ 🟢 OK  │ 71h      │
  │ nextcloud  │ DEGRADADA│ 29.0.4 │ 🔴 FAIL│ 2h       │
  └────────────┴──────────┴────────┴────────┴──────────┘

FILA 4 — CONTEXTO (time series 7d):
  ┌─ Sesiones activas (por tenant) ─────────────────────────────┐
  │  skull: ████████████ 23   maya: ██████ 12   inka: ███ 8     │
  └──────────────────────────────────────────────────────────────┘
  ┌─ Latencia ctx_id lookup (P50/P95/P99) ──────────────────────┐
  └──────────────────────────────────────────────────────────────┘

FILA 5 — ERROR BUDGET (gauge mensual):
  ┌──────────────────────────────────────────────────────────────┐
  │ Error Budget ctx_id:  ████████████░░░░ 87.5% restante       │
  │ Burn Rate: 0.3x (normal)                                    │
  └──────────────────────────────────────────────────────────────┘
```

### B.3 — Loki (S12-monitorserver, ficha `alloy` o `loki`)

**Qué hace:** agrega los logs estructurados de `/var/log/bos/bos.log` y permite buscarlos
por `ctx_id`, `tenant_id`, `subsystem`, `operation`, `level`.

**Consultas útiles para el operador:**
```logql
# Todos los errores de las últimas 24h
{component="bos", level="ERROR"}

# Traza completa de una sesión específica
{ctx_id="ctx-88291-a4f9"}

# Operaciones de promote en el tenant skull
{subsystem="context-plane", operation="promote", tenant_id="skull"}

# Reparaciones fallidas
{subsystem="ficha-engine", operation="repair", result="fail"}
```

### B.4 — Alertmanager (S12-monitorserver, ficha `alertmanager`)

**Qué hace:** recibe alertas de Prometheus y las enruta por severidad.

**Reglas de alerta para el BOS:**
```yaml
# Críticas (P0, < 15 min)
- Ficha crítica DEGRADADA > 5min → PagerDuty
- ctx_id lookup P99 > 10ms por 5min → PagerDuty
- Nodo K8s NotReady > 3min → PagerDuty

# Altas (P1, < 1h)
- Disco > 85% → RocketChat #sbos-alerts
- Sesiones activas = 0 (nadie puede operar) → RocketChat
- Error budget burning > 10x → RocketChat

# Medias (P2, < 4h)
- RAM > 90% → RocketChat
- Ficha no-crítica DEGRADADA > 15min → RocketChat
```

---

## PARTE C — ARQUITECTURA COMPLETA

```
┌─────────────────────────────────────────────────────────────────────┐
│                        BOS DAEMON (Go)                              │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────────┐ │
│  │ /metrics     │  │ JSON-RPC 2.0 │  │ /var/log/bos/              │ │
│  │ :9090        │  │ /run/bos/    │  │ bos.log + audit.log        │ │
│  │ (Prometheus) │  │ bos.sock     │  │ + fichas/*.log             │ │
│  └──────┬───────┘  └──────┬───────┘  └────────────┬───────────────┘ │
│         │                 │                        │                 │
│         │                 │                        │                 │
│  ┌──────▼───────┐  ┌──────▼───────┐  ┌────────────▼───────────────┐ │
│  │ Prometheus   │  │ Dashboard    │  │ Loki                        │ │
│  │ (scrape 15s) │  │ bauth        │  │ (log aggregation)           │ │
│  │              │  │ (consulta vía│  │                             │ │
│  │ series       │  │ JSON-RPC)    │  │ search by ctx_id, tenant,   │ │
│  │ temporales   │  │              │  │ operation                   │ │
│  └──────┬───────┘  └──────────────┘  └────────────┬───────────────┘ │
│         │                                          │                 │
│  ┌──────▼───────┐                           ┌──────▼───────┐        │
│  │ Grafana      │                           │ LogQL        │        │
│  │ (dashboards) │                           │ (consultas)  │        │
│  └──────────────┘                           └──────────────┘        │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ Alertmanager ← evalúa reglas ← Prometheus                    │   │
│  │   critical → PagerDuty                                       │   │
│  │   high → RocketChat #sbos-alerts                             │   │
│  │   medium → RocketChat #sbos-alerts-all                       │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘

NOTA: Prometheus, Grafana, Loki y Alertmanager son fichas del stack SBOS
(servidor S12-monitorserver), instaladas y gestionadas por el BOS como
cualquier otra ficha. No son servicios externos — son parte del ecosistema.
```

---

## Referencias

- [0.00 — Directrices BOS](../0.00_MANUAL-DIRECTRICES-BOS-CONTROL-PLANE.md)
- [2.03 — Health Checks y Métricas](../2.03_MANUAL-SO-OBSERVABLE-METRICAS.md)
- SBOS-032-OPERATIONS — SLOs, runbooks, Alertmanager
- [Google SRE Book](https://sre.google/books/) — SLI/SLO/Error Budget
- [Prometheus](https://prometheus.io/) · [Grafana](https://grafana.com/) · [Loki](https://grafana.com/oss/loki/)

---

*SKULL · SBOS · BosAgent · Julio 2026*
