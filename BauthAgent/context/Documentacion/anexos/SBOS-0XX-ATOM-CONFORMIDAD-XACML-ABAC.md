# SBOS-0XX — Definición Estricta de Átomos: Conformidad con XACML 3.0 y NIST SP 800-162 ABAC

**Estado:** Propuesto
**Dominio:** bAuth · IAM · AtomLang · PolicySet→Policy→Rule→Atom
**Tabla afectada:** `bauth.idn_roles_template` (T-162), nodos `tipo = 'evaluacion'`
**Fuentes normativas:** OASIS XACML 3.0 Core Specification, NIST SP 800-162 (ABAC)
**Objetivo:** fijar, columna por columna, qué exige la norma para que un átomo sea válido como `Rule` XACML — no una aproximación de negocio a XACML, sino conformidad estricta.

---

## 1. Por qué este documento

Durante el diseño de AtomLang se identificó que el mapeo entre columnas de negocio de T-162 y los elementos formales de un `<Rule>` XACML no estaba completamente alineado con la especificación. El caso concreto que disparó esta revisión: la columna `clave` (candidata a `nombre` del átomo) estaba recibiendo valores de texto libre en español (`'quórum de aprobadores'`) que, en la especificación real, no corresponden al identificador formal de la regla — corresponden a su descripción.

Este documento resuelve esa ambigüedad y, aprovechando la revisión, fija de forma completa y verificada contra la norma cómo debe estructurarse un átomo para ser XACML 3.0 estrictamente conforme, con su equivalente en ABAC (NIST SP 800-162).

---

## 2. Marco normativo: qué es realmente un `Rule` en XACML 3.0

Según la especificación OASIS XACML 3.0 Core, la unidad más elemental de una política es el `Rule`. Su definición formal, la más citada en literatura técnica derivada del estándar, es:

> *"A rule is a target, an effect, and a set of conditions."*

Un `<Rule>` XACML 3.0 tiene los siguientes componentes formales, cada uno con un rol específico y no intercambiable:

| Elemento XACML | Obligatorio | Rol |
|---|---|---|
| `RuleId` | **Sí** | Identificador único, estable, no legible-de-negocio. Sirve para referenciar la regla desde otras políticas y desde logs/auditoría. |
| `Description` | No | Texto libre, legible por humanos, explica el propósito de la regla. **Nunca sustituye al `RuleId`.** |
| `Target` | No* | Define el conjunto de requests (subject/resource/action/environment) a los que la regla podría aplicar. Si se omite, se calcula por herencia desde la `Policy` contenedora. |
| `Effect` | **Sí** | Único valor permitido: `Permit` o `Deny`. Es lo que la regla produce si el `Target` matchea y el `Condition` evalúa verdadero. |
| `Condition` | No | Expresión booleana adicional que refina la aplicabilidad más allá del `Target`. Puede anidar funciones y atributos arbitrariamente complejos. |
| `ObligationExpressions` | No | Acciones que el PEP **debe** ejecutar al hacer cumplir la decisión. No son opcionales para el PEP una vez que la regla se evalúa. |
| `AdviceExpressions` | No | Información adicional que el PEP **puede ignorar** con seguridad — a diferencia de las obligaciones. |

Un dato clave de la especificación, frecuentemente pasado por alto: **`Target` y `Condition` no son lo mismo**. El `Target` es lo que determina si la regla es *aplicable* a un request (un filtro de indexación, esencialmente); el `Condition` es lo que determina, una vez aplicable, si el efecto se *dispara*. Motores XACML reales usan el `Target` para indexar y descartar reglas rápidamente sin evaluar lógica compleja, y solo evalúan el `Condition` de las reglas que ya matchearon por `Target`. Esta distinción tiene implicancias de performance directas para tu PrivilegeEngine si se implementa igual.

**PolicySet y Policy** siguen el mismo patrón de identificador + descripción + contenedor de sus hijos + combining algorithm — `PolicySetId`/`PolicyId` como identificador formal, `Description` como texto de negocio, `Target` propio o heredado, y (opcionalmente) sus propias `ObligationExpressions`/`AdviceExpressions` adicionales a las de sus reglas hijas.

---

## 3. Marco complementario: NIST SP 800-162 (ABAC)

XACML es la implementación técnica; NIST SP 800-162 es el marco conceptual de referencia para el modelo ABAC que XACML implementa. Define formalmente:

- **Atributo**: característica que define un aspecto específico del subject, object, environment o acción solicitada, **predefinida y pre-asignada por una autoridad**. Este último punto es relevante: un atributo no es un valor ad-hoc, tiene que estar gobernado por un proceso de asignación con autoridad clara — lo cual es exactamente lo que tu WORM/hash-chain en `bos_atom_audit` está diseñado para evidenciar.
- **Subject**: entidad activa (individuo, proceso o dispositivo) que causa que la información fluya entre objetos o cambie el estado del sistema.
- **Object**: lo que el subject solicita acceder.
- **Operation**: la ejecución de una función a solicitud de un subject sobre un object (read, write, edit, delete, execute...).
- **Environment conditions**: atributos operacionales o situacionales — tiempo, ubicación, nivel de amenaza, temperatura, etc. Corresponde exactamente a tu concepto de Context Plane (`bos.GetContext()` con dispositivo, ubicación, horario, nivel de confianza).
- **Policy**: representación formal de las reglas o relaciones que describen las operaciones permitidas para un conjunto de atributos dado.

NIST SP 800-162 también formaliza los cuatro puntos funcionales del modelo de control de acceso — PEP, PDP, PIP (Policy Information Point) y PAP — que ya estás usando como vocabulario en tu arquitectura (bAuth como PAP/PDP, Kong como PEP). Vale notar que el modelo NIST incluye explícitamente el **PIP** como componente separado — el punto que resuelve/provee los valores de atributo en tiempo de evaluación. En tu arquitectura, el Context Plane (`bos.GetContext()`) cumple funcionalmente ese rol de PIP: es quien le entrega al PDP (bAuth) los atributos de contexto necesarios para evaluar la política.

---

## 4. Mapeo estricto: columnas de T-162 (`idn_roles_template`) → elementos XACML/ABAC

Esta es la definición normativa completa. Cada fila resuelve una ambigüedad encontrada en el diseño original.

### 4.1 Identidad del átomo

| Columna T-162 | Elemento XACML/ABAC | Regla de conformidad |
|---|---|---|
| `id` (uuidv7) | Equivalente interno de `RuleId` | Ya conforme: es estable, único, no editable por negocio. |
| `clave` | **NO debe ser** `Description` de negocio en texto libre | Debe ser un identificador técnico estable — snake_case o slug, sin espacios, sin tildes, no traducible. Ejemplo correcto: `quorum_aprobadores`, no `'quórum de aprobadores'`. |
| `help` | `Description` (XACML) | Rol correcto para el texto de negocio legible por humanos. `'Quórum de aprobadores'`, `'Certificado mTLS presente → x509'`, etc. van acá, no en `clave`. |

**Corrección de A.1 del documento original:** los ejemplos dados (`'quórum de aprobadores'`, `'verbo privilegiado'`, `'certificado mTLS presente → x509'`, `'riesgo bajo'`) son válidos como contenido de `help`/`Description`, **no** como contenido de `clave`/`RuleId`. Si `clave` ya está siendo usada así en producción, es una no-conformidad a corregir antes de considerar el átomo "definido estrictamente según norma".

### 4.2 Efecto del átomo

XACML exige `Effect ∈ {Permit, Deny}` como único vocabulario válido — no hay tercer valor. Tu columna `access BOOLEAN` en `privilege_atom_grant` (`true`/`false`) es una traducción binaria correcta de esto, siempre que la semántica se mantenga estrictamente `true = Permit`, `false = Deny`, sin overloads adicionales (ej. usar `false` para representar "no evaluado" sería una desviación de la norma — para eso XACML tiene el valor `Indeterminate`, que es un resultado de evaluación, no un valor de `Effect`).

### 4.3 Aplicabilidad: Target vs. Condition

Esta es la distinción que más se suele perder al portar XACML a un modelo propio. Se recomienda que el nodo `tipo = 'evaluacion'` (átomo) tenga, explícita y separadamente:

- **Target propio** — qué combinación mínima de subject/resource/action/environment hace que el átomo sea candidato a evaluarse (usado para indexación rápida, no para lógica compleja).
- **Condition propio** — la expresión booleana real que decide el resultado, una vez que el átomo fue considerado candidato por el Target.

Si AtomLang colapsa ambos en una sola expresión sin distinción, se pierde la capacidad de indexar/optimizar evaluación como lo hacen los motores XACML de referencia, y se aleja de conformidad estricta con la especificación.

### 4.4 Obligation vs. Advice — ya resuelto en SBOS-0XX-G04, formalizado acá

Ya se estableció (documento G-04) que `obligation` en T-171 (`privilege_resource_atom`) representa un contrato del recurso (ej. `required_loa: AAL2`), evaluado por Kong como PEP. Esto es estrictamente conforme con XACML: **una obligación no es opcional para el PEP** — si el átomo la trae, Kong está obligado a evaluarla antes de conceder acceso final, exactamente como exige la norma (`ObligationExpressions` deben ejecutarse, `AdviceExpressions` pueden ignorarse).

**Gap identificado en este documento**: AtomLang no distingue hoy entre `Obligation` (vinculante para el PEP) y `Advice` (informativo, ignorable). Se recomienda agregar esa distinción explícita en el schema de T-171 si en algún momento se necesita transmitir información no vinculante hacia Kong (ej. "este átomo fue otorgado bajo excepción temporal" como advice, sin que sea una condición de bloqueo).

```sql
-- Ajuste sugerido a T-171 para separar obligación vinculante de advice informativo
ALTER TABLE bauth.privilege_resource_atom
    ADD COLUMN advice JSONB NULL;

COMMENT ON COLUMN bauth.privilege_resource_atom.obligation IS
    'ObligationExpression XACML — vinculante. El PEP (Kong) DEBE evaluarla y actuar en consecuencia.';
COMMENT ON COLUMN bauth.privilege_resource_atom.advice IS
    'AdviceExpression XACML — informativo. El PEP puede ignorarla con seguridad; no bloquea la decisión.';
```

### 4.5 Atributos ABAC del átomo

Bajo NIST SP 800-162, un átomo evaluado en el PDP necesita poder referenciar atributos de cuatro categorías. Se recomienda que la estructura de `Condition`/`Target` de AtomLang exponga explícitamente a cuál de las cuatro pertenece cada término de la expresión, para trazabilidad de auditoría (un auditor de IAM va a pedir ver, por átomo, qué atributos de qué categoría participaron en la decisión):

| Categoría NIST | Ejemplo en tu dominio |
|---|---|
| Subject | rol del usuario, nivel de LoA/AAL actual, tenant, sucursal |
| Object/Resource | `resource_id` en T-171 (ej. `"tryton.ventas.aprobar"`) |
| Operation/Action | verbo privilegiado (uno de tus ejemplos originales de `clave`) |
| Environment | dispositivo, ubicación, horario, nivel de confianza — tu Context Plane |

### 4.6 Gobernanza del atributo (autoridad de asignación)

NIST SP 800-162 exige que los atributos sean *"predefinidos y pre-asignados por una autoridad"* — no valores libres. En tu arquitectura, esto se traduce en una regla operativa concreta: **ningún átomo (`tipo = 'evaluacion'`) debe poder crearse fuera del flujo gobernado que ya se definió** (nacimiento vía `SEQUENCE` en `idn_roles_template`, documentado en SBOS-0XX-BAUTH-ATOM-GRANT-CONSISTENCY.md). Ese flujo *es* tu mecanismo de "autoridad de asignación" exigido por la norma — vale la pena citarlo explícitamente como tal en la documentación de cumplimiento, porque es lo que un auditor va a buscar como evidencia de que los atributos no se crean de forma ad-hoc.

---

## 5. Checklist de conformidad estricta para un átomo nuevo

Antes de dar un átomo (`tipo = 'evaluacion'`) por completo y conforme a norma, debe cumplir:

- [ ] `clave` es un identificador técnico estable (slug/snake_case), no texto de negocio.
- [ ] `help` contiene la descripción legible de negocio (rol de `Description` XACML).
- [ ] `atom_position` fue asignado vía el mecanismo atómico gobernado (`SEQUENCE`), nunca calculado ad-hoc.
- [ ] El resultado del átomo se expresa estrictamente como `Permit`/`Deny` (mapeado a `access BOOLEAN`), sin overload semántico adicional.
- [ ] Si el átomo tiene lógica de aplicabilidad, distingue explícitamente Target (candidatura rápida) de Condition (evaluación real).
- [ ] Si el átomo impone una obligación sobre un recurso (T-171), queda marcada como `obligation` (vinculante) y no confundida con `advice` (informativa).
- [ ] Los atributos referenciados en la lógica del átomo están categorizados (Subject/Object/Action/Environment) para trazabilidad de auditoría ABAC.
- [ ] El átomo nació exclusivamente a través del flujo gobernado de creación — nunca insertado directo sin pasar por la reserva de `atom_position`.

---

## 6. Fuentes consultadas

- OASIS, *eXtensible Access Control Markup Language (XACML) Version 3.0*, especificación core (OS y working drafts) — docs.oasis-open.org/xacml/3.0/
- WSO2 Identity Server Docs — estructura y sintaxis de política XACML 3.0
- Axiomatics — glosario de referencia de componentes XACML (Rule, Policy, PolicySet, Obligation, Advice)
- NIST, *Special Publication 800-162, Guide to Attribute Based Access Control (ABAC) Definition and Considerations* — csrc.nist.gov/pubs/sp/800/162/upd2/final
- Wikipedia — XACML (estructura PolicySet/Policy/Rule, jerarquía y cambios entre versiones)

---

## 7. Pendiente

- Auditar retroactivamente los átomos ya creados en `idn_roles_template` (`tipo = 'evaluacion'`) para detectar cuántos tienen `clave` con contenido de `Description` en vez de identificador técnico, y planear su migración sin romper referencias existentes en `privilege_atom_grant`.
- Definir el formato exacto del slug de `clave` (charset permitido, longitud máxima, namespace por dominio D0–D13/D98/D99) como constraint `CHECK` en T-162.
- Diseñar cómo AtomLang (`.atm.yaml` compilado por `atomc`) expresa Target y Condition como estructuras separadas, si hoy están colapsadas en una sola expresión.
