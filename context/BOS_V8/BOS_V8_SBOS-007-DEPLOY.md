# SBOS-007-DEPLOY
## Topologia de Despliegue — Estandar HUMAN-DOC (Enriquecido V8)
### SKULL · SBOS v1.1-V8 · Mayo 2026

---

## 1. Arquitectura Fisica

| Componente | Ubicacion | SO |
|---|---|---|
| Servidor del cliente | Hardware propio / VPS dedicado | Ubuntu Server 26.04 LTS |
| Daemons soberanos | systemd en host (fuera de K8s) | Ubuntu nativo |
| Aplicaciones del stack | Pods Kubernetes | Contenedores OCI |
| Endpoints corporativos | USB booteable / red | Fedora KDE Plasma (SBOS VDI) |

---

## 2. Componentes por Ubicacion

| Componente | Ubicacion | Razon |
|---|---|---|
| IAM Installer Core | systemd host | Guardian del SO — no puede depender de K8s |
| bKernel | systemd host | Acceso directo WAL via socket Unix (<50us) |
| biedata | systemd host | Escritura coordinada con antiloop WAL |
| bCompass | systemd host | Ciclo de vida independiente de K8s |
| bSearch | systemd host | Acceso WAL para indexacion |
| bAuth | systemd host | Acceso WAL para identidad |
| bhnexus | systemd host | Broker de hardware |
| Core UI (Flutter) | Pod K8s sbos-installer | Interfaz web accesible por navegador |
| Todas las apps | Pods K8s en sus namespaces | Gestionadas por fichas |
| Vault | Pod K8s sbos-security | Tras bootstrap, fuente de verdad de secrets |

---

## 3. Namespaces Kubernetes (14)

| Namespace | Servidor logico | Pod Security Standard |
|---|---|---|
| sbos-installer | IAM Installer UI | restricted |
| sbos-data | dataserver | restricted |
| sbos-identity | identityserver | restricted |
| sbos-security | securityserver | restricted |
| sbos-gateway | gatewayserver | baseline |
| sbos-comms | commsserver | baseline |
| sbos-erp | erpserver | baseline |
| sbos-apps | appsserver | baseline |
| sbos-docs | docserver | baseline |
| sbos-monitor | monitorserver | baseline |
| sbos-geo | geoserver | baseline |
| sbos-vdi | vdiserver | baseline |
| sbos-search | searchserver | baseline |
| sbos-ops | opsserver | baseline |

ResourceQuotas + LimitRanges obligatorios en cada namespace. PriorityClasses: system-node-critical (kube-system), system-cluster-critical (sbos-data), high-priority (sbos-identity), normal-priority (resto).

---

## 4. Topologia de Nodos

### Nodo unico (cliente que empieza)

```
+----------------------------------------------+
|  VPS UNICO (Ubuntu 26.04)                     |
|                                               |
|  systemd: bos, bkernel, biedata, bcompass...  |
|                                               |
|  +---------------------------------------+   |
|  |  K8s CLUSTER (nodo unico)             |   |
|  |  Control Plane + Worker (mismo host)  |   |
|  |  14 namespaces, 110+ apps posibles    |   |
|  +---------------------------------------+   |
+----------------------------------------------+
```

Requisitos minimos: 2 vCPU, 4GB RAM, 40GB SSD. Recomendado: 4+ vCPU, 8+ GB RAM, 100+ GB SSD.

### Multi-nodo (crecimiento)

```
Control Plane (x3 HA)  <->  dataserver node  <->  identityserver node  <-> ...
     etcd Raft x3           PG + Redis + MinIO      Keycloak + Vault
                            bKernel + biedata
                            (daemons en host PG)
```

Crecimiento horizontal: 3 parametros (agregar nodo, etiquetar con tipo=servidor-logico, scheduling automatico por nodeSelector).

---

## 5. Orden de Arranque (Bootstrap)

```
T+00:00  Ubuntu Server 26.04 LTS mínimo
        Prerrequisitos: kubeadm, kubectl, containerd (como PHP para Laravel)
        git clone https://github.com/SISTEMASSKULL/bos-install.git && cd bos-install
        sudo ./bin/bosctl setup --mode=prod --seed ./seed-skull.yml

T+00:02  system-install automático: binarios, core, blibs, servicios, preflight
T+00:07  daemon iniciado, socket /run/bos/bos.sock activo
T+00:15  [0/7] sbos-bootstrap-k8s (kubeadm init, Calico offline, StorageClass local-path)
T+00:20  [1/7] sbos-namespace (tenant namespace + NetworkPolicy)
T+00:21  [1.5] sbos-bootstrap-storage (PVs hostPath)
T+00:24  [2/7] postgresql (StatefulSet 18.4)
T+00:25  [3/7] redis (8.6.2)
T+00:27  [4/7] vault (2.0.1, init + unseal + PKI)
T+00:30  [5/7] keycloak (26.6.2, realm master + sbos)
T+00:34  [6/7] DDL Context Plane
T+00:36  [7/7] kong (API Gateway + plugins)
        ====== SISTEMA BASE COMPLETO ======

T+00:48  Administrador instala apps desde Core UI
```

Tiempo total bootstrap: ~48 minutos. **Un solo comando.** Sin intervención manual.
**Sin dependencia de internet** (manifiestos y recursos offline en el repo).

**Decisión de arquitectura:** ADR-044 — Repositorio de Instalación Autocontenido.
El repo `bos-install` contiene binarios precompilados, core scripts, 22 fichas
declarativas, y manifiestos CNI. kubeadm/kubectl/containerd son prerrequisitos
del SO (como PHP para Laravel), no parte del producto.

---

## 6. Red Zero Trust

- GlobalNetworkPolicy default-deny (Calico) desde T+00:15
- Cada ficha incluye su NetworkPolicy en pre_install
- mTLS automatico entre pods (Linkerd service mesh)
- TLS 1.3 en todas las comunicaciones externas
- Kyverno: 4 politicas admission obligatorias

---

## 7. Ambientes

| Ambiente | Proposito | Diferencias |
|---|---|---|
| Desarrollo | VPS staging de SKULL | Nodo unico, datos de prueba |
| Staging | Pre-produccion del cliente | Configuracion identica a prod, datos sanitizados |
| Produccion | Servidor del cliente | Patroni HA, backups activos, monitoreo completo |

---

## 8. Hardening CIS

La Ficha Bootstrap aplica hardening de Kubernetes CIS Benchmark Level 1:
- 25 sysctl del kernel
- SSH hardening
- auditd + AppArmor
- Swap desactivado
- etcd encriptado AES-256
- Audit logging del API server
- kube-bench verificacion semanal (sbos-compliance-check)

---

## 9. Vault Bootstrap Problem

Los secrets para instalar Vault se almacenan como K8s Secrets encriptados en etcd durante bootstrap. Una vez Vault en INSTALADA — OK, el IAM Installer migra esos K8s Secrets a Vault en post_install. Vault se convierte en fuente de verdad de todos los secrets del stack.

---

## 10. Actualizacion de Kubernetes

Ficha sbos-k8s-upgrader gestiona upgrades: `kubeadm upgrade plan` → `kubeadm upgrade apply` en rolling sin downtime. Verifica CIS Benchmark post-upgrade. Solo se activa cuando hay version nueva declarada en manifest.

---

## 11. Servicios por Namespace

Mapa de pods principales que corren en cada namespace, con los daemons soberanos del host relacionados.

| Namespace | Pods principales | Daemons soberanos host relacionados |
|---|---|---|
| sbos-installer | core-ui (Flutter web) | bos (IAM Installer) — gestiona via API |
| sbos-data | postgresql (Patroni), redis, minio, pgbouncer | bkernel, biedata (acceso WAL via socket Unix) |
| sbos-identity | keycloak (x2 replicas), oauth2-proxy, wazuh-manager, linkerd-control-plane | bauth (sync KC via Admin API) |
| sbos-security | vault | bos (lee secrets en bootstrap) |
| sbos-gateway | kong, nginx, certbot, modsecurity | — |
| sbos-erp | tryton, tryton-workers, rabbitmq | bcompass (slot WAL bcompass_slot) |
| sbos-apps | orangehrm, saleor, espocrm, zammad, wiki-js, taiga, calcom | bkernel (slots bkernel_slot) |
| sbos-comms | postfix, dovecot, roundcube, mattermost, centrifugo, rocket-chat | — |
| sbos-docs | paperless-ngx, tesseract, docuseal, kimios | — |
| sbos-monitor | prometheus, grafana, alertmanager, loki, tempo, grafana-alloy, zabbix | — |
| sbos-geo | traccar, fleetbase, xibo, novosga | — |
| sbos-vdi | nextcloud, onlyoffice | bhnexus (broker hardware), banexus (cliente Fedora) |
| sbos-search | elasticsearch (Wazuh logs) | bsearch (acceso WAL para indexacion) |
| sbos-ops | gitlab, k6, trivy, bareos, velero, pgbackrest | — |
| sbos-ai | ollama, qdrant, open-webui, embedding-worker, langfuse, flowise | bcompass (invoca Ollama via HTTP) |

**Nota sobre aiserver:** El namespace sbos-ai no esta en la lista de 14 namespaces base porque el producto `ai` es opcional (criticality: false). Se crea cuando el admin instala el producto AI desde Core UI.

---

## 12. V7 Enriquecimiento — Topologia del Par Nexus Soberano (NEXUS-CONCEPTUALIZACION)

El V7 define una topologia de despliegue especifica para el Par Nexus Soberano que complementa la topologia general:

```
+-------------------------------+       +----------------------------------+
|  HOST UBUNTU (systemd)        |       |  CLIENTE FEDORA (systemd --user)  |
|                               |       |                                  |
|  bhnexus.service              |<------|> banexus.service                  |
|  - Puerto :9444 (WSS)         |  mTLS |  - Puerto :9445 (WSS salida)     |
|  - Certificado CA server      |       |  - Certificado cliente firmado   |
|  - Listener WebSocket         |       |  - Interceptor USB/shell         |
|  - Relay de chapas/cajones    |       |  - Evaluador local PhysicalMask  |
|  - Auditoria acceso fisico    |       |  - Cache de BitMask local        |
+-------------------------------+       +----------------------------------+
```

### Protocolo monogamico

Un bhnexus se conecta exactamente con un banexus. La conexion es mTLS persistente con certificados intercambiados en bootstrap.

### Latencia objetivo
- Auth fisica (chapa/cajon): <15ms
- Auth VDI (inicio sesion): <50ms
- Auth compuesta (fisica + logica): <100ms

### Despliegue del Par Nexus
- bhnexus se despliega como parte del daemon host (ficha Tipo 1)
- banexus se despliega como parte de la imagen SBOS VDI (ficha Tipo 1)
- Certificados se intercambian durante el bootstrap del VDI
- La conexion se establece automaticamente al iniciar sesion en el VDI

---

## 13. ENRIQUECIMIENTO SBOS (Primera Version)

### SBOS-016-13-1: Topologia de Servidores Logicos (desde SBOS-016-Servers-v1_0.md)

Cada servidor logico es una carpeta dentro de `servers/`. Contiene las fichas de las aplicaciones que le pertenecen. Cuando el negocio crece, la carpeta se replica como un nodo K8s independiente en un VPS separado.

```
Modo nodo unico (1 VPS):              Modo horizontal (N VPS):
servers/                               VPS-1: dataserver (dedicado)
  +-- dataserver/                      VPS-2: gatewayserver (dedicado)
  +-- gatewayserver/                   VPS-3: identityserver (dedicado)
  +-- identityserver/                  ... 15 VPS en total
  +-- ... (15 carpetas)
```

### SBOS-016-13-2: Detalle Completo de los 15 Servidores (desde SBOS-016-Servers-v1_0.md)

| ID | Servidor | Criticidad | Aplicaciones clave |
|----|----------|:----------:|--------------------|
| S-HOST | hostserver/ | MAXIMA | sbos-bootstrap, sbos-nginx-web (opcional). Daemons: bKernel, biedata, bCompass |
| S00 | hostserver/k8s-network-validator | — | Validacion CNI, DNS interno, conectividad inter-pod |
| S01 | dataserver/ | MAXIMA | PostgreSQL + Patroni, Redis, MinIO (13 aplicaciones) |
| S02 | gatewayserver/ | MAXIMA | NGINX, Certbot, ModSecurity, Kong, Vault (7 apps) |
| S03 | identityserver/ | MAXIMA | Keycloak, Wazuh, Linkerd (8 apps) |
| S04 | erpserver/ | MAXIMA | Tryton ERP, contabilidad Bolivia PUCT/SIN (5 apps) |
| S05 | devserver/ | ALTA | Laravel, Vue.js, Django SIAT Bolivia, Celery (6 apps) |
| S06 | appsserver/ | ALTA | Saleor, Directus, OrangeHRM, Taiga, EspoCRM, Wiki.js, Zammad (13 apps) |
| S07 | reportserver/ | ALTA | JasperSoft, Superset, Airflow, OpenMetadata (7 apps) |
| S08 | docserver/ | ALTA | Paperless-NGX, Tesseract, Kimios, DocuSeal (7 apps) |
| S09 | searchserver/ | ALTA | Elasticsearch, RabbitMQ (2 apps) |
| S10 | commsserver/ | ALTA | Postfix, Dovecot, FreePBX, Rocket.Chat, Mattermost, ClamAV (10 apps) |
| S11 | vdiserver/ | ALTA | KDE Plasma, Kasm, Nextcloud, OnlyOffice, sbos-vdi-config (5 apps) |
| S12 | monitorserver/ | MAXIMA | Prometheus, Grafana, Loki, Tempo, Zabbix, Alertmanager (10 apps) |
| S13 | geoserver/ | MEDIA | Traccar, Fleetbase, Xibo, Novo SGA, CardMesh (5 apps) |
| S14 | opsserver/ | ALTA | GitLab, Bareos, Velero, pgBackRest (7 apps) |
| S15 | aiserver/ | NINGUNA | Ollama, Qdrant, Open WebUI, Embedding Worker, Langfuse, Flowise (6 apps, opcional) |

### SBOS-016-13-3: Los Tres Daemons Soberanos del Host — Especificacion (desde SBOS-016-Servers-v1_0.md)

Los daemons soberanos corren directamente en el host Ubuntu, fuera del cluster Kubernetes. Necesitan acceso directo al WAL de PostgreSQL (bKernel) y a conexiones de bajo nivel del sistema.

| Atributo | bKernel | biedata | bCompass |
|----------|---------|---------|----------|
| **Servicio** | `bkernel.service` | `biedata.service` | `bcompass.service` |
| **Binario** | `/usr/local/bin/bkernel` | `/usr/local/bin/biedata` | `/usr/local/bin/bcompass` |
| **Config** | `/etc/bkernel/bkernel.toml` | `/etc/biedata/biedata.toml` | `/etc/bcompass/bcompass.toml` |
| **Conocimiento** | `/etc/bkernel/rules/` | `/etc/biedata/boxes/` | `/etc/bcompass/router/` |
| **Usuario** | `bkernel` (PG replication) | `biedata` (PG SELECT + Redis) | `bcompass-readonly` (PG SELECT) |
| **Hot-reload** | SIGUSR1 -> reglas YAML | SIGUSR1 -> cajas | SIGUSR1 -> rutas |
| **Puerto** | Sin puerto externo | Sin puerto externo | Sin puerto externo |
| **BD propia** | `bkernel_db` | `biedata_db` | `bcompass_db` |
| **Escribe en BDs stack** | Si (bKernel) | Si (controlado) | No (solo lectura) |
| **Dependencias** | postgresql, redis | postgresql, redis | postgresql, redis, ollama (soft) |
| **Trigger manual** | — | — | SIGUSR2 + payload JSON |

**Justificacion bKernel en host:** escucha el WAL de PostgreSQL en tiempo real. Requiere rol de replicacion y conexion de baja latencia al socket Unix. Correr en K8s agregaria latencia variable inaceptable para sincronizacion en tiempo real (< 100ms consistente).

**Justificacion biedata en host:** gestiona integraciones con sistemas externos (APIs REST, SFTP, webhooks). Necesita acceso a la red del host para alcanzar endpoints externos sin las restricciones de NetworkPolicy de K8s.

**Justificacion bCompass en host:** necesita acceso de solo lectura a todas las BDs del stack via socket Unix. El protocolo de notificacion bCompass -> SBOS VDI usa SIGUSR2 para triggers manuales desde Core UI -- una senal POSIX trivial en el host.

### SBOS-016-13-4: Productos Adicionales del Stack (desde SBOS-016-Servers-v1_0.md)

| Producto | Fichas nuevas | Servidores | Descripcion |
|----------|:-------------:|------------|-------------|
| **mail** | 4 | commsserver | Correo corporativo: mailserver, postfixadmin, roundcube, cypht |
| **erp** | 2 | erpserver | ERP y contabilidad: tryton, tryton-workers |
| **documents** | 5 | docserver | Gestion documental: paperless-ngx, tesseract, tabula, kimios, docuseal |
| **monitoring** | 4 | monitorserver | Observabilidad extendida: loki, tempo, alertmanager, zabbix |
| **vdi** | 4 | vdiserver | Escritorio virtual: kasm, nextcloud, onlyoffice, sbos-vdi-config |
| **devops** | 3 | opsserver | CI/CD y backup: gitlab, bareos, velero |
| **ai** (opcional) | 6 | aiserver | IA soberana: ollama, qdrant, open-webui, embedding-worker, langfuse, flowise |

Cada producto amplia automaticamente las fichas de infraestructura existentes (PostgreSQL, Keycloak, Kong) con las configuraciones que necesita. El aiserver es completamente opcional y puede instalarse en cualquier momento post-bootstrap.

### SBOS-018-13-5: Feature Flags para fichas de aplicacion (desde SBOS-018-DEPLOY-FeatureFlags-v1_0.md)

El `manifest.yml` de una ficha puede incluir el campo `feature_flag` para controlar la visibilidad de la ficha por tenant:

```yaml
name: sp-nueva-app
version: "0.1.0"
feature_flag:
  enabled: true
  keycloak_realm_attribute: "feature_sp_nueva_app"
  stage: experimental   # experimental | beta | ga
```

**Ciclo de vida del feature flag:**

| Etapa | Quien ve la ficha | Mecanismo |
|-------|-------------------|-----------|
| **EXPERIMENTAL** | Solo equipo SKULL | Atributo habilitado solo en realm SKULL |
| **BETA** | Clientes que opten voluntariamente | Admin activa toggle en Core UI: Configuracion > Features |
| **GA** | Todos los tenants | Campo `feature_flag` se elimina del manifest.yml |

**Logica de evaluacion en FICHA_PROBE.py:** si la ficha tiene `feature_flag.enabled=true`, el IAM Installer consulta el atributo del realm en Keycloak. Si el atributo no existe o no es "true", la ficha no se despliega.

### SBOS-018-13-6: Blue/Green para daemons soberanos (desde SBOS-018-DEPLOY-FeatureFlags-v1_0.md)

Para bKernel, biedata y bCompass (binarios systemd, no fichas K8s), el proceso de actualizacion usa un patron blue/green con validacion previa:

1. **Verificacion de firma Ed25519:** el Release Plane distribuye binarios firmados. Se verifica con `openssl pkeyutl -verify` antes de continuar.

2. **Dry-run en paralelo:** el nuevo binario se lanza con `--dry-run` en puerto de metricas diferente (ej. 9101 para bKernel). Procesa el WAL pero no escribe destinos.

3. **Criterios de swap** (evaluados tras 5 min de dry-run en canary, 6h en early, 5 min en stable):
   - Lag WAL del nuevo daemon < 500ms
   - Cero errores en logs del nuevo daemon

4. **Swap atomico (< 30 segundos de interrupcion):**
   ```bash
   sudo systemctl stop bkernel
   cp /opt/bos/bkernel.new /usr/local/bin/bkernel
   sudo systemctl start bkernel
   ```

5. **Rollback inmediato:** si el nuevo daemon falla post-swap, se restaura el binario previo:
   ```bash
   sudo systemctl stop bkernel
   cp /opt/bos/bkernel.prev /usr/local/bin/bkernel
   sudo systemctl start bkernel
   ```

### SBOS-018-13-7: Estrategia de despliegue por canal del Release Plane (desde SBOS-018-DEPLOY-FeatureFlags-v1_0.md)

| Canal | Fichas | Daemons soberanos |
|-------|--------|-------------------|
| **canary** | Feature flags EXPERIMENTAL activos | Blue/green con dry-run de 24h |
| **early** | Feature flags BETA activos + 2 semanas en canary sin incidentes | Blue/green con dry-run de 6h |
| **stable** | Sin feature flags (solo GA) + 4 semanas en early | Blue/green con dry-run de 5 min |

**Graduacion entre canales:** canary -> early (2 semanas sin alertas `bKernelDown` ni errores WAL), early -> stable (4 semanas adicionales sin incidentes).

### SBOS-018-13-8: Runbook RK-014 — Actualizacion Blue/Green de Daemon Soberano (desde SBOS-018-DEPLOY-FeatureFlags-v1_0.md)

**Responsable:** DevOps Lead | **Tiempo estimado:** 30 min (5 min dry-run + 25 min swap + verificacion)

```
[ ] Descargar y verificar firma Ed25519 del nuevo binario
[ ] Lanzar en modo --dry-run (5 min canary/stable, 6h early)
[ ] Verificar criterios: lag WAL < 500ms + 0 errores
[ ] OK -> swap atomico (< 30 segundos)
[ ] FAIL -> abortar, investigar antes de reintentar
[ ] Post-swap: verificar lag WAL en Grafana < 500ms
[ ] Si post-swap falla: rollback con binario previo en < 1 minuto
```

---

## Trazabilidad

| Seccion | Extraida de | Secciones originales |
|---|---|---|
| §1-2 Arquitectura | SBOS-004 v4.0 | §2 Daemons, §8 Donde Vive |
| §3 Namespaces | SBOS-004 v4.0 | §9 Namespaces y Gobernanza |
| §4 Topologia | SBOS-004 v4.0 | §7 Nodo Unico/Multi-Nodo |
| §5 Bootstrap | SBOS-004 v4.0, SBOS-031 v1.0 | §6 Secuencia Completa |
| §6 Red | SBOS-004 v4.0 | §10 Zero Trust, §11 mTLS |
| §7 Ambientes | SBOS-029 v1.0 | §entornos |
| §8 Hardening | SBOS-004 v4.0 | §13 CIS |
| §9 Vault | SBOS-004 v4.0 | §8 Vault bootstrap |
| §10 Updates | SBOS-004 v4.0 | §17 Politica de Actualizacion |
| §11 Servicios | SBOS-005-STACK v1.0 §3 + SBOS-030-BOUNDED-CONTEXTS v1.0 | Tabla por servidor logico + BCs + daemons relacionados |
| §12 V7 | BOS_V7_SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md | Topologia Par Nexus, protocolo monogamico, latencias objetivo, despliegue |
| §13 SBOS-016-13-1 a SBOS-016-13-4 | SBOS-016-Servers-v1_0.md | Topologia de 15 servidores logicos, detalle de daemons soberanos (bKernel/biedata/bCompass), tabla de productos adicionales |
| §13 SBOS-018-13-5 a SBOS-018-13-8 | SBOS-018-DEPLOY-FeatureFlags-v1_0.md | Feature flags para fichas (EXPERIMENTAL/BETA/GA), blue/green para daemons soberanos (Ed25519, dry-run, swap atomico, rollback), estrategia por canal, Runbook RK-014 |

---

## Fuentas de Enriquecimiento V8

| Fuente | Tipo | Contenido aportado |
|---|---|---|
| BOS_V6_SBOS-007-DEPLOY.md | V6 (canonico) | Contenido base completo preservado |
| BOS_V7_SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md | V7 | Topologia Par Nexus, protocolo monogamico, latencias, despliegue |
| SBOS-016-Servers-v1_0.md | SBOS (V8) | Topologia de 15 servidores logicos (S-HOST a S15) con criticidad y apps, los 3 daemons soberanos del host con especificacion systemd completa, productos adicionales del stack |
| SBOS-018-DEPLOY-FeatureFlags-v1_0.md | SBOS (V8) | Feature flags para fichas (EXPERIMENTAL/BETA/GA lifecycle), blue/green deployment para daemons soberanos con dry-run y swap atomico, estrategia por canal Release Plane, Runbook RK-014 |

---

_SKULL · SBOS · SBOS-007-DEPLOY · HUMAN-DOC v1.1-V8 · Mayo 2026_
_Enriquecimiento V8: V7 topologia del Par Nexus Soberano, protocolo monogamico mTLS, latencias objetivo; SBOS topologia de servidores y daemons soberanos_
