# BAUTH-AUDITORIA-REGLAS-POLITICAS — Del catálogo al rol: la cadena completa
## Cómo una política se vuelve una regla asignada a un rol específico · 2026-06-30

**Pregunta central:** *"Un cajero y un contador tienen asignada la misma política financiera, pero cada uno con diferente límite de monto. ¿Cómo se gestiona esto en bAuth?"*

---

## 1. LAS 4 CAPAS DE DATOS (arquitectura real)

Actualmente existen 4 capas de datos que gestionan políticas y reglas. El problema es que **no están claramente diferenciadas** y sus responsabilidades se solapan.

```
┌──────────────────────────────────────────────────────────────────────┐
│  CAPA 1 — CATÁLOGO UNIVERSAL (cfg_policy_library · 9,142 entradas)   │
│  "QUÉ políticas, reglas, configs y métodos EXISTEN en el universo"    │
│                                                                      │
│  Aquí están TODAS las normas de todos los estándares.                 │
│  node_type: section | group | policy | config                        │
│  semantic_type: policy | configuration | method | standard | guideline│
└────────────────────────────┬─────────────────────────────────────────┘
                             │
          ┌──────────────────┴──────────────────┐
          ▼                                     ▼
┌──────────────────────────┐    ┌──────────────────────────────────────┐
│  CAPA 2a — VALIDACIÓN    │    │  CAPA 2b — OPERATIVAS                │
│  (cfg_validation_rule)   │    │  (ath_policy_d1..d12)                │
│  58+ reglas              │    │  ~100 políticas activas              │
│                          │    │                                      │
│  "CÓMO validar campos"   │    │  "QUÉ evaluar en runtime"            │
│  • VAL-D8-001:           │    │  • D3: max_daily_limit               │
│    session_ttl_max       │    │  • D3: requires_dual_approval        │
│    BETWEEN 3600 AND 43200│    │  • D9: password_min_length           │
│  • VAL-D9-001:           │    │  • D9: mfa_required                  │
│    min_length            │    │                                      │
│    BETWEEN 8 AND 64      │    │  Se evalúan en runtime contra el     │
│                          │    │  contexto del usuario (rol, tier).   │
│  Validan ESTRUCTURA.     │    │  Deciden PERMITIR/DENEGAR.           │
│  No deciden acceso.      │    │                                      │
└──────────────────────────┘    └──────────────┬───────────────────────┘
                                               │
                                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│  CAPA 3 — ASIGNACIÓN POR ROL (RoleTemplate · idn_role_template)      │
│  "QUÉ valores específicos aplican a ESTE rol"                         │
│                                                                      │
│  Rol "CAJERO" (BIZ_N1):              Rol "CONTADOR" (BIZ_N2):       │
│  ┌────────────────────────┐          ┌────────────────────────┐     │
│  │ financial:             │          │ financial:             │     │
│  │   maxAmount: $100,000  │          │   maxAmount: $500,000  │     │
│  │   requiresDual: false  │          │   requiresDual: true   │     │
│  │   period: daily        │          │   period: daily        │     │
│  │ credentials:           │          │ credentials:           │     │
│  │   mfa_required: false  │          │   mfa_required: true   │     │
│  │   min_aal: AAL1        │          │   min_aal: AAL2        │     │
│  └────────────────────────┘          └────────────────────────┘     │
│                                                                      │
│  MISMA política (maxAmount), DIFERENTE regla ($100K vs $500K).      │
│  MISMA política (mfa_required), DIFERENTE regla (false vs true).     │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│  CAPA 4 — ASIGNACIÓN POR USUARIO (UserTemplate · idn_user_template)  │
│  "QUÉ roles tiene ESTE usuario"                                       │
│                                                                      │
│  Usuario "jperez":                     Usuario "mgomez":              │
│  ┌────────────────────────┐           ┌────────────────────────┐    │
│  │ roles:                 │           │ roles:                 │    │
│  │   - ROL-CAJERO         │           │   - ROL-CONTADOR       │    │
│  │   - ROL-VENDEDOR       │           │   - ROL-AUDITOR        │    │
│  │ empresa: "sucursal_norte"│         │ empresa: "oficina_central"│ │
│  └────────────────────────┘           └────────────────────────┘    │
│                                                                      │
│  jperez hereda las reglas del CAJERO (maxAmount=$100K).              │
│  mgomez hereda las reglas del CONTADOR (maxAmount=$500K).            │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 2. LA DISTINCIÓN CRÍTICA: POLÍTICA ≠ REGLA

| Concepto | Definición | Ejemplo | Dónde se almacena |
|---------|-----------|---------|-------------------|
| **POLÍTICA** | Una categoría de control que EXISTE. Es la definición abstracta. | "Existe un límite máximo diario para transacciones financieras" | `cfg_policy_library` (definición) + `ath_policy_d3` (activa) |
| **REGLA** | El valor CONCRETO de una política para un ROL específico. | "Para CAJERO, el límite es $100,000" | `idn_role_template.config.financial.limits[].maxAmount` |
| **VALIDACIÓN** | El RANGO permitido para una regla. | "maxAmount debe estar entre 0 y 999,999,999" | `cfg_validation_rule` (VAL-D3-001) |
| **CONFIG** | El valor por DEFECTO del sistema. | "Si un rol no define maxAmount, usar $2,000" | `ath_config_d3` o `bglobal.global_config` |

**La confusión actual:** Las 4 cosas se llaman "políticas" en diferentes partes del código.
La `cfg_policy_library` contiene políticas, reglas, configs Y métodos — todo mezclado bajo
`node_type` y `semantic_type`. No hay una separación clara entre "esto es una definición"
y "esto es una instancia para un rol específico".

---

## 3. CADENA COMPLETA: DE LA BIBLIOTECA AL ROL

### Paso 1 — La biblioteca define QUÉ existe

```sql
-- cfg_policy_library contiene la DEFINICIÓN de la política:
INSERT INTO cfg_policy_library (section_name, node_type, semantic_type, domain_map, enforcement)
VALUES ('max_daily_limit', 'policy', 'policy', '{D3}', 'mandatory');
```

### Paso 2 — La semilla promueve políticas a operativas

```sql
-- El seed (build time) copia las mandatory a ath_policy_d3:
INSERT INTO ath_policy_d3 (policy_code, config, is_active)
SELECT section_name, content, true
FROM cfg_policy_library
WHERE semantic_type = 'policy' AND domain_map @> '{D3}' AND enforcement = 'mandatory';
```

### Paso 3 — El RoleTemplate asigna VALORES CONCRETOS por rol

```sql
-- El seed del RoleTemplate genera límites POR TIER:
UPDATE idn_role_template SET template = jsonb_set(template, '{financial,limits}',
  (SELECT jsonb_agg(jsonb_build_object(
    'transactionType', code,
    'maxAmount', CASE
      WHEN tier = 'BIZ_N1' THEN 100000   -- Cajero
      WHEN tier = 'BIZ_N2' THEN 50000    -- Contador
      WHEN tier = 'BIZ_N3' THEN 10000    -- Supervisor
      ELSE 0
    END,
    'period', 'daily'
  )) FROM fin_transaction_type WHERE is_active = true)
);
```

### Paso 4 — Runtime evalúa con el contexto del usuario

```rust
// bauth.policy.domain.evaluate(D3, ctx):
// 1. Carga políticas activas de ath_policy_d3
// 2. Obtiene el RolBitMask del usuario desde idn_user_template
// 3. Obtiene los límites del RolTemplate desde idn_role_template.config.financial
// 4. Evalúa: ¿el monto de esta transacción ≤ maxAmount del rol del usuario?
// 5. Retorna ALLOW o DENY
```

---

## 4. DIAGRAMA DE FLUJO: POLÍTICA → REGLA → ROL → USUARIO → RUNTIME

```
cfg_policy_library (9,142 entradas)
  │  "Existe la política max_daily_limit para D3, enforcement=mandatory"
  │
  ├──► ath_policy_d3 (operativa)
  │      "max_daily_limit está ACTIVA en runtime"
  │
  ├──► cfg_validation_rule (58 reglas)
  │      "maxAmount debe ser INTEGER entre 0 y 999,999,999"
  │
  └──► RoleTemplate (seed_idn_role_template_data.sql)
         │
         │  El seed GENERA valores POR TIER:
         │
         ├── ROL-CAJERO (BIZ_N1):  maxAmount = $100,000
         ├── ROL-CONTADOR (BIZ_N2): maxAmount = $50,000
         ├── ROL-SUPERVISOR (BIZ_N3): maxAmount = $10,000
         └── ROL-GERENTE (BIZ_N5): maxAmount = $1,000,000
              │
              │  El admin asigna roles a usuarios:
              ▼
         UserTemplate
           │
           ├── jperez → [ROL-CAJERO, ROL-VENDEDOR]
           ├── mgomez → [ROL-CONTADOR, ROL-AUDITOR]
           └── ...
                │
                ▼
         RUNTIME: bauth.access.evaluate("factura.emitir", "jperez")
           │
           ├── FastPath: RolBitMask[jperez] tiene el bit de "factura.emitir"? → SÍ
           ├── PolicyPath: cargar ath_policy_d3 → max_daily_limit está activa
           ├── Obtener límite del rol: ROL-CAJERO → maxAmount = $100,000
           ├── Comparar: transacción = $5,000 ≤ $100,000 → OK
           └── Verdict: ALLOW
```

---

## 5. HALLAZGOS DE LA AUDITORÍA

### HALLAZGO 1 (🔴 CRÍTICO): `cfg_validation_rule` y `cfg_policy_library` solapadas

| Tabla | Propósito | Nivel | Ejemplo |
|-------|-----------|-------|---------|
| `cfg_policy_library` | Catálogo universal. Define QUÉ políticas/configs/métodos existen. | Alto (conceptual) | "Existe una política llamada max_daily_limit" |
| `cfg_validation_rule` | Validación de campos. Define COMO validar valores concretos. | Bajo (técnico) | "max_daily_limit debe ser INTEGER entre 0 y 999,999,999" |

**Problema:** Ambas referencian estándares (`standard_ref`). Ambas clasifican por dominio. Pero no hay FK que las vincule. Una política en `cfg_policy_library` NO sabe qué reglas de validación le aplican en `cfg_validation_rule`.

**Recomendación:** Agregar FK `cfg_validation_rule.policy_ref → cfg_policy_library.section_name`. Así cada regla de validación sabe EXACTAMENTE qué política está validando.

### HALLAZGO 2 (🟠 ALTO): El RoleTemplate genera valores por TIER, no por ROL individual

El seed actual (`seed_idn_role_template_data.sql`) usa `CASE WHEN r.tier` para asignar límites. Esto significa que TODOS los roles del mismo tier reciben los mismos valores BASE. La personalización fina (ej: "este cajero específico tiene $200,000 porque trabaja en la sucursal principal") no está soportada por el seed — requiere intervención manual del admin vía Dashboard.

**Recomendación:** El Dashboard debe permitir editar los valores por ROL (no solo por tier) después de la generación inicial. La columna `customized` protege estas personalizaciones.

### HALLAZGO 3 (🟠 ALTO): `cfg_validation_rule` tiene 58 reglas; el seed referencia 14 estándares

Las 58 reglas de validación cubren 12 dominios pero solo validan constraints TÉCNICOS (RANGE, ENUM, TYPE). No hay validaciones SEMÁNTICAS (ej: "un cajero no puede tener maxAmount > $500,000 porque viola SoD con el gerente").

**Recomendación:** Extender `cfg_validation_rule` con `category='SEMANTIC'` para reglas de negocio cross-rol. El `RuleEngine` ya soporta `SEMANTIC` como categoría.

### HALLAZGO 4 (🟡 MEDIO): La tabla `fin_limit` no está siendo usada en seeds

`fin_limit` es una tabla relacional (rol, transaction_type, max_amount, period) diseñada para almacenar límites por rol. Pero el seed del RoleTemplate genera los límites DIRECTAMENTE en el JSONB sin pasar por `fin_limit`.

**Recomendación:** Decidir: ¿usamos `fin_limit` como fuente canónica de límites (normalizado) o los almacenamos solo en el JSONB del RoleTemplate (denormalizado)? Si elegimos JSONB, marcar `fin_limit` como `[DEPRECADO]`.

### HALLAZGO 5 (🟡 MEDIO): `cfg_validation_rule` y `cfg_policy_library` no tienen owner claro

| Tabla | ¿Quién la puebla? | ¿Quién la modifica? | ¿Quién la lee? |
|-------|-------------------|---------------------|----------------|
| `cfg_policy_library` | Seeds (build time) | Admin de Seguridad (Dashboard, futuro) | Dashboard, reconcile loop, seeds |
| `cfg_validation_rule` | Seeds (build time) | ¿Nadie? (solo build time) | RuleEngine, template_validate.rs |

`cfg_validation_rule` no tiene un mecanismo de actualización en runtime. Si un estándar cambia (ej: NIST aumenta el mínimo de contraseña de 8 a 10), hay que MODIFICAR EL SEED SQL y re-ejecutarlo. No hay workflow de aprobación como el de `cfg_policy_library`.

**Recomendación:** Aplicar el MISMO workflow de aprobación (PARTE 0.4) a `cfg_validation_rule`. Un cambio en una regla de validación es tan crítico como un cambio en una política.

---

## 6. CORRECCIONES RECOMENDADAS

### Fase 1 — Vincular (inmediato)

| Acción | Prioridad |
|--------|:---:|
| Agregar `cfg_validation_rule.policy_ref → cfg_policy_library.section_name` (FK) | 🔴 |
| Documentar la distinción POLÍTICA ≠ REGLA ≠ VALIDACIÓN ≠ CONFIG en MANUAL_DB_DDL.md | 🔴 |
| Agregar `COMMENT ON` en las 4 tablas explicando su rol en la cadena | 🟠 |

### Fase 2 — Unificar

| Acción | Prioridad |
|--------|:---:|
| Extender `cfg_validation_rule.category` con `SEMANTIC` para reglas de negocio | 🟠 |
| Aplicar workflow de aprobación a `cfg_validation_rule` (mismo que `cfg_policy_library`) | 🟠 |
| Decidir: `fin_limit` relacional vs JSONB en RoleTemplate → marcar o eliminar | 🟡 |

### Fase 3 — Robustecer

| Acción | Prioridad |
|--------|:---:|
| Auditoría WORM para `cfg_validation_rule` (misma protección que la biblioteca) | 🟡 |
| Dashboard: editor de reglas por ROL (no solo por tier) | 🟡 |
| Reconcile loop: verificar `cfg_validation_rule` vs valores en RoleTemplates activos | 🟡 |

---

## 7. CONCLUSIÓN

La cadena **biblioteca → política → validación → regla → rol → usuario → runtime** está
implementada pero con 3 problemas:

1. **Solapamiento:** `cfg_policy_library` y `cfg_validation_rule` contienen información relacionada sin FK que las vincule
2. **Granularidad:** Los valores por rol se generan por TIER, no por ROL individual. Falta personalización fina.
3. **Protección asimétrica:** La biblioteca tiene 4 anillos de protección planeados, pero `cfg_validation_rule` no tiene ninguno

La solución es tratar `cfg_validation_rule` con el MISMO nivel de protección que `cfg_policy_library`
(FORTALEZA), vincularlas mediante FK, y permitir que el Dashboard edite reglas por ROL preservando
personalizaciones.

---

*BAUTH-AUDITORIA-REGLAS-POLITICAS.md v1.0 · 2026-06-30*
