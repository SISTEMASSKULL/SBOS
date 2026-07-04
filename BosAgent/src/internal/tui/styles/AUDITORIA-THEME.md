# AUDITORÍA THEME ABYSS + CATÁLOGO DE TOKENS

> **Versión:** 2.0 — 2026-06-15
> **Referencia:** SBOS-THEME-ABYSS.md v1.1.0
> **Alcance:** internal/tui/styles/ — 11 archivos

---

## PALETA COMPLETA — ABYSS

### Slate — Base neutral (fondos, texto, bordes)

| Paso | Hex | Muestra | Rol en TUI |
|------|-----|---------|-----------|
| 50 | #f8fafc | <span style="display:inline-block;width:48px;height:14px;background:#f8fafc;border-radius:3px;border:1px solid #333;"></span> | — |
| 100 | #f1f5f9 | <span style="display:inline-block;width:48px;height:14px;background:#f1f5f9;border-radius:3px;border:1px solid #333;"></span> | Texto principal (headings, datos) |
| 200 | #e2e8f0 | <span style="display:inline-block;width:48px;height:14px;background:#e2e8f0;border-radius:3px;border:1px solid #333;"></span> | Texto secundario activo |
| 300 | #cbd5e1 | <span style="display:inline-block;width:48px;height:14px;background:#cbd5e1;border-radius:3px;border:1px solid #333;"></span> | — |
| 400 | #94a3b8 | <span style="display:inline-block;width:48px;height:14px;background:#94a3b8;border-radius:3px;"></span> | Texto secundario (labels, timestamps) |
| 500 | #64748b | <span style="display:inline-block;width:48px;height:14px;background:#64748b;border-radius:3px;"></span> | Texto muted / placeholders |
| 600 | #475569 | <span style="display:inline-block;width:48px;height:14px;background:#475569;border-radius:3px;"></span> | Texto deshabilitado |
| 700 | #334155 | <span style="display:inline-block;width:48px;height:14px;background:#334155;border-radius:3px;"></span> | Bordes de input |
| 800 | #1e293b | <span style="display:inline-block;width:48px;height:14px;background:#1e293b;border-radius:3px;"></span> | Bordes principales / separadores |
| 900 | #0f172a | <span style="display:inline-block;width:48px;height:14px;background:#0f172a;border-radius:3px;"></span> | Paneles / bloques / sidebar |
| 950 | #020617 | <span style="display:inline-block;width:48px;height:14px;background:#020617;border-radius:3px;"></span> | Fondo raíz del terminal |

### Cyan — Acento único (cursor, foco, acción, señal positiva)

| Paso | Hex | Muestra | Rol en TUI |
|------|-----|---------|-----------|
| 50 | #ecfeff | <span style="display:inline-block;width:48px;height:14px;background:#ecfeff;border-radius:3px;border:1px solid #333;"></span> | — |
| 100 | #cffafe | <span style="display:inline-block;width:48px;height:14px;background:#cffafe;border-radius:3px;border:1px solid #333;"></span> | — |
| 200 | #a5f3fc | <span style="display:inline-block;width:48px;height:14px;background:#a5f3fc;border-radius:3px;border:1px solid #333;"></span> | — |
| 300 | #67e8f9 | <span style="display:inline-block;width:48px;height:14px;background:#67e8f9;border-radius:3px;border:1px solid #333;"></span> | Texto en badge oscuro |
| 400 | #22d3ee | <span style="display:inline-block;width:48px;height:14px;background:#22d3ee;border-radius:3px;"></span> | Texto sobre acento / valor positivo |
| 500 | #06b6d4 | <span style="display:inline-block;width:48px;height:14px;background:#06b6d4;border-radius:3px;"></span> | **Acento principal** — cursor, foco, CTA |
| 600 | #0891b2 | <span style="display:inline-block;width:48px;height:14px;background:#0891b2;border-radius:3px;"></span> | Hover/pressed |
| 700 | #0e7490 | <span style="display:inline-block;width:48px;height:14px;background:#0e7490;border-radius:3px;"></span> | Barra media / sparklines |
| 800 | #155e75 | <span style="display:inline-block;width:48px;height:14px;background:#155e75;border-radius:3px;"></span> | Border badges activos |
| 900 | #164e63 | <span style="display:inline-block;width:48px;height:14px;background:#164e63;border-radius:3px;"></span> | Fondo badges / bg selección |
| 950 | #083344 | <span style="display:inline-block;width:48px;height:14px;background:#083344;border-radius:3px;"></span> | — |

> **Regla cardinal (§5 del spec):** Cyan-500 #06b6d4 es el acento para cursor, foco, ítem activo. Cyan-400 #22d3ee SOLO para texto sobre fondo cyan y valor positivo/delta.

---

## 0. ARQUITECTURA DEL SISTEMA

```
CAPA 1  — tokens_primitive.go    (const)   Paletas Tailwind 50–950. NUNCA se usan en pantallas.
CAPA 2A — tokens_state.go        (const)   Colores de estado perceptuales. NUNCA se tematizan.
CAPA 2B — tokens_semantic.go     (var)     Tokens de intención. MUTABLES por ApplyTheme().
CAPA 3  — tokens_component.go    (var)     Estilos lipgloss. RECONSTRUIDOS por rebuildThemeComponents().
```

**Regla de oro:** Una pantalla NUNCA usa lipgloss.NewStyle() inline. Solo consume tokens de Capa 3.

---

## 1. PALETA ABYSS — Verificación de valores

| Token semántico | Hex | Muestra | Primitive | Spec | ¿OK? |
|----------------|-----|---------|-----------|------|------|
| ColorAccent → ColorCyan | #06b6d4 | <span style="display:inline-block;width:36px;height:12px;background:#06b6d4;border-radius:50%;"></span> | PrimCyan500 | cyan-500 | ✅ |
| ColorAccentText | #22d3ee | <span style="display:inline-block;width:36px;height:12px;background:#22d3ee;border-radius:50%;"></span> | PrimCyan400 | cyan-400 | ✅ |
| ColorMenuActiveBg | #164e63 | <span style="display:inline-block;width:36px;height:12px;background:#164e63;border-radius:50%;"></span> | PrimCyan900 | cyan-900 | ✅ |
| ColorBgBase | #020617 | <span style="display:inline-block;width:36px;height:12px;background:#020617;border-radius:50%;"></span> | PrimSlate950 | slate-950 | ✅ |
| ColorBgSurface | #0f172a | <span style="display:inline-block;width:36px;height:12px;background:#0f172a;border-radius:50%;"></span> | PrimSlate900 | slate-900 | ✅ |
| ColorBgElevated / ColorBorder | #1e293b | <span style="display:inline-block;width:36px;height:12px;background:#1e293b;border-radius:50%;"></span> | PrimSlate800 | slate-800 | ✅ |
| ColorTextPrimary | #f1f5f9 | <span style="display:inline-block;width:36px;height:12px;background:#f1f5f9;border-radius:50%;border:1px solid #333;"></span> | PrimSlate100 | slate-100 | ✅ |
| ColorTextSecondary | #94a3b8 | <span style="display:inline-block;width:36px;height:12px;background:#94a3b8;border-radius:50%;"></span> | PrimSlate400 | slate-400 | ✅ |
| ColorTextDisabled | #475569 | <span style="display:inline-block;width:36px;height:12px;background:#475569;border-radius:50%;"></span> | PrimSlate600 | slate-600 | ✅ |
| ColorTopBarBg | #020617 | <span style="display:inline-block;width:36px;height:12px;background:#020617;border-radius:50%;"></span> | PrimSlate950 | — | ✅ |

**Conclusión: Los 10 tokens de Abyss coinciden 1:1 con el spec.** El problema no son los valores, sino qué token se asigna a cada componente.

---

## 2. CATÁLOGO COMPLETO DE TOKENS DE COMPONENTE (Capa 3)

### 2.1 Texto — Escala tipográfica

| Estilo | Token | Hex | Muestra | Rol |
|--------|-------|-----|---------|-----|
| White | ColorTextPrimary | #f1f5f9 | <span style="display:inline-block;width:36px;height:12px;background:#f1f5f9;border-radius:50%;border:1px solid #333;"></span> | Títulos, headers, datos importantes |
| Muted | ColorTextSecondary | #94a3b8 | <span style="display:inline-block;width:36px;height:12px;background:#94a3b8;border-radius:50%;"></span> | Etiquetas, timestamps, texto secundario |
| Dim | ColorTextDisabled | #475569 | <span style="display:inline-block;width:36px;height:12px;background:#475569;border-radius:50%;"></span> | Hints, placeholders, texto decorativo |
| AccentBold | ColorCyan | #06b6d4 | <span style="display:inline-block;width:36px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Texto activo negrita |
| TableHeader | ColorTextPrimary | #f1f5f9 | <span style="display:inline-block;width:36px;height:12px;background:#f1f5f9;border-radius:50%;border:1px solid #333;"></span> | Encabezados de tabla |

### 2.2 Acento — Cyan (el único acento del tema)

| Estilo | Token | Hex | Muestra | Rol |
|--------|-------|-----|---------|-----|
| Cyan | ColorCyan | #06b6d4 | <span style="display:inline-block;width:36px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Color de acento base |
| TabActive | ColorCyan | #06b6d4 | <span style="display:inline-block;width:36px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Tab/pestaña activa |
| ResourceName | ColorCyan | #06b6d4 | <span style="display:inline-block;width:36px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Nombre de recurso |
| AccentBar | ColorCyan | #06b6d4 | <span style="display:inline-block;width:36px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Barra de progreso |

### 2.3 Superficies y Contenedores

| Estilo | Foreground | Background | Border | Rol |
|--------|-----------|------------|--------|-----|
| Box | — | — | ColorBorder #1e293b | Caja normal |
| BoxActive | — | — | ColorCyan #06b6d4 | Caja con foco |
| Panel | ColorTextPrimary | ColorBgSurface #0f172a | ColorBorder | Panel |
| Rule | ColorBorder #1e293b | — | — | Línea horizontal |

### 2.4 Menú de Navegación

| Estilo | Foreground | Background | Rol |
|--------|-----------|------------|-----|
| MenuItemActive | 🔴 ColorAccentText #22d3ee | ColorMenuActiveBg #164e63 | Item activo dashboard |
| MenuItemFocused | ColorTextPrimary #f1f5f9 | — | Item con foco |
| MenuItemNormal | ColorTextSecondary #94a3b8 | — | Item normal |
| ListItemActive | 🔴 ColorAccentText #22d3ee | ColorMenuActiveBg #164e63 | Item activo lista |

> 🔴 **BUG #1:** MenuItemActive.Foreground y ListItemActive.Foreground usan ColorAccentText (#22d3ee, cyan brillante). El spec §5 dice que cursor/foco/activo debe usar ColorAccent (#06b6d4, cyan-500). Cambiar a ColorCyan.

### 2.5 Formularios e Inputs

| Estilo | Foreground | Background | Border | Rol |
|--------|-----------|------------|--------|-----|
| InputActive | — | ColorBgBase #020617 | ColorCyan #06b6d4 | Input con foco |
| InputInactive | — | ColorBgBase #020617 | ColorBorder #1e293b | Input normal |
| Label | ColorTextDisabled #475569 | — | — | Etiqueta |
| LabelActive | ColorCyan #06b6d4 | — | — | Etiqueta activa |
| SectionTitle | ColorTextSecondary #94a3b8 | — | — | Título de sección |

### 2.6 Pasos de Instalación (Stepper)

| Estilo | Foreground | Rol |
|--------|-----------|-----|
| StepOK | ColorCyan #06b6d4 | Paso completado |
| StepActive | ColorCyan #06b6d4 (bold) | Paso en progreso |
| StepPending | ColorTextDisabled #475569 | Paso pendiente |

### 2.7 Barras de Estado y Layout

| Estilo | Foreground | Background | Rol |
|--------|-----------|------------|-----|
| TopBar | ColorCyan #06b6d4 | ColorTopBarBg #020617 | Barra superior |
| Footer | ColorTextSecondary | ColorBgSurface #0f172a | Barra inferior |

### 2.8 Scroll

| Estilo | Foreground | Rol |
|--------|-----------|-----|
| ScrollTrack | ColorTextDisabled #475569 | Track del scrollbar |
| ScrollThumb | ColorCyan #06b6d4 | Thumb del scrollbar |

### 2.9 Colores de Estado (NO se tematizan)

| Estilo | Token | Hex | Muestra | Rol |
|--------|-------|-----|---------|-----|
| Success | ColorStateOKFg | #2dd4a2 | <span style="display:inline-block;width:36px;height:12px;background:#2dd4a2;border-radius:50%;"></span> | Éxito, completado |
| Warning | ColorStateWarnFg | #f9c84a | <span style="display:inline-block;width:36px;height:12px;background:#f9c84a;border-radius:50%;"></span> | Advertencia |
| Error | ColorStateErrFg | #f87474 | <span style="display:inline-block;width:36px;height:12px;background:#f87474;border-radius:50%;"></span> | Error |
| Critical | ColorStateCritFg | #ff5555 | <span style="display:inline-block;width:36px;height:12px;background:#ff5555;border-radius:50%;"></span> | Crítico, destructivo |
| Pending | ColorStateIdleFg | #9ea9f8 | <span style="display:inline-block;width:36px;height:12px;background:#9ea9f8;border-radius:50%;"></span> | En progreso |
| StatusOK | ColorStateOKFg | #2dd4a2 | <span style="display:inline-block;width:36px;height:12px;background:#2dd4a2;border-radius:50%;"></span> | Estado operativo (sin bold) |
| StatusErr | ColorStateErrFg | #f87474 | <span style="display:inline-block;width:36px;height:12px;background:#f87474;border-radius:50%;"></span> | Estado error (sin bold) |

### 2.10 Adaptador huh — huh_theme.go

| Elemento huh | Token usado | Hex | Muestra | Rol |
|-------------|------------|-----|---------|-----|
| Título campo (focus) | ColorCyan | #06b6d4 | <span style="display:inline-block;width:36px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Título del campo activo |
| Selector (> ) | ColorCyan | #06b6d4 | <span style="display:inline-block;width:36px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Indicador de selección |
| Botón enfocado | bg:ColorCyan | #06b6d4 | <span style="display:inline-block;width:36px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Botón activo |
| Cursor textinput | ColorStateOKFg | #2dd4a2 | <span style="display:inline-block;width:36px;height:12px;background:#2dd4a2;border-radius:50%;"></span> | Cursor de texto |
| Placeholder | ColorTextDisabled | #475569 | <span style="display:inline-block;width:36px;height:12px;background:#475569;border-radius:50%;"></span> | Texto placeholder |
| Error indicator | ColorStateErrFg | #f87474 | <span style="display:inline-block;width:36px;height:12px;background:#f87474;border-radius:50%;"></span> | Indicador de error |
| Prefix seleccionado (✓) | ColorStateOKFg | #2dd4a2 | <span style="display:inline-block;width:36px;height:12px;background:#2dd4a2;border-radius:50%;"></span> | Checkmark de selección |
| Prefix no seleccionado (•) | ColorTextDisabled | #475569 | <span style="display:inline-block;width:36px;height:12px;background:#475569;border-radius:50%;"></span> | Bullet inactivo |

---

## 3. BUGS ENCONTRADOS

### 🔴 BUG #1 — ColorAccentText donde debe ir ColorCyan

**Archivo:** theme.go — rebuildThemeComponents()

```go
// ACTUAL (incorrecto):
MenuItemActive = lipgloss.NewStyle().
    Foreground(ColorAccentText).  // ← #22d3ee (cyan brillante)
    Background(ColorMenuActiveBg)

ListItemActive = lipgloss.NewStyle().
    Foreground(ColorAccentText).  // ← #22d3ee (cyan brillante)
    Background(ColorMenuActiveBg).
    BorderLeft(true).BorderForeground(ColorCyan).PaddingLeft(1)

// CORRECTO según spec §5:
MenuItemActive = lipgloss.NewStyle().
    Foreground(ColorCyan).        // ← #06b6d4 (cyan-500)
    Background(ColorMenuActiveBg)

ListItemActive = lipgloss.NewStyle().
    Foreground(ColorCyan).        // ← #06b6d4 (cyan-500)
    Background(ColorMenuActiveBg).
    BorderLeft(true).BorderForeground(ColorCyan).PaddingLeft(1)
```

**Afecta:** MenuItemActive, ListItemActive
**Efecto visual:** Texto de menú activo se ve cyan brillante/celeste en vez de cyan oscuro.

### 🟡 BUG #2 — ColorTextPrimary muy claro para cuerpo de texto

ColorTextPrimary = #f1f5f9 (slate-100). Correcto por spec, pero en el TUI hay MUCHO texto (logs, estados, labels). Usar slate-100 para todo cansa la vista.

---

## 4. PROPUESTA DE CORRECCIÓN

### 4.1 🔴 CRÍTICO — ColorAccentText → ColorCyan en menú activo

**Archivo:** theme.go — rebuildThemeComponents()
**Cambio:** 2 líneas. ColorAccentText → ColorCyan en MenuItemActive.Foreground y ListItemActive.Foreground.

### 4.2 🟡 — Nuevo token TextHeading para títulos

Agregar TextHeading al struct Theme. Usar slate-50 (#f8fafc) para títulos, bajar TextPrimary a slate-200 (#e2e8f0) para cuerpo.

```go
// theme.go — struct Theme (agregar campo)
TextHeading lipgloss.Color // títulos y headers (más brillante que el cuerpo)

// theme.go — entrada "abyss" (ajustar)
TextHeading:   lipgloss.Color(PrimSlate50),   // #f8fafc — solo títulos
TextPrimary:   lipgloss.Color(PrimSlate200),  // #e2e8f0 — cuerpo de texto
TextSecondary: lipgloss.Color(PrimSlate400),  // #94a3b8 — sin cambio
TextDisabled:  lipgloss.Color(PrimSlate600),  // #475569 — sin cambio
```

### 4.3 🟢 — Completar tokens para bordes y formularios

```go
// NUEVOS en tokens_component.go (reconstruidos en rebuildThemeComponents)
BorderFocus   = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorCyan)
BorderError   = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorStateErrFg)
BorderSuccess = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorStateOKFg)

InputNormal  = lipgloss.NewStyle().Border(lipgloss.NormalBorder()).BorderForeground(ColorBorder)
InputFocus   = lipgloss.NewStyle().Border(lipgloss.NormalBorder()).BorderForeground(ColorCyan)
InputError   = lipgloss.NewStyle().Border(lipgloss.NormalBorder()).BorderForeground(ColorStateErrFg)

Divider      = lipgloss.NewStyle().Foreground(ColorBorder)
HRule        = lipgloss.NewStyle().Foreground(ColorBorder).SetString("─")
```

### 4.4 🟢 — Mejorar huh_theme.go con bordes

```go
// huh_theme.go — HuhTheme()
t.Focused.Base = t.Focused.Base.
    BorderForeground(ColorCyan).    // borde cyan en campo focus
    BorderLeft(true).
    PaddingLeft(1)
```

---

## 5. RESUMEN DE CAMBIOS

| # | Prioridad | Archivos | Líneas | Impacto |
|---|----------|---------|--------|---------|
| 1 | 🔴 CRÍTICO | theme.go | 2 | Corrige "cyanes celestes" en menús |
| 2 | 🟡 MEJORA | theme.go + tokens_semantic.go + tokens_component.go | ~15 | Reduce "mucho blanco" en texto |
| 3 | 🟢 COMPLETAR | tokens_component.go + theme.go | ~20 | Bordes y formularios completos |
| 4 | 🟢 MEJORA | huh_theme.go | 1 | Campos huh con borde de foco |