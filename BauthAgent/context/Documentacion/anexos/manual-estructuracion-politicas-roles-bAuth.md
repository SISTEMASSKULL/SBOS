# Manual de Estructuración de Árboles de Configuración de Roles y Privilegios

### Fundamentos normativos, jerarquía conceptual y convenciones de nomenclatura para sistemas IAM Enterprise (bAuth / SBOS)

**Versión:** 1.0
**Alcance:** Diseño del árbol de configuración de templates de rol — PolicySet, Policy, Rule, Atom, Verbo, Target, Condition, Effect.
**Basado en:** OASIS XACML 3.0, NIST SP 800-162 (ABAC), NIST SP 800-63-4, ISO/IEC 27001:2022, patrones de la industria (AWS IAM, Open Policy Agent/Rego, Casbin).

---

## 0. Propósito de este manual

Este documento define **una única forma canónica y no ambigua** de nombrar, anidar y evaluar los elementos de autorización dentro de bAuth, de modo que:

1. Cualquier desarrollador, auditor o agente de IA que lea el árbol de configuración interprete cada nodo de la misma manera, sin importar quién lo escribió.
2. La nomenclatura sea trazable a estándares internacionales reconocidos (no inventada ad-hoc), lo cual facilita certificaciones (ISO 27001, SOX, auditorías Zero Trust) y evita reescribir el modelo si en el futuro se necesita interoperar con XACML/OPA/otros PDP externos.
3. La misma estructura sirva tanto para **atoms de aplicación** (ej. Tryton, ERP, CRM) como para **guardrails transversales** (reglas simples que no pertenecen a ninguna aplicación).

---

## 1. Jerarquía canónica (de arriba hacia abajo)

```
PolicySet
  └── Policy
        └── Rule (= Atom)
              ├── Target
              │     ├── Subject
              │     ├── Resource
              │     ├── Action (Verbo)
              │     └── Environment
              ├── Condition
              └── Effect
```

Esta jerarquía es la definida formalmente por **OASIS XACML 3.0**: *"XACML defines three top-level policy elements: `<Rule>`, `<Policy>` and `<PolicySet>`... The `<Rule>` element contains a Boolean expression... The `<Policy>` element contains a set of `<Rule>` elements and a specified procedure for combining the results of their evaluation... The `<PolicySet>` element contains a set of `<Policy>` or other `<PolicySet>` elements and a specified procedure for combining the results of their evaluation."*

No existen niveles alternativos "oficiales" por fuera de estos tres — cualquier nivel adicional que necesites (ej. "Dominio", "Módulo", "Tenant") es una convención propia de tu organización, y debe declararse explícitamente como tal (ver §7).

---

## 2. Definición de cada elemento

### 2.1 PolicySet

| Propiedad | Descripción |
|---|---|
| **Qué es** | Contenedor raíz que agrupa una o más `Policy` y/o `PolicySet` anidados. |
| **Contiene directamente** | `Target` (opcional) + lista de `Policy`/`PolicySet` + `PolicyCombiningAlgorithm` |
| **NO contiene directamente** | `Rule` (nunca — las Rules solo viven dentro de una Policy) |
| **Propósito** | Combinar políticas administradas de forma independiente (por equipo, dominio o tenant) en una sola decisión. |
| **Analogía en bAuth** | Un **Tenant** completo, o un **Dominio de Control** (de tus 12 dominios BitMask) que agrupa varias aplicaciones. |

### 2.2 Policy

| Propiedad | Descripción |
|---|---|
| **Qué es** | Unidad básica de decisión — la que efectivamente usa el PDP (*Policy Decision Point*) para producir una autorización. |
| **Contiene directamente** | `Target` (opcional) + lista de `Rule` + `RuleCombiningAlgorithm` |
| **Propósito** | Agrupar Rules relacionadas que actúan sobre el mismo recurso/módulo. |
| **Analogía en bAuth** | Una **Aplicación** (`bos_application`) — ej. `tryton.sale`, `tryton.account`. |

> **Cita normativa:** *"The `<Policy>` element... is the basic unit of policy used by the PDP, and so it is intended to form the basis of an authorization decision."*

### 2.3 Rule (= tu "Atom")

| Propiedad | Descripción |
|---|---|
| **Qué es** | La unidad más elemental de política. Un Atom/Rule **nunca se evalúa aislado por el PDP** como fuente única de decisión — vive dentro de una Policy, salvo el caso especial del Guardrail (§6). |
| **Contiene** | `Target` + `Condition` + `Effect` |
| **Propósito** | Expresar una única regla evaluable: "si se cumple esta condición, el resultado es Permit/Deny". |

> **Cita normativa:** *"A Rule is the most elementary unit of policy. It may exist in isolation only within one of the major actors of the XACML domain [el PAP]. The main components of a Rule are: Target, Effect, Condition, Obligation expressions."*

**Regla de nomenclatura para bAuth:** en tu UI y documentación, usa el badge **`[REGLA]`** o **`[ATOM]`** para este nodo — nunca `[EVAL]` (ese término se reserva para el momento de evaluación en runtime, ver §8).

### 2.4 Target

El Target especifica **a qué solicitudes aplica** el elemento (PolicySet, Policy o Rule), en términos de cuatro categorías de atributos estándar:

| Categoría XACML | Nombre en bAuth | Ejemplo |
|---|---|---|
| **Subject** | Rol / Identidad / Grupo | `rol IN (vendedor_senior, gerente_ventas)` |
| **Resource** | Recurso / Modelo / Campo | `sale.order`, `res_partner.credit_limit` |
| **Action** | **Verbo** | `apply_discount`, `write`, `read`, `approve` |
| **Environment** | Contexto (dispositivo, hora, ubicación, tenant) | `horario_laboral == true`, `device.trusted == true` |

> **Cita normativa:** *"As XACML is used in Attribute-Based Access Controlling, all the attributes are categorized into four main categories: Subject, Resource, Action, Environment."*
>
> *"An empty `<Target>` matches any request."* — un Target vacío es válido y significa "aplica a todo" (usado típicamente en Guardrails globales).

### 2.5 Condition

Expresión booleana **adicional** al Target, que refina cuándo la Rule realmente aplica más allá del simple matching de atributos.

> **Cita normativa:** *"A Boolean expression that refines the applicability of the rule beyond the predicates implied by its target. Therefore, it may be absent."* — *"An empty Condition is always evaluated to true."*

Puede ser:
- **Simple** (un único predicado): `max_access == READ`
- **Compuesta** (varios predicados combinados con AND/OR): `discount_percent <= 15 AND horario_laboral == true`
- **Basada en umbral/rango** (comparadores `<=`, `>=`, `IN`, `BETWEEN`): `transaccion.amount > 3000`

### 2.6 Effect

Resultado que la Rule produce si su Target matchea y su Condition evalúa a verdadero. En XACML estándar solo existen **dos valores posibles**:

- `Permit`
- `Deny`

> **Cita normativa:** *"The effect of the rule indicates the rule-writer's intended consequence of a 'True' evaluation of the rule. Two values are allowed: 'Permit' and 'Deny'."*

No inventes valores adicionales de Effect (ej. "Permit parcial", "Solo lectura" como Effect) — esos matices deben resolverse como **verbos distintos** (`read` vs `write` vs `approve`) evaluados por Rules separadas, no como una tercera categoría de Effect. Esto es lo que ya hacés correctamente en tu ejemplo `credit_limit — solo lectura`: el Effect es `Deny` sobre el verbo `write`, combinado implícitamente con un `Permit` sobre el verbo `read`.

### 2.7 Obligation / Advice (opcional, XACML 3.0)

- **Obligation**: acción que el PEP (*Policy Enforcement Point*) **debe** ejecutar tras la decisión (ej. "registrar en auditoría", "notificar al supervisor"). El PEP no puede ignorarla.
- **Advice** (nuevo en XACML 3.0): información adicional que el PEP **puede** ignorar. Uso típico: explicar el motivo del Deny al usuario final (*"Alex es denegado porque no tiene email válido"*).

> **Cita normativa:** *"Advice is similar to obligations... The difference is contractual: the PEP can disregard any advice it receives... A common scenario is to explain why something was denied."*

Recomendación para bAuth: usa **Obligation** para tu columna `bos_atom_audit` (registro WORM obligatorio), y **Advice** para el mensaje HTTP 403 legible que ve el usuario.

---

## 3. Algoritmos de combinación (Combining Algorithms)

Cuando una Policy tiene varias Rules (o un PolicySet tiene varias Policies), se necesita un algoritmo que resuelva el resultado final si hay resultados contradictorios.

| Algoritmo | Comportamiento | Cuándo usarlo |
|---|---|---|
| **Deny-overrides** | Si **cualquier** Rule evalúa `Deny`, el resultado final es `Deny`, sin importar el resto. | Módulos de control estricto (finanzas, compliance, datos sensibles). Es el default recomendado para bAuth. |
| **Permit-overrides** | Si **cualquier** Rule evalúa `Permit`, el resultado final es `Permit`. | Módulos donde se prioriza disponibilidad sobre restricción (ej. exenciones frecuentes). |
| **First-applicable** | Se evalúan las Rules en orden; se usa el resultado de la **primera** cuyo Target+Condition aplique. | Cuando el orden de declaración importa explícitamente (ej. reglas jerárquicas: excepción → regla general). |
| **Only-one-applicable** | Exige que exactamente una Policy/PolicySet sea aplicable por Target; si más de una aplica → `Indeterminate`. | Solo a nivel Policy/PolicySet, para evitar solapamientos de alcance no intencionados. |
| **Deny-unless-permit** (XACML 3.0) | Resultado es `Deny` salvo que exista al menos un `Permit` explícito; nunca produce `Indeterminate`/`NotApplicable`. | Sistemas donde "silencio = denegado" es un requisito de seguridad (recomendado para bAuth como default de Guardrails). |
| **Permit-unless-deny** (XACML 3.0) | Inverso del anterior: `Permit` salvo que exista un `Deny` explícito. | Uso limitado — solo en contextos de baja sensibilidad. |

> **Cita normativa:** *"In the case of the Deny-overrides algorithm, if a single `<Rule>` or `<Policy>` element is encountered that evaluates to 'Deny', then, regardless of the evaluation result of the other... elements... the combined result is 'Deny'."*

**Recomendación de diseño para bAuth:** declara el `combining_algorithm` como **atributo obligatorio** tanto en `bos_atom_policy` (nivel Rule→Policy) como en un futuro campo a nivel PolicySet (Rule→PolicySet), porque sin este dato el resultado de dos Rules contradictorias es indefinido.

---

## 4. Valores de decisión (Decision Values)

Toda evaluación de Target+Condition produce uno de cuatro valores posibles — no solo Permit/Deny:

| Valor | Significado |
|---|---|
| **Permit** | La Rule/Policy aplica y su condición se cumple. |
| **Deny** | La Rule/Policy aplica y su condición NO se cumple (o su Effect es explícitamente Deny). |
| **NotApplicable** | El Target no matchea la solicitud — la Rule ni siquiera entra a evaluarse. |
| **Indeterminate** | Ocurrió un error durante la evaluación (atributo faltante, tipo inválido, timeout de PIP) — no se puede determinar el resultado. |

> **Cita normativa:** *"The result of Rule is either applicable, not applicable or indeterminate. An applicable Rule has effect either deny or permit."*

**Importante para tu `bos_atom_audit`:** registra siempre estos cuatro valores posibles, no solo Permit/Deny — un `Indeterminate` no auditado es un vector de auditoría ciego (ej. si un PIP externo falla al resolver `device.trusted`, el sistema debe registrar *que no pudo decidir*, no fallar silenciosamente a un default).

---

## 5. Componentes del motor de decisión (Arquitectura de referencia)

NIST SP 800-162 formaliza cuatro puntos funcionales que todo motor ABAC/PBAC debe tener, independientemente de su implementación interna (bitmask, árbol de expresión, etc.):

| Componente | Función | Equivalente sugerido en bAuth |
|---|---|---|
| **PAP** (Policy Administration Point) | Donde se **crean y gestionan** las Policies/Rules | UI de templates de rol + `bos_atom_catalog` (CRUD) |
| **PDP** (Policy Decision Point) | Donde se **evalúa** la solicitud contra las Policies y se produce la Decision | El motor BitMask en sí |
| **PEP** (Policy Enforcement Point) | Donde se **intercepta la solicitud real** y se hace cumplir la Decision (permitir/bloquear la operación) | El middleware/gateway que intercepta la llamada API antes de llegar a la app (Tryton, ERP, etc.) |
| **PIP** (Policy Information Point) | Fuente de **atributos adicionales** necesarios para evaluar (ej. `horario_laboral`, `device.trusted`, `tenant.tipo`) | El `Context Plane` (`bos.GetContext()`) que ya diseñaste |

> **Cita normativa:** *"The four main functional points of an ACM include the Policy Enforcement Point (PEP), the Policy Decision Point (PDP), the Policy Information Point (PIP), and the Policy Administration Point (PAP)."*

Esta separación es clave porque **tu `bos.GetContext()` es literalmente un PIP formalizado** — vale la pena documentarlo así explícitamente en tu arquitectura bAuth para alinear terminología con auditores familiarizados con NIST 800-162.

---

## 6. Dos formas válidas de estructurar una Rule (Atom)

Ambas comparten **exactamente la misma estructura interna** (Target + Condition + Effect + Verbo obligatorio). La diferencia es de **pertenencia**, no de forma.

### 6.1 Atom de Aplicación

```yaml
Policy: tryton.sale                          # bos_application
RuleCombiningAlgorithm: deny-overrides

  Rule: sale_order_apply_discount             # bos_atom_catalog
    Target:
      Subject:   rol IN (vendedor_senior, gerente_ventas)
      Resource:  sale.order
      Action:    apply_discount                # verbo — bos_verb (obligatorio)
    Condition:
      - discount_percent <= 15   (si rol = vendedor_senior)
      - discount_percent <= 100  (si rol = gerente_ventas)
      - horario_laboral == true
    Effect: Permit | Deny
```

- **Pertenece a un `application_id`** concreto.
- **Participa de un `RuleCombiningAlgorithm`** compartido con otras Rules hermanas de la misma Policy.
- Su resultado final puede verse alterado por el algoritmo (ej. un `Deny` de otra Rule puede sobreescribir su `Permit` bajo `deny-overrides`).

### 6.2 Guardrail Atom (Regla simple / transversal)

```yaml
Rule: payment_amount_threshold_check          # bos_atom_catalog, application_id = NULL
  Target:
    Subject:   cualquier usuario autenticado
    Resource:  transaccion
    Action:    procesar                        # verbo obligatorio, incluso aquí
  Condition:
    - transaccion.amount > 3000
  Effect: Deny (requiere escalamiento) | Permit
```

- **No pertenece a ninguna aplicación** (`application_id` = NULL o un pseudo-application "global").
- **No participa de ningún `RuleCombiningAlgorithm`** externo — se evalúa de forma autónoma.
- Se ejecuta típicamente **antes** (pre-check) o **en paralelo** con los Atoms de Aplicación, actuando como un tope universal.

> Terminología equivalente en la industria: AWS IAM llama a este patrón **Service Control Policy (SCP)** o **Permission Boundary** — un guardrail global independiente de cualquier política de recurso específico.

### 6.3 Tabla comparativa

| | Atom de Aplicación | Guardrail Atom |
|---|---|---|
| `application_id` | Poblado | NULL / "global" |
| Combina con otras Rules | Sí (`RuleCombiningAlgorithm`) | No — autónomo |
| Verbo obligatorio | Sí | Sí |
| Auditoría | Incluye qué algoritmo resolvió el conflicto final | Registra solo su propio resultado |
| Analogía industria | XACML `Policy` con Rules hijas | AWS SCP / Permission Boundary |

---

## 7. El Verbo (Action) — por qué es obligatorio en TODO Atom

El **Verbo marca la acción** y es, junto al Subject y el Resource, una de las cuatro categorías de atributo que XACML exige siempre presentes en el Target. Sin verbo, una Rule es inevaluable: no tiene sentido autorizar "sobre `sale.order`" sin decir si es `create`, `read`, `write`, `approve`, `void`, etc.

**Reglas de diseño para `bos_verb`:**

1. `verb_id` en `bos_atom_catalog` debe ser **`NOT NULL`** siempre — incluso en Guardrails.
2. El verbo **condiciona qué Conditions contextuales son relevantes** de evaluar (ej. `write` puede requerir chequear `horario_laboral`; `read` puede no requerirlo) — evita recalcular bits contextuales irrelevantes para el verbo en cuestión.
3. Usa un catálogo de verbos estandarizado y no ambiguo. Verbos recomendados de base (extensible por dominio):

| Verbo | Significado |
|---|---|
| `create` | Crear un recurso nuevo |
| `read` | Leer/consultar |
| `write` / `update` | Modificar un recurso existente |
| `delete` | Eliminar |
| `approve` | Aprobar un flujo (ej. pago, descuento) |
| `void` / `cancel` | Anular/cancelar |
| `execute` | Ejecutar una acción de negocio (ej. `apply_discount`, `reconcile`) |
| `export` | Extraer datos hacia fuera del sistema |
| `delegate` | Ceder temporalmente un privilegio a otro subject |

---

## 8. Separación estricta: Configuración vs. Evaluación

Esta es la distinción más importante para evitar ambigüedad en tu UI y en tu documentación técnica.

| | **Configuración (Rule Definition)** | **Evaluación (Decision)** |
|---|---|---|
| **Qué es** | La receta — la regla tal como se define, sin datos reales | El plato servido — el resultado de aplicar la receta a un caso concreto |
| **¿Tiene Subject real?** | No (solo el patrón de Subject esperado en el Target) | Sí — un usuario concreto en un instante concreto |
| **¿Tiene timestamp de ejecución?** | No | Sí — momento exacto del intento |
| **¿Tiene resultado Permit/Deny ya resuelto?** | No — solo describe bajo qué condición se decidiría | Sí — resultado concreto |
| **¿Es mutable?** | Sí (se puede editar la regla) | No — debe ser inmutable (WORM), es evidencia forense |
| **Tabla en bAuth** | `bos_atom_catalog` + `bos_atom_policy` | `bos_atom_audit` |
| **Badge de UI recomendado** | `[REGLA]` / `[POLÍTICA]` | `[DECISIÓN]` / `[AUDITORÍA]` (color visualmente distinto) |

**Regla de nomenclatura crítica:** nunca uses la palabra "Eval"/"Evaluación" para nombrar un nodo de configuración. Ese término debe reservarse exclusivamente para el momento en que el PDP efectivamente corre la Rule contra una solicitud real y produce uno de los cuatro Decision Values (§4).

---

## 9. Taxonomía de Subject y gestión de Sets de Roles a escala (1300+ roles)

### 9.1 El problema de escala

Con un catálogo de cientos o miles de roles, escribir el Subject de cada Rule como una lista literal (`rol IN (vendedor_senior, gerente_ventas, ...)`) es inviable: la misma lista se termina repitiendo en decenas de Rules distintas, y el día que cambie la composición de ese grupo (se agrega o quita un rol) hay que localizar y editar cada Rule que la contenía — exactamente el mismo problema de duplicación que ya identificamos en la sprawl documental de `REGISTRO-ESTADO.md`, pero aplicado a datos de autorización.

### 9.2 Los tipos de variación entre roles

Antes de escribir una Rule, conviene clasificar qué tipo de diferencia hay entre los roles que se ven afectados:

| Tipo | Naturaleza de la diferencia | Cómo se resuelve |
|---|---|---|
| **Tipo 1 — Aplicabilidad** | El rol simplemente tiene o no tiene asignada la Rule (no hay valor que varíe) | Presencia/ausencia de la asignación en `bos_role_atom`, vía Set (§9.3) |
| **Tipo 2 — Parámetro** | Misma lógica exacta, solo cambia un número/valor (ej. 15% vs 100%) | Una Rule por Set, cada Set con su propio valor en la Condition |
| **Tipo 3 — Lógica adicional** | La Condition cambia de forma (un rol requiere un AND extra que otro no) | Rules separadas — ya no es un simple parámetro, es una regla de negocio distinta |
| **Tipo 4 — Verbo/recurso distinto** | Los roles operan sobre verbos u objetos distintos (ej. uno solo lee, otro lee y escribe) | Atoms distintos por definición (§7) — no es una variación a resolver, son reglas separadas de por sí |

El caso más común en la práctica (Tipo 1 y Tipo 2) se resuelve con el mismo mecanismo: **Sets de Roles**.

### 9.3 Subject como taxonomía de tres formas

El campo `Subject` dentro del Target de cualquier Rule admite exactamente tres formas — no hay una cuarta:

```
Subject: rol_especifico         → aplica a UN solo rol
Subject: SET(nombre_del_set)    → aplica a un CONJUNTO de roles, declarado una sola vez
Subject: ANY                    → aplica a TODOS los roles (universal)
```

`Subject: ANY` no es un caso especial inventado — es el mismo concepto que ya reconoce el estándar: *"An empty `<Target>` matches any request"* (XACML 3.0, §2.4 de este manual). Un Target sin restricción de Subject ya es, por definición, universal.

### 9.4 Dominio `D98 · Registro Estructural` — declaración de Sets

Los Sets se declaran **una sola vez**, en un dominio dedicado, separado de los dominios de reglas de negocio. Se recomienda reservar el identificador **`D98`** para este propósito:

```
D98 · REGISTRO ESTRUCTURAL DE SETS DE ROLES        [REGISTRO ESTRUCTURAL]
  (no contiene Rules evaluables — no produce Permit/Deny, solo declara pertenencia)

  SET: tier_descuento_alto
    roles: [vendedor_senior]

  SET: tier_descuento_full
    roles: [gerente_ventas, cfo]

  SET: aprobadores_pago_nivel1
    roles: [analista_pagos, contador_junior]

  SET: aprobadores_pago_nivel2
    roles: [gerente_finanzas, cfo]
```

**Por qué se separa de los demás dominios (`D0`…`D97`, `D99`):**

| | Dominios de reglas de negocio (`D0`…`D97`) | `D98` (Registro Estructural) |
|---|---|---|
| Contenido | Rules con Target+Condition+Effect | Declaraciones de pertenencia rol→Set |
| ¿Produce una Decision (Permit/Deny)? | Sí | No |
| Ciclo de cambio | Cambia por política de negocio (compliance, nueva regla) | Cambia por movimiento organizacional (altas, bajas, cambios de puesto) |
| Dueño típico | Área de Negocio / Compliance | RRHH / Administración de Identidad |
| Tabla en bAuth | `bos_atom_catalog` + `bos_atom_policy` | `bos_group` (ya formalizada en el schema de 9 tablas) |
| Badge recomendado | `[POLICYSET]` / `[POLICY]` / `[REGLA]` | `[REGISTRO ESTRUCTURAL]` — nunca `[POLICYSET]`, porque no resuelve a una Decision |

**Regla de nomenclatura:** `D98` no lleva badge `[POLICYSET]` a pesar de estar al mismo nivel jerárquico que los demás dominios, precisamente porque no participa de ningún `PolicyCombiningAlgorithm` ni produce una Decision — es metadata de estructura, no lógica de autorización.

### 9.5 Ejemplo aplicado — descuento por Set (Tipo 2, corregido)

Retomando el caso del descuento: en vez de fusionar Target+Condition con comentarios en texto libre (`<= 15% (rol = vendedor_senior)` — ambiguo para un evaluador automático), cada Set obtiene su propia Rule, referenciando el Set declarado en `D98`:

```
Rule: descuento_max_tier_alto
  Target:
    Subject:  SET(tier_descuento_alto)     ← referencia a D98, no lista repetida
    Resource: sale.order
    Action:   apply_discount
  Condition: discount_percent <= 15 AND horario_laboral == true
  Effect: Permit

Rule: descuento_max_tier_full
  Target:
    Subject:  SET(tier_descuento_full)
    Resource: sale.order
    Action:   apply_discount
  Condition: discount_percent <= 100 AND horario_laboral == true
  Effect: Permit
```

Con 1300 roles, esto no implica 1300 Rules — implica un número reducido de Sets (los que efectivamente existan como categorías de negocio), y cada rol nuevo simplemente se agrega a un Set existente en `D98`, sin tocar ninguna Rule.

---

## 10. Plantilla de referencia para el árbol de configuración de rol

```yaml
D98 · REGISTRO ESTRUCTURAL DE SETS DE ROLES           [REGISTRO ESTRUCTURAL]
  SET: tier_descuento_alto
    roles: [vendedor_senior]
  SET: tier_descuento_full
    roles: [gerente_ventas, cfo]

PolicySet: "Tenant Empresarial X"                    # o "Dominio bos_domain"
PolicyCombiningAlgorithm: deny-overrides
Target: { tenant_id: X }

  Policy: "tryton.sale"                              # bos_application
  RuleCombiningAlgorithm: deny-overrides
  Target: { application: tryton.sale }

    Rule: "sale_order_discount_tier_alto"            # Atom de Aplicación
      Target:
        Subject:  SET(tier_descuento_alto)            ← referencia a D98
        Resource: { model: sale.order }
        Action:   { verb: apply_discount }
        Environment: { tenant: X }
      Condition:
        - discount_percent <= 15
        - horario_laboral == true
      Effect: Permit | Deny
      Obligation: registrar_en_bos_atom_audit
      Advice: "Descuento excede el máximo permitido para su rol"

    Rule: "sale_order_discount_tier_full"            # Atom de Aplicación
      Target:
        Subject:  SET(tier_descuento_full)            ← referencia a D98
        Resource: { model: sale.order }
        Action:   { verb: apply_discount }
        Environment: { tenant: X }
      Condition:
        - discount_percent <= 100
        - horario_laboral == true
      Effect: Permit | Deny
      Obligation: registrar_en_bos_atom_audit

  Rule (Guardrail): "payment_amount_threshold_check"  # Atom transversal, sin Policy padre
    application_id: NULL
    Target:
      Subject:  ANY                                    ← universal, aplica a todo rol autenticado
      Resource: { model: transaccion }
      Action:   { verb: procesar }
    Condition:
      - transaccion.amount > 3000
    Effect: Deny (requiere escalamiento) | Permit
```

---

## 11. Checklist de validación antes de publicar un template de rol

- [ ] Todo nodo hoja tiene los tres componentes obligatorios: **Target + Condition + Effect**.
- [ ] Todo nodo hoja tiene un **Verbo (`verb_id`) no nulo**.
- [ ] Toda **Policy** con más de una Rule declara explícitamente su **`RuleCombiningAlgorithm`**.
- [ ] Todo **PolicySet** con más de una Policy declara explícitamente su **`PolicyCombiningAlgorithm`**.
- [ ] Ningún nodo de configuración usa la palabra "Eval"/"Evaluación" en su badge — reservada solo para runtime.
- [ ] Los Atoms transversales (Guardrails) están marcados con `application_id = NULL` y documentados como autónomos (sin combining algorithm externo).
- [ ] El Effect de cada Rule es únicamente `Permit` o `Deny` — cualquier matiz adicional se resuelve con un verbo distinto, no con un tercer valor de Effect.
- [ ] Existe una Obligation definida para registrar en `bos_atom_audit` (WORM) cada decisión, incluyendo los casos `NotApplicable` e `Indeterminate`.
- [ ] Las Conditions con comparadores numéricos (`<=`, `>`, `IN`, `BETWEEN`) tienen resuelto si se evalúan como bits pre-categorizados (rangos) o como parámetro comparado por un mini-parser externo al bitmask puro.
- [ ] Ninguna Rule lista roles individuales repetidos en texto libre (`rol IN (a, b, c...)`) cuando ese mismo conjunto se repite en más de una Rule — debe declararse como **Set** (§9) y referenciarse por nombre.
- [ ] Todo Set de roles usado como Subject está declarado una única vez en el dominio **`D98 · Registro Estructural`**, no duplicado ni redefinido dentro de otro dominio.
- [ ] Ninguna diferencia entre roles que sea **solo de pertenencia a grupo** (Tipo 1, §9.2) fue resuelta escribiendo Rules o Conditions separadas por rol — debe resolverse con Sets.

---

## 12. Glosario rápido de equivalencias entre estándares

| Concepto | XACML 3.0 | NIST 800-162 (ABAC) | AWS IAM | bAuth / SBOS |
|---|---|---|---|---|
| Contenedor raíz de políticas | PolicySet | Policy (genérico) | Service Control Policy | Tenant / Dominio |
| Unidad de decisión por recurso | Policy | Policy | Identity/Resource-based Policy | Application (`bos_application`) |
| Unidad atómica evaluable | Rule | Rule | Statement | Atom (`bos_atom_catalog`) |
| Quién puede | Subject | Subject attribute | Principal | Rol (Dominio Lógico) |
| Sobre qué | Resource | Object attribute | Resource | Modelo/Campo |
| Qué acción | Action | Operation | Action | Verbo (`bos_verb`) |
| Bajo qué circunstancia | Environment / Condition | Environment attribute | Condition block | Dominio Contextual |
| Motor que decide | PDP | PDP | IAM Policy Evaluation Engine | BitMask Engine |
| Quién administra | PAP | PAP | IAM Console/API | UI de templates de rol |
| Quién intercepta la solicitud real | PEP | PEP | — (implícito en cada servicio AWS) | Middleware/Gateway bAuth |
| Fuente de atributos externos | PIP | PIP | — | `bos.GetContext()` (Context Plane) |
| Regla sin aplicación específica | Policy con Target vacío | — | Permission Boundary / SCP | Guardrail Atom |
| Grupo de subjects reutilizable | Atributo de grupo (Subject Category custom) | Grouping attribute | IAM Group | **Set de Roles** (`bos_group`) |
| Catálogo de pertenencia rol→Set | — (no normado explícitamente) | — | Group membership | **Dominio `D98` · Registro Estructural** |

---

## Fuentes normativas consultadas

- OASIS, *eXtensible Access Control Markup Language (XACML) Version 3.0*, especificación core (docs.oasis-open.org).
- NIST Special Publication 800-162, *Guide to Attribute Based Access Control (ABAC) Definition and Considerations*.
- Análisis complementario de estructura formal XACML 3.0 (coverage criteria, PMC/MDPI).
- Documentación de referencia XACML (WSO2, DZone, Datypic schema reference).

---

## 13. Anexo — Caso comparativo aplicado: Árbol de templates de rol SBOS

Este anexo toma el árbol real de configuración de rol capturado en la UI de bAuth (rama `D0 → D1 → D2`, bloques `B1…B7`) y lo compara **nodo por nodo** contra la estructura que exige el estándar (§1-§8 de este manual). El objetivo es servir de ejemplo de referencia y checklist de corrección — **no reemplaza ni invalida el árbol existente**, solo señala qué badges/atributos faltan para que sea 100% trazable a XACML 3.0 / NIST 800-162.

### 12.1 Árbol tal como está hoy (as-is)

```
D0 · IDENTIDAD ORGANIZACIONAL                    (sin badge)
  B1 · Identificación y metadatos                (sin badge)
  B3 · Flujo de aprobación                       (sin badge)

D1 · ACCESO LÓGICO                               (sin badge)
  B4 · Dominio lógico (autenticación)            (sin badge)
  B6 · Zonas de negocio                          (sin badge)
  B7 · Privilegios ERP (5 capas)                 (sin badge)
    model_access            [POLÍTICA]  CAPA 1 · CRUD por modelo
    visible_actions         [POLÍTICA]  CAPA 2 · menús visibles
    field_restrictions      [POLÍTICA]  CAPA 3 · campos individuales
      campo margin — oculto             [EVAL]
        propiedad: field.sale_order.margin
        operador (ENUM): visible_to_role
        valor: false
        efecto: omitir de respuesta JSON · campo omitido en SELECT
      campo cost_price — oculto         [EVAL]
        propiedad: field.product.cost_price
        operador (ENUM): visible_to_role
        valor: false
        efecto: omitir de respuesta JSON
      campo credit_limit — solo lectura [EVAL]
        propiedad: field.res_partner.credit_limit
        operador (ENUM): max_access
        valor: READ
        efecto: DENY write · HTTP 403 si intenta modificar
    button_rules            [POLÍTICA]  CAPA 4 · botones con PYSON
      venta ≤ 10 000 BOB — aprobación simple        [EVAL]
      venta 10 001–50 000 BOB — doble + WebAuthn     [EVAL]
      pago > 5 000 BOB — SoD                         [EVAL]
      venta > 50 000 BOB — fuera del tier 2           [EVAL]
    record_rules            [POLÍTICA]  CAPA 5 · filtros de fila

D2 · ACCESO FÍSICO                                (sin badge)
  B5 · Dominio físico                             (sin badge)
    metodos                                       (sin badge, corte de imagen)
```

### 12.2 Diagnóstico — qué corregir y por qué

| # | Nodo afectado | Problema detectado | Corrección según estándar |
|---|---|---|---|
| 1 | `D0`, `D1`, `D2` | No llevan badge. Al agrupar varios **B*** (que a su vez agrupan Policies), estructuralmente son **PolicySet** — no pueden quedar sin identificar. | Etiquetar como **`[POLICYSET]`**. Cada uno debe declarar su `PolicyCombiningAlgorithm`. |
| 2 | `B1`, `B3`, `B4`, `B6`, `B5` | Sin badge. Si contienen Rules directamente (sin sub-agrupar en más Policies), son **Policy**. Si a su vez agrupan sub-bloques de reglas, son **PolicySet** anidados. | Etiquetar como **`[POLICY]`** o **`[POLICYSET]`** según corresponda — nunca dejar un nivel jerárquico sin badge. |
| 3 | `B7 · Privilegios ERP (5 capas)` | Sin badge, pero agrupa **5 Policies** (`model_access`…`record_rules`). Estructuralmente es un **PolicySet**, no una Policy ni una capa neutra. | Etiquetar `B7` como **`[POLICYSET]`** con su propio `PolicyCombiningAlgorithm` (ver punto 6). |
| 4 | `campo margin — oculto`, `campo cost_price — oculto`, `campo credit_limit — solo lectura` | Etiquetados **`[EVAL]`** | Renombrar a **`[REGLA]`** o **`[ATOM]`** (§2.3, §8). "Eval" se reserva para el runtime/Decision, no para la definición. |
| 5 | Ítems bajo `button_rules` (los 4 rangos de monto) | Etiquetados **`[EVAL]`** | Mismo fix: **`[REGLA]`**. Además, actualmente el título fusiona Target+Condition en una sola frase libre ("venta ≤ 10 000 BOB — aprobación simple") — falta descomponerlo en `Target / Condition / Effect` explícitos (ver 12.3). |
| 6 | `field_restrictions`, `button_rules` (como Policy) | No exponen su `RuleCombiningAlgorithm`. | Declarar explícitamente. Para `field_restrictions`: recomendado **deny-overrides** (control de datos sensibles). Para `button_rules`: recomendado **first-applicable** (los tiers de monto son excluyentes por rango y el orden de evaluación importa) combinado con **deny-overrides** para la regla de SoD (que debe poder bloquear independientemente del tier). |
| 7 | Todas las Rules de `field_restrictions` y `button_rules` | Ninguna expone el campo **Verbo (Action)** de forma explícita — está implícito dentro de `efecto` (`omitir...`, `DENY write`, `aprobación simple`). | Cada Rule debe declarar su verbo como atributo propio del Target: `read` (visibilidad de campo), `write` (modificación), `approve`/`execute` (botones de flujo). Ningún Atom debe depender de inferir el verbo desde el texto del efecto (§7). |
| 8 | Rules de `button_rules` | No exponen `Subject` (¿qué rol dispara la regla `doble + WebAuthn`?) ni `Environment` explícito (monto es Condition, pero falta si aplica AAL2/AAL3 como atributo de contexto). | Completar el Target con Subject + Environment, no solo el monto como Condition aislada. |
| 9 | `record_rules` (CAPA 5) | Nodo colapsado, no se ve su contenido — no auditable desde la imagen. | Verificar que al expandirse siga el mismo patrón PolicySet→Policy→Rule y no introduzca un quinto nivel jerárquico no declarado. |
| 10 | `D2 → B5 → metodos` | Corte de imagen, badge no visible. | Aplicar la misma auditoría de nomenclatura una vez visible el nodo completo. |

### 12.3 Árbol corregido (ejemplo de referencia)

```
D0 · IDENTIDAD ORGANIZACIONAL                         [POLICYSET]
PolicyCombiningAlgorithm: deny-overrides

  B1 · Identificación y metadatos                     [POLICY]
  B3 · Flujo de aprobación                            [POLICY]

D1 · ACCESO LÓGICO                                    [POLICYSET]
PolicyCombiningAlgorithm: deny-overrides

  B4 · Dominio lógico (autenticación)                 [POLICY]
  B6 · Zonas de negocio                               [POLICY]

  B7 · Privilegios ERP (5 capas)                      [POLICYSET]
  PolicyCombiningAlgorithm: deny-overrides

    model_access                                      [POLICY]   · CAPA 1 · CRUD por modelo
    RuleCombiningAlgorithm: deny-overrides

    visible_actions                                   [POLICY]   · CAPA 2 · menús visibles
    RuleCombiningAlgorithm: deny-overrides

    field_restrictions                                [POLICY]   · CAPA 3 · campos individuales
    RuleCombiningAlgorithm: deny-overrides

      Regla: campo_margin_oculto                       [REGLA / ATOM]
        Target:
          Resource: field.sale_order.margin
          Action (verbo): read
        Condition: visible_to_role == false
        Effect: Deny (read)
        Obligation: omitir campo de respuesta JSON (campo excluido en SELECT)

      Regla: campo_cost_price_oculto                   [REGLA / ATOM]
        Target:
          Resource: field.product.cost_price
          Action (verbo): read
        Condition: visible_to_role == false
        Effect: Deny (read)
        Obligation: omitir campo de respuesta JSON

      Regla: campo_credit_limit_readonly                [REGLA / ATOM]
        Target:
          Resource: field.res_partner.credit_limit
          Action (verbo): write
        Condition: max_access == READ
        Effect: Deny (write) · Permit (read, regla implícita complementaria)
        Advice: "HTTP 403 — campo de solo lectura para este rol/contexto"

    button_rules                                       [POLICY]   · CAPA 4 · botones con PYSON
    RuleCombiningAlgorithm: first-applicable + deny-overrides (SoD)

      Regla: venta_tier1_aprobacion_simple              [REGLA / ATOM]
        Target:
          Subject:  rol IN (vendedor)
          Resource: sale.order
          Action (verbo): approve
        Condition: monto <= 10000 BOB
        Effect: Permit

      Regla: venta_tier2_doble_webauthn                 [REGLA / ATOM]
        Target:
          Subject:  rol IN (vendedor_senior, gerente_ventas)
          Resource: sale.order
          Action (verbo): approve
        Condition:
          - monto BETWEEN 10001 AND 50000 BOB
          - Environment: aal_level >= AAL2 (WebAuthn)
          - requiere segunda aprobación (four-eyes)
        Effect: Permit (si ambas aprobaciones + WebAuthn se cumplen) / Deny

      Regla: pago_sod_check                             [REGLA / ATOM — Guardrail]
        application_id: NULL (transversal, no exclusivo de sale.order)
        Target:
          Resource: payment.transaction
          Action (verbo): approve
        Condition:
          - monto > 5000 BOB
          - subject.id == transaccion.creado_por  → mismo usuario no puede aprobar su propio registro
        Effect: Deny (violación de Segregation of Duties)

      Regla: venta_tier3_fuera_de_alcance                [REGLA / ATOM]
        Target:
          Resource: sale.order
          Action (verbo): approve
        Condition: monto > 50000 BOB
        Effect: Deny (escalar a Tier 3 / comité de aprobación)

    record_rules                                       [POLICY]   · CAPA 5 · filtros de fila
    RuleCombiningAlgorithm: (pendiente de definir al expandir el nodo)

D2 · ACCESO FÍSICO                                    [POLICYSET]
PolicyCombiningAlgorithm: deny-overrides

  B5 · Dominio físico                                 [POLICY]
    metodos                                           [pendiente de auditar — nodo cortado en la imagen]
```

### 12.4 Resumen ejecutivo del anexo

- **Estructura de fondo:** correcta — el árbol ya respeta la jerarquía de agrupación (dominio → bloque → capa → regla) y separa apropiadamente Config de Evaluación.
- **Gap principal:** ausencia sistemática de **badges explícitos en los niveles contenedores** (`D*`, `B*`) — hoy se diferencia visualmente solo `POLÍTICA` vs `EVAL`, pero faltan `POLICYSET` para los niveles de agregación superiores.
- **Gap secundario:** el término `EVAL` debe renombrarse a `REGLA`/`ATOM` en toda la UI (aplica a los 7 nodos hoja visibles en la captura).
- **Gap técnico:** ningún nodo Policy/PolicySet visible expone su `Combining Algorithm` — es información crítica que hoy vive implícita (o no definida) y debe ser un campo de primera clase en el schema, no una convención tácita.
- **Gap de Target:** las Rules de `button_rules` mezclan Target+Condition+Effect en un único string descriptivo ("venta ≤ 10 000 BOB — aprobación simple") en vez de exponer los tres componentes por separado — dificulta tanto la auditoría automática como la reutilización de Conditions entre Rules similares.
