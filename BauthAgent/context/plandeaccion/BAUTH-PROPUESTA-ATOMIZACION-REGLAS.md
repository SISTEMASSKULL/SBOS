# BAUTH-PROPUESTA-ATOMIZACION-REGLAS — Unificar el modelo de átomos a las reglas
## domain.app.module.verb = átomo · domain.app.module.rule = átomo de regla · 2026-06-30

**Propuesta:** Aplicar el MISMO modelo atómico que funciona en `privilege_atom` a las reglas
y políticas. Lo que hoy son 4 tablas desconectadas se vuelve UN solo sistema coherente.

---

## 1. EL PROBLEMA ACTUAL

Hoy tenemos DOS sistemas paralelos que gestionan lo mismo de formas incompatibles:

### Sistema A — Átomos de permiso (FUNCIONA)

```
privilege_atom = domain.app.group.verb
  ├── D3.tryton.ventas.CREATE        → posición 42 en RolBitMask
  ├── D3.tryton.ventas.READ          → posición 43
  ├── D1.superset.dashboard.VIEW     → posición 100
  └── ... 5,808 átomos en total

Asignación: privilege_role_atom (rol ↔ átomo, allowed=true/false)
Evaluación: fastpath_check(rol, atom_position) → O(1)
```

### Sistema B — Reglas y políticas (ROTO)

```
4 tablas distintas para conceptos que son ESENCIALMENTE LO MISMO:

cfg_policy_library:    "Existe max_daily_limit para D3, enforcement=mandatory"
cfg_validation_rule:   "max_daily_limit debe ser INTEGER entre 0 y 999,999,999"
ath_policy_d3:         "max_daily_limit está ACTIVA"
RoleTemplate.config:   "ROL-CAJERO: maxAmount = $100,000"
fin_limit:             Tabla relacional que NADIE USA
fin_transaction_type:  Catálogo de tipos de transacción

Resultado: 6 tablas para hacer lo que 2 tablas (átomo + valor) podrían resolver.
```

---

## 2. LA PROPUESTA: TODO ES UN ÁTOMO

### Principio unificador

> **Toda regla, política, configuración y permiso es un ÁTOMO.**
> **Un átomo = `dominio.aplicación.módulo.verbo`**
> **Lo único que cambia es si el átomo es BINARIO (allow/deny) o tiene VALOR (número, texto, booleano).**

### Los dos tipos de átomos

| Tipo | Estructura | Ejemplo | Evaluación |
|------|-----------|---------|------------|
| **Átomo de ACCIÓN** (actual) | `d.a.m.v` → posición N en BitMask | D3.tryton.ventas.CREATE | Binario: ¿tiene el bit? → ALLOW/DENY |
| **Átomo de REGLA** (nuevo) | `d.a.m.v` → posición N en BitMask + valor | D3.bauth.financial.max_daily | Con valor: ¿tiene el bit? → leer valor → comparar |

### Cómo funciona

```
privilege_atom (catálogo unificado de átomos)
  │
  ├── Átomo #42:  D3.tryton.ventas.CREATE           [ACCIÓN, binario]
  ├── Átomo #43:  D3.tryton.ventas.READ             [ACCIÓN, binario]
  ├── Átomo #100: D1.superset.dashboard.VIEW        [ACCIÓN, binario]
  │
  ├── Átomo #2000: D3.bauth.financial.max_daily      [REGLA, numérico]
  ├── Átomo #2001: D3.bauth.financial.requires_dual  [REGLA, booleano]
  ├── Átomo #2002: D9.bauth.password.min_length      [REGLA, numérico]
  ├── Átomo #2003: D8.bauth.session.ttl_max          [REGLA, numérico]
  ├── Átomo #2004: D7.bauth.network.vpn_required     [REGLA, booleano]
  └── ... (tantos átomos como combinaciones d.a.m.v existan)
```

### Asignación a roles (IGUAL que los átomos de acción)

```
privilege_role_atom (rol ↔ átomo, valor opcional)
  │
  ├── ROL-CAJERO ↔ átomo #42 (CREATE) → allowed=true     [binario]
  ├── ROL-CAJERO ↔ átomo #43 (READ) → allowed=true       [binario]
  ├── ROL-CAJERO ↔ átomo #2000 (max_daily) → value=100000 [con valor]
  ├── ROL-CAJERO ↔ átomo #2001 (requires_dual) → value=false [con valor]
  │
  ├── ROL-CONTADOR ↔ átomo #2000 (max_daily) → value=500000 [con valor]
  ├── ROL-CONTADOR ↔ átomo #2001 (requires_dual) → value=true [con valor]
  └── ...
```

### Evaluación en runtime (UN solo motor)

```rust
fn evaluate(user: &User, atom_slug: &str, context: &Context) -> Verdict {
    let atom = atom_catalog.resolve(atom_slug)?;

    // 1. FastPath: ¿tiene el usuario el bit de este átomo en su RolBitMask?
    if !fastpath_check(&user.rol_bitmask, atom.position) {
        return DENY;
    }

    // 2. ¿Es átomo de ACCIÓN o de REGLA?
    match atom.atom_type {
        AtomType::Action => ALLOW,  // binario: tiene el bit = permitido

        AtomType::Rule {
            ref data_type,
            ref validation,
        } => {
            // 3. Obtener el VALOR asignado al ROL del usuario para este átomo
            let rule_value = get_role_atom_value(&user.roles, atom.position);

            // 4. Evaluar regla: comparar valor de la regla con el contexto
            match data_type {
                DataType::Numeric { max } => {
                    if context.request_amount <= rule_value.as_u64() { ALLOW } else { DENY }
                }
                DataType::Boolean => {
                    if rule_value.as_bool() { ALLOW } else { DENY }
                }
                // ... otros tipos
            }
        }
    }
}
```

---

## 3. QUÉ SE SIMPLIFICA (y qué se elimina)

### Tablas que DESAPARECEN (absorbidas por el modelo atómico)

| Tabla actual | Reemplazada por |
|-------------|----------------|
| `ath_policy_d1..d12` | `privilege_atom` (átomos de regla en el catálogo unificado) |
| `ath_config_d1..d12` | `privilege_role_atom.value` (valor de regla asignado al rol) |
| `cfg_validation_rule` | `privilege_atom.validation` (validación en el mismo átomo) |
| `fin_limit` | `privilege_role_atom.value` para átomos D3 |
| `fin_transaction_type` | `privilege_group` (agrupación de átomos financieros) |

### Tablas que se MANTIENEN (simplificadas)

| Tabla | Nuevo rol |
|-------|-----------|
| `cfg_policy_library` | **Catálogo de referencia documental.** Define QUÉ átomos existen y por qué (estándar). NO se evalúa en runtime. |
| `privilege_atom` | **Catálogo unificado de átomos** (acciones + reglas). `atom_slug`, `atom_type`, `data_type`, `validation`. |
| `privilege_role_atom` | **Asignación rol ↔ átomo.** `role_id`, `atom_id`, `allowed`, `value` (para átomos de regla). |
| `privilege_role` | Roles definidos por tenant. |
| `idn_role_template` | Template JSONB que AGRUPA átomos en secciones lógicas para el admin. |
| `idn_user_template` | Usuario con roles asignados + RolBitMask precomputado. |

---

## 4. MANEJO DEL UNIVERSO COMBINATORIO

### El problema

Si todo es `d.a.m.v`, ¿cuántos átomos hay?

- 12 dominios × 15 aplicaciones × 50 módulos × 30 verbos/reglas = 270,000 combinaciones

Pero en la práctica:
- La mayoría de combinaciones NO EXISTEN (no hay "D2.superset.almacen.TOTP")
- Los átomos se CREAN bajo demanda cuando se necesita una nueva regla
- El catálogo crece orgánicamente, no se pre-puebla con todas las combinaciones

### El modelo actual ya maneja 5,808 átomos sin problema

```
privilege_atom: 5,808 registros
privilege_role_atom: 212 asignaciones (y creciendo por tenant)
RolBitMask: N bits, donde N = número de átomos en el catálogo
FastPath: O(1) — acceso directo al bit N
```

Agregar átomos de regla solo incrementa N. El mecanismo es el mismo.

### Agrupación lógica para el Dashboard

El admin NO ve 5,808 átomos planos. Los ve agrupados por el árbol `d.a.m.v`:

```
Dashboard — Editor de Rol
  │
  ├── 🌐 D1 — LÓGICO
  │   └── App: Tryton
  │       ├── Módulo: ventas
  │       │   ├── ☑ CREATE    [ACCIÓN]
  │       │   ├── ☑ READ      [ACCIÓN]
  │       │   └── ☐ DELETE    [ACCIÓN]
  │       └── Módulo: compras
  │           └── ☑ CREATE    [ACCIÓN]
  │
  ├── 💰 D3 — FINANCIERO
  │   └── App: bAuth (motor de reglas)
  │       └── Módulo: financial
  │           ├── max_daily:     [$100,000]  [REGLA numérica]
  │           ├── requires_dual: [☐]         [REGLA booleana]
  │           └── currency:      [BOB]        [REGLA texto]
  │
  └── 🔐 D9 — CREDENCIALES
      └── App: bAuth (motor de reglas)
          └── Módulo: password
              ├── min_length:    [12]         [REGLA numérica]
              ├── require_mfa:   [☑]         [REGLA booleana]
              └── hibp_enabled:  [☑]         [REGLA booleana]
```

---

## 5. FLUJO COMPLETO CON EL NUEVO MODELO

### 5.1 Crear una nueva regla (Admin de Dominio)

```
1. Admin abre Dashboard → Panel de Reglas
2. "Nueva regla financiera"
3. Selecciona: dominio=D3, app=bauth, módulo=financial, verbo=max_daily_internal
4. Define: tipo=numérico, validación={min:0, max:999999999}, estándar=NIST SP 800-63B
5. Propone (lifecycle='proposed')
6. Admin de Seguridad revisa → aprueba (lifecycle='active')
7. Se crea el átomo en privilege_atom (atom_position = N+1)
8. El átomo aparece disponible para asignar a roles
```

### 5.2 Asignar regla a un rol (Admin de Dominio)

```
1. Admin expande árbol D3 > bAuth > financial
2. Ve el nuevo átomo: max_daily_internal
3. Selecciona ROL-CAJERO
4. Asigna valor: $100,000
5. → INSERT INTO privilege_role_atom (role_id, atom_id, allowed=true, value=100000)
6. → Se recalcula RolBitMask del rol (bit N+1 = 1)
7. → Se propagan a usuarios que tienen ROL-CAJERO
```

### 5.3 Evaluar en runtime

```
bauth.access.evaluate("D3.bauth.financial.max_daily_internal", user="jperez")
  │
  ├── 1. atom_catalog.resolve("D3.bauth.financial.max_daily_internal") → position=2000
  ├── 2. fastpath_check(user.rol_bitmask, 2000) → true (tiene el bit)
  ├── 3. atom.atom_type = Rule(Numeric { min:0, max:999999999 })
  ├── 4. rule_value = get_role_atom_value(user.roles, 2000) → 100000
  ├── 5. context.request_amount = 5000
  ├── 6. 5000 ≤ 100000 → ALLOW
  └── Verdict: ALLOW
```

---

## 6. VENTAJAS DEL MODELO UNIFICADO

| Ventaja | Explicación |
|---------|------------|
| **Un solo motor** | Acciones y reglas usan el MISMO BitMask, FastPath, y privilegio_role_atom |
| **Una sola tabla de asignación** | `privilege_role_atom` asigna tanto permisos como reglas |
| **O(1) para todo** | Verificar si un usuario tiene una regla es tan rápido como verificar un permiso |
| **Dashboard unificado** | El admin ve acciones y reglas en el MISMO árbol d.a.m.v |
| **Combinatoria manejable** | Solo existen los átomos creados. No se pre-pueblan 270,000 combinaciones. |
| **Elimina 5 tablas** | `ath_policy_d*`, `ath_config_d*`, `cfg_validation_rule`, `fin_limit`, `fin_transaction_type` |
| **Extensible** | Nuevo tipo de átomo = nueva variante de `AtomType`. Sin cambiar el motor. |

---

## 7. COMPARACIÓN: ANTES vs DESPUÉS

| Aspecto | Antes (6 tablas) | Después (modelo atómico) |
|--------|-----------------|------------------------|
| **Catálogo de reglas** | `cfg_policy_library` + `cfg_validation_rule` + `ath_policy_d*` + `fin_*` | `privilege_atom` (atom_type=Rule) |
| **Asignación a rol** | JSONB en RoleTemplate (denormalizado, sin FK) | `privilege_role_atom` (relacional, con FK) |
| **Validación** | `cfg_validation_rule` (tabla separada, sin FK a políticas) | `privilege_atom.validation` (en el mismo registro) |
| **Evaluación runtime** | `ath_loader` → `ath_converter` → `evaluate()` (multi-paso) | `fastpath_check()` + `get_role_atom_value()` (O(1) + 1 query) |
| **Valores por rol** | Generados por TIER en seed SQL (todos BIZ_N1 igual) | Asignados por ROL individual en `privilege_role_atom.value` |
| **Dashboard** | Panel 4 separado para políticas; Panel 11 separado para átomos | UN solo árbol d.a.m.v con todo |

---

## 8. PLAN DE MIGRACIÓN

### Fase 1 — Extender `privilege_atom` (sin romper nada)

```sql
ALTER TABLE bauth.privilege_atom ADD COLUMN IF NOT EXISTS atom_type TEXT
    CHECK (atom_type IN ('ACTION', 'RULE')) DEFAULT 'ACTION';
ALTER TABLE bauth.privilege_atom ADD COLUMN IF NOT EXISTS data_type TEXT
    CHECK (data_type IN ('BOOLEAN', 'NUMERIC', 'TEXT', 'ENUM', 'RANGE'));
ALTER TABLE bauth.privilege_atom ADD COLUMN IF NOT EXISTS validation JSONB;
-- validation: {"min": 0, "max": 999999999, "allowed_values": null, "unit": "BOB"}
```

### Fase 2 — Extender `privilege_role_atom` (sin romper nada)

```sql
ALTER TABLE bauth.privilege_role_atom ADD COLUMN IF NOT EXISTS value JSONB;
-- value: null para átomos ACTION, 100000 para átomos RULE numéricos
ALTER TABLE bauth.privilege_role_atom ADD COLUMN IF NOT EXISTS customized BOOLEAN DEFAULT false;
```

### Fase 3 — Migrar reglas existentes a átomos

1. Para cada entrada en `ath_policy_d3` con `node_type='policy'`:
   - Crear átomo `D3.bauth.financial.{policy_code}` con `atom_type='RULE'`
2. Para cada valor en `RoleTemplate.config.financial.limits[]`:
   - Migrar a `privilege_role_atom (role_id, atom_id, value)`
3. Verificar que la evaluación runtime produce los mismos resultados

### Fase 4 — Eliminar tablas obsoletas

Marcar como `[DEPRECADO]`: `ath_policy_d*`, `ath_config_d*`, `cfg_validation_rule`, `fin_limit`.
Eliminar en siguiente release después de verificar migración completa.

---

## 9. CONCLUSIÓN

El modelo `d.a.m.v` que ya funciona para permisos de acción debe extenderse a reglas y políticas.
La distinción entre "permiso" y "regla" es solo el TIPO de átomo (binario vs con valor).
El mecanismo de asignación, evaluación y visualización es EXACTAMENTE el mismo.

Esto reduce 6 tablas a 2, unifica el Dashboard en un solo árbol, y hace que el universo
de combinaciones sea manejable (solo existen los átomos creados, no todas las combinaciones posibles).

---

*BAUTH-PROPUESTA-ATOMIZACION-REGLAS.md v1.0 · 2026-06-30*
