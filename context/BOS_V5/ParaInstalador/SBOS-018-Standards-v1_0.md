# SBOS-018 — Estándares de Calidad y Principios de Desarrollo
## SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

**Código:** SBOS-018
**Versión:** 1.0
**Estado:** ACTIVO
**Complemento:** SBOS-018-DEPLOY-FeatureFlags-v1_0.md (Feature Flags y Blue/Green de daemons soberanos — integrado en v2.0 como §7)
**Reemplaza a:** SBOS-013-STANDARDS v2.0 (SUPERSEDED)
**Clasificación:** Estándares Técnicos — Referencia Obligatoria para todo Desarrollo SKULL

---

## Tabla de Contenidos

1. [Los 14 Principios Inquebrantables del Core](#1-los-14-principios-inquebrantables-del-core)
2. [Estándares Bash](#2-estándares-bash)
3. [Estándares Python](#3-estándares-python)
4. [Estándares Rust (SBOS Data Kernel, SBOS Data Integration)](#4-estándares-rust-bkernel-biedata-bcompass)
5. [Estándares YAML (yaml_engine.yml)](#5-estándares-yaml-yaml_engineyml)
6. [Estándares de Contratos YAML de Daemons Soberanos](#6-estándares-de-contratos-yaml-de-daemons-soberanos)
7. [Estándares SBOS Data RAG](#7-estándares-bsearch)
8. [Regla de Oro: Global vs Individual](#8-regla-de-oro-global-vs-individual)
9. [Validadores Automáticos en CI/CD](#9-validadores-automáticos-en-cicd)

---

## Tabla Canónica de Lenguajes por Daemon

| Daemon | Nombre conceptual | Servicio | Lenguaje |
|--------|------------------|----------|---------|
| SBOS IAM Installer | SBOS IAM Installer: Application & Process Orchestrator | `bos.service` | Go |
| SBOS Data Kernel | SBOS Data Kernel: Active Orchestration Engine | `bkernel.service` | **Rust** |
| SBOS Data Integration | SBOS Data Integration: Federated Batch Exchange | `biedata.service` | **Rust** |
| SBOS AI Tools | SBOS AI Tools: Collaborative & Federated Intelligence | `bcompass.service` | Go |
| SBOS Data RAG | SBOS Data RAG: Sovereign Federated Intelligent Search | `bsearch.service` | Go |
| SBOS Auth Enforce | SBOS Auth Enforce: Unified Identity & Permissions Orchestrator | `bauth.service` | Go |
| SBOS Nexus Host | SBOS Nexus Host: The Unified Sovereign Connectivity Bridge | `bhnexus.service` | Go |
| SBOS Nexus Host Client | SBOS Nexus Agent: Distributed Access Interface | `banexus.service` | Go |

---

## 1. Los 14 Principios Inquebrantables del Core

1. **P1:** `sbos_k8s_core()` es el ÚNICO punto que llama kubectl para apps
2. **P2:** `pre_install` es el guardián — si falla, ABORT completo, sin bypass
3. **P3:** El catálogo global NUNCA nombra aplicaciones concretas
4. **P4:** El Core nunca crece para soportar aplicaciones nuevas (las apps se soportan a sí mismas vía fichas), pero evoluciona continuamente para convertirse en una herramienta de instalación, observación y administración enterprise, robusta y profesional
5. **P5:** `yaml_engine.yml` no contiene lógica Bash — solo declaraciones
6. **P6:** Todas las funciones del `task_catalog.sh` terminan con `export -f`
7. **P7:** El ciclo Absorber/Ejecutar/Liberar es obligatorio
8. **P8:** `STATE_MANAGER.py` es la ÚNICA escritura en `.sbos_state.json`
9. **P9:** Idempotencia obligatoria: `--dry-run=client | kubectl apply -f -`
10. **P10:** Toda función Bash termina con `return 0` o `return 1` explícitos
11. **P11:** `update` nunca reinstala — aplica solo el delta por drift_check
12. **P12:** `repair` siempre diagnostica antes de actuar
13. **P13:** Todo evento de instalación se emite en tiempo real
14. **P14:** `cold` nunca ejecuta automáticamente — requiere aprobación humana

---

## 2. Estándares Bash

- `#!/usr/bin/env bash` + `set -euo pipefail` obligatorio
- `local` para todas las variables dentro de funciones
- `yq eval` para leer YAML — nunca `grep`/`sed` para parsear YAML
- `${SBOS_DIR}` — nunca `/opt/sbos` hardcodeado
- Logging vía `python3 "${LOGGER_PY}"` — nunca `echo` directo para logs
- Idempotencia: verificar estado antes de actuar
- Señales `__SBOS__STEP_START__`, `__SBOS__STEP_OK__`, `__SBOS__STEP_ERROR__` en cada función
- Finales de línea: LF Unix — NUNCA CRLF

---

## 3. Estándares Python

- Type hints en todas las funciones públicas
- Docstrings en todas las clases y funciones públicas
- `from pathlib import Path` — nunca `os.path`
- Logging vía `LOGGER.py` con `get_logger("sbos.modulo")` — nunca `print()`
- Todo subprocess vía `PROCESS_MANAGER.py` — nunca `subprocess.run()` directo
- Manejo explícito de excepciones — sin `except Exception: pass`
- `asyncio.create_subprocess_exec` para procesos de instalación
- Tests unitarios para toda lógica de negocio

---

## 4. Estándares Rust — SBOS Data Kernel y SBOS Data Integration

Los daemons de carga CPU-bound del SBOS están escritos en **Rust**:
**SBOS Data Kernel** (bkernel.service) y **SBOS Data Integration** (biedata.service).
Los demás daemons — **SBOS AI Tools** (bcompass), **SBOS Data RAG** (bsearch), **SBOS Auth Enforce** (bauth), **SBOS Nexus Host** (bhnexus), **SBOS Nexus Agent** (banexus) — están escritos en **Go** — ver §5.

**Compilación y seguridad:**
- `#![deny(unsafe_code)]` salvo en los bloques de C ABI (`route_catalog.so`, `box_catalog.so`) donde el unsafe es explícito, acotado y documentado
- `clippy` con `--deny warnings` — todo warning es un error en CI/CD
- `cargo fmt --check` obligatorio antes de merge — el formateado no es opcional

**Gestión de errores:**
- Sin `.unwrap()` ni `.expect()` en código de producción — usar `?` operator o manejo explícito
- Tipos de error propios con `thiserror::Error` — sin `Box<dyn Error>` en APIs públicas
- Todo `Result<T, E>` debe manejarse — el compilador lo garantiza, no suprimir el warning

**Arquitectura de los .so (shared objects de rutas y cajas):**
- El C ABI exportado sigue exactamente `bcompass_route_api.h` (SBOS AI Tools) o `bkernel_box_api.h` (SBOS Data Kernel/SBOS Data Integration) — sin extensiones
- El punto de entrada es siempre `bcompass_route_init()` o `bkernel_box_init()` — sin variantes
- Los `.so` no tienen estado global — toda la información de contexto llega vía `BCompassContext` / `BoxContext`
- Un `.so` que no puede compilar con `cargo build --release` es un error bloqueante — no se distribuye

**Pruebas:**
- Tests de integración obligatorios para todas las tareas del `.so` (`#[test]` en módulo `tests`)
- Prueba de carga con 1000 ejecuciones consecutivas sin leak de memoria (Valgrind o similar)
- El `.so` debe pasar `valgrind --leak-check=full` con zero errores antes de entrar a producción

**Firma criptográfica:**
- Todo `.so` distribuido con el SBOS IAM Installer lleva firma SHA-256 del equipo SKULL
- El daemon verifica la firma antes de `dlopen()` — un `.so` sin firma o con firma inválida no se carga (D5 de cada daemon)

---

## 5. Estándares YAML (yaml_engine.yml)

- Cero lógica Bash — solo declaraciones `task:` + `params:`
- `update_strategy` obligatorio en tareas de fase `update` (`hot`/`warm`/`cold`)
- `drift_check: true` por defecto
- `maintenance_window: true` en toda tarea `cold`

---

## 6. Estándares de Contratos YAML de Daemons Soberanos

Los daemons soberanos del stack usan archivos YAML como unidades de conocimiento declarativas. Estos contratos tienen sus propios estándares de calidad, separados de los estándares de la ficha del SBOS IAM Installer.

### route_engine.yml (SBOS AI Tools — SBOS-014)

```yaml
# Estructura mínima válida de un route_engine.yml
# Regla: todo archivo route_engine.yml debe pasar validate_sp02.py --type route

phases:                          # ← OBLIGATORIO: al menos una fase
  <fase_name>:
    tasks:
      - task: "<nombre_tarea>"   # ← OBLIGATORIO: nombre de tarea
        params: {}               # ← OBLIGATORIO: params (puede estar vacío)
        # on_failure: abort      ← OPCIONAL: default es abort
        # output: <nombre>       ← OPCIONAL: solo si la tarea produce output
```

**Reglas de validación para `route_engine.yml`:**
- Toda tarea debe ser del catálogo global del motor SBOS AI Tools o estar implementada en el `route_catalog.so` de la ruta — no puede referenciar tareas inexistentes
- Las referencias a outputs (`{fase.output}`) deben apuntar a outputs declarados en fases anteriores
- No puede existir una referencia circular entre fases
- `on_failure: retry(n)` — `n` debe ser un entero entre 1 y 5
- `llm_prompt` siempre debe declarar `model:` explícitamente — no hay modelo por defecto implícito

### box_engine.yml (SBOS Data Integration — SBOS-011)

```yaml
# Estructura mínima válida de un box_engine.yml
# Regla: todo archivo box_engine.yml debe pasar validate_sp02.py --type box

phases:
  <fase_name>:
    tasks:
      - task: "<nombre_tarea>"
        params: {}
```

**Reglas de validación para `box_engine.yml`:**
- La fase `extract` (si existe) siempre precede a `transform` y `load` — nunca en otro orden
- `on_failure: retry(n)` — máximo `n: 3` para cajas de integración externa (sistemas externos pueden estar caídos)
- Las cajas con `type: import` nunca tienen `destination: stack_db` como fuente — la dirección es externa → stack
- Las cajas con `type: export` nunca tienen `source: external_api` como destino — la dirección es stack → externa

### manifest.yml de cualquier daemon soberano

```yaml
# Reglas de validación para manifest.yml (rutas SBOS AI Tools, cajas SBOS Data Integration, colecciones Embedding Worker)

identity:
  id: "<string sin espacios, snake_case>"   # ← OBLIGATORIO
  version: "<semver N.N>"                   # ← OBLIGATORIO
  # Para SBOS AI Tools:
  route_type: "analyst|agent|flow|report"  # ← OBLIGATORIO en rutas SBOS AI Tools

trigger:                                     # ← OBLIGATORIO
  type: "schedule|message|manual|event"    # ← OBLIGATORIO

governance:
  category: 1|2|3                           # ← OBLIGATORIO
```

**Reglas transversales para manifests:**
- `identity.id` en `snake_case` — sin guiones, sin espacios, sin mayúsculas
- `version` en formato `N.N` — siempre exactamente dos números
- `governance.category` siempre declarado — no existe governance implícito

---

## 7. Estándares SBOS Data RAG

SBOS Data RAG (SBOS-013) usa patrones propios para la configuración de indexación en fichas del SBOS IAM Installer. Todo bloque `bsearch_config` en un `manifest.yml` de ficha debe cumplir:

```yaml
# bsearch_config en manifest.yml de una ficha — estructura válida
bsearch_config:
  enabled: true                  # ← OBLIGATORIO
  priority: 1-10                 # ← OBLIGATORIO — determina orden de indexación
  schema_discoverer: true|false  # ← OBLIGATORIO — habilita análisis semántico por LLM
  index_entities:                # ← OBLIGATORIO si enabled: true
    - entity: "<nombre>"         # ← snake_case
      table: "<schema>.<tabla>"  # ← formato schema.tabla obligatorio
      searchable_fields: []      # ← al menos un campo
      display_template: ""       # ← obligatorio — cómo se muestra en resultados
```

**Reglas de validación para `bsearch_config`:**
- `priority` entre 1 y 10 — no se admiten prioridades fuera de rango
- `table` siempre en formato `schema.tabla` — sin tabla sin schema
- `searchable_fields` debe contener al menos un campo — no puede indexar vacío
- `display_template` debe referenciar al menos uno de los campos de `searchable_fields`

---

## 8. Regla de Oro: Global vs Individual

Si la función **menciona** el nombre de una app concreta → va en el `task_catalog.sh` **individual** de esa ficha.

Si la función opera sobre K8s de forma **genérica** sin saber qué app es → va en el `00_TASK_CATALOG_SBOS.sh` **global**.

Esta regla aplica también a los daemons soberanos:

| Ámbito | Motor | Catálogo global | Catálogo específico |
|---|---|---|---|
| Ficha SBOS IAM Installer | Core (SP-01) | `00_TASK_CATALOG_SBOS.sh` | `task_catalog.sh` de la ficha |
| Ruta SBOS AI Tools | Motor SBOS AI Tools | Tareas globales del motor (`llm_prompt`, `db_query`, etc.) | `route_catalog.so` de la ruta |
| Caja SBOS Data Integration | Motor SBOS Data Integration | Tareas globales del motor (`http_fetch`, `csv_parse`, etc.) | `box_catalog.so` de la caja |

---

## 9. Validadores Automáticos en CI/CD

Los validadores son **pasos bloqueantes del `make release`** — no son opcionales ni de advertencia. Un release no puede generarse si cualquier validador retorna exit != 0.

### validate_sp01.py — Validador del Core (SP-01)

Verifica cumplimiento de los 14 Principios Inquebrantables en el código Core:

| Verificación | Principio | Falla si |
|---|---|---|
| kubectl fuera de `sbos_k8s_core` | P1 | Cualquier archivo del core llama `kubectl` directamente |
| Nombres de apps en catálogo global | P3 | El `00_TASK_CATALOG_SBOS.sh` menciona nombres de apps concretas |
| subprocess fuera de PROCESS_MANAGER | P5 | Python usa `subprocess.run()` directamente |
| Funciones sin `export -f` | P6 | Función Bash en `task_catalog.sh` sin `export -f` al final |
| Escritura directa a `.sbos_state.json` | P8 | Código fuera de `STATE_MANAGER.py` escribe en ese archivo |
| kubectl create sin `--dry-run` | P9 | `kubectl create` sin flag de idempotencia |
| Tareas cold sin flag `maintenance_window` | P14 | Tarea `cold` sin `maintenance_window: true` en YAML |
| Calidad Python | — | `print()`, `os.path`, `except Exception: pass`, type hints faltantes |

```bash
# Integración en Makefile — paso bloqueante
validate:
	python validate_sp01.py --file ./core/00_TASK_CATALOG_SBOS.sh
	python validate_sp01.py --file ./core/STATE_MANAGER.py
	python validate_sp01.py --file ./core/INSTALL_RUNNER.py
	# ... todos los archivos del core

release: validate build test
	@echo "Release validado — generando artefactos"
```

Uso manual: `python validate_sp01.py --file ./core/[archivo]`

Todo código debe pasar el validador con exit 0 antes de ser entregado.

### validate_sp02.py — Validador de Contratos de Daemons Soberanos

Nuevo validador (v4.0). Verifica cumplimiento de los estándares de contratos YAML de los daemons soberanos:

| Tipo de contrato | Flag | Verifica |
|---|---|---|
| `route_engine.yml` de SBOS AI Tools | `--type route` | Fases válidas, tareas referenciadas, outputs declarados, sin ciclos, on_failure válido |
| `box_engine.yml` de SBOS Data Integration | `--type box` | Orden de fases, n de retry, dirección de la caja |
| `manifest.yml` de ruta/caja | `--type manifest` | id snake_case, version semver, governance.category presente |
| `bsearch_config` en manifest | `--type bsearch` | priority en rango, table con schema, searchable_fields no vacío |

```bash
# Integración en Makefile — paso bloqueante
validate_daemons:
	find /etc/bos/blibs/bcompass/router -name "route_engine.yml" \
	  -exec python validate_sp02.py --type route --file {} \;
	find /etc/bos/blibs/bcompass/router -name "manifest.yml" \
	  -exec python validate_sp02.py --type manifest --file {} \;
	find /etc/bos/blibs/biedata/boxes -name "box_engine.yml" \
	  -exec python validate_sp02.py --type box --file {} \;

release: validate validate_daemons build test
	@echo "Release validado — generando artefactos"
```

Uso manual: `python validate_sp02.py --type route --file ./router/analyst/reglas_inactivas/route_engine.yml`

### Integración completa en pipeline CI/CD

```
make release
  │
  ├── [BLOQUEANTE] validate (validate_sp01.py)
  │     → Exit != 0 → ABORT — release cancelado
  │
  ├── [BLOQUEANTE] validate_daemons (validate_sp02.py)
  │     → Exit != 0 → ABORT — release cancelado
  │
  ├── [BLOQUEANTE] cargo clippy --deny warnings (Rust .so)
  │     → Exit != 0 → ABORT — release cancelado
  │
  ├── [BLOQUEANTE] cargo fmt --check (Rust .so)
  │     → Exit != 0 → ABORT — release cancelado
  │
  ├── [BLOQUEANTE] tests (Python + Rust)
  │     → Exit != 0 → ABORT — release cancelado
  │
  └── build → sign → package → publish
```

**Política de excepciones:** no existen. Los validadores no tienen flags `--warn-only` ni `--skip`. Si un desarrollador necesita una excepción, debe proponer una modificación al estándar — no una excepción al validador.

---

## 5. Estándares Go — Daemons I/O-bound

Los daemons I/O-bound del SBOS están escritos en Go:
SBOS IAM Installer (bos), SBOS AI Tools (bcompass), SBOS Data RAG (bsearch),
SBOS Auth Enforce (bauth), SBOS Nexus Host (bhnexus), SBOS Nexus Agent (banexus).

**Versión mínima:** Go 1.22+
**Compilación:** `CGO_ENABLED=0 go build -ldflags="-s -w"` — binario estático
**Targets:** linux/amd64 y linux/arm64

---

*SKULL · SBOS · SBOS-018-STANDARDS · v1.0 · Marzo 2026*
*Reemplaza: SBOS-013-STANDARDS v2.0 — SUPERSEDED*

---

## 10. Justificación Técnica de la Decisión Rust vs Go por Daemon

La elección de lenguaje para cada daemon soberano no es arbitraria ni estética — es una consecuencia directa del perfil de carga de trabajo. La matriz de decisión central es la siguiente:

| Criterio | Rust | Go |
|----------|------|----|
| **Modelo de memoria** | Ownership + borrow checker (zero GC) | Garbage Collector concurrente |
| **Latencia** | Determinista, sin pausas GC | Predecible, GC de baja latencia |
| **Concurrencia** | async/await + tokio (zero-cost abstractions) | Goroutines (2–4 KB) + channels |
| **Workloads I/O-bound** | Excelente (pero más verboso) | Excelente + idiomático |
| **Tiempo de desarrollo** | Mayor (borrow checker) | Rápido (sintaxis minimalista) |
| **Caso ideal en SBOS** | WAL CDC, parseo de archivos grandes, ETL transaccional | WebSocket, HTTP APIs, Redis Streams |

**La regla de asignación:**
- **Rust** → daemons con requisitos de latencia determinista y sin GC: `bkernel`, `biedata`
- **Go** → daemons I/O-bound con alta concurrencia de red: `bcompass`, `bsearch`, `bauth`, `bhnexus`, `banexus`
- **Go + Python + Bash** → `bos` (naturaleza híbrida de orquestación)

No existe un lenguaje óptimo para todos los daemons. La arquitectura polyglot del SBOS es una decisión de ingeniería deliberada, no una deuda técnica.

---

## 11. Stack Tecnológico Detallado por Daemon

### 11.1 bos — Go + Python + Bash

El SBOS IAM Installer es el daemon orquestador soberano. Su naturaleza es fundamentalmente híbrida: necesita la velocidad y el control de un binario nativo (Go), la flexibilidad de un lenguaje dinámico para la lógica declarativa de fichas (Python), y acceso directo al sistema operativo para operaciones atómicas de instalación (Bash).

**Por qué Go para el daemon principal:** binario estático sin dependencias, arranque en < 100ms, concurrencia nativa para gestionar múltiples fichas en paralelo, `net/http` nativo para comunicación con el Release Server y el Core UI.

**Por qué Python para los módulos de fichas:** las fichas son lógica declarativa que evoluciona con cada cliente — Python permite modificarlas sin recompilar el daemon. Los `task_catalog.so` son módulos Python compilados (Cython) para distribución eficiente.

**Por qué Bash para operaciones OS:** operaciones atómicas de instalación con semántica POSIX garantizada, rollback de binarios vía shell script, sin capa de abstracción entre el daemon y el sistema de archivos del host.

| Componente | Herramienta / Versión | Propósito |
|---|---|---|
| **Lenguaje principal** | Go 1.22+ | Binario daemon, servidor HTTP, orquestación |
| **Módulos de fichas** | Python 3.11+ + Cython | Lógica declarativa compilable |
| **Scripts OS** | Bash 5.x | Operaciones atómicas del sistema |
| **Gestor de paquetes Go** | go modules (go.mod) | Dependencias del daemon |
| **Gestor de paquetes Python** | pip + pyproject.toml | Dependencias de módulos |
| **Build system** | Makefile + go build | Compilación cruzada amd64/arm64 |
| **Runtime HTTP** | net/http stdlib | API con Core UI y Release Server |
| **Config parsing** | github.com/BurntSushi/toml | Lectura de bos.toml |
| **Logging** | github.com/rs/zerolog | Logging estructurado JSON |
| **Testing Go** | go test + testify | Unit tests del daemon |
| **Testing Python** | pytest | Tests de módulos de fichas |
| **CI/CD** | GitHub Actions + golangci-lint | Lint, tests, build release |

---

### 11.2 bkernel — Rust

El SBOS Data Kernel escucha el Write-Ahead Log (WAL) de PostgreSQL en tiempo real y ejecuta reglas de sincronización. El retraso > 500ms en el procesamiento del WAL se traduce directamente en datos inconsistentes entre aplicaciones del stack.

**El problema del GC en CDC:** los lenguajes con GC (Go, Java, Python) introducen pausas no deterministas de 1–50ms durante la recolección de basura. En un daemon que debe procesar eventos WAL con latencia < 100ms consistente, una pausa de 50ms durante una transacción grande es inaceptable. Rust elimina este problema por diseño: no tiene GC, la memoria se libera determinísticamente al salir del scope.

**Proyectos de producción que validan esta decisión:**
- **Supabase/etl:** framework CDC de Supabase en Rust para replicación en tiempo real a BigQuery e Iceberg — misma arquitectura WAL + Rust que bkernel.
- **pgwire-replication (Deltaforge):** crate Rust de bajo nivel para CDC usando `pgoutput` directamente sobre el wire protocol de PostgreSQL, sin libpq. Latencia determinista por diseño.
- **chgcap-rs:** alternativa a Debezium en Rust. Motivación explícita: Debezium en Java introduce overhead de JVM y pausas GC inaceptables para CDC de alta frecuencia.
- **Artie (replication platform):** usa Go + Redis Streams para webhooks, pero Rust para el core de replicación donde la latencia es crítica.

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

---

### 11.3 biedata — Rust

El SBOS Data Integration procesa archivos grandes (Excel de 50K+ filas, CSV de varios GB) como parte de integraciones con sistemas externos. El requisito crítico: una importación de 50.000 filas de Excel debe completarse de principio a fin sin interrupciones por GC, y sin consumir más memoria de la estrictamente necesaria.

**Benchmark calamine (Rust) vs alternativas** — archivo XLSX de 1.000.001 filas y 41 columnas (~186 MB):

| Biblioteca | Lenguaje | Tiempo (1M filas) | Relativo | Notas |
|---|---|---|---|---|
| **calamine** | Rust | 25.3s | **1x (más rápido)** | Sin GC, memoria predecible |
| **excelize** | Go | 44.3s | 1.75x más lento | GC spikes en archivos grandes |
| **ClosedXML** | C# (.NET) | 178.3s | 7x más lento | GC overhead alto |
| **openpyxl** | Python | 238.6s | 9.4x más lento | Interpretado + GC |

Calamine es 9.4x más rápido que openpyxl y 7x más rápido que ClosedXML. Polars (DataFrame de Python de alta performance) usa calamine como su motor de lectura de Excel por defecto — validación de que es production-ready para archivos de escala GB.

**Por qué sin GC es crítico para ETL transaccional:** en biedata, una importación de Excel es una transacción — o importa todas las filas o no importa ninguna (rollback). Si el GC pausa el proceso durante la transacción, el estado de la BD puede quedar parcialmente escrito. Con Rust, el ownership garantiza que los recursos se liberan en el orden correcto y la transacción puede hacer rollback de forma atómica.

| Componente | Herramienta / Crate | Propósito |
|---|---|---|
| **Lenguaje** | Rust 1.85+ (Edition 2024) | Daemon principal |
| **Runtime async** | tokio 1.x | Concurrencia I/O para integraciones |
| **Excel reader** | calamine 0.32 | Lectura XLSX/XLS/ODS sin GC pauses |
| **Excel writer** | rust_xlsxwriter 0.7 | Generación de reportes XLSX |
| **CSV parsing** | csv 1.3 + serde | Procesamiento de archivos CSV |
| **HTTP client** | reqwest 0.12 (async) | Llamadas a APIs REST externas |
| **XML/SOAP** | quick-xml 0.36 | Integración con servicios SOAP/XML |
| **SFTP** | russh 0.44 + tokio | Transferencia de archivos SFTP |
| **PostgreSQL client** | tokio-postgres + deadpool | Escritura en BD con origin='biedata' |
| **Redis client** | redis-rs (tokio) | Lectura de comandos desde bkernel |
| **TLS/Certificados** | rustls 0.23 | Conexiones HTTPS seguras (SIAT, AFIP, SAT) |
| **Config/Boxes** | toml + serde_yaml | Lectura de box_engine.yml |
| **Hot-reload .so** | libloading 0.8 | Carga de box_catalog.so |
| **Logging** | tracing + tracing-subscriber | Audit trail de integraciones |
| **Testing** | cargo test + mockall | Mocks de APIs externas |
| **Build** | cargo --release (MUSL) | Binario estático |

---

### 11.4 bcompass — Go

El SBOS AI Tools es un orquestador de agentes LLM. Su workload es fundamentalmente I/O-bound: múltiples llamadas HTTP a Ollama (inferencia LLM), consultas de solo lectura a PostgreSQL, y lecturas de Redis. El cuello de botella no es CPU sino la latencia de respuesta de los modelos (100ms – 30s por llamada).

**Por qué Go es ideal para orquestación de LLMs:**
- **Goroutines como agentes:** cada ruta analyst/agent/flow/monitor corre en su goroutine con costo de 2–4 KB. Una ruta que llama a 5 modelos LLM en paralelo crea 5 goroutines, no 5 OS threads.
- **Assembled.com (plataforma LLM en producción):** documenta que Go permite paralelizar búsquedas en múltiples backends LLM con canales, reduciendo la latencia total a la del backend más lento con timeouts configurables.
- **ByteDance/Eino:** framework de orquestación LLM en Go usado en producción para pipelines multi-agente con streaming automático y checkpoints para human-in-the-loop.

**Go vs Python para orquestación LLM:** Python (LangChain, LlamaIndex) domina el ecosistema de prototipado LLM. Sin embargo, para un daemon de producción embebido en un sistema soberano, Go tiene ventajas operativas críticas: binario estático sin virtualenv, arranque en < 50ms vs 1–3s de Python, y manejo de concurrencia sin el GIL. bcompass no necesita entrenar modelos ni manipular tensores — solo orquestar llamadas HTTP: exactamente el punto fuerte de Go.

| Componente | Herramienta / Módulo | Propósito |
|---|---|---|
| **Lenguaje** | Go 1.22+ | Daemon principal |
| **HTTP client LLM** | net/http stdlib + retries | Llamadas a Ollama (OpenAI compat API) |
| **HTTP client Streaming** | github.com/sashabaranov/go-openai | Streaming de respuestas LLM |
| **PostgreSQL client** | github.com/jackc/pgx/v5 | Queries readonly a BDs del stack |
| **Redis client** | github.com/redis/go-redis/v9 | Pub/Sub y streams para triggers |
| **YAML routes** | gopkg.in/yaml.v3 | Parsing de route_engine.yml |
| **Hot-reload .so** | plugin stdlib (Go plugins) | Carga de route_catalog.so |
| **Config** | github.com/BurntSushi/toml | Lectura de bcompass.toml |
| **Logging** | github.com/rs/zerolog | Logging estructurado JSON |
| **Métricas** | github.com/prometheus/client_golang | Exportación de métricas |
| **Context/timeout** | context stdlib | Cancelación de rutas LLM largas |
| **Signal handling** | os/signal + SIGUSR1/SIGUSR2 | Hot-reload y triggers manuales |
| **Testing** | go test + testify + httptest | Mocks de Ollama y PostgreSQL |
| **Linting** | golangci-lint | Calidad de código en CI |
| **Build** | go build -ldflags='-s -w' | Binario estático sin símbolos de debug |

---

### 11.5 bsearch — Go

El SBOS Data RAG es un motor de indexación y búsqueda. Consume eventos del bkernel vía Redis Streams, indexa entidades en Meilisearch, y sirve búsquedas con autenticación multi-tenant. El workload es masivamente concurrente: cientos de eventos de indexación por segundo más búsquedas interactivas de usuarios.

**Redis Streams + Go — patrón de producción documentado:**
- **Artie (replication platform):** usa Redis Streams + Go (Asynq) en producción para webhooks con alta confiabilidad. El patrón exacto de bsearch: stream como log durable, workers Go como consumer group, XACK para acknowledgment.
- **Consumer groups con goroutines:** cada worker del consumer group corre en su propia goroutine. `XREADGROUP` con `BLOCK` para espera eficiente sin busy-waiting.
- **Fan-out nativo:** una goroutine lee del stream, N goroutines procesan en paralelo, channel para fan-in de resultados de indexación.

Meilisearch tiene SDK oficial para Go (`meilisearch-go`). Los índices de bsearch son multi-tenant vía Tenant Tokens de Meilisearch, generados con HMAC-SHA256 desde Go de forma eficiente.

| Componente | Herramienta / Módulo | Propósito |
|---|---|---|
| **Lenguaje** | Go 1.22+ | Daemon principal |
| **Redis Streams** | github.com/redis/go-redis/v9 (XREADGROUP) | Consumer group para eventos bkernel |
| **Meilisearch SDK** | github.com/meilisearch/meilisearch-go | Indexación y búsquedas full-text |
| **Tenant Tokens** | crypto/hmac + crypto/sha256 stdlib | Multi-tenancy de índices |
| **PostgreSQL client** | github.com/jackc/pgx/v5 | Queries directas para schema discovery |
| **HTTP server** | github.com/gin-gonic/gin | API de búsqueda con auth JWT |
| **JWT validation** | github.com/golang-jwt/jwt/v5 | Validación tokens Keycloak |
| **Pattern YAML** | gopkg.in/yaml.v3 | Parsing de pattern_engine.yml |
| **Hot-reload .so** | plugin stdlib (Go plugins) | Carga de pattern_catalog.so |
| **inotify watcher** | github.com/fsnotify/fsnotify | Hot-reload de patrones en /etc/bos/blibs/bsearch/ |
| **Config** | github.com/BurntSushi/toml | Lectura de bsearch.toml |
| **Logging** | github.com/rs/zerolog | Logging estructurado JSON |
| **Métricas** | github.com/prometheus/client_golang | Lag de indexación, latencia de búsqueda |
| **Testing** | go test + testcontainers-go | Tests con Meilisearch y Redis reales |
| **Build** | go build -ldflags='-s -w' | Binario estático |

---

### 11.6 bauth — Go

El SBOS Auth Enforce orquesta autenticación federada: HTTP a la Admin API de Keycloak, XML-RPC a Tryton para sincronización de usuarios, y WebSockets para notificaciones de sesión al SBOS VDI. Es un workload I/O-bound puro con alta concurrencia de llamadas API heterogéneas.

**Concurrencia heterogénea — el patrón exacto de Go:**
- Keycloak Admin API: REST HTTP, hasta 100 requests/s durante onboarding masivo. `context.Context` para timeouts per-request.
- Tryton XML-RPC: protocolo síncrono, pero bauth lo envuelve en goroutines para no bloquear el loop principal.
- WebSocket notifications: sesiones activas del SBOS VDI reciben notificaciones de cambio de permisos en tiempo real.
- Go maneja los tres protocolos con el mismo scheduler de goroutines sin threads adicionales del OS.

| Componente | Herramienta / Módulo | Propósito |
|---|---|---|
| **Lenguaje** | Go 1.22+ | Daemon principal |
| **HTTP client KC** | net/http + oauth2 | Keycloak Admin REST API |
| **XML-RPC client** | github.com/kolo/xmlrpc | Tryton user sync |
| **WebSocket server** | github.com/coder/websocket | Notificaciones de sesión SBOS VDI |
| **PostgreSQL client** | github.com/jackc/pgx/v5 | Estado de sesiones en bauth_db |
| **JWT generation** | github.com/golang-jwt/jwt/v5 | Tokens de sesión SBOS VDI |
| **Auth rules YAML** | gopkg.in/yaml.v3 | Parsing de auth_engine.yml |
| **Hot-reload .so** | plugin stdlib (Go plugins) | Carga de auth_catalog.so |
| **Config** | github.com/BurntSushi/toml | Lectura de bauth.toml |
| **Logging** | github.com/rs/zerolog | Audit log de autenticaciones |
| **Testing** | go test + testify + WireMock | Mock de Keycloak y Tryton |
| **Build** | go build -ldflags='-s -w' | Binario estático |

---

### 11.7 bhnexus y banexus — Go

bhnexus (host Ubuntu) y banexus (agente Fedora en SBOS VDI) implementan el protocolo de privilegios del sistema: políticas de red, quotas de disco, acceso a aplicaciones VDI. El requisito de escala es 10.000+ conexiones WebSocket concurrentes por servidor de virtualización.

**Go y WebSockets a escala — evidencia de producción:**
- **Benchmark documentado:** con la arquitectura correcta de goroutines + epoll, un servidor Go maneja 10 millones de conexiones WebSocket concurrentes en hardware estándar.
- **EC2 t3.medium:** sustiene > 25.000 sesiones WebSocket abiertas antes de saturar CPU o memoria con goroutines bien gestionadas.
- **Centrifugo (plataforma WebSocket en Go en producción):** documenta técnicas de `PreparedMessage` para reducir allocations de GC en broadcasts a miles de conexiones.
- **Mail.ru (caso real):** implementaron servidor de chat con 1 millón de conexiones WebSocket en Go usando netpoll + epoll para minimizar el uso de goroutines por conexión.

**Técnicas de optimización para 10K+ conexiones:**
- Una goroutine por conexión: el Go scheduler maneja 10K goroutines con costo total de ~20–40 MB RAM (2–4 KB por goroutine).
- Buffered channels: cola de mensajes por cliente para no bloquear el hub de broadcast ante clientes lentos.
- `PreparedMessage`: genera el frame WebSocket una sola vez para broadcasts, evitando N compresiones concurrentes.
- Redis pub/sub para horizontal scaling: el protocolo de bhnexus/banexus escala a múltiples servidores host vía Redis.

**banexus** es idéntico arquitecturalmente a bhnexus pero corre como servicio `--user` en el espacio de usuario de Fedora dentro del contenedor SBOS VDI. Se distribuye como binario Go estático dentro de la imagen Docker, eliminando dependencias de runtime en el contenedor.

| Componente | Herramienta / Módulo | Propósito |
|---|---|---|
| **Lenguaje** | Go 1.22+ | Daemon principal |
| **WebSocket server** | github.com/coder/websocket | 10K+ conexiones concurrentes (API idiomática) |
| **WebSocket alternativo** | github.com/gorilla/websocket | Fallback, 42K importaciones en producción |
| **PreparedMessage** | websocket.PreparedMessage | Broadcast eficiente sin re-comprimir |
| **HTTP server** | net/http stdlib | Health checks y API de control |
| **PostgreSQL client** | github.com/jackc/pgx/v5 | Rights en bhnexus_db |
| **Rights YAML** | gopkg.in/yaml.v3 | Parsing de rights_engine.yml |
| **Hot-reload .so** | plugin stdlib (Go plugins) | Carga de rights_catalog.so |
| **inotify watcher** | github.com/fsnotify/fsnotify | Hot-reload de rights vía SIGUSR1 |
| **Squid helper** | net/http + Unix socket | Política de red para Squid proxy |
| **Config host** | github.com/BurntSushi/toml | Lectura de host.yml (bhnexus) |
| **Config agent** | github.com/BurntSushi/toml | Lectura de banexus.toml |
| **Logging** | github.com/rs/zerolog | Audit log de accesos VDI |
| **Métricas** | github.com/prometheus/client_golang | Conexiones activas, latencia de rights |
| **Testing** | go test + testify | Tests de políticas de acceso |
| **Build bhnexus** | go build (Linux amd64) | Binario para host Ubuntu |
| **Build banexus** | go build (Linux amd64 static) | Binario estático para imagen Fedora |

---

## 12. Toolchain de Desarrollo por Lenguaje

### 12.1 Rust — Toolchain Completo

Rust tiene el toolchain más integrado del ecosistema de sistemas. Cargo unifica build, test, lint, docs y publicación en una sola herramienta.

| Herramienta | Comando | Cuándo se usa |
|---|---|---|
| **rustup** | `rustup toolchain install stable` | Instalación y actualización de Rust |
| **cargo build** | `cargo build --release` | Build optimizado para producción |
| **cargo test** | `cargo test --all-features` | Todos los unit e integration tests |
| **cargo check** | `cargo check` (sin compilar .so) | Verificación rápida de tipos < 1s |
| **cargo clippy** | `cargo clippy -- -D warnings` | Linter: warnings tratados como errores en CI |
| **rustfmt** | `cargo fmt --check` | Formato uniforme enforced en CI |
| **cargo audit** | `cargo audit` | Vulnerabilidades de seguridad en dependencias |
| **cross** | `cross build --target x86_64-unknown-linux-musl` | Cross-compile a binario estático MUSL |
| **cargo flamegraph** | `cargo flamegraph --bin bkernel` | Profiling de CPU en producción |
| **tokio-console** | `TOKIO_CONSOLE=1 cargo run` | Debug de tasks async en desarrollo |
| **rust-analyzer** | Extensión VSCode / RustRover | Autocompletado + diagnósticos en tiempo real |

### 12.2 Go — Toolchain Completo

| Herramienta | Comando | Cuándo se usa |
|---|---|---|
| **go build** | `go build -ldflags='-s -w' -o bin/` | Build para producción (sin símbolos debug) |
| **go test** | `go test -race -coverprofile=cov.out ./...` | Tests con detector de race conditions |
| **go vet** | `go vet ./...` | Análisis estático de correctitud |
| **golangci-lint** | `golangci-lint run --fix` | Suite completa de linters (40+) |
| **gofmt / goimports** | `gofmt -w . / goimports -w .` | Formato y organización de imports |
| **go mod tidy** | `go mod tidy` | Limpieza de dependencias no usadas |
| **govulncheck** | `govulncheck ./...` | Vulnerabilidades en dependencias |
| **dlv (Delve)** | `dlv debug --headless` | Debugger nativo para Go |
| **pprof** | `go tool pprof http://localhost:6060/debug/pprof/` | Profiling CPU/memoria en producción |
| **go tool trace** | `go test -trace trace.out` | Análisis de goroutines y scheduling |
| **gopls** | Extensión VSCode / GoLand | Language server oficial |

---

## 13. Pipeline CI/CD por Daemon

### 13.1 Pipeline Rust — bkernel y biedata

| Etapa | Comando | Criterio de éxito |
|---|---|---|
| **Format** | `cargo fmt --check` | Sin diffs de formato |
| **Lint** | `cargo clippy -- -D warnings` | 0 warnings |
| **Check** | `cargo check --all-features` | Sin errores de tipo |
| **Test** | `cargo test --all-features` | 100% tests pasan |
| **Audit** | `cargo audit` | Sin CVEs críticas |
| **Build** | `cross build --release --target x86_64-unknown-linux-musl` | Binario estático generado |
| **Sign** | ed25519 firma del binario | Firma verificable por bos |

### 13.2 Pipeline Go — bcompass, bsearch, bauth, bhnexus, banexus

| Etapa | Comando | Criterio de éxito |
|---|---|---|
| **Format** | `gofmt -l . \| grep -c .` | 0 archivos sin formato |
| **Vet** | `go vet ./...` | Sin errores de análisis |
| **Lint** | `golangci-lint run` | 0 issues con configuración estricta |
| **Test** | `go test -race -count=1 ./...` | 0 fallos, 0 race conditions |
| **Coverage** | `go test -coverprofile=cov.out ./...` | > 80% cobertura |
| **Vuln** | `govulncheck ./...` | Sin CVEs críticas |
| **Build** | `go build -ldflags='-s -w' -o bin/` | Binario estático generado |
| **Sign** | ed25519 firma del binario | Firma verificable por bos |

---

## 14. Estructura de Repositorios por Daemon

Cada daemon tiene su propio repositorio independiente. Los ciclos de release de bkernel (crítico, Rust) y bcompass (LLM, Go) son completamente diferentes. Un monorepo crearía acoplamientos innecesarios entre binarios con requisitos de seguridad y velocidad de iteración distintos.

| Repositorio | Lenguaje | Binario target | Notas |
|---|---|---|---|
| **sbos-bos** | Go + Python + Bash | bos | Daemon IAM Installer + módulos Python de fichas |
| **sbos-bkernel** | Rust | bkernel | CDC WAL — latencia crítica — releases controlados |
| **sbos-biedata** | Rust | biedata | ETL + parseo Excel — misma cadencia que bkernel |
| **sbos-bcompass** | Go | bcompass | Orquestador LLM — iteración rápida por rutas nuevas |
| **sbos-bsearch** | Go | bsearch | Motor de búsqueda — evolución junto a Meilisearch |
| **sbos-bauth** | Go | bauth | Auth daemon — cambios alineados con Keycloak releases |
| **sbos-bnexus** | Go | bhnexus + banexus | Repo unificado: protocolo host y agente son el mismo |

---

## 15. Matriz de Riesgos Técnicos por Daemon

| Daemon | Riesgo principal | Severidad | Mitigación |
|---|---|---|---|
| **bkernel** | Complejidad borrow checker en manejo de LSN | Media | Tokio + tipos wrapper para LSN. Tests exhaustivos de replay. |
| **biedata** | calamine: sin soporte de formato (solo lectura de valores) | Media | Documentar limitación. rust_xlsxwriter para escritura. |
| **bcompass** | GC pauses durante streaming LLM largo (> 30s) | Baja | `context.Context` con timeout. Streaming chunked para no acumular en heap. |
| **bsearch** | Go plugin system (.so) inestable entre versiones | Media | Fijar versión de Go en CI. Interfaz mínima en plugin API. |
| **bhnexus/banexus** | Memory leak en goroutines sin cierre correcto | Media | `SetReadDeadline` + `SetWriteDeadline`. pprof en producción para detectar leaks. |
| **bauth** | Latencia Tryton XML-RPC en onboarding masivo | Baja | Pool de goroutines para XML-RPC. Circuit breaker por timeout. |
| **bos** | Módulos Python sin recompilar tras cambio de lógica | Media | Cython en pre-release. Tests de integración de fichas en CI. |

---

*SKULL · SBOS · SBOS-018-STANDARDS · v1.0 · Marzo 2026 — Enriquecido con justificaciones técnicas del stack de daemons soberanos*
-e 
---

## Versionado API REST

> **Integrado desde SBOS-018-API en v2.0.**

**Versión:** 1.0
**Estado:** ACTIVO
**Clasificación:** Estándar de Ingeniería — Contratos de API
**Complementa:** SBOS-007-COREUI-v4_0.md (§A Versionado API REST) y SBOS-022-BoundedContexts-v1_0.md (§nueva Contratos API)
**Insertar en:** SBOS-007 como §nueva sección API Versioning + SBOS-022 como §nueva sección Contratos API

---

## Sección para SBOS-007 — Política de Versionado API REST

### A.1 Convención de versionado en Kong

Todas las APIs externas accesibles por los clientes y sus integraciones pasan por Kong. El formato de URL es uniforme en todo el stack:

```
/api/v{MAJOR}/{bounded-context}/{recurso}
```

**Ejemplos:**

| Endpoint | Bounded Context | Recurso | Versión |
|----------|----------------|---------|---------|
| `/api/v1/identity/users` | identity | users | v1 |
| `/api/v1/erp/invoices` | erp | invoices | v1 |
| `/api/v1/hrm/employees` | hrm | employees | v1 |
| `/api/v1/ecommerce/orders` | ecommerce | orders | v1 |
| `/api/v2/erp/invoices` | erp | invoices | v2 (cuando exista breaking change) |

**Regla de incremento de versión MAJOR:** cualquier cambio que requiera modificar el código del cliente consumidor es un cambio breaking. Específicamente:

- Eliminar un campo de la respuesta JSON.
- Cambiar el tipo de dato de un campo existente.
- Cambiar la semántica de un campo (mismo nombre, diferente significado).
- Cambiar la URL de un endpoint.
- Cambiar el método HTTP de un endpoint.
- Hacer obligatorio un campo que antes era opcional.

**Lo que NO requiere incremento de versión MAJOR:**
- Agregar nuevos campos opcionales a la respuesta (backward compatible).
- Agregar nuevos endpoints.
- Mejorar la performance sin cambiar el contrato.

**Quién define la versión:** el equipo del bounded context propietario del recurso. El cambio de versión MAJOR requiere un RFC en SBOS-025 (proceso ARB).

### A.2 Versionado de la API interna IAM Installer ↔ Core UI

Esta API **no pasa por Kong** — es interna al host. El IAM Installer (SP-04 FastAPI) y el Core UI (SP-06 Flutter) se comunican directamente.

**Header de versión:** `X-IAM-API-Version: {semver}`

```
# Ejemplo de request del Core UI al IAM Installer
GET /internal/fichas/status
X-IAM-API-Version: 1.3.0
Authorization: Bearer <token interno>
```

**Reglas de compatibilidad interna:**

1. El IAM Installer declara su versión de API en el endpoint `GET /internal/version`.
2. El Core UI verifica la compatibilidad al iniciar la sesión.
3. Si la versión del IAM Installer es incompatible con el Core UI, el Core UI muestra un banner de advertencia al administrador.
4. El IAM Installer y el Core UI se despliegan coordinadamente en el mismo release — no se puede desplegar uno sin que el otro sea compatible. Esta restricción está codificada en el proceso de release de SP-04 y SP-06.

**Política de compatibilidad backward:** el IAM Installer soporta la versión de API del Core UI actual y la versión anterior (N y N-1). Esto permite que el Core UI se actualice en un deploy separado si es necesario.

### A.3 Política de sunset para APIs externas en Kong

Cuando un endpoint es deprecado (reemplazado por una versión mayor):

1. **Header Sunset en todas las respuestas del endpoint deprecado:**
   ```
   Sunset: Sat, 31 Dec 2026 23:59:59 GMT
   Deprecation: true
   Link: <https://bos.cliente.com/api/v2/erp/invoices>; rel="successor-version"
   ```

2. **Período mínimo de soporte tras deprecación:** 6 meses. Durante este período, el endpoint v{anterior} sigue funcionando.

3. **Notificación al administrador:** el Core UI muestra un banner amarillo cuando el administrador usa una funcionalidad que depende de un endpoint en período de sunset. El banner incluye la fecha límite y el enlace a la documentación de migración.

4. **Eliminación del endpoint:** después del período de sunset, el endpoint retorna `HTTP 410 Gone` con mensaje explicativo.

### A.4 Contrato de API por bounded context (OpenAPI 3.1)

Ubicación en el repositorio: `servers/{server}/api/openapi.yaml`

```yaml
# Ejemplo: servers/s04-erpserver/api/openapi.yaml
openapi: "3.1.0"
info:
  title: SBOS ERP API
  version: "1.0.0"
  description: |
    API del bounded context ERP (Tryton).
    Esta API es gestionada por el IAM Installer y expuesta via Kong.
  contact:
    name: SKULL Systems
    url: https://skull.bo

servers:
  - url: https://bos.{tenant}.com/api/v1/erp
    description: Producción (tenant específico)
    variables:
      tenant:
        description: Realm/tenant del cliente
        default: example

paths:
  /invoices:
    get:
      operationId: listInvoices
      summary: Listar facturas
      security:
        - keycloakOAuth: [erp:read]
      parameters:
        - name: state
          in: query
          schema:
            type: string
            enum: [draft, confirmed, posted, paid, cancelled]
        - name: limit
          in: query
          schema:
            type: integer
            default: 20
            maximum: 100
      responses:
        "200":
          description: Lista de facturas
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/InvoiceList'
        "401":
          description: Token JWT inválido o expirado
        "403":
          description: Sin permiso erp:read en el realm

components:
  securitySchemes:
    keycloakOAuth:
      type: oauth2
      flows:
        authorizationCode:
          authorizationUrl: https://bos.{tenant}.com/realms/{tenant}/protocol/openid-connect/auth
          tokenUrl: https://bos.{tenant}.com/realms/{tenant}/protocol/openid-connect/token
          scopes:
            erp:read: Lectura de datos ERP
            erp:write: Escritura de datos ERP
```

**Generación automática:** FastAPI genera el archivo `openapi.json` automáticamente desde las anotaciones del código. Para Tryton y otras apps del stack (que no son FastAPI), el contrato es declarativo manual — el equipo de fichas lo mantiene actualizado.

**Proceso de cambio breaking:** cualquier cambio al contrato OpenAPI que sea breaking requiere un RFC en SBOS-025 antes de ser implementado.

---

## Sección para SBOS-022 — Contratos de API entre Bounded Contexts

### B.1 APIs entre bounded contexts: WAL, no REST

Una distinción fundamental del SBOS: los bounded contexts **no se llaman entre sí via API REST**. La comunicación entre bounded contexts es via el WAL de PostgreSQL (bKernel como propagador). Las APIs REST son para consultas del Core UI y para integraciones externas via Kong.

```
BC-02 RRHH (OrangeHRM)
  ↓ INSERT en orangehrm.employee (WAL event)
  ↓ bKernel detecta el evento
  ↓ bKernel aplica regla YAML
  ↓ bKernel escribe en BC-04 Identity (crea usuario en Keycloak via API KC)
  ↓ bKernel escribe en BC-01 ERP (crea party en Tryton)
```

No hay una llamada HTTP directa de OrangeHRM hacia Tryton. El bKernel es el único propagador.

### B.2 Tabla de contratos de API externos por bounded context

| Bounded Context | API externa expuesta | Versión actual | Consumers externos permitidos |
|----------------|---------------------|---------------|------------------------------|
| BC-01 ERP | `/api/v1/erp/` | v1 | Integraciones de clientes via Kong |
| BC-02 RRHH | `/api/v1/hrm/` | v1 | Portal self-service de empleados |
| BC-03 Ecommerce | `/api/v1/ecommerce/` | v1 | Tienda web externa del cliente |
| BC-04 Identity | `/api/v1/identity/` | v1 | Solo admin — no exponer a usuarios finales |
| BC-05 Tributario | `/api/v1/tax/` | v1 | Sistemas contables externos del cliente |

### B.3 Eventos WAL como contratos internos

Aunque los BCs no se llaman via API, los **eventos WAL son contratos implícitos**. Si BC-02 (RRHH) cambia la estructura de la tabla `orangehrm.employee`, el bKernel puede dejar de detectar correctamente los eventos de empleados.

Los cambios de esquema en tablas monitoreadas por el bKernel requieren:
1. RFC en SBOS-025 (como cambio breaking).
2. Actualización de las reglas YAML del bKernel para el nuevo esquema.
3. Prueba en staging antes de aplicar en producción.

---

*SKULL · SBOS · SBOS-018-API · v1.0 · Marzo 2026*
*Insertar: Sección A en SBOS-007-CoreUI, Sección B en SBOS-022-BoundedContexts*
-e 
---

## Feature Flags y Blue/Green de Daemons

> **Integrado desde SBOS-018-DEPLOY en v2.0.**

**Versión:** 1.0
**Estado:** ACTIVO
**Clasificación:** Estándar de Ingeniería — Estrategia de Despliegue
**Complementa:** SBOS-018-Standards-v1_0.md (§7 Feature Flags y Blue/Green) y SBOS-024-Operations-v1_0.md (§12 RK-014)
**Insertar en:** SBOS-018 como §7 + complemento en SBOS-024 §12

---

## §7 — Feature Flags y Estrategia de Despliegue Gradual para Fichas y Daemons

### 7.1 Principio de no-interferencia con el rollout canary existente

El IAM Installer ya implementa un rollout canary con tres canales (canary → early → stable) y criterios de halt automático definidos en SBOS-024 §5. Esta sección **no rediseña** ese mecanismo — lo complementa con:

1. **Feature flags para fichas de aplicación:** permiten activar funcionalidades nuevas solo en tenants específicos antes del rollout completo.
2. **Blue/green para daemons soberanos:** proceso análogo al rollout canary pero para los binarios systemd (bKernel, SBOS Data Integration, SBOS AI Tools) que tienen un ciclo de actualización diferente al de las fichas K8s.

---

### 7.2 Feature Flags para fichas de aplicación

#### Mecanismo

En el `manifest.yml` de una ficha, el campo `feature_flag` controla la visibilidad de la ficha:

```yaml
# manifest.yml — ficha en estado EXPERIMENTAL
name: sp-nueva-app
version: "0.1.0"
description: "Nueva integración experimental"
server: s04-erpserver
namespace: erpserver

# Feature flag: controla en qué tenants se despliega esta ficha
feature_flag:
  enabled: true                        # Esta ficha requiere feature flag activo
  keycloak_realm_attribute: "feature_sp_nueva_app"  # Nombre del atributo en el realm
  stage: experimental                  # experimental | beta | ga
```

**Cómo el IAM Installer evalúa el feature flag:**

```python
# IAM Installer — lógica de evaluación de feature flags en FICHA_PROBE.py

def should_deploy_ficha(ficha: Ficha, realm_config: RealmConfig) -> bool:
    """
    Decide si una ficha debe desplegarse en este tenant.
    """
    if not ficha.feature_flag or not ficha.feature_flag.enabled:
        return True  # Sin feature flag: siempre desplegar

    # Consultar el atributo del realm en Keycloak
    attribute = realm_config.get_attribute(ficha.feature_flag.keycloak_realm_attribute)

    if attribute is None:
        return False  # Atributo no configurado: no desplegar (opt-in requerido)

    return attribute.lower() == "true"
```

#### Ciclo de vida de una ficha con feature flag

```
EXPERIMENTAL → BETA → GA

EXPERIMENTAL (feature_flag.stage = "experimental"):
  - La ficha solo se despliega si el realm tiene el atributo habilitado
  - Solo el realm SKULL (equipo de desarrollo) tiene el atributo habilitado
  - Los clientes nunca ven esta ficha a menos que la soliciten explícitamente

BETA (feature_flag.stage = "beta"):
  - La ficha se despliega en realms que opten voluntariamente
  - El administrador del cliente activa el flag en el Core UI: Configuración > Features > [toggle]
  - El Core UI refleja la activación via la API del IAM Installer a Keycloak

GA (feature_flag.stage = "ga" o campo ausente):
  - El field feature_flag se elimina del manifest.yml
  - La ficha se despliega en todos los tenants automáticamente en el próximo ciclo de reconciliación
  - Los tenants que tenían el flag activo no notan cambio
```

#### Ejemplo práctico

```yaml
# Fase EXPERIMENTAL — solo equipo SKULL
name: sp-nueva-app
version: "0.1.0"
feature_flag:
  enabled: true
  keycloak_realm_attribute: "feature_sp_nueva_app"
  stage: experimental

---

# Fase BETA — clientes piloto voluntarios (2 semanas después)
name: sp-nueva-app
version: "0.2.0"
feature_flag:
  enabled: true
  keycloak_realm_attribute: "feature_sp_nueva_app"
  stage: beta

---

# Fase GA — sin feature flag, todos los tenants (2 semanas de beta sin incidentes)
name: sp-nueva-app
version: "0.3.0"
# Sin campo feature_flag → disponible para todos
```

---

### 7.3 Blue/Green para daemons soberanos

Los daemons soberanos (bKernel, SBOS Data Integration, SBOS AI Tools) son binarios systemd. Su proceso de actualización es fundamentalmente diferente al de las fichas K8s — no hay kubectl rollout ni Helm upgrade. Este proceso blue/green garantiza que la transición al nuevo binario es segura.

#### Preparación del nuevo binario

```bash
# El Release Plane distribuye el nuevo binario firmado con Ed25519
# Verificar la firma antes de continuar

# Descargar el nuevo binario
curl -Lo /opt/bos/bkernel.new \
  https://releases.skull.bo/v${NUEVA_VERSION}/bkernel-linux-amd64
curl -Lo /opt/bos/bkernel.new.sig \
  https://releases.skull.bo/v${NUEVA_VERSION}/bkernel-linux-amd64.sig

# Verificar firma Ed25519
openssl pkeyutl -verify \
  -pubin -inkey /etc/skull/release-plane-public.pem \
  -sigfile /opt/bos/bkernel.new.sig \
  -in /opt/bos/bkernel.new
# Esperado: "Signature Verified Successfully"
# Si falla: NO continuar — el binario puede estar comprometido
```

#### Proceso blue/green: observación en modo dry-run

```bash
# Paso 1: Lanzar el nuevo daemon en modo dry-run (observación sin escrituras)
# El nuevo bKernel se lanza como instancia alternativa con flag --dry-run
# procesa el WAL igual que el daemon activo pero NO escribe en ningún destino

/opt/bos/bkernel.new \
  --config /etc/bos/blibs/bkernel/bkernel.toml \
  --dry-run \
  --metrics-port 9101 \       # Puerto diferente al daemon activo (9100)
  --instance-name bkernel-new \
  &
BLUE_GREEN_PID=$!

echo "Nuevo bKernel en dry-run con PID $BLUE_GREEN_PID — observando 5 minutos"
sleep 300  # 5 minutos de observación
```

#### Criterios de swap: condiciones para considerar el nuevo binario como sano

```bash
# Verificar que el nuevo daemon es saludable durante el dry-run

# Métrica 1: lag WAL del nuevo daemon < 500ms
NEW_LAG=$(curl -s http://localhost:9101/metrics | grep bkernel_wal_lag_seconds | awk '{print $2}')
if (( $(echo "$NEW_LAG > 0.5" | bc -l) )); then
  echo "❌ FAIL: lag WAL del nuevo daemon ($NEW_LAG s) > 500ms — NO hacer swap"
  kill $BLUE_GREEN_PID
  exit 1
fi

# Métrica 2: cero errores en logs del nuevo daemon
ERRORS=$(journalctl --pid=$BLUE_GREEN_PID --since="-5m" | grep -c "ERROR")
if [ "$ERRORS" -gt 0 ]; then
  echo "❌ FAIL: $ERRORS errores en logs del nuevo daemon — NO hacer swap"
  kill $BLUE_GREEN_PID
  exit 1
fi

echo "✅ Nuevo daemon saludable — procediendo con el swap"
```

#### Swap atómico (< 30 segundos de interrupción)

```bash
# Paso 2: Guardar el daemon viejo como backup para rollback
cp /usr/local/bin/bkernel /opt/bos/bkernel.prev

# Paso 3: Detener el dry-run del nuevo daemon
kill $BLUE_GREEN_PID

# Paso 4: Swap atómico — el tiempo entre stop y start debe ser < 30 segundos
# El systemd service manager gestiona el reinicio

sudo systemctl stop bkernel
cp /opt/bos/bkernel.new /usr/local/bin/bkernel
chmod +x /usr/local/bin/bkernel
sudo systemctl start bkernel

# Verificar el swap
sudo systemctl status bkernel
sudo journalctl -u bkernel -n 10 | grep "version\|started"

echo "✅ Swap completado — verificar lag WAL en Grafana"
```

#### Rollback inmediato si el swap falla

```bash
# Si el nuevo daemon falla post-swap:
sudo systemctl stop bkernel
cp /opt/bos/bkernel.prev /usr/local/bin/bkernel
sudo systemctl start bkernel

echo "⚠️ Rollback ejecutado — daemon anterior restaurado"
sudo systemctl status bkernel
```

---

### 7.4 Estrategia de despliegue por canal del Release Plane

Esta sección complementa SBOS-024 §5 sin duplicar su contenido.

| Canal | Descripción | Fichas | Daemons soberanos |
|-------|-------------|--------|-------------------|
| **canary** | Early adopters SKULL (equipo interno) | Feature flags EXPERIMENTAL activos | Blue/green con dry-run de 24h |
| **early** | Clientes voluntarios (opt-in) | Feature flags BETA activos + fichas con 2 semanas en canary sin incidentes | Blue/green con dry-run de 6h |
| **stable** | Todos los clientes restantes | Sin feature flags (solo fichas GA) + fichas con 4 semanas en early | Blue/green con dry-run de 5min (validación rápida) |

**Criterio de graduación de un binario de daemon entre canales:**
- canary → early: 2 semanas sin alertas `bKernelDown` ni errores de protocolo WAL en el canal canary.
- early → stable: 4 semanas adicionales sin incidentes en el canal early.

---

## §12 (SBOS-024) — Runbook RK-014: Actualización Blue/Green de Daemon Soberano

**Activación:** nueva versión de bKernel, SBOS Data Integration o SBOS AI Tools disponible en Release Plane.
**Responsable:** DevOps Lead
**Tiempo estimado:** 30 minutos (5 min dry-run + 25 min swap + verificación)

```
[ ] Descargar y verificar firma Ed25519 del nuevo binario
[ ] Lanzar en modo --dry-run durante 5 minutos (canary/early) o validación rápida (stable)
[ ] Verificar criterios de salud: lag WAL < 500ms + 0 errores
[ ] Si criterios OK: ejecutar swap atómico (< 30 segundos)
[ ] Si criterios FAIL: abortar — investigar antes de reintentar
[ ] Post-swap: verificar lag WAL en Grafana < 500ms
[ ] Si post-swap falla: rollback con bkernel.prev en < 1 minuto
```

---

*SKULL · SBOS · SBOS-018-DEPLOY · v1.0 · Marzo 2026*
*Insertar §7 en SBOS-018-Standards y §12 en SBOS-024-Operations*
*Complementa: SBOS-024 §5 (rollout canary existente), SBOS-005 §10 (canales Release Plane)*
