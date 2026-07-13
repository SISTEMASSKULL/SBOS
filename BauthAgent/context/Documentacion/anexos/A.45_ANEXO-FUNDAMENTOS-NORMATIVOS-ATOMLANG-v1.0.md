# A.45 — Fundamentos Normativos de AtomLang
## Tipo B+C — Respaldo normativo e investigación: de dónde proviene cada constructo del lenguaje

**Versión:** 1.0.0  
**Fecha:** 2026-07-13  
**Tipo de anexo:** B (respaldo normativo/industria) + C (justificación de decisión técnica)  
**Respalda a:** [2.13 MANUAL-ATOMLANG-LENGUAJE §2–§6](../2.13_MANUAL-ATOMLANG-LENGUAJE-v1.0.md) · [2.14 MANUAL-COMPOSICION-ARBOL §3–§7](../2.14_MANUAL-COMPOSICION-ARBOL-v1.0.md) · [2.05 MANUAL-POLITICAS §2](../2.05_MANUAL-POLITICAS-v1.0.md)  
**Normas consultadas:** OASIS XACML 3.0 (docs.oasis-open.org) · NIST SP 800-162 (ABAC) · NIST SP 800-207 (Zero Trust) · NIST SP 800-53 Rev.5 AC-3 · ISO 24760-2:2025 · ISO 27001:2022 A.5.15-18 · TOGAF 10

---

## §1 Propósito y cómo citarlo

Este anexo es la **fuente normativa de todo constructo de AtomLang**. Los manuales 2.13 y 2.14 afirman que cada elemento del lenguaje (átomo, política, zona, aplicación, dominio, target, condition, effect, combining_algorithm, bauth_config_param) proviene de un estándar reconocido — este anexo verifica y documenta esa afirmación, norma por norma, citación por citación.

**Cómo citarlo:** `A.45 §N` (ej. "norma de zona: A.45 §5").

**Frontera con los manuales:** este anexo NO repite la doctrina de uso de AtomLang (eso está en 2.13 y 2.14). Este anexo contiene la **investigación normativa** que respalda esa doctrina — la norma original, el fragmento relevante, el mapeo a bAuth, y la verificación de que la adaptación es conforme.

---

## §2 La raíz: OASIS XACML 3.0 como base del modelo

AtomLang no inventa una semántica nueva. Es una **adaptación soberana de OASIS XACML 3.0** — el estándar de facto de control de acceso por atributos adoptado por gobierno, financiero y defensa a nivel internacional.

**Referencia normativa:** OASIS Standard, *eXtensible Access Control Markup Language (XACML) Version 3.0*, 22 January 2013, docs.oasis-open.org/xacml/3.0/xacml-3.0-core-spec-os-en.html

La arquitectura de XACML 3.0 define tres elementos de política y cuatro componentes funcionales que AtomLang adopta íntegramente:

### §2.1 Los tres elementos de política XACML → equivalentes bAuth

| XACML 3.0 | Definición normativa (extracto) | Equivalente bAuth / AtomLang |
|---|---|---|
| **`<PolicySet>`** | *"Contains a set of `<Policy>` or other `<PolicySet>` elements and a specified procedure for combining the results of their evaluation."* (§5.1) | Dominio (D00–D13) · Zona (B6 `zona_*`) · Bloque contenedor (B7 como PolicySet) |
| **`<Policy>`** | *"Contains a set of `<Rule>` elements and a specified procedure for combining the results of their evaluation... The `<Policy>` element is the basic unit of policy used by the PDP."* (§5.2) | Política (`bos_atom_policy`, `cfg_policy_library`) · Aplicación (`bos_application`) dentro de una zona |
| **`<Rule>`** | *"The most elementary unit of policy... A Rule is intended to be evaluated in the context of a containing `<Policy>`."* (§5.3) | Átomo (`bos_atom_catalog`) — la unidad atómica evaluable de bAuth |

### §2.2 Los cuatro componentes funcionales XACML → equivalentes bAuth

| XACML / NIST SP 800-162 | Función normativa | Equivalente bAuth |
|---|---|---|
| **PAP** (Policy Administration Point) | Donde se crean y gestionan las políticas | UI de templates de rol + `bos_atom_catalog` |
| **PDP** (Policy Decision Point) | Donde se evalúa la solicitud y se produce la decisión | Motor BitMask + `rule_engine.rs` |
| **PEP** (Policy Enforcement Point) | Donde se intercepta la solicitud real y se hace cumplir la decisión | Middleware / Kong PEP (bAuth boundary) |
| **PIP** (Policy Information Point) | Fuente de atributos adicionales para la evaluación | Context Plane (`ctx_id`, §SBOS-049) · `bauth_config_param` |

*Cita NIST SP 800-162 §4:* *"The four main functional points of an ACM include the Policy Enforcement Point (PEP), the Policy Decision Point (PDP), the Policy Information Point (PIP), and the Policy Administration Point (PAP)."*

### §2.3 Por qué YAML y no XML (XACML nativo) ni Rego (OPA) ni Cedar

| Alternativa | Ventaja | Por qué NO para AtomLang |
|---|---|---|
| **XACML XML nativo** | Estándar de facto, interoperable | XML verboso — un Atom simple requiere 80+ líneas. Ilegible para administradores no técnicos |
| **ALFA** (sintaxis abreviada de XACML) | Legible, compatible XACML | Ecosistema Java — incompatible con el stack Rust MUSL soberano |
| **OPA/Rego** | Ecosistema cloud-native, flexible | Paradigma Datalog — curva pronunciada para administradores IAM. Interpretado, no compilado |
| **Cedar** | Verificación formal, Rust | Semántica propia, no mapea a los dominios D00–D13 ni al BitMask de bAuth sin adaptación total |
| **YAML + JSON Schema + atomc** (**elegido**) | YAML ya conocido, JSON Schema es estándar, compilador en Rust comparte stack | Restringe YAML en lugar de inventar sintaxis — el administrador ya "sabe" YAML; `atomc` agrega la capa de validación |

**Decisión:** *YAML restringido + compilador nativo Rust* — coherente con el stack SBOS (fabrica.sh, CLAUDE.md, specs ya en YAML/Markdown). No introduce formato ajeno. El compilador es parte del daemon, comparte tipos y puede reutilizar directamente los newtypes de bAuth (`verb_id`, `policy_id`, etc.).

---

## §3 Target: norma de cada categoría de atributo

*Cita XACML 3.0 §2.4:* *"As XACML is used in Attribute-Based Access Control, all the attributes are categorized into four main categories: Subject, Resource, Action, Environment."*

*Cita XACML 3.0 §5.5:* *"An empty `<Target>` matches any request."*

*Cita NIST SP 800-162 §3:* *"Access control policy can be composed of subject attributes, object (resource) attributes, environment attributes, and other attributes."*

| Categoría XACML | Nombre en AtomLang bAuth | Fuente normativa | Ejemplo en bAuth |
|---|---|---|---|
| **Subject** | `target.subject` (ROL \| SET \| ANY) | XACML §2.4 · NIST 800-162 §3 · NIST RBAC SP 800-53 AC-3 | `SET(analistas_finanzas)` — FK a `bos_group` (D98) |
| **Resource** | `target.resource` | XACML §2.4 · NIST 800-162 §3 | `payment_supplier_transaction` — FK a `bos_resource_catalog` |
| **Action** | `verb_id` (dentro de `target`, como primer elemento) | XACML §2.4 · NIST 800-162 §3 | `approve` — FK a `bos_verb` |
| **Environment** | `target.environment[]` | XACML §2.4 · NIST 800-162 §3 | `horario_laboral == true` — resuelto por PIP (Context Plane) |

**Subject — tres formas, norma de cada una:**

| Forma | Norma | Descripción |
|---|---|---|
| `kind: ROL` (rol único) | NIST RBAC ANSI INCITS 359-2004 §3.1 | Un solo rol como sujeto — uno a uno |
| `kind: SET` (grupo) | NIST SP 800-53 AC-2 (group membership) · XACML §5.5 (SubjectCategory) | Conjunto de roles declarado en D98 — FK a `bos_group` |
| `kind: ANY` | XACML 3.0 §5.5 ("An empty Target matches any request") | Cualquier actor autenticado — típico en Guardrails transversales |

---

## §4 Condition y operadores: norma ABAC

*Cita XACML 3.0 §5.6:* *"A Boolean expression that refines the applicability of the rule beyond the predicates implied by its target. Therefore, it may be absent."* y *"An empty Condition is always evaluated to true."*

*Cita NIST SP 800-162 §4:* *"An ABAC rule specifies access decisions based on attributes of subjects, objects (resources), and the environment in the form of Boolean functions."*

Los operadores de AtomLang son el vocabulario cerrado de la función booleana ABAC:

| Operador AtomLang | Tipo de función booleana | Norma base |
|---|---|---|
| `==` `!=` | Igualdad de atributo | XACML FunctionId `urn:oasis:names:tc:xacml:1.0:function:string-equal` |
| `>` `<` `>=` `<=` | Comparación numérica | XACML FunctionId `integer-greater-than` / `integer-less-than` |
| `IN` `NOT_IN` | Pertenencia a conjunto | XACML FunctionId `string-is-in` / `string-bag` |
| `BETWEEN` | Rango numérico | Composición XACML (`AND` de `>=` + `<=`) |

**Evaluación en dos etapas — invariante crítica de seguridad:**

```
1. Target-gate: Match | No-Match | Indeterminate
   (se evalúa SIEMPRE primero — si No-Match, el Atom devuelve NotApplicable)
2. Condition: True | False | Indeterminate
   (se evalúa SOLO si el Target cerró en Match)
```

*Cita XACML 3.0 §7.3:* *"If the target result is 'Match', then the PDP SHALL proceed to evaluate the condition... If the target result is 'No-match', then the Rule is 'NotApplicable'."*

Un evaluador que ejecute la Condition antes de confirmar el Target-gate produce resultados falsos positivos — este fue exactamente el defecto D2 detectado en el árbol real de bAuth (documentado en [A.46 §3](A.46_ANEXO-ATOMLANG-GRAMATICA-COMPILADOR-v1.0.md)).

---

## §5 Effect, Obligation y Advice: norma XACML §2.6

*Cita XACML 3.0 §2.6:* *"The effect of the rule indicates the rule-writer's intended consequence of a 'True' evaluation of the rule. Two values are allowed: 'Permit' and 'Deny'."*

*Cita XACML 3.0 §5.3.15:* *"An obligation expression SHALL be fulfilled by the PEP... If an obligation cannot be fulfilled, the PEP SHALL deny the access."*

*Cita XACML 3.0 §6.5 (Advice):* *"Advice is similar to obligations... The difference is contractual: the PEP can disregard any advice it receives."*

| Constructo AtomLang | Norma | Semántica |
|---|---|---|
| `effect.decision: Permit` | XACML §2.6 | Decisión afirmativa — el acceso se concede |
| `effect.decision: Deny` | XACML §2.6 | Decisión negativa — el acceso se deniega |
| `effect.obligation` | XACML §5.3.15 | El PEP DEBE ejecutar — no puede ignorarlo (ej. auditoría WORM, step-up) |
| `effect.advice` | XACML §6.5 | El PEP PUEDE ignorarlo — información para UI/logging |

**Los cuatro valores de Decision del evaluador** (no del Effect del Atom):

| Valor | Norma | Cuándo ocurre |
|---|---|---|
| `Permit` | XACML §7.3 | Target Match + Condition True + Effect=Permit |
| `Deny` | XACML §7.3 | Target Match + Condition True + Effect=Deny |
| `NotApplicable` | XACML §7.3 | Target No-Match — el Atom no aplica a esta solicitud |
| `Indeterminate` | XACML §7.3 | Error durante evaluación (PIP falla, atributo faltante, tipo inválido) |

*Consecuencia para auditoría:* los cuatro valores deben registrarse en `bos_atom_audit` (WORM). Un `Indeterminate` no registrado es un vector de auditoría ciego — si el PIP falla al resolver un atributo, el sistema debe registrar que no pudo decidir, no fallar silenciosamente a un default.

---

## §6 combining_algorithm: norma XACML §7.18

*Cita XACML 3.0 §7.18:* *"In the case of the Deny-overrides algorithm, if a single `<Rule>` or `<Policy>` element is encountered that evaluates to 'Deny', then, regardless of the evaluation result of the other elements, the combined result is 'Deny'."*

AtomLang adopta los 5 algoritmos XACML estándar y agrega una extensión propia:

| Algoritmo | XACML §7.18 | Extensión bAuth | Uso recomendado |
|---|---|---|---|
| `deny-overrides` | ✅ Estándar | — | Módulos de control estricto — **default** |
| `permit-overrides` | ✅ Estándar | — | Módulos de alta disponibilidad |
| `first-applicable` | ✅ Estándar | — | Reglas jerárquicas ordenadas |
| `deny-unless-permit` | ✅ Estándar (XACML 3.0) | — | Guardrails ("silencio = denegado") |
| `permit-unless-deny` | ✅ Estándar (XACML 3.0) | — | Contextos de baja sensibilidad |
| **`aggregate-strictest`** | ❌ No estándar | ✅ Extensión bAuth | Políticas step-up — toma el valor más estricto de todos los Permit concurrentes |

**`aggregate-strictest` — justificación normativa:**

XACML `first-applicable` sobre Atoms de step-up concurrentes produce un resultado arbitrario dependiente del orden de declaración — si `A1` (max_age=300) y `A2` (max_age=600) aplican simultáneamente, el resultado puede ser 300 o 600 según el orden, sin que el autor pueda controlarlo. `aggregate-strictest` resuelve esto: toma el `max_age` mínimo (más estricto) y el `required_loa` máximo (más alto) entre todos los Permit que aplican.

*Justificación NIST SP 800-63B §4.3:* *"The CSP SHALL use the most recent authenticator assurance level... [in case of multiple concurrent authentication requirements]"* — el principio de "valor más estricto" es consistente con el mandato NIST de usar el nivel más alto entre requisitos concurrentes.

---

## §7 Zonas: norma de micro-segmentación lógica

Las zonas (B6 `zona_*`) en el árbol de bAuth son una implementación del concepto de **segmento lógico** definido por NIST y aplicado en ISO 27001:

*Cita NIST SP 800-207 §2.2 (Zero Trust Architecture):* *"Micro-segmentation creates small zones of control around individual or small groups of resources. Access to each zone is independently managed... The ZTA approach creates the logical equivalent of a perimeter around each resource or small group of resources."*

*Cita ISO 27001:2022 A.8.22 (Segregation of networks):* *"Groups of information services, users and information systems shall be segregated in the organization's networks."*

| Concepto normativo | Norma | Equivalente en bAuth |
|---|---|---|
| Micro-segmento / Zone | NIST SP 800-207 §2.2 | `zona_*` en B6 del árbol (ej. `zona_logical_ventas`, `zona_financial_ventas`) |
| Segregación lógica | ISO 27001:2022 A.8.22 | Cada zona como PolicySet en el árbol — acceso gobernado por sus propios Atoms |
| Resource-based access | NIST SP 800-207 §3.3 | Los Atoms de zona regulan el ACCESO a la zona, no las operaciones dentro de ella |
| Perímetro de datos | NIST SP 800-207 §2.1 (ZTA) | La zona es el perímetro lógico — bAuth aplica Zero Trust interno: verificar cada acceso |

**Zona ≠ Dominio (distinción crítica):**

| | Dominio (D00–D13) | Zona (B6 `zona_*`) |
|---|---|---|
| **Qué es** | Plano de identidad (aspecto del BitMask) | Segmento lógico de negocio dentro de D1 |
| **Norma** | ISO 24760-2:2025 §5 (identity domain) · NIST SP 800-63 §6.2 | NIST SP 800-207 §2.2 · ISO 27001:2022 A.8.22 |
| **En el árbol** | Raíz del árbol (D00…D13) | Sub-nodo de D1 Acceso Lógico (B6) |
| **Contiene** | Bloques B0–B19 (aspectos del dominio) | Aplicaciones y sus Atoms de acceso |
| **¿Produce Decision?** | PolicySet (combina sus hijos) | Policy/PolicySet (gobierna el acceso a su segmento) |

---

## §8 Aplicaciones: norma de agrupación de recursos

Las aplicaciones dentro de zonas (B6 `app_*`) corresponden al concepto de **resource group** o **application component** en los estándares:

*Cita NIST SP 800-53 Rev.5 AC-3:* *"Enforce approved authorizations for logical access to information and system resources in accordance with applicable access control policies."* — el "system resource" se agrupa por aplicación/módulo.

*Cita TOGAF 10 §B.3 (Application Component):* *"An encapsulation of application functionality aligned to implementation structure, which is modular and replaceable."*

*Cita XACML 3.0 §5.2:* *"The `<Policy>` element... is intended to form the basis of an authorization decision [para un recurso o módulo concreto]."*

| Concepto normativo | Norma | Equivalente en bAuth |
|---|---|---|
| Application Component | TOGAF 10 §B.3 | `bos_application` (tryton.sale, orangehrm.leave, bos_crm) |
| Resource group | NIST SP 800-53 AC-3 | Conjunto de resources gobernados por la misma Policy |
| Policy (basic unit) | XACML 3.0 §5.2 | La Policy de una aplicación — agrupa sus Atoms y declara `combining_algorithm` |
| Scope of enforcement | NIST SP 800-207 §3.3 | Una aplicación = un scope de enforcement dentro de su zona |

**Aplicación vs. Zona — distinción operativa:**

| | Zona (`zona_*`) | Aplicación (`app_*`) |
|---|---|---|
| **Qué regula** | ACCESO al segmento lógico (¿puede el actor entrar?) | OPERACIONES dentro del módulo (¿qué puede hacer una vez dentro?) |
| **Nivel XACML** | PolicySet (contiene Policies de aplicaciones) | Policy (contiene Rules/Atoms de operaciones) |
| **Ejemplo** | `zona_financial_ventas` — ¿puede este rol acceder al dominio financiero de ventas? | `app_tryton_account` — ¿puede aprobar facturas dentro del dominio financiero? |
| **Átomo típico** | Verbo: `read`/`write`/`execute` sobre la zona como resource | Verbo: `approve`/`reconcile`/`void` sobre un objeto específico del módulo |

---

## §9 Dominios (D00–D13): norma de plano de identidad

*Cita ISO 24760-2:2025 §5.1 (Identity Management Reference Architecture):* *"An identity domain is a bounded context within which the identity of an entity is managed... Access to resources within the domain is governed by the policies of that domain."*

*Cita NIST SP 800-63 §6.2 (Federation):* *"A federation is a set of organizations that agree to share identity information. Each organization operates within its own trust domain."*

En bAuth, los 13 dominios (D00–D13) son los **planos de identidad** sobre los que opera el BitMask Dual 64-bit. Cada dominio es una raíz del árbol RolTemplate y un aspecto del modelo de identidad convergente:

| Dominio | Aspecto de identidad | Norma de referencia |
|---|---|---|
| D00 Identidad Organizacional | Directory / árbol de identidad | ISO 24760-2:2025 §5 · NIST SP 800-63 §4 |
| D1 Acceso Lógico | Access Management (AM) | XACML 3.0 · NIST SP 800-162 |
| D2 Acceso Físico | Physical Access Control | ISO 27001:2022 A.7.2 (physical access) · OSDP |
| D3 Firma Digital | Digital Signature | Ley 164 Bolivia · ADSIB FIPS 186-4 |
| D4 Calendario | Temporal conditions | RFC 5545 iCalendar · NIST SP 800-162 §4 |
| D12 Blockchain | Ledger / anclaje forense | Ethereum EVM · NIST SP 800-208 |
| D99 Admin Global | IGA / governance layer | NIST SP 800-53 AC-2 · ISO 27001:2022 A.5.18 |

Los bloques B0–B19 dentro de cada dominio son **agrupaciones de aspecto** — no son XACML por sí mismos, sino convenciones de organización del árbol bAuth que agrupan Policies relacionadas (análogo a XACML PolicySet anidado).

---

## §10 bauth_config_param: norma de fuente de atributos PIP

Los valores de negocio parametrizados (umbrales monetarios, monedas, límites, reglas) deben provenir de una fuente de atributos gobernada, no de literales hardcodeados en el árbol. Esta es la norma:

*Cita NIST SP 800-162 §5 (Attribute Considerations):* *"Attribute values should be obtained from authoritative attribute sources... The organization should establish policies for attribute management, including how attributes are created, updated, and revoked."*

*Cita XACML 3.0 §7.2 (PIP):* *"The PIP is the system entity that acts as a source of attribute values. These values are then used by the PDP to evaluate policies."*

| Concepto | Norma | Implementación bAuth |
|---|---|---|
| Attribute authority | NIST SP 800-162 §5 | `bauth_config_param` — fuente autoritativa de parámetros variables |
| PIP resolution | XACML §7.2 | El PDP llama al PIP (Context Plane) que resuelve `@bauth_config_param.clave` en runtime |
| Attribute governance | NIST SP 800-162 §5.3 | Los parámetros de `bauth_config_param` se gobiernan con auditoría WORM (quién cambió qué, cuándo) |
| Isolation of policy logic | ISO 27001:2022 A.8.9 | La política NO contiene datos de negocio — solo referencias; los datos viven en su fuente autoritativa |

**Por qué `bauth_config_param` y no `bos_config_param`:**  
`bos` es el daemon de control del plano de instalación (IAM Installer) — un universo distinto del de bAuth. `bauth_config_param` vive dentro del schema de bAuth, gobernado por bAuth, accesible solo por bAuth. La separación es consistente con la arquitectura de daemons soberanos de SBOS (SBOS-050 P9: nunca HTTP/TCP entre daemons).

---

## §11 Secciones y bloques (B0–B19): estructura propia de bAuth

Los bloques B0–B19 del RolTemplate no tienen un equivalente directo en XACML — son una convención de organización propia de bAuth. Su propósito es agrupar los aspectos del dominio en secciones temáticas mantenibles. El traslado fiel completo de los 14 bloques del RolTemplate v6.0 está en [A.01 §1-§14](A.01_ANEXO-ROLTEMPLATE-v1.0.md).

| Bloque | Aspecto agrupado | Nivel XACML aproximado |
|---|---|---|
| B0 Seguridad | Parámetros de seguridad del dominio | PolicySet (configuración, no Rules ejecutables) |
| B1 Organizacional | Identidad organizacional | PolicySet / datos (no produce Decision) |
| B4 Dominio lógico (autenticación) | Métodos de autenticación, step-up | PolicySet → Policies → Rules |
| B6 Zonas de negocio | Segmentos lógicos + aplicaciones | PolicySet → Policies (zonas) → Rules |
| B7 Privilege Engine | Motor algebraico NIST RBAC | PolicySet de 5 capas (model_access, visible_actions, field_restrictions, button_rules, record_rules) |
| D98 Registro Estructural | Catálogo de Sets de roles | NO produce Decision — es metadata de pertenencia |

---

## §12 Tabla maestra: cada constructo AtomLang → norma de origen

Referencia rápida para auditorías y verificación de cumplimiento:

| Constructo AtomLang | XACML 3.0 | NIST SP 800-162 | ISO 27001:2022 | Otros |
|---|---|---|---|---|
| `atom` (Rule) | §5.3 Rule | §4 ABAC Rule | A.5.15 | ANSI INCITS 359-2004 (RBAC Rule) |
| `policy` (Policy) | §5.2 Policy | §4 Policy | A.5.15 | — |
| `policy_set` (PolicySet) | §5.1 PolicySet | §4 Policy container | A.5.15 | — |
| `target.subject` | §5.5 AccessSubject | §3 Subject attribute | A.5.15, A.5.18 | NIST SP 800-53 AC-3 |
| `target.resource` | §5.5 Resource | §3 Object attribute | A.5.15 | NIST SP 800-53 AC-3 |
| `verb_id` (Action) | §5.5 Action | §3 Operation | A.5.15 | NIST RBAC §3.1 |
| `target.environment` | §5.5 Environment | §3 Environment attribute | A.5.15 | NIST SP 800-207 ZTA |
| `condition` | §5.6 Condition | §4 Boolean function | A.5.15 | — |
| `effect.decision` | §2.6 Effect (Permit/Deny) | §4 Decision | A.5.15 | — |
| `effect.obligation` | §5.3.15 Obligation | — | A.8.15 (audit) | — |
| `effect.advice` | §6.5 Advice | — | — | — |
| `combining_algorithm` | §7.18 Combining algorithms | §4 Conflict resolution | A.5.15 | — |
| `zona_*` (Zone) | PolicySet (contenedor) | — | A.8.22 | NIST SP 800-207 §2.2 |
| `app_*` (Application) | Policy (basic unit) | — | A.5.15 | TOGAF 10 §B.3 |
| Dominio D00–D13 | PolicySet raíz | — | — | ISO 24760-2:2025 §5 |
| Bloque B0–B19 | PolicySet anidado (convención) | — | — | Convención propia bAuth |
| `bauth_config_param` (PIP) | §7.2 PIP | §5 Attribute authority | A.8.9 | — |
| D98 Registro Estructural | — (no XACML) | §3 Group attribute | A.5.18 | NIST SP 800-53 AC-2 |

---

## §13 Mapa anexo → manuales

| Sección de este anexo | Respalda al manual | Sección respaldada |
|---|---|---|
| §2 (XACML como base) | 2.13 §2, §4 | Por qué existe AtomLang; constructos del lenguaje |
| §3 (Target) | 2.13 §4.2 | Target: Subject, Resource, Environment |
| §4 (Condition) | 2.13 §4.3 | Condition y operadores |
| §5 (Effect/Obligation) | 2.13 §4.4 | Effect y Obligation |
| §6 (combining_algorithm) | 2.13 §4.5 | combining_algorithm |
| §7 (Zonas) | 2.14 §4 | Las zonas (B6) — concepto y reglas |
| §8 (Aplicaciones) | 2.14 §5 | Las aplicaciones — dentro de zonas |
| §9 (Dominios) | 2.14 §3 | Los dominios D00–D13 como raíces |
| §10 (bauth_config_param) | 2.14 §7 | Reglas de parametrización |
| §11 (Bloques B0–B19) | 2.14 §2 | El árbol RolTemplate |
| §12 (Tabla maestra) | 2.13, 2.14, 2.05 | Referencia transversal de cumplimiento |

---

## Referencias

- OASIS Standard, *XACML Version 3.0*, 22 January 2013 — docs.oasis-open.org/xacml/3.0/xacml-3.0-core-spec-os-en.html
- NIST SP 800-162, *Guide to Attribute Based Access Control (ABAC) Definition and Considerations*, January 2014
- NIST SP 800-207, *Zero Trust Architecture*, August 2020
- NIST SP 800-53 Rev.5, *Security and Privacy Controls for Federal Information Systems*, September 2020
- NIST SP 800-63-4, *Digital Identity Guidelines*, 2024
- ISO/IEC 24760-2:2025, *Identity Management — Part 2: Reference architecture and requirements*
- ISO/IEC 27001:2022, *Information security management systems — Requirements*
- TOGAF 10, *The Open Group Architecture Framework*, 2022 — opengroup.org/togaf
- Amazon, *Cedar Policy Language Specification v3.3*, cedar-policy.github.io
- ANSI INCITS 359-2004, *Role Based Access Control*

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-13 | Primera edición. Mapa normativo completo de todos los constructos de AtomLang: XACML 3.0 como base (por qué YAML y no Cedar/OPA/ALFA); norma de Target (XACML §5.5 + NIST 800-162 §3); Condition (XACML §5.6 + invariante Target-gate primero); Effect/Obligation/Advice (XACML §2.6 + §5.3.15 + §6.5); combining_algorithm (XACML §7.18 + justificación de `aggregate-strictest` por NIST 800-63B §4.3); zonas B6 (NIST SP 800-207 §2.2 + ISO 27001:2022 A.8.22); aplicaciones (NIST SP 800-53 AC-3 + TOGAF 10 §B.3 + XACML §5.2); dominios D00–D13 (ISO 24760-2:2025 §5); bloques B0–B19 (convención propia bAuth); bauth_config_param como PIP (NIST SP 800-162 §5 + XACML §7.2). Tabla maestra de 17 constructos con sus normas. Corrección: `bos_config_param` → `bauth_config_param`. |
