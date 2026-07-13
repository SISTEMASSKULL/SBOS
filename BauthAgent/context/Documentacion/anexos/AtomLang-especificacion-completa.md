# AtomLang — Especificación Completa: Problema, Lenguaje, Compilador y Resultado Esperado

**Tipo de documento:** Especificación técnica de diseño (Problem Statement + Especificación de lenguaje + Propuesta de implementación)
**Alcance:** Árbol de configuración de roles (templates) → AtomLang (lenguaje) → Compilador (`atomc`) → Árbol técnico ejecutable por el evaluador (PDP) de bAuth
**Referencia:** Árbol real `D1 · ACCESO LÓGICO → B4 · Dominio lógico (autenticación) → step_up_triggers`

---
## 1. Contexto

bAuth define privilegios y comportamiento de autenticación mediante un árbol de configuración jerárquico (Dominios → Bloques → Políticas → Atoms), escrito y mantenido por humanos a través de una UI. Ese árbol —el que hoy se ve en pantalla— es el **Árbol Fuente**.

Este árbol fuente eventualmente debe ser **evaluado por una máquina de estados determinística** (el motor BitMask / PDP) para decidir, en cada solicitud real, si algo se permite, se deniega, o se exige un paso adicional (step-up de autenticación, aprobación, etc.).

El problema surge en la **transición entre ambos**: el Árbol Fuente está escrito en un lenguaje semi-libre (strings, mayúsculas/minúsculas inconsistentes, texto descriptivo mezclado con datos estructurados), y hoy se asume —incorrectamente— que ese mismo árbol puede pasar directo al evaluador sin ninguna etapa intermedia de validación/normalización.

---

## 2. Problema detectado

### 2.1 Caso de referencia (árbol real analizado)

Dentro de `step_up_triggers` (Policy, `combining_algorithm: first-applicable`) existen 3 Atoms:

```
A1 · "monto de transacción alto (>10 000 BOB)"
   verbo: execute | propiedad: transaction.amount_bob | operador: > | valor: 10000
   efecto: required_loa=3, max_age_seconds=300, acr=aal3

A2 · "zona de alta seguridad"
   verbo: ANY | propiedad: zone.security_level | operador: == | valor: CRITICAL
   efecto: required_loa=3, max_age_seconds=600

A3 · "verbo CONFIGURE o ADMIN"
   verbo: configure | propiedad: action.verb | operador: IN | valor: [CONFIGURE, ADMIN, DELETE]
   efecto: required_loa=3, max_age_seconds=0 (fresca siempre)
```

Al **ejecutar** este árbol como lo haría un intérprete real (Target-gate → Condition → Combining Algorithm), se detectaron los siguientes defectos — ninguno visible mirando el árbol de forma jerárquica/visual, todos visibles solo al correr la máquina de estados:

| # | Defecto | Evidencia | Consecuencia |
|---|---|---|---|
| 1 | **Inconsistencia de case** entre el campo `verbo` (Target) y el `valor` (Condition) del mismo Atom | A3: `verbo = "configure"` (minúscula) vs `valor = ["CONFIGURE", "ADMIN", "DELETE"]` (mayúscula) | Con una solicitud real `action.verb = "CONFIGURE"`, el Target-gate de A3 (`"CONFIGURE" == "configure"`) falla por case-sensitivity → el Atom nunca se activa. El Atom pensado para exigir la re-autenticación **más estricta** (`max_age_seconds=0`) queda **silenciosamente inoperante**. |
| 2 | **Mismo atributo evaluado dos veces, con normalización distinta**, dentro del mismo Atom | A3 evalúa `verbo`/`action.verb` tanto en el Target-gate como otra vez en la Condition | Redundancia que introduce el propio defecto #1 — dos fuentes de verdad para el mismo dato, con dos formatos distintos. |
| 3 | **`first-applicable` sobre atoms independientes puede enmascarar requisitos más estrictos** | Si `amount_bob > 10000` **y** `zone == CRITICAL` ocurren a la vez, el algoritmo devuelve solo el efecto de A1 (`max_age_seconds=300`) e ignora el de A2 (`max_age_seconds=600`, más estricto) | El requisito de seguridad más alto se pierde por el orden de declaración, no por diseño intencional. |
| 4 | **Ausencia de badges explícitos en los nodos contenedores** (visto en el árbol completo, `D0/D1/D2`, `B1/B3/B4/B6/B7`) | Solo las hojas llevan `[ATOM]`/`[POLÍTICA]`; los niveles de agregación superiores no declaran si son `PolicySet` o `Policy` | Un validador automático no puede distinguir estructuralmente niveles de agregación sin inferencia manual. |
| 5 | **Verbo/Subject/Set expresados como texto libre**, no como referencia a catálogo | `verbo: configure` es un string, no un `verb_id` de `bos_verb`; roles listados inline en vez de referenciar `SET(...)` de `bos_group` | Cualquier variante ortográfica (espacio, mayúscula, sinónimo) rompe el matching sin que el sistema lo detecte antes de producción. |
| 6 | **No existe una etapa de validación entre "lo que el humano escribió" y "lo que la máquina ejecuta"** | El árbol fuente se asume ejecutable tal cual | Los defectos #1-#5 llegan directo a runtime; se descubren por auditoría manual o, peor, por un incidente de seguridad real. |

### 2.2 Diagnóstico de fondo

El problema **no es de contenido lógico** (el diseño de las reglas de step-up es correcto en su intención) — **es de lenguaje**: el Árbol Fuente permite representar el mismo concepto de más de una forma (`configure` vs `CONFIGURE`, roles listados vs Set referenciado, verbo como texto vs verbo como ID), y un lenguaje que permite más de una representación para el mismo significado es, por definición, no determinístico para una máquina.

---

## 3. Qué queremos obtener (objetivo)

### 3.1 Objetivo general

Definir un **lenguaje estructurado de Atoms ("AtomLang")** con gramática cerrada, de modo que:

1. Todo elemento del árbol (Dominio, Bloque, Política, Atom, Verbo, Subject, Operador, Effect, Combining Algorithm) tenga **un tipo formal y un vocabulario cerrado** — nunca texto libre donde hoy hay ambigüedad.
2. Exista una **etapa de compilación obligatoria** entre el árbol que escribe el humano (Árbol Fuente) y el árbol que ejecuta el motor (Árbol Técnico) — nunca se evalúa el Árbol Fuente directamente.
3. El compilador **rechace** (no "corrija en silencio") cualquier Árbol Fuente que no cumpla la gramática — igual que un compilador de un lenguaje de programación real rechaza código con errores de sintaxis o de tipos.
4. El **Árbol Técnico resultante** sea 100% determinístico: solo IDs, enums y valores tipados — cero strings comparados por igualdad textual en tiempo de evaluación.

### 3.2 Los dos árboles (definición formal)

| | **Árbol Fuente** | **Árbol Técnico (Canonical / IR)** |
|---|---|---|
| Quién lo produce | Humano vía UI/YAML/JSON | El compilador, a partir del Árbol Fuente |
| Lenguaje | Controlado pero legible (nombres, descripciones) | Puramente simbólico: IDs, enums, referencias FK |
| ¿Se ejecuta directamente? | No, nunca | Sí — es el único input del evaluador (PDP) |
| Rol | Documentación + fuente de edición | Artefacto de ejecución |
| Analogía | Código fuente | Bytecode / AST compilado |
| Tabla en bAuth (hoy) | `bos_atom_catalog` + `bos_atom_policy` | *(a definir — nueva tabla/vista, ver §4)* |

### 3.3 Requisitos del grafo de dependencias (jerarquía de pertenencia)

```
Tenant
  └── Dominio (PolicySet)
        └── Bloque (Policy | PolicySet anidado)
              └── Política (Policy)
                    ├── combining_algorithm      [obligatorio si tiene 2+ Atoms]
                    └── Atom (Rule)
                          ├── Verbo               → FK a bos_verb (enum cerrado)
                          ├── Target
                          │     ├── Subject        → Rol (FK) | SET (FK a bos_group) | ANY
                          │     ├── Resource       → FK a modelo/campo
                          │     └── Environment    → FK a atributo de contexto (PIP)
                          ├── Condition             → predicado (property, operator enum, value tipado)
                          └── Effect                → Permit | Deny  (+ Obligation tipada aparte)

Catálogos externos (nunca redefinidos inline dentro de un Atom):
  bos_verb   — vocabulario cerrado de verbos
  bos_group  — Sets de roles (declarados en D98 · Registro Estructural)
```

**Regla dura de dependencia:** una entidad solo contiene entidades del nivel inmediato inferior; los catálogos (`bos_verb`, `bos_group`) solo se **referencian** por ID, nunca se copian como texto dentro de un Atom.

### 3.4 Requisitos de tipado por nodo

| Campo | Tipo exigido | Elimina el defecto § |
|---|---|---|
| `verbo` (Target.Action) | `enum(bos_verb.verb_id)` | #1, #2, #5 |
| `Subject` | `union(role_id \| set_id \| ANY)` | #5 |
| `operador` (Condition) | `enum(">","<","==","IN","BETWEEN",...)` cerrado | #1 |
| `valor` (Condition) | tipado según `property` (numérico, enum, lista de enum — nunca string libre comparado por igualdad) | #1 |
| `combining_algorithm` | `enum(deny-overrides, permit-overrides, first-applicable, deny-unless-permit, ...)` | #3 |
| `Effect` | `enum(Permit, Deny)` — matices van en `Obligation` tipada, nunca en el Effect | — |
| Todo nodo contenedor (`Dominio`, `Bloque`, `Política`) | badge obligatorio `PolicySet` \| `Policy` \| `REGISTRO ESTRUCTURAL` | #4 |

### 3.5 Requisitos del compilador (pipeline de 3 fases)

```
Fase 1 — Lexer/Tokenizer
  Recorre el Árbol Fuente; resuelve cada string contra su Enum/FK correspondiente.
  Si un valor no matchea ningún ID conocido → ERROR de compilación (no se genera Árbol Técnico).

Fase 2 — Parser / Validador semántico
  Verifica el grafo de dependencias (§3.3):
    - Ningún Atom fuera de una Política.
    - Ninguna Política con 2+ Atoms sin combining_algorithm declarado.
    - Ningún Subject con roles listados inline si ya existe un Set equivalente en D98.
    - Ningún atributo repetido entre Target y Condition del mismo Atom (defecto #2).
    - Todo nodo contenedor con badge explícito (defecto #4).

Fase 3 — Generador de Árbol Técnico
  Emite el árbol final en forma canónica (JSON/IR), listo para el evaluador —
  sin strings comparables por igualdad textual, solo IDs/enums/valores tipados.
```

### 3.6 Requisito del evaluador (una vez resuelto el árbol técnico)

El evaluador (PDP) debe operar **exclusivamente** sobre el Árbol Técnico, aplicando la máquina de estados formal ya definida:

```
Target-gate: Match | No-Match | Indeterminate
Condition (solo si Target=Match): True | False | Indeterminate
Rule → NotApplicable | Indeterminate | Permit(Effect) | Deny(Effect)
Combining Algorithm → reduce la lista de resultados de Rules/Policies a una única Decision
```

Y debe resolver explícitamente el caso del defecto #3 (múltiples Atoms aplicables simultáneamente con requisitos distintos de `required_loa`/`max_age_seconds`): el objetivo es que el `combining_algorithm` para Policies de step-up **agregue** los efectos más estrictos entre todos los Atoms que apliquen (ej. tomar el máximo `required_loa` y el mínimo `max_age_seconds` entre todos los `Permit` concurrentes), no que se quede con el primero según orden de declaración.

---

## 4. Brecha entre lo que existe hoy y lo que se necesita

| Componente | Estado actual | Estado objetivo |
|---|---|---|
| Árbol Fuente | Existe (UI, `bos_atom_catalog`) | Se mantiene, pero deja de ser ejecutable directamente |
| Gramática formal de AtomLang | No existe — el "lenguaje" es implícito y libre | Definir EBNF/JSON Schema completo (siguiente entregable) |
| Catálogo cerrado de verbos | Existe (`bos_verb`) pero se referencia por string, no siempre por ID | Forzar referencia exclusiva por `verb_id` en el compilador |
| Catálogo de Sets | Existe conceptualmente (`bos_group`, dominio `D98`) | Formalizar como única fuente de Subject grupal — prohibir listas inline |
| Compilador (Lexer/Parser/Validador) | No existe | Construir como etapa obligatoria antes de cualquier publicación de rol |
| Árbol Técnico / IR | No existe como artefacto propio | Definir su esquema (tabla o vista materializada `bos_atom_compiled`) |
| Evaluador (PDP) | Opera hoy directamente sobre datos semi-libres | Debe migrar a operar exclusivamente sobre el Árbol Técnico |
| Combining algorithm agregador (para step-up) | `first-applicable` simple (con el riesgo del defecto #3) | Definir/soportar un algoritmo de agregación de efectos (max/min) para Policies de tipo step-up |

---

## 5. Estructura formal del Atom (especificación de tipo — JSON Schema)

Esta es la definición de tipo que cualquier implementador (humano o agente de IA) debe usar como contrato exacto. Ningún campo puede quedar como string libre donde aquí se declara `enum`, `FK` o tipo estricto.

```json
{
  "$id": "AtomLang.Atom.v1",
  "type": "object",
  "required": ["atom_id", "verb_id", "target", "effect"],
  "additionalProperties": false,
  "properties": {
    "atom_id": {
      "type": "string",
      "pattern": "^[a-z][a-z0-9_]{2,63}$",
      "description": "Identificador único, snake_case, inmutable una vez publicado."
    },
    "application_id": {
      "type": ["integer", "null"],
      "description": "FK a bos_application. null == Guardrail Atom (§6.2 del manual base)."
    },
    "policy_id": {
      "type": ["integer", "null"],
      "description": "FK a la Policy contenedora. null solo permitido si application_id también es null."
    },
    "verb_id": {
      "type": "integer",
      "description": "FK obligatoria a bos_verb.verb_id. PROHIBIDO representar el verbo como string en cualquier otro campo del Atom."
    },
    "target": {
      "type": "object",
      "required": ["resource_id"],
      "additionalProperties": false,
      "properties": {
        "subject": {
          "oneOf": [
            { "type": "object", "required": ["kind","role_id"], "properties": {
                "kind": { "const": "ROLE" }, "role_id": { "type": "integer" } } },
            { "type": "object", "required": ["kind","set_id"], "properties": {
                "kind": { "const": "SET" },  "set_id": { "type": "integer", "description": "FK a bos_group, declarado únicamente en D98" } } },
            { "type": "object", "required": ["kind"], "properties": {
                "kind": { "const": "ANY" } } }
          ],
          "default": { "kind": "ANY" }
        },
        "resource_id": {
          "type": "integer",
          "description": "FK al catálogo de modelos/campos (bos_resource_catalog). Nunca un string tipo 'sale.order.margin'."
        },
        "environment": {
          "type": "array",
          "items": { "$ref": "#/definitions/attribute_ref" },
          "description": "Atributos de contexto exigidos como parte del Target (ej. tenant_id, device.trusted). Cada uno resuelto por el PIP."
        }
      }
    },
    "condition": {
      "type": ["object", "null"],
      "additionalProperties": false,
      "properties": {
        "operator": {
          "enum": [">", "<", ">=", "<=", "==", "!=", "IN", "NOT_IN", "BETWEEN"],
          "description": "Vocabulario cerrado. Ningún otro símbolo es válido; el compilador rechaza cualquier operador fuera de esta lista."
        },
        "property_id": {
          "type": "integer",
          "description": "FK a bos_attribute_catalog. Define también el data_type esperado de 'value' (numeric, enum, string_enum, boolean, list)."
        },
        "value": {
          "description": "Tipo dinámico, determinado por property_id.data_type en el catálogo. Si property_id.data_type == 'enum', value DEBE resolver contra el mismo enum registrado — nunca comparado como string crudo."
        }
      },
      "default": null,
      "description": "Condition ausente (null) se evalúa siempre como True (equivalente XACML: 'An empty Condition is always evaluated to true')."
    },
    "effect": {
      "type": "object",
      "required": ["decision"],
      "additionalProperties": false,
      "properties": {
        "decision": { "enum": ["Permit", "Deny"] },
        "obligation": {
          "type": "object",
          "additionalProperties": true,
          "description": "Efectos secundarios OBLIGATORIOS para el PEP (ej. required_loa, max_age_seconds, acr, registrar_en_audit). Tipados por clave, no texto libre concatenado."
        },
        "advice": {
          "type": ["string", "null"],
          "description": "Mensaje informativo, el PEP puede ignorarlo. Nunca contiene lógica de decisión."
        }
      }
    },
    "is_control_plane": {
      "type": "boolean",
      "default": false,
      "description": "true si el Atom regula la configuración del propio sistema de autorización (ej. configure step_up_triggers), no datos de negocio."
    }
  },
  "definitions": {
    "attribute_ref": {
      "type": "object",
      "required": ["property_id", "operator", "value"],
      "properties": {
        "property_id": { "type": "integer" },
        "operator": { "enum": [">", "<", ">=", "<=", "==", "!=", "IN", "NOT_IN", "BETWEEN"] },
        "value": {}
      }
    }
  }
}
```

**Reglas de validación semántica que el JSON Schema por sí solo NO puede expresar (van en el Validador, Fase 2 del compilador):**

1. Si `property_id` referenciado en `condition` es el mismo `property_id` usado para resolver `target.subject` o `verb_id` → **error de compilación** ("atributo duplicado entre Target y Condition", defecto #2 del problema detectado).
2. Si `policy_id` referencia una Policy con 2+ Atoms hermanos y esa Policy no tiene `combining_algorithm` declarado → **error de compilación**.
3. Si `target.subject.kind == "ROLE"` y existe un `SET` en `bos_group` cuya membresía es idéntica al conjunto de roles que se intenta expresar de forma repetida en 2+ Atoms → **warning de compilación** ("posible duplicación, considere declarar un SET").

---

## 6. Estructura del Árbol Técnico compilado (Compiled Tree / IR)

El Árbol Técnico es el único artefacto que el evaluador (PDP) consume. Es la salida de la Fase 3 del compilador — nunca se edita a mano.

```json
{
  "$id": "AtomLang.CompiledTree.v1",
  "type": "object",
  "required": ["policy_sets"],
  "properties": {
    "policy_sets": {
      "type": "array",
      "items": { "$ref": "#/definitions/policy_set" }
    }
  },
  "definitions": {
    "policy_set": {
      "type": "object",
      "required": ["policy_set_id", "combining_algorithm", "children"],
      "properties": {
        "policy_set_id": { "type": "integer" },
        "target": { "$ref": "#/definitions/target_filter" },
        "combining_algorithm": { "$ref": "#/definitions/combining_algorithm" },
        "children": {
          "type": "array",
          "items": { "oneOf": [ { "$ref": "#/definitions/policy" }, { "$ref": "#/definitions/policy_set" } ] }
        }
      }
    },
    "policy": {
      "type": "object",
      "required": ["policy_id", "combining_algorithm", "atoms"],
      "properties": {
        "policy_id": { "type": "integer" },
        "application_id": { "type": ["integer", "null"] },
        "combining_algorithm": { "$ref": "#/definitions/combining_algorithm" },
        "atoms": { "type": "array", "items": { "$ref": "AtomLang.Atom.v1" } }
      }
    },
    "combining_algorithm": {
      "enum": ["deny-overrides", "permit-overrides", "first-applicable", "deny-unless-permit", "permit-unless-deny", "aggregate-strictest"]
    },
    "target_filter": {
      "type": "object",
      "description": "Target opcional a nivel PolicySet/Policy — filtra qué Atoms hijos siquiera se evalúan para este contexto (ej. tenant_id)."
    }
  }
}
```

**Nota sobre `aggregate-strictest`:** este es un `combining_algorithm` que **no existe en XACML 3.0 estándar** — se define aquí como extensión propia de bAuth para resolver el defecto #3 (§2.1 del problema detectado). En vez de devolver el primer `Permit` (como `first-applicable`) o el primero que cierre en `Deny`/`Permit`, **recorre todos los resultados `Permit` de la Policy y combina sus Obligations tomando, atributo por atributo, el valor más estricto** (ver algoritmo formal en §7.4).

---

## 7. Algoritmo formal de evaluación (especificación ejecutable)

Esta sección define el evaluador con precisión de pseudocódigo tipado — cualquier agente de IA o desarrollador debe poder implementar esto sin ambigüedad adicional, sin necesitar inferir intención.

### 7.1 Tipos de estado (enum cerrado, ya formalizado en el manual base)

```
DecisionState = Permit | Deny | NotApplicable | Indeterminate
```

### 7.2 Evaluación de un Atom individual

```
function evaluate_atom(atom: Atom, ctx: RequestContext) -> AtomResult:

    # ETAPA 1 — Target-gate (obligatoria, se evalúa SIEMPRE primero)
    if not resolve(ctx, atom.verb_id) == ctx.request_verb_id:
        return AtomResult(atom.atom_id, NotApplicable, effect=null)

    if atom.target.subject.kind == "ROLE":
        if ctx.subject_role_id != atom.target.subject.role_id:
            return AtomResult(atom.atom_id, NotApplicable, effect=null)
    elif atom.target.subject.kind == "SET":
        if ctx.subject_role_id not in resolve_set_members(atom.target.subject.set_id):
            return AtomResult(atom.atom_id, NotApplicable, effect=null)
    # kind == "ANY" -> siempre pasa

    if atom.target.resource_id != ctx.resource_id:
        return AtomResult(atom.atom_id, NotApplicable, effect=null)

    for env_ref in atom.target.environment:
        value = pip.resolve(ctx, env_ref.property_id)
        if value is None:
            return AtomResult(atom.atom_id, Indeterminate, effect=null)
        if not apply_operator(env_ref.operator, value, env_ref.value):
            return AtomResult(atom.atom_id, NotApplicable, effect=null)

    # ETAPA 2 — Condition (solo alcanzable si TODO el Target hizo Match)
    if atom.condition is None:
        condition_result = True
    else:
        value = pip.resolve(ctx, atom.condition.property_id)
        if value is None:
            return AtomResult(atom.atom_id, Indeterminate, effect=null)
        condition_result = apply_operator(atom.condition.operator, value, atom.condition.value)

    if not condition_result:
        return AtomResult(atom.atom_id, NotApplicable, effect=null)

    return AtomResult(atom.atom_id, atom.effect.decision, atom.effect)
```

**Invariante crítica (formaliza lo discutido en la conversación previa):** la Condition **nunca** se evalúa si el Target-gate no cerró en Match. Un evaluador que evalúe Condition antes de confirmar Target-gate produce resultados falsos — este fue exactamente el error detectado y corregido en el análisis previo del árbol `step_up_triggers`.

### 7.3 Combinación estándar (algoritmos ya normados por XACML)

```
function combine(results: List[AtomResult], algorithm: CombiningAlgorithm) -> PolicyResult:

    if algorithm == "deny-overrides":
        if any(r.state == Deny for r in results): return Deny(first Deny's effect)
        if any(r.state == Indeterminate for r in results): return Indeterminate
        if any(r.state == Permit for r in results): return Permit(first Permit's effect)
        return NotApplicable

    if algorithm == "permit-overrides":
        if any(r.state == Permit for r in results): return Permit(first Permit's effect)
        if any(r.state == Indeterminate for r in results): return Indeterminate
        if any(r.state == Deny for r in results): return Deny(first Deny's effect)
        return NotApplicable

    if algorithm == "first-applicable":
        for r in results:
            if r.state in (Permit, Deny): return r
        return NotApplicable

    if algorithm == "deny-unless-permit":
        if any(r.state == Permit for r in results): return Permit(first Permit's effect)
        return Deny(default_effect)
```

### 7.4 Algoritmo de agregación (`aggregate-strictest`) — extensión bAuth para resolver el defecto #3

```
function combine_aggregate_strictest(results: List[AtomResult]) -> PolicyResult:

    permits = [r for r in results if r.state == Permit]
    if len(permits) == 0:
        return combine(results, "deny-overrides")   # fallback si nadie aplica

    # Agregación campo por campo de las Obligations de TODOS los Permit concurrentes
    merged_obligation = {}
    for r in permits:
        for key, value in r.effect.obligation.items():
            if key not in merged_obligation:
                merged_obligation[key] = value
            else:
                merged_obligation[key] = strictest(key, merged_obligation[key], value)

    return Permit(effect={ "decision": "Permit", "obligation": merged_obligation })


function strictest(key: str, a, b):
    # Reglas de "qué valor es más estricto" — deben declararse por atributo en bos_attribute_catalog
    if key in ("required_loa", "acr_level"):
        return max(a, b)              # exigir el nivel de garantía MÁS ALTO
    if key in ("max_age_seconds",):
        return min(a, b)              # exigir la sesión MÁS FRESCA (menor tolerancia)
    raise ConfigError(f"no hay regla de 'strictest' definida para el atributo {key}")
```

Aplicado al caso real: si `A1` (Permit, `max_age_seconds=300`) y `A2` (Permit, `max_age_seconds=600`) matchean simultáneamente, `aggregate-strictest` devuelve `max_age_seconds = min(300, 600) = 300` (la más exigente) en vez del resultado arbitrario que producía `first-applicable`.

---

## 8. Gramática EBNF del lenguaje humano (Árbol Fuente)

Esta es la gramática que el **Lexer/Parser (Fase 1-2 del compilador)** usa para aceptar o rechazar lo que un humano escribe en la UI/YAML, antes de generar el Árbol Técnico. Cualquier construcción fuera de esta gramática es un error de sintaxis, no una "interpretación flexible".

```ebnf
(* AtomLang — Gramática del Árbol Fuente v1.0 *)

arbol_fuente      = { dominio } , dominio_registro_estructural ;

dominio           = "Dominio" , identificador , badge_dominio ,
                     [ combining_algorithm ] ,
                     { bloque | politica } ;

badge_dominio     = "[POLICYSET]" ;

dominio_registro_estructural
                  = "Dominio" , "D98" , "[REGISTRO ESTRUCTURAL]" ,
                    { declaracion_set } ;

declaracion_set   = "SET" , identificador , "roles" , ":" , "[" , { rol_id } , "]" ;

bloque            = "Bloque" , identificador , ( badge_policy | badge_dominio ) ,
                     [ combining_algorithm ] ,
                     { bloque | politica } ;

politica          = "Politica" , identificador , badge_policy ,
                     combining_algorithm ,
                     { atomo } ;

badge_policy      = "[POLICY]" ;

atomo             = "Atomo" , identificador , badge_atomo ,
                     "verbo" , ":" , verbo_ref ,
                     "target" , ":" , target ,
                     [ "condition" , ":" , condicion ] ,
                     "effect" , ":" , effect ;

badge_atomo       = "[ATOM]" | "[REGLA]" ;

verbo_ref         = identificador ;              (* DEBE existir en catálogo bos_verb — validado en Fase 1 *)

target            = "subject" , ":" , subject ,
                     "resource" , ":" , resource_ref ,
                     [ "environment" , ":" , "[" , { atributo_ref } , "]" ] ;

subject           = ( "ROL" , "(" , rol_id , ")" )
                  | ( "SET" , "(" , set_id , ")" )
                  | "ANY" ;

resource_ref      = identificador ;              (* DEBE existir en catálogo de recursos *)

condicion         = atributo_ref ;

atributo_ref      = propiedad_id , operador , valor ;

operador          = ">" | "<" | ">=" | "<=" | "==" | "!=" | "IN" | "NOT_IN" | "BETWEEN" ;

effect            = "decision" , ":" , ( "Permit" | "Deny" ) ,
                     [ "obligation" , ":" , mapa_tipado ] ,
                     [ "advice" , ":" , cadena ] ;

combining_algorithm
                  = "combining_algorithm" , ":" ,
                    ( "deny-overrides" | "permit-overrides" | "first-applicable"
                    | "deny-unless-permit" | "permit-unless-deny" | "aggregate-strictest" ) ;

identificador     = letra_minuscula , { letra_minuscula | digito | "_" } ;   (* snake_case obligatorio, sin excepción *)

rol_id            = identificador ;
set_id            = identificador ;
propiedad_id      = identificador ;
mapa_tipado       = "{" , { clave , ":" , valor_tipado } , "}" ;
```

**Reglas léxicas obligatorias (Fase 1, antes de siquiera intentar el parseo):**

1. Todo `identificador` se normaliza a **minúscula + snake_case** en la frontera de entrada — el Lexer rechaza (no corrige) cualquier variante con mayúsculas, espacios o guiones, exigiendo que el autor lo corrija en el Árbol Fuente.
2. Todo `verbo_ref`, `resource_ref`, `rol_id`, `set_id` se resuelve contra su catálogo correspondiente **en esta misma fase** — si no existe, error de compilación con el mensaje `"<valor> no está registrado en <catálogo>"`.
3. Ningún `valor` dentro de `atributo_ref` se compara nunca como string crudo contra el Árbol Técnico — se resuelve primero a su tipo declarado en `bos_attribute_catalog` (numeric, boolean, enum_ref, list_of_enum_ref).

---

## 9. Ejemplo end-to-end: Fuente → Validación → Árbol Técnico → Evaluación

### 9.1 Árbol Fuente (como lo escribiría un humano, ya conforme a la gramática §8)

```yaml
Politica: step_up_triggers
  combining_algorithm: aggregate-strictest    # corregido — ya no first-applicable

  Atomo: monto_transaccion_alto
    verbo: execute
    target:
      subject: ANY
      resource: transaccion
      environment: []
    condition:
      propiedad: transaction_amount_bob
      operador: ">"
      valor: 10000
    effect:
      decision: Permit
      obligation: { required_loa: 3, max_age_seconds: 300, acr: aal3 }

  Atomo: zona_alta_seguridad
    verbo: any_verb                            # verbo genérico registrado en catálogo, no el texto "ANY"
    target:
      subject: ANY
      resource: zona
    condition:
      propiedad: zone_security_level
      operador: "=="
      valor: critical
    effect:
      decision: Permit
      obligation: { required_loa: 3, max_age_seconds: 600 }

  Atomo: verbo_administrativo
    verbo: configure                            # único, normalizado, sin variante mayúscula posible
    target:
      subject: ANY
      resource: sistema_auth
    condition: null                             # el Target-gate del verbo YA es el criterio completo — sin duplicar (corrige defecto #2)
    effect:
      decision: Permit
      obligation: { required_loa: 3, max_age_seconds: 0 }
```

### 9.2 Paso por el compilador

```
Fase 1 (Lexer):
  "execute"      → resuelve a verb_id=5 en bos_verb           ✓
  "any_verb"     → resuelve a verb_id=0 (comodín registrado)   ✓
  "configure"    → resuelve a verb_id=7 en bos_verb            ✓
  "transaccion", "zona", "sistema_auth" → resuelven a resource_id en catálogo   ✓
  Ningún identificador viola snake_case.                        ✓

Fase 2 (Validador semántico):
  Policy "step_up_triggers" tiene 3 Atoms y declara combining_algorithm.   ✓
  Ningún Atom repite el mismo property_id entre target y condition.       ✓
  "verbo_administrativo" no tiene Condition redundante con el Target-gate. ✓
  → Compilación EXITOSA.

Fase 3 (Generador de IR): produce el Árbol Técnico (JSON, §6) con solo IDs.
```

### 9.3 Árbol Técnico resultante (fragmento, IDs simbólicos por legibilidad)

```json
{
  "policy_id": 42,
  "combining_algorithm": "aggregate-strictest",
  "atoms": [
    { "atom_id": "monto_transaccion_alto", "verb_id": 5, "target": {"subject":{"kind":"ANY"},"resource_id": 101},
      "condition": {"property_id": 30, "operator": ">", "value": 10000},
      "effect": {"decision":"Permit","obligation":{"required_loa":3,"max_age_seconds":300,"acr":"aal3"}} },
    { "atom_id": "zona_alta_seguridad", "verb_id": 0, "target": {"subject":{"kind":"ANY"},"resource_id": 102},
      "condition": {"property_id": 31, "operator": "==", "value": "critical"},
      "effect": {"decision":"Permit","obligation":{"required_loa":3,"max_age_seconds":600}} },
    { "atom_id": "verbo_administrativo", "verb_id": 7, "target": {"subject":{"kind":"ANY"},"resource_id": 103},
      "condition": null,
      "effect": {"decision":"Permit","obligation":{"required_loa":3,"max_age_seconds":0}} }
  ]
}
```

### 9.4 Evaluación en runtime — Request Context concurrente

```
ctx = { request_verb_id: 5, transaction_amount_bob: 15000, zone_security_level: "critical", resource_id: 101 }
```

```
evaluate_atom(monto_transaccion_alto, ctx)   → Permit, obligation={loa:3, max_age:300, acr:aal3}
evaluate_atom(zona_alta_seguridad, ctx)      → Target-gate: verb_id=0 (comodín) matchea siempre;
                                                 resource_id target=102 ≠ ctx.resource_id=101 → NotApplicable
evaluate_atom(verbo_administrativo, ctx)     → Target-gate: verb_id=7 ≠ ctx.verb_id=5 → NotApplicable

combine([Permit, NotApplicable, NotApplicable], "aggregate-strictest")
  → solo hay 1 Permit → obligation final = {loa:3, max_age:300, acr:aal3}
```

Con un segundo contexto donde `resource_id` coincide para ambos (`monto_transaccion_alto` y `zona_alta_seguridad` aplican a la vez):

```
combine([Permit(max_age:300), Permit(max_age:600)], "aggregate-strictest")
  → merged_obligation.max_age_seconds = min(300, 600) = 300
  → merged_obligation.required_loa    = max(3, 3) = 3
  → Resultado: Permit, obligation = {required_loa:3, max_age_seconds:300}
```

El requisito más estricto (300s, no 600s por accidente de orden) se preserva de forma determinística — el defecto #3 del problema original queda formalmente resuelto por diseño del algoritmo, no por convención de quien escribe el árbol.

---

## 10. Propuesta del Lenguaje

### 10.1 Nombre y extensión de archivo

| | Propuesta |
|---|---|
| Nombre del lenguaje | **AtomLang** |
| Extensión de archivo fuente | `.atm.yaml` (ej. `step_up_triggers.atm.yaml`) |
| Extensión del artefacto compilado (IR) | `.atm.json` (nunca editado a mano — solo generado) |
| Ubicación sugerida en el filesystem de SBOS | `/opt/skull/orquestador/proyectos/desarrollo/sbos/bauth/atoms/src/*.atm.yaml` (fuente) → `/opt/skull/.../bauth/atoms/compiled/*.atm.json` (IR, generado, ignorado por git salvo el último build validado) |

### 10.2 Filosofía de diseño: YAML restringido, no un lenguaje desde cero

**Decisión de diseño central:** AtomLang **no inventa una sintaxis nueva** — es **YAML con una gramática restringida encima** (un "superset controlado"), validado por JSON Schema (§5 de este documento) + reglas semánticas adicionales.

**Por qué esta decisión y no un lenguaje custom (tipo el EBNF completo de un parser desde cero):**

| Alternativa | Costo | Beneficio |
|---|---|---|
| Lenguaje custom (parser propio, sintaxis propia) | Alto — hay que escribir lexer/parser desde cero, y cada desarrollador/agente de IA debe aprender una sintaxis nueva | Control total sobre la gramática |
| **YAML + JSON Schema + validador semántico (propuesta)** | Bajo — YAML ya lo parsean todas las librerías estándar (Go, Rust, Python, Node); el compilador solo agrega la capa de validación | Cualquier agente de IA ya "sabe" escribir YAML válido; el trabajo se reduce a **restringir**, no a **enseñar sintaxis nueva** |

Esto es coherente con tu propio patrón en SBOS: `fabrica.sh`, `CLAUDE.md`, tus specs (`SBOS-0XX-*.md`) ya usan YAML/Markdown como formato base — AtomLang se integra al mismo hábito, en vez de introducir un formato ajeno.

### 10.3 Sintaxis final propuesta (ejemplo canónico)

```yaml
# step_up_triggers.atm.yaml
atomlang_version: 1

policy:
  policy_id: step_up_triggers
  application_id: null          # null = Guardrail-level Policy (autenticación, no negocio)
  combining_algorithm: aggregate-strictest

  atoms:
    - atom_id: monto_transaccion_alto
      verbo: execute
      target:
        subject: ANY
        resource: transaccion
      condition:
        propiedad: transaction_amount_bob
        operador: ">"
        valor: 10000
      effect:
        decision: Permit
        obligation:
          required_loa: 3
          max_age_seconds: 300
          acr: aal3

    - atom_id: zona_alta_seguridad
      verbo: any_verb
      target:
        subject: ANY
        resource: zona
      condition:
        propiedad: zone_security_level
        operador: "=="
        valor: critical
      effect:
        decision: Permit
        obligation:
          required_loa: 3
          max_age_seconds: 600

    - atom_id: verbo_administrativo
      verbo: configure
      target:
        subject: ANY
        resource: sistema_auth
      condition: null
      effect:
        decision: Permit
        obligation:
          required_loa: 3
          max_age_seconds: 0
```

### 10.4 Reglas de estilo obligatorias (enforced por linter, no por convención)

1. **`atomlang_version` obligatorio** como primera clave de todo archivo — permite migraciones de gramática (v1→v2) sin ambigüedad de qué reglas aplicar.
2. **snake_case obligatorio** en todo identificador (`atom_id`, `policy_id`, nombres de propiedad) — el linter rechaza el archivo si detecta camelCase, espacios, o mayúsculas en identificadores.
3. **Ningún valor de `verbo`, `resource`, `subject.set_id` puede ser un literal no registrado** — el linter consulta el catálogo (`bos_verb`, `bos_resource_catalog`, `bos_group`) en tiempo de lint, no en runtime.
4. **`condition: null` explícito**, nunca omitido — si un Atom no necesita Condition adicional, se declara `null` explícitamente (evita ambigüedad entre "me olvidé de escribirlo" y "intencionalmente no tiene").
5. **Un archivo `.atm.yaml` = una Policy** (o un PolicySet con sus Policies hijas inline) — nunca múltiples Policies no relacionadas en el mismo archivo, para que el diff de git sea legible por dominio de negocio.

---

## 11. Propuesta del Compilador

### 11.1 Nombre y forma de distribución

| | Propuesta |
|---|---|
| Nombre del binario | **`atomc`** (AtomLang Compiler) |
| Lenguaje de implementación | **Rust 1.85+ (MUSL)** |
| Forma de distribución | Binario estático dentro del ecosistema bAuth (`BauthAgent/tools/atomc/`) — mismo stack que el daemon principal |

**Por qué Rust:**

- El compilador comparte el stack con el daemon bAuth (Rust 1.85+ MUSL, tokio) — un solo lenguaje en todo el subsistema de identidad, sin dependencias externas adicionales.
- El parseo de YAML + validación JSON Schema tiene librerías maduras en Rust (`serde_yaml`, `jsonschema-rs`), con tipado estricto en tiempo de compilación — coherente con la filosofía de eliminar strings ambiguos del sistema.
- Al estar en Rust, `atomc` puede reutilizar directamente los tipos del dominio bAuth (`BauthError`, newtypes de `verb_id`, `policy_id`, etc.) sin serializar/deserializar entre lenguajes.
- El binario compilado es un artefacto MUSL estático — mismo patrón de despliegue que el resto del ecosistema SBOS.

### 11.2 Arquitectura interna (mapea 1:1 a las 3 fases ya especificadas)

```
BauthAgent/tools/atomc/
  src/
    main.rs            → entrypoint CLI (atomc lint | atomc compile | atomc validate | atomc publish)
    lexer/
      mod.rs           → Fase 1: tokeniza YAML, resuelve cada string contra catálogos (bos_verb, bos_resource_catalog, bos_group)
    parser/
      mod.rs           → Fase 1-2: construye AST tipado (structs Rust) desde el YAML validado por JSON Schema
      ast.rs           → tipos del AST: Policy, Atom, Target, Condition, Effect, Obligation
    semantic/
      mod.rs           → Fase 2: valida grafo de dependencias, combining_algorithm obligatorio, atributos duplicados Target/Condition
    codegen/
      mod.rs           → Fase 3: emite el Árbol Técnico (.atm.json) — serializado para bos_atom_compiled
    catalog/
      mod.rs           → cliente solo-lectura contra PostgreSQL (bos_verb, bos_group, bos_resource_catalog, bos_attribute_catalog)
    diagnostics/
      mod.rs           → formato estándar de errores/warnings con códigos ATOMC-E-0xx / ATOMC-W-0xx
  schemas/
    AtomLang.Atom.v1.json          → JSON Schema versionado del Atom
    AtomLang.CompiledTree.v1.json  → JSON Schema versionado del Árbol Técnico
  Cargo.toml
```

### 11.3 Comandos propuestos (interfaz CLI)

```bash
atomc lint ./atoms/src/step_up_triggers.atm.yaml
  → valida sintaxis YAML + JSON Schema + estilo (§1.4). No toca la base de datos.

atomc validate ./atoms/src/step_up_triggers.atm.yaml
  → lint + resuelve referencias contra catálogos reales en Postgres (bos_verb, bos_group, etc.)
  → detecta atributos duplicados Target/Condition, combining_algorithm faltante.

atomc compile ./atoms/src/*.atm.yaml --out ./atoms/compiled/
  → corre validate + genera el Árbol Técnico (.atm.json) por cada Policy.
  → falla el build completo (exit code ≠ 0) si CUALQUIER archivo no compila — no hay compilación parcial.

atomc publish ./atoms/compiled/step_up_triggers.atm.json
  → inserta/actualiza la fila correspondiente en bos_atom_compiled (Postgres) dentro de una transacción,
     con versión incremental y registro en bos_atom_audit del cambio de configuración (quién publicó, cuándo).
```

### 11.4 Formato estándar de diagnóstico (para que un agente de IA lo consuma sin ambigüedad)

```json
{
  "level": "error",
  "code": "ATOMC-E-014",
  "message": "verbo 'CONFIGURE' no está registrado en bos_verb (¿quisiste decir 'configure'?)",
  "file": "step_up_triggers.atm.yaml",
  "atom_id": "verbo_administrativo",
  "field_path": "atoms[2].verbo",
  "phase": "lexer"
}
```

Cada código de error (`ATOMC-E-0xx` para errores que detienen la compilación, `ATOMC-W-0xx` para warnings) queda catalogado en `internal/diagnostics/codes.go`, de forma que tanto un humano como un agente de IA (ej. tu `BauthAgent`) puedan mapear el código a una acción correctiva estándar sin tener que interpretar el texto libre del mensaje.

### 11.5 Integración con la Fábrica SBOS (dónde vive en tu pipeline actual)

```
Desarrollador / Agente edita → step_up_triggers.atm.yaml (git, dentro del repo de BauthAgent)
        ↓
Pre-commit hook / guild        → atomc lint (rápido, sin DB — bloquea commits con errores de sintaxis)
        ↓
CI (al abrir PR)               → atomc validate (contra Postgres de dev) — bloquea merge si hay error semántico
        ↓
Pipeline de release            → atomc compile → atomc publish (contra Postgres de test/prod)
        ↓
bAuth (PDP)                     → recarga bos_atom_compiled (hot-reload o restart controlado del BitMask engine)
```

---

## 12. Resultado Esperado

### 12.1 El artefacto final

El resultado tangible de todo este trabajo es una **fila validada y versionada en `bos_atom_compiled`**, generada exclusivamente por `atomc compile` + `atomc publish` — nunca escrita a mano:

```sql
-- bos_atom_compiled (nueva tabla, complementa las 9 ya formalizadas)
CREATE TABLE bos_atom_compiled (
    compiled_id       BIGSERIAL PRIMARY KEY,
    policy_id         TEXT NOT NULL,
    atomlang_version  INT NOT NULL,
    ir_json           JSONB NOT NULL,          -- el Árbol Técnico completo de esa Policy
    source_hash       TEXT NOT NULL,           -- hash del .atm.yaml fuente que lo generó (trazabilidad)
    compiled_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    compiled_by       TEXT NOT NULL,           -- usuario/CI que ejecutó atomc publish
    is_active         BOOLEAN NOT NULL DEFAULT true
);
```

### 12.2 Garantías que el resultado debe cumplir (Definition of Done)

| # | Garantía | Cómo se verifica |
|---|---|---|
| 1 | Ningún `.atm.json` en `bos_atom_compiled` contiene un string comparado por igualdad textual en el evaluador — todo es ID/enum. | Test automatizado: parsear cada `ir_json` y assertar que ningún valor de `verb_id`, `resource_id`, `property_id` sea de tipo string. |
| 2 | El bug de case-sensitivity (`configure` vs `CONFIGURE`) es **estructuralmente imposible** — no depende de disciplina del autor. | Test de compilador: intentar compilar un `.atm.yaml` con `verbo: CONFIGURE` (no registrado) y verificar que `atomc` lo rechaza con código `ATOMC-E-014`. |
| 3 | Ninguna Policy con 2+ Atoms queda sin `combining_algorithm`. | Constraint `NOT NULL` en el JSON Schema + test de `atomc validate`. |
| 4 | El caso de Atoms concurrentes con distinto `max_age_seconds`/`required_loa` (defecto #3) resuelve siempre al valor más estricto, no al primero por orden de declaración. | Test de integración del evaluador: correr el escenario de §9.4 de este documento y assertar `max_age_seconds == 300`, no `600` ni indeterminado por orden. |
| 5 | Todo cambio publicado en `bos_atom_compiled` queda trazado (quién, cuándo, desde qué `source_hash`) en `bos_atom_audit`. | Revisión de que `atomc publish` siempre inserta también una fila de auditoría, dentro de la misma transacción (atomicidad). |
| 6 | El PDP (evaluador) nunca lee `bos_atom_catalog` (fuente humana) directamente — solo `bos_atom_compiled`. | Revisión de código del BitMask engine: la única consulta de lectura en el hot path apunta a `bos_atom_compiled WHERE is_active = true`. |

### 12.3 Qué NO entrega esta propuesta (explícitamente fuera de alcance)

- No define todavía el `bos_attribute_catalog` completo con la regla `strictest()` para cada atributo posible de Obligation — queda como entregable posterior (ver §13, Próximos entregables, al final de este documento).
- No define la UI de edición del Árbol Fuente (`.atm.yaml`) — este documento asume que ya existe o se construye por separado; `atomc` es agnóstico a si el YAML lo escribe un humano en un editor o una UI visual que serializa a YAML.
- No define el mecanismo exacto de hot-reload del BitMask engine al detectar un nuevo `is_active=true` en `bos_atom_compiled` — se asume un mecanismo de recarga ya existente en tu arquitectura (o a definir junto al equipo de `BauthAgent`).

### 12.4 Próximo paso sugerido

Con lenguaje, compilador y resultado esperado ya definidos, el siguiente entregable natural es el **`bos_attribute_catalog`** (mencionado en §3.3 como fuera de alcance) — es el catálogo que falta para que `atomc` pueda validar completamente cualquier `condition`/`obligation` sin excepciones, y es prerequisito para que `atomc validate` funcione end-to-end contra Postgres real.

---

## 13. Próximos entregables (fuera de alcance de este documento)

1. **Catálogo cerrado completo de `bos_attribute_catalog`** — definir `data_type` y regla de `strictest()` para cada atributo usado en Obligations (no solo `required_loa`/`max_age_seconds`). *(Prerequisito bloqueante para que `atomc validate` funcione end-to-end.)*
2. **Extensión de la gramática EBNF** (§8) para cubrir `PolicySet` anidados con `target_filter` (multi-tenant) y el caso de Atoms `is_control_plane: true`.
3. **Definición de versión y migración del IR** — qué pasa con el Árbol Técnico ya compilado en `bos_atom_compiled` cuando cambia la gramática `atomlang_version` v1 → v2 (retro-compatibilidad).
4. **UI de edición del Árbol Fuente** — editor visual (o integración con la UI de templates de rol ya existente) que serialice a `.atm.yaml` válido, para que el humano no necesite escribir YAML a mano.
5. **Mecanismo de hot-reload del BitMask engine** — cómo el PDP detecta y carga una nueva fila `is_active=true` en `bos_atom_compiled` sin downtime.

*(Nota: la especificación de mensajes de error del compilador y el formato de diagnóstico estándar, originalmente listados aquí, ya quedaron resueltos en §11.4 de este documento.)*
