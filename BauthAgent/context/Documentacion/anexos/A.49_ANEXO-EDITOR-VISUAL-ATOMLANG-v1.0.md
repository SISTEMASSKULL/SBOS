# A.49 — Constructor Visual AtomLang
## Tipo A+D — Especificación del editor visual y verificación de implementación

**Versión:** 1.1.0
**Fecha:** 2026-07-14
**Tipo de anexo:** A (traslado de SSOT) + D (verificación de código / estado de implementación)
**Respalda a:** [2.13 MANUAL-ATOMLANG-LENGUAJE §6](../2.13_MANUAL-ATOMLANG-LENGUAJE-v2.0.md) · [1.06 D00 Identidad v2.0](../1.06_MANUAL-D00-IDENTIDAD-v2.0.md) · [2.15 Motor de Identidad](../2.15_MANUAL-MOTOR-IDENTIDAD-v1.0.md)
**Fuentes absorbidas:** `PLAN-CONSTRUCTOR-IDENTIDADES-v1.0.md` · `ATOMLANG-DEFINICION-CANONICA-v2.0.md` §7 · `ATOMLANG-ROLES-USUARIOS-VISION-v1.0.md` §2
**Normas base:** NIST SP 800-162 §4 (PAP) · ISO 27001:2022 A.5.15 (gestión de acceso)

---

## §1 Propósito y cómo citarlo

Este anexo especifica el **constructor visual de AtomLang**: la superficie de autoría donde el
administrador construye el árbol de autorización mediante una paleta de objetos predefinidos,
drag & drop, y formularios de propiedades.

**Cómo citarlo:** `A.49 §N` (ej. "ver zonas de drop: A.49 §3").

**Frontera con el manual:** el manual 2.13 §6 describe qué es el constructor visual. Este
anexo contiene la especificación técnica precisa: paleta de objetos, reglas de drop, tipos
de campos del formulario, y la integración con los catálogos PostgreSQL.

---

## §2 Paleta de objetos

La paleta es el panel izquierdo del dashboard. Contiene los 9 tipos de objetos arrastrables,
agrupados por categoría:

### 2.1 Contenedores

| Objeto | Ícono | Estructura que genera al soltar |
|---|---|---|
| **Dominio** | 🟦 | `Dominio "nuevo_dominio" { combining_algorithm: deny-overrides }` |
| **Bloque** | 🟩 | `Bloque "nuevo_bloque" { }` |
| **PolicySet** | 🟨 | `PolicySet "nuevo_policyset" { combining_algorithm: deny-overrides }` |
| **Política** | 🟧 | `Política "nueva_politica" { combining_algorithm: deny-overrides, application_id: null }` |

### 2.2 Unidad de decisión

| Objeto | Ícono | Estructura que genera al soltar |
|---|---|---|
| **Regla** | 🟥 | `Regla "nueva_regla" { target { subject, resource, verbo }, condition { property_id, operator, value }, effect { decision } }` |

La Regla **siempre** se genera con sus tres hijos (target, condition, effect) ya incluidos.
El administrador no agrega esas partes — solo las completa.

### 2.3 Hojas de datos (dentro de Objetos)

| Objeto | Uso |
|---|---|
| **Atributo** | Clave: valor libre. Para metadatos, configuración. |
| **Lista** | Array de ítems homogéneos. Para members[], available_methods[], etc. |
| **Enumerado** | Clave: valor de conjunto fijo con opciones restringidas. |

---

## §3 Reglas de drop (zonas válidas)

La UI solo habilita la zona de drop cuando el objeto arrastrado es válido en esa posición.
El sistema de validación de drop sigue la gramática del lenguaje (A.46 §2):

| Posición en el árbol | ¿Qué se puede soltar aquí? | ¿Qué NUNCA se puede soltar? |
|---|---|---|
| **Raíz** | Dominio | Cualquier otra cosa |
| **Dentro de Dominio** | Bloque, PolicySet, Política | Regla, Atributo, Verbo |
| **Dentro de Bloque** | Política, PolicySet, Objeto, Lista | Dominio, Regla |
| **Dentro de PolicySet** | PolicySet (anidado), Política | Regla, Dominio |
| **Dentro de Política** | Regla | Dominio, Bloque, PolicySet, otra Política |
| **Dentro de Regla** | Nada (ya tiene target, condition, effect) | — |
| **Dentro de Objeto** | Atributo, Lista, Enumerado | Regla, Política |
| **Dentro de Lista** | Objeto, Atributo | Regla, Política |

---

## §4 Panel de propiedades — tipos de campos

Cuando el administrador selecciona un nodo en el árbol, el panel derecho muestra sus propiedades
editables. Cada campo tiene un tipo que determina el control UI usado:

### 4.1 Campo de texto libre

Para: `clave` (nombre del nodo), `advice`, `help`.

```
┌─────────────────────────────┐
│ Nombre:                      │
│ [venta_aprobacion_tier1    ] │
│ ⚠ snake_case, sin dígitos   │
└─────────────────────────────┘
```

Regla: el valor se valida contra la expresión regular `^[a-z][a-z0-9_]{2,63}$`.
Si contiene dígitos que parecen montos → PAP-W-041.

### 4.2 Desplegable (catálogo cerrado)

Para: `verbo`, `operator`, `decision`, `combining_algorithm`, `subject.kind`, `status`.

```
┌─────────────────────────────┐
│ Verbo:                       │
│ [approve                 ▾ ] │
│   read                       │
│   write                      │
│   create                     │
│   delete                     │
│   approve         ← selec.   │
│   execute                    │
└─────────────────────────────┘
```

Los valores se cargan al iniciar el dashboard vía `bauth.atom.catalog_lookup` contra PostgreSQL.

### 4.3 Búsqueda con autocompletado (catálogo referencial)

Para: `subject.set_id`, `subject.role_id`, `resource`, `condition.property_id`.

```
┌─────────────────────────────┐
│ Conjunto (SET):              │
│ [vend▾                    ] │
│   vendedores                 │
│   vendedores_senior          │
│   gerentes_ventas            │
└─────────────────────────────┘
```

El dashboard consulta PostgreSQL mientras el admin escribe. Si el valor no existe en el
catálogo → no aparece en las opciones. Imposible asignar una referencia inválida.

### 4.4 Selector de constante (para campos AMOUNT/CURRENCY)

Para: `condition.value` cuando `property_id.data_type` es `AMOUNT` o `CURRENCY`.

```
┌─────────────────────────────┐
│ Valor:                       │
│ [@bauth_config_param.ap▾  ] │
│   approval_threshold_tier1   │
│   approval_threshold_tier2   │
│   sod_payment_threshold      │
│   moneda_legal               │
│   (no se permite literal)    │
└─────────────────────────────┘
```

Solo muestra @constantes del tipo correcto. No hay campo de texto libre.

### 4.5 Toggle (booleano)

Para: campos `active`, `is_required`, booleanos en general.

### 4.6 Sub-formulario (objeto anidado)

Para: `target`, `condition`, `effect`, `obligation`. Abre un panel secundario con los campos
hijos del objeto.

---

## §5 Validación post-construcción

El botón "Validar" dispara `atomc validate` sobre el árbol completo. El resultado se muestra
en una barra inferior:

```
┌─────────────────────────────────────────────────────────────┐
│ atomc validate: 3 errores, 2 avisos                         │
│                                                             │
│ ✕ ATOMC-E-005: regla "venta_especial" sin verbo             │
│ ✕ ATOMC-E-042: literal 10000 en campo AMOUNT                │
│ ✕ ATOMC-E-031: política "payment_approvals" sin algorithm   │
│ ⚠ ATOMC-W-041: nombre "venta_10_000_bob" contiene umbral    │
│ ⚠ ATOMC-W-011: condition ausente en regla "pago_global"     │
└─────────────────────────────────────────────────────────────┘
```

Los nodos con errores se marcan en rojo en el árbol. Clic en un error → salta al nodo afectado
y abre el panel de propiedades en el campo problemático.

---

## §6 Las tres vistas del árbol

El dashboard ofrece tres vistas filtradas sobre el mismo árbol (detalle completo en A.50 §2):

| Vista | Filtro | Uso |
|---|---|---|
| **General** | Sin filtro — árbol completo | Arquitecto de seguridad. Definir políticas y reglas. |
| **Rol** | `Target.Subject SET(conjunto)` | Arquitecto de identidad. Ver qué átomos recibe un rol. |
| **Usuario** | Rol + atributos personales + excepciones | Admin / RRHH. Inscribir usuario, agregar overrides. |

El filtro se aplica recorriendo el árbol: una Regla es visible si `Target.Subject` coincide
con el rol filtrado. Las reglas con `subject: ANY` siempre son visibles. Las ramas sin reglas
visibles se colapsan.

---

## §7 Integración con catálogos PostgreSQL

Todos los desplegables y búsquedas se resuelven contra la base de datos en tiempo real:

| Campo | Consulta | Endpoint JSON-RPC |
|---|---|---|
| verbo | `SELECT verb_slug FROM bauth.privilege_verb ORDER BY verb_slug` | `bauth.atom.catalog_lookup` |
| subject.set_id | `SELECT set_slug FROM bauth.privilege_role_set` | `bauth.atom.catalog_lookup` |
| subject.role_id | `SELECT rol_slug FROM bauth.idn_role_template WHERE status = 'ACTIVE'` | `bauth.atom.catalog_lookup` |
| resource | `SELECT resource_slug FROM bauth.privilege_resource` | `bauth.atom.catalog_lookup` |
| property_id | `SELECT attr_slug, data_type FROM bauth.privilege_attribute` | `bauth.atom.catalog_lookup` |
| @constantes | `SELECT param_key, data_type FROM bauth.bauth_config_param WHERE is_active = true` | `bauth.atom.catalog_lookup` |

Los catálogos se cachean en el dashboard (TTL 60s) para no saturar la BD en cada pulsación.

---

## §8 Estado de implementación

| Componente | Estado |
|---|---|
| Widget `ArbolTemplate` (visualización de árbol) | ✅ Implementado en Flutter |
| Panel de propiedades (lectura) | ✅ Implementado |
| Menú contextual en nodos enumerados | ✅ Implementado |
| Paleta de objetos arrastrables | ❌ No implementado |
| Drag & drop con zonas válidas | ❌ No implementado |
| Integración con catálogos PostgreSQL vía JSON-RPC | ❌ No implementado (árbol hardcodeado en Dart) |
| Validación post-construcción (atomc validate) | ❌ Pendiente (atomc L0 → L1) |
| Filtro por Rol / Usuario | ❌ No implementado |

---

## §9 Mapa anexo → manuales

| Sección | Respalda a | Qué sección |
|---|---|---|
| §2 (paleta de objetos) | 2.13 §6.1 | Estructura de cada objeto |
| §3 (reglas de drop) | 2.13 §6.2 | La UI impide errores |
| §4 (tipos de campos) | 2.13 §6.1 | Cómo se completan valores |
| §5 (validación) | 2.13 §6.3 | Post-construcción |
| §6 (tres vistas) | 2.13 §7 | Modelo simplificado |
| §7 (catálogos) | 2.13 §5.2 | Vocabularios cerrados |

---

## Referencias

- [2.13 Manual AtomLang v2.0](../2.13_MANUAL-ATOMLANG-LENGUAJE-v2.0.md) §6 — Constructor visual
- [A.46 Gramática y compilador](A.46_ANEXO-ATOMLANG-GRAMATICA-COMPILADOR-v2.0.md) — Reglas G-01..G-10
- [A.50 Modelo simplificado](A.50_ANEXO-MODELO-SIMPLIFICADO-ROLES-USUARIOS-v1.0.md) — Tres vistas
- NIST SP 800-162 §4 — PAP (Policy Administration Point)

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-14 | Primera edición. Especifica el constructor visual: paleta de 9 objetos, reglas de drop por tipo de nodo, 6 tipos de campo en el panel de propiedades (texto, desplegable, búsqueda, constante, toggle, sub-formulario), validación post-construcción con atomc validate, tres vistas (General/Rol/Usuario), integración con 6 catálogos PostgreSQL vía JSON-RPC. |


---

## §10 — v1.1.0: Paleta de Identidades (2026-07-14)

Además de la paleta de políticas (Dominio, Bloque, PolicySet, Política, Regla), el dashboard
incluye una **paleta de Identidades** para construir entidades en el árbol D00:

| Objeto | Nivel | Tipos (desplegable) | Se suelta en |
|---|---|---|---|
| 🏢 **Tenant** | tenant | interno, externo | Raíz |
| 📁 **bDomain** | bdomain | empresa, persona, hogar, desarrollador, m2m, edificio, almacen, catalogo, finca, hospital, hotel, universidad, datacenter, centro_distribucion, obra | Tenant |
| 📁 **bSubDomain** | bsubdomain | sucursal, dependiente, familiar, oficina, deposito, patio, sala, categoria, parcela, piso, zona, aula, habitacion, facultad | bDomain |
| 📍 **Pos** | pos | caja, terminal, puerta, sensor, actuador, punto_virtual, estante, camara, rack, estacionamiento, rubro, muelle | bSubDomain |
| 👤 **Actor** | actor | HUMAN, SERVICE, DEVICE, BOT, producto, equipo, vehiculo, servidor, storage, switch, firewall, marca, paciente, alumno, huesped, cultivo, maquina, paquete, contenedor | Pos |
| 🏷️ **Atributo** | — | category + attr_key + type + valor | Cualquier entidad |
| 🔗 **Asignar Rol** | — | selector de roles existentes | Actor |

Los tipos válidos por nivel son gobernados por D93. El motor de identidad valida cada
atributo antes de persistir.
