# A.51 — Merge de Roles y Asignación Temporal
## Tipo B+C+A — Fundamento normativo, diseño técnico y especificación de la fusión de roles y asignaciones temporales

**Versión:** 1.0.0
**Fecha:** 2026-07-14
**Tipo de anexo:** B (normativo/industria) + C (justificación técnica) + A (SSOT del diseño propuesto)
**Respalda a:** [2.13 MANUAL-ATOMLANG-LENGUAJE v2.0 §7](../2.13_MANUAL-ATOMLANG-LENGUAJE-v2.0.md) — el modelo simplificado · [A.50 — Modelo Simplificado](A.50_ANEXO-MODELO-SIMPLIFICADO-ROLES-USUARIOS-v1.0.md) §2 — pipeline de 5 pasos
**Fuentes consultadas:** Microsoft Dynamics 365 (Temporary Role Management) · GTRBAC (Generalized Temporal RBAC) · ANSI INCITS 359-2004 §4.2 (DSD) · NIST SP 800-53 AC-5 (SoD)
**Normas base:** ANSI INCITS 359-2004 (RBAC — Dynamic Separation of Duty) · NIST SP 800-53 AC-5 (Separation of Duties) · NIST SP 800-162 §4 (ABAC) · ISO 27001:2022 A.5.15 (access control)
**Código existente:** `src/domain/merge.rs` (MergeRoles) · `src/bitmask/rol.rs` (RolBitMask::merge) · `src/server/handlers/merge_templates.rs` · `src/domain/delegation.rs` (D10, reducción AND) · `idn_user_role` (asignación con `valid_from`/`valid_until`)

---

## §1 Propósito y cómo citarlo

Este anexo define el modelo de **fusión de roles** en AtomLang: cómo un usuario puede tener
múltiples roles asignados simultáneamente, cómo se combinan sus permisos (merge de BitMasks
vía OR), y cómo funcionan las asignaciones temporales (reemplazo por vacaciones, suplencia,
delegación con reducción AND).

**Cómo citarlo:** `A.51 §N` (ej. "ver modos de fusión: A.51 §3").

**Frontera con A.50:** el anexo A.50 define el pipeline simplificado de 5 pasos (definir →
compilar → asignar → inscribir → evaluar). Este anexo extiende el **Paso 4 (inscribir)**
con asignaciones temporales y fusión de múltiples roles.

---

## §2 Fundamento: por qué existe el merge de roles

### 2.1 La necesidad de negocio

En cualquier organización real, los usuarios no tienen un solo rol de por vida:

| Escenario | Qué implica |
|---|---|
| **Vacaciones** | El empleado A se ausenta 15 días. El empleado B necesita sus permisos temporalmente. Al regresar A, B pierde esos permisos. |
| **Reemplazo por enfermedad** | Similar a vacaciones pero con inicio imprevisto. |
| **Acumulación de responsabilidades** | Un empleado es promovido y mantiene temporalmente su rol anterior durante la transición. |
| **Cobertura de guardia** | Un operador de guardia necesita permisos elevados solo durante su turno (D4 — temporal). |
| **Proyectos cross-funcionales** | Un ingeniero necesita acceso a finanzas por 3 meses para un proyecto de migración. |

### 2.2 Cómo lo resuelve la industria

**Microsoft Dynamics 365** define dos modos de sesión temporal ([fuente](https://learn.microsoft.com/en-us/dynamics365/fin-ops-core/fin-ops/sysadmin/temp-role-mgmt)):

| Modo | Comportamiento | Al expirar |
|---|---|---|
| **Merge** | Agrega roles temporales junto con los existentes | Revoca solo los temporales. Los originales permanecen. |
| **Replace** | Reemplaza todos los roles existentes por los temporales | Restaura los roles originales. Los temporales se revocan. |

**GTRBAC** (Generalized Temporal RBAC) define activación de roles con restricciones temporales:
- `enable`/`disable` — activación/desactivación de roles por evento temporal
- Periodicidad: "todos los lunes de 8 a 17"
- Duración: "por 15 días a partir del 2026-08-01"

### 2.3 Cómo lo resuelve bAuth hoy

bAuth ya tiene la infraestructura técnica completa:

| Componente | Archivo | Qué hace |
|---|---|---|
| **Merge de BitMasks** | `src/bitmask/rol.rs` | `RolBitMask::merge()` — OR secuencial de N máscaras |
| **Fusión de roles** | `src/domain/merge.rs` | `MergeRoles` — combina atomicos de múltiples roles |
| **Asignación temporal** | `idn_user_role` | `valid_from`/`valid_until` + `is_active` — ventana temporal |
| **Delegación AND** | `src/domain/delegation.rs` | D10 — reducción al mínimo común (nunca excede lo propio) |
| **Recálculo automático** | `compute_rol_bitmask()` | OR de todos los roles activos → `rol_bitmask_base64` → Redis |

Lo que **falta** es exponer este mecanismo en AtomLang como un concepto de primera clase.

---

## §3 Los modos de fusión (Merge Modes)

AtomLang define tres modos de asignación de roles a usuarios:

```
MODO BASE (asignación permanente)
  Usuario tiene rol X.
  UserBitMask = RolBitMask(X)
  Sin fecha de expiración.

MODO MERGE (roles simultáneos)
  Usuario tiene roles [X, Y] activos al mismo tiempo.
  UserBitMask = RolBitMask(X) OR RolBitMask(Y)
  Ambos roles contribuyen bits. No hay conflicto porque cada átomo
  es una posición independiente.

MODO REPLACE (suplencia temporal)
  Usuario normalmente tiene rol X.
  Temporalmente (vacaciones de otro): se le asigna rol Y en modo REPLACE.
  Mientras tanto: UserBitMask = RolBitMask(Y)   (X se suspende)
  Al expirar:         UserBitMask = RolBitMask(X)   (X se restaura)
```

### 3.1 Merge — múltiples roles simultáneos

```
Usuario: María Gómez
  Roles activos: [Cajero, Supervisor_Turno]
  
  Cajero:          [1 1 0 1 1 0 1 0]   (5 átomos)
  Supervisor_Turno:[1 1 1 1 1 1 1 0]   (7 átomos)
  ----------------------------------- OR
  UserBitMask:     [1 1 1 1 1 1 1 0]   (7 átomos — unión sin duplicados)

  María puede hacer todo lo de cajero + todo lo de supervisor.
  Si se revoca Supervisor_Turno, solo pierde los átomos exclusivos de ese rol.
  Si se revoca Cajero, solo pierde los átomos exclusivos de ese rol.
```

### 3.2 Replace — suplencia por vacaciones

```
Usuario: Juan Pérez (Cajero)
Usuario: Ana López (Gerente — se va de vacaciones 15 días)

Paso 1 — RRHH configura suplencia:
  Juan Pérez recibe asignación temporal:
    rol:       Gerente
    modo:      REPLACE
    válido:    2026-08-01 → 2026-08-15
    motivo:    "Vacaciones de Ana López"
    delegante: Ana López

Paso 2 — Durante los 15 días:
  UserBitMask(Juan) = RolBitMask(Gerente)   ← Cajero suspendido
  Pero con reducción AND (D10):
  UserBitMask(Juan) = RolBitMask(Gerente) AND RolBitMask(Ana)
  Así Juan solo recibe lo que Ana ya tenía.

Paso 3 — El 2026-08-16:
  La asignación expira automáticamente.
  UserBitMask(Juan) = RolBitMask(Cajero)    ← restaurado
  Auditoría: registro WORM de todo el ciclo.
```

### 3.3 Reglas SoD en merge de roles

El sistema SoD (Separation of Duties) verifica que la combinación de roles no cree
conflictos. Esto aplica especialmente en modo MERGE:

```
ROL_A y ROL_B tienen SoD estático (SSD):
  No pueden estar activos simultáneamente en el mismo usuario.

Antes de activar el merge:
  1. SoD check: ¿ROL_A y ROL_B están en conflicto?
     → SI: RECHAZAR. Requiere aprobación ARB + registro de excepción.
     → NO: permitir merge.

Conflictos dinámicos (DSD — D10):
  ROL_A puede aprobar pagos.
  ROL_B puede iniciar pagos.
  Mismo usuario con ambos roles → puede iniciar Y aprobar el mismo pago.
  → D10 detecta y bloquea en runtime (reducción AND no aplica a átomos SoD).
```

---

## §4 Diseño en AtomLang — la asignación temporal como objeto del árbol

### 4.1 Nuevo nodo en el árbol: `asignacion_temporal`

Se propone un nuevo tipo de nodo en el árbol AtomLang para representar asignaciones
temporales. Vive bajo la Vista Usuario, no en el árbol de políticas:

```yaml
# En la Vista Usuario del dashboard
usuario "Juan Pérez":
  rol_base: Cajero
  
  # ── ASIGNACIONES TEMPORALES ──
  asignacion_temporal "Suplencia Gerencia Agosto 2026":
    rol:          Gerente_Regional
    modo:         REPLACE          # MERGE | REPLACE
    delegante:    Ana López        # el usuario cuyo rol se está supliendo
    valido_desde: 2026-08-01T00:00:00Z
    valido_hasta: 2026-08-15T23:59:59Z
    motivo:       "Vacaciones programadas"
    reduccion:    AND              # D10: reducción al mínimo común
    aprobado_por: RRHH.Director
```

### 4.2 Modos de asignación (enum)

```yaml
modo_asignacion:
  - PERMANENTE    # asignación sin expiración (rol base)
  - MERGE         # agrega al UserBitMask existente (OR)
  - REPLACE       # reemplaza el UserBitMask existente (solo el temporal)
```

### 4.3 Integración con D10 (reducción AND)

Cuando la asignación temporal tiene `reduccion: AND`:

```
RolBitMask(delegante: Ana López):   [1 1 1 1 1 1 0 1]
RolBitMask(Gerente_Regional):       [1 1 1 1 1 1 1 1]
------------------------------------------------------ AND
RolBitMask efectivo para Juan:      [1 1 1 1 1 1 0 1]  ← lo que Ana ya tenía
```

Juan NUNCA recibe más privilegios que Ana. Si Ana no podía aprobar transferencias (>$50k),
Juan tampoco podrá, aunque el rol Gerente_Regional normalmente lo permita.

---

## §5 Propuesta de tabla: `bauth.user_role_assignment`

La tabla `idn_user_role` ya existe pero es genérica. Se propone extenderla o crear
una tabla complementaria para asignaciones temporales con semántica AtomLang:

```sql
-- Extensión propuesta para idn_user_role (o nueva tabla)
ALTER TABLE bauth.idn_user_role ADD COLUMN IF NOT EXISTS
    assignment_mode  TEXT DEFAULT 'PERMANENTE';  -- PERMANENTE | MERGE | REPLACE

ALTER TABLE bauth.idn_user_role ADD COLUMN IF NOT EXISTS
    delegating_user  UUID;  -- el usuario cuyo rol se está supliendo (vacaciones)

ALTER TABLE bauth.idn_user_role ADD COLUMN IF NOT EXISTS
    reduction_mode   TEXT DEFAULT 'AND';  -- AND | NONE (D10)

ALTER TABLE bauth.idn_user_role ADD COLUMN IF NOT EXISTS
    motivo           TEXT;  -- requerido para auditoría
```

---

## §6 Pipeline extendido (Paso 4 refinado)

El Paso 4 del modelo simplificado (A.50 §2) se refina así:

```
PASO 4 — INSCRIBIR usuarios a roles (admin / RRHH)

4a. ASIGNACIÓN PERMANENTE (rol base)
    idn_user_role: INSERT { user_uuid, role_id, mode: PERMANENTE }

4b. ASIGNACIÓN TEMPORAL MERGE (roles simultáneos)
    idn_user_role: INSERT { user_uuid, role_id, mode: MERGE,
                            valid_from, valid_until }
    → SoD check antes de persistir
    → UserBitMask = OR(todos los roles activos)

4c. ASIGNACIÓN TEMPORAL REPLACE (suplencia)
    idn_user_role: INSERT { user_uuid, role_id, mode: REPLACE,
                            valid_from, valid_until,
                            delegating_user, reduction_mode }
    → Verifica delegation_config del rol fuente
    → Si reduction_mode = AND: aplica D10
    → UserBitMask = RolBitMask(temporal) AND RolBitMask(delegante)
    → Los roles base se suspenden durante la vigencia

4d. EXPIRACIÓN AUTOMÁTICA
    Cron job o trigger: WHERE valid_until < now() AND is_active = true
    → is_active = false
    → Si mode = REPLACE: restaurar roles base
    → Recalcular UserBitMask → Redis
    → Auditoría WORM
```

---

## §7 Estado de implementación

| Componente | Estado |
|---|---|
| `RolBitMask::merge()` (OR de máscaras) | ✅ Implementado (`src/bitmask/rol.rs`) |
| `MergeRoles` (fusión de roles) | ✅ Implementado (`src/domain/merge.rs`) |
| `merge_templates.rs` (handler) | ✅ Implementado |
| `idn_user_role` con `valid_from`/`valid_until` | ✅ DDL aplicado (T-171) |
| `delegation.rs` (D10 — reducción AND) | ✅ Implementado |
| Columnas `assignment_mode`, `delegating_user`, `reduction_mode`, `motivo` | ❌ Propuesta — no aplicado |
| Nodo `asignacion_temporal` en el árbol AtomLang | ❌ Diseño — no implementado |
| UI de asignación temporal en dashboard | ❌ No implementado |
| Flujo de suplencia/vacaciones documentado | ❌ No existe — este anexo es el primero |

---

## §8 Mapa anexo → manuales

| Sección | Respalda a | Qué sección |
|---|---|---|
| §2 (fundamento) | 2.13 v2.0 §7 · A.50 §2 | Necesidad de negocio + industria |
| §3 (modos de fusión) | 2.13 v2.0 §7 · A.50 §4 | Merge, Replace, SoD |
| §4 (diseño AtomLang) | 2.13 v2.0 §6 | Constructor visual — nodo asignacion_temporal |
| §5 (propuesta tabla) | DDLs compartidos | Extensión idn_user_role |
| §6 (pipeline extendido) | A.50 §2 | Paso 4 refinado |

---

## Referencias

- Microsoft Dynamics 365 — [Temporary Role Management](https://learn.microsoft.com/en-us/dynamics365/fin-ops-core/fin-ops/sysadmin/temp-role-mgmt)
- GTRBAC — Generalized Temporal RBAC, ACM Transactions on Information and System Security
- ANSI INCITS 359-2004 §4.2 — Dynamic Separation of Duty (DSD)
- NIST SP 800-53 AC-5 — Separation of Duties
- [A.50 — Modelo Simplificado](A.50_ANEXO-MODELO-SIMPLIFICADO-ROLES-USUARIOS-v1.0.md)
- [1.04 — Manual BitMask](../1.04_MANUAL-BITMASK-v1.0.md) §10 (merge, herencia DAG)
- [1.08 — Manual User Template](../1.08_MANUAL-USER-TEMPLATE-v1.0.md) §5 (idn_user_role)

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-14 | Primera edición. Define el modelo de fusión de roles: 3 modos (PERMANENTE, MERGE, REPLACE), integración con D10 (reducción AND para suplencias), propuesta de extensión de `idn_user_role` con columnas `assignment_mode`/`delegating_user`/`reduction_mode`/`motivo`, pipeline Paso 4 refinado con 4 sub-pasos, y nuevo nodo `asignacion_temporal` en el árbol AtomLang. |
