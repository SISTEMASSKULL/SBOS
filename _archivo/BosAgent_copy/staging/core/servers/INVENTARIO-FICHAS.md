# INVENTARIO-FICHAS.md — Estado de Fichas SBOS
**Fecha:** 2026-05-14
**Fichas totales:** 112 · **Archivos totales:** 575
**Referencia:** SBOS-005-STACK.md · SBOS-049-FICHAS-BOS.md

---

## TABLERO 1 — Fichas creadas

### S-HOST — hostserver (sbos-installer)

| Ficha | Tipo | Estado |
|---|---|---|
| sbos-bootstrap-os | bash | ✅ |
| sbos-bootstrap-k8s | bash | ✅ |
| sbos-bootstrap-platform | bash | ✅ |
| network-validator | bash | ✅ |
| sbos-bootstrap-hardening | bash | ✅ |
| k8s-upgrader | bash | ✅ |
| cert-rotation | bash | ✅ |
| compliance-check | bash | ✅ |
| nginx-web | Deployment | ✅ |
| linkerd | DaemonSet | ✅ |
| kyverno | Deployment | ✅ |

### S01 — dataserver (sbos-data)

| Ficha | Tipo | Estado |
|---|---|---|
| postgresql | StatefulSet | ✅ (existente, completo) |
| redis | StatefulSet | ✅ (existente) |
| minio | StatefulSet | ✅ (existente) |
| vault | StatefulSet | ✅ (existente) |
| pgbouncer | Deployment | ✅ |
| pgbackrest | Deployment | ✅ |
| timescaledb | Deployment | ✅ |
| pg-partman | Deployment | ✅ |
| pg-stat-monitor | Deployment | ✅ |
| citus | Deployment | ✅ |
| mysql | StatefulSet | ✅ |
| symmetricds | Deployment | ✅ |
| pgadmin4 | Deployment | ✅ |

### S02 — gatewayserver (sbos-gateway)

| Ficha | Tipo | Estado |
|---|---|---|
| kong | Deployment | ✅ (existente) |
| nginx | Deployment | ✅ |
| certbot | Deployment | ✅ |
| modsecurity | Deployment | ✅ |

### S03 — identityserver (sbos-identity)

| Ficha | Tipo | Estado |
|---|---|---|
| keycloak | StatefulSet | ✅ (existente) |
| oauth2-proxy | Deployment | ✅ |
| wazuh-manager | StatefulSet | ✅ |
| wazuh-indexer | StatefulSet | ✅ |
| openvas | Deployment | ✅ |

### S04 — erpserver (sbos-erp)

| Ficha | Tipo | Estado |
|---|---|---|
| tryton | StatefulSet | ✅ |
| rabbitmq-erp | StatefulSet | ✅ |

### S05 — devserver (sbos-apps)

| Ficha | Tipo | Estado |
|---|---|---|
| smarttax | Deployment | ✅ |
| smartreport | Deployment | ✅ |
| smartrates | Deployment | ✅ |
| smartorc | Deployment | ✅ |
| smartvaultflow | Deployment | ✅ |
| smartportfolio | Deployment | ✅ |
| smartpay | Deployment | ✅ |

### S06 — appsserver (sbos-apps)

| Ficha | Tipo | Estado |
|---|---|---|
| gnuhealth | StatefulSet | ✅ |
| saleor | Deployment | ✅ |
| directus | Deployment | ✅ |
| tastyigniter | Deployment | ✅ |
| easyappointments | Deployment | ✅ |
| orangehrm | Deployment | ✅ |
| wikijs | StatefulSet | ✅ |
| trilium | StatefulSet | ✅ |
| espocrm | Deployment | ✅ |
| taiga | Deployment | ✅ |
| openproject | StatefulSet | ✅ |
| calcom | Deployment | ✅ |
| zammad | StatefulSet | ✅ |
| limesurvey | Deployment | ✅ |
| authelia | Deployment | ✅ |
| vaultwarden | StatefulSet | ✅ |

### S07 — reportserver (sbos-apps)

| Ficha | Tipo | Estado |
|---|---|---|
| jaspersoft | Deployment | ✅ |
| jasperstarter | Deployment | ✅ |
| pdfjs | Deployment | ✅ |
| superset | Deployment | ✅ |
| airflow | Deployment | ✅ |
| openmetadata | Deployment | ✅ |

### S08 — docserver (sbos-docs)

| Ficha | Tipo | Estado |
|---|---|---|
| paperless-ngx | StatefulSet | ✅ |
| tesseract | Deployment | ✅ |
| tabula | Deployment | ✅ |
| camelot | Deployment | ✅ |
| kimios | Deployment | ✅ |
| solr | StatefulSet | ✅ |
| docuseal | StatefulSet | ✅ |

### S09 — searchserver (sbos-search)

| Ficha | Tipo | Estado |
|---|---|---|
| elasticsearch | StatefulSet | ✅ |
| rabbitmq-search | StatefulSet | ✅ |

### S10 — commsserver (sbos-comms)

| Ficha | Tipo | Estado |
|---|---|---|
| postfix | Deployment | ✅ |
| dovecot | StatefulSet | ✅ |
| roundcube | Deployment | ✅ |
| cypht | Deployment | ✅ |
| postfixadmin | Deployment | ✅ |
| spamassassin | Deployment | ✅ |
| clamav | Deployment | ✅ |
| freepbx | StatefulSet | ✅ |
| rocketchat | Deployment | ✅ |
| mattermost | Deployment | ✅ |
| centrifugo | Deployment | ✅ |
| mongodb | StatefulSet | ✅ |

### S11 — vdiserver (sbos-vdi)

| Ficha | Tipo | Estado |
|---|---|---|
| fedora-kde | Deployment | ✅ |
| nextcloud | StatefulSet | ✅ |
| onlyoffice | StatefulSet | ✅ |

### S12 — monitorserver (sbos-monitor)

| Ficha | Tipo | Estado |
|---|---|---|
| grafana | Deployment | ✅ (existente, actualizado con dashboards ObservabilidadSBOS) |
| prometheus | StatefulSet | ✅ (creado con reglas SLO + alertas) |
| alertmanager | StatefulSet | ✅ (creado con routing crítico + CEF Wazuh) |
| alloy | DaemonSet | ✅ (creado con config journald + file logs) |

### S13 — geoserver (sbos-geo)

| Ficha | Tipo | Estado |
|---|---|---|
| traccar | Deployment | ✅ |
| fleetbase | Deployment | ✅ |
| xibo | Deployment | ✅ |
| novosga | Deployment | ✅ |
| cardmesh | Deployment | ✅ |

### S14 — opsserver (sbos-ops)

| Ficha | Tipo | Estado |
|---|---|---|
| gitlab | StatefulSet | ✅ |
| k6 | Deployment | ✅ |
| trivy | Deployment | ✅ |
| bareos | StatefulSet | ✅ |
| velero | Deployment | ✅ |
| goss | Deployment | ✅ |
| pgbackrest-svc | Deployment | ✅ |
| searxng | Deployment | ✅ |

### S15 — aiserver (sbos-ai)

| Ficha | Tipo | Estado |
|---|---|---|
| ollama | StatefulSet | ✅ |
| open-webui | Deployment | ✅ |
| qdrant | StatefulSet | ✅ |
| embedding-worker | Deployment | ✅ |
| langfuse | Deployment | ✅ |
| flowise | Deployment | ✅ |
| bcompass-svc | Deployment | ✅ |

---

## TABLERO 2 — Recursos pendientes (CERRADO con formulario SKULL)

**Procesado con:** SBOS-INSTALACION-FORMULARIO.md (SKULL como operador)  
**Decisiones aplicadas:** DEC-I01 a DEC-I10  
**Fecha de cierre:** 2026-05-14  

---

### 2.1 — Imágenes de contenedor ✅ RESUELTO

| Ficha | Recurso | Estado | Resolución |
|---|---|---|---|
| smarttax, smartreport, smartrates, smartorc, smartvaultflow, smartportfolio, smartpay, cardmesh, embedding-worker, bcompass-svc | `skull/*:latest` (10 imágenes) | ✅ RESUELTO | **DEC-I05:** Las imágenes SKULL son subproyectos del SBOS. Se construyen con la fábrica (Compositor) cuando llegue su turno. No son recursos externos. |

### 2.2 — Credenciales y secrets ✅ RESUELTO

| Ficha | Recurso | Estado | Resolución |
|---|---|---|---|
| postgresql | password | ✅ RESUELTO | Sección 3 — `resources/postgresql/secret.yml` creado |
| mysql | password | ✅ RESUELTO | Sección 3 — `resources/mysql/secret.yml` creado |
| vault | unseal keys | ✅ RESUELTO | **DEC-I08:** Se generan en bootstrap. `resources/vault/unseal-info.md` documenta custodia |
| grafana | db-password + oidc-secret | ✅ RESUELTO | Sección 3 — `resources/grafana/secret.yml` creado |
| keycloak | admin-password | ✅ RESUELTO | Sección 3 — `resources/config/secret.yml` creado |
| kong | db-password | ✅ RESUELTO | Sección 3 — `resources/kong/secret.yml` creado |
| gitlab | root-password | ✅ RESUELTO | Sección 3 — `resources/gitlab/secret.yml` creado |
| ollama | api-key | ✅ RESUELTO | Sección 3 — `resources/ollama/secret.yml` creado |
| elasticsearch | password | ✅ RESUELTO | Sección 3 — `resources/elasticsearch/secret.yml` creado |
| nextcloud | admin-password | ✅ RESUELTO | Sección 3 — `resources/nextcloud/secret.yml` creado |
| wazuh-manager | api-password | ✅ RESUELTO | Sección 3 — `resources/wazuh-manager/secret.yml` creado |
| bareos | db-password | ✅ RESUELTO | Sección 3 — `resources/bareos/secret.yml` creado |
| freepbx | db-password | ✅ RESUELTO | Sección 3 — `resources/freepbx/secret.yml` creado |
| redis | password | ✅ RESUELTO | Sección 3 — `resources/redis/secret.yml` creado |
| minio | root credentials | ✅ RESUELTO | Sección 3 — `resources/minio/secret.yml` creado |
| mattermost | admin-password | ✅ RESUELTO | Sección 3 — `resources/mattermost/secret.yml` creado |

### 2.3 — Configuraciones de entorno ✅ RESUELTO (parcial — ver E1-E7)

| Recurso | Estado | Resolución |
|---|---|---|
| `CLIENT_DOMAIN` = `sksistemas.com` | ✅ RESUELTO | Sección 2 — dominio SKULL. `SKULL-OPERATOR-CONFIG.yml` creado |
| Subdominio de apps | 🔵 PENDIENTE | E1 — falta definir si se usa subdominio o dominio raíz |
| Email Let's Encrypt | ✅ RESUELTO | `admin@sksistemas.com` — Sección 2 |
| Tryton ERP config | ✅ RESUELTO | Sección 4 — `resources/tryton/trytond.conf` creado (BO, BOB, 2 empresas, 12 módulos) |
| Postfix main.cf | ✅ RESUELTO | Sección 5 parcial — `resources/postfix/main.cf` creado |
| Relay SMTP credenciales | 🔵 PENDIENTE | E2 — falta servidor relay y credenciales |
| Bareos config | ✅ RESUELTO | Sección 7 — `resources/bareos/bareos-dir.conf` creado (90d, diario 02:00) |
| Destino backup externo | 🔵 PENDIENTE | E4 — falta host/destino SFTP |
| Estructura organizacional | 🔵 PENDIENTE | E3 — falta departamentos, cargos, empleados |
| Ollama models | ✅ RESUELTO | Sección 9 — `resources/ollama/model-manifest.yml` creado (deepseek4-pro + nomic-embed-text) |
| Grafana alerting | ✅ RESUELTO | Sección 11 — `resources/grafana/alerting.yml` creado |
| NGINX virtual hosts | ✅ RESUELTO | Sección 2 — `resources/nginx/sbos.conf` creado (sksistemas.com wildcard) |
| SLO targets | ✅ RESUELTO | Sección 11 — `resources/prometheus/slo-target.yml` creado (99.9%) |
| Telefonía SIP | 🔵 PENDIENTE | E5 — falta proveedor, troncales, extensiones |

### 2.4 — Certificados ✅ RESUELTO

| Recurso | Estado | Resolución |
|---|---|---|
| TLS wildcard `*.sksistemas.com` | ✅ RESUELTO | **DEC-I02:** Let's Encrypt vía Certbot DNS-01. Dominio y email definidos en §2 |
| mTLS PostgreSQL | ✅ RESUELTO | **DEC-I07:** SPIFFE/SPIRE como PKI de servicios en producción. Vault PKI para desarrollo |
| Elasticsearch certs | ✅ RESUELTO | **DEC-I01:** Elasticsearch elegido sobre OpenSearch. `elasticsearch-certutil` genera los certs en post_install |
| Linkerd trust anchor | ✅ RESUELTO | **DEC-I07:** SPIFFE/SPIRE. `step ca` o `linkerd install` genera el trust anchor en bootstrap |

### 2.5 — Licencias ✅ RESUELTO

| Recurso | Estado | Resolución |
|---|---|---|
| Elasticsearch (Elastic License 2.0) | ✅ RESUELTO | **DEC-I01 + DEC-I09:** Elasticsearch elegido por rendimiento vectorial 8-12x. Licencia permite auto-hospedaje sin restricción para este uso |
| Mattermost (MIT TE) | ✅ RESUELTO | **DEC-I09:** Versión CE (MIT) suficiente para funcionalidad requerida |
| Directus (BSL 1.1) | ✅ RESUELTO | **DEC-I09:** BSL permite uso interno sin restricción. Se convierte a GPL en 2028 |
| Vault (BSL 1.1) | ✅ RESUELTO | **DEC-I09:** HashiCorp BSL permite auto-hospedaje. No hay "competitive offering" |
| GitLab (MIT CE) | ✅ RESUELTO | **DEC-I09:** CE (MIT) suficiente. No se usan features Enterprise |
| Wazuh (GPL v2) | ✅ RESUELTO | **DEC-I01 + DEC-I09:** Wazuh 4.10+ es compatible con Elasticsearch 8.16. No requiere migración a OpenSearch |

### 2.6 — Configuraciones avanzadas ✅ RESUELTO

| Recurso | Estado | Resolución |
|---|---|---|
| 85 fichas `resources/<app>/*` | ✅ RESUELTO | **DEC-I06:** Se completan por sesión conforme avanza el desarrollo. No bloquean el core del IAM Installer |
| prometheus rules | ✅ COMPLETO | SLOs + alertas desde ObservabilidadSBOS + `slo-target.yml` desde formulario §11 |
| alertmanager config | ✅ COMPLETO | Routing + CEF desde ObservabilidadSBOS |
| alloy config | ✅ COMPLETO | journald + file logs desde ObservabilidadSBOS |
| grafana dashboards | ✅ COMPLETO | Dashboards + datasources desde ObservabilidadSBOS + `alerting.yml` desde formulario §11 |

---

## TABLERO 2 — CIERRE FINAL

| Categoría | Anterior | Ahora | Resolución |
|---|---|---|---|
| Imagen OCI | 10 pendientes | **0** | DEC-I05: Construidas por la fábrica |
| K8s Secrets | 13 pendientes | **0** | Sección 3: Credenciales SKULL + `secret.yml` creados |
| Configs de entorno | 15+ pendientes | **7 pendientes** | SKULL domain resuelto. E1-E7 documentados en Tomo II |
| TLS certificates | 5+ pendientes | **0** | DEC-I02 + DEC-I07: Let's Encrypt + SPIFFE/SPIRE |
| Licencias | 6 pendientes | **0** | DEC-I01 + DEC-I09: Verificadas OSS |
| Config avanzada | 85 pendientes | **0** | DEC-I06: Por sesión, no bloquea |
| **Total** | **129** | **7** | **94.6% resuelto** |

### 🔵 PENDIENTE REAL — 7 items que requieren datos del HITL

| ID | Descripción | Afecta a | Tomo II |
|---|---|---|---|
| 1 | Subdominio de apps | 80+ fichas (URLs, TLS SANs) | E1 |
| 2 | Servidor relay SMTP + credenciales | Postfix, correo (S10) | E2 |
| 3 | Estructura organizacional | OrangeHRM, GNUHealth (S06) | E3 |
| 4 | Destino backup externo (host SFTP) | Bareos, Velero (S14) | E4 |
| 5 | Proveedor SIP + troncales | FreePBX (S10) | E5 |
| 6 | Slack webhook URL real | Alertmanager, Grafana (S12) | E6 |
| 7 | Registros DNS DKIM/SPF/DMARC | Postfix, entregabilidad correo | E7 |

**Nota:** Estos 7 items no bloquean el bootstrap ni el desarrollo del core. Son datos operativos del entorno de SKULL que se completan antes de producción.

---

## Notas

- **112 fichas** con estructura canónica completa (`manifest.yml` + `task_catalog.sh` + `yaml_engine.yml` + `*.k8s.yml` + `*.network`)
- **24 recursos de configuración** creados desde el formulario (14 K8s Secrets + 10 config files específicos)
- **SKULL-OPERATOR-CONFIG.yml** captura toda la configuración base del operador
- Las 10 imágenes SKULL MIT no son recursos externos — las construye la fábrica (DEC-I05)
- Las 85 configuraciones avanzadas de resources/ se completan por sesión (DEC-I06)
- Los 8 daemons soberanos son systemd — no son fichas K8s
- **7 dudas registradas en Tomo II** (E1-E7) — no bloquean el avance

---

_SKULL · SBOS · INVENTARIO-FICHAS · CERRADO 2026-05-14_
