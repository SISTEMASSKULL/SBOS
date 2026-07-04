# Manual de Desarrollo — bSearch (Motor de Búsqueda Soberano)
## bSearch: Sovereign Search Engine — PostgreSQL-Native
## Manual del Desarrollador · v1.0 · Junio 2026
### SKULL · SBOS · Go 1.26+
### Redactado por biblio-dev (Bibliotecario de Desarrollo)

---

## Prefacio — Alcance y decisiones de gobierno

Este manual operacionaliza la construcción de `bsearch`. Recoge la documentación
fuente (`DAEMON-BSEARCH.md`, `CONTRATO-BKERNEL-BSEARCH.md`,
`DDL-COMPARTIDA-BKERNEL-BSEARCH.md`, `pgvector_guia_completa.md`) y las **decisiones
de gobierno del HITL (2026-06-01)** que la perfeccionan con experiencia operativa.

> **Decisiones de gobierno que este manual fija:**
>
> 1. **Desarrollo en DOS FASES.** La IA (embeddings/búsqueda semántica) se difiere.
>    **Fase 1: solo búsqueda LÉXICA** (PostgreSQL full-text), pero **se prepara el
>    terreno**: se crea la BD paralela `semantic_store` con su estructura completa y
>    bSearch **ya va poblando `plain_text` y metadata** desde el día 1, sin generar
>    embeddings. **Fase 2: IA local** → backfill de embeddings + HNSW + búsqueda híbrida.
>
> 2. **Fuentes MULTI-MOTOR** (el modelo del CONTRATO). bSearch indexa eventos de
>    PostgreSQL, MySQL, SQL Server y MongoDB que le llegan vía bKernel. La nota §2.5
>    de `DAEMON-BSEARCH.md` ("solo PostgreSQL/Tryton") queda como **vestigio a corregir**.
>
> 3. **bSearch es dueño de SUS índices.** bKernel publica el evento canónico UNA vez
>    en Redis; bSearch lo consume y escribe en **sus dos índices** (`busqueda_universal`
>    léxico + `semantic_index` preparado). bKernel nunca escribe en los índices de
>    búsqueda (Frontera F8).

---

## 1. Identidad del Daemon

| Campo | Valor |
|---|---|
| Nombre | bSearch — Sovereign Search Engine, PostgreSQL-Native, Zero External Dependencies |
| Daemon | `bsearch` |
| Servicio | `bsearch.service` |
| Lenguaje | **Go 1.26+ (compilado estático, goroutines)** |
| Transporte | **WebSocket exclusivo (`wss://` sobre TLS)** — sin HTTP REST |
| **Interface Dual (ADR-020)** | **CLI + JSON-RPC 2.0 sobre Unix socket `/run/bos/bsearch.sock`** (control/admin) |
| Motor de búsqueda léxica | PostgreSQL 18+ (GIN, tsvector, pg_trgm, unaccent, fuzzystrmatch, Snowball ES) |
| Motor de búsqueda semántica | **Fase 2** — pgvector (HALFVEC/HNSW) en `semantic_store` |
| Fuente de indexación | bKernel → Redis Stream `bkernel:index_queue` (multi-motor) |
| Caché de salida | `sync.Map` (L1) + Redis (L2) TTL 300-600s |
| Auth | Keycloak JWT (`realm` del JWT, nunca del cliente) + BitMask 64-bit (bAuth) |
| BD propia | `bsearch_db` (metadatos, patrones, query_log, `_inbox`) + `busqueda_universal` |
| **BD paralela semántica** | **`semantic_store`** (Fase 1: estructura + plain_text; Fase 2: embeddings) |
| Driver PostgreSQL | pgx/v5 |
| WebSocket | gorilla/websocket o nhooyr.io/websocket |
| Métricas | `:9104` (Prometheus) |
| Build | `go build -ldflags="-s -w"` |
| Directorio patrones | `/etc/bos/blibs/bsearch/patterns/<app>/` |
| Servidor lógico | S09 (searchserver — nombre fósil; ver §2) |

---

## 2. Qué es bSearch — y qué no

bSearch es el **buscador de negocio soberano** del SBOS. Indexa proyecciones de los
datos del ecosistema y permite buscarlas, devolviendo siempre un **deep-link a la
fuente de verdad** (el formulario real de la app origen + Keycloak SSO).

**Decisiones de destilación arquitectónica (intactas del doc fuente):**
- **Elasticsearch retirado del negocio** → es solo para Wazuh/SIEM. Búsqueda de negocio = PostgreSQL nativo.
- **Meilisearch rechazado** para el core → solo caché periférica opcional de e-commerce.
- **Go 1.26+ sobre Rust** → goroutines (Fan-Out/Fan-In), `context.WithCancel` (search-as-you-type), pgx/v5, manejo masivo de WebSockets.
- **WebSocket exclusivo** → canal persistente para search-as-you-type; sin superficie HTTP REST.
- **Origen = WAL/CDC vía bKernel (ADR-001)** → orden causal por LSN, cero invasión a las apps.

| bSearch NO es | Responsable real |
|---|---|
| Fuente de verdad de los datos | Las apps propietarias (deep-link) |
| Escritor de bases de negocio | biedata |
| Listener de CDC | bKernel |
| Generador de embeddings (Fase 1) | Fase 2 — IA local |

---

## 3. Objetivos del daemon

| # | Objetivo | Fase | Verificación |
|---|---|---|---|
| O1 | Búsqueda léxica full-text sobre `busqueda_universal` | 1 | query WS → resultados con score |
| O2 | Indexar eventos multi-motor desde `bkernel:index_queue` | 1 | Path A (PG) + Path B (texto_plano) |
| O3 | Deduplicación effectively-once (`_inbox` UNIQUE event_id) | 1 | doble evento → un registro |
| O4 | Deep-link a la fuente de verdad (Frontera B9) | 1 | resultado abre formulario origen |
| O5 | WebSocket `wss://` con rate limit, ping/pong, validación Origin | 1 | pruebas de canal |
| O6 | **Interface Dual** (CLI + Unix socket JSON-RPC) para control | 1 | `bsearch describe/health` |
| O7 | **Poblar `semantic_store.plain_text`** sin generar embeddings | 1 | filas en semantic_index, embedding NULL |
| O8 | Backfill de embeddings + HNSW + búsqueda híbrida | 2 | hybrid ranking |

---

## 4. Arquitectura de indexación — el contrato con bKernel

bSearch consume el **evento canónico** de `bkernel:index_queue`. El contrato completo
está en `CONTRATO-BKERNEL-BSEARCH.md`. Resumen operativo:

```
bKernel publica evento canónico → Redis Stream bkernel:index_queue
   │  (event_id único, _meta.contrato_version, source.motor,
   │   index_hints.texto_plano [obligatorio si motor≠postgresql],
   │   payload_navegacion.uri_resuelta, tenant_id, traceparent)
   ▼
bSearch Stream Consumer (consumer group)
   1. ¿event_id en _inbox? → sí: XACK y salir (duplicado)
   2. validar contrato_version, tenant_id, uri_resuelta
   3. construir texto_buscable:
        Path A (postgresql): Data Flattening sobre payload.after  (o texto_plano si viene)
        Path B (mysql/sqlserver/mongodb): usar texto_plano  (si falta → DLQ "texto_plano_ausente")
   4. UPSERT en busqueda_universal (partición por origen_db)         ← ÍNDICE LÉXICO (Fase 1)
   5. UPSERT en semantic_index (plain_text+metadata, embedding NULL) ← TERRENO SEMÁNTICO (Fase 1)
   6. INSERT en _inbox (event_id, processed_at)
   7. XACK al Redis Stream
```

**Garantías del contrato (G1-G14):** event_id único, texto_plano para no-PostgreSQL,
tenant_id nunca nulo, at-least-once, deduplicación effectively-once, UPSERT idempotente,
deep-link a la fuente, DLQ tras 3 fallos, particionamiento independiente por `origen_db`.

> **Punto clave de coordinación:** el paso 5 es la preparación del terreno semántico.
> bSearch escribe `plain_text` (= `texto_plano` del contrato) en `semantic_index` desde
> Fase 1, pero **sin calcular embedding**. En Fase 2 se hace backfill sobre ese plain_text.

---

## 5. Índice LÉXICO — `busqueda_universal` (Fase 1, núcleo)

### 5.1 Las 14 herramientas PostgreSQL

bSearch usa exclusivamente capacidades nativas de PostgreSQL 18 sobre un campo de
texto plano `texto_buscable`: GIN, `tsvector`, `pg_trgm` (fuzzy), `unaccent`,
`fuzzystrmatch`, stemming Snowball Spanish, diccionarios `.syn`/`.ths` (sinónimos/abreviaturas).

### 5.2 UPSERT (del contrato §VI)

```sql
INSERT INTO busqueda_universal (
    id, origen_db, entidad_tipo, entidad_id, titulo_resultado,
    tenant_id, empresa_id, sucursal_id, pos_id,
    texto_buscable, documento_tsvector, payload_navegacion, payload_origen, updated_at)
VALUES (
    gen_random_uuid(), $app_id, $entity_type, $record_id, $titulo,
    $tenant_id, $empresa_id, $sucursal_id, $pos_id,
    $texto_buscable, to_tsvector('spanish', unaccent($texto_buscable)),
    $payload_navegacion, $payload, NOW())
ON CONFLICT (origen_db, entidad_id, tenant_id) DO UPDATE SET
    titulo_resultado=EXCLUDED.titulo_resultado,
    texto_buscable=EXCLUDED.texto_buscable,
    documento_tsvector=EXCLUDED.documento_tsvector,
    payload_navegacion=EXCLUDED.payload_navegacion,
    payload_origen=EXCLUDED.payload_origen, updated_at=NOW()
WHERE busqueda_universal.texto_buscable != EXCLUDED.texto_buscable
   OR busqueda_universal.payload_navegacion != EXCLUDED.payload_navegacion;
```

Particionado por `origen_db`: cada app a su partición (`p_bsearch_tryton`,
`p_bsearch_orangehrm`, ...). Motores distintos nunca compiten por el mismo registro.

### 5.3 Consulta léxica (search-as-you-type)

```go
// goroutine por consulta; context.WithCancel cancela la búsqueda previa al teclear
rows, err := pool.Query(ctx, `
  SELECT origen_db, entidad_id, titulo_resultado, payload_navegacion,
         ts_rank(documento_tsvector, query) AS score
  FROM busqueda_universal,
       websearch_to_tsquery('spanish', unaccent($1)) query
  WHERE tenant_id = $2
    AND documento_tsvector @@ query
  ORDER BY score DESC
  LIMIT 20`, termino, tenantID)
```

---

## 6. Terreno SEMÁNTICO — `semantic_store` (Fase 1: estructura; Fase 2: IA)

> **Corrección a `pgvector_guia_completa.md`:** es una guía genérica. En SBOS la capa
> de captura **NO es Debezium/Kafka** — es **bKernel + WAL + Redis** (ADR-001). El
> servicio de embeddings **NO es OpenAI** — es **local/soberano** (ADR-012 + soberanía).
> El `plain_text` de la guía **es el `texto_plano`** del contrato bKernel↔bSearch — no
> se reimplementan normalizadores en bSearch. Los ejemplos Python se traducen a **Go/pgx**.

### 6.1 Qué se construye en Fase 1 (sin IA)

`semantic_store` es una **BD paralela** (no invasiva, no es fuente de verdad, deep-link
a origen — misma doctrina que `busqueda_universal`). En Fase 1 se crea **toda la
estructura** y se **puebla `plain_text` + metadata**, dejando `embedding` nullable y
**sin** índice HNSW. Así se acumula una base sólida de datos reales para que la Fase 2
sea solo "encender el motor" (backfill), no reconstruir.

### 6.2 DDL (Fase 1 — particionado por tenant desde el inicio)

```sql
CREATE DATABASE semantic_store ENCODING 'UTF8' TEMPLATE template0;
\c semantic_store
CREATE EXTENSION IF NOT EXISTS vector;   -- pgvector v0.8.2 (PostgreSQL 18)

CREATE TABLE semantic_index (
    id             BIGSERIAL    NOT NULL,
    tenant_id      BIGINT       NOT NULL,
    entity_type    VARCHAR(100) NOT NULL,
    entity_id      BIGINT       NOT NULL,
    plain_text     TEXT         NOT NULL,         -- = texto_plano del contrato bKernel↔bSearch
    embedding      HALFVEC(1536),                 -- NULLABLE en Fase 1 — se llena en Fase 2
    metadata       JSONB        NOT NULL DEFAULT '{}',
    model_version  VARCHAR(80),                   -- NULL hasta Fase 2
    source_db      VARCHAR(100),
    indexed_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    source_updated TIMESTAMPTZ,
    PRIMARY KEY (id, tenant_id),
    UNIQUE (tenant_id, entity_type, entity_id)
) PARTITION BY HASH (tenant_id);
-- 16 particiones p00..p15 (MODULUS 16) — ver pgvector_guia §2.5

-- Índices de Fase 1 (NO crear HNSW todavía — es Fase 2):
CREATE INDEX idx_si_tenant   ON semantic_index (tenant_id, entity_type);
CREATE INDEX idx_si_metadata ON semantic_index USING gin (metadata jsonb_path_ops);
CREATE INDEX idx_si_stale    ON semantic_index (source_updated, indexed_at)
                              WHERE source_updated > indexed_at;
```

### 6.3 UPSERT de Fase 1 (sin embedding)

```sql
INSERT INTO semantic_index
  (tenant_id, entity_type, entity_id, plain_text, metadata, source_db, source_updated)
VALUES ($1,$2,$3,$4,$5::jsonb,$6,$7)
ON CONFLICT (tenant_id, entity_type, entity_id) DO UPDATE SET
  plain_text=EXCLUDED.plain_text, metadata=EXCLUDED.metadata,
  indexed_at=NOW(), source_updated=EXCLUDED.source_updated;
-- embedding y model_version quedan NULL hasta Fase 2
```

### 6.4 Reglas obligatorias desde el día 1 (de la guía, Parte V)

Aunque la IA sea Fase 2, estas decisiones se toman **ahora** porque condicionan la estructura:
- **HALFVEC, nunca VECTOR** (50% menos espacio, recall >99%).
- **Particionado por `tenant_id` desde el inicio** (DROP/TRUNCATE instantáneo por tenant).
- **Política de elegibilidad** (`elegibilidad.yaml`): no indexar todo (reduce volumen 40-70%). Define qué entidades merecen estar en `semantic_index`.
- **TTL**: el índice semántico no es eterno (job de limpieza). El dato original sigue en su app.

### 6.5 Qué llega en Fase 2 (preparado, no implementado ahora)

- Servicio de **embeddings local/soberano** (sentence-transformers / Ollama). Posible nacimiento del `aiserver` (reabre GAP-07 de bKernel). **Nunca OpenAI.**
- **Backfill**: calcular embedding sobre el `plain_text` ya acumulado; `UPDATE ... SET embedding=$v::halfvec, model_version='...'`.
- Índice **HNSW** (`halfvec_cosine_ops`, m=16, ef_construction=64) por partición, con `CONCURRENTLY`.
- **Búsqueda híbrida**: fusión de ranking léxico (`busqueda_universal`) + semántico (`semantic_index`), búsqueda en dos pasos (índice → deep-link a fuente).
- **Umbral de migración** (guía §5.3): pgvector hasta ~15M registros / hasta que HNSW supere la RAM → evaluar pgvectorscale o Qdrant. Los `entity_id` no cambian: migración transparente.

---

## 7. WebSocket y seguridad (Fase 1)

| Aspecto | Regla |
|---|---|
| Transporte | `wss://` exclusivo; sin HTTP REST de búsqueda |
| Validación Origin | solo dominios del ecosistema (`*.empresa.com`); rechazo cross-origin |
| Rate limit | > 5 msg/s por canal → corte unilateral (anti-DoS) |
| Ping/Pong | Ping cada 30s; sin Pong → matar goroutine (anti-zombi) |
| Auth | JWT Keycloak; `realm` del token; BitMask 64-bit (bAuth) por hilo antes de consultar particiones |
| Interno K8s | `ws://bsearch.core.svc.cluster.local/ws` — latencia en microsegundos |

---

## 8. Interface Dual (ADR-020) — control y administración

> bSearch sirve **búsquedas** por WebSocket. Pero ADR-020 exige, además, una
> **Interface Dual de control** (CLI + JSON-RPC 2.0 sobre Unix socket) para
> administración, salud y operación. No se mezcla con el canal de búsqueda wss.

```
/run/bos/bsearch.sock  (JSON-RPC 2.0)  ←  bosctl, otros daemons intra-host
CLI:  bsearch describe | health | reindex <app> | patterns <app> | inbox stats
```

- CLI y RPC comparten dispatcher y modelo de dominio (sin lógica duplicada).
- Errores: protocolo (`-32600..-32602`) vs aplicación (`-32000`), siempre éxito de transporte (ORQUESTA-043 P6).
- El Schema Discoverer (§21 del doc fuente) se opera por esta interface: genera patrones DRAFT por app desde `information_schema` (PG/MySQL/SQLServer) o desde el `bsearch_template` de la ficha bKernel (MongoDB / prioridad del admin).

---

## 9. Criterios de aceptación

| # | Criterio | Fase | Evidencia |
|---|---|---|---|
| C-01 | Compila estático Go sin warnings | 1 | log `build-go.sh` + SHA256 |
| C-02 | Consume `bkernel:index_queue` con consumer group | 1 | XREADGROUP + XACK |
| C-03 | Deduplicación por `_inbox` (UNIQUE event_id) | 1 | doble evento → un registro |
| C-04 | Path A (PG) y Path B (texto_plano) indexan correctamente | 1 | casos multi-motor |
| C-05 | `texto_plano` ausente en motor≠PG → DLQ | 1 | evento inválido → `bkernel:index_dlq` |
| C-06 | Búsqueda léxica wss devuelve resultados con score y deep-link | 1 | query → resultado abre fuente |
| C-07 | WebSocket: Origin, rate limit, ping/pong | 1 | pruebas de canal |
| C-08 | Auth JWT + BitMask por tenant/partición | 1 | acceso denegado a otro tenant |
| C-09 | **`semantic_index` se puebla (plain_text+metadata, embedding NULL)** | 1 | SELECT con embedding IS NULL |
| C-10 | `semantic_store` particionada HALFVEC, sin HNSW aún | 1 | `\d+ semantic_index` |
| C-11 | Interface Dual (CLI + Unix socket) operativa | 1 | `bsearch describe/health` |
| C-12 | Métricas `:9104`, dashboard, alerts | 1 | scrape + archivos |
| C-13 | (Fase 2) Backfill embeddings + HNSW + híbrido | 2 | hybrid ranking |

**Evidencia (ADR-030, AA-1):** log real en disco + SHA256 por criterio.

---

## 10. Plan de desarrollo (fases)

> Base existente: el código de bSearch lo desarrolla el agente **bintelligence-developer**
> en `desarrollo/sbos/BintelligenceAgent/`. PGE obligatorio (ADR-026), MAX_ITER=5.

### Fase 1A — Indexer y búsqueda léxica (núcleo)
1. Tipos Go: `EventoCanonico`, `Resultado`, config; driver pgx/v5.
2. Stream Consumer (`bkernel:index_queue`, consumer group, XACK, `_inbox` dedup).
3. Path A (Data Flattening) + Path B (texto_plano) → UPSERT `busqueda_universal`.
4. DLQ tras 3 fallos (`bkernel:index_dlq`) con motivos del contrato §IX.
5. `busqueda_universal` particionado por `origen_db` + diccionarios ES.

### Fase 1B — WebSocket, seguridad, Interface Dual
6. WebSocket `wss` (gorilla/nhooyr): Origin, rate limit, ping/pong.
7. Auth JWT Keycloak + BitMask bAuth por partición.
8. Búsqueda léxica con `websearch_to_tsquery` + `ts_rank` + `context.WithCancel`.
9. Caché L1 (`sync.Map`) + L2 (Redis).
10. Interface Dual: CLI `clap`-equivalente Go + Unix socket JSON-RPC + dispatcher.
11. Schema Discoverer (patrones DRAFT por app).

### Fase 1C — Terreno semántico (sin IA)
12. Crear `semantic_store` + `semantic_index` (HALFVEC nullable, particionado, sin HNSW).
13. En el indexer: UPSERT paralelo a `semantic_index` con `plain_text` + metadata.
14. `elegibilidad.yaml` (qué se indexa) + job TTL.
15. Métricas, dashboard, alerts; certificación C-01..C-12.

### Fase 2 — IA semántica (diferida, terreno ya preparado)
16. Servicio de embeddings local/soberano (aiserver) — decisión de presupuesto/HITL.
17. Backfill de embeddings sobre `plain_text` acumulado + HNSW por partición.
18. Búsqueda híbrida (fusión léxico+semántico) + umbral de migración (guía §5.3).

---

## 11. Coordinación entre los 3 daemons de datos

> **Sección espejo en los 3 manuales — contrato de coordinación común.**

### 11.1 El modelo corregido (decisión HITL, jun 2026)

```
        WAL / Binlog / CDC  (multi-motor)
                 │
                 ▼
      ┌────────────────────┐   bKernel SOLO ESCUCHA · nadie lo llama
      │      bKernel        │
      └─────┬─────────┬─────┘
   ESCRIBIR │         │ INDEXAR (Redis Stream bkernel:index_queue)
 (Unix sock)│         │
            ▼         ▼
   ┌────────────────┐  ┌──────────────────────────────────────┐
   │   biedata      │  │            bSearch                    │
   │ ÚNICO escritor │  │  consume UNA vez → escribe en SUS     │
   └───────┬────────┘  │  dos índices:                         │
           ▼           │   · busqueda_universal (léxico, F1)   │
  Tryton/Keycloak/...  │   · semantic_index (terreno, F1→F2)   │
                       └──────────────────────────────────────┘
```

### 11.2 Reparto de responsabilidades

| Daemon | Su ficha/patrón programa… | ¿Toca BD de negocio? | Interface entrante |
|---|---|---|---|
| **bKernel** | qué tarea de biedata disparar + qué publicar a bSearch | ❌ nunca | ninguna (cero superficie) |
| **biedata** | cómo validar y escribir | ✅ único escritor | `:9470` + Unix socket + CLI |
| **bSearch** | cómo indexar (léxico + terreno semántico) | ❌ solo sus índices | WebSocket `wss` + Unix socket (control) |

### 11.3 Lo que bSearch espera de bKernel (contrato)

- Evento canónico con `event_id` único, `_meta.contrato_version`, `source.motor`.
- `index_hints.texto_plano` **obligatorio para motor ≠ postgresql** (si falta → DLQ).
- `payload_navegacion.uri_resuelta` (deep-link), `tenant_id` no nulo, `traceparent`.
- `app_slug` registrado en `bsearch_db.app_registry` (si no → DLQ).

### 11.4 Lo que bSearch NO hace

- No se conecta a las BDs de las apps para escribir (Frontera B9 — solo deep-link).
- No genera embeddings llamando a servicios externos (Fase 2 = IA local).
- No es fuente de verdad: todo resultado lleva al formulario real de la app origen.

---

## 12. Fronteras inviolables

| # | bSearch NUNCA |
|---|---|
| B1 | Toca las BDs de las aplicaciones (solo lee vía bKernel/CDC; deep-link a origen) |
| B2 | Expone HTTP REST de búsqueda (solo `wss`) |
| B3 | Muestra sus datos como definitivos (Frontera B9 — siempre deep-link a la fuente) |
| B4 | Indexa un evento sin pasar por `_inbox` (deduplicación) |
| B5 | Genera embeddings con servicios externos (Fase 2 = local/soberano) |
| B6 | Confía en el `realm` del cliente (lo extrae del JWT) |
| B7 | Crea el índice HNSW en Fase 1 (terreno preparado, motor apagado) |

---

## 13. Trazabilidad

| Sección | Fuente |
|---|---|
| Identidad, destilación, WebSocket, Go | `DAEMON-BSEARCH.md` (con corrección de §2.5) |
| Contrato de indexación, paths, garantías | `CONTRATO-BKERNEL-BSEARCH.md` |
| DDL compartida | `DDL-COMPARTIDA-BKERNEL-BSEARCH.md` |
| BD paralela, HALFVEC, particionado, crecimiento | `pgvector_guia_completa.md` (adaptada a SBOS) |
| **Dos fases (léxica F1 / IA F2)** | **Decisión HITL 2026-06-01** |
| **Multi-motor vigente / §2.5 vestigio** | **Decisión HITL 2026-06-01** |
| **Interface Dual** | **ADR-020** |
| WebSocket/RPC/errores | ORQUESTA-043 (Partes 1, 6) |

---

_SKULL · SBOS · MANUAL-DESARROLLO-BSEARCH · v1.0 · Junio 2026 · biblio-dev_
_Fase 1: búsqueda léxica + terreno semántico preparado · Fase 2: IA local + híbrido_
