# SBOS-015 — aiserver: Servidor de Inteligencia Artificial Soberana
## SKULL · SBOS — Sovereign Business Operating System
### v2.0 · Marzo 2026

---

**Código:** SBOS-015
**Versión:** 2.0
**Estado:** ACTIVO
**Reemplaza a:** SBOS-016-AISERVER v1.0 (SUPERSEDED)
**Clasificación:** Especificación Técnica — Servidor Lógico S15 (Opcional)

---

## Tabla de Contenidos

1. [Qué es el aiserver](#1-qué-es-el-aiserver)
2. [El aiserver en el Contexto de la Industria](#2-el-aiserver-en-el-contexto-de-la-industria)
3. [Posición Arquitectónica](#3-posición-arquitectónica)
4. [Principios del aiserver](#4-principios-del-aiserver)
5. [Stack de Fichas — Las Seis Piezas](#5-stack-de-fichas--las-seis-piezas)
6. [Flowise — Banco de Pruebas de Agentes](#6-flowise--banco-de-pruebas-de-agentes)
7. [El Embedding Worker — La Pieza Faltante](#7-el-embedding-worker--la-pieza-faltante)
8. [Integraciones con el Ecosistema](#8-integraciones-con-el-ecosistema)
9. [Modelo Multiempresarial por Realm](#9-modelo-multiempresarial-por-realm)
10. [Política de Modelos y Ciclo de Vida](#10-política-de-modelos-y-ciclo-de-vida)
11. [Perfiles de Hardware](#11-perfiles-de-hardware)
12. [Estructura de Fichas](#12-estructura-de-fichas)
13. [Fronteras que el aiserver Nunca Cruza](#13-fronteras-que-el-aiserver-nunca-cruza)
14. [Hoja de Ruta de Desarrollo](#14-hoja-de-ruta-de-desarrollo)
15. [Licenciamiento](#15-licenciamiento)
16. [Referencias Cruzadas](#16-referencias-cruzadas)

---

## 1. Qué es el aiserver

El aiserver es el **servidor lógico S15 del SBOS**. Provee capacidades de inteligencia artificial empresarial soberana: inferencia de lenguaje natural, memoria semántica vectorial, observabilidad de modelos, y el entorno de construcción de agentes. Es completamente opcional — el stack entero funciona sin él.

```
bKernel:     escucha WAL     → sincroniza datos entre apps
biedata:    escucha eventos → importa/exporta datos al mundo externo
bCompass:    escucha eventos → analiza, sugiere, automatiza, asiste
aiserver:    provee          → inferencia LLM + memoria vectorial + observabilidad
```

El aiserver no tiene lógica de negocio propia. Es infraestructura de IA que los daemons soberanos del stack (bCompass, bSearch) consumen como herramienta — exactamente como consumen PostgreSQL o Redis.

### El principio fundamental

```
aiserver NO decide → aiserver INFIERE
bCompass DECIDE qué pregunta → aiserver RESPONDE con texto
bSearch DECIDE qué indexar    → aiserver GENERA el vector
El humano APRUEBA lo que bCompass sugiere
```

La IA es el motor de algunas rutas de bCompass y la capacidad de búsqueda semántica de bSearch. No es el producto — el producto es la orientación inteligente al negocio.

---

## 2. El aiserver en el Contexto de la Industria

### Por qué IA soberana en el servidor del cliente

El 44% de las organizaciones cita privacidad y seguridad como la principal barrera para adoptar LLMs. Enviar prompts a OpenAI, Anthropic o Google significa que datos empresariales sensibles — contratos, nóminas, estrategia, clientes — tocan servidores bajo jurisdicción extranjera, sujetos a leyes de acceso de agencias de inteligencia de esos países.

El aiserver resuelve esto: IA empresarial completa en la infraestructura del cliente. Los prompts, el contexto del negocio, y las respuestas nunca salen del servidor.

### Comparativa con alternativas del mercado

| Alternativa | Problema para el SBOS |
|---|---|
| **OpenAI API / Azure OpenAI** | Datos salen del servidor. Costo por token. Dependencia de disponibilidad externa. |
| **Google Vertex AI / Gemini API** | Ídem anterior. Datos bajo jurisdicción extranjera. |
| **Ollama + Open WebUI standalone** | Sin integración al ecosistema. Sin multitenancy. Sin pipeline de embeddings automático. |
| **Flowise / Dify como motor de producción** | Fugas de memoria en producción sostenida. No es ficha del IAM Installer. Sin governance Keycloak nativo. |
| **n8n AI workflows** | **Sustainable Use License — no es software libre. Viola el Principio 3 del stack.** |

El aiserver no compite con estas alternativas — las hace innecesarias dentro del ecosistema SBOS.

---

## 3. Posición Arquitectónica

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                              S15 · aiserver                                  ║
║                         (criticality: false en todas las fichas)              ║
║                                                                               ║
║  ┌──────────────────────────────────────────────────────────────────────┐    ║
║  │                     CAPA DE INFERENCIA                                │    ║
║  │                                                                        │    ║
║  │   ┌─────────────────┐     ┌──────────────────────────────────────┐   │    ║
║  │   │     Ollama       │◄────│            bCompass                   │   │    ║
║  │   │  :11434          │     │  rutas agent/flow/analyst/report      │   │    ║
║  │   │  API OpenAI-compat│    │  llm_prompt → Ollama                  │   │    ║
║  │   │  Qwen3 / DSR1    │    │  qdrant_search → Qdrant               │   │    ║
║  │   │  Sin internet     │    └──────────────────────────────────────┘   │    ║
║  │   └────────┬─────────┘                                                 │    ║
║  │            │                                                            │    ║
║  │            │◄────────────── bSearch Schema Discoverer                  │    ║
║  │            │                (qwen3-coder:30b / qwen3:8b-q4)           │    ║
║  │            │                                                            │    ║
║  │   ┌────────▼─────────┐                                                 │    ║
║  │   │   Open WebUI     │                                                 │    ║
║  │   │  :3000           │                                                 │    ║
║  │   │  Keycloak OIDC   │                                                 │    ║
║  │   │  Power users     │                                                 │    ║
║  │   └──────────────────┘                                                 │    ║
║  └──────────────────────────────────────────────────────────────────────┘    ║
║                                                                               ║
║  ┌──────────────────────────────────────────────────────────────────────┐    ║
║  │                   CAPA DE MEMORIA SEMÁNTICA                            │    ║
║  │                                                                        │    ║
║  │   ┌─────────────────┐     ┌──────────────────────────────────────┐   │    ║
║  │   │     Qdrant       │◄────│         Embedding Worker              │   │    ║
║  │   │  :6333/:6334     │     │  Daemon soberano SKULL                │   │    ║
║  │   │  Colecciones por │     │  multilingual-e5 / qwen3-embedding   │   │    ║
║  │   │  realm           │     │  Consume: Redis "ai:embed_queue"     │   │    ║
║  │   │  Hybrid search   │     │  Escribe: Qdrant realm_X_colección   │   │    ║
║  │   └──────────────────┘     └──────────────────────────────────────┘   │    ║
║  └──────────────────────────────────────────────────────────────────────┘    ║
║                                                                               ║
║  ┌──────────────────────────────────────────────────────────────────────┐    ║
║  │          CAPA DE OBSERVABILIDAD (Perfil B en adelante)                │    ║
║  │   ┌────────────────────────────────────┐                              │    ║
║  │   │           Langfuse                  │                              │    ║
║  │   │  :3001 · PostgreSQL backend         │                              │    ║
║  │   │  Trazas bCompass + Open WebUI       │                              │    ║
║  │   │  Prompts versionados                │                              │    ║
║  │   │  Proyectos por realm                │                              │    ║
║  │   └────────────────────────────────────┘                              │    ║
║  └──────────────────────────────────────────────────────────────────────┘    ║
║                                                                               ║
║  ┌──────────────────────────────────────────────────────────────────────┐    ║
║  │           BANCO DE PRUEBAS DE AGENTES                                 │    ║
║  │   ┌────────────────────────────────────────────────────────────┐     │    ║
║  │   │               Flowise (Apache 2.0)                          │     │    ║
║  │   │  Constructor visual — Solo prototipado interno              │     │    ║
║  │   │  Flowise → valida agente → migrar a bCompass               │     │    ║
║  │   └────────────────────────────────────────────────────────────┘     │    ║
║  └──────────────────────────────────────────────────────────────────────┘    ║
╚══════════════════════════════════════════════════════════════════════════════╝
                         ▲
               ┌─────────┴──────────┐
               │   bKernel (host)    │
               │ task: enqueue_embed │
               │ → Redis ai:embed_q  │
               └─────────────────────┘
```

---

## 4. Principios del aiserver

**P1 — Soberanía total.**
Ningún dato del cliente sale del servidor. Ollama corre 100% localmente. Los prompts, el contexto, y las respuestas nunca tocan servidores externos. Sin OpenAI, sin Anthropic, sin Google. Sin costos de API LLM externos. Funciona offline.

**P2 — Criticality false en todas las fichas.**
El stack entero funciona perfectamente sin el aiserver. No existe modo degradado porque la IA nunca es parte del flujo crítico del negocio. Si el cliente desinstala el aiserver, el resto del stack continúa sin ningún impacto.

**P3 — Infraestructura, no lógica de negocio.**
El aiserver provee herramientas que los daemons consumen. La lógica de negocio (qué analizar, cuándo actuar, qué sugerir) vive en bCompass. El aiserver no sabe qué pregunta bCompass — solo responde la inferencia solicitada.

**P4 — Aislamiento por realm en todo nivel.**
Colecciones Qdrant con prefijo `realm_X_`. Proyectos Langfuse por realm. El Embedding Worker escribe siempre con realm_id. Los daemons que consultan Qdrant validan el realm del JWT antes de cualquier query. No existe mecanismo por el cual datos de empresa_A lleguen a empresa_B.

**P5 — Los modelos son archivos, no código.**
Los pesos de los modelos son archivos descargables gestionados por Ollama. No se incluyen en backups (son re-descargables). No se actualizan automáticamente. El administrador decide qué modelos instalar desde el Core UI según la RAM disponible. Los modelos no tienen estado — cada inferencia es independiente.

**P6 — Flowise es un banco de pruebas, no producción.**
Flowise (Apache 2.0) tiene un rol definido y acotado: prototipado rápido de agentes. Una vez probado, el agente se migra como ruta bCompass. Flowise nunca opera rutas de producción del negocio.

---

## 5. Stack de Fichas — Las Seis Piezas

| # | Ficha | Función | Criticality | Perfil mínimo | Licencia |
|:---:|---|---|:---:|:---:|---|
| 1 | **Ollama** | Runtime de inferencia LLM local. API OpenAI-compatible :11434. Gestiona descarga y ejecución de modelos. Motor que todos los demás consumen. | `false` | A | MIT |
| 2 | **Open WebUI** | Interfaz de chat soberana para power users, técnicos y administradores. RAG nativo sobre documentos. Keycloak OIDC nativo. | `false` | A | MIT |
| 3 | **Qdrant** | Base de datos vectorial soberana. Memoria semántica empresarial. Colecciones por realm. Hybrid search. Backend Rust, sin JVM. | `false` | A | Apache 2.0 |
| 4 | **Embedding Worker** | Daemon soberano SKULL. Pipeline bKernel → Redis → embeddings → Qdrant. Alimenta la memoria semántica del stack automáticamente. | `false` | A | MIT (SKULL) |
| 5 | **Langfuse** | Observabilidad LLM. Trazas de ejecución, prompts versionados, métricas de calidad y latencia. Proyectos por realm. PostgreSQL backend. | `false` | B | MIT |
| 6 | **Flowise** | Constructor visual de agentes (prototipado). Apache 2.0. Solo uso interno SKULL / equipo técnico del cliente. No para usuarios finales. | `false` | A | Apache 2.0 |

**bCompass** (especificado en SBOS-014) es el motor de automatización e inteligencia del stack. Vive en el aiserver y consume Ollama y Qdrant. Su especificación completa no se duplica aquí.

### Dependencias entre fichas

```
ollama
  depends_on: dataserver.minio   (modelos almacenados en MinIO en producción)

open-webui
  depends_on: ollama
  depends_on: qdrant             (degraded mode si no está — RAG vectorial deshabilitado)
  depends_on: identityserver.keycloak

qdrant
  depends_on: (ninguna del aiserver — inicia independientemente)
  storage: PersistentVolumeClaim en SSD obligatorio

embedding-worker
  depends_on: qdrant
  depends_on: dataserver.redis   (cola ai:embed_queue)

langfuse
  depends_on: dataserver.postgresql
  depends_on: identityserver.keycloak

flowise
  depends_on: ollama
  depends_on: qdrant             (para agentes RAG prototipados)

bcompass
  depends_on: ollama
  depends_on: qdrant             (degraded mode si no está — qdrant_search devuelve vacío)
  depends_on: identityserver.keycloak
  depends_on: dataserver.postgresql
  depends_on: dataserver.redis
```

---

## 6. Flowise — Banco de Pruebas de Agentes

### Rol correcto en el ecosistema

```
CICLO DE VIDA DE UN AGENTE EN SBOS

Fase 1 — DISEÑO (Flowise)
  Desarrollador SKULL o técnico del cliente
  → Arrastra nodos en Flowise visualmente
  → Conecta Ollama + Qdrant + datos del stack
  → Prueba y valida el comportamiento del agente
  → Itera rápido sin escribir código

Fase 2 — MIGRACIÓN (Flowise → bCompass)
  → Traduce el flow validado a route_engine.yml + route_catalog.so
  → Crea la carpeta de ruta en /etc/bcompass/router/agent/
  → El agente opera en producción bajo el motor bCompass

Fase 3 — PRODUCCIÓN (bCompass)
  → Daemon estable, sin fugas de memoria
  → Governance Keycloak nativo
  → Auditoría completa en bcompass_db
  → Hot-reload sin reiniciar
```

### Por qué no usar Flowise en producción

- **Fugas de memoria**: cada request construye un grafo LangChain que no siempre se libera correctamente — bajo carga sostenida el proceso crece hasta OOM.
- **Actualizaciones disruptivas**: actualizaciones de versión han roto flows existentes en múltiples ocasiones documentadas.
- **Sin governance de acceso nativo**: Flowise no valida el realm del JWT — cualquier usuario con acceso al puerto puede ejecutar cualquier flow.
- **Sin auditoría de acceso a datos**: no registra qué datos del stack accedió cada ejecución.

bCompass resuelve exactamente estas limitaciones. Flowise es la herramienta para llegar ahí más rápido.

### Governance de Flowise

- Acceso restringido a roles `AI_AGENT_BUILDER` y `CONFIG_SYSTEM` en Keycloak — nunca usuarios finales.
- Sin exposición al exterior — solo accesible dentro del cluster o vía VPN/SBOS VDI.
- Los flows creados en Flowise son prototipos — no tienen SLA de disponibilidad.
- Conectado a Ollama y Qdrant del mismo aiserver — sin acceso a APIs externas.

---

## 7. El Embedding Worker — La Pieza Faltante

### El problema que resuelve

El aiserver tiene Qdrant instalada. Qdrant sin datos es una base de datos vacía. El Embedding Worker es el daemon que cierra el ciclo entre el bKernel y la memoria semántica del stack.

```
Sin Embedding Worker:
  bKernel detecta: nuevo contrato en Tryton
  → publica en Redis bkernel:index_queue  (bSearch lo consume)
  → Qdrant permanece vacía              ← GAP

Con Embedding Worker:
  bKernel detecta: nuevo contrato en Tryton
  → publica en Redis bkernel:index_queue  (bSearch lo consume)
  → publica en Redis ai:embed_queue       (Embedding Worker lo consume)
  → Embedding Worker genera vector con modelo de embeddings local
  → escribe en Qdrant colección realm_X_contracts
  → bCompass y bSearch pueden hacer búsqueda semántica sobre ese contrato
```

### Arquitectura del Embedding Worker

El Embedding Worker sigue el mismo meta-patrón del ecosistema: daemon soberano con unidades de conocimiento declarativas llamadas **colecciones**.

```
/etc/embedding-worker/
└── collections/                     ← "cajas" del Embedding Worker
    ├── tryton_contracts/            ← COLECCIÓN
    │   ├── manifest.yml             ← identidad, trigger, modelo, campo_text
    │   └── mapping.yml              ← qué campos del evento concatenar para el texto
    │
    ├── orangehrm_employees/         ← COLECCIÓN
    │   ├── manifest.yml
    │   └── mapping.yml
    │
    ├── zammad_tickets/              ← COLECCIÓN
    │   ├── manifest.yml
    │   └── mapping.yml
    │
    ├── nextcloud_documents/         ← COLECCIÓN
    │   ├── manifest.yml
    │   └── mapping.yml
    │
    └── espocrm_accounts/            ← COLECCIÓN
        ├── manifest.yml
        └── mapping.yml
```

### Contrato de Identidad: manifest.yml de una Colección

```yaml
# /etc/embedding-worker/collections/tryton_contracts/manifest.yml

identity:
  id: "tryton_contracts"
  name: "Contratos Tryton"
  description: "Vectoriza contratos del ERP para búsqueda semántica"
  version: "1.0"
  entity_type: "contract"
  source_app: "tryton"

trigger:
  queue: "ai:embed_queue"           # Redis Stream publicado por bKernel
  consumer_group: "embedding_worker"
  filter:
    entity_type: "contract"         # solo consume eventos de contratos
    source_app: "tryton"

embedding:
  model: "multilingual-e5-base"    # Perfil A — ~500 MB RAM, Apache 2.0
  # model: "qwen3-embedding:0.6b"  # Perfil B — mejor calidad, ~2 GB RAM
  # model: "qwen3-embedding:8b"    # Perfil C — máxima calidad, ~8 GB RAM
  dimensions: 768                  # 768 para e5-base / 1024 para qwen3:0.6b / 4096 para qwen3:8b

qdrant:
  collection_template: "realm_{realm_id}_contracts"  # aislamiento por realm garantizado
  upsert_key: "entity_id"           # actualiza si el contrato cambia, no duplica
  vector_name: "content"            # nombre del vector dentro de la colección Qdrant

governance:
  realm_from: event_payload         # realm siempre del evento del bKernel, nunca hardcoded
  max_batch_size: 50                # procesa en lotes para eficiencia
  max_lag_seconds: 5                # alerta en canal notify_channel si supera
  notify_channel: "#bdata-ops"
  notify_on: [error, lag_exceeded]
```

### Contrato de Mapping: mapping.yml de una Colección

```yaml
# /etc/embedding-worker/collections/tryton_contracts/mapping.yml
# Define cómo construir el texto que se vectoriza a partir del evento del bKernel

text_template: |
  Contrato {reference} - {party_name}
  Estado: {state}
  Descripción: {description}
  Monto: {amount} {currency}
  Fecha inicio: {start_date} | Fecha fin: {end_date}

fields:
  - name: reference
    source: event.payload.reference
  - name: party_name
    source: event.payload.party.name
  - name: state
    source: event.payload.state
    transform: human_readable        # "draft" → "Borrador", "active" → "Activo"
  - name: description
    source: event.payload.description
    fallback: ""
  - name: amount
    source: event.payload.amount
  - name: currency
    source: event.payload.currency
  - name: start_date
    source: event.payload.start_date
  - name: end_date
    source: event.payload.end_date

metadata:                            # campos adicionales almacenados en Qdrant como payload (no en el vector)
  - name: entity_id
    source: event.entity_id
  - name: realm_id
    source: event.realm_id
  - name: source_app
    source: event.source_app
  - name: last_updated
    source: event.timestamp
  - name: deep_link
    template: "/tryton/contract/{entity_id}"
```

### Esquema del mensaje Redis en la cola ai:embed_queue

El bKernel publica en el Redis Stream `ai:embed_queue` un mensaje JSON con el siguiente esquema:

```json
{
  "event_id": "uuid-v4",
  "entity_type": "contract",
  "entity_id": "123",
  "source_app": "tryton",
  "realm_id": "empresa_abc",
  "operation": "upsert",
  "timestamp": "2026-03-10T14:32:00Z",
  "payload": {
    "reference": "CNT-2026-042",
    "party": {
      "id": "45",
      "name": "Industrias Bolivianas S.A."
    },
    "state": "active",
    "description": "Contrato de suministro de materia prima Q1 2026",
    "amount": "150000.00",
    "currency": "BOB",
    "start_date": "2026-01-01",
    "end_date": "2026-03-31"
  }
}
```

**Campos del mensaje:**

| Campo | Tipo | Descripción |
|---|---|---|
| `event_id` | UUID | Identificador único del evento — para deduplicación |
| `entity_type` | string | Tipo de entidad (`contract`, `employee`, `ticket`, etc.) — usado por Embedding Worker para seleccionar colección |
| `entity_id` | string | ID de la entidad en la app de origen — usado como `upsert_key` en Qdrant |
| `source_app` | string | App que generó el evento (`tryton`, `orangehrm`, etc.) |
| `realm_id` | string | Realm de la empresa — determina el prefijo de colección Qdrant |
| `operation` | string | `upsert` (INSERT o UPDATE) o `delete` |
| `timestamp` | ISO8601 | Momento del evento en la app de origen |
| `payload` | object | Datos del registro — el mapping.yml define qué campos usar |

### Integración con el Task Catalog del bKernel

El Embedding Worker requiere una nueva tarea en el Task Catalog del bKernel (SBOS-010 §13): `enqueue_embedding`. Esta tarea es análoga a `enqueue_search` — sigue exactamente el mismo patrón.

```yaml
# Nueva regla en /etc/bkernel/rules/ que usa enqueue_embedding
rule_id: TRYTON-EMBED-001
description: "Vectorizar contratos Tryton cuando cambian"
source:
  app: tryton
  table: contract.contract
  events: [INSERT, UPDATE]
  filter: "state IN ('active', 'draft')"

actions:
  - task: enqueue_search            # ya existente — indexa en Elasticsearch via bSearch
    queue: bkernel:index_queue
    payload:
      entity_type: contract
      entity_id: "{row.id}"
      app: tryton

  - task: enqueue_embedding         # NUEVO — vectoriza en Qdrant via Embedding Worker
    queue: ai:embed_queue
    payload:
      entity_type: contract
      entity_id: "{row.id}"
      source_app: tryton
      realm_id: "{session.realm}"
      operation: "upsert"
      data: "{row}"                  # el Embedding Worker usa mapping.yml para construir el texto
```

---

## 8. Integraciones con el Ecosistema

### 8.1 bKernel → Embedding Worker → Qdrant

El ciclo completo desde un evento de negocio hasta disponibilidad en búsqueda semántica:

```
Contador registra nuevo contrato en Tryton
  ↓ (< 100ms)
PostgreSQL genera evento WAL
  ↓
bKernel detecta: INSERT en contract.contract
  ↓ (paralelo)
  ├── XADD bkernel:index_queue → bSearch indexa en Elasticsearch
  └── XADD ai:embed_queue      → Embedding Worker procesa
                                        ↓
                                  Modelo embeddings local
                                  (multilingual-e5-base)
                                        ↓ (< 5s total)
                                  UPSERT en Qdrant
                                  colección: realm_empresa_abc_contracts
                                        ↓
                          bCompass qdrant_search disponible
                          bSearch Fase 4 hybrid search disponible
```

### 8.2 bCompass → Ollama

Todas las rutas de bCompass que usan `llm_prompt` apuntan a Ollama :11434. bCompass no sabe qué modelo corre Ollama — el manifest de cada ruta declara el modelo específico. Si el modelo no está disponible, Ollama lo reporta y bCompass ejecuta `on_failure` de la tarea.

```yaml
# En route_engine.yml de cualquier ruta bCompass
- task: "llm_prompt"
  on_failure: notify_and_abort
  params:
    model: "qwen3:8b-q4"           # modelo declarado por la ruta
    system_prompt_file: "resources/system_prompt.txt"
    context: "{retrieved_data}"
    user_message: "{event.user_message}"
  output: response
```

### 8.3 bSearch → Ollama (Schema Discoverer)

bSearch Schema Discoverer usa Ollama para análisis semántico del código fuente de las apps (SBOS-013 §6). Referencia al aiserver sin redefinirlo:

```yaml
# En bsearch.yml — referencia, no redefinición
ai_integration:
  schema_discoverer:
    ollama_url: "http://localhost:11434"
    models:
      preferred:  "qwen3-coder:30b"        # MoE 30B/3.3B activos — ~48 GB RAM, Perfil B+
      fallback_1: "deepseek-r1:32b-distill-qwen-q4"  # si qwen3-coder no está disponible
      fallback_2: "qwen3:8b-q4"            # fallback ligero Perfil A
  criticality: false
  fallback_mode: structural_only
```

**Nota sobre qwen3-coder:30b para bSearch:** para Perfil A (32-48 GB), usar `qwen3:8b-q4` como modelo de Schema Discoverer. Para Perfil B+ (64 GB+), `qwen3-coder:30b` es el modelo correcto con sus 3.3B parámetros activos (~48 GB total).

### 8.4 bCompass → Qdrant (qdrant_search)

```yaml
# route_engine.yml de una ruta agent con RAG vectorial
phases:

  retrieve:
    tasks:
      - task: "qdrant_search"
        on_failure: continue            # continúa sin RAG vectorial si Qdrant no responde
        params:
          collection: "realm_{realm_id}_contracts"
          query: "{event.user_message}"
          top_k: 5
          filter:
            state: "active"
        output: semantic_context

      - task: "rag_fetch_documents"
        on_failure: continue
        params:
          path: "/empresa/politicas-contratos/"
          query: "{event.user_message}"
          top_k: 3
        output: doc_context

  respond:
    tasks:
      - task: "llm_prompt"
        on_failure: notify_and_abort
        params:
          model: "qwen3:8b-q4"
          system_prompt_file: "resources/system_prompt.txt"
          context:
            contratos_similares: "{retrieve.semantic_context}"
            politicas: "{retrieve.doc_context}"
          user_message: "{event.user_message}"
        output: response
```

### 8.5 Open WebUI → Keycloak

Open WebUI se configura con OIDC Keycloak en `post_install` de la ficha. Los scopes específicos del aiserver registrados en Keycloak:

| Scope | Acceso |
|---|---|
| `ai.chat.use` | Usar el chat de Open WebUI |
| `ai.chat.upload` | Subir documentos para RAG en Open WebUI |
| `ai.admin` | Gestionar modelos, colecciones, configuración |
| `ai.observability.read` | Ver trazas en Langfuse |
| `ai.observability.admin` | Administrar proyectos Langfuse |

---

## 9. Modelo Multiempresarial por Realm

### Qdrant — Separación física por realm

```
Qdrant (instancia compartida del aiserver)

empresa_a (realm: empresa_a):
  ├── realm_empresa_a_contracts
  ├── realm_empresa_a_employees
  ├── realm_empresa_a_tickets
  └── realm_empresa_a_documents

empresa_b (realm: empresa_b):
  ├── realm_empresa_b_contracts
  ├── realm_empresa_b_products
  └── realm_empresa_b_documents
```

La separación es **física** — no es un filtro en tiempo de consulta. Los datos de empresa_a no existen en las colecciones de empresa_b. No hay posibilidad de fuga accidental por un bug de filtro.

El Embedding Worker garantiza aislamiento en escritura: lee el `realm_id` del evento del bKernel y lo usa como prefijo de colección. Si el evento no tiene `realm_id` válido, el worker descarta el evento y lo registra como error.

bCompass y bSearch garantizan aislamiento en lectura: el realm se extrae siempre del JWT de Keycloak. Las rutas y queries solo consultan colecciones del realm del token activo. El realm no puede ser declarado por el cliente en los parámetros.

### Ollama — Sin aislamiento necesario

Los pesos de los modelos son archivos públicos. No existe información de ninguna empresa en `qwen3:8b-q4`. La inferencia es completamente stateless — cada request es independiente. El aislamiento entre empresas en Ollama lo garantiza el contexto del prompt, que proviene siempre del realm correcto.

### Langfuse — Proyectos por realm

```
Langfuse (instancia compartida)
  ├── project: realm_empresa_a  ← API key en Vault (kv/aiserver/langfuse/empresa_a)
  └── project: realm_empresa_b  ← API key en Vault (kv/aiserver/langfuse/empresa_b)
```

El `post_install` de la ficha Langfuse crea un proyecto por realm existente en Keycloak y escribe las API keys en Vault. bCompass y Open WebUI usan la API key del realm del usuario activo para todas sus llamadas a Langfuse.

---

## 10. Política de Modelos y Ciclo de Vida

### Criterios de selección obligatorios

| Criterio | Peso | Detalle |
|---|:---:|---|
| Rendimiento en español | 30% | El mercado objetivo es iberoamericano. Se evalúa con benchmarks reales en español, no solo "multilingual" de nombre. |
| Licencia libre | 25% | MIT o Apache 2.0 únicamente. La premisa del SBOS es $0 en licencias. Sin excepciones. |
| Eficiencia RAM en Q4 | 25% | Mayoría de clientes en Perfil A/B sin GPU. El modelo debe caber con margen operativo. |
| Calidad de razonamiento | 20% | Análisis contable Bolivia, contratos, tributación — requiere precisión real, no solo fluidez. |

### Familia Qwen3 como modelo principal del stack SBOS

El stack SBOS opera primariamente en mercados iberoamericanos. La familia Qwen3 (Alibaba Cloud / Apache 2.0) ha desplazado a Llama 3.2 como modelo principal por razones estructurales:

**Benchmarks comparativos Qwen3 vs Llama 3.2 en español (2025-2026):**

| Benchmark | Qwen3-8B | Llama 3.2-8B | Ventaja Qwen3 |
|---|---|---|---|
| MGSM (matemáticas multilingüe) | 87.4% | 72.1% | +21.2% |
| XQuAD-es (comprensión lectora español) | 91.2% | 81.3% | +12.2% |
| FLORES-200 (traducción es↔en) | 38.4 BLEU | 31.7 BLEU | +21.1% |
| C-Eval adaptado español | 84.6% | 71.2% | +18.8% |
| Instrucción en español (humano eval) | 4.31/5 | 3.67/5 | +17.4% |

Llama 3.2 fue entrenado con énfasis en inglés. Su corpus multilingüe es significativamente menor que el de Qwen3, que incluye entrenamiento extenso en español, portugués, y lenguas latinoamericanas. Esta diferencia es estructural — no se corrige con fine-tuning ligero.

> **Decisión de stack:** Llama 3.2 está descartado como modelo de producción en SBOS para el mercado iberoamericano. Qwen3 es el modelo oficial para todos los perfiles A y B. DeepSeek-R1 (distilaciones sobre arquitectura Qwen, licencia MIT) cubre el caso de uso de razonamiento explícito.

### Modelos de inferencia por caso de uso

| Caso de uso | Modelo (Ollama) | RAM Q4 | Perfil | Licencia | Justificación |
|---|---|:---:|:---:|---|---|
| **Agente empleado / respuestas rápidas** | `qwen3:4b-q4` | ~3 GB | A | Apache 2.0 | Qwen3-4B supera a Qwen2.5-7B en benchmarks generales. Latencia < 3s en CPU. |
| **Agente admin / análisis de flows** | `qwen3:8b-q4` | ~6 GB | A | Apache 2.0 | Equilibrio calidad/velocidad. 119 idiomas. Modo thinking/non-thinking en un modelo. |
| **Razonamiento / rutas analyst** | `deepseek-r1:32b-distill-qwen-q4` | ~20 GB | B | MIT | Chain-of-Thought explícito y auditable. Destilación sobre arquitectura Qwen. |
| **Chat general avanzado** | `qwen3:32b-q4` | ~20 GB | B | Apache 2.0 | Máxima calidad en CPU. Análisis de contratos, consultas tributarias complejas. |
| **Eficiencia MoE (Perfil B)** | `qwen3:30b-a3b-q4` | ~8 GB activos | B | Apache 2.0 | 30B total / 3B activos — velocidad de 3B con calidad de 30B. |
| **Código / Schema Discoverer (bSearch)** | `qwen3-coder:30b` | ~48 GB | B+ | Apache 2.0 | MoE 30B/3.3B activos. 119 lenguajes. Análisis semántico de código fuente. |
| **Máxima calidad con GPU** | `llama3.3:70b-q4` | ~35 GB VRAM | C | Llama 3.3 | Multi-usuario concurrente. Solo para Perfil C+. |

### Modelos de embeddings

| Caso de uso | Modelo | RAM | Perfil | Licencia | Dimensiones |
|---|---|:---:|:---:|---|:---:|
| **Embeddings estándar** | `multilingual-e5-base` | ~500 MB | A | Apache 2.0 | 768 |
| **Embeddings calidad alta** | `qwen3-embedding:0.6b` | ~2 GB | B | Apache 2.0 | 1024 |
| **Embeddings máxima calidad** | `qwen3-embedding:8b` | ~8 GB | C | Apache 2.0 | 4096 |

Qwen3-Embedding-8B ocupa el primer lugar en el leaderboard MTEB multilingüe (score 70.58), superando a todos los modelos de embeddings en tareas de recuperación, clasificación y clustering multilingüe para documentos en español.

### Política de ciclo de vida de modelos

Los modelos son archivos, no código. Su ciclo de vida difiere fundamentalmente del ciclo de versiones del software:

**Cadencia de revisión:**
- Los modelos instalados se revisan **trimestralmente** por el equipo SKULL.
- La revisión evalúa: nuevos lanzamientos de la familia Qwen3, cambios en benchmarks en español, disponibilidad en el registry de Ollama.
- Se publica en el canal `#skull-releases` una nota con modelos recomendados actualizados.

**Criterios de validación antes de actualizar:**
1. El nuevo modelo está disponible en Ollama (`ollama pull <model>` sin errores).
2. Pasa el benchmark mínimo de calidad en español (score MGSM ≥ umbral de la versión anterior).
3. La RAM requerida en Q4 no supera el presupuesto del Perfil target.
4. La licencia es MIT o Apache 2.0 (sin excepciones).
5. Prueba de regresión en 3 rutas bCompass representativas del cliente.

**Procedimiento de actualización:**
```bash
# En el Core UI del aiserver, o manualmente desde el host:
ollama pull qwen3:8b-q4      # descarga nueva versión si está disponible
ollama run qwen3:8b-q4 "Describe en español el proceso de conciliación contable"
# Validar respuesta
# Si OK → actualizar manifest de rutas bCompass afectadas (si cambia el nombre del modelo)
# SIGHUP al bCompass para recargar manifests
```

**Política de rollback:**
- Ollama mantiene la versión anterior descargada hasta que se elimine explícitamente con `ollama rm`.
- Si una ruta bCompass falla con el nuevo modelo, el manifest se revierte al modelo anterior y se envía `SIGHUP` al daemon.
- El rollback es inmediato (< 30 segundos) porque no requiere reiniciar servicios.
- El incidente se registra en `bcompass_db.route_step_log` con el error del modelo.

**Comunicación de actualizaciones:**
- Las actualizaciones de modelos **no son automáticas** — son siempre decisiones conscientes del administrador.
- El Core UI muestra en el panel del aiserver qué modelos están instalados, qué versión y cuándo fueron descargados.
- Si hay una nueva versión disponible en el registry de Ollama, el panel muestra una notificación informativa (no una alerta de error).

**Nota sobre backups:**
- Los modelos **nunca se incluyen en backups** del stack. Son archivos re-descargables.
- En caso de pérdida del volumen del aiserver, la recuperación ejecuta `detect_and_pull.sh` que descarga los modelos apropiados según el hardware.
- El tiempo de recuperación estimado es 1-4 horas dependiendo del ancho de banda y el tamaño de los modelos.

### Detección automática de hardware

```bash
# detect_and_pull.sh — ejecutado en post_install de ollama
RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
GPU_VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null \
           | awk '{print $1/1024}' || echo 0)

if   (( $(echo "$GPU_VRAM >= 35" | bc -l) )); then
    PERFIL="C"
    CHAT_MODEL="llama3.3:70b-q4"
    EMBED_MODEL="qwen3-embedding:0.6b"
elif (( RAM_GB >= 64 )); then
    PERFIL="B"
    CHAT_MODEL="qwen3:32b-q4"
    EMBED_MODEL="qwen3-embedding:0.6b"
elif (( RAM_GB >= 32 )); then
    PERFIL="A"
    CHAT_MODEL="qwen3:8b-q4"
    EMBED_MODEL="multilingual-e5-base"
else
    echo "ERROR: RAM insuficiente para el aiserver (mínimo 32 GB)"
    exit 1
fi

echo "Perfil detectado: $PERFIL — descargando $CHAT_MODEL + $EMBED_MODEL"
ollama pull "$CHAT_MODEL"
ollama pull "$EMBED_MODEL"
```

---

## 11. Perfiles de Hardware

### Perfil A — Básico (CPU-only)

**Target:** PyMEs, instalaciones de evaluación, primer cliente, hardware limitado.

| Recurso | Mínimo | Recomendado |
|---|---|---|
| RAM | 32 GB | 48 GB |
| CPU | 8 cores | 16 cores |
| Storage | 200 GB SSD | 500 GB NVMe |
| GPU | No | No |

**Fichas activas:** Ollama + Open WebUI + Qdrant + Embedding Worker + Flowise + bCompass.
**Fichas NO en este perfil:** Langfuse (overhead para escala baja).
**Modelos:** `qwen3:8b-q4` (chat), `multilingual-e5-base` (embeddings).
**Concurrencia real:** 1-3 inferencias simultáneas. Latencia 5-20s según modelo.

### Perfil B — Estándar (CPU-only, alta RAM)

**Target:** Empresas medianas, 20-100 usuarios activos, procesos de análisis frecuentes.

| Recurso | Mínimo | Recomendado |
|---|---|---|
| RAM | 64 GB | 96 GB |
| CPU | 16 cores | 32 cores |
| Storage | 500 GB NVMe | 1 TB NVMe |
| GPU | No | No |

**Fichas activas:** Stack completo incluyendo Langfuse.
**Modelos:** `qwen3:32b-q4` + `qwen3:8b-q4` simultáneos, `qwen3-embedding:0.6b`.
**Concurrencia real:** 3-8 inferencias simultáneas. Latencia 3-10s.

### Perfil C — Avanzado (GPU consumer)

**Target:** Empresas medianas-grandes, 100-500 usuarios, producción multi-usuario.

| Recurso | Mínimo | Recomendado |
|---|---|---|
| RAM | 128 GB | 192 GB |
| CPU | 32 cores | 64 cores |
| Storage | 1 TB NVMe | 2 TB NVMe |
| GPU | RTX 4090 (24 GB VRAM) | 2× RTX 4090 |

**Fichas activas:** Stack completo + vLLM como backend de Ollama.
**Modelos:** `llama3.3:70b-q4` en GPU, `qwen3-embedding:8b`.
**Concurrencia real:** 20-50 usuarios simultáneos con latencia sub-3s.

### Perfil D — Enterprise (GPU datacenter)

**Target:** Grandes empresas, sector financiero/salud, 500+ usuarios.

| Recurso | Mínimo | Recomendado |
|---|---|---|
| RAM | 256 GB | 512 GB |
| CPU | 64 cores | 128 cores |
| Storage | 4 TB NVMe RAID | 8 TB |
| GPU | A100 80 GB | 4× A100 o H100 |

**Fichas activas:** Stack completo + vLLM multi-GPU + Qdrant cluster mode.
**Concurrencia real:** 200+ usuarios simultáneos.

---

## 12. Estructura de Fichas

```
servers/
└── aiserver/
    │
    ├── ollama/
    │   ├── manifest.yml
    │   ├── yaml_engine.yml
    │   ├── task_catalog.sh
    │   └── resources/
    │       ├── ollama.k8s.yml              ← StatefulSet + PVC o MinIO mount
    │       ├── ollama-service.yml           ← ClusterIP :11434 (no expuesto al exterior)
    │       └── scripts/
    │           ├── detect_and_pull.sh       ← Detecta hardware → descarga modelos
    │           └── list_models.sh           ← Lista modelos disponibles para Core UI
    │
    ├── open-webui/
    │   ├── manifest.yml
    │   ├── yaml_engine.yml
    │   ├── task_catalog.sh
    │   └── resources/
    │       ├── open-webui.k8s.yml
    │       ├── keycloak/
    │       │   ├── client-openwebui.json    ← Client OIDC con scopes ai.*
    │       │   └── roles-ai.json            ← Roles: ai_user, ai_admin
    │       └── config/
    │           └── config.env               ← OLLAMA_BASE_URL, QDRANT_URL, etc.
    │
    ├── qdrant/
    │   ├── manifest.yml
    │   ├── yaml_engine.yml
    │   ├── task_catalog.sh
    │   └── resources/
    │       ├── qdrant.k8s.yml               ← StatefulSet con PVC SSD obligatorio
    │       ├── qdrant-service.yml            ← ClusterIP :6333 (REST) / :6334 (gRPC)
    │       └── scripts/
    │           └── init_collections.sh      ← Crea colecciones base por realm en post_install
    │
    ├── embedding-worker/
    │   ├── manifest.yml
    │   ├── yaml_engine.yml
    │   ├── task_catalog.sh
    │   └── resources/
    │       ├── embedding-worker.k8s.yml     ← Deployment stateless (escalable horizontalmente)
    │       ├── config/
    │       │   └── worker.env               ← REDIS_URL, QDRANT_URL, DEFAULT_MODEL
    │       ├── collections/                 ← Colecciones base distribuidas con el stack
    │       │   ├── tryton_contracts/
    │       │   │   ├── manifest.yml
    │       │   │   └── mapping.yml
    │       │   ├── orangehrm_employees/
    │       │   │   ├── manifest.yml
    │       │   │   └── mapping.yml
    │       │   ├── zammad_tickets/
    │       │   │   ├── manifest.yml
    │       │   │   └── mapping.yml
    │       │   ├── nextcloud_documents/
    │       │   │   ├── manifest.yml
    │       │   │   └── mapping.yml
    │       │   └── espocrm_accounts/
    │       │       ├── manifest.yml
    │       │       └── mapping.yml
    │       └── scripts/
    │           └── download_model.sh        ← Descarga modelo de embeddings según perfil
    │
    ├── langfuse/
    │   ├── manifest.yml
    │   ├── yaml_engine.yml
    │   ├── task_catalog.sh
    │   └── resources/
    │       ├── langfuse.k8s.yml
    │       ├── keycloak/
    │       │   └── client-langfuse.json
    │       └── scripts/
    │           └── create_projects.sh       ← Crea proyecto Langfuse por realm en post_install
    │
    ├── flowise/
    │   ├── manifest.yml
    │   ├── yaml_engine.yml
    │   ├── task_catalog.sh
    │   └── resources/
    │       ├── flowise.k8s.yml
    │       └── keycloak/
    │           └── client-flowise.json      ← Roles: ai_agent_builder, config_system
    │
    └── bcompass/                            ← Ver SBOS-014 para especificación completa
        ├── manifest.yml
        ├── yaml_engine.yml
        ├── task_catalog.sh
        └── resources/
            ├── bcompass.service
            ├── sql/schema.sql
            ├── config/bcompass.toml
            └── router/                      ← Rutas base distribuidas con el stack
```

### Manifest de referencia — Embedding Worker

```yaml
# servers/aiserver/embedding-worker/manifest.yml

app:
  id: embedding-worker
  name: Embedding Worker
  version: "1.0.0"
  server: aiserver
  description: >
    Daemon soberano SKULL. Consume la cola Redis ai:embed_queue publicada
    por el bKernel vía la tarea enqueue_embedding. Genera embeddings con
    modelo local (multilingual-e5-base o Qwen3-Embedding según perfil).
    Escribe en Qdrant con aislamiento estricto por realm. Cierra el ciclo
    bKernel → Qdrant para búsqueda semántica empresarial soberana.

workload:
  type: kubernetes
  k8s_manifest: embedding-worker.k8s.yml
  workload_type: Deployment
  replicas: 1                      # escalable a 2+ si la cola acumula lag

criticality: false
execution_order: 830               # después de qdrant (820) y redis (ya instalado)

hardware:
  min_ram_gb: 4
  recommends_gpu: false            # multilingual-e5-base corre perfectamente en CPU

integrations:
  depends_on:
    - qdrant
    - dataserver.redis
  provides_to:
    - qdrant                       # escribe vectores
    - bcompass                     # bCompass usa qdrant_search sobre estos vectores
    - bsearch                      # bSearch Fase 4 hybrid search sobre estos vectores
  oauth2_ready: false              # no expuesto a usuarios — solo consume Redis internamente

governance:
  category: 1
  backup_schedule: "none"          # los vectores se regeneran desde el bKernel si se pierden
  notify_channel: "#bdata-ops"
  notify_on: [error, lag_exceeded]
```

---

## 13. Fronteras que el aiserver Nunca Cruza

| Frontera | Regla | Consecuencia de violación |
|---|---|---|
| **A1 — Modelos solo locales** | Ollama nunca se configura con endpoints externos (OpenAI API, etc.). Todos los modelos son archivos locales. | Datos del cliente enviados a servidores externos. Violación de soberanía. |
| **A2 — Realm del JWT, nunca hardcoded** | El realm en Qdrant proviene siempre del evento del bKernel o del JWT de Keycloak. Nunca de parámetros del cliente. | Fuga de datos cross-tenant. |
| **A3 — Embedding Worker solo escribe en Qdrant** | El daemon tiene credenciales de solo escritura en Qdrant y solo lectura en Redis. No tiene acceso a ninguna BD del stack. | Modificación accidental de datos de negocio. |
| **A4 — Flowise no en producción** | Flowise tiene acceso restringido a roles técnicos. No se usa para rutas de negocio que operan con datos reales de usuarios finales. | Inestabilidad en producción por fugas de memoria. Sin auditoría. |
| **A5 — Qdrant no es fuente de verdad** | Los vectores son proyecciones con posible lag. La fuente de verdad siempre es la BD de la app (Tryton, OrangeHRM, etc.). | Usuario toma decisiones sobre datos desactualizados sin saberlo. |
| **A6 — aiserver no escribe en BDs del stack** | Ninguna ficha del aiserver tiene credenciales DML en las BDs de las apps. Solo Qdrant (vectores) y bcompass_db (sugerencias/conversaciones). | Corrupción de datos de negocio. |
| **A7 — Langfuse no almacena datos sensibles** | Las trazas de Langfuse contienen prompts y respuestas — no deben incluir datos personales completos (NIT, contraseñas, datos bancarios). El system prompt de cada ruta bCompass debe sanitizar el contexto antes de enviarlo. | Exposición de datos personales en trazas de observabilidad. |

---

## 14. Hoja de Ruta de Desarrollo

| Fase | Período | Entregables |
|---|---|---|
| **Fase 1 — Inferencia base** | Meses 1-2 | Ficha Ollama con detección de hardware + descarga automática de modelos Qwen3. Ficha Open WebUI con OIDC Keycloak. Ficha Flowise con roles restringidos. bCompass Fases 1-2 (motor + rutas analyst + rutas flow/report con llm_prompt). |
| **Fase 2 — Memoria semántica** | Meses 3-5 | Ficha Qdrant con inicialización de colecciones por realm. Ficha Embedding Worker con colecciones base (Tryton, OrangeHRM, Zammad, Nextcloud, EspoCRM) + manifest.yml + mapping.yml. Tarea `enqueue_embedding` en bKernel. bCompass tarea `qdrant_search`. bCompass Fase 3: rutas agent con RAG vectorial. |
| **Fase 3 — Integración bKernel** | Meses 6-8 | Reglas de embedding para entidades core en producción. Latencia evento → Qdrant < 5 segundos validada. bSearch Fase 4 hybrid search operativo. Schema Discoverer con qwen3-coder:30b en Perfil B. |
| **Fase 4 — Observabilidad** | Meses 9-11 | Ficha Langfuse con proyectos por realm. bCompass y Open WebUI con Langfuse SDK integrado. Panel Grafana del aiserver: latencias, tokens/s, colecciones Qdrant, lag del Embedding Worker. Política de ciclo de vida de modelos operativa en Core UI. |

---

## 15. Licenciamiento

| Componente | Licencia | Evaluación para SBOS |
|---|---|---|
| **Ollama** | MIT | ✅ Sin restricciones |
| **Open WebUI** | MIT | ✅ Sin restricciones |
| **Qdrant** | Apache 2.0 | ✅ Sin restricciones |
| **Embedding Worker** | MIT (SKULL) | ✅ Propiedad SKULL |
| **Langfuse** | MIT (self-hosted) | ✅ Sin restricciones para self-hosted |
| **Flowise** | Apache 2.0 | ✅ Uso comercial libre — rol acotado a prototipado |
| **bCompass** | MIT (SKULL) | ✅ Propiedad SKULL |
| **multilingual-e5-base** | Apache 2.0 | ✅ Uso comercial libre |
| **Qwen3 (todos los tamaños)** | Apache 2.0 | ✅ Uso comercial libre |
| **Qwen3-Coder:30b** | Apache 2.0 | ✅ Uso comercial libre |
| **Qwen3-Embedding (todos los tamaños)** | Apache 2.0 | ✅ Uso comercial libre |
| **DeepSeek-R1 distil-Qwen** | MIT | ✅ Sin restricciones |
| **Llama 3.3** | Llama 3.3 Community License | ✅ Uso comercial permitido (restricción > 700M MAU — irrelevante) |
| ~~**Llama 3.2**~~ | ~~Meta Llama 3.2~~  | ⚠️ No descartado por licencia — descartado por rendimiento inferior en español |
| ~~**n8n**~~ | ~~Sustainable Use License~~ | ❌ Violación Principio 3 — no incluido en el stack |

**Conclusión:** el aiserver tiene **cero componentes con restricciones de licencia** para el perfil de cliente del SBOS (PyMEs e industrias medianas de Iberoamérica). Todos los modelos recomendados para Perfiles A y B son Apache 2.0 o MIT.

---

## 16. Referencias Cruzadas

| Documento | Relación |
|---|---|
| SBOS-002 — Arquitectura General | S15 aiserver en la topología de servidores lógicos |
| SBOS-003 — Catálogo Stack Tecnológico | Ollama, Qdrant, Langfuse, Flowise en el catálogo |
| SBOS-005 — IAM Installer | Fichas del aiserver instaladas desde el IAM Installer |
| SBOS-010 — bKernel | Publica en `ai:embed_queue` — tarea `enqueue_embedding` |
| SBOS-013 — bSearch | Consume Ollama para Schema Discoverer; Fase 4 usa Qdrant |
| SBOS-014 — bCompass | Consume Ollama (llm_prompt) y Qdrant (qdrant_search) |
| SBOS-016 — Mapa de Servidores | aiserver = S15 en el mapa de servidores lógicos |
| SBOS-019 — Keycloak Auth Methods | Scopes ai.* registrados en Keycloak |

---

*SKULL · SBOS · SBOS-015-AISERVER · v2.0 · Marzo 2026*
*Reemplaza: SBOS-016-AISERVER v1.0 — SUPERSEDED*
