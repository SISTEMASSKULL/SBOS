# Plan de Implementación BOS — De la Primera Ficha al VDI Operativo

**Versión:** 2.0.0  
**Fecha:** 2026-10-07  
**Autor:** bos-developer  
**Estado:** PROPUESTA — pendiente aprobación HITL  
**Ref:** ADR-040 (bootstrap), ADR-022 (sin intervención manual), SBOS-049 (ctx_id), SBOS-050 (puertos)

---

## 1. Objetivo

Dejar el servidor SBOS completamente operativo desde cero — Ubuntu 26.04 virgen — hasta el
**VDI server (S11)** funcionando: escritorio virtual soberano accesible desde cualquier
dispositivo con autenticación física (NFC/biométrico).

**Criterio de éxito final:** usuario presenta tarjeta NFC → banexus captura → bAuth evalúa
→ BOS genera ctx_id → Guacamole abre sesión Fedora KDE → usuario trabaja en Nextcloud/OnlyOffice.

---

## 2. Estado actual verificado en disco (2026-10-07)

### 2.1 Catálogo real

| Métrica | Valor |
|---------|-------|
| Fichas con `manifest.yml` en `SBOS/servers/` (canónico) | **131** (S00–S15 activas) |
| Fichas con `task_catalog.sh` | **131** (100%) |
| Fichas antes del VDI (execution_order < 355) | **106** |
| Fichas VDI (execution_order 355–360) | **4** (fedora-kde · nextcloud · guacamole · onlyoffice) |
| Fichas post-VDI (geo, ops, AI…) | **20+** |
| S16-webserver (nginx/certbot/modsecurity/weblate) | declaradas como dirs — **sin manifest.yml** |
| Daemons soberanos sin ficha declarada | bauth · bnotify · bhnexus · banexus · biedata · bsearch · bcompass · bkernel |

### 2.2 Niveles de implementación del task_catalog.sh

| Nivel | Ubicación | Fichas | Descripción |
|-------|-----------|--------|-------------|
| **ROBUSTO** | `BosAgent/src/servers/` | 11 | 300–820 líneas · lógica K8s completa · verificadas en VPS |
| **STUB** | `SBOS/servers/<Sxx>/` | ~120 | 50–80 líneas · estructura correcta · manifests K8s necesarios |

Las 11 fichas robustas (manual 1.01 §12.1 ✅):
`bos-preflight` · `sbos-bootstrap-os/k8s/cni/storage` · `sbos-namespace` · `postgresql` (820 l.) · `redis` (584 l.) · `vault` · `keycloak` · `kong`

### 2.3 Brechas reales bloqueantes

| ID | Brecha | Bloquea |
|----|--------|---------|
| **BC-07** | `DbInitService` no existe — aplicación manual de DDLs | Capa 2+ |
| **BC-08** | Context Plane incompleto (sin heartbeat, rate limit, auditoría) | bAuth |
| **BC-09** | Ficha `bauth` no declarada en `servers/` | VDI autenticación |
| **BC-10** | Fichas `bhnexus`/`banexus` no declaradas en `servers/` | NFC/chapas |
| **BC-11** | Fichas VDI son STUB (58–73 líneas) — sin manifests K8s reales | VDI funcional |
| **BC-12** | Fichas `bnotify`, `biedata`, `bsearch`, `bcompass`, `bkernel` no declaradas | Datos y notificaciones |
| **BC-13** | S16-webserver (nginx/certbot/modsecurity/weblate) sin manifest.yml | Dominio público TLS |

---

## 3. Arquitectura de capas del bootstrap progresivo

Según manual 1.01 §4 (ADR-040 — Mínimo Viable Progresivo):

```
CAPA 0 — S00: OS + K8s base                       execution_order  1–35
CAPA 1 — S00/S02: nginx + daemons iniciales        execution_order 50–70
CAPA 2 — S01: Datos completos                      execution_order 100–130
CAPA 3 — S02/S03: Gateway + Identidad             execution_order 120–165
CAPA 4 — S04/S05: ERP + Smart apps                execution_order 170–192
CAPA 5 — S06/S07/S08: Apps + Reports + Docs       execution_order 200–310
CAPA 6 — Hardening + Search + Comms               execution_order 300–350
CAPA 7 — VDI (S11)                                execution_order 355–360
CAPA 8 — Geo + Ops + AI (S13–S15)                execution_order 365–430
```

---

## 4. Cadena completa de fichas — orden de instalación

> Leyenda: ✅ ROBUSTO (BosAgent/src/servers/) · 🟡 STUB (task_catalog.sh < 100 líneas) · 🔴 FALTA (sin manifest.yml o sin declarar)

### CAPA 0 — S00: Sistema Operativo + K8s base (execution_order 1–35)

| Order | Ficha | Estado | Notas |
|-------|-------|--------|-------|
| 1 | bos-preflight | ✅ 323 l. | paquetes SO, usuario bosagent, TLS cert |
| 1 | sbos-bootstrap-os | ✅ 211 l. | kernel modules, sysctl, /data/ · Verif: C-01 |
| 5 | sbos-bootstrap-k8s | ✅ 678 l. | kubeadm + containerd · Verif: C-02 |
| 5 | sbos-namespace | ✅ 226 l. | namespace K8s + NetworkPolicy + Quota |
| 10 | sbos-bootstrap-platform | 🟡 180 l. | base platform pre-K8s |
| 15 | network-validator | 🟡 144 l. | validación de red K8s |
| 15 | sbos-lifecycle | 🟡 169 l. | gestión de ciclo de vida daemons |
| 17 | sbos-security | 🟡 | RBAC + políticas de seguridad base |
| 18 | sbos-repair | 🟡 | detección y auto-reparación |
| 19 | sbos-package-manager | 🟡 | gestor de paquetes OS declarativo |
| 20 | sbos-container-watchdog | 🟡 | watchdog de contenedores K8s |
| 25 | local-path-provisioner | 🟡 64 l. | StorageClass local-path · Verif: C-03 |
| 25 | sbos-bootstrap-cni | ✅ 492 l. | Calico 3.32.0 CNI |
| 30 | sbos-bootstrap-storage | ✅ 349 l. | PVCs funcionales |
| 35 | sbos-bootstrap-monitoring | 🟡 509 l. | agentes de métricas base |

### CAPA 1 — S00/S02: Nginx + daemons iniciales (execution_order 50–70)

| Order | Ficha | Estado | Notas |
|-------|-------|--------|-------|
| 50 | nginx (S02) | 🟡 152 l. | reverse proxy base (antes de certbot) |
| 70 | sbos-bkernel | 🟡 259 l. | daemon bKernel CDC/WAL → Redis Streams |

### CAPA 2 — S01: Datos completos (execution_order 100–130)

| Order | Ficha | Estado | Notas |
|-------|-------|--------|-------|
| 100 | postgresql | ✅ 820 l. | SBOS_db + schemas · Verif: C-04 |
| — | **DbInitService** | 🔴 FALTA | BC-07: DDLs + seeds tras C-04 |
| 105 | pgbouncer | 🟡 | connection pooler PG |
| 108 | pgbackrest | 🟡 | backup PG continuo |
| 110 | redis | ✅ 584 l. | 3 DBs · AOF · Verif: C-05 |
| 112 | timescaledb | 🟡 | extensión PG series temporales |
| 114 | pg-partman | 🟡 | particionado automático PG |
| 115 | minio | 🟡 | object storage (backups/assets/docs) |
| 116 | pg-stat-monitor | 🟡 | monitoreo consultas PG |
| 118 | citus | 🟡 | sharding PG distribuido |
| 120 | mysql | 🟡 | MySQL para apps que lo requieren |
| 125 | symmetricds | 🟡 | sincronización BD multi-nodo |
| 130 | pgadmin4 | 🟡 | administración visual PG |

### CAPA 3 — S02/S03: Gateway + Identidad (execution_order 120–165)

| Order | Ficha | Estado | Notas |
|-------|-------|--------|-------|
| 120 | vault | ✅ | init + unseal Shamir 3/5 + PKI · Verif: C-06 |
| 130 | keycloak | ✅ 549 l. | realm + 5 SPIs custom · Verif: C-07 |
| 135 | besu-qbft | 🟡 616 l. | blockchain QBFT (audit trail) |
| 135 | oauth2-proxy | 🟡 | proxy OAuth2 para apps sin OIDC nativo |
| 142 | certbot | 🟡 75 l. | certificados Let's Encrypt |
| 144 | modsecurity | 🟡 | WAF OWASP CRS |
| 145 | kong | ✅ 79 l. | API Gateway + plugins · Verif: C-08 |
| 150 | linkerd | 🟡 76 l. | service mesh mTLS |
| 155 | kyverno | 🟡 76 l. | políticas K8s OPA |
| 160 | wazuh-manager | 🟡 | SIEM + detección intrusiones |
| 160 | stalwart | 🟡 86 l. | servidor correo JMAP/IMAP/SMTP |
| 162 | wazuh-indexer | 🟡 | índice Wazuh (Elasticsearch-based) |
| 165 | openvas | 🟡 | scanner vulnerabilidades |
| — | **bauth** | 🔴 FALTA | BC-09: daemon identidad soberana |
| — | **bnotify** | 🔴 FALTA | BC-12: push MFA + notificaciones |

### CAPA 4 — S04/S05: ERP + Smart apps (execution_order 170–192)

| Order | Ficha | Estado | Notas |
|-------|-------|--------|-------|
| 170 | tryton | 🟡 | ERP soberano + localización Bolivia |
| 175 | rabbitmq-erp | 🟡 | broker mensajes para ERP |
| 176 | novu | 🟡 107 l. | hub notificaciones multi-canal |
| 180 | smarttax | 🟡 | motor facturación electrónica Bolivia |
| 182 | smartreport | 🟡 | generador reportes financieros |
| 184 | smartrates | 🟡 | tipos de cambio BCB |
| 186 | smartorc | 🟡 | OCR inteligente documentos |
| 188 | smartvaultflow | 🟡 | flujos de aprobación Vault |
| 190 | smartportfolio | 🟡 | gestión de cartera |
| 192 | smartpay | 🟡 | pasarela de pagos soberana |

### CAPA 5 — S06/S07/S08: Apps empresariales (execution_order 200–310)

| Order | Ficha | Estado | Notas |
|-------|-------|--------|-------|
| 200 | gnuhealth | 🟡 | gestión salud (hospitales/clínicas) |
| 205 | saleor | 🟡 | e-commerce headless |
| 210 | directus | 🟡 | CMS headless |
| 215 | tastyigniter | 🟡 | gestión restaurantes |
| 220 | easyappointments | 🟡 | agenda y citas |
| 225 | orangehrm | 🟡 | RRHH soberano |
| 230 | wikijs | 🟡 | wiki corporativa |
| 235 | trilium | 🟡 | notas jerárquicas |
| 240 | espocrm | 🟡 | CRM soberano |
| 245 | taiga | 🟡 | gestión proyectos ágil |
| 250 | openproject | 🟡 | gestión proyectos empresarial |
| 255 | calcom | 🟡 | calendario y reservas |
| 260 | zammad | 🟡 | helpdesk soberano |
| 265 | limesurvey | 🟡 | encuestas corporativas |
| 270 | authelia | 🟡 | 2FA proxy para apps sin OIDC |
| 275 | vaultwarden | 🟡 | gestor contraseñas soberano |
| 280 | jaspersoft | 🟡 | reportes BI empresariales |
| 282 | jasperstarter | 🟡 | runner JasperReports CLI |
| 284 | pdfjs | 🟡 | renderizado PDF soberano |
| 286 | superset | 🟡 | dashboards BI interactivos |
| 288 | airflow | 🟡 | orquestación ETL/pipelines datos |
| 290 | openmetadata | 🟡 | catálogo datos empresarial |
| 295 | paperless-ngx | 🟡 | gestión documentos OCR |
| 298 | tesseract | 🟡 | motor OCR (soporte paperless) |
| 300 | tabula | 🟡 | extracción datos de PDF |
| 302 | camelot | 🟡 | extracción tablas de PDF |
| 305 | kimios | 🟡 | ECM soberano |
| 308 | solr | 🟡 | motor búsqueda full-text |
| 310 | docuseal | 🟡 | firma digital de documentos |

### CAPA 6 — Hardening + Search + Comms (execution_order 300–350)

| Order | Ficha | Estado | Notas |
|-------|-------|--------|-------|
| 300 | sbos-bootstrap-hardening | 🟡 190 l. | CIS hardening + UFW |
| 310 | k8s-upgrader | 🟡 141 l. | upgrades K8s sin downtime |
| 315 | elasticsearch | 🟡 | búsqueda full-text distribuida |
| 318 | rabbitmq-search | 🟡 | broker para pipeline búsqueda |
| 320 | cert-rotation | 🟡 135 l. | rotación automática certificados |
| 320 | postfix | 🟡 | MTA correo saliente |
| 322 | dovecot | 🟡 | servidor IMAP/POP3 |
| 325 | roundcube | 🟡 | webmail soberano |
| 328 | cypht | 🟡 | cliente correo ligero |
| 330 | compliance-check | 🟡 76 l. | verificación cumplimiento ISO |
| 330 | postfixadmin | 🟡 | administración dominios Postfix |
| 332 | spamassassin | 🟡 | filtro anti-spam |
| 335 | clamav | 🟡 | antivirus soberano |
| 338 | freepbx | 🟡 | PBX telefonía IP |
| 340 | nginx-web | 🟡 76 l. | web server tenant (S00) |
| 340 | rocketchat | 🟡 | mensajería corporativa |
| 342 | mongodb | 🟡 | MongoDB (para Rocket.Chat) |
| 345 | mattermost | 🟡 | mensajería alternativa |
| 350 | centrifugo | 🟡 | WebSocket pub/sub tiempo real |
| — | **bhnexus** | 🔴 FALTA | BC-10: proxy hardware WebSocket :9444 |
| — | **banexus** | 🔴 FALTA | BC-10: edge sentinel NFC/biométrico |

### CAPA 7 — VDI Server S11 (execution_order 355–360) — META PRINCIPAL

| Order | Ficha | Estado | Prerequisito real |
|-------|-------|--------|-------------------|
| 355 | fedora-kde | 🟡 57 l. | imagen Fedora KDE + TigerVNC |
| 358 | nextcloud | 🟡 58 l. | almacenamiento soberano (OIDC via bAuth) |
| 359 | guacamole | 🟡 73 l. | gateway HTML5 VNC/RDP (OIDC via bAuth) |
| 360 | onlyoffice | 🟡 58 l. | editor documentos (integrado Nextcloud) |

### Fichas post-VDI (S13–S15) — no bloquean el VDI

| Order | Ficha | Servidor | Notas |
|-------|-------|---------|-------|
| 365–378 | traccar/fleetbase/xibo/novosga/cardmesh | S13 | geo-espacial |
| 380–405 | gitlab/k6/trivy/bareos/velero/goss/pgbackrest-svc/searxng | S14 | operaciones |
| 410–430 | ollama/open-webui/qdrant/embedding-worker/langfuse/flowise/bcompass-svc | S15 | IA |

### Fichas sin execution_order aún (pendientes)

| Ficha | Servidor | Estado |
|-------|---------|--------|
| sbos-notifier | S06 | 🟡 285 l. (execution_order pendiente) |
| certbot | S16 | 🔴 sin manifest.yml |
| modsecurity | S16 | 🔴 sin manifest.yml |
| nginx | S16 | 🔴 sin manifest.yml |
| weblate | S16 | 🔴 sin manifest.yml |

---

## 5. Brechas por resolver — prioridad para llegar al VDI

### BC-07 — DbInitService (BLOQUEANTE para todo lo demás)

BOS debe inicializar SBOS_db inmediatamente después de postgresql C-04.

```
internal/domain/dbinit_service.go   ← lógica pura
internal/server/rpc_db.go           ← bos.db.init · bos.db.status
cmd/bosctl/db.go                    ← bosctl db init | db status
```

Nuevo criterio: **C-04b — SBOSDB inicializada** (bauth ≥ 130 tablas · bos ≥ 21 · bglobal ≥ 10)

### BC-08 — Context Plane completo

Sin heartbeat de dctx_id (30s TTL), sin rate limiting y sin auditoría, bAuth no puede funcionar.
Archivo: `internal/context/service.go` + `internal/server/rpc_ctx.go`

Nuevo criterio: **C-04c — Context Plane operativo**

### BC-09 — Ficha bauth (crear en SBOS/servers/)

```
servers/S03-identityserver/bauth/
  manifest.yml         ← identity, depends_on: [keycloak, vault, postgresql, kong], execution_order: 148
  task_catalog.sh      ← bauth_install, bauth_verify, bauth_health, bauth_repair
  PROPOSITO.md         ← obligatorio (servers.yml §4)
  resources/           ← systemd unit, socket perms
```

### BC-10 — Fichas bhnexus + banexus (crear en SBOS/servers/)

```
servers/S02-gatewayserver/bhnexus/
  manifest.yml         ← execution_order: 148, depends_on: [bauth, kong, vault], port: 9444
  task_catalog.sh

servers/S02-gatewayserver/banexus/
  manifest.yml         ← execution_order: 149, depends_on: [bhnexus], host=true (sin K8s)
  task_catalog.sh
```

### BC-11 — Completar STUBs del VDI (S11)

Las 4 fichas VDI (fedora-kde, nextcloud, guacamole, onlyoffice) necesitan:
1. `<app>.k8s.yml` — Deployment/StatefulSet real con recursos K8s
2. `<app>.volume` — PVC (nextcloud: 500Gi)
3. `resources/` — configuraciones, SQL schema si aplica
4. Lógica de `ficha_install()` real en task_catalog.sh (actualmente llama `sbos_k8s_core` genérico)

### BC-12 — Fichas daemons faltantes (crear en SBOS/servers/)

| Daemon | Servidor destino | execution_order sugerido |
|--------|-----------------|--------------------------|
| bnotify | S03-identityserver | 149 (después de bauth) |
| biedata | S01-dataserver | 117 (después de minio) |
| bsearch | S01-dataserver | 119 (después de citus) |
| bcompass | S15-aiserver | 431 (después de flowise) |
| bkernel (daemon) | S01-dataserver | 70 (o ajustar sbos-bkernel) |

### BC-13 — S16-webserver (agregar manifest.yml a cada ficha)

Las 4 fichas S16 tienen directorio pero sin manifest.yml. Ejecutan después del VDI.

---

## 6. Orden de implementación recomendado

```
BC-07  DbInitService (SBOS_db automática)
  ↓
BC-08  Context Plane completo
  ↓
BC-09  Ficha bauth en servers/
  ↓
BC-10  Fichas bhnexus + banexus
  ↓ (en paralelo:)
BC-11  Completar STUBs VDI (manifests K8s reales)
BC-12  Fichas bnotify + biedata + bsearch
  ↓
Verificar cadena completa en VPS (bosctl bootstrap verify --full)
  → C-01..C-08 ✅ + C-04b ✅ + C-04c ✅
  → bosctl ficha install fedora-kde → nextcloud → guacamole → onlyoffice
  → Criterios C-09..C-14
```

---

## 7. Criterios de éxito por etapa

| Criterio | Verificación |
|----------|-------------|
| C-01..C-03 | sbos-bootstrap-os/k8s/cni ✅ |
| C-04 | postgresql acepta conexiones |
| **C-04b** | bosctl db status → bauth≥130 tablas · bos≥21 |
| **C-04c** | ctx.create → dctx_id < 10ms · heartbeat 30s |
| C-05..C-08 | redis · vault · keycloak · kong ✅ |
| **C-09** | Nextcloud accesible via OIDC bAuth |
| **C-10** | Guacamole accesible via OIDC bAuth |
| **C-11** | ≥ 2 pods fedora-kde Running |
| **C-12** | Home montado (ls ~/Documentos) en sesión VDI |
| **C-13** | device.register < 2s P99 |
| **C-14** | test-user → NFC → GNOME < 10s → archivo persiste ✅ |

### Criterio final — VDI operativo

```
✦ "El SBOS está instalado":
  Ubuntu virgen → bosctl setup --mode=prod --seed seed-skull.yml
  T+~60 min:
    bosctl bootstrap verify --full → C-01..C-14 todos ✅
    Usuario NFC → LED chapa verde
    Browser: https://{dominio}/guacamole → sesión Fedora KDE abre
    Fedora: Nextcloud → editar documento OnlyOffice → guardar ✅
```

---

## 8. Resumen ejecutivo

| Aspecto | Realidad (verificada en disco) |
|---------|-------------------------------|
| Fichas declaradas en catálogo canónico | **131** (SBOS/servers/) |
| Fichas antes del VDI | **106** |
| Fichas VDI | **4** (todas como STUB) |
| Fichas robustas listas | **11** (BosAgent/src/servers/) |
| Daemons soberanos sin ficha | **8** (bauth · bnotify · bhnexus · banexus · biedata · bsearch · bcompass · bkernel) |
| Brechas bloqueantes | **7** (BC-07 a BC-13) |

**Ruta crítica mínima hacia el VDI:**

```
BC-07 → BC-08 → BC-09 → BC-10 → BC-11
  BD     Ctx    bAuth   NFC    VDI STUBs completos
```

Las capas intermedias (S04–S10: ERP, apps, reportes, comms) tienen fichas STUB.
El BOS puede instalarlas en orden topológico una vez que la infraestructura base (Capas 0–3)
esté verificada. Los STUBs funcionan para instalar la infraestructura del pod; lo que falta
es el contenido de configuración específico de cada app.

---

*Documento v2.0.0 — generado por bos-developer · verificación en disco: 2026-10-07*
*Fuente canónica: `SBOS/servers/` · Motor: `BosAgent/src/`*
