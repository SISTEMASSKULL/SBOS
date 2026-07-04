# SBOS-005-STACK
## Catalogo del Stack Tecnologico — Estandar HUMAN-DOC (Enriquecido V8)
### SKULL · SBOS v1.0-V8 · Mayo 2026

---

## 1. Premisas de Seleccion

Toda aplicacion candidata al stack SBOS debe satisfacer 5 criterios obligatorios:

1. **Autenticacion delegable a Keycloak:** OIDC/SAML nativo o adaptable via OAuth2-Proxy
2. **Compatibilidad con PostgreSQL:** Motor principal. Excepciones MySQL solo si no existe soporte PG nativo (FreePBX, OrangeHRM, Easy!Appointments) — requieren SymmetricDS
3. **Licencia libre OSI-approved:** $0 en licenciamiento, codigo fuente auditable, sin restricciones comerciales por usuarios/instancias/ingresos, sin clausulas "fair use" o "sustainable use"
4. **Interoperabilidad:** API REST/GraphQL, webhooks, protocolos estandar
5. **Empaquetable como ficha SBOS:** manifest.yml + yaml_engine.yml + resources/

### Licencias aprobadas
MIT, Apache 2.0, GPL v2/v3, LGPL, MPL 2.0, BSD (2/3-clause), AGPL v3, ISC, PostgreSQL License, Zlib.

### Licencias NO aceptables
BSL (Business Source License), Sustainable Use License, Commons Clause, SSPL con restricciones, cualquier "source available" no OSI.

### Excepciones evaluadas y aceptadas
HashiCorp Vault (BSL 1.1): autoalojamiento libre, restriccion solo en servicios gestionados. Elasticsearch 8 (Elastic License 2.0): misma situacion. Directus (BSL 1.1): misma situacion. Aceptables para uso propio del cliente.

## 2. Resumen del Stack

| Dimension | Valor |
|---|---|
| Servidores logicos | 16 (S-HOST + S01–S15) |
| Aplicaciones catalogadas | 110+ (variable por cliente) |
| Licenciamiento | $0 USD |
| Persistencia principal | PostgreSQL 17 + Patroni HA 3 nodos |
| IAM / RBAC | Keycloak 26.x (OIDC, SAML, MFA, multi-tenant) |
| Observabilidad | LGTM stack + Zabbix + Wazuh |
| DR | pgBackRest (PITR) + Bareos + Velero |
| Tiempo real | Centrifugo OSS + Redis pub/sub |
| API Gateway | Kong OSS + NGINX + ModSecurity WAF |
| Orquestacion soberana | bCompass (MIT, SKULL) |
| IA soberana | Ollama + Open WebUI + Qdrant |
| Daemons soberanos | 8 (Rust + Go, systemd fuera K8s) |

## 3. Los 16 Servidores Logicos con Aplicaciones Completas

### S-HOST — hostserver (Fichas Tipo 1 — bash/systemd)

| # | App | Licencia | BD | Auth KC | Funcion |
|---|---|---|---|---|---|
| 1 | sbos-bootstrap | MIT (SKULL) | — | — | Hardening Ubuntu + CRI-O + kubeadm |
| 2 | sbos-k8s-upgrader | MIT (SKULL) | — | — | Upgrades K8s rolling |
| 3 | sbos-cert-rotation | MIT (SKULL) | — | — | Renovacion TLS cada 90 dias |
| 4 | sbos-compliance-check | MIT (SKULL) | — | — | kube-bench CIS semanal |
| 5 | sbos-nginx-web | MIT (SKULL) | — | — | Web institucional (criticality: false) |

### S01 — dataserver (Persistencia)

| # | App | Version | Licencia | BD propia | Auth KC | Funcion |
|---|---|---|---|---|---|---|
| 1 | PostgreSQL | 17 | PostgreSQL Lic. | — (es el motor) | N/A | Motor SQL principal 90%+ apps. ACID, MVCC, WAL |
| 2 | Patroni | — | MIT | etcd (DCS) | N/A | HA 3 nodos, failover <30s |
| 3 | PgBouncer | — | ISC | — | N/A | Connection pool — reduce overhead multi-pod |
| 4 | pgBackRest | — | MIT | — | N/A | PITR backup desde replica |
| 5 | TimescaleDB | ext | Apache 2.0 CE | — | N/A | Series de tiempo (metricas negocio, IoT) |
| 6 | pg_partman | ext | PG License | — | N/A | Particionado automatico por tiempo |
| 7 | pg_stat_monitor | ext | BSD 3 | — | N/A | Monitoreo queries avanzado |
| 8 | Citus | ext | AGPL v3 | — | N/A | Sharding horizontal (analiticos) |
| 9 | Redis | 7 | BSD 3 | — | N/A | Cache, sesiones, broker Celery/Centrifugo. DB0/DB1/DB2 |
| 10 | MinIO | — | AGPL v3 | — | N/A | Object storage S3. Backend Loki, Bareos, Paperless, Ollama |
| 11 | MySQL | 8 | GPL v2 | — | N/A | BD secundaria: FreePBX, OrangeHRM, Easy!Appointments. criticality: false |
| 12 | SymmetricDS | — | GPL v3 | — | N/A | CDC bidireccional PG↔MySQL |
| 13 | PgAdmin 4 | — | PG License | — | OAuth2-Proxy | Admin UI PostgreSQL |

### S02 — gatewayserver (Ingress + Seguridad perimetral)

| # | App | Version | Licencia | BD | Auth KC | Funcion |
|---|---|---|---|---|---|---|
| 1 | NGINX | — | BSD 2 | — | N/A | Reverse proxy, TLS termination |
| 2 | Certbot | — | Apache 2.0 | — | N/A | Certificados Let's Encrypt auto-renovables |
| 3 | ModSecurity + OWASP CRS | — | Apache 2.0 | — | N/A | WAF: SQLi, XSS, CSRF, path traversal |
| 4 | Kong Gateway OSS | — | Apache 2.0 | kong (PG) | JWT validate | API Gateway: JWT, rate-limit, CORS, ACL, OIDC |
| 5 | HashiCorp Vault | — | BSL 1.1 ⚠ | vault (PG) | AppRole | Secrets dinamicos TTL corto. Fuente de verdad secrets post-bootstrap |

### S03 — identityserver (IAM + SIEM + Service Mesh)

| # | App | Version | Licencia | BD | Auth KC | Funcion |
|---|---|---|---|---|---|---|
| 1 | Keycloak | 26.x | Apache 2.0 | keycloak (PG) | ES el IdP | SSO OIDC/SAML, MFA, multi-tenant por realm |
| 2 | OAuth2-Proxy | — | MIT | — | JWT | Auth proxy para apps sin OIDC nativo |
| 3 | Wazuh | 4.10+ | GPL v2 | — (Elasticsearch) | N/A | SIEM/XDR, DaemonSet todos los nodos |
| 4 | OpenVAS/Greenbone | — | GPL v2 | — | OIDC | Vulnerability scanner programado |
| 5 | Linkerd | — | Apache 2.0 | — | N/A | mTLS automatico inter-pod |
| 6 | Network Policies | — | (Calico) | — | N/A | Deny-by-default entre namespaces |

### S04 — erpserver (Aislamiento Critical Path)

| # | App | Version | Licencia | BD | Auth KC | Funcion |
|---|---|---|---|---|---|---|
| 1 | Tryton ERP | — | GPL v3 | tryton (PG) | OIDC | Contabilidad, inventario, ventas, compras. Hub MDM bKernel |
| 2 | RabbitMQ | 3.13+ | MPL 2.0 | — | N/A | AMQP. Desacoplamiento Tryton↔Saleor/Airflow |

### S05 — devserver (Proyectos SKULL — todos MIT)

| # | App | Licencia | Funcion |
|---|---|---|---|
| 1 | SmartTax | MIT (SKULL) | Tax compliance BO/AR/MX — firma XML, envio SIN/AFIP/SAT |
| 2 | SmartReport | MIT (SKULL) | BI avanzado y reporteria |
| 3 | SmartRates | MIT (SKULL) | Pricing engine dinamico |
| 4 | SmartORC | MIT (SKULL) | Correspondence — recepcion y respuesta al cliente |
| 5 | SmartVaultFlow | MIT (SKULL) | Document vault seguro + workflow |
| 6 | SmartPortfolio | MIT (SKULL) | Catalogo generator desde PDFs |
| 7 | SmartPay | MIT (SKULL) | Payment gateway QR + orquestacion pagos |

### Smart* Enriquecimiento — Detalle tecnologico por subproyecto

Cada subproyecto Smart* corre en S05 devserver y se implementa como ficha SBOS con su propio stack interno:

| Subproyecto | Stack interno | BD | Runtime | Puertos |
|---|---|---|---|---|
| SmartPay | Medusa 2.x (Node.js 22 LTS) | bpay_db (PG) + Redis | Node.js | 28100-28110 |
| SmartORC | Python 3.12 + FastAPI | borc_db (PG) | Python | 28120-28130 |
| SmartVaultFlow | Python 3.12 + FastAPI | bvault_db (PG) | Python | 28140-28150 |
| SmartTax | PHP 8.2 + CodeIgniter | btax_db (PG) | PHP-FPM | 28160-28170 |
| SmartRates | Go 1.22 | brates_db (PG) | Go binary | 28180 |

### S06 — appsserver (Apps de negocio)

| # | App | Version | Licencia | BD | Auth KC | Funcion |
|---|---|---|---|---|---|---|
| 1 | GNU Health | 4.4+ | GPL v3 | gnuhealth (PG) | OIDC | Salud/EHR. Cert OPS/OMS. criticality: false |
| 2 | Saleor | — | BSD 3 | saleor (PG) | OIDC | E-Commerce headless GraphQL |
| 3 | Directus | 11+ | BSL 1.1 ⚠ | directus (PG) | OIDC | CMS headless, API auto-generada |
| 4 | TastyIgniter | 3.7+ | MIT | tastyigniter (PG) | OIDC | Restaurantes, QR mesa. criticality: false |
| 5 | Easy!Appointments | 1.5+ | GPL v3 | easyappt (MySQL) | OAuth2-Proxy | Agendamiento CalDAV sync |
| 6 | OrangeHRM | 6.0+ | GPL v2 CE | orangehrm (MySQL) | OIDC | RRHH: nomina, asistencia, evaluaciones |
| 7 | Wiki.js | 3.0+ | AGPL v3 | wikijs (PG) | OIDC | Knowledge base colaborativa |
| 8 | Trilium Notes | — | AGPL v3 | — (SQLite) | OIDC | Notas jerarquicas E2E cifradas |
| 9 | EspoCRM | 8.0+ | GPL v3 | espocrm (PG) | OIDC | CRM: pipeline, leads, email marketing |
| 10 | Taiga | 6.7+ | MPL 2.0 | taiga (PG) | OIDC | PM Agile: Scrum, Kanban |
| 11 | OpenProject | 14+ | GPL v3 | openproject (PG) | OIDC | PM Formal: Gantt, WBS, OKRs |
| 12 | Cal.com | 2.0+ | AGPL v3 | calcom (PG) | OIDC | Scheduling multi-timezone |
| 13 | Zammad | 6.4+ | GPL v3 | zammad (PG) | OIDC | Help desk multicanal + SLA |
| 14 | LimeSurvey | 6.0+ | GPL v2 | limesurvey (PG) | OIDC | Encuestas NPS + logica condicional |
| 15 | Authelia | — | Apache 2.0 | — | N/A | MFA complementario para apps legacy |
| 16 | Vaultwarden | — | AGPL v3 | vaultwarden (PG) | OIDC | Gestor contrasenas corporativo. AES-256 E2E |

### S07 — reportserver (BI + ETL)

| # | App | Version | Licencia | BD | Auth KC | Funcion |
|---|---|---|---|---|---|---|
| 1 | JasperSoft Studio | 6.18.1 CE | LGPL | — | N/A | Reportes fiscales Bolivia PUCT/SIN |
| 2 | JasperStarter | 3.6.2 | LGPL | — | N/A | Generacion batch masiva |
| 3 | PDF.js | — | Apache 2.0 | — | N/A | Visor PDF embebido |
| 4 | Superset | 4.1+ | Apache 2.0 | superset (PG) | OIDC | BI: 40+ visualizaciones, KPIs tiempo real |
| 5 | Airflow | 2.10+ | Apache 2.0 | airflow (PG) | OIDC | ETL, DAGs, sincronizaciones batch |
| 6 | OpenMetadata | 1.6+ | Apache 2.0 | openmetadata (PG) | OIDC | Catalogo datos, linaje, calidad |

### S08 — docserver (DMS + OCR + Firma)

| # | App | Version | Licencia | BD | Auth KC | Funcion |
|---|---|---|---|---|---|---|
| 1 | Paperless-NGX | — | GPL v3 | paperless (PG) | OIDC | DMS: OCR, clasificacion ML, full-text |
| 2 | Tesseract+EasyOCR | — | Apache 2.0 | — | N/A | 100+ idiomas inc. quechua/aymara |
| 3 | Tabula | — | MIT | — | N/A | PDF tables → CSV/XLSX |
| 4 | Camelot | — | MIT | — | N/A | PDFs complejos lattice/stream |
| 5 | Kimios DMS | 1.3+ | LGPL v2.1 | — | OIDC | BPM documental, versionado |
| 6 | Apache Solr | 9.0+ | Apache 2.0 | — | N/A | Full-text backend Kimios |
| 7 | DocuSeal | 1.7+ | AGPL v3 | docuseal (PG) | OIDC | Firma digital multi-firmante |

### S09 — searchserver

| # | App | Version | Licencia | BD | Auth KC | Funcion |
|---|---|---|---|---|---|---|
| 1 | Elasticsearch | 8.16+ | Elastic Lic. 2.0 ⚠ | — | N/A | Logs Wazuh, busqueda unificada |
| 2 | RabbitMQ | 3.13+ | MPL 2.0 | — | N/A | AMQP (tambien en S04 — SLAs diferentes) |

### S10 — commsserver (Correo + VoIP + Mensajeria)

| # | App | Version | Licencia | BD | Auth KC | Funcion |
|---|---|---|---|---|---|---|
| 1 | Postfix | — | Postfix Lic. | — | N/A | MTA: SPF, DKIM, DMARC |
| 2 | Dovecot | — | MIT/LGPL | — | N/A | IMAP/POP3 buzones |
| 3 | Roundcube | — | GPL v3 | roundcube (PG) | OAuth2-Proxy | Webmail SSO |
| 4 | Cypht | — | GPL v2 | — | OAuth2-Proxy | Webmail multi-cuenta |
| 5 | PostfixAdmin | — | GPL v2 | postfixadmin (PG) | OAuth2-Proxy | Admin dominios/buzones |
| 6 | SpamAssassin | — | Apache 2.0 | — | N/A | Anti-spam bayesiano |
| 7 | ClamAV+Amavis | — | GPL v2 | — | N/A | Antivirus adjuntos |
| 8 | FreePBX+Asterisk | 17/21 | GPL v2 CE | asterisk (MySQL) | OAuth2-Proxy | PBX/VoIP. criticality: false |
| 9 | Rocket.Chat | 6.0+ | MIT | rocketchat (MongoDB) | OIDC | Messaging: canales, video, webhooks |
| 10 | Mattermost | 9.0+ | MIT TE | mattermost (PG) | OIDC | Messaging DevOps: playbooks, alertas |
| 11 | Centrifugo | v6 OSS | Apache 2.0 | — (Redis) | JWT JWKS | WebSocket pub/sub tiempo real |

### S11 — vdiserver (Escritorio Virtual)

| # | App | Version | Licencia | BD | Auth KC | Funcion |
|---|---|---|---|---|---|---|
| 1 | Fedora KDE Plasma | 43 | GPL/LGPL | — | bAuth+banexus | Desktop soberano PEP |
| 2 | Nextcloud Files | — | AGPL v3 | nextcloud (PG) | OIDC | Archivos + CalDAV/CardDAV |
| 3 | OnlyOffice Docs | — | AGPL v3 | onlyoffice (PG) | OIDC | Office suite colaborativa |

### S12 — monitorserver (Observabilidad)

| # | App | Version | Licencia | BD | Auth KC | Funcion |
|---|---|---|---|---|---|---|
| 1 | Prometheus | — | Apache 2.0 | — (TSDB) | N/A | Scraping metricas. Retencion 90d |
| 2 | Grafana OSS | — | AGPL v3 | grafana (PG) | OIDC | Dashboards unificados metricas/logs/trazas |
| 3 | Alertmanager | — | Apache 2.0 | — | N/A | Alerting base → Mattermost/email |
| 4 | Loki | — | AGPL v3 | — (MinIO) | N/A | Log aggregation con labels K8s |
| 5 | Grafana Alloy | — | Apache 2.0 | — | N/A | DaemonSet unificado (reemplaza Promtail) |
| 6 | Tempo | — | AGPL v3 | — (MinIO) | N/A | Tracing OpenTelemetry |
| 7 | Zabbix | 7.0+ | GPL v2 | zabbix (PG) | OAuth2-Proxy | Infra monitoring OS 16 servidores |
| 8 | Portainer CE | — | Zlib | — (BoltDB) | OAuth2-Proxy | Container mgmt visual |

### S13 — geoserver (GPS + Logistica + Signage)

| # | App | Version | Licencia | BD | Auth KC | Funcion |
|---|---|---|---|---|---|---|
| 1 | Traccar | 6.5+ | Apache 2.0 | traccar (PG) | OIDC | GPS 200+ protocolos. criticality: false |
| 2 | Fleetbase+FleetOps | — | MIT | fleetbase (PG) | OIDC | Despacho, conductores, POD |
| 3 | Xibo CMS | 4.1+ | AGPL v3 | xibo (PG) | OIDC | Signage digital. criticality: false |
| 4 | Novo SGA | 2.1+ | MIT | novosga (PG) | OIDC | Gestion turnos multi-sucursal |
| 5 | CardMesh | — | MIT (SKULL) | cardmesh (PG) | OIDC | vCards NFC/QR, sync EspoCRM |

### S14 — opsserver (CI/CD + Backup + DR)

| # | App | Version | Licencia | BD | Auth KC | Funcion |
|---|---|---|---|---|---|---|
| 1 | GitLab CE | 17.8+ | MIT CE | gitlab (PG) | OIDC | SCM + CI/CD + Container Registry |
| 2 | K6 | — | AGPL v3 | — | N/A | Load testing pre-deploy |
| 3 | Trivy | — | Apache 2.0 | — | N/A | Security scan CVEs imagenes + YAML |
| 4 | Bareos | 23+ | AGPL v3 | bareos (PG) | N/A | Backup 16 servidores. AES-256. MinIO backend |
| 5 | Velero | — | Apache 2.0 | — (MinIO) | N/A | K8s DR snapshots cada 4h |
| 6 | Goss | — | Apache 2.0 | — | N/A | Validation: integridad backups, smoke tests |
| 7 | pgBackRest | — | MIT | — (MinIO) | N/A | PG backup PITR |
| 8 | SearXNG | — | AGPL v3 | — | OIDC | Metabuscador soberano 229+ motores. Backend RAG |

Se instala AL FINAL — necesita todo el stack para backup.

### S15 — aiserver (IA Soberana — opcional)

| # | App | Version | Licencia | BD | Auth KC | Funcion |
|---|---|---|---|---|---|---|
| 1 | Ollama | — | MIT | — | N/A | LLM runtime local. API OpenAI-compatible |
| 2 | Open WebUI | — | MIT | — | OIDC | UI ChatGPT-like multi-tenant |
| 3 | Qdrant | — | Apache 2.0 | — (Raft) | N/A | Vector DB para RAG. Colecciones por realm |
| 4 | Embedding Worker | — | MIT (SKULL) | — | N/A | Consume ai:embed_queue bKernel → Qdrant |
| 5 | Langfuse | — | MIT | langfuse (PG) | OIDC | Observabilidad LLM: trazas, prompts, scores |
| 6 | Flowise | — | Apache 2.0 | — | OIDC | Constructor visual agentes (prototipado) |
| 7 | bCompass | — | MIT (SKULL) | bcompass_db (PG) | N/A | Route Engine + Langfuse + HITL |

Modelos: Qwen3 (Apache 2.0) principal. DeepSeek-R1 destilados (MIT) razonamiento.
Hardware: CPU-only = 64GB RAM min para 32B Q4. GPU NVIDIA recomendada produccion.

## 4. Daemons Soberanos (systemd host — fuera de K8s)

| Daemon | Servicio | Lenguaje | Razon fuera de K8s | BD propia |
|---|---|---|---|---|
| IAM Installer | bos.service | Go | Guardian del SO, no depende de K8s | bos_db |
| bKernel | bkernel.service | Rust | Acceso WAL via socket Unix <50us | bkernel_db |
| biedata | biedata.service | Rust | Escritura coordinada con antiloop WAL | biedata_db |
| bCompass | bcompass.service | Go | Ciclo vida independiente K8s | bcompass_db |
| bSearch | bsearch.service | Go | Acceso WAL para indexacion | — |
| bAuth | bauth.service | Go | Acceso WAL para identidad | bauth_db |
| bhnexus | bhnexus.service | Go | Broker hardware, WebSocket mTLS | — |
| banexus | banexus.service (--user) | Go | Edge sentinel en Fedora VDI | — |

Rust para CPU-bound (WAL parsing, rule engine). Go para I/O-bound (WebSocket, HTTP, concurrencia).

## 5. Herramientas Prohibidas

| Componente | Razon del veto |
|---|---|
| n8n | Sustainable Use License — no OSI. Reemplazado por bCompass (MIT) |
| Docker | Vetado — exclusivamente Podman/OCI |
| Kasm Workspaces | Eliminado — SBOS VDI usa Fedora KDE nativo con bAuth+banexus |
| Cualquier "Source Available" no OSI | Viola principio P9 |

## 6. Reemplazos Cloud → Soberano

| Servidor | Reemplaza | Ahorro estimado |
|---|---|---|
| dataserver | AWS RDS, Cloud SQL, Azure DB | |
| gatewayserver | Cloudflare, AWS ALB | |
| identityserver | Auth0, Okta, Azure AD | |
| erpserver | SAP B1, Dynamics, Netsuite | |
| appsserver | Salesforce, Zendesk, Monday | |
| reportserver | Tableau, Power BI, Looker | |
| docserver | DocuSign, SharePoint | |
| commsserver | Gmail, Slack, Zoom, Twilio | |
| vdiserver | Citrix, VMware Horizon | |
| monitorserver | Datadog, New Relic, Splunk | |
| aiserver | OpenAI API, Azure OpenAI | |
| **Total SaaS equiv.** | | **$8,000–15,000/mes** |

SBOS: $0 en licencias. Datos nunca salen de la infra del cliente.

## 7. Clasificacion Funcional

| Clasificacion | Ejemplos |
|---|---|
| Core infrastructure | PostgreSQL, Redis, K8s, CRI-O, Calico, etcd |
| Auxiliary services | Patroni→PG, PgBouncer→PG, ClickHouse→Centrifugo, Langfuse→Ollama |
| Platform services | Keycloak, Vault, Kong, Centrifugo, MinIO, Elasticsearch, Qdrant |
| Business applications | Tryton, OrangeHRM, Saleor, Rocket.Chat, Open WebUI |
| Operational tooling | Prometheus, Grafana, GitLab, Bareos, Velero |
| Sovereign daemons | bKernel, biedata, bCompass, bSearch, bAuth, bhnexus, banexus, IAM Installer |

## 8. Variabilidad por Cliente

Fichas opcionales (criticality: false): GNU Health (salud), TastyIgniter (restauracion), Traccar+Fleetbase (flota), aiserver completo, FreePBX+Asterisk (PBX), MySQL 8 (auto si FreePBX/OrangeHRM), Xibo CMS (signage).

Admin ve en Core UI solo fichas de su perfil de sector. IAM Installer resuelve depends_on automaticamente.

## 9. Gaps Pendientes

- Videoconferencias soberanas: Jitsi Meet o BigBlueButton
- E-Learning/LMS: Moodle o ILIAS
- Contabilidad simple sin ERP: FrontAccounting o Dolibarr
- ITAM/CMDB: Snipe-IT
- Formularios avanzados: Penpot + Formbricks
- ETL visual: Apache Hop o Airbyte

## 10. Politica Kong API Gateway

Todos los endpoints pasan por Kong. Plugins activos: jwt, rate-limiting, cors, acl, openid-connect, ip-restriction, bot-detection, request-transformer, response-transformer, proxy-cache.

Rate limiting por tipo: estandar (100 req/min), partner (500), interno (1000), anonimo (20).

Apps sin OIDC nativo protegidas via OAuth2-Proxy: PgAdmin 4, FreePBX, Zabbix (parcial), Portainer CE.

---

## Trazabilidad

| Seccion | Extraida de | Secciones originales |
|---|---|---|
| §1 Premisas | SBOS-003-STACK v4.0 | §1-§2 (criterios + principio licencias + auditoria) |
| §2 Resumen | SBOS-003-STACK v4.0 | §5 |
| §3 Servidores | SBOS-003-STACK v4.0 | §6-§7 completo (16 servidores con tablas detalladas por app) |
| §3 Smart* | SBOS-PAY-006-ARQUITECTURA, SBOS-REPORT-006-ARQUITECTURA, BOSORC-006-ARQUITECTURA, SBOS-VAULT-006-ARQUITECTURA | Detalle tecnologico por subproyecto Smart* |
| §4 Daemons | SBOS-003-STACK v4.0 + SBOS-018 | Tabla lenguajes + razon fuera K8s + BD propia |
| §5 Prohibidos | SBOS-003-STACK v4.0 | §8 |
| §6 Reemplazos | SBOS-003-STACK v4.0 | §4 Soberania |
| §7 Clasificacion | SBOS-003-STACK v4.0 | §11 |
| §8 Variabilidad | SBOS-003-STACK v4.0 | §12 |
| §9 Gaps | SBOS-003-STACK v4.0 | §13 |
| §10 Kong | SBOS-003-STACK v4.0 | §9 |

---

## Fuentas de Enriquecimiento V8

| Fuente | Tipo | Contenido aportado |
|---|---|---|
| BOS_V6_SBOS-005-STACK.md | V6 (canonico) | Contenido base completo preservado |
| SBOS-PAY-006-ARQUITECTURA.md (Smart Pay) | Smart* | Stack tecnologico SmartPay (Medusa 2.x, Node.js 22 LTS, bpay_db) |
| BOSORC-006-ARQUITECTURA.md (Smart ORC) | Smart* | Stack ORC (Python 3.12, FastAPI, borc_db) |
| SBOS-VAULT-006-ARQUITECTURA.md (Smart Vault Flow) | Smart* | Stack Vault Flow (Python 3.12, FastAPI, bvault_db) |
| SBOS-REPORT-006-ARQUITECTURA.md (Smart Report) | Smart* | Stack Report (Python, FastAPI, breport_db) |
| BOSCMS-006-ARQUITECTURA.md (SBOS CMS) | Smart* | Stack CMS (PHP 8.2, CodeIgniter, bcms_db) |

---

_SKULL · SBOS · SBOS-005-STACK · HUMAN-DOC v1.0-V8 · Mayo 2026_
_Enriquecimiento V8: Smart* stacks detallados de subproyectos + tabla unificada de stacks internos_
