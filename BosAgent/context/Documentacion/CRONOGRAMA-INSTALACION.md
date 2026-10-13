# Cronograma de Instalación — Ficha por Ficha

**Versión:** 2.3.0  
**Fecha:** 2026-10-13  
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

**Faltantes:**
- ⚠️ `configurar_kubectl`: en primera instalación hace SKIP porque kubectl no existe aún (lo instala sbos-bootstrap-k8s en orden 20). El symlink se crea en un repair posterior.

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

**Faltantes:**
- ⚠️ `configurar_containerd`: hace SKIP en primera instalación (containerd lo instala sbos-bootstrap-k8s en orden 20). Solo actúa en repair posterior.

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

**Faltantes:**
- ⚠️ La regla hairpin NAT puede perderse si el pod de kyverno arranca antes de que se aplique (BUG-36)

**Bugs:**
- ⚠️ BUG-36: hairpin NAT puede no estar activa cuando kyverno admission-controller arranca → falla con `dial tcp 10.96.0.1:443: i/o timeout`. Ver CRONOGRAMA PROBLEMA #1.

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

**Faltantes:**
- ❌ Registrar en `.sbos_state.json` para que el observer la supervise (BUG-31)

**Bugs:**
- ⚠️ BUG-31: ficha huérfana — no está en state, el observer no puede repararla si falla

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

**⚠️ Inconsistencia:** Mismo problema que sbos-bootstrap-platform — no está en state (BUG-31).

**Logros:**
- ✅ Las 4 pruebas pasaron en su momento (el cluster está funcional)

**Faltantes:**
- ❌ Registrar en state (BUG-31)
- ❌ La prueba de hairpin NAT puede fallar si la regla se pierde (BUG-36)

**Bugs:**
- ⚠️ BUG-36: si hairpin NAT no está activa, esta ficha fallará al verificar conectividad al apiserver

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

**Faltantes:**
- ❌ health.check_command ausente en manifest — BOS no detecta "PG no acepta conexiones" proactivamente (GAP-2)
- ❌ Dependencia circular con vault debe eliminarse del manifest (BUG-35)

**Bugs:**
- ⚠️ BUG-35: dependencia circular postgresql → vault → postgresql declarada (no funcional pero conceptualmente incorrecta)

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
- ❌ Admission-controller pod en CrashLoop por hairpin NAT (BUG-36)
- ❌ Switch a modo enforce no ejecutado (pendiente hasta cluster estable + sbos-bootstrap-hard)

**Bugs activos:**
- ❌ BUG-36: admission-controller no puede conectar al apiserver. Fix: verificar regla hairpin NAT + reiniciar pod. Ver CRONOGRAMA PROBLEMA #1.

---

### [110] redis · S01 · ✅ INSTALLED

**Propósito:** Caché y bus de eventos del stack SBOS. Tres bases de datos lógicas: caché genérica (DB 0), registro de ctx_id del Context Plane (DB 1) y Redis Streams para bKernel CDC (DB 2). Requerido por bKernel, Context Plane y múltiples apps.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni, sbos-bootstrap-storage, vault

**🔶 Huevo y gallina:** Mismo patrón que postgresql — declara `vault` como dependencia pero vault se instala después. Fix pendiente: eliminar vault de deps (BUG-35).

**Logros:**
- ✅ Redis 8.6.2 corriendo (1/1 Running)
- ✅ Autenticación con password obligatoria
- ✅ PVC persistente

**Faltantes:**
- ❌ health.check_command ausente (GAP-2)
- ❌ Dependencia circular con vault debe eliminarse (BUG-35)

**Bugs:** ⚠️ BUG-35 (mismo que postgresql)

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
- ❌ ReplicaSets huérfanos de crash anterior consumen recursos (BUG-29)

**Bugs activos:**
- ⚠️ BUG-29: ReplicaSets huérfanos de instalación anterior en namespace `linkerd`. Limpiar con `kubectl get rs -n linkerd | grep "0/0/0"`.
- ⚠️ BUG-33: oauth2-proxy fue inyectado en el mesh antes de que linkerd estuviera completamente estable → sidecar en failfast. Fix: anotar namespace `sbos-gateway` con `linkerd.io/inject=disabled` + rollout restart oauth2-proxy.

---

### [120] minio · S01 · ✅ INSTALLED

**Propósito:** Almacenamiento de objetos compatible S3. Aloja backups SBOS, assets estáticos, documentos de Nextcloud y Paperless, datos de Grafana Loki y Tempo. Tres buckets: `sbos-backups`, `sbos-assets`, `sbos-documents`.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni, sbos-bootstrap-storage, vault

**🔶 Huevo y gallina:** Misma declaración circular con vault (BUG-35). MinIO no necesita Vault para arrancar.

**Logros:**
- ✅ MinIO/SeaweedFS corriendo (1/1 Running) — imagen `chrislusf/seaweedfs` (no requiere auth Docker Hub)
- ✅ 3 buckets S3 creados: sbos-backups, sbos-assets, sbos-documents
- ✅ API S3 en puerto 9000

**Faltantes:**
- ❌ health.check_command ausente (GAP-2)

**Bugs:** ⚠️ BUG-35 (declaración circular vault, misma que PG/Redis)

---

## FASE 4B — Inicialización de la base de datos SBOS (orden ~105) ⚠️ FICHA FALTANTE

> **Este es un GAP crítico del instalador.** PostgreSQL Running ≠ SBOS_db lista.
> El pod de PostgreSQL puede estar corriendo (INSTALLED) pero la base de datos
> `SBOSDB` con sus 158 tablas, 12 schemas y seeds puede no existir.
> Actualmente esto se hace manualmente con psql. Debe existir una ficha
> `sbos-database-init` que lo automatice.

---

### [~105] sbos-database-init · S01 · ⚠️ FICHA FALTANTE (GAP crítico)

**Propósito:** Desplegar el schema completo de `SBOSDB` en el pod de PostgreSQL recién instalado. Ejecutar `SBOS_db_V2_DDL.sql` (158 tablas en 12 schemas: `bos`, `bauth`, `bkernel`, `biedata`, `bsearch`, `bnexus`, `bnotify`, `kong`, `keycloak`, `tryton`, `mattermost`, `audit`). Cargar los seeds iniciales (enums T060, menús contextuales T061, roles template T162, etc.). Verificar que todas las tablas existen y los índices están creados.

**Dependencias:** postgresql

**Por qué es el orden ~105:** postgresql tiene orden 100. Este inicializador debe correr cuando el pod está Running pero ANTES de que las aplicaciones (keycloak, kong, tryton, etc.) intenten usar sus schemas. Slot ideal: orden 105.

**🔶 Huevo y gallina — SCHEMA VS APP:**
- **Fase A (orden ~105):** Crear todos los schemas y tablas vacías con DDL idempotente (`CREATE TABLE IF NOT EXISTS`, `CREATE SCHEMA IF NOT EXISTS`). Los schemas deben existir antes que las apps.
- **Fase B (orden ~160+):** Las apps (keycloak, kong, tryton) crean sus propios registros al arrancar — no van en este seed.
- **Fase C (post-instalación completa):** Seeds de dominio SBOS (bloques de roles, menús contextuales, configuración inicial de tenants) se cargan desde scripts individuales por módulo.

**Estado actual en VPS:**
- `SBOSDB` existe con 158 tablas (se creó manualmente con psql)
- 62 tablas verificadas OK, el resto sin verificar exhaustivamente
- Sin ficha BOS que lo supervise — si se destruye el pod PG, el schema se pierde (PVC Retain conserva los datos pero la ficha no puede repararlos)

**Faltantes:**
- ❌ Crear ficha `servers/S01/sbos-database-init/manifest.yml` con:
  - `execution_order: 105`
  - `dependencies: [postgresql]`
  - `auto_install: true`
- ❌ Crear `task_catalog.sh` que:
  1. Verifica conexión a postgresql: `pg_isready -h <pod-ip> -U postgres`
  2. Ejecuta DDL idempotente: `psql ... -f DDLs/SBOS_db_V2_DDL.sql`
  3. Verifica tabla count: `SELECT count(*) FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog','information_schema')`
  4. Carga seeds críticos: enums de T060, si no existen
  5. Health check: consulta a una tabla crítica (`SELECT 1 FROM bos.bos_ctx_session LIMIT 1`)
- ❌ Crear `health.check_command` que verifique que las tablas existen y el schema está desplegado

**Solución paso a paso:**
```
1. Crear servers/S01/sbos-database-init/ con manifest.yml + task_catalog.sh
2. Execution order: 105 (después de postgresql=100, antes de apps=130+)
3. El task_catalog.sh ejecuta DDLs/SBOS_db_V2_DDL.sql via kubectl exec al pod postgresql
4. Verificar: SELECT count(*) FROM information_schema.tables = 158
5. bosctl ficha install sbos-database-init
```

**Riesgo si no se crea:**
- Si el pod de postgresql se destruye (o el PVC se pierde), la base de datos hay que recrear manualmente. BOS no puede repararlo.
- Las apps que arrancan por primera vez asumen que sus tablas existen → falla silenciosa.

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
- **Fase 1 (orden 130):** Pod Vault arranca. Estado: SEALED. No puede servir secretos.
- **Fase 2 (MANUAL OBLIGATORIA):** `vault operator init` (genera 5 unseal keys) + `vault operator unseal` (3 de 5 keys). Sin esto el pod está Running pero no sirve nada.
- **Fase 3 (automática post-unseal):** Vault configura AppRole `sbos-pods`, PKI engine, KV v2, políticas. Las aplicaciones obtienen tokens de AppRole para leer sus credenciales.
- **Fase 4 (permanente):** Cada vez que el pod se reinicia, vuelve a sellarse → necesita el proceso de unseal de nuevo. FIX-26A (liveness probe) previene el CrashLoop → FIX-B (observer) lo repara automáticamente.

**Logros:**
- ✅ StatefulSet desplegado con PVC Retain
- ✅ Backend PostgreSQL configurado (HA Raft)
- ✅ FIX-26A commiteado: liveness probe corregido a `sealedok=true` (pod no muere cuando sellado)

**Faltantes:**
- ❌ FIX-26A no aplicado en VPS aún — vault sigue en CrashLoop (95+ reinicios)
- ❌ health.check_command ausente: `vault status | grep "Sealed: false"` (GAP-2)
- ❌ Auto-unseal: aún requiere intervención manual tras cada reinicio del pod

**Bugs activos:**
- ❌ BUG-26: pod en CrashLoop (liveness probe sin sealedok=true). Fix: CRONOGRAMA PROBLEMA #2.
- ❌ BUG-27: oauth2-proxy y tryton bloqueados en cascada hasta que vault sea estable.

---

### [135] besu-qbft · S02 · ✅ INSTALLED

**Propósito:** Red blockchain soberana QBFT (Proof of Authority). Aloja los contratos `SettlementEngine.sol` y `AuditAnchor.sol` que bAuth usa para el módulo D12 (settlment y auditoría inmutable). 1 nodo validador, Chain ID 1337.

**Dependencias:** postgresql, vault

**Logros:**
- ✅ Hyperledger Besu 24.12.0 corriendo
- ✅ Génesis QBFT inicializado
- ✅ RPC :8545, WS :8546 accesibles

**Faltantes:**
- ❌ health.check_command ausente (GAP-2)
- ❌ Contratos AuditAnchor.sol y SettlementEngine.sol no desplegados (pendiente fase de bAuth D12)

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

**Faltantes:**
- ❌ SPIs SKULL sin implementar (pendiente desarrollo bAuth)
- ❌ `Web Origins: *.empresa.sbos.app` para SSO multi-subdominio (SSO-2)

**Bugs:** ninguno activo

---

### [150] oauth2-proxy · S02 · ❌ PHYSICAL_ERROR (derivado de vault)

**Propósito:** Proxy de autenticación OIDC que protege las aplicaciones internas sin que necesiten implementar lógica de auth. Valida el token JWT contra Keycloak e inyecta headers `X-Forwarded-User`, `X-Forwarded-Email`, `X-Forwarded-Groups` en cada request.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni, keycloak, vault, kong

**🔶 Huevo y gallina:** oauth2-proxy necesita vault para leer el client_secret de Keycloak. Si vault está down, oauth2-proxy no puede arrancar. Adicionalmente, el sidecar de linkerd en el pod de oauth2-proxy falla si linkerd no está completamente estable (BUG-33).

**Logros:**
- ✅ Deployment configurado con AppRole de Vault
- ✅ NetworkPolicy hacia Keycloak configurada

**Faltantes:**
- ❌ Pod en PHYSICAL_ERROR — se recupera automáticamente cuando vault sea estable (FIX-B observer activo)
- ❌ Sidecar linkerd debe deshabilitarse en este namespace (BUG-33)

**Bugs activos:**
- ❌ BUG-27: PHYSICAL_ERROR derivado de vault. Fix: aplicar FIX-26A en VPS (CRONOGRAMA PROBLEMA #3).
- ❌ BUG-33: inyección de sidecar linkerd prematura. Fix: `linkerd.io/inject=disabled` en namespace.

---

### [160] kong · S02 · ✅ INSTALLED

**Propósito:** API Gateway soberano. Punto único de entrada a todas las APIs del sistema. JWT validation, rate limiting, plugin Lua `SBOS-Context` que inyecta el `ctx_id` en cada request para trazabilidad. DB mode con `kong_db` en PostgreSQL.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni, postgresql, keycloak, vault

**Logros:**
- ✅ Kong 3.9.x LTS corriendo (1/1 Running)
- ✅ Admin API :8001, Proxy :8000/:8443, Status :8007
- ✅ Base de datos `kong_db` inicializada

**Faltantes:**
- ❌ health.check_command ausente (GAP-2)
- ❌ Plugin Lua SBOS-Context (ctx_id injection) no desplegado — pendiente desarrollo
- ❌ Rutas y servicios de aplicaciones configurados manualmente (no via ficha declarativa)

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

**Faltantes:**
- ❌ GAP-nginx-1: no hay ficha `sbos-kong-tenant` para automatizar rutas Kong por tenant
- ❌ GAP-nginx-2: Certbot (TLS Let's Encrypt real) solo funciona con dominio DNS público
- ❌ UPDATE_AVAILABLE: imagen nginx en VPS puede diferir de manifest v1.28.0

**Bugs:** ninguno activo (nginx corre correctamente — UPDATE_AVAILABLE es de versión, no de funcionalidad)

---

### [170] sbos-notifier · S06 · ✅ INSTALLED

**Propósito:** Sistema de notificaciones universales del stack SBOS. Push MFA (OTP, TOTP, WebAuthn), alertas críticas del sistema, mensajes a usuarios. Requerido por bAuth para el flujo Step-Up de autenticación (RFC 9470).

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni, postgresql, redis, vault, keycloak, kong

**Logros:**
- ✅ sbos-notifier (bnotify) corriendo (1/1 Running)
- ✅ Integrado con keycloak para autenticación

**Faltantes:**
- ❌ health.check_command ausente (GAP-2)

**Bugs:** ninguno activo

---

### [180] certbot · S02 · ✅ INSTALLED

**Propósito:** Certificados TLS Let's Encrypt para el dominio público. HTTP-01 challenge via webroot de nginx. NO es un pod K8s — es un systemd timer en el host que renueva el certificado cada 60 días.

**Dependencias:** nginx

**Logros:**
- ✅ certbot instalado como systemd timer en host S02
- ✅ Certificados TLS generados

**Faltantes:**
- ⚠️ Solo funciona si el dominio público está apuntando a esta VPS (DNS configurado)

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

**Faltantes:**
- ❌ health.check_command ausente (GAP-2)
- ❌ Streams Redis sin consumidores activos aún (pendiente desarrollo de consumidores bAuth/bsearch)

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

**Faltantes:**
- ❌ health.check_command ausente (GAP-2)
- ❌ Scraping de daemons SBOS (9400-9499) incompleto — daemons aún no exponen métricas

**Bugs:** ninguno activo

---

### [205] alertmanager · S12 · ✅ INSTALLED

**Propósito:** Enrutamiento de alertas. Reglas SBOS predefinidas: WAL lag en PostgreSQL, Vault sellado, DLQ depth alto, pod down. Routing hacia sbos-notifier para Push MFA a los administradores.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni, prometheus

**Logros:**
- ✅ Alertmanager 0.28.1 corriendo
- ✅ Reglas SBOS configuradas

**Faltantes:**
- ❌ Routing hacia sbos-notifier no configurado aún

**Bugs:** ninguno activo

---

### [215] grafana · S12 · ✅ INSTALLED

**Propósito:** Visualización de métricas y logs. OAuth2 Keycloak (SSO). Dashboards SBOS precargados. Datasources configurados: Prometheus, PostgreSQL directo, Loki (cuando esté instalado).

**Dependencias:** sbos-bootstrap-storage, prometheus, keycloak, vault

**Logros:**
- ✅ Grafana 12.0.1 corriendo (1/1 Running)
- ✅ OAuth2 Keycloak configurado (SSO)
- ✅ Datasource Prometheus conectado

**Faltantes:**
- ❌ Datasource Loki no disponible (loki es STUB)
- ❌ Dashboards SBOS básicos — pendiente diseño

**Bugs:** ninguno activo

---

### [215] loki · S12 · ⚙️ PENDING (STUB — 135 líneas)

**Propósito:** Agregación y búsqueda de logs de todos los pods del cluster. Recibe logs de Grafana Alloy, los indexa con labels de K8s (namespace, pod, container) y el `ctx_id` SBOS extraído por Alloy. Grafana los visualiza.

**Dependencias:** prometheus, grafana, minio

**⚠️ STUB:** La ficha tiene solo 135 líneas — deploy básico sin configuración real de almacenamiento en MinIO, sin retención configurada, sin pipeline de labels ctx_id.

**Logros:** ninguno (STUB sin deploy real completado)

**Faltantes:**
- ❌ Deploy completo de Loki con backend S3 en MinIO
- ❌ Pipeline de labels ctx_id configurado
- ❌ Política de retención definida

**Bugs:** ninguno activo (no está instalado)

---

### [220] alloy · S12 · ✅ INSTALLED

**Propósito:** Pipeline de logs y métricas (reemplaza Grafana Agent). Recoge logs de todos los pods del cluster, extrae el `ctx_id` de los logs SBOS usando regex, y los envía a Loki. También recolecta métricas adicionales.

**Dependencias:** sbos-bootstrap-k8s, sbos-bootstrap-cni, prometheus

**Logros:**
- ✅ Grafana Alloy 1.8.3 corriendo (1/1 Running)
- ✅ Pipeline de recolección de logs configurado

**Faltantes:**
- ❌ Envío a Loki bloqueado (Loki es STUB — no está instalado)
- ❌ Extracción de ctx_id configurada pero sin destino operativo

**Bugs:** ninguno activo

---

### [220] tempo · S12 · ⚙️ PENDING (STUB — 98 líneas)

**Propósito:** Trazado distribuido (distributed tracing). Recibe spans de aplicaciones instrumentadas con OpenTelemetry, los almacena y los hace consultables desde Grafana.

**Dependencias:** loki, prometheus

**⚠️ STUB:** 98 líneas — la ficha más corta del catálogo. Sin configuración de backend S3.

**Logros:** ninguno (STUB)

**Faltantes:** deploy completo con backend MinIO y correlación ctx_id

**Bugs:** ninguno activo

---

### [225] zabbix · S12 · ⏳ NO_INSTALADA (auto_install: false — STUB)

**Propósito:** Monitoreo de infraestructura tradicional (host, red, hardware). Complementa Prometheus para alertas de hardware y disponibilidad de servicios no K8s.

**Dependencias:** postgresql, grafana

**Estado:** No instalado. auto_install=false + STUB 140 líneas.

**Logros:** ninguno

**Faltantes:** decisión de si es parte del MVP (Q-5 HITL §11.4)

---

### [250] sbos-bootstrap-hard · S-HOST · ✅ INSTALLED

**Propósito:** Hardening final del cluster. UFW deny-all (solo puertos 22/80/443 permitidos desde exterior), Calico default-deny en modo enforcement, Kyverno switch de `audit` a `enforce`, CIS Ubuntu 26.04 Benchmark y CIS K8s Benchmark. Esta es la última ficha de infraestructura.

**Dependencias:** sbos-bootstrap-cni, sbos-bootstrap-k8s, sbos-bootstrap-monitoring, prometheus, grafana

**🔶 Huevo y gallina — FASE FINAL DE KYVERNO:**
- Kyverno se instaló en orden 100 en modo `audit` (no rechaza nada).
- En esta ficha (orden 250) se activa el modo `enforce`. Desde aquí, pods sin probes son rechazados.
- Por eso el hardening es lo ÚLTIMO: todos los pods del stack ya están instalados y tienen probes.

**⚠️ ADVERTENCIA:** Si kyverno no está completamente funcional (BUG-36), el switch a enforce fallará o kyverno quedará en un estado inconsistente.

**Logros:**
- ✅ UFW activo con reglas mínimas
- ✅ Calico en modo enforcement

**Faltantes:**
- ❌ Kyverno aún NO está en modo enforce (admission-controller en CrashLoop por BUG-36)

**Bugs:** ⚠️ Depende de BUG-36 (kyverno) estar resuelto antes de que sbos-bootstrap-hard ejecute el switch

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

**Faltantes:**
- ❌ auto_install no definido en manifest (GAP-6)
- ❌ Editor OnlyOffice sin conectar a nextcloud (requiere configuración manual post-install)

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

**Faltantes:**
- ❌ Tabla `guacamole_connection` vacía — ningún escritorio configurado (GAP-4 crítico)
- ❌ health.check_command ausente (GAP-2)
- ❌ auto_install no definido en manifest (GAP-6)

**Bugs:**
- ❌ GAP-4: guacamole arranca sin conexiones. El gateway existe pero no apunta a ningún escritorio.

---

### [220] onlyoffice · S13 · ✅ INSTALLED

**Propósito:** Editor de documentos Office colaborativo en tiempo real. Integrado con Nextcloud para editar .docx, .xlsx, .pptx directamente en el navegador. Multi-usuario simultáneo.

**Dependencias:** postgresql, redis, kong

**Logros:**
- ✅ OnlyOffice Document Server 8.2.2 corriendo (1/1 Running)
- ✅ Memory limit 3Gi (FIX-24: antes 2Gi causaba OOMKill)
- ✅ CPU request 200m (FIX-24: antes 500m causaba Insufficient CPU)

**Faltantes:**
- ❌ Conectado a Nextcloud pero sin configuración declarativa (manual post-install)
- ❌ auto_install no definido en manifest (GAP-6)

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

**Faltantes:**
- ❌ Pod en PHYSICAL_ERROR — derivado de vault (misma cadena que oauth2-proxy)
- ❌ auto_install no definido en manifest (GAP-6)

**Bugs activos:**
- ❌ PHYSICAL_ERROR derivado de vault. Se resuelve con FIX-26A + FIX-B observer.

---

### [230] fedora-kde · S13 · ⏸️ UPDATE_AVAILABLE

**Propósito:** Escritorio virtual corporativo soberano. Un usuario Keycloak autenticado recibe un pod Fedora 44 + KDE Plasma 6 personalizado: sus archivos, sus apps permitidas según su rol, su configuración de escritorio — todo persistente entre sesiones. Accesible desde cualquier navegador sin instalar nada en el cliente.

**Dependencias:** keycloak, kong, guacamole

---

#### Arquitectura VDI completa (objetivo de diseño)

```
                    IDENTIDAD ÚNICA POR USUARIO
                           │
                    Keycloak JWT contiene:
                    - username: juan.perez
                    - email: juan.perez@empresa.sbos.app
                    - groups: [empleados, contabilidad, fedora_user]
                           │
nginx → oauth2-proxy-desktop (extrae JWT) → sbos-vdi-provisioner
                                                    │
                         ┌──────────────────────────┤
                         ▼                          ▼
              Pod fedora-kde-juan.perez    PVC fedora-home-juan.perez
              (creado si no existe)        10 Gi, /home/juan.perez/
                         │                  archivos, config KDE,
              Perfil cargado según          historial, escritorio
              grupos Keycloak:
              - Apps en menú KDE
              - Nivel sudo
              - Acceso a impresoras/USB
```

---

#### Perfiles de usuario — grupos Keycloak → capacidades Fedora

| Grupo Keycloak | Perfil Fedora | Sudo | Apps disponibles | Persistencia |
|----------------|---------------|------|------------------|--------------|
| `fedora_admin` | wheel | Completo | Todas + terminal | PVC 20 Gi |
| `fedora_user` | usuarios | Sin sudo | Apps empresa (Tryton, correo, Nextcloud) | PVC 10 Gi |
| `fedora_readonly` | readonly | Sin sudo | Solo lectura, sin instalar | PVC 5 Gi |
| `fedora_guest` | guest | Sin sudo | Navegador, visor documentos | Sin PVC (tmpfs) |

**Implementación del perfil:**
1. `sbos-vdi-provisioner` crea el pod con variables de entorno `SBOS_USER`, `SBOS_GROUPS`
2. El `start-desktop.sh` de la imagen lee esas variables y:
   - Crea el usuario Linux si no existe (`useradd -m -u <uid> <username>`)
   - Monta el PVC como `/home/<username>/`
   - Genera `~/.config/menus/applications.menu` con las apps del grupo
   - Configura sudoers si el grupo es `fedora_admin`
3. TigerVNC arranca como ese usuario (no como `sbosuser` genérico)

---

#### Identidad de correo = identidad VDI

El email del usuario (`juan.perez@empresa.sbos.app`) es su identidad principal:
- **Mailserver (Postfix+Dovecot):** autentica via Keycloak SASL → el buzón se crea automáticamente cuando el usuario existe en Keycloak
- **VDI:** el email del JWT (`X-Forwarded-Email`) determina qué pod y qué PVC se asignan
- **Nextcloud:** el mismo usuario Keycloak tiene acceso a sus archivos en la nube
- **Tryton ERP:** el mismo usuario con sus permisos de módulo

**Un solo usuario, una sola contraseña, todos los servicios.**

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
| 5 | Keycloak: `Web Origins *.empresa.sbos.app` configurado | Bajo | Manualidad actual |
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

**VDI-PROBLEMA #3 — VDI-GAP-1: 1 pod compartido para TODOS los usuarios**

- **Síntoma:** Si dos usuarios hacen login al mismo tiempo, ambos ven el mismo escritorio.
- **Causa:** `replicas: 1` en el Deployment — hay un solo pod para todo el sistema.
- **Impacto:** Multi-usuario imposible. Privacidad comprometida (usuario A ve lo que hizo usuario B).
- **Arquitectura objetivo:**
  ```
  Guacamole recibe conexión de usuario A
    → Consulta sbos-vdi-provisioner (nuevo daemon a crear)
    → provisioner busca/crea pod fedora-kde-userA
    → Guacamole conecta al VNC del pod específico de ese usuario
  ```
- **Solución:** Crear `sbos-vdi-provisioner` — un daemon Go que:
  1. Expone API: `POST /api/vdi/session {user_id}` → devuelve IP:puerto del pod VNC del usuario
  2. Al recibir la solicitud: verifica si existe pod `fedora-kde-{user_id}`, si no → crea Deployment dinámico
  3. Limpia pods inactivos (TTL configurable)
- **Dependencia de HITL:** Decisión Q-3 pendiente sobre arquitectura de sesiones (1-pod-por-usuario vs pod-pool vs pod-compartido-con-sesiones).
- **Verificación:** Dos usuarios distintos conectados simultáneamente → escritorios completamente independientes.

---

**VDI-PROBLEMA #4 — VDI-GAP-2: sin PVC por usuario (home temporal)**

- **Síntoma:** Al reiniciar el pod fedora-kde, el home del usuario (`/home/sbosuser/`) desaparece — archivos, configuración, historial de trabajo, todo perdido.
- **Causa:** El pod no tiene PVC propio. El sistema de archivos es ephemeral (emptyDir o la capa de escritura del contenedor).
- **Impacto:** Cada login es como entrar por primera vez. Inaceptable para uso corporativo.
- **Solución:**
  1. Agregar al Deployment de fedora-kde un PVC por usuario:
     ```yaml
     volumes:
     - name: user-home
       persistentVolumeClaim:
         claimName: "fedora-kde-home-{user_id}"
     ```
  2. El PVC se crea en el mismo `sbos-vdi-provisioner` cuando crea el pod de usuario
  3. Política: `Retain` → datos sobreviven aunque el pod se destruya
  4. Cuota por usuario: 10 Gi (configurable en sbos-vdi-config)
- **Verificación:** Crear archivo en `/home/sbosuser/test.txt` → reiniciar pod → el archivo sigue existiendo.

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

**Faltantes:**
- ❌ VDI-PROBLEMA #2: eliminar ConfigMap y rebuildar imagen (1-2 días)
- ❌ VDI-PROBLEMA #3: crear sbos-vdi-provisioner (semana, depende HITL Q-3)
- ❌ VDI-PROBLEMA #4: agregar PVC por usuario (depende del provisioner)
- ❌ VDI-PROBLEMA #5: bloquear puerto 6901 (30 minutos — urgente, en VPS)
- ❌ Rebuild imagen `sbos/fedora-desktop:1.4.0` y desplegar en VPS
- ❌ SSO-2: Keycloak `Web Origins: *.empresa.sbos.app` (configuración realm)
- ❌ SSO-3: Kong plugin JWT → Bearer token relay a upstream
- ❌ SSO-4: Nextcloud plugin OIDC activado (app ya instalada — solo config)
- ❌ AUDIT-1: oauth2-proxy registra inicio/fin sesión VDI en `bos.bos_ctx_session`

**Orden recomendado de resolución:** #5 (urgente seguridad) → #1 (trivial) → #2 (bajo riesgo) → #6 (Keycloak Web Origins) → #3+#4 (provisioner, requiere HITL)

---

### [420] sbos-vdi-config · S13 · ⏳ NO_INSTALADA (auto_install: false)

**Propósito:** Configuración final del ecosistema VDI: rutas Kong para `/nextcloud/`, `/onlyoffice/`, `/desktop/`, cliente OIDC `sbos-desktop` en realm Keycloak, NetworkPolicies que permiten sbos-vdi → sbos-data y sbos-security.

**Dependencias:** nextcloud, onlyoffice, guacamole, keycloak, kong

**Estado:** No instalada. Depende de que todas las fichas VDI estén INSTALLED primero.

**Logros:** ninguno (no instalada — parte de su configuración se hizo manualmente)

**Faltantes:**
- ❌ Instalar con `bosctl ficha install sbos-vdi-config` cuando todas las fichas VDI estén INSTALLED
- ❌ Rutas Kong VDI configuradas manualmente en lugar de via esta ficha

---

## FASE 11 — Aplicaciones de negocio (órdenes 170–180)

> Estas fichas requieren aprobación manual (auto_install: false) o dependen
> de decisiones HITL pendientes. Se instalan por tenant según sus necesidades.

---

### [170] tryton (S01) · ⚙️ INSTALL_FAILED | [170] tryton (S04) · ⏳ NO_INSTALADA

**Propósito:** ERP soberano Tryton 7.4. Módulos de contabilidad, inventario, ventas y RRHH. MDM (Master Data Management) hub vía bKernel CDC.

**Dependencias:** postgresql, vault, kong

**⚠️ INC-1 — DUPLICADO CRÍTICO:** `S01/tryton` y `S04/tryton` son archivos idénticos (566 líneas, diff = 0). BOS puede registrar dos fichas con IDs en conflicto. Requiere respuesta HITL Q-1 antes de continuar.

**Logros:**
- ⚠️ S01/tryton: instalación intentada — falló porque vault estaba down

**Faltantes:**
- ❌ Resolver duplicado S01/S04 (Q-1 HITL)
- ❌ Instalar tras vault estable: `bosctl ficha install tryton`
- ❌ Vault mount `sbos/` configurado para credenciales Tryton

**Bugs activos:**
- ❌ INC-1: duplicado S01=S04 — decision del humano requerida
- ❌ INSTALL_FAILED en S01 derivado de vault caído

---

### [175] tryton-workers · S04 · ⏳ NO_INSTALADA

**Propósito:** Procesos de cola de tareas asíncronas del ERP (informes, importaciones masivas, exportaciones).

**Dependencias:** tryton

**⚠️ INC-7:** No declara dependencia en `tryton` (S01) en su manifest. Puede intentar instalarse antes que Tryton esté listo.

**Logros:** ninguno

**Faltantes:** Agregar `tryton` a dependencies del manifest + instalar tras tryton INSTALLED

---

### [172] mattermost · S10 · ⏳ NO_INSTALADA (auto_install: false — 260 líneas)
### [177] mattermost · S06 · ⚙️ PENDING (auto_install: true)

**Propósito:** Chat empresarial SBOS. Canales por daemon, webhooks de alertas del sistema, mensajería interna del equipo.

**⚠️ INC-5 — DUPLICADO:** S06/mattermost (726 líneas, robusta, auto_install:true) y S10/mattermost (260 líneas, básica, auto_install:false). IDs en conflicto. Requiere respuesta HITL Q-4.

**Logros:** ninguno (S06 en PENDING por deps)

**Faltantes:** Resolver duplicado (Q-4 HITL) + instalar tras vault estable

---

### [174] ferretdb · S06 · ⚙️ PENDING
### [175] calcom · S06 · ⚙️ PENDING
### [176] novu · S06 · ⚙️ PENDING

**Propósito:**
- **ferretdb:** MongoDB wire-compatible sobre PostgreSQL. Backend de Novu.
- **calcom:** Plataforma de agendamiento Cal.com. Gestión de citas y reuniones.
- **novu:** Sistema de notificaciones multi-canal (email, SMS, push, in-app).

**Estado:** En PENDING esperando dependencias (vault caído bloquea la cadena). Se instalarán automáticamente tras vault INSTALLED (auto_install:true en algunos).

**Logros:** ninguno

**Faltantes:** Vault estable → instalación automática o manual según auto_install

---

## FASE 12 — Correo (S10, órdenes 300–315)

> Módulo de correo electrónico soberano. La identidad de correo ES la identidad SBOS:
> el mismo usuario Keycloak que accede al VDI tiene su buzón de correo en el mailserver.
> Requiere dominio público con registro MX configurado en DNS.

---

#### Concepto: correo como capa de identidad, no sistema separado

El mailserver SBOS NO es un sistema de correo independiente con sus propios usuarios. Es una **extensión de identidad Keycloak**:

```
Administrador crea usuario en Keycloak:
  username: juan.perez
  email: juan.perez@empresa.sbos.app
  groups: [empleados, fedora_user, correo_activo]
              │
              ├── Keycloak gestiona la contraseña y el SSO
              ├── mailserver (Postfix+Dovecot) autentica CONTRA Keycloak
              │   via SASL → el buzón se crea automáticamente
              ├── VDI: ese usuario tiene su pod Fedora y su PVC
              └── Roundcube/Cypht: login con las mismas credenciales
```

**El usuario NUNCA tiene contraseñas separadas.** Una contraseña Keycloak → todo el ecosistema SBOS.

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

**Logros:** ninguno (STUB 135 líneas)

**Faltantes:**
- ❌ Completar ficha a nivel ROBUSTO (target: 400+ líneas)
- ❌ Configurar Dovecot SASL → Keycloak LDAP
- ❌ Crear `mailserver_db` schema en PostgreSQL (tabla `virtual_mailboxes`, `virtual_aliases`)
- ❌ Configurar PVC `/data/mailserver/` con política Retain
- ❌ Abrir puertos 25/465/587 (SMTP) y 993 (IMAPS) en UFW cuando se instale
- ❌ health.check_command: `postfix status && dovecot --version`

---

### [305] postfixadmin · S10 · ⏳ NO_INSTALADA

**Propósito:** UI web de administración del mailserver. Crear/eliminar buzones, alias, dominios. Alternativa a editar la BD directamente. Autenticación via Keycloak SSO (solo admins con grupo `mail_admin`).

**Logros:** ninguno (STUB 135 líneas)

**Faltantes:** Completar ficha ROBUSTO + integración Keycloak

---

### [310] roundcube · S10 · ⏳ NO_INSTALADA

**Propósito:** Cliente webmail para usuarios. Acceden a su correo desde el navegador (o desde el escritorio VDI — Roundcube se puede instalar como app en el menú KDE de Fedora). Login con credenciales Keycloak via IMAP OAuth2.

**Logros:** ninguno (STUB 135 líneas)

**Faltantes:** Completar ficha ROBUSTO + OAuth2 Keycloak como método de login

---

### [315] cypht · S10 · ⏳ NO_INSTALADA

**Propósito:** Webmail alternativo modular con soporte para múltiples cuentas (IMAP, calendarios, RSS). Más ligero que Roundcube. Puede convivir con Roundcube como opción de cliente.

**Logros:** ninguno (STUB 135 líneas)

**Faltantes:** Completar ficha ROBUSTO

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

**Propósito:** Gestión documental soberana: OCR automático (tesseract), archivo digital con indexado full-text (paperless-ngx), firma digital (docuseal), ECM empresarial (kimios), extractor de tablas de PDFs (tabula).

**Estado:** Todas STUBs 135 líneas. No instaladas.

**Logros:** ninguno

**Faltantes:** Completar a nivel ROBUSTO + instalar por tenant

---

## FASE 14 — Búsqueda y mensajería (S09, órdenes 400–405)

---

### [400] elasticsearch · [405] rabbitmq · S09 · ⏳ NO_INSTALADAS

**Propósito:** Motor de búsqueda full-text (elasticsearch) y broker de mensajes AMQP (rabbitmq). Backend de bsearch y bus de eventos entre servicios.

**Estado:** STUBs 135 líneas. No instaladas.

---

## FASE 15 — DevOps (S14, órdenes 450–460)

---

### [450] gitlab · [455] bareos · [460] velero · S14 · ⏳ NO_INSTALADAS

**Propósito:** Plataforma DevOps soberana (GitLab CE), backup empresarial (Bareos) y backup K8s (Velero).

**Estado:** STUBs 135 líneas. No instaladas.

---

## FASE 16 — Inteligencia Artificial (S15, órdenes 500–525)

---

### [500] ollama · [505] qdrant · [510] open-webui · [515] embedding-worker · [520] langfuse · [525] flowise · S15 · ⏳ NO_INSTALADAS

**Propósito:** Stack de IA soberana: servidor de modelos LLM locales (ollama), base de datos vectorial RAG (qdrant), interfaz web de chat (open-webui), worker de embeddings de documentos (embedding-worker), observabilidad de LLMs (langfuse), orquestador visual de flujos LLM (flowise).

**Estado:** Todas STUBs 135 líneas. No instaladas.

---

## Mapa de problemas activos — con soluciones concretas

> Esta sección agrupa todos los bugs activos por prioridad con:
> **síntoma → causa raíz → solución paso a paso → verificación**.
> El orden es el de resolución recomendado (cada bloque desbloquea el siguiente).

---

### BLOQUE A — VPS inmediata (desbloquean toda la cadena)

---

**PROBLEMA A-1 — BUG-36: hairpin NAT puede no estar activa → kyverno admission-controller falla**

- **Síntoma:** `kubectl logs -n kyverno deploy/kyverno-admission-controller` muestra `dial tcp 10.96.0.1:443: i/o timeout`. kyverno queda en PENDING sin poder registrar sus webhooks.
- **Causa raíz:** Hetzner VPS no provee hairpin NAT. Los pods no pueden alcanzar la IP pública del servidor (que es el endppoint del apiserver K8s externamente). La regla iptables que FIX-19 agrega puede perderse al reiniciar el host o al reiniciar iptables.
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

**PROBLEMA A-6 — linkerd ReplicaSets huérfanos consumen recursos**

- **Síntoma:** `kubectl get rs -n linkerd | grep "0/0/0"` muestra varios ReplicaSets con 0 pods deseados/actuales/listos.
- **Causa:** Instalaciones anteriores fallidas de linkerd dejaron ReplicaSets obsoletos. Consumen entradas en etcd y confunden al observer.
- **Solución:**
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

**PROBLEMA B-1 — BUG-35: dependencia circular PG/Redis/MinIO → vault**

- **Síntoma:** `bosctl ficha status postgresql` muestra dependencias bloqueadas. El DAG del observer puede calcular orden incorrecto.
- **Causa:** `manifest.yml` de postgresql, redis y minio declaran `vault` como dependencia. Vault declara `postgresql` como dependencia. Ciclo: PG→Vault→PG.
- **Solución (3 archivos a editar):**
  ```yaml
  # En servers/S01/postgresql/manifest.yml — ELIMINAR vault de dependencies
  # En servers/S01/redis/manifest.yml — ELIMINAR vault de dependencies
  # En servers/S01/minio/manifest.yml — ELIMINAR vault de dependencies
  # (Ninguno de estos 3 necesita Vault para arrancar)
  ```
- **Razonamiento:** PG, Redis y MinIO arrancan con credenciales generadas en el momento (openssl rand). Vault los toma bajo control DESPUÉS de instalarse. La dependencia es Vault→PG, no PG→Vault.
- **Verificación:** `bosctl observer dag` → no debe mostrar ciclos en el grafo de dependencias.

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

**PROBLEMA B-3 — GAP-4: guacamole sin conexiones → escritorio inaccesible vía Guacamole**

- **Síntoma:** El usuario hace login en Guacamole (`/guacamole/`), ve la interfaz, pero la lista de conexiones está vacía. No puede conectar a ningún escritorio.
- **Causa:** `guacamole_connection` en la BD `guacamole_db` está vacía. Guacamole no autodetecta los pods VNC — hay que decirle explícitamente a qué IP:puerto conectar.
- **Solución — agregar a `ficha_post_install()` de guacamole:**
  ```bash
  # En servers/S13/guacamole/task_catalog.sh — ficha_post_install():
  # Insertar la conexión VNC al pod fedora-kde:
  FEDORA_IP=$(kubectl get svc fedora-kde -n sbos-vdi -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
  if [[ -n "$FEDORA_IP" ]]; then
      kubectl exec -n sbos-data deployment/postgresql -- psql -U postgres -d guacamole_db -c "
        INSERT INTO guacamole_connection (connection_name, protocol, max_connections)
        VALUES ('Escritorio SBOS', 'vnc', 10)
        ON CONFLICT DO NOTHING;
        INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
        SELECT connection_id, 'hostname', '${FEDORA_IP}' FROM guacamole_connection WHERE connection_name='Escritorio SBOS' ON CONFLICT DO NOTHING;
        INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
        SELECT connection_id, 'port', '5901' FROM guacamole_connection WHERE connection_name='Escritorio SBOS' ON CONFLICT DO NOTHING;
      " 2>/dev/null || true
  fi
  ```
- **Verificación:** Login en `/guacamole/` → lista "Escritorio SBOS" → conectar → desktop visible.

---

**PROBLEMA B-4 — GAP-2: health.check_command ausente en fichas críticas**

- **Síntoma:** BOS no puede detectar proactivamente si postgresql, redis, vault, keycloak, kong, minio están respondiendo correctamente (solo detecta si el pod está Running/CrashLoop via k8s_discovery).
- **Causa:** Las fichas no tienen `health.check_command` definido en sus `manifest.yml`. Solo tienen `health.type: k8s_pod`.
- **Impacto:** BOS puede reportar una ficha como INSTALLED aunque el servicio esté respondiendo errores — solo detecta el crash a nivel de pod, no a nivel de protocolo.
- **Solución — agregar a cada manifest:**
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

**PROBLEMA C-3 — SBOS-database-init: falta ficha de inicialización de BD**

- **Decisión HITL:** El DDL (`DDLs/SBOS_db_V2_DDL.sql`) tiene 158 tablas. ¿Se despliega todo en un solo paso o por módulo (bos-schema, bauth-schema, etc.)?
  - Opción A (recomendada): Una sola ficha `sbos-database-init` que ejecuta el DDL completo. Simple, mantenible.
  - Opción B: Una ficha por daemon (`bos-schema`, `bauth-schema`, etc.). Más granular pero más complejo.

---

### BLOQUE D — Seguridad urgente

---

**PROBLEMA D-1 — VDI-GAP-5: puerto 6901 expuesto sin auth (URGENTE)**

- **Ver VDI-PROBLEMA #5 arriba.** Es el único problema de seguridad activo que requiere acción inmediata, independientemente del estado de vault.
- **Tiempo estimado:** 30 minutos.
- **Acción:**
  ```bash
  # En VPS:
  ufw deny 6901/tcp
  ufw status | grep 6901
  # Verificar que el acceso desde fuera falla:
  # curl http://IP-VPS:6901 → debe fallar
  ```

---

## Resumen de estado por ficha

| Orden | Ficha | Estado | Bloqueo principal |
|-------|-------|--------|-------------------|
| 1 | bos-preflight | ✅ INSTALLED | — |
| 5 | sbos-namespace | ✅ INSTALLED | — |
| 10 | sbos-bootstrap-os | ✅ INSTALLED | — |
| 20 | sbos-bootstrap-k8s | ✅ INSTALLED | ⚠️ BUG-36 hairpin NAT |
| 25 | sbos-bootstrap-cni | ✅ INSTALLED | — |
| 28 | sbos-bootstrap-platform | ⚙️ PENDING (no en state) | ❌ BUG-31 |
| 30 | sbos-bootstrap-storage | ✅ INSTALLED | — |
| 35 | sbos-bootstrap-monitoring | ✅ INSTALLED | — |
| 50 | sbos-k8s-network-validator | ⚙️ PENDING (no en state) | ❌ BUG-31 |
| 70 | sbos-bkernel | ✅ INSTALLED | — |
| ~105 | sbos-database-init | ⚠️ FICHA FALTANTE | ❌ No existe — BD creada manualmente |
| 100 | postgresql | ✅ INSTALLED | ⚠️ BUG-35 dep circular |
| 100 | kyverno | ⚙️ PENDING (CrashLoop) | ❌ BUG-36 hairpin NAT |
| 110 | redis | ✅ INSTALLED | ⚠️ BUG-35 dep circular |
| 110 | linkerd | 🔄 INSTALLING | ⚠️ BUG-29 RS huérfanos |
| 120 | minio | ✅ INSTALLED | — |
| 130 | vault | ❌ PHYSICAL_ERROR | ❌ FIX-26A pendiente VPS |
| 135 | besu-qbft | ✅ INSTALLED | — |
| 140 | keycloak | ✅ INSTALLED | — |
| 150 | oauth2-proxy | ❌ PHYSICAL_ERROR | ❌ derivado vault |
| 160 | kong | ✅ INSTALLED | — |
| 170 | nginx | ⏸️ UPDATE_AVAILABLE | — |
| 170 | sbos-notifier | ✅ INSTALLED | — |
| 170 | tryton (S01) | 💥 INSTALL_FAILED | ❌ derivado vault |
| 170 | tryton (S04) | ⏳ NO_INSTALADA | ❌ INC-1 duplicado |
| 172 | mattermost (S10) | ⏳ NO_INSTALADA | ❌ INC-5 duplicado |
| 174 | ferretdb | ⚙️ PENDING | derivado vault |
| 175 | tryton-workers | ⏳ NO_INSTALADA | dep en tryton |
| 175 | calcom | ⏳ NO_INSTALADA | — |
| 176 | novu | ⚙️ PENDING | derivado vault |
| 177 | mattermost (S06) | ⚙️ PENDING | derivado vault / INC-5 |
| 180 | certbot | ✅ INSTALLED | — |
| 200 | prometheus | ✅ INSTALLED | — |
| 200 | nextcloud | ✅ INSTALLED | — |
| 205 | alertmanager | ✅ INSTALLED | — |
| 210 | guacamole | ✅ INSTALLED | ❌ GAP-4 sin conexiones |
| 215 | grafana | ✅ INSTALLED | — |
| 215 | loki | ⏳ NO_INSTALADA (STUB) | — |
| 220 | alloy | ✅ INSTALLED | ⚠️ Loki no disponible |
| 220 | tempo | ⏳ NO_INSTALADA (STUB) | — |
| 220 | onlyoffice | ✅ INSTALLED | — |
| 225 | zabbix | ⏳ NO_INSTALADA (STUB) | — |
| 225 | oauth2-proxy-desktop | ❌ PHYSICAL_ERROR | ❌ derivado vault |
| 230 | fedora-kde | ⏸️ UPDATE_AVAILABLE | ⚠️ INC-2/3, VDI-GAP-1/2/5 |
| 250 | sbos-bootstrap-hard | ✅ INSTALLED | ⚠️ kyverno no en enforce |
| 300–315 | mailserver stack | ⏳ NO_INSTALADA (STUB) | — |
| 345–365 | docs stack | ⏳ NO_INSTALADA (STUB) | — |
| 400–405 | búsqueda/mensajería | ⏳ NO_INSTALADA (STUB) | — |
| 420 | sbos-vdi-config | ⏳ NO_INSTALADA | VDI incompleto |
| 450–460 | devops stack | ⏳ NO_INSTALADA (STUB) | — |
| 500–525 | IA stack | ⏳ NO_INSTALADA (STUB) | — |

---

**Fichas INSTALLED:** 24 · **PHYSICAL_ERROR:** 3 · **INSTALL_FAILED:** 1 · **INSTALLING:** 1 · **UPDATE_AVAILABLE:** 2 · **PENDING/NO_INSTALADA:** 34 · **FALTANTE (a crear):** 2 (`sbos-database-init`, `sbos-kong-tenant`)

---

*Documento v2.0.0 — bos-developer · 2026-10-13*  
*Panel de control de reparación: `PLAN-INSTALACION-DESDE-CERO.md §13`*
