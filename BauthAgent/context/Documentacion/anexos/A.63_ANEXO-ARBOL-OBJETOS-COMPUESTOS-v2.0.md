# A.63 — Objetos Compuestos del Árbol AtomLang v2.0
## Dos editores, un patrón — Composite GoF aplicado por separado a los árboles de Identidad y de Roles

**Versión:** 2.0.0
**Fecha:** 2026-07-15
**Tipo de anexo:** A (traslado de SSOT) + C (justificación de decisión técnica)
**Respalda a:** [2.13 AtomLang v2.0](../2.13_MANUAL-ATOMLANG-LENGUAJE-v2.0.md) · [1.06 D00 Identidad v2.1.0](../1.06_MANUAL-D00-IDENTIDAD-v2.0.md) · [2.15 Motor de Identidad v1.2.0](../2.15_MANUAL-MOTOR-IDENTIDAD-v1.0.md) · [2.17 Motor de Roles v1.1.0](../2.17_MANUAL-MOTOR-ROLES-v1.0.md)
**Reemplaza a:** A.63 v1.0.0 (2026-07-15)
**Normas base:** GoF Composite Pattern (Gamma, Helm, Johnson, Vlissides 1994) · OASIS XACML 3.0 §5 · NIST SP 800-162 §4 (PAP) · NIST SP 800-63A (IAL)
**Referencias industria:** WSO2 PAP · ONAP Policy Framework · AWS IAM Console · Okta Admin Console

---

## §0 Corrección de v1.0.0 — qué estaba mal

v1.0.0 cometió cinco errores de diseño:

| Error | Descripción | Corrección en v2.0.0 |
|---|---|---|
| **E1** | Un solo dashboard con pestañas [Roles] [Identidad] [Catálogo] — tres mundos incompatibles en una misma pantalla | **Dos editores independientes.** Cada uno con su propia paleta, sus propios NodeContracts y su propio panel de propiedades. |
| **E2** | Paleta única con objetos mezclados (Dominio + Tenant + Marca en la misma barra) | **Paleta específica por editor.** El editor de Identidad muestra Tenant/bDomain/Actor/Atributo. El editor de Roles muestra Dominio/Bloque/PolicySet/Política/Regla/Guardrail. |
| **E3** | El Catálogo/Buscador tratado como "tercer árbol" con drag & drop | **El Buscador no es un editor.** Es una vista de consulta del Motor de Identidad. No tiene paleta ni drag & drop. No es un árbol — es una grilla de resultados. |
| **E4** | NodeContract único con contratos mezclados de ambos dominios | **Contratos separados.** Editor de Identidad: contratos basados en `idn_identidad_requisito` (IAL1/IAL2). Editor de Roles: contratos basados en reglas XACML (combining_algorithm, verb_id, effect). |
| **E5** | Un solo Panel de Propiedades para objetos incompatibles (Regla vs Actor) | **Panel de propiedades específico.** Seleccionar una Regla muestra target/condition/effect. Seleccionar un Actor muestra nombre/tipo/atributos/dominios/roles. |

**Principio rector:** Identidad y Roles comparten el patrón Composite y la estructura EAV. Pero **son dos productos diferentes con usuarios, flujos de trabajo y vocabulario distintos.** Un admin de RRHH que registra empleados no necesita ver reglas XACML. Un arquitecto de seguridad que diseña políticas no necesita ver la jerarquía de sucursales.

---

## §1 Propósito

Definir la jerarquía de **objetos compuestos** para los DOS editores de árbol de bAuth usando
el patrón **Composite** (Gamma et al. 1994):

1. **Editor de Identidad (D00):** registro y gestión de entidades y sus atributos
2. **Editor de Roles (privilege_atom):** diseño y gestión de políticas de autorización

Ambos comparten el patrón Composite y la validación por NodeContract. Pero cada uno
tiene su propia paleta, sus propios contratos, su propio panel de propiedades y su
propio flujo de trabajo. **No se mezclan en la misma pantalla.**

El **Buscador** no es un editor. Es una vista de consulta integrada en el dashboard de
Identidad. No tiene árbol, no tiene paleta, no tiene drag & drop.

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

## §3 Editor de Identidad — árbol de entidades

### 3.1 Jerarquía

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

### 3.2 Objetos de la paleta

| Objeto | Tipo GoF | Icono | Se suelta en | Significado |
|---|---|---|---|---|
| **Tenant** | Composite | 🏢 | Raíz | Organización raíz. Puede ser empresa, persona con múltiples roles, o entidad multi-propósito. |
| **bDomain** | Composite | 📁 | Tenant | Dominio de negocio: empresa, hogar, equipo, proyecto, familia. |
| **bSubDomain** | Composite | 📂 | bDomain | Subdivisión: sucursal, departamento, oficina, área. |
| **Pos** | Composite | 📍 | bSubDomain | Punto lógico: caja, puerta, escritorio, vehículo, servidor. |
| **Actor** | Leaf | 👤 | Pos, bSubDomain, bDomain | Entidad hoja: persona, bot, dispositivo, servicio. |
| **Atributo** | Leaf | 🏷️ | Cualquier entidad | Propiedad: nombre, email, CI, NIT, placa, serial. |

### 3.3 Contratos del Editor de Identidad

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

### 3.4 Mockup del Editor de Identidad

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  bAuth · Editor de Identidad                         🎨 Tema │ 🔌 │ 👤 admin │
├────────────┬─────────────────────────────────────────────────────────────────┤
│ PALETA     │ ÁRBOL DE ENTIDADES                          🔍 [Buscar entidad] │
│            ├─────────────────────────────────────────────────────────────────┤
│ 🏢 Tenant  │                                                                 │
│ 📁 bDomain │  🏢 SKULL (interno)                               [＋ bDomain]  │
│ 📂 bSubDom │    │  🏷️ slug: skull                                           │
│ 📍 Pos     │    │  🏷️ is_internal: true                                     │
│ 👤 Actor   │    │                                                            │
│ 🏷️ Atributo│    📁 SKULL-CORP (empresa)                       [＋ bSubDomain]│
│            │      │  🏷️ tipo: sociedad_comercial                             │
│            │      │  🏷️ NIT: 12345678901234 · ✅ Verificado SIN             │
│            │      │  🏷️ Email: legal@skull.com                               │
│            │      │                                                          │
│            │      📂 Norte (sucursal)                           [＋ Pos]      │
│            │        │  🏷️ tipo: oficina_comercial                            │
│            │        │  🏷️ Dirección: Calle Comercio #100                     │
│            │        │                                                        │
│            │        📍 CAJA-01 (punto_de_venta)                [＋ Actor]     │
│            │          │  🏷️ tipo: caja                                       │
│            │          │  🏷️ Serial: TERM-2024-001                            │
│            │          │                                                      │
│            │          👤 jperez (PERSONA) · Nivel IAL2 ✅                   │
│            │            │  🏷️ CI: 1234567 LP · ✅ Verificado SEGIP           │
│            │            │  🏷️ Email: jperez@skull.com                        │
│            │            │  🏷️ Teléfono: +591-7-1234567                       │
│            │            │  🏷️ Cargo: vendedor_senior                         │
│            │            │  🔗 Roles: [vendedor_senior] [cajero_basico]       │
│            │                                                                 │
│            │  📁 Juan Pérez (persona_física)                                 │
│            │    └── (expandir para ver hogar, oficina, etc.)                 │
│            │                                                                 │
│            └──────────────────────────────────────────────[＋]──[🗑️]──[🔍]──│
│  📊 1 tenant · 2 bDomains · 1 bSub · 1 Pos · 1 Actor · 12 atributos        │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 3.5 Panel de Propiedades — Actor seleccionado

Al hacer clic en `👤 jperez`, el panel lateral muestra:

```
┌─────────────────────────────────────────┐
│  👤 ACTOR                               │
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
│  │                                   │   │
│  │ [＋ Agregar atributo]              │   │
│  └───────────────────────────────────┘   │
│                                         │
│  ┌─ DOMINIOS ───────────────────────┐   │
│  │ ✅ civil      · 4 atributos       │   │
│  │ ✅ laboral    · 3 atributos       │   │
│  │ ✅ autenticacion · 2 atributos    │   │
│  │ ⬜ cliente    · sin atributos     │   │
│  │ ⬜ financiero · sin atributos     │   │
│  └───────────────────────────────────┘   │
│                                         │
│  ┌─ ROLES ASIGNADOS ────────────────┐   │
│  │ 🔗 vendedor_senior · PERMANENTE   │   │
│  │ 🔗 cajero_basico · PERMANENTE     │   │
│  │ [＋ Asignar rol]                   │   │
│  └───────────────────────────────────┘   │
│                                         │
│  [Guardar]  [Cancelar]  [🔍 Auditoría]  │
└─────────────────────────────────────────┘
```

### 3.6 Panel de Propiedades — Atributo seleccionado

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
│                                         │
│  Verificación: ✅ Verificado             │
│    Fuente: SEGIP                        │
│    Fecha:  2024-03-15                   │
│    Expira: 2026-03-15                   │
│                                         │
│  ┌─ HISTORIAL ──────────────────────┐   │
│  │ 2024-03-15 · Creado · admin       │   │
│  │ 2024-03-15 · Verificado · SEGIP   │   │
│  └───────────────────────────────────┘   │
│                                         │
│  [Editar]  [Verificar]  [Eliminar]      │
└─────────────────────────────────────────┘
```

---

## §4 Editor de Roles — árbol de políticas

### 4.1 Jerarquía

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

### 4.2 Objetos de la paleta

| Objeto | Tipo GoF | Icono | Se suelta en | Significado |
|---|---|---|---|---|
| **Dominio** | Composite | 🟦 | Raíz | Los 12 dominios de autorización (D1 ACCESO, D3 FINANCIERO, D6 PRIVACIDAD...). |
| **Bloque** | Composite | 🟩 | Dominio | Agrupación funcional (B4 Autenticación, B6 Zonas, B7 PrivilegeEngine...). |
| **PolicySet** | Composite | 🟨 | Dominio, Bloque, PolicySet | Contenedor de políticas y sub-PolicySets. Aplica combining_algorithm. |
| **Política** | Composite | 🟧 | Dominio, Bloque, PolicySet | Política concreta con combining_algorithm y application_id. Contiene Reglas. |
| **Regla** | Leaf | 🟥 | Política, PolicySet (solo con contrato) | Regla XACML: target + condition + effect. Unidad mínima de decisión. |
| **Guardrail** | Leaf | 🟪 | PolicySet, Dominio | Regla global sin application_id. Aplica a todo el dominio o PolicySet. |

### 4.3 Contratos del Editor de Roles

| Objeto | allowedChildren | requiredAttrs | minChildren | maxChildren |
|---|---|---|---|---|
| **Dominio D1-D12** | bloque, policyset, politica, guardrail | combining_algorithm, domain_name | 1 | null |
| **Bloque B0-B19** | policyset, politica | nombre | 1 | null |
| **PolicySet** | policyset, politica, guardrail | combining_algorithm | 1 | null |
| **Política** | regla | combining_algorithm, application_id | 1 | null |
| **Regla** | — (target+condition+effect son PARTE de la regla) | verb_id, target, effect | — | — |
| **Guardrail** | — | verb_id, effect | — | — |

**Diferencia clave con Identidad:** en Roles, los atributos obligatorios son propiedades
XACML (`combining_algorithm`, `verb_id`, `effect`), no atributos EAV de entidad. El contrato
valida la estructura de la política, no la completitud de una entidad.

### 4.4 Mockup del Editor de Roles

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  bAuth · Editor de Políticas                          🎨 Tema │ 🔌 │ 👤 arq  │
├────────────┬─────────────────────────────────────────────────────────────────┤
│ PALETA     │ ÁRBOL DE POLÍTICAS                          🔍 [Buscar política] │
│            ├─────────────────────────────────────────────────────────────────┤
│ 🟦 Dominio │                                                                 │
│ 🟩 Bloque  │  🟦 D1 · ACCESO LÓGICO                     [＋ Bloque/PolicySet] │
│ 🟨 PolSet  │    ⚙ combining_algorithm: deny-overrides                         │
│ 🟧 Política│    │                                               ──────────────│
│ 🟥 Regla   │    🟩 B4 · Autenticación                                     │
│ 🟪 Guardr. │      ⚙ combining_algorithm: deny-overrides (hereda de D1)       │
│            │      │                                               ────────────│
│            │      🟧 password_policy                         [＋ Regla]       │
│            │        ⚙ combining_algorithm: deny-overrides                     │
│            │        ⚙ application_id: bauth.password_policy                  │
│            │        │                                               ──────────│
│            │        🟥 longitud_mínima                ✅ COMPLETA            │
│            │        🟥 historial_contraseñas          ✅ COMPLETA            │
│            │        🟥 complejidad_caracteres         ⚠ FALTA EFFECT         │
│            │                                                                │
│            │    🟩 B7 · PrivilegeEngine                                     │
│            │      ⚙ combining_algorithm: deny-overrides                      │
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
│  📊 12 dominios · 41 políticas · 178 reglas activas · 2 advertencias        │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 4.5 Panel de Propiedades — Regla seleccionada

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
│  │ Resource:  [credit_limit ▾]      │    │
│  │ Verbo:     [read ▾]              │    │
│  │ Env:       [any ▾]               │    │
│  └──────────────────────────────────┘    │
│                                         │
│  ┌─ CONDITION ──────────────────────┐   │
│  │ Property:  [user.role ▾]          │   │
│  │ Operator:  [not_in ▾]             │   │
│  │ Value:     [SET(admin_financiero)│   │
│  └──────────────────────────────────┘    │
│                                         │
│  ┌─ EFFECT ⚠ REQUERIDO ────────────┐   │
│  │ Decision:  [Seleccionar... ▾]     │   │
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
│  [Guardar]  [Validar]  [Compilar]       │
└─────────────────────────────────────────┘
```

### 4.6 Panel de Propiedades — Dominio seleccionado

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
│  [Editar]  [Compilar todo]  [Auditar]   │
└─────────────────────────────────────────┘
```

---

## §5 El Buscador NO es un editor de árbol

El Buscador de entidades (antes "tercer árbol" o "Catálogo de Autopartes" en v1.0.0) es una
**vista de consulta** del Motor de Identidad. No es un editor. No tiene paleta. No tiene
drag & drop. No tiene NodeContract.

### 5.1 Por qué no es un editor

- **No crea entidades.** Para crear un farol, se usa el Editor de Identidad: `bauthctl identidad create`.
- **No modifica atributos.** Para cambiar el precio de un farol, se usa el Editor de Identidad.
- **Solo consulta.** El Buscador ejecuta `bauth.identidad.search()` y muestra resultados.

### 5.2 Dónde vive

El Buscador es una **vista integrada en el dashboard de Identidad**, accesible desde la
barra de búsqueda superior (`🔍 [Buscar entidad]` en el mockup §3.4). También es accesible
como vista independiente desde el menú lateral. Pero nunca como "tercer editor de árbol."

### 5.3 Mockup del Buscador (vista de resultados)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  bAuth · Buscador de Entidades                      🎨 Tema │ 🔌 │ 👤 operador│
├──────────────────────────────────────────────────────────────────────────────┤
│  🔍 foco del izq tyt carina 92                           [Buscar] [Filtros ▾] │
├──────────────────────────────────────────────────────────────────────────────┤
│  Filtros activos: Tipo=FAROL · Tenant=Toyota · Compatible=Carina 92          │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ 🔩 Farol Delantero Izquierdo · TOYOTA · 212-1112-L          ★★★★★   │    │
│  │    Compatible: Carina 92-97 · Corona 92-97 · Corolla 93-97           │    │
│  │    Fabricante: DEPO (Taiwán) · Código: 212-1112-L                    │    │
│  │    Posición: Delantero Izquierdo · Sistema: Iluminación              │    │
│  │    ▸ 3 proveedores · Stock total: 85u · Desde $42                    │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ 🔩 Farol Delantero Izquierdo · BOSCH · B-9876-L              ★★★★☆  │    │
│  │    Compatible: Carina 92-97 · Corona 92-97                           │    │
│  │    Fabricante: BOSCH (Alemania) · Código: B-9876-L                   │    │
│  │    Posición: Delantero Izquierdo · Sistema: Iluminación              │    │
│  │    ▸ 1 proveedor · Stock total: 10u · Desde $65                      │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ 🔩 Farol Delantero Izquierdo · HELLA · H-CAR-FD               ★★★☆☆ │    │
│  │    Compatible: Carina 92-97                                           │    │
│  │    Fabricante: HELLA (Alemania) · Código: H-CAR-FD                    │    │
│  │    Posición: Delantero Izquierdo · Sistema: Iluminación              │    │
│  │    ▸ 2 proveedores · Stock total: 5u · Desde $78                      │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  📊 3 resultados · <50ms · Buscado en 165M atributos                        │
│  🔗 [Ver en árbol de identidad]  [Exportar CSV]  [Compartir]                │
└──────────────────────────────────────────────────────────────────────────────┘
```

Cada resultado es una **entidad** (`idn_identidad_entidad`) con sus **atributos**
(`idn_identidad_atributo`). El Buscador consulta con GIN (fuzzy + full-text) y muestra
resultados planos. Nada de árboles. Nada de drag & drop.

---

## §6 Cómo el constructor visual usa el contrato (común a ambos editores)

Cada vez que el usuario arrastra un objeto, el constructor visual consulta el `NodeContract`
del objeto padre para determinar:

1. **¿Se puede soltar aquí?** → `allowedChildren` del padre debe contener el tipo del hijo
2. **¿Faltan atributos obligatorios?** → `requiredAttrs` del nodo deben estar completos
3. **¿Tiene demasiados hijos?** → `maxChildren` no debe excederse
4. **¿Qué ícono/color mostrar?** → `icon` y el tipo determinan el estilo visual

```
Usuario arrastra "Política" sobre "PolicySet"
  → PolicySet.NodeContract.allowedChildren contiene "politica"?
  → SÍ → zona de drop se ilumina en verde
  → NO → zona de drop se mantiene gris (imposible soltar)

Usuario arrastra "Regla" sobre "Dominio"
  → Dominio.NodeContract.allowedChildren contiene "regla"?
  → NO → Dominio no acepta Reglas directamente
  → La UI no habilita la zona de drop
```

### 6.1 Diferencias de validación entre editores

| | Editor de Identidad | Editor de Roles |
|---|---|---|
| **Qué valida** | Completitud mínima de entidad (IAL1/IAL2) | Estructura XACML (combining_algorithm, verb_id, effect) |
| **Fuente del contrato** | `idn_identidad_requisito` (tabla SQL) | NodeContract (metadatos del tipo de nodo) |
| **Atributos obligatorios** | `nombre`, `email`, `CI` según tipo de entidad y nivel | `combining_algorithm`, `verb_id`, `effect` según tipo de nodo |
| **Validación post-construcción** | Motor de Identidad (`validate` + `verify`) | atomc (`atomc check`) |
| **Error visible** | "PERSONA nivel 1 requiere: nombre, email. Falta: email." | "Regla campo_credit_limit_readonly: falta effect." |

---

## §7 Mapa anexo → manuales

| Sección | Respalda a |
|---|---|
| §1 (propósito) | 2.15 §1-§2 · 2.17 §1-§2 |
| §2 (Composite Pattern) | GoF Gamma et al. 1994 |
| §3 (Editor de Identidad) | 1.06 D00 · 1.07 Atributos · 2.15 Motor de Identidad · A.52-A.57 |
| §4 (Editor de Roles) | 1.03 Átomos · 1.04 BitMask · 2.17 Motor de Roles · A.59-A.62 |
| §5 (Buscador) | 2.15 §5 (search) · A.56 §4 (búsquedas) · A.57 (rendimiento) |
| §6 (validación visual) | A.56 §3.6 (idn_identidad_requisito) · A.61 §3.3 (idn_rolestpl_requisito) |

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 2.0.0 | 2026-07-15 | **Corrección mayor.** v1.0.0 mezclaba Identidad, Roles y Catálogo en un solo dashboard con paleta unificada. v2.0.0 los separa: Editor de Identidad (entidades + atributos) y Editor de Roles (políticas + reglas) son productos independientes con su propia paleta, contratos, panel de propiedades y mockups. El Buscador deja de ser un "tercer árbol" y se redefine como vista de consulta del Motor de Identidad. |
| 1.0.0 | 2026-07-15 | Primera edición (incorrecta). Mezclaba los 3 árboles, NodeContract unificado, mockup con pestañas. |