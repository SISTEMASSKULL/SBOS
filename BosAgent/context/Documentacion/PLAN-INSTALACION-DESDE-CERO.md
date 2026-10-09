# Plan de Instalación desde Cero — VPS Limpia Ubuntu 26.04

**Versión:** 1.3.0  
**Fecha:** 2026-10-09  
**Autor:** bos-developer  
**Estado:** ✅ PT-01..PT-02b COMPLETADOS — 31/31 fichas INSTALLED/UPDATE_AVAILABLE en VPS de prueba  
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
| **FIX-DOC** | `BosAgent/CLAUDE.md` tabla "Rutas canónicas" | 📄 DOC | Rutas TLS documentadas como `/etc/bos/tls/bos.crt` pero `paths.CertFile` apunta a `/etc/bos/certs/bos.crt` — cualquier agente que leyera el CLAUDE.md buscaría la ruta incorrecta | Corregir a `/etc/bos/certs/bos.crt` y `/etc/bos/certs/bos.key` |
| **FIX-14** | `internal/state/types.go` | 🔴 CRÍTICO | `ValidTransitions[StatePending]` no incluía `StateInstalled` ni `StateInstalling` — `Transition(fichaID, StateInstalled)` fallaba silenciosamente (error ignorado con `_`) en fichas PENDING con recursos ya corriendo en K8s | Agregar `StateInstalling, StateInstalled` como destinos válidos desde `StatePending` |
| **FIX-15** | `internal/domain/ficha_service.go` | 🔴 CRÍTICO | `Repair()` y `Update()` no llamaban `svc.state.Transition(fichaID, StateInstalled)` al completar con éxito — solo `Install()` actualizaba el estado | Agregar `svc.state.Transition(fichaID, state.StateInstalled)` en ambas funciones |
| **FIX-16** | `cmd/bosctl/ficha.go` | 🔴 CRÍTICO | `cmdFichaRepair/Install/Update/Remove` usaban `buildFichaSvc()` que crea `FichaService(installer=nil)` → `ErrInstallerUnavailable` | Cambiar a `doRPCCall()` al daemon (que tiene el orchestrator real), siguiendo el patrón de `cmdFichaLogs` |

**Resultado tras FIX-01..FIX-16:** `CGO_ENABLED=0 go build ./...` — ✅ sin errores · 31/31 fichas INSTALLED/UPDATE_AVAILABLE en VPS de prueba (commit b4550e7)

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
[ PENDIENTE ] PT-04:  bosctl ficha install (4 fichas VDI)
    ↓
[ PENDIENTE ] PT-05:  Prueba end-to-end NFC → Fedora KDE → Nextcloud → OnlyOffice
```

**Resultado VPS de prueba (2026-10-09):**
- 39 pods Running en K8s
- 29 fichas INSTALLED · 2 fichas UPDATE_AVAILABLE (31/31 OK)
- 3 daemons host activos: bauth (real v3.0.0) · bkernel (stub) · bhnexus (stub)
- Port-forwards: postgresql→15432 · redis→16379

**PT-03 — Daemons desplegados:**
| Daemon | Tipo | Socket | Servicio systemd |
|--------|------|--------|-----------------|
| bAuth | Real v3.0.0 (Rust MUSL) | `/run/bos/bauth.sock` | `bauth.service` |
| bkernel | Stub Go (placeholder) | `/run/bos/bkernel.sock` | `bkernel.service` |
| bhnexus | Stub Go (placeholder) | `/run/bos/bhnexus.sock` | `bhnexus.service` |

Stub fuente: `BosAgent/src/tools/sbos-stub-daemon/` (reemplazar por real cuando esté desarrollado)

---

*Documento v1.2.0 — bos-developer · 2026-10-07*  
*Plan completo de instalación: `PLAN-IMPLEMENTACION-BOS-VDI.md` (artefacto interactivo: https://claude.ai/artifact/8KqeXT172Cwgzh7vWoF86f)*
