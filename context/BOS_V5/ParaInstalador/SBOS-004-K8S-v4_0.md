# SBOS-004-K8S
## Arquitectura de Infraestructura Kubernetes

### SKULL · SBOS — Sovereign Business Operating System
### v4.0 · Marzo 2026

---

## Tabla de Contenidos

1. [Fundamento Conceptual](#1-fundamento-conceptual)
2. [Daemons Soberanos del Host — Fuera de K8s](#2-daemons-soberanos-del-host--fuera-de-ks)
3. [El Modelo Correcto: IAM Installer → Todo](#3-el-modelo-correcto-iam-installer--todo)
4. [La Ficha Bootstrap: SP-02](#4-la-ficha-bootstrap-sp-02)
5. [Lo que el IAM Installer Necesita para Arrancar](#5-lo-que-el-iam-installer-necesita-para-arrancar)
6. [Secuencia Completa: De Ubuntu Limpio a Cluster Operativo](#6-secuencia-completa-de-ubuntu-limpio-a-cluster-operativo)
7. [Topología del Cluster: De Nodo Único a Multi-Nodo](#7-topología-del-cluster-de-nodo-único-a-multi-nodo)
8. [Dónde Vive Cada Componente](#8-dónde-vive-cada-componente)
9. [Namespaces y Gobernanza de Recursos](#9-namespaces-y-gobernanza-de-recursos)
10. [Red: Zero Trust con Calico](#10-red-zero-trust-con-calico)
11. [mTLS entre Servicios — Linkerd](#11-mtls-entre-servicios--linkerd)
12. [Services: DNS Interno del Cluster](#12-services-dns-interno-del-cluster)
13. [Hardening CIS: El Cluster Seguro por Defecto](#13-hardening-cis-el-cluster-seguro-por-defecto)
14. [Admission Control: La Última Línea de Defensa](#14-admission-control-la-última-línea-de-defensa)
15. [Especificaciones de Hardware por Servidor Lógico](#15-especificaciones-de-hardware-por-servidor-lógico)
16. [Crecimiento Horizontal — 3 Parámetros](#16-crecimiento-horizontal--3-parámetros)
17. [Política de Actualización de Kubernetes](#17-política-de-actualización-de-kubernetes)
18. [Estado Final: Ubuntu Limpio → Cluster Listo](#18-estado-final-ubuntu-limpio--cluster-listo)
19. [Registro de Cambios v4.0](#19-registro-de-cambios-v40)

---

## 1. Fundamento Conceptual

### Por qué Kubernetes desde el Día 1

Kubernetes no es solo un orquestador de contenedores — es un **modelo de operación**. Introduce abstracciones que definen cómo las aplicaciones se describen a sí mismas, cómo se comunican, cómo se escalan, y cómo se recuperan de fallos. Migrar a ese modelo cuando ya tienes 30 aplicaciones corriendo en Docker Compose es extremadamente costoso. Empezar en Kubernetes desde el primer servidor significa que la aplicación número 1 y la aplicación número 97 comparten el mismo modelo operacional, sin ninguna migración en el camino.

El costo de Kubernetes en nodo único es marginal: entre 500 MB y 1 GB de RAM para el control plane. A cambio, el cliente tiene desde el primer minuto DNS interno entre servicios, NetworkPolicies de aislamiento, secrets encriptados en etcd, health checks automáticos, reinicio automático de pods fallidos, y la capacidad de expandir a múltiples nodos con tres parámetros sin cambiar la configuración de ninguna aplicación.

### El principio del instalador que construye su propia plataforma

Kubeadm automatiza la creación y configuración de los componentes necesarios para un cluster Kubernetes, incluyendo la configuración del control plane y los worker nodes. El SBOS lleva este principio un paso más lejos: el IAM Installer usa kubeadm, configura Calico, instala MetalLB, y finalmente se despliega a sí mismo como un pod en el cluster que acaba de construir. El instalador construye su propia plataforma y luego vive dentro de ella.

### Las cuatro C de la seguridad

La industria estructura la seguridad de Kubernetes en cuatro capas: Cloud, Cluster, Container, y Code. Este documento define la capa **Cluster** en su totalidad: hardening del API server y etcd, RBAC, admission controllers, network policies de zero trust, y encriptación de secrets en reposo.

---

## 2. Daemons Soberanos del Host — Fuera de K8s

Esta sección establece con precisión qué componentes del SBOS corren en el host Ubuntu como servicios systemd — **completamente fuera del cluster Kubernetes** — y por qué esta decisión es arquitectónicamente necesaria y no negociable.

### Los daemons soberanos del host

| Daemon | Tipo | Razón para vivir fuera de K8s |
|---|---|---|
| **IAM Installer Core (SP-01)** | systemd en el host | Guardián del SO — no puede depender de lo que él mismo instala, vigila y repara. Si K8s falla, el Core debe poder diagnosticar y reparar. |
| **bKernel** | systemd en el host | Acceso directo al WAL de PostgreSQL — requiere socket local del host. La latencia de red overlay de K8s es incompatible con la captura de cambios en microsegundos. |
| **SBOS Data Integration** | systemd en el host | Escribe en PostgreSQL marcando origin='biedata' para que el bKernel no genere loops. Esta coordinación requiere acceso directo al host para ser atómica. |
| **SBOS AI Tools** | systemd en el host | Daemon de orquestación soberana. Escucha eventos del bKernel via WAL, coordina workflows con Ollama y Qdrant. Ciclo de vida independiente del cluster para garantizar disponibilidad ante fallos de K8s. |

### Por qué estos daemons no pueden ser pods K8s

**Razón 1 — Acceso directo al WAL de PostgreSQL:**

El bKernel escucha el Write-Ahead Log de PostgreSQL para capturar cambios de datos en tiempo real. Este mecanismo requiere una conexión de replicación directa con latencia de microsegundos. Los pods K8s se comunican a través de la red overlay de Calico (vxlan o BGP), que introduce latencias variables de 1-5ms por salto de red. Para un daemon que captura miles de transacciones por segundo, esta latencia no es aceptable. Corriendo en el host, el bKernel usa el socket Unix local de PostgreSQL — latencia de microsegundos, cero overhead de red.

```
bKernel en el host:
  bKernel → /var/run/postgresql/.s.PGSQL.5432 (socket Unix) → PostgreSQL
  Latencia: ~50 microsegundos

bKernel como pod K8s (hipotético, rechazado):
  Pod bKernel → Calico overlay → postgresql.sbos-data.svc.cluster.local:5432
  Latencia: 1,000-5,000 microsegundos (20-100x más lento)
```

**Razón 2 — Ciclo de vida independiente del cluster:**

El IAM Installer Core es el guardián del sistema. Su responsabilidad incluye diagnosticar y reparar un cluster K8s que ha fallado. Si el IAM Installer Core fuera un pod K8s, un fallo del cluster lo destruiría — exactamente cuando más se necesita. El IAM Installer Core debe estar disponible cuando K8s no lo está.

```
Escenario de fallo:
  K8s cluster falla (etcd corrupto, API server no responde)
  ↓
  IAM Installer Core (systemd) sigue corriendo en el host
  ↓
  IAM Installer Core ejecuta Ficha Bootstrap fase 'repair'
  ↓
  Cluster K8s recuperado
```

Si el IAM Installer Core fuera un pod, este escenario de recuperación sería imposible.

**Razón 3 — Escritura coordinada con antiloop:**

SBOS Data Integration escribe en PostgreSQL con `pg_replication_origin_session_setup('biedata')` para marcar que esos cambios vienen de SBOS Data Integration — no de aplicaciones del stack. El bKernel filtra esos cambios para evitar loops infinitos. Esta coordinación de dos procesos (bKernel + SBOS Data Integration) sobre el mismo socket de PostgreSQL requiere acceso directo al host para ser atómica y libre de race conditions de red.

**Razón 4 — Principio de mínima dependencia:**

Los daemons soberanos son más críticos que las aplicaciones que coordinan. Hacerlos dependientes de K8s introduciría una inversión de dependencia inaceptable: el coordinador de las apps dependería de las mismas apps que coordina.

```
Correcto:
  Host (systemd) → K8s → Apps → bKernel escucha cambios

Incorrecto (rechazado):
  K8s → pod bKernel → necesita K8s para escuchar K8s
```

### Gestión de los daemons soberanos

Los daemons soberanos se instalan, actualizan y supervisan mediante el IAM Installer — no mediante el sistema de fichas K8s. Tienen sus propios manifests de actualización, sus propias señales de estado (SIGTERM, SIGHUP, SIGUSR1), y sus propios logs en `/var/log/sbos/`.

```
/etc/systemd/system/
  bos.service        → SBOS IAM Installer: Application & Process Orchestrator
  bkernel.service    → SBOS Data Kernel: Active Orchestration Engine
  biedata.service    → SBOS Data Integration: Federated Batch Exchange
  bcompass.service   → SBOS AI Tools: Collaborative & Federated Intelligence
  bsearch.service    → SBOS Data RAG: Sovereign Federated Intelligent Search
  bauth.service      → SBOS Auth Enforce: Unified Identity & Permissions Orchestrator
  bhnexus.service    → SBOS Nexus Host: The Unified Sovereign Connectivity Bridge

Prioridad de arranque:
  bkernel.service  Requires: postgresql.service
  biedata.service  Requires: bkernel.service
  bcompass.service Requires: bkernel.service
  bauth.service    Requires: postgresql.service
  bhnexus.service  Requires: bauth.service
  bos.service      Requires: (ninguno — arranca primero)
```

### Frontera absoluta: lo que los daemons soberanos NO hacen en K8s

Los daemons soberanos del host **nunca** crean pods, deployments, services ni recursos K8s directamente. Su interacción con el cluster es exclusivamente a través de sus APIs declarativas: PostgreSQL (lectura de WAL), Redis (pub/sub para señales de estado), y las APIs REST de los servicios K8s que consumen (Ollama, Qdrant). La gobernanza del cluster es dominio exclusivo del IAM Installer Core — los otros daemons son consumidores de datos, no administradores de infraestructura.

---

## 3. El Modelo Correcto: IAM Installer → Todo

Este es el principio más importante del documento.

### Modelo incorrecto (v2.0)

```
Técnico → instala K8s manualmente vía SSH
        → despliega Core UI manualmente
        → administrador toma el control
```

### Modelo correcto (v3.0+)

```
Ubuntu Server 24.04 LTS — instalación mínima, nada más
  │
  │  (única intervención humana del técnico SKULL)
  │  curl -sSL https://get.sbos.io/installer | sudo bash
  ▼
IAM Installer instalado como servicio systemd
  │
  │  IAM Installer detecta: "No hay K8s — ejecutar Ficha Bootstrap"
  ▼
Ficha Bootstrap SP-02 ejecuta (workload.type: bash)
  │  Instala Ubuntu hardening + CRI-O + kubeadm + K8s + Calico
  │  + MetalLB + Kyverno + namespaces + Core UI
  ▼
Ubuntu hardened + K8s cluster operativo + Core UI disponible
  │
  ▼
Administrador abre el navegador → Core UI
  │
  ▼
Instala fichas → stack empresarial completo
```

**La frontera es total:** el técnico SKULL no configura K8s. No despliega apps. No toca kubectl. Su única intervención es un comando en el servidor Ubuntu limpio. Todo lo demás lo hace el IAM Installer mediante la Ficha Bootstrap.

---

## 4. Las Fichas de Bootstrap: De Monolito a Etapas

> **Actualizado en v5.0.** La Ficha Bootstrap original (SP-02) se divide en **3 fichas de sistema + 1 ficha de validación + 1 ficha de hardening** que se intercalan con fichas de aplicación (PostgreSQL, Vault, Keycloak, etc.) en el grafo DAG. La especificación completa de las 16 fichas de la primera instalación está en SBOS-031-INSTALL-ROUTINE.

### Por qué son Fichas y no código del Core

**Versionable:** cuando sale una nueva versión de Kubernetes, se actualiza la ficha `sbos-bootstrap-k8s`. El IAM Installer la detecta como ACTUALIZACION_DISPONIBLE.

**Reparable:** si el cluster queda en estado inconsistente, la fase `repair` de cada ficha diagnostica y corrige su alcance sin afectar las demás.

**Auditable:** cada paso queda en el mismo sistema de logs y señales que cualquier otra operación.

**Auto-aplicable en cada arranque:** el IAM Installer revisa las fichas de bootstrap en cada arranque y aplica cambios pendientes automáticamente.

### Por qué se dividió el monolito

La Ficha Bootstrap original era un bloque de 18 tareas que se ejecutaban de corrido. Pero entre la preparación del SO y el despliegue del Core UI hay aplicaciones (PostgreSQL, Vault, Keycloak) que deben instalarse como contenedores K8s. Estas aplicaciones necesitan que K8s exista, que los namespaces estén creados, y que el StorageClass tenga un provisioner funcional — prerequisitos que el monolito original no separaba.

La división permite que las fichas de aplicación (Tipo 2, `workload.type: kubernetes`) se intercalen naturalmente con las fichas de bootstrap (Tipo 1, `workload.type: bash`) en el grafo DAG del `DEPENDENCY_RESOLVER`.

### Ficha 1: sbos-bootstrap-os (order: 0)

Prepara el sistema operativo para recibir Kubernetes. Sin esta ficha, `kubeadm init` falla en preflight checks.

```yaml
# yaml_engine.yml de sbos-bootstrap-os
phases:
  pre_install:
    tasks:
      - task: "bootstrap_validate_ubuntu_version"    # Ubuntu 24.04 LTS requerido
      - task: "bootstrap_validate_hardware"          # CPU >= 2, RAM >= 4GB, Disco >= 40GB
      - task: "bootstrap_validate_network"           # Conectividad para descargar imágenes

  install:
    # workload.type: bash — K8s no existe todavía
    tasks:
      - task: "bootstrap_harden_ubuntu"              # 25 sysctl, ulimits, SSH, auditd, AppArmor
      - task: "bootstrap_disable_swap"               # Requisito obligatorio de K8s
      - task: "bootstrap_configure_kernel_modules"   # overlay, br_netfilter
      - task: "bootstrap_install_crio"               # CRI-O: container runtime
      - task: "bootstrap_install_kubeadm_stack"      # kubeadm + kubelet + kubectl (versiones fijadas)
```

### Ficha 2: sbos-bootstrap-k8s (order: 1, depends_on: sbos-bootstrap-os)

Inicializa el cluster Kubernetes y configura la red. Después de esta ficha, el cluster existe y los pods pueden comunicarse.

```yaml
# yaml_engine.yml de sbos-bootstrap-k8s
phases:
  install:
    tasks:
      - task: "bootstrap_kubeadm_init"               # kubeadm init con kubeadm-config.yaml CIS
      - task: "bootstrap_install_calico"             # Calico CNI + GlobalNetworkPolicy deny-all
      - task: "bootstrap_install_metallb"            # LoadBalancer para bare metal / VPS
      - task: "bootstrap_install_metrics_server"     # Para HPA y kubectl top

  repair:
    diagnosis_first: true
    tasks:
      - task: "bootstrap_diagnose_cluster"
        on_failure: "continue"
      - task: "bootstrap_repair_etcd"
        on_failure: "abort"

  update:
    tasks:
      - task: "bootstrap_upgrade_kubernetes"
        update_strategy: "rolling"
      - task: "bootstrap_upgrade_calico"
```

### Ficha 3: sbos-bootstrap-platform (order: 2, depends_on: sbos-bootstrap-k8s)

Configura la plataforma K8s para recibir aplicaciones: namespaces, RBAC, StorageClass, seguridad. Sin esta ficha, los StatefulSets de PostgreSQL no pueden crear PVCs.

```yaml
# yaml_engine.yml de sbos-bootstrap-platform
phases:
  install:
    tasks:
      - task: "bootstrap_configure_rbac"             # installer-sa, patroni-sa
      - task: "bootstrap_create_namespaces"          # 14 namespaces sbos-*
      - task: "bootstrap_apply_quotas_and_limits"    # ResourceQuotas + LimitRanges
      - task: "bootstrap_apply_pod_security"         # Pod Security Standards por namespace
      - task: "bootstrap_configure_etcd_encryption"  # AES-256 para secrets en reposo
      - task: "bootstrap_configure_audit_logging"    # Audit log del API server
      - task: "bootstrap_install_storageclass"       # local-path-provisioner como default
      - task: "bootstrap_configure_cert_renewal"     # Cron TLS cada 90 días
```

### Ficha 4: sbos-k8s-network-validator (order: 3, depends_on: sbos-bootstrap-platform)

Pod efímero que certifica que la plataforma K8s está lista para recibir StatefulSets.

```yaml
# yaml_engine.yml de sbos-k8s-network-validator
phases:
  install:
    tasks:
      - task: "validate_cni_calico"                  # Calico operativo
      - task: "validate_dns_internal"                # kubernetes.default.svc resuelve
      - task: "validate_storageclass_default"        # PVC test → Bound → eliminar
      - task: "validate_metallb"                     # LoadBalancer funcional
      - task: "validate_inter_pod_connectivity"      # Ping entre namespaces
```

### Fichas de aplicación intercaladas (order: 100-300)

Después de las fichas de bootstrap, el daemon ejecuta las fichas de aplicación en orden DAG:

```
sbos-bootstrap-os (0) → sbos-bootstrap-k8s (1) → sbos-bootstrap-platform (2)
  → sbos-k8s-network-validator (3)
    → postgresql (100), redis (110), minio (115)
      → vault (120) → keycloak (130) → kong (145)
    → nginx (140), linkerd (150), kyverno (155)
    → prometheus (200), grafana (210)
      → sbos-bootstrap-hardening (300)
```

La especificación detallada de cada ficha (dependencias, tareas, tiempos, validación técnica) está en **SBOS-031-INSTALL-ROUTINE**.

### Ficha 16: sbos-bootstrap-hardening (order: 300, depends_on: keycloak, kong, prometheus, linkerd)

Verificación final después de que toda la infraestructura base está operativa.

```yaml
# yaml_engine.yml de sbos-bootstrap-hardening
phases:
  install:
    tasks:
      - task: "bootstrap_run_kube_bench"             # Verifica CIS Level 1 — todos PASS
      - task: "bootstrap_verify_network_policies"    # NetworkPolicies activas por namespace
      - task: "bootstrap_verify_mtls_linkerd"        # mTLS operativo entre pods
      - task: "bootstrap_verify_all_health_checks"   # Todos los servicios base responden
```

---

## 5. Lo que el IAM Installer Necesita para Arrancar

El IAM Installer se carga en un servidor con **Ubuntu Server 24.04 LTS recién instalado** — instalación mínima, sin ningún paquete adicional.

### Requisitos mínimos del servidor

| Recurso | Mínimo (nodo único) | Recomendado (producción) |
|---|---|---|
| CPU | 2 vCPU | 4+ vCPU |
| RAM | 4 GB | 8+ GB |
| Disco | 40 GB SSD | 100+ GB SSD |
| SO | Ubuntu Server 24.04 LTS | Ubuntu Server 24.04 LTS |
| Red | Conectividad a internet | IP estática + conectividad |

### El comando de instalación

```bash
# Lo único que hace el técnico SKULL — una vez, en el servidor Ubuntu limpio:
curl -sSL https://get.sbos.io/installer | sudo bash
```

Este script hace una única cosa: instala el IAM Installer como servicio systemd y lo arranca. Todo lo demás es automático.

---

## 6. Secuencia Completa: De Ubuntu Limpio a Sistema Base Operativo

> **Actualizado en v5.0.** La secuencia ahora refleja las fichas de bootstrap divididas intercaladas con fichas de aplicación (PostgreSQL, Vault, Keycloak, etc.). La especificación detallada está en SBOS-031-INSTALL-ROUTINE.

```
T+0:00  Ubuntu Server 24.04 LTS recién instalado (instalación mínima)
          │
          │  Técnico SKULL: curl -sSL https://get.sbos.io/installer | sudo bash
          │                 (opcionalmente: --deploy=cliente.deploy.yml)
          ▼
T+0:02  IAM Installer instalado como servicio systemd — arranca automáticamente
        DEPENDENCY_RESOLVER construye grafo DAG de todas las fichas
          ▼
        ━━━ Ficha 01: sbos-bootstrap-os (bash) ━━━
T+0:07  [✓] Ubuntu 24.04 validado, hardware OK, red OK
        [✓] Hardening: 25 sysctl, SSH, auditd, AppArmor
        [✓] Swap desactivado, kernel modules cargados
        [✓] CRI-O instalado, kubeadm stack instalado
          ▼
        ━━━ Ficha 02: sbos-bootstrap-k8s (bash) ━━━
T+0:15  [✓] kubeadm init — cluster K8s inicializado
        [✓] Calico CNI + GlobalNetworkPolicy deny-all
        [✓] MetalLB + metrics-server
          ▼
        ━━━ Ficha 03: sbos-bootstrap-platform (bash) ━━━
T+0:20  [✓] 14 namespaces sbos-* creados con RBAC
        [✓] StorageClass local-path-provisioner (default)
        [✓] Encriptación etcd + audit logging + cert renewal
          ▼
        ━━━ Ficha 04: sbos-k8s-network-validator (k8s) ━━━
T+0:21  [✓] CNI, DNS, StorageClass, MetalLB verificados
          ▼
        ━━━ Fichas de aplicación (k8s — contenedores) ━━━
T+0:24  [✓] Ficha 05: postgresql — StatefulSet + Patroni + BDs iniciales
T+0:25  [✓] Ficha 06: redis — StatefulSet + health check
T+0:27  [✓] Ficha 07: minio — StatefulSet + buckets iniciales
T+0:30  [✓] Ficha 08: vault — init + unseal + PKI engine
T+0:34  [✓] Ficha 09: keycloak — realm master + realm sbos
T+0:36  [✓] Ficha 10: nginx — reverse proxy + SSL
T+0:39  [✓] Ficha 11: kong — API Gateway + OAuth2 plugins
T+0:41  [✓] Ficha 12: linkerd — mTLS control plane
T+0:43  [✓] Ficha 13: kyverno — 4 políticas obligatorias
T+0:45  [✓] Ficha 14: prometheus — scraping todos los servicios
T+0:47  [✓] Ficha 15: grafana — dashboards + datasource
          ▼
        ━━━ Ficha 16: sbos-bootstrap-hardening (bash) ━━━
T+0:48  [✓] kube-bench CIS Level 1: todos PASS
        [✓] NetworkPolicies + mTLS + cert renewal verificados
          ▼
T+0:48  ══════ SISTEMA BASE COMPLETO ══════
        16 fichas instaladas
        Administrado por: bosctl status / bosctl fichas
        Si se proporcionó --deploy: continúa con productos adicionales
```

**Tiempo total:** aproximadamente 48 minutos desde Ubuntu limpio hasta sistema base operativo. El técnico puede ejecutar el comando y volver en 50 minutos — no hay pasos interactivos.

---

## 7. Topología del Cluster: De Nodo Único a Multi-Nodo

### Nodo único (cliente que empieza)

```
┌────────────────────────────────────────────────────────────────────┐
│  VPS ÚNICO (Ubuntu 24.04)                                          │
│                                                                    │
│  IAM Installer (systemd — fuera del cluster)                       │
│  bKernel (systemd — fuera del cluster)                             │
│  SBOS Data Integration (systemd — fuera del cluster)                            │
│  SBOS AI Tools (systemd — fuera del cluster)                            │
│    Core SP-01 (Motor Bash) + Backend Python (15 módulos)           │
│                                                                    │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │  KUBERNETES CLUSTER (nodo único)                            │  │
│  │                                                             │  │
│  │  Control Plane + Worker (mismo host)                        │  │
│  │  kube-apiserver · etcd · controller · scheduler · kubelet  │  │
│  │  CRI-O · Calico · MetalLB · metrics-server · Kyverno       │  │
│  │                                                             │  │
│  │  sbos-installer:  Core UI (Running)                         │  │
│  │  sbos-data:       vacío (esperando ficha postgresql)        │  │
│  │  sbos-identity:   vacío (esperando ficha keycloak)          │  │
│  │  ... (12 namespaces más — todos vacíos y listos)            │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  .sbos_state.json · servers/ (fichas)                              │
└────────────────────────────────────────────────────────────────────┘
```

En nodo único se remueve el `NoSchedule` taint del control plane. Esta es la única diferencia respecto a un cluster multi-nodo — todas las NetworkPolicies, RBAC, PVCs y ResourceQuotas funcionan exactamente igual.

### Multi-nodo (cliente en crecimiento)

```
┌─────────────────────┐  ┌──────────────────────┐  ┌─────────────────────┐
│  VPS Control Plane  │  │  VPS dataserver      │  │  VPS identityserver │
│  (HA: 3 nodos etcd) │  │  tipo=dataserver     │  │  tipo=identityserver│
│                     │  │                      │  │                     │
│  kube-apiserver x3  │  │  sbos-data:          │  │  sbos-identity:     │
│  etcd Raft x3       │  │    postgresql        │  │    keycloak         │
│  scheduler          │  │    redis             │  │    vault            │
│  controller         │  │    minio             │  │                     │
│                     │  │                      │  │                     │
│  (daemons soberanos │  │  bKernel (systemd)   │  │                     │
│  en el host CP)     │  │  SBOS Data Integration (systemd)  │  │                     │
└─────────────────────┘  └──────────────────────┘  └─────────────────────┘
          │                        │                         │
          └────────────────────────┴─────────────────────────┘
                         Calico CNI (L3 routing)
                    GlobalNetworkPolicy default-deny
```

El scheduling se controla con `nodeSelector` en el `.k8s.yml` de cada ficha. El IAM Installer aplica el label `tipo=<servidor-lógico>` automáticamente al agregar un nodo.

**Nota sobre daemons en multi-nodo:** los daemons soberanos (bKernel, SBOS Data Integration, SBOS AI Tools) siguen corriendo en el host del nodo donde reside PostgreSQL (dataserver). En modo multi-nodo, el nodo control plane no corre bKernel — solo el nodo dataserver necesita acceso directo al WAL de PostgreSQL.

---

## 8. Dónde Vive Cada Componente

| Componente | Dónde vive | Por qué |
|---|---|---|
| IAM Installer Core + Python | systemd en el host | Guardián del SO — no puede depender de lo que él mismo instala y vigila |
| **bKernel** | **systemd en el host** | **Escucha PostgreSQL WAL — necesita acceso directo al socket Unix del host. Ver §2.** |
| **SBOS Data Integration** | **systemd en el host** | **Escribe con origin='biedata' — coordinación atómica con bKernel requiere host local. Ver §2.** |
| **SBOS AI Tools** | **systemd en el host** | **Daemon de orquestación soberana — ciclo de vida independiente del cluster. Ver §2.** |
| Core UI (Flutter) | Pod K8s en `sbos-installer` | Instalado por la Ficha Bootstrap. Accesible por navegador |
| Todas las apps del BOS | Pods K8s en sus namespaces | Instaladas por el IAM Installer vía fichas |
| etcd | Control plane (kubeadm) | Base de datos del cluster — encriptada en reposo desde el bootstrap |
| Vault | Pod K8s en `sbos-security` | Instalado como ficha. Gestiona todos los secrets tras su instalación |

**El Vault bootstrap problem:** los secrets para instalar Vault se almacenan como K8s Secrets encriptados en etcd durante el bootstrap. Una vez que Vault está en `INSTALADA — OK`, el IAM Installer migra automáticamente esos K8s Secrets a Vault en el `post_install` de la ficha de Vault. Vault se convierte entonces en la fuente de verdad de todos los secrets del stack.

---

## 9. Namespaces y Gobernanza de Recursos

Los 14 namespaces se crean durante la Ficha Bootstrap — vacíos pero completamente configurados con ResourceQuotas, LimitRanges y Pod Security Standards. Están listos para recibir fichas desde el primer minuto.

### Los 14 Namespaces

| Namespace | Servidor Lógico | PSS |
|---|---|---|
| `sbos-installer` | IAM Installer UI | restricted |
| `sbos-data` | dataserver | restricted |
| `sbos-identity` | identityserver | restricted |
| `sbos-security` | securityserver | restricted |
| `sbos-gateway` | gatewayserver | baseline |
| `sbos-comms` | commsserver | baseline |
| `sbos-erp` | erpserver | baseline |
| `sbos-apps` | appsserver | baseline |
| `sbos-docs` | docserver | baseline |
| `sbos-monitor` | monitorserver | baseline |
| `sbos-geo` | geoserver | baseline |
| `sbos-vdi` | vdiserver | baseline |
| `sbos-search` | searchserver | baseline |
| `sbos-ops` | opsserver | baseline |

### ResourceQuotas + LimitRanges: el par obligatorio

Una vez aplicada una ResourceQuota en un namespace, todos los pods deben declarar `requests` y `limits`. Los LimitRanges establecen valores por defecto para pods que no los declaran.

```yaml
# ResourceQuota ejemplo — sbos-data
apiVersion: v1
kind: ResourceQuota
metadata:
  name: sbos-data-quota
  namespace: sbos-data
spec:
  hard:
    requests.cpu: "32"
    requests.memory: 128Gi
    limits.cpu: "64"
    limits.memory: 256Gi
    persistentvolumeclaims: "20"
    services.loadbalancers: "0"    # Los LB se definen solo en gateway
---
# LimitRange ejemplo — sbos-data
apiVersion: v1
kind: LimitRange
metadata:
  name: sbos-data-limits
  namespace: sbos-data
spec:
  limits:
  - type: Container
    default:
      cpu: "500m"
      memory: 512Mi
    defaultRequest:
      cpu: "100m"
      memory: 128Mi
    max:
      cpu: "16"
      memory: 64Gi
```

### PriorityClasses

```yaml
system-node-critical   → kube-system (CoreDNS, Calico, MetalLB)
system-cluster-critical → sbos-data (PostgreSQL, etcd)
high-priority          → sbos-identity (Keycloak, Vault)
normal-priority        → todos los demás namespaces
```

### PodDisruptionBudgets

Aplicados automáticamente en `post_install` de cada ficha con `replica_count >= 2`:

```yaml
minAvailable: 1  # Garantiza al menos 1 réplica disponible durante mantenimiento
```

---

## 10. Red: Zero Trust con Calico

La Ficha Bootstrap instala Calico CNI y aplica inmediatamente una **GlobalNetworkPolicy default-deny** para todo el cluster:

```yaml
# GlobalNetworkPolicy default-deny — aplicada en T+0:25
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: default-deny
spec:
  selector: all()
  types:
  - Ingress
  - Egress
  ingress: []
  egress: []
```

Desde ese momento, **ningún pod puede comunicarse con ningún otro** hasta que la NetworkPolicy de su ficha abra explícitamente los puertos necesarios. Cada ficha incluye su `<app>.network` que se aplica en `pre_install` — antes de que el pod exista.

La GlobalNetworkPolicy de Calico lo hace con un solo recurso para todo el cluster.

### NetworkPolicy de cada ficha: los puertos se abren al instalar

```yaml
# postgresql.network — se aplica en pre_install, antes de que el pod exista
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgresql-network
  namespace: sbos-data
spec:
  podSelector:
    matchLabels:
      app: postgresql
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          sbos-server: commsserver      # postfixadmin, roundcube, cypht
    - namespaceSelector:
        matchLabels:
          sbos-server: identityserver   # keycloak
    ports:
    - protocol: TCP
      port: 5432
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

### Flujo de tráfico permitido

```
Internet (HTTPS:443, SMTP:25, IMAP:993)
  │
  ▼
sbos-gateway (Kong + OAuth2-Proxy)
  ├──▶ sbos-comms      → sbos-data (postgresql:5432, redis:6379)
  ├──▶ sbos-identity   → sbos-data (postgresql:5432)
  ├──▶ sbos-erp, sbos-apps, sbos-docs... → sbos-data, sbos-identity
  └──▶ sbos-monitor    → todos (port 9090 métricas solamente)

kube-system ↔ todos los namespaces (port 53 DNS únicamente)
```

---

## 11. mTLS entre Servicios — Linkerd

Calico (NetworkPolicies) controla **quién puede hablar con quién** a nivel de red. Linkerd añade la segunda capa: **todo el tráfico entre pods es cifrado en tránsito con mTLS** — mutual TLS — sin ningún cambio en el código de las aplicaciones.

### Por qué Linkerd y no Istio

| Criterio | Linkerd | Istio |
|---|---|---|
| Overhead de memoria | ~10 MB por pod (proxy Rust) | ~50-100 MB por pod (Envoy C++) |
| Complejidad operacional | Baja — CRDs mínimos | Alta — superficie de configuración enorme |
| Tiempo de instalación | ~5 minutos (ficha) | ~20 minutos + tunning |
| mTLS automático | Sí — activado por defecto | Sí — pero requiere configuración explícita |
| Licencia | Apache 2.0 (CNCF) | Apache 2.0 (CNCF) |

Linkerd usa proxies escritos en Rust (linkerd2-proxy) — latencia sub-milisegundo, huella de memoria mínima. Para el perfil de SBOS (PyMEs, hardware moderado), el overhead de Istio es inaceptable.

### Cómo funciona el mTLS de Linkerd

```
Sin Linkerd (texto claro entre pods):
  Pod A (app) ──────────────────────────▶ Pod B (app)
               tráfico TCP sin cifrar

Con Linkerd (mTLS transparente):
  Pod A (app) ──▶ sidecar linkerd2-proxy ══[mTLS]══ sidecar linkerd2-proxy ──▶ Pod B (app)
                  (mismo pod, puerto 4140)              (mismo pod, puerto 4140)
               apps no saben que hay cifrado — es transparente
```

Las aplicaciones no necesitan implementar TLS. No necesitan gestionar certificados. No necesitan cambiar una línea de código. El sidecar proxy de Linkerd intercepta el tráfico de red del pod y lo cifra automáticamente.

### Inyección automática de sidecars

Los namespaces `sbos-*` tienen la anotación `linkerd.io/inject: enabled`. Cualquier pod que se despliegue en estos namespaces recibe automáticamente el sidecar de Linkerd — sin configuración por ficha.

```yaml
# Aplicado en bootstrap_create_namespaces
apiVersion: v1
kind: Namespace
metadata:
  name: sbos-data
  annotations:
    linkerd.io/inject: enabled
  labels:
    sbos-server: dataserver
    pod-security.kubernetes.io/enforce: restricted
```

### Observabilidad de Linkerd

El Core UI expone métricas de Linkerd via Grafana: tasa de éxito de requests entre servicios (success rate), latencia P50/P95/P99, y throughput en tiempo real. Las alertas en Alertmanager incluyen `linkerd_success_rate < 0.99` como condición de alerta `critical` para servicios de criticality alta.

---

## 12. Services: DNS Interno del Cluster

Las apps se conectan entre sí exclusivamente por nombre de Service Kubernetes — nunca por IP.

| Service | DNS Interno | Puerto | Tipo |
|---|---|---|---|
| PostgreSQL | `postgresql.sbos-data.svc.cluster.local` | 5432 | ClusterIP |
| Redis | `redis.sbos-data.svc.cluster.local` | 6379 | ClusterIP |
| MinIO | `minio.sbos-data.svc.cluster.local` | 9000 | ClusterIP |
| Keycloak | `keycloak.sbos-identity.svc.cluster.local` | 8080 | ClusterIP |
| Vault | `vault.sbos-identity.svc.cluster.local` | 8200 | ClusterIP |
| Kong (proxy) | `kong.sbos-gateway.svc.cluster.local` | 8000 | LoadBalancer |
| Mailserver SMTP | `mailserver.sbos-comms.svc.cluster.local` | 25 | LoadBalancer |
| Mailserver IMAP | `mailserver.sbos-comms.svc.cluster.local` | 993 | LoadBalancer |
| Prometheus | `prometheus.sbos-monitor.svc.cluster.local` | 9090 | ClusterIP |
| Core UI | `core-ui.sbos-installer.svc.cluster.local` | 443 | LoadBalancer |

**Regla de seguridad:** ningún Service de base de datos es `LoadBalancer` ni `NodePort` — todos son `ClusterIP`. Inaccesibles desde fuera del cluster por diseño. Los únicos `LoadBalancer` son Kong (HTTP), los puertos de correo (necesariamente expuestos), y el Core UI.

---

## 13. Hardening CIS: El Cluster Seguro por Defecto

La Ficha Bootstrap aplica el perfil **CIS Kubernetes Benchmark Level 1** completo.

### Estado del CIS Benchmark en 2026

El CIS Kubernetes Benchmark se actualiza con cada minor version de Kubernetes. La versión de referencia para Kubernetes 1.30+ es el **CIS Kubernetes Benchmark v1.10** (publicado en 2025). Los controles aplicados por la Ficha Bootstrap cubren el Level 1 completo de esta versión.

Los cambios relevantes respecto al v1.9 (versión anterior) en la versión v1.10 incluyen: nuevos controles para validación de imágenes con firma criptográfica (SLSA), controles adicionales para runtime security con seccomp profiles, y validación reforzada de configuración de etcd en clusters multi-nodo. La Ficha Bootstrap implementa todos estos controles nuevos.

La Ficha de Sistema `sbos-compliance-check` ejecuta `kube-bench` semanalmente contra el benchmark vigente. La versión del benchmark a usar se declara en el manifest de `sbos-compliance-check` y se actualiza con la ficha.

### API Server

```yaml
apiServer:
  extraArgs:
    anonymous-auth: "false"
    encryption-provider-config: /etc/kubernetes/encryption-config.yaml
    audit-log-path: /var/log/kubernetes/audit.log
    audit-log-maxage: "30"
    audit-log-maxbackup: "10"
    audit-log-maxsize: "100"
    audit-policy-file: /etc/kubernetes/audit-policy.yaml
    enable-admission-plugins: >-
      NodeRestriction,PodSecurity,ResourceQuota,LimitRanger,
      ServiceAccount,DefaultStorageClass,
      MutatingAdmissionWebhook,ValidatingAdmissionWebhook
    insecure-port: "0"
    tls-min-version: VersionTLS12
    profiling: "false"
    authorization-mode: Node,RBAC
```

### etcd: encriptación en reposo

Sin encriptación, los Kubernetes Secrets en etcd están en base64 — cualquier acceso a etcd los expone en texto claro:

```yaml
# /etc/kubernetes/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources: [secrets, configmaps]
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <BASE64_32_BYTE_KEY>    # Generado en el bootstrap
      - identity: {}
```

La clave AES se rota cada 90 días por la Ficha de Sistema `sbos-cert-rotation`, sin downtime.

### Kubelet

```yaml
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
authorization:
  mode: Webhook
readOnlyPort: 0              # Puerto 10255 desactivado
protectKernelDefaults: true
seccompDefault: true
tlsMinVersion: VersionTLS12
```

### Verificación continua

La Ficha de Sistema `sbos-compliance-check` ejecuta `kube-bench` semanalmente. Cualquier FAIL en controles críticos genera una alerta en el dashboard de salud del Core UI.

---

## 14. Admission Control: La Última Línea de Defensa

El SBOS usa **Kyverno** como admission controller — YAML nativo de Kubernetes, sin lenguajes adicionales como Rego.

### Las 4 políticas obligatorias en todos los namespaces `sbos-*`

```
sbos-disallow-privileged    → privileged: false
sbos-require-resources      → requests y limits obligatorios en CPU y memoria
sbos-disallow-latest-tag    → imagen != "*:latest"
sbos-require-probes         → readinessProbe obligatoria
```

Estas políticas garantizan que ningún pod que viole el hardening CIS pueda entrar al cluster — aunque alguien intentara aplicarlo manualmente con kubectl.

---

## 15. Especificaciones de Hardware por Servidor Lógico

| ID | Servidor | Workload K8s | vCPU | RAM | Disco | HA Mínimo | Notas |
|:---:|---|---|:---:|:---:|:---:|:---:|---|
| S01 | dataserver | StatefulSet | 16 | 64 GB | 2 TB NVMe | 3 nodos (Patroni) | NVMe obligatorio para IOPS de PostgreSQL |
| S02 | gatewayserver | Deployment | 8 | 16 GB | 100 GB SSD | 2 activo-activo | Kong stateless — escala sin límite |
| S03 | identityserver | Deployment | 8 | 16 GB | 200 GB SSD | 2 nodos | Sin Keycloak no hay autenticación en el stack |
| S04 | erpserver | StatefulSet | 16 | 32 GB | 500 GB SSD | 2 nodos | Sesiones de usuario concurrentes |
| S05 | devserver | Deployment | 8 | 16 GB | 200 GB SSD | 3+ pods | Gitea, CI/CD |
| S06 | appsserver | Deployment | 8 | 16 GB | 200 GB SSD | 2 pods/app | Apps variables por cliente |
| S07 | reportserver | CronJob+Deploy | 8 | 32 GB | 500 GB SSD | 2 nodos | Reportes pesados nocturnos |
| S08 | docserver | StatefulSet | 8 | 16 GB | 2 TB SSD | 2 nodos | SSD para acceso concurrente de archivos |
| S09 | searchserver | StatefulSet | 8 | 32 GB | 1 TB SSD | 3 nodos | Elasticsearch requiere quórum de 3 |
| S10 | commsserver | Deployment | 8 | 16 GB | 500 GB SSD | 2 nodos | 500 GB para buzones de correo |
| S11 | vdiserver | StatefulSet | 16 | 32 GB | 500 GB SSD | 2 + autoscale | Carga altamente variable |
| S12 | monitorserver | StatefulSet | 8 | 32 GB | 2 TB SSD | 2 nodos | Prometheus retención 90 días |
| S13 | geoserver | Deployment | 4 | 8 GB | 200 GB SSD | 2 nodos | Carga baja en mayoría de clientes |
| S14 | opsserver | CronJob+Deploy | 8 | 16 GB | 1 TB SSD | 1 + offsite DR | Disco para staging de backups offsite |
| S15 | aiserver | StatefulSet | 16 | 64 GB | 2 TB NVMe | 1 (opcional) | GPU NVIDIA recomendada para producción LLM |

---

## 16. Crecimiento Horizontal — 3 Parámetros

```
Desde el Core UI:
  1. IP del nuevo VPS (Ubuntu Server 24.04 limpio)
  2. Contraseña SSH root
  3. Tipo de servidor (dataserver / identityserver / commsserver / ...)
```

`INFRA_CONFIGURATOR.py` ejecuta automáticamente:

```
1. Conectar al nuevo VPS vía SSH
2. Aplicar el mismo hardening Ubuntu de la Ficha Bootstrap
3. Instalar CRI-O + kubeadm + kubelet en versiones idénticas al cluster
4. Generar token kubeadm join fresco (válido 24h)
5. Ejecutar kubeadm join
6. kubectl label node <nodo> tipo=<servidor-lógico>
7. Verificar nodo en estado Ready
8. K8s schedula pods automáticamente según nodeSelector
9. Notificar al administrador: nodo disponible
```

Nada requiere modificar ninguna ficha, ninguna configuración de aplicación, ni ningún DNS.

**TopologySpreadConstraints** para distribución uniforme entre nodos:

```yaml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: kubernetes.io/hostname
  whenUnsatisfiable: DoNotSchedule
  labelSelector:
    matchLabels:
      app: keycloak
```

---

## 17. Política de Actualización de Kubernetes

La versión de Kubernetes del cluster SBOS se gestiona mediante la Ficha de Sistema `sbos-k8s-upgrader` — no manualmente. Esta sección documenta la cadencia, el proceso de validación y el procedimiento de rollback.

### Cadencia de Actualización

El SBOS sigue la política de soporte de Kubernetes upstream. Kubernetes publica tres minor versions por año (aproximadamente cada 4 meses), con soporte de 14 meses por versión. La política del SBOS es:

| Tipo de versión | Política |
|---|---|
| **Patch release** (1.x.Y) | Actualización automática — sin aprobación manual. La Ficha `sbos-k8s-upgrader` la aplica dentro de 7 días del release. |
| **Minor release** (1.Y.0) | Actualización semiautomática — requiere aprobación del administrador en el Core UI. La Ficha la presenta como `ACTUALIZACION_DISPONIBLE` con changelog resumido. |
| **Major release** (X.0.0) | No aplica — Kubernetes no ha tenido un cambio de major desde v1. |

**Ventana de mantenimiento recomendada:** las minor releases se aplican en horario de bajo tráfico. La Ficha `sbos-k8s-upgrader` acepta una configuración de ventana de mantenimiento en su `manifest.yml`.

```yaml
# manifest.yml de sbos-k8s-upgrader
maintenance_window:
  enabled: true
  days: [saturday, sunday]
  start_hour: 02
  end_hour: 06
  timezone: "America/La_Paz"
```

### Proceso de Validación Pre-Upgrade

La Ficha `sbos-k8s-upgrader` nunca aplica un upgrade sin validar primero el estado del cluster. El proceso de validación incluye:

```
1. kubeadm upgrade plan → verificar compatibilidad de versión
2. Verificar estado de todos los nodos: kubectl get nodes (todos Ready)
3. Verificar estado de todos los pods críticos: PostgreSQL, Keycloak, Kong, Vault
4. Snapshot de etcd → backup atómico antes del upgrade
5. Verificar disponibilidad de imágenes de la nueva versión
6. Verificar PodDisruptionBudgets — ningún servicio violará su minAvailable durante rolling upgrade
```

Si cualquier paso de validación falla, el upgrade se cancela automáticamente y se notifica al administrador. El cluster permanece en su versión actual — no se aplican cambios parciales.

### Proceso de Upgrade

```
Paso 1: kubeadm upgrade apply vX.Y.Z (control plane)
  - API server actualizado
  - Controller manager actualizado
  - Scheduler actualizado
  - etcd actualizado (si aplica)

Paso 2: kubectl drain <nodo> --ignore-daemonsets (vaciar nodos uno por uno)
  - Los pods migran automáticamente a otros nodos por los PodDisruptionBudgets

Paso 3: apt upgrade kubelet kubectl en el nodo drenado

Paso 4: kubectl uncordon <nodo> (reactivar nodo)

Paso 5: Repetir pasos 2-4 para cada nodo worker (rolling — uno a la vez)

Paso 6: Actualizar Calico CNI a la versión compatible con el nuevo K8s

Paso 7: kube-bench — verificar CIS Level 1 en PASS en el cluster actualizado
```

El proceso garantiza **cero downtime** en modo multi-nodo. En nodo único, hay una ventana de indisponibilidad de 3–5 minutos durante el upgrade del control plane (API server reiniciado).

### Procedimiento de Rollback

Kubernetes **no tiene un rollback automático de versión** — bajar una versión de K8s no está soportado upstream. La estrategia de rollback del SBOS se basa en restauración de etcd:

**Si el upgrade falla durante el control plane (antes de que cualquier nodo worker sea actualizado):**

```
1. Detener kube-apiserver: systemctl stop kube-apiserver
2. Restaurar etcd desde el snapshot pre-upgrade:
   etcdctl snapshot restore /var/lib/etcd-backup/pre-upgrade.db \
     --data-dir /var/lib/etcd
3. Reinstalar binarios de la versión anterior:
   apt install kubeadm=X.Y.Z-00 kubelet=X.Y.Z-00 kubectl=X.Y.Z-00
4. Reiniciar servicios: systemctl restart kubelet
5. Verificar estado: kubectl get nodes
```

**Tiempo de RTO para rollback:** aproximadamente 15–20 minutos desde la detección del fallo hasta el cluster restaurado.

**Si el upgrade falla en un nodo worker ya actualizado:**

El nodo actualizado se elimina del cluster (`kubectl delete node <nodo>`) y se reprovisiona desde cero con `INFRA_CONFIGURATOR.py`. Los pods del nodo ya fueron evacuados por el `kubectl drain` antes del upgrade — no hay pérdida de datos.

**Lección operacional:** el snapshot de etcd en el paso de validación pre-upgrade es la garantía de rollback. Sin ese snapshot, el rollback es imposible. La Ficha `sbos-k8s-upgrader` nunca procede al upgrade sin confirmar que el snapshot existe y es válido.

---

## 18. Estado Final: Ubuntu Limpio → Cluster Listo

Al terminar la Ficha Bootstrap (~50 minutos):

### Sistema Operativo

25 sysctl · ulimits 3 capas · SSH solo clave pública · auditd CIS Level 1 · AppArmor · fail2ban · swap desactivado

### Kubernetes

CRI-O · Calico + GlobalNetworkPolicy deny-all · MetalLB · metrics-server · Kyverno (4 políticas) · RBAC installer-sa/patroni-sa · etcd encriptado AES-256 · Audit logging · Cron renovación TLS 90 días · kube-bench: todos CIS Level 1 en PASS

### Daemons soberanos del host (instalados por la Ficha Bootstrap)

IAM Installer Core (systemd, activo) · bKernel (systemd, en espera de PostgreSQL) · SBOS Data Integration (systemd, en espera de bKernel) · SBOS AI Tools (systemd, en espera de bKernel)

### Namespaces

```
kube-system:      Running  (CoreDNS, Calico, MetalLB, Kyverno, metrics-server)
sbos-installer:   Running  (Core UI — esperando instrucciones)

sbos-data:        Creado · Quota · LimitRange · PSS:restricted · vacío
sbos-identity:    Creado · Quota · LimitRange · PSS:restricted · vacío
sbos-security:    Creado · Quota · LimitRange · PSS:restricted · vacío
sbos-gateway:     Creado · Quota · LimitRange · PSS:baseline   · vacío
sbos-comms:       Creado · Quota · LimitRange · PSS:baseline   · vacío
sbos-erp:         Creado · Quota · LimitRange · PSS:baseline   · vacío
sbos-apps:        Creado · Quota · LimitRange · PSS:baseline   · vacío
sbos-docs:        Creado · Quota · LimitRange · PSS:baseline   · vacío
sbos-monitor:     Creado · Quota · LimitRange · PSS:baseline   · vacío
sbos-geo:         Creado · Quota · LimitRange · PSS:baseline   · vacío
sbos-vdi:         Creado · Quota · LimitRange · PSS:baseline   · vacío
sbos-search:      Creado · Quota · LimitRange · PSS:baseline   · vacío
sbos-ops:         Creado · Quota · LimitRange · PSS:baseline   · vacío
```

### Herramientas del host

yq · jq · curl · git · helm · kube-bench · crictl · Flutter SDK

---

## 19. Registro de Cambios v4.0

**C1 — Sección nueva "Daemons Soberanos del Host — Fuera de K8s" (§2):**
Nueva sección que aclara explícitamente que bKernel, SBOS Data Integration y SBOS AI Tools son servicios systemd del host Ubuntu — no pods K8s. La sección explica con detalle técnico por qué cada daemon no puede vivir en K8s: (1) acceso directo al WAL de PostgreSQL requiere latencia de microsegundos via socket Unix — imposible a través de la red overlay de K8s; (2) ciclo de vida independiente del cluster es necesario para escenarios de reparación de K8s; (3) coordinación atómica SBOS Data Integration/bKernel requiere host local para evitar race conditions. Incluye diagrama de dependencias systemd y especificación de la frontera absoluta de los daemons (no crean recursos K8s directamente).

**C2 — Política de actualización de Kubernetes (§17):**
Nueva sección completa que cubre cadencia de actualización (patch automático, minor semiautomático), proceso de validación pre-upgrade (7 pasos incluyendo snapshot de etcd), proceso de upgrade rolling (7 pasos con cero downtime en multi-nodo), y procedimiento de rollback (restauración de etcd + reinstalación de binarios, RTO ~15 minutos). Incluye configuración de ventana de mantenimiento en manifest.yml de sbos-k8s-upgrader. Lección operacional: el snapshot pre-upgrade es la única garantía de rollback viable.

**I1 — CIS Kubernetes Benchmark versión 2026:**
Verificado: el CIS Kubernetes Benchmark vigente para Kubernetes 1.30+ es la versión **v1.10**, publicada en 2025. Agrega controles para: validación de imágenes con firma criptográfica (SLSA), runtime security con seccomp profiles obligatorios, y validación reforzada de etcd en clusters multi-nodo. La Ficha Bootstrap implementa todos los controles Level 1 del v1.10. Documentado en §13.

**Actualización menor:** la topología multi-nodo en §7 incluye ahora los daemons soberanos explícitamente en el diagrama ASCII, mostrando que bKernel e SBOS Data Integration corren en el host del nodo dataserver — no en el control plane.

---

*SKULL · SBOS · SBOS-004-K8S · v4.0 · Marzo 2026*

> **Referencias:** kubeadm — kubernetes.io (oficial) · CIS Kubernetes Benchmark v1.10 — Center for Internet Security · kube-bench — Aqua Security (CNCF) · Calico CNI Zero Trust — Tigera Project · Kyverno Policy Engine — CNCF Incubating · Linkerd — linkerd.io (CNCF) · MetalLB — metallb.universe.tf · NSA/CISA Kubernetes Hardening Guidance (2022) · NIST SP 800-190 Application Container Security Guide · Kubernetes Upgrade Documentation — kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade
