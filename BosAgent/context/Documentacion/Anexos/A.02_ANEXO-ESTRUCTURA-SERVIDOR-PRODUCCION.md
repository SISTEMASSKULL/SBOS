# Anexo A.02 — Estructura del Servidor de Producción SBOS
## Layout del filesystem, organización de carpetas, y directrices que el BOS impone al preparar el terreno

**Versión:** 1.0.0
**Fecha:** 2026-07-17
**Autor:** bos-developer — SBOS
**Referencia:** [0.00 — Directrices BOS Control Plane](../0.00_MANUAL-DIRECTRICES-BOS-CONTROL-PLANE.md) · [1.01 — Bootstrap y Stack Alpha](../1.01_MANUAL-BOOTSTRAP-STACK-ALPHA.md)
**Aplica a:** servidor de producción (`/opt/skull/SBOS/`) — actualmente llamado "servidor de pruebas" (VPS 13.140.128.230)

---

## 1. Propósito

Este anexo define la **estructura canónica del servidor de producción SBOS**. Es el plano que el
BOS materializa durante `bosctl system-install` y mantiene durante toda la vida del sistema.

**El BOS es el arquitecto del filesystem de producción.** Antes de que cualquier daemon o
aplicación exista, el BOS ya creó los directorios, asignó los puertos, definió la organización
de backups, y dejó el terreno listo para que las fichas se instalen.

---

## 2. Principios de organización

### 2.1 Qué VA en producción

Solo lo necesario para **operar**. Nada de desarrollo.

| Va a producción | NO va a producción |
|-----------------|-------------------|
| `servers/` — catálogo de fichas (fuente única) | `BosAgent/src/` — código fuente Go |
| `DDLs/` — esquemas y seeds de base de datos | `BauthAgent/context/` — documentación de desarrollo |
| `config/` — configuración de producción | `OrquestaCoreSBOS/` — fábrica |
| `backups/` — respaldos | `CompositorSBOS/` — fábrica |
| `context/` — solo manuales de usuario y sistema | `_archivo/` — histórico de desarrollo |
| `scripts/` — scripts operativos | `.github/` — CI/CD |
| `paths.yml` — rutas canónicas | `CLAUDE.md` — instrucciones de agente |
| `staging/` — credenciales y seeds de producción | Cualquier `_legacy/`, `_snapshots/`, `*.bak` |
| `/etc/bos/` — configuración del daemon | `/opt/skull/orquestador/` — fábrica |
| `/opt/bos/` — binarios y core del BOS | Código fuente de cualquier daemon |

### 2.2 Los daemons son fichas (como cualquier otra aplicación)

En producción, **cada daemon es una ficha** que el BOS instala exactamente igual que instala
PostgreSQL, Redis o cualquier aplicación. El BOS no distingue entre "daemon" y "aplicación":
todo es una ficha con `manifest.yml` + `task_catalog.sh` + `PROPOSITO.md`.

**División de responsabilidades:**
- **El daemon (BauthAgent, BkernelAgent...)** compila su binario y lo copia a su directorio de ficha en `servers/`
- **El BOS** descubre la ficha, resuelve sus dependencias, y la instala/verifica/repara como a cualquier otra

```
CICLO DE VIDA DE UN DAEMON COMO FICHA:

1. DESARROLLO (lo hace el agente del daemon):
   BauthAgent/src/                  ← código fuente Rust/Go
   cargo build --release            ← compilación
   cp target/release/bauth \        ← el binario se copia a la ficha
     servers/S03-identityserver/bauth/bauth

2. PRODUCCIÓN (lo hace el BOS):
   bosctl ficha rescan              ← descubre la ficha bauth
   bosctl ficha install bauth       ← instala: copia binario a /opt/bos/bin/, crea systemd unit, inicia
   bosctl ficha status bauth        ← verifica: socket /run/bos/bauth.sock, health check
   bosctl ficha repair bauth        ← repara si se degrada
   bosctl ficha update bauth        ← actualiza a nueva versión

3. RESULTADO:
   /run/bos/bauth.sock              ← socket Unix verificado por el BOS
   systemctl status bauth           ← systemd unit gestionado por el BOS
```

**Todos los daemons se instalan como fichas, en el servidor lógico que les corresponde por función:**

| Daemon | Servidor lógico | Motivo |
|--------|:--------------:|--------|
| `bkernel` | S01-dataserver | Procesa datos (CDC PostgreSQL → Redis Streams) — pertenece al motor de datos |
| `biedata` | S01-dataserver | Gateway JSON-RPC externo sobre los datos — pertenece a la capa de datos |
| `bsearch` | S01-dataserver | Motor de búsqueda sobre PostgreSQL — pertenece a la capa de datos |
| `bauth` | S03-identityserver | Núcleo de identidad — pertenece al servidor de identidad |
| `bnotify` | S03-identityserver | Push MFA + notificaciones — pertenece al flujo de autenticación |
| `bnexus` (bhnexus + banexus) | S02-gatewayserver | Proxy de hardware universal + edge sentinel — pertenece al borde |
| `bcompass` | S15-aiserver | Asistencia IA — pertenece al servidor de IA |
| `bi18n` | S01-dataserver | Internacionalización — traducciones y localización |

---

## 3. Estructura canónica de producción — `/opt/skull/SBOS/`

```
/opt/skull/SBOS/                  ← raíz del sistema operativo empresarial
│
├── servers/                      ← catálogo de fichas (FUENTE ÚNICA — compartido)
│   ├── servers.yml               ← doctrina de servidores lógicos
│   ├── S00-hostserver/              ← bootstrap del SO (10 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── bos-preflight/           ← ficha 00: paquetes SO, usuario bosagent, TLS
│   │   ├── sbos-bootstrap-os/       ← ficha 01: kernel modules, sysctl, /data/
│   │   ├── sbos-bootstrap-k8s/      ← ficha 02: kubeadm + containerd + kubelet
│   │   ├── sbos-bootstrap-cni/      ← ficha 03: Calico 3.32.0
│   │   ├── sbos-bootstrap-storage/  ← ficha 04: StorageClass local-path
│   │   ├── sbos-bootstrap-platform/ ← ficha 05: namespaces, RBAC, etcd encryption
│   │   ├── sbos-bootstrap-hardening/← ficha 06: CIS hardening, UFW, Kyverno
│   │   ├── sbos-bootstrap-monitoring/← ficha 07: bootstrap de observabilidad
│   │   ├── sbos-namespace/          ← ficha 08: namespace del tenant + NetworkPolicy
│   │   ├── network-validator/       ← ficha 09: certifica CNI, DNS, conectividad
│   │   ├── nginx-web/               ← (unificado con S02/nginx — se elimina)
│   │   ├── cert-rotation/           ← ficha 11: rotación automática de certificados
│   │   ├── compliance-check/        ← ficha 12: verificación CIS post-instalación
│   │   ├── k8s-upgrader/            ← ficha 13: actualización de versión de K8s
│   │   ├── kyverno/                 ← ficha 14: admission policies
│   │   ├── linkerd/                 ← ficha 15: service mesh mTLS
│   │   ├── sbos-container-watchdog/ ← ficha 16: monitoreo de contenedores
│   │   ├── sbos-lifecycle/          ← ficha 17: ciclo de vida del host
│   │   ├── sbos-package-manager/    ← ficha 18: gestión declarativa de paquetes SO
│   │   ├── sbos-repair/             ← ficha 19: auto-reparación del sistema
│   │   └── sbos-security/           ← ficha 20: hardening de seguridad del host
│   │
│   ├── S01-dataserver/              ← bases de datos + daemons de datos (20 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── postgresql/              ← PG 18.4, SBOS_db, WAL logical
│   │   ├── redis/                   ← Redis 8.6.2, 3 DBs, AOF
│   │   ├── minio/                   ← object storage S3
│   │   ├── mongodb/                 ← MongoDB (backend Rocket.Chat)
│   │   ├── mysql/                   ← MySQL (apps legacy)
│   │   ├── citus/                   ← PostgreSQL distribuido (escalado horizontal)
│   │   ├── timescaledb/             ← series temporales (métricas, IoT)
│   │   ├── pgbouncer/               ← connection pooling PostgreSQL
│   │   ├── pgbackrest/              ← backup y restauración PostgreSQL
│   │   ├── pg-partman/              ← particionado automático de tablas
│   │   ├── pg-stat-monitor/         ← monitoreo de estadísticas PostgreSQL
│   │   ├── pgadmin4/                ← administración web de PostgreSQL
│   │   ├── symmetricds/             ← sincronización multi-BD (CDC)
│   │   ├── bkernel/                 ← ficha: daemon CDC Rust MUSL (compila BkernelAgent)
│   │   ├── biedata/                 ← ficha: daemon JSON-RPC gateway externo (compila BiedataAgent)
│   │   ├── bsearch/                 ← ficha: motor de búsqueda soberano (compila BintelligenceAgent)
│   │   ├── bi18n/                   ← ficha: internacionalización (compila Bi18nAgent)
│   │   ├── bpay/                    ← ficha: motor de pagos (compila BpayAgent)
│   │   ├── brate/                   ← ficha: tipos de cambio y crypto (compila BrateAgent)
│   │   └── btax/                    ← ficha: facturación electrónica SIN (compila BtaxAgent)
│   │
│   ├── S02-gatewayserver/           ← API gateway y secretos (4 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── kong/                    ← API Gateway 3.9.x LTS
│   │   ├── vault/                   ← secretos, PKI, AppRole
│   │   ├── besu-qbft/               ← nodo Blockchain Hyperledger Besu
│   │   └── bnexus/                  ← carpeta agrupadora
│   │       ├── bhnexus/             ← ficha: hardware bridge (WebSocket mTLS :9444)
│   │       └── banexus/             ← ficha: edge sentinel (auth_request HMAC < 50ms)
│   │
│   ├── S03-identityserver/          ← identidad + seguridad + notificaciones (7 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── keycloak/                ← IdP central (26.6.2), SSO 65+ apps
│   │   ├── bauth/                   ← ficha: daemon de identidad (compila BauthAgent)
│   │   ├── bnotify/                 ← ficha: push MFA + notificaciones (compila BnotifyAgent)
│   │   ├── wazuh-manager/           ← SIEM — ingesta de eventos de seguridad
│   │   ├── wazuh-indexer/           ← índice de eventos Wazuh
│   │   └── openvas/                 ← escaneo de vulnerabilidades
│   │
│   ├── S04-erpserver/               ← ERP (2 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── tryton/                  ← ERP base + localización Bolivia
│   │   └── rabbitmq-erp/            ← cola de mensajes para procesos ERP
│   │
│   ├── S05-devserver/               ← Smart Apps de negocio (7 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── smarttax/                ← facturación electrónica
│   │   ├── smartreport/             ← reportes financieros y fiscales
│   │   ├── smartrates/              ← tipos de cambio
│   │   ├── smartorc/                ← ORC (Operaciones, Registro y Control)
│   │   ├── smartvaultflow/          ← flujo de caja y tesorería
│   │   ├── smartportfolio/          ← portafolio de inversiones
│   │   └── smartpay/                ← pagos y cobranzas
│   │
│   ├── S06-appsserver/              ← Apps empresariales (20 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── saleor/                  ← e-commerce
│   │   ├── directus/                ← CMS headless / backend admin
│   │   ├── orangehrm/               ← RRHH
│   │   ├── taiga/                   ← gestión de proyectos
│   │   ├── espocrm/                 ← CRM
│   │   ├── wikijs/                  ← wiki y documentación
│   │   ├── zammad/                  ← helpdesk y tickets
│   │   ├── mattermost/              ← mensajería (también en S10)
│   │   ├── calcom/                  ← agenda y reservas
│   │   ├── easyappointments/        ← reservas de citas
│   │   ├── openproject/             ← gestión de proyectos avanzada
│   │   ├── limesurvey/              ← encuestas
│   │   ├── gnuhealth/               ← sistema de salud
│   │   ├── novu/                    ← notificaciones multi-canal
│   │   ├── tastyigniter/            ← restaurantes y delivery
│   │   ├── trilium/                 ← notas y conocimiento
│   │   ├── vaultwarden/             ← gestor de contraseñas
│   │   ├── authelia/                ← portal de autenticación
│   │   ├── sbos-notifier/           ← agente de envío de notificaciones (compartido)
│   │   └── stalwart/                ← servidor de correo todo-en-uno
│   │
│   ├── S07-reportserver/            ← Reportes y BI (7 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── superset/                ← dashboards y visualización
│   │   ├── airflow/                 ← orquestación de pipelines
│   │   ├── jaspersoft/              ← reportes empresariales
│   │   ├── jasperstarter/           ← generador de reportes CLI
│   │   ├── openmetadata/            ← catálogo de datos
│   │   └── pdfjs/                   ← visor y generador de PDF
│   │
│   ├── S08-docserver/               ← Documentos y OCR (7 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── paperless-ngx/           ← gestión documental
│   │   ├── docuseal/                ← firmas digitales
│   │   ├── kimios/                  ← workflow documental
│   │   ├── tesseract/               ← OCR
│   │   ├── tabula/                  ← extracción de tablas de PDF
│   │   ├── camelot/                 ← extracción avanzada de PDF
│   │   └── solr/                    ← índice de búsqueda documental
│   │
│   ├── S09-searchserver/            ← Búsqueda empresarial (2 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── elasticsearch/           ← motor de búsqueda full-text
│   │   └── rabbitmq-search/         ← cola de indexación
│   │
│   ├── S10-commsserver/             ← Comunicaciones (15 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── postfix/                 ← SMTP
│   │   ├── dovecot/                 ← IMAP/POP3
│   │   ├── postfixadmin/            ← administración de cuentas de correo
│   │   ├── roundcube/               ← webmail
│   │   ├── cypht/                   ← webmail ligero
│   │   ├── stalwart/                ← servidor de correo moderno
│   │   ├── freepbx/                 ← central telefónica VoIP
│   │   ├── mattermost/              ← mensajería de equipo
│   │   ├── rocketchat/              ← mensajería (alternativa)
│   │   ├── centrifugo/              ← mensajería en tiempo real
│   │   ├── clamav/                  ← antivirus
│   │   ├── spamassassin/            ← anti-spam
│   │   ├── zammad/                  ← helpdesk (también en S06)
│   │   ├── jitsi/                   ← videoconferencia (pendiente)
│   │   └── matrix/                  ← mensajería federada (pendiente)
│   │
│   ├── S11-vdiserver/               ← Escritorio virtual soberano (4 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── nextcloud/               ← archivos, CalDAV, CardDAV
│   │   ├── onlyoffice/              ← ofimática colaborativa
│   │   ├── guacamole/               ← gateway VNC/RDP/SSH vía navegador
│   │   └── fedora-kde/              ← escritorio soberano Fedora KDE Plasma
│   │
│   ├── S12-monitorserver/           ← Observabilidad (7 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── prometheus/              ← métricas y alertas
│   │   ├── grafana/                 ← dashboards
│   │   ├── alertmanager/            ← gestión de alertas
│   │   ├── alloy/                   ← collector OTel (reemplaza Loki/Prometheus agents)
│   │   ├── sbos-app-kube-state-metrics/ ← métricas de estado K8s
│   │   └── sbos-app-node-exporter/  ← métricas de nodo
│   │
│   ├── S13-geoserver/               ← Geo-espacial (5 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── traccar/                 ← rastreo GPS
│   │   ├── fleetbase/               ← gestión de flotas
│   │   ├── xibo/                    ← señalización digital
│   │   ├── novosga/                 ← gestión de atención al cliente
│   │   └── cardmesh/                ← malla de tarjetas RFID/NFC
│   │
│   ├── S14-opsserver/               ← Operaciones y DevOps (8 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── gitlab/                  ← repositorio Git + CI/CD
│   │   ├── bareos/                  ← backup empresarial
│   │   ├── velero/                  ← backup y disaster recovery K8s
│   │   ├── pgbackrest-svc/          ← servicio de backup PostgreSQL
│   │   ├── k6/                      ← pruebas de carga
│   │   ├── goss/                    ← validación de estado del sistema
│   │   ├── trivy/                   ← escaneo de vulnerabilidades
│   │   └── searxng/                 ← metabuscador privado
│   │
│   └── S15-aiserver/                ← Inteligencia Artificial (7 fichas)
│       ├── PROPOSITO.md
│       ├── ollama/                  ← motor LLM local
│       ├── qdrant/                  ← base de datos vectorial
│       ├── open-webui/              ← interfaz chat IA
│       ├── embedding-worker/        ← generación de embeddings
│       ├── flowise/                 ← orquestación de flujos IA
│       ├── langfuse/                ← observabilidad de LLMs
│       └── bcompass-svc/            ← servicio HITL de asistencia IA
│
│   └── S16-webserver/               ← Plataforma web multi-tenant (4 fichas) 🆕
│       ├── PROPOSITO.md
│       ├── nginx/                   ← reverse proxy + TLS termination + wildcard/custom domains
│       ├── certbot/                 ← certificados SSL por dominio (Let's Encrypt)
│       ├── modsecurity/             ← WAF (Web Application Firewall)
│       └── website-engine/          ← renderizado dinámico por tenant/empresa/sucursal
│
├── DDLs/                          ← esquema de base de datos (FUENTE ÚNICA — compartido)
│   ├── ddls.yml                  ← doctrina de DDLs
│   ├── inicializar_sbos_db.sh    ← orquestador único de carga
│   ├── migrations/               ← estructura de tablas
│   │   ├── sbos_00__esquema_base.sql
│   │   ├── bos_01__control_plane.sql
│   │   └── ...
│   ├── seeds/                    ← datos iniciales idempotentes
│   │   ├── bauth_01__cfg_key_translation.sql
│   │   ├── bglobal_01__global_country.sql
│   │   └── ...
│   └── resources/                ← herramientas (no se cargan en BD)
│
├── config/                        ← configuración de producción
│   ├── entornos/
│   │   └── produccion.yml        ← parámetros del servidor (IP, puertos, recursos)
│   └── bos/
│       ├── bos.toml              ← configuración del daemon BOS
│       └── bos-install.toml      ← configuración de instalación
│
├── backups/                       ← respaldos (gestionados por BOS)
│   ├── S01-postgresql/           ← backups de PostgreSQL (pg_dump programado)
│   ├── S03-keycloak/             ← export de realms
│   ├── S03-vault/                ← snapshots de Vault
│   └── estado/                   ← snapshots de .sbos_state.json
│
├── context/                       ← documentación operativa (sin código)
│   └── manuales/                 ← solo manuales de USUARIO y SISTEMA
│       ├── MANUAL-USUARIO-BOS.md
│       ├── MANUAL-SISTEMA-BOS.md
│       └── ...
│
├── scripts/                       ← herramientas operativas
│   ├── portctl.sh                ← consulta de puertos
│   └── ...
│
├── paths.yml                      ← rutas canónicas del sistema
│
└── staging/                       ← credenciales y seeds de producción
    ├── seed-produccion.yml        ← seed del tenant principal
    └── bos-bootstrap.env          ← variables de entorno
```

---

## 4. Estructura gestionada por el BOS en el sistema

Fuera de `/opt/skull/SBOS/`, el BOS crea y gestiona estos directorios del sistema:

```
/etc/bos/                          ← configuración estática del daemon
├── bos.toml                       ← configuración principal
├── bos-install.toml               ← estado de instalación
├── .env                           ← variables de entorno
├── .kube/
│   └── config                     ← kubeconfig del cluster
├── rbac/
│   └── roles.json                 ← roles RBAC
├── tls/
│   ├── bos.crt                    ← certificado TLS (autofirmado o Vault PKI)
│   └── bos.key                    ← clave privada TLS
└── cap-policies/                  ← políticas YAML del Motor de Capacidad (M5.3)
    └── default.yml

/run/bos/                          ← runtime (efímero — sobrevive reinicio)
├── bos.sock                       ← socket Unix (Interface Dual)
├── bos.pid                        ← PID del daemon
└── bos-grpc.sock                  ← socket gRPC interno

/var/log/bos/                      ← logs
├── bos.log                        ← log principal del daemon
├── audit.log                      ← auditoría (ISO 27001 A.8.15)
├── fichas/                        ← logs de instalación de fichas
│   ├── postgresql.log
│   ├── redis.log
│   └── ...
└── ai-audit.jsonl                 ← trayectorias del agente IA (biaos)

/var/lib/bos/                      ← estado persistente
├── .sbos_state.json               ← estado centralizado (fcntl.flock)
└── k8s-installer.state            ← estado de instalación K8s  

/opt/bos/                          ← binarios y core del BOS
├── bin/
│   ├── bos                        ← binario del daemon
│   └── bosctl                     ← binario del CLI
├── core/
│   └── servers/                   ← copia local del catálogo de fichas
└── blibs/                         ← bibliotecas compartidas

/etc/sbos/                         ← estado del tenant
└── tenant.conf                    ← configuración del tenant principal

/etc/sysctl.d/
└── 99-sbos-k8s.conf               ← parámetros del kernel para K8s

/data/                             ← datos persistentes (PVs de K8s)
```

---

## 5. Asignación de puertos — catálogo base

El BOS verifica que estos puertos estén disponibles durante `bos-preflight`. Son los puertos
mínimos del stack Alpha. El catálogo completo está en `SBOS-050-PORT-CATALOG.md`.

| Puerto | Propietario | Propósito | Acceso |
|:------:|-------------|-----------|--------|
| 22 | SSH | Administración del host | Externo (controlado por UFW) |
| 443 | Kong | API Gateway — entrada de todas las apps | Externo |
| 9443 | BOS | Context API HTTPS (TLS 1.3) — Kong la consulta en cada request | Interno (Kong) |
| 6443 | K8s API Server | kubeadm | Interno |
| 5432 | PostgreSQL | Motor principal (ClusterIP :8100) | Interno (K8s) |
| 6379 | Redis | Caché, sesiones, streams (ClusterIP :8120) | Interno (K8s) |
| 8080 | Keycloak | IdP — health y admin (ClusterIP :8200) | Interno (K8s) |
| 8200 | Vault | Secretos — API (ClusterIP :8300) | Interno (K8s) |
| 8001 | Kong Admin | Admin API (solo localhost) | Interno |
| 9090 | BOS | Métricas Prometheus (solo localhost) | Interno |
| 8095 | Coordinador | JSON-RPC (solo localhost, solo desarrollo) | Interno |

**Regla de firewall (UFW):** deny-all por defecto. Solo 22 (SSH) y 443 (Kong) abiertos al
exterior. Todo lo demás es ClusterIP o localhost. Sin excepciones.

---

## 6. Organización de backups

Gestionados por el BOS vía `bosctl backup`. Cada tipo de dato tiene su estrategia:

| Dato | Ubicación | Frecuencia | Retención | Estrategia |
|------|-----------|:----------:|:---------:|------------|
| `SBOS_db` (completa) | `backups/S01-postgresql/` | Diaria (2 AM) | 7 días local, 90 días MinIO, 7 años offline | `pg_dump --format=custom` + SHA-256 |
| `skSBOS_db` WAL | `backups/S01-postgresql/wal/` | Continua | 7 días | `archive_command` de PostgreSQL |
| `.sbos_state.json` | `backups/estado/` | Cada cambio | 30 versiones | Copia atómica + SHA-256 |
| Vault | `backups/S03-vault/` | Semanal | 90 días | `vault operator raft snapshot save` |
| Keycloak realms | `backups/S03-keycloak/` | Semanal | 90 días | Export JSON vía Admin API |
| Logs | MinIO S01 | Rotación diaria | 90 días online, 7 años offline | `logrotate` + compresión xz |
| `servers/` (fichas) | Git (fuente de verdad) | Cada cambio | Permanente | Git es el backup primario |

---

## 7. El BOS como instalador universal de daemons

En producción, el BOS es el **único** mecanismo de instalación. No hay `cargo build`, `go build`,
ni `pip install`. Todo es una ficha.

### Flujo de instalación de un daemon como ficha

```bash
# 1. El daemon se declara como ficha en el servidor lógico que le corresponde
#    Ejemplo: servers/S03-identityserver/bauth/

# 2. El BOS la descubre al escanear servers/
bosctl ficha rescan

# 3. El BOS la instala respetando el DAG de dependencias
bosctl ficha install bauth

# 4. El BOS verifica que el daemon está operativo
bosctl ficha status bauth
# → state: INSTALADA, health: HEALTHY, socket: /run/bos/bauth.sock

# 5. Si el daemon se degrada, el BOS lo repara
bosctl ficha repair bauth

# 6. Si hay nueva versión, el BOS la actualiza con compensación
bosctl ficha update bauth --version=2.0.0
```

### Contrato de ficha para daemons

Todo daemon que quiera ser instalado por el BOS debe proveer:

| Archivo | Obligatorio | Contenido |
|---------|:-----------:|-----------|
| `manifest.yml` | ✅ | Identidad, servidor lógico, dependencias, versión, health check, puertos |
| `PROPOSITO.md` | ✅ | Qué es, por qué existe, para qué sirve |
| `task_catalog.sh` | ✅ | Funciones `<daemon>_install`, `<daemon>_verify`, `<daemon>_health`, `<daemon>_repair`, `<daemon>_remove` |
| `<daemon>.service` | ✅ | Unit systemd (el task_catalog.sh lo copia a `/etc/systemd/system/`) |
| `resources/` | Opcional | Archivos de configuración, seeds, assets |

---

## 8. Orden de instalación en producción

El BOS sigue el DAG topológico. Este es el orden planificado para el servidor de producción:

```
FASE 0 — Bootstrap del SO (S-HOST)
  1. bos-preflight         ← paquetes SO, usuario bosagent, directorios, TLS cert
  2. sbos-bootstrap-os     ← kernel modules, sysctl, /data/
  3. sbos-bootstrap-k8s    ← kubeadm + containerd + kubelet + kubectl
  4. sbos-bootstrap-cni    ← Calico 3.32.0
  5. sbos-bootstrap-storage ← StorageClass local-path

FASE 1 — Stack de datos (S01)
  6. postgresql            ← SBOS_db + schemas + BDs de apps
  7. redis                 ← 3 DBs (cache/ctx_id/streams)
  8. minio                 ← 3 buckets (backups/assets/documents)

FASE 2 — Identidad y gateway (S02, S03)
  9. vault                 ← init + unseal + PKI + AppRole
  10. keycloak             ← realm maestro + 5 SPIs
  11. kong                 ← API Gateway + plugins OIDC, rate-limit, ctx-inject
  12. nginx                ← ingress dumb → Kong
  13. bauth                ← daemon de identidad (ficha — binario compilado por BauthAgent)
  14. bnotify              ← push MFA + notificaciones (ficha — binario compilado por BnotifyAgent)

FASE 3 — Daemons de datos (S01)
  15. bkernel              ← CDC PostgreSQL → Redis Streams (ficha — binario compilado por BkernelAgent)
  16. biedata              ← JSON-RPC 2.0 gateway externo (ficha — binario compilado por BiedataAgent)
  17. bsearch              ← motor de búsqueda soberano (ficha — binario compilado por BintelligenceAgent)

FASE 4 — Borde y conectividad (S02)
  18. bnexus               ← proxy de hardware (bhnexus WS mTLS :9444 + banexus edge sentinel HMAC) (ficha)

FASE 5 — Aplicaciones (S04, S06, S11...)
  20. tryton               ← ERP
  21. nextcloud            ← archivos cloud soberano
  22. guacamole            ← gateway VNC/RDP/SSH
  23. fedora-kde            ← escritorio VDI

FASE 5 — Observabilidad (S12)
  23. prometheus
  24. grafana
  25. loki
```

---

## 9. Diferencias clave: desarrollo vs producción

| Aspecto | Desarrollo (`/opt/skull/orquestador/proyectos/SBOS/`) | Producción (`/opt/skull/SBOS/`) |
|---------|-------------------------------------------------------|--------------------------------|
| **Propósito** | Codificar, testear, documentar | Operar el negocio |
| **Código fuente** | ✅ `*/src/` con Go, Rust, Python | ❌ Solo binarios compilados |
| **Fábrica** | ✅ `OrquestaCoreSBOS/`, `CompositorSBOS/` | ❌ No existe |
| **Agentes IA** | ✅ `*Agent/` con contextos de desarrollo | ❌ No existen |
| **Documentación** | Completa: specs, ADRs, gaps, sesiones | Solo manuales de usuario y sistema |
| **servers/** | ✅ Catálogo compartido (fuente única) | ✅ **El mismo** catálogo (copia sincronizada) |
| **DDLs/** | ✅ Esquemas y seeds (fuente única) | ✅ **Los mismos** (copia sincronizada) |
| **Binarios** | Compilados en el host | Copiados vía scp o `bosctl system-install` |
| **BOS** | Corre en modo desarrollo (`BOS_DEV_SKIP_ROOT=1`) | Corre como root, systemd, hardening activo |
| **Agentes** | 17 agentes desarrolladores activos | 0 — no hay desarrollo en producción |
| **Tamaño** | ~22 GB (código, git, docs, backups) | ~2 GB (solo lo necesario para operar) |

---

## 10. El BOS como arquitecto del terreno

Antes de que cualquier ficha se instale, el BOS ya preparó el terreno. Esto es lo que
`bosctl system-install` garantiza:

1. **Directorios creados** con permisos correctos (`bosagent:bosagent`, 0750/0640)
2. **Puertos verificados** — sin conflictos con servicios existentes
3. **Paquetes del SO instalados** — los 10 de `bos-preflight` + sus dependencias
4. **Usuario del sistema creado** — `bosagent` (uid=999), sin shell, sin home
5. **systemd configurado** — `bos.service` enabled, `Delegate=yes` para cgroup v2
6. **TLS cert generado** — autofirmado para `:9443` (luego reemplazado por Vault PKI en Pasada 2)
7. **K8s cluster inicializado** — a través de la ficha `sbos-bootstrap-k8s`
8. **Backups programados** — cron jobs para pg_dump, Vault snapshot, state file
9. **Firewall configurado** — UFW deny-all, solo 22 + 443 abiertos
10. **Logrotate configurado** — rotación de `/var/log/bos/` cada 10MB, 5 archivos

Solo cuando los 10 puntos están verificados, el BOS considera que el terreno está listo y
procede a instalar la primera ficha del stack.

---

## Referencias

- [servers.yml](../../../servers/servers.yml) — doctrina de servidores lógicos
- [ddls.yml](../../../DDLs/ddls.yml) — doctrina de DDLs y seeds
- [SBOS-050-PORT-CATALOG](../../../context/BOS_V8/BOS_V8_SBOS-050-PORT-CATALOG.md)
- [SBOS-055-FICHA-SOVEREIGNTY](../../../context/BOS_V8/BOS_V8_SBOS-055-FICHA-SOVEREIGNTY.md)
- [bos_01__control_plane.sql](../../../DDLs/migrations/bos_01__control_plane.sql) — schema `bos` (528 líneas)
- [0.00 — Directrices BOS](../0.00_MANUAL-DIRECTRICES-BOS-CONTROL-PLANE.md)
- [1.01 — Bootstrap y Stack Alpha](../1.01_MANUAL-BOOTSTRAP-STACK-ALPHA.md)

---

*SKULL · SBOS · BosAgent · Julio 2026*
