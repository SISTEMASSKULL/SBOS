# A.64 — Guía de Desarrollo Desktop: bAuth Control Plane
## Living Specification — maquetas, estado de implementación y protocolo de evolución

**Versión:** 1.1  
**Fecha:** 2026-07-18  
**Autor:** bauth-developer  
**Fuente de verdad del código:** `src/desktop/lib/` — Flutter + Riverpod 3.x + tf_shadcn_flutter

---

## Método — cómo vive y crece este documento

Este documento es una **Living Specification**: no se completa antes de programar, sino que
co-evoluciona con el código. Cada sección nace como maqueta ASCII, avanza cuando el código
la implementa, y se cierra cuando ambos están verificados y alineados.

### Los cuatro estados (en el TOC — vista rápida)

| Estado | Significado |
|---|---|
| `[MAQUETA]` | Diseño acordado, sin código todavía |
| `[EN DESARROLLO]` | Código existe, maqueta puede diferir |
| `[IMPLEMENTADO]` | Código y maqueta verificados y alineados |
| `[POSTERGADO]` | Sin trabajo previsto en los próximos 2 sprints |

### Bloque de estado — dentro de cada sección

El título de cada sección queda limpio. El detalle vive **al inicio del cuerpo** de la sección
como un bloque de respaldo con tres campos:

```
> **Estado:** MAQUETA | EN DESARROLLO | IMPLEMENTADO | POSTERGADO
> **Aprobado:** YYYY-MM-DD — resumen de lo que fue acordado
> **Pendiente:** · item 1 · item 2 · …
```

- **Aprobado** registra qué fue revisado y confirmado (HITL o commit verificado).
  Si aún no fue aprobado dice `—`.
- **Pendiente** lista lo que falta hacer: reparaciones de código, ajustes de maqueta,
  conexiones a DB, etc. Si no hay nada pendiente dice `ninguno`.
- Cada vez que se repara un ítem pendiente, se tacha o elimina y se actualiza Aprobado.

### Regla de co-commit — cero fricción

```
Cambio de código  →  actualizar bloque de estado en A.64 en el mismo commit
Cambio en A.64    →  el código debe existir o ser el siguiente commit
```

No hay reuniones de sincronización. El commit es la unidad de verdad.

### Cuándo agregar una sección nueva

Solo en dos momentos:
1. **Antes de implementar** — la semana en que se va a escribir el código (estado `[MAQUETA]`)
2. **Después de implementar** — documentando lo que ya existe (estado `[EN DESARROLLO]`)

Las secciones que describen vistas lejanas se marcan `[POSTERGADO]` — no se borran,
pero tampoco bloquean el avance.

### Qué hace honesto este documento

- Si maqueta no coincide con código: **se corrige la maqueta**.
- Si una sección pasa a `[IMPLEMENTADO]` y el código cambia: **vuelve a `[EN DESARROLLO]`**.
- Ningún agente marca `[IMPLEMENTADO]` sin evidencia — debe existir el archivo Dart y
  el comportamiento verificado manualmente.

---

**Inventario de códigos:** `A.64.01_INVENTARIO-CODIGOS-DESKTOP-v1.0.md` — catálogo completo de todos los códigos G-/V-/W-/DL-/PR- usados en este documento, con árbol de slots, tabla de consulta rápida y maqueta del shell anotada.

## Changelog

| Versión | Fecha | Cambio |
|---|---|---|
| 1.2 | 2026-08-03 | Códigos G-/V-/W- agregados en todas las maquetas (§1–§9) · referencia a A.64.01 · anotaciones inline en ASCII art |
| 1.1 | 2026-07-18 | Método Living Spec · Changelog · estados por sección · TEMPLATES (Identidad/Rol/User/Aplicacion) · CRUD 11 ítems · TOP Bloque 3 con selector desplegable · §4.5 AtomLang log compilación · §3.1 menú de usuario |
| 1.0 | 2026-07-18 | Versión inicial — estructura de 3 bloques · maquetas §1–§11 |

---

## Tabla de contenidos

1. [Shell global — los 3 bloques](#1-shell-global--los-3-bloques) `[MAQUETA]`
2. [Bloque izquierdo — sidenav](#2-bloque-izquierdo--sidenav) `[MAQUETA]`
3. [Bloque central — capas fijas](#3-bloque-central--capas-fijas) `[MAQUETA]`
4. [Bloque derecho — panel de acciones](#4-bloque-derecho--panel-de-acciones) `[MAQUETA]`
5. [Vista: Dashboard de Salud](#5-vista-dashboard-de-salud) `[EN DESARROLLO]`
6. [Vista: Rol Template (AtomLang)](#6-vista-rol-template-atomlang) `[EN DESARROLLO]`
7. [Vista: Roles](#7-vista-roles) `[EN DESARROLLO]`
8. [Vista: Usuarios](#8-vista-usuarios) `[EN DESARROLLO]`
9. [Vista: Árbol de Entidades](#9-vista-árbol-de-entidades) `[EN DESARROLLO]`
10. [Vistas en construcción](#10-vistas-en-construcción) `[MAQUETA]`
11. [Sidenav colapsado](#11-sidenav-colapsado) `[MAQUETA]`

---

## 1. Shell global — los 3 bloques

> **Estado:** MAQUETA  
> **Aprobado:** 2026-07-18 — 3 bloques (IZQ/CENTRAL/DER) con TOP/BODY/BOTTOM cada uno; estados expandido y contraído para Bloques 1 y 3  
> **Pendiente:** · reparar `bloque_lateral_derecho.dart` — actualmente no tiene TOP ni BOTTOM, solo `SingleChildScrollView` · implementar toggle colapsado en Bloque 3

**Expandido — 248 px · flex 1 · 300 px**

`G-SN` 248 px                `G-BC` flex 1                     `G-BD` 300 px
```
╔══════════════════╦══════════════════════════════════╦══════════════════╗
║ G-SN:TOP         ║ G-BC:TOP · G-BC-001              ║ G-BD:TOP         ║
║ G-SN-001         ║  BarraSuperior 48 px             ║ G-BD-001         ║
║  56 px           ║                                  ║  56 px           ║
╠══════════════════╣──────────────────────────────────╠══════════════════╣
║ G-SN:BOD         ║ G-BC:BB · G-BC-009               ║ G-BD:BOD         ║
║ G-SN-003 W-002   ║  BarraBreadcrumb 40 px           ║ G-BD-002..007    ║
║  [◎] Roles       ║  ──────────────────────────────  ║  (por selector)  ║
║  [◎] Usuarios    ║ G-BC:OUT · Outlet flex 1         ║  [◎] Uso 24 h    ║
║  ...             ║  ──────────────────────────────  ║                  ║
║                  ║ G-BC:SB · G-BC-010               ║                  ║
╠══════════════════╣──────────────────────────────────╠══════════════════╣
║ G-SN:BOT         ║ G-BC:BOT · G-BC-011              ║ G-BD:BOT         ║
║ G-SN-006         ║  BarraInferior 30 px             ║ G-BD-008         ║
╚══════════════════╩══════════════════════════════════╩══════════════════╝
```

**Contraído — 76 px · flex 1 · 76 px**

```
╔══════╦════════════════════════════════════════════════════╦══════╗
║ TOP  ║  TOP                                               ║ TOP  ║
╠══════╣────────────────────────────────────────────────────╠══════╣
║ BODY ║  BODY                                              ║ BODY ║
║ [◎]  ║                                                    ║ [◎]  ║
║ [◎]  ║  Outlet (flex 1)                                   ║ [◎]  ║
║ [◎]  ║                                                    ║ [◎]  ║
╠══════╣────────────────────────────────────────────────────╠══════╣
║ BOT  ║  BOTTOM                                            ║ BOT  ║
╚══════╩════════════════════════════════════════════════════╚══════╝
```

---

## 2. Bloque izquierdo — sidenav

> **Estado:** MAQUETA  
> **Aprobado:** 2026-07-18 — grupos GENERAL / TEMPLATES (Identidad/Rol/User/Aplicacion) / CRUD (11 ítems) / IDENTIDAD / SISTEMA / CUENTA confirmados; `menu_datos.dart` actualizado  
> **Pendiente:** · rutas nuevas de TEMPLATES (`rtpl_identidad`) y CRUD (`metodos`, `dominios`, `bloques`, `atributos`, `verbos`, `aplicaciones`, `modulos`, `grupos`, `reglas`) sin vistas implementadas · Bloque 3 (DER) también debe tener toggle expand/collapse

### 2.1 Sidenav expandido (248 px)

```
┌─────────────────────────────────────┐  ← 248 px ancho
│ ╔══╗  bAuth                         │  G-SN:TOP · G-SN-001
│ ║🛡️║  Control Plane                 │    click → colapsa sidenav
│ ╚══╝                                │
├─────────────────────────────────────┤
│                                     │  G-SN:BOD
│  GENERAL                            │  G-SN-002 · título de grupo
│  ⊞ Dashboard de Salud               │  G-SN-003  W-002 · ítem activo
│  👥 Usuarios Conectados    [89]     │  G-SN-003  G-SN-004 · badge numérico
│                                     │
│  TEMPLATES                          │  G-SN-002
│  🪪 Identidad                       │  G-SN-003  W-002
│  🛡 Rol                             │  G-SN-003  W-002
│  👤 User                            │  G-SN-003  W-002
│  📦 Aplicacion                      │  G-SN-003  W-002
│                                     │
│  CRUD                               │  G-SN-002
│  ⚙  Métodos                         │  G-SN-003  W-002
│  🌐 Dominios                        │  G-SN-003  W-002
│  🧱 Bloques                         │  G-SN-003  W-002
│  🏷 Atributos                       │  G-SN-003  W-002
│  ⚡ Verbos                          │  G-SN-003  W-002
│  🛡  Roles                  [366]   │  G-SN-003  G-SN-004  W-002
│  👥 Usuarios               [1.2k]  │  G-SN-003  G-SN-004  W-002
│  📦 Aplicaciones                    │  G-SN-003  W-002
│  🧩 Módulos                         │  G-SN-003  W-002
│  🔗 Grupos                          │  G-SN-003  W-002
│  📋 Reglas                          │  G-SN-003  W-002
│                                     │
│  IDENTIDAD                          │  G-SN-002
│  ⎇  Árbol de Entidades              │  G-SN-003  W-002
│  📈 Uso del Sistema          ●⚠     │  G-SN-003  G-SN-005 · ámbar = advertencia
│                                     │
│  SISTEMA                            │  G-SN-002
│  🔄 Sincronización           ●✓     │  G-SN-003  G-SN-005 · verde = ok
│  📄 Auditoría                ●⚠     │  G-SN-003  G-SN-005
│  🛡  Visión BOS               ●⚠     │  G-SN-003  G-SN-005
│  🔗 Blockchain                      │  G-SN-003  W-002
│                                     │
│  CUENTA                             │  G-SN-002
│  💳 Mi Cuenta                       │  G-SN-003  W-002
│  🎧 Soporte SBOS                    │  G-SN-003  W-002
│                                     │
│           ─────────────────         │  G-SN-007 · separador
│  ⊞  Configuración                   │  G-SN-003  W-002 · fijo al pie del nav
├─────────────────────────────────────┤
│ ●  Daemon operativo                 │  G-SN:BOT · G-SN-006
│    v0.9.0 · uptime 99.9%            │  monospace, muted
└─────────────────────────────────────┘
```

**Notas:**
- El ítem activo tiene fondo ligeramente resaltado (color muted con opacidad)
- Los badges numéricos `[366]` aparecen en la derecha del ítem
- Los puntos de estado `●✓` / `●⚠` son círculos de 7px (verde/ámbar)
- La sección Configuración es un ítem separado, fijo bajo el spacer

---

## 3. Bloque central — capas fijas

> **Estado:** MAQUETA  
> **Aprobado:** 2026-07-18 — BarraSuperior con menú de usuario desplegable `[SA▾]` (Mi perfil / Cambiar usuario / Registrar / Iniciar sesión / Cerrar sesión); BarraBreadcrumb; BarraEstado; BarraInferior  
> **Pendiente:** · menú desplegable `[SA▾]` no implementado en código (actualmente solo muestra avatar estático) · BarraEstado puede diferir del código real — verificar

### 3.1 BarraSuperior (48 px, fija en TOP)

**Estado normal:** `G-BC:TOP` · `G-BC-001`

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│  [≪]  [🔍 Buscar roles, usuarios, políticas…              ⌘K]  ●9450  [☀]  [🔔]  [SA ▾] │
│ G-BC-002  G-BC-003 W-010                                  G-BC-004 G-BC-005 G-BC-006 G-BC-007│
└──────────────────────────────────────────────────────────────────────────────────┘
```

**Menú de usuario — desplegable al pulsar `[SA ▾]`:** `G-BC-008`

```
                                                          ┌──────────────────────────┐
                                                          │  ╔══╗  sbos-admin        │
                                                          │  ╚══╝  Administrador     │
                                                          ├──────────────────────────┤
                                                          │  [◎]  Mi perfil          │
                                                          │  [◎]  Cambiar usuario    │
                                                          ├──────────────────────────┤
                                                          │  [◎]  Registrar          │
                                                          │  [◎]  Iniciar sesión     │
                                                          ├──────────────────────────┤
                                                          │  [◎]  Cerrar sesión      │
                                                          └──────────────────────────┘
```

**Elementos:**
- `[≪]` / `[≫]` → `G-BC-002` — toggle que colapsa/expande el sidenav izquierdo
- Buscador → `G-BC-003` `W-010`: fondo muted + ícono lupa + placeholder + atajo `⌘K`
- `●9450` → `G-BC-004`: chip conexión: punto verde + IP:puerto en monospace
- `[☀]` → `G-BC-005`: toggle de tema claro/oscuro
- `[🔔]` → `G-BC-006`: campana; punto rojo si hay notificación crítica
- `[SA ▾]` → `G-BC-007` `W-005`: avatar gradiente + nombre + rol + desplegable de sesión

### 3.2 BarraBreadcrumb (40 px, bajo la barra superior) `G-BC:BB` · `G-BC-009`

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  Control Plane  /  Dashboard de Salud                                               │
│  ─── muted ─── ─  ──── bold, foreground ────                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

Cambia automáticamente con la ruta activa. "Control Plane" permanece siempre en muted.

### 3.3 BarraEstado (30 px, bajo el outlet) `G-BC:SB` · `G-BC-010`

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ ● Conectado  WebSocket · ↕ 12 ms  │  ● Reconcile · proyecciones  hace 3m  │ ⚠ 1 drift │         142.857 eval/s  89 sesiones  366 roles │
│   verde       bold + monospace     sep  verde       normal         monospace  ámbar                      ──── monospace, alineado derecha ──── │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

**Segmentos (izquierda a derecha):**
1. `● Conectado` (verde, bold) + `WebSocket · ↕ 12 ms` (monospace, muted)
2. Separador vertical `│`
3. `● Reconcile · proyecciones` (verde) + `hace 3m` (monospace)
4. Separador vertical `│`
5. `⚠ 1 drift` (ámbar)
6. Spacer (flex)
7. `142.857 eval/s · 89 sesiones · 366 roles` (monospace, alineado derecha)

---

## 4. Bloque derecho — panel de acciones

> **Estado:** MAQUETA  
> **Aprobado:** 2026-07-18 — rediseño completo: TOP con selector (Config/Herramientas/AtomLang/Uso/Ayuda/Salir); BODY contextual por vista activa de Bloque 1; §4.4 Herramientas = paleta AtomLang (A.49 §2); §4.5 AtomLang = log compilación con 4 estados (sin compilar / en progreso / errores / éxito) y botones mutuamente excluyentes (Compilar → Recompilar → Publicar); BOTTOM con estado de sesión  
> **Pendiente:** · TODO el refactor en código — `bloque_lateral_derecho.dart` no tiene TOP/BODY/BOTTOM ni selector · no tiene `activoDer` conectado en provider · ningún widget de las opciones existe todavía en Dart

El TOP contiene un selector desplegable que determina qué widget se muestra en el BODY.
Cada opción del selector tiene su propio widget de contenido.

---

### 4.1 Estructura con selector `G-BD`

**Expandido (300 px):**

```
┌──────────────────────────────┐
│  G-BD:TOP                    │
│  [ ⚙ Configuración      ▾ ] │  G-BD-001 · selector desplegable
├──────────────────────────────┤
│  G-BD:BOD                    │
│  G-BD-002 PanelConfig        │  (cuando selector = Configuración)
│  G-BD-003 PanelHerramientas  │  (cuando selector = Herramientas)
│  G-BD-004 PanelAtomLang      │  (cuando selector = AtomLang)
│  G-BD-005..007               │  (Uso / Ayuda / Salir)
├──────────────────────────────┤
│  G-BD:BOT                    │
│  ● Sesión activa · 2h 14m   │  G-BD-008
└──────────────────────────────┘
```

**Contraído (76 px):**

```
┌──────┐
│ TOP  │
│ [▾]  │
├──────┤
│ BODY │
│      │
├──────┤
│ BOT  │
└──────┘
```

---

### 4.2 Opciones del selector

```
┌──────────────────────────────┐
│  [ ⚙ Configuración      ▾ ] │
├──────────────────────────────┤
│  ⚙  Conexion                │
│  ⚙  Configuración            │
│  🔧  Herramientas             │
│  🔷  AtomLang                │
│  📈  Uso (24 h)              │
│  ❓  Ayuda                   │
│  ─────────────────────────   │
│  ✕   Salir                   │
└──────────────────────────────┘
```

---

### 4.3 BODY: Configuración

```
│  ⚙  CONFIGURACIÓN            │
│  ──────────────────────────  │
│  Tema          [ Oscuro  ▾ ] │
│  Idioma        [ Español ▾ ] │
│  Servidor      13.140.128.230│
│  Puerto        9450          │
│  Timeout       30 s          │
│  Notificaciones  [ ON   ▾ ]  │
```

---

### 4.4 BODY: Herramientas (contextual por vista activa en Bloque 1)

Este espacio **no es un panel fijo**. Su contenido cambia según la opción
seleccionada en el Bloque 1 (sidenav izquierdo). Cada vista tiene su propio
set de widgets de herramientas u objetos.

**Referencia de objetos:** 2.14 §2–§7 · A.47 §2

---

**Ejemplo — vista "Rol Template" activa:**

Muestra la paleta de objetos para componer tanto el árbol de identidad (Panel 1)
como el árbol AtomLang (Panel 2) del RolTemplate.

```
│  🔧  HERRAMIENTAS — Rol Template   │
│  ────────────────────────────────  │
│                                    │
│  IDENTIDAD                         │
│  ┌──────────────────────────────┐  │
│  │  [IDENTIDAD RT]  🟪 Nuevo rol│  │
│  │  B1+B2+B3 · Panel 1          │  │
│  └──────────────────────────────┘  │
│                                    │
│  CONTENEDORES                      │
│  ┌──────────────────────────────┐  │
│  │  [POLICYSET]  Dominio        │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  [POLICYSET]  Zona B6        │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  [POLICY]     Aplicación     │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  [POLICY]     Capa B7        │  │
│  └──────────────────────────────┘  │
│                                    │
│  REGLAS                            │
│  ┌──────────────────────────────┐  │
│  │  [REGLA]  Atom · Permit      │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  [REGLA]  Atom · Deny        │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  [REGLA]  Guardrail · Deny   │  │
│  └──────────────────────────────┘  │
│                                    │
│  REGISTRO                          │
│  ┌──────────────────────────────┐  │
│  │  [D98]  Set de Roles         │  │
│  └──────────────────────────────┘  │
```

Los objetos CONTENEDORES, REGLAS y REGISTRO se arrastran al **Panel 2**
(árbol AtomLang). El objeto IDENTIDAD RT se arrastra al **Panel 1**
(árbol de jerarquía de roles). Cada objeto abre un formulario de configuración
con los campos propios del nodo.

---

#### Objeto "Identidad RT" — definición formal

**Tipo:** compuesto 🟪 — al soltarse en Panel 1 genera un subtree completo
con todos los campos de identidad pre-estructurados como placeholders.
No es un nodo atómico: es el molde canónico para crear un rol nuevo.

**Destino:** Panel 1 — árbol de jerarquía de roles (`bauth.idn_role_template`).
Los otros objetos de la paleta (CONTENEDORES, REGLAS, REGISTRO) van al Panel 2.

**Origen del esquema:** D0/B1 del Panel 2 — contrato RolTemplate v6.0 (A.01 §3).
La estructura de campos es FIJA (canónica); los valores son los que el
administrador rellena para ese rol particular.

**Subtree que genera — campos por bloque:**

```
[IDENTIDAD RT] — Rol nuevo
│
├── B1 · Identificación y metadatos     (A.01 §3 · ANSI INCITS 359 · ISO 24760-2)
│     ├── id                  placeholder "ROL-NNN"   (inmutable post-creación)
│     ├── parent_id           selector → nodo del árbol Panel 1
│     ├── type_id             enumerado 10 tipos NIST  (INDIVIDUAL/GROUP/M2M/…)
│     ├── hierarchy_level     enumerado 1–5            (1=C-Level … 5=Operativo)
│     ├── path_ids            readonly — calculado por el sistema
│     ├── version             "1.0.0"                  (SemVer — MAJOR=breaking)
│     ├── status              enumerado DRAFT           (inicio del ciclo de vida)
│     ├── name{}
│     │     ├── es            placeholder "Nombre del rol"
│     │     ├── en            placeholder "Role name"
│     │     └── pt            placeholder "Nome da função"
│     ├── description{}
│     │     └── es            placeholder "Descripción del rol"
│     └── metadata{}
│           ├── department              texto libre
│           ├── cost_center             texto libre
│           ├── region                  texto libre
│           ├── territory_code          texto libre
│           ├── job_family              texto libre
│           ├── job_level               enumerado (I1-I5 · M1-M5 · D1-D3)
│           ├── max_subordinates        número
│           ├── required_certifications lista texto
│           ├── reporting_line          texto libre
│           ├── classification          enumerado (PUBLIC/INTERNAL/CONFIDENTIAL/RESTRICTED)
│           ├── org_unit_id             texto — unidad canónica (no solo nombre)
│           ├── tenant_id               texto — tenant del despliegue
│           ├── sector_code             enumerado CAEB SIN (21 sectores Bolivia)
│           ├── accountability_chain[]  lista de roles (cadena hasta el CEO)
│           └── data_owner_roles[]      lista de roles (custodios de los datos del rol)
│
├── B2 · Vigencia y ciclo de vida       (A.01 §4 · ISO 24760 §7 · NIST AC-2)
│     ├── validity_period.type   enumerado (INDEFINITE/FIXED/TEMPORARY/EMERGENCY)
│     ├── start_date             fecha
│     ├── end_date               fecha o null (null si INDEFINITE)
│     └── review_date            fecha — alerta 30 días antes
│
└── B3 · Flujo de aprobación            (A.01 §5 · ISO 27001 A.5.2 · CM-3/AC-5)
      ├── required_approvers     número (quórum de aprobaciones)
      ├── approver_roles[]       lista de roles habilitados para aprobar
      ├── notification_channel   enumerado (rocket_chat/email)
      ├── sla_hours              número (default 48)
      └── escalation_to[]        lista de roles de escalación
```

**Reglas de uso:**

| Regla | Detalle |
|---|---|
| Solo en Panel 1 | No puede soltarse en Panel 2 ni Panel 3 |
| Un solo nodo raíz nuevo | No duplica roles existentes — crea siempre uno nuevo en DRAFT |
| `parent_id` obligatorio | El selector debe apuntar a un nodo existente del árbol (o null = raíz) |
| Campos del metadata: 15 | 9 del contrato original + 6 de la extensión D0 (A.01 §17.3-D0) |
| `id` inmutable | Una vez guardado no puede cambiar — el sistema asigna uuidv7 |
| `status` inicial | Siempre DRAFT — el flujo B3 lo lleva a REVIEW → ACTIVE |

**Fuentes normativas:** A.01 §3 B1 (15 campos metadata) · A.01 §4 B2 (vigencia) ·
A.01 §5 B3 (flujo de aprobación) · A.01 §17.3-D0 (6 campos nuevos del metadata) ·
ISO 24760-2 §5 (identidad canónica) · NIST AC-2(a) (clasificación de tipos de cuenta)

---

### 4.5 BODY: AtomLang — log de compilación

Muestra el resultado de `atomc` para el árbol activo según la vista en Bloque 1:

| Vista activa (Bloque 1) | Árbol que compila |
|---|---|
| Rol Template | árbol `.atm.yaml` del RolTemplate seleccionado |
| User Template | árbol de atributos y contratos del UserTemplate |
| Árbol de Entidades | árbol D00 Identidad Organizacional |

**Flujo único — sin solapamiento de botones:**

```
Árbol editado → [ Compilar ] → con errores → corregir → [ Recompilar ]
                                                                ↓
                                               sin errores → [ Publicar ]
```

Los tres botones son **mutuamente excluyentes**: nunca dos a la vez.

---

**Estado 1 — árbol sin compilar (o con cambios sin compilar):**

```
│  🔷  ATOMLANG                            │
│  ───────────────────────────────────── │
│  Árbol: Rol Template · GERENTE_VENTAS  │
│  Sin compilación · cambios pendientes  │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Compilar                       │   │
│  └─────────────────────────────────┘   │
```

---

**Estado 2 — compilación en progreso:**

```
│  🔷  ATOMLANG                            │
│  ───────────────────────────────────── │
│  Árbol: Rol Template · GERENTE_VENTAS  │
│                                         │
│  ⟳ Fase 1 — Lexer / Parser …          │
│  · Fase 2 — Semántica                  │
│  · Fase 3 — Codegen                    │
```

---

**Estado 3 — compilación con errores (Fase 3 bloqueada):**

```
│  🔷  ATOMLANG                            │
│  ───────────────────────────────────── │
│  Árbol: Rol Template · GERENTE_VENTAS  │
│  atomc · Fase 1 ✓ · Fase 2 ✗          │
│                                         │
│  ✕ ATOMC-E-031  "payment_approvals"   │
│    sin combining_algorithm             │
│  ✕ ATOMC-E-014  verb_id "autorizar"   │
│    no existe en privilege_verb         │
│  ✕ ATOMC-E-042  literal 10000 en      │
│    campo AMOUNT                        │
│  ⚠ ATOMC-W-011  condition ausente en  │
│    regla "pago_global"                 │
│                                         │
│  3 errores · 1 aviso · Fase 3 bloqueada│
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Recompilar                     │   │
│  └─────────────────────────────────┘   │
```

---

**Estado 4 — compilación exitosa:**

```
│  🔷  ATOMLANG                            │
│  ───────────────────────────────────── │
│  Árbol: Rol Template · GERENTE_VENTAS  │
│  atomc · Fase 1 ✓ · Fase 2 ✓ · Fase 3 ✓│
│                                         │
│  ✓ 0 errores · 0 avisos               │
│  ✓ 47 átomos compilados               │
│  ✓ → privilege_atom_compiled           │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Publicar                       │   │
│  └─────────────────────────────────┘   │
```

**Referencia:** A.46 §2–§4 (fases y catálogo ATOMC-E/W) · A.49 §5

---

### 4.6 BODY: Uso (24 h)

```
│  📈  USO (24 h)              │
│  ──────────────────────────  │
│  Evaluaciones      234.567   │
│  Tokens emitidos     1.234   │
│  FastPath           99.7% ✓  │
│  Sesiones activas       89   │
│  Roles cargados        366   │
```

---

### 4.7 BODY: Ayuda

```
│  ❓  AYUDA                   │
│  ──────────────────────────  │
│  [◎]  Documentación          │
│  [◎]  Atajos de teclado      │
│  [◎]  Reportar un problema   │
│  ──────────────────────────  │
│  bAuth v0.9.0                │
│  SBOS Identity Core          │
```

---

### 4.8 BODY: Salir

```
│  ✕  SALIR                    │
│  ──────────────────────────  │
│  ¿Confirmar cierre de sesión?│
│                              │
│  ┌────────────────────────┐  │
│  │  Cerrar sesión         │  │
│  └────────────────────────┘  │
│  ┌────────────────────────┐  │
│  │  Cancelar              │  │
│  └────────────────────────┘  │
```

---

## 5. Vista: Dashboard de Salud

> **Estado:** EN DESARROLLO  
> **Aprobado:** —  
> **Pendiente:** · verificar que maqueta coincide con `vista_dashboard.dart` actual · conectar datos reales vía `bauthApiProvider`

**Ruta:** `dashboard` — Archivo: `vistas/vista_dashboard.dart`

```
┌── OUTLET (bloque central) ──────────────────────────────────────────────────────────┐
│                                                                                     │
│  Dashboard de Salud                      [● OPERACIONAL]   [En vivo│ 7d│ 30d]      │
│  Identity Control Plane · 18 dominios    V-DS-002 W-008    V-DS-003                 │
│  ← V-DS-001 Cabecera ──────────────────────────────────────────────────────────→   │
│                                                                                     │
│  ← V-DS-004 RejillaKpis (Row, Expanded) ────────────────────────────────────────→  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │ V-DS-005     │  │ V-DS-005     │  │ V-DS-005     │  │ V-DS-005     │           │
│  │ W-001        │  │ W-001        │  │ W-001        │  │ W-001        │           │
│  │ 👥 1.247     │  │ 🛡 366       │  │ ✓ 5.808      │  │ ⚡ 99.7%     │           │
│  │              │  │              │  │              │  │              │           │
│  │ 89 conectados│  │ 3 con DRIFT  │  │ catálogo     │  │ 0.3% Policy  │           │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘           │
│                                                                                     │
│  ┌──────────────┐  ┌──────────────┐                                                │
│  │ V-DS-005 W-001│ │ V-DS-005 W-001│                                               │
│  │ 📊 0.3 ns    │  │ 💻 18%       │                                                │
│  │              │  │              │                                                │
│  │ P99 4.7 ms   │  │ RAM 62 MB    │                                                │
│  └──────────────┘  └──────────────┘                                                │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

**Estructura interna:**
- `V-DS-001` Cabecera: Row con título/subtítulo izquierda + `V-DS-002` badge + `V-DS-003` selector derecha
- `V-DS-004` RejillaKpis: Row con 6 `V-DS-005` expandidas (`Expanded` cada una)
- `V-DS-005` → `W-001` TarjetaKpi: icono arriba izquierda + valor grande (bold) + unidad + nota inferior
- `V-DS-002` → `W-008` BadgeEstado: borde primary, fondo primary 12% opacidad, punto + texto estado
- `V-DS-003` SelectorRango: 3 opciones `[En vivo│7d│30d]` con borde compartido; activo = fondo muted

---

## 6. Vista: Rol Template (AtomLang)

> **Estado:** MAQUETA  
> **Aprobado:** 2026-07-19 — objetivo de la vista documentado; estructura de 3 paneles (Identidad / Rol Template / Compilado) acordada; relación cruzada entre árboles definida  
> **Pendiente:** · reescribir `vista_rol_template.dart` para el nuevo layout de 3 paneles · paleta AtomLang (§4.4 Bloque 3) no conectada · `atomc` no integrado · linter inline existente (commit `b0bfdc4`) debe integrarse al Panel 2

**Ruta:** `rtpl` — Archivo: `vistas/vista_rol_template.dart`

---

### Objetivo de la sección

Esta vista es el **PAP (Policy Administration Point)** de bAuth: el espacio donde el
administrador construye, navega y publica la autorización de un RolTemplate. Presenta
tres representaciones del mismo objeto en simultáneo porque cada una responde una
pregunta distinta:

| Panel | Pregunta que responde | Fuente de datos |
|---|---|---|
| **1 · Identidad Rol Template** | ¿QUIÉNES son los roles y cuál es la identidad particular de cada uno? | `bauth.idn_role_template` ↔ `bauth.idn_identity_entity` |
| **2 · Rol Template** | ¿Cuál es el ESQUEMA general de identidad y QUÉ pueden hacer los roles? | D0 B1 (esquema) + árbol AtomLang D1–D13, D98 (políticas) |
| **3 · Compilado** | ¿CÓMO evalúa el sistema el rol activo en <0.5 ns? | `bauth.privilege_atom_compiled` → RolBitMask (one-hot N-bit) |

**Separación GENERAL / PARTICULAR — principio rector de la vista:**

El Panel 2 contiene **información general**: la parte D0/B1 define el ESQUEMA de identidad
que todo rol debe cumplir (estructura de campos: id, parent_id, type_id, hierarchy_level,
name, metadata, audit, digital_signature), y los dominios D1–D13, D98, D99 contienen
las políticas, reglas y átomos de autorización que aplican a todos los roles del sistema.
Esta información es **genérica** — define la forma, no los valores de ningún rol concreto.

El Panel 1 contiene **información particular**: es el árbol jerárquico de todos los roles
que existen en el sistema (SU → SYS → BIZ-N1 → BIZ-N2 → ...). Cada nodo del árbol
lleva adjuntos sus propios **datos de identidad particulares** — los valores concretos
para ESE rol específico: su `id`, `name`, `org_unit_id`, `sector_code`, `tenant_id`,
`accountability_chain`, sus aprobadores de cambio, su vigencia, etc. Estos valores son
distintos en cada nodo y se derivan del esquema del Panel 2/D0 aplicado a ese rol concreto.

**El objeto "Identidad RT" como puente entre GENERAL y PARTICULAR:**

Cuando el administrador quiere crear un rol nuevo en Panel 1, usa el objeto compuesto
**"Identidad RT"** de la paleta de Herramientas (§4.4 Bloque 3). Este objeto toma el
esquema D0/B1 del Panel 2 como molde y presenta un formulario pre-estructurado con todos
los campos listos para rellenar con los valores particulares del rol nuevo. La estructura
(los campos) viene del Panel 2; los valores (el contenido) van al nodo del Panel 1.

```
Panel 2 D0/B1 (ESQUEMA — general)
    ↓  define los campos
Objeto "Identidad RT" (molde — paleta Herramientas)
    ↓  rellena con valores concretos
Nodo en Panel 1 (IDENTIDAD PARTICULAR — por rol)
```

**Relación cruzada entre Panel 1 y Panel 2 — mecanismo SET:**

La relación entre los dos paneles es explícita por el propio lenguaje AtomLang. Cuando
una política o regla del árbol (Panel 2) debe aplicar solo a determinados roles, declara
su propiedad `subject` con el valor `SET(nombre_set)` o `ROL(id_rol)`. Este es el
mecanismo que establece qué roles del Panel 1 están afectados por esa regla.

Los SETs se declaran en el nodo **D98 · Registro Estructural** (Panel 2): cada SET
agrupa uno o varios roles del árbol jerárquico (Panel 1). Un rol puede pertenecer a
varios SETs simultáneamente. Cuando el PrivilegeEngine evalúa una regla cuyo `subject`
es `SET(vendedores)`, la aplica a todos los roles del Panel 1 que pertenecen a ese SET.

```
Panel 2 — D98 declara:
  SET vendedores = {ROL_VENDEDOR_SENIOR, ROL_VENDEDOR_JUNIOR, ROL_EJECUTIVO_VENTAS}
  SET gerentes_ventas = {ROL_GERENTE_REGIONAL, ROL_DIRECTOR_VENTAS}

Panel 2 — regla en B6 zona_ventas declara:
  subject = SET(vendedores) → verbo WRITE → Permit

Panel 1 — el nodo ROL_VENDEDOR_SENIOR pertenece a SET(vendedores)
  → la regla le aplica → se traza el enlace ●──
```

El enlace visual `●──` entre un nodo del Panel 2 y un nodo del Panel 1 es la
representación de esta pertenencia a SET. Al seleccionar un rol en Panel 1, el
sistema resalta en Panel 2 todas las reglas cuyos SETs contienen a ese rol —
el administrador ve de un vistazo el conjunto exacto de políticas que gobiernan
ese rol concreto, sin necesidad de recorrer el árbol manualmente.

**Fuentes normativas:** 1.06 D00 §3–§4 (identidad + árbol 5 niveles) · 1.09 Roles §2
(RolTemplate como plano abstracto) · 1.04 BitMask §2–§4 (AtomBitMask vs RolBitMask) ·
2.13 AtomLang §3 (modelo de tres árboles) · 2.14 Composición §2 (RolTemplate como
unidad de mantenimiento) · A.46 §2 (gramática y fases compilador) · A.01 §3 B1
(esquema de identidad — campos canónicos del contrato v6.0)

---

### Maqueta — 3 paneles sobre el outlet

```
┌── OUTLET — Vista: Rol Template (AtomLang) ──────────────────────────────────────────┐
│                                                                                      │
│  [GERENTE_VENTAS ▾]  V-RT-001 · selector de RolTemplate activo                      │
│                                                                                      │
│  ┌─ V-RT:P1 IDENTIDAD ─────┐  ┌─ V-RT:P2 ROL TEMPLATE ──────┐  ┌─ V-RT:P3 ───────┐ │
│  │  V-RT-004  W-006        │  │  V-RT-007  W-006             │  │  V-RT-008        │ │
│  │  idn_role_template      │  │  Árbol AtomLang (.atm.yaml)  │  │  → BitMask       │ │
│  ├─ V-RT:P1>TB ────────────┤  ├─────────────────────────────┤  ├──────────────────┤ │
│  │  V-RT-003               │  │                              │  │                  │ │
│  │  ▼ [SU] SuperUsuario    │  │  ▼ D00 [POLICYSET]           │  │  RolBitMask      │ │
│  │  W-009  W-006           │  │  W-006                       │  │  ··1··0···1···   │ │
│  │    ▼ [SYS] Sistema      │  │    ▼ D01 [POLICYSET]         │  │                  │ │
│  │      ▼ [BIZ-N1] Dir.    │  │      ▼ B6 [POLICYSET]        │  │  Átomos:         │ │
│  │        ▼ [BIZ-N2]       │  │        ▼ App [POLICY]        │  │  042 · Permit    │ │
│  │  V-RT-010 ●──GERENTE_VT │  │  V-RT-010 ●──  [REGLA] P    │  │  043 · Deny      │ │
│  │          ▼ VENDEDOR     │  │               [REGLA] D      │  │  044 · Permit    │ │
│  │          ▼ PROMOTOR     │  │      ▼ D98 [REGISTRO]        │  │                  │ │
│  ├─ V-RT:P1>BOT ───────────┤  │      · SET vendedores_senior │  │  FastPath:  ✓    │ │
│  │  V-RT-005               │  │      · SET gerentes_zona     │  │  PolicyPath: —   │ │
│  │  (ficha identidad nodo) │  │                              │  │                  │ │
│  └─────────────────────────┘  └─────────────────────────────┘  └──────────────────┘ │
│                                                                                      │
│  ┌─ V-RT:BOT · V-RT-009 ──────────────────────────────────────────────── [Copiar] ─┐ │
│  │  D01 · Acceso Lógico › B6 · Zona Ventas › App Ventas › [REGLA] aprobacion_t1   │ │
│  └────────────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

**`V-RT:P1` — Panel 1 Identidad Rol Template (DATOS PARTICULARES):**
- `V-RT-004` `W-006` ArbolRoles: árbol jerárquico `bauth.idn_role_template` ↔ `bauth.idn_identity_entity`
- 5 niveles: tenant → bdomain → bsubdomain → pos → actor (1.06 §4)
- Cada nodo muestra su tier via `W-009` ChipTier: `[SU]` `[SYS]` `[BIZ-Nx]` `[EXT]` `[M2M]`
- **Cada nodo lleva adjunta su identidad particular**: los valores concretos de ESE rol
  (`id`, `name`, `org_unit_id`, `sector_code`, `tenant_id`, `accountability_chain`, vigencia,
  aprobadores de cambio, etc.) — distintos en cada nodo, derivados del esquema D0/B1 del Panel 2
- Clic en un nodo → lo activa + expande `V-RT-005` FichaIdentidadNodo (`V-RT:P1>BOT`) +
  resalta en Panel 2 las reglas que lo referencian vía `V-RT-010` EnlaceCruzado
- El objeto **"Identidad RT"** de la paleta (`G-BD-003`) crea un nodo nuevo con su identidad particular

#### CRUD de Panel 1 — `bauth.idn_role_template`

El CRUD opera exclusivamente sobre los campos de identidad de la tabla `bauth.idn_role_template`.
Nada del árbol AtomLang (campo `template`) se toca desde aquí — ese es territorio de Panel 2.

**Campos editables por el administrador:**

| Campo | Tipo | Obligatorio | Editable | Notas |
|---|---|:---:|:---:|---|
| `id` | TEXT PK | ✓ | ✗ | Inmutable tras creación. Ej: `ROL-GERENTE-VENTAS` |
| `parent_id` | TEXT FK | ✓ | ✓ | Pre-relleno con el nodo seleccionado al crear |
| `tier` | TEXT | ✓ | ✓ | `SU·SYS·BIZ_N1..N5·EXT_N0·M2M·VISITANTE` |
| `hierarchy_level` | INTEGER | ✓ | ✓ | Derivado del parent; ajustable manualmente |
| `type_id` | TEXT | — | ✓ | `TYPE-OPERATIVO`, `TYPE-SUPERVISOR`, etc. |
| `tenant_id` | TEXT | ✓ | ✓ | Default `*` (global) |
| `empresa_id` | TEXT | ✓ | ✓ | Default `*` (global) |
| `status` | TEXT | ✓ | ✓ | 7 estados: `DEFINIDO→DESARROLLADO→REVISADO→AUTORIZADO→PUBLICADO→DEPRECADO→RETIRADO` |
| `version` | TEXT | ✓ | ✓ | Semver. Default `1.0.0` |
| `loa_required` | INTEGER | ✓ | ✓ | 1–4 (AAL nivel mínimo requerido) |
| `mfa_required` | BOOLEAN | ✓ | ✓ | Default `false` |
| `step_up_enabled` | BOOLEAN | ✓ | ✓ | Default `false` |
| `sod_group` | TEXT | — | ✓ | Grupo SoD al que pertenece (nullable) |
| `max_sessions` | INTEGER | — | ✓ | Default `1` |
| `session_timeout` | INTEGER | — | ✓ | Segundos. Default `28800` (8h) |
| `audit_level` | TEXT | ✓ | ✓ | `none · basic · full` |
| `owner_tenant` | TEXT | ✓ | ✓ | Default `*` |
| `start_time` | TIMESTAMPTZ | ✓ | ✓ | Vigencia desde. Default `now()` |
| `expiry_time` | TIMESTAMPTZ | — | ✓ | Vigencia hasta (nullable = sin expiración) |

**Campos gestionados por el sistema (solo lectura en UI):**

`path_ids` · `rol_bitmask_base64` · `sam128_*` · `sync_status` · `sync_error` ·
`last_sync_at` · `created_at` · `updated_at` · `created_by` · `issuer` ·
`template` · `template_version`

---

**Operaciones CRUD:**

**C — Crear rol** (botón `+ Nuevo rol` en toolbar de Panel 1, o clic derecho en nodo padre → *Nuevo hijo*)
- Se abre un Sheet lateral con los campos obligatorios y opcionales de la tabla
- `id`: el admin escribe el identificador canónico del rol (ej: `ROL-JEFE-ZONA-NORTE`)
- `parent_id`: pre-relleno con el nodo seleccionado; ajustable
- `tier` y `hierarchy_level`: propuesta automática basada en el parent; ajustable
- Campos con default: se muestran pre-rellenos, el admin puede cambiarlos
- Campos de sistema (`created_by`, `issuer`, `created_at`, `status='DEFINIDO'`): asignados automáticamente
- Al confirmar: INSERT en `bauth.idn_role_template`; el nodo aparece en el árbol inmediatamente

**R — Ver identidad** (clic en cualquier nodo del árbol)
- Panel inferior de Panel 1 muestra la ficha completa del nodo seleccionado
- Se muestran todos los campos editables + los de solo lectura (`path_ids`, `created_at`, etc.)
- Botones `Editar` y `Retirar` disponibles según el `status` actual del rol

**U — Editar identidad** (botón `Editar` en la ficha del nodo)
- Mismo Sheet que Crear, pero con los valores actuales pre-rellenos
- `id` bloqueado (inmutable)
- Al confirmar: UPDATE en `bauth.idn_role_template`; se actualiza `updated_at` automáticamente
- **Transición de `status`**: solo avanza en secuencia (`DEFINIDO→DESARROLLADO→…`); no retrocede excepto a `RETIRADO`

**D — Retirar / Eliminar rol** (botón `Retirar` en la ficha, o clic derecho → *Retirar*)
- **Soft delete**: cambia `status` a `RETIRADO` — disponible siempre
- **Hard delete**: solo si `status = DEFINIDO` AND sin roles hijos — muestra confirmación explícita
  con la advertencia: *"Esta acción es irreversible. El rol no tiene hijos ni átomos asignados."*
- Si el rol tiene hijos o `status > DEFINIDO`: solo se ofrece la opción de Retirar (soft)

**Panel 2 — Rol Template — DOS PARTES (DATOS GENERALES):**

*Parte A — Identidad general (D0/B1):*
- El **esquema de identidad** que todo rol debe cumplir: estructura canónica de campos
  (`id`, `parent_id`, `type_id`, `hierarchy_level`, `name{}`, `metadata{}`, `audit{}`,
  `digital_signature{}`) definida en A.01 §3 B1
- Es el MOLDE genérico — define los campos, no los valores de ningún rol concreto
- Los valores particulares de cada rol viven en los nodos del Panel 1

*Parte B — Árbol de políticas/reglas/átomos (D1–D13, D98, D99):*
- El árbol AtomLang `.atm.yaml` con toda la lógica de autorización
- Nodos coloreados por tipo: `[POLICYSET]` azul · `[POLICY]` naranja · `[REGLA]` rojo · `[REGISTRO]` gris
- Linter inline: errores `⚠ ATOMC-E-xxx` en rojo · warnings `⚠ ATOMC-W-xxx` en ámbar
- Enlace `●──` cuando un nodo tiene `subject.kind = ROL` o `subject.kind = SET` → apunta al
  nodo correspondiente en Panel 1
- La paleta de objetos AtomLang (§4.4 Bloque 3) actúa sobre esta parte

**Panel 3 — Compilado:**
- Resultado de `atomc` Fase 3: vector RolBitMask one-hot N-bit
- Lista de átomos compilados con su posición y efecto (Permit/Deny)
- `FastPath ✓` si todos los átomos están en el catálogo BitMask
- Solo se actualiza al presionar "Publicar" desde §4.5 AtomLang del Bloque 3
- Muestra estado `DESACTUALIZADO` si el Panel 2 fue editado después de la última compilación

---

## 7. Completitud de Roles

> **Estado:** EN DISEÑO
> **Aprobado:** —
> **Pendiente:** · implementar

**Ruta:** `roles` — Archivo: `vistas/vista_roles.dart` (legacy — a reescribir)

**Propósito:** El RolTemplate es un árbol único y global — tan extenso que trabajarlo
completo dificulta concentrarse en un rol particular. Esta vista ofrece una lente por rol:
filtra el template único y presenta solo lo que aplica al rol seleccionado, permitiendo
completar y especializar su configuración sin interferir con el resto del template.

**Separación de responsabilidades:**
- **§6** — crea, edita y retira roles (`bauth.idn_role_template` — identidad)
- **§7** — completa la configuración de cada rol dentro del template único (especialización)

**Audiencia:** Administrador IAM — conoce la arquitectura del template y actúa con criterio.

### Layout — 2 bloques sobre el outlet

```
┌── OUTLET — Completitud de Roles  V-CR ───────────────────────────────────────────────┐
│                                                                                       │
│  ┌─ V-CR:B1 · V-CR-001  340px ─────────────┐  ┌─ V-CR:B2 · V-CR-006 flex 1 ────────┐ │
│  │  V-CR:B1>TOP  V-CR-002 BarraTiers        │  │  ┌─ V-CR:B2>TOP · V-CR-007 ──────┐ │ │
│  │  [TODOS][SU][SYS][BIZ_N1]…  W-009       │  │  │  [SU] SuperUsuario  ← auto    │ │ │
│  ├──────────────────────────────────────────┤  │  └───────────────────────────────┘ │ │
│  │  V-CR-004 FilaRol                        │  │  ┌─ V-CR:B2>OUT · V-CR-008 ──────┐ │ │
│  │  ● [SU] SuperUsuario  W-009   ← auto     │  │  │  [Métodos][Átomos][Saga]      │ │ │
│  │    ▼ [SYS] Sistema    W-009              │  │  │  V-CR:B2>T1 / T2 / T3         │ │ │
│  │      ▼ [BIZ-N1] Dir.                     │  │  │  (filtro por rol activo)      │ │ │
│  │        ▼ [BIZ-N2]                        │  │  │                               │ │ │
│  │          ▼ GERENTE_VENTAS                │  │  └───────────────────────────────┘ │ │
│  │            ▼ VENDEDOR                    │  │  ┌─ V-CR:B2>BOT · V-CR-009 ──────┐ │ │
│  │            ▼ PROMOTOR                    │  │  │  [Publicar]    [Cancelar]     │ │ │
│  ├──────────────────────────────────────────┤  │  └───────────────────────────────┘ │ │
│  │  V-CR-005 PieListaRoles                  │  │  V-CR-010 W-007 (si sin selección) │ │
│  └──────────────────────────────────────────┘  └────────────────────────────────────┘ │
│                                                                                       │
│  ← al seleccionar GERENTE_VENTAS en Bloque 1:                                        │
│                                                                                       │
│  ┌─ Bloque 1: IDENTIDAD ROL TEMPLATE ──────┐  ┌─ Bloque 2 ─────────────────────────┐ │
│  │  ...                                     │  │  ┌─ TOP ───────────────────────┐   │ │
│  │   ●──── GERENTE_VENTAS  ← seleccionado   │  │  │  GERENTE_VENTAS             │   │ │
│  │          ▼ VENDEDOR                      │  │  └─────────────────────────────┘   │ │
│  │          ▼ PROMOTOR                      │  │  ┌─ OUTLET ────────────────────┐   │ │
│  │                                          │  │  │  ▼ D01 [POLICYSET]          │   │ │
│  └──────────────────────────────────────────┘  │  │    ▼ B6 [POLICYSET]         │   │ │
│                                                 │  │      ▼ [POLICY] zona_ventas │   │ │
│                                                 │  │        [REGLA] Permit ●     │   │ │
│                                                 │  │  ▼ D98 [REGISTRO]           │   │ │
│                                                 │  │    · SET gerentes_zona ●    │   │ │
│                                                 │  └─────────────────────────────┘   │ │
│                                                 │  ┌─ BOTTOM ────────────────────┐   │ │
│                                                 │  │  [Publicar]    [Cancelar]   │   │ │
│                                                 │  └─────────────────────────────┘   │ │
│                                                 └────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────────────────────┘
```

**Bloque 1 — `PanelIdentidadRoles` (widget compartido con §6 Panel 1):**

> El contenido de este bloque ES el mismo widget que §6 Panel 1.
> Se reproduce aquí completo para que la muestra sea legible sin saltar de sección.

```
┌─ 1: IDENTIDAD ──────────┐
│  idn_role_template      │
│  ↔ idn_identity_entity│
├─────────────────────────┤
│                         │
│  ▼ [SU] SuperUsuario    │
│    ▼ [SYS] Sistema      │
│      ▼ [BIZ-N1] Dir.    │
│        ▼ [BIZ-N2]       │
│   ●──── GERENTE_VENTAS  │
│          ▼ VENDEDOR     │
│          ▼ PROMOTOR     │
│                         │
│  ● nodo activo          │
│  ── enlace cruzado      │
│     con Panel 2         │
└─────────────────────────┘
```

**Descripción del widget:**
- Árbol jerárquico de todos los roles del sistema extraído de `bauth.idn_role_template` ↔ `bauth.idn_identity_entity`
- 5 niveles en la jerarquía: tenant → bdomain → bsubdomain → pos → actor (1.06 §4)
- Cada nodo muestra su tier (`[SU]` `[SYS]` `[BIZ-Nx]` `[EXT]` `[M2M]`)
- **Cada nodo lleva adjunta su identidad particular**: los valores concretos de ESE rol
  (`id`, `name`, `org_unit_id`, `sector_code`, `tenant_id`, `accountability_chain`, vigencia,
  aprobadores de cambio, etc.) — distintos en cada nodo, derivados del esquema D0/B1 del Panel 2
- Clic en un nodo → lo selecciona y dispara el filtro del OUTLET en Bloque 2
- **Al cargar la pantalla**: se auto-selecciona el primer nodo del árbol y se aplica el primer filtro
- **Solo lectura aquí** — el CRUD de identidad del rol pertenece a §6 Panel 1

> ⚠️ En §7 Bloque 1 NO hay CRUD de rol. Este widget es exclusivamente un selector.
> El CRUD de `bauth.idn_role_template` está definido en §6 — Panel 1 · CRUD.

---

**Bloque 2 — estructura TOP / OUTLET / BOTTOM:**

**TOP — nombre del rol activo:**
- Muestra el `id` del rol seleccionado en Bloque 1 (ej: `GERENTE_VENTAS`)
- **Nunca vacío**: al cargar la pantalla se auto-selecciona el primer nodo del árbol
- Sirve de contexto visual permanente: el admin sabe en todo momento sobre qué rol está trabajando

**OUTLET — vista filtrada del template único, por rol:**

Muestra el RolTemplate global filtrado según el rol seleccionado en Bloque 1.
El template es único — el OUTLET es solo una lente. Nada vive aquí de forma separada.

**Reglas de filtro (se aplican en orden):**

| Condición del nodo en el template global | Visible en OUTLET |
|---|:---:|
| No tiene `SET` definido — aplica a todos los roles | ✓ Siempre visible |
| Tiene `SET` que **incluye** al rol seleccionado | ✓ Visible (marcado `●`) |
| Tiene `SET` que incluye **otros roles** pero no al seleccionado | ✗ Oculto |
| Tiene `UNSET` que nombra al rol seleccionado | ✗ Excluido explícitamente |

**Propiedad `UNSET`:**
Propiedad opcional en cada nodo del template. Lista los roles para los cuales ese nodo
NO es visible ni asignable — aunque no tengan un SET que los excluya. El filtro la respeta.
```yaml
# Ejemplo en el template:
- nodo: zona_financiero_critico
  subject: SET(auditores_financieros)
  UNSET: [ROL-GERENTE-VENTAS, ROL-PROMOTOR]   # estos roles nunca ven este nodo
```

**Reglas de edición en el OUTLET:**
- Los nodos **sin SET** (universales): solo lectura — el admin los ve pero no los toca aquí
- Los nodos con **SET que incluye este rol**: solo lectura — fueron definidos en otro contexto
- Los nodos **agregados desde esta pantalla** para este rol: editables y eliminables
- Al agregar un nodo nuevo desde §7: se crea en el template global con `SET({rol_seleccionado})`
- Solo se puede eliminar o modificar lo que se agregó desde §7 — nunca el template general

**Contenido del OUTLET — tres tabs:**

El OUTLET navega entre las tres secciones mediante tabs. El rol activo (TOP) es siempre visible.

---

#### Tab 1 — Métodos

```
┌─ OUTLET ──────────────────────────────────────────────────────────────────────┐
│  [ Métodos ]  Átomos    Saga de Autenticación                                 │
│  ─────────────────────────────────────────────────────────────────────────── │
│                                                                               │
│  ┌─ ASIGNADOS — tier BIZ_N3 (template general · solo lectura) ─────────────┐ │
│  │  ✓  password              [general]                                      │ │
│  │  ✓  totp                  [general]                                      │ │
│  │  ✓  email_otp             [general]                                      │ │
│  └──────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌─ REQUERIDOS — específicos de este rol (editables) ──────────────────────┐ │
│  │  ✓  webauthn_2fa          [este rol]                               [×]  │ │
│  │  ✓  x509_mtls             [este rol]                               [×]  │ │
│  │  [+ Agregar método requerido ▾]                                         │ │
│  └──────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌─ ALTERNATIVOS — específicos de este rol (editables) ────────────────────┐ │
│  │  ✓  recovery_codes        [este rol]                               [×]  │ │
│  │  [+ Agregar método alternativo ▾]                                       │ │
│  └──────────────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────────────┘
```

**Leyenda:**
- `[general]` gris — heredado del template, solo lectura
- `[este rol]` color — agregado desde §7 para este rol, editable y eliminable con `[×]`
- `[+ Agregar ▾]` — desplegable con los métodos disponibles no asignados aún
- Fuente: `D1 · B4 · Autenticación (métodos)`

---

#### Tab 2 — Átomos

```
┌─ OUTLET ──────────────────────────────────────────────────────────────────────┐
│  Métodos    [ Átomos ]  Saga de Autenticación                                 │
│  ─────────────────────────────────────────────────────────────────────────── │
│                                                                               │
│  ┌─ HEREDADOS — via SET gerentes_ventas (solo lectura) ────────────────────┐ │
│  │  ▼ CRM                                                                  │ │
│  │    ▼ Clientes · Gestión                                                 │ │
│  │      ✓  cliente.leer         Permit  [general] ●                        │ │
│  │      ✓  cliente.actualizar   Permit  [general] ●                        │ │
│  │      ✗  cliente.eliminar     Deny    [general] ●                        │ │
│  │  ▼ ERP                                                                  │ │
│  │    ▼ Ventas · Cotizaciones                                              │ │
│  │      ✓  cotizacion.crear     Permit  [general] ●                        │ │
│  │      ✓  cotizacion.aprobar   Permit  [general] ●                        │ │
│  └──────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌─ AGREGADOS — específicos de este rol (editables) ───────────────────────┐ │
│  │  ▼ ERP                                                                  │ │
│  │    ▼ Reportes                                                           │ │
│  │      ✓  reporte.exportar     Permit  [este rol]                    [×]  │ │
│  │      ✓  reporte.consolidar   Permit  [este rol]                    [×]  │ │
│  │  [+ Agregar átomo ▾]                                                    │ │
│  └──────────────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────────────┘
```

**Leyenda:**
- `●` — el nodo referencia al rol seleccionado vía SET en el template
- `✓ Permit` / `✗ Deny` — efecto del átomo
- `[general]` gris — heredado, solo lectura; `[este rol]` color — editable con `[×]`
- `[+ Agregar átomo ▾]` — selector App → Módulo → Grupo → Verbo + efecto Permit/Deny
- Fuente: `D1 · B7 · Privilegios de Aplicaciones` + D98 SETs

---

#### Tab 3 — Saga de Autenticación

```
┌─ OUTLET ──────────────────────────────────────────────────────────────────────┐
│  Métodos    Átomos    [ Saga de Autenticación ]                               │
│  ─────────────────────────────────────────────────────────────────────────── │
│                                                                               │
│  Paso 1 ────────────────── password                      [general]           │
│     │                                                                         │
│     ├── si LoA < 2 ──────── Paso 2: totp                [general]           │
│     │                           │                                             │
│     │                           └── si falla ────────── Paso 3:             │
│     │                                                    recovery_codes       │
│     │                                                    [este rol]  [×]     │
│     │                                                                         │
│     └── si accede desde IP externa ── Paso 2b: webauthn_2fa                  │
│                                                [este rol]  [×]               │
│                                                    │                          │
│                                                    └─── emitir JWT ✓         │
│                                                                               │
│  [+ Agregar paso]    [+ Agregar condición]                                    │
│                                                                               │
│  LoA resultante: AAL2   MFA: requerido   step_up: habilitado                 │
└───────────────────────────────────────────────────────────────────────────────┘
```

**Leyenda:**
- Flujo de izquierda a derecha y de arriba a abajo — cada paso tiene un método y una condición
- `[general]` gris — paso heredado del template, solo lectura
- `[este rol]` color — paso agregado aquí para este rol, editable y eliminable con `[×]`
- Pie del tab: resumen calculado del LoA resultante, si MFA es requerido y si step-up está activo
- Fuente: `D1 · step_up_triggers` + `required_methods` + `alternative_methods` (RFC 9470)

**BOTTOM — acciones:**

```
┌─ BOTTOM ──────────────────────────────────────────────────┐
│  [Publicar]                              [Cancelar]        │
└───────────────────────────────────────────────────────────┘
```

- **Publicar**: persiste la especialización del rol en el template único (ver arquitectura abajo)
- **Cancelar**: descarta los cambios no publicados y restaura el estado anterior

---

**Arquitectura fundamental — UN solo RolTemplate:**

> No existe un template por rol. Hay **un único RolTemplate** compartido por todos los roles.
> El OUTLET de Bloque 2 es una **vista filtrada** de ese template único, no un almacén separado.
> Todos los datos viven en `template` JSONB de `bauth.idn_role_template` (el template global).

Cuando el admin trabaja la especialización de un rol en el OUTLET y presiona **Publicar**:

1. Por cada nodo editado, el sistema busca si ya existe un nodo equivalente en el template global
   con un `SET(...)` que contenga otros roles
2. **Si ya existe**: solo agrega el rol seleccionado a ese SET existente —
   no crea un nodo duplicado
   ```
   antes:  subject = SET(vendedores)          → {ROL-VENDEDOR, ROL-PROMOTOR}
   después: subject = SET(vendedores)          → {ROL-VENDEDOR, ROL-PROMOTOR, ROL-GERENTE-VENTAS}
   ```
3. **Si no existe**: crea el nodo nuevo en el template global con `subject = SET({este_rol})`
4. Al filtrar en el OUTLET para otro rol, los nodos donde ese rol está en el SET aparecerán
   automáticamente — el filtro es el mecanismo de vista, no de almacenamiento

**Consecuencia directa**: lo que se define aquí para GERENTE_VENTAS queda en el template global
bajo el SET que lo contiene. Si mañana se filtra por ROL-DIRECTOR-VENTAS y ese director pertenece
al mismo SET, verá esas mismas reglas — porque comparten el SET, no porque tengan templates separados.

**Propiedad `UNSET` en el template:**
Complementa el mecanismo SET. Permite excluir un rol de ver o recibir un nodo aunque no
haya un SET que lo bloquee. El filtro del OUTLET la evalúa antes de mostrar cualquier nodo.

**Selección por defecto:**
Al cargar §7, se auto-selecciona el primer rol del árbol (Bloque 1) y se ejecuta el filtro
inmediatamente — el OUTLET nunca aparece vacío al entrar a la pantalla.

```
┌── OUTLET  V-CR ─────────────────────────────────────────────────────────────────────┐
│                                                                                     │
│  ┌── V-CR:B1 · V-CR-001  340px ──────────┐  ┌── V-CR:B2 · V-CR-006 flex 1 ───────┐ │
│  │ V-CR:B1>TOP  V-CR-002 BarraTiers       │  │                                     │ │
│  │ [TODOS][SU][SYS][BIZ_N1][BIZ_N2]      │  │  V-CR:B2>TOP  V-CR-007              │ │
│  │ [BIZ_N3][BIZ_N4][BIZ_N5][EXT_N0]      │  │  vendedor_senior                    │ │
│  │ [M2M][VISITANTE]   ← scroll horiz W-009│  │  ─────────────────────────         │ │
│  ├────────────────────────────────────────┤  │  biz_vendedor_senior_v2  [BIZ_N2]  │ │
│  │ V-CR-004 FilaRol                       │  │  W-009                              │ │
│  │ vendedor_senior   [BIZ_N2] 24⚛  W-009 │  │                                     │ │
│  │ biz_vendedor_senior_v2                 │  │  Estado    activo  W-004            │ │
│  ├────────────────────────────────────────┤  │  Átomos    24                       │ │
│  │ cajero             [BIZ_N1] 12⚛  W-009│  │                                     │ │
│  │ biz_cajero_standard_v3                 │  │  ACCIONES                           │ │
│  ├────────────────────────────────────────┤  │  [👤 Asignar a usuario]             │ │
│  │ gerente_ventas     [BIZ_N3] 38⚛  W-009│  │  [⎇ Ver herencia]                   │ │
│  │ biz_gerente_ventas_v1                  │  │                                     │ │
│  ├────────────────────────────────────────┤  │  ← V-CR-010 W-007 si sin selección  │ │
│  │ su_admin               [SU] 64⚛  W-009│  │                                     │ │
│  ├────────────────────────────────────────┤  │     [🛡️] Selecciona un rol           │ │
│  │ sys_auditoria         [SYS] 31⚛  W-009│  │                                     │ │
│  ├────────────────────────────────────────┤  │                                     │ │
│  │ V-CR-005  366 roles                    │  │                                     │ │
│  └────────────────────────────────────── ┘  └─────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

**Barra de tiers (scroll horizontal):**
- Pills clicables: `TODOS` `SU` `SYS` `BIZ_N1` `BIZ_N2` `BIZ_N3` `BIZ_N4` `BIZ_N5` `EXT_N0` `M2M` `VISITANTE`
- Activo = fondo primary, texto primaryForeground
- Inactivo = fondo muted, texto mutedForeground

**Color de pills de tier en la lista:**
- `SU` / `SYS` → rojo (destructive con 15% opacidad)
- `BIZ_N4` / `BIZ_N5` → azul primary (con 12% opacidad)
- resto → muted

**Fila de rol:**
- Nombre (bold 12.5px) + ID (11px muted monospace) columna izquierda
- Pill de tier + contador de átomos `24 ⚛` a la derecha

**Pie del panel izquierdo:**
- Barra de `N roles [· TIER_ACTIVO]` (11px, muted, fondo muted 36px alto)

---

## 8. Vista: Usuarios

> **Estado:** EN DESARROLLO  
> **Aprobado:** —  
> **Pendiente:** · verificar maqueta contra `vista_usuarios.dart` · conectar datos reales

**Ruta:** `usuarios` — Archivo: `vistas/vista_usuarios.dart`

```
┌── OUTLET  V-US ─────────────────────────────────────────────────────────────────────┐
│                                                                                     │
│  ┌── V-US:B1 · V-US-001  320px ──────────┐  ┌── V-US:B2 · V-US-005 flex 1 ───────┐ │
│  │  V-US:B1>TOP                           │  │                                     │ │
│  │  ┌──────────────────────────────────┐  │  │  V-US-006 FichaUsuario             │ │
│  │  │ V-US-002 W-010  🔍 Buscar...     │  │  │                                     │ │
│  │  └──────────────────────────────────┘  │  │  ╔══╗  jperez      W-005           │ │
│  ├────────────────────────────────────────┤  │  ║JP║  jperez@skull.com            │ │
│  │  V-US-003 FilaUsuario                  │  │  ╚══╝                [activo] W-004│ │
│  │  ╔══╗  jperez             [activo]     │  │                                     │ │
│  │  ║JP║  W-005   W-004                  │  │  INFORMACIÓN                        │ │
│  ├────────────────────────────────────────┤  │  UUID     3f2a-... (monospace)      │ │
│  │  V-US-003 FilaUsuario                  │  │  Tipo     HUMAN                     │ │
│  │  ╔══╗  mgomez             [activo]     │  │                                     │ │
│  │  ║MG║  W-005   W-004                  │  │  ROLES ASIGNADOS         2          │ │
│  ├────────────────────────────────────────┤  │  V-US-007 ChipsRolesAsignados       │ │
│  │  V-US-003                              │  │  [vendedor_senior]                  │ │
│  │  ╔══╗  sa_admin           [activo]     │  │  [supervisor_regional]              │ │
│  │  ║SA║  W-005   W-004                  │  │                                     │ │
│  ├────────────────────────────────────────┤  │  ← V-US-008 W-007 si sin selección  │ │
│  │  V-US-003                              │  │                                     │ │
│  │  ╔══╗  bot_sync          [inactivo]    │  │     [🔍] Selecciona un usuario      │ │
│  │  ║BS║  W-005   W-004                  │  │                                     │ │
│  ├────────────────────────────────────────┤  │                                     │ │
│  │  V-US-004  4 usuarios                  │  │                                     │ │
│  └────────────────────────────────────── ┘  └─────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

**`V-US:B1>TOP`** `V-US-002` `W-010` — barra búsqueda full-width (fondo muted, borde, lupa 14px)

**`V-US-003` FilaUsuario:**
- `W-005` AvatarCircular (32px): inicial del username, fondo primary 15% opacidad, letra primary
- Username (bold 13px) + email (11px muted)
- `W-004` ChipEstado: `activo` (fondo primary 12%) o `inactivo` (muted)

**`V-US-006` FichaUsuario — panel detalle:**
- `W-005` AvatarCircular grande (44px) + username 17px bold + email 12px muted + `W-004` chip estado
- Sección "INFORMACIÓN": UUID (monospace) + Tipo de cuenta
- Sección "ROLES ASIGNADOS": counter + `V-US-007` ChipsRolesAsignados: chips `[nombre_rol]` en Wrap

**`V-US-004` PieListaUsuarios:**
- `N usuarios` (11px, muted, fondo muted 36px alto)

---

## 9. Vista: Árbol de Entidades

> **Estado:** EN DESARROLLO  
> **Aprobado:** —  
> **Pendiente:** · modelo D00 `idn_identity_entity` (5 niveles: tenant/bdomain/bsubdomain/pos/actor) implementado en Dart pero API `bauth.entidad.tree` aún no existe en el servidor Rust · panel de detalle funciona con datos mock · verificar maqueta contra `vista_entidades.dart`

**Ruta:** `identidad` — Archivo: `vistas/vista_entidades.dart`

```
┌── OUTLET  V-AE ─────────────────────────────────────────────────────────────────────┐
│                                                                                     │
│  ┌── V-AE:B1 · V-AE-001  340px ──────────┐  ┌── V-AE:B2 · V-AE-005 flex 1 ───────┐ │
│  │ V-AE:B1>TOP  V-AE-002                 │  │                                     │ │
│  │ ⎇  Árbol de Entidades  40px muted     │  │  V-AE-006 FichaEntidad              │ │
│  ├────────────────────────────────────── ┤  │                                     │ │
│  │                                       │  │  V-AE-007 IconoNivel (40px)         │ │
│  │ V-AE-003 NodoEntidad  W-006           │  │  ╔════╗  SKULL                      │ │
│  │ ▼ [TNT] interno  SKULL  W-003         │  │  ║ 🏢 ║  [TNT] interno  W-003       │ │
│  │   ▼ [BDM] empresa  SKULL-CORP  W-003  │  │  ╚════╝                             │ │
│  │     ▼ [BSD] sucursal  Norte   W-003   │  │                                     │ │
│  │       ▼ [POS] caja  CAJA-01   W-003   │  │  IDENTIFICADORES                    │ │
│  │         ─ [ACT] HUMAN  Juan   W-003   │  │  ID      3a2b-c4d5-... (mono)       │ │
│  │         ─ [ACT] HUMAN  María  W-003   │  │  Slug    skull-corp (mono)           │ │
│  │     ▼ [BSD] deposito  Dep-A   W-003   │  │  Tenant  root-tenant-id (mono)       │ │
│  │       ▼ [POS] estante  Est-01 W-003   │  │                                     │ │
│  │         ─ [ACT] producto  Lap W-003   │  │  POSICIÓN EN EL ÁRBOL               │ │
│  │   ▼ [BDM] almacen  Almacén   W-003   │  │  Nivel   tenant                     │ │
│  │     ▼ [BSD] deposito  Bodega  W-003   │  │  Tipo    interno                    │ │
│  │   ─ [BDM] datacenter  DC     W-003   │  │                                     │ │
│  │                                       │  │  HIJOS DIRECTOS                     │ │
│  │                                       │  │  [BDM] empresa  · [BDM] almacen     │ │
│  ├───────────────────────────────────────┤  │                                     │ │
│  │ V-AE-004  11 entidades               │  │  ← V-AE-008 W-007 si sin selección   │ │
│  └──────────────────────────────────────┘  │     [⎇] Selecciona una entidad       │ │
│                                            └─────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

**`W-003` BadgeNivel — colores por nivel:**

| Badge | Nivel       | Color fondo   | Color texto  |
|-------|-------------|---------------|--------------|
| `TNT` | tenant      | violeta 18%   | violeta      |
| `BDM` | bdomain     | azul 18%      | azul         |
| `BSD` | bsubdomain  | teal 18%      | teal         |
| `POS` | pos         | ámbar 18%     | ámbar        |
| `ACT` | actor       | verde 18%     | verde        |

**Indentación de nodos:**
- Cada nivel de profundidad agrega 18px de sangría izquierda
- Nodos con hijos muestran `▼` (expandido) o `▶` (colapsado) en 12px muted
- Nodos hoja muestran `─` (sin ícono, mismo ancho 12px)
- El `tipo` va en monospace 10px muted; el `nombre` en 12px foreground

**Nodo seleccionado:**
- Fondo primary 10% opacidad en toda la fila
- Nombre en primary (color acento) + bold

**Panel detalle — ícono de nivel:**
- Cuadrado redondeado 40px con fondo coloreado (15% opacidad del color del nivel)
- Ícono dentro: 🏢 (tenant) / ⬛ (bdomain/layers) / 📍 (bsubdomain) / 💻 (pos/monitor) / 👤 (actor)

---

## 10. Vistas en construcción

> **Estado:** MAQUETA  
> **Aprobado:** —  
> **Pendiente:** · todas las rutas siguientes muestran `_VistaEnConstruccion` · se irán implementando y moviendo a secciones propias conforme avance el desarrollo

Las siguientes rutas muestran el marcador `_VistaEnConstruccion`:

```
┌── OUTLET ────────────────────────────────────────────────────────────────┐
│                                                                          │
│                                                                          │
│                          ⚙️                                              │
│                    En construcción                                       │
│                                                                          │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

Rutas pendientes: `conectados`, `utpl`, `pol`, `appcat`, `politicas`, `uso`,
`sync`, `auditoria`, `bos`, `blockchain`, `cuenta`, `soporte`, `config`

---

## 11. Sidenav colapsado (76 px)

> **Estado:** MAQUETA  
> **Aprobado:** —  
> **Pendiente:** · actualizar iconos del grupo CRUD (11 ítems) en la vista colapsada · implementar toggle colapsado para Bloque 3 (DER) — actualmente solo Bloque 1 tiene toggle · verificar animación en código

Cuando el usuario presiona `≪` en la BarraSuperior, el sidenav se anima hasta 76px
mostrando solo íconos (sin etiquetas ni títulos de grupo):

```
┌──────────┐  ← 76 px
│ ╔══╗     │  ← TOP 56px: solo logo, sin texto
│ ║🛡️║     │
│ ╚══╝     │
├──────────┤
│   ⊞      │  ← GENERAL: solo íconos, sin títulos de grupo
│   👥     │
│          │
│   🪪     │  ← TEMPLATES
│   🛡     │
│   👤     │
│   📦     │
│          │
│   ⚙      │  ← CRUD
│   🌐     │
│   🧱     │
│   🏷     │
│   ⚡     │
│   🛡     │
│   👥     │
│   📦     │
│   🧩     │
│   🔗     │
│   📋     │
│          │
│   ⎇     │  ← IDENTIDAD
│   📈     │
│          │
│   🔄     │  ← SISTEMA
│   📄     │
│   🛡     │
│   🔗     │
│          │
│   💳     │  ← CUENTA
│   🎧     │
│   ─────  │
│   ⊞      │  ← Configuración (fijo al pie)
├──────────┤
│ ●        │  ← BOTTOM 48px: solo punto verde, sin texto
└──────────┘
```

Los ítems activos siguen resaltados. Los badges y puntos de estado no se muestran en modo colapsado.

---

## Resumen de rutas implementadas

| Ruta          | Vista                  | Archivo                     | Estado        |
|---------------|------------------------|-----------------------------|---------------|
| `dashboard`   | Dashboard de Salud     | `vista_dashboard.dart`      | ✅ Completa   |
| `rtpl`        | Rol Template           | `vista_rol_template.dart`   | ✅ Completa   |
| `roles`       | Completitud de Roles   | `vista_roles.dart` (legacy) | 🔧 Rediseño   |
| `usuarios`    | Usuarios IAM           | `vista_usuarios.dart`       | ✅ Nueva      |
| `identidad`   | Árbol de Entidades     | `vista_entidades.dart`      | ✅ Nueva      |
| `conectados`  | Usuarios Conectados    | —                           | 🔧 Placeholder|
| `utpl`        | User Template          | —                           | 🔧 Placeholder|
| `pol` / `politicas` | Políticas        | —                           | 🔧 Placeholder|
| `appcat`      | Aplicaciones           | —                           | 🔧 Placeholder|
| `uso`         | Uso del Sistema        | —                           | 🔧 Placeholder|
| `sync`        | Sincronización         | —                           | 🔧 Placeholder|
| `auditoria`   | Auditoría              | —                           | 🔧 Placeholder|
| `bos`         | Visión BOS             | —                           | 🔧 Placeholder|
| `blockchain`  | Blockchain             | —                           | 🔧 Placeholder|
| `cuenta`      | Mi Cuenta              | —                           | 🔧 Placeholder|
| `soporte`     | Soporte SBOS           | —                           | 🔧 Placeholder|
| `config`      | Configuración          | —                           | 🔧 Placeholder|
