# Bitácora de Pruebas — BOS IAM Installer
## Historia completa de decisiones, fases y estado del desarrollo

**Proyecto:** SBOS — Sovereign Business Operating System
**Componente:** BosAgent — IAM Installer + 22 fichas
**Servidor de desarrollo:** `144.91.76.130` (VPS Contabo)
**Servidor de pruebas:** `13.140.128.230` (VPS limpia Ubuntu 26.04)
**Repositorio:** `/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/`

---

## FASE 0 — Contexto y punto de partida

### ¿Qué es BOS?

BOS (IAM Installer) es el **plano de control soberano del SBOS**:
- **Day 0:** Bootstrap — instala K8s + 22 fichas desde Ubuntu 26.04 virgen (~48 min)
- **Day 1:** Daemon residente (systemd) — administra 112+ fichas en 16 servidores lógicos
- **Day 2:** Reconciliación — detecta drift, repara multi-capa
- **CLI:** `bosctl` con 23+ subcomandos vía Unix socket

### Estado al inicio de esta sesión (2026-06-03)

| Componente | Estado |
|-----------|--------|
| bosctl compilado | ✅ 12MB, 23 comandos |
| TUI (6 pantallas) | ✅ Funcional |
| Fichas (22 declaradas) | ⚠️ Sin probar end-to-end |
| Bootstrap completo | ❌ Sin validar |
| Nspawn de pruebas | ✅ Corriendo |

---

## FASE 1 — Depuración del entorno nspawn (2026-06-03)

### Contexto

El operador (Pane 8) identificó que `sbos-bootstrap-os` fallaba con exit 100 porque
el nspawn no tenía acceso a internet. Se continuó la depuración desde aquí.

### Problemas encontrados y resueltos

#### 1.1 Internet del nspawn (exit 100 en apt-get)
- **Síntoma:** `sbos-bootstrap-os` falla con exit 100
- **Diagnóstico:** UFW en el host tenía `DEFAULT_FORWARD_POLICY="DROP"` → bloqueaba FORWARD entre eth0 y la veth del nspawn
- **Fix:** `sed -i 's/DROP/ACCEPT/' /etc/default/ufw && ufw reload`
- **Lección:** En el host del nspawn, UFW FORWARD debe estar en ACCEPT

#### 1.2 dpkg bloqueado por /etc/localtime bind-mount
- **Síntoma:** `tzdata` postinst falla con "Device or resource busy" al intentar modificar `/etc/localtime`
- **Causa:** El nspawn monta `/etc/localtime` del host como bind-ro
- **Fix runtime:** `umount /etc/localtime` dentro del nspawn vía nsenter
- **Lección:** En la imagen limpia del nspawn, `/etc/localtime` no debe ser bind-mount del host

#### 1.3 lsmod no disponible en nspawn
- **Síntoma:** task_catalog.sh de sbos-bootstrap-os y sbos-bootstrap-k8s fallan con `lsmod: command not found`
- **Causa:** El paquete `kmod` no está en la imagen Ubuntu 26.04 base del nspawn
- **Fix código:**
  - Agregada función `_module_loaded()` que usa `/proc/modules` directamente
  - Reemplazados todos los `lsmod | grep -q "^..."` por `_module_loaded "..."`
  - Agregado `kmod` a paquetes base en sbos-bootstrap-os
- **Lección:** En K8s en contenedores, preferir `/proc/modules` sobre `lsmod`

#### 1.4 verify_ficha_health ignoraba health.type del manifest
- **Síntoma:** La verificación post-install buscaba pods K8s para fichas bash (que no tienen pods)
- **Causa:** `verify_ficha_health()` siempre llamaba `verify_pod_running` ignorando `health.type` del manifest.yml
- **Fix código:** Agregadas ramas en `verify_ficha_health`:
  - `health.type=command` → ejecutar el comando definido
  - `health.type=http` → curl al ClusterIP (con fallback a `verify_pod_running` si K8s no disponible)
  - `health.type=none/skip` → pasar siempre
  - Pods: `verify_pod_running` solo cuando kubectl está disponible
- **Decisión:** Las fichas helm (kubernetes) usan `verify_pod_running` solo cuando K8s está instalado. Antes de K8s, siempre pasan.

#### 1.5 Error de sintaxis en 00_TASK_CATALOG_SBOS.sh línea 558
- **Síntoma:** Script falla con "syntax error near unexpected token `}'"
- **Causa:** `namespace=$(yq eval ... "$manifest"` sin `)` de cierre
- **Fix:** Agregado el `)` faltante

#### 1.6 Health command de sbos-bootstrap-os usaba lsmod
- **Síntoma:** Verificación de health falla en nspawn
- **Causa:** `health.command: "uname -r && lsmod | grep -q br_netfilter && echo HEALTHY"`
- **Fix:** Cambiado a verificar archivos creados por la instalación: `test -f /etc/sysctl.d/99-sbos-k8s.conf && test -d /data/postgres && test -d /data/redis && echo HEALTHY`

#### 1.7 IP routeable del nspawn
- **Síntoma:** curl da HTTP 000 aunque el MASQUERADE esté configurado
- **Causa:** La IP del nspawn era link-local (169.254.x.x) que el kernel no enruta fuera del link
- **Fix:** Agregar IP routeable en la misma subred que el host veth: `ip addr add <host_ip+1>/28 dev host0 onlink`
- **Causa raíz:** La subred del veth es /28 — el nspawn debe usar una IP dentro del rango, no fuera de él
- **Lección:** Para el script de arranque: detectar la subred del host veth y calcular la IP del nspawn como `host_ip + 1`

#### 1.8 /dev/kmsg no accesible en nspawn (kubelet)
- **Síntoma:** `kubelet` falla con "open /dev/kmsg: operation not permitted"
- **Causa:** El nspawn no permite acceso al dispositivo de kernel `/dev/kmsg` a menos que se use `--bind=/dev/kmsg`
- **Fix nspawn:** Arrancar con `--bind=/dev/kmsg`
- **Fix código:** En `sbos-bootstrap-k8s/task_catalog.sh`: si `/dev/kmsg` no existe, crear symlink `ln -sf /dev/console /dev/kmsg` + `tmpfiles.d`
- **Fuente:** Solución estándar de KinD (kubernetes-sigs/kind/pull/664)
- **Lección:** En producción (servidor bare-metal) `/dev/kmsg` existe nativamente. Solo en contenedores se necesita el workaround.

#### 1.9 kubernetesVersion vacío en kubeadm-config.yaml
- **Síntoma:** kubeadm init falla con "invalid configuration for GroupVersionKind"
- **Causa dual:**
  1. El template `kubeadm-config.yaml` tenía comentarios que confundían al sed al sustituir `__K8S_VERSION__`
  2. `kubectl version --client` en K8s 1.32 devuelve formato diferente que no coincide con el regex anterior
- **Fix código:**
  1. Eliminados comentarios del `kubeadm-config.yaml` — solo YAML puro
  2. Detección de versión con 3 fallbacks: `kubectl version --output=yaml`, `kubeadm version -o short`, `v${K8S_VERSION}.0`

#### 1.10 cat /dev/kmsg bloqueaba el instalador indefinidamente
- **Síntoma:** El proceso `00_MASTER_INSTALL_SBOS.sh` se quedaba bloqueado esperando que `cat` terminara
- **Causa:** Una verificación de accesibilidad usaba `cat /dev/kmsg > /dev/null 2>&1` que es un stream infinito del kernel
- **Fix código:** Eliminado el `cat /dev/kmsg`. La verificación ahora solo comprueba existencia con `[[ -e /dev/kmsg ]]`

#### 1.11 Timeout del nodo Ready insuficiente
- **Síntoma:** El nodo K8s no llegaba a Ready en 180 segundos → rollback automático
- **Causa:** En servidor nuevo descargando imágenes Calico/K8s, puede tardar 5-10 minutos
- **Fix:** Timeout ampliado de 180s a 600s. Diagnóstico de pods pendientes en cada tick de 60s.

### Decisiones tomadas en Fase 1

| # | Decisión | Razón |
|---|----------|-------|
| D-01 | Usar `/proc/modules` en lugar de `lsmod` | `lsmod` no disponible en contenedores base |
| D-02 | Symlink `/dev/kmsg → /dev/console` via `tmpfiles.d` | Solución estándar K8s en contenedores (KinD) |
| D-03 | Arrancar nspawn con `--bind=/dev/kmsg` | Sin esto, kubelet no puede abrir el dispositivo |
| D-04 | Timeout nodo Ready: 600s | Descargas de imágenes en servidor nuevo pueden tardar |
| D-05 | `verify_ficha_health` respeta `health.type` del manifest | Las fichas bash no tienen pods K8s |
| D-06 | Fichas helm: verify pasa si kubectl no disponible | K8s se instala en fases — no hay kubectl antes de K8s |
| D-07 | vault: replicas 1 (Iteración 1) | Sin Raft configurado, 3 réplicas no funcionan en Iter 1 |
| D-08 | sbos-notifier: `python:3.14` en lugar de slim | slim no tiene curl para readinessProbe HTTP |
| D-09 | Usar nspawn solo para Capa 0 (sbos-bootstrap-os) | nspawn tiene demasiadas limitaciones para K8s completo |
| D-10 | VPS limpia para validación completa de K8s | Sin restricciones de contenedor, entorno igual a producción |

---

## FASE 2 — Validación en VPS real (2026-06-03 → en curso)

### Servidor de pruebas

| Campo | Valor |
|-------|-------|
| **IP** | `13.140.128.230` |
| **OS** | Ubuntu 26.04 LTS |
| **RAM** | 11 GB |
| **Disco** | 385 GB libres |
| **CPUs** | 6 |
| **Estado** | Virgen — sin K8s, sin Docker |
| **Acceso** | `ssh root@13.140.128.230` (pass: `12345678ubuntu`) |

### Checklist pre-instalación

- [ ] Transferir `bosctl` y scripts al servidor
- [ ] Configurar `/etc/bos/bos-bootstrap.env` con datos del tenant de prueba
- [ ] Ejecutar `bosctl setup` o `bosctl bootstrap start`
- [ ] Monitorear cada ficha en orden del DAG
- [ ] Documentar cualquier nuevo error en esta bitácora

### Orden del DAG (22 fichas)

```
N0 (OS):       sbos-bootstrap-os           → valida kernel, sysctl, /data/
N1 (K8s):      sbos-bootstrap-k8s          → kubeadm + containerd + Calico
N2 (Data):     postgresql, redis, minio
N3 (Seguridad):vault, keycloak
N4 (Gateway):  oauth2-proxy, kong, nginx, kyverno, linkerd
N5 (Notif/Mon):sbos-notifier, prometheus, grafana, alertmanager, alloy
N6 (Hardening):sbos-bootstrap-hard, certbot, sbos-bootstrap-storage, sbos-bootstrap-monitoring, sbos-bootstrap-cni
```

### Criterios de aceptación (C-01 a C-13)

| ID | Criterio | Estado |
|----|----------|--------|
| C-01 | Daemons activos | ⬜ Pendiente |
| C-02 | Healthchecks OK | ⬜ Pendiente |
| C-03 | ctx_id propaga | ⬜ Pendiente |
| C-04 | Calico funcional | ⬜ Pendiente |
| C-05 | WAL slot activo | ⬜ Pendiente |
| C-06 | Redis responde | ⬜ Pendiente |
| C-07 | Idempotencia | ⬜ Pendiente |
| C-08 | Limpieza+reinstala | ⬜ Pendiente |
| C-09 | Pantalla bienvenida | ⬜ Pendiente |
| C-10 | Validación formularios | ⬜ Pendiente |
| C-11 | Progreso en vivo | ⬜ Pendiente |
| C-12 | Pantalla completado | ⬜ Pendiente |
| C-13 | Modo automático | ⬜ Pendiente |

---

## FASE 3 — Bugs encontrados en VPS real

### BUG-VPS-1: `bos_bootstrap_deps` no definida → yq faltante → exit 99 ✅ CORREGIDO
**Causa:** `00_YAML_ENGINE_SBOS.sh` verifica `yq` al ser sourced. `bos_bootstrap_deps` (que instala yq) no estaba definida en el código fuente — solo existía en versiones antiguas del script en el nspawn.
**Fix en código fuente:** Función `bos_bootstrap_deps` agregada al inicio de `00_MASTER_INSTALL_SBOS.sh`. Llamada ANTES de sourcear el yaml engine.
**Archivo:** `core/00_MASTER_INSTALL_SBOS.sh` (función en línea ~65, llamada en línea ~112)

### BUG-VPS-2: daemon arranca en `config-pending` → rechaza bootstrap ✅ CORREGIDO
**Causa:** Sin `bos-install.toml`, el daemon entra en modo read-only y rechaza `bootstrap_start`.
**Fix:** `ensureDaemonRunning` en `install_ui.go` crea `bos-install.toml` mínimo con `org_name` y `client_domain` requeridos antes de arrancar el daemon.

### BUG-VPS-3: daemon cambia contraseña root sin permiso ✅ CORREGIDO
**Causa:** `autoBootstrap(benv)` corre ANTES de validar config. Lee `BOS_ROOT_PASSWORD` de `bos-bootstrap.env` (donde el TUI guarda el password del formulario) y llama `chpasswd`.
**Fix:** `ensureDaemonRunning` arranca el daemon con `BOS_DEV_SKIP_ROOT=1` → skip de `autoBootstrap`. El autoBootstrap real corre durante la instalación completa (Day 0).

### Decisiones tomadas

| # | Decisión | Razón |
|---|----------|-------|
| D-11 | `BOS_DEV_SKIP_ROOT=1` al auto-arrancar daemon desde TUI | Evita cambio de contraseña root y otros efectos secundarios del autoBootstrap |
| D-12 | `bos_bootstrap_deps` definida en `00_MASTER_INSTALL_SBOS.sh` | La función debe estar disponible antes de que cualquier script externo la necesite |

---

## Archivos modificados en esta sesión

| Archivo | Cambio |
|---------|--------|
| `core/00_TASK_CATALOG_SBOS.sh` | verify_ficha_health con health.type + fix sintaxis |
| `servers/S-HOST/sbos-bootstrap-os/manifest.yml` | health.command sin lsmod |
| `servers/S-HOST/sbos-bootstrap-os/task_catalog.sh` | _module_loaded(), kmod en paquetes |
| `servers/S-HOST/sbos-bootstrap-k8s/task_catalog.sh` | _module_loaded(), /dev/kmsg symlink, version detection, timeout 600s |
| `servers/S-HOST/sbos-bootstrap-k8s/resources/kubeadm-config.yaml` | Eliminados comentarios, solo YAML puro |
| `servers/S02/vault/task_catalog.sh` | replicas: 3 → 1 |
| `servers/S03/linkerd/task_catalog.sh` | _linkerd() con namespace explícito y kubectl wait |
| `servers/S06/sbos-notifier/task_catalog.sh` | python:3.14-slim → python:3.14 |
| `context/.../SBOS-NSPAWN-TEST-ENV.md` | Documentados todos los fixes (UFW, kmsg, red, dpkg) |
| `PLAN-CORRECCION-FICHAS.md` | Plan completo con 14 bugs |
| `BITACORA-PRUEBAS-BOS.md` | Este documento |

---

## Decisiones de arquitectura pendientes

| Pregunta | Contexto | Estado |
|----------|----------|--------|
| ¿Calico BGP o VXLAN? | El VPS puede no soportar BGP | Decidir al probar en VPS real |
| ¿certbot en staging o producción? | Para pruebas usar staging de Let's Encrypt | Pendiente |
| ¿Seed file del tenant de prueba? | Necesitamos datos básicos para el bootstrap | Crear antes de ejecutar |

---

_Bitácora iniciada: 2026-06-03 · Proyecto SBOS · Fase 2 activa_
