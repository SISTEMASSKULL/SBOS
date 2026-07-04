# servers/ — Catálogo de Servidores Lógicos y Fichas SBOS

Directorio de fichas para el IAM Installer (bos-agent).
Producción: `/etc/bos/blibs/servers/` · Staging: `BosAgent/staging/core/servers/`

## 16 Servidores Lógicos — 112 fichas

| Servidor | Namespace K8s | Fichas | Total |
|---|---|---|---|
| **hostserver** (S-HOST) | sbos-installer | sbos-bootstrap-os, sbos-bootstrap-k8s, sbos-bootstrap-platform, network-validator, sbos-bootstrap-hardening, k8s-upgrader, cert-rotation, compliance-check, nginx-web, linkerd, kyverno | 11 |
| **dataserver** (S01) | sbos-data | postgresql, redis, minio, vault, pgbouncer, pgbackrest, timescaledb, pg-partman, pg-stat-monitor, citus, mysql, symmetricds, pgadmin4 | 13 |
| **gatewayserver** (S02) | sbos-gateway | kong, nginx, certbot, modsecurity | 4 |
| **identityserver** (S03) | sbos-identity | keycloak, oauth2-proxy, wazuh-manager, wazuh-indexer, openvas | 5 |
| **erpserver** (S04) | sbos-erp | tryton, rabbitmq-erp | 2 |
| **devserver** (S05) | sbos-apps | smarttax, smartreport, smartrates, smartorc, smartvaultflow, smartportfolio, smartpay | 7 |
| **appsserver** (S06) | sbos-apps | gnuhealth, saleor, directus, tastyigniter, easyappointments, orangehrm, wikijs, trilium, espocrm, taiga, openproject, calcom, zammad, limesurvey, authelia, vaultwarden | 16 |
| **reportserver** (S07) | sbos-apps | jaspersoft, jasperstarter, pdfjs, superset, airflow, openmetadata | 6 |
| **docserver** (S08) | sbos-docs | paperless-ngx, tesseract, tabula, camelot, kimios, solr, docuseal | 7 |
| **searchserver** (S09) | sbos-search | elasticsearch, rabbitmq-search | 2 |
| **commsserver** (S10) | sbos-comms | postfix, dovecot, roundcube, cypht, postfixadmin, spamassassin, clamav, freepbx, rocketchat, mattermost, centrifugo, mongodb | 12 |
| **vdiserver** (S11) | sbos-vdi | fedora-kde, nextcloud, onlyoffice | 3 |
| **monitorserver** (S12) | sbos-monitor | grafana, prometheus, alertmanager, alloy | 4 |
| **geoserver** (S13) | sbos-geo | traccar, fleetbase, xibo, novosga, cardmesh | 5 |
| **opsserver** (S14) | sbos-ops | gitlab, k6, trivy, bareos, velero, goss, pgbackrest-svc, searxng | 8 |
| **aiserver** (S15) | sbos-ai | ollama, open-webui, qdrant, embedding-worker, langfuse, flowise, bcompass-svc | 7 |

**Total: 112 fichas · 575 archivos · 15 servidores**

## Formato canónico

Cada ficha incluye (SBOS-049 §4):

```
servers/<servidor>/<ficha>/
├── manifest.yml          # Identidad, workload, orden, dependencias, health
├── yaml_engine.yml       # Fases: pre_install, install, post_install, update, repair, uninstall
├── task_catalog.sh       # Funciones ficha_<id>_<fase>() con export -f
├── <ficha>.k8s.yml       # K8s Deployment/StatefulSet + Service
├── <ficha>.network       # K8s NetworkPolicy
└── resources/            # Config, SQL, dashboards, integrations
```

## Daemons Soberanos (systemd host — no son fichas K8s)

| Daemon | Servicio | Lenguaje | Razon |
|---|---|---|---|
| IAM Installer | bos.service | Go | Guardian del SO |
| bKernel | bkernel.service | Rust | Acceso WAL <50us |
| biedata | biedata.service | Rust | Escritura antiloop WAL |
| bCompass | bcompass.service | Go | Ciclo vida independiente K8s |
| bSearch | bsearch.service | Go | Indexacion WAL |
| bAuth | bauth.service | Go | Identidad WAL |
| bhnexus | bhnexus.service | Go | WebSocket mTLS hardware |
| banexus | banexus.service (--user) | Go | Edge sentinel Fedora VDI |

## Referencias

- `SBOS-005-STACK.md` — Stack tecnológico completo (110+ apps, 16 servidores)
- `SBOS-007-DEPLOY.md` — Namespaces K8s y topología
- `SBOS-018-DAEMON-BOS.md` — Arquitectura del IAM Installer
- `SBOS-019-FICHAS.md` — Sistema de fichas (formato, contratos, jerarquía)
- `SBOS-035-INSTALL-ROUTINE.md` — Secuencia bootstrap de 16 fichas
- `SBOS-049-FICHAS-BOS.md` — Doctrina del sistema de fichas
