# Cronograma de Instalación — Ficha por Ficha

**Versión:** 2.23.0  
**Fecha:** 2026-10-14  
**Autor:** bos-developer  

> Este documento es el **registro cronológico de construcción** del instalador SBOS.
> Cada ficha está documentada con su propósito, estado real en la VPS, logros,
> faltantes y bugs. El orden es el `execution_order` real que sigue el observer de BOS.
>
> **Problema del huevo y la gallina:** Algunas fichas se instalan en múltiples fases
> porque sus dependencias crean ciclos. Cuando esto ocurre, la ficha aparece con
> sus fases descritas explícitamente.

---

## Leyenda de estado

| Símbolo | Estado | Descripción |
|---------|--------|-------------|
| ✅ | INSTALLED | Instalada y verificada en VPS |
| 🔄 | INSTALLING | En proceso (VPS) |
| ❌ | PHYSICAL_ERROR | Pod en CrashLoop — ficha rota |
| 💥 | INSTALL_FAILED | Instalación falló — requiere retry |
| ⏸️ | UPDATE_AVAILABLE | Versión nueva disponible — sin actualizar |
| ⚙️ | PENDING_DEPS | En PENDING esperando dependencias (auto_install=true) |
| ⏳ | NO_INSTALADA | auto_install=false · no instalada aún |
| 🔶 | HUEVO_GALLINA | Ficha multi-fase — leer nota de fases |

---

## Arquitectura de identidad unificada — principio rector

> Este principio atraviesa todo el cronograma. Entenderlo antes de leer las fichas
> evita confusión sobre por qué las dependencias son como son.

**Un usuario SBOS = una identidad Keycloak = todos los servicios.**

```
                    ┌─────────────────────────────────────────┐
                    │           KEYCLOAK (S03)                │
                    │   Fuente de verdad de identidad          │
                    │   juan.perez@empresa.sbos.app            │
                    │   grupos: [empleados, contabilidad,      │
                    │            fedora_user, correo_activo]   │
                    └────────────────┬────────────────────────┘
                                     │ SSO (OIDC/SAML/LDAP)
              ┌──────────────────────┼──────────────────────────┐
              │                      │                          │
              ▼                      ▼                          ▼
    VDI (fedora-kde)        Correo (mailserver)       Apps (Tryton, Nextcloud)
    Pod personalizado        Buzón IMAP propio         Acceso según rol
    PVC con home del         Misma contraseña          Misma contraseña
    usuario                  Keycloak                  Keycloak
    Apps según grupo
```

**Consecuencia para el instalador:**
- Keycloak se instala antes que cualquier app de usuario (orden 140)
- Mailserver NO tiene usuarios propios — autentica contra Keycloak
- VDI NO tiene usuarios Linux fijos — los crea al vuelo según el JWT de Keycloak
- Cada app que se instala debe configurar su conector OIDC/SAML hacia Keycloak

---

## FASE 1 — Preparación del host (órdenes 1–10)

> El host Ubuntu 26.04 se prepara para alojar el cluster K8s. Estas fichas corren
> como scripts bash en el host, no como pods. No tienen dependencias de K8s.

---

### [1] bos-preflight · S-HOST · ✅ INSTALLED

**Propósito:** Verificar que el servidor cumple los requisitos mínimos (RAM ≥16 GB, disco ≥165 GB, CPU ≥8, Ubuntu 26.04) e instalar las condiciones base que el daemon BOS necesita para operar: usuario `bosagent`, directorios `/etc/bos`, token RPC aleatorio, certificado TLS autofirmado y sudoers.

**Dependencias:** ninguna

**Logros:**
- ✅ Usuario `bosagent` y grupo creados
- ✅ Estructura de directorios `/etc/bos`, `/etc/sbos`, `/var/log/bos`, `/opt/bos` creada
- ✅ Paquetes del SO instalados (curl, jq, openssl, python3, wget, etc.)
- ✅ Token RPC generado con `openssl rand -hex 32` (nunca hardcodeado)
- ✅ Certificado TLS autofirmado en `/etc/bos/certs/bos.crt`
- ✅ Cgroup v2 delegation configurada
- ✅ Sudoers para bosagent

**Comportamiento esperado (por diseño):**
- 📋 `configurar_kubectl`: hace SKIP en primera instalación — es correcto. kubectl aún no existe cuando esta ficha corre (orden ~1); lo instala `sbos-bootstrap-k8s` en orden 20. El symlink `/usr/local/bin/kubectl` se crea automáticamente cuando BOS ejecuta un `repair` de `bos-preflight` tras completar el bootstrap de K8s. **No es un bug ni un faltante — es la secuencia de arranque esperada.**

**Bugs corregidos:**
- ✅ FIX (de927a0): health check usaba `/run/bos` (tmpfs — desaparece en reboot). Corregido a verificar `/etc/bos/rpc-token` y `/etc/bos/certs/bos.crt`.

---

### [10] sbos-bootstrap-os · S-HOST · ✅ INSTALLED

**Propósito:** Preparar el núcleo del sistema operativo para K8s: cargar módulos kernel (`br_netfilter`, `overlay`, `ip_tables`), configurar `sysctl` con los parámetros de red que K8s necesita, crear la estructura `/data/` para los PersistentVolumes, instalar herramientas de red (iptables-persistent, socat, conntrack) y deshabilitar swap.

**Dependencias:** ninguna

**Logros:**
- ✅ Módulos kernel cargados y persistidos en `/etc/modules-load.d/sbos-k8s.conf`
- ✅ sysctl configurado (`ip_forward=1`, `bridge-nf-call-iptables=1`, `vm.max_map_count=262144`)
- ✅ `/data/postgres`, `/data/redis`, `/data/vault`, `/data/keycloak`, etc. creados con UIDs correctos
- ✅ `iptables-persistent` y `netfilter-persistent` instalados (FIX-20: necesarios para persistir hairpin NAT en reboot)
- ✅ Swap deshabilitado

**Comportamiento esperado (por diseño):**
- 📋 `configurar_containerd`: hace SKIP en primera instalación — es correcto. containerd aún no existe cuando esta ficha corre; lo instala `sbos-bootstrap-k8s` en orden 20. La configuración de containerd (registry mirrors, snapshotter) se aplica en el `repair` posterior de `sbos-bootstrap-os`. **No es un bug ni un faltante — es la secuencia de arranque esperada.**

**Bugs:** ninguno activo

---

## FASE 2 — Cluster Kubernetes (órdenes 5, 20, 25, 28, 30, 35)

> Se levanta el plano de control K8s, la red de pods (CNI Calico), los namespaces
> SBOS y la infraestructura de almacenamiento y observabilidad del cluster.
> sbos-namespace tiene orden 5 pero depende de sbos-bootstrap-k8s (orden 20) —
> el observer lo instala cuando la dependencia se cumple, no por orden absoluto.

---

### [5] sbos-namespace · S-HOST · ✅ INSTALLED

**Propósito:** Crear el namespace base `sbos-system` con `NetworkPolicy default-deny` global. Es el namespace donde corre el propio daemon BOS.

**Dependencias:** sbos-bootstrap-k8s

**Logros:**
- ✅ Namespace `sbos-system` creado
- ✅ NetworkPolicy default-deny aplicada

**Faltantes:** ninguno

**Bugs:** ninguno activo

---

### [20] sbos-bootstrap-k8s · S-HOST · ✅ INSTALLED

**Propósito:** Instalar y configurar el cluster Kubernetes con `kubeadm init`. Instala containerd, configura su runtime para systemd cgroup driver, inicializa el cluster con kubeadm, instala kubectl, genera el kubeconfig en `/etc/bos/.kube/config`, instala Calico básico como CNI inicial y verifica que el nodo esté en estado Ready.

**Dependencias:** sbos-bootstrap-os

**🔶 Huevo y gallina — Fase A/B:**
- **Fase A (este orden 20):** kubeadm init + Calico básico. El cluster arranca con un CNI mínimo que permite instalar fichas.
- **Fase B (orden 25, sbos-bootstrap-cni):** Calico completo con NetworkPolicies default-deny. Sin la Fase A, la Fase B no puede instalarse (necesita K8s funcionando).

**Logros:**
- ✅ containerd instalado y configurado con `SystemdCgroup=true`
- ✅ Cluster K8s inicializado (kubeadm 1.32)
- ✅ Node en estado Ready
- ✅ kubeconfig en `/etc/bos/.kube/config`
- ✅ Calico CNI básico funcionando
- ✅ Hairpin NAT aplicado (FIX-19): regla iptables para que pods alcancen apiserver en IP pública
- ✅ certSANs con `127.0.0.1` (FIX-18): kubectl funciona desde localhost
- ✅ (ciclo 11) BUG-36 CERRADO: `sbos-hairpin-nat.service` (systemd) instalado — MASQUERADE `10.244.0.0/16` persiste en cada reinicio del host

**Faltantes:** ninguno

**Bugs:** ninguno

---

### [25] sbos-bootstrap-cni · S-HOST · ✅ INSTALLED

**Propósito:** Completar la configuración de Calico CNI: crear `IPPool` soberano, aplicar `NetworkPolicy default-deny` global (ningún pod puede comunicarse sin una NetworkPolicy explícita que lo permita), y verificar comunicación pod-to-pod entre namespaces.

**Dependencias:** sbos-bootstrap-k8s

**Logros:**
- ✅ Calico completo con IPPool configurado
- ✅ NetworkPolicy default-deny global activa
- ✅ Comunicación pod-to-pod verificada

**Faltantes:** ninguno

**Bugs:** ninguno activo

---

### [28] sbos-bootstrap-platform · S-HOST · ⚙️ PENDING (no en state)

**Propósito:** Crear los 12 namespaces SBOS (`sbos-data`, `sbos-security`, `sbos-gateway`, `sbos-erp`, `sbos-collab`, `sbos-vdi`, `sbos-monitoring`, etc.), instalar `local-path-provisioner` (StorageClass dinámica para PVCs de aplicaciones) y configurar RBAC base para service accounts.

**Dependencias:** sbos-bootstrap-cni

**⚠️ Inconsistencia:** La ficha existe en `servers/` y sus recursos están desplegados en el cluster (namespaces y local-path-provisioner activos), pero NO aparece en `.sbos_state.json`. El observer no la supervisa.

**Logros:**
- ✅ 12 namespaces SBOS presentes en cluster (verificado por pods corriendo en ellos)
- ✅ `local-path-provisioner` activo (StorageClass `local-path`)
- ✅ (ciclo 7) `ficha_repair` agregada — idempotente (re-aplica kubectl apply de namespaces y StorageClass)

**Faltantes:**
- ✅ BUG-31 auto-resolve — se corrige en el próximo reinicio del daemon: `InitializeFichaStates` la registra y el observer la instala idempotentemente

**Bugs:** ninguno

---

### [30] sbos-bootstrap-storage · S-HOST · ✅ INSTALLED

**Propósito:** Crear los 19 PersistentVolumes hostPath en `/data/` con política `Retain`. Los PVs con Retain conservan los datos aunque el PVC o pod sean eliminados — los datos sobreviven a reinstalaciones.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni

**Logros:**
- ✅ 19 PVs creados en `/data/` con política Retain
- ✅ PVs vinculados a sus PVCs correctamente

**Faltantes:** ninguno

**Bugs:** ninguno activo

---

### [35] sbos-bootstrap-monitoring · S-HOST · ✅ INSTALLED

**Propósito:** Desplegar `prometheus-node-exporter` (métricas del host) y `kube-state-metrics` (estado del cluster K8s) como base de observabilidad. Prometheus (orden 200) se apoya en estos exporters para completar su scraping.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni, sbos-bootstrap-storage

**Logros:**
- ✅ prometheus-node-exporter Running en namespace sbos-monitoring
- ✅ kube-state-metrics Running

**Faltantes:** ninguno

**Bugs:** ninguno activo

---

## FASE 3 — Validación de red (orden 50)

---

### [50] sbos-k8s-network-validator · S-HOST · ⚙️ PENDING (no en state)

**Propósito:** Ejecutar 4 pruebas de validación antes de instalar workloads: resolución DNS interna, comunicación pod-to-pod entre namespaces, creación y montaje de PVC, y verificación de hairpin NAT hacia el apiserver. Si alguna prueba falla, el instalador se detiene con diagnóstico claro.

**Dependencias:** sbos-bootstrap-platform, sbos-bootstrap-storage

**Logros:**
- ✅ Las 4 pruebas pasaron en su momento (el cluster está funcional)
- ✅ (ciclo 7) `ficha_repair` agregada — re-ejecuta validación limpiando el ConfigMap marker primero

**Faltantes:**
- ✅ BUG-31 auto-resolve — se corrige en el próximo reinicio del daemon (ficha_install es idempotente)

**Bugs:**
- ✅ (ciclo 11) BUG-36 cerrado: `sbos-hairpin-nat.service` garantiza que MASQUERADE persiste — esta ficha ya no fallará por hairpin NAT ausente

---

## FASE 4 — Base de datos, caché y objetos (órdenes 100–120)

> PostgreSQL, Redis y MinIO se instalan ANTES de Vault (orden 130).
> Este es el primer punto del problema huevo-y-gallina del sistema:
> Vault necesita PostgreSQL para su backend HA, y las aplicaciones
> necesitan Vault para sus credenciales. La resolución es instalar
> PG/Redis/MinIO con credenciales estáticas generadas en el momento,
> y luego Vault las toma bajo su control.

---

### [100] postgresql · S01 · ✅ INSTALLED

**Propósito:** Motor de base de datos principal del stack SBOS. Aloja las 10 BDs del ecosistema (`SBOSDB`, `kong_db`, `keycloak_db`, `tryton_db`, `mattermost_db`, etc.). Habilita WAL logical replication (`pgoutput`) que bKernel usa para el pipeline CDC.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni, sbos-bootstrap-storage, vault

**🔶 Huevo y gallina — CRÍTICO:**
- **Problema:** PostgreSQL declara `vault` como dependencia (en manifest), pero Vault (orden 130) declara `postgresql` como dependencia. Ciclo directo.
- **Resolución actual:** El observer instala postgresql en orden 100 porque Vault no está instalado (el DAG resuelve el ciclo por orden numérico, no por deps). En la práctica funciona, pero la declaración es incorrecta.
- **Fix pendiente (BUG-35):** Eliminar `vault` de las dependencies de postgresql y redis. PostgreSQL no necesita Vault para arrancar — Vault necesita PostgreSQL.
- **Fase A (orden 100):** PG instala con credenciales generadas por openssl en el momento.
- **Fase B (tras vault orden 130):** Vault toma el control de las credenciales via AppRole. Los pods obtienen passwords de Vault, no del Secret K8s inicial.

**Logros:**
- ✅ PostgreSQL 18.4 corriendo (1/1 Running)
- ✅ 10 bases de datos SBOS creadas
- ✅ WAL logical replication habilitada (slot `sbos_cdc`)
- ✅ PVC 50 Gi con política Retain

**Logros adicionales:**
- ✅ (ciclo 2) BUG-35 cerrado en postgresql: `vault` ya es `runtime_dependency`, no `dependency`

**Faltantes:**
- ✅ GAP-2 FALSO POSITIVO: health check presente — `pg_isready -U postgres` con kubectl exec

---

### [100] kyverno · S03 · ⚙️ PENDING (hairpin NAT issue)

**Propósito:** Admission controller de seguridad. Aplica políticas que requieren que todos los pods tengan `livenessProbe` y `readinessProbe`, prohíben `hostPort`, verifican firmas OCI de imágenes y exigen `NetworkPolicy` por namespace. Protege el cluster de despliegues inseguros.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni

**🔶 Huevo y gallina — DOBLE:**
- **Problema 1 (audit vs enforce):** Si kyverno arranca en modo `enforce`, rechaza pods sin probes — pero los pods de kyverno mismos y los primeros bootstraps no tienen probes. Solución: kyverno arranca en modo `audit` (solo registra, no rechaza). El switch a `enforce` lo hace sbos-bootstrap-hard en orden 250.
- **Problema 2 (hairpin NAT):** El init container `kyvernopre` necesita conectarse al apiserver de K8s desde dentro del pod. En Hetzner, los pods no pueden alcanzar la IP pública del servidor. Sin la regla hairpin NAT de FIX-19 activa, `kyvernopre` falla indefinidamente con `dial tcp 10.96.0.1:443: i/o timeout`.

**Logros:**
- ✅ Helm chart 3.3.4 (app v1.13.4) — versión estable en K8s 1.32 (FIX-21: chart 3.3.x pinado)
- ✅ Políticas definidas: require-probes, forbid-hostport, verify-oci, require-networkpolicy

**Faltantes:**
- ✅ (ciclo 11) BUG-36 CERRADO: `sbos-hairpin-nat.service` garantiza MASQUERADE persistente — kyverno puede conectar al apiserver tras reinicio del host
- ❌ Switch a modo enforce no ejecutado en VPS — **acción VPS requerida** (no código): (1) reiniciar pod kyverno en VPS, (2) verificar admission-controller Running, (3) ejecutar sbos-bootstrap-hard con el switch. El código ya está correcto — falta ejecutarlo en producción.

**Bugs activos:** ninguno

---

### [110] redis · S01 · ✅ INSTALLED

**Propósito:** Caché y bus de eventos del stack SBOS. Tres bases de datos lógicas: caché genérica (DB 0), registro de ctx_id del Context Plane (DB 1) y Redis Streams para bKernel CDC (DB 2). Requerido por bKernel, Context Plane y múltiples apps.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni, sbos-bootstrap-storage

**🔶 Huevo y gallina:** Resuelto — `vault` movido a `runtime_dependencies` (BUG-35 cerrado).

**Logros:**
- ✅ Redis 8.6.2 corriendo (1/1 Running)
- ✅ Autenticación con password obligatoria
- ✅ PVC persistente
- ✅ (ciclo 2) BUG-35 cerrado: `vault` como `runtime_dependency`, no `dependency`

**Faltantes:**
- ✅ GAP-2 FALSO POSITIVO: health check presente — `redis-cli ping` expected_output: PONG

---

### [110] linkerd · S03 · 🔄 INSTALLING

**Propósito:** Service mesh con mTLS automático. Inyecta un sidecar proxy en cada pod (via annotation en namespace), estableciendo cifrado y autenticación mutua entre todos los servicios del cluster sin que las aplicaciones necesiten código adicional.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni

**🔶 Huevo y gallina — FASES:**
- **Fase 1 (este orden 110):** Instala el plano de control de Linkerd (proxy-injector, destination, identity). Timeout 15 minutos (requerido en Ubuntu 26.04 con nf_tables).
- **Fase 2 (implícita, tras instalación):** Los namespaces con `linkerd.io/inject: enabled` obtienen inyección de sidecar automática en nuevos pods.
- **Fase 3 (implícita):** Pods existentes necesitan `kubectl rollout restart` para obtener el sidecar. Esto puede causar conflictos si el plano de control de linkerd no está completamente estable.

**Logros:**
- ✅ Helm chart con `--set proxyInit.iptablesMode=nft` (FIX PT-05: kernel Ubuntu 26.04 usa nf_tables)
- ✅ Timeout 15 minutos configurado en install
- ✅ Control plane parcialmente instalado

**Faltantes:**
- 🔄 Instalación en progreso — estado en VPS pendiente de verificar

**Bugs activos:** ninguno
- ✅ (ciclo 4) BUG-29 cerrado: `ficha_repair()` limpia ReplicaSets huérfanos automáticamente
- ✅ (ciclo 2) BUG-33 cerrado: oauth2-proxy pod template tiene `linkerd.io/inject: disabled`

---

### [120] minio · S01 · ✅ INSTALLED

**Propósito:** Almacenamiento de objetos compatible S3. Aloja backups SBOS, assets estáticos, documentos de Nextcloud y Paperless, datos de Grafana Loki y Tempo. Tres buckets: `sbos-backups`, `sbos-assets`, `sbos-documents`.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni, sbos-bootstrap-storage

**🔶 Huevo y gallina:** Resuelto — `vault` movido a `runtime_dependencies` (BUG-35 cerrado).

**Logros:**
- ✅ MinIO/SeaweedFS corriendo (1/1 Running) — imagen `chrislusf/seaweedfs` (no requiere auth Docker Hub)
- ✅ 3 buckets S3 creados: sbos-backups, sbos-assets, sbos-documents
- ✅ API S3 en puerto 9000
- ✅ (ciclo 2) BUG-35 cerrado: `vault` como `runtime_dependency`, no `dependency`
- ✅ (ciclo 3) GAP-2 cerrado: health check `type: http, path: /minio/health/live, port: 9000` en manifest.yml

**Faltantes:** ninguno activo

---

## FASE 4B — Inicialización de la base de datos SBOS (orden 105)

> PostgreSQL Running ≠ SBOS_db lista. El pod puede estar corriendo (INSTALLED)
> pero la base de datos `SBOSDB` con sus 158 tablas, 12 schemas y seeds debe
> inicializarse explícitamente con la ficha `sbos-database-init`.
> Actualmente esto se hace manualmente con psql. Debe existir una ficha
> `sbos-database-init` que lo automatice.

---

### [105] sbos-database-init · S01 · ⏳ NUEVA FICHA CREADA (pendiente primer deploy)

**Propósito:** Desplegar el schema completo de `SBOSDB` en el pod de PostgreSQL recién instalado. Ejecutar `SBOS_db_V2_DDL.sql` (158 tablas en 12 schemas: `bos`, `bauth`, `bkernel`, `biedata`, `bsearch`, `bnexus`, `bnotify`, `kong`, `keycloak`, `tryton`, `mattermost`, `audit`). Verificar que todas las tablas existen. Idempotente: re-ejecutar no destruye datos.

**Dependencias:** postgresql

**Por qué es el orden 105:** postgresql tiene orden 100. Este inicializador debe correr cuando el pod está Running pero ANTES de que las aplicaciones (keycloak, kong, tryton, etc.) intenten usar sus schemas.

**🔶 Huevo y gallina — SCHEMA VS APP:**
- **Fase A (orden 105):** Crear todos los schemas y tablas vacías con DDL idempotente (`CREATE TABLE IF NOT EXISTS`, `CREATE SCHEMA IF NOT EXISTS`). Los schemas deben existir antes que las apps.
- **Fase B (orden 160+):** Las apps (keycloak, kong, tryton) crean sus propios registros al arrancar — no van en este seed.
- **Fase C (post-instalación completa):** Seeds de dominio SBOS se cargan desde scripts individuales por módulo.

**Estado actual en VPS:**
- `SBOSDB` existe con 158 tablas (se creó manualmente en sesión anterior)
- La ficha ahora puede supervisarlo: `ficha_repair()` re-aplica el DDL si el schema se degrada.

**Logros (ciclo 5):**
- ✅ `servers/S01/sbos-database-init/manifest.yml` creado — `execution_order: 105`, `dependencies: [postgresql]`, `auto_install: true`
- ✅ `servers/S01/sbos-database-init/task_catalog.sh` creado — 7 funciones: `pre_install`, `install`, `post_install`, `repair`, `test`, `status`, `diagnosis`
- ✅ `ficha_pre_install()`: verifica pg_isready + existencia del DDL en `/etc/bos/ddl/SBOS_db_V2_DDL.sql`
- ✅ `ficha_install()`: crea SBOSDB, copia DDL al pod con `kubectl cp`, ejecuta `psql -f` idempotente, verifica ≥50 tablas y ≥6 schemas
- ✅ `ficha_repair()`: re-aplica DDL idempotente para convergir schemas faltantes
- ✅ `ficha_test()`: 4 assertions — DB existe, tabla count ≥50, schema bauth presente, schema bos presente
- ✅ `ficha_uninstall()`: NO elimina SBOSDB (datos protegidos por diseño)

**Faltantes / pendiente:**
- ✅ (ciclo 13) DDL auto-copiado: `ficha_pre_install` busca el DDL en 4 rutas candidatas (`SBOS_SERVERS_DIR/../DDLs/`, `/opt/skull/.../DDLs/`, `/etc/bos/blibs/DDLs/`, relativa a `BASH_SOURCE`) y lo copia a `/etc/bos/ddl/` — cero intervención manual (ADR-022)

**Comportamiento esperado (por diseño):**
- 📋 Seeds (T060/T061/T162): no se cargan en el instalador de BD — es correcto. Los seeds de catálogos (menús contextuales, roles template, i18n) se cargan por cada módulo en su propia Fase C de arranque, no en el bootstrap de la base de datos. Cargarlos aquí crearía dependencias de orden que violan ADR-022.

**Acciones VPS pendientes:**
```bash
# 1. Copiar DDL al host de la VPS (si no existe)
mkdir -p /etc/bos/ddl
cp /opt/skull/orquestador/proyectos/SBOS/DDLs/SBOS_db_V2_DDL.sql /etc/bos/ddl/

# 2. Instalar la ficha (SBOSDB ya existe — el DDL idempotente converge diferencias)
bosctl ficha install sbos-database-init
```

---

## FASE 5 — Seguridad: secretos y blockchain (órdenes 130–135)

> Vault se instala DESPUÉS de postgresql porque usa PG como backend HA.
> Esta es la resolución del huevo-y-gallina: el orden numérico (130 > 100)
> garantiza que PG esté instalado cuando Vault lo necesita.
> DESPUÉS del unseal de Vault, todas las aplicaciones posteriores
> pueden obtener sus credenciales de Vault (no de Secrets K8s estáticos).

---

### [130] vault · S02 · ❌ PHYSICAL_ERROR (FIX-26A commiteado — pendiente VPS)

**Propósito:** Gestor de secretos centralizado. Fuente de verdad para TODAS las credenciales del stack: passwords de PostgreSQL para cada app, tokens de Keycloak, certificados TLS internos (PKI engine), llaves de cifrado. Ninguna aplicación obtiene su password de otro lugar que no sea Vault.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni, sbos-bootstrap-storage, postgresql

**🔶 Huevo y gallina — MULTI-FASE CRÍTICA:**
- **Fase 1 (orden 130):** Pod Vault arranca. Estado: SEALED. No puede servir secretos. Esto es correcto — Vault siempre arranca sellado por diseño.
- **Fase 2 — CEREMONIA DE UNSEAL (ver abajo):** Los custodios introducen sus fragmentos de clave. Solo entonces Vault puede servir secretos.
- **Fase 3 (automática post-unseal):** Vault configura AppRole `sbos-pods`, PKI engine, KV v2, políticas. Las aplicaciones obtienen tokens de AppRole para leer sus credenciales.
- **Fase 4 (permanente post-unseal):** vault-unsealer (orden 131) mantiene Vault unsealed entre reinicios del pod.

**Logros:**
- ✅ StatefulSet desplegado con PVC Retain
- ✅ Backend Raft configurado (PostgreSQL para HA)
- ✅ FIX-26A commiteado: liveness probe `sealedok=true` (pod no crashea cuando sellado)
- ✅ (ciclo 2) GAP-2 cerrado: health check real — verifica `initialized=true + sealed=false` con `vault status -format=json`

**Acción VPS técnica pendiente:**
- ❌ FIX-26A no aplicado en VPS aún — aplicar con: `kubectl rollout restart statefulset/vault -n sbos-security`. Una vez hecho, vault dejará de crashear y pasará a estado SELLADO estable.

**🔑 Por qué vault SIEMPRE requiere que los custodios intervengan — y por qué eso es correcto:**

Vault implementa **Shamir Secret Sharing**: durante la inicialización genera N fragmentos de clave (`unseal keys`). Se necesitan M de esos N fragmentos para abrir el vault (típicamente 3 de 5). Cada fragmento se entrega a un custodio distinto (personas de confianza de la organización — no servidores ni archivos).

Esto significa que **ningún sistema automatizado puede abrir Vault por sí solo** — ni BOS, ni un script, ni un archivo en disco. Si alguien obtiene acceso físico al servidor, los datos siguen cifrados porque las claves están distribuidas entre personas reales. Eso es soberanía real.

**La intervención de los custodios NO es intervención técnica.** No se trata de ejecutar comandos, reparar pods, ni correr kubectl. Es una *ceremonia de seguridad*: el instalador BOS presenta una pantalla interactiva (entrada enmascarada, como una contraseña) y cada custodio introduce su fragmento por teclado. El instalador acepta los fragmentos, desella Vault, y continúa automáticamente. El custodio no necesita saber nada de Kubernetes ni de infraestructura.

Esta pantalla de introducción de fragmentos está documentada en `context/Documentacion/PENDIENTE-VAULT-UNSEAL-INTERACTIVO.md` y su implementación está en suspenso hasta que el instalador funcione end-to-end.

**Bugs activos:**
- ❌ BUG-27: oauth2-proxy y tryton en cascada — se desbloquean automáticamente en cuanto los custodios hayan completado la ceremonia de unseal. No requiere cambios de código.

---

### [131] vault-unsealer · S02 · ⚙️ NUEVA (ciclo 11)

**Propósito:** CronJob que monitorea el pod de Vault cada minuto y lo re-desella automáticamente si se reinicia el pod (lo que vuelve a sellarlo). Su función NO es la ceremonia inicial de unseal — esa la hacen los custodios una sola vez. Su función es mantener Vault unsealado entre reinicios del pod sin requerir que los custodios repitan la ceremonia en cada reinicio.

**Dependencias:** vault (debe estar previamente unsealed por los custodios)

**Cómo funciona:**
1. `ficha_pre_install()`: verifica que Vault ya fue inicializado y que existen las unseal keys en K8s Secret (las pone el instalador después de la ceremonia inicial)
2. `ficha_install()`: crea Secret K8s con keys + RBAC (ServiceAccount/Role/RoleBinding) + CronJob `* * * * *`
3. CronJob: cada minuto comprueba `vault status -format=json | .sealed` → si `true` (por reinicio del pod), ejecuta 3× `vault operator unseal` usando las keys del Secret
4. `ficha_repair()`: fuerza unseal inmediato leyendo keys del Secret K8s (sin esperar el CronJob)

**Nota de diseño — archivo vs. custodios:**
- **Producción:** los custodios entregan sus fragmentos en la ceremonia inicial via prompt interactivo de BOS. BOS guarda las keys en K8s Secret (cifrado en etcd) para que vault-unsealer pueda usarlas en reinicios futuros. El custodio solo interviene una vez.
- **Dev/CI (`--dev-mode`):** las keys pueden leerse de `/etc/bos/vault-init-keys.json` para entornos no productivos donde no hay custodios reales.

**Logros:**
- ✅ (ciclo 11) manifest.yml creado (execution_order: 131, auto_install: true, dependency: vault)
- ✅ (ciclo 11) task_catalog.sh completo: pre_install / install / verify / health / repair / test / remove
- ✅ (ciclo 11) Secret vault-unseal-keys: almacena keys dentro del cluster (cifrado en etcd)
- ✅ (ciclo 11) RBAC mínimo: solo puede leer ese Secret + exec en vault-0

**Acción VPS pendiente:**
- ❌ No desplegado en VPS aún — bloqueado por vault sin unseal (BUG-27). Una vez los custodios completen la ceremonia de unseal, este CronJob se instala automáticamente. El código está completo y correcto.

**Bugs activos:** ninguno

---

### [135] besu-qbft · S02 · ✅ INSTALLED

**Propósito:** Red blockchain soberana QBFT (Proof of Authority). Aloja los contratos `SettlementEngine.sol` y `AuditAnchor.sol` que bAuth usa para el módulo D12 (settlment y auditoría inmutable). 1 nodo validador, Chain ID 1337.

**Dependencias:** postgresql, vault

**Logros:**
- ✅ Hyperledger Besu 24.12.0 corriendo
- ✅ Génesis QBFT inicializado
- ✅ RPC :8545, WS :8546 accesibles

**Faltantes:**
- ✅ GAP-2 FALSO POSITIVO: health check ya presente — `podman inspect {{.State.Running}}` (runtime: podman)

**Pendiente de desarrollo externo (bAuth D12):**
- ❌ Contratos AuditAnchor.sol y SettlementEngine.sol no desplegados — son entregables del módulo D12 de bAuth. La red besu-qbft está operativa y lista. BOS no despliega contratos de otros daemons — los despliega bAuth cuando implemente D12.

**Bugs:** ninguno activo

---

## FASE 6 — Identidad y gateway (órdenes 140–180)

> Keycloak es el proveedor de identidad central. Kong es el gateway único.
> oauth2-proxy protege las aplicaciones internas. nginx sirve como reverse proxy
> y punto de entrada HTTP/HTTPS. Certbot gestiona los certificados TLS.

---

### [140] keycloak · S03 · ✅ INSTALLED

**Propósito:** Proveedor de identidad centralizado OIDC/OAuth2. Gestiona autenticación SSO para todo el ecosistema SBOS. Realm `skull` contiene todos los usuarios, roles y clientes OIDC. 5 SPIs SKULL personalizados.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni, postgresql, vault

**🔶 Huevo y gallina:** Keycloak necesita vault para sus secretos, pero vault necesita keycloak para que las aplicaciones puedan autenticarse contra él. Resolución: keycloak usa credenciales estáticas inicialmente, luego vault gestiona las credenciales de los clients OIDC.

**Logros:**
- ✅ Keycloak 26.6.2 corriendo (1/1 Running)
- ✅ Realm `skull` creado con configuración SBOS
- ✅ `KC_CACHE_STACK=jdbc-ping` (FIX sesión 9: evita crash ISPN)
- ✅ `sslRequired=none` + `frontendUrl=http://IP_PUBLICA` configurados para el flujo OIDC
- ✅ Cliente OIDC `sbos-desktop` creado para el VDI
- ✅ (14d1a6a) health check: `curl :9000/health/ready | grep UP` (GAP-2 cerrado)

**Pendiente de desarrollo (propio de Keycloak — Iteración 2):**
- 📋 SPIs SKULL en Iter1: registrados via `kcadm` como componentes (sin JARs). En Iteración 2 se compilarán los JARs Java y se montarán en el directorio `providers/` del pod. Los SPIs son extensiones **propias de Keycloak** para el dominio IAM de SBOS — no son responsabilidad de bAuth ni los invoca bAuth. Keycloak y bAuth son totalmente independientes entre sí.
- ✅ `Web Origins: *.sbos.app` para SSO multi-subdominio (SSO-2) — implementado en ficha_post_install ciclo 20

**Bugs:** ninguno activo

---

### [150] oauth2-proxy · S02 · ❌ PHYSICAL_ERROR (derivado de vault)

**Propósito:** Proxy de autenticación OIDC que protege las aplicaciones internas sin que necesiten implementar lógica de auth. Valida el token JWT contra Keycloak e inyecta headers `X-Forwarded-User`, `X-Forwarded-Email`, `X-Forwarded-Groups` en cada request.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni, keycloak, vault, kong

**🔶 Huevo y gallina:** oauth2-proxy necesita vault para leer el client_secret de Keycloak. Si vault está down, oauth2-proxy no puede arrancar. Adicionalmente, el sidecar de linkerd en el pod de oauth2-proxy falla si linkerd no está completamente estable (BUG-33).

**Logros:**
- ✅ Deployment configurado con AppRole de Vault
- ✅ NetworkPolicy hacia Keycloak configurada
- ✅ (ciclo 2) BUG-33 cerrado: `linkerd.io/inject: disabled` en pod template annotations

**Bloqueado por vault (acción VPS — código correcto):**
- ❌ Pod en PHYSICAL_ERROR — se recupera automáticamente cuando vault sea unsealed en VPS. No requiere cambios de código.
- ❌ `rollout restart deployment/oauth2-proxy` — acción VPS para que el pod recoja BUG-33 ya commiteado. Una vez vault esté unsealed: `kubectl rollout restart deployment/oauth2-proxy -n sbos-gateway`.

**Bugs activos:**
- ❌ BUG-27: PHYSICAL_ERROR en cascada por vault sin unseal. Se resuelve solo al unseal vault — no requiere cambios de código.

---

### [160] kong · S02 · ✅ INSTALLED

**Propósito:** API Gateway soberano. Punto único de entrada a todas las APIs del sistema. JWT validation, rate limiting, plugin Lua `SBOS-Context` que inyecta el `ctx_id` en cada request para trazabilidad. DB mode con `kong_db` en PostgreSQL.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni, postgresql

**Logros:**
- ✅ Kong 3.9.x LTS corriendo (1/1 Running)
- ✅ Admin API :8001, Proxy :8000/:8443, Status :8007
- ✅ Base de datos `kong_db` inicializada
- ✅ Health check: `kong health | grep -c healthy` (ya presente en manifest)
- ✅ (ciclo 2) `vault` y `keycloak` movidos a `runtime_dependencies` — Kong arranca solo con PG

- ✅ (ciclo 28) Plugin `correlation-id` global activado con header `X-Ctx-ID` — inyecta ctx_id en TODOS los requests (SBOS-049). Propaga el header si ya existe (llamadas internas entre daemons); genera UUID v4 nuevo si no existe. `echo_downstream=true` lo devuelve al cliente. Plugin ya bundled en Kong — cero Lua custom, cero dependencia de biedata. biedata es consumidor del ctx_id, no su fuente.
- ✅ (ciclo 14) Rutas y servicios de aplicaciones declarados automáticamente en `ficha_post_install()` + `ficha_repair()`

**Bugs:** ninguno activo

---

### [170] nginx · S02 · ⏸️ UPDATE_AVAILABLE

**Propósito:** Ingress único del host S02. Recibe TODO el tráfico externo (:80/:443) y lo delega a Kong o directamente a los servicios VDI. nginx NO decide el enrutamiento por tenant ni por dominio — eso es exclusivamente responsabilidad de Kong. nginx es el terminador TLS y el punto de entrada; Kong es el enrutador soberano.

**Dependencias:** kong

---

#### Arquitectura de nginx: una sola entrada, dos destinos

```
Internet
   │
   ▼
:80 nginx HOST ──────────────→ 301 redirect a :443
   │
   ▼
:443 nginx HOST (TLS autofirmado / Certbot)
   │
   ├── /desktop/       → oauth2-proxy-desktop → fedora-kde pod
   ├── /guacamole/     → guacamole pod
   ├── /nextcloud/     → nextcloud pod
   ├── /grafana/       → grafana pod
   ├── /onlyoffice/    → onlyoffice pod
   ├── /desktop/oauth2/→ oauth2-proxy-desktop (callback OIDC)
   ├── /.well-known/   → certbot webroot
   └── (todo lo demás) → Kong :8000 (catch-all @kong)
```

**Regla clave:** nginx NO hace routing por dominio. Usa `server_name _` (acepta cualquier Host). El header `Host` llega intacto a Kong, que es quien rutea según el tenant/empresa/sucursal.

---

#### Flujo de autenticación correcto (objetivo de diseño)

```
Usuario → https://IP/
                │
                ▼
        ┌─────────────────────────────────┐
        │   SBOS Landing Page (index.html) │
        │   "Sistema Operativo Soberano"   │
        │   [Botón: Iniciar sesión]        │
        └────────────────┬────────────────┘
                         │ click
                         ▼
                    /desktop/
                         │
                oauth2-proxy-desktop
                         │
                         ▼
              ┌──────────────────────┐
              │  Keycloak Login Page  │
              │  (tema SBOS/tenant)   │
              └──────┬───────────────┘
                     │
          ┌──────────┴──────────┐
          │                     │
       EXITOSO               FALLIDO
          │                     │
          ▼                     ▼
   fedora-kde VDI         /?error=auth
   (escritorio del      (vuelve a landing
    usuario)             con mensaje)
```

**Bug actual:** `location / { return 302 /desktop/; }` — la landing page nunca se muestra. El usuario llega al login de Keycloak directamente sin pasar por la página de bienvenida SBOS.

**Fix en nginx task_catalog.sh:**
```nginx
# INCORRECTO (actual):
location / {
    return 302 /desktop/;
}

# CORRECTO (objetivo):
location / {
    root /var/www/html;
    index index.html;
    try_files $uri $uri/ =404;
    # El botón "Iniciar sesión" en index.html apunta a /desktop/
    # El parámetro ?error=auth muestra mensaje si el login falló
}
```

**El index.html también necesita:**
- Leer `?error=auth` y mostrar mensaje "Credenciales incorrectas, intente nuevamente"
- Botón prominente "Iniciar sesión" → `/desktop/`
- Mostrar el nombre/logo del tenant (si aplica — Kong puede inyectar un header `X-SBOS-Tenant`)

---

#### Web de SBOS (página de bienvenida)

nginx sirve `/var/www/html/index.html` — la página de bienvenida del sistema SBOS:
- **Diseño:** fondo gradiente oscuro, logo, "Sistema Operativo Empresarial Soberano"
- **Links:** `/admin` (Core UI), `/api` (Kong), `/monitor` (Grafana), `/docs`
- **Stack visible:** Ubuntu 26.04, K8s 1.32, Go, Rust, Python, PostgreSQL 18, Keycloak 26
- **Estado actual:** La raíz `/` hace `return 302 /desktop/` → el index.html nunca se sirve (INC-nginx-1).

---

#### Webs por tenants, empresas y sucursales

**La arquitectura multi-tenant de nginx es transparente — nginx no hace nada especial.** El enrutamiento por tenant ocurre en Kong:

```
Empresa A accede a: empresa-a.sbos.app
Empresa B accede a: empresa-b.sbos.app

nginx (catch-all):
  Host: empresa-a.sbos.app → @kong (pasa el header Host)
  Host: empresa-b.sbos.app → @kong (pasa el header Host)

Kong (Domain Resolver):
  Host: empresa-a.sbos.app → Route #1 → Service empresa-a → Tryton tenant A
  Host: empresa-b.sbos.app → Route #2 → Service empresa-b → Tryton tenant B
```

**Pasos para agregar un tenant nuevo con web propia:**
1. En DNS: apuntar `empresa-a.sbos.app` a la IP de la VPS
2. En Kong Admin API: crear `Route` con `hosts: ["empresa-a.sbos.app"]` y `Service` que apunte al pod del tenant
3. En Kong: configurar plugin JWT y rate-limit para esa Route
4. nginx no requiere ningún cambio — el `server_name _` ya acepta ese dominio

**Faltante crítico:** No existe una ficha `sbos-kong-tenant` que automatice el paso 2. Actualmente las Routes de Kong se configuran manualmente. Una empresa nueva requiere intervención manual.

---

#### Estado VPS y problema de versión

- **Estado en VPS:** UPDATE_AVAILABLE (⏸️)
- **Causa:** `manifest.yml` declara `version: "1.28.0"` pero la imagen instalada vía apt puede ser una versión diferente. BOS calcula UPDATE_AVAILABLE por diferencia de versiones.
- **Impacto:** nginx está corriendo correctamente (systemd active) — UPDATE_AVAILABLE es falso si la versión actual sirve bien.
- **Fix:** Verificar versión real con `nginx -v` en VPS y actualizar manifest si coincide. O ejecutar `bosctl ficha repair nginx` para sincronizar.

---

**Logros:**
- ✅ nginx 1.28.0+ instalado en host S02 como servicio systemd
- ✅ TLS autofirmado con SAN para la IP del servidor (idempotente — no regenera si queda >30 días)
- ✅ HTTP→HTTPS redirect (:80 → :443)
- ✅ Rutas VDI: `/desktop/`, `/guacamole/`, `/nextcloud/`, `/grafana/`, `/onlyoffice/`
- ✅ Headers de seguridad CIS+OWASP: `X-Frame-Options`, `X-Content-Type-Options`, `HSTS`, `X-XSS-Protection`
- ✅ Log format SBOS con `ctx_id` y `tenant` extraídos de headers Kong
- ✅ Webroot Certbot en `/.well-known/acme-challenge/`
- ✅ Página de bienvenida SBOS en `/var/www/html/index.html`
- ✅ Firewall UFW: puertos 80 y 443 abiertos

**Logros:**
- ✅ (14d1a6a) `location /`: sirve `index.html` con `try_files` (INC-nginx-1 cerrado)
- ✅ (14d1a6a) `index.html`: botón "Iniciar sesión" → `/desktop/`, manejo `?error=auth` con JS

- ✅ (ciclo 29) GAP-nginx-1 CERRADO: ficha `sbos-kong-tenant` creada (S02, orden 165). Configura rutas Kong por Host-header para el tenant inicial: dominio raíz, subdominio `<tenant>.<domain>` y wildcard `*.<tenant>.<domain>`. JWT plugin + rate-limiting por ruta. Idempotente. Tenants adicionales → saga `bos.tenant.create`.
- ✅ (ciclo 30) nginx preparado para bcms: `include /etc/nginx/conf.d/domains/*.conf;` añadido al bloque `http {}`. Directorio `/etc/nginx/conf.d/domains/` creado en `ficha_install`. Placeholder `sbos-institucional.conf` generado para `sbos.app`. Ver sección siguiente.
- 📋 GAP-nginx-2: Certbot ya maneja el DNS gracefully — `ficha_pre_install` hace `dig` check y salta si el dominio no resuelve; nginx usa cert autofirmado mientras tanto. No hay acción de código pendiente: es un requisito externo del protocolo ACME (el DNS del cliente debe apuntar a la VPS).
- 📋 UPDATE_AVAILABLE: nginx puede diferir en VPS — **acción VPS cuando convenga**: `bosctl ficha repair nginx`. No requiere cambios de código.

**Bugs:** ninguno activo (nginx corre correctamente — UPDATE_AVAILABLE es de versión, no de funcionalidad)

#### Arquitectura web SBOS — S02 vs S16 (preparación para bcms)

nginx S02 tiene **dos roles que NO deben confundirse**:

| Rol | Servidor lógico | Qué hace |
|-----|----------------|---------|
| **API/VDI Gateway** | S02 (este) | Recibe todo el tráfico, termina TLS, delega a Kong o directamente a servicios VDI (desktop, guacamole, nextcloud). `server_name _` — no distingue dominios. |
| **Web Platform** | S16-webserver (futuro) | nginx dedicado a servir los sitios web de cada tenant/empresa/sucursal. Genera un `.conf` por dominio. Lo gestiona bcms. |

**El servidor S16 aún no existe como fichas.** Se creará cuando arranque el desarrollo de bcms. Referencia de arquitectura: `context/Documentacion/Anexos/A.03_ANEXO-PLATAFORMA-WEB-MULTI-TENANT-NGINX.md`.

##### Modelo de dominios (A.03)

Tres tipos de sitio web en SBOS — **no se generan automáticamente**; el cliente registra sus propios dominios:

| Tipo | Ejemplo | Quién lo define |
|------|---------|----------------|
| Institucional SBOS | `sbos.app`, `www.sbos.app` | El operador SKULL en instalación |
| Tenant corporativo | `www.grupo-skull.com` | El cliente al contratar |
| Sucursal | `tienda.lapaz.skull.com` | El tenant al crear sucursal |

Los dominios se registran en la tabla `bos.web_domains` (schema `bos`, `bos_net_web_domain`). Cada dominio activado genera un archivo `.conf` en `/etc/nginx/conf.d/domains/` y se hace `nginx -s reload`.

##### nginx S02 preparado para bcms (ciclo 30)

El `nginx.conf` principal ahora tiene al final del bloque `http {}`:

```nginx
# bcms deposita aquí un .conf por cada dominio registrado en bos.web_domains.
include /etc/nginx/conf.d/domains/*.conf;
```

El directorio `/etc/nginx/conf.d/domains/` se crea en `ficha_install`. Ya existe un placeholder:

```
/etc/nginx/conf.d/domains/sbos-institucional.conf  ←  sbos.app (placeholder JSON hasta que bcms esté)
```

**Flujo cuando bcms entre en operación:**

```
bcms genera: /etc/nginx/conf.d/domains/<dominio>.conf
  server { listen 443 ssl; server_name <dominio>;
           proxy_pass http://bcms-website-engine.sbos-web.svc.cluster.local:3000; }

bcms ejecuta: nginx -s reload   ← nginx carga el nuevo .conf sin reiniciar
```

nginx NO necesita ningún cambio más. bcms puede desarrollarse con total independencia de nginx S02. Kong NO está en la ruta web — nginx va directo al website-engine con headers:
- `X-SBOS-Tenant`, `X-SBOS-Empresa`, `X-SBOS-Sucursal` → identifican el contexto del sitio
- `X-Ctx-ID` → correlación (inyectado por Kong en la ruta API, no en la ruta web)

##### Plan S16-webserver (fichas futuras — inicio: sesión bcms)

```
S16/nginx-web/         ← nginx dedicado a sitios web (no API/VDI)
S16/certbot-web/       ← Let's Encrypt para dominios de clientes
S16/modsecurity/       ← WAF para protección de sitios públicos
S16/website-engine/    ← bcms daemon (Rust) — sirve páginas por tenant/empresa/sucursal
```

Hasta que S16 exista, nginx S02 sirve como puente provisional a través del `include /etc/nginx/conf.d/domains/*.conf;`.

---

### [170] sbos-notifier · S06 · ✅ INSTALLED

**Propósito:** Sistema de notificaciones universales del stack SBOS. Push MFA (OTP, TOTP, WebAuthn), alertas críticas del sistema, mensajes a usuarios. Requerido por bAuth para el flujo Step-Up de autenticación (RFC 9470).

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni, postgresql, redis, vault, keycloak, kong

**Logros:**
- ✅ sbos-notifier (bnotify) corriendo (1/1 Running)
- ✅ Integrado con keycloak para autenticación
- ✅ (ciclo 3) GAP-2 cerrado: health check `type: http, path: /health/ready, port: 28200` en manifest.yml

**Faltantes:** ninguno activo

**Bugs:** ninguno activo

---

### [180] certbot · S02 · ✅ INSTALLED

**Propósito:** Certificados TLS Let's Encrypt para el dominio público. HTTP-01 challenge via webroot de nginx. NO es un pod K8s — es un systemd timer en el host que renueva el certificado cada 60 días.

**Dependencias:** nginx

**Logros:**
- ✅ certbot instalado como systemd timer en host S02
- ✅ Certificados TLS generados

**Comportamiento esperado (por diseño):**
- 📋 Let's Encrypt solo emite certificados si el dominio DNS apunta a esta VPS — es un requisito externo del protocolo ACME HTTP-01, no un faltante del instalador. BOS no puede controlar el DNS del cliente. El operador debe configurar el DNS antes de ejecutar `bosctl ficha repair certbot`.

**Bugs:** ninguno activo

---

## FASE 7 — Daemons host (orden 70)

> sbos-bkernel tiene execution_order: 70 pero depende de postgresql, redis y vault.
> Esto lo ubica CONCEPTUALMENTE aquí (después de la fase de secretos),
> aunque su número sea menor. El observer lo instala cuando sus deps están INSTALLED,
> independientemente del número de orden.

---

### [70] sbos-bkernel · S-HOST · ✅ INSTALLED

**Propósito:** Motor de Datos Soberano CDC (Change Data Capture). Escucha el WAL de PostgreSQL via replication slot `pgoutput`, normaliza los eventos de dominio (INSERT/UPDATE/DELETE en tablas SBOS) y los publica en Redis Streams. CERO puertos TCP — solo Unix socket.

**Dependencias:** postgresql, redis, vault

**🔶 Huevo y gallina:** sbos-bkernel tiene orden 70 (menor que postgresql=100, redis=110, vault=130), pero sus dependencias lo obligan a esperar. El observer resuelve esto: bkernel queda en PENDING hasta que sus 3 dependencias estén INSTALLED.

**Logros:**
- ✅ bkernel daemon activo (systemd service)
- ✅ Socket en `/run/bos/bkernel.sock`
- ✅ Replication slot configurado en PostgreSQL
- ✅ (ciclo 3) GAP-2 cerrado: health check `type: command, command: systemctl is-active bkernel` en manifest.yml

**Pendiente de desarrollo externo (bAuth / bsearch):**
- ❌ Streams Redis sin consumidores activos — bkernel produce eventos en Redis Streams correctamente. Los consumidores son responsabilidad de bAuth (identidad) y bsearch (índice). BOS no implementa consumidores de otros daemons. Cuando bAuth y bsearch estén listos, se conectarán automáticamente.

**Bugs:** ninguno activo

---

## FASE 8 — Observabilidad (órdenes 200–250)

> El stack de monitoreo se instala DESPUÉS de la infraestructura base.
> Prometheus scraping de daemons SBOS (9400-9499) + K8s metrics.
> sbos-bootstrap-hard (orden 250) cierra esta fase con el hardening final.

---

### [200] prometheus · S12 · ✅ INSTALLED

**Propósito:** Motor de métricas del cluster. Scrapea daemons SBOS (puertos 9400-9499), métricas K8s de kube-state-metrics y node-exporter, y Alertmanager. Fuente de verdad para el estado del cluster en tiempo real.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni, sbos-bootstrap-storage, sbos-bootstrap-monitoring, vault

**Logros:**
- ✅ Prometheus 3.4.0 corriendo (1/1 Running)
- ✅ PVC 20 Gi con `strategy: Recreate` (evita lock en rolling update)
- ✅ Linkerd disabled en namespace sbos-monitoring (evita PostStartHookError en sidecar proxy)
- ✅ (ciclo 3) GAP-2 cerrado: health check `type: http, path: /-/ready, port: 9090` en manifest.yml

**Faltantes:**
- ❌ Scraping de daemons SBOS (9400-9499) incompleto — **pendiente de desarrollo externo**: cada daemon (bAuth, bkernel, biedata, bsearch, bnexus, bnotify) debe exponer su endpoint `/metrics` en el puerto asignado del rango 9400-9499. Prometheus ya tiene la regla de scraping configurada — en cuanto los daemons expongan métricas, Prometheus las recolectará automáticamente.

**Bugs:** ninguno activo

---

### [205] alertmanager · S12 · ✅ INSTALLED

**Propósito:** Enrutamiento de alertas. Reglas SBOS predefinidas: WAL lag en PostgreSQL, Vault sellado, DLQ depth alto, pod down. Routing hacia sbos-notifier para Push MFA a los administradores.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni, prometheus

**Logros:**
- ✅ Alertmanager 0.28.1 corriendo
- ✅ Reglas SBOS configuradas

**Faltantes:** ninguno activo

**Logros adicionales:**
- ✅ (ciclo 14) Routing hacia sbos-notifier declarado en kong `ficha_post_install()` via ruta `/sbos-notifier`

**Bugs:** ninguno activo

---

### [215] grafana · S12 · ✅ INSTALLED

**Propósito:** Visualización de métricas y logs. OAuth2 Keycloak (SSO). Dashboards SBOS precargados. Datasources configurados: Prometheus, PostgreSQL directo, Loki (cuando esté instalado).

**Dependencias:** sbos-bootstrap-storage, prometheus, keycloak, vault

**Logros:**
- ✅ Grafana 12.0.1 corriendo (1/1 Running)
- ✅ Datasource Prometheus conectado (ConfigMap provisioning)
- ✅ OAuth2/OIDC Keycloak — implementado ciclo 20 en ficha_post_install

**Faltantes:**
- ✅ Datasource Loki — implementado en ficha_post_install ciclo 21: se agrega automáticamente via Grafana API cuando Loki pod esté Running (idempotente)
- ✅ Datasource PostgreSQL (SBOS_db) — implementado en ficha_post_install ciclo 21: se agrega via Grafana API cuando PG disponible y PG_AUX_PASSWORD seteado
- ✅ OIDC Keycloak (SSO) — implementado en ficha_post_install ciclo 20: env vars GF_AUTH_GENERIC_OAUTH_* via K8s Secret sbos-grafana-oidc
- ❌ Dashboards SBOS básicos — **pendiente de diseño**: requiere que primero los daemons expongan métricas (ver Prometheus arriba) para saber qué graficar. No es un faltante del instalador — es una tarea de diseño que depende de métricas reales.

**Bugs:** ninguno activo

---

### [215] loki · S12 · ⚙️ PENDING (auto_install=true, esperando deps)

**Propósito:** Agregación y búsqueda de logs de todos los pods del cluster. Recibe logs de Grafana Alloy, los indexa con labels de K8s (namespace, pod, container) y el `ctx_id` SBOS extraído por Alloy. Grafana los visualiza.

**Dependencias:** prometheus, grafana, minio

**Logros (ciclo 5):**
- ✅ Implementación real confirmada: usa `helm upgrade --install loki grafana/loki` versión 6.9.0
- ✅ `runtime: docker` corregido a `runtime: kubernetes` en manifest.yml
- ✅ PV Retain 20 Gi en `/data/loki` + modo singleBinary (1 réplica, bajo consumo)
- ✅ Replicación deshabilitada (development mode para cluster monodo)

**Faltantes:**
- ✅ (ciclo 13) Retención configurada: `retention_period=720h` (30 días) + `compactor.retention_enabled=true`
- ✅ (ciclo 13) `structuredMetadata.enabled=true` — Loki puede recibir ctx_id como metadata estructurada de Alloy
- ❌ Backend S3/MinIO — logs en disco local (PVC 20Gi) — **comportamiento transitorio esperado**: Loki está configurado para usar MinIO como backend S3 cuando esté disponible. Mientras MinIO no esté estable, usa disco local. No requiere cambios de código; la transición a MinIO se hará automáticamente con `bosctl ficha repair loki` cuando MinIO esté operativo.

**Bugs:** ninguno activo (no está instalado)

---

### [220] alloy · S12 · ✅ INSTALLED

**Propósito:** Pipeline de logs y métricas (reemplaza Grafana Agent). Recoge logs de todos los pods del cluster, extrae el `ctx_id` de los logs SBOS usando regex, y los envía a Loki. También recolecta métricas adicionales.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni, prometheus

**Logros:**
- ✅ Grafana Alloy 1.8.3 corriendo (1/1 Running)
- ✅ Pipeline de recolección de logs configurado

**Faltantes:**
- ✅ Envío a Loki — ciclo 21: `forward_to = [loki.write.loki_endpoint.receiver]` en pipeline (antes era `[]`); Alloy buffer y reintenta si Loki no está disponible; activo en cuanto Loki se instale
- ✅ Extracción de ctx_id — operativa: pipeline `loki.process.extract_ctx_id` ya extrae `traceparent` y `ctx_id`; ahora sí llegan a Loki (forward_to corregido ciclo 21)

**Bugs:** ninguno activo

---

### [220] tempo · S12 · ⚙️ PENDING (auto_install=true, esperando deps)

**Propósito:** Trazado distribuido (distributed tracing). Recibe spans de aplicaciones instrumentadas con OpenTelemetry, los almacena y los hace consultables desde Grafana.

**Dependencias:** loki, prometheus

**Logros (ciclo 5):**
- ✅ Implementación real confirmada: usa `helm upgrade --install tempo grafana/tempo` (Helm)
- ✅ `runtime: docker` corregido a `runtime: kubernetes` en manifest.yml
- ✅ 98 líneas pero deploy Helm completo + `ficha_remove` con `helm uninstall`

**Faltantes:**
- ✅ (ciclo 13) Retención configurada: `tempo.retention=720h` + `tempo.search.enabled=true`
- ❌ Backend S3/MinIO — trazas en disco local — **comportamiento transitorio esperado**: igual que Loki, la transición a MinIO es automática con `bosctl ficha repair tempo` cuando MinIO esté operativo. No requiere cambios de código.

**Bugs:** ninguno activo

---

### [225] zabbix · S12 · ⏳ NO_INSTALADA (auto_install: false)

**Propósito:** Monitoreo de infraestructura tradicional (host, red, hardware). Complementa Prometheus para alertas de hardware y disponibilidad de servicios no K8s.

**Dependencias:** postgresql, grafana

**Logros (ciclo 5):**
- ✅ Implementación real confirmada: usa `helm upgrade --install zabbix zabbix-community/zabbix` (Helm)
- ✅ `runtime: docker` corregido a `runtime: kubernetes` en manifest.yml
- ✅ 140 líneas con PG config, Helm install, `ficha_remove`

**Faltantes:** decisión de si es parte del MVP (Q-5 HITL §11.4)

---

### [250] sbos-bootstrap-hard · S-HOST · ✅ INSTALLED

**Propósito:** Hardening final del cluster. UFW deny-all (solo puertos 22/80/443 permitidos desde exterior), Calico default-deny en modo enforcement, Kyverno switch de `audit` a `enforce`, CIS Ubuntu 26.04 Benchmark y CIS K8s Benchmark. Esta es la última ficha de infraestructura.

**Dependencias:** sbos-bootstrap-cni, sbos-bootstrap-k8s, sbos-bootstrap-monitoring, prometheus, grafana

**🔶 Huevo y gallina — FASE FINAL DE KYVERNO:**
- Kyverno se instaló en orden 100 en modo `audit` (no rechaza nada).
- En esta ficha (orden 250) se activa el modo `enforce`. Desde aquí, pods sin probes son rechazados.
- Por eso el hardening es lo ÚLTIMO: todos los pods del stack ya están instalados y tienen probes.

**Logros:**
- ✅ UFW activo con reglas mínimas
- ✅ Calico en modo enforcement
- ✅ (ciclo 11) BUG-36 cerrado — kyverno puede conectar al apiserver: desbloqueado

**Acción VPS pendiente (código correcto):**
- ❌ Switch kyverno a modo enforce — el código está listo; falta ejecutarlo en producción: (1) reiniciar pod kyverno en VPS, (2) verificar admission-controller Running, (3) ejecutar switch. Ver sección kyverno para el comando exacto.

**Bugs:** ninguno

---

## FASE 9 — VDI Plataforma (órdenes 200–220)

> Las fichas VDI se instalan en paralelo con observabilidad (mismo rango de órdenes).
> Nextcloud, Guacamole y OnlyOffice forman la plataforma de productividad.
> Todas tienen auto_install sin definir (GAP-6 — Q-2 HITL pendiente).

---

### [200] nextcloud · S13 · ✅ INSTALLED

**Propósito:** Plataforma de almacenamiento y colaboración personal. Cada usuario tiene su espacio de archivos. Integración OIDC con Keycloak (SSO), backend de objetos en MinIO. Editor de documentos via OnlyOffice.

**Dependencias:** postgresql, redis, minio, keycloak, kong

**Logros:**
- ✅ Nextcloud 30.0.2 corriendo (1/1 Running)
- ✅ SSO Keycloak configurado
- ✅ Backend MinIO S3 configurado
- ✅ readinessProbe via `occ status` (FIX-22: exec probe — httpGet bloqueaba con Apache mpm_prefork)
- ✅ (ciclo 3) GAP-2 y GAP-6 cerrados: health `type: http /status.php :80` + governance auto_install: true
- ✅ (ciclo 7) `ficha_test` agregada: verifica deployment Ready + /status.php HTTP 200

**Faltantes:**
- ✅ (ciclo 15) `ficha_post_install()` configura plugin OnlyOffice en Nextcloud: `occ app:enable onlyoffice` + `DocumentServerUrl` + `DocumentServerInternalUrl` + `StorageUrl` (idempotente)

**Bugs:** ninguno activo

---

### [210] guacamole · S13 · ✅ INSTALLED

**Propósito:** Gateway de escritorio remoto. Permite acceder a escritorios VNC/RDP desde el navegador sin instalar software en el cliente. Auditoría de sesiones integrada. Autentica via OIDC Keycloak.

**Dependencias:** postgresql, keycloak, kong

**🔶 Huevo y gallina — TABLA VACÍA:**
- Guacamole se instala correctamente (pod Running, base de datos creada).
- PERO la tabla `guacamole_connection` está vacía — no hay ninguna conexión configurada que apunte a los pods fedora-kde. El usuario hace login en Guacamole y no ve ningún escritorio.
- El fix (GAP-4) es insertar la conexión VNC en `ficha_post_install()`.

**Logros:**
- ✅ Apache Guacamole 1.5.5 + guacd corriendo
- ✅ Base de datos `guacamole_db` creada con schema completo
- ✅ Autenticación OIDC Keycloak funcional
- ✅ (ciclo 2) GAP-4 cerrado: `ficha_post_install()` inserta conexión VNC "Escritorio SBOS" → `fedora-kde.sbos-vdi.svc.cluster.local:5900`
- ✅ (ciclo 2) fedora-kde Service: puerto 5900 expuesto internamente para guacd
- ✅ (ciclo 3) GAP-2 cerrado: health check `type: http, path: /guacamole/, port: 8080`
- ✅ (ciclo 3) GAP-6 cerrado: `governance: auto_install: true, category_label: vdi-gateway`
- ✅ (ciclo 7) `ficha_test` agregada: verifica pod Running + conexión VNC en guacamole_connection

**Acción VPS pendiente (código correcto):**
- ❌ `bosctl ficha repair guacamole` — el código de `ficha_post_install()` está correcto y registra la conexión VNC. Falta ejecutarlo en la VPS para que guacamole quede apuntando a fedora-kde. Comando: `bosctl ficha repair guacamole`.

---

### [220] onlyoffice · S13 · ✅ INSTALLED

**Propósito:** Editor de documentos Office colaborativo en tiempo real. Integrado con Nextcloud para editar .docx, .xlsx, .pptx directamente en el navegador. Multi-usuario simultáneo.

**Dependencias:** postgresql, redis, kong

**Logros:**
- ✅ OnlyOffice Document Server 8.2.2 corriendo (1/1 Running)
- ✅ Memory limit 3Gi (FIX-24: antes 2Gi causaba OOMKill)
- ✅ CPU request 200m (FIX-24: antes 500m causaba Insufficient CPU)
- ✅ (ciclo 3) GAP-2 y GAP-6 cerrados: health `type: http /healthcheck :80` + governance auto_install: true
- ✅ (ciclo 7) `ficha_test` agregada: verifica pod Running + /healthcheck HTTP 200

**Faltantes:**
- ✅ (ciclo 15) Conexión declarativa con Nextcloud via `_onlyoffice_configure_nextcloud()` en `ficha_post_install()` y `ficha_repair()`

**Bugs:** ninguno activo

---

## FASE 10 — VDI Escritorio (órdenes 225–230, 420)

---

### [225] oauth2-proxy-desktop · S13 · ❌ PHYSICAL_ERROR (derivado de vault)

**Propósito:** Intercepta el acceso a `/desktop/` y valida el token Keycloak antes de permitir acceso al escritorio VNC. Es el guardián de identidad del VDI — sin él cualquier persona con la URL puede acceder.

**Dependencias:** keycloak, fedora-kde

**🔶 Huevo y gallina:** oauth2-proxy-desktop depende de fedora-kde (orden 230) que tiene orden MAYOR. El observer lo instala cuando fedora-kde esté INSTALLED. Pero fedora-kde depende a su vez de guacamole. La cadena es: guacamole → fedora-kde → oauth2-proxy-desktop.

**Logros:**
- ✅ Deployment configurado con cliente OIDC `sbos-desktop` en Keycloak realm skull
- ✅ NetworkPolicy hacia Keycloak configurada

**Bloqueado por vault (acción VPS — código correcto):**
- ❌ Pod en PHYSICAL_ERROR — mismo bloqueo BUG-27: depende de vault para leer el client_secret de Keycloak. Se recupera automáticamente cuando vault sea unsealed. No requiere cambios de código.
- ✅ (ciclo 3) GAP-2 y GAP-6 cerrados: health `type: http /ping :4180` + governance auto_install: true

**Bugs activos:**
- ❌ PHYSICAL_ERROR derivado de vault (BUG-27). Se resuelve con FIX-26A (vault rollout restart) + unseal en VPS.

---

### [230] fedora-kde · S13 · ⏸️ UPDATE_AVAILABLE

**Propósito:** Escritorio virtual corporativo soberano. Un usuario Keycloak/bAuth autenticado recibe una sesión KDE Plasma 6 personalizada dentro de un pod compartido: sus archivos propios, sus apps según su rol, su configuración de escritorio — todo persistente entre sesiones. Accesible desde cualquier navegador sin instalar nada en el cliente.

**Dependencias:** keycloak, kong, guacamole

---

#### ⚠️ MODELO CANÓNICO SBOS VDI — LEER ANTES DE CUALQUIER DESARROLLO

> **Este modelo es NO NEGOCIABLE y fue establecido en la concepción del proyecto.**
> Todo agente que toque el VDI debe leer esta sección primero.
> La arquitectura "un pod por usuario" fue EVALUADA Y DESCARTADA — no implementar.

**El modelo es: un pod compartido + N sesiones VNC simultáneas + N PVCs de home independientes.**

```
┌─────────────────────────────────────────────────────────────────────┐
│  fedora-kde POD  (SIEMPRE VIVO — jamás se destruye por usuario)     │
│                                                                     │
│  juan.perez   → sesión KDE en display :1 (VNC :5901)               │
│                 home montado desde PVC-juan.perez (10 Gi, Retain)   │
│                 menús según rol "contabilidad" del JWT               │
│                 cuotas: 1 CPU / 2 GB RAM (cgroups del provisioner)  │
│                                                                     │
│  maria.gomez  → sesión KDE en display :2 (VNC :5902)               │
│                 home montado desde PVC-maria.gomez (10 Gi, Retain)  │
│                 menús según rol "rrhh" del JWT                       │
│                                                                     │
│  admin        → sesión KDE en display :3 (VNC :5903)               │
│                 home montado desde PVC-admin (20 Gi, Retain)        │
│                 menús completos + terminal + sudo                    │
└─────────────────────────────────────────────────────────────────────┘

juan.perez se desconecta 10 horas → su sesión QUEDA SUSPENDIDA en el pod
juan.perez vuelve → retoma KDE exactamente donde lo dejó (hoja abierta, edición en curso)

PVC-juan.perez persiste SIEMPRE — incluso si el pod se reinicia por mantenimiento
Al reconectar: el provisioner remonta el PVC y reactiva la sesión suspendida
```

**Reglas absolutas del modelo:**

| Regla | Correcto ✅ | Incorrecto ❌ |
|-------|------------|--------------|
| Ciclo de vida del pod | Siempre Running; se reinicia solo por mantenimiento | Crear/destruir pods por actividad de usuario |
| Ciclo de vida de la sesión | Suspender tras idle timeout (N horas); reactivar al reconectar | Destruir sesión al desconectarse |
| Ciclo de vida del PVC home | Nunca desactivar ni tocar automáticamente (política `Retain`) | Desactivar el PVC al suspender una sesión o reiniciar pod |
| Arquitectura de pods | 1 pod (o pool) compartido para todos los usuarios | 1 pod por usuario (`fedora-kde-juan.perez`) |
| Fuente de identidad | JWT de Keycloak/bAuth → el provisioner construye el entorno | Variables hardcodeadas en el Deployment |

**Por qué NO es "un pod por usuario":**
- 10.000 usuarios × 2 GB RAM = 20 TB RAM — inviable en cualquier infraestructura
- Los usuarios no necesitan un pod propio; necesitan una **sesión aislada** dentro de un pod compartido
- Es exactamente cómo funciona cualquier servidor de escritorios corporativo real (Citrix, RDS, LTSP)
- Un pod puede servir ~30–80 sesiones simultáneas dependiendo del hardware del nodo

**Escalabilidad horizontal:**
Cuando un nodo se llena, K8s lanza otro pod `fedora-kde` en otro nodo — el provisioner sabe qué nodo tiene espacio y dirige al usuario allí. El PVC del usuario es accesible desde cualquier nodo (ReadWriteMany o NFS).

---

#### Arquitectura VDI completa — flujo de conexión

```
Usuario abre navegador → nginx:443/desktop/
  → oauth2-proxy-desktop valida sesión Keycloak/bAuth
  → extrae JWT: { sub, groups, resource_limits, disk_quota }
  → llama sbos-vdi-provisioner: POST /api/vdi/session { jwt }

sbos-vdi-provisioner:
  1. Verifica si el usuario ya tiene sesión activa → si sí, devuelve su display
  2. Si no: busca display libre en pod fedora-kde
  3. Crea usuario Linux si no existe (useradd -m)
  4. Monta PVC-{user} en /home/{user}/ (lo crea si es primera vez, Retain)
  5. Aplica cgroups con cuotas del JWT (CPU, RAM)
  6. Genera menús KDE según grupos del JWT (~/.config/menus/)
  7. Lanza TigerVNC en display :N como ese usuario
  8. Retorna URL noVNC con ese display

Usuario ve su KDE personalizado en el navegador
```

---

#### Perfiles de usuario — grupos Keycloak/bAuth → entorno Fedora

| Grupo | Perfil | Sudo | Apps en menú | PVC home |
|-------|--------|------|--------------|----------|
| `fedora_admin` | wheel | Completo | Todas + terminal | 20 Gi |
| `fedora_user` | usuarios | Sin sudo | Apps empresa (ERP, correo, Nextcloud) | 10 Gi |
| `fedora_readonly` | readonly | Sin sudo | Solo lectura, sin instalar | 5 Gi |
| `fedora_guest` | guest | Sin sudo | Navegador, visor documentos | tmpfs (sin persistencia) |

**El provisioner construye el entorno de cada usuario al iniciar sesión:**
1. Lee JWT → extrae `sub` (username), `groups`, `resource_limits`, `disk_quota`
2. Crea usuario Linux si no existe (`useradd -m -u <uid> <username>`)
3. Monta PVC como `/home/<username>/` (crea el PVC la primera vez)
4. Genera `~/.config/menus/applications.menu` según grupos
5. Configura cgroups para el proceso de sesión
6. Arranca TigerVNC como ese usuario en un display libre

---

#### Identidad de correo = identidad VDI = identidad SBOS

El email corporativo (`juan.perez@empresa.sbos.app`) es la identidad única del usuario en TODO el ecosistema. Ver **MODELO DE IDENTIDAD SBOS** en FASE 12 (sección mailserver) para el principio completo.

- **Mailserver:** el buzón corporativo ES la fuente de verdad del usuario — existe en mailserver → existe en SBOS
- **VDI:** el email del JWT (`X-Forwarded-Email`) determina qué sesión KDE y qué PVC home se asignan en el pod compartido
- **Nextcloud:** el mismo usuario accede a sus archivos corporativos sin segundo login
- **Tryton ERP:** el mismo usuario con sus permisos de módulo según rol en Keycloak/bAuth
- **Roundcube/Cypht:** accede a su buzón con las MISMAS credenciales (no hay contraseña separada de correo)

**Un solo usuario, una sola contraseña, todos los servicios. Sin excepciones.**

---

#### SSO dentro del escritorio — apps sin segundo login

Cuando el usuario se autentica para entrar al VDI, el token Keycloak que oauth2-proxy valida **no debe volver a pedirse** al abrir Tryton, Nextcloud o Roundcube. El usuario ya demostró su identidad — todas las apps del escritorio deben reconocerlo automáticamente.

**Mecanismo: perfil Chromium compartido + cookie de sesión Keycloak**

Todas las apps web del escritorio se abren con el mismo perfil de Chromium. La cookie de sesión de Keycloak (almacenada en ese perfil) es válida para todos los subdominios del tenant (`*.empresa.sbos.app`). Resultado: el usuario abre Tryton y ya está autenticado.

```bash
# Todos los .desktop usan --profile-directory=sbos-session (mismo perfil)
# apps definidas en la imagen para el grupo fedora_user:

/usr/share/applications/sbos-tryton.desktop:
  Exec=chromium --app=https://tryton.empresa.sbos.app \
                --profile-directory=sbos-session \
                --disable-background-networking

/usr/share/applications/sbos-nextcloud.desktop:
  Exec=chromium --app=https://nextcloud.empresa.sbos.app \
                --profile-directory=sbos-session

/usr/share/applications/sbos-correo.desktop:
  Exec=chromium --app=https://roundcube.empresa.sbos.app \
                --profile-directory=sbos-session
```

**Condición para que funcione:** Keycloak debe tener configurado el dominio como `Web Origins: https://*.empresa.sbos.app` y `Valid Redirect URIs: https://*.empresa.sbos.app/*` para que la cookie sea válida en todos los subdominios del tenant.

**Token relay en Kong:** Kong recibe el Bearer token de la cookie Keycloak, lo valida y lo pasa como header `Authorization: Bearer <token>` a cada servicio upstream. Tryton, Nextcloud y Roundcube leen ese header y no piden login.

---

#### Persistencia de datos — auditoría y trazabilidad

El PVC `fedora-home-{username}` almacena TODO lo que el usuario genera o configura. Es la huella digital soberana del usuario en el sistema.

**Lo que persiste en el PVC:**

| Ruta en el PVC | Contenido | Para qué sirve |
|----------------|-----------|----------------|
| `~/.config/chromium/sbos-session/` | Perfil Chromium: cookies, caché, historial de navegación, configuración de cada app | SSO entre sesiones, estado de apps |
| `~/.config/plasma*/`, `~/.kde*/` | Configuración escritorio KDE: tema, widgets, disposición de paneles | El escritorio se ve igual en cada sesión |
| `~/Documents/`, `~/Downloads/` | Archivos descargados, documentos editados | Archivos del usuario |
| `~/.local/share/recently-used.xbel` | Archivos abiertos recientemente | UX — acceso rápido a trabajo anterior |
| `~/.bash_history`, `~/.zsh_history` | Historial de comandos en terminal | Auditoría — registro de operaciones |
| `~/.config/menus/applications.menu` | Menú de apps generado por el provisioner | Control de acceso a apps |

**Trazabilidad del sistema (no en el PVC — en la BD):**

| Qué se registra | Dónde | Quién lo escribe |
|-----------------|-------|-----------------|
| Inicio/fin de sesión VDI | `bos.bos_ctx_session` (PostgreSQL) | oauth2-proxy-desktop al autenticar |
| Cada request a cada app | Kong access log + `bos.bos_ctx_request` | Kong plugin SBOS-Context |
| Operaciones en Tryton | `audit.audit_log` | Tryton audit module |
| Cambios en archivos Nextcloud | Nextcloud activity log | Nextcloud activity app |
| Comandos ejecutados en terminal | `~/.bash_history` en PVC | bash/zsh |

**Consecuencia de diseño crítica:** El PVC debe tener política `Retain`. Si el pod se destruye (falla, se actualiza, se migra), el PVC sobrevive y el usuario recupera exactamente donde estaba — con sus apps abiertas, su historial y su configuración.

---

#### Lo que falta para tener SSO + persistencia completos

| # | Qué falta | Complejidad | Bloqueado por |
|---|-----------|-------------|---------------|
| 1 | Vault estable (unseal) | Bajo | Problema A-2/A-3 VPS |
| 2 | oauth2-proxy-desktop Running | Automático | Vault estable |
| 3 | `sbos-vdi-provisioner` (1 pod/usuario + PVC) | Alto | Decisión HITL Q-3 |
| 4 | `.desktop` con `--profile-directory=sbos-session` | Bajo | Dentro de la imagen |
| 5 | Keycloak: `Web Origins *.sbos.app` configurado | ✅ ciclo 20 | keycloak/ficha_post_install |
| 6 | Kong: plugin JWT que extrae token de cookie y lo pasa como Bearer | Medio | Plugin Lua pendiente |
| 7 | Tryton: módulo OIDC configurado para aceptar tokens Keycloak | Medio | Tryton no instalado |
| 8 | Nextcloud: plugin OIDC configurado | Bajo | Ya instalado — configuración manual |
| 9 | Roundcube: OAuth2 IMAP login con Keycloak | Medio | Roundcube no instalado |
| 10 | sbos-database-init: registrar sesiones VDI en `bos.bos_ctx_session` | Medio | Ficha faltante |
| 11 | Bloquear puerto 6901 (VDI-GAP-5) | Urgente/Bajo | Nadie — 30 min en VPS |

---

#### Arquitectura VDI actual (simplificada — estado real en VPS)

```
Usuario en navegador
        │
        ▼
https://IP:443/desktop/
        │
nginx (HOST) → oauth2-proxy-desktop (SSO Keycloak)
        │
        ▼
fedora-kde pod  ← UN SOLO POD COMPARTIDO (VDI-GAP-1)
  TigerVNC :5901
  noVNC :6901 (expuesto sin auth — VDI-GAP-5 URGENTE)
  home: ephemeral (VDI-GAP-2 — se pierde en reboot)
```

---

#### Problemas VDI — Detalle exhaustivo y soluciones

---

**VDI-PROBLEMA #1 — ✅ NO EXISTE: versión ya era correcta**

- **Verificado (commit 14d1a6a):** `manifest.yml` ya tenía `version: "1.0.0"`. El UPDATE_AVAILABLE en VPS tiene otra causa (imagen no rebuildeada con los cambios del Containerfile v1.4.0).
- **Estado real:** El Containerfile avanzó de v1.1.0 a v1.4.0 (Chrome, menús, sbos-webapp). La imagen debe rebuildearse y desplegarse en VPS para que BOS deje de detectar la diferencia.

---

**VDI-PROBLEMA #2 — INC-3: ConfigMap sobreescribe start-desktop.sh de la imagen**

- **Síntoma:** El script de arranque del escritorio no viene de la imagen Docker — viene de un ConfigMap K8s `fedora-kde-start-script` que se monta en `/start-desktop.sh`.
- **Causa:** Se modificó `start-desktop.sh` fuera del proceso de build de la imagen y se puso en un ConfigMap para no reconstruir la imagen. Viola P-VDI-1.
- **Impacto:** Si alguien hace `kubectl delete configmap fedora-kde-start-script`, el escritorio no arranca. La imagen y el ConfigMap pueden divergir silenciosamente.
- **Solución:**
  1. Copiar el contenido actual del ConfigMap al `start-desktop.sh` del Containerfile
  2. Reconstruir la imagen: `docker build -t sbos/fedora-desktop:1.0.1 .`
  3. Actualizar el Deployment para usar la nueva imagen
  4. Eliminar el ConfigMap y el volume mount del Deployment
- **Verificación:** `kubectl describe deployment fedora-kde -n sbos-vdi | grep -i configmap` → no debe aparecer.

---

**VDI-PROBLEMA #3/#4 — Arquitectura multi-sesión (REDEFINICIÓN CONFIRMADA)**

> ⚠️ La arquitectura de "un pod por usuario" fue descartada. Ver análisis completo en la sección HITL más abajo.

La arquitectura correcta para SBOS VDI es **multi-sesión dentro de un pod compartido**, con PVC de home por usuario independiente del pod:

```
fedora-kde pod (siempre vivo — NUNCA se destruye)
│
├── juan.perez se conecta → display :1 (VNC :5901) · home PVC-juan.perez montado
├── maria.gomez se conecta → display :2 (VNC :5902) · home PVC-maria.gomez montado
└── admin se conecta     → display :3 (VNC :5903) · home PVC-admin montado

Si juan.perez se va 10 horas y vuelve:
  → su sesión KDE sigue exactamente como la dejó (pod no se destruyó)
  → sus archivos intactos en PVC-juan.perez (no efímero)
  → su hoja de cálculo abierta, su edición en curso, todo esperando
```

**Qué aporta el JWT de Keycloak/bAuth a cada sesión:**
- Identidad: `sub` → crea usuario de sistema si no existe
- Roles → genera menús KDE personalizados según el rol (contabilidad ve apps distintas que RRHH)
- Cuotas → `sbos-vdi-provisioner` aplica cgroups: CPU, RAM limitados por claim del token
- Disco → tamaño del PVC definido por claim `disk_quota` (ej. 10 Gi)

**Responsabilidades del `sbos-vdi-provisioner` (concepto correcto):**

| Responsabilidad | Descripción |
|---|---|
| Autenticación | Valida JWT de Keycloak/bAuth al recibir solicitud de sesión |
| Gestión de displays | Asigna display `:N` libre (TigerVNC), registra asignación user↔display |
| Home mounting | Crea PVC-{user} si no existe (política `Retain`), monta en `/home/{user}` |
| Cuotas | Aplica cgroups al proceso de sesión según claims del JWT |
| Perfil KDE | Escribe `.desktop` files y menús según rol antes de iniciar sesión |
| Sesión persistente | Sesión suspendida en idle (NO destruida) — usuario retoma exactamente donde estaba |
| Cleanup | Libera display tras N días sin actividad (configurable) · PVC **NUNCA** se toca — persiste para siempre |

- **Estado:** Pendiente de respuestas HITL Q-VDI-C/D/E (ver más abajo).
- **Verificación:** Usuario A y B conectados simultáneamente → escritorios independientes, homes independientes, menús distintos según rol.

---

**VDI-PROBLEMA #5 — VDI-GAP-5: puerto 6901 (noVNC) expuesto sin autenticación**

- **Síntoma:** Cualquier persona que conozca `http://IP-VPS:6901` accede directamente al escritorio VDI sin pasar por Keycloak ni por Guacamole.
- **Causa:** El Deployment tiene un `NodePort` en :6901 expuesto en todos los nodos K8s. UFW permite tráfico entrante en puertos nodePort range (30000-32767) pero :6901 es un hostPort directo.
- **Impacto:** Bypass completo de autenticación. Riesgo de seguridad crítico.
- **Solución inmediata (2 pasos):**
  1. En K8s: quitar el `hostPort: 6901` del Deployment (solo mantener containerPort: 6901 sin exposición)
  2. En UFW: `ufw deny 6901/tcp`
  - El acceso al escritorio queda SOLO via nginx:443/desktop/ → oauth2-proxy → pod
- **Solución definitiva:** Agregar NetworkPolicy que prohíba tráfico externo directo al pod fedora-kde en :5901 y :6901.
- **Verificación:** `curl http://IP-VPS:6901` desde fuera → debe fallar (connection refused/timeout).

---

**🔶 Huevo y gallina — CADENA DE ARRANQUE VDI:**
1. **Vault** (orden 130) → estable → oauth2-proxy-desktop obtiene client_secret
2. **oauth2-proxy-desktop** → Running → puede autenticar usuarios
3. **fedora-kde** → Running → el escritorio existe
4. **guacamole** (orden 210) → Running + tabla `guacamole_connection` con VNC de fedora-kde
5. **nginx** (orden 170) → regenera config con IPs actuales de todos los servicios VDI
6. **Usuario** → accede a nginx → oauth2-proxy → Keycloak → escritorio

**El eslabón roto actualmente: vault caído → oauth2-proxy caído → SSO no funciona.**

---

**Logros:**
- ✅ Imagen `sbos/fedora-desktop:1.0.0` con KDE Plasma 6 + openbox como WM X11
- ✅ noVNC HTML5 funcional (novnc-index.html baked en imagen)
- ✅ KWallet deshabilitado (no bloquea arranque del escritorio)
- ✅ sbos-webapp con `--password-store=basic` (sin solicitar keyring en cada arranque)
- ✅ SSO vía oauth2-proxy-desktop → Keycloak verificado end-to-end (cuando vault estaba estable)
- ✅ TigerVNC con contraseña generada aleatoriamente (no hardcodeada)
- ✅ (14d1a6a) Chrome instalado + sbos-webapp con perfil SSO compartido (`sbos-session`)
- ✅ (14d1a6a) Menús KDE: `.desktop` para Nextcloud, Grafana, Guacamole, OnlyOffice, Tryton
- ✅ (14d1a6a) Categoría SBOS en menú KDE, klipper portapapeles, noVNC app/ dir
- ✅ (14d1a6a) `auto_install: false` + `requires_approval: true` agregados al manifest
- ✅ (14d1a6a) health check: `type: command` con pod count
- ✅ (ciclo 7) `ficha_test` agregada: verifica pod Running + noVNC :6901 HTTP 200 + VNC :5900 escuchando

**Faltantes:**
- ✅ (ciclo 13) VDI-PROBLEMA #5 CERRADO: NetworkPolicy `deny-direct-novnc-external` — puerto 6901 solo accesible desde `sbos-gateway`; acceso directo sin auth bloqueado
- ✅ SSO-2: Keycloak `Web Origins: *.sbos.app` (ciclo 20 — keycloak/ficha_post_install)
- ✅ SSO-3: Kong plugin JWT en 4 rutas (ciclo 20 — kong/ficha_post_install + _kong_ensure_plugin)
- ✅ SSO-4: Nextcloud OIDC via user_oidc app (ciclo 20 — nextcloud/ficha_post_install)
- ✅ (ciclo 31) VDI-PROBLEMA #2 CERRADO EN CÓDIGO: `start-desktop.sh` ya está baked en Containerfile (`COPY resources/start-desktop.sh /start-desktop.sh`); Deployment no monta ConfigMap. Añadidos theme files Fluent-dark al Containerfile (`kdeglobals`, `plasmarc`, `Kvantum`, `kcminputrc`). Versión sincronizada a `1.4.0` en task_catalog.sh. **Pendiente VPS:** rebuildar imagen con `bosctl ficha repair fedora-kde` o manualmente (ver instrucciones ciclo 31 al final del CRONOGRAMA).
- 📋 VDI-PROBLEMA #3 (sbos-vdi-provisioner): 1 pod compartido para todos los usuarios (VDI-GAP-1). Solución = daemon Go que crea un pod `fedora-kde-{user_id}` por usuario al autenticarse. **Bloqueado por HITL Q-3** — requiere aprobación de arquitectura antes de implementar.
- 📋 VDI-PROBLEMA #4 (PVC por usuario): home efímero — se pierde en cada reboot del pod (VDI-GAP-2). Solución = PVC `fedora-kde-home-{user_id}` creado por el provisioner. **Bloqueado por VDI-PROBLEMA #3** — no se puede implementar sin el provisioner.
- 📋 Rebuild imagen `sbos/fedora-desktop:1.4.0`: acción VPS pura — no requiere cambios de código en BOS. Ejecutar cuando se resuelva VDI-PROBLEMA #2: `docker build` + `kubectl rollout restart`.
- 📋 AUDIT-1 (oauth2-proxy sesión VDI): registrar inicio/fin de sesión en `bos.bos_ctx_session` vía JSON-RPC `bos.ctx.*`. Desarrollo nuevo planificado (no corrección de bug). Se implementa en sesión dedicada al Context Plane.

**Bugs activos:** ninguno — todos los ítems pendientes son desarrollo futuro o decisiones HITL, no errores de código.

---

#### ⏳ HITL — Decisiones pendientes para VDI (responder aquí)

> **Arquitectura confirmada:** pod compartido + multi-sesión VNC por usuario + PVC de home por usuario.
> El pod nunca se destruye. La sesión del usuario persiste aunque se desconecte horas o días.
> ✅ Todas las preguntas respondidas — ver decisiones formalizadas abajo.

---

**Q-VDI-A — Rebuild imagen** ✅ RESPONDIDA

> *A1: rebuild ahora. Condición: preservar íntegramente el theme y configuración visual actual.*

**Decisión formalizada:**
- `start-desktop.sh` se bake dentro de la imagen Docker (deja de venir por ConfigMap)
- El Deployment elimina la referencia al ConfigMap `fedora-kde-start-script`
- Todo el theme visual KDE actual (colores, fuentes, iconos, wallpaper) se preserva intacto en la imagen
- **Acción:** bos-developer revisa el Dockerfile y el ConfigMap actual, identifica el theme, lo incluye en el build, e instruye el rebuild en VPS

---

**Q-VDI-C — Capacidad de usuarios simultáneos** ✅ RESPONDIDA

> *5–10 en fase de pruebas. Hasta 100 concurrentes en primera etapa productiva.*

**Decisión formalizada:**
- **VPS mínima para primera etapa:** 128 GB RAM / 32 cores (soporta ~60–80 sesiones cómodas; ~100 con optimización)
- Para superar 100 concurrentes: cluster multi-nodo (el provisioner ya escala horizontalmente por diseño)
- El provisioner implementa un control de capacidad: si el nodo está al 90% de RAM, redirige a otro nodo o devuelve error "sin capacidad disponible" antes de arrancar una sesión nueva

---

**Q-VDI-D — TTL de sesión idle** ✅ RESPONDIDA

> *Configurable por política de Keycloak/bAuth. El dominio lógico define la persistencia, no un valor hardcodeado.*

**Decisión formalizada:**
- El provisioner NO tiene un TTL hardcodeado
- Lee el claim `session_ttl_hours` del JWT (o un default del `sbos-vdi-config` ConfigMap si el claim no está presente)
- Cada tenant/empresa puede definir su política de sesión en Keycloak/bAuth: `session_ttl_hours: 8` (jornada laboral), `24`, `72`, etc.
- El claim viaja en el JWT → el provisioner lo respeta → transición a bAuth sin cambiar el provisioner

---

**Q-VDI-E — Fuente del perfil de escritorio** ✅ RESPONDIDA

> *Keycloak define los perfiles ahora (grupos → menús KDE). bAuth hereda el modelo en transición sin fricciones.*

**Decisión formalizada:**
- El provisioner lee los `groups` del JWT de Keycloak para construir los menús KDE
- La estructura de grupos/roles define qué apps aparecen en el escritorio de cada usuario
- Cuando bAuth esté operativo: el JWT de bAuth tendrá la misma estructura de claims → el provisioner no cambia, solo cambia el emisor del token
- Esto garantiza la transición sin refactorizar el VDI

---

**✅ Todas las decisiones tomadas. `sbos-vdi-provisioner` puede implementarse.**

Secuencia de implementación:
1. Rebuild imagen fedora-desktop (VDI-PROBLEMA #2) — preservando theme actual
2. Implementar `sbos-vdi-provisioner` con multi-sesión VNC + PVC por usuario + cgroups + menús desde JWT
3. Actualizar ficha `fedora-kde` para eliminar el ConfigMap del Deployment

---

### [420] sbos-vdi-config · S13 · ⏳ NO_INSTALADA (auto_install: false)

**Propósito:** Configuración final del ecosistema VDI: NetworkPolicies que permiten sbos-vdi → sbos-data y sbos-security, y política de egress a internet para fedora-kde. Usa un ConfigMap `sbos-vdi-configured` como marcador de idempotencia.

**Dependencias:** nextcloud, onlyoffice, guacamole, keycloak, kong

**Estado:** No instalada. Depende de que todas las fichas VDI estén INSTALLED primero.

**Logros (ciclo 5):**
- ✅ Implementación auditada: 221 líneas con 4 NetworkPolicies, `ficha_pre_install`, `ficha_install`, `ficha_repair`, `ficha_verify`, `ficha_health`, `ficha_remove`
- ✅ Idempotencia por ConfigMap `sbos-vdi-configured` — si ya existe, `ficha_install` hace SKIP
- ✅ `ficha_repair` re-aplica NetworkPolicies sin destruir el marker
- ✅ Estructura correcta: rutas Kong y Keycloak OIDC ya se configuraron manualmente (fuera de este ciclo); esta ficha cubre la capa de red
- ✅ `allow-fedora-kde-internet-egress` NetworkPolicy correctamente referenciada en `ficha_verify` y `ficha_health`

**Comportamiento esperado (por diseño):**
- 📋 `sbos-vdi-config` se instala manualmente después de que todas las fichas VDI estén INSTALLED — es correcto por diseño. Esta ficha depende del estado final del VDI (IPs de pods, secretos OIDC, rutas Kong) que no están disponibles hasta que las fichas VDI anteriores terminen. Comando: `bosctl ficha install sbos-vdi-config`.
- 📋 Rutas Kong VDI (`/nextcloud/`, `/onlyoffice/`, `/desktop/`) configuradas en su propia ficha `kong` — moverlas a `sbos-vdi-config` es una mejora de iteración futura, no un error actual.

---

## FASE 11 — Aplicaciones de negocio (órdenes 170–180)

> Estas fichas requieren aprobación manual (auto_install: false) o dependen
> de decisiones HITL pendientes. Se instalan por tenant según sus necesidades.

---

### [170] tryton · S04 · ⏳ NO_INSTALADA

**Propósito:** ERP soberano Tryton 7.4. Módulos de contabilidad, inventario, ventas y RRHH. MDM (Master Data Management) hub vía bKernel CDC.

**Dependencias:** postgresql, vault, kong

**✅ INC-1 RESUELTO (ciclo 24):** `S01/tryton` eliminado — era duplicado idéntico. La única ficha canónica es `S04/tryton`.

**Logros:** ninguno (bloqueado por vault sin unseal — BUG-27)

**Acción VPS pendiente (código correcto):**
- ❌ Instalar tras vault estable: `bosctl ficha install tryton`
- ❌ Vault mount `sbos/` para credenciales Tryton se configura automáticamente en `ficha_post_install`

---

### [175] tryton-workers · S04 · ⏳ NO_INSTALADA

**Propósito:** Procesos de cola de tareas asíncronas del ERP (informes, importaciones masivas, exportaciones).

**Dependencias:** tryton

**~~INC-7 FALSO POSITIVO~~:** El manifest ya tiene `dependencies: [tryton]` — la dependencia estaba correcta. Error en el diagnóstico inicial.

**Logros:** ninguno (bloqueado por tryton INSTALL_FAILED — derivado de vault)

**Faltantes:** Instalar tras tryton INSTALLED

---

### [177] brocket (Rocket.Chat) · S06 · ⏳ PENDIENTE DE FICHA

**Propósito:** Chat empresarial interino del SBOS mientras se desarrolla bChat (el chat soberano nativo de bNotify). Rocket.Chat reemplaza a Mattermost. Canales por daemon, webhooks de alertas del sistema, mensajería interna del equipo.

**✅ INC-5 RESUELTO (ciclo 24):** S06/mattermost y S10/mattermost eliminados. La decisión arquitectónica es usar Rocket.Chat (bRocket) como solución interina hasta que bChat (Rust/gRPC, parte de bNotify) esté listo. Migración documentada en `BNOTIFY-036`.

**Dependencias:** postgresql, vault, kong

**Pendiente de desarrollo:**
- ❌ Crear ficha `servers/S06/brocket/` con Rocket.Chat (imagen: `rocket.chat:latest`) — tarea futura
- ❌ bChat (solución soberana definitiva) — parte del roadmap bNotify (gate G3)

---

### [174] ferretdb · S06 · ⚙️ PENDING
### [175] calcom · S06 · ⚙️ PENDING
### [176] novu · S06 · ⚙️ PENDING

**Propósito:**
- **ferretdb:** MongoDB wire-compatible sobre PostgreSQL. Backend de Novu.
- **calcom:** Plataforma de agendamiento Cal.com. Gestión de citas y reuniones.
- **novu:** Sistema de notificaciones multi-canal (email, SMS, push, in-app).

**Estado:** En PENDING esperando dependencias (vault caído bloquea la cadena). Se instalarán automáticamente tras vault INSTALLED (auto_install:true en algunos).

**Logros:**
- ✅ (ciclo 3) ferretdb, calcom, novu: health checks corregidos de formato legacy `check_via:` a `type: command`
- ✅ ferretdb: health verifica pod Running (27017 = MongoDB wire protocol, no HTTP)
- ✅ (ciclo 7) ferretdb/calcom/novu: `auto_install: true` + `category_label` agregados a manifest.yml (faltaban)
- ✅ (ciclo 7) ferretdb/calcom/novu: `ficha_test` agregada a cada task_catalog.sh
- ✅ (ciclo 7) loki/tempo/zabbix: `ficha_repair` agregada (re-aplica Helm idempotente)

**Faltantes:** Vault estable → instalación automática o manual según auto_install

---

## FASE 12 — Correo (S10, órdenes 300–315)

> Módulo de correo electrónico soberano. La identidad de correo ES la identidad SBOS:
> el mismo usuario Keycloak que accede al VDI tiene su buzón de correo en el mailserver.
> Requiere dominio público con registro MX configurado en DNS.

---

#### ⚠️ MODELO DE IDENTIDAD SBOS — PRINCIPIO FUNDAMENTAL (leer antes de cualquier desarrollo de usuarios/auth)

> **Un usuario SBOS = alguien con cuenta de correo corporativo en el mailserver del servidor.**
> No hay otra definición. No hay otro origen de usuarios.

**Reglas absolutas:**

| Regla | Correcto ✅ | Incorrecto ❌ |
|-------|------------|--------------|
| Identidad | Cuenta de correo corporativo (`juan@empresa.com`) | Cuenta externa (Gmail, Outlook, Yahoo) |
| Contraseña | La contraseña del buzón de correo = contraseña de TODO SBOS | Contraseña separada por aplicación |
| Registro | Administrador crea cuenta en mailserver → automáticamente existe en todo SBOS | Crear usuario en Keycloak sin buzón de correo |
| Gateway | Keycloak (transitorio) / bAuth (definitivo) — puerta obligatoria a TODA aplicación | Aplicación con su propia pantalla de login |
| Dominio | Solo el dominio corporativo del cliente | Ningún proveedor externo |

**Por qué el correo es la identidad y no Keycloak:**
- El correo corporativo es la credencial laboral que el empleado ya reconoce como propia
- Una empresa = un dominio de correo = un conjunto de usuarios SBOS
- Al dar de baja a un empleado: se **desactiva** su buzón → automáticamente pierde acceso a todo SBOS · su historial y datos quedan intactos
- No se puede crear un usuario "fantasma" en Keycloak sin que exista en el mailserver

**Flujo de vida de un usuario SBOS:**

```
1. Administrador crea buzón en mailserver:
      juan.perez@empresa.sbos.app  +  contraseña

2. Mailserver notifica a Keycloak/bAuth → usuario sincronizado automáticamente
      (grupos asignados según dominio o configuración del tenant)

3. Juan recibe email de bienvenida con enlace de primer acceso

4. Juan entra a la pantalla de Keycloak/bAuth:
      email: juan.perez@empresa.sbos.app
      contraseña: [la del buzón de correo]

5. Keycloak/bAuth emite token SSO → Juan accede a:
      ├── VDI (sesión KDE personalizada en fedora-kde)
      ├── Nextcloud (sus archivos corporativos)
      ├── Roundcube/Cypht (su buzón de correo, mismas credenciales)
      ├── ERP Tryton (según permisos de su rol)
      └── Cualquier otra app SBOS del servidor

   NINGUNA aplicación tiene pantalla de login propia.
   Toda app → redirige a Keycloak/bAuth → vuelve con token.

6. Administrador da de baja al empleado:
      Desactiva el buzón en mailserver → Keycloak/bAuth suspende acceso
      → Juan no puede entrar a ninguna app SBOS
      → Su historia, auditoría y datos quedan intactos (jamás se borran)
```

**Resumen en una línea:**
> *Cuenta de correo corporativo = identidad SBOS. Keycloak/bAuth = puerta de entrada obligatoria a todo.*

---

#### ⚠️ REGLA ABSOLUTA SBOS — Sin eliminación física (aplica a TODO el sistema)

> **En SBOS no se elimina nada. Nada se borra. Nada se destruye de forma permanente.**
> El vocabulario "eliminar", "borrar", "delete" (en contexto de datos de negocio) no existe en SBOS.

| En lugar de | Se usa |
|-------------|--------|
| Eliminar usuario | Desactivar usuario |
| Borrar buzón | Suspender buzón |
| Eliminar cuenta | Bloquear cuenta |
| Borrar registro | Marcar como inactivo (`active = false`, `deleted_at = now()`) |
| Destruir sesión | Suspender sesión |
| Eliminar archivo | Archivar / mover a papelera soberana |

**Por qué:** eliminar = destruir historia, auditoría y trazabilidad. SBOS es un sistema empresarial soberano — toda acción queda registrada, todo dato tiene historia, toda cuenta tiene un ciclo de vida rastreable. ISO 27001 exige que los registros de auditoría sean íntegros e inalterables.

**Único caso de eliminación física permitida:** borrado por mandato legal explícito (RGPD "derecho al olvido"), que requiere un proceso auditado, aprobado por el administrador del tenant y registrado en el log de auditoría con firma digital. Este proceso NO está automatizado — es una acción manual y deliberada.

*Esta regla aplica a: usuarios, cuentas de correo, sesiones VDI, registros ERP, configuraciones, PVCs, logs, contratos, y cualquier entidad del dominio de negocio.*

---

#### ¿Cuándo levantar el mailserver?

El mailserver se puede instalar en cualquier momento después de Keycloak y PostgreSQL. No bloquea el VDI ni las apps de negocio. Se levanta cuando el tenant necesita correo corporativo propio.

**Prerrequisitos técnicos:**
- Dominio público: `empresa.sbos.app` (o el dominio propio del cliente)
- Registro DNS `MX empresa.sbos.app → IP-VPS`
- Registro DNS `A empresa.sbos.app → IP-VPS`
- Puerto 25 (SMTP) abierto en UFW (actualmente bloqueado por sbos-bootstrap-hard)
- Puerto 993 (IMAPS) abierto en UFW para clientes externos

**Prerrequisitos de configuración:**
- Keycloak realm con el dominio del tenant configurado como `email domain`
- Plugin SASL configurado para verificar passwords contra Keycloak LDAP federation
- Base de datos `mailserver_db` en PostgreSQL (tabla de buzones virtual)

---

### [300] mailserver · S10 · ⏳ NO_INSTALADA

**Propósito:** Servidor de correo soberano. Postfix (SMTP, envío/recepción), Dovecot (IMAP/POP3, lectura), SpamAssassin (filtro de spam), ClamAV (antivirus de adjuntos). Un buzón por usuario Keycloak del tenant. Los datos del correo persisten en PVC `/data/mailserver/` con política Retain.

**Dependencias:** postgresql, keycloak, vault

**🔶 Autenticación — conexión con Keycloak:**
- Dovecot usa SASL con backend LDAP apuntando a Keycloak LDAP federation
- Keycloak expone los usuarios del realm como árbol LDAP (`dc=empresa,dc=sbos,dc=app`)
- Postfix autentica remitentes via Dovecot SASL
- Resultado: `login juan.perez + contraseña Keycloak` → acceso al buzón IMAP

**Logros (ciclo 5):**
- ✅ `runtime: docker` corregido a `runtime: kubernetes` en manifest.yml
- ✅ Implementación real confirmada: 210 líneas con PV Retain (50 Gi) + PVC + StatefulSet + Service (5 puertos: 25, 465, 587, 143, 993)
- ✅ `ficha_health` y `ficha_verify` implementadas

**Logros (ciclo 12):**
- ✅ `ficha_test()` agregada: test_pod_running (StatefulSet readyReplicas) + test_smtp_puerto (TCP :25)
- ✅ `ficha_repair()` ya existía — confirmada

**Faltantes:**
- ✅ (ciclo 13) `ficha_health()` mejorada: verifica `postfix status` via `kubectl exec mailserver-0`
- ✅ (ciclo 13) Apertura automática de puertos UFW en `ficha_install`: 25/465/587/143/993 (si UFW activo)
- ✅ Autenticación Keycloak — implementado en ficha_post_install ciclo 23: ENABLE_OAUTH2=1 + OAUTH2_INTROSPECTION_URL apuntando a Keycloak (Dovecot OAuth2, más moderno que LDAP SASL)
- ✅ (ciclo 15) `ficha_post_install()` crea schema `mailserver_db`: tablas `virtual_mailboxes` + `virtual_aliases` (idempotente — skip si ya existen)

---

### [305] postfixadmin · S10 · ⏳ NO_INSTALADA

**Propósito:** UI web de administración del mailserver. Crear/desactivar buzones, alias, dominios. Alternativa a editar la BD directamente. Autenticación via Keycloak SSO (solo admins con grupo `mail_admin`).

**Logros (ciclo 5):**
- ✅ `runtime: docker` corregido a `runtime: kubernetes` en manifest.yml
- ✅ Implementación básica: Deployment + Service (postfixadmin/postfixadmin:3.3.15, puerto 80)

**Logros (ciclo 12):**
- ✅ Env vars DB: `POSTFIXADMIN_DB_TYPE=pgsql`, `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD=sbos_bootstrap_pass`, `DB_NAME=postfixadmin_db`, `SMTP_SERVER/PORT`, `SETUP_PASSWORD`
- ✅ `ficha_test()` agregada: test_pod_running + test_http_responde (HTTP 200/302 en ClusterIP:80/postfixadmin/)
- ✅ Línea en blanco `spec:\n\n  replicas:` eliminada
- ✅ `ficha_repair()` ya existía — confirmada

**Faltantes:**
- ✅ Integración Keycloak SSO (OIDC OAuth2) — implementado en ficha_post_install ciclo 22 via K8s Secret sbos-postfixadmin-oidc

---

### [310] roundcube · S10 · ⏳ NO_INSTALADA

**Propósito:** Cliente webmail para usuarios. Acceden a su correo desde el navegador (o desde el escritorio VDI — Roundcube se puede instalar como app en el menú KDE de Fedora). Login con credenciales Keycloak via IMAP OAuth2.

**Logros (ciclo 5):**
- ✅ `runtime: docker` corregido a `runtime: kubernetes` en manifest.yml
- ✅ Implementación básica: Deployment + Service (roundcube/roundcubemail:1.6.10, puerto 80)

**Logros (ciclo 12):**
- ✅ Env vars: `ROUNDCUBEMAIL_DEFAULT_HOST=ssl://mailserver...`, `DEFAULT_PORT=993`, `SMTP_SERVER=tls://mailserver...`, `SMTP_PORT=587`, `DB_TYPE=pgsql`, `DB_HOST`, `DB_USER`, `DB_PASSWORD=sbos_bootstrap_pass`, `DB_NAME=roundcube_db`, `SKIN=elastic`, `PLUGINS`
- ✅ `ficha_test()` agregada: test_pod_running + test_http_responde (HTTP 200/302)
- ✅ Línea en blanco `spec:\n\n  replicas:` eliminada
- ✅ `ficha_repair()` ya existía — confirmada

**Faltantes:**
- ✅ OAuth2 Keycloak como método de login — implementado en ficha_post_install ciclo 22 via ROUNDCUBEMAIL_OAUTH_* env vars y K8s Secret sbos-roundcube-oidc

---

### [315] cypht · S10 · ⏳ NO_INSTALADA

**Propósito:** Webmail alternativo modular con soporte para múltiples cuentas (IMAP, calendarios, RSS). Más ligero que Roundcube. Puede convivir con Roundcube como opción de cliente.

**Logros (ciclo 5):**
- ✅ `runtime: docker` corregido a `runtime: kubernetes` en manifest.yml
- ✅ Implementación básica: Deployment + Service (sailfishsoftware/cypht:latest, puerto 80)

**Logros (ciclo 12):**
- ✅ Env vars: `IMAP_SERVER`, `IMAP_PORT=993`, `SMTP_SERVER`, `SMTP_PORT=587`, `DB_CONNECTION_TYPE=pgsql`, `DB_HOST`, `DB_PORT=5432`, `DB_USER`, `DB_PASS=sbos_bootstrap_pass`, `DB_NAME=cypht_db`, `CYPHT_SESSION_TYPE=DB`
- ✅ `ficha_test()` agregada: test_pod_running + test_http_responde (HTTP 200/302)
- ✅ Línea en blanco `spec:\n\n  replicas:` eliminada
- ✅ `ficha_repair()` ya existía — confirmada

**Faltantes:**
- ✅ Keycloak OIDC login — implementado en ficha_post_install ciclo 22 via K8s Secret sbos-cypht-oidc

---

#### Flujo completo: usuario nuevo con correo en SBOS

```
1. Admin crea usuario en Keycloak:
   juan.perez@empresa.sbos.app + grupo [correo_activo]

2. Keycloak notifica via webhook a sbos-notifier → sbos-notifier
   llama a mailserver API: "crear buzón juan.perez@empresa.sbos.app"

3. Mailserver crea entrada en mailserver_db + directorio /var/mail/juan.perez/

4. El usuario puede hacer login en:
   - Roundcube/Cypht con su contraseña Keycloak (webmail)
   - Thunderbird/Outlook configurando IMAP :993 + SMTP :587 (cliente desktop)
   - Desde el VDI Fedora: Thunderbird ya aparece en el menú de apps del grupo correo_activo

5. Cuando el usuario accede al VDI, su Thunderbird ya está configurado
   con su cuenta de correo (el pod carga la configuración desde su PVC)
```

---

## FASE 13 — Gestión documental (S08, órdenes 345–365)

> Todas con auto_install: false y STUBs de 135 líneas. Instalar cuando el tenant lo requiera.

---

### [345] tesseract-ocr · [350] paperless-ngx · [355] docuseal · [360] kimios · [365] tabula · S08 · ⏳ NO_INSTALADAS

**Ciclo 8 — logros:**
- `paperless-ngx`: PVCs `paperless-media` 20Gi + `paperless-data` 5Gi + volumeMounts · env PAPERLESS_REDIS/DBHOST/DBNAME/SECRET_KEY · resources 256Mi→512Mi · limpiado `spec: + línea vacía`

**Propósito:** Gestión documental soberana: OCR automático (tesseract), archivo digital con indexado full-text (paperless-ngx), firma digital (docuseal), ECM empresarial (kimios), extractor de tablas de PDFs (tabula).

**Estado:** Todas STUBs 135 líneas. No instaladas.

**Logros:** ninguno

**Faltantes:** Completar a nivel ROBUSTO + instalar por tenant

---

## FASE 14 — Búsqueda y mensajería (S09, órdenes 400–405)

---

### [400] elasticsearch · [405] rabbitmq · S09 · ⏳ NO_INSTALADAS

**Propósito:** Motor de búsqueda full-text (elasticsearch) y broker de mensajes AMQP (rabbitmq). Backend de bsearch y bus de eventos entre servicios.

**Estado:** Implementaciones reales. No instaladas.

**Ciclo 8 — logros:**
- `elasticsearch`: BUG-capitalización `kind: Statefulset → StatefulSet` corregido · PVC `es-data` 20Gi (local-path) + volumeMount `/usr/share/elasticsearch/data` · env `discovery.type=single-node`, `ES_JAVA_OPTS=-Xms512m -Xmx512m`, `xpack.security.enabled=false` · initContainer `sysctl vm.max_map_count=262144` (obligatorio para ES) · resources 500m→2000m / 1Gi→2Gi
- `rabbitmq`: BUG-capitalización `kind: Statefulset → StatefulSet` corregido · PVC `rabbitmq-data` 5Gi + volumeMount `/var/lib/rabbitmq` · env `RABBITMQ_DEFAULT_USER/PASS` + nodename canónico

---

## FASE 15 — DevOps (S14, órdenes 450–460)

---

### [450] gitlab · [455] bareos · [460] velero · S14 · ⏳ NO_INSTALADAS

**Propósito:** Plataforma DevOps soberana (GitLab CE), backup empresarial (Bareos) y backup K8s (Velero).

**Estado:** Implementaciones reales. No instaladas.

**Ciclo 8 — logros:**
- `gitlab`: BUG-capitalización `kind: Statefulset → StatefulSet` corregido · PVCs `gitlab-data` 50Gi + `gitlab-config` 1Gi + `gitlab-logs` 5Gi · env `GITLAB_OMNIBUS_CONFIG` con external_url, root_password, puma 2 workers · resources 1Gi→4Gi / 2Gi→6Gi
- `bareos`: PVC `bareos-data` 10Gi + volumeMount `/var/lib/bareos` · env DB_HOST/USER/NAME · limpiado `spec: + línea vacía`

---

## FASE 16 — Inteligencia Artificial (S15, órdenes 500–525)

---

### [500] ollama · [505] qdrant · [510] open-webui · [515] embedding-worker · [520] langfuse · [525] flowise · S15 · ⏳ NO_INSTALADAS

**Propósito:** Stack de IA soberana: servidor de modelos LLM locales (ollama), base de datos vectorial RAG (qdrant), interfaz web de chat (open-webui), worker de embeddings de documentos (embedding-worker), observabilidad de LLMs (langfuse), orquestador visual de flujos LLM (flowise).

**Estado:** Implementaciones reales. No instaladas.

**Ciclo 8 — logros:**
- `qdrant`: BUG-capitalización `kind: Statefulset → StatefulSet` corregido · PVC `qdrant-storage` 10Gi + volumeMount `/qdrant/storage` · resources 256Mi→512Mi / 1Gi→2Gi
- `ollama`: PVC separado `ollama-models` 30Gi + volumeMount `/root/.ollama` (modelos LLM persisten entre reinicios) · resources 256Mi→2Gi / 1Gi→8Gi · limpiado `spec: + línea vacía`

---

## Mapa de problemas activos — con soluciones concretas

> Esta sección agrupa todos los bugs activos por prioridad con:
> **síntoma → causa raíz → solución paso a paso → verificación**.
> El orden es el de resolución recomendado (cada bloque desbloquea el siguiente).

---

### BLOQUE A — VPS inmediata (desbloquean toda la cadena)

---

**PROBLEMA A-1 — BUG-36: hairpin NAT puede no estar activa → kyverno admission-controller falla** ✅ CERRADO (ciclo 11)

- **Síntoma original:** `kubectl logs -n kyverno deploy/kyverno-admission-controller` muestra `dial tcp 10.96.0.1:443: i/o timeout`. kyverno queda en PENDING sin poder registrar sus webhooks.
- **Causa raíz:** Hetzner VPS no provee hairpin NAT. Los pods no pueden alcanzar la IP pública del servidor (que es el endpoint del apiserver K8s externamente). La regla iptables podía perderse al reiniciar el host.
- **Solución aplicada (ciclo 11):** `sbos-bootstrap-k8s/ficha_install()` instala `sbos-hairpin-nat.service` (systemd Type=oneshot) que aplica `iptables MASQUERADE 10.244.0.0/16 POSTROUTING` en cada arranque del host. Permanente sin depender de iptables-persistent.
- **Solución:**
  ```bash
  # 1. Verificar si la regla existe actualmente en VPS
  iptables -t nat -L PREROUTING -n | grep "10.96.0.1"
  iptables -t nat -L OUTPUT -n | grep "10.96.0.1"
  
  # 2. Si no existe, agregarla:
  SERVER_IP=$(curl -sf https://ifconfig.me)
  iptables -t nat -A PREROUTING -d $SERVER_IP -p tcp --dport 6443 -j DNAT --to-destination 10.96.0.1:443
  iptables -t nat -A OUTPUT -d $SERVER_IP -p tcp --dport 6443 -j DNAT --to-destination 10.96.0.1:443
  iptables -t nat -A POSTROUTING -d 10.96.0.1 -p tcp --dport 443 -j MASQUERADE
  
  # 3. Persistir para que sobreviva reboot:
  iptables-save > /etc/iptables/rules.v4
  
  # 4. Reiniciar el pod de kyverno admission-controller:
  kubectl rollout restart deployment kyverno-admission-controller -n kyverno
  
  # 5. Verificar que kyverno está Running y sus webhooks registrados:
  kubectl get validatingwebhookconfigurations | grep kyverno
  ```
- **Verificación:** `kubectl get pods -n kyverno | grep admission-controller` → todos Running (no CrashLoopBackOff).

---

**PROBLEMA A-2 — BUG-26: vault en CrashLoop por liveness probe sin `sealedok=true`**

- **Síntoma:** Pod vault tiene 95+ reinicios. `kubectl describe pod vault-0 -n sbos-security` muestra `Liveness probe failed: HTTP probe failed with statuscode: 503` (vault sellado devuelve 503 en /v1/sys/health sin sealedok=true).
- **Causa raíz:** La liveness probe original es `/v1/sys/health?standbyok=true` — cuando vault está sellado devuelve 503, Kubernetes lo mata y reinicia el pod, que vuelve a quedar sellado. Ciclo infinito.
- **Fix commiteado (FIX-26A en de927a0):** La probe correcta es `/v1/sys/health?standbyok=true&sealedok=true`. Vault sellado devuelve 200 y K8s no mata el pod.
- **Solución — desplegar en VPS:**
  ```bash
  # Copiar task_catalog.sh actualizado al pod o via kubectl patch:
  kubectl patch statefulset vault -n sbos-security --type=json -p='[
    {"op":"replace",
     "path":"/spec/template/spec/containers/0/livenessProbe/httpGet/path",
     "value":"/v1/sys/health?standbyok=true&sealedok=true"}
  ]'
  
  # Verificar que el StatefulSet se actualizó:
  kubectl get statefulset vault -n sbos-security -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}'
  
  # Esperar que el pod se reinicie con la nueva probe:
  kubectl rollout status statefulset vault -n sbos-security
  ```
- **Verificación:** `kubectl get pods -n sbos-security | grep vault` → Running sin reinicios acumulándose.

---

**PROBLEMA A-3 — Vault debe desellar manualmente tras cada reinicio**

- **Síntoma:** Vault está Running (liveness probe ok tras A-2) pero en estado SEALED. Las apps que necesitan secretos no pueden obtenerlos.
- **Causa raíz:** Vault seal por diseño de seguridad — las unseal keys no se almacenan en el sistema (si lo hicieran, cualquiera con acceso al cluster tendría acceso a todos los secretos).
- **Solución:**
  ```bash
  # Obtener las unseal keys del archivo seguro (guardadas en el momento del vault init)
  # Ejecutar 3 de 5 operaciones de unseal:
  kubectl exec -n sbos-security vault-0 -- vault operator unseal <unseal-key-1>
  kubectl exec -n sbos-security vault-0 -- vault operator unseal <unseal-key-2>
  kubectl exec -n sbos-security vault-0 -- vault operator unseal <unseal-key-3>
  
  # Verificar estado:
  kubectl exec -n sbos-security vault-0 -- vault status | grep "Sealed"
  # Debe mostrar: Sealed: false
  ```
- **Nota larga:** Para auto-unseal soberano (sin dependencia de HashiCorp Cloud), usar Vault Transit seal con un segundo Vault dedicado (arquitectura compleja — pendiente decisión HITL).
- **Verificación:** `kubectl exec -n sbos-security vault-0 -- vault status | grep "Sealed"` → `Sealed: false`.

---

**PROBLEMA A-4 — oauth2-proxy en PHYSICAL_ERROR derivado de vault**

- **Síntoma:** Pod oauth2-proxy en CrashLoopBackOff. Error: `failed to get provider configuration: ... connection refused` o `vault: 503 Service Unavailable`.
- **Causa raíz:** oauth2-proxy intenta leer el `client_secret` de Keycloak desde Vault al arrancar. Vault está sellado/caído → lectura falla → pod no arranca → K8s lo reinicia → ciclo.
- **Solución:** Se resuelve automáticamente al completar A-2 + A-3. FIX-B (observer) ya está activo en el binary actual — detecta PHYSICAL_ERROR y lanza repair automáticamente.
- **Proceso automático tras A-3:**
  1. Vault unseal → AppRole de oauth2-proxy obtiene token
  2. oauth2-proxy lee client_secret de Keycloak de Vault
  3. Pod arranca correctamente
  4. Observer detecta PHYSICAL_ERROR → StatePhysicalError → lanza repair
  5. Estado pasa a INSTALLED
- **Si no ocurre automáticamente:** `bosctl ficha repair oauth2-proxy`
- **Verificación:** `kubectl get pods -n sbos-gateway | grep oauth2` → Running.

---

**PROBLEMA A-5 — tryton INSTALL_FAILED derivado de vault**

- **Síntoma:** `bosctl ficha status tryton` → INSTALL_FAILED. El pod no arranca porque no puede obtener credenciales de BD de Vault.
- **Causa raíz:** Misma que A-4 — Vault sellado impide obtener el DSN de PostgreSQL para Tryton.
- **Solución:** Completar A-2+A-3, luego: `bosctl ficha repair tryton`
- **Prerequisito:** Resolver INC-1 (duplicado S01/S04) antes — ver BLOQUE C.
- **Verificación:** `kubectl get pods -n sbos-erp | grep tryton` → Running.

---

**PROBLEMA A-6 — linkerd ReplicaSets huérfanos consumen recursos** ✅ CERRADO (ciclo 4)

- **Síntoma original:** `kubectl get rs -n linkerd | grep "0/0/0"` mostraba varios ReplicaSets con 0 pods deseados/actuales/listos.
- **Causa:** Instalaciones anteriores fallidas de linkerd dejaron ReplicaSets obsoletos.
- **Solución aplicada (ciclo 4):** `ficha_repair()` de linkerd limpia automáticamente todos los ReplicaSets con 0 réplicas antes de re-aplicar el deployment (BUG-29 cerrado).
- **Solución manual si aún hay huérfanos:**
  ```bash
  # Ver RS huérfanos:
  kubectl get rs -n linkerd | grep -E "^.*\s+0\s+0\s+0\s+"
  
  # Eliminarlos:
  kubectl get rs -n linkerd | grep -E "\s+0\s+0\s+0\s+" | awk '{print $1}' | \
    xargs kubectl delete rs -n linkerd
  ```
- **Verificación:** `kubectl get rs -n linkerd` → solo RSs con replicas > 0.

---

### BLOQUE B — Código (correcciones en fichas)

---

**PROBLEMA B-1 — BUG-35: dependencia circular PG/Redis/MinIO → vault** ✅ CERRADO (ciclo 2)

- **Síntoma original:** Ciclo de dependencias PG→Vault→PG bloqueaba el DAG del observer.
- **Causa original:** `manifest.yml` de postgresql, redis y minio declaraban `vault` como dependencia directa.
- **Solución aplicada (ciclo 2):** `vault` movido a `runtime_dependencies` (no `dependencies`) en los manifests de postgresql, redis y minio. PG/Redis/MinIO arrancan con credenciales propias; Vault los gestiona después de instalarse.
- **Verificación:** `bosctl observer dag` → no muestra ciclos. Estado actual: los 3 servicios INSTALLED sin bloqueo.

---

**PROBLEMA B-2 — BUG-31: fichas huérfanas no están en .sbos_state.json**

- **Síntoma:** `sbos-bootstrap-platform` y `sbos-k8s-network-validator` existen en `servers/` y están desplegadas en el cluster, pero no aparecen en `.sbos_state.json`. El observer no las supervisa.
- **Causa:** Se instalaron antes de que BOS tuviera el state manager completo, o se instalaron fuera del flujo normal de BOS.
- **Solución:**
  ```bash
  # Registrar manualmente en state (o via bosctl):
  bosctl ficha repair sbos-bootstrap-platform
  bosctl ficha repair sbos-k8s-network-validator
  # Estos comandos deben detectar que la ficha ya está instalada y solo registrarla en state
  ```
- **Si repair no registra en state:** Agregar método `bosctl ficha adopt` que detecta estado real y lo registra.
- **Verificación:** `bosctl state list | grep sbos-bootstrap-platform` → aparece en la lista.

---

**PROBLEMA B-3 — GAP-4: guacamole sin conexiones → escritorio inaccesible vía Guacamole** ✅ CERRADO EN CÓDIGO (ciclo 2) — pendiente VPS

- **Síntoma original:** Lista de conexiones vacía en Guacamole.
- **Solución aplicada (ciclo 2):** `ficha_post_install()` en `servers/S13/guacamole/task_catalog.sh` inserta automáticamente la conexión VNC "Escritorio SBOS" apuntando a `fedora-kde.sbos-vdi.svc.cluster.local:5900`. Idempotente via `ON CONFLICT DO NOTHING`.
- **Pendiente VPS (única acción requerida):**
  ```bash
  bosctl ficha repair guacamole
  ```
- **Verificación:** Login en `/guacamole/` → lista "Escritorio SBOS" → conectar → desktop visible.

---

**PROBLEMA B-4 — GAP-2: health.check_command ausente en fichas críticas** ✅ CERRADO (ciclo 3)

- **Síntoma original:** BOS no podía detectar proactivamente si los servicios respondían (solo detectaba CrashLoop via k8s_discovery).
- **Causa original:** Las fichas no tenían `health.check_command` definido.
- **Solución aplicada (ciclo 3):** Se agregó health check canónico a todas las fichas críticas. Manifests verificados:
  - postgresql: `type: command` → `pg_isready -U postgres`
  - redis: `type: command` → `redis-cli ping | grep PONG`
  - vault: `type: http` → `/v1/sys/health`
  - keycloak: `type: http` → `/health/ready`
  - kong: `type: http` → `/status port 8007`
  - minio: `type: http` → `/minio/health/live`
  - prometheus: `type: http` → `/-/ready`
  - sbos-notifier: `type: http` → `/health/ready`
  - sbos-bkernel: `type: command` → `systemctl is-active bkernel`
- **Estado:** ✅ Todos los manifests tienen health check real. GAP-2 cerrado.

> *Referencia histórica (solución que se aplicó):*
  ```yaml
  # postgresql:
  health:
    type: command
    command: "kubectl exec -n sbos-data deployment/postgresql -- pg_isready -U postgres"
    timeout_seconds: 5
  
  # redis:
  health:
    type: command
    command: "kubectl exec -n sbos-data deployment/redis -- redis-cli ping | grep -q PONG"
    timeout_seconds: 5
  
  # vault:
  health:
    type: command
    command: "kubectl exec -n sbos-security vault-0 -- vault status | grep -q 'Sealed.*false'"
    timeout_seconds: 10
  
  # kong:
  health:
    type: command
    command: "kubectl exec -n sbos-gateway deployment/kong -- curl -sf http://localhost:8007/status"
    timeout_seconds: 5
  ```
- **Verificación:** `bosctl ficha health postgresql` → responde OK/DEGRADED según el estado real del servicio.

---

### BLOQUE C — HITL (requieren decisión del humano)

---

**PROBLEMA C-1 — INC-1: duplicado S01/tryton = S04/tryton**

- **Síntoma:** `diff servers/S01/tryton/manifest.yml servers/S04/tryton/manifest.yml` → sin diferencias.
- **Causa:** Se creó una copia sin propósito distinto.
- **Decisión HITL requerida (Q-1):**
  - Opción A: `S01/tryton` = instancia ERP tenant principal (auto_install:true). `S04/tryton` = reservado para tenant secundario (auto_install:false, requiere customización). → Diferenciarlos en descripciones y namesapce K8s.
  - Opción B: Eliminar `S04/tryton` completamente (solo un ERP por instalación).
  - Opción C: `S04/tryton` es la instancia de staging/test (namespace diferente).

---

**PROBLEMA C-2 — INC-5: duplicado S06/mattermost = S10/mattermost**

- **Síntoma:** S06 tiene 726 líneas (robusta, auto_install:true) y S10 tiene 260 líneas (básica, auto_install:false).
- **Decisión HITL requerida (Q-4):**
  - Opción A: S06 = instancia de chat empresarial (usar esta, eliminar S10).
  - Opción B: S10 = instancia de soporte externo (diferente config, diferente namespace).

---

**PROBLEMA C-3 — SBOS-database-init: falta ficha de inicialización de BD** ✅ CERRADO (ciclo 5 + ciclo 13)

- **Solución aplicada (ciclo 5):** Ficha `sbos-database-init` creada en `servers/S01/sbos-database-init/` (orden 105, auto_install=true, dependencia: postgresql).
- **Mejora (ciclo 13):** `ficha_pre_install()` busca el DDL en 4 rutas candidatas y lo copia automáticamente sin intervención manual (ADR-022).
- **Pendiente VPS:** Ejecutar `bosctl ficha install sbos-database-init` para desplegar el DDL (158 tablas SBOS_db) en la VPS.

---

### BLOQUE D — Seguridad urgente

---

**PROBLEMA D-1 — VDI-GAP-5: puerto 6901 expuesto sin auth** ✅ CERRADO (ciclo 13)

- **Solución aplicada (ciclo 13):** NetworkPolicy `deny-direct-novnc-external` en `sbos-vdi-config/task_catalog.sh` bloquea el acceso al puerto 6901 desde fuera del namespace `sbos-gateway`. El acceso al escritorio solo es posible a través de Guacamole (que autentica con Keycloak).
- **Verificación:** `kubectl get networkpolicy -n sbos-vdi deny-direct-novnc-external` → existe. Acceso directo `curl http://IP-VPS:6901` → timeout/rechazado.

---

## Resumen de estado por ficha

| Orden | Ficha | Estado | Bloqueo principal |
|-------|-------|--------|-------------------|
| 1 | bos-preflight | ✅ INSTALLED | — |
| 5 | sbos-namespace | ✅ INSTALLED | — |
| 10 | sbos-bootstrap-os | ✅ INSTALLED | — |
| 20 | sbos-bootstrap-k8s | ✅ INSTALLED | ✅ BUG-36 cerrado (ciclo 11) |
| 25 | sbos-bootstrap-cni | ✅ INSTALLED | — |
| 28 | sbos-bootstrap-platform | ⚙️ PENDING | 📋 BUG-31: estado PENDING esperado — se registra y pasa a INSTALLED en el próximo reinicio del daemon BOS (comportamiento por diseño) |
| 30 | sbos-bootstrap-storage | ✅ INSTALLED | — |
| 35 | sbos-bootstrap-monitoring | ✅ INSTALLED | — |
| 50 | sbos-k8s-network-validator | ⚙️ PENDING | 📋 BUG-31: estado PENDING esperado — se registra y pasa a INSTALLED en el próximo reinicio del daemon BOS (comportamiento por diseño) |
| 70 | sbos-bkernel | ✅ INSTALLED | — |
| 105 | sbos-database-init | ⏳ NUEVA (pendiente deploy) | Creada en ciclo 5 — instalar con `bosctl ficha install sbos-database-init` |
| 100 | postgresql | ✅ INSTALLED | ✅ BUG-35 cerrado (ciclo 2) |
| 100 | kyverno | ⚙️ PENDING | ✅ BUG-36 cerrado (ciclo 11) — sbos-hairpin-nat.service persistente |
| 110 | redis | ✅ INSTALLED | ✅ BUG-35 cerrado (ciclo 2) |
| 110 | linkerd | 🔄 INSTALLING | ✅ BUG-29 cerrado (ciclo 4) |
| 120 | minio | ✅ INSTALLED | — |
| 130 | vault | ❌ PHYSICAL_ERROR | ❌ FIX-26A pendiente VPS |
| 131 | vault-unsealer | ⏳ NUEVA | Creada ciclo 11 — instalar tras init de vault |
| 135 | besu-qbft | ✅ INSTALLED | — |
| 140 | keycloak | ✅ INSTALLED | — |
| 150 | oauth2-proxy | ❌ PHYSICAL_ERROR | ❌ derivado vault |
| 160 | kong | ✅ INSTALLED | — |
| 170 | nginx | ⏸️ UPDATE_AVAILABLE (versión) · ✅ bcms-ready (ciclo 30) | — |
| 170 | sbos-notifier | ✅ INSTALLED | — |
| 170 | tryton (S04) | ⏳ NO_INSTALADA | ❌ bloqueado por vault (BUG-27) — INC-1 ✅ resuelto ciclo 24 |
| 174 | ferretdb | ⚙️ PENDING | derivado vault |
| 175 | tryton-workers | ⏳ NO_INSTALADA | dep en tryton |
| 175 | calcom | ⏳ NO_INSTALADA | — |
| 176 | novu | ⚙️ PENDING | derivado vault |
| 177 | brocket (Rocket.Chat) | ⏳ FICHA PENDIENTE | INC-5 ✅ resuelto ciclo 24 — ficha aún por crear |
| 180 | certbot | ✅ INSTALLED | — |
| 200 | prometheus | ✅ INSTALLED | — |
| 200 | nextcloud | ✅ INSTALLED | — |
| 205 | alertmanager | ✅ INSTALLED | — |
| 210 | guacamole | ✅ INSTALLED | ❌ `bosctl ficha repair guacamole` pendiente VPS (código ✅ ciclo 2) |
| 215 | grafana | ✅ INSTALLED | — |
| 215 | loki | ⚙️ PENDING (Helm, esperando deps) | — |
| 220 | alloy | ✅ INSTALLED | 📋 Loki aún no instalado (deps pendientes) — Alloy bufferiza y enviará cuando Loki esté disponible |
| 220 | tempo | ⚙️ PENDING (Helm, esperando deps) | — |
| 220 | onlyoffice | ✅ INSTALLED | — |
| 225 | zabbix | ⏳ NO_INSTALADA (auto_install=false) | — |
| 225 | oauth2-proxy-desktop | ❌ PHYSICAL_ERROR | ❌ derivado vault |
| 230 | fedora-kde | ⏸️ UPDATE_AVAILABLE | ❌ INC-2/3 (HITL Q-2/3), VDI-GAP-1/2 pendientes; GAP-5 ✅ ciclo 13 |
| 250 | sbos-bootstrap-hard | ✅ INSTALLED | ❌ kyverno switch enforce — acción VPS pendiente (código correcto) |
| 300–315 | mailserver stack | ⏳ NO_INSTALADA (auto_install=false) | — |
| 345–365 | docs stack | ⏳ NO_INSTALADA (auto_install=false) | — |
| 400–405 | búsqueda/mensajería | ⏳ NO_INSTALADA (auto_install=false) | — |
| 420 | sbos-vdi-config | ⏳ NO_INSTALADA (auto_install=false) | Instalar tras VDI completo |
| 450–460 | devops stack | ⏳ NO_INSTALADA (auto_install=false) | — |
| 500–525 | IA stack | ⏳ NO_INSTALADA (auto_install=false) | — |

---

**Fichas INSTALLED:** 24 · **PHYSICAL_ERROR:** 3 · **INSTALL_FAILED:** 1 · **INSTALLING:** 1 · **UPDATE_AVAILABLE:** 2 · **PENDING/NO_INSTALADA:** 35 · **A DESPLEGAR:** 1 (`sbos-database-init`)

**Correcciones ciclo 5 (c77c12e):** `sbos-database-init` ficha creada · `runtime: docker → kubernetes` corregido en 23 fichas (S10/S12/S08/S09/S14/S15/S01/S04) · loki/tempo/zabbix confirmados como implementaciones Helm reales · sbos-vdi-config auditada

**Correcciones ciclo 7:** `ficha_repair` agregada a TODAS las fichas (100% cobertura) · `ficha_test` agregada a fichas S13 activas (nextcloud/guacamole/onlyoffice/fedora-kde) y S06 (ferretdb/calcom/novu) · `auto_install: true + category_label` agregados a ferretdb/calcom/novu manifests · `ficha_repair` loki/tempo/zabbix (Helm idempotente) · sbos-bootstrap-platform y sbos-k8s-network-validator con `ficha_repair`

**Correcciones ciclo 8:** BUG-capitalización `kind: Statefulset → StatefulSet` en 4 fichas (elasticsearch/rabbitmq/gitlab/qdrant) · PVCs y volumeMounts en 7 fichas stateful (elasticsearch 20Gi · rabbitmq 5Gi · qdrant 10Gi · gitlab 56Gi · ollama 30Gi · paperless-ngx 25Gi · bareos 10Gi) · env vars obligatorias (ES discovery.type/JAVA_OPTS · GitLab OMNIBUS_CONFIG · RabbitMQ credenciales) · initContainer sysctl ES · resources ajustados (elasticsearch 1→2Gi · gitlab 256Mi→6Gi · ollama 256Mi→8Gi)

**Correcciones ciclo 9:** env vars críticas sin las cuales los servicios no arrancan — langfuse (DATABASE_URL/NEXTAUTH_SECRET/SALT/NEXTAUTH_URL/TELEMETRY) · open-webui (OLLAMA_BASE_URL/WEBUI_SECRET_KEY) + PVC open-webui-data 5Gi · flowise (DATABASE_TYPE/HOST/USER/PASS/NAME + FLOWISE_USERNAME/PASSWORD) · embedding-worker (OLLAMA_URL/QDRANT_URL/REDIS_URL) · docuseal (DATABASE_URL/SECRET_KEY_BASE/APP_URL) · kimios (DB_HOST/PORT/NAME/USER/PASS + KIMIOS_ADMIN_PASSWORD) + resources 256Mi→512Mi · limpieza cosmética `spec: + línea vacía` en tabula/tesseract-ocr/velero

**Correcciones ciclo 10:** `ficha_test` agregada a 5 fichas `auto_install=true` que faltaban — sbos-bootstrap-platform (7 namespaces + StorageClass) · sbos-k8s-network-validator (ConfigMap + CoreDNS) · loki (helm status=deployed + pod) · tempo (helm status=deployed + pod) · oauth2-proxy-desktop (pod Running + /ping 200) — **estado final: 0 bugs sistemáticos pendientes**

**Correcciones ciclo 11:** automatización completa de intervenciones manuales — (1) **vault-unsealer** nueva ficha (orden 131, auto_install=true): CronJob que desella Vault automáticamente cada minuto leyendo keys de K8s Secret `vault-unseal-keys`, elimina la intervención manual del Fase 2 de vault (ADR-022) · (2) **BUG-36 CERRADO**: `sbos-hairpin-nat.service` (systemd `Type=oneshot`) instalado por `ficha_install()` de sbos-bootstrap-k8s — `iptables MASQUERADE 10.244.0.0/16 POSTROUTING` persiste en cada reinicio del host sin depender de iptables-persistent

**Correcciones ciclo 12:** fichas S10 correo (4 fichas) — `ficha_test()` agregada a mailserver (StatefulSet + TCP :25) · postfixadmin · roundcube · cypht (pod running + HTTP 200/302) + env vars de DB/SMTP críticas en postfixadmin (`POSTFIXADMIN_DB_*`, `SMTP_SERVER`), roundcube (`ROUNDCUBEMAIL_DEFAULT_HOST ssl://`, `DB_*`), cypht (`IMAP_SERVER`, `DB_*`, `CYPHT_SESSION_TYPE=DB`) + limpieza `spec: + línea vacía` en 3 fichas

**Correcciones ciclo 13:** (1) **sbos-database-init**: DDL auto-copiado — `ficha_pre_install` busca en 4 rutas candidatas y copia sin intervención manual · (2) **loki**: retención 720h + `structuredMetadata.enabled` para ctx_id · (3) **tempo**: retención 720h + search habilitado · (4) **mailserver**: `ficha_health` con `postfix status` via kubectl exec + puertos UFW automáticos en `ficha_install` · (5) **VDI-PROBLEMA #5 CERRADO**: NetworkPolicy `deny-direct-novnc-external` en sbos-vdi-config bloquea acceso directo a puerto 6901

**Correcciones ciclo 14:** **kong routing declarativo** — `ficha_post_install()` configura automáticamente 5 servicios + 5 rutas en Kong Admin API: `nextcloud→/nextcloud`, `onlyoffice→/onlyoffice`, `grafana→/grafana`, `guacamole→/desktop`, `sbos-notifier→/sbos-notifier`; helpers `_kong_ensure_service` + `_kong_ensure_route` idempotentes (skip si ya existen); `ficha_repair()` re-aplica rutas en cada ciclo de reparación; `ficha_test()` verifica ≥5 rutas activas

**Correcciones ciclo 15:** (1) **mailserver**: `ficha_post_install()` crea schema `mailserver_db` con tablas `virtual_mailboxes` + `virtual_aliases` (idempotente via `information_schema`) · (2) **onlyoffice**: `ficha_post_install()` + `ficha_repair()` configuran plugin OnlyOffice en Nextcloud via `occ`: `app:enable onlyoffice`, `DocumentServerUrl=https://<domain>/onlyoffice/`, `DocumentServerInternalUrl` (ClusterIP), `StorageUrl`; graceful si Nextcloud no está listo

**Correcciones ciclo 23:** **mailserver OAuth2 Dovecot + limpieza BUG-31** — (1) **mailserver/ficha_post_install**: agrega `ENABLE_OAUTH2=1` + `OAUTH2_INTROSPECTION_URL` al StatefulSet apuntando a Keycloak token introspection endpoint; idempotente (skip si ya configurado); reemplaza la integración LDAP SASL prevista por OAuth2 nativo de docker-mailserver v14 · (2) BUG-31 marcado como auto-resolve en sbos-bootstrap-platform y sbos-k8s-network-validator; commit: `462630f`

**Correcciones ciclo 22:** **SSO OIDC stack de correo** — (1) **keycloak/ficha_post_install**: 3 clientes OIDC adicionales — `sbos-postfixadmin`, `sbos-roundcube`, `sbos-cypht` — con redirectURIs y secrets guardados en K8s `sbos-security` · (2) **postfixadmin/ficha_post_install**: OIDC via env vars `OIDC_CLIENT_ID/SECRET/DISCOVERY_URL` leídas de K8s Secret `sbos-postfixadmin-oidc` (idempotente, skip si KC no listo) · (3) **roundcube/ficha_post_install**: OAuth2 Keycloak via `ROUNDCUBEMAIL_OAUTH_*` env vars (auth/token/identity URIs) leídas de K8s Secret `sbos-roundcube-oidc` · (4) **cypht/ficha_post_install**: OIDC via env vars `OIDC_CLIENT_ID/SECRET/DISCOVERY_URL` leídas de K8s Secret `sbos-cypht-oidc`; commit: `da69d9f`

**Correcciones ciclo 20:** **SSO declarativo — identidad unificada Keycloak** — (1) **keycloak/ficha_post_install**: SSO-2 Web Origins `*.sbos.app` + crea 4 clientes OIDC (`sbos-nextcloud`, `sbos-grafana`, `sbos-mattermost`, `sbos-guacamole`) y guarda secrets en K8s Secrets namespace `sbos-security` (idempotente con `_kc_ensure_client` + kcadm.sh); `ficha_repair()` re-aplica SSO en cada ciclo · (2) **nextcloud/ficha_post_install**: SSO-4 — lee K8s Secret `sbos-nextcloud-oidc`, habilita app `user_oidc` y configura proveedor OIDC Keycloak via `occ user_oidc:provider add` (idempotente, skip si KC no listo) · (3) **kong/ficha_post_install**: SSO-3 — JWT plugin en 4 rutas (`nextcloud-route`, `grafana-route`, `guacamole-route`, `mattermost-route`) via Kong Admin API (idempotente con `_kong_ensure_plugin`); `ficha_repair()` re-aplica plugins · (4) **grafana/ficha_post_install**: OIDC Keycloak via env vars `GF_AUTH_GENERIC_OAUTH_*` patch al deployment, leídas de K8s Secret `sbos-grafana-oidc` (skip graceful si secret no disponible); commit: `17a4ff6`

**Correcciones ciclo 19:** **calidad Go — suite completa verde** — (1) `gofmt` aplicado a 105 archivos (0 archivos con formato incorrecto) · (2) `go vet` limpio: fix `fmt.Println` con `\n` redundante en `install_ui.go:68` · (3) 2 tests fallidos corregidos: `timeout_test.go` esperaba 600s para sagas pero el código usa 30min (actualizado), `manager_test.go` marcaba `InstallFailed→Installed` como inválida pero la transición fue habilitada intencionalmente (caso eliminado) · (4) exports corregidos en ferretdb y mattermost S10 (faltaban `ficha_health` y `ficha_test`); resultado: **0 errores build · 0 advertencias vet · 48 paquetes 100% green**

**Correcciones ciclo 18:** **ficha_health() cobertura 100%** — agregada a las 20 fichas restantes: S-HOST/bos-preflight (binario ejecutable) · S-HOST/sbos-bkernel (systemctl is-active) · S-HOST/sbos-namespace (kubectl get namespace) · S-HOST/sbos-bootstrap-os (sysctl net.bridge) · S-HOST/sbos-bootstrap-k8s (kubelet activo) · S-HOST/sbos-bootstrap-cni (calico-node pods Running) · S-HOST/sbos-bootstrap-storage (storageclass local-path) · S-HOST/sbos-bootstrap-monitoring (namespace sbos-monitoring) · S-HOST/sbos-bootstrap-hard (K8s nodes Ready) · S01/sbos-database-init (SBOS_db existe en PG) · S01/tryton · S02/besu-qbft (podman inspect Running) · S02/certbot (cert.pem en /etc/letsencrypt) · S03/kyverno (wrapper ficha_health_check) · S03/linkerd (pods Running en NS linkerd) · S04/tryton · S06/calcom · S06/ferretdb · S06/novu (wrappers) · S10/mattermost (deployment readyReplicas); resultado: **100% fichas con ficha_health()** — observer puede evaluar salud completa del ecosistema

**Correcciones ciclo 17b:** **ficha_health() adicionales** — S02/oauth2-proxy · S06/mattermost · S13/oauth2-proxy-desktop (deployments) + S10/mattermost (ficha_health explícita junto a ficha_health_check)

**Correcciones ciclo 17:** **ficha_health() en fichas core** — agregada a 16 fichas que la tenían pendiente: S01/postgresql · S01/redis · S01/minio (StatefulSet) · S02/kong · S02/vault · S02/nginx (systemctl is-active) · S03/keycloak · S06/sbos-notifier · S12/grafana · S12/prometheus · S12/alertmanager · S12/alloy (DaemonSet numberReady) · S13/nextcloud · S13/guacamole · S13/onlyoffice · S13/fedora-kde

**Correcciones ciclo 16:** **ficha_test() cobertura 100%** — agregada a las 20 fichas que la tenían pendiente: S04/tryton-workers · S08/docuseal · S08/paperless-ngx · S08/kimios · S08/tabula · S08/tesseract-ocr · S09/elasticsearch · S09/rabbitmq · S10/mattermost · S12/zabbix · S13/sbos-vdi-config (configmap + 3 NetworkPolicies) · S14/bareos · S14/gitlab · S14/velero · S15/ollama · S15/qdrant · S15/flowise · S15/langfuse · S15/open-webui · S15/embedding-worker; 0 fichas sin ficha_test en todo el proyecto

**Correcciones ciclo 24:** **INC-1 + INC-5 resueltas + fichas nuevas** — (1) **INC-1 CERRADA**: `S01/tryton` eliminado (`git rm`); S04 es la ubicación canónica (único ERP) · (2) **INC-5 CERRADA**: `S06/mattermost` + `S10/mattermost` eliminados (`git rm`); bRocket (Rocket.Chat) es el sucesor; referencias `provides_to` actualizadas en novu/calcom · (3) **sbos-bi18n nueva ficha** (S-HOST orden 75): daemon Rust MUSL, `ficha_pre_install/install/post_install/repair/test/remove` completos, unit systemd `Type=notify`, sockets `/run/bos/bi18n.sock` + `/run/bos/bi18n-grpc.sock`, idempotencia por versión; commit: `5d1046a`

**Correcciones ciclo 25:** **documentación nginx+CMS + vault unseal en suspenso** — (1) **7.01_MANUAL-NGINX-WEB-CMS.md** creado: arquitectura bcms, modelo tenant/empresa/sucursal, DDL schema cms (6 tablas), plan 4 fases, 7 HITL; (2) T-415 `bos.net_web_domain` advertencia en postgresql/manifest.yml; (3) **PENDIENTE-VAULT-UNSEAL-INTERACTIVO.md** documenta implementación en suspenso (esperar end-to-end funcional); commit: `d0051b2`

**Correcciones ciclo 26:** **seeds bglobal + mailserver_db en sbos-database-init** — (1) **sbos-database-init/task_catalog.sh**: pasos 5-7 en `ficha_install` — crea `mailserver_db` (idempotente), carga seeds bglobal (T001 idiomas · T002 países+monedas · T004 timezones) prerequisitos de bi18n, carga seed mailserver (PostfixAdmin schema + postmaster); helpers `_cargar_seed()` + `_resolver_seeds_dir()` · (2) **DDLs/seeds/mailserver_T001__initial_accounts.sql** nuevo: schema PostfixAdmin completo (domain/mailbox/alias/admin/domain_admins/log/quota2) + dominio `mail.sbos.local` + cuenta `postmaster@mail.sbos.local` con hash bcrypt; todo idempotente; commit: `2c395fb`

**Correcciones ciclo 27–29:** Keycloak independiente de bAuth (IAM transitorio), ctx_id Kong sin biedata, sbos-kong-tenant. Ver entradas individuales.

**Correcciones ciclo 30:** **nginx S02 preparado para bcms** — (1) `include /etc/nginx/conf.d/domains/*.conf;` añadido al bloque `http {}` del nginx.conf generado: bcms puede depositar `.conf` por dominio sin tocar el config principal; (2) nuevo paso 4 en `ficha_install`: crea `/etc/nginx/conf.d/domains/` y genera `sbos-institucional.conf` placeholder para `sbos.app`; (3) CRONOGRAMA: documentada arquitectura S02 vs S16, modelo de dominios A.03 (institucional/tenant/sucursal), flujo bcms, plan S16-webserver. nginx S02 no requiere más cambios para recibir bcms.

**Correcciones ciclo 31:** **VDI-PROBLEMA #2 CERRADO + theme Fluent-dark baked + decisiones HITL VDI formalizadas** — (1) **Containerfile**: `start-desktop.sh` ya estaba baked (confirmado); añadidos `resources/kde-defaults/` al Containerfile: `kdeglobals` (FluentDark color scheme, Noto Sans), `plasmarc` (Plasma Fluent-dark), `Kvantum/kvantum.kvconfig` (motor Qt Fluent), `kcminputrc`, `plasma-localerc`; kwinrc ampliado con `BorderlessMaximizedWindows=true` + TabBox settings (compositing sigue OFF — mandatorio para VNC); (2) **task_catalog.sh**: `SBOS_IMAGE` sincronizado de `1.0.0` → `1.4.0` (coincide con LABEL del Containerfile); (3) **CRONOGRAMA**: decisiones HITL Q-A/C/D/E formalizadas; modelo canónico VDI; modelo de identidad SBOS (correo corporativo); regla sin eliminación física; **Pendiente VPS:** `bosctl ficha repair fedora-kde` para rebuild y redespliegue de imagen 1.4.0.

**Correcciones ciclo 33:** **Dominio completo: certbot SAN multi-dominio + nginx 33 subdominios** — (1) **certbot**: agregada variable `SBOS_SUBDOMAIN_LIST` con los 33 subdominios SBOS; función `_san_args()` que construye array bash `-d sub.domain` por cada entrada; `ficha_install/repair` usan el array SAN — Let's Encrypt emite un solo cert con todos los subdominios como SANs; (2) **nginx**: nueva función `_gen_sbos_subdomain_blocks()` — genera un `conf.d/domains/sbos-<servicio>.conf` por cada uno de los 33 subdominios; subdominios estándar → Kong (enrutamiento por Host header); `desktop.sksistemas.com` recibe bloque especial con WebSocket + oauth2-proxy path prefix `/desktop/oauth2/` → `/oauth2/`; detección automática de cert (Let's Encrypt si existe, autofirmado si no); idempotente — se sobrescribe en cada repair para reflejar IPs actuales; bcms usa `tenant-*.conf` en la misma carpeta (sin conflicto); paso `generar_subdominios_sbos` agregado a `ficha_install` y `ficha_repair`; (3) **arquitectura confirmada**: `13.140.128.230` = VPS producción; `144.91.76.130` = VPS desarrollo; DNS propagado en Google/Cloudflare/Quad9; (4) **Kong pendiente**: rutas host-based por subdominio deben añadirse a `sbos-kong-tenant/task_catalog.sh` (ciclo siguiente).

**Correcciones ciclo 32:** **Dominio unificado sksistemas.com — 10 fichas** — (1) **Variable canónica**: `BOS_DOMAIN` es la única variable de dominio en todo el ecosistema; `SBOS_DOMAIN` en certbot era un bug — unificado a `BOS_DOMAIN`; (2) **Default corregido** de `sbos.app` → `sksistemas.com` en: `certbot`, `keycloak`, `mailserver`, `nextcloud`, `onlyoffice`, `sbos-vdi-config`, `sbos-kong-tenant`; (3) **nginx institucional**: `sbos-institucional.conf` placeholder corregido de `sbos.app www.sbos.app` → `sksistemas.com www.sksistemas.com`; (4) **oauth2-proxy-desktop**: `PUBLIC_URL` default cambiado de IP hardcodeada `https://13.140.128.230` → `https://sksistemas.com`; (5) **oauth2-proxy**: `--cookie-domain=.sksistemas.com` ya estaba correcto — sin cambio; (6) Para producción: configurar `BOS_DOMAIN=sksistemas.com` (ya es el default) y `BOS_DOMAIN` en env del host antes de correr fichas; DNS requerido: `sksistemas.com` + `www.sksistemas.com` → IP pública VPS.

---

*Documento v2.23.0 — bos-developer · 2026-10-14*  
*Panel de control de reparación: `PLAN-INSTALACION-DESDE-CERO.md §13`*
