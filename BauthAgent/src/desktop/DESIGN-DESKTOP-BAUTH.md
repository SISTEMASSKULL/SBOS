# DESIGN-DESKTOP-BAUTH — Sistema de Diseño Dashboard bAuth para Claude Design

**Versión:** 1.0.0 · **Fecha:** 2026-06-28 · **Autor:** sbos-coordinador
**Proyecto:** bAuth Desktop — Dashboard Soberano de Administración de Identidad (PAP)
**Objetivo:** Especificación completa para que Claude Design genere el UI Kit HTML/CSS del dashboard de administración
**Stack destino:** HTML5 + CSS3 + JavaScript vanilla (prototipo) → Flutter 3.44+ (producción)
**Referencia:** PLAN-DESKTOP-BAUTH.md v3.0.0 (1563 líneas)

---

## 0. DIAGNÓSTICO DEL HTML ACTUAL

### 0.1 Lo que Claude Design entregó

El archivo `bAuth Desktop.html` (182 líneas) contiene:
- Un **splash screen** con logo SVG de bAuth y texto "Identity Control Plane"
- Infraestructura de **bundle autodesempaquetable** (React/Babel via blob URLs)
- **0 pantallas funcionales** — solo el logo y el nombre

### 0.2 Lo que FALTA (gap analysis)

| # | Lo que debería tener | Estado actual | Tipo |
|---|---------------------|:---:|------|
| 1 | Dashboard con 12 KPI cards + métricas | ❌ Ausente | Técnico |
| 2 | Radar de 12 dominios con semaforización | ❌ Ausente | Técnico |
| 3 | Tabla de usuarios conectados en tiempo real | ❌ Ausente | Técnico |
| 4 | Editor de Roles con árbol jerárquico D1-D12 | ❌ Ausente | Técnico |
| 5 | Editor de Usuarios con 15 secciones | ❌ Ausente | Técnico |
| 6 | Pantalla de Políticas (14×12 grid) | ❌ Ausente | Técnico |
| 7 | Panel de Sincronización KC+Tryton | ❌ Ausente | Técnico |
| 8 | Visor de Auditoría ISO 27001 | ❌ Ausente | Técnico |
| 9 | Panel "Visión BOS" (8 indicadores) | ❌ Ausente | Técnico |
| 10 | Métricas de rendimiento (CPU, RAM, latencia) | ❌ Ausente | Técnico |
| 11 | Exportación CSV/JSON/PDF | ❌ Ausente | Técnico |
| 12 | Navegación por teclado completa | ❌ Ausente | Técnico |
| **13** | **Perfil del Tenant + Plan y límites** | **❌ Ausente** | **Negocio** |
| **14** | **Gestión de Empresas (org_empresa CRUD)** | **❌ Ausente** | **Negocio** |
| **15** | **Gestión de Sucursales por empresa** | **❌ Ausente** | **Negocio** |
| **16** | **Gestión de POS lógicos (org_pos_logico)** | **❌ Ausente** | **Negocio** |
| **17** | **Tracking de uso empresarial** | **❌ Ausente** | **Negocio** |
| **18** | **Soporte SBOS + Estado de onboarding** | **❌ Ausente** | **Negocio** |

> **Hallazgo de la investigación de código:** El DDL tiene todas las tablas necesarias
> (`org_empresa`, `org_sucursal`, `org_pos_logico`, `idn_tenant`, `idn_tenant_verification`).
> Pero los handlers Rust para CRUD de empresas/sucursales/POS **no existen aún**.
> El diseño visual debe anticipar estas pantallas para que cuando se implementen los
> handlers, la UI ya esté lista.

### 0.3 Instrucción para Claude Design

**Este documento reemplaza y expande el HTML actual.** Claude Design debe regenerar
completamente el proyecto con TODAS las pantallas, componentes y estados especificados aquí.
El splash screen actual es el punto de partida — mantener el logo y la identidad visual,
pero construir todo lo demás desde cero.

---

## 1. INSTRUCCIONES PARA CLAUDE DESIGN

### 1.1 Cómo usar este documento

Este documento es la **especificación maestra de diseño** para el Dashboard de Administración
bAuth. Contiene el diseño completo de 12 pantallas, 18 componentes, tokens visuales,
flujos de usuario, y reglas de implementación.

### 1.2 Formato de salida esperado

Claude Design debe generar esta estructura:

```
desktop/bAuth-Admin-UI/
├── README.md                               # Contexto de marca + guía
├── index.html                              # UI Kit completo con navegación
├── tokens/
│   ├── colors.css                          # Custom properties (paleta SBOS Dark)
│   ├── typography.css                      # Inter + JetBrains Mono
│   ├── spacing.css                         # Escala 4px + grid
│   └── depth.css                           # Sombras y elevación
├── components/
│   ├── sidebar.html                        # Barra lateral de navegación
│   ├── topbar.html                         # Barra superior (breadcrumb + acciones)
│   ├── kpi-card.html                       # Tarjeta de indicador clave
│   ├── status-badge.html                   # Badge semáforo (🟢🟡🔴)
│   ├── domain-icon.html                    # Icono por dominio (D1-D12)
│   ├── data-table.html                     # Tabla de datos (sort, filtro, paginación)
│   ├── tree-node.html                      # Nodo de árbol jerárquico
│   ├── domain-tree.html                    # Árbol completo D1-D12
│   ├── radar-chart.html                    # Gráfico radar 12 dominios (SVG)
│   ├── bar-chart.html                      # Gráfico de barras (SVG)
│   ├── line-chart.html                     # Gráfico de líneas (actividad login)
│   ├── gauge.html                          # Medidor tipo gauge (CPU, RAM, pool)
│   ├── progress-bar.html                   # Barra de progreso con semáforo
│   ├── modal.html                          # Diálogos modales
│   ├── toast.html                          # Notificaciones toast
│   ├── tabs.html                           # Pestañas de navegación
│   ├── search-bar.html                     # Barra de búsqueda global (Ctrl+K)
│   └── context-menu.html                   # Menú contextual (click derecho)
├── screens/
│   ├── 01-dashboard.html                   # Dashboard principal
│   ├── 02-role-list.html                   # Lista de Roles (PlutoGrid)
│   ├── 03-role-editor.html                 # Editor de Rol — ÁRBOL D1-D12
│   ├── 04-user-list.html                   # Lista de Usuarios
│   ├── 05-user-editor.html                 # Editor de Usuario
│   ├── 06-policies.html                    # Políticas de Autenticación
│   ├── 07-sync.html                        # Sincronización KC+Tryton
│   ├── 08-audit.html                       # Auditoría ISO 27001
│   ├── 09-bos-vision.html                  # Visión BOS (8 indicadores)
│   ├── 10-session-detail.html              # Detalle de Sesión Individual
│   ├── 11-commercial.html                  # Panel Comercial + Firma Digital
│   ├── 12-tenant-profile.html              # Perfil del Tenant + Plan + Límites
│   ├── 13-companies.html                   # Gestión de Empresas (org_empresa CRUD)
│   ├── 14-branches.html                    # Gestión de Sucursales por empresa
│   ├── 15-pos-management.html              # Puntos de Venta (org_pos_logico)
│   ├── 16-business-usage.html              # Tracking de uso por empresa/sucursal
│   └── 17-support.html                     # Soporte SBOS + Estado de Onboarding
└── preview/
    ├── colors.html                         # @dsCard group="Tokens"
    ├── typography.html                     # @dsCard group="Tokens"
    ├── components.html                     # @dsCard group="Componentes"
    └── dashboard.html                      # @dsCard group="Pantallas"
```

### 1.3 Reglas de implementación

| # | Regla | Detalle |
|---|-------|---------|
| R1 | **CSS custom properties** | Todo color, fuente, espacio y sombra como variable CSS en `:root` |
| R2 | **Semántica HTML5** | `<header>`, `<nav>`, `<main>`, `<aside>`, `<section>`, `<article>` |
| R3 | **Estados completos** | Cada componente: default, hover, focus, active, disabled, loading, empty, error |
| R4 | **Sin frameworks CSS** | CSS vanilla. Sin Tailwind, Bootstrap, Material |
| R5 | **Tema oscuro SBOS** | Default: `[data-theme="dark"]`. Alternativo: `[data-theme="light"]` |
| R6 | **Teclado primero** | Todo operable sin mouse. Shortcuts globales documentados |
| R7 | **Preview cards** | `<!-- @dsCard group="Nombre del Grupo" -->` en cada componente y pantalla |
| R8 | **Responsive 3 breakpoints** | `--bp-compact` (900px), `--bp-tablet` (1200px), `--bp-desktop` (1440px+) |
| R9 | **Español** | Todo texto de UI y comentarios en español |
| R10 | **Gráficos SVG nativos** | Sin librerías externas. Radar, barras, líneas en SVG inline |
| R11 | **Datos demo realistas** | Usar los 5 usuarios de prueba + 368 roles + métricas simuladas realistas |
| R12 | **Standalone** | Cada HTML abre directamente en navegador, sin servidor |

---

## 2. TEMA VISUAL — SBOS Dark Professional Admin

### 2.1 Personalidad

```
┌──────────────────────────────────────────────────────────────────────┐
│  PERSONALIDAD — bAuth Admin Dashboard                                │
│                                                                      │
│  🎯 Para:    Administradores de identidad, oficiales de seguridad    │
│  🏢 Entorno: Oficina, centro de operaciones de seguridad (SOC)       │
│  🧠 Estado:  Supervisión, control, auditoría, cumplimiento           │
│                                                                      │
│  ES:         Un centro de comando para la identidad corporativa      │
│  ES:         Un tablero de control con semaforización clara          │
│  ES:         Una herramienta de precisión para governance            │
│                                                                      │
│  NO ES:      Una app de consumo — es herramienta profesional         │
│  NO ES:      Un dashboard de marketing — es operaciones              │
│                                                                      │
│  TONO:       Sobrio, profesional, autoritativo, confiable            │
│  DENSIDAD:   Alta — el administrador necesita ver todo de un vistazo │
│  RITMO:      Jerarquizado — KPI → tablas → drill-down → detalle      │
└──────────────────────────────────────────────────────────────────────┘
```

### 2.2 Paleta de colores

```css
:root, [data-theme="dark"] {
  /* ── SUPERFICIES ───────────────────────────────────── */
  --color-bg-root:        #060A10;    /* Fondo raíz */
  --color-bg-primary:     #0B1018;    /* Panel principal */
  --color-bg-secondary:   #0F161F;    /* Cards, secciones */
  --color-bg-tertiary:    #141C28;    /* Inputs, celdas */
  --color-bg-elevated:    #192230;    /* Modales, popups */
  --color-bg-hover:       #1E2A3A;    /* Hover */
  --color-bg-active:      #243040;    /* Seleccionado */

  /* ── BORDES ────────────────────────────────────────── */
  --color-border-subtle:  #162030;
  --color-border-default: #203048;
  --color-border-strong:  #2A4060;
  --color-border-accent:  #3B82F6;

  /* ── TEXTO ─────────────────────────────────────────── */
  --color-text-primary:   #E8EEF6;
  --color-text-secondary: #8899B0;
  --color-text-tertiary:  #556880;
  --color-text-inverse:   #0B1018;

  /* ── ACCIONES ──────────────────────────────────────── */
  --color-accent:         #3B82F6;
  --color-accent-hover:   #4F94F7;
  --color-accent-active:  #2563EB;
  --color-accent-subtle:  rgba(59,130,246,0.10);

  /* ── SEMÁFORO ──────────────────────────────────────── */
  --color-success:        #22C55E;
  --color-success-bg:     rgba(34,197,94,0.08);
  --color-warning:        #EAB308;
  --color-warning-bg:     rgba(234,179,8,0.08);
  --color-error:          #EF4444;
  --color-error-bg:       rgba(239,68,68,0.08);
  --color-info:           #06B6D4;
  --color-info-bg:        rgba(6,182,212,0.08);

  /* ── 12 DOMINIOS ───────────────────────────────────── */
  --color-d1:  #8B5CF6;   --color-d1-bg:  rgba(139,92,246,0.10);
  --color-d2:  #F97316;   --color-d2-bg:  rgba(249,115,22,0.10);
  --color-d3:  #22C55E;   --color-d3-bg:  rgba(34,197,94,0.10);
  --color-d4:  #3B82F6;   --color-d4-bg:  rgba(59,130,246,0.10);
  --color-d5:  #EC4899;   --color-d5-bg:  rgba(236,72,153,0.10);
  --color-d6:  #14B8A6;   --color-d6-bg:  rgba(20,184,166,0.10);
  --color-d7:  #6366F1;   --color-d7-bg:  rgba(99,102,241,0.10);
  --color-d8:  #A855F7;   --color-d8-bg:  rgba(168,85,247,0.10);
  --color-d9:  #EAB308;   --color-d9-bg:  rgba(234,179,8,0.10);
  --color-d10: #787B86;   --color-d10-bg: rgba(120,123,134,0.10);
  --color-d11: #FB923C;   --color-d11-bg: rgba(251,146,60,0.10);
  --color-d12: #06B6D4;   --color-d12-bg: rgba(6,182,212,0.10);

  /* ── CÓDIGO ────────────────────────────────────────── */
  --color-code-bg:      #060A10;
  --color-code-string:  #A5D6FF;
  --color-code-number:  #FFC48C;
  --color-code-key:     #8BB8F2;
  --color-code-bool:    #FF8CBF;
  --color-code-null:    #FF6B6B;

  /* ── TIPOGRAFÍA ────────────────────────────────────── */
  --font-sans:   'Inter', system-ui, -apple-system, sans-serif;
  --font-mono:   'JetBrains Mono', 'Cascadia Code', monospace;
  --text-xs:     0.6875rem;   --text-sm:  0.8125rem;
  --text-base:   0.9375rem;   --text-md:  1.0625rem;
  --text-lg:     1.25rem;     --text-xl:  1.5rem;
  --text-2xl:    1.875rem;    --text-3xl: 2.375rem;
  --font-normal: 400;  --font-medium: 500;
  --font-semibold: 600; --font-bold: 700;
  --leading-tight: 1.2; --leading-normal: 1.5; --leading-relaxed: 1.7;

  /* ── ESPACIADO ─────────────────────────────────────── */
  --space-1: 0.25rem;  --space-2: 0.5rem;   --space-3: 0.75rem;
  --space-4: 1rem;     --space-5: 1.25rem;  --space-6: 1.5rem;
  --space-8: 2rem;     --space-10: 2.5rem;  --space-12: 3rem;
  --space-16: 4rem;

  /* ── BORDES ────────────────────────────────────────── */
  --radius-sm: 0.25rem;  --radius-md: 0.375rem;
  --radius-lg: 0.5rem;   --radius-xl: 0.75rem;  --radius-full: 9999px;

  /* ── LAYOUT 3 COLUMNAS ─────────────────────────────── */
  --left-sidebar-width:          56px;   /* colapsado (iconos) */
  --left-sidebar-expanded:       220px;  /* expandido (hover) */
  --right-sidebar-width:         0px;    /* colapsado por defecto */
  --right-sidebar-expanded:      320px;  /* expandido */
  --topbar-height:               0px;    /* SIN topbar — reemplazado por left sidebar */
  --statusbar-height:            24px;

  /* ── SOMBRAS ───────────────────────────────────────── */
  --shadow-sm:  0 1px 2px rgba(0,0,0,0.4);
  --shadow-md:  0 4px 12px rgba(0,0,0,0.5);
  --shadow-lg:  0 8px 32px rgba(0,0,0,0.6);
  --shadow-glow: 0 0 16px rgba(59,130,246,0.12);

  /* ── CAPAS Z ───────────────────────────────────────── */
  --z-base: 0;  --z-dropdown: 100;  --z-sticky: 200;
  --z-overlay: 300;  --z-modal: 400;  --z-toast: 500;
}
```

---

## 2bis. ARQUITECTURA DE LAYOUT GLOBAL — 3 Columnas

### Principio (mismo patrón que bAuthDEV)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  bAuth Desktop — Layout Global (PAP — Policy Administration Point)          │
│                                                                              │
│  ┌──────────┬──────────────────────────────────────────┬──────────────────┐ │
│  │          │                                          │                  │ │
│  │  LEFT    │              CENTER BODY                 │  RIGHT           │ │
│  │  SIDEBAR │              (área principal)            │  SIDEBAR         │ │
│  │          │                                          │                  │ │
│  │  Naveg.  │  Todo el contenido se renderiza aquí:    │  Panel de        │ │
│  │  princi. │  • Dashboard con KPIs + radar           │  contexto        │ │
│  │          │  • Editor de Roles (árbol D1-D12)        │  (adaptable)     │ │
│  │  🛡️      │  • Editor de Usuarios (árbol 15 secc.)   │                  │ │
│  │  📊      │  • Listas (Roles, Usuarios, Políticas)   │  • Acciones      │ │
│  │  👥      │  • Sincronización KC+Tryton               │    rápidas       │ │
│  │  👤      │  • Auditoría ISO 27001                    │  • Resumen       │ │
│  │  🛡️      │  • Visión BOS (8 indicadores)            │    de sección    │ │
│  │  🔄      │  • Empresas / Sucursales / POS           │  • Ayuda         │ │
│  │  📋      │  • Uso del Sistema                       │    contextual    │ │
│  │  👁      │  • Soporte                               │                  │ │
│  │  🏢      │                                          │  Se adapta       │ │
│  │  🌐      │                                          │  según la        │ │
│  │  📊      │                                          │  pantalla:       │ │
│  │  🎓      │                                          │  • Dashboard →   │ │
│  │          │                                          │    acciones      │ │
│  │  ─────── │                                          │  • Editor Rol →  │ │
│  │  🟢 v3.0 │                                          │    resumen       │ │
│  │  12d 4h  │                                          │  • Editor User → │ │
│  │          │                                          │    datos clave   │ │
│  └──────────┴──────────────────────────────────────────┴──────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Dimensiones

| Panel | Ancho | Comportamiento |
|-------|:---:|------|
| **Left Sidebar** | 56px → 220px | Colapsado: solo iconos. Expandido (hover): iconos + labels |
| **Center Body** | Flexible (resto) | Área de trabajo principal |
| **Right Sidebar** | 0px → 320px | Adaptable. Dashboard: acciones rápidas. Editor Rol/User: resumen de sección |

### Left Sidebar — Navegación Principal (Admin)

```
┌────────────┐          ┌─────────────────────┐
│ 🛡️         │          │ 🛡️ bAuth Desktop    │
│ ─────────  │          │ ──────────────────  │
│ 📊         │ hover →  │ 📊 Dashboard        │
│ 👥         │          │ 👥 Roles            │
│ 👤         │          │ 👤 Usuarios         │
│ 🛡️         │          │ 🛡️ Políticas        │
│ 🔄         │          │ 🔄 Sincronización   │
│ 📋         │          │ 📋 Auditoría        │
│ 👁         │          │ 👁 Visión BOS       │
│ ─────────  │          │ ──────────────────  │
│ 🏢         │          │ 🏢 Empresas         │
│ 🌐         │          │ 🌐 Sucursales       │
│ 🖥         │          │ 🖥 Puntos de Venta   │
│ 📊         │          │ 📊 Uso del Sistema  │
│ ─────────  │          │ ──────────────────  │
│ 🎓         │          │ 🎓 Soporte          │
│ ⚙         │          │ ⚙ Configuración     │
│ ─────────  │          │ ──────────────────  │
│ 🟢         │          │ 🟢 Conectado        │
│            │          │ v3.0.0 · 12d 4h     │
└────────────┘          └─────────────────────┘
  COLAPSADO               EXPANDIDO (hover)
  56px                    220px
```

| Icono | Label | Destino | Atajo |
|:---:|------|------|-------|
| 🛡️ | bAuth Desktop | Logo — click va a Dashboard | — |
| 📊 | Dashboard | KPIs, radar 12 dominios, usuarios conectados | `Ctrl+1` |
| 👥 | Roles | Lista de roles + Editor de Rol (árbol D1-D12) | `Ctrl+2` |
| 👤 | Usuarios | Lista de usuarios + Editor de Usuario (árbol 15 secc.) | `Ctrl+3` |
| 🛡️ | Políticas | Políticas de autenticación por tier y dominio | `Ctrl+4` |
| 🔄 | Sincronización | Estado sync KC+Tryton, drift, reconciliación | `Ctrl+5` |
| 📋 | Auditoría | Eventos ISO 27001, filtros, exportación | `Ctrl+6` |
| 👁 | Visión BOS | 8 indicadores de salud desde perspectiva IAM | `Ctrl+7` |
| 🏢 | Empresas | CRUD de empresas cliente (org_empresa) | `Ctrl+8` |
| 🌐 | Sucursales | CRUD de sucursales por empresa | `Ctrl+9` |
| 🖥 | Puntos de Venta | Configuración SIN Bolivia, dosificación | `Ctrl+0` |
| 📊 | Uso del Sistema | Tracking de uso por empresa/sucursal | `Ctrl+Shift+U` |
| 🎓 | Soporte | Gerente de cuenta, onboarding, recursos | `Ctrl+Shift+H` |

### Right Sidebar — Panel de Contexto (adaptable por pantalla)

```
PANEL EN DASHBOARD:                    PANEL EN EDITOR DE ROL:
┌────────────────────────┐            ┌────────────────────────┐
│ ⚡ ACCIONES RÁPIDAS     │            │ 📋 RESUMEN DEL ROL      │
│ ─────────────────────  │            │ ─────────────────────  │
│ [➕ Nuevo Rol]          │            │ Secciones: 12/14        │
│ [➕ Nuevo Usuario]      │            │ Átomos activos: 42      │
│ [🔄 Sincronizar Todo]   │            │ Conflictos SoD: 0       │
│ [📤 Exportar Auditoría] │            │ LoA requerido: AAL2     │
│                         │            │ MFA: ✅                 │
│ 🔔 ALERTAS              │            │ Tier: BIZ_N3            │
│ ─────────────────────  │            │                         │
│ 🟡 3 roles con DRIFT   │            │ [💾 GUARDAR BORRADOR]   │
│ 🔴 1 sucursal degradada│            │ [📋 PUBLICAR ROL]       │
│ ⚠ 2 usuarios bloqueados│            │ [🧪 VALIDAR]            │
│                         │            │ [📤 EXPORTAR JSON]      │
│ 📈 USO (24h)            │            │ [📋 DUPLICAR]           │
│ ─────────────────────  │            │                         │
│ Evaluaciones: 234,567  │            │ ⚠ IMPACTO DEL CAMBIO    │
│ Tokens emitidos: 1,234 │            │ ─────────────────────  │
│ FastPath: 99.7%        │            │ 3 roles heredan de este │
│                         │            │ 47 usuarios afectados   │
└────────────────────────┘            └────────────────────────┘

PANEL EN EDITOR DE USUARIO:           PANEL EN AUDITORÍA:
┌────────────────────────┐            ┌────────────────────────┐
│ 👤 DATOS CLAVE          │            │ 📊 FILTROS RÁPIDOS      │
│ ─────────────────────  │            │ ─────────────────────  │
│ UUID: 019f06db-...     │            │ ☑ Últimas 24 horas     │
│ Username: juan.perez   │            │ ☐ Última semana        │
│ Empresa: Comer. Valle  │            │ ☐ Último mes           │
│ Sucursal: Central      │            │                         │
│                         │            │ Usuario: [Todos ▼]     │
│ 📊 ACTIVIDAD            │            │ Acción: [Todas ▼]      │
│ ─────────────────────  │            │ Dominio: [Todos ▼]     │
│ Última sesión: 11:27   │            │                         │
│ Sesiones activas: 1    │            │ 📊 KPIs SEGURIDAD       │
│ Roles asignados: 2     │            │ ─────────────────────  │
│ Evaluaciones hoy: 89   │            │ MFA: 87% │ Passkey: 34%│
│                         │            │ Bloqueos: 23           │
│ 🔒 SEGURIDAD            │            │ Ghost accounts: 3      │
│ ─────────────────────  │            │                         │
│ LoA: AAL2 ✅            │            │ [📤 EXPORTAR CSV]       │
│ MFA: TOTP ✅            │            │ [📤 EXPORTAR PDF]       │
│ WebAuthn: YubiKey 5C ✅ │            └────────────────────────┘
│ Password: 92/100 🟢    │
│                         │
│ [🔒 FORZAR CIERRE]      │
│ [📋 VER AUDITORÍA]      │
└────────────────────────┘
```

**Comportamiento del Right Sidebar:**
- **Dashboard**: acciones rápidas + alertas + KPIs de uso
- **Editor de Rol**: resumen del rol + impacto del cambio + botones de acción
- **Editor de Usuario**: datos clave + actividad + seguridad + acciones
- **Listas** (Roles, Usuarios): filtros rápidos + exportar
- **Auditoría**: filtros + KPIs de seguridad + exportación
- **Colapsable** con `Ctrl+Shift+B`

### Comparación con el layout anterior

| Aspecto | Antes (Top Menu) | Ahora (Left+Right Sidebar) |
|---------|:---:|:---:|
| Navegación | Tabs horizontales | Sidebar izquierdo con 14 items |
| Panel contextual | No existía | Sidebar derecho adaptable por pantalla |
| Espacio de trabajo | Robado por menú top + tabs | Centro completo dedicado al contenido |
| Acciones rápidas | Mezcladas en toolbar | Panel derecho dedicado |
| Resumen en editor | Panel lateral dentro del editor | Sidebar derecho unificado |

---

## 3. CATÁLOGO DE COMPONENTES

### 3.1 Sidebar de Navegación

```html
<!-- @dsCard group="Navegación" -->
<!--
  ESTRUCTURA:
  ┌──────────────────────┐
  │ 🛡️ bAuth            │ ← Logo + nombre
  │ ─────────────────── │
  │ 📊 Dashboard        │ ← Item activo: borde izq accent
  │ 👥 Roles            │
  │ 👤 Usuarios         │
  │ 🛡️ Políticas        │
  │ 🔄 Sincronización   │
  │ 📋 Auditoría        │
  │ 👁 Visión BOS       │
  │ ⛓ Blockchain        │
  │ ⚙ Configuración     │
  │ ─────────────────── │
  │ 🟢 Conectado        │ ← Estado conexión
  │ v3.0.0 · 12d 4h    │
  └──────────────────────┘

  ESTADOS POR ITEM:
  - default:    texto --color-text-secondary, sin fondo
  - hover:      fondo --color-bg-hover, texto --color-text-primary
  - active:     borde izquierdo 3px --color-accent, fondo --color-accent-subtle
  - disabled:   texto --color-text-tertiary, cursor not-allowed
  - badge:      número a la derecha (ej: "Roles 5" con badge de drift)
-->
```

### 3.2 KPI Card

```html
<!-- @dsCard group="Indicadores" -->
<!--
  ESTRUCTURA:
  ┌─────────────────────┐
  │ 👤  Total Usuarios  │ ← Icono + etiqueta
  │     1,247           │ ← Valor grande
  │     📈 +12% (30d)   │ ← Tendencia (opcional)
  │     ████████░░ 78%  │ ← Barra de progreso (opcional)
  └─────────────────────┘

  VARIANTES:
  - default:  borde sutil, fondo --color-bg-secondary
  - success:  borde izquierdo --color-success
  - warning:  borde izquierdo --color-warning
  - error:    borde izquierdo --color-error

  TAMAÑOS:
  - sm: 120px × 80px (dashboard compacto)
  - md: 180px × 110px (dashboard principal, default)
  - lg: 240px × 140px (dashboard expandido)
-->
```

### 3.3 Árbol Jerárquico de Dominios (DomainTree)

```html
<!-- @dsCard group="Árbol de Dominios" -->
<!--
  COMPONENTE CENTRAL del editor de roles.
  Jerarquía: Rol → Dominio → Zona → App → Módulo → Verbo → Átomo

  NODO RAÍZ — Rol
  └── D1 LÓGICO             ← Nodo dominio (color D1)
  │   └── AREA-CAJA         ← Nodo zona
  │       └── Tryton         ← Nodo app
  │           └── sale_pos   ← Nodo módulo
  │               ├── ☑ READ   ← Nodo verbo + checkbox átomo
  │               ├── ☑ WRITE
  │               └── ☐ EXEC
  ├── D2 FÍSICO             ← Nodo dominio (color D2)
  │   └── EDIFICIO-CENTRAL
  │       └── PISO-1
  │           └── ZONA-CAJA
  │               └── LECTOR-PUERTA
  │                   └── ☑ ACCESO
  ├── D3 FINANCIERO         ← Nodo dominio (color D3)
  │   ├── FAC_EMITIR ($2,000/día)
  │   ├── COBRO_RECIBIR ($5,000)
  │   └── ⚠ SoD: creador ≠ aprobador
  └── ... D4 a D12

  ESTADOS POR NODO:
  - collapsed:  flecha ▶, hijos ocultos
  - expanded:   flecha ▼, hijos visibles
  - selected:   fondo --color-accent-subtle, borde izquierdo accent
  - checked:    checkbox ☑ marcado (átomo activo)
  - unchecked:  checkbox ☐ desmarcado
  - partial:    checkbox ☒ (algunos hijos marcados, herencia parcial)
  - disabled:   texto gris, no interactivo
  - conflict:   borde rojo pulsante (conflicto SoD detectado)
  - drift:      badge amarillo "DRIFT" (desincronizado de KC/Tryton)

  COMPORTAMIENTO:
  - Click en flecha → expandir/colapsar
  - Click en checkbox → marcar/desmarcar átomo (hereda a padres)
  - Doble click en nombre → editar inline
  - Click derecho → menú contextual (Editar, Duplicar, Sincronizar, Eliminar)
  - Arrastrar → reordenar zonas/apps/módulos
  - Búsqueda: resalta nodos que coinciden, expande automáticamente

  TECLAS:
  - ↑↓: Navegar entre nodos
  - →: Expandir nodo
  - ←: Colapsar nodo
  - Space: Marcar/desmarcar checkbox
  - Enter: Seleccionar nodo (mostrar panel lateral)
  - F2: Renombrar nodo
  - Delete: Eliminar nodo (con confirmación)
-->
```

### 3.4 Tabla de Datos (DataTable)

```html
<!-- @dsCard group="Tablas" -->
<!--
  ESTRUCTURA:
  ┌──────────────────────────────────────────────────────────────┐
  │  🔍 [Buscar...__________]  [Filtro: Todos ▼]  [📤 Exportar] │ ← Toolbar
  ├──────────────────────────────────────────────────────────────┤
  │  ☐  │ Usuario       │ Rol      │ Tenant │ Sesión │ Estado   │ ← Headers
  ├──────────────────────────────────────────────────────────────┤
  │  ☐  │ juan.perez    │ CAJERO   │ ORG-A  │ 3h 12m │ 🟢      │ ← Filas
  │  ☐  │ maria.lopez   │ SUPERV.  │ ORG-A  │ 1h 47m │ 🟢      │
  │  ☐  │ carlos.ruiz   │ GERENTE  │ ORG-B  │ 8h 01m │ 🟡      │
  ├──────────────────────────────────────────────────────────────┤
  │  ← 1 2 3 ... 12 →  │  89 resultados  │  Filas: [50 ▼]      │ ← Footer
  └──────────────────────────────────────────────────────────────┘

  FUNCIONALIDADES:
  - Sort: click en header → ASC / DESC / ninguno
  - Filtro: por columna, multi-criterio
  - Selección: checkboxes múltiples para acciones en lote
  - Paginación: numérica con flechas + selector de filas por página
  - Columnas ocultables: click derecho en header → mostrar/ocultar
  - Resize de columnas: arrastrar borde derecho del header
  - Exportar: CSV/JSON del conjunto filtrado actual
  - Click en fila → drill-down (detalle expandible o nueva pantalla)

  ESTADOS:
  - loading:  skeleton rows (6 filas grises pulsantes)
  - empty:    "No se encontraron resultados" con ilustración
  - error:    "Error al cargar datos" con botón [Reintentar]
-->
```

### 3.5 Gráfico Radar de 12 Dominios (SVG)

```html
<!-- @dsCard group="Gráficos" -->
<!--
  SVG inline. 12 ejes (D1-D12), cada uno con:
  - Etiqueta: D1 Lógico, D2 Físico, ...
  - Valor: 0-100% (estado de salud del dominio)
  - Color: --color-d1 a --color-d12
  - Semaforización: 🟢 >80%, 🟡 50-80%, 🔴 <50%

  ESTRUCTURA DEL SVG:
  - 3 anillos concéntricos (33%, 66%, 100%)
  - 12 líneas radiales (una por dominio)
  - Polígono relleno con opacidad (une los 12 puntos de valor)
  - 12 círculos en los puntos de valor con el color del dominio
  - Labels D1-D12 en los extremos de los ejes

  INTERACTIVIDAD:
  - Hover sobre punto → tooltip: "D3 Financiero: 94% 🟢 | 2,345,678 eval | 0.3ns"
  - Click en punto → filtra tabla inferior por ese dominio
-->
```

### 3.6 Gráfico de Actividad de Login (SVG)

```html
<!-- @dsCard group="Gráficos" -->
<!--
  SVG inline. Barras apiladas por hora (24h).
  - Verde: logins exitosos
  - Rojo: logins fallidos
  - Amarillo: cuentas bloqueadas
  - Hover: tooltip con valores exactos

  Ejemplo de tooltip:
  "14:00 — 2,345 éxito | 123 fallo | 5 bloqueado"
-->
```

### 3.7 Panel de Rendimiento (PerformancePanel)

```html
<!-- @dsCard group="Paneles" -->
<!--
  ESTRUCTURA:
  ┌── RENDIMIENTO DEL DAEMON ────────────────────────────┐
  │                                                       │
  │  CPU  ████████░░░░░░░░░░  18%          🟢            │
  │  RAM  ████████████░░░░░░  62 MB        🟢            │
  │  HILOS ██░░░░░░░░░░░░░░░  47 activos   🟢            │
  │                                                       │
  │  ── LATENCIA DE EVALUACIÓN ──                         │
  │  P50 ▏ 0.3ms    P95 ▏ 1.2ms    P99 ▏ 4.7ms          │
  │                                                       │
  │  ── CONEXIONES ──                                     │
  │  PostgreSQL ████████░░  8/20 (40%)     🟢             │
  │  Redis      ██░░░░░░░░  95.2% hit      🟢             │
  │                                                       │
  │  ── RENDIMIENTO ──                                    │
  │  Evaluaciones/seg │ 142,857 ▏ 7ms 12 dominios         │
  │  Uptime           │ 12d 4h 31m          🟢            │
  │  Reinicios (24h)  │ 0                    🟢            │
  └───────────────────────────────────────────────────────┘
-->
```

### 3.8 Panel "Visión BOS"

```html
<!-- @dsCard group="Paneles" -->
<!--
  8 indicadores desde la perspectiva del IAM Installer:

  ┌── VISIÓN BOS — Salud de la Capa de Identidad ────────┐
  │                                                       │
  │  BOS-01 Socket health    🟢 /run/bos/bauth.sock OK   │
  │  BOS-02 ctx_id activos   🟢 1,247 sesiones           │
  │  BOS-03 Roles sync       🟡 3 roles con DRIFT         │
  │  BOS-04 Átomos registr.  🟢 5,808 átomos             │
  │  BOS-05 Ficha bauth      🟢 INSTALADA v3.0.0         │
  │  BOS-06 PostgreSQL pool  🟢 8/20 (40%)               │
  │  BOS-07 Redis hit rate   🟢 95.2%                    │
  │  BOS-08 Uptime daemon    🟢 12d 4h, 0 reinicios      │
  │                                                       │
  │  [⟳ REFRESCAR]  [📤 EXPORTAR REPORTE BOS]            │
  └───────────────────────────────────────────────────────┘
-->
```

### 3.9 Detalle de Sesión Individual

```html
<!-- @dsCard group="Paneles" -->
<!--
  Vista expandible al hacer click en un usuario conectado:

  ┌── DETALLE DE SESIÓN — juan.perez ────────────────────┐
  │                                                       │
  │  ┌── IDENTIDAD ────────────────────────────────────┐ │
  │  │  UUID:      019abcd-...                          │ │
  │  │  Username:  juan.perez                           │ │
  │  │  Email:     juan.perez@org-a.com.bo              │ │
  │  │  Tenant:    ORG-A                                │ │
  │  │  Empresa:   Comercializadora del Valle S.A.      │ │
  │  │  Sucursal:  Central — La Paz                     │ │
  │  └──────────────────────────────────────────────────┘ │
  │                                                       │
  │  ┌── SESIÓN ACTUAL ───────────────────────────────┐  │
  │  │  ctx_id:    01J-abc123-...                      │  │
  │  │  Inicio:    08:15:32 | Duración: 3h 12m        │  │
  │  │  LoA:       AAL2 (Password + TOTP)             │  │
  │  │  Dispositivo: Ubuntu 26.04 · Firefox 145       │  │
  │  │  IP:        192.168.1.45 / 200.87.123.45       │  │
  │  │  Ubicación: La Paz, Bolivia 🇧🇴 (HIGH trust)   │  │
  │  └──────────────────────────────────────────────────┘ │
  │                                                       │
  │  ┌── ROLES ───────────────────────────────────────┐  │
  │  │  ☑ CAJERO (BIZ_N1) │ FastPath: 99.7%          │  │
  │  │  ☐ SUPERVISOR (BIZ_N2) │ (no activo)          │  │
  │  └──────────────────────────────────────────────────┘ │
  │                                                       │
  │  ┌── ÚLTIMAS EVALUACIONES ────────────────────────┐  │
  │  │  Hora     │ Dom │ Átomo            │ Resultado │  │
  │  │  11:27:45 │ D1  │ tryton.sale.wr   │ PERMITIDO │  │
  │  │  11:27:12 │ D3  │ fin.factura.emit │ PERMITIDO │  │
  │  └──────────────────────────────────────────────────┘ │
  │                                                       │
  │  [🔒 FORZAR CIERRE] [📋 VER AUDITORÍA COMPLETA]       │
  └───────────────────────────────────────────────────────┘
-->
```

### 3.10 Tarjeta de Empresa (CompanyCard)

```html
<!-- @dsCard group="Negocio" -->
<!--
  ESTRUCTURA:
  ┌── 🏢 COMERCIALIZADORA DEL VALLE S.A. ──────────────────┐
  │  NIT: 123456789012  │  Régimen: General                │
  │  📍 3 sucursales    │  👤 47 usuarios                  │
  │  🖥 11 POS lógicos  │  🟢 Activa                       │
  │  ┌── USO (30d) ─────────────────────────────────────┐  │
  │  │  📊 45,678 eval │ 🔑 1,234 tokens │ ⚡ 99.7% Fast │  │
  │  └──────────────────────────────────────────────────┘  │
  │  [🌐 SUCURSALES] [👤 USUARIOS] [🖥 POS] [✏ EDITAR]   │
  └────────────────────────────────────────────────────────┘

  ESTADOS: active, suspended, trial, empty
-->
```

### 3.11 Tarjeta de Sucursal (BranchCard)

```html
<!-- @dsCard group="Negocio" -->
<!--
  ESTRUCTURA:
  ┌── 📍 Sucursal Central — La Paz ────────────────────────┐
  │  Dir: Av. 16 de Julio #1234 │ 🖥 5 POS │ 👤 23 users  │
  │  🕐 Lun-Vie 8-18 │ Admin: admin@comercializadora.com   │
  │  ┌── USO ───────────────────────────────────────────┐  │
  │  │  📊 28,456 eval │ 92% FastPath │ 8% PolicyPath   │  │
  │  └──────────────────────────────────────────────────┘  │
  │  [👤 USUARIOS] [🖥 POS] [✏ EDITAR]                    │
  └────────────────────────────────────────────────────────┘
-->
```

### 3.12 Indicador de Plan y Límites (PlanGauge)

```html
<!-- @dsCard group="Negocio" -->
<!--
  ESTRUCTURA:
  ┌── 💎 PLAN PRO — $199/mes ─────────────────────────────┐
  │  ┌──────────┬──────────┬──────────┬──────────┐        │
  │  │████████░░│██████░░░░│████░░░░░░│████████░░│        │
  │  └──────────┴──────────┴──────────┴──────────┘        │
  │  Roles 18/25  Users 847/1K  Empresas 8/10  Dom 8/8   │
  │  ⚠ Empresas al 80% — considera ampliar               │
  │  [📊 VER DETALLE] [🔄 CAMBIAR PLAN]                    │
  └────────────────────────────────────────────────────────┘

  UMBRALES: >80% 🟡 | >95% 🔴 | 100% 🔒
-->
```

### 3.13 Panel de Tracking de Uso Empresarial (BusinessUsagePanel)

```html
<!-- @dsCard group="Negocio" -->
<!--
  ESTRUCTURA (por tenant completo):
  ┌── 📊 USO DEL SISTEMA — Últimos 30 días ───────────────┐
  │                                                        │
  │  ┌── MÉTRICAS ─────────────────────────────────────┐  │
  │  │  🏢 8       👤 847     📊 234.5K    ⚡ 99.7%    │  │
  │  │  Empresas    Usuarios   Eval/mes     FastPath    │  │
  │  └─────────────────────────────────────────────────┘  │
  │                                                        │
  │  ┌── POR EMPRESA (barras SVG) ─────────────────────┐  │
  │  │  Comercializadora ██████████████████████ 45,678 │  │
  │  │  Distribuidora    ██████ 8,234                  │  │
  │  │  Agroindustrias   ████████████████████ 28,456   │  │
  │  └─────────────────────────────────────────────────┘  │
  │                                                        │
  │  ┌── ALERTAS ──────────────────────────────────────┐  │
  │  │  🟡 Transportes Andinos — 0 actividad 5 días    │  │
  │  │  🔴 Farmacias Bolivia — 98% del límite usuarios │  │
  │  └─────────────────────────────────────────────────┘  │
  └────────────────────────────────────────────────────────┘
-->
```

---

## 4. ESTRUCTURA DE PANTALLAS

### 4.1 Pantalla 01 — Dashboard Principal

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 🛡️ bAuth  │ 👁 Dashboard · Roles · Usuarios · Políticas · Sync · Auditoría  │
│ ──────────┼──────────────────────────────────────────────────────────────────┤
│           │  ┌── KPI CARDS ───────────────────────────────────────────────┐  │
│           │  │ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐   │  │
│ SIDEBAR   │  │ │👤 1,247│ │🔵   89 │ │📋  366 │ │✅ 99.7%│ │⚡ 0.3ns│   │  │
│           │  │ │Usuarios│ │Activos │ │Roles   │ │FastPath│ │Latencia│   │  │
│           │  │ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘   │  │
│ 📊 Dash   │  └─────────────────────────────────────────────────────────────┘  │
│ 👥 Roles  │  ┌── RADAR 12 DOMINIOS ─────┐  ┌── RENDIMIENTO ──────────────┐  │
│ 👤 Users  │  │          D1              │  │  CPU ████░░░░░  18%    🟢  │  │
│ 🛡️ Políticas│ │     D12    ◯    D2       │  │  RAM ██████░░░  62 MB  🟢  │  │
│ 🔄 Sync   │  │   D11          D3        │  │  P50 0.3ms  P99 4.7ms     │  │
│ 📋 Audit  │  │  D10              D4      │  │  PG ████░░ 8/20    🟢    │  │
│ 👁 BOS    │  │   D9            D5        │  │  Redis 95.2% hit   🟢    │  │
│ ⛓ Block   │  │     D8        D6         │  │  Uptime 12d 4h     🟢    │  │
│ ⚙ Config  │  │         D7               │  └───────────────────────────┘  │
│           │  └──────────────────────────┘                                  │
│ 🟢 v3.0.0 │  ┌── ACTIVIDAD DE LOGIN (24h) ───────────────────────────────┐ │
│ 12d 4h    │  │  ████████████████████████████░░░░░░░░  78% éxito   📈     │ │
│           │  │  ██████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  12% fallo           │ │
│           │  │  ████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  10% bloqueado       │ │
│           │  │  00  02  04  06  08  10  12  14  16  18  20  22           │ │
│           │  └───────────────────────────────────────────────────────────┘ │
│           │  ┌── USUARIOS CONECTADOS ───┐ ┌── TOP ROLES EVALUADOS ───────┐ │
│           │  │ juan.perez  CAJERO  3h  │ │ 1. CAJERO      2,345,678     │ │
│           │  │ maria.lopez SUPERV 1h  │ │ 2. VENDEDOR     1,876,543     │ │
│           │  │ carlos.ruiz GERENTE 8h │ │ 3. SUPERVISOR   1,234,567     │ │
│           │  └─────────────────────────┘ └────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 4.2 Pantalla 02 — Lista de Roles

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 🛡️ bAuth  │ 📋 Roles                                                         │
│ ──────────┼──────────────────────────────────────────────────────────────────┤
│           │  ┌── TOOLBAR ──────────────────────────────────────────────────┐ │
│           │  │  🔍 [Buscar rol...________]  Tier: [Todos ▼]  Status: [Todos │ │
│           │  │  [➕ NUEVO ROL]  [📤 EXPORTAR CSV]  [📥 IMPORTAR JSON]      │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── TABLA DE ROLES ──────────────────────────────────────────┐ │
│           │  │  Nombre          │ Tier    │ Átomos │ LoA │ MFA │ Status   │ │
│           │  │  ────────────────┼─────────┼────────┼─────┼─────┼──────────│ │
│           │  │  CAJERO          │ BIZ_N1  │     12 │   2 │ ✅  │ ACTIVO   │ │
│           │  │  SUPERVISOR      │ BIZ_N1  │     42 │   2 │ ✅  │ ACTIVO   │ │
│           │  │  GERENTE_SUC     │ BIZ_N1  │    156 │   2 │ ✅  │ ACTIVO   │ │
│           │  │  AUDITOR         │ BIZ_N2  │     89 │   3 │ ✅  │ ACTIVO   │ │
│           │  │  CAJERO_MI_APP   │ BIZ_N1  │     14 │   2 │ ✅  │ BORRADOR │ │
│           │  │  CONTADOR_V2     │ BIZ_N4  │     22 │   3 │ ⚠   │ DRIFT    │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ← 1 2 3 ... 8 → │ 366 roles │ Filas: [50 ▼]                    │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 4.3 Pantalla 03 — Editor de Rol (EL CORAZÓN)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 🛡️ bAuth  │ 📋 Roles > CAJERO (BIZ_N1)                         [💾 GUARDAR] │
│ ──────────┼──────────────────────────────────────────────────────────────────┤
│           │  ┌── ÁRBOL DE DOMINIOS ──────────────┐  ┌── RESUMEN ──────────┐  │
│           │  │                                    │  │                     │  │
│           │  │  🔍 [Buscar en árbol..._____]      │  │  Secciones: 12/14   │  │
│           │  │                                    │  │  Átomos:    42      │  │
│           │  │  ☑ CAJERO (BIZ_N1)                │  │  Conflictos: 0      │  │
│           │  │  ├── ☑ D1 LÓGICO          🟢      │  │  Tier:      BIZ_N1  │  │
│           │  │  │   └── ☑ AREA-CAJA              │  │  LoA:       2       │  │
│           │  │  │       └── ☑ Tryton             │  │  MFA:       ✅      │  │
│           │  │  │           ├── ☑ sale_pos       │  │  FastPath:  99.7%   │  │
│           │  │  │           │   ├── ☑ READ       │  │                     │  │
│           │  │  │           │   ├── ☑ WRITE      │  │  [📋 PUBLICAR ROL]  │  │
│           │  │  │           │   └── ☐ EXEC       │  │  [🧪 VALIDAR]       │  │
│           │  │  │           ├── ☑ account_invoice│  │  [📤 EXPORTAR JSON]  │  │
│           │  │  │           └── ☑ party          │  │  [📋 DUPLICAR]      │  │
│           │  │  ├── ☐ D2 FÍSICO          ⚪      │  └─────────────────────┘  │
│           │  │  ├── ☑ D3 FINANCIERO      🟢      │                           │
│           │  │  │   ├── FAC_EMITIR ($2K/día)     │  ┌── DETALLE D3 ───────┐ │
│           │  │  │   ├── COBRO_RECIBIR ($5K)      │  │ Límite diario:      │ │
│           │  │  │   └── ⚠ SoD: creador≠aprob     │  │ [$2,000.00______]   │ │
│           │  │  ├── ☑ D4 TEMPORAL        🟢      │  │                     │ │
│           │  │  │   └── Lun-Vie 8-18             │  │ Límite mensual:     │ │
│           │  │  ├── ☐ D5 BIOMÉTRICO      ⚪      │  │ [$50,000.00_____]   │ │
│           │  │  ├── ☐ D6 GEOESPACIAL     ⚪      │  │                     │ │
│           │  │  ├── ☐ D7 RED             ⚪      │  │ Apr. dual > $5,000  │ │
│           │  │  ├── ☑ D8 CONTEXTO        🟢      │  │ ☑ Activo            │ │
│           │  │  ├── ☑ D9 CREDENCIALES    🟢      │  └─────────────────────┘ │
│           │  │  │   ├── ☑ PASSWORD               │                           │
│           │  │  │   ├── ☑ TOTP                   │                           │
│           │  │  │   └── ☐ WEBAUTHN               │                           │
│           │  │  ├── ☐ D10 DELEGACIÓN     ⚪      │                           │
│           │  │  ├── ☑ D11 AUDITORÍA      🟢      │                           │
│           │  │  └── ☐ D12 BLOCKCHAIN     ⚪      │                           │
│           │  └────────────────────────────────────┘                           │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 4.4 Pantalla 04 — Lista de Usuarios

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 🛡️ bAuth  │ 👤 Usuarios                                                      │
│ ──────────┼──────────────────────────────────────────────────────────────────┤
│           │  ┌── KPIs ─────────────────────────────────────────────────────┐ │
│           │  │ 👤 1,247 Total │ 🔵 89 Conectados │ 🔴 12 Bloq │ 🟡 3 Ghost │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │  ┌── TOOLBAR ──────────────────────────────────────────────────┐ │
│           │  │  🔍 [Buscar...___]  Tenant: [Todos ▼]  Status: [Todos ▼]    │ │
│           │  │  [➕ NUEVO USUARIO]  [📤 EXPORTAR CSV]                       │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │  ┌── TABLA DE USUARIOS ────────────────────────────────────────┐ │
│           │  │  Usuario       │ Email              │ Roles    │ St │ Last   │ │
│           │  │  ──────────────┼────────────────────┼──────────┼────┼────────│ │
│           │  │  juan.perez    │ juan@org-a.com.bo  │ CAJERO   │ 🟢 │ 11:27  │ │
│           │  │  maria.lopez   │ maria@org-a.com.bo │ SUPERV.  │ 🟢 │ 11:15  │ │
│           │  │  carlos.ruiz   │ carlos@org-b.com.bo│ GERENTE  │ 🟡 │ 08:01  │ │
│           │  │  ana.torres    │ ana@org-a.com.bo   │ AUDITOR  │ 🔴 │ 06/25  │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 4.5 Pantalla 05 — Editor de Usuario

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 🛡️ bAuth  │ 👤 Usuarios > juan.perez                            [💾 GUARDAR] │
│ ──────────┼──────────────────────────────────────────────────────────────────┤
│           │  ┌── TABS ─────────────────────────────────────────────────────┐ │
│           │  │ [👤 IDENTIDAD] [🔑 ROLES] [📱 DISPOSITIVOS] [🔒 SEGURIDAD] │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── IDENTIDAD ───────────────────────────────────────────────┐ │
│           │  │  Username:    [juan.perez_______________]                    │ │
│           │  │  Email:       [juan.perez@org-a.com.bo_]                    │ │
│           │  │  Nombre:      [Juan Pérez Gutiérrez______]                  │ │
│           │  │  Tenant:      [ORG-A ▼]                                     │ │
│           │  │  Empresa:     [Comercializadora del Valle S.A. ▼]          │ │
│           │  │  Sucursal:    [Central — La Paz ▼]                         │ │
│           │  │  LoA mínimo:  [AAL2 ▼]                                      │ │
│           │  │  Status:      🟢 ACTIVO                                     │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── ROLES ASIGNADOS ─────────────────────────────────────────┐ │
│           │  │  Roles actuales:                                             │ │
│           │  │  ┌──────────────────────────────────────────────────────┐   │ │
│           │  │  │ ☑ CAJERO (BIZ_N1) — 12 átomos, FastPath 99.7%      │   │ │
│           │  │  │ ☐ SUPERVISOR (BIZ_N2) — 42 átomos (disponible)     │   │ │
│           │  │  └──────────────────────────────────────────────────────┘   │ │
│           │  │  [➕ ASIGNAR ROL]                                            │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── ACTIVIDAD RECIENTE ──────────────────────────────────────┐ │
│           │  │  📊 234 evaluaciones hoy │ 99.7% FastPath │ 0.3ns promedio │ │
│           │  │  Última sesión: Hoy 08:15:32 · Duración: 3h 12m           │ │
│           │  │  [👁 VER SESIÓN COMPLETA]                                   │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 4.6 Pantalla 06 — Políticas de Autenticación

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 🛡️ bAuth  │ 🛡️ Políticas de Autenticación                                    │
│ ──────────┼──────────────────────────────────────────────────────────────────┤
│           │  ┌── FILTROS ──────────────────────────────────────────────────┐ │
│           │  │  Tier: [BIZ_N1 ▼]  Dominio: [Todos ▼]  [🔍 BUSCAR POLÍTICA] │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── POLÍTICAS POR TIER: BIZ_N1 ──────────────────────────────┐ │
│           │  │                                                              │ │
│           │  │  #  │ Política                          │ Status  │ Acción  │ │
│           │  │  ───┼───────────────────────────────────┼─────────┼─────────│ │
│           │  │  1  │ Password mínimo 12 caracteres     │ ✅ Act. │ [✏]    │ │
│           │  │  2  │ Argon2id memoria 64 MB            │ ✅ Act. │ [✏]    │ │
│           │  │  3  │ TOTP requerido para AAL2          │ ✅ Act. │ [✏]    │ │
│           │  │  4  │ WebAuthn Passwordless ofrecido    │ ⚠ Opt. │ [✏]    │ │
│           │  │  5  │ Bloqueo a 5 intentos fallidos     │ ✅ Act. │ [✏]    │ │
│           │  │  6  │ Rotación credenciales 90 días     │ ✅ Act. │ [✏]    │ │
│           │  │  7  │ Sesión máxima 8 horas             │ ✅ Act. │ [✏]    │ │
│           │  │  8  │ Revocación en <30 segundos        │ ✅ Act. │ [✏]    │ │
│           │  │  ... │ ...                                │ ...     │ ...    │ │
│           │  │                                                              │ │
│           │  │  [➕ NUEVA POLÍTICA]  [🧪 SIMULAR EVALUACIÓN]               │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── RESUMEN POR DOMINIO ─────────────────────────────────────┐ │
│           │  │  D1: 4 políticas │ D2: 2 │ D3: 6 │ D4: 3 │ D9: 8 │ ...    │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 4.7 Pantalla 07 — Sincronización KC+Tryton

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 🛡️ bAuth  │ 🔄 Sincronización KC + Tryton                                    │
│ ──────────┼──────────────────────────────────────────────────────────────────┤
│           │  ┌── RESUMEN GLOBAL ───────────────────────────────────────────┐ │
│           │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │ │
│           │  │  │ ✅ 363   │  │ 🟡   3   │  │ 🔴   0   │  │ ⏱ 60s   │   │ │
│           │  │  │ SYNCED   │  │ DRIFT    │  │ ERROR    │  │ Interval │   │ │
│           │  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── ROLES CON DRIFT — REQUIEREN ATENCIÓN ────────────────────┐ │
│           │  │  ⚠ CONTADOR_V2 — 3 átomos extra en KC no declarados        │ │
│           │  │  ⚠ VENDEDOR_BO — 1 método MFA obsoleto en Tryton           │ │
│           │  │  ⚠ GERENTE_ZONA — schema drift en D3 Financiero            │ │
│           │  │  [🔄 RECONCILIAR TODO]  [🔄 RECONCILIAR SELECCIONADOS]     │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── TIMELINE DE EVENTOS DE SYNC ─────────────────────────────┐ │
│           │  │  14:32  ✅ Reconciliación automática — 366 roles OK         │ │
│           │  │  13:32  🟡 DRIFT detectado — CONTADOR_V2 (3 átomos)       │ │
│           │  │  12:32  ✅ Reconciliación automática — 366 roles OK         │ │
│           │  │  11:32  ✅ Reconciliación automática — 365 roles OK         │ │
│           │  │  10:32  ✅ Sincronización manual — GERENTE_ZONA            │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 4.8 Pantalla 08 — Auditoría ISO 27001

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 🛡️ bAuth  │ 📋 Auditoría ISO 27001 A.8.15                                    │
│ ──────────┼──────────────────────────────────────────────────────────────────┤
│           │  ┌── FILTROS ──────────────────────────────────────────────────┐ │
│           │  │  Desde: [2026-06-01]  Hasta: [2026-06-28]  Usuario: [Todos] │ │
│           │  │  Acción: [Todas ▼]  Resultado: [Todos ▼]  Dominio: [Todos]  │ │
│           │  │  [🔍 BUSCAR]  [📤 EXPORTAR CSV]  [📤 EXPORTAR PDF]         │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── KPIs DE SEGURIDAD ───────────────────────────────────────┐ │
│           │  │ 🔐 MFA: 87% │ 🔑 Passkey: 34% │ 🚫 Bloqueos: 23 │ 👻 Ghost: 3│ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── TABLA DE EVENTOS ─────────────────────────────────────────┐ │
│           │  │  Fecha       │ Usuario    │ Acción         │ Resultado│ ctx  │ │
│           │  │  ────────────┼────────────┼────────────────┼──────────┼──────│ │
│           │  │  06-28 11:27 │ juan.perez │ access.evaluate│ ALLOW    │01J..│ │
│           │  │  06-28 11:15 │ maria.lopez│ token.issue    │ SUCCESS  │01J..│ │
│           │  │  06-28 10:58 │ pedro.sal  │ login          │ DENIED   │01J..│ │
│           │  │  06-28 10:58 │ pedro.sal  │ login          │ DENIED   │01J..│ │
│           │  │  06-28 10:57 │ pedro.sal  │ login          │ DENIED   │01J..│ │
│           │  │  06-28 10:57 │ 🔒 BLOQUEO │ account_locked │ LOCKED   │ —   │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ← 1 2 3 ... 234 → │ 11,723 eventos │ Filas: [50 ▼]             │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 4.9 Pantalla 09 — Visión BOS + Estado del Daemon

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 🛡️ bAuth  │ 👁 Visión BOS — Salud de la Capa de Identidad                    │
│ ──────────┼──────────────────────────────────────────────────────────────────┤
│           │  ┌── INDICADORES BOS (8 semáforos) ────────────────────────────┐ │
│           │  │                                                              │ │
│           │  │  ┌───────────────────────┐  ┌──────────────────────────────┐│ │
│           │  │  │ BOS-01 Socket health  │  │ BOS-02 ctx_id activos        ││ │
│           │  │  │ 🟢 /run/bos/bauth.sock│  │ 🟢 1,247 sesiones activas    ││ │
│           │  │  │    OK — respondiendo  │  │    Sin fugas detectadas      ││ │
│           │  │  └───────────────────────┘  └──────────────────────────────┘│ │
│           │  │  ┌───────────────────────┐  ┌──────────────────────────────┐│ │
│           │  │  │ BOS-03 Roles sync     │  │ BOS-04 Átomos registrados    ││ │
│           │  │  │ 🟡 3 roles con DRIFT  │  │ 🟢 5,808 átomos en catálogo ││ │
│           │  │  │    CONTADOR_V2...     │  │    Cobertura completa        ││ │
│           │  │  └───────────────────────┘  └──────────────────────────────┘│ │
│           │  │  ┌───────────────────────┐  ┌──────────────────────────────┐│ │
│           │  │  │ BOS-05 Ficha bauth    │  │ BOS-06 PostgreSQL pool       ││ │
│           │  │  │ 🟢 INSTALADA v3.0.0  │  │ 🟢 8/20 conexiones (40%)    ││ │
│           │  │  │    Health checks OK   │  │    Sin agotamiento           ││ │
│           │  │  └───────────────────────┘  └──────────────────────────────┘│ │
│           │  │  ┌───────────────────────┐  ┌──────────────────────────────┐│ │
│           │  │  │ BOS-07 Redis hit rate │  │ BOS-08 Uptime daemon         ││ │
│           │  │  │ 🟢 95.2% cache hits   │  │ 🟢 12d 4h 31m               ││ │
│           │  │  │    TTL 30s óptimo     │  │    0 reinicios en 24h        ││ │
│           │  │  └───────────────────────┘  └──────────────────────────────┘│ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── ESTADO DEL DAEMON ────────────────────────────────────────┐ │
│           │  │  Servicio:    bauth.service (systemd) — Type=notify          │ │
│           │  │  Binario:     /usr/local/bin/bauth (MUSL, LTO)              │ │
│           │  │  Socket:      /run/bos/bauth.sock (0660, grupo bosagent)    │ │
│           │  │  Puerto TCP:  9450 (WebSocket, solo daemons)                │ │
│           │  │  Watchdog:    30s (systemd WatchdogSec)                     │ │
│           │  │  Versión:     3.0.0 — compilado 2026-06-27                  │ │
│           │  │  Logs:        journalctl -u bauth -f                        │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 4.10 Pantalla 10 — Detalle de Sesión Individual

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 🛡️ bAuth  │ 👤 Sesión: juan.perez                               [✕ CERRAR]  │
│ ──────────┼──────────────────────────────────────────────────────────────────┤
│           │                                                                  │
│           │  ┌── DATOS DE IDENTIDAD ──────────────────────────────────────┐ │
│           │  │  UUID:      019abcd-1234-7abc-5678-efghijklmnop             │ │
│           │  │  Username:  juan.perez                                      │ │
│           │  │  Email:     juan.perez@org-a.com.bo                         │ │
│           │  │  Tenant:    ORG-A (sbos-1234567890)                         │ │
│           │  │  Empresa:   Comercializadora del Valle S.A.                 │ │
│           │  │  Sucursal:  Central — La Paz                                │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── SESIÓN ACTUAL ──┐  ┌── ROLES ──┐  ┌── DISPOSITIVO ──────┐ │
│           │  │ ctx_id: 01J-abc..│  │ ☑ CAJERO  │  │ Ubuntu 26.04         │ │
│           │  │ Inicio: 08:15:32 │  │ ☐ SUPERV. │  │ Firefox 145          │ │
│           │  │ Duración: 3h 12m │  │           │  │ IP: 192.168.1.45     │ │
│           │  │ Expira: 16:15:32 │  │           │  │ IP pub: 200.87.123.45│ │
│           │  │ LoA: AAL2        │  │           │  │ 🇧🇴 La Paz (HIGH)    │ │
│           │  └──────────────────┘  └───────────┘  └───────────────────────┘ │
│           │                                                                  │
│           │  ┌── ÚLTIMAS 20 EVALUACIONES ──────────────────────────────────┐ │
│           │  │  Hora     │ Dom │ Átomo              │ Resultado │ Latencia  │ │
│           │  │  ─────────┼─────┼────────────────────┼───────────┼───────────│ │
│           │  │  11:27:45 │ D1  │ tryton.sale.writ   │ PERMITIDO │ 0.3ns     │ │
│           │  │  11:27:12 │ D3  │ fin.factura.emitir │ PERMITIDO │ 2.1ms     │ │
│           │  │  11:26:58 │ D4  │ temp.horario.check │ PERMITIDO │ 1.8ms     │ │
│           │  │  11:26:01 │ D1  │ tryton.party.read  │ PERMITIDO │ 0.3ns     │ │
│           │  │           │     │                    │           │           │ │
│           │  │  📊 Patrón: 99.7% FastPath │ 0.3% PolicyPath               │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  [🔒 FORZAR CIERRE DE SESIÓN]  [📋 EXPORTAR AUDITORÍA]          │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 4.11 Pantalla 11 — Perfil del Tenant + Plan

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 🛡️ bAuth  │ ⚙ Mi Cuenta > Perfil del Tenant                                  │
│ ──────────┼──────────────────────────────────────────────────────────────────┤
│           │  ┌── TABS ─────────────────────────────────────────────────────┐ │
│           │  │ [👤 PERFIL] [💎 PLAN] [🔑 SEGURIDAD] [📧 NOTIFICACIONES]   │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── DATOS DEL TENANT ────────────────────────────────────────┐ │
│           │  │                                                             │ │
│           │  │  Tenant ID:     019f06db-62a6-7777-b581-4c37e3aeee9f      │ │
│           │  │  Slug:          skull                                       │ │
│           │  │  Nombre Legal:  [SKULL SISTEMAS S.R.L.________________]     │ │
│           │  │  NIT:           [123456789012______________________]        │ │
│           │  │  Email:         [admin@skull.sbos.bo_______________]        │ │
│           │  │  Teléfono:      [+591 777889900____________________]        │ │
│           │  │  País:          🇧🇴 Bolivia                                 │ │
│           │  │  Tipo:          STANDARD                                    │ │
│           │  │  Aislamiento:   DEDICADO (realm propio en Keycloak)        │ │
│           │  │                                                             │ │
│           │  │  [💾 GUARDAR CAMBIOS]                                       │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── VERIFICACIÓN KYC ────────────────────────────────────────┐ │
│           │  │                                                             │ │
│           │  │  ✅ IDENTITY_CHECK   — Verificado (15 Jun 2026)            │ │
│           │  │  ✅ LEGAL_CHECK      — Verificado (16 Jun 2026)            │ │
│           │  │  ✅ TECHNICAL_SETUP  — Verificado (16 Jun 2026)            │ │
│           │  │  ✅ SECURITY_REVIEW  — Verificado (20 Jun 2026)            │ │
│           │  │  ✅ FINAL_APPROVAL   — Aprobado (20 Jun 2026)              │ │
│           │  │                                                             │ │
│           │  │  Estado: 🟢 COMPLETED — Tenant en producción               │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── PLAN ACTUAL ──────────────────────────────────────────────┐ │
│           │  │                                                              │ │
│           │  │  ┌───────────────────────────────────────────────────────┐  │ │
│           │  │  │  💎 PLAN PRO — $199/mes · Facturación: 28 cada mes   │  │ │
│           │  │  │                                                       │  │ │
│           │  │  │  ┌──────────┬──────────┬──────────┬──────────┐       │  │ │
│           │  │  │  │████████░░│██████░░░░│████░░░░░░│████████░░│       │  │ │
│           │  │  │  └──────────┴──────────┴──────────┴──────────┘       │  │ │
│           │  │  │  Roles        Usuarios     Empresas     Dominios      │  │ │
│           │  │  │  18/25        847/1,000    8/10          8/8          │  │ │
│           │  │  │                                                       │  │ │
│           │  │  │  ⚠ Empresas: 8 de 10 (80%) — considera ampliar      │  │ │
│           │  │  └───────────────────────────────────────────────────────┘  │ │
│           │  │                                                              │ │
│           │  │  [🔄 CAMBIAR A ENTERPRISE]  [📋 VER HISTORIAL DE PAGOS]    │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 4.12 Pantalla 12 — Gestión de Empresas (org_empresa CRUD)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 🛡️ bAuth  │ 🏢 Empresas                                                      │
│ ──────────┼──────────────────────────────────────────────────────────────────┤
│           │  ┌── RESUMEN ──────────────────────────────────────────────────┐ │
│           │  │  🏢 8 empresas │ 🌐 34 sucursales │ 🖥 67 POS │ 👤 847 users│ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── TOOLBAR ──────────────────────────────────────────────────┐ │
│           │  │  🔍 [Buscar empresa...___]  Status: [Todas ▼] [➕ NUEVA]    │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── TABLA DE EMPRESAS ────────────────────────────────────────┐ │
│           │  │  Empresa                      │ NIT       │ Suc │ Users│ St  │ │
│           │  │  ─────────────────────────────┼───────────┼─────┼──────┼─────│ │
│           │  │  🏢 Comercializadora Valle    │ 123456789 │   3 │   47 │ 🟢  │ │
│           │  │  🏢 Distribuidora Andina      │ 987654321 │   1 │   12 │ 🟢  │ │
│           │  │  🏢 Agroindustrias Oriente    │ 456789123 │   5 │   89 │ 🟢  │ │
│           │  │  🏢 Farmacias Bolivia         │ 789123456 │   2 │   34 │ 🟡  │ │
│           │  │  🏢 Transportes Andinos       │ 321654987 │   3 │   56 │ 🔴  │ │
│           │  └──────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ← 1 2 → │ 8 empresas │ Filas: [20 ▼]                            │
│           │                                                                  │
│           │  ┌── LÍMITES DEL PLAN ─────────────────────────────────────────┐ │
│           │  │  Empresas: 8/10 │ ████████░░ 80% │ ⚠ Quedan 2 cupos        │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Modal: Nueva Empresa**
```
┌── 🏢 NUEVA EMPRESA ──────────────────────────────────────────────┐
│                                                                  │
│  Razón Social *    [________________________________]            │
│  NIT *             [________________________]                    │
│  Régimen Fiscal    [General ▼]                                   │
│  País              [Bolivia ▼]                                   │
│  Ciudad            [La Paz ▼]                                    │
│  Moneda            [Boliviano (BOB) ▼]                           │
│  Zona Horaria      [America/La_Paz ▼]                            │
│                                                                  │
│  ¿Es operador?  ○ No — es cliente  ○ Sí — es casa matriz        │
│                                                                  │
│  [CANCELAR]  [🏢 CREAR EMPRESA]                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

### 4.13 Pantalla 13 — Gestión de Sucursales (org_sucursal CRUD)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 🛡️ bAuth  │ 🌐 Sucursales > Comercializadora del Valle S.A.                  │
│ ──────────┼──────────────────────────────────────────────────────────────────┤
│           │                                                                  │
│           │  Empresa: [Comercializadora del Valle S.A. ▼]  [➕ NUEVA SUC.]   │
│           │                                                                  │
│           │  ┌── LISTA DE SUCURSALES ──────────────────────────────────────┐ │
│           │  │                                                              │ │
│           │  │  ┌── 📍 Sucursal Central — La Paz ──────────────────────┐   │ │
│           │  │  │  Dir: Av. 16 de Julio #1234, Edif. Central, Piso 3  │   │ │
│           │  │  │  🕐 Lun-Vie 08:00-18:00 │ 👤 23 users │ 🖥 5 POS    │   │ │
│           │  │  │  Admin: admin.central@comercializadora.com           │   │ │
│           │  │  │  🟢 Activa │ 📅 Desde: 15 Mar 2026                  │   │ │
│           │  │  │  [👤] [🖥 POS] [✏] [📊]                            │   │ │
│           │  │  └──────────────────────────────────────────────────────┘   │ │
│           │  │                                                              │ │
│           │  │  ┌── 📍 Sucursal Norte — El Alto ───────────────────────┐   │ │
│           │  │  │  Dir: Av. Juan Pablo II #567, Zona 16 de Julio      │   │ │
│           │  │  │  🕐 Lun-Sáb 07:00-19:00 │ 👤 15 users │ 🖥 3 POS   │   │ │
│           │  │  │  🟢 Activa │ 📅 Desde: 15 Mar 2026                  │   │ │
│           │  │  │  [👤] [🖥 POS] [✏] [📊]                            │   │ │
│           │  │  └──────────────────────────────────────────────────────┘   │ │
│           │  │                                                              │ │
│           │  │  ┌── 📍 Sucursal Sur — Oruro ───────────────────────────┐   │ │
│           │  │  │  Dir: Calle Bolívar #890, Zona Central              │   │ │
│           │  │  │  🕐 Lun-Vie 08:00-18:00 │ 👤 9 users │ 🖥 2 POS    │   │ │
│           │  │  │  🟡 Degradada │ ⚠ Última conexión: hace 2h 34min   │   │ │
│           │  │  │  [👤] [🖥 POS] [✏] [📊] [🔄 DIAGNOSTICAR]         │   │ │
│           │  │  └──────────────────────────────────────────────────────┘   │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  Sucursales: 34/50 │ ████████░░ 68% │ Plan PRO                  │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 4.14 Pantalla 14 — Puntos de Venta (org_pos_logico)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 🛡️ bAuth  │ 🖥 Puntos de Venta > Central — La Paz                           │
│ ──────────┼──────────────────────────────────────────────────────────────────┤
│           │                                                                  │
│           │  Sucursal: [Central — La Paz ▼]  [➕ NUEVO POS]                  │
│           │                                                                  │
│           │  ┌── POS LÓGICOS ──────────────────────────────────────────────┐ │
│           │  │                                                              │ │
│           │  │  ┌── 🖥 POS-001 — Caja Principal ───────────────────────┐   │ │
│           │  │  │  CUIS: 123456 │ NIT Sucursal: 123456789012          │   │ │
│           │  │  │  Dosificación SIN: Activa │ Facturas: 4567-5000      │   │ │
│           │  │  │  Punto de facturación: 1 │ 🟢 Operativo             │   │ │
│           │  │  │  [✏ EDITAR] [📋 DOSIFICACIÓN] [🔄 SINCRONIZAR]     │   │ │
│           │  │  └──────────────────────────────────────────────────────┘   │ │
│           │  │                                                              │ │
│           │  │  ┌── 🖥 POS-002 — Caja Rápida ──────────────────────────┐   │ │
│           │  │  │  CUIS: 123457 │ Punto de facturación: 2 │ 🟢        │   │ │
│           │  │  │  [✏ EDITAR] [📋 DOSIFICACIÓN] [🔄 SINCRONIZAR]     │   │ │
│           │  │  └──────────────────────────────────────────────────────┘   │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 4.15 Pantalla 15 — Tracking de Uso Empresarial

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 🛡️ bAuth  │ 📊 Uso del Sistema — Visión Empresarial                          │
│ ──────────┼──────────────────────────────────────────────────────────────────┤
│           │                                                                  │
│           │  ┌── PERÍODO ──────────────────────────────────────────────────┐ │
│           │  │  [📅 Últimos 30 días ▼]  Empresa: [Todas ▼]  [📤 EXPORTAR] │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── MÉTRICAS GLOBALES ────────────────────────────────────────┐ │
│           │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │ │
│           │  │  │ 🏢      │ │ 👤       │ │ 📊       │ │ ⚡       │      │ │
│           │  │  │   8     │ │   847    │ │  234.5K  │ │  99.7%   │      │ │
│           │  │  │ Empresas│ │ Usuarios │ │ Eval/mes │ │ FastPath │      │ │
│           │  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── GRÁFICO: EVALUACIONES POR EMPRESA (barras SVG) ───────────┐ │
│           │  │                                                              │ │
│           │  │  Comercializadora ████████████████████████████████ 45,678  │ │
│           │  │  Agroindustrias   ██████████████████ 28,456                │ │
│           │  │  Farmacias Bol.   ██████████████ 22,111                    │ │
│           │  │  Transportes And. ████████ 12,345                           │ │
│           │  │  Distribuidora    ██████ 8,234                              │ │
│           │  └──────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── EMPRESAS POR CRECIMIENTO ─────────────────────────────────┐ │
│           │  │  # │ Empresa                  │ Crecimiento │ Δ Usuarios    │ │
│           │  │  1 │ Agroindustrias Oriente   │ 📈 +34%     │ +12           │ │
│           │  │  2 │ Comercializadora Valle   │ 📈 +22%     │ +5            │ │
│           │  │  3 │ Farmacias Bolivia        │ 📈 +18%     │ +3            │ │
│           │  └──────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── ALERTAS — EMPRESAS QUE NECESITAN ATENCIÓN ─────────────────┐ │
│           │  │  🔴 Transportes Andinos — Sin actividad 5 días              │ │
│           │  │  🟡 Farmacias Bolivia — 98% del límite de usuarios          │ │
│           │  │  🟡 Sucursal Sur (Oruro) — Degradada hace 2h 34min         │ │
│           │  └──────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 4.16 Pantalla 16 — Soporte SBOS y Estado de Onboarding

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 🛡️ bAuth  │ 🎓 Soporte SBOS                                                  │
│ ──────────┼──────────────────────────────────────────────────────────────────┤
│           │                                                                  │
│           │  ┌── TU GERENTE DE CUENTA SBOS ─────────────────────────────────┐ │
│           │  │  ┌────────────────────────────────────────────────────────┐  │ │
│           │  │  │  👤 María Gutiérrez — Account Manager                  │  │ │
│           │  │  │  📧 maria.gutierrez@skull.sbos.bo                      │  │ │
│           │  │  │  📞 +591 777889900                                      │  │ │
│           │  │  │  💬 Tiempo de respuesta: < 4 horas hábiles              │  │ │
│           │  │  │  [💬 ENVIAR MENSAJE]  [📅 AGENDAR LLAMADA]            │  │ │
│           │  │  └────────────────────────────────────────────────────────┘  │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── ESTADO DE TU ONBOARDING ───────────────────────────────────┐ │
│           │  │                                                              │ │
│           │  │  ✅ 1. Tenant verificado (KYC completado)    (20 Jun)       │ │
│           │  │  ✅ 2. Daemon bAuth instalado y health OK    (20 Jun)       │ │
│           │  │  ✅ 3. Primer rol creado y publicado         (22 Jun)       │ │
│           │  │  ✅ 4. Primeros usuarios registrados         (23 Jun)       │ │
│           │  │  ✅ 5. Políticas de autenticación config.    (24 Jun)       │ │
│           │  │  ✅ 6. Sincronización KC+Tryton estable      (25 Jun)       │ │
│           │  │  ⬜ 7. Auditoría ISO 27001 configurada        (pendiente)    │ │
│           │  │  ⬜ 8. Firma digital ADSIB activada           (pendiente)    │ │
│           │  │                                                              │ │
│           │  │  ┌── PROGRESO ───────────────────────────────────────────┐  │ │
│           │  │  │  ██████████████████████████████████████░░░░░░  75%     │  │ │
│           │  │  └──────────────────────────────────────────────────────┘  │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
│           │                                                                  │
│           │  ┌── HISTORIAL DE INTERACCIONES ────────────────────────────────┐ │
│           │  │  28 Jun 14:32  📧 Consulta: "¿Cómo agrego una sucursal?"    │ │
│           │  │  28 Jun 15:10  💬 Respuesta: "Te guío paso a paso"          │ │
│           │  │  20 Jun 09:00  🚀 Tenant activado en producción              │ │
│           │  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 4bis. ESPECIFICACIONES DE FORMULARIOS CRUD

> **Instrucción para Claude Design:** Cada formulario es un modal HTML con validación en vivo,
> mensajes de error en español, campos requeridos con asterisco (*). Campos calculados o
> de solo lectura se muestran pero no se editan. Los selectores cargan opciones del catálogo real.

### DF1. FORMULARIO — Nueva Empresa (org_empresa)

```html
<!-- @dsCard group="Formularios CRUD" -->
<!--
  ┌── 🏢 NUEVA EMPRESA ───────────────────────────────────────┐
  │                                                           │
  │  DATOS FISCALES                                           │
  │  ┌─────────────────────────────────────────────────────┐  │
  │  │  Razón Social *          NIT *                      │  │
  │  │  [__________________]    [__________________]       │  │
  │  │                                                     │  │
  │  │  Régimen Fiscal *        ¿Es operador?              │  │
  │  │  [General ▼]             ○ No (cliente)             │  │
  │  │  General, Simplificado   ○ Sí (casa matriz)         │  │
  │  └─────────────────────────────────────────────────────┘  │
  │                                                           │
  │  CONFIGURACIÓN REGIONAL                                   │
  │  ┌─────────────────────────────────────────────────────┐  │
  │  │  País *     Ciudad *    Moneda *    Zona Horaria *  │  │
  │  │  [Bolivia]  [La Paz]    [BOB]        [La_Paz ▼]    │  │
  │  └─────────────────────────────────────────────────────┘  │
  │                                                           │
  │  [CANCELAR]                         [🏢 CREAR EMPRESA]   │
  └──────────────────────────────────────────────────────────┘

  CAMPOS: razon_social(SI,text,3-200), nit(SI,text,8-15 dígitos),
  regimen_fiscal(SI,select), es_operador(SI,radio), pais(SI,select,ISO-3166),
  ciudad(SI,select), moneda_default(SI,select,ISO-4217), timezone(SI,select,IANA)
-->
```

### DF2. FORMULARIO — Nueva Sucursal (org_sucursal)

```html
<!-- @dsCard group="Formularios CRUD" -->
<!--
  ┌── 🌐 NUEVA SUCURSAL ─────────────────────────────────────┐
  │                                                           │
  │  Empresa *                                               │
  │  [Comercializadora del Valle S.A. ▼]                     │
  │                                                           │
  │  Nombre *             Dirección                           │
  │  [_______________]    [____________________________]      │
  │                                                           │
  │  Ciudad *             Zona              Zona Horaria      │
  │  [La Paz ▼]           [__________]      [La_Paz ▼]       │
  │                                                           │
  │  HORARIO: Apertura [08:00] Cierre [18:00]                │
  │  DÍAS: ☑Lun ☑Mar ☑Mié ☑Jue ☑Vie ☐Sáb ☐Dom              │
  │                                                           │
  │  Admin de Sucursal: [🔍 Buscar usuario...___________]    │
  │                                                           │
  │  [CANCELAR]                       [🌐 CREAR SUCURSAL]    │
  └──────────────────────────────────────────────────────────┘

  CAMPOS: empresa_id(SI,select), nombre(SI,text,3-100), direccion(NO,text,300),
  ciudad(SI,select), zona(NO,text,100), timezone(NO,select,IANA),
  horario_apertura(NO,time), horario_cierre(NO,time,>apertura),
  dias_operacion(NO,checkbox), admin_user_uuid(NO,search)
-->
```

### DF3. FORMULARIO — Usuario (ÁRBOL JERÁRQUICO · UserTemplate v6.0)

```html
<!-- @dsCard group="Formularios CRUD Jerárquicos" -->
<!--
  REGLA: "El admin NO llena formularios planos. Navega un ÁRBOL JERÁRQUICO."
  (BAUTH-CRUD-ROLES-USUARIOS.md)

  Identity → template JSONB → Sección → Sub-bloque → Campo/Array/Objeto

  👤 USUARIO
  ├── 📋 IDENTIDAD (identity) ✏ — 25 campos
  │   ├── username*, email*, display_name, nickname, locale*, zoneinfo*
  │   ├── tenant_id*, empresa_id*, sucursal_id, pos_logico
  │   ├── account_type*, user_type*, status
  │   ├── Ciclo de vida (lifecycle) 👁 — termination, offboarding, purge
  │   ├── Federación ✏ — federated_idp, brokering
  │   └── Firma Digital 👁 — EdDSA_Ed25519, certificate_thumbprint
  ├── 🔒 DATOS PERSONALES (personal_info) ✏ · _classification:CONFIDENTIAL
  │   ├── Control Acceso — full_access_roles, restricted_fields, gdpr_sensitive
  │   ├── Nombre — given_name*, middle_name, family_name*, second_family_name
  │   ├── Demográficos — birth_date*🔒, gender🔒, nationality*, marital_status
  │   ├── Identificación — primary_document (type*, number*🔒, issue/expiry, verified)
  │   ├── Contacto — emails[]*, phones[], addresses[]
  │   ├── Emergencia — emergency_contacts[]
  │   ├── Salud 🔒RESTRICTED — blood_type, allergies, physician
  │   └── Biométricos 🔒RESTRICTED — face_photo, _gdpr_basis, _consent_id
  ├── 💼 DATOS PROFESIONALES (professional_info) ✏
  │   ├── employee_code*, employee_type*, job_title*, department*
  │   ├── Línea de Reporte — manager_uuid*, reports_to_chain
  │   ├── Detalles Empleo — hire_date*, termination_date, contract_type
  │   ├── Compensación 🔒RESTRICTED — salary_currency, salary_amount
  │   ├── Certificaciones, Educación, Habilidades [➕]
  │   └── Ubicación Oficina, Horario
  ├── 🔑 ROLES ASIGNADOS (roles_assignments) ✏
  │   ├── active_roles[] [➕ Asignar desde catálogo 368 roles]
  │   ├── role_history[] 👁, delegations_received[] 👁, delegations_given[] ✏
  │   └── role_compliance 👁 — sod_conflicts, compliant, unused_permissions
  ├── 🔐 CREDENCIALES KC (keycloak_credentials) 👁 — password, TOTP, WebAuthn, compliance
  ├── 🏢 CREDENCIALES FÍSICAS ✏ — smart_cards[], biometric_enrollments[]
  ├── 📱 DISPOSITIVOS ✏ — primary_device (trust_score), secondary_devices[]
  ├── 📍 UBICACIÓN ✏ — home/work, assigned_branches[], allowed_countries[]
  ├── 🕐 TEMPORAL ✏ — schedule, shifts, breaks, overtime
  ├── 🌐 RED ✏ — allowed_cidrs[], vpn_required, device_trust_min
  ├── 📋 AUDITORÍA ✏ — audit_level, retention_days, compliance_status
  ├── 🔗 SERVICIOS EXTERNOS 👁 — consented_apps[]
  ├── ⚖ COMPLIANCE ✏ — sod, conflict_of_interest, policies, risk
  └── 🔄 CICLO DE VIDA 👁+✏ — provisioning, deprovisioning, sync_state

  Ver DESIGN-BAUTHDEV.md §3bis F3 para el árbol completo con todos los campos,
  niveles de clasificación, controles de acceso, y menú contextual.
-->
```

### DF4. FORMULARIO — Rol (ÁRBOL JERÁRQUICO · RolTemplate v6.0)

```html
<!-- @dsCard group="Formularios CRUD Jerárquicos" -->
<!--
  REGLA: "El admin navega un ÁRBOL JERÁRQUICO. Cada dominio es una rama.
   Cada rama tiene sub-ramas. Cada hoja es un átomo." (BAUTH-CRUD-ROLES-USUARIOS.md)

  Identity → template JSONB → Sección → Política → Rule → Condición

  🔑 ROL
  ├── 📋 IDENTIDAD (role) ✏ — id*, tier*, status*, version*, name{i18n}*, metadata
  │   ├── Vigencia — validity_period (FIXED/INDEFINITE/PROJECT_BASED)
  │   ├── Flujo Aprobación — approvers*, SLA, escalación
  │   └── Firma Digital 👁 — EdDSA_Ed25519
  ├── 💻 D1 — LÓGICO ✏ (200+ atributos)
  │   ├── Métodos (14) 👁 catálogo — PASSWORD, TOTP, WEBAUTHN, PASSKEY...
  │   ├── Flujos (8) ✏ — standard_login, elevated_login, financial_high_value...
  │   ├── Step-Up Rules (6) ✏ — FIN-APPROVE, SYSTEM-CONFIG...
  │   ├── Zonas [➕29] → App [➕12] → Módulo → Verbo → Átomo ☑/☐
  │   ├── Tryton (5 capas) — modelAccess, actions, fields, buttons, recordRules
  │   └── Control Temporal + Sesiones
  ├── 🏢 D2 — FÍSICO ✏ · 👁 catálogo zonas, métodos físicos, biometric enrollment
  ├── 💰 D3 — FINANCIERO ✏ · tipos transacción, límites, approval chain, SoD, SIN
  ├── 🕐 D4 — TEMPORAL · 🧬 D5 — BIOMÉTRICO · 🌍 D6 — GEOESPACIAL
  ├── 🌐 D7 — RED · 🔗 D8 — CONTEXTO · 🔐 D9 — CREDENCIALES
  ├── 🔄 D10 — DELEGACIÓN · 📋 D11 — AUDITORÍA · ⛓ D12 — BLOCKCHAIN
  ├── 🔒 SEGURIDAD ✏ — key_inventory👁, crypto_algorithms👁, security_zone
  ├── ⚖ COMPLIANCE ✏ — frameworks, GDPR, data_retention, breach_notification
  ├── 🔄 SYNC 👁 — KC composite_role, Tryton group, drift detection
  └── ⚠ CONFLICTOS ✏ — sod incompatible_roles, incompatible_functions

  INTERACCIÓN: [+] abre modal con catálogo desde BD · Click der. = menú contextual
  · ▶/▼ expandir/colapsar · Doble click = editar inline · ☑ = marcar átomo

  FLUJO CRUD (6 pasos):
  1. Crear header → 2. Expandir D1 → 3. Guardar sección
  4. Repetir D2-D12 → 5. Preview → 6. Publicar → sync KC+Tryton

  Ver DESIGN-BAUTHDEV.md §3bis F4 para el árbol completo con ~600 atributos,
  los 14 métodos de auth, 8 flujos, 5 capas Tryton, y catálogos dinámicos.
-->
```

### DF5. FORMULARIO — Punto de Venta SIN Bolivia (org_pos_logico · Facturación Electrónica)

```html
<!-- @dsCard group="Formularios CRUD" -->
<!--
  ESPECIFICACIÓN COMPLETA: SIN RND 102100000011 · Ley 164 · ADSIB-FD-POLT-015 v2.3

  ┌── 🖥 PUNTO DE VENTA — FACTURACIÓN ELECTRÓNICA SIN BOLIVIA ─┐
  │                                                             │
  │  TABS: [1📋 REGISTRO] [2📄 DOSIFICACIÓN] [3🔑 CÓDIGOS]    │
  │        [4📝 LEYENDAS] [5🏭 CAEB] [6🌐 WS SIN] [7🖥 HW]    │
  │                                                             │
  │  ─── 1. REGISTRO SIN ──────────────────────────────────── │
  │  ┌───────────────────────────────────────────────────────┐ │
  │  │  Empresa *           Sucursal *        Nº Punto Vta * │ │
  │  │  [Comercializadora]  [Central — LP]    [___1_______]  │ │
  │  │                                                       │ │
  │  │  Nombre del POS *           Código Sucursal SIN *     │ │
  │  │  [___Caja Principal_____]   [___001_______________]    │ │
  │  │                                                       │ │
  │  │  Modalidad *                    Ambiente SIN *        │ │
  │  │  ● COMPUTARIZADA EN LÍNEA      [PRODUCCION ▼]        │ │
  │  │  ○ ELECTRÓNICA EN LÍNEA         PRUEBAS / PRODUCCION  │ │
  │  │  ○ PORTAL WEB SIAT                                     │ │
  │  │                                                       │ │
  │  │  Tipo de Factura Principal *                           │ │
  │  │  [FACTURA_CREDITO_FISCAL ▼]  (27 tipos fiscales SIN) │ │
  │  └───────────────────────────────────────────────────────┘ │
  │                                                             │
  │  ─── 2. DOSIFICACIÓN (RND 10.0021.16, Art. 16) ───────── │
  │  ┌───────────────────────────────────────────────────────┐ │
  │  │  Nº Autorización SIN *   Tipo *       Estado          │ │
  │  │  [___1234567890_______]  [POR_TIEMPO] [ACTIVA ▼]     │ │
  │  │                         POR_TIEMPO / POR_CANTIDAD     │ │
  │  │                                                       │ │
  │  │  Fecha Solicitud         Fecha Activación             │ │
  │  │  [___2026-06-20______]   [___2026-06-28___________]   │ │
  │  │                                                       │ │
  │  │  Fecha Límite Emisión *                               │ │
  │  │  [___2027-06-25___________________________________]   │ │
  │  │                                                       │ │
  │  │  ─── RANGO ───                                       │ │
  │  │  Desde: [___1000001_________]  Nº Actual: [1000150]   │ │
  │  │  Hasta: [___2000000_________]  ⚠ Anuladas NO liberan  │ │
  │  └───────────────────────────────────────────────────────┘ │
  │                                                             │
  │  ─── 3. CÓDIGOS FISCALES ─────────────────────────────── │
  │  ┌───────────────────────────────────────────────────────┐ │
  │  │  CUIS: [___ABC123DEF456GHI789_______________________] │ │
  │  │  ⓘ Código Único de Iniciación de Sistemas.          │ │
  │  │    Se obtiene UNA vez. Cambia solo si se reinstala.  │ │
  │  │                                                       │ │
  │  │  CUFD: [___DEF456GHI789JKL012______________________]  │ │
  │  │  ⓘ Código Único de Facturación Diaria.               │ │
  │  │    Se renueva cada 24h (00:05 AM BOT).               │ │
  │  │    Otorgado: [2026-06-28 00:05]  Vigencia: [+24h]    │ │
  │  │                                                       │ │
  │  │  CAFC: [___GHI789JKL012MNO345______________________]  │ │
  │  │  ⓘ Código Autorización Facturación Computarizada.    │ │
  │  │    Solo modalidad COMPUTARIZADA_EN_LINEA.             │ │
  │  │    Autoriza generación del CUF (módulo 11 + Base 16).│ │
  │  │                                                       │ │
  │  │  📐 CUF: generado por factura, 28 chars alfanuméricos │ │
  │  └───────────────────────────────────────────────────────┘ │
  │                                                             │
  │  ─── 4. LEYENDAS LEGALES ─────────────────────────────── │
  │  ┌───────────────────────────────────────────────────────┐ │
  │  │  Leyenda SIN * (RND 102100000011):                    │ │
  │  │  [ESTA FACTURA CONTRIBUYE AL DESARROLLO DEL PAIS,    │ │
  │  │   EL USO ILICITO SERA SANCIONADO PENALMENTE...]      │ │
  │  │                                                       │ │
  │  │  Leyenda Derechos Consumidor (Ley 453):               │ │
  │  │  [EL CONSUMIDOR TIENE DERECHO A..._______________]    │ │
  │  │                                                       │ │
  │  │  Leyenda Representación Gráfica:                      │ │
  │  │  [ESTE DOCUMENTO ES UNA REPRESENTACION VISUAL...]     │ │
  │  │                                                       │ │
  │  │  Leyenda Crédito Fiscal (Ley 317, solo gasolineras):  │ │
  │  │  [_______________________________________________]    │ │
  │  └───────────────────────────────────────────────────────┘ │
  │                                                             │
  │  ─── 5. ACTIVIDAD CAEB ───────────────────────────────── │
  │  ┌───────────────────────────────────────────────────────┐ │
  │  │  Código: [___62010____]  [🔍 BUSCAR EN CATÁLOGO]     │ │
  │  │  Desc:   [___Programación informática_____________]   │ │
  │  └───────────────────────────────────────────────────────┘ │
  │                                                             │
  │  ─── 6. CONEXIÓN WEBSERVICE SIN ──────────────────────── │
  │  ┌───────────────────────────────────────────────────────┐ │
  │  │  URL WS: [https://siat.impuestos.gob.bo/servicios__]  │ │
  │  │  PROD: siat.impuestos.gob.bo / PRUEBAS: pilotosi...   │ │
  │  │                                                       │ │
  │  │  Token: [••••••••••••] (Vault)  Cert ADSIB *: [🔍]   │ │
  │  │  ⓘ RSA-SHA256, Persona Jurídica, Ley 164             │ │
  │  │                                                       │ │
  │  │  Heartbeat: [2026-06-28 14:32] Errores: [0] 🟢 OK    │ │
  │  └───────────────────────────────────────────────────────┘ │
  │                                                             │
  │  ─── 7. DISPOSITIVO FÍSICO ───────────────────────────── │
  │  ┌───────────────────────────────────────────────────────┐ │
  │  │  Device ID: [DEV-POS-001]  Hostname: [pos-caja-01]   │ │
  │  │  IP: [192.168.1.45]  MAC: [AA:BB:CC:DD:EE:FF]       │ │
  │  │  K8s Node: [node-lpz-03]  Geo: [-16.4955,-68.1336]  │ │
  │  │  Estado: 🟢 ACTIVO  │  Vinculado: 2026-06-28 08:00  │ │
  │  └───────────────────────────────────────────────────────┘ │
  │                                                             │
  │  ⚠ COMPLIANCE:                                            │
  │  • Sin CUFD vigente → NO se emiten facturas               │
  │  • Sin conexión SIN → CONTINGENCIA máx 48-72h              │
  │  • Firma ADSIB OBLIGATORIA en modalidad ELECTRONICA        │
  │  • Datos fiscales deben residir en Bolivia (D6-JURISD.)    │
  │  • Retención: 8 años mínimo (Código Tributario)           │
  │                                                             │
  │  [CANCELAR]  [💾 GUARDAR]  [🖥 CREAR + SOLICITAR CUIS]   │
  └─────────────────────────────────────────────────────────────┘

  CAMPOS (45 en 7 secciones) — idénticos al catálogo F5 del DEV.
  Ver DESIGN-BAUTHDEV.md §3bis F5 para tabla completa de campos.

  FLUJO ACTIVACIÓN:
  1. Datos Básicos → [GUARDAR] → 2. Dosificación → [SOLICITAR CUIS]
  3. bAuth → WebService SIN → obtiene CUIS → guarda
  4. bAuth → cron 00:05 AM renueva CUFD diario
  5. CAEB + Leyendas → [ACTIVAR] → estado=ACTIVA
  6. Primera factura → CUF generado (mod11+Base16, 28 chars)

  NORMAS: SIN RND 102100000011 · RND 102600000007 (01/10/2026)
  · Ley 164 · ADSIB-FD-POLT-015 v2.3 · Ley 453 · Ley 317
-->
```

---

## 5. FLUJOS DE USUARIO

### 5.1 Flujo Principal — Administrar Roles
```
LOGIN → Dashboard → Click "Roles" en sidebar → Lista de Roles
→ Click en "CAJERO" → Editor de Rol con Árbol D1-D12
→ Expandir D3 Financiero → Cambiar límite: $2,000 → $5,000
→ Marcar ☑ WebAuthn en D9 Credenciales
→ Click [💾 GUARDAR BORRADOR]
→ Sistema valida: bauth.template.validate → 260+ reglas
→ Sistema calcula: bauth.role.compute.mask → nuevo RolBitMask
→ Sistema verifica: bauth.sod.check → sin conflictos
→ Click [📋 PUBLICAR ROL]
→ Sistema ejecuta: bauth.merge.templates → escribe en idn_role_template
→ Sistema dispara: bauth.sync.reconcile → actualiza KC+Tryton
→ Toast: "✅ Rol CAJERO publicado y sincronizado"
```

### 5.2 Flujo — Investigar DRIFT
```
Dashboard → Semáforo BOS-03 en 🟡 "3 roles con DRIFT"
→ Click en BOS-03 → Pantalla Sync con los 3 roles filtrados
→ Click en "CONTADOR_V2" → Detalle del drift:
  "3 átomos extra en Keycloak no declarados en bauth_db:
   tryton.account.move.write, tryton.account.move.delete,
   tryton.account.bank_statement.read"
→ Click [🔄 RECONCILIAR] → bauth.sync.reconcile
→ Toast: "✅ CONTADOR_V2 reconciliado — 3 átomos removidos de KC"
→ Semáforo BOS-03 vuelve a 🟢
```

### 5.3 Flujo — Investigar Intento de Intrusión
```
Dashboard → Tabla de actividad de login muestra pico rojo a las 10:57
→ Click en la barra roja → Auditoría filtrada por esa hora
→ 5 intentos fallidos de "pedro.salazar" → cuenta bloqueada
→ Click en "pedro.salazar" → Detalle de usuario
→ Pestaña Seguridad: IP 189.234.56.78 (no reconocida, 🇧🇴 Cochabamba)
→ [🔓 DESBLOQUEAR CUENTA] → [📧 NOTIFICAR USUARIO]
```

### 5.4 Flujo — Gestionar Empresas y Sucursales
```
Dashboard → Sidebar "🏢 Empresas" → Lista de empresas del tenant
→ Click [➕ NUEVA EMPRESA] → Completar: Razón Social, NIT, Régimen, Ciudad
→ Empresa creada → Click [🌐 SUCURSALES]
→ [➕ NUEVA SUCURSAL] → Completar: Nombre, Dirección, Horario, Admin
→ Sucursal creada → Click [🖥 POS]
→ [➕ NUEVO POS] → Completar: CUIS, dosificación SIN, punto facturación
→ POS creado → Asignar usuarios desde la pantalla de Usuarios
→ Cliente onboarded — métricas aparecen en 📊 Uso del Sistema
```

### 5.5 Flujo — Monitorear Uso del Sistema
```
Dashboard → Sidebar "📊 Uso del Sistema"
→ Ver métricas globales: 8 empresas, 847 usuarios, 234.5K eval/mes
→ Identificar Comercializadora como mayor consumidora (45,678 eval)
→ Click en barra → Drill-down a sucursales de Comercializadora
→ Central: 28,456 (60%) │ Norte: 12,345 (26%) │ Sur: 4,877 (10%)
→ Revisar alertas: Transportes Andinos inactiva 5d 🔴
→ [💬 CONTACTAR CLIENTE] → enviar mensaje de reactivación
→ Farmacias Bolivia al 98% del límite de usuarios 🟡
→ [📧 SUGERIR AMPLIACIÓN DE PLAN] al administrador de Farmacias
```

### 5.6 Flujo — Cambiar de Plan
```
Dashboard → Sidebar "⚙ Mi Cuenta" → Tab "💎 Plan"
→ Ver uso actual: PRO, 8/10 empresas (80%), 847/1,000 usuarios (85%)
→ Click [🔄 CAMBIAR A ENTERPRISE]
→ Modal comparativo: PRO vs ENTERPRISE
→ [CONFIRMAR CAMBIO] → Tenant actualizado a ENTERPRISE
→ Dashboard refleja nuevos límites ilimitados
→ Barras de uso bajan de 80% a < 10%
→ Email de confirmación + factura del nuevo plan
```

---

## 6. TECLAS Y ATAJOS

```
┌──────────────────────────────────────────────────────────────────────┐
│  ATAJOS GLOBALES                                                     │
│  ──────────────────────────────────────────────────────────────────  │
│  Ctrl+K / Cmd+K    → Barra de búsqueda/comando global               │
│  Ctrl+1..9         → Cambiar entre vistas principales               │
│  Ctrl+S            → Guardar rol/usuario actual                     │
│  Ctrl+Shift+P      → Publicar rol                                   │
│  Ctrl+F            → Buscar en tabla/árbol actual                   │
│  Ctrl+R / F5       → Refrescar datos                                │
│  Ctrl+Z            → Deshacer último cambio                         │
│  Esc               → Cerrar panel/diálogo / Cancelar edición        │
│  Tab / Shift+Tab   → Navegar entre campos y secciones               │
│  ↑↓←→              → Navegar nodos del árbol                        │
│  Space             → Marcar/desmarcar checkbox en nodo              │
│  Enter             → Expandir nodo / Abrir detalle                  │
│  F2                → Renombrar nodo (edición inline)                │
│  Delete            → Eliminar elemento (con confirmación)           │
│  Alt+← / Alt+→     → Navegar historial de vistas                   │
│  Ctrl+Shift+L      → Bloquear pantalla (security lock)              │
│  Ctrl+,            → Abrir Configuración                            │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 7. ESTADOS GLOBALES

### 7.1 Conexión al daemon

| Estado | Indicador | Comportamiento |
|--------|-----------|----------------|
| 🟢 Conectado | Verde en sidebar footer | Todas las funciones activas |
| 🟡 Reconectando | Amarillo, spinner | Modo lectura, operaciones deshabilitadas |
| 🔴 Desconectado | Rojo, banner superior | Solo pantalla de conexión/reintento |

### 7.2 Estados de Rol

| Estado | Badge | Acciones disponibles |
|--------|-------|---------------------|
| BORRADOR | 🟡 | Editar, Validar, Publicar, Eliminar |
| ACTIVO | 🟢 | Ver, Duplicar, Editar (crea nueva versión), Retirar |
| DRIFT | ⚠🟡 | Ver, Reconciliar, Forzar sync |
| RETIRADO | ⚫ | Ver (histórico), Reactivar |
| ERROR | 🔴 | Ver, Diagnosticar, Reintentar |

### 7.3 Estados de Sincronización

| Estado | Significado | Acción |
|--------|------------|--------|
| ✅ SYNCED | Rol idéntico en bauth_db, KC y Tryton | Ninguna |
| 🟡 DRIFT | Diferencias detectadas | Reconciliar |
| 🔴 ERROR | Falló la sincronización | Diagnosticar |
| ⏳ SYNCING | Sincronización en progreso | Esperar |
| ⚪ PENDING | Pendiente de primer sync | Sincronizar |

---

## 8. DATOS DEMO PARA PROTOTIPO

Usar estos datos realistas en el HTML generado:

### 8.1 Usuarios de prueba
| Usuario | UUID | Rol | Átomos | Tier |
|---------|------|-----|:---:|:---:|
| test_superadmin | 019f06db-62a6-77b1-b581-4c37e3aeee9f | supervisor | 42 | SU |
| test_gerente | 019f06db-62a9-729c-89ea-1a2fcc714c12 | gerente | 42 | BIZ_N1 |
| test_contador | 019f06db-62a9-7323-90a3-1c8b2880408f | contador | 22 | BIZ_N4 |
| test_cajero | 019f06db-62a9-73ab-a85a-f5d12f20233d | cajero | 8 | BIZ_N5 |
| test_cliente | 019f06db-62a9-7551-b33c-12583be0ed1f | sin rol | 0 | — |

### 8.2 Métricas simuladas
- 1,247 usuarios totales, 89 conectados ahora
- 366 roles, 12 dominios, 5,808 átomos
- 99.7% FastPath, 0.3ns latencia promedio
- CPU: 18%, RAM: 62 MB, PostgreSQL: 8/20 conexiones
- Redis: 95.2% hit rate, Uptime: 12d 4h 31m
- 234,567 evaluaciones/mes, 3 roles con DRIFT

---

## 9. PLAN DE IMPLEMENTACIÓN PARA CLAUDE DESIGN

### Fase 1 — Tokens y Layout Base (Día 1-2)
1. `tokens/colors.css` — todas las custom properties
2. `tokens/typography.css` — Inter + JetBrains Mono
3. `tokens/spacing.css` + `tokens/depth.css`
4. Layout base: sidebar + topbar + main + statusbar
5. Navegación entre pantallas (TABS simulados con CSS)

### Fase 2 — Componentes Core (Día 3-4)
6. `kpi-card.html` — tarjetas de indicadores
7. `data-table.html` — tabla con sort, filtro, paginación
8. `status-badge.html` — semáforos
9. `sidebar.html` — navegación completa
10. `modal.html` + `tabs.html` + `search-bar.html`

### Fase 3 — Gráficos SVG (Día 5-6)
11. `radar-chart.html` — radar 12 dominios
12. `bar-chart.html` — barras apiladas (login activity)
13. `gauge.html` — medidores CPU/RAM/Pool
14. `progress-bar.html` — barras semaforizadas

### Fase 4 — Árbol de Dominios (Día 7-9) ★ COMPONENTE CRÍTICO
15. `tree-node.html` — nodo individual con todos sus estados
16. `domain-tree.html` — árbol completo D1-D12 con datos demo
17. Panel lateral de resumen + formulario de detalle

### Fase 5 — Pantallas Técnicas (Día 10-12)
18. `01-dashboard.html` — dashboard completo con KPIs + radar + usuarios conectados
19. `02-role-list.html` — lista de roles con tabla
20. `03-role-editor.html` — editor con árbol D1-D12 + panel lateral
21. `04-user-list.html` — lista de usuarios
22. `05-user-editor.html` — editor de usuario con tabs
23. `06-policies.html` — grid de políticas de autenticación

### Fase 6 — Pantallas de Monitoreo (Día 13-15)
24. `07-sync.html` — sincronización KC+Tryton + timeline
25. `08-audit.html` — auditoría ISO 27001 con filtros
26. `09-bos-vision.html` — visión BOS (8 indicadores)
27. `10-session-detail.html` — detalle de sesión individual
28. `11-commercial.html` — panel comercial + firma digital

### Fase 7 — Pantallas de Negocio (Día 16-19) ★ NUEVO
29. Componentes: `company-card.html`, `branch-card.html`, `plan-gauge.html`, `usage-panel.html`
30. `12-tenant-profile.html` — perfil del tenant + plan + KYC
31. `13-companies.html` — CRUD de empresas (org_empresa)
32. `14-branches.html` — CRUD de sucursales por empresa
33. `15-pos-management.html` — puntos de venta (org_pos_logico)
34. `16-business-usage.html` — tracking de uso empresarial
35. `17-support.html` — soporte SBOS + onboarding

### Fase 8 — Estados y Polish (Día 20-22)
36. Estados: loading, empty, error en todos los componentes
37. Tema claro `[data-theme="light"]`
38. Responsive: 3 breakpoints
39. Teclado: todos los shortcuts globales
40. `preview/` cards con `@dsCard` para cada componente y pantalla
41. `index.html` unificado con navegación entre las 17 pantallas

---

## 10. GLOSARIO

| Término | Significado |
|---------|------------|
| **PAP** | Policy Administration Point — donde se administran políticas de acceso |
| **Dominio** | Uno de los 12 dominios de control (D1 Lógico a D12 Blockchain) |
| **RolTemplate** | Plantilla de rol en JSONB con 14 secciones |
| **UserTemplate** | Plantilla de usuario en JSONB con 16 secciones |
| **Átomo** | Unidad mínima de permiso. Posición en el BitMask de 64-bit |
| **FastPath** | Evaluación local de permisos en <0.5ns usando RolBitMask |
| **DRIFT** | Divergencia entre el estado declarado (bauth_db) y el real (KC+Tryton) |
| **SoD** | Separation of Duties — reglas de conflicto (creador ≠ aprobador) |
| **LoA** | Level of Assurance — AAL1 (bajo), AAL2 (medio), AAL3 (alto) |
| **ctx_id** | Identificador de contexto operativo (SBOS-049) |
| **BOS** | IAM Installer — instala y gobierna la capa de identidad |
| **KC** | Keycloak 26.6.2 — motor de autenticación |
| **VPS** | Virtual Private Server — 13.140.128.230 |

---

*DESIGN-DESKTOP-BAUTH.md v1.0.0 · 2026-06-28 · SKULL · SBOS*
*Elaborado por sbos-coordinador basado en PLAN-DESKTOP-BAUTH.md v3.0.0*
*Formato optimizado para Claude Design — compatible con `/design-sync` y DESIGN.md specification*
