# SBOS — Proyecciones de Capacidad y Registro de Pruebas de Carga
## Modelo Tenant Real · Benchmarks · Formularios de Registro

**Documento:** SBOS-PERF-002  
**Versión:** 1.0  
**Estado:** Normativo Activo  
**Fecha:** 2026-06-12  
**Clasificación:** Interno · Ingeniería + Arquitectura  
**Reemplaza parcialmente:** SBOS-PERF-001 §2 (proyecciones de capacidad)

---

## Índice

1. [Modelo Real de Tenant SBOS](#1-modelo-real-de-tenant-sbos)
2. [Proyecciones por Perfil de Tenant](#2-proyecciones-por-perfil-de-tenant)
3. [Proyecciones de Plataforma Multi-Tenant](#3-proyecciones-de-plataforma-multi-tenant)
4. [SLO Ajustados al Modelo Real](#4-slo-ajustados-al-modelo-real)
5. [Estructura de Base de Datos para Registro de Pruebas](#5-estructura-de-base-de-datos-para-registro-de-pruebas)
6. [Formulario de Registro — Ejecución de Prueba](#6-formulario-de-registro--ejecución-de-prueba)
7. [Formulario de Registro — Resultados por Componente](#7-formulario-de-registro--resultados-por-componente)
8. [Formulario de Registro — Saturación y Umbrales](#8-formulario-de-registro--saturación-y-umbrales)
9. [Tablas de Tabulación de Resultados](#9-tablas-de-tabulación-de-resultados)
10. [Criterios de Aceptación y Decisión](#10-criterios-de-aceptación-y-decisión)
11. [Plantilla de Resumen Ejecutivo de Prueba](#11-plantilla-de-resumen-ejecutivo-de-prueba)

---

## 1. Modelo Real de Tenant SBOS

El modelo de capacidad anterior usaba proyecciones genéricas. Este documento
reemplaza esas proyecciones con los parámetros reales del modelo de negocio
de SBOS tal como fue definido por el equipo de arquitectura.

### 1.1 Parámetros Reales del Modelo

| Dimensión | Mínimo | Típico | Máximo |
|---|---|---|---|
| Empresas por tenant | 1 | 150 | 300 |
| Sucursales por empresa | 1 | 4 | 9 |
| Personas por sucursal | 5 | 25 | 100 |

### 1.2 Factor de Concurrencia Adoptado

No todos los usuarios están activos simultáneamente. Se adopta el factor
de concurrencia estándar de la industria para sistemas ERP/POS:

- **Hora valle** (08:00-09:00, 13:00-14:00): 10% de usuarios activos
- **Hora normal** (09:00-12:00, 15:00-18:00): 30% de usuarios activos
- **Hora pico** (12:00-13:00, cierre de turno): 50% de usuarios activos

El benchmark usa **30% como referencia base** y **50% como escenario de estrés**.

### 1.3 Factor de Carga por Usuario Activo

Un usuario activo en el sistema genera:

| Operación | Frecuencia estimada | RPS por usuario |
|---|---|---|
| Consulta de catálogo / pantalla POS | 1 cada 10s | 0.10 RPS |
| Operación de venta (JSON-RPC) | 1 cada 60s | 0.017 RPS |
| Consulta de stock (JSON-RPC) | 1 cada 30s | 0.033 RPS |
| Heartbeat de contexto (ctx_id) | 1 cada 30s | 0.033 RPS |
| **Total estimado por usuario activo** | | **~10 RPS** |

Cada operación de venta genera aproximadamente **5 eventos WAL**
(escritura en cuenta, línea de venta, movimiento de stock, factura, log).

---

## 2. Proyecciones por Perfil de Tenant

### 2.1 Perfil Pequeño (tenant-S)

```
Empresas:          100
Sucursales/empresa: 1
Total sucursales:  100
Personas/sucursal:  5
Total usuarios:    500
```

| Métrica | Valle (10%) | Normal (30%) | Pico (50%) |
|---|---|---|---|
| ctx_id activos | 50 | 150 | 250 |
| RPS JSON-RPC | 500 | 1.500 | 2.500 |
| WAL eventos/s | 8 | 25 | 42 |
| Redis DB1 estimado | ~35 KB | ~105 KB | ~175 KB |

### 2.2 Perfil Mediano (tenant-M)

```
Empresas:          150
Sucursales/empresa:  4
Total sucursales:  600
Personas/sucursal:  25
Total usuarios:   15.000
```

| Métrica | Valle (10%) | Normal (30%) | Pico (50%) |
|---|---|---|---|
| ctx_id activos | 1.500 | 4.500 | 7.500 |
| RPS JSON-RPC | 15.000 | 45.000 | 75.000 |
| WAL eventos/s | 250 | 750 | 1.250 |
| Redis DB1 estimado | ~1 MB | ~3,1 MB | ~5,2 MB |

### 2.3 Perfil Grande (tenant-L)

```
Empresas:          300
Sucursales/empresa:  9
Total sucursales:  2.700
Personas/sucursal:  100
Total usuarios:   270.000
```

| Métrica | Valle (10%) | Normal (30%) | Pico (50%) |
|---|---|---|---|
| ctx_id activos | 27.000 | 81.000 | 135.000 |
| RPS JSON-RPC | 270.000 | 810.000 | 1.350.000 |
| WAL eventos/s | 4.500 | 13.500 | 22.500 |
| Redis DB1 estimado | ~18,9 MB | ~56,7 MB | ~94,5 MB |

> **Nota sobre el perfil grande:** Un tenant-L con 300 empresas y 2.700 sucursales
> a plena carga (50% concurrencia) es equivalente a una corporación nacional de
> primer nivel. En la práctica, un tenant-L justifica un análisis de capacidad
> dedicado antes del onboarding. El sistema debe soportarlo, pero no se espera
> que sea el perfil típico en la fase GA v1.

---

## 3. Proyecciones de Plataforma Multi-Tenant

### 3.1 Distribución Realista de Tenants (Ley de Potencias SaaS)

La experiencia en plataformas SaaS muestra que la distribución de clientes
sigue una ley de potencias: la mayoría de los tenants son pequeños, con
unos pocos medianos y muy pocos grandes.

**Distribución adoptada:**
- 70% de tenants: perfil pequeño (tenant-S)
- 25% de tenants: perfil mediano (tenant-M)
- 5% de tenants: perfil grande (tenant-L)

### 3.2 Proyecciones Agregadas por Fase

Todas las cifras en escenario **normal (30% concurrencia)**:

| Fase | Tenants | S (70%) | M (25%) | L (5%) | ctx_id pico | RPS pico | WAL/s | Redis DB1 |
|---|---|---|---|---|---|---|---|---|
| **Alpha** | 5 | 3 | 1 | 1 | ~87.150 | ~871.500 | ~14.525 | ~61 MB |
| **Beta** | 50 | 35 | 12 | 3 | ~303.750 | ~3.037.500 | ~50.625 | ~213 MB |
| **GA v1** | 500 | 350 | 125 | 25 | ~2.640.000 | ~26.400.000 | ~440.000 | ~1,85 GB |
| **GA v2** | 2.000 | 1.400 | 500 | 100 | ~10.560.000 | ~105.600.000 | ~1.760.000 | ~7,4 GB |

> **Importante:** Las cifras de GA v1 (500 tenants, 2,6M ctx_id concurrentes)
> revelan que la arquitectura de Redis necesita planificación de capacidad
> seria desde Fase 3. 1,85 GB dedicados al Context Registry es manejable
> con Redis Cluster de 3 masters × 8 GB RAM, pero el WAL de 440.000 eventos/s
> requiere validación empírica de bKernel. Ese es exactamente el propósito
> del Escenario 5 del plan de pruebas.

### 3.3 Proyección de Redis DB1 por Volumen de ctx_id

El tamaño de cada entrada en Redis DB1 se estima en ~700 bytes:
- Payload JSON del ctx_id: ~500 bytes
- Overhead de Redis (clave, TTL, metadata): ~200 bytes

| ctx_id concurrentes | Redis DB1 estimado | ¿Cabe en 4 GB? | ¿Cabe en 8 GB? |
|---|---|---|---|
| 100.000 | ~70 MB | ✅ | ✅ |
| 500.000 | ~350 MB | ✅ | ✅ |
| 1.000.000 | ~700 MB | ✅ | ✅ |
| 2.640.000 (GA v1) | ~1,85 GB | ✅ | ✅ |
| 5.000.000 | ~3,5 GB | ⚠️ ajustado | ✅ |
| 10.560.000 (GA v2) | ~7,4 GB | ❌ | ⚠️ ajustado |

**Acción para GA v2:** Redis Cluster con 6 masters × 8 GB RAM dedicados
a DB1, o activar Redis Cluster con hash slots distribuidos por `tenant_id`.

---

## 4. SLO Ajustados al Modelo Real

Los SLO del documento SBOS-PERF-001 se mantienen. Esta sección los contextualiza
con los escenarios de carga reales del modelo de tenant SBOS.

### 4.1 SLO Vigentes

| Métrica | P50 | P99 | Límite absoluto | Componente responsable |
|---|---|---|---|---|
| Latencia JSON-RPC end-to-end | < 30ms | < 150ms | 500ms | Kong + Go service |
| Latencia ctx_id lookup Redis | < 1ms | < 5ms | 20ms | Redis DB1 |
| Latencia WAL → bKernel (CDC) | < 5ms | < 50ms | 100ms | bKernel (Rust) |
| Latencia bAuth BitMask (cache hit) | < 5ms | < 15ms | 50ms | bAuth + Redis |
| Latencia bAuth BitMask (cache miss) | < 15ms | < 40ms | 100ms | bAuth + Keycloak |
| Latencia context.promoted | < 15ms | < 40ms | 100ms | bos + bAuth + Redis |
| Tasa de error gRPC global | < 0,01% | < 0,1% | 1% | Todos los servicios Go |
| ctx_id lookup failures | 0 | < 0,01% | 0,1% | bos Context API |
| Alta de tenant (bosctl deploy) | < 30s | < 90s | 300s | bos |
| Instalación de ficha (single) | < 60s | < 180s | 600s | bos |

### 4.2 Umbrales de Saturación por Componente

Cuándo actuar antes de que el SLO se rompa:

| Componente | Métrica observable | WARNING | CRITICAL | Acción |
|---|---|---|---|---|
| Redis DB1 (Context Registry) | Memoria usada | 60% | 80% | Añadir RAM → Redis Cluster con más shards |
| Redis Streams (biedata) | Consumer lag | > 1.000 eventos | > 10.000 | Escalar biedata horizontalmente |
| PostgreSQL bkernel_db | Latencia escritura P99 | > 10ms | > 50ms | Revisar índices, escalar vertical |
| PostgreSQL tryton_db | Conexiones activas | > 80% pool | > 95% | Añadir PgBouncer, read replicas |
| bKernel WAL slot | Lag del slot (bytes pendientes) | > 10 KB | > 1 MB | Escalar vertical bKernel |
| Kong pods | CPU promedio por pod | > 70% | > 90% | HPA activo, más pods |
| bAuth | Cache miss ratio | > 20% | > 40% | Aumentar TTL del BitMask cache |
| bos DAG (install paralela) | Tiempo por tenant en batch | > 90s | > 300s | Reducir paralelismo del bos |
| Website Engine | P99 tiempo de respuesta | > 200ms | > 500ms | HPA, revisar cache de CTX assets |

---

## 5. Estructura de Base de Datos para Registro de Pruebas

Todo resultado de prueba de carga se registra en la base de datos
`bench_db` del entorno de staging. Esta base de datos es la fuente
de verdad para comparación histórica y auditoría de releases.

### 5.1 DDL Completo

```sql
-- Base de datos dedicada al registro de pruebas
CREATE DATABASE bench_db;
\c bench_db;

-- ================================================================
-- Tabla maestra: cada ejecución de prueba
-- ================================================================
CREATE TABLE bench_runs (
    run_id          SERIAL          PRIMARY KEY,
    run_code        VARCHAR(32)     NOT NULL UNIQUE,
                                    -- Formato: SBOS-BENCH-{YYYYMMDD}-{N}
                                    -- Ejemplo: SBOS-BENCH-20260612-001

    -- Identificación
    escenario       VARCHAR(20)     NOT NULL
                    CHECK (escenario IN (
                        'S1-baseline',
                        'S2-multitenant',
                        'S3-redis-saturation',
                        'S4-bos-dag',
                        'S5-wal-throughput',
                        'S6-spike',
                        'S7-soak-48h'
                    )),
    tipo            VARCHAR(20)     NOT NULL
                    CHECK (tipo IN ('smoke','load','stress','spike','soak')),
    fase_objetivo   VARCHAR(10)     NOT NULL
                    CHECK (fase_objetivo IN ('alpha','beta','ga-v1','ga-v2')),

    -- Parámetros de entrada
    n_tenants       INTEGER         NOT NULL,
    perfil_tenant   VARCHAR(10)     NOT NULL
                    CHECK (perfil_tenant IN ('S','M','L','mixed')),
    n_vus_pico      INTEGER         NOT NULL,   -- Virtual Users en el pico
    duracion_s      INTEGER         NOT NULL,   -- Duración total en segundos
    factor_conc     NUMERIC(4,2)    NOT NULL,   -- 0.10, 0.30, 0.50
    carga_rps_obj   INTEGER         NOT NULL,   -- RPS objetivo del test

    -- Entorno
    k8s_nodes       INTEGER,
    pg_version      VARCHAR(20),
    redis_version   VARCHAR(20),
    kong_version    VARCHAR(20),
    bkernel_commit  VARCHAR(40),
    bos_commit      VARCHAR(40),

    -- Metadatos de ejecución
    ejecutado_por   VARCHAR(64)     NOT NULL,
    fecha_inicio    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    fecha_fin       TIMESTAMPTZ,
    duracion_real_s INTEGER,

    -- Veredicto
    resultado       VARCHAR(10)     CHECK (resultado IN ('pass','fail','abort','pending'))
                    DEFAULT 'pending',
    slo_cumplidos   BOOLEAN,        -- true solo si TODOS los SLO pasaron
    notas           TEXT,

    CONSTRAINT chk_fechas CHECK (fecha_fin IS NULL OR fecha_fin > fecha_inicio)
);

-- ================================================================
-- Métricas globales de la ejecución (una fila por run)
-- ================================================================
CREATE TABLE bench_metricas_globales (
    id              SERIAL          PRIMARY KEY,
    run_id          INTEGER         NOT NULL REFERENCES bench_runs(run_id),

    -- Latencia JSON-RPC (ms)
    rpc_lat_p50_ms      NUMERIC(10,3),
    rpc_lat_p95_ms      NUMERIC(10,3),
    rpc_lat_p99_ms      NUMERIC(10,3),
    rpc_lat_max_ms      NUMERIC(10,3),

    -- Throughput
    rps_pico            NUMERIC(12,2),
    rps_promedio        NUMERIC(12,2),
    total_requests      BIGINT,
    requests_fallidos   BIGINT,
    tasa_error_pct      NUMERIC(6,4),   -- porcentaje: 0.0032

    -- Context Plane
    ctx_lookup_p50_ms   NUMERIC(10,3),
    ctx_lookup_p99_ms   NUMERIC(10,3),
    ctx_lookup_max_ms   NUMERIC(10,3),
    ctx_lookups_totales BIGINT,
    ctx_lookup_failures BIGINT,
    ctx_id_pico         INTEGER,        -- max ctx_id activos simultáneos

    -- WAL / bKernel
    wal_lag_p50_ms      NUMERIC(10,3),
    wal_lag_p99_ms      NUMERIC(10,3),
    wal_eventos_por_s   NUMERIC(12,2),
    wal_slot_lag_max_kb NUMERIC(12,2),  -- KB de lag en el slot PG
    dlq_size_max        INTEGER,
    dlq_eventos_totales INTEGER,

    -- bAuth
    bauth_hit_p50_ms    NUMERIC(10,3),
    bauth_hit_p99_ms    NUMERIC(10,3),
    bauth_miss_p50_ms   NUMERIC(10,3),
    bauth_miss_p99_ms   NUMERIC(10,3),
    bauth_cache_miss_pct NUMERIC(6,4),

    UNIQUE (run_id)
);

-- ================================================================
-- Métricas por componente de infraestructura
-- ================================================================
CREATE TABLE bench_metricas_infra (
    id              SERIAL          PRIMARY KEY,
    run_id          INTEGER         NOT NULL REFERENCES bench_runs(run_id),
    componente      VARCHAR(30)     NOT NULL
                    CHECK (componente IN (
                        'redis-db1', 'redis-streams', 'redis-cluster',
                        'postgresql-bkernel', 'postgresql-tryton',
                        'kong', 'bkernel', 'bauth', 'bos',
                        'website-engine', 'biedata', 'bsearch'
                    )),

    -- Recurso
    cpu_avg_pct     NUMERIC(5,2),
    cpu_max_pct     NUMERIC(5,2),
    ram_avg_mb      NUMERIC(10,2),
    ram_max_mb      NUMERIC(10,2),
    ram_total_mb    NUMERIC(10,2),

    -- Métrica específica del componente (libre)
    metrica_1_nombre VARCHAR(64),
    metrica_1_valor  NUMERIC(14,4),
    metrica_1_unidad VARCHAR(20),

    metrica_2_nombre VARCHAR(64),
    metrica_2_valor  NUMERIC(14,4),
    metrica_2_unidad VARCHAR(20),

    metrica_3_nombre VARCHAR(64),
    metrica_3_valor  NUMERIC(14,4),
    metrica_3_unidad VARCHAR(20),

    -- ¿Saturó este componente durante la prueba?
    saturo          BOOLEAN         DEFAULT FALSE,
    umbral_alcanzado VARCHAR(20)    CHECK (umbral_alcanzado IN ('none','warning','critical')),
    detalle_saturacion TEXT,

    UNIQUE (run_id, componente)
);

-- ================================================================
-- Serie temporal: métricas cada 30 segundos durante la prueba
-- (para trazar la curva de latencia vs. tiempo)
-- ================================================================
CREATE TABLE bench_serie_temporal (
    id              BIGSERIAL       PRIMARY KEY,
    run_id          INTEGER         NOT NULL REFERENCES bench_runs(run_id),
    ts              TIMESTAMPTZ     NOT NULL,
    segundo         INTEGER         NOT NULL,   -- segundos desde fecha_inicio

    rps             NUMERIC(12,2),
    rpc_p99_ms      NUMERIC(10,3),
    ctx_lookup_p99_ms NUMERIC(10,3),
    wal_lag_p99_ms  NUMERIC(10,3),
    redis_ram_mb    NUMERIC(10,2),
    ctx_id_activos  INTEGER,
    error_rate_pct  NUMERIC(6,4)
);

CREATE INDEX idx_bench_serie_run ON bench_serie_temporal (run_id, segundo);

-- ================================================================
-- Curva de escala: resultados del Escenario 2 (N tenants)
-- Una fila por iteración de tenants probada en S2-multitenant
-- ================================================================
CREATE TABLE bench_curva_escala (
    id              SERIAL          PRIMARY KEY,
    run_id          INTEGER         NOT NULL REFERENCES bench_runs(run_id),
    n_tenants       INTEGER         NOT NULL,
    perfil          VARCHAR(10)     NOT NULL,

    -- Métricas en este punto de la curva
    ctx_id_activos  INTEGER,
    rps_pico        NUMERIC(12,2),
    rpc_p99_ms      NUMERIC(10,3),
    ctx_lookup_p99_ms NUMERIC(10,3),
    redis_ram_mb    NUMERIC(10,2),
    wal_lag_p99_ms  NUMERIC(10,3),
    tasa_error_pct  NUMERIC(6,4),

    -- ¿Rompió algún SLO en este punto?
    slo_ok          BOOLEAN         NOT NULL DEFAULT TRUE,
    primer_slo_roto VARCHAR(64),    -- nombre del SLO que rompió primero

    UNIQUE (run_id, n_tenants)
);

-- ================================================================
-- Verificación de SLO: una fila por SLO por run
-- ================================================================
CREATE TABLE bench_slo_check (
    id              SERIAL          PRIMARY KEY,
    run_id          INTEGER         NOT NULL REFERENCES bench_runs(run_id),
    slo_nombre      VARCHAR(64)     NOT NULL,
    slo_metrica     VARCHAR(64)     NOT NULL,
    slo_umbral      NUMERIC(14,4)   NOT NULL,
    slo_unidad      VARCHAR(20)     NOT NULL,
    valor_medido    NUMERIC(14,4),
    paso            BOOLEAN,
    margen_pct      NUMERIC(8,2),   -- (umbral - medido) / umbral * 100. Positivo = margen. Negativo = excedido.
    notas           TEXT,

    UNIQUE (run_id, slo_nombre)
);

-- ================================================================
-- Notas y eventos durante la ejecución (log cualitativo)
-- ================================================================
CREATE TABLE bench_eventos (
    id              SERIAL          PRIMARY KEY,
    run_id          INTEGER         NOT NULL REFERENCES bench_runs(run_id),
    ts              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    segundo         INTEGER,        -- relativo al inicio del run
    tipo            VARCHAR(20)     NOT NULL
                    CHECK (tipo IN ('anomalia','saturacion','recovery','nota','alerta','abort')),
    componente      VARCHAR(30),
    descripcion     TEXT            NOT NULL,
    accion_tomada   TEXT
);
```

### 5.2 Vistas Útiles para Análisis

```sql
-- Vista: resumen ejecutivo de todos los runs
CREATE VIEW v_bench_resumen AS
SELECT
    r.run_id,
    r.run_code,
    r.escenario,
    r.tipo,
    r.fase_objetivo,
    r.n_tenants,
    r.perfil_tenant,
    r.n_vus_pico,
    r.resultado,
    r.slo_cumplidos,
    m.rpc_lat_p99_ms,
    m.ctx_lookup_p99_ms,
    m.wal_lag_p99_ms,
    m.tasa_error_pct,
    m.ctx_id_pico,
    r.fecha_inicio,
    r.duracion_real_s
FROM bench_runs r
LEFT JOIN bench_metricas_globales m ON r.run_id = m.run_id
ORDER BY r.fecha_inicio DESC;

-- Vista: curva de escala agregada (para graficar tenants vs latencia)
CREATE VIEW v_curva_escala AS
SELECT
    c.n_tenants,
    c.perfil,
    ROUND(AVG(c.rpc_p99_ms)::numeric, 2)         AS rpc_p99_ms_avg,
    ROUND(AVG(c.ctx_lookup_p99_ms)::numeric, 3)   AS ctx_p99_ms_avg,
    ROUND(AVG(c.redis_ram_mb)::numeric, 1)         AS redis_ram_mb_avg,
    ROUND(AVG(c.tasa_error_pct)::numeric, 4)       AS error_pct_avg,
    COUNT(*) FILTER (WHERE c.slo_ok = FALSE)       AS runs_con_slo_roto,
    COUNT(*)                                        AS total_runs
FROM bench_curva_escala c
JOIN bench_runs r ON c.run_id = r.run_id
WHERE r.resultado = 'pass'
GROUP BY c.n_tenants, c.perfil
ORDER BY c.n_tenants;

-- Vista: SLOs rotos por run (solo los que fallaron)
CREATE VIEW v_slo_fallidos AS
SELECT
    r.run_code,
    r.escenario,
    r.n_tenants,
    s.slo_nombre,
    s.slo_metrica,
    s.slo_umbral,
    s.slo_unidad,
    s.valor_medido,
    ROUND(s.margen_pct::numeric, 2) AS exceso_pct
FROM bench_slo_check s
JOIN bench_runs r ON s.run_id = r.run_id
WHERE s.paso = FALSE
ORDER BY r.fecha_inicio DESC, s.slo_nombre;

-- Vista: componentes que saturaron por run
CREATE VIEW v_saturaciones AS
SELECT
    r.run_code,
    r.escenario,
    r.n_tenants,
    i.componente,
    i.umbral_alcanzado,
    i.cpu_max_pct,
    i.ram_max_mb,
    i.detalle_saturacion
FROM bench_metricas_infra i
JOIN bench_runs r ON i.run_id = r.run_id
WHERE i.saturo = TRUE
ORDER BY r.fecha_inicio DESC, i.componente;
```

---

## 6. Formulario de Registro — Ejecución de Prueba

Completar **antes y durante** cada ejecución. Una copia por run.

```
================================================================
SBOS — REGISTRO DE EJECUCIÓN DE PRUEBA DE CARGA
================================================================

IDENTIFICACIÓN
  Código de run:    SBOS-BENCH-________-___
  Escenario:        [ ] S1-baseline  [ ] S2-multitenant  [ ] S3-redis-saturation
                    [ ] S4-bos-dag   [ ] S5-wal-throughput  [ ] S6-spike  [ ] S7-soak-48h
  Tipo:             [ ] smoke  [ ] load  [ ] stress  [ ] spike  [ ] soak
  Fase objetivo:    [ ] alpha  [ ] beta  [ ] ga-v1  [ ] ga-v2
  Ejecutado por:    _________________________________
  Fecha/hora inicio:  ____-____-____ __:__:__ UTC
  Fecha/hora fin:     ____-____-____ __:__:__ UTC

PARÁMETROS DE ENTRADA
  Tenants:          _______
  Perfil de tenant: [ ] S (pequeño)  [ ] M (mediano)  [ ] L (grande)  [ ] mixed
  VUs en pico:      _______
  Factor conc.:     [ ] 10%  [ ] 30%  [ ] 50%  otro: ______
  RPS objetivo:     _______
  Duración (s):     _______

ENTORNO DE EJECUCIÓN
  Nodos K8s:        _______
  PostgreSQL:       ________  (versión)
  Redis:            ________  (versión)
  Kong:             ________  (versión)
  bKernel commit:   ________________________________________
  bos commit:       ________________________________________
  Observabilidad:   [ ] Prometheus  [ ] Grafana  [ ] Loki  [ ] Tempo  [ ] k6 dashboard

PRE-FLIGHT CHECKLIST
  [ ] Entorno staging aislado y limpio (sin datos de runs anteriores)
  [ ] Fixtures de tenants generados y desplegados via bosctl
  [ ] Stack de observabilidad activo y capturando métricas
  [ ] DLQ vacía al inicio: ____ eventos
  [ ] Redis DB1 vacío al inicio: ____ KB
  [ ] WAL slot lag al inicio: ____ bytes
  [ ] Snapshot de métricas Prometheus tomado (baseline T=0)
  [ ] Dashboard Grafana abierto y grabando
  [ ] k6 conectado al entorno de staging

NOTAS DE INICIO
  _______________________________________________________________
  _______________________________________________________________
```

---

## 7. Formulario de Registro — Resultados por Componente

Completar **inmediatamente después** de cada ejecución con los datos
de Prometheus/Grafana.

```
================================================================
SBOS — RESULTADOS DE COMPONENTES
Run: SBOS-BENCH-________-___
================================================================

--- LATENCIA JSON-RPC (Kong → Go service → respuesta) ---
  P50:      _________ ms
  P95:      _________ ms
  P99:      _________ ms   SLO: < 150ms   [ ] PASS  [ ] FAIL
  Máximo:   _________ ms   SLO: < 500ms   [ ] PASS  [ ] FAIL

--- THROUGHPUT ---
  RPS promedio:     _________
  RPS pico:         _________
  Total requests:   _________
  Fallidos:         _________
  Tasa de error:    _________ %   SLO: < 0,1%   [ ] PASS  [ ] FAIL

--- CONTEXT PLANE (Redis DB1 ctx_id lookup) ---
  P50:              _________ ms
  P99:              _________ ms   SLO: < 5ms   [ ] PASS  [ ] FAIL
  Máximo:           _________ ms   SLO: < 20ms  [ ] PASS  [ ] FAIL
  Total lookups:    _________
  Lookup failures:  _________      SLO: < 0,01%  [ ] PASS  [ ] FAIL
  ctx_id máx. simultáneos: _________
  Redis DB1 RAM pico:       _________ MB
  Redis DB1 RAM % capacidad: _________ %

--- WAL / bKernel ---
  Latencia WAL P50: _________ ms
  Latencia WAL P99: _________ ms   SLO: < 50ms   [ ] PASS  [ ] FAIL
  Latencia WAL Máx: _________ ms   SLO: < 100ms  [ ] PASS  [ ] FAIL
  WAL eventos/s pico: _________
  WAL slot lag máx: _________ KB
  DLQ size máx:     _________
  DLQ eventos total: _________

--- bAuth (evaluación BitMask) ---
  Cache HIT P50:    _________ ms
  Cache HIT P99:    _________ ms   SLO: < 15ms   [ ] PASS  [ ] FAIL
  Cache MISS P50:   _________ ms
  Cache MISS P99:   _________ ms   SLO: < 40ms   [ ] PASS  [ ] FAIL
  Cache miss ratio: _________ %    Umbral WARNING: 20%
  Estado:           [ ] nominal  [ ] warning  [ ] critical

--- bos (Context Plane + DAG) ---
  ctx.promoted latencia P99: _________ ms   SLO: < 40ms  [ ] PASS  [ ] FAIL
  Alta de tenant P99:        _________ s    SLO: < 90s   [ ] PASS  [ ] FAIL
  Tenants desplegados:       _________
  Tenants con error saga:    _________

--- RECURSOS DE INFRAESTRUCTURA ---

  PostgreSQL (bkernel_db)
    CPU promedio: ______ %   CPU máximo: ______ %
    RAM:          ______ MB / ______ MB total
    Latencia escritura P99: ______ ms   Umbral: 10ms WARNING / 50ms CRITICAL
    Conexiones activas pico: ______

  PostgreSQL (tryton_db)
    CPU promedio: ______ %   CPU máximo: ______ %
    RAM:          ______ MB / ______ MB total
    Conexiones activas pico: ______   Pool total: ______
    % pool usado pico: ______ %

  Redis Cluster
    CPU total prom: ______ %
    RAM total:      ______ MB / ______ MB total
    Ops/s pico:     ______
    Latencia cmd p99: ______ ms

  Kong
    CPU promedio por pod: ______ %
    RAM por pod:          ______ MB
    Pods activos en pico: ______
    HPA activado:    [ ] Sí  [ ] No

  bKernel (Rust)
    CPU promedio: ______ %   CPU máximo: ______ %
    RAM:          ______ MB / ______ MB total
    Threads activos: ______

  bAuth
    CPU promedio: ______ %
    RAM:          ______ MB
    Pods:         ______

  Website Engine (si aplica)
    Respuesta P99: ______ ms   SLO: < 500ms  [ ] PASS  [ ] FAIL
    Pods activos pico: ______
```

---

## 8. Formulario de Registro — Saturación y Umbrales

```
================================================================
SBOS — ANÁLISIS DE SATURACIÓN Y UMBRALES
Run: SBOS-BENCH-________-___
================================================================

¿SATURÓ ALGÚN COMPONENTE?

  Redis DB1 (Context Registry)
    RAM máxima usada: ______ MB  /  ______ MB total = ______ %
    Estado:  [ ] nominal (<60%)  [ ] warning (60-80%)  [ ] critical (>80%)
    ¿Degradó el P99 de ctx_id lookup?  [ ] No  [ ] Sí — de ____ms a ____ms

  bKernel WAL
    Slot lag máximo:  ______ KB
    Estado:  [ ] nominal (<10KB)  [ ] warning (10KB-1MB)  [ ] critical (>1MB)
    ¿Creció la DLQ?  [ ] No  [ ] Sí — tamaño máximo: ______ eventos

  Kong
    CPU máximo por pod:  ______ %
    Estado:  [ ] nominal (<70%)  [ ] warning (70-90%)  [ ] critical (>90%)
    ¿Activó HPA?  [ ] No  [ ] Sí — escaló de ____ a ____ pods

  bAuth
    Cache miss ratio:  ______ %
    Estado:  [ ] nominal (<20%)  [ ] warning (20-40%)  [ ] critical (>40%)

  PostgreSQL
    Latencia escritura P99:  ______ ms
    Estado:  [ ] nominal (<10ms)  [ ] warning (10-50ms)  [ ] critical (>50ms)

  bos DAG
    Tiempo por tenant en batch:  ______ s
    Estado:  [ ] nominal (<90s)  [ ] warning (90-300s)  [ ] critical (>300s)

---

PUNTO DE INFLEXIÓN (solo para S2-multitenant)

  ¿A qué número de tenants empezó a degradar el P99 de rpc?
    Tenants en inflexión:    _______
    P99 antes:               _______ ms
    P99 después:             _______ ms
    Componente que degradó primero: _____________________________

  ¿A qué número de tenants rompió el primer SLO?
    Tenants en ruptura:      _______
    SLO roto:                _____________________________
    Valor medido:            _______ (umbral era: _______)

---

VEREDICTO FINAL

  ¿Todos los SLO pasaron?    [ ] Sí → PASS  [ ] No → FAIL

  SLOs que fallaron (si aplica):
    1. ___________________________________________________
    2. ___________________________________________________
    3. ___________________________________________________

  Resultado oficial:    [ ] PASS  [ ] FAIL  [ ] ABORT
  Motivo de abort (si aplica): _________________________________

  ¿Apto para avanzar a siguiente fase?  [ ] Sí  [ ] No  [ ] Con condiciones

  Condiciones para avanzar (si aplica):
    _____________________________________________________________
    _____________________________________________________________

---

ANOMALÍAS Y EVENTOS DURANTE LA EJECUCIÓN

  Hora        | Componente          | Evento                          | Acción tomada
  ------------|---------------------|---------------------------------|------------------
  __:__:__ UTC| _________________ | ______________________________ | _______________
  __:__:__ UTC| _________________ | ______________________________ | _______________
  __:__:__ UTC| _________________ | ______________________________ | _______________
  __:__:__ UTC| _________________ | ______________________________ | _______________

---

ARTEFACTOS GENERADOS

  [ ] k6_report.html guardado en:        benchmarks/{run_code}/
  [ ] Snapshot Prometheus guardado en:   benchmarks/{run_code}/
  [ ] Captura Grafana dashboard en:      benchmarks/{run_code}/
  [ ] redis-cli INFO guardado en:        benchmarks/{run_code}/redis_info.txt
  [ ] pg_stat_activity.csv guardado en:  benchmarks/{run_code}/
  [ ] summary.md completado en:          benchmarks/{run_code}/summary.md
  [ ] Datos cargados en bench_db:        [ ] Sí  [ ] No
```

---

## 9. Tablas de Tabulación de Resultados

Estas tablas se completan acumulando los resultados de múltiples runs.
Son la base para el análisis de tendencias y la decisión de release GA.

### 9.1 Tabla Maestra de Runs

| Run code | Fecha | Escenario | Tenants | Perfil | VUs pico | P99 RPC (ms) | P99 ctx (ms) | P99 WAL (ms) | Error % | DLQ máx | Resultado |
|---|---|---|---|---|---|---|---|---|---|---|---|
| SBOS-BENCH-________-001 | | | | | | | | | | | |
| SBOS-BENCH-________-002 | | | | | | | | | | | |
| SBOS-BENCH-________-003 | | | | | | | | | | | |
| SBOS-BENCH-________-004 | | | | | | | | | | | |
| SBOS-BENCH-________-005 | | | | | | | | | | | |

### 9.2 Curva de Escala — Tenants vs Latencia P99

Completar a partir del Escenario S2-multitenant. Cada fila es una
iteración de tenants en un run de tipo `S2-multitenant`.

| Tenants | Perfil | ctx_id activos | RPS pico | P99 RPC (ms) | P99 ctx lookup (ms) | Redis DB1 (MB) | WAL P99 (ms) | Error % | ¿SLO OK? | Primer SLO roto |
|---|---|---|---|---|---|---|---|---|---|---|
| 5 | S | | | | | | | | | |
| 10 | S | | | | | | | | | |
| 25 | S | | | | | | | | | |
| 50 | M | | | | | | | | | |
| 100 | M | | | | | | | | | |
| 250 | M | | | | | | | | | |
| 500 | M | | | | | | | | | |
| 500 | mixed | | | | | | | | | |
| 1000 | mixed | | | | | | | | | |
| 2000 | mixed | | | | | | | | | |

### 9.3 Tabla de Saturación por Componente

Acumula todos los runs. Una celda por componente por run.

| Run code | Redis DB1 % | WAL lag KB | bKernel CPU % | Kong CPU % | bAuth miss % | PG lat P99 ms | Saturó |
|---|---|---|---|---|---|---|---|
| SBOS-BENCH-________-001 | | | | | | | |
| SBOS-BENCH-________-002 | | | | | | | |
| SBOS-BENCH-________-003 | | | | | | | |

### 9.4 Tabla de SLOs por Run

| Run code | RPC P99 | ctx P99 | WAL P99 | Error% | ctx fail% | bAuth hit P99 | bos deploy P99 | TODOS PASS |
|---|---|---|---|---|---|---|---|---|
| SBOS-BENCH-________-001 | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ |
| SBOS-BENCH-________-002 | | | | | | | | |
| SBOS-BENCH-________-003 | | | | | | | | |

### 9.5 Checklist de Aceptación GA v1

Esta tabla se completa una sola vez, cuando el sistema alcanza los criterios
de GA v1. Es la evidencia formal que autoriza el primer release a producción.

| Criterio | Escenario | Run que lo certifica | P99 medido | Umbral SLO | ¿Pasa? | Fecha |
|---|---|---|---|---|---|---|
| SLOs §4.1 cumplidos a 100 VUs | S1-baseline | | | Todos los SLO | | |
| 500 tenants sin degradar SLO | S2-multitenant | | | P99 RPC < 150ms | | |
| 5.000 ctx_id concurrentes P99 < 5ms | S3-redis-saturation | | | < 5ms | | |
| 50 tenants en paralelo < 90s/tenant | S4-bos-dag | | | < 90s | | |
| 200 WAL eventos/s sin lag creciente | S5-wal-throughput | | | WAL lag < 1MB | | |
| 48h soak sin degradación | S7-soak-48h | | | Todos los SLO | | |
| Sin memory leaks Go services | S7-soak-48h | | | 0 leaks | | |
| Sin goroutine leaks | S7-soak-48h | | | 0 leaks | | |
| DLQ vacía al finalizar | Todos | | | 0 eventos | | |

**Firma de aceptación GA v1:**

```
Arquitecto:    _______________________  Fecha: ____________
Ingeniería:    _______________________  Fecha: ____________
Operaciones:   _______________________  Fecha: ____________
```

---

## 10. Criterios de Aceptación y Decisión

### 10.1 Árbol de Decisión por Resultado

```
Resultado del run
       │
       ├── PASS (todos los SLO cumplidos)
       │     └── ¿Hubo componentes en WARNING?
       │           ├── No → ✅ Sin acción. Continuar al siguiente escenario.
       │           └── Sí → ⚠️  PASS condicional.
       │                       Documentar componente en WARNING.
       │                       Monitorear en producción.
       │                       Planificar capacidad antes del siguiente hito.
       │
       ├── FAIL (uno o más SLOs rotos)
       │     └── ¿Qué componente saturó primero?
       │           ├── Redis → Escalar RAM Redis. Re-ejecutar S3.
       │           ├── bKernel WAL lag → Escalar vertical bKernel. Re-ejecutar S5.
       │           ├── Kong → Aumentar replicas. Revisar HPA. Re-ejecutar S1.
       │           ├── bAuth cache miss → Aumentar TTL BitMask. Re-ejecutar S1.
       │           ├── PostgreSQL lat. → Revisar índices. VACUUM. Re-ejecutar.
       │           └── bos DAG → Reducir paralelismo instalación. Re-ejecutar S4.
       │
       └── ABORT (prueba interrumpida antes de completar)
             └── Documentar motivo en bench_eventos.
                 Resolver causa raíz.
                 Re-ejecutar desde cero (no contar como run válido).
```

### 10.2 Regla de Re-ejecución

Un SLO que falló en un run no puede darse por "superado" hasta que pase
en **dos runs consecutivos independientes** bajo las mismas condiciones.
Una sola ejecución exitosa después de un fallo se clasifica como `provisional`.

---

## 11. Plantilla de Resumen Ejecutivo de Prueba

Guardar como `benchmarks/{run_code}/summary.md` al finalizar cada run.

```markdown
# Resumen de Prueba — {run_code}

**Fecha:** {fecha}  
**Escenario:** {escenario}  
**Tipo:** {tipo}  
**Ejecutado por:** {nombre}  
**Resultado:** PASS / FAIL / ABORT  

## Configuración

- Tenants: {n} ({perfil})
- VUs pico: {vus}
- Duración: {segundos}s
- Factor de concurrencia: {pct}%

## Resultados Clave

| Métrica | Medido | SLO | Estado |
|---|---|---|---|
| RPC P99 | {val} ms | < 150ms | PASS/FAIL |
| ctx_id lookup P99 | {val} ms | < 5ms | PASS/FAIL |
| WAL bKernel P99 | {val} ms | < 50ms | PASS/FAIL |
| Tasa de error | {val} % | < 0,1% | PASS/FAIL |
| ctx_id pico | {val} | — | — |
| Redis DB1 RAM pico | {val} MB | — | — |
| DLQ máx | {val} | 0 | PASS/FAIL |

## Qué pasó

{descripción en prosa de lo observado durante la prueba. 
¿Fue estable? ¿Hubo picos? ¿Algún componente se comportó diferente a lo esperado?}

## Saturaciones / Anomalías

{Si hubo saturaciones o eventos anómalos, describirlos aquí con timestamp y componente.}

## Punto de inflexión (solo S2)

{A qué número de tenants empezó a degradar y qué SLO rompió primero.}

## Acciones derivadas

- [ ] {acción concreta 1}
- [ ] {acción concreta 2}

## Artefactos

- k6_report.html: ✅ / ❌
- Snapshot Prometheus: ✅ / ❌
- Captura Grafana: ✅ / ❌
- Datos en bench_db: ✅ / ❌
```

---

*SBOS-PERF-002 v1.0 · Junio 2026 · SKULL*  
*Proyecciones basadas en modelo real: 100-300 empresas por tenant,*  
*1-9 sucursales por empresa, 5-100 personas por sucursal.*  
*Reemplaza las proyecciones genéricas de SBOS-PERF-001 §2.*
