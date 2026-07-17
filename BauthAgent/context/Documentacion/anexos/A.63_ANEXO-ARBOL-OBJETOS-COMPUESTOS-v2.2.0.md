# A.63 — Objetos Compuestos del Árbol AtomLang v2.2.0
## Arquitectura completa del Desktop bAuth: shell, editores, buscador, compilación, auditoría y flujos de trabajo

**Versión:** 2.2.0
**Fecha:** 2026-07-15
**Tipo de anexo:** A (traslado de SSOT) + C (justificación de decisión técnica)
**Respalda a:** [2.13 AtomLang v2.0](../2.13_MANUAL-ATOMLANG-LENGUAJE-v2.0.md) · [1.06 D00 Identidad v2.1.0](../1.06_MANUAL-D00-IDENTIDAD-v2.0.md) · [2.15 Motor de Identidad v1.2.0](../2.15_MANUAL-MOTOR-IDENTIDAD-v1.0.md) · [2.17 Motor de Roles v1.1.0](../2.17_MANUAL-MOTOR-ROLES-v1.0.md) · [A.56 Diseño BD Identidad](A.56_ANEXO-DISENO-BD-IDENTIDAD-v1.0.md) · [A.61 Diseño BD Roles](A.61_ANEXO-DISENO-BD-ROLES-v1.0.md)
**Reemplaza a:** A.63 v2.1.0 (2026-07-15)
**Normas base:** GoF Composite Pattern (Gamma, Helm, Johnson, Vlissides 1994) · OASIS XACML 3.0 §5 · NIST SP 800-162 §4 (PAP) · NIST SP 800-63A (IAL)
**Referencias industria:** WSO2 PAP · ONAP Policy Framework · AWS IAM Console · Okta Admin Console · VS Code (LSP, minimap, menú contextual) · Figma (panel de propiedades)

---

## §0 Correcciones acumuladas

| Versión | Qué corrigió |
|---|---|
| **v2.0.0** | Separó el dashboard unificado en dos editores independientes. Degradó el Buscador de "tercer árbol" a vista de consulta. |
| **v2.1.0** | Agregó: shell, landing page, selector multi-tenant, 12 paneles de propiedades, flujo de compilación atomc, interfaz Usuario↔Rol, SETs D94/D98, navegación cruzada, NodeContract explícito, estados vacío/carga/error, undo/redo + atajos. |
| **v2.2.0** | Completa lo que v2.1.0 dejó sin diseñar: menú contextual (clic derecho), semántica del drag (crear/mover/copiar), flujo Verificar atributo (APIs externas SEGIP/SIN/ADSIB), flujo Vincular HW (bNexus), comportamiento offline/reconexión, vista de auditoría, operaciones en lote, vista de atributos (D93), consola atomc, reportes, panel de admin. |

---

## §1 Propósito

Definir la **arquitectura completa de la aplicación desktop de bAuth**: shell de navegación,
dos editores de árbol (Identidad y Roles), buscador de entidades, flujo de compilación atomc,
interfaz de asignación Usuario↔Rol, gestión de SETs, auditoría, menú contextual, operaciones
en lote, comportamiento offline, y todos los estados de la UI.

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
el mecanismo de drag & drop, el menú contextual.

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
│  🏷️ Atributos (D93)                                                         │
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
│ 🔍 Auditoría│                                                                 │
│ ⚙ Admin     │                                                                 │
├────────────┴─────────────────────────────────────────────────────────────────┤
│  BARRA DE ESTADO: ✅ Conectado · interno.skull · 12 dominios · 178 reglas    │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Componentes del shell

| Componente | Qué contiene | Persiste entre navegación |
|---|---|---|
| **Barra superior** | Logo bAuth, menú hamburguesa, selector de tenant, indicadores (tema, conexión, usuario) | Sí |
| **Sidebar** | Navegación: Inicio, Identidad (Entidades, Atributos, Buscador, USERSETs), Roles (Políticas, Asignaciones, SETs), atomc, Reportes, Auditoría, Admin | Sí |
| **Área de trabajo** | El editor activo | No — cambia al navegar |
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
| Menú contextual → "Ver en Roles" | Editor de Roles, item abierto | Clic derecho sobre Actor → "Ver roles asignados" |

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
| **Tenant** | Composite | 🏢 | Raíz | Organización raíz. |
| **bDomain** | Composite | 📁 | Tenant | Dominio de negocio: empresa, hogar, equipo, proyecto. |
| **bSubDomain** | Composite | 📂 | bDomain | Subdivisión: sucursal, departamento, oficina. |
| **Pos** | Composite | 📍 | bSubDomain | Punto lógico: caja, puerta, escritorio, vehículo. |
| **Actor** | Leaf | 👤 | Pos, bSubDomain, bDomain | Entidad hoja: persona, bot, dispositivo, servicio. |
| **Atributo** | Leaf | 🏷️ | Cualquier entidad | Propiedad: nombre, email, CI, NIT, placa. |

### 5.3 Contratos del Editor de Identidad

| Objeto | allowedChildren | requiredAttrs | minChildren | maxChildren |
|---|---|---|---|---|
| **Tenant** | bdomain, atributo | nombre, slug, is_internal | 1 | null |
| **bDomain** | bsubdomain, actor, atributo | nombre, tipo (D93) | 1 | null |
| **bSubDomain** | pos, actor, atributo | nombre, tipo (D93) | 1 | null |
| **Pos** | actor, atributo | nombre, tipo (D93) | 1 | null |
| **Actor** | atributo | nombre, tipo_entidad | 0 | null |
| **Atributo** | — | category, attr_key | 0 | 1 (por entidad) |

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
│ 🔍 Auditor.│          │                                                      │
│ ⚙ Admin    │          👤 jperez (PERSONA) · IAL2 ✅                          │
│            │            │  🏷️ CI: 1234567 LP · ✅ SEGIP                      │
│            │            │  🏷️ Email: jperez@skull.com                        │
│            │            │  🔗 Roles: vendedor_senior, cajero_basico          │
│            │                                                                 │
│            │  📁 Juan Pérez (persona_física) · expandir ▸                    │
│            └────────────────────────────────────────────────[＋] [🗑️] [🔍]──│
│  ✅ Conectado · interno.skull · 1 tenant · 2 bDomains · 12 atributos        │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 5.5 Panel de Propiedades — Tenant

```
┌─────────────────────────────────────────┐
│  🏢 TENANT                              │
│  ───────────────────────────────        │
│  Slug: skull · Nombre: SKULL            │
│  Tipo: interno · País: BO               │
│  ┌─ ATRIBUTOS ──────────────────────┐   │
│  │ 🏷️ nombre · comercial: SKULL S.R.L.│  │
│  │ 🏷️ tributario · NIT: 12345678901234│  │
│  │ [＋ Agregar atributo]              │   │
│  └───────────────────────────────────┘   │
│  ┌─ ESTADÍSTICAS ──────────────────┐    │
│  │ bDomains: 3 · bSubs: 5 · Pos: 12│    │
│  │ Actores: 47 · Atributos: 312     │    │
│  └───────────────────────────────────┘   │
│  ┌─ USERSETs ───────────────────────┐    │
│  │ 👥 vendedores · 12 miembros      │    │
│  │ [＋ Crear USERSET]                │    │
│  └───────────────────────────────────┘   │
│  [Editar] [Exportar JSON] [🔍 Auditoría] │
└─────────────────────────────────────────┘
```

### 5.6 Panel de Propiedades — bDomain

```
┌─────────────────────────────────────────┐
│  📁 bDOMAIN                              │
│  ───────────────────────────────        │
│  Slug: skull-corp · SKULL-CORP          │
│  Tipo: sociedad_comercial               │
│  ┌─ ATRIBUTOS ──────────────────────┐   │
│  │ 🏷️ NIT: 12345678901234 ✅ SIN     │   │
│  │ 🏷️ Email: legal@skull.com         │   │
│  └───────────────────────────────────┘   │
│  ┌─ ENTIDADES HIJAS ───────────────┐    │
│  │ 📂 Norte · 📂 Sur · 👤 mgarcia   │    │
│  └───────────────────────────────────┘   │
│  [Editar] [＋ bSubDomain] [＋ Actor]     │
└─────────────────────────────────────────┘
```

### 5.7 Panel de Propiedades — bSubDomain

```
┌─────────────────────────────────────────┐
│  📂 bSUBDOMAIN                           │
│  ───────────────────────────────        │
│  Slug: norte · Nombre: Norte            │
│  Tipo: oficina_comercial                │
│  ┌─ ATRIBUTOS ──────────────────────┐   │
│  │ 🏷️ Dirección: Calle Comercio #100 │   │
│  └───────────────────────────────────┘   │
│  ┌─ PUNTOS LÓGICOS ────────────────┐    │
│  │ 📍 CAJA-01 · 📍 CAJA-02          │    │
│  └───────────────────────────────────┘   │
│  [Editar] [＋ Pos] [＋ Actor]            │
└─────────────────────────────────────────┘
```

### 5.8 Panel de Propiedades — Pos + flujo Vincular HW

```
┌─────────────────────────────────────────┐
│  📍 POS                                  │
│  ───────────────────────────────        │
│  Slug: caja-01 · Nombre: CAJA-01        │
│  Tipo: punto_de_venta                   │
│  ┌─ ATRIBUTOS ──────────────────────┐   │
│  │ 🏷️ Serial: TERM-2024-001          │   │
│  │ 🏷️ IP: 192.168.1.50               │   │
│  └───────────────────────────────────┘   │
│  ┌─ HARDWARE VINCULADO ────────────┐    │
│  │ 🔌 TERM-2024-001 · Terminal POS  │    │
│  │    MAC: aa:bb:cc:dd:ee:01        │    │
│  │    Estado: ✅ Online              │    │
│  │    [Desvincular]                  │    │
│  └───────────────────────────────────┘   │
│  ┌─ ACTORES ───────────────────────┐    │
│  │ 👤 jperez · vendedor             │    │
│  └───────────────────────────────────┘   │
│  [Editar] [＋ Actor] [Vincular HW]       │
└─────────────────────────────────────────┘
```

**Flujo `[Vincular HW]`:** al presionar el botón, se abre un modal que consulta a bNexus
por dispositivos físicos disponibles en el mismo tenant:

```
┌──────────────────────────────────────────────────────────────┐
│  🔌 VINCULAR HARDWARE A CAJA-01                              │
│                                                              │
│  Buscar dispositivo: [TERM________________________________]🔍│
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ ☐ TERM-2024-003 · Terminal POS · 192.168.1.55        │   │
│  │    MAC: aa:bb:cc:dd:ee:03 · Sin vincular             │   │
│  │ ☑ TERM-2024-008 · Terminal POS · 192.168.1.57        │   │
│  │    MAC: aa:bb:cc:dd:ee:08 · Sin vincular             │   │
│  │ ☐ IMP-2024-001 · Impresora fiscal · 192.168.1.60     │   │
│  │    MAC: ff:ee:dd:cc:bb:01 · Vinculada a CAJA-02      │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ⚠ Al vincular, CAJA-01 hereda IP, MAC y metadata del      │
│    dispositivo físico. El dispositivo queda marcado como     │
│    "en uso" en bNexus.                                      │
│                                                              │
│  [Cancelar]  [Vincular seleccionado]                        │
└──────────────────────────────────────────────────────────────┘
```

**JSON-RPC:** `bnexus.device.list(tenant_id, filters?)` → lista de dispositivos.
Al vincular: `bauth.pos.vincular_hw(pos_id, device_id)` → actualiza Pos + notifica a bNexus.

### 5.9 Panel de Propiedades — Actor

```
┌─────────────────────────────────────────┐
│  👤 ACTOR                                │
│  ───────────────────────────────        │
│  Slug: jperez · Tipo: PERSONA           │
│  Nivel: IAL2 ✅ · Tenant: interno.skull │
│  ┌─ ATRIBUTOS ──────────────────────┐   │
│  │ 👤 nombre · given_name: Juan      │   │
│  │ 👤 nombre · family_name: Pérez    │   │
│  │ 📧 email · work: jperez@skull.com │   │
│  │ 📋 id_nacional · CI: 1234567 LP   │   │
│  │ [＋ Agregar atributo]              │   │
│  └───────────────────────────────────┘   │
│  ┌─ DOMINIOS DE IDENTIDAD ─────────┐    │
│  │ ✅ civil · 4 atributos            │    │
│  │ ✅ laboral · 3 atributos          │    │
│  │ ⬜ cliente · sin atributos        │    │
│  └───────────────────────────────────┘   │
│  ┌─ ROLES ASIGNADOS ────────────────┐   │
│  │ 🔗 vendedor_senior · PERMANENTE   │   │
│  │ 🔗 cajero_basico · PERMANENTE     │   │
│  │ [＋ Asignar rol]                   │   │
│  └───────────────────────────────────┘   │
│  [Guardar] [Cancelar] [🔍 Auditoría]     │
└─────────────────────────────────────────┘
```

### 5.10 Panel de Propiedades — Atributo + flujo Verificar

```
┌─────────────────────────────────────────┐
│  🏷️ ATRIBUTO                            │
│  ───────────────────────────────        │
│  Entidad: jperez (PERSONA)              │
│  Categoría: documento                   │
│  Atributo: id_nacional · Tipo: CI       │
│  Valor: 1234567 LP                      │
│  Dominio: civil · Visibilidad: PRIVADA  │
│  atom_code: 5826 🔗                     │
│                                         │
│  Verificación: ✅ Verificado             │
│    Fuente: SEGIP · Fecha: 2024-03-15    │
│    Expira: 2026-03-15                   │
│                                         │
│  ┌─ HISTORIAL ──────────────────────┐   │
│  │ 2024-03-15 · Creado · admin       │   │
│  │ 2024-03-15 · Verificado · SEGIP   │   │
│  │ [Ver historial completo]          │   │
│  └───────────────────────────────────┘   │
│  [Editar] [Verificar] [Eliminar]         │
└─────────────────────────────────────────┘
```

**Flujo `[Verificar]`:** el botón dispara el verbo `verify` del Motor de Identidad (2.15 §3.2).
Se abre un modal de progreso que consulta a la API externa (SEGIP, SIN, ADSIB según el tipo
de atributo):

```
┌──────────────────────────────────────────────────────────────┐
│  🔍 VERIFICANDO CI 1234567 LP contra SEGIP                   │
│                                                              │
│  ⬛ Conectando a SEGIP ············ ✅ (234ms)               │
│  ⬛ Enviando CI: 1234567 LP ······· ✅                       │
│  ⬛ Verificando coincidencia ······ ⏳                       │
│                                                              │
│  [Cancelar]                                                  │
└──────────────────────────────────────────────────────────────┘
```

**Resultados posibles:**

| Resultado | Badge | Acción |
|---|---|---|
| ✅ Verificado | Verde `✅ Verificado` + `verified_by: SEGIP` + `verified_at: now()` | Actualiza `idn_identidad_atributo.is_verified = true` |
| ❌ No coincide | Rojo `❌ Rechazado` + "La CI no coincide con los registros de SEGIP" | El atributo se marca con error. No se puede subir a IAL2. |
| ⚠ API no disponible | Amarillo `⚠ Pendiente` + "SEGIP no disponible. Reintentar más tarde." | El atributo queda sin verificar. Se agenda reintento. |
| ⏱ Timeout | Amarillo `⚠ Timeout` + "SEGIP no respondió en 30s." | Igual que no disponible. |

**JSON-RPC:** `bauth.identidad.atributo.verify(entidad_id, attr_key, type)` → `VerifyResult`
**CLI equivalente:** `bauthctl identidad atributo verify jperez id_nacional CI`

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
  ├────────── Leaf: Regla         ── hijos: target, condition, effect (incluidos)
  └────────── Leaf: Guardrail     ── hijos: target, effect (sin condition, application_id=null)
```

### 6.2 Objetos de la paleta

| Objeto | Tipo GoF | Icono | Se suelta en | Significado |
|---|---|---|---|---|
| **Dominio** | Composite | 🟦 | Raíz | Los 12 dominios de autorización XACML. |
| **Bloque** | Composite | 🟩 | Dominio | Agrupación funcional. Hereda combining_algorithm. |
| **PolicySet** | Composite | 🟨 | Dominio, Bloque, PolicySet | Contenedor de políticas. |
| **Política** | Composite | 🟧 | Dominio, Bloque, PolicySet | Política concreta con application_id. |
| **Regla** | Leaf | 🟥 | Política, PolicySet (con contrato) | Regla XACML atómica. |
| **Guardrail** | Leaf | 🟪 | PolicySet, Dominio | Regla global sin application_id. |

### 6.3 Contratos del Editor de Roles

| Objeto | allowedChildren | requiredAttrs | minChildren | maxChildren |
|---|---|---|---|---|
| **Dominio** | bloque, policyset, politica, guardrail | combining_algorithm, domain_name | 1 | null |
| **Bloque** | policyset, politica | nombre | 1 | null |
| **PolicySet** | policyset, politica, guardrail | combining_algorithm | 1 | null |
| **Política** | regla | combining_algorithm, application_id | 1 | null |
| **Regla** | — | verb_id, target, effect | — | — |
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
│ ─────────  │      │                                               ────────────│
│ ROLES      │      🟧 password_policy                         [＋ Regla]       │
│ 🟦 Polític.│        ⚙ application_id: bauth.password_policy                  │
│ 🔗 Asignac.│        │                                               ──────────│
│ 📋 SETs    │        🟥 longitud_mínima                ✅ COMPLETA            │
│ ─────────  │        🟥 historial_contraseñas          ✅ COMPLETA            │
│ 🛠️ atomc   │        🟥 complejidad_caracteres         ⚠ FALTA EFFECT         │
│ 📊 Reportes│                                                                │
│ 🔍 Auditor.│    🟩 B7 · PrivilegeEngine                                     │
│ ⚙ Admin    │      │                                               ────────────│
│            │      🟧 field_restrictions                    [＋ Regla]         │
│            │        │                                               ──────────│
│            │        🟥 campo_margin_oculto               ✅ COMPLETA         │
│            │        🟥 campo_cost_price_oculto           ✅ COMPLETA         │
│            │        🟥 campo_credit_limit_readonly       ⚠ SIN EFFECT        │
│            └──────────────────────────────────────────────────────────────────│
│  ✅ Conectado · interno.skull · 12 dominios · 41 políticas · 2 advertencias  │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 6.5–6.10 Paneles de Propiedades del Editor de Roles

Los paneles de Dominio, Bloque, PolicySet, Política, Regla y Guardrail mantienen el mismo
diseño de v2.1.0 (§6.5–§6.10). Ver documento anterior para referencia completa.

---

## §7 Flujo de compilación — atomc integrado

### 7.1 Cuándo se compila

| Gatillo | Alcance | Quién ejecuta |
|---|---|---|
| Botón `[Compilar regla]` | Una regla | atomc en servidor (`atomc.compile_rule`) |
| Botón `[Compilar política]` | Una política y sus reglas | atomc en servidor |
| Botón `[Compilar dominio]` | Un dominio completo | atomc en servidor |
| Menú contextual → "Compilar dominio" | Dominio sobre el que se hizo clic derecho | atomc en servidor |
| `Ctrl+Shift+C` (atajo global) | Elemento seleccionado | atomc en servidor |

### 7.2 Qué hace el compilador

```
1. LEXER: Tokeniza el árbol fuente (el "código fuente" ES el árbol)
2. PARSER: Valida la estructura contra la gramática AtomLang
3. SEMANTIC: Verifica reglas de negocio (SoD, conflictos, herencia)
4. CODEGEN: Genera el IR (privilege_atom_compiled) + recalcula RolBitMask
```

### 7.3 Progreso de compilación

```
┌──────────────────────────────────────────────────────────────┐
│  🔨 COMPILANDO D1 · ACCESO LÓGICO                            │
│                                                              │
│  ⬛ Lexer      ··············· ✅ 178 tokens (12ms)          │
│  ⬛ Parser     ··············· ✅ Árbol válido (8ms)         │
│  ⬛ Semantic   ··············· ⚠ 2 advertencias (45ms)       │
│  ⬛ Codegen    ··············· ⏳ Generando IR...             │
│                                                              │
│  [Cancelar]  [Ver IR generado]                              │
└──────────────────────────────────────────────────────────────┘
```

### 7.4 Resultado exitoso

```
┌──────────────────────────────────────────────────────────────┐
│  ✅ COMPILACIÓN EXITOSA — D1 · ACCESO LÓGICO                 │
│  ⏱ 89ms · 47 átomos generados · 0 errores · 2 avisos       │
│  [Cerrar]  [Ver IR]  [Ver diff con compilación anterior]    │
└──────────────────────────────────────────────────────────────┘
```

### 7.5 Errores inline en el árbol

```
🟧 password_policy                          ⚠ 2 ERRORES
  │
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
      └─────────────────────────────────────────────┘
```

### 7.6 Integración desktop ↔ atomc

```
Desktop (Flutter)                      BauthAgent (Rust)
─────────────────                      ──────────────────
1. Usuario presiona [Compilar]
   → Envía domain_id o politica_id
                                       2. Handler atomc.compile
                                          → Resuelve subárbol desde BD
                                          → Ejecuta atomc (lexer, parser, semantic, codegen)
                                          → Persiste IR en privilege_atom_compiled
                                          → Recalcula RolBitMask
3. Recibe resultado JSON
4. Actualiza árbol con errores inline
```

**JSON-RPC:** `bauth.atomc.compile(domain_id, options?)` → `CompileResult`

---

## §8 Interfaz de asignación Usuario↔Rol

### 8.1 Dos puntos de entrada

| Desde | Flujo |
|---|---|
| **Panel de Actor** (§5.9) → `[＋ Asignar rol]` | Modal de asignación rápida |
| **Sidebar > ROLES > 🔗 Asignaciones** | Vista completa: grilla usuarios × roles |
| **Menú contextual sobre Actor** → "Asignar rol" | Modal de asignación rápida |
| **Selección múltiple** (§21) → "Asignar rol a N seleccionados" | Modal de asignación en lote |

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
│  │     Matriz SoD: zona.supervisar XOR caja.operar      │   │
│  │     [Forzar asignación (requiere autorización)]       │   │
│  │ ☐ administrador     · SYS    · 312 átomos             │   │
│  │   🔒 Requiere autorización tier SU                   │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  Modo: [PERMANENTE ▾]  Válido hasta: [Sin expiración] 📅    │
│                                                              │
│  [Cancelar]  [Asignar]                                      │
└──────────────────────────────────────────────────────────────┘
```

**Validación SoD en tiempo real:** cada checkbox se evalúa contra los roles actuales del usuario.

### 8.3 Vista completa de Asignaciones

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🏠 Inicio > 🔗 Asignaciones                                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│  🔍 [Buscar...]  [Filtro: Todos ▾]  [＋ Nueva asignación]  [Asignación lote] │
├──────────────────────────────────────────────────────────────────────────────┤
│  ☐ Usuario          │ Rol              │ Modo       │ Desde      │ Hasta     │
├──────────────────────┼─────────────────┼────────────┼────────────┼───────────│
│  ☐ 👤 jperez         │ vendedor_senior │ PERMANENTE │ 2024-03-15 │ —         │
│  ☐ 👤 jperez         │ cajero_basico   │ PERMANENTE │ 2024-06-01 │ —         │
│  ☐ 👤 mgarcia        │ cajero_basico   │ PERMANENTE │ 2024-02-10 │ —         │
│  ☑ 👤 mgarcia        │ analista_pagos  │ TEMPORAL   │ 2026-07-01 │ 2026-08-01│
│  ☐ 🤖 bot-factura    │ m2m_facturacion │ PERMANENTE │ 2024-05-01 │ —         │
│                                                                              │
│  1 seleccionado · [Revocar seleccionado]  [Cambiar expiración]               │
│  📊 3 usuarios · 6 asignaciones · 4 roles distintos                         │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## §9 Gestión de SETs — D94 USERSETs y D98 SETs

### 9.1 Dónde se gestionan

| Tipo | Dominio | Sidebar | Qué agrupa | Ejemplo |
|---|---|---|---|---|
| **USERSET (D94)** | Identidad | `👥 USERSETs` | Entidades (actores) por contexto operativo | `vendedores`, `financieros` |
| **SET (D98)** | Roles | `📋 SETs` | Roles por conjunto funcional | `roles_financieros`, `politicas_pci` |

### 9.2 Vista USERSETs (D94)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🏠 Inicio > 👥 USERSETs (D94)                                               │
├──────────────────────────────────────────────────────────────────────────────┤
│  🔍 [Buscar USERSET...]  [＋ Nuevo USERSET]                                  │
├──────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ 👥 vendedores · SKULL · 12 miembros                                  │    │
│  │    Usado en: 5 reglas (D1, D3, D7)                                   │    │
│  │    Miembros: jperez, mgarcia, aruiz, lflores, ...                    │    │
│  │    [Editar miembros]  [Ver reglas que lo usan 🔗]                     │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ 👥 financieros · SKULL · 5 miembros                                  │    │
│  │    Usado en: 12 reglas (D3, D7)                                      │    │
│  │    [Editar miembros]  [Ver reglas que lo usan 🔗]                     │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 9.3 Vista SETs (D98)

Estructura análoga a USERSETs pero agrupando roles en lugar de actores.

### 9.4 Editor de miembros

```
┌──────────────────────────────────────────────────────────────────────┐
│  ✏ EDITAR MIEMBROS — 👥 vendedores                                  │
│                                                                      │
│  🔍 [Buscar entidad...]                                              │
│                                                                      │
│  Disponibles:                          Miembros (12):                │
│  ┌────────────────────────┐            ┌────────────────────────┐   │
│  │ ☐ 👤 dtorres           │   [＋]     │ 👤 jperez      [✕]     │   │
│  │ ☑ 👤 aruiz             │   ───▶    │ 👤 mgarcia     [✕]     │   │
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
  nodeType:       string,
  editor:         "identidad" | "roles",
  allowedChildren: string[],
  requiredAttrs:  string[],
  optionalAttrs:  string[],
  minChildren:    int,
  maxChildren:    int | null,
  icon:           string,
  color:          string,
  description:    string,
  contextMenuActions: string[],    // Acciones del menú contextual
  crossEditorLinks: {
    attr: string,
    targetEditor: "identidad" | "roles" | "sets",
    targetRoute: string
  }[]
}
```

### 10.2 Contratos completos — Editor de Identidad

```
// TENANT
{ nodeType: "tenant", editor: "identidad",
  allowedChildren: ["bdomain", "atributo"],
  requiredAttrs: ["nombre", "slug", "is_internal"],
  optionalAttrs: ["pais", "logo_url", "plan_tier"],
  minChildren: 1, maxChildren: null,
  icon: "🏢", color: "blue",
  contextMenuActions: ["edit", "add_bdomain", "add_atributo", "export_json", "copy_slug", "audit"] }

// BDOMAIN
{ nodeType: "bdomain", editor: "identidad",
  allowedChildren: ["bsubdomain", "actor", "atributo"],
  requiredAttrs: ["nombre", "tipo"],
  optionalAttrs: ["descripcion"],
  minChildren: 1, maxChildren: null,
  icon: "📁", color: "teal",
  contextMenuActions: ["edit", "add_bsubdomain", "add_actor", "add_atributo", "copy_slug", "delete"] }

// BSUBDOMAIN
{ nodeType: "bsubdomain", editor: "identidad",
  allowedChildren: ["pos", "actor", "atributo"],
  requiredAttrs: ["nombre", "tipo"],
  optionalAttrs: ["descripcion", "direccion"],
  minChildren: 1, maxChildren: null,
  icon: "📂", color: "green",
  contextMenuActions: ["edit", "add_pos", "add_actor", "add_atributo", "copy_slug", "delete"] }

// POS
{ nodeType: "pos", editor: "identidad",
  allowedChildren: ["actor", "atributo"],
  requiredAttrs: ["nombre", "tipo"],
  optionalAttrs: ["serial", "ip", "coordenadas", "device_id"],
  minChildren: 1, maxChildren: null,
  icon: "📍", color: "amber",
  contextMenuActions: ["edit", "add_actor", "add_atributo", "vincular_hw", "copy_slug", "delete"] }

// ACTOR
{ nodeType: "actor", editor: "identidad",
  allowedChildren: ["atributo"],
  requiredAttrs: ["nombre", "tipo_entidad"],
  minChildren: 0, maxChildren: null,
  icon: "👤", color: "indigo",
  contextMenuActions: ["edit", "add_atributo", "asignar_rol", "add_to_userset", "copy_slug", "audit", "delete"],
  crossEditorLinks: [
    { attr: "roles_asignados", targetEditor: "roles", targetRoute: "/roles/rol/{role_slug}" },
    { attr: "userset_pertenece", targetEditor: "sets", targetRoute: "/sets/usersets/{set_slug}" }
  ]}

// ATRIBUTO
{ nodeType: "atributo", editor: "identidad",
  allowedChildren: [],
  requiredAttrs: ["category", "attr_key"],
  optionalAttrs: ["type", "value_text", "value_data", "dominio_origen",
                  "visibilidad", "is_verified", "verified_by", "atom_code"],
  minChildren: 0, maxChildren: 0,
  icon: "🏷️", color: "gray",
  contextMenuActions: ["edit", "verify", "delete", "copy_value"],
  crossEditorLinks: [
    { attr: "atom_code", targetEditor: "roles", targetRoute: "/roles/atomo/{atom_code}" }
  ]}
```

### 10.3 Contratos completos — Editor de Roles

```
// DOMINIO
{ nodeType: "dominio", editor: "roles",
  allowedChildren: ["bloque", "policyset", "politica", "guardrail"],
  requiredAttrs: ["combining_algorithm", "domain_name"],
  optionalAttrs: ["descripcion", "domain_code"],
  minChildren: 1, maxChildren: null,
  icon: "🟦", color: "blue",
  contextMenuActions: ["edit", "add_bloque", "add_policyset", "add_politica", "add_guardrail",
                        "compile", "stats", "audit", "delete"] }

// BLOQUE
{ nodeType: "bloque", editor: "roles",
  allowedChildren: ["policyset", "politica"],
  requiredAttrs: ["nombre"],
  optionalAttrs: ["descripcion", "hereda_combining_algorithm"],
  minChildren: 1, maxChildren: null,
  icon: "🟩", color: "green",
  contextMenuActions: ["edit", "add_policyset", "add_politica", "duplicate", "delete"] }

// POLICYSET
{ nodeType: "policyset", editor: "roles",
  allowedChildren: ["policyset", "politica", "guardrail"],
  requiredAttrs: ["combining_algorithm"],
  optionalAttrs: ["nombre", "descripcion"],
  minChildren: 1, maxChildren: null,
  icon: "🟨", color: "yellow",
  contextMenuActions: ["edit", "add_sub_policyset", "add_politica", "add_guardrail",
                        "duplicate", "delete"] }

// POLÍTICA
{ nodeType: "politica", editor: "roles",
  allowedChildren: ["regla"],
  requiredAttrs: ["combining_algorithm", "application_id"],
  optionalAttrs: ["nombre", "descripcion", "target"],
  minChildren: 1, maxChildren: null,
  icon: "🟧", color: "orange",
  contextMenuActions: ["edit", "add_regla", "validate", "compile", "duplicate", "delete"] }

// REGLA
{ nodeType: "regla", editor: "roles",
  allowedChildren: [],
  requiredAttrs: ["verb_id", "target", "effect"],
  optionalAttrs: ["condition", "obligation", "advice", "nombre"],
  minChildren: 0, maxChildren: 0,
  icon: "🟥", color: "red",
  contextMenuActions: ["edit", "duplicate", "validate", "compile", "copy_slug", "delete"],
  crossEditorLinks: [
    { attr: "target.subject_set", targetEditor: "sets", targetRoute: "/sets/usersets/{set_slug}" },
    { attr: "condition.value_set", targetEditor: "sets", targetRoute: "/sets/sets/{set_slug}" }
  ]}

// GUARDRAIL
{ nodeType: "guardrail", editor: "roles",
  allowedChildren: [],
  requiredAttrs: ["verb_id", "effect"],
  optionalAttrs: ["target", "nombre"],
  minChildren: 0, maxChildren: 0,
  icon: "🟪", color: "purple",
  contextMenuActions: ["edit", "validate", "duplicate", "delete"] }
```

---

## §11 Cómo el constructor visual usa el contrato

### 11.1 Algoritmo de validación en drag & drop

```
función puedeSoltar(hijo: NodoTemplate, padre: NodoTemplate, modo: DragMode): boolean {
  1. Verificar editor:
     si hijo.contract.editor ≠ padre.contract.editor → false

  2. Verificar allowedChildren:
     si padre.contract.allowedChildren NO contiene hijo.contract.nodeType → false

  3. Verificar maxChildren:
     si padre.hijos.count(hijo.contract.nodeType) >= padre.contract.maxChildren → false

  4. Verificar cross-tenant (solo Identidad):
     si padre.tenant_id ≠ hijo.tenant_id → false

  5. Si todo OK:
     → zona de drop se ilumina en verde
     → cursor muestra ícono según modo: ＋ (crear), ↔ (mover), ❐❐ (copiar)
}
```

### 11.2 Semántica del drag — crear, mover, copiar

| Tipo de drag | Cómo se activa | Comportamiento | Cursor |
|---|---|---|---|
| **Crear** | Arrastrar desde la paleta al árbol | Crea un NUEVO nodo. Abre panel de propiedades vacío para completar requiredAttrs. | `＋` |
| **Mover** | Arrastrar un nodo del árbol a otro padre (sin modificador) | Cambia `parent_id`. El nodo y sus hijos cambian de ubicación en la jerarquía. | `↔` |
| **Copiar (duplicar)** | `Ctrl + arrastrar` un nodo del árbol | Crea una COPIA del nodo (nuevo UUID v7) con los mismos atributos. La copia queda en el padre destino. | `❐❐` |
| **Mover selección múltiple** | `Ctrl+clic` para seleccionar varios, luego arrastrar | Mueve todos los nodos seleccionados al padre destino. Solo si todos pasan la validación. | `↔↔` |

**Reglas adicionales:**
- **No se puede mover un nodo a su propio subárbol** (crearía un ciclo)
- **Mover entre tenants no está permitido** (§11.1 paso 4)
- **Al mover un nodo, sus hijos lo acompañan** (movimiento de subárbol completo)
- **Al copiar un nodo con hijos, los hijos también se copian** (copia profunda)

### 11.3 Diferencias de validación entre editores

| | Editor de Identidad | Editor de Roles |
|---|---|---|
| **Qué valida** | Completitud mínima de entidad (IAL1/IAL2) | Estructura XACML |
| **Fuente del contrato** | NodeContract + `idn_identidad_requisito` | NodeContract |
| **Validación post-construcción** | Motor de Identidad (`validate` + `verify`) | atomc (`atomc check`) |
| **Restricción cross-tenant** | ✅ No se permite | ❌ No aplica |

---

## §12 El Buscador — vista de consulta

El Buscador **no es un editor.** Es una vista de consulta del Motor de Identidad.

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
│  │    Fabricante: DEPO (Taiwán) · Posición: Delantero Izquierdo         │    │
│  │    ▸ 3 proveedores · Stock total: 85u · Desde $42                    │    │
│  │    🔗 [Ver en árbol]  [Copiar slug]                                   │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│  📊 3 resultados · <50ms · Buscado en 165M atributos                        │
│  [Exportar CSV]  [Compartir resultados]                                     │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## §13 Estados de la UI — vacío, carga, error, offline

### 13.1 Estados por vista

| Vista | Normal | Vacío | Carga | Error |
|---|---|---|---|---|
| **Inicio** | KPIs + actividad | "No hay tenants. [Crear primer tenant]" | Skeleton cards | "⚠ No se pudo conectar. [Reintentar]" |
| **Identidad** | Árbol con entidades | "Arrastrá un bDomain desde la paleta" + zona de drop gigante | Esqueleto de árbol 5 niveles | "⚠ Timeout en idn_identidad_entidad. [Reintentar]" |
| **Roles** | Árbol con políticas | "Arrastrá un Dominio desde la paleta" | Esqueleto con 12 dominios fantasma | "⚠ No se pudo cargar el árbol. [Reintentar]" |
| **Buscador** | Resultados | Sin búsqueda: ejemplos. Sin resultados: sugerencias. | Skeleton cards con ★ | "⚠ Índice GIN en reconstrucción. [Reintentar]" |

### 13.2 Comportamiento offline / reconexión

El desktop se conecta a bAuth vía WebSocket sobre Unix socket (ADR-020). Si el daemon no responde:

| Estado | Indicador visual | Comportamiento |
|---|---|---|
| **Conectado** | `✅ Conectado` (verde) en barra de estado | Operaciones normales |
| **Reconectando** | `🟡 Reconectando...` (amarillo, pulsando) | Árbol en solo lectura. Operaciones de escritura entran en cola local. |
| **Desconectado** | `🔴 Sin conexión` (rojo) + banner superior | Banner: "⚠ Sin conexión a bAuth. Las operaciones se guardarán localmente y se sincronizarán al reconectar. [Reintentar ahora] [Trabajar offline]" |
| **Reconexión** | Toast verde: "✅ Conexión restaurada. 3 operaciones sincronizadas." | La cola local se vacía contra el daemon. Si hay conflictos, se muestran en un diálogo. |

**Cola offline:**
- Las operaciones de escritura (crear, editar, eliminar, asignar) se encolan en SQLite local.
- Al reconectar, se envían en orden FIFO.
- Si una operación falla (ej. conflicto de versión), se notifica al usuario y se pausa la cola.
- Límite: 500 operaciones en cola. Superado eso, se advierte al usuario.

### 13.3 Componentes de estado reutilizables (Flutter)

| Widget | Uso |
|---|---|
| `EmptyStateCard` | Icono + mensaje + acción sugerida |
| `SkeletonTree` | Esqueleto de árbol con N niveles |
| `SkeletonCard` | Esqueleto de tarjeta |
| `ErrorBanner` | Banner rojo con mensaje y botón [Reintentar] |
| `LoadingOverlay` | Overlay semitransparente con spinner |
| `OfflineBanner` | Banner amarillo persistente con cola de operaciones pendientes |
| `ConnectionIndicator` | Icono en barra de estado: ✅ 🟡 🔴 |

---

## §14 Undo/Redo y atajos de teclado

### 14.1 Pila de deshacer/rehacer

```
Comando {
  tipo: "insert" | "delete" | "move" | "update_attrs" | "duplicate" | "bulk_assign",
  nodo_id: string,
  datos_anteriores: {},
  datos_nuevos: {},
  timestamp: int
}
```

**Límite:** 100 comandos por sesión. Se descarta al cerrar.

### 14.2 Atajos de teclado

#### Globales

| Atajo | Acción |
|---|---|
| `Ctrl+S` | Guardar cambios en panel de propiedades activo |
| `Ctrl+Z` / `Ctrl+Shift+Z` | Deshacer / Rehacer |
| `Ctrl+Shift+C` | Compilar elemento seleccionado |
| `Ctrl+F` | Foco en barra de búsqueda |
| `Ctrl+N` | Nuevo elemento |
| `Ctrl+D` | Duplicar nodo seleccionado |
| `Escape` | Cerrar modal / deseleccionar / cancelar drag |
| `F2` | Renombrar nodo |
| `Supr` | Eliminar nodo (con confirmación) |
| `Ctrl+1..4` | Ir a Inicio / Identidad / Roles / Buscador |
| `Ctrl+5` | Ir a Auditoría |
| `Ctrl+clic` | Selección múltiple |
| `Shift+clic` | Selección de rango |
| `Ctrl+A` | Seleccionar todos los nodos del nivel actual |

#### Editor de Identidad

| Atajo | Acción |
|---|---|
| `Ctrl+Shift+N` | Nueva entidad |
| `Ctrl+Shift+A` | Agregar atributo |
| `→/←` | Expandir/colapsar nodo |
| `↑/↓` | Navegar entre hermanos |
| `Ctrl+Enter` | Verificar atributos |

#### Editor de Roles

| Atajo | Acción |
|---|---|
| `Ctrl+Shift+N` | Nueva regla |
| `Ctrl+Shift+P` | Nueva política |
| `Ctrl+Enter` | Validar regla con atomc |
| `Ctrl+Shift+Enter` | Compilar dominio |
| `→/←` `↑/↓` | Navegación del árbol |

### 14.3 Diálogo de confirmación para operaciones destructivas

```
┌──────────────────────────────────────────────────────────────┐
│  ⚠ ¿Eliminar la política "password_policy"?                  │
│                                                              │
│  Esta política contiene 3 reglas:                             │
│    🟥 longitud_mínima · 🟥 historial_contraseñas              │
│    🟥 complejidad_caracteres                                  │
│                                                              │
│  ⚠ La eliminación es irreversible. Las reglas quedarán       │
│    huérfanas y no se evaluarán en el PDP.                    │
│                                                              │
│  [Cancelar]  [Eliminar política y sus reglas]                │
└──────────────────────────────────────────────────────────────┘
```

---

## §15 Menú contextual (clic derecho)

### 15.1 Principio

Cada nodo del árbol tiene un menú contextual que se abre con clic derecho. Las acciones
disponibles se derivan de `NodeContract.contextMenuActions` + `NodeContract.allowedChildren`.

### 15.2 Menús contextuales — Editor de Identidad

```
Clic derecho sobre 🏢 Tenant:
  ✏️ Editar tenant
  📁 Agregar bDomain
  🏷️ Agregar atributo
  ──────────────
  📋 Copiar slug
  📤 Exportar JSON
  🔍 Auditoría

Clic derecho sobre 📁 bDomain:
  ✏️ Editar bDomain
  📂 Agregar bSubDomain
  👤 Agregar Actor
  🏷️ Agregar atributo
  ──────────────
  📋 Copiar slug
  📋 Duplicar (Ctrl+D)
  ──────────────
  🗑️ Eliminar bDomain

Clic derecho sobre 📍 Pos:
  ✏️ Editar Pos
  👤 Agregar Actor
  🏷️ Agregar atributo
  🔌 Vincular hardware
  ──────────────
  📋 Copiar slug
  ──────────────
  🗑️ Eliminar Pos

Clic derecho sobre 👤 Actor:
  ✏️ Editar Actor
  🏷️ Agregar atributo
  🔗 Asignar rol
  👥 Agregar a USERSET
  ──────────────
  📋 Copiar slug
  📋 Duplicar Actor (Ctrl+D)
  🔍 Auditoría
  ──────────────
  🗑️ Eliminar Actor

Clic derecho sobre 🏷️ Atributo:
  ✏️ Editar atributo
  🔍 Verificar (SEGIP/SIN/ADSIB)
  ──────────────
  📋 Copiar valor
  ──────────────
  🗑️ Eliminar atributo
```

### 15.3 Menús contextuales — Editor de Roles

```
Clic derecho sobre 🟦 Dominio:
  ✏️ Editar dominio
  🟩 Agregar Bloque
  🟨 Agregar PolicySet
  🟧 Agregar Política
  🟪 Agregar Guardrail
  ──────────────
  🔨 Compilar dominio
  📊 Estadísticas del dominio
  ──────────────
  📋 Copiar domain_name
  🔍 Auditoría
  ──────────────
  🗑️ Eliminar dominio

Clic derecho sobre 🟧 Política:
  ✏️ Editar política
  🟥 Agregar Regla
  ──────────────
  ✅ Validar con atomc
  🔨 Compilar política
  📋 Duplicar política (Ctrl+D)
  ──────────────
  🗑️ Eliminar política

Clic derecho sobre 🟥 Regla:
  ✏️ Editar regla
  ──────────────
  ✅ Validar con atomc
  🔨 Compilar regla
  📋 Duplicar regla (Ctrl+D)
  📋 Copiar slug
  ──────────────
  🗑️ Eliminar regla

Clic derecho sobre 🟪 Guardrail:
  ✏️ Editar guardrail
  ✅ Validar con atomc
  📋 Duplicar (Ctrl+D)
  ──────────────
  🗑️ Eliminar guardrail
```

### 15.4 Menú contextual en selección múltiple

```
Clic derecho sobre N nodos seleccionados (3 Actores):
  🔗 Asignar rol a 3 actores
  👥 Agregar a USERSET
  ──────────────
  🗑️ Eliminar 3 actores
```

---

## §16 Vista de Atributos (D93) — catálogo de definiciones

El sidebar `🏷️ Atributos (D93)` abre el **catálogo de definiciones de atributos**.
No son instancias (jperez tiene CI 1234567 LP), sino **definiciones** (qué es una CI,
qué categoría tiene, qué REGEX la valida, qué API la verifica).

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🏠 Inicio > 🏷️ Atributos (D93)                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│  🔍 [Buscar atributo...]  [Categoría: Todas ▾]  [＋ Nueva definición]        │
├──────────────────────────────────────────────────────────────────────────────┤
│  Categoría       │ Atributo       │ Tipos                    │ Validación     │
├──────────────────┼───────────────┼─────────────────────────┼───────────────│
│  👤 nombre        │ given_name     │ —                        │ REGEX nombre   │
│  👤 nombre        │ family_name    │ —                        │ REGEX apellido │
│  👤 nombre        │ comercial      │ —                        │ 2-128 chars    │
│  📧 email         │ work, recovery │ billing, legal, home     │ RFC 5321       │
│  📞 telefono      │ mobile, work   │ whatsapp, fax, emergency │ E.164          │
│  📋 id_nacional   │ CI, DNI, CC    │ DUI, CURP, CPF           │ REGEX por país │
│  🏢 tributario    │ NIT, CUIT, RUT │ CNPJ, RFC                │ mod11 + SIN    │
│  📍 direccion     │ fiscal, work   │ home, delivery           │ Coordenadas    │
│  🚗 vehiculo      │ placa, marca   │ modelo, tipo             │ Único          │
│  📦 producto      │ codigo, stock  │ precio_unitario          │ >= 0           │
│                                                                              │
│  📊 60+ definiciones · 8 categorías · 18 display formats                    │
└──────────────────────────────────────────────────────────────────────────────┘
```

Cada fila es cliqueable. Abre el panel de definición del atributo:

```
┌─────────────────────────────────────────┐
│  🏷️ DEFINICIÓN — id_nacional            │
│  ───────────────────────────────        │
│  Categoría:    documento                │
│  Atributo:     id_nacional              │
│  Tipos:        CI, DNI, CC, DUI, CURP, CPF│
│  Obligatorio:  IAL2 (PERSONA)           │
│                                         │
│  ┌─ VALIDACIÓN ────────────────────┐    │
│  │ CI (Bolivia):                    │    │
│  │   REGEX: ^\d{1,8}\s[A-Z]{1,2}$  │    │
│  │   Checksum: mod11                │    │
│  │   API verificación: SEGIP        │    │
│  │                                  │    │
│  │ DNI (Argentina):                 │    │
│  │   REGEX: ^\d{7,8}$               │    │
│  │   API verificación: RENAPER      │    │
│  └──────────────────────────────────┘    │
│                                         │
│  ┌─ DISPLAY ───────────────────────┐    │
│  │ Formato: texto                    │    │
│  │ Enmascarar: últimos 3 dígitos    │    │
│  │ PII: true                        │    │
│  │ atom_code: 5826 🔗               │    │
│  └──────────────────────────────────┘    │
│                                         │
│  ┌─ USADO POR ─────────────────────┐    │
│  │ 37 dominios · 1,247 entidades    │    │
│  │ [Ver entidades que usan este attr]│   │
│  └──────────────────────────────────┘    │
│                                         │
│  [Editar]  [Ver entidades]  [Auditar]   │
└─────────────────────────────────────────┘
```

---

## §17 Consola atomc

El sidebar `🛠️ atomc` abre la **consola del compilador**. No es el editor de roles —
es el historial de compilaciones, el estado del LSP, y las versiones del IR.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🏠 Inicio > 🛠️ atomc                                                        │
├──────────────────────────────────────────────────────────────────────────────┤
│  ┌─ ESTADO DEL COMPILADOR ───────────────────────────────────────────────┐   │
│  │ atomc v2.1.0 · LSP: ✅ Activo en /run/bos/bauth.sock                  │   │
│  │ Última compilación completa: 2026-07-15 14:32 · 12 dominios · 0 errores│   │
│  │ IR version: 47 · privilege_atom_compiled: 1,059 filas                  │   │
│  └────────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─ HISTORIAL DE COMPILACIONES ──────────────────────────────────────────┐   │
│  │ Fecha       │ Dominio │ Resultado            │ Átomos │ Tiempo │ Por   │   │
│  ├─────────────┼─────────┼──────────────────────┼────────┼────────┼───────│   │
│  │ 2026-07-15  │ D1      │ ✅ 0 err, 2 avisos   │ 47     │ 89ms   │ arq   │   │
│  │ 2026-07-15  │ D3      │ ✅ 0 err, 0 avisos   │ 32     │ 67ms   │ arq   │   │
│  │ 2026-07-14  │ D7      │ ⚠ 0 err, 5 avisos   │ 28     │ 102ms  │ arq   │   │
│  │ 2026-07-14  │ D1      │ 🔴 2 err, 3 avisos  │ —      │ 45ms   │ admin │   │
│  │ [Ver detalle] [Ver diff] [Recompilar]                                      │
│  └────────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─ LOG DE atomc ────────────────────────────────────────────────────────┐   │
│  │ [2026-07-15 14:32:01] atomc::compile domain=D1 triggered by arq       │   │
│  │ [2026-07-15 14:32:01] atomc::lexer: 178 tokens in 12ms                │   │
│  │ [2026-07-15 14:32:01] atomc::parser: tree valid in 8ms                │   │
│  │ [2026-07-15 14:32:01] atomc::semantic: 0 errors, 2 warnings in 45ms   │   │
│  │ [2026-07-15 14:32:01] atomc::codegen: 47 atoms in 24ms                │   │
│  │ [2026-07-15 14:32:01] atomc::bitmask: RolBitMask recomputed            │   │
│  └────────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  [Compilar todo]  [Limpiar caché IR]  [Exportar IR]                         │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Acciones disponibles:**
- `[Compilar todo]` — recompila los 12 dominios en secuencia
- `[Limpiar caché IR]` — vacía `privilege_atom_compiled` y fuerza recompilación completa
- `[Exportar IR]` — descarga el IR compilado como JSON
- Cada fila del historial permite `[Ver detalle]` (resultado completo), `[Ver diff]` (comparar con compilación anterior), `[Recompilar]` (repetir)

---

## §18 Reportes

El sidebar `📊 Reportes` muestra KPIs avanzados:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🏠 Inicio > 📊 Reportes                                                     │
├──────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────┐ ┌─────────────────────────┐ ┌────────────────┐  │
│  │ 🔒 CUMPLIMIENTO SoD     │ │ 📋 COBERTURA POLÍTICAS  │ │ 👥 SIN ROL     │  │
│  │                         │ │                         │ │                │  │
│  │ 12 conflictos definidos │ │ 12/12 dominios          │ │ 3 usuarios     │  │
│  │ 0 conflictos activos    │ │ 41 políticas activas    │ │ sin rol        │  │
│  │ 100% cumplimiento       │ │ 178 reglas compiladas   │ │ asignado       │  │
│  │                         │ │                         │ │                │  │
│  │ [Ver matriz SoD]        │ │ [Ver gaps]              │ │ [Ver usuarios] │  │
│  └─────────────────────────┘ └─────────────────────────┘ └────────────────┘  │
│                                                                              │
│  ┌─────────────────────────┐ ┌─────────────────────────┐ ┌────────────────┐  │
│  │ ⏱ PRIVILEGES NO USADOS │ │ 🏢 TENANTS              │ │ 🔑 MFA          │  │
│  │                         │ │                         │ │                │  │
│  │ 23 átomos sin uso       │ │ 1 interno · 2 externos  │ │ 89% usuarios   │  │
│  │ en 90+ días             │ │ 47 entidades totales    │ │ con MFA        │  │
│  │                         │ │                         │ │ activo         │  │
│  │ [Ver átomos]            │ │ [Ver tenants]           │ │ [Ver detalle]  │  │
│  └─────────────────────────┘ └─────────────────────────┘ └────────────────┘  │
│                                                                              │
│  [Exportar PDF]  [Exportar CSV]  [Programar reporte semanal]                 │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Métricas disponibles vía JSON-RPC:**
- `bauth.report.sod()` — cumplimiento SoD
- `bauth.report.coverage()` — cobertura de políticas
- `bauth.report.orphan_users()` — usuarios sin rol
- `bauth.report.unused_privileges(days=90)` — átomos sin uso
- `bauth.report.mfa_adoption()` — adopción MFA

---

## §19 Admin — configuración del sistema

El sidebar `⚙ Admin` contiene configuración que afecta a todo el tenant:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🏠 Inicio > ⚙ Admin                                                         │
├──────────────────────────────────────────────────────────────────────────────┤
│  ┌─ POLÍTICAS DE CONTRASEÑA ─────────────────────────────────────────────┐   │
│  │ Longitud mínima: [8 ▾]    Complejidad: [Alta ▾]                       │   │
│  │ Rotación: [90 días ▾]     Historial: [5 ▾]                            │   │
│  │ [Guardar cambios]                                                       │   │
│  └────────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─ POLÍTICAS MFA ───────────────────────────────────────────────────────┐   │
│  │ MFA obligatorio: [✅]    Métodos: [TOTP ✅] [WebAuthn ✅] [HOTP ⬜]    │   │
│  │ Step-Up para operaciones críticas: [✅]                                │   │
│  │ [Guardar cambios]                                                       │   │
│  └────────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─ APIs EXTERNAS ───────────────────────────────────────────────────────┐   │
│  │ SEGIP:  [✅ Configurado] · Última verificación: 2026-07-15 10:23      │   │
│  │ SIN:    [✅ Configurado] · Última verificación: 2026-07-15 09:15      │   │
│  │ ADSIB:  [⬜ No configurado]                                            │   │
│  │ [Configurar APIs]  [Probar conexión]                                   │   │
│  └────────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─ RED Y SEGURIDAD ─────────────────────────────────────────────────────┐   │
│  │ IPs autorizadas (admin): [192.168.1.0/24] [10.0.0.0/8]               │   │
│  │ Bloqueo tras intentos fallidos: [5 ▾]                                 │   │
│  │ Duración del bloqueo: [15 minutos ▾]                                   │   │
│  │ [Guardar cambios]                                                       │   │
│  └────────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─ SINÓNIMOS DE BÚSQUEDA (D93) ────────────────────────────────────────┐   │
│  │ [Ir a gestión de sinónimos] · 47 sinónimos configurados               │   │
│  │ Última sincronización de archivos .syn: 2026-07-15 14:00              │   │
│  └────────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## §20 Vista de Auditoría

El sidebar `🔍 Auditoría` y los botones `[🔍 Auditoría]` en los paneles abren esta vista:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🏠 Inicio > 🔍 Auditoría                                                     │
├──────────────────────────────────────────────────────────────────────────────┤
│  Entidad: [jperez ▾]  Tipo: [Todos ▾]  Desde: [2024-01-01]  Hasta: [hoy]    │
│  [Buscar]  [Exportar CSV]                                                     │
├──────────────────────────────────────────────────────────────────────────────┤
│  Fecha          │ Actor   │ Entidad  │ Cambio                          │ ctx  │
├─────────────────┼─────────┼──────────┼─────────────────────────────────┼──────│
│ 2026-07-15 10:23│ admin   │ jperez   │ Atributo "telefono" modificado   │ 7a2b │
│                 │         │          │ +591-7-1234567 → +591-7-9999999  │      │
│ 2026-07-14 14:32│ jperez  │ jperez   │ Verificó CI en SEGIP ✅          │ 3c1d │
│ 2026-06-01 09:00│ admin   │ jperez   │ Asignó rol "cajero_basico"       │ 9e4f │
│ 2026-03-15 08:00│ admin   │ jperez   │ Creó la entidad "jperez"         │ 1a2b │
│ 2026-03-15 08:01│ admin   │ jperez   │ Atributo "CI" creado             │ 1a2b │
│                                                                              │
│  📊 47 eventos · Página 1 de 5 · [◀ Anterior] [Siguiente ▶]                │
│                                                                              │
│  Fuente: idn_identidad_atributo_history · idn_rolestpl_atom_history          │
│          idn_user_role_history (audit trigger)                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

Cada fila es expandible para ver el detalle completo del cambio (old_state, new_state, ctx_id completo).

**Si se abrió desde un panel** (ej. `[🔍 Auditoría]` en Actor jperez), los filtros vienen pre-poblados para esa entidad.

---

## §21 Operaciones en lote (bulk)

### 21.1 Selección múltiple en el árbol

| Acción | Comportamiento |
|---|---|
| `Ctrl + clic` | Agrega/quita un nodo de la selección |
| `Shift + clic` | Selecciona el rango entre el primer nodo y el clickeado |
| `Ctrl + A` | Selecciona todos los nodos del nivel actual |
| Clic en zona vacía | Deselecciona todo |

La barra de herramientas muestra un contador: `[3 seleccionados ▾]`.

### 21.2 Acciones en lote — Editor de Identidad

```
[3 Actores seleccionados ▾]
  ├── 🔗 Asignar rol a 3 actores
  ├── 👥 Agregar a USERSET
  ├── 🏷️ Agregar atributo común
  ├── ──────────────
  └── 🗑️ Eliminar 3 actores
```

**Modal de asignación en lote:**

```
┌──────────────────────────────────────────────────────────────┐
│  🔗 ASIGNAR ROL A 3 ACTORES                                  │
│                                                              │
│  Actores: jperez, mgarcia, aruiz                             │
│                                                              │
│  Rol: [vendedor_senior ▾]                                    │
│  Modo: [PERMANENTE ▾]                                        │
│                                                              │
│  ┌─ VALIDACIÓN PREVIA ──────────────────────────────────┐   │
│  │ ✅ jperez  · Sin conflictos                           │   │
│  │ ✅ mgarcia · Sin conflictos                           │   │
│  │ ⚠ aruiz   · Conflicto SoD con rol actual "auditor"   │   │
│  │             [Forzar para este actor]                   │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ⚠ La asignación se aplicará a 3 actores.                    │
│                                                              │
│  [Cancelar]  [Asignar a 2 (saltar conflicto)]  [Forzar todo]│
└──────────────────────────────────────────────────────────────┘
```

### 21.3 Acciones en lote — Editor de Roles

```
[2 Reglas seleccionadas ▾]
  ├── ✅ Validar 2 reglas con atomc
  ├── 📋 Duplicar 2 reglas
  ├── ──────────────
  └── 🗑️ Eliminar 2 reglas
```

### 21.4 Acciones en lote — Vista de Asignaciones

La grilla de asignaciones (§8.3) ya incluye checkboxes por fila. Al seleccionar múltiples:

```
[2 asignaciones seleccionadas ▾]
  ├── 🔄 Cambiar modo a TEMPORAL
  ├── 📅 Cambiar expiración
  └── 🗑️ Revocar 2 asignaciones
```

---

## §22 Mapa anexo → manuales

| Sección | Respalda a |
|---|---|
| §1–§2 (propósito, Composite) | 2.15 §1-§2 · 2.17 §1-§2 · GoF Gamma et al. 1994 |
| §3 (Shell y navegación) | 2.15 §5 · 2.17 §5 · ADR-020 |
| §4 (Landing page) | 2.15 §5 (stats) · 2.17 §5 (stats) |
| §5 (Editor de Identidad) | 1.06 D00 · 1.07 Atributos · 2.15 Motor de Identidad · A.52-A.57 |
| §6 (Editor de Roles) | 1.03 Átomos · 1.04 BitMask · 2.17 Motor de Roles · A.59-A.62 |
| §7 (Flujo de compilación) | 2.17 §6 (pipeline 4 motores) · atomc |
| §8 (Interfaz Usuario↔Rol) | 2.17 §4.3-§4.4 · 1.08 Usuarios · A.51 |
| §9 (Gestión de SETs) | 1.06 D00 (USERSETs) · 2.17 §4.5 |
| §10 (NodeContract) | A.56 §3.6 · A.61 §3.3 |
| §11 (Validación visual + drag) | A.56 §3.6 · A.61 §3.3 |
| §12 (Buscador) | 2.15 §5 · A.56 §4 · A.57 |
| §13 (Estados UI + offline) | ADR-020 (WebSocket) · Patrones UX enterprise |
| §14 (Undo/redo + atajos) | Command Pattern (GoF) · CUA |
| §15 (Menú contextual) | VS Code · Figma · Patrones UX desktop |
| §16 (Vista de Atributos D93) | 1.07 Atributos v2.0 · 2.15 §4 (catálogo de validación) |
| §17 (Consola atomc) | 2.17 §6 · atomc lexer/parser/semantic/codegen |
| §18 (Reportes) | 2.17 §4.7 (auditoría) · BAUTH-CATALOGO-ROLES |
| §19 (Admin) | 1.06 D00 (sinónimos) · A.56 §4.3 (synonym sync) · NIST SP 800-63B |
| §20 (Auditoría) | A.56 §3.5 (history) · A.61 §3.2 (history) · ISO 27001 A.8.15 |
| §21 (Operaciones en lote) | 2.17 §4.3 (assign) · 2.15 §5 (CRUD) |

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 2.2.0 | 2026-07-15 | **Completo.** Agrega: menú contextual por tipo de nodo (§15), semántica del drag crear/mover/copiar (§11.2), flujo Verificar atributo con APIs externas SEGIP/SIN/ADSIB (§5.10), flujo Vincular HW vía bNexus (§5.8), comportamiento offline/reconexión con cola local (§13.2), vista de auditoría completa (§20), operaciones en lote con selección múltiple (§21), vista de atributos D93 (§16), consola atomc con historial (§17), reportes (§18), panel de admin (§19). |
| 2.1.0 | 2026-07-15 | Agregó shell, landing page, selector multi-tenant, 12 paneles de propiedades, flujo de compilación, Usuario↔Rol, SETs, navegación cruzada, NodeContract, estados UI, undo/redo + atajos. |
| 2.0.0 | 2026-07-15 | Separó dashboard unificado en dos editores independientes + Buscador. |
| 1.0.0 | 2026-07-15 | Primera edición (incorrecta). Mezclaba 3 árboles en un solo dashboard. |