# SBOS-036-PRODUCTS
## Especificación de Productos: Manifiestos de Soluciones — Estándar HUMAN-DOC
### SKULL · SBOS · v1.0 · Abril 2026

---

## 1. Concepto de Producto

Un Producto es un **manifiesto de solución** que declara qué fichas necesita y qué configuraciones debe aplicar para entregar una capacidad completa de negocio. No es código — es una declaración de intención.

Según las mejores prácticas de la industria en application packaging enterprise, un producto bien definido debe incluir: descubrimiento de dependencias, empaquetado con todas las configuraciones, testing de aceptación (UAT), y despliegue por fases. El concepto de Producto del SBOS implementa estos principios con un modelo declarativo: el instalador lee el manifiesto, evalúa el estado actual, y para cada ficha participante decide si instalar, ampliar configuración, o saltar.

### 3 Niveles del Instalador

```
NIVEL 1 — FICHA (unidad atómica)
  bosctl install <ficha>
  Una aplicación. Se instala igual siempre.

NIVEL 2 — PRODUCTO (manifiesto de solución)
  bosctl product install <producto>
  Agrupa fichas + configuraciones para solución completa.
  Evalúa qué existe, amplía lo faltante, instala lo nuevo.

NIVEL 3 — DEPLOY (manifiesto del cliente)
  bosctl deploy <archivo.yml>
  Agrupa productos + datos empresa.
  Instalación completa punta a punta.
```

## 2. Estructura del Manifiesto YAML

```yaml
product:
  name: "<nombre>"
  description: "<descripción>"
  version: "<semver>"
  category: "platform | communication | business | intelligence | operations"
  auto_install: false         # true solo para bootstrap
  optional: false             # true = criticality false (ej: ai)

requirements:                 # configuraciones sobre fichas ya instaladas
  - ficha: "<nombre>"
    needs:
      databases: [{ name: "<db>", owner: "<user>" }]
      users: [{ name: "<user>", privileges: ["<db>:ALL"] }]
      clients: [{ client_id: "<id>", realm: "sbos", redirect_uris: [...] }]
      routes: [{ name: "<ruta>", paths: [...], service_host: "...", plugins: ["oauth2"] }]
      secrets: [{ path: "secret/...", description: "..." }]
      buckets: [{ name: "<bucket>" }]

fichas:                       # fichas nuevas que el producto instala
  - ficha: "<nombre>"
    params: { key: "value" }

verify:                       # checks post-instalación
  - check: "<tipo>"
    description: "<qué verifica>"
```

Procesamiento: leer manifiesto → evaluar requirements (lo que falta → crear, lo que existe → skip) → instalar fichas nuevas (idempotente) → ejecutar verify → registrar en .sbos_state.json.

## 3. Catálogo de 8 Productos

### 3.1 bootstrap — Sistema Base (platform, auto_install: true)
16 fichas (SBOS-035). ~48 min. Único con auto_install. Sin requirements (es primero).
```yaml
fichas: [sbos-bootstrap-os, sbos-bootstrap-k8s, sbos-bootstrap-platform, 
  sbos-k8s-network-validator, postgresql, redis, minio, vault, keycloak,
  nginx, kong, linkerd, kyverno, prometheus, grafana, sbos-bootstrap-hardening]
verify: [cis_benchmark, all_health_checks 16/16]
```

### 3.2 mail — Correo Corporativo (communication)
4 fichas: mailserver, postfixadmin, roundcube, cypht. ~12 min.
```yaml
requirements:
  postgresql: { databases: [mail_db, postfixadmin_db], users: [mailserver, postfixadmin] }
  keycloak: { clients: [roundcube, cypht] }
  kong: { routes: [webmail → /mail, mail-admin → /postfixadmin] }
  vault: { secrets: [dkim keys, mail credentials] }
fichas:
  - mailserver: { domains: ["{{MAIL_DOMAIN}}"], dkim: true, tls: "vault-pki" }
  - postfixadmin, roundcube (oauth2), cypht (oauth2)
verify: [smtp_send, imap_receive, webmail_oauth_login]
```

### 3.3 erp — ERP y Contabilidad (business)
2 fichas: tryton, tryton-workers. ~8 min.
```yaml
requirements:
  postgresql: { databases: [tryton_db] }
  keycloak: { clients: [tryton] }
  kong: { routes: [erp → /erp] }
fichas:
  - tryton: { country: "{{COUNTRY}}", chart_of_accounts: "{{CHART_OF_ACCOUNTS}}", currency: "{{CURRENCY}}" }
  - tryton-workers: { worker_count: 2 }
verify: [http_health, oauth_login]
```

### 3.4 documents — Gestión Documental (business)
5 fichas: paperless-ngx, tesseract-ocr, docuseal, kimios, tabula. ~10 min.
```yaml
requirements:
  postgresql: { databases: [paperless_db, docuseal_db] }
  keycloak: { clients: [paperless, docuseal] }
  kong: { routes: [documents → /docs, signing → /sign] }
  minio: { buckets: [documents, signed-documents] }
fichas:
  - paperless-ngx: { ocr_languages: ["spa", "eng"], storage_backend: "minio" }
  - tesseract-ocr, tabula, kimios, docuseal
verify: [upload_document, ocr_extraction, digital_signature]
```

### 3.5 monitoring — Observabilidad Extendida (operations)
4 fichas: loki, tempo, alertmanager, zabbix. ~8 min. Extiende prometheus+grafana del bootstrap.
```yaml
requirements:
  postgresql: { databases: [zabbix_db] }
  keycloak: { clients: [grafana, zabbix] }
fichas:
  - loki: { retention_days: 30 }
  - tempo: { retention_days: 7 }
  - alertmanager: { notify_email: "{{ADMIN_EMAIL}}" }
  - zabbix
verify: [logs_ingestion, traces_ingestion, alerting_test]
```

### 3.6 vdi — Escritorio Virtual Soberano (platform)
4 fichas: fedora-kde-sbos, nextcloud, onlyoffice, sbos-vdi-config. ~15 min.
```yaml
requirements:
  postgresql: { databases: [nextcloud_db, onlyoffice_db] }
  keycloak: { clients: [nextcloud, onlyoffice] }
  kong: { routes: [cloud → /cloud] }
  minio: { buckets: [nextcloud-data] }
fichas:
  - fedora-kde-sbos: { control: "bauth+banexus" }
  - nextcloud: { storage_backend: "minio" }
  - onlyoffice
  - sbos-vdi-config: { branding: "{{BRANDING}}" }
verify: [desktop_session, nextcloud_access, onlyoffice_edit]
```

### 3.7 ai — Inteligencia Artificial Soberana (intelligence, optional: true)
6 fichas: ollama, qdrant, open-webui, embedding-worker, langfuse, flowise. ~12 min. Todas criticality: false.
```yaml
requirements:
  postgresql: { databases: [langfuse_db] }
  kong: { routes: [ai-chat → /ai] }
fichas:
  - ollama: { model: "qwen3:8b", gpu: "auto-detect" }
  - qdrant
  - open-webui (oauth2)
  - embedding-worker: { model: "nomic-embed-text" }
  - langfuse, flowise
verify: [llm_inference, vector_search, webui_access]
```

### 3.8 devops — CI/CD y Backup (operations)
3 fichas: gitlab, bareos, velero. ~15 min. Se instala AL FINAL (necesita todo el stack para backup).
```yaml
requirements:
  postgresql: { databases: [gitlab_db] }
  keycloak: { clients: [gitlab] }
  kong: { routes: [gitlab → /gitlab] }
  minio: { buckets: [gitlab-artifacts, bareos-backups, velero-backups] }
fichas:
  - gitlab: { runners: 2 }
  - bareos
  - velero: { backup_schedule: "0 2 * * *", retention_days: 30 }
verify: [gitlab_access, backup_test, restore_test]
```

## 4. Resumen del Catálogo

| Producto | Categoría | Fichas | Requirements | Tiempo | Opcional |
|---|---|---|---|---|---|
| bootstrap | platform | 16 | (ninguno) | ~48 min | No |
| mail | communication | 4 | PG + KC + Kong + Vault | ~12 min | No |
| erp | business | 2 | PG + KC + Kong | ~8 min | No |
| documents | business | 5 | PG + KC + Kong + MinIO | ~10 min | No |
| monitoring | operations | 4 | PG + KC | ~8 min | No |
| vdi | platform | 4 | PG + KC + Kong + MinIO | ~15 min | No |
| ai | intelligence | 6 | PG + Kong | ~12 min | Sí |
| devops | operations | 3 | PG + KC + Kong + MinIO | ~15 min | No |

**Patrón:** todos dependen de postgresql + keycloak → bootstrap es prerequisito obligatorio.

## 5. Variables y Resolución

| Variable | Origen | Ejemplo |
|---|---|---|
| {{DOMAIN}} | deploy.yml | skull.io |
| {{MAIL_DOMAIN}} | deploy.yml | skull.io |
| {{ADMIN_EMAIL}} | deploy.yml | admin@skull.io |
| {{COUNTRY}} | deploy.yml | BO |
| {{CURRENCY}} | Derivado de country | BOB |
| {{CHART_OF_ACCOUNTS}} | Derivado de country | bo_puct |
| {{BRANDING}} | deploy.yml | Objeto con colores, logo |

Variable no definida → instalador solicita por CLI antes de continuar.

## 6. Estructura de Archivos

```
/etc/bos/
├── bos.toml
├── .sbos_state.json          ← incluye products.{nombre}.status
├── blibs/servers/            ← fichas (no cambian)
└── products/                 ← manifiestos de producto
    ├── bootstrap.product.yml
    ├── mail.product.yml
    ├── erp.product.yml
    ├── documents.product.yml
    ├── monitoring.product.yml
    ├── vdi.product.yml
    ├── ai.product.yml
    └── devops.product.yml
```

---

## Trazabilidad

| Sección | Extraída de | Secciones originales |
|---|---|---|
| §1 Concepto | SBOS-032 v1.0 + investigación web | §1-§2 (definición producto, 3 niveles) + industry best practices application packaging |
| §2 Estructura YAML | SBOS-032 v1.0 | §3 (schema completo del manifiesto con todos los campos) |
| §3 Catálogo | SBOS-032 v1.0 | §4 completo (8 productos con YAML, requirements, fichas, verify, tiempos) |
| §4 Resumen | SBOS-032 v1.0 | §8 (tabla resumen con patrón de dependencias) |
| §5 Variables | SBOS-032 v1.0 | §6 (tabla de variables + resolución) |
| §6 Archivos | SBOS-032 v1.0 | §7 (estructura /etc/bos/) |

---

---

# ENRIQUECIMIENTO V8 — SBOS-036-PRODUCTS

## V5 — Enriquecimiento desde BOS_V5_SBOS-032-PRODUCTS-v1_0

### V5 §1 — Manifiestos YAML Completos de Productos

**Producto bootstrap (extendido):**
```yaml
product:
  name: "bootstrap"
  description: "Sistema base SBOS — Kubernetes, almacenamiento, identidad, observabilidad"
  version: "1.0.0"
  category: "platform"
  auto_install: true
  optional: false
  fichas:
    - ficha: sbos-bootstrap-os
      params: { crio_version: "1.30", kubernetes_version: "1.30" }
    - ficha: sbos-bootstrap-k8s
      params: { pod_network_cidr: "10.244.0.0/16", service_cidr: "10.96.0.0/12" }
    - ficha: sbos-bootstrap-platform
      params: { namespaces: 14, linkerd_inject: true }
    - ficha: sbos-k8s-network-validator
    - ficha: postgresql
      params: { version: "17", pool_size: 100 }
    - ficha: redis
    - ficha: minio
      params: { buckets: [backups, uploads, archives] }
    - ficha: vault
      params: { unseal_threshold: 3, unseal_keys: 5 }
    - ficha: keycloak
      params: { realm: "sbos", features: "preview" }
    - ficha: nginx
    - ficha: kong
    - ficha: linkerd
    - ficha: kyverno
    - ficha: prometheus
      params: { retention_days: 30 }
    - ficha: grafana
    - ficha: sbos-bootstrap-hardening
  verify:
    - check: cis_benchmark
      description: "42/42 PASS CIS Level 1"
    - check: health_all
      description: "16/16 health checks OK"
```

**Producto vdi (extendido):**
```yaml
product:
  name: "vdi"
  description: "Escritorio Virtual Soberano — Fedora KDE + Nextcloud + OnlyOffice"
  version: "1.0.0"
  category: "platform"
  optional: false
  requirements:
    databases:
      - name: nextcloud_db
        owner: nextcloud
      - name: onlyoffice_db
        owner: onlyoffice
    clients:
      - client_id: nextcloud
        redirect_uris: ["https://{{DOMAIN}}/cloud/*"]
      - client_id: onlyoffice
        redirect_uris: ["https://{{DOMAIN}}/onlyoffice/*"]
    routes:
      - name: cloud
        paths: ["/cloud"]
        service_host: "nextcloud.sbos-documents.svc.cluster.local"
        plugins: ["oauth2"]
    buckets:
      - name: nextcloud-data
  fichas:
    - ficha: fedora-kde-sbos
      params: { control: "bauth+banexus", usb_bootable: true }
    - ficha: nextcloud
      params: { storage_backend: "minio", default_quota: "10GB" }
    - ficha: onlyoffice
      params: { jwt_secret_from_vault: "secret/vdi/onlyoffice/jwt" }
    - ficha: sbos-vdi-config
      params: { branding: "{{BRANDING}}", welcome_message: "Bienvenido a {{company_name}}" }
  verify:
    - check: desktop_session
      description: "VDI desktop reachable via Kasm"
    - check: nextcloud_access
      description: "Nextcloud login OK via OAuth2"
    - check: onlyoffice_edit
      description: "Document edit in OnlyOffice from Nextcloud"
```

### V5 §2 — Requisitos Técnicos por Producto

| Producto | PG DBs | KC Clients | Kong Routes | MinIO Buckets | Vault Paths |
|---|---|---|---|---|---|
| bootstrap | 5 | 0 | 0 | 3 | PKI, unseal |
| mail | 2 | 2 | 2 | 0 | DKIM, mail creds |
| erp | 1 | 1 | 1 | 0 | tryton secret |
| documents | 2 | 2 | 2 | 2 | docuseal secret |
| monitoring | 1 | 2 | 0 | 0 | grafana admin |
| vdi | 2 | 2 | 1 | 1 | onlyoffice jwt |
| ai | 1 | 0 | 1 | 0 | (ninguno) |
| devops | 1 | 1 | 1 | 3 | gitlab runner token |

---

## Smart* — Enriquecimiento desde Subproyectos SBOS

### Smart Portfolio — SBOS-Portfolio-014-GENERACION

El producto bportfolio produce 4 formatos de salida:
1. **Catálogo PDF completo** (WeasyPrint + Jinja2, A4, 300dpi)
2. **Ficha individual de producto** (A5, generación sincrónica < 3s)
3. **Catálogo web** (HTML dinámico desde BD, responsive, mobile-first)
4. **Excel lista de precios** (openpyxl, formato contable)

**Gestión de templates por empresa:**
- Herencia: empresa → tenant → global
- Templates Jinja2 con variables CSS corporativas (`--color-primario`, `--color-secundario`)
- Imágenes referencian URLs de MinIO (WeasyPrint las descarga al generar)

### Smart ORC — BOSORC-008-SEGURIDAD

El producto SmartORC se integra como un servicio de correspondencia que requiere:
- Bits ORCMask 20-24 en BitmaskBundle
- Canal Centrifugo para notificaciones en tiempo real
- Integración con bKernel para audit_events
- Rocket.Chat para canales de comunicación por clasificación de documento

### Smart Vault Flow — SBOS-VAULT-009-OPERACION

El producto SmartVault Flow se materializa como bvault con:
- Almacenamiento en Nextcloud para archivos de activos
- Integración con HashiCorp Vault para claves RSA
- Centrifugo para notificaciones de flujo de aprobación
- pgBackRest para backup de bvault_db

---

## Fuentes de Enriquecimiento V8

| Fuente | Archivo | Secciones utilizadas |
|---|---|---|
| V6 original | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V6_SBOS-036-PRODUCTS.md` | Documento completo (238 líneas) |
| V5 Products | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-032-PRODUCTS-v1_0.md` | §1 Manifiestos YAML bootstrap/vdi extendidos, §2 Requisitos técnicos por producto |
| SmartPortfolio Generación | `/opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Portfolio/context/SBOS-Portfolio-014-GENERACION.md` | 4 formatos de salida, templates Jinja2, gestión por empresa |
| SmartORC Seguridad | `/opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart ORC/context/BOSORC-008-SEGURIDAD.md` | Integración con Centrifugo, bKernel, Rocket.Chat |
| SmartVault Operación | `/opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Vault Flow/context/SBOS-VAULT-009-OPERACION.md` | Almacenamiento Nextcloud, Vault RSA, Centrifugo, pgBackRest |

---

_SKULL · SBOS · SBOS-036-PRODUCTS · V8 (V6+V5+Smart*) · Mayo 2026_
