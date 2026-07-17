# A.60 — Ciclo de Vida de Átomos, Roles y Asignaciones
## Tipo A+C — Estados, transiciones, herencia DAG, merge de roles y trazabilidad de cambios

**Versión:** 1.0.0
**Fecha:** 2026-07-15
**Tipo de anexo:** A (traslado de SSOT) + C (justificación de decisión técnica)
**Respalda a:** [2.17 Motor de Roles v1.1.0](../2.17_MANUAL-MOTOR-ROLES-v1.0.md) · [1.09 Roles](../1.09_MANUAL-ROLES-v1.0.md) · [1.04 BitMask](../1.04_MANUAL-BITMASK-v1.0.md) · [A.51 Merge de Roles](A.51_ANEXO-MERGE-ROLES-TEMPORAL-v1.0.md)
**Fuentes:** Manual 1.09 §11-§14 · Manual 1.04 §10 · Manual 1.08 §5

---

## §1 Propósito

Documenta los ciclos de vida del ecosistema de roles: estados de un rol, transiciones,
herencia DAG, merge de múltiples roles, y trazabilidad de cambios en asignaciones.

**Cómo citarlo:** `A.60 §N`

---

## §2 Ciclo de vida del rol — 6 estados

Fuente: Manual 1.09 §11.

```
DRAFT ──→ REVIEW ──→ ACTIVE ←──→ SUSPENDED
                       │
                       ▼
                  DEPRECATED ──→ ARCHIVED (irreversible)
```

| Estado | ¿Asignable a usuarios? | ¿BitMask activo? |
|---|---|---|
| DRAFT | No | No |
| REVIEW | No | No |
| ACTIVE | Sí | Sí |
| SUSPENDED | No | bAuth bloquea JWT |
| DEPRECATED | No nuevos | Rechaza nuevas asignaciones |
| ARCHIVED | No | BitMask invalidado |

**Regla absoluta:** ARCHIVED es irreversible. Si se necesita recuperar, crear nuevo rol.

Transiciones clave:
- DRAFT → REVIEW: automático (daemon), requiere `change_reason`
- REVIEW → ACTIVE: aprobador autorizado, requiere `approved_by` + `approved_at`
- ACTIVE → DEPRECATED: SU/role_owner, requiere plan de retiro + rol sucesor
- DEPRECATED → ARCHIVED: solo SU, 0 usuarios activos

---

## §3 Estados del átomo en D95 (Catálogo de Átomos)

Fuente: A.50 §3. El átomo compilado pasa por estados en el catálogo:

| Estado | Significado |
|---|---|
| **ACTIVO** | Pasó compilación (atomc). Asignable a roles. BitMask lo evalúa. |
| **CORROMPIDO** | Falló validación. Será removido en próxima compilación. |
| **DEPRECADO** | Marcado para eliminación. Aún evaluable. |
| **BLOQUEADO** | Conflicto SoD. No evaluable hasta resolver. |

---

## §4 Herencia DAG — closure table

Fuente: Manual 1.09 §9. Herencia OR según ANSI INCITS 359-2012 §3.3.

- **548 roles** en un solo árbol. Raíz: `ROL-SYS-SUPERUSUARIO`.
- **547 aristas directas** (parent_id poblado).
- **1,126 aristas transitivas** (profundidad 2 a 7).
- **1,673 filas totales** en `idn_role_closure`.
- **Profundidad máxima:** 7 niveles.

Distribución por `hierarchy_level`:

| Nivel | Roles | Ejemplos |
|---|---|---|
| 0 | 1 | Raíz |
| 1 | 34 | Directivos, M2M, servicios core |
| 2 | 152 | Mandos altos, jefaturas |
| 3 | 168 | Mandos medios, coordinadores |
| 4 | 144 | Profesionales, analistas |
| 5 | 40 | Operativos calificados |
| 6 | 8 | Operativos base |
| 7 | 1 | Hoja más profunda |

Un usuario con `ROL-GERENTE-GENERAL` hereda automáticamente todos los permisos de sus
roles descendientes. El OR es implícito — `from_positions()` activa todas las posiciones.

---

## §5 Merge de múltiples roles

Fuente: Manual 1.04 §10.1, A.51 §3.

Cuando un usuario tiene múltiples roles activos, el UserBitMask se calcula como el OR
de los RolBitMask de todos sus roles:

```
Cajero:     [1 1 0 1 1 0 1 0]
Supervisor: [1 1 1 1 1 1 1 0]
------------------------------ OR (merge)
Efectiva:   [1 1 1 1 1 0 1 0]
```

El OR nunca inventa bits. Solo activa los que ya existían en algún operando
(test: `test_or_does_not_invent_permissions`, rol.rs:229).

Tres modos de asignación (A.51 §3):

| Modo | Comportamiento | Al expirar |
|---|---|---|
| **PERMANENTE** | Sin fecha de expiración | — |
| **MERGE** | Agrega rol temporal junto con los existentes (OR) | Revoca solo el temporal |
| **REPLACE** | Reemplaza roles existentes por el temporal | Restaura los originales |

---

## §6 Trazabilidad de cambios en átomos

Cada cambio en un átomo o en una asignación se registra en `idn_rolestpl_atom_history`:

| Evento | change_type | Se registra |
|---|---|---|
| atomc compila un átomo | `COMPILE` | old_state (JSONB), new_state (JSONB), source_hash |
| Admin asigna átomo a rol | `ASSIGN` | role_id, atom_code, allowed=true |
| Admin revoca átomo de rol | `REVOKE` | role_id, atom_code, allowed=false |
| Átomo activado en D95 | `ACTIVATE` | atom_code, compiled_by |
| Átomo desactivado de D95 | `DEACTIVATE` | atom_code, motivo |

Tabla append-only, particionada por mes. ISO 27001 A.8.15, PCI DSS 10.3.2.

---

## §7 Mapa anexo → manuales

| Sección | Respalda a |
|---|---|
| §2 (estados del rol) | 1.09 §11 · 2.17 §4 |
| §3 (estados del átomo) | A.50 §3 · 2.17 §4 |
| §4 (herencia DAG) | 1.09 §9 · 1.04 §10 |
| §5 (merge de roles) | 1.04 §10.1 · A.51 §3 |
| §6 (trazabilidad) | A.58 §3 · 2.17 §4.2 |

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-15 | Ciclo de vida del ecosistema de roles: 6 estados del rol, 4 estados del átomo, herencia DAG (1,673 filas, 7 niveles), merge OR, 3 modos de asignación, trazabilidad de cambios. |
