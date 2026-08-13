# A.79 — Reglas de Implementación del Editor de Árbol PAP (Dashboard bAuth)
## Validación de nodos, layout y navegación en el árbol de políticas AtomLang

**Versión:** 1.3.0  
**Fecha:** 2026-08-07  
**Tipo de anexo:** C — Justificación de decisión técnica de implementación  
**Respalda a:** [2.13 MANUAL-ATOMLANG-LENGUAJE v2.0](../2.13_MANUAL-ATOMLANG-LENGUAJE-v2.0.md) · [2.14 MANUAL-COMPOSICION-ARBOL v1.0](../2.14_MANUAL-COMPOSICION-ARBOL-v1.0.md) · [A.47 CLASIFICACION-COMPOSICION-ARBOL](./A.47_ANEXO-CLASIFICACION-COMPOSICION-ARBOL-v1.0.md)  
**Fuente de verdad de dependencia:** `bauth.idn_roles_template` · `bauth.idn_policy_node_type`  
**Stack desktop:** Flutter · tf_shadcn_flutter · Riverpod 3.x

---

## §1 Propósito

Este anexo captura las reglas de implementación del editor visual del árbol de políticas AtomLang en el dashboard bAuth (PAP — Policy Administration Point). Su objetivo es que estas decisiones no se pierdan entre sesiones y sirvan de referencia para el desarrollador desktop.

Las reglas aquí definidas se irán refinando durante la implementación — este documento es vivo.

---

## §2 Layout de la vista `v-rt:pol`

La vista tiene estructura fija de tres franjas verticales:

```
┌──────────────────────────────────────────────────────────┐
│  TOP                                                     │
│  contexto: nodo seleccionado en el árbol                 │
│  ┌─────────────────────────────────────────────────────┐ │
│  │  menú selector:  [ Roles ]  [ Usuarios ]  [ Otros ] │ │
│  └─────────────────────────────────────────────────────┘ │
├──────────────────────────────────────────────────────────┤
│  BODY  (IndexedStack — un widget visible a la vez)       │
│                                                          │
│  ── cuando TOP = Roles ────────────────────────────────  │
│  │  Sección 1: grupos de roles   (barra de botones)    │ │
│  │  Sección 2: propiedades       (formulario)          │ │
│                                                          │
│  ── cuando TOP = Usuarios ─────────────────────────────  │
│  │  Sección 1: grupos de usuarios (barra de botones)   │ │
│  │  Sección 2: propiedades        (formulario)         │ │
│                                                          │
│  ── cuando TOP = Otros ────────────────────────────────  │
│  │  Sección 1: otros tipos de nodo (barra de botones)  │ │
│  │  Sección 2: propiedades         (formulario)        │ │
│                                                          │
├──────────────────────────────────────────────────────────┤
│  BOTTOM  ← guardar / cancelar / limpiar                  │
└──────────────────────────────────────────────────────────┘
```

**Regla UI-00:** el menú selector del TOP activa uno de los tres widgets del BODY y desactiva los otros dos. Patrón Flutter: `IndexedStack` — los tres widgets viven en memoria, solo uno es visible. El índice activo lo controla un provider Riverpod.

---

## §3 Estrategia de validación — Decisión: Opción B

### §3.1 Descripción de la opción elegida

**Seleccionar primero, agregar después.**

1. El usuario selecciona un nodo en el árbol de políticas.
2. La **Sección 1** (grupos) filtra y muestra únicamente los tipos de nodo que pueden ser hijos válidos del nodo seleccionado — los demás aparecen deshabilitados o se ocultan.
3. El usuario hace clic en un tipo habilitado → la **Sección 2** muestra el formulario de atributos para ese tipo.
4. El usuario rellena los campos y confirma → el nuevo nodo se inserta como hijo del nodo seleccionado en la BD.

### §3.2 Por qué se eligió la Opción B sobre la Opción A (drag & drop)

| Criterio | Opción A (drag & drop) | Opción B (selección + filtro) |
|---|---|---|
| Feedback anticipado | No — el usuario descubre la restricción al soltar | Sí — los botones deshabilitados lo comunican antes de actuar |
| Complejidad de implementación | Alta (estado de drag, validación de drop target en tiempo real, indicadores visuales) | Baja (función pura de filtrado) |
| Fuente de verdad | Árbol de dependencia consultado en tiempo de drag | Árbol de dependencia consultado al seleccionar nodo |
| Lógica reutilizable | Dispersa en handlers de drag/drop | Centralizada en `childrenPermitidos(node_type)` |
| Mantenibilidad | Cada cambio al árbol de dependencia requiere tocar los handlers | Solo requiere actualizar el mapa de hijos válidos |

**Regla UI-01:** la validación de jerarquía se implementa exclusivamente mediante el filtrado de grupos (Opción B). No se implementa drag & drop en la primera iteración.

---

## §4 Función `childrenPermitidos` — Mapa de hijos válidos

Esta función es la única fuente de verdad de qué tipos de nodo pueden crearse bajo un nodo dado. Se deriva directamente del árbol de dependencia documentado en 2.14 §3 y A.47 §2.

```
childrenPermitidos(node_type) → Set<node_type>

tenant       → { domain }
domain       → { block }
block        → { policy, policy_set, object, list, attribute, enum, event }
policy       → { rule }
policy_set   → { policy }
rule         → { atom }
atom         → ∅  (nodo hoja — ningún hijo permitido)
object       → ∅  (nodo hoja)
list         → { object, attribute, enum }
attribute    → ∅  (nodo hoja)
enum         → ∅  (nodo hoja)
event        → ∅  (nodo hoja)
```

**Regla UI-02:** si `childrenPermitidos(node_type)` devuelve `∅`, la Sección 1 muestra todos los botones deshabilitados y un mensaje: _"Este nodo no admite elementos hijos."_

**Regla UI-03:** si no hay ningún nodo seleccionado en el árbol, todos los botones de la Sección 1 están deshabilitados hasta que el usuario seleccione un nodo.

---

## §5 Los tres widgets del BODY

Cada widget tiene la misma estructura interna: **Sección 1** (barra de grupos — botones) + **Sección 2** (panel de propiedades — formulario). Lo que varía entre widgets es el conjunto de tipos de nodo que exponen y el contexto de sus propiedades.

### §5.1 Widget Roles — dimensión `subject.rol`

Cubre los tipos de nodo ligados a la dimensión de roles (`dim.ROL`). El `condition_expr` puede referenciar roles individuales o sets de roles de D98.

#### §5.1.1 Layout interno — vertical con splitter resizable

```
Widget Roles
┌─────────────────────────────────────────┐
│  BLOQUE A — Árbol de grupos             │
│                                         │
│  ▼ Política        (policy)             │
│    ▼ Regla         (rule)               │
│      ▷ Átomo       (atom)               │
│  ▷ PolicySet       (policy_set)         │
│                                         │
├━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┤  ← splitter resizable
│  BLOQUE B — Atributos                   │
│  ┌─────────────────┬───────────────┐   │
│  │  Atrib. grupo   │  Atrib. comun │   │  ← tabs
│  └─────────────────┴───────────────┘   │
│  (contenido del tab activo)             │
└─────────────────────────────────────────┘
```

**Orientación:** vertical — Bloque A arriba, Bloque B abajo.  
**Splitter:** resizable entre los dos bloques. El usuario puede ampliar el árbol o el formulario según necesite. Altura mínima de cada bloque: 80 px.  
**Implementación Flutter:** `ResizablePanel` de tf_shadcn_flutter con dos paneles en eje vertical.

#### §5.1.2 Bloque A — Árbol de grupos

El árbol muestra la jerarquía de tipos de nodo válidos para la dimensión Roles. Cada nodo del árbol es **seleccionable**; la selección activa/cambia el contenido del Bloque B.

| Nodo en árbol | node_type | Habilitado cuando el nodo del árbol principal es |
|---|---|---|
| Política | `policy` | `block` |
| ▷ Regla (hijo de Política) | `rule` | `policy` |
| ▷▷ Átomo (hijo de Regla) | `atom` | `rule` |
| PolicySet | `policy_set` | `block` |
| ▷ Política (hijo de PolicySet) | `policy` | `policy_set` |

Los nodos que no son hijos válidos del nodo seleccionado en el árbol principal aparecen deshabilitados (ver §4 `childrenPermitidos`).

#### §5.1.3 Bloque B — Panel de atributos (dos tabs)

**Tab 1 — Atributos del grupo** (específicos del `node_type` seleccionado en Bloque A):

| node_type | Campo | Widget |
|---|---|---|
| `policy` | — | solo atributos comunes |
| `policy_set` | — | solo atributos comunes |
| `rule` | `effect` | toggle Permit / Deny |
| `rule` | `condition_expr.subject.rol` | kind: ROL\|SET\|UNSET\|ANY · id: selector rol o set D98 |
| `atom` | `atom_position` | solo lectura — asignado por sistema |
| `atom` | `verb_id` | selector desde `bauth.privilege_verb` |
| `atom` | `effect` | toggle Permit / Deny |
| `atom` | `condition_expr.subject.rol` | kind: ROL\|SET\|UNSET\|ANY · id: selector rol o set D98 |

**Tab 2 — Atributos comunes** (iguales para cualquier `node_type`):

| Campo | Widget |
|---|---|
| `label` (jsonb es/en) | campo doble es / en |
| `alias` | input text — solo snake_case |
| `description` | textarea |
| `is_active` | toggle switch |
| `valid_from` | date picker |
| `valid_until` | date picker |

---

### §5.2 Widget Usuarios — dimensión `subject.user`

Cubre los tipos de nodo que definen reglas ligadas a la dimensión de usuarios (`dim.USER`). El `condition_expr` de estos nodos puede referenciar usuarios individuales o sets de usuarios de D94.

| Botón (Sección 1) | node_type | Habilitado cuando el nodo seleccionado es |
|---|---|---|
| Política | `policy` | `block` |
| PolicySet | `policy_set` | `block` |
| Regla | `rule` | `policy` |
| Átomo | `atom` | `rule` |

**Propiedades específicas de Sección 2 (además de los atributos comunes):**

| node_type | Campo | Detalle |
|---|---|---|
| `rule` | `effect` | toggle Permit / Deny |
| `rule` | `condition_expr.subject.user` | kind: USER\|USERSET\|USERUNSET\|ANY · id: selector usuario o set D94 |
| `atom` | `atom_position` | solo lectura — asignado por sistema |
| `atom` | `verb_id` | selector desde `bauth.privilege_verb` |
| `atom` | `effect` | toggle Permit / Deny |
| `atom` | `condition_expr.subject.user` | kind: USER\|USERSET\|USERUNSET\|ANY · id: selector usuario o set D94 |

---

### §5.3 Widget Otros — tipos estructurales

Cubre los tipos de nodo que no producen Decision (Permit/Deny) pero forman la estructura del árbol: contenedores de datos, listas, enumeraciones, eventos CAEP.

| Botón (Sección 1) | node_type | Habilitado cuando el nodo seleccionado es |
|---|---|---|
| Bloque | `block` | `domain` |
| Objeto | `object` | `block` · `list` |
| Lista | `list` | `block` |
| Atributo | `attribute` | `block` · `list` |
| Enum | `enum` | `block` · `list` |
| Evento | `event` | `block` |

**Propiedades específicas de Sección 2 (además de los atributos comunes):**

| node_type | Campo | Detalle |
|---|---|---|
| `block` | `block_code` | selector restringido B01–B10 |
| `attribute` | `value` | input text |
| `enum` | `value` | input text |
| `enum` | `options` | editor de lista (agregar / quitar valores) |
| `object` | — | solo atributos comunes |
| `list` | — | solo atributos comunes |
| `event` | — | solo atributos comunes |

---

### §5.4 Estados de botón (aplica a los tres widgets)

| Estado | Condición | Visual |
|---|---|---|
| **Habilitado** | `node_type ∈ childrenPermitidos(seleccionado)` | color primario, clicable |
| **Deshabilitado** | `node_type ∉ childrenPermitidos(seleccionado)` | opaco, no clicable |
| **Activo** | botón seleccionado en la Sección 1 del widget activo | borde/fondo destacado |

**Regla UI-04:** los botones no se ocultan — se deshabilitan. El usuario siempre ve el catálogo completo de su widget y entiende qué no está permitido en el nodo actual.

---

## §6 Sección 2 — Panel de propiedades

El panel de propiedades muestra los campos del tipo de nodo seleccionado en la Sección 1. Se organiza en dos sub-bloques:

### §6.1 Sub-bloque A — Atributos comunes (siempre visibles)

Estos campos aplican a todo `node_type` sin excepción:

| Campo | Tipo | Widget sugerido |
|---|---|---|
| `label` (jsonb es/en) | texto multiidioma | campo doble es/en |
| `alias` | texto corto | input text |
| `description` | texto libre | textarea |
| `is_active` | booleano | toggle switch |
| `valid_from` | fecha | date picker |
| `valid_until` | fecha | date picker |

Los campos `id`, `tenant_id`, `parent_id`, `node_type`, `depth`, `path`, `sort_order`, `order_idx`, `version`, `created_at`, `updated_at` son gestionados por el sistema — no se muestran en el formulario de creación.

### §6.2 Sub-bloque B — Atributos específicos por tipo (condicionales)

Se muestran solo cuando el botón del tipo correspondiente está activo:

| node_type | Campo extra | Tipo | Widget sugerido |
|---|---|---|---|
| `domain` | `domain_number` | entero | input numérico (solo lectura — asignado por sistema) |
| `block` | `block_code` | texto corto | selector B01–B10 |
| `rule` | `effect` | booleano | toggle Permit / Deny |
| `rule` | `condition_expr` | jsonb | editor visual de condición (ver §7) |
| `atom` | `atom_position` | bigint | solo lectura — asignado por sistema |
| `atom` | `verb_id` | FK | selector desplegable desde `bauth.privilege_verb` |
| `atom` | `effect` | booleano | toggle Permit / Deny |
| `atom` | `condition_expr` | jsonb | editor visual de condición (ver §7) |
| `attribute` | `value` | texto | input text |
| `enum` | `value` | texto | input text |
| `enum` | `options` | text[] | editor de lista (agregar / quitar valores) |

**Regla UI-05:** el campo `atom_position` es asignado automáticamente por el sistema al momento de persistir — nunca lo edita el usuario.

**Regla UI-06:** el campo `block_code` es un selector restringido (B01–B10), no un input libre.

---

## §7 Editor visual de `condition_expr` (jsonb)

El campo `condition_expr` es un JSONB con estructura fija derivada de XACML 3.0. El editor visual debe generar ese JSON sin que el usuario lo escriba manualmente.

### §7.1 Estructura de `condition_expr`

```json
{
  "subject": {
    "rol":  { "kind": "ROL|SET|UNSET|ANY", "id": "<uuid|null>" },
    "user": { "kind": "USER|USERSET|USERUNSET|ANY", "id": "<uuid|null>" }
  },
  "resource": "<resource_id>",
  "environment": [
    { "property_id": "<id>", "operator": "<op>", "value": "<val>" }
  ],
  "apply": {
    "function_id": "<fn>",
    "attribute_designator": {
      "category": "subject|resource|action|environment",
      "attribute_id": "<id>",
      "data_type": "<type>",
      "must_be_present": true
    },
    "attribute_value": { "value": "<val>", "data_type": "<type>" }
  }
}
```

### §7.2 Reglas del editor de condición

**Regla UI-07:** los selectores de `kind` para `subject.rol` solo permiten los valores `ROL`, `SET`, `UNSET`, `ANY`. Si se elige `ROL`, el campo `id` pasa a ser un selector de rol. Si se elige `SET` o `UNSET`, el campo `id` es un selector de set de D98. Si se elige `ANY`, el campo `id` desaparece.

**Regla UI-08:** los selectores de `kind` para `subject.user` solo permiten `USER`, `USERSET`, `USERUNSET`, `ANY` con la misma lógica.

**Regla UI-09:** las dos dimensiones del subject (ROL y USER) son independientes — el usuario puede configurar ambas al mismo tiempo.

**Regla UI-10:** los operadores válidos para `environment` son: `==`, `!=`, `>`, `<`, `>=`, `<=`, `IN`, `NOT_IN`, `BETWEEN`. El editor los presenta como selector, no como input libre.

---

## §8 Reglas generales de implementación

**Regla UI-11:** la función `childrenPermitidos` es una constante en el frontend — no se consulta a la BD para determinar qué hijos son válidos. El árbol de dependencia es estático y conocido en compilación.

**Regla UI-12:** el formulario de Sección 2 se limpia al cambiar de botón activo en Sección 1.

**Regla UI-13:** el formulario de Sección 2 se limpia al cambiar el nodo seleccionado en el árbol.

**Regla UI-14:** ningún campo de identificación (`alias`, `path`) acepta espacios — solo `snake_case`.

**Regla UI-15:** D00, D98 y D99 están **EN SUSPENSO** — si el nodo seleccionado es de uno de esos dominios, la Sección 1 muestra un aviso: _"Este dominio tiene estructura propia. Edición no disponible en esta versión."_

---

## §9 Pendientes de definición (pulir durante implementación)

| ID | Pendiente |
|---|---|
| P-01 | Definir widget concreto para el editor visual de `condition_expr` (formulario por campos vs. editor JSON asistido) |
| P-02 | Definir comportamiento al editar un nodo existente (vs. crear nuevo) — ¿mismo formulario? |
| P-03 | Definir cómo se navega el árbol (panel lateral, árbol colapsable, breadcrumb) |
| P-04 | Definir validaciones de `valid_from` / `valid_until` (rango coherente, solapamientos) |
| P-05 | Definir si `name` (jsonb) se muestra en el formulario además de `label` (jsonb) |

---

## §10 Empaquetado y distribución (Windows)

El dashboard se desarrolla en Linux y se compila localmente en Windows. El flujo de empaquetado es el siguiente:

### Rutina de empaquetado (Linux — lado servidor)

Desde `BauthAgent/src/` se genera un tar.gz con los fuentes Flutter estructurado bajo el prefijo `desktop/`:

```bash
cd /opt/skull/orquestador/proyectos/SBOS/BauthAgent/src
tar -czf /tmp/bauth_desktop.tar.gz \
  desktop/lib/ \
  desktop/pubspec.yaml \
  desktop/pubspec.lock \
  desktop/analysis_options.yaml \
  desktop/windows/
```

El archivo de destino es siempre `/tmp/bauth_desktop.tar.gz` (nombre fijo — no incluye SHA).

### Rutina de compilación y ejecución (Windows — lado cliente)

```powershell
cd $env:USERPROFILE
Remove-Item -Recurse -Force desktop -ErrorAction SilentlyContinue
scp skull@144.91.76.130:/tmp/bauth_desktop.tar.gz .
tar xzf bauth_desktop.tar.gz
cd desktop
flutter pub get
flutter run -d windows
```

### Reglas

| Regla | Descripción |
|---|---|
| **DEV-01** | El tar.gz contiene **solo fuentes** — no binarios ni carpeta `build/`. |
| **DEV-02** | La estructura interna del tar.gz **siempre empieza con `desktop/`** para que `cd desktop` funcione tras extracción. |
| **DEV-03** | El nombre del archivo en el servidor es siempre `/tmp/bauth_desktop.tar.gz` (fijo). El SCP no necesita conocer el SHA. |
| **DEV-04** | Antes de empaquetar, correr `flutter analyze --no-fatal-infos` y confirmar **0 issues**. |
| **DEV-05** | `assets/` se incluye solo si el proyecto tiene assets declarados en `pubspec.yaml`. Verificar antes de agregar. |

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.3.0 | 2026-08-07 | §10 agregado: rutina de empaquetado Linux + compilación Windows, 5 reglas DEV-01..DEV-05. |
| 1.2.0 | 2026-08-07 | §5.1 Widget Roles detallado: layout vertical con splitter resizable (ResizablePanel), Bloque A = árbol de grupos navegable, Bloque B = dos tabs (Atrib. grupo / Atrib. comunes). Altura mínima 80 px por bloque. |
| 1.1.0 | 2026-08-07 | §2 layout actualizado: TOP con menú selector [Roles\|Usuarios\|Otros] + BODY como IndexedStack de tres widgets. §5 reestructurado en §5.1 Widget Roles (dim.ROL + D98), §5.2 Widget Usuarios (dim.USER + D94), §5.3 Widget Otros (block/object/list/attribute/enum/event). Regla UI-00 agregada (IndexedStack + provider). |
| 1.0.0 | 2026-08-07 | Primera edición. Layout v-rt:pol, estrategia validación Opción B, mapa childrenPermitidos, atributos comunes/específicos por nodo, reglas UI-01..UI-15, 5 pendientes. |
