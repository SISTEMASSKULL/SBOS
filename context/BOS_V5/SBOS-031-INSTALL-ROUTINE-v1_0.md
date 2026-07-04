# SBOS-031-INSTALL-ROUTINE
## Rutina Profesional de Instalación del SBOS IAM Installer

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

**Código:** SBOS-031
**Estado:** NUEVO
**Clasificación:** Especificación de Instalación — Secuencia Obligatoria
**Dependencias documentales:** SBOS-004 (K8s), SBOS-005 (Installer), SBOS-006 (Fichas), SBOS-016 (Servidores)

---

## 1. Principio Fundamental

Cada etapa de la instalación es una **ficha**. El daemon `bos` hace una sola cosa: lee fichas, resuelve dependencias, ejecuta en orden. No hay código especial para "bootstrap" ni para "fundación" — el mismo motor que instala PostgreSQL es el que instala Kubernetes. La diferencia es el `workload.type`: las fichas de host se ejecutan en bash directamente en Ubuntu, las fichas de aplicación se despliegan como contenedores en Kubernetes.

El instalador es **idempotente**: si una ficha ya está instalada y healthy, la salta. Si se ejecuta de nuevo, verifica y no hace nada. Toda ficha se puede instalar por CLI (`bosctl install <ficha>`) o por Core UI cuando éste exista.

---

## 2. La Secuencia Completa — Validada Técnicamente

### FICHA 01: sbos-bootstrap-os

| Campo | Valor |
|-------|-------|
| **order** | 0 |
| **tipo** | bash (host Ubuntu) |
| **depends_on** | ninguno |
| **tiempo estimado** | ~5 min |

**Qué hace:**
- Valida Ubuntu Server 24.04 LTS, CPU >= 2, RAM >= 4GB, Disco >= 40GB, red disponible
- Hardening Ubuntu: 25 parámetros sysctl, ulimits, SSH hardening, auditd, AppArmor, fail2ban
- Desactiva swap permanentemente (requisito obligatorio de Kubernetes)
- Carga módulos kernel: `overlay`, `br_netfilter` (requisitos de CRI-O y Kubernetes)
- Instala CRI-O (container runtime para K8s)
- Instala kubeadm + kubelet + kubectl (versiones fijadas y pinadas con `apt-mark hold`)

**Por qué es una ficha separada:** Kubernetes no puede inicializarse sin un container runtime funcional y sin los módulos kernel cargados. Si CRI-O falla, kubeadm init falla. Esta ficha garantiza que el SO está listo antes de tocar K8s.

**Validación técnica:** kubeadm requiere: swap desactivado, br_netfilter cargado, container runtime instalado y corriendo, kubelet instalado. Sin estos prerequisitos, `kubeadm init` falla en la fase de preflight checks.

---

### FICHA 02: sbos-bootstrap-k8s

| Campo | Valor |
|-------|-------|
| **order** | 1 |
| **tipo** | bash (host Ubuntu) |
| **depends_on** | sbos-bootstrap-os |
| **tiempo estimado** | ~8 min |

**Qué hace:**
- `kubeadm init` con configuración CIS hardened → crea API Server + etcd + controller-manager + scheduler
- Configura kubeconfig para el usuario `bosagent`
- Instala Calico CNI → red funcional entre pods
- Aplica GlobalNetworkPolicy default-deny (todo tráfico bloqueado por defecto)
- Instala MetalLB → LoadBalancer funcional en bare metal
- Instala metrics-server → necesario para `kubectl top` y HPA
- En modo nodo único: remueve taint NoSchedule del control plane

**Por qué es una ficha separada:** Después de `kubeadm init`, el nodo está en estado `NotReady` hasta que se instale un CNI (Calico). Sin CNI, CoreDNS no arranca y no hay resolución DNS en el cluster. Sin MetalLB, no hay LoadBalancer en bare metal.

**Validación técnica:** La documentación oficial de Kubernetes confirma que después de `kubeadm init`, el servidor DNS no será scheduled hasta que se instale un CNI plugin. El nodo permanece en NotReady hasta que la red esté operativa.

---

### FICHA 03: sbos-bootstrap-platform

| Campo | Valor |
|-------|-------|
| **order** | 2 |
| **tipo** | bash (kubectl contra el cluster) |
| **depends_on** | sbos-bootstrap-k8s |
| **tiempo estimado** | ~5 min |

**Qué hace:**
- Crea los 14 namespaces `sbos-*` con labels y anotaciones (incluyendo `linkerd.io/inject: enabled`)
- Configura RBAC: ServiceAccounts `installer-sa`, `patroni-sa`
- Aplica ResourceQuotas por namespace
- Aplica LimitRanges por namespace
- Aplica Pod Security Standards por namespace
- Activa encriptación etcd (AES-256-CBC para secrets y configmaps en reposo)
- Configura audit logging del API server
- **Instala StorageClass con local-path-provisioner como default**
- Configura cron de renovación de certificados TLS cada 90 días

**Por qué es una ficha separada:** Sin namespaces, no hay dónde desplegar pods. Sin StorageClass, los PersistentVolumeClaims de PostgreSQL quedan en Pending y el StatefulSet nunca arranca. Sin RBAC, los ServiceAccounts no tienen permisos para operar.

**Validación técnica:** En clusters bare metal estándar de Kubernetes, el StorageClass con provisioner dinámico frecuentemente no está configurado por defecto. Sin él, cualquier PVC de un StatefulSet queda en estado Pending y el pod nunca arranca. El local-path-provisioner de Rancher es la solución estándar para bare metal.

---

### FICHA 04: sbos-k8s-network-validator

| Campo | Valor |
|-------|-------|
| **order** | 3 |
| **tipo** | kubernetes (pod efímero de diagnóstico) |
| **depends_on** | sbos-bootstrap-platform |
| **tiempo estimado** | ~1 min |

**Qué hace:**
- Despliega un pod efímero que certifica:
  - CNI funcional (Calico operativo)
  - DNS interno funcional (resolución de `kubernetes.default.svc.cluster.local`)
  - Conectividad inter-pod (ping entre namespaces permitidos)
  - StorageClass default presente y funcional (crea un PVC temporal, verifica Bound, elimina)
  - MetalLB respondiendo
- Si cualquier check falla → ABORT con CAUSA + SOLUCIÓN
- Si todos pasan → estado INSTALADA_OK, se elimina a sí mismo

**Por qué es una ficha separada:** Esto es lo que en Docker Compose hacía tu `network-validator`. En K8s, valida que la plataforma está lista para recibir StatefulSets con PVCs. Sin esta validación, el primer StatefulSet (PostgreSQL) podría fallar silenciosamente.

---

### FICHA 05: postgresql

| Campo | Valor |
|-------|-------|
| **order** | 100 |
| **tipo** | kubernetes (StatefulSet) |
| **depends_on** | sbos-k8s-network-validator |
| **namespace** | sbos-data |
| **tiempo estimado** | ~3 min |

**Qué hace:**
- Aplica NetworkPolicy `postgresql.network` (abre puerto 5432 solo a namespaces autorizados)
- Despliega StatefulSet PostgreSQL 18 + Service + PVC (usa el StorageClass default)
- Configura Patroni para HA
- Crea las bases de datos iniciales del stack (keycloak_db, kong_db, grafana_db, etc.)
- Espera: `pg_isready -U postgres` = OK

**Validación técnica:** PostgreSQL se despliega como StatefulSet porque necesita identidad estable y almacenamiento persistente vinculado al pod. El PVC usa el StorageClass configurado en la ficha anterior. Sin PostgreSQL, Vault, Keycloak, Kong y Grafana no pueden arrancar.

---

### FICHA 06: redis

| Campo | Valor |
|-------|-------|
| **order** | 110 |
| **tipo** | kubernetes (StatefulSet) |
| **depends_on** | sbos-k8s-network-validator |
| **namespace** | sbos-data |
| **tiempo estimado** | ~1 min |

**Qué hace:**
- Aplica NetworkPolicy
- Despliega StatefulSet Redis + Service + PVC
- Espera: `redis-cli ping` = PONG

---

### FICHA 07: minio

| Campo | Valor |
|-------|-------|
| **order** | 115 |
| **tipo** | kubernetes (StatefulSet) |
| **depends_on** | sbos-k8s-network-validator |
| **namespace** | sbos-data |
| **tiempo estimado** | ~2 min |

**Qué hace:**
- Aplica NetworkPolicy
- Despliega StatefulSet MinIO + Service + PVC
- Configura buckets iniciales para backups
- Espera: health check OK

---

### FICHA 08: vault

| Campo | Valor |
|-------|-------|
| **order** | 120 |
| **tipo** | kubernetes (StatefulSet) |
| **depends_on** | postgresql |
| **namespace** | sbos-identity |
| **tiempo estimado** | ~3 min |

**Qué hace:**
- Aplica NetworkPolicy
- Despliega StatefulSet Vault + Service + PVC
- Inicializa Vault (`vault operator init`) → genera unseal keys + root token
- Unseal Vault (`vault operator unseal`)
- Configura backend de storage PostgreSQL
- Habilita secrets engine PKI para certificados internos
- Almacena el root token en `.sbos_state.json` (encriptado)
- Espera: `vault status` = initialized + unsealed

**Por qué depende de PostgreSQL:** Vault usa PostgreSQL como backend de storage para persistir sus datos de forma duradera.

---

### FICHA 09: keycloak

| Campo | Valor |
|-------|-------|
| **order** | 130 |
| **tipo** | kubernetes (StatefulSet) |
| **depends_on** | postgresql, vault |
| **namespace** | sbos-identity |
| **tiempo estimado** | ~4 min |

**Qué hace:**
- Aplica NetworkPolicy
- Obtiene credenciales de la BD desde Vault
- Despliega StatefulSet Keycloak + Service
- Configura conexión a `keycloak_db` en PostgreSQL
- Crea realm `master` con admin inicial
- Configura realm `skbos` con los flows de autenticación base
- Espera: health check OK + realm accesible

**Validación técnica:** La documentación oficial de Keycloak establece que la base de datos debe estar disponible y accesible antes del despliegue. Keycloak no gestiona su propia base de datos — es responsabilidad del instalador provisionarla previamente.

---

### FICHA 10: nginx

| Campo | Valor |
|-------|-------|
| **order** | 140 |
| **tipo** | kubernetes (Deployment) |
| **depends_on** | sbos-bootstrap-platform |
| **namespace** | sbos-gateway |
| **tiempo estimado** | ~2 min |

**Qué hace:**
- Aplica NetworkPolicy
- Despliega NGINX como reverse proxy + SSL termination
- Configura certificados TLS (auto-firmados inicialmente, renovables vía Vault PKI)
- Espera: health check OK

---

### FICHA 11: kong

| Campo | Valor |
|-------|-------|
| **order** | 145 |
| **tipo** | kubernetes (Deployment) |
| **depends_on** | postgresql, keycloak |
| **namespace** | sbos-gateway |
| **tiempo estimado** | ~3 min |

**Qué hace:**
- Aplica NetworkPolicy
- Despliega Kong API Gateway + Service
- Configura conexión a `kong_db` en PostgreSQL
- Configura plugins OAuth2 contra Keycloak
- Registra rutas base del API Gateway
- Espera: health check OK

**Por qué depende de Keycloak:** Kong necesita Keycloak para validar tokens OAuth2 en las rutas protegidas.

---

### FICHA 12: linkerd

| Campo | Valor |
|-------|-------|
| **order** | 150 |
| **tipo** | kubernetes (Deployment) |
| **depends_on** | sbos-bootstrap-platform |
| **namespace** | sbos-identity (control plane) |
| **tiempo estimado** | ~3 min |

**Qué hace:**
- Instala Linkerd control plane
- Los sidecars se inyectan automáticamente en namespaces con anotación `linkerd.io/inject: enabled`
- Activa mTLS automático entre todos los pods del cluster
- Espera: `linkerd check` = OK

---

### FICHA 13: kyverno

| Campo | Valor |
|-------|-------|
| **order** | 155 |
| **tipo** | kubernetes (Deployment) |
| **depends_on** | sbos-bootstrap-platform |
| **namespace** | kube-system |
| **tiempo estimado** | ~2 min |

**Qué hace:**
- Despliega Kyverno admission controller
- Aplica 4 políticas obligatorias: restrict-image-registries, require-labels, restrict-host-path, require-resource-limits
- Espera: health check OK

---

### FICHA 14: prometheus

| Campo | Valor |
|-------|-------|
| **order** | 200 |
| **tipo** | kubernetes (StatefulSet) |
| **depends_on** | sbos-bootstrap-platform |
| **namespace** | sbos-monitor |
| **tiempo estimado** | ~3 min |

**Qué hace:**
- Aplica NetworkPolicy (acceso al puerto 9090 de métricas desde todos los namespaces)
- Despliega Prometheus + Service + PVC
- Configura scrape targets para todos los servicios instalados
- Espera: health check OK

---

### FICHA 15: grafana

| Campo | Valor |
|-------|-------|
| **order** | 210 |
| **tipo** | kubernetes (Deployment) |
| **depends_on** | postgresql, prometheus |
| **namespace** | sbos-monitor |
| **tiempo estimado** | ~2 min |

**Qué hace:**
- Aplica NetworkPolicy
- Despliega Grafana + Service
- Configura conexión a `grafana_db` en PostgreSQL
- Configura Prometheus como datasource
- Importa dashboards base del cluster
- Espera: health check OK

---

### FICHA 16: sbos-bootstrap-hardening

| Campo | Valor |
|-------|-------|
| **order** | 300 |
| **tipo** | bash (verificación desde el host) |
| **depends_on** | keycloak, kong, prometheus, linkerd |
| **tiempo estimado** | ~2 min |

**Qué hace:**
- Ejecuta `kube-bench` → verifica todos los controles CIS Level 1 = PASS
- Verifica NetworkPolicies activas en cada namespace
- Verifica mTLS Linkerd operativo entre pods
- Verifica que cert renewal cron está configurado
- Verifica que todos los servicios base responden a health checks
- Si todo pasa → marca el sistema como **SISTEMA BASE COMPLETO**

---

## 3. Grafo DAG Completo

```
sbos-bootstrap-os (0, bash)
  └──▶ sbos-bootstrap-k8s (1, bash)
         └──▶ sbos-bootstrap-platform (2, bash)
                │
                ├──▶ sbos-k8s-network-validator (3, k8s)
                │      │
                │      ├──▶ postgresql (100, k8s)
                │      │      ├──▶ vault (120, k8s)
                │      │      │      └──▶ keycloak (130, k8s)
                │      │      │              └──▶ kong (145, k8s)
                │      │      ├──▶ grafana (210, k8s)
                │      │      └──▶ kong (145, k8s)
                │      │
                │      ├──▶ redis (110, k8s)
                │      └──▶ minio (115, k8s)
                │
                ├──▶ nginx (140, k8s)
                ├──▶ linkerd (150, k8s)
                ├──▶ kyverno (155, k8s)
                └──▶ prometheus (200, k8s)
                                    │
                                    └──▶ grafana (210, k8s)

Todo converge en:
  sbos-bootstrap-hardening (300, bash)
    depends_on: keycloak, kong, prometheus, linkerd
    
═══════════════════════════════════════════
  SISTEMA BASE COMPLETO
  Administrado por: bosctl
  16 fichas ejecutadas
  ~48 minutos desde Ubuntu limpio
═══════════════════════════════════════════
```

---

## 4. Timeline Estimada

| Tiempo | Ficha | Qué ocurre |
|--------|-------|------------|
| T+0:00 | — | `curl -sSL https://get.skbos.io/installer \| sudo bash` |
| T+0:02 | — | daemon `bos` instalado como systemd, arranca |
| T+0:02 | sbos-bootstrap-os | Hardening Ubuntu + CRI-O + kubeadm stack |
| T+0:07 | sbos-bootstrap-k8s | kubeadm init + Calico + MetalLB + metrics-server |
| T+0:15 | sbos-bootstrap-platform | Namespaces + RBAC + StorageClass + etcd encryption |
| T+0:20 | sbos-k8s-network-validator | Certifica CNI + DNS + StorageClass funcional |
| T+0:21 | postgresql | StatefulSet + Patroni + BDs iniciales |
| T+0:24 | redis | StatefulSet + health check |
| T+0:25 | minio | StatefulSet + buckets iniciales |
| T+0:27 | vault | StatefulSet + init + unseal + PKI engine |
| T+0:30 | keycloak | StatefulSet + realm master + realm skbos |
| T+0:34 | nginx | Reverse proxy + SSL |
| T+0:37 | kong | API Gateway + OAuth2 plugins |
| T+0:40 | linkerd | mTLS control plane + sidecars |
| T+0:42 | kyverno | Admission controller + 4 políticas |
| T+0:44 | prometheus | Scraping todos los servicios |
| T+0:46 | grafana | Dashboards + datasource Prometheus |
| T+0:48 | sbos-bootstrap-hardening | CIS benchmark + verificación final |
| **T+0:48** | **COMPLETO** | **Sistema base operativo — `bosctl status` muestra 16 fichas OK** |

---

## 5. Qué Ve el Técnico

```bash
$ curl -sSL https://get.skbos.io/installer | sudo bash

[bos] SBOS IAM Installer v1.0.0 instalado
[bos] Iniciando rutina de instalación...

[bos] ━━━ FICHA 01/16: sbos-bootstrap-os ━━━
[✓] Ubuntu 24.04 LTS verificado
[✓] Hardening: 25 sysctl aplicados
[✓] Swap desactivado
[✓] Módulos kernel: overlay, br_netfilter
[✓] CRI-O v1.34 instalado y activo
[✓] kubeadm v1.32 + kubelet + kubectl instalados
[✓] sbos-bootstrap-os: INSTALADA_OK (5m 12s)

[bos] ━━━ FICHA 02/16: sbos-bootstrap-k8s ━━━
[✓] kubeadm init completado
[✓] Calico CNI instalado — GlobalNetworkPolicy deny-all activa
[✓] MetalLB configurado
[✓] metrics-server instalado
[✓] sbos-bootstrap-k8s: INSTALADA_OK (7m 45s)

[bos] ━━━ FICHA 03/16: sbos-bootstrap-platform ━━━
[✓] 14 namespaces sbos-* creados
[✓] RBAC configurado
[✓] ResourceQuotas + LimitRanges aplicados
[✓] StorageClass local-path-provisioner (default)
[✓] Encriptación etcd AES-256 activa
[✓] sbos-bootstrap-platform: INSTALADA_OK (4m 30s)

[bos] ━━━ FICHA 04/16: sbos-k8s-network-validator ━━━
[✓] CNI Calico: OK
[✓] DNS interno: OK
[✓] StorageClass: PVC test Bound OK
[✓] MetalLB: OK
[✓] sbos-k8s-network-validator: INSTALADA_OK (45s)

[bos] ━━━ FICHA 05/16: postgresql ━━━
[✓] NetworkPolicy aplicada
[✓] StatefulSet postgresql desplegado en sbos-data
[✓] PVC Bound (50GB local-path)
[✓] pg_isready: OK
[✓] BDs creadas: keycloak_db, kong_db, grafana_db, bkernel_db, bcompass_db
[✓] postgresql: INSTALADA_OK (3m 20s)

[bos] ━━━ FICHA 06/16: redis ━━━
[✓] redis-cli ping: PONG
[✓] redis: INSTALADA_OK (55s)

[bos] ━━━ FICHA 07/16: minio ━━━
[✓] Buckets: backups, uploads, archives
[✓] minio: INSTALADA_OK (1m 40s)

[bos] ━━━ FICHA 08/16: vault ━━━
[✓] vault operator init: 5 unseal keys generadas
[✓] vault operator unseal: OK
[✓] Backend PostgreSQL configurado
[✓] PKI engine habilitado
[✓] vault: INSTALADA_OK (2m 50s)

[bos] ━━━ FICHA 09/16: keycloak ━━━
[✓] Conectado a keycloak_db vía Vault credentials
[✓] Realm master creado
[✓] Realm skbos configurado
[✓] keycloak: INSTALADA_OK (3m 55s)

[bos] ━━━ FICHA 10/16: nginx ━━━
[✓] Reverse proxy + SSL auto-firmado
[✓] nginx: INSTALADA_OK (1m 30s)

[bos] ━━━ FICHA 11/16: kong ━━━
[✓] Conectado a kong_db
[✓] Plugins OAuth2 configurados contra Keycloak
[✓] kong: INSTALADA_OK (2m 45s)

[bos] ━━━ FICHA 12/16: linkerd ━━━
[✓] Control plane instalado
[✓] mTLS activo en namespaces sbos-*
[✓] linkerd check: OK
[✓] linkerd: INSTALADA_OK (2m 30s)

[bos] ━━━ FICHA 13/16: kyverno ━━━
[✓] 4 políticas obligatorias activas
[✓] kyverno: INSTALADA_OK (1m 50s)

[bos] ━━━ FICHA 14/16: prometheus ━━━
[✓] Scraping 12 targets
[✓] prometheus: INSTALADA_OK (2m 15s)

[bos] ━━━ FICHA 15/16: grafana ━━━
[✓] Datasource Prometheus configurado
[✓] 3 dashboards importados
[✓] grafana: INSTALADA_OK (1m 40s)

[bos] ━━━ FICHA 16/16: sbos-bootstrap-hardening ━━━
[✓] kube-bench CIS Level 1: 42/42 PASS
[✓] NetworkPolicies: 14/14 namespaces protegidos
[✓] mTLS Linkerd: activo
[✓] Cert renewal cron: configurado
[✓] sbos-bootstrap-hardening: INSTALADA_OK (1m 45s)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ SISTEMA BASE COMPLETO
  16/16 fichas instaladas
  Tiempo total: 47m 32s

  Para ver el estado:    bosctl status
  Para ver las fichas:   bosctl fichas
  Para ver los logs:     bosctl logs --follow
  Para instalar más:     bosctl install <ficha>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 6. Después del Sistema Base — Aplicaciones de Negocio

Una vez que el sistema base está operativo, las fichas de negocio se instalan por CLI:

```bash
bosctl install tryton            # ERP
bosctl install mailserver        # Correo
bosctl install postfixadmin      # Admin de correo
bosctl install roundcube         # Webmail
bosctl install nextcloud         # Archivos
bosctl install wazuh             # SIEM
# ... etc
```

Cada una de estas fichas tiene su `depends_on` que el daemon resuelve automáticamente. Si `roundcube` depende de `postgresql` y `keycloak`, y ambos ya están en `INSTALADA_OK`, la ficha se desbloquea y se instala directamente.

Cuando el Core UI se construya, será una ficha más:

```bash
bosctl install core-ui           # Cuando esté desarrollado
```

Y a partir de ese momento, el admin podrá usar tanto CLI como Core UI indistintamente.

---

## 7. Relación con Productos y Deploy

Esta rutina de 16 fichas es el contenido del **producto `bootstrap`** definido en SBOS-032-PRODUCTS. Es el único producto con `auto_install: true` — el daemon lo ejecuta automáticamente al detectar un servidor sin K8s.

Cuando se usa un seed file de deploy (SBOS-033-DEPLOY), el daemon ejecuta primero esta rutina y luego continúa con los productos adicionales que el técnico haya especificado (mail, erp, etc.).

```
bosctl deploy cliente.deploy.yml
  │
  ├── Producto bootstrap (esta rutina — 16 fichas) ← SBOS-031
  ├── Producto mail (4 fichas + configuraciones)   ← SBOS-032
  ├── Producto erp (2 fichas + configuraciones)    ← SBOS-032
  └── ...
```

---

## 8. Impacto en el Proyecto

### Documentos actualizados

| Documento | Cambio | Estado |
|-----------|--------|--------|
| **SBOS-004** | Ficha Bootstrap dividida en 3 fichas (os, k8s, platform) + network-validator + hardening | ✅ Actualizado |
| **SBOS-005** | `bosctl install/product/deploy` en CLI + rutina de primera instalación en §16.1 | ✅ Actualizado |
| **SBOS-016** | Fases de instalación pendiente de actualizar | ❌ Pendiente |

### Fichas que deben crearse

| Ficha | Estado actual | Acción |
|-------|--------------|--------|
| sbos-bootstrap-os | No existe (parte del monolito sbos-bootstrap) | Crear como ficha Tipo 1 independiente |
| sbos-bootstrap-k8s | No existe (parte del monolito sbos-bootstrap) | Crear como ficha Tipo 1 independiente |
| sbos-bootstrap-platform | No existe (parte del monolito sbos-bootstrap) | Crear como ficha Tipo 1 independiente |
| sbos-k8s-network-validator | Mencionado en SBOS-016 sin ficha | Crear como ficha nueva |
| sbos-bootstrap-hardening | No existe | Crear como ficha Tipo 1 nueva |
| postgresql | Documentado en SBOS-006 | Ya existe — verificar depends_on |
| redis | Documentado en SBOS-003 | Verificar ficha completa |
| minio | Documentado en SBOS-003 | Verificar ficha completa |
| vault | Documentado en SBOS-003 | Verificar ficha completa |
| keycloak | Documentado en SBOS-003/008/019/020 | Verificar ficha completa |
| nginx | Documentado en SBOS-003 | Verificar ficha completa |
| kong | Documentado en SBOS-003 | Verificar ficha completa |
| linkerd | Documentado en SBOS-004 | Verificar ficha completa |
| kyverno | Documentado en SBOS-004 | Verificar ficha completa |
| prometheus | Documentado en SBOS-003 | Verificar ficha completa |
| grafana | Documentado en SBOS-003 | Verificar ficha completa |

---

*SKULL · SBOS · SBOS-031-INSTALL-ROUTINE · v1.0 · Marzo 2026*

> **Referencias técnicas que validan la secuencia:**
> - Kubernetes oficial: kubeadm init requiere CRI + swap off + kernel modules
> - Kubernetes oficial: DNS server no se schedule hasta instalar CNI
> - Kubernetes oficial: StorageClass con provisioner requerido para PVCs dinámicos en bare metal
> - Keycloak oficial: database debe estar accesible antes del deployment
> - HashiCorp Vault: requiere backend de storage operativo para init
> - Rancher local-path-provisioner: solución estándar para StorageClass en bare metal
> - ArgoCD sync-waves: patrón de la industria para ordenar dependencias en bootstrap
