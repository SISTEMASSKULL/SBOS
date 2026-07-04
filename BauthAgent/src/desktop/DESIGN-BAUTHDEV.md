# DESIGN-BAUTHDEV — Sistema de Diseño para Claude Design

**Versión:** 1.0.0 · **Fecha:** 2026-06-28 · **Autor:** sbos-coordinador
**Proyecto:** bAuthDEV — Plataforma de Desarrollo e Integración bAuth (GUI)
**Objetivo:** Especificación completa de pantallas para que Claude Design genere el UI Kit HTML/CSS
**Stack destino:** HTML5 + CSS3 + JavaScript vanilla (progresivo hacia Flutter 3.44+)
**Inspiración:** Postman (testeo API) + Warp Terminal (bloques) + Stripe Dashboard (experiencia dev)

---

## 0. INSTRUCCIONES PARA CLAUDE DESIGN

### 0.1 Cómo usar este documento

Este documento es una **especificación de diseño completa** para Claude Design. Contiene:

1. **Token de diseño** — colores, tipografía, espaciado, sombras (CSS custom properties)
2. **Catálogo de componentes** — cada componente con sus estados, variantes y comportamiento
3. **Estructura de pantallas** — layout exacto, jerarquía de paneles, navegación
4. **Flujos de usuario** — secuencias de interacción paso a paso
5. **Guía de implementación** — orden de construcción, dependencias entre pantallas

### 0.2 Formato de salida esperado

Claude Design debe generar:

```
desktop/bAuthDEV-ui-kit/
├── README.md                          # Contexto de marca y guía de uso
├── tokens/
│   ├── colors.css                     # CSS custom properties de color
│   ├── typography.css                 # Escala tipográfica + Google Fonts
│   ├── spacing.css                    # Escala de espaciado + grid
│   └── depth.css                      # Sombras, elevación, capas
├── components/
│   ├── button.html                    # Botones (primario, secundario, icono, peligro)
│   ├── input.html                     # Campos de texto, search, select
│   ├── panel.html                     # Paneles colapsables/expandibles
│   ├── tree.html                      # Árbol jerárquico (catálogo de métodos)
│   ├── block.html                     # Bloque de cinta (Calculator Tape)
│   ├── editor.html                    # Editor JSON con resaltado
│   ├── badge.html                     # Badges de estado, etiquetas
│   ├── tab.html                       # Pestañas de navegación
│   ├── modal.html                     # Modales y popups
│   ├── tooltip.html                   # Tooltips y ayuda contextual
│   └── console.html                   # Consola segura de comandos
├── screens/
│   ├── 01-connection.html             # Pantalla de conexión
│   ├── 02-login.html                  # Login / Autenticación del desarrollador
│   ├── 03-register.html               # Registro de desarrollador (TRIAL)
│   ├── 04-dashboard.html              # Dashboard principal del tenant
│   ├── 05-explorer-editor.html        # Layout 3 paneles: explorador + editor + respuesta
│   ├── 06-tape-blocks.html            # Cinta de bloques (Calculator Tape)
│   ├── 07-token-lab.html              # Laboratorio de Tokens (4 variantes)
│   ├── 08-template-creator.html       # Creador de Plantillas (Roles/Usuarios)
│   ├── 09-blockchain-lab.html         # Laboratorio Blockchain + Merkle
│   ├── 10-signature-lab.html          # Laboratorio de Firma Digital
│   ├── 11-collections.html            # Colecciones y entornos
│   ├── 12-wizard-flow.html            # Flujos guiados (Wizards)
│   ├── 13-tenant-profile.html         # Perfil del Tenant + Plan contratado
│   ├── 14-companies.html              # Gestión de Empresas cliente (CRUD)
│   ├── 15-branches.html               # Gestión de Sucursales por empresa
│   ├── 16-client-users.html           # Usuarios de las empresas cliente
│   ├── 17-usage-tracking.html         # Tracking de uso por empresa/sucursal
│   └── 18-support.html                # Soporte y colaboración SBOS
└── index.html                         # UI Kit completo con navegación entre pantallas
```

### 0.3 Reglas de implementación para Claude Design

| # | Regla | Detalle |
|---|-------|---------|
| R1 | **CSS custom properties** | Todos los colores, fuentes, espaciados y sombras como variables CSS en `:root` |
| R2 | **Semántica HTML5** | Usar `<header>`, `<nav>`, `<main>`, `<aside>`, `<section>`, `<article>` apropiadamente |
| R3 | **Estados completos** | Cada componente debe tener: default, hover, focus, active, disabled, loading, error, empty |
| R4 | **Sin frameworks CSS** | Solo CSS vanilla con custom properties. Sin Tailwind, Bootstrap, Material |
| R5 | **Responsive** | 3 breakpoints: `--bp-compact` (900px), `--bp-tablet` (1200px), `--bp-desktop` (1440px+) |
| R6 | **Tema oscuro por defecto** | El tema base es oscuro (SBOS Dark). Tema claro como `[data-theme="light"]` |
| R7 | **Teclado primero** | Todo operable sin mouse: `Tab`, `↑↓←→`, `Enter`, `Esc`, `Space`, `Ctrl+K` (búsqueda) |
| R8 | **Preview cards** | Cada pantalla y componente incluye `<!-- @dsCard group="Nombre del Grupo" -->` |
| R9 | **Español** | Todo el texto de interfaz en español. Comentarios CSS/HTML también en español |
| R10 | **Modo standalone** | Cada HTML se puede abrir directamente en el navegador sin servidor |

---

## 1. TEMA VISUAL — SBOS Dark Professional

### 1.1 Atmósfera y personalidad

```
┌──────────────────────────────────────────────────────────────────────┐
│  PERSONALIDAD DE MARCA — SBOS bAuthDEV                               │
│                                                                      │
│  🎯 Para:    Desarrolladores backend/frontend integrando auth        │
│  🏢 Entorno: Terminal, IDE, herramientas de desarrollo               │
│  🧠 Estado:  Concentración profunda, flujo de trabajo, productividad │
│                                                                      │
│  NO es:      Una app de consumo masivo                               │
│  NO es:      Un dashboard ejecutivo con métricas de negocio          │
│  NO es:      Una landing page de marketing                           │
│                                                                      │
│  ES:         Una herramienta de precisión para desarrolladores       │
│  ES:         Un entorno de trabajo que inspira confianza técnica     │
│  ES:         Una interfaz que desaparece — el foco está en los datos │
│                                                                      │
│  TONO:       Profesional, técnico, minimalista, sin distracciones    │
│  DENSIDAD:   Alta — mucha información en poco espacio (como un IDE)  │
│  RITMO:      Estructurado — paneles, pestañas, árboles, bloques      │
└──────────────────────────────────────────────────────────────────────┘
```

### 1.2 Paleta de colores — CSS Custom Properties

```css
:root {
  /* ── FONDO (Background Layers) ─────────────────────────── */
  --color-bg-root:        #080C11;    /* Fondo raíz — el más profundo */
  --color-bg-primary:     #0D1117;    /* Fondo principal de paneles */
  --color-bg-secondary:   #12171E;    /* Fondo secundario — cards, bloques */
  --color-bg-tertiary:    #171E28;    /* Fondo terciario — inputs, áreas activas */
  --color-bg-elevated:    #1C2430;    /* Fondo elevado — modales, popups */
  --color-bg-hover:       #212A38;    /* Hover sobre superficies */
  --color-bg-active:      #263040;    /* Activo/seleccionado */

  /* ── BORDES (Border System) ────────────────────────────── */
  --color-border-subtle:  #1A2332;    /* Borde sutil — separadores pasivos */
  --color-border-default: #253040;    /* Borde por defecto */
  --color-border-strong:  #304058;    /* Borde fuerte — foco activo */
  --color-border-accent:  #3B82F6;    /* Borde acento — selección activa */

  /* ── TEXTO (Text Hierarchy) ────────────────────────────── */
  --color-text-primary:   #E6EDF5;    /* Texto principal — lectura */
  --color-text-secondary: #8B9CB5;    /* Texto secundario — etiquetas, ayuda */
  --color-text-tertiary:  #5B6E85;    /* Texto terciario — placeholders, deshabilitado */
  --color-text-inverse:   #0D1117;    /* Texto sobre fondo claro */

  /* ── ACCIONES (Action Colors) ──────────────────────────── */
  --color-accent-primary: #3B82F6;    /* Acción principal — botones, links */
  --color-accent-hover:   #4F94F7;    /* Hover sobre acción principal */
  --color-accent-active:  #2563EB;    /* Active/press sobre acción principal */
  --color-accent-subtle:  rgba(59,130,246,0.12); /* Fondo sutil de acento */

  /* ── SEMÁNTICA (Semantic Colors) ───────────────────────── */
  --color-success:        #22C55E;    /* Éxito — allow, OK, completado */
  --color-success-bg:     rgba(34,197,94,0.10);
  --color-warning:        #EAB308;    /* Advertencia — precaución, degradado */
  --color-warning-bg:     rgba(234,179,8,0.10);
  --color-error:          #EF4444;    /* Error — deny, fallo, crítico */
  --color-error-bg:       rgba(239,68,68,0.10);
  --color-info:           #06B6D4;    /* Información — neutral, métricas */
  --color-info-bg:        rgba(6,182,212,0.10);

  /* ── DOMINIOS (12 Domain Colors) ───────────────────────── */
  --color-d1-logical:     #8B5CF6;    /* D1 — Lógico (apps, módulos) */
  --color-d2-physical:    #F97316;    /* D2 — Físico (edificios, zonas) */
  --color-d3-financial:   #22C55E;    /* D3 — Financiero (límites, SoD) */
  --color-d4-temporal:    #3B82F6;    /* D4 — Temporal (horarios) */
  --color-d5-biometric:   #EC4899;    /* D5 — Biométrico (LoA) */
  --color-d6-geospatial:  #14B8A6;    /* D6 — Geoespacial */
  --color-d7-network:     #6366F1;    /* D7 — Red (CIDR, ZTNA) */
  --color-d8-context:     #A855F7;    /* D8 — Contexto (ctx_id) */
  --color-d9-credential:  #EAB308;    /* D9 — Credenciales */
  --color-d10-audit:      #787B86;    /* D10 — Auditoría */
  --color-d11-delegation: #FB923C;    /* D11 — Delegación */
  --color-d12-blockchain: #06B6D4;    /* D12 — Blockchain */

  /* ── CÓDIGO (Code Editor Colors) ───────────────────────── */
  --color-code-bg:        #0A0E14;    /* Fondo del editor */
  --color-code-string:    #A5D6FF;    /* Strings JSON */
  --color-code-number:    #FFC48C;    /* Números */
  --color-code-boolean:   #FF8CBF;    /* Booleanos */
  --color-code-null:      #FF6B6B;    /* Null */
  --color-code-key:       #8BB8F2;    /* Claves JSON */
  --color-code-method:    #C4A5FF;    /* Métodos bAuth */
  --color-code-comment:   #5B6E85;    /* Comentarios */
  --color-code-error:     #FF6B6B;    /* Error de sintaxis */
}
```

### 1.3 Tipografía

```css
@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600&family=Inter:wght@400;500;600;700&display=swap');

:root {
  /* ── FAMILIAS ──────────────────────────────────────────── */
  --font-sans:      'Inter', system-ui, -apple-system, sans-serif;
  --font-mono:      'JetBrains Mono', 'Cascadia Code', 'Fira Code', monospace;

  /* ── ESCALA TIPOGRÁFICA (Major Third 1.25) ────────────── */
  --text-xs:    0.6875rem;    /* 11px — badges, etiquetas pequeñas */
  --text-sm:    0.8125rem;    /* 13px — texto secundario, ayuda */
  --text-base:  0.9375rem;    /* 15px — texto de cuerpo (óptimo lectura) */
  --text-md:    1.0625rem;    /* 17px — texto de panels, listas */
  --text-lg:    1.25rem;      /* 20px — subtítulos */
  --text-xl:    1.5rem;       /* 24px — títulos de sección */
  --text-2xl:   1.875rem;     /* 30px — títulos de pantalla */
  --text-3xl:   2.375rem;     /* 38px — hero, dashboard principal */

  /* ── PESOS ─────────────────────────────────────────────── */
  --font-normal:    400;
  --font-medium:    500;
  --font-semibold:  600;
  --font-bold:      700;

  /* ── ALTURAS DE LÍNEA ──────────────────────────────────── */
  --leading-tight:  1.2;    /* Títulos */
  --leading-normal: 1.5;    /* Texto cuerpo */
  --leading-relaxed:1.7;    /* Texto largo, documentación */

  /* ── ESPACIADO ENTRE LETRAS ────────────────────────────── */
  --tracking-tight: -0.02em;  /* Títulos grandes */
  --tracking-normal: 0;       /* Texto normal */
  --tracking-mono:   -0.01em; /* Código monoespaciado */
}
```

### 1.4 Espaciado y Grid

```css
:root {
  /* ── ESCALA DE ESPACIADO (4px base) ───────────────────── */
  --space-0:   0;
  --space-1:   0.25rem;   /* 4px */
  --space-2:   0.5rem;    /* 8px */
  --space-3:   0.75rem;   /* 12px */
  --space-4:   1rem;      /* 16px */
  --space-5:   1.25rem;   /* 20px */
  --space-6:   1.5rem;    /* 24px */
  --space-8:   2rem;      /* 32px */
  --space-10:  2.5rem;    /* 40px */
  --space-12:  3rem;      /* 48px */
  --space-16:  4rem;      /* 64px */

  /* ── BORDES REDONDEADOS ────────────────────────────────── */
  --radius-none:   0;
  --radius-sm:     0.25rem;   /* 4px — inputs pequeños, badges */
  --radius-md:     0.375rem;  /* 6px — botones, inputs */
  --radius-lg:     0.5rem;    /* 8px — cards, paneles */
  --radius-xl:     0.75rem;   /* 12px — modales */
  --radius-full:   9999px;    /* Píldoras, badges circulares */

  /* ── LAYOUT ────────────────────────────────────────────── */
  --sidebar-width:         260px;    /* Explorador de métodos */
  --editor-min-width:      400px;    /* Ancho mínimo del editor */
  --response-min-width:    350px;    /* Ancho mínimo del visor */
  --console-height:        200px;    /* Altura de la consola inferior */
  --topbar-height:         44px;     /* Barra superior */
  --statusbar-height:      28px;     /* Barra de estado inferior */
}
```

### 1.5 Sombras y Elevación

```css
:root {
  /* ── CAPAS (z-index system) ────────────────────────────── */
  --z-base:         0;      /* Contenido normal */
  --z-dropdown:     100;    /* Dropdowns, autocompletados */
  --z-sticky:       200;    /* Headers sticky, tabs */
  --z-overlay:      300;    /* Overlays, máscaras */
  --z-modal:        400;    /* Modales, diálogos */
  --z-tooltip:      500;    /* Tooltips, popovers */
  --z-toast:        600;    /* Notificaciones toast */

  /* ── SOMBRAS (Tema Oscuro — las sombras son "luces") ────── */
  --shadow-none:    none;
  --shadow-sm:      0 1px 2px rgba(0,0,0,0.3), 0 0 1px rgba(255,255,255,0.03);
  --shadow-md:      0 4px 8px rgba(0,0,0,0.4), 0 0 2px rgba(255,255,255,0.04);
  --shadow-lg:      0 8px 24px rgba(0,0,0,0.5), 0 0 4px rgba(255,255,255,0.05);
  --shadow-xl:      0 16px 48px rgba(0,0,0,0.6);
  --shadow-glow:    0 0 12px rgba(59,130,246,0.15);  /* Glow para foco */
  --shadow-glow-error: 0 0 12px rgba(239,68,68,0.15);
}
```

---

## 1bis. ARQUITECTURA DE LAYOUT GLOBAL — 3 Columnas

### Principio

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  bAuthDEV — Layout Global                                                    │
│                                                                              │
│  ┌──────────┬──────────────────────────────────────────┬──────────────────┐ │
│  │          │                                          │                  │ │
│  │  LEFT    │              CENTER BODY                 │  RIGHT           │ │
│  │  SIDEBAR │              (área principal)            │  SIDEBAR         │ │
│  │          │                                          │                  │ │
│  │  Naveg.  │  Todo el contenido se renderiza aquí:    │  Catálogo de     │ │
│  │  princi. │  • Editor + Respuesta                    │  métodos         │ │
│  │          │  • Cinta de bloques                      │  (colapsable)    │ │
│  │  🔌      │  • Labs (Token, Blockchain, Firma)       │                  │ │
│  │  📊      │  • Dashboard                             │  🔍 Buscar       │ │
│  │  🧪      │  • Empresas / Sucursales                 │  ─────────       │ │
│  │  📜      │  • Colecciones                           │  📁 Auth         │ │
│  │  📦      │  • Soporte                               │    .issue       │ │
│  │  🏢      │  • Wizards                               │    .validate    │ │
│  │  👤      │                                          │  📁 Token        │ │
│  │  🎓      │                                          │    .emission    │ │
│  │          │                                          │  ...             │ │
│  │  ─────── │                                          │                  │ │
│  │  🟢 v3.0 │                                          │  📋 Comandos     │ │
│  │  12d 4h  │                                          │  recientes       │ │
│  │          │                                          │                  │ │
│  └──────────┴──────────────────────────────────────────┴──────────────────┘ │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────────┐ │
│  │  🧭 CONSOLA SEGURA (colapsable) — escribe un método y presiona Enter    │ │
│  └──────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Dimensiones

| Panel | Ancho | Comportamiento |
|-------|:---:|------|
| **Left Sidebar** | 56px → 220px | Colapsado: solo iconos. Expandido (hover/click): iconos + labels |
| **Center Body** | Flexible (resto) | Área de trabajo principal. Ocupa todo el espacio disponible |
| **Right Sidebar** | 0px → 300px | Colapsable. Se abre al seleccionar método o con `Ctrl+B` |
| **Consola** | Full width, 0px → 200px | Colapsable. Se abre con `` ` `` (backtick) o click en borde inferior |

### Left Sidebar — Navegación Principal

```
┌────────────┐          ┌──────────────────┐
│ 🛡️         │          │ 🛡️ bAuthDEV      │
│ ─────────  │          │ ───────────────  │
│ 🔌         │ hover →  │ 🔌 Conexión      │
│ 📊         │          │ 📊 Dashboard     │
│ 🧪         │          │ 🧪 Labs          │
│ 📜         │          │ 📜 Historial     │
│ 📦         │          │ 📦 Colecciones   │
│ 🏢         │          │ 🏢 Mis Empresas  │
│ 👤         │          │ 👤 Mi Cuenta     │
│ 🎓         │          │ 🎓 Soporte       │
│ ─────────  │          │ ───────────────  │
│ ⚙          │          │ ⚙ Configuración │
│            │          │                  │
│ ─────────  │          │ ───────────────  │
│ 🟢         │          │ 🟢 Conectado     │
│            │          │ v3.0.0 · 12d 4h  │
└────────────┘          └──────────────────┘
  COLAPSADO               EXPANDIDO (hover)
  (solo iconos)           (iconos + labels)
  56px                    220px
```

**Items de navegación:**

| Icono | Label | Destino | Atajo |
|:---:|------|------|-------|
| 🛡️ | bAuthDEV | Logo — click va a Dashboard | — |
| 🔌 | Conexión | Pantalla de conexión SSH | `Ctrl+Shift+C` |
| 📊 | Dashboard | Dashboard del tenant | `Ctrl+1` |
| 🧪 | Labs | Labs (Token, Blockchain, Firma, Plantillas) | `Ctrl+2` |
| 📜 | Historial | Historial de bloques ejecutados | `Ctrl+3` |
| 📦 | Colecciones | Colecciones guardadas + entornos | `Ctrl+4` |
| 🏢 | Mis Empresas | Empresas cliente, sucursales, usuarios | `Ctrl+5` |
| 👤 | Mi Cuenta | Perfil del tenant, plan, límites | `Ctrl+6` |
| 🎓 | Soporte | Documentación, onboarding, contacto SBOS | `Ctrl+7` |
| ⚙ | Configuración | Preferencias, tema, atajos | `Ctrl+,` |

**Badges en items:**
- 🏢 Mis Empresas: número de empresas activas
- 📜 Historial: bloques sin guardar en sesión actual
- 🎓 Soporte: notificación pendiente (🟡)

### Right Sidebar — Catálogo de Métodos

```
┌────────────────────────────┐
│ 🔍 [Buscar método...___]   │
│ ────────────────────────── │
│                            │
│ 📁 Autenticación           │
│   ├── bauth.token.issue   │ ← click → pre-llena editor
│   ├── bauth.token.validate│
│   └── bauth.token.jwks    │
│                            │
│ 📁 Acceso                  │
│   ├── bauth.access.evaluate│
│   └── bauth.context.evaluate│
│                            │
│ 📁 Dominios (12)           │
│   ├── bauth.domain.logical │
│   ├── bauth.domain.physical│
│   └── ...                  │
│                            │
│ 📁 Roles y Usuarios        │
│   ├── bauth.role.template.*│
│   ├── bauth.user.*         │
│   └── ...                  │
│                            │
│ 📁 Sync · Firma · Block    │
│   └── ...                  │
│                            │
│ ────────────────────────── │
│ 📋 COMANDOS RECIENTES      │
│ ────────────────────────── │
│ ▸ token.issue +Mask        │
│ ▸ access.evaluate cajero   │
│ ▸ health.check             │
│                            │
│ ────────────────────────── │
│ 💡 TIP: Ctrl+B = mostrar   │
│    / ocultar catálogo      │
└────────────────────────────┘
```

**Comportamiento del Right Sidebar:**
- **Colapsado por defecto** en pantallas que no son editor (Dashboard, Empresas, Cuenta)
- **Expandido automáticamente** al entrar al Editor o Cinta de Bloques
- **Click en método** → carga el método en el editor central + pre-llena params
- **Doble click en método** → ejecuta directamente (atajo rápido)
- **Ctrl+B** → toggle mostrar/ocultar
- **Ctrl+K** → foco en búsqueda del catálogo
- **Comandos recientes**: últimos 10 métodos ejecutados, click para re-usar

### Transiciones entre pantallas

```
Click en Left Sidebar → Center Body cambia al contenido de la pantalla seleccionada
                       → Right Sidebar se adapta:
                          • Editor/Cinta: catálogo expandido
                          • Dashboard/Empresas/Cuenta/Soporte: catálogo colapsado
```

### Comparación: Antes vs Ahora

| Aspecto | Antes (Top Menu) | Ahora (Left Sidebar) |
|---------|:---:|:---:|
| Navegación | Tabs horizontales limitados (~7 visibles) | Sidebar vertical con 10+ items visibles |
| Espacio vertical | Roba 44px de altura | Usa espacio lateral (más abundante en desktop) |
| Escalabilidad | Sin espacio para más tabs | Scroll vertical si hay más items |
| Iconos | Solo texto | Icono + label (visible en hover) |
| Estado | Tab activo subrayado | Item activo con highlight + borde izquierdo |
| Catálogo | Panel izquierdo (roba espacio fijo) | Panel derecho colapsable (libera espacio) |
| Adaptación | Forzado en todas las pantallas | Catálogo se oculta en pantallas no-editor |

---

## 2. CATÁLOGO DE COMPONENTES

### 2.1 Botones (Button System)

```html
<!-- @dsCard group="Componentes Base" -->
<!--
  VARIANTES:
  - primary:    Fondo --color-accent-primary, texto blanco
  - secondary:  Borde --color-border-default, fondo transparente
  - ghost:      Sin borde, solo texto, hover muestra fondo
  - danger:     Fondo --color-error, texto blanco
  - icon:       Solo icono, 32×32px, circular

  TAMAÑOS:
  - sm: 28px altura, --text-xs
  - md: 36px altura, --text-sm (default)
  - lg: 44px altura, --text-base

  ESTADOS: default, hover, focus, active, disabled, loading
  ESTADO LOADING: spinner + texto "Enviando..."
-->
```

### 2.2 Entradas (Input System)

```html
<!-- @dsCard group="Componentes Base" -->
<!--
  TIPOS:
  - text:      Campo de texto estándar
  - search:    Con icono de lupa a la izquierda
  - select:    Dropdown nativo estilizado
  - textarea:  Área multilínea (editor JSON)
  - number:    Solo números, con steppers opcionales

  ESTADOS: default, hover, focus, filled, error, disabled
  CON AYUDA:  Label arriba, placeholder adentro, texto de ayuda abajo
  CON ERROR:  Borde rojo + mensaje de error abajo + icono ⚠
-->
```

### 2.3 Árbol Jerárquico (TreeView)

```html
<!-- @dsCard group="Navegación" -->
<!--
  USO: Catálogo de métodos (panel izquierdo)
  ESTRUCTURA:
  ├── 📁 Categoría (expandible/colapsable)
  │   ├── 📄 Método 1
  │   ├── 📄 Método 2
  │   └── 📁 Subcategoría
  │       └── 📄 Método 3

  COMPORTAMIENTO:
  - Click en categoría → expandir/colapsar (▼/▶)
  - Click en método → seleccionar (highlight) + cargar en editor
  - Doble click en método → ejecutar directamente
  - Teclas: ↑↓ navegar, → expandir, ← colapsar, Enter seleccionar
  - Búsqueda: Ctrl+K abre búsqueda rápida, filtra en tiempo real

  ESTADOS POR NODO:
  - default:    Texto --color-text-secondary, sin fondo
  - hover:      Fondo --color-bg-hover
  - selected:   Fondo --color-accent-subtle, texto --color-accent-primary
  - matched:    (búsqueda) texto --color-warning, highlight amarillo
-->
```

### 2.4 Bloque de Cinta (Calculator Tape Block)

```html
<!-- @dsCard group="Cinta de Ejecución" -->
<!--
  INSPIRACIÓN: Warp Terminal Blocks + calculadoras con impresora
  ESTRUCTURA:
  ┌── BLOQUE #N — 14:32:05 ─────────────────────────────┐
  │  ▸ COMANDO (JSON colapsable)                          │
  │  ─── RESULTADO ────────────────────────────────────── │
  │  { JSON respuesta formateado y colapsable }           │
  │  ⏱ 3.2ms │ 📏 1,112 chars │ 🔐 Ed25519 │ 🟢 OK      │
  │  [▶ RE-EJECUTAR] [✏ EDITAR] [📋 COPIAR] [⭐ GUARDAR]│
  └──────────────────────────────────────────────────────┘

  ESTADOS:
  - executing:  Borde pulsante --color-accent-primary, spinner
  - success:    Borde izquierdo --color-success, badge 🟢
  - error:      Borde izquierdo --color-error, badge 🔴
  - collapsed:  Solo muestra método + timestamp + estado (1 línea)
  - expanded:   Muestra todo (default)

  METADATOS VISIBLES:
  - Timestamp (HH:MM:SS)
  - Latencia (ms/ns)
  - Tamaño de respuesta
  - Algoritmo de firma (si aplica)
  - Veredicto (PERMITIDO/DENEGADO) con color semántico
  - Tipo de token (LIVIANO, +MASK, +BLOCKCHAIN, RS256)

  ACCIONES POR BLOQUE:
  - [▶] Re-ejecutar: mismo comando, nuevo bloque abajo
  - [✏] Editar: abre editor flotante con el comando del bloque
  - [📋] Copiar comando: JSON al portapapeles
  - [📋📋] Copiar resultado: JSON respuesta al portapapeles
  - [⭐] Guardar favorito: destacar bloque, carpeta "Favoritos"
  - [📤] Exportar .sh: genera comando bash equivalente
  - [✕] Ocultar: mueve a papelera (recuperable)
-->
```

### 2.5 Editor JSON con Resaltado

```html
<!-- @dsCard group="Editor de Código" -->
<!--
  CARACTERÍSTICAS:
  - Resaltado de sintaxis JSON en tiempo real
  - Números de línea (columna izquierda, color --color-text-tertiary)
  - Bracket matching (resalta paréntesis/llaves emparejados)
  - Autocompletado de métodos bAuth (escribe "bauth." → lista de métodos)
  - Validación en vivo (JSON mal formado → subrayado rojo)
  - Formateo con Ctrl+Shift+F
  - Plegado de código (colapsar objetos JSON anidados)

  ESQUEMA DE COLORES:
  - Fondo:         --color-code-bg (#0A0E14)
  - Strings:       --color-code-string (#A5D6FF)
  - Números:       --color-code-number (#FFC48C)
  - Booleanos:     --color-code-boolean (#FF8CBF)
  - Null:          --color-code-null (#FF6B6B)
  - Claves JSON:   --color-code-key (#8BB8F2)
  - Métodos bAuth: --color-code-method (#C4A5FF)
  - Error sintaxis: fondo rojo sutil + subrayado ondulado

  MODOS:
  - edit:    Editor completo (request)
  - read:    Solo lectura (respuesta), mismo resaltado
  - diff:    Dos editores lado a lado, diferencias resaltadas
-->
```

### 2.6 Consola Segura de Comandos

```html
<!-- @dsCard group="Consola" -->
<!--
  INSPIRACIÓN: Visual FoxPro 9 Command Window + terminal segura
  COMPORTAMIENTO:
  - Input de una sola línea para comandos JSON-RPC
  - Autocompletado de métodos (TAB)
  - Historial de comandos (↑↓)
  - Ayuda contextual (escribe "help" o presiona "?")
  - Solo se permiten métodos del catálogo bAuth
  - Comandos rechazados muestran mensaje de error amigable
  - La conexión SSH es transparente (el usuario no la ve)

  MENSAJES DEL SISTEMA:
  - Conexión exitosa:  "🟢 Conectado a bAuth v3.0.0 | uptime: 12d 4h"
  - Comando rechazado: "⛔ Solo se permiten métodos JSON-RPC del catálogo bAuth"
  - Sin conexión:      "🔴 Sin conexión al daemon bAuth"
  - Ejecutando:        "⏳ Ejecutando bauth.token.issue..."
-->
```

### 2.7 Laboratorio (Lab Panel)

```html
<!-- @dsCard group="Laboratorios" -->
<!--
  ESTRUCTURA COMÚN A LOS 4 LABS:
  ┌─── 🧪 NOMBRE DEL LAB ─────────────────────────────────┐
  │  [Selector de variante/usuario/parámetro]              │
  │  [Área de parámetros y opciones]                       │
  │  [Botón de ejecución principal]                        │
  │  ─── RESULTADO ─────────────────────────────────────── │
  │  [Visualización del resultado]                         │
  │  [Métricas y métadatos]                                │
  │  [Snippet de código generado]                          │
  │  [Acciones: copiar, exportar, probar otro]             │
  └────────────────────────────────────────────────────────┘

  ESTADOS:
  - empty:    Mensaje "Selecciona los parámetros y haz clic en EJECUTAR"
  - loading:  Spinner + "Ejecutando..."
  - result:   Resultado formateado con colores semánticos
  - error:    Mensaje de error con detalles y sugerencias
-->
```

### 2.8 Badges y Etiquetas de Estado

```html
<!-- @dsCard group="Indicadores" -->
<!--
  TIPOS:
  - Estado de conexión: 🟢 Conectado | 🟡 Reconectando | 🔴 Desconectado
  - Veredicto:          ✅ PERMITIDO | ❌ DENEGADO | ⚠ DEGRADADO
  - Variante token:     LIVIANO | +MASK | +BLOCKCHAIN | RS256
  - Dominio:            D1 Lógico | D2 Físico | ... | D12 Blockchain
  - Plan:               TRIAL | BASIC | PRO | ENTERPRISE
  - LoA:                AAL1 | AAL2 | AAL3
-->
```

### 2.9 Pestañas de Navegación

```html
<!-- @dsCard group="Navegación" -->
<!--
  ESTRUCTURA:
  ┌──────────────────────────────────────────────────────────┐
  │ [🟢 Conexión] [📋 Catálogo] [🧪 Labs] [📜 Historial]  │
  │ [📦 Colecciones] [⚙ Config] [👤 Empresas]              │
  └──────────────────────────────────────────────────────────┘

  COMPORTAMIENTO:
  - Tab activa: borde inferior --color-accent-primary, texto blanco
  - Tab inactiva: texto --color-text-tertiary
  - Tab hover: texto --color-text-secondary
  - Navegación: Ctrl+1..9 para cambiar entre tabs
  - Badge en tab: número de items pendientes (ej: Historial [3])
-->
```

### 2.10 Formulario de Registro (Developer Signup)

```html
<!-- @dsCard group="Negocio" -->
<!--
  ESTRUCTURA:
  ┌── 🚀 CREAR TU CUENTA GRATUITA ────────────────────────────┐
  │                                                            │
  │  Paso 1 de 3: Datos del desarrollador                      │
  │  ┌──────────────────────────────────────────────────────┐  │
  │  │  Nombre completo: [____________________________]      │  │
  │  │  Email:           [____________________________]      │  │
  │  │  Teléfono:        [____] [_______________] (opcional) │  │
  │  │  País:            [Bolivia ▼]                         │  │
  │  │  Ciudad:          [La Paz ▼]                          │  │
  │  │  Cómo nos encontraste: [GitHub ▼]                     │  │
  │  └──────────────────────────────────────────────────────┘  │
  │                                                            │
  │  Paso 2 de 3: Tu empresa/emprendimiento                    │
  │  ┌──────────────────────────────────────────────────────┐  │
  │  │  Nombre de tu empresa: [________________________]     │  │
  │  │  Rol: [Desarrollador independiente ▼]                 │  │
  │  │  Stack principal: [Go ▼] [+ Agregar]                  │  │
  │  │  ¿Ya tienes clientes?: ○ Sí, tengo ○ Todavía no       │  │
  │  │  ¿Cuántos?: [1-10 ▼]                                  │  │
  │  └──────────────────────────────────────────────────────┘  │
  │                                                            │
  │  Paso 3 de 3: ¿Qué te interesa?                            │
  │  ┌──────────────────────────────────────────────────────┐  │
  │  │  ☑ Autenticación para mis apps                        │  │
  │  │  ☑ Firma digital para facturación SIN                 │  │
  │  │  ☑ Control de acceso por roles                        │  │
  │  │  ☐ Blockchain y auditoría                             │  │
  │  │  ☐ Solo estoy explorando                              │  │
  │  └──────────────────────────────────────────────────────┘  │
  │                                                            │
  │  ☑ Acepto los términos de uso y la política de privacidad  │
  │                                                            │
  │  [🚀 CREAR CUENTA GRATUITA]                                │
  │  ⓘ Sin tarjeta de crédito. Plan TRIAL con 3 roles,        │
  │    50 usuarios, 3 dominios. Sin límite de tiempo.          │
  └────────────────────────────────────────────────────────────┘

  ESTADOS:
  - filling:   Formulario activo con validación en vivo
  - validating: "Verificando email..." spinner
  - success:   "✅ Cuenta creada. Redirigiendo a tu dashboard..."
  - error:     Mensaje de error específico (email duplicado, etc.)
  - email-sent: "📧 Te enviamos un email de verificación. Revisa tu bandeja."
-->
```

### 2.11 Formulario de Login (Developer Auth)

```html
<!-- @dsCard group="Negocio" -->
<!--
  ESTRUCTURA:
  ┌── 🔐 INICIAR SESIÓN — bAuthDEV ──────────────────────────┐
  │                                                           │
  │  ┌─────────────────────────────────────────────────────┐  │
  │  │              🛡️ bAuthDEV                              │  │
  │  │        Plataforma de Desarrollo bAuth                │  │
  │  └─────────────────────────────────────────────────────┘  │
  │                                                           │
  │  Email:    [____________________________________]         │
  │  Password: [____________________________________]  👁     │
  │                                                           │
  │  [🔐 INICIAR SESIÓN]                                      │
  │                                                           │
  │  ─────── o ───────                                        │
  │                                                           │
  │  [G] Continuar con Google    [Github] Continuar con GitHub │
  │                                                           │
  │  ¿No tienes cuenta? [🚀 Crear cuenta gratuita]            │
  │  ¿Olvidaste tu contraseña? [Recuperar]                    │
  └──────────────────────────────────────────────────────────┘

  ESTADOS:
  - default:    Formulario vacío
  - filling:    Campos con datos
  - submitting: "Verificando credenciales..." spinner
  - success:    Redirección al dashboard del tenant
  - error:      "Email o contraseña incorrectos. ¿Olvidaste tu contraseña?"
  - mfa:        "Ingresa el código de verificación de tu app authenticator"
  - locked:     "Cuenta bloqueada por múltiples intentos. Espera 15 minutos."
-->
```

### 2.12 Tarjeta de Empresa Cliente (CompanyCard)

```html
<!-- @dsCard group="Negocio" -->
<!--
  ESTRUCTURA:
  ┌── 🏢 COMERCIALIZADORA DEL VALLE S.A. ──────────────────┐
  │                                                        │
  │  NIT: 123456789012  │  Plan heredado: PRO              │
  │  📍 3 sucursales    │  👤 47 usuarios                  │
  │  🟢 Activa          │  📅 Desde: 15 Mar 2026           │
  │                                                        │
  │  ┌── USO (30 días) ─────────────────────────────────┐  │
  │  │  ████████████████████░░░░  87% del límite PRO    │  │
  │  │  Evaluaciones: 45,678  │  Sesiones: 234          │  │
  │  │  Nuevos usuarios: 5    │  Token emitidos: 1,234  │  │
  │  └──────────────────────────────────────────────────┘  │
  │                                                        │
  │  [👤 VER USUARIOS] [🌐 SUCURSALES] [📊 DETALLE] [✏]  │
  └────────────────────────────────────────────────────────┘

  ESTADOS:
  - active:    borde izquierdo --color-success
  - suspended: borde izquierdo --color-warning, badge 🟡
  - trial:     badge 🆓 TRIAL
  - empty:     "Aún no tienes empresas cliente. [+ AGREGAR PRIMERA EMPRESA]"
-->
```

### 2.13 Panel de Tracking de Uso (UsagePanel)

```html
<!-- @dsCard group="Negocio" -->
<!--
  ESTRUCTURA (por empresa o sucursal):
  ┌── 📊 USO DE bAuth — COMERCIALIZADORA DEL VALLE ─────────┐
  │                                                          │
  │  Período: [Últimos 30 días ▼]  [📤 EXPORTAR REPORTE]    │
  │                                                          │
  │  ┌── MÉTRICAS ───────────────────────────────────────┐  │
  │  │  📊 45,678     🔑 1,234      👤 234       ⚡ 99.7% │  │
  │  │  Evaluaciones   Tokens        Sesiones     FastPath│  │
  │  └─────────────────────────────────────────────────────┘  │
  │                                                          │
  │  ┌── EVALUACIONES POR DÍA (gráfico barras SVG) ──────┐  │
  │  │  ██████████████████████░░░░░  Lun-Vie pico 14-16  │  │
  │  └─────────────────────────────────────────────────────┘  │
  │                                                          │
  │  ┌── TOP USUARIOS ───────────────────────────────────┐  │
  │  │  # │ Usuario        │ Evaluaciones │ Última sesión │  │
  │  │  1 │ juan.perez     │ 12,345       │ Hoy 11:27    │  │
  │  │  2 │ maria.lopez    │ 8,765        │ Hoy 10:15    │  │
  │  └─────────────────────────────────────────────────────┘  │
  │                                                          │
  │  ┌── DOMINIOS MÁS EVALUADOS ─────────────────────────┐  │
  │  │  D1 Lógico: 89% │ D3 Financiero: 7% │ D4 Temp: 4% │  │
  │  └─────────────────────────────────────────────────────┘  │
  └──────────────────────────────────────────────────────────┘
-->
```

### 2.14 Indicador de Plan y Límites (PlanBadge)

```html
<!-- @dsCard group="Negocio" -->
<!--
  VARIANTES:
  ┌── 🆓 PLAN TRIAL ──────────────────────────────────────┐
  │  Sin costo. Sin fecha de expiración.                   │
  │  ┌──────────┬──────────┬──────────┬──────────┐        │
  │  │████░░░░░░│██████░░░░│██████░░░░│██████████│        │
  │  └──────────┴──────────┴──────────┴──────────┘        │
  │  Roles 2/3    Users 23/50  Empresas 1/1   Dominios 3/3│
  │  [🔄 CAMBIAR A PRO]                                    │
  └────────────────────────────────────────────────────────┘

  ┌── 💎 PLAN PRO ────────────────────────────────────────┐
  │  $199/mes · Facturación: 28 de cada mes               │
  │  ┌──────────┬──────────┬──────────┬──────────┐        │
  │  │████████░░│██████░░░░│████░░░░░░│████████░░│        │
  │  └──────────┴──────────┴──────────┴──────────┘        │
  │  Roles 18/25  Users 847/1K  Empresas 8/10 Dom 8/8    │
  │  [📊 VER DETALLE] [🔄 CAMBIAR PLAN]                    │
  └────────────────────────────────────────────────────────┘

  UMBRALES DE ALERTA:
  - >80%: barra amarilla 🟡 "Próximo al límite"
  - >95%: barra roja 🔴 "Considera ampliar tu plan"
  - 100%: botón deshabilitado 🔒 "Límite alcanzado — mejora tu plan"
-->
```

---

## 3. ESTRUCTURA DE PANTALLAS

### 3.1 Pantalla 01 — Conexión (Connection Screen)

```
┌──────────────────────────────────────────────────────────────────┐
│  🛡️ bAuthDEV — Plataforma de Desarrollo bAuth                    │
│  ─────────────────────────────────────────────────────────────── │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                                                              │ │
│  │              🔐 Conectar al Daemon bAuth                     │ │
│  │                                                              │ │
│  │  ┌── MÉTODO DE CONEXIÓN ─────────────────────────────────┐  │ │
│  │  │                                                        │  │ │
│  │  │  ○ WebSocket Directo  ● SSH Tunnel (recomendado)      │  │ │
│  │  │                                                        │  │ │
│  │  │  Host:    [13.140.128.230                    ]         │  │ │
│  │  │  Puerto:  [9450                              ]         │  │ │
│  │  │  Usuario: [bauthdev                          ]         │  │ │
│  │  │  🔑 Clave SSH: [──── CARGAR ARCHIVO ────────]         │  │ │
│  │  │                                                        │  │ │
│  │  │  [🧪 PROBAR CONEXIÓN]  →  🟢 bAuth v3.0.0 operativo  │  │ │
│  │  │                                                        │  │ │
│  │  │  [💾 GUARDAR CONEXIÓN]  [📋 CARGAR PERFIL]            │  │ │
│  │  └────────────────────────────────────────────────────────┘  │ │
│  │                                                              │ │
│  │  ┌── CONEXIONES RECIENTES ───────────────────────────────┐  │ │
│  │  │                                                        │  │ │
│  │  │  🟢 vmi3346550 (13.140.128.230:9450) — hace 2h       │  │ │
│  │  │  🟢 staging.sbos.bo:9450 — ayer                       │  │ │
│  │  │  🔴 localhost:9450 — sin conexión                     │  │ │
│  │  │                                                        │  │ │
│  │  └────────────────────────────────────────────────────────┘  │ │
│  │                                                              │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ⓘ Tu conexión es cifrada y limitada a comandos JSON-RPC.       │
│    No tienes acceso al sistema operativo del servidor.           │
└──────────────────────────────────────────────────────────────────┘
```

**Estados:**
- `disconnected` — Sin conexión, formulario vacío
- `connecting` — "Probando conexión..." con spinner
- `connected` — 🟢 "bAuth v3.0.0 operativo | uptime: 12d 4h"
- `error` — 🔴 "No se pudo conectar: Connection refused" con sugerencias
- `ssh-loading` — Cargando clave SSH privada

---

### 3.2 Pantalla 02 — Dashboard Principal (con Left Sidebar + Center Body)

```
┌──────────┬──────────────────────────────────────────────────────────────────────┐
│          │                                                                      │
│  🛡️      │  📊 DASHBOARD — test_cajero [8 átomos] · 🟢 Conectado v3.0.0       │
│  ─────── │  ────────────────────────────────────────────────────────────────── │
│          │                                                                      │
│  📊  ●   │  ┌── MÉTRICAS DE TU TENANT ──────────────────────────────────────┐  │
│          │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────┐ │  │
│  🧪      │  │  │👤     847│ │🔑      18│ │📊  234.5K│ │⚡   0.3ns│ │🟢 12d│ │  │
│          │  │  │Usuarios  │ │Roles     │ │Eval. /mes│ │FastPath  │ │Uptime│ │  │
│  📜      │  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────┘ │  │
│          │  └────────────────────────────────────────────────────────────────┘  │
│  📦      │                                                                      │
│          │  ┌── ACCESO RÁPIDO ───────────────────────────────────────────────┐  │
│  🏢      │  │ [🧪 GetContext] [🔐 Token Lab] [⛓ Blockchain] [✍️ Firma] [🎨 Roles]│  │
│          │  └────────────────────────────────────────────────────────────────┘  │
│  👤      │                                                                      │
│          │  ┌── ACTIVIDAD RECIENTE ──────────────────────────────────────────┐  │
│  🎓      │  │ 14:32 token.issue   test_cajero     🟢 1.1 KB Ed25519         │  │
│          │  │ 14:31 access.eval   tryton.g1.d1    ✅ PERMITIDO 0.3ns        │  │
│  ─────── │  │ 14:29 ctx.evaluate  ctx-019f06db    ✅ 12 dominios OK         │  │
│          │  │ 14:28 token.validate eyJhbGciOi...  🟢 Válido                 │  │
│  ⚙       │  │ 14:25 role.list     BIZ_N1          📋 45 roles               │  │
│          │  │ [📜 VER TODO EL HISTORIAL]                                     │  │
│  ─────── │  └────────────────────────────────────────────────────────────────┘  │
│          │                                                                      │
│  🟢      │  ┌── EMPRESAS ACTIVAS ───────────────────────────────────────────┐  │
│  v3.0.0  │  │ 🏢 Comercializadora Valle  👤47  📍3  📊45.6K eval/mes       │  │
│  12d 4h  │  │ 🏢 Distribuidora Andina    👤12  📍1  📊8.2K eval/mes        │  │
│          │  │ [🏢 VER TODAS LAS EMPRESAS]                                    │  │
│          │  └────────────────────────────────────────────────────────────────┘  │
│          │                                                                      │
└──────────┴──────────────────────────────────────────────────────────────────────┘
  LEFT         CENTER BODY (dashboard — right sidebar colapsado)
  SIDEBAR
  (expandido)
```

**Nota:** En Dashboard, el right sidebar está colapsado. El left sidebar está expandido
mostrando la navegación completa con Dashboard activo (●).

---

### 3.3 Pantalla 03 — Editor + Catálogo (Layout 3 Columnas)

```
┌──────────┬──────────────────────────────────┬────────────────────────────┐
│          │                                  │                            │
│  🛡️      │  EDITOR + RESPUESTA              │  CATÁLOGO DE MÉTODOS       │
│  ─────── │  ─────────────────────────────── │  ───────────────────────── │
│          │                                  │                            │
│  📊      │  ┌── JSON-RPC REQUEST ────────┐  │  🔍 [buscar método...]    │
│          │  │ {                           │  │  ─────────────────────    │
│  🧪      │  │   "jsonrpc": "2.0",        │  │                            │
│          │  │   "method": "bauth.        │  │  📁 Autenticación          │
│  📜      │  │     access.evaluate",      │  │  ├── token.issue    [*]   │
│          │  │   "params": {              │  │  ├── token.validate       │
│  📦      │  │     "atom_slug":           │  │  └── token.jwks           │
│          │  │       "tryton.g1.d1.nuevo",│  │                            │
│  🏢      │  │     "user_uuid":           │  │  📁 Acceso                 │
│          │  │       "019f06db-..."       │  │  ├── access.evaluate [*]  │
│  👤      │  │   },                       │  │  └── context.evaluate     │
│          │  │   "id": 1                  │  │                            │
│  🎓      │  │ }                          │  │  📁 Dominios              │
│          │  └────────────────────────────┘  │  ├── domain.logical       │
│  ─────── │                                  │  ├── domain.physical      │
│          │  [▶ ENVIAR] [📦 LOTE] [🔤 FORM]  │  ├── domain.financial     │
│  ⚙       │                                  │  └── ... (12 dominios)    │
│          │  ┌── RESPUESTA ───────────────┐  │                            │
│  ─────── │  │ {                           │  │  📁 Roles y Usuarios      │
│          │  │   "jsonrpc": "2.0",        │  │  ├── role.template.list   │
│  🟢      │  │   "result": {              │  │  ├── user.list            │
│  v3.0.0  │  │     "verdict": "allow",    │  │  └── ...                  │
│  12d 4h  │  │     "fastpath": true,      │  │                            │
│          │  │     "latency_ns": 0.3      │  │  ─────────────────────    │
│          │  │   },                        │  │  📋 RECIENTES              │
│          │  │   "id": 1                  │  │  ▸ token.issue +Mask       │
│          │  │ }                           │  │  ▸ access.evaluate        │
│          │  └────────────────────────────┘  │  ▸ health.check            │
│          │                                  │                            │
│          │  ┌── SNIPPET ─────────────────┐  │  💡 Ctrl+B = toggle        │
│          │  │ // Go                       │  │     Ctrl+K = buscar        │
│          │  │ params := map[string]...    │  │                            │
│          │  │ result, _ := rpc.Call(     │  │                            │
│          │  │   "bauth.access.evaluate",  │  │                            │
│          │  │   params)                   │  │                            │
│          │  │ [📋 Copiar] [🔄 Go ▼]      │  │                            │
│          │  └────────────────────────────┘  │                            │
│          │                                  │                            │
├──────────┴──────────────────────────────────┴────────────────────────────┤
│  🧭 CONSOLA: ▸ [bauth.health.check________________________] [▶]         │
└──────────────────────────────────────────────────────────────────────────┘
  LEFT         CENTER BODY                         RIGHT SIDEBAR
  SIDEBAR      (editor arriba, respuesta abajo)    (catálogo expandido)
  (colapsado)                                      300px
  56px
```

**Comportamiento de los splitters:**
- Los 3 paneles superiores son redimensionables arrastrando los bordes
- Doble click en un borde → restaura el tamaño por defecto
- La consola inferior es colapsable (click en borde superior)
- Layout responsive: < 1200px → paneles en tabs verticales

---

### 3.4 Pantalla 04 — Cinta de Bloques (Calculator Tape View)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🛠️ bAuthDEV  │  🟢 Conectado  │  👤 test_cajero [8 átomos]  │  📜 Cinta  │
├──────────┬────────────────────────────────────────────────────────────────────┤
│          │                                                                    │
│ CATALOGO │  ┌─ 🧮 CINTA DE EJECUCIÓN ─────────────────────────────────────┐  │
│ METODOS  │  │                                                                │ │
│          │  │  ┌── BLOQUE #1 — 14:32:05 ─────────────────────────────────┐  │ │
│ 🔍 buscar│  │  │                                                           │  │ │
│ ──────── │  │  │  ▸ COMANDO:  bauth.token.issue                           │  │ │
│          │  │  │  {                                                        │  │ │
│ TOKENS   │  │  │    "user_uuid": "019f06db-...",                           │  │ │
│  ├─ issue│  │  │    "include_mask": true                                   │  │ │
│  │  [*]  │  │  │  }                                                        │  │ │
│  ├─ vali│  │  │                                                           │  │ │
│  │      │  │  │  ─── RESULTADO ────────────────────────────────────────── │  │ │
│  ├─ jwks│  │  │  {                                                          │  │ │
│          │  │  │    "algorithm": "EdDSA",                                    │  │ │
│ ACCESO   │  │  │    "jwt_size_chars": 1112,                                  │  │ │
│  ├─ acce│  │  │    "rolbitmask": { "active_count": 8 }                      │  │ │
│  │  [*] │  │  │  }                                                          │  │ │
│  │      │  │  │  ⏱ 3.2ms │ 📏 1,112 chars │ 🔐 Ed25519 │ 🟢 OK            │  │ │
│  ├─ cont│  │  │                                                           │  │ │
│  │      │  │  │  [▶ RE-EJECUTAR] [✏ EDITAR] [📋 COPIAR] [⭐ GUARDAR]    │  │ │
│ DOMINIOS │  │  └──────────────────────────────────────────────────────────┘  │ │
│  ├─ logi│  │                                                                │ │
│  │  ... │  │  ┌── BLOQUE #2 — 14:32:28 ─────────────────────────────────┐  │ │
│          │  │  │                                                           │  │ │
│ ROLES    │  │  │  ▸ COMANDO:  bauth.access.evaluate                        │  │ │
│  ├─ temp│  │  │  {                                                        │  │ │
│  │  ... │  │  │    "atom_slug": "tryton.g1.d1.nuevo",                     │  │ │
│          │  │  │    "user_uuid": "019f06db-..."                            │  │ │
│ SINCRON.│  │  │  }                                                        │  │ │
│  ├─ reco│  │  │                                                           │  │ │
│  │  ... │  │  │  ─── RESULTADO ────────────────────────────────────────── │  │ │
│          │  │  │  {                                                          │  │ │
│ FIRMA    │  │  │    "verdict": "allow",                                      │  │ │
│  ├─ inte│  │  │    "fastpath": true,                                        │  │ │
│  │  ... │  │  │    "latency_ns": 0.3                                        │  │ │
│          │  │  │  }                                                          │  │ │
│          │  │  │  ⏱ 0.3ns │ 🧬 FastPath │ 🟢 PERMITIDO                     │  │ │
│          │  │  │                                                           │  │ │
│          │  │  │  [▶ RE-EJECUTAR] [✏ EDITAR] [📋 COPIAR] [⭐ GUARDAR]    │  │ │
│          │  │  └──────────────────────────────────────────────────────────┘  │ │
│          │  │                                                                │ │
│          │  │  ─── BLOQUES ANTERIORES (colapsados) ──────────────────────── │ │
│          │  │  Sesión 26 Jun · 23 bloques · 3⭐ · 2🔴  ─── [▼ EXPANDIR]    │ │
│          │  │  Sesión 25 Jun · 45 bloques · 5⭐ · 0🔴  ─── [▼ EXPANDIR]    │ │
│          │  │                                                                │ │
│          │  │  [🧹 LIMPIAR CINTA] [📤 EXPORTAR .SH] [🔍 BUSCAR EN CINTA]  │ │
│          │  └────────────────────────────────────────────────────────────────┘ │
│          │                                                                    │
├──────────┴────────────────────────────────────────────────────────────────────┤
│  ┌─ 🧭 CONSOLA SEGURA ─────────────────────────────────────────────────────┐ │
│  │  ▸ [_                                                           ] [▶]   │ │
│  └──────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.5 Pantalla 05 — Token Lab (4 variantes)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🛠️ bAuthDEV  │  🟢 Conectado  │  👤 test_cajero  │  🧪 Token Lab          │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌── SELECCIÓN DE VARIANTE ──────────────────────────────────────────────┐  │
│  │                                                                         │  │
│  │  [1️⃣ LIVIANO]  [2️⃣ +MASK]  [3️⃣ +BLOCKCHAIN]  [4️⃣ RS256 LEGACY]       │  │
│  │    Activo                                                               │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌── VARIANTE 1: TOKEN LIVIANO (Identidad pura, ~1.1 KB) ─────────────────┐ │
│  │                                                                         │ │
│  │  Usuario: [test_cajero ▼]  (019f06db-62a9-73ab-a85a-f5d12f20233d)     │ │
│  │                                                                         │ │
│  │  Parámetros:                                                            │ │
│  │  ☐ include_mask (cookie offline)    ☐ anchor (blockchain)              │ │
│  │  Algorithm: Ed25519 (default)                                           │ │
│  │                                                                         │ │
│  │  [🔑 EMITIR TOKEN]                                                      │ │
│  │                                                                         │ │
│  │  ─── TOKEN EMITIDO ──────────────────────────────────────────────────  │ │
│  │                                                                         │ │
│  │  ┌── HEADER ──┐  ┌── PAYLOAD ─────────────────────────────────────┐   │ │
│  │  │ {"alg":     │  │ "sub": "019f06db-62a9-73ab-a85a-f5d12f20233d" │   │ │
│  │  │  "EdDSA",   │  │ "iss": "bauth.sbos.bo"                        │   │ │
│  │  │  "typ":     │  │ "ctx_id": "ctx-019f06db-..."                  │   │ │
│  │  │  "JWT"}     │  │ "tenant_id": "019f06db-..."                   │   │ │
│  │  └─────────────┘  │ "loa": 2, "acr": "sbos_aal2"                  │   │ │
│  │                   │ "iat": 1719442200, "exp": 1719471000          │   │ │
│  │                   │ "jti": "01abc-def456-ghi789"                  │   │ │
│  │                   └───────────────────────────────────────────────┘   │ │
│  │                                                                         │ │
│  │  📏 Tamaño: 1,112 chars │ 🔐 Algoritmo: EdDSA │ ⚡ Firma: ~50 µs     │ │
│  │                                                                         │ │
│  │  ┌── JWT COMPLETO ──────────────────────────────────────────────────┐ │ │
│  │  │ eyJhbGciOiJFZDI1NTE5IiwidHlwIjoiSldUIn0.eyJzdWIiOiIwMTlm...     │ │ │
│  │  │ [📋 COPIAR JWT] [🔍 DECODIFICAR] [✅ VALIDAR]                     │ │ │
│  │  └───────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                         │ │
│  │  ┌── SNIPPET — Go ──────────────────────────────────────────────────┐ │ │
│  │  │ params := map[string]interface{}{                                  │ │ │
│  │  │     "user_uuid": userUUID,                                         │ │ │
│  │  │ }                                                                  │ │ │
│  │  │ result, _ := rpc.Call("bauth.token.issue", params)                │ │ │
│  │  │ jwt := result["jwt"].(string)                                      │ │ │
│  │  │ [📋 COPIAR] [🔄 Go ▼]                                             │ │ │
│  │  └───────────────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌── COMPARATIVA RÁPIDA ─────────────────────────────────────────────────┐  │
│  │              │ LIVIANO │ +MASK    │ +BLOCKCHAIN │ RS256               │  │
│  │  Tamaño      │ 1.1 KB  │ 1.1 KB   │ 1.1 KB      │ ~2 KB               │  │
│  │  Offline     │ ❌      │ ✅       │ ❌          │ ❌                  │  │
│  │  Blockchain  │ ❌      │ ❌       │ ✅          │ ❌                  │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.6 Pantalla 06 — Creador de Plantillas (Roles y Usuarios)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🛠️ bAuthDEV  │  🟢 Conectado  │  👤 test_cajero  │  🎨 Plantillas         │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌── PASO 1: Elegir plantilla base ──────────────────────────────────────┐  │
│  │                                                                         │  │
│  │  🔍 Buscar plantilla: [caj___________________________]                 │  │
│  │                                                                         │  │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │  │
│  │  │ ☑ CAJERO (BIZ_N1)                                               │  │  │
│  │  │   D1: Tryton(sale_pos, account_invoice, party)                  │  │  │
│  │  │   D3: FAC_EMITIR($2K), COBRO_RECIBIR($5K), CIERRE_CAJA         │  │  │
│  │  │   D4: Lun-Vie 8-18 │ D9: PASSWORD+TOTP │ 14 políticas          │  │  │
│  │  │   [USAR CAJERO COMO BASE]  [VER DETALLE COMPLETO]               │  │  │
│  │  ├──────────────────────────────────────────────────────────────────┤  │  │
│  │  │ ☐ SUPERVISOR (BIZ_N1)                                           │  │  │
│  │  │   D1: Todas las apps │ D3: Sin límite │ 42 átomos               │  │  │
│  │  │   [USAR SUPERVISOR COMO BASE]  [VER DETALLE COMPLETO]           │  │  │
│  │  ├──────────────────────────────────────────────────────────────────┤  │  │
│  │  │ ☐ GERENTE (BIZ_N1)                                              │  │  │
│  │  │   ...                                                            │  │  │
│  │  └──────────────────────────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌── PASO 2: Personalizar dominios ───────────────────────────────────────┐ │
│  │                                                                         │ │
│  │  ┌─── D1 LÓGICO — Basado en CAJERO ─────────────────────────────────┐ │ │
│  │  │  🏢 Zonas: AREA-CAJA (heredado)                                   │ │ │
│  │  │  📦 Apps:                                                          │ │ │
│  │  │     ☑ Tryton.sale_pos (READ, WRITE, EXEC) ← heredado              │ │ │
│  │  │     ☐ Tryton.account_invoice (READ) ← lo desmarco                 │ │ │
│  │  │     ☑ Tryton.party (READ) ← heredado                              │ │ │
│  │  │     [➕ Agregar app de mi sistema]                                 │ │ │
│  │  └────────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                         │ │
│  │  ┌─── D3 FINANCIERO — Basado en CAJERO ──────────────────────────────┐ │ │
│  │  │  FAC_EMITIR: $2,000/día → [$5,000] ← actualizo límite            │ │ │
│  │  │  COBRO_RECIBIR: $5,000 → sin cambios                              │ │ │
│  │  │  CIERRE_CAJA: ☑ heredado                                          │ │ │
│  │  └────────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                         │ │
│  │  ┌─── D4 TEMPORAL ───────────────────────────────────────────────────┐ │ │
│  │  │  Lun-Vie 8-18 → [Lun-Dom 6-22] ← amplío cobertura                 │ │ │
│  │  └────────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                         │ │
│  │  ┌─── D9 CREDENCIALES ───────────────────────────────────────────────┐ │ │
│  │  │  ☑ PASSWORD (heredado)  ☑ TOTP (heredado)                        │ │ │
│  │  │  ☑ WEBAUTHN_PWDLESS ← agrego, necesito phishing-resistant         │ │ │
│  │  │  Flujo: standard_login → agrego paso 3: WEBAUTHN                  │ │ │
│  │  └────────────────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌── PASO 3: Guardar y crear usuarios de prueba ──────────────────────────┐ │
│  │                                                                         │ │
│  │  Nuevo Rol: CAJERO_MI_APP (basado en CAJERO, BIZ_N1)                   │ │
│  │  Cambios: D1 +mi_pos, D3 $2K→$5K, D4 Lun-Dom 6-22, D9 +WEBAUTHN      │ │
│  │                                                                         │ │
│  │  👤 Usuarios de prueba:                                                 │ │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │ │
│  │  │ juan.perez@mi-app.com        → CAJERO_MI_APP     [🧪 PROBAR]   │   │ │
│  │  │ maria.lopez@mi-app.com       → CAJERO_MI_APP     [🧪 PROBAR]   │   │ │
│  │  │ admin@mi-app.com             → CAJERO_MI_APP     [🧪 PROBAR]   │   │ │
│  │  │                                + SUPERVISOR                     │   │ │
│  │  │ [➕ AGREGAR USUARIO]                                            │   │ │
│  │  └─────────────────────────────────────────────────────────────────┘   │ │
│  │                                                                         │ │
│  │  [🧪 PROBAR AUTENTICACIÓN END-TO-END]  [💾 GUARDAR PLANTILLA]         │ │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌── PASO 4: Código de integración ───────────────────────────────────────┐ │
│  │                                                                         │ │
│  │  // ESTO es todo lo que necesitas en tu app:                            │ │
│  │  params := map[string]interface{}{                                      │ │
│  │      "atom_slug": "mi_pos.consultar",                                   │ │
│  │      "user_uuid": userUUID,                                             │ │
│  │  }                                                                      │ │
│  │  result, _ := rpc.Call("bauth.access.evaluate", params)                │ │
│  │  if result["verdict"] == "allow" { ... }                                │ │
│  │                                                                         │ │
│  │  [📋 COPIAR — Go] [📋 COPIAR — Rust] [📋 COPIAR — Python]             │ │
│  └─────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.7 Pantalla 07 — Blockchain Lab + Merkle Verifier

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🛠️ bAuthDEV  │  🟢 Conectado  │  👤 test_superadmin  │  ⛓ Blockchain Lab │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌── ANCLAJE DE EVENTOS ─────────────────────────────────────────────────┐  │
│  │                                                                         │  │
│  │  Usuario: [test_superadmin ▼]  (019f06db-62a6-77b1-b581-4c37e3aeee9f) │  │
│  │                                                                         │  │
│  │  ┌── PASO 1: Emitir token con anclaje ──────────────────────────────┐  │  │
│  │  │  ☑ anchor: true (anclar en Besu QBFT)                             │  │  │
│  │  │  [🔑 EMITIR TOKEN + ANCLAR]                                       │  │  │
│  │  │  ← token_sha256: 0xe5f6...a7b8                                     │  │  │
│  │  │  ← merkle_leaf_keccak256: 0xa1b2...c3d4                            │  │  │
│  │  │  ← merkle_root: 0x8f3a...b21c                                      │  │  │
│  │  │  ← tx_hash: 0x7d3f... │ Bloque: #1,234,567                         │  │  │
│  │  └────────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                         │  │
│  │  ┌── CADENA DE ANCLAJE (Visual) ────────────────────────────────────┐  │  │
│  │  │                                                                    │  │  │
│  │  │  JWT (1.1 KB)                                                      │  │  │
│  │  │    │                                                               │  │  │
│  │  │    ▼ SHA-256                                                       │  │  │
│  │  │  token_sha256: 0xe5f6...a7b8                                       │  │  │
│  │  │    │                                                               │  │  │
│  │  │    ▼ Keccak-256                                                    │  │  │
│  │  │  merkle_leaf: 0xa1b2...c3d4                                        │  │  │
│  │  │    │                                                               │  │  │
│  │  │    ▼ Merkle Tree (batch 200 eventos)                               │  │  │
│  │  │  merkle_root: 0x8f3a...b21c                                        │  │  │
│  │  │    │                                                               │  │  │
│  │  │    ▼ Transacción Besu QBFT                                          │  │  │
│  │  │  ┌─────────────────────────────────────────────────────────────┐   │  │  │
│  │  │  │ 🔒 tx_hash: 0x7d3f...  │ Bloque: #1,234,567                 │   │  │  │
│  │  │  │ 🔒 Confirmaciones: 15,432 │ Gas: 21,000 │ Precio: 12 Gwei   │   │  │  │
│  │  │  │ 🔒 Red: Besu QBFT (4 validadores, permissioned)             │   │  │  │
│  │  │  └─────────────────────────────────────────────────────────────┘   │  │  │
│  │  └────────────────────────────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌── VERIFICACIÓN MERKLE PROOF ───────────────────────────────────────────┐ │
│  │                                                                         │ │
│  │  Evento ID: [pegar event_id o JWT_______________]                       │ │
│  │  Merkle Proof: [pegar proof JSON___________________]                    │ │
│  │                                                                         │ │
│  │  [🔍 VERIFICAR INTEGRIDAD]                                             │ │
│  │                                                                         │ │
│  │  ┌── PASO 1: SHA-256 del JWT ───────────────────────────────────────┐ │ │
│  │  │  → 0xe5f6...a7b8 ✅ Calculado                                     │ │ │
│  │  └──────────────────────────────────────────────────────────────────┘ │ │
│  │  ┌── PASO 2: Keccak-256 del hash ────────────────────────────────────┐ │ │
│  │  │  → 0xa1b2...c3d4 ✅ Calculado                                     │ │ │
│  │  └──────────────────────────────────────────────────────────────────┘ │ │
│  │  ┌── PASO 3: Reconstruir raíz con Merkle proof ──────────────────────┐ │ │
│  │  │  leaf → hash_hermano_1 → hash_hermano_2 → hash_hermano_3 → root  │ │ │
│  │  │  → 0x8f3a...b21c ✅ Reconstruido                                  │ │ │
│  │  └──────────────────────────────────────────────────────────────────┘ │ │
│  │  ┌── PASO 4: Comparar con blockchain ─────────────────────────────────┐ │ │
│  │  │  0x8f3a...b21c === 0x8f3a...b21c ✅ COINCIDEN                     │ │ │
│  │  │  📍 Bloque #1,234,567 │ ⛓ Red Besu QBFT │ 🔒 15,432 conf.       │ │ │
│  │  └──────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                         │ │
│  │  ┌── VEREDICTO ──────────────────────────────────────────────────────┐ │ │
│  │  │                                                                     │ │ │
│  │  │  ✅ INTEGRIDAD CONFIRMADA                                          │ │ │
│  │  │  El token no fue alterado.                                         │ │ │
│  │  │  El evento existe y está anclado en el bloque #1,234,567.          │ │ │
│  │  │  Esta prueba es verificable SIN acceso al daemon bAuth.            │ │ │
│  │  │                                                                     │ │ │
│  │  └─────────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                         │ │
│  │  [📤 EXPORTAR PRUEBA PARA AUDITORÍA] → archivo JSON                     │ │
│  └─────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.8 Pantalla 08 — Firma Digital Lab

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🛠️ bAuthDEV  │  🟢 Conectado  │  👤 test_contador  │  ✍️ Firma Lab       │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌── MOTOR INTERNO: Ed25519 (Vault PKI) ─────────────────────────────────┐  │
│  │                                                                         │  │
│  │  Documento a firmar:                                                    │  │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │  │
│  │  │ [CARGAR ARCHIVO]  o  [ESCRIBIR TEXTO]                            │  │  │
│  │  │ ┌──────────────────────────────────────────────────────────────┐ │  │  │
│  │  │ │ {"evento": "cierre_caja", "monto": 15420.50,                 │ │  │  │
│  │  │ │  "fecha": "2026-06-28T18:00:00-04",                          │ │  │  │
│  │  │ │  "sucursal": "LP-001"}                                       │ │  │  │
│  │  │ └──────────────────────────────────────────────────────────────┘ │  │  │
│  │  └──────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                         │  │
│  │  Algoritmo: Ed25519 │ CA: Vault PKI Interna │ FIPS 186-5              │  │
│  │                                                                         │  │
│  │  [✍️ FIRMAR]  →  Firma: 0xa1b2c3d4... (64 bytes)                      │  │
│  │                                                                         │  │
│  │  ┌── VERIFICACIÓN ──────────────────────────────────────────────────┐  │  │
│  │  │  Documento + Firma + Clave Pública                                │  │  │
│  │  │  [✅ VERIFICAR] → ✅ Firma válida (Ed25519, FIPS 186-5)          │  │  │
│  │  │  ⚡ Velocidad: ~50 µs                                             │  │  │
│  │  └──────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                         │  │
│  │  Uso: sagas, JWT M2M, eventos CDC, logs de auditoría                   │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌── MOTOR EXTERNO: RSA-SHA256 (ADSIB Bolivia) ───────────────────────────┐ │
│  │                                                                         │ │
│  │  Documento XML (factura SIN):                                           │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │ │
│  │  │ [CARGAR FACTURA XML]  factura_123456.xml  (45 KB)                │  │ │
│  │  │ ┌──────────────────────────────────────────────────────────────┐ │  │ │
│  │  │ │ <?xml version="1.0" encoding="UTF-8"?>                       │ │  │ │
│  │  │ │ <facturaDigital xmlns:xsi="...">                              │ │  │ │
│  │  │ │   <cabecera>...</cabecera>                                    │ │  │ │
│  │  │ │   <detalle>...</detalle>                                      │ │  │ │
│  │  │ │ </facturaDigital>                                             │ │  │ │
│  │  │ └──────────────────────────────────────────────────────────────┘ │  │  │
│  │  └──────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                         │  │
│  │  Algoritmo: RSA 2048 + SHA-256 │ CA: ADSIB (ATT → ADSIB)              │  │
│  │  Cumplimiento: Ley 164 Bolivia │ SIN RND 102100000011                 │  │
│  │                                                                         │  │
│  │  [✍️ FIRMAR CON ADSIB]  →  Firma: 0xb2c3d4e5... (256 bytes)          │  │
│  │                                                                         │  │
│  │  ┌── VERIFICACIÓN ADSIB ────────────────────────────────────────────┐  │  │
│  │  │  [✅ VERIFICAR CONTRA ADSIB] → ✅ Firma válida + CRL OK          │  │  │
│  │  │  📜 Certificado: CN=EMPRESA S.A., OU=SIN, O=ADSIB, C=BO         │  │  │
│  │  │  🔒 CRL: No revocado │ 📅 Válido hasta: 2027-06-28              │  │  │
│  │  └──────────────────────────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌── COMPARATIVA ────────────────────────────────────────────────────────┐ │
│  │                  │ INTERNO (Ed25519)    │ EXTERNO (ADSIB RSA)         │ │
│  │  Tamaño firma    │ 64 bytes             │ 256 bytes                   │ │
│  │  Velocidad       │ ~50 µs               │ ~2,000 µs                   │ │
│  │  CA              │ Vault PKI (propia)   │ ADSIB (ATT → ADSIB)        │ │
│  │  Validez jurídica│ Interna SBOS         │ Nacional Bolivia (Ley 164) │ │
│  │  Uso principal   │ Tokens, logs, sagas  │ Facturación SIN            │ │
│  └─────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.9 Pantalla 09 — Colecciones y Entornos

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🛠️ bAuthDEV  │  🟢 Conectado  │  👤 test_cajero  │  📦 Colecciones       │
├──────────┬────────────────────────────────────────────────────────────────────┤
│          │                                                                    │
│ 📁 MIS    │  ┌── COLECCIÓN: Flujo de Caja ─────────────────────────────────┐  │
│ COLECCIONES│  │                                                              │  │
│          │  │  ┌──────────────────────────────────────────────────────────┐  │  │
│ ├── Flujo │  │  │ #1  bauth.token.issue     test_cajero     🟢 1.1 KB    │  │  │
│ │   Caja  │  │  │ #2  bauth.token.validate  eyJhbGciOi...   🟢 Válido    │  │  │
│ ├── Factur│  │  │ #3  bauth.access.evaluate tryton.sale_pos ✅ PERMITIDO  │  │  │
│ │   Elect.│  │  │ #4  bauth.context.evaluate ctx-019f06db... ✅ 12 dom.   │  │  │
│ ├── Prueba│  │  └──────────────────────────────────────────────────────────┘  │  │
│ │   MFA   │  │                                                              │  │
│ │         │  │  [▶ EJECUTAR TODA LA COLECCIÓN]  [📤 EXPORTAR JSON]         │  │
│ ├── Onboar│  │  [➕ AGREGAR REQUEST]  [🔄 REORDENAR]                        │  │
│ │   ding  │  │                                                              │  │
│          │  └──────────────────────────────────────────────────────────────┘  │
│          │                                                                    │
│ ──────── │  ┌── ENTORNO: Producción ───────────────────────────────────────┐  │
│          │  │                                                              │  │
│ ⭐ FAVORIT│  │  Variables definidas:                                        │  │
│ ├── Token │  │  ┌──────────────────────────────────────────────────────┐   │  │
│ │   Lab   │  │  │ {{host}}        = 13.140.128.230                     │   │  │
│ ├── GetCon│  │  │ {{port}}        = 9450                                │   │  │
│ │   text  │  │  │ {{tenant_id}}   = 019f06db-62a6-7777-...             │   │  │
│          │  │  │ {{user_uuid}}   = 019f06db-62a9-73ab-...              │   │  │
│ ──────── │  │  │ {{ctx_id}}      = ctx-019f06db-62a6-7777-...          │   │  │
│          │  │  └──────────────────────────────────────────────────────┘   │  │
│ 🗑 PAPELER│  │                                                              │  │
│ ├── (3 blo│  │  [🔄 CAMBIAR A: Desarrollo ▼]  [➕ NUEVA VARIABLE]         │  │
│ │   ques) │  │  [📤 EXPORTAR COMO .env]                                    │  │
│          │  └──────────────────────────────────────────────────────────────┘  │
│          │                                                                    │
└──────────┴────────────────────────────────────────────────────────────────────┘
```

---

### 3.10 Pantalla 10 — Wizard: Mi primer GetContext (Flujo Guiado)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🛠️ bAuthDEV  │  🟢 Conectado  │  👤 Nuevo Dev  │  🧭 Wizard             │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌── PROGRESO DEL WIZARD ────────────────────────────────────────────────┐  │
│  │                                                                         │  │
│  │  ● PASO 1 ──── ● PASO 2 ──── ○ PASO 3 ──── ○ PASO 4 ──── ○ PASO 5   │  │
│  │  Conectar      Autenticar    Validar       Evaluar       Tu código     │  │
│  │                                                                         │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌── PASO 3: Validar el token ────────────────────────────────────────────┐ │
│  │                                                                         │ │
│  │  ✅ Token emitido en el paso anterior                                   │ │
│  │                                                                         │ │
│  │  Vamos a validar que el token sea correcto:                             │ │
│  │                                                                         │ │
│  │  ┌── REQUEST ENVIADO ───────────────────────────────────────────────┐  │ │
│  │  │ {                                                                  │  │ │
│  │  │   "method": "bauth.token.validate",                                │  │ │
│  │  │   "params": {                                                      │  │ │
│  │  │     "jwt": "eyJhbGciOiJFZDI1NTE5..."                               │  │ │
│  │  │   }                                                                │  │ │
│  │  │ }                                                                  │  │ │
│  │  └────────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                         │ │
│  │  ┌── RESPUESTA ─────────────────────────────────────────────────────┐  │ │
│  │  │ {                                                                  │  │ │
│  │  │   "valid": true,                                                   │  │ │
│  │  │   "claims": {                                                      │  │ │
│  │  │     "sub": "019f06db-62a9-73ab-a85a-f5d12f20233d",                │  │ │
│  │  │     "iss": "bauth.sbos.bo",                                        │  │ │
│  │  │     "loa": 2,                                                      │  │ │
│  │  │     "iat": 1719442200,                                             │  │ │
│  │  │     "exp": 1719471000                                              │  │ │
│  │  │   }                                                                │  │ │
│  │  │ }                                                                  │  │ │
│  │  └────────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                         │ │
│  │  ✅ El token ES VÁLIDO. Fue firmado por bAuth con Ed25519.             │ │
│  │  📅 Expira en 7h 59min.                                                │ │
│  │                                                                         │ │
│  │                                       [◀ ATRÁS]  [SIGUIENTE ▶]         │ │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌── CONSEJO ─────────────────────────────────────────────────────────────┐ │
│  │  💡 En tu app, siempre valida el JWT antes de usarlo.                   │ │
│  │  Puedes usar las JWKS de bAuth para verificar la firma sin llamar      │ │
│  │  al daemon cada vez: GET /run/bos/bauth.sock → bauth.token.jwks       │ │
│  └─────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.11 Pantalla 11 — Administración de Empresas y Usuarios

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🛠️ bAuthDEV  │  🟢 Conectado  │  Plan: PRO  │  👤 Admin                   │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌── TABS ────────────────────────────────────────────────────────────────┐ │
│  │  [🏢 EMPRESAS]  [👤 USUARIOS]  [🔑 ROLES]  [🌐 SUCURSALES]            │ │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌── EMPRESAS ────────────────────────────────────────────────────────────┐ │
│  │                                                                         │ │
│  │  🔍 Buscar empresa: [_______________________________]                   │ │
│  │                                                                         │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │ │
│  │  │ 🏢 COMERCIALIZADORA DEL VALLE S.A.                               │  │ │
│  │  │   NIT: 123456789012 │ Plan: PRO │ 3 sucursales │ 47 usuarios    │  │ │
│  │  │   📍 Sucursal Central (La Paz)     👤 23 usuarios                │  │ │
│  │  │   📍 Sucursal Norte (El Alto)      👤 15 usuarios                │  │ │
│  │  │   📍 Sucursal Sur (Oruro)          👤 9 usuarios                 │  │ │
│  │  │   [✏ EDITAR] [👤 VER USUARIOS] [🌐 VER SUCURSALES]              │  │ │
│  │  ├──────────────────────────────────────────────────────────────────┤  │ │
│  │  │ 🏢 DISTRIBUIDORA ANDINA S.R.L.                                   │  │ │
│  │  │   NIT: 987654321098 │ Plan: BASIC │ 1 sucursal │ 12 usuarios    │  │ │
│  │  │   [✏ EDITAR] [👤 VER USUARIOS] [🌐 VER SUCURSALES]              │  │ │
│  │  ├──────────────────────────────────────────────────────────────────┤  │ │
│  │  │ [➕ AGREGAR EMPRESA]                                              │  │ │
│  │  └──────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                         │ │
│  │  ┌── LÍMITES DE TU PLAN PRO ────────────────────────────────────────┐  │ │
│  │  │  Empresas: 2/10 │ Sucursales: 4/50 │ Usuarios: 59/1,000          │  │ │
│  │  │  Roles: 8/25 │ Dominios: 8/8                                     │  │ │
│  │  │  ┌──────────┬──────────┬──────────┬──────────┬──────────┐        │  │ │
│  │  │  │████░░░░░░│███████░░░│███░░░░░░░│████████░░│██████████│        │  │ │
│  │  │  └──────────┴──────────┴──────────┴──────────┴──────────┘        │  │ │
│  │  │  Empresas    Sucursales  Usuarios    Roles       Dominios         │  │ │
│  │  └───────────────────────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.12 Pantalla 12 — Registro de Desarrollador (TRIAL Signup)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                                                                        │ │
│  │                         🚀 CREAR CUENTA GRATUITA                       │ │
│  │                                                                        │ │
│  │  ┌── PASO 1 DE 3: Datos del desarrollador ─────────────────────────┐  │ │
│  │  │                                                                   │  │ │
│  │  │  Nombre completo *  [________________________________]           │  │ │
│  │  │  Email *             [________________________________]           │  │ │
│  │  │  Teléfono            [____] [________________]  (opcional)        │  │ │
│  │  │  País *              [Bolivia ▼]                                 │  │ │
│  │  │  Ciudad              [La Paz ▼]                                  │  │ │
│  │  │  Cómo llegaste aquí  [GitHub ▼]                                  │  │ │
│  │  │                                                                   │  │ │
│  │  │                                       [SIGUIENTE →]              │  │ │
│  │  └───────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                        │ │
│  │  ┌── PASO 2 DE 3: Tu emprendimiento ───────────────────────────────┐  │ │
│  │  │                                                                   │  │ │
│  │  │  Soy...             [Desarrollador independiente ▼]              │  │ │
│  │  │  Mi empresa/emprendimiento: [__________________________]         │  │ │
│  │  │  Stack principal:   [Go ▼] [Rust ▼] [+ Agregar]                  │  │ │
│  │  │  Ya tengo clientes: ○ Sí, entre [1-10 ▼] ○ Todavía no           │  │ │
│  │  │  ¿Cuántos?:                                                       │  │ │
│  │  │                                                                   │  │ │
│  │  │                              [← ATRÁS]  [SIGUIENTE →]            │  │ │
│  │  └───────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                        │ │
│  │  ┌── PASO 3 DE 3: ¿Qué te interesa? ───────────────────────────────┐  │ │
│  │  │                                                                   │  │ │
│  │  │  ☑ Autenticación y control de acceso para mis apps               │  │ │
│  │  │  ☑ Firma digital para facturación electrónica SIN                │  │ │
│  │  │  ☑ Roles y permisos personalizables por empresa                  │  │ │
│  │  │  ☐ Blockchain y anclaje de tokens para auditoría                 │  │ │
│  │  │  ☐ Solo estoy explorando — no tengo un caso de uso aún           │  │ │
│  │  │                                                                   │  │ │
│  │  │  ☑ Acepto los [Términos de Uso] y [Política de Privacidad]      │  │ │
│  │  │                                                                   │  │ │
│  │  │                          [← ATRÁS]  [🚀 CREAR CUENTA GRATUITA]   │  │ │
│  │  └───────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                        │ │
│  │  ⓘ Sin tarjeta de crédito. Acceso inmediato al plan TRIAL.            │ │
│  │    Tus datos nos permiten darte soporte personalizado.                 │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ¿Ya tienes cuenta? [🔐 Iniciar Sesión]                                     │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Reglas de validación:**
- Email: único, no desechable (prohibidos dominios temporales)
- Nombre: mínimo 3 caracteres
- País y Ciudad: requeridos para asignar servidor regional
- Términos: obligatorio aceptar

**Qué pasa después del registro:**
1. Se crea tenant TRIAL automáticamente (tenant_id UUIDv7)
2. Se envía email de verificación
3. Se abre bAuthDEV conectado al daemon con el tenant nuevo
4. El dashboard muestra: "🎉 ¡Bienvenido! Tu tenant TRIAL está listo."
5. SBOS recibe notificación: "Nuevo desarrollador: nombre, email, stack, intereses"

---

### 3.13 Pantalla 13 — Perfil del Tenant + Plan

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🛠️ bAuthDEV  │  🟢 Conectado  │  👤 juan.perez  │  ⚙ Mi Cuenta           │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌── TABS ────────────────────────────────────────────────────────────────┐ │
│  │  [👤 PERFIL] [💎 PLAN] [🔑 SEGURIDAD] [📧 NOTIFICACIONES]             │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌── PERFIL DEL TENANT ───────────────────────────────────────────────────┐ │
│  │                                                                         │ │
│  │  Tenant ID:    019f06db-62a6-7777-b581-4c37e3aeee9f                    │ │
│  │  Slug:         juan-perez-dev                                           │ │
│  │  Nombre legal: [Juan Pérez Gutiérrez_______________]                    │ │
│  │  Email:        [juan@mi-empresa.com.bo___________]                      │ │
│  │  Teléfono:     [+591 77712345___________________]                       │ │
│  │  País:         🇧🇴 Bolivia                                              │ │
│  │                                                                         │ │
│  │  [💾 GUARDAR CAMBIOS]                                                   │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌── MI PLAN ACTUAL ──────────────────────────────────────────────────────┐ │
│  │                                                                         │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │ │
│  │  │                                                                   │  │ │
│  │  │  🆓 PLAN TRIAL — Sin costo                                        │  │ │
│  │  │                                                                   │  │ │
│  │  │  ┌──────────┬──────────┬──────────┬──────────┬──────────┐        │  │ │
│  │  │  │████░░░░░░│██████░░░░│██████░░░░│██████████│██████████│        │  │ │
│  │  │  └──────────┴──────────┴──────────┴──────────┴──────────┘        │  │ │
│  │  │  Roles       Usuarios    Empresas    Sucursales   Dominios         │  │ │
│  │  │  2/3         23/50       1/1          1/3          3/3             │  │ │
│  │  │                                                                   │  │ │
│  │  │  ⚠ Estás al 78% del límite de usuarios.                          │  │ │
│  │  │                                                                   │  │ │
│  │  └──────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                         │ │
│  │  ┌── PLANES DISPONIBLES ────────────────────────────────────────────┐  │ │
│  │  │                                                                    │  │ │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │  │ │
│  │  │  │ 💼 BASIC     │  │ 💎 PRO       │  │ 🏢 ENTERPRISE│            │  │ │
│  │  │  │ $49/mes      │  │ $199/mes     │  │ A consultar  │            │  │ │
│  │  │  │ 5 roles      │  │ 25 roles     │  │ Ilimitado    │            │  │ │
│  │  │  │ 100 usuarios │  │ 1,000 usuarios│  │ 50,000+      │            │  │ │
│  │  │  │ 1 empresa    │  │ 10 empresas  │  │ Ilimitado    │            │  │ │
│  │  │  │ 3 dominios   │  │ 8 dominios   │  │ 12 dominios  │            │  │ │
│  │  │  │ [ELEGIR]     │  │ [ELEGIR] ★   │  │ [CONTACTAR]  │            │  │ │
│  │  │  └──────────────┘  └──────────────┘  └──────────────┘            │  │ │
│  │  └────────────────────────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.14 Pantalla 14 — Gestión de Empresas Cliente

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🛠️ bAuthDEV  │  🟢 Conectado  │  👤 juan.perez  │  🏢 Mis Empresas       │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌── RESUMEN ─────────────────────────────────────────────────────────────┐ │
│  │  🏢 8 empresas  │  🌐 34 sucursales  │  👤 847 usuarios  │  💎 Plan PRO│ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌── TOOLBAR ─────────────────────────────────────────────────────────────┐ │
│  │  🔍 [Buscar empresa...___________]  [Todas ▼]  [➕ NUEVA EMPRESA]      │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌── LISTA DE EMPRESAS ───────────────────────────────────────────────────┐ │
│  │                                                                         │ │
│  │  ┌── 🏢 COMERCIALIZADORA DEL VALLE S.A. ─────────────────────────┐    │ │
│  │  │  NIT: 123456789012  │  📍 3 sucursales  │  👤 47 usuarios     │    │ │
│  │  │  🟢 Activa          │  📅 Desde: 15 Mar 2026                   │    │ │
│  │  │  ┌── USO (30 días) ───────────────────────────────────────┐   │    │ │
│  │  │  │  📊 45,678 eval  │  🔑 1,234 tokens  │  ⚡ 99.7% FastPath│   │    │ │
│  │  │  │  ██████████████████████████░░░░░░  87% del límite      │   │    │ │
│  │  │  └────────────────────────────────────────────────────────┘   │    │ │
│  │  │  [👤 USUARIOS] [🌐 SUCURSALES] [📊 DETALLE] [✏ EDITAR]      │    │ │
│  │  └───────────────────────────────────────────────────────────────┘    │ │
│  │                                                                         │ │
│  │  ┌── 🏢 DISTRIBUIDORA ANDINA S.R.L. ─────────────────────────────┐    │ │
│  │  │  NIT: 987654321098  │  📍 1 sucursal   │  👤 12 usuarios     │    │ │
│  │  │  🟢 Activa          │  📅 Desde: 02 Abr 2026                   │    │ │
│  │  │  ┌── USO ──────────────────────────────────────────────────┐   │    │ │
│  │  │  │  📊 8,234 eval   │  🔑 456 tokens   │  ⚡ 98.1% FastPath │   │    │ │
│  │  │  │  ██████████░░░░░░░░░░░░░░░░░░░░░░░  28% del límite      │   │    │ │
│  │  │  └────────────────────────────────────────────────────────┘   │    │ │
│  │  │  [👤 USUARIOS] [🌐 SUCURSALES] [📊 DETALLE] [✏ EDITAR]      │    │ │
│  │  └───────────────────────────────────────────────────────────────┘    │ │
│  │                                                                         │ │
│  │  ┌── 🏢 AGROINDUSTRIAS DEL ORIENTE LTDA. ─────────────────────────┐    │ │
│  │  │  ...                                                                │ │
│  │  └────────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                         │ │
│  │  ┌── [➕ AGREGAR EMPRESA] ──────────────────────────────────────────┐ │ │
│  │  │  Empresas: 8/10 │ ████████░░ 80% │ ⚠ Quedan 2 cupos en tu plan │ │ │
│  │  └──────────────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Modal: Nueva Empresa**
```
┌── 🏢 NUEVA EMPRESA CLIENTE ───────────────────────────────────┐
│                                                               │
│  Razón Social *  [________________________________]           │
│  NIT *           [________________________]                   │
│  Régimen Fiscal  [General ▼]                                  │
│  País            [Bolivia ▼]                                  │
│  Ciudad          [La Paz ▼]                                   │
│  Moneda          [Boliviano (BOB) ▼]                          │
│                                                               │
│  ¿Esta empresa es operadora del sistema?                      │
│  ○ No — es un cliente tuyo (default)                          │
│  ○ Sí — es mi propia empresa                                 │
│                                                               │
│  [CANCELAR]  [🏢 CREAR EMPRESA]                              │
└───────────────────────────────────────────────────────────────┘
```

---

### 3.15 Pantalla 15 — Gestión de Sucursales

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🛠️ bAuthDEV  │  🟢 Conectado  │  👤 juan.perez  │  🌐 Sucursales         │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Empresa: [Comercializadora del Valle S.A. ▼]  [➕ NUEVA SUCURSAL]          │
│                                                                              │
│  ┌── SUCURSALES DE COMERCIALIZADORA DEL VALLE ────────────────────────────┐ │
│  │                                                                         │ │
│  │  ┌── 📍 Sucursal Central — La Paz ─────────────────────────────────┐   │ │
│  │  │  Dirección: Av. 16 de Julio #1234, Edif. Central, Piso 3       │   │ │
│  │  │  Zona:     Central │ Ciudad: La Paz │ Horario: Lun-Vie 8-18    │   │ │
│  │  │  Admin:    admin.central@comercializadora.com                   │   │ │
│  │  │  👤 23 usuarios  │  🖥 5 POS lógicos  │  🟢 Activa             │   │ │
│  │  │  ┌── USO (30d) ─────────────────────────────────────────────┐  │   │ │
│  │  │  │  📊 28,456 eval │ 92% FastPath │ 8% PolicyPath           │  │   │ │
│  │  │  └──────────────────────────────────────────────────────────┘  │   │ │
│  │  │  [👤 USUARIOS] [🖥 POS LÓGICOS] [✏ EDITAR] [📊 DETALLE]     │   │ │
│  │  └──────────────────────────────────────────────────────────────────┘   │ │
│  │                                                                         │ │
│  │  ┌── 📍 Sucursal Norte — El Alto ──────────────────────────────────┐   │ │
│  │  │  Dirección: Av. Juan Pablo II #567, Zona 16 de Julio           │   │ │
│  │  │  Admin:    admin.norte@comercializadora.com                     │   │ │
│  │  │  👤 15 usuarios  │  🖥 3 POS lógicos  │  🟢 Activa             │   │ │
│  │  │  [👤 USUARIOS] [🖥 POS LÓGICOS] [✏ EDITAR] [📊 DETALLE]     │   │ │
│  │  └──────────────────────────────────────────────────────────────────┘   │ │
│  │                                                                         │ │
│  │  ┌── 📍 Sucursal Sur — Oruro ──────────────────────────────────────┐   │ │
│  │  │  👤 9 usuarios  │  🖥 2 POS lógicos  │  🟡 Degradada           │   │ │
│  │  │  ⚠ Última conexión: hace 2h 34min                               │   │ │
│  │  │  [👤 USUARIOS] [🖥 POS LÓGICOS] [✏ EDITAR] [📊 DETALLE]     │   │ │
│  │  └──────────────────────────────────────────────────────────────────┘   │ │
│  │                                                                         │ │
│  │  Sucursales: 3/50 │ ████░░░░ 6% │ Plan PRO                            │ │
│  └─────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Modal: Nueva Sucursal**
```
┌── 🌐 NUEVA SUCURSAL ───────────────────────────────────────────┐
│                                                                │
│  Empresa      [Comercializadora del Valle S.A. ▼]              │
│  Nombre *     [________________________________]               │
│  Dirección    [________________________________]               │
│  Ciudad *     [La Paz ▼]                                      │
│  Zona         [Central ▼]                                     │
│  Horario      [08:00] a [18:00]  Días: [Lun-Vie ▼]           │
│  Admin Email  [________________________________]               │
│                                                                │
│  [CANCELAR]  [🌐 CREAR SUCURSAL]                              │
└────────────────────────────────────────────────────────────────┘
```

---

### 3.16 Pantalla 16 — Usuarios de Empresas Cliente

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🛠️ bAuthDEV  │  🟢 Conectado  │  👤 juan.perez  │  👤 Usuarios           │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Empresa: [Comercializadora del Valle ▼]  Sucursal: [Todas ▼]               │
│                                                                              │
│  ┌── TOOLBAR ─────────────────────────────────────────────────────────────┐ │
│  │  🔍 [Buscar usuario...___]  Rol: [Todos ▼]  Status: [Todos ▼]         │ │
│  │  [➕ NUEVO USUARIO]  [📤 EXPORTAR CSV]                                 │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌── TABLA DE USUARIOS ───────────────────────────────────────────────────┐ │
│  │  Usuario          │ Email                    │ Rol      │ St │ Último   │ │
│  │  ────────────────┼──────────────────────────┼──────────┼────┼──────────│ │
│  │  juan.perez      │ juan@comercializadora.com │ CAJERO   │ 🟢 │ 11:27   │ │
│  │  maria.lopez     │ maria@comercializadora.com│ SUPERV.  │ 🟢 │ 11:15   │ │
│  │  carlos.ruiz     │ carlos@comercializadora   │ GERENTE  │ 🟡 │ 08:01   │ │
│  │  ana.torres      │ ana@comercializadora.com  │ AUDITOR  │ 🔴 │ 25 Jun  │ │
│  │  pedro.salazar   │ pedro@comercializadora    │ CAJERO   │ 🔒 │ —       │ │
│  └──────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ← 1 2 3 ... 5 → │ 47 usuarios │ Filas: [20 ▼]                              │
│                                                                              │
│  ┌── RESUMEN DE ROLES ASIGNADOS ───────────────────────────────────────────┐ │
│  │  CAJERO: 23 👤 │ SUPERVISOR: 8 👤 │ GERENTE: 3 👤 │ AUDITOR: 1 👤     │ │
│  │  CONTADOR: 5 👤 │ SIN ROL: 7 👤 ⚠                                         │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.17 Pantalla 17 — Tracking de Uso (Visión del Negocio)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🛠️ bAuthDEV  │  🟢 Conectado  │  👤 juan.perez  │  📊 Mi Negocio        │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌── PERÍODO ─────────────────────────────────────────────────────────────┐ │
│  │  [📅 01 Jun 2026] — [📅 28 Jun 2026]  [Últimos 30d ▼]  [📤 EXPORTAR] │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌── MÉTRICAS GLOBALES DE TU NEGOCIO ─────────────────────────────────────┐ │
│  │                                                                         │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐    │ │
│  │  │ 🏢      │ │ 👤       │ │ 📊       │ │ ⚡       │ │ 💰       │    │ │
│  │  │   8     │ │   847    │ │  234.5K  │ │  99.7%   │ │ PRO      │    │ │
│  │  │ Empresas│ │ Usuarios │ │ Eval/mes │ │ FastPath │ │ $199/mes │    │ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘    │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌── ¿QUIÉN USA TU SISTEMA? ──────────────────────────────────────────────┐ │
│  │                                                                         │ │
│  │  ┌── EVALUACIONES POR EMPRESA (gráfico barras SVG) ─────────────────┐  │ │
│  │  │  Comercializadora ████████████████████████████████ 45,678       │  │ │
│  │  │  Distribuidora    ██████████ 8,234                               │  │ │
│  │  │  Agroindustrias   ██████████████████ 28,456                      │  │ │
│  │  │  Farmacias Bol.   ██████████████ 22,111                          │  │ │
│  │  │  Transportes And. ████████ 12,345                                │  │ │
│  │  └──────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                         │ │
│  │  ┌── EMPRESAS CON MAYOR CRECIMIENTO ───────────────────────────────┐  │ │
│  │  │  # │ Empresa                  │ Crecimiento │ Nuevos usuarios   │  │ │
│  │  │  1 │ Agroindustrias Oriente   │ 📈 +34%     │ +12 este mes      │  │ │
│  │  │  2 │ Comercializadora Valle   │ 📈 +22%     │ +5 este mes       │  │ │
│  │  │  3 │ Farmacias Bolivia        │ 📈 +18%     │ +3 este mes       │  │ │
│  │  └──────────────────────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌── SALUD DE TUS CLIENTES ───────────────────────────────────────────────┐ │
│  │                                                                         │ │
│  │  ┌── EMPRESAS QUE NECESITAN ATENCIÓN ───────────────────────────────┐ │ │
│  │  │  🟡 Transportes Andinos — 3 usuarios bloqueados, 0 actividad 5d  │ │ │
│  │  │  🟡 Farmacias Bolivia — 92% del límite de usuarios del plan      │ │ │
│  │  └──────────────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.18 Pantalla 18 — Soporte y Colaboración SBOS

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🛠️ bAuthDEV  │  🟢 Conectado  │  👤 juan.perez  │  🎓 Soporte           │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌── TU GERENTE DE CUENTA SBOS ───────────────────────────────────────────┐ │
│  │                                                                         │ │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │ │
│  │  │  👤 María Gutiérrez — tu contacto en SBOS                       │   │ │
│  │  │  📧 maria.gutierrez@skull.sbos.bo   │   📞 +591 777889900       │   │ │
│  │  │  💬 Respondemos en < 4 horas hábiles                            │   │ │
│  │  │  [💬 ENVIAR MENSAJE]  [📅 AGENDAR LLAMADA]                      │   │ │
│  │  └─────────────────────────────────────────────────────────────────┘   │ │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌── RECURSOS DE APRENDIZAJE ─────────────────────────────────────────────┐ │
│  │                                                                         │ │
│  │  ┌─────────────────────┐ ┌─────────────────────┐ ┌──────────────────┐  │ │
│  │  │ 📖 Documentación    │ │ 🎥 Videotutoriales  │ │ 💬 Foro          │  │ │
│  │  │ 47 métodos RPC      │ │ "Mi primer GetCtx"  │ │ Comunidad devs   │  │ │
│  │  │ Guías paso a paso   │ │ "Roles y SoD"       │ │ Preguntas y tips │  │ │
│  │  │ [ABRIR]             │ │ [VER]               │ │ [ENTRAR]         │  │ │
│  │  └─────────────────────┘ └─────────────────────┘ └──────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌── HISTORIAL DE INTERACCIONES CON SBOS ──────────────────────────────────┐ │
│  │                                                                         │ │
│  │  28 Jun 14:32  📧 Consulta: "¿Cómo aumento el límite de facturación?" │ │
│  │  28 Jun 15:10  💬 Respuesta: "Te explico cómo ajustar D3 Financiero"  │ │
│  │  25 Jun 10:15  📅 Llamada: Onboarding inicial (30 min)                 │ │
│  │  20 Jun 09:00  🚀 Registro: Creaste tu cuenta TRIAL                    │ │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌── ESTADO DE TU ONBOARDING ─────────────────────────────────────────────┐ │
│  │                                                                         │ │
│  │  ✅ 1. Registro completado                          (20 Jun)            │ │
│  │  ✅ 2. Email verificado                             (20 Jun)            │ │
│  │  ✅ 3. Primer conexión al daemon                    (20 Jun)            │ │
│  │  ✅ 4. Primer GetContext exitoso                    (22 Jun)            │ │
│  │  ✅ 5. Primer rol personalizado creado              (24 Jun)            │ │
│  │  ✅ 6. Primera empresa cliente onboardeada          (25 Jun)            │ │
│  │  ⬜ 7. Activar facturación (cambiar a plan pago)    (pendiente)         │ │
│  │  ⬜ 8. Primer token de producción emitido            (pendiente)         │ │
│  │                                                                         │ │
│  │  ┌── PROGRESO GENERAL ───────────────────────────────────────────┐    │ │
│  │  │  ██████████████████████████████████████░░░░░░░░  75% completado│    │ │
│  │  └──────────────────────────────────────────────────────────────┘    │ │
│  └─────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 3bis. ESPECIFICACIONES DE FORMULARIOS CRUD

> **Instrucción para Claude Design:** Cada formulario aquí especificado debe generarse como
> un modal HTML con validación en vivo, mensajes de error en español, y campos requeridos
> marcados con asterisco (*). Los campos calculados o de solo lectura deben mostrarse
> pero no ser editables. Los selectores deben cargar opciones desde el catálogo real.

### F1. FORMULARIO — Nueva Empresa (org_empresa)

```html
<!-- @dsCard group="Formularios CRUD" -->
<!--
  ┌── 🏢 NUEVA EMPRESA CLIENTE ───────────────────────────────┐
  │                                                            │
  │  DATOS FISCALES                                            │
  │  ┌──────────────────────────────────────────────────────┐  │
  │  │  Razón Social *                                      │  │
  │  │  [___Comercializadora del Valle S.A._____________]   │  │
  │  │  ⓘ Nombre legal completo según registro FUNDEMPRESA │  │
  │  │                                                      │  │
  │  │  NIT *                Régimen Fiscal *               │  │
  │  │  [___123456789012___] [General ▼]                    │  │
  │  │  ⓘ 12 dígitos        Opciones: General, Simplificado │  │
  │  │                      Agropecuario, No Domiciliado    │  │
  │  └──────────────────────────────────────────────────────┘  │
  │                                                            │
  │  CONFIGURACIÓN REGIONAL                                    │
  │  ┌──────────────────────────────────────────────────────┐  │
  │  │  País *         Ciudad *        Moneda *             │  │
  │  │  [Bolivia ▼]    [La Paz ▼]     [Boliviano (BOB) ▼]  │  │
  │  │                                                      │  │
  │  │  Zona Horaria *          Formato Fecha               │  │
  │  │  [America/La_Paz ▼]      [DD/MM/YYYY ▼]             │  │
  │  │                                                      │  │
  │  │  Símbolo Moneda    Idiomas adicionales               │  │
  │  │  [Bs.___________]  ☐ English (en-US)                │  │
  │  │                    ☐ Portugués (pt-BR)              │  │
  │  └──────────────────────────────────────────────────────┘  │
  │                                                            │
  │  CLASIFICACIÓN                                             │
  │  ┌──────────────────────────────────────────────────────┐  │
  │  │  ○ Esta empresa es cliente mío (default)             │  │
  │  │  ○ Es mi propia empresa (casa matriz, operador)     │  │
  │  └──────────────────────────────────────────────────────┘  │
  │                                                            │
  │  [CANCELAR]                    [🏢 CREAR EMPRESA]         │
  └────────────────────────────────────────────────────────────┘

  CAMPOS:
  ┌─────────────────────┬──────────┬──────────┬──────────────────────────────┐
  │ Campo               │ Tipo     │ Req      │ Validación                   │
  ├─────────────────────┼──────────┼──────────┼──────────────────────────────┤
  │ razon_social        │ text     │ SI       │ min 3, max 200 chars         │
  │ nit                 │ text     │ SI       │ digits only, 8-15 chars      │
  │ regimen_fiscal      │ select   │ SI       │ GENERAL, SIMPLIFICADO,       │
  │                     │          │          │ AGROPECUARIO, NO_DOMICILIADO │
  │ es_operador         │ radio    │ SI       │ true=mi empresa, false=cliente│
  │ locale_default      │ select   │ NO       │ es-BO, en-US, pt-BR          │
  │ timezone_default    │ select   │ NO       │ IANA timezone                │
  │ moneda_default      │ select   │ NO       │ BOB, USD, EUR, BRL, ARS      │
  │ currency_symbol     │ text     │ NO       │ max 5 chars, ej: "Bs."       │
  │ date_format         │ select   │ NO       │ DD/MM/YYYY, MM/DD/YYYY       │
  │ monedas_extra       │ multiselect│ NO     │ monedas adicionales           │
  │ locales_extra       │ multiselect│ NO     │ idiomas adicionales           │
  │ status              │ hidden   │ —        │ auto: "ACTIVE"               │
  │ empresa_id          │ hidden   │ —        │ auto: "NIT-{nit}"            │
  └─────────────────────┴──────────┴──────────┴──────────────────────────────┘

  VALIDACIONES:
  - nit: debe ser único en el tenant
  - razon_social: min 3 caracteres, no solo números
  - Si es_operador=true: se requiere empresa_id manual
  - moneda_default: debe existir en monedas_extra si se agregan extras
-->
```

### F2. FORMULARIO — Nueva Sucursal (org_sucursal)

```html
<!-- @dsCard group="Formularios CRUD" -->
<!--
  ┌── 🌐 NUEVA SUCURSAL ──────────────────────────────────────┐
  │                                                           │
  │  Empresa: [Comercializadora del Valle S.A. ▼]             │
  │                                                           │
  │  DATOS PRINCIPALES                                        │
  │  ┌─────────────────────────────────────────────────────┐  │
  │  │  Nombre *                                           │  │
  │  │  [___Sucursal Central___________________________]   │  │
  │  │                                                     │  │
  │  │  Dirección               Ciudad *                   │  │
  │  │  [___Av. 16 de Julio___] [La Paz ▼]                 │  │
  │  │                                                     │  │
  │  │  Zona/Barrio              Zona Horaria              │  │
  │  │  [___Central___________]  [America/La_Paz ▼]        │  │
  │  └─────────────────────────────────────────────────────┘  │
  │                                                           │
  │  HORARIO DE OPERACIÓN                                     │
  │  ┌─────────────────────────────────────────────────────┐  │
  │  │  Apertura: [08:00]    Cierre: [18:00]               │  │
  │  │                                                     │  │
  │  │  Días de operación:                                 │  │
  │  │  ☑ Lunes  ☑ Martes  ☑ Miércoles  ☑ Jueves         │  │
  │  │  ☑ Viernes  ☐ Sábado  ☐ Domingo                   │  │
  │  └─────────────────────────────────────────────────────┘  │
  │                                                           │
  │  ADMINISTRADOR DE SUCURSAL                                │
  │  ┌─────────────────────────────────────────────────────┐  │
  │  │  Admin: [🔍 Buscar usuario...___________________]   │  │
  │  │  ⓘ Este usuario podrá gestionar la sucursal        │  │
  │  │  Seleccionado: juan.perez (juan@comercializadora)   │  │
  │  └─────────────────────────────────────────────────────┘  │
  │                                                           │
  │  [CANCELAR]                    [🌐 CREAR SUCURSAL]       │
  └──────────────────────────────────────────────────────────┘

  CAMPOS:
  ┌─────────────────────┬──────────┬──────────┬──────────────────────────────┐
  │ Campo               │ Tipo     │ Req      │ Validación                   │
  ├─────────────────────┼──────────┼──────────┼──────────────────────────────┤
  │ empresa_id          │ select   │ SI       │ debe existir                 │
  │ nombre              │ text     │ SI       │ min 3, max 100 chars         │
  │ direccion           │ text     │ NO       │ max 300 chars                │
  │ ciudad              │ select   │ SI       │ ciudades del país            │
  │ zona                │ text     │ NO       │ max 100 chars                │
  │ timezone            │ select   │ NO       │ IANA timezone, hereda emp    │
  │ horario_apertura    │ time     │ NO       │ HH:MM, 00:00-23:59           │
  │ horario_cierre      │ time     │ NO       │ HH:MM, 00:00-23:59, > apert │
  │ dias_operacion      │ checkbox │ NO       │ LUNES..DOMINGO               │
  │ admin_user_uuid     │ search   │ NO       │ usuario existente en tenant  │
  │ sucursal_id         │ hidden   │ —        │ auto: "{empresa}-{nombre}"   │
  └─────────────────────┴──────────┴──────────┴──────────────────────────────┘

  VALIDACIONES:
  - nombre: único dentro de la misma empresa
  - horario_cierre > horario_apertura (si ambos especificados)
  - admin_user_uuid: debe existir en idn_user_template
  - Al menos 1 día de operación seleccionado si se especifican horarios
-->
```

### F3. FORMULARIO — Usuario (ÁRBOL JERÁRQUICO · 15 Secciones · UserTemplate v6.0)

```html
<!-- @dsCard group="Formularios CRUD Jerárquicos" -->
<!--
  REGLA FUNDAMENTAL (BAUTH-CRUD-ROLES-USUARIOS.md):
  "El admin NO llena formularios planos. Navega un ÁRBOL JERÁRQUICO."

  ARQUITECTURA DE ALMACENAMIENTO:
    Identity (idn_user_template)
      └── template JSONB
           ├── Sección (ej: personal_info)
           │    ├── Sub-bloque (ej: demographics)
           │    │    ├── Campo simple (birth_date, gender)
           │    │    └── Campo compuesto (nationality: {primary, secondary})
           │    └── Sub-bloque (ej: identification)
           │         └── Array de objetos (primary_document, secondary_documents[])
           └── Sección (ej: professional_info)
                └── Sub-bloque (ej: compensation)
                     └── Campos con _classification=RESTRICTED (salary)

  PATRÓN DE INTERACCIÓN:
    - Navegación: expandir/colapsar ramas con ▶/▼
    - Valores simples: click → edición inline
    - Arrays: click en [+] → modal con catálogo filtrado
    - Objetos anidados: sub-árbol desplegable
    - Datos PII/RESTRICTED: badge de clasificación + icono 🔒
    - Solo lectura (KC): badge 👁 + campos deshabilitados

  ÁRBOL COMPLETO:

  👤 USUARIO: juan.perez
  │
  ├── 📋 1. IDENTIDAD (identity) — 25 campos
  │   ├── Datos básicos ✏
  │   │   ├── uuid:          "019f06db-..." (readonly, generado)
  │   │   ├── username *:    [juan.perez___________] regex: ^[a-z][a-z0-9._-]{2,64}$
  │   │   ├── email *:       [juan@comercializadora.com]
  │   │   ├── display_name:  [Juan Pérez Gutiérrez__]
  │   │   ├── nickname:      [Juancho_____________]
  │   │   ├── honorific_prefix: [Lic. ▼] (Dr., Lic., Ing., Sr., Sra.)
  │   │   ├── honorific_suffix: [MBA ▼]
  │   │   ├── profile_url:   [https://sbos.app/users/juan.perez]
  │   │   ├── locale *:      [es-BO ▼]
  │   │   ├── zoneinfo *:    [America/La_Paz ▼]
  │   │   └── preferred_language: [es ▼]
  │   ├── Tenant/Empresa ✏
  │   │   ├── tenant_id *:   [skull ▼]
  │   │   ├── empresa_id *:  [NIT-1234567890 ▼]
  │   │   ├── sucursal_id:   [skull-central ▼]
  │   │   ├── pos_logico:    [POS-01 ▼]
  │   │   ├── realm_kc:      [tenant-skull] (readonly)
  │   │   └── namespace_k8s: [tenant-skull]
  │   ├── Clasificación ✏
  │   │   ├── account_type *: [HUMAN ▼] (HUMAN, SERVICE, M2M, SYSTEM)
  │   │   ├── user_type *:    [EMPLOYEE ▼] (EMPLOYEE, CONTRACTOR, EXTERNAL, VENDOR, INTERN)
  │   │   └── version:        "1.1.0"
  │   ├── Ciclo de vida (lifecycle) 👁
  │   │   ├── status:           🟢 ACTIVE
  │   │   ├── created_at:       2026-01-15T08:00:00Z
  │   │   ├── activated_at:     2026-01-15T08:30:00Z
  │   │   ├── termination_date: null
  │   │   ├── termination_reason: null
  │   │   ├── offboarding_status: null
  │   │   └── purge_after:      null
  │   ├── Federación (federation) ✏
  │   │   ├── federated_idp:      null  [➕ Vincular IdP externo]
  │   │   ├── federated_user_id:  null
  │   │   ├── federated_username: null
  │   │   ├── identity_provider:  [keycloak ▼]
  │   │   └── brokering_enabled:  ☐
  │   └── Firma Digital (digital_signature) 👁
  │       ├── algorithm:               EdDSA_Ed25519
  │       ├── signature:               base64...
  │       ├── certificate_thumbprint:  sha256:abc123...
  │       ├── post_quantum_planned:    CRYSTALS-Dilithium
  │       └── validity:                2026-01-15 → 2027-01-15
  │
  ├── 🔒 2. DATOS PERSONALES (personal_info) — 60+ campos · _classification: CONFIDENTIAL
  │   ├── ⚙ Control de Acceso ✏
  │   │   ├── _classification:       [CONFIDENTIAL ▼]
  │   │   ├── full_access_roles:     [ROL-ORG-CHRO] [➕]
  │   │   ├── masked_access_roles:   [ROL-ORG-GER-RRHH] [➕]
  │   │   ├── restricted_fields:     [national_id, birth_date, bank_account] [➕]
  │   │   └── gdpr_sensitive_fields: [gender, nationality, biometric_data] [➕]
  │   ├── Nombre ✏
  │   │   ├── given_name *:          [Juan______________]
  │   │   ├── middle_name:           [Carlos____________]
  │   │   ├── family_name *:         [Pérez_____________]
  │   │   ├── second_family_name:    [Gutiérrez_________]
  │   │   ├── full_name:             "Juan Carlos Pérez Gutiérrez" (auto)
  │   │   ├── formatted_name:        "Lic. Juan Pérez Gutiérrez, MBA" (auto)
  │   │   ├── initials:              "JCPG" (auto)
  │   │   └── previous_names: [] [➕]
  │   ├── Demográficos ✏
  │   │   ├── birth_date *:          [1985-06-15________] 🔒 restricted
  │   │   ├── gender:                [M ▼] (M, F, NB, NR) 🔒 gdpr_sensitive
  │   │   ├── nationality *:         [BOL ▼] ISO 3166-1 alpha-3
  │   │   ├── nationality_secondary: null
  │   │   ├── ethnicity:             null 🔒 gdpr_sensitive
  │   │   ├── religion:              null 🔒 gdpr_sensitive
  │   │   ├── marital_status:        [MARRIED ▼] (SINGLE, MARRIED, DIVORCED, WIDOWED, CIVIL_UNION)
  │   │   ├── dependents_count:      2
  │   │   └── military_status:       null
  │   ├── Identificación ✏
  │   │   ├── ▶ primary_document
  │   │   │   ├── type *:            [CI ▼] (DNI, PASSPORT, CI, RUT, NIT, CC, RNE)
  │   │   │   ├── number *:          [****5678Z] 🔒 masked — valor real: 12345678 LP
  │   │   │   ├── issue_date *:      [2015-03-10________]
  │   │   │   ├── expiry_date *:     [2025-03-10________]
  │   │   │   ├── issuing_country *: [BO ▼]
  │   │   │   ├── issuing_authority: [SEGIP_____________]
  │   │   │   ├── verified:          ☑ (2026-01-15 por HR.VERIFICATION)
  │   │   │   └── hashed_number:     sha256:abc... (auto)
  │   │   ├── ▶ secondary_documents [] [➕ Agregar documento]
  │   │   ├── ▶ tax_identifiers [] [➕ Agregar NIT]
  │   │   └── ▶ social_identifiers [] [➕]
  │   ├── Contacto ✏
  │   │   ├── ▶ emails [] [➕ Agregar email]  (mín 1 requerido)
  │   │   │   └── 📧 juan@comercializadora.com
  │   │   │       ├── type: work | is_primary: ☑ | verified: ☑
  │   │   │       └── verification_method: EMAIL_LINK
  │   │   ├── ▶ phones [] [➕ Agregar teléfono]
  │   │   │   └── 📱 +591 77712345
  │   │   │       ├── type: mobile | carrier: TIGO | is_primary: ☑
  │   │   │       └── verified: ☑ | country_code: +591
  │   │   ├── ▶ ims [] [➕] (WhatsApp, Telegram, Signal)
  │   │   └── ▶ websites [] [➕]
  │   ├── Direcciones ✏
  │   │   └── ▶ addresses [] [➕ Agregar dirección]
  │   │       └── 🏠 Casa
  │   │           ├── type: HOME | street: Calle Bolívar #123
  │   │           ├── city: La Paz | country: BO | postal_code: 0201
  │   │           ├── coordinates: -16.4955,-68.1336
  │   │           └── is_primary: ☑ | verified: ☑
  │   ├── Contactos de Emergencia ✏
  │   │   └── ▶ emergency_contacts [] [➕]
  │   │       └── 🚨 María Pérez (esposa)
  │   │           ├── relationship: SPOUSE | phone: +591 77754321
  │   │           ├── email: maria@email.com
  │   │           └── priority: 1 | can_pickup_children: ☑
  │   ├── Información de Salud 🔒 RESTRICTED
  │   │   ├── _classification: RESTRICTED
  │   │   ├── _access_roles: [ROL-ORG-CHRO]
  │   │   ├── blood_type: O+
  │   │   ├── allergies: [Penicilina] [➕]
  │   │   ├── medical_conditions: [] [➕]
  │   │   ├── disability_status: null
  │   │   ├── disability_accommodations: [] [➕]
  │   │   └── physician: Dr. Carlos Mendoza | +591 22456789
  │   └── Datos Biométricos 🔒 RESTRICTED · GDPR Art.9
  │       ├── _classification: RESTRICTED
  │       ├── _gdpr_basis: explicit_consent
  │       ├── _consent_id: uuid-consent-biometric
  │       ├── face_photo_url: https://...
  │       ├── face_photo_hash: sha256:def...
  │       └── face_photo_updated_at: 2026-01-15T08:00:00Z
  │
  ├── 💼 3. DATOS PROFESIONALES (professional_info) — 40+ campos
  │   ├── Identificación Laboral ✏
  │   │   ├── employee_code *:  [EMP789456_________]
  │   │   ├── employee_type *:  [FULL_TIME ▼] (FULL_TIME, PART_TIME, CONTRACTOR, INTERN, OUTSOURCED)
  │   │   └── employment_status: 🟢 ACTIVE
  │   ├── Puesto (job) ✏
  │   │   ├── title *:          [Cajero Principal______________]
  │   │   ├── title_en:         [Head Cashier_________________]
  │   │   ├── job_family:       [Ventas_______________________]
  │   │   ├── job_level:        [O3 ▼] (O1-O5, T1-T5, M1-M5, D1-D3)
  │   │   ├── job_code:         [CAJA-SENIOR__________________]
  │   │   ├── job_description:  [Responsable de caja principal]
  │   │   ├── fte_ratio:        [1.0__________________________]
  │   │   └── flsa_status:      [NONEXEMPT ▼]
  │   ├── Organización ✏
  │   │   ├── department *:     [Caja_________________________]
  │   │   ├── division:         [Operaciones__________________]
  │   │   ├── cost_center:      [CAJA-CENTRAL_________________]
  │   │   ├── business_unit:    [LATAM-BOL____________________]
  │   │   ├── legal_entity:     [Comercializadora del Valle___]
  │   │   ├── profit_center:    [PC-CENTRAL-001_______________]
  │   │   └── location_code:    [LPZ-HQ_______________________]
  │   ├── Línea de Reporte ✏
  │   │   ├── manager_uuid *:   [🔍 uuid-carlos-ruiz___________]
  │   │   ├── manager_username: carlos.ruiz (auto)
  │   │   ├── manager_email:    carlos@comercializadora.com (auto)
  │   │   ├── ▶ reports_to_chain [] (auto)
  │   │   ├── direct_reports_count: 0
  │   │   ├── ▶ direct_reports [] [➕]
  │   │   └── dotted_line_manager: null [🔍]
  │   ├── Detalles de Empleo ✏
  │   │   ├── hire_date *:             [2024-01-15________]
  │   │   ├── original_hire_date:      [2024-01-15________]
  │   │   ├── seniority_date:          [2024-01-15________]
  │   │   ├── probation_end_date:      [2024-04-15________]
  │   │   ├── termination_date:        null
  │   │   ├── termination_reason:      null
  │   │   ├── last_working_day:        null
  │   │   ├── notice_period_days:      30
  │   │   ├── contract_type:           [INDEFINITE ▼] (INDEFINITE, FIXED_TERM, SEASONAL)
  │   │   └── contract_end_date:       null
  │   ├── Compensación 🔒 RESTRICTED
  │   │   ├── _classification:  RESTRICTED
  │   │   ├── _access_roles:    [ROL-ORG-CHRO, ROL-ORG-CFO]
  │   │   ├── salary_currency:  [BOB ▼]
  │   │   ├── salary_amount:    [8,500.00________] 🔒
  │   │   ├── salary_frequency: [MONTHLY ▼]
  │   │   ├── overtime_eligible: ☐
  │   │   ├── bonus_eligible:   ☑
  │   │   └── bonus_target_pct: 15
  │   ├── Ubicación de Oficina ✏
  │   │   ├── building:         Edificio Central
  │   │   ├── floor:            1
  │   │   ├── wing:             Ala Norte
  │   │   ├── desk:             C-42
  │   │   └── desk_phone:       21234567
  │   ├── Certificaciones ✏
  │   │   └── ▶ certifications [] [➕]
  │   │       └── 📜 SALES_CERT_A | SEGIP | 2025-06-01 | required_for_role: ☑
  │   ├── Educación ✏
  │   │   └── ▶ education [] [➕]
  │   └── Habilidades ✏
  │       └── ▶ skills [] [➕]
  │
  ├── 🔑 4. ROLES ASIGNADOS (roles_assignments)
  │   ├── ▶ active_roles [] [➕ Asignar rol desde catálogo]
  │   │   └── 🔑 CAJERO (BIZ_N3)
  │   │       ├── assignment_id:  uuid-assign-001 (auto)
  │   │       ├── role_id:        ROL-ORG-CAJ
  │   │       ├── assigned_at:    2026-01-15T08:00:00Z
  │   │       ├── assigned_by:    ADMIN.SISTEMA
  │   │       ├── approved_by:    DIRECTOR_VENTAS
  │   │       ├── valid_from:     2026-01-15 ─── valid_until: null (indefinido)
  │   │       ├── status:         🟢 ACTIVE
  │   │       ├── is_primary_role: ☑
  │   │       ├── can_be_delegated: ☑
  │   │       ├── bitmask_effective: 0x0000010900030052 (readonly)
  │   │       └── ▶ context_overrides (excepciones temporales/red/geo)
  │   ├── ▶ role_history [] 👁 (histórico de asignaciones pasadas)
  │   ├── ▶ delegations_received [] 👁 (delegaciones de otros usuarios)
  │   ├── ▶ delegations_given [] [➕ Nueva delegación]
  │   └── ▶ role_compliance 👁
  │       ├── sod_conflicts_detected:  []
  │       ├── sod_conflicts_overridden: []
  │       ├── last_sod_check_at:       2026-06-24T08:00:00Z
  │       ├── compliant:                ☑
  │       └── unused_permissions_count: 3
  │
  ├── 🔐 5. CREDENCIALES KEYCLOAK (keycloak_credentials) 👁 SOLO LECTURA
  │   ├── Password
  │   │   ├── has_password:       ☑
  │   │   ├── strength_score:     92/100
  │   │   └── hibp_compromised:   ☐ (limpio)
  │   ├── TOTP
  │   │   └── ▶ devices []:  [Dispositivo 1: Google Authenticator]
  │   ├── WebAuthn
  │   │   └── ▶ credentials []:  [YubiKey 5C NFC · 2026-01-15]
  │   ├── Passkeys:  ☑ (1 registrada)
  │   ├── Backup Codes:  ☑ (8 de 10 disponibles)
  │   └── Compliance
  │       ├── covers_required_methods:  ☑
  │       └── compliant:                ☑
  │
  ├── 🏢 6. CREDENCIALES FÍSICAS (physical_credentials) ✏
  │   ├── ▶ smart_cards [] [➕]
  │   │   └── 🪪 NFC MIFARE DESFire · ACTIVE · card_number: ****1234
  │   ├── ▶ mobile_credentials [] [➕]
  │   └── ▶ biometric_enrollments [] [➕]
  │       └── 🧬 Fingerprint · RIGHT_INDEX · Argon2id · liveness: ☑ · consent: ☑
  │
  ├── 📱 7. DISPOSITIVOS (device_registry) ✏
  │   ├── ▶ primary_device
  │   │   ├── device_id:      DEV-POS-001
  │   │   ├── platform:       ubuntu_26_04
  │   │   ├── os_version:     26.04
  │   │   ├── trust_score:    85/100
  │   │   ├── attestation_provider: SBOS MDM
  │   │   └── push_token_registered: ☑
  │   └── ▶ secondary_devices [] [➕]
  │
  ├── 📍 8. PERFIL DE UBICACIÓN (location_profile) ✏
  │   ├── home_location:     La Paz, BO (-16.4955, -68.1336)
  │   ├── work_location:     Av. 16 de Julio #1234, La Paz
  │   ├── ▶ assigned_branches []:  [skull-central, skull-sucursal-sc] [➕]
  │   ├── ▶ allowed_countries []:  [BO, AR, BR, CL, PE] [➕]
  │   ├── ▶ blocked_countries []:  [] [➕]
  │   └── ▶ location_history [] 👁
  │
  ├── 🕐 9. PERFIL TEMPORAL (temporal_profile) ✏
  │   ├── assigned_schedule_id:  SCHEDULE-STANDARD
  │   ├── timezone:              America/La_Paz
  │   ├── ▶ work_schedule
  │   │   ├── ▶ days []:  Lun-Vie
  │   │   │   └── ▶ shifts []:  08:00-12:00, 14:00-18:00
  │   │   └── ▶ breaks []:  12:00-14:00 (almuerzo)
  │   ├── overtime_allowed: ☐
  │   ├── remote_work_allowed: ☐
  │   └── attendance_today: 🟢 Presente (08:02 AM)
  │
  ├── 🌐 10. PERFIL DE RED (network_profile) ✏
  │   ├── ▶ allowed_cidrs []:  [10.0.1.0/24, 10.0.2.0/24] [➕]
  │   ├── vpn_required:        ☐
  │   ├── mtls_required:       ☐
  │   └── device_trust_min_score: 70
  │
  ├── 📋 11. PERFIL DE AUDITORÍA (audit_profile) ✏
  │   ├── audit_level:       [full ▼]
  │   ├── retention_days:    2555
  │   ├── hash_chain_required: ☑
  │   ├── review_schedule:   [QUARTERLY ▼]
  │   └── ▶ compliance_status 👁
  │       ├── iso_27001:     ☑ compliant
  │       ├── sox:           — no aplica
  │       ├── pci_dss:       ☑ compliant
  │       ├── gdpr:          ☑ compliant
  │       └── nist_800_53:   ☑ compliant
  │
  ├── 🔗 12. SERVICIOS EXTERNOS (external_services) 👁
  │   └── ▶ consented_apps []:  [Tryton, Superset, Grafana]
  │       └── 📱 Tryton · scopes: [read, write] · desde: 2026-01-15 · 🟢 ACTIVE
  │
  ├── ⚖ 13. PERFIL DE COMPLIANCE (compliance_profile) ✏
  │   ├── ▶ segregation_of_duties
  │   │   └── ⚠ Conflicto detectado: CAJERO + AUDITOR → [RESOLVER]
  │   ├── ▶ conflict_of_interest
  │   │   ├── ▶ declarations []:  [Declaración anual 2026]
  │   │   ├── ▶ family_in_company []:  [María Pérez — Depto. Contabilidad]
  │   │   └── ▶ outside_interests []:  []
  │   ├── ▶ required_certifications []:  [SALES_CERT_A · vence 2025-06-01 ⚠]
  │   ├── ▶ policy_acknowledgments []:  [☑ ISO 27001 · ☑ PCI DSS · ☐ GDPR refresher]
  │   └── ▶ risk_assessment:  🟢 LOW (score: 0.15)
  │
  └── 🔄 14. CICLO DE VIDA (lifecycle_automation) 👁 + ✏
      ├── Provisioning
      │   ├── source:          SCIM 2.0
      │   ├── method:          AUTO
      │   ├── status:          🟢 PROVISIONED
      │   └── ▶ auto_provisioned_resources []:  [KC, Tryton, Superset]
      ├── Deprovisioning
      │   ├── method:          DISABLE (on termination)
      │   ├── grace_period_days: 30
      │   └── ▶ steps []:  [1. Revocar sesiones, 2. Desactivar KC, 3. Archivar datos]
      ├── Reactivación
      │   ├── allowed:            ☑
      │   ├── requires_approval:  ☑
      │   ├── max_inactive_days:  365
      │   └── reverify_identity:  ☑
      └── Sync State 👁
          ├── sync_status:  🟢 SYNCED
          ├── kc_user_id:   kc-usr-001
          └── tryton_user_id: 1547

  LEYENDA VISUAL DEL ÁRBOL:
  ├── ▶ Rama expandible (con hijos)
  ├── 📋 Rama de solo lectura 👁
  ├── ✏ Rama editable
  ├── 🔒 Dato PII protegido (máscara + control de acceso)
  ├── 🔑 Dato RESTRICTED (solo roles específicos)
  ├── [➕]  Abre modal con catálogo para agregar item a array
  ├── [🔍] Buscador de entidades (usuarios, roles, etc.)
  └── ⚠   Alerta/conflicto detectado

  INTERACCIONES:
  - Click en ▶/▼: expandir/colapsar rama
  - Click en valor: edición inline (texto, número, fecha, select)
  - Click en [➕]: modal con catálogo filtrado desde BD
  - Click derecho en rama: menú contextual (Duplicar, Ver JSONB, Validar, Copiar)
  - Doble click en objeto JSON: expandir a editor JSON completo
  - Campos 🔒: valor enmascarado (****), hover muestra tooltip con nivel de acceso requerido
  - Campos 👁: deshabilitados, tooltip "Sincronizado desde Keycloak — solo lectura"
-->
```

### F4. FORMULARIO — Rol (ÁRBOL JERÁRQUICO · 16 Bloques · RolTemplate v6.0)

```html
<!-- @dsCard group="Formularios CRUD Jerárquicos" -->
<!--
  REGLA FUNDAMENTAL (BAUTH-CRUD-ROLES-USUARIOS.md §3):
  "El admin NO llena formularios planos. Navega un ÁRBOL JERÁRQUICO.
   Cada dominio es una rama. Cada rama tiene sub-ramas. Cada hoja es un átomo."

  ARQUITECTURA DE ALMACENAMIENTO:
    Identity (idn_role_template)
      └── template JSONB
           ├── Sección (ej: logical_access)
           │    ├── Política (ej: requiredMethods)
           │    │    ├── Rule (method, order, required)
           │    │    └── Rule
           │    └── Política (ej: zones)
           │         └── Zona → App → Módulo → Verbo → Átomo (checkbox)
           ├── Sección (ej: financial)
           │    ├── Política (transactionTypes)
           │    │    └── Rule (code, riskLevel, limit)
           │    └── Política (approvalChain)
           │         └── Rule (tier, amount, approvers)
           └── ... 14-16 secciones

  ÁRBOL COMPLETO (16 secciones · ~600 atributos):

  🔑 ROL: CAJERO (BIZ_N3) · v6.0.0
  │
  ├── 📋 0. IDENTIDAD DEL ROL (role) — bloque cabecera
  │   ├── Datos Básicos ✏
  │   │   ├── id *:              [ROL-ORG-CAJ________] regex: ^[A-Z]+-[0-9]{3}$
  │   │   ├── parent_id:         [ROL-ORG-VEND-JUNIOR ▼] (herencia H-RBAC)
  │   │   ├── type_id:           [TYPE-OPERATIVO-CAJA___________]
  │   │   ├── hierarchy_level *: [4____________] (1=C-Level ... 5=Operativo)
  │   │   └── path_ids:          ["ROL-ORG-VEND-JUNIOR", "ROL-ORG-CAJ"] (auto)
  │   ├── Clasificación ✏
  │   │   ├── tier *:            [BIZ_N3 ▼] (SU, SYS, BIZ_N1-N5, EXT_N0, M2M, VISITANTE)
  │   │   ├── status *:          [PUBLICADO ▼] (DEFINIDO→...→PUBLICADO→DEPRECADO→RETIRADO)
  │   │   └── version *:         [6.0.0__________] SemVer
  │   ├── Nombre Multilenguaje ✏
  │   │   ├── name.es *:         [Cajero_________________________]
  │   │   ├── name.en *:         [Cashier________________________]
  │   │   ├── name.pt *:         [Caixa__________________________]
  │   │   ├── description.es *:  [Rol de cajero con acceso a POS_]
  │   │   ├── description.en:    [Cashier role with POS access___]
  │   │   └── description.pt:    [Função de caixa com acesso a___]
  │   ├── Metadatos ✏
  │   │   ├── department *:       [Caja__________________________]
  │   │   ├── cost_center *:      [CAJA-CENTRAL__________________]
  │   │   ├── region:             [CENTRAL_______________________]
  │   │   ├── territory_code:     [CAJA-CENTRAL-001______________]
  │   │   ├── job_family:         [Caja__________________________]
  │   │   ├── job_level:          [O3___] (I1-I5, M1-M5, D1-D3)
  │   │   ├── max_subordinates:   0
  │   │   ├── required_certifications: [] [➕]
  │   │   ├── reporting_line:     [OPERACIONES___________________]
  │   │   └── classification:     [INTERNAL ▼] (CONFIDENTIAL, RESTRICTED, INTERNAL, PUBLIC)
  │   ├── Seguridad Base ✏
  │   │   ├── loa_required *:    [2___] (1-4, AAL1-AAL3)
  │   │   ├── mfa_required *:    ☑
  │   │   ├── step_up_enabled:   ☑ (RFC 9470)
  │   │   ├── max_sessions:      1
  │   │   ├── session_timeout:   28800 seg (8h)
  │   │   └── audit_level:       [basic ▼] (none, basic, full)
  │   ├── Vigencia (validity_period) ✏
  │   │   ├── type:              [INDEFINITE ▼] (FIXED, INDEFINITE, PROJECT_BASED)
  │   │   ├── start_date:        2026-01-01
  │   │   ├── end_date:          null (indefinido)
  │   │   ├── review_date:       2026-07-01
  │   │   ├── ▶ renewal_settings
  │   │   │   ├── renewable:       ☑
  │   │   │   ├── max_renewals:    2
  │   │   │   ├── renewal_duration_days: 365
  │   │   │   ├── auto_renewal:    ☐
  │   │   │   └── renewal_approval_roles: [DIRECTOR_VENTAS, COMPLIANCE_OFFICER]
  │   │   └── ▶ early_termination
  │   │       ├── allowed:            ☑
  │   │       ├── requires_approval:  ☑
  │   │       ├── approver_roles:     [DIRECTOR_VENTAS, HR_DIRECTOR]
  │   │       ├── notice_period_days: 5
  │   │       └── documentation:      mandatory
  │   ├── Flujo de Aprobación (approval_workflow) ✏
  │   │   ├── required_approvers:  2
  │   │   ├── approver_roles:      [DIRECTOR_VENTAS, CFO] [➕]
  │   │   ├── notification_channel: [rocket_chat ▼]
  │   │   ├── sla_hours:           48
  │   │   ├── escalation_after_hours: 24
  │   │   └── escalation_to:       [CISO, CEO] [➕]
  │   └── Firma Digital (digital_signature) 👁
  │       ├── signature:              base64_EdDSA
  │       ├── algorithm:              EdDSA_Ed25519
  │       ├── certificate_thumbprint: sha256:abc123...
  │       ├── post_quantum_planned:   CRYSTALS-Dilithium
  │       └── validity:               2026-06-20 → 2027-06-20
  │
  ├── 💻 1. D1 — ACCESO LÓGICO (logical_access) · ~200 atributos
  │   ├── ▶ Métodos Disponibles (availableMethods) 👁 catálogo
  │   │   ├── 🔑 PASSWORD
  │   │   │   ├── loaMin:1 loaMax:2 | phishing_resistant:☐ | device_bound:☐
  │   │   │   ├── min_length:12 | max_age_days:null | hibp_check:☑
  │   │   │   └── can_be_primary:☑ | can_be_fallback:☐ | recovery_eligible:☐
  │   │   ├── 🔑 TOTP
  │   │   │   ├── loaMin:2 loaMax:3 | phishing_resistant:☐ | device_bound:☑
  │   │   │   └── step_seconds:30 | digits:6 | algorithm:SHA1
  │   │   ├── 🔑 WEBAUTHN_PWDLESS
  │   │   │   ├── loaMin:2 loaMax:3 | phishing_resistant:☑ | device_bound:☑
  │   │   │   └── attestation:direct | user_verification:required | resident_key:☑
  │   │   ├── 🔑 PASSKEY_DEVICE
  │   │   │   ├── loaMin:3 loaMax:3 | phishing_resistant:☑ | device_bound:☑
  │   │   │   └── attestation:direct | user_verification:required
  │   │   ├── 🔑 SMARTCARD_X509 (mTLS)
  │   │   ├── 🔑 FIDO2_CTAP
  │   │   ├── 🔑 HOTP
  │   │   ├── 🔑 EMAIL_OTP
  │   │   ├── 🔑 RECOVERY_CODES
  │   │   ├── 🔑 MAGIC_LINK
  │   │   ├── 🔑 CIBA_DECOUPLED
  │   │   ├── 🔑 OAUTH_M2M
  │   │   ├── 🔑 SAML_BROKERED
  │   │   └── 🔑 QR_PHYSICAL
  │   ├── ▶ Flujos Requeridos (requiredMethods) ✏
  │   │   ├── standard_login
  │   │   │   ├── [1] PASSWORD           (required:☑)
  │   │   │   └── [2] TOTP               (required:☑)
  │   │   ├── elevated_login
  │   │   │   ├── [1] PASSWORD           (required:☑)
  │   │   │   └── [2] WEBAUTHN_PWDLESS   (required:☑)
  │   │   ├── hardware_protected_login
  │   │   │   ├── [1] PASSKEY_DEVICE     (required:☑)
  │   │   │   └── [2] TOTP               (required:☑)
  │   │   ├── financial_high_value
  │   │   │   ├── [1] WEBAUTHN_PWDLESS   (required:☑)
  │   │   │   └── [2] TOTP               (required:☑)
  │   │   ├── system_config_change
  │   │   │   └── [1] PASSKEY_DEVICE     (required:☑)
  │   │   ├── m2m_service_account
  │   │   │   └── [1] OAUTH_M2M          (required:☑)
  │   │   └── decoupled_external
  │   │       └── [1] CIBA_DECOUPLED     (required:☑)
  │   ├── ▶ Métodos Alternativos (alternativeMethods) ✏ [➕]
  │   │   └── Si TOTP no disponible → HOTP (max 5 usos/día, requiere aprobación)
  │   ├── ▶ Step-Up Rules ✏ [➕]
  │   │   ├── FIN-APPROVE:     trigger=financial_approve → LoA 3, maxAge 300s
  │   │   ├── SYSTEM-CONFIG:   trigger=system_config_change → LoA 3
  │   │   ├── USER-MGMT:       trigger=user_management → LoA 3
  │   │   ├── DATA-EXPORT:     trigger=data_export → LoA 3
  │   │   ├── DELEGATION-CREATE: trigger=delegation_create → LoA 3
  │   │   └── SOD-OVERRIDE:    trigger=sod_override → LoA 3
  │   ├── ▶ Zonas de Negocio ✏ [➕ Agregar zona del catálogo]
  │   │   └── 📁 AREA-CAJA (zoneCode: ZN-CASHIER, scope: LOCAL)
  │   │       ├── verbs: [READ, WRITE, APPROVE, EXECUTE] ☑/☐
  │   │       ├── restrictions
  │   │       │   ├── maxRecordLimit: 1000
  │   │       │   ├── dataClassification: [PUBLIC, INTERNAL, CONFIDENTIAL]
  │   │       │   └── piiAccess: ☐ | maskingPolicy: FULL_MASK
  │   │       ├── ▶ Aplicaciones [➕ Agregar app del catálogo]
  │   │       │   └── 📱 Tryton
  │   │       │       ├── ▶ Módulos [➕]
  │   │       │       │   └── 📦 sale_pos
  │   │       │       │       ├── ☑ READ   (átomo POS-1)
  │   │       │       │       ├── ☑ WRITE  (átomo POS-2)
  │   │       │       │       └── ☐ EXEC   (átomo POS-3)
  │   │       │       ├── ▶ Menús visibles [➕]: [menu_sale_orders, menu_pos]
  │   │       │       ├── ▶ Acciones visibles [➕]: [action_confirm_sale, action_cancel]
  │   │       │       ├── ▶ Campos ocultos [➕]: [margin, cost_price]
  │   │       │       ├── ▶ Campos solo-lectura [➕]: [warehouse_id]
  │   │       │       └── ▶ Reglas de Botones [➕]
  │   │       │           └── sale_order.confirm
  │   │       │               ├── condition_pyson: Eval('state') == 'draft'
  │   │       │               ├── users_required: 1
  │   │       │               └── step_up_loa: null
  │   │       ├── ▶ Reglas de Registro [➕]
  │   │       │   └── sale_order: domain=[('shop.region','=',user.region)]
  │   │       ├── limit_tier: 2 (hasta $10,000)
  │   │       ├── sod_cannot_also: zone_financial/ventas:AUDIT
  │   │       └── requires_dual_approval_above: 5000
  │   ├── ▶ Capas Tryton (trytonPrivileges) ✏
  │   │   ├── Capa 1 — modelAccess (25+ modelos)
  │   │   │   ├── sale.order:       [☑read ☑write ☑create ☐delete]
  │   │   │   ├── account.invoice:  [☑read ☑write ☐create ☐delete]
  │   │   │   └── ...
  │   │   ├── Capa 2 — visibleActions: [22 acciones] ☑/☐
  │   │   ├── Capa 3 — fieldOverrides: [17 campos] ☑/☐
  │   │   ├── Capa 4 — buttonRules: [6 reglas con PYSON]
  │   │   └── Capa 5 — recordRules: [4 reglas SQL]
  │   ├── Control Temporal ✏
  │   │   ├── enabled: ☑
  │   │   ├── schedule_type: SPECIFIC_DAYS
  │   │   ├── timezone: America/La_Paz
  │   │   └── ▶ allowed_days [] [➕]
  │   │       └── LUNES: [08:00-12:00, 14:00-18:00]
  │   └── Gestión de Sesiones ✏
  │       ├── max_session_duration_s: 28800 (8h)
  │       ├── inactivity_timeout_s: 900 (15min)
  │       ├── concurrent_sessions_allowed: ☐
  │       └── force_logout_at_end_shift: ☑
  │
  ├── 🏢 2. D2 — ACCESO FÍSICO (physical_access)
  │   ├── enabled: ☑
  │   ├── ▶ Métodos físicos [➕]
  │   │   ├── QR_DYNAMIC | NFC_MIFARE_DESFIRE | NFC_MIFARE_CLASSIC
  │   │   ├── FINGERPRINT_HASH | FACE_HASH | IRIS_HASH
  │   │   ├── SMARTCARD_X509 | PIN_PAD | RFID_125KHZ
  │   │   └── [➕ Agregar método]
  │   ├── ▶ requiredMethods por área ✏
  │   │   ├── standard_areas:    [QR_DYNAMIC, NFC_MIFARE_DESFIRE]
  │   │   ├── restricted_areas:  [FINGERPRINT_HASH + PIN_PAD]
  │   │   └── critical_areas:    [FACE_HASH + SMARTCARD_X509]
  │   ├── ▶ Zonas Físicas ✏ [➕ Agregar zona del catálogo]
  │   │   └── 🏢 EDIFICIO-CENTRAL
  │   │       └── 📍 PISO-1
  │   │           └── 🚪 ZONA-CAJA (security_level: 2, category: EMPLOYEE)
  │   │               ├── access_level: FULL
  │   │               ├── schedule: Lun-Vie 8-18
  │   │               ├── requires_escort: ☐
  │   │               ├── requires_two_person: ☐
  │   │               └── ▶ Puntos de Acceso [➕]: [LECTOR-PUERTA-01]
  │   ├── Controles de Seguridad ✏
  │   │   ├── two_person_rule: ☐
  │   │   ├── mantrap_required: ☐
  │   │   ├── duress_code: ☐
  │   │   └── anti_passback_global: ☑
  │   ├── ▶ Política Biométrica ✏
  │   │   ├── mode: HYBRID (admin_only | self_service | hybrid)
  │   │   ├── supervisor_required: ☑
  │   │   ├── liveness_required: ☑
  │   │   ├── hash_algorithm: Argon2id (t=3, m=64MB)
  │   │   └── fmr_threshold: 1:10000
  │   └── ▶ Emergency Override ✏
  │       ├── allowed: ☐
  │       ├── triggers: [FIRE_ALARM, MEDICAL_EMERGENCY, SECURITY_BREACH, POWER_OUTAGE]
  │       └── requires_approval: ☑
  │
  ├── 💰 3. D3 — FINANCIERO (financial)
  │   ├── enabled: ☑
  │   ├── ▶ Tipos de Transacción ✏ [➕]
  │   │   ├── FAC_EMITIR (VENTAS, ALTO)
  │   │   │   ├── standard_limit: $2,000
  │   │   │   ├── requires_dual_approval: ☑ (above: $5,000)
  │   │   │   └── requires_step_up: ☑ → LoA 3
  │   │   ├── FAC_ANULAR (VENTAS, CRÍTICO)
  │   │   ├── COBRO_RECIBIR (COBROS, MEDIO)
  │   │   ├── NC_EMITIR (VENTAS, ALTO)
  │   │   ├── APERTURA_CAJA (CAJA, BAJO)
  │   │   └── CIERRE_CAJA (CAJA, ALTO)
  │   ├── ▶ Límites ✏
  │   │   ├── per_transaction_limit: $2,000
  │   │   ├── daily_limit:           $10,000
  │   │   ├── weekly_limit:          $40,000
  │   │   ├── monthly_limit:         $50,000
  │   │   ├── annual_limit:          $500,000
  │   │   ├── requires_dual_approval_above: $5,000
  │   │   └── currency: BOB
  │   ├── ▶ Cadena de Aprobación ✏
  │   │   ├── Tier 1: hasta $1,000 → 1 aprobador (SUPERVISOR)
  │   │   ├── Tier 2: hasta $10,000 → 2 aprobadores (SUPERVISOR + GERENTE)
  │   │   ├── Tier 3: hasta $100,000 → 3 aprobadores (+ DIRECTOR)
  │   │   └── Tier 4: > $100,000 → 4 aprobadores (+ CFO)
  │   ├── ▶ Reglas SoD ✏ [➕]
  │   │   ├── FAC-CREATE-APPROVE: severity=CRITICAL
  │   │   ├── FAC-CREATE-ANULAR: severity=HIGH
  │   │   ├── COBRO-CONCILIAR: severity=MEDIUM
  │   │   ├── CAJA-APERTURA-CIERRE: severity=HIGH
  │   │   └── VENTAS-AUDITORIA: severity=CRITICAL
  │   └── ▶ Compliance SIN Bolivia ✏
  │       ├── country: BO
  │       ├── tax_authority: SIN
  │       ├── digital_signature_required: ☑
  │       └── algorithm: EDDSA_ED25519
  │
  ├── 🕐 4. D4 — TEMPORAL → [similar: schedule, shifts, overtime, breaks, attendance]
  ├── 🧬 5. D5 — BIOMÉTRICO → [similar: fingerprint, face, iris, liveness, FMR, GDPR]
  ├── 🌍 6. D6 — GEOESPACIAL → [similar: countries, geo-fences, velocity, trust tiers]
  ├── 🌐 7. D7 — RED → [similar: CIDRs, VPN, mTLS, device trust, ZTNA, segmentation]
  ├── 🔗 8. D8 — CONTEXTO → [similar: ctx_id scope, session TTL, CAEP events, risk]
  ├── 🔐 9. D9 — CREDENCIALES → [similar: password policy, MFA, recovery, lockout, rotation]
  ├── 🔄 10. D10 — DELEGACIÓN → [similar: can_delegate, target_roles, duration, audit]
  ├── 📋 11. D11 — AUDITORÍA → [similar: level, retention, events, frameworks, review]
  ├── ⛓ 12. D12 — BLOCKCHAIN → [similar: merkle, DID, besu, anchoring frequency]
  │
  ├── 🔒 13. SEGURIDAD (security) ✏
  │   ├── ▶ key_inventory [] 👁 (desde sec_key_inventory)
  │   │   └── 🔑 JWT_SIGNING · EdDSA · Vault · 🟢 ACTIVE
  │   ├── ▶ crypto_algorithms [] 👁 (desde bos_crypto_algorithm)
  │   ├── sod_validation: [REAL_TIME ▼]
  │   └── security_zone: 3 (1-5)
  │
  ├── ⚖ 14. COMPLIANCE (compliance) ✏
  │   ├── ▶ frameworks: [ISO27001, NIST800-53, PCI-DSS, GDPR, SOX]
  │   ├── gdpr_consent
  │   │   ├── data_processing: ☑
  │   │   ├── marketing: ☐
  │   │   └── third_party: ☐
  │   ├── ▶ data_subject_rights (6 derechos)
  │   ├── data_retention_days: 2555
  │   ├── breach_notification_hours: 72
  │   ├── compliance_status: full
  │   └── controls_implemented/total: 18/20
  │
  ├── 🔄 15. SYNC (sync_metadata) 👁 SOLO LECTURA
  │   ├── sync_status: 🟢 SYNCED
  │   ├── last_sync_at: 2026-06-28T14:32:00Z
  │   ├── ▶ keycloak
  │   │   ├── composite_role: ROL-ORG-CAJ
  │   │   ├── auth_flow_browser: sbos-webauthn-2fa
  │   │   ├── mfa_required: ☑
  │   │   └── status: 🟢 SYNCED
  │   └── ▶ tryton
  │       ├── group_name: ROL-ORG-CAJ
  │       ├── ir_model_access: 25 modelos configurados
  │       └── status: 🟢 SYNCED
  │
  └── ⚠ 16. CONFLICTOS (conflict_management) 👁 + ✏
      ├── ▶ segregation_of_duties
      │   ├── ▶ incompatible_roles [] [➕]
      │   │   └── ⚠ ROL-ORG-AUDITOR · severity: CRITICAL · mitigation: DENY
      │   └── ▶ incompatible_functions [] [➕]
      │       └── ⚠ FAC_EMITIR:CREATE vs FAC_EMITIR:APPROVE · severity: CRITICAL
      ├── ▶ conflict_validation
      │   ├── check_frequency: REAL_TIME
      │   └── validation_scope: [DIRECT, INHERITED, DELEGATION]
      └── ▶ interest_conflicts
          ├── ▶ restricted_entities [] [➕]
          └── declaration_requirements: ANNUAL

  INTERACCIÓN CON CATÁLOGOS (MODALES):
  - [➕ Agregar zona]: abre modal con 29 zonas de log_zone
  - [➕ Agregar app]: abre modal con 12 apps de privilege_application
  - [➕ Agregar método]: abre modal con 32 métodos de ath_method
  - [➕ Agregar regla SoD]: abre modal con reglas de fin_sod_rule
  - [➕ Agregar país]: abre modal con 196 países de global_country
  Cada modal muestra: ☑ checkbox · nombre · descripción · referencia estándar · preview JSONB

  MENÚ CONTEXTUAL (click derecho en cualquier nodo):
  ✏ Editar · 📋 Duplicar · 🗑 Eliminar · 📄 Ver JSONB · 📋 Copiar config
  ▼ Expandir todos · ▶ Colapsar todos · ☑ Marcar todos · ☐ Desmarcar todos
  ⚠ Validar conflictos SoD · 📊 Ver impacto en BitMask

  FLUJO CRUD (6 pasos):
  1. POST /bauth/role {template_code, domain} → 201 {role_id, template}
  2. Expandir rama D1 → GET /bauth/role/catalog/D1 → zonas, apps, verbos
  3. Guardar sección → PUT /bauth/role/{id}/section/D1 {section_data}
  4. Repetir para D2-D12
  5. Preview → GET /bauth/role/{id}/preview → 14 secciones JSONB
  6. Publicar → POST /bauth/role/{id}/publish → sync KC+Tryton
-->
```

### F5. FORMULARIO — Punto de Venta SIN Bolivia (org_pos_logico · Facturación Electrónica)

```html
<!-- @dsCard group="Formularios CRUD" -->
<!--
  ESPECIFICACIÓN COMPLETA según SIN RND 102100000011, Ley 164 Bolivia,
  ADSIB-FD-POLT-015 v2.3, y RND 10.0021.16.

  ┌── 🖥 PUNTO DE VENTA — CONFIGURACIÓN SIN BOLIVIA ─────────┐
  │                                                           │
  │  [1📋 REGISTRO] [2📄 DOSIF.] [3🔑 CÓDIGOS] [4📝 LEYENDAS]│
  │  [5🏭 CAEB] [6🌐 CONEXIÓN SIN] [7🖥 DISPOSITIVO]         │
  │                                                           │
  │  ─── 1. REGISTRO SIN ─────────────────────────────────── │
  │  ┌─────────────────────────────────────────────────────┐  │
  │  │  Empresa *               Sucursal *                 │  │
  │  │  [Comercializadora ▼]    [Central — La Paz ▼]      │  │
  │  │                                                     │  │
  │  │  Nombre del POS *                                   │  │
  │  │  [___Caja Principal — La Paz____________________]   │  │
  │  │                                                     │  │
  │  │  Nº Punto de Venta *     Código Sucursal SIN *      │  │
  │  │  [___1_______________]   [___001________________]    │  │
  │  │  ⓘ Secuencial por       ⓘ Asignado por el SIN      │  │
  │  │  sucursal (1-9999)       en el Padrón Nacional       │  │
  │  │                                                     │  │
  │  │  Modalidad de Facturación *                          │  │
  │  │  ● COMPUTARIZADA EN LÍNEA  (SFV - Software Propio)  │  │
  │  │  ○ ELECTRÓNICA EN LÍNEA    (SFE - Factura XML c/firma│  │
  │  │  ○ PORTAL WEB              (SIAT - Ingreso manual)   │  │
  │  │  ⓘ Según RND 102100000011. Asignada por SIN según   │  │
  │  │    perfil del contribuyente                          │  │
  │  │                                                     │  │
  │  │  Ambiente SIN *           Tipo Factura Principal *   │  │
  │  │  [PRODUCCION ▼]           [FACTURA_CREDITO_FISCAL ▼]│  │
  │  │  PRUEBAS / PRODUCCION     (27 tipos fiscales SIN)    │  │
  │  └─────────────────────────────────────────────────────┘  │
  │                                                           │
  │  ─── 2. DOSIFICACIÓN (RND 10.0021.16, Art. 16) ──────── │
  │  ┌─────────────────────────────────────────────────────┐  │
  │  │  Nº Autorización SIN *                               │  │
  │  │  [___1234567890_________________________________]    │  │
  │  │  ⓘ Número otorgado por el SIN al activar dosif.     │  │
  │  │                                                     │  │
  │  │  Tipo Dosificación *     Estado Actual              │  │
  │  │  [POR_TIEMPO ▼]          [PENDIENTE ▼]              │  │
  │  │  POR_TIEMPO: vence en    PENDIENTE → ACTIVA →       │  │
  │  │    fecha fija            VENCIDA / AGOTADA / REVOCADA│  │
  │  │  POR_CANTIDAD: vence     ⓘ Se actualiza solo vía    │  │
  │  │    al agotar rango       WebService del SIN          │  │
  │  │                                                     │  │
  │  │  Fecha Límite Emisión *  Fecha Activación            │  │
  │  │  [___2027-06-25_______]  [___2026-06-28__________]   │  │
  │  │  ⓘ Si POR_TIEMPO: fecha  Cuándo el SIN activó la    │  │
  │  │    máxima para emitir     dosificación               │  │
  │  │                                                     │  │
  │  │  ─── RANGO DE FACTURACIÓN ───                       │  │
  │  │  Nº Desde *               Nº Hasta *                 │  │
  │  │  [___1000001___________]  [___2000000___________]    │  │
  │  │                                                     │  │
  │  │  Nº Actual (próximo a emitir)                        │  │
  │  │  [___1000150___________]  ⓘ Auto-incrementado       │  │
  │  │  ⚠ El rango NO se reutiliza. Facturas anuladas       │  │
  │  │    NO liberan el número (SIN RND 102100000011)       │  │
  │  └─────────────────────────────────────────────────────┘  │
  │                                                           │
  │  ─── 3. CÓDIGOS FISCALES SIN ────────────────────────── │
  │  ┌─────────────────────────────────────────────────────┐  │
  │  │                                                     │  │
  │  │  ┌── CUIS: Código Único de Iniciación de Sistemas ─┐│  │
  │  │  │  [___ABC123DEF456GHI789_______________________]  ││  │
  │  │  │  Otorgado: [___2026-01-15 08:00_______________]  ││  │
  │  │  │  ⓘ Identifica al contribuyente + su sistema.    ││  │
  │  │  │    Se obtiene UNA vez al iniciar operaciones.   ││  │
  │  │  │    Cambia solo si se reinstala el sistema.      ││  │
  │  │  └─────────────────────────────────────────────────┘│  │
  │  │                                                     │  │
  │  │  ┌── CUFD: Código Único de Facturación Diaria ─────┐│  │
  │  │  │  [___DEF456GHI789JKL012_______________________]  ││  │
  │  │  │  Otorgado: [___2026-06-28 00:05_______________]  ││  │
  │  │  │  Vigencia:  [___2026-06-29 00:05_______________]  ││  │
  │  │  │  ⓘ Se renueva CADA 24 HORAS (00:05 AM BOT).    ││  │
  │  │  │    Sin CUFD vigente NO se puede emitir facturas. ││  │
  │  │  │    bAuth lo renueva automáticamente vía WS SIN.  ││  │
  │  │  └─────────────────────────────────────────────────┘│  │
  │  │                                                     │  │
  │  │  ┌── CAFC: Código Autorización Facturación Comput. ─┐│  │
  │  │  │  [___GHI789JKL012MNO345_______________________]  ││  │
  │  │  │  Vigencia:  [___2027-06-25____________________]  ││  │
  │  │  │  ⓘ Solo para modalidad COMPUTARIZADA_EN_LINEA.  ││  │
  │  │  │    Autoriza la generación del CUF (módulo 11).   ││  │
  │  │  └─────────────────────────────────────────────────┘│  │
  │  │                                                     │  │
  │  │  ⓘ CUF (Código Único de Factura) se genera por cada │  │
  │  │    factura: algoritmo módulo 11 + Base 16, 28 chars.│  │
  │  │    No se almacena aquí — es efímero por factura.     │  │
  │  └─────────────────────────────────────────────────────┘  │
  │                                                           │
  │  ─── 4. LEYENDAS LEGALES OBLIGATORIAS ────────────────── │
  │  ┌─────────────────────────────────────────────────────┐  │
  │  │  Leyenda SIN * (RND 102100000011)                    │  │
  │  │  [___ESTA FACTURA CONTRIBUYE AL DESARROLLO DEL PAIS_│  │
  │  │   ___EL USO ILICITO SERA SANCIONADO PENALMENTE_____] │  │
  │  │  ⓘ Texto exacto requerido por SIN en toda factura   │  │
  │  │                                                     │  │
  │  │  Leyenda Derechos Consumidor (Ley Nº 453)            │  │
  │  │  [___EL CONSUMIDOR TIENE DERECHO A..._____________]  │  │
  │  │                                                     │  │
  │  │  Leyenda Representación Gráfica                      │  │
  │  │  [___ESTE DOCUMENTO ES UNA REPRESENTACION VISUAL...] │  │
  │  │  ⓘ Solo visible en PDF/impresión, no en el XML      │  │
  │  │                                                     │  │
  │  │  Leyenda Crédito Fiscal (Ley Nº 317, gasolineras)    │  │
  │  │  [_______________________________________________]  │  │
  │  │  ⓘ Solo para estaciones de servicio                 │  │
  │  └─────────────────────────────────────────────────────┘  │
  │                                                           │
  │  ─── 5. ACTIVIDAD ECONÓMICA CAEB ────────────────────── │
  │  ┌─────────────────────────────────────────────────────┐  │
  │  │  Código CAEB *            Descripción               │  │
  │  │  [___62010_____________]  [___Programación infor___] │  │
  │  │  ⓘ Clasificador de      ⓘ Auto-completado del       │  │
  │  │    Actividades Econ.       catálogo CAEB SIN          │  │
  │  │    de Bolivia (SIN)                                    │  │
  │  └─────────────────────────────────────────────────────┘  │
  │                                                           │
  │  ─── 6. CONEXIÓN WEBSERVICE SIN ─────────────────────── │
  │  ┌─────────────────────────────────────────────────────┐  │
  │  │  URL WebService SIN *                                 │  │
  │  │  [___https://pilotosi.impuestos.gob.bo/servicios___]  │  │
  │  │  ⓘ PRODUCCION:  https://siat.impuestos.gob.bo        │  │
  │  │    PRUEBAS:     https://pilotosi.impuestos.gob.bo     │  │
  │  │                                                     │  │
  │  │  Token Autenticación SIN   Certificado ADSIB *       │  │
  │  │  [___••••••••••••••••••]   [🔍 SELECCIONAR EN VAULT]  │  │
  │  │  ⓘ Se guarda en Vault      ⓘ RSA-SHA256 Persona      │  │
  │  │    path: sin/{pos_id}         Jurídica (Ley 164)      │  │
  │  │                                                     │  │
  │  │  ─── ESTADO CONEXIÓN (solo lectura) ───              │  │
  │  │  Último Heartbeat:  [___2026-06-28 14:32_________]   │  │
  │  │  Errores conexión:  [___0_________________________]   │  │
  │  │  Estado: 🟢 CONECTADO — 0 errores en 24h              │  │
  │  │  [🧪 PROBAR CONEXIÓN AL SIN]                          │  │
  │  └─────────────────────────────────────────────────────┘  │
  │                                                           │
  │  ─── 7. DISPOSITIVO FÍSICO VINCULADO ────────────────── │
  │  ┌─────────────────────────────────────────────────────┐  │
  │  │  Device ID *              Hostname                   │  │
  │  │  [___DEV-POS-001_______]  [___pos-caja-01_________]  │  │
  │  │                                                     │  │
  │  │  Dirección IP             Dirección MAC               │  │
  │  │  [___192.168.1.45______]  [___AA:BB:CC:DD:EE:FF___]  │  │
  │  │                                                     │  │
  │  │  Nodo Kubernetes          Geolocalización             │  │
  │  │  [___node-lpz-03_______]  [___-16.4955,-68.1336____]  │  │
  │  │                                                     │  │
  │  │  Vinculado en: [___2026-06-28 08:00_______________]   │  │
  │  │  Estado: 🟢 ACTIVO                                     │  │
  │  │  ⓘ Cambiar el dispositivo requiere re-CUIS ante SIN   │  │
  │  └─────────────────────────────────────────────────────┘  │
  │                                                           │
  │  ⚠ ADVERTENCIAS DE COMPLIANCE:                            │
  │  • Sin CUFD vigente → no se emiten facturas               │
  │  • Sin conexión al SIN → modo CONTINGENCIA (máx 48-72h)   │
  │  • La firma digital ADSIB es OBLIGATORIA para modalidad   │
  │    ELECTRONICA_EN_LINEA (Ley 164, RND 102100000011)       │
  │  • Datos fiscales deben residir en Bolivia (D6-JURISD.)   │
  │  • Retención de facturas: 8 años mínimo (Código Tributario│
  │                                                           │
  │  [CANCELAR]  [💾 GUARDAR BORRADOR]  [🖥 CREAR POS + SOLICITAR CUIS] │
  └───────────────────────────────────────────────────────────┘

  CAMPOS COMPLETOS (45 campos en 7 secciones):
  ┌──────────────────────────┬─────────────┬───────┬──────────────────────────────┐
  │ Campo                    │ Tipo        │ Req   │ Validación / Origen          │
  ├──────────────────────────┼─────────────┼───────┼──────────────────────────────┤
  │                          │ 1. REGISTRO SIN                                   │
  ├──────────────────────────┼─────────────┼───────┼──────────────────────────────┤
  │ empresa_id               │ select      │ SI    │ debe existir en org_empresa │
  │ sucursal_id              │ select      │ SI    │ filtrado por empresa_id      │
  │ nombre                   │ text        │ SI    │ min 3, max 100 chars         │
  │ numero_punto_venta       │ number      │ SI    │ 1-9999, único por sucursal   │
  │ codigo_sucursal_sin      │ text        │ SI    │ código Padrón SIN, 3 dígitos │
  │ modalidad_facturacion    │ radio       │ SI    │ ELECTRONICA_EN_LINEA,        │
  │                          │             │       │ COMPUTARIZADA_EN_LINEA,      │
  │                          │             │       │ PORTAL_WEB                   │
  │ ambiente_sin             │ select      │ SI    │ PRODUCCION, PRUEBAS          │
  │ tipo_factura             │ select      │ SI    │ 27 tipos fiscales SIN:       │
  │                          │             │       │ FACTURA_CREDITO_FISCAL,      │
  │                          │             │       │ FACTURA_SIN_DERECHO_CREDITO, │
  │                          │             │       │ NOTA_CREDITO_DEBITO,         │
  │                          │             │       │ FACTURA_EXPORTACION,         │
  │                          │             │       │ FACTURA_HIDROCARBUROS, ...   │
  ├──────────────────────────┼─────────────┼───────┼──────────────────────────────┤
  │                          │ 2. DOSIFICACIÓN (RND 10.0021.16 Art.16)           │
  ├──────────────────────────┼─────────────┼───────┼──────────────────────────────┤
  │ numero_autorizacion      │ text        │ SI    │ Nº otorgado por SIN          │
  │ tipo_dosificacion        │ radio       │ SI    │ POR_TIEMPO, POR_CANTIDAD     │
  │ estado_dosificacion      │ select      │ —     │ PENDIENTE,ACTIVA,VENCIDA,    │
  │                          │             │       │ AGOTADA,REVOCADA (readonly)  │
  │ fecha_solicitud_dosif    │ datetime    │ NO    │ cuándo se solicitó al SIN    │
  │ fecha_activacion_dosif   │ datetime    │ NO    │ cuándo el SIN la activó      │
  │ fecha_limite_emision     │ date        │ SI*   │ *obligatorio si POR_TIEMPO   │
  │ rango_inicio             │ bigint      │ SI    │ >0, primer nº del rango      │
  │ rango_fin                │ bigint      │ SI    │ >rango_inicio                │
  │ numero_actual            │ bigint      │ —     │ auto-increment, ≥rango_inicio│
  ├──────────────────────────┼─────────────┼───────┼──────────────────────────────┤
  │                          │ 3. CÓDIGOS FISCALES                               │
  ├──────────────────────────┼─────────────┼───────┼──────────────────────────────┤
  │ cuis                     │ text        │ SI    │ Código Único Iniciación Sist │
  │ cuis_otorgado_en         │ datetime    │ NO    │ timestamp otorgamiento CUIS  │
  │ cufd                     │ text        │ SI*   │ *obligatorio en PRODUCCION   │
  │ cufd_otorgado_en         │ datetime    │ NO    │ timestamp otorgamiento CUFD  │
  │ cufd_vigencia            │ datetime    │ NO    │ expira 24h después (00:05)   │
  │ cafc                     │ text        │ NO    │ solo modalidad COMPUTARIZADA │
  │ cafc_vigencia            │ date        │ NO    │ fecha vigencia CAFC          │
  ├──────────────────────────┼─────────────┼───────┼──────────────────────────────┤
  │                          │ 4. LEYENDAS LEGALES                               │
  ├──────────────────────────┼─────────────┼───────┼──────────────────────────────┤
  │ leyenda_sin              │ textarea    │ SI    │ default: "ESTA FACTURA       │
  │                          │             │       │ CONTRIBUYE AL DESARROLLO..." │
  │ leyenda_derechos_consum. │ textarea    │ NO    │ Ley Nº 453                   │
  │ leyenda_representacion   │ textarea    │ NO    │ default: "Este documento es  │
  │                          │             │       │ una representación visual..." │
  │ leyenda_credito_fiscal   │ textarea    │ NO    │ Ley Nº 317 (gasolineras)     │
  ├──────────────────────────┼─────────────┼───────┼──────────────────────────────┤
  │                          │ 5. ACTIVIDAD CAEB                                 │
  ├──────────────────────────┼─────────────┼───────┼──────────────────────────────┤
  │ caeb_codigo              │ text        │ SI    │ catálogo CAEB SIN Bolivia    │
  │ caeb_descripcion         │ text        │ —     │ auto-completado del catálogo │
  ├──────────────────────────┼─────────────┼───────┼──────────────────────────────┤
  │                          │ 6. CONEXIÓN WEBSERVICE SIN                        │
  ├──────────────────────────┼─────────────┼───────┼──────────────────────────────┤
  │ sin_wsdl_url             │ url         │ SI*   │ *obligatorio en COMP/EL      │
  │ sin_token                │ password    │ SI*   │ guardado en Vault            │
  │ sin_certificado_id       │ vault-ref   │ SI*   │ *obligatorio si ELECTRONICA  │
  │                          │             │       │ ref a ADSIB en Vault PKI     │
  │ ultimo_heartbeat_sin     │ datetime    │ —     │ readonly, actualiza bAuth    │
  │ sin_error_count          │ number      │ —     │ readonly, resetea cada 24h   │
  ├──────────────────────────┼─────────────┼───────┼──────────────────────────────┤
  │                          │ 7. DISPOSITIVO FÍSICO                             │
  ├──────────────────────────┼─────────────┼───────┼──────────────────────────────┤
  │ device_id                │ text        │ SI    │ ID único del dispositivo     │
  │ hostname                 │ text        │ NO    │ hostname del equipo          │
  │ ip                       │ ip          │ NO    │ dirección IP (formato INET)  │
  │ mac                      │ text        │ NO    │ MAC address (formato MACADDR)│
  │ nodo_k8s                 │ text        │ NO    │ nodo Kubernetes asignado     │
  │ geo                      │ text        │ NO    │ coordenadas "lat,lon"        │
  │ vinculado_en             │ datetime    │ NO    │ fecha vinculación hardware   │
  │ estado                   │ select      │ SI    │ ACTIVO, INACTIVO,            │
  │                          │             │       │ MANTENIMIENTO, BLOQUEADO_SIN │
  ├──────────────────────────┼─────────────┼───────┼──────────────────────────────┤
  │ pos_id                   │ hidden      │ —     │ auto: "POS-{sucursal}-{nro}"│
  └──────────────────────────┴─────────────┴───────┴──────────────────────────────┘

  VALIDACIONES CRÍTICAS:
  - numero_punto_venta: único dentro de (sucursal_id)
  - Si ambiente_sin=PRODUCCION: cuis, cufd, sin_wsdl_url OBLIGATORIOS
  - Si modalidad=ELECTRONICA_EN_LINEA: sin_certificado_id OBLIGATORIO (ADSIB)
  - Si modalidad=COMPUTARIZADA_EN_LINEA: cafc recomendado
  - rango_fin > rango_inicio
  - fecha_limite_emision > fecha_activacion_dosif > hoy (si POR_TIEMPO)
  - numero_actual dentro del rango [rango_inicio, rango_fin]
  - cufd_vigencia = cufd_otorgado_en + 24h (00:05 AM siguiente día)
  - Facturas ANULADAS no liberan el número (regla SIN)
  - Datos fiscales: residencia en Bolivia (D6-JURISDICTION)

  FLUJO DE ACTIVACIÓN SIN:
  1. Admin configura Datos Básicos + Registro SIN → [GUARDAR BORRADOR]
  2. Admin configura Dosificación + Códigos Fiscales → [SOLICITAR CUIS]
  3. bAuth invoca WebService SIN → obtiene CUIS → guarda en org_pos_logico
  4. bAuth programa renovación diaria de CUFD (cron 00:05 AM BOT)
  5. Admin configura CAEB + Leyendas → [ACTIVAR POS]
  6. POS listo → estado_dosificacion = ACTIVA
  7. Primera factura emitida → CUF generado (módulo 11 + Base 16, 28 chars)

  ALGORITMO CUF (referencia para bAuth, no se configura en este formulario):
  1. NIT emisor (12 dígitos, relleno izquierda con ceros)
  2. Fecha/hora emisión: YYYYMMDDHHmmssSSS (17 caracteres)
  3. Código sucursal SIN (3 dígitos)
  4. Modalidad (2 dígitos): 01=EL, 02=CL, 03=PW
  5. Tipo emisión (1 dígito): 1=online, 2=offline, 3=contingencia
  6. Tipo factura (2 dígitos): 01=CF, 02=SFDC, 03=NDC, etc.
  7. Tipo documento sector (2 dígitos)
  8. Número factura (10 dígitos, relleno con ceros)
  9. Punto de venta (4 dígitos, relleno con ceros)
  10. Dígito control módulo 11 → encode Base 16 → 2 caracteres finales
  TOTAL: 28 caracteres alfanuméricos únicos

  REFERENCIAS NORMATIVAS:
  - SIN RND 102100000011 (11/08/2021) — Marco legal SFV
  - SIN RND 102600000007 (25/03/2026) — Fecha límite 01/10/2026 grupos 9-12
  - SIN RND 10.0021.16 — Dosificación facturas (Art. 16)
  - Ley 164 Bolivia — Firma digital con validez jurídica
  - ADSIB-FD-POLT-015 v2.3 — Certificación digital Bolivia
  - Ley Nº 453 — Derechos del consumidor
  - Ley Nº 317 — Crédito fiscal gasolineras
  - Código Tributario Bolivia — Retención 8 años
-->
```

---

## 4. FLUJOS DE USUARIO PRINCIPALES

### 4.1 Flujo #1 — Primer contacto (TRIAL)
```
ABRIR APP → Pantalla Conexión → Conectar SSH → Dashboard → QUICKSTART
→ Wizard "Mi primer GetContext" (6 pasos, 3 minutos)
→ Token emitido + validado + acceso evaluado → Snippet copiado
→ "Tu app ya puede validar permisos con bAuth"
```

### 4.2 Flujo #2 — Explorar el catálogo
```
Dashboard → Tab Catálogo → Explorador de métodos
→ Click en bauth.token.issue → Editor pre-llenado
→ Click [▶ ENVIAR] → Respuesta en visor + Snippet generado
→ Bloque agregado a la cinta
```

### 4.3 Flujo #3 — Crear rol personalizado
```
Dashboard → Tab Labs → Creador de Plantillas
→ Elegir plantilla base (CAJERO) → Personalizar dominios
→ Guardar como CAJERO_MI_APP → Crear usuarios de prueba
→ Probar end-to-end → Copiar código de integración
```

### 4.4 Flujo #4 — Probar las 4 variantes de token
```
Dashboard → Tab Labs → Token Lab
→ Variante 1 (LIVIANO) → Emitir → Ver JWT decodificado
→ Variante 2 (+MASK) → Emitir → Ver RolBitMask (968 chars)
→ Variante 3 (+BLOCKCHAIN) → Emitir → Ver cadena de anclaje
→ Variante 4 (RS256) → Emitir → Ver JWT legacy
→ Copiar snippets para cada variante
```

### 4.5 Flujo #5 — Registro y Onboarding
```
ABRIR APP → Pantalla Conexión → Click "Crear cuenta gratuita"
→ Registro (3 pasos: datos personales + emprendimiento + intereses)
→ Email de verificación enviado → Click en link del email
→ bAuthDEV se abre → Tenant TRIAL creado automáticamente
→ Conexión SSH configurada → Dashboard con banner "🎉 ¡Bienvenido!"
→ Wizard "Mi primer GetContext" sugerido
→ Gerente de cuenta SBOS asignado → Email de bienvenida personalizado
```

### 4.6 Flujo #6 — Onboardear una empresa cliente
```
Dashboard → Tab "Mis Empresas" → Click [➕ NUEVA EMPRESA]
→ Completar: Razón Social, NIT, Régimen Fiscal, Ciudad
→ Empresa creada → Ver ficha de empresa con uso en 0
→ Click [🌐 SUCURSALES] → [➕ NUEVA SUCURSAL]
→ Completar: Nombre, Dirección, Ciudad, Horario
→ Sucursal creada → Click [👤 USUARIOS] → [➕ NUEVO USUARIO]
→ Asignar: username, email, rol (CAJERO), sucursal
→ Usuario creado → Entregar credenciales al cliente
→ Cliente empieza a usar la app → Métricas aparecen en Dashboard
```

### 4.7 Flujo #7 — Verificar quién usa tu sistema
```
Dashboard → Tab "Mi Negocio"
→ Ver métricas globales: 8 empresas, 847 usuarios, 234.5K eval/mes
→ Revisar "¿Quién usa tu sistema?": barras por empresa
→ Identificar Comercializadora del Valle: 45,678 eval (87% del límite)
→ Click en la barra → Drill-down: sucursales de Comercializadora
→ Central: 28,456 eval (60%) | Norte: 12,345 eval (26%) | Sur: 4,877 eval (10%)
→ Identificar sucursales con poca actividad
→ Ver "Empresas que necesitan atención": Transportes Andinos inactiva 5d
→ [💬 CONTACTAR CLIENTE] → sugerir reactivación
```

### 4.8 Flujo #8 — Cambiar de plan (TRIAL → PRO)
```
Dashboard → Tab "Mi Cuenta" → Sección Plan
→ Ver límites actuales: TRIAL, 23/50 usuarios (78%)
→ Click [ELEGIR] en PRO ($199/mes)
→ Modal: "Confirma tu cambio a PRO"
→ Resumen: 25 roles, 1,000 usuarios, 10 empresas, 8 dominios
→ [CONFIRMAR CAMBIO A PRO]
→ Tenant actualizado → plan_tier: PRO, subscription_status: ACTIVE
→ Dashboard refleja nuevos límites → Barras de uso bajan
→ Email: "Factura de $199 — primer mes"
```

---

## 5. ESTADOS GLOBALES DE LA APLICACIÓN

### 5.1 Estados de conexión

| Estado | Indicador | Color | Comportamiento |
|--------|-----------|-------|----------------|
| `connected` | 🟢 Conectado a bAuth v3.0.0 | `--color-success` | Todas las funciones habilitadas |
| `connecting` | 🟡 Conectando... | `--color-warning` | Spinner, funciones deshabilitadas |
| `disconnected` | 🔴 Sin conexión | `--color-error` | Solo pantalla de conexión |
| `reconnecting` | 🔄 Reconectando (intento 3/5) | `--color-warning` | Reintento automático con backoff |
| `degraded` | ⚠ Conexión degradada | `--color-warning` | Funciones limitadas, sin Labs |

### 5.2 Estados de tenant (plan contratado)

| Plan | Badge | Límites visibles |
|------|-------|-----------------|
| `TRIAL` | 🆓 TRIAL | 3 roles, 50 usuarios, 3 dominios, 1 empresa |
| `BASIC` | 💼 BASIC | 5 roles, 100 usuarios, 3 dominios, 1 empresa |
| `PRO` | 💎 PRO | 25 roles, 1,000 usuarios, 8 dominios, 10 empresas |
| `ENTERPRISE` | 🏢 ENTERPRISE | Ilimitado |

---

## 6. NAVEGACIÓN POR TECLADO (Accesibilidad Total)

```
┌──────────────────────────────────────────────────────────────────────┐
│  ATAJOS GLOBALES                                                     │
│  ──────────────────────────────────────────────────────────────────  │
│  Ctrl+K        → Búsqueda rápida de métodos                          │
│  Ctrl+Enter    → Enviar request actual                               │
│  Ctrl+Shift+F  → Formatear JSON en editor                            │
│  Ctrl+1..9     → Cambiar entre tabs principales                      │
│  Ctrl+[        → Colapsar panel izquierdo (explorador)               │
│  Ctrl+]        → Colapsar panel derecho (respuesta)                  │
│  Ctrl+Shift+C  → Copiar respuesta al portapapeles                    │
│  Ctrl+Shift+H  → Ver historial de comandos                           │
│  Ctrl+Shift+L  → Limpiar cinta de bloques                           │
│  Ctrl+Shift+S  → Guardar sesión                                      │
│  Esc           → Cerrar modal / popup / editor flotante              │
│  F1            → Mostrar ayuda contextual                            │
│  F5            → Re-ejecutar último comando                          │
│                                                                      │
│  NAVEGACIÓN EN ÁRBOL (catálogo)                                      │
│  ↑↓            → Navegar entre métodos                               │
│  →             → Expandir categoría                                  │
│  ←             → Colapsar categoría                                  │
│  Enter         → Seleccionar método (cargar en editor)               │
│  Space         → Expandir/colapsar categoría alternado               │
│                                                                      │
│  NAVEGACIÓN EN CINTA DE BLOQUES                                      │
│  ↑↓            → Navegar entre bloques                               │
│  Enter         → Expandir bloque colapsado                           │
│  Space         → Seleccionar bloque (mostrar acciones)               │
│  Ctrl+Enter    → Re-ejecutar bloque seleccionado                     │
│  Ctrl+E        → Editar bloque seleccionado                          │
│  Delete        → Ocultar bloque seleccionado                         │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 7. PLAN DE IMPLEMENTACIÓN PARA CLAUDE DESIGN

### 7.1 Fase 1 — Tokens y Componentes Base (Día 1-2)
1. Crear `tokens/colors.css` con todas las custom properties
2. Crear `tokens/typography.css` con escala tipográfica + Google Fonts
3. Crear `tokens/spacing.css` y `tokens/depth.css`
4. Crear componentes base: `button.html`, `input.html`, `badge.html`, `modal.html`
5. Crear `index.html` con layout base (topbar + sidebar + main + statusbar)

### 7.2 Fase 2 — Componentes de Navegación (Día 3-4)
6. Crear `tree.html` (árbol jerárquico para catálogo de métodos)
7. Crear `tab.html` (pestañas de navegación)
8. Crear `panel.html` (paneles colapsables con splitters)
9. Crear `console.html` (consola segura de comandos)

### 7.3 Fase 3 — Editor y Cinta (Día 5-7)
10. Crear `editor.html` (editor JSON con resaltado de sintaxis)
11. Crear `block.html` (bloque de cinta Calculator Tape)
12. Integrar en pantalla principal 3 paneles + consola

### 7.4 Fase 4 — Pantallas de Laboratorio (Día 8-10)
13. Crear `07-token-lab.html` (4 variantes de token)
14. Crear `08-template-creator.html` (creador de plantillas)
15. Crear `09-blockchain-lab.html` (laboratorio blockchain)
16. Crear `10-signature-lab.html` (laboratorio de firma digital)

### 7.5 Fase 5 — Pantallas Técnicas + Negocio Base (Día 11-13)
17. Crear `01-connection.html` (pantalla de conexión)
18. Crear `02-login.html` (login del desarrollador)
19. Crear `03-register.html` (registro TRIAL — 3 pasos)
20. Crear `04-dashboard.html` (dashboard principal del tenant)
21. Crear `11-collections.html` (colecciones y entornos)
22. Crear `12-wizard-flow.html` (flujo guiado)

### 7.6 Fase 6 — Pantallas de Negocio (Día 14-17) ★ NUEVO
23. Crear `13-tenant-profile.html` (perfil del tenant + plan y límites)
24. Crear componentes: `company-card.html`, `plan-badge.html`, `usage-panel.html`
25. Crear `14-companies.html` (gestión de empresas cliente — CRUD completo)
26. Crear `15-branches.html` (gestión de sucursales por empresa)
27. Crear `16-client-users.html` (usuarios de las empresas cliente)
28. Crear `17-usage-tracking.html` (tracking de uso por empresa/sucursal)
29. Crear `18-support.html` (soporte, onboarding, gerente de cuenta)

### 7.7 Fase 7 — Integración y Polish (Día 18-20)
30. Integrar navegación entre las 18 pantallas
31. Implementar teclado completo (atajos globales)
32. Añadir estados: loading, empty, error a todos los componentes
33. Tema claro `[data-theme="light"]`
34. Responsive: 3 breakpoints
35. `preview/` cards con `@dsCard` para cada componente y pantalla

---

## 8. REFERENCIAS Y DOCUMENTOS FUENTE

| Documento | Ruta | Contenido |
|-----------|------|-----------|
| PLAN-BAUTHDEV-RPC-TESTER.md | `BauthAgent/src/desktop/` | Especificación completa de bAuthDEV (1937 líneas) |
| PLAN-DESKTOP-BAUTH.md | `BauthAgent/src/desktop/` | Dashboard de administración PAP |
| BAUTH-VISION.md | `BauthAgent/src/context/ia/` | Visión del producto bAuth |
| SBOS-049-CONTEXT-PLANE.md | `context/sbos/Procesar/humano/BOS_V8/` | Context Plane, ctx_id |
| SBOS-050-PORT-CATALOG.md | `context/sbos/Procesar/humano/BOS_V8/` | Catálogo de puertos |
| SBOS-ROLTEMPLATE-v6_0.md | `BauthAgent/src/` | 14 secciones del contrato de Rol |
| SBOS-USERTEMPLATE-v6_0.md | `BauthAgent/src/` | 16 secciones del contrato de Usuario |

---

## 9. GLOSARIO PARA CLAUDE DESIGN

| Término | Significado en bAuthDEV |
|---------|------------------------|
| **bAuth** | Identity Control Plane del SBOS. Orquestador central de autenticación. |
| **JSON-RPC 2.0** | Protocolo de comunicación. Request: `{jsonrpc, method, params, id}`. Response: `{jsonrpc, result, id}`. |
| **Catálogo de métodos** | 47+ métodos JSON-RPC disponibles en bAuth, organizados por categoría. |
| **Cinta de bloques** | Patrón "Calculator Tape": cada request + respuesta = un bloque inmutable en una cinta vertical. |
| **Editor flotante** | Modal que aparece al hacer clic en [EDITAR] sobre un bloque, permitiendo modificar el comando. |
| **Snippet** | Código generado automáticamente en Go/Rust/Python/JS/Dart/cURL a partir del request actual. |
| **Token Lab** | Laboratorio para experimentar con las 4 variantes de token JWT de bAuth. |
| **Plantilla** | RolTemplate pre-configurado (368 roles base). El desarrollador personaliza uno existente. |
| **Dominio** | Uno de los 12 dominios de control (D1 Lógico, D2 Físico, ..., D12 Blockchain). |
| **FastPath** | Evaluación local de permisos usando RolBitMask, <0.5ns. Para modo offline. |
| **Merkle Proof** | Prueba criptográfica de que un token fue anclado en blockchain Besu QBFT. |
| **SSH Tunnel** | Conexión cifrada transparente entre bAuthDEV y el servidor. El usuario no ve SSH. |
| **Wizard** | Flujo guiado paso a paso. 4 wizards pre-diseñados para aprender bAuth. |
| **ctx_id** | Identificador de contexto operativo (SBOS-049). Trazabilidad de extremo a extremo. |

---

*DESIGN-BAUTHDEV.md v1.0.0 · 2026-06-28 · SKULL · SBOS*
*Elaborado por sbos-coordinador basado en PLAN-BAUTHDEV-RPC-TESTER.md v3.0.0 y PLAN-DESKTOP-BAUTH.md v3.0.0*
*Formato optimizado para Claude Design — compatible con `/design-sync` y DESIGN.md specification*
