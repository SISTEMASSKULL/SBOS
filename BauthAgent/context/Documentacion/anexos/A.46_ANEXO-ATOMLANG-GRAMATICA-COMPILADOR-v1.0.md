# A.46 — Gramática AtomLang y Compilador `atomc`
## Tipo A+D — Traslado de SSOT + verificación de implementación: la especificación completa del lenguaje y su compilador

**Versión:** 1.0.3  
**Fecha:** 2026-07-14  
**Tipo de anexo:** A (traslado de SSOT) + D (verificación de código / estado de implementación)  
**Respalda a:** [2.13 MANUAL-ATOMLANG-LENGUAJE v2.0 §5, §8](../2.13_MANUAL-ATOMLANG-LENGUAJE-v2.0.md) · [2.15 Motor de Identidad](../2.15_MANUAL-MOTOR-IDENTIDAD-v1.0.md) · [1.06 D00 Identidad v2.0](../1.06_MANUAL-D00-IDENTIDAD-v2.0.md) · [A.45 §9.2](A.45_ANEXO-FUNDAMENTOS-NORMATIVOS-ATOMLANG-v1.0.md)  
**Fuentes absorbidas:** `AtomLang-especificacion-completa.md` §5–§12 · `ATOMLANG-DSL-SPEC-v1.0.md` §1–§5 (ambas legacy en `anexos/` — este anexo las reemplaza)  
**Normas base:** OASIS XACML 3.0 · NIST SP 800-162 §4 · JSON Schema 2020-12

---

## §1 Propósito y cómo citarlo

Este anexo contiene la especificación formal y completa de AtomLang: la gramática EBNF, el JSON Schema de cada constructo, el algoritmo de evaluación ejecutable, el pipeline del compilador `atomc`, el catálogo de errores ATOMC-E/W, y el estado de implementación verificado.

**Cómo citarlo:** `A.46 §N` (ej. "ver catálogo de errores: A.46 §4").

**Frontera:** este anexo NO repite la doctrina de uso (eso está en 2.13) ni las normas que justifican cada constructo (eso está en A.45). Este anexo contiene la **especificación técnica precisa** — lo que necesita el implementador del compilador.

---

## §2 Gramática EBNF del Árbol Fuente

Esta es la gramática que el Lexer/Parser de `atomc` usa para aceptar o rechazar un archivo `.atm.yaml`. Cualquier construcción fuera de esta gramática es un error de sintaxis — el compilador rechaza, no corrige.

```ebnf
(* AtomLang — Gramática del Árbol Fuente v1.0 *)
(* Sobre base YAML: la gramática describe las claves y valores válidos *)

arbol_fuente        = declaracion_version ,
                      ( policy_decl | policy_set_decl ) ;

declaracion_version = "atomlang_version" ":" INTEGER ;    (* OBLIGATORIO — primera clave *)

(* ── PolicySet ── *)
policy_set_decl     = "policy_set" ":"
                        "policy_set_id" ":" identificador ,
                        "combining_algorithm" ":" combining_algorithm ,
                        [ "target" ":" target ] ,
                        "children" ":" "[" { policy_decl | policy_set_decl } "]" ;

(* ── Policy ── *)
policy_decl         = "policy" ":"
                        "policy_id" ":" identificador ,
                        "application_id" ":" ( INTEGER | "null" ) ,
                        "combining_algorithm" ":" combining_algorithm ,
                        [ "target" ":" target ] ,
                        "atoms" ":" "[" { atom_decl } "]" ;

(* ── Atom (Rule) ── *)
atom_decl           = "-" "atom_id" ":" identificador ,
                        "verb_id" ":" verb_ref ,
                        "target" ":" target ,
                        "condition" ":" ( condicion | "null" ) ,
                        "effect" ":" effect ;

(* ── Target ── *)
target              = "subject" ":" subject ,
                      "resource" ":" resource_ref ,
                      [ "environment" ":" "[" { atributo_ref } "]" ] ;

subject             = "kind" ":" ( "ROL" | "SET" | "ANY" ) ,
                      [ "role_id" ":" rol_ref ]            (* si kind=ROL *)
                      [ "set_id"  ":" set_ref  ] ;         (* si kind=SET *)

(* ── Condition ── *)
condicion           = "property_id" ":" propiedad_ref ,
                      "operator"    ":" operador ,
                      "value"       ":" valor_ref ;        (* valor_ref: literal tipado o @bauth_config_param.clave *)

atributo_ref        = "property_id" ":" propiedad_ref ,
                      "operator"    ":" operador ,
                      "value"       ":" valor_ref ;

operador            = ">" | "<" | ">=" | "<=" | "==" | "!=" | "IN" | "NOT_IN" | "BETWEEN" ;

(* ── Effect ── *)
effect              = "decision" ":" ( "Permit" | "Deny" ) ,
                      [ "obligation" ":" mapa_tipado ] ,
                      [ "advice" ":" cadena ] ;

(* ── combining_algorithm ── *)
combining_algorithm = "deny-overrides" | "permit-overrides" | "first-applicable"
                    | "deny-unless-permit" | "permit-unless-deny" | "aggregate-strictest" ;

(* ── Referencias a catálogos (resueltas en Fase 1 contra Postgres) ── *)
verb_ref            = identificador ;    (* DEBE existir en bauth.privilege_verb.verb_slug *)
resource_ref        = identificador ;    (* DEBE existir en bauth.privilege_resource.resource_slug *(propuesta)* *)
set_ref             = identificador ;    (* DEBE existir en bauth.privilege_role_set.set_slug *(propuesta)* — declarado en D98 *)
rol_ref             = identificador ;    (* DEBE existir en bauth.idn_role_template.rol_slug *)
propiedad_ref       = identificador ;    (* DEBE existir en bauth.privilege_attribute.attr_slug *(propuesta)* *)

(* ── Valor referenciado (PIP o literal tipado) ── *)
valor_ref           = ( "@bauth_config_param" "." identificador )   (* referencia PIP — preferido *)
                    | valor_literal_tipado ;                          (* literal — restricciones §2.3 *)

valor_literal_tipado = BOOLEAN | STRING_ENUM | cadena ;   (* NUMBER prohibido para tipos AMOUNT/CURRENCY *)

(* ── Terminales ── *)
identificador       = letra_minuscula , { letra_minuscula | digito | "_" } ;  (* snake_case obligatorio *)
mapa_tipado         = "{" , { clave ":" valor_tipado } "}" ;
```

### §2.1 Reglas léxicas obligatorias (Fase 1 del compilador)

1. Todo `identificador` en **snake_case** — el Lexer rechaza (no corrige) camelCase, espacios o mayúsculas.
2. Todo `verb_ref`, `resource_ref`, `set_ref`, `rol_ref`, `propiedad_ref` se resuelve **en Fase 1** contra su catálogo en Postgres. Si no existe: `ATOMC-E-014`.
3. Ningún `valor_ref` de tipo `AMOUNT` o `CURRENCY` puede ser literal numérico o código de moneda — usar `@bauth_config_param.<clave>`.
4. `condition: null` explícito si el Atom no tiene condición (nunca omitir el campo).
5. `atomlang_version` es la primera clave del archivo.

### §2.2 Grafo de dependencias — reglas de contención válidas

```
PolicySet
  ├── combining_algorithm     (1, OBLIGATORIO, primer atributo)
  ├── target                  (0..1, opcional — filtra qué Policies hijas aplican)
  └── children: [Policy | PolicySet]  (1..N)

Policy
  ├── combining_algorithm     (1, OBLIGATORIO si 2+ atoms)
  ├── target                  (0..1)
  └── atoms: [Atom]           (1..N)

Atom
  ├── verb_id                 (1, OBLIGATORIO — FK bauth.privilege_verb)
  ├── target                  (1, OBLIGATORIO)
  │     ├── subject           (1, OBLIGATORIO)
  │     ├── resource          (1, OBLIGATORIO — FK bauth.privilege_resource *(propuesta)*)
  │     └── environment       (0..N, atributos de contexto)
  ├── condition               (1, explícito — null si no hay condición adicional)
  └── effect                  (1, OBLIGATORIO — decision + obligation + advice)
```

**Reglas de validación del grafo (G-01..G-10):**

| # | Regla | Error compilador |
|---|---|---|
| G-01 | `Policy` con 2+ Atoms SIEMPRE tiene `combining_algorithm` | ATOMC-E-031 |
| G-02 | `Atom` con `application_id != null` DEBE estar dentro de una `Policy` con `combining_algorithm` | ATOMC-E-031 |
| G-03 | `condition` nunca se omite — `null` explícito si no hay condición | ATOMC-W-011 |
| G-04 | Un `property_id` no puede aparecer en `target.environment` Y en `condition` del mismo Atom | ATOMC-E-021 |
| G-05 | Todo `verb_id` debe existir en `bauth.privilege_verb` — nunca string libre | ATOMC-E-014 |
| G-06 | Todo `subject.set_id` debe existir en `bauth.privilege_role_set` *(propuesta)* (declarado en D98) | ATOMC-E-014 |
| G-07 | `effect.decision` solo acepta `Permit` o `Deny` — no hay tercer valor | ATOMC-E-051 |
| G-08 | Ningún `valor_ref` de tipo AMOUNT puede ser literal numérico | ATOMC-E-042 |
| G-09 | Ningún `valor_ref` de tipo CURRENCY puede ser código de moneda literal | ATOMC-E-043 |
| G-10 | Ningún `atom_id` puede contener dígitos que representen montos o monedas | ATOMC-E-041 |

### §2.3 Tipos de valor permitidos por data_type (resolución Fase 2)

El `data_type` de cada `property_id` está registrado en `bauth.privilege_attribute` *(propuesta)*. El compilador valida que el `valor_ref` sea del tipo correcto:

| `data_type` en catálogo | Valores permitidos en `value` | Valores PROHIBIDOS |
|---|---|---|
| `boolean` | `true` · `false` | Cualquier otro |
| `string_enum` | Valor registrado en el enum del atributo | String libre no registrado |
| `numeric` | Literal numérico (INTEGER/DECIMAL) | — (literales numéricos OK para non-AMOUNT) |
| `AMOUNT` | **Solo** `@bauth_config_param.<clave>` | Literal numérico → ATOMC-E-042 |
| `CURRENCY` | **Solo** `@bauth_config_param.<clave>` | Código de moneda literal (BOB, USD, EUR) → ATOMC-E-043 |
| `list_of_enum` | `[valor1, valor2, ...]` donde cada valor está en el enum | Strings libres no registrados |

---

## §3 JSON Schema por constructo

### §3.1 JSON Schema del Atom (AtomLang.Atom.v1)

```json
{
  "$id": "AtomLang.Atom.v1",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["atom_id", "verb_id", "target", "condition", "effect"],
  "additionalProperties": false,
  "properties": {
    "atom_id": {
      "type": "string",
      "pattern": "^[a-z][a-z0-9_]{2,63}$",
      "description": "Identificador snake_case único, FK a bauth.privilege_atom.atom_slug."
    },
    "application_id": {
      "type": ["integer", "null"],
      "description": "FK a bauth.privilege_application (Caso 1 — Rule de Aplicación) | null (Caso 2 — Guardrail)."
    },
    "verb_id": {
      "type": "string",
      "description": "FK a bauth.privilege_verb.verb_id — vocabulario cerrado, resuelto en Fase 1."
    },
    "target": {
      "type": "object",
      "required": ["subject", "resource"],
      "additionalProperties": false,
      "properties": {
        "subject": {
          "oneOf": [
            { "type": "object", "required": ["kind", "role_id"],
              "properties": { "kind": { "const": "ROL" }, "role_id": { "type": "string" } } },
            { "type": "object", "required": ["kind", "set_id"],
              "properties": { "kind": { "const": "SET" }, "set_id": { "type": "string",
              "description": "FK a bauth.privilege_role_set *(propuesta)* — declarado en D98 · Registro Estructural" } } },
            { "type": "object", "required": ["kind"],
              "properties": { "kind": { "const": "ANY" } } }
          ]
        },
        "resource": { "type": "string",
          "description": "FK a bauth.privilege_resource.resource_slug (tabla propuesta) — nunca string libre." },
        "environment": {
          "type": "array",
          "items": { "$ref": "#/$defs/attribute_ref" }
        }
      }
    },
    "condition": {
      "oneOf": [
        { "$ref": "#/$defs/attribute_ref" },
        { "type": "null" }
      ],
      "description": "null si no hay condición adicional — NUNCA omitir el campo."
    },
    "effect": {
      "type": "object",
      "required": ["decision"],
      "additionalProperties": false,
      "properties": {
        "decision": { "enum": ["Permit", "Deny"] },
        "obligation": { "type": "object", "additionalProperties": true },
        "advice": { "type": ["string", "null"] }
      }
    }
  },
  "$defs": {
    "attribute_ref": {
      "type": "object",
      "required": ["property_id", "operator", "value"],
      "additionalProperties": false,
      "properties": {
        "property_id": { "type": "string",
          "description": "FK a bauth.privilege_attribute *(propuesta)* — define el data_type esperado." },
        "operator": { "enum": [">","<",">=","<=","==","!=","IN","NOT_IN","BETWEEN"] },
        "value": { "description": "Tipo dinámico según property_id.data_type. AMOUNT/CURRENCY: solo @bauth_config_param.*" }
      }
    }
  }
}
```

### §3.2 JSON Schema del Árbol Técnico compilado (AtomLang.CompiledTree.v1)

```json
{
  "$id": "AtomLang.CompiledTree.v1",
  "type": "object",
  "required": ["policy_sets"],
  "properties": {
    "policy_sets": {
      "type": "array",
      "items": { "$ref": "#/$defs/policy_set" }
    }
  },
  "$defs": {
    "policy_set": {
      "required": ["policy_set_id", "combining_algorithm", "children"],
      "properties": {
        "policy_set_id": { "type": "integer" },
        "combining_algorithm": { "$ref": "#/$defs/combining_algorithm" },
        "children": {
          "type": "array",
          "items": { "oneOf": [ { "$ref": "#/$defs/policy" }, { "$ref": "#/$defs/policy_set" } ] }
        }
      }
    },
    "policy": {
      "required": ["policy_id", "combining_algorithm", "atoms"],
      "properties": {
        "policy_id": { "type": "integer" },
        "application_id": { "type": ["integer", "null"] },
        "combining_algorithm": { "$ref": "#/$defs/combining_algorithm" },
        "atoms": { "type": "array", "items": { "$ref": "AtomLang.Atom.v1" } }
      }
    },
    "combining_algorithm": {
      "enum": ["deny-overrides","permit-overrides","first-applicable",
               "deny-unless-permit","permit-unless-deny","aggregate-strictest"]
    }
  }
}
```

**Invariante del IR (Árbol Técnico):** ningún campo de tipo `verb_id`, `resource_id`, `property_id` puede ser de tipo string en el IR compilado — todos son INTEGER (FK resueltas en Fase 1). Un test automatizado puede verificar esto parseando cada `ir_json` en `bauth.privilege_atom_compiled *(propuesto)*` y assertando que los campos de ID son enteros.

---

## §4 Catálogo de errores del compilador ATOMC

### §4.1 Errores — detienen la compilación (ATOMC-E-xxx)

| Código | Fase | Campo / Condición | Descripción | Acción correctiva |
|---|---|---|---|---|
| ATOMC-E-011 | Lexer | `atomlang_version` ausente | El archivo no declara versión del lenguaje | Agregar `atomlang_version: 1` como primera clave |
| ATOMC-E-012 | Lexer | `atomlang_version` no soportada | Versión mayor a la del compilador instalado | Actualizar `atomc` o bajar la versión del archivo |
| ATOMC-E-013 | Lexer | `identificador` con camelCase/mayúsculas/espacios | Identificador no cumple snake_case | Convertir a snake_case |
| ATOMC-E-014 | Lexer | `verb_ref` / `resource_ref` / `set_ref` / `propiedad_ref` | El valor no existe en su catálogo Postgres | Verificar y registrar el valor en el catálogo correspondiente |
| ATOMC-E-021 | Semantic | `property_id` repetido en `target.environment` y `condition` del mismo Atom | Atributo duplicado — dos fuentes de verdad | Eliminar el campo redundante (normalmente de `target.environment`) |
| ATOMC-E-031 | Semantic | Policy con 2+ Atoms sin `combining_algorithm` | Resultado de combinación indefinido | Declarar `combining_algorithm` explícito en la Policy |
| ATOMC-E-032 | Semantic | Atom con `application_id != null` fuera de Policy con `combining_algorithm` | Rule de Aplicación sin contexto | Envolver el Atom en una Policy con `combining_algorithm` |
| ATOMC-E-041 | Semantic | `atom_id` contiene dígitos que representan montos o monedas (ej. `venta_10_000_bob`) | atom_id codifica valores de negocio — PROHIBIDO | Renombrar a nombre semántico (ej. `venta_aprobacion_nivel1`) |
| ATOMC-E-042 | Semantic | `value` literal numérico en campo de tipo AMOUNT | Monto hardcodeado — varía por tenant/región | Reemplazar con `@bauth_config_param.<clave>` |
| ATOMC-E-043 | Semantic | `value` código de moneda literal (BOB, USD, EUR, etc.) en campo CURRENCY | Moneda hardcodeada — varía por tenant/región | Reemplazar con `@bauth_config_param.moneda_legal` |
| ATOMC-E-051 | Semantic | `effect.decision` con valor distinto de Permit/Deny | Tercer valor de Effect no existe en XACML | Usar solo `Permit` o `Deny`; matices en `obligation` |
| ATOMC-E-061 | Emitter | `property_id` resuelto pero `data_type` desconocido en catálogo | El atributo existe pero sin tipo registrado | Registrar `data_type` en `bauth.privilege_attribute *(propuesta)*` |

### §4.2 Warnings — compilación continúa (ATOMC-W-xxx)

| Código | Fase | Condición | Descripción | Acción recomendada |
|---|---|---|---|---|
| ATOMC-W-011 | Lexer | Campo `condition` ausente (no declarado) | Ambigüedad: ¿omisión intencional o error? | Agregar `condition: null` explícito |
| ATOMC-W-012 | Semantic | Policy con 1 solo Atom y `combining_algorithm` declarado | El algoritmo no tiene efecto con un solo Atom | Verificar si falta un segundo Atom o si se puede simplificar |
| ATOMC-W-021 | Semantic | Mismo `set_id` repetido en 2+ Atoms hermanos sin diferencia de `operator` | Posible duplicación de Rule | Revisar si los Atoms son realmente distintos |
| ATOMC-W-031 | Semantic | Atom con `subject.kind: ROL` y el mismo rol listado en un Set del D98 | El Set ya agrupa ese rol — la Rule de rol individual puede ser redundante | Considerar usar `subject.kind: SET` apuntando al Set existente |

### §4.3 Formato estándar del diagnóstico

```json
{
  "level": "error",
  "code": "ATOMC-E-042",
  "message": "valor literal '10000' en campo AMOUNT — usar '@bauth_config_param.approval_threshold'",
  "file": "button_rules.atm.yaml",
  "atom_id": "venta_aprobacion_simple",
  "field_path": "atoms[0].condition.value",
  "phase": "semantic",
  "norm_ref": "NIST SP 800-162 §5 · A.45 §10"
}
```

---

## §5 Algoritmo formal de evaluación (especificación ejecutable para el PDP)

Esta sección especifica el algoritmo que el evaluador (PDP) aplica al Árbol CANONICAL. Es la fuente de verdad para la implementación.

### §5.1 Evaluación de un Atom individual

```
function evaluate_atom(atom, ctx) → AtomResult:

  # ETAPA 1 — Target-gate (OBLIGATORIA PRIMERO, siempre)
  if not match_verb(ctx.request_verb_id, atom.verb_id):
      return AtomResult(atom.atom_id, NotApplicable, null)

  if atom.target.subject.kind == "ROL":
      if ctx.subject_role_id != atom.target.subject.role_id:
          return AtomResult(atom.atom_id, NotApplicable, null)
  elif atom.target.subject.kind == "SET":
      if ctx.subject_role_id not in resolve_set(atom.target.subject.set_id):
          return AtomResult(atom.atom_id, NotApplicable, null)
  # kind == "ANY" → siempre pasa

  if atom.target.resource_id != ctx.resource_id:
      return AtomResult(atom.atom_id, NotApplicable, null)

  for env_ref in atom.target.environment:
      value = pip.resolve(ctx, env_ref.property_id)
      if value is None: return AtomResult(atom.atom_id, Indeterminate, null)
      if not apply_operator(env_ref.operator, value, env_ref.value):
          return AtomResult(atom.atom_id, NotApplicable, null)

  # ETAPA 2 — Condition (solo si Target cerró en Match)
  if atom.condition is None:
      condition_result = True
  else:
      value = pip.resolve(ctx, atom.condition.property_id)
      if value is None: return AtomResult(atom.atom_id, Indeterminate, null)
      condition_result = apply_operator(atom.condition.operator, value, atom.condition.value)

  if not condition_result:
      return AtomResult(atom.atom_id, NotApplicable, null)

  return AtomResult(atom.atom_id, atom.effect.decision, atom.effect)
```

### §5.2 Algoritmos de combinación estándar

```
combine(results, algorithm):

  "deny-overrides":
    if any Deny → Deny (primer Deny's effect)
    if any Indeterminate → Indeterminate
    if any Permit → Permit (primer Permit's effect)
    → NotApplicable

  "permit-overrides":
    if any Permit → Permit
    if any Indeterminate → Indeterminate
    if any Deny → Deny
    → NotApplicable

  "first-applicable":
    for r in results: if r in (Permit, Deny) → return r
    → NotApplicable

  "deny-unless-permit":
    if any Permit → Permit
    → Deny (nunca Indeterminate ni NotApplicable)
```

### §5.3 `aggregate-strictest` — extensión bAuth para step-up concurrente

```
combine_aggregate_strictest(results):
  permits = [r for r in results if r.state == Permit]
  if len(permits) == 0: return combine(results, "deny-overrides")

  merged = {}
  for r in permits:
      for key, value in r.effect.obligation.items():
          if key not in merged:
              merged[key] = value
          else:
              merged[key] = strictest(key, merged[key], value)

  return Permit(obligation=merged)

strictest(key, a, b):
  if key in ("required_loa", "acr_level"):  return max(a, b)  # más alto LoA
  if key in ("max_age_seconds",):            return min(a, b)  # sesión más fresca
  raise ConfigError("sin regla 'strictest' para: " + key)
```

**Caso de prueba de referencia:**
```
atoms: [Permit(max_age=300), Permit(max_age=600)]
aggregate-strictest → min(300, 600) = 300  (el más exigente, no el primero)
```

---

## §6 Arquitectura interna del compilador `atomc`

```
BauthAgent/tools/atomc/
  src/
    main.rs          → CLI dispatcher (atomc lint | validate | compile | publish)
    lexer/
      mod.rs         → Fase 1: tokeniza YAML, resuelve referencias vs catálogos Postgres
      catalog.rs     → Cliente read-only vs bauth.privilege_verb, bauth.privilege_role_set *(propuesta)*, bauth.privilege_resource *(propuesta)*, bauth.privilege_attribute *(propuesta)*
    parser/
      mod.rs         → Fase 1-2: construye AST tipado (structs Rust) desde YAML validado
      ast.rs         → Tipos: PolicySet, Policy, Atom, Target, Subject, Condition, Effect, Obligation
    semantic/
      mod.rs         → Fase 2: valida grafo G-01..G-10, literales prohibidos, atributos duplicados
    codegen/
      mod.rs         → Fase 3: emite Árbol Técnico JSON (solo IDs/enums enteros)
    diagnostics/
      mod.rs         → Formato ATOMC-E/W, asocia código → norma
      codes.rs       → Catálogo completo de códigos con causa, campo, fase, acción, norm_ref
  schemas/
    AtomLang.Atom.v1.json
    AtomLang.CompiledTree.v1.json
  Cargo.toml
```

### §6.1 DDL propuesto: `bauth.privilege_atom_compiled` (tabla del IR)

**Estado:** L0 — diseñado, sin aplicar. Requiere HITL antes de crear la migración (`bauth_4X__privilege_atom_compiled.sql`).

```sql
-- TABLA PROPUESTA: bauth.privilege_atom_compiled
-- El único input del evaluador (PDP) — todos los IDs resueltos como INTEGER (sin strings)
-- WORM: solo INSERT y UPDATE de is_active, nunca DELETE ni UPDATE de ir_json
CREATE TABLE bauth.privilege_atom_compiled (
    compiled_id       BIGSERIAL    PRIMARY KEY,
    policy_id         TEXT         NOT NULL,          -- slug del RolTemplate que generó este árbol
    atomlang_version  INT          NOT NULL,           -- versión de AtomLang usada en la compilación
    ir_json           JSONB        NOT NULL,           -- Árbol Técnico (solo IDs/enums enteros)
    source_hash       TEXT         NOT NULL,           -- SHA256 del .atm.yaml fuente
    compiled_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    compiled_by       TEXT         NOT NULL,           -- usuario/CI que ejecutó atomc publish
    is_active         BOOLEAN      NOT NULL DEFAULT true,
    ctx_id            TEXT         NOT NULL DEFAULT 'system'  -- SBOS-049
);

-- Índice para el hot-path del PDP: solo árbol activo por policy
CREATE INDEX idx_privilege_atom_compiled_active
    ON bauth.privilege_atom_compiled (policy_id, is_active)
    WHERE is_active = true;
```

---

## §7 Estado de implementación verificado

| Componente | Estado | Evidencia |
|---|---|---|
| Schema `atomlang` en Postgres VPS | ✅ Creado | Verificado en VPS de pruebas (2026-07-11) |
| Tabla `atom_node` (adj. list + mat. path) | ✅ Creada | VPS de pruebas |
| Vista `vw_atom_path` (ruta completa) | ✅ Creada | VPS de pruebas |
| Vista `vw_gaps` (SOURCE vs CANONICAL) | ✅ Creada | VPS de pruebas |
| Datos D1 `step_up_triggers` SOURCE | ✅ Insertados | 3 nodos |
| Datos D1 `step_up_triggers` CANONICAL | ✅ Insertados | 2 nodos (el tercero = SIN_EQUIVALENTE, pendiente HITL) |
| Binario `atomc` (Rust) | ❌ No implementado | `BauthAgent/tools/atomc/` no existe — **L0** |
| Tabla `atom_lexer_rules` | ❌ No creada | Pendiente (P1) |
| DDL `bauth.privilege_atom_compiled` *(propuesto)* aplicado | ❌ No aplicado | Diseñado en §6.1 — pendiente migración |
| Evaluador leyendo solo `bauth.privilege_atom_compiled` *(propuesto)* | ❌ Lee `bauth.privilege_atom` directamente | Brecha P1 de seguridad |
| Datos D1 completo SOURCE | ⬜ Pendiente | B4, B5, B6, B7 sin CANONICAL completo |
| Datos D2–D12 completo | ⬜ Pendiente | — |

### §7.1 Gaps detectados en D1 (verificados en VPS)

Resumen del análisis `vw_gaps` para D1 (fuente: `ATOMLANG-GAP-ANALYSIS-D1-v1.0.md` legacy):

| Tipo de gap | Cantidad | Severidad | Resolución |
|---|---|---|---|
| `NOMBRE_DIFERENTE` (nombre humano vs. canónico) | ~22 | Media | `atom_lexer_rules` tabla de mapeo (P1) |
| `SIN_EQUIVALENTE` (no existe en SSOT) | ~2 | **Alta — HITL** | Consultar al humano: ¿requisito real o error de agente? |
| `FALTA_PROPIEDAD` (sin prop_path/operator) | ~12 | Media | Completar con `_prop()/_op()/_val()` en Flutter |
| `TIPO_DIFERENTE` (objeto en vez de politica) | ~6 | **Alta** | Reestructuración manual del nodo (B7 capas) |
| `ESTRUCTURA_MALFORMADA` (G-08/09 violados) | ~3 | **Alta — bloqueante** | Partir `_prop('A AND B')` en regla compuesta |

---

## §8 Mapa anexo → manuales

| Sección | Respalda a | Qué sección |
|---|---|---|
| §2 (gramática EBNF) | 2.13 §3-§4 | Constructos del lenguaje |
| §3 (JSON Schema) | 2.13 §5 | Estructura del archivo .atm.yaml |
| §4 (catálogo de errores) | 2.13 §6 | Compilador — códigos de diagnóstico |
| §5 (algoritmo evaluador) | 2.05 §7 | Motor de evaluación PDP |
| §6 (arquitectura atomc) | 2.13 §6 | Compilador — arquitectura interna |
| §7 (estado implementación) | 2.13 §8 | Estado del arte — inventario verificado |

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.2 | 2026-07-14 | Actualización de cabecera: referencia a 2.13 v2.0 y A.45 §9.2 (dominios del lenguaje D95-D99). Sin cambios en el cuerpo — gramática EBNF, JSON Schema, catálogo de errores y arquitectura atomc vigentes. |
| 1.0.1 | 2026-07-13 | Correcciones por revisión: reemplazadas todas las referencias a tablas `bos_*` inventadas. |
| 1.0.0 | 2026-07-13 | Primera edición. Unifica gramáticas, catálogo ATOMC, arquitectura atomc, DDL privilege_atom_compiled. |
