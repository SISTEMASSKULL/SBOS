# A.63 — Objetos Compuestos del Árbol AtomLang v2.1.0
## Arquitectura completa del Desktop bAuth: shell, dos editores, buscador, compilación y flujos de trabajo

**Versión:** 2.1.0
**Fecha:** 2026-07-15
**Tipo de anexo:** A (traslado de SSOT) + C (justificación de decisión técnica)
**Respalda a:** [2.13 AtomLang v2.0](../2.13_MANUAL-ATOMLANG-LENGUAJE-v2.0.md) · [1.06 D00 Identidad v2.1.0](../1.06_MANUAL-D00-IDENTIDAD-v2.0.md) · [2.15 Motor de Identidad v1.2.0](../2.15_MANUAL-MOTOR-IDENTIDAD-v1.0.md) · [2.17 Motor de Roles v1.1.0](../2.17_MANUAL-MOTOR-ROLES-v1.0.md) · [A.56 Diseño BD Identidad](A.56_ANEXO-DISENO-BD-IDENTIDAD-v1.0.md) · [A.61 Diseño BD Roles](A.61_ANEXO-DISENO-BD-ROLES-v1.0.md)
**Reemplaza a:** A.63 v2.0.0 (2026-07-15)
**Normas base:** GoF Composite Pattern (Gamma, Helm, Johnson, Vlissides 1994) · OASIS XACML 3.0 §5 · NIST SP 800-162 §4 (PAP) · NIST SP 800-63A (IAL)
**Referencias industria:** WSO2 PAP · ONAP Policy Framework · AWS IAM Console · Okta Admin Console · VS Code (LSP, minimap) · Figma (panel de propiedades)

---

## §0 Corrección de v1.0.0 → v2.0.0 → v2.1.0

| Versión | Qué corrigió |
|---|---|
| **v2.0.0** | Separó el dashboard unificado en dos editores independientes. Degradó el Buscador de "tercer árbol" a vista de consulta. |
| **v2.1.0** | Agrega todo lo que v2.0.0 dejó sin diseñar: shell de navegación, landing page, selector multi-tenant, paneles de propiedades faltantes (7), flujo de compilación atomc, interfaz Usuario↔Rol, gestión de SETs D94/D98, navegación cruzada entre editores, NodeContract explícito, estados vacío/carga/error, undo/redo + atajos de teclado. |

---

## §1 Propósito

Definir la **arquitectura completa de la aplicación desktop de bAuth**: shell de navegación,
dos editores de árbol (Identidad y Roles), buscador de entidades, flujo de compilación atomc,
interfaz de asignación Usuario↔Rol, gestión de SETs, y todos los estados de la UI.

---

## §2 Composite Pattern — El fundamento OOP (compartido)

El patrón **Composite** (GoF) es la solución canónica para jerarquías parte-todo:

| Participante | Rol en OOP | Rol en Editor de Identidad | Rol en Editor de Roles |
|---|---|---|---|
| **Component** | Interfaz base del árbol | `NodoTemplate` — todo nodo del árbol | `NodoTemplate` — todo nodo del árbol |
| **Leaf** | Nodo sin hijos | `Actor`, `Atributo` | `Regla`, `Guardrail` |
| **Composite** | Nodo con hijos | `Tenant`, `bDomain`, `bSubDomain`, `Pos` | `Dominio`, `Bloque`, `PolicySet`, `Política` |

```
Component
  ↑             ↑
Leaf        Composite (0..* hijos)
  │              │
  │           contiene Leaves y Composites
  │
  └── ningún hijo permitido
```

**Lo que se comparte:** el patrón, la interfaz `NodoTemplate`, la validación por `NodeContract`,
el mecanismo de drag & drop.

**Lo que NO se comparte:** la paleta de objetos, los tipos de nodo, los contratos,
el panel de propiedades, los flujos de trabajo.

---

## §3 Arquitectura de la aplicación — Shell y navegación

### 3.1 Estructura general

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  BARRA SUPERIOR: [☰ Menú]  bAuth Desktop  [Tenant: SKULL ▾]  🎨 🔌 👤 admin │
├────────────┬─────────────────────────────────────────────────────────────────┤
│ SIDEBAR    │                                                                 │
│            │                     ÁREA DE TRABAJO                             │
│ 🏠 Inicio  │                    (editor activo)                              │
│ ─────────  │                                                                 │
│ IDENTIDAD  │                                                                 │
│  👥 Entidades                                                               │
│  🏷️ Atributos                                                               │
│  🔍 Buscador                                                                │
│  👥 USERSETs (D94)                                                          │
│ ─────────  │                                                                 │
│ ROLES      │                                                                 │
│  🟦 Políticas                                                               │
│  🔗 Asignaciones                                                            │
│  📋 SETs (D98)                                                              │
│ ─────────  │                                                                 │
│ 🛠️ atomc    │                                                                 │
│ 📊 Reportes │                                                                 │
│ ⚙ Admin     │                                                                 │
├────────────┴─────────────────────────────────────────────────────────────────┤
│  BARRA DE ESTADO: ✅ Conectado · interno.skull · 12 dominios · 178 reglas    │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Componentes del shell

| Componente | Qué contiene | Persiste entre navegación |
|---|---|---|
| **Barra superior** | Logo bAuth, menú hamburguesa, selector de tenant, indicadores (tema, conexión, usuario) | Sí |
| **Sidebar** | Navegación por secciones: Inicio, Identidad, Roles, atomc, Reportes, Admin | Sí |
| **Área de trabajo** | El editor activo (Identidad, Roles, Buscador, SETs, Asignaciones) | No — cambia al navegar |
| **Barra de estado** | Conexión, tenant activo, ctx_id resumido, estadísticas rápidas | Sí |

### 3.3 Selector de tenant

```
Barra superior:  [Tenant: SKULL (interno) ▾]
                  ├── 🏢 SKULL (interno)
                  ├── 🏪 Maya Representaciones (externo)
                  ├── 🚗 Toyota Bolivia (externo)
                  ├── ─────────────────
                  └── ＋ Agregar tenant...
```

Al cambiar de tenant:
- El Editor de Identidad recarga el árbol desde la raíz del nuevo tenant
- El Editor de Roles recarga las políticas del nuevo tenant
- El Buscador cambia su scope al nuevo tenant
- La barra de estado refleja `interno.maya`

**Permiso requerido:** átomo `tenant.switch` en el UserBitMask. Sin él, el dropdown aparece deshabilitado.

### 3.4 Navegación cruzada entre editores

Los dos editores no son estancos. Se navega entre ellos mediante **deep links**:

| Origen | Destino | Gatillo |
|---|---|---|
| Panel de Actor → rol asignado | Editor de Roles, rol abierto | Clic en `🔗 vendedor_senior` |
| Panel de Regla → SET en target | Vista SETs (D94/D98), SET abierto | Clic en `SET(financieros)` |
| Panel de Atributo → atom_code | Editor de Roles, átomo abierto | Clic en `atom_code: 5826` |
| Editor de Roles → entidad asignada | Editor de Identidad, entidad abierta | Clic en `👤 jperez` en asignación |
| Buscador → entidad | Editor de Identidad, entidad abierta | Botón `[Ver en árbol]` |

**Implementación:** cada navegación cruzada usa una ruta interna tipo `/identidad/actor/act-jperez` o `/roles/rol/vendedor_senior`. El sidebar marca la sección activa. La miga de pan muestra la ruta.

### 3.5 Migas de pan (breadcrumbs)

```
Editor de Identidad:
🏠 Inicio > 👥 Entidades > 🏢 SKULL > 📁 SKULL-CORP > 📂 Norte > 📍 CAJA-01 > 👤 jperez

Editor de Roles:
🏠 Inicio > 🟦 Políticas > 🟦 D1 · ACCESO > 🟩 B4 · Autenticación > 🟧 password_policy > 🟥 longitud_mínima
```

Cada segmento es cliqueable. Navega al nivel correspondiente del árbol.

---

## §4 Landing page — Inicio

Al abrir la aplicación, el usuario ve:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  BARRA SUPERIOR: [☰]  bAuth Desktop  [Tenant: SKULL ▾]  🎨 🔌 👤 admin      │
├────────────┬─────────────────────────────────────────────────────────────────┤
│ 🏠 Inicio  │  🏠 INICIO — bAuth Identity Control Plane                       │
│            │                                                                 │
│            │  ┌─────────────────────┐ ┌─────────────────────┐ ┌────────────┐ │
│            │  │ 👥 ENTIDADES        │ │ 🟦 POLÍTICAS        │ │ 📊 ROLES   │ │
│            │  │                     │ │                     │ │            │ │
│            │  │   1 tenant          │ │   12 dominios       │ │   548      │ │
│            │  │   7 bDomains        │ │   41 políticas      │ │   activos  │ │
│            │  │   12 Actores        │ │   178 reglas        │ │            │ │
│            │  │   84 atributos      │ │   2 advertencias    │ │   3 users  │ │
│            │  │                     │ │                     │ │   asignados│ │
│            │  │ [Ir a Entidades]    │ │ [Ir a Políticas]    │ │ [Ir a Roles│ │
│            │  └─────────────────────┘ └─────────────────────┘ └────────────┘ │
│            │                                                                 │
│            │  ┌─────────────────────────────────────────────────────────────┐│
│            │  │ 🔔 ACTIVIDAD RECIENTE                                       ││
│            │  │                                                             ││
│            │  │ Hace 5 min  · admin creó la entidad "CAJA-02"              ││
│            │  │ Hace 23 min · arq compiló D1 · ACCESO LÓGICO (0 errores)    ││
│            │  │ Ayer 14:32  · jperez verificó CI en SEGIP ✅                ││
│            │  │ Ayer 09:15  · admin asignó rol "cajero_basico" a mgarcia    ││
│            │  └─────────────────────────────────────────────────────────────┘│
│            │                                                                 │
│            │  ⚡ Acciones rápidas:                                            │
│            │  [＋ Nueva entidad]  [＋ Nueva política]  [🔍 Buscar]            │
└────────────┴─────────────────────────────────────────────────────────────────┘
```

**De dónde salen los KPIs:** `bauth.identidad.stats()` y `bauth.rol.stats()` al montar el componente Home. La actividad reciente viene de `bauth.audit.recent(limit=10)`.

---

## §5 Editor de Identidad — árbol de entidades

### 5.1 Jerarquía

```
Componente base (NodoTemplate)
  │
  ├── Composite: Tenant           ── hijos: bDomain, Atributo
  ├──── Composite: bDomain        ── hijos: bSubDomain, Actor, Atributo
  ├────── Composite: bSubDomain   ── hijos: Pos, Actor, Atributo
  ├──────── Composite: Pos        ── hijos: Actor, Atributo
  ├────────── Leaf: Actor         ── hijos: Atributo
  └──────────────── Leaf: Atributo  ── sin hijos
```

### 5.2 Objetos de la paleta

| Objeto | Tipo GoF | Icono | Se suelta en | Significado |
|---|---|---|---|---|
| **Tenant** | Composite | 🏢 | Raíz | Organización raíz. Puede ser empresa, persona con múltiples roles, o entidad multi-propósito. |
| **bDomain** | Composite | 📁 | Tenant | Dominio de negocio: empresa, hogar, equipo, proyecto, familia. |
| **bSubDomain** | Composite | 📂 | bDomain | Subdivisión: sucursal, departamento, oficina, área. |
| **bSubDomain** | Composite | 📂 | bDomain | Subdivisión: sucursal, departamento, oficina, área. |
| **Pos** | Composite | 📍 | bSubDomain | Punto lógico: caja, puerta, escritorio, vehículo, servidor. |
| **Actor** | Leaf | 👤 | Pos, bSubDomain, bDomain | Entidad hoja: persona, bot, dispositivo, servicio. |
| **Atributo** | Leaf | 🏷️ | Cualquier entidad | Propiedad: nombre, email, CI, NIT, placa, serial. |

### 5.3 Contratos del Editor de Identidad

| Objeto | allowedChildren | requiredAttrs | minChildren | maxChildren |
|---|---|---|---|---|
| **Tenant** | bdomain, atributo | nombre, slug, is_internal | 1 (bdomain o atributo) | null |
| **bDomain** | bsubdomain, actor, atributo | nombre, tipo (D93) | 1 | null |
| **bSubDomain** | pos, actor, atributo | nombre, tipo (D93) | 1 | null |
| **Pos** | actor, atributo | nombre, tipo (D93) | 1 | null |
| **Actor** | atributo | nombre, tipo_entidad (PERSONA/ORGANIZACION/VEHICULO/...) | 0 | null |
| **Atributo** | — | category, attr_key | 0 | 1 (por entidad) |

**Regla de completitud:** `idn_identidad_requisito` define el grado mínimo de atributos por
tipo de entidad y nivel (IAL1/IAL2). El editor verifica estos requisitos ANTES de permitir
crear la entidad. Si faltan atributos obligatorios, el botón "Crear" permanece deshabilitado.

### 5.4 Mockup del Editor de Identidad

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  [☰] bAuth  [Tenant: SKULL ▾]                           🎨 Tema │ 🔌 │ 👤 a │
├────────────┬─────────────────────────────────────────────────────────────────┤
│ 🏠 Inicio  │ 🏠 Inicio > 👥 Entidades                     🔍 [Buscar entidad] │
│            ├─────────────────────────────────────────────────────────────────┤
│ IDENTIDAD  │                                                                 │
│ 👥 Entidad.│  🏢 SKULL (interno)                               [＋ bDomain]  │
│ 🏷️ Atribut.│    │  🏷️ slug: skull · is_internal: true                      │
│ 🔍 Buscador│    │                                                            │
│ 👥 USERSETs │    📁 SKULL-CORP (empresa) · tipo: sociedad_comercial          │
│ ─────────  │      │  🏷️ NIT: 12345678901234 · ✅ SIN                        │
│ ROLES      │      │  🏷️ Email: legal@skull.com                               │
│ 🟦 Polític.│      │                                                          │
│ 🔗 Asignac.│      📂 Norte (sucursal) · tipo: oficina_comercial              │
│ 📋 SETs    │        │  🏷️ Dirección: Calle Comercio #100                     │
│ ─────────  │        │                                                        │
│ 🛠️ atomc   │        📍 CAJA-01 (punto_de_venta)                [＋ Actor]     │
│ 📊 Reportes│          │  🏷️ tipo: caja · Serial: TERM-2024-001               │
│ ⚙ Admin    │          │                                                      │
│            │          👤 jperez (PERSONA) · IAL2 ✅                          │
│            │            │  🏷️ CI: 1234567 LP · ✅ SEGIP                      │
│            │            │  🏷️ Email: jperez@skull.com                        │
│            │            │  🏷️ Teléfono: +591-7-1234567                       │
│            │            │  🔗 Roles: vendedor_senior, cajero_basico          │
│            │                                                                 │
│            │  📁 Juan Pérez (persona_física) · expandir ▸                    │
│            │                                                                 │
│            └────────────────────────────────────────────────[＋] [🗑️] [🔍]──│
│  ✅ Conectado · interno.skull · 1 tenant · 2 bDomains · 12 atributos        │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 5.5 Panel de Propiedades — Tenant

```
┌─────────────────────────────────────────┐
│  🏢 TENANT                              │
│  ───────────────────────────────        │
│  Slug:      skull                       │
│  Nombre:    SKULL                       │
│  Tipo:      interno                     │
│  País:      BO                          │
│  Creado:    2024-01-10                  │
│                                         │
│  ┌─ ATRIBUTOS ──────────────────────┐   │
│  │ 🏷️ nombre · comercial             │   │
│  │    SKULL S.R.L.                   │   │
│  │ 🏷️ tributario · NIT               │   │
│  │    12345678901234                 │   │
│  │ [＋ Agregar atributo]              │   │
│  └───────────────────────────────────┘   │
│                                         │
│  ┌─ ESTADÍSTICAS ──────────────────┐    │
│  │ bDomains:     3                   │    │
│  │ bSubDomains:  5                   │    │
│  │ Pos:          12                  │    │
│  │ Actores:      47                  │    │
│  │ Atributos:    312                 │    │
│  └───────────────────────────────────┘   │
│                                         │
│  ┌─ USERSETs DEL TENANT ───────────┐    │
│  │ 👥 vendedores · 12 miembros      │    │
│  │ 👥 financieros · 5 miembros      │    │
│  │ 👥 admin_financiero · 2 miembros │    │
│  │ [＋ Crear USERSET]                │    │
│  └───────────────────────────────────┘   │
│                                         │
│  [Editar]  [Exportar]  [🔍 Auditoría]   │
└─────────────────────────────────────────┘
```

### 5.6 Panel de Propiedades — bDomain

```
┌─────────────────────────────────────────┐
│  📁 bDOMAIN                              │
│  ───────────────────────────────        │
│  Slug:      skull-corp                  │
│  Nombre:    SKULL-CORP                  │
│  Tipo:      sociedad_comercial          │
│  Tenant:    interno.skull               │
│  Creado:    2024-01-15                  │
│                                         │
│  ┌─ ATRIBUTOS ──────────────────────┐   │
│  │ 🏷️ NIT: 12345678901234 ✅ SIN     │   │
│  │ 🏷️ Email: legal@skull.com         │   │
│  │ [＋ Agregar atributo]              │   │
│  └───────────────────────────────────┘   │
│                                         │
│  ┌─ ENTIDADES HIJAS ───────────────┐    │
│  │ 📂 Norte · sucursal              │    │
│  │ 📂 Sur · sucursal                │    │
│  │ 👤 mgarcia · PERSONA              │    │
│  └───────────────────────────────────┘   │
│                                         │
│  [Editar]  [＋ bSubDomain]  [＋ Actor]   │
└─────────────────────────────────────────┘
```

### 5.7 Panel de Propiedades — bSubDomain

```
┌─────────────────────────────────────────┐
│  📂 bSUBDOMAIN                           │
│  ───────────────────────────────        │
│  Slug:      norte                       │
│  Nombre:    Norte                       │
│  Tipo:      oficina_comercial           │
│  Padre:     interno.skull.skull-corp    │
│  Creado:    2024-02-01                  │
│                                         │
│  ┌─ ATRIBUTOS ──────────────────────┐   │
│  │ 🏷️ Dirección: Calle Comercio #100 │   │
│  │ 🏷️ Teléfono: +591-2-1234567       │   │
│  │ [＋ Agregar atributo]              │   │
│  └───────────────────────────────────┘   │
│                                         │
│  ┌─ PUNTOS LÓGICOS ────────────────┐    │
│  │ 📍 CAJA-01 · punto_de_venta      │    │
│  │ 📍 CAJA-02 · punto_de_venta      │    │
│  │ 📍 Puerta-Principal · puerta     │    │
│  └───────────────────────────────────┘   │
│                                         │
│  [Editar]  [＋ Pos]  [＋ Actor]          │
└─────────────────────────────────────────┘
```

### 5.8 Panel de Propiedades — Pos

```
┌─────────────────────────────────────────┐
│  📍 POS                                  │
│  ───────────────────────────────        │
│  Slug:      caja-01                     │
│  Nombre:    CAJA-01                     │
│  Tipo:      punto_de_venta              │
│  Padre:     interno.skull.skull-corp.norte│
│  Creado:    2024-02-10                  │
│                                         │
│  ┌─ ATRIBUTOS ──────────────────────┐   │
│  │ 🏷️ Serial: TERM-2024-001          │   │
│  │ 🏷️ IP: 192.168.1.50               │   │
│  │ [＋ Agregar atributo]              │   │
│  └───────────────────────────────────┘   │
│                                         │
│  ┌─ ACTORES EN ESTE PUNTO ─────────┐    │
│  │ 👤 jperez · PERSONA · vendedor   │    │
│  │ 👤 mgarcia · PERSONA · cajera    │    │
│  └───────────────────────────────────┘   │
│                                         │
│  [Editar]  [＋ Actor]  [Vincular HW]    │
└─────────────────────────────────────────┘
```

### 5.9 Panel de Propiedades — Actor

```
┌─────────────────────────────────────────┐
│  👤 ACTOR                                │
│  ───────────────────────────────        │
│  Slug:      jperez                      │
│  Tipo:      PERSONA                     │
│  Nivel:     IAL2 ✅                     │
│  Tenant:    interno.skull               │
│  Creado:    2024-03-15                  │
│                                         │
│  ┌─ ATRIBUTOS ──────────────────────┐   │
│  │ 👤 nombre · given_name            │   │
│  │    Juan                           │   │
│  │ 👤 nombre · family_name           │   │
│  │    Pérez                          │   │
│  │ 📧 email · work                   │   │
│  │    jperez@skull.com ✅            │   │
│  │ 📋 id_nacional · CI               │   │
│  │    1234567 LP ✅ SEGIP            │   │
│  │ 📞 telefono · mobile              │   │
│  │    +591-7-1234567                 │   │
│  │ 💼 employee_code                  │   │
│  │    EMP-2024-0042                  │   │
│  │ [＋ Agregar atributo]              │   │
│  └───────────────────────────────────┘   │
│                                         │
│  ┌─ DOMINIOS DE IDENTIDAD ─────────┐    │
│  │ ✅ civil      · 4 atributos       │   │
│  │ ✅ laboral    · 3 atributos       │   │
│  │ ✅ autenticacion · 2 atributos    │   │
│  │ ⬜ cliente    · sin atributos     │   │
│  │ ⬜ financiero · sin atributos     │   │
│  └───────────────────────────────────┘   │
│                                         │
│  ┌─ ROLES ASIGNADOS ────────────────┐   │
│  │ 🔗 vendedor_senior · PERMANENTE   │   │
│  │    Desde: 2024-03-15              │   │
│  │ 🔗 cajero_basico · PERMANENTE     │   │
│  │    Desde: 2024-06-01              │   │
│  │ [＋ Asignar rol]                   │   │
│  └───────────────────────────────────┘   │
│                                         │
│  [Guardar]  [Cancelar]  [🔍 Auditoría]  │
└─────────────────────────────────────────┘
```

**Clic en `🔗 vendedor_senior`:** navega al Editor de Roles con esa política abierta.
**Clic en `[＋ Asignar rol]`:** abre el modal de asignación (ver §9).

### 5.10 Panel de Propiedades — Atributo

```
┌─────────────────────────────────────────┐
│  🏷️ ATRIBUTO                            │
│  ───────────────────────────────        │
│  Entidad:   jperez (PERSONA)            │
│  Categoría: documento                   │
│  Atributo:  id_nacional                 │
│  Tipo:      CI                          │
│  Valor:     1234567 LP                  │
│  Dominio:   civil                       │
│  Visibilidad: PRIVADA                   │
│  atom_code: 5826  🔗                    │
│                                         │
│  Verificación: ✅ Verificado             │
│    Fuente: SEGIP                        │
│    Fecha:  2024-03-15                   │
│    Expira: 2026-03-15                   │
│                                         │
│  ┌─ HISTORIAL ──────────────────────┐   │
│  │ 2024-03-15 · Creado · admin       │   │
│  │ 2024-03-15 · Verificado · SEGIP   │   │
│  │ [Ver historial completo]          │   │
│  └───────────────────────────────────┘   │
│                                         │
│  [Editar]  [Verificar]  [Eliminar]      │
└─────────────────────────────────────────┘
```

**Clic en `atom_code: 5826 🔗`:** navega al Editor de Roles mostrando el átomo 5826 y qué roles lo tienen asignado.

---

## §6 Editor de Roles — árbol de políticas

### 6.1 Jerarquía

```
Componente base (NodoTemplate)
  │
  ├── Composite: Dominio D1-D12   ── hijos: Bloque, PolicySet, Política, Guardrail
  ├──── Composite: Bloque B0-B19  ── hijos: PolicySet, Política
  ├────── Composite: PolicySet    ── hijos: PolicySet, Política, Guardrail
  ├──────── Composite: Política   ── hijos: Regla
  ├────────── Leaf: Regla         ── hijos: target, condition, effect (incluidos en la regla)
  └────────── Leaf: Guardrail     ── hijos: target, effect (sin condition, application_id=null)
```

### 6.2 Objetos de la paleta

| Objeto | Tipo GoF | Icono | Se suelta en | Significado |
|---|---|---|---|---|
| **Dominio** | Composite | 🟦 | Raíz | Los 12 dominios de autorización (D1 ACCESO, D3 FINANCIERO, D6 PRIVACIDAD...). |
| **Bloque** | Composite | 🟩 | Dominio | Agrupación funcional (B4 Autenticación, B6 Zonas, B7 PrivilegeEngine...). |
| **PolicySet** | Composite | 🟨 | Dominio, Bloque, PolicySet | Contenedor de políticas y sub-PolicySets. Aplica combining_algorithm. |
| **Política** | Composite | 🟧 | Dominio, Bloque, PolicySet | Política concreta con combining_algorithm y application_id. Contiene Reglas. |
| **Regla** | Leaf | 🟥 | Política, PolicySet (solo con contrato) | Regla XACML: target + condition + effect. Unidad mínima de decisión. |
| **Guardrail** | Leaf | 🟪 | PolicySet, Dominio | Regla global sin application_id. Aplica a todo el dominio o PolicySet. |

### 6.3 Contratos del Editor de Roles

| Objeto | allowedChildren | requiredAttrs | minChildren | maxChildren |
|---|---|---|---|---|
| **Dominio D1-D12** | bloque, policyset, politica, guardrail | combining_algorithm, domain_name | 1 | null |
| **Bloque B0-B19** | policyset, politica | nombre | 1 | null |
| **PolicySet** | policyset, politica, guardrail | combining_algorithm | 1 | null |
| **Política** | regla | combining_algorithm, application_id | 1 | null |
| **Regla** | — (target+condition+effect son PARTE de la regla) | verb_id, target, effect | — | — |
| **Guardrail** | — | verb_id, effect | — | — |

### 6.4 Mockup del Editor de Roles

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  [☰] bAuth  [Tenant: SKULL ▾]                           🎨 Tema │ 🔌 │ 👤 arq│
├────────────┬─────────────────────────────────────────────────────────────────┤
│ 🏠 Inicio  │ 🏠 Inicio > 🟦 Políticas                    🔍 [Buscar política] │
│            ├─────────────────────────────────────────────────────────────────┤
│ IDENTIDAD  │                                                                 │
│ 👥 Entidad.│  🟦 D1 · ACCESO LÓGICO                     [＋ Bloque/PolicySet] │
│ 🏷️ Atribut.│    ⚙ combining_algorithm: deny-overrides                         │
│ 🔍 Buscador│    │                                               ──────────────│
│ 👥 USERSETs │    🟩 B4 · Autenticación                                     │
│ ─────────  │      ⚙ combining_algorithm: deny-overrides (hereda de D1)       │
│ ROLES      │      │                                               ────────────│
│ 🟦 Polític.│      🟧 password_policy                         [＋ Regla]       │
│ 🔗 Asignac.│        ⚙ combining_algorithm: deny-overrides                     │
│ 📋 SETs    │        ⚙ application_id: bauth.password_policy                  │
│ ─────────  │        │                                               ──────────│
│ 🛠️ atomc   │        🟥 longitud_mínima                ✅ COMPLETA            │
│ 📊 Reportes│        🟥 historial_contraseñas          ✅ COMPLETA            │
│ ⚙ Admin    │        🟥 complejidad_caracteres         ⚠ FALTA EFFECT         │
│            │                                                                │
│            │    🟩 B7 · PrivilegeEngine                                     │
│            │      │                                               ────────────│
│            │      🟧 field_restrictions                    [＋ Regla]         │
│            │        ⚙ combining_algorithm: deny-overrides                     │
│            │        ⚙ application_id: bauth.field_visibility                 │
│            │        │                                               ──────────│
│            │        🟥 campo_margin_oculto               ✅ COMPLETA         │
│            │        🟥 campo_cost_price_oculto           ✅ COMPLETA         │
│            │        🟥 campo_credit_limit_readonly       ⚠ SIN EFFECT        │
│            │                                                                │
│            │    🟪 D1-GLOBAL-GUARDRAIL                                     │
│            │      ⚙ sin application_id (aplica a todo D1)                    │
│            └──────────────────────────────────────────────────────────────────│
│  ✅ Conectado · interno.skull · 12 dominios · 41 políticas · 2 advertencias  │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 6.5 Panel de Propiedades — Dominio

```
┌─────────────────────────────────────────┐
│  🟦 DOMINIO                              │
│  ───────────────────────────────        │
│  Código:    D1                          │
│  Nombre:    ACCESO LÓGICO               │
│  combining_algorithm: deny-overrides    │
│                                         │
│  ┌─ CONTENIDO ──────────────────────┐   │
│  │ Bloques:    4 (B4, B6, B7, B8)   │   │
│  │ PolicySets: 2                     │   │
│  │ Políticas:  12                    │   │
│  │ Reglas:     47 activas            │   │
│  │ Guardrails: 1                     │   │
│  └───────────────────────────────────┘   │
│                                         │
│  ┌─ ESTADÍSTICAS ──────────────────┐    │
│  │ ✅ Completas:     42 reglas       │    │
│  │ ⚠ Advertencias:    3 reglas       │    │
│  │ ❌ Errores:         2 reglas       │    │
│  │ Última compilación: 2026-07-15    │    │
│  └───────────────────────────────────┘   │
│                                         │
│  [Editar]  [Compilar dominio]  [Auditar]│
└─────────────────────────────────────────┘
```

### 6.6 Panel de Propiedades — Bloque

```
┌─────────────────────────────────────────┐
│  🟩 BLOQUE                               │
│  ───────────────────────────────        │
│  Código:    B4                          │
│  Nombre:    Autenticación               │
│  Dominio:   D1 · ACCESO LÓGICO          │
│  combining_algorithm: deny-overrides     │
│           (hereda de D1)                │
│                                         │
│  ┌─ CONTENIDO ──────────────────────┐   │
│  │ PolicySets: 1                     │   │
│  │ Políticas:  3                     │   │
│  │ Reglas:     12 activas            │   │
│  └───────────────────────────────────┘   │
│                                         │
│  ┌─ POLÍTICAS DEL BLOQUE ──────────┐    │
│  │ 🟧 password_policy                │    │
│  │ 🟧 mfa_policy                     │    │
│  │ 🟧 session_policy                 │    │
│  └───────────────────────────────────┘   │
│                                         │
│  [Editar]  [＋ PolicySet]  [＋ Política] │
└─────────────────────────────────────────┘
```

### 6.7 Panel de Propiedades — PolicySet

```
┌─────────────────────────────────────────┐
│  🟨 POLICYSET                            │
│  ───────────────────────────────        │
│  Nombre:    Zona Financiera             │
│  Dominio:   D3 · FINANCIERO             │
│  combining_algorithm: first-applicable  │
│                                         │
│  ┌─ CONTENIDO ──────────────────────┐   │
│  │ Sub-PolicySets: 1                 │   │
│  │ Políticas:  4                     │   │
│  │ Guardrails: 1                     │   │
│  └───────────────────────────────────┘   │
│                                         │
│  ┌─ POLÍTICAS ──────────────────────┐   │
│  │ 🟧 payment_approvals              │   │
│  │ 🟧 refund_authorization           │   │
│  │ 🟧 discount_overrides             │   │
│  │ 🟧 invoice_modification           │   │
│  └───────────────────────────────────┘   │
│                                         │
│  [Editar]  [＋ Sub-PolicySet]  [＋ Política] [＋ Guardrail]│
└─────────────────────────────────────────┘
```

### 6.8 Panel de Propiedades — Política

```
┌─────────────────────────────────────────┐
│  🟧 POLÍTICA                             │
│  ───────────────────────────────        │
│  Nombre:    field_restrictions          │
│  Dominio:   D7 · PrivilegeEngine        │
│  Bloque:    B7 · PrivilegeEngine        │
│  combining_algorithm: deny-overrides    │
│  application_id: bauth.field_visibility │
│                                         │
│  ┌─ REGLAS ─────────────────────────┐   │
│  │ 🟥 campo_margin_oculto ✅         │   │
│  │ 🟥 campo_cost_price_oculto ✅     │   │
│  │ 🟥 campo_credit_limit_readonly ⚠  │   │
│  └───────────────────────────────────┘   │
│                                         │
│  ┌─ ESTADÍSTICAS ──────────────────┐    │
│  │ Reglas:      3                    │    │
│  │ Completas:   2                    │    │
│  │ Incompletas: 1                    │    │
│  └───────────────────────────────────┘   │
│                                         │
│  [Editar]  [＋ Regla]  [Validar]  [Compilar política]│
└─────────────────────────────────────────┘
```

### 6.9 Panel de Propiedades — Regla

```
┌─────────────────────────────────────────┐
│  🟥 REGLA                                │
│  ───────────────────────────────        │
│  Nombre:    campo_credit_limit_readonly  │
│  Dominio:   D7 · PrivilegeEngine        │
│  Política:  field_restrictions           │
│  Estado:    ⚠ INCOMPLETA                 │
│                                         │
│  ┌─ TARGET ────────────────────────┐    │
│  │ Subject:   [SET(financieros) ▾]  │    │
│  │             🔗 Ver SET            │    │
│  │ Resource:  [credit_limit ▾]      │    │
│  │ Verbo:     [read ▾]              │    │
│  │ Env:       [any ▾]               │    │
│  └──────────────────────────────────┘    │
│                                         │
│  ┌─ CONDITION ──────────────────────┐   │
│  │ Property:  [user.role ▾]          │   │
│  │ Operator:  [not_in ▾]             │   │
│  │ Value:     [SET(admin_financiero)▾│   │
│  │             🔗 Ver SET            │   │
│  └──────────────────────────────────┘    │
│                                         │
│  ┌─ EFFECT ⚠ REQUERIDO ────────────┐   │
│  │ Decision:  [Seleccionar... ▾]     │   │
│  │ Obligation: [opcional]            │   │
│  │ Advice:    [opcional]             │   │
│  │ ❌ Falta effect. La regla no      │   │
│  │    puede compilarse sin él.       │   │
│  └──────────────────────────────────┘    │
│                                         │
│  ┌─ VALIDACIÓN ────────────────────┐    │
│  │ atomc:   1 error, 0 avisos       │    │
│  │ Contrato: target ✅ · condition ✅ │    │
│  │           effect ❌               │    │
│  └──────────────────────────────────┘    │
│                                         │
│  [Guardar]  [Validar]  [Compilar regla] │
└─────────────────────────────────────────┘
```

**Clic en `🔗 Ver SET` junto a `SET(financieros)`:** navega a la vista de SETs (§10) con ese SET abierto.

### 6.10 Panel de Propiedades — Guardrail

```
┌─────────────────────────────────────────┐
│  🟪 GUARDRAIL                            │
│  ───────────────────────────────        │
│  Nombre:    D1-GLOBAL-GUARDRAIL         │
│  Dominio:   D1 · ACCESO LÓGICO          │
│  application_id: null (global)          │
│                                         │
│  ┌─ TARGET ────────────────────────┐    │
│  │ Verbo:     [approve ▾]            │    │
│  │ Resource:  [payment.transaction ▾]│    │
│  └──────────────────────────────────┘    │
│                                         │
│  ┌─ EFFECT ────────────────────────┐    │
│  │ Decision:  [Deny ▾]               │    │
│  │ Obligation: { audit: on }         │    │
│  │ Advice:    Requiere aprobación    │    │
│  │            de tier 2              │    │
│  └──────────────────────────────────┘    │
│                                         │
│  ⚠ Un Guardrail no tiene condition     │
│    ni application_id. Aplica a TODAS    │
│    las políticas del dominio.           │
│                                         │
│  [Guardar]  [Validar]                   │
└─────────────────────────────────────────┘
```

---

## §7 Flujo de compilación — atomc integrado

### 7.1 Cuándo se compila

| Gatillo | Alcance | Quién ejecuta |
|---|---|---|
| Botón `[Compilar regla]` en panel de Regla | Una regla | atomc en servidor (JSON-RPC `atomc.compile_rule`) |
| Botón `[Compilar política]` en panel de Política | Una política y todas sus reglas | atomc en servidor |
| Botón `[Compilar dominio]` en panel de Dominio | Un dominio completo (bloques, políticas, reglas) | atomc en servidor |
| Menú `atomc > Compilar todo` | Todos los dominios del tenant | atomc en servidor |
| `Ctrl+Shift+C` (atajo global) | El dominio o política seleccionada | atomc en servidor |

### 7.2 Qué hace el compilador

```
1. LEXER: Tokeniza el árbol fuente (donde el "código fuente" ES el árbol)
2. PARSER: Valida la estructura contra la gramática AtomLang
3. SEMANTIC: Verifica reglas de negocio (SoD, conflictos, herencia)
4. CODEGEN: Genera el IR (privilege_atom_compiled) + recalcula RolBitMask
```

### 7.3 Qué ve el usuario durante la compilación

```
┌──────────────────────────────────────────────────────────────┐
│  🔨 COMPILANDO D1 · ACCESO LÓGICO                            │
│                                                              │
│  ⬛ Lexer      ··············· ✅ 178 tokens (12ms)          │
│  ⬛ Parser     ··············· ✅ Árbol válido (8ms)         │
│  ⬛ Semantic   ··············· ⚠ 2 advertencias (45ms)       │
│  ⬛ Codegen    ··············· ⏳ Generando IR...             │
│                                                              │
│  ┌─ ADVERTENCIAS ───────────────────────────────────────┐   │
│  │ ⚠ campo_credit_limit_readonly: falta effect            │   │
│  │    La regla no se incluirá en el IR compilado.         │   │
│  │ ⚠ password_policy: combining_algorithm heredado        │   │
│  │    de D1. ¿Es correcto?                                │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  [Cancelar]  [Ver IR generado]                              │
└──────────────────────────────────────────────────────────────┘
```

### 7.4 Resultado de la compilación

```
┌──────────────────────────────────────────────────────────────┐
│  ✅ COMPILACIÓN EXITOSA — D1 · ACCESO LÓGICO                 │
│                                                              │
│  ⬛ Lexer      ··············· ✅ 178 tokens                 │
│  ⬛ Parser     ··············· ✅ Árbol válido                │
│  ⬛ Semantic   ··············· ✅ 0 errores, 2 avisos         │
│  ⬛ Codegen    ··············· ✅ IR generado (47 átomos)     │
│                                                              │
│  📊 BitMask actualizado: 47 bits en D1                       │
│  📋 privilege_atom_compiled: 47 filas insertadas             │
│  ⏱ Tiempo total: 89ms                                       │
│                                                              │
│  [Cerrar]  [Ver IR]  [Ver diff con compilación anterior]    │
└──────────────────────────────────────────────────────────────┘
```

### 7.5 Errores de compilación — inline en el árbol

Los errores se marcan directamente en el árbol, no solo en un panel aparte:

```
🟧 password_policy                          ⚠ 2 ERRORES
  │
  🟥 longitud_mínima                ✅ COMPLETA
  🟥 historial_contraseñas          🔴 CONDITION INVÁLIDA
  │   ┌─────────────────────────────────────────────┐
  │   │ atomc: operator '<<' no existe en AtomLang  │
  │   │ Sugerencia: usar '<=' o '<'                  │
  │   │ [Corregir]  [Ignorar]                        │
  │   └─────────────────────────────────────────────┘
  🟥 complejidad_caracteres         🔴 VERBO NO RECONOCIDO
      ┌─────────────────────────────────────────────┐
      │ atomc: verb_id 'enforce' no está en el      │
      │ vocabulario G-03 (password)                  │
      │ Verbos válidos: configure, validate, reset   │
      │ [Corregir]  [Ignorar]                        │
      └─────────────────────────────────────────────┘
```

### 7.6 Integración desktop ↔ atomc

```
Desktop (Flutter)                      BauthAgent (Rust)
─────────────────                      ──────────────────

1. Usuario presiona [Compilar]
   → Envía dominio_id o politica_id
                                       2. Handler `atomc.compile`
                                          → Resuelve el subárbol desde BD
                                          → Ejecuta atomc (lexer, parser, semantic, codegen)
                                          → Persiste IR en privilege_atom_compiled
                                          → Recalcula RolBitMask
3. Recibe resultado:
   {                                  4. Retorna:
     "status": "success",                {
     "errors": [],                         "compiled_id": "abc123",
     "warnings": [...],                    "atoms_generated": 47,
     "atoms_generated": 47,                "elapsed_ms": 89
     "elapsed_ms": 89                    }
   }
5. Actualiza el árbol:
   → Marca nodos con errores inline
   → Actualiza badge de advertencias
   → Refresca KPIs en barra de estado
```

**JSON-RPC:** `bauth.atomc.compile(domain_id, options?)` → `CompileResult`
**CLI equivalente:** `bauthctl atomc compile --domain D1`

---

## §8 Interfaz de asignación Usuario↔Rol

### 8.1 Dos puntos de entrada

| Desde | Flujo |
|---|---|
| **Panel de Actor** (§5.9) → `[＋ Asignar rol]` | Modal: "Asignar rol a jperez" |
| **Sidebar > ROLES > 🔗 Asignaciones** | Vista completa: grilla de usuarios × roles |

### 8.2 Modal de asignación rápida (desde Actor)

```
┌──────────────────────────────────────────────────────────────┐
│  ＋ ASIGNAR ROL A jperez                                     │
│                                                              │
│  Buscar rol: [vendedor___________________________] 🔍        │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ ☐ vendedor_junior · BIZ_N2 · 45 átomos               │   │
│  │ ☑ vendedor_senior  · BIZ_N1 · 67 átomos              │   │
│  │ ☐ supervisor_zona  · BIZ_N1 · 89 átomos              │   │
│  │   ⚠ Conflicto SoD con cajero_basico                  │   │
│  │ ☐ administrador     · SYS    · 312 átomos             │   │
│  │   🔒 Requiere autorización tier SU                   │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  Modo:     [PERMANENTE ▾]                                    │
│  Válido hasta: [Sin expiración]  📅                          │
│                                                              │
│  ┌─ CONFLICTOS SoD ────────────────────────────────────┐    │
│  │ ⚠ supervisor_zona + cajero_basico = CONFLICTO        │    │
│  │   Matriz SoD: zona.supervisar XOR caja.operar        │    │
│  │   [Forzar asignación (requiere autorización)]         │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  [Cancelar]  [Asignar]                                      │
└──────────────────────────────────────────────────────────────┘
```

**Validación SoD en tiempo real:** cada checkbox se evalúa contra los roles actuales del usuario. Si hay conflicto, se marca ⚠ y requiere confirmación adicional.

### 8.3 Vista completa de Asignaciones (sidebar)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🏠 Inicio > 🔗 Asignaciones                                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│  🔍 [Buscar usuario o rol...]  [Filtro: Todos ▾]  [＋ Nueva asignación]      │
├──────────────────────────────────────────────────────────────────────────────┤
│  Usuario          │ Rol                │ Modo       │ Desde      │ Hasta     │
├────────────────────┼───────────────────┼────────────┼────────────┼───────────│
│  👤 jperez         │ vendedor_senior   │ PERMANENTE │ 2024-03-15 │ —         │
│  👤 jperez         │ cajero_basico     │ PERMANENTE │ 2024-06-01 │ —         │
│  👤 mgarcia        │ cajero_basico     │ PERMANENTE │ 2024-02-10 │ —         │
│  👤 mgarcia        │ analista_pagos    │ TEMPORAL   │ 2026-07-01 │ 2026-08-01│
│  👤 aruiz           │ supervisor_zona   │ PERMANENTE │ 2024-01-20 │ —         │
│  🤖 bot-factura     │ m2m_facturacion   │ PERMANENTE │ 2024-05-01 │ —         │
│                                                                              │
│  📊 3 usuarios · 6 asignaciones · 4 roles distintos                         │
│  [Exportar CSV]  [🔍 Auditoría de asignaciones]                             │
└──────────────────────────────────────────────────────────────────────────────┘
```

Cada fila es cliqueable. Abre el panel de detalle con historial de la asignación, cambios de modo, y botón `[Revocar]`.

---

## §9 Gestión de SETs — D94 USERSETs y D98 SETs

### 9.1 Dónde se gestionan

| Tipo | Dominio | Sidebar | Qué agrupa | Ejemplo |
|---|---|---|---|---|
| **USERSET (D94)** | Identidad | `👥 USERSETs` | Entidades (actores) por contexto operativo | `vendedores`, `financieros`, `admin_financiero` |
| **SET (D98)** | Roles | `📋 SETs` | Roles por conjunto funcional | `roles_financieros`, `politicas_pci` |

### 9.2 Vista USERSETs (D94)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🏠 Inicio > 👥 USERSETs (D94)                                               │
├──────────────────────────────────────────────────────────────────────────────┤
│  🔍 [Buscar USERSET...]  [＋ Nuevo USERSET]                                  │
├──────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ 👥 vendedores                                                         │    │
│  │    Tenant: SKULL · 12 miembros                                        │    │
│  │    Usado en: 5 reglas (D1, D3, D7)                                   │    │
│  │    Miembros: jperez, mgarcia, aruiz, lflores, ...                    │    │
│  │    [Editar miembros]  [Ver reglas que lo usan]                        │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ 👥 financieros                                                        │    │
│  │    Tenant: SKULL · 5 miembros                                         │    │
│  │    Usado en: 12 reglas (D3, D7)                                      │    │
│  │    Miembros: aruiz, cgomez, ...                                      │    │
│  │    [Editar miembros]  [Ver reglas que lo usan]                        │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ 👥 admin_financiero                                                   │    │
│  │    Tenant: SKULL · 2 miembros                                         │    │
│  │    Usado en: 3 reglas (D3)                                           │    │
│  │    Miembros: aruiz, cgomez                                           │    │
│  │    [Editar miembros]  [Ver reglas que lo usan]                        │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 9.3 Vista SETs (D98)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🏠 Inicio > 📋 SETs (D98)                                                   │
├──────────────────────────────────────────────────────────────────────────────┤
│  🔍 [Buscar SET...]  [＋ Nuevo SET]                                          │
├──────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ 📋 roles_financieros                                                   │    │
│  │    Tenant: SKULL · 3 roles miembros                                   │    │
│  │    Usado en: 8 reglas (D3)                                            │    │
│  │    Roles: analista_pagos, contador_junior, auditor_interno            │    │
│  │    [Editar roles]  [Ver reglas que lo usan]                           │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ 📋 politicas_pci                                                       │    │
│  │    Tenant: SKULL · 5 roles miembros                                   │    │
│  │    Usado en: 15 reglas (D6)                                           │    │
│  │    Roles: cajero_basico, vendedor_senior, supervisor_zona, ...        │    │
│  │    [Editar roles]  [Ver reglas que lo usan]                           │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 9.4 Editor de miembros de un USERSET

```
┌──────────────────────────────────────────────────────────────────────┐
│  ✏ EDITAR MIEMBROS — 👥 vendedores                                  │
│                                                                      │
│  🔍 [Buscar entidad...]                                              │
│                                                                      │
│  Disponibles:                          Miembros (12):                │
│  ┌────────────────────────┐            ┌────────────────────────┐   │
│  │ ☐ 👤 dtorres           │   [＋]     │ 👤 jperez      [✕]     │   │
│  │ ☐ 👤 lflores           │   ───▶    │ 👤 mgarcia     [✕]     │   │
│  │ ☑ 👤 aruiz             │            │ 👤 aruiz       [✕]     │   │
│  │ ☐ 👤 cgomez            │            │ 👤 lflores     [✕]     │   │
│  │ ☐ 🤖 bot-inventario    │   [✕]     │                        │   │
│  └────────────────────────┘   ◀───    └────────────────────────┘   │
│                                                                      │
│  [Cancelar]  [Guardar cambios]                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## §10 NodeContract — definición canónica explícita

### 10.1 Estructura del contrato

```
NodeContract {
  nodeType:       string,        // "dominio" | "politica" | "regla" | "guardrail"
                                 //   | "bloque" | "policyset"
                                 //   | "tenant" | "bdomain" | "bsubdomain"
                                 //   | "pos" | "actor" | "atributo"

  editor:         "identidad" | "roles",
                                 // A qué editor pertenece este nodo.
                                 // Determina en qué paleta aparece.

  allowedChildren: string[],     // Tipos de nodo que pueden soltarse como hijos.
                                 // Vacío = Leaf (no acepta hijos).

  requiredAttrs:  string[],      // Atributos OBLIGATORIOS para que el nodo sea válido.
                                 // Identidad: category, attr_key, nombre, tipo, slug.
                                 // Roles: combining_algorithm, verb_id, effect, application_id.

  optionalAttrs:  string[],      // Atributos opcionales que enriquecen el nodo.

  minChildren:    int,           // Mínimo de hijos requeridos. 0 = sin requisito.
  maxChildren:    int | null,    // Máximo de hijos permitidos. null = sin límite.

  icon:           string,        // Emoji o ícono Flutter (Icon.xxx).
  color:          string,        // Color en la paleta y el árbol.

  description:    string,        // Tooltip: qué es este nodo y para qué sirve.

  crossEditorLinks: {            // Deep links a otros editores.
    attr: string,                // Nombre del atributo que contiene el link.
    targetEditor: "identidad" | "roles" | "sets",
    targetRoute: string          // Ruta interna: "/roles/rol/{slug}"
  }[]
}
```

### 10.2 Contratos completos — Editor de Identidad

```
// ─── TENANT ───
{
  nodeType: "tenant",
  editor: "identidad",
  allowedChildren: ["bdomain", "atributo"],
  requiredAttrs: ["nombre", "slug", "is_internal"],
  optionalAttrs: ["pais", "logo_url", "plan_tier"],
  minChildren: 1,
  maxChildren: null,
  icon: "🏢",
  color: "blue",
  description: "Organización raíz del árbol de identidad. Puede ser empresa, persona multi-rol, o entidad multi-propósito.",
  crossEditorLinks: []
}

// ─── BDOMAIN ───
{
  nodeType: "bdomain",
  editor: "identidad",
  allowedChildren: ["bsubdomain", "actor", "atributo"],
  requiredAttrs: ["nombre", "tipo"],
  optionalAttrs: ["descripcion"],
  minChildren: 1,
  maxChildren: null,
  icon: "📁",
  color: "teal",
  description: "Dominio de negocio: empresa, hogar, equipo, proyecto.",
  crossEditorLinks: []
}

// ─── BSUBDOMAIN ───
{
  nodeType: "bsubdomain",
  editor: "identidad",
  allowedChildren: ["pos", "actor", "atributo"],
  requiredAttrs: ["nombre", "tipo"],
  optionalAttrs: ["descripcion", "direccion"],
  minChildren: 1,
  maxChildren: null,
  icon: "📂",
  color: "green",
  description: "Subdivisión de bDomain: sucursal, departamento, área.",
  crossEditorLinks: []
}

// ─── POS ───
{
  nodeType: "pos",
  editor: "identidad",
  allowedChildren: ["actor", "atributo"],
  requiredAttrs: ["nombre", "tipo"],
  optionalAttrs: ["serial", "ip", "coordenadas", "device_id"],
  minChildren: 1,
  maxChildren: null,
  icon: "📍",
  color: "amber",
  description: "Punto lógico: caja, puerta OSDP, escritorio, vehículo, servidor.",
  crossEditorLinks: []
}

// ─── ACTOR ───
{
  nodeType: "actor",
  editor: "identidad",
  allowedChildren: ["atributo"],
  requiredAttrs: ["nombre", "tipo_entidad"],
  optionalAttrs: [],
  minChildren: 0,
  maxChildren: null,
  icon: "👤",
  color: "indigo",
  description: "Entidad hoja del árbol: persona, bot, dispositivo, servicio.",
  crossEditorLinks: [
    { attr: "roles_asignados", targetEditor: "roles", targetRoute: "/roles/rol/{role_slug}" },
    { attr: "userset_pertenece", targetEditor: "sets", targetRoute: "/sets/usersets/{set_slug}" }
  ]
}

// ─── ATRIBUTO ───
{
  nodeType: "atributo",
  editor: "identidad",
  allowedChildren: [],
  requiredAttrs: ["category", "attr_key"],
  optionalAttrs: ["type", "value_text", "value_data", "dominio_origen",
                  "visibilidad", "is_verified", "verified_by", "atom_code"],
  minChildren: 0,
  maxChildren: 0,
  icon: "🏷️",
  color: "gray",
  description: "Propiedad de una entidad: nombre, email, CI, NIT, placa, serial. Sin hijos.",
  crossEditorLinks: [
    { attr: "atom_code", targetEditor: "roles", targetRoute: "/roles/atomo/{atom_code}" }
  ]
}
```

### 10.3 Contratos completos — Editor de Roles

```
// ─── DOMINIO ───
{
  nodeType: "dominio",
  editor: "roles",
  allowedChildren: ["bloque", "policyset", "politica", "guardrail"],
  requiredAttrs: ["combining_algorithm", "domain_name"],
  optionalAttrs: ["descripcion", "domain_code"],
  minChildren: 1,
  maxChildren: null,
  icon: "🟦",
  color: "blue",
  description: "Los 12 dominios de autorización XACML. Raíz del árbol de políticas.",
  crossEditorLinks: []
}

// ─── BLOQUE ───
{
  nodeType: "bloque",
  editor: "roles",
  allowedChildren: ["policyset", "politica"],
  requiredAttrs: ["nombre"],
  optionalAttrs: ["descripcion", "hereda_combining_algorithm"],
  minChildren: 1,
  maxChildren: null,
  icon: "🟩",
  color: "green",
  description: "Agrupación funcional dentro de un dominio. Hereda combining_algorithm del padre.",
  crossEditorLinks: []
}

// ─── POLICYSET ───
{
  nodeType: "policyset",
  editor: "roles",
  allowedChildren: ["policyset", "politica", "guardrail"],
  requiredAttrs: ["combining_algorithm"],
  optionalAttrs: ["nombre", "descripcion"],
  minChildren: 1,
  maxChildren: null,
  icon: "🟨",
  color: "yellow",
  description: "Contenedor de políticas y sub-PolicySets. Aplica combining_algorithm a sus hijos.",
  crossEditorLinks: []
}

// ─── POLÍTICA ───
{
  nodeType: "politica",
  editor: "roles",
  allowedChildren: ["regla"],
  requiredAttrs: ["combining_algorithm", "application_id"],
  optionalAttrs: ["nombre", "descripcion", "target"],
  minChildren: 1,
  maxChildren: null,
  icon: "🟧",
  color: "orange",
  description: "Política concreta ligada a un application_id. Contiene reglas de decisión.",
  crossEditorLinks: []
}

// ─── REGLA ───
{
  nodeType: "regla",
  editor: "roles",
  allowedChildren: [],
  requiredAttrs: ["verb_id", "target", "effect"],
  optionalAttrs: ["condition", "obligation", "advice", "nombre"],
  minChildren: 0,
  maxChildren: 0,
  icon: "🟥",
  color: "red",
  description: "Regla XACML atómica: target + condition + effect. El target/condition/effect son parte de la regla, no hijos en el árbol.",
  crossEditorLinks: [
    { attr: "target.subject_set", targetEditor: "sets", targetRoute: "/sets/usersets/{set_slug}" },
    { attr: "condition.value_set", targetEditor: "sets", targetRoute: "/sets/sets/{set_slug}" }
  ]
}

// ─── GUARDRAIL ───
{
  nodeType: "guardrail",
  editor: "roles",
  allowedChildren: [],
  requiredAttrs: ["verb_id", "effect"],
  optionalAttrs: ["target", "nombre"],
  minChildren: 0,
  maxChildren: 0,
  icon: "🟪",
  color: "purple",
  description: "Regla global sin application_id ni condition. Aplica a todo el dominio o PolicySet que lo contiene.",
  crossEditorLinks: []
}
```

---

## §11 Cómo el constructor visual usa el contrato

### 11.1 Algoritmo de validación en drag & drop

```
función puedeSoltar(hijo: NodoTemplate, padre: NodoTemplate): boolean {
  1. Verificar editor:
     si hijo.contract.editor ≠ padre.contract.editor → false
     (no se puede arrastrar un objeto de Identidad sobre el árbol de Roles, ni viceversa)

  2. Verificar allowedChildren:
     si padre.contract.allowedChildren NO contiene hijo.contract.nodeType → false
     → zona de drop gris, cursor prohibido

  3. Verificar maxChildren:
     si padre.hijos.count(hijo.contract.nodeType) >= padre.contract.maxChildren → false
     → zona de drop gris + tooltip: "Máximo N hijos de tipo X alcanzado"

  4. Verificar cross-tenant (solo Identidad):
     si padre.tenant_id ≠ hijo.tenant_id → false
     → tooltip: "No se puede mover una entidad a otro tenant"

  5. Si todo OK:
     → zona de drop se ilumina en verde
     → cursor cambia a permitido
     → tooltip: "Soltar aquí para agregar {hijo.contract.nodeType}"
}
```

### 11.2 Diferencias de validación entre editores

| | Editor de Identidad | Editor de Roles |
|---|---|---|
| **Qué valida** | Completitud mínima de entidad (IAL1/IAL2) | Estructura XACML (combining_algorithm, verb_id, effect) |
| **Fuente del contrato** | NodeContract + `idn_identidad_requisito` (tabla SQL) | NodeContract |
| **Atributos obligatorios** | `nombre`, `email`, `CI` según tipo de entidad y nivel | `combining_algorithm`, `verb_id`, `effect` según tipo de nodo |
| **Validación post-construcción** | Motor de Identidad (`validate` + `verify`) | atomc (`atomc check`) |
| **Error visible** | "PERSONA nivel 1 requiere: nombre, email. Falta: email." | "Regla campo_credit_limit_readonly: falta effect." |
| **Restricción cross-tenant** | ✅ No se permite mover entidades entre tenants | ❌ No aplica (los dominios son por tenant) |

---

## §12 El Buscador — vista de consulta

El Buscador **no es un editor de árbol.** Es una vista de consulta del Motor de Identidad.

### 12.1 Mockup del Buscador

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🏠 Inicio > 🔍 Buscador                                                     │
├──────────────────────────────────────────────────────────────────────────────┤
│  🔍 foco del izq tyt carina 92                           [Buscar] [Filtros ▾] │
├──────────────────────────────────────────────────────────────────────────────┤
│  Filtros activos: Tipo=FAROL · Tenant=Toyota · Compatible=Carina 92          │
├──────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ 🔩 Farol Delantero Izquierdo · TOYOTA · 212-1112-L          ★★★★★   │    │
│  │    Compatible: Carina 92-97 · Corona 92-97 · Corolla 93-97           │    │
│  │    Fabricante: DEPO (Taiwán) · Código: 212-1112-L                    │    │
│  │    Posición: Delantero Izquierdo · Sistema: Iluminación              │    │
│  │    ▸ 3 proveedores · Stock total: 85u · Desde $42                    │    │
│  │    🔗 [Ver en árbol de identidad]                                     │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ 🔩 Farol Delantero Izquierdo · BOSCH · B-9876-L              ★★★★☆  │    │
│  │    Compatible: Carina 92-97 · Corona 92-97                           │    │
│  │    Fabricante: BOSCH (Alemania) · Código: B-9876-L                   │    │
│  │    ▸ 1 proveedor · Stock total: 10u · Desde $65                      │    │
│  │    🔗 [Ver en árbol de identidad]                                     │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│  📊 3 resultados · <50ms · Buscado en 165M atributos                        │
│  [Exportar CSV]  [Compartir resultados]                                     │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Clic en `[Ver en árbol de identidad]`:** navega al Editor de Identidad con la entidad seleccionada y el árbol expandido hasta ella.

---

## §13 Estados de la UI — vacío, carga, error

### 13.1 Estados de cada vista

#### Inicio (landing page)

| Estado | Mockup |
|---|---|
| **Normal** | KPIs con datos, actividad reciente, acciones rápidas (ver §4) |
| **Vacío** | "🏢 No hay tenants configurados. [Crear primer tenant]" |
| **Carga** | Skeleton cards pulsando en las 3 cajas de KPIs + lista de actividad |
| **Error** | Banner rojo: "⚠ No se pudo conectar a bAuth. [Reintentar]" |

#### Editor de Identidad

| Estado | Mockup |
|---|---|
| **Normal** | Árbol con entidades (ver §5.4) |
| **Vacío** | "📁 Este tenant no tiene entidades todavía. Arrastrá un bDomain desde la paleta o usá [＋ Nueva entidad]." La paleta está habilitada. El área del árbol muestra una zona de drop gigante con borde punteado. |
| **Carga** | Esqueleto del árbol: líneas grises simulando 5 niveles con nodos fantasma. La paleta se deshabilita hasta que cargue. |
| **Error** | "⚠ No se pudo cargar el árbol de entidades. Error: timeout en idn_identidad_entidad. [Reintentar] [Usar caché local]" |

#### Editor de Roles

| Estado | Mockup |
|---|---|
| **Normal** | Árbol con políticas (ver §6.4) |
| **Vacío** | "🟦 No hay dominios de autorización configurados. Arrastrá un Dominio desde la paleta para empezar." |
| **Carga** | Esqueleto del árbol. Los 12 dominios aparecen como nodos fantasma hasta que se resuelven las políticas. |
| **Error** | "⚠ No se pudo cargar el árbol de políticas. [Reintentar]" |

#### Buscador

| Estado | Mockup |
|---|---|
| **Normal** | Resultados (ver §12.1) |
| **Vacío (sin búsqueda)** | "🔍 Buscá entidades por nombre, tipo, código, o cualquier atributo. Ejemplos: 'farol toyota', 'jperez', 'NIT 12345678901234'." |
| **Vacío (sin resultados)** | "😕 No se encontraron resultados para 'foco del izq ford falcon'. Sugerencias: verificá la ortografía, usá menos filtros, o buscá por código de producto." |
| **Carga** | Skeleton cards con barras de puntuación (★) pulsando |
| **Error** | "⚠ La búsqueda falló. Error: índice GIN en reconstrucción. [Reintentar en 30s]" |

### 13.2 Componentes de estado reutilizables

Todos los estados se implementan con estos widgets Flutter:

| Widget | Uso |
|---|---|
| `EmptyStateCard` | Icono + mensaje + acción sugerida |
| `SkeletonTree` | Esqueleto de árbol con N niveles y nodos fantasma |
| `SkeletonCard` | Esqueleto de tarjeta con barras de puntuación |
| `ErrorBanner` | Banner rojo con mensaje, código de error, y botón [Reintentar] |
| `LoadingOverlay` | Overlay semitransparente con spinner (para operaciones bloqueantes como compilación) |

---

## §14 Undo/Redo y atajos de teclado

### 14.1 Pila de deshacer/rehacer

Cada operación que modifica el árbol se registra en una pila de comandos:

```
Comando {
  tipo: "insert" | "delete" | "move" | "update_attrs",
  nodo_id: string,
  datos_anteriores: {},    // Estado antes de la operación
  datos_nuevos: {},        // Estado después de la operación
  timestamp: int
}
```

| Operación | Ctrl+Z (deshacer) | Ctrl+Shift+Z (rehacer) |
|---|---|---|
| Arrastrar Política a PolicySet | Elimina la política del PolicySet | Re-inserta la política |
| Eliminar una Regla | Re-crea la Regla con sus atributos anteriores | Re-elimina la Regla |
| Editar target de Regla | Restaura el target anterior | Re-aplica el nuevo target |
| Mover Actor de Pos | Devuelve el Actor a su Pos anterior | Re-mueve el Actor |

**Límite de pila:** 100 comandos por sesión. Al cerrar el editor, la pila se descarta.

### 14.2 Atajos de teclado

#### Globales (funcionan en cualquier vista)

| Atajo | Acción |
|---|---|
| `Ctrl+S` | Guardar cambios pendientes en el panel de propiedades activo |
| `Ctrl+Z` | Deshacer última operación en el editor activo |
| `Ctrl+Shift+Z` | Rehacer última operación deshecha |
| `Ctrl+Shift+C` | Compilar el elemento seleccionado (dominio, política, o regla) |
| `Ctrl+F` | Foco en la barra de búsqueda del editor activo |
| `Ctrl+N` | Nuevo elemento (depende del editor activo: entidad, política, regla) |
| `Escape` | Cerrar modal / deseleccionar nodo / cancelar drag |
| `F2` | Renombrar nodo seleccionado |
| `Supr` | Eliminar nodo seleccionado (con confirmación) |
| `Ctrl+1` | Ir a Inicio |
| `Ctrl+2` | Ir a Editor de Identidad |
| `Ctrl+3` | Ir a Editor de Roles |
| `Ctrl+4` | Ir a Buscador |

#### Editor de Identidad

| Atajo | Acción |
|---|---|
| `Ctrl+Shift+N` | Nueva entidad (tipo depende del nodo seleccionado) |
| `Ctrl+Shift+A` | Agregar atributo a la entidad seleccionada |
| `→` / `←` | Expandir / colapsar nodo del árbol |
| `↑` / `↓` | Navegar entre nodos hermanos |
| `Tab` | Foco en el panel de propiedades |
| `Ctrl+Enter` | Verificar atributos de entidad seleccionada |

#### Editor de Roles

| Atajo | Acción |
|---|---|
| `Ctrl+Shift+N` | Nueva regla en la política seleccionada |
| `Ctrl+Shift+P` | Nueva política en el dominio/bloque/policyset seleccionado |
| `Ctrl+Enter` | Validar regla seleccionada con atomc |
| `Ctrl+Shift+Enter` | Compilar dominio seleccionado |
| `→` / `←` | Expandir / colapsar nodo |
| `↑` / `↓` | Navegar entre nodos hermanos |

### 14.3 Diálogo de confirmación para operaciones destructivas

```
┌──────────────────────────────────────────────────────────────┐
│  ⚠ ¿Eliminar la política "password_policy"?                  │
│                                                              │
│  Esta política contiene 3 reglas:                             │
│    🟥 longitud_mínima                                         │
│    🟥 historial_contraseñas                                   │
│    🟥 complejidad_caracteres                                  │
│                                                              │
│  ⚠ La eliminación es irreversible. Las reglas quedarán       │
│    huérfanas y no se evaluarán en el PDP.                    │
│                                                              │
│  [Cancelar]  [Eliminar política y sus reglas]                │
└──────────────────────────────────────────────────────────────┘
```

---

## §15 Mapa anexo → manuales

| Sección | Respalda a |
|---|---|
| §1 (propósito) | 2.15 §1-§2 · 2.17 §1-§2 |
| §2 (Composite Pattern) | GoF Gamma et al. 1994 |
| §3 (Shell y navegación) | 2.15 §5 · 2.17 §5 · ADR-020 |
| §4 (Landing page) | 2.15 §5 (stats) · 2.17 §5 (stats) |
| §5 (Editor de Identidad) | 1.06 D00 · 1.07 Atributos · 2.15 Motor de Identidad · A.52-A.57 |
| §6 (Editor de Roles) | 1.03 Átomos · 1.04 BitMask · 2.17 Motor de Roles · A.59-A.62 |
| §7 (Flujo de compilación) | 2.17 §6 (pipeline 4 motores) · atomc (lexer/parser/semantic/codegen) |
| §8 (Interfaz Usuario↔Rol) | 2.17 §4.3-§4.4 · 1.08 Usuarios · A.51 Merge de Roles |
| §9 (Gestión de SETs D94/D98) | 1.06 D00 (USERSETs) · 2.17 §4.5 (grupos/conjuntos) |
| §10 (NodeContract explícito) | A.56 §3.6 (idn_identidad_requisito) · A.61 §3.3 (idn_rolestpl_requisito) |
| §11 (Validación visual) | A.56 §3.6 · A.61 §3.3 |
| §12 (Buscador) | 2.15 §5 (search) · A.56 §4 (búsquedas) · A.57 (rendimiento) |
| §13 (Estados UI) | Patrones estándar de UX para aplicaciones enterprise |
| §14 (Undo/redo + atajos) | Command Pattern (GoF) · Estándar CUA (Common User Access) |

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 2.1.0 | 2026-07-15 | **Completo.** Agrega: shell de navegación con sidebar + breadcrumbs (§3), landing page con KPIs (§4), selector multi-tenant (§3.3), navegación cruzada entre editores (§3.4), 7 paneles de propiedades faltantes (§5.5-§5.8, §6.6-§6.8, §6.10), flujo de compilación atomc completo (§7), interfaz Usuario↔Rol con validación SoD (§8), gestión de SETs D94/D98 (§9), NodeContract como código explícito (§10), estados vacío/carga/error para todas las vistas (§13), undo/redo + 25 atajos de teclado (§14). |
| 2.0.0 | 2026-07-15 | Separó el dashboard unificado en dos editores independientes + Buscador como vista de consulta. |
| 1.0.0 | 2026-07-15 | Primera edición (incorrecta). Mezclaba los 3 árboles en un solo dashboard. |