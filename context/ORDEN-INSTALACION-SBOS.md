# SBOS — Orden de Instalación por Capas de Dependencia
**Versión:** 2.0.0 · **Fecha:** 2026-10-20  
**Fuente de verdad:** `context/BOS_V8/SBOS-002-ARCH.md` · `Documentacion/CRONOGRAMA-INSTALACION.md`  
**VPS prueba activa:** `13.140.128.230` · Estado capturado: ciclo 58 (2026-10-20)

---

## Modelo de capas SBOS (SBOS-002-ARCH §3)

El orden de instalación no se define por servidor lógico — se define por el grafo de dependencias
entre capas. Un servicio de una capa superior nunca puede instalarse antes de que la capa inferior
esté completamente operativa.

```
┌─────────────────────────────────────────────────────────────────────┐
│ CAPA 5 — USUARIO        Core UI (Flutter) · VDI (Fedora KDE)   [K8s]│
├─────────────────────────────────────────────────────────────────────┤
│ CAPA 4 — APLICACIONES   ERP · RRHH · CRM · Docs · Comms · IA   [K8s]│
├─────────────────────────────────────────────────────────────────────┤
│ CAPA 3 — GOBIERNO        Keycloak · Vault · Kong · nginx        [K8s]│
├─────────────────────────────────────────────────────────────────────┤
│ CAPA 2 — DAEMONS         bkernel · bauth · biedata · bnotify         │
│          SOBERANOS        bsearch · bhnexus · banexus       [systemd]│
├─────────────────────────────────────────────────────────────────────┤
│ CAPA 1 — DATOS           PostgreSQL · Redis · MinIO            [K8s] │
├─────────────────────────────────────────────────────────────────────┤
│ CAPA 0 — INFRAESTR.      IAM Installer · Kubernetes · Ubuntu         │
└─────────────────────────────────────────────────────────────────────┘
```

> **Nota:** los **servidores lógicos S00-S16 son unidades de clasificación conceptual y migración**,
> no el criterio de orden de instalación. Una ficha de S12 puede instalarse antes que una de S01 si
> las dependencias lo requieren.

---

## Leyenda

| Estado VPS | Significado |
|---|---|
| `INSTALLED` | Instalada y verificada (ciclo 58 / cronograma v2.37.0) |
| `INSTALL_FAILED` | Falló la instalación — 24 confirmadas en ciclo 58 |
| `READY` | Auto_install=true, en cola, esperando slot |
| `PENDIENTE` | auto_install=false — no se auto-instala |
| `DESCARTADO` | No se instalará en v1 (fuente: cronograma oficial) |

| Decisión | Significado |
|---|---|
| **ACTIVA** | Instalada y corriendo — forma parte del núcleo de producción |
| **REPOSO** | Instalada con `replicas: 0` — activa solo por demanda o proyecto |
| **ELIMINAR** | Duplicado, obsoleta o reemplazada — borrar del repo |

---

## CAPA 0 — Infraestructura base (Bootstrap host + K8s)

> **Prerequisito de todo.** Sin esta capa no existe el cluster K8s ni el runtime de contenedores.
> El IAM Installer (BOS) ya corre como systemd antes de esta capa — es quien la instala.

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 1 | `bos-preflight` | S00-hostserver | `INSTALLED` | — | Prepara el host: usuario bosagent, directorios `/etc/bos`, `/run/bos`, paquetes SO, cgroup v2, TLS autofirmado, token RPC aleatorio | **ACTIVA** |
| 2 | `sbos-namespace` | S00-hostserver | `INSTALLED` | — | Crea los 17+ namespaces K8s + NetworkPolicy default-deny por tenant | **ACTIVA** |
| 3 | `sbos-bootstrap-os` | S00-hostserver | `INSTALLED` | 128Mi / 100m | Hardening Ubuntu 26.04: CRI-O, kernel params, sysctl, iptables-persistent | **ACTIVA** |
| 4 | `sbos-bootstrap-k8s` | S00-hostserver | `INSTALLED` | 128Mi / 100m | kubeadm init + certSANs + regla hairpin NAT (Hetzner) + corrige Kyverno webhook | **ACTIVA** |
| 5 | `sbos-bootstrap-cni` | S00-hostserver | `INSTALLED` | — | Calico CNI: NetworkPolicies default-deny, IP pools, tráfico pod-to-pod | **ACTIVA** |
| 6 | `sbos-bootstrap-platform` | S00-hostserver | `INSTALLED` | 128Mi / 100m | 17 namespaces, RBAC, StorageClasses, LimitRanges | **ACTIVA** |
| 7 | `local-path-provisioner` | S00-hostserver | `INSTALLED` | 64Mi / 50m | Provisioner dinámico para StorageClass `sbos-local-path` | **ACTIVA** |
| 8 | `sbos-bootstrap-storage` | S00-hostserver | `INSTALLED` | — | PersistentVolumes hostPath con política Retain para 19 fichas iniciales | **ACTIVA** |
| 9 | `sbos-bootstrap-monitoring` | S00-hostserver | `INSTALLED` | — | node-exporter + kube-state-metrics como prerequisito de bootstrap | **ACTIVA** |
| 10 | `network-validator` | S00-hostserver | `INSTALLED` | 128Mi / 100m | Valida CNI, DNS, service mesh y conectividad prerequisito — 4 pruebas | **ACTIVA** |
| 11 | `kyverno` | S00-hostserver | `INSTALLED` | — | Admission control Kyverno 1.13.0 (chart 3.3.4 estable en K8s 1.32) — políticas SBOS | **ACTIVA** |
| 12 | `container-watchdog` | S00-hostserver | `INSTALLED` | — | Watchdog del daemon BOS y procesos core dentro del contenedor | **ACTIVA** |
| 13 | `sbos-fichas-migrator` | S00-hostserver | `INSTALLED` | — | Migra fichas entre versiones de estado — prerequisito del observer | **ACTIVA** |

---

## CAPA 1 — Datos base (PostgreSQL · Redis · MinIO)

> **Prerequisito de los daemons SBOS y de todas las aplicaciones.** El WAL de PostgreSQL es el
> bus de eventos nativo del SBOS (SBOS-002-ARCH §2). Sin PostgreSQL, ningún daemon funciona.

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 14 | `postgresql-extensions` | S12-monitorserver | `INSTALLED` | — | PostGIS 3.5, pgvector, pg_cron 1.6, pgAudit — prerequisito del DDL SBOSDB | **ACTIVA** |
| 15 | `postgresql` | S01-dataserver | `INSTALLED` | 4Gi / 2000m | PostgreSQL 18 con Patroni HA — BD única de todo SBOS, WAL bus de eventos | **ACTIVA** |
| 16 | `sbos-database-init` | S01-dataserver | `INSTALLED` | — | DDL completo SBOSDB: 158 tablas, 12 schemas, seeds base | **ACTIVA** |
| 17 | `pgbouncer` | S01-dataserver | `INSTALLED` | 128Mi / 100m | Connection pooler para PostgreSQL — reduce conexiones de apps | **ACTIVA** |
| 18 | `pgbackrest` | S01-dataserver | `INSTALLED` | 128Mi / 100m | Backup PITR desde réplica standby | **ACTIVA** |
| 19 | `redis` | S01-dataserver | `INSTALLED` | 2Gi / 500m | Redis 8.6.2 — caché, colas de tareas y sesiones | **ACTIVA** |
| 20 | `minio` | S01-dataserver | `PENDIENTE` | 2Gi / 1000m | Object storage S3-compatible para backups, uploads y archivos | **ACTIVA** |
| 21 | `timescaledb` | S01-dataserver | `INSTALLED` | 256Mi / 200m | Extensión time-series de PostgreSQL para métricas e IoT | **ACTIVA** |
| 22 | `pg-partman` | S01-dataserver | `INSTALLED` | 128Mi / 100m | Particionado automático por tiempo en PostgreSQL | **ACTIVA** |
| 23 | `pg-stat-monitor` | S01-dataserver | `INSTALLED` | 128Mi / 100m | Monitoreo avanzado de queries PostgreSQL | **ACTIVA** |

---

## CAPA 1b — Datos secundarios (solo cuando la capa 1 está estable)

> Bases de datos y almacenamiento opcionales para apps específicas.

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 24 | `mysql` | S01-dataserver | `INSTALLED` | 512Mi / 200m | BD secundaria para FreePBX, OrangeHRM, Easy!Appointments | **REPOSO** |
| 25 | `citus` | S01-dataserver | `INSTALLED` | 512Mi / 500m | Sharding horizontal de PostgreSQL para analytics | **REPOSO** |
| 26 | `symmetricds` | S01-dataserver | `INSTALLED` | 256Mi / 200m | CDC bidireccional PG ↔ MySQL — necesario cuando FreePBX u OrangeHRM están activos | **REPOSO** |
| 27 | `mongodb` | S01-dataserver | `INSTALLED` | 512Mi / 200m | MongoDB para Rocket.Chat (único consumidor) | **REPOSO** |
| 28 | `pgadmin4` | S01-dataserver | `INSTALLED` | 256Mi / 200m | Admin UI de PostgreSQL con OAuth2-Proxy | **ACTIVA** |

---

## CAPA 2 — Seguridad y secrets (Vault)

> **Prerequisito de daemons y aplicaciones que manejan credenciales.** Vault PKI emite los
> certificados TLS. Sin Vault, los daemons no pueden obtener sus secrets.

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 29 | `vault` | S02-gatewayserver | `INSTALLED` | 1Gi / 500m | Vault 2.0.1 — gestión de secrets con backend PostgreSQL y PKI engine | **ACTIVA** |
| 30 | `vault-unsealer` | S02-gatewayserver | `INSTALL_FAILED` | — | CronJob que desella Vault automáticamente tras cada reinicio del pod | **ACTIVA** |

---

## CAPA 3 — Gobierno: Identidad · API Gateway · TLS

> **Prerequisito de todas las aplicaciones con SSO.** Keycloak es el IAM centralizado del SBOS.
> Kong es el API Gateway que aplica OIDC. nginx termina TLS y sirve como reverse proxy.
> **Los daemons bauth y biedata dependen de esta capa completa.**

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 31 | `keycloak` | S03-identityserver | `INSTALLED` | 2Gi / 1000m | Keycloak 26.6.2 — IAM con PostgreSQL backend, realm skbos, 5 SPIs | **ACTIVA** |
| 32 | `oauth2-proxy` | S03-identityserver | `INSTALLED` | 128Mi / 100m | Auth proxy OIDC para apps sin soporte nativo de Keycloak | **ACTIVA** |
| 33 | `certbot` | S02-gatewayserver | `INSTALLED` | 128Mi / 100m | Let's Encrypt + DNS-01 challenge — renueva automáticamente vía systemd timer | **ACTIVA** |
| 34 | `modsecurity` | S02-gatewayserver | `INSTALLED` | 256Mi / 200m | WAF ModSecurity OWASP CRS 4.x — protección SQLi, XSS, CSRF | **ACTIVA** |
| 35 | `kong` | S02-gatewayserver | `INSTALLED` | 1Gi / 500m | Kong 3.9.x LTS — API Gateway con backend PostgreSQL y plugin OIDC | **ACTIVA** |
| 36 | `nginx` | S02-gatewayserver | `INSTALLED` | 512Mi / 500m | Reverse proxy, TLS termination, HTTP/2, virtual hosts, wildcard cert | **ACTIVA** |
| 37 | `linkerd` | S00-hostserver | `INSTALL_FAILED` | 256Mi / 200m | mTLS automático entre pods, zero-trust inter-namespace | **REPOSO** |

---

## CAPA 4 — Daemons soberanos SBOS (systemd en el host)

> **Corren fuera de K8s como servicios systemd** — acceso directo al WAL via socket Unix.
> Dependen de: PostgreSQL (CAPA 1) + Vault (CAPA 2) + Keycloak + Kong (CAPA 3).
> **Este es el kernel del SBOS — sin daemons no hay integración soberana.**

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 38 | `sbos-bkernel` | S00-hostserver | `INSTALL_FAILED` | — | **bKernel** — CDC daemon: escucha WAL de PostgreSQL, normaliza y publica eventos a Redis Streams. Es el "kernel" del bus de eventos SBOS | **ACTIVA** |
| 39 | `sbos-bi18n` | S00-hostserver | `INSTALL_FAILED` | — | **bi18n** — Orquestador Universal de Internacionalización: formatos, monedas, fechas, ICU4X | **ACTIVA** |
| 40 | `bauth` | S03-identityserver | `INSTALLED` | 64Mi / 200m | **bAuth** — daemon soberano de identidad: BitMask 64-bit, token unificado, PDP de permisos | **ACTIVA** |
| 41 | `bnotify` | S03-identityserver | `INSTALL_FAILED` | — | **bNotify** — daemon Rust/gRPC de notificaciones soberanas: Push MFA, alertas del sistema | **ACTIVA** |
| 42 | `biedata` | S00-hostserver | `PENDIENTE` | — | **bIedata** — JSON-RPC 2.0 gateway entre daemons: aduana de datos soberana, depende de bAuth | **ACTIVA** |
| 43 | `bsearch` | S09-searchserver | `INSTALL_FAILED` | — | **bSearch** — motor de búsqueda soberano sobre PostgreSQL 18+ (full-text, vectorial, semántico) | **ACTIVA** |
| 44 | `bhnexus` | S02-gatewayserver | `INSTALL_FAILED` | 32Mi / 100m | **bHNexus** — proxy de hardware universal: puerta TLS mutual para clientes NFC/físicos (corre en host) | **ACTIVA** |
| 45 | `banexus` | S02-gatewayserver | `PENDIENTE` | 8Mi / 50m | **bANexus** — daemon edge: corre en el cliente Fedora (systemd --user), conecta a bhnexus | **ACTIVA** |
| 46 | `oauth2-proxy-gateway` | S02-gatewayserver | `INSTALL_FAILED` | — | OAuth2-Proxy en el gateway — valida tokens Keycloak antes de pasar a Kong | **ACTIVA** |
| 47 | `sbos-kong-tenant` | S02-gatewayserver | `INSTALLED` | — | Configura Kong por tenant: routes, services, plugins OIDC | **ACTIVA** |

---

## CAPA 4b — Infraestructura de soporte a daemons

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 48 | `sbos-lifecycle` | S00-hostserver | `INSTALLED` | 64Mi / 50m | BOS daemon como systemd — watchdog, startup reconcile, shutdown saga | **ACTIVA** |
| 49 | `sbos-security` | S00-hostserver | `PENDIENTE` | 32Mi / 25m | Scan CIS: hardening Ubuntu, K8s y verificación RBAC bosctl | **ACTIVA** |
| 50 | `sbos-repair` | S00-hostserver | `PENDIENTE` | 64Mi / 50m | Reparación multi-capa: Ubuntu → K8s → Fichas | **ACTIVA** |
| 51 | `sbos-package-manager` | S00-hostserver | `PENDIENTE` | 32Mi / 25m | Gestor multi-backend: apt + pip + helm — instala dependencias declarativas de fichas | **ACTIVA** |
| 52 | `sbos-notifier` | S06-appsserver | `INSTALL_FAILED` | — | Sistema de notificaciones universales SBOS — Push MFA, alertas, depende de bnotify | **ACTIVA** |

---

## CAPA 5 — Monitoreo (Prometheus · Grafana · Loki)

> Instalado antes de las aplicaciones para tener visibilidad durante el despliegue.

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 53 | `prometheus` | S12-monitorserver | `INSTALLED` | 2Gi / 500m | Métricas y alertas — retención 90d, scrape 30s, SLO recording rules | **ACTIVA** |
| 54 | `kube-state-metrics` | S12-monitorserver | `INSTALL_FAILED` | 128Mi / 50m | Exportador de métricas de objetos K8s → Prometheus | **ACTIVA** |
| 55 | `node-exporter` | S12-monitorserver | `INSTALL_FAILED` | 64Mi / 50m | Exportador de métricas del host: CPU/mem/disk/network → Prometheus | **ACTIVA** |
| 56 | `alertmanager` | S12-monitorserver | `INSTALLED` | 256Mi / 100m | Gestión de alertas: routing, silencing, inhibition | **ACTIVA** |
| 57 | `grafana` | S12-monitorserver | `INSTALLED` | 512Mi / 200m | Dashboards de observabilidad con backend PostgreSQL y auth OIDC | **ACTIVA** |
| 58 | `loki` | S12-monitorserver | `INSTALLED` | 512Mi / — | Loki 3.4.3 — agrega logs de Alloy, indexa y sirve a Grafana | **ACTIVA** |
| 59 | `alloy` | S12-monitorserver | `INSTALLED` | 256Mi / 100m | Colector de logs: journald + archivos → Loki (reemplaza Promtail) | **ACTIVA** |
| 60 | `tempo` | S12-monitorserver | `INSTALLED` | — | Trazado distribuido — recibe spans de apps, consultas desde Grafana | **ACTIVA** |

---

## CAPA 6 — ERP y negocio central (Tryton)

> **Tryton es la fuente de verdad del negocio.** Todo lo demás (RRHH, CRM, e-commerce) se
> integra con Tryton vía bKernel. Instalar Tryton antes que las apps que dependen de él.

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 61 | `tryton` | S04-erpserver | `INSTALLED` | 512Mi / 200m | Tryton ERP v8.0 — contabilidad, inventario, ventas. MDM hub vía bKernel | **ACTIVA** |
| 62 | `tryton-workers` | S04-erpserver | `INSTALLED` | 512Mi / — | Workers asíncronos de Tryton — informes, importaciones, tareas en cola | **ACTIVA** |
| 63 | `rabbitmq-erp` | S04-erpserver | `INSTALLED` | 512Mi / 200m | AMQP broker — desacopla Tryton ↔ Saleor/Airflow | **ACTIVA** |

---

## CAPA 7 — Nginx multi-tenant (puerta de entrada al VDI y a todas las apps)

> **Debe instalarse antes del VDI.** nginx multi-tenant es la puerta de entrada HTTP/HTTPS
> al escritorio Fedora KDE (vía guacamole), a nextcloud, onlyoffice y a todas las apps de
> cliente. Sin nginx multi-tenant operativo, el VDI y las apps no son accesibles desde el exterior.
> Depende de nginx base (CAPA 3) + certbot (CAPA 3).

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 64 | `nginx-multitenant` | S02-gatewayserver | `PENDIENTE` | 256Mi / 200m | Reverse proxy + TLS termination multi-tenant — puerta de entrada al VDI y apps de cliente | **ACTIVA** |
| 65 | `certbot` (multi-tenant) | S16-webserver | `PENDIENTE` | 128Mi / 100m | Gestor de certificados Let's Encrypt por dominio personalizado de cada cliente | **ACTIVA** |
| 66 | `modsecurity` (multi-tenant) | S16-webserver | `PENDIENTE` | 0 / 0 | WAF ModSecurity OWASP CRS 4.x para el nginx multi-tenant | **ACTIVA** |
| 67 | `nginx-web` | S00-hostserver | `INSTALLED` | 128Mi / 100m | Web institucional estática SBOS | **ACTIVA** |

---

## CAPA 8 — VDI y escritorio corporativo (Fedora KDE)

> **El VDI es la interfaz del usuario final.** fedora-kde + guacamole exponen el escritorio
> corporativo a través del nginx multi-tenant ya operativo (CAPA 7).
> nextcloud y onlyoffice son las primeras apps registradas en el desktop Fedora.
> Depende de: nginx multi-tenant (CAPA 7) + Keycloak (SSO) + bAuth (identidad) + PostgreSQL.

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 68 | `fedora-kde` | S11-vdiserver | `INSTALLED` | — | Fedora 44 + KDE Plasma 6 — escritorio corporativo soberano SBOS | **ACTIVA** |
| 69 | `guacamole` | S11-vdiserver | `INSTALLED` | 512Mi / 250m | Gateway VDI HTML5 — expone Fedora KDE en el navegador vía OIDC + nginx multi-tenant | **ACTIVA** |
| 70 | `nextcloud` | S11-vdiserver | `INSTALLED` | 1Gi / 500m | Archivos corporativos + CalDAV/CardDAV — **app nativa del desktop Fedora** | **ACTIVA** |
| 71 | `onlyoffice` | S11-vdiserver | `INSTALLED` | 1Gi / 500m | Suite ofimática colaborativa (3Gi limit real) — **integrada en Nextcloud y desktop** | **ACTIVA** |

---

## CAPA 9 — Aplicaciones de negocio (S06-appsserver)

> Instaladas después del VDI y del stack base. Dependen de Keycloak, Kong, PostgreSQL y bAuth.

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 72 | `directus` | S06-appsserver | `INSTALLED` | 256Mi / 200m | Headless CMS con API auto-generada sobre cualquier BD | **ACTIVA** |
| 73 | `wikijs` | S06-appsserver | `INSTALLED` | 256Mi / 200m | Base de conocimiento corporativa — **app del desktop Fedora** | **ACTIVA** |
| 74 | `vaultwarden` | S06-appsserver | `INSTALLED` | 128Mi / 100m | Gestor de contraseñas Bitwarden-compatible — **app del desktop Fedora** | **ACTIVA** |
| 75 | `trilium` | S06-appsserver | `INSTALLED` | 128Mi / 100m | Notas jerárquicas E2E encriptadas — **app del desktop Fedora** | **ACTIVA** |
| 76 | `openproject` | S06-appsserver | `INSTALLED` | 1Gi / 500m | PM formal: Gantt, WBS, OKRs | **ACTIVA** |
| 77 | `espocrm` | S06-appsserver | `UNKNOWN` | 256Mi / 200m | CRM: pipeline, leads, cuentas, contactos | **ACTIVA** |
| 78 | `orangehrm` | S06-appsserver | `INSTALL_FAILED` | 512Mi / 200m | RRHH: nómina, asistencia, gestión de personal | **ACTIVA** |
| 79 | `taiga` | S06-appsserver | `INSTALL_FAILED` | 512Mi / 500m | PM ágil: Scrum, Kanban | **REPOSO** |
| 80 | `zammad` | S06-appsserver | `UNKNOWN` | 512Mi / 500m | Help desk multi-canal con SLA | **REPOSO** |
| 81 | `calcom` | S06-appsserver | `INSTALLED` | 256Mi / 200m | Agendamiento multi-zona horaria | **REPOSO** |
| 82 | `easyappointments` | S06-appsserver | `UNKNOWN` | 256Mi / 200m | Agendamiento con sincronización CalDAV | **REPOSO** |
| 83 | `limesurvey` | S06-appsserver | `INSTALL_FAILED` | 256Mi / 200m | Encuestas NPS e investigación | **REPOSO** |
| 84 | `authelia` | S06-appsserver | `UNKNOWN` | 128Mi / 100m | MFA complementario, SSO forward-auth para NGINX | **REPOSO** |
| 85 | `saleor` | S06-appsserver | `INSTALL_FAILED` | 512Mi / 500m | E-commerce headless GraphQL | **REPOSO** |
| 86 | `tastyigniter` | S06-appsserver | `INSTALL_FAILED` | 256Mi / 200m | Plataforma de restaurante con menú QR | **REPOSO** |
| 87 | `gnuhealth` | S06-appsserver | `INSTALL_FAILED` | 1Gi / 500m | Hospital management / Historia Clínica Electrónica | **REPOSO** |

---

## CAPA 10 — Comunicaciones (mail · chat · VoIP)

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 88 | `stalwart` | S10-commsserver | `INSTALLED` | 2048Mi / 1000m | **Mail unificado soberano** (SMTP + IMAP + POP3 + anti-spam). Reemplaza postfix + dovecot | **ACTIVA** |
| 89 | `roundcube` | S10-commsserver | `INSTALLED` | 256Mi / 200m | Webmail con SSO via OAuth2-Proxy — **app del desktop Fedora** | **ACTIVA** |
| 90 | `clamav` | S10-commsserver | `INSTALLED` | 256Mi / 200m | Antivirus para adjuntos de correo | **ACTIVA** |
| 91 | `centrifugo` | S10-commsserver | `INSTALLED` | 256Mi / 200m | WebSocket pub/sub real-time con auth JWT JWKS | **ACTIVA** |
| 92 | `mattermost` | S10-commsserver | `INSTALLED` | 512Mi / 500m | Mensajería DevOps — **app del desktop Fedora** | **ACTIVA** |
| 93 | `postfix` | S10-commsserver | `INSTALLED` | 128Mi / 100m | SMTP con SPF, DKIM, DMARC — redundante con stalwart | **REPOSO** |
| 94 | `dovecot` | S10-commsserver | `INSTALLED` | 128Mi / 100m | IMAP/POP3 con buzones Maildir — redundante con stalwart | **REPOSO** |
| 95 | `postfixadmin` | S10-commsserver | `INSTALLED` | 256Mi / 200m | Admin web de dominios y buzones — solo si stalwart no cubre UI | **REPOSO** |
| 96 | `spamassassin` | S10-commsserver | `INSTALL_FAILED` | 256Mi / 200m | Filtro anti-spam bayesiano — redundante con stalwart anti-spam | **REPOSO** |
| 97 | `rocketchat` | S10-commsserver | `INSTALLED` | 512Mi / 500m | Chat con canales, video y archivos — alternativa a Mattermost | **REPOSO** |
| 98 | `cypht` | S10-commsserver | `INSTALLED` | 256Mi / 200m | Webmail multi-cuenta — alternativa ligera a Roundcube | **REPOSO** |
| 99 | `freepbx` | S10-commsserver | `UNKNOWN` | 512Mi / 500m | PBX/VoIP — central telefónica corporativa | **REPOSO** |

---

## CAPA 11 — Gestión documental y OCR (S08-docserver)

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 100 | `solr` | S08-docserver | `INSTALLED` | 1Gi / 500m | Búsqueda full-text backend para DMS | **ACTIVA** |
| 101 | `paperless-ngx` | S08-docserver | `INSTALLED` | 512Mi / 500m | DMS: OCR, clasificación ML, búsqueda full-text — **app del desktop Fedora** | **ACTIVA** |
| 102 | `docuseal` | S08-docserver | `INSTALLED` | 256Mi / 200m | Firmas digitales multi-firmante | **ACTIVA** |
| 103 | `tesseract` | S08-docserver | `INSTALL_FAILED` | 256Mi / 200m | OCR 100+ idiomas — dependencia de paperless-ngx | **ACTIVA** |
| 104 | `kimios` | S08-docserver | `DESCARTADO` | 512Mi / 500m | DMS con BPM y flujos — reemplazado por paperless-ngx | **ELIMINAR** |
| 105 | `tabula` | S08-docserver | `INSTALL_FAILED` | 128Mi / 100m | Extrae tablas de PDF a CSV/XLSX | **REPOSO** |
| 106 | `camelot` | S08-docserver | `UNKNOWN` | 128Mi / 100m | Extracción compleja de PDF | **REPOSO** |

---

## CAPA 12 — Reporting e inteligencia de negocio (S07-reportserver)

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 107 | `jasperstarter` | S07-reportserver | `INSTALLED` | 128Mi / 100m | Generación masiva batch de reportes JasperReports | **ACTIVA** |
| 108 | `pdfjs` | S07-reportserver | `INSTALLED` | 64Mi / 50m | Visor PDF embebido — **app del desktop Fedora** | **ACTIVA** |
| 109 | `jaspersoft` | S07-reportserver | `INSTALL_FAILED` | 256Mi / 200m | Reportes fiscales Bolivia PUCT/SIN | **REPOSO** |
| 110 | `openmetadata` | S07-reportserver | `INSTALLED` | 1Gi / 500m | Catálogo de datos, linaje, gobierno de datos | **REPOSO** |
| 111 | `superset` | S07-reportserver | `UNKNOWN` | 1Gi / 500m | BI: visualizaciones, KPIs, dashboards | **REPOSO** |
| 112 | `airflow` | S07-reportserver | `UNKNOWN` | 1Gi / 500m | ETL DAGs, sincronizaciones, pipelines de datos | **REPOSO** |

---

## CAPA 13 — Seguridad y compliance (S03-identityserver)

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 113 | `wazuh-manager` | S03-identityserver | `INSTALLED` | 2Gi / 1000m | SIEM/XDR: análisis de logs, integridad de archivos, detección vulnerabilidades | **REPOSO** |
| 114 | `wazuh-indexer` | S03-identityserver | `INSTALL_FAILED` | 2Gi / 1000m | Nodo indexer Wazuh (fork OpenSearch) — requiere 2Gi RAM | **REPOSO** |
| 115 | `openvas` | S03-identityserver | `INSTALL_FAILED` | 512Mi / 500m | Scanner de vulnerabilidades: CVE, puertos abiertos, misconfigurations | **REPOSO** |

---

## CAPA 14 — Búsqueda avanzada (S09-searchserver)

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 116 | `elasticsearch` | S09-searchserver | `INSTALLED` | 2Gi / 1000m | Backend de logs para Wazuh, búsqueda full-text complementaria | **REPOSO** |

---

## CAPA 15 — Geo y tracking (S13-geoserver)

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 117 | `traccar` | S13-geoserver | `INSTALLED` | 256Mi / 200m | Tracking GPS — 200+ protocolos de dispositivos | **REPOSO** |
| 118 | `fleetbase` | S13-geoserver | `INSTALL_FAILED` | 256Mi / 200m | Dispatch, conductores, gestión de flota | **REPOSO** |
| 119 | `xibo` | S13-geoserver | `UNKNOWN` | 256Mi / 200m | Señalización digital (digital signage) | **REPOSO** |
| 120 | `novosga` | S13-geoserver | `UNKNOWN` | 256Mi / 200m | Gestión de colas multi-sucursal | **REPOSO** |
| 121 | `cardmesh` | S13-geoserver | `UNKNOWN` | 256Mi / 200m | vCards NFC/QR (MIT SKULL) | **REPOSO** |

---

## CAPA 16 — Operaciones y CI/CD (S14-opsserver)

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 122 | `bareos` | S14-opsserver | `INSTALL_FAILED` | 512Mi / 500m | Backup de 16 servidores con cifrado AES-256 | **ACTIVA** |
| 123 | `goss` | S14-opsserver | `INSTALLED` | 64Mi / 50m | Validación de integridad de backups | **ACTIVA** |
| 124 | `searxng` | S14-opsserver | `INSTALLED` | 128Mi / 100m | Motor de búsqueda meta soberano — **app del desktop Fedora** | **ACTIVA** |
| 125 | `pgbackrest-svc` | S14-opsserver | `UNKNOWN` | 128Mi / 100m | Backup PITR de PostgreSQL a MinIO con scheduling | **ACTIVA** |
| 126 | `trivy` | S14-opsserver | `UNKNOWN` | 256Mi / 200m | Escaneo CVE de contenedores y K8s | **REPOSO** |
| 127 | `velero` | S14-opsserver | `UNKNOWN` | 256Mi / 200m | Disaster recovery de K8s — snapshots a MinIO | **REPOSO** |
| 128 | `gitlab` | S14-opsserver | `DESCARTADO` | 4Gi / 2000m | SCM + CI/CD + Container Registry — requiere 4Gi RAM | **REPOSO** |
| 129 | `k6` | S14-opsserver | `UNKNOWN` | 128Mi / 100m | Load testing y benchmarks | **REPOSO** |

---

## CAPA 17 — Inteligencia artificial (S15-aiserver)

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 130 | `qdrant` | S15-aiserver | `INSTALLED` | 1Gi / 500m | Vector DB para embeddings RAG | **ACTIVA** |
| 131 | `open-webui` | S15-aiserver | `INSTALLED` | 512Mi / 200m | UI tipo ChatGPT multi-tenant con RAG — **app del desktop Fedora** | **ACTIVA** |
| 132 | `langfuse` | S15-aiserver | `INSTALLED` | 256Mi / 200m | Observabilidad de LLMs: trazas, costos, evaluaciones | **ACTIVA** |
| 133 | `flowise` | S15-aiserver | `INSTALLED` | 256Mi / 200m | Constructor visual de agentes IA, low-code | **ACTIVA** |
| 134 | `ollama` | S15-aiserver | `PENDIENTE` | 4Gi / 2000m | Runtime local de LLMs (llama, mistral, deepseek) — requiere GPU idealmente | **REPOSO** |
| 135 | `embedding-worker` | S15-aiserver | `UNKNOWN` | 256Mi / 200m | Worker de embeddings: ai:embed_queue → Qdrant (MIT SKULL) | **REPOSO** |
| 136 | `bcompass-svc` | S15-aiserver | `UNKNOWN` | 256Mi / 200m | Route Engine + HITL (MIT SKULL) | **REPOSO** |

---

## CAPA 18 — Mantenimiento del host (ciclo largo)

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 137 | `k8s-upgrader` | S00-hostserver | `INSTALLED` | 128Mi / 100m | Actualizaciones rolling K8s con cordon/drain | **ACTIVA** |
| 138 | `sbos-bootstrap-hardening` | S00-hostserver | `PENDIENTE` | 128Mi / 100m | Hardening CIS completo: kernel params, auditd, AppArmor, firewalld | **ACTIVA** |
| 139 | `cert-rotation` | S00-hostserver | `PENDIENTE` | 128Mi / 100m | Rotación TLS cada 90 días vía Let's Encrypt + Vault | **ACTIVA** |
| 140 | `compliance-check` | S00-hostserver | `PENDIENTE` | 128Mi / 100m | Auditoría semanal kube-bench CIS + Trivy CVEs | **ACTIVA** |
| 141 | `zabbix` | S12-monitorserver | `INSTALLED` | — | Zabbix 7.2 LTS — monitoreo de infraestructura legada | **REPOSO** |

---

## CAPA 19 — Smart apps SKULL (S05-devserver)

> Aplicaciones propietarias MIT SKULL. Instalar solo cuando el cliente lo requiere.

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 142 | `smarttax` | S05-devserver | `PENDIENTE` | 256Mi / 200m | Cumplimiento fiscal BO/AR/MX | **REPOSO** |
| 143 | `smartreport` | S05-devserver | `PENDIENTE` | 256Mi / 200m | BI y reporting avanzado (MIT SKULL) | **REPOSO** |
| 144 | `smartorc` | S05-devserver | `PENDIENTE` | 256Mi / 200m | Gestión de correspondencia (MIT SKULL) | **REPOSO** |
| 145 | `smartvaultflow` | S05-devserver | `PENDIENTE` | 256Mi / 200m | Bóveda de documentos + workflow (MIT SKULL) | **REPOSO** |
| 146 | `smartportfolio` | S05-devserver | `PENDIENTE` | 256Mi / 200m | Generador de catálogos (MIT SKULL) | **REPOSO** |
| 147 | `smartrates` | S05-devserver | `PENDIENTE` | 256Mi / 200m | Motor de precios dinámicos (MIT SKULL) | **REPOSO** |
| 148 | `smartpay` | S05-devserver | `PENDIENTE` | 256Mi / 200m | Gateway de pagos QR (MIT SKULL) | **REPOSO** |

---

## CAPA 20 — Blockchain (solo proyectos específicos)

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 149 | `besu-qbft` | S02-gatewayserver | `INSTALLED` | — | Hyperledger Besu 24.12.0 — red blockchain QBFT soberana (4 nodos) | **REPOSO** |

---

## CAPA 21 — Web multi-idioma (S16-webserver)

| # | Ficha | Servidor lógico | Estado VPS | RAM / CPU | Descripción | Decisión |
|---|-------|----------------|-----------|-----------|-------------|----------|
| 150 | `weblate` | S16-webserver | `PENDIENTE` | 1Gi / 500m | Plataforma self-hosted para editar archivos FTL/Fluent de bi18n | **REPOSO** |

---

## Fichas obsoletas / ELIMINAR

| Ficha | Servidor lógico | Motivo |
|-------|----------------|--------|
| `trilium-notes` | S08-docserver | Duplicado exacto de `trilium` (S06) — mismo producto, dos fichas |
| `tesseract-ocr` | S08-docserver | Duplicado de `tesseract` (S08) — mismo motor OCR |
| `mailserver` | S10-commsserver | docker-mailserver reemplazado por `stalwart` (mail unificado SMTP+IMAP+anti-spam) |
| `rabbitmq` | S09-searchserver | Tercera instancia RabbitMQ — ya existen `rabbitmq-erp` y `rabbitmq-search`; bsearch usa PG18 nativo |
| `rabbitmq-search` | S09-searchserver | bSearch usa PostgreSQL 18 nativo, no necesita cola AMQP separada |
| `novu` | S06-appsserver | Reemplazado por `bnotify` (daemon SBOS soberano) |
| `kimios` | S08-docserver | Reemplazado por paperless-ngx (ya en cronograma como Descartado) |
| `ferretdb` | _descartadas | Ya en carpeta _descartadas — duplicado de MongoDB |
| `sbos-bootstrap-hard` | _descartadas | Ya en carpeta _descartadas — reemplazada por sbos-bootstrap-hardening |

---

## Resumen ejecutivo

| Categoría | Cantidad |
|---|---|
| Fichas **ACTIVA** (núcleo de producción) | 70 |
| Fichas **REPOSO** (activar por demanda) | 47 |
| Fichas **ELIMINAR** (borrar del repo) | 9 |
| **Total fichas activas en repo** | **126** |

### Estado actual VPS prueba (ciclo 58 — 2026-10-20)

| Estado | Cantidad |
|---|---|
| `INSTALLED` | 82 |
| `INSTALL_FAILED` | 24 |
| `READY` | 31 |
| `PENDING` | 20 |
| `PHYSICAL_ERROR` | 1 |

### Fichas ACTIVAS con fallo — orden de reparación

| Prioridad | Ficha | Bloqueo |
|---|---|---|
| 🔴 P1 | `vault-unsealer` | Vault ya instalado — solo resetear a READY |
| 🔴 P1 | `kube-state-metrics` | Archivos en blibs OK — resetear a READY |
| 🔴 P1 | `node-exporter` | Archivos en blibs OK — resetear a READY |
| 🔴 P1 | `sbos-bkernel` | Binario `bkernel-daemon` no disponible — crear o desactivar |
| 🔴 P1 | `sbos-bi18n` | Binario `bi18nd` no disponible — crear o desactivar |
| 🔴 P1 | `bnotify` | Dependencias Rust de compilación pendientes |
| 🔴 P1 | `oauth2-proxy-gateway` | Verificar config Keycloak y secret |
| 🔴 P1 | `bhnexus` | Verificar imagen y configuración |
| 🟠 P2 | `bsearch` | Verificar dependencias PG18 |
| 🟠 P2 | `sbos-notifier` | Verificar BASH_SOURCE guard (fix ya aplicado) |
| 🟠 P2 | `orangehrm` | Verificar config MySQL + Secret |
| 🟠 P2 | `bareos` | Verificar storage config |
| 🟡 P3 | `tesseract` | Imagen disponible — reintentar |

### RAM disponible en VPS de prueba (6 cores / 11GB)
La VPS de prueba está al 98% de RAM. Para continuar instalando fichas ACTIVAS faltantes:

```bash
# Escalar a 0 fichas REPOSO que consumen RAM:
kubectl scale statefulset/besu-qbft -n sbos-blockchain --replicas=0   # ~362MB
kubectl scale deployment/traccar -n sbos-geo --replicas=0              # ~768MB
kubectl scale deployment/onlyoffice -n sbos-vdi --replicas=0           # ~1GB+
# Total liberable: ~2GB — suficiente para instalar daemons faltantes
```
