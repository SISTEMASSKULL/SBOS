# AtomLang — Grupos y Atributos por Nodo (borrador para revisión)

Documento de trabajo. El usuario corrige y con esa versión se actualiza `widget_roles.dart`.

Fuente: `ATOMLANG-ESTRUCTURA-JERARQUICA.md` + `A.46 §2`.

**Regla:** nodo con hijos → **[GRUPO]** · nodo hoja sin hijos → **[ATRIBUTO]**

En el widget: [GRUPO] = `_GrupoAtributos` (encabezado) · [ATRIBUTO] = `_CampoFila` (campo)

---

## tenant

Nodo raíz. Sin atributos propios — solo atributos comunes.

---

## domain

Todos sus hijos son hojas → solo ATRIBUTOs, ningún GRUPO interno.

| Tipo | Nombre | Descripción |
|------|--------|-------------|
| [ATRIBUTO] | id | Código del dominio (D00–D15, D98, D99) |
| [ATRIBUTO] | nombre | Nombre descriptivo |
| [ATRIBUTO] | owner | Equipo/rol responsable (governance) |
| [ATRIBUTO] | classification | Sensibilidad general (financiero · PII · crítico) |
| [ATRIBUTO] | version | Versión del dominio |
| [ATRIBUTO] | policy_set_ref | FK al PolicySet raíz del dominio |

---

## block

Todos sus hijos son hojas → solo ATRIBUTOs, ningún GRUPO interno.

| Tipo | Nombre | Descripción |
|------|--------|-------------|
| [ATRIBUTO] | id | Identificador del bloque |
| [ATRIBUTO] | domain_ref | FK al dominio padre |
| [ATRIBUTO] | resource_type | Tipo de recurso agrupado |
| [ATRIBUTO] | policy_ref | FK a la Policy/PolicySet que lo representa |

---

## policy_set

Tiene hojas directas + el GRUPO `target` (que a su vez contiene el GRUPO `subject`).

**Hojas directas de policy_set → ATRIBUTOs:**

| Tipo | Nombre | Descripción |
|------|--------|-------------|
| [ATRIBUTO] | id | Identificador |
| [ATRIBUTO] | combining_algorithm | deny-overrides \| permit-overrides \| first-applicable \| deny-unless-permit \| permit-unless-deny \| aggregate-strictest |
| [ATRIBUTO] | status | draft \| active \| deprecated |
| [ATRIBUTO] | version | Versión semántica |
| [ATRIBUTO] | policy_issuer | Quién autorizó/firmó |

**[GRUPO] target** — heredable por los hijos, NO evaluable en este nivel:

| Tipo | Nombre | Descripción |
|------|--------|-------------|
| **[GRUPO]** | **subject** | Tiene hijos → es GRUPO |
| [ATRIBUTO] | subject.set | Roles/sets INCLUIDOS |
| [ATRIBUTO] | subject.unset | Roles/sets EXCLUIDOS |
| [ATRIBUTO] | subject.userset | Usuarios específicos INCLUIDOS |
| [ATRIBUTO] | subject.userunset | Usuarios específicos EXCLUIDOS |
| [ATRIBUTO] | resource | Recurso (hoja directa de target) |
| [ATRIBUTO] | action | Acción/verbo (hoja directa de target) |
| [ATRIBUTO] | environment | Contexto ambiental (hoja directa de target) |

---

## policy

Misma estructura que policy_set más el campo `type`.

**Hojas directas de policy → ATRIBUTOs:**

| Tipo | Nombre | Descripción |
|------|--------|-------------|
| [ATRIBUTO] | id | Identificador |
| [ATRIBUTO] | type | PolicySet \| Policy |
| [ATRIBUTO] | combining_algorithm | deny-overrides \| permit-overrides \| first-applicable \| deny-unless-permit \| permit-unless-deny \| aggregate-strictest |
| [ATRIBUTO] | status | draft \| active \| deprecated |
| [ATRIBUTO] | version | Versión semántica |
| [ATRIBUTO] | policy_issuer | Quién autorizó/firmó |

**[GRUPO] target** — heredable por los hijos, NO evaluable en este nivel:

| Tipo | Nombre | Descripción |
|------|--------|-------------|
| **[GRUPO]** | **subject** | Tiene hijos → es GRUPO |
| [ATRIBUTO] | subject.set | Roles/sets INCLUIDOS |
| [ATRIBUTO] | subject.unset | Roles/sets EXCLUIDOS |
| [ATRIBUTO] | subject.userset | Usuarios específicos INCLUIDOS |
| [ATRIBUTO] | subject.userunset | Usuarios específicos EXCLUIDOS |
| [ATRIBUTO] | resource | Recurso (hoja directa de target) |
| [ATRIBUTO] | action | Acción/verbo (hoja directa de target) |
| [ATRIBUTO] | environment | Contexto ambiental (hoja directa de target) |

---

## rule

Tiene hojas directas + el GRUPO `target` (con sub-GRUPO `subject`).

**Hojas directas de rule → ATRIBUTOs:**

| Tipo | Nombre | Descripción |
|------|--------|-------------|
| [ATRIBUTO] | id | Identificador |
| [ATRIBUTO] | policy_ref | FK a la Policy padre |
| [ATRIBUTO] | description | Semántica de negocio en lenguaje natural |
| [ATRIBUTO] | rule_combining_algorithm | Solo si tiene >1 Atom hijo |

**[GRUPO] target** — refina el heredado de la Policy, NO evaluable en este nivel:

| Tipo | Nombre | Descripción |
|------|--------|-------------|
| **[GRUPO]** | **subject** | Tiene hijos → es GRUPO (override opcional) |
| [ATRIBUTO] | subject.set | Roles/sets INCLUIDOS (override) |
| [ATRIBUTO] | subject.unset | Roles/sets EXCLUIDOS (override) |
| [ATRIBUTO] | subject.userset | Usuarios INCLUIDOS (override) |
| [ATRIBUTO] | subject.userunset | Usuarios EXCLUIDOS (override) |
| [ATRIBUTO] | resource | Override opcional (hoja directa de target) |
| [ATRIBUTO] | action | Override opcional (hoja directa de target) |
| [ATRIBUTO] | environment | Override opcional (hoja directa de target) |

---

## atom

**[GRUPO] identidad** — tiene hijos → GRUPO:

| Tipo | Nombre | Descripción |
|------|--------|-------------|
| [ATRIBUTO] | id | Identificador único (dNN.bloque.verbo) |
| [ATRIBUTO] | domain | Código de dominio |
| [ATRIBUTO] | bloque | Subdivisión funcional |
| [ATRIBUTO] | verbo | Acción autorizada |
| [ATRIBUTO] | depends_on | Árbol de dependencias (átomos padre) |
| [ATRIBUTO] | version | Versión semántica del átomo |

**[GRUPO] TARGET** — evaluable ✅ fase 1: ¿aplica esta regla? — tiene hijos → GRUPO:

| Tipo | Nombre | Descripción |
|------|--------|-------------|
| **[GRUPO]** | **subject** | Tiene hijos → es GRUPO |
| [ATRIBUTO] | subject.set | Roles/sets INCLUIDOS |
| [ATRIBUTO] | subject.unset | Roles/sets EXCLUIDOS |
| [ATRIBUTO] | subject.userset | Usuarios específicos INCLUIDOS |
| [ATRIBUTO] | subject.userunset | Usuarios específicos EXCLUIDOS |
| [ATRIBUTO] | resource | Recurso sobre el que opera (hoja directa de TARGET) |
| [ATRIBUTO] | action | Acción — mapea al verbo (hoja directa de TARGET) |
| [ATRIBUTO] | environment | Contexto ambiental: device/location/schedule/trust (hoja directa) |

**CONDITION** — hoja directa del atom → ATRIBUTO:

| Tipo | Nombre | Descripción |
|------|--------|-------------|
| [ATRIBUTO] | condition | Expresión booleana en runtime · null si no aplica |

**[GRUPO] EFFECT** — tiene hijos (obligation/advice + WORM) → GRUPO:

| Tipo | Nombre | Descripción |
|------|--------|-------------|
| [ATRIBUTO] | effect | PERMIT \| DENY — discriminante evaluado |

**[GRUPO] obligation/advice** — tiene hijos → GRUPO (REACTIVO CONDICIONAL):

| Tipo | Nombre | Descripción |
|------|--------|-------------|
| [ATRIBUTO] | fulfill_on | PERMIT \| DENY — gate de disparo |
| [ATRIBUTO] | obligation | Proceso vinculante si EFFECT == fulfill_on |
| [ATRIBUTO] | advice | Sugerencia al PEP, no vinculante |

**[GRUPO] auditoría WORM** — tiene hijos → GRUPO (REACTIVO INCONDICIONAL):

| Tipo | Nombre | Descripción |
|------|--------|-------------|
| [ATRIBUTO] | created_at / created_by | Metadatos de creación (WORM) |
| [ATRIBUTO] | checksum / hash | Integridad SHA-256 |
| [ATRIBUTO] | cdc_source | Referencia WAL (LSN) |

**[GRUPO] encoding físico** — tiene hijos → GRUPO (ESTRUCTURAL):

| Tipo | Nombre | Descripción |
|------|--------|-------------|
| [ATRIBUTO] | bit_position | Posición en el BitMask de 64 bits |
| [ATRIBUTO] | role_mask | One-hot encoding del rol (N-bit) |

---

## object / list / event

Sin atributos propios. Solo atributos comunes.

---

## attribute

| Tipo | Nombre | Descripción |
|------|--------|-------------|
| [ATRIBUTO] | value | text · valor del atributo |

---

## enum

| Tipo | Nombre | Descripción |
|------|--------|-------------|
| [ATRIBUTO] | value | text · valor actualmente seleccionado |
| [ATRIBUTO] | options | text[] · conjunto de valores permitidos |

---

## Atributos comunes — todos los nodos (tab "Atrib. comunes")

**[GRUPO] Identidad:**
id · tenant_id · parent_id · node_type

**[GRUPO] Nombre:**
label · name · alias · description · help

**[GRUPO] Posición:**
depth · path · sort_order · order_idx

**[GRUPO] Ciclo de vida:**
is_active · version · valid_from · valid_until · created_at · updated_at
