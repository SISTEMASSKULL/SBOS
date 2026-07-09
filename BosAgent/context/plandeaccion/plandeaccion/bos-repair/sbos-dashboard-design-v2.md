# SBOS Dashboard — Sistema de Control IAM Installer SBOS · bos-daemon
## Documento de Diseño TUI v2.0 — Go + Charmbracelet
### Basado en estándares industriales: K9s, Prometheus, Datadog, CNCF, Kubernetes SIG

---

## 1. Visión y Alcance

Este dashboard es una herramienta de **control total del sistema operativo y orquestación**,
inspirada en las mejores prácticas de herramientas profesionales como **K9s** (TUI Kubernetes),
**Grafana** (observabilidad), **Datadog** (control plane monitoring) y los estándares de la
**CNCF** (Cloud Native Computing Foundation).

### Capacidades principales
- Control total de Ubuntu: procesos, servicios systemd, usuarios, PAM, red, disco
- Control total de Kubernetes: Control Plane, Workloads, Autoscaling, RBAC
- Escalado vertical (VPA) y horizontal (HPA + KEDA + Cluster Autoscaler)
- Observabilidad: métricas, logs, eventos, alertas
- Gestión de identidad: PAM, sudoers, K8s RBAC, impersonation (ADR-003)
- Instalación y ciclo de vida de componentes SBOS

---

## 2. Maquetas Visuales

### 2.1 TopBar (2 líneas — siempre visible)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  ⚡ Sistema de Control IAM Installer SBOS - bos daemon                              │
│     skull@dev-vps  ● DEV  │  K8s: ✔  │  Nodes: 3/3  │  2026-06-11 10:32:15        │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Vista Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  ⚡ Sistema de Control IAM Installer SBOS - bos daemon                              │
│     skull@dev-vps  ● DEV  │  K8s: ✔  │  Nodes: 3/3  │  2026-06-11 10:32:15        │
├────────────────┬────────────────────────────────────────────────────────────────────┤
│  NAVEGACIÓN  ▲ │  Overview — Resumen del Sistema                                    │
│              █ ├────────────────────────────────────────────────────────────────────┤
│  ▶ Overview  █ │  CPU              RAM             DISCO          RED               │
│    K8s       █ │  ████████░░░░     ██████░░░░░░    █████░░░░░░   ↑ 1.2 MB/s        │
│    Control   ▼ │  65%  8cores      5.2/8.0 GB      48/120 GB     ↓ 0.4 MB/s        │
│    Plane       │  load: 1.2 0.9 0.7               UPTIME: 12d 4h 32m              │
│    Workloads   ├──────────────────────────────────┬─────────────────────────────────┤
│    Autoscaling │  NODOS K8s                        │  PODS — RESUMEN                │
│    Network     │                                  │                                 │
│    Storage     │  ● master  Ready  CPU:45% MEM:60%│  Running:  12  ████████████ ✔  │
│    Security    │  ● node-1  Ready  CPU:70% MEM:55%│  Pending:   2  ██           ⟳  │
│    Jobs        │  ● node-2  Ready  CPU:30% MEM:40%│  Error:     1  █            ✗  │
│    Usuarios    │                                  │  Total:    15               │  │
│    PAM/RBAC    │  Pods schedulables: 13/15         │                                 │
│    Logs        ├──────────────────────────────────┼─────────────────────────────────┤
│    Alertas     │  SERVICIOS SYSTEMD                │  HPA / VPA — AUTOSCALING       │
│    Config      │  ✔ bos-agent   running            │  ⚡ nginx    HPA  2→5 replicas  │
│                │  ✔ kubelet     running            │  ⚡ api-svc  HPA  CPU:85%→↑    │
│  ──────────    │  ✔ containerd  running            │  ⟳ worker   VPA  mem:→512Mi    │
│  ENV           │  ✗ docker      failed             │  ● redis    —    stable        │
│  ▶ DEV  ✔      ├──────────────────────────────────┴─────────────────────────────────┤
│    STG  ✔      │  ⟳ Instalando: calico/setup.sh  [███████░░░] 70%  │  3/5 items    │
├────────────────┴────────────────────────────────────────────────────────────────────┤
│  [↑↓ Menú]  [Tab → Body]  [r Refresh]  [q Salir]                                   │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.3 Vista K8s — Control Plane

```
├────────────────┬────────────────────────────────────────────────────────────────────┤
│  NAVEGACIÓN  ▲ │  K8s — Control Plane                                               │
│              █ ├────────────────────────────────────────────────────────────────────┤
│    Overview  █ │  [Control Plane]  Workloads  Autoscaling  Network  Storage         │
│  ▶ K8s       █ │                                                                    │
│    Control   ▼ │  COMPONENTE          ESTADO    LATENCIA   ERRORES   UPTIME         │
│    Plane       │  ─────────────────────────────────────────────────────────────     │
│    Workloads   │  ● API Server        ✔ OK      12ms       0/min     12d            │
│    Autoscaling │  ● etcd              ✔ OK      3ms        0/min     12d            │
│    Network     │  ● Scheduler         ✔ OK      —          0/min     12d            │
│    Storage     │  ● Controller Mgr    ✔ OK      —          2/min     12d            │
│    Security    │  ● kubelet (master)  ✔ OK      —          0/min     12d         ▲ │
│                │  ● kubelet (node-1)  ✔ OK      —          0/min     12d         █ │
│                │  ● kubelet (node-2)  ⟳ WARN    —          5/min     12d         ▼ │
│                │                                                                    │
│                │  etcd: tamaño DB: 2.1GB  líderes: 1  peers: 2  health: ✔          │
│                │  API Server: req/s: 142  p99: 45ms  errores 5xx: 0%               │
│                ├────────────────────────────────────────────────────────────────────┤
│                │  ✔ Control plane saludable  │  etcd: OK  │  API: 142 req/s        │
├────────────────┴────────────────────────────────────────────────────────────────────┤
│  [↑↓ Scroll]  [← → Sub-tab]  [Tab → Menú]  [/ Buscar]  [r Refresh]  [q Salir]     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.4 Vista K8s — Workloads

```
│  [Control Plane]  [Workloads]  Autoscaling  Network  Storage                       │
│                                                                                    │
│  [Pods]  Deployments  StatefulSets  DaemonSets  Jobs  CronJobs                    │
│                                                                                    │
│  NOMBRE              NS           ESTADO    READY  RESTART  CPU    MEM    AGE      │
│  ─────────────────────────────────────────────────────────────────────────────     │
│  ● nginx-7d4f9       default      Running   2/2    0        45m    128Mi  5d   ✔   │
│  ● postgres-5c2      default      Running   1/1    0        120m   512Mi  5d   ✔   │
│  ● redis-8b3a1       default      Running   1/1    2        30m    256Mi  5d   ✔   │
│  ● coredns-2xk9      kube-system  Pending   0/1    5        —      —      1h   ⟳   │
│  ● metrics-srv       kube-system  Error     0/1    12       —      —      2h   ✗   │
│  ● calico-node       kube-system  Running   3/3    0        80m    192Mi  5d   ✔   │
│  ● bos-agent-xyz     bos-system   Running   1/1    0        20m    64Mi   12d  ✔   │
```

### 2.5 Vista K8s — Autoscaling (HPA + VPA + KEDA + Cluster Autoscaler)

```
│  Control Plane  Workloads  [Autoscaling]  Network  Storage                         │
│                                                                                    │
│  [HPA]  VPA  KEDA  Cluster Autoscaler  Resource Quotas                            │
│                                                                                    │
│  HPA — HORIZONTAL POD AUTOSCALER                                                   │
│  NOMBRE          TARGET           MIN  MAX  ACTUAL  CPU%   MEM%   ESTADO          │
│  ──────────────────────────────────────────────────────────────────────────        │
│  nginx-hpa       nginx-deploy      2    10   5       85%    —      ⚡ Escalando    │
│  api-hpa         api-deploy        1    20   3       42%    —      ✔ Estable       │
│  worker-hpa      worker-deploy     0    50   0       0%     —      ● Scale-to-zero │
│                                                                                    │
│  VPA — VERTICAL POD AUTOSCALER                                                     │
│  NOMBRE          TARGET           MODO         CPU rec.   MEM rec.   ESTADO        │
│  ──────────────────────────────────────────────────────────────────────────        │
│  worker-vpa      worker-deploy    Auto         200m       512Mi      ⟳ Aplicando   │
│  db-vpa          postgres-sts     Recommend    500m       1Gi        ● Sugerencia  │
│                                                                                    │
│  KEDA — EVENT-DRIVEN AUTOSCALING                                                   │
│  NOMBRE          TRIGGER          VALOR ACT.  THRESHOLD  REPLICAS   ESTADO         │
│  ──────────────────────────────────────────────────────────────────────────        │
│  queue-scaler    kafka:topic-a    1250 msgs   1000       5→8        ⚡ Escalando   │
│  batch-scaler    rabbitmq:jobs    0 msgs      100        3→0        ● Scale-zero   │
│                                                                                    │
│  CLUSTER AUTOSCALER                                                                │
│  Nodos: 3/5  │  CPU cluster: 62%  │  MEM cluster: 52%  │  Pods no schedulables: 0 │
│  ● Último scale-up:  hace 2h  (+1 nodo)                                           │
│  ● Último scale-down: hace 8h  (-1 nodo)                                          │
```

### 2.6 Vista Sistema OS

```
│  [Métricas]  Procesos  Systemd  Red  Disco  Kernel                                │
│                                                                                    │
│  CPU por CORE                    MEMORIA                                           │
│  core-0  ████████░░  78%         Total:  8.0 GB                                   │
│  core-1  █████░░░░░  52%         Usada:  5.2 GB  [██████░░░░] 65%                 │
│  core-2  ███████░░░  71%         Libre:  1.8 GB                                   │
│  core-3  ████░░░░░░  41%         Buff:   1.0 GB                                   │
│  core-4  ██████░░░░  62%         Swap:   0/2GB   [░░░░░░░░░░]  0%                 │
│  core-5  █████████░  88%  ⚠      DISCO                                            │
│  core-6  ███░░░░░░░  34%         /        48/120GB [████░░░░░░] 40%               │
│  core-7  ██████░░░░  58%         /var     12/50GB  [██░░░░░░░░] 24%               │
│                                  /tmp      1/10GB  [░░░░░░░░░░] 10%               │
│  Load avg: 1.2  0.9  0.7                                                           │
│  Uptime: 12d 4h 32m              RED: ens3                                         │
│  Procs: 247 total  3 zombie      ↑ TX: 1.2 MB/s  Total: 45.2 GB                   │
│  Threads: 892                    ↓ RX: 0.4 MB/s  Total: 12.1 GB                   │
```

### 2.7 Vista Autoscaling — Reglas y Estado

```
│  [HPA]  VPA  KEDA  Cluster Autoscaler  Resource Quotas  LimitRange                │
│                                                                                    │
│  RESOURCE QUOTAS — namespace: default                                              │
│  RECURSO         USADO       LÍMITE      %USO    ESTADO                           │
│  ──────────────────────────────────────────────────────                            │
│  pods            12          20          60%     ✔ OK                              │
│  cpu requests    4.2         8.0         53%     ✔ OK                              │
│  mem requests    2.8GB       8.0GB       35%     ✔ OK                              │
│  cpu limits      6.0         12.0        50%     ✔ OK                              │
│  mem limits      4.0GB       16.0GB      25%     ✔ OK                              │
│                                                                                    │
│  LIMITRANGE — namespace: default                                                   │
│  TIPO       RECURSO   DEFAULT REQ   DEFAULT LIM   MIN      MAX                     │
│  Container  cpu       100m          500m           50m      2                      │
│  Container  memory    128Mi         512Mi          64Mi     4Gi                    │
│  Pod        cpu       —             —              200m     4                      │
│                                                                                    │
│  POD DISRUPTION BUDGETS                                                            │
│  NOMBRE          SELECTOR         MIN AVAILABLE   DISPONIBLES  ESTADO             │
│  nginx-pdb       app=nginx         2               2            ✔ Saludable        │
│  api-pdb         app=api           1               3            ✔ Saludable        │
```

### 2.8 Vista PAM/RBAC

```
│  [PAM/sudoers]  K8s RBAC  Impersonation  Audit Log                                │
│                                                                                    │
│  PAM — USUARIOS Y PERMISOS SUDO                                                   │
│  USUARIO    GRUPOS           SUDO        ÚLTIMO USO    ESTADO                      │
│  ──────────────────────────────────────────────────────────────                    │
│  skull      sudo,docker,k8s  ALL=(ALL)   10:31:50      ✔ Activo                   │
│  deploy     deploy,k8s       NOPASSWD    09:45:12      ✔ Activo                   │
│  root       root             ALL=(ALL)   —             ✔ Root                     │
│  svc-bos    bos              NOPASSWD    10:32:14      ✔ Daemon                   │
│                                                                                    │
│  K8s RBAC — ROLES Y BINDINGS                                                      │
│  SUJETO          TIPO              ROL/CLUSTER ROL        NAMESPACE   ESTADO       │
│  skull           User              cluster-admin           *          ✔             │
│  deploy          User              deploy-role             default    ✔             │
│  svc-bos         ServiceAccount    bos-daemon-impersonator bos-sys    ✔             │
│  bos-agent       ServiceAccount    view                    *          ✔             │
│                                                                                    │
│  IMPERSONATION — BOS PROXY (ADR-003)                                              │
│  USUARIO       OPERACIÓN                    RESULTADO    HORA                      │
│  skull      → kubectl get pods              ✔ OK         10:31:50                  │
│  skull      → kubectl scale deploy nginx    ✔ OK         10:28:30                  │
│  deploy     → kubectl delete pod xxx        ✗ DENIED     10:25:11                  │
│  skull      → sudo systemctl restart sshd   ✔ OK         10:20:05                  │
```

### 2.9 Vista Alertas

```
│  [Activas]  Historial  Reglas  Silenciadas                                         │
│                                                                                    │
│  ALERTAS ACTIVAS                                                                   │
│  SEV  NOMBRE                    ORIGEN           MENSAJE                  DESDE    │
│  ─────────────────────────────────────────────────────────────────────────────     │
│  ✗    PodCrashLooping           metrics-srv       exit 1, 12 restarts     2h ago   │
│  ⚠    NodeHighCPU              node-1            CPU core-5 > 85%         5m ago   │
│  ⚠    HPAScaleLimit            nginx-hpa         at maxReplicas=10       12m ago   │
│  ⚠    etcdDatabaseSizeHigh     etcd              DB > 2GB (limit: 8GB)   1h ago   │
│  ℹ    VPARecommendation        worker-vpa        mem rec: 512Mi→768Mi    30m ago   │
│                                                                                    │
│  Críticas: 1  Warnings: 3  Info: 1  Silenciadas: 0                                │
```

### 2.10 Vista Logs

```
│  [bos-agent]  sshd  kubelet  kernel  ufw  etcd  containerd                       │
│                                                                                    │
│  [INFO ]  10:32:14  agent: heartbeat ok                                            │
│  [INFO ]  10:32:10  k8s: pod nginx-7d4f9 healthy, replicas=5 (HPA scale-up)      │
│  [WARN ]  10:32:05  k8s: coredns-2xk9 — ImagePullBackOff                          │
│  [ERROR]  10:31:58  k8s: metrics-srv crashloop — exit 1 (restart #12)             │
│  [INFO ]  10:31:50  os: impersonate skull → kubectl get pods → OK                 │
│  [INFO ]  10:31:40  hpa: nginx scale 3→5 replicas (CPU: 85%)                      │
│  [WARN ]  10:31:30  pam: deploy sudo kubectl delete — DENIED (not in sudoers)     │
│  [INFO ]  10:31:25  keda: queue-scaler trigger kafka 1250/1000 → scale 5→8        │
│  [INFO ]  10:31:10  vpa: worker-vpa applying mem 256Mi→512Mi                      │
│  [INFO ]  10:30:58  agent: heartbeat ok                                         ▲ │
│  [INFO ]  10:30:50  etcd: snapshot ok, size: 2.1GB                             █ │
│  [WARN ]  10:30:40  node-1: core-5 CPU 88% (threshold: 85%)                    ▼ │
│                                                                                    │
│  ● Follow: ON  │  daemon: bos-agent  │  línea 247/1204  │  filtro: —              │
```

---

## 3. Estructura de Zonas

```
┌──────────────────────────────────────────────────────────────┐
│  TOP  (2 líneas fijas)                                       │
│  L1: ⚡ título completo                                      │
│  L2: usuario@host + env + estado K8s + nodos + fecha/hora   │
├──────────────────┬───────────────────────────────────────────┤
│                  │  CONTAINER TOP  (1 línea)                 │
│                  │  título vista + sub-tabs                  │
│  MENU            ├───────────────────────────────────────────┤
│  (viewport       │                                           │
│   scrollable     │  CONTAINER BODY  (flexible)               │
│   solo vertical) │  renderContainerBody() según vista        │
│                  │                                           │
│                  ├───────────────────────────────────────────┤
│                  │  CONTAINER STATUS  (1 línea)              │
│                  │  job activo + progreso + evento relevante │
├──────────────────┴───────────────────────────────────────────┤
│  BOTTOM  (1 línea)                                           │
│  hints contextuales según foco + vista activa               │
└──────────────────────────────────────────────────────────────┘
```

---

## 4. Árbol de Módulos

```
sbos-dashboard/
│
├── main.go                         ← entry point
│
├── model/
│   ├── model.go                    ← Model central, Init/Update/View
│   ├── focus.go                    ← máquina de estados de foco
│   └── keymap.go                   ← keybindings centralizadas
│
├── ui/
│   ├── topbar.go                   ← renderTop() — 2 líneas
│   ├── bottombar.go                ← renderBottom() + hints contextuales
│   ├── menu.go                     ← renderMenu() + viewport + scrollbar
│   └── container/
│       ├── container.go            ← orquestador del container
│       ├── top.go                  ← título vista + sub-tabs
│       ├── status.go               ← línea de estado + progreso
│       └── body.go                 ← dispatcher → views/
│
├── views/
│   ├── overview.go                 ← resumen general
│   ├── k8s/
│   │   ├── k8s.go                  ← orquestador K8s + sub-tabs
│   │   ├── controlplane.go         ← API Server, etcd, Scheduler, CM
│   │   ├── workloads.go            ← Pods, Deployments, StatefulSets, DaemonSets
│   │   ├── autoscaling.go          ← HPA, VPA, KEDA, Cluster Autoscaler
│   │   ├── network.go              ← Services, Ingress, NetworkPolicies
│   │   └── storage.go              ← PVs, PVCs, StorageClasses
│   ├── sistema/
│   │   ├── sistema.go              ← orquestador OS + sub-tabs
│   │   ├── metricas.go             ← CPU/core, RAM, Swap
│   │   ├── procesos.go             ← top processes, zombies
│   │   ├── systemd.go              ← servicios, estado, uptime
│   │   ├── red.go                  ← interfaces, tráfico, conexiones
│   │   ├── disco.go                ← particiones, I/O, inodes
│   │   └── kernel.go               ← versión, módulos, sysctl
│   ├── jobs.go                     ← instalaciones activas + historial
│   ├── usuarios.go                 ← sesiones activas, last, who
│   ├── pam_rbac/
│   │   ├── pam_rbac.go             ← orquestador PAM/RBAC
│   │   ├── pam.go                  ← sudoers, grupos, autenticación
│   │   ├── rbac.go                 ← ClusterRoles, Bindings, ServiceAccounts
│   │   ├── impersonation.go        ← audit de impersonation BOS (ADR-003)
│   │   └── audit.go                ← log de accesos y operaciones
│   ├── logs.go                     ← viewer multi-daemon + follow + búsqueda
│   ├── alertas.go                  ← alertas activas, historial, reglas
│   ├── network.go                  ← firewall UFW, DNS, puertos
│   ├── storage.go                  ← discos OS, backups
│   ├── seguridad.go                ← certificados, CVEs, auditoría
│   ├── backups.go                  ← estado, schedule, historial
│   ├── monitoreo.go                ← métricas time-series, sparklines
│   └── config.go                   ← configuración BosAgent
│
├── styles/
│   └── styles.go                   ← todos los lipgloss.Style
│
├── theme/
│   └── theme.go                    ← paleta de colores
│
├── widgets/
│   ├── progressbar.go              ← barra de progreso parametrizable
│   ├── sparkline.go                ← mini gráfico ASCII time-series
│   ├── table.go                    ← tabla con headers, ordenamiento
│   ├── statusdot.go                ← ● indicador de estado con color
│   ├── gauge.go                    ← medidor de porcentaje (CPU/RAM)
│   └── badge.go                    ← etiqueta de estado (Running/Error...)
│
└── data/
    ├── types.go                    ← structs puros sin lógica UI
    ├── mock.go                     ← datos de ejemplo (misma interfaz)
    └── ticker.go                   ← tea.Tick commands por intervalo
```

---

## 5. Menú de Navegación — Ítems Completos

```
┌────────────────┐
│  NAVEGACIÓN  ▲ │
│              █ │
│  ▶ Overview    │  Resumen general del sistema
│    ─────────   │
│    K8s         │  → sub-vistas internas:
│      Control   │     Control Plane (API Server, etcd, Scheduler, CM)
│      Plane     │     Workloads (Pods, Deploys, StatefulSets, Daemons)
│      Workloads │     Autoscaling (HPA, VPA, KEDA, Cluster AS)
│      Autoscal. │     Network (Services, Ingress, NetPolicies)
│      Network   │     Storage (PVs, PVCs, StorageClasses)
│      Storage   │
│    ─────────   │
│    Sistema OS  │  → sub-vistas:
│      Métricas  │     CPU/RAM/Swap, Procesos, Systemd
│      Procesos  │     Red, Disco, Kernel
│      Systemd   │
│      Red       │
│      Disco     │
│      Kernel    │
│    ─────────   │
│    Jobs        │  Instalaciones activas e historial
│    Usuarios    │  Sesiones activas, last login
│    PAM/RBAC    │  → PAM, RBAC, Impersonation, Audit
│    Logs        │  Viewer multi-daemon + follow
│    Alertas     │  Activas, historial, reglas
│    Network     │  UFW, DNS, puertos OS
│    Storage     │  Discos OS, backups
│    Seguridad   │  Certificados, CVEs
│    Backups     │  Estado, schedule
│    Monitoreo   │  Time-series, sparklines
│    Config      │  Configuración BosAgent
│              ▼ │
└────────────────┘
```

---

## 6. Vistas y Sub-tabs Completos

| Vista | Sub-tabs | Datos principales |
|---|---|---|
| **Overview** | — | Métricas OS, nodos, pods resumen, HPA activos, servicios |
| **K8s › Control Plane** | — | API Server, etcd, Scheduler, Controller Manager |
| **K8s › Workloads** | Pods · Deployments · StatefulSets · DaemonSets · Jobs · CronJobs | Estado, ready, CPU, MEM, restarts, age |
| **K8s › Autoscaling** | HPA · VPA · KEDA · Cluster AS · Quotas · LimitRange · PDB | Réplicas, triggers, thresholds, recomendaciones |
| **K8s › Network** | Services · Ingress · NetworkPolicies · Endpoints | Tipo, IP, puertos, reglas |
| **K8s › Storage** | PVs · PVCs · StorageClasses · VolumeSnapshots | Capacidad, status, access mode |
| **Sistema OS › Métricas** | CPU · RAM · Swap · I/O | Por core, tendencia, load avg |
| **Sistema OS › Procesos** | Top · Zombie · Threads | PID, CPU%, MEM%, comando |
| **Sistema OS › Systemd** | Activos · Fallidos · Todos | Estado, since, logs |
| **Sistema OS › Red** | Interfaces · Conexiones · DNS | TX/RX, conexiones activas |
| **Sistema OS › Disco** | Particiones · I/O · Inodes | Uso, velocidad lectura/escritura |
| **Sistema OS › Kernel** | Versión · Módulos · Sysctl | Parámetros críticos |
| **Jobs** | Activos · Historial · Pendientes | Progreso, logs, errores |
| **Usuarios** | Activos · Last · Grupos | Sesiones SSH, terminal, hora |
| **PAM/RBAC › PAM** | Sudoers · Grupos · Auth | Permisos efectivos por usuario |
| **PAM/RBAC › RBAC** | ClusterRoles · Bindings · SAs | Permisos K8s por sujeto |
| **PAM/RBAC › Impersonation** | Audit · Activos · Historial | Proxy BOS ADR-003 |
| **Logs** | bos-agent · sshd · kubelet · kernel · ufw · etcd · containerd | Streaming, follow, búsqueda |
| **Alertas** | Activas · Historial · Reglas · Silenciadas | Severidad, origen, tiempo |
| **Network** | UFW · DNS · Puertos · Túneles | Reglas firewall, resolución |
| **Storage** | Discos · SMART · Backups | Salud, temperatura, historial |
| **Seguridad** | Certificados · Puertos · CVEs · Auditoría | Expiración, vulnerabilidades |
| **Backups** | Estado · Schedule · Historial | Última ejecución, tamaño, estado |
| **Monitoreo** | CPU · RAM · Red · K8s | Sparklines time-series |
| **Config** | General · K8s · Daemons · Alertas | Configuración BosAgent |

---

## 7. Detalle de Módulos Clave

### 7.1 `model/model.go`

```go
type Model struct {
    // Dimensiones (actualizadas por WindowSizeMsg)
    Width  int
    Height int

    // Foco y navegación
    Focus        focus.Focus
    MenuIndex    int
    MenuVP       viewport.Model
    SubTabIndex  map[string]int   // sub-tab por vista: {"k8s": 2, "sistema": 0}

    // Entorno activo
    ActiveEnv  string  // "DEV" | "STG"
    Envs       []data.Env

    // Viewports del body por vista (preservan posición de scroll)
    BodyVPs    map[string]viewport.Model

    // ── Datos del sistema ──────────────────────────────────
    // OS
    CPUPercents  []float64     // por core
    MemInfo      data.MemInfo
    DiskStats    []data.Disk
    NetStats     data.NetStats
    Processes    []data.Process
    Services     []data.Service
    Users        []data.User
    KernelInfo   data.KernelInfo

    // K8s — Control Plane
    APIServer    data.APIServerMetrics
    Etcd         data.EtcdMetrics
    Scheduler    data.SchedulerMetrics
    ControllerMgr data.ControllerMgrMetrics

    // K8s — Workloads
    Nodes        []data.Node
    Pods         []data.Pod
    Deployments  []data.Deployment
    StatefulSets []data.StatefulSet
    DaemonSets   []data.DaemonSet
    Jobs         []data.K8sJob
    CronJobs     []data.CronJob

    // K8s — Autoscaling
    HPAs         []data.HPA
    VPAs         []data.VPA
    KEDAScalers  []data.KEDAScaler
    ClusterAS    data.ClusterAutoscaler
    Quotas       []data.ResourceQuota
    LimitRanges  []data.LimitRange
    PDBs         []data.PodDisruptionBudget

    // K8s — Network
    Services_K8s []data.K8sService
    Ingresses    []data.Ingress
    NetPolicies  []data.NetworkPolicy

    // K8s — Storage
    PVs          []data.PersistentVolume
    PVCs         []data.PersistentVolumeClaim
    StorageClasses []data.StorageClass

    // Identidad y RBAC
    PAMUsers     []data.PAMUser
    ClusterRoles []data.ClusterRole
    RoleBindings []data.RoleBinding
    ImpersonationAudit []data.ImpersonationEvent

    // Logs
    LogDaemons   []string         // lista de daemons disponibles
    LogDaemon    int              // índice del daemon activo
    LogEntries   []data.LogEntry
    LogFollow    bool
    LogSearch    string

    // Alertas
    Alerts       []data.Alert

    // Jobs SBOS (instalación)
    InstallJobs  []data.InstallJob
    CurrentJob   string
    Progress     int
    JobsDone     int
    JobsTotal    int

    // Estado global
    Now          time.Time
    Searching    bool
    SearchQuery  string
    StatusMsg    string

    // KeyMap
    Keys         keymap.KeyMap
}
```

---

### 7.2 `model/focus.go`

```go
type Focus int

const (
    FocusMenu Focus = iota
    FocusBody
)

// Transiciones válidas
// FocusMenu  + Tab        → FocusBody
// FocusBody  + Tab        → FocusMenu
// FocusBody  + Shift+Tab  → FocusMenu

func (f Focus) Next() Focus {
    if f == FocusMenu { return FocusBody }
    return FocusMenu
}
```

---

### 7.3 `model/keymap.go`

```go
type KeyMap struct {
    // Globales
    Quit        key.Binding  // q, ctrl+c
    Refresh     key.Binding  // r
    ToggleFocus key.Binding  // Tab
    PrevFocus   key.Binding  // Shift+Tab

    // Menú
    MenuUp     key.Binding  // ↑, k
    MenuDown   key.Binding  // ↓, j
    MenuSelect key.Binding  // Enter

    // Body — navegación
    ScrollUp    key.Binding  // ↑, k
    ScrollDown  key.Binding  // ↓, j
    ScrollPgUp  key.Binding  // PgUp
    ScrollPgDn  key.Binding  // PgDn
    ScrollTop   key.Binding  // g
    ScrollBot   key.Binding  // G
    SubTabNext  key.Binding  // →, l, L
    SubTabPrev  key.Binding  // ←, h, H

    // Body — acciones
    Search      key.Binding  // /
    SearchEsc   key.Binding  // Esc
    Delete      key.Binding  // d  (pods, jobs)
    Describe    key.Binding  // D  (describe recurso K8s)
    Logs        key.Binding  // l  (ver logs del pod)
    Scale       key.Binding  // s  (scale deployment)
    Execute     key.Binding  // e  (exec pod shell)
    Follow      key.Binding  // f  (follow logs)
    Copy        key.Binding  // c  (copiar nombre)

    // Env
    ChangeEnv   key.Binding  // E
}
```

---

### 7.4 `data/types.go` — Structs K8s completos

```go
// ── Control Plane ──────────────────────────────────────────
type APIServerMetrics struct {
    RequestsPerSec float64
    P99LatencyMs   float64
    Errors5xx      float64
    Goroutines     int
    Healthy        bool
}

type EtcdMetrics struct {
    DBSizeMB       float64
    Leaders        int
    Peers          int
    Healthy        bool
    LatencyMs      float64
    ProposalsFailed int
}

type SchedulerMetrics struct {
    SchedulingLatencyMs float64
    PendingPods         int
    Healthy             bool
    Goroutines          int
}

type ControllerMgrMetrics struct {
    ErrorsPerMin  int
    Goroutines    int
    Healthy       bool
    QueueDepth    int
}

// ── Workloads ───────────────────────────────────────────────
type Pod struct {
    Name        string
    Namespace   string
    Status      PodStatus
    Ready       string      // "2/2"
    Restarts    int
    CPUm        int         // millicores
    MemMi       int         // MiB
    Age         string
    Node        string
    Labels      map[string]string
}

type Deployment struct {
    Name        string
    Namespace   string
    Desired     int
    Ready       int
    Updated     int
    Available   int
    Age         string
}

// ── Autoscaling ─────────────────────────────────────────────
type HPA struct {
    Name        string
    Namespace   string
    Target      string
    MinReplicas int
    MaxReplicas int
    Current     int
    CPUTarget   int     // porcentaje
    CPUCurrent  int
    MemTarget   int
    MemCurrent  int
    Status      HPAStatus
}

type VPA struct {
    Name        string
    Namespace   string
    Target      string
    Mode        string      // "Off" | "Initial" | "Recreate" | "Auto"
    CPURec      string      // recomendación CPU
    MemRec      string      // recomendación Mem
    Status      VPAStatus
}

type KEDAScaler struct {
    Name        string
    Namespace   string
    Target      string
    TriggerType string      // "kafka" | "rabbitmq" | "prometheus" | ...
    CurrentVal  int
    Threshold   int
    Replicas    int
    Status      KEDAStatus
}

type ClusterAutoscaler struct {
    NodesTotal    int
    NodesReady    int
    NodesMax      int
    LastScaleUp   time.Time
    LastScaleDown time.Time
    CPUCluster    float64
    MemCluster    float64
    UnschedulablePods int
}

type ResourceQuota struct {
    Name       string
    Namespace  string
    Items      []ResourceQuotaItem
}

type ResourceQuotaItem struct {
    Resource  string
    Used      string
    Hard      string
    Percent   float64
}

type PodDisruptionBudget struct {
    Name           string
    Namespace      string
    Selector       string
    MinAvailable   int
    MaxUnavailable int
    Available      int
    Healthy        bool
}

// ── Identidad ───────────────────────────────────────────────
type PAMUser struct {
    Name     string
    Groups   []string
    SudoRule string
    LastSudo time.Time
    Active   bool
}

type ImpersonationEvent struct {
    Time      time.Time
    Operator  string   // usuario real (bos-daemon)
    AsUser    string   // usuario impersonado
    Operation string   // kubectl ..., sudo ...
    Result    bool
}

// ── Alertas ─────────────────────────────────────────────────
type Alert struct {
    Severity AlertSeverity  // Critical | Warning | Info
    Name     string
    Source   string
    Message  string
    Since    time.Time
    Silenced bool
}

type AlertSeverity int
const (
    SeverityCritical AlertSeverity = iota
    SeverityWarning
    SeverityInfo
)
```

---

### 7.5 `data/ticker.go` — Intervalos por tipo

```go
// Intervalos de actualización (estándar industria — basado en Prometheus/Datadog)
const (
    TickClock          = 1 * time.Second    // reloj
    TickProgress       = 500 * time.Millisecond  // barras de progreso
    TickMetricsOS      = 2 * time.Second    // CPU, RAM, Red (tiempo real)
    TickPods           = 3 * time.Second    // pods (cambian frecuente)
    TickHPA            = 5 * time.Second    // HPA (ciclo cada 15s en K8s)
    TickNodes          = 5 * time.Second    // nodos
    TickServices       = 5 * time.Second    // systemd
    TickUsers          = 5 * time.Second    // sesiones activas
    TickControlPlane   = 10 * time.Second   // API Server, etcd, Scheduler
    TickRBAC           = 10 * time.Second   // RBAC, PAM
    TickVPA            = 30 * time.Second   // VPA (ciclo largo)
    TickClusterAS      = 30 * time.Second   // Cluster Autoscaler
    TickAlerts         = 15 * time.Second   // alertas
    TickLogs           = 1 * time.Second    // logs (streaming)
)
```

---

### 7.6 `widgets/` — Componentes reutilizables

```go
// progressbar.go
func ProgressBar(pct, width int) string
// Ejemplo: [███████░░░] 70%

// sparkline.go
func Sparkline(values []float64, width int) string
// Ejemplo: ▁▂▄▆█▇▅▃▂▁  (histórico de CPU últimos N segundos)

// gauge.go
func Gauge(pct float64, width int, label string) string
// Ejemplo: CPU ████████░░ 78%

// table.go
type Table struct {
    Headers  []string
    Rows     [][]string
    Widths   []int
    Sortable bool
    SortCol  int
    SortAsc  bool
}
func (t Table) Render(width int) string

// statusdot.go
func StatusDot(status string) string
// ✔ verde | ⟳ amarillo | ✗ rojo | ░ gris | ⚡ cyan

// badge.go
func Badge(label string, status StatusType) string
// [Running] [Pending] [Error] con color según estado
```

---

## 8. Controles de Teclado Completos

### Globales (siempre activos)
| Tecla | Acción |
|---|---|
| `q` / `Ctrl+C` | Salir |
| `r` | Refresh manual inmediato |
| `Tab` | Alternar foco Menú ↔ Body |
| `Shift+Tab` | Body → Menú |
| `E` | Cambiar entorno DEV/STG |

### Foco en Menú
| Tecla | Acción |
|---|---|
| `↑` / `k` | Ítem anterior |
| `↓` / `j` | Ítem siguiente |
| `Enter` | Seleccionar vista |
| `g` / `Home` | Primer ítem |
| `G` / `End` | Último ítem |

### Foco en Body — general
| Tecla | Acción |
|---|---|
| `↑` / `k` | Scroll arriba |
| `↓` / `j` | Scroll abajo |
| `PgUp` | Scroll página arriba |
| `PgDn` | Scroll página abajo |
| `g` | Ir al inicio |
| `G` | Ir al final |
| `←` / `h` | Sub-tab anterior |
| `→` / `l` | Sub-tab siguiente |
| `/` | Activar búsqueda |
| `Esc` | Cancelar búsqueda |
| `r` | Refresh manual |

### Body — vistas K8s (pods, deployments)
| Tecla | Acción |
|---|---|
| `d` | Describe recurso (kubectl describe) |
| `D` | Delete recurso (con confirmación) |
| `l` | Ver logs del pod |
| `e` | Exec shell en pod |
| `s` | Scale deployment |
| `c` | Copiar nombre al clipboard |

### Body — vista Logs
| Tecla | Acción |
|---|---|
| `f` | Toggle follow (auto-scroll) |
| `←` / `→` | Cambiar daemon |
| `/` | Buscar en logs |
| `Esc` | Limpiar búsqueda |

---

## 9. UX — Principios Profesionales

### Basados en estándares K9s + Grafana + htop

```
1. FOCO SIEMPRE VISIBLE
   borde cyan     = zona activa
   borde gris     = zona inactiva
   ítem selecto   = fondo cyan, texto negro

2. INFORMACIÓN DENSIFICADA (estilo htop)
   sin espacio desperdiciado
   métricas numéricas + barra visual siempre juntas
   columnas alineadas con ancho fijo

3. SCROLLBAR CONDICIONAL (estilo K9s)
   aparece solo cuando contenido > área visible
   auto-scroll al ítem seleccionado

4. PROGRESSIVE DISCLOSURE
   Overview: resumen de todo (1 pantalla)
   Vista específica: detalle completo
   Describe: máximo detalle on-demand

5. HINTS CONTEXTUALES (estilo K9s)
   BottomBar cambia según: foco + vista + sub-tab
   solo muestra teclas RELEVANTES al contexto

6. FEEDBACK EN TIEMPO REAL
   ContainerStatus: siempre muestra actividad actual
   Alertas críticas: visibles en TopBar L2
   HPA scaling: visible en Overview y vista K8s

7. COLOR SEMÁNTICO CONSISTENTE
   verde  ✔ = OK, Running, Done, permitido
   amarillo ⚡⟳ = Warning, Scaling, Pending, procesando
   rojo  ✗ = Error, Failed, Denied, crítico
   gris  ░ = Pendiente, en cola, sin datos
   cyan  ▶ = Seleccionado, activo, foco

8. GLYPH VOCABULARY CONSISTENTE (estándar TUI industria)
   ●  nodo/entorno activo
   ▶  ítem seleccionado
   ✔  estado OK
   ✗  estado error
   ⟳  en proceso
   ░  pendiente
   ⚡  alerta/scaling activo
   █  barra llena
   ░  barra vacía
   ▲▼ scrollbar

9. DIMENSIONES 100% PARAMÉTRICAS
   cero valores hardcodeados
   WindowSizeMsg dispara recálculo en cascada

10. DATOS DESACOPLADOS (testeable)
    views/ reciben structs data/, no el Model
    mock.go implementa misma interfaz que real
    swap mock→real transparente para las vistas
```

---

## 10. Estándares y Referencias Industriales

| Estándar/Herramienta | Influencia en SBOS Dashboard |
|---|---|
| **K9s** | Navegación TUI, glyph vocabulary, sub-tabs, hints contextuales |
| **htop** | Densidad de información, barras CPU por core, layout compacto |
| **Grafana** | Paneles por categoría, time-series con sparklines, alertas |
| **Datadog K8s** | Métricas de Control Plane: API Server, etcd, Scheduler, CM |
| **Prometheus** | Intervalos de scrape (2-15s), métricas de workloads |
| **CNCF Autoscaling** | HPA v2, VPA, KEDA, Cluster Autoscaler como ciudadanos de primera clase |
| **K8s SIG Scalability** | PodDisruptionBudget, ResourceQuota, LimitRange visibles |
| **ADR-003 BOS** | Impersonation proxy transparente, audit log de operaciones |

---

## 11. Dependencias

```bash
go mod init sbos-dashboard

# Charmbracelet ecosystem
go get github.com/charmbracelet/bubbletea@v1.3.10
go get github.com/charmbracelet/bubbles@v1.0.0
go get github.com/charmbracelet/lipgloss@v1.1.0

# Métricas OS
go get github.com/shirou/gopsutil/v3@latest

# K8s client (para datos reales)
go get k8s.io/client-go@latest
go get k8s.io/api@latest
go get k8s.io/metrics@latest
```

| Librería | Versión | Rol |
|---|---|---|
| BubbleTea | v1.3.10 | Framework TEA — loop, Init/Update/View, mensajes |
| Bubbles | v1.0.0 | viewport (scroll), textinput (búsqueda), spinner |
| Lipgloss | v1.1.0 | Estilos, bordes, colores, Join, Place |
| gopsutil | v3 | CPU, RAM, disco, red, procesos, uptime desde OS |
| client-go | latest | API K8s: pods, HPAs, VPAs, nodes, events |

---

## 12. Ejecutar

```bash
go mod tidy
go run main.go

# Con debug
DEBUG=1 go run main.go
```

---

## 13. Notas de Implementación

- **Control Plane monitoring**: inspirado en Datadog K8s — API Server, etcd, Scheduler, Controller Manager como métricas de primera clase.
- **Autoscaling completo**: HPA + VPA + KEDA + Cluster Autoscaler — los 4 mecanismos de escalado de la industria CNCF visibles en una sola vista.
- **VPA + HPA coexistencia**: el dashboard muestra la regla de no conflicto (HPA controla CPU→réplicas, VPA controla memory→recursos).
- **KEDA scale-to-zero**: visible explícitamente como estado `● Scale-zero` — diferenciado de error.
- **PodDisruptionBudget**: visible en la vista Autoscaling — esencial para operaciones seguras de scale-down.
- **ResourceQuota + LimitRange**: controles de capacidad por namespace — estándar en clusters multi-tenant.
- **Sparklines**: gráficos ASCII time-series para tendencias de CPU/RAM sin dependencias externas.
- **Impersonation audit**: cada operación BOS como proxy (ADR-003) queda registrada en la vista PAM/RBAC › Impersonation.
- **Multi-viewport**: cada vista preserva su posición de scroll en `BodyVPs map[string]viewport.Model`.
- **Ticker por tipo**: cada categoría tiene su propio intervalo — evita saturar el event loop con actualizaciones innecesarias.
