# PROPUESTA-OBJETOS-PALETA-ATOMLANG — Catálogo Completo de Objetos
## Documento no indexado — Extensión de A.64 §4.4 y §6

**Fecha:** 2026-07-31 · **Autor:** bauth-developer
**Referencias:** A.64 §4.4 Herramientas · §6 Rol Template · `rol_template_datos.dart` (3826 líneas) · `atomlang_datos.dart` (vocabulario) · `idn_policy_node_type` (T-161b, 12 tipos) · 1.06 D00 v2.0 (D94 USERSET, D98 SET)

---

## 1. Los 7 contextos de REGLA — mismo `TipoNodo.regla`, distinto comportamiento

En el árbol Dart (`rol_template_datos.dart`), todas las reglas usan el mismo `TipoNodo.regla`. Pero el CONTEXTO donde se ubican determina su comportamiento, validaciones y pre-configuración. La paleta ofrece el objeto correcto para cada contexto.

| # | Contexto | Padre en el árbol | Pre-configuración | Ejemplo Dart |
|:-:|----------|-------------------|-------------------|-------------|
| 1 | **Regla de evaluación** | `condiciones` (OR entre sub-reglas) | combining=all-of, effect=Pending | `condiciones` → `riesgo bajo...` (línea 440) |
| 2 | **Regla perimetral (Guardrail)** | `ZR · Reglas perimetrales` | combining=deny-overrides, pre-evaluado ANTES de ZA | `zone_clientes_read` (línea 2297) |
| 3 | **Record Rule** (filtro de dominio) | `record_rule` | combining=deny-overrides, SQL domain filter | `tryton.sale.sale.read` (línea 833) |
| 4 | **Button Rule** (visibilidad UI) | `button_rules` | combining=permit-overrides, effect=visible/oculto | `button_approve_visible` (línea 1940) |
| 5 | **Field Rule** (acceso a campo) | `field` | combining=deny-overrides, field_mask en obligation | `sale.field.margin` (línea 917) |
| 6 | **Action Rule** (acción de módulo) | `actions` | combining=permit-overrides, verbo específico | `stock.action.validate` (línea 899) |
| 7 | **Regla de validación** (config) | `D99 · Administrativo Global` | NO produce Decision, solo valida estructura | `cfg_validation_rule` (manual 2.05 §7.3) |

**Regla de oro:** La regla #2 (Guardrail) se evalúa ANTES que las reglas #3-#6. Si el guardrail DENY, las demás no se evalúan. Es el patrón XACML `deny-overrides` a nivel de zona perimetral.

**Fuente:** `rol_template_datos.dart` · manual 2.05 §7.3 (3 materializaciones de Rule) · `PolicyRule` struct (62 tipos en runtime)

---

## 2. Vocabulario AtomLang completo — fuente del compilador `atomc`

### 2.1 Verbos (14)

`read | write | create | delete | approve | execute | configure | audit | emit | login | delegate | export | void | ANY`

Fuente: `bauth.privilege_verb` (T-174, 64 filas en VPS). La UI muestra el subconjunto de 14 verbos activos usados en átomos.

### 2.2 Operadores de Condition (9)

`== | != | > | < | >= | <= | IN | NOT_IN | BETWEEN`

Fuente: `atomlang_datos.dart` §vocabularioOperadores. Cerrado — el compilador rechaza cualquier otro símbolo con `ATOMC-E-013`.

### 2.3 Algoritmos de combinación (6)

`deny-overrides | permit-overrides | first-applicable | deny-unless-permit | permit-unless-deny | aggregate-strictest`

Fuente: XACML 3.0 §7.14 + extensión bAuth `aggregate-strictest` para step-up RFC 9470.

### 2.4 Subject — vocabulario completo (6 valores, 2 niveles)

El Target.Subject define A QUIÉN aplica el átomo. Opera en dos niveles independientes:

| Nivel | Valor | Significado | Catálogo | Dominio |
|:-----:|-------|-------------|----------|:-------:|
| **Rol** | `ANY` | Cualquier rol autenticado | — | — |
| **Rol** | `ROL(id)` | Un rol específico | `bauth.idn_roles_rol_hierarchical` (T-041) | D01 |
| **Rol** | `SET(id)` | Conjunto de roles | `bauth.privilege_role_set` *(propuesta)* | **D98** |
| **Entidad** | `ANY` | Cualquier entidad autenticada | — | — |
| **Entidad** | `USER(id)` | Un actor/entidad específico | `bauth.idn_identity_entity` (T-156) | D00 |
| **Entidad** | `USERSET(id)` | Conjunto de entidades por contexto operativo | `bauth.idn_identity_entity` + tabla de membresía | **D94** |
| **Entidad** | `USERUNSET(id)` | Exclusión explícita de un USERSET | Misma membresía, flag `excluded` | **D94** |

**Por qué dos niveles:** `SET(vendedores)` responde "este rol puede vender". `USERSET(RRHH)` responde "esta persona es empleado". Son preguntas distintas. El Target-gate evalúa ambas: el rol DEBE tener el átomo Permit Y la entidad DEBE pertenecer al USERSET requerido.

**Fuente:** 1.06 D00 v2.0 §5.1 (D94 USERSET) · `rol_template_datos.dart` ejemplos `SET(vendedores)` · `atomlang_datos.dart` §vocabularioSubject (ANY, ROL, SET)

### 2.5 Effect — estructura canónica

```yaml
effect:
  decision: Permit | Deny
  obligation:           # opcional — dictado al PEP
    required_loa: AAL2
    max_age_seconds: 300
    acr: phishing_resistant
    registrar_en_audit: true
  advice: "mensaje informativo"  # opcional — el PEP PUEDE ignorarlo
```

**Obligation keys canónicas:** `required_loa`, `max_age_seconds`, `acr`, `registrar_en_audit`, `field_mask`, `sso_protocol`, `users_required`, `notify`.

Fuente: `atomlang_datos.dart` §nodoTipoAtomo · `rol_template_datos.dart` ejemplos con `obl:`

### 2.6 Badges XACML (5)

`[POLICYSET] | [POLICY] | [REGLA] | [ATOM] | [REGISTRO ESTRUCTURAL]`

Fuente: `idn_policy_node_type` (T-161b) · `vocabulario.dart` §kBadgesXACML

---

## 3. Catálogo de objetos de la paleta Herramientas (§4.4)

Cada objeto es una tarjeta arrastrable. Al soltarlo en el árbol, crea un nodo con `node_type` pre-definido y abre su formulario de configuración. Los campos son FIJOS (estructura canónica del tipo de nodo); el usuario solo rellena VALORES.

### 3.1 Paleta completa (18 objetos, 5 grupos)

```
┌──────────────────────────────────────┐
│  🔧  HERRAMIENTAS — Rol Template    │
│  ──────────────────────────────────  │
│                                      │
│  IDENTIDAD (Panel 1)                 │
│  ┌────────────────────────────────┐  │
│  │  [IDENTIDAD RT]  🟪 Nuevo rol │  │
│  │  B1+B2+B3 · destino: Panel 1  │  │
│  └────────────────────────────────┘  │
│                                      │
│  ESTRUCTURA (Panel 2)                │
│  ┌────────────────────────────────┐  │
│  │  [DOMAIN]  🟦 Cabecera dominio│  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  [BLOCK]   ⬜ Bloque           │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  [POLICY_SET]  🟦 Conjunto    │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  [POLICY]  🟦 Política        │  │
│  └────────────────────────────────┘  │
│                                      │
│  EVALUACIÓN (Panel 2 → Panel 3)      │
│  ┌────────────────────────────────┐  │
│  │  [REGLA]  🟠 Evaluación       │  │
│  │  contexto: condiciones (OR)   │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  [GUARDRAIL]  🔴 Perimetral   │  │
│  │  contexto: ZR · pre-evaluado  │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  [RECORD RULE]  🟡 Filtro     │  │
│  │  contexto: record_rule · SQL  │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  [BUTTON RULE]  🟢 UI        │  │
│  │  contexto: button_rules        │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  [FIELD RULE]  🔵 Campo       │  │
│  │  contexto: field · field_mask  │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  [ACTION RULE]  🟣 Acción     │  │
│  │  contexto: actions · verbo     │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  [ATOM]  🔵 Átomo indiv.     │  │
│  │  hijo directo de REGLA         │  │
│  └────────────────────────────────┘  │
│                                      │
│  DATOS (Panel 2, hijos de bloque)    │
│  ┌────────────────────────────────┐  │
│  │  [OBJECT]  ⬜ Objeto JSONB    │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  [LIST]    ⬜ Lista de ítems  │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  [ENUM]    🟣 Valor fijo     │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  [ATTRIBUTE] ⬜ Clave:valor   │  │
│  └────────────────────────────────┘  │
│                                      │
│  REGISTRO (Panel 2 → D98)            │
│  ┌────────────────────────────────┐  │
│  │  [D98]  📋 SET de roles       │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  [D94]  👥 USERSET entidades  │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

---

## 4. Formularios de cada objeto

### 4.1 `[ATOM]` — Átomo de evaluación (el objeto central)

**Badge:** `[ATOM]` · **Color:** teal · **Destino:** Panel 2, hijo de RULE.
**Fuente en Dart:** `_ev()` en `rol_template_datos.dart` · `_nodoTipoAtomo()` en `atomlang_datos.dart`

```
┌──────────────────────────────────────────────────────────┐
│  ÁTOMO — tryton.sale.sale.read                          │
│  ─────────────────────────────────────────────────────── │
│                                                          │
│  ┌─ TARGET-GATE (XACML §7.2) ──────────────────────────┐ │
│  │                                                      │ │
│  │  VERBO  [read ▾]                                     │ │
│  │         read | write | create | delete | approve     │ │
│  │         execute | configure | audit | emit | login   │ │
│  │         delegate | export | void | ANY               │ │
│  │                                                      │ │
│  │  SUBJECT — Nivel ROL                                 │ │
│  │  tipo    [SET(id) ▾]                                 │ │
│  │          ANY | ROL(id) | SET(id)                     │ │
│  │  id      [vendedores ▾]    ← si tipo ≠ ANY           │ │
│  │          (selector: D98 role_sets)                    │ │
│  │                                                      │ │
│  │  SUBJECT — Nivel ENTIDAD (opcional)                  │ │
│  │  tipo    [USERSET(id) ▾]                             │ │
│  │          (vacío) | ANY | USER(id) | USERSET(id)      │ │
│  │          | USERUNSET(id)                              │ │
│  │  id      [RRHH ▾]           ← si tipo ≠ (vacío)/ANY  │ │
│  │          (selector: D94 entity_sets)                  │ │
│  │                                                      │ │
│  │  RESOURCE  [tryton_erp/sale.sale ▾]                  │ │
│  │            (selector: privilege_resource_atom T-171)  │ │
│  │                                                      │ │
│  │  ┌─ ENVIRONMENT (opcional) ────────────────────────┐ │ │
│  │  │  + Agregar predicado de entorno                 │ │ │
│  │  │  propiedad  [hora_del_dia ▾]                    │ │ │
│  │  │  operador   [BETWEEN ▾]                         │ │ │
│  │  │  valor      [08:00, 18:00]                      │ │ │
│  │  │  [✕ quitar]                                     │ │ │
│  │  └─────────────────────────────────────────────────┘ │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ CONDITION (XACML §7.4) ────────────────────────────┐ │
│  │  (opcional — null = siempre True)                    │ │
│  │                                                      │ │
│  │  propiedad  [monto]           (selector: atributos)  │ │
│  │  operador   [>= ▾]                                   │ │
│  │             == | != | > | < | >= | <=                │ │
│  │             IN | NOT_IN | BETWEEN                    │ │
│  │  valor      [10000]             (tipado según prop)  │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ EFFECT (XACML §7.3) ───────────────────────────────┐ │
│  │                                                      │ │
│  │  decision  [Permit ▾]           Permit | Deny        │ │
│  │                                                      │ │
│  │  ┌─ OBLIGATIONS (opcional) ────────────────────────┐ │ │
│  │  │  required_loa    [AAL2 ▾]   AAL1|AAL2|AAL3     │ │ │
│  │  │  max_age_seconds [300]                           │ │ │
│  │  │  acr             [phishing_resistant ▾]          │ │ │
│  │  │  field_mask      [nombre, email]                 │ │ │
│  │  │  + Agregar obligation key                       │ │ │
│  │  └─────────────────────────────────────────────────┘ │ │
│  │                                                      │ │
│  │  advice  "Monto supera límite — requiere gerente"    │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                          │
│  atom_position  (auto-asignado por trigger al guardar)   │
│                                                          │
│  ┌─ Guardar ─┐  ┌─ Cancelar ─┐                          │
└──────────────────────────────────────────────────────────┘
```

**Validaciones al guardar:**
- `verbo` DEBE estar en `bauth.privilege_verb` → `ATOMC-E-014`
- `subject.tipo = SET(id)` → `id` DEBE existir en D98 role_sets → `ATOMC-E-070`
- `subject.tipo = USERSET(id)` → `id` DEBE existir en D94 entity_sets → `ATOMC-E-071`
- `operador` DEBE estar en vocabulario cerrado de 9 → `ATOMC-E-013`
- `decision` solo `Permit` o `Deny` → `ATOMC-E-003`

### 4.2 `[DOMAIN]` — Cabecera de dominio de control

**Badge:** `[POLICYSET]` · **Color:** primary · **Destino:** Panel 2, hijo de TENANT (raíz).
**Fuente en Dart:** `_nodoTipoDominio()` en `atomlang_datos.dart`

```
┌──────────────────────────────────────────────────────────┐
│  DOMAIN — D01 Control de Acceso Lógico                  │
│  ─────────────────────────────────────────────────────── │
│                                                          │
│  domain_code   [D01 ▾]                                   │
│                D00 | D01 | D02 | D03 | D04 | D05 | D06  │
│                D07 | D08 | D09 | D10 | D11 | D12 | D13  │
│                D14 | D15 | D98 | D99                     │
│                                                          │
│  label         {"es": "Control de Acceso Lógico",       │
│                 "en": "Logical Access Control"}          │
│                                                          │
│  description   {"es": "___", "en": "___"}               │
│                                                          │
│  combining_alg [deny-overrides ▾]                        │
│                (opcional — si no se declara, cada        │
│                 Policy hija define el suyo)              │
│                                                          │
│  standard_ref  [NIST RBAC N3 · XACML 3.0]               │
│                (pre-relleno desde cfg_policy_library     │
│                 según domain_code seleccionado)          │
│                                                          │
│  pipeline      [FAST-PATH ▾]                             │
│                FAST-PATH | POLICY-PATH | PRE-BITMASK     │
│                                                          │
│  ┌─ Guardar ─┐  ┌─ Cancelar ─┐                          │
└──────────────────────────────────────────────────────────┘
```

### 4.3 `[BLOCK]` — Bloque de agrupación intermedia

**Badge:** `[POLICY]` o `[POLICYSET]` · **Color:** foreground · **Destino:** Panel 2, hijo de DOMAIN o BLOCK.
**Fuente en Dart:** `_nodoTipoBloque()` en `atomlang_datos.dart`

```
┌──────────────────────────────────────────────────────────┐
│  BLOCK — B01 authorization                              │
│  ─────────────────────────────────────────────────────── │
│                                                          │
│  parent_domain [D01]           (pre-relleno automático)  │
│                                                          │
│  block_code    [B01 ▾]          (filtrado por dominio)   │
│                D01: authorization, roles, zones, fields, │
│                contracts, session, certification,        │
│                dynamic_policy, business_zone             │
│                                                          │
│  badge         [POLICY ▾]                                │
│                [POLICY] si contiene políticas directas   │
│                [POLICYSET] si agrupa más bloques         │
│                                                          │
│  label         {"es": "___", "en": "___"}               │
│  description   {"es": "___", "en": "___"}               │
│  standard_ref  [NIST RBAC N3 §4.2]                      │
│                                                          │
│  ┌─ Guardar ─┐  ┌─ Cancelar ─┐                          │
└──────────────────────────────────────────────────────────┘
```

### 4.4 `[POLICY_SET]` — Conjunto de políticas

**Badge:** `[POLICYSET]` · **Color:** primary · **Destino:** Panel 2, hijo de DOMAIN, BLOCK o POLICY_SET.

```
┌──────────────────────────────────────────────────────────┐
│  POLICY_SET                                              │
│  ─────────────────────────────────────────────────────── │
│                                                          │
│  label         {"es": "___", "en": "___"}               │
│                                                          │
│  combining_alg [deny-overrides ▾]                        │
│                deny-overrides | permit-overrides         │
│                first-applicable | deny-unless-permit     │
│                permit-unless-deny | aggregate-strictest  │
│                                                          │
│  scope         [global ▾]                                │
│                global | business_zone | role_specific    │
│                                                          │
│  target        (opcional) JSONB — filtro de recursos     │
│  description   {"es": "___", "en": "___"}               │
│                                                          │
│  ┌─ Guardar ─┐  ┌─ Cancelar ─┐                          │
└──────────────────────────────────────────────────────────┘
```

### 4.5 `[POLICY]` — Política con reglas

**Badge:** `[POLICY]` · **Color:** primary · **Destino:** Panel 2, hijo de POLICY_SET.

```
┌──────────────────────────────────────────────────────────┐
│  POLICY — app_crm                                        │
│  ─────────────────────────────────────────────────────── │
│                                                          │
│  label         {"es": "___", "en": "___"}               │
│                                                          │
│  app_code      [crm ▾]            (FK privilege_app)     │
│                                                          │
│  combining_alg [deny-overrides ▾]                        │
│                                                          │
│  layer         [B7 ▾]             CAPA 1-7               │
│                                                          │
│  subject       [SET(vendedores) ▾]                       │
│                (selector: D98 role_sets)                 │
│                                                          │
│  description   {"es": "___", "en": "___"}               │
│                                                          │
│  ┌─ Guardar ─┐  ┌─ Cancelar ─┐                          │
└──────────────────────────────────────────────────────────┘
```

### 4.6 `[REGLA]` — Regla de evaluación (contexto: condiciones)

**Badge:** `[REGLA]` · **Color:** amber · **Destino:** Panel 2, hijo de `condiciones` (OR entre sub-reglas).

```
┌──────────────────────────────────────────────────────────┐
│  REGLA — riesgo bajo + zona normal → contraseña         │
│  ─────────────────────────────────────────────────────── │
│                                                          │
│  nombre        [riesgo bajo + zona normal → contraseña] │
│                                                          │
│  effect        [Permit ▾]                                │
│                Permit | Deny                             │
│                                                          │
│  ┌─ EVALUACIONES (eval [op_lógico eval]* efecto) ──────┐ │
│  │                                                      │ │
│  │  propiedad [risk_score]     operador [< ▾]           │ │
│  │            valor [0.5]                               │ │
│  │                                                      │ │
│  │  op_lógico [AND ▾]                                   │ │
│  │                                                      │ │
│  │  propiedad [zone_type]      operador [== ▾]          │ │
│  │            valor [normal]                             │ │
│  │                                                      │ │
│  │  [+ Agregar evaluación]                              │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ Guardar ─┐  ┌─ Cancelar ─┐                          │
└──────────────────────────────────────────────────────────┘
```

### 4.7 `[GUARDRAIL]` — Regla perimetral (contexto: ZR)

**Badge:** `[REGLA]` · **Color:** red/destructive · **Destino:** Panel 2, bajo `ZR · Reglas perimetrales`.
**Comportamiento:** Evaluado ANTES de entrar a la ZA. Si DENY → no se evalúan las reglas internas.

```
┌──────────────────────────────────────────────────────────┐
│  GUARDRAIL — zone_clientes_read                          │
│  ─────────────────────────────────────────────────────── │
│  ⚠  Evaluado ANTES de entrar a la zona de aplicación    │
│                                                          │
│  subject       [ANY ▾]                                   │
│  resource      [zone_logical/clientes ▾]                 │
│                                                          │
│  ┌─ CONDICIONES DE PERÍMETRO ──────────────────────────┐ │
│  │  propiedad [pii_access]     operador [== ▾]         │ │
│  │            valor [true]                              │ │
│  │                                                      │ │
│  │  [+ Agregar condición]                              │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                          │
│  effect        [Permit ▾]                                │
│                                                          │
│  ┌─ OBLIGATIONS DE PERÍMETRO ──────────────────────────┐ │
│  │  masking     [lastFourVisible(DNI,telefono,email)]  │ │
│  │  audit       [PII_READ]                              │ │
│  │  logging     [extra]                                 │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ Guardar ─┐  ┌─ Cancelar ─┐                          │
└──────────────────────────────────────────────────────────┘
```

### 4.8 `[RECORD RULE]` — Filtro de dominio (contexto: record_rule)

**Badge:** `[REGLA]` · **Color:** amber · **Destino:** Panel 2, bajo `record_rule` dentro de una ZA.
**Comportamiento:** Genera SQL domain filter (`record_rule=salesperson_filter`).

```
┌──────────────────────────────────────────────────────────┐
│  RECORD RULE — tryton.sale.sale.read                     │
│  ─────────────────────────────────────────────────────── │
│                                                          │
│  verbo         [read ▾]                                  │
│  subject       [SET(vendedores) ▾]                       │
│  resource      [tryton_erp/sale.sale ▾]                  │
│                                                          │
│  ┌─ DOMAIN FILTER ─────────────────────────────────────┐ │
│  │  record_rule  [salesperson_filter]                   │ │
│  │               (nombre de ir.rule en Tryton)           │ │
│  │                                                      │ │
│  │  domain       [('salesperson','=',user.id)]          │ │
│  │               (expresión de dominio Odoo/Tryton)     │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                          │
│  effect        [Permit ▾]                                │
│  audit         [on]                                      │
│                                                          │
│  ┌─ Guardar ─┐  ┌─ Cancelar ─┐                          │
└──────────────────────────────────────────────────────────┘
```

### 4.9 `[BUTTON RULE]` — Visibilidad de botón UI (contexto: button_rules)

**Badge:** `[REGLA]` · **Color:** green · **Destino:** Panel 2, bajo `button_rules` dentro de una ZA.

```
┌──────────────────────────────────────────────────────────┐
│  BUTTON RULE — button_approve_visible                    │
│  ─────────────────────────────────────────────────────── │
│                                                          │
│  button_name   [approve ▾]       (nombre técnico botón)  │
│  subject       [SET(vendedores) ▾]                       │
│  resource      [tryton_erp/sale.sale ▾]                  │
│                                                          │
│  ┌─ CONDICIÓN DE VISIBILIDAD ──────────────────────────┐ │
│  │  propiedad [monto]          operador [<= ▾]         │ │
│  │            valor [@bauth_config_param.approval_limit]│ │
│  └──────────────────────────────────────────────────────┘ │
│                                                          │
│  effect        [Permit · visible ▾]                      │
│                Permit (visible) | Deny (oculto)          │
│                                                          │
│  ┌─ Guardar ─┐  ┌─ Cancelar ─┐                          │
└──────────────────────────────────────────────────────────┘
```

### 4.10 `[FIELD RULE]` — Acceso a nivel de campo (contexto: field)

**Badge:** `[REGLA]` · **Color:** blue · **Destino:** Panel 2, bajo `field` dentro de una ZA.

```
┌──────────────────────────────────────────────────────────┐
│  FIELD RULE — sale.field.margin                          │
│  ─────────────────────────────────────────────────────── │
│                                                          │
│  field_name    [margin ▾]        (nombre técnico campo)  │
│  subject       [SET(vendedores) ▾]                       │
│  resource      [tryton_erp/sale.sale ▾]                  │
│                                                          │
│  ┌─ CONDICIÓN DE ACCESO ───────────────────────────────┐ │
│  │  propiedad [monto]          operador [>= ▾]         │ │
│  │            valor [10000]                             │ │
│  │  (solo visible si la venta supera 10000 BOB)         │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                          │
│  effect        [Permit · read ▾]                         │
│  field_mask    [margin, margin_percent]                  │
│                (campos visibles en el formulario)        │
│                                                          │
│  ┌─ Guardar ─┐  ┌─ Cancelar ─┐                          │
└──────────────────────────────────────────────────────────┘
```

### 4.11 `[ACTION RULE]` — Acción de módulo (contexto: actions)

**Badge:** `[REGLA]` · **Color:** violet · **Destino:** Panel 2, bajo `actions` dentro de una ZA.

```
┌──────────────────────────────────────────────────────────┐
│  ACTION RULE — stock.action.validate                     │
│  ─────────────────────────────────────────────────────── │
│                                                          │
│  action_name   [validate ▾]      (nombre técnico acción) │
│  verbo         [execute ▾]                               │
│  subject       [SET(almaceneros) ▾]                      │
│  resource      [tryton_erp/stock.move ▾]                 │
│                                                          │
│  ┌─ CONDICIÓN ─────────────────────────────────────────┐ │
│  │  propiedad [stock.estado]    operador [IN ▾]        │ │
│  │            valor [draft, assigned]                   │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                          │
│  effect        [Permit ▾]                                │
│                                                          │
│  ┌─ Guardar ─┐  ┌─ Cancelar ─┐                          │
└──────────────────────────────────────────────────────────┘
```

### 4.12 `[OBJECT]` — Estructura de datos JSONB

**Badge:** `OBJ` · **Color:** muted · **Destino:** Panel 2, hijo de BLOCK o POLICY_SET.

```
┌──────────────────────────────────────────────────────────┐
│  OBJECT — threshold_config                               │
│  ─────────────────────────────────────────────────────── │
│                                                          │
│  label         {"es": "___", "en": "___"}               │
│                                                          │
│  ┌─ EDITOR JSONB ──────────────────────────────────────┐ │
│  │  {                                                   │ │
│  │    "min_amount": 1000,                               │ │
│  │    "max_amount": 50000,                              │ │
│  │    "currency": "BOB"                                 │ │
│  │  }                                                   │ │
│  └──────────────────────────────────────────────────────┘ │
│  [Validar JSON]  [Formatear]                             │
│                                                          │
│  ┌─ Guardar ─┐  ┌─ Cancelar ─┐                          │
└──────────────────────────────────────────────────────────┘
```

### 4.13 `[LIST]` — Colección ordenada de ítems

```
┌──────────────────────────────────────────────────────────┐
│  LIST — allowed_currencies                               │
│  ─────────────────────────────────────────────────────── │
│                                                          │
│  label         {"es": "___", "en": "___"}               │
│  item_type     [TEXT ▾]                                  │
│                                                          │
│  ┌─ ÍTEMS ────────────────────────────────────────────┐ │
│  │  BOB                                          [✕]   │ │
│  │  USD                                          [✕]   │ │
│  │  EUR                                          [✕]   │ │
│  │  [+ Agregar ítem]                                   │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ Guardar ─┐  ┌─ Cancelar ─┐                          │
└──────────────────────────────────────────────────────────┘
```

### 4.14 `[ENUM]` — Valor de conjunto fijo

```
┌──────────────────────────────────────────────────────────┐
│  ENUM — risk_level                                       │
│  ─────────────────────────────────────────────────────── │
│                                                          │
│  key           [risk_level]                               │
│                                                          │
│  value         [HIGH ▾]                                   │
│                LOW | MEDIUM | HIGH | CRITICAL            │
│                                                          │
│  source        [ses_risk_policy]  (tabla de referencia)  │
│  description   {"es": "___", "en": "___"}               │
│                                                          │
│  ┌─ Guardar ─┐  ┌─ Cancelar ─┐                          │
└──────────────────────────────────────────────────────────┘
```

### 4.15 `[ATTRIBUTE]` — Hoja clave→valor libre

```
┌──────────────────────────────────────────────────────────┐
│  ATTRIBUTE                                               │
│  ─────────────────────────────────────────────────────── │
│                                                          │
│  key           [timeout_seconds]                          │
│  value         [300]                                      │
│  type          [INTEGER ▾]                                │
│  description   {"es": "___", "en": "___"}               │
│                                                          │
│  ┌─ Guardar ─┐  ┌─ Cancelar ─┐                          │
└──────────────────────────────────────────────────────────┘
```

### 4.16 `[EVENT]` — Disparador de políticas por evento

```
┌──────────────────────────────────────────────────────────┐
│  EVENT — session_revoked                                 │
│  ─────────────────────────────────────────────────────── │
│                                                          │
│  label         {"es": "___", "en": "___"}               │
│                                                          │
│  trigger       [session-revoked ▾]                       │
│                session-revoked | token-claims-change     │
│                assurance-level-change | credential-change│
│                device-compliance-change | risk-change    │
│                                                          │
│  action        [REVOKE ▾]                                │
│                REVOKE | STEP_UP | SUSPEND | NOTIFY      │
│                                                          │
│  payload_schema (JSONB, opcional)                        │
│  description   {"es": "___", "en": "___"}               │
│                                                          │
│  ┌─ Guardar ─┐  ┌─ Cancelar ─┐                          │
└──────────────────────────────────────────────────────────┘
```

### 4.17 `[D98]` — SET de roles

**Badge:** `[REGISTRO ESTRUCTURAL]` · **Destino:** Panel 2, bajo D98.
**Fuente en Dart:** `role_sets[]` en `rol_template_datos.dart` líneas 125-175

```
┌──────────────────────────────────────────────────────────┐
│  SET DE ROLES — vendedores                              │
│  ─────────────────────────────────────────────────────── │
│                                                          │
│  set_slug   [vendedores]            (snake_case, único)  │
│  set_name   [Vendedores Senior]                          │
│  active     [✓]                                           │
│                                                          │
│  ┌─ MEMBERS — roles que pertenecen a este SET ─────────┐ │
│  │  ROL_VENDEDOR_SENIOR       tier BIZ_N2  [✕ quitar] │ │
│  │  ROL_VENDEDOR_JUNIOR       tier BIZ_N3  [✕ quitar] │ │
│  │  ROL_EJECUTIVO_VENTAS      tier BIZ_N3  [✕ quitar] │ │
│  │  [+ Agregar rol]  (selector: árbol Panel 1)         │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ Guardar ─┐  ┌─ Cancelar ─┐                          │
└──────────────────────────────────────────────────────────┘
```

**Uso en átomos:** `subject = SET(vendedores)` → el átomo aplica a todos los miembros.

### 4.18 `[D94]` — USERSET de entidades

**Concepto:** Define conjuntos de ACTORES (entidades) por contexto operativo. Una entidad puede pertenecer a N USERSETs. El Target.Subject de un átomo puede exigir pertenencia a un USERSET.

**Fuente:** 1.06 D00 v2.0 §5.1 (D94)

**Formulario:**
```
┌──────────────────────────────────────────────────────────┐
│  USERSET — autenticacion                                │
│  ─────────────────────────────────────────────────────── │
│                                                          │
│  set_slug     [autenticacion]        (snake_case, único) │
│  set_name     [Usuarios con acceso al sistema]           │
│  tipo_restringido  [persona ▾]  (opcional — restringe   │
│                    qué tipos de entidad pueden entrar)    │
│                    persona | empresa | vehiculo |         │
│                    producto | servidor | bot | ...        │
│  active       [✓]                                        │
│                                                          │
│  ┌─ MEMBERS — entidades en este USERSET ───────────────┐ │
│  │  Juan Pérez (HUMAN)              [✕ quitar]         │ │
│  │  María López (HUMAN)             [✕ quitar]         │ │
│  │  [+ Agregar entidad]  (selector: árbol Panel 1/     │ │
│  │                        bauth.idn_identity_entity)    │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ Guardar ─┐  ┌─ Cancelar ─┐                          │
└──────────────────────────────────────────────────────────┘
```

**Uso en átomos:** `subject.entity = USERSET(RRHH)` → solo empleados. `subject.entity = USERUNSET(proveedor)` → todos menos proveedores.

**Validación de pertenencia por tipo (D93):**
- `tipo=persona` → puede entrar en USERSET(autenticacion, RRHH, proveedor, cliente)
- `tipo=vehiculo` → puede entrar en USERSET(flota, activos_fijos)
- `tipo=producto` → puede entrar en USERSET(inventario)
- `tipo=servidor` → puede entrar en USERSET(activos_ti, monitoreo)

### 4.19 `[IDENTIDAD RT]` — Rol nuevo (Panel 1)

**Tipo:** compuesto 🟪 — genera subtree B1+B2+B3.
**Fuente en Dart:** A.64 §4.4 líneas 420-496

**Formulario (3 pestañas):**
```
┌─ B1 · IDENTIFICACIÓN ─┐ ┌─ B2 · VIGENCIA ─┐ ┌─ B3 · APROBACIÓN ─┐
│ parent_id  [▾ árbol]   │ │ type   [INDEFINITE▾]│ │ quórum    [2]      │
│ type_id    [INDIVIDUAL▾]│ │ start   [2026-08-01]│ │ aprobadores [▾]    │
│ tier       [BIZ_N3 ▾]  │ │ end     [null]      │ │ canal  [email ▾]   │
│ name_es    [________]  │ │ review  [2027-08-01]│ │ SLA     [48 h ▾]   │
│ name_en    [________]  │ │                       │ │ escalación [▾]     │
│ ...                     │ │                       │ │                     │
└────────────────────────┘ └──────────────────────┘ └────────────────────┘
```

---

## 5. Reglas de drop (matriz de destinos válidos)

| Origen | Destinos válidos | Inválido |
|--------|-----------------|----------|
| `[DOMAIN]` | Raíz Panel 2 | Cualquier otro |
| `[BLOCK]` | DOMAIN, BLOCK | RULE, ATOM |
| `[POLICY_SET]` | DOMAIN, BLOCK, POLICY_SET | RULE, ATOM |
| `[POLICY]` | POLICY_SET | DOMAIN, RULE, ATOM |
| `[RULE]` | POLICY, POLICY_SET | DOMAIN, BLOCK |
| `[ATOM]` | **RULE** (obligatorio) | Todo lo demás |
| `[OBJECT]` | BLOCK, POLICY_SET, POLICY | RULE |
| `[LIST]` | BLOCK, POLICY_SET, OBJECT | RULE |
| `[ENUM]` | OBJECT, POLICY, RULE | — |
| `[ATTRIBUTE]` | OBJECT, POLICY, RULE, ATOM | — |
| `[D98]` | Raíz Panel 2 (bajo D98) | Fuera de D98 |
| `[D94]` | Raíz Panel 2 (bajo D00) | Fuera de D00 |
| `[IDENTIDAD RT]` | Panel 1 (árbol de roles) | Panel 2 |

---

## 6. Lo que YA existe y lo que hay que construir

### 6.1 Código existente (no tocar, extender)

| Archivo | Rol | Estado |
|---------|-----|:------:|
| `rol_template_datos.dart` | Árbol completo con 3826 líneas de ejemplos | ✅ Referencia |
| `atomlang_datos.dart` | Vocabulario AtomLang (5 secciones) | ✅ Parcial — falta USERSET/USERUNSET |
| `vocabulario.dart` | Constantes UI (verbos, operadores, badges) | ✅ |
| `vista_rol_template.dart` | Vista 3 paneles | ⚠️ Refactor pendiente |
| `arbol_template.dart` | Renderizado del árbol con linter | ✅ |
| `bloque_lateral_derecho.dart` | Panel Herramientas | ❌ Sin TOP/BODY/BOTTOM |

### 6.2 Tareas P1 (bloqueantes)

1. **Agregar USERSET/USERUNSET al vocabulario** — `atomlang_datos.dart` §vocabularioSubject y `vocabulario.dart`
2. **Refactor `bloque_lateral_derecho`** — estructura TOP/BODY/BOTTOM con selector
3. **Widget `objeto_paleta.dart`** — tarjeta arrastrable genérica con `node_type`, badge, color (datos de T-161b)
4. **Formulario `formulario_atom.dart`** — el formulario completo del átomo (§3.1) con target-gate + condition + effect

### 6.3 Tareas P2

5. **Formulario `formulario_regla.dart`** — regla con selector de efecto + lista de átomos hijos
6. **Formulario `formulario_set.dart`** — D98 SET de roles con selector de miembros desde Panel 1
7. **Formulario `formulario_userset.dart`** — D94 USERSET con restricción por tipo (D93)
8. **Lógica `reglas_drop.dart`** — validación de destinos según matriz (§4)

### 6.4 Tareas P3

9. **Refactor `vista_rol_template`** — 3 paneles con enlace cruzado SET↔átomo (§6 A.64)
10. **Integración `atomc`** — botón Compilar → Recompilar → Publicar (§4.5 A.64)

---

*Documento no indexado — reemplaza v1.0 · SKULL · SBOS · Julio 2026*
