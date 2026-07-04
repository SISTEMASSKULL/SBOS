# SBOS-038-IDENTITY-VISUAL
## Generador de Identidad Visual — Estándar HUMAN-DOC
### SKULL · SBOS · v1.0 · Abril 2026

---

## 1. Propósito

Toma logo fuente (PNG 512x512+ o SVG) + colores corporativos del seed file → genera automáticamente todos los formatos, tamaños y variantes que el stack necesita. Sin intervención manual del técnico.

## 2. Entrada (del seed file)

```yaml
branding:
  primary_color: "#1a365d"
  secondary_color: "#2b6cb0"
  accent_color: "#ed8936"
  logo_path: "assets/logo.png"        # mínimo 512x512
  logo_dark_path: "assets/logo-dark.png"  # opcional
  favicon_path: "assets/favicon.png"  # opcional
  email_signature_html: "assets/email-signature.html"
```

## 3. Assets Generados (27 archivos)

### Favicons
favicon.ico (16/32/48 multi-size), favicon.svg, favicon-16x16.png, favicon-32x32.png.

### Iconos PWA/Móvil
apple-touch-icon.png (180x180), android-chrome-192.png, android-chrome-512.png, maskable-icon-512.png (con safe zone 20%).

### Social/Open Graph
og-image.png (1200x630), twitter-card.png (1200x600).

### Variantes de Logo
logo-original.png, logo-256.png, logo-128.png, logo-64.png, logo-mono-light.png (greyscale), logo-mono-dark.png (greyscale+negate), logo-inverted.png.

### Correo Electrónico
email-signature.html (template con logo + datos empresa), email-logo.png (max 200px), email-banner.png (600x100).

### Keycloak Theme
keycloak-logo.png, keycloak-bg.css (colores corporativos), keycloak-favicon.ico.

### Manifests
site.webmanifest (PWA), browserconfig.xml (Windows tiles), head-tags.html (fragmento `<link>` para inyectar).

## 4. Pipeline de Generación

Motor: `sharp` (Node.js, compilado con libvips nativo). Sin dependencias externas (ImageMagick, etc.).

```
logo.png (512x512+)
  ├── sharp.resize → favicons (16, 32, 48) → sharp-ico → favicon.ico
  ├── sharp.resize → apple-touch-icon, android-chrome (192, 512)
  ├── sharp.resize + extend → maskable-icon (padding safe zone)
  ├── sharp.resize → logo variantes (256, 128, 64)
  ├── sharp.greyscale → mono-light | sharp.greyscale.negate → mono-dark
  ├── sharp.composite + template → og-image, twitter-card
  ├── sharp.resize(200) → email-logo | sharp.composite → email-banner
  └── Template engine → webmanifest, browserconfig, head-tags, keycloak-bg.css
```

## 5. Inyección en el Stack

| Aplicación | Assets | Mecanismo |
|---|---|---|
| Keycloak | logo, CSS colores, favicon | Custom theme /opt/keycloak/themes/sbos/ |
| NGINX | favicon.ico, favicon.svg | /var/www/html/ |
| Roundcube | email-signature.html, email-logo | Firma por defecto |
| Grafana | logo-256, favicon | Custom branding grafana.ini |
| Core UI (futuro) | logo-256, favicon, webmanifest, head-tags | Assets estáticos Flutter |
| SBOS VDI (futuro) | logo-128, colores CSS | KDE Plasma theme |
| Documentos PDF | logo-mono-light | Template reportes |

## 6. CLI

```bash
sbos-identity-generator assets/logo.png /etc/bos/branding/ \
  --primary "#1a365d" --secondary "#2b6cb0" --accent "#ed8936" \
  --company "SKULL S.R.L." --domain "skull.io"

# Output: 27 assets generados en /etc/bos/branding/
```

Se ejecuta durante paso 3 del deploy (SBOS-037 §4).

---

## Trazabilidad

| Sección | Extraída de | Secciones originales |
|---|---|---|
| §1-2 | SBOS-034 v1.0 | §1-§2 (propósito, entrada) |
| §3 Assets | SBOS-034 v1.0 | §3 completo (7 categorías, 27 archivos con tamaños y uso) |
| §4 Pipeline | SBOS-034 v1.0 | §4 (sharp pipeline, integración instalador) |
| §5 Inyección | SBOS-034 v1.0 | §5 (tabla 7 aplicaciones con mecanismo) |
| §6 CLI | SBOS-034 v1.0 | §6 (ejemplo completo con flags) |

---

---

# ENRIQUECIMIENTO V8 — SBOS-038-IDENTITY-VISUAL

## V5 — Enriquecimiento desde BOS_V5_SBOS-034-IDENTITY-GENERATOR-v1_0

### V5 §1 — Detalle de Assets por Categoría

**7 categorías con 27 archivos totales:**

| Categoría | Archivos | Formatos | Tamaños |
|---|---|---|---|
| Favicons | 4 | .ico, .svg, .png | 16×16, 32×32, 48×48 |
| PWA/Móvil | 4 | .png | 180×180, 192×192, 512×512 |
| Social/OG | 2 | .png | 1200×630, 1200×600 |
| Logo variantes | 7 | .png | original, 256, 128, 64, mono-light, mono-dark, inverted |
| Correo | 3 | .html, .png | logo 200×max, banner 600×100 |
| Keycloak | 3 | .png, .css, .ico | logo personalizado, CSS tema |
| Manifiestos | 4 | .webmanifest, .xml, .html | PWA, tiles, head-tags |

### V5 §2 — Pipeline expandido con sharp

**sharp pipeline completo:**
```javascript
const sharp = require('sharp');
const fs = require('fs');

async function generateAssets(logoPath, outputDir, colors, company, domain) {
  const logo = sharp(logoPath);
  const metadata = await logo.metadata();

  // 1. Favicon .ico (16, 32, 48)
  await sharp(logoPath)
    .resize(16, 16)
    .toFile(`${outputDir}/favicon-16x16.png`);
  // ... similar para 32, 48, luego combinar con sharp-ico

  // 2. Apple touch icon (180x180)
  await sharp(logoPath)
    .resize(180, 180)
    .toFile(`${outputDir}/apple-touch-icon.png`);

  // 3. Android Chrome (192, 512)
  await sharp(logoPath)
    .resize(192, 192)
    .toFile(`${outputDir}/android-chrome-192.png`);

  // 4. Maskable icon (512 + safe zone 20%)
  await sharp(logoPath)
    .resize(410, 410)  // 80% of 512 = 410
    .extend({
      top: 51, bottom: 51, left: 51, right: 51,
      background: { r: 255, g: 255, b: 255, alpha: 1 }
    })
    .toFile(`${outputDir}/maskable-icon-512.png`);

  // 5. Logo variants
  await sharp(logoPath).resize(256, 256).toFile(`${outputDir}/logo-256.png`);
  await sharp(logoPath).resize(128, 128).toFile(`${outputDir}/logo-128.png`);
  await sharp(logoPath).resize(64, 64).toFile(`${outputDir}/logo-64.png`);
  await sharp(logoPath).greyscale().toFile(`${outputDir}/logo-mono-light.png`);
  await sharp(logoPath).greyscale().negate().toFile(`${outputDir}/logo-mono-dark.png`);

  // 6. OG image (1200x630 with company name overlay)
  const ogImage = await sharp(logoPath)
    .resize(300, 300)
    .flatten({ background: colors.primary });
  // Composite company name text overlay
  const svgText = `<svg width="1200" height="630">
    <text x="600" y="400" text-anchor="middle" fill="white" font-size="48">${company}</text>
  </svg>`;
  await sharp({
    create: { width: 1200, height: 630, channels: 4, background: colors.primary }
  })
    .composite([
      { input: await ogImage.toBuffer(), top: 100, left: 450 },
      { input: Buffer.from(svgText), top: 0, left: 0 }
    ])
    .toFile(`${outputDir}/og-image.png`);
}
```

### V5 §3 — CLI Expandido con Flags y Opciones

```bash
# Uso completo
sbos-identity-generator <logo_path> <output_dir> \
  --primary "#1a365d" \
  --secondary "#2b6cb0" \
  --accent "#ed8936" \
  --company "SKULL S.R.L." \
  --domain "skull.io" \
  --company-legal "SKULL Tecnología y Sistemas S.R.L." \
  --email "admin@skull.io" \
  --phone "+591 2 1234567" \
  --address "Calle 1, Edificio 2, La Paz" \
  --social-facebook "https://facebook.com/skull" \
  --social-linkedin "https://linkedin.com/company/skull" \
  --dark-logo "assets/logo-dark.png" \
  --icon-only

# Flags
# --icon-only: generar solo favicons e iconos (saltar variantes logo grandes)
# --skip-email: no generar assets de correo
# --skip-keycloak: no generar theme de Keycloak
# --dry-run: validar entrada sin generar archivos
# --verbose: logging detallado por asset
```

---

## Smart* — Enriquecimiento desde SBOS-IAM-Style

### Smart IAM Style — Brand System Vision (01_brand-system_vision)

**Jerarquía de marca SKULL/SBOS:**
```
SKULL ©
  └── SBOS (Smart Business Operating System)
      ├── Smart[X] (acento cyan #06B6D4): VaultFlow, ORC, Pay, Report, Tax, Portfolio, Rates
      └── Daemons Soberanos (acento red #DC2626): bos, bkernel, biedata, bcompass, bsearch, bauth, bhnexus, banexus
```

**El isotipo sigma (σ):**
El isotipo del sistema es una sigma (σ) estilizada con semántica múltiple:
- σ = Six Sigma — control estadístico de calidad, mejora continua
- σ = Sumatoria — integración total de dominios, suma de capacidades
- Flecha del ciclo — ciclo PDCA (Plan-Do-Check-Act) continuo
- Forma visual = S implícita → SKULL y SBOS

**Sistema de color activo (Tailwind CSS v4):**
| Capa | Entidades | Color activo | HEX |
|---|---|---|---|
| Capa 0 | SKULL / SBOS | Slate Deep | #334155 |
| Capa 1 | Smart[X] | Cyan | #06B6D4 |
| Capa 2 | Daemons | Red | #DC2626 |
| IA | AI Tools | Violet | #8B5CF6 |

### Smart IAM Style — Composition Engine (06-A_logo-generator_composition-engine)

**Sistema de proporciones — Unidad Base U:**
U = alto del isotipo (IS). Es el punto de referencia de todas las proporciones del sistema. U = 100 unidades de Illustrator (artboard del isotipo cuadrado 100×100).

**Tamaños de elementos en U:**
| Elemento | Alto | Ancho |
|---|---|---|
| IS (isotipo) | 1.00 U | 1.00 U |
| MR (marca) | 0.55 U | ~2.60 U |
| CP (copyright) | 0.18 U | 0.18 U |
| NC (nombre comercial) | 0.14 U | ~2.80 U |
| DIV (línea divisoria) | 0.008 U | variable |
| RBR (rubro) | 0.130 U | ~2.60 U |
| ESL (eslogan) | 0.110 U | ~2.40 U |

**Catálogo de composiciones oficiales:**
| Código | Nombre | Eje |
|---|---|---|
| COMP_ISO | Solo isotipo | centrado |
| COMP_WM | Solo wordmark | centrado |
| COMP_CPT | Compacto | horizontal |
| COMP_H | Horizontal completo | horizontal |
| COMP_V | Vertical completo | vertical |
| COMP_HERO | Gran formato | vertical |
| COMP_EML | Firma de email | horizontal |
| COMP_WMK | Marca de agua | centrado |
| COMP_SEAL | Sello / certificado | centrado circular |
| COMP_DUAL | Co-branding dos marcas | horizontal |
| COMP_TRI | Co-branding tres marcas | horizontal |

---

## Fuentes de Enriquecimiento V8

| Fuente | Archivo | Secciones utilizadas |
|---|---|---|
| V6 original | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V6_SBOS-038-IDENTITY-VISUAL.md` | Documento completo (102 líneas) |
| V5 Identity | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-034-IDENTITY-GENERATOR-v1_0.md` | §1 Detalle 27 assets/7 categorías, §2 Pipeline sharp expandido, §3 CLI completo |
| IAM Style Brand Vision | `/opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS-IAM-Style/context/01_brand-system_vision.md` | Jerarquía SKULL/SBOS, isotipo sigma, sistema de color activo, 15 principios rectores |
| IAM Style Composition Engine | `/opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS-IAM-Style/context/06-A_logo-generator_composition-engine.md` | Unidad base U, catálogo 11 composiciones, gap system, co-branding DUAL/TRI |

---

_SKULL · SBOS · SBOS-038-IDENTITY-VISUAL · V8 (V6+V5+Smart*) · Mayo 2026_
