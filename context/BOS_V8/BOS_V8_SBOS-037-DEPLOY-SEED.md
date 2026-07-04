# SBOS-037-DEPLOY-SEED
## Seed File y Configuración Inicial del Cliente — Estándar HUMAN-DOC
### SKULL · SBOS · v1.0 · Abril 2026

---

## 1. Concepto

Un Deploy es el nivel más alto del instalador. Manifiesto con toda la información para llevar un servidor desde Ubuntu virgen hasta sistema productivo con identidad y cultura de la empresa.

```bash
curl -sSL https://get.sbos.io/installer | sudo bash -s -- --deploy=mi-empresa.deploy.yml
```

Un solo comando. Sin pasos interactivos. Técnico ejecuta y vuelve en una hora.

## 2. Estructura del Seed File (6 secciones)

### Sección 1 — Identidad de la Empresa (técnico llena)
```yaml
tenant:
  company_name: "SKULL S.R.L."
  legal_name: "SKULL Tecnología y Sistemas S.R.L."
  tax_id: "1234567890"
  tax_id_type: "NIT"           # NIT|CUIT|RFC|RUC|RUT
  country: "BO"                # ISO 3166-1
  state: "La Paz"
  city: "La Paz"
  industry: "technology"       # technology|manufacturing|retail|services|health|education|government
  company_size: "small"        # micro|small|medium|large
  fiscal_year_start: "01-01"
  default_currency: "BOB"      # ISO 4217
  branding:
    primary_color: "#1a365d"
    secondary_color: "#2b6cb0"
    accent_color: "#ed8936"
    logo_path: "assets/logo.png"         # mínimo 512x512 PNG
    favicon_path: "assets/favicon.png"
    email_signature_html: "assets/email-signature.html"
```

### Sección 2 — Red y Dominio (técnico llena)
```yaml
network:
  domain: "skull.io"
  mail_domain: "skull.io"
  server_ip: "203.0.113.10"
  internal_ip: "10.0.0.10"
  timezone: "America/La_Paz"
  locale: "es_BO"
```
DNS requeridos ANTES: A skull.io → IP, A *.skull.io → IP, MX skull.io → mail.skull.io, TXT SPF.

### Sección 3 — Administrador Inicial (técnico llena)
```yaml
admin:
  username: "admin"
  email: "admin@skull.io"
  first_name: "Administrador"
  last_name: "SKULL"
  # Password NUNCA aquí — generada automáticamente, mostrada UNA VEZ
```

### Sección 4 — Productos (técnico selecciona)
```yaml
products:
  - bootstrap         # OBLIGATORIO — siempre primero
  - mail              # Correo corporativo
  - erp               # ERP y contabilidad
  # - documents       # Gestión documental (comentado = no instalar)
  # - vdi             # Escritorio virtual
  # - ai              # Inteligencia artificial
```

### Sección 5 — Llaves Maestras (generadas automáticamente, NO EDITAR)
vault_root_token, vault_unseal_keys (5 llaves, threshold 3), keycloak_admin_pass, postgresql_superuser, ed25519_keypair, jwt_signing_key, admin_initial_pass. Todas almacenadas en Vault. vault_unseal_keys impresas UNA VEZ.

### Sección 6 — Metadatos (generados automáticamente, NO EDITAR)
deploy_id (UUID), timestamps, versión instalador, productos completados, fichas count, tiempo total.

## 3. Prerequisitos del Técnico

### Del cliente
| Dato | Dónde se usa |
|---|---|
| Nombre empresa + legal | KC realm, certificados, firmas correo |
| NIT/CUIT/RFC | ERP, integración fiscal SIAT/AFIP/SAT |
| País | Plan de cuentas, moneda, locale, timezone |
| Dominio | NGINX, Kong, KC, SSL, correo |
| Logo PNG 512x512+ | KC login, Core UI, correo, documentos |
| Colores corporativos | KC themes, Core UI, SBOS VDI |
| Email admin | Primera cuenta KC |

### Del servidor
Ubuntu 26.04 LTS, CPU≥2, RAM≥4GB, Disco≥40GB SSD, acceso root, IP pública con DNS configurado.

## 4. Flujo de Procesamiento (9 pasos)

```
1. VALIDAR seed file (4 secciones, logo, DNS, productos)
2. GENERAR llaves maestras (en memoria → Vault cuando disponible)
3. GENERAR identidad visual desde logo: favicon.ico, apple-touch-icon, android-chrome,
   og-image, logo variantes (monocromático, invertido, miniatura)
4. EJECUTAR productos en secuencia:
   [bos] Producto 1/3: bootstrap → 16 fichas → 48m
   [bos] Mover llaves maestras a Vault
   [bos] Producto 2/3: mail → PG mail_db crear + KC client roundcube → 12m
   [bos] Producto 3/3: erp → PG tryton_db crear + KC client tryton → 8m
5. APLICAR identidad visual (KC tema, NGINX favicon, firma correo)
6. CREAR cuenta administrador (KC realm sbos, rol realm-admin)
7. CREAR cuenta emergencia (KC realm master, solo recuperación)
8. REGISTRAR deploy en .sbos_state.json
9. IMPRIMIR credenciales UNA SOLA VEZ
```

### Output final del técnico
```
✓ DEPLOY COMPLETO: SKULL S.R.L.
  Productos: bootstrap, mail, erp | Fichas: 22 | Tiempo: 67m 27s

  CREDENCIALES — GUARDAR DE FORMA SEGURA (se muestran UNA VEZ):
  Admin:      https://skull.io | admin | Kj8#mP2$vL9nQ4xR (cambiar)
  Emergencia: https://skull.io/auth | emergency-admin | Tz5$nW7#bH3kM9yF
  Vault Keys: 5 llaves (threshold 3) — distribuir entre personas de confianza
```

## 5. Resolución de Variables

| Variable | Fuente | Ejemplo |
|---|---|---|
| {{DOMAIN}} | network.domain | skull.io |
| {{COUNTRY}} | tenant.country | BO |
| {{CURRENCY}} | tenant.default_currency | BOB |
| {{CHART_OF_ACCOUNTS}} | Derivado de country | bo_puct |
| {{TAX_ID}} | tenant.tax_id | 1234567890 |
| {{BRANDING}} | tenant.branding (objeto) | colores + paths |

### Derivaciones automáticas por país

| País | Moneda | Plan cuentas | Timezone default | Integración fiscal |
|---|---|---|---|---|
| BO | BOB | bo_puct | America/La_Paz | SIAT |
| AR | ARS | ar_pcga | America/Argentina/Buenos_Aires | AFIP |
| MX | MXN | mx_pcga | America/Mexico_City | SAT |
| CO | COP | co_puc | America/Bogota | DIAN |
| PE | PEN | pe_pcge | America/Lima | SUNAT |
| CL | CLP | cl_pcga | America/Santiago | SII |

## 6. Seguridad del Seed File

**NUNCA** se escribe en el seed file: contraseñas, vault keys, tokens API, claves privadas, credenciales de acceso. Todo se genera automáticamente con generadores criptográficos y se almacena en Vault.

Ciclo de vida: técnico llena secciones 1-4 (solo identidad) → instalador genera llaves en memoria → mueve a Vault → escribe metadatos → seed file queda como registro sin secretos.

Cuenta emergencia: emergency-admin en realm master, credenciales impresas UNA VEZ + Vault, guardar offline (caja fuerte). Siguiendo mejores prácticas Microsoft Entra y NIST SP 800-63B.

## 7. Deploy Incremental

```bash
# Sistema ya tiene bootstrap + mail. Agregar erp + documents:
bosctl deploy agregar-productos.deploy.yml

[bos] Productos solicitados: bootstrap, mail, erp, documents
[bos] Ya instalados: bootstrap ✓, mail ✓
[bos] Pendientes: erp, documents
→ Solo instala lo que falta. Idempotente.
```

---

## Trazabilidad

| Sección | Extraída de | Secciones originales |
|---|---|---|
| §1 Concepto | SBOS-033 v1.0 | §1 (definición deploy, nivel más alto) |
| §2 Seed file | SBOS-033 v1.0 | §2 completo (6 secciones con YAML completo ejemplo SKULL) |
| §3 Prerequisitos | SBOS-033 v1.0 | §3 (tablas cliente + servidor + DNS) |
| §4 Flujo | SBOS-033 v1.0 | §4 completo (9 pasos con output técnico) |
| §5 Variables | SBOS-033 v1.0 | §5 (tabla resolución + derivaciones por país 6 países) |
| §6 Seguridad | SBOS-033 v1.0 | §6 (política credenciales + ciclo vida + cuenta emergencia) |
| §7 Incremental | SBOS-033 v1.0 | §7 (deploy sobre sistema existente) |

---

---

# ENRIQUECIMIENTO V8 — SBOS-037-DEPLOY-SEED

## V5 — Enriquecimiento desde BOS_V5_SBOS-033-DEPLOY-v1_0

### V5 §1 — Procesamiento del Seed File Paso a Paso (9 Steps + Expanded Output)

**Paso 1 — Validar seed file:**
```
Validaciones:
  [✓] YAML parseable
  [✓] Secciones 1-4 presentes (tenant, network, admin, products)
  [✓] tenant.company_name no vacío
  [✓] tenant.tax_id formato válido para el país
  [✓] network.domain formato FQDN válido
  [✓] Logo existe en logo_path (mínimo 512x512 PNG)
  [✓] DNS: A record para domain → server_ip
  [✓] DNS: MX record para mail_domain
  [✓] Productos lista válida (bootstrap + al menos 1 más)
  [✓] Productos sin duplicados
  [✓] bootstrap es el primer producto de la lista
```

**Paso 2 — Generar llaves maestras:**
```yaml
# Generado automáticamente (NUNCA en seed file)
generated_keys:
  vault_root_token: "hvs.RANDOM64"
  vault_unseal_keys: ["key1","key2","key3","key4","key5"]
  keycloak_admin_pass: "RANDOM32"
  postgresql_superuser_pass: "RANDOM32"
  ed25519_private: "ES256_RANDOM"       # Release Plane signing
  ed25519_public: "verify_RANDOM"
  jwt_signing_key: "RS256_RANDOM"       # Keycloak realm
  admin_initial_pass: "RANDOM12"        # Mostrada una vez
```

**Paso 3 — Generar identidad visual:**
Ejecuta `sbos-identity-generator` (ver SBOS-038) con los parámetros de branding del seed file.

**Paso 5 — Aplicar identidad visual (detalle):**
```
- Keycloak theme: /opt/keycloak/themes/sbos/login/theme.properties
  logo: keycloak-logo.png
  background-color: primary_color
  button-color: accent_color
- NGINX: /var/www/html/favicon.ico, /var/www/html/favicon.svg
- Roundcube: Firma por defecto con email-signature.html
```

### V5 §2 — Deploy Incremental y Configuración

**Comandos de gestión de deploy:**
```bash
bosctl deploy status              # Ver estado actual del deploy
bosctl deploy validate <archivo>  # Validar seed file sin instalar
bosctl deploy diff <archivo>      # Qué productos faltan vs los instalados
bosctl deploy rollback            # Revertir al último deploy exitoso
```

**Deploy sobre sistema existente:**
```bash
# Sistema ya tiene bootstrap + mail. Agregar erp + documents:
bosctl deploy agregar-productos.deploy.yml
# Output:
[bos] Estado actual: bootstrap ✓, mail ✓
[bos] Solicitados: bootstrap, mail, erp, documents
[bos] Ya instalados: 2/4
[bos] Pendientes: erp, documents
[bos] Iniciando erp (8 min)... OK ✓
[bos] Iniciando documents (10 min)... OK ✓
[bos] Deploy incremental completado. Tiempo: 18 min.
```

---

## Smart* — Enriquecimiento desde Subproyectos SBOS

### Smart Portfolio — bkb_seed_bolivia_v1.yml

El seed file de bportfolio sigue una estructura similar en 6 secciones para la Base de Conocimiento:

**Secciones del seed file de bKB:**
1. **tenant**: Identidad del tenant, país, moneda
2. **empresas**: Lista de empresas del tenant con sus datos de branding
3. **reglas_bkb**: Reglas de clasificación automática para la Base de Conocimiento
4. **sucursales**: Sucursales/POS por empresa con configuración regional
5. **plantillas_branding**: Plantillas visuales por empresa (WeasyPrint + Jinja2)
6. **usuarios_iniciales**: Cuentas de administrador iniciales (referencia a Keycloak)

**Ejemplo de regla bKB (clasificación):**
```yaml
reglas_bkb:
  - patron: ".*factura.*"
    categoria: "Facturas"
    prioridad: 10
    requiere_verificacion: false
  - patron: ".*orden de compra.*|.*OC.*"
    categoria: "Órdenes de Compra"
    prioridad: 8
    requiere_verificacion: true
```

---

## Fuentes de Enriquecimiento V8

| Fuente | Archivo | Secciones utilizadas |
|---|---|---|
| V6 original | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V6_SBOS-037-DEPLOY-SEED.md` | Documento completo (186 líneas) |
| V5 Deploy | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-033-DEPLOY-v1_0.md` | §1 Procesamiento 9 pasos expandido con validaciones, §2 Comandos gestión deploy, deploy incremental |
| SmartPortfolio bKB | `/opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Portfolio/context/bkb_seed_bolivia_v1.yml` | Estructura seed file bKB, reglas de clasificación automática |

---

_SKULL · SBOS · SBOS-037-DEPLOY-SEED · V8 (V6+V5+Smart*) · Mayo 2026_
