# Soluciones Rootless K8s — SBOS Bootstrap

**Generado por:** Compositor S-29 (formalización in-situ PFI)
**Fecha:** 2026-05-19
**Proyecto:** SBOS — BosAgent
**Ficha:** sbos-bootstrap-k8s (task_catalog.sh)

---

## 1. Problema raíz

Ejecutar `kubeadm init` dentro de un contenedor Podman **rootless** (sin sudo, UID 1000 en host)
requiere que los procesos anidados (runc/crun, kubelet, static pods) operen con capacidades de
kernel que el user namespace de rootless podman no puede delegar.

El kernel de Linux exige `CAP_SYS_RESOURCE` en el **initial user namespace** (host root real)
para ciertas operaciones. Los procesos dentro del contenedor, aunque se ejecuten como
UID 0 dentro del contenedor, son host UID 1000 y NO tienen el initial userns.

---

## 2. Stack de soluciones aplicadas

### 2.1 Parámetros de creación del contenedor (S-29)

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

| Parámetro | Propósito |
|---|---|
| `--privileged` | Desactiva la mayoría de restricciones de capacidades |
| `--cgroupns=private` | **(S-29)** Namespace de cgroups privado — el systemd del contenedor gestiona su propio árbol de cgroups. Sin esto, el contenedor hereda el cgroupns del host y no puede delegar controladores |
| `--security-opt seccomp=unconfined` | Permite syscalls bloqueadas por el perfil default (mount, pivot_root) |
| `--security-opt apparmor=unconfined` | Ídem para AppArmor |
| `--tmpfs /tmp --tmpfs /run` | systemd necesita /run escribible (patrón KIND) |
| `--volume /lib/modules:/lib/modules:ro` | K8s necesita leer módulos del kernel |
| `-e container=podman` | Señaliza a systemd que corre en contenedor |

**IMPORTANTE:** NO montar `-v /sys/fs/cgroup:/sys/fs/cgroup:rw`. Con `--cgroupns=private`,
el namespace privado de cgroups no coincide con el filesystem del host, causando errores
`EXDEV` (invalid cross-device link) en runc.

### 2.2 Configuración de containerd (task_catalog.sh — P24, P26, P27, P29)

```
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = false          # Default — usar cgroupfs driver (S-26)
  NoPivotRoot = true             # P24: contenedor anidado usa overlayfs como rootfs
  NoNewKeyring = true            # P26: sin CAP_SYS_ADMIN en initial userns
  BinaryName = '/usr/bin/crun'   # P27: crun como OCI runtime
  restrict_oom_score_adj = true  # P29: solución oficial K8s para KubeletInUserNamespace
```

#### P29: `restrict_oom_score_adj = true` — Solución oficial K8s

**Error que resuelve:**
```
OCI runtime create failed: oom_score_adj: Permission denied
```

**Causa:** El kernel exige `CAP_SYS_RESOURCE` en el **initial user namespace** para
escribir en `/proc/self/oom_score_adj`. Los procesos rootless no tienen esta capacidad.

**Qué hace:** Delegar el manejo del OOM score al daemon de containerd en lugar del
OCI runtime. El runtime ya no intenta escribir en `/proc/self/oom_score_adj`.

**Referencia:** KEP-2033 (KubeletInUserNamespace), documentación oficial de containerd.

### 2.3 Configuración de kubelet (task_catalog.sh — P29)

```ini
# /etc/systemd/system/kubelet.service.d/delegate.conf
[Service]
Delegate=yes
```

Permite que kubelet gestione sub-cgroups para pods sin que systemd revoque los permisos.

### 2.4 Parámetros de kubeadm init

```yaml
nodeRegistration:
  kubeletExtraArgs:
  - name: cgroup-driver
    value: cgroupfs
  - name: cgroups-per-qos
    value: "false"
  - name: enforce-node-allocatable
    value: ""
  - name: feature-gates
    value: KubeletInUserNamespace=true
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: cgroupfs
featureGates:
  KubeletInUserNamespace: true
```

### 2.5 P30: Delegación de controladores cgroup v2

**Error que resuelve:**
```
OCI runtime create failed: controller `cpu` is not available under \
  /sys/fs/cgroup/k8s.io/<pod-hash>/cgroup.controllers
```

**Causa:** Con `--cgroupns=private`, el systemd del contenedor solo delega `memory` y `pids`
en el `cgroup.subtree_control` raíz. El controlador `cpu` está disponible en
`cgroup.controllers` pero NO habilitado en `cgroup.subtree_control`. Sin `cpu` delegado,
los sub-cgroups de pods tienen `cgroup.controllers` vacío, y runc falla.

**Solución:** Un servicio systemd oneshot que se ejecuta antes de containerd y escribe
`+cpu` (y `+io`, `+cpuset` si están disponibles) en `/sys/fs/cgroup/cgroup.subtree_control`:

```ini
# /etc/systemd/system/cgroup-delegate-cpu.service
[Unit]
Description=Enable CPU/IO/cpuset controllers in root cgroup subtree_control
Before=containerd.service kubelet.service
DefaultDependencies=no
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c "\
    available=\$(cat /sys/fs/cgroup/cgroup.controllers 2>/dev/null); \
    delegated=\$(cat /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null); \
    for ctrl in cpu cpuset io; do \
        if echo \"\$available\" | grep -qw \"\$ctrl\" && ! echo \"\$delegated\" | grep -qw \"\$ctrl\"; then \
            echo \"+\$ctrl\" > /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || true; \
        fi; \
    done"

[Install]
WantedBy=multi-user.target
```

**Implementado en:** `task_catalog.sh` → función `_setup_cgroup_delegation()`.

### 2.6 P31: Propagación explícita de controllers en cada nivel de jerarquía cgroup v2

**Error que resuelve:**
```
controller 'cpu' is not available under /sys/fs/cgroup/k8s.io/<pod>/cgroup.controllers
```

**Causa raíz (documentada en kernel.org):** En cgroup v2, los controllers NO se heredan
automáticamente — deben habilitarse explícitamente escribiendo en `cgroup.subtree_control`
de cada nivel de la jerarquía. El directorio `k8s.io` tiene `cgroup.controllers` vacío
porque kubeadm lo crea pero no escribe en su `subtree_control`.

**Solución:** Función `_ensure_cgroup_controllers()` que propaga todos los controllers
disponibles en root hacia `k8s.io` y recursivamente a todos los subdirectorios de pods.
Si `k8s.io` está estancado (creado antes de que root tuviera controllers), migra procesos
y elimina subdirectorios para que containerd los recree con herencia correcta.

**Llamado en:** `ficha_pre_install`, `ficha_post_install`, `ficha_repair`.

### 2.7 P18: CNI adaptativo — kindnet para contenedor, Calico para bare-metal

**Error que resuelve:** Calico `install-cni` CrashLoopBackOff en contenedor anidado:
```
failed to generate container spec: path "/var/run/netns" is mounted on
"/run" but it is not a shared or slave mount
```

**Causa:** Calico requiere montar `/host/opt/cni/bin` desde el host para instalar sus
binarios CNI, lo cual es imposible en contenedor rootless sin privilegios sobre el
filesystem del host.

**Solución:** Detección adaptativa del entorno (P18). `_install_cni()` elige:
- **Contenedor anidado** → kindnet (Kubernetes SIG Testing), CNI oficial para K8s-en-contenedor sin bind-mounts del host
- **Bare-metal/VM** → Calico, CNI completo con network policies

**Implementado en:** `task_catalog.sh` → función `_install_cni()`.

---

## 3. Evidencia verificable

### 3.1 `oom_score_adj: Permission denied` — RESUELTO (P29)

```bash
# → restrict_oom_score_adj = true
```

### 3.2 Containerd funcional

```bash
# → active
```

### 3.3 Delegación de controladores — RESUELTO (P30)

```bash
# Debe mostrar: cpu memory pids  (al menos)
```

### 3.4 Servicio de delegación activo

```bash
# → active
```

### 3.5 Herencia de controladores a hijos

```bash
# Debe mostrar: cpu memory pids
```

---

## 4. Referencias

- [Kubernetes: KubeletInUserNamespace](https://kubernetes.io/docs/tasks/administer-cluster/kubelet-in-userns/)
- [rootlesscontaine.rs: cgroup v2 delegation](https://rootlesscontaine.rs/getting-started/common/cgroup2/)
- [KIND: rootless podman provider](https://github.com/kubernetes-sigs/kind/blob/main/pkg/cluster/internal/providers/podman/provision.go)
- [containerd: CRI config reference](https://github.com/containerd/containerd/blob/main/docs/cri/config.md)
- KEP-2033: KubeletInUserNamespace
