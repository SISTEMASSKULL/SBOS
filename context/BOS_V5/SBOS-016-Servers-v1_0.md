# SBOS-016 — Mapa de Servidores Lógicos
## SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

**Código:** SBOS-016
**Versión:** 1.0
**Estado:** ACTIVO
**Reemplaza a:** SBOS-011-SERVERS v2.0 (SUPERSEDED)
**Clasificación:** Referencia de Arquitectura — Topología de Servidores

---

## Tabla de Contenidos

1. [Concepto: Carpeta = Servidor = Nodo](#1-concepto-carpeta--servidor--nodo)
2. [Los 15 Servidores](#2-los-15-servidores)
3. [Los Tres Daemons Soberanos del Host](#3-los-tres-daemons-soberanos-del-host)
4. [Fases de Instalación](#4-fases-de-instalación)
5. [Topología Completa](#5-topología-completa)

---

## 1. Concepto: Carpeta = Servidor = Nodo

Cada servidor lógico es una carpeta dentro de `servers/`. Contiene las fichas de las aplicaciones que le pertenecen. Cuando el negocio crece, la carpeta se replica como un nodo K8s independiente en un VPS separado.

```
Modo nodo único (1 VPS):              Modo horizontal (N VPS):

servers/                               VPS-1: dataserver (dedicado)
  ├── dataserver/                      VPS-2: gatewayserver (dedicado)
  ├── gatewayserver/                   VPS-3: identityserver (dedicado)
  ├── identityserver/                  VPS-4: erpserver (dedicado)
  └── ... (15 carpetas)                ... 15 VPS en total
```

El stack puede operar completamente en un solo nodo físico (modo nodo único) y escalar horizontalmente nodo por nodo sin cambios arquitectónicos.

---

## 2. Los 15 Servidores

### S-HOST · hostserver/ — Bootstrap y Sistema Base

Servidor del host. Contiene la ficha de sistema Bootstrap (SP-02) que prepara Ubuntu + Kubernetes. Es la raíz de todo el árbol de dependencias. También aloja fichas de mantenimiento del sistema base y la web institucional opcional (nginx-web).

**Fichas:** `sbos-bootstrap`, `sbos-nginx-web` (opcional).
**Criticidad:** MÁXIMA — sin este servidor, nada existe.

Nota: los ocho **Daemons Soberanos del Host** (bKernel, biedata, bCompass) también corren en el host Ubuntu, fuera de Kubernetes. Ver §3.

---

### S00 · hostserver/k8s-network-validator — Validación de Red K8s

Ficha de diagnóstico que certifica CNI, DNS interno y conectividad inter-pod. Prerequisito absoluto de todo el stack. Se ejecuta una vez tras el bootstrap.

---

### S01 · dataserver/ — Motor de Persistencia

Motor de persistencia unificado. Todo el stack lee y escribe aquí. PostgreSQL 18 como motor principal (90%+ del stack), Patroni para HA, Redis para caché/sesiones/colas, MinIO para object storage.

**13 aplicaciones. Criticidad: MÁXIMA.**

---

### S02 · gatewayserver/ — Seguridad Perimetral

Único punto de entrada externo. NGINX como reverse proxy, Certbot para SSL, ModSecurity WAF, Kong como API Gateway, HashiCorp Vault para secretos dinámicos.

**7 aplicaciones. Criticidad: MÁXIMA.**

---

### S03 · identityserver/ — Identidad y Seguridad

IdP central (Keycloak) + SIEM (Wazuh) + service mesh (Linkerd). Keycloak es el gobierno de identidad de todo el SBOS — el Principio 1 del stack.

**8 aplicaciones. Criticidad: MÁXIMA.**

---

### S04 · erpserver/ — Motor ERP

Tryton como fuente de verdad de negocio. Nodo exclusivo — critical path isolation. Contabilidad Bolivia PUCT/SIN, inventario, manufactura, ventas.

**5 aplicaciones. Criticidad: MÁXIMA.**

---

### S05 · devserver/ — Proyectos de Desarrollo Propio SKULL

7 aplicaciones propias: SmartTax (fiscal), SmartReport (BI), SmartRates (tarifas), SmartORC (correspondencia), SmartVaultFlow (documentos), SmartPortfolio (catálogos), SmartPay (pagos QR). Ciclos de deploy frecuentes, pipeline independiente.

**7 aplicaciones. Criticidad: ALTA.**

---

### S06 · appsserver/ — Apps Open Source

13 aplicaciones maduras: Saleor, Directus, OrangeHRM, Taiga, EspoCRM, Wiki.js, Zammad, etc. Software estable con ciclos de actualización predecibles.

**13 aplicaciones. Criticidad: ALTA.**

---

### S07 · reportserver/ — Reportes y BI

Generación de reportes fiscales Bolivia SIN (JasperSoft), dashboards BI (Superset), ETL (Airflow), catálogo de datos (OpenMetadata).

**7 aplicaciones. Criticidad: ALTA.**

---

### S08 · docserver/ — Gestión Documental

Ciclo completo: captura → OCR (Tesseract) → extracción (Tabula/Camelot) → flujo de aprobación (Kimios) → firma digital (DocuSeal) → archivo (Paperless-NGX).

**7 aplicaciones. Criticidad: ALTA.**

---

### S09 · searchserver/ — Búsqueda y Mensajería

Elasticsearch para indexación masiva y backend SIEM. RabbitMQ para mensajería async entre servicios.

**2 aplicaciones. Criticidad: ALTA.**

---

### S10 · commsserver/ — Comunicaciones

Stack completo: correo (Postfix + Dovecot), VoIP (FreePBX + Asterisk), mensajería (Rocket.Chat + Mattermost), antivirus (ClamAV).

**10 aplicaciones. Criticidad: ALTA.**

---

### S11 · vdiserver/ — Escritorio Virtual Soberano (SBOS VDI)

Fedora KDE Plasma + Nextcloud + OnlyOffice. Escritorio corporativo soberano personalizable por empresa. Control de privilegios via bAuth + banexus (ver SBOS-012, SBOS-036). Receptor de notificaciones del bCompass vía protocolo `sbos://`. Ver SBOS-012.

**5 aplicaciones. Criticidad: ALTA.**

---

### S12 · monitorserver/ — Observabilidad

Nodo dedicado que NUNCA compite por recursos con lo que monitorea. Prometheus + Grafana + Loki + Tempo + Zabbix + Alertmanager.

**10 aplicaciones. Criticidad: MÁXIMA.**

---

### S13 · geoserver/ — Presencia Física

GPS (Traccar), logística (Fleetbase), señalética digital (Xibo), colas de atención (Novo SGA), tarjetas digitales (CardMesh).

**5 aplicaciones. Criticidad: MEDIA.**

---

### S14 · opsserver/ — CI/CD y Backup

GitLab para código y CI/CD, Bareos + Velero + pgBackRest para backup y DR. Se configura AL FINAL porque necesita que todo el stack exista para hacer backup.

**7 aplicaciones. Criticidad: ALTA.**

---

### S15 · aiserver/ — Inteligencia Artificial Soberana *(Opcional)*

Motor de inferencia LLM + memoria semántica vectorial + observabilidad de modelos. Provee capacidades de IA soberana que bCompass y bSearch consumen como herramienta. Completamente opcional — el stack entero funciona sin él.

Fichas: Ollama, Open WebUI, Qdrant, Embedding Worker, Langfuse, Flowise, bCompass (ver SBOS-015 para especificación completa).

**6 fichas + bCompass. Criticidad: NINGUNA — `criticality: false` en todas las fichas.**

---

## 3. Los Tres Daemons Soberanos del Host

Los daemons soberanos de SBOS son procesos que corren **directamente en el host Ubuntu**, fuera del cluster Kubernetes. Esta decisión arquitectónica es intencional: necesitan acceso directo al WAL de PostgreSQL (bKernel) y a las conexiones de bajo nivel del sistema, lo que no es posible con las restricciones de red de Kubernetes.

Los tres daemons soberanos son **bKernel**, **biedata**, y **bCompass**.

```
HOST UBUNTU
├── /etc/systemd/system/
│   ├── bkernel.service    ← Daemon soberano 1
│   ├── biedata.service   ← Daemon soberano 2
│   └── bcompass.service   ← Daemon soberano 3
│
├── /usr/local/bin/
│   ├── bkernel            ← Binario del motor bKernel
│   ├── biedata           ← Binario del motor biedata
│   └── bcompass           ← Binario del motor bCompass
│
├── /etc/bkernel/          ← Configuración y reglas del bKernel
├── /etc/biedata/         ← Configuración y cajas del biedata
└── /etc/bcompass/         ← Configuración y rutas del bCompass
```

### bKernel — Motor de Datos Soberano

| Atributo | Valor |
|---|---|
| **Nombre systemd** | `bkernel.service` |
| **Binario** | `/usr/local/bin/bkernel` |
| **Path configuración** | `/etc/bkernel/bkernel.toml` |
| **Path reglas** | `/etc/bkernel/rules/` |
| **Usuario** | `bkernel` (permisos PostgreSQL replication) |
| **Señal hot-reload** | `SIGUSR1` → recarga reglas YAML sin reiniciar |
| **Puerto** | Sin puerto (no expone APIs externas) |
| **Dependencias systemd** | `postgresql.service`, `redis.service` |

**Justificación de diseño:** el bKernel escucha el Write-Ahead Log (WAL) de PostgreSQL en tiempo real para detectar cambios en las BDs del stack. Este acceso requiere el rol de replicación de PostgreSQL y una conexión de baja latencia al socket Unix del servidor. Correr el bKernel dentro de un Pod de Kubernetes agregaría una capa de red adicional que introduce latencia variable inaceptable para la sincronización en tiempo real. El bKernel en el host accede al WAL con latencia < 100ms consistente.

Ver SBOS-010 para especificación técnica completa.

---

### biedata — Motor de Integración Soberano

| Atributo | Valor |
|---|---|
| **Nombre systemd** | `biedata.service` |
| **Binario** | `/usr/local/bin/biedata` |
| **Path configuración** | `/etc/biedata/biedata.toml` |
| **Path cajas** | `/etc/biedata/boxes/` |
| **Usuario** | `biedata` (permisos PostgreSQL SELECT en biedata_db + acceso Redis) |
| **Señal hot-reload** | `SIGUSR1` → recarga cajas sin reiniciar |
| **Puerto** | Sin puerto (no expone APIs externas) |
| **Dependencias systemd** | `postgresql.service`, `redis.service` |

**Justificación de diseño:** biedata gestiona integraciones con sistemas externos (APIs REST, SFTP, archivos, webhooks). Necesita acceso a la red del host para alcanzar endpoints externos que pueden estar en la misma LAN del cliente o en la internet. Las reglas de NetworkPolicy de Kubernetes añaden complejidad operativa significativa para este patrón de acceso. biedata en el host tiene acceso directo a la red sin NAT ni restricciones de CNI, simplificando la gestión de integraciones y el debugging.

Ver SBOS-011 para especificación técnica completa.

---

### bCompass — Motor de Inteligencia Soberano

| Atributo | Valor |
|---|---|
| **Nombre systemd** | `bcompass.service` |
| **Binario** | `/usr/local/bin/bcompass` |
| **Path configuración** | `/etc/bcompass/bcompass.toml` |
| **Path rutas** | `/etc/bcompass/router/` |
| **Usuario** | `bcompass-readonly` (PostgreSQL SELECT en todas las BDs del stack; escritura solo en bcompass_db) |
| **Señal hot-reload** | `SIGUSR1` → recarga rutas sin reiniciar |
| **Señal trigger manual** | `SIGUSR2` + payload JSON → ejecuta ruta específica desde Core UI |
| **Puerto** | Sin puerto (no expone APIs externas — comunica vía Redis) |
| **Dependencias systemd** | `postgresql.service`, `redis.service`, `ollama.service` (soft — degraded mode si no está) |

**Justificación de diseño:** bCompass necesita acceso de solo lectura a todas las BDs del stack para las rutas `analyst` y `agent`. Correr bCompass en el host le permite usar el socket Unix de PostgreSQL para lecturas de alta frecuencia sin overhead de red. Además, el protocolo de notificación bCompass → SBOS VDI (SBOS-014 §19) usa `SIGUSR2` para triggers manuales desde el Core UI — una señal POSIX que es trivial en el host pero requiere plumbing adicional desde un Pod. El aiserver (Ollama) puede estar en Kubernetes; bCompass alcanza el servicio `ollama:11434` vía ClusterIP normalmente.

Ver SBOS-014 para especificación técnica completa.

---

### Resumen de los Tres Daemons

```
$ systemctl status bkernel biedata bcompass

● bkernel.service - bKernel Sovereign Data Engine (SBOS)
   Active: active (running)
   /usr/local/bin/bkernel --config /etc/bkernel/bkernel.toml

● biedata.service - biedata Sovereign Integration Engine (SBOS)
   Active: active (running)
   /usr/local/bin/biedata --config /etc/biedata/biedata.toml

● bcompass.service - bCompass Sovereign Business Intelligence Engine (SBOS)
   Active: active (running)
   /usr/local/bin/bcompass --config /etc/bcompass/bcompass.toml
```

Los tres daemons comparten el mismo meta-patrón de diseño:

| Característica | bKernel | biedata | bCompass |
|---|---|---|---|
| Tipo de motor | Binario | Binario | Binario |
| Unidad de conocimiento | Regla YAML | Caja (.so) | Ruta (.so) |
| Directorio conocimiento | `/etc/bkernel/rules/` | `/etc/biedata/boxes/` | `/etc/bcompass/router/` |
| Hot-reload | SIGUSR1 | SIGUSR1 | SIGUSR1 |
| Escribe en BDs stack | Sí (bKernel) | Sí (controlado) | No (solo lectura) |
| BD propia | `bkernel_db` | `biedata_db` | `bcompass_db` |
| Expone API externa | No | No | No |

---

## 4. Fases de Instalación

> **Actualizado en v2.0.** Las fases ahora reflejan las fichas reales de la rutina de instalación (SBOS-031) y los productos (SBOS-032). El orden lo resuelve el daemon `bos` automáticamente mediante el grafo DAG de dependencias — no es una lista manual.

El orden NO es una recomendación — es obligatorio por dependencias técnicas. El `DEPENDENCY_RESOLVER` lo calcula automáticamente.

### Producto: bootstrap (automático — 16 fichas)

| Ficha | Order | Tipo | Servidor | Descripción |
|-------|:-----:|------|----------|-------------|
| sbos-bootstrap-os | 0 | bash | hostserver | Ubuntu hardening, CRI-O, kubeadm stack |
| sbos-bootstrap-k8s | 1 | bash | hostserver | kubeadm init, Calico CNI, MetalLB |
| sbos-bootstrap-platform | 2 | bash | hostserver | Namespaces, RBAC, StorageClass, etcd encryption |
| sbos-k8s-network-validator | 3 | k8s | hostserver | Certifica CNI, DNS, StorageClass |
| postgresql | 100 | k8s | dataserver | StatefulSet + Patroni + BDs iniciales |
| redis | 110 | k8s | dataserver | StatefulSet + caché/sesiones |
| minio | 115 | k8s | dataserver | Object storage + buckets |
| vault | 120 | k8s | identityserver | Secretos dinámicos + PKI |
| keycloak | 130 | k8s | identityserver | IdP central + OAuth2 |
| nginx | 140 | k8s | gatewayserver | Reverse proxy + SSL |
| kong | 145 | k8s | gatewayserver | API Gateway + plugins |
| linkerd | 150 | k8s | identityserver | mTLS entre pods |
| kyverno | 155 | k8s | hostserver | Admission policies |
| prometheus | 200 | k8s | monitorserver | Monitoreo |
| grafana | 210 | k8s | monitorserver | Dashboards |
| sbos-bootstrap-hardening | 300 | bash | hostserver | Verificación CIS final |

### Productos adicionales (instalados por CLI o deploy)

| Producto | Fichas nuevas | Servidores | Descripción |
|----------|:-------------:|------------|-------------|
| **mail** | 4 | commsserver | Correo corporativo: mailserver, postfixadmin, roundcube, cypht |
| **erp** | 2 | erpserver | ERP y contabilidad: tryton, tryton-workers |
| **documents** | 5 | docserver | Gestión documental: paperless-ngx, tesseract, tabula, kimios, docuseal |
| **monitoring** | 4 | monitorserver | Observabilidad extendida: loki, tempo, alertmanager, zabbix |
| **vdi** | 4 | vdiserver | Escritorio virtual: nextcloud, onlyoffice, sbos-vdi-config, fedora-kde-sbos |
| **devops** | 3 | opsserver | CI/CD y backup: gitlab, bareos, velero |
| **ai** *(opcional)* | 6 | aiserver | IA soberana: ollama, qdrant, open-webui, embedding-worker, langfuse, flowise |

Cada producto amplía automáticamente las fichas de infraestructura existentes (PostgreSQL, Keycloak, Kong) con las configuraciones que necesita. Ver SBOS-032-PRODUCTS para manifiestos completos.

**Nota sobre el aiserver:** completamente opcional. Puede instalarse en cualquier momento después del bootstrap (requiere PostgreSQL). `criticality: false` en todas sus fichas.

---

## 5. Topología Completa

```
SBOS — 15 Servidores Lógicos

HOST UBUNTU (físico / VPS raíz)
│
├── [DAEMONS SOBERANOS — fuera de K8s, en el host]
│   ├── bkernel.service    → bkernel_db (PostgreSQL)
│   ├── biedata.service   → biedata_db (PostgreSQL)
│   └── bcompass.service   → bcompass_db (PostgreSQL)
│
└── KUBERNETES CLUSTER
    │
    ├── S-HOST: hostserver/     [BOOTSTRAP — raíz del árbol]
    │
    ├── S01: dataserver/        [MÁXIMA criticidad]
    │   PostgreSQL · Patroni · Redis · MinIO
    │   ← Todo el stack depende de S01
    │
    ├── S02: gatewayserver/     [MÁXIMA criticidad]
    │   NGINX · Kong · Vault · ModSecurity
    │   ← Único punto de entrada externo
    │
    ├── S03: identityserver/    [MÁXIMA criticidad]
    │   Keycloak · Wazuh · Linkerd
    │   ← Principio 1: Gobernanza por Keycloak
    │
    ├── S04: erpserver/         [MÁXIMA criticidad]
    │   Tryton · Bolivia PUCT/SIN
    │   ← Fuente de verdad de negocio
    │
    ├── S05: devserver/         [ALTA criticidad]
    │   SmartTax · SmartReport · SmartRates · SmartORC
    │   SmartVaultFlow · SmartPortfolio · SmartPay
    │
    ├── S06: appsserver/        [ALTA criticidad]
    │   OrangeHRM · EspoCRM · Zammad · Taiga · Wiki.js · Saleor · Directus
    │
    ├── S07: reportserver/      [ALTA criticidad]
    │   JasperSoft · Superset · Airflow · OpenMetadata
    │
    ├── S08: docserver/         [ALTA criticidad]
    │   Paperless-NGX · Kimios · DocuSeal · Tesseract
    │
    ├── S09: searchserver/      [ALTA criticidad]
    │   Elasticsearch · RabbitMQ
    │
    ├── S10: commsserver/       [ALTA criticidad]
    │   Postfix · Dovecot · FreePBX · Rocket.Chat · Mattermost
    │
    ├── S11: vdiserver/         [ALTA criticidad]
    │   Fedora KDE Plasma · Nextcloud · OnlyOffice
    │   ← Escritorio Soberano SBOS VDI (SBOS-012)
    │   ← Control via bAuth + banexus (SBOS-036)
    │
    ├── S12: monitorserver/     [MÁXIMA criticidad]
    │   Prometheus · Grafana · Loki · Tempo · Zabbix
    │   ← Nodo dedicado — nunca comparte recursos
    │
    ├── S13: geoserver/         [MEDIA criticidad]
    │   Traccar · Fleetbase · Xibo · Novo SGA
    │
    ├── S14: opsserver/         [ALTA criticidad]
    │   GitLab · Bareos · Velero · pgBackRest
    │   ← Instalado AL FINAL
    │
    └── S15: aiserver/          [NINGUNA criticidad — OPCIONAL]
        Ollama · Qdrant · Open WebUI · Embedding Worker · Langfuse · Flowise
        ← Puede instalarse en cualquier momento post Fase 3
        ← Toda ficha: criticality: false
```

---

*SKULL · SBOS · SBOS-016-SERVERS · v1.0 · Marzo 2026*
*Reemplaza: SBOS-011-SERVERS v2.0 — SUPERSEDED*
