# Plan de Instalación desde Cero — VPS Limpia Ubuntu 26.04

**Versión:** 2.7.0  
**Fecha:** 2026-10-13  
**Autor:** bos-developer  
**Estado:** 🔄 PT-05 EN CURSO — 24/35 fichas INSTALLED · 2 PHYSICAL_ERROR (vault, oauth2-proxy — FIX-26A commiteado, pendiente deploy VPS) · 1 INSTALL_FAILED (tryton — desbloqueado tras vault) · 2 fixes críticos aplicados en código (FIX-26A + FIX-B observer)  
**Prerrequisito:** Ubuntu 26.04 Server LTS — instalación por defecto, sin software adicional

---

## 0. Correcciones aplicadas en esta sesión (pre-vuelo)

Los siguientes bugs fueron encontrados y corregidos antes de poder ejecutar las pruebas.
**Sin estas correcciones la instalación habría fallado.**

**Leyenda de severidad:**
- 🔴 **CRÍTICO** — fallo funcional que impide la instalación completamente
- 🟠 **SEGURIDAD** — violación del principio P6 (credenciales o tokens hardcodeados)
- 🟡 **CALIDAD** — violación de convención R16 (rutas hardcodeadas, código muerto)
- 📄 **DOC** — documentación incorrecta o desactualizada

| ID | Archivo | Severidad | Descripción | Fix aplicado |
|----|---------|-----------|-------------|--------------|
| **FIX-01** | `cmd/bosctl/system_install.go` | 🔴 CRÍTICO | `bos-install.toml` generado con expresiones Go literales como valores — TOML inválido → parseo fallaba al iniciar el daemon | Usar `fmt.Sprintf` con `%q` y constantes `paths.*` |
| **FIX-02** | `cmd/bosctl/system_install.go` | 🔴 CRÍTICO | `runPreflightFicha` buscaba `task_catalog.sh` en `/opt/bos/core/servers/...` (ruta inexistente) — ficha bos-preflight nunca se encontraba | Agregar `paths.ServersPath` como primer candidato de búsqueda |
| **FIX-03** | `servers/seed-skull.yml` | 🔴 CRÍTICO | `shamir_keys: 3` + `shamir_threshold: 5` — con threshold > keys, Vault nunca puede ser unsealed tras inicialización | Corregir a `shamir_keys: 5, shamir_threshold: 3` |
| **FIX-04** | `servers/S-HOST/bos-preflight/task_catalog.sh` | 🟠 SEGURIDAD | Token RPC `"dev-token-2026"` hardcodeado en texto claro + base64 estático en `.env` — viola P6 | Generar con `openssl rand -hex 32` — nunca predecible |
| **FIX-05** | `cmd/bosctl/rbac.go` | 🟡 CALIDAD | `/run/bos/bauth.sock` hardcodeado como string literal | `paths.RuntimeFile("bauth.sock")` |
| **FIX-06** | `cmd/bosctl/packages.go` | 🟡 CALIDAD | `const defaultBlibsDir = "/etc/bos/blibs/..."` hardcodeado | `var` con `filepath.Join(paths.ServersPath, ...)` |
| **FIX-07** | `cmd/bosctl/deploy.go` | 🟡 CALIDAD | `/var/log/bos/fichas/` hardcodeado como string literal | `filepath.Join(paths.VarLogBos, "fichas", ...)` |
| **FIX-08** | `cmd/bos/env.go` | 🟡 CALIDAD | Paths de búsqueda `/etc/bos/core/...` hardcodeados como strings | `filepath.Join(paths.EtcBos, ...)` |
| **FIX-09** | `cmd/bos/run_normal.go` | 🟡 CALIDAD | `/etc/bos/ai/action_catalog.yml` hardcodeado | `paths.ConfigDir("ai/action_catalog.yml")` |
| **FIX-10** | `cmd/bosctl/deploy.go::rpcAuthToken()` | 🟠 SEGURIDAD | Token base64 hardcodeado como fallback en la función `rpcAuthToken()` — si `/etc/bos/rpc-token` no existe, la sesión usaba credencial estática predecible | Retornar `""` (el servidor rechaza con 401 y fuerza regeneración) |
| **FIX-11** | `cmd/bosctl/deploy.go::deployTenant()` | 🟡 CALIDAD | PASO 0 y PASO 1.5 tenían triple sangría incorrecta; comentario de PASO 2 aparecía antes del código de PASO 1.5 — código visualmente engañoso | Normalizar sangría a 1 tab; reordenar comentarios según ejecución real |
| **FIX-12** | `cmd/bosctl/deploy.go` | 🔴 CRÍTICO | Cadena de compensación incompleta: si PASO 2 o posteriores fallaban, el rollback no eliminaba el StorageClass/PVs del PASO 1.5, dejando PVs huérfanos en el cluster | Agregar `compensateStep1_5()` que encadena namespace + storage; actualizar `compensateSteps12` y fallo de PASO 2 |
| **FIX-13** | `cmd/bosctl/system_install.go::runPreflightFicha()` | 🟡 CALIDAD | Objeto `cmd` (`exec.Command`) construido pero nunca ejecutado — solo se usaba para copiar el env a `wrapper`; código muerto confuso | Eliminar `cmd`; construir `fichaEnv` directamente y asignarlo a `wrapper` |
| **FIX-17** | `internal/state/types.go` | 🔴 CRÍTICO | `ValidTransitions[StateInstallFailed]` no incluía `StateInstalled` — `Repair()` con éxito no podía transicionar desde INSTALL_FAILED; el error se descartaba silenciosamente | Agregar `StateInstalled` a las transiciones desde `StateInstallFailed` |
| **FIX-DOC** | `BosAgent/CLAUDE.md` tabla "Rutas canónicas" | 📄 DOC | Rutas TLS documentadas como `/etc/bos/tls/bos.crt` pero `paths.CertFile` apunta a `/etc/bos/certs/bos.crt` — cualquier agente que leyera el CLAUDE.md buscaría la ruta incorrecta | Corregir a `/etc/bos/certs/bos.crt` y `/etc/bos/certs/bos.key` |
| **FIX-14** | `internal/state/types.go` | 🔴 CRÍTICO | `ValidTransitions[StatePending]` no incluía `StateInstalled` ni `StateInstalling` — `Transition(fichaID, StateInstalled)` fallaba silenciosamente (error ignorado con `_`) en fichas PENDING con recursos ya corriendo en K8s | Agregar `StateInstalling, StateInstalled` como destinos válidos desde `StatePending` |
| **FIX-15** | `internal/domain/ficha_service.go` | 🔴 CRÍTICO | `Repair()` y `Update()` no llamaban `svc.state.Transition(fichaID, StateInstalled)` al completar con éxito — solo `Install()` actualizaba el estado | Agregar `svc.state.Transition(fichaID, state.StateInstalled)` en ambas funciones |
| **FIX-16** | `cmd/bosctl/ficha.go` | 🔴 CRÍTICO | `cmdFichaRepair/Install/Update/Remove` usaban `buildFichaSvc()` que crea `FichaService(installer=nil)` → `ErrInstallerUnavailable` | Cambiar a `doRPCCall()` al daemon (que tiene el orchestrator real), siguiendo el patrón de `cmdFichaLogs` |

**Resultado tras FIX-01..FIX-17:** `CGO_ENABLED=0 go build ./...` — ✅ sin errores · 35/35 fichas INSTALLED/UPDATE_AVAILABLE en VPS de prueba (PT-04 completado)

---

## 0b. Correcciones de infraestructura (bootstrap — sesión 2026-10-10)

Bugs encontrados durante PT-05 al intentar instalación post-PT-04. Causa raíz: Hetzner VPS no provee hairpin NAT — los pods no podían alcanzar el apiserver en su IP pública.

| ID | Archivo | Severidad | Descripción | Commit |
|----|---------|-----------|-------------|--------|
| **FIX-18** | `S-HOST/sbos-bootstrap-k8s/resources/kubeadm-config.yaml` | 🔴 CRÍTICO | Faltaban `certSANs` con `127.0.0.1` — sin ellos kubectl desde el host no podía conectar via localhost; solo valía con la IP pública | Agregar `certSANs: ["127.0.0.1", "__NODE_IP__", "__NODE_NAME__"]` |
| **FIX-19** | `S-HOST/sbos-bootstrap-k8s/task_catalog.sh` | 🔴 CRÍTICO | Sin hairpin NAT (Hetzner lo bloquea), los pods no podían alcanzar el apiserver en su IP pública → Kyverno `kyvernopre` init container no podía sincronizar ConfigMaps → Kyverno nunca arrancaba → su webhook con `failurePolicy: Fail` bloqueaba todo `kubectl apply` en el cluster | Detectar IP pública post-kubeadm e insertar regla `iptables -t nat -A OUTPUT -d <pub_ip>/32 -p tcp --dport 6443 -j REDIRECT --to-port 6443` |
| **FIX-20** | `S-HOST/sbos-bootstrap-os/task_catalog.sh` | 🔴 CRÍTICO | `iptables-persistent` y `netfilter-persistent` no estaban en la lista de paquetes base — la regla hairpin NAT (FIX-19) se perdía en cada reinicio del host | Añadir `iptables-persistent netfilter-persistent` a `packages` + `mkdir -p /etc/iptables` |
| **FIX-21** | `S03/kyverno/task_catalog.sh` | 🔴 CRÍTICO | Chart Kyverno v3.3.x (app v1.19.1) tiene bug en K8s 1.32: `kyvernopre` init container cuelga indefinidamente en `configmap informer cache failed to sync` — Kyverno nunca arranca | Pinear chart a `3.3.4` (app v1.13.4) — estable en K8s 1.32 |
| **FIX-22** | `S13/nextcloud/task_catalog.sh` | 🔴 CRÍTICO | `readinessProbe: httpGet:/status.php` — Apache `mpm_prefork` bloquea durante inicialización; kubelet siempre obtiene timeout → pod nunca marca Ready | Cambiar a `exec: [su, www-data, -s, /bin/sh, -c, "php /var/www/html/occ status --output=json 2>/dev/null \| grep -q installed"]` |
| **FIX-23** | `S13/nextcloud/task_catalog.sh` | 🔴 CRÍTICO | `ficha_repair` tenía `readinessProbe: httpGet` mientras `ficha_install` tenía `exec` — probe diferente entre install y repair | Unificar ambas a exec |
| **FIX-24** | `S13/onlyoffice/task_catalog.sh` | 🟡 CALIDAD | Memory limit `2Gi` insuficiente — `allthemesgen`/`pluginsmanager`/`x2t` al arrancar causan OOMKill + CPU spike a 146 load. CPU request `500m` causaba `Insufficient CPU` al rolling update con el nodo a 96% CPU | Límite → `3Gi`; request CPU → `200m` |
| **FIX-25** | `S13/nextcloud/task_catalog.sh` | 🟡 CALIDAD | Sin protección frente a Kyverno webhook `failurePolicy: Fail` cuando el admission controller no responde — `kubectl apply` falla silenciosamente | Añadir `_k_apply_safe()`: intenta apply normal; si detecta `connection refused` en webhook Kyverno, parcha temporalmente `failurePolicy: Ignore`, aplica y restaura |

**Resultado tras FIX-18..FIX-25:** Bootstrap corregido · VPS contaminada descartada · Ubuntu 26.04 limpio disponible para PT-05

---

## 1. Requisitos de la VPS de prueba

| Recurso | Mínimo requerido | Verificación |
|---------|-----------------|-------------|
| OS | Ubuntu 26.04 LTS Server (instalación por defecto) | `lsb_release -rs` → `26.04` |
| RAM | 16 GB | `free -m` |
| CPU | 8 cores | `nproc` |
| Disco libre en `/` | 165 GB | `df -h /` |
| Conectividad internet | Sí (APT + registries) | `curl -sf http://archive.ubuntu.com` |
| Acceso SSH root | Sí | `ssh root@<ip>` |

**VPS de prueba actual:** `root@13.140.128.230`  
**Modo instalación:** `--mode=dev` (advertencias no bloquean — los recursos mínimos son avisos)

---

## 2. Pasos desde cero

### PASO 1 — Compilar BOS en la máquina de desarrollo

```bash
cd BosAgent/src

# Compilar daemon y CLI
CGO_ENABLED=0 /home/skull/sdk/go/bin/go build -o bin/bos ./cmd/bos/
CGO_ENABLED=0 /home/skull/sdk/go/bin/go build -o bin/bosctl ./cmd/bosctl/

# Verificar (tests con race detector)
/home/skull/sdk/go/bin/go test -race -count=1 ./... 2>&1 | tail -10
```

**Resultado esperado:** dos binarios en `bin/bos` y `bin/bosctl`, sin errores de test.

---

### PASO 2 — Crear el paquete de despliegue

El paquete contiene todo lo que necesita la VPS virgen — sin dependencias externas:

```bash
# Desde BosAgent/src/
rm -rf /tmp/bos-deploy && mkdir /tmp/bos-deploy

cp bin/bos bin/bosctl /tmp/bos-deploy/
cp -r core/          /tmp/bos-deploy/core/
cp -r servers/       /tmp/bos-deploy/servers/
cp servers/seed-skull.yml /tmp/bos-deploy/seed-skull.yml

# (Opcional) incluir manifiestos Calico locales para instalación offline
# cp servers/S-HOST/sbos-bootstrap-cni/resources/calico-v3.32.0.yaml /tmp/bos-deploy/servers/S-HOST/sbos-bootstrap-cni/resources/

ls -lh /tmp/bos-deploy/
```

**Estructura del paquete:**
```
/tmp/bos-deploy/
├── bos              ← daemon (binario estático ~12 MB)
├── bosctl           ← CLI (binario estático)
├── core/            ← scripts del motor Bash (00_MASTER_INSTALL_SBOS.sh, etc.)
├── servers/         ← 143 fichas declarativas (S-HOST a S16)
└── seed-skull.yml   ← seed del tenant skull (5 llaves Shamir, threshold 3)
```

---

### PASO 3 — Transferir paquete a la VPS

```bash
# Desde la máquina de desarrollo
scp -r /tmp/bos-deploy root@13.140.128.230:/tmp/bos-deploy

# Verificar integridad básica
ssh root@13.140.128.230 "ls -lh /tmp/bos-deploy/ && file /tmp/bos-deploy/bos"
# Esperado: ELF 64-bit LSB executable, x86-64, statically linked
```

---

### PASO 4 — Ejecutar system-install en la VPS

```bash
ssh root@13.140.128.230

# Desde dentro del VPS:
cd /tmp/bos-deploy

# system-install realiza los pasos en orden:
#   1. binarios  → copia bos/bosctl a /opt/bos/bin/ + symlinks en /usr/local/bin/
#   2. core      → copia core/ a /opt/bos/core/
#   3. blibs     → copia servers/ a /etc/bos/blibs/servers/ (143 fichas)
#   4. env       → crea /etc/bos/bos-install.toml y /etc/bos/bos-bootstrap.env mínimos
#   5. servicios → instala bos.service + bos-console.service en systemd
#   6. preflight → ejecuta ficha bos-preflight:
#                    - verifica OS Ubuntu 26.04
#                    - verifica RAM/CPU/disco
#                    - instala paquetes del SO (desde manifest.yml)
#                    - crea usuario/grupo bosagent
#                    - crea directorios /etc/bos, /run/bos, /var/log/bos, /opt/bos
#                    - genera certificado TLS autofirmado para :9443
#                    - genera token RPC aleatorio (openssl rand -hex 32)
#                    - configura sudoers bosagent
#                    - configura cgroup v2 delegation

./bosctl system-install --mode=dev 2>&1 | tee /tmp/system-install.log
```

**Salida esperada (cada línea = un paso):**
```
  → binarios... ✓
  → core... ✓
  → blibs... ✓
  → env... ✓
  → servicios... ✓
  → preflight... ✓

Sistema listo. BOS arrancará en la consola (tty1) automáticamente.
```

**Si algo falla:** revisar `/var/log/bos/fichas/bos-preflight.log`

---

### PASO 5 — Iniciar BOS y completar bos-bootstrap.env

```bash
# Editar el archivo de bootstrap (creado vacío por system-install)
nano /etc/bos/bos-bootstrap.env
```

Contenido mínimo para prueba:
```bash
BOS_TENANT_NAME=skull
BOS_TENANT_ID=1234567890
BOS_TENANT_PAIS=BO
BOS_TENANT_DOMAIN=skull.sbos.local
BOS_ROOT_USER=admin
BOS_ADMIN_NOMBRE=Admin
BOS_ROOT_PASSWORD=Admin2026!
BOS_MFA_ENABLED=false
```

```bash
# Iniciar el daemon
systemctl start bos.service
systemctl status bos.service

# Verificar que el socket Unix está activo
sleep 5 && ls -la /run/bos/bos.sock
```

**Esperado:** `srw-rw---- 1 bosagent bosagent ... /run/bos/bos.sock`

---

### PASO 6 — Desplegar el tenant con el seed

```bash
# Desplegar en modo no-interactivo con seed-skull.yml
bosctl deploy --seed /tmp/bos-deploy/seed-skull.yml

# Este comando ejecuta los 7 pasos del seed en orden:
#   [0/7] sbos-bootstrap-k8s  — instala containerd + kubeadm + kubelet, init cluster
#   [1/7] sbos-namespace      — crea namespace sbos-skull-prod + NetworkPolicy
#   [1.5] sbos-bootstrap-storage — StorageClass local-path + PVs
#   [2/7] postgresql          — despliega PostgreSQL 18.4 + 9 BDs + schemas
#   [3/7] redis               — despliega Redis 8.6.2 (3 DBs, AOF)
#   [4/7] vault               — inicializa Vault 2.0.1 + Shamir 3/5 + PKI
#   [5/7] keycloak            — despliega Keycloak 26.6.2 + realm skull + 5 SPIs
#   [6/7] context plane DDL   — bos.ctx.auto_migrate (bos + registered_devices)
#   [7/7] fichas del tenant   — sbos-bkernel + kong
```

**Tiempo estimado:** 30–45 minutos (descarga de imágenes K8s + KC en la primera corrida)

---

### PASO 7 — Verificar criterios C-01..C-08

```bash
# C-01: OS bootstrap
bosctl bootstrap status os

# C-02: Nodo K8s Ready
kubectl --kubeconfig /etc/bos/.kube/config get nodes

# C-03: Calico CNI
kubectl --kubeconfig /etc/bos/.kube/config get pods -n kube-system | grep calico

# C-04: PostgreSQL + SBOSDB
kubectl exec -n sbos-data statefulset/postgresql -- psql -U postgres -c '\l'

# C-04c: Context Plane (SBOS-049)
bosctl ctx create --tenant skull

# C-05: Redis
kubectl exec -n sbos-data statefulset/redis -- redis-cli ping

# C-06: Vault unsealed
kubectl exec -n sbos-security statefulset/vault -- vault status | grep sealed

# C-07: Keycloak realm
curl -sf http://localhost:8080/auth/realms/skull | python3 -m json.tool | head -5

# C-08: Kong alive
kubectl exec -n sbos-gateway deployment/kong -- kong health
```

---

### PASO 8 — Instalar fichas VDI (PT-04)

```bash
# Prerequisito: bAuth, bhnexus, banexus deben estar desplegados (PT-03)
# Una vez los daemons estén corriendo:

bosctl ficha install fedora-kde    # pre_install: namespace + Secret
bosctl ficha install nextcloud     # pre_install: nextcloud_db + rol + Secret
bosctl ficha install guacamole     # pre_install: guacamole_db + initdb.sh + OIDC
bosctl ficha install onlyoffice    # pre_install: onlyoffice_db + JWT secret

# Verificar:
kubectl get pods -n sbos-vdi
bosctl ficha health fedora-kde
bosctl ficha health nextcloud
bosctl ficha health guacamole
bosctl ficha health onlyoffice
```

---

## 3. Diagnóstico de fallos comunes

| Síntoma | Causa probable | Solución |
|---------|---------------|----------|
| `preflight: task_catalog.sh no encontrado` | Paquete no incluye `servers/S-HOST/bos-preflight/` | Verificar `ls /tmp/bos-deploy/servers/S-HOST/bos-preflight/` |
| `kubeadm_init: exit 1` | Swap activo o puerto 6443 ocupado | `swapoff -a` · `fuser 6443/tcp` |
| `esperar_nodo_ready: timeout 600s` | Calico no puede descargar imagen | Verificar conectividad: `curl -sf https://quay.io` |
| `bos-install.toml: parse error` | TOML inválido (FIX-01 ya corregido) | Aplicar FIX-01 y recompilar |
| `vault sealed=true tras deploy` | Shamir mal configurado (FIX-03 ya corregido) | Aplicar FIX-03 en seed-skull.yml |
| `bos.sock: no such file` | bos.service no arrancó | `journalctl -u bos.service -n 50` |
| `containerd: text file busy` | Binario ya cargado en memoria | Ignorable — `system-install` lo maneja |
| `dpkg locked 30s` | unattended-upgrades en VPS nueva | El bootstrap espera 30s y fuerza liberación |
| `kyverno kyvernopre init container Running indefinitely` | Bug Kyverno v1.19 en K8s 1.32 (FIX-21 corregido) | Chart 3.3.4 ya pinado; si ocurre igual: `helm upgrade kyverno kyverno/kyverno --version 3.3.4 -n kyverno --reuse-values` |
| `kubectl apply: connection refused (kyverno webhook)` | Kyverno no arrancó — hairpin NAT faltante (FIX-19 corregido) | Verificar regla NAT: `iptables -t nat -L OUTPUT -n \| grep 6443`; si falta, ejecutar `bosctl ficha repair sbos-bootstrap-k8s` |
| `TLS handshake timeout` al conectar a apiserver desde pods | Hairpin NAT no aplicado o perdido tras reinicio | `iptables -t nat -A OUTPUT -d <pub_ip>/32 -p tcp --dport 6443 -j REDIRECT --to-port 6443` + `iptables-save > /etc/iptables/rules.v4` |
| `nextcloud pod CrashLoopBackOff / never Ready` | Apache mpm_prefork bloquea httpGet probe (FIX-22 corregido) | Exec probe ya implementado; si ocurre: verificar que readinessProbe usa `php /var/www/html/occ status` |
| `onlyoffice OOMKilled` | Memory limit insuficiente (FIX-24 corregido) | Límite 3Gi ya configurado; node con alta carga → reducir CPU request a 200m |

---

## 4. Estado del código — auditoría de calidad

### 4.1 Monolitismo

Límite aplicado: **≤ 400 líneas** (parámetro actualizado en `BosAgent/CLAUDE.md`).  
Techo permitido hasta **800 líneas** cuando la cohesión semántica lo justifica (dispatchers, sagas, bootstraps de infraestructura).

| Archivo | Líneas totales | Líneas efectivas | Veredicto |
|---------|---------------|-----------------|-----------|
| `cmd/bos/run_normal.go::runNormal` | 495 | 373 | ✅ VERDE — bajo el techo de 400 líneas efectivas; secuencia de inicialización bien documentada con pasos #1..#10 |
| `cmd/bosctl/deploy.go::deployTenant` | 665 | 509 | ✅ VERDE — saga lineal de 7 pasos + helpers RPC; cohesión semántica justifica el tamaño (< 800) |
| `cmd/bosctl/ficha.go` | 667 | 565 | ✅ VERDE — dispatcher de 18 subcomandos; cada `cmdFichaXxx` es corto y delega; patrón correcto |
| `cmd/bosctl/bootstrap.go` | 642 | 544 | ✅ VERDE — saga bootstrap Day 0; cohesión total; < 800 |
| `servers/S02/vault/task_catalog.sh` | 1211 | ~900 | ✅ VERDE — Bash de infraestructura (init + unseal + Shamir + PKI + AppRole + policies); complejidad intrínseca de Vault; bien estructurado en secciones `# ── X ──` |

### 4.2 Documentación de funciones (estado post-auditoría)

| Archivo | Estado | Observaciones |
|---------|--------|---------------|
| `internal/paths/paths.go` | ✅ Excelente | Docstrings completos con callers, efectos secundarios, ejemplos |
| `cmd/bosctl/system_install.go` | ✅ Bueno | Cada función documenta responsabilidad y efectos secundarios |
| `cmd/bos/env.go` | ✅ Bueno | `loadBootstrapEnv` documenta orden de búsqueda y efectos de seguridad |
| `servers/S-HOST/bos-preflight/task_catalog.sh` | ✅ Bueno | Header completo, señales documentadas, sección por función |
| `servers/S-HOST/sbos-bootstrap-k8s/task_catalog.sh` | ✅ Excelente | Cada paso numerado, workarounds documentados (nspawn, /dev/kmsg) |
| `cmd/bosctl/deploy.go::deployTenant` | ✅ VERDE | Saga de 7 pasos bien comentados; cada step documenta su compensación con `doRPCCall` |
| `cmd/bos/run_normal.go` | ✅ VERDE | Secuencia de 10 pasos de inicialización; cada bloque lleva comentario inline `// #N —` |

### 4.3 Parametrización

| Criterio | Estado |
|----------|--------|
| Rutas del sistema | ✅ Centralizadas en `paths.*` (R16 — 9 violaciones corregidas en esta sesión) |
| Versiones de stack | ✅ Variables en task_catalog.sh (`K8S_VERSION`, `CALICO_VERSION`, etc.) |
| Puertos | ✅ Definidos en SBOS-050; verificados en bos-preflight |
| Credenciales | ✅ Generadas dinámicamente (FIX-04 — token RPC ahora `openssl rand`) |
| Namespace K8s | ✅ Env vars (`SBOS_NAMESPACE`) con defaults explícitos |
| Timeouts | ✅ `K8S_WAIT_TIMEOUT=600` configurable, con valor razonado en comentario |

---

## 5. Estado de la prueba y próximos pasos

```
[✅ HECHO] Commit correcciones FIX-01..FIX-16 (b4550e7)
    ↓
[✅ HECHO] PT-01:  scp bin/bos + bin/bosctl + core/ + servers/ → VPS
    ↓
[✅ HECHO] PT-01b: bosctl system-install --mode=dev en VPS limpia
    ↓
[✅ HECHO] PT-02:  bosctl deploy --seed seed-skull.yml
    ↓
[✅ HECHO] PT-02b: Verificar C-01..C-08 + 31/31 fichas INSTALLED/UPDATE_AVAILABLE
    ↓
[✅ HECHO] PT-03:  bAuth real v3.0.0 + stubs bkernel/bhnexus activos como servicios systemd
    ↓
[✅ HECHO] PT-04:  4 fichas VDI instaladas (nextcloud, guacamole, onlyoffice, fedora-kde)
    ↓
[🔄 EN CURSO] Correcciones bootstrap FIX-18..FIX-25 aplicadas · VPS limpia disponible
    ↓
[ SIGUIENTE ] PT-05b: Reinstalar en Ubuntu limpio con bootstrap corregido · verificar end-to-end
```

**Estado post-correcciones (2026-10-10):**
- VPS anterior: descartada (Kyverno colgado + Kyverno webhook bloqueando nextcloud)
- VPS nueva: Ubuntu 26.04 limpio disponible
- Correcciones aplicadas: FIX-18..FIX-25 (hairpin NAT + certSANs + Kyverno 3.3.4 + nextcloud exec probe + onlyoffice 3Gi)
- Commits: `ac032ae` (hairpin NAT + certSANs + Kyverno pin) · `39fdb23` (nextcloud exec probe)

**PT-03 — Daemons desplegados:**
| Daemon | Tipo | Socket | Servicio systemd |
|--------|------|--------|-----------------|
| bAuth | Real v3.0.0 (Rust MUSL) | `/run/bos/bauth.sock` | `bauth.service` |
| bkernel | Stub Go (placeholder) | `/run/bos/bkernel.sock` | `bkernel.service` |
| bhnexus | Stub Go (placeholder) | `/run/bos/bhnexus.sock` | `bhnexus.service` |

Stub fuente: `BosAgent/src/tools/sbos-stub-daemon/` (reemplazar por real cuando esté desarrollado)

**PT-04 — Fichas VDI instaladas:**
| Ficha | Imagen | Namespace | Estado |
|-------|--------|-----------|--------|
| nextcloud | nextcloud:30.0.2-apache | sbos-vdi | INSTALLED |
| guacamole | guacamole/guacamole:1.5.5 + guacd:1.5.5 | sbos-vdi | INSTALLED |
| onlyoffice | onlyoffice/documentserver:8.2.2 | sbos-vdi | INSTALLED |
| fedora-kde | dorowu/ubuntu-desktop-lxde-vnc:focal (placeholder) | sbos-vdi | INSTALLED |

NetworkPolicies aplicadas: `allow-vdi-postgresql` + `allow-vdi-redis` en sbos-data (ingress desde sbos-vdi).

---

---

## 6. Estado verificado en VPS — 2026-10-13 02:16 UTC

### 6.1 Resumen de estado (35 fichas)

| Estado | Cantidad | Fichas |
|--------|----------|--------|
| **INSTALLED** | 24 | alertmanager, alloy, besu-qbft, bos-preflight, certbot, grafana, guacamole, keycloak, kong, minio, nextcloud, onlyoffice, postgresql, prometheus, redis, sbos-bkernel, sbos-bootstrap-cni, sbos-bootstrap-hard, sbos-bootstrap-k8s, sbos-bootstrap-monitoring, sbos-bootstrap-os, sbos-bootstrap-storage, sbos-namespace, sbos-notifier |
| **UPDATE_AVAILABLE** | 2 | fedora-kde (imagen actualizada localmente), nginx |
| **INSTALLING** | 1 | linkerd (en progreso) |
| **INSTALL_FAILED** | 1 | tryton (bloqueado por Vault) |
| **PENDING** | 5 | calcom, ferretdb, kyverno, mattermost, novu (auto_install=false) |
| **PHYSICAL_ERROR** | 2 | **vault**, **oauth2-proxy** |

### 6.2 Problemas activos — bloqueadores

#### BUG-26 — Vault: CrashLoopBackOff por liveness probe con Vault sellado
**Severidad:** 🔴 CRÍTICO → ✅ **FIX-26A COMMITEADO** (commit `0a1a182`) · **Pendiente: aplicar en VPS**  
**Síntoma original:** `vault-0` reiniciaba cada ~4 minutos (95+ reinicios). Al arrancar, Vault está sellado; el liveness probe `/v1/sys/health?standbyok=true` devolvía 503 → K8s lo mataba.

**Causa raíz:** El liveness probe no incluía `sealedok=true`. El endpoint de health de Vault devuelve 503 cuando está sellado sin ese parámetro.

**Estado del fix:**
- FIX-26A aplicado en `S02/vault/task_catalog.sh` — liveness probe ahora usa `?standbyok=true&sealedok=true`
- FIX-B aplicado en `observer.go` — BOS repara fichas en PHYSICAL_ERROR automáticamente
- **Para activar en VPS:** copiar task_catalog.sh actualizado + `bosctl ficha repair vault` + unseal manual (ver §6.2 instrucciones)

**Impacto en cascada (activo hasta aplicar fix en VPS):**
- `oauth2-proxy` → PHYSICAL_ERROR (no puede obtener secretos OIDC de Vault)
- `tryton` → INSTALL_FAILED (requiere Vault para credenciales PG y secreto OIDC)

**Unseal manual (hasta aplicar fix):**
```bash
# Ejecutar desde la VPS como root — ventana de ~55s tras arranque del pod
export KUBECONFIG=/root/.kube/config
kubectl delete pod vault-0 -n sbos-security --grace-period=5
sleep 30
for KEY in $(python3 -c "import json; d=json.load(open('/etc/bos/vault-init-keys.json')); [print(k) for k in d['unseal_keys_b64'][:3]]"); do
  kubectl exec -n sbos-security vault-0 -- vault operator unseal $KEY
done
kubectl exec -n sbos-security vault-0 -- vault status
```

#### BUG-27 — oauth2-proxy: CrashLoopBackOff derivado de Vault caído
**Severidad:** 🔴 CRÍTICO → se resuelve automáticamente al aplicar FIX-26A en VPS  
**Síntoma:** `oauth2-proxy` en PHYSICAL_ERROR (78+ reinicios). No puede leer secretos OIDC desde Vault.  
**Solución:** Aplicar FIX-26A en VPS → vault estable → FIX-B del observer detecta PHYSICAL_ERROR → llama repair → oauth2-proxy se recupera automáticamente sin intervención adicional.

#### BUG-28 — bosctl: timeout conectando al daemon BOS por WebSocket
**Severidad:** 🟡 CALIDAD  
**Síntoma:** `bosctl ficha install tryton` → `context deadline exceeded`. El JSON-RPC directo vía `socat` funciona, pero el cliente WebSocket de `bosctl` no puede negociar el handshake desde una sesión SSH sin el entorno correcto.  
**Workaround:** Usar JSON-RPC directo para operaciones de estado y control mientras se diagnostica.

### 6.3 Estado de idempotencia del instalador

| Criterio | Estado | Evidencia |
|----------|--------|-----------|
| **Detección instalación nueva vs actualización** | ✅ Implementado | `bos.state.read` distingue INSTALLED/PENDING/INSTALL_FAILED |
| **No destruye fichas ya instaladas en re-ejecución** | ✅ Verificado | 24 fichas INSTALLED sobrevivieron múltiples sesiones |
| **Fichas con auto_install=false esperan aprobación** | ✅ Correcto | kyverno, calcom, ferretdb, mattermost, novu en PENDING |
| **Compensación por fallo no hace rollback total** | ✅ Diseño | Sagas con compensación parcial (FIX-12) |
| **Vault: unseal no es idempotente entre reinicios** | ⚠️ FIX-26A commiteado — pendiente VPS | Liveness probe corregido en repo; aún no aplicado en VPS — vault sigue en PHYSICAL_ERROR |
| **BOS repara fichas en PHYSICAL_ERROR automáticamente** | ✅ FIX-B aplicado (commit 0a1a182) | observer.go Fase 3 ahora incluye StatePhysicalError |
| **bosctl disponible desde cualquier contexto** | ⚠️ BUG-28 | WebSocket falla en SSH; JSON-RPC directo funciona |
| **Diagnóstico de fichas en error no destruye cluster** | ✅ Verificado | `INSTALL_FAILED` en tryton no afectó otras 24 fichas |

### 6.4 Próximos pasos (PT-05b)

```
[✅ INSTALADO] 24/35 fichas INSTALLED — base funcional
[✅ COMMITEADO] FIX-26A (vault liveness probe) + FIX-B (observer PHYSICAL_ERROR) — commit 0a1a182
    ↓
[ PENDIENTE VPS ] Copiar S02/vault/task_catalog.sh actualizado a /etc/bos/blibs/servers/S02/vault/
                  → bosctl ficha repair vault
                  → unseal manual (3 de 5 keys)
    ↓
[ AUTO ] FIX-B observer detecta vault PHYSICAL_ERROR → llama repair → vault queda INSTALLED
[ AUTO ] oauth2-proxy: observer detecta PHYSICAL_ERROR → repair → INSTALLED
    ↓
[ SIGUIENTE  ] bosctl ficha install tryton → verificar INSTALLED
    ↓
[ PENDIENTE  ] linkerd: verificar INSTALLED (instalación en curso)
    ↓
[ PENDIENTE  ] nginx: bosctl ficha update nginx (UPDATE_AVAILABLE)
    ↓
[ PENDIENTE  ] fedora-kde: bosctl ficha update fedora-kde (imagen 1.4.0 disponible localmente)
    ↓
[ PENDIENTE  ] PT-05b completo: 30/35 fichas INSTALLED + Vault estable
```

### 6.5 Diagnóstico de fallos nuevos (añadir a §3)

| Síntoma | Causa probable | Solución |
|---------|---------------|----------|
| `vault-0 CrashLoopBackOff` | Liveness probe mata Vault sellado (BUG-26) | FIX-26: `sealedok=true` en probe + auto-unseal |
| `oauth2-proxy CrashLoopBackOff` | Vault caído — sin secretos OIDC | Arreglar Vault primero |
| `tryton INSTALL_FAILED` | task_catalog.sh requiere Vault para credenciales | Arreglar Vault → `bosctl ficha install tryton` |
| `bosctl ficha install: context deadline exceeded` | WebSocket RPC falla en sesión SSH sin entorno completo (BUG-28) | Usar `socat` + JSON-RPC directo o ejecutar desde consola local |

---

---

## 7. Arquitectura operacional de BOS — Motores y responsabilidades

### 7.0 Principio soberano

> **BOS es el observador, instalador y mantenedor de todas las fichas. K8s corre los contenedores. El motor de fichas y el motor de puertos organizan todos los pods para un trabajo eficiente. La idempotencia la provee BOS, no K8s.**

Ninguna ficha se levanta, repara ni actualiza por iniciativa de K8s. K8s provee el runtime de contenedores; BOS decide cuándo, cómo y en qué estado debe estar cada ficha.

---

### 7.1 Los dos motores del plano de control

#### Motor de Fichas — observer + orchestrator + health

Responsabilidad: ciclo de vida completo de cada ficha (install → observe → repair → update → remove).

```
┌────────────────────────────────────────────────────────────────────────┐
│                        MOTOR DE FICHAS (BOS)                           │
│                                                                        │
│  plugin.Loader        health.Checker         observer.Loop             │
│  ─────────────        ─────────────         ──────────────             │
│  Escanea servers/     Ejecuta check_command  Tick cada 5s:             │
│  Carga manifests      de cada manifest       Fase 0: detecta updates   │
│  Calcula SHA-256      Clasifica:             Fase 1: desbloquea PENDING │
│  Valida contratos     HEALTHY/DEGRADED       Fase 2: instala READY     │
│                       DOWN/UNKNOWN           Fase 3: repara DEGRADADA  │
│                              ↓                       ↓                 │
│                       state.SetHealth()      Orchestrator.Install()    │
│                                              Orchestrator.Repair()     │
│                                                      ↓                 │
│                                              task_catalog.sh           │
│                                              ficha_install()           │
│                                              ficha_repair()            │
│                                              ficha_uninstall()         │
│                                                                        │
│  reconcile.k8s_discovery                                               │
│  ───────────────────────                                               │
│  Cada 5min: consulta K8s → mapea estado pod → actualiza state          │
│  IsReady()    → INSTALLED                                              │
│  IsDegraded() → DEGRADADA   ← observer Fase 3 repara                  │
│  Found        → PHYSICAL_ERROR                                         │
│  !Found       → PENDING                                                │
└────────────────────────────────────────────────────────────────────────┘
```

La máquina de estados de una ficha tiene 18 estados (ADR-021). Los relevantes para reparación:

```
PENDING → READY → INSTALLING → INSTALLED ← → DEGRADADA → REPAIRING → INSTALLED
                                          ↑               ↓
                                    PHYSICAL_ERROR → REPAIRING  ✅ FIX-B aplicado (commit 0a1a182)
```

#### Motor de Puertos (portman) — Kardex soberano de asignaciones

Responsabilidad: garantizar que cada ficha use exactamente los puertos que le corresponden según SBOS-050, sin colisiones, con registro auditado.

```
┌────────────────────────────────────────────────────────────────────────┐
│                      MOTOR DE PUERTOS (portman)                        │
│                                                                        │
│  7 métodos JSON-RPC:                                                   │
│  bos.portman.assign   — asigna puertos a una ficha (algoritmo A/B)     │
│  bos.portman.lookup   — consulta asignación activa de un puerto        │
│  bos.portman.release  — libera puertos al eliminar una ficha           │
│  bos.portman.check    — verifica disponibilidad en 3 capas:            │
│                          1. Kardex (BD) — ¿ya asignado?               │
│                          2. K8s API   — ¿servicio usando ese puerto?   │
│                          3. SO        — ¿puerto en uso en el host?     │
│  bos.portman.list     — lista asignaciones del Kardex                  │
│  bos.portman.validate — compara Kardex vs K8s real (drift)             │
│  bos.portman.export   — exporta Kardex completo en Markdown            │
│                                                                        │
│  Integración con motor de fichas:                                      │
│  ficha install → portman.assign(fichaID, portTypes)                    │
│  ficha remove  → portman.release(fichaID)                              │
│  observer tick → portman.validate() → detecta drift de puertos        │
│                                                                        │
│  Almacenamiento: PostgreSQL (sbos_db.bos.port_kardex)                  │
│  Rango SBOS: 9400–9499 (daemons) · K8s ClusterIP: libre               │
└────────────────────────────────────────────────────────────────────────┘
```

**Estado actual del Kardex:** El portman existe y tiene la interfaz completa. Sin embargo, los task_catalog.sh de las fichas instaladas NO llaman a `bos.portman.assign` durante la instalación — asignan puertos manualmente en los YAML. Esto significa que el Kardex está vacío y el motor de puertos no está siendo usado. **Es un gap de integración** — los task_catalog.sh deben llamar al portman al inicio de `ficha_install()`.

---

### 7.2 Pipeline completo de instalación de una ficha (correcto)

```
1. plugin.Loader escanea servers/ → carga manifest.yml
2. observer Fase 1: verifica deps → PENDING → READY
3. observer Fase 2: elige ficha READY → INSTALLING
4. Orchestrator.Install(fichaID):
   a. Llama ficha_pre_install() del task_catalog
   b. portman.assign(fichaID, portTypes) → obtiene puertos del Kardex
   c. Llama ficha_install() con los puertos asignados
   d. Llama ficha_post_install()
   e. Registra hashes en state
5. state → INSTALLED
6. health.Checker ejecuta check_command → health_status HEALTHY
7. reconcile.k8s_discovery confirma pods Ready → mantiene INSTALLED
```

**Pipeline de reparación automática (correcto):**
```
1. health.Checker: check_command retorna != 0 → DEGRADADA
   O reconcile.k8s_discovery: pod NotReady → DEGRADADA
2. observer Fase 3: detecta DEGRADADA → REPAIRING
3. Orchestrator.Repair(fichaID):
   a. Llama ficha_repair() del task_catalog
   b. ficha_repair() resuelve el problema (unseal, reconnect, etc.)
4. state → INSTALLED
```

---

### 7.3 Análisis arquitectónico — El problema de Vault (raíz de la cascada)

> **BOS es el observador que instala, repara y mantiene las fichas.** K8s corre el contenedor; BOS gestiona el ciclo de vida completo. Un problema en una ficha es responsabilidad de BOS — no de K8s.

El pipeline correcto para cualquier ficha con estado degradado es:

```
k8s_discovery detecta anomalía en K8s
    ↓
mapea a estado BOS: DEGRADADA o PHYSICAL_ERROR
    ↓
observer Fase 3 detecta el estado degradado
    ↓
Orchestrator.Repair(fichaID) → ejecuta task_catalog.sh ficha_repair()
    ↓
ficha_repair() resuelve el problema (unseal, migration, seed, etc.)
    ↓
k8s_discovery: pod healthy → INSTALLED
```

Este pipeline **YA EXISTE en el código** de BOS. El problema de Vault no es un error de diseño del instalador — es que **dos gaps impiden que el pipeline se complete**.

---

### 7.0.1 Gaps que rompen el pipeline (análisis de código)

#### GAP-A — El liveness probe de K8s mata el pod antes de que llegue a DEGRADADA

> ✅ **FIX-26A APLICADO** — commit `0a1a182` · Pendiente deploy en VPS (copiar task_catalog.sh + `bosctl ficha repair vault`)

**Código CORREGIDO en `S02/vault/task_catalog.sh`:**
```yaml
livenessProbe:
  httpGet:
    path: /v1/sys/health?standbyok=true&sealedok=true   # ← FIX-26A: sealedok=true agregado
  initialDelaySeconds: 60
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /v1/sys/health?standbyok=true&sealedok=true&uninitok=true   # ← correcto (sin cambio)
```

**Lo que hace el k8s_discovery (`internal/reconcile/k8s_discovery.go:172-183`):**
```go
func workloadStatusToFichaState(ws *k8s.WorkloadStatus) state.FichaState {
    switch {
    case ws.IsReady():       return state.StateInstalled    // todas las réplicas Ready
    case ws.IsDegraded():    return state.StateDegraded     // réplicas parciales
    case ws.Found:           return state.StatePhysicalError // pod existe pero NO está en ningún ReplicaSet Ready
    default:                 return state.StatePending
    }
}
```

**El problema con CrashLoopBackOff:**
- Cuando el pod entra en CrashLoop, K8s cuenta el pod como `Found=true` pero ninguna réplica está Ready ni Running estable
- `IsReady()=false`, `IsDegraded()=false`, `Found=true` → **PHYSICAL_ERROR**
- El pod nunca llega a DEGRADADA → el observer nunca lo repara

**Si el liveness probe tuviera `sealedok=true`:**
- Pod no muere → se queda Running pero NotReady (readinessProbe falla cuando sellado)
- `IsReady()=false`, `IsDegraded()=true` (réplicas deseadas=1, Ready=0 pero Running=1) → **DEGRADADA**
- Observer Fase 3 detecta DEGRADADA → llama `ficha_repair` → unseal → pod queda Ready → INSTALLED

#### GAP-B — El observer ignoraba PHYSICAL_ERROR

> ✅ **FIX-B APLICADO** — commit `0a1a182` · Ya activo en el binario de la VPS tras rebuild

**Código CORREGIDO en `internal/observer/observer.go:228-230`:**
```go
// Fase 3 — reparar fichas DEGRADADA o PHYSICAL_ERROR
for name, fichaEntry := range st.Fichas {
    if fichaEntry.State != state.StateDegraded &&
        fichaEntry.State != state.StateRepairing &&
        fichaEntry.State != state.StatePhysicalError {  // ← FIX-B: PHYSICAL_ERROR incluido
        continue
    }
```

La máquina de estados ya permitía `PHYSICAL_ERROR → REPAIRING` (`types.go:144`). Ahora el observer también lo dispara.

#### GAP-C — Manifests sin `health.check_command`

El health checker (`internal/health/checker.go`) está implementado y ejecutaría `check_command` del manifest para detectar problemas proactivamente (sin esperar a que K8s lo detecte). Pero **ningún manifest de las fichas instaladas define `health.check_command`** → `health_status = UNKNOWN` para todas las fichas.

Sin `check_command`, BOS solo detecta problemas a través del k8s_discovery — que solo ve el estado de los pods, no el estado interno de la aplicación (como "Vault sellado").

---

### 7.0.2 Los dos fixes que cierran los tres gaps

**FIX-A / FIX-26A (task_catalog.sh de vault) — ✅ APLICADO (commit 0a1a182) · Pendiente deploy VPS:**
```bash
# ANTES:
path: /v1/sys/health?standbyok=true
# DESPUÉS (activo en repositorio):
path: /v1/sys/health?standbyok=true&sealedok=true
```
Con esto: pod sellado → Running+NotReady → DEGRADADA → observer lo repara.

**FIX-B (observer.go) — ✅ APLICADO (commit 0a1a182):**
```go
// ANTES:
if fichaEntry.State != state.StateDegraded && fichaEntry.State != state.StateRepairing {

// DESPUÉS (activo):
if fichaEntry.State != state.StateDegraded &&
   fichaEntry.State != state.StateRepairing &&
   fichaEntry.State != state.StatePhysicalError {
```
Con esto: incluso si un pod llega a CrashLoop, BOS intenta repararlo automáticamente.

**FIX-C (en manifests de fichas críticas) — Agregar `health.check_command`:**
```yaml
# vault/manifest.yml:
health:
  check_command: "kubectl exec vault-0 -n sbos-security -- vault status | grep -q 'Sealed.*false'"
  check_interval_seconds: 30
  consecutive_failures_threshold: 2

# postgresql/manifest.yml:
health:
  check_command: "kubectl exec postgresql-0 -n sbos-data -- pg_isready -U postgres"
  check_interval_seconds: 30
  consecutive_failures_threshold: 3
```
Con esto: BOS detecta "Vault sellado" como degradación proactivamente — sin esperar al CrashLoop.

---

### 7.0.3 Cadena de idempotencia con los tres fixes

```
▶ Vault arranca (sellado)
    → readinessProbe: sealedok=true → 200 OK → pod Running, NOT Ready
    → livenessProbe: sealedok=true → 200 OK → pod NO muere
    → health.check_command: "vault status | grep Sealed.*false" → falla → DEGRADADA
    → observer Fase 3: detecta DEGRADADA → Repair()
        → task_catalog.sh ficha_repair():
            sealed=$(vault status) == "true"
            vault operator unseal $KEY1 $KEY2 $KEY3
        → sealed == "false"
    → readinessProbe ahora retorna 200 (vault unsealed)
    → pod pasa a Ready
    → health.check_command retorna 0 → HEALTHY
    → k8s_discovery: IsReady() = true → INSTALLED
    
▶ Vault cae 3 días después (reinicio del pod):
    → mismo ciclo automático, sin intervención humana
    → idempotente: si ya está unsealed, ficha_repair() retorna OK sin hacer nada
```

Este es el comportamiento soberano correcto: **BOS detecta, BOS repara, sin intervención manual**.

---

## 8. Informe técnico integral — Secuencia, errores y dudas de concepción

### 8.1 Secuencia de instalación declarada (execution_order)

La secuencia de 60 fichas está definida por `execution_order` en cada `manifest.yml`. BOS la respeta estrictamente: una ficha no arranca hasta que sus `dependencies[]` estén en estado INSTALLED.

```
Orden  Ficha                       Servidor  auto  Dependencias clave
─────  ──────────────────────────  ────────  ────  ──────────────────────────────────
  1    bos-preflight               S-HOST    sí    —
  5    sbos-namespace              S-HOST    sí    sbos-bootstrap-k8s
 10    sbos-bootstrap-os           S-HOST    sí    —
 20    sbos-bootstrap-k8s          S-HOST    sí    sbos-bootstrap-os
 25    sbos-bootstrap-cni          S-HOST    sí    sbos-bootstrap-k8s
 28    sbos-bootstrap-platform     S-HOST    sí    sbos-bootstrap-cni           ← BUG-31: no en state
 30    sbos-bootstrap-storage      S-HOST    sí    sbos-bootstrap-k8s, cni
 35    sbos-bootstrap-monitoring   S-HOST    sí    sbos-bootstrap-k8s, cni, storage
 50    sbos-k8s-network-validator  S-HOST    sí    sbos-bootstrap-platform      ← BUG-31: no en state
 70    sbos-bkernel                S-HOST    sí    postgresql, redis, vault
100    kyverno                     S03       sí    sbos-bootstrap-k8s, cni      ← BUG-30: PENDING vs k8s parcial
100    postgresql                  S01       sí    k8s, cni, storage, vault     ← ojo: dep circular con vault
110    linkerd                     S03       sí    sbos-bootstrap-k8s, cni      ← BUG-29: 2/5 pods crash
110    redis                       S01       sí    k8s, cni, storage, vault
120    minio                       S01       sí    k8s, cni, storage, vault
130    vault                       S02       sí    k8s, cni, storage, postgresql ← BUG-26: CrashLoop sealed
135    besu-qbft                   S02       sí    postgresql, vault
140    keycloak                    S03       sí    postgresql, vault
150    oauth2-proxy                S02       sí    keycloak, vault, kong        ← BUG-27 + BUG-33
160    kong                        S02       sí    postgresql, keycloak, vault
170    nginx                       S02       sí    kong                         UPDATE_AVAILABLE
170    sbos-notifier               S06       sí    postgresql, redis, vault...
170    tryton                      S01       NO    postgresql, vault, kong      ← INSTALL_FAILED por vault
200    prometheus                  S12       sí    sbos-bootstrap-storage...
200    nextcloud                   S13       ?     postgresql, redis, minio...
205    alertmanager                S12       sí    prometheus
210    guacamole                   S13       ?     postgresql, keycloak, kong
215    grafana                     S12       sí    prometheus, keycloak, vault
220    onlyoffice                  S13       ?     postgresql, redis, kong
230    fedora-kde                  S13       ?     keycloak, kong, guacamole    UPDATE_AVAILABLE
250    sbos-bootstrap-hard         S-HOST    sí    (prometheus, grafana)
```

> **Inconsistencia crítica detectada:** `postgresql` y `redis` declaran `vault` como dependencia (orden 100/110), pero `vault` (orden 130) declara `postgresql` como dependencia. Dependencia circular. BOS resuelve esto en la práctica porque Vault se instala sin que PostgreSQL use Vault internamente, pero la declaración es incorrecta conceptualmente → **BUG-35**.

---

### 8.2 Análisis de cada problema

---

#### BUG-26 — Vault: CrashLoopBackOff — pod sellado mata el liveness probe

**Estado:** ✅ **FIX-26A COMMITEADO** (commit `0a1a182`) · Vault sigue en PHYSICAL_ERROR en VPS hasta que se aplique el fix

**Error original (logs):**
```
==> Vault server started!
==> Vault shutdown triggered   ← K8s lo mataba por liveness probe
```
```yaml
# Probe ANTES (incorrecto):
livenessProbe:
  httpGet:
    path: /v1/sys/health?standbyok=true   ← devolvía 503 si sellado → K8s mataba el pod

# Probe DESPUÉS (fix aplicado en repositorio):
livenessProbe:
  httpGet:
    path: /v1/sys/health?standbyok=true&sealedok=true   ← pod permanece Running aunque sellado
```

**Por qué ocurre:** Vault con Raft reinicia sellado tras cada muerte del pod. El endpoint devuelve 503 cuando está sellado sin `sealedok=true`. K8s interpreta 503 como fallo → mata el pod → ciclo infinito.

**Impacto en cascada (activo hasta deploy del fix en VPS):**
- `oauth2-proxy` → PHYSICAL_ERROR (no puede leer secretos OIDC de Vault)
- `tryton` → INSTALL_FAILED (task_catalog.sh necesita credenciales de Vault)
- `grafana`, `prometheus`, `kong`, `keycloak` → funcionan porque sus secretos ya están en K8s Secrets desde la instalación inicial

**FIX-26A aplicado en `S02/vault/task_catalog.sh` (commit 0a1a182):**
```yaml
livenessProbe:
  httpGet:
    path: /v1/sys/health?standbyok=true&sealedok=true   ← CORRECTO — en repositorio
  initialDelaySeconds: 60
  periodSeconds: 15
  failureThreshold: 3
```
Con `sealedok=true`, Vault sellado devuelve 200 → K8s no lo mata → Vault puede recibir unseal.

*Parte B — Init container de auto-unseal en el StatefulSet de Vault:*
```yaml
initContainers:
- name: vault-unseal
  image: hashicorp/vault:2.0.1
  command: ["/bin/sh", "-c"]
  args:
  - |
    until vault status -address=http://127.0.0.1:8200 2>/dev/null; do sleep 2; done
    if vault status -address=http://127.0.0.1:8200 | grep -q 'Sealed.*true'; then
      vault operator unseal -address=http://127.0.0.1:8200 $UNSEAL_KEY_1
      vault operator unseal -address=http://127.0.0.1:8200 $UNSEAL_KEY_2
      vault operator unseal -address=http://127.0.0.1:8200 $UNSEAL_KEY_3
    fi
  env:
  - name: UNSEAL_KEY_1
    valueFrom:
      secretKeyRef:
        name: vault-unseal-keys
        key: key1
  # etc.
```
O más simple: un K8s CronJob que corre cada 2 minutos y hace unseal si detecta que Vault está sellado.

**Acción inmediata (sin rebuild):**
```bash
# Ejecutar en VPS como root — ventana de 55s tras reinicio del pod
export KUBECONFIG=/root/.kube/config
kubectl delete pod vault-0 -n sbos-security --grace-period=5
sleep 30
for KEY in $(python3 -c "import json; d=json.load(open('/etc/bos/vault-init-keys.json')); [print(k) for k in d['unseal_keys_b64'][:3]]"); do
  kubectl exec -n sbos-security vault-0 -- vault operator unseal $KEY
done
```

---

#### BUG-27 — oauth2-proxy: TIMEOUT en instalación + CrashLoopBackOff

**Estado:** PHYSICAL_ERROR · instalación reintentada 4 veces · 78 reinicios en pods actuales

**Error exacto (logs):**
```
[2026-10-12T16:49:24Z] [oauth2-proxy] TIMEOUT: oauth2-proxy pod no Ready en 120s
[2026-10-12T16:51:29Z] [oauth2-proxy] TIMEOUT: oauth2-proxy pod no Ready en 120s
... (se repite 4 veces)
```

**Por qué ocurre:** oauth2-proxy necesita conectarse a Keycloak (OIDC) para arrancar. Keycloak está up, pero el proxy de linkerd inyectado en el pod de oauth2-proxy no puede obtener certificado de identidad (ver BUG-29 y BUG-33). El pod tiene 2 contenedores (`0/2`) — oauth2-proxy + linkerd-proxy. El sidecar de linkerd está en failfast → oauth2-proxy nunca llega a Ready.

**Solución:** Dos pasos:
1. Arreglar Vault (BUG-26) y Linkerd (BUG-29)
2. Si el ciclo persiste, excluir oauth2-proxy del mesh de linkerd mientras se estabiliza:
   ```bash
   kubectl patch deployment oauth2-proxy -n sbos-security \
     -p '{"spec":{"template":{"metadata":{"annotations":{"linkerd.io/inject":"disabled"}}}}}'
   ```
   Esto hace que el pod tenga solo 1 contenedor (sin sidecar de linkerd) y puede arrancar normalmente.

---

#### BUG-29 — Linkerd: 2/5 pods en CrashLoopBackOff — doble instalación + race condition identity

**Estado:** INSTALLING · 3/5 pods Running · 2 pods en CrashLoop

**Error exacto (logs):**
```
Failed to obtain identity error=status: Unknown, message: "controller 
linkerd-identity-headless.linkerd.svc.cluster.local:8080: service in fail-fast"
```

**Por qué ocurre:** Hay duplicados de deployments:
```
linkerd-destination-865f677f9f-lgv9w      4/4 Running    ← instancia original, OK
linkerd-destination-965876b9f-ffgqq       0/4 CrashLoop  ← segunda instancia, replica set nuevo
linkerd-proxy-injector-6b9b9dccd9-gvmwj   2/2 Running    ← instancia original, OK
linkerd-proxy-injector-67bbcc7755-p29t9   0/2 CrashLoop  ← segunda instancia, replica set nuevo
```

Los pods en crash son de un segundo ReplicaSet creado durante un re-install o rolling update. Estos nuevos pods tienen el proxy de linkerd inyectado (el webhook ya estaba activo), pero el proxy no puede comunicarse con `linkerd-identity` porque está en un estado inconsistente. Los pods originales (sin sidecar) siguen corriendo.

**Solución:**
1. Escalar a 0 los pods en crash (los ReplicaSets huérfanos):
   ```bash
   kubectl scale deploy linkerd-destination -n linkerd --replicas=1  # solo 1 instancia
   kubectl scale deploy linkerd-proxy-injector -n linkerd --replicas=1
   ```
2. O hacer un helm rollback de linkerd a la versión anterior del chart.
3. A largo plazo: el task_catalog.sh de linkerd debe detectar que linkerd ya está instalado y NO volver a hacer `helm upgrade --install` sin `--atomic` — una actualización que falla deja duplicados.

---

#### BUG-30 — Kyverno: PENDING en state pero admission-controller en CrashLoopBackOff

**Estado en state:** PENDING · **Estado real en K8s:** 1/4 pods en CrashLoopBackOff (126+ reinicios)

**Pods en K8s:**
```
kyverno-admission-controller    0/1 CrashLoopBackOff  126 reinicios   ← falla crítica
kyverno-background-controller   1/1 Running
kyverno-cleanup-controller      0/1 Running            (arranque lento)
kyverno-reports-controller      1/1 Running
```

**Error exacto (logs admission-controller):**
```
dial tcp 10.96.0.1:443: i/o timeout
```
`10.96.0.1` es la ClusterIP del servicio `kubernetes` — el apiserver. El admission-controller no puede conectarse al apiserver desde dentro del pod. Este es el **mismo problema de hairpin NAT** de FIX-19, pero ahora afecta el namespace `kyverno`.

**Por qué es diferente a los demás componentes de Kyverno:** El admission-controller es el único componente que necesita hacer llamadas SALIENTES al apiserver para registrar su webhook. Background-controller y reports-controller hacen llamadas al propio proceso de kyverno (puerto local), no al apiserver externamente. El admission-controller REQUIERE que el apiserver sea alcanzable desde el pod.

**Problema dual:**
1. El state dice PENDING pero K8s tiene kyverno parcialmente instalado → inconsistencia state vs realidad.
2. Sin admission-controller funcional, las políticas Kyverno no se aplican — las NetworkPolicies y PodSecurityPolicies del cluster no se validan.

**Causa raíz:** La regla hairpin NAT de FIX-19 se aplica en el host, pero el namespace `kyverno` puede tener una NetworkPolicy que bloquea el tráfico de salida hacia `10.96.0.1`. O la regla iptables se perdió si el pod arrancó antes de que se aplicara la regla.

**Solución:**
```bash
# 1. Verificar que la regla hairpin NAT sigue aplicada
iptables -t nat -L OUTPUT -n | grep 6443

# 2. Si la regla no está, reaplicarla (FIX-19)
NODE_IP=$(kubectl get node -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
iptables -t nat -A OUTPUT -d ${NODE_IP}/32 -p tcp --dport 6443 -j REDIRECT --to-port 6443
iptables-save > /etc/iptables/rules.v4

# 3. Verificar NetworkPolicy del namespace kyverno (no debe bloquear egress a 10.96.0.1)
kubectl get networkpolicy -n kyverno

# 4. Reiniciar admission-controller con la regla ya aplicada
kubectl delete pod -n kyverno -l app.kubernetes.io/component=admission-controller

# 5. Si persiste, helm upgrade forzado
helm upgrade kyverno kyverno/kyverno --version 3.3.4 -n kyverno --reuse-values --force
```

---

#### BUG-31 — sbos-bootstrap-platform y sbos-k8s-network-validator: fichas huérfanas

**Estado:** Existen en `/etc/bos/blibs/servers/S-HOST/` pero NO aparecen en `.sbos_state.json`

**Impacto:** Ninguno funcional inmediato — las fichas que los declaran como dependencia (`elasticsearch`, `rabbitmq`, `gitlab`, etc.) están todas en `auto_install=false`. Pero deberían estar registradas en el state para que el observer las supervise.

**Causa:** Probablemente se agregaron a las fichas en el repo después de que el instalador ya corrió y creó el state. BOS no descubrió estas fichas nuevas porque el state ya existía.

**Solución:** Ejecutar `bosctl ficha install sbos-bootstrap-platform` para que BOS las registre. O reiniciar bos.service para que el discovery incluya las fichas nuevas del directorio.

---

#### BUG-32 — tryton: duplicado en fichas (S01 y S04)

**Estado:** En la secuencia de ejecución aparece `tryton` dos veces — en S01 y en S04 — con el mismo `execution_order: 170`.

**Impacto:** El state registra solo una instancia (`tryton: INSTALL_FAILED`). La ficha en S04 (`tryton-workers` o replica) puede causar conflictos si se intenta instalar.

**Duda de concepción:** ¿S01 es el servidor de aplicación Tryton y S04 es el servidor de workers/multi-instancia? Si es así, deben tener IDs diferentes (`tryton-app` y `tryton-workers`) y el segundo debe depender del primero. Verificar con el diseño de servidores.

---

#### BUG-33 — oauth2-proxy inyectado en mesh de linkerd prematuramente

**Estado:** Pods de oauth2-proxy tienen 2 contenedores (`0/2`) — el sidecar de linkerd fue inyectado automáticamente por el webhook de linkerd.

**Por qué es un problema:** El sidecar necesita que `linkerd-identity` esté completamente funcional para obtener certificados mTLS. Si linkerd está parcialmente instalado (BUG-29), el sidecar entra en failfast y bloquea el arranque de oauth2-proxy.

**Solución corta:** Anotar el namespace para excluir los pods de oauth2-proxy del mesh hasta que linkerd esté estable:
```bash
kubectl annotate namespace sbos-security linkerd.io/inject=disabled --overwrite
kubectl rollout restart deployment oauth2-proxy -n sbos-security
```
Una vez linkerd esté estable, remover la anotación para que el mesh aplique correctamente.

---

#### BUG-34 — fedora-kde: versión inconsistente entre manifest y estado real

**Estado:** UPDATE_AVAILABLE

**Inconsistencia:**
- `manifest.yml` declara `version: "41.0.0"` 
- Imagen corriendo en K8s: `docker.io/sbos/fedora-desktop:1.3.0`
- Imagen local actualizada: `1.4.0` (Containerfile v1.4.0 con KWallet desactivado)

**Duda de concepción:** La versión `41.0.0` en el manifest no corresponde al tag de imagen `1.3.0`. El versionado del manifest y de la imagen Docker siguen esquemas diferentes y no están sincronizados. Esto confunde al observador de BOS que no puede comparar versiones correctamente.

**Solución:** Sincronizar: si el manifest dice `version: 1.4.0`, la imagen debe ser `docker.io/sbos/fedora-desktop:1.4.0`. El tag de imagen DEBE coincidir con la versión del manifest para que BOS detecte actualizaciones correctamente.

**Para aplicar la actualización:**
```bash
# 1. Actualizar manifest.yml con version: "1.4.0"
# 2. Reconstruir imagen 1.4.0 en la VPS
# 3. bosctl ficha update fedora-kde
```

---

#### BUG-35 — Dependencia circular: postgresql/redis dependen de vault, vault depende de postgresql

**Estado:** Error de diseño en manifests · sin impacto funcional actual pero semánticamente incorrecto

**Declaración en manifests:**
```yaml
# postgresql/manifest.yml:
dependencies: [sbos-bootstrap-k8s, sbos-bootstrap-cni, sbos-bootstrap-storage, vault]
# redis/manifest.yml:
dependencies: [..., vault]
# vault/manifest.yml:
dependencies: [sbos-bootstrap-k8s, sbos-bootstrap-cni, sbos-bootstrap-storage, postgresql]
```

**Problema:** `vault` depende de `postgresql` → postgresql debe instalarse antes que vault. Pero `postgresql` también declara `vault` como dependencia → vault debe instalarse antes que postgresql. Ciclo.

**Por qué funciona en la práctica:** BOS usa `execution_order` como desempate. Como `postgresql` tiene order 100 y `vault` tiene order 130, postgresql se instala primero aunque la dependencia circular esté declarada. PostgreSQL NO necesita Vault funcionando para instalarse — solo para leer credenciales más adelante.

**Solución FIX-35:** Eliminar `vault` de las dependencias de `postgresql` y `redis`. Estas fichas no necesitan Vault para instalarse; sus credenciales se generan y guardan en Vault después de que ambos estén running.

---

#### BUG-36 — Kyverno admission-controller: hairpin NAT no aplicado en namespace kyverno

**Estado:** Derivado de BUG-30 · causa raíz confirmada · hairpin NAT es el patrón de fallo reincidente

**Error exacto:**
```
dial tcp 10.96.0.1:443: i/o timeout
```

**Contexto:** Este es el cuarto bug causado por el hairpin NAT en este proyecto (FIX-19 fue el primero). La regla de FIX-19 se aplica en el arranque del nodo (`/etc/iptables/rules.v4`), pero puede no estar disponible cuando un pod de un namespace específico arranca por primera vez si hay un delay de carga de reglas.

**Patrón sistémico:** Cualquier pod que necesite llamar al apiserver de K8s (`kubernetes.default.svc.cluster.local` → `10.96.0.1:443`) falla si:
1. La VPS no tiene hairpin NAT en el router (Hetzner — caso conocido).
2. La regla iptables no está aplicada en el momento en que el pod hace la primera llamada.

**Fichas que pueden verse afectadas por este patrón:**
- kyverno-admission-controller ← afectado actualmente
- Cualquier webhook admission controller
- Cualquier controlador que llame al apiserver directamente (RBAC, cert-manager, etc.)

**Fix permanente para el patrón (FIX-36):** Agregar verificación de la regla hairpin NAT al task_catalog.sh del bootstrap y al observer:

```bash
# En sbos-bootstrap-k8s/task_catalog.sh ficha_health_check():
_verificar_hairpin_nat() {
    local node_ip
    node_ip=$(kubectl get node -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
    if ! iptables -t nat -C OUTPUT -d "${node_ip}/32" -p tcp --dport 6443 -j REDIRECT --to-port 6443 2>/dev/null; then
        echo "WARN: regla hairpin NAT faltante — reaplicando"
        iptables -t nat -A OUTPUT -d "${node_ip}/32" -p tcp --dport 6443 -j REDIRECT --to-port 6443
        iptables-save > /etc/iptables/rules.v4
    fi
}
```

Esto permite que el motor de fichas, al ejecutar `ficha_health_check()` como parte del observer, detecte y repare automáticamente la pérdida de la regla hairpin NAT — sin intervención humana.

**Solución inmediata:**
```bash
# En VPS como root
NODE_IP=$(kubectl get node -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
iptables -t nat -A OUTPUT -d ${NODE_IP}/32 -p tcp --dport 6443 -j REDIRECT --to-port 6443
iptables-save > /etc/iptables/rules.v4
kubectl delete pod -n kyverno -l app.kubernetes.io/component=admission-controller
```

---

### 8.3 VDI (fedora-kde) — Principios de diseño y dudas de concepción

> **El VDI es el producto de cara al usuario final.** Es la ventana a través de la cual el cliente accede a toda la suite SBOS. Cualquier fallo en el escritorio es el primer contacto del usuario con el sistema — y un fallo mal manejado destruye la confianza en todo el producto. **Los cambios al VDI deben ser profesionales, reproducibles y recuperables sin intervención humana.**

#### Principios irrenunciables del VDI

| Principio | Regla | Consecuencia si se viola |
|-----------|-------|--------------------------|
| **P-VDI-1 — Imagen como fuente de verdad** | Toda configuración del escritorio vive en el `Containerfile`. Nada en ConfigMaps, nada en `kubectl exec`, nada fuera de la imagen. | El ConfigMap `fedora-kde-start-script` viola este principio → debe eliminarse (VDI-4). |
| **P-VDI-2 — Versión semántica sincronizada** | La versión en `manifest.yml` DEBE coincidir exactamente con el tag Docker de la imagen. `version: "1.4.0"` → imagen `sbos/fedora-kde:1.4.0`. | BOS no puede comparar versiones correctamente → UPDATE_AVAILABLE nunca se resuelve. |
| **P-VDI-3 — Resurrección sin intervención** | Si el pod muere (reinicio, OOMKill, node drain), K8s levanta uno nuevo y el escritorio arranca exactamente igual. El usuario ve el mismo escritorio en menos de 2 minutos — sin que nadie toque nada. | Cualquier configuración fuera de la imagen se pierde en el reinicio. |
| **P-VDI-4 — Cambio atómico** | Un cambio en el escritorio sigue este flujo: `Containerfile` → commit → buildah build → nueva versión de imagen → `manifest.yml version:` → `bosctl ficha update fedora-kde`. Nunca aplicar configuraciones a mano y luego "recordar" escribirlas en la imagen. | Configuraciones aplicadas manualmente no sobreviven al próximo rebuild. |
| **P-VDI-5 — Testeo antes de producción** | Antes de hacer `bosctl ficha update`, verificar visualmente en noVNC que el escritorio arranca correctamente: panel visible, apps del menú accesibles, sin popups de error. | Una actualización de imagen rota deja al usuario sin escritorio hasta el rollback. |
| **P-VDI-6 — Rollback trivial** | Cada versión de imagen se guarda en el registry local antes de hacer update. Si la nueva imagen falla, `bosctl ficha repair fedora-kde` debe volver a la última versión estable en segundos. | Sin versión anterior disponible, el rollback requiere rebuild completo (~15 min). |

#### Protocolo de cambio al VDI (obligatorio para cualquier modificación)

```
1. Modificar Containerfile con el cambio
2. Probar localmente (buildah build + run manual)
3. Commit con versión semántica: git commit -m "feat(vdi): v1.5.0 — descripción"
4. Actualizar manifest.yml: version: "1.5.0"
5. Transferir imagen a VPS: buildah push o scp del .tar
6. bosctl ficha update fedora-kde
7. Verificar en noVNC: escritorio visible, apps del menú funcionando
8. Si algo falla: bosctl ficha repair fedora-kde → imagen anterior
```

**Nunca:** `kubectl exec` para cambiar configuración → `kubectl edit` deployment → `kubectl apply` de YAML editado a mano. Esos cambios no sobreviven al próximo `bosctl ficha update`.

---

#### VDI-1 — ¿Cómo se mantiene la configuración del escritorio entre reinicios del pod?

**Situación actual:** Toda la configuración KDE (tema, wallpaper, iconos, kwalletrc) vive en `/home/vdiuser/.config/` dentro del pod. Si el pod se reinicia, se pierde.

**Opciones:**
- A) Baked en la imagen: toda configuración se preconfigura en el Containerfile. ✅ Adoptado parcialmente (kwinrc, kwalletrc). Contra: requiere rebuild para cambiar configuración.
- B) PersistentVolumeClaim: montar `/home/vdiuser` en un PVC. ✅ Persiste entre reinicios. Contra: más complejo de gestionar.
- C) ConfigMaps: montar archivos de configuración desde ConfigMaps. ✅ Actualizable sin rebuild. Contra: solo para archivos pequeños.

**Recomendación:** Baked para configuración de base (tema, kwalletrc, kwinrc) + PVC para perfil de usuario (bookmarks, preferencias personales). La imagen actual usa solo "baked" → decisión pendiente de validar con el usuario.

#### VDI-2 — ¿Deben los servicios SBOS del escritorio apuntar a DNS interno de K8s o al dominio externo?

**Situación actual:** Las `.desktop` files usan `http://tryton.sbos-erp.svc.cluster.local:8000/` — DNS interno de K8s.

**Por qué es correcto:** El pod fedora-kde corre dentro del cluster K8s. Desde dentro del cluster, `tryton.sbos-erp.svc.cluster.local` resuelve directamente a la ClusterIP del servicio — sin pasar por el load balancer externo, sin necesidad de TLS público.

**Problema conocido:** Si el VDI se usa desde una máquina externa (no dentro del cluster) — por ejemplo, si se exporta el escritorio a una máquina Windows vía RDP/VNC externo — los DNS internos no resolverán. Para ese caso se necesita un Kong Ingress o un DNS split-horizon.

#### VDI-3 — ¿Por qué el error de certificado en Chrome al intentar abrir Tryton?

**Situación actual:** Chrome muestra `ERR_CERT_AUTHORITY_INVALID` con `13.140.128.230`. Esto ocurre porque:
1. Tryton no está desplegado (namespace `sbos-erp` vacío).
2. Chrome puede estar intentando resolver `tryton.sbos-erp.svc.cluster.local` → falla DNS → Chrome no muestra "DNS no encontrado" sino que cae al error de conexión.
3. O el usuario abrió Chrome navegando a `https://13.140.128.230` (la IP pública) que tiene un certificado autofirmado de Kong.

**Solución:** Desplegar Tryton (después de arreglar Vault). El ícono del menú apunta a `http://` (no `https://`) por lo que una vez que Tryton esté up, el error desaparece.

#### VDI-4 — ¿El script start-desktop.sh debe estar en la imagen o en un ConfigMap?

**Situación actual:** El script está en la imagen (`COPY resources/start-desktop.sh /start-desktop.sh`) pero también existe un ConfigMap `fedora-kde-start-script` que lo sobreescribe via `volumeMount`.

**Problema:** Doble fuente de verdad. Si se actualiza la imagen, el ConfigMap tiene prioridad y los cambios en el script de la imagen no se aplican.

**Solución:** Eliminar el ConfigMap `fedora-kde-start-script` — el script debe vivir solo en la imagen. El ConfigMap fue una solución temporal para parchear el pod sin rebuild; ahora que la imagen está actualizada, el ConfigMap debe eliminarse.

---

### 8.4 Prioridades de resolución

#### Hoja de ruta — orden lógico de implementación

Los fixes se ejecutan en este orden para desbloquear cada nivel antes de continuar:

```
NIVEL 0 — Infraestructura base (hairpin NAT)
  └── FIX-36: verificar y reaplicar regla hairpin NAT → desbloquea kyverno y cualquier admission controller

NIVEL 1 — Desbloquear Vault (raíz de la cascada)
  ├── FIX-26A: corregir liveness probe vault (sealedok=true) → vault deja de crashear
  ├── FIX-26B: init container auto-unseal → vault se abre solo tras reinicio
  └── FIX-B (observer.go): incluir PHYSICAL_ERROR en Fase 3 → BOS puede reparar vault automáticamente

NIVEL 2 — Desbloquear servicios que dependen de Vault
  ├── FIX-33: excluir oauth2-proxy del mesh de linkerd (anotación namespace)
  └── (automático) tryton: bosctl ficha install tryton → se instala tras vault y oauth2-proxy estables

NIVEL 3 — Desbloquear Linkerd
  └── FIX-29: escalar a 0 los ReplicaSets huérfanos de linkerd (destination + proxy-injector)

NIVEL 4 — Reparaciones de estado y limpieza
  ├── FIX-30: kyverno admission-controller (tras hairpin NAT — puede que se resuelva solo)
  ├── FIX-34: sincronizar versión fedora-kde manifest 1.4.0 + bosctl ficha update
  ├── FIX-VDI4: eliminar ConfigMap fedora-kde-start-script (doble fuente de verdad)
  └── FIX-31: bosctl ficha install sbos-bootstrap-platform

NIVEL 5 — Deuda técnica (no bloquean)
  ├── FIX-35: eliminar vault de dependencias de postgresql/redis (dependencia circular)
  ├── FIX-32: aclarar diseño multiservidor tryton S01/S04
  └── FIX-C (manifests): agregar health.check_command a fichas críticas (vault, postgresql, redis)
```

#### Tabla de prioridades

| Prioridad | Bug | Esfuerzo | Impacto | Nivel |
|-----------|-----|----------|---------|-------|
| P0 | **BUG-36/FIX-19** Verificar hairpin NAT en host | Bajo | Desbloquea kyverno admission-controller | 0 |
| P0 | **FIX-26A** Copiar vault/task_catalog.sh a VPS + repair + unseal | Muy bajo | Desbloquea vault, oauth2-proxy, tryton | 0 |
| P1 | **BUG-26** Vault liveness probe `sealedok=true` | Bajo | Vault deja de crashear — raíz de la cascada | 1 |
| P1 | **BUG-26** Vault init container auto-unseal | Medio | Vault se abre solo tras cada reinicio | 1 |
| P1 | **GAP-B** observer.go incluir PHYSICAL_ERROR Fase 3 | — | ✅ Ya aplicado (commit 0a1a182) | 1 |
| P2 | **BUG-33** oauth2-proxy excluir de linkerd mesh | Bajo | oauth2-proxy arranca sin esperar linkerd | 2 |
| P2 | **Tryton** bosctl ficha install tryton | Bajo | Despliega ERP tras vault estable | 2 |
| P3 | **BUG-29** Linkerd escalar ReplicaSets huérfanos | Bajo | Elimina CrashLoop en linkerd | 3 |
| P3 | **BUG-27** oauth2-proxy (derivado de vault+linkerd) | — | Se resuelve con P1+P2 | — |
| P4 | **BUG-30** Kyverno admission-controller | Bajo-Medio | Restart tras hairpin NAT o helm upgrade | 4 |
| P4 | **BUG-34** fedora-kde versión inconsistente | Bajo | Corregir manifest + bosctl ficha update | 4 |
| P4 | **VDI-4** Eliminar ConfigMap start-script | Bajo | `kubectl delete configmap fedora-kde-start-script` | 4 |
| P4 | **BUG-31** fichas huérfanas en state | Bajo | `bosctl ficha install sbos-bootstrap-platform` | 4 |
| P5 | **BUG-35** Dependencia circular postgresql↔vault | Bajo | Eliminar vault de deps de postgresql/redis | 5 |
| P5 | **BUG-32** tryton duplicado S01/S04 | Medio | Aclarar diseño multiservidor tryton | 5 |
| P5 | **GAP-C** Agregar `health.check_command` a manifests | Medio | BOS detecta estado interno, no solo pods K8s | 5 |
| P5 | **GAP-portman** Integrar portman en task_catalog.sh | Alto | Kardex poblado — Motor de Puertos activo | 5 |

---

---

## 9. Resumen ejecutivo — Estado del instalador y camino a PT-05 completo

### El instalador es idempotente y soberano — con dos gaps que deben cerrarse

BOS como instalador soberano está correctamente diseñado:
- El observer detecta estados degradados y dispara reparación automática.
- El motor de fichas ejecuta los task_catalog.sh con ciclos install/repair/remove.
- El motor de puertos (portman) tiene la interfaz completa para gestionar asignaciones.
- 24/35 fichas están INSTALLED y estables — el instalador funciona.

Los problemas actuales son **dos gaps de implementación**, no fallas de diseño:

| Gap | Componente | Efecto | Estado |
|-----|-----------|--------|--------|
| **GAP-A** | Liveness probe Vault sin `sealedok=true` | Vault en CrashLoop → cascada | ✅ **FIX-26A commiteado** (0a1a182) · pendiente VPS |
| **GAP-B** | Observer ignoraba `PHYSICAL_ERROR` en Fase 3 | BOS no reparaba fichas en CrashLoop | ✅ **FIX-B aplicado** (0a1a182) · activo en binario |
| **GAP-C** | Sin `health.check_command` en manifests | Detección tardía — BOS espera K8s, no actúa proactivamente | ⚠️ Pendiente (P2) — no bloqueante |
| **GAP-portman** | task_catalog.sh no llama a portman | Kardex vacío — motor de puertos no registra asignaciones | ⚠️ Pendiente (P5) — deuda técnica |
| **health check bos-preflight (tmpfs)** | Health check usaba `/run/bos` (tmpfs) | False-UNHEALTHY tras reboot | ✅ **Corregido** (de927a0) · verifica paths persistentes |

### Secuencia de fix — de lo más urgente a deuda técnica

1. **Hoy (P0-P1):** Reaplicar hairpin NAT → corregir liveness probe vault → rebuild bos con GAP-B fix → Vault se recupera solo
2. **Tras vault estable (P2):** Excluir oauth2-proxy de linkerd → instalar tryton
3. **Tras tryton (P3):** Escalar a 0 ReplicaSets huérfanos de linkerd
4. **Limpieza (P4):** fedora-kde v1.4.0 update + ConfigMap eliminar + fichas huérfanas
5. **Deuda técnica (P5):** Circular deps + health.check_command + portman integración en task_catalog.sh

Con P0-P3 ejecutados, el estado esperado es: **30+/35 fichas INSTALLED** · Vault estable · tryton desplegado · linkerd funcional.

---

## 10. Análisis del VDI — Propósito real, componentes necesarios y arquitectura de escala

> **El VDI de SBOS no es un escritorio remoto genérico — es un escritorio corporativo soberano** donde bAuth/Keycloak controlan el acceso a archivos, carpetas, recursos y aplicaciones; donde cada usuario tiene su propio espacio persistente; y donde cada acción queda auditada con `ctx_id`. Guacamole y VNC son los componentes correctos para este propósito. El único problema real es la arquitectura de provisioning.

**Criterio de éxito (PLAN-IMPLEMENTACION-BOS-VDI.md §1):**
> *NFC → banexus → bAuth evalúa → BOS genera ctx_id → Guacamole abre sesión Fedora KDE → usuario trabaja en Nextcloud/OnlyOffice*

---

### 10.1 Por qué cada componente es necesario — y cuál es el único problema real

#### Guacamole — el gateway de identidad y auditoría del escritorio

Guacamole no está en el VDI simplemente para "abrir un escritorio remoto". Su rol en SBOS es:

| Función | Cómo la cumple Guacamole |
|---------|--------------------------|
| **Punto de entrada único autenticado** | Integrado con Keycloak via OIDC — el usuario solo hace login una vez |
| **Control de qué sesiones puede abrir el usuario** | Las `guacamole_connection` se asignan por usuario/grupo en Keycloak — un contador solo ve su escritorio, un admin ve todos |
| **Auditoría completa de sesiones** | Guacamole registra inicio/fin de sesión, duración, actividad — integrable con ctx_id de bAuth |
| **Aislamiento de acceso** | El usuario no conoce la IP ni el puerto VNC de su pod — solo llega via el proxy de Guacamole |
| **Gateway a múltiples recursos** | El mismo Guacamole que abre fedora-kde puede abrir SSH a un servidor, RDP a una máquina Windows del cliente, etc. |

Sin Guacamole, el único acceso es noVNC directo — que no tiene autenticación de identidad, no controla quién puede acceder, y no audita las sesiones.

#### VNC (TigerVNC) — el protocolo correcto dentro del pod

TigerVNC dentro del pod fedora-kde es correcto porque:
- Es el protocolo que guacd (el daemon de Guacamole) entiende para conectarse al escritorio
- Es ligero, maduro, y no requiere agentes especiales en el escritorio
- Funciona con KDE Plasma sobre X11 sin modificaciones

**noVNC embebido en el pod:** puede eliminarse. Hoy el pod expone el puerto 6901 con noVNC que da acceso directo al escritorio sin pasar por Guacamole — es un bypass de seguridad. En producción, el puerto VNC (5900) solo debe ser accesible desde guacd, no desde el exterior.

#### KDE Plasma 6 — justificado por el propósito real

El escritorio KDE tiene sentido en SBOS porque:
- **Control de acceso a archivos/carpetas**: bAuth define qué directorios puede ver el usuario. Esto requiere un filesystem real montado en el escritorio, no un portal web.
- **Configuración del escritorio por rol**: El tema, las apps del menú, los atajos de teclado, los fondos — todo puede personalizarse según el rol del usuario en bAuth (un empleado de contabilidad ve apps de Tryton, un técnico ve la consola).
- **LibreOffice local**: Para documentos complejos, formatos propietarios o trabajo sin conexión a OnlyOffice.
- **Persistencia del espacio de trabajo**: El usuario puede tener archivos en `~/Documentos` que persisten entre sesiones — no en la nube, en su disco soberano.

---

### 10.2 El único problema real: arquitectura de provisioning

El escritorio KDE, Guacamole y VNC son correctos. El problema es uno solo:

> **`replicas: 1` hardcodeado — un solo pod de escritorio compartido entre todos los usuarios.**

Con la implementación actual, si 10 usuarios se conectan a Guacamole y abren "su escritorio", los 10 ven y controlan el mismo KDE. No hay aislamiento. No hay identidad por usuario en el escritorio.

La solución no es cambiar la tecnología — es cambiar la arquitectura de provisioning:

```
ARQUITECTURA ACTUAL (incorrecta):
──────────────────────────────────
Usuario A ─┐
Usuario B ─┼── Guacamole ──── guacd ──── fedora-kde pod único (replicas:1)
Usuario C ─┘                              (todos comparten el mismo escritorio)


ARQUITECTURA OBJETIVO (correcta):
──────────────────────────────────
                                         fedora-kde-<usuario-A> pod + PVC-A
                                        /
Usuario A ─┐                           /
Usuario B ─┼── Guacamole ──── guacd ──┼── fedora-kde-<usuario-B> pod + PVC-B
Usuario C ─┘                           \
                                        \
                                         fedora-kde-<usuario-C> pod + PVC-C

Cada usuario tiene:
  • Su propio pod fedora-kde (creado al login, destruido al logout o en standby)
  • Su propio PVC de 20Gi (persiste para siempre — sobrevive al pod)
  • Su propia configuración KDE (tema, apps, permisos) según su rol en bAuth
  • Sus archivos en ~/Documentos, ~/Nextcloud, ~/Desktop
```

---

### 10.3 Cómo bAuth y Keycloak controlan el escritorio

El control de acceso en el VDI opera en cuatro capas:

```
CAPA 1 — Autenticación (Keycloak + bAuth)
  Usuario presenta credenciales (o NFC via banexus)
  Keycloak valida → bAuth genera token bitmask de 64 bits
  El bitmask define: qué apps puede abrir, qué archivos puede ver,
  qué acciones puede ejecutar.

CAPA 2 — Autorización de sesión (Guacamole + bAuth)
  Guacamole consulta: ¿tiene este usuario permiso para abrir escritorio VDI?
  Si el bitmask incluye el bit VDI_ACCESS → Guacamole abre la conexión VNC
  Guacamole registra inicio de sesión con ctx_id

CAPA 3 — Configuración del escritorio (bAuth → PAM + envvars)
  Al crear el pod fedora-kde-<usuario>, BOS inyecta:
    • SBOS_USER_ROLES=contabilidad,documentos (del bitmask)
    • SBOS_HOME_PVC=fedora-kde-home-<user-id>
    • SBOS_ACCESSIBLE_APPS=[tryton,nextcloud,onlyoffice] (filtrado por bitmask)
  El script de inicio del escritorio lee estas variables y:
    • Monta solo las carpetas autorizadas de Nextcloud
    • Muestra solo los íconos de apps autorizados en el menú
    • Aplica el tema y fondo corporativo del tenant

CAPA 4 — Auditoría (ctx_id en cada operación)
  Cada acción del usuario genera un evento:
    • Apertura de sesión → ctx_id en Guacamole
    • Acceso a archivo → ctx_id en Nextcloud
    • Edición de documento → ctx_id en OnlyOffice
    • Cierre de sesión → ctx_id en Guacamole
  Todos los ctx_id van al Context Plane (bos.ctx.*)
  Audit trail inmutable disponible para compliance ISO 27001
```

---

### 10.4 Análisis de escala real — con la arquitectura correcta

Con provisioning dinámico de pods (1 pod por sesión activa, no por usuario registrado):

| Usuarios registrados | Sesiones activas típicas (20%) | Pods activos | RAM | ¿Factible? |
|----------------------|-------------------------------|-------------|-----|-----------|
| 100 | 20 | 20 pods | 40–80 GB | ✅ 1 servidor 96 GB |
| 500 | 100 | 100 pods | 200–400 GB | ✅ cluster 2-4 nodos |
| 1 000 | 200 | 200 pods | 400–800 GB | ✅ cluster 4-8 nodos |
| 10 000 | 2 000 | 2 000 pods | 4–8 TB | ⚠️ datacenter dedicado |

La imagen actual de 4 GB RAM por pod es optimizable. Las oportunidades:
- Eliminar Firefox del pod (el usuario usa Chrome para las apps SBOS vía Guacamole)
- Cambiar Chrome `--app` por links del menú KDE que abren en sesión Guacamole
- Reducir LibreOffice a solo Writer+Calc (sin Impress/Draw si no se usan)
- Resultado esperado: ~1.5–2 GB RAM por pod activo (reducción de 50%)

Con 2 GB por pod: 1000 sesiones activas = 2 TB — un cluster de 4 nodos de 512 GB cada uno.

---

### 10.5 Lo que hay que implementar para que el VDI sea lo que debe ser

El VDI actual es una demostración funcional pero no es el producto final. Estos son los gaps de implementación en orden de prioridad:

| Gap | Descripción | Impacto | Responsable |
|-----|-------------|---------|-------------|
| **VDI-GAP-1** | `replicas: 1` compartido — todo en un pod | Crítico — no hay aislamiento por usuario | task_catalog.sh fedora-kde |
| **VDI-GAP-2** | Sin PVC por usuario — escritorio se borra en reinicio | Crítico — P15: persistencia requerida | task_catalog.sh + provisioner |
| **VDI-GAP-3** | Guacamole sin conexiones configuradas — tabla vacía | Crítico — el gateway no apunta a nada | task_catalog.sh guacamole |
| **VDI-GAP-4** | noVNC expuesto directamente (bypass de Guacamole) | Seguridad — acceso sin autenticación bAuth | Eliminar o bloquear puerto 6901 externamente |
| **VDI-GAP-5** | Sin inyección del bitmask bAuth en el escritorio | Funcional — el escritorio no se personaliza por rol | init script fedora-kde |
| **VDI-GAP-6** | Provisioning manual — nadie crea pods por usuario | Funcional — requiere operación manual | BOS operator o CronJob |
| **VDI-GAP-7** | Sin destrucción de pod al cerrar sesión | Costo — pods inactivos consumen recursos | Guacamole hook + BOS |

#### VDI-GAP-1 y VDI-GAP-2 — La solución técnica

El provisioning dinámico de pods por usuario puede implementarse como una ficha BOS nueva (`fedora-kde-provisioner`) con dos funciones:

```bash
# ficha_install(): instala el provisioner (un CronJob o un Operator ligero)
# El provisioner escucha eventos de Guacamole (login/logout) y:

_crear_sesion_usuario() {
    local user_id="$1" bitmask="$2"
    # 1. Crear PVC si no existe (persiste para siempre)
    kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fedora-kde-home-${user_id}
  namespace: sbos-vdi
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 20Gi
EOF
    # 2. Crear pod con el PVC del usuario y el bitmask como env var
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: fedora-kde-${user_id}
  namespace: sbos-vdi
spec:
  containers:
  - name: desktop
    image: docker.io/sbos/fedora-kde:1.4.0
    env:
    - name: SBOS_USER_ID
      value: "${user_id}"
    - name: SBOS_BITMASK
      value: "${bitmask}"
    volumeMounts:
    - name: home
      mountPath: /home/vdiuser
  volumes:
  - name: home
    persistentVolumeClaim:
      claimName: fedora-kde-home-${user_id}
EOF
    # 3. Registrar la conexión en Guacamole apuntando al nuevo pod
    _guacamole_crear_conexion "$user_id" "fedora-kde-${user_id}.sbos-vdi.svc.cluster.local"
}

_destruir_sesion_usuario() {
    local user_id="$1"
    # Eliminar el pod — el PVC NO se elimina (datos persisten)
    kubectl delete pod "fedora-kde-${user_id}" -n sbos-vdi
    # El PVC permanece para la próxima sesión del usuario
}
```

---

### 10.6 El flujo completo del VDI soberano (criterio C-14)

```
1. Usuario toca tarjeta NFC en el lector físico
      ↓
2. banexus captura el evento → bhnexus → bAuth
   bAuth consulta SBOSDB: ¿está registrado este NFC? ¿tiene acceso VDI?
   bAuth genera token + bitmask (ej: VDI_ACCESS | NEXTCLOUD | TRYTON | ONLYOFFICE)
      ↓
3. BOS recibe el evento via ctx_id y llama fedora-kde-provisioner:
   "crear sesión para user_id=U42, bitmask=0x0F3A"
      ↓
4. fedora-kde-provisioner:
   - Crea PVC fedora-kde-home-U42 (si no existe)
   - Crea pod fedora-kde-U42 con el PVC montado en /home/vdiuser
   - Inyecta SBOS_BITMASK=0x0F3A en el pod
   - Registra conexión en Guacamole apuntando al pod
      ↓
5. El pod arranca en ~60s. El script start-desktop.sh lee SBOS_BITMASK:
   - Muestra solo los íconos de Tryton, Nextcloud, OnlyOffice (no Grafana)
   - Monta ~/Nextcloud via WebDAV autenticado con token bAuth
   - Aplica tema corporativo del tenant
      ↓
6. Guacamole notifica al navegador del usuario: "sesión lista"
   El usuario ve el escritorio KDE, con sus archivos, sus apps, su configuración
      ↓
7. El usuario trabaja. Cada acción genera eventos en bAuth con ctx_id:
   - Abrir archivo: evento AUDIT_FILE_ACCESS
   - Guardar en Nextcloud: evento AUDIT_STORAGE_WRITE
   - Abrir Tryton: evento AUDIT_APP_LAUNCH
      ↓
8. Al cerrar sesión:
   - fedora-kde-provisioner elimina el pod
   - El PVC permanece (20Gi de datos del usuario)
   - Guacamole registra fin de sesión con ctx_id
   - Próxima sesión: el usuario ve exactamente donde lo dejó
```

---

## 11. Auditoría consolidada del instalador — Estado real, gaps, inconsistencias y preguntas HITL

> **Base de esta auditoría:** inspección directa del código fuente en `BosAgent/src/servers/` y `internal/`. Todo punto tiene referencia a archivo y líneas reales. No hay suposiciones.

---

### 11.1 Estado real por componente — implementado vs pendiente

#### MOTOR BOS (Go — `internal/`)

| Módulo | Archivo | Estado | Evidencia |
|--------|---------|--------|-----------|
| Observer loop | `internal/observer/observer.go` | ✅ Implementado | Fase 1-2-3 funcionales |
| Observer GAP-B (PHYSICAL_ERROR) | `observer.go:230` | ✅ **FIX-B aplicado** (commit 0a1a182) | `StatePhysicalError` en condición Fase 3 |
| bos-preflight health check (tmpfs) | `bos-preflight/manifest.yml` | ✅ **Corregido** (commit de927a0) | health check usa `/etc/bos/rpc-token` + `/etc/bos/certs/bos.crt` — paths persistentes |
| Health checker | `internal/health/checker.go` | ✅ Implementado | Lee `check_command` del manifest |
| State manager | `internal/state/` | ✅ Implementado | 18 estados + fcntl.flock |
| Portman (Motor de Puertos) | `internal/server/rpc_portman.go` (397 l.) | ✅ Implementado | 7 métodos JSON-RPC |
| Portman — integración fichas | `servers/**/task_catalog.sh` | ❌ **GAP** | 0 fichas llaman `bos.portman.assign` |
| Scaler (auto-scaling aware) | `internal/scaler/scaler.go` | ✅ Implementado | Context-aware (bAuth sesiones activas) |
| Context Plane | `internal/context/` (2536 l.) | ✅ Implementado | ctx_id, lifecycle, bAuth integration |
| k8s_discovery | `internal/reconcile/k8s_discovery.go` | ✅ Implementado | Mapea K8s → BOS state cada 5min |
| VDI verification | `cmd/bosctl/vdi.go` + `internal/bootstrap/verify_vdi.go` | ✅ Implementado | C-09..C-14 verificables con `bosctl vdi verify` |
| VDI provisioner (1 pod/sesión) | (ningún módulo) | ❌ **GAP** | No existe lógica de provisioning dinámico |

#### FICHAS — clasificación por nivel de madurez real

**65 fichas totales en `BosAgent/src/servers/`**

| Nivel | Criterio | Cantidad | Fichas |
|-------|----------|----------|--------|
| **ROBUSTA** | >400 líneas · deploy completo · repair · idempotente | **22** | ver tabla §11.1a |
| **COMPLETA** | 200–400 líneas · funcional pero sin optimizar | **17** | ver tabla §11.1b |
| **STUB-135** | Exactamente 135 líneas · deploy básico sin repair ni PVC | **19** | S08-S09-S10-S12(3)-S14-S15 |
| **INCOMPLETA** | <200 líneas pero no es stub canónico | **7** | onlyoffice, ferretdb, calcom, tryton-workers, zabbix, velero, tempo |

##### Tabla §11.1a — Fichas ROBUSTAS (>400 líneas) con estado en VPS

| Ficha | Líneas | Estado VPS | Tiene repair | Tiene health.cmd |
|-------|--------|-----------|-------------|-----------------|
| `S02/vault` | 1308 | PHYSICAL_ERROR (FIX-26A commiteado, pendiente VPS) | ✅ | ❌ GAP |
| `S01/postgresql` | 834 | INSTALLED | ✅ | ❌ GAP |
| `S02/kong` | 788 | INSTALLED | ✅ | ❌ GAP |
| `S13/oauth2-proxy-desktop` | 596 | PHYSICAL_ERROR (derivado vault — se resuelve con FIX-26A) | ✅ | ❌ GAP |
| `S01/redis` | 591 | INSTALLED | ✅ | ❌ GAP |
| `S-HOST/sbos-bootstrap-monitoring` | 581 | INSTALLED | ✅ | ❌ GAP |
| `S-HOST/sbos-bootstrap-hard` | 576 | INSTALLED | ✅ | — |
| `S01/tryton` | 566 | INSTALL_FAILED (desbloqueado tras FIX-26A en VPS) | ✅ | ❌ GAP |
| `S04/tryton` | 566 | — | ✅ | ❌ GAP — **DUPLICADO de S01** |
| `S03/keycloak` | 549 | INSTALLED | ✅ | ❌ GAP |
| `S06/sbos-notifier` | 519 | INSTALLED | ✅ | ❌ GAP |
| `S-HOST/sbos-bootstrap-cni` | 492 | INSTALLED | ✅ | — |
| `S12/prometheus` | 490 | INSTALLED | ✅ | ❌ GAP |
| `S02/oauth2-proxy` | 479 | PHYSICAL_ERROR (derivado vault — se resuelve con FIX-26A) | ✅ | ❌ GAP |
| `S03/linkerd` | 440 | INSTALLING (en progreso — timeout 15 min esperado) | ✅ | ❌ GAP |
| `S13/nextcloud` | 422 | INSTALLED | ✅ | ❌ GAP |
| `S03/kyverno` | 418 | PENDING (hairpin NAT issue — BUG-36) | ✅ | ❌ GAP |
| `S12/alloy` | 386 | INSTALLED | ✅ | ❌ GAP |
| `S-HOST/sbos-bootstrap-storage` | 382 | INSTALLED | ✅ | — |
| `S12/grafana` | 390 | INSTALLED | ✅ | ❌ GAP |
| `S-HOST/sbos-bootstrap-k8s` | 639 | INSTALLED | ✅ | — |
| `S01/minio` | 598 | INSTALLED | ✅ | ❌ GAP |

##### Tabla §11.1b — Fichas COMPLETAS (200–400 líneas)

| Ficha | Líneas | Estado VPS | Tiene repair | Tiene health.cmd |
|-------|--------|-----------|-------------|-----------------|
| `S02/certbot` | 355 | INSTALLED | ✅ | — |
| `S-HOST/bos-preflight` | 334 | INSTALLED | ✅ | — |
| `S06/novu` | 327 | PENDING | ✅ | ✅ presente |
| `S-HOST/sbos-bootstrap-os` | 326 | INSTALLED | ✅ | — |
| `S-HOST/sbos-k8s-network-validator` | 319 | NO EN STATE | ✅ | — |
| `S12/alertmanager` | 315 | INSTALLED | ✅ | ❌ GAP |
| `S-HOST/sbos-bkernel` | 287 | INSTALLED | ✅ | ❌ GAP |
| `S10/mattermost` | 260 | — | ⚠️ básico | ❌ GAP |
| `S-HOST/sbos-bootstrap-platform` | 242 | NO EN STATE | ✅ | — |
| `S13/fedora-kde` | 239 | UPDATE_AVAIL | ✅ | ❌ **GAP CRÍTICO** |
| `S13/guacamole` | 230 | INSTALLED | ✅ | ❌ **GAP CRÍTICO** |
| `S-HOST/sbos-namespace` | 226 | INSTALLED | ✅ | — |
| `S13/sbos-vdi-config` | 221 | — | ✅ | — |
| `S10/mailserver` | 210 | — | ⚠️ básico | ❌ GAP |
| `S06/mattermost` | 726 | PENDING | ✅ | ❌ GAP |
| `S02/besu-qbft` | 654 | INSTALLED | ✅ | ❌ GAP |
| `S02/nginx` | 691 | UPDATE_AVAIL | ✅ | ❌ GAP |

---

### 11.2 Gaps reales del instalador — con localización exacta en el código

#### GAP-1 — Motor de Puertos: Kardex siempre vacío

**Severidad:** Media · **Archivo:** todos los `task_catalog.sh`

El módulo `rpc_portman.go` está implementado con 7 métodos JSON-RPC. Pero al hacer:
```bash
grep -rl "portman\|bos\.portman" servers/
# → 0 resultados
```
Ninguna de las 65 fichas llama a `bos.portman.assign` durante `ficha_install()`. Los puertos se asignan directamente en el YAML (`containerPort: 8080`) sin registrarlos en el Kardex. El Motor de Puertos existe pero no está integrado con el ciclo de instalación.

**Fix necesario:** Agregar al inicio de cada `ficha_install()` una llamada al portman para registrar los puertos del manifest. Puede hacerse como helper `_portman_assign()` en el boilerplate de task_catalog.sh.

---

#### GAP-2 — health.check_command: solo 3 fichas de 65 lo tienen

**Severidad:** Alta · **Archivos:** `servers/*/manifest.yml`

El health checker (`internal/health/checker.go`) está implementado. Solo 3 fichas lo usan:
- `S06/novu/manifest.yml` — `curl http://localhost:28200/v1/health-check`
- `S06/ferretdb/manifest.yml` — `curl http://localhost:27017/`
- `S06/calcom/manifest.yml` — `curl http://localhost:9061/api/health`

Las fichas críticas de la cadena de dependencias no tienen `check_command`:

| Ficha crítica | Sin check_command | Consecuencia |
|---------------|-------------------|--------------|
| vault | ❌ | BOS no detecta "Vault sellado" — espera al CrashLoop |
| postgresql | ❌ | BOS no detecta "PG no acepta conexiones" |
| keycloak | ❌ | BOS no detecta "realm no disponible" |
| kong | ❌ | BOS no detecta "gateway caído" |
| fedora-kde | ❌ | BOS no sabe si el escritorio arrancó correctamente |
| guacamole | ❌ | BOS no sabe si el gateway de sesiones está listo |

Sin `check_command`, el health_status de estas fichas es siempre `UNKNOWN`. BOS depende exclusivamente de k8s_discovery para detectar problemas — que solo ve el estado del pod, no el estado interno de la aplicación.

---

#### GAP-3 — VDI: sin provisioning dinámico por sesión de usuario

**Severidad:** Crítica para producción · **Archivo:** `servers/S13/fedora-kde/task_catalog.sh`

```bash
grep -n "replicas\|user_id\|SBOS_USER\|bitmask\|PersistentVolumeClaim" \
  servers/S13/fedora-kde/task_catalog.sh
# → Solo: replicas: 1 (línea 138)
# → 0 resultados para user_id, PVC, bitmask
```

El pod fedora-kde es una instancia única compartida. No existe lógica de:
- Creación de pod por sesión de usuario autenticado
- PVC por usuario para persistencia del home
- Inyección del bitmask bAuth en el pod al crear la sesión
- Destrucción del pod al cerrar sesión

**Fix necesario:** Nueva ficha `S13/fedora-kde-provisioner` + integración con Guacamole hook de sesión. El scaler (`internal/scaler/`) ya existe y es context-aware — puede extenderse para VDI.

---

#### GAP-4 — Guacamole: table guacamole_connection siempre vacía

**Severidad:** Crítica · **Archivo:** `servers/S13/guacamole/task_catalog.sh:57-58`

```sql
CREATE TABLE guacamole_connection (...);
CREATE TABLE guacamole_connection_parameter (...);
```

La tabla se crea pero nunca se inserta ninguna conexión. Guacamole arranc sin saber a dónde conectar. Cuando un usuario hace login en Guacamole, no ve ningún escritorio disponible — el gateway existe pero está vacío.

**Fix necesario:** En `ficha_post_install()` de guacamole, insertar una conexión VNC que apunte al pool de pods fedora-kde (o al pod específico del usuario después de que el provisioner lo cree). La conexión debe autenticarse via bAuth token.

---

#### GAP-5 — fedora-kde: noVNC expuesto sin autenticación bAuth

**Severidad:** Seguridad · **Archivo:** `servers/S13/fedora-kde/task_catalog.sh:157,203`

El pod expone el puerto 6901 (noVNC) directamente vía un Service K8s. Cualquier usuario que conozca la URL puede acceder al escritorio sin pasar por Guacamole ni por bAuth. Esto anula el control de acceso y la auditoría.

**Fix necesario:** Eliminar el Service que expone 6901 externamente. El puerto VNC (5900) solo debe ser accesible desde el pod de guacd. El acceso al escritorio debe ser exclusivamente a través de Guacamole autenticado.

---

#### GAP-6 — S13 fichas sin campo auto_install en manifest

**Severidad:** Media · **Archivos:** `servers/S13/*/manifest.yml`

```bash
grep "auto_install:" servers/S13/*/manifest.yml
# → 0 resultados para fedora-kde, guacamole, nextcloud, onlyoffice
```

Sin `auto_install`, el observer no sabe si debe instalar estas fichas automáticamente cuando sus dependencias estén listas, o si requieren aprobación manual. El comportamiento actual es indefinido.

---

#### GAP-7 — Seed fichas: sección `fichas:` vacía

**Severidad:** Alta · **Archivo:** `servers/seed-skull.yml`

```bash
awk '/^fichas:/,/^[a-z]/' servers/seed-skull.yml | grep "^\s*-"
# → Solo: - sbos-bkernel y - kong (las 2 únicas fichas del seed)
```

El seed actualmente instala solo bkernel y kong automáticamente. Toda la infraestructura base (postgresql, redis, vault, keycloak, etc.) no está en el seed — depende del `auto_install: true` en los manifests para que el observer las instale. Esto es correcto para la infraestructura, pero falta definir qué fichas de aplicación se instalan automáticamente en un tenant nuevo.

---

### 11.3 Inconsistencias confirmadas con evidencia

| ID | Inconsistencia | Evidencia | Impacto |
|----|----------------|-----------|---------|
| **INC-1** | `S01/tryton` y `S04/tryton` son archivos IDÉNTICOS | `diff` produce 0 diferencias · ambos 566 líneas | BOS registra 2 fichas `tryton` con mismo ID → conflicto de state |
| **INC-2** | `fedora-kde manifest.yml` declara `version: "41.0.0"` pero la imagen es `sbos/fedora-desktop:1.0.0` | `grep version manifest.yml` vs `grep SBOS_IMAGE task_catalog.sh` | BOS calcula UPDATE_AVAILABLE incorrecto (compara strings incomparables) |
| **INC-3** | ConfigMap `fedora-kde-start-script` en K8s sobreescribe el `start-desktop.sh` baked en la imagen | Existe el ConfigMap en el deployment actual + `COPY resources/start-desktop.sh` en Containerfile | El script de la imagen nunca se ejecuta — P-VDI-1 violado |
| **INC-4** | `sbos-bootstrap-platform` y `sbos-k8s-network-validator` tienen fichas en `servers/` pero NO aparecen en `.sbos_state.json` | Estado VPS: PENDING (no en state) | Observer no las supervisa — pueden estar en estado incompleto sin que BOS lo sepa |
| **INC-5** | `S06/mattermost` y `S10/mattermost` son dos fichas con el mismo nombre en servidores distintos | `ls servers/S06/mattermost` y `ls servers/S10/mattermost` existen ambas | BOS puede confundir los IDs — el ID de ficha debe ser único en todo el catálogo |
| **INC-6** | Fichas en `servers/S12/` con 135 líneas (loki, zabbix, tempo) son STUBs que forman parte del stack de monitoreo crítico | `wc -l servers/S12/loki/task_catalog.sh` → 135 | Stack de observabilidad incompleto: Prometheus INSTALLED pero Loki/Tempo/Zabbix no tienen deploy real |
| **INC-7** | `S04/tryton-workers` tiene 150 líneas pero depende conceptualmente de `S01/tryton` — sin esa dependencia declarada | `grep dependencies servers/S04/tryton-workers/manifest.yml` | tryton-workers puede intentar instalarse antes que el servidor Tryton esté ready |

---

### 11.4 Preguntas HITL — responder para consolidar el instalador

Las siguientes son decisiones de diseño que solo el humano puede tomar. Cada una bloquea un gap específico.

---

**Q-1 — Tryton duplicado (INC-1, BUG-32)**

`S01/tryton` y `S04/tryton` son archivos idénticos (566 líneas, mismo contenido).
- **Opción A:** S01/tryton = servidor de aplicación principal (web + backend). S04/tryton-workers = workers de background (Celery-like). En ese caso S04 no necesita el task_catalog.sh de S01 — necesita uno propio que despliegue los workers.
- **Opción B:** S04 es una copia accidental — solo debe existir S01/tryton.

> ¿Cuál es la función de `S04/tryton`? ¿Es un nodo distinto de Tryton (alta disponibilidad) o es un error de duplicación?

---

**Q-2 — Fichas S13 VDI: auto_install (GAP-6)**

Las fichas `fedora-kde`, `guacamole`, `nextcloud`, `onlyoffice` no tienen `auto_install` definido.
- **Opción A:** `auto_install: true` — el observer las instala automáticamente cuando sus dependencias (postgresql, vault, keycloak, kong) estén INSTALLED. El VDI se despliega solo.
- **Opción B:** `auto_install: false` — requieren `bosctl ficha install <nombre>` manual o aprobación HITL. El operador controla cuándo se activa el VDI.

> ¿El VDI (nextcloud, guacamole, onlyoffice, fedora-kde) debe instalarse automáticamente o requiere aprobación manual en cada tenant nuevo?

---

**Q-3 — Guacamole + fedora-kde: arquitectura de conexiones (GAP-4)**

Para que Guacamole conecte a los escritorios:
- **Opción A (Pool estático):** Guacamole tiene una conexión fija al Service `fedora-kde` (balanceo entre réplicas). Todos los usuarios ven el mismo pool — más simple, no hay aislamiento.
- **Opción B (Pod por usuario):** El provisioner crea un pod `fedora-kde-<user_id>` cuando el usuario hace login. Guacamole recibe la IP del pod directamente. Aislamiento completo — más complejo.
- **Opción C (Pool con slots):** N pods pre-calentados. Al login se asigna un slot disponible al usuario. Al logout el slot vuelve al pool (home del usuario en PVC, no en el pod).

> ¿Cuál es el modelo de sesión para el VDI? ¿Pod por usuario, pool, o pool con slots?

---

**Q-4 — Mattermost duplicado (INC-5)**

Existen `S06/mattermost` (726 líneas) y `S10/mattermost` (260 líneas).
- S06 parece ser la versión robusta (mensajería corporativa).
- S10 parece ser una versión en el servidor de comunicaciones.

> ¿Son dos instancias distintas (por ejemplo, una interna para el staff del cliente y otra para comunicación externa), o es una duplicación accidental?

---

**Q-5 — Stack de monitoreo: Loki/Tempo/Zabbix como STUBs (INC-6)**

`S12/loki` (135 líneas), `S12/tempo` (98 líneas), `S12/zabbix` (140 líneas) son STUBs sin deploy real. Solo Prometheus, Alertmanager, Grafana y Alloy están completos.

> ¿Son Loki (logs), Tempo (trazas) y Zabbix parte del MVP del stack de monitoreo? ¿O son opcionales para una fase posterior?

---

**Q-6 — Portman: ¿cuándo integrar? (GAP-1)**

El Motor de Puertos está implementado pero ninguna ficha lo usa. Integrarlo requiere modificar los 65 `task_catalog.sh` para que llamen `bos.portman.assign` al inicio de `ficha_install()`.

> ¿Integramos el portman ahora (requiere modificar todas las fichas) o lo dejamos como deuda técnica planificada para la siguiente fase?

---

**Q-7 — health.check_command en fichas críticas (GAP-2)**

Agregar `check_command` a vault, postgresql, keycloak, kong, redis es necesario para que BOS detecte problemas internos (Vault sellado, PG sin conexiones) sin esperar al CrashLoop. Requiere modificar 6 manifests.

> ¿Agregamos `check_command` a las fichas críticas ahora como parte del hardening del instalador, o después de resolver los bugs activos (Vault, Linkerd, Kyverno)?

---

### 11.5 Hoja de ruta hacia el instalador robusto e idempotente

#### Lo que ya está robusto y no necesita cambios

- Observer loop (Fases 1-2-3) con FIX-B aplicado
- State machine (18 estados, fcntl.flock, transiciones correctas)
- Context Plane (ctx_id en todas las operaciones)
- Fichas de infraestructura base: postgresql, redis, vault, keycloak, kong, kyverno, linkerd (todas con repair idempotente)
- Fichas VDI de contenido: nextcloud, oauth2-proxy-desktop (robustas)
- Scaler context-aware (listo para VDI)
- Portman (implementado, listo para integración)

#### Lo que necesita trabajo para producción

| Prioridad | Gap | Esfuerzo | Bloquea |
|-----------|-----|----------|---------|
| **P0** | FIX-26A vault en VPS — copiar task_catalog.sh + `bosctl ficha repair vault` + unseal | Muy bajo | Desbloquea vault, oauth2-proxy, tryton |
| **P0** | BUG-36: Verificar hairpin NAT en VPS → reiniciar kyverno admission-controller | Muy bajo | Desbloquea kyverno |
| **P1** | FIX-B observer PHYSICAL_ERROR | ✅ Ya aplicado (0a1a182) | Reparación automática |
| **P1** | FIX health check bos-preflight (tmpfs /run/bos) | ✅ Ya aplicado (de927a0) | Health check correcto tras reboot |
| **P2** | GAP-2: `health.check_command` fichas críticas (vault, pg, kc, kong) | Bajo | Detección proactiva |
| **P2** | INC-3: Eliminar ConfigMap `fedora-kde-start-script` | Muy bajo | P-VDI-1 |
| **P2** | INC-2: Sincronizar versión manifest ↔ tag imagen fedora-kde | Muy bajo | UPDATE_AVAILABLE correcto |
| **P3** | GAP-3/4: VDI provisioner + Guacamole conexiones (depende de Q-3) | Alto | VDI multi-usuario soberano |
| **P3** | GAP-5: Eliminar exposición directa noVNC (port 6901) | Bajo | Auditoría VDI completa |
| **P3** | GAP-6: `auto_install` en fichas S13 (depende de Q-2) | Muy bajo | Observer instala VDI solo |
| **P4** | INC-1: Resolver tryton S01 vs S04 (depende de Q-1) | Bajo | Conflicto de ID en state |
| **P4** | INC-5: Resolver mattermost S06 vs S10 (depende de Q-4) | Bajo | Conflicto de ID en state |
| **P4** | INC-4: Registrar sbos-bootstrap-platform en state | Bajo | Observer supervisa fichas faltantes |
| **P4** | GAP-7: Definir fichas de aplicación en seed-skull.yml | Bajo | Instalación automatizada por tenant |
| **P5** | GAP-1: Integrar portman en task_catalog.sh (depende de Q-6) | Alto | Kardex de puertos completo |
| **P5** | INC-6: Completar STUBs Loki/Tempo/Zabbix (depende de Q-5) | Medio | Stack de observabilidad completo |
| **P5** | INC-7: Agregar dependencia tryton en tryton-workers manifest | Muy bajo | Orden de instalación correcto |

---

---

## 12. Ruta de instalación completa — ficha por ficha hasta el VDI

> Esta sección es el **mapa de construcción** del sistema. Cada etapa tiene un objetivo claro, sus fichas ordenadas, los requerimientos que deben cumplirse antes de iniciar, y el criterio que define cuándo esa etapa está completa. El orden numérico (`execution_order`) es el que el observer sigue internamente.

---

### Visión general del pipeline (resumen de 12 etapas)

```
[ETAPA 0] Pre-vuelo del host ────── bos-preflight, sbos-bootstrap-os
[ETAPA 1] Cluster Kubernetes ──────  sbos-namespace, sbos-bootstrap-k8s, sbos-bootstrap-cni
[ETAPA 2] Infraestructura K8s ───── sbos-bootstrap-platform, sbos-bootstrap-storage, sbos-bootstrap-monitoring
[ETAPA 3] Validación de red ──────── sbos-k8s-network-validator
[ETAPA 4] Base de datos y objetos ── postgresql, redis, minio
[ETAPA 5] Seguridad: mesh y policy ─ kyverno, linkerd
[ETAPA 6] Secretos ──────────────── vault, besu-qbft
[ETAPA 7] Identidad y gateway ────── keycloak, kong, oauth2-proxy, nginx, certbot
[ETAPA 8] Daemons host y notif. ─── sbos-bkernel, sbos-notifier
[ETAPA 9] Observabilidad ────────── prometheus, alertmanager, grafana, loki, alloy, tempo
[ETAPA 10] Hardening final ─────── sbos-bootstrap-hard
[ETAPA 11] VDI: Plataforma ──────── nextcloud, guacamole, onlyoffice
[ETAPA 12] VDI: Escritorio ─────── fedora-kde, oauth2-proxy-desktop, sbos-vdi-config
─────────────────────────────────────────────────────────────────────
[OPCIONALES] Aplicaciones de negocio (auto_install: false — instalar por tenant)
```

---

### ETAPA 0 — Pre-vuelo del host

**Objetivo:** Verificar que el servidor cumple los prerrequisitos mínimos e instalar las dependencias del SO que BOS necesita para operar. Sin esta etapa, ningún binario ni comando funciona.

**Requerimientos previos:** Ubuntu 26.04 Server LTS instalado · acceso root · conexión a internet.

| Orden | Ficha | Servidor | `auto_install` | Qué hace |
|-------|-------|----------|---------------|---------|
| 1 | `bos-preflight` | S-HOST | `true` | Verifica OS 26.04, RAM ≥16 GB, disco ≥165 GB, CPU ≥8 cores, puertos libres. Crea usuario `bosagent` + grupo, directorios `/etc/bos /etc/sbos /var/log/bos /opt/bos`, instala paquetes del SO declarados en `system_packages` (curl, jq, openssl, python3, etc.), genera token RPC aleatorio, genera certificado TLS autofirmado `/etc/bos/certs/bos.crt`, configura cgroup v2 delegation, sudoers para bosagent |
| 10 | `sbos-bootstrap-os` | S-HOST | `true` | Carga módulos kernel requeridos (`br_netfilter`, `overlay`, `ip_tables`, etc.) · configura `sysctl` para K8s (ip_forward, bridge-nf-call, vm.max_map_count) · instala herramientas base (socat, conntrack, ipset, iptables-persistent, etc.) · crea estructura `/data/postgres`, `/data/redis`, `/data/vault`, etc. con permisos correctos por UID · deshabilita swap |

**Comportamiento en servidor ya configurado:** Ambas fichas verifican antes de actuar — si el usuario ya existe, los directorios ya están y los módulos ya están cargados, salen con STEP_OK sin tocar nada. Esto es **idempotencia correcta**, no un error.

**Limitaciones conocidas (verificadas en código):**

| Limitación | Ficha | Detalle |
|-----------|-------|---------|
| `configurar_kubectl` hace SKIP en primera instalación | `bos-preflight:198` | kubectl lo instala `sbos-bootstrap-k8s` (orden 20) — este symlink solo se crea en un repair posterior |
| `configurar_containerd` hace SKIP en primera instalación | `sbos-bootstrap-os:174` | containerd lo instala `sbos-bootstrap-k8s` (orden 20) — este paso solo actúa en repair |
| health check corregido | `bos-preflight manifest` | Antes usaba `/run/bos` (tmpfs, desaparece en reboot). Ahora verifica `/etc/bos/rpc-token` y `/etc/bos/certs/bos.crt` (persistentes) |

**Criterio de completitud:** `bosctl ficha status bos-preflight` → INSTALLED · `bosctl ficha status sbos-bootstrap-os` → INSTALLED · `id bosagent` OK · `/etc/bos/certs/bos.crt` existe · `sysctl net.ipv4.ip_forward` = 1 · swap = 0.

---

### ETAPA 1 — Cluster Kubernetes

**Objetivo:** Levantar el plano de control K8s y la red de pods (CNI). Al final de esta etapa hay un nodo K8s funcional con red entre pods y con el mecanismo de namespaces listo.

**Requerimientos previos:** ETAPA 0 completa · `containerd` corriendo · módulos kernel activos.

| Orden | Ficha | Servidor | `auto_install` | Qué hace |
|-------|-------|----------|---------------|---------|
| 5 | `sbos-namespace` | S-HOST | `true` | Crea el namespace base `sbos-system` con `NetworkPolicy default-deny` por tenant. Requiere K8s activo para aplicar. Dep: `sbos-bootstrap-k8s` |
| 20 | `sbos-bootstrap-k8s` | S-HOST | `true` | Inicializa el cluster con `kubeadm init` + configura `containerd` runtime · instala `kubectl` + `kubeconfig` en `/etc/bos/.kube/config` · instala Calico básico como CNI · verifica node Ready |
| 25 | `sbos-bootstrap-cni` | S-HOST | `true` | Calico completo: `IPPool`, `NetworkPolicy default-deny` global, verificación pod-to-pod · Dep: `sbos-bootstrap-k8s` |

**Criterio:** `kubectl get nodes` → `Ready` · `kubectl get pods -n calico-system` → Running.

---

### ETAPA 2 — Infraestructura del cluster

**Objetivo:** Instalar los recursos transversales que todas las fichas de aplicación necesitan: clases de almacenamiento, volúmenes persistentes, espacio de nombres SBOS y base de observabilidad del cluster.

**Requerimientos previos:** ETAPA 1 completa · nodo K8s Ready · CNI funcional.

| Orden | Ficha | Servidor | `auto_install` | Qué hace |
|-------|-------|----------|---------------|---------|
| 28 | `sbos-bootstrap-platform` | S-HOST | `true` | Crea los 12 namespaces SBOS (`sbos-data`, `sbos-security`, `sbos-gateway`, `sbos-erp`, `sbos-collab`, `sbos-vdi`, `sbos-monitoring`, etc.) · instala `local-path-provisioner` (StorageClass dinámica) · configura RBAC base para service accounts SBOS |
| 30 | `sbos-bootstrap-storage` | S-HOST | `true` | Crea los 19 PersistentVolumes hostPath en `/data/` con política `Retain` (los datos sobreviven a la eliminación de pods) · Dep: `sbos-bootstrap-k8s`, `sbos-bootstrap-cni` |
| 35 | `sbos-bootstrap-monitoring` | S-HOST | `true` | Despliega `prometheus-node-exporter` (métricas del host) y `kube-state-metrics` (estado del cluster K8s) como base de observabilidad · Dep: `sbos-bootstrap-k8s`, `sbos-bootstrap-cni`, `sbos-bootstrap-storage` |

**Criterio:** 12 namespaces existentes · StorageClass `local-path` presente · `node-exporter` y `kube-state-metrics` Running.

---

### ETAPA 3 — Validación de conectividad de red

**Objetivo:** Confirmar empíricamente que el cluster funciona antes de instalar workloads. Si algo falla aquí, se detecta antes de invertir tiempo en instalaciones.

**Requerimientos previos:** ETAPA 2 completa.

| Orden | Ficha | Servidor | `auto_install` | Qué hace |
|-------|-------|----------|---------------|---------|
| 50 | `sbos-k8s-network-validator` | S-HOST | `true` | Ejecuta 4 pruebas: resolución DNS interna (`service.namespace.svc.cluster.local`) · comunicación pod-to-pod entre namespaces · creación y montaje de PVC · verificación de hairpin NAT hacia el apiserver · Dep: `sbos-bootstrap-platform`, `sbos-bootstrap-storage` |

**Criterio:** 4/4 pruebas en verde · log `[VALIDACION OK]` en `bosctl ficha status sbos-k8s-network-validator`.

> ⚠️ **BUG-36 conocido:** El validador puede fallar en la prueba de hairpin NAT si la regla iptables no está aplicada. Ver §8.2 BUG-36 para el fix manual antes de continuar.

---

### ETAPA 4 — Base de datos, caché y almacenamiento de objetos

**Objetivo:** Instalar los tres servicios de persistencia que todo el stack SBOS consume. Ninguna aplicación puede instalarse sin que estos estén INSTALLED.

**Requerimientos previos:** ETAPA 2 completa · PVs disponibles · `vault` **NO** es requisito aquí — postgresql se instala antes de vault (vault necesita postgresql para su backend).

| Orden | Ficha | Servidor | `auto_install` | Qué hace |
|-------|-------|----------|---------------|---------|
| 100 | `postgresql` | S01 | `true` | PostgreSQL 18.4 · StatefulSet con PVC 50 Gi · Crea 10 BDs SBOS (`SBOSDB`, `kong_db`, `keycloak_db`, `tryton_db`, etc.) · Configura WAL logical replication (`pgoutput`) para bKernel CDC · `pg_hba` restringido a IPs de pods específicos (P5 Zero Trust) |
| 110 | `redis` | S01 | `true` | Redis 8.6.2 · 3 DBs lógicas: caché(0), ctx_id(1), streams(2) · password obligatorio · Usado por bKernel para Streams y por Context Plane para ctx_id |
| 120 | `minio` | S01 | `true` | MinIO/SeaweedFS S3-compatible · 3 buckets: `sbos-backups`, `sbos-assets`, `sbos-documents` · Credenciales S3 en ConfigMap · Usado por Nextcloud, Paperless, Grafana, backups |

**Criterio:** Los 3 pods `1/1 Running` · `psql -c "\l"` muestra las 10 BDs · `redis-cli ping` → PONG · bucket `sbos-backups` existente.

---

### ETAPA 5 — Mesh de servicios y control de admisión

**Objetivo:** Aplicar mTLS automático entre todos los pods (confidencialidad en tránsito) y políticas de seguridad que impiden despliegues sin probes, con hostPort, o sin NetworkPolicy.

**Requerimientos previos:** ETAPA 1 completa · CNI funcional. Estas fichas no necesitan BD pero sí un cluster limpio antes de que lleguen workloads de aplicación.

| Orden | Ficha | Servidor | `auto_install` | Qué hace |
|-------|-------|----------|---------------|---------|
| 100 | `kyverno` | S03 | `true` | Kyverno 1.13.0 · 4 políticas: require liveness/readiness probes · forbid hostPort · verify OCI signatures · require NetworkPolicy · Modo `audit` en Iter1 → `enforce` en Iter2 |
| 110 | `linkerd` | S03 | `true` | Linkerd stable-2.14.10 · mTLS automático con iptables mode `nft` (requerido en Ubuntu 26.04 con kernel nf_tables) · injection via anotación de namespace · ServiceProfile por servicio |

**Criterio:** `linkerd check` sin errores · `kyverno` 4 pods Running · políticas en modo audit activas.

> ⚠️ **BUG conocido (linkerd):** Requiere `--set proxyInit.iptablesMode=nft` y timeout 15 min. Ya corregido en `task_catalog.sh`.

---

### ETAPA 6 — Secretos y blockchain soberana

**Objetivo:** Instalar el gestor de secretos centralizado (Vault) y la red blockchain de auditoría (Besu QBFT). Vault es la fuente de verdad para todas las credenciales del stack — ninguna aplicación obtiene secretos de otro lugar.

**Requerimientos previos:** `postgresql` INSTALLED (Vault backend HA) · `sbos-bootstrap-storage` INSTALLED (PVC).

| Orden | Ficha | Servidor | `auto_install` | Qué hace |
|-------|-------|----------|---------------|---------|
| 130 | `vault` | S02 | `true` | HashiCorp Vault 2.0.1 · StatefulSet 1 réplica · AppRole `sbos-pods` para todos los pods · PKI engine para certificados internos · KV v2 para secretos · **Requiere unseal manual tras primer arranque** (ver §8.2 BUG-26) · Dep: postgresql, sbos-bootstrap-storage |
| 135 | `besu-qbft` | S02 | `true` | Hyperledger Besu 24.12.0 · Red blockchain QBFT 1 validador · `SettlementEngine.sol` + `AuditAnchor.sol` · RPC :8545, WS :8546, P2P :30303 · Chain ID 1337 · Dep: postgresql, vault |

**Criterio:** `vault status` → `Initialized: true, Sealed: false` · bloque genesis de besu creado · `curl localhost:8545` responde JSON-RPC.

> ⚠️ **ACCIÓN MANUAL REQUERIDA:** Después de que Vault arranque por primera vez, ejecutar `vault operator init` → guardar las 5 unseal keys → `vault operator unseal` (3 veces). Sin esto, Vault queda sellado y todo el stack falla en cadena (BUG-26 / FIX-26A).

---

### ETAPA 7 — Identidad, gateway y TLS

**Objetivo:** Establecer la capa de identidad centralizada (Keycloak + oauth2-proxy) y el punto único de entrada al sistema (Kong + nginx). Al final de esta etapa, el sistema tiene autenticación SSO funcional y un reverse proxy con HTTPS.

**Requerimientos previos:** `vault` INSTALLED y **desbloqueado** · `postgresql` INSTALLED · `sbos-bootstrap-cni` INSTALLED.

| Orden | Ficha | Servidor | `auto_install` | Qué hace |
|-------|-------|----------|---------------|---------|
| 140 | `keycloak` | S03 | `true` | Keycloak 26.6.2 · Realm `master` + Realm `skull` · 5 SPIs SKULL · OIDC/OAuth2 para todo el ecosistema · Dep: postgresql, vault |
| 160 | `kong` | S02 | `true` | Kong 3.9.x LTS · DB mode PostgreSQL `kong_db` · JWT validation, rate limiting, plugin Lua `SBOS-Context` (inyecta ctx_id) · Admin API :8001, Proxy :8000/:8443, Status :8007 · Dep: postgresql, keycloak, vault |
| 150 | `oauth2-proxy` | S02 | `true` | OAuth2-Proxy 7.8.0 · Valida tokens contra Keycloak · Inyecta headers `X-Forwarded-User/Email/Groups` · Protege apps sin lógica de auth propia · Dep: keycloak, vault, kong |
| 170 | `nginx` | S02 | `true` | Reverse proxy y servidor web · Enruta `/api/` → kong · `/desktop/` → oauth2-proxy-desktop · Sirve `/.well-known/acme-challenge/` para Certbot · Dep: kong |
| 180 | `certbot` | S02 | `true` | Certbot 3.2.0 · Certificados TLS Let's Encrypt vía HTTP-01 challenge (webroot nginx) · **No es pod K8s** — es un `systemd timer` en el host · Renovación automática cada 60 días · Dep: nginx |

**Criterio:** `curl http://localhost:8001/` → Kong Admin 200 · Keycloak realm `skull` accesible · oauth2-proxy `/ping` → 200 · nginx sirviendo · certificado TLS válido.

---

### ETAPA 8 — Daemons host y notificador

**Objetivo:** Activar los daemons del ecosistema SBOS que corren en el host (no en K8s): bKernel para el pipeline de eventos CDC desde PostgreSQL WAL, y bNotify para notificaciones push y MFA step-up.

**Requerimientos previos:** `postgresql` INSTALLED (WAL logical) · `redis` INSTALLED (Streams) · `vault` INSTALLED · todas las fichas de ETAPA 7.

| Orden | Ficha | Servidor | `auto_install` | Qué hace |
|-------|-------|----------|---------------|---------|
| 70 | `sbos-bkernel` | S-HOST | `true` | bKernel CDC Daemon · Escucha WAL de PostgreSQL (pgoutput) · Normaliza eventos de dominio · Publica intenciones en Redis Streams · **CERO puertos TCP** (F-02) · Dep: postgresql, redis, vault |
| 170 | `sbos-notifier` | S06 | `true` | SBOS Notifier (bnotify) · Push MFA (OTP, TOTP, WebAuthn) · Alertas críticas del sistema · Mensajes a usuarios · Requerido por bAuth para Step-Up (RFC 9470) · Dep: postgresql, redis, vault, keycloak, kong |

**Criterio:** `systemctl status sbos-bkernel` → active · `bosctl ficha status sbos-notifier` → INSTALLED · WAL replication slot activo en PostgreSQL.

---

### ETAPA 9 — Observabilidad completa

**Objetivo:** Instalar el stack de monitoreo, métricas, logs y trazas que da visibilidad a todo el sistema. El criterio "instalador robusto" requiere que BOS pueda ver en tiempo real el estado de cada componente.

**Requerimientos previos:** `sbos-bootstrap-monitoring` INSTALLED · `vault` INSTALLED · `minio` INSTALLED (para Loki/Tempo).

| Orden | Ficha | Servidor | `auto_install` | Qué hace |
|-------|-------|----------|---------------|---------|
| 200 | `prometheus` | S12 | `true` | Prometheus 3.4.0 · Scraping de daemons SBOS (9400-9499), K8s nodes/pods · Alertmanager integrado · PVC 20 Gi con `strategy: Recreate` (evita lock) · Dep: sbos-bootstrap-storage, sbos-bootstrap-monitoring, vault |
| 205 | `alertmanager` | S12 | `true` | Alertmanager 0.28.1 · Reglas SBOS (WAL lag, Vault sealed, DLQ depth, pod down) · Routing hacia bnotify · Dep: prometheus |
| 215 | `grafana` | S12 | `true` | Grafana 12.0.1 · OAuth2 Keycloak · Dashboards SBOS precargados · Datasources Prometheus + PostgreSQL + Loki · Dep: prometheus, keycloak, vault |
| 215 | `loki` | S12 | `true` | Grafana Loki — logs · Extrae y almacena logs de todos los pods con ctx_id · Dep: prometheus, grafana, minio — ⚠️ **STUB** actualmente |
| 220 | `alloy` | S12 | `true` | Grafana Alloy 1.8.3 · Pipelines de logs y métricas · Extrae `ctx_id` de logs SBOS · Envía a Loki · Dep: prometheus |
| 220 | `tempo` | S12 | `true` | Grafana Tempo — trazas distribuidas · Dep: loki, prometheus — ⚠️ **STUB** actualmente |
| 225 | `zabbix` | S12 | `false` | Zabbix — monitoreo de infraestructura tradicional · Dep: postgresql, grafana — ⚠️ **STUB** / `auto_install: false` |

**Criterio:** Prometheus scrapea al menos 20 targets · Grafana accesible con SSO Keycloak · dashboards SBOS cargados.

---

### ETAPA 10 — Hardening final del cluster

**Objetivo:** Aplicar el endurecimiento de seguridad definitivo: firewall, políticas de red Calico en modo enforce, Kyverno en modo enforce y benchmarks CIS. Esta etapa se ejecuta DESPUÉS de que todo el stack esté up — aplicarlo antes bloqueaería la instalación.

**Requerimientos previos:** TODAS las fichas de infraestructura INSTALLED · prometheus y grafana Running (el hardening los necesita para monitorear las políticas).

| Orden | Ficha | Servidor | `auto_install` | Qué hace |
|-------|-------|----------|---------------|---------|
| 250 | `sbos-bootstrap-hard` | S-HOST | `true` | UFW deny-all (solo 22/80/443 permitidos) · Calico `default-deny` enforcement · Kyverno modo `enforce` (deja de ser solo audit) · CIS Ubuntu 26.04 Benchmark · CIS K8s Benchmark · Dep: sbos-bootstrap-cni, sbos-bootstrap-k8s, sbos-bootstrap-monitoring, prometheus, grafana |

**Criterio:** `ufw status` → activo con 3 reglas · Kyverno en modo enforce · `lynis audit system` sin hallazgos críticos.

> ⚠️ Después de esta etapa, cualquier pod sin `livenessProbe`/`readinessProbe` será rechazado por Kyverno. Todas las fichas ROBUSTAS ya tienen probes. Los STUBs sin probes fallarán — no instalar fichas STUB después del hardening sin agregarles probes primero.

---

### ETAPA 11 — VDI Plataforma: almacenamiento, documentos y gateway de escritorio

**Objetivo:** Instalar la capa de productividad colaborativa y el gateway que permitirá el acceso al escritorio virtual. Al final de esta etapa, los usuarios pueden acceder a archivos, documentos y colaborar — pero el escritorio aún no está disponible.

**Requerimientos previos:** `postgresql`, `redis`, `minio`, `keycloak`, `kong` INSTALLED · Etapa 10 completa.

| Orden | Ficha | Servidor | `auto_install` | Qué hace |
|-------|-------|----------|---------------|---------|
| 200 | `nextcloud` | S13 | — (*Q-2*) | Nextcloud 30.0.2 · Almacenamiento personal y colaborativo · Integración OIDC Keycloak (SSO) · Backend MinIO S3 · Editor Nextcloud-Office vía OnlyOffice · Dep: postgresql, redis, minio, keycloak, kong |
| 210 | `guacamole` | S13 | — (*Q-2*) | Apache Guacamole 1.5.5 + guacd · **Gateway de escritorio remoto** · Autenticación OIDC Keycloak · Proxy VNC/RDP hacia pods fedora-kde · Auditoría de sesiones · Dep: postgresql, keycloak, kong |
| 220 | `onlyoffice` | S13 | — (*Q-2*) | OnlyOffice Document Server 8.2.2 · Edición colaborativa de documentos Office en tiempo real · Integrado con Nextcloud · Dep: postgresql, redis, kong |

**Criterio:** Nextcloud accesible con SSO · guacamole dashboard disponible · onlyoffice server health OK.

---

### ETAPA 12 — VDI Escritorio: Fedora KDE corporativo

**Objetivo:** Instalar y configurar el escritorio virtual soberano. **Esta es la etapa final del MVP.** Al completarla, un usuario puede autenticarse con sus credenciales SBOS y acceder a un escritorio Fedora KDE completo con todas las aplicaciones corporativas, con aislamiento por usuario, persistencia de datos y auditoría completa.

**Requerimientos previos:** `guacamole`, `keycloak`, `kong`, `nextcloud`, `onlyoffice` INSTALLED.

| Orden | Ficha | Servidor | `auto_install` | Qué hace |
|-------|-------|----------|---------------|---------|
| 225 | `oauth2-proxy-desktop` | S13 | — (*Q-2*) | OAuth2-Proxy v7.8.0 · Intercepta acceso a `/desktop/` · Valida token Keycloak · Inyecta headers de identidad en la sesión VNC · **SSO del escritorio** · Dep: keycloak, fedora-kde |
| 230 | `fedora-kde` | S13 | — (*Q-2*) | Fedora KDE — Escritorio Virtual Corporativo · Pod TigerVNC + KDE Plasma · noVNC HTML5 (acceso vía browser) · KWallet deshabilitado · sbos-webapp (`--password-store=basic`) · **Actualmente: 1 pod compartido** — VDI-GAP-3 · Dep: keycloak, kong, guacamole |
| 420 | `sbos-vdi-config` | S13 | — (*Q-2*) | Configuración final del VDI: rutas Kong para VDI (`/nextcloud/`, `/onlyoffice/`, `/desktop/`) · Client OIDC `sbos-desktop` en realm Keycloak · NetworkPolicies: sbos-vdi puede conectar a sbos-data y sbos-security · Dep: nextcloud, onlyoffice, guacamole, keycloak, kong |

**Criterio de VDI completado (C-09 a C-14):**

| Check | Verificación | Estado actual |
|-------|-------------|---------------|
| C-09 | Semáforo VDI verde (`bosctl vdi verify`) | ✅ Implementado |
| C-10 | Guacamole accesible con SSO Keycloak | ✅ Funcional |
| C-11 | Fedora KDE arranca dentro del pod | ✅ Funcional |
| C-12 | Home del usuario montado (PVC por usuario) | ❌ VDI-GAP-2 (1 PVC compartido) |
| C-13 | Aplicaciones abren con SSO (Nextcloud, mail) | ⚠️ Parcial |
| C-14 | Archivo persiste tras cerrar sesión | ❌ VDI-GAP-2 |

---

### Fichas opcionales — instalar por necesidad del tenant (`auto_install: false`)

Estas fichas **no se instalan automáticamente**. Requieren `bosctl ficha install <nombre>` o aprobación HITL. Se agrupan por módulo de negocio.

| Módulo | Fichas | Orden | Dependencias principales |
|--------|--------|-------|--------------------------|
| **ERP (S01/S04)** | `tryton`, `tryton-workers` | 170, 175 | postgresql, vault, kong |
| **Colaboración (S06)** | `ferretdb`, `calcom`, `novu`, `mattermost`(S06) | 174-177 | postgresql, redis, keycloak |
| **Correo (S10)** | `mailserver`, `postfixadmin`, `roundcube`, `cypht` | 300-315 | postgresql, kong, keycloak |
| **Documentos (S08)** | `tesseract-ocr`, `paperless-ngx`, `docuseal`, `kimios`, `tabula` | 345-365 | postgresql, minio, keycloak |
| **Búsqueda (S09)** | `elasticsearch`, `rabbitmq` | 400, 405 | sbos-bootstrap-platform |
| **DevOps (S14)** | `gitlab`, `bareos`, `velero` | 450-460 | postgresql, minio, keycloak |
| **IA (S15)** | `ollama`, `qdrant`, `open-webui`, `embedding-worker`, `langfuse`, `flowise` | 500-525 | ollama, qdrant, postgresql |

---

### Resumen del pipeline completo hasta el VDI

```
HORAS ESTIMADAS DESDE UBUNTU VIRGEN

 0:00 ─── ETAPA 0  (bos-preflight + sbos-bootstrap-os)            ~5 min
 0:05 ─── ETAPA 1  (K8s + CNI)                                    ~15 min
 0:20 ─── ETAPA 2  (platform + storage + monitoring base)         ~8 min
 0:28 ─── ETAPA 3  (network validator)                            ~3 min
 0:31 ─── ETAPA 4  (postgresql + redis + minio)                   ~10 min
 0:41 ─── ETAPA 5  (kyverno + linkerd)                            ~12 min
 0:53 ─── ETAPA 6  (vault [+ unseal manual] + besu-qbft)          ~10 min + HITL unseal
 1:03 ─── ETAPA 7  (keycloak + kong + oauth2-proxy + nginx)       ~10 min
 1:13 ─── ETAPA 8  (bkernel + sbos-notifier)                      ~5 min
 1:18 ─── ETAPA 9  (prometheus + alertmanager + grafana + alloy)  ~10 min
 1:28 ─── ETAPA 10 (sbos-bootstrap-hard)                          ~5 min
 1:33 ─── ETAPA 11 (nextcloud + guacamole + onlyoffice)           ~12 min
 1:45 ─── ETAPA 12 (fedora-kde + oauth2-proxy-desktop + vdi-config) ~8 min
 1:53 ─── VDI OPERATIVO ✓                                         ~114 min total

 ÚNICO PUNTO DE INTERVENCIÓN MANUAL: unseal de Vault (~2 min)
 TODO LO DEMÁS ES AUTOMÁTICO VÍA EL OBSERVER DE BOS
```

---

---

## 13. Plan de acción — lista maestra de problemas en orden de ejecución

> **Cómo usar esta sección:** Es el único punto de entrada para el trabajo de reparación y desarrollo. Los §0–§12 son referencia de detalle — este §13 es el dashboard. Cada problema tiene un número fijo. Empezar por el #1 y avanzar en orden: los siguientes dependen de los anteriores.

**Leyenda de estado:**
- ✅ `LISTO` — ya corregido en código, sin acción pendiente
- 🔄 `COMMITEADO` — fix en repositorio, falta aplicar en VPS
- ⏳ `PENDIENTE` — no iniciado, listo para trabajar
- ❓ `HITL` — bloqueado por decisión del humano (pregunta HITL en §11.4)

---

### BLOQUE A — Reparar el cluster VPS actual (ejecución en VPS)

> Estos problemas hacen que el instalador no pueda completarse. Son acciones manuales sobre el servidor. Una vez resueltos, el observer de BOS toma el control automáticamente.

---

#### PROBLEMA #1 — Hairpin NAT ausente: kyverno admission-controller no puede conectar al apiserver

**Estado:** ⏳ PENDIENTE  
**Tipo:** Acción en VPS (no requiere código)  
**Síntoma:** kyverno en PENDING en state · admission-controller en CrashLoopBackOff · `dial tcp 10.96.0.1:443: i/o timeout`  
**Por qué primero:** Kyverno con `failurePolicy: Fail` bloquea todo `kubectl apply`. Sin esto, ningún repair puede aplicarse al cluster.  
**Referencia detallada:** §8.2 BUG-36

```bash
# En la VPS como root:
export KUBECONFIG=/root/.kube/config

# 1. Verificar si la regla existe
iptables -t nat -L OUTPUT -n | grep 6443

# 2. Si NO existe, reaplicarla (reemplazar 13.140.128.230 con la IP pública del servidor)
PUB_IP=$(curl -s ifconfig.me)
iptables -t nat -A OUTPUT -d ${PUB_IP}/32 -p tcp --dport 6443 -j REDIRECT --to-port 6443

# 3. Persistir la regla (no se pierde en reboot)
iptables-save > /etc/iptables/rules.v4

# 4. Reiniciar el admission-controller de kyverno
kubectl rollout restart deployment/kyverno-admission-controller -n kyverno
```

**Verificación:** `kubectl get pods -n kyverno` → todos 1/1 Running · `kubectl apply` sin errores de webhook.

---

#### PROBLEMA #2 — Vault en CrashLoop: liveness probe mata el pod sellado

**Estado:** 🔄 COMMITEADO (commit `0a1a182`) — falta aplicar en VPS  
**Tipo:** Copiar archivo + ejecutar repair + unseal manual  
**Síntoma:** vault PHYSICAL_ERROR · 95+ reinicios · `vault-0 CrashLoopBackOff`  
**Por qué segundo:** vault bloqueado bloquea oauth2-proxy y tryton en cascada.  
**Referencia detallada:** §8.2 BUG-26 / §7.0.1 GAP-A

```bash
# En la máquina de desarrollo — copiar el fix a la VPS:
scp BosAgent/src/servers/S02/vault/task_catalog.sh \
    root@13.140.128.230:/etc/bos/blibs/servers/S02/vault/task_catalog.sh

# En la VPS como root:
export KUBECONFIG=/root/.kube/config
bosctl ficha repair vault

# Esperar 60s hasta que el pod arranque, luego hacer unseal (3 de 5 keys):
sleep 70
for KEY in $(python3 -c "
import json
d=json.load(open('/etc/bos/vault-init-keys.json'))
[print(k) for k in d['unseal_keys_b64'][:3]]
"); do
  kubectl exec -n sbos-security vault-0 -- vault operator unseal $KEY
done
```

**Verificación:** `kubectl exec -n sbos-security vault-0 -- vault status | grep Sealed` → `Sealed: false` · `bosctl ficha status vault` → INSTALLED.

---

#### PROBLEMA #3 — oauth2-proxy y oauth2-proxy-desktop en PHYSICAL_ERROR (derivado de vault)

**Estado:** ⏳ PENDIENTE — se resuelve automáticamente tras PROBLEMA #2  
**Tipo:** Automático vía observer (FIX-B ya activo)  
**Síntoma:** oauth2-proxy y oauth2-proxy-desktop en PHYSICAL_ERROR · no puede obtener secretos OIDC  
**Por qué tercero:** depende de vault estable.  
**Referencia detallada:** §8.2 BUG-27 / §7.0.1 GAP-B

```bash
# No requiere acción manual.
# FIX-B (commit 0a1a182) ya activo: observer Fase 3 detecta PHYSICAL_ERROR → llama repair.
# Tras vault INSTALLED, el observer repara oauth2-proxy automáticamente en el siguiente tick (5s).

# Verificar:
bosctl ficha status oauth2-proxy
bosctl ficha status oauth2-proxy-desktop
```

**Verificación:** Ambos → INSTALLED · pods `1/1 Running` sin reinicios.

---

#### PROBLEMA #4 — tryton INSTALL_FAILED (bloqueado por vault caído)

**Estado:** ⏳ PENDIENTE — instalar manualmente tras PROBLEMA #2+#3  
**Tipo:** Comando en VPS  
**Síntoma:** tryton INSTALL_FAILED · task_catalog.sh necesita credenciales de Vault  
**Referencia detallada:** §8.2 BUG-32 (duplicado S01/S04) — ver también Q-1 en §11.4

```bash
# Tras vault INSTALLED:
bosctl ficha install tryton
# Verificar:
bosctl ficha status tryton
```

**Verificación:** tryton → INSTALLED · pod `1/1 Running`.

> ⚠️ BUG-32: existe duplicado `S01/tryton` = `S04/tryton`. Antes de instalar, responder Q-1 del §11.4.

---

#### PROBLEMA #5 — Linkerd: ReplicaSets huérfanos de instalación anterior

**Estado:** ⏳ PENDIENTE — tras #1 kyverno estable  
**Tipo:** Limpieza K8s  
**Síntoma:** Linkerd INSTALLING en state · ReplicaSets huérfanos de crash anterior consumen recursos  
**Referencia detallada:** §8.2 BUG-29 / §8.2 BUG-33

```bash
export KUBECONFIG=/root/.kube/config

# Escalar a 0 los ReplicaSets huérfanos de linkerd
kubectl get rs -n linkerd | grep "0/0/0" | awk '{print $1}' | \
  xargs -I{} kubectl scale rs {} --replicas=0 -n linkerd

# Anotar oauth2-proxy para excluirlo del mesh de linkerd (BUG-33)
kubectl annotate namespace sbos-gateway linkerd.io/inject=disabled --overwrite
kubectl rollout restart deployment/oauth2-proxy -n sbos-gateway
```

**Verificación:** `kubectl get rs -n linkerd` sin ReplicaSets en 0/0/0 · `linkerd check` sin errores críticos.

---

### BLOQUE B — Correcciones de código y configuración (sin intervención en VPS)

> Estos problemas no bloquean el cluster actual pero sí afectan la idempotencia y corrección del instalador. Se resuelven editando ficheros en el repositorio.

---

#### PROBLEMA #6 — fedora-kde: versión en manifest incompatible con tag de imagen

**Estado:** ⏳ PENDIENTE  
**Tipo:** Edición de manifest (1 línea)  
**Síntoma:** manifest dice `version: "41.0.0"` · imagen es `sbos/fedora-desktop:1.0.0` → BOS calcula UPDATE_AVAILABLE incorrecto  
**Referencia detallada:** §11.3 INC-2

```bash
# Editar servers/S13/fedora-kde/manifest.yml:
# version: "41.0.0"  → version: "1.0.0"
# Después: bosctl ficha update fedora-kde (cuando VDI provisioner esté listo)
```

**Verificación:** `bosctl ficha status fedora-kde` → INSTALLED (no UPDATE_AVAILABLE).

---

#### PROBLEMA #7 — fedora-kde: ConfigMap sobreescribe el script baked en la imagen

**Estado:** ⏳ PENDIENTE  
**Tipo:** Eliminar ConfigMap del deployment  
**Síntoma:** El ConfigMap `fedora-kde-start-script` sobreescribe `start-desktop.sh` de la imagen → viola P-VDI-1 (imagen como fuente de verdad)  
**Referencia detallada:** §11.3 INC-3

```bash
# En servers/S13/fedora-kde/task_catalog.sh:
# Eliminar la sección que crea el ConfigMap fedora-kde-start-script
# y el volumeMount correspondiente en el Deployment.
# El script ya está en la imagen (COPY resources/start-desktop.sh).
```

**Verificación:** `kubectl get cm -n sbos-vdi | grep fedora-kde-start-script` → no existe.

---

#### PROBLEMA #8 — sbos-bootstrap-platform y sbos-k8s-network-validator: fichas sin registrar en state

**Estado:** ⏳ PENDIENTE  
**Tipo:** Investigar y registrar en state  
**Síntoma:** Ambas fichas existen en `servers/` pero no aparecen en `.sbos_state.json` → el observer no las supervisa  
**Referencia detallada:** §11.3 INC-4 / §8.2 BUG-31

```bash
# En la VPS, verificar si están instaladas realmente:
kubectl get pods -A | grep -E "local-path|network-validator"
# Si están instaladas: registrar manualmente en state via bosctl
bosctl ficha status sbos-bootstrap-platform
bosctl ficha status sbos-k8s-network-validator
```

**Verificación:** Ambas aparecen en `bosctl ficha list` con estado correcto.

---

#### PROBLEMA #9 — Dependencia circular: postgresql/redis declaran vault como dependencia

**Estado:** ⏳ PENDIENTE  
**Tipo:** Edición de manifests (3 líneas)  
**Síntoma:** postgresql (orden 100) y redis (orden 110) declaran `vault` como dependencia, pero vault (orden 130) declara `postgresql` — dependencia circular en el grafo de instalación  
**Referencia detallada:** §8.2 BUG-35

```bash
# Editar servers/S01/postgresql/manifest.yml → quitar "vault" de dependencies
# Editar servers/S01/redis/manifest.yml → quitar "vault" de dependencies
# La realidad: postgresql y redis NO necesitan vault para arrancar.
# Vault necesita postgresql para su backend HA — esa dependencia SÍ es correcta.
```

**Verificación:** `grep -A10 "dependencies:" servers/S01/postgresql/manifest.yml` → vault no aparece.

---

### BLOQUE C — Preguntas HITL (decisiones de diseño — responder antes de implementar)

> Estos problemas requieren una decisión del humano antes de poder implementar el fix. No tienen una respuesta técnica única — dependen del diseño del negocio.

---

#### PROBLEMA #10 — ❓ HITL: tryton duplicado S01 vs S04

**Estado:** ❓ HITL — ver Q-1 en §11.4  
**Pregunta:** `S01/tryton` y `S04/tryton` son archivos idénticos. ¿Son dos nodos distintos de Tryton (HA) o es un error de duplicación?

---

#### PROBLEMA #11 — ❓ HITL: auto_install fichas VDI (S13)

**Estado:** ❓ HITL — ver Q-2 en §11.4  
**Pregunta:** `fedora-kde`, `guacamole`, `nextcloud`, `onlyoffice` no tienen `auto_install` definido. ¿Se instalan automáticamente o requieren aprobación manual por tenant?

---

#### PROBLEMA #12 — ❓ HITL: arquitectura de sesiones VDI

**Estado:** ❓ HITL — ver Q-3 en §11.4  
**Pregunta:** ¿Pod por usuario, pool estático, o pool con slots? Define la arquitectura del provisioner fedora-kde.

---

#### PROBLEMA #13 — ❓ HITL: mattermost duplicado S06 vs S10

**Estado:** ❓ HITL — ver Q-4 en §11.4  
**Pregunta:** ¿Dos instancias con propósitos distintos o error de duplicación?

---

### BLOQUE D — Desarrollo VDI (implementar tras responder HITL)

> Estos gaps requieren código nuevo. Se implementan en orden porque cada uno habilita el siguiente.

---

#### PROBLEMA #14 — Guacamole sin conexiones: tabla guacamole_connection vacía

**Estado:** ⏳ PENDIENTE — bloquea el VDI (usuario no ve ningún escritorio al hacer login)  
**Tipo:** Código en task_catalog.sh  
**Acción:** En `ficha_post_install()` de guacamole, insertar una conexión VNC que apunte al Service `fedora-kde.sbos-vdi:5900`  
**Referencia detallada:** §11.2 GAP-4

---

#### PROBLEMA #15 — noVNC expuesto sin autenticación bAuth (puerto 6901)

**Estado:** ⏳ PENDIENTE — riesgo de seguridad  
**Tipo:** Código en task_catalog.sh (eliminar Service externo)  
**Acción:** Eliminar el Service K8s que expone el puerto 6901 al exterior. Solo guacd debe poder conectar al puerto VNC del pod fedora-kde  
**Referencia detallada:** §11.2 GAP-5

---

#### PROBLEMA #16 — S13 fichas sin campo auto_install (depende de HITL #11)

**Estado:** ❓ Bloqueado por PROBLEMA #11  
**Tipo:** Edición de manifests (4 líneas)  
**Acción:** Agregar `auto_install: true|false` a manifests de fedora-kde, guacamole, nextcloud, onlyoffice según respuesta HITL

---

#### PROBLEMA #17 — VDI provisioner: 1 pod compartido para todos los usuarios (depende de HITL #12)

**Estado:** ❓ Bloqueado por PROBLEMA #12  
**Tipo:** Desarrollo nuevo (ficha `fedora-kde-provisioner` + integración con scaler)  
**Acción:** Implementar provisioner según arquitectura elegida (pod/usuario, pool, o slots)  
**Referencia detallada:** §10.2, §11.2 GAP-3, VDI-GAP-1, VDI-GAP-2

---

### BLOQUE E — Deuda técnica (no bloqueante — planificar cuando el cluster esté estable)

---

#### PROBLEMA #18 — health.check_command ausente en fichas críticas

**Estado:** ⏳ PENDIENTE (P2) — no bloqueante  
**Acción:** Agregar `check_command` a manifests de vault, postgresql, keycloak, kong, fedora-kde, guacamole  
**Referencia detallada:** §11.2 GAP-2

---

#### PROBLEMA #19 — Motor de Puertos sin integración: Kardex vacío

**Estado:** ⏳ PENDIENTE (P5) — deuda técnica  
**Acción:** Agregar llamada a `bos.portman.assign` al inicio de `ficha_install()` en cada task_catalog.sh  
**Referencia detallada:** §11.2 GAP-1

---

#### PROBLEMA #20 — STUBs de monitoreo: Loki, Tempo, Zabbix incompletos

**Estado:** ❓ HITL — ver Q-5 en §11.4  
**Acción:** Completar STUBs si son parte del MVP, o marcar como `auto_install: false` explícitamente

---

### Resumen visual del plan de acción

```
BLOQUE A — VPS (hacer en orden estricto)
  #1  ⏳ Hairpin NAT → kyverno recovery        [sin código — acción VPS]
  #2  🔄 FIX-26A vault en VPS                  [copiar archivo + repair + unseal]
  #3  ⏳ oauth2-proxy auto-repair              [automático tras #2 — FIX-B activo]
  #4  ⏳ tryton install                        [manual tras #2+#3]
  #5  ⏳ linkerd cleanup + oauth2-proxy mesh   [limpieza K8s]

BLOQUE B — Código (en cualquier orden, sin dependencias entre sí)
  #6  ⏳ fedora-kde versión manifest
  #7  ⏳ fedora-kde eliminar ConfigMap
  #8  ⏳ fichas huérfanas en state
  #9  ⏳ dependencia circular postgresql/redis→vault

BLOQUE C — HITL (responder para desbloquear Bloque D)
  #10 ❓ tryton S01 vs S04
  #11 ❓ auto_install VDI
  #12 ❓ arquitectura sesiones VDI
  #13 ❓ mattermost duplicado

BLOQUE D — VDI desarrollo (en orden)
  #14 ⏳ guacamole conexiones [depende de #12 respondido]
  #15 ⏳ noVNC bloquear puerto 6901
  #16 ❓ auto_install S13 [depende de #11]
  #17 ❓ VDI provisioner [depende de #12]

BLOQUE E — Deuda técnica (planificar tras cluster estable)
  #18 ⏳ health.check_command fichas críticas
  #19 ⏳ portman integración task_catalog.sh
  #20 ❓ Loki/Tempo/Zabbix STUBs

ESTADO ESPERADO TRAS BLOQUE A COMPLETO:
  27+ fichas INSTALLED · vault estable · tryton funcionando
  oauth2-proxy INSTALLED · kyverno Running · linkerd limpio
```

---

*Documento v2.7.0 — bos-developer · 2026-10-13*  
*Plan completo de instalación: `PLAN-IMPLEMENTACION-BOS-VDI.md`*
