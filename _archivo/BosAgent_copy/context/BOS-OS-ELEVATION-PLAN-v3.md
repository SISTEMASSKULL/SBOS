# BOS — Business Operating System
## Plan de Elevación al Sistema Operativo de Negocios
**Versión:** 4.0 — Visión definitiva: BOS = Ubuntu + Kubernetes + BOS + BOS Installer  
**Fecha:** 2026-05-19  
**Punto de partida:** Sprint 4.1 certificado — ciclo de vida BOS E2E  
**Misión:** BOS es la suma de Ubuntu + Kubernetes + sus propias capacidades,  
presentadas al mundo como un único Sistema Operativo de Negocios (Business OS)  
**Estándares:** ISO/IEC 25010:2023 · ISO/IEC 12207:2017 · IEC 62443-4-1:2018/2024 · NIST SP 800-190 · CIS Kubernetes Benchmark v1.9+

---

## Declaración de Visión

> **BOS no es un administrador de Ubuntu y Kubernetes.  
> BOS ES Ubuntu + Kubernetes + sus propias capacidades,  
> unificados bajo una única interfaz soberana: `bosctl`.**

La analogía correcta no es "BOS administra Ubuntu". La analogía correcta es:

- macOS **es** Darwin (kernel) + Cocoa + AppKit + sus propias apps, unificados bajo una marca y una experiencia
- Talos OS **es** Linux kernel + Kubernetes + su API, sin costuras entre capas
- **BOS es** Ubuntu (kernel + systemd + apt) + Kubernetes (scheduling + networking + RBAC) + BOS (ciclo de vida + fichas + IA + catálogo), presentados como **un único sistema operativo orientado al negocio**

El usuario final no sabe ni le importa que debajo hay Ubuntu y Kubernetes. Solo conoce `bosctl` y las fichas. **BOS es la experiencia completa.**

Referente técnico: Talos Linux usa una misma API para todo: actualizaciones automáticas, adición de nodos al cluster y cambios de configuración. Define el estado deseado con un único archivo YAML. Sin configuración manual, sin drift. Todo reproducible. BOS lleva ese concepto más lejos: no solo los nodos K8s, sino **el negocio completo** queda bajo una única superficie de control.

---

## Índice

1. [La Suma: BOS = Ubuntu + Kubernetes + BOS](#1-la-suma)
2. [Arquitectura Unificada — Una Sola Superficie de Control](#2-arquitectura-unificada)
3. [Mapa de Capacidades Unificadas](#3-mapa-de-capacidades-unificadas)
4. [Plan de Implementación por Dominio](#4-plan-de-implementación-por-dominio)
5. [bosctl — La CLI Soberana del Business OS](#5-bosctl)
6. [Comandos de Verificación por Dominio](#6-comandos-de-verificación-por-dominio)
7. [Trazabilidad a Estándares](#7-trazabilidad-a-estándares)
8. [Matriz de Riesgos y Mitigación](#8-matriz-de-riesgos-y-mitigación)
9. [Sprints y Criterio de Certificación](#9-sprints-y-criterio-de-certificación)
10. [D7 — BOS Installer: El ISO Bootable del Business OS](#10-d7--bos-installer-el-iso-bootable-del-business-os)

---

## 1. La Suma: BOS = Ubuntu + Kubernetes + BOS

### 1.1 Qué aporta cada capa a la suma

```
┌─────────────────────────────────────────────────────────────────────┐
│                   UBUNTU — La base del poder                        │
│                                                                     │
│  Aporta a BOS:                                                      │
│  • Kernel Linux — scheduler de CPU · cgroups v2 · namespaces       │
│  • systemd — ciclo de vida de procesos · journald · socket act.    │
│  • apt/dpkg — instalación de software del sistema base             │
│  • nftables — firewall y network routing del host                  │
│  • filesystem — /etc · /opt · /var · /proc · /sys                  │
│  • Todo esto BOS lo EXPONE como capacidades propias vía bosctl     │
└─────────────────────────────────────────────────────────────────────┘
              +
┌─────────────────────────────────────────────────────────────────────┐
│                   KUBERNETES — El motor de aplicaciones             │
│                                                                     │
│  Aporta a BOS:                                                      │
│  • Scheduling declarativo de workloads (pods, deployments)         │
│  • Self-healing nativo (restart policy, liveness probes)           │
│  • Networking de pods (CNI: kindnet/flannel/calico)                │
│  • RBAC nativo del API server                                       │
│  • etcd — estado distribuido del cluster                           │
│  • cAdvisor (en kubelet) — métricas de contenedores en tiempo real │
│  • kubectl API — interfaz programática a todo lo anterior          │
│  • Todo esto BOS lo EXPONE como capacidades propias vía bosctl     │
└─────────────────────────────────────────────────────────────────────┘
              +
┌─────────────────────────────────────────────────────────────────────┐
│                   BOS — Las capacidades originales                  │
│                                                                     │
│  Aporta a la suma:                                                  │
│  • State file unificado — estado de TODAS las fichas               │
│  • Ciclo de vida como SO de negocios (boot→run→watchdog→shutdown)  │
│  • Catálogo de fichas — instalar/versionar/rollback cualquier cosa  │
│  • bosctl RBAC — control de acceso a la CLI soberana               │
│  • Repair saga multi-capa (Ubuntu apt + K8s kubectl en un comando) │
│  • Agente IA integrado — diagnóstico y reparación autónoma         │
│  • Single pane of glass — UNA interfaz para el negocio completo    │
└─────────────────────────────────────────────────────────────────────┘
              =
┌═════════════════════════════════════════════════════════════════════┐
║          BOS BUSINESS OPERATING SYSTEM — LA SUMA TOTAL             ║
║                                                                     ║
║  Una única superficie: bosctl                                       ║
║  Un único estado: /etc/bos/.sbos_state.json                        ║
║  Un único ciclo de vida: boot → run → heal → evolve → shutdown     ║
║  Un único catálogo: fichas para OS · K8s · apps · seguridad · IA   ║
║  Un único punto de acceso privilegiado: bosctl                      ║
║                                                                     ║
║  El usuario final ve: BOS                                           ║
║  Lo que hay debajo: Ubuntu + Kubernetes + capacidades BOS propias   ║
└═════════════════════════════════════════════════════════════════════┘
```

### 1.2 El principio fundamental de la suma

Cuando el usuario ejecuta `bosctl repair`, BOS:
- Usa `apt` de Ubuntu si el problema es en el SO
- Usa `kubectl` de Kubernetes si el problema es en el cluster
- Usa su propia repair saga si el problema es de estado de fichas
- Todo en un único comando, con un único audit log, con un único resultado en el state file

El usuario **nunca** necesita saber que detrás hay apt y kubectl. BOS es el sistema operativo.

---

## 2. Arquitectura Unificada — Una Sola Superficie de Control

```
╔═════════════════════════════════════════════════════════════════════╗
║              BOS BUSINESS OPERATING SYSTEM                         ║
║                    bosctl — superficie soberana                     ║
╠═════════════════════════════════════════════════════════════════════╣
║                                                                     ║
║  ┌─────────────────────────────────────────────────────────────┐  ║
║  │              CAPACIDADES PROPIAS DE BOS                      │  ║
║  │  State file · Fichas · RBAC bosctl · Repair saga · IA agent │  ║
║  │  App catalog · Versioning · Lifecycle manager               │  ║
║  └─────────────────────────────────────────────────────────────┘  ║
║                              │ expone como propias                  ║
║  ┌──────────────────────────┐│┌─────────────────────────────────┐  ║
║  │  CAPA UBUNTU             ││  CAPA KUBERNETES                 │  ║
║  │  apt · systemd · nftables││  kubectl · RBAC · CNI · cAdvisor │  ║
║  │  cgroups · journald · fs ││  scheduler · etcd · helm · probes│  ║
║  └──────────────────────────┘└─────────────────────────────────┘  ║
║                              │ sobre                                ║
║  ┌─────────────────────────────────────────────────────────────┐  ║
║  │              KERNEL LINUX + HARDWARE                         │  ║
║  │  CPU · Memoria · Disco · Red — capa que BOS hereda          │  ║
║  └─────────────────────────────────────────────────────────────┘  ║
╚═════════════════════════════════════════════════════════════════════╝
```

**La regla de diseño de la suma:**

```
Si Ubuntu ya tiene la capacidad → BOS la incorpora y la expone via bosctl
Si Kubernetes ya tiene la capacidad → BOS la incorpora y la expone via bosctl
Si ninguno la tiene → BOS la construye y la expone via bosctl

En todos los casos: el usuario final solo ve bosctl.
En todos los casos: el resultado queda en el state file de BOS.
En todos los casos: hay audit log.
En todos los casos: hay una ficha.
```

---

## 3. Mapa de Capacidades Unificadas

| Capacidad BOS | Origen en la suma | Cómo BOS la unifica |
|---|---|---|
| **bosctl repair --target=os** | Ubuntu (apt + dpkg + systemctl) | BOS orquesta apt/dpkg/systemctl, registra en state file, audit log |
| **bosctl repair --target=k8s** | Kubernetes (kubectl drain/uncordon) | BOS orquesta la secuencia kubectl, registra en state file, audit log |
| **bosctl repair --target=all** | Ubuntu + Kubernetes | BOS ejecuta ambas sagas en orden correcto — UNA sola llamada |
| **bosctl install nginx** | Ubuntu apt | BOS llama a apt, genera ficha, registra estado, configura health_check |
| **bosctl install prometheus --backend=helm** | Kubernetes helm | BOS llama a helm, genera ficha K8s, registra estado, configura health_check |
| **bosctl install kube-state-metrics** | Kubernetes (CNCF) | BOS instala el DaemonSet, genera ficha, supervisa como parte del SO |
| **bosctl top** | Kubernetes cAdvisor + kubectl top | BOS consume métricas del kubelet/cAdvisor, presenta vista unificada |
| **bosctl logs \<pod\>** | Kubernetes kubectl logs | BOS envuelve kubectl logs con contexto del state file |
| **bosctl security scan** | Ubuntu + Kubernetes (CIS checks) | BOS verifica permisos Ubuntu (etcd, kubelet) + RBAC K8s + CNI activo |
| **bosctl ask "¿por qué falla?"** | Ubuntu (journald) + K8s (kubectl get all) + BOS (state file) | BOS agrega contexto de las tres capas y lo envía al LLM |
| **bosctl app rollback nginx** | Ubuntu apt (reinstala versión) ó K8s helm rollback | BOS decide qué backend usar y ejecuta el rollback correcto |
| **bosctl status \<ficha\>** | BOS state file | Vista unificada del estado de CUALQUIER componente |
| **bosctl shutdown** | Ubuntu (systemctl + poweroff) + K8s (drain saga) | BOS coordina el shutdown seguro de K8s antes de apagar Ubuntu |
| **bosctl --user \<rol\> \<cmd\>** | BOS propio (RBAC de la CLI) | Control de acceso a bosctl, independiente del RBAC de K8s |

---

## 4. Plan de Implementación por Dominio

### D1 — Reparación Unificada del Sistema (BOS = Ubuntu + Kubernetes)

**Valor central:** `bosctl repair` repara simultáneamente el SO Ubuntu, el cluster Kubernetes y las fichas BOS.

**Ficha nueva:** `sbos-repair`  
**Comando:** `bosctl repair --target=[os|k8s|node|all]`

**Archivos:**

| Archivo | Propósito |
|---|---|
| `src/internal/repair/os_repair.go` | Incorpora Ubuntu: llama a apt --fix-broken, dpkg --audit, systemctl restart |
| `src/internal/repair/k8s_node_repair.go` | Incorpora K8s: llama a kubectl cordon/drain/uncordon |
| `src/internal/repair/repair_manager.go` | Lógica original de BOS: orquesta ambas capas, decide el orden, maneja timeouts |
| `src/internal/repair/health_verifier.go` | Post-repair: verifica que Ubuntu Y K8s quedaron sanos |
| `staging/core/servers/hostserver/sbos-repair/manifest.yml` | Ficha BOS con health_check dual (SO + cluster) |

**Secuencia `bosctl repair --target=all`:**

```
BOS repair saga — sistema completo:

FASE 1 — Ubuntu (capa base)
  1. Detectar paquetes rotos: dpkg --audit
  2. Reparar: apt --fix-broken install -y (timeout 60s)
  3. Verificar críticos: containerd · kubelet · systemd
  4. Reiniciar servicios afectados: systemctl restart <servicio>

FASE 2 — Kubernetes (capa de orquestación)
  5. Verificar nodos: kubectl get nodes
  6. Para cada nodo NotReady > umbral:
     kubectl cordon → drain → systemctl restart kubelet → uncordon
  7. Verificar pods críticos del control plane: etcd · apiserver · coredns

FASE 3 — Estado BOS (capa de negocio)
  8. Reconciliar state file
  9. Para cada ficha degradada: ejecutar su repair saga específica
  10. Actualizar state file: sbos-repair → REPARADO

FASE 4 — Verificación integral
  11. Ubuntu: dpkg -l | grep -v ^ii → 0 paquetes rotos
  12. K8s: kubectl get nodes → todos Ready
  13. K8s: kubectl get pods -A → todos Running/Completed
  14. BOS: bosctl status → todas las fichas HEALTHY
  15. Audit log: repair-all phases=4 ubuntu=OK k8s=OK bos=OK
```

---

### D2 — Package Manager Unificado (apt + pip + helm en una sola superficie)

**Valor central:** `bosctl install` es el gestor de paquetes del Business OS. Un solo comando instala software del SO Ubuntu (apt), librerías Python (pip) o aplicaciones Kubernetes (helm), y todo queda registrado en el catálogo unificado de BOS.

**Ficha nueva:** `sbos-package-manager`  
**Comandos:** `bosctl install` · `bosctl remove` · `bosctl upgrade`

**Archivos:**

| Archivo | Propósito |
|---|---|
| `src/internal/packages/apt_adapter.go` | Incorpora Ubuntu apt |
| `src/internal/packages/pip_adapter.go` | Incorpora Python pip3 |
| `src/internal/packages/helm_adapter.go` | Incorpora K8s helm |
| `src/internal/packages/package_manager.go` | Lógica BOS: detecta backend, delega, registra |
| `src/internal/packages/ficha_generator.go` | **Original BOS**: genera manifest.yml con health_check automático |

**Lo que BOS suma:**

```
Sin BOS:
  apt install nginx     → nginx instalado en Ubuntu (estado en dpkg)
  helm install prom ... → Prometheus instalado en K8s (estado en helm)
  pip install numpy     → numpy instalado en Python (estado en pip)
  → Tres estados en tres lugares distintos. Sin visión unificada.

Con BOS:
  bosctl install nginx
  bosctl install prometheus --backend=helm
  bosctl install numpy --backend=pip
  → Tres instalaciones ejecutadas via sus backends nativos
  → Un solo catálogo: bosctl app list muestra TODO
  → Un solo health check: bosctl status <ficha>
  → Un solo rollback: bosctl app rollback <ficha>
```

**Auto-generación de ficha post-install:**

```yaml
# /etc/bos/fichas/nginx/manifest.yml
name: sbos-app-nginx
version: "1.26.0"
backend: apt
package: nginx
installed_at: "2026-05-19T14:00:00Z"
health_check:
  type: systemctl
  service: nginx
  expected: active
lifecycle:
  start: systemctl start nginx
  stop: systemctl stop nginx
  status: systemctl is-active nginx
```

```yaml
# /etc/bos/fichas/prometheus/manifest.yml
name: sbos-app-prometheus
version: "2.51.0"
backend: helm
chart: prometheus-community/kube-prometheus-stack
namespace: monitoring
installed_at: "2026-05-19T14:00:00Z"
health_check:
  type: kubectl
  resource: deployment/prometheus-server
  namespace: monitoring
  expected: Available
```

---

### D3 — Observabilidad Unificada (cAdvisor + kube-state-metrics + journald = bosctl top)

**Valor central:** BOS incorpora las métricas que ya existen en Ubuntu (journald, /proc) y Kubernetes (cAdvisor en kubelet, kube-state-metrics) y las presenta en una vista unificada del negocio.

**Fichas nuevas:** `sbos-app-kube-state-metrics` · `sbos-app-node-exporter` · `sbos-container-watchdog`  
**Comandos nuevos:** `bosctl top` · `bosctl logs` · `bosctl health`

**Vista de `bosctl top`:**

```
bosctl top
┌──────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  NODO (fuente: Ubuntu /proc + kubectl top nodes)                    │
│                                                                      │
│  FICHAS BOS (fuente: /etc/bos/.sbos_state.json)                     │
│  sbos-bootstrap-os        INSTALADA--OK   HEALTHY                   │
│  sbos-bootstrap-k8s       INSTALADA--OK   HEALTHY                   │
│  sbos-app-nginx           INSTALADA--OK   HEALTHY   v1.26.0        │
│  sbos-app-prometheus      INSTALADA--OK   HEALTHY   v2.51.0        │
│                                                                      │
│  PODS K8s (fuente: kube-state-metrics + cAdvisor en kubelet)        │
│  kube-system   coredns-*          2m    18Mi   Running              │
│  kube-system   etcd-*            48m   128Mi   Running              │
│  kube-system   kube-apiserver-* 120m   256Mi   Running              │
│  monitoring    prometheus-*       35m    64Mi   Running              │
└──────────────────────────────────────────────────────────────────────┘
```

**Ciclo del Watchdog Unificado (Ubuntu + Kubernetes):**

```
Cada 30s — BOS watchdog unificado:

UBUNTU:
  1. df -h / → si disk > 85% → alert + cleanup de logs viejos
  2. free -m → si mem > 90% → alert en journal
  3. systemctl is-active containerd kubelet → si falla → bosctl repair --target=os

KUBERNETES:
  4. kubectl get nodes → NotReady > umbral → bosctl repair --target=node
  5. kubectl get pods -A (vía kube-state-metrics si disponible)
     CrashLoop con restartCount > umbral → kubectl rollout restart deployment/<>
     Pending > 5min → alert + kubectl describe pod en audit log

BOS:
  6. Verificar health_check de cada ficha en state file
     Ficha INSTALADA--OK con health DEGRADED → escalar repair saga de la ficha
  7. Registrar: watchdog cycle=N ubuntu=OK k8s=OK fichas=N_HEALTHY/M_TOTAL
```

---

### D4 — Agente IA del Business OS (Capacidad Original)

**Valor central:** `bosctl ask` envía al LLM contexto de las TRES capas (Ubuntu + Kubernetes + estado de fichas BOS) y responde en el idioma del negocio.

**Ficha nueva:** `sbos-ai-agent`  
**Comandos:** `bosctl ask` · `bosctl diagnose` · `bosctl explain` · `bosctl plan`

**Archivos:**

| Archivo | Propósito |
|---|---|
| `src/internal/ai/context_builder.go` | Agrega contexto de Ubuntu (journald) + K8s (kubectl get all) + BOS (state file) |
| `src/internal/ai/claude_client.go` | Cliente HTTP para api.anthropic.com/v1/messages |
| `src/internal/ai/response_parser.go` | Extrae comandos bosctl propuestos |
| `src/cmd/bosctl/ask.go` | CLI ask/diagnose/explain/plan |

**Contexto que el LLM recibe:**

```json
{
  "bos_state": { "...state file completo..." },
  "ubuntu": {
    "journal_last_100": ["..."],
    "disk_usage": "28%",
    "memory": "34%",
    "failed_services": []
  },
  "kubernetes": {
    "nodes": ["..."],
    "pods_degraded": ["..."],
    "events_last_50": ["..."],
    "kube_state_metrics": {}
  }
}
```

**Seguridad:**

```
- ANTHROPIC_API_KEY en /etc/bos/secrets/ai.key (chmod 600, owner bos)
- Nunca en journal ni en audit log
- Timeout 30s — no bloquea el daemon
- dry-run por defecto
- Audit log: ai_query=ask tokens=1024 result=OK (sin contenido de query ni respuesta)
```

---

### D5 — Catálogo de Aplicaciones (Estado Unificado del Negocio)

**Valor central:** Un único `bosctl app list` muestra el inventario completo de todo lo que corre en el Business OS.

**Ficha nueva:** `sbos-app-catalog`  
**Comandos:** `bosctl app list` · `bosctl app rollback` · `bosctl app history`

**Archivos:**

| Archivo | Propósito |
|---|---|
| `src/internal/catalog/catalog.go` | Índice unificado de fichas: Ubuntu + K8s + apps de negocio |
| `src/internal/catalog/versioning.go` | Snapshots del state file antes de cada cambio |
| `src/internal/catalog/rollback.go` | Rollback inteligente: apt reinstall ó helm rollback según backend |

**Salida de `bosctl app list`:**

```
═══════════════════════════════════════════════════════════════
CATEGORÍA: SO BASE (Ubuntu)
  sbos-bootstrap-os         1.0   INSTALADA--OK   HEALTHY   2026-05-19

CATEGORÍA: ORQUESTACIÓN (Kubernetes)
  sbos-bootstrap-k8s        1.0   INSTALADA--OK   HEALTHY   2026-05-19
  sbos-bootstrap-hardening  1.0   INSTALADA--OK   HEALTHY   2026-05-19

CATEGORÍA: OBSERVABILIDAD
  sbos-app-kube-state-metrics 2.10 INSTALADA--OK  HEALTHY   2026-05-19
  sbos-app-node-exporter    1.7   INSTALADA--OK   HEALTHY   2026-05-19
  sbos-app-prometheus       2.51  INSTALADA--OK   HEALTHY   2026-05-19

CATEGORÍA: APLICACIONES DE NEGOCIO
  sbos-app-nginx            1.26  INSTALADA--OK   HEALTHY   2026-05-19
  sbos-app-facturacion      3.2   INSTALADA--OK   HEALTHY   2026-05-19

CATEGORÍA: IA Y DIAGNÓSTICO
  sbos-ai-agent             1.0   INSTALADA--OK   HEALTHY   2026-05-19

RESUMEN: 9 fichas · 9 HEALTHY · 0 DEGRADED · 0 BLOQUEADA
```

**Rollback unificado según backend:**

```
bosctl app rollback nginx --to=1.24.0
  Backend apt:  BOS ejecuta apt install nginx=1.24.0
  Actualiza state file: version=1.24.0
  Verifica health_check: systemctl is-active nginx
  Si falla → restaura snapshot del state file

bosctl app rollback prometheus --to=2.48.0
  Backend helm: BOS ejecuta helm rollback sbos-app-prometheus <revision>
  Actualiza state file: version=2.48.0
  Verifica health_check: kubectl get deployment prometheus-server
  Si falla → helm rollback a la versión anterior
```

---

### D6 — Seguridad Unificada (Ubuntu hardening + Kubernetes RBAC + bosctl RBAC)

**Valor central:** La seguridad del Business OS es la suma de tres capas: hardening del SO Ubuntu, RBAC nativo de Kubernetes, y RBAC propio de bosctl.

**Fichas:** `sbos-bootstrap-hardening` · `sbos-security`

**Dos tipos de RBAC coexistentes:**

```
RBAC DE KUBERNETES (nativo del API server):
  • Controla: quién puede hacer qué sobre recursos K8s
  • Dueño técnico: Kubernetes API server
  • Rol de BOS: aplica los manifests RBAC via kubectl apply

RBAC DE bosctl (propio de BOS):
  • Controla: quién puede ejecutar qué comando bosctl
  • Dueño técnico: BOS daemon
  • Rol de BOS: implementa y hace cumplir

Ambos RBAC coexisten y se complementan en el Business OS.
```

**Tareas de sbos-bootstrap-hardening:**

```
Task 1: ubuntu-hardening
  • Permisos de etcd: chmod 700 /var/lib/etcd
  • Verificación filesystem BOS: /etc/bos/secrets/ chmod 700
  CIS K8s Benchmark §1.1.11

Task 2: kubelet-hardening
  • Verificar y aplicar en /var/lib/kubelet/config.yaml:
      anonymousAuth: false
      authorization.mode: Webhook
      protectKernelDefaults: true
      readOnlyPort: 0
  CIS K8s Benchmark §4.2

Task 3: k8s-apiserver-hardening
  • Verificar --anonymous-auth=false y --audit-log-path en kube-apiserver
  CIS K8s Benchmark §1.2

Task 4: cni-health
  • Verificar que el CNI (kindnet) está activo y gestionando FORWARD
  • kubectl get pods -n kube-system | grep kindnet → Running

Task 5: k8s-rbac-baseline
  • Aplicar manifests RBAC de K8s para el cluster BOS
  • Verificar: kubectl auth can-i delete pods --as=default → no

Task 6: bosctl-rbac
  • Crear /etc/bos/rbac/roles.json:
      admin   : todos los comandos bosctl
      operator: install · repair · top · ask · logs · diagnose
      readonly: status · top · logs · app list
```

**`bosctl security scan`:**

```
══════════════════════════════════════════════════════
UBUNTU HARDENING
  [PASS] /var/lib/etcd permissions: 700                  CIS §1.1.11
  [PASS] /etc/bos/secrets permissions: 700               ISO 27001
  [PASS] ANTHROPIC_API_KEY not in journal                 ISO 27001

KUBERNETES HARDENING
  [PASS] kubelet anonymous-auth: false                    CIS §4.2.1
  [PASS] kubelet protect-kernel-defaults: true            CIS §4.2.6
  [PASS] kube-apiserver anonymous-auth: false             CIS §1.2.1
  [PASS] CNI kindnet: Running, FORWARD rules: OK          NIST 800-190
  [PASS] K8s RBAC baseline applied                        CIS §5.1

BOS RBAC
  [PASS] bosctl RBAC roles configured                     IEC 62443-4-2
  [PASS] readonly role cannot execute repair              IEC 62443-4-2

SCORE: 10/10 — 100% ✅
══════════════════════════════════════════════════════
```

---

## 5. bosctl — La CLI Soberana del Business OS

`bosctl` es la única interfaz del Business OS. No existe sudo para operaciones de BOS. No existe kubectl directo para los usuarios del negocio. Todo pasa por bosctl.

### Mapa completo de comandos por dominio:

```
bosctl
│
├── SISTEMA (Ubuntu + K8s unificados)
│   ├── bosctl status [ficha]        → estado de cualquier componente
│   ├── bosctl repair --target=      → repara OS, K8s, nodo, o todo
│   ├── bosctl top                   → vista unificada de métricas
│   ├── bosctl logs <pod/servicio>   → logs unificados
│   └── bosctl health                → health report completo del sistema
│
├── SOFTWARE (apt + pip + helm unificados)
│   ├── bosctl install <pkg>         → instala en el backend correcto + registra ficha
│   ├── bosctl remove <pkg>          → desinstala + limpia ficha
│   └── bosctl upgrade <pkg>         → actualiza + versiona en catálogo
│
├── APLICACIONES (catálogo unificado)
│   ├── bosctl app list              → inventario completo Ubuntu+K8s+apps
│   ├── bosctl app history <ficha>   → historial de versiones
│   └── bosctl app rollback <ficha>  → rollback vía apt ó helm según backend
│
├── SEGURIDAD
│   ├── bosctl security scan         → CIS check Ubuntu + K8s + bosctl RBAC
│   └── bosctl security audit        → audit log de todas las acciones
│
└── IA (capacidad original)
    ├── bosctl ask "<pregunta>"      → LLM con contexto Ubuntu+K8s+BOS
    ├── bosctl diagnose              → diagnóstico autónomo sin pregunta
    ├── bosctl explain <ficha>       → explicación de una ficha o estado
    └── bosctl plan "<objetivo>"     → plan de acción propuesto por IA
```

### RBAC de bosctl:

```json
{
  "roles": {
    "admin":    ["*"],
    "operator": ["install","remove","repair","top","logs","ask","diagnose","app"],
    "readonly": ["status","top","logs","health","app list","explain"]
  },
  "users": {
    "skull": "admin"
  }
}
```

---

## 6. Comandos de Verificación por Dominio

### D1 — Reparación
```bash
bosctl repair --target=all
# Esperado: ubuntu=OK k8s=OK bos=OK en audit log

bosctl repair --target=os --dry-run
# Esperado: "Would run: apt --fix-broken install (no packages broken)"

journalctl -u bos.service | grep "repair-all"
# Esperado: repair-all phases=4 ubuntu=OK k8s=OK bos=OK
```

### D2 — Package Manager
```bash
bosctl install nginx
bosctl install prometheus --backend=helm
bosctl install numpy --backend=pip

bosctl app list
# Esperado: los tres en el catálogo unificado, todos HEALTHY

bosctl remove nginx
bosctl status sbos-app-nginx
# Esperado: DESINSTALADA
```

### D3 — Observabilidad
```bash
bosctl install kube-state-metrics
bosctl install node-exporter

bosctl top
# Esperado: vista unificada Ubuntu (CPU/mem/disk) + K8s pods + fichas BOS

bosctl health
# Esperado: Ubuntu OK · K8s OK · N fichas HEALTHY
```

### D4 — IA Agent
```bash
export ANTHROPIC_API_KEY="sk-ant-..."

bosctl ask "¿está el Business OS saludable?"
# Esperado: respuesta en español con análisis de las tres capas

bosctl diagnose
# Esperado: diagnóstico autónomo + lista de comandos bosctl propuestos

journalctl -u bos.service | grep -i "api_key\|sk-ant"
# Esperado: sin resultados — key nunca logueada
```

### D5 — App Catalog
```bash
bosctl app list
# Esperado: catálogo completo categorizado

bosctl app rollback nginx --to=1.24.0
bosctl status sbos-app-nginx
# Esperado: INSTALADA -- OK · version=1.24.0
```

### D6 — Seguridad
```bash
bosctl security scan
# Esperado: score 100% — Ubuntu + K8s + bosctl RBAC todos PASS

bosctl --user readonly repair --target=os 2>&1
# Esperado: ERROR: insufficient permissions (role=readonly)

kubectl auth can-i delete pods --as=system:serviceaccount:default:default
# Esperado: no

bosctl status sbos-bootstrap-hardening
# Esperado: INSTALADA -- OK | HEALTHY
```

---

## 7. Trazabilidad a Estándares Internacionales

### ISO/IEC 25010:2023

| Característica | Sub-característica | BOS como Business OS |
|---|---|---|
| Functional Suitability | Completeness | bosctl cubre TODO: Ubuntu + K8s + apps + IA |
| Reliability | Availability | Watchdog unificado Ubuntu+K8s; Restart=on-failure; reconcile al boot |
| Reliability | Fault Tolerance | Repair saga multi-capa; self-healing K8s + BOS como segundo nivel |
| Reliability | Recoverability | bosctl repair --target=all; state file 3 niveles; rollback por ficha |
| Security | Confidentiality | API key nunca logueada; secretos chmod 600; TLS en endpoints BOS |
| Security | Accountability | Audit log unificado en journald para TODA acción en las tres capas |
| Security | Authenticity | bosctl RBAC (propio) + K8s RBAC (aplicado) — seguridad en profundidad |
| Maintainability | Modularity | Arquitectura de fichas: cada componente es una ficha |
| Maintainability | Modifiability | Rollback por ficha; snapshots del state file antes de cada cambio |
| Compatibility | Interoperability | bosctl envuelve apt+pip+helm+kubectl — interfaz unificada |
| Safety | Harm avoidance | dry-run en AI agent; confirmación explícita; lista negra de comandos |

### Referentes del ecosistema

| Referente | Qué valida |
|---|---|
| **Talos OS** | Diseñado expresamente para K8s. Sin SSH ni acceso a consola. Todo API-driven. BOS va más lejos: no solo K8s, sino el negocio completo. |
| **Platform Engineering / IDP** | Capa de abstracción — un SO para los desarrolladores de la organización. BOS es exactamente eso en la capa de infraestructura. |
| **Single Pane of Glass** | Vista unificada de sistemas e infraestructura. `bosctl top` + `bosctl app list` + `bosctl health` es el SPOG de BOS. |

### Posición de BOS en el ecosistema

```
Talos OS          → Linux + K8s como OS inmutable, API-driven, para nodos K8s
BOS Business OS   → Ubuntu + K8s + IA como OS mutable, CLI-driven, para negocios

Diferencias con Talos:
  - BOS mantiene mutabilidad (apt install, configuración)
  - BOS agrega IA integrada (bosctl ask/diagnose)
  - BOS tiene catálogo de fichas con versionado y rollback
  - BOS gestiona aplicaciones de negocio, no solo nodos K8s
  - BOS mantiene Ubuntu como base familiar
```

---

## 8. Matriz de Riesgos y Mitigación

| ID | Riesgo | Dom. | Prob. | Impacto | Mitigación |
|---|---|---|---|---|---|
| R01 | apt --fix-broken falla con dependencias circulares | D1 | Baja | Alto | Timeout 60s + fallback dpkg --configure -a + audit ERROR |
| R02 | helm rollback incompatible con estado K8s actual | D5 | Baja | Alto | Health check post-rollback; si falla → revertir snapshot state |
| R03 | Pod watchdog actúa antes que K8s agote sus reintentos | D3 | Media | Medio | Esperar restartCount > umbral configurable |
| R04 | LLM devuelve comando destructivo (kubectl delete --all) | D4 | Baja | Alto | dry-run obligatorio + lista negra de patrones peligrosos |
| R05 | Confusión entre bosctl RBAC y K8s RBAC | D6 | Media | Medio | Tests que validan ambos RBAC independientemente |
| R06 | API key Anthropic expuesta en logs | D4 | Media | Alto | api_key_env únicamente; grep en journal como test automático |
| R07 | kube-state-metrics incompatible con versión K8s | D3 | Baja | Medio | Verificación de compatibilidad semántica en bosctl install |
| R08 | Hardening de kubelet flags rompe pods existentes | D6 | Media | Alto | Aplicar flags en dry-run primero; verificar pods Running post-apply |
| R09 | State file corrupto invalida el catálogo completo | NUCL | Muy baja | Crítico | 3 niveles de fallback (tmp→rename→bak); reconcile al boot |
| R10 | bosctl top sin metrics-server ni kube-state-metrics | D3 | Media | Bajo | Degradar a kubectl describe node; alertar para instalar ficha |

---

## 9. Sprints y Criterio de Certificación

### Plan de sprints

| Sprint | Dominio | Entregable Business OS | Fichas |
|---|---|---|---|
| Sprint 5 | D6 | sbos-bootstrap-hardening · Ubuntu hardening · K8s RBAC · bosctl RBAC · CNI health · security scan | sbos-bootstrap-hardening · sbos-security |
| Sprint 6 | D1 | bosctl repair --target=all (Ubuntu+K8s+BOS en un comando) | sbos-repair |
| Sprint 7 | D2 | bosctl install (apt+pip+helm unificados) · ficha auto-generada | sbos-package-manager |
| Sprint 8 | D3 | kube-state-metrics+node-exporter como fichas · bosctl top · watchdog unificado | sbos-app-kube-state-metrics · sbos-app-node-exporter · sbos-container-watchdog |
| Sprint 9 | D5 | bosctl app list (catálogo categorizado) · rollback inteligente | sbos-app-catalog |
| Sprint 10 | D4 | bosctl ask/diagnose con contexto Ubuntu+K8s+BOS · dry-run · seguridad de key | sbos-ai-agent |
| Sprint 11 | D7 | BOS Installer ISO · pantallas branded · instalación desatendida completa · modo offline y online | sbos-installer · bos-installer.iso |

### Criterio de elevación: BOS = Business Operating System certificado

```bash
# === CERTIFICACIÓN BOS BUSINESS OS ===

# 1. Reparación unificada (Ubuntu + K8s + BOS)
bosctl repair --target=all
echo "[D1] Repair multi-capa: OK"

# 2. Package manager unificado
bosctl install curl && bosctl remove curl
bosctl install prometheus --backend=helm
echo "[D2] Package manager unificado: OK"

# 3. Observabilidad del Business OS
bosctl top
bosctl health
echo "[D3] Vista unificada Ubuntu+K8s+fichas: OK"

# 4. Catálogo unificado del negocio
bosctl app list | grep -E "SO Base|Orquestación|Observabilidad|Negocio|IA"
echo "[D5] Catálogo categorizado: OK"

# 5. Seguridad en profundidad (Ubuntu + K8s + bosctl)
bosctl security scan | grep "100%"
bosctl --user readonly repair 2>&1 | grep "insufficient permissions"
kubectl auth can-i delete pods --as=default | grep "^no$"
echo "[D6] Seguridad tres capas: OK"

# 6. IA del Business OS
bosctl ask "¿está el Business OS saludable?" | grep -i "saludable\|healthy\|OK"
echo "[D4] IA integrada: OK"

# 7. Integridad del state file (corazón de BOS)
bosctl status sbos-bootstrap-os
bosctl status sbos-bootstrap-k8s
bosctl status sbos-bootstrap-hardening
bosctl status sbos-ai-agent
echo "[NUCLEO] State file íntegro: OK"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   BOS BUSINESS OPERATING SYSTEM — CERTIFICADO       ║"
echo "║   Ubuntu + Kubernetes + BOS = UN SOLO SISTEMA       ║"
echo "╚══════════════════════════════════════════════════════╝"
```

---

## Apéndice A — BOS vs. un SO convencional: propiedad y herencia

| Propiedad de un SO | Quién la aporta en BOS |
|---|---|
| Kernel y hardware | Linux (heredado de Ubuntu) |
| Gestión de procesos | systemd de Ubuntu + kubelet de K8s (heredados) |
| Cgroups v2 | Linux kernel (heredado de Ubuntu) |
| Ciclo de vida del SO | **BOS propio** (boot→watchdog→repair→shutdown saga) |
| Gestión de software | Ubuntu apt + K8s helm + pip (heredados) · **BOS unifica en bosctl install** |
| Networking del host | Ubuntu nftables (heredado) |
| Networking de pods | CNI K8s — kindnet (heredado) |
| RBAC del cluster | K8s API server (heredado) · **BOS lo aplica y verifica** |
| RBAC de la CLI | **BOS propio** (bosctl RBAC) |
| Scheduling de pods | K8s scheduler (heredado) |
| Self-healing de pods | K8s restart policy (heredado) · **BOS como segundo nivel** |
| Métricas de contenedores | cAdvisor en kubelet (heredado) · **BOS instala kube-state-metrics** |
| Filesystem canónico | /opt/bos · /etc/bos · /etc/bos/secrets · /etc/bos/catalog |
| Audit log | journald de Ubuntu (heredado) · **BOS escribe su audit log en él** |
| Estado unificado | **BOS propio** — /etc/bos/.sbos_state.json |
| Catálogo de apps | **BOS propio** — fichas con versioning y rollback |
| IA integrada | **BOS propio** — bosctl ask/diagnose |
| Interfaz única | **BOS propio** — bosctl |

---

## Apéndice B — Estado de fichas al completar todos los sprints

| Ficha | Categoría | Estado Objetivo | Sprint |
|---|---|---|---|
| sbos-bootstrap-os | SO Base | INSTALADA -- OK ✅ | Certificado |
| sbos-bootstrap-k8s | Orquestación | INSTALADA -- OK ✅ | Certificado |
| sbos-bootstrap-hardening | Seguridad | INSTALADA -- OK | Sprint 5 |
| sbos-security | Seguridad | INSTALADA -- OK | Sprint 5 |
| sbos-repair | Sistema | INSTALADA -- OK | Sprint 6 |
| sbos-package-manager | Sistema | INSTALADA -- OK | Sprint 7 |
| sbos-app-kube-state-metrics | Observabilidad | INSTALADA -- OK | Sprint 8 |
| sbos-app-node-exporter | Observabilidad | INSTALADA -- OK | Sprint 8 |
| sbos-app-prometheus | Observabilidad | INSTALADA -- OK | Sprint 8 |
| sbos-container-watchdog | Sistema | INSTALADA -- OK | Sprint 8 |
| sbos-app-catalog | Negocio | INSTALADA -- OK | Sprint 9 |
| sbos-ai-agent | IA | INSTALADA -- OK | Sprint 10 |
| sbos-installer | Infraestructura | INSTALADA -- OK | Sprint 11 |

---

## 10. D7 — BOS Installer: El ISO Bootable del Business OS

### 10.1 Visión: BOS se instala como un sistema operativo real

Un sistema operativo de negocios real no se instala con scripts manuales. Se instala desde un medio bootable — USB o CD — con una experiencia visual propia, pantallas con la identidad de marca, mensajes que explican al usuario qué está instalando y por qué, exactamente como lo hace Ubuntu, Windows o macOS.

**BOS Installer es el D7 que convierte a BOS en un OS de primera clase:**

```
El usuario inserta el USB con bos-installer.iso
    ↓
La máquina bootea desde el USB
    ↓
Aparece la pantalla de bienvenida de BOS Business OS
(logo, colores corporativos, descripción del sistema)
    ↓
El instalador guía o trabaja desatendido mostrando:
  "Instalando Ubuntu 26.04 — base del sistema..."
  "Configurando Kubernetes — motor de aplicaciones..."
  "Instalando BOS — sistema operativo de negocios..."
  "Aplicando fichas de seguridad..."
  "BOS Business OS listo."
    ↓
La máquina reinicia y arranca directamente en BOS
bosctl status → todas las fichas HEALTHY
```

### 10.2 Fundamentos técnicos investigados

La tecnología que hace posible el BOS Installer ya existe y está probada en producción:

**Ubuntu Autoinstall (base técnica principal):**
Ubuntu soporta instalación completamente desatendida desde la versión 20.04 LTS usando el formato autoinstall con archivos YAML. El instalador responde todas las preguntas de configuración por adelantado y corre sin ninguna interacción humana. Soporta configuración compleja de disco (LVM, RAID, cifrado), gestión de usuarios, instalación de paquetes y ejecución de scripts personalizados post-instalación mediante `late-commands`.

Fuente oficial: `canonical-subiquity.readthedocs-hosted.com/en/latest/intro-to-autoinstall.html`

**Referente conceptual — Talos OS:**
Talos Linux está diseñado desde cero como un OS seguro, inmutable y mínimo para Kubernetes. Elimina el configuration drift tratando la infraestructura como código. Un único archivo YAML define el estado deseado. Sin configuración manual, sin drift, todo reproducible. Con `talosctl` se puede limpiar y re-bootstrapear el cluster completo con un solo comando. BOS lleva ese concepto más lejos: no solo nodos K8s, sino el negocio completo.

Fuente: `talos.dev` · `docs.siderolabs.com/talos/v1.9/platform-specific-installations/bare-metal-platforms/iso`

**Herramientas de construcción del ISO:**
La cadena de herramientas estándar para construir ISOs personalizadas de Ubuntu incluye `xorriso` para reempaquetar el ISO, `livefs-editor` para modificar el filesystem del live system, GRUB como bootloader configurable, y `cloud-init` para la configuración post-instalación. Existe incluso CUBIC (Custom Ubuntu ISO Creator) como herramienta gráfica para prototipado.

### 10.3 Arquitectura del BOS Installer

```
bos-installer.iso
├── GRUB bootloader (modificado — pantalla BOS branded)
│   ├── grub.cfg → autoboot en 10s con countdown BOS
│   └── grub.theme → colores y logo corporativo BOS
│
├── /casper/                          ← Ubuntu live system
│   ├── vmlinuz                       ← kernel Ubuntu 26.04
│   └── initrd                        ← initramfs
│
├── /nocloud/                         ← autoinstall config
│   ├── user-data                     ← YAML principal (define TODO)
│   └── meta-data                     ← vacío (requerido por cloud-init)
│
├── /bos-payload/                     ← payload BOS (modo offline)
│   ├── bin/
│   │   ├── bos                       ← daemon BOS compilado
│   │   └── bosctl                    ← CLI BOS
│   ├── fichas/                       ← las 114+ fichas
│   ├── images/                       ← imágenes containerd pre-descargadas
│   │   ├── pause:3.10
│   │   ├── etcd:3.5.24-0
│   │   └── kube-apiserver:v1.32.13
│   └── bos-bootstrap.sh             ← script de bootstrap post-Ubuntu
│
└── /bos-branding/                    ← identidad visual
    ├── splash.png                    ← pantalla de bienvenida
    ├── progress-screens/             ← pantallas de progreso
    │   ├── 01-ubuntu.png
    │   ├── 02-kubernetes.png
    │   ├── 03-bos-fichas.png
    │   └── 04-complete.png
    └── bos-installer-ui              ← binario de la UI (Python/TUI)
```

### 10.4 Secuencia técnica completa de instalación

```
FASE 0 — Boot (GRUB)
  ┌─────────────────────────────────────────────┐
  │  BOS BUSINESS OPERATING SYSTEM v1.0         │
  │                                             │
  │  [logo BOS]                                 │
  │                                             │
  │  Instalando BOS Business OS en este equipo  │
  │  El proceso toma aproximadamente 15 minutos  │
  │                                             │
  │  Iniciando en 10 segundos...               │
  │  [Presiona cualquier tecla para opciones]   │
  └─────────────────────────────────────────────┘
  Parámetro GRUB:
    linux /casper/vmlinuz autoinstall quiet splash
    ds=nocloud;s=/cdrom/nocloud/

FASE 1 — Ubuntu Autoinstall (subiquity)
  Pantalla: "BOS Installer — Preparando el sistema base..."
  user-data YAML ejecuta:
    - Particionado: LVM estándar (/, /var, swap)
    - Usuario: bos-admin (sin sudo expuesto al negocio)
    - Paquetes base: openssh-server, curl, git, python3, apt-transport-https
    - SSH keys: clave pública del administrador BOS
  Duración estimada: 5-8 minutos

FASE 2 — late-commands (ejecutados por subiquity en chroot)
  Pantalla: "BOS Installer — Instalando motor de contenedores..."
  Acciones:
    a. Instalar containerd desde payload offline o internet
    b. Instalar kubelet, kubeadm, kubectl (versión fijada)
    c. Configurar /etc/systemd/logind.conf.d/kubelet.conf
       (InhibitDelayMaxSec=90 — requerido para GracefulNodeShutdown)
    d. Copiar binarios BOS: /opt/bos/bin/bos y bosctl
    e. Copiar fichas a /etc/bos/blibs/servers/
    f. Instalar bos.service como systemd unit
    g. systemctl enable bos.service
  Duración estimada: 3-5 minutos

FASE 3 — primer boot con BOS daemon
  Pantalla TUI de progreso (bos-installer-ui corriendo como servicio):
  ┌─────────────────────────────────────────────┐
  │  BOS BUSINESS OPERATING SYSTEM              │
  │                                             │
  │  [████████░░░░░░░░░░░░] 45%                │
  │                                             │
  │  ✅ Ubuntu 26.04 instalado                  │
  │  ✅ Kubernetes v1.32 configurado            │
  │  🔄 Instalando fichas de sistema...         │
  │     sbos-bootstrap-os    [COMPLETADO]       │
  │     sbos-bootstrap-k8s   [EN PROGRESO...]   │
  │     sbos-bootstrap-hardening [PENDIENTE]    │
  │                                             │
  │  No apague el equipo durante la instalación │
  └─────────────────────────────────────────────┘
  BOS daemon arranca y ejecuta auto-install topológico:
    sbos-bootstrap-os → sbos-bootstrap-k8s → sbos-lifecycle
    → sbos-bootstrap-hardening → fichas adicionales configuradas

FASE 4 — Instalación completa
  ┌─────────────────────────────────────────────┐
  │  BOS BUSINESS OPERATING SYSTEM              │
  │                                             │
  │  [████████████████████] 100%               │
  │                                             │
  │  ✅ Ubuntu 26.04 LTS                        │
  │  ✅ Kubernetes v1.32.13                     │
  │  ✅ BOS Business OS v1.0                    │
  │  ✅ 8 fichas instaladas y verificadas        │
  │                                             │
  │  BOS listo. Reiniciando en 10 segundos...  │
  │                                             │
  │  Accede con: bosctl status                  │
  └─────────────────────────────────────────────┘
  El USB puede retirarse. El sistema bootea desde disco.
```

### 10.5 El user-data YAML — corazón del instalador

```yaml
#cloud-config
autoinstall:
  version: 1

  # Identidad del sistema
  identity:
    hostname: bos-node-01
    username: bos-admin
    password: "$6$rounds=4096$..."   # hash generado en build time

  # Idioma y teclado
  locale: es_ES.UTF-8
  keyboard:
    layout: es

  # Red — DHCP por defecto, configurable
  network:
    network:
      version: 2
      ethernets:
        eth0:
          dhcp4: true

  # Disco — LVM estándar
  storage:
    layout:
      name: lvm

  # SSH
  ssh:
    install-server: true
    allow-pw: false
    authorized-keys:
      - "ssh-ed25519 AAAA... bos-admin"

  # Paquetes base mínimos
  packages:
    - openssh-server
    - curl
    - git
    - python3
    - apt-transport-https
    - ca-certificates
    - gnupg

  # Scripts post-instalación — aquí BOS toma el control
  late-commands:
    # Configurar systemd para GracefulNodeShutdown
    - mkdir -p /target/etc/systemd/logind.conf.d
    - |
      echo '[Login]
      InhibitDelayMaxSec=90' > /target/etc/systemd/logind.conf.d/kubelet.conf

    # Copiar payload BOS desde el USB
    - mkdir -p /target/opt/bos/bin
    - cp /cdrom/bos-payload/bin/bos /target/opt/bos/bin/bos
    - cp /cdrom/bos-payload/bin/bosctl /target/opt/bos/bin/bosctl
    - chmod +x /target/opt/bos/bin/bos /target/opt/bos/bin/bosctl

    # Copiar fichas
    - mkdir -p /target/etc/bos/blibs/servers
    - cp -r /cdrom/bos-payload/fichas/* /target/etc/bos/blibs/servers/

    # Ejecutar bootstrap en chroot
    - curtin in-target --target=/target -- bash /cdrom/bos-payload/bos-bootstrap.sh

    # Instalar bos.service
    - cp /cdrom/bos-payload/bos.service /target/etc/systemd/system/bos.service
    - curtin in-target --target=/target -- systemctl enable bos.service

    # UI de progreso para el primer boot
    - cp /cdrom/bos-payload/bos-installer-ui.service /target/etc/systemd/system/
    - curtin in-target --target=/target -- systemctl enable bos-installer-ui.service
```

### 10.6 Modo offline vs modo online

```
MODO OFFLINE (USB autosuficiente — recomendado para producción)
  El USB contiene TODO:
  ├── Ubuntu base ISO
  ├── Binarios BOS (bos, bosctl)
  ├── Fichas pre-empaquetadas
  ├── Imágenes containerd (pause, etcd, kube-apiserver, etc.)
  └── Paquetes apt (.deb) de containerd, kubelet, kubeadm, kubectl

  Ventajas:
  - No requiere internet durante la instalación
  - Instalación reproducible — versiones exactas garantizadas
  - Funciona en entornos air-gapped (seguridad alta)
  - Tiempo de instalación predecible

  Construcción del ISO offline:
    make bos-installer-offline VERSION=1.0.0
    # Descarga todo, empaqueta el ISO, genera SHA256

MODO ONLINE (descarga en tiempo real)
  El USB contiene solo el bootloader y el user-data YAML
  Los binarios y fichas se descargan desde:
    github.com/SISTEMASSKULL/skproject-sbos

  Ventajas:
  - USB más pequeño (< 1GB vs 8GB offline)
  - Siempre instala la versión más reciente
  - Útil para desarrollo y staging

  late-commands descarga:
    curl -fsSL https://get.bos.skull.systems/install.sh | bash
```

### 10.7 Pantallas de instalación — experiencia de marca

Cada pantalla de progreso es un componente diseñado como parte de la identidad BOS, no un genérico del instalador Ubuntu. La UI de instalación se implementa como un programa TUI (Terminal User Interface) que corre en paralelo al proceso de instalación y lee el estado desde el state file de BOS:

```
PANTALLA 1 — Bienvenida (GRUB splash)
  Logo BOS centrado
  Nombre: "BOS Business Operating System"
  Versión: "v1.0 — powered by Ubuntu 26.04 LTS + Kubernetes v1.32"
  Descripción: "El sistema operativo de negocios que unifica
                infraestructura, aplicaciones e inteligencia artificial
                bajo una única interfaz soberana."
  Countdown: "Instalando en 10 segundos..."

PANTALLA 2 — Instalando Ubuntu (Fase 1)
  Barra de progreso: 0-30%
  Texto: "Preparando la base del sistema..."
  Subtexto: "Ubuntu 26.04 LTS es la fundación sobre la que BOS
             construye su poder. Kernel Linux, systemd, y las
             herramientas base del sistema operativo."

PANTALLA 3 — Instalando Kubernetes (Fase 2)
  Barra de progreso: 30-60%
  Texto: "Configurando el motor de aplicaciones..."
  Subtexto: "Kubernetes v1.32 provee el scheduling declarativo,
             self-healing automático y networking de aplicaciones.
             BOS lo incorpora como capacidad propia."

PANTALLA 4 — Instalando fichas BOS (Fase 3, en tiempo real)
  Barra de progreso: 60-95%
  Texto: "Instalando el Business Operating System..."
  Lista en tiempo real (leída desde el state file):
    ✅ sbos-bootstrap-os     — sistema base configurado
    ✅ sbos-bootstrap-k8s    — cluster Kubernetes activo
    🔄 sbos-lifecycle        — daemon supervisor instalándose...
    ⏳ sbos-bootstrap-hardening
    ⏳ sbos-security

PANTALLA 5 — Instalación completa
  Barra de progreso: 100%
  ✅ Ubuntu 26.04 LTS instalado
  ✅ Kubernetes v1.32.13 activo (nodo Ready)
  ✅ BOS Business OS v1.0 operativo
  ✅ N fichas instaladas y verificadas
  Texto: "BOS está listo. Este equipo ahora corre el
          Business Operating System de SKULL Systems."
  Instrucciones:
    "Accede via SSH: ssh bos-admin@<IP>"
    "Estado del sistema: bosctl status"
    "Ayuda: bosctl ask '¿qué puedo hacer?'"
  Countdown: "Reiniciando en 10 segundos..."
```

### 10.8 Fichas del dominio D7

**Ficha `sbos-installer`** — empaqueta y construye el ISO:

```
staging/core/servers/hostserver/sbos-installer/
  manifest.yml        ← metadata, sin dependencias (es la raíz)
  task_catalog.sh     ← construye bos-installer.iso
  yaml_engine.yml     ← versiones, rutas, configuración del build
```

**Archivos nuevos en el repositorio:**

| Archivo | Propósito |
|---|---|
| `installer/user-data.yaml` | YAML autoinstall — corazón del instalador |
| `installer/meta-data` | Archivo vacío requerido por cloud-init |
| `installer/grub.cfg` | Bootloader con pantalla BOS branded |
| `installer/grub.theme` | Tema visual GRUB (colores, logo, fuentes) |
| `installer/bos-bootstrap.sh` | Script ejecutado en late-commands |
| `installer/bos-installer-ui` | UI TUI de progreso (Python + rich) |
| `installer/bos-installer-ui.service` | Systemd unit de la UI |
| `installer/splash.png` | Pantalla de bienvenida GRUB |
| `installer/progress-screens/` | Assets visuales de cada fase |
| `Makefile` | `make bos-installer-offline` y `make bos-installer-online` |

### 10.9 Comandos de verificación

```bash
# Construir el ISO
make bos-installer-offline VERSION=1.0.0
ls -lh dist/bos-installer-1.0.0-amd64.iso
# Esperado: archivo ISO de ~4-8GB con SHA256 adjunto

# Verificar integridad del ISO
sha256sum -c dist/bos-installer-1.0.0-amd64.iso.sha256
# Esperado: OK

# Probar en VM (QEMU)
qemu-system-x86_64 -m 4096 -smp 2 \
  -cdrom dist/bos-installer-1.0.0-amd64.iso \
  -hda /tmp/bos-test.img \
  -boot d

# Post-instalación — verificar en la VM
ssh bos-admin@<IP-VM> "bosctl status"
# Esperado: todas las fichas INSTALADA -- OK | HEALTHY

ssh bos-admin@<IP-VM> "kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes"
# Esperado: bos-node-01   Ready   control-plane

# Verificar pantallas de instalación en journal
ssh bos-admin@<IP-VM> "journalctl -u bos-installer-ui --no-pager"
# Esperado: secuencia completa de pantallas logueada

# Verificar modo offline (sin internet durante la instalación)
# Desconectar red de la VM antes de bootear el ISO
# La instalación debe completarse sin errores de red
```

### 10.10 Criterio de certificación D7

```bash
# BOS Installer certificado cuando:

# 1. El ISO bootea en hardware físico y en VM sin intervención
# 2. La instalación completa en menos de 20 minutos (offline)
# 3. Las pantallas branded aparecen en cada fase
# 4. bosctl status reporta todas las fichas HEALTHY post-install
# 5. kubectl get nodes reporta Ready
# 6. El modo offline funciona sin ninguna conexión a internet
# 7. El modo online descarga e instala la versión más reciente
# 8. Re-instalación: el ISO puede volver a instalar sobre un BOS existente

echo "╔══════════════════════════════════════════════════════════╗"
echo "║   BOS INSTALLER CERTIFICADO                              ║"
echo "║   bos-installer.iso → BOS Business OS en cualquier      ║"
echo "║   máquina, sin intervención, con identidad de marca      ║"
echo "╚══════════════════════════════════════════════════════════╝"
```

---

*BOS Business Operating System — v4.0 — 2026-05-19*  
*Visión: Ubuntu + Kubernetes + BOS + BOS Installer = Un solo sistema operativo orientado al negocio*  
*Referentes: talos.dev · ubuntu autoinstall · platform engineering 2026 · CNCF ecosystem · kubernetes.io*  
*Estándares: ISO/IEC 25010:2023 · IEC 62443-4-1/4-2 · NIST SP 800-190 · CIS K8s v1.9+*
