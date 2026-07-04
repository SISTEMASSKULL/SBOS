# SBOS-033-DEPLOY
## Especificación de Despliegue — Seed File y Configuración Inicial del Cliente

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

**Código:** SBOS-033-DEPLOY (nuevo número — el anterior SBOS-033 de Portabilidad se renumera)
**Estado:** NUEVO
**Clasificación:** Especificación de Instalación — Despliegue de Cliente
**Dependencias documentales:** SBOS-005 (Installer), SBOS-031 (Rutina de Instalación), SBOS-032 (Productos)

---

## 1. ¿Qué es un Deploy?

Un Deploy es el **nivel más alto de operación del instalador**. Es un manifiesto que contiene toda la información necesaria para llevar un servidor desde Ubuntu virgen hasta un sistema productivo completo con la identidad y cultura de una empresa específica.

El técnico SKULL llena el archivo **antes** de ejecutar la instalación. El daemon `bos` lo lee y ejecuta todos los productos en secuencia, inyectando los datos de la empresa en cada ficha y cada producto que lo necesite.

```
curl -sSL https://get.sbos.io/installer | sudo bash -s -- --deploy=mi-empresa.deploy.yml
```

Un solo comando. Sin pasos interactivos. El técnico puede ejecutarlo y volver en una hora — el sistema estará operativo.

---

## 2. Estructura del Seed File

El seed file tiene 6 secciones. Las primeras 4 las llena el técnico. Las últimas 2 las genera el instalador automáticamente.

```yaml
# deploy/mi-empresa.deploy.yml
# ══════════════════════════════════════════════════════
# SBOS — Seed File de Despliegue
# Este archivo contiene toda la información necesaria
# para instalar un servidor SBOS completo.
# ══════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────
# SECCIÓN 1: IDENTIDAD DE LA EMPRESA
# El técnico SKULL llena estos datos con la información
# del cliente. Se inyectan en Keycloak, Kong, Tryton,
# firmas de correo, certificados, etc.
# ─────────────────────────────────────────────────────
tenant:
  # Datos legales
  company_name: "SKULL S.R.L."
  legal_name: "SKULL Tecnología y Sistemas S.R.L."
  tax_id: "1234567890"              # NIT (Bolivia), CUIT (Argentina), RFC (México)
  tax_id_type: "NIT"                # NIT | CUIT | RFC | RUC | RUT
  country: "BO"                     # ISO 3166-1 alpha-2
  state: "La Paz"
  city: "La Paz"
  address: "Av. Principal #123, Zona Sur"
  postal_code: "0000"
  phone: "+591 2 1234567"
  website: "https://skull.io"
  
  # Datos de operación
  industry: "technology"            # technology | manufacturing | retail | services | health | education | government
  company_size: "small"             # micro (<10) | small (10-49) | medium (50-249) | large (250+)
  fiscal_year_start: "01-01"        # MM-DD
  default_currency: "BOB"           # ISO 4217
  
  # Cultura institucional e identidad visual
  branding:
    primary_color: "#1a365d"
    secondary_color: "#2b6cb0"
    accent_color: "#ed8936"
    logo_path: "assets/logo.png"          # Logo principal (mínimo 512x512 PNG)
    logo_dark_path: "assets/logo-dark.png" # Logo para fondos oscuros (opcional)
    favicon_path: "assets/favicon.png"     # Favicon fuente (mínimo 256x256 PNG)
    email_signature_html: "assets/email-signature.html"  # Template HTML para firma de correo

# ─────────────────────────────────────────────────────
# SECCIÓN 2: RED Y DOMINIO
# Configuración de red del servidor donde se instalará.
# ─────────────────────────────────────────────────────
network:
  domain: "skull.io"                # Dominio principal (DNS debe apuntar al server_ip)
  mail_domain: "skull.io"           # Dominio para correo (puede ser igual o diferente)
  server_ip: "203.0.113.10"         # IP pública del servidor
  internal_ip: "10.0.0.10"         # IP interna (si aplica, si no = server_ip)
  timezone: "America/La_Paz"       # IANA timezone
  locale: "es_BO"                  # Locale para formatos de fecha, número, moneda
  
  # DNS records que el cliente debe configurar ANTES de la instalación:
  # A    skull.io           → 203.0.113.10
  # A    *.skull.io         → 203.0.113.10 (wildcard para subdominios)
  # MX   skull.io           → mail.skull.io (prioridad 10)
  # TXT  skull.io           → v=spf1 ip4:203.0.113.10 -all

# ─────────────────────────────────────────────────────
# SECCIÓN 3: ADMINISTRADOR INICIAL
# La primera cuenta humana que podrá gestionar el sistema.
# ─────────────────────────────────────────────────────
admin:
  username: "admin"
  email: "admin@skull.io"
  first_name: "Administrador"
  last_name: "SKULL"
  # NOTA: La contraseña NO se escribe aquí.
  # El instalador genera una contraseña segura automáticamente
  # y la muestra UNA SOLA VEZ al finalizar la instalación.
  # El admin debe cambiarla en su primer login.

# ─────────────────────────────────────────────────────
# SECCIÓN 4: PRODUCTOS A INSTALAR
# Lista de productos que el técnico selecciona según
# las necesidades del cliente. El orden importa solo
# para el bootstrap — los demás se resuelven por dependencias.
# ─────────────────────────────────────────────────────
products:
  - bootstrap          # OBLIGATORIO — siempre primero
  - mail               # Correo corporativo
  - erp                # ERP y contabilidad
  # - documents        # Gestión documental (comentado = no instalar)
  # - vdi              # Escritorio virtual
  # - ai               # Inteligencia artificial
  # - monitoring       # Observabilidad extendida
  # - devops           # CI/CD y backup

# ─────────────────────────────────────────────────────
# SECCIÓN 5: LLAVES MAESTRAS (generadas automáticamente)
# NO EDITAR — el instalador genera y almacena estas
# credenciales durante la instalación.
# ─────────────────────────────────────────────────────
# Las siguientes llaves se generan automáticamente:
#
#   vault_root_token:     → se genera en vault init
#   vault_unseal_keys:    → 5 llaves, threshold 3
#   keycloak_admin_pass:  → generada aleatoriamente
#   postgresql_superuser: → generada aleatoriamente
#   ed25519_keypair:      → generada para firma de actualizaciones
#   jwt_signing_key:      → generada para Kong/OAuth2
#   admin_initial_pass:   → generada para el admin de sección 3
#
# Almacenamiento:
#   → Todas se almacenan encriptadas en Vault
#   → vault_unseal_keys se imprimen UNA VEZ en consola
#     (el admin debe guardarlas offline de forma segura)
#   → admin_initial_pass se imprime UNA VEZ en consola
#
# El instalador NUNCA almacena llaves en texto plano
# fuera de Vault después de la inicialización.

# ─────────────────────────────────────────────────────
# SECCIÓN 6: METADATOS DEL DEPLOY (generados automáticamente)
# NO EDITAR — el instalador registra estos datos
# al completar la instalación.
# ─────────────────────────────────────────────────────
# deploy_id:           → UUID generado al inicio
# deploy_started_at:   → timestamp ISO 8601
# deploy_completed_at: → timestamp ISO 8601
# deploy_version:      → versión del instalador usada
# products_installed:  → lista de productos completados
# fichas_count:        → total de fichas instaladas
# total_time_seconds:  → tiempo total de instalación
```

---

## 3. Lo que el Técnico Necesita Antes de Ejecutar

### 3.1 Del cliente

| Dato | Ejemplo | Dónde se usa |
|------|---------|--------------|
| Nombre de empresa | SKULL S.R.L. | Keycloak realm, certificados, firmas de correo |
| Nombre legal | SKULL Tecnología y Sistemas S.R.L. | Facturación, ERP Tryton |
| NIT / CUIT / RFC | 1234567890 | ERP, integración fiscal SIAT/AFIP/SAT |
| País | BO | Plan de cuentas, moneda, locale, zona horaria |
| Dominio | skull.io | NGINX, Kong, Keycloak, certificados SSL, correo |
| Logo (PNG 512x512+) | logo.png | Keycloak login, Core UI, correo, documentos |
| Colores corporativos | #1a365d, #2b6cb0 | Keycloak themes, Core UI, SBOS VDI |
| Email del admin | admin@skull.io | Primera cuenta Keycloak, notificaciones |
| Productos deseados | bootstrap, mail, erp | Qué instalar |

### 3.2 Del servidor

| Dato | Ejemplo | Cómo obtenerlo |
|------|---------|----------------|
| IP pública | 203.0.113.10 | Proveedor VPS / hosting |
| Ubuntu 24.04 LTS | Instalación mínima | Verificar: `lsb_release -a` |
| CPU >= 2 | 4 vCPU | Verificar: `nproc` |
| RAM >= 4GB | 8 GB | Verificar: `free -h` |
| Disco >= 40GB SSD | 100 GB | Verificar: `df -h` |
| Acceso root o sudo | - | SSH activo |

### 3.3 DNS (el cliente debe configurar ANTES)

```
# Registros DNS mínimos requeridos antes de la instalación:
A    skull.io           → 203.0.113.10
A    *.skull.io         → 203.0.113.10
MX   skull.io           → mail.skull.io (prioridad 10)    # solo si producto mail
TXT  skull.io           → v=spf1 ip4:203.0.113.10 -all   # solo si producto mail
```

---

## 4. Lo que el Instalador Hace con el Seed File

```
curl -sSL https://get.sbos.io/installer | sudo bash -s -- --deploy=skull-empresa.deploy.yml
  │
  ▼
1. VALIDAR seed file
  │  ¿Tiene las 4 secciones obligatorias? (tenant, network, admin, products)
  │  ¿El logo existe en assets/?
  │  ¿El dominio resuelve a server_ip? (DNS check)
  │  ¿Los productos listados existen en products/?
  │  SI FALLA → ERROR con detalle exacto de qué falta
  │
  ▼
2. GENERAR llaves maestras (sección 5)
  │  → vault_unseal_keys (5 llaves, threshold 3)
  │  → todas las credenciales de servicios
  │  → admin_initial_pass
  │  → Almacenar temporalmente en memoria (se mueven a Vault cuando esté listo)
  │
  ▼
3. GENERAR identidad visual
  │  → Desde logo.png (512x512+) genera:
  │     favicon.ico (16, 32, 48)
  │     apple-touch-icon.png (180x180)
  │     android-chrome (192, 512)
  │     og-image.png (1200x630)
  │     logo variantes (monocromático, invertido, miniatura)
  │  → Almacena en /etc/bos/branding/
  │  → Especificación completa en SBOS-034-IDENTITY-GENERATOR
  │
  ▼
4. EJECUTAR productos en secuencia
  │
  │  Para cada producto en products[]:
  │    → Leer products/<nombre>.product.yml
  │    → Resolver variables {{DOMAIN}}, {{COUNTRY}}, etc. desde el seed file
  │    → Evaluar requirements (¿fichas existentes tienen config suficiente?)
  │    → Ampliar configuraciones donde falte
  │    → Instalar fichas nuevas
  │    → Verificar producto
  │
  │  Ejemplo para bootstrap + mail + erp:
  │
  │  [bos] ━━━ Deploy: SKULL S.R.L. ━━━
  │  [bos] Productos: bootstrap → mail → erp
  │  
  │  [bos] ━━━ Producto 1/3: bootstrap ━━━
  │    [✓] sbos-bootstrap-os → SO preparado
  │    [✓] sbos-bootstrap-k8s → K8s operativo
  │    [✓] sbos-bootstrap-platform → namespaces + StorageClass
  │    [✓] sbos-k8s-network-validator → red certificada
  │    [✓] postgresql → BD con datos iniciales
  │    ...
  │    [✓] sbos-bootstrap-hardening → CIS verificado
  │    [✓] Producto bootstrap: COMPLETO (48m 12s)
  │
  │  [bos] Moviendo llaves maestras a Vault...
  │    [✓] vault_root_token almacenado
  │    [✓] Credenciales de servicios almacenadas
  │    [✓] Llaves temporales en memoria eliminadas
  │
  │  [bos] ━━━ Producto 2/3: mail ━━━
  │    postgresql → configuración: mail_db NO EXISTE → crear
  │    keycloak → client roundcube NO EXISTE → crear
  │    kong → ruta /mail NO EXISTE → crear
  │    [✓] mailserver instalado → DKIM generado para skull.io
  │    [✓] postfixadmin instalado
  │    [✓] roundcube instalado
  │    [✓] cypht instalado
  │    [✓] SMTP test: OK
  │    [✓] Producto mail: COMPLETO (11m 45s)
  │
  │  [bos] ━━━ Producto 3/3: erp ━━━
  │    postgresql → configuración: tryton_db NO EXISTE → crear
  │    keycloak → client tryton NO EXISTE → crear
  │    kong → ruta /erp NO EXISTE → crear
  │    [✓] tryton instalado → plan de cuentas Bolivia PUCT
  │    [✓] tryton-workers instalados (2 workers)
  │    [✓] Producto erp: COMPLETO (7m 30s)
  │
  ▼
5. APLICAR identidad visual
  │  → Keycloak: tema con logo y colores de la empresa
  │  → NGINX: favicon y certificado con nombre de empresa
  │  → Firma de correo: template con datos de empresa
  │
  ▼
6. CREAR cuenta de administrador
  │  → Keycloak: crear usuario admin en realm sbos
  │  → Asignar rol realm-admin
  │  → Contraseña temporal (requiere cambio en primer login)
  │
  ▼
7. CREAR cuenta de emergencia
  │  → Keycloak: crear usuario emergency-admin en realm master
  │  → Solo para recuperación si el admin principal se bloquea
  │  → Credenciales se imprimen UNA VEZ y se almacenan en Vault
  │
  ▼
8. REGISTRAR deploy completado
  │  → Escribir sección 6 del seed file (metadatos)
  │  → STATE_MANAGER registra el deploy en .sbos_state.json
  │
  ▼
9. IMPRIMIR credenciales (UNA SOLA VEZ)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ DEPLOY COMPLETO: SKULL S.R.L.

  Productos instalados: bootstrap, mail, erp
  Fichas activas: 22
  Tiempo total: 67m 27s

  ┌─────────────────────────────────────────────┐
  │  CREDENCIALES — GUARDAR DE FORMA SEGURA     │
  │  Se muestran UNA SOLA VEZ                   │
  ├─────────────────────────────────────────────┤
  │  Admin SBOS:                                │
  │    URL:      https://skull.io               │
  │    Usuario:  admin                          │
  │    Password: Kj8#mP2$vL9nQ4xR              │
  │    (cambiar en primer login)                │
  │                                             │
  │  Cuenta de emergencia:                      │
  │    URL:      https://skull.io/auth          │
  │    Usuario:  emergency-admin                │
  │    Password: Tz5$nW7#bH3kM9yF              │
  │    (solo para recuperación)                 │
  │                                             │
  │  Vault Unseal Keys (3 de 5 requeridas):     │
  │    Key 1: a3f8d...                          │
  │    Key 2: b7c2e...                          │
  │    Key 3: d9e1a...                          │
  │    Key 4: f4b6c...                          │
  │    Key 5: h2g8d...                          │
  │    (distribuir entre personas de confianza) │
  └─────────────────────────────────────────────┘

  Para ver el estado:     bosctl status
  Para ver productos:     bosctl product list
  Para instalar más:      bosctl product install <producto>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 5. Resolución de Variables

El instalador resuelve las variables `{{}}` de los manifiestos de producto usando datos del seed file:

| Variable | Fuente en seed file | Ejemplo |
|----------|-------------------|---------|
| `{{DOMAIN}}` | network.domain | skull.io |
| `{{MAIL_DOMAIN}}` | network.mail_domain | skull.io |
| `{{SERVER_IP}}` | network.server_ip | 203.0.113.10 |
| `{{TIMEZONE}}` | network.timezone | America/La_Paz |
| `{{LOCALE}}` | network.locale | es_BO |
| `{{ADMIN_EMAIL}}` | admin.email | admin@skull.io |
| `{{ADMIN_USERNAME}}` | admin.username | admin |
| `{{COMPANY_NAME}}` | tenant.company_name | SKULL S.R.L. |
| `{{LEGAL_NAME}}` | tenant.legal_name | SKULL Tecnología y Sistemas S.R.L. |
| `{{TAX_ID}}` | tenant.tax_id | 1234567890 |
| `{{TAX_ID_TYPE}}` | tenant.tax_id_type | NIT |
| `{{COUNTRY}}` | tenant.country | BO |
| `{{CURRENCY}}` | tenant.default_currency | BOB |
| `{{CHART_OF_ACCOUNTS}}` | Derivado de country | bo_puct |
| `{{BRANDING}}` | tenant.branding (objeto completo) | colores + paths |
| `{{PRIMARY_COLOR}}` | tenant.branding.primary_color | #1a365d |

**Derivaciones automáticas por país:**

| País | Moneda | Plan de cuentas | Zona horaria default | Integración fiscal |
|------|--------|-----------------|---------------------|-------------------|
| BO | BOB | bo_puct | America/La_Paz | SIAT |
| AR | ARS | ar_pcga | America/Argentina/Buenos_Aires | AFIP |
| MX | MXN | mx_pcga | America/Mexico_City | SAT |
| CO | COP | co_puc | America/Bogota | DIAN |
| PE | PEN | pe_pcge | America/Lima | SUNAT |
| CL | CLP | cl_pcga | America/Santiago | SII |

Si el técnico no especifica `default_currency`, `timezone` o plan de cuentas, el instalador los deriva del `country`.

---

## 6. Seguridad del Seed File

### 6.1 Lo que NUNCA se escribe en el seed file

- Contraseñas (ni del admin, ni de servicios, ni de bases de datos)
- Vault unseal keys
- Tokens de API
- Claves privadas Ed25519, JWT o TLS
- Cualquier credencial que dé acceso al sistema

Todas las credenciales se **generan automáticamente** durante la instalación con generadores criptográficamente seguros y se almacenan exclusivamente en Vault.

### 6.2 Ciclo de vida del seed file

```
ANTES de la instalación:
  El técnico llena secciones 1-4
  El seed file contiene solo datos de identidad y preferencias — no secretos

DURANTE la instalación:
  El instalador lee el seed file
  Genera llaves en memoria
  Las mueve a Vault cuando esté disponible
  Escribe sección 6 (metadatos) al completar

DESPUÉS de la instalación:
  El seed file queda en /etc/bos/deploy/
  Contiene datos de identidad + metadatos del deploy
  NO contiene credenciales
  Sirve como registro de qué se instaló y con qué configuración
```

### 6.3 Cuenta de emergencia

Siguiendo las mejores prácticas de la industria, el instalador crea automáticamente una cuenta de emergencia (`emergency-admin`) en el realm `master` de Keycloak. Esta cuenta:

- Solo se usa si el administrador principal se bloquea
- No se asigna a ninguna persona específica
- Sus credenciales se imprimen UNA VEZ y se almacenan en Vault
- Debe guardarse offline (caja fuerte, sobre sellado, etc.)

---

## 7. Deploy en Sistema ya Instalado

El deploy también funciona sobre un sistema que ya tiene productos instalados. El instalador evalúa qué productos ya están y solo instala lo que falta:

```bash
# Sistema ya tiene bootstrap + mail instalados
# Ahora quiero agregar erp y documents
bosctl deploy agregar-productos.deploy.yml

[bos] ━━━ Deploy incremental: SKULL S.R.L. ━━━
[bos] Productos solicitados: bootstrap, mail, erp, documents
[bos] Ya instalados: bootstrap ✓, mail ✓
[bos] Pendientes: erp, documents

[bos] ━━━ Producto: erp ━━━
  postgresql → tryton_db NO EXISTE → crear
  ...
  [✓] Producto erp: COMPLETO

[bos] ━━━ Producto: documents ━━━
  postgresql → paperless_db NO EXISTE → crear
  ...
  [✓] Producto documents: COMPLETO

━━━ Deploy incremental COMPLETO ━━━
```

---

## 8. Estructura de Archivos

```
/etc/bos/
  ├── bos.toml                         ← configuración del daemon
  ├── .sbos_state.json                 ← estado (fichas + productos + deploy)
  ├── deploy/
  │   └── skull-empresa.deploy.yml     ← seed file del despliegue
  ├── branding/                        ← identidad visual generada
  │   ├── logo-original.png
  │   ├── favicon.ico
  │   ├── apple-touch-icon.png
  │   ├── android-chrome-192.png
  │   ├── android-chrome-512.png
  │   ├── og-image.png
  │   ├── logo-mono-light.png
  │   ├── logo-mono-dark.png
  │   └── email-signature.html
  ├── blibs/
  │   ├── servers/                     ← fichas
  │   └── products/                    ← manifiestos de producto
  └── assets/                          ← assets originales del cliente (logo fuente)
```

---

## 9. Registro de Cambios

### v1.0 — Marzo 2026

Documento nuevo. Define el concepto de Deploy como manifiesto de cliente, la estructura del seed file con 6 secciones (4 manuales + 2 automáticas), el flujo de procesamiento del instalador con 9 pasos, la resolución de variables con derivaciones automáticas por país, la política de seguridad de credenciales, el deploy incremental, y la cuenta de emergencia.

---

*SKULL · SBOS · SBOS-033-DEPLOY · v1.0 · Marzo 2026*

> **Referencias:** Microsoft Entra tenant creation best practices · Microsoft multitenant deployment architecture · Emergency access accounts (Microsoft) · NIST SP 800-63B (credential management) · ISO 27001 A.9 (access control)
