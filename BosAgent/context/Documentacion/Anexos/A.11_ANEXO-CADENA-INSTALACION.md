# Anexo A.11 — Cadena Completa de Instalación
## De Ubuntu virgen a VDI operativo con Fedora — paso por paso

**Versión:** 4.0.0 · **Fecha:** 2026-07-18 · **Autor:** bos-developer — SBOS
**Fortalece al motor:** ① IAM Installer
**Referencia:** [1.02 — Sagas de Instalación](../1.02_MANUAL-IAM-INSTALLER-SAGAS.md) · [A.02 — Estructura del Servidor](A.02_ANEXO-ESTRUCTURA-SERVIDOR-PRODUCCION.md)

**Cambio en v4.0.0:** Principio de idempotencia por fase (inspirado en kubeadm init).
Cada paso de System-Install verifica antes de actuar. Si ya está hecho → skip.
Rutas actualizadas a la estructura unificada `/opt/skull/SBOS/`.

---

## El comando

```bash
git clone https://github.com/SISTEMASSKULL/bos-install.git
cd bos-install
sudo ./bosctl setup --mode=prod --seed ./seed-skull.yml
```

**Esta es la única intervención humana en todo el SBOS.** El `git clone` + `bosctl setup`
es el equivalente a `kubeadm init` pero para el sistema operativo empresarial completo.
De aquí en adelante, **todo** lo hace el BOS.

Un solo comando. El BOS ejecuta 37 pasos en secuencia y verifica 14 criterios.
Si un paso falla, los pasos anteriores de esa etapa se compensan en orden inverso.
Si todo sale bien, al final del Paso 37 hay un sistema operativo empresarial completo
con escritorio Fedora accesible por web.

---

## Reglas irrenunciables de la instalación

Estas reglas aplican a los 37 pasos. Violarlas = el Bibliotecario rechaza la entrega.

| # | Regla | Consecuencia |
|:-:|-------|-------------|
| **R1** | **Nada se ejecuta de forma manual.** Todo — paquetes, directorios, permisos, pods, secretos, certificados — lo ejecuta el BOS vía JSON-RPC o el motor Bash. El humano solo ejecuta `bosctl setup`. | Si algo requiere `ssh` al servidor, el código del BOS está incompleto |
| **R2** | **Cero intromisión manual en el servidor.** Si un paso falla, no se arregla entrando al servidor. Se repara el código del BOS, se recompila el binario, se reinicia el daemon, y se vuelve a ejecutar la instalación desde el paso que falló. | `ssh` de emergencia = el BOS no es soberano |
| **R3** | **Idempotencia.** Cada paso puede ejecutarse N veces con el mismo resultado. Si un paso ya está completo, ejecutarlo de nuevo no rompe nada ni duplica recursos. | Paso no idempotente = error de diseño, no de operación |
| **R4** | **Todo estado lo escribe el BOS.** Ni el humano ni un script externo crean archivos de configuración, `.env`, `tenant.conf` ni state files. El BOS es el único escritor de `/etc/bos/`. | Archivo creado manualmente = corrupción del estado |
| **R5** | **Compensación, no parche.** Si un paso falla, los pasos anteriores se compensan en orden inverso. El sistema vuelve al estado anterior limpio. No se deja el sistema a medio instalar. | Sistema en estado inconsistente = inaceptable |
| **R6** | **Las dependencias del SO son fichas declarativas.** Agregar un paquete `apt` = editar `servers/S00-hostserver/bos-preflight/manifest.yml`, no hacer `apt install` manual ni modificar `install.sh`. | `apt install` manual = el BOS no controla su entorno |
| **R7** | **Solo el BOS instala — y lo hace a través de una ficha.** Todo daemon, aplicación, base de datos o servicio entra al SBOS como ficha con `manifest.yml` + `task_catalog.sh` + `PROPOSITO.md`. El BOS no distingue entre "daemon" y "aplicación": todo es una ficha que se instala, actualiza, repara y remueve con el mismo ciclo de vida. | `systemctl start` manual, `apt install` de un daemon, copiar un binario a mano = violación de R7 |

### Principio de idempotencia por fase (inspirado en kubeadm init)

Cada paso de instalación sigue el mismo patrón que `kubeadm init phase`:

```
ANTES de ejecutar → verificar si ya está hecho
SI ya está hecho  → skip y reportar "ya existe"
SI no está hecho  → ejecutar
SI falló antes    → reparar y completar
```

**Ejecutar `bosctl setup` 10 veces produce exactamente el mismo estado del sistema.**
La primera vez instala. Las siguientes 9 verifican y reportan "skip — ya existe".
Esto es lo que hace kubeadm con sus fases (certs, kubeconfigs, static pods) y es
lo que el BOS aplica a cada uno de sus 37 pasos.

---

## ETAPA A — SYSTEM-INSTALL (Pasos 1-6 · sin compensación)

El daemon todavía no corre. `bosctl` actúa como instalador del sistema. Esta etapa es
la **única** que requiere intervención humana inicial (`git clone` + `bosctl setup`).
Todo lo demás — desde el Paso 7 en adelante — lo ejecuta el daemon BOS sin el humano.

Cada paso implementa el patrón kubeadm: **verificar antes de actuar.**

**Código:** `cmd/bosctl/system_install.go` (393 líneas, `cmdSystemInstall`)

### Paso 0 — Preflight checks (validación del sistema)

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Verifica que el sistema cumple los requisitos mínimos ANTES de tocar nada |
| **Código** | `cmdSystemInstall()` — validaciones iniciales |
| **Checks** | ¿Ejecutando como root? ¿Ubuntu 26.04? ¿≥ 10 GB libres en `/opt`? ¿Puertos 9443, 22, 443 libres? ¿`systemd` presente? ¿`kubeadm` en PATH? |
| **Tipo de error** | **Bloqueante** — si falta un requisito, `bosctl setup` aborta con mensaje descriptivo |
| **Idempotencia** | Los checks siempre se ejecutan. Si pasan → continuar. Si fallan → abortar (no hay nada que saltar) |
| **Inspirado en** | `kubeadm init phase preflight` — mismos checks: root, puertos, comandos en PATH |

### Paso 1 — Crear estructura de directorios

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Crea `/opt/skull/SBOS/` y todos sus subdirectorios: `bin/`, `core/`, `blibs/servers/`, `config/`, `runtime/`, `logs/`, `state/`, `data/`, `backups/`, `kube/`, `tenant/`, `sysctl/` |
| **Código** | `installBinaries()` + `installCore()` + `installBlibs()` — cada uno crea sus directorios |
| **Permisos** | `bosagent:bosagent`, 0750 para directorios, 0640 para archivos |
| **Idempotencia** | Si el directorio ya existe con permisos correctos → **skip**. Si existe pero permisos incorrectos → **corrige permisos**. Si no existe → **crea** |
| **Resultado** | `find /opt/skull/SBOS/ -type d` muestra la estructura completa |
| **Si falla** | Error fatal — sin directorios no hay dónde instalar |

### Paso 2 — Copiar binarios (bos + bosctl)

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Copia `bos` y `bosctl` al directorio unificado de binarios |
| **Código** | `installBinaries()` — líneas 86-121 de system_install.go |
| **Origen** | Directorio del clon (`bos-install/` o junto al ejecutable) |
| **Destino** | `/opt/skull/SBOS/bin/bos`, `/opt/skull/SBOS/bin/bosctl` |
| **Symlinks** | `/usr/local/bin/bos` → `/opt/skull/SBOS/bin/bos`, `/usr/local/bin/bosctl` → `/opt/skull/SBOS/bin/bosctl` |
| **Idempotencia** | Si el binario ya existe y tiene el mismo SHA256 → **skip**. Si existe pero SHA256 diferente → **reemplaza** (actualización). Si no existe → **copia**. Si el symlink ya apunta correctamente → **skip** |
| **Resultado** | `bos --version` y `bosctl --version` responden con la versión correcta |
| **Si falla** | Error fatal — no hay binarios que ejecutar |

### Paso 3 — Copiar core/ (scripts del motor Bash)

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Copia los 5 scripts del motor Bash al directorio unificado |
| **Código** | `installCore()` — líneas 127-168 de system_install.go |
| **Scripts copiados** | `00_MASTER_INSTALL_SBOS.sh`, `01_LOAD_ENVIRONMENT.sh`, `02_RESOLVE_DEPENDENCIES.sh`, `03_EXECUTE_FICHA.sh`, `04_ROLLBACK_FICHA.sh` |
| **Destino** | `/opt/skull/SBOS/core/` |
| **Idempotencia** | Si el directorio ya contiene los 5 scripts con el mismo contenido → **skip**. Si falta alguno o difiere → **copia** (selectivo, solo lo que cambió) |
| **Resultado** | `/opt/skull/SBOS/core/00_MASTER_INSTALL_SBOS.sh` existe y es ejecutable |
| **Si falla** | `bos.ficha.install` fallará con exit 127 — el daemon no puede ejecutar sagas sin estos scripts |

### Paso 4 — Copiar blibs/ (catálogo de fichas)

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Copia el directorio `servers/` completo al sistema de bibliotecas |
| **Código** | `installBlibs()` — líneas 174-203 de system_install.go |
| **Contenido** | 16 servidores lógicos (S00-S16), ~112 fichas con `manifest.yml` + `task_catalog.sh` |
| **Destino** | `/opt/skull/SBOS/blibs/servers/` |
| **Idempotencia** | `cp -a` con `--update` — solo copia archivos más nuevos que el destino. Si todo está sincronizado → **skip**. Si hay fichas nuevas o modificadas → **copia incremental** |
| **Resultado** | `servers.yml` existe, todos los `manifest.yml` legibles, `bosctl ficha rescan` las descubre |
| **Si falla** | El daemon arranca pero no encuentra ninguna ficha — `bosctl ficha list` vacío |

### Paso 5 — Crear archivos de configuración

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Crea `bos.toml`, `bos-install.toml` y `.env` con valores por defecto |
| **Código** | `installEnvTemplate()` — líneas 244-287 de system_install.go |
| **Archivos** | `/opt/skull/SBOS/config/bos.toml` (config principal), `/opt/skull/SBOS/config/bos-install.toml` (estado de instalación), `/opt/skull/SBOS/config/.env` (variables de entorno) |
| **Idempotencia** | Si el archivo ya existe → **nunca sobreescribe** (respeta personalización del admin). Si no existe → **crea con valores por defecto** |
| **Importante** | `.env` y `bos.toml` son los ÚNICOS archivos que el BOS crea una vez y nunca vuelve a tocar. El admin puede editarlos y el BOS respeta los cambios |
| **Si falla** | El daemon no arranca en modo normal sin `bos-install.toml` |

### Paso 6a — Instalar servicios systemd

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Copia `bos.service` y `bos-console.service` a `/etc/systemd/system/`, ejecuta `daemon-reload` y `enable` |
| **Código** | `installServices()` — líneas 206-239 de system_install.go |
| **Servicios** | `bos.service` (daemon principal, Type=simple, user=bosagent), `bos-console.service` (dashboard en tty1) |
| **Idempotencia** | Si `systemctl is-enabled bos.service` → **skip**. Si el archivo `.service` ya existe y es idéntico → **skip**. Si no existe → **copia y enable** |
| **Resultado** | `systemctl is-enabled bos.service` → enabled |
| **Si falla** | El daemon no arranca al iniciar el sistema |

### Paso 6b — Ejecutar bos-preflight (dependencias del SO)

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Ejecuta `ficha_pre_install`, `ficha_install` y `ficha_post_install` de la ficha `bos-preflight` |
| **Código** | `runPreflightFicha()` — líneas 291-339 de system_install.go |
| **Ficha** | `servers/S00-hostserver/bos-preflight/task_catalog.sh` |
| **Qué instala** | Paquetes del SO (apt), crea usuario `bosagent`, configura cgroups v2, genera certificado TLS, crea symlinks de compatibilidad (`/etc/bos/` → `/opt/skull/SBOS/config/`, etc.) |
| **Idempotencia** | Si `bosagent` ya existe y los paquetes ya están instalados → **skip** (el task_catalog.sh verifica cada paquete con `dpkg -s`). Si el TLS cert ya existe y es válido → **skip**. Si los symlinks ya apuntan correctamente → **skip** |
| **Variable** | `BOS_INSTALL_MODE=prod` → requisitos estrictos; `dev` → advertencias no bloquean |
| **Resultado** | Usuario `bosagent` existe, cgroups v2 delegados, TLS cert en `config/tls/`, symlinks creados |
| **Si falla** | Dependencias del SO no están — BOS no puede operar |

---

## ETAPA B — AUTO-BOOTSTRAP (Pasos 7-8 · sin compensación)

El daemon `bos` arranca por primera vez. Antes de entrar al event loop principal,
ejecuta la secuencia de auto-bootstrap: prepara el host, inicializa RBAC, verifica
cgroups y configura la red bridge.

**Código:** `cmd/bos/auto_bootstrap.go` (89 líneas, `autoBootstrap`)

### Paso 7 — bootstrap.Setup() (directorios, sysctl, permisos)

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Crea estructura de directorios, aplica parámetros sysctl, configura permisos |
| **Código** | `internal/bootstrap.Setup()` invocado desde `autoBootstrap()` |
| **Directorios** | `/data/`, `/var/log/bos/`, `/run/bos/` |
| **Sysctl** | `net.ipv4.ip_forward=1`, `fs.inotify.max_user_watches`, límites de archivos |
| **Resultado** | Directorios existen con permisos correctos, sysctl aplicados |
| **Si falla** | `log.Fatal()` — el daemon no arranca |

### Paso 8 — RBAC, cgroups y bridge

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Carga roles RBAC desde `/etc/bos/rbac/roles.json`, verifica delegación de cgroups v2, configura red bridge para contenedores |
| **Código** | `autoBootstrap()` líneas 34-88 |
| **RBAC** | `security.NewFileRBAC(paths.RBACRoles)` — roles por defecto si el archivo no existe |
| **Cgroups** | Detecta bare-metal vs contenedor, configura `Delegate=yes` en systemd si es necesario |
| **Bridge** | `network.EnsureBridgeNetwork()` — puente para comunicación entre pods |
| **Resultado** | RBAC operativo, cgroups escribibles, bridge de red creado |
| **Si falla** | RBAC degrada a modo permisivo; cgroups sin delegación → `log.Fatal()` en bare-metal |

---

## ETAPA C — RUN-NORMAL (Pasos 9-10 · sin compensación)

El daemon entra en modo normal. Inicializa 15 subsistemas en orden y levanta el socket
Unix `/run/bos/bos.sock`. A partir de este momento, `bosctl` y los demás daemons pueden
comunicarse con BOS vía JSON-RPC.

**Código:** `cmd/bos/run_normal.go` (445 líneas, `runNormal`)

### Paso 9 — Inicializar los 15 subsistemas

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Inicializa en orden: STATE_MANAGER → plugin loader → K8s core → PG Auxiliar → release manager → saga orchestrator + compensator → observer loop → health checker → reconcile scheduler → repair manager → unified watchdog → Context Plane → RBAC (FileRBAC o BauthRBAC bridge) → métricas Prometheus → biaos (agente IA) |
| **Código** | `runNormal()` líneas 128-306 |
| **STATE_MANAGER** | Abre `/etc/bos/.sbos_state.json` con `fcntl.flock` exclusivo |
| **Plugin Loader** | Escanea `/etc/bos/blibs/servers/`, carga todas las fichas en memoria |
| **K8s Core** | Conecta a `kubectl` vía `kubeconfig`, inicializa PG Auxiliar Anti-Pérdida |
| **Observer Loop** | Inicializa estados de fichas desde `stateMgr`, arranca goroutine DAG topológico |
| **Watchdog** | Unificado 3-capas (Ubuntu + K8s + BOS), ciclo 30s |
| **Context Plane** | PG+Redis si `BOS_PG_DSN` configurada; si no, memStore degradado |
| **Métricas** | Prometheus en `127.0.0.1:9090` (solo loopback) |
| **Resultado** | 15 subsistemas inicializados, audit log registra `state=all_subsystems_started` |
| **Si falla** | `log.Fatal()` en STATE_MANAGER o K8s; el resto degradan gracefully |

### Paso 10 — Levantar socket Unix y API server

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Crea el socket Unix `/run/bos/bos.sock` (0660, grupo bosagent), activa Context API en `:9443` con TLS 1.3, inicia goroutines de health, reconcile y watchdog |
| **Código** | `runNormal()` líneas 238-444 |
| **Interface Dual** | WebSocket RPC + JSON-RPC 2.0 sobre el mismo socket Unix |
| **API :9443** | 6 endpoints REST (HTTPS/TLS 1.3) para Kong y health probes |
| **AutoMigrate** | Verifica tablas `registered_devices` + `context_sessions` en schema `bos` |
| **SDNotify** | `READY=1` a systemd — el servicio se marca como activo |
| **Resultado** | `bosctl status` responde, `/run/bos/bos.sock` acepta conexiones JSON-RPC |
| **C-01 ✅** | sysctl + /data/ verificados |
| **C-02 ✅** | kubeconfig funcional, `kubectl cluster-info` responde |

---

## ETAPA D — STACK MÍNIMO (Pasos 11-17 · saga con compensación)

El daemon está corriendo. `bosctl deploy` lee el `seed-skull.yml` y ejecuta la saga
`deployTenant()`: 7 pasos que instalan el stack mínimo de infraestructura. Cada paso
que falla dispara la compensación de todos los pasos anteriores.

**Código:** `cmd/bosctl/deploy.go` (560 líneas, `deployTenant`)

### Paso 11 — Instalar Kubernetes (kubeadm)

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Inicializa el cluster Kubernetes con `kubeadm init` |
| **Ficha** | `sbos-bootstrap-k8s` |
| **Código saga** | `deploy.go:145-148` — PASO 0 |
| **Resultado** | `kubectl cluster-info` responde, nodo master Ready |
| **Compensación** | No — es el paso 0, base de todo |
| **Si falla** | Error fatal — sin K8s no hay plataforma |
| **C-03 ✅** | `kubectl get nodes` muestra el nodo Ready |

### Paso 12 — Crear namespace K8s + NetworkPolicy

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Crea el namespace `sbos-{tenant}`, aplica NetworkPolicy `default-deny`, ResourceQuota y LimitRange |
| **Ficha** | `sbos-namespace` (definida en `seed.infrastructure.ficha`) |
| **Código saga** | `deploy.go:151-161` — PASO 1 |
| **Variables** | `TENANT_ID`, `TENANT_NAME`, `DOMAIN_ID`, `DOMAIN_TYPE` desde el seed |
| **Aislamiento** | `tenancy_trust_model: hard`, `isolation_mechanism: namespace_rbac` |
| **Compensación** | `compensateStep1` — elimina el namespace |
| **Si falla** | Se revierte PASO 1 |

### Paso 13 — Configurar StorageClass + PersistentVolumes

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Crea StorageClass y PersistentVolumes para las bases de datos y aplicaciones |
| **Ficha** | `sbos-bootstrap-storage` |
| **Código saga** | `deploy.go:165-171` — PASO 1.5 |
| **Resultado** | PVCs funcionales, `kubectl get sc` muestra la clase |
| **Compensación** | `compensateStep1` — elimina namespace |
| **Si falla** | Sin almacenamiento persistente, PG/Redis/Vault no pueden desplegarse |

### Paso 14 — Provisionar PostgreSQL + bases de datos

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Despliega PostgreSQL 18.4 como pod K8s (ClusterIP `8100`), crea las bases de datos definidas en el seed |
| **Ficha** | `postgresql` |
| **Código saga** | `deploy.go:173-183` — PASO 2 |
| **Variables** | `ENGINE: postgresql`, `VERSION: "18.4"` |
| **Bases creadas** | `keycloak_db`, `bkernel_db`, `bauth_db`, `tryton_db`, `minio_meta`, `bsearch_catalog`, `bcompass_db`, `bnotify_db`, `audit_db` |
| **Schema** | `SBOS_db` — un schema por servicio |
| **Compensación** | `compensateSteps12` — no destructivo, PG se mantiene |
| **C-04 ✅** | `pg_isready` → accepting connections |

### Paso 15 — Configurar Redis + Context Registry

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Despliega Redis 8.6.2 como pod K8s, configura 3 bases de datos lógicas |
| **Ficha** | `redis` |
| **Código saga** | `deploy.go:185-196` — PASO 3 |
| **DB0** | `streams_cache` — Redis Streams + caché general |
| **DB1** | `context_registry` — registro de contexto (TTL = sesión bauth) |
| **DB2** | `rate_limiting` — rate limiting distribuido |
| **Persistencia** | AOF (Append-Only File) |
| **Compensación** | `compensateSteps123` — no destructivo, Redis se mantiene |
| **C-05 ✅** | `redis-cli PING` → PONG |

### Paso 16 — Inicializar Vault + PKI + AppRole

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Despliega Vault 2.0.1, ejecuta `vault operator init` con Shamir 3/5, configura motor KV v2, crea AppRoles por ficha |
| **Ficha** | `vault` |
| **Código saga** | `deploy.go:198-211` — PASO 4 |
| **Base path** | `secret/tenants/{tenant}` |
| **AppRole TTL** | 24h |
| **Resultado** | Vault initialized + unsealed, secret path creado |
| **Compensación** | `compensateSteps1234` — sella Vault |
| **C-06 ✅** | `vault status` → Initialized=true, Sealed=false |

### Paso 17 — Desplegar Keycloak + Realm + SPIs

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Despliega Keycloak como ficha de infraestructura, crea el Realm del tenant, configura los Service Provider Interfaces |
| **Ficha** | `keycloak` |
| **Código saga** | `deploy.go:213-227` — PASO 5 |
| **Realm** | Definido en `seed.identity.realm` (ej: `skull`) |
| **SPIs** | `BosRolTemplate`, `FinancialDomain`, `PhysicalDomain`, `LogicalDomain`, `TemporalContext` |
| **Sesión** | SSO max 12h, token 15m |
| **Importante** | Keycloak se instala como **ficha de infraestructura** (gestión de realms, SPIs, Federation). El **IdP soberano es bauth** — Keycloak no autentica usuarios finales |
| **Compensación** | `compensateSteps12345` — elimina el Realm |
| **C-07 ✅** | `/health/ready` → UP |
| **C-08 ✅** | Kong reachable |

---

## ETAPA E — CONTEXT PLANE DDL (Paso 18 · dentro de la saga)

### Paso 18 — Aplicar DDL del Context Plane

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Crea las tablas `registered_devices` y `context_sessions` en el schema `bos` de `SBOS_db` |
| **Código saga** | `deploy.go:229-243` — PASO 6 |
| **Método RPC** | `bos.ctx.auto_migrate` |
| **Tablas creadas** | `bos.registered_devices` (7 columnas), `bos.context_sessions` (5 columnas) |
| **Índices** | `idx_ctx_tenant` |
| **Compensación** | `compensateSteps123456` — no destructivo, DDL se mantiene |
| **Si `auto_migrate: false`** | Se salta — las tablas se crearán cuando PG esté disponible |

---

## ETAPA F — DAEMONS Y APLICACIONES (Pasos 19-30 · Paso 7 de la saga)

El DEPENDENCY_RESOLVER (Kahn) calcula el orden topológico de instalación a partir
de las dependencias declaradas en cada `manifest.yml`. El Paso 7 de `deployTenant()`
itera sobre `cfg.Fichas` en ese orden. **Cada ficha es atómica: se instala completa
o se revierte completamente.**

**Código saga:** `deploy.go:245-257` — PASO 7

### Paso 19 — Instalar bkernel (CDC daemon)

| Campo | Detalle |
|--------|--------|
| **Ficha** | `sbos-bkernel` |
| **Servidor** | S01-dataserver |
| **Depende de** | postgresql |
| **Qué hace** | Despliega el daemon bkernel — listener CDC sobre WAL de PostgreSQL, propaga cambios a Redis Streams |
| **Resultado** | Pod Running, CDC activo sobre `SBOS_db` |
| **Si falla** | Compensación: `compensateSteps123456` — borra el pod, limpia configuración |

### Paso 20 — Instalar Kong (API Gateway)

| Campo | Detalle |
|--------|--------|
| **Ficha** | `kong` |
| **Servidor** | S02-gatewayserver |
| **Depende de** | keycloak, redis, postgresql |
| **Qué hace** | Despliega Kong 3.9.x LTS como API Gateway — punto único de entrada HTTPS, ruteo a servicios internos |
| **Resultado** | `kong health` → OK, rutas cargadas |
| **Si falla** | Compensación: elimina el pod y las rutas |

### Paso 21 — Instalar bauth (Identity Daemon)

| Campo | Detalle |
|--------|--------|
| **Ficha** | `bauth` |
| **Servidor** | S03-identityserver |
| **Depende de** | keycloak, vault, postgresql |
| **Qué hace** | Despliega el daemon de identidad soberano — BitMask 64-bit, token unificado, motor de políticas |
| **Resultado** | `/run/bos/bauth.sock` responde JSON-RPC |
| **Si falla** | Compensación: borra el pod, limpia schema `bauth` |

### Paso 22 — Instalar tryton (ERP)

| Campo | Detalle |
|--------|--------|
| **Ficha** | `tryton` |
| **Servidor** | S04-erpserver |
| **Depende de** | postgresql |
| **Qué hace** | Despliega Tryton ERP con localización — base de datos `tryton_db`, módulos contables y de inventario |
| **Resultado** | ERP accesible vía Kong, BD `tryton_db` creada |
| **Si falla** | Compensación: borra el pod, limpia BD `tryton_db` |

### Paso 23 — Instalar bnotify (Push Notification Daemon)

| Campo | Detalle |
|--------|--------|
| **Ficha** | `bnotify` |
| **Servidor** | S03-identityserver |
| **Depende de** | redis, kong, bauth |
| **Qué hace** | Despliega el daemon de notificaciones — Push MFA, notificaciones del sistema, cliente CAEP |
| **Resultado** | `/run/bos/bnotify.sock` responde JSON-RPC |
| **Si falla** | Compensación: borra el pod, limpia schema `bnotify` |

### Paso 24 — Instalar bhnexus (Proxy de Hardware)

| Campo | Detalle |
|--------|--------|
| **Ficha** | `bhnexus` |
| **Servidor** | S02-gatewayserver |
| **Depende de** | kong, bauth |
| **Qué hace** | Despliega el proxy de hardware universal — WebSocket mTLS en `:9444`, bridge entre dispositivos físicos y el bus de eventos |
| **Resultado** | WebSocket `:9444` acepta conexiones mTLS |
| **Si falla** | Compensación: borra el pod, cierra el puerto |

### Paso 25 — Instalar banexus (Edge Sentinel)

| Campo | Detalle |
|--------|--------|
| **Ficha** | `banexus` |
| **Servidor** | S02-gatewayserver |
| **Depende de** | bhnexus |
| **Qué hace** | Despliega el edge sentinel — intercepta dispositivos USB/serial vía udev, los expone al bus de eventos |
| **Resultado** | Edge sentinel activo, reglas udev cargadas |
| **Si falla** | Compensación: borra el pod, limpia reglas udev |

### Paso 26 — Instalar nginx (Reverse Proxy)

| Campo | Detalle |
|--------|--------|
| **Ficha** | `nginx` |
| **Servidor** | S16-webserver |
| **Depende de** | kong |
| **Qué hace** | Despliega nginx como reverse proxy — TLS en `:443`, virtual hosting por tenant, ruteo a Kong upstream |
| **Resultado** | `curl -k https://localhost` → responde (nginx → Kong → servicio) |
| **Si falla** | Compensación: borra el pod, libera puerto 443 |

### Paso 27 — Instalar certbot (SSL)

| Campo | Detalle |
|--------|--------|
| **Ficha** | `certbot` |
| **Servidor** | S16-webserver |
| **Depende de** | nginx |
| **Qué hace** | Obtiene certificados SSL vía Let's Encrypt para el dominio del tenant |
| **Resultado** | Certificado en `/etc/letsencrypt/live/{domain}/fullchain.pem` |
| **Si falla** | Nginx sigue funcionando con certificado auto-firmado |

### Paso 28 — Instalar modsecurity (WAF)

| Campo | Detalle |
|--------|--------|
| **Ficha** | `modsecurity` |
| **Servidor** | S16-webserver |
| **Depende de** | nginx |
| **Qué hace** | Activa ModSecurity como WAF con OWASP Core Rule Set |
| **Resultado** | WAF activo, reglas OWASP CRS cargadas |
| **Si falla** | Nginx sigue funcionando sin WAF |

### Paso 29 — Instalar nextcloud (Cloud Storage)

| Campo | Detalle |
|--------|--------|
| **Ficha** | `nextcloud` |
| **Servidor** | S11-vdiserver |
| **Depende de** | postgresql, keycloak, minio |
| **Qué hace** | Despliega Nextcloud con OIDC (vía bauth), almacenamiento en MinIO, PVC 500Gi |
| **Resultado** | Login OIDC funcional, archivos accesibles vía WebDAV |
| **Si falla** | Compensación: borra el pod, limpia PVC |

### Paso 30 — Instalar guacamole (VDI Gateway)

| Campo | Detalle |
|--------|--------|
| **Ficha** | `guacamole` |
| **Servidor** | S11-vdiserver |
| **Depende de** | postgresql, keycloak |
| **Qué hace** | Despliega Apache Guacamole con OIDC — gateway VNC/RDP/SSH para escritorios remotos |
| **Resultado** | Login OIDC funcional, pool de conexiones VNC operativo |
| **Si falla** | Compensación: borra el pod, limpia BD |

### Paso 31 — Instalar fedora-logico (VDI Desktop)

| Campo | Detalle |
|--------|--------|
| **Ficha** | `fedora-logico` |
| **Servidor** | S11-vdiserver |
| **Depende de** | guacamole, nextcloud |
| **Qué hace** | Despliega pods de escritorio Fedora 42 + GNOME con HPA min=2/max=20, home montado desde Nextcloud vía WebDAV |
| **Resultado** | ≥ 2 pods Running, GNOME accesible vía Guacamole |
| **Si falla** | Compensación: borra los pods, limpia HPA |

### Paso 32 — Instalar website-engine (Multi-tenant Web)

| Campo | Detalle |
|--------|--------|
| **Ficha** | `website-engine` |
| **Servidor** | S16-webserver |
| **Depende de** | postgresql, redis |
| **Qué hace** | Despliega el motor de renderizado web multi-tenant — cada tenant tiene su propio sitio en `{tenant}.sbos.app` |
| **Resultado** | Renderizado multi-tenant funcional |
| **Si falla** | Compensación: borra el pod, limpia configuración |

### Paso 33 — Crear usuarios iniciales

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Crea los usuarios definidos en `seed.users` vía JSON-RPC a bauth |
| **Código saga** | `deploy.go:260-266` |
| **Usuario admin** | `admin@skull.sbos.app` con roles `[realm-admin, bos-operator]`, contraseña temporal |
| **Resultado** | Usuario admin puede iniciar sesión |

---

## ETAPA G — CONTEXT PLANE (Pasos 34-35)

El Context Plane ya tiene sus tablas creadas (Paso 18). Ahora se verifica el ciclo
de vida completo de `ctx_id`.

### Paso 34 — Activar Context API y verificar device.register

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Verifica que los 6 endpoints de la Context API en `:9443` responden con TLS 1.3, ejecuta `bos.ctx.device.register` |
| **Endpoints** | `POST /api/v1/context/device.register`, `POST /api/v1/context/heartbeat`, `POST /api/v1/context/promote`, `POST /api/v1/context/switch`, `POST /api/v1/context/invalidate`, `GET /api/v1/context/{ctx_id}` |
| **Resultado** | `device.register` retorna `dctx_id` (UUIDv7), heartbeat 30s renueva TTL en Redis |
| **Redis** | DB1 `context_registry` — lookup O(1) < 1ms P50 |
| **Si falla** | Degrada a memStore — el sistema funciona sin Context Plane persistente |

### Paso 35 — Verificar ciclo promote → switch → invalidate

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Ejecuta el ciclo completo: `dctx_id` → `promote` → `ctx_id` → `switch` (cambio de tenant/dominio) → `invalidate` |
| **Resultado** | `device.register` < 2s P99, `ctx_id` lookup Redis < 1ms P50 |
| **C-13 ✅** | device.register < 2s P99 desde sbos-client |

---

## ETAPA H — VERIFICACIÓN VDI (Pasos 36-37)

El sistema está completamente instalado. La verificación VDI certifica que el
escritorio Fedora funciona y el usuario puede trabajar.

**Código:** `cmd/bosctl/vdi.go` (97 líneas, `vdiVerify`)

### Paso 36 — Ejecutar bosctl vdi verify

| Campo | Detalle |
|--------|--------|
| **Qué hace** | Llama a `bos.query.vdi` vía JSON-RPC, obtiene el semáforo del VDI Layer |
| **Fichas verificadas** | `nextcloud`, `guacamole`, `fedora_logico` |
| **Estados posibles** | `✓ healthy` (pod Running + health check OK), `✗ degradado` (pod Running pero health check falla), `✗ error` (pod no Running) |
| **Semáforo** | `VERDE` si las 3 fichas están healthy |
| **Exit code** | 0 si VERDE, 1 si no |

### Paso 37 — Verificar criterios C-09 a C-14

| Criterio | Qué verifica | Resultado esperado |
|:--------:|-------------|--------------------|
| **C-09** | Nextcloud OIDC | Login vía bauth, archivos accesibles vía WebDAV |
| **C-10** | Guacamole OIDC | Login vía bauth, escritorio VNC/SSH accesible |
| **C-11** | Fedora Lógico | ≥ 2 pods Running, HPA min=2/max=20 |
| **C-12** | Home montado | `ls ~/Documentos` en pod fedora-logico muestra archivos |
| **C-13** | device.register | < 2s P99 desde sbos-client en pod fedora-logico |
| **C-14** | Flujo e2e | test-user → login bauth → GNOME < 10s → crear archivo → persiste en Nextcloud |

```
✅ C-09  Nextcloud OIDC funcional
✅ C-10  Guacamole OIDC funcional
✅ C-11  Fedora Lógico ≥ 2 pods Running
✅ C-12  Home montado en pod fedora-logico
✅ C-13  device.register < 2s P99
✅ C-14  Flujo e2e completo
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
14/14 criterios verificados
✦ "El SBOS está instalado" ✦
```

---

## Resumen de los 37 pasos

| # | Paso | Etapa | Código/Ficha | Criterio |
|:-:|------|:-----:|-------------|:--------:|
| 1 | Copiar binarios bos + bosctl | A | `installBinaries()` | — |
| 2 | Copiar core/ (5 scripts Bash) | A | `installCore()` | — |
| 3 | Copiar blibs/ (112+ fichas) | A | `installBlibs()` | — |
| 4 | Crear .env + bos-install.toml | A | `installEnvTemplate()` | — |
| 5 | Instalar servicios systemd | A | `installServices()` | — |
| 6 | Ejecutar bos-preflight | A | `runPreflightFicha()` | — |
| 7 | bootstrap.Setup() | B | `autoBootstrap()` | — |
| 8 | RBAC + cgroups + bridge | B | `autoBootstrap()` | — |
| 9 | Inicializar 15 subsistemas | C | `runNormal()` | — |
| 10 | Levantar socket Unix + API :9443 | C | `runNormal()` | C-01, C-02 |
| 11 | Instalar Kubernetes (kubeadm) | D | `sbos-bootstrap-k8s` | C-03 |
| 12 | Namespace K8s + NetworkPolicy | D | `sbos-namespace` | — |
| 13 | StorageClass + PVs | D | `sbos-bootstrap-storage` | — |
| 14 | PostgreSQL + 9 bases de datos | D | `postgresql` | C-04 |
| 15 | Redis + Context Registry | D | `redis` | C-05 |
| 16 | Vault + PKI + AppRole | D | `vault` | C-06 |
| 17 | Keycloak + Realm + SPIs | D | `keycloak` | C-07, C-08 |
| 18 | Context Plane DDL | E | `bos.ctx.auto_migrate` | — |
| 19 | bkernel (CDC daemon) | F | `sbos-bkernel` | — |
| 20 | Kong (API Gateway) | F | `kong` | — |
| 21 | bauth (Identity Daemon) | F | `bauth` | — |
| 22 | tryton (ERP) | F | `tryton` | — |
| 23 | bnotify (Push Notifications) | F | `bnotify` | — |
| 24 | bhnexus (Hardware Proxy) | F | `bhnexus` | — |
| 25 | banexus (Edge Sentinel) | F | `banexus` | — |
| 26 | nginx (Reverse Proxy) | F | `nginx` | — |
| 27 | certbot (SSL) | F | `certbot` | — |
| 28 | modsecurity (WAF) | F | `modsecurity` | — |
| 29 | nextcloud (Cloud Storage) | F | `nextcloud` | — |
| 30 | guacamole (VDI Gateway) | F | `guacamole` | — |
| 31 | fedora-logico (VDI Desktop) | F | `fedora-logico` | — |
| 32 | website-engine (Multi-tenant Web) | F | `website-engine` | — |
| 33 | Crear usuarios iniciales | F | `deploy.go:260-266` | — |
| 34 | Activar Context API + device.register | G | Context API :9443 | — |
| 35 | Ciclo promote → switch → invalidate | G | Context API :9443 | C-13 |
| 36 | bosctl vdi verify | H | `vdi.go` | semáforo |
| 37 | Verificar C-09 a C-14 | H | `vdi.go` + manual | C-09..C-14 |

---

## Línea de tiempo estimada

```
T+0:00    Paso 1-6    System-Install (binarios + core + blibs + preflight)
T+2:00    Paso 7-10   Auto-Bootstrap + Run-Normal (C-01 ✅ C-02 ✅)
T+2:00    Paso 11-17  Stack Mínimo — deployTenant PASOS 0-5
T+15:00   Paso 18     Context Plane DDL (C-03 ✅ C-04 ✅ C-05 ✅ C-06 ✅ C-07 ✅ C-08 ✅)
T+15:00   Paso 19-33  Daemons + Aplicaciones + Usuarios (PASO 7 DAG + seed.fichas)
T+27:00   Paso 34-35  Context Plane (device.register < 2s, ctx_id < 1ms)
T+28:00   Paso 36-37  Verificación VDI (C-09..C-14)
T+30:00   ✦ "El SBOS está instalado" ✦
```

---

## Qué existe y qué falta

| Etapa | Pasos | Estado | Qué existe en código | Qué falta implementar |
|:-----:|:-----:|:------:|---------------------|----------------------|
| A — System-Install | 1-6 | ✅ L2 | `system_install.go` (393 líneas). Compila. | Verificar en VPS |
| B — Auto-Bootstrap | 7-8 | ✅ L2 | `auto_bootstrap.go` (89 líneas). Compila. | Verificar en VPS |
| C — Run-Normal | 9-10 | ✅ L2 | `run_normal.go` (445 líneas). Compila. | Verificar en VPS |
| D — Stack Mínimo | 11-17 | ✅ L2 | `deploy.go:122-253`. Saga probada, compensación implementada. | Adaptar Redis a K8s |
| E — Context DDL | 18 | ✅ L2 | `bos.ctx.auto_migrate`. Tablas definidas. | Verificar en VPS |
| F — Daemons y Apps | 19-33 | 🔴 L1-L2 | Paso 7 itera `cfg.Fichas`. DEPENDENCY_RESOLVER (Kahn) ordena. | `task_catalog.sh` de bauth, bnotify, bhnexus, banexus, nextcloud, guacamole, fedora-logico, website-engine |
| G — Context Plane | 34-35 | 🔴 L1 | Código de tipos, servicio, store en `internal/context/`. | Activar 6 endpoints :9443, heartbeat, rate limiting |
| H — Verificación VDI | 36-37 | 🔴 L1-L0 | `vdi.go` (97 líneas) con `vdi verify` y `vdi status`. C-09..C-14 definidos. | Implementar `bos.query.vdi` en el daemon, completar health checks |

---

*SKULL · SBOS · BosAgent · Julio 2026*
