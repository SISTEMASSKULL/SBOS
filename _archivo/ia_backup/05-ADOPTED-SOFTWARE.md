# Software Adoptado (Externo)

**Generado por:** Compositor S-29 (reprocesamiento SBOS)
**Fecha:** 2026-05-18
**Proyecto:** SBOS
**Fuentes:** SBOS-005-STACK (v6), SBOS-030-BOUNDED-CONTEXTS (v6), SBOS-031-SECURITY (v6)
**Jerarquia aplicada:** bauth > v6 > v5 > humano

## Resumen del stack (110+ aplicaciones catalogadas)

| Dimensión | Valor |
|---|---|
| Servidores logicos | 16 (S-HOST + S01-S15) |
| Aplicaciones catalogadas | 110+ (variable por cliente) |
| Licenciamiento | Cero USD en costos de licencia |
| Persistencia principal | PostgreSQL 17 + Patroni HA 3 nodos |
| IAM / RBAC | Keycloak 26.6.1 (OIDC, SAML, MFA, multi-tenant) |
| Observabilidad | LGTM stack + Zabbix + Wazuh |
| DR | pgBackRest (PITR) + Bareos + Velero |
| API Gateway | Kong OSS + NGINX + ModSecurity WAF |
| IA soberana | Ollama + Open WebUI + Qdrant |

## Stack por servidor logico

### S01 -- dataserver (Persistencia)
| App | Version | Licencia | Funcion |
|---|---|---|---|
| PostgreSQL | 17 | PG License | Motor SQL principal. ACID, MVCC, WAL |
| Patroni | 3.x | MIT | HA 3 nodos, failover < 30s |
| PgBouncer | 1.x | ISC | Connection pool |
| pgBackRest | 2.x | MIT | PITR backup desde replica |
| Redis | 7 | BSD 3 | Cache, sesiones, broker Centrifugo |
| MinIO | latest | AGPL v3 | Object storage S3 |

### S02 -- gatewayserver (Seguridad perimetral)
| App | Funcion |
|---|---|
| NGINX | Reverse proxy, TLS termination |
| Certbot | Certificados Let's Encrypt |
| ModSecurity + OWASP CRS | WAF: SQLi, XSS, CSRF |
| Kong Gateway OSS | API Gateway: JWT, rate-limit, CORS, ACL, OIDC |

### S03 -- identityserver (IAM)
| App | Version | Funcion |
|---|---|---|
| Keycloak | 26.6.1 (canonica) | IdP: OIDC, SAML, MFA, WebAuthn, Passkeys, FAPI 2.0 |
| Vault | 1.x | Gestion de secretos, PKI, rotacion |
| OAuth2-Proxy | 7.x | Proxy auth para apps sin soporte OIDC nativo |

### S04 -- erpserver (ERP)
| App | Funcion |
|---|---|
| Tryton ERP | ERP principal: contabilidad, facturacion, compras, inventario |

### S05 -- appsserver (Apps de negocio)
| App | Funcion |
|---|---|
| Saleor | E-commerce / CRM |
| EspoCRM | CRM ligero |
| OrangeHRM | RRHH |
| Zammad | Service Desk |

### S06 -- commsserver (Comunicaciones)
Postfix + Dovecot (correo), Mattermost (mensajeria), Centrifugo OSS (WebSocket bus)

### Otros servidores
S07 docserver (Paperless, Nextcloud), S08 reportserver (Superset, Airflow), S09 monitorserver (Prometheus, Grafana, Loki), S10 vdiserver (Kasm, Fedora KDE), S11 searchserver (Typesense, Qdrant), S12 aiserver (Ollama, Open WebUI, Langfuse), S13 geoserver, S14 securityserver (Wazuh), S15 opsserver (pgAdmin, Kibana).

## Estandares de seleccion
1. Autenticacion delegable a Keycloak (OIDC/SAML nativo u OAuth2-Proxy)
2. Compatibilidad con PostgreSQL (excepciones MySQL: OrangeHRM, FreePBX, Easy!Appointments)
3. Licencia OSI-approved: MIT, Apache 2.0, GPL v2/v3, LGPL, MPL 2.0, BSD, AGPL v3, ISC
4. API REST/GraphQL, webhooks, protocolos estandar
5. Empaquetable como ficha SBOS (manifest.yml + yaml_engine.yml + resources/)
