# A.63 — Objetos Compuestos del Árbol AtomLang
## Patrón Composite GoF aplicado al constructor visual de los 3 árboles de bAuth: Identidad, Roles y Buscador

**Versión:** 1.0.0
**Fecha:** 2026-07-15
**Tipo de anexo:** A (traslado de SSOT) + C (justificación de decisión técnica)
**Respalda a:** [A.49 Constructor Visual](../anexos/A.49_ANEXO-EDITOR-VISUAL-ATOMLANG-v1.0.md) · [2.13 AtomLang v2.0](../2.13_MANUAL-ATOMLANG-LENGUAJE-v2.0.md) · [1.06 D00 v2.1.0](../1.06_MANUAL-D00-IDENTIDAD-v2.0.md) · [2.17 Motor de Roles](../2.17_MANUAL-MOTOR-ROLES-v1.0.md)
**Normas base:** GoF Composite Pattern (Gamma, Helm, Johnson, Vlissides 1994) · OASIS XACML 3.0 §5 · NIST SP 800-162 §4 (PAP)
**Referencias industria:** WSO2 PAP · ONAP Policy Framework · Cisco Securent Resource Tree · US Patent US7512965 (Policy builder)

---

## §1 Propósito

Definir la jerarquía de **objetos compuestos** del árbol AtomLang usando el patrón **Composite**
(Gamma et al. 1994). Un solo modelo OOP sirve para los 3 árboles de bAuth: Identidad (D00),
Roles (privilege_atom) y Buscador (catálogo de autopartes). El patrón Composite garantiza
que cada nodo sabe qué hijos puede tener, qué operaciones permite, y qué atributos necesita
— eliminando errores de construcción manual.

---

## §2 Composite Pattern — El fundamento OOP

El patrón **Composite** (GoF) es la solución canónica para jerarquías parte-todo. Define:

| Participante | Rol en OOP | Rol en AtomLang |
|---|---|---|
| **Component** | Interfaz base del árbol | `NodoTemplate` — todo nodo del árbol |
| **Leaf** | Nodo sin hijos | `Atributo`, `Verbo`, `Decision`, `Regla` |
| **Composite** | Nodo con hijos | `Dominio`, `Política`, `PolicySet`, `bDomain`, `Entidad` |

```
Component
  ↑             ↑
Leaf        Composite (0..* hijos)
  │              │
  │           contiene Leaves y Composites
  │
  └── ningún hijo permitido
```

**Regla de oro del Composite:** el Cliente trata Leaves y Composites de manera uniforme.
En el dashboard, arrastrar una `Regla` (Leaf) o una `Política` (Composite) usa el mismo
código de drag & drop. La diferencia es qué hijos acepta cada uno.

---

## §3 Los 3 árboles y su jerarquía de objetos

### 3.1 Árbol de Identidad (D00)

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

Cada nivel del árbol D00 es un `Composite` que acepta tipos específicos de hijos:

| Objeto | Tipo GoF | Hijos válidos | Se suelta en |
|---|---|---|---|
| **Tenant** | Composite | bDomain, Atributo | Raíz |
| **bDomain** | Composite | bSubDomain, Actor, Atributo | Tenant |
| **bSubDomain** | Composite | Pos, Actor, Atributo | bDomain |
| **Pos** | Composite | Actor, Atributo | bSubDomain |
| **Actor** | Leaf | Atributo | Pos |
| **Atributo** | Leaf | — | Cualquier entidad |

### 3.2 Árbol de Roles (privilege_atom)

```
Componente base (NodoTemplate)
  │
  ├── Composite: Dominio D1      ── hijos: Bloque, PolicySet, Política
  ├──── Composite: Bloque B4     ── hijos: Política, PolicySet
  ├────── Composite: PolicySet   ── hijos: PolicySet, Política
  ├──────── Composite: Política  ── hijos: Regla, combining_algorithm
  ├────────── Leaf: Regla        ── hijos: target, condition, effect (incluidos)
  └────────── Leaf: Guardrail    ── hijos: target, condition, effect (application_id=null)
```

| Objeto | Tipo GoF | Hijos válidos | Se suelta en |
|---|---|---|---|
| **Dominio** | Composite | Bloque, PolicySet, Política | Raíz |
| **Bloque** | Composite | Política, PolicySet | Dominio |
| **PolicySet** | Composite | PolicySet, Política, Regla (Guardrail) | Dominio, PolicySet |
| **Política** | Composite | Regla | PolicySet, Bloque, Zona |
| **Regla** | Leaf | target, condition, effect (ya incluidos) | Política |
| **Guardrail** | Leaf | target, condition, effect (application_id=null) | PolicySet, Dominio |

### 3.3 Árbol del Buscador (Catálogo de Autopartes)

```
Componente base (NodoTemplate)
  │
  ├── Composite: Tennant Toyota    ── hijos: Catálogo, Sección
  ├──── Composite: Catálogo        ── hijos: ModeloAuto, Sección
  ├────── Composite: ModeloAuto    ── hijos: Sección (motor, frenos...)
  ├──────── Composite: Sección     ── hijos: Sistema (iluminación, eléctrico...)
  ├────────── Composite: Sistema   ── hijos: Posición, Marca
  ├──────────── Leaf: Posición     ── atributos: farol_del_der
  └──────────── Leaf: Marca        ── atributos: DEPO, BOSCH
```

---

## §4 El contrato `NodeContract` — validación de estructura

Cada nodo tiene un **contrato** que define: qué hijos acepta, qué atributos requiere,
y qué valores son válidos. Esto se implementa como metadatos del `NodeContract`, no
como reglas dispersas en código.

```
NodeContract {
  nodeType: "dominio" | "politica" | "regla" | "bdomain" | ...
  allowedChildren: ["bloque", "policyset", "politica"]   ← qué hijos SOLO puede tener
  requiredAttrs: ["combining_algorithm"]                   ← atributos OBLIGATORIOS
  optionalAttrs: ["target"]                                ← atributos OPCIONALES
  maxChildren: null | int                                  ← límite de hijos
  minChildren: 0 | int                                     ← mínimo de hijos
  connectingPorts: ["superior", "inferior"]               ← dónde se conecta
  icon: "🏢" | "📁" | "📄"                                ← representación visual
}
```

### 4.1 Contratos del Árbol de Roles

| Objeto | allowedChildren | requiredAttrs | maxChildren | minChildren |
|---|---|---|---|---|
| **Dominio D1** | bloque, policyset, politica | combining_algorithm | null | 1 |
| **Bloque B4** | politica, policyset | nombre | null | 1 |
| **PolicySet** | policyset, politica, regla | combining_algorithm | null | 1 |
| **Política** | regla | combining_algorithm, application_id | null | 1 |
| **Regla** | — (target+condition+effect incluidos) | verb_id, target, effect | 3 | 3 |
| **Guardrail** | — | verb_id, effect | 2 | 2 |

### 4.2 Contratos del Árbol de Identidad

| Objeto | allowedChildren | requiredAttrs | maxChildren | minChildren |
|---|---|---|---|---|
| **Tenant** | bdomain, atributo | nombre, slug, is_internal | null | 1 |
| **bDomain** | bsubdomain, actor, atributo | nombre, tipo | null | 1 |
| **bSubDomain** | pos, actor, atributo | nombre, tipo | null | 1 |
| **Pos** | actor, atributo | nombre, tipo | null | 1 |
| **Actor** | atributo | nombre, tipo | null | 0 |
| **Atributo** | — | category, attr_key | 0 | 1 |

---

## §5 Mockup visual de la interfaz de edición

### 5.1 Vista General — el dashboard con 3 árboles

```
┌────────────────────────────────────────────────────────────────────────────┐
│  bAuth · Identity Control Plane                    🎨 Tema │ 🔌 │ 👤 jperez │
├──────────┬─────────────────────────────────────────────────────────────────┤
│ PALETA   │ ÁRBOL [Roles] [Identidad] [Catálogo]            🔍 [Buscar...] │
│          ├─────────────────────────────────────────────────────────────────┤
│ 🟦 Dom.  │                                                                │
│ 🟩 Bloque│  🟦 D1 · ACCESO LÓGICO                         [POLICYSET]     │
│ 🟨 PolSe │    ⚙ combining_algorithm: deny-overrides        B0-B19:7 │ At:48│
│ 🟧 Polít │    │                                               ──────────── │
│ 🟥 Regla │    🟩 B4 · Autenticación                        [POLICYSET]     │
│ 🟪 Guard │      ⚙ combining_algorithm: deny-overrides                       │
│          │      │                                               ──────────── │
│ 🟫 Obj.  │      🟧 password_policy                           [POLICY]       │
│ 📄 List. │        ⚙ combining_algorithm: deny-overrides      Capa B4       │
│ 🏷️ Atrib │        │                                               ────────── │
│          │        🟥 longitud_mínima                          [REGLA]       │
│          │          ├── 🎯 target: ANY                        verb:configure│
│          │          ├── 🔍 condition: len>=@bauth.param      ────────────── │
│          │          └── ✅ effect: Permit { audit: on }                     │
│          │                                                                │
│          │        🟥 historial_contraseñas                                 │
│          │          ├── 🎯 target: ANY                                     │
│          │          └── ✅ effect: Deny { audit: on }                      │
│          │                                                                │
│          │    🟩 B6 · Zonas de negocio                                     │
│          │      ⚙ combining_algorithm: deny-overrides                      │
│          │      │                                               ─────────── │
│          │      🟨 Zona Financiera Alta Seguridad                           │
│          │        │                                               ───────── │
│          │        🟧 payment_approvals                                     │
│          │          ⚙ first-applicable                                     │
│          │          │                                               ────────│
│          │          🟥 pago_aprobacion_tier1              ⚠ FALTA CONDITION│
│          │          🟥 pago_sod_check                                       │
│          │                                                                │
│          │    🟩 B7 · PrivilegeEngine                                      │
│          │      └── 🟧 field_restrictions                                  │
│          │            ⚙ deny-overrides                                     │
│          │            │                                                    │
│          │            🟥 campo_margin_oculto               ✅ COMPLETO      │
│          │            🟥 campo_cost_price_oculto           ✅ COMPLETO      │
│          │            🟥 campo_credit_limit_readonly       ⚠ SIN EFFECT    │
│          └──────────────────────────────────────────────────────────────────│
│  📊 Ver KPIs   ✅ 12 dominios · 45 políticas · 128 reglas · 3 errores     │
└────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Vista Identidad — entidades del sistema

```
┌─────────────────────────────────────────────────────────────────────┐
│ PALETA     │ ÁRBOL [Roles] [Identidad] [Catálogo]                   │
│            ├─────────────────────────────────────────────────────────┤
│ 🏢 Tenant  │  🏢 SKULL (interno)                    [DOMINIO]        │
│ 📁 bDomain │    │                                                    │
│ 📁 bSubDom │    📁 SKULL-CORP (empresa)              [BDOMAIN]       │
│ 📍 Pos     │      │  🏷️ NIT: 12345678901234          ──────────────  │
│ 👤 Actor   │      │  🏷️ Email: legal@skull.com                      │
│ 🏷️ Atrib   │      │                                                  │
│ 🔗 Asig.Rol│      📁 Norte (sucursal)                 [BSUBDOMAIN]   │
│            │        │  🏷️ Dir: Calle Comercio #100                   │
│            │        │                                                  │
│            │        📍 CAJA-01 (caja)                  [POS]          │
│            │          │  🏷️ Serie: TERM-2024-001                      │
│            │          │                                                  │
│            │          👤 jperez (HUMAN)                  [ACTOR]      │
│            │            │  🏷️ CI: 1234567 LP            ─────────── │
│            │            │  Rol: vendedor_senior                        │
│            │            └── 🏷️ Email: jperez@skull.com               │
│            │                                                  ────── │
│            │  📁 Juan Pérez (persona)                   [BDOMAIN]     │
│            │    📁 Oficina (oficina)                    [BSUBDOMAIN]  │
│            │      📍 Desarrollo (punto_virtual)         [POS]         │
│            │        👤 jperez (HUMAN)                   [ACTOR]      │
│            │                                                  ────── │
│            │  📁 Casa-Juan (hogar)                      [BDOMAIN]     │
│            │    📁 Principal (familiar)                  [BSUBDOMAIN]  │
│            │      📍 Puerta-Entrada (puerta, OSDP)      [POS]         │
│            │                                                  ────── │
│ 📊 3 tenants · 7 bDomains · 5 bSubs · 6 Pos · 4 Actores ✅          │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.3 Vista Catálogo — autopartes

```
┌─────────────────────────────────────────────────────────────────────┐
│ PALETA     │ ÁRBOL [Roles] [Identidad] [Catálogo]                   │
│            ├─────────────────────────────────────────────────────────┤
│ 🚗 Marca  │  🚗 TOYOTA                                [MARCA]       │
│ 📋 Modelo │    │                                                    │
│ 🔧 Sección│    📋 Carina 92-97                         [MODELO]      │
│ ⚙ Sistema │      │  1.8L · T190 · 1992-1997            ─────────────│
│ 🔩 Pieza  │      │                                                    │
│ 🏷️ Atrib  │      🔧 Motor                               [SECCIÓN]   │
│            │        ⚙ Admisión                                       │
│            │        ⚙ Inyección/Combustible                          │
│            │        ⚙ Distribución                                   │
│            │        ⚙ Refrigeración                                   │
│            │                                                        │
│            │      🔧 Frenos                             [SECCIÓN]   │
│            │        ⚙ Delanteros                         [SISTEMA]  │
│            │          🔩 Pastillas DEPO 212-FREN-001     [PIECE]     │
│            │            🏷️ Precio: $45 · Stock: ANDINA 50u           │
│            │          🔩 Pastillas TRW TRW-FCAR-001      [PIECE]     │
│            │            🏷️ Precio: $52 · Stock: ANDINA 30u           │
│            │          🔩 Disco BREMBO BD-CAR-001         [PIECE]     │
│            │            🏷️ Precio: $95 · Stock: ANDINA 10u           │
│            │                                                    ──── │
│            │      🔧 Eléctrico                                        │
│            │        ⚙ Iluminación                         [SISTEMA]  │
│            │          🔩 Farol DEPO 212-1112-L            [PIECE]     │
│            │          🔩 Farol BOSCH B-9876-L             [PIECE]     │
│            │          🔩 Farol HELLA H-CAR-FD             [PIECE]     │
│            │                                                    ──── │
│  🚗 TOYOTA · 5 secciones · 8 sistemas · 46 partes compatibles      │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.4 Panel de Propiedades — detalle del nodo seleccionado

Al hacer clic en un nodo, el panel derecho muestra sus propiedades editables:

```
┌────────────────────────────────────────────────┐
│  🟥 REGLA                                       │
│  Nombre: pago_aprobacion_tier1                  │
│                                                 │
│  ┌─ TARGET ─────────────────────────────────┐   │
│  │ Subject:   [SET(vendedores) ▾]            │   │
│  │ Resource:  [payment.transaction ▾]        │   │
│  │ Verbo:     [approve ▾]                    │   │
│  │ Environment: [horario_laboral ▾]          │   │
│  └──────────────────────────────────────────┘   │
│                                                 │
│  ┌─ CONDITION ──────────────────────────────┐   │
│  │ Property: [transaction.amount ▾]          │   │
│  │ Operator: [<= ▾]                          │   │
│  │ Value:    [@bauth_config_param. ▾]        │   │
│  └──────────────────────────────────────────┘   │
│                                                 │
│  ┌─ EFFECT ────────────────────────────────┐   │
│  │ Decision:  [Permit ▾]                    │   │
│  │ Obligation: { audit: on }                │   │
│  │ Advice:    [Tier 1 approval              │   │
│  └──────────────────────────────────────────┘   │
│                                                 │
│  🔍 Validar │  atomc: 0 errores, 1 aviso   │
│  📋 Contrato: 3 de 3 hijos completos ✅         │
│  onlyChildren: [target, condition, effect]     │
│  requiredAttrs: [verb_id, target, effect] ✅    │
└────────────────────────────────────────────────┘
```

### 5.5 Cómo el constructor visual usa el contrato

Cada vez que el usuario arrastra un objeto, el constructor visual consulta el `NodeContract`
del objeto para determinar:

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

**Esto elimina la mala concepción manual de los árboles.** Si la UI solo permite acciones
válidas según el contrato, no hay forma de crear un árbol estructuralmente incorrecto.

---

## §6 Contratos de consulta — el buscador también tiene árbol

El Buscador (catálogo de autopartes) sigue el mismo patrón. Los contratos determinan
qué se puede buscar y cómo se estructura el resultado del catálogo.

| Objeto | allowedChildren | requiredAttrs |
|---|---|---|
| **ModeloAuto** | Marca, Sección | modelo, año, motor |
| **Sección** | Sección, Sistema | nombre |
| **Sistema** | Posición | codigo_sistema |
| **Posición** | Marca | tipo_posicion (delantero, trasero) |
| **Marca (fabricante)** | — | nombre, codigo_producto, precio |

---

## §7 Mapa anexo → manuales

| Sección | Respalda a |
|---|---|
| §2 (Composite Pattern) | GoF Gamma et al. 1994 |
| §3 (3 árboles) | A.49 §2 · 2.13 §4 · 1.06 §4 · 2.17 §4 |
| §4 (NodeContract) | A.49 §3 (reglas de drop) · A.56 §3.6 (idn_identidad_requisito) |
| §5 (validación visual) | A.49 §5 (validación post-construcción) |
| §6 (buscador) | A.55 §2-§5 |

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-15 | Primera edición. Diseño OOP de objetos compuestos para el árbol visual AtomLang usando el patrón Composite de GoF. 3 árboles: Identidad, Roles, Buscador. NodeContract para validación estructural en drag & drop. Elimina la mala concepción manual del árbol. |
