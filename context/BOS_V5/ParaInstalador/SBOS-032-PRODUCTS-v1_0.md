# SBOS-032-PRODUCTS
## Especificación de Productos — Manifiestos de Soluciones del SBOS

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

**Código:** SBOS-032
**Estado:** NUEVO
**Clasificación:** Especificación de Instalación — Productos y Soluciones
**Dependencias documentales:** SBOS-005 (Installer), SBOS-006 (Fichas), SBOS-016 (Servidores), SBOS-031 (Rutina de Instalación)

---

## 1. ¿Qué es un Producto?

Un Producto es un **manifiesto de solución** que le dice al instalador qué fichas necesita y qué configuraciones debe aplicar para entregar una capacidad completa de negocio. No es código — es una declaración de intención.

Las fichas no cambian. PostgreSQL es PostgreSQL. Keycloak es Keycloak. Lo que el producto define es: "para tener correo corporativo, necesito que PostgreSQL tenga estas bases de datos, que Keycloak tenga estos clients, que Kong tenga estas rutas, y necesito instalar estas fichas nuevas."

El instalador lee el manifiesto, evalúa el estado actual del sistema, y decide por cada ficha participante:

- **No existe** → la instala completa
- **Existe pero su configuración no es suficiente** → inyecta lo que falta
- **Existe y ya tiene todo lo necesario** → la salta

El instalador ya tiene toda la información para tomar esta decisión — el `STATE_MANAGER`, el `HEALTH_CHECKER` y el `RECONCILE_SCHEDULER` saben qué está instalado, qué configuración tiene y qué estado tiene cada ficha.

---

## 2. Los Tres Niveles del Instalador

```
NIVEL 1 — FICHA (unidad atómica)
  bosctl install <ficha>
  Una aplicación. Se instala igual siempre.
  Ejemplo: bosctl install postgresql

NIVEL 2 — PRODUCTO (manifiesto de solución)
  bosctl product install <producto>
  Agrupa fichas + configuraciones para una solución completa.
  Evalúa qué existe, amplía lo que falta, instala lo nuevo.
  Ejemplo: bosctl product install mail

NIVEL 3 — DEPLOY (manifiesto del cliente)
  bosctl deploy <archivo.yml>
  Agrupa productos + datos de la empresa.
  Instalación completa de punta a punta.
  Ejemplo: bosctl deploy skull-empresa.deploy.yml
```

Este documento especifica el Nivel 2. El Nivel 3 se especifica en SBOS-033-DEPLOY.

---

## 3. Estructura del Manifiesto de Producto

```yaml
# products/<nombre>.product.yml
product:
  name: "<nombre>"
  description: "<descripción para el admin>"
  version: "<versión del producto>"
  category: "<categoría>"     # platform | communication | business | intelligence | operations

# Qué necesita de fichas que pueden ya estar instaladas
requirements:
  - ficha: "<nombre_ficha>"
    needs:
      databases:              # bases de datos que necesita en PostgreSQL
        - name: "<nombre_db>"
          owner: "<usuario>"
      users:                  # usuarios que necesita en PostgreSQL
        - name: "<usuario>"
          privileges: ["<db>:ALL"]
      clients:                # clients que necesita en Keycloak
        - client_id: "<id>"
          realm: "sbos"
          redirect_uris: ["..."]
      routes:                 # rutas que necesita en Kong
        - name: "<nombre>"
          paths: ["/..."]
          service_host: "<servicio>.sbos-<ns>.svc"
          service_port: <puerto>
          plugins: ["oauth2"]
      secrets:                # secretos que necesita en Vault
        - path: "secret/<producto>/..."
          description: "..."
      buckets:                # buckets que necesita en MinIO
        - name: "<nombre>"

# Fichas que el producto instala (las que no existen)
fichas:
  - ficha: "<nombre_ficha>"
    params:                   # parámetros específicos para esta instalación
      key: "value"

# Verificaciones post-instalación
verify:
  - check: "<tipo_check>"
    description: "<qué verifica>"
```

---

## 4. Catálogo de Productos

### 4.1 bootstrap — Sistema Base

| Campo | Valor |
|-------|-------|
| **Categoría** | platform |
| **Auto-install** | Sí — se ejecuta automáticamente al primer arranque |
| **Fichas** | 16 fichas (ver SBOS-031-INSTALL-ROUTINE) |
| **Tiempo** | ~48 minutos |

Este producto es especial: es el único con `auto_install: true`. El daemon `bos` lo ejecuta automáticamente al detectar que no hay cluster K8s. No tiene `requirements` porque es el primero — no hay nada preexistente.

```yaml
# products/bootstrap.product.yml
product:
  name: "bootstrap"
  description: "Sistema Base SBOS — Ubuntu + Kubernetes + Infraestructura"
  version: "1.0"
  category: "platform"
  auto_install: true

fichas:
  - ficha: "sbos-bootstrap-os"
  - ficha: "sbos-bootstrap-k8s"
  - ficha: "sbos-bootstrap-platform"
  - ficha: "sbos-k8s-network-validator"
  - ficha: "postgresql"
  - ficha: "redis"
  - ficha: "minio"
  - ficha: "vault"
  - ficha: "keycloak"
  - ficha: "nginx"
  - ficha: "kong"
  - ficha: "linkerd"
  - ficha: "kyverno"
  - ficha: "prometheus"
  - ficha: "grafana"
  - ficha: "sbos-bootstrap-hardening"

verify:
  - check: "cis_benchmark"
    description: "kube-bench CIS Level 1 todos PASS"
  - check: "all_health_checks"
    description: "16/16 fichas en INSTALADA_OK"
```

---

### 4.2 mail — Correo Corporativo

| Campo | Valor |
|-------|-------|
| **Categoría** | communication |
| **Depende de** | bootstrap |
| **Fichas nuevas** | mailserver, postfixadmin, roundcube, cypht |
| **Servidor lógico** | commsserver (S10) |
| **Tiempo** | ~12 minutos |

```yaml
# products/mail.product.yml
product:
  name: "mail"
  description: "Servidor de Correo Corporativo"
  version: "1.0"
  category: "communication"

requirements:
  - ficha: "postgresql"
    needs:
      databases:
        - name: "mail_db"
          owner: "mailserver"
        - name: "postfixadmin_db"
          owner: "postfixadmin"
      users:
        - name: "mailserver"
          privileges: ["mail_db:ALL"]
        - name: "postfixadmin"
          privileges: ["postfixadmin_db:ALL"]

  - ficha: "keycloak"
    needs:
      clients:
        - client_id: "roundcube"
          realm: "sbos"
          redirect_uris: ["https://{{DOMAIN}}/mail/*"]
          protocol: "openid-connect"
        - client_id: "cypht"
          realm: "sbos"
          redirect_uris: ["https://{{DOMAIN}}/cypht/*"]
          protocol: "openid-connect"

  - ficha: "kong"
    needs:
      routes:
        - name: "webmail"
          paths: ["/mail"]
          service_host: "roundcube.sbos-comms.svc"
          service_port: 8080
          plugins: ["oauth2"]
        - name: "mail-admin"
          paths: ["/postfixadmin"]
          service_host: "postfixadmin.sbos-comms.svc"
          service_port: 8080
          plugins: ["oauth2"]

  - ficha: "vault"
    needs:
      secrets:
        - path: "secret/mail/dkim"
          description: "DKIM private keys por dominio"
        - path: "secret/mail/credentials"
          description: "Credenciales de servicios de correo"

fichas:
  - ficha: "mailserver"
    params:
      domains: ["{{MAIL_DOMAIN}}"]
      dkim: true
      tls: "vault-pki"
  - ficha: "postfixadmin"
    params:
      db_name: "postfixadmin_db"
  - ficha: "roundcube"
    params:
      oauth2_client: "roundcube"
      imap_host: "mailserver.sbos-comms.svc"
  - ficha: "cypht"
    params:
      oauth2_client: "cypht"

verify:
  - check: "smtp_send"
    description: "Enviar correo de prueba"
  - check: "imap_receive"
    description: "Recibir correo en buzón"
  - check: "webmail_oauth_login"
    description: "Login OAuth2 en Roundcube"
```

---

### 4.3 erp — ERP y Contabilidad

| Campo | Valor |
|-------|-------|
| **Categoría** | business |
| **Depende de** | bootstrap |
| **Fichas nuevas** | tryton, tryton-workers |
| **Servidor lógico** | erpserver (S04) |
| **Tiempo** | ~8 minutos |

```yaml
# products/erp.product.yml
product:
  name: "erp"
  description: "ERP y Contabilidad — Tryton"
  version: "1.0"
  category: "business"

requirements:
  - ficha: "postgresql"
    needs:
      databases:
        - name: "tryton_db"
          owner: "tryton"
      users:
        - name: "tryton"
          privileges: ["tryton_db:ALL"]

  - ficha: "keycloak"
    needs:
      clients:
        - client_id: "tryton"
          realm: "sbos"
          redirect_uris: ["https://{{DOMAIN}}/erp/*"]
          protocol: "openid-connect"

  - ficha: "kong"
    needs:
      routes:
        - name: "erp"
          paths: ["/erp"]
          service_host: "tryton.sbos-erp.svc"
          service_port: 8000
          plugins: ["oauth2"]

fichas:
  - ficha: "tryton"
    params:
      country: "{{COUNTRY}}"
      chart_of_accounts: "{{CHART_OF_ACCOUNTS}}"
      currency: "{{CURRENCY}}"
  - ficha: "tryton-workers"
    params:
      worker_count: 2

verify:
  - check: "http_health"
    description: "Tryton responde en /erp"
  - check: "oauth_login"
    description: "Login OAuth2 en Tryton"
```

---

### 4.4 documents — Gestión Documental

| Campo | Valor |
|-------|-------|
| **Categoría** | business |
| **Depende de** | bootstrap |
| **Fichas nuevas** | paperless-ngx, tesseract-ocr, docuseal, kimios, tabula |
| **Servidor lógico** | docserver (S08) |
| **Tiempo** | ~10 minutos |

```yaml
# products/documents.product.yml
product:
  name: "documents"
  description: "Gestión Documental — Captura, OCR, Firma, Archivo"
  version: "1.0"
  category: "business"

requirements:
  - ficha: "postgresql"
    needs:
      databases:
        - name: "paperless_db"
          owner: "paperless"
        - name: "docuseal_db"
          owner: "docuseal"
      users:
        - name: "paperless"
          privileges: ["paperless_db:ALL"]
        - name: "docuseal"
          privileges: ["docuseal_db:ALL"]

  - ficha: "keycloak"
    needs:
      clients:
        - client_id: "paperless"
          realm: "sbos"
          redirect_uris: ["https://{{DOMAIN}}/docs/*"]
        - client_id: "docuseal"
          realm: "sbos"
          redirect_uris: ["https://{{DOMAIN}}/sign/*"]

  - ficha: "kong"
    needs:
      routes:
        - name: "documents"
          paths: ["/docs"]
          service_host: "paperless.sbos-docs.svc"
          service_port: 8000
          plugins: ["oauth2"]
        - name: "signing"
          paths: ["/sign"]
          service_host: "docuseal.sbos-docs.svc"
          service_port: 3000
          plugins: ["oauth2"]

  - ficha: "minio"
    needs:
      buckets:
        - name: "documents"
        - name: "signed-documents"

fichas:
  - ficha: "paperless-ngx"
    params:
      ocr_languages: ["spa", "eng"]
      storage_backend: "minio"
  - ficha: "tesseract-ocr"
  - ficha: "tabula"
  - ficha: "kimios"
  - ficha: "docuseal"

verify:
  - check: "upload_document"
    description: "Subir documento PDF"
  - check: "ocr_extraction"
    description: "OCR extrae texto correctamente"
  - check: "digital_signature"
    description: "Firma digital funcional"
```

---

### 4.5 monitoring — Observabilidad Extendida

| Campo | Valor |
|-------|-------|
| **Categoría** | operations |
| **Depende de** | bootstrap (prometheus y grafana ya incluidos) |
| **Fichas nuevas** | loki, tempo, alertmanager, zabbix |
| **Servidor lógico** | monitorserver (S12) |
| **Tiempo** | ~8 minutos |

```yaml
# products/monitoring.product.yml
product:
  name: "monitoring"
  description: "Observabilidad Extendida — Logs, Traces, Alertas, Infraestructura"
  version: "1.0"
  category: "operations"

requirements:
  - ficha: "postgresql"
    needs:
      databases:
        - name: "zabbix_db"
          owner: "zabbix"
      users:
        - name: "zabbix"
          privileges: ["zabbix_db:ALL"]

  - ficha: "keycloak"
    needs:
      clients:
        - client_id: "grafana"
          realm: "sbos"
          redirect_uris: ["https://{{DOMAIN}}/grafana/*"]
        - client_id: "zabbix"
          realm: "sbos"
          redirect_uris: ["https://{{DOMAIN}}/zabbix/*"]

fichas:
  - ficha: "loki"
    params:
      retention_days: 30
  - ficha: "tempo"
    params:
      retention_days: 7
  - ficha: "alertmanager"
    params:
      notify_email: "{{ADMIN_EMAIL}}"
  - ficha: "zabbix"
    params:
      db_name: "zabbix_db"

verify:
  - check: "logs_ingestion"
    description: "Loki recibe logs de todos los pods"
  - check: "traces_ingestion"
    description: "Tempo recibe traces"
  - check: "alerting_test"
    description: "Alertmanager dispara alerta de prueba"
```

---

### 4.6 vdi — Escritorio Virtual Soberano

| Campo | Valor |
|-------|-------|
| **Categoría** | platform |
| **Depende de** | bootstrap |
| **Fichas nuevas** | fedora-kde-sbos, nextcloud, onlyoffice, sbos-vdi-config |
| **Servidor lógico** | vdiserver (S11) |
| **Tiempo** | ~15 minutos |

```yaml
# products/vdi.product.yml
product:
  name: "vdi"
  description: "Escritorio Virtual Soberano — SBOS VDI"
  version: "1.0"
  category: "platform"

requirements:
  - ficha: "postgresql"
    needs:
      databases:
        - name: "nextcloud_db"
          owner: "nextcloud"
        - name: "onlyoffice_db"
          owner: "onlyoffice"
      users:
        - name: "nextcloud"
          privileges: ["nextcloud_db:ALL"]
        - name: "onlyoffice"
          privileges: ["onlyoffice_db:ALL"]

  - ficha: "keycloak"
    needs:
      clients:
        - client_id: "nextcloud"
          realm: "sbos"
          redirect_uris: ["https://{{DOMAIN}}/cloud/*"]
        - client_id: "onlyoffice"
          realm: "sbos"
          redirect_uris: ["https://{{DOMAIN}}/office/*"]

  - ficha: "kong"
    needs:
      routes:
        - name: "cloud"
          paths: ["/cloud"]
          service_host: "nextcloud.sbos-vdi.svc"
          service_port: 80
          plugins: ["oauth2"]

  - ficha: "minio"
    needs:
      buckets:
        - name: "nextcloud-data"

fichas:
  - ficha: "fedora-kde-sbos"
    params:
      control: "bauth+banexus"
  - ficha: "nextcloud"
    params:
      storage_backend: "minio"
  - ficha: "onlyoffice"
  - ficha: "sbos-vdi-config"
    params:
      branding: "{{BRANDING}}"

verify:
  - check: "desktop_session"
    description: "Iniciar sesión en escritorio Fedora KDE controlado por bAuth"
  - check: "nextcloud_access"
    description: "Acceder a archivos desde Nextcloud"
  - check: "onlyoffice_edit"
    description: "Editar documento en OnlyOffice"
```

---

### 4.7 ai — Inteligencia Artificial Soberana

| Campo | Valor |
|-------|-------|
| **Categoría** | intelligence |
| **Depende de** | bootstrap |
| **Fichas nuevas** | ollama, qdrant, open-webui, embedding-worker, langfuse, flowise |
| **Servidor lógico** | aiserver (S15) |
| **Tiempo** | ~12 minutos |
| **Opcional** | Sí — `criticality: false` en todas las fichas |

```yaml
# products/ai.product.yml
product:
  name: "ai"
  description: "Inteligencia Artificial Soberana"
  version: "1.0"
  category: "intelligence"
  optional: true

requirements:
  - ficha: "postgresql"
    needs:
      databases:
        - name: "langfuse_db"
          owner: "langfuse"
      users:
        - name: "langfuse"
          privileges: ["langfuse_db:ALL"]

  - ficha: "kong"
    needs:
      routes:
        - name: "ai-chat"
          paths: ["/ai"]
          service_host: "open-webui.sbos-ai.svc"
          service_port: 8080
          plugins: ["oauth2"]

fichas:
  - ficha: "ollama"
    params:
      model: "qwen3:8b"
      gpu: "auto-detect"
  - ficha: "qdrant"
  - ficha: "open-webui"
  - ficha: "embedding-worker"
    params:
      model: "nomic-embed-text"
  - ficha: "langfuse"
  - ficha: "flowise"

verify:
  - check: "llm_inference"
    description: "Ollama responde a prompt de prueba"
  - check: "vector_search"
    description: "Qdrant almacena y recupera embedding"
  - check: "webui_access"
    description: "Open WebUI accesible con OAuth2"
```

---

### 4.8 devops — CI/CD y Backup

| Campo | Valor |
|-------|-------|
| **Categoría** | operations |
| **Depende de** | bootstrap |
| **Fichas nuevas** | gitlab, bareos, velero |
| **Servidor lógico** | opsserver (S14) |
| **Tiempo** | ~15 minutos |
| **Nota** | Se instala AL FINAL porque necesita que todo el stack exista para hacer backup |

```yaml
# products/devops.product.yml
product:
  name: "devops"
  description: "CI/CD y Backup — GitLab + DR"
  version: "1.0"
  category: "operations"

requirements:
  - ficha: "postgresql"
    needs:
      databases:
        - name: "gitlab_db"
          owner: "gitlab"
      users:
        - name: "gitlab"
          privileges: ["gitlab_db:ALL"]

  - ficha: "keycloak"
    needs:
      clients:
        - client_id: "gitlab"
          realm: "sbos"
          redirect_uris: ["https://{{DOMAIN}}/gitlab/*"]

  - ficha: "kong"
    needs:
      routes:
        - name: "gitlab"
          paths: ["/gitlab"]
          service_host: "gitlab.sbos-ops.svc"
          service_port: 80
          plugins: ["oauth2"]

  - ficha: "minio"
    needs:
      buckets:
        - name: "gitlab-artifacts"
        - name: "bareos-backups"
        - name: "velero-backups"

fichas:
  - ficha: "gitlab"
    params:
      runners: 2
  - ficha: "bareos"
  - ficha: "velero"
    params:
      backup_schedule: "0 2 * * *"
      retention_days: 30

verify:
  - check: "gitlab_access"
    description: "GitLab accesible con OAuth2"
  - check: "backup_test"
    description: "Backup de prueba completado"
  - check: "restore_test"
    description: "Restore de prueba exitoso"
```

---

## 5. Cómo el Instalador Procesa un Producto

```
bosctl product install mail
  │
  ▼
1. LEER manifiesto products/mail.product.yml
  │
  ▼
2. EVALUAR requirements (para cada ficha listada):
  │
  │  postgresql → STATE_MANAGER: ¿INSTALADA_OK? 
  │    SÍ → Verificar needs:
  │           ¿mail_db existe?        → consulta pg_database
  │           ¿postfixadmin_db existe? → consulta pg_database  
  │           ¿usuario mailserver?     → consulta pg_roles
  │           Lo que NO existe → CREAR
  │           Lo que YA existe → SKIP
  │    NO → ERROR: "postgresql no instalada. Ejecute: bosctl product install bootstrap"
  │
  │  keycloak → STATE_MANAGER: ¿INSTALADA_OK?
  │    SÍ → Verificar needs:
  │           ¿client roundcube existe? → consulta API Keycloak
  │           Lo que NO existe → CREAR
  │    NO → ERROR
  │
  │  kong → (mismo patrón)
  │  vault → (mismo patrón)
  │
  ▼
3. INSTALAR fichas nuevas (en orden de depends_on + execution_order):
  │
  │  Para cada ficha en fichas[]:
  │    ¿Ya INSTALADA_OK? → SKIP (idempotente)
  │    ¿BLOQUEADA?       → ERROR con dependencias faltantes
  │    ¿NO_INSTALADA?    → INSTALAR con params del producto
  │
  ▼
4. VERIFICAR producto:
  │
  │  Ejecutar cada check en verify[]
  │  Si alguno falla → producto en estado ALERTA con detalle
  │
  ▼
5. REGISTRAR producto:
  │
  │  STATE_MANAGER registra en .sbos_state.json:
  │    products.mail.status: "INSTALADO"
  │    products.mail.version: "1.0"
  │    products.mail.fichas: ["mailserver", "postfixadmin", "roundcube", "cypht"]
  │    products.mail.installed_at: "2026-03-13T15:30:00Z"
```

---

## 6. Variables de Producto

Los manifiestos usan variables con sintaxis `{{VARIABLE}}` que se resuelven desde el seed file del deploy (SBOS-033-DEPLOY) o desde la configuración del daemon:

| Variable | Origen | Ejemplo |
|----------|--------|---------|
| `{{DOMAIN}}` | deploy.yml → network.domain | skull.io |
| `{{MAIL_DOMAIN}}` | deploy.yml → network.mail_domain | skull.io |
| `{{ADMIN_EMAIL}}` | deploy.yml → admin.email | admin@skull.io |
| `{{COUNTRY}}` | deploy.yml → tenant.country | BO |
| `{{CURRENCY}}` | Derivado de country | BOB |
| `{{CHART_OF_ACCOUNTS}}` | Derivado de country | bo_puct |
| `{{BRANDING}}` | deploy.yml → tenant.branding | objeto con colores, logo, etc. |

Si una variable no está definida en el deploy, el instalador la solicita por CLI antes de continuar.

---

## 7. Estructura de Archivos

```
/etc/bos/
  ├── bos.toml                    ← configuración del daemon
  ├── .sbos_state.json            ← estado (incluye productos instalados)
  ├── blibs/
  │   └── servers/                ← fichas (no cambian)
  │       ├── dataserver/postgresql/
  │       ├── identityserver/keycloak/
  │       └── commsserver/mailserver/
  └── products/                   ← manifiestos de producto (NUEVO)
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

## 8. Resumen del Catálogo

| Producto | Categoría | Fichas nuevas | Requirements sobre | Tiempo | Opcional |
|----------|-----------|---------------|--------------------|--------|----------|
| **bootstrap** | platform | 16 | (ninguno — es primero) | ~48 min | No |
| **mail** | communication | 4 | postgresql, keycloak, kong, vault | ~12 min | No |
| **erp** | business | 2 | postgresql, keycloak, kong | ~8 min | No |
| **documents** | business | 5 | postgresql, keycloak, kong, minio | ~10 min | No |
| **monitoring** | operations | 4 | postgresql, keycloak | ~8 min | No |
| **vdi** | platform | 4 | postgresql, keycloak, kong, minio | ~15 min | No |
| **ai** | intelligence | 6 | postgresql, kong | ~12 min | Sí |
| **devops** | operations | 3 | postgresql, keycloak, kong, minio | ~15 min | No |

**Patrón visible:** todos los productos dependen de `postgresql` y `keycloak`. Esto confirma que el producto `bootstrap` — que instala ambos — es el prerequisito obligatorio de todo.

---

## 9. Registro de Cambios

### v1.0 — Marzo 2026

Documento nuevo. Define el concepto de Producto como manifiesto de solución, la estructura del manifiesto YAML, el flujo de procesamiento del instalador, y el catálogo inicial de 8 productos.

---

*SKULL · SBOS · SBOS-032-PRODUCTS · v1.0 · Marzo 2026*
