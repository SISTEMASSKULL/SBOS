# A.62 — Rendimiento del Motor de Roles
## Tipo D — Análisis de capacidad y tiempos de respuesta para consultas y operaciones del Motor de Roles

**Versión:** 1.0.0
**Fecha:** 2026-07-15
**Tipo de anexo:** D (verificación de rendimiento)
**Respalda a:** [2.17 Motor de Roles v1.1.0](../2.17_MANUAL-MOTOR-ROLES-v1.0.md) · [A.61 Diseño BD Roles](A.61_ANEXO-DISENO-BD-ROLES-v1.0.md)
**Fuentes:** Manual 1.03 (privilege_atom) · Manual 1.04 (BitMask, RolBitMask, merge)

---

## §1 Escala del Motor de Roles

| Tabla | Filas | Tamaño estimado |
|---|---|---|
| `privilege_atom` | 1,059 actuales (6,000 diseñadas) | ~2 MB |
| `privilege_role_atom` | 548 roles × N átomos. Máximo: 548 × 6,000 = **3,288,000** | ~100 MB |
| `privilege_user_atom` | Excepciones, ~1% de role_atom | ~2 MB |
| `idn_role_template` | 548 | ~5 MB |
| `idn_role_closure` | 1,673 | ~0.1 MB |
| `idn_user_role` | 1,000 usuarios × ~3 roles = 3,000 | ~1 MB |
| `idn_rolestpl_atom_config` | 6,000 × 5 = 30,000 | ~3 MB |
| `idn_rolestpl_atom_history` | ~10,000/año | ~5 MB/año |
| **Total** | **~3.3M filas** | **~120 MB** |

El Motor de Roles es **50 veces más pequeño** que el Motor de Identidad (3.3M vs 165M filas).

---

## §2 Tiempos de consulta

### 2.1 Consulta de átomos de un rol

```sql
SELECT a.atom_slug, ra.allowed
FROM privilege_role_atom ra
JOIN privilege_atom a ON ra.atom_code = a.atom_code
WHERE ra.role_id = 'cajero' AND ra.allowed = true;
```

| Escala | Filas en role_atom | Tiempo |
|---|---|---|
| Actual (548 roles, 1,059 átomos) | ~50 por rol | <0.5ms |
| Completo (548 roles, 6,000 átomos) | ~200 por rol | <1ms |
| Con JOIN a privilege_atom | — | <2ms |

Índice por PK compuesta `(role_id, atom_code)`. Sin full scan.

### 2.2 Cálculo de UserBitMask (merge OR + herencia DAG)

```
PASO 1: Obtener roles activos del usuario
  → 1-3 filas en idn_user_role → <0.5ms

PASO 2: Obtener átomos de cada rol (incluyendo ancestros vía closure table)
  → JOIN privilege_role_atom + idn_role_closure
  → ~500 filas para 3 roles con herencia → <3ms

PASO 3: from_positions() — construir RolBitMask de ~6,000 bits
  → Operación en memoria, sin DB → <0.01ms

TOTAL: <5ms. Se ejecuta UNA VEZ al promover sesión. Se cachea en Redis.
```

### 2.3 Merge de múltiples roles (OR)

```rust
pub fn merge(masks: &[&RolBitMask]) -> Option<RolBitMask>
```

| Operación | Tamaño del vector | Tiempo |
|---|---|---|
| OR de 2 máscaras | 6,000 bits (750 bytes) | <0.001ms |
| OR de 5 máscaras | 6,000 bits | <0.005ms |
| OR de 10 máscaras | 6,000 bits | <0.01ms |

Operación bitwise en memoria. Tiempo despreciable comparado con la consulta SQL.

### 2.4 Asignación/Revocación de átomo a rol

```
bauth.rol.atom.assign(role_id, atom_code)
  → INSERT en privilege_role_atom → <1ms
  → compute_rol_bitmask() → <3ms (incluye herencia DAG)
  → UPDATE idn_role_template.rol_bitmask_base64 → <1ms
  → INSERT en idn_rolestpl_atom_history → <1ms
  TOTAL: <6ms
```

---

## §3 Comparación Motor de Identidad vs Motor de Roles

| | Motor de Identidad | Motor de Roles |
|---|---|---|
| **Filas totales** | 165,000,000 | 3,300,000 |
| **Tamaño BD** | ~68 GB | ~120 MB |
| **Búsqueda más pesada** | Fuzzy sobre 165M filas: <100ms (GIN) | JOIN sobre 3.3M filas: <2ms (B-tree) |
| **Operación más frecuente** | atributo.set() → validate → <5ms | rol.atom.assign() → compute → <6ms |
| **Necesita GIN** | ✅ (fuzzy + full-text) | ❌ (consultas por PK compuesta) |
| **Necesita particionamiento** | ✅ HASH(tenant_id) | ❌ (solo history por mes) |
| **Cache** | Redis para value_normalized | Redis para UserBitMask |

El Motor de Roles es **50× más pequeño, 50× más rápido, y 50× más simple** que el de
Identidad. No necesita índices GIN, columnas generadas, ni particionamiento complejo.
Sus consultas son por clave primaria compuesta. La closure table (1,673 filas) cabe
en memoria.

---

## §4 Mapa anexo → manuales

| Sección | Respalda a |
|---|---|
| §1 (escala) | A.61 §2-§3 |
| §2 (tiempos de consulta) | 2.17 §3-§4 |
| §3 (comparación) | A.57 · 2.15 |

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-15 | Primera edición. Rendimiento del Motor de Roles: 3.3M filas, <6ms por operación, sin necesidad de GIN ni particionamiento. |
