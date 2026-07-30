# Anexo A.02 — Estructura del Servidor de Producción SBOS
## Layout del filesystem, organización de carpetas, y directrices que el BOS impone al preparar el terreno

**Versión:** 2.2.0
**Fecha:** 2026-07-18
**Autor:** bos-developer — SBOS
**Referencia:** [0.00 — Directrices BOS Control Plane](../0.00_MANUAL-DIRECTRICES-BOS-CONTROL-PLANE.md) · [1.01 — IAM Installer](../1.01_MANUAL-IAM-INSTALLER.md) · [3.08 — Port Manager](../3.08_MANUAL-PORT-MANAGER.md) · [A.12 — RFC 6335 Port Manager](A.12_ANEXO-PORT-MANAGER-KARDEX.md)
**Aplica a:** servidor de producción (`/opt/skull/SBOS/`) — actualmente llamado "servidor de pruebas" (VPS 13.140.128.230)

**Cambio en v2.2.0:** Regla R7 — Instalación universal por ficha. Solo el BOS instala.
Todo daemon crea su propia ficha con 5 obligaciones (O1-O5) y sigue el mismo ciclo de vida
(install/update/repair/remove) que cualquier aplicación o base de datos.
**Cambio en v2.1.0:** Fortalecido con el Port Manager (3.08 + A.12).
**Cambio en v2.0.0:** Fusión de secciones 3 y 4. Toda la estructura gestionada por el BOS
(binarios, configuración, runtime, logs, estado, datos) ahora vive dentro de
`/opt/skull/SBOS/`. La sección 4 anterior (`/etc/bos/`, `/opt/bos/`, `/var/log/bos/`,
`/run/bos/`, `/var/lib/bos/`, `/data/`) desaparece como ubicaciones independientes.

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
| `bin/` — binarios de todos los daemons | `/opt/skull/orquestador/` — fábrica |
| `config/` — configuración del daemon y del sistema | Código fuente de cualquier daemon |

### 2.2 Los daemons son fichas — Regla R7

**R7 — Instalación universal por ficha:** solo el BOS instala. Todo — aplicación, base de datos,
daemon, proxy, escritorio VDI — entra al SBOS como una ficha. No hay excepción.

**El BOS no distingue entre "daemon" y "aplicación":** todo es una ficha con `manifest.yml`
+ `task_catalog.sh` + `PROPOSITO.md`. Un daemon se instala, actualiza, repara y remueve
exactamente igual que PostgreSQL, Redis o Nextcloud.

**Obligaciones de cada daemon para ser instalable por el BOS:**

| # | Obligación | Qué significa |
|:--|-----------|---------------|
| **O1** | Crear su propia ficha | El daemon tiene un directorio en `servers/<servidor>/<nombre>/` con `manifest.yml`, `task_catalog.sh`, `PROPOSITO.md` y `<nombre>.service` |
| **O2** | Copiar todo lo necesario a la ficha | El binario compilado, archivos de configuración, seeds, recursos — todo lo que el daemon necesita para operar debe estar dentro del directorio de la ficha |
| **O3** | Definir sus procesos de instalación | `task_catalog.sh` debe implementar al menos: `<daemon>_install`, `<daemon>_verify`, `<daemon>_health`, `<daemon>_repair`, `<daemon>_remove` |
| **O4** | Declarar sus dependencias | `manifest.yml` debe declarar de qué otras fichas depende (bases de datos, secretos, otros daemons) |
| **O5** | Configurarse para que el BOS lo tome | La ficha debe cumplir el contrato de ficha: `manifest.yml` con identidad, servidor lógico, dependencias, versión, health check y puertos |

**Ciclo de vida del daemon como ficha — el mismo que cualquier aplicación:**

```
┌─────────────────────────────────────────────────────────────────────┐
│  DESARROLLO (lo hace el agente del daemon, NO el BOS)               │
│                                                                      │
│  1. Escribe código en su propio repo (BauthAgent/src/, etc.)        │
│  2. Compila: cargo build --release / CGO_ENABLED=0 go build        │
│  3. Copia el binario a la ficha:                                    │
│       cp target/release/bauth servers/S03-identityserver/bauth/     │
│  4. Copia configuraciones, seeds, resources a la ficha              │
│  5. Escribe/actualiza el task_catalog.sh con las 5 funciones        │
│  6. Actualiza manifest.yml (versión, dependencias, puertos)         │
│  7. Commitea la ficha actualizada                                   │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│  PRODUCCIÓN (lo hace el BOS, SIN intervención del desarrollador)    │
│                                                                      │
│  bosctl ficha rescan              ← descubre la ficha actualizada   │
│  bosctl ficha install bauth       ← copia binario a bin/,           │
│                                      crea systemd unit, inicia       │
│  bosctl ficha status bauth        ← socket respondiendo, healthy    │
│  bosctl ficha repair bauth        ← repara si se degrada            │
│  bosctl ficha update bauth        ← actualiza a nueva versión       │
│  bosctl ficha remove bauth        ← remueve con compensación        │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│  RESULTADO                                                           │
│                                                                      │
│  /opt/skull/SBOS/bin/bauth                 ← binario instalado      │
│  /opt/skull/SBOS/runtime/bauth.sock        ← socket operativo       │
│  systemctl status bauth                    ← systemd unit activo    │
│  bosctl ficha status bauth → INSTALADA ✅  ← estado verificado      │
└─────────────────────────────────────────────────────────────────────┘
```

**Violar R7 significa:** instalar un binario manualmente en el servidor, copiar un
systemd unit a mano, ejecutar `systemctl start` directamente, hacer `apt install`
de un daemon, o cualquier otra forma de instalación que no sea `bosctl ficha install`.
**El BOS es el único instalador del SBOS.**

**Todos los daemons se instalan como fichas, en el servidor lógico que les corresponde por función:**

| Daemon | Servidor lógico | Motivo |
|--------|:--------------:|--------|
| `biedata` | S01-dataserver | Gateway JSON-RPC externo sobre los datos — pertenece a la capa de datos |
| `bsearch` | S01-dataserver | Motor de búsqueda sobre PostgreSQL — pertenece a la capa de datos |
| `bauth` | S03-identityserver | Núcleo de identidad — pertenece al servidor de identidad |
| `bnotify` | S03-identityserver | Push MFA + notificaciones — pertenece al flujo de autenticación |
| `bnexus` (bhnexus + banexus) | S02-gatewayserver | Proxy de hardware universal + edge sentinel — pertenece al borde |
| `bcompass` | S15-aiserver | Asistencia IA — pertenece al servidor de IA |
| `bi18n` | S01-dataserver | Internacionalización — traducciones y localización |

---

## 3. Estructura unificada de producción — `/opt/skull/SBOS/`

### 3.0 Fundamento — por qué todo bajo una sola raíz

La industria converge hacia sistemas autocontenidos. Tres patrones lo respaldan:

| Patrón | Ejemplo real | Principio |
|--------|-------------|-----------|
| **Single-store inmutable** | NixOS `/nix/store` | Todo bajo un directorio. Paquetes = hashes criptográficos. Actualizaciones atómicas. Rollback instantáneo. Sin `/bin`, `/lib`, `/etc` dispersos. |
| **`/opt/<vendor>/<product>`** | FHS 3.0 §3.13 | Aplicaciones autocontenidas: binarios + config + datos bajo una raíz. Instalar = copiar. Desinstalar = `rm -rf`. Sin contaminar el sistema. |
| **Single-directory deployment** | Contenedores, appliances, Go static binaries | Todo relativo al binario. Portable en USB, NFS, o disco. Un `rsync` captura el sistema completo. |

**Para SBOS esto significa:** `/opt/skull/SBOS/` es la ÚNICA raíz. Todo — binarios,
configuración, runtime, logs, estado, datos, backups — vive aquí. Lo que antes estaba
disperso en `/etc/bos/`, `/opt/bos/`, `/var/log/bos/`, `/run/bos/`, `/var/lib/bos/`,
`/data/` ahora son subdirectorios de esta raíz.

**Beneficios concretos:**
- **Portabilidad:** migrar el SBOS a otro disco o servidor = un `rsync /opt/skull/SBOS/`
- **Backup atómico:** un snapshot de `/opt/skull/SBOS/` captura TODO el estado del sistema
- **Soberanía:** el BOS controla cada archivo sin que herramientas externas escriban en `/etc/` o `/var/`
- **Desinstalación limpia:** `rm -rf /opt/skull/SBOS/` borra todo rastro del SBOS
- **Auditabilidad:** un `find` sobre una raíz muestra cada archivo que existe

### 3.1 Árbol completo

```
/opt/skull/SBOS/                       ← raíz ÚNICA del sistema operativo empresarial
│
├── bin/                               ← binarios de TODOS los daemons y el CLI
│   ├── bos                            ← daemon BOS (Go estático, CGO_ENABLED=0)
│   ├── bosctl                         ← CLI de administración
│   ├── bauth                          ← daemon de identidad (Rust MUSL)
│   ├── bkernel                        ← daemon CDC (Rust MUSL)
│   ├── bnotify                        ← daemon de notificaciones (Rust/gRPC)
│   ├── biedata                        ← gateway JSON-RPC externo
│   ├── bsearch                        ← motor de búsqueda
│   ├── bi18n                          ← orquestador i18n
│   ├── bpay                           ← motor de pagos
│   ├── brate                          ← tipos de cambio
│   ├── btax                           ← facturación electrónica
│   ├── bhnexus                        ← proxy de hardware
│   ├── banexus                        ← edge sentinel
│   └── bcompass                       ← asistencia IA
│
├── core/                              ← scripts del motor Bash (5 scripts)
│   ├── 00_MASTER_INSTALL_SBOS.sh      ← orquestador principal
│   ├── 01_LOAD_ENVIRONMENT.sh         ← carga de variables
│   ├── 02_RESOLVE_DEPENDENCIES.sh     ← DAG topológico (Kahn)
│   ├── 03_EXECUTE_FICHA.sh            ← ejecutor de task_catalog.sh
│   └── 04_ROLLBACK_FICHA.sh           ← compensación
│
├── blibs/                             ← bibliotecas compartidas por los daemons
│   └── servers/                       ← caché local del catálogo de fichas
│
├── servers/                           ← catálogo de fichas (FUENTE ÚNICA — shared kernel)
│   ├── servers.yml                    ← doctrina de servidores lógicos
│   ├── S00-hostserver/                ← bootstrap del SO (20 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── bos-preflight/             ← ficha 00: paquetes SO, usuario bosagent, TLS
│   │   ├── sbos-bootstrap-os/         ← ficha 01: kernel modules, sysctl
│   │   ├── sbos-bootstrap-k8s/        ← ficha 02: kubeadm + containerd + kubelet
│   │   ├── sbos-bootstrap-cni/        ← ficha 03: Calico 3.32.0
│   │   ├── sbos-bootstrap-storage/    ← ficha 04: StorageClass local-path
│   │   ├── sbos-bootstrap-platform/   ← ficha 05: namespaces, RBAC, etcd encryption
│   │   ├── sbos-bootstrap-hardening/  ← ficha 06: CIS hardening, UFW, Kyverno
│   │   ├── sbos-bootstrap-monitoring/ ← ficha 07: bootstrap de observabilidad
│   │   ├── sbos-namespace/            ← ficha 08: namespace del tenant + NetworkPolicy
│   │   ├── network-validator/         ← ficha 09: certifica CNI, DNS, conectividad
│   │   ├── cert-rotation/             ← ficha 11: rotación automática de certificados
│   │   ├── compliance-check/          ← ficha 12: verificación CIS post-instalación
│   │   ├── k8s-upgrader/              ← ficha 13: actualización de versión de K8s
│   │   ├── kyverno/                   ← ficha 14: admission policies
│   │   ├── linkerd/                   ← ficha 15: service mesh mTLS
│   │   ├── sbos-container-watchdog/   ← ficha 16: monitoreo de contenedores
│   │   ├── sbos-lifecycle/            ← ficha 17: ciclo de vida del host
│   │   ├── sbos-package-manager/      ← ficha 18: gestión declarativa de paquetes SO
│   │   ├── sbos-repair/               ← ficha 19: auto-reparación del sistema
│   │   └── sbos-security/             ← ficha 20: hardening de seguridad del host
│   │
│   ├── S01-dataserver/                ← bases de datos + daemons de datos (20 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── postgresql/                ← PG 18.4, SBOS_db, WAL logical
│   │   ├── redis/                     ← Redis 8.6.2, 3 DBs, AOF
│   │   ├── minio/                     ← object storage S3
│   │   ├── mongodb/                   ← MongoDB (backend Rocket.Chat)
│   │   ├── mysql/                     ← MySQL (apps legacy)
│   │   ├── citus/                     ← PostgreSQL distribuido
│   │   ├── timescaledb/               ← series temporales (métricas, IoT)
│   │   ├── pgbouncer/                 ← connection pooling PostgreSQL
│   │   ├── pgbackrest/                ← backup y restauración PostgreSQL
│   │   ├── pg-partman/                ← particionado automático de tablas
│   │   ├── pg-stat-monitor/           ← monitoreo de estadísticas PostgreSQL
│   │   ├── pgadmin4/                  ← administración web de PostgreSQL
│   │   ├── symmetricds/               ← sincronización multi-BD (CDC)
│   │   ├── bkernel/                   ← ficha: daemon CDC (compila BkernelAgent)
│   │   ├── biedata/                   ← ficha: gateway JSON-RPC (compila BiedataAgent)
│   │   ├── bsearch/                   ← ficha: motor de búsqueda (compila BintelligenceAgent)
│   │   ├── bi18n/                     ← ficha: i18n (compila Bi18nAgent)
│   │   ├── bpay/                      ← ficha: pagos (compila BpayAgent)
│   │   ├── brate/                     ← ficha: tipos de cambio (compila BrateAgent)
│   │   └── btax/                      ← ficha: facturación SIN (compila BtaxAgent)
│   │
│   ├── S02-gatewayserver/             ← API gateway y secretos (4 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── kong/                      ← API Gateway 3.9.x LTS
│   │   ├── vault/                     ← secretos, PKI, AppRole
│   │   ├── besu-qbft/                 ← nodo Blockchain Hyperledger Besu
│   │   └── bnexus/                    ← carpeta agrupadora
│   │       ├── bhnexus/               ← ficha: hardware bridge (WebSocket mTLS :9444)
│   │       └── banexus/               ← ficha: edge sentinel (auth_request HMAC < 50ms)
│   │
│   ├── S03-identityserver/            ← identidad + seguridad + notificaciones (7 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── keycloak/                  ← ficha de infraestructura (realms, SPIs, Federation)
│   │   ├── bauth/                     ← ficha: IdP soberano (compila BauthAgent)
│   │   ├── bnotify/                   ← ficha: push MFA + notificaciones (compila BnotifyAgent)
│   │   ├── wazuh-manager/             ← SIEM — ingesta de eventos de seguridad
│   │   ├── wazuh-indexer/             ← índice de eventos Wazuh
│   │   └── openvas/                   ← escaneo de vulnerabilidades
│   │
│   ├── S04-erpserver/                 ← ERP (2 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── tryton/                    ← ERP base + localización Bolivia
│   │   └── rabbitmq-erp/              ← cola de mensajes para procesos ERP
│   │
│   ├── S05-devserver/                 ← Smart Apps de negocio (7 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── smarttax/                  ← facturación electrónica
│   │   ├── smartreport/               ← reportes financieros y fiscales
│   │   ├── smartrates/                ← tipos de cambio
│   │   ├── smartorc/                  ← ORC (Operaciones, Registro y Control)
│   │   ├── smartvaultflow/            ← flujo de caja y tesorería
│   │   ├── smartportfolio/            ← portafolio de inversiones
│   │   └── smartpay/                  ← pagos y cobranzas
│   │
│   ├── S06-appsserver/                ← Apps empresariales (20 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── saleor/                    ← e-commerce
│   │   ├── directus/                  ← CMS headless / backend admin
│   │   ├── orangehrm/                 ← RRHH
│   │   ├── taiga/                     ← gestión de proyectos
│   │   ├── espocrm/                   ← CRM
│   │   ├── wikijs/                    ← wiki y documentación
│   │   ├── zammad/                    ← helpdesk y tickets
│   │   ├── mattermost/                ← mensajería de equipo
│   │   ├── calcom/                    ← agenda y reservas
│   │   ├── easyappointments/          ← reservas de citas
│   │   ├── openproject/               ← gestión de proyectos avanzada
│   │   ├── limesurvey/                ← encuestas
│   │   ├── gnuhealth/                 ← sistema de salud
│   │   ├── novu/                      ← notificaciones multi-canal
│   │   ├── tastyigniter/              ← restaurantes y delivery
│   │   ├── trilium/                   ← notas y conocimiento
│   │   ├── vaultwarden/               ← gestor de contraseñas
│   │   ├── authelia/                  ← portal de autenticación
│   │   ├── sbos-notifier/             ← agente de envío de notificaciones
│   │   └── stalwart/                  ← servidor de correo todo-en-uno
│   │
│   ├── S07-reportserver/              ← Reportes y BI (7 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── superset/                  ← dashboards y visualización
│   │   ├── airflow/                   ← orquestación de pipelines
│   │   ├── jaspersoft/                ← reportes empresariales
│   │   ├── jasperstarter/             ← generador de reportes CLI
│   │   ├── openmetadata/              ← catálogo de datos
│   │   └── pdfjs/                     ← visor y generador de PDF
│   │
│   ├── S08-docserver/                 ← Documentos y OCR (7 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── paperless-ngx/             ← gestión documental
│   │   ├── docuseal/                  ← firmas digitales
│   │   ├── kimios/                    ← workflow documental
│   │   ├── tesseract/                 ← OCR
│   │   ├── tabula/                    ← extracción de tablas de PDF
│   │   ├── camelot/                   ← extracción avanzada de PDF
│   │   └── solr/                      ← índice de búsqueda documental
│   │
│   ├── S09-searchserver/              ← Búsqueda empresarial (2 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── elasticsearch/             ← motor de búsqueda full-text
│   │   └── rabbitmq-search/           ← cola de indexación
│   │
│   ├── S10-commsserver/               ← Comunicaciones (15 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── postfix/                   ← SMTP
│   │   ├── dovecot/                   ← IMAP/POP3
│   │   ├── postfixadmin/              ← administración de cuentas de correo
│   │   ├── roundcube/                 ← webmail
│   │   ├── cypht/                     ← webmail ligero
│   │   ├── stalwart/                  ← servidor de correo moderno
│   │   ├── freepbx/                   ← central telefónica VoIP
│   │   ├── mattermost/                ← mensajería de equipo
│   │   ├── rocketchat/                ← mensajería (alternativa)
│   │   ├── centrifugo/                ← mensajería en tiempo real
│   │   ├── clamav/                    ← antivirus
│   │   ├── spamassassin/              ← anti-spam
│   │   ├── zammad/                    ← helpdesk
│   │   ├── jitsi/                     ← videoconferencia (pendiente)
│   │   └── matrix/                    ← mensajería federada (pendiente)
│   │
│   ├── S11-vdiserver/                 ← Escritorio virtual soberano (4 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── nextcloud/                 ← archivos, CalDAV, CardDAV
│   │   ├── onlyoffice/                ← ofimática colaborativa
│   │   ├── guacamole/                 ← gateway VNC/RDP/SSH vía navegador
│   │   └── fedora-kde/                ← escritorio soberano Fedora KDE Plasma
│   │
│   ├── S12-monitorserver/             ← Observabilidad (7 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── prometheus/                ← métricas y alertas
│   │   ├── grafana/                   ← dashboards
│   │   ├── alertmanager/              ← gestión de alertas
│   │   ├── alloy/                     ← collector OTel
│   │   ├── sbos-app-kube-state-metrics/ ← métricas de estado K8s
│   │   └── sbos-app-node-exporter/    ← métricas de nodo
│   │
│   ├── S13-geoserver/                 ← Geo-espacial (5 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── traccar/                   ← rastreo GPS
│   │   ├── fleetbase/                 ← gestión de flotas
│   │   ├── xibo/                      ← señalización digital
│   │   ├── novosga/                   ← gestión de atención al cliente
│   │   └── cardmesh/                  ← malla de tarjetas RFID/NFC
│   │
│   ├── S14-opsserver/                 ← Operaciones y DevOps (8 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── gitlab/                    ← repositorio Git + CI/CD
│   │   ├── bareos/                    ← backup empresarial
│   │   ├── velero/                    ← backup y disaster recovery K8s
│   │   ├── pgbackrest-svc/            ← servicio de backup PostgreSQL
│   │   ├── k6/                        ← pruebas de carga
│   │   ├── goss/                      ← validación de estado del sistema
│   │   ├── trivy/                     ← escaneo de vulnerabilidades
│   │   └── searxng/                   ← metabuscador privado
│   │
│   ├── S15-aiserver/                  ← Inteligencia Artificial (7 fichas)
│   │   ├── PROPOSITO.md
│   │   ├── ollama/                    ← motor LLM local
│   │   ├── qdrant/                    ← base de datos vectorial
│   │   ├── open-webui/                ← interfaz chat IA
│   │   ├── embedding-worker/          ← generación de embeddings
│   │   ├── flowise/                   ← orquestación de flujos IA
│   │   ├── langfuse/                  ← observabilidad de LLMs
│   │   └── bcompass-svc/              ← servicio HITL de asistencia IA
│   │
│   └── S16-webserver/                 ← Plataforma web multi-tenant (4 fichas)
│       ├── PROPOSITO.md
│       ├── nginx/                     ← reverse proxy + TLS + virtual hosting
│       ├── certbot/                   ← certificados SSL (Let's Encrypt)
│       ├── modsecurity/               ← WAF (OWASP Core Rule Set)
│       └── website-engine/            ← renderizado dinámico multi-tenant
│
├── DDLs/                              ← esquema de base de datos (FUENTE ÚNICA — shared kernel)
│   ├── ddls.yml                       ← doctrina de DDLs
│   ├── inicializar_sbos_db.sh         ← orquestador único de carga
│   ├── migrations/                    ← estructura de tablas
│   │   ├── sbos_00__esquema_base.sql
│   │   ├── bos_01__control_plane.sql
│   │   └── ...
│   ├── seeds/                         ← datos iniciales idempotentes
│   │   ├── bauth_01__cfg_key_translation.sql
│   │   ├── bglobal_01__global_country.sql
│   │   └── ...
│   └── resources/                     ← herramientas (no se cargan en BD)
│
├── config/                            ← configuración del daemon y del sistema
│   ├── bos.toml                       ← configuración principal del daemon
│   ├── bos-install.toml               ← estado de instalación
│   ├── .env                           ← variables de entorno
│   ├── rbac/
│   │   └── roles.json                 ← roles RBAC
│   ├── tls/
│   │   ├── bos.crt                    ← certificado TLS (autofirmado o Vault PKI)
│   │   └── bos.key                    ← clave privada TLS
│   ├── cap-policies/                  ← políticas YAML del Motor de Capacidad
│   │   └── default.yml
│   └── entornos/
│       └── produccion.yml             ← parámetros del servidor (IP, puertos, recursos)
│
├── runtime/                           ← runtime (efímero — se recrea en cada arranque)
│   ├── bos.sock                       ← socket Unix (Interface Dual)
│   ├── bos.pid                        ← PID del daemon
│   └── bos-grpc.sock                  ← socket gRPC interno
│
├── logs/                              ← logs del sistema
│   ├── bos.log                        ← log principal del daemon
│   ├── audit.log                      ← auditoría (ISO 27001 A.8.15)
│   ├── fichas/                        ← logs de instalación de fichas
│   │   ├── postgresql.log
│   │   ├── redis.log
│   │   └── ...
│   └── ai-audit.jsonl                 ← trayectorias del agente IA (biaos)
│
├── state/                             ← estado persistente
│   ├── .sbos_state.json               ← estado centralizado (fcntl.flock)
│   └── k8s-installer.state            ← estado de instalación K8s
│
├── data/                              ← datos persistentes (PVs de K8s)
│
├── backups/                           ← respaldos (gestionados por BOS)
│   ├── S01-postgresql/                ← backups de PostgreSQL (pg_dump programado)
│   ├── S03-keycloak/                  ← export de realms
│   ├── S03-vault/                     ← snapshots de Vault
│   └── estado/                        ← snapshots de .sbos_state.json
│
├── kube/                              ← configuración de Kubernetes
│   └── config                         ← kubeconfig del cluster
│
├── tenant/                            ← estado del tenant
│   └── tenant.conf                    ← configuración del tenant principal
│
├── sysctl/                            ← parámetros del kernel
│   └── 99-sbos-k8s.conf               ← sysctl para K8s
│
├── context/                           ← documentación operativa (sin código)
│   └── manuales/                      ← solo manuales de USUARIO y SISTEMA
│       ├── MANUAL-USUARIO-BOS.md
│       ├── MANUAL-SISTEMA-BOS.md
│       └── ...
│
├── scripts/                           ← herramientas operativas
│   ├── portctl.sh                     ← consulta de puertos
│   └── ...
│
├── staging/                           ← credenciales y seeds de producción
│   ├── seed-produccion.yml            ← seed del tenant principal
│   └── bos-bootstrap.env              ← variables de entorno de bootstrap
│
└── paths.yml                          ← rutas canónicas del sistema
```

### 3.2 Symlinks de compatibilidad con el sistema

Linux espera ciertas rutas por convención (systemd, logrotate, FHS). El BOS crea estos
symlinks en `bos-preflight` para que las herramientas del sistema encuentren lo que
necesitan **sin que los datos salgan de `/opt/skull/SBOS/`**:

```
/etc/bos/            → /opt/skull/SBOS/config/       ← systemd busca bos.toml aquí
/run/bos/            → /opt/skull/SBOS/runtime/       ← socket Unix para otros daemons
/var/log/bos/        → /opt/skull/SBOS/logs/          ← logrotate y journald
/var/lib/bos/        → /opt/skull/SBOS/state/         ← estado persistente
/etc/sbos/           → /opt/skull/SBOS/tenant/        ← tenant.conf
/etc/sysctl.d/99-sbos-k8s.conf → /opt/skull/SBOS/sysctl/99-sbos-k8s.conf
```

**Principio:** los datos viven en `/opt/skull/SBOS/`. Los symlinks son punteros que
el sistema usa para encontrarlos. Si el symlink se rompe, el BOS lo recrea en el
próximo `bos-preflight`. Los datos nunca estuvieron fuera de la raíz.

### 3.3 Qué NO va en `/opt/skull/SBOS/`

Dos cosas quedan fuera porque son infraestructura del SO, no del SBOS:

| Path | Motivo |
|------|--------|
| `/data/` | Punto de montaje de PVs de K8s. Es un directorio del host que K8s espera encontrar en la raíz. El BOS usa un bind mount: `/opt/skull/SBOS/data/` → `/data/`. |
| `bos.service` / `bos-console.service` | Units de systemd en `/etc/systemd/system/`. No son datos, son la definición del servicio. systemd exige esta ubicación. |

Todo lo demás vive bajo `/opt/skull/SBOS/`.

---

## 5. Asignación de puertos — catálogo base

La asignación de puertos en el SBOS **no es manual**. El **Port Manager** ([3.08](../3.08_MANUAL-PORT-MANAGER.md) · [A.12](A.12_ANEXO-PORT-MANAGER-KARDEX.md))
es el subsistema del daemon BOS que deriva, verifica y registra cada puerto automáticamente
durante `bos.ficha.install`. El operador nunca elige un número de puerto — el BOS aplica
la fórmula `BASE_SERVIDOR + (FICHA×10) + TIPO` definida en el RFC 6335 (BCP 165).

Los puertos que siguen son los **mínimos del stack Alpha** que el BOS verifica durante
`bos-preflight`. El catálogo completo (400+ puertos, 16 servidores lógicos, fórmula de
derivación) está en `SBOS-050-PORT-CATALOG.md`. El Port Manager lo ejecuta.

| Puerto | Propietario | Propósito | Acceso |
|:------:|-------------|-----------|--------|
| 22 | SSH | Administración del host | Externo (controlado por UFW) |
| 443 | Kong | API Gateway — entrada de todas las apps | Externo |
| 9443 | BOS | Context API HTTPS (TLS 1.3) — Kong la consulta en cada request | Interno (Kong) |
| 6443 | K8s API Server | kubeadm | Interno |
| 5432 | PostgreSQL | Motor principal (ClusterIP :8100) | Interno (K8s) |
| 6379 | Redis | Caché, sesiones, streams (ClusterIP :8120) | Interno (K8s) |
| 8080 | Keycloak | Ficha de infraestructura — realms y SPIs (ClusterIP :8200) | Interno (K8s) |
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
# → state: INSTALADA, health: HEALTHY, socket: /opt/skull/SBOS/runtime/bauth.sock

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
| **Binarios** | Compilados en el host | Copiados a `/opt/skull/SBOS/bin/` vía `bosctl system-install` |
| **BOS** | Corre en modo desarrollo (`BOS_DEV_SKIP_ROOT=1`) | Corre como root, systemd, hardening activo |
| **Agentes** | 17 agentes desarrolladores activos | 0 — no hay desarrollo en producción |
| **Tamaño** | ~22 GB (código, git, docs, backups) | ~2 GB (solo lo necesario para operar) |

---

## 10. El BOS como arquitecto del terreno

Antes de que cualquier ficha se instale, el BOS ya preparó el terreno. Esto es lo que
`bosctl system-install` garantiza:

1. **Directorios creados** con permisos correctos (`bosagent:bosagent`, 0750/0640)
2. **Puertos verificados y registrados** — el Port Manager escanea el espacio de puertos, verifica contra el Kardex (`bos.port_assignment`) y contra IANA, y deja el terreno listo sin conflictos
3. **Paquetes del SO instalados** — los definidos en `bos-preflight/manifest.yml` + sus dependencias
4. **Usuario del sistema creado** — `bosagent` (uid=999), sin shell, sin home
5. **systemd configurado** — `bos.service` enabled, `Delegate=yes` para cgroup v2
6. **TLS cert generado** — autofirmado para `:9443` (luego reemplazado por Vault PKI en Pasada 2)
7. **K8s cluster inicializado** — a través de la ficha `sbos-bootstrap-k8s`
8. **Symlinks de compatibilidad creados** — `/etc/bos/` → `config/`, `/run/bos/` → `runtime/`, etc.
9. **Backups programados** — cron jobs para pg_dump, Vault snapshot, state file
10. **Firewall configurado** — UFW deny-all, solo 22 + 443 abiertos
11. **Logrotate configurado** — rotación de `logs/` cada 10MB, 5 archivos

Solo cuando los 11 puntos están verificados, el BOS considera que el terreno está listo y
procede a instalar la primera ficha del stack.

---

## Referencias

- [servers.yml](../../../servers/servers.yml) — doctrina de servidores lógicos
- [ddls.yml](../../../DDLs/ddls.yml) — doctrina de DDLs y seeds
- [SBOS-050-PORT-CATALOG](../../../context/BOS_V8/BOS_V8_SBOS-050-PORT-CATALOG.md)
- [SBOS-055-FICHA-SOVEREIGNTY](../../../context/BOS_V8/BOS_V8_SBOS-055-FICHA-SOVEREIGNTY.md)
- [bos_01__control_plane.sql](../../../DDLs/migrations/bos_01__control_plane.sql) — schema `bos` (528 líneas)
- [0.00 — Directrices BOS](../0.00_MANUAL-DIRECTRICES-BOS-CONTROL-PLANE.md)
- [1.01 — IAM Installer](../1.01_MANUAL-IAM-INSTALLER.md)
- [3.08 — Port Manager](../3.08_MANUAL-PORT-MANAGER.md) — subsistema de asignación automática de puertos
- [A.12 — RFC 6335 Port Manager y Kardex](A.12_ANEXO-PORT-MANAGER-KARDEX.md) — diseño técnico del motor de puertos

---

*SKULL · SBOS · BosAgent · Julio 2026*
