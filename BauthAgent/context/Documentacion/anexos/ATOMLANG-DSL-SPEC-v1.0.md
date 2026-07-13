# AtomLang — Especificación DSL v1.0
### Domain-Specific Language para la compilación de árboles de configuración de roles bAuth/SBOS

**Versión:** 1.0  
**Estado:** BORRADOR — en construcción  
**Alcance:** Definición formal de la gramática, el grafo de dependencias y el compilador SOURCE → CANONICAL  
**Base normativa:** OASIS XACML 3.0 · NIST SP 800-162 · SBOS RolTemplate v6.0

---

## 0. Motivación

El árbol de configuración de roles que construye el agente (y que visualiza el dashboard Flutter) está escrito en **lenguaje humano**: los nombres de las ramas son descripciones como `"monto de transacción alto (>10 000 BOB)"` o `"verbo CONFIGURE o ADMIN"`. Esto es valioso para la comprensión humana, pero inviable para una máquina de estados: no puede determinar el tipo, el trigger canónico ni el efecto sin parsear texto libre.

AtomLang resuelve esto definiendo:

1. **Gramática** — qué combinaciones de nodos son sintácticamente válidas.
2. **Grafo de dependencias** — qué tipo de nodo puede contener/referenciar a cuál.
3. **Compilador** — transforma el árbol SOURCE (humano) en un árbol CANONICAL que el evaluador/PDP ejecuta sin ambigüedad.

---

## 1. Gramática (EBNF)

```ebnf
(* AtomLang EBNF v1.0 *)

program         ::= domain_decl+

(* ── Niveles organizacionales (fuera de XACML, convención bAuth) ── *)
domain_decl     ::= "domain" DOMAIN_ID help? "{" block_decl+ "}"
block_decl      ::= "block" BLOCK_ID help? "{" block_content+ "}"
block_content   ::= policy_decl | rule_decl | data_decl | block_decl

(* ── Niveles XACML ── *)
policy_decl     ::= "policy" POLICY_ID combining_algo help? "{" policy_child+ "}"
policy_child    ::= atom_decl | compound_rule_decl | policy_decl

compound_rule_decl ::= "rule" RULE_ID verbo help? "{" predicate (logic_op predicate)+ effect "}"
atom_decl          ::= "atom" ATOM_ID verbo target? condition effect obligation?

(* ── Componentes de un átomo ── *)
target          ::= "target" "{" subject? resource? action? environment? "}"
subject         ::= "subject" ":"  subject_expr
resource        ::= "resource" ":" PROP_PATH
action          ::= "action"  ":" verbo
environment     ::= "env"     ":" PROP_PATH operator VALUE

subject_expr    ::= ROLE_ID | "SET" "(" SET_ID ")" | "ANY"
condition       ::= predicate (logic_op predicate)*
predicate       ::= PROP_PATH operator VALUE
effect          ::= "permit" effect_body? | "deny" effect_body?
effect_body     ::= "{" obligation* advice? "}"
obligation      ::= "must" ":" TEXT
advice          ::= "may"  ":" TEXT

(* ── Nodos de datos (no producen decisión XACML) ── *)
data_decl       ::= object_decl | list_decl | attr_decl | enum_decl
object_decl     ::= "object" KEY "{" (attr_decl | enum_decl | object_decl | list_decl)+ "}"
list_decl       ::= "list" KEY "[" object_decl* "]"
attr_decl       ::= "attr"  KEY "=" VALUE help?
enum_decl       ::= "enum"  KEY "=" VALUE "IN" "[" VALUE ("," VALUE)* "]" help?

(* ── Terminales y operadores ── *)
combining_algo  ::= "deny-overrides" | "permit-overrides" | "first-applicable"
                  | "only-one-applicable" | "deny-unless-permit" | "permit-unless-deny"

verbo           ::= "read" | "write" | "create" | "delete" | "approve" | "execute"
                  | "export" | "delegate" | "configure" | "audit" | "login" | "emit"
                  | "void" | "ANY"

logic_op        ::= "AND" | "OR" | "NOT"

operator        ::= "==" | "!=" | ">" | "<" | ">=" | "<="
                  | "IN" | "NOT_IN" | "BETWEEN" | "STARTS_WITH"
                  | "SUBSET_OF" | "IS_SET" | "visible_to_role" | "max_access"

DOMAIN_ID       ::= /D[0-9]+/                        (* D0 D1 D2 ... D99 *)
BLOCK_ID        ::= /B[0-9]+/                        (* B1 B4 B7 ... *)
POLICY_ID       ::= /[a-z][a-z0-9_]*/               (* snake_case *)
RULE_ID         ::= /[a-z][a-z0-9_]*/
ATOM_ID         ::= /[a-z][a-z0-9_]*/               (* trigger canónico: financial_approve *)
SET_ID          ::= /[a-z][a-z0-9_]*/
PROP_PATH       ::= /[a-z][a-z0-9_.{}]*/            (* transaction.amount_bob *)
ROLE_ID         ::= /[A-Z][A-Z0-9_-]*/
KEY             ::= /[a-z_][a-z0-9_.{}[\]#-]*/
VALUE           ::= QUOTED_STRING | NUMBER | IDENTIFIER | LIST_LITERAL
help            ::= "#" TEXT_TO_EOL
```

### 1.1 Ejemplo AtomLang — step_up_triggers canónico

```atomlang
domain D1 # "Acceso Lógico" {
  block B4 # "Dominio lógico (autenticación)" {

    policy step_up_triggers first-applicable # "RFC 9470 step-up mid-session" {

      atom financial_approve execute
        target { resource: transaction.amount_bob }
        condition: transaction.amount_bob > 10000
        deny {
          must: "required_loa=3,max_age_seconds=300,acr_value=high_security"
        }

      atom system_config_change configure
        target { resource: action.verb }
        condition: action.verb IN [CONFIGURE,ADMIN,DELETE]
        deny {
          must: "required_loa=3,max_age_seconds=0,acr_value=high_security"
        }
    }

  }
}
```

---

## 2. Grafo de dependencias

Define qué tipo de nodo puede ser **padre** (contener/referenciar) de cuál. Toda relación no declarada aquí es inválida sintácticamente.

```
dominio
  ├── bloque              (1..N)
  └── politica            (0..N, raro — normalmente via bloque)

bloque
  ├── bloque              (0..N, anidado)
  ├── politica            (0..N)
  ├── regla               (0..N)
  ├── objeto              (0..N, datos)
  ├── lista               (0..N, datos)
  ├── atributo            (0..N)
  └── enumerado           (0..N)

politica                  [XACML Policy]
  ├── enumerado[combining_algorithm]  (1, OBLIGATORIO, primer hijo)
  ├── evaluacion          (0..N, cada una con su propio efecto)
  └── regla               (0..N, compound condition → efecto compartido)

regla                     [XACML Rule — Condition compuesta]
  ├── enumerado[verbo]    (1, OBLIGATORIO, primer hijo)
  ├── evaluacion          (1..N, predicados de la Condition)
  ├── enumerado[op_lógico](0..N, entre evaluaciones: AND|OR|NOT)
  └── atributo[efecto]    (1, OBLIGATORIO, último hijo)

evaluacion                [XACML Atom / predicado]
  ├── enumerado[verbo]    (1, OBLIGATORIO, primer hijo)
  ├── atributo[propiedad] (1, OBLIGATORIO)
  ├── enumerado[operador] (1, OBLIGATORIO)
  ├── atributo[valor]     (1, OBLIGATORIO)
  └── atributo[efecto]    (0..1, presente cuando la evaluacion ES un Atom directo de politica)

objeto                    [datos, no produce decisión]
  ├── atributo            (0..N)
  ├── enumerado           (0..N)
  ├── objeto              (0..N, anidado)
  └── lista               (0..N)

lista                     [array homogéneo de datos, nunca de evals con efecto]
  └── objeto              (0..N)
```

### 2.1 Reglas de validación del grafo

| # | Regla | Consecuencia de violación |
|---|---|---|
| G-01 | `lista` nunca contiene `evaluacion` o `regla` | Compilación rechazada — usar `politica` |
| G-02 | `evaluacion` nunca contiene `politica` o `regla` | Compilación rechazada — nodo mal tipado |
| G-03 | `politica` SIEMPRE tiene `combining_algorithm` como primer hijo | Warning compilador + default `deny-overrides` |
| G-04 | `evaluacion` directa de `politica` SIEMPRE tiene `verbo` | Warning compilador + default `ANY` |
| G-05 | `regla` SIEMPRE tiene `verbo` como primer hijo | Warning compilador + default `ANY` |
| G-06 | `regla` SIEMPRE termina con `atributo[efecto]` | Error compilador — regla sin efecto es inválida |
| G-07 | `evaluacion` directa de `regla` NUNCA tiene `atributo[efecto]` propio | Warning — el efecto pertenece a la regla |
| G-08 | `_prop('A AND B')` con AND/OR en el valor de propiedad | Error compilador — partir en regla con `op_lógico` |
| G-09 | Entre dos `evaluacion` dentro de una `regla` DEBE haber un `enumerado[op_lógico]` | Error compilador |
| G-10 | `dominio` y `bloque` no son nodos XACML — no tienen `combining_algorithm` | Error compilador si se intenta asignar |

---

## 3. Compilador SOURCE → CANONICAL

El compilador transforma el árbol SOURCE (nombres humanos, estructura posiblemente imperfecta) en el árbol CANONICAL (identificadores máquina, XACML válido).

### 3.1 Pipeline de compilación (3 fases)

```
SOURCE tree (Flutter/humano)
        │
        ▼
┌───────────────────┐
│  Fase 1: LEXER    │  Tokeniza node_key en (tipo, trigger_id, props implícitas)
└───────────────────┘
        │
        ▼
┌───────────────────┐
│  Fase 2: PARSER   │  Valida grafo de dependencias (reglas G-01..G-10)
│                   │  Detecta y clasifica gaps
└───────────────────┘
        │
        ▼
┌───────────────────┐
│  Fase 3: EMITTER  │  Genera árbol CANONICAL con IDs canónicos + XACML completo
└───────────────────┘
        │
        ▼
CANONICAL tree (PostgreSQL atom_node tree='CANONICAL')
```

### 3.2 Reglas de transformación del Lexer (Fase 1)

El Lexer extrae la semántica implícita del nombre humano:

| Patrón SOURCE (regex) | Trigger canónico | Prop extraída | Operador | Valor |
|---|---|---|---|---|
| `/monto.*>\s*(\d[\d\s]*)/i` | `financial_approve` | `transaction.amount_bob` | `>` | grupo capturado |
| `/config.*change|verbo.*CONFIG\|ADMIN/i` | `system_config_change` | `action.verb` | `IN` | `[CONFIGURE,ADMIN,DELETE]` |
| `/zona.*segur|security.*level.*CRITICAL/i` | *(sin equivalente canónico)* | — | — | GAP |
| `/intentos.*(\d+)-(\d+)/i` | `lockout_attempt_range_{N}_{M}` | `login.failed_attempts_in_window` | `BETWEEN` | `[N, M]` |
| `/intentos.*>\s*(\d+)/i` | `lockout_attempt_overflow` | `login.failed_attempts_in_window` | `>` | grupo capturado |
| `/riesgo.*bajo|risk.*low/i` | `low_risk` | `risk.score` | `<=` | `0.50` |
| `/zona.*sensible|sensitivity.*HIGH/i` | `sensitive_zone` | `zone.sensitivity` | `IN` | `[HIGH,CRITICAL]` |

### 3.3 Reglas de transformación del Emitter (Fase 3)

| Elemento SOURCE | Transformación CANONICAL |
|---|---|
| `node_key` humano | `ATOM_ID` canónico (snake_case, extraído por Lexer) |
| `TipoNodo.evaluacion` | `evaluacion` + `verbo` explícito + `prop_path` + `operator` + `prop_val` + `xacml_effect` |
| `TipoNodo.politica` sin `combining_algorithm` | Añadir `combining_algorithm = deny-overrides` (default) + Warning |
| `TipoNodo.regla` sin `verbo` | Añadir `verbo = ANY` + Warning |
| `_prop('A AND B')` malformado | Split en `regla` con 2 `evaluacion` + `op_lógico('AND')` |
| `TipoNodo.lista` con hijos `evaluacion` | Reclasificar a `TipoNodo.politica` + Warning |
| `efecto` en texto libre | Parsear → `xacml_effect = PERMIT|DENY` + `obligation = texto_restante` |

### 3.4 Niveles de diagnóstico del compilador

| Nivel | Código | Significado | Acción |
|---|---|---|---|
| **ERROR** | E-001 | `regla` sin efecto al final | Compilación detenida |
| **ERROR** | E-002 | `_prop` con AND/OR incrustado | Compilación detenida — requiere split manual |
| **ERROR** | E-003 | `lista` contiene `evaluacion` con efecto | Compilación detenida — reclasificar a `politica` |
| **WARNING** | W-001 | Nodo SOURCE sin equivalente CANONICAL | GAP registrado — compilación continúa |
| **WARNING** | W-002 | Nombre humano sin trigger canónico conocido | Requiere mapeo manual en tabla `atom_lexer_rules` |
| **WARNING** | W-003 | `politica` sin `combining_algorithm` | Default `deny-overrides` aplicado |
| **WARNING** | W-004 | `evaluacion` sin `verbo` | Default `ANY` aplicado |
| **INFO** | I-001 | Nombre SOURCE transformado exitosamente | Registrado en `atom_node.canonical_id` |

---

## 4. Tabla de equivalencias — RolTemplate SSOT vs árbol SOURCE

Esta tabla es el corazón del compilador: mapea los nombres humanos del árbol SOURCE a los identificadores canónicos del RolTemplate v6.0.

### D1 · step_up_triggers

| SOURCE `node_key` | CANONICAL `atom_id` | `prop_path` | `operator` | `val` | `verbo` | Gap |
|---|---|---|---|---|---|---|
| `monto de transacción alto (>10 000 BOB)` | `financial_approve` | `transaction.amount_bob` | `>` | `10000` | `execute` | NOMBRE |
| `verbo CONFIGURE o ADMIN` | `system_config_change` | `action.verb` | `IN` | `[CONFIGURE,ADMIN,DELETE]` | `configure` | NOMBRE |
| `zona de alta seguridad` | *(sin equivalente)* | `zone.security_level` | `==` | `CRITICAL` | `ANY` | **SIN_EQUIVALENTE** |

### D1 · account_lockout_policy

| SOURCE `node_key` | CANONICAL `atom_id` | `prop_path` | Gap |
|---|---|---|---|
| `intentos 1-3: sin penalización` | `lockout_range_1_3` | `login.failed_attempts_in_window` | NOMBRE |
| `intentos 4-6: retardo progresivo` | `lockout_range_4_6` | `login.failed_attempts_in_window` | NOMBRE |
| `intentos 7-10: bloqueo temporal` | `lockout_range_7_10` | `login.failed_attempts_in_window` | NOMBRE |
| `intentos > 10: bloqueo hasta administrador` | `lockout_overflow` | `login.failed_attempts_in_window` | NOMBRE |
| `ventana de conteo de intentos` | `lockout_window_60m` | `login.attempt_window_minutes` | NOMBRE |

### D1 · primary_auth condiciones

| SOURCE `node_key` | CANONICAL `atom_id` | Gap |
|---|---|---|
| `riesgo bajo + zona normal → contraseña` | `low_risk_password_grant` | NOMBRE |
| `riesgo bajo` | `risk_score_low` | NOMBRE |
| `zona no sensible` | `zone_not_sensitive` | NOMBRE |
| `zona sensible o acción privilegiada → hardware` | `sensitive_zone_hardware_grant` | NOMBRE |
| `zona sensible` | `zone_sensitivity_high` | NOMBRE |
| `verbo privilegiado` | `privileged_verb_check` | NOMBRE |
| `certificado mTLS presente → x509` | `mtls_cert_x509_grant` | NOMBRE |

---

## 5. Estado de implementación

| Componente | Estado |
|---|---|
| Schema `atomlang` en VPS PostgreSQL 18 | ✅ Creado |
| Tabla `atom_node` (adj. list + mat. path) | ✅ Creada |
| Vista `vw_atom_path` (ruta completa) | ✅ Creada |
| Vista `vw_gaps` (análisis SOURCE vs CANONICAL) | ✅ Creada |
| Datos D1 `step_up_triggers` SOURCE + CANONICAL | ✅ Insertados y vinculados |
| Datos D1 completo (resto de políticas) | ⬜ Pendiente |
| Datos D0 completo | ⬜ Pendiente |
| Datos D2–D12 completo | ⬜ Pendiente |
| Tabla `atom_lexer_rules` (reglas Lexer) | ⬜ Pendiente |
| Implementación Fase 1 Lexer (Rust/SQL) | ⬜ Pendiente |
| Implementación Fase 2 Parser (Rust/SQL) | ⬜ Pendiente |
| Implementación Fase 3 Emitter (Rust/SQL) | ⬜ Pendiente |
| Integración con `bos_atom_catalog` (DDL real) | ⬜ Pendiente |
