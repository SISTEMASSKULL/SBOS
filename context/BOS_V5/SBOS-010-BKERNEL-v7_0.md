# SBOS-010
## SBOS Data Kernel: Active Orchestration Engine
### Daemon bkernel.service · Lenguaje: Rust (definitivo)

**SKULL · SBOS — Sovereign Business Operating System**
**v8.0 · Marzo 2026 — Integración DLQ, reglas y WAL replay**

**Complemento:** SBOS-010-WAL-ReplayStrategy-v1_0.md (§28 — Estrategia de Replay WAL, Idempotencia y Recovery — integrado en v8.0)

---

| Campo | Valor |
|-------|-------|
| **Nombre original** | SBOS Data Kernel |
| **Nombre conceptual** | SBOS Data Kernel: Active Orchestration Engine |
| **Daemon** | `bkernel` |
| **Servicio systemd** | `bkernel.service` |
| **Lenguaje** | **Rust** — definitivo |
| **Unidad declarativa** | Regla |
| **Directorio** | `/etc/bos/blibs/bkernel/rules/<nombre_regla>/` |

---

## Tabla de Contenidos

1. [Qué es el SBOS Data Kernel](#1-qué-es-el-bkernel)
2. [El SBOS Data Kernel en el Contexto de la Industria](#2-el-bkernel-en-el-contexto-de-la-industria)
3. [Naturaleza del Daemon: El Corazón que no Sale del Cuerpo](#3-naturaleza-del-daemon)
4. [Principio Fundamental: Cero Invasión](#4-cero-invasión)
5. [Las 6 Capacidades Estratégicas del SBOS Data Kernel](#5-las-6-capacidades)
6. [Arquitectura de Conocimiento Externo](#6-arquitectura-de-conocimiento-externo)
7. [El Framework Binario: Rust](#7-el-framework-binario)
8. [Estructura de Reglas por Aplicación](#8-estructura-de-reglas)
9. [Formato de Reglas YAML](#9-formato-yaml)
10. [El CDC Engine — Change Data Capture](#10-el-cdc-engine)
11. [El Problema del Loop Infinito — Solución con pg_replication_origin](#11-loop-infinito)
12. [El Rule Engine — Forward-Chaining](#12-rule-engine)
13. [El Task Catalog — Plugins Nativos y Externos](#13-task-catalog)
14. [Tryton como Hub Central — Arquitectura MDM](#14-tryton-hub)
15. [El Writer Pool — Escritura Idempotente](#15-writer-pool)
16. [Thread Pool Adaptativo y Escalado Vertical](#16-thread-pool)
17. [La Base de Datos Propia del SBOS Data Kernel](#17-bkernel-db)
18. [La Relación SBOS Data Kernel ↔ SBOS Data RAG](#18-relacion-bsearch)
19. [bData e bkAI — Componentes Satélite](#19-componentes-satelite)
20. [Integración con el Ecosistema SBOS](#20-integracion-ecosistema)
21. [Fronteras que el SBOS Data Kernel Nunca Cruza](#21-fronteras)
22. [Fuentes de Verdad por Entidad de Negocio](#22-fuentes-de-verdad)
23. [La Tarea enqueue_embedding en el Task Catalog](#23-enqueue-embedding)
24. [Decisión de Implementación: Rust — Fundamento Técnico](#24-implementacion-dual)
25. [Posicionamiento Competitivo](#25-posicionamiento)
26. [Hoja de Ruta de Desarrollo](#26-hoja-de-ruta)
27. [Registro de Cambios v7.0](#27-registro-de-cambios)
28. [Replay WAL, Idempotencia y Recovery](#28-replay-wal) _(ver SBOS-010-WAL-ReplayStrategy-v1_0.md — integrado en v8.0)_

---

## 1. Qué es el SBOS Data Kernel

El SBOS Data Kernel es el **corazón de datos del SBOS**. Es un daemon binario soberano que vive permanentemente en el host Ubuntu (no en Kubernetes), se levanta con el sistema operativo, y procesa el flujo de datos entre las 110+ aplicaciones del stack.

Es al dominio de los **DATOS** lo que el SBOS IAM Installer es al dominio de la **INFRAESTRUCTURA**: el componente central que mantiene la coherencia del sistema sin que ninguna aplicación lo sepa ni lo necesite.

### Lo que hace en una línea

> El SBOS Data Kernel escucha el WAL (Write-Ahead Log) de PostgreSQL, detecta cambios en cualquier aplicación del stack, aplica reglas declarativas YAML, y produce escrituras idempotentes hacia los destinos correspondientes — sin que las aplicaciones origen ni destino sean modificadas.

### Posición en el ecosistema

```
HOST UBUNTU (systemd — fuera de K8s)
  ├── SBOS IAM Installer (systemd)   → dominio: INFRAESTRUCTURA
  ├── bkernel.service     → SBOS Data Kernel: DATOS          ← este documento
  ├── biedata.service     → SBOS Data Integration: INTEGRACIÓN EXTERIOR
  ├── bcompass.service    → SBOS AI Tools: INTELIGENCIA
  ├── bsearch.service     → SBOS Data RAG: BÚSQUEDA FEDERADA
  ├── bauth.service       → SBOS Auth Enforce: AUTENTICACIÓN E IDENTIDAD
  └── bhnexus.service     → SBOS Nexus Host: PRIVILEGIOS DE ESCRITORIO

KUBERNETES (pods)
  └── 110+ aplicaciones del stack
```

### Relación con otros documentos SBOS

| Documento | Relación |
|---|---|
| **SBOS-002** | SBOS Data Kernel es el componente central del diagrama de arquitectura general |
| **SBOS-011** | SBOS Data Integration es un daemon satélite del SBOS Data Kernel hacia el exterior |
| **SBOS-013** | SBOS Data RAG consume la cola Redis que SBOS Data Kernel produce |
| **SBOS-014** | SBOS AI Tools consume eventos del SBOS Data Kernel para orquestar workflows |
| **SBOS-022** | SBOS-022 documentará el modelo de mensajería unificado donde SBOS Data Kernel es el canal principal |

---

## 2. El SBOS Data Kernel en el Contexto de la Industria

### El problema del ecosistema empresarial moderno

Las empresas medianas de hoy operan con 10-50 aplicaciones de software. Cada una tiene su propia base de datos. Cuando un empleado cambia de cargo en RRHH, ese cambio debería propagarse automáticamente a: el ERP (cambio de accesos y centro de costo), el CRM (actualización del perfil), el sistema de identidad (cambio de rol y permisos), el sistema de nómina (cambio de banda salarial), y el sistema de soporte (cambio del responsable).

En la práctica, esto no sucede automáticamente. Los equipos de TI construyen "integraciones" ad-hoc entre pares de aplicaciones: webhooks, scripts de sincronización nocturna, exports a Excel. El resultado es un ecosistema frágil, con datos inconsistentes entre sistemas, y una carga de mantenimiento que crece con cada nueva aplicación.

### Soluciones existentes y sus limitaciones

| Categoría | Producto ejemplo | Limitación crítica |
|---|---|---|
| **CDC puro** | Debezium, Sequin | Solo captura — no tiene Rule Engine ni MDM. Requiere infraestructura adicional (Kafka, Flink). |
| **ESB / iPaaS** | MuleSoft, Boomi, n8n | Son invasivos — requieren modificar las aplicaciones para publicar eventos. SaaS = datos salen del servidor del cliente. |
| **MDM Hub** | Profisee, Semarchy | Procesamiento batch (no real-time). Requieren configuración compleja. ETL invasivo. |
| **Infraestructura de eventos** | Kafka + Flink | Requieren JVM, cluster propio, equipo especializado. Son infraestructura, no solución de negocio. |

### Por qué el SBOS Data Kernel es diferente

El SBOS Data Kernel combina en un solo daemon binario lo que el mercado solo ofrece como pila compleja de herramientas:

1. **CDC** (captura de cambios vía WAL sin extensiones PostgreSQL)
2. **MDM Hub** (Tryton como fuente de verdad + entity_crossref)
3. **Rule Engine** (forward-chaining declarativo en YAML)
4. **Event Bus implícito** (WAL de PostgreSQL es el bus)

Y lo hace con propiedades que ninguna solución comercial ofrece juntas:
- Sin GC (Rust — latencia determinista, sin pausas por Garbage Collector)
- Sin invasión a las aplicaciones (cero cambios en el código de ninguna app)
- Sin infraestructura adicional (sin Kafka, sin JVM, sin cluster)
- Soberano (corre en el servidor del cliente, no en SaaS)

---

## 3. Naturaleza del Daemon: El Corazón que no Sale del Cuerpo

El SBOS Data Kernel tiene exactamente **tres** fuentes de input válidas. No hay más:

```
INPUTS VÁLIDOS DEL BKERNEL:
  1. WAL de PostgreSQL (eventos de datos)
  2. SIGTERM              (apagado graceful)
  3. SIGHUP               (hot-reload de reglas sin reiniciar)

Todo lo demás no existe para el SBOS Data Kernel.
No tiene API REST. No tiene puerto abierto. No tiene interfaz web.
```

Esta restricción es su mayor fortaleza arquitectónica: un daemon sin superficie de ataque externa. No puede ser consultado, no puede ser comandado remotamente, no puede ser comprometido via red. Su único comportamiento es procesar el WAL y producir salidas hacia los sistemas destino configurados.

### Ciclo de vida del proceso

```
systemd start
     ↓
CONFIG LOAD: bkernel.toml + /etc/bos/blibs/bkernel/rules/**/*.yml
     ↓
STARTUP VALIDATION: conexiones a BDs, slots de replicación, plugins .so
     ↓
MAIN LOOP: WAL → Rule Engine → Writer Pool → Fanout
     ↓ (paralelo)
THREAD POOL: procesa batches de 1,000 eventos en paralelo
     ↓
CHECKPOINT: guarda LSN cada batch confirmado
     ↓ (en cualquier momento)
SIGHUP: hot-reload de reglas (sin perder eventos en vuelo)
SIGTERM: drain del buffer → checkpoint final → salida limpia
```

El SBOS Data Kernel **nunca pierde un evento**. Si el sistema se apaga inesperadamente, al reiniciar retoma desde el último LSN checkpointed. Todos los eventos intermedios son procesados.

---

## 4. Principio Fundamental: Cero Invasión

El principio de cero invasión significa que **ninguna aplicación del stack es modificada** para que el SBOS Data Kernel funcione.

No se instalan agentes. No se modifican esquemas de base de datos de las aplicaciones. No se agregan webhooks. No se inyecta código. El SBOS Data Kernel es invisible para las aplicaciones que observa.

La única configuración necesaria es la que habilita la replicación lógica de PostgreSQL — una opción de configuración del motor de base de datos, no de la aplicación:

```sql
-- En postgresql.conf:
wal_level = logical          -- habilitar decodificación lógica
max_replication_slots = 20   -- un slot por base de datos monitoreada

-- Crear el slot de replicación para cada app:
SELECT pg_create_logical_replication_slot('bkernel_orangehrm', 'pgoutput');
SELECT pg_create_logical_replication_slot('bkernel_tryton', 'pgoutput');
SELECT pg_create_logical_replication_slot('bkernel_saleor', 'pgoutput');
-- ... (un slot por BD)
```

Esto es lo único. Las aplicaciones no saben que el SBOS Data Kernel existe.

---

## 5. Las 6 Capacidades Estratégicas del SBOS Data Kernel

### Capacidad 1 — CDC Real-Time (Change Data Capture)

Captura cada INSERT, UPDATE y DELETE en cualquier tabla de cualquier aplicación del stack en tiempo real, con latencia de milisegundos desde que ocurre el cambio en la BD hasta que el SBOS Data Kernel lo procesa.

### Capacidad 2 — MDM (Master Data Management)

Mantiene Tryton como la fuente de verdad para datos maestros (empleados como `party.party`, productos, cuentas). Propaga cambios bidireccionalmente: cambios en OrangeHRM actualizan Tryton; cambios en Tryton se propagan a las apps del stack.

### Capacidad 3 — Rule Engine Declarativo

Las reglas de sincronización son archivos YAML que cualquier administrador con conocimiento del negocio puede leer y modificar. No requieren recompilar el binario. Se recargan en caliente con SIGHUP.

### Capacidad 4 — Event Bus Implícito (CQRS)

El WAL de PostgreSQL actúa como bus de eventos nativo sin infraestructura adicional. El SBOS Data Kernel implementa CQRS implícito: las escrituras de las apps son los comandos, el WAL es el log de eventos, las sincronizaciones son las proyecciones.

### Capacidad 5 — Auditoría Global

Registra en `bkernel_db.audit_events` cada cambio en el ecosistema con contexto completo: qué cambió, en qué aplicación, cuándo, con qué usuario Keycloak activo, en qué período fiscal. Esta tabla es la fuente de verdad para auditorías ISO 27001 y regulatorias.

### Capacidad 6 — Indexación Federada (hacia SBOS Data RAG y aiserver)

Produce la cola Redis que SBOS Data RAG consume para mantener el índice de búsqueda universal. También produce la cola Redis que el Embedding Worker del aiserver consume para vectorizar entidades en Qdrant.

---

## 6. Arquitectura de Conocimiento Externo

El binario del SBOS Data Kernel es **agnóstico del negocio**. No sabe nada sobre OrangeHRM, Tryton, ni ninguna aplicación específica. Todo el conocimiento específico de cada aplicación vive fuera del binario, en archivos YAML:

```
/etc/bos/blibs/bkernel/
  ├── bkernel.toml              → configuración del daemon
  ├── rules/
  │   ├── orangehrm/            → reglas para eventos de OrangeHRM
  │   │   ├── employee_sync/
  │   │   │   ├── manifest.yml
  │   │   │   ├── rule_engine.yml
  │   │   │   ├── rule_catalog.so
  │   │   │   └── resources/
  │   │   └── attendance_sync/
  │   │       ├── manifest.yml
  │   │       ├── rule_engine.yml
  │   │       ├── rule_catalog.so
  │   │       └── resources/
  │   ├── tryton/               → reglas para eventos de Tryton
  │   │   ├── invoice_sync/
  │   │   └── product_sync/
  │   ├── saleor/
  │   ├── espocrm/
  │   ├── zammad/
  │   └── cross_app/            → reglas que coordinan entre múltiples apps
  │       ├── employee_onboarding/
  │       └── customer_merge/
  └── plugins/                  → plugins .so para procesos complejos
      ├── full_employee_migration.so
      └── fiscal_year_close.so
```

El SBOS Data Kernel puede cubrir una nueva aplicación del stack sin recompilarse: basta con crear una carpeta nueva en `rules/` con los archivos YAML correspondientes y enviar SIGHUP.

---

## 7. El Framework Binario: Rust

**Lenguaje: Rust — decisión definitiva**
El GC de Go produce pausas impredecibles (0.5–5ms) inaceptables para procesamiento
de millones de eventos WAL/día. Rust garantiza latencia determinista sin GC.

### Por qué no lenguajes con GC

El SBOS Data Kernel procesa millones de eventos diarios. Necesita un lenguaje de bajo nivel que garantice:

- **Sin Garbage Collector:** pausas impredecibles del GC en un motor de eventos son inaceptables — cada pausa acumula cola de eventos y aumenta latencia de forma no determinista
- **Control de memoria:** eficiencia determinista en asignación y liberación
- **Concurrencia segura:** procesamiento paralelo sin corrupción de datos
- **Rendimiento nativo:** compilado a código máquina, sin JVM ni runtime interpretado

Lenguajes con GC (Go, Java, C#, Python) quedan descartados para el core del SBOS Data Kernel. No se trata solo de velocidad promedio, sino de latencia garantizada.

### Por qué Rust y no C++ ni ningún otro lenguaje

La decisión de lenguaje para bkernel es **definitiva: Rust**. No existe implementación alternativa en C++/Qt ni en ningún otro lenguaje. La elección se basa en la matriz de decisión de la investigación de stack del proyecto (SBOS-DAEMON-STACK v1.0):

| Criterio | Rust | Go | Por qué importa en bkernel |
|---|---|---|---|
| Modelo de memoria | Ownership + borrow checker (zero GC) | Garbage Collector concurrente | WAL CDC requiere latencia determinista sub-milisegundo |
| Latencia | Determinista, sin pausas GC | Predecible, GC de baja latencia (0.5–50ms) | Pausa de 50ms durante transacción WAL = datos inconsistentes |
| Concurrencia | async/await + tokio (zero-cost) | Goroutines (2-4 KB) + channels | Procesamiento paralelo de batches de 1,000 eventos |
| Caso ideal SBOS | **WAL CDC, parseo de streams de alta frecuencia** | WebSocket, HTTP APIs | bkernel es exactamente el caso ideal de Rust |

**C++ fue descartado** porque Rust ofrece las mismas garantías de rendimiento sin GC con seguridad de memoria garantizada en tiempo de compilación — propiedad que C++ no puede ofrecer sin disciplina manual (RAII + smart pointers) que no escala en equipos distribuidos.

**El borrow checker como ventaja operativa:** los bugs de concurrencia en CDC son los más difíciles de debuggear en producción. El compilador de Rust actúa como revisor de código permanente que rechaza en tiempo de compilación exactamente los errores más costosos del procesamiento de WAL: use-after-free, data races, null pointer dereferences.

### Proyectos de producción que validan la decisión Rust para CDC

- **Supabase/etl:** Framework CDC de Supabase en Rust para replicación en tiempo real a BigQuery e Iceberg. Usa la misma arquitectura de WAL + Rust que bkernel.
- **pgwire-replication (Deltaforge):** Crate Rust de bajo nivel para CDC usando `pgoutput` directamente sobre el wire protocol de PostgreSQL, sin libpq. Latencia determinista por diseño.
- **chgcap-rs:** Alternativa a Debezium en Rust. Motivación explícita: Debezium en Java introduce overhead de JVM y pausas GC inaceptables para CDC de alta frecuencia.
- **Artie (replication platform):** Usa Go + Redis Streams para webhooks, pero Rust para el core de replicación donde la latencia es crítica.

**Por qué no Go para bkernel:** RisingWave documentó que para un CDC custom y específico como bkernel, Rust es la opción correcta cuando se necesita control total sobre el procesamiento del WAL sin overhead de JVM ni pausas GC. Go introduce pausas GC de 0.5–50ms no deterministas — inaceptables para el SLO de < 500ms P99 del bkernel.

### Estructura del binario Rust

```rust
// /bkernel-rust/src/main.rs
mod cdc;        // CDC Engine: lectura WAL via pgoutput
mod engine;     // Rule Engine: match + transform + forward-chaining
mod writers;    // Writer Pool: UPSERT idempotente multi-destino
mod catalog;    // Task Catalog: plugins nativos y externos
mod state;      // State Manager: LSN + DLQ + entity_crossref
mod fanout;     // Fanout: Redis + MinIO + cola SBOS Data RAG + cola embedding

#[tokio::main]
async fn main() -> Result<()> {
    let config  = Config::from_file("/etc/bos/blibs/bkernel/bkernel.toml")?;
    let rules   = engine::RuleIndex::load("/etc/bos/blibs/bkernel/rules/")?;
    let writers = writers::Pool::new(&config.writers)?;
    let state   = state::Manager::open(&config.state_db)?;
    let fanout  = fanout::Engine::new(&config.fanout)?;

    let pool = rayon::ThreadPoolBuilder::new()
        .num_threads(num_cpus::get())
        .build()?;

    let mut wal = cdc::WalReader::new(&config.postgres, &state).await?;

    loop {
        let batch = wal.read_batch(1_000).await?;

        pool.install(|| {
            batch.par_iter().for_each(|event| {
                if let Some(actions) = rules.match_event(event) {
                    for action in &actions {
                        writers.execute(action);
                    }
                }
                fanout.dispatch(event);  // → Redis cache, MinIO, SBOS Data RAG queue, embed queue
            });
        });

        state.save_checkpoint(batch.last_lsn())?;
    }
}
```

---

### Proyectos de producción que validan la decisión Rust para CDC

- **Supabase/etl:** Framework CDC de Supabase en Rust para replicación en tiempo real a BigQuery e Iceberg. Usa la misma arquitectura de WAL + Rust que bkernel.
- **pgwire-replication (Deltaforge):** Crate Rust de bajo nivel para CDC usando `pgoutput` directamente sobre el wire protocol de PostgreSQL, sin libpq. Latencia determinista por diseño.
- **chgcap-rs:** Alternativa a Debezium en Rust. Motivación explícita: Debezium en Java introduce overhead de JVM y pausas GC inaceptables para CDC de alta frecuencia.
- **Artie (replication platform):** Usa Go + Redis Streams para webhooks, pero Rust para el core de replicación donde la latencia es crítica.

**Por qué no Go para bkernel:** RisingWave (plataforma de streaming) documentó explícitamente que para un CDC custom y específico como bkernel, Rust es la opción correcta cuando se necesita control total sobre el procesamiento del WAL sin overhead de JVM ni pausas GC. Go introduce pausas GC de 0.5–50ms no deterministas — inaceptables para el SLO de < 500ms P99 del bkernel.

---

## 7b. Stack Tecnológico del Daemon bkernel

| Componente | Herramienta / Crate | Propósito |
|---|---|---|
| **Lenguaje** | Rust 1.85+ (Edition 2024) | Daemon principal |
| **Runtime async** | tokio 1.x (rt-multi-thread) | Event loop para WAL streaming |
| **Cliente WAL/CDC** | pgwire-replication 0.2 | Conexión directa al wire protocol de PG |
| **Cliente PostgreSQL** | tokio-postgres 0.7 | Control plane: slots, publications |
| **Pool de conexiones** | deadpool-postgres 0.13 | Pool async para queries de escritura |
| **Redis client** | redis-rs 0.25 (tokio) | Publicación de eventos en streams |
| **Serialización** | serde 1.x + serde_json | Serialización de eventos WAL |
| **YAML rules parsing** | serde_yaml 0.9 | Lectura de rule_engine.yml |
| **Hot-reload .so** | libloading 0.8 | Carga dinámica de rule_catalog.so |
| **Config** | toml 0.8 + serde | Lectura de bkernel.toml |
| **Logging** | tracing + tracing-subscriber | Logging estructurado con spans |
| **Métricas** | prometheus-client 0.22 | Exportación de métricas al puerto 9100 |
| **Error handling** | anyhow 1.x + thiserror | Propagación de errores ergonómica |
| **Testing** | cargo test + tokio::test | Unit e integration tests async |
| **Linting** | clippy + rustfmt | Calidad de código enforced en CI |
| **Build** | cargo --release (LTO=true) | Binario optimizado para producción |
| **Cross-compile** | cross (MUSL target) | Binario estático para Ubuntu |

### Pipeline CI/CD — bkernel

| Etapa | Comando | Criterio de éxito |
|---|---|---|
| **Format** | `cargo fmt --check` | Sin diffs de formato |
| **Lint** | `cargo clippy -- -D warnings` | 0 warnings |
| **Check** | `cargo check --all-features` | Sin errores de tipo |
| **Test** | `cargo test --all-features` | 100% tests pasan |
| **Audit** | `cargo audit` | Sin CVEs críticas |
| **Build** | `cross build --release --target x86_64-unknown-linux-musl` | Binario estático generado |
| **Sign** | ed25519 firma del binario | Firma verificable por bos |

### Curva de aprendizaje y gestión del riesgo Rust

El borrow checker de Rust es el mayor obstáculo de aprendizaje. Un desarrollador experimentado en C/C++ o Go necesita 2–4 semanas de ramp-up antes de ser productivo en Rust. Sin embargo, una vez dominado, el compilador previene clases enteras de bugs (use-after-free, data races, null pointers) que en Go o Python solo se descubren en producción.

**Para bkernel este rigor es una ventaja, no una desventaja:** los bugs de concurrencia en CDC son los más difíciles de debuggear en producción. El compilador de Rust actúa como un revisor de código permanente que rechaza en tiempo de compilación exactamente los errores más costosos del procesamiento de WAL.

---


## 8. Estructura de Reglas por Aplicación

Cada aplicación del stack tiene su propia subcarpeta en `/etc/bos/blibs/bkernel/rules/`. Las reglas son archivos YAML independientes — uno por flujo de sincronización. El SBOS Data Kernel carga todos al iniciar y construye el Rule Index en memoria.

### Ciclo de vida de una regla

```
1. CREACIÓN:    Admin escribe rule.yml en /etc/bos/blibs/bkernel/rules/<app>/
2. DETECCIÓN:   SBOS Data Kernel recibe SIGHUP (hot-reload sin reiniciar)
3. VALIDACIÓN:  Se valida sintaxis YAML y coherencia de campos
4. ACTIVACIÓN:  Regla cargada en memoria (Rule Index actualizado)
5. EJECUCIÓN:   Ante eventos que cumplan condiciones
6. ACTUALIZACIÓN: Admin modifica rule.yml → nuevo SIGHUP
7. HOT-RELOAD:  Regla recargada sin perder eventos en vuelo
8. DESACTIVACIÓN: enabled: false o archivo eliminado
```

---

## 9. Formato de Reglas YAML

### Regla básica de sincronización

```yaml
# /etc/bos/blibs/bkernel/rules/orangehrm/employee_to_tryton.yml
rule:
  id:          "OHRM-001"
  name:        "employee_to_tryton_party"
  description: "Sincroniza empleados de OrangeHRM a party.party en Tryton"
  version:     "1.0.0"
  enabled:     true
  priority:    50

  when:
    source:    "orangehrm"
    table:     "hs_hr_employee"
    operation: "INSERT, UPDATE"
    condition: '.new.emp_work_email != null'

  transform:
    - map:
        name:  '"\(.new.emp_firstname) \(.new.emp_lastname)"'
        email: .new.emp_work_email
        type:  '"employee"'
    - normalize:
        field:        email
        to_lowercase: true

  then:
    - action:     "write"
      target:     "tryton"
      table:      "party.party"
      upsert_key: ["email"]
      mapping:
        name:   .name
        email:  .email
        active: true
      only_if_changed: true
    - action: "catalog"
      task:   "update_entity_crossref"
      params:
        app_a: "orangehrm"
        id_a:  .new.emp_number
        app_b: "tryton"
        id_b:  "{result.id}"
    - action:  "enqueue"
      queue:   "bkernel:index_queue"
      payload:
        entity_type: "employee"
        entity_id:   .new.emp_number
        source_app:  "orangehrm"
```

### Regla que invoca plugin externo

```yaml
# /etc/bos/blibs/bkernel/rules/cross_app/employee_to_keycloak.yml
rule:
  id: "CROSS-001"
  name: "employee_to_keycloak_user"

  when:
    source:    "orangehrm"
    table:     "hs_hr_employee"
    operation: "INSERT"
    condition: '.new.emp_work_email != null'

  then:
    - action: "plugin"
      name:   "bauth_sync"
    - action: "catalog"
      task:   "log_audit_event"
```

### Esquema de campos disponibles

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `id` | string | Sí | Identificador único, nunca se reutiliza |
| `name` | string | Sí | Nombre legible para logs |
| `version` | string | Sí | Versión semántica para auditoría |
| `enabled` | bool | Sí | `false` desactiva sin eliminar la regla |
| `priority` | int | No | Default 50. Mayor número = evaluación primero |
| `when.source` | string | Sí | Nombre de la app origen |
| `when.table` | string | Sí | Nombre de la tabla en la BD de la app |
| `when.operation` | string | Sí | INSERT / UPDATE / DELETE / ALL |
| `when.condition` | string | No | Expresión jq sobre el evento CDC |
| `transform[]` | array | No | Lista de transformaciones (map, normalize, lookup) |
| `then[].action` | string | Sí | write / notify / enqueue / catalog / plugin |
| `then[].target` | string | Para write | Destino definido en `bkernel.toml` |
| `then[].upsert_key` | array | Para write | Campos de clave de negocio |
| `only_if_changed` | bool | No | Default true. Evita escrituras innecesarias |

---

## 10. El CDC Engine — Change Data Capture

### Mecanismo primario: pgoutput con Logical Replication

PostgreSQL 10 introdujo `pgoutput` como plugin de decodificación lógica nativo — sin extensiones adicionales, sin dependencias externas. El SBOS Data Kernel usa `pgoutput` como único mecanismo de captura.

```
PostgreSQL WAL
     ↓
pgoutput plugin (nativo PostgreSQL 10+)
     ↓
Logical Replication Slot "bkernel_{app}"
     ↓
SBOS Data Kernel CDC Engine
     ↓ (decodificado como)
BkernelEvent {
  app:       "orangehrm"
  table:     "hs_hr_employee"
  operation: INSERT | UPDATE | DELETE
  old_row:   Option<HashMap<String, Value>>  // NULL en INSERT
  new_row:   Option<HashMap<String, Value>>  // NULL en DELETE
  lsn:       u64
  timestamp: i64
  origin:    Option<String>  // usado para loop prevention
}
```

### Ventajas de pgoutput sobre alternativas

| Alternativa | Limitación | pgoutput |
|---|---|---|
| Triggers en tablas | Invasivo — modifica la app | Sin invasión |
| pg_logical extension | Requiere extensión instalada | Nativo desde PG10 |
| Debezium | JVM, Kafka, cluster adicional | Sin infraestructura extra |
| Polling SQL | Alta latencia, carga en BD | Real-time, sin polling |

---

## 11. El Problema del Loop Infinito — Solución con pg_replication_origin

### El problema

El SBOS Data Kernel escucha el WAL de PostgreSQL y escribe en PostgreSQL. Sus propias escrituras generarían nuevos eventos WAL que el SBOS Data Kernel procesaría, produciendo más escrituras, en un loop infinito.

### La solución: pg_replication_origin (nativa de PostgreSQL)

`pg_replication_origin` permite marcar transacciones con un origen. El SBOS Data Kernel marca todas sus escrituras con `origin='bkernel'` y filtra eventos con ese origen al leer el WAL:

```sql
-- Al iniciar cada transacción de escritura del SBOS Data Kernel:
SELECT pg_replication_origin_session_setup('bkernel');

-- Todas las escrituras de esta sesión quedan marcadas con origin='bkernel'
INSERT INTO party_party ...;  -- marcado como origin='bkernel'

-- Al leer el WAL (en el CDC Engine):
-- El SBOS Data Kernel configura el filtro en el callback filter_by_origin_cb de pgoutput
-- Eventos con origin='bkernel' son ignorados automáticamente por el slot
```

Esta es la solución correcta y nativa de PostgreSQL — no un hack. El protocolo `pgoutput` expone el callback `filter_by_origin_cb` exactamente para este caso de uso.

### Comparativa con otras aproximaciones

| Aproximación | Problema |
|---|---|
| Campo `bkernel_synced_at` + condición en regla | Fragil — requiere que cada regla tenga la condición. Una regla sin la condición genera loop. |
| Trigger BEFORE INSERT en cada tabla | Invasivo — modifica el esquema de las apps |
| `pg_replication_origin` | Correcto — nativo, irrompible, sin condiciones en reglas |

---

## 12. El Rule Engine — Motor de Reglas Forward-Chaining

### Arquitectura del Rule Engine

El Rule Engine carga todas las reglas YAML al inicio y construye un índice invertido para matching O(1):

```
Rule Index (en memoria):
┌─────────────────────────────────────────────────────────────────┐
│ (orangehrm, hs_hr_employee, INSERT)  → [OHRM-001, CROSS-001]   │
│ (orangehrm, hs_hr_employee, UPDATE)  → [OHRM-002, CROSS-010]   │
│ (tryton, product_product, UPDATE)    → [TRY-023, TRY-024]      │
│ (saleor, order_line, INSERT)         → [SAL-089, CROSS-031]     │
└─────────────────────────────────────────────────────────────────┘

Matching: O(1) para el 95% de los casos (sin condición jq)
          O(n_conditions) para reglas con condición jq
```

### Evaluación de condiciones jq

```
Evento CDC: {
  "table": "hs_hr_employee",
  "op": "UPDATE",
  "old": {"emp_status": "active"},
  "new": {"emp_status": "terminated", "emp_number": 42}
}

Condición YAML: '.new.emp_status == "terminated" and .old.emp_status != "terminated"'
Evaluación jq:  true → regla se activa
```

### Forward-Chaining

El Rule Engine evalúa reglas en orden de prioridad. Las acciones `write` de una regla pueden generar nuevos eventos CDC que disparan otras reglas, creando flujos de datos en cascada automáticos sin que ninguna regla necesite conocer a las demás.

---

## 13. El Task Catalog — Plugins Nativos y Externos

### El problema que resuelve

El Rule Engine puede expresar la mayoría de las sincronizaciones en YAML declarativo: INSERT, UPDATE, UPSERT, transformaciones de campos, condiciones. Pero hay procesos de negocio que son fundamentalmente procedurales y demasiado complejos para YAML:

- Migrar un empleado con su historial completo de salarios, licencias y dependientes a Tryton, respetando el orden de foreign keys y ejecutando validaciones de consistencia
- Resolver un conflicto de clientes duplicados entre EspoCRM y Saleor haciendo un merge con historial de pedidos
- Ejecutar el cierre fiscal de una empresa: calcular saldos, cerrar cuentas, generar asientos de apertura

La solución es el **Task Catalog**: un sistema de dos capas.

### Capa 1 — Plugins CORE (compilados en el binario)

Tareas universales que aplican a cualquier app:

| Tarea | Descripción |
|---|---|
| `update_entity_crossref` | Registra la relación entre IDs de dos sistemas (ej: `orangehrm.42 ↔ tryton.1089`) |
| `log_audit_event` | Escribe en `bkernel_db.audit_events` con contexto completo |
| `enqueue_search` | Escribe en `bkernel:index_queue` para que SBOS Data RAG indexe la entidad |
| `enqueue_embedding` | Escribe en `ai:embed_queue` para que el Embedding Worker vectorice la entidad |
| `notify_bcompass` | Emite un evento que SBOS AI Tools puede procesar como trigger de workflow |

### Capa 2 — Plugins EXTERNOS (.so shared objects)

Para procesos de negocio específicos, el SBOS Data Kernel carga plugins compilados dinámicamente desde `/etc/bos/blibs/bkernel/plugins/`:

```
/etc/bos/blibs/bkernel/plugins/
  ├── full_employee_migration.so     # OrangeHRM → Tryton con historial completo
  ├── fiscal_year_close.so           # Cierre de ejercicio fiscal Tryton
  ├── customer_merge.so              # Merge de clientes duplicados cross-app
  ├── new_company_bootstrap.so       # Bootstrap completo de empresa nueva
  └── realm_bootstrap.so             # Creación de realm Keycloak con roles iniciales
```

El SBOS Data Kernel carga los plugins en startup con `dlopen()` y los registra en el Task Catalog interno bajo su nombre. Las reglas YAML pueden invocar cualquier plugin registrado via `action: "plugin"`.

### La Plugin API — Contrato estable

```rust
// Interfaz que todo plugin debe implementar (C ABI para compatibilidad Rust/C++)
#[repr(C)]
pub struct BkernelPlugin {
    pub name:       *const c_char,
    pub version:    *const c_char,
    pub target_app: *const c_char,
    pub execute:    extern "C" fn(ctx: *const BkernelEventContext, handles: *const BkernelHandles) -> BkernelResult,
    pub validate:   extern "C" fn(handles: *const BkernelHandles) -> BkernelResult,
}

/// Punto de entrada que el SBOS Data Kernel resuelve con dlsym()
#[no_mangle]
pub extern "C" fn bkernel_plugin_init() -> *const BkernelPlugin { ... }
```

El uso de C ABI garantiza compatibilidad binaria entre el plugin y el binario independientemente del compilador.

### Seguridad de los plugins

- **Firma criptográfica:** el SBOS IAM Installer firma cada `.so` con la clave privada de SKULL. El SBOS Data Kernel verifica la firma antes de cargar. Plugins no firmados son rechazados.
- **Validación en startup:** `plugin.validate()` se ejecuta antes de registrar. Si falla, el plugin no se carga y el SBOS Data Kernel continúa.
- **Handles de solo lectura por defecto:** `db_exec` (escritura) solo está disponible si el manifiesto declara `requires_write: true`.
- **Timeout de ejecución:** default 5 segundos. Si excede, el evento va al dead letter queue.

### Plugins distribuidos con el SBOS

| Plugin | App objetivo | Descripción |
|---|---|---|
| `full_employee_migration` | OrangeHRM | Migración con historial completo a Tryton |
| `salary_history_sync` | OrangeHRM | Histórico salarial con conversión de moneda |
| `offboarding_complete` | OrangeHRM | Cierre de todas las relaciones del empleado |
| `fiscal_year_close` | Tryton | Cierre de ejercicio con validaciones contables |
| `chart_of_accounts_init` | Tryton | Inicialización del plan de cuentas |
| `product_catalog_bulk_sync` | Saleor | Sincronización masiva de catálogo a Tryton |
| `new_company_bootstrap` | cross_app | Bootstrap completo de empresa nueva |
| `customer_merge` | cross_app | Merge de clientes duplicados con historial |
| `realm_bootstrap` | Keycloak | Realm con roles y grupos por defecto |

---

## 14. Tryton como Hub Central — Arquitectura MDM

### Por qué Tryton es el hub MDM del SBOS

Tryton es el ERP open-source más robusto del stack. Su modelo de datos es el más rico para representar entidades de negocio. Por diseño, el SBOS usa Tryton como la fuente de verdad para los datos maestros.

```
                        ┌─────────────────┐
                        │     TRYTON      │
                        │   (Hub MDM)     │
                        │  party_party    │ ← empleados, clientes, proveedores
                        │  product_product│ ← catálogo unificado
                        │  account_*      │ ← estructura contable
                        └────────┬────────┘
                                 │ (SBOS Data Kernel sincroniza en ambas direcciones)
           ┌─────────────────────┼─────────────────────┐
    ┌──────┴──────┐      ┌───────┴──────┐      ┌──────┴──────┐
    │  OrangeHRM  │      │    Saleor    │      │   EspoCRM   │
    │  (empleados)│      │  (productos, │      │  (contactos,│
    │             │      │   pedidos)   │      │   cuentas)  │
    └─────────────┘      └─────────────┘      └─────────────┘
```

### Patrón Registry Hub de MDM

El SBOS Data Kernel implementa el patrón **Registry Hub**: Tryton mantiene los datos maestros, y la tabla `entity_crossref` de `bkernel_db` registra las referencias cruzadas entre las IDs de cada app:

```
entity_crossref:
  orangehrm.employees.42  ↔  tryton.party.1089
  orangehrm.employees.42  ↔  keycloak.users.abc-123
  orangehrm.employees.42  ↔  espocrm.contacts.xyz-456
```

Cualquier componente del stack que necesite encontrar la representación de un empleado en Tryton a partir de su ID en OrangeHRM consulta `entity_crossref`. Esta es la identidad unificada cross-app del SBOS.

---

## 15. El Writer Pool — Escritura Idempotente

### UPSERT sobre clave de negocio

El SBOS Data Kernel nunca hace INSERT puro. Siempre hace `INSERT ... ON CONFLICT (business_key) DO UPDATE`:

```sql
-- Generado por el Writer Pool para la regla OHRM-001
INSERT INTO party_party (name, email, type, active, bkernel_synced_at)
VALUES ('Juan Pérez', 'juan@empresa.com', 'employee', true, NOW())
ON CONFLICT (email)
DO UPDATE SET
  name              = EXCLUDED.name,
  type              = EXCLUDED.type,
  active            = EXCLUDED.active,
  bkernel_synced_at = NOW()
WHERE party_party.name   != EXCLUDED.name
   OR party_party.type   != EXCLUDED.type
   OR party_party.active != EXCLUDED.active;
-- La cláusula WHERE implementa only_if_changed: true
-- Si los datos son idénticos, no ocurre UPDATE y no se genera evento WAL
```

### Pool de conexiones por destino

```toml
# /etc/bos/blibs/bkernel/bkernel.toml
[writers.tryton]
type = "postgres"
connection_string = "postgresql://tryton:pass@127.0.0.1:5433/tryton"
pool_size = 20
connect_timeout_secs = 5
max_retries = 3

[writers.keycloak]
type = "http"
base_url = "http://keycloak.sbos-identity.svc:8080"
auth = { type = "admin_api", realm = "master" }
pool_size = 10

[writers.redis]
url = "redis://127.0.0.1:6379"
pool_size = 30
```

### Dead Letter Queue (DLQ)

Los eventos que fallan después de `max_retries` se almacenan en la DLQ para revisión:

```sql
INSERT INTO dead_letter_queue (event_id, rule_id, error, event_data, status)
VALUES (
    'wal:0/A1B2C3:42',
    'CROSS-001',
    'Keycloak 503: Service Unavailable',
    '{"table": "hs_hr_employee", "op": "INSERT", ...}',
    'pending'
);
```

El administrador puede inspeccionar la DLQ desde Grafana y re-encolar eventos manualmente desde el Core UI.

---

## 16. Thread Pool Adaptativo y Escalado Vertical

El SBOS Data Kernel es un proceso único en el host con múltiples hilos. No escala horizontalmente — escala verticalmente usando todos los núcleos disponibles.

### Arquitectura de hilos

```
PROCESO BKERNEL (PID único)
├── Hilo 0: WAL Reader (alta prioridad, dedicado)
├── Hilo 1: Rule Matcher / Dispatcher
├── Hilo 2: Monitor / Health check / sd_notify watchdog
└── Worker Pool (N hilos, ajuste dinámico)
     ├── Worker 0 — procesa batch de eventos
     ├── Worker 1 — procesa batch de eventos
     └── Worker N — procesa batch de eventos
```

### Métricas de rendimiento esperadas

| Recurso | Capacidad |
|---|---|
| CPU (32 cores) | 32 workers en paralelo |
| Memoria RSS | < 512 MB en operación normal |
| Throughput | 500,000 – 1,000,000 eventos/segundo |
| Latencia p50 | < 2 ms (evento WAL → escritura confirmada) |
| Latencia p99 | < 10 ms |
| Latencia p999 | < 50 ms |

---

## 17. La Base de Datos Propia del SBOS Data Kernel

El SBOS Data Kernel mantiene su propio estado en `bkernel_db` — una base de datos PostgreSQL dedicada en el host. Esta BD nunca contiene datos de negocio de las aplicaciones; solo el estado operacional del SBOS Data Kernel.

### Esquema completo

```sql
-- Estado de replicación por slot
CREATE TABLE replication_state (
    slot_name       TEXT PRIMARY KEY,
    app_name        TEXT NOT NULL,
    last_lsn        TEXT NOT NULL,
    last_processed  TIMESTAMPTZ,
    events_total    BIGINT DEFAULT 0,
    lag_bytes       BIGINT DEFAULT 0,
    status          TEXT DEFAULT 'active'
);

-- Log de sincronizaciones ejecutadas
CREATE TABLE sync_log (
    id              BIGSERIAL PRIMARY KEY,
    rule_id         TEXT NOT NULL,
    source_app      TEXT NOT NULL,
    source_table    TEXT NOT NULL,
    source_lsn      TEXT NOT NULL,
    target_app      TEXT NOT NULL,
    target_table    TEXT NOT NULL,
    operation       TEXT NOT NULL,
    duration_ms     INTEGER,
    status          TEXT NOT NULL,  -- success, failed, skipped
    error           TEXT,
    executed_at     TIMESTAMPTZ DEFAULT NOW()
) PARTITION BY RANGE (executed_at);

-- Log de evaluación de reglas
CREATE TABLE rule_execution_log (
    id              BIGSERIAL PRIMARY KEY,
    rule_id         TEXT NOT NULL,
    lsn             TEXT NOT NULL,
    conditions_met  BOOLEAN,
    actions_count   INTEGER,
    duration_us     INTEGER,
    executed_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Conflictos detectados entre aplicaciones
CREATE TABLE conflict_log (
    id              BIGSERIAL PRIMARY KEY,
    entity_type     TEXT NOT NULL,
    entity_key      TEXT NOT NULL,
    app_a           TEXT NOT NULL,
    app_b           TEXT NOT NULL,
    value_a         JSONB,
    value_b         JSONB,
    resolution      TEXT,
    resolved_at     TIMESTAMPTZ,
    detected_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Auditoría global de cambios en el ecosistema
CREATE TABLE audit_events (
    id              BIGSERIAL PRIMARY KEY,
    source_app      TEXT NOT NULL,
    source_table    TEXT NOT NULL,
    source_record   TEXT,
    operation       TEXT NOT NULL,
    data_before     JSONB,
    data_after      JSONB,
    keycloak_user   TEXT,
    keycloak_realm  TEXT,
    fiscal_period   TEXT,
    lsn             TEXT,
    occurred_at     TIMESTAMPTZ NOT NULL,
    ingested_at     TIMESTAMPTZ DEFAULT NOW()
) PARTITION BY RANGE (occurred_at);

-- Anomalías detectadas por el motor de análisis
CREATE TABLE anomaly_events (
    id              BIGSERIAL PRIMARY KEY,
    pattern_id      TEXT NOT NULL,
    description     TEXT,
    severity        TEXT,  -- low, medium, high, critical
    context         JSONB,
    notified        BOOLEAN DEFAULT false,
    detected_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Dead Letter Queue
CREATE TABLE dead_letter_queue (
    id              BIGSERIAL PRIMARY KEY,
    event_id        TEXT NOT NULL,
    rule_id         TEXT,
    error           TEXT NOT NULL,
    event_data      JSONB NOT NULL,
    retry_count     INTEGER DEFAULT 0,
    status          TEXT DEFAULT 'pending',  -- pending, resolved, discarded
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Registro cruzado de identidades entre aplicaciones
CREATE TABLE entity_crossref (
    id              BIGSERIAL PRIMARY KEY,
    app_a           TEXT NOT NULL,
    id_a            TEXT NOT NULL,
    app_b           TEXT NOT NULL,
    id_b            TEXT NOT NULL,
    entity_type     TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(app_a, id_a, app_b)
);
```

---

## 18. La Relación SBOS Data Kernel ↔ SBOS Data RAG

El SBOS Data Kernel produce eventos de indexación. SBOS Data RAG los consume. Esta es la única relación entre los dos sistemas.

```
SBOS Data Kernel
  → escribe en Redis Stream "bkernel:index_queue"
     payload: {entity_type, entity_id, source_app, realm, data}

SBOS Data RAG (daemon separado)
  → consume "bkernel:index_queue"
  → construye/actualiza índice en Meilisearch
  → gestiona patrones de búsqueda
```

El SBOS Data Kernel **nunca** indexa directamente ni consulta índices de búsqueda. No tiene conocimiento del estado de SBOS Data RAG. Si SBOS Data RAG está caído, los mensajes esperan en la cola Redis hasta que SBOS Data RAG se recupere.

---

## 19. bData e bkAI — Componentes Satélite del Ecosistema

### bData

bData es un componente satélite que gestiona la ingesta de datos externos (CSV, Excel, APIs legacy) hacia las BDs de las apps del stack. Su relación con el SBOS Data Kernel es indirecta: bData escribe en las BDs de las apps con `origin='bdata'`, y el SBOS Data Kernel detecta esos cambios vía WAL normalmente y los propaga según las reglas.

El SBOS Data Kernel no interactúa con bData directamente. bData no es un componente del SBOS Data Kernel — es un daemon satélite independiente con su propia especificación (SBOS Data Integration, SBOS-011).

### bkAI

bkAI es el componente de inteligencia analítica del ecosistema del SBOS Data Kernel. Lee `bkernel_db` de forma exclusivamente de solo lectura para:
- Identificar patrones de sincronización que podrían optimizarse
- Detectar correlaciones no documentadas entre aplicaciones
- Sugerir nuevas reglas basadas en comportamientos observados

El SBOS Data Kernel **no interactúa con bkAI** directamente. bkAI lee, el SBOS Data Kernel escribe — nunca al revés. Cualquier sugerencia de bkAI pasa por revisión y aprobación humana antes de convertirse en regla activa (frontera D9).

---

## 20. Integración con el Ecosistema SBOS

| Componente | Dirección | Mecanismo | Descripción |
|---|---|---|---|
| PostgreSQL (apps) | ← (lee) | WAL logical replication | Fuente primaria de eventos |
| PostgreSQL (Tryton) | → (escribe) | Pool de conexiones | Hub MDM — destino principal |
| Keycloak | → (escribe) | Admin API REST | Sincronización de usuarios y atributos |
| Redis | → (escribe) | Redis Streams | Cola para SBOS Data RAG (`bkernel:index_queue`) y aiserver (`ai:embed_queue`) |
| MinIO | → (escribe) | Parquet files | Para Airflow pipelines y Superset análisis |
| SBOS Data RAG | → (produce cola) | Redis Stream | SBOS Data RAG consume y procesa independientemente |
| aiserver (Embedding Worker) | → (produce cola) | Redis Stream | Vectorización en Qdrant |
| SBOS AI Tools | → (emite eventos) | `notify_bcompass` task | Triggers de workflow en SBOS AI Tools |
| bData (SBOS Data Integration) | ← (detecta via WAL) | WAL | Las escrituras de SBOS Data Integration son eventos normales |
| bkAI | ← (es leído por) | Solo lectura en bkernel_db | bkAI analiza, no modifica |
| Wazuh SIEM | → (escribe) | `anomaly_events` table | Alertas de seguridad y anomalías |

---

## 21. Fronteras que el SBOS Data Kernel Nunca Cruza

| Frontera | Regla | Consecuencia de violación |
|---|---|---|
| **D1 — Solo WAL** | El SBOS Data Kernel no acepta inputs externos más allá de WAL, SIGTERM, SIGHUP | Superficie de ataque. Acoplamiento con sistemas externos. |
| **D2 — Cero modificación de apps** | No instala agentes, no modifica esquemas, no agrega triggers en las apps | Invasión de las aplicaciones |
| **D3 — Cero conocimiento en el binario** | Todo el conocimiento de negocio vive en YAML externo | El binario necesitaría recompilarse por cada regla de negocio |
| **D4 — UPSERT siempre** | Nunca INSERT puro — siempre idempotente sobre clave de negocio | Re-procesamiento de eventos genera duplicados |
| **D5 — pg_replication_origin** | Todas las escrituras marcadas con `origin='bkernel'` | Loop infinito de eventos |
| **D6 — DLQ antes que descartar** | Eventos fallidos van al DLQ — nunca se descartan silenciosamente | Pérdida de datos sin trazabilidad |
| **D7 — bkernel_db solo estado** | La BD propia del SBOS Data Kernel nunca contiene datos de negocio de las apps | Mezcla de responsabilidades |
| **D8 — SBOS Data RAG es separado** | El SBOS Data Kernel solo produce la cola Redis — no indexa directamente | Acoplamiento directo con SBOS Data RAG |
| **D9 — bkAI no modifica reglas** | Las sugerencias de bkAI requieren aprobación humana antes de activarse | Cambios autónomos en el comportamiento del sistema sin supervisión |
| **D10 — Cero ingesta directa externa** | El SBOS Data Kernel no importa datos desde CSV, Excel, APIs externas — esa responsabilidad es de SBOS Data Integration | Mezcla de responsabilidades CDC vs integración |

---

## 22. Fuentes de Verdad por Entidad de Negocio

Esta sección responde la pregunta operacional más frecuente: **¿quién posee la entidad X?**

La regla del SBOS es que cada entidad de negocio tiene un **sistema primario** (fuente de verdad) y uno o más **sistemas secundarios** (proyecciones sincronizadas por el SBOS Data Kernel con lag mínimo).

### Tabla de fuentes de verdad

| Entidad de negocio | Sistema primario (fuente de verdad) | Sistemas secundarios | Lag esperado |
|---|---|---|---|
| **Empleado (datos de RRHH)** | OrangeHRM | Tryton (party.party), Keycloak (usuario), EspoCRM (contacto) | WAL → SBOS Data Kernel → destino: < 3 seg |
| **Empleado (datos de nómina)** | Tryton | OrangeHRM (referencia), sistemas bancarios | < 3 seg |
| **Cliente** | EspoCRM (datos relacionales) | Tryton (datos financieros), Saleor (cuenta ecommerce) | < 3 seg |
| **Prospecto** | EspoCRM | — (no se proyecta hasta conversión) | N/A |
| **Proveedor** | Tryton | EspoCRM (cuenta) | < 3 seg |
| **Producto (maestro)** | Tryton | Saleor (catálogo online), otros canales | < 3 seg |
| **Producto (catálogo ecommerce)** | Saleor | — (Tryton es quien tiene el maestro) | — |
| **Pedido de venta** | Tryton | Saleor (pedido web origen) | < 3 seg |
| **Factura** | Tryton | **Única fuente — no se proyecta** | N/A |
| **Inventario** | Tryton | Saleor (stock disponible visible) | < 3 seg |
| **Ticket de soporte** | Zammad | EspoCRM (historial de interacciones) | < 3 seg |
| **Rol de acceso** | bos_bauth_template (PostgreSQL) | Keycloak (Composite Role + Auth Flow), Tryton (grupos) | < 5 seg |
| **Usuario del sistema** | UserTemplate (PostgreSQL) | Keycloak (user record), Tryton (res.user) | < 5 seg |
| **Cuenta contable** | Tryton | **Única fuente — no se proyecta** | N/A |

### Regla de oro de las fuentes de verdad

> **Si un dato tiene una única fuente marcada como "no se proyecta", ningún otro sistema debe tener una copia que el SBOS Data Kernel mantenga.** Si ese dato necesita estar en otro sistema, el otro sistema debe consultar a Tryton en tiempo real — no tener una copia local.

La Factura y la Cuenta Contable son los ejemplos más críticos: son datos financieros con implicaciones regulatorias. Nunca deben tener proyecciones que puedan estar desactualizadas.

### Lag de sincronización

El lag documentado es el tiempo bajo condiciones normales de operación:
- Evento en BD de app origen → WAL → SBOS Data Kernel: < 100 ms
- SBOS Data Kernel Rule Engine → escritura en destino: < 2 seg (p99)
- **Total extremo a extremo:** < 3 segundos en el p99

Si el lag supera 5 segundos sostenidamente, el sistema de observabilidad (monitorserver) emite una alerta. Si supera 30 segundos, es alerta crítica.

---

## 23. La Tarea enqueue_embedding en el Task Catalog

### Propósito

La tarea `enqueue_embedding` es la interfaz entre el SBOS Data Kernel y el Embedding Worker del aiserver. Cuando el SBOS Data Kernel detecta un cambio en una entidad que debe vectorizarse en Qdrant (contratos, productos, tickets, documentos de conocimiento), escribe el evento en la cola Redis `ai:embed_queue`.

### Tipos de entidades que generan enqueue_embedding

| Entidad | App origen | Condición de disparo |
|---|---|---|
| Contrato | Tryton (`contract.contract`) | INSERT o UPDATE donde `state IN ('active', 'draft')` |
| Factura | Tryton (`account.invoice`) | INSERT o UPDATE donde `state = 'posted'` |
| Producto | Tryton (`product.product`) | INSERT o UPDATE |
| Ticket de soporte | Zammad (`tickets`) | INSERT o UPDATE donde `state != 'closed'` |
| Artículo de conocimiento | Zammad (`knowledge_base_answers`) | INSERT o UPDATE donde `published = true` |
| Contacto | EspoCRM (`contacts`) | INSERT o UPDATE |
| Descripción de cargo | OrangeHRM (`hs_hr_job_title`) | INSERT o UPDATE |

### Contrato del payload del evento

```yaml
# Esquema completo del mensaje que SBOS Data Kernel escribe en ai:embed_queue
# Redis Stream XADD ai:embed_queue * ...

payload:
  schema_version: "1.0"          # versión del contrato — permite evolución sin romper consumidores

  # Identificación de la entidad
  entity_type:  string            # "contract" | "invoice" | "product" | "ticket" | "knowledge" | "contact"
  entity_id:    string            # ID primaria de la entidad en el sistema de origen
  source_app:   string            # "tryton" | "zammad" | "espocrm" | "orangehrm"

  # Aislamiento multi-tenant — siempre del evento, nunca hardcoded
  realm:        string            # realm de Keycloak del contexto de la sesión que originó el cambio

  # Datos de la entidad para vectorización
  data:         object            # el registro completo de la fila tal como vino del WAL
                                  # el Embedding Worker usa mapping.yml para extraer el texto a vectorizar

  # Metadata de trazabilidad
  event_lsn:    string            # LSN del evento WAL de origen
  event_ts:     int               # Unix timestamp del evento en la BD de origen
  bkernel_ts:   int               # Unix timestamp de cuando el SBOS Data Kernel procesó el evento

  # Control de procesamiento
  priority:     int               # default: 5. Rango: 1-10. Mayor = mayor prioridad en la cola
  ttl_seconds:  int               # default: 3600. Si el Embedding Worker no lo procesa en TTL, se descarta con log
```

### Ejemplo de regla que usa enqueue_embedding

```yaml
# /etc/bos/blibs/bkernel/rules/tryton/contract_embed.yml
rule:
  id:      "TRYTON-EMBED-001"
  name:    "vectorize_tryton_contracts"
  version: "1.0.0"
  enabled: true

  when:
    source:    "tryton"
    table:     "contract.contract"
    operation: "INSERT, UPDATE"
    condition: '.new.state == "active" or .new.state == "draft"'

  then:
    - action: "catalog"
      task:   "enqueue_search"         # indexar en Meilisearch para búsqueda textual
      params:
        queue:       "bkernel:index_queue"
        entity_type: "contract"
        entity_id:   .new.id
        source_app:  "tryton"
        realm:       "{session.realm}"

    - action: "catalog"
      task:   "enqueue_embedding"      # vectorizar en Qdrant para búsqueda semántica
      params:
        queue:        "ai:embed_queue"
        entity_type:  "contract"
        entity_id:    .new.id
        source_app:   "tryton"
        realm:        "{session.realm}"
        data:         "{row}"
        priority:     5
```

### Relación con el Embedding Worker del aiserver

El Embedding Worker (documentado en SBOS-015) consume `ai:embed_queue` y:
1. Lee el `mapping.yml` de la colección Qdrant correspondiente al `entity_type`
2. Construye el texto que se va a vectorizar usando el template del mapping
3. Llama al modelo de embedding configurado (multilingual-e5-base para Perfil A, qwen3-embedding para Perfil B+)
4. Hace upsert del vector en Qdrant en la colección `realm_{realm_id}_{entity_type}s`
5. Confirma el procesamiento del mensaje en el Redis Stream

Si el Embedding Worker está caído, los mensajes esperan en la cola Redis. El SBOS Data Kernel no sabe ni necesita saber el estado del Embedding Worker.

---

## 24. Decisión de Implementación: Rust — Fundamento Técnico

La decisión de implementar bkernel en Rust es definitiva. No existe ni existirá una versión paralela en C++/Qt. Esta sección documenta el fundamento técnico de esa decisión para que quede registrado en el proyecto.

### Por qué Rust y no C++

C++ fue la alternativa considerada — ambos eliminan el GC y compilan a código máquina. La ventaja decisiva de Rust es que sus garantías de seguridad de memoria son **estructurales, no disciplinarias**:

| Aspecto | Rust | C++ |
|---|---|---|
| Seguridad de memoria | Garantizada en compilación (borrow checker) | Manual — depende de disciplina del equipo |
| Data races | Imposibles en código safe | Posibles — requieren revisión manual |
| Use-after-free | Error de compilación | Bug de producción |
| Throughput pico | +5-10% sobre C++ (LTO + MUSL) | Base |
| Latencia p999 | Sin GC spikes | Sin GC spikes |
| Toolchain | Cargo unificado (build, test, lint, audit) | CMake + vcpkg + múltiples herramientas |
| Binario estático | `cross --target x86_64-unknown-linux-musl` | Posible pero más complejo con Qt |

En un daemon de CDC de alta frecuencia — donde un bug de concurrencia puede corrompir el estado de datos de 110+ aplicaciones — la garantía estructural de Rust supera cualquier ventaja de velocidad de desarrollo inicial que pudiera ofrecer C++.

### Gestión del riesgo: borrow checker

El borrow checker es el mayor obstáculo de aprendizaje de Rust. Un desarrollador con experiencia en C/C++ o Go necesita 2–4 semanas de ramp-up antes de ser productivo. Sin embargo, para bkernel este rigor es una ventaja: el compilador previene en build-time exactamente los errores más costosos del procesamiento de WAL.

**Mitigación:** tipos wrapper para LSN (Log Sequence Number), tests exhaustivos de replay con `tokio::test`, y documentación interna de patrones de ownership para el CDC Engine.

---


## 25. Posicionamiento Competitivo

| Producto / Categoría | CDC | MDM Hub | Rule Engine | Sin GC | Soberano | Cero Invasión |
|---|---|---|---|---|---|---|
| **SBOS Data Kernel (SBOS)** | ✅ | ✅ | ✅ | ✅ Rust | ✅ | ✅ |
| Debezium | ✅ CDC only | ❌ | ❌ | ❌ JVM | ✅ | ✅ |
| Sequin | ✅ CDC only | ❌ | ❌ | ❌ Elixir | ✅ | ✅ |
| MuleSoft / Boomi | ❌ invasivo | Parcial | ✅ | ❌ JVM | ❌ SaaS | ❌ |
| Profisee / Semarchy | ❌ ETL batch | ✅ | Parcial | ❌ .NET/Java | ❌ SaaS | ❌ ETL |
| Apache Kafka + Flink | ✅ infraestructura | ❌ | ❌ | ❌ JVM | ✅ | ✅ requiere código |

**La diferencia definitiva:** El SBOS Data Kernel es el único que combina CDC + MDM + Rule Engine en un daemon sin GC, sin infraestructura adicional, sin invasión a las apps, y diseñado para correr en el servidor del cliente sin licencias.

---

## 26. Hoja de Ruta de Desarrollo

### Fase 1 — Fundación CDC (Meses 1-3)

- Implementación Rust: CDC Engine + Rule Engine básico + Writer Pool
- CDC Engine conectado a las 5 apps centrales: OrangeHRM, Tryton, Saleor, EspoCRM, Zammad
- Writer Pool con idempotencia UPSERT
- Loop prevention definitivo con `pg_replication_origin`
- BD propia del SBOS Data Kernel (`bkernel_db`) con `replication_state` y `sync_log`
- 10 reglas básicas de ejemplo (employee sync, contact sync)
- Estructura `rules/` por aplicación establecida

### Fase 2 — Rule Engine Completo (Meses 4-6)

- Rule Engine con hot-reload SIGHUP
- Rule Index O(1) para matching eficiente
- Forward-chaining para flujos multi-regla
- Dead Letter Queue con reintentos configurables
- Task Catalog con rutinas básicas (`update_entity_crossref`, `log_audit_event`, `enqueue_search`, `enqueue_embedding`)
- 50 reglas cubriendo los flujos principales del stack
- Cola de indexación `bkernel:index_queue` hacia SBOS Data RAG operativa
- Cola `ai:embed_queue` hacia Embedding Worker operativa

### Fase 3 — Auditoría, Anomalías y bkAI v1 (Meses 7-9)

- `audit_events` completo con contexto Keycloak (realm, usuario, gestión fiscal)
- Motor de anomalías integrado con Wazuh
- `entity_crossref` completo — identidad unificada cross-app
- Fanout hacia MinIO (Parquet) para Airflow y Superset
- bkAI v1: primeras sugerencias de optimización de reglas basadas en `sync_log` y `rule_execution_log`

### Fase 4 — Producción y Cobertura Total (Meses 10-12)

- Hardening de producción y cobertura completa: 110+ apps del stack
- Dashboard operativo en Grafana
- bkAI v2: detección de correlaciones no documentadas entre aplicaciones
- Tabla de fuentes de verdad por entidad completada para todas las apps del stack
- Documentación final y auditoría de seguridad

---

## 27. Registro de Cambios v8.0

### Alineación con SBOS-DAEMON-STACK v1.0 en v8.0

**C1 — Eliminación de la implementación dual Rust/C++/Qt (§7, §24, §26):**
La investigación de stack tecnológico (SBOS-DAEMON-STACK v1.0, Marzo 2026) establece definitivamente que bkernel se implementa en **Rust únicamente**. Se elimina toda referencia a C++/Qt como alternativa de implementación. La sección §7 reemplaza la "tabla dual" por la matriz de decisión Rust vs lenguajes con GC. La sección §24 reemplaza "Estrategia de Implementación Dual" por "Decisión de Implementación: Rust — Fundamento Técnico". La Hoja de Ruta (§26) elimina la línea "implementación dual en paralelo" y la "decisión en mes 6".

**C2 — Stack tecnológico completo alineado (§7b):**
El stack de crates de Rust documenta versiones específicas: Rust 1.85+ (Edition 2024), tokio 1.x, pgwire-replication 0.2, tokio-postgres 0.7, deadpool-postgres 0.13, redis-rs 0.25, serde 1.x, serde_yaml 0.9, libloading 0.8, anyhow 1.x, thiserror, prometheus-client 0.22. Alineado con la tabla maestra del documento de stack.

**C3 — Justificación técnica enriquecida con evidencia de producción:**
Se añaden referencias a proyectos de producción que validan Rust para CDC: Supabase/etl, pgwire-replication (Deltaforge), chgcap-rs, Artie. Se documenta explícitamente por qué Go no es candidato para bkernel (pausas GC 0.5–50ms vs SLO < 500ms P99).

**Correcciones heredadas de v7.0 preservadas íntegramente.**

---

*SKULL · SBOS · SBOS-010 — SBOS Data Kernel · v8.0 · Marzo 2026 — Integración DLQ, reglas y WAL replay*

> **Referencias técnicas:** PostgreSQL Documentation — Logical Replication (Chapter 29) · PostgreSQL Documentation — Replication Progress Tracking (`pg_replication_origin`, Chapter 50) · tokio-postgres crate (Rust) · SBOS-DAEMON-STACK v1.0 (Skull Technologies, Marzo 2026) · Supabase/etl — GitHub · pgwire-replication (Deltaforge) · chgcap-rs · Drools Documentation — The Rule Engine, Forward Chaining · Gartner — MDM Registry Hub pattern

---

## 29. Catálogo de Reglas, DLQ y Protocolo con Apps

> **Integrado desde SBOS-010-001 en v8.0.**

### 1.1 Reglas Core (cross-app)

| ID | Nombre | Source → Target | Evento | Prioridad |
|----|--------|-----------------|--------|-----------|
| CORE-001 | employee_onboarding | OrangeHRM → Tryton + Keycloak | INSERT en hs_hr_employee | 10 |
| CORE-002 | employee_offboarding | OrangeHRM → Tryton + Keycloak | UPDATE emp_status='terminated' | 10 |
| CORE-003 | customer_merge | Tryton → EspoCRM + Saleor | UPDATE en party.party con merge_target | 20 |
| CORE-004 | product_price_sync | Tryton → Saleor | UPDATE en product.product.list_price | 30 |
| CORE-005 | invoice_to_accounting | Saleor → Tryton | INSERT en order_order con status='confirmed' | 20 |
| CORE-006 | payment_reconciliation | Tryton → Tryton (cross-module) | INSERT en account.payment con state='succeeded' | 15 |
| CORE-007 | inventory_alert | Tryton → Redis (bcompass queue) | UPDATE stock.move cuando quantity < reorder_point | 40 |

### 1.2 Reglas OrangeHRM

| ID | Nombre | Evento | Acción |
|----|--------|--------|--------|
| OHRM-001 | employee_to_tryton_party | INSERT/UPDATE en hs_hr_employee | UPSERT en party.party |
| OHRM-002 | leave_to_tryton_attendance | INSERT en hs_hr_leave | INSERT en attendance.line |
| OHRM-003 | department_sync | INSERT/UPDATE en ohrm_subunit | UPSERT en company.department |

### 1.3 Reglas Saleor

| ID | Nombre | Evento | Acción |
|----|--------|--------|--------|
| SALE-001 | order_to_tryton_sale | INSERT en order_order status='confirmed' | INSERT en sale.sale |
| SALE-002 | product_stock_update | UPDATE en warehouse_stock | UPDATE en stock.move |
| SALE-003 | customer_to_tryton | INSERT en account_user | UPSERT en party.party |
| SALE-004 | refund_to_tryton | INSERT en order_fulfillmentreturn | INSERT en sale.return |

### 1.4 Reglas EspoCRM

| ID | Nombre | Evento | Acción |
|----|--------|--------|--------|
| ESPO-001 | contact_to_tryton | INSERT/UPDATE en contact | UPSERT en party.party |
| ESPO-002 | opportunity_to_tryton | UPDATE opportunity status='Won' | INSERT en sale.opportunity |

### 1.5 Reglas Zammad

| ID | Nombre | Evento | Acción |
|----|--------|--------|--------|
| ZMMD-001 | ticket_to_espocrm | INSERT en tickets | INSERT en EspoCRM case |
| ZMMD-002 | ticket_close_to_tryton | UPDATE ticket status='closed' | UPDATE service.contract |

### 1.6 Formato Completo de una Regla (todos los campos)

```yaml
rule:
  id: "OHRM-001"
  name: "employee_to_tryton_party"
  description: "Sincroniza empleados de OrangeHRM a party.party en Tryton"
  version: "1.0.0"
  enabled: true
  priority: 50                      # menor = mayor prioridad

  when:
    source: "orangehrm"             # app origen (nombre de la BD)
    table: "hs_hr_employee"         # tabla que dispara la regla
    operation: "INSERT, UPDATE"     # INSERT | UPDATE | DELETE | ALL
    condition: '.new.emp_work_email != null'  # jq expression sobre el evento

  transform:
    - map:                          # mapeo de campos
        name: '"\(.new.emp_firstname) \(.new.emp_lastname)"'
        email: .new.emp_work_email
        type: '"employee"'
        vat_code: .new.emp_tax_id
    - normalize:                    # normalización
        field: email
        to_lowercase: true
    - lookup:                       # lookup en otra tabla
        field: department_id
        source: "orangehrm"
        table: "ohrm_subunit"
        key: "id"
        value: "name"
    - validate:                     # validación pre-escritura
        field: email
        regex: '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        on_fail: "skip"             # skip | dlq | abort

  then:
    - action: "write"
      target: "tryton"
      table: "party.party"
      upsert_key: ["email"]
      idempotency: true             # UPSERT en vez de INSERT
    - action: "notify"
      target: "redis"
      channel: "bkernel:events"
      payload: '{"type":"employee_synced","id":.new.emp_number}'
    - action: "enqueue"
      target: "bsearch"
      index: "employees"
      document_id: .new.emp_number

  error_handling:
    max_retries: 3
    retry_delay_ms: [1000, 5000, 15000]   # exponential backoff
    on_max_retries: "dlq"                  # dlq | skip | abort
    dlq_topic: "bkernel:dlq:ohrm-001"

  metadata:
    author: "SKULL Team"
    created_at: "2026-03-14"
    tags: ["hr", "employee", "tryton"]
```

---

## 2. Dead Letter Queue (DLQ)

### 2.1 Arquitectura

```
Evento WAL
  │
  ├── Rule Engine match → acción
  │     │
  │     ├── Writer ejecuta → OK → checkpoint LSN
  │     │
  │     └── Writer falla → Retry Manager
  │           │
  │           ├── Retry 1 (1s delay) → OK → checkpoint
  │           ├── Retry 2 (5s delay) → OK → checkpoint
  │           ├── Retry 3 (15s delay) → FAIL
  │           │
  │           └── DLQ → bkernel_dlq (tabla PostgreSQL)
  │                 │
  │                 ├── Alerta a admin (Redis → WebSocket → Core UI)
  │                 └── Evento queda en DLQ hasta resolución manual
  │
  └── Evento sin reglas → descartado (log debug, no DLQ)
```

### 2.2 Tabla DLQ en PostgreSQL

```sql
CREATE TABLE bkernel_dlq (
    id              BIGSERIAL PRIMARY KEY,
    event_id        UUID NOT NULL,
    rule_id         VARCHAR(50) NOT NULL,
    source_table    VARCHAR(200) NOT NULL,
    operation       VARCHAR(10) NOT NULL,
    event_data      JSONB NOT NULL,
    error_message   TEXT NOT NULL,
    error_code      VARCHAR(50),
    retry_count     INT DEFAULT 0,
    max_retries     INT DEFAULT 3,
    first_failure   TIMESTAMPTZ DEFAULT NOW(),
    last_retry      TIMESTAMPTZ,
    status          VARCHAR(20) DEFAULT 'pending',  -- pending | retrying | resolved | discarded
    resolved_at     TIMESTAMPTZ,
    resolved_by     VARCHAR(100),
    resolution_note TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_dlq_status ON bkernel_dlq(status);
CREATE INDEX idx_dlq_rule ON bkernel_dlq(rule_id);
```

### 2.3 Comandos de gestión DLQ

```bash
bosctl bkernel dlq list                    # listar eventos en DLQ
bosctl bkernel dlq list --rule=OHRM-001    # filtrar por regla
bosctl bkernel dlq retry <event_id>        # reintentar un evento
bosctl bkernel dlq retry-all --rule=OHRM-001  # reintentar todos de una regla
bosctl bkernel dlq discard <event_id>      # descartar (marcar como resuelto)
bosctl bkernel dlq stats                   # estadísticas de DLQ
```

---

## 3. Protocolo bkernel ↔ Tryton

### 3.1 Mecanismo de escritura

El bkernel escribe en Tryton mediante **SQL directo** usando el Writer Pool con conexiones de pool dedicadas. No usa la API XML-RPC de Tryton porque:

1. XML-RPC añade latencia de serialización/deserialización
2. XML-RPC no permite UPSERT nativo
3. El bkernel necesita control transaccional completo (BEGIN/COMMIT/ROLLBACK)

```rust
// Writer Pool para Tryton
impl TrytonWriter {
    async fn upsert(&self, table: &str, data: &Value, upsert_key: &[String]) -> Result<()> {
        let conn = self.pool.get().await?;
        
        // UPSERT idempotente usando ON CONFLICT
        let sql = format!(
            "INSERT INTO {} ({}) VALUES ({}) ON CONFLICT ({}) DO UPDATE SET {}",
            table,
            columns.join(", "),
            placeholders.join(", "),
            upsert_key.join(", "),
            update_set.join(", ")
        );
        
        // pg_replication_origin para evitar loop infinito
        conn.execute("SELECT pg_replication_origin_session_setup('bkernel')", &[]).await?;
        conn.execute(&sql, &params).await?;
        conn.execute("SELECT pg_replication_origin_session_reset()", &[]).await?;
        
        Ok(())
    }
}
```

### 3.2 Prevención del loop infinito

Cuando bkernel escribe en Tryton, esa escritura genera un nuevo evento WAL. Sin protección, el bkernel lo detectaría como un cambio nuevo y ejecutaría reglas sobre él — loop infinito.

**Solución:** `pg_replication_origin` (nativo de PostgreSQL 10+)

```
1. bkernel registra un origen de replicación: 'bkernel'
2. Antes de escribir: pg_replication_origin_session_setup('bkernel')
3. Escribe en Tryton
4. Después de escribir: pg_replication_origin_session_reset()
5. Al leer WAL: filtra eventos con origin = 'bkernel'
6. Resultado: bkernel ignora sus propias escrituras
```

### 3.3 Manejo de Tryton caído

```
bkernel detecta timeout en Writer Pool (> 5s)
  │
  ├── Marcar Writer Pool de Tryton como "degraded"
  ├── Eventos destinados a Tryton van a retry queue (Redis)
  ├── Health check cada 10s: intenta reconectar
  │
  ├── Tryton vuelve:
  │     ├── Marcar Writer Pool como "healthy"
  │     ├── Drenar retry queue en orden
  │     └── Log: "Tryton recovered, N events replayed"
  │
  └── Tryton no vuelve en 5 min:
        ├── Eventos de retry queue → DLQ
        ├── Alerta crítica al admin
        └── bkernel sigue procesando reglas de otras apps
```

---

## 4. Redis como Bus de Eventos

### 4.1 Canales Redis

```
bkernel:events                  → Todos los eventos procesados (para monitoreo)
bkernel:events:<app>            → Eventos por aplicación (para suscriptores específicos)
bkernel:dlq:<rule_id>           → Notificaciones de DLQ
bkernel:health                  → Heartbeat del bkernel (cada 10s)
bkernel:metrics                 → Métricas agregadas cada minuto
bsearch:index_queue             → Cola para reindexación de bSearch
bcompass:analysis_queue          → Cola para análisis de bCompass
```

### 4.2 Formato de evento en Redis

```json
{
  "event_id": "uuid",
  "source": "orangehrm",
  "table": "hs_hr_employee",
  "operation": "INSERT",
  "lsn": "0/1A2B3C4D",
  "timestamp": "2026-03-14T10:30:00Z",
  "data": {
    "old": null,
    "new": { "emp_number": 123, "emp_firstname": "María", "emp_lastname": "García" }
  },
  "rules_matched": ["OHRM-001"],
  "actions_executed": [
    { "rule": "OHRM-001", "target": "tryton", "result": "ok", "duration_ms": 12 }
  ]
}
```

---

## 5. Integración con SBOS-010-WAL-ReplayStrategy

La estrategia de replay WAL documentada en SBOS-010-WAL se integra con el DLQ:

```
Escenario: bkernel se reinicia después de un crash
  │
  ├── Lee último LSN del checkpoint en bkernel_state
  ├── Conecta al replication slot (que retuvo los WAL no confirmados)
  ├── Re-procesa desde el último LSN confirmado
  │
  ├── Idempotencia: todas las escrituras usan UPSERT (ON CONFLICT)
  │   → reprocesar el mismo evento produce el mismo resultado
  │
  └── DLQ: eventos que fallaron antes del crash siguen en la tabla DLQ
        → el admin puede reintentarlos con bosctl bkernel dlq retry-all
```

---

## 6. Métricas Prometheus del bkernel

```
# Contadores
bkernel_events_received_total{source="orangehrm"}
bkernel_events_processed_total{source="orangehrm", rule="OHRM-001"}
bkernel_events_failed_total{source="orangehrm", rule="OHRM-001"}
bkernel_dlq_events_total{rule="OHRM-001"}
bkernel_writes_total{target="tryton"}

# Histogramas
bkernel_event_processing_duration_seconds{rule="OHRM-001"}
bkernel_write_duration_seconds{target="tryton"}

# Gauges
bkernel_replication_lag_bytes
bkernel_dlq_pending_count
bkernel_writer_pool_active{target="tryton"}
bkernel_rules_loaded_count
```

---

## 7. Registro de Cambios

### v1.0 — Marzo 2026

Documento nuevo. Catálogo de 16 reglas por aplicación con formato completo, arquitectura DLQ con tabla PostgreSQL y comandos de gestión, protocolo bkernel↔Tryton con prevención de loop infinito via pg_replication_origin, Redis como bus de eventos con formato de mensajes, integración con replay WAL, y métricas Prometheus.

---

*SKULL · SBOS · SBOS-010-001 · Anexo 001 · v1.0 · Marzo 2026*

---

## 30. Replay WAL, Idempotencia y Recovery

> **Integrado desde SBOS-010-WAL en v8.0.**

**Versión:** 1.0
**Estado:** ACTIVO
**Clasificación:** Especificación Técnica — Garantías de Delivery del bKernel
**Complementa:** SBOS-010-BKERNEL-v7_0.md (insertar como §28 — Estrategia de Replay WAL)
**Insertar en:** SBOS-010 como nueva sección §28

---

## §18 — Estrategia de Replay WAL, Idempotencia y Recovery del bKernel

### 18.1 Modelo de delivery: at-least-once con idempotencia garantizada

El bKernel opera bajo el modelo **at-least-once delivery**:

- **At-least-once:** ante un crash del bKernel entre el procesamiento de un batch y el checkpoint del LSN, ese batch puede procesarse dos veces al reiniciar. El sistema garantiza que no se pierden eventos, a costa de la posibilidad de procesar el mismo evento más de una vez.

- **Idempotencia garantizada:** el Writer Pool verifica la tabla `bkernel_db.processed_events` antes de cada escritura. Si el `event_id` ya existe en la tabla, la escritura se omite silenciosamente. Esto convierte el modelo at-least-once en exactly-once desde la perspectiva del estado resultante.

```
GARANTÍA FORMAL:
  Para todo evento E con event_id único:
  COUNT(E en destino) = 1
  — independientemente de cuántas veces el bKernel lo haya procesado
```

### 18.2 Mecanismo de checkpoint del LSN

El bKernel persiste el último LSN procesado en `bkernel_db.checkpoint` después de cada batch confirmado:

```sql
-- Esquema de la tabla de checkpoint
CREATE TABLE bkernel_db.checkpoint (
    id          SERIAL PRIMARY KEY,
    lsn         pg_lsn NOT NULL,           -- "0/1A2B3C4D" — posición en el WAL
    updated_at  TIMESTAMPTZ DEFAULT NOW(),
    batch_size  INTEGER,                   -- Cuántos eventos tenía el último batch
    hostname    TEXT                       -- Host donde corre el bKernel
);
```

**Ciclo de vida del LSN:**

```
INICIO bKernel:
  1. Leer el LSN de bkernel_db.checkpoint (SELECT lsn ORDER BY updated_at DESC LIMIT 1)
  2. Si no hay registro: arrancar desde LSN actual del slot (nuevo deployment)
  3. Si hay registro: arrancar desde ese LSN (recovery de crash o reinicio normal)

PROCESAMIENTO (ciclo normal):
  1. Leer el WAL desde el LSN checkpointado
  2. Procesar batch de hasta 1000 eventos
  3. Aplicar Rule Engine
  4. Ejecutar Writer Pool (con verificación de idempotencia)
  5. CHECKPOINT: UPDATE bkernel_db.checkpoint SET lsn = $nuevo_lsn

DETENCIÓN (SIGTERM limpio):
  1. Terminar el batch en vuelo
  2. CHECKPOINT del LSN final
  3. Cerrar la conexión al slot de replicación
  4. Salir con código 0
```

**Garantía:** si el bKernel sufre un crash entre el paso 4 (Writer Pool) y el paso 5 (CHECKPOINT), el batch se reprocesará al reiniciar. La idempotencia del Writer Pool garantiza que no habrá escrituras duplicadas.

### 18.3 Escenario A — Reinicio normal o crash (recovery automático)

Este escenario es el más frecuente: el bKernel se detiene (reboot del host, actualización, crash) y systemd lo reinicia.

**Proceso automático — sin intervención manual:**

```
1. systemd detecta que bkernel.service está caído
2. systemd espera RestartSec=5s (configurable)
3. systemd reinicia el proceso /usr/local/bin/bkernel
4. bKernel lee el LSN de bkernel_db.checkpoint
5. bKernel se reconecta al slot de replicación desde ese LSN
6. bKernel procesa los eventos pendientes (los que ocurrieron mientras estaba caído)
7. El lag WAL baja gradualmente hasta < 500ms
```

**Verificación:**

```bash
# Verificar que el bKernel está activo y procesando
systemctl status bkernel

# Verificar el lag WAL en tiempo real
journalctl -u bkernel -f | grep "wal_lag"

# En Grafana: métrica bkernel_wal_lag_seconds debe bajar a < 500ms en ~2 minutos
# Si no baja después de 5 minutos: ejecutar RK-003 (SBOS-024)
```

**Tiempo esperado de recuperación:** < 5 minutos para lag < 500ms.
**Pérdida de datos:** cero. El slot de replicación retiene el WAL mientras el bKernel está caído.

### 18.4 Escenario B — Reconstrucción de un bounded context desde un LSN específico

**Caso de uso:** la tabla de proyección de un bounded context se corrompió (bug en el Rule Engine, intervención manual incorrecta) y necesita reconstruirse desde el historial de eventos.

**Herramienta:** `pg_recvlogical`

```bash
# Paso 1: Identificar el LSN de inicio para el replay
# (el punto en el WAL justo antes de la corrupción)
sudo -u postgres psql -d bkernel_db \
  -c "SELECT lsn, updated_at FROM checkpoint ORDER BY updated_at DESC LIMIT 20;"

# Paso 2: Detener el bKernel para el replay manual
sudo systemctl stop bkernel

# Paso 3: Limpiar la tabla de proyección corrupta
sudo -u postgres psql -d bkernel_db \
  -c "TRUNCATE TABLE bkview_invoices_summary;"
# También limpiar processed_events para ese bounded context:
sudo -u postgres psql -d bkernel_db \
  -c "DELETE FROM processed_events WHERE source_app = 'tryton';"

# Paso 4: Replay manual desde el LSN específico
# --startpos: LSN desde donde empezar el replay
# --slot: el slot de replicación del bounded context a reconstruir
# --plugin: pgoutput

pg_recvlogical \
  --dbname=tryton_db \
  --slot=bkernel_tryton \
  --startpos=0/1A2B3C4D \
  --no-loop \
  --file=/tmp/wal_replay_tryton.json \
  --plugin=pgoutput

# Paso 5: Reiniciar el bKernel para procesar el replay
sudo systemctl start bkernel

# El bKernel procesará el archivo de replay y reconstruirá la proyección
# Verificar en Grafana que el lag baja a < 500ms
```

**Tiempo estimado:** 15-60 minutos dependiendo del volumen de eventos a rehacer.
**Pérdida de datos:** cero si el WAL del período a reconstruir está disponible en el slot.

### 18.5 Escenario C — Slot de replicación invalidado

**Causa:** el parámetro `max_slot_wal_keep_size` de PostgreSQL limita cuánto WAL puede retener un slot. Si el bKernel está detenido durante un tiempo prolongado y el WAL acumulado supera ese límite, PostgreSQL invalida el slot automáticamente para proteger el disco.

**Síntoma:** el bKernel arranca pero no puede conectarse al slot de replicación. El log muestra:
```
ERROR: replication slot "bkernel_tryton" does not exist
```

**Procedimiento de recuperación:**

```bash
# Paso 1: Confirmar que el slot está invalidado o eliminado
sudo -u postgres psql -c \
  "SELECT slot_name, active, invalidation_reason FROM pg_replication_slots;"
# invalidation_reason = "wal_removed" confirma el problema

# Paso 2: Detener el bKernel
sudo systemctl stop bkernel

# ⚠️ ADVERTENCIA: El WAL anterior al momento de invalidación ya fue eliminado.
# NO es posible recuperar los eventos perdidos desde el slot.
# La reconstrucción requiere restaurar desde backup.

# Paso 3: Evaluar el gap de eventos
# Tiempo de bKernel caído = tiempo_parada - tiempo_actual
# Si el gap es aceptable (< RPO del SLA): recrear slot y continuar
# Si el gap NO es aceptable: restaurar desde backup (RK-012 de SBOS-026)

# Paso 4 (si gap aceptable): Recrear el slot
sudo -u postgres psql -c \
  "SELECT pg_create_logical_replication_slot('bkernel_tryton', 'pgoutput');"
# Repetir para cada slot invalidado

# Paso 5: Actualizar el LSN en bkernel_db.checkpoint al LSN actual
sudo -u postgres psql -d bkernel_db -c \
  "UPDATE checkpoint SET lsn = pg_current_wal_lsn(), updated_at = NOW();"

# Paso 6: Reiniciar el bKernel
sudo systemctl start bkernel
```

**Prevención:** la alerta `WALSlotReplicationLag` de SBOS-026 §7 dispara cuando el slot acumula > 1GB sin consumir, antes de que `max_slot_wal_keep_size` lo invalide.

### 18.6 Tabla de garantías por escenario

| Escenario | Recovery automático | Pérdida de datos | Intervención manual | Tiempo estimado |
|-----------|-------------------|-----------------|--------------------|----|
| **A: Crash/reinicio** | ✅ Sí — systemd reinicia | ❌ Ninguna | No requerida | < 5 min para lag < 500ms |
| **B: Reconstrucción de BC** | ❌ No — proceso deliberado | ❌ Ninguna (si WAL disponible) | Sí — 4 pasos | 15-60 min |
| **C: Slot invalidado (gap aceptable)** | ❌ No | ✅ Sí — eventos durante el gap | Sí — 5 pasos | 15-30 min |
| **C: Slot invalidado (gap no aceptable)** | ❌ No | Depende del RPO | Sí — restore completo (RK-012) | 30-90 min |

---

*SKULL · SBOS · SBOS-010-WAL · v1.0 · Marzo 2026*
*Insertar como §18 en SBOS-010-BKERNEL*
*Complementa: SBOS-024 RK-003 (bKernel caído), SBOS-026 RK-012 (restore con recreación de slots)*
