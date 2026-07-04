# MANUAL DEL SUPERVISOR — BOS Agent

**Versión:** 1.2
**Fecha:** 2026-05-20 (S-32 — verificación completa de código)
**Proyecto:** SBOS — BosAgent
**Propósito:** Guía operativa para el supervisor de fábrica que supervisa al BOS Agent
**Código verificado:** 12,379 líneas Go · 18 paquetes internos · 23 comandos bosctl

---

## 1. ARQUITECTURA DE DESPLIEGUE — Decisión de diseño fundamental

```
HOST (bare-metal / VM — Ubuntu 24.04 LTS)
│
├── /opt/bos/bin/bos              ← BOS daemon (systemd o proceso nativo)
├── /opt/bos/bin/bosctl           ← CLI de control del BOS
│
├── sbos-bootstrap-os             ← Ficha 01 — se instala en el HOST directamente
│   └── Paquetes del sistema, containerd, crun, kernel modules
│
├── sbos-bootstrap-k8s            ← Ficha 02 — se instala en el HOST directamente
│   ├── kubeadm init              ← Corre en el HOST (no en contenedor)
│   ├── kubelet                   ← systemd service en el HOST
│   ├── containerd                ← systemd service en el HOST
│   └── CNI (Calico en prod)     ← Pods en K8s, pero instalados desde el HOST
│
└── Kubernetes (cluster en el HOST)
    │
    ├── keycloak                  ← Pod en K8s
    ├── kong                      ← Pod en K8s
    ├── prometheus                ← Pod en K8s
    ├── grafana                   ← Pod en K8s
    ├── postgresql                ← Pod en K8s
    ├── vault                     ← Pod en K8s
    ├── redis                     ← Pod en K8s
    ├── nginx                     ← Pod en K8s
    ├── minio                     ← Pod en K8s
    ├── linkerd                   ← Pods en K8s (service mesh)
    ├── kyverno                   ← Pods en K8s (policy engine)
    ├── velero                    ← Pods en K8s (backup)
    └── ... (~112 fichas)        ← Todas como Pods en K8s
```

### 1.1 División de responsabilidades

| Capa | Se instala en | Fichas | Motor de instalación |
|---|---|---|---|
| **Soberana** | HOST directamente | `sbos-bootstrap-os`, `sbos-bootstrap-k8s` | Bash nativo (task_catalog.sh) |
| **Aplicación** | Kubernetes (pods) | Todas las demás (~112 fichas) | `kubectl apply` (manifests YAML) |

### 1.2 Justificación

- **BOS y bootstrap NO pueden correr en Kubernetes** — son los que CREAN Kubernetes. 
  No pueden ser pods porque K8s no existe todavía cuando se instalan.
- **Las fichas de aplicación SÍ corren en Kubernetes** — aprovechan scheduling, health checks,
  rolling updates, resource limits, y todo el ecosistema K8s.
- **`kubectl apply` es nativamente idempotente** — todas las fichas de aplicación lo usan,
  lo que significa que `ficha_install` y `ficha_repair` comparten el mismo mecanismo
  sin producir residuos.

### 1.3 Ficha canónica de aplicación en K8s

```bash
ficha_install() {
    kubectl apply -f "${SBOS_FICHA_DIR}/manifests/"
}
ficha_uninstall() {
    kubectl delete -f "${SBOS_FICHA_DIR}/manifests/" --ignore-not-found
}
ficha_health() {
    kubectl get pods -n "${SBOS_NAMESPACE}" -l "app=${FICHA_ID}"
}
```

---

## 2. Estrategia de CNI

| Entorno | CNI | Motivo |
|---|---|---|
| **Producción** (bare-metal/VM) | Calico v3.29 | Network policies, eBPF, soporte completo |
| **Pruebas** (contenedor podman rootless) | kindnet | Sin bind-mounts del host, diseñado para K8s-en-contenedor |

La detección es automática (P18 en `sbos-bootstrap-k8s/task_catalog.sh`):
```bash
_install_cni() {
    if [[ "$(_detect_environment)" == "container" ]]; then
        kubectl apply -f https://.../kindnet/.../install-kindnet.yaml
    else
        kubectl apply -f https://.../calico/.../calico.yaml
    fi
}
```

---


Es **desechable** — se recrea desde cero para cada ciclo de prueba.

### 3.1 Parámetros de creación

```bash
  --privileged \
  --cgroupns=private \
  --security-opt seccomp=unconfined \
  --security-opt apparmor=unconfined \
  --tmpfs /tmp \
  --tmpfs /run \
  --volume /lib/modules:/lib/modules:ro \
  --network sbos-staging \
  -e container=podman \
  ubuntu-systemd:26.04 /sbin/init
```

### 3.2 Diferencias con producción

|---|---|---|
| CNI | kindnet (automático) | Calico (automático) |
| Cgroup delegation | P30 + P31 requeridos | Systemd del host maneja todo |
| `restrict_oom_score_adj` | Necesario | Opcional |
| Kernel modules | Solo `/lib/modules` en lectura | Acceso completo |
| `/run` mount | tmpfs, requiere `--shared` para CNI | Montaje nativo del host |

---

## 4. Cgroup v2 en contenedores anidados

### 4.1 Diagnóstico rápido

```bash
# Verificar cadena de delegación (debe mostrar cpu memory pids en cada nivel)
cat /sys/fs/cgroup/cgroup.subtree_control        # root
cat /sys/fs/cgroup/k8s.io/cgroup.subtree_control  # k8s.io → pods
```

### 4.2 Soluciones implementadas

| ID | Solución | Qué hace |
|---|---|---|
| P29 | `restrict_oom_score_adj = true` | containerd maneja OOM score, no crun |
| P30 | `cgroup-delegate-cpu.service` | Systemd oneshot antes de containerd |
| P31 | `_ensure_cgroup_controllers()` | Propaga controllers en cada nivel de jerarquía |

### 4.3 Verificación de estado

```bash
# Verificar que el clúster funciona
kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes
# Debe mostrar: Ready

# Verificar pods del sistema
kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -A
# Todos deben estar Running (o Completed)
```

---

## 5. Estado de Construcción — Fases

| Fase | Dominios | Estado | Entregables |
|---|---|---|---|
| **Sprints 1-4** | Ciclo de vida | ✅ Certificado | State manager, installer saga, health checker, reconcile scheduler, plugin loader, K8s core, WebSocket server, E2E eval 24/24 |
| **Fase A** | D6 Seguridad | ✅ Completa | 8 archivos Go (`internal/security/`), `bosctl security scan/audit`, RBAC provider (FileRBAC + BauthRBAC bridge), CIS checks Ubuntu+K8s |
| **Fase B** | D1+D2 Reparación+Paquetes | ✅ Completa | 4 archivos repair (`internal/repair/`), 5 archivos packages (`internal/packages/`), `bosctl repair --target=all/os/k8s`, `bosctl install/remove/upgrade` con 3 backends (apt/pip/helm) |
| **Fase C** | D3 Observabilidad | ✅ Completa | 2 archivos obs (`internal/observability/`), 1 archivo watchdog (`internal/watchdog/`), `bosctl top/health-report/logs`, watchdog 30s unificado, 3 fichas obs |
| **Fase D** | D5+D4 Catálogo+IA | ⬜ Pendiente | `internal/catalog/`, `internal/ai/`, `bosctl app list/history/rollback`, `bosctl ask/diagnose/explain/plan` |
| **Fase E** | D7 Installer ISO | ⬜ Pendiente | ISO bootable, branded screens, Ubuntu Autoinstall, late-commands |

---

## 6. Inventario de Paquetes Go — 18 paquetes, 12,379 líneas

```
src/
├── cmd/
│   ├── bos/main.go           (1314 líneas)  Entry point, auto-bootstrap, shutdown, signal handling
│   ├── bosctl/main.go        (573 líneas)   CLI dispatch, RBAC guard, WebSocket helpers, OS-layer commands
│   ├── bosctl/top.go         (13 líneas)    bosctl top dispatcher
│   ├── bosctl/health_report.go (31 líneas)  bosctl health-report dispatcher
│   ├── bosctl/logs.go        (79 líneas)    Logs unificados: systemd + kubectl
│   ├── bosctl/identity.go    (179 líneas)   Identity management: whoami, users, roles, set-role, revoke
│   ├── bosctl/packages.go    (182 líneas)   Package manager CLI: install, remove, upgrade
│   ├── bosctl/repair.go      (58 líneas)    Repair CLI: --target, --dry-run, --timeout
│   ├── bosctl/security.go    (67 líneas)    Security scan + audit CLI
│   └── bosmin/main.go        (169 líneas)   Minimal daemon for testing
│
└── internal/
    ├── config/               (773 líneas)   Config loader, growth thresholds, watchdog config
    ├── state/                (989 líneas)   State manager: .sbos_state.json con fcntl flock
    ├── installer/            (529 líneas)   Saga pattern: compensator + saga engine
    ├── health/               (864 líneas)   Health checker: periodic + on-demand
    ├── reconcile/            (556 líneas)   Reconcile scheduler: drift detection + topological sort
    ├── server/               (951 líneas)   HTTP API + WebSocket server (ws.go 767 líneas)
    ├── plugin/               (325 líneas)   Plugin loader: YAML manifests
    ├── k8s/                  (220 líneas)   Kubernetes client wrapper
    ├── release/              (234 líneas)   Release manager: versioned deployments
    ├── wslib/                (299 líneas)   WebSocket client library
    ├── toml/                 (166 líneas)   TOML parser (native Go, sin dependencias externas)
    ├── security/             (8 archivos)   RBAC provider (FileRBAC + BauthRBAC bridge), CIS scanner, Ubuntu+K8s checks, identity provider
    ├── repair/               (770 líneas)   OS repair, K8s node repair, repair manager, health verifier
    ├── packages/             (558 líneas)   apt/pip/helm adapters, package manager, ficha auto-generator
    ├── observability/        (522 líneas)   top.go (métricas unificadas), health_report.go (3-capas)
    └── watchdog/             (369 líneas)   UnifiedWatchdog: ciclo 30s Ubuntu→K8s→BOS
```

---

## 7. Layout Canónico del Sistema de Archivos

```
/etc/bos/
├── bos.toml                     ← Configuración runtime (thresholds, intervalos)
├── bos-install.toml             ← Configuración de instalación (tenant, modo)
├── bos-bootstrap.env            ← Variables de bootstrap (credenciales, tenant ID)
├── .sbos_state.json             ← STATE FILE — corazón del sistema
├── .sbos_state.json.bak         ← Backup del state file
├── blibs/servers/               ← Fichas instaladas (~112 directorios)
│   ├── hostserver/              ← Fichas capa soberana (host)
│   │   ├── sbos-bootstrap-os/
│   │   ├── sbos-bootstrap-k8s/
│   │   ├── sbos-lifecycle/
│   │   ├── sbos-bootstrap-hardening/
│   │   ├── sbos-security/
│   │   ├── sbos-repair/
│   │   ├── sbos-package-manager/
│   │   └── sbos-container-watchdog/
│   ├── monitorserver/           ← Fichas de observabilidad
│   ├── dataserver/              ← Fichas de bases de datos
│   ├── identityserver/          ← Fichas de identidad (Keycloak, Vault)
│   ├── netserver/               ← Fichas de red (Kong, Nginx)
│   ├── aiserver/                ← Fichas de IA
│   └── ...                      ← ~10 servidores lógicos más
├── .kube/                       ← Kubeconfig y estado K8s
├── rbac/
│   └── roles.json               ← RBAC de bosctl (admin/operator/readonly)
└── secrets/
    └── ai.key                   ← ANTHROPIC_API_KEY (0600)

/opt/bos/
├── bin/
│   ├── bos                      ← Daemon binario
│   └── bosctl                   ← CLI binario
└── core/                        ← Scripts core del orquestador
    ├── 00_MASTER_INSTALL_SBOS.sh
    ├── 00_TASK_CATALOG_SBOS.sh
    ├── 00_YAML_ENGINE_SBOS.sh
    ├── 00_CLEANUP_SBOS.sh
    └── host-setup.sh

/run/bos/
├── bos.sock                     ← Unix socket (WebSocket del daemon)
└── bos.pid                      ← PID file

/var/log/bos/
├── bos.log                      ← Log principal del daemon
└── audit.log                    ← Audit log de acciones privilegiadas
```

---

## 9. Ciclo de vida del BOS Agent

### 9.1 Estados de ficha

```
NO_INSTALADA → INSTALANDO → INSTALADA_OK
                  ↓                ↓
              INSTALADA_NOK → REPARANDO → INSTALADA_OK / ERROR
                  
BLOQUEADA: esperando dependencias (topological sort)
```

### 9.2 Flujo del observador

```
Observer loop (cada heartbeat):
  1. Fase 1: Desbloquear BLOQUEADA (si dependencias satisfechas)
  2. Fase 2: Auto-instalar NO_INSTALADA (si depende de algo ya INSTALADA_OK)
  3. Fase 3: Auto-reparar ALERTA / INSTALADA_NOK
```

### 9.3 Saga pattern

Cada ficha implementa obligatoriamente:
- `ficha_pre_install()` — validaciones pre-vuelo
- `ficha_install()` — despliegue con rollback si falla
- `ficha_post_install()` — verificación post-instalación
- `ficha_repair()` — reparación
- `ficha_uninstall()` — desinstalación limpia
- `ficha_health()` — health check
- `ficha_diagnosis()` — diagnóstico detallado

---

## 10. Reglas absolutas para el supervisor

| Regla | Detalle |
|---|---|
| NUNCA `sudo podman` | Podman rootless exclusivamente |
| NUNCA `docker` | Docker vetado en todo el sistema |
| NUNCA `install.sh` | Obsoleto — BOS maneja todo autónomamente |
| NUNCA bash manual en contenedor | Toda solución va en `task_catalog.sh` |
| SIEMPRE `podman cp` + BOS restart | Para actualizar fuente de fichas |
| SIEMPRE verificar cgroups | `cpu memory pids` en los 3 niveles antes de kubeadm |
| SIEMPRE commit tras cambios validados | Conventional Commits en SBOS repo |

---

## 11. Referencia Completa de Comandos bosctl

### 11.1 Control del Daemon (vía WebSocket Unix socket)

```bash
bosctl status                   # Estado del daemon + todas las fichas
bosctl health                   # Health del daemon + fichas cargadas
bosctl shutdown --timeout 180   # Apagar BOS limpiamente
bosctl reload                   # Recargar configuración (SIGHUP)
```

### 11.2 Reparación Unificada (Fase B — D1)

```bash
bosctl repair --target=all         # Reparación completa: Ubuntu + K8s + BOS
bosctl repair --target=os          # Solo capa OS (dpkg, apt, systemd)
bosctl repair --target=k8s         # Solo capa K8s (cordon→drain→restart→uncordon)
bosctl repair --target=bos         # Solo reconciliación de fichas BOS
bosctl repair --dry-run            # Simular sin ejecutar
bosctl repair --timeout=600        # Timeout personalizado (default 600s)
```

### 11.3 Package Manager Unificado (Fase B — D2)

```bash
bosctl install <pkg> --backend=apt    # Instalar paquete del sistema + auto-ficha
bosctl install <pkg> --backend=pip    # Instalar paquete Python + auto-ficha
bosctl install <pkg> --backend=helm   # Instalar chart Helm + auto-ficha
bosctl remove <pkg>                   # Desinstalar + limpiar ficha
bosctl upgrade <pkg> --to=<version>   # Actualizar a versión específica
```

### 11.4 Observabilidad Unificada (Fase C — D3)

```bash
bosctl top                          # Métricas unificadas: CPU/MEM/DISK + K8s + Fichas
bosctl health-report                # Reporte de salud 3-capas (Ubuntu + K8s + BOS)
bosctl health-report --json         # Reporte en JSON para scripting
bosctl logs bos                     # Logs del daemon (journalctl)
bosctl logs kubelet                 # Logs de kubelet
bosctl logs <pod> --namespace=<ns>  # Logs de pod K8s (kubectl logs)
bosctl logs --follow                # Stream en vivo
```

### 11.5 Seguridad (Fase A — D6)

```bash
bosctl security scan                # Escaneo CIS completo: Ubuntu + K8s + RBAC
bosctl security audit               # Audit log (últimas 50 líneas)
bosctl security audit 100           # Últimas N líneas
```

### 11.6 Identidad (Fase B)

```bash
bosctl identity whoami              # Usuario y rol actual
bosctl identity users               # Listar todos los usuarios
bosctl identity roles               # Listar roles definidos
bosctl identity set-role <user> <role>  # Asignar rol (requiere admin)
bosctl identity revoke <user>           # Revocar acceso (requiere admin)
```

### 11.7 Comandos OS-layer (ADR-001 — reemplazan sudo)

```bash
bosctl exec -- <comando>            # Ejecutar como root vía BOS
bosctl ls <path>                    # Listar directorio con privilegios root
bosctl cat <path>                   # Leer archivo con privilegios root
bosctl tail <path>                  # Tail archivo con privilegios root
bosctl systemctl <acción>           # systemctl passthrough
bosctl journalctl <flags>           # journalctl passthrough
```

### 11.8 Watchdog (interno del daemon)

```bash
# Verificar ciclo de watchdog en logs (cada 30s)
# Output: duration_ms, all_pass, ubuntu=X/Y, k8s=X/Y, bos=X/Y
```

### 11.9 Variables de Entorno

| Variable | Propósito | Default |
|---|---|---|
| `BOS_SOCKET` | Path al Unix socket del daemon | `/run/bos/bos.sock` |
| `BOS_USER` | Identidad para RBAC (vacío = trusted root, sin check) | — |
| `BOS_BAUTH_ENABLED` | Usar BauthRBAC bridge (WebSocket a BauthAgent) | `false` |
| `BOS_BAUTH_SOCKET` | Path al socket de BauthAgent | `/run/bos/bauth.sock` |

### 11.10 Códigos de Salida

| Código | Significado |
|---|---|
| 0 | Éxito |
| 1 | Error general |
| 2 | Error de validación |
| 3 | Ficha no encontrada |
| 4 | Operación en progreso |
| 5 | Dependencia no satisfecha |
| 6 | Daemon no disponible |
| 7 | Timeout |
| 8 | Governance denied (RBAC) |
| 10 | Error interno |

---

## 12. Operaciones de Despliegue

### 12.1 Compilación (Go 1.22 en contenedor — no instalar Go en el host)

```bash
S=/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src
mkdir -p /tmp/bos-build && \
podman run --rm -v "$S:/src:Z" -v /tmp/bos-build:/out:Z -w /src \
  -e CGO_ENABLED=0 golang:1.22 sh -c \
  'go build -o /out/bos ./cmd/bos && go build -o /out/bosctl ./cmd/bosctl' && \
echo "BUILD OK"
```


```bash
# Matar daemon anterior + desplegar binarios + reiniciar
  > /var/log/bos/bos.log 2>&1 &
rm -rf /tmp/bos-build

# Verificar
```

### 12.3 Actualizar fuente de ficha individual

```bash
podman cp staging/core/servers/hostserver/sbos-bootstrap-k8s/task_catalog.sh \
```

### 12.4 Recrear contenedor limpio

```bash
# ... luego recrear con parámetros de §3.1
```

---

## 13. Configuración del Daemon — bos.toml

```toml
[runtime]
container_engine = "podman"
container_mode = "rootful"

[daemon]
log_level = "debug"

[state]
lock_timeout_seconds = 5

[health]
check_interval_seconds = 60
consecutive_failures_threshold = 3

[reconcile]
interval_seconds = 300
drift_check = true

[sagas]
install_timeout_minutes = 30
repair_timeout_minutes = 10
uninstall_timeout_minutes = 10

[growth]
cpu_threshold_percent = 80
ram_threshold_percent = 85
disk_threshold_percent = 75

[watchdog]
interval_seconds = 30
disk_threshold_percent = 85
memory_threshold_percent = 90
k8s_node_check = true
k8s_pod_check = true
bos_ficha_check = true
auto_repair = false
```

---

## 14. Guía Rápida de Desarrollo

### 14.1 Flujo de trabajo estándar

```
1. Modificar código en src/
2. Compilar: podman run --rm -v ... golang:1.22 (ver §12.1)
4. Verificar: bosctl top + bosctl health-report
5. Si todo OK: commit + push
```

### 14.2 Dónde vive cada cosa

| Qué | Dónde |
|---|---|
| Código fuente Go | `src/` |
| Comandos CLI | `src/cmd/bosctl/` (un archivo por comando) |
| Entry point daemon | `src/cmd/bos/main.go` |
| Lógica de negocio | `src/internal/<paquete>/` |
| Fichas (manifests) | `staging/core/servers/<server>/<ficha>/` |
| Config runtime | `staging/bos.toml` → `/etc/bos/bos.toml` |
| Documentos de contexto | `context/` |
| Planes de desarrollo | `context/BOS-OS-ELEVATION-PLAN-v3.md`, `context/plan-desarrollo-bos-elevacion.md` |

### 14.3 Prueba de que el sistema está vivo

```bash
# Check 1: Daemon corriendo

# Check 2: Watchdog activo (debe mostrar ciclos cada ~30s)

# Check 3: CLI funcional

# Check 4: State file íntegro
```

---

## Apéndice A — Fases completadas

| Fase | Dominio | Archivos Go | Comandos bosctl | Fichas nuevas |
|---|---|---|---|---|
| Sprints 1-4 | Ciclo de vida | 6,500+ líneas (10 paquetes) | status, health, shutdown, reload, install | sbos-lifecycle |
| Fase A | D6 Seguridad | 8 (1,064 líneas) | security scan, security audit | sbos-bootstrap-hardening, sbos-security |
| Fase B | D1+D2 Repair+Paq | 9 (1,446 líneas) | repair --target=, install/remove/upgrade, identity | sbos-repair, sbos-package-manager |
| Fase C | D3 Observabilidad | 3 (891 líneas) | top, health-report, logs | sbos-app-kube-state-metrics, sbos-app-node-exporter, sbos-container-watchdog |
| **Total construido** | **4 fases** | **30+ archivos, ~12,400 líneas** | **23 comandos** | **8 fichas + ~112 heredadas** |

## Apéndice B — Documentos de Contexto del Proyecto

| Documento | Propósito | Estado |
|---|---|---|
| `MANUAL-SUPERVISOR-BOS-AGENT.md` | Este manual — guía operativa del supervisor | ✅ v1.2 |
| `BOS-OS-ELEVATION-PLAN-v3.md` | Plan maestro: BOS = Ubuntu + K8s + BOS | ✅ v4.0 |
| `BOS-LIFECYCLE-PLAN-v2.md` | Plan de ciclo de vida validado contra ISO/IEC | ✅ v2.0 |
| `plan-desarrollo-bos-elevacion.md` | Plan de desarrollo por fases (A-E) | ✅ v1.0 |
| `PLAN-DESARROLLO-LIFECYCLE.md` | Plan original de sprints 1-4 | ✅ Completado |
| `VERIFICACION-COMPLETITUD-FICHAS.md` | Taxonomía y verificación de 112 fichas | ✅ |
| `SOLUCIONES-ROOTLESS-K8S.md` | Soluciones técnicas para K8s en contenedor | ✅ |
| `context/old/` | Documentos históricos de diagnóstico | 📦 Archivo |
