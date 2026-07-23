# A.45 — Fundamentos Normativos de AtomLang
## Tipo B+C — Respaldo normativo e investigación: de dónde proviene cada constructo del lenguaje

**Versión:** 1.2.0  
**Fecha:** 2026-07-14  
**Tipo de anexo:** B (respaldo normativo/industria) + C (justificación de decisión técnica)  
**Respalda a:** [2.13 MANUAL-ATOMLANG-LENGUAJE v2.0 §2–§7](../2.13_MANUAL-ATOMLANG-LENGUAJE-v2.0.md) · [1.06 D00 Identidad v2.0](../1.06_MANUAL-D00-IDENTIDAD-v2.0.md) · [1.07 Atributos v2.0](../1.07_MANUAL-ATRIBUTOS-v2.0.md) · [2.15 Motor de Identidad](../2.15_MANUAL-MOTOR-IDENTIDAD-v1.0.md) · [2.14 MANUAL-COMPOSICION-ARBOL §3–§7](../2.14_MANUAL-COMPOSICION-ARBOL-v1.0.md) · [2.05 MANUAL-POLITICAS §2](../2.05_MANUAL-POLITICAS-v1.0.md)  
**Normas consultadas:** OASIS XACML 3.0 · NIST SP 800-162 (ABAC) · NIST SP 800-207 (Zero Trust) · NIST SP 800-53 Rev.5 AC-3 · ANSI INCITS 359-2004 (RBAC) · ISO 24760-2:2025 · ISO 27001:2022 A.5.15-18 · ISO 9001:2015 §3.2.4 · SCIM 2.0 RFC 7643 · TOGAF 10

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

*Consecuencia para auditoría:* los cuatro valores deben registrarse en `privilege_atom_audit` (WORM). Un `Indeterminate` no registrado es un vector de auditoría ciego — si el PIP falla al resolver un atributo, el sistema debe registrar que no pudo decidir, no fallar silenciosamente a un default.

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

## §9 Dominios: planos de control (D00-D13) y dominios del lenguaje (D95-D99)

*Cita ISO 24760-2:2025 §5.1 (Identity Management Reference Architecture):* *"An identity domain is a bounded context within which the identity of an entity is managed... Access to resources within the domain is governed by the policies of that domain."*

*Cita NIST SP 800-63 §6.2 (Federation):* *"A federation is a set of organizations that agree to share identity information. Each organization operates within its own trust domain."*

### §9.1 Planos de control (D00-D13) — los módulos de evaluación del BitMask

Fuente: Manual 1.01 §4. Los 14 planos de control son los **planos de identidad** sobre los
que opera el BitMask 64-bit. Cada uno es un evaluador de dominio con código Rust en
`src/domain/`. El pipeline de evaluación los ordena en 5 fases con cortocircuito (D8→D9
Pre-BitMask, D1→D2 Fast-Path, D3→D10→D4 Policy-Path, D6→D7→D5→D12 External, D11 Siempre).

| Plano | Nombre | Path | Norma de referencia |
|:-----:|--------|------|---------------------|
| D00 | Identidad Organizacional | Pre-condición (ctx_id) | ISO 24760-2:2025 §5 · NIST SP 800-63 §4 |
| D1 | Acceso Lógico | Fast-Path <0.5ns | NIST 800-63B-4 · RFC 9470 · XACML 3.0 |
| D2 | Acceso Físico | Fast-Path +OSDP | IEC 60839-11-5 · OSDP v2.2.2 · NIST SP 800-116 |
| D3 | Financiero | Policy-Path | PCI DSS 4.0.1 · SOX §404 · COSO · ISO 20022 |
| D4 | Temporal | Policy-Path (encadenado a D1) | GTRBAC · RFC 5545 · ISO 8601 |
| D5 | Biométrico | External-Path | ISO/IEC 30107-3 · NIST SP 800-63B §5.2.3 |
| D6 | Geoespacial | External-Path (encadenado a D1) | OGC GeoFence · BeyondCorp |
| D7 | Red | External-Path (vía Kong) | NIST SP 800-207 ZTA · IEEE 802.1X |
| D8 | Contexto/Sesión | Pre-BitMask | SBOS-049 · W3C Trace Context · CAEP |
| D9 | Credenciales | Pre-BitMask | NIST SP 800-63B AAL1-3 · FIDO2 · WebAuthn |
| D10 | Delegación | Policy-Path (reducción AND) | INCITS 359 DSD · NIST AC-5 |
| D11 | Auditoría | Post-hoc (registra, no decide) | ISO 27001 A.8.15 · PCI 10.3.2 · NIST AU-2/3 |
| D12 | Blockchain/Anclaje | External-Path | NIST IR 8202 · EIP-725/735 · W3C DID |
| D13 | Firma Digital Externa | Diseño (átomos 5929-5964) | Ley 164 · ADSIB-FD-POLT-015 v2.3 |

### §9.2 Dominios del lenguaje AtomLang (D95-D99)

Además de los 14 planos de control que participan en la evaluación del BitMask, AtomLang
define **5 dominios del lenguaje** que no son evaluados en runtime pero son parte de la
estructura del DSL. Residen en el mismo árbol (`bauth.atom_tree`) pero tienen reglas
diferentes:

#### D95 — Catálogo de Átomos Compilados

**Rol:** Dominio auto-generado de solo lectura. La "tabla de símbolos" del sistema: contiene
los átomos que pasaron la compilación y están listos para ser asignados a roles.

**Base normativa:**
- NIST SP 800-162 §4.2: integridad de política — separación entre definición y ejecución
- ISO 27001:2022 A.8.9: gestión de configuración — solo artefactos validados llegan a producción
- Principio de compilación: el PDP lee exclusivamente el IR compilado (A.46 §3.2), nunca el fuente

**Comportamiento normativo:**
- Si un átomo en D00-D13 pasa D97 (normas) y D96 (contrato de métodos) → atomc lo emite en D95 como ACTIVO
- Si el átomo se corrompe en el árbol fuente → atomc lo remueve de D95 (estado CORROMPIDO)
- D95 garantiza que ningún átomo no validado llegue al PDP (fail-secure por defecto)

#### D96 — Contrato de Métodos de Autenticación

**Rol:** Define los contratos de entrada/salida de los 18 métodos de autenticación.
Es el "sistema de tipos" de los métodos auth: qué datos necesita cada método, qué retorna,
qué debe proveer el cliente, y las secuencias válidas de flujos multi-step.

**Base normativa:**
- NIST SP 800-63B §4 (AAL1-3): cada nivel de assurance requiere métodos y combinaciones específicas
- RFC 9470 (Step-Up Authentication): el orden de métodos en un flujo step-up es normativo
- FIDO2/WebAuthn W3C: contratos de entrada/salida para autenticación sin contraseña
- ISO 27001:2022 A.5.15: reglas de acceso basadas en requisitos de negocio

**¿Qué valida?**
- Que cada método declare sus parámetros obligatorios (entrada) y su respuesta (salida)
- Que los flujos multi-step tengan orden canónico y timeout definido
- Que las precondiciones del cliente estén documentadas (dispositivo, canal, LoA previo)

#### D97 — Conformidad Normativa

**Rol:** Meta-dominio. Define los requisitos que cada nodo del árbol debe cumplir para ser
conforme a las normas. Es el "type checker" de cumplimiento: cada tipo de nodo tiene una
lista de requisitos trazables a un estándar.

**Base normativa:**
- ISO 27001:2022 A.5.15: *"Rules for access control shall be established based on business and information security requirements"*
- NIST SP 800-162 §5: *"Attribute values should be obtained from authoritative attribute sources"*
- XACML 3.0 §7.3: orden de evaluación Target → Condition → Effect
- NIST SP 800-53 AC-6: principio de mínimo privilegio (verbo obligatorio en todo átomo)

**Requisitos que valida (catálogo parcial):**

| Requisito | Aplica a | Norma |
|---|---|---|
| combining_algorithm obligatorio | Política con 2+ átomos | XACML 3.0 §7.18 |
| verbo debe existir en catálogo | Toda evaluación | NIST SP 800-162 §4 |
| property_id tipado | Toda condición | NIST SP 800-162 §4 |
| subject.set_id declarado en D98 | Todo Target con SET | ANSI INCITS 359-2004 |
| Sin literales numéricos en AMOUNT | Toda condición con tipo AMOUNT | NIST SP 800-162 §5 · ISO 27001 A.8.9 |
| effect.decision solo Permit/Deny | Todo Effect | XACML 3.0 §2.6 |
| Sin atributos duplicados Target/Condition | Todo átomo | XACML 3.0 §7.3 |

#### D98 — Registro Estructural

**Rol:** Declaraciones del lenguaje. NO produce Decision. NO entra al BitMask. Contiene
constantes (`@bauth_config_param.*`), conjuntos de roles (`Set<Rol>`), y enums del lenguaje.

**Base normativa:**
- ANSI INCITS 359-2004 §3.1 (Core RBAC): la asignación de permisos a roles es la base del modelo
- NIST SP 800-53 AC-2: group membership como mecanismo de asignación
- NIST SP 800-162 §5: gobernanza de atributos — constantes como fuente autoritativa

**Por qué existe separado:** los conjuntos cambian por movimientos organizacionales (altas/bajas
frecuentes). Las reglas cambian por compliance (infrecuente). Separarlos permite cambiar la
membresía de un conjunto sin recompilar todo el árbol de políticas.

#### D99 — Administrativo Global

**Rol:** Garante transversal. PolicySet global cuyas políticas aplican a TODO el sistema.
No entra al BitMask funcional. Es el garante de D00 (identidad organizacional). Cambia
solo por HITL. 447 nodos.

**Base normativa:**
- NIST SP 800-207 §3.1: Control Plane Policies — políticas que gobiernan el plano de control
- AWS SCP analogy: límites de permiso globales que aplican antes que cualquier política de recurso
- ISO 27001:2022 A.5.18: gobernanza de acceso privilegiado

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
| D95 Catálogo de Átomos | NIST SP 800-162 §4.2 (integridad) | §4.2 IR integrity | A.8.9 | Principio fail-secure |
| D96 Contrato de Métodos | NIST SP 800-63B §4 (AAL1-3) | §5 Attribute authority | A.5.15 | RFC 9470 · FIDO2 |
| D97 Conformidad Normativa | XACML 3.0 §7.3 | §4 Boolean function | A.5.15 | NIST SP 800-53 AC-6 |
| D98 Registro Estructural | — (no XACML) | §3 Group attribute | A.5.18 | ANSI INCITS 359-2004 |
| D99 Admin Global | NIST SP 800-207 §3.1 (Control Plane) | — | A.5.18 | AWS SCP analogy |

---

## §13 Mapa anexo → manuales

| Sección de este anexo | Respalda al manual | Sección respaldada |
|---|---|---|
| §2 (XACML como base) | 2.13 v2.0 §2, §5 | Por qué existe AtomLang; constructos del lenguaje |
| §3 (Target) | 2.13 v2.0 §5.3 | Target: Subject, Resource, Verbo, Environment |
| §4 (Condition) | 2.13 v2.0 §5.3 | Condition y operadores |
| §5 (Effect/Obligation) | 2.13 v2.0 §5.3 | Effect y Obligation |
| §6 (combining_algorithm) | 2.13 v2.0 §5.2 | combining_algorithm |
| §7 (Zonas) | 2.14 §4 | Las zonas (B6) — concepto y reglas |
| §8 (Aplicaciones) | 2.14 §5 | Las aplicaciones — dentro de zonas |
| §9.1 (Planos D00-D13) | 2.13 v2.0 §4.2 · 2.14 §3 | Planos de control como módulos |
| §9.2 (Dominios D95-D99) | 2.13 v2.0 §4.3 | Dominios del lenguaje AtomLang |
| §10 (bauth_config_param) | 2.14 §7 | Reglas de parametrización |
| §11 (Bloques B0–B19) | 2.14 §2 | El árbol RolTemplate |
| §12 (Tabla maestra) | 2.13 v2.0, 2.14, 2.05 | Referencia transversal de cumplimiento |

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
| 1.2.0 | 2026-07-14 | **Dominios D93-D94 + Motor de Identidad.** Nueva §14: D93 (Catálogo de Identidades: ISO 9001, SCIM), D94 (Registro de Usuarios: NIST AC-2, ANSI INCITS 359), Motor de Identidad (NIST 800-63A/B, RFC 5321, E.164, BCP 47), gobernanza de atributos vía átomos D00. Cabecera actualizada con referencias a 1.06 v2.0, 1.07 v2.0, 2.15. |
| 1.1.0 | 2026-07-14 | Actualización mayor: §9 reescrito con las DOS taxonomías de dominio (planos de control D00-D13 según Manual 1.01 §4 + dominios del lenguaje D95-D99 según Manual 2.13 v2.0 §4.3). Nuevos dominios documentados: D95 (Catálogo de Átomos — NIST SP 800-162 §4.2 integridad de política, ISO 27001 A.8.9, principio fail-secure), D96 (Contrato de Métodos — NIST SP 800-63B §4 AAL1-3, RFC 9470 Step-Up, FIDO2/WebAuthn), D97 (Conformidad Normativa — XACML 3.0 §7.3, NIST SP 800-162 §5, NIST SP 800-53 AC-6). Tabla D00-D13 corregida con los 14 planos completos (D3 Financiero, no Firma Digital; D13 Firma Digital Externa Ley 164). §12 tabla maestra ampliada de 17 a 22 constructos. §13 mapa actualizado con referencias a 2.13 v2.0. |
| 1.0.0 | 2026-07-13 | Primera edición. Mapa normativo completo de todos los constructos de AtomLang. |


---

## §14 — v1.2.0: Dominios del lenguaje D93-D94 y Motor de Identidad (2026-07-14)

### D93 — Catálogo de Identidades

Define qué `tipo` es válido para cada `nivel` en `idn_identidad_entidad`, qué atributos son requeridos,
y qué conjuntos de membresía (USERSET) son permitidos para cada tipo de entidad. Base normativa:

- **ISO 9001:2015 §3.2.4**: definición de cliente como quien recibe el producto/servicio
- **ISO 9001:2015 §3.2.5**: definición de proveedor como quien provee
- **ANSI INCITS 359-2004 §3.1 (Core RBAC)**: conjuntos de usuarios como entidad de membresía
- **SCIM 2.0 RFC 7643 §4.1**: atributos canónicos de recurso extensible

### D94 — Registro de Usuarios

Define conjuntos de usuarios (USERSET) que agrupan entidades por contexto operativo.
Una entidad pertenece a múltiples conjuntos sin duplicarse. Base normativa:

- **NIST SP 800-53 AC-2**: group membership como mecanismo de asignación
- **ANSI INCITS 359-2004**: user assignment (UA) en RBAC

### Motor de Identidad

El motor de validación de datos de entidades usa el MISMO lenguaje AtomLang que el motor
BitMask. Verbos: `validate` (formato), `verify` (fuente externa: SIN, SEGIP, ADSIB),
`format` (canónico). Base normativa:

- **NIST SP 800-63A**: Identity Assurance Levels (IAL) — verificación de evidencia
- **NIST SP 800-63B §5**: verificación de canales (email, teléfono)
- **RFC 5321**: formato de email · **E.164**: formato de teléfono
- **BCP 47**: formato de locale · **IANA**: formato de timezone

### Gobernanza de atributos vía átomos D00

Los atributos en `idn_identidad_atributo.atom_code` vinculan cada atributo con un átomo D00 en
`privilege_atom`. Esto permite que el BitMask gobierne quién puede ver/editar cada
atributo de identidad. Base normativa:

- **NIST SP 800-162 §4**: separación PAP/PDP/PEP/PIP
- **NIST SP 800-162 §5**: gobernanza de atributos desde fuente autoritativa
