# Infraestructura Base

**Generado por:** Compositor S-29 (reprocesamiento SBOS)
**Fecha:** 2026-05-18
**Proyecto:** SBOS
**Fuentes:** SBOS-002-ARCH (v6), SBOS-007-DEPLOY (v6), SBOS-005-STACK (v6), SBOS-BAUTH-CONCEPTUALIZACION-v5_0 (bauth)
**Jerarquia aplicada:** bauth > v6 > v5 > humano

## Arquitectura fisica

| Componente | Ubicacion | SO |
|---|---|---|
| Servidor del cliente | Hardware propio / VPS dedicado | Ubuntu Server 24.04 LTS |
| Daemons soberanos | systemd en host (fuera de K8s) | Ubuntu nativo |
| Aplicaciones del stack | Pods Kubernetes | Contenedores OCI |
| Endpoints corporativos | USB booteable / red | Fedora KDE Plasma (SBOS VDI) |

## Las 6 capas del sistema

| Capa | Componentes | Runtime |
|---|---|---|
| Infraestructura | IAM Installer, K8s (CRI-O, Calico, MetalLB, Kyverno), Ubuntu 24.04 | systemd + K8s |
| Daemons Soberanos | bKernel, biedata, bCompass, bSearch, bAuth, bhnexus | systemd host |
| Datos | PostgreSQL (Patroni HA 3 nodos), Redis, MinIO | K8s pods |
| Aplicaciones | erpserver, appsserver, commsserver, docserver, reportserver... | K8s pods |
| Gobierno | Keycloak 26.6.1, Vault, Kong API Gateway | K8s pods |
| Usuario | Core UI (Flutter), SBOS VDI (Fedora KDE) | K8s pods + USB |

## Kubernetes -- 14 namespaces

sbos-installer, sbos-data, sbos-identity, sbos-security, sbos-gateway, sbos-erp, sbos-apps, sbos-comms, sbos-docs, sbos-monitor, sbos-geo, sbos-vdi, sbos-search, sbos-ops. Pod Security Standards: restricted (data, identity, security), baseline (resto).

## Requisitos de hardware

| Escenario | vCPU | RAM | SSD |
|---|---|---|---|
| Nodo unico minimo | 2 | 4 GB | 40 GB |
| Nodo unico recomendado | 4+ | 8+ GB | 100+ GB |
| Multi-nodo | Escalable agregando workers K8s | | |

## Orden de arranque (ProtocoloFundacional)
T+00:00 Ubuntu Server 24.04 LTS minimo
T+00:02 IAM Installer como systemd
T+00:48 K8s cluster operativo + Core UI disponible
T+01:00 Administrador instala fichas desde Core UI
hostserver(0) > postgresql(100) > redis(110) > minio(120) > vault(130) > keycloak(140) > oauth2-proxy(150) > kong(160) > nginx(170) > certbot(180) > mailserver(200) > tryton(310) > bkernel(350) > biedata(360) > bcompass(370) > apps negocio(400+) > aiserver(900+)

## Infraestructura bAuth (bauth v5.0)

| Componente | Especificacion |
|---|---|
| bAuth (Go) | 64 MB base + ~0.5 MB/usuario concurrente |
| PostgreSQL bAuth | bauth_db con tablas bos_rol_template, bos_user_template, bauth_biometric_templates |
| Redis | Cache BitmaskBundle TTL 30s, single node hasta 500 usuarios |
| Keycloak | 26.6.1, JVM heap 1 GB base + ~5 MB/usuario |
| Unix socket | /run/bos/bauth.sock, permisos 0660, grupo bos |
| Plan escalado | Contabo VPS 10 (5-10 usuarios) a VPS 60+ (500-1000+ usuarios) |

## Seguridad de infraestructura
- Linkerd mTLS automatico inter-pod
- Network Policies deny-by-default (Calico)
- Kyverno para Pod Security Standards
- Wazuh DaemonSet en todos los nodos
- Secrets via Vault (nunca en texto claro)
