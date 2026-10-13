# Cronograma de Instalación — Ficha por Ficha

**Versión:** 1.0.0  
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

**Faltantes:**
- ❌ health.check_command ausente (GAP-2)
- ❌ SPIs SKULL sin implementar (pendiente desarrollo bAuth)

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

**Propósito:** Reverse proxy y servidor web del host S02. Enruta `/api/` → kong, `/desktop/` → oauth2-proxy-desktop. Sirve `/.well-known/acme-challenge/` para Certbot. Punto de entrada HTTP/HTTPS para usuarios finales.

**Dependencias:** kong

**Logros:**
- ✅ nginx instalado y sirviendo
- ✅ Rutas `/desktop/` y `/api/` configuradas
- ✅ Webroot para Certbot configurado

**Faltantes:**
- ⏸️ UPDATE_AVAILABLE — versión nueva disponible pero no actualizada aún

**Bugs:** ninguno activo

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

**Propósito:** Escritorio virtual corporativo. Pod que ejecuta KDE Plasma sobre TigerVNC. Accesible desde el navegador via noVNC HTML5 → Guacamole. Cada usuario corporativo accede a su escritorio Fedora con sus aplicaciones SBOS preconfiguradas (Tryton, Nextcloud, etc.).

**Dependencias:** keycloak, kong, guacamole

**🔶 Huevo y gallina — ARQUITECTURA INCOMPLETA:**
- **Problema crítico (VDI-GAP-1):** `replicas: 1` — todo el sistema comparte UN SOLO escritorio. Si dos usuarios se conectan al mismo tiempo, ven lo mismo.
- **Solución necesaria:** Provisioner dinámico que cree 1 pod por sesión de usuario autenticado.
- **Problema crítico (VDI-GAP-2):** Sin PVC por usuario — el home del usuario desaparece cuando el pod se reinicia.
- **INC-3:** ConfigMap `fedora-kde-start-script` sobreescribe el `start-desktop.sh` baked en la imagen — viola P-VDI-1 (imagen como fuente de verdad).
- **INC-2:** manifest dice `version: "41.0.0"` pero la imagen es `sbos/fedora-desktop:1.0.0` → BOS calcula UPDATE_AVAILABLE incorrecto.

**Logros:**
- ✅ Imagen `sbos/fedora-desktop:1.0.0` con KDE Plasma 6 + openbox como WM X11
- ✅ noVNC HTML5 funcional (novnc-index.html baked en imagen)
- ✅ KWallet deshabilitado (no bloquea arranque del escritorio)
- ✅ sbos-webapp con `--password-store=basic`
- ✅ SSO vía oauth2-proxy-desktop → Keycloak verificado end-to-end

**Faltantes:**
- ❌ VDI-GAP-1: sin provisioning dinámico — 1 pod compartido (depende Q-3 HITL)
- ❌ VDI-GAP-2: sin PVC por usuario (home temporal — se pierde en reboot)
- ❌ VDI-GAP-5: puerto noVNC 6901 expuesto externamente sin autenticación (bypass de Guacamole)
- ❌ INC-2: versión manifest incompatible con tag imagen (1 línea de fix)
- ❌ INC-3: ConfigMap sobreescribe start-desktop.sh de imagen (eliminar ConfigMap)
- ❌ auto_install no definido en manifest (GAP-6)

**Bugs activos:**
- ⚠️ INC-2: UPDATE_AVAILABLE falso (versiones incomparables)
- ⚠️ INC-3: P-VDI-1 violado (imagen no es fuente de verdad del script)
- ❌ VDI-GAP-5: acceso directo por puerto 6901 sin pasar por bAuth/Guacamole

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

> Módulo de correo electrónico soberano. Requiere dominio público con MX configurado.
> Todas con auto_install: false — instalar cuando el tenant lo requiera.

---

### [300] mailserver · S10 · ⏳ NO_INSTALADA
### [305] postfixadmin · S10 · ⏳ NO_INSTALADA
### [310] roundcube · S10 · ⏳ NO_INSTALADA
### [315] cypht · S10 · ⏳ NO_INSTALADA

**Propósito:** Stack completo de correo soberano: `mailserver` (Postfix + Dovecot + SpamAssassin), `postfixadmin` (UI de administración), `roundcube` (cliente webmail), `cypht` (webmail alternativo modular).

**Estado:** No instaladas. Requieren configuración de DNS MX + dominio público.

**Logros:** ninguno (todas son STUBs de 135 líneas)

**Faltantes:** Completar fichas a nivel ROBUSTO + configurar DNS + instalar por tenant

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

**Fichas INSTALLED:** 24 · **PHYSICAL_ERROR:** 3 · **INSTALL_FAILED:** 1 · **INSTALLING:** 1 · **UPDATE_AVAILABLE:** 2 · **PENDING/NO_INSTALADA:** 34

---

*Documento v1.0.0 — bos-developer · 2026-10-13*  
*Panel de control de reparación: `PLAN-INSTALACION-DESDE-CERO.md §13`*
