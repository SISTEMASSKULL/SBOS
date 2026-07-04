# SBOS-018-DAEMON-BOS
## SBOS IAM Installer: Infrastructure Provisioning & Lifecycle Orchestrator
## Estándar HUMAN-DOC
### SKULL · SBOS · V8 · Mayo 2026

---

## 1. Identidad del Daemon

| Campo | Valor |
|---|---|
| Nombre conceptual | SBOS IAM Installer: Infrastructure Provisioning & Lifecycle Orchestrator |
| Daemon | `bos` |
| Servicio systemd | `bos.service` |
| Lenguaje daemon | Go 1.22+ (binario estático, CGO_ENABLED=0) |
| Módulos de fichas | Python 3.11+ + Cython |
| Scripts OS | Bash 5.x |
| Unidad declarativa | Ficha |
| Directorio de fichas | `/etc/bos/blibs/servers/<servidor>/<nombre_ficha>/` |
| Archivos por ficha | `manifest.yml`, `task_catalog.sh`, `yaml_engine.yml`, `resources/` |
| CLI | `bosctl` (binario Go) |
| Socket | `/run/bos/bos.sock` (Unix domain socket para bosctl) |
| TCP | `0.0.0.0:9443` (HTTPS para Core UI) |
| Config | `/etc/bos/bos.toml` |
| Estado | `/etc/bos/.sbos_state.json` (solo STATE_MANAGER escribe) |

**Decisión de arquitectura definitiva:** El `task_catalog.sh` de cada ficha es y permanecerá Bash (.sh). No migrará a binario compilado. Fundamento: las fichas generan errores de configuración en producción que requieren corrección inmediata (30 segundos editando Bash vs minutos recompilando). El daemon principal (`bos`) sí es binario Go compilado — es él quien consume, ejecuta y desacopla los task_catalog.sh.

---

## 2. Función y Posición en el Ecosistema

### Lo que es

Control plane soberano del SBOS. Motor de aprovisionamiento y gestión del ciclo de vida de infraestructura soberana. Transforma Ubuntu virgen en cluster K8s con stack SBOS completo (~48 min). Después se convierte en daemon residente permanente que observa, administra y repara la salud del sistema en tres niveles: SO → K8s → Fichas.

Implementa el patrón control plane con reconciliación continua. Adicionalmente gestiona una flota de instalaciones a través del SKULL Release Plane, manteniendo cadena de confianza criptográfica (Ed25519 + SHA-256) desde desarrollo hasta producción de cada cliente.

### Instalación (ADR-044)

La instalación se distribuye como un **repositorio Git autocontenido**. Un solo comando:

```bash
git clone https://github.com/SISTEMASSKULL/bos-install.git && cd bos-install
sudo ./bin/bosctl setup --mode=prod --seed ./seed-skull.yml
```

El repositorio contiene binarios precompilados (`CGO_ENABLED=0`), scripts del motor
Bash (`core/`), 22 fichas declarativas (`servers/`), y manifiestos CNI offline
(`resources/calico-v3.32.0.yaml`). kubeadm, kubectl y containerd son prerrequisitos
del sistema operativo (como PHP y Composer para Laravel), no parte del producto.

**Decisión completa:** ADR-044 — Repositorio de Instalación Autocontenido.

### Lo que hace permanentemente

- Mantiene estado deseado (fichas) alineado con estado actual (cluster)
- Detecta drift en configuraciones, versiones, estados de pods
- Responde a instrucciones del administrador vía Core UI y bosctl
- Descubre fichas nuevas en `servers/` sin reiniciarse
- Gestiona crecimiento horizontal del cluster
- Se conecta al SKULL Release Plane para actualizaciones (pull-only)
- Revierte automáticamente si una actualización del daemon falla (watchdog)

### Lo que NO hace

- No toma decisiones destructivas sin confirmación humana explícita
- No modifica código de fichas — solo las ejecuta
- No mantiene estado fuera de `.sbos_state.json`
- No llama a `kubectl` excepto vía `sbos_k8s_core()`
- No envía datos del cliente al SKULL Release Plane
- No acepta conexiones entrantes del Release Plane — toda comunicación es pull (P15)
- No puede auto-eliminarse (invariante de seguridad)
- No modifica datos dentro de las bases de datos (jurisdicción del bKernel)

---

## 3. Tres Niveles de Operación

| Nivel | Qué es | Comando | Especificación |
|---|---|---|---|
| Ficha | Unidad atómica (postgresql, keycloak, roundcube) | `bosctl install <ficha>` | SBOS-006 |
| Producto | Manifiesto que agrupa fichas + configuraciones | `bosctl product install <producto>` | SBOS-032 |
| Deploy | Productos + datos del cliente (seed file) | `bosctl deploy <archivo.yml>` | SBOS-033 |

---

## 4. Arquitectura de Tres Planos

```
┌────────────────────────────────────────────────────────────────────────┐
│  PLANO 1 — SKULL RELEASE PLANE (infraestructura SKULL)                 │
│                                                                         │
│  SKULL Release Server                                                   │
│    /api/v1/releases/latest      ← versión actual + changelog           │
│    /api/v1/fichas/catalog       ← catálogo oficial de fichas           │
│    /api/v1/rollout/wave/<canal> ← versión para este canal              │
│    /dist/iam-installer-<arch>   ← binario Go compilado                 │
│    /dist/fichas/<id>/<ver>/     ← fichas empaquetadas                  │
│    /dist/checksums.sha256       ← hashes SHA-256                       │
│    /dist/checksums.sha256.sig   ← firma Ed25519 de los hashes          │
│                                                                         │
│  Entorno Dev (Windows+WSL) · Pipeline CI/CD · SKULL Admin Fleet Dash   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │  HTTPS · Solo descarga (pull-only)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│  PLANO 2 — IAM INSTALLER (host Ubuntu del cliente)                     │
│                                                                         │
│  IAM INSTALLER DAEMON (systemd — siempre activo)                       │
│    Core SP-01 (4 archivos Bash) + Backend Python (16 módulos)          │
│    + Core UI (Flutter pod K8s)                                         │
│                                                                         │
│  .sbos_state.json · servers/ · /opt/bos/ · iam-installer.prev          │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │  kubectl apply vía sbos_k8s_core()
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│  PLANO 3 — KUBERNETES CLUSTER (plano de ejecución del cliente)         │
│  14 namespaces · 110+ apps como pods · 15 servidores lógicos           │
└────────────────────────────────────────────────────────────────────────┘
```

Frontera de soberanía absoluta: tráfico entre Plano 1 y Plano 2 es exclusivamente de descarga. SKULL no tiene acceso SSH al cliente, no accede a la API K8s del cliente, no recibe datos operacionales. Única señal que el IAM Installer envía al exterior: HTTP GET con versión y canal de rollout.

---

## 5. Stack Tecnológico del Daemon

| Componente | Herramienta / Versión | Propósito |
|---|---|---|
| Lenguaje principal | Go 1.22+ | Binario daemon, servidor HTTP, orquestación |
| Módulos de fichas | Python 3.11+ + Cython | Lógica declarativa compilable |
| Scripts OS | Bash 5.x | Operaciones atómicas del sistema |
| Gestor Go | go modules (go.mod) | Dependencias del daemon |
| Gestor Python | pip + pyproject.toml | Dependencias de módulos |
| Build system | Makefile + go build | Compilación cruzada amd64/arm64 |
| HTTP | net/http stdlib | API con Core UI y Release Server |
| Config | github.com/BurntSushi/toml | Lectura de bos.toml |
| Logging | github.com/rs/zerolog | Logging estructurado JSON |
| Testing Go | go test + testify | Unit tests del daemon |
| Testing Python | pytest | Tests de módulos |
| CI/CD | GitHub Actions + golangci-lint | Lint, tests, build release |

**Go para el daemon:** Binario estático sin dependencias. Arranque <100ms. Concurrencia nativa (goroutines) para múltiples fichas en paralelo. net/http nativo.

**Python para módulos:** Fichas son lógica declarativa que evoluciona por cliente. Modificables sin recompilar daemon.

**Bash para OS:** Operaciones atómicas (cp, mv, chmod, systemctl) con semántica POSIX. Rollback de binarios vía shell. Sin capa de abstracción entre daemon y filesystem.

---

## 6. Los 4 Archivos Maestros Bash (Core SP-01)

El Core **no sabe qué aplicaciones existen** — solo lee contratos de fichas y los ejecuta.

### `00_MASTER_INSTALL_SBOS.sh` — Punto de Entrada

Recibe `comando + ficha_id + [version]`. Valida argumentos, localiza ficha en `servers/`, absorbe `task_catalog.sh`, ejecuta acción, libera funciones.

Comandos: `install | update | repair | remove | status | probe | lint`

### `00_TASK_CATALOG_SBOS.sh` — Biblioteca de Funciones Genéricas

**NUNCA nombra ninguna aplicación concreta** (Principio P3).

| Grupo | Funciones |
|---|---|
| 1 · Validaciones | check_root_user, check_system_requirements, check_k8s_cluster_ready, check_node_resources |
| 2 · K8s Genéricas | create_k8s_namespace, create_pvc, delete_pvc, apply_network_policy, create_k8s_secret, apply_configmap, copy_file_to_pod, exec_command_in_pod, delete_k8s_manifest |
| 3 · Esperas | wait_pod_ready, wait_pod_healthy, verify_pod_running, verify_service_responds, verify_port_in_pod, wait_http_endpoint_ready |
| 4 · Filesystem | create_directories, apply_permissions, backup_directory, restore_directory |
| 5 · Ciclo de Vida | rollout_restart, scale_deployment, take_backup_snapshot, restore_backup_snapshot |

### `00_YAML_ENGINE_SBOS.sh` — Intérprete Declarativo

Lee `yaml_engine.yml` con `yq`. Implementa: P1 (sbos_k8s_core() único kubectl apply), P7 (Absorber/Ejecutar/Liberar), P14 (diagnosis_first en repair).

### `00_ARCHITECTURE_SBOS.yml` — Registro Declarativo Global

Mapea `nombre_tarea → función_bash` para tareas globales. Árbitro de frontera global vs específico.

---

## 7. Los 16 Módulos Python

### Capa Dominio (6 módulos — reglas de negocio)

| Módulo | Responsabilidad | Escribe a |
|---|---|---|
| `STATE_MANAGER.py` | **Única** escritura en `.sbos_state.json`. fcntl.flock. Árbitro transiciones | `.sbos_state.json` |
| `DEPENDENCY_RESOLVER.py` | Grafo DAG (Kahn). Orden topológico. Desbloqueo de fichas | STATE_MANAGER |
| `HEALTH_CHECKER.py` | Ejecuta health.check_command. Clasifica: ok/degraded/error/pending | STATE_MANAGER |
| `FICHA_LINTER.py` | Valida contratos SBOS. Cobertura ≥90% | Reporte errores |
| `FICHA_PROBE.py` | Dry-run completo sin desplegar | Reporte a Core UI |
| `GROWTH_DETECTOR.py` | Métricas Prometheus. Saturación CPU>80%, RAM>85%, disco>75% | Core UI WebSocket |

### Capa Orquestación (10 módulos — coordinación)

| Módulo | Responsabilidad |
|---|---|
| `INSTALL_RUNNER.py` | Orquesta ciclo como Saga: install/update/repair/uninstall con compensación |
| `RECONCILE_SCHEDULER.py` | Loop periódico: hashes SHA-256 actual vs declarado |
| `YAML_ENGINE.py` | Wrapper Python sobre motor Bash. Parsea señales `__SBOS__STEP_*` |
| `RELEASE_MANAGER.py` | Protocolo con SKULL Release Plane. Ed25519. Watchdog. Modo degradado |
| `PLUGIN_LOADER.py` | Escanea `servers/` para descubrir fichas. Hashes SHA-256 |
| `INFRA_CONFIGURATOR.py` | kubeadm join para nodos nuevos. Node selectors |
| `MENU_ENGINE.py` | Agrega info para Core UI |
| `PROCESS_MANAGER.py` | **Único** que llama `subprocess`. Eventos línea a línea |
| `PROGRESS_EMITTER.py` | WebSocket + `.jsonl` para replay al reconectar |
| `LOGGER.py` | Logging centralizado. Puente CLI hacia Bash |

**Responsabilidad única estricto:** STATE_MANAGER = único escritor .sbos_state.json. PROCESS_MANAGER = único subprocess. RELEASE_MANAGER = único HTTP al Release Plane.

---

## 8. Sagas de Instalación con Compensación

### Saga: Install

| Paso | Acción | Compensación |
|---|---|---|
| 1 | DEPENDENCY_RESOLVER.verify_all_satisfied | (lectura) → ABORT si falla |
| 2 | STATE_MANAGER.transition → INSTALANDO | transition → NO_INSTALADA |
| 3 | YAML_ENGINE pre_install | (idempotente) |
| 4 | YAML_ENGINE install | YAML_ENGINE uninstall (o cleanup genérico) |
| 5 | YAML_ENGINE post_install | (verificaciones) |
| 6 | HEALTH_CHECKER.verify | Falla → ALERTA |
| 7 | STATE_MANAGER → INSTALADA_OK + register_hashes | — |

### Saga: Update

| Paso | Acción | Compensación |
|---|---|---|
| 1 | STATE_MANAGER → ACTUALIZANDO | transition → INSTALADA_OK (versión anterior) |
| 2 | PLUGIN_LOADER.backup_current_resources | restore_resources |
| 3 | YAML_ENGINE update | YAML_ENGINE rollback |
| 4 | HEALTH_CHECKER.verify | Ejecutar comp. paso 3 |
| 5 | STATE_MANAGER → INSTALADA_OK + register_hashes | — |

### Saga: Repair

| Paso | Acción | Compensación |
|---|---|---|
| 1 | STATE_MANAGER → REPARANDO | transition → ALERTA |
| 2 | SI diagnosis_first: execute diagnosis | Reporte sin acción |
| 3 | YAML_ENGINE repair | (best effort) |
| 4 | HEALTH_CHECKER.verify | OK → INSTALADA_OK / FAIL → ALERTA + notificar |

### Saga: Uninstall

| Paso | Acción | Compensación |
|---|---|---|
| 0 | GOVERNANCE check (cat.3 → aprobación dual, timeout 60min) | — |
| 1 | STATE_MANAGER → DESINSTALANDO | transition → INSTALADA_OK |
| 2 | DEPENDENCY_RESOLVER.verify_no_dependents | ABORT con lista |
| 3 | YAML_ENGINE uninstall | YAML_ENGINE install (reinstalar) |
| 4 | STATE_MANAGER → NO_INSTALADA + clear_hashes | — |

### Timeouts

install: 30min · update: 15min · repair: 10min · uninstall: 10min · deploy: 120min. Si timeout → compensación desde último paso hacia atrás.

---

## 9. Protocolo de Señales `__SBOS__`

### Progreso

```
__SBOS__STEP_START__    <descripción>
__SBOS__STEP_OK__       <descripción>
__SBOS__STEP_ERROR__    CAUSA: <texto>
                        SOLUCIÓN: <texto>
                        COMANDO: <comando CLI sugerido>
__SBOS__STEP_SKIP__     <razón>
__SBOS__STEP_PROGRESS__ <N>/<TOTAL> <descripción>
```

### Finalización

```
__SBOS__DONE__OK__
__SBOS__DONE__ERROR__
__SBOS__DONE__ERROR__COMPENSABLE__
__SBOS__DONE__ERROR__FATAL__           # requiere intervención manual
```

### Metadata

```
__SBOS__META__VERSION__   __SBOS__META__PORT__      __SBOS__META__NAMESPACE__
__SBOS__META__POD__       __SBOS__META__PVC__       __SBOS__META__SECRET__
__SBOS__META__CONFIG__
```

YAML_ENGINE captura metadata → STATE_MANAGER registra recursos creados por ficha (para cleanup en compensación).

Reglas: líneas sin `__SBOS__` = log informativo. STEP_ERROR es multilínea. Señales por stdout, stderr = diagnóstico. Timeout 30min sin señal.

---

## 10. Transiciones de Estado Válidas

```
NO_INSTALADA     → INSTALANDO
INSTALANDO       → INSTALADA_OK | NO_INSTALADA (compensación)
INSTALADA_OK     → ACTUALIZANDO | REPARANDO | DESINSTALANDO | ALERTA
ALERTA           → INSTALADA_OK | REPARANDO
ACTUALIZANDO     → INSTALADA_OK | ALERTA
REPARANDO        → INSTALADA_OK | ALERTA
DESINSTALANDO    → NO_INSTALADA | INSTALADA_OK (comp. restauró)
BLOQUEADA        ↔ NO_INSTALADA
```

Cualquier transición fuera de tabla → STATE_MANAGER rechaza + error crítico + system_alert.

**Nota V8:** El archivo de internos (BOS_V5_SBOS-005-001-DAEMON-INTERNALS) define 171 transiciones
válidas sobre 8 estados en la implementación real. La tabla aquí listada es la versión
canónica HUMAN-DOC que captura todas las rutas de negocio permitidas. Para el detalle
completo de la máquina de estados, ver la especificación de STATE_MANAGER §24.

---

## 11. Schema `.sbos_state.json`

```json
{
  "version": "1.0",
  "updated_at": "ISO-8601",
  "system": {
    "hostname": "string",
    "ubuntu_version": "26.04",
    "kubernetes_version": "1.31.2",
    "cluster_id": "uuid",
    "bootstrap_completed_at": "ISO-8601",
    "last_health_check": "ISO-8601",
    "last_reconcile": "ISO-8601"
  },
  "fichas": {
    "<ficha_id>": {
      "status": "NO_INSTALADA|INSTALANDO|INSTALADA_OK|ALERTA|...",
      "version": "semver",
      "server": "string",
      "installed_at": "ISO-8601",
      "health": { "result": "ok|degraded|error|pending", "last_check": "ISO-8601", "consecutive_failures": 0 },
      "hashes": { "manifest": "sha256:...", "yaml_engine": "sha256:...", "task_catalog": "sha256:...", "resources": "sha256:..." },
      "execution_order": 100,
      "depends_on": ["ficha_ids"],
      "governance_category": 2
    }
  },
  "products": { "<id>": { "status": "string", "fichas": ["ids"] } },
  "deploy": { "deploy_id": "uuid", "seed_file": "path", "products_requested": [], "products_completed": [] },
  "operations": { "active": null, "history": [] },
  "release": { "current_version": "semver", "prev_version": "semver", "channel": "canary|early|stable", "pending_stabilization": false }
}
```

Concurrencia: fcntl.flock(LOCK_EX) timeout 5s. Solo UNA operación activa a la vez.

---

## 12. Protocolo `bosctl` ↔ Daemon

HTTP sobre Unix socket `/run/bos/bos.sock`. Permisos 0660, grupo bosagent. Sin JWT (auth a nivel OS).

### Comandos

```bash
bosctl status                    → GET /api/dashboard
bosctl health                    → GET /api/health
bosctl version                   → GET /internal/version
bosctl fichas                    → GET /api/fichas
bosctl probe <ficha>             → POST /api/fichas/{id}/probe
bosctl lint <ficha>              → lint local
bosctl install <ficha>           → POST /api/fichas/{id}/install
bosctl install --all             → ejecuta grafo completo
bosctl update <ficha>            → POST /api/fichas/{id}/update
bosctl repair <ficha>            → POST /api/fichas/{id}/repair
bosctl remove <ficha>            → POST /api/fichas/{id}/uninstall (--confirm=DESINSTALAR-<ID>)
bosctl product list              → GET /api/products
bosctl product install <prod>    → POST /api/products/{nombre}/install
bosctl deploy <archivo.yml>      → POST /api/deploy
bosctl deploy status             → GET /api/deploy/status
bosctl update-daemon             → fuerza verificación
bosctl rollback                  → revierte al binario anterior
```

Exit codes: 0=éxito, 1=error genérico, 2=validación, 3=ficha no encontrada, 4=operación activa, 5=dependencias, 6=daemon no disponible, 7=timeout, 8=gobernanza, 10=error interno.

Principio equivalencia: todo lo que bosctl puede hacer, Core UI podrá hacer (misma API REST).

---

## 13. Servicio systemd

```ini
[Unit]
Description=SBOS IAM Installer — Sovereign Control Plane
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/bos/bos
ExecStartPost=/opt/bos/bosctl health --wait-stable=60 --on-fail=rollback
Restart=always
RestartSec=5
User=bosagent
Group=bosagent
WorkingDirectory=/opt/bos
Environment=BOS_ENV=production
Environment=BOS_CONFIG=/etc/bos/bos.toml
StandardOutput=journal
StandardError=journal
SyslogIdentifier=bos
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/opt/bos /etc/bos /var/log/bos
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

Restart=always (nunca queda caído). ExecStartPost verifica estabilización 60s → rollback si falla. User=bosagent (mínimos privilegios). Hardening: NoNewPrivileges + ProtectSystem=strict.

---

## 14. Estructura de Archivos

```
/opt/bos/
├── iam-installer          ← binario activo
├── iam-installer.prev     ← custodia para rollback
└── bosctl                 ← CLI

/etc/bos/
├── bos.toml               ← configuración daemon
├── .sbos_state.json       ← estado persistente
├── *.jsonl                ← eventos para replay WebSocket
└── blibs/
    ├── core/              ← 4 archivos maestros Bash
    │   ├── 00_MASTER_INSTALL_SBOS.sh
    │   ├── 00_TASK_CATALOG_SBOS.sh
    │   ├── 00_YAML_ENGINE_SBOS.sh
    │   └── 00_ARCHITECTURE_SBOS.yml
    ├── servers/           ← fichas por servidor lógico
    │   └── <servidor>/<ficha>/
    │       ├── manifest.yml
    │       ├── yaml_engine.yml
    │       ├── task_catalog.sh
    │       └── resources/
    ├── bkernel/rules/     ← reglas YAML del bKernel
    ├── biedata/boxes/     ← cajas de biedata
    ├── bcompass/router/   ← rutas de bCompass
    ├── bsearch/patterns/  ← patrones de bSearch
    ├── bauth/auths/       ← fichas auth de bAuth
    ├── bhnexus/rights/    ← fichas rights de bhnexus
    └── banexus/           ← config agente cliente

/var/log/bos/              ← logs (rotación por journald)
/etc/systemd/system/bos.service
```

---

## 15. Ciclo de Vida Completo

### Primera instalación (Ubuntu virgen)

```
curl -sSL https://get.sbos.io/installer | sudo bash [-s -- --deploy=cliente.yml]
  → daemon bos instalado como systemd → arranca
  → PLUGIN_LOADER escanea servers/ → DEPENDENCY_RESOLVER construye DAG
  → Ejecuta grafo completo en orden topológico:
    sbos-bootstrap-os → sbos-bootstrap-k8s → sbos-bootstrap-platform →
    validator → postgresql → redis → minio → vault → keycloak →
    nginx → kong → linkerd → kyverno → prometheus → grafana →
    sbos-bootstrap-hardening
  → Si --deploy → continúa con productos del seed file
```

### Operación normal

```
systemd levanta bos → RELEASE_MANAGER verifica versión →
FICHA_LINTER valida → PLUGIN_LOADER escanea → DEPENDENCY_RESOLVER → HEALTH_CHECKER →
Loops independientes:
  RELEASE_MANAGER (actualizaciones cada N horas)
  RECONCILE_SCHEDULER (drift check cada N minutos)
  PLUGIN_LOADER watch (fichas nuevas)
  HEALTH_CHECKER (salud continua)
  GROWTH_DETECTOR (saturación nodos)
  API REST / WebSocket (Core UI + bosctl)
```

---

## 16. Ciclo Absorber → Ejecutar → Liberar

```
ABSORBER:
  FICHA_LINTER valida contrato
  Localiza servers/<servidor>/<ficha>/
  source task_catalog.sh → _task_<app>_*() en memoria
  DEPENDENCY_RESOLVER verifica dependencias

EJECUTAR:
  YAML Engine lee yaml_engine.yml fase a fase:
    pre_install → install (sbos_k8s_core ÚNICO kubectl apply) → post_install
    SI FALLA → compensación Saga
  STATE_MANAGER → INSTALADA_OK
  DEPENDENCY_RESOLVER.recalculate() → desbloquea dependientes

LIBERAR:
  unset -f _task_<app>_*() → funciones eliminadas
  Core limpio, sin contaminación entre fichas
```

---

## 17. Release Plane

### Seguridad Ed25519 (RFC 8032)

Clave privada en Vault sellado SKULL (quórum N de M). Clave pública compilada en binario. Cada release: checksums.sha256 + firma Ed25519. Cada instalación: verificar firma → verificar SHA-256 → si falla en cualquier paso → ABORT.

### Canales de Rollout

| Canal | Población | Propósito | Tiempo |
|---|---|---|---|
| canary | 1-3 clientes | Producción real | Semana 1 |
| early | ~20% flota | Escala | Semanas 2-3 |
| stable | Resto | General | Semana 4+ |

### Criterios de Halt

| Evento | Criterio | Acción |
|---|---|---|
| P0 | 1 cliente inutilizable | HALT inmediato todos los canales |
| P1 | 2 incidentes <4h mismo canal | HALT canal + hold siguientes |
| Latencia | API >50% baseline >15min | HOLD — decisión humana |
| Error rate | >1% endpoints críticos >10min | HOLD |

### Rollback Automático del Daemon

```
Nuevo binario → systemctl restart bos → bosctl health --wait-stable=60
5 criterios en 60 segundos:
  1. systemctl is-active = active
  2. GET /health = 200
  3. .sbos_state.json accesible
  4. RECONCILE_SCHEDULER completó un ciclo
  5. Sin crash loops (max 1 reinicio)
NO → cp .prev → restart → notifica CRITICAL
SÍ → .prev conservado 7 días
```

### Modo Degradado Offline

RELEASE_MANAGER reintenta con backoff (5min→30min→2h→6h). Todos los demás módulos operan sin cambio. Solo no puede instalar fichas no descargadas previamente. Core UI muestra banner de advertencia.

---

## 18. Observación Integral SO → K8s → Fichas

| Nivel | Qué observa | Acción ante fallo |
|---|---|---|
| SO | kernel, systemd, disco, RAM, CPU, CRI-O, updates | Reinicio/diagnóstico/cleanup/alerta |
| K8s | API Server, etcd, nodos, certificados, CNI, CoreDNS | Diagnóstico/repair/alerta rotación |
| Fichas | health.check_command, drift SHA-256, dependencias, versiones | repair si auto_repair / notifica si requiere humano |

¿Por qué el IAM Installer y no K8s? K8s reinicia pods pero no puede: repararse a sí mismo, diagnosticar problemas del SO, reconciliar integraciones KC/Kong/Vault, ni gestionar ciclo completo de fichas con dependencias.

### 18.1 Ciclo de Vida Multitenant — Operaciones de Tenant

El IAM Installer gestiona el ciclo de vida completo de cada tenant (empresa cliente) como unidad operacional de SKULL. Un tenant = un realm Keycloak + un namespace K8s con sus fichas + bases de datos dedicadas + credenciales Vault propias.

#### A.1 — Alta de Empresa Cliente (Nuevo Tenant)

Saga de 7 pasos con compensación completa. Se dispara con `bosctl deploy <seed-file.yml>` donde el seed file (SBOS-037) contiene la identidad del cliente.

| Paso | Acción | Compensación si falla |
|---|---|---|
| 1 | Validar seed file (campos obligatorios, DNS, logo) | ABORT — sin cambios |
| 2 | Crear realm Keycloak via Admin API (realm + clients base) | DELETE realm |
| 3 | Desplegar SPIs en el realm (5 authenticators + RolTemporalAuthenticator) | Rollback realm a configuración base |
| 4 | Crear usuarios iniciales en KC: admin-cliente (realm-admin) + emergency-admin (realm backup) + **service accounts para fichas** (bAuth, bSearch, bCompass — cuentas de máquina sin login humano, credenciales almacenadas en Vault) | DELETE usuarios KC + revocar service accounts en Vault |
| 5 | Instalar fichas del producto en namespace dedicado (ver §3 Niveles) | Uninstall fichas en orden inverso |
| 6 | Crear bases de datos del tenant en PostgreSQL con credenciales Vault | DROP databases + revocar Vault paths |
| 7 | Emitir evento `tenant.created` + registrar en `.sbos_state.json` | Eliminar entrada state |

**Service accounts creados por defecto en el Paso 4:**

| Account | Propósito | Credenciales en Vault |
|---|---|---|
| `svc-bauth-{realm}` | bAuth → KC Admin API (sync RolTemplates) | `secret/tenants/{realm}/svc-bauth` |
| `svc-bsearch-{realm}` | bSearch → indexación de entidades del realm | `secret/tenants/{realm}/svc-bsearch` |
| `svc-bcompass-{realm}` | bCompass → rutas de análisis del realm | `secret/tenants/{realm}/svc-bcompass` |

Los service accounts tienen `clientAuthenticatorType: client-secret` y `serviceAccountsEnabled: true` en KC. No tienen contraseña de usuario — se autentican con `client_credentials` grant. El comando `bosctl tenant suspend` no los desactiva — solo desactiva las cuentas de usuarios humanos del realm.

```bash
# Comando de alta
bosctl deploy cliente-acme.deploy.yml

# Output esperado al completar:
✓ TENANT CREADO: ACME S.R.L.
  Realm KC: acme-srlt | Namespace: sbos-acme | Fichas: 22
  Admin: https://acme.skull.io | admin@acme.com
  Vault paths: secret/tenants/acme-srlt/
  Service accounts: svc-bauth-acme-srlt, svc-bsearch-acme-srlt, svc-bcompass-acme-srlt
```

#### A.2 — Modificación de Tenant

| Tipo de modificación | Proceso | Requiere ARB |
|---|---|---|
| Agregar producto (ej: ai) | `bosctl product install ai --tenant=acme` | No |
| Cambiar dominio | Actualizar NGINX + Kong + KC + certificados TLS | No |
| Cambiar NIT/razón social | Actualizar seed file + re-sincronizar Tryton + KC | No |
| Agregar servidor lógico | Tarea 3.5 de deploy + relabel nodo K8s | Sí (impacta S-HOST) |
| Cambiar plan de cuentas Tryton | Migración contable — requiere backup previo verificado | Sí |
| Escalar fichas (réplicas) | `bosctl update <ficha> --tenant=acme` con nuevo manifest | No |

Todas las modificaciones son idempotentes. Re-ejecutar con el mismo seed file actualizado converge al estado deseado sin duplicar recursos.

#### A.3 — Suspensión Temporal de Tenant

Se usa cuando el cliente no paga, hay una investigación de seguridad, o el cliente solicita pausa temporal.

**Dos modalidades de suspensión:**

**Suspensión de Identidad** — login bloqueado, datos intactos, fichas corriendo:
```bash
bosctl tenant suspend acme-srlt --reason="pago_vencido"

# Internamente ejecuta:
# 1. PUT /admin/realms/acme-srlt { "enabled": false }  → KC
# 2. bAuth notifica bhnexus → BitMask a cero en todos los nodos
# 3. Registra evento en .sbos_state.json con timestamp y razón
# 4. Core UI muestra banner rojo al administrador SKULL
```

Efectos:
- Ningún usuario del realm puede autenticarse (KC rechaza login)
- JWTs existentes expiran en ≤5 minutos (duración AT configurada)
- bhnexus invalida cache BitMask → banexus aplica deny-all
- **Los datos del cliente permanecen intactos — solo el acceso está bloqueado**
- **Las fichas siguen corriendo — los slots WAL siguen activos y consumiendo WAL**
- Usar cuando: pago vencido (primeros avisos), investigación seguridad, pausa temporal (≤1 día)

**Suspensión Completa** — identidad bloqueada + procesamiento de datos detenido:
```bash
bosctl tenant suspend acme-srlt --mode=full --reason="suspension_prolongada"

# Ejecuta todo lo de la suspensión de identidad, MÁS:
# SELECT pg_drop_replication_slot('bkernel_acme_srlt_tryton');
# SELECT pg_drop_replication_slot('bkernel_acme_srlt_orangehrm');
# ⚠️ SOLO si la suspensión será > 1 día — evita acumulación ilimitada de WAL
# que puede llenar el disco de PostgreSQL y detener el servidor completo
```

Efectos adicionales a la suspensión de identidad:
- Slots de replicación lógica eliminados → bKernel deja de procesar eventos del tenant
- La BD del tenant permanece intacta, solo sin procesamiento en tiempo real
- Al reactivar, los slots deben recrearse (`bosctl tenant resume --recreate-slots`)
- Sin `--recreate-slots`, bKernel no procesará cambios del tenant hasta la próxima reinstalación
- Usar cuando: suspensión confirmada de más de 1 día

**Tabla de decisión: ¿Qué suspensión usar?**

| Situación | Duración esperada | Suspensión recomendada |
|---|---|---|
| Pago vencido — primeros avisos | ≤ 1 día | Identidad |
| Pago vencido — impago confirmado | > 1 día | Completa |
| Investigación de seguridad activa | Indefinido | Completa |
| Mantenimiento técnico del tenant | ≤ 4 horas | Identidad |
| Solicitud del cliente — vacaciones | > 1 día | Completa |

Reactivación:
```bash
bosctl tenant resume acme-srlt                    # si se usó suspensión de identidad
bosctl tenant resume acme-srlt --recreate-slots   # si se usó suspensión completa
```

#### A.4 — Baja Definitiva de Tenant

Proceso formal en tres momentos con retención legal por jurisdicción.

**Semana -2 (notificación):**
- Enviar notificación formal al cliente (email + Core UI)
- Generar export completo de datos: `bosctl tenant export acme-srlt --format=sql+files`
- Backup verificado con pgBackRest: `bosctl tenant backup acme-srlt --verify`
- Entrega de export al cliente (SFTP firmado o USB cifrado)

**Día 0 (ejecución):**
```bash
bosctl tenant decommission acme-srlt --confirm="BAJA-DEFINITIVA-ACME-SRLT"

# Ejecuta en orden:
# 1. Suspensión de identidad (A.3) → acceso bloqueado
# 2. DELETE namespace sbos-acme → fichas eliminadas
# 3. DELETE realm acme-srlt en KC → identidades eliminadas
# 4. Retención datos según jurisdicción (ver tabla)
# 5. Revocación paths Vault del tenant
# 6. Actualización .sbos_state.json → tenant: terminated
```

**Tabla de retención legal de datos por jurisdicción:**

| País | Marco legal | Retención contable | Retención laboral | Retención fiscal | Acción SBOS |
|---|---|---|---|---|---|
| Bolivia | Código de Comercio Art. 36, Ley 843 | 10 años | 5 años | 10 años | Mantener backup PG cifrado en MinIO hasta vencimiento |
| Argentina | Ley 25.326, Res. UIF | 10 años | 10 años | 10 años | Mantener backup PG cifrado hasta vencimiento |
| México | CFF Art. 30, LFPDPPP | 5 años | 5 años | 5 años | Mantener backup PG cifrado hasta vencimiento |
| Colombia | DIAN, Código de Comercio Art. 60 | 10 años | 5 años | 10 años | Mantener backup PG cifrado hasta vencimiento |
| Perú | Ley 29733, SUNAT | 5 años | 5 años | 5 años | Mantener backup PG cifrado hasta vencimiento |
| Chile | Ley 21.719, SII | 6 años | 5 años | 6 años | Mantener backup PG cifrado hasta vencimiento |

**Día 1 (confirmación):**
- Verificar eliminación completa de accesos (no queden tokens activos)
- Eliminar slots de replicación lógica del tenant (si no se hizo en suspensión completa):

```sql
-- PASO 1: Verificar qué slots existen para el tenant antes de eliminar
SELECT slot_name, plugin, active,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS lag_acumulado
FROM pg_replication_slots
WHERE slot_name LIKE '%acme_srlt%';

-- PASO 2: Eliminar cada slot encontrado
-- (ajustar nombres según lo que devolvió la consulta anterior)
SELECT pg_drop_replication_slot('bkernel_acme_srlt_tryton');
SELECT pg_drop_replication_slot('bkernel_acme_srlt_orangehrm');
SELECT pg_drop_replication_slot('bkernel_acme_srlt_saleor');
-- Repetir para cada BD del tenant que tuviera slot activo

-- PASO 3: Verificación final — debe retornar 0 filas
SELECT slot_name FROM pg_replication_slots
WHERE slot_name LIKE '%acme_srlt%';
-- Resultado esperado: (0 rows)
```

> ⚠️ **Consecuencia si se omite este paso:** PostgreSQL mantiene el slot activo y no puede liberar el WAL anterior al punto de inicio del slot. En un servidor con múltiples tenants activos, un slot huérfano puede acumular gigabytes de WAL hasta llenar el disco y detener PostgreSQL — afectando TODOS los tenants del servidor. Este paso es obligatorio aunque el tenant ya no tenga namespace ni realm.

- Archivar backup de retención en almacenamiento frío con etiqueta `tenant=acme-srlt, retention_until=YYYY-MM-DD`
- Emitir certificado de eliminación de datos al cliente (si lo solicita — cumplimiento GDPR/LGPD)
- Cerrar ticket en el sistema de gestión de clientes

#### Comandos bosctl de Gestión de Tenants

```bash
bosctl tenant list                          # Lista todos los tenants con estado
bosctl tenant status <realm-id>             # Estado detallado: fichas, usuarios, último acceso
bosctl tenant suspend <realm-id>            # Suspensión de identidad (por defecto)
bosctl tenant suspend <realm-id> --mode=full  # Suspensión completa (elimina slots WAL)
bosctl tenant resume <realm-id>             # Reactivación (suspensión de identidad)
bosctl tenant resume <realm-id> --recreate-slots  # Reactivación (suspensión completa)
bosctl tenant export <realm-id>             # Export de datos
bosctl tenant backup <realm-id> --verify    # Backup verificado
bosctl tenant decommission <realm-id>       # Baja definitiva (requiere string confirmación)
bosctl tenant retention list                # Lista tenants en retención con fecha expiración
bosctl tenant retention purge <realm-id>    # Purga datos una vez expirado el plazo legal
```

---

## 19. Governance Dual-Control

Operación destructiva = desinstalar, repair invasivo, escalar a cero, drenar nodo, eliminar namespace.

Protocolo: Core UI muestra diagnóstico completo (recursos afectados, dependencias, recomendación) → criticality:true requiere diagnosis_first + segunda confirmación → remove requiere backup previo verificado → ejecución con Saga compensatoria.

Auto-eliminación PROHIBIDA (invariante de seguridad).

---

## 20. Los 15 Principios de Arquitectura

| # | Principio | Consecuencia si se viola |
|---|---|---|
| P1 | Punto único kubectl (sbos_k8s_core) | Pierde trazabilidad |
| P2 | Declarativo sobre imperativo | No puede reproducir instalación |
| P3 | Funciones globales agnósticas | Core se acopla a apps |
| P4 | Idempotencia obligatoria | Estados inconsistentes |
| P5 | Streaming señales línea a línea | UI bloqueada |
| P6 | Export -f obligatorio | Funciones no en subshells |
| P7 | Absorber/Ejecutar/Liberar | Colisión entre fichas |
| P8 | Estado centralizado (STATE_MANAGER) | Race conditions |
| P9 | Dry-run antes de apply | Manifests inválidos |
| P10 | Secrets vía Vault | Credenciales expuestas |
| P11 | NetworkPolicy por ficha | Pods sin aislamiento |
| P12 | Backup antes de repair | Datos perdidos |
| P13 | Logging vía LOGGER | Logs sin trazabilidad |
| P14 | Diagnosis antes de repair | Reparaciones que empeoran |
| P15 | Pull-only actualizaciones | Pérdida soberanía |

---

## 21. Posicionamiento vs Industria

| Capacidad | Terraform | ArgoCD | K8s Operators | Crossplane | IAM Installer |
|---|---|---|---|---|---|
| Day 0 (SO+K8s) | ❌ | ❌ | ❌ | ❌ | ✅ |
| Day 1 (Apps) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Reconciliación Day 2 | ❌ | ✅ | ✅ | ✅ | ✅ |
| Self-healing SO+K8s+Apps | ❌ | ❌ | Parcial | ❌ | ✅ |
| Cadena custodia Ed25519 | Parcial | Parcial | ❌ | ❌ | ✅ |
| Gestión flota | ❌ | ❌ | ❌ | ❌ | ✅ |
| Offline completo | ❌ | ❌ | ✅ | ❌ | ✅ |
| Governance dual-control | ❌ | ✅ (sync) | ❌ | ❌ | ✅ |
| Rollback auto daemon | ❌ | ❌ | ❌ | ❌ | ✅ |
| Sagas compensación | ❌ | ❌ | ❌ | ❌ | ✅ |
| Soberanía total | ❌ | ❌ | Parcial | ❌ | ✅ |
| Fichas editables prod | N/A | N/A | ❌ | ❌ | ✅ |

---

## 22. Ficha de Referencia: PostgreSQL

### manifest.yml

```yaml
name: "postgresql"
version: "18.0"
description: "Motor de persistencia principal del SBOS"
server: "dataserver"
execution_order: 100
governance_category: 2
workload:
  type: "kubernetes"
  namespace: "sbos-data"
  workload_type: "StatefulSet"
  replicas: 1
requirements:
  depends_on:
    - type: "ficha"
      target: "sbos-bootstrap-platform"
      state: "installed"
  resources: { cpu: "500m", memory: "2Gi", storage: "50Gi" }
health:
  check_command: "pg_isready -h localhost -p 5432"
  check_interval_seconds: 60
  consecutive_failures_threshold: 3
  auto_repair: false
  prometheus_query: "pg_up == 1"
criticality: true
auto_update: false
tags: ["database", "core", "stateful"]
```

### yaml_engine.yml

```yaml
phases:
  pre_install:
    tasks:
      - task: "validate_namespace_exists"
        params: { namespace: "sbos-data" }
      - task: "validate_storageclass_default"
      - task: "validate_resources_available"
        params: { cpu: "500m", memory: "2Gi" }
  install:
    tasks:
      - task: "pg_create_namespace"
      - task: "pg_create_secrets"
      - task: "pg_create_configmap"
      - task: "pg_deploy_statefulset"
      - task: "wait_pod_ready"
        params: { namespace: "sbos-data", pod_selector: "app=postgresql", timeout_seconds: 300 }
      - task: "pg_init_databases"
        params: { databases: ["keycloak_db", "tryton_db", "kong_db", "grafana_db"] }
      - task: "pg_configure_patroni"
      - task: "pg_configure_pgbouncer"
      - task: "pg_configure_wal_archiving"
  post_install:
    tasks:
      - task: "wait_pod_healthy"
        params: { namespace: "sbos-data", pod_selector: "app=postgresql" }
      - task: "verify_service_responds"
        params: { service: "postgresql.sbos-data.svc", port: 5432 }
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

### task_catalog.sh (estructura)

```bash
#!/usr/bin/env bash
pg_create_namespace() {
    __SBOS__STEP_START__    Crear namespace sbos-data
    kubectl create namespace sbos-data --dry-run=client -o yaml | kubectl apply -f -
    __SBOS__STEP_OK__       Namespace sbos-data listo
    __SBOS__META__NAMESPACE__   sbos-data
}
export -f pg_create_namespace

pg_deploy_statefulset() {
    __SBOS__STEP_START__    Desplegar StatefulSet PostgreSQL
    sbos_k8s_core "apply" "resources/postgresql-statefulset.yaml"
    __SBOS__STEP_OK__       StatefulSet postgresql desplegado
    __SBOS__META__POD__     postgresql-0
}
export -f pg_deploy_statefulset
```

---

## 23. Configuración bos.toml

```toml
[daemon]
listen_socket = "/run/bos/bos.sock"
listen_tcp = "0.0.0.0:9443"
tls_cert = "/etc/bos/tls/server.crt"
tls_key = "/etc/bos/tls/server.key"
log_level = "info"

[state]
state_file = "/etc/bos/.sbos_state.json"
lock_timeout_seconds = 5
events_dir = "/etc/bos/"

[health]
check_interval_seconds = 60
consecutive_failures_threshold = 3

[reconcile]
interval_seconds = 300
drift_check = true

[release]
server_url = "https://releases.skull.io"
check_interval_hours = 6
channel = "canary"
stabilization_window_seconds = 300
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

## 24. Especificación de Módulos de Dominio

### STATE_MANAGER

Funciones: get_state(), get_ficha_status(id), transition(id, status), register_hashes(id, hashes), set_operation_active(op), complete_operation(id, result), register_product(id, state), register_deploy(state), get_operations_history(filters).

Reglas: fcntl.flock(LOCK_EX) timeout 5s. Transición validada contra tabla §10. Solo UNA operación activa. Toda mutación incrementa updated_at y emite evento via SIGNAL_BUS.

### DEPENDENCY_RESOLVER

Funciones: build_graph(fichas) → DAG, topological_sort(dag), is_unblocked(id), get_blocked_by(id), verify_all_satisfied(id), verify_no_dependents(id), get_install_order(ids).

Algoritmo: Lee depends_on → grafo dirigido → detecta ciclos (error fatal) → Kahn → dentro del mismo nivel, ordena por execution_order.

### HEALTH_CHECKER

Funciones: check(id) → {result: ok|degraded|error|pending, details}, check_all(), verify(id) → bool.

Criterios: ok = exit 0 + pods Running + probes passing. degraded = exit 0 pero restarts > 3/hora. error = exit != 0 o CrashLoopBackOff. pending = estado transitorio.

consecutive_failures >= 3 → ALERTA. auto_repair: true + fallo → INSTALL_RUNNER.repair (max 1/ciclo).

### FICHA_LINTER

Validación: manifest.yml (name, version, server, execution_order, workload requeridos; workload.type ∈ {bash, kubernetes}; governance_category ∈ {1,2,3}; health.check_command presente). yaml_engine.yml (al menos fase install; tareas referenciadas deben existir). task_catalog.sh (export -f en todas las funciones; señales __SBOS__). resources/ (archivos declarados existen; checksums calculables).

### FICHA_PROBE

probe_install(id) → { feasible, blockers, would_execute, estimated_duration_ms, resources_required, resources_available, dependencies_satisfied }.

### GROWTH_DETECTOR

Umbrales (bos.toml): CPU >80%, RAM >85%, disco >75%, ventana 30min. Salida: { saturated, metrics, recommendation: none|add_node|increase_resources, suggested_action, fichas_heaviest }.

---

## 25. Pipeline CI/CD

```
make release VERSION=X.Y.Z
  [1] go build → amd64 + arm64
  [2] Tests integración contra K8s staging
  [3] validate_sp01.py (OBLIGATORIO — exit ≠ 0 = ABORT)
      P1: kubectl solo en sbos_k8s_core
      P3: 00_TASK_CATALOG sin apps concretas
      P6: export -f en todas las funciones
  [4] validate_sp02.py (OBLIGATORIO — exit ≠ 0 = ABORT)
      Cada ficha: manifest.yml válido, tareas referenciadas existen,
      export -f, resources/ completo
  [5] checksums.sha256 + firma Ed25519
  [6] Asignación canal (canary/early/stable)
  [7] Publicación en Release Server (solo si todos exit 0)
```

---

## 26. Integración con Context Plane (SBOS-049)

El bos IAM Installer es el **Policy Administrator** del Context Plane según NIST 800-207
(ADR-011). Esto significa:

1. **Inicializa el Context Registry** al crear un nuevo tenant (Paso 1 del alta de tenant):
   - Crea el namespace Redis para el Context Registry del tenant
   - Establece el TTL por defecto de contexto (15 min, configurable)
   - Configura las políticas de propagación W3C Baggage

2. **Destruye el Context Registry** al eliminar un tenant:
   - Elimina todas las entradas ctx_id del tenant
   - Cierra los WebSocket activos del tenant en bhnexus

3. **Verifica ctx_id vía bKernel** en operaciones inter-subproyecto:
   - Cada ficha que expone API pública incluye validación de ctx_id en su health check
   - bKernel monitorea el WAL y asegura que todo evento lleve ctx_id (SBOS CMS B-01)

4. **API de contexto en bos**:
   - POST /api/context/validate — valida ctx_id contra Context Registry
   - POST /api/context/promote — promueve contexto de pre-auth a auth (SBOS-049 §8)

---

## Trazabilidad

| Sección | Extraída de | Secciones originales |
|---|---|---|
| §1 Identidad | SBOS-005 v5.0 | Header, §2b Stack |
| §2 Función | SBOS-005 v5.0 | §1 Definición Ejecutiva, §2 Propósito, §3 Definición Técnica |
| §3 Niveles | SBOS-005 v5.0 | §2 Tres niveles Ficha/Producto/Deploy |
| §4 Tres planos | SBOS-005 v5.0 | §4 diagrama ASCII completo |
| §5 Stack | SBOS-005 v5.0 | §2b Stack Tecnológico del Daemon |
| §6 Archivos Bash | SBOS-005 v5.0 | §6 Los 4 Archivos Maestros con tablas funciones |
| §7 Módulos | SBOS-005 v5.0 | §5 Capas Responsabilidad, §7 Los 16 Módulos |
| §8 Sagas | SBOS-005-001 v1.0 | §3 Sagas (4 sagas con pasos y compensación) |
| §9 Señales | SBOS-005-001 v1.0 | §5 Catálogo Señales |
| §10 Transiciones | SBOS-005-001 v1.0 | §1.2 Tabla transiciones |
| §11 State schema | SBOS-005-001 v1.0 | §1 Schema JSON completo |
| §12 bosctl | SBOS-005-001 v1.0 | §2 Protocolo completo |
| §13 systemd | SBOS-005 v5.0 | §15.2 Unit file |
| §14 Estructura | SBOS-005 v5.0 | §15.3 Archivos |
| §15 Ciclo vida | SBOS-005 v5.0 | §16 Primera instalación + normal |
| §16 Absorber | SBOS-005 v5.0 | §17 Ciclo completo |
| §17 Release | SBOS-005 v5.0 | §9-§13 Release Plane, Ed25519, canales, halt, rollback, offline |
| §18 Observación | SBOS-005 v5.0 | §20 SO→K8s→Fichas |
| §18.1 A.1 — Service accounts | SBOS-COMPLETITUD-v2 §4.1 Gap 1 + ROLFRAMEWORK A.1 | Paso 4 explicitado: svc-bauth, svc-bsearch, svc-bcompass + tabla service accounts con Vault paths |
| §18.1 A.3 — Suspensión dual | SBOS-COMPLETITUD-v2 §4.1 Gap 2 + ROLFRAMEWORK A.3 | Distinción suspensión identidad (≤1 día, slots activos) vs completa (>1 día, slots eliminados). Tabla de decisión y comando --recreate-slots |
| §18.1 A.4 — Slots WAL Día 1 | SBOS-COMPLETITUD-v2 §4.1 Gap 3 + ROLFRAMEWORK A.4 + SBOS-008-INTEGRATION §7 | SQL explícito pg_drop_replication_slot con verificación previa (3 pasos) y advertencia de consecuencia si se omite |
| §19 Governance | SBOS-005 v5.0 | §21 Dual-Control |
| §20 Principios | SBOS-005 v5.0 | §24 Los 15 Principios |
| §21 Posicionamiento | SBOS-005 v5.0 | §23 Tabla vs industria |
| §22 Ficha ref | SBOS-005-001 v1.0 | §6 manifest+yaml_engine+task_catalog |
| §23 bos.toml | SBOS-005-001 v1.0 | §8 Configuración |
| §24 Módulos dominio | SBOS-005-001 v1.0 | §4 Especificación módulos |
| §25 Pipeline | SBOS-005 v5.0 | §14 CI/CD |
| §26 Context Plane | SBOS-049-CONTEXT-PLANE v3.0 + SBOS-048 ADR-011 | bos como Policy Administrator NIST 800-207 |

---

## Fuentes de Enriquecimiento V8

| Fuente | Ruta | Tipo | Detalle |
|---|---|---|---|
| BOS_V6_SBOS-018-DAEMON-BOS.md | Procesar/ | V6 Base | Contenido completo preservado |
| BOS_V5_SBOS-005-001-DAEMON-INTERNALS-v1_0.md | Procesar/ | V5 | 171 transiciones de estado, protocolo bosctl, sagas detalladas |
| SBOS CMS B-01 CTX-ID-BKERNEL.md | sbos/subproyectos/ | Smart* | Integración bKernel WAL→Tryton, ctx_id propagation, audit_events |
| SBOS-049-CONTEXT-PLANE v3.0 | Consolidado | V8 | Context Plane: ctx_id, Context Registry, bos como Policy Administrator |
| SBOS-048 ADR-011 | Consolidado | V8 | ADR-011: bos dueño del Context Plane |

---

_SKULL · SBOS · SBOS-018-DAEMON-BOS · V8 · Mayo 2026_
