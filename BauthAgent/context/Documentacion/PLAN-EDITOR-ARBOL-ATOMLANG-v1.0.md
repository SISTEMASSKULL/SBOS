# Plan — Editor de Árbol AtomLang (Desktop)
## Arquitectura data-driven para el widget de grupos y atributos

**Versión:** 1.1.0
**Fecha:** 2026-08-07
**Estado:** DDL creado — pendiente implementación Rust + Flutter
**Depende de:** 2.13 AtomLang · 2.14 Árbol · A.46 §2 EBNF · ATOMLANG-ESTRUCTURA-JERARQUICA.md · A.79

---

## 1. Problema actual

El widget `widget_roles.dart` tiene un `switch (node_type) { 'atom' => [...], 'policy' => [...] }`
hardcodeado en Dart. Cada grupo y cada atributo están literalmente escritos en el código del cliente.

Esto es monolítico, estático e incorrecto por las mismas razones que en el motor de identidad
sería incorrecto hacer `switch (tipo) { 'empresa' => [NIT, razon_social...], 'vehiculo' => [placa, marca...] }`:

- Cualquier cambio en la gramática AtomLang requiere recompilar el cliente
- El cliente conoce la estructura interna del daemon → acoplamiento incorrecto
- No hay validación real — el daemon no sabe qué mandó el cliente
- Imposible extender sin tocar Flutter

---

## 2. Solución — patrón análogo al motor de identidad

| Identidad (existente) | Árbol AtomLang (a construir) |
|---|---|
| `idn_identity_entity` — árbol de entidades | `idn_roles_template` — árbol de nodos |
| `idn_identity_attribute` — EAV de atributos | Atributos del nodo (JSONB en `data`) |
| D93 — catálogo de tipos válidos + atributos requeridos | **Catálogo de esquema** — tipos de nodo + grupos + atributos |
| Motor de identidad — valida con AtomLang | `atomc` — compila y valida el árbol |
| `bauth.identidad.*` — API CRUD del cliente | `bauth.rol_template.*` — API CRUD del cliente |
| El desktop nunca toca la BD | El desktop nunca toca la BD |

**Regla:** el daemon es la única fuente de verdad del esquema. El cliente (Flutter) no sabe nada
de la estructura interna — la consulta al daemon y renderiza lo que recibe.

---

## 3. Componentes del sistema

### 3.1 Catálogo de esquema (BD — configurable por CRUD)

**DECISIÓN H-01 RESUELTA: el catálogo vive en la base de datos, no en Rust estático.**

Dos tablas en `SBOS_db`:
- `T-580 bauth.pol_atomlang_node_schema` — jerarquía de grupos por `node_type` (auto-referencial, análogo a `idn_identity_entity`)
- `T-581 bauth.pol_atomlang_attr_schema` — atributos (hojas) de cada grupo (análogo a `idn_identity_attribute`)
- `T-582 bauth.pol_atomlang_schema_history` — historial WORM de cambios

DDL: `DDLs/bauth_atomlang_schema.sql`
Seeds: `DDLs/seeds/bauth_T580__pol_atomlang_node_schema.sql` + `bauth_T581__pol_atomlang_attr_schema.sql`

Si los estándares cambian (nueva norma exige un nuevo campo), el admin lo agrega
desde la UI de CRUD del desktop — sin recompilar el daemon. El daemon lee el esquema
desde BD en cada arranque (cacheado en Redis con invalidación por canal pub/sub).

```
Catálogo:
  node_type: "atom"
    grupos:
      - id: "identidad"
        label: {es: "Identidad", en: "Identity"}
        atributos:
          - key: "id"            tipo: uuid     readonly: true
          - key: "domain"        tipo: text     readonly: false
          - key: "bloque"        tipo: text     readonly: false
          - key: "verbo"         tipo: text     readonly: false
          - key: "depends_on"    tipo: text[]   readonly: false
          - key: "version"       tipo: semver   readonly: false
      - id: "TARGET"
        grupos_hijos:            ← subject es GRUPO dentro de TARGET
          - id: "subject"
            atributos:
              - key: "set"       tipo: slug[]
              - key: "unset"     tipo: slug[]
              - key: "userset"   tipo: slug[]
              - key: "userunset" tipo: slug[]
        atributos_propios:       ← hojas directas de TARGET
          - key: "resource"      tipo: slug
          - key: "action"        tipo: slug
          - key: "environment"   tipo: text
      - id: "CONDITION"
        atributos:
          - key: "condition"     tipo: expression  nullable: true
      - id: "EFFECT"
        grupos_hijos:
          - id: "obligation_advice"
            atributos:
              - key: "fulfill_on"   tipo: enum[PERMIT,DENY]
              - key: "obligation"   tipo: text
              - key: "advice"       tipo: text
          - id: "worm"
            readonly: true
            atributos:
              - key: "created_at"  tipo: timestamptz  readonly: true
              - key: "created_by"  tipo: uuid          readonly: true
              - key: "checksum"    tipo: text          readonly: true
        atributos_propios:
          - key: "effect"        tipo: enum[PERMIT,DENY]
      - id: "encoding_fisico"
        readonly: true
        atributos:
          - key: "bit_position"  tipo: bigint   readonly: true
          - key: "role_mask"     tipo: bigint   readonly: true
```

### 3.2 API JSON-RPC — métodos de esquema

Expuestos en el namespace `bauth.rol_template.schema.*`:

```
bauth.rol_template.schema.node_types()
  → Lista todos los node_type válidos con su label e ícono

bauth.rol_template.schema.node_type(type: string)
  → Para un node_type dado, retorna su árbol de grupos y atributos
  → El cliente usa esta respuesta para renderizar el panel

bauth.rol_template.schema.validate(node_id, attrs: map)
  → El daemon valida los valores contra el esquema y la gramática AtomLang
  → Retorna lista de errores por campo (field_key → error_msg)
```

### 3.3 API JSON-RPC — métodos de datos

```
bauth.rol_template.node.get(node_id)
  → Retorna el nodo con todos sus atributos actuales

bauth.rol_template.node.set_attr(node_id, group, key, value)
  → El daemon persiste el atributo validando contra el esquema
  → Retorna ok o error de validación

bauth.rol_template.node.create(parent_id, node_type, attrs)
bauth.rol_template.node.delete(node_id)
bauth.rol_template.node.move(node_id, new_parent_id)

bauth.rol_template.tree.get(tenant_id)
  → Árbol completo (para el Bloque A del widget)
```

### 3.4 Widget Flutter — lectura dinámica del esquema

El widget ya no tiene switch hardcodeado. En su lugar:

```
Al seleccionar un nodo en el árbol (Bloque A):
  1. Llama bauth.rol_template.node.get(node_id)
     → Obtiene los valores actuales del nodo

  2. Llama bauth.rol_template.schema.node_type(node.node_type)
     → Obtiene la estructura de grupos y atributos

  3. Renderiza _GrupoAtributos por cada grupo del esquema
     → Dentro de cada grupo, _CampoFila por cada atributo
     → Valor actual = lo que retornó node.get()
     → Readonly/editable = lo que dice el esquema

Al editar un campo:
  1. Llama bauth.rol_template.node.set_attr(node_id, group, key, value)
  2. El daemon valida → retorna ok o {field: error}
  3. El widget muestra el error inline en el _CampoFila correspondiente
```

---

## 4. Estructura de datos — respuesta del esquema

La respuesta de `bauth.rol_template.schema.node_type("atom")` en JSON-RPC 2.0:

```json
{
  "node_type": "atom",
  "label": {"es": "Átomo", "en": "Atom"},
  "grupos": [
    {
      "id": "identidad",
      "label": {"es": "Identidad"},
      "readonly": false,
      "atributos": [
        { "key": "id",         "label": {"es": "ID"},          "tipo": "uuid",   "readonly": true  },
        { "key": "domain",     "label": {"es": "Dominio"},     "tipo": "text",   "readonly": false },
        { "key": "bloque",     "label": {"es": "Bloque"},      "tipo": "text",   "readonly": false },
        { "key": "verbo",      "label": {"es": "Verbo"},       "tipo": "slug",   "readonly": false },
        { "key": "depends_on", "label": {"es": "Depende de"},  "tipo": "text[]", "readonly": false },
        { "key": "version",    "label": {"es": "Versión"},     "tipo": "semver", "readonly": false }
      ],
      "subgrupos": []
    },
    {
      "id": "TARGET",
      "label": {"es": "Target"},
      "readonly": false,
      "atributos": [
        { "key": "resource",    "label": {"es": "Recurso"},    "tipo": "slug", "readonly": false },
        { "key": "action",      "label": {"es": "Acción"},     "tipo": "slug", "readonly": false },
        { "key": "environment", "label": {"es": "Entorno"},    "tipo": "text", "readonly": false }
      ],
      "subgrupos": [
        {
          "id": "subject",
          "label": {"es": "Subject"},
          "atributos": [
            { "key": "set",       "label": {"es": "Set (incluidos)"},  "tipo": "slug[]" },
            { "key": "unset",     "label": {"es": "Unset (excluidos)"},"tipo": "slug[]" },
            { "key": "userset",   "label": {"es": "Userset"},          "tipo": "slug[]" },
            { "key": "userunset", "label": {"es": "Userunset"},        "tipo": "slug[]" }
          ]
        }
      ]
    },
    {
      "id": "CONDITION",
      "label": {"es": "Condition"},
      "atributos": [
        { "key": "condition", "label": {"es": "Expresión"}, "tipo": "expression", "nullable": true }
      ],
      "subgrupos": []
    },
    {
      "id": "EFFECT",
      "label": {"es": "Effect"},
      "atributos": [
        { "key": "effect", "label": {"es": "Decisión"}, "tipo": "enum", "valores": ["PERMIT","DENY"] }
      ],
      "subgrupos": [
        {
          "id": "obligation_advice",
          "label": {"es": "Obligation / Advice"},
          "atributos": [
            { "key": "fulfill_on",  "label": {"es": "Disparar en"}, "tipo": "enum", "valores": ["PERMIT","DENY"] },
            { "key": "obligation",  "label": {"es": "Obligation"},  "tipo": "text" },
            { "key": "advice",      "label": {"es": "Advice"},      "tipo": "text" }
          ]
        },
        {
          "id": "worm",
          "label": {"es": "Auditoría WORM"},
          "readonly": true,
          "atributos": [
            { "key": "created_at", "label": {"es": "Creado en"}, "tipo": "timestamptz", "readonly": true },
            { "key": "created_by", "label": {"es": "Creado por"},"tipo": "uuid",        "readonly": true },
            { "key": "checksum",   "label": {"es": "Checksum"},  "tipo": "text",        "readonly": true }
          ]
        }
      ]
    },
    {
      "id": "encoding_fisico",
      "label": {"es": "Encoding físico"},
      "readonly": true,
      "atributos": [
        { "key": "bit_position", "label": {"es": "Bit position"}, "tipo": "bigint", "readonly": true },
        { "key": "role_mask",    "label": {"es": "Role mask"},    "tipo": "bigint", "readonly": true }
      ],
      "subgrupos": []
    }
  ]
}
```

---

## 5. Cambios requeridos en el widget Flutter

### 5.1 Modelo de datos (nuevo)

```dart
// Descripción de un atributo según el esquema del daemon
class AttrSchema {
  final String key;
  final Map<String, String> label;   // {es: ..., en: ...}
  final String tipo;                 // uuid | text | slug | slug[] | enum | expression
  final bool readonly;
  final bool nullable;
  final List<String> valores;        // si tipo==enum
}

// Descripción de un grupo (puede tener subgrupos)
class GrupoSchema {
  final String id;
  final Map<String, String> label;
  final bool readonly;
  final List<AttrSchema> atributos;
  final List<GrupoSchema> subgrupos;
}

// Esquema completo de un node_type
class NodeTypeSchema {
  final String nodeType;
  final Map<String, String> label;
  final List<GrupoSchema> grupos;
}
```

### 5.2 Provider (nuevo)

```dart
// Notifier que carga el esquema del daemon por node_type
class EsquemaNodeNotifier extends AsyncNotifier<NodeTypeSchema?> {
  Future<NodeTypeSchema?> cargar(String nodeType);
}

// Notifier que carga los valores actuales de un nodo
class ValoresNodeNotifier extends AsyncNotifier<Map<String, dynamic>> {
  Future<void> cargar(String nodeId);
  Future<void> setAttr(String nodeId, String group, String key, dynamic value);
}
```

### 5.3 Widget — renderizado dinámico

```dart
// _AtributosGrupo ya no llama _gruposPorTipo hardcodeado
// En su lugar, observa EsquemaNodeNotifier y renderiza los grupos

Widget build(BuildContext context) {
  final esquema = ref.watch(esquemaNodeProvider(tipo));
  return esquema.when(
    loading: () => ...,
    error:   (e, _) => ...,
    data:    (schema) => _renderGrupos(schema.grupos, valores),
  );
}

Widget _renderGrupos(List<GrupoSchema> grupos, Map valores) {
  return Column(
    children: [
      for (final grupo in grupos) ...[
        _GrupoAtributos(
          titulo: grupo.label['es']!,
          readonly: grupo.readonly,
          campos: [
            for (final attr in grupo.atributos)
              _CampoFila(
                campo: attr.key,
                descripcion: attr.label['es']!,
                tipo: attr.tipo,
                valor: valores[attr.key],
                soloLectura: attr.readonly,
              ),
          ],
          subgrupos: [
            for (final sub in grupo.subgrupos)
              _GrupoAtributos(titulo: sub.label['es']!, ...),
          ],
        ),
      ],
    ],
  );
}
```

---

## 6. Decisiones HITL pendientes

| ID | Decisión | Opciones |
|----|----------|---------|
| H-01 | ~~¿El catálogo de esquema vive en Rust (estático) o en BD (configurable)?~~ | **RESUELTO: BD** — T-580/T-581/T-582 en `bauth_atomlang_schema.sql`. Seeds cargados. |
| H-02 | ¿Los subgrupos se renderizan anidados visualmente o como grupos planos con prefijo en el título (ej. "Target — Subject")? | A) Anidado → refleja el árbol real · B) Plano con prefijo → más simple de implementar |
| H-03 | ¿El campo `condition` (expresión booleana libre) se edita como texto libre o con un constructor visual? | A) Texto libre (fase 1) · B) Constructor por campos (fase 2) |
| H-04 | ¿Los atributos `slug[]` (set, unset, userset, userunset) se editan como texto separado por comas o como chips con autocompletado contra el catálogo del daemon? | A) Texto plano (fase 1) · B) Chips con autocompletado (fase 2) |
| H-05 | ¿Los campos WORM (auditoría) se muestran en el tab "Atrib. grupo" o solo en "Atrib. comunes"? | A) Solo en comunes · B) En grupo como sección colapsada readonly |

---

## 7. Plan de implementación — fases

### Fase 1 — ✅ DDL BD + seeds (COMPLETADO 2026-08-07)

1. ~~Definir catálogo en Rust~~ → **REEMPLAZADO: T-580/T-581/T-582 en BD**
2. DDL: `DDLs/bauth_atomlang_schema.sql` — creado
3. Seeds T-580: `DDLs/seeds/bauth_T580__pol_atomlang_node_schema.sql` — creado
4. Seeds T-581: `DDLs/seeds/bauth_T581__pol_atomlang_attr_schema.sql` — creado
5. **PENDIENTE:** Implementar `bauth.atomlang.schema.node_types()` y `bauth.atomlang.schema.node_type(type)` en Rust (`src/server/jsonrpc.rs` + `src/catalog/`)
6. **PENDIENTE:** Reemplazar `_gruposPorTipo` en Flutter por lectura dinámica del API

### Fase 2 — API de datos + edición real

5. Implementar `bauth.rol_template.node.get(node_id)` y `bauth.rol_template.node.set_attr(...)`
6. Conectar `_CampoFila` con edición real vía JSON-RPC
7. Mostrar errores de validación inline

### Fase 3 — Validación completa

8. Implementar `bauth.rol_template.schema.validate(node_id, attrs)`
9. El widget valida antes de guardar y muestra errores por campo
10. Integrar con `atomc` para validación semántica completa

---

## 8. Qué NO cambia

- La estructura visual del widget (Bloque A árbol + splitter + Bloque B tabs) — ya correcta
- `_AtributosComunes` — los atributos comunes a todos los nodos siguen hardcodeados
  porque son atributos de `idn_roles_template` (la tabla), no de la gramática AtomLang
- `_GrupoAtributos` y `_CampoFila` como componentes base — solo cambia quién los construye
- `PanelLateral` con `bodyFlex` + `bottom` — arquitectura del panel ya correcta
