# AtomLang — Estructura Jerárquica de Nodos

> **Estado:** Borrador de trabajo (v0.1)
> **Contexto:** bAuth / SBOS — Sistema de control de acceso ABAC (XACML 3.0 / NIST SP 800-162)
> **Relacionado:** T-170 (privilege_atom_grant), bos_atom_audit, bauth-reactor (CDC/WAL)

---

## 1. Propósito

Este documento define la jerarquía canónica de nodos de AtomLang —
`Domain / Bloque / (PolicySet | Policy) / Rule / Atom` — distinguiendo
en cada nivel entre tres tipos de nodo:

---

### [GRUPO]

**Nodo contenedor.** Un GRUPO no tiene valor propio — el valor reside
siempre en sus ATRIBUTOS hijos. Su función es agrupar, organizar y dar
semántica a los nodos que contiene.

**Regla estructural de AtomLang (ver §1.1):**
> Todo nodo que tenga hijos — atributos u otros grupos — es un GRUPO.

Un GRUPO puede ser de tres subtipos según el rol de sus hijos en la evaluación:

| Subtipo | Cuándo aplica | Ejemplos |
|---|---|---|
| **Estructural** | Sus hijos son metadata fija; no participan en la decisión del PDP. | `identidad`, `encoding_fisico`, `DOMAIN`, `BLOQUE` |
| **Evaluable** | Sus hijos son leídos por `atomc` para tomar la decisión PERMIT/DENY. | `TARGET`, `CONDITION`, `EFFECT` |
| **Reactivo** | Sus hijos definen procesos ejecutados *después* de que la decisión ya fue tomada. | `obligation/advice`, `auditoría WORM` |

Un GRUPO evaluable como `EFFECT` contiene tanto su atributo de valor (`effect: PERMIT|DENY`)
como sus sub-grupos reactivos (`obligation/advice`, `auditoría WORM`). El GRUPO es el
contenedor; los atributos hijos son quienes participan en la evaluación.

---

### [ATRIBUTO]

**Nodo hoja.** Tiene un valor concreto tipado (string, enum, uuid, expresión booleana,
slug[], etc.). **Nunca tiene hijos.** Si un nodo necesita contener sub-nodos, deja de ser
un atributo y se convierte en GRUPO.

Es lo que `atomc` lee, valida y emite en el árbol compilado para alimentar al PDP.

---

### [PROCESO]

**Efecto secundario ejecutado por `atomc` en runtime** como consecuencia del valor de
`EFFECT`. No participa en el cálculo de la decisión — ocurre *después* de que la decisión
ya fue tomada. En bAuth son llamadas reales: escrituras en `bos_atom_audit`,
notificaciones vía bNotify, revocación de sesiones, etc.

---

**Regla de oro:** solo tres GRUPOs evaluables participan en la decisión PERMIT/DENY
dentro de un Atom — `TARGET`, `CONDITION` y `EFFECT`. Todo lo que ocurre después de que
`EFFECT` toma su valor es **reactivo**: o bien procesos condicionados al resultado
(`obligation/advice`, activados solo si `effect == fulfill_on`), o bien procesos
incondicionales que ejecutan sin importar el resultado (`auditoría WORM`). El encoding
físico no es reactivo — es metadata estructural fija.

**Patrón ECA (Event-Condition-Action):**
- **Event** — la request llega al PDP (`atomc`)
- **Condition** — los atributos hijos de los GRUPOs `TARGET` y `CONDITION` se evalúan
- **Action** — el atributo `effect` dentro del GRUPO `EFFECT` produce PERMIT | DENY, y dispara los reactivos

---

## 1.1 Regla estructural de AtomLang vs. conceptos de las normas internacionales

### La regla estructural de AtomLang

> **Todo nodo que tenga hijos — ya sean atributos u otros grupos — es un `[GRUPO]`.**
> **Un `[ATRIBUTO]` es siempre una hoja: no tiene hijos.**

Esta regla es derivable y universal. No requiere justificación caso por caso. Si al construir
el árbol un nodo necesita contener sub-nodos, eso lo convierte en `[GRUPO]`
independientemente de cómo lo defina cualquier norma externa.

### Por qué esto difiere de XACML 3.0 y NIST SP 800-162

Las normas internacionales definen algunos conceptos como atributos escalares que en AtomLang
resultan ser grupos porque necesitan contener sub-nodos:

| Concepto | Norma (XACML 3.0 / NIST SP 800-162) | AtomLang | Por qué es GRUPO en AtomLang |
|---|---|---|---|
| **Effect** | Atributo escalar: `PERMIT` \| `DENY` | `[GRUPO]` | Contiene el atributo de valor (`effect`) + los sub-grupos reactivos post-decisión (`obligation/advice`, `auditoría WORM`). |
| **Condition** | Atributo escalar: expresión booleana | `[GRUPO]` | Contiene el atributo de expresión (`condition`) + metadatos del evaluador (comportamiento ante atributo faltante). |

EFFECT y CONDITION no son casos especiales — son simplemente dos nodos donde la norma define
un escalar pero AtomLang necesita estructura con hijos para representar el concepto completo.
La regla los convierte en grupos de forma automática, sin excepción.

### La regla de conformidad normativa

La distinción AtomLang ↔ norma **no viola** las normas internacionales porque opera en planos
distintos del sistema:

```
Árbol FUENTE / ATOMLANG                    Árbol COMPILADO  (output de atomc)
──────────────────────────────             ──────────────────────────────────
🔶 EFFECT [GRUPO]                     →    "Effect": "PERMIT"
   ├─ effect: "PERMIT"                      (atributo escalar — conforme a XACML 3.0)
   ├─ 🔶 obligation/advice            →    "Obligations": [{ "fulfill_on": "PERMIT", … }]
   └─ 🔶 auditoría WORM               →    (interno — escritura WORM en bos_atom_audit)

🔶 CONDITION [GRUPO]                  →    "Condition": "ctx.device.managed == true"
   └─ condition: "ctx.device.managed == true"   (expresión escalar — conforme a XACML 3.0)
```

- **Árbol FUENTE** (`.atm.yaml`) y **árbol ATOMLANG** (AST interno de `atomc`): usan los
  GRUPOs. Son internos al sistema — la norma no los evalúa.
- **Árbol COMPILADO** (`.atm.json`): `atomc` aplana los GRUPOs al formato escalar que exige
  la norma. Este árbol es el que consume el PDP, y cumple la norma al 100%.

> **Regla de oro:** toda auditoría de conformidad normativa evalúa el **árbol compilado**,
> no el árbol fuente. AtomLang es el lenguaje del editor y el compilador; la norma es el
> contrato del output.

---

## 2. Árbol jerárquico completo

```
🔷 DOMAIN [GRUPO — namespace organizacional]
│   ├─ id                    [ATRIBUTO]
│   ├─ nombre                [ATRIBUTO]
│   ├─ owner                 [ATRIBUTO]
│   ├─ classification        [ATRIBUTO]
│   └─ version                [ATRIBUTO]
│
└── 🔷 BLOQUE [GRUPO — subdivisión funcional]
    │   ├─ id                    [ATRIBUTO]
    │   ├─ domain_ref            [ATRIBUTO — FK]
    │   └─ resource_type         [ATRIBUTO]
    │
    └── 🔷 POLICYSET / POLICY [GRUPO — nodo de combinación XACML]
        │   ├─ id                        [ATRIBUTO]
        │   ├─ type                      [ATRIBUTO] (PolicySet | Policy)
        │   ├─ combining_algorithm       [ATRIBUTO] (aggregate-strictest)
        │   ├─ status                    [ATRIBUTO] (draft|active|deprecated)
        │   ├─ version                   [ATRIBUTO]
        │   │
        │   └─ 🔶 target [GRUPO — heredable/refinable, NO evaluable aquí]
        │       ├─ 🔶 subject [GRUPO — default heredable]
        │       │   ├─ set/unset/userset/userunset  [ATRIBUTO — default, normalmente vacíos = ANY]
        │       ├─ resource      [ATRIBUTO — default]
        │       ├─ action        [ATRIBUTO — default]
        │       └─ environment   [ATRIBUTO — default]
        │
        └── 🔷 RULE [GRUPO — agrupa variantes de un mismo verbo]
            │   ├─ id                        [ATRIBUTO]
            │   ├─ policy_ref                [ATRIBUTO — FK]
            │   ├─ description               [ATRIBUTO]
            │   ├─ rule_combining_algorithm  [ATRIBUTO — solo si >1 Atom hijo]
            │   │
            │   └─ 🔶 target [GRUPO — refina el heredado, NO evaluable aquí]
            │       ├─ 🔶 subject [GRUPO — override opcional]
            │       │   ├─ set/unset/userset/userunset  [ATRIBUTO — override opcional]
            │       ├─ resource      [ATRIBUTO — override opcional]
            │       ├─ action        [ATRIBUTO — override opcional]
            │       └─ environment   [ATRIBUTO — override opcional]
            │
            └── 🔷 ATOM [GRUPO — hoja, pero contiene los únicos nodos EVALUABLES]
                │
                ├─ 🔶 identidad [GRUPO — ESTRUCTURAL, no depende de la evaluación]
                │   ├─ id                [ATRIBUTO]
                │   ├─ domain/bloque/verbo [ATRIBUTO — naming dNN.bloque.verbo]
                │   ├─ depends_on        [ATRIBUTO — árbol de dependencias]
                │   └─ version           [ATRIBUTO]
                │
                ├─ 🔶 TARGET [GRUPO — evaluable ✅ — fase 1: ¿aplica esta regla?]
                │   ├─ 🔶 subject [GRUPO — inclusión/exclusión de rol y usuario]
                │   │   ├─ set          [ATRIBUTO] — roles/sets INCLUIDOS
                │   │   ├─ unset        [ATRIBUTO] — roles/sets EXCLUIDOS
                │   │   ├─ userset      [ATRIBUTO] — usuarios específicos INCLUIDOS
                │   │   └─ userunset    [ATRIBUTO] — usuarios específicos EXCLUIDOS
                │   ├─ resource          [ATRIBUTO]
                │   ├─ action            [ATRIBUTO] (= verbo)
                │   └─ environment       [ATRIBUTO] (device/location/schedule/trust)
                │
                ├─ 🔶 CONDITION [GRUPO — evaluable ✅ — fase 2: ¿se cumple la condición?]
                │   └─ condition [ATRIBUTO] — expresión booleana; null = sin condición adicional
                │
                ├─ 🔶 EFFECT [GRUPO — evaluable ✅ — fase 3: agrupador del discriminante + reactivos]
                │   ├─ effect [ATRIBUTO] — PERMIT|DENY (discriminante declarado; «Effect» escalar de la norma)
                │   │
                │   │   ◄─ todo lo que sigue es REACTIVO: se ejecuta DESPUÉS
                │   │      de que effect tomó su valor. No participa en la
                │   │      decisión — la decisión ya está tomada aquí.
                │   │
                │   ├─ 🔶 obligation/advice [GRUPO — REACTIVO CONDICIONAL]
                │   │   │   Solo se ejecuta si EFFECT == fulfill_on.
                │   │   │   Son PROCESOS reales en bAuth: llamadas a servicios,
                │   │   │   escrituras, notificaciones. Vinculantes (obligation)
                │   │   │   o informativos (advice).
                │   │   │
                │   │   ├─ fulfill_on   [ATRIBUTO] (PERMIT|DENY) — gate de disparo:
                │   │   │               esta obligation/advice solo se activa si
                │   │   │               EFFECT tomó este valor específico
                │   │   ├─ obligation   [PROCESO] — ejecutado si EFFECT == fulfill_on
                │   │   │               (ej. EFFECT=DENY → obligation: revocar_sesion)
                │   │   │               (ej. EFFECT=PERMIT → obligation: log_acceso_exitoso)
                │   │   └─ advice       [PROCESO — no vinculante] — sugerencia al PEP
                │   │                   (ej. EFFECT=PERMIT → advice: mostrar_aviso_politica)
                │   │
                │   └─ 🔶 auditoría WORM [GRUPO — REACTIVO INCONDICIONAL]
                │           Se ejecuta SIEMPRE, sin importar el valor de EFFECT.
                │           Son PROCESOS de escritura inmutable (T-170):
                │           el registro de un DENY es tan crítico como el de un PERMIT
                │           para detección de intentos de acceso no autorizado.
                │
                │           ├─ [PROCESO] escribir_registro_worm →
                │           │           ├─ created_at / created_by  [ATRIBUTO]
                │           │           ├─ checksum / hash           [ATRIBUTO — integridad]
                │           │           └─ cdc_source                [ATRIBUTO — WAL lsn]
                │           └─ [PROCESO] emitir_evento_cdc →
                │                       (notifica bauth-reactor vía WAL para CDC downstream)
                │
                └─ 🔶 encoding físico [GRUPO — ESTRUCTURAL, independiente de EFFECT]
                        Metadata de identidad fija. Existe antes de cualquier evaluación
                        y no cambia según el resultado. No es reactivo.
                        ├─ bit_position  [ATRIBUTO]
                        └─ role_mask     [ATRIBUTO — one-hot N-bit]
```

---

## 2.1 Árbol con datos de ejemplo (instancia real)

Mismo árbol que la sección 2, pero con valores concretos para el caso
`d03.facturas.aprobar` — de Domain hasta Atom, con dos variantes de
Rule para mostrar cómo conviven distintos Atoms bajo la misma Rule.

```
🔷 DOMAIN
│   ├─ id: "D03"
│   ├─ nombre: "Facturación"
│   ├─ owner: "equipo-finanzas"
│   ├─ classification: "financiero"
│   └─ version: "3.2.0"
│
└── 🔷 BLOQUE
    │   ├─ id: "facturas"
    │   ├─ domain_ref: "D03"
    │   └─ resource_type: "factura"
    │
    └── 🔷 POLICY  ("d03.facturas")
        │   ├─ id: "pol.d03.facturas"
        │   ├─ type: "Policy"
        │   ├─ combining_algorithm: "aggregate-strictest"
        │   ├─ status: "active"
        │   ├─ version: "1.4.0"
        │   │
        │   └─ 🔶 target (heredable por defecto)
        │       ├─ subject: ANY
        │       ├─ resource: "factura"
        │       ├─ action: ANY
        │       └─ environment: {}
        │
        ├── 🔷 RULE  ("d03.facturas.aprobar")
        │   │   ├─ id: "rule.d03.facturas.aprobar"
        │   │   ├─ policy_ref: "pol.d03.facturas"
        │   │   ├─ description: "Aprobación de facturas por supervisor"
        │   │   ├─ rule_combining_algorithm: "aggregate-strictest"
        │   │   │
        │   │   └─ 🔶 target (refina el heredado)
        │   │       ├─ subject: (sin override, hereda)
        │   │       ├─ resource: "factura"
        │   │       ├─ action: "aprobar"
        │   │       └─ environment: (sin override, hereda)
        │   │
        │   ├── 🔷 ATOM  #1 (caso estándar)
        │   │   ├─ 🔶 identidad
        │   │   │   ├─ id: "d03.facturas.aprobar"
        │   │   │   ├─ domain: "D03" · bloque: "facturas" · verbo: "aprobar"
        │   │   │   ├─ depends_on: ["d03.facturas.leer"]
        │   │   │   └─ version: "1.0.0"
        │   │   │
        │   │   ├─ 🔶 TARGET
        │   │   │   ├─ 🔶 subject
        │   │   │   │   ├─ set: ["d98.set.supervisor_finanzas"]
        │   │   │   │   ├─ unset: []
        │   │   │   │   ├─ userset: []
        │   │   │   │   └─ userunset: ["usr.jgomez"]   ← baja de acceso puntual
        │   │   │   ├─ resource: "factura"
        │   │   │   ├─ action: "aprobar"
        │   │   │   └─ environment: { trust_level_min: 3 }
        │   │   │
        │   │   ├─ CONDITION:
        │   │   │     "context.device.managed == true AND
        │   │   │      context.schedule.within_business_hours == true"
        │   │   │
        │   │   ├─ EFFECT: PERMIT   ◄─ discriminante calculado
        │   │   │   │
        │   │   │   ├─ 🔶 obligation/advice  [REACTIVO CONDICIONAL]
        │   │   │   │   ├─ fulfill_on: PERMIT    ← solo dispara si EFFECT == PERMIT
        │   │   │   │   ├─ obligation: [PROCESO] log_acceso_exitoso → bos_atom_audit
        │   │   │   │   └─ advice: (ninguno)
        │   │   │   │
        │   │   │   └─ 🔶 auditoría WORM  [REACTIVO INCONDICIONAL]
        │   │   │       ├─ [PROCESO] escribir_registro_worm:
        │   │   │       │   ├─ created_at: "2026-06-12T08:30:00Z"
        │   │   │       │   ├─ created_by: "ivan.skull"
        │   │   │       │   ├─ checksum: "sha256:9f1a...c02e"
        │   │   │       │   └─ cdc_source: "wal-lsn:0/1A2B3C4"
        │   │   │       └─ [PROCESO] emitir_evento_cdc → bauth-reactor
        │   │   │
        │   │   └─ 🔶 encoding físico  [ESTRUCTURAL]
        │   │       ├─ bit_position: 47
        │   │       └─ role_mask: 0b0000...100000 (bit 47 activo)
        │   │
        │   └── 🔷 ATOM  #2 (variante: monto alto → escalado)
        │       ├─ 🔶 identidad
        │       │   ├─ id: "d03.facturas.aprobar_monto_alto"
        │       │   ├─ domain: "D03" · bloque: "facturas" · verbo: "aprobar"
        │       │   ├─ depends_on: ["d03.facturas.aprobar"]
        │       │   └─ version: "1.0.0"
        │       │
        │       ├─ 🔶 TARGET
        │       │   ├─ 🔶 subject
        │       │   │   ├─ set: ["d98.set.director_finanzas"]
        │       │   │   ├─ unset: []
        │       │   │   ├─ userset: ["usr.presidencia"]   ← acceso puntual, no está en ningún set
        │       │   │   └─ userunset: []
        │       │   ├─ resource: "factura"
        │       │   ├─ action: "aprobar"
        │       │   └─ environment: { trust_level_min: 4 }
        │       │
        │       ├─ CONDITION:
        │       │     "resource.monto > 50000 AND
        │       │      context.device.managed == true"
        │       │
        │       ├─ EFFECT: PERMIT   ◄─ discriminante calculado
        │       │   │
        │       │   ├─ 🔶 obligation/advice  [REACTIVO CONDICIONAL]
        │       │   │   ├─ fulfill_on: PERMIT    ← solo dispara si EFFECT == PERMIT
        │       │   │   ├─ obligation: [PROCESO] log_acceso_exitoso → bos_atom_audit
        │       │   │   ├─ obligation: [PROCESO] notificar_canal → bNotify.finanzas_channel
        │       │   │   └─ advice: [PROCESO] sugerir_doble_verificacion (si monto > 100000)
        │       │   │
        │       │   └─ 🔶 auditoría WORM  [REACTIVO INCONDICIONAL]
        │       │       ├─ [PROCESO] escribir_registro_worm:
        │       │       │   ├─ created_at: "2026-07-01T14:05:00Z"
        │       │       │   ├─ created_by: "ivan.skull"
        │       │       │   ├─ checksum: "sha256:44bd...771f"
        │       │       │   └─ cdc_source: "wal-lsn:0/1A2C9F1"
        │       │       └─ [PROCESO] emitir_evento_cdc → bauth-reactor
        │       │
        │       └─ 🔶 encoding físico  [ESTRUCTURAL]
        │           ├─ bit_position: 48
        │           └─ role_mask: 0b0000...1000000 (bit 48 activo)
        │
        └── 🔷 RULE  ("d03.facturas.rechazar")
            │   ├─ id: "rule.d03.facturas.rechazar"
            │   ├─ policy_ref: "pol.d03.facturas"
            │   ├─ description: "Rechazo de facturas por supervisor"
            │   └─ rule_combining_algorithm: "aggregate-strictest"
            │
            └── 🔷 ATOM
                ├─ 🔶 identidad
                │   ├─ id: "d03.facturas.rechazar"
                │   ├─ domain: "D03" · bloque: "facturas" · verbo: "rechazar"
                │   ├─ depends_on: ["d03.facturas.leer"]
                │   └─ version: "1.0.0"
                │
                ├─ 🔶 TARGET
                │   ├─ 🔶 subject
                │   │   ├─ set: ["d98.set.supervisor_finanzas"]
                │   │   ├─ unset: ["d98.set.supervisor_junior"]   ← rol incluido en el set pero excluido explícitamente
                │   │   ├─ userset: []
                │   │   └─ userunset: []
                │   ├─ resource: "factura"
                │   ├─ action: "rechazar"
                │   └─ environment: { trust_level_min: 3 }
                │
                ├─ CONDITION: "context.device.managed == true"
                ├─ EFFECT: PERMIT   ◄─ discriminante calculado
                │   │
                │   ├─ 🔶 obligation/advice  [REACTIVO CONDICIONAL]
                │   │   ├─ fulfill_on: PERMIT    ← solo dispara si EFFECT == PERMIT
                │   │   └─ obligation: [PROCESO] log_acceso_exitoso → bos_atom_audit
                │   │
                │   └─ 🔶 auditoría WORM  [REACTIVO INCONDICIONAL]
                │       ├─ [PROCESO] escribir_registro_worm:
                │       │   ├─ created_at: "2026-06-12T08:31:00Z"
                │       │   ├─ created_by: "ivan.skull"
                │       │   ├─ checksum: "sha256:1c7e...aa90"
                │       │   └─ cdc_source: "wal-lsn:0/1A2B3D9"
                │       └─ [PROCESO] emitir_evento_cdc → bauth-reactor
                │
                └─ 🔶 encoding físico  [ESTRUCTURAL]
                    ├─ bit_position: 49
                    └─ role_mask: 0b0000...10000000 (bit 49 activo)
```

**Qué muestra este ejemplo:**

- **Herencia de `target`** — la Policy declara `resource: "factura"` de
  forma amplia; la Rule refina `action` al verbo específico; el Atom
  añade `subject` y `environment` concretos. Ningún nivel repite lo
  que ya heredó sin necesidad.
- **Una Rule, múltiples Atoms** — `d03.facturas.aprobar` tiene dos
  variantes (Atom #1 estándar, Atom #2 para monto alto) que comparten
  `verbo` pero difieren en `subject`, `condition` y `bit_position`.
  Esto ilustra exactamente el caso pendiente de la sección 3.4: ambos
  Atoms devuelven `PERMIT` pero bajo condiciones mutuamente excluyentes
  (`monto > 50000` vs. implícito `monto <= 50000`), así que aquí no
  hay conflicto real — pero si dos Atoms de la misma Rule pudieran
  evaluar `PERMIT` y `DENY` para el mismo request, ahí es donde
  `rule_combining_algorithm` tendría que actuar.
- **`depends_on` encadenado** — Atom #2 depende de Atom #1
  (`d03.facturas.aprobar`), que a su vez depende de
  `d03.facturas.leer`, formando el árbol de dependencias real.
- **`bit_position` secuencial** — 47, 48, 49 son posiciones contiguas
  en el BitMask de 64 bits para este bloque; en la práctica dependerán
  del algoritmo de asignación que quede pendiente de documentar
  (sección 7).
- **`subject` como inclusión/exclusión de rol y usuario** — cada Atom
  usa una combinación distinta de los 4 sub-nodos:
  - Atom #1 (`aprobar`) usa `set` + `userunset` → todo el rol
    `supervisor_finanzas` puede aprobar, **excepto** el usuario
    `usr.jgomez` (revocación puntual sin tocar el rol).
  - Atom #2 (`aprobar_monto_alto`) usa `set` + `userset` → el rol
    `director_finanzas` puede aprobar montos altos, y además se
    concede acceso puntual a `usr.presidencia`, que no pertenece a
    ningún set formal.
  - Atom `rechazar` usa `set` + `unset` → todo `supervisor_finanzas`
    puede rechazar, **excepto** el sub-rol `supervisor_junior` (que
    XACML resolvería vía jerarquía de roles, pero aquí se excluye
    explícitamente a nivel de rol, no de usuario individual).

  Ver sección 3.5.1 para la semántica de evaluación completa.

---

## 3. Atributos por nivel (detalle)

### 3.1 Domain (dNN)

Namespace organizacional. **No tiene** Target/Condition/Effect propios.

| Atributo | Descripción |
|---|---|
| `id` | Código de dominio (`D03`). D01–D14 + D98 reservado (Sets) |
| `nombre` | Nombre descriptivo (`Facturación`) |
| `owner` | Equipo/rol responsable (governance) |
| `classification` | Sensibilidad general (`financiero`, `PII`, `crítico`) |
| `version` | Versión del dominio completo (releases coordinados) |
| `policy_set_ref` | Referencia al PolicySet raíz del dominio |

### 3.2 Bloque

Subdivisión funcional dentro del dominio. **No tiene** Target/Condition/Effect propios.

| Atributo | Descripción |
|---|---|
| `id` | Identificador del bloque (`facturas`) |
| `domain_ref` | FK al dominio padre |
| `resource_type` | Tipo de recurso agrupado (casi siempre heredado al `resource` del Target) |
| `policy_ref` | Referencia a la Policy/PolicySet que lo representa |

### 3.3 PolicySet / Policy

Primer nivel con **combining algorithm real** (XACML 3.0).

- **PolicySet** → contiene Policies/PolicySets → usa `policy_combining_algorithm`
- **Policy** → contiene Rules → usa `rule_combining_algorithm`

| Atributo | Descripción |
|---|---|
| `id` | Identificador |
| `type` | `PolicySet` \| `Policy` |
| `target` | Target heredable por defecto (subject/resource/action/environment) — los hijos pueden sobreescribirlo |
| `combining_algorithm` | `aggregate-strictest` (custom) — XACML define también `deny-overrides`, `permit-overrides`, `first-applicable`, `only-one-applicable` |
| `obligations` / `advice` | Se acumulan con los de las Rules hijas |
| `policy_issuer` | Quién autorizó/firmó la policy (relevante para `bsign`) |
| `version` | Versión semántica |
| `status` | `draft` \| `active` \| `deprecated` |

### 3.4 Rule

Contenedor lógico intermedio que agrupa variantes de un mismo verbo/regla de negocio.

| Atributo | Descripción |
|---|---|
| `id` | (`d03.facturas.aprobar` a nivel Rule, sin sufijo de variante) |
| `policy_ref` | FK a la Policy padre |
| `target` | Puede refinar (no reemplazar) el target heredado de la Policy |
| `rule_combining_algorithm` | Cómo se combinan los Atoms hijos, solo si hay >1 |
| `description` | Semántica de negocio en lenguaje natural (auditoría no técnica) |

> ⚠️ **Nota de diseño:** en XACML 3.0 canónico, Rule *es* la hoja y no
> tiene combining algorithm propio — solo PolicySet y Policy combinan.
> Al introducir un nivel Rule intermedio con múltiples Atoms hijos,
> AtomLang debe decidir explícitamente si ese nivel también aplica
> `aggregate-strictest` o si delega la resolución de conflictos
> exclusivamente a la Policy padre. **Pendiente de definición formal.**

### 3.5 Atom (hoja)

Único nivel con `target/condition/effect` **evaluables en runtime**.

**Identidad**

| Atributo | Descripción |
|---|---|
| `id` | Identificador único (`d03.usuarios.crear`) |
| `domain` / `bloque` / `verbo` | Naming `dNN.bloque.verbo` |
| `parent` / `depends_on` | Referencia(s) al/los átomo(s) padre en el árbol de dependencias |
| `version` | Versión semántica del átomo |

**Target (evaluable)**

| Atributo | Descripción |
|---|---|
| `subject` | ROL \| SET \| ANY (taxonomía de Subject) |
| `resource` | Recurso sobre el que opera |
| `action` | Acción (mapea al verbo) |
| `environment` | Contexto ambiental (device, location, schedule — de `bos.GetContext()`) |

**Grupos evaluables: CONDITION y EFFECT**

> **AtomLang vs. norma (ver §1.1):** En XACML 3.0 / NIST SP 800-162, `condition` y `effect`
> son atributos escalares. En AtomLang son **GRUPOs** porque contienen sub-nodos hijos.
> El compilador `atomc` aplana estos grupos al escalar que exige la norma en el árbol compilado.

| Grupo AtomLang | Atributo de valor | Descripción |
|---|---|---|
| `CONDITION` | `condition` | Expresión booleana evaluada en runtime (ej. `trust_level >= 3 AND device.managed == true`). `null` = sin condición adicional. |
| `EFFECT` | `effect` | `PERMIT` \| `DENY` (únicos valores válidos en XACML 3.0 — ver nota abajo). Discriminante declarado por el autor. |

> **⚠️ Nota: `effect` ≠ `decision` ≠ Extended Indeterminate**
>
> Tres conceptos distintos que se confunden frecuentemente al implementar `atomc`:
>
> | Concepto | Dónde vive | Valores | Quién lo escribe |
> |---|---|---|---|
> | `effect` | Atributo del Atom (declarativo) | `PERMIT` \| `DENY` | El autor de la policy |
> | `decision` | Elemento `<Result>` de la Response del PDP | `Permit` \| `Deny` \| `Indeterminate` \| `NotApplicable` | El motor `atomc` en runtime |
> | Extended Indeterminate | Interno al combining algorithm | `Indeterminate{P}` \| `Indeterminate{D}` \| `Indeterminate{DP}` | El motor `atomc` cuando `condition` truena |
>
> `effect` es la **intención declarada** del autor de la regla. `decision` es el **resultado real** del PDP.
> Un Atom con `effect: PERMIT` puede producir `decision: Deny` si otro Atom con `effect: DENY`
> tiene mayor prioridad en `aggregate-strictest`. Extended Indeterminate solo aparece en runtime
> cuando `condition` falla (atributo faltante, error de tipo) — le indica al combining algorithm si
> el error "habría sido" Permit o Deny para poder decidir si fail-closed o fail-open.
> Ver sección 7 para la pregunta abierta sobre semántica de Extended Indeterminate en `aggregate-strictest`.

**Post-decisión — REACTIVO CONDICIONAL** *(depende del valor de `effect`)*

Todo lo que sigue a `EFFECT` en el árbol es reactivo: ocurre **después** de que
la decisión PERMIT/DENY ya fue tomada. No influye en ella — la ejecuta.

| Campo | Tipo | Descripción |
|---|---|---|
| `fulfill_on` | [ATRIBUTO] | `PERMIT` \| `DENY` — gate de disparo. Esta obligation/advice solo se activa si `EFFECT` tomó este valor. Es el vínculo explícito entre el discriminante y el proceso reactivo. |
| `obligation` | [PROCESO] | Proceso vinculante ejecutado por `atomc` si `EFFECT == fulfill_on`. Ejemplos: `log_acceso_exitoso → bos_atom_audit` (PERMIT), `revocar_sesion → bAuth` (DENY), `notificar_canal → bNotify` (PERMIT). El PEP **debe** ejecutarlo — si falla, el PDP puede revertir la decisión. |
| `advice` | [PROCESO — no vinculante] | Sugerencia al PEP ligada al valor de `EFFECT`. Si el PEP no puede ejecutarla, la decisión igual se mantiene. Ej: `mostrar_aviso_politica` (PERMIT), `sugerir_contacto_soporte` (DENY). |
| `priority` | [ATRIBUTO] | Prioridad en resolución de conflictos entre Atoms que producen distintos effects |

**Post-decisión — REACTIVO INCONDICIONAL** *(siempre ejecuta, sin importar el valor de `effect`)*

La auditoría WORM se dispara en PERMIT **y** en DENY. Auditar un intento
de acceso denegado (DENY) es igual o más crítico que auditar un acceso
exitoso — es la base de la detección de intrusiones en bAuth / T-170.

| Campo | Tipo | Descripción |
|---|---|---|
| `escribir_registro_worm` | [PROCESO] | Escritura inmutable en `bos_atom_audit`. Contiene: `created_at`, `created_by`, `checksum`/`hash` (integridad SHA-256), `effect_resultante` (el valor real, no la intención). |
| `emitir_evento_cdc` | [PROCESO] | Notifica a `bauth-reactor` vía WAL/CDC para propagación downstream. Referenciado por `cdc_source` (WAL LSN). |
| `created_at` / `created_by` | [ATRIBUTO] | Metadatos de creación del Atom (WORM — no modificables tras firma) |
| `checksum` / `hash` | [ATRIBUTO] | Integridad SHA-256 del Atom en `bos_atom_audit` |
| `cdc_source` | [ATRIBUTO] | Referencia al evento WAL que originó el cambio (`bauth-reactor`, LSN) |

**Encoding físico (BitMask 64-bit)**

| Atributo | Descripción |
|---|---|
| `bit_position` | Posición en el BitMask de 64 bits (label encoding del Átomo) |
| `role_mask` | Referencia al one-hot encoding del Rol (N-bit) que agrupa múltiples átomos |

---

## 4. Tabla resumen — herencia por nivel

| Nodo | Target propio | Condition | Effect | Combining Algorithm |
|---|---|---|---|---|
| Domain | ❌ (namespace) | ❌ | ❌ | ❌ |
| Bloque | ❌ (namespace) | ❌ | ❌ | ❌ |
| PolicySet | ✅ heredable | ❌ | ❌ | ✅ `policy_combining_algorithm` |
| Policy | ✅ heredable/refinable | ❌ | ❌ | ✅ `rule_combining_algorithm` |
| Rule | ✅ refinable | ❌ | ❌ | ✅ (si tiene >1 Atom hijo — *pendiente de definición*) |
| **Atom** | ✅ final | ✅ | ✅ | — (es la hoja) |

**Nota clave:** `target` aparece en tres niveles (PolicySet, Rule, Atom),
pero solo el del Atom se evalúa realmente contra el request. Los de
PolicySet y Rule son *filtros de aplicabilidad* — determinan qué
subárbol de políticas es candidato antes de llegar a evaluar el Atom
(optimización/indexación, coherente con XACML 3.0).

---

## 5. Verbos canónicos (ejemplo CRUD+)

```
crear, leer, actualizar, eliminar, aprobar, rechazar,
delegar, revocar, exportar, firmar, auditar
```

---

## 6. Ejemplo completo — Atom en YAML (`.atm.yaml`)

```yaml
id: d03.facturas.aprobar
domain: D03
bloque: facturas
verbo: aprobar
version: 1.0.0
depends_on:
  - d03.facturas.leer
target:
  subject:
    type: ROL
    ref: d98.set.supervisor_finanzas
  resource: factura
  action: aprobar
  environment:
    trust_level_min: 3
condition: "context.device.managed == true AND context.schedule.within_business_hours == true"
effect: PERMIT
combining_algorithm: aggregate-strictest
obligation:
  - log_to: bos_atom_audit
bit_position: 47
```

---

## 7. Preguntas abiertas / próximos pasos

- [ ] Definir formalmente si `Rule` aplica `aggregate-strictest` propio
      cuando agrupa >1 Atom, o si delega siempre a la `Policy` padre.
- [ ] Formalizar el mecanismo de *override* de `target` entre niveles
      (Policy → Rule → Atom): ¿reemplazo total o merge por campo?
- [ ] Especificar el schema JSON/YAML formal para `atomc` (compilador Go).
- [ ] Definir taxonomía completa de `verbo` por dominio (más allá de CRUD+).
- [ ] Documentar el algoritmo exacto de resolución de `bit_position`
      dentro del BitMask de 64 bits (colisiones, reservas, versionado).
- [ ] Definir semántica de Extended Indeterminate para `aggregate-strictest`:
      si el `condition` de un Atom con `effect: DENY` truena en runtime
      (atributo faltante, error de tipo, división por cero), ¿el resultado
      se trata como `Indeterminate{D}` (probablemente Deny) o como
      `Indeterminate{DP}` (podría ser cualquiera)? Esto determina si
      `atomc` debe ser **fail-closed** (denegar ante error) o **fail-open**.
      **Recomendación:** fail-closed, coherente con XACML 7.2.2 "deny-biased PEP"
      y con el perfil productivo de `bAuth` (sistema ABAC de acceso real).
- [ ] Definir qué procesos reactivos (`obligation`) son **compensables**:
      si `escribir_registro_worm` falla, ¿`atomc` revierte la decisión de
      PERMIT? ¿Hay un patrón saga con compensador para obligations críticas?
      Coherente con el patrón saga/compensadores ya usado en otros daemons SBOS.

---

*Documento vivo — se irá refinando en conversación.*
