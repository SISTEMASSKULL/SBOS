# SBOS-019-001
## Anexo: Catálogo de Configuración Keycloak y Kong por Aplicación Base
### Identidad + Gateway para Cada App del Stack Mínimo Viable

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

**Código:** SBOS-019-001
**Complementa:** SBOS-019-KC-AuthMethods-v2_0.md, SBOS-003-STACK-v4_0.md, SBOS-032-PRODUCTS-v1_0.md
**Propósito:** Para cada app del stack base, documentar el client Keycloak, la ruta Kong, la BD PostgreSQL, y los permisos bAuth que se crean durante la instalación del producto correspondiente. Sin este catálogo, las fichas no pueden integrarse al gobierno de identidad.

---

## 1. Convenciones

```
Realm:       sbos (único realm para el tenant)
Domain:      {{DOMAIN}} (del seed file, ej: skull.io)
Client IDs:  nombre-de-la-app en lowercase
Roles KC:    {app}-admin, {app}-operator, {app}-viewer
Kong plugins: jwt (verificación JWT KC), rate-limiting (por defecto), cors
Namespace K8s: sbos-{servidor} (ej: sbos-erp, sbos-comms, sbos-apps)
```

---

## 2. Aplicaciones de Infraestructura (producto: bootstrap)

Estas apps se instalan con el bootstrap y ya tienen configuración de seguridad base.

### Grafana

```yaml
keycloak:
  client_id: "grafana"
  protocol: "openid-connect"
  root_url: "https://{{DOMAIN}}/grafana"
  redirect_uris: ["https://{{DOMAIN}}/grafana/*"]
  web_origins: ["https://{{DOMAIN}}"]
  roles: ["grafana-admin", "grafana-editor", "grafana-viewer"]
  default_role: "grafana-viewer"

kong:
  route: "/grafana"
  service: "grafana.sbos-monitor.svc:3000"
  plugins: ["jwt", "rate-limiting", "cors"]
  strip_path: false

postgresql:
  database: "grafana_db"
  owner: "grafana"
```

### PgAdmin 4

```yaml
keycloak:
  client_id: "pgadmin"
  protocol: "openid-connect"
  root_url: "https://{{DOMAIN}}/pgadmin"
  redirect_uris: ["https://{{DOMAIN}}/pgadmin/*"]
  roles: ["pgadmin-admin"]
  note: "Solo accesible por sbos-admin — no visible para usuarios normales"

kong:
  route: "/pgadmin"
  service: "pgadmin.sbos-data.svc:5050"
  plugins: ["jwt", "rate-limiting", "ip-restriction"]
  ip_restriction: ["10.0.0.0/8"]  # solo red interna

postgresql:
  database: "pgadmin_db"
  owner: "pgadmin"
```

---

## 3. Aplicaciones de Negocio Core

### Tryton ERP (producto: erp)

```yaml
keycloak:
  client_id: "tryton"
  protocol: "openid-connect"
  root_url: "https://{{DOMAIN}}/erp"
  redirect_uris: ["https://{{DOMAIN}}/erp/*"]
  web_origins: ["https://{{DOMAIN}}"]
  roles:
    - "tryton-admin"        # Full access
    - "tryton-accountant"   # Contabilidad + facturación
    - "tryton-sales"        # Ventas + inventario lectura
    - "tryton-warehouse"    # Inventario + compras
    - "tryton-viewer"       # Solo lectura global
  default_role: "tryton-viewer"
  auth_flow: "browser"
  required_actions: ["UPDATE_PASSWORD"]

kong:
  route: "/erp"
  service: "tryton.sbos-erp.svc:8000"
  plugins: ["jwt", "rate-limiting", "cors"]
  rate_limit: "100/minute"

postgresql:
  database: "tryton_db"
  owner: "tryton"

bauth:
  bitmask_bit: 2  # APP_TRYTON
  governance_category: 3  # operación destructiva requiere dual approval
```

### OrangeHRM (producto: hr)

```yaml
keycloak:
  client_id: "orangehrm"
  protocol: "openid-connect"
  root_url: "https://{{DOMAIN}}/hr"
  redirect_uris: ["https://{{DOMAIN}}/hr/*"]
  web_origins: ["https://{{DOMAIN}}"]
  roles:
    - "hr-admin"       # Full RRHH
    - "hr-manager"     # Gestión de equipo
    - "hr-employee"    # Portal del empleado (solo sus datos)
    - "hr-viewer"      # Solo lectura
  default_role: "hr-employee"
  note: "Usa MySQL como BD. SymmetricDS sincroniza con PostgreSQL para bKernel"

kong:
  route: "/hr"
  service: "orangehrm.sbos-apps.svc:80"
  plugins: ["jwt", "rate-limiting", "cors"]

postgresql:
  note: "OrangeHRM usa MySQL. La BD orangehrm_mysql es sincronizada por SymmetricDS"

bauth:
  bitmask_bit: 3  # APP_ORANGEHRM
```

---

## 4. Aplicaciones de Comunicación (producto: mail)

### Roundcube Webmail

```yaml
keycloak:
  client_id: "roundcube"
  protocol: "openid-connect"
  root_url: "https://{{DOMAIN}}/mail"
  redirect_uris: ["https://{{DOMAIN}}/mail/*"]
  roles: ["mail-user"]
  default_role: "mail-user"
  note: "Todos los empleados tienen acceso a correo por defecto"

kong:
  route: "/mail"
  service: "roundcube.sbos-comms.svc:8080"
  plugins: ["jwt", "cors"]
```

### PostfixAdmin

```yaml
keycloak:
  client_id: "postfixadmin"
  root_url: "https://{{DOMAIN}}/postfixadmin"
  redirect_uris: ["https://{{DOMAIN}}/postfixadmin/*"]
  roles: ["mail-admin"]
  note: "Solo accesible por administradores de correo"

kong:
  route: "/postfixadmin"
  service: "postfixadmin.sbos-comms.svc:8080"
  plugins: ["jwt", "rate-limiting", "ip-restriction"]
```

---

## 5. Aplicaciones de Observabilidad (producto: monitoring)

### Zabbix

```yaml
keycloak:
  client_id: "zabbix"
  root_url: "https://{{DOMAIN}}/zabbix"
  redirect_uris: ["https://{{DOMAIN}}/zabbix/*"]
  roles: ["zabbix-admin", "zabbix-viewer"]

kong:
  route: "/zabbix"
  service: "zabbix.sbos-monitor.svc:8080"
  plugins: ["jwt", "rate-limiting"]

postgresql:
  database: "zabbix_db"
  owner: "zabbix"
```

---

## 6. Aplicaciones de Gestión Documental (producto: documents)

### Paperless-NGX

```yaml
keycloak:
  client_id: "paperless"
  root_url: "https://{{DOMAIN}}/docs"
  redirect_uris: ["https://{{DOMAIN}}/docs/*"]
  roles: ["docs-admin", "docs-editor", "docs-viewer"]
  default_role: "docs-viewer"

kong:
  route: "/docs"
  service: "paperless.sbos-docs.svc:8000"
  plugins: ["jwt", "rate-limiting", "cors"]

postgresql:
  database: "paperless_db"
  owner: "paperless"
```

### DocuSeal (Firma digital)

```yaml
keycloak:
  client_id: "docuseal"
  root_url: "https://{{DOMAIN}}/sign"
  redirect_uris: ["https://{{DOMAIN}}/sign/*"]
  roles: ["sign-admin", "sign-signer"]

kong:
  route: "/sign"
  service: "docuseal.sbos-docs.svc:3000"
  plugins: ["jwt", "cors"]

postgresql:
  database: "docuseal_db"
  owner: "docuseal"
```

---

## 7. Aplicaciones de CI/CD y Backup (producto: devops)

### GitLab CE

```yaml
keycloak:
  client_id: "gitlab"
  root_url: "https://{{DOMAIN}}/gitlab"
  redirect_uris: ["https://{{DOMAIN}}/gitlab/*"]
  roles: ["gitlab-admin", "gitlab-developer", "gitlab-viewer"]
  note: "Solo accesible por equipo técnico del cliente"

kong:
  route: "/gitlab"
  service: "gitlab.sbos-ops.svc:80"
  plugins: ["jwt", "rate-limiting"]

postgresql:
  database: "gitlab_db"
  owner: "gitlab"
```

---

## 8. Aplicaciones Opcionales (IA, VDI)

### Open WebUI (producto: ai)

```yaml
keycloak:
  client_id: "openwebui"
  root_url: "https://{{DOMAIN}}/ai"
  redirect_uris: ["https://{{DOMAIN}}/ai/*"]
  roles: ["ai-admin", "ai-analyst", "ai-viewer"]

kong:
  route: "/ai"
  service: "open-webui.sbos-ai.svc:8080"
  plugins: ["jwt", "rate-limiting"]
```

### SBOS VDI (producto: vdi)

```yaml
keycloak:
  client_id: "kasm"
  root_url: "https://{{DOMAIN}}/desktop"
  redirect_uris: ["https://{{DOMAIN}}/desktop/*"]
  roles: ["vdi-admin", "vdi-user"]
  note: "VDI usa el RolTemplate completo para configurar el escritorio del usuario"

kong:
  route: "/desktop"
  service: "kasm.sbos-vdi.svc:443"
  plugins: ["jwt"]
```

---

## 9. Resumen: Mapa de Rutas y Bits

| Path | App | KC Client | BitMask Bit | Producto |
|------|-----|-----------|:-----------:|----------|
| `/erp` | Tryton | tryton | 2 | erp |
| `/hr` | OrangeHRM | orangehrm | 3 | hr |
| `/mail` | Roundcube | roundcube | — | mail |
| `/postfixadmin` | PostfixAdmin | postfixadmin | — | mail |
| `/docs` | Paperless-NGX | paperless | — | documents |
| `/sign` | DocuSeal | docuseal | — | documents |
| `/grafana` | Grafana | grafana | — | bootstrap |
| `/pgadmin` | PgAdmin 4 | pgadmin | — | bootstrap |
| `/zabbix` | Zabbix | zabbix | — | monitoring |
| `/gitlab` | GitLab | gitlab | — | devops |
| `/ai` | Open WebUI | openwebui | — | ai |
| `/desktop` | Kasm (VDI) | kasm | — | vdi |

---

## 10. Registro de Cambios

### v1.0 — Marzo 2026

Documento nuevo. Catálogo de configuración Keycloak (client, roles, flows) y Kong (rutas, plugins) para 12 aplicaciones base del stack, organizadas por producto. Incluye BDs PostgreSQL, bits de BitMask, y notas de integración.

---

*SKULL · SBOS · SBOS-019-001 · Anexo 001 · v1.0 · Marzo 2026*
