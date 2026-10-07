# Plan de Implementación BOS — De la Primera Ficha al VDI Operativo

**Versión:** 2.1.0  
**Fecha:** 2026-10-07  
**Autor:** bos-developer  
**Estado:** BC-07..BC-13 COMPLETOS — pendiente pruebas de instalación en VPS  
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

### 2.1 Catálogo real — post BC-07..BC-13

| Métrica | Valor |
|---------|-------|
| Fichas con `manifest.yml` en `SBOS/servers/` (canónico) | **143** (S00–S16) |
| Fichas con `task_catalog.sh` | **143** (100%) |
| Fichas antes del VDI (execution_order < 355) | **109** |
| Fichas VDI (execution_order 355–360) | **4** — fedora-kde · nextcloud · guacamole · onlyoffice |
| Fichas post-VDI (geo, ops, AI, S16…) | **30** |
| S16-webserver | **4 fichas completas** — nginx · certbot · modsecurity · weblate |
| Daemons soberanos sin ficha declarada | ~~8~~ → **0** — todos declarados |

### 2.2 Niveles de implementación del task_catalog.sh

| Nivel | Ubicación | Fichas | Descripción |
|-------|-----------|--------|-------------|
| **ROBUSTO** | `BosAgent/src/servers/` | 11 | 300–820 líneas · lógica K8s completa · verificadas en VPS |
| **COMPLETO** | `SBOS/servers/<Sxx>/` | 12 | k8s.yml + task_catalog.sh real + Secret/ConfigMap generados |
| **STUB** | `SBOS/servers/<Sxx>/` | ~120 | estructura correcta · manifests K8s pendientes de completar |

Las 11 fichas robustas (manual 1.01 §12.1 ✅):
`bos-preflight` · `sbos-bootstrap-os/k8s/cni/storage` · `sbos-namespace` · `postgresql` (820 l.) · `redis` (584 l.) · `vault` · `keycloak` · `kong`

Las 12 fichas completas (BC-09..BC-13 ✅ commits `6c4a456`..`76d1522`):
`bauth` · `bhnexus` · `banexus` · `fedora-kde` · `nextcloud` · `guacamole` · `onlyoffice` · `biedata` · `bnotify` · `bsearch` · `nginx (S16)` · `certbot · modsecurity · weblate`

### 2.3 Brechas resueltas (BC-07..BC-13)

| ID | Brecha | Estado | Commit |
|----|--------|--------|--------|
| **BC-07** | `DbInitService` no existía — DDLs manuales | ✅ RESUELTO | `377fb29` |
| **BC-08** | Context Plane sin sweeper/rate-limit | ✅ RESUELTO | `4c45f61` |
| **BC-09** | Ficha `bauth` no declarada | ✅ RESUELTO | `6c4a456` |
| **BC-10** | Fichas `bhnexus`/`banexus` no declaradas | ✅ RESUELTO | `7278bd8` |
| **BC-11** | Fichas VDI eran STUBs sin k8s.yml reales | ✅ RESUELTO | `b049fa3` |
| **BC-12** | Daemons soberanos sin ficha | ✅ RESUELTO | `61fac4d` |
| **BC-13** | S16-webserver sin manifest.yml | ✅ RESUELTO | `76d1522` |

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
| — | **DbInitService** | ✅ BC-07 | `DbInitService` automático tras C-04 — commit `377fb29` |
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
| 148 | **bauth** | ✅ BC-09 | S03 · SystemdService · /run/bos/bauth.sock — commit `6c4a456` |
| 152 | **bnotify** | ✅ BC-12 | S03 · SystemdService · /run/bos/bnotify.sock — commit `61fac4d` |

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
| 148 | **bhnexus** | ✅ BC-10 | S02 · SystemdService · port 9444 TLS + unix sock — commit `7278bd8` |
| 149 | **banexus** | ✅ BC-10 | S02 · SystemdService · Requires=bhnexus — commit `7278bd8` |

### CAPA 7 — VDI Server S11 (execution_order 355–360) — META PRINCIPAL

| Order | Ficha | Estado | Prerequisito real |
|-------|-------|--------|-------------------|
| 355 | fedora-kde | ✅ lscr.io/linuxserver/webtop:fedora-kde · noVNC :3000 · PVC 20Gi | bAuth OIDC |
| 357 | nextcloud | ✅ nextcloud:30.0-apache · PVC 500Gi · pre_install crea nextcloud_db | bAuth OIDC |
| 358 | guacamole | ✅ guacamole 1.5.5 · initdb.sh · OIDC ConfigMap | bAuth OIDC · guacamole_db |
| 358 | onlyoffice | ✅ onlyoffice/documentserver:8.2 · JWT · /healthcheck · PVC 50Gi | onlyoffice_db |

### Fichas post-VDI (S13–S15) — no bloquean el VDI

| Order | Ficha | Servidor | Notas |
|-------|-------|---------|-------|
| 365–378 | traccar/fleetbase/xibo/novosga/cardmesh | S13 | geo-espacial |
| 380–405 | gitlab/k6/trivy/bareos/velero/goss/pgbackrest-svc/searxng | S14 | operaciones |
| 410–430 | ollama/open-webui/qdrant/embedding-worker/langfuse/flowise/bcompass-svc | S15 | IA |

### Fichas sin execution_order aún (pendiente)

| Ficha | Servidor | Estado |
|-------|---------|--------|
| sbos-notifier | S06 | 🟡 285 l. (execution_order pendiente) |

---

## 5. Lo que falta para las pruebas de instalación

BC-07..BC-13 cierran todas las brechas de *declaración*. Lo que queda son brechas de
**compilación, despliegue y verificación** en el VPS real.

### PT-01 — BOS compilar y desplegar en VPS (PREREQUISITO GLOBAL)

BOS ya está corriendo en el VPS (`bos.service` activo, commit `c6d3b1e`).
Antes de cualquier prueba hay que recompilar con los cambios BC-07 y BC-08:

```bash
# En BosAgent/src/
CGO_ENABLED=0 /home/skull/sdk/go/bin/go build ./...
/home/skull/sdk/go/bin/go test -race -count=2 ./...
# Desplegar en VPS:
scp -r bin/bos root@13.140.128.230:/usr/local/bin/bos
systemctl restart bos.service
```

**Verificar:** `bosctl health` → `{"status":"ok"}` · `bosctl ctx create --tenant skull` → `ctx_id` válido

---

### PT-02 — Verificar cadena C-01..C-08 en VPS

Antes de instalar VDI, confirmar que la infraestructura base ya está operativa:

| Criterio | Comando de verificación | Estado esperado |
|----------|------------------------|-----------------|
| C-01 OS | `bosctl bootstrap status os` | ✅ running |
| C-02 K8s | `kubectl get nodes` | Ready |
| C-03 CNI | `kubectl get pods -n kube-system \| grep calico` | Running |
| C-04 PG | `kubectl exec -n sbos-data statefulset/postgresql -- psql -U postgres -c '\l'` | SBOSDB visible |
| **C-04b** | `bosctl db status` | bauth≥130 · bos≥21 tablas |
| **C-04c** | `bosctl ctx create --tenant skull` | dctx_id < 10ms |
| C-05 Redis | `kubectl exec -n sbos-data statefulset/redis -- redis-cli ping` | PONG |
| C-06 Vault | `kubectl exec -n sbos-gateway statefulset/vault -- vault status` | sealed=false |
| C-07 KC | `curl -sf https://SBOS_DOMAIN/auth/realms/skbos` | realm JSON |
| C-08 Kong | `kubectl exec -n sbos-gateway deployment/kong -- kong health` | alive |

**Bloqueo:** C-04b requiere BOS reiniciado con BC-07 (`DbInitService`). Si SBOSDB ya tiene las tablas desde migraciones manuales previas, `DbInitService` las detecta y no hace nada (idempotente).

---

### PT-03 — Compilar y desplegar daemons soberanos

Los daemons tienen ficha declarada pero sus **binarios** deben compilarse y copiarse al VPS antes de instalar:

| Daemon | Repositorio | Binario destino en VPS | Prerequisito |
|--------|-------------|------------------------|--------------|
| **bauth** | `BauthAgent/` | `/usr/local/bin/bauth` | PG + Vault + KC + Kong |
| **bhnexus** | `BnexusAgent/` (Rust MUSL) | `/usr/local/bin/bhnexus` | bauth activo |
| **banexus** | `BnexusAgent/` (Rust MUSL) | `/usr/local/bin/banexus` | bhnexus activo |
| **bkernel** | `BkernelAgent/` (Rust MUSL) | `/usr/local/bin/bkernel-daemon` | PG + Redis |
| **bnotify** | `BnotifyAgent/` (Rust MUSL) | `/usr/local/bin/bnotify` | bauth activo |
| **biedata** | `BiedataAgent/` | `/usr/local/bin/biedata` | bkernel + bauth |
| **bsearch** | `BintelligenceAgent/` | `/usr/local/bin/bsearch` | PG + bauth |

Comando tipo para daemon Rust:
```bash
cargo build --release --target x86_64-unknown-linux-musl
scp target/x86_64-unknown-linux-musl/release/<daemon> root@13.140.128.230:/usr/local/bin/
```

**Instalación via BOS (una vez binario copiado):**
```bash
bosctl ficha install bauth
bosctl ficha install bhnexus
bosctl ficha install banexus
```

---

### PT-04 — Instalar fichas VDI (ruta crítica)

Con la infraestructura base operativa (PT-01..PT-03), instalar las 4 fichas VDI en orden:

```bash
bosctl ficha install fedora-kde    # pre_install: crea namespace + Secret
bosctl ficha install nextcloud     # pre_install: crea nextcloud_db + Secret
bosctl ficha install guacamole     # pre_install: crea guacamole_db + schema + OIDC
bosctl ficha install onlyoffice    # pre_install: crea onlyoffice_db + JWT secret
```

**Verificaciones parciales:**
```bash
kubectl get pods -n sbos-vdi       # todos Running
bosctl ficha health fedora-kde     # :3000 responde
bosctl ficha health nextcloud      # /status.php responde
bosctl ficha health guacamole      # /api/languages responde
bosctl ficha health onlyoffice     # /healthcheck responde
```

---

### PT-05 — Prueba de extremo a extremo (criterio VDI operativo)

| Paso | Acción | Criterio de éxito |
|------|--------|-------------------|
| 1 | Presentar tarjeta NFC al lector | LED verde · banexus captura evento |
| 2 | banexus → bhnexus → bAuth | `device.register` < 2s · ctx_id creado |
| 3 | BOS genera sesión VDI | `bos.ctx.create` responde con `session_id` |
| 4 | Abrir browser `https://{dominio}/guacamole` | Pantalla login Guacamole visible |
| 5 | Login OIDC vía Keycloak → bAuth | JWT válido · token bitmask generado |
| 6 | Guacamole conecta a fedora-kde :3000 | Sesión Fedora KDE visible en browser |
| 7 | Montar Nextcloud en Fedora KDE | Carpeta `~/Nextcloud` accesible |
| 8 | Crear documento con OnlyOffice | Documento guardado · visible en Nextcloud |
| 9 | Cerrar sesión → guardar estado | Home persiste en PVC `fedora-kde-home` |

---

### PT-06 — Brechas de implementación pendientes (no bloquean prueba inicial)

Estas brechas no impiden la prueba de instalación básica pero deben resolverse antes de producción:

| ID | Descripción | Impacto |
|----|-------------|---------|
| **PT-06a** | `bosctl db status` no implementado aún en CLI (BC-07 solo tiene RPC) | Verificación manual de C-04b |
| **PT-06b** | `cert-rotation` (S00) no tiene CA configurada para bhnexus | bhnexus usa openssl fallback |
| **PT-06c** | ConfigMap OIDC de guacamole usa `SBOS_DOMAIN` — necesita el dominio real del tenant | Hardcodear en pre_install o inyectar vía BOS config |
| **PT-06d** | Fichas STUB Capa 2 (pgbouncer, pgbackrest, minio) no tienen k8s.yml | No bloquean VDI pero degradan robustez |
| **PT-06e** | `bcompass` está en S15 como K8s Deployment — binario no compilado | No bloquea VDI (es opcional AI) |

---

## 6. Orden de implementación recomendado

```
[COMPLETADO] BC-07..BC-13 — Todas las brechas de declaración cerradas

[SIGUIENTE] Pruebas de instalación:

PT-01  Recompilar BOS + desplegar en VPS
  ↓
PT-02  Verificar C-01..C-08 en VPS (infraestructura base)
  ↓
PT-03  Compilar y desplegar bAuth + bhnexus + banexus + bkernel
  ↓
PT-04  bosctl ficha install fedora-kde → nextcloud → guacamole → onlyoffice
  ↓
PT-05  Prueba end-to-end: NFC → bAuth → ctx_id → Guacamole → Fedora KDE → Nextcloud
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

| Aspecto | Estado actual |
|---------|--------------|
| Fichas declaradas en catálogo canónico | **143** (SBOS/servers/ S00–S16) |
| Fichas antes del VDI | **109** |
| Fichas VDI | **4** — todas con k8s.yml real ✅ |
| Fichas robustas listas | **11** (BosAgent/src/servers/) |
| Fichas completas BC-09..BC-13 | **12** nuevas ✅ |
| Daemons soberanos sin ficha | ~~8~~ → **0** ✅ |
| Brechas de declaración (BC-07..BC-13) | ~~7~~ → **0** ✅ |
| **Brechas de prueba (PT-01..PT-05)** | **5 pendientes** — ver §5 |

**Ruta crítica para pruebas:**

```
[OK] BC-07..BC-13 — declaración completa

[AHORA] PT-01 recompilar BOS
          ↓
        PT-02 verificar C-01..C-08 en VPS
          ↓
        PT-03 compilar + desplegar bAuth · bhnexus · banexus · bkernel
          ↓
        PT-04 bosctl ficha install (4 fichas VDI)
          ↓
        PT-05 prueba NFC → Guacamole → Fedora KDE → Nextcloud ✅
```

Las capas intermedias (S04–S10: ERP, apps, reportes, comms) tienen fichas STUB.
BOS puede instalarlas en orden topológico una vez que la infraestructura base (Capas 0–3)
esté verificada y PT-05 pase.

---

*Documento v2.1.0 — actualizado bos-developer · 2026-10-07 · BC-07..BC-13 completados*
*Fuente canónica: `SBOS/servers/` · Motor: `BosAgent/src/`*
