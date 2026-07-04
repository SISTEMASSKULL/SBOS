# SBOS-034-IDENTITY-GENERATOR
## Generador de Identidad Visual — Branding Automatizado del SBOS

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

**Código:** SBOS-034 (nuevo número — el anterior SBOS-034 de ISMS se renumera)
**Estado:** NUEVO
**Clasificación:** Especificación de Herramienta — Generación de Assets Visuales
**Dependencias documentales:** SBOS-033-DEPLOY (seed file con branding)

---

## 1. Propósito

Cuando el instalador despliega un servidor SBOS para una empresa, cada aplicación del stack necesita la identidad visual del cliente: el login de Keycloak muestra el logo, el correo lleva la firma corporativa, el favicon del navegador refleja la marca, el escritorio virtual tiene los colores de la empresa.

El Identity Generator es una herramienta que toma un **logo fuente** (PNG 512x512 mínimo o SVG) y los **colores corporativos** del seed file, y genera automáticamente todos los formatos, tamaños y variantes que el stack necesita — sin intervención manual del técnico.

---

## 2. Entrada

Del seed file (`deploy.yml → tenant.branding`):

```yaml
branding:
  primary_color: "#1a365d"
  secondary_color: "#2b6cb0"
  accent_color: "#ed8936"
  logo_path: "assets/logo.png"           # Mínimo 512x512 PNG o SVG
  logo_dark_path: "assets/logo-dark.png"  # Para fondos oscuros (opcional)
  favicon_path: "assets/favicon.png"      # Mínimo 256x256 (opcional — si no, usa logo)
  email_signature_html: "assets/email-signature.html"
```

---

## 3. Salida — Assets Generados

### 3.1 Favicons (navegador)

| Archivo | Tamaño | Uso |
|---------|--------|-----|
| `favicon.ico` | 16x16, 32x32, 48x48 (multi-size ICO) | Browsers legacy, PDF embedding |
| `favicon.svg` | Vectorial | Browsers modernos, escala a cualquier tamaño |
| `favicon-16x16.png` | 16x16 | Chrome, Firefox tabs |
| `favicon-32x32.png` | 32x32 | Retina displays, Safari tabs |

### 3.2 Iconos de aplicación móvil / PWA

| Archivo | Tamaño | Uso |
|---------|--------|-----|
| `apple-touch-icon.png` | 180x180 | iOS home screen |
| `android-chrome-192.png` | 192x192 | Android home screen, PWA manifest |
| `android-chrome-512.png` | 512x512 | PWA splash screen, manifest |
| `maskable-icon-512.png` | 512x512 (con safe zone) | PWA adaptive icons (Android) |

### 3.3 Social / Open Graph

| Archivo | Tamaño | Uso |
|---------|--------|-----|
| `og-image.png` | 1200x630 | Facebook, LinkedIn sharing |
| `twitter-card.png` | 1200x600 | Twitter/X card |

### 3.4 Variantes del logo

| Archivo | Descripción | Uso |
|---------|-------------|-----|
| `logo-original.png` | Copia del logo fuente | Referencia |
| `logo-256.png` | 256x256 | Keycloak login, Core UI header |
| `logo-128.png` | 128x128 | Aplicaciones internas |
| `logo-64.png` | 64x64 | Miniaturas |
| `logo-mono-light.png` | Monocromático sobre fondo claro | Documentos, impresión |
| `logo-mono-dark.png` | Monocromático sobre fondo oscuro | Dark mode, Safari pinned tabs |
| `logo-inverted.png` | Colores invertidos | Fondos con colores corporativos |

### 3.5 Correo electrónico

| Archivo | Descripción | Uso |
|---------|-------------|-----|
| `email-signature.html` | Template HTML con logo incrustado y datos de empresa | Roundcube, Cypht, configuración por defecto |
| `email-logo.png` | Logo optimizado para email (max 200px ancho) | Incrustado en firma HTML |
| `email-banner.png` | Banner con logo + colores (600x100) | Headers de notificaciones |

### 3.6 Keycloak Theme

| Archivo | Descripción | Uso |
|---------|-------------|-----|
| `keycloak-logo.png` | Logo para pantalla de login | Keycloak theme custom |
| `keycloak-bg.css` | CSS con colores corporativos | Theme de login y account |
| `keycloak-favicon.ico` | Favicon del portal de identidad | Pestaña del navegador en auth |

### 3.7 Manifest y metadatos

| Archivo | Descripción | Uso |
|---------|-------------|-----|
| `site.webmanifest` | Manifest PWA con icons y colores | Instalación como PWA |
| `browserconfig.xml` | Configuración Windows tiles | Microsoft Edge |
| `head-tags.html` | Fragmento HTML con todos los `<link>` necesarios | Inyectar en `<head>` de cada app web |

---

## 4. Herramientas de Generación

El generador usa `sharp` (Node.js) como motor principal — es la librería de procesamiento de imágenes más rápida y está compilada con libvips nativo. No requiere software externo (ImageMagick, GraphicsMagick, etc.).

```bash
# Dependencias del generador
npm install sharp sharp-ico
```

### 4.1 Pipeline de generación

```
logo.png (512x512+)
  │
  ├──▶ sharp.resize() → favicon-16.png, favicon-32.png, favicon-48.png
  │      └──▶ sharp-ico → favicon.ico (multi-size)
  │
  ├──▶ sharp.resize() → apple-touch-icon.png (180x180)
  ├──▶ sharp.resize() → android-chrome-192.png, android-chrome-512.png
  ├──▶ sharp.resize() + sharp.extend() → maskable-icon-512.png (con padding safe zone 20%)
  │
  ├──▶ sharp.resize() → logo-256.png, logo-128.png, logo-64.png
  ├──▶ sharp.greyscale() → logo-mono-light.png
  ├──▶ sharp.greyscale().negate() → logo-mono-dark.png
  │
  ├──▶ sharp.composite() + banner template → og-image.png (1200x630)
  ├──▶ sharp.composite() + banner template → twitter-card.png (1200x600)
  │
  ├──▶ sharp.resize(200) → email-logo.png
  ├──▶ sharp.composite() + banner template → email-banner.png (600x100)
  │
  └──▶ Template engine → site.webmanifest, browserconfig.xml, head-tags.html
                          keycloak-bg.css, email-signature.html
```

### 4.2 Integración con el instalador

El generador se ejecuta durante el paso 3 del deploy (SBOS-033-DEPLOY §4):

```
bosctl deploy cliente.deploy.yml
  │
  ├── 1. Validar seed file
  ├── 2. Generar llaves maestras
  ├── 3. GENERAR IDENTIDAD VISUAL  ← aquí
  │       sbos-identity-generator assets/logo.png /etc/bos/branding/ \
  │         --primary "#1a365d" \
  │         --secondary "#2b6cb0" \
  │         --accent "#ed8936" \
  │         --company "SKULL S.R.L." \
  │         --domain "skull.io"
  │
  ├── 4. Ejecutar productos...
  └── 5. Aplicar identidad visual a Keycloak, NGINX, correo...
```

---

## 5. Dónde se Inyectan los Assets

| Aplicación | Assets inyectados | Mecanismo |
|------------|-------------------|-----------|
| **Keycloak** | keycloak-logo.png, keycloak-bg.css, keycloak-favicon.ico | Custom theme en `/opt/keycloak/themes/sbos/` |
| **NGINX** | favicon.ico, favicon.svg | Copiados a `/var/www/html/` del pod |
| **Kong** | Ninguno directo | Las apps detrás de Kong usan sus propios assets |
| **Roundcube** | email-signature.html, email-logo.png | Configuración por defecto de firma |
| **Grafana** | logo-256.png, favicon.ico | Custom branding vía `grafana.ini` |
| **Core UI** (futuro) | logo-256.png, favicon.ico, site.webmanifest, head-tags.html | Assets estáticos del frontend Flutter |
| **SBOS VDI** (futuro) | logo-128.png, colores CSS | Configuración de KDE Plasma theme |
| **Documentos PDF** | logo-mono-light.png | Template de reportes JasperSoft |

---

## 6. CLI del Generador

```bash
# Generar todos los assets desde un logo
sbos-identity-generator <logo-path> <output-dir> [opciones]

# Opciones
  --primary <color>      Color primario (hex)
  --secondary <color>    Color secundario (hex)
  --accent <color>       Color de acento (hex)
  --company <nombre>     Nombre de empresa (para OG image y manifests)
  --domain <dominio>     Dominio (para manifests y URLs)
  --dark-logo <path>     Logo alternativo para fondos oscuros
  --favicon-source <path> Imagen fuente diferente para favicon
  --skip-social          No generar OG image ni Twitter card
  --skip-email           No generar assets de correo
  --skip-keycloak        No generar theme de Keycloak
  --format <json|text>   Formato de reporte de salida

# Ejemplo
sbos-identity-generator assets/logo.png /etc/bos/branding/ \
  --primary "#1a365d" --secondary "#2b6cb0" --accent "#ed8936" \
  --company "SKULL S.R.L." --domain "skull.io"

# Salida
[✓] favicon.ico (16, 32, 48)
[✓] favicon.svg
[✓] apple-touch-icon.png (180x180)
[✓] android-chrome-192.png
[✓] android-chrome-512.png
[✓] maskable-icon-512.png
[✓] og-image.png (1200x630)
[✓] twitter-card.png (1200x600)
[✓] logo-256.png, logo-128.png, logo-64.png
[✓] logo-mono-light.png, logo-mono-dark.png
[✓] email-logo.png, email-banner.png, email-signature.html
[✓] keycloak-logo.png, keycloak-bg.css, keycloak-favicon.ico
[✓] site.webmanifest, browserconfig.xml, head-tags.html

27 assets generados en /etc/bos/branding/
```

---

## 7. Registro de Cambios

### v1.0 — Marzo 2026

Documento nuevo. Define el generador de identidad visual que automatiza la creación de todos los formatos de logo, favicon, iconos PWA, assets de correo, theme de Keycloak y manifests desde un logo fuente y colores corporativos del seed file.

---

*SKULL · SBOS · SBOS-034-IDENTITY-GENERATOR · v1.0 · Marzo 2026*

> **Referencias:** sharp (libvips) — procesamiento de imágenes Node.js · pwa-asset-generator — generación de assets PWA · RealFaviconGenerator — estándar de la industria para favicon · Web App Manifest specification (W3C) · Apple Human Interface Guidelines (Touch Icons) · Open Graph protocol (Facebook) · Twitter Card specification
