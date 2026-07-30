# A.47 — Clasificación y Composición del Árbol de Configuración
## Tipo B+C — Fundamento normativo y justificación técnica para la posición de cada nodo en el árbol de políticas bAuth

**Versión:** 1.0.3  
**Fecha:** 2026-07-14  
**Tipo de anexo:** B (normativo/industria) + C (justificación de decisión técnica)  
**Respalda a:** [2.14 MANUAL-COMPOSICION-ARBOL §8–§10](../2.14_MANUAL-COMPOSICION-ARBOL-v1.0.md) · [2.13 MANUAL-ATOMLANG-LENGUAJE v2.0 §4](../2.13_MANUAL-ATOMLANG-LENGUAJE-v2.0.md) · [1.06 D00 Identidad v2.0](../1.06_MANUAL-D00-IDENTIDAD-v2.0.md) · [2.15 Motor de Identidad](../2.15_MANUAL-MOTOR-IDENTIDAD-v1.0.md)  
**Fuentes absorbidas:** `manual-estructuracion-politicas-roles-bAuth.md` §6–§12 (legacy en `anexos/` — este anexo lo reemplaza) · `ATOMLANG-GAP-ANALYSIS-D1-v1.0.md` §1–§5 (gaps D1 absorbidos en §6)  
**Normas base:** OASIS XACML 3.0 · NIST SP 800-162 §4 · NIST SP 800-207 §2.2 · ANSI INCITS 359-2004 · AWS IAM equivalences

---

## §1 Propósito y cómo citarlo

Este anexo contiene:
1. Las reglas normativas que determinan **dónde va cada nodo** en el árbol (Zona, Aplicación, Guardrail, D98)
2. La justificación técnica de los 6 anti-patrones de composición
3. El checklist de validación antes de publicar un template de rol
4. El glosario canónico de equivalencias entre estándares
5. El diagnóstico del árbol as-is de bAuth (captura D1, pre-AtomLang) con comparación nodo a nodo

**Cómo citarlo:** `A.47 §N` (ej. "ver reglas de clasificación: A.47 §2").

---

## §2 Reglas de clasificación — ¿dónde va cada nodo?

Estas son las reglas que determinan si un elemento del árbol debe ser PolicySet (Dominio o Zona), Policy (Aplicación), Rule (Atom), o D98 (Registro Estructural). El compilador `atomc` verifica estas reglas en Fase 2 (Semantic).

### §2.1 Árbol de decisión para clasificar un nodo

```
¿El nodo produce Decision (Permit/Deny)?
├── NO → ¿Es un dominio del lenguaje AtomLang?
│         ├── D95 · Catálogo de Átomos → badge [CATÁLOGO]
│         │     Solo lectura. Poblado automáticamente por atomc.
│         ├── D96 · Contrato de Métodos → badge [CONTRATO]
│         │     Declarativo. Define entradas/salidas/flujos auth.
│         ├── D97 · Conformidad Normativa → badge [NORMATIVO]
│         │     Validador. Requisitos ISO/NIST/XACML por tipo de nodo.
│         └── D98 · Registro Estructural → badge [REGISTRO ESTRUCTURAL]
│               no lleva combining_algorithm · contiene Sets, constantes, enums
└── SÍ → ¿Es garante transversal (aplica a todo el sistema)?
          ├── SÍ → D99 · Administrativo Global → badge [POLICYSET][GLOBAL]
          │         combining_algorithm obligatorio. No entra al BitMask.
          └── NO → ¿contiene otros nodos que producen Decision?
                    ├── SÍ → es PolicySet (Dominio o Zona)
                    │         ├── ¿Es un plano de control del BitMask (D00-D13)?
                    │         │   └── SÍ → badge [POLICYSET] + código D + path de evaluación
                    │         └── ¿Es un segmento lógico dentro de un Dominio?
                    │             └── SÍ → badge [POLICYSET] + nombre de zona (B6)
                    └── NO → ¿contiene directamente Rules (Atoms)?
                              ├── SÍ → es Policy (Aplicación o capa B7)
                              │         → badge [POLICY] · combining_algorithm obligatorio si 2+ Rules
                              └── NO → es Rule/Atom (la unidad evaluable)
                                        └── badge [REGLA] o [ATOM] — NUNCA [EVAL]
```

### §2.2 Reglas de posicionamiento de Atoms (XACML 3.0 §2.2 + NIST SP 800-162 §4)

**Regla A-01 — Atom de Aplicación:** si la regla pertenece al flujo de negocio de un módulo específico (ERP, CRM, RRHH), colócarla dentro de la Policy de esa Aplicación (`application_id != null`). La Policy debe declarar `combining_algorithm`.

**Regla A-02 — Guardrail Atom:** si la regla aplica transversalmente a toda solicitud, independientemente de la Aplicación, colócarla como Rule standalone (`application_id = null`). No tiene Policy contenedora.

**Regla A-03 — Atoms de B7 (PrivilegeEngine):** los Atoms que controlan acceso a nivel de modelo, campo, menú o fila en cualquier aplicación del tenant (registradas en `bauth.privilege_application`) pertenecen a una de las 5 capas de B7. Cada capa es una Policy con su propio `combining_algorithm`. B7 aplica a ERP, CRM, RRHH, correo, portales y toda aplicación con control de acceso de grano fino — no solo ERP.

**Regla A-04 — D98 no es contenedor de Atoms:** los Sets declarados en D98 NO contienen Atoms. Son solo declaraciones de membresía. Si un nodo en D98 tiene un `effect: Permit/Deny`, está en el lugar incorrecto.

**Regla A-05 — D95 es solo lectura:** el Catálogo de Átomos (D95) es poblado exclusivamente por `atomc compile`. Ningún administrador puede crear, modificar o eliminar nodos en D95 manualmente. Si un átomo en D00-D13 pasa D97 y D96, atomc lo emite en D95 como ACTIVO. Si se corrompe, atomc lo remueve.

**Regla A-06 — D96 es declarativo:** el Contrato de Métodos (D96) define contratos de entrada/salida para los 18 métodos de autenticación. No contiene reglas de negocio ni átomos evaluables. Sus nodos son objetos de datos (parámetros obligatorios, tipo de retorno, precondiciones, flujos).

**Regla A-07 — D97 es un validador:** la Conformidad Normativa (D97) contiene requisitos trazables a normas (ISO, NIST, XACML). No produce Decision. atomc consulta D97 en Fase 2 (Semantic) para verificar que cada nodo del árbol cumple los requisitos aplicables a su tipo.

**Regla A-08 — D99 es un PolicySet global:** el Administrativo Global (D99) sigue la misma estructura que D00-D13 (PolicySet → Política → Regla) pero sus políticas aplican a TODO el sistema, sin importar el dominio funcional. No entra al BitMask. Cambia solo por HITL.

### §2.3 Decisión de `combining_algorithm` por tipo de contenedor

| Tipo | Cuándo usar `deny-overrides` | Cuándo usar `first-applicable` | Cuándo usar `aggregate-strictest` |
|---|---|---|---|
| Dominio (PolicySet raíz) | Siempre — un Deny en cualquier zona del Dominio debe prevalecer | Nunca — a nivel de Dominio | Nunca |
| Zona (PolicySet B6) | Control estricto — datos sensibles, finanzas, compliance | Nunca a nivel de Zona | Nunca |
| Aplicación (Policy) | Default seguro para módulos de datos | Tiers de valores mutuamente excluyentes por rango (ej. Tier1-Tier2-Tier3) | Átomos de step-up concurrentes |
| B7 `field_restrictions` | Siempre — `deny-overrides` para acceso a campos | — | — |
| B7 `button_rules` | Para SoD dentro de button_rules | Para los tiers de monto (primer rango que aplica gana) | Si múltiples step-up aplican al mismo botón |

---

## §3 D98 — Registro Estructural: reglas normativas

### §3.1 Por qué D98 no es XACML

XACML 3.0 no tiene un equivalente directo para "declaración de grupo de roles reutilizable como Subject". En XACML estándar, el Subject se resuelve contra atributos del sujeto en el PIP. bAuth hace una elección arquitectónica: declarar los grupos explícitamente en D98 (tabla `bauth.privilege_role_set` *(propuesta)*) para que el compilador los resuelva estáticamente (no en runtime por el PIP).

**Justificación de la elección:** con 368 roles en 7 tiers, la resolución dinámica del grupo via PIP en cada solicitud tiene coste computacional O(n). La resolución estática via `bauth.privilege_role_set` *(propuesta)* resuelve en O(1) — un bit check en el BitMask. Esta es la misma razón por la que AWS IAM usa Groups como entidad de primera clase.

### §3.2 Reglas de uso de D98

| Regla | Descripción |
|---|---|
| R-D98-01 | Un Set solo puede declararse en D98 — nunca inline dentro de un Atom |
| R-D98-02 | Un Atom que referencia un Set via `subject.set_id` DEBE tener ese Set declarado en D98 (ATOMC-E-014 si no existe) |
| R-D98-03 | D98 no lleva badge `[POLICYSET]` ni `combining_algorithm` — es estructural, no evaluable |
| R-D98-04 | Un rol puede pertenecer a múltiples Sets simultáneamente (relación N:M en `bauth.privilege_role_set_member` *(propuesta)*) |
| R-D98-05 | Eliminar un Set de D98 requiere verificar que ningún Atom lo referencia — el compilador detecta la referencia huérfana |
| R-D98-06 | `UNSET` en un nodo declara los roles que NO pueden ver ni recibir ese nodo aunque pertenezcan al SET que lo incluye. El compilador evalúa `UNSET` **con prioridad** sobre `subject.set_id`. Cada rol en `UNSET` DEBE existir en `bauth.idn_role_template` (ATOMC-E-062 si no existe) |
| R-D98-07 | Si un rol aparece simultáneamente en `UNSET` de un nodo Y como miembro del `SET` referenciado en `subject.set_id` del mismo nodo, el compilador emite ATOMC-W-032 (contradicción explícita — `UNSET` prevalece y el rol queda excluido) |

### §3.3 Ciclo de vida de un Set (D98) vs. ciclo de vida de un Atom

| Aspecto | Set en D98 | Atom en árbol de políticas |
|---|---|---|
| Dueño del cambio | RRHH / Administración de Identidad | Área de Negocio / Compliance / TI |
| Causa de cambio | Alta/baja/cambio de puesto de empleado | Nueva política de negocio, umbral, excepción |
| Frecuencia | Alta (diaria/semanal en organizaciones grandes) | Baja-media (mensual/trimestral) |
| Requiere recompilar árbol | No — solo actualiza `bauth.privilege_role_set` *(propuesta)* | Sí — `atomc compile + publish` |
| Tabla en bAuth | `bauth.privilege_role_set` + `bauth.privilege_role_set_member` *(propuestas)* | `bauth.privilege_atom` + `bauth.privilege_atom_compiled` *(propuesto)* |

---

## §4 Los dos tipos de Atom: base normativa exacta

### §4.1 Atom de Aplicación — XACML 3.0 §5.2

> *"The `<Policy>` element... is the basic unit of policy used by the PDP, and so it is intended to form the basis of an authorization decision."*

El Atom de Aplicación es una Rule dentro de una Policy. La Policy es la unidad que el PDP usa como base de la decisión para una Aplicación específica. Por eso el campo `application_id` no es null — vincula la Rule con la Policy de esa Aplicación.

**Consecuencia de evaluación:** el resultado del Atom de Aplicación PUEDE SER modificado por el `combining_algorithm` de su Policy contenedora (ej. un Permit puede ser anulado por el Deny de otro Atom hermano bajo `deny-overrides`).

### §4.2 Guardrail Atom — XACML 3.0 §2.2 + AWS SCP analogy

> *"A Rule is the most elementary unit of policy. It may exist in isolation only within one of the major actors of the XACML domain."* (XACML 3.0 §2.2)

El Guardrail Atom existe en aislamiento relativo — sin Policy contenedora. Su resultado NO es modificado por ningún `combining_algorithm`. Esto garantiza que el Guardrail actúa como un tope universal: si produce Deny, ese Deny no puede ser anulado por Permit de una Aplicación.

**Analogía verificada con AWS IAM:** las Service Control Policies (SCPs) en AWS Organizations tienen exactamente el mismo comportamiento — son límites de permiso que se aplican antes e independientemente de las políticas de identidad/recurso. Ver §5 (glosario) para la tabla de equivalencias completa.

### §4.3 Tabla de comparación completa

| Propiedad | Atom de Aplicación | Guardrail Atom |
|---|---|---|
| `application_id` | `INTEGER` (FK `bauth.privilege_application`) | `NULL` |
| Posición en árbol | Dentro de una Policy con `combining_algorithm` | Standalone — nivel Dominio o raíz |
| Resultado modificable por `combining_algorithm` | Sí | No |
| Evaluación en el PDP | Solo cuando la Aplicación es invocada | En toda solicitud |
| Verbo obligatorio | Sí — ATOMC-E-005 si falta | Sí — mismo requisito |
| `condition: null` permitido | Sí (explícito) | Sí (explícito) |
| Obligatorio declarar `combining_algorithm` en Policy | Sí si 2+ Atoms | N/A (no hay Policy contenedora) |
| Base XACML | §5.2 — Policy como unidad básica del PDP | §2.2 — Rule en aislamiento |
| Analogía industria | IAM Policy con Statements | AWS SCP / Azure Permission Boundary |

---

## §5 Glosario canónico de equivalencias entre estándares

| Concepto | XACML 3.0 | NIST SP 800-162 | AWS IAM | Azure AD | bAuth/SBOS |
|---|---|---|---|---|---|
| Contenedor raíz de políticas | PolicySet | Policy (genérico) | Service Control Policy | Conditional Access Policy | Dominio D00–D13 |
| Segmento de red/lógico | PolicySet con Target de entorno | — | Permission Boundary | Named Location | Zona B6 |
| Unidad de decisión por módulo | Policy | Policy | Identity/Resource-based Policy | — | Aplicación (`bauth.privilege_application`) |
| Motor de privilegios de aplicaciones (5 capas) | PolicySet anidado | — | — | — | B7 · PrivilegeEngine |
| Unidad atómica evaluable | Rule | Rule | Statement | — | Atom (`bauth.privilege_atom`) |
| Quién puede (Subject) | Subject | Subject attribute | Principal | — | Rol (Dominio Lógico) |
| Sobre qué (Resource) | Resource | Object attribute | Resource | — | Modelo/Campo |
| Qué acción (Action/Verbo) | Action | Operation | Action | — | Verbo (`bauth.privilege_verb`) |
| Bajo qué circunstancia | Environment / Condition | Environment attribute | Condition block | — | Dominio Contextual |
| Motor que decide | PDP | PDP | IAM Policy Evaluation Engine | — | BitMask Engine + PDP nativo |
| Quién administra | PAP | PAP | IAM Console/API | Azure Portal | Dashboard bAuth (PAP) |
| Quién intercepta | PEP | PEP | — (implícito por servicio) | — | Middleware/Gateway bAuth |
| Fuente de atributos externos | PIP | PIP | — | — | `bos.GetContext()` Context Plane |
| Regla global sin módulo | Policy con Target vacío | — | Permission Boundary / SCP | — | Guardrail Atom (`application_id = null`) |
| Grupo de subjects reutilizable | Subject Category custom | Grouping attribute | IAM Group | AAD Group | Set de Roles (`bauth.privilege_role_set`) *(propuesta)* |
| Catálogo de pertenencia rol→Set | — (no normado) | — | Group membership | Group membership | D98 · Registro Estructural |
| Combinar resultados contradictorios | CombiningAlgorithm | — | Explicit Deny wins | — | `combining_algorithm` (6 opciones) |
| Resultado "sin información" | Indeterminate | — | — | — | `Indeterminate` (4 valores XACML) |
| Resultado "no aplica" | NotApplicable | — | No match | — | `NotApplicable` (4 valores XACML) |

---

## §6 Diagnóstico del árbol as-is — D1 Acceso Lógico (pre-AtomLang)

Esta sección preserva el análisis del árbol real de configuración D1 en el estado capturado antes de la implementación de AtomLang (fuente: `manual-estructuracion-politicas-roles-bAuth.md` §12 y `ATOMLANG-GAP-ANALYSIS-D1-v1.0.md`). Es el caso de referencia para entender qué significan los anti-patrones de 2.14 §10 en términos concretos.

### §6.1 Árbol tal como estaba (as-is)

```
D0 · IDENTIDAD ORGANIZACIONAL                    (sin badge)
  B1 · Identificación y metadatos                (sin badge)
  B3 · Flujo de aprobación                       (sin badge)

D1 · ACCESO LÓGICO                               (sin badge)
  B4 · Dominio lógico (autenticación)            (sin badge)
  B6 · Zonas de negocio                          (sin badge)
  B7 · Privilegios de Aplicaciones (5 capas)                 (sin badge)
    model_access            [POLÍTICA]  CAPA 1 · CRUD por modelo
    visible_actions         [POLÍTICA]  CAPA 2 · menús visibles
    field_restrictions      [POLÍTICA]  CAPA 3 · campos individuales
      campo margin — oculto             [EVAL]         ← anti-patrón 5
      campo cost_price — oculto         [EVAL]         ← anti-patrón 5
      campo credit_limit — solo lectura [EVAL]         ← anti-patrón 5
    button_rules            [POLÍTICA]  CAPA 4 · botones con PYSON
      venta ≤ 10 000 BOB — aprobación simple        [EVAL]   ← anti-patrones 1, 5, y 3
      venta 10 001–50 000 BOB — doble + WebAuthn     [EVAL]   ← anti-patrones 1, 5
      pago > 5 000 BOB — SoD                         [EVAL]   ← anti-patrones 1, 5
      venta > 50 000 BOB — fuera del tier 2           [EVAL]   ← anti-patrones 1, 5
    record_rules            [POLÍTICA]  CAPA 5 · filtros de fila

D2 · ACCESO FÍSICO                                (sin badge)
  B5 · Dominio físico                             (sin badge)
```

### §6.2 Diagnóstico nodo a nodo

| # | Nodo afectado | Anti-patrón | Problema | Corrección |
|---|---|---|---|---|
| 1 | `D0`, `D1`, `D2` | 4 (sin badge) | Contenedores de múltiples Policies — son PolicySet sin identificar | Badge `[POLICYSET]` + `combining_algorithm` explícito |
| 2 | `B1`, `B3`, `B4`, `B6`, `B5` | 4 (sin badge) | Sin tipo XACML declarado | Badge `[POLICY]` o `[POLICYSET]` según su contenido |
| 3 | `B7 · Privilegios de Aplicaciones` | 4 (sin badge) | Agrupa 5 Policies — es un PolicySet sin identificar | Badge `[POLICYSET]` con `combining_algorithm: deny-overrides` |
| 4 | Todos los `[EVAL]` | 5 (badge incorrecto) | "Eval" se reserva para runtime/Decision — estos son nodos de configuración | Renombrar a `[REGLA]` o `[ATOM]` |
| 5 | `venta ≤ 10 000 BOB — aprobación simple` | 1 (monto en nombre) | El monto 10 000 está en el nombre del átomo — se vuelve mentiroso al cambiar la política | Renombrar a `venta_aprobacion_tier1` y usar `@bauth_config_param.approval_threshold_tier1` en `value` |
| 6 | `button_rules` 4 rules del tier | 6 (first-applicable mascarando concurrent step-up) | Si dos tiers aplican simultáneamente, `first-applicable` toma el primero declarado, no el más estricto | Usar `aggregate-strictest` para Atoms de step-up concurrentes |
| 7 | `field_restrictions` y `button_rules` | Técnico | No exponen `combining_algorithm` — resultado de conflicto indefinido | Declarar explícitamente (`deny-overrides` para `field_restrictions`, ver §2.3) |
| 8 | Rules de `button_rules` | Técnico | Ninguna expone `Subject` (¿qué rol dispara la regla?) ni `Environment` explícito | Completar Target con `subject.kind` + `subject.set_id` o `subject.role_id` |
| 9 | Rules de `button_rules` | Técnico | Target+Condition+Effect fusionados en un string libre (`"venta ≤ 10 000 BOB — aprobación simple"`) | Descomponer en campos explícitos: `target.resource`, `condition.property_id`, `condition.operator`, `condition.value`, `effect.decision` |

### §6.3 Árbol corregido (referencia — post-AtomLang)

```
D98 · REGISTRO ESTRUCTURAL DE SETS DE ROLES      [REGISTRO ESTRUCTURAL]
  SET: tier_descuento_alto     → roles: [vendedor_senior]
  SET: tier_descuento_full     → roles: [gerente_ventas, cfo]
  SET: aprobadores_pago_n1     → roles: [analista_pagos, contador_junior]
  SET: aprobadores_pago_n2     → roles: [gerente_finanzas, cfo]

D0 · IDENTIDAD ORGANIZACIONAL                    [POLICYSET]  deny-overrides
  B1 · Identificación y metadatos                [POLICY]
  B3 · Flujo de aprobación                       [POLICY]

D1 · ACCESO LÓGICO                               [POLICYSET]  deny-overrides
  B4 · Dominio lógico (autenticación)            [POLICY]
  B6 · Zonas de negocio                          [POLICYSET]  deny-overrides

  B7 · Privilegios de Aplicaciones (5 capas)                 [POLICYSET]  deny-overrides
    model_access                                 [POLICY]  CAPA 1 · deny-overrides
    visible_actions                              [POLICY]  CAPA 2 · deny-overrides
    field_restrictions                           [POLICY]  CAPA 3 · deny-overrides
      campo_margin_oculto                        [REGLA]
        target.resource: field.sale_order.margin
        target.action (verb_id): read
        condition: null
        effect.decision: Deny
        effect.obligation: { omit_from_response: true }

      campo_cost_price_oculto                    [REGLA]
        target.resource: field.product.cost_price
        target.action (verb_id): read
        condition: null
        effect.decision: Deny
        effect.obligation: { omit_from_response: true }

      campo_credit_limit_readonly                [REGLA]
        target.resource: field.res_partner.credit_limit
        target.action (verb_id): write
        condition:
          property_id: field.access_level
          operator: "=="
          value: READ
        effect.decision: Deny
        effect.advice: "HTTP 403 — campo de solo lectura para este rol/contexto"

    button_rules                                 [POLICY]  CAPA 4 · aggregate-strictest (step-up)
      venta_aprobacion_tier1                     [REGLA]
        target.subject.kind: SET
        target.subject.set_id: tier_descuento_alto
        target.resource: sale.order
        target.action (verb_id): approve
        condition:
          property_id: sale_order.amount_bob
          operator: "<="
          value: "@bauth_config_param.approval_threshold_tier1"   ← NO literal 10000
        effect.decision: Permit

      venta_aprobacion_tier2_doble_webauthn      [REGLA]
        target.subject.kind: SET
        target.subject.set_id: tier_descuento_full
        target.resource: sale.order
        target.action (verb_id): approve
        condition:
          property_id: sale_order.amount_bob
          operator: BETWEEN
          value: ["@bauth_config_param.approval_threshold_tier1",
                  "@bauth_config_param.approval_threshold_tier2"]
        effect.decision: Permit
        effect.obligation: { required_loa: AAL2, four_eyes: true }

      pago_sod_check                             [REGLA — Guardrail]
        application_id: null
        target.subject.kind: ANY
        target.resource: payment.transaction
        target.action (verb_id): approve
        condition:
          property_id: payment.creator_id
          operator: "=="
          value: "@ctx.subject_id"    ← mismo usuario que creó el pago
        effect.decision: Deny
        effect.obligation: { sod_violation: true }

      venta_tier3_fuera_alcance                  [REGLA]
        target.resource: sale.order
        target.action (verb_id): approve
        condition:
          property_id: sale_order.amount_bob
          operator: ">"
          value: "@bauth_config_param.approval_threshold_tier2"
        effect.decision: Deny
        effect.advice: "Escalar a Tier 3 / comité de aprobación"

    record_rules                                 [POLICY]  CAPA 5 · deny-overrides
      (pendiente de definir al expandir el nodo)

D2 · ACCESO FÍSICO                               [POLICYSET]  deny-overrides
  B5 · Dominio físico                            [POLICY]
```

### §6.4 Resumen ejecutivo del diagnóstico

- **Estructura de fondo:** correcta — el árbol ya respetaba la jerarquía de agrupación (dominio → bloque → capa → regla) y la separación Config/Evaluación.
- **Gap principal:** ausencia sistemática de **badges explícitos** en los niveles contenedores (`D*`, `B*`) — todos los contenedores D0/D1/D2 y B1/B3/B4/B5/B6/B7 carecían de tipo XACML y `combining_algorithm`.
- **Gap de nomenclatura:** el badge `[EVAL]` en 7 nodos hoja debe renombrarse a `[REGLA]`/`[ATOM]`.
- **Gap técnico — el más grave:** las Rules de `button_rules` mezclaban Target+Condition+Effect en un único string descriptivo libre ("venta ≤ 10 000 BOB — aprobación simple") opaco para cualquier compilador.
- **Gap de parametrización:** los montos (10 000, 50 000, 5 000 BOB) eran literales numéricos codificados en los nombres de los nodos y en los valores de las condiciones.

---

## §7 Checklist de validación antes de publicar un template de rol

Este checklist es el instrumento de control antes de ejecutar `atomc publish`. El compilador verifica automáticamente los puntos marcados con [AUTO]; los puntos marcados con [MANUAL] requieren revisión humana.

### §7.1 Checklist de estructura (Fase 1 y 2 del compilador)

- [ ] [AUTO] Todo `atom_id`, `policy_id`, `policy_set_id` está en snake_case sin mayúsculas ni espacios
- [ ] [AUTO] Todo `verb_id` existe en `bauth.privilege_verb` — ningún verbo libre fuera del catálogo
- [ ] [AUTO] Todo `resource` existe en `bauth.privilege_resource` *(propuesta)*
- [ ] [AUTO] Todo `subject.set_id` existe en `bauth.privilege_role_set` *(propuesta)* (declarado en D98)
- [ ] [AUTO] Todo `subject.role_id` existe en `bauth.idn_role_template.rol_slug`
- [ ] [AUTO] Todo `property_id` en `condition` y `target.environment` existe en `bauth.privilege_attribute` *(propuesta)*
- [ ] [AUTO] Ningún `property_id` aparece en `target.environment` Y en `condition` del mismo Atom (G-04)
- [ ] [AUTO] Toda Policy con 2+ Atoms declara `combining_algorithm` (G-01, ATOMC-E-031)
- [ ] [AUTO] `effect.decision` es solo `Permit` o `Deny` — sin tercer valor (G-07, ATOMC-E-051)
- [ ] [AUTO] Ningún `value` de tipo AMOUNT es un literal numérico (G-08, ATOMC-E-042)
- [ ] [AUTO] Ningún `value` de tipo CURRENCY es un código de moneda literal (G-09, ATOMC-E-043)
- [ ] [AUTO] Ningún `atom_id` contiene dígitos que representen montos o monedas (G-10, ATOMC-E-041)
- [ ] [AUTO] El campo `condition` siempre está presente — `null` si no hay condición (G-03)

### §7.2 Checklist de semántica y diseño (revisión manual)

- [ ] [MANUAL] Todo nodo contenedor (Dominio, Zona, Aplicación) lleva badge explícito (`[POLICYSET]`, `[POLICY]`, `[REGISTRO ESTRUCTURAL]`)
- [ ] [MANUAL] Ningún nodo de configuración usa el badge `[EVAL]` — reservado para runtime
- [ ] [MANUAL] Todo Guardrail Atom tiene `application_id: null` documentado explícitamente
- [ ] [MANUAL] Todos los Sets de D98 usados en los Atoms están declarados en D98
- [ ] [MANUAL] Ningún rol es listado inline en un Atom como lista repetida cuando ese conjunto ya es (o debería ser) un Set en D98
- [ ] [MANUAL] Las Conditions con comparadores numéricos tienen resuelto si se evalúan como rangos en `bauth.privilege_attribute` *(propuesta)* o como comparadores en el PDP
- [ ] [MANUAL] Cada Atom con step-up obligation (required_loa, max_age_seconds) está dentro de una Policy con `combining_algorithm: aggregate-strictest`
- [ ] [MANUAL] Existe una Obligation definida para registrar en `bauth.privilege_atom_audit` (WORM) cada decisión, incluyendo `NotApplicable` e `Indeterminate`
- [ ] [MANUAL] El árbol corregido fue verificado en VPS de staging con `atomc validate` antes de `atomc publish`

---

## §8 Cuatro valores de Decision: por qué auditarlos todos

Todo Atom evaluado produce uno de cuatro valores — no solo Permit/Deny. Registrar solo Permit/Deny en `bauth.privilege_atom_audit` crea puntos ciegos de auditoría.

| Valor | Significado | Causa típica | Por qué auditarlo |
|---|---|---|---|
| **Permit** | Target matchea + Condition verdadera + Effect=Permit | Regla normal de acceso | Traza de acceso concedido |
| **Deny** | Target matchea + Condition verdadera + Effect=Deny | Regla de restricción | Traza de acceso denegado — evidencia forense |
| **NotApplicable** | Target NO matchea — la Rule ni entra a evaluarse | Subject/Resource/Verb distintos | Confirma que la Rule no aplica al caso — elimina falsos positivos en auditoría |
| **Indeterminate** | Error durante evaluación | PIP timeout, atributo faltante, tipo inválido | **CRÍTICO** — un `Indeterminate` no auditado es una decisión sin trazabilidad. Si el PIP falla al resolver `device.trusted`, el sistema debe registrar que NO PUDO DECIDIR, no fallar silenciosamente |

**Base normativa:** XACML 3.0 §7.3 — *"The result of Rule is either applicable, not applicable or indeterminate. An applicable Rule has effect either deny or permit."* El estándar define los cuatro valores como entidades de primera clase del protocolo de evaluación.

---

## §9 El Verbo — por qué es obligatorio en TODO Atom

XACML 3.0 define cuatro categorías de atributo en el Target: Subject, Resource, Action (Verbo), Environment. Las cuatro son obligatorias para que el Target sea evaluable de forma no ambigua.

Sin verbo, un Atom no puede distinguir entre `read`, `write`, `approve`, `delete` sobre el mismo recurso — el Atom se aplica a cualquier operación sobre el recurso, lo que viola el principio de mínimo privilegio.

**Catálogo de verbos base para bAuth (`bauth.privilege_verb`):**

| `verb_id` | Significado semántico |
|---|---|
| `create` | Crear un recurso nuevo |
| `read` | Leer/consultar |
| `write` | Modificar un recurso existente |
| `delete` | Eliminar |
| `approve` | Aprobar un flujo (pago, descuento, solicitud) |
| `void` | Anular/cancelar |
| `execute` | Ejecutar una acción de negocio (ej. `apply_discount`, `reconcile`) |
| `export` | Extraer datos hacia fuera del sistema |
| `delegate` | Ceder temporalmente un privilegio a otro sujeto |
| `configure` | Modificar configuración del sistema |
| `admin` | Operación administrativa de superusuario |

**Regla de diseño:** los verbos específicos de negocio (ej. `apply_discount`, `process_payment`) se registran en `bauth.privilege_verb` como extensiones del catálogo base. Nunca en texto libre dentro del Atom.

---

## §10 Mapa anexo → manuales

| Sección | Respalda a | Qué sección |
|---|---|---|
| §2 (reglas de clasificación) | 2.13 v2.0 §4 · 2.14 §8 | Dominios D00-D13, D95-D99. Tipos de Atom según posición |
| §3 (D98 reglas normativas) | 2.13 v2.0 §4.3 · 2.14 §7 | D98 Registro Estructural |
| §4 (dos tipos de Atom) | 2.14 §8 | Base XACML de los dos tipos |
| §5 (glosario equivalencias) | 2.13 §9, 2.14 §5 | Estado del arte industria |
| §6 (diagnóstico as-is D1) | 2.14 §10 | Anti-patrones con casos concretos |
| §7 (checklist validación) | 2.14 §11 | Ciclo de mantenimiento |
| §8 (4 valores Decision) | 2.05 §7 | Auditoría PDP |
| §9 (Verbo obligatorio) | 2.13 §4 | Constructo verb_id |

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.2 | 2026-07-14 | Actualización: árbol de decisión §2.1 ampliado con D95-D99 (Catálogo de Átomos, Contrato de Métodos, Conformidad Normativa, Administrativo Global). Nuevas reglas A-05..A-08 para dominios del lenguaje. Cabecera y mapa §10 actualizados con referencia a 2.13 v2.0. |
| 1.0.1 | 2026-07-13 | Correcciones por revisión: B7 renombrado, referencias `bos_*` reemplazadas. |
| 1.0.0 | 2026-07-13 | Primera edición. Árbol de decisión, reglas A-01..A-04, D98, glosario, diagnóstico D1, checklist. |


---

## §11 — v1.0.3: Dominios D93-D94 del lenguaje AtomLang (2026-07-14)

### Catálogo de dominios ampliado

| Dominio | Rol | Badge |
|---|---|---|
| **D93** | Catálogo de Identidades — tipos válidos por nivel, atributos requeridos, conjuntos permitidos | `[CATÁLOGO]` |
| **D94** | Registro de Usuarios — conjuntos de usuarios (USERSET) | `[REGISTRO USUARIOS]` |
| D95 | Catálogo de Átomos — compilados, listos para asignar | `[CATÁLOGO ÁTOMOS]` |
| D96 | Contrato de Métodos — entradas/salidas/flujos auth | `[CONTRATO]` |
| D97 | Conformidad Normativa — requisitos ISO/NIST/XACML | `[NORMATIVO]` |
| D98 | Registro Estructural — conjuntos de roles (SET) | `[REGISTRO ESTRUCTURAL]` |
| D99 | Administrativo Global — garante transversal | `[POLICYSET][GLOBAL]` |

### Nuevas reglas de clasificación

**Regla A-09 — D93 gobierna tipos de entidad:** el Catálogo de Identidades define qué `tipo`
es válido para cada `nivel` en `idn_identity_entity`. El motor de identidad rechaza cualquier tipo
no registrado. Agregar un sector nuevo (educación, salud) es agregar su tipo a la política D93.

**Regla A-10 — D94 agrupa usuarios:** el Registro de Usuarios define USERSETs que agrupan
entidades por contexto operativo (RRHH, flota, autenticacion). Una entidad pertenece a
múltiples conjuntos sin duplicarse. Mismo patrón que D98 (SET de roles).
