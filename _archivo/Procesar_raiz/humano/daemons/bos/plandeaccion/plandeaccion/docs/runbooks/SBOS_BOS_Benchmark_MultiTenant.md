# SBOS — Plan de Pruebas de Carga Multi-Tenant
## Benchmarks, Umbrales y Criterios de Saturación

**Documento:** SBOS-PERF-001  
**Versión:** 1.0  
**Estado:** Normativo Activo  
**Fecha:** 2026-06-12  
**Clasificación:** Interno · Ingeniería + Arquitectura  

---

## 1. Propósito

"Está diseñado para escalar" no sustituye a un benchmark concreto.

Este documento define formalmente:

1. Cuántos tenants simultáneos debe soportar el sistema en cada fase.
2. Qué métricas definen el techo de capacidad (SLO/SLA).
3. En qué punto satura cada componente crítico y cuál es la acción a tomar.
4. El plan de ejecución de pruebas de carga con herramientas y escenarios concretos.

---

## 2. Definiciones de Capacidad por Fase

### 2.1 Capacidad Objetivo por Fase de Producción

| Fase | Tenants activos | ctx_id concurrentes | RPS JSON-RPC (pico) | WAL eventos/s |
|---|---|---|---|---|
| **Alpha** (Fase 1-2) | 5 | 50 | 500 | 200 |
| **Beta** (Fase 3-4) | 50 | 500 | 5.000 | 2.000 |
| **GA v1** (Fase 5) | 500 | 5.000 | 50.000 | 20.000 |
| **GA v2** (post-Fase 5) | 5.000 | 50.000 | 500.000 | 200.000 |

Cada fase tiene sus propios benchmarks. Los umbrales de GA v1 son los
criterios de aceptación para producción inicial.

### 2.2 SLO — Service Level Objectives (lo que el sistema garantiza)

Estos son los umbrales que el sistema debe cumplir bajo carga normal (P50)
y carga de pico (P99). Una prueba de carga pasa solo si todos los SLO se
cumplen simultáneamente bajo la carga de la fase correspondiente.

| Métrica | P50 objetivo | P99 objetivo | Límite absoluto |
|---|---|---|---|
| Latencia JSON-RPC end-to-end | < 30ms | < 150ms | 500ms |
| Latencia lookup ctx_id Redis | < 1ms | < 5ms | 20ms |
| Latencia WAL → bKernel (CDC) | < 5ms | < 50ms | 100ms |
| Latencia bAuth BitMask (cache hit) | < 5ms | < 15ms | 50ms |
| Latencia bAuth BitMask (cache miss) | < 15ms | < 40ms | 100ms |
| Latencia context.promoted end-to-end | < 15ms | < 40ms | 100ms |
| Tasa de error gRPC global | < 0.01% | < 0.1% | 1% |
| ctx_id lookup failures | 0 | < 0.01% | 0.1% |
| Tiempo alta de tenant (bosctl deploy) | < 30s | < 90s | 300s |
| Tiempo instalación de ficha (single) | < 60s | < 180s | 600s |

### 2.3 Criterios de Saturación por Componente

La saturación ocurre cuando un componente no puede absorber más carga
sin degradar los SLO. Cada componente tiene su umbral y su acción.

| Componente | Métrica de saturación | Umbral WARNING | Umbral CRITICAL | Acción |
|---|---|---|---|---|
| **Redis — Context Registry** | Memoria usada | 60% | 80% | Escalar Redis (más RAM) → evaluar Redis Cluster con más shards |
| **Redis — Streams** | Consumer lag (biedata) | > 1.000 eventos | > 10.000 eventos | Escalar biedata horizontalmente |
| **PostgreSQL — bkernel_db** | Latencia de escritura P99 | > 10ms | > 50ms | Revisar índices, escalar vertical PG |
| **PostgreSQL — tryton_db** | Conexiones activas | > 80% pool | > 95% pool | Añadir PgBouncer, escalar replicas de lectura |
| **bKernel WAL** | Lag del slot de replicación | > 10.000 bytes | > 1MB | Revisar rules pesadas, escalar vertical |
| **Kong — Gateway** | CPU por pod | > 70% | > 90% | HPA activo, añadir pods Kong |
| **bAuth** | Cache miss ratio | > 20% | > 40% | Aumentar TTL de BitMask cache en Redis |
| **bos DAG topológico** | Tiempo instalación N fichas en paralelo | > 90s por tenant | > 300s por tenant | Reducir paralelismo, revisar dependencias |
| **Website Engine** | Tiempo de respuesta P99 | > 200ms | > 500ms | HPA, revisar cache de CTX assets |

---

## 3. Arquitectura de las Pruebas

### 3.1 Entorno de Pruebas

Las pruebas de carga se ejecutan en un entorno **dedicado** de staging que
replica la topología de producción. No se ejecutan en producción.

```
Entorno staging de carga
├── Kubernetes: misma versión y configuración que producción
├── PostgreSQL: misma configuración (Patroni HA)
├── Redis: misma configuración (Cluster mode)
├── MinIO: misma configuración (distribuido)
├── Kong + Keycloak: misma versión
├── bos + bKernel + bAuth + biedata: mismos binarios que producción
└── Observabilidad: Prometheus + Grafana + Loki completos
     (necesario para medir durante la prueba)
```

**Importante:** Un entorno de staging sub-dimensionado invalida los
resultados. El entorno debe ser equivalente en especificaciones de hardware.

### 3.2 Herramientas

| Herramienta | Uso |
|---|---|
| **k6** (Grafana) | Generador de carga HTTP/WebSocket. Scripts en JavaScript. Integración nativa con Grafana |
| **bosctl** | Provisionar tenants de prueba vía scripts bash sobre la API del bos |
| **psql + pgbench** | Benchmarks directos sobre PostgreSQL (WAL throughput, latencia de escritura) |
| **redis-benchmark** | Saturación del Context Registry Redis (GET/SET sobre ctx_id) |
| **prometheus + grafana** | Recolección y visualización de métricas durante las pruebas |
| **k6 Cloud / xk6-distributed** | Pruebas distribuidas desde múltiples orígenes (simula carga geográfica real) |

---

## 4. Escenarios de Prueba

### Escenario 1 — Baseline de tenant único

**Objetivo:** Establecer la línea base. Un solo tenant, carga creciente.

**Setup:**
```bash
bosctl deploy fixtures/tenant-baseline.yml  # 1 tenant, 1 empresa, 1 sucursal
```

**k6 script:**
```javascript
// Ramp: 0 → 100 VUs en 60s, sostener 300s, bajar en 60s
export const options = {
  stages: [
    { duration: '60s', target: 100 },
    { duration: '300s', target: 100 },
    { duration: '60s', target: 0 },
  ],
  thresholds: {
    'http_req_duration{method:POST}': ['p(99)<150'],  // SLO P99
    'http_req_failed': ['rate<0.001'],                 // SLO error rate
  },
};

export default function () {
  // Simula flujo real: login → ctx_id → operación POS → logout
  const loginRes = http.post(`${BASE}/auth/login`, loginPayload);
  const ctxId = loginRes.json('ctx_id');

  http.post(`${BASE}/api/v1/rpc`, {
    jsonrpc: '2.0',
    method: 'pos.venta.CerrarVenta',
    params: { ctx_id: ctxId, ...ventaPayload },
  });
}
```

**Criterio de paso:** Todos los SLO del §2.2 cumplidos a 100 usuarios virtuales.

---

### Escenario 2 — Escalamiento por tenants (el benchmark crítico)

**Objetivo:** Encontrar el punto en que agregar más tenants degrada los SLO.
Esto responde directamente a la brecha: cuántos tenants soporta el sistema.

**Setup:** Provisionar tenants en bloques progresivos.

```bash
# Fixture generator — crea N tenants con empresas y sucursales reales
for n in 10 50 100 250 500 1000; do
  python3 fixtures/gen_tenants.py --count=$n --out=fixtures/tenants_$n.yml
  bosctl deploy fixtures/tenants_$n.yml
  sleep 30  # esperar estabilización
  k6 run --tag tenants=$n scenarios/multitenant_load.js
done
```

**Métricas observadas en cada iteración:**

- Latencia P99 JSON-RPC end-to-end
- Latencia P99 ctx_id lookup (Redis GET)
- Memoria Redis DB1 (Context Registry)
- CPU/RAM bAuth
- WAL lag (slot de replicación)
- Tiempo de resolución de DAG en bos (bosctl deploy N fichas)

**Resultado esperado del benchmarking:**

La prueba produce una curva de latencia vs. número de tenants. El punto de
inflexión donde la pendiente de latencia supera el umbral WARNING define
la capacidad nominal del sistema en esa configuración de hardware.

```
Ejemplo de curva esperada:

Latencia P99 ctx_id lookup
│
5ms ─────────────────────────────────────── WARNING (5ms)
│                                   ↗ (Redis RAM 60% → saturación inminente)
1ms ─────────────────────────────────────── (rango saludable)
│                    ─────────────────
│         ──────────
│  ────────
└─────────────────────────────────────────────────────────
 10      50     100     250     500    1000  tenants
```

El punto de inflexión de esta curva (cuando el P99 supera el WARNING)
define el límite operativo sin intervención de scaling.

---

### Escenario 3 — Saturación del Context Registry (Redis)

**Objetivo:** Determinar con exactitud cuántos ctx_id concurrentes satura Redis DB1.

**Setup:** Crear ctx_id activos sin que expiren (TTL largo para el test).

```bash
# Usar redis-benchmark para saturación directa
redis-benchmark -h $REDIS_HOST -p 6379 -n 1000000 \
  -c 500 \
  -t get \
  --dbnum 1 \
  -k 1
```

Y con k6 simulando el flujo real:

```javascript
// Mantener N sesiones activas simultáneamente
// y medir degradación del lookup por volumen
const CTX_IDS = Array.from({length: TARGET_CONCURRENT}, (_, i) => `ctx-load-test-${i}`);

export default function () {
  const ctx = CTX_IDS[Math.floor(Math.random() * CTX_IDS.length)];
  http.get(`${BOS_HOST}/api/v1/context/${ctx}`);
}
```

**Umbrales medidos:**

| ctx_id concurrentes | Latencia GET esperada | Memoria Redis DB1 | Estado |
|---|---|---|---|
| 1.000 | < 1ms | ~50MB | ✅ Nominal |
| 5.000 | < 1ms | ~250MB | ✅ Nominal |
| 10.000 | < 2ms | ~500MB | ✅ Nominal |
| 25.000 | < 3ms | ~1.2GB | ⚠️ Monitorear |
| 50.000 | < 5ms | ~2.5GB | ⚠️ WARNING |
| 100.000 | TBD | TBD | 🔴 Medir en prueba real |

*Los valores de 50.000+ deben medirse en la prueba real. Los valores de 1.000-25.000
son proyecciones basadas en el tamaño promedio del payload JSON del ctx_id (~500 bytes
+ overhead Redis de ~200 bytes = ~700 bytes por clave).*

**Punto de saturación esperado:** Redis saturará por RAM antes de saturar por CPU.
Con 4GB dedicados a Redis DB1 → estimación de ~5M de claves → equivalente a
~5M de ctx_id activos simultáneos, muy por encima del objetivo GA v2 (50.000).
La prueba real validará o corregirá esta proyección.

---

### Escenario 4 — Saturación del bos DAG topológico

**Objetivo:** Determinar el tiempo de instalación cuando se despliegan N tenants
en paralelo y si el DAG topológico del bos se convierte en cuello de botella.

**Setup:**

```bash
# Crear 100 seeds de tenant y desplegarlos en paralelo
for i in $(seq 1 100); do
  bosctl deploy fixtures/tenant_template_$i.yml &
done
wait

# Medir: tiempo total, tiempo por tenant, si hubo timeouts o fallos de saga
```

**Métricas observadas:**

- Tiempo total de despliegue de N tenants en paralelo
- Tiempo promedio por tenant (debe escalar linealmente, no exponencialmente)
- Tasa de fallos de saga de alta (compensaciones activadas)
- CPU/RAM del bos durante el pico de instalación

**Criterio de diseño a validar:**

El bos resuelve el DAG de dependencias entre fichas por tenant. Si el DAG
de cada tenant es independiente (lo es, por diseño), el tiempo de instalación
de N tenants en paralelo debe ser aproximadamente igual al tiempo de
instalación de 1 tenant. La prueba valida este supuesto.

---

### Escenario 5 — WAL throughput bajo escritura masiva

**Objetivo:** Verificar que bKernel no se convierte en cuello de botella cuando
hay escritura masiva en PostgreSQL desde múltiples servicios simultáneamente.

**Setup:**

```bash
# Simular operaciones POS concurrentes de múltiples sucursales
k6 run --env CONCURRENT_POS=500 scenarios/pos_concurrent_write.js
```

**Métricas observadas:**

- WAL lag del slot de replicación (bytes pendientes de procesar)
- Latencia bKernel P99 (tiempo desde escritura PG hasta ejecución de la regla)
- CPU/RAM bKernel
- Tamaño de la DLQ (si crece, indica bKernel está saturado)

**Umbral de alerta:**

Si el WAL lag supera 1MB sostenido por más de 60 segundos, bKernel está
saturado. La acción es escalar vertical (más CPU/RAM), ya que bKernel
es single-instance por diseño (la replicación lógica de PG tiene un solo
consumidor por slot).

---

## 5. Ejecución del Plan de Pruebas

### 5.1 Frecuencia

| Tipo de prueba | Frecuencia | Trigger |
|---|---|---|
| **Smoke test** (Escenario 1, 10 VUs, 60s) | En cada merge a main | CI/CD automático |
| **Load test** (Escenarios 1-3, carga normal) | Semanal en staging | Cron |
| **Stress test** (todos los escenarios, carga 2x objetivo) | Mensual | Manual + aprobación |
| **Spike test** (carga 10x en 30 segundos) | Trimestral | Manual + aprobación |
| **Soak test** (carga normal, 48 horas continuas) | Antes de cada release GA | Manual + aprobación |

### 5.2 Criterios de Aceptación para GA v1

Una release no pasa a GA hasta que los siguientes benchmarks estén documentados
con evidencia reproducible:

- [ ] Escenario 1 (baseline): todos los SLO §2.2 cumplidos
- [ ] Escenario 2 (multi-tenant): 500 tenants simultáneos sin degradar SLO
- [ ] Escenario 3 (Redis): 5.000 ctx_id concurrentes con latencia P99 < 5ms
- [ ] Escenario 4 (bos DAG): 50 tenants en paralelo, tiempo < 90s promedio por tenant
- [ ] Escenario 5 (WAL): 200 WAL eventos/s sin lag creciente en bKernel
- [ ] Soak test: 48 horas a carga normal sin degradación de métricas
- [ ] Sin memory leaks detectados en Go services (perftools pprof heap)
- [ ] Sin goroutine leaks detectados (pprof goroutine)
- [ ] DLQ vacía al finalizar todas las pruebas

### 5.3 Artefactos de Salida de Cada Prueba

Cada ejecución de prueba produce los siguientes artefactos, almacenados en
el repositorio de evidencias:

```
benchmarks/
└── {fecha}-{escenario}/
    ├── k6_report.html          # Reporte completo k6 con gráficas
    ├── prometheus_snapshot/    # Snapshot de métricas durante la prueba
    ├── grafana_dashboard.png   # Captura del dashboard durante pico de carga
    ├── redis_info.txt          # redis-cli INFO durante y después de la prueba
    ├── pg_stat_activity.csv    # Conexiones PG durante la prueba
    └── summary.md              # Análisis humano: qué pasó, umbrales alcanzados,
                                #   acciones tomadas, ¿pasa o falla?
```

---

## 6. Proyecciones de Capacidad por Hardware

### 6.1 Configuración Mínima para GA v1 (500 tenants / 5.000 ctx_id)

| Componente | Especificación mínima | Justificación |
|---|---|---|
| **PostgreSQL (Patroni)** | 3 nodos × 16 vCPU / 64GB RAM / NVMe | shared_buffers=16GB, WAL throughput |
| **Redis Cluster** | 3 masters × 4 vCPU / 8GB RAM | Context Registry + Streams |
| **Kong pods** | 4 pods × 2 vCPU / 4GB RAM | 50.000 RPS pico |
| **bKernel (Rust)** | 1 instancia × 8 vCPU / 16GB RAM | WAL parsing sin GC |
| **bAuth pods** | 3 pods × 2 vCPU / 4GB RAM | BitMask evaluation + Redis cache |
| **bos daemon** | 1 instancia × 4 vCPU / 8GB RAM | DAG topológico, baja carga continua |
| **Go services (POS, etc.)** | HPA 2-20 pods × 1 vCPU / 2GB RAM | Stateless, escala horizontal |
| **MinIO** | 4 nodos × 4 vCPU / 8GB RAM / 2TB NVMe | Erasure coding N/2 |

### 6.2 Proyección de Capacidad por Componente

| Componente | GA v1 (500T) | GA v2 (5.000T) | Acción de escalamiento |
|---|---|---|---|
| PostgreSQL | 1 cluster HA | 1 cluster HA + N read replicas | Escalar vertical primero, luego read replicas |
| Redis DB1 | 1 cluster (3 masters) | 1 cluster (6 masters, más shards) | Añadir shards al cluster |
| bKernel | 1 instancia | 1 instancia (escalar vertical) | No escala horizontal — diseño single-consumer por slot PG |
| Kong | 4 pods | 8-16 pods | HPA automático |
| pgvector (HNSW RAM) | < 4GB índices | Evaluar migración a Qdrant | Ver §15.5 del documento maestro |

---

## 7. Integración con el Roadmap

| Hito del Roadmap | Benchmark requerido | Semana |
|---|---|---|
| Fase 1 completa (bos + Context Plane) | Escenario 4 (DAG) — 5 tenants | Semana 10 |
| Fase 2 completa (POS + ERP) | Escenarios 1 + 5 — Alpha capacity | Semana 20 |
| Fase 3 completa (Web Platform) | Escenarios 1 + 2 + 3 — 50 tenants | Semana 28 |
| Fase 5 — Criterios GA v1 | Todos los escenarios — 500 tenants | Semana 44-46 |
| Post-GA — Capacity planning GA v2 | Stress test 5.000 tenants | Semana 48+ |

---

*SBOS-PERF-001 v1.0 · Junio 2026 · SKULL*  
*Cierra la brecha identificada: "está diseñado para escalar" → reemplazado por umbrales,*  
*escenarios de prueba, criterios de saturación y criterios de aceptación formales para GA.*
