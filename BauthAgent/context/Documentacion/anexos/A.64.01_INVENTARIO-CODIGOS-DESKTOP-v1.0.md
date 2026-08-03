# A.64.01 — Inventario de Códigos: Desktop bAuth
## Referencia rápida · secciones · objetos · widgets · slots

**Versión:** 1.0.0  
**Fecha:** 2026-08-03  
**Autor:** bauth-developer  
**Complementa:** `A.64_ANEXO-MAQUETAS-DESKTOP-v1.0.md` (maquetas + estados Living Spec)

---

## §1 · Sistema de códigos

### 1.1 Prefijos

| Prefijo | Tipo | Pregunta que responde |
|---------|------|-----------------------|
| `G-XX` | Sección del shell global | ¿En qué bloque del shell? |
| `V-XX` | Vista (pantalla) | ¿En qué pantalla? |
| `G-XX-NNN` | Objeto dentro de un bloque global | ¿Qué elemento concreto del shell? |
| `V-XX-NNN` | Objeto dentro de una vista | ¿Qué elemento concreto de esa pantalla? |
| `W-NNN` | Widget reutilizable (≥2 vistas) | ¿Qué clase Dart lo implementa? |
| `DL-NNN` | Diálogo / Modal | ¿Qué diálogo? |
| `PR-NNN` | Provider Riverpod | ¿Qué estado gestiona? |

### 1.2 Distinción objeto vs widget

Un **objeto** (`G-XX-NNN` / `V-XX-NNN`) nombra una posición o elemento **dentro de una sección
o vista específica**. Un **widget** (`W-NNN`) nombra la **clase Dart** que lo implementa y que
puede reutilizarse en 2 o más vistas distintas.

```
V-DS-005  →  "la tarjeta KPI que está en el Dashboard"   (posición)
W-001     →  "la clase TarjetaKpi"                        (implementación)
```

Cuando el usuario dice **"modifica V-DS-005"** → hablamos de layout/posición en esa vista.  
Cuando el usuario dice **"modifica W-001"** → hablamos del componente Dart directamente.

### 1.3 Notación de slots (posición estructural)

Los slots son **regiones dentro de un bloque o vista** — no son widgets, son coordenadas
de posición. Se usan en la ruta de path para ubicar exactamente dónde está un objeto.

| Abrev. | Slot |
|--------|------|
| `TOP` | Cabecera del bloque (fija, no hace scroll) |
| `BOD` | Cuerpo (scrollable) |
| `BOT` | Pie del bloque (fijo) |
| `OUT` | Outlet — área de contenido dinámico (flex 1) |
| `BB` | BarraBreadcrumb |
| `SB` | BarraEstado (StatusBar) |
| `P1` `P2` `P3` | Panel 1, 2, 3 dentro de un outlet |
| `B1` `B2` | Bloque izquierdo / derecho dentro de un outlet |
| `T1` `T2` `T3` | Tab 1, 2, 3 |
| `DET` | Panel Detalle |
| `TB` | Toolbar |

### 1.4 Sintaxis de ruta

```
CÓDIGO:SLOT>SLOT>SLOT
```

Ejemplos de uso en conversación:

| Ruta | Significa |
|------|-----------|
| `G-BC:TOP` | BarraSuperior del bloque central |
| `G-BC:OUT` | El outlet — donde viven las vistas |
| `V-RT:OUT>P1>TB` | Toolbar del Panel 1 en Rol Template |
| `V-RT:OUT>P1>BOT` | FichaIdentidadNodo (pie del Panel 1) |
| `V-CR:OUT>B2>T2` | Tab Átomos del panel derecho en Completitud de Roles |
| `V-US:OUT>B1>TOP` | BuscadorUsuarios en la lista de usuarios |
| `V-AE:OUT>B2>DET` | FichaEntidad en el panel detalle del árbol |

---

## §2 · Mapa de secciones

### Bloques del shell (G-)

| Código | Nombre | Archivo Dart | Estado |
|--------|--------|-------------|--------|
| `G-SH` | Shell global (scaffold) | `nucleo/shell/shell_principal.dart` | EN DESARROLLO |
| `G-SN` | Sidenav — bloque izquierdo (248 px / 76 px colapsado) | `nucleo/shell/bloques/bloque_lateral_izquierdo.dart` | EN DESARROLLO |
| `G-BC` | Bloque Central — TOP/BB/OUT/SB/BOT | `nucleo/shell/bloques/bloque_central.dart` | EN DESARROLLO |
| `G-BD` | Bloque Derecho — panel de acciones (300 px / 76 px) | `nucleo/shell/bloques/bloque_lateral_derecho.dart` | MAQUETA |

### Vistas (V-)

| Código | Nombre | Ruta Flutter | Archivo Dart | Estado A.64 |
|--------|--------|-------------|--------------|-------------|
| `V-DS` | Dashboard de Salud | `dashboard` | `vistas/vista_dashboard.dart` | EN DESARROLLO |
| `V-RT` | Rol Template AtomLang | `rtpl` | `vistas/vista_rol_template.dart` | EN DESARROLLO |
| `V-CR` | Completitud de Roles | `roles` | `vistas/vista_roles.dart` | EN DISEÑO |
| `V-US` | Usuarios IAM | `usuarios` | `vistas/vista_usuarios.dart` | EN DESARROLLO |
| `V-AE` | Árbol de Entidades | `identidad` | `vistas/vista_entidades.dart` | EN DESARROLLO |
| `V-UT` | User Template | `utpl` | — | POSTERGADO |
| `V-MT` | Métodos | `metodos` | — | POSTERGADO |
| `V-DM` | Dominios | `dominios` | — | POSTERGADO |
| `V-SY` | Sincronización | `sync` | — | POSTERGADO |
| `V-AU` | Auditoría | `auditoria` | — | POSTERGADO |
| `V-CF` | Configuración | `config` | — | POSTERGADO |

---

## §3 · Árbol de slots

```
G-SH
├── G-SN                              `G-SN`
│   ├── :TOP   EncabezadoNav          `G-SN:TOP`
│   ├── :BOD   Lista de ítems         `G-SN:BOD`
│   └── :BOT   PieNav (daemon)        `G-SN:BOT`
│
├── G-BC                              `G-BC`
│   ├── :TOP   BarraSuperior 48px     `G-BC:TOP`
│   ├── :BB    BarraBreadcrumb 40px   `G-BC:BB`
│   ├── :OUT   Outlet → vista activa  `G-BC:OUT`
│   ├── :SB    BarraEstado 30px       `G-BC:SB`
│   └── :BOT   BarraInferior 30px     `G-BC:BOT`
│
└── G-BD                              `G-BD`
    ├── :TOP   SelectorContexto       `G-BD:TOP`
    ├── :BOD   Contenido contextual   `G-BD:BOD`
    └── :BOT   EstadoSesion           `G-BD:BOT`

─ Vistas activas en G-BC:OUT ─────────────────────────────────────────

V-DS (plano)                          `V-DS`
├── Cabecera                          `V-DS-001`
└── RejillaKpis                       `V-DS-004`

V-RT (plano)                          `V-RT`
├── SelectorRolActivo                 `V-RT-001`
├── :P1   Panel Identidad             `V-RT:P1`
│   ├── :TB   Toolbar                 `V-RT:P1>TB`
│   └── :BOT  FichaIdentidadNodo      `V-RT:P1>BOT`
├── :P2   Panel RolTemplate           `V-RT:P2`
│   └── ArbolAtomLang                 `V-RT-007`
├── :P3   Panel Compilado             `V-RT:P3`
└── :BOT  BarraRutaNodo               `V-RT:BOT`

V-CR (plano)                          `V-CR`
├── :B1   BloqueLista 340px           `V-CR:B1`
│   └── :TOP  BarraTiers              `V-CR:B1>TOP`
└── :B2   PanelDetalle                `V-CR:B2`
    ├── :TOP  NombreRolActivo         `V-CR:B2>TOP`
    ├── :OUT  OutletRol (tabs)        `V-CR:B2>OUT`
    │   ├── :T1  Tab Métodos          `V-CR:B2>T1`
    │   ├── :T2  Tab Átomos           `V-CR:B2>T2`
    │   └── :T3  Tab Saga Auth        `V-CR:B2>T3`
    └── :BOT  Acciones                `V-CR:B2>BOT`

V-US (plano)                          `V-US`
├── :B1   BloqueLista 320px           `V-US:B1`
│   └── :TOP  BuscadorUsuarios        `V-US:B1>TOP`
└── :B2   PanelDetalle                `V-US:B2`
    └── :DET  FichaUsuario            `V-US:B2>DET`

V-AE (plano)                          `V-AE`
├── :B1   BloqueArbol 340px           `V-AE:B1`
│   └── :TOP  CabeceraArbol           `V-AE:B1>TOP`
└── :B2   PanelDetalle                `V-AE:B2`
    └── :DET  FichaEntidad            `V-AE:B2>DET`
```

---

## §4 · Objetos por sección

### G-SN — Sidenav

```
G-SN:TOP
┌─────────────────────────────────────┐
│ ╔══╗  bAuth          ← G-SN-001     │
│ ╚══╝  Control Plane                 │
├─────────────────────────────────────┤
G-SN:BOD
│  GENERAL            ← G-SN-002      │
│  ⊞ Dashboard        ← G-SN-003      │  W-002
│  👥 Usuarios  [89]  ← G-SN-003  G-SN-004
│                                     │
│  TEMPLATES          ← G-SN-002      │
│  🛡  Roles  [366]   ← G-SN-003  G-SN-004
│  …                                  │
│  ● Sincronización ●✓← G-SN-003  G-SN-005
│         ─────────   ← G-SN-007      │
│  ⊞  Configuración   ← G-SN-003      │
├─────────────────────────────────────┤
G-SN:BOT
│ ● Daemon operativo  ← G-SN-006      │
│   v0.9.0 · 99.9%                    │
└─────────────────────────────────────┘
```

| Código | Nombre | Descripción |
|--------|--------|-------------|
| `G-SN-001` | EncabezadoNav | Logo (🛡️) + "bAuth / Control Plane" + toggle colapsar sidenav |
| `G-SN-002` | GrupoNav | Etiqueta de grupo: GENERAL / TEMPLATES / CRUD / IDENTIDAD / SISTEMA / CUENTA |
| `G-SN-003` | ÍtemNav | Ítem individual: icono + etiqueta + badge + punto de estado → `W-002` |
| `G-SN-004` | BadgeContador | Chip numérico a la derecha del ítem: `[366]` `[1.2k]` |
| `G-SN-005` | PuntoEstado | Círculo 7px al final del ítem: verde `●✓` / ámbar `●⚠` |
| `G-SN-006` | PieNav | Estado daemon + versión + uptime (monospace, muted) |
| `G-SN-007` | SeparadorNav | Línea `─────` que separa el ítem Configuración del resto |

---

### G-BC — Bloque Central

```
G-BC:TOP [G-BC-001]
┌─────────────────────────────────────────────────────────────────┐
│  [G-BC-002]  [G-BC-003 W-010]     [G-BC-004] [G-BC-005] [G-BC-006] [G-BC-007 W-005]
│   [≪/≫]       🔍 Buscar… ⌘K        ●9450       [☀]        [🔔]        [SA ▾]
└─────────────────────────────────────────────────────────────────┘

G-BC:BB [G-BC-009]
┌─────────────────────────────────────────────────────────────────┐
│  Control Plane  /  Dashboard de Salud                            │
└─────────────────────────────────────────────────────────────────┘

G-BC:OUT  → vista activa

G-BC:SB [G-BC-010]
┌─────────────────────────────────────────────────────────────────┐
│ ● Conectado WebSocket · 12ms │ ● Reconcile · hace 3m │ ⚠ 1 drift  … 366 roles│
└─────────────────────────────────────────────────────────────────┘
```

| Código | Nombre | Descripción |
|--------|--------|-------------|
| `G-BC-001` | BarraSuperior | Contenedor fijo 48px en TOP del bloque central |
| `G-BC-002` | ToggleSidenav | Botón `[≪]`/`[≫]` — colapsa/expande G-SN |
| `G-BC-003` | BuscadorGlobal | Input fondo muted, icono lupa, placeholder, atajo `⌘K` → `W-010` |
| `G-BC-004` | ChipConexion | `● 9450` — punto verde + host:puerto monospace |
| `G-BC-005` | ToggleTema | Botón `[☀]`/`[🌙]` — alterna tema claro/oscuro |
| `G-BC-006` | Campanilla | Botón `[🔔]` + punto rojo si hay alerta crítica pendiente |
| `G-BC-007` | AvatarMenu | Avatar gradiente + nombre + rol + `[▾]` → abre `G-BC-008` · usa `W-005` |
| `G-BC-008` | MenuUsuarioDesplegable | Popup flotante: avatar · nombre · rol · Mi perfil · Cambiar usuario · Registrar · Iniciar sesión · Cerrar sesión |
| `G-BC-009` | BarraBreadcrumb | Ruta activa (40px): "Control Plane / Vista actual" — muted / bold |
| `G-BC-010` | BarraEstado | Segmentos izq→der: conexión · reconcile · drift · spacer · métricas (30px) |
| `G-BC-011` | BarraInferior | Reservada — 30px (contenido TBD) |

---

### G-BD — Bloque Derecho

```
G-BD:TOP [G-BD-001]
┌──────────────────────────────┐
│  [ ⚙ Configuración      ▾ ] │
├──────────────────────────────┤
G-BD:BOD
│  G-BD-002  PanelConfig       │  (cuando selector = Configuración)
│  G-BD-003  PanelHerramientas │  (cuando selector = Herramientas)
│  G-BD-004  PanelAtomLang     │  (cuando selector = AtomLang)
│  G-BD-005  PanelUso          │  (cuando selector = Uso 24h)
│  G-BD-006  PanelAyuda        │  (cuando selector = Ayuda)
│  G-BD-007  ConfirmarSalir    │  (cuando selector = Salir)
├──────────────────────────────┤
G-BD:BOT [G-BD-008]
│  ● Sesión activa · 2h 14m   │
└──────────────────────────────┘
```

| Código | Nombre | Descripción |
|--------|--------|-------------|
| `G-BD-001` | SelectorContexto | Dropdown: ⚙ Config / 🔧 Herr / 🔷 AtomLang / 📈 Uso / ❓ Ayuda / ✕ Salir |
| `G-BD-002` | PanelConfig | Tema · Idioma · Servidor · Puerto · Timeout · Notificaciones |
| `G-BD-003` | PanelHerramientas | Paleta AtomLang — contextual según vista activa en G-BC:OUT (A.64 §4.4) |
| `G-BD-004` | PanelAtomLang | Log compilación `atomc` (estados 1–4) + Compilar / Recompilar / Publicar |
| `G-BD-005` | PanelUso | Métricas 24h: evaluaciones · tokens · FastPath · sesiones · roles |
| `G-BD-006` | PanelAyuda | Links: Documentación · Atajos · Reportar problema · versión bAuth |
| `G-BD-007` | ConfirmarSalir | "¿Confirmar cierre de sesión?" + `[Cerrar sesión]` + `[Cancelar]` |
| `G-BD-008` | EstadoSesion | `● Sesión activa · 2h 14m` (pie del bloque, fijo) |

---

### V-DS — Dashboard de Salud

```
V-DS
┌── OUTLET ───────────────────────────────────────────────────────┐
│                                                                 │
│  Dashboard de Salud          [V-DS-002 W-008] [V-DS-003]       │
│  Identity Control Plane …    OPERACIONAL       En vivo│7d│30d  │
│                              ← V-DS-001 ─────────────────────→ │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  …      │
│  │ V-DS-005     │  │ V-DS-005     │  │ V-DS-005     │         │
│  │ W-001        │  │ W-001        │  │ W-001        │         │
│  │ 👥 1.247     │  │ 🛡 366       │  │ ✓ 5.808      │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│  ← V-DS-004 (Row con Expanded por tarjeta) ─────────────────→ │
└─────────────────────────────────────────────────────────────────┘
```

| Código | Nombre | Descripción |
|--------|--------|-------------|
| `V-DS-001` | Cabecera | Row: título/subtítulo izquierda + `V-DS-002` + `V-DS-003` derecha |
| `V-DS-002` | BadgeEnVivo | Badge "● OPERACIONAL" borde+fondo coloreado por estado → `W-008` |
| `V-DS-003` | SelectorRango | Tres botones agrupados: En vivo / 7d / 30d (visual, sin filtro de API aún) |
| `V-DS-004` | RejillaKpis | Row de 6 `TarjetaKpi` con `Expanded` cada una |
| `V-DS-005` | TarjetaKpi | Card: icono + etiqueta + valor grande + unidad + nota con tono → `W-001` |

---

### V-RT — Rol Template AtomLang

```
V-RT
┌── OUTLET ───────────────────────────────────────────────────────┐
│  [GERENTE_VENTAS ▾]  ← V-RT-001                                 │
│                                                                 │
│  ┌─ V-RT:P1 ──────────┐  ┌─ V-RT:P2 ──────────┐  ┌─V-RT:P3─┐ │
│  │ V-RT:P1>TB          │  │ V-RT:P2             │  │V-RT-008 │ │
│  │ [V-RT-003] [+Átomo] │  │ V-RT-007            │  │         │ │
│  │─────────────────────│  │ árbol AtomLang       │  │ BitMask │ │
│  │ V-RT-004   W-006    │  │                     │  │ átomos  │ │
│  │ ▼ [SU] SuperUsuario │  │ ▼ D00 [POLICYSET]   │  │         │ │
│  │   ▼ GERENTE_VENTAS  │  │   ▼ D01 [POLICYSET] │  │FastPath │ │
│  │─────────────────────│  │  ●── [REGLA] Permit  │  └─────────┘ │
│  │ V-RT:P1>BOT         │  │      V-RT-010       │             │
│  │ V-RT-005            │  └─────────────────────┘             │
│  └─────────────────────┘                                       │
│                                                                 │
│  ┌─ V-RT:BOT ──────────────────────────────── [Copiar] ──────┐ │
│  │  D01 › B6 › [REGLA] aprobacion_t1    ← V-RT-009           │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

| Código | Nombre | Descripción |
|--------|--------|-------------|
| `V-RT-001` | SelectorRolActivo | Dropdown: elige el RolTemplate a editar (GERENTE_VENTAS▾) |
| `V-RT-003` | ToolbarP1 | Barra `V-RT:P1>TB`: buscador inline + `[+ Nuevo rol]` + `[+ Átomo]` |
| `V-RT-004` | ArbolRoles | Árbol jerárquico `idn_role_template`: 5 niveles · tier badge · enlace cruzado → usa `W-006` por nodo |
| `V-RT-005` | FichaIdentidadNodo | `V-RT:P1>BOT`: campos del nodo seleccionado + `[Editar]` `[Retirar]` |
| `V-RT-007` | ArbolAtomLang | Árbol `.atm.yaml`: nodos POLICYSET/POLICY/REGLA/REGISTRO con linter inline → usa `W-006` |
| `V-RT-008` | Panel3Compilado | RolBitMask one-hot + lista átomos compilados + FastPath ✓/✗ |
| `V-RT-009` | BarraRutaNodo | `V-RT:BOT`: ruta del nodo seleccionado (breadcrumb nodo) + `[Copiar]` |
| `V-RT-010` | EnlaceCruzado | Indicador visual `●──` entre nodo P1 y regla P2 que lo referencia vía SET |

---

### V-CR — Completitud de Roles

```
V-CR
┌── OUTLET ───────────────────────────────────────────────────────┐
│  ┌── V-CR:B1 340px ─────────────┐  ┌── V-CR:B2 flex1 ─────────┐│
│  │ V-CR:B1>TOP                   │  │ V-CR:B2>TOP               ││
│  │ V-CR-002 BarraTiers           │  │ V-CR-007 NombreRolActivo  ││
│  │[TODOS][SU][SYS][BIZ_N1]… W-009│  │ GERENTE_VENTAS            ││
│  ├───────────────────────────────┤  ├───────────────────────────┤│
│  │ V-CR-004 FilaRol              │  │ V-CR:B2>OUT               ││
│  │ vendedor_senior  [BIZ_N2] 24⚛ │  │ V-CR-008 OutletRol        ││
│  │  W-009            W-009       │  │ [Métodos][Átomos][Saga]   ││
│  ├───────────────────────────────┤  │ V-CR:B2>T1/T2/T3          ││
│  │ …                             │  ├───────────────────────────┤│
│  ├───────────────────────────────┤  │ V-CR:B2>BOT               ││
│  │ V-CR-005 PieListaRoles        │  │ V-CR-009 [Publicar][Canc] ││
│  │ 366 roles · [BIZ_N2]          │  │                           ││
│  └───────────────────────────────┘  └───────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

| Código | Nombre | Descripción |
|--------|--------|-------------|
| `V-CR-001` | BloqueLista | Panel izquierdo 340px: BarraTiers en TOP + lista de roles en BOD |
| `V-CR-002` | BarraTiers | Pills scroll horizontal: TODOS · SU · SYS · BIZ_N1..BIZ_N5 · EXT_N0 · M2M · VISITANTE |
| `V-CR-003` | PillTier | Pill individual: activo=primary, inactivo=muted → `W-009` |
| `V-CR-004` | FilaRol | Nombre (bold) + id (monospace muted) + `W-009` pill + contador `24⚛` |
| `V-CR-005` | PieListaRoles | `N roles [· TIER_ACTIVO]` (11px, muted, 36px) |
| `V-CR-006` | PanelDetalle | Panel derecho flex 1: TOP / OUTLET / BOTTOM |
| `V-CR-007` | NombreRolActivo | `V-CR:B2>TOP`: id del rol seleccionado — nunca vacío (auto-selección al cargar) |
| `V-CR-008` | OutletRol | `V-CR:B2>OUT`: tabs T1 Métodos / T2 Átomos / T3 Saga Autenticación |
| `V-CR-009` | AccionesRol | `V-CR:B2>BOT`: `[Publicar]` + `[Cancelar]` |
| `V-CR-010` | PanelVacioRol | Estado vacío cuando ningún rol está seleccionado → `W-007` |

---

### V-US — Usuarios IAM

```
V-US
┌── OUTLET ───────────────────────────────────────────────────────┐
│  ┌── V-US:B1 320px ─────────────┐  ┌── V-US:B2 flex1 ─────────┐│
│  │ V-US:B1>TOP                   │  │                           ││
│  │ V-US-002 W-010                │  │  V-US-006 FichaUsuario    ││
│  │ 🔍 Buscar…                    │  │                           ││
│  ├───────────────────────────────┤  │  ╔══╗ jperez             ││
│  │ V-US-003 FilaUsuario          │  │  ╚══╝ jperez@skull.com   ││
│  │ ╔══╗ jperez        [activo]   │  │  W-005 W-004             ││
│  │ W-005  W-004                  │  │                           ││
│  ├───────────────────────────────┤  │  INFORMACIÓN              ││
│  │ …                             │  │  UUID: 3f2a-… (mono)      ││
│  ├───────────────────────────────┤  │                           ││
│  │ V-US-004 PieListaUsuarios     │  │  ROLES  V-US-007          ││
│  │ 4 usuarios                    │  │  [vendedor_senior]        ││
│  └───────────────────────────────┘  └───────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

| Código | Nombre | Descripción |
|--------|--------|-------------|
| `V-US-001` | BloqueLista | Panel izquierdo 320px: buscador en TOP + lista de usuarios en BOD |
| `V-US-002` | BuscadorUsuarios | Input full-width fondo muted, icono lupa 14px, controller → `W-010` |
| `V-US-003` | FilaUsuario | `W-005` (32px) + username bold 13px + email 11px muted + `W-004` chip estado |
| `V-US-004` | PieListaUsuarios | `N usuarios` (11px, muted, fondo muted 36px) |
| `V-US-005` | PanelDetalle | Panel derecho flex 1 |
| `V-US-006` | FichaUsuario | `W-005` grande 44px + username 17px + email 12px + chip + info + roles |
| `V-US-007` | ChipsRolesAsignados | Wrap de chips `[nombre_rol]` dentro de la ficha |
| `V-US-008` | PanelVacioUsuario | Estado vacío cuando ningún usuario seleccionado → `W-007` |

---

### V-AE — Árbol de Entidades

```
V-AE
┌── OUTLET ───────────────────────────────────────────────────────┐
│  ┌── V-AE:B1 340px ─────────────┐  ┌── V-AE:B2 flex1 ─────────┐│
│  │ V-AE:B1>TOP                   │  │                           ││
│  │ V-AE-002 CabeceraArbol        │  │  V-AE-006 FichaEntidad    ││
│  │ ⎇  Árbol de Entidades         │  │                           ││
│  ├───────────────────────────────┤  │  V-AE-007                 ││
│  │ V-AE-003 NodoEntidad          │  │  ╔════╗ SKULL             ││
│  │ ▼ [TNT] interno  SKULL        │  │  ╚════╝ [TNT] interno     ││
│  │   W-003  W-006                │  │  W-003                    ││
│  │   ▼ [BDM] empresa  SKULL-CORP │  │                           ││
│  │     ▼ [BSD] sucursal  Norte   │  │  IDENTIFICADORES          ││
│  │       ▼ [POS] caja  CAJA-01   │  │  ID · Slug · Tenant       ││
│  │         ─ [ACT] HUMAN  Juan   │  │                           ││
│  ├───────────────────────────────┤  │  POSICIÓN · HIJOS         ││
│  │ V-AE-004 PieArbol             │  │                           ││
│  │ 11 entidades                  │  │  ← V-AE-008 si vacío     ││
│  └───────────────────────────────┘  └───────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

| Código | Nombre | Descripción |
|--------|--------|-------------|
| `V-AE-001` | BloqueArbol | Panel izquierdo 340px con `V-AE-002` en TOP y árbol en BOD |
| `V-AE-002` | CabeceraArbol | Fila fija 40px fondo muted: icono `⎇` + "Árbol de Entidades" |
| `V-AE-003` | NodoEntidad | Nodo: expand/colapsar + `W-003` badge nivel + tipo (mono) + nombre → usa `W-006` |
| `V-AE-004` | PieArbol | `N entidades` (11px, muted, fondo muted 36px) |
| `V-AE-005` | PanelDetalle | Panel derecho flex 1 |
| `V-AE-006` | FichaEntidad | `V-AE-007` (40px) + identificadores + posición en árbol + hijos directos |
| `V-AE-007` | IconoNivel | Cuadrado redondeado 40px: fondo con color del nivel (15% op.) + ícono central por nivel |
| `V-AE-008` | PanelVacioEntidad | Estado vacío cuando ninguna entidad seleccionada → `W-007` |

---

## §5 · Widgets reutilizables (W-NNN)

> **Regla de entrada**: solo entra aquí si aparece en **2 o más** vistas/secciones distintas
> con los mismos parámetros de contrato. Duplicar código para que "cuente" está prohibido.

| Código | Clase Dart | Aparece en | Parámetros clave |
|--------|-----------|------------|------------------|
| `W-001` | `TarjetaKpi` | `V-DS-005` ×6 | `etiqueta, icono, valor, unidad, nota, tono(_Tono)` |
| `W-002` | `ItemNav` | `G-SN-003` ×N | `icono, etiqueta, ruta, badge, puntoCritico` |
| `W-003` | `BadgeNivel` | `V-AE-003`, `V-RT-004` | `nivel` (TNT/BDM/BSD/POS/ACT) |
| `W-004` | `ChipEstado` | `V-US-003`, `V-US-006`, `V-CR-004` | `estado` (activo/inactivo/OPERACIONAL/…) |
| `W-005` | `AvatarCircular` | `V-US-003`, `V-US-006`, `G-BC-007` | `inicial, color, tamaño` |
| `W-006` | `NodoArbol` | `V-RT-004`, `V-RT-007`, `V-AE-003`, `V-CR:B1` | `icono, etiqueta, profundidad, expandido, seleccionado, onTap` |
| `W-007` | `PanelVacio` | `V-US-008`, `V-AE-008`, `V-CR-010` | `icono, titulo, subtitulo` |
| `W-008` | `BadgeEstado` | `V-DS-002`, `G-BC-010` | `estado`(OPERACIONAL/CONECTANDO/SIN CONEXIÓN) |
| `W-009` | `ChipTier` | `V-CR-003`, `V-CR-004`, `V-RT-004` | `tier` (SU/SYS/BIZ_N1..BIZ_N5/EXT_N0/M2M/VISITANTE) |
| `W-010` | `BarraBusqueda` | `V-US-002`, `G-BC-003` | `placeholder, controller, onChanged, atajo` |

**Ubicación en código:** `lib/widgets/comunes/`  
**Para agregar un nuevo W-**: primero confirmar que aparece en ≥2 vistas, luego agregar aquí
y crear el archivo en `lib/widgets/comunes/<nombre_snake>.dart`.

---

## §6 · Diálogos (DL-NNN)

| Código | Clase Dart | Se abre desde | Descripción |
|--------|-----------|---------------|-------------|
| `DL-001` | `DialogoCrearAtomo` | `V-RT-003` → `[+ Átomo]` | Modal: inserta átomo en `bauth.idn_roles_template` vía psql + base64 |

**Ubicación en código:** `lib/widgets/comunes/dialogo_<nombre>.dart`  
**API:** `mostrarDialogo<Nombre>(context, ...params)` → función top-level que llama `showDialog`.

---

## §7 · Providers Riverpod (PR-NNN)

| Código | Nombre Riverpod | Tipo | Descripción |
|--------|----------------|------|-------------|
| `PR-001` | `syncStatusProvider` | `FutureProvider.autoDispose<SyncStatusInfo>` | Estado daemon bAuth · `bauth.sync.status` · refresh 30s |
| `PR-002` | `bauthApiProvider` | `Provider<BauthApi>` | Instancia singleton de `BauthApi` (JSON-RPC / psql) |
| `PR-003` | `rolTemplateProvider` | `FutureProvider.autoDispose` | Árbol completo `bauth.idn_role_template` (pendiente) |
| `PR-004` | `entidadesProvider` | `FutureProvider.autoDispose` | Árbol `bauth.idn_identity_entity` — D00 (pendiente) |

**Ubicación en código:** `lib/nucleo/conexion/proveedor_conexion.dart`

---

## §8 · Maqueta anotada — Shell completo

Shell expandido con todos los códigos de sección y slot marcados:

```
G-SH
╔════════════════════╦══════════════════════════════════════╦══════════════════╗
║ G-SN   248px       ║ G-BC   flex 1                        ║ G-BD   300px     ║
╠════════════════════╬══════════════════════════════════════╬══════════════════╣
║ G-SN:TOP           ║ G-BC:TOP  [G-BC-001]                 ║ G-BD:TOP         ║
║ [G-SN-001]         ║ [G-BC-002] [G-BC-003 W-010] ···      ║ [G-BD-001]       ║
║ ╔══╗ bAuth         ║ [G-BC-004] [G-BC-005] [G-BC-006]     ║ [⚙ Config ▾]    ║
║ ╚══╝ Control Plane ║ [G-BC-007 W-005]                     ║                  ║
╠════════════════════╬──────────────────────────────────────╬══════════════════╣
║ G-SN:BOD           ║ G-BC:BB  [G-BC-009]                  ║ G-BD:BOD         ║
║                    ║──────────────────────────────────────║                  ║
║ [G-SN-002] GENERAL ║ G-BC:OUT                             ║ [G-BD-002]       ║
║ [G-SN-003 W-002]   ║                                      ║   o              ║
║ [G-SN-003 W-002]   ║   Vista activa (V-DS / V-RT / …)     ║ [G-BD-003]       ║
║ [G-SN-004] [89]    ║                                      ║   o              ║
║                    ║──────────────────────────────────────║ [G-BD-004]       ║
║ [G-SN-002] SISTEMA ║ G-BC:SB  [G-BC-010]                  ║   o              ║
║ [G-SN-003 W-002]   ║──────────────────────────────────────║ [G-BD-005..007]  ║
║ [G-SN-005] ●✓      ║ G-BC:BOT  [G-BC-011]                 ║                  ║
║ [G-SN-007] ─────   ║                                      ║                  ║
║ [G-SN-003 W-002]   ║                                      ║                  ║
╠════════════════════╬──────────────────────────────────────╬══════════════════╣
║ G-SN:BOT           ║                                      ║ G-BD:BOT         ║
║ [G-SN-006]         ║                                      ║ [G-BD-008]       ║
╚════════════════════╩══════════════════════════════════════╩══════════════════╝
```

---

## §9 · Referencia rápida — tabla de consulta

Tabla para buscar rápidamente un código sin recorrer todo el documento:

| Código | Tipo | Nombre | Sección / Vista |
|--------|------|--------|-----------------|
| `G-BC-001` | obj | BarraSuperior | G-BC:TOP |
| `G-BC-002` | obj | ToggleSidenav | G-BC:TOP |
| `G-BC-003` | obj→W-010 | BuscadorGlobal | G-BC:TOP |
| `G-BC-004` | obj | ChipConexion | G-BC:TOP |
| `G-BC-005` | obj | ToggleTema | G-BC:TOP |
| `G-BC-006` | obj | Campanilla | G-BC:TOP |
| `G-BC-007` | obj→W-005 | AvatarMenu | G-BC:TOP |
| `G-BC-008` | obj | MenuUsuarioDesplegable | G-BC:TOP |
| `G-BC-009` | obj | BarraBreadcrumb | G-BC:BB |
| `G-BC-010` | obj→W-008 | BarraEstado | G-BC:SB |
| `G-BC-011` | obj | BarraInferior | G-BC:BOT |
| `G-BD-001` | obj | SelectorContexto | G-BD:TOP |
| `G-BD-002` | obj | PanelConfig | G-BD:BOD |
| `G-BD-003` | obj | PanelHerramientas | G-BD:BOD |
| `G-BD-004` | obj | PanelAtomLang | G-BD:BOD |
| `G-BD-005` | obj | PanelUso | G-BD:BOD |
| `G-BD-006` | obj | PanelAyuda | G-BD:BOD |
| `G-BD-007` | obj | ConfirmarSalir | G-BD:BOD |
| `G-BD-008` | obj | EstadoSesion | G-BD:BOT |
| `G-SN-001` | obj | EncabezadoNav | G-SN:TOP |
| `G-SN-002` | obj | GrupoNav | G-SN:BOD |
| `G-SN-003` | obj→W-002 | ÍtemNav | G-SN:BOD |
| `G-SN-004` | obj | BadgeContador | G-SN:BOD |
| `G-SN-005` | obj | PuntoEstado | G-SN:BOD |
| `G-SN-006` | obj | PieNav | G-SN:BOT |
| `G-SN-007` | obj | SeparadorNav | G-SN:BOD |
| `V-AE-001` | obj | BloqueArbol | V-AE:B1 |
| `V-AE-002` | obj | CabeceraArbol | V-AE:B1>TOP |
| `V-AE-003` | obj→W-006 | NodoEntidad | V-AE:B1>BOD |
| `V-AE-004` | obj | PieArbol | V-AE:B1>BOT |
| `V-AE-005` | obj | PanelDetalle | V-AE:B2 |
| `V-AE-006` | obj | FichaEntidad | V-AE:B2>DET |
| `V-AE-007` | obj | IconoNivel | V-AE:B2>DET |
| `V-AE-008` | obj→W-007 | PanelVacioEntidad | V-AE:B2>DET |
| `V-CR-001` | obj | BloqueLista | V-CR:B1 |
| `V-CR-002` | obj | BarraTiers | V-CR:B1>TOP |
| `V-CR-003` | obj→W-009 | PillTier | V-CR:B1>TOP |
| `V-CR-004` | obj | FilaRol | V-CR:B1>BOD |
| `V-CR-005` | obj | PieListaRoles | V-CR:B1>BOT |
| `V-CR-006` | obj | PanelDetalle | V-CR:B2 |
| `V-CR-007` | obj | NombreRolActivo | V-CR:B2>TOP |
| `V-CR-008` | obj | OutletRol | V-CR:B2>OUT |
| `V-CR-009` | obj | AccionesRol | V-CR:B2>BOT |
| `V-CR-010` | obj→W-007 | PanelVacioRol | V-CR:B2 |
| `V-DS-001` | obj | Cabecera | V-DS |
| `V-DS-002` | obj→W-008 | BadgeEnVivo | V-DS-001 |
| `V-DS-003` | obj | SelectorRango | V-DS-001 |
| `V-DS-004` | obj | RejillaKpis | V-DS |
| `V-DS-005` | obj→W-001 | TarjetaKpi | V-DS-004 ×6 |
| `V-RT-001` | obj | SelectorRolActivo | V-RT |
| `V-RT-003` | obj | ToolbarP1 | V-RT:P1>TB |
| `V-RT-004` | obj→W-006 | ArbolRoles | V-RT:P1 |
| `V-RT-005` | obj | FichaIdentidadNodo | V-RT:P1>BOT |
| `V-RT-007` | obj→W-006 | ArbolAtomLang | V-RT:P2 |
| `V-RT-008` | obj | Panel3Compilado | V-RT:P3 |
| `V-RT-009` | obj | BarraRutaNodo | V-RT:BOT |
| `V-RT-010` | obj | EnlaceCruzado | V-RT:P1/P2 |
| `V-US-001` | obj | BloqueLista | V-US:B1 |
| `V-US-002` | obj→W-010 | BuscadorUsuarios | V-US:B1>TOP |
| `V-US-003` | obj | FilaUsuario | V-US:B1>BOD |
| `V-US-004` | obj | PieListaUsuarios | V-US:B1>BOT |
| `V-US-005` | obj | PanelDetalle | V-US:B2 |
| `V-US-006` | obj | FichaUsuario | V-US:B2>DET |
| `V-US-007` | obj | ChipsRolesAsignados | V-US-006 |
| `V-US-008` | obj→W-007 | PanelVacioUsuario | V-US:B2>DET |
| `W-001` | widget | TarjetaKpi | V-DS ×6 |
| `W-002` | widget | ItemNav | G-SN ×N |
| `W-003` | widget | BadgeNivel | V-AE, V-RT |
| `W-004` | widget | ChipEstado | V-US, V-CR |
| `W-005` | widget | AvatarCircular | V-US, G-BC |
| `W-006` | widget | NodoArbol | V-RT×2, V-AE, V-CR |
| `W-007` | widget | PanelVacio | V-US, V-AE, V-CR |
| `W-008` | widget | BadgeEstado | V-DS, G-BC |
| `W-009` | widget | ChipTier | V-CR, V-RT |
| `W-010` | widget | BarraBusqueda | V-US, G-BC |
| `DL-001` | diálogo | DialogoCrearAtomo | V-RT:P1>TB |
| `PR-001` | provider | syncStatusProvider | V-DS, G-SN:BOT |
| `PR-002` | provider | bauthApiProvider | global |
| `PR-003` | provider | rolTemplateProvider | V-RT, V-CR |
| `PR-004` | provider | entidadesProvider | V-AE |

---

## Registro de cambios

| Versión | Fecha | Cambio |
|---------|-------|--------|
| 1.0.0 | 2026-08-03 | Creación — sistema de códigos completo: G-SN/G-BC/G-BD · V-DS/V-RT/V-CR/V-US/V-AE · W-001..W-010 · DL-001 · PR-001..PR-004 · árbol de slots · maqueta anotada § 8 · tabla de consulta rápida §9 |
