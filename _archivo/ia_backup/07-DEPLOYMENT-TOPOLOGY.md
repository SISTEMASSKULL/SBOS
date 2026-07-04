# Topologia de Despliegue

**Generado por:** Compositor S-29 (reprocesamiento SBOS)
**Fecha:** 2026-05-18
**Proyecto:** SBOS
**Fuentes:** SBOS-007-DEPLOY (v6), SBOS-002-ARCH (v6), SBOS-033-DEPLOY (v6), SBOS-BAUTH-CONCEPTUALIZACION-v5_0 (bauth)
**Jerarquia aplicada:** bauth > v6 > v5 > humano

## Arquitectura fisica
- **Servidores fisicos:** 1+ servidores del cliente (hardware propio o VPS dedicado)
- **Sistema operativo host:** Ubuntu Server 24.04 LTS
- **Orquestador de contenedores:** Kubernetes (CRI-O, Calico, MetalLB, Kyverno)
- **Daemons soberanos:** systemd en el host (fuera de K8s)
- **Red:** Acceso publico via Kong/NGINX, mTLS interno via Linkerd

## Topologia NEXUS (PRECEDENCIA BAUTH)

La topologia invariable del SBOS para identidad fisica:
```
banexus (edge, nodo Fedora) → bhnexus (host, Unix socket) → bAuth (fuente de verdad)
```
NUNCA: banexus → bAuth directamente. bhnexus es el unico cliente autorizado del socket /run/bos/bauth.sock.

## Los 16 servidores logicos

| ID | Nombre | Apps | Namespace K8s |
|---|---|---|---|
| S-HOST | hostserver | sbos-bootstrap, sbos-k8s-upgrader, certificados | sbos-installer |
| S01 | dataserver | PostgreSQL, Patroni, PgBouncer, Redis, MinIO, MySQL | sbos-data |
| S02 | gatewayserver | NGINX, Certbot, ModSecurity, Kong | sbos-gateway |
| S03 | identityserver | Keycloak 26.6.1, Vault, OAuth2-Proxy | sbos-identity |
| S04 | erpserver | Tryton ERP | sbos-erp |
| S05 | appsserver | Saleor, EspoCRM, OrangeHRM, Zammad | sbos-apps |
| S06 | commsserver | Postfix, Dovecot, Mattermost, Centrifugo | sbos-comms |
| S07 | docserver | Paperless, Nextcloud, MinIO | sbos-docs |
| S08 | reportserver | Superset, Airflow, Metabase | sbos-monitor |
| S09 | monitorserver | Prometheus, Grafana, Loki, Zabbix, Wazuh | sbos-monitor |
| S10 | vdiserver | Kasm Workspaces, Fedora KDE | sbos-vdi |
| S11 | searchserver | Typesense, Qdrant | sbos-search |
| S12 | aiserver | Ollama, Open WebUI, Langfuse, bCompass | sbos-search |
| S13 | geoserver | (servicios geoespaciales) | sbos-geo |
| S14 | securityserver | Wazuh manager, Wazuh indexer | sbos-security |
| S15 | opsserver | pgAdmin, Kibana, netdata | sbos-ops |

## Ambientes

| Ambiente | Proposito |
|---|---|
| Produccion | Instalacion en servidor del cliente. Unico ambiente en produccion. |
| Staging | Testbench en /opt/sbos-dev/ para validacion pre-release |
| Desarrollo | VPS de SKULL (144.91.76.130) -- desarrollo de daemons y fichas |

## Orden de instalacion (Fichas)
hostserver(0) > postgresql(100) > redis(110) > minio(120) > vault(130) > keycloak(140) > oauth2-proxy(150) > kong(160) > nginx(170) > certbot(180) > mailserver(200) > tryton(310) > bkernel(350) > biedata(360) > bcompass(370) > apps negocio(400+) > aiserver(900+)
