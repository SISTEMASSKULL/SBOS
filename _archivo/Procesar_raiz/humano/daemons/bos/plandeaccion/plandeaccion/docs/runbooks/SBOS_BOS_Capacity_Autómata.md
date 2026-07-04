# SBOS — bos como Autómata de Capacidad Soberana
## Supervisión Continua · Proyección Dinámica · Políticas de Crecimiento

**Documento:** SBOS-BOS-CAP-001  
**Versión:** 1.0  
**Estado:** Normativo Activo  
**Fecha:** 2026-06-12  
**Clasificación:** Interno · Arquitectura · Operaciones  

---

## Índice

1. [El Problema que Resuelve](#1-el-problema-que-resuelve)
2. [El bos como Autómata de Capacidad](#2-el-bos-como-autómata-de-capacidad)
3. [El Motor de Observación Continua](#3-el-motor-de-observación-continua)
4. [El Motor de Proyección Dinámica](#4-el-motor-de-proyección-dinámica)
5. [El Motor de Políticas de Capacidad](#5-el-motor-de-políticas-de-capacidad)
6. [Acciones Autónomas del bos](#6-acciones-autónomas-del-bos)
7. [El Sistema de Alertas y Recomendaciones](#7-el-sistema-de-alertas-y-recomendaciones)
8. [Controles de Admisión — El bos como Portero](#8-controles-de-admisión--el-bos-como-portero)
9. [Base de Datos de Capacidad — cap_db](#9-base-de-datos-de-capacidad--cap_db)
10. [Dashboard del Administrador](#10-dashboard-del-administrador)
11. [Integración con los Daemons](#11-integración-con-los-daemons)
12. [Comandos bosctl de Capacidad](#12-comandos-bosctl-de-capacidad)
13. [Configuración de Políticas YAML](#13-configuración-de-políticas-yaml)

---

## 1. El Problema que Resuelve

### 1.1 El Plan No es Suficiente

Un plan de capacidad estático tiene una vida útil limitada. En el mundo
real, el crecimiento no sigue la curva planificada:

```
Planificado:    Tenant A → max 150 empresas en 12 meses
Real:           Tenant A → 800 empresas en 4 meses (viral, fusión, contrato corporativo)
```

Sin supervisión continua, el sistema simplemente falla cuando la realidad
supera lo planificado. El administrador se entera cuando los usuarios ya
están viendo errores.

### 1.2 Lo que el bos Garantiza

> **El sistema nunca se cae por falta de capacidad no anticipada.**
> Si la capacidad no puede satisfacerse, el bos bloquea la admisión
> de nueva carga antes de que el sistema se degrade.
> El administrador siempre actúa sobre recomendaciones — nunca sobre crisis.

### 1.3 Los Tres Principios del Autómata de Capacidad

**Principio 1 — Observación continua antes que planificación estática.**
Los valores reales medidos cada 60 segundos reemplazan a las proyecciones
teóricas. El bos actualiza sus modelos con datos reales en tiempo real.

**Principio 2 — Proyección dinámica con horizonte rodante.**
El bos proyecta la capacidad necesaria a 7, 30 y 90 días basándose
en la tendencia real observada, no en el plan original. Si la tendencia
cambia, la proyección cambia.

**Principio 3 — Acción antes de la degradación.**
El bos actúa (escala, recomienda, bloquea) cuando los indicadores
predicen un problema, no cuando el problema ya ocurrió.

---

## 2. El bos como Autómata de Capacidad

### 2.1 Los Cuatro Motores del Autómata

El bos ejecuta cuatro motores en paralelo, de forma continua:

```
┌─────────────────────────────────────────────────────────────────┐
│                    bos Capacity Automaton                        │
│                                                                  │
│  ┌──────────────────┐    cada 60s    ┌──────────────────────┐   │
│  │  Motor de        │ ─────────────► │  Motor de            │   │
│  │  Observación     │                │  Proyección Dinámica  │   │
│  │  (Collector)     │                │  (Forecaster)        │   │
│  └──────────────────┘                └──────────┬───────────┘   │
│           │                                      │               │
│           │ métricas                             │ proyecciones  │
│           ▼                                      ▼               │
│      cap_db                          ┌──────────────────────┐   │
│  (serie temporal)                    │  Motor de Políticas   │   │
│                                      │  (Policy Engine)      │   │
│                                      └──────────┬───────────┘   │
│                                                  │               │
│                                      ┌───────────▼──────────┐   │
│                                      │  Motor de Acción      │   │
│                                      │  (Action Engine)      │   │
│                                      │  · Escala autónoma    │   │
│                                      │  · Alertas admin      │   │
│                                      │  · Control admisión   │   │
│                                      └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 El Ciclo de 60 Segundos

```
T+0s    Motor de Observación recolecta métricas de:
         Prometheus (todos los pods), Redis (INFO MEMORY),
         PostgreSQL (pg_stat_activity, pg_replication_slots),
         bKernel (WAL lag, DLQ size), bAuth (cache miss ratio),
         bos mismo (ctx_id activos, tenants activos, fichas instaladas)

T+5s    Motor de Proyección calcula:
         · Tasa de crecimiento real (últimas 24h, 7d, 30d)
         · Proyección a 7 días con intervalo de confianza
         · Proyección a 30 días con intervalo de confianza
         · Proyección a 90 días (para planificación de hardware)
         · Tiempo hasta WARNING de cada componente crítico
         · Tiempo hasta CRITICAL de cada componente crítico

T+15s   Motor de Políticas evalúa:
         · ¿Algún componente superó umbral WARNING?
         · ¿Alguna proyección predice CRITICAL en < 7 días?
         · ¿Hay requests de admisión pendientes que deben bloquearse?
         · ¿Hay acciones autónomas de scaling autorizadas?

T+20s   Motor de Acción ejecuta:
         · Escala horizontal pods autorizados (HPA override)
         · Emite alertas graduadas al administrador
         · Activa controles de admisión si aplica
         · Escribe en cap_db (serie temporal de capacidad)

T+60s   Siguiente ciclo
```

---

## 3. El Motor de Observación Continua

### 3.1 Métricas Recolectadas — Inventario Completo

El Motor de Observación recolecta las siguientes métricas en cada ciclo:

**Métricas de identidad y contexto:**

| Métrica | Fuente | Frecuencia |
|---|---|---|
| ctx_id activos totales | Redis DB1 `DBSIZE` | 60s |
| ctx_id activos por tenant | Redis `SCAN ctx:{tenant}:*` | 60s |
| Tasa de creación de ctx_id (nuevos/min) | bos audit log | 60s |
| Tasa de invalidación de ctx_id | bos audit log | 60s |
| context.promoted por minuto | bos audit log | 60s |
| Tenants activos (con ≥1 ctx_id) | Redis DB1 | 60s |
| Empresas activas por tenant | cap_db (agregado) | 5min |
| Sucursales activas por tenant | cap_db (agregado) | 5min |
| Usuarios únicos activos (últimas 24h) | bkernel_db.audit_events | 5min |

**Métricas de infraestructura:**

| Métrica | Fuente | Frecuencia |
|---|---|---|
| Redis DB1 memoria usada (bytes) | Redis `INFO MEMORY` | 60s |
| Redis DB1 memoria total disponible | Redis `INFO MEMORY` | 60s |
| Redis DB1 % ocupación | Calculado | 60s |
| Redis ops/s | Redis `INFO STATS` | 60s |
| Redis latencia cmd P99 | Redis `LATENCY HISTORY` | 60s |
| PostgreSQL conexiones activas / pool total | `pg_stat_activity` | 60s |
| PostgreSQL WAL slot lag (bytes) | `pg_replication_slots` | 60s |
| PostgreSQL tamaño de BDs por tenant | `pg_database_size()` | 5min |
| bKernel DLQ size | Prometheus `bkernel_dlq_size` | 60s |
| bKernel WAL processing lag P99 (ms) | Prometheus | 60s |
| Kong RPS total | Prometheus `kong_http_requests_total` | 60s |
| Kong latencia P99 (ms) | Prometheus | 60s |
| Kong CPU por pod | Kubernetes metrics-server | 60s |
| bAuth cache miss ratio | Prometheus `bauth_cache_miss_ratio` | 60s |
| MinIO storage usado (bytes) | MinIO metrics | 5min |
| MinIO storage disponible | MinIO metrics | 5min |
| Nodos Kubernetes (CPU/RAM disponible) | metrics-server | 60s |
| Pods en estado no-Ready | Kubernetes API | 60s |

**Métricas de negocio (ritmo de crecimiento):**

| Métrica | Fuente | Frecuencia |
|---|---|---|
| Nuevas empresas registradas (últimas 24h) | tryton_db por tenant | 5min |
| Nuevas sucursales registradas (últimas 24h) | tryton_db por tenant | 5min |
| Nuevos usuarios registrados (últimas 24h) | keycloak_db por realm | 5min |
| Nuevas fichas instaladas (últimas 24h) | bos audit log | 5min |
| Nuevos tenants (últimas 24h) | bos audit log | 5min |

### 3.2 El Registro de Estado de Capacidad (snapshot cada ciclo)

Cada ciclo de 60 segundos produce un snapshot en `cap_db.capacity_snapshots`
con el estado completo de todos los componentes. Es la serie temporal
que el Motor de Proyección usa para calcular tendencias.

---

## 4. El Motor de Proyección Dinámica

### 4.1 Por Qué las Proyecciones son Dinámicas

El plan original dice "500 tenants en GA v1". La realidad dice que
Tenant A creció de 150 a 800 empresas en 4 meses. El Motor de
Proyección detecta esa aceleración y recalcula el horizonte de capacidad
basándose en la tasa de crecimiento real observada, no en el plan.

### 4.2 Cálculo de Tasa de Crecimiento Real

El bos mantiene una ventana deslizante de observaciones para cada
componente crítico. Calcula la tendencia usando regresión lineal simple
sobre las últimas N observaciones:

```
Para Redis DB1 % ocupación:
  Observaciones (últimas 24h, una por hora):
  [42%, 44%, 45%, 47%, 48%, 50%, 52%, 53%, ...]

  Pendiente (tasa de crecimiento): +1.2% por hora
  Valor actual: 53%
  
  Proyección:
    En 7 días  → 53% + (1.2% × 168h) = 254%  → CRITICAL en ~4,7 días
    En 30 días → fuera de rango hace 3 semanas
  
  Alerta generada: "Redis DB1 alcanzará CRITICAL en ~4,7 días
                    a la tasa de crecimiento actual. Acción requerida."
```

### 4.3 Los Tres Horizontes de Proyección

| Horizonte | Propósito | Acción típica |
|---|---|---|
| **7 días** | Alertas operativas inmediatas. ¿Hay que actuar esta semana? | Scaling de pods, ajuste de Redis RAM, control de admisión |
| **30 días** | Planificación de capacidad. ¿Hay que pedir hardware o contratar más VPS? | Orden de hardware, presupuesto de cloud, decisión de arquitectura |
| **90 días** | Planificación estratégica. ¿La arquitectura actual alcanza o hay que rediseñar? | Migración de pgvector a Qdrant, añadir nodos K8s, ajuste de umbrales |

### 4.4 Intervalo de Confianza

El bos calcula el intervalo de confianza de sus proyecciones basándose
en la varianza de la tasa de crecimiento observada:

- **Alta confianza** (varianza baja): crecimiento estable y predecible.
  La proyección es fiable. El bos puede actuar de forma más agresiva.

- **Baja confianza** (varianza alta): crecimiento errático o datos insuficientes.
  El bos es más conservador: activa controles de admisión antes, recomienda
  al administrador en lugar de actuar autónomamente.

```
Ejemplo de salida del Forecaster:

  Componente:    Redis DB1
  Valor actual:  53% (4,2 GB / 8 GB)
  Tendencia 24h: +1.2%/hora  (varianza: baja → alta confianza)
  
  Proyección 7d:
    P50: 83%  ← cruzará WARNING (60%) en ~5,8 días
    P10: 71%  (escenario optimista)
    P90: 94%  ← escenario pesimista: CRITICAL antes de 5 días
  
  Recomendación: SCALE Redis RAM de 8GB → 16GB antes de 72 horas.
  Urgencia: ALTA
```

### 4.5 Detección de Aceleración

Además de la tendencia lineal, el bos detecta cambios de aceleración:
cuando la tasa de crecimiento en sí misma está aumentando (segunda
derivada positiva), emite una alerta de aceleración independientemente
de si los umbrales actuales están en zona segura.

```
Ejemplo:
  Semana 1: +50 empresas/semana en tenant-A
  Semana 2: +80 empresas/semana en tenant-A
  Semana 3: +130 empresas/semana en tenant-A
  
  El valor actual puede estar dentro de los límites,
  pero la aceleración indica que los límites se alcanzarán
  mucho antes de lo proyectado linealmente.
  
  Alerta: "Aceleración detectada en tenant-A. Tasa de crecimiento
           de empresas aumentó 160% en 3 semanas. Revisar límites
           de admisión para este tenant."
```

---

## 5. El Motor de Políticas de Capacidad

### 5.1 Las Políticas son Declarativas

Las políticas de capacidad se definen en YAML. El Motor de Políticas
las evalúa en cada ciclo y determina qué acciones tomar. No hay
lógica hardcodeada: todo el comportamiento del autómata está en los
archivos de política.

Las políticas tienen cuatro campos obligatorios:
- `condition`: qué condición activa la política
- `action`: qué hace el bos cuando la condición se cumple
- `governance`: nivel de autonomía (autónomo, recomendar, bloquear)
- `cooldown`: cuánto tiempo esperar antes de re-evaluar la misma política

### 5.2 Niveles de Governance

| Nivel | Nombre | Descripción |
|---|---|---|
| `autonomous` | Autónomo | El bos actúa solo, sin confirmación humana. Para acciones seguras y reversibles (escalar pods, ajustar HPA) |
| `recommend` | Recomendar | El bos presenta la recomendación al administrador con datos de respaldo. Humano decide. Para acciones con costo (más VPS, más RAM) |
| `block_and_alert` | Bloquear y alertar | El bos bloquea la admisión de nueva carga y alerta al administrador. Para situaciones donde admitir más carga garantiza degradación |
| `emergency` | Emergencia | El bos bloquea, alerta, y aplica la acción autónoma de mitigación más agresiva disponible. Solo cuando la degradación ya comenzó |

### 5.3 Catálogo de Políticas Predefinidas

```yaml
# ================================================================
# cap-policies/redis-db1-growth.yml
# ================================================================
id: "redis-db1-growth"
description: >
  Gestiona el crecimiento del Context Registry en Redis DB1.
  Redis DB1 es el componente más crítico: si se satura, el ctx_id
  lookup falla y todos los usuarios pierden sesión.
enabled: true
priority: 1   # 1 = más alta prioridad

conditions:
  - metric: "redis_db1_pct"
    threshold: 60
    operator: "gte"
    window: "5m"     # debe mantenerse >= 60% por 5 minutos (no pico transitorio)
    level: warning

  - metric: "redis_db1_pct"
    threshold: 80
    operator: "gte"
    window: "2m"
    level: critical

  - metric: "redis_db1_forecast_7d_p50"
    threshold: 75
    operator: "gte"
    level: forecast_warning   # la proyección a 7 días supera 75%

actions:
  on_warning:
    governance: recommend
    message: >
      Redis DB1 alcanzó {{redis_db1_pct}}% de ocupación ({{redis_db1_gb}} GB
      de {{redis_db1_total_gb}} GB). A la tasa actual, alcanzará CRITICAL
      en {{redis_db1_days_to_critical}} días.
    recommendation: >
      Ampliar RAM de Redis DB1 de {{redis_db1_total_gb}} GB a
      {{redis_db1_recommended_gb}} GB antes de {{redis_db1_deadline}}.
    data_attached:
      - redis_db1_growth_chart_7d
      - ctx_id_by_tenant_breakdown
      - top_5_tenants_by_ctx_id

  on_critical:
    governance: block_and_alert
    message: >
      Redis DB1 en {{redis_db1_pct}}% de ocupación. CRÍTICO.
      Activando control de admisión: bloqueo de nuevos ctx_id
      para tenants no-premium.
    autonomous_action:
      type: admission_control
      rule: "block_new_ctx_id_for_tier_standard"
      reason: "Redis DB1 capacity critical"
    escalation:
      - admin_dashboard_alert: CRITICAL
      - email: true
      - bosctl_event: capacity.redis_db1.critical

  on_forecast_warning:
    governance: recommend
    message: >
      Proyección a 7 días indica Redis DB1 en {{redis_db1_forecast_7d_p50}}%.
      Ventana de acción: {{redis_db1_days_to_warning}} días.
    recommendation: >
      Planificar ampliación de RAM Redis antes de {{redis_db1_forecast_date}}.
      Acción no urgente pero con ventana limitada.

cooldown: 3600   # no re-evaluar la misma acción por 1 hora

---
# ================================================================
# cap-policies/wal-bkernel-saturation.yml
# ================================================================
id: "wal-bkernel-saturation"
description: >
  bKernel es single-instance (un consumidor por slot WAL).
  Si se satura, la DLQ crece y los eventos fiscales y de contexto
  se retrasan. No escala horizontalmente — solo verticalmente.
enabled: true
priority: 1

conditions:
  - metric: "bkernel_wal_lag_p99_ms"
    threshold: 50
    operator: "gte"
    window: "3m"
    level: warning

  - metric: "bkernel_dlq_size"
    threshold: 100
    operator: "gte"
    level: warning

  - metric: "bkernel_wal_slot_lag_kb"
    threshold: 1024
    operator: "gte"     # > 1 MB
    level: critical

actions:
  on_warning:
    governance: recommend
    message: >
      bKernel WAL lag P99 = {{bkernel_wal_lag_p99_ms}}ms (SLO: 50ms).
      DLQ: {{bkernel_dlq_size}} eventos. WAL slot lag: {{bkernel_wal_slot_lag_kb}} KB.
    recommendation: >
      bKernel no escala horizontalmente. Acción: aumentar CPU/RAM
      del pod bkernel de {{bkernel_cpu_current}} → {{bkernel_cpu_recommended}} vCPU
      y de {{bkernel_ram_current}} GB → {{bkernel_ram_recommended}} GB.
      Revisar también si hay reglas YAML con alto costo de evaluación.

  on_critical:
    governance: block_and_alert
    message: >
      WAL slot lag > 1 MB. bKernel no puede procesar a la velocidad
      de escritura actual. Riesgo de pérdida de eventos fiscales.
    autonomous_action:
      type: admission_control
      rule: "reduce_write_throughput_non_fiscal"
      reason: "bKernel WAL saturation"
    escalation:
      - admin_dashboard_alert: CRITICAL
      - email: true
      - pagerduty: true   # si está configurado

cooldown: 1800

---
# ================================================================
# cap-policies/tenant-growth-acceleration.yml
# ================================================================
id: "tenant-growth-acceleration"
description: >
  Detecta cuando un tenant específico está creciendo más rápido
  de lo esperado y puede superar su cuota asignada antes del
  horizonte planificado. Actúa por tenant, no globalmente.
enabled: true
priority: 2

conditions:
  - metric: "tenant_empresa_count_growth_rate_weekly"
    threshold: 50           # creció > 50 empresas en la última semana
    operator: "gte"
    scope: "per_tenant"
    level: acceleration_detected

  - metric: "tenant_ctx_id_pico_vs_quota"
    threshold: 80           # está usando > 80% de su cuota de ctx_id
    operator: "gte"
    scope: "per_tenant"
    level: quota_warning

  - metric: "tenant_ctx_id_pico_vs_quota"
    threshold: 95
    operator: "gte"
    scope: "per_tenant"
    level: quota_critical

actions:
  on_acceleration_detected:
    governance: recommend
    message: >
      Tenant {{tenant_id}} creció {{tenant_empresas_delta}} empresas
      en la última semana ({{tenant_empresas_total}} totales).
      Proyección: alcanzará cuota máxima de {{tenant_quota_empresas}}
      en {{tenant_days_to_quota}} días.
    recommendation: >
      Revisar cuota del tenant {{tenant_id}} y negociar ampliación
      o tier upgrade. La plataforma necesita planificar capacidad
      adicional para este tenant.
    data_attached:
      - tenant_growth_chart_30d
      - tenant_resource_usage_breakdown

  on_quota_warning:
    governance: recommend
    message: >
      Tenant {{tenant_id}} usa {{tenant_ctx_id_pico_pct}}% de su
      cuota de ctx_id concurrentes. Cuota actual: {{tenant_quota_ctx_id}}.

  on_quota_critical:
    governance: block_and_alert
    message: >
      Tenant {{tenant_id}} en {{tenant_ctx_id_pico_pct}}% de cuota.
      Activando control de admisión: nuevos registros de empresa
      bloqueados para este tenant hasta ampliar cuota o reducir carga.
    autonomous_action:
      type: tenant_admission_control
      tenant: "{{tenant_id}}"
      rule: "block_new_empresa_registration"
      reason: "Tenant ctx_id quota at {{tenant_ctx_id_pico_pct}}%"

cooldown: 3600

---
# ================================================================
# cap-policies/kong-rps-saturation.yml
# ================================================================
id: "kong-rps-saturation"
description: >
  Kong escala horizontalmente. El bos puede ordenar más pods
  de forma autónoma dentro del presupuesto de nodos disponibles.
enabled: true
priority: 2

conditions:
  - metric: "kong_cpu_avg_pct"
    threshold: 70
    operator: "gte"
    window: "3m"
    level: warning

  - metric: "kong_cpu_avg_pct"
    threshold: 90
    operator: "gte"
    window: "1m"
    level: critical

actions:
  on_warning:
    governance: autonomous
    autonomous_action:
      type: hpa_override
      deployment: "kong"
      namespace: "kong-system"
      min_replicas: "{{kong_current_replicas + 2}}"
      reason: "kong_cpu_avg_pct = {{kong_cpu_avg_pct}}%"
    notification:
      admin_dashboard_alert: INFO
      message: >
        bos escaló Kong de {{kong_current_replicas}} a
        {{kong_new_replicas}} pods (CPU en {{kong_cpu_avg_pct}}%).

  on_critical:
    governance: autonomous
    autonomous_action:
      type: hpa_override
      deployment: "kong"
      max_replicas: "{{kong_max_replicas}}"
      reason: "kong_cpu_avg_pct critical = {{kong_cpu_avg_pct}}%"
    escalation:
      - admin_dashboard_alert: WARNING
      - message: >
          Kong escalado a máximo ({{kong_max_replicas}} pods).
          Si CPU sigue alta, revisar bottleneck upstream (bAuth, PostgreSQL).

cooldown: 300   # 5 minutos entre escalados de Kong

---
# ================================================================
# cap-policies/postgresql-connections.yml
# ================================================================
id: "postgresql-connections"
description: >
  PostgreSQL tiene un pool de conexiones limitado.
  Si se agota, las queries fallan con "too many connections".
  El bos actúa antes de que eso ocurra.
enabled: true
priority: 1

conditions:
  - metric: "pg_connections_pct"
    threshold: 80
    operator: "gte"
    window: "5m"
    level: warning

  - metric: "pg_connections_pct"
    threshold: 95
    operator: "gte"
    window: "1m"
    level: critical

actions:
  on_warning:
    governance: autonomous
    autonomous_action:
      type: pgbouncer_pool_resize
      increase_pct: 20
      reason: "pg_connections_pct = {{pg_connections_pct}}%"
    notification:
      admin_dashboard_alert: INFO
      message: >
        PgBouncer pool ampliado +20%. Conexiones PG en {{pg_connections_pct}}%.

  on_critical:
    governance: block_and_alert
    message: >
      PostgreSQL conexiones en {{pg_connections_pct}}%.
      Riesgo inmediato de "too many connections".
    autonomous_action:
      type: admission_control
      rule: "queue_non_critical_write_requests"
      reason: "PostgreSQL connections critical"

cooldown: 600

---
# ================================================================
# cap-policies/minio-storage-growth.yml
# ================================================================
id: "minio-storage-growth"
description: >
  MinIO almacena todos los recursos (imágenes, documentos, videos)
  de todos los tenants. El crecimiento de storage es predecible
  pero acumulativo e irreversible.
enabled: true
priority: 3

conditions:
  - metric: "minio_used_pct"
    threshold: 60
    operator: "gte"
    level: warning

  - metric: "minio_used_pct"
    threshold: 80
    operator: "gte"
    level: critical

  - metric: "minio_forecast_30d_p50"
    threshold: 80
    operator: "gte"
    level: forecast_warning

actions:
  on_warning:
    governance: recommend
    recommendation: >
      Storage MinIO en {{minio_used_pct}}% ({{minio_used_tb}} TB de
      {{minio_total_tb}} TB). Proyección 30 días: {{minio_forecast_30d_p50}}%.
      Planificar adición de nodos MinIO o expansión de discos.

  on_forecast_warning:
    governance: recommend
    recommendation: >
      En 30 días MinIO estará al {{minio_forecast_30d_p50}}%.
      Ventana de planificación: {{minio_days_to_warning}} días.
      Acción: solicitar hardware o expandir volúmenes antes de esa fecha.

cooldown: 86400   # re-evaluar cada 24 horas (storage crece lento)
```

---

## 6. Acciones Autónomas del bos

### 6.1 Qué puede hacer el bos sin aprobación humana

Las acciones autónomas son **reversibles, seguras y de bajo riesgo**.
El criterio es: si la acción resulta equivocada, se puede deshacer
en minutos sin impacto en producción.

| Acción autónoma | Condición que la activa | Reversible |
|---|---|---|
| Escalar pods Go services (HPA override) | CPU > 70% por 3min | ✅ Sí |
| Escalar pods Kong | CPU > 70% por 3min | ✅ Sí |
| Ajustar PgBouncer pool size | Conexiones PG > 80% | ✅ Sí |
| Aumentar TTL del BitMask cache en Redis | bAuth miss ratio > 20% | ✅ Sí |
| Activar control de admisión (soft) | Componente en WARNING prolongado | ✅ Sí |
| Registrar evento en cap_db | Siempre | ✅ Sí |
| Emitir alerta al administrador | Cualquier condición | ✅ Sí |

### 6.2 Qué NUNCA hace el bos sin aprobación humana

Las acciones irreversibles, con costo económico, o con impacto
sobre datos, **siempre requieren aprobación del administrador**:

| Acción que REQUIERE aprobación | Motivo |
|---|---|
| Ampliar RAM de Redis (más infraestructura) | Costo económico |
| Añadir nodos al cluster Kubernetes | Costo económico |
| Ampliar discos MinIO | Costo económico + operación de infraestructura |
| Eliminar tenants o datos | Irreversible |
| Modificar cuotas de tenants | Impacto contractual con el cliente |
| Cambiar la configuración de Keycloak | Impacto en autenticación de usuarios |
| Modificar reglas del Rule Engine de bKernel | Impacto en flujos fiscales |
| Suspender un tenant | Decisión de negocio |

### 6.3 Flujo de Aprobación para Acciones con Governance `recommend`

```
bos genera recomendación
    │
    ▼
Notificación en dashboard del administrador
    │  (con datos adjuntos: gráficas, proyecciones, costo estimado)
    │
    ▼
Administrador evalúa
    ├── Aprobar → bos ejecuta la acción
    ├── Rechazar → bos registra rechazo, vuelve a alertar
    │              si la condición empeora
    └── Posponer → bos vuelve a alertar en N horas
                   (configurable, default 24h)
```

---

## 7. El Sistema de Alertas y Recomendaciones

### 7.1 Niveles de Alerta

| Nivel | Color | Significado | Acción esperada del admin |
|---|---|---|---|
| `INFO` | Azul | El bos actuó autónomamente. Sin acción requerida | Revisar cuando sea conveniente |
| `ADVISORY` | Verde | Tendencia a observar. Sin acción inmediata | Leer en próxima sesión |
| `WARNING` | Amarillo | Acción planificada requerida en días/semanas | Planificar en esta semana |
| `ACTION_REQUIRED` | Naranja | Acción requerida en horas. El bos no puede resolver solo | Actuar hoy |
| `CRITICAL` | Rojo | Control de admisión activo. Degradación inminente o presente | Actuar ahora |
| `EMERGENCY` | Rojo parpadeante | Degradación en curso. Máxima prioridad | Intervención inmediata |

### 7.2 Anatomía de una Recomendación del bos

Cada recomendación emitida por el bos contiene:

```
================================================================
⚠️  RECOMENDACIÓN DE CAPACIDAD — bos Capacity Automaton
================================================================
Código:       CAP-2026-06-12-0042
Nivel:        ACTION_REQUIRED
Componente:   Redis DB1 (Context Registry)
Timestamp:    2026-06-12T14:37:22Z

SITUACIÓN ACTUAL
  Ocupación actual:  67% (5,36 GB / 8 GB)
  ctx_id activos:    7.623
  Tasa crecimiento:  +1.4%/hora (últimas 6h, confianza: ALTA)

PROYECCIÓN
  En 24 horas:       91%  → superará CRITICAL
  En 48 horas:       > 100% → saturación
  Intervalo confianza (P10-P90): 85% — 96% en 24h

CAUSA RAÍZ
  Tenant skull/maya registró 312 nuevas empresas en las últimas
  6 horas (tasa 5x sobre su promedio histórico). El crecimiento
  de ctx_id está acelerado en este tenant específico.

ACCIÓN RECOMENDADA
  Opción A (urgente, horas):
    Ampliar Redis DB1 RAM: 8 GB → 16 GB
    Impacto operativo: reinicio de Redis (< 30s con Cluster)
    Costo estimado: +USD 45/mes (infraestructura)

  Opción B (mientras se ejecuta Opción A):
    bos activa control de admisión para tenant skull/maya:
    bloqueo de nuevos registros de empresa hasta resolución.
    Esto requiere comunicación al cliente.

  Opción C (si no se puede ampliar RAM):
    Reducir TTL de ctx_id inactivos de 8h → 2h
    Efecto: libera ~25% de espacio en Redis DB1
    Sin costo. El bos puede ejecutar esto autónomamente si autoriza.

DATOS ADJUNTOS
  · Gráfica Redis DB1 % últimas 24h (sparkline)
  · Top 5 tenants por ctx_id activos
  · Desglose de crecimiento tenant skull/maya (empresas, últ. 7 días)
  · Comparación con SLO: ctx_id lookup P99 aún en 2ms (saludable)

ACCIONES DISPONIBLES
  [ Aprobar Opción A ]  [ Aprobar Opción C (autónoma) ]  
  [ Activar Opción B (control admisión) ]  [ Posponer 4h ]
================================================================
```

### 7.3 Canales de Notificación

| Canal | Nivel mínimo | Configuración |
|---|---|---|
| Dashboard bos (Core UI, bosctl) | INFO | Siempre activo |
| Email al administrador | WARNING | Configurable por tenant |
| Webhook (Slack, Teams, etc.) | WARNING | URL configurable |
| SMS / PagerDuty | CRITICAL | Configurable |
| bosctl event stream | Todos | Siempre activo |

---

## 8. Controles de Admisión — El bos como Portero

### 8.1 Filosofía

> Es mejor decirle "no" a un registro nuevo que degradar el servicio
> a los miles de usuarios que ya están operando.

El control de admisión es la última línea de defensa antes de la
degradación. No es un fallo del sistema: es el sistema funcionando
correctamente bajo presión.

### 8.2 Jerarquía de Controles de Admisión

El bos aplica controles en orden de granularidad, desde el más
fino al más grueso. Siempre aplica el mínimo necesario:

```
Nivel 1 (más fino):    Bloquear nuevas empresas para tenant X
Nivel 2:               Bloquear nuevas sucursales para tenant X
Nivel 3:               Bloquear nuevos usuarios para tenant X
Nivel 4:               Bloquear nuevos ctx_id para tier standard (no premium)
Nivel 5:               Limitar RPS para tenants non-critical
Nivel 6 (más grueso):  Bloquear onboarding de nuevos tenants
```

El bos nunca aplica el Nivel 6 si el Nivel 1 es suficiente.

### 8.3 Implementación Técnica

Los controles de admisión se implementan en dos capas:

**Capa 1 — Kong Plugin:**
El plugin SBOS-Context en Kong consulta el estado de admisión del
bos en cada request. Si el control está activo para ese tenant
y ese tipo de operación, Kong retorna:

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32010,
    "message": "Capacidad temporalmente limitada para nuevos registros",
    "data": {
      "admission_control": true,
      "reason": "platform_capacity_warning",
      "retry_after": "2026-06-12T18:00:00Z",
      "contact": "admin@sbos.io"
    }
  }
}
```

**Capa 2 — bos Context API:**
La Context API del bos rechaza la creación de nuevos ctx_id si
el control de admisión de Nivel 4 o superior está activo.

### 8.4 Transparencia con el Cliente

Cuando el control de admisión está activo, el administrador del
tenant recibe una notificación clara con:

- Qué operaciones están bloqueadas temporalmente
- Por qué (sin exponer detalles internos de infraestructura)
- Cuándo se espera resolver
- Qué puede hacer el administrador del tenant (reducir carga,
  contactar al equipo de plataforma para upgrade de cuota)

---

## 9. Base de Datos de Capacidad — cap_db

### 9.1 DDL Completo

```sql
CREATE DATABASE cap_db;
\c cap_db;

-- ================================================================
-- Serie temporal de snapshots de capacidad (cada 60s)
-- ================================================================
CREATE TABLE capacity_snapshots (
    id                      BIGSERIAL       PRIMARY KEY,
    ts                      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- Context Plane
    ctx_id_activos_total    INTEGER,
    ctx_id_creados_min      INTEGER,        -- nuevos en el último minuto
    ctx_id_invalidados_min  INTEGER,
    tenants_activos         INTEGER,

    -- Redis DB1
    redis_db1_usado_mb      NUMERIC(10,2),
    redis_db1_total_mb      NUMERIC(10,2),
    redis_db1_pct           NUMERIC(5,2),
    redis_ops_por_s         NUMERIC(12,2),
    redis_lat_p99_ms        NUMERIC(10,3),

    -- PostgreSQL
    pg_conexiones_activas   INTEGER,
    pg_conexiones_total     INTEGER,
    pg_conexiones_pct       NUMERIC(5,2),
    pg_wal_slot_lag_kb      NUMERIC(12,2),

    -- bKernel
    bkernel_wal_lag_p99_ms  NUMERIC(10,3),
    bkernel_dlq_size        INTEGER,
    bkernel_eventos_por_s   NUMERIC(12,2),

    -- Kong
    kong_rps_total          NUMERIC(12,2),
    kong_lat_p99_ms         NUMERIC(10,3),
    kong_pods_activos       INTEGER,
    kong_cpu_avg_pct        NUMERIC(5,2),

    -- bAuth
    bauth_hit_p99_ms        NUMERIC(10,3),
    bauth_miss_ratio_pct    NUMERIC(5,2),

    -- MinIO
    minio_usado_gb          NUMERIC(12,2),
    minio_total_gb          NUMERIC(12,2),
    minio_usado_pct         NUMERIC(5,2),

    -- K8s
    k8s_nodos_ready         INTEGER,
    k8s_cpu_disponible_pct  NUMERIC(5,2),
    k8s_ram_disponible_pct  NUMERIC(5,2)

) PARTITION BY RANGE (ts);

-- Partición por día para eficiencia de consultas
CREATE TABLE capacity_snapshots_y2026m06
    PARTITION OF capacity_snapshots
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

CREATE INDEX idx_cap_snap_ts ON capacity_snapshots (ts DESC);

-- ================================================================
-- Métricas de crecimiento por tenant (cada 5 minutos)
-- ================================================================
CREATE TABLE tenant_growth_metrics (
    id                  BIGSERIAL       PRIMARY KEY,
    ts                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    tenant_id           VARCHAR(64)     NOT NULL,

    -- Dimensiones del tenant
    empresas_total      INTEGER,
    sucursales_total    INTEGER,
    usuarios_total      INTEGER,
    fichas_instaladas   INTEGER,

    -- Actividad
    ctx_id_activos      INTEGER,        -- en este momento
    ctx_id_pico_24h     INTEGER,        -- máximo en las últimas 24h
    rps_promedio_5m     NUMERIC(12,2),  -- promedio de los últimos 5 minutos
    rps_pico_5m         NUMERIC(12,2),

    -- Crecimiento (delta respecto al snapshot anterior)
    delta_empresas      INTEGER,
    delta_sucursales    INTEGER,
    delta_usuarios      INTEGER,
    delta_ctx_id        INTEGER,

    -- Cuotas
    cuota_empresas      INTEGER,        -- límite configurado para este tenant
    cuota_ctx_id        INTEGER,
    cuota_storage_gb    NUMERIC(10,2),
    cuota_empresas_pct  NUMERIC(5,2),   -- % de cuota usado
    cuota_ctx_id_pct    NUMERIC(5,2),

    -- Control de admisión
    admission_level     INTEGER         DEFAULT 0,  -- 0=libre, 1-6=ver §8.2
    admission_reason    VARCHAR(128)
) PARTITION BY RANGE (ts);

CREATE INDEX idx_tgm_tenant_ts ON tenant_growth_metrics (tenant_id, ts DESC);

-- ================================================================
-- Proyecciones calculadas por el Forecaster (cada ciclo)
-- ================================================================
CREATE TABLE capacity_forecasts (
    id                  SERIAL          PRIMARY KEY,
    ts                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    componente          VARCHAR(64)     NOT NULL,
    metrica             VARCHAR(64)     NOT NULL,

    -- Valor actual
    valor_actual        NUMERIC(14,4)   NOT NULL,
    unidad              VARCHAR(20),

    -- Proyecciones
    forecast_7d_p10     NUMERIC(14,4),
    forecast_7d_p50     NUMERIC(14,4),
    forecast_7d_p90     NUMERIC(14,4),

    forecast_30d_p10    NUMERIC(14,4),
    forecast_30d_p50    NUMERIC(14,4),
    forecast_30d_p90    NUMERIC(14,4),

    forecast_90d_p50    NUMERIC(14,4),

    -- Tendencia
    tasa_crecimiento_h  NUMERIC(10,6),  -- por hora
    confianza           VARCHAR(10)     CHECK (confianza IN ('alta','media','baja')),
    aceleracion         BOOLEAN         DEFAULT FALSE,

    -- Umbrales
    dias_hasta_warning  NUMERIC(8,2),
    dias_hasta_critical NUMERIC(8,2),
    umbral_warning      NUMERIC(14,4),
    umbral_critical     NUMERIC(14,4)
);

CREATE INDEX idx_forecasts_comp_ts ON capacity_forecasts (componente, ts DESC);

-- ================================================================
-- Registro de alertas y recomendaciones emitidas
-- ================================================================
CREATE TABLE capacity_alerts (
    id                  SERIAL          PRIMARY KEY,
    codigo              VARCHAR(32)     NOT NULL UNIQUE,  -- CAP-{YYYY}-{MM}-{DD}-{NNNN}
    ts                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    nivel               VARCHAR(20)     NOT NULL
                        CHECK (nivel IN ('info','advisory','warning',
                                         'action_required','critical','emergency')),
    componente          VARCHAR(64)     NOT NULL,
    politica_id         VARCHAR(64),    -- qué política la generó
    tenant_id           VARCHAR(64),    -- null si es alerta global

    mensaje             TEXT            NOT NULL,
    recomendacion       TEXT,
    datos_adjuntos      JSONB,          -- gráficas, breakdowns, proyecciones

    -- Ciclo de vida
    estado              VARCHAR(20)     NOT NULL DEFAULT 'pending'
                        CHECK (estado IN ('pending','acknowledged','approved',
                                          'rejected','postponed','resolved','expired')),
    resuelto_at         TIMESTAMPTZ,
    resuelto_por        VARCHAR(64),
    accion_tomada       TEXT,
    postponed_until     TIMESTAMPTZ
);

CREATE INDEX idx_alerts_estado ON capacity_alerts (estado, ts DESC);
CREATE INDEX idx_alerts_tenant ON capacity_alerts (tenant_id, ts DESC);

-- ================================================================
-- Registro de acciones autónomas del bos
-- ================================================================
CREATE TABLE autonomous_actions (
    id                  SERIAL          PRIMARY KEY,
    ts                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    alert_id            INTEGER         REFERENCES capacity_alerts(id),
    politica_id         VARCHAR(64),

    tipo                VARCHAR(64)     NOT NULL,
    descripcion         TEXT            NOT NULL,
    parametros          JSONB,
    resultado           VARCHAR(20)     CHECK (resultado IN ('success','failed','reverted')),
    resultado_detalle   TEXT,
    revertido_at        TIMESTAMPTZ,
    revertido_por       VARCHAR(64)
);

-- ================================================================
-- Registro de controles de admisión activos
-- ================================================================
CREATE TABLE admission_controls (
    id                  SERIAL          PRIMARY KEY,
    activado_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    desactivado_at      TIMESTAMPTZ,
    activo              BOOLEAN         NOT NULL DEFAULT TRUE,

    nivel               INTEGER         NOT NULL CHECK (nivel BETWEEN 1 AND 6),
    tenant_id           VARCHAR(64),    -- null si aplica globalmente
    regla               VARCHAR(128)    NOT NULL,
    razon               TEXT            NOT NULL,
    alert_id            INTEGER         REFERENCES capacity_alerts(id),

    -- Estadísticas
    requests_bloqueados BIGINT          DEFAULT 0,
    activado_por        VARCHAR(64)     DEFAULT 'bos-automaton'
);
```

### 9.2 Vistas Operativas

```sql
-- Estado de capacidad en tiempo real (el dashboard del admin lo consume)
CREATE VIEW v_capacity_current AS
WITH latest AS (
    SELECT DISTINCT ON (TRUE) *
    FROM capacity_snapshots
    ORDER BY ts DESC
)
SELECT
    ts                                          AS "Última medición",
    ctx_id_activos_total                        AS "ctx_id activos",
    ROUND(redis_db1_pct::numeric, 1) || '%'     AS "Redis DB1 %",
    ROUND(pg_conexiones_pct::numeric, 1) || '%' AS "PG conexiones %",
    ROUND(bkernel_wal_lag_p99_ms::numeric, 1) || 'ms' AS "WAL P99",
    bkernel_dlq_size                            AS "DLQ size",
    ROUND(kong_rps_total::numeric)              AS "Kong RPS",
    ROUND(minio_usado_pct::numeric, 1) || '%'   AS "MinIO %",
    k8s_nodos_ready                             AS "K8s nodos"
FROM latest;

-- Tenants que más crecieron en las últimas 24h
CREATE VIEW v_fastest_growing_tenants AS
SELECT
    tenant_id,
    MAX(empresas_total)      AS empresas_actuales,
    SUM(delta_empresas)      AS nuevas_empresas_24h,
    MAX(ctx_id_pico_24h)     AS ctx_id_pico,
    MAX(cuota_empresas_pct)  AS pct_cuota_empresas,
    MAX(admission_level)     AS nivel_control_admision
FROM tenant_growth_metrics
WHERE ts >= NOW() - INTERVAL '24 hours'
GROUP BY tenant_id
ORDER BY nuevas_empresas_24h DESC
LIMIT 10;

-- Alertas pendientes de acción por parte del administrador
CREATE VIEW v_pending_alerts AS
SELECT
    codigo,
    nivel,
    componente,
    tenant_id,
    mensaje,
    recomendacion,
    ts                    AS generada_at,
    NOW() - ts            AS edad
FROM capacity_alerts
WHERE estado IN ('pending', 'postponed')
  AND (postponed_until IS NULL OR postponed_until <= NOW())
ORDER BY
    CASE nivel
        WHEN 'emergency'       THEN 1
        WHEN 'critical'        THEN 2
        WHEN 'action_required' THEN 3
        WHEN 'warning'         THEN 4
        WHEN 'advisory'        THEN 5
        WHEN 'info'            THEN 6
    END,
    ts ASC;
```

---

## 10. Dashboard del Administrador

### 10.1 Lo que el Administrador Ve en Tiempo Real

El Core UI del bos expone un dashboard de capacidad que se actualiza
cada 60 segundos con los datos del Motor de Observación:

**Panel 1 — Estado Global (semáforo):**
Un semáforo por componente crítico. Verde / Amarillo / Rojo.
Orden: Redis DB1 · bKernel WAL · PostgreSQL · Kong · bAuth · MinIO · K8s

**Panel 2 — Alertas Pendientes:**
Lista priorizada de alertas que requieren acción del administrador,
con su nivel, componente, edad y botones de acción (Aprobar / Rechazar / Posponer).

**Panel 3 — Tendencias de Crecimiento (sparklines 24h):**
ctx_id activos · Redis DB1 % · Kong RPS · WAL lag · DLQ size

**Panel 4 — Top Tenants por Crecimiento:**
Los 10 tenants con mayor delta de empresas / ctx_id en las últimas 24h.
Con indicador visual si alguno tiene control de admisión activo.

**Panel 5 — Proyecciones a 7 días:**
Para cada componente crítico: valor actual → valor proyectado P50
con semáforo de urgencia (¿cuándo cruza WARNING? ¿cuándo cruza CRITICAL?).

**Panel 6 — Acciones Autónomas Recientes:**
Log de las últimas N acciones que el bos tomó autónomamente,
con resultado (éxito / fallo / revertida).

### 10.2 Comandos bosctl para el Administrador

Ver la sección §12 para el catálogo completo.

---

## 11. Integración con los Daemons

El bos Capacity Automaton obtiene datos directamente de cada daemon:

| Daemon | Qué aporta al bos | Canal |
|---|---|---|
| **bKernel** | WAL lag, DLQ size, eventos/s, errores de reglas | Prometheus metrics + Redis pub/sub |
| **bAuth** | Cache miss ratio, BitMask evaluation latency | Prometheus metrics |
| **bhnexus** | Conexiones WebSocket activas (banexus conectados) | Prometheus metrics |
| **biedata** | Redis Stream consumer lag, operaciones fiscales/min | Prometheus metrics |
| **bSearch** | Qdrant RAM, Typesense docs indexed, query latency | Prometheus metrics |
| **bCompass** | Rutas activas, aprobaciones HITL pendientes, LLM latency | Prometheus metrics |
| **Kong** | RPS, latencia P99, errores 4xx/5xx por tenant | Prometheus metrics |
| **Keycloak** | Logins/min, sesiones activas, reinos activos | Keycloak metrics endpoint |

Además, el bos consulta directamente:
- Kubernetes metrics-server (CPU/RAM de nodos y pods)
- Redis `INFO` y `LATENCY` commands
- PostgreSQL `pg_stat_activity`, `pg_replication_slots`, `pg_database_size()`
- MinIO `/minio/health/cluster` y metrics endpoint

---

## 12. Comandos bosctl de Capacidad

```bash
# ── Observación en tiempo real ──────────────────────────────────

# Dashboard de capacidad en terminal (actualización cada 10s)
bosctl capacity watch

# Estado puntual de todos los componentes
bosctl capacity status

# Ver proyecciones a 7/30/90 días
bosctl capacity forecast --horizon=7d
bosctl capacity forecast --horizon=30d --component=redis-db1

# Top tenants por crecimiento (últimas 24h)
bosctl capacity top-tenants --hours=24

# Ver tendencia de un componente específico
bosctl capacity trend redis-db1 --hours=48

# ── Alertas y recomendaciones ────────────────────────────────────

# Listar alertas pendientes de acción
bosctl capacity alerts --status=pending

# Ver detalle de una alerta
bosctl capacity alert CAP-2026-06-12-0042

# Aprobar una recomendación
bosctl capacity alert CAP-2026-06-12-0042 --approve

# Rechazar (con motivo)
bosctl capacity alert CAP-2026-06-12-0042 --reject \
  --reason="Escalaremos mañana, ya coordinado con infra"

# Posponer N horas
bosctl capacity alert CAP-2026-06-12-0042 --postpone=4h

# ── Control de admisión ──────────────────────────────────────────

# Ver controles de admisión activos
bosctl capacity admission list

# Activar manualmente un control de admisión
bosctl capacity admission activate \
  --level=1 \
  --tenant=skull \
  --rule=block_new_empresa_registration \
  --reason="Manutencion programada"

# Desactivar un control de admisión
bosctl capacity admission deactivate --id=42

# ── Acciones manuales de capacidad ──────────────────────────────

# Forzar re-evaluación de todas las políticas ahora
bosctl capacity evaluate --now

# Ver log de acciones autónomas recientes
bosctl capacity actions --last=20

# Revertir una acción autónoma
bosctl capacity action revert --id=17 --reason="Falso positivo"

# ── Gestión de cuotas por tenant ─────────────────────────────────

# Ver cuotas de un tenant
bosctl capacity quota skull

# Actualizar cuota de un tenant (requiere aprobación OWNER)
bosctl capacity quota skull --set-empresas=500 --set-ctx-id=10000

# Ver todos los tenants cerca de su cuota
bosctl capacity quota --warning-pct=80
```

---

## 13. Configuración de Políticas YAML

### 13.1 Dónde Viven las Políticas

```
/etc/sbos/cap-policies/
├── redis-db1-growth.yml
├── wal-bkernel-saturation.yml
├── tenant-growth-acceleration.yml
├── kong-rps-saturation.yml
├── postgresql-connections.yml
├── minio-storage-growth.yml
├── k8s-node-capacity.yml
├── bauth-cache-saturation.yml
└── custom/
    └── {tenant-specific-policies}.yml
```

### 13.2 Recarga en Caliente

El bos recarga las políticas sin reinicio:

```bash
# Recargar todas las políticas
bosctl capacity policies reload

# Validar sintaxis de una política antes de cargarla
bosctl capacity policies validate /etc/sbos/cap-policies/redis-db1-growth.yml

# Listar políticas activas
bosctl capacity policies list

# Desactivar una política temporalmente
bosctl capacity policies disable redis-db1-growth --reason="Mantenimiento Redis"
```

### 13.3 Cuotas por Tenant — Configuración

Las cuotas se definen en el seed.yml del tenant y pueden modificarse
sin reiniciar el bos:

```yaml
# En el seed.yml del tenant (o en un patch posterior)
tenant:
  id: skull
  quotas:
    empresas_max:        300     # máximo de empresas registradas
    sucursales_max:      2700    # máximo de sucursales
    usuarios_max:        270000  # máximo de usuarios en Keycloak
    ctx_id_concurrentes: 81000   # máximo de ctx_id simultáneos
    storage_gb:          500     # GB en MinIO
    rps_max:             50000   # RPS máximo desde Kong
    tier:                premium # standard | premium | enterprise
    # Los tenants premium no son bloqueados por admission control Nivel 4
    # Los tenants enterprise tienen SLA garantizado y no pueden bloquearse
    # sin aprobación explícita del administrador de plataforma
```

---

*SBOS-BOS-CAP-001 v1.0 · Junio 2026 · SKULL*  
*El bos no es solo un instalador. Es el autómata soberano que garantiza*  
*que el sistema nunca se cae por falta de capacidad no anticipada.*
