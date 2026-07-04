# SBOS-005-001
## Especificación Técnica Interna del Daemon `bos` — Nivel de Código

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

**Código:** SBOS-005-001
**Estado:** NUEVO
**Clasificación:** Especificación de Desarrollo — Daemon IAM Installer
**Complementa:** SBOS-005-INSTALLER-v5_0.md (documento base del IAM Installer)
**Propósito:** Todo lo que un desarrollador necesita para codificar el daemon `bos` sin hacer preguntas.

---

## 1. Formato del `.sbos_state.json`

Este archivo es la fuente de verdad local del sistema. Solo `STATE_MANAGER` escribe en él. Cualquier otro módulo que necesite leer o mutar el estado lo hace a través de `STATE_MANAGER`.

### 1.1 Schema completo

```json
{
  "$schema": "sbos-state-v1",
  "version": "1.0",
  "updated_at": "2026-03-14T10:30:00Z",

  "system": {
    "installer_version": "0.9.3",
    "installer_channel": "canary",
    "os": "Ubuntu 24.04 LTS",
    "arch": "amd64",
    "hostname": "sbos-prod-01",
    "kubernetes_version": "1.31.2",
    "cluster_id": "uuid",
    "bootstrap_completed_at": "2026-03-14T09:00:00Z",
    "last_health_check": "2026-03-14T10:29:00Z",
    "last_reconcile": "2026-03-14T10:25:00Z"
  },

  "fichas": {
    "postgresql": {
      "status": "INSTALADA_OK",
      "version": "18.0",
      "server": "dataserver",
      "installed_at": "2026-03-14T09:12:00Z",
      "updated_at": "2026-03-14T09:12:00Z",
      "health": {
        "result": "ok",
        "last_check": "2026-03-14T10:29:00Z",
        "consecutive_failures": 0,
        "details": "All pods running, replication OK"
      },
      "hashes": {
        "manifest": "sha256:abc123...",
        "yaml_engine": "sha256:def456...",
        "task_catalog": "sha256:ghi789...",
        "resources": "sha256:jkl012..."
      },
      "execution_order": 100,
      "depends_on": ["sbos-bootstrap-platform"],
      "governance_category": 2
    },
    "keycloak": {
      "status": "INSTALADA_OK",
      "version": "26.1",
      "server": "identityserver",
      "installed_at": "2026-03-14T09:20:00Z",
      "updated_at": "2026-03-14T09:20:00Z",
      "health": { "result": "ok", "last_check": "2026-03-14T10:29:00Z", "consecutive_failures": 0 },
      "hashes": { "manifest": "sha256:...", "yaml_engine": "sha256:...", "task_catalog": "sha256:...", "resources": "sha256:..." },
      "execution_order": 130,
      "depends_on": ["postgresql", "vault"],
      "governance_category": 3
    },
    "mailserver": {
      "status": "NO_INSTALADA",
      "version": null,
      "server": "commsserver",
      "installed_at": null,
      "health": null,
      "hashes": null,
      "execution_order": 200,
      "depends_on": ["postgresql", "keycloak"],
      "governance_category": 1
    }
  },

  "products": {
    "bootstrap": {
      "status": "INSTALADO",
      "version": "1.0",
      "installed_at": "2026-03-14T09:48:00Z",
      "fichas": ["sbos-bootstrap-os", "sbos-bootstrap-k8s", "sbos-bootstrap-platform", "sbos-k8s-network-validator", "postgresql", "redis", "minio", "vault", "keycloak", "nginx", "kong", "linkerd", "kyverno", "prometheus", "grafana", "sbos-bootstrap-hardening"]
    },
    "mail": {
      "status": "NO_INSTALADO",
      "version": null,
      "installed_at": null,
      "fichas": []
    }
  },

  "deploy": {
    "deploy_id": "uuid",
    "seed_file": "/etc/bos/deploy/skull-empresa.deploy.yml",
    "tenant_name": "SKULL S.R.L.",
    "domain": "skull.io",
    "started_at": "2026-03-14T09:00:00Z",
    "completed_at": "2026-03-14T10:07:00Z",
    "products_requested": ["bootstrap", "mail", "erp"],
    "products_completed": ["bootstrap"],
    "products_pending": ["mail", "erp"]
  },

  "operations": {
    "active": null,
    "history": [
      {
        "operation_id": "uuid",
        "type": "install",
        "ficha_id": "postgresql",
        "status": "success",
        "started_at": "2026-03-14T09:12:00Z",
        "completed_at": "2026-03-14T09:14:30Z",
        "duration_ms": 150000,
        "admin_sub": "admin@skull.io",
        "steps_total": 12,
        "steps_completed": 12,
        "compensation_executed": false
      }
    ]
  },

  "release": {
    "current_version": "0.9.3",
    "prev_version": "0.9.2",
    "channel": "canary",
    "last_check": "2026-03-14T08:00:00Z",
    "next_check": "2026-03-14T14:00:00Z",
    "pending_stabilization": false,
    "stabilization_deadline": null
  }
}
```

### 1.2 Transiciones de estado válidas

`STATE_MANAGER` rechaza cualquier transición que no esté en esta tabla:

```
NO_INSTALADA     → INSTALANDO        (INSTALL_RUNNER inicia install)
INSTALANDO       → INSTALADA_OK      (INSTALL_RUNNER: todos los pasos OK)
INSTALANDO       → NO_INSTALADA      (INSTALL_RUNNER: compensación ejecutada)
INSTALADA_OK     → ACTUALIZANDO      (INSTALL_RUNNER inicia update)
INSTALADA_OK     → REPARANDO         (INSTALL_RUNNER inicia repair)
INSTALADA_OK     → DESINSTALANDO     (INSTALL_RUNNER inicia uninstall)
INSTALADA_OK     → ALERTA            (HEALTH_CHECKER: health check falla)
ALERTA           → INSTALADA_OK      (HEALTH_CHECKER: health check pasa)
ALERTA           → REPARANDO         (INSTALL_RUNNER inicia repair)
ACTUALIZANDO     → INSTALADA_OK      (INSTALL_RUNNER: update completo)
ACTUALIZANDO     → ALERTA            (INSTALL_RUNNER: update falló, rollback no posible)
ACTUALIZANDO     → INSTALADA_OK      (INSTALL_RUNNER: update falló, rollback exitoso → versión anterior)
REPARANDO        → INSTALADA_OK      (INSTALL_RUNNER: repair exitoso)
REPARANDO        → ALERTA            (INSTALL_RUNNER: repair falló)
DESINSTALANDO    → NO_INSTALADA      (INSTALL_RUNNER: uninstall completo)
DESINSTALANDO    → INSTALADA_OK      (INSTALL_RUNNER: uninstall falló, compensación restauró)
BLOQUEADA        → NO_INSTALADA      (DEPENDENCY_RESOLVER: dependencias ahora satisfechas)
NO_INSTALADA     → BLOQUEADA         (DEPENDENCY_RESOLVER: dependencias ya no satisfechas)
```

Cualquier transición fuera de esta tabla es un **bug**. `STATE_MANAGER` la rechaza, logea un error crítico, y emite un evento `system_alert` con severidad `critical`.

### 1.3 Concurrencia y locks

```
STATE_MANAGER usa fcntl.flock(LOCK_EX) en .sbos_state.json
  │
  ├── Lock adquirido → lee, muta, escribe, libera
  ├── Lock no disponible (otro módulo escribiendo) → espera hasta 5 segundos
  └── Timeout → error "state_lock_timeout", la operación falla
  
Solo UNA operación puede estar activa a la vez (operations.active != null).
Si un módulo intenta iniciar una operación mientras hay una activa,
STATE_MANAGER rechaza con "operation_in_progress".
```

---

## 2. Protocolo `bosctl` ↔ Daemon

### 2.1 Mecanismo de comunicación

`bosctl` se comunica con el daemon `bos` mediante **HTTP sobre Unix socket**.

```
Socket: /run/bos/bos.sock
Protocolo: HTTP/1.1 sobre Unix domain socket
Autenticación: El socket tiene permisos 0660, grupo bosagent.
               Solo root y usuarios del grupo bosagent pueden conectar.
               No se necesita JWT (la autenticación es a nivel de OS).
```

Esto es diferente del Core UI, que se conecta por TCP con JWT de Keycloak. `bosctl` es local y privilegiado — no necesita autenticación de red.

### 2.2 Endpoints internos (solo bosctl, no expuestos por TCP)

Estos endpoints solo son accesibles por Unix socket, no por la API REST TCP que consume el Core UI:

```
GET  /internal/state              → dump completo de .sbos_state.json
GET  /internal/state/fichas       → solo la sección fichas
GET  /internal/state/products     → solo la sección products
GET  /internal/config             → configuración actual de bos.toml
POST /internal/reconcile          → forzar reconciliación inmediata
POST /internal/health-check       → forzar health check de todas las fichas
GET  /internal/logs/{ficha_id}    → últimas N líneas de log de una ficha
GET  /internal/version            → versión del daemon + uptime + estado
```

### 2.3 Comandos de bosctl y su mapeo a endpoints

```bash
# ─── Fichas ───
bosctl status                    → GET /api/dashboard
bosctl fichas                    → GET /api/fichas
bosctl ficha <id>                → GET /api/fichas/{id}
bosctl install <id>              → POST /api/fichas/{id}/install {"confirmed":true}
bosctl install <id> --dry-run    → POST /api/fichas/{id}/probe
bosctl repair <id>               → POST /api/fichas/{id}/repair {"confirmed":true}
bosctl update <id>               → POST /api/fichas/{id}/update {"confirmed":true}
bosctl uninstall <id>            → POST /api/fichas/{id}/uninstall (requiere --confirm=DESINSTALAR-<ID>)
bosctl logs <id>                 → GET /internal/logs/{id}

# ─── Productos ───
bosctl product list              → GET /api/products
bosctl product install <nombre>  → POST /api/products/{nombre}/install
bosctl product status <nombre>   → GET /api/products/{nombre}
bosctl product verify <nombre>   → POST /api/products/{nombre}/verify

# ─── Deploy ───
bosctl deploy <archivo.yml>      → POST /api/deploy {"seed_file":"<path>"}
bosctl deploy status             → GET /api/deploy/status

# ─── Sistema ───
bosctl health                    → GET /api/health
bosctl health --wait-stable=60   → GET /api/health (polling cada 5s hasta stable o timeout)
bosctl version                   → GET /internal/version
bosctl state                     → GET /internal/state
bosctl reconcile                 → POST /internal/reconcile
bosctl config                    → GET /internal/config
```

### 2.4 Formato de output del CLI

```bash
# bosctl status (tabla compacta)
SBOS IAM Installer v0.9.3 · canary · uptime 6h 32m
Cluster: sbos-prod-01 · K8s 1.31.2 · 1 nodo · OK

FICHAS (22 instaladas / 3 en alerta / 96 totales)
────────────────────────────────────────────────────
ID               VERSIÓN  ESTADO        HEALTH  SERVER
postgresql       18.0     INSTALADA_OK  ok      dataserver
keycloak         26.1     INSTALADA_OK  ok      identityserver
mailserver       3.2.1    ALERTA        error   commsserver

# bosctl install postgresql (progreso en tiempo real)
[bos] Instalando postgresql v18.0...
[✓] 1/12  Verificar dependencias                    0.1s
[✓] 2/12  Crear namespace sbos-data                 0.2s
[⟳] 3/12  Crear PVC 500GB...                        (12s)
[✓] 3/12  PVC creado y bound                        14.3s
...
[✓] 12/12 Health check: todos los pods running      2.1s

═══ postgresql instalado en 2m 30s ═══
```

### 2.5 Exit codes

```
0   → operación exitosa
1   → error genérico
2   → error de validación (parámetros incorrectos)
3   → ficha no encontrada
4   → operación rechazada (ya hay una activa)
5   → dependencias no satisfechas
6   → daemon no disponible (socket no existe o no responde)
7   → timeout (operación no completó en tiempo esperado)
8   → error de gobernanza (requiere aprobación dual)
10  → error interno del daemon
```

---

## 3. Sagas de Instalación con Compensación

Cada operación del `INSTALL_RUNNER` es una **Saga**: una secuencia de pasos donde cada paso tiene una acción de compensación que se ejecuta si un paso posterior falla. Esto garantiza que el sistema nunca quede en un estado inconsistente.

### 3.1 Saga: Install

```
Paso 1: DEPENDENCY_RESOLVER.verify_all_satisfied(ficha_id)
  Compensación: (ninguna — es una lectura)
  Falla → ABORT (no se ejecuta nada)

Paso 2: STATE_MANAGER.transition(ficha_id, INSTALANDO)
  Compensación: STATE_MANAGER.transition(ficha_id, NO_INSTALADA)

Paso 3: YAML_ENGINE.execute_phase("pre_install", ficha_id)
  Compensación: (las pre_install deben ser idempotentes y no destructivas)

Paso 4: YAML_ENGINE.execute_phase("install", ficha_id)
  Compensación: YAML_ENGINE.execute_phase("uninstall", ficha_id)
  (si la ficha no tiene fase uninstall, ejecuta cleanup genérico:
   delete namespace, delete PVCs, delete secrets)

Paso 5: YAML_ENGINE.execute_phase("post_install", ficha_id)
  Compensación: (las post_install son verificaciones, no crean recursos)

Paso 6: HEALTH_CHECKER.verify(ficha_id)
  Compensación: (es una lectura)
  Falla → la ficha queda en ALERTA (no se compensa — los recursos existen pero no están sanos)

Paso 7: STATE_MANAGER.transition(ficha_id, INSTALADA_OK)
  (solo si paso 6 fue OK)
  STATE_MANAGER.register_hashes(ficha_id, PLUGIN_LOADER.compute_hashes(ficha_id))

SI FALLA EN PASO 4:
  → Ejecutar compensación del paso 4 (uninstall/cleanup)
  → Ejecutar compensación del paso 2 (volver a NO_INSTALADA)
  → Emitir evento "operation_done" con result="failed"
  → Emitir evento "step_error" con CAUSA + SOLUCIÓN
```

### 3.2 Saga: Update

```
Paso 1: STATE_MANAGER.transition(ficha_id, ACTUALIZANDO)
  Compensación: STATE_MANAGER.transition(ficha_id, INSTALADA_OK) [versión anterior]

Paso 2: PLUGIN_LOADER.backup_current_resources(ficha_id)
  → Copia resources/ actual a resources.prev/
  Compensación: PLUGIN_LOADER.restore_resources(ficha_id)

Paso 3: YAML_ENGINE.execute_phase("update", ficha_id)
  Compensación: YAML_ENGINE.execute_phase("rollback", ficha_id)
  (si no hay fase rollback, restaurar resources.prev + re-ejecutar install)

Paso 4: HEALTH_CHECKER.verify(ficha_id)
  Falla → ejecutar compensación del paso 3 (rollback)

Paso 5: STATE_MANAGER.transition(ficha_id, INSTALADA_OK)
  STATE_MANAGER.register_hashes(ficha_id, PLUGIN_LOADER.compute_hashes(ficha_id))
```

### 3.3 Saga: Repair

```
Paso 1: STATE_MANAGER.transition(ficha_id, REPARANDO)
  Compensación: STATE_MANAGER.transition(ficha_id, ALERTA)

Paso 2: SI ficha.repair.diagnosis_first == true:
         YAML_ENGINE.execute_phase("repair.diagnosis", ficha_id)
         → Genera reporte de diagnóstico
         → NO ejecuta acciones correctivas todavía

Paso 3: YAML_ENGINE.execute_phase("repair", ficha_id)
  Compensación: (ninguna — repair es "best effort")

Paso 4: HEALTH_CHECKER.verify(ficha_id)
  OK → STATE_MANAGER.transition(ficha_id, INSTALADA_OK)
  FAIL → STATE_MANAGER.transition(ficha_id, ALERTA) + notificar admin
```

### 3.4 Saga: Uninstall

```
Paso 0: GOVERNANCE check
  SI governance_category == 3:
    → Requiere aprobación dual (segundo admin diferente)
    → STATE_MANAGER.set_pending_governance(operation_id, awaiting_approval)
    → ABORT hasta que llegue la segunda aprobación (timeout: 60 minutos)

Paso 1: STATE_MANAGER.transition(ficha_id, DESINSTALANDO)
  Compensación: STATE_MANAGER.transition(ficha_id, INSTALADA_OK)

Paso 2: DEPENDENCY_RESOLVER.verify_no_dependents(ficha_id)
  → Verificar que ninguna otra ficha INSTALADA dependa de esta
  Falla → ABORT con lista de fichas dependientes

Paso 3: YAML_ENGINE.execute_phase("uninstall", ficha_id)
  → Si no tiene fase uninstall: cleanup genérico (delete namespace, PVCs, secrets)
  Compensación: YAML_ENGINE.execute_phase("install", ficha_id) [reinstalar]

Paso 4: STATE_MANAGER.transition(ficha_id, NO_INSTALADA)
  STATE_MANAGER.clear_hashes(ficha_id)
```

### 3.5 Timeouts por Saga

```
install:    30 minutos (fichas grandes como postgresql pueden tardar)
update:     15 minutos
repair:     10 minutos
uninstall:  10 minutos
deploy:     120 minutos (puede instalar múltiples productos)

Si el timeout se alcanza:
  → Ejecutar compensación desde el último paso completado hacia atrás
  → Emitir evento "operation_timeout"
  → STATE_MANAGER registra el timeout en el historial
```

---

## 4. Especificación Interna de Cada Módulo de Dominio

### 4.1 STATE_MANAGER

```
Responsabilidad: Árbitro exclusivo del estado persistente.

Datos que gestiona:
  .sbos_state.json (schema en §1)

Funciones públicas:
  get_state() → StateSnapshot
  get_ficha_status(ficha_id) → FichaStatus
  transition(ficha_id, new_status) → Result<void, TransitionError>
  register_hashes(ficha_id, hashes) → void
  clear_hashes(ficha_id) → void
  set_operation_active(operation) → Result<void, OperationInProgressError>
  complete_operation(operation_id, result) → void
  register_product(product_id, product_state) → void
  register_deploy(deploy_state) → void
  get_operations_history(filters) → Vec<Operation>

Reglas internas:
  - Toda escritura usa fcntl.flock(LOCK_EX) con timeout 5s
  - Toda transición se valida contra la tabla de §1.2
  - Toda mutación incrementa updated_at
  - Toda mutación emite un evento via SIGNAL_BUS
  - Solo UNA operación activa a la vez
  
Errores que puede emitir:
  TransitionError { from, to, reason: "invalid_transition" }
  StateLockTimeout { waited_ms: 5000 }
  OperationInProgressError { active_operation_id }
```

### 4.2 DEPENDENCY_RESOLVER

```
Responsabilidad: Grafo DAG de dependencias entre fichas.

Datos que consume:
  Todos los manifest.yml de fichas cargadas por PLUGIN_LOADER
  Estado actual de cada ficha via STATE_MANAGER

Funciones públicas:
  build_graph(fichas: Vec<FichaManifest>) → DAG
  topological_sort(dag: DAG) → Vec<FichaId>
  is_unblocked(ficha_id) → bool
  get_blocked_by(ficha_id) → Vec<FichaId>
  verify_all_satisfied(ficha_id) → Result<void, DependencyError>
  verify_no_dependents(ficha_id) → Result<void, DependentError>
  get_install_order(ficha_ids: Vec<FichaId>) → Vec<FichaId>

Algoritmo:
  1. Lee depends_on de cada manifest.yml
  2. Construye grafo dirigido (ficha → dependencia)
  3. Detecta ciclos → error fatal si encuentra uno
  4. Calcula orden topológico (Kahn's algorithm)
  5. Dentro del mismo nivel topológico, ordena por execution_order

Errores que puede emitir:
  DependencyError { ficha_id, missing: Vec<FichaId> }
  DependentError { ficha_id, dependents: Vec<FichaId> }
  CyclicDependencyError { cycle: Vec<FichaId> }
```

### 4.3 HEALTH_CHECKER

```
Responsabilidad: Evaluador de salud de fichas instaladas.

Datos que consume:
  health.check_command de cada manifest.yml
  Métricas de Prometheus (para fichas con health.prometheus_query)

Funciones públicas:
  check(ficha_id) → HealthResult { result: ok|degraded|error|pending, details: String }
  check_all() → Vec<(FichaId, HealthResult)>
  verify(ficha_id) → bool  (usado por Sagas: true si ok, false si error)

Criterios de clasificación:
  ok        → check_command exit 0 Y pods Running Y probes passing
  degraded  → check_command exit 0 PERO pods con restarts > 3 en última hora
  error     → check_command exit != 0 O pods CrashLoopBackOff O probes failing
  pending   → ficha en estado transitorio (INSTALANDO, ACTUALIZANDO, etc.)

Reglas:
  - Si consecutive_failures >= 3 → STATE_MANAGER.transition(ficha_id, ALERTA)
  - Si ficha en ALERTA y check pasa → STATE_MANAGER.transition(ficha_id, INSTALADA_OK)
  - Si ficha tiene auto_repair: true Y check falla:
    → INSTALL_RUNNER.repair(ficha_id) automáticamente (max 1 intento por ciclo)
```

### 4.4 FICHA_LINTER

```
Responsabilidad: Validar que una ficha cumple el contrato SBOS.

Datos que consume:
  Archivos de la ficha: manifest.yml, yaml_engine.yml, task_catalog.sh, resources/

Funciones públicas:
  lint(ficha_path) → LintResult { valid: bool, errors: Vec<LintError>, warnings: Vec<LintWarning> }
  lint_all(servers_path) → Vec<(FichaId, LintResult)>

Reglas de validación (obligatorias — lint falla si no cumple):
  manifest.yml:
    - Campos requeridos: name, version, server, execution_order, workload
    - workload.type ∈ {bash, kubernetes}
    - Si workload.type == kubernetes: workload.namespace requerido
    - governance_category ∈ {1, 2, 3}
    - health.check_command presente y no vacío
  
  yaml_engine.yml:
    - Al menos una fase: install
    - Toda tarea referenciada debe existir en task_catalog.sh O en 00_TASK_CATALOG_SBOS.sh
    - Si tiene fase repair: diagnosis_first debe ser bool
  
  task_catalog.sh:
    - Toda función termina con export -f (Principio P6)
    - No contiene referencias a apps concretas si es task_catalog global
    - Usa señales __SBOS__STEP_* para comunicar progreso
  
  resources/:
    - Todos los archivos declarados en manifest.yml existen
    - Checksums SHA-256 calculables

Warnings (no bloquean pero se reportan):
  - Ficha sin fase repair (recomendada)
  - Ficha sin fase update (recomendada para governance 2+)
  - execution_order duplicado con otra ficha del mismo server
```

### 4.5 FICHA_PROBE

```
Responsabilidad: Dry-run completo — predecir qué haría una operación sin ejecutarla.

Funciones públicas:
  probe_install(ficha_id) → ProbeResult
  probe_update(ficha_id) → ProbeResult
  probe_uninstall(ficha_id) → ProbeResult

ProbeResult:
  {
    ficha_id: string,
    operation: "install" | "update" | "uninstall",
    feasible: bool,
    blockers: Vec<String>,     // razones por las que no se puede ejecutar
    would_execute: Vec<Step>,  // lista de pasos que se ejecutarían
    estimated_duration_ms: u64,
    resources_required: { cpu_millicores, ram_mb, disk_gb },
    resources_available: { cpu_millicores, ram_mb, disk_gb },
    dependencies_satisfied: bool
  }

Mecanismo:
  1. Lee yaml_engine.yml de la ficha
  2. Recorre cada fase sin ejecutar los comandos
  3. Evalúa las condiciones de cada tarea
  4. Consulta recursos disponibles en el cluster (kubectl top nodes)
  5. Consulta DEPENDENCY_RESOLVER para dependencias
  6. Genera el reporte
```

### 4.6 GROWTH_DETECTOR

```
Responsabilidad: Detectar cuándo el cluster necesita más recursos.

Datos que consume:
  Métricas de Prometheus vía HTTP API
  Umbrales configurados en bos.toml

Funciones públicas:
  evaluate() → GrowthReport
  get_saturation() → ClusterSaturation

Umbrales (configurables en bos.toml):
  growth.cpu_threshold_percent: 80     # sugerir expansión cuando CPU > 80%
  growth.ram_threshold_percent: 85     # sugerir expansión cuando RAM > 85%
  growth.disk_threshold_percent: 75    # sugerir expansión cuando disco > 75%
  growth.evaluation_window_minutes: 30 # evaluar sobre los últimos 30 min

GrowthReport:
  {
    evaluation_at: datetime,
    saturated: bool,
    metrics: { cpu_percent, ram_percent, disk_percent },
    recommendation: "none" | "add_node" | "increase_resources",
    suggested_action: string,  // "Agregar nodo con al menos 4 vCPU y 8GB RAM"
    fichas_heaviest: Vec<{ ficha_id, cpu_percent, ram_mb }>
  }
```

---

## 5. Catálogo Completo de Señales `__SBOS__`

Las señales son la interfaz entre los scripts Bash (task_catalog.sh) y el daemon Go/Python. Se emiten por stdout y el `YAML_ENGINE` las parsea línea a línea.

### 5.1 Señales de progreso

```bash
__SBOS__STEP_START__    <descripción libre>
__SBOS__STEP_OK__       <descripción libre>
__SBOS__STEP_ERROR__    CAUSA: <texto>
                        SOLUCIÓN: <texto>
                        COMANDO: <comando CLI sugerido>
__SBOS__STEP_SKIP__     <razón por la que se saltó>
__SBOS__STEP_PROGRESS__ <N>/<TOTAL> <descripción>
```

### 5.2 Señales de finalización

```bash
__SBOS__DONE__OK__                     # fase completó exitosamente
__SBOS__DONE__ERROR__                  # fase falló
__SBOS__DONE__ERROR__COMPENSABLE__     # fase falló pero se puede compensar
__SBOS__DONE__ERROR__FATAL__           # fase falló, NO se puede compensar, requiere intervención manual
```

### 5.3 Señales de metadata

```bash
__SBOS__META__VERSION__     <versión de la app instalada>
__SBOS__META__PORT__        <puerto en el que escucha>
__SBOS__META__NAMESPACE__   <namespace K8s>
__SBOS__META__POD__         <nombre del pod>
__SBOS__META__PVC__         <nombre del PVC creado>
__SBOS__META__SECRET__      <nombre del secret creado>
__SBOS__META__CONFIG__      <nombre del ConfigMap creado>
```

El `YAML_ENGINE` captura estas señales de metadata y las pasa a `STATE_MANAGER` para registrar qué recursos creó cada ficha — esto permite al cleanup genérico saber qué eliminar en caso de compensación.

### 5.4 Reglas del protocolo

1. Toda línea que NO empiece con `__SBOS__` se trata como log informativo y se pasa a `PROGRESS_EMITTER` como evento `log_line`
2. `__SBOS__STEP_ERROR__` es multilinea: las líneas siguientes hasta la próxima señal `__SBOS__` pertenecen al error
3. Las señales se emiten a stdout. stderr se captura como log de diagnóstico pero NO se parsea como señal
4. El daemon NUNCA espera más de 30 minutos por una señal (timeout configurable en bos.toml)

---

## 6. Ficha de Referencia Completa

Esta es una ficha real con TODOS los campos posibles del contrato SBOS:

### 6.1 manifest.yml (todos los campos)

```yaml
# /etc/bos/blibs/servers/dataserver/postgresql/manifest.yml
name: "postgresql"
version: "18.0"
description: "Motor de persistencia principal del SBOS"
server: "dataserver"

execution_order: 100
governance_category: 2    # 1=normal, 2=requiere confirmación, 3=requiere aprobación dual

workload:
  type: "kubernetes"       # "bash" | "kubernetes"
  namespace: "sbos-data"
  workload_type: "StatefulSet"  # StatefulSet | Deployment | DaemonSet | Job
  replicas: 1

requirements:
  depends_on:
    - type: "ficha"
      target: "sbos-bootstrap-platform"
      state: "installed"
  resources:
    cpu: "500m"
    memory: "2Gi"
    storage: "50Gi"

health:
  check_command: "pg_isready -h localhost -p 5432"
  check_interval_seconds: 60
  consecutive_failures_threshold: 3
  auto_repair: false
  prometheus_query: "pg_up == 1"

criticality: true          # false = ficha opcional, no bloquea nada
auto_update: false          # true = RELEASE_MANAGER aplica updates sin confirmación
tags: ["database", "core", "stateful"]
```

### 6.2 yaml_engine.yml (todas las fases)

```yaml
# /etc/bos/blibs/servers/dataserver/postgresql/yaml_engine.yml
phases:

  pre_install:
    tasks:
      - task: "validate_namespace_exists"
        params:
          namespace: "sbos-data"
      - task: "validate_storageclass_default"
      - task: "validate_resources_available"
        params:
          cpu: "500m"
          memory: "2Gi"

  install:
    tasks:
      - task: "pg_create_namespace"
      - task: "pg_create_secrets"
      - task: "pg_create_configmap"
      - task: "pg_deploy_statefulset"
      - task: "wait_pod_ready"
        params:
          namespace: "sbos-data"
          pod_selector: "app=postgresql"
          timeout_seconds: 300
      - task: "pg_init_databases"
        params:
          databases: ["keycloak_db", "tryton_db", "kong_db", "grafana_db"]
      - task: "pg_configure_patroni"
      - task: "pg_configure_pgbouncer"
      - task: "pg_configure_wal_archiving"

  post_install:
    tasks:
      - task: "wait_pod_healthy"
        params:
          namespace: "sbos-data"
          pod_selector: "app=postgresql"
      - task: "verify_service_responds"
        params:
          service: "postgresql.sbos-data.svc"
          port: 5432
      - task: "pg_verify_replication"

  repair:
    diagnosis_first: true
    tasks:
      - task: "pg_diagnose_cluster"
        on_failure: "continue"
      - task: "pg_diagnose_replication"
        on_failure: "continue"
      - task: "pg_repair_patroni"
        on_failure: "abort"
      - task: "pg_repair_pgbouncer"
        on_failure: "continue"

  update:
    tasks:
      - task: "pg_backup_pre_update"
      - task: "pg_rolling_update"
        update_strategy: "rolling"
      - task: "pg_verify_post_update"
    rollback:
      tasks:
        - task: "pg_restore_from_backup"

  uninstall:
    tasks:
      - task: "pg_backup_final"
      - task: "pg_delete_statefulset"
      - task: "pg_delete_pvcs"
        confirm: true
      - task: "pg_delete_secrets"
      - task: "pg_delete_namespace"
```

### 6.3 task_catalog.sh (estructura)

```bash
#!/usr/bin/env bash
# /etc/bos/blibs/servers/dataserver/postgresql/task_catalog.sh
# Tareas ESPECÍFICAS de PostgreSQL — solo este archivo las conoce

pg_create_namespace() {
    __SBOS__STEP_START__    Crear namespace sbos-data
    kubectl create namespace sbos-data --dry-run=client -o yaml | kubectl apply -f -
    __SBOS__STEP_OK__       Namespace sbos-data listo
    __SBOS__META__NAMESPACE__   sbos-data
}
export -f pg_create_namespace

pg_create_secrets() {
    __SBOS__STEP_START__    Generar credenciales PostgreSQL
    local pg_pass
    pg_pass=$(openssl rand -base64 32)
    kubectl create secret generic postgresql-credentials \
        --namespace=sbos-data \
        --from-literal=POSTGRES_PASSWORD="$pg_pass" \
        --dry-run=client -o yaml | kubectl apply -f -
    __SBOS__STEP_OK__       Credenciales almacenadas en secret postgresql-credentials
    __SBOS__META__SECRET__  postgresql-credentials
}
export -f pg_create_secrets

pg_deploy_statefulset() {
    __SBOS__STEP_START__    Desplegar StatefulSet PostgreSQL
    sbos_k8s_core "apply" "resources/postgresql-statefulset.yaml"
    __SBOS__STEP_OK__       StatefulSet postgresql desplegado
    __SBOS__META__POD__     postgresql-0
}
export -f pg_deploy_statefulset

pg_init_databases() {
    local databases=("$@")
    __SBOS__STEP_START__    Crear bases de datos iniciales
    for db in "${databases[@]}"; do
        kubectl exec -n sbos-data postgresql-0 -- \
            psql -U postgres -c "CREATE DATABASE ${db} WITH OWNER postgres;" 2>/dev/null || true
        echo "  → Base de datos ${db} lista"
    done
    __SBOS__STEP_OK__       ${#databases[@]} bases de datos creadas
}
export -f pg_init_databases

# ... (más funciones, cada una con export -f)
```

---

## 7. Endpoints de Productos y Deploy

Estos endpoints complementan los de SBOS-007 §11 para cubrir las operaciones de Nivel 2 (Productos) y Nivel 3 (Deploy):

### 7.1 Productos

```
GET  /api/products
  → Lista todos los productos disponibles en products/ con su estado

GET  /api/products/{product_id}
  → Detalle de un producto: fichas participantes, requirements, estado de cada ficha

POST /api/products/{product_id}/install
  Request: { "confirmed": true, "params": { "DOMAIN": "skull.io", ... } }
  Response 202: { "operation_id": "uuid", "websocket_url": "/ws/operations/uuid" }

POST /api/products/{product_id}/verify
  → Re-ejecuta las verificaciones del producto sin instalar nada
  Response 200: { "checks": [{ "name": "smtp_send", "result": "pass" }, ...] }
```

### 7.2 Deploy

```
POST /api/deploy
  Request: { "seed_file": "/path/to/deploy.yml" }
  → Valida el seed file, genera llaves, inicia la secuencia de productos
  Response 202: { "deploy_id": "uuid", "websocket_url": "/ws/deploy/uuid" }

GET  /api/deploy/status
  → Estado del deploy activo (si hay uno)
  Response 200: {
    "deploy_id": "uuid",
    "tenant_name": "SKULL S.R.L.",
    "products_total": 3,
    "products_completed": 1,
    "current_product": "mail",
    "current_ficha": "mailserver",
    "progress_percent": 45,
    "started_at": "...",
    "estimated_remaining_minutes": 32
  }
```

---

## 8. Configuración del Daemon (bos.toml)

```toml
# /etc/bos/bos.toml

[daemon]
listen_socket = "/run/bos/bos.sock"       # Unix socket para bosctl
listen_tcp = "0.0.0.0:9443"               # TCP para Core UI (HTTPS)
tls_cert = "/etc/bos/tls/server.crt"
tls_key = "/etc/bos/tls/server.key"
log_level = "info"                         # debug | info | warn | error
log_file = "/var/log/bos/bos.log"

[state]
state_file = "/etc/bos/.sbos_state.json"
lock_timeout_seconds = 5
events_dir = "/etc/bos/"                   # directorio para .jsonl

[health]
check_interval_seconds = 60
consecutive_failures_threshold = 3

[reconcile]
interval_seconds = 300                     # cada 5 minutos
drift_check = true

[release]
server_url = "https://releases.skull.io"
check_interval_hours = 6
channel = "canary"                         # canary | early | stable
stabilization_window_seconds = 300         # 5 minutos de observación post-update
ed25519_public_key = "base64:..."

[growth]
cpu_threshold_percent = 80
ram_threshold_percent = 85
disk_threshold_percent = 75
evaluation_window_minutes = 30

[sagas]
install_timeout_minutes = 30
update_timeout_minutes = 15
repair_timeout_minutes = 10
uninstall_timeout_minutes = 10
deploy_timeout_minutes = 120

[ficha_defaults]
servers_path = "/etc/bos/blibs/servers"
products_path = "/etc/bos/products"
```

---

## 9. Registro de Cambios

### v1.0 — Marzo 2026

Documento nuevo. Especificación técnica interna del daemon `bos` que cubre: schema completo de `.sbos_state.json` con transiciones de estado, protocolo bosctl↔daemon vía Unix socket, 4 Sagas de instalación con compensación, especificación de 6 módulos de dominio con funciones públicas y reglas, catálogo completo de señales `__SBOS__`, ficha de referencia con todos los campos posibles (manifest.yml + yaml_engine.yml + task_catalog.sh), endpoints de Productos y Deploy, y formato de bos.toml.

---

*SKULL · SBOS · SBOS-005-001 · Anexo 001 · v1.0 · Marzo 2026*
*Complementa: SBOS-005-INSTALLER-v5_0.md · SBOS-006-FICHA-v4_0.md · SBOS-007-COREUI-v4_0.md*
