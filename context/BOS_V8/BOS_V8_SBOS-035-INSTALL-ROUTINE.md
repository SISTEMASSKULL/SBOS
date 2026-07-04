# SBOS-035-INSTALL-ROUTINE
## Rutina Profesional de Instalación del IAM Installer — Estándar HUMAN-DOC
### SKULL · SBOS · v1.0 · Abril 2026

---

## 1. Principio

Cada etapa de la instalación es una ficha. El daemon bos lee fichas, resuelve dependencias, ejecuta en orden. No hay código especial de "bootstrap" — mismo motor que instala PG instala K8s. Diferencia: workload.type (bash en host vs contenedor en K8s). Idempotente: ficha instalada y healthy → salta. Re-ejecutar verifica y no hace nada.

## 2. Las 16 Fichas de la Secuencia

### FICHA 01: sbos-bootstrap-os (order: 0, bash)
Valida Ubuntu 26.04, CPU≥2, RAM≥4GB, disco≥40GB. Hardening: 25 sysctl, ulimits, SSH, auditd, AppArmor, fail2ban. Desactiva swap. Carga módulos overlay + br_netfilter. Instala CRI-O + kubeadm/kubelet/kubectl (pinados).

### FICHA 02: sbos-bootstrap-k8s (order: 1, bash, depends: 01)
kubeadm init CIS hardened → API Server + etcd + controller + scheduler. Calico CNI + GlobalNetworkPolicy deny-all. MetalLB (LoadBalancer bare metal). metrics-server. Nodo único: remove taint NoSchedule.

### FICHA 03: sbos-bootstrap-platform (order: 2, bash, depends: 02)
14 namespaces sbos-* con Linkerd inject. RBAC ServiceAccounts. ResourceQuotas + LimitRanges. Pod Security Standards. Encriptación etcd AES-256-CBC. Audit logging API server. **StorageClass local-path-provisioner (default)**. Cron renovación TLS 90 días.

### FICHA 04: sbos-k8s-network-validator (order: 3, k8s efímero, depends: 03)
Pod efímero certifica: CNI Calico OK, DNS interno OK, conectividad inter-pod, StorageClass default funcional (PVC test), MetalLB OK. Fallo → ABORT con causa + solución. Éxito → se elimina.

### FICHA 05: postgresql (order: 100, StatefulSet, depends: 04)
NetworkPolicy. StatefulSet PG 18 + Patroni HA + PVC. Crea BDs iniciales (keycloak_db, kong_db, grafana_db, bkernel_db, bcompass_db). Health: pg_isready.

### FICHA 06: redis (order: 110, StatefulSet, depends: 04)
StatefulSet + health: redis-cli ping = PONG.

### FICHA 07: minio (order: 115, StatefulSet, depends: 04)
StatefulSet + buckets iniciales (backups, uploads, archives).

### FICHA 08: vault (order: 120, StatefulSet, depends: PG)
vault operator init → 5 unseal keys + root token. Unseal. Backend PG. PKI engine. Root token en .sbos_state.json encriptado.

### FICHA 09: keycloak (order: 130, StatefulSet, depends: PG + Vault)
Credenciales BD desde Vault. keycloak_db. Realm master + realm skbos con auth flows base.

### FICHA 10: nginx (order: 140, Deployment, depends: 03)
Reverse proxy + SSL termination (auto-firmado inicial, renovable Vault PKI).

### FICHA 11: kong (order: 145, Deployment, depends: PG + KC)
API Gateway. kong_db. Plugins OAuth2 contra KC. Rutas base.

### FICHA 12: linkerd (order: 150, Deployment, depends: 03)
Control plane. mTLS automático en namespaces sbos-*. linkerd check OK.

### FICHA 13: kyverno (order: 155, Deployment, depends: 03)
Admission controller. 4 políticas: restrict-image-registries, require-labels, restrict-host-path, require-resource-limits.

### FICHA 14: prometheus (order: 200, StatefulSet, depends: 03)
Scrape targets todos los servicios.

### FICHA 15: grafana (order: 210, Deployment, depends: PG + Prometheus)
Datasource Prometheus. 3 dashboards base.

### FICHA 16: sbos-bootstrap-hardening (order: 300, bash, depends: KC + Kong + Prometheus + Linkerd)
kube-bench CIS Level 1: 42/42 PASS. NetworkPolicies 14/14 namespaces. mTLS Linkerd activo. Cert renewal cron. → **SISTEMA BASE COMPLETO**.

## 3. DAG de Dependencias

```
sbos-bootstrap-os (0)
  └──▶ sbos-bootstrap-k8s (1)
         └──▶ sbos-bootstrap-platform (2)
                ├──▶ network-validator (3)
                │      ├──▶ postgresql (100)
                │      │      ├──▶ vault (120) ──▶ keycloak (130) ──▶ kong (145)
                │      │      └──▶ grafana (210)
                │      ├──▶ redis (110)
                │      └──▶ minio (115)
                ├──▶ nginx (140)
                ├──▶ linkerd (150)
                ├──▶ kyverno (155)
                └──▶ prometheus (200) ──▶ grafana (210)
                
Todo converge → sbos-bootstrap-hardening (300)
═══════════════════════════════════════
  SISTEMA BASE COMPLETO · 16 fichas · ~48 min desde Ubuntu limpio
```

## 4. Timeline

| Tiempo | Ficha | Qué ocurre |
|---|---|---|
| T+0:00 | — | `curl -sSL https://get.skbos.io/installer \| sudo bash` |
| T+0:02 | bootstrap-os | Hardening + CRI-O + kubeadm |
| T+0:07 | bootstrap-k8s | kubeadm init + Calico + MetalLB |
| T+0:15 | bootstrap-platform | Namespaces + RBAC + StorageClass + etcd encryption |
| T+0:20 | network-validator | CNI + DNS + StorageClass + MetalLB OK |
| T+0:21 | postgresql | StatefulSet + Patroni + BDs |
| T+0:24 | redis + minio | StatefulSets data |
| T+0:27 | vault | Init + unseal + PKI |
| T+0:30 | keycloak | Realms + auth flows |
| T+0:34 | nginx + kong | Gateway + SSL + OAuth2 |
| T+0:40 | linkerd + kyverno | mTLS + policies |
| T+0:44 | prometheus + grafana | Observabilidad |
| T+0:48 | hardening | CIS benchmark + verificación final |
| **T+0:48** | **COMPLETO** | **16 fichas OK — bosctl status** |

## 5. Post Sistema Base — Apps de Negocio

```bash
bosctl install tryton       # ERP
bosctl install mailserver   # Correo
bosctl install roundcube    # Webmail
bosctl install nextcloud    # Archivos
bosctl install wazuh        # SIEM
bosctl install core-ui      # Cuando esté desarrollado
```

Cada ficha tiene depends_on resuelto automáticamente por el daemon.

## 6. Relación con Productos y Deploy

Esta rutina = producto `bootstrap` (SBOS-032). Único con auto_install: true.
```
bosctl deploy cliente.deploy.yml
  ├── Producto bootstrap (16 fichas — esta rutina)
  ├── Producto mail (4 fichas)
  ├── Producto erp (2 fichas)
  └── ...
```

---

## Trazabilidad

| Sección | Extraída de | Secciones originales |
|---|---|---|
| §1 Principio | SBOS-031 v1.0 | §1 (idempotencia, bosctl) |
| §2 16 Fichas | SBOS-031 v1.0 | §2 completo (16 fichas con order, tipo, depends_on, qué hace, validación técnica) |
| §3 DAG | SBOS-031 v1.0 | §3 (grafo DAG ASCII completo) |
| §4 Timeline | SBOS-031 v1.0 | §4 (tabla T+0 a T+48 con tiempos por ficha) |
| §5 Post-base | SBOS-031 v1.0 | §6 (bosctl install apps negocio) |
| §6 Productos | SBOS-031 v1.0 | §7 (relación con SBOS-032/033, deploy.yml) |

---

---

# ENRIQUECIMIENTO V8 — SBOS-035-INSTALL-ROUTINE

## V5 — Enriquecimiento desde BOS_V5_SBOS-031-INSTALL-ROUTINE-v1_0

### V5 §1 — Detalle Técnico de Cada Ficha

**FICHA 01 — bootstrap-os (validación y hardening)**
```
Validación pre-vuelo:
  - OS: Ubuntu 26.04 LTS (lsb_release -a)
  - CPU: ≥ 2 cores (nproc)
  - RAM: ≥ 4GB (free -m)
  - Disco: ≥ 40GB (df -h /)
  - Red: conectividad a release.skull.systems:443 (curl --connect-timeout 5)
  - Kernel: ≥ 5.15 (uname -r)

Hardening de seguridad (25 sysctl + 7 módulos):
  - sysctl: kernel.kptr_restrict=2, kernel.dmesg_restrict=1,
    kernel.randomize_va_space=2, net.ipv4.conf.all.rp_filter=1,
    net.ipv4.tcp_syncookies=1, fs.protected_hardlinks=1,
    fs.protected_symlinks=1, net.ipv4.conf.all.log_martians=1,
    net.ipv6.conf.all.disable_ipv6=0 (no deshabilitar),
    vm.swappiness=1, vm.overcommit_memory=1 + 17 más

  - Módulos: overlay, br_netfilter, ip_vs, ip_vs_rr, ip_vs_wrr, ip_vs_sh, nf_conntrack

  - Deshabilitar: swap (swapoff -a && sed -i '/swap/d' /etc/fstab)

  - Servicios: instalar CRI-O, kubeadm, kubelet, kubectl (versiones pinzadas)
```

**FICHA 02 — bootstrap-k8s (CIS hardened)**
```
kubeadm init:
  - API Server: --audit-log-path, --encryption-provider-config (AES-256-CBC)
  - Controller Manager: --terminated-pod-gc-threshold=100
  - Scheduler: --policy-config-map=scheduler-policy
  - etcd: cifrado en reposo + autenticación mutua

Post-init:
  - Calico CNI con NetworkPolicy enforcement
  - GlobalNetworkPolicy deny-all (default-deny para tráfico entrante/saliente)
  - MetalLB (LoadBalancer L2 para bare metal)
  - metrics-server (autoscaling base)
  - Remove taint NoSchedule del nodo único
```

**FICHA 16 — hardening (CIS benchmark 42/42)**
```
kube-bench ejecuta 42 tests CIS Kubernetes Benchmark Level 1:
  - Master node security (12 tests)
  - Control plane configuration (10 tests)
  - Worker node security (8 tests)
  - Policies and permissions (7 tests)
  - Logging and monitoring (5 tests)

Cobertura post-hardening:
  - 14 namespaces con NetworkPolicy (deny-all + allow-list)
  - Linkerd mTLS activo en todos los namespaces sbos-*
  - Cron job de renovación TLS cada 90 días
  - PodSecurityStandards aplicados en todos los namespaces
  - ResourceQuotas + LimitRanges en cada namespace
```

### V5 §2 — DAG de Dependencias con Validaciones Técnicas

Cada ficha ejecuta validaciones específicas antes de marcar éxito:

| Ficha | Validación técnica de éxito |
|---|---|
| bootstrap-os | `kubectl version --client`, `crio --version`, sysctl persistidos |
| bootstrap-k8s | `kubectl get nodes -o wide`, `kubectl cluster-info`, Calico pods Running |
| bootstrap-platform | `kubectl get ns`, `kubectl get sc`, `lsns` para Linkerd injection |
| network-validator | Pod efímero corre 5 checks: CNI, DNS, inter-pod, PVC, MetalLB |
| postgresql | `pg_isready`, Patroni member list, BDs iniciales creadas |
| vault | `vault status` → Sealed: false, PKI mount listo |
| keycloak | `curl -f http://keycloak:8080/realms/sbos/.well-known/openid-configuration` |
| hardening | `kube-bench run --version 1.0 --targets master,node` → 42/42 |

---

## Fuentes de Enriquecimiento V8

| Fuente | Archivo | Secciones utilizadas |
|---|---|---|
| V6 original | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V6_SBOS-035-INSTALL-ROUTINE.md` | Documento completo (142 líneas) |
| V5 Install | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-031-INSTALL-ROUTINE-v1_0.md` | §1 Detalle técnico fichas 01, 02, 16, §2 DAG con validaciones técnicas, §3 Timeline expandido |

---

_SKULL · SBOS · SBOS-035-INSTALL-ROUTINE · V8 (V6+V5) · Mayo 2026_
