# SBOS-003-STACK

## Catálogo del Stack Tecnológico

### SKULL · SBOS — Sovereign Business Operating System

### v4.0 · Marzo 2026

\---

## Tabla de Contenidos

1. [Criterios de Selección](#1-criterios-de-selección)
2. [Principio de Licencias: $0 y Libres — Sin Excepciones](#2-principio-de-licencias-0-y-libres--sin-excepciones)
3. [Tabla de Auditoría de Licencias de Todo el Stack](#3-tabla-de-auditoría-de-licencias-de-todo-el-stack)
4. [Principio de Soberanía: Por Qué Este Stack](#4-principio-de-soberanía-por-qué-este-stack)
5. [Resumen del Stack](#5-resumen-del-stack)
6. [Servidores Lógicos](#6-servidores-lógicos)
7. [Detalle por Servidor](#7-detalle-por-servidor)
8. [Componentes Vetados y Justificación del Veto](#8-componentes-vetados-y-justificación-del-veto)
9. [API Gateway — Contratos y Políticas Kong](#9-api-gateway--contratos-y-políticas-kong)
10. [Modelo de Autorización RBAC](#10-modelo-de-autorización-rbac)
11. [Clasificación Funcional de Aplicaciones](#11-clasificación-funcional-de-aplicaciones)
12. [Notas de Variabilidad por Cliente](#12-notas-de-variabilidad-por-cliente)
13. [Gaps Identificados y Roadmap](#13-gaps-identificados-y-roadmap)
14. [Registro de Cambios v4.0](#14-registro-de-cambios-v40)

\---

## 1\. Criterios de Selección

Toda aplicación candidata a integrar el stack SBOS debe satisfacer:

1. **Autenticación delegable a Keycloak:** Soporte nativo o adaptable de OIDC/SAML para RBAC centralizado
2. **Compatibilidad con PostgreSQL:** Como motor de persistencia principal o mediante adaptadores
3. **Licencia open source:** Sin costos de licenciamiento, código fuente auditable
4. **Interoperabilidad con el stack:** API REST/GraphQL, webhooks, protocolos estándar
5. **Viabilidad como ficha SBOS:** Empaquetable con manifest.yml + yaml\_engine.yml + resources/

El catálogo es dinámico. El IAM Installer detecta fichas nuevas en `servers/` y las presenta en el menú. No todas se instalan: el administrador selecciona según requerimientos del cliente.

\---

## 2\. Principio de Licencias: $0 y Libres — Sin Excepciones

El SBOS tiene un principio inquebrantable: **cero costo de licenciamiento en el stack base**. Este principio no admite excepciones.

### ¿Qué significa "licencia libre" en el contexto del SBOS?

Una licencia es aceptable si cumple **todas** las siguientes condiciones:

1. **$0 de costo** para autoalojamiento en producción comercial
2. **Código fuente auditable** — sin binarios opacos en componentes críticos
3. **Sin restricciones de uso comercial** por número de usuarios, instancias o ingresos
4. **Sin cláusulas de "fair use" o "sustainable use"** que limiten el uso empresarial

Las licencias aprobadas para componentes del stack base incluyen: MIT, Apache 2.0, GPL v2/v3, LGPL, MPL 2.0, BSD (2-clause, 3-clause), AGPL v3.

Las licencias **no aceptables** incluyen: Business Source License (BSL), Sustainable Use License, Commons Clause sobre cualquier licencia, Server Side Public License (SSPL) con restricciones, licencias de "source available" con restricciones comerciales.

### Herramienta de orquestación vetada

**n8n** fue evaluada como herramienta de automatización de workflows. Aunque es funcional, competente, y self-hosted, usa la **Sustainable Use License** — una licencia que no es OSI-certified como software libre y que incluye restricciones comerciales. Esto viola directamente el Principio 3 del stack. n8n ha sido removida del stack base. Ver §8 para detalles completos del veto.

### SBOS AI Tools como reemplazo soberano

En lugar de n8n, el stack incorpora **SBOS AI Tools** como daemon soberano de orquestación de inteligencia y workflows:

* **Licencia:** MIT (SKULL) — sin restricciones comerciales de ningún tipo
* **Propiedad:** SKULL — código completamente bajo control del proyecto
* **Integración:** daemon del host, parte del stack de daemons soberanos junto con bKernel e SBOS Data Integration
* **Capacidad:** rutas agent / flow / analyst / report con LLM local via Ollama, búsqueda vectorial via Qdrant, workflows de negocio integrados al WAL de PostgreSQL

\---

## 3\. Tabla de Auditoría de Licencias de Todo el Stack

Esta tabla lista todos los componentes del stack con su licencia exacta y evaluación para uso en el SBOS. El modelo es idéntico al usado en SBOS-016 para el aiserver.

### S00 · hostserver

|Componente|Licencia|Evaluación|
|-|-|-|
|Ubuntu Server 24.04 LTS|Ubuntu LTS (Canonical)|✅ Libre para producción — soporte comercial opcional|
|CRI-O|Apache 2.0|✅ Sin restricciones|
|kubeadm / kubelet / kubectl|Apache 2.0|✅ Sin restricciones|
|Calico CNI|Apache 2.0|✅ Sin restricciones|
|MetalLB|Apache 2.0|✅ Sin restricciones|
|Kyverno|Apache 2.0|✅ Sin restricciones|
|kube-bench|Apache 2.0|✅ Sin restricciones|
|Helm|Apache 2.0|✅ Sin restricciones|

### S01 · dataserver

|Componente|Licencia|Evaluación|
|-|-|-|
|PostgreSQL 17|PostgreSQL License (BSD-like)|✅ Sin restricciones|
|Patroni|MIT|✅ Sin restricciones|
|PgBouncer|ISC|✅ Sin restricciones|
|pgBackRest|MIT|✅ Sin restricciones|
|TimescaleDB (extensión)|Apache 2.0 (Community)|✅ Sin restricciones en CE|
|pg\_partman (extensión)|PostgreSQL License|✅ Sin restricciones|
|Citus (extensión)|AGPL v3|✅ Sin restricciones para self-hosted|
|Redis 7|BSD 3-Clause|✅ Sin restricciones|
|MinIO|AGPL v3|✅ Sin restricciones para self-hosted|
|MySQL 8|GPL v2|✅ Sin restricciones — uso secundario acotado|
|SymmetricDS|GPL v3|✅ Sin restricciones|
|PgAdmin 4|PostgreSQL License|✅ Sin restricciones|

### S02 · gatewayserver

|Componente|Licencia|Evaluación|
|-|-|-|
|NGINX|BSD 2-Clause|✅ Sin restricciones|
|Certbot|Apache 2.0|✅ Sin restricciones|
|ModSecurity|Apache 2.0|✅ Sin restricciones|
|OWASP Core Rule Set|Apache 2.0|✅ Sin restricciones|
|Kong Gateway (OSS)|Apache 2.0|✅ Sin restricciones — se usa la edición OSS|
|HashiCorp Vault|BSL 1.1 (post-2023)|⚠️ BSL — autoalojamiento libre, restricciones en servicios gestionados. Evaluado como aceptable para uso propio del cliente.|

### S03 · identityserver

|Componente|Licencia|Evaluación|
|-|-|-|
|Keycloak|Apache 2.0|✅ Sin restricciones|
|OAuth2-Proxy|MIT|✅ Sin restricciones|
|Wazuh|GPL v2 (OSS)|✅ Sin restricciones|
|OpenVAS / Greenbone|GPL v2|✅ Sin restricciones|
|Linkerd|Apache 2.0|✅ Sin restricciones|

### S04 · erpserver

|Componente|Licencia|Evaluación|
|-|-|-|
|Tryton ERP|GPL v3|✅ Sin restricciones|
|RabbitMQ|Mozilla Public License 2.0|✅ Sin restricciones|

### S05 · devserver

|Componente|Licencia|Evaluación|
|-|-|-|
|Laravel Framework|MIT|✅ Sin restricciones|
|Vue.js 3 + PrimeVue|MIT|✅ Sin restricciones|
|Django REST Framework|BSD 3-Clause|✅ Sin restricciones|
|Celery|BSD 3-Clause|✅ Sin restricciones|

### S06 · appsserver

|Componente|Licencia|Evaluación|
|-|-|-|
|GNU Health|GPL v3|✅ Sin restricciones|
|Saleor Commerce|BSD 3-Clause|✅ Sin restricciones|
|Directus|BSL 1.1|⚠️ BSL — autoalojamiento libre. Evaluado como aceptable para uso propio.|
|TastyIgniter|MIT|✅ Sin restricciones|
|Easy!Appointments|GPL v3|✅ Sin restricciones|
|OrangeHRM 6.0+|GPL v2 (Community Edition)|✅ Community Edition, sin restricciones|
|Wiki.js|AGPL v3|✅ Sin restricciones para self-hosted|
|Trilium Notes|AGPL v3|✅ Sin restricciones para self-hosted|
|EspoCRM|GPL v3|✅ Sin restricciones|
|Taiga|MPL 2.0|✅ Sin restricciones|
|OpenProject|GPL v3|✅ Community Edition, sin restricciones|
|Cal.com|AGPL v3|✅ Sin restricciones para self-hosted|
|Zammad|GPL v3|✅ Sin restricciones|
|LimeSurvey|GPL v2|✅ Sin restricciones|
|Authelia|Apache 2.0|✅ Sin restricciones|
|Vaultwarden|AGPL v3|✅ Sin restricciones para self-hosted|
|~~n8n~~|~~Sustainable Use License~~|❌ **VETADO** — Viola principio $0 licencias libres. Ver §8.|

### S07 · reportserver

|Componente|Licencia|Evaluación|
|-|-|-|
|JasperSoft Studio 6.18.1|LGPL (Community Edition)|✅ Community Edition LGPL — libre para uso comercial|
|JasperStarter 3.6.2|LGPL|✅ Sin restricciones|
|PDF.js|Apache 2.0|✅ Sin restricciones|
|Apache Superset|Apache 2.0|✅ Sin restricciones|
|Apache Airflow|Apache 2.0|✅ Sin restricciones|
|OpenMetadata|Apache 2.0|✅ Sin restricciones|

### S08 · docserver

|Componente|Licencia|Evaluación|
|-|-|-|
|Paperless-NGX|GPL v3|✅ Sin restricciones|
|Tesseract|Apache 2.0|✅ Sin restricciones|
|EasyOCR|Apache 2.0|✅ Sin restricciones|
|Tabula|MIT|✅ Sin restricciones|
|Camelot|MIT|✅ Sin restricciones|
|Kimios DMS|LGPL v2.1|✅ Sin restricciones|
|Apache Solr|Apache 2.0|✅ Sin restricciones|
|DocuSeal|AGPL v3|✅ Sin restricciones para self-hosted|

### S09 · searchserver

|Componente|Licencia|Evaluación|
|-|-|-|
|Elasticsearch 8|SSPL / Elastic License 2.0|⚠️ Elastic License 2.0 — self-hosted libre, restricción en servicios cloud gestionados. Aceptable para uso propio.|
|RabbitMQ 3.13+|MPL 2.0|✅ Sin restricciones|

### S10 · commsserver

|Componente|Licencia|Evaluación|
|-|-|-|
|Postfix|IBM Public License / Postfix License|✅ Sin restricciones|
|Dovecot|MIT / LGPL v2.1|✅ Sin restricciones|
|Roundcube|GPL v3|✅ Sin restricciones|
|Cypht|GPL v2|✅ Sin restricciones|
|PostfixAdmin|GPL v2|✅ Sin restricciones|
|SpamAssassin|Apache 2.0|✅ Sin restricciones|
|ClamAV + Amavis|GPL v2|✅ Sin restricciones|
|FreePBX 17|GPL v2 (Community Edition)|✅ Community Edition, sin restricciones|
|Asterisk 21|GPL v2|✅ Sin restricciones|
|Rocket.Chat 6.0+|MIT|✅ Sin restricciones|
|Mattermost 9.0+|MIT (Team Edition)|✅ Team Edition, sin restricciones|
|Centrifugo OSS v6|Apache 2.0|✅ Sin restricciones|

### S11 · vdiserver

|Componente|Licencia|Evaluación|
|-|-|-|
|Fedora KDE Plasma|GPL / LGPL (mixed)|✅ Sin restricciones|
|Nextcloud Files|AGPL v3|✅ Sin restricciones para self-hosted|
|OnlyOffice Docs|AGPL v3|✅ Sin restricciones para self-hosted|

### S12 · monitorserver

|Componente|Licencia|Evaluación|
|-|-|-|
|Prometheus|Apache 2.0|✅ Sin restricciones|
|Grafana (OSS)|AGPL v3|✅ Sin restricciones para self-hosted|
|Alertmanager|Apache 2.0|✅ Sin restricciones|
|Loki|AGPL v3|✅ Sin restricciones para self-hosted|
|Grafana Alloy|Apache 2.0|✅ Sin restricciones|
|Tempo|AGPL v3|✅ Sin restricciones para self-hosted|
|Zabbix 7.0+|GPL v2|✅ Sin restricciones|
|PagerDuty Integration|N/A (integración opcional)|⚠️ **No es componente base.** Integración opcional para clientes con contrato activo. El alerting base usa Alertmanager → Mattermost y email. Ver nota en §7/S12.|
|Portainer CE|Zlib License|✅ Community Edition, sin restricciones|

### S13 · geoserver

|Componente|Licencia|Evaluación|
|-|-|-|
|Traccar 6.5+|Apache 2.0|✅ Sin restricciones|
|Fleetbase + FleetOps|MIT|✅ Sin restricciones|
|Xibo CMS|AGPL v3|✅ Sin restricciones para self-hosted|
|Novo SGA|MIT|✅ Sin restricciones|
|CardMesh|MIT (SKULL)|✅ Propiedad SKULL|

### S14 · opsserver

|Componente|Licencia|Evaluación|
|-|-|-|
|GitLab CE 17.8+|MIT|✅ Community Edition, sin restricciones|
|K6|AGPL v3|✅ Sin restricciones para self-hosted|
|Trivy|Apache 2.0|✅ Sin restricciones|
|Bareos 23.0+|AGPL v3|✅ Sin restricciones|
|Velero|Apache 2.0|✅ Sin restricciones|
|Goss|Apache 2.0|✅ Sin restricciones|
|pgBackRest|MIT|✅ Sin restricciones|
|SearXNG|AGPL v3|✅ Sin restricciones para self-hosted|

### S15 · aiserver

|Componente|Licencia|Evaluación|
|-|-|-|
|Ollama|MIT|✅ Sin restricciones|
|Open WebUI|MIT|✅ Sin restricciones|
|Qdrant|Apache 2.0|✅ Sin restricciones|
|Embedding Worker|MIT (SKULL)|✅ Propiedad SKULL|
|Langfuse|MIT (self-hosted)|✅ Sin restricciones para self-hosted|
|Flowise|Apache 2.0|✅ Uso comercial libre — rol acotado a prototipado|
|SBOS AI Tools|MIT (SKULL)|✅ Propiedad SKULL|
|Qwen3 (todos los tamaños)|Apache 2.0|✅ Uso comercial libre|
|DeepSeek-R1 (distilados Qwen)|MIT|✅ Sin restricciones|

**Conclusión de la auditoría:** el stack SBOS tiene **cero componentes con restricciones de licencia críticas** para el perfil de cliente objetivo (PyMEs e industrias medianas de Iberoamérica). Los componentes con BSL o Elastic License 2.0 son aceptables porque sus restricciones aplican a servicios cloud gestionados — no al autoalojamiento que practica el SBOS. n8n es el único componente removido por violación del principio de licencias.

\---

## 4\. Principio de Soberanía: Por Qué Este Stack

El SBOS no es una lista de software open source. Es una **plataforma empresarial soberana** — un sistema completo que reemplaza, sin excepción, cada servicio de terceros que la empresa utiliza.

Cada servidor lógico representa una categoría completa de servicios cloud:

|Servidor lógico|Reemplaza|
|-|-|
|**hostserver**|**No reemplaza un servicio cloud — es la base soberana del sistema. Ubuntu + K8s gestionados automáticamente.**|
|dataserver|AWS RDS, Google Cloud SQL, Azure Database, Redis Cloud|
|gatewayserver|Cloudflare, AWS ALB, Azure Front Door|
|identityserver|Auth0, Okta, Azure AD, Google Workspace Identity|
|erpserver|SAP Business One, Microsoft Dynamics, Oracle Netsuite|
|devserver|GitHub Actions, Heroku, AWS Lambda|
|appsserver|Salesforce, Zendesk, Monday.com, Calendly, SurveyMonkey|
|reportserver|Tableau, Power BI, Looker, Databricks|
|docserver|DocuSign, SharePoint, Adobe Acrobat|
|searchserver|Algolia, Elastic Cloud|
|commsserver|Gmail, Twilio, RingCentral, Slack, Zoom|
|vdiserver|Citrix, VMware Horizon, Google Workspace|
|monitorserver|Datadog, New Relic, Splunk, PagerDuty|
|geoserver|Google Maps Platform, Fleet Complete|
|opsserver|GitHub Enterprise, Acronis, Veeam|
|**aiserver**|OpenAI, Anthropic API, Azure OpenAI, Google Gemini API|

El costo de licenciamiento de estos servicios para una empresa mediana iberoamericana supera los USD 8,000–15,000 mensuales. El SBOS los reemplaza con USD 0 en licencias, con datos que nunca salen de la infraestructura del cliente.

\---

## 5\. Resumen del Stack

|Dimensión|Valor|
|-|-|
|Servidores lógicos|**16** (S-HOST + S00–S15)|
|Aplicaciones catalogadas|**110+** (variable por cliente)|
|Fases de instalación|9 (0–8, orden por dependencias)|
|Licenciamiento|$0 USD|
|Persistencia principal|PostgreSQL 17 + Patroni HA|
|IAM / RBAC|Keycloak 26.5.3 (OIDC, SAML, MFA)|
|Observabilidad|LGTM + Zabbix + Wazuh|
|DR|Bareos + pgBackRest (PITR) + Velero|
|Tiempo real|Centrifugo OSS + Redis|
|API Gateway|Kong OSS + NGINX Ingress|
|**Orquestación soberana**|**SBOS AI Tools (MIT, SKULL)**|
|**IA Soberana**|**Ollama + Open WebUI + Qdrant**|
|**Gestión de Credenciales**|**Vaultwarden**|

\---

## 6\. Servidores Lógicos

|ID|Servidor|Dominio Funcional|Apps|
|:-:|-|-|:-:|
|S-HOST|`hostserver/`|Infraestructura base: Ubuntu + Kubernetes|5|
|S01|`dataserver/`|Persistencia, caché, object storage|13|
|S02|`gatewayserver/`|Ingress, TLS, WAF, API Gateway, secretos|7|
|S03|`identityserver/`|IAM, SIEM/XDR, service mesh, zero trust|8|
|S04|`erpserver/`|ERP core — fuente de verdad de negocio|2|
|S05|`devserver/`|Desarrollo propio, APIs fiscales|6|
|S06|`appsserver/`|Apps open source de negocio|16|
|S07|`reportserver/`|BI, reportería fiscal, ETL|7|
|S08|`docserver/`|DMS, OCR, firma digital|7|
|S09|`searchserver/`|Indexación, message broker|2|
|S10|`commsserver/`|Correo, VoIP, mensajería, WebSocket|11|
|S11|`vdiserver/`|VDI, storage colaborativo, ofimática|4|
|S12|`monitorserver/`|Métricas, logs, trazas, alertas|10|
|S13|`geoserver/`|GPS, logística, signage, turnos|5|
|S14|`opsserver/`|SCM, CI/CD, backup, DR, búsqueda soberana|8|
|**S15**|**`aiserver/`**|**IA soberana, orquestación, RAG, embeddings**|**7**|

\---

## 7\. Detalle por Servidor

### S-HOST · hostserver/

El hostserver es el único servidor lógico cuyas fichas son todas **Fichas de Sistema Tipo 1** (`workload.type: bash`). Corren directamente en el host Ubuntu — no como pods K8s — porque son responsables de construir y mantener la plataforma sobre la que K8s y todas las demás fichas viven. No aparecen en el menú de instalación del administrador. El IAM Installer las gestiona automáticamente en cada arranque.

**Principio:** ninguna ficha del hostserver instala software de negocio. Su único dominio es: Ubuntu funcionando correctamente + Kubernetes funcionando correctamente. Todo lo demás es responsabilidad de los otros servidores lógicos.

|#|Ficha|Tipo|Licencia|Función|
|:-:|-|-|-|-|
|1|**sbos-bootstrap**|Sistema Tipo 1|MIT (SKULL)|**Primera ficha que ejecuta el IAM Installer en un Ubuntu Server limpio.** Instala y configura todo: hardening Ubuntu (25 sysctl, ulimits, SSH, auditd, AppArmor, fail2ban), CRI-O, kubeadm, K8s cluster completo, Calico CNI con deny-all, MetalLB, Kyverno, namespaces, ResourceQuotas, encriptación etcd, y el Core UI. Sin esta ficha no existe ninguna otra. Se verifica en cada arranque del IAM Installer.|
|2|**sbos-k8s-upgrader**|Sistema Tipo 1|MIT (SKULL)|Gestiona los upgrades de versión de Kubernetes de forma segura: `kubeadm upgrade plan` → `kubeadm upgrade apply` en rolling, sin downtime. Verifica CIS Benchmark tras el upgrade. Solo se activa cuando hay nueva versión disponible declarada en su manifest.|
|3|**sbos-cert-rotation**|Sistema Tipo 1|MIT (SKULL)|Rota automáticamente los certificados TLS del cluster K8s (vencen a 1 año con kubeadm) y la clave AES-256 de encriptación de etcd (cada 90 días). Ejecuta como CronJob del host. Garantiza que el cluster nunca quede con certificados vencidos.|
|4|**sbos-compliance-check**|Sistema Tipo 1|MIT (SKULL)|Ejecuta `kube-bench` semanalmente. Reporta controles CIS Level 1 en FAIL directamente al dashboard de salud del Core UI. El administrador ve el estado de cumplimiento sin necesidad de acceso al servidor.|
|5|**sbos-nginx-web**|Sistema Tipo 1|MIT (SKULL)|Web institucional opcional del cliente. NGINX en el host (fuera de K8s) para separar tráfico web corporativo del tráfico interno del cluster. `criticality: false`.|

\---

### S01 · dataserver/

Motor de persistencia unificado. Todo el stack lee y escribe aquí. PostgreSQL 17 como motor principal (90%+ del stack), Patroni para HA, Redis para caché/sesiones, MinIO para object storage.

|#|Aplicación|Tipo|Licencia y Edición|Función|
|:-:|-|-|-|-|
|1|PostgreSQL 17|BD relacional principal|PostgreSQL License (libre)|Motor SQL principal. 90%+ de las apps del stack. ACID, MVCC, WAL. Versión 17 — última estable 2026.|
|2|Patroni|HA manager PG|MIT|Cluster HA de PostgreSQL con 3 nodos, replicación streaming, failover automático en menos de 30 segundos. etcd como DCS.|
|3|PgBouncer|Connection pooler|ISC|Pool de conexiones — reduce el overhead de conexiones efímeras de apps multi-pod.|
|4|pgBackRest|Backup PG|MIT|PITR — Point-In-Time Recovery. Restauración al segundo exacto. Se ejecuta desde réplica Patroni para no cargar el primary.|
|5|TimescaleDB|Extensión PG|Apache 2.0 (CE)|Series de tiempo para métricas del negocio y datos IoT.|
|6|pg\_partman|Extensión PG|PostgreSQL License|Particionado automático de tablas por rango de tiempo.|
|7|pg\_stat\_monitor|Extensión PG|BSD 3-Clause|Monitoreo de queries — más detallado que pg\_stat\_statements.|
|8|Citus|Extensión PG|AGPL v3|Sharding horizontal transparente para workloads analíticos masivos.|
|9|Redis 7|In-memory store|BSD 3-Clause|Caché, sesiones, broker Celery, pub/sub Centrifugo/Keycloak. DB0=general, DB1=sesiones, DB2=caché apps.|
|10|MinIO|Object storage S3|AGPL v3|Documentos, logs, backups, modelos AI. Backend de Loki, Bareos, Paperless, Ollama.|
|11|MySQL 8|BD secundaria|GPL v2|FreePBX, OrangeHRM, Easy!Appointments (sin soporte PG nativo). `critical: false`.|
|12|SymmetricDS|CDC|GPL v3|Sincronización bidireccional PostgreSQL ↔ MySQL.|
|13|PgAdmin 4|Admin UI|PostgreSQL License|Administración y consulta de PostgreSQL. `oauth2\_ready: true`.|

**Nota de diseño:** la co-existencia de PostgreSQL 17 (principal) con MySQL 8 (secundaria) no es una inconsistencia — es pragmatismo. FreePBX, OrangeHRM y Easy!Appointments no tienen soporte nativo para PostgreSQL y su migración implicaría forks no mantenibles. MySQL 8 + SymmetricDS mantiene la sincronización con el ecosistema principal donde es necesario.

\---

### S02 · gatewayserver/

Único punto de entrada externo. NGINX como reverse proxy, Certbot para SSL, ModSecurity WAF, Kong como API Gateway, HashiCorp Vault para secretos dinámicos.

|#|Aplicación|Tipo|Licencia y Edición|Función|
|:-:|-|-|-|-|
|1|NGINX|Reverse proxy|BSD 2-Clause|TLS termination, proxy a Kong y servicios internos.|
|2|Certbot|Cert management|Apache 2.0|Emisión y renovación automática de certificados TLS via Let's Encrypt.|
|3|ModSecurity + OWASP CRS|WAF|Apache 2.0|OWASP Top-10: SQLi, XSS, CSRF, path traversal. Actualización automática de reglas.|
|4|Rate Limiting|DDoS L7|(integrado en Kong)|Control de tasa por IP, usuario, endpoint. Integrado en Kong.|
|5|DDoS Protection|DDoS L4-L7|(integrado en NGINX)|Anti-slowloris, connection limiting, geo-blocking configurable.|
|6|Kong Gateway OSS|API Gateway|Apache 2.0|Proxy de APIs. Plugins: JWT, rate-limit, CORS, ACL, OpenID Connect. **Se usa la edición OSS — libre sin restricciones.**|
|7|HashiCorp Vault|Secrets management|BSL 1.1|Credenciales dinámicas TTL corto, mínimo privilegio por app. Fuente de verdad de todos los secrets tras su instalación. BSL aceptable — restricción aplica solo a servicios gestionados, no autoalojamiento.|

\---

### S03 · identityserver/

IdP central (Keycloak) + SIEM (Wazuh) + service mesh (Linkerd). Keycloak es el gobierno de todo el BOS.

|#|Aplicación|Tipo|Licencia y Edición|Función|
|:-:|-|-|-|-|
|1|Keycloak 26.5.3|IdP / IAM|Apache 2.0|SSO OIDC/SAML. RBAC: roles, grupos, scopes, realms. MFA TOTP/WebAuthn. Multi-tenant por realm.|
|2|OAuth2-Proxy|Auth proxy|MIT|Protege apps sin OIDC nativo vía proxy reverso de autenticación. Delega a Keycloak.|
|3|LDAP/AD Federation|Directory sync|(integrado en Keycloak)|Sincronización con Active Directory / LDAP corporativo existente.|
|4|OIDC/SAML Broker|Identity broker|(integrado en Keycloak)|Federación con Google, Microsoft Entra, GitHub para clientes que lo requieren.|
|5|Wazuh 4.10+|SIEM/XDR|GPL v2|Correlación de eventos de seguridad. DaemonSet en todos los nodos K8s.|
|6|OpenVAS / Greenbone|Vuln scanner|GPL v2|Escaneo programado de vulnerabilidades del cluster. Reporta al Core UI.|
|7|Linkerd|Service mesh|Apache 2.0|mTLS automático inter-pod. Cifrado en tránsito transparente sin cambios en código de apps.|
|8|Network Policies|Microsegmentación|(integrado en K8s/Calico)|Deny-by-default entre namespaces. GlobalNetworkPolicy Calico.|

\---

### S04 · erpserver/ (Aislamiento Critical Path)

|#|Aplicación|Tipo|Licencia y Edición|Función|
|:-:|-|-|-|-|
|1|Tryton ERP|ERP Core / Hub bKernel|GPL v3|Contabilidad Bolivia PUCT/SIN, inventario, manufactura, ventas, compras. Fuente de verdad del bKernel.|
|2|RabbitMQ 3.13+|Message broker AMQP|MPL 2.0|Desacoplamiento asíncrono Tryton ↔ Saleor, Airflow, Django SIAT. Persistencia en disco cifrada.|

**Nota de diseño:** el erpserver está en nodo físico aislado por diseño. Una degradación del ERP no debe afectar las comunicaciones, el acceso de usuarios, ni los servicios al cliente. El aislamiento físico es una decisión de gobernanza, no solo técnica.

\---

### S05 · devserver/

|#|Aplicación|Tipo|Licencia y Edición|Función|
|:-:|-|-|-|-|
|1|Laravel Framework|Backend API|MIT|APIs REST empresariales, lógica de negocio específica del cliente.|
|2|Vue.js 3 + PrimeVue|Frontend SPA|MIT|Interfaz reactiva para apps propias del cliente.|
|3|Laravel Payment Gateway|Pagos|MIT (SKULL)|Tigo Money, QR Simple Bolivia, pasarelas locales.|
|4|Laravel QR Payment API|Pagos QR|MIT (SKULL)|QR dinámicos con verificación en tiempo real.|
|5|Django REST + SIAT Bolivia|API fiscal|BSD 3-Clause|CUF, firma XML, envío SIN, contingencia offline. Crítico para cumplimiento tributario boliviano.|
|6|Celery Workers|Task queue|BSD 3-Clause|Prioridades: SIAT (alta) > reportes > email > sync. Broker: Redis.|

\---

### S06 · appsserver/

|#|Aplicación|Tipo|Licencia y Edición|Función|
|:-:|-|-|-|-|
|1|GNU Health 4.4+|Salud / EHR|GPL v3|Historia clínica, laboratorio, epidemiología. Certificado OPS/OMS.|
|2|Saleor Commerce|E-Commerce|BSD 3-Clause|Headless, GraphQL, multi-canal. Integrado con Tryton vía RabbitMQ.|
|3|Directus 11+|CMS headless|BSL 1.1|API auto-generada sobre esquema BD. Portal de contenidos y data API. BSL aceptable — autoalojamiento libre.|
|4|TastyIgniter 3.7+|Restaurantes|MIT|Delivery, QR en mesa, gestión de cocina en tiempo real.|
|5|Easy!Appointments 1.5+|Agendamiento|GPL v3|Reservas online. Sync con Nextcloud Calendar vía CalDAV.|
|6|OrangeHRM 6.0+|RRHH|GPL v2 — **Community Edition**|Nómina, asistencia, evaluaciones de desempeño. Community Edition libre para uso comercial.|
|7|Wiki.js 3.0+|Knowledge base|AGPL v3|Documentación colaborativa, versionada, búsqueda full-text.|
|8|Trilium Notes|Notas|AGPL v3|Organización jerárquica, cifrado E2E.|
|9|EspoCRM 8.0+|CRM|GPL v3|Pipeline ventas, leads, email marketing integrado.|
|10|Taiga 6.7+|PM Agile|MPL 2.0|Scrum, Kanban, épicas, sprints.|
|11|OpenProject 14+|PM Formal|GPL v3|Gantt, WBS, OKRs, presupuestos de proyecto.|
|12|Cal.com 2.0+|Scheduling|AGPL v3|Disponibilidad real, flujos de aprobación, multi-timezone.|
|13|Zammad 6.4+|Help desk|GPL v3|Tickets multicanal, SLA, base de conocimiento integrada.|
|14|LimeSurvey 6.0+|Encuestas|GPL v2|NPS, formularios con lógica condicional.|
|15|Authelia|MFA complementario|Apache 2.0|Capa adicional de autenticación sobre Keycloak para apps legacy.|
|16|**Vaultwarden**|**Gestor de contraseñas**|**AGPL v3**|**Implementación Rust de la API Bitwarden. Gestor de credenciales corporativas autoalojado. Compatible con todos los clientes Bitwarden (web, móvil, extensiones de navegador, desktop). E2E cifrado AES-256. Organizaciones, colecciones, roles, SSO via Keycloak OIDC. 50MB RAM. PostgreSQL como backend.**|

**Nota sobre n8n:** n8n fue evaluada para este servidor. Fue **vetada** por su Sustainable Use License. Ver §8 para justificación completa y §7/S15 para el reemplazo soberano (SBOS AI Tools).

\---

### S07 · reportserver/

|#|Aplicación|Tipo|Licencia y Edición|Función|
|:-:|-|-|-|-|
|1|JasperSoft Studio 6.18.1|Reportes fiscales|**LGPL — Community Edition**|Libro C/V SIN, IEDGE, F-110, PUCT. Formatos regulados Bolivia. Community Edition 6.18.1 confirmada con licencia LGPL — libre para uso comercial.|
|2|JasperStarter 3.6.2|CLI batch|LGPL|Generación masiva automatizada de reportes.|
|3|PDF.js|Visor|Apache 2.0|Previsualización PDF embebida en el navegador.|
|4|Apache Superset 4.1+|BI / Dashboards|Apache 2.0|KPIs tiempo real, 40+ tipos de visualización. Conecta a PostgreSQL y Elasticsearch.|
|5|Apache Airflow 2.10+|ETL / Orchestrator|Apache 2.0|DAGs: ETL nocturno, reportes SIN, sincronizaciones batch.|
|6|OpenMetadata 1.6+|Data catalog|Apache 2.0|Linaje de datos, calidad, glosario de negocio. Conecta con PostgreSQL y Airflow.|
|7|Repositorio Plantillas|Storage (MinIO)|—|.jrxml, logos, formatos SIN, PUCT versionados en MinIO.|

\---

### S08 · docserver/

|#|Aplicación|Tipo|Licencia y Edición|Función|
|:-:|-|-|-|-|
|1|Paperless-NGX|DMS|GPL v3|OCR integrado, clasificación ML, búsqueda full-text.|
|2|Tesseract + EasyOCR|OCR|Apache 2.0|100+ idiomas incluyendo quechua y aymara.|
|3|Tabula|Extracción PDF|MIT|Tablas PDF → CSV/XLSX para procesamiento de datos.|
|4|Camelot|Extracción avanzada|MIT|PDFs complejos con tablas en modos lattice/stream.|
|5|Kimios DMS 1.3+|BPM documental|LGPL v2.1|Aprobación por flujos, versionado, auditoría.|
|6|Apache Solr 9.0+|Search engine|Apache 2.0|Full-text documental. Backend del DMS Kimios.|
|7|DocuSeal 1.7+|Firma digital|AGPL v3|Multi-firmante, trail de auditoría. Alternativa soberana a DocuSign.|

\---

### S09 · searchserver/

|#|Aplicación|Tipo|Licencia y Edición|Función|
|:-:|-|-|-|-|
|1|Elasticsearch 8.16+|Search engine|Elastic License 2.0|Logs, SIEM Wazuh, búsqueda unificada del stack. Licencia aceptable — restricción aplica a servicios gestionados, no autoalojamiento.|
|2|RabbitMQ 3.13+|Message broker|MPL 2.0|AMQP. Tryton, Saleor, Airflow. **Nota:** también aparece en erpserver porque el mensaje de negocio y el bus de búsqueda tienen SLAs diferentes.|

\---

### S10 · commsserver/

|#|Aplicación|Tipo|Licencia y Edición|Función|
|:-:|-|-|-|-|
|1|Postfix|MTA (SMTP)|IBM PL / Postfix License|SPF, DKIM, DMARC. Stack de correo saliente.|
|2|Dovecot|MDA (IMAP/POP3)|MIT / LGPL|Servicio de buzones. UID 5000:5000 en producción.|
|3|Roundcube|Webmail|GPL v3|SSO vía OAuth2-Proxy. Redis DB1 para sesiones.|
|4|Cypht|Webmail alt.|GPL v2|Multi-cuenta, RSS integrado. Construido desde `php:8.3-apache`.|
|5|PostfixAdmin|Mail admin|GPL v2|Dominios virtuales, buzones, alias. `oauth2\_ready: true`.|
|6|SpamAssassin|Anti-spam|Apache 2.0|Bayesiano + RBL + heurísticas.|
|7|ClamAV + Amavis|Antivirus|GPL v2|Escaneo de adjuntos vía milter.|
|8|FreePBX 17 + Asterisk 21|PBX / VoIP|GPL v2 — **Community Edition**|IVR, grabación, click-to-call desde EspoCRM. Backend: MySQL.|
|9|Rocket.Chat 6.0+|Messaging|MIT|Canales, video, webhooks GitLab/Zabbix.|
|10|Mattermost 9.0+|Messaging DevOps|MIT — **Team Edition**|Playbooks, compliance, alertas Prometheus/Alertmanager. Team Edition libre.|
|11|Centrifugo OSS v6|WebSocket server|Apache 2.0|Pub/sub tiempo real. Redis broker. JWT vía Keycloak JWKS.|

**Servicios auxiliares del ecosistema Centrifugo:**

|Componente|Tipo|Función|
|-|-|-|
|ClickHouse|Analytics columnar|Métricas históricas de conexiones WebSocket.|
|Appwrite Messaging|Push notifications|Push self-hosted iOS/Android/Web para usuarios offline.|

\---

### S11 · vdiserver/

|#|Aplicación|Tipo|Licencia y Edición|Función|
|:-:|-|-|-|-|
|1|Fedora 43 KDE Plasma|Desktop (PEP)|GPL / LGPL|Escritorio personalizable. Keycloak como PDP (Policy Decision Point). Control de privilegios via bAuth + banexus.|
|2|Nextcloud Files|Collaborative storage|AGPL v3|Archivos accesibles desde VDI y dispositivos. CalDAV/CardDAV.|
|3|Nextcloud Calendar|CalDAV|AGPL v3|Sync con Roundcube, Easy!Appointments, Cal.com.|
|4|OnlyOffice Docs|Office suite|AGPL v3|Edición colaborativa Word/Excel/PowerPoint en navegador.|

\---

### S12 · monitorserver/

Nodo dedicado que **NUNCA** compite por recursos con lo que monitorea.

|#|Aplicación|Tipo|Licencia y Edición|Función|
|:-:|-|-|-|-|
|1|Prometheus|Metrics|Apache 2.0|Scraping /metrics de todo el stack. Retención 90 días.|
|2|Grafana (OSS)|Dashboards|AGPL v3|Métricas + logs + trazas unificados. SSO via Keycloak.|
|3|Alertmanager|Alerting|Apache 2.0|Deduplicación, routing a Mattermost/email. **Es el alerting base del sistema.**|
|4|Loki|Log aggregation|AGPL v3|Logs con labels K8s nativos. Backend: MinIO.|
|5|Grafana Alloy|Unified agent|Apache 2.0|DaemonSet. Reemplaza Promtail + Prometheus Agent.|
|6|Promtail|Log agent (legacy)|Apache 2.0|En transición a Alloy.|
|7|Tempo|Tracing|AGPL v3|OpenTelemetry, correlación de trazas con logs Loki.|
|8|Zabbix 7.0+|Infra monitoring|GPL v2|Agentes OS en los 16 servidores lógicos.|
|9|**PagerDuty Integration**|On-call (opcional)|N/A — Integración externa|**Integración opcional para clientes con contrato activo. No es componente base del stack. El alerting base del sistema usa Alertmanager → Mattermost y email. PagerDuty se activa únicamente cuando el cliente requiere escalación telefónica nocturna y tiene contrato vigente con PagerDuty.**|
|10|Portainer CE|Container mgmt|Zlib License — **Community Edition**|Gestión visual K8s complementaria al Core UI.|

\---

### S13 · geoserver/

|#|Aplicación|Tipo|Licencia y Edición|Función|
|:-:|-|-|-|-|
|1|Traccar 6.5+|GPS tracking|Apache 2.0|200+ protocolos de dispositivos, geofences, historial.|
|2|Fleetbase + FleetOps|Logistics|MIT|Despacho, conductores, Proof of Delivery (POD).|
|3|Xibo CMS 4.1+|Digital signage|AGPL v3|Pantallas digitales, turnos, campañas.|
|4|Novo SGA 2.1+|Queue management|MIT|Gestión de turnos multi-sucursal.|
|5|CardMesh|Digital vCards|MIT (SKULL)|NFC/QR, analytics de contactos, sync EspoCRM.|

\---

### S14 · opsserver/

Se configura AL FINAL porque necesita que todo el stack exista para hacer backup.

|#|Aplicación|Tipo|Licencia y Edición|Función|
|:-:|-|-|-|-|
|1|GitLab CE 17.8+|SCM + CI/CD|MIT — **Community Edition**|Source of Truth. Repositorios, pipelines y Registro de Imágenes OCI. Gestiona el ciclo de vida de los manifiestos YAML de Kubernetes.|
|2|K6|Load testing|AGPL v3|Pruebas de carga pre-deploy. Scripts en JavaScript.|
|3|Trivy|Security scan|Apache 2.0|Escaneo de vulnerabilidades (CVEs) en imágenes generadas con Buildah y auditoría de archivos YAML de Kubernetes.|
|4|Bareos 23.0+|Backup|AGPL v3|Cifrado AES-256, 16 servidores. Deduplicación. Backend: MinIO.|
|5|Velero|K8s DR|Apache 2.0|Snapshots de los Namespaces de Podman/K3s cada 4h. Recuperación de desastres (RTO < 30 min).|
|6|Goss|Validation|Apache 2.0|Integridad de backups, smoke tests post-deploy.|
|7|pgBackRest|PG backup|MIT|Backup de PostgreSQL 18. Permite Point-In-Time Recovery (PITR) para restaurar la base de datos fiscal al segundo exacto.|
|8|**SearXNG**|**Metabuscador soberano**|**AGPL v3**|**Motor de búsqueda soberano. Agrega 229+ motores sin tracking. Backend para el RAG de SBOS AI Tools y Open WebUI. Sin registro de usuarios. Alternativa soberana a Bing/Google para búsqueda web empresarial. Metabuscador privado. Backend para el RAG de SBOS AI Tools. Provee búsqueda web soberana sin rastreo para la inteligencia del negocio.**|

\---

### S15 · aiserver/

El aiserver es el servidor lógico S15 del SBOS. Completamente opcional — el stack entero funciona sin él. Provee capacidades de inteligencia artificial empresarial soberana: inferencia LLM local, memoria semántica vectorial, observabilidad de modelos, y el entorno de construcción de agentes.

|#|Ficha / Componente|Tipo|Licencia y Edición|Función|
|:-:|-|-|-|-|
|1|**Ollama**|LLM runtime|MIT|Servidor de inferencia local. API compatible con OpenAI. Corre modelos Qwen3, DeepSeek-R1, Llama sin internet.|
|2|**Open WebUI**|Interfaz LLM|MIT|Interfaz multi-usuario tipo ChatGPT. SSO Keycloak OIDC. RAG documental. Multi-tenant por realm.|
|3|**Qdrant**|Vector database|Apache 2.0|Almacenamiento y búsqueda vectorial para RAG empresarial. Colecciones por realm/empresa.|
|4|**Embedding Worker**|Pipeline embeddings|MIT (SKULL)|Daemon SKULL. Consume cola `ai:embed\_queue` del bKernel. Genera embeddings de entidades de negocio y los persiste en Qdrant.|
|5|**Langfuse**|Observabilidad LLM|MIT (self-hosted)|Trazas de prompts, latencias, costos por modelo y proyecto. Panel de calidad por realm.|
|6|**Flowise**|Agentes visuales|Apache 2.0|Constructor visual de agentes AI. Rol acotado a prototipado de flujos — no producción sostenida.|
|7|**SBOS AI Tools**|**Orquestación soberana**|**MIT (SKULL)**|**Daemon soberano de orquestación de inteligencia y workflows. Reemplazo de n8n con licencia $0 sin restricciones comerciales. Rutas: agent / flow / analyst / report. Consume Ollama para inferencia LLM, Qdrant para búsqueda semántica, WAL de PostgreSQL para eventos de negocio. Parte del stack de 8 daemons soberanos del SBOS.**|

**Modelos de IA catalogados:**

|Modelo|Licencia|Rol en el stack|
|-|-|-|
|Qwen3 (familia completa)|Apache 2.0|**Modelo principal de inferencia** — todos los tamaños|
|Qwen3-Coder:30b|Apache 2.0|Generación de código|
|DeepSeek-R1 (distilados Qwen)|MIT|**Modelo de razonamiento** — análisis complejo|
|Llama 3.3|Llama 3.3 Community License|Alternativa multilingüe — restricción > 700M MAU irrelevante para el perfil SBOS|

\---

## 8\. Componentes Vetados y Justificación del Veto

### n8n — Plataforma de automatización de workflows

|Campo|Detalle|
|-|-|
|**Herramienta**|n8n (n8n GmbH)|
|**Versión evaluada**|1.x (self-hosted)|
|**Capacidad**|Automatización de workflows visual, 400+ integraciones, lógica condicional, loops, LLM pipelines|
|**Licencia**|Sustainable Use License (n8n GmbH)|
|**Por qué fue evaluada**|Excelente integración con el stack, 400+ conectores nativos incluyendo PostgreSQL, Keycloak, Mattermost, Ollama|

**Razón del veto:**

La Sustainable Use License de n8n **no es una licencia OSI-certified como software libre**. Incluye restricciones de uso que limitan el uso comercial en determinados contextos. Específicamente, prohíbe usar n8n para prestar servicios de automatización a terceros o crear productos competitivos, y puede requerir licencia comercial en escenarios de uso empresarial intensivo.

Esto viola directamente el **Principio 3 del stack SBOS: licencia open source sin costos de licenciamiento**. El SBOS es una plataforma que SKULL despliega para clientes comerciales. Usar n8n en ese contexto entra exactamente en el caso de uso que la Sustainable Use License restringe.

**Impacto del veto:**

* n8n es removida de todos los servidores donde aparecía (appsserver, aiserver)
* La funcionalidad de orquestación de workflows es cubierta por **SBOS AI Tools** (MIT, SKULL)
* La funcionalidad de pipelines AI es cubierta por **SBOS AI Tools** conectando a Ollama + Qdrant
* La funcionalidad de integración con el stack es cubierta por el propio **bKernel** y sus reglas YAML declarativas

**Lección arquitectónica:**

El caso n8n ilustra por qué el principio de licencias $0 y libres no admite excepciones: un componente puede ser técnicamente excelente y aun así ser inaceptable si su licencia crea riesgo legal o de costos para los clientes de SKULL. La soberanía del stack incluye soberanía legal.

\---

## 9\. API Gateway — Contratos y Políticas Kong

Kong OSS es el API Gateway del SBOS. Todos los servicios externos del stack pasan por Kong antes de llegar a las aplicaciones. Esta sección especifica los contratos de API y las políticas de gobierno.

### Catálogo de Endpoints que Kong Expone al Exterior

|Endpoint (prefijo)|Versión|Backend|Descripción|
|-|-|-|-|
|`/api/v1/erp/`|v1|Tryton REST adapter|Operaciones ERP: clientes, facturas, inventario|
|`/api/v1/crm/`|v1|EspoCRM REST API|Pipeline de ventas, contactos, leads|
|`/api/v1/billing/`|v1|Django SIAT / Laravel|Emisión de facturas, consulta SIN, CUF|
|`/api/v1/auth/`|v1|Keycloak token endpoint|Token OIDC, refresh, logout|
|`/api/v1/files/`|v1|Nextcloud WebDAV adapter|Subida y descarga de documentos|
|`/api/v1/tickets/`|v1|Zammad REST API|Creación y consulta de tickets de soporte|
|`/api/v1/ai/`|v1|SBOS AI Tools / Ollama adapter|Inferencia LLM, búsqueda semántica|
|`/api/v1/search/`|v1|Elasticsearch REST|Búsqueda unificada del stack|
|`/ws/`|—|Centrifugo WebSocket|Conexiones WebSocket tiempo real|
|`/health/`|—|IAM Installer health endpoint|Estado del cluster (monitoring externo)|

**Regla de versión:** todos los endpoints de negocio incluyen la versión en el path (`/v1/`, `/v2/`). Los endpoints de infraestructura (`/health/`, `/ws/`) no se versionan.

### Política de Versionado de APIs

El SBOS sigue una política de versionado explícito en path para todas las APIs de negocio expuestas via Kong.

**Cómo se introduce una v2:**

1. La nueva versión se despliega en el backend como endpoint paralelo
2. Kong añade la ruta `/api/v2/<servicio>/` apuntando al nuevo endpoint
3. La ruta `/api/v1/<servicio>/` se mantiene activa — sin interrupción para clientes existentes
4. El período de coexistencia es de **mínimo 90 días** desde el anuncio de la v2
5. Se notifica a integraciones conocidas del cliente con 60 días de anticipación
6. La v1 se depreca formalmente al finalizar el período — Kong responde con `410 Gone` + header `Deprecation-Date`

**Cómo se depreca una v1:**

```
Fase 1 (día 0): Anuncio de deprecación — header Warning añadido a todas las respuestas v1
Fase 2 (día 30): Logs de uso de v1 activados — se notifica a integraciones activas
Fase 3 (día 60): Header Sunset añadido a todas las respuestas v1 (RFC 8594)
Fase 4 (día 90): Ruta v1 removida de Kong — 410 Gone con enlace a documentación v2
```

**Nunca se elimina una versión sin período de deprecación.** Una versión con clientes activos no puede ser eliminada — solo puede ser deprecada con el proceso completo.

### Política de Rate Limiting por Tipo de Cliente

Kong aplica rate limiting por tipo de cliente mediante el plugin `rate-limiting` configurado con Redis como backend compartido (para consistencia entre múltiples instancias de Kong).

|Tipo de Cliente|Requests / minuto|Requests / hora|Burst permitido|Identificación|
|-|-|-|:-:|-|
|**Cliente estándar**|100 req/min|3,000 req/hora|2x por 10 segundos|JWT claim `client\_tier: standard`|
|**Partner integrador**|500 req/min|15,000 req/hora|3x por 30 segundos|JWT claim `client\_tier: partner`|
|**Interno (SKULL / CI/CD)**|Sin límite|Sin límite|—|JWT claim `client\_tier: internal`|
|**Sin autenticación**|10 req/min|200 req/hora|No|IP anónima — solo endpoints públicos|

**Respuesta ante rate limit excedido:**

```http
HTTP/1.1 429 Too Many Requests
Retry-After: 30
X-RateLimit-Limit-Minute: 100
X-RateLimit-Remaining-Minute: 0
X-RateLimit-Reset: 1743465600
Content-Type: application/json

{"error": "rate\_limit\_exceeded", "retry\_after\_seconds": 30}
```

**Plugins de Kong activos en todos los endpoints:**

|Plugin|Función|
|-|-|
|`jwt`|Validación de token JWT firmado por Keycloak|
|`rate-limiting`|Control de tasa por cliente (configuración por tier)|
|`cors`|Headers CORS para clientes web y móvil|
|`acl`|Listas de control de acceso por grupo Keycloak|
|`openid-connect`|OIDC nativo para apps que lo soporten|
|`request-transformer`|Normalización de headers antes de llegar al backend|
|`response-transformer`|Enriquecimiento de responses con metadata de trazabilidad|
|`proxy-cache`|Caché de respuestas GET para endpoints de consulta|

\---

## 10\. Modelo de Autorización: RBAC

El stack implementa **Role-Based Access Control (RBAC)** centralizado en Keycloak:

|Componente RBAC|Función|
|-|-|
|**Roles**|Conjuntos de permisos (admin, operador, contador, rrhh)|
|**Grupos**|Agrupación de usuarios (departamento, sucursal, empresa)|
|**Scopes**|Alcance de acceso a recursos por aplicación|
|**Realms**|Aislamiento a nivel tenant (cliente/empresa)|
|**Client Roles**|Roles específicos por aplicación registrada en Keycloak|
|**Composite Roles**|Agregación de roles para simplificar administración|

Cada app registra su client OIDC en Keycloak durante `post\_install`, incluyendo roles, scopes y mappers. El JWT contiene claims de autorización que cada app valida autónomamente. OAuth2-Proxy cubre apps sin soporte OIDC nativo.

**Aplicaciones del stack que no soportan OIDC nativo y se protegen vía OAuth2-Proxy:**
PgAdmin 4, FreePBX, Zabbix (parcial), Portainer CE, algunas vistas de GitLab CE.

\---

## 11\. Clasificación Funcional de Aplicaciones

|Clasificación|Descripción|Ejemplos|
|-|-|-|
|**Core infrastructure**|Base indispensable del cluster|PostgreSQL, Redis, K8s, CRI-O, Calico|
|**Auxiliary services**|Soporte que potencia a otra app|Patroni→PG, PgBouncer→PG, etcd→Patroni, ClickHouse→Centrifugo, Langfuse→Ollama|
|**Platform services**|Transversales, consumidos por múltiples apps|Keycloak, Vault, Kong, Centrifugo, MinIO, Elasticsearch, Qdrant, SBOS AI Tools|
|**Business applications**|Apps que opera el usuario final|Tryton, OrangeHRM, Saleor, Rocket.Chat, Open WebUI|
|**Operational tooling**|Monitoreo, backup, CI/CD|Prometheus, Grafana, GitLab, Bareos, Velero|
|**Sovereign daemons**|Daemons del host — fuera de K8s|bKernel, SBOS Data Integration, SBOS AI Tools, IAM Installer Core|

\---

## 12\. Notas de Variabilidad por Cliente

El catálogo es declarativo y dinámico. No todas las fichas se instalan en todos los clientes.

**Fichas con `criticality: false` — opcionales puras:**

|Ficha|Razón de opcionalidad|
|-|-|
|GNU Health|Solo clientes del sector salud|
|TastyIgniter|Solo clientes del sector restauración|
|Traccar + Fleetbase|Solo clientes con flota vehicular|
|aiserver (completo)|Opcional en todos los clientes — el stack funciona sin IA|
|FreePBX + Asterisk|Solo clientes con necesidad de PBX propia|
|MySQL 8|Se instala automáticamente cuando FreePBX u OrangeHRM están seleccionados|
|PagerDuty|Solo clientes con contrato PagerDuty activo|
|GNU Health|Solo sector salud|
|Xibo CMS|Solo clientes con señalética digital|

**Variabilidad por sector:**

El administrador del cliente ve en el Core UI únicamente las fichas disponibles para su perfil de sector. La selección es interactiva — el IAM Installer resuelve automáticamente las dependencias (`depends\_on`) de cada ficha seleccionada.

\---

## 13\. Gaps Identificados y Roadmap

El análisis comparativo con plataformas enterprise de referencia (Odoo Community, Nextcloud Hub, YunoHost, Sandstorm, Umbrel Business) identifica los siguientes gaps con prioridad de resolución:

### Gaps resueltos en v3.0

* **Automatización de workflows (SBOS AI Tools)** — Reemplazo soberano de n8n. MIT, SKULL.
* **IA soberana (Ollama + Open WebUI + Qdrant + Flowise + Langfuse)** — Nuevo aiserver completo.
* **Gestor de contraseñas corporativo (Vaultwarden)** — Reemplaza LastPass, 1Password empresarial.
* **Metabuscador soberano (SearXNG)** — Backend de búsqueda web para RAG, sin tracking.

### Gaps pendientes (siguiente versión)

* **Video conferencias soberanas:** Jitsi Meet o BigBlueButton. Actualmente la videoconferencia recae en Rocket.Chat (limitado) o en servicios externos como Zoom. Ambos son open source, Kubernetes-ready, y soportan SSO Keycloak.
* **E-Learning / LMS:** Moodle o ILIAS. Sectores educativos, corporativos con formación continua, y salud (capacitación GNU Health) necesitan LMS. Moodle tiene soporte OIDC nativo y PostgreSQL.
* **Accounting específico Bolivia sin ERP completo:** para clientes que solo necesitan contabilidad simple sin el peso de Tryton completo. FrontAccounting o Dolibarr cubren este nicho.
* **Gestión de activos (ITAM/CMDB):** Snipe-IT para inventario de hardware/software empresarial. Complementa el opsserver y cierra el ciclo con Wazuh.
* **Formularios empresariales avanzados:** Penpot (diseño) + Formbricks (formularios y encuestas a usuarios — complemento de LimeSurvey para feedback in-product).
* **ETL visual moderno:** Apache Hop o Airbyte como complemento de Airflow para equipos no-técnicos de datos.

### Nota sobre el aiserver y hardware

El aiserver en su configuración CPU-only requiere un nodo con mínimo 64 GB RAM para correr modelos de 32B parámetros con quantización Q4. Para producción con múltiples usuarios concurrentes se recomienda un nodo con GPU NVIDIA (RTX 4090 mínimo, A100 recomendado para escala). Esta es la única dependencia de hardware especializado en todo el stack SBOS.

\---

## 14\. Registro de Cambios v4.0

**C1 — Eliminación de n8n y veto documentado (§8):**
n8n fue eliminada de todos los servidores donde aparecía. La Sustainable Use License viola el Principio 3 de licencias del stack ($0, libres, sin restricciones comerciales). Se añade §8 "Componentes Vetados" con justificación completa del veto, impacto arquitectónico y lección aprendida. SBOS AI Tools (MIT, SKULL) reemplaza a n8n como daemon soberano de orquestación de inteligencia y workflows, incorporado en S15/aiserver.

**C2 — S15 aiserver agregado con tabla completa:**
El aiserver no existía como entrada en SBOS-003. Se incorpora como servidor S15 con tabla de 7 fichas (Ollama, Open WebUI, Qdrant, Embedding Worker, Langfuse, Flowise, SBOS AI Tools), modelos catalogados (Qwen3 como modelo principal, DeepSeek-R1 como modelo de razonamiento), y licencias verificadas. Fuente: SBOS-016-AISERVER v1.0.

**C3 — Tabla de auditoría de licencias (§3):**
Nueva sección antes de las tablas de servidores. Audita todos los componentes del stack con licencia exacta y evaluación. Modelo basado en la tabla de licencias existente en SBOS-016. Conclusión: cero componentes con restricciones críticas para el perfil de cliente del SBOS. n8n es el único componente vetado.

**C4 — Columna "Licencia y Edición" en todas las tablas:**
Todas las tablas de servidores incluyen ahora columna explícita de licencia y edición. Los componentes con variantes Community/Enterprise documentan su edición exacta: JasperSoft Studio Community Edition 6.18.1 (LGPL, confirmado), PagerDuty documentado como integración opcional no base del stack con nota explícita. Kasm Workspaces eliminado del stack — ver SBOS-012 §2 "Por Qué No Kasm Workspaces". El SBOS VDI usa Fedora KDE Plasma nativo controlado por bAuth + banexus.

**C5 — API Gateway — Contratos y Políticas Kong (§9):**
Nueva sección completa con: catálogo de endpoints que Kong expone al exterior con versiones, política de versionado de APIs (introducción de v2, deprecación de v1 con proceso de 90 días), política de rate limiting por tipo de cliente (estándar / partner / interno / anónimo) con tabla de límites y ejemplo de respuesta HTTP 429, y catálogo de plugins activos en todos los endpoints.

**Actualización de versiones (I1):**
PostgreSQL actualizado a v17 (última estable 2026). Keycloak confirmado en 26.5.3. Kubernetes: la versión exacta se gestiona mediante la Ficha Bootstrap `sbos-k8s-upgrader` — el documento no fija una versión estática porque el upgrader mantiene la versión siempre actualizada. Wazuh confirmado en 4.10+. Kong OSS confirmado como la edición usada.

\---

*SKULL · SBOS · SBOS-003-STACK · v4.0 · Marzo 2026*

> \*\*Referencias:\*\* CIS Kubernetes Benchmark v1.9 · JasperSoft Community Edition 6.18.1 — Jaspersoft · n8n Sustainable Use License — n8n GmbH · Kong OSS Apache 2.0 — konghq.com · RFC 8594 Sunset Header · SBOS-016-AISERVER v1.0 · OSI Open Source Definition — opensource.org · SBOS-012 §2 — Por Qué No Kasm Workspaces

