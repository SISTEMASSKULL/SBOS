# A.48 — Parametrización `bauth_config_param`
## Tipo B+C+A — Fundamento normativo, diseño técnico y especificación del catálogo de parámetros del PIP de bAuth

**Versión:** 1.1.0  
**Fecha:** 2026-07-20  
**Tipo de anexo:** B (normativo/industria) + C (justificación técnica) + A (SSOT del catálogo propuesto)  
**Respalda a:** [2.13 MANUAL-ATOMLANG v2.0 §5.2](../2.13_MANUAL-ATOMLANG-LENGUAJE-v2.0.md) — vocabularios cerrados y @bauth_config_param · [2.14 MANUAL-COMPOSICION §9](../2.14_MANUAL-COMPOSICION-ARBOL-v1.0.md) — parametrización en el árbol  
**Normas base:** NIST SP 800-162 §5 (PIP) · XACML 3.0 §7.2 (attribute retrieval) · ISO 27001:2022 A.5.15 (access control policy)  
**Estado de implementación:** L0 — concepto definido · **DDL del §5 REEMPLAZADO — ver decisión arquitectónica §1.1**

---

## §1.1 Decisión arquitectónica — DDL §5 REEMPLAZADO (2026-07-20)

> **`bauth_config_param` no es una tabla nueva.** El DDL propuesto en §5 de este documento queda **reemplazado** por tablas ya existentes en el inventario A.65.02.

**Decisión:** Los parámetros del PIP `@bauth_config_param` se almacenan en las tablas ya definidas del proyecto:

| `scope` del parámetro | Tabla destino | Código A.65.02 | Por qué |
|---|---|---|---|
| `global` | `bglobal.global_config` | T-114 | Parámetros del sistema cross-daemon (suelo: NIST, SIN Bolivia, límites de seguridad estándar). Aplica a todos los daemons y aplicaciones. |
| `tenant` | `bauth.idn_tenant_config` | T-009 | Parámetros específicos de la organización cliente (techo y piso que cada tenant define: `approval_threshold_*`, `moneda_legal`, `geo_drift_tolerance_km`). |

**Qué cambia:**
- La tabla `bauth.bauth_config_param` y la tabla `bauth.bauth_param_audit` del §5 **no se crearán**.
- La cadena de precedencia global → tenant del §5.1 **sigue vigente**, pero resuelta sobre T-114 → T-009.
- El catálogo de 20 parámetros (§3.2), la sintaxis `@bauth_config_param.*` (§4) y la gobernanza del ciclo de cambio (§6) **permanecen válidos** — solo cambia la implementación DDL.

**Qué NO cambia:**
- El compilador `atomc` sigue generando `{"type": "pip_ref", "source": "bauth_config_param", "key": "..."}` en el IR.
- El PDP sigue resolviendo `@bauth_config_param.<clave>` en runtime.
- Los errores ATOMC-E-042 y ATOMC-E-043 siguen siendo obligatorios.

---

## §1 Propósito y cómo citarlo

Este anexo define qué es `bauth_config_param`, por qué existe, qué valores deben vivir en él, y cómo debe implementarse (DDL propuesto, gobernanza, scope por tenant, referenciación desde AtomLang).

**Cómo citarlo:** `A.48 §N` (ej. "ver DDL propuesto: A.48 §5").

**Frontera:** este anexo define el **catálogo de parámetros del PIP** de bAuth. No define el PIP en sí (eso es el Context Plane, cubierto en los manuales de 2.05 y 1.10). No define los valores de configuración del daemon `bauth.service` (esos son TOML en `/etc/bauth/config.toml`). `bauth_config_param` son **valores de negocio parametrizables** que los Atoms referencian en sus condiciones.

**Por qué no se llama `bos_config_param`:** `bos` es el daemon del IAM Installer — un universo completamente diferente. `bauth_config_param` pertenece al schema de bAuth, es gobernado por bAuth, y no tiene ninguna relación con el daemon `bos`. El prefijo `bauth_` es la declaración de ownership del parámetro.

---

## §2 Fundamento normativo: el PIP como fuente de atributos

### §2.1 NIST SP 800-162 §5 — Policy Information Point

> *"The Policy Information Point (PIP) retrieves attributes from relevant sources that will be used for policy decision-making."*

El PIP es el componente que el PDP consulta para obtener los valores de los atributos usados en las condiciones de los Atoms. En bAuth, el PIP principal es el Context Plane (`bos.GetContext()`). Sin embargo, algunos atributos no son atributos de contexto dinámico (ej. `device.trusted` o `zone.security_level`) sino **valores de negocio configurables por el administrador** que dependen de la política de la organización, no del estado del sistema en un instante dado.

`bauth_config_param` es la fuente PIP para esta segunda categoría: valores configurables, no derivados del contexto de la solicitud.

**Distinción crítica PIP dinámico vs. PIP estático:**

| | Context Plane (PIP dinámico) | `bauth_config_param` (PIP estático) |
|---|---|---|
| Qué resuelve | Estado del sistema en el instante de la solicitud (`risk.score`, `zone.sensitivity`, `device.trusted`) | Valores de política de negocio configurados por el administrador (`approval_threshold`, `currency`, `max_sessions`) |
| Cuándo cambia | En cada solicitud (el valor puede ser diferente) | Cuando cambia una política de negocio (evento infrecuente, auditable) |
| Gobernanza | Infraestructura / Context Plane | Administrador de negocio con aprobación de compliance |
| Scope | Por solicitud (ctx_id) | Por tenant, por dominio, o global |
| Latencia de cambio | Instantánea (refleja estado actual) | Auditada y controlada (requiere ciclo de aprobación) |

### §2.2 XACML 3.0 §7.2 — Attribute retrieval

> *"There are several possible sources of attributes, including the access subject... the resource... or the environment. When these attributes are not contained in the request context, the PDP may retrieve them from an external source known as the Policy Information Point."*

XACML 3.0 formaliza que el PDP puede solicitar al PIP atributos adicionales no presentes en la solicitud original. En bAuth, cuando un Atom referencia `@bauth_config_param.approval_threshold_tier1`, el compilador `atomc` genera en el IR (Árbol Técnico) una referencia al PIP `bauth_config_param` con la clave `approval_threshold_tier1`. En runtime, el PDP invoca el PIP para resolver el valor antes de evaluar la Condition.

### §2.3 ISO 27001:2022 A.5.15 — Access control policy

> *"Rules for access control shall be established based on business and information security requirements."*

Los valores parametrizados en `bauth_config_param` son exactamente los umbrales, cantidades y configuraciones que implementan las "reglas de control de acceso basadas en los requisitos de negocio". Cambiar estos valores es un cambio de política de negocio — debe ser auditado, aprobado y trazado. No puede ser un cambio silencioso en el código fuente.

---

## §3 Qué valores DEBEN estar en `bauth_config_param`

### §3.1 Criterios de inclusión

Un valor DEBE vivir en `bauth_config_param` (y NUNCA como literal en un Atom) cuando cumple cualquiera de estos criterios:

| Criterio | Ejemplo | Por qué no puede ser literal |
|---|---|---|
| **Varía por tenant** | Umbral de aprobación de pago | Empresa A tiene límite de 10 000 BOB; empresa B de 50 000 BOB |
| **Varía por región/país** | Moneda legal | Bolivia: BOB · Argentina: ARS · Operaciones internacionales: USD |
| **Varía en el tiempo** | Límite de efectivo por normativa | SIN puede actualizar el umbral por decreto — cambiar un literal requiere recompilar el árbol |
| **Define una política de compliance** | Número máximo de sesiones concurrentes | NIST 800-63B puede revisar los límites — el valor no debe estar hardcodeado |
| **Es un umbral con unidades** | Monto en moneda | Un monto sin su moneda es un literal parcialmente ambiguo |
| **Tiene implicaciones legales** | Tipo impositivo | No puede estar hardcodeado en una regla de autorización — pertenece a la configuración del tenant |

### §3.2 Catálogo inicial de parámetros (propuesto)

| `param_key` | `data_type` | `scope` | Descripción | Ejemplo de valor |
|---|---|---|---|---|
| `approval_threshold_tier1` | `AMOUNT` | tenant | Monto máximo de aprobación simple (sin step-up) | `10000.00` |
| `approval_threshold_tier2` | `AMOUNT` | tenant | Monto máximo de aprobación doble (sin comité) | `50000.00` |
| `approval_threshold_tier3` | `AMOUNT` | tenant | Monto máximo para comité ejecutivo | `500000.00` |
| `sod_payment_threshold` | `AMOUNT` | tenant | Monto a partir del cual aplica verificación SoD en pagos | `5000.00` |
| `moneda_legal` | `CURRENCY` | tenant | Moneda legal del tenant | `BOB` |
| `moneda_operaciones_ext` | `CURRENCY` | tenant | Moneda para operaciones internacionales | `USD` |
| `max_descuento_tier1` | `NUMERIC_PERCENT` | tenant | Porcentaje máximo de descuento para Tier 1 | `15.0` |
| `max_descuento_tier2` | `NUMERIC_PERCENT` | tenant | Porcentaje máximo de descuento para Tier 2 | `100.0` |
| `max_sessions_per_user` | `INTEGER` | global | Máximo de sesiones concurrentes por usuario | `3` |
| `session_idle_timeout_min` | `INTEGER` | tenant | Timeout de inactividad en minutos | `30` |
| `session_absolute_expiry_min` | `INTEGER` | tenant | Expiración absoluta de sesión en minutos | `480` |
| `password_min_length` | `INTEGER` | global | Longitud mínima de contraseña (NIST 800-63B ≥ 15) | `15` |
| `lockout_threshold_attempts` | `INTEGER` | global | Número de intentos fallidos antes de bloqueo | `10` |
| `risk_score_low_max` | `NUMERIC_PERCENT` | global | Umbral máximo de risk score para clasificar como "bajo" | `0.50` |
| `risk_score_high_min` | `NUMERIC_PERCENT` | global | Umbral mínimo de risk score para clasificar como "alto" | `0.80` |
| `step_up_max_age_aal2` | `INTEGER` | global | Antigüedad máxima de sesión (segundos) para AAL2 step-up | `3600` |
| `step_up_max_age_aal3` | `INTEGER` | global | Antigüedad máxima de sesión (segundos) para AAL3 step-up | `900` |
| `geo_drift_tolerance_km` | `NUMERIC` | tenant | Tolerancia de deriva geográfica en km para session binding | `50.0` |
| `sin_umbral_facturacion` | `AMOUNT` | global | Umbral SIN para facturación electrónica obligatoria (RND SIN) | `1000.00` |
| `sin_moneda_facturacion` | `CURRENCY` | global | Moneda oficial SIN para facturación | `BOB` |

### §3.3 Lo que NO va en `bauth_config_param`

| Tipo de valor | Dónde va en cambio |
|---|---|
| Configuración del daemon (puerto, timeouts técnicos de red) | `/etc/bauth/config.toml` |
| Secretos y claves criptográficas | Vault PKI |
| Estado dinámico de la solicitud (risk score real, ubicación actual) | Context Plane (PIP dinámico) |
| Atributos del sujeto (tier del rol, método de auth usado) | `bauth.privilege_role` + Context Plane |
| Atributos del recurso (clasificación del modelo) | `bauth.privilege_resource` *(propuesta)* |

---

## §4 Referenciación desde AtomLang

### §4.1 Sintaxis de referencia

```yaml
condition:
  property_id: sale_order.amount_bob
  operator: ">"
  value: "@bauth_config_param.approval_threshold_tier1"
```

La sintaxis `@bauth_config_param.<param_key>` indica al compilador `atomc` que el valor es una referencia PIP, no un literal. En el IR (Árbol Técnico `bauth.privilege_atom_compiled` *(propuesto)*), se almacena como:

```json
{
  "condition": {
    "property_id": 42,
    "operator": ">",
    "value": {
      "type": "pip_ref",
      "source": "bauth_config_param",
      "key": "approval_threshold_tier1"
    }
  }
}
```

El PDP resuelve la referencia en runtime antes de evaluar el operador.

### §4.2 Cuándo el compilador fuerza el uso de referencias

El compilador `atomc` RECHAZA literales para campos de tipo AMOUNT y CURRENCY (errores ATOMC-E-042 y ATOMC-E-043). El administrador DEBE usar una referencia `@bauth_config_param.*` en su lugar:

```yaml
# ❌ ATOMC-E-042 — literal numérico en campo AMOUNT
value: 10000

# ❌ ATOMC-E-043 — código de moneda literal en campo CURRENCY
value: "BOB"

# ✅ CORRECTO — referencia PIP
value: "@bauth_config_param.approval_threshold_tier1"
value: "@bauth_config_param.moneda_legal"
```

**Código de error completo — ATOMC-E-042:**
```json
{
  "level": "error",
  "code": "ATOMC-E-042",
  "message": "valor literal numérico '10000' en campo de tipo AMOUNT — usar '@bauth_config_param.<clave>'",
  "norm_ref": "NIST SP 800-162 §5 · A.48 §3.1 criterio VARÍA-POR-TENANT"
}
```

---

## §5 DDL propuesto para `bauth_config_param` *(REEMPLAZADO — ver §1.1)*

> ⚠️ **SUPERSEDIDO por decisión arquitectónica §1.1 (2026-07-20).**  
> Las tablas `bauth.bauth_config_param` y `bauth.bauth_param_audit` definidas aquí **no se crearán**.  
> Los parámetros `scope='global'` van en `bglobal.global_config` (T-114) y los `scope='tenant'` van en `bauth.idn_tenant_config` (T-009).  
> Este §5 se conserva como **referencia del esquema de columnas y los datos seed** — sirve de guía para mapear los 20 parámetros del §3.2 a T-009 / T-114 durante la migración.

**Estado original:** L0 — diseñado, sin aplicar. La migración aplica directamente a T-009 y T-114.

```sql
-- ============================================================
-- bauth_config_param: catálogo de parámetros del PIP de bAuth
-- Schema: bauth_db.bauth (schema privado de bAuth)
-- Gobernanza: solo administradores con rol IAM_PARAM_ADMIN
-- Auditado: todas las modificaciones registradas en bauth_param_audit
-- ============================================================

CREATE TYPE bauth_param_scope AS ENUM ('global', 'tenant', 'domain');
CREATE TYPE bauth_param_data_type AS ENUM (
    'INTEGER', 'NUMERIC', 'NUMERIC_PERCENT',
    'AMOUNT', 'CURRENCY',
    'BOOLEAN', 'STRING_ENUM', 'STRING'
);

CREATE TABLE bauth.bauth_config_param (
    param_id      BIGSERIAL    PRIMARY KEY,
    param_key     TEXT         NOT NULL,
    data_type     bauth_param_data_type NOT NULL,
    scope         bauth_param_scope NOT NULL DEFAULT 'tenant',
    tenant_id     UUID         NULL,  -- NULL = aplica a todos los tenants (scope global)
    domain_code   TEXT         NULL,  -- NULL = no restringido a un dominio específico (D01, D06...)
    param_value   TEXT         NOT NULL,     -- almacenado como texto, casteado en runtime
    description   TEXT         NOT NULL,
    norm_ref      TEXT         NULL,         -- estándar o norma que define el rango válido
    valid_from    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    valid_until   TIMESTAMPTZ  NULL,         -- NULL = sin expiración
    is_active     BOOLEAN      NOT NULL DEFAULT true,
    created_by    TEXT         NOT NULL,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by    TEXT         NULL,
    updated_at    TIMESTAMPTZ  NULL,
    CONSTRAINT uq_param_scope UNIQUE (param_key, tenant_id, domain_code)
);

-- Índice para el hot-path del PDP: resolver @bauth_config_param.clave por tenant
CREATE INDEX idx_bauth_param_active ON bauth.bauth_config_param
    (param_key, tenant_id, is_active)
    WHERE is_active = true;

-- Tabla de auditoría WORM (solo INSERT — nunca UPDATE/DELETE)
CREATE TABLE bauth.bauth_param_audit (
    audit_id      BIGSERIAL    PRIMARY KEY,
    param_id      BIGINT       NOT NULL REFERENCES bauth.bauth_config_param,
    param_key     TEXT         NOT NULL,
    old_value     TEXT         NULL,
    new_value     TEXT         NOT NULL,
    changed_by    TEXT         NOT NULL,
    change_reason TEXT         NOT NULL,
    ctx_id        TEXT         NOT NULL,      -- SBOS-049: ctx_id obligatorio
    changed_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);
```

### §5.1 Resolución de parámetros — precedencia

Cuando el PDP resuelve `@bauth_config_param.approval_threshold_tier1` para un tenant específico, aplica la siguiente precedencia (de más específico a más general):

```
1. Parámetro de tenant (tenant_id = X, domain_code = D06)     → mayor precedencia
2. Parámetro de tenant (tenant_id = X, domain_code = NULL)
3. Parámetro global   (tenant_id = NULL, domain_code = NULL)  → menor precedencia
```

Si no existe ningún parámetro en la cadena de precedencia para la clave solicitada, el PDP retorna `Indeterminate` para el Atom que lo referencia (el atributo PIP no pudo resolverse — equivalente a PIP timeout en XACML).

### §5.2 Ejemplo de datos seed

```sql
-- Parámetros globales de seguridad
INSERT INTO bauth.bauth_config_param
  (param_key, data_type, scope, tenant_id, param_value, description, norm_ref, created_by)
VALUES
  ('max_sessions_per_user', 'INTEGER', 'global', NULL, '3',
   'Máximo de sesiones concurrentes por usuario en cualquier tenant',
   'NIST SP 800-63B §4.2.3', 'system_bootstrap'),
  ('password_min_length', 'INTEGER', 'global', NULL, '15',
   'Longitud mínima de contraseña — NIST requiere mínimo 15 caracteres para AAL2+',
   'NIST SP 800-63B §5.1.1.2 Rev.4', 'system_bootstrap'),
  ('risk_score_low_max', 'NUMERIC_PERCENT', 'global', NULL, '0.50',
   'Umbral máximo de risk score para clasificar sesión como bajo riesgo',
   'NIST SP 800-63B §4.1', 'system_bootstrap'),
  ('sin_umbral_facturacion', 'AMOUNT', 'global', NULL, '1000.00',
   'Umbral SIN Bolivia para facturación electrónica obligatoria',
   'SIN RND 102100000011', 'system_bootstrap'),
  ('sin_moneda_facturacion', 'CURRENCY', 'global', NULL, 'BOB',
   'Moneda oficial SIN para facturación electrónica en Bolivia',
   'SIN RND 102100000011', 'system_bootstrap');

-- Parámetros de tenant (ejemplo: tenant 'empresa_demo')
INSERT INTO bauth.bauth_config_param
  (param_key, data_type, scope, tenant_id, param_value, description, norm_ref, created_by)
VALUES
  ('approval_threshold_tier1', 'AMOUNT', 'tenant', 'TENANT_UUID_AQUI', '10000.00',
   'Monto máximo para aprobación simple sin step-up adicional',
   'Política interna Empresa Demo — Compliance 2026-01', 'admin_empresa_demo'),
  ('moneda_legal', 'CURRENCY', 'tenant', 'TENANT_UUID_AQUI', 'BOB',
   'Moneda legal del tenant para comparaciones de monto',
   'Ley 164 Bolivia', 'admin_empresa_demo');
```

---

## §6 Gobernanza del catálogo

### §6.1 Quién puede modificar `bauth_config_param`

| Acción | Rol requerido | Proceso |
|---|---|---|
| Crear parámetro global | `IAM_PARAM_ADMIN` (SKULL admin) | HITL — requiere aprobación del humano |
| Crear parámetro de tenant | `TENANT_PARAM_ADMIN` (admin del tenant) | Flujo de aprobación interno del tenant |
| Modificar valor de parámetro | Mismo rol que el de creación | Registrado en `bauth_param_audit` con `change_reason` obligatorio |
| Desactivar parámetro (`is_active = false`) | Mismo rol que el de creación | Solo si ningún Atom activo lo referencia — verificar antes |
| Eliminar parámetro | PROHIBIDO | `bauth_config_param` es append-only para el historial activo; desactivar en cambio |

### §6.2 Ciclo de cambio de un parámetro

Un cambio de valor en `bauth_config_param` (ej. subir el umbral de `approval_threshold_tier1` de 10 000 a 15 000 BOB por una nueva política de compliance) sigue este ciclo:

1. Área de Negocio / Compliance propone el cambio con justificación y norma de respaldo
2. Administrador del tenant verifica que el nuevo valor no crea conflictos con otros Atoms
3. Se crea una nueva entrada en `bauth_config_param` con `valid_from` = fecha de vigencia (o se actualiza el valor con registro en `bauth_param_audit`)
4. El PDP comienza a usar el nuevo valor en la próxima resolución (sin reinicio del daemon)
5. Los Atoms existentes que referencian `@bauth_config_param.approval_threshold_tier1` automáticamente usarán el nuevo valor en la próxima evaluación

**Ventaja sobre literales hardcodeados:** el cambio de política no requiere recompilar el árbol de Atoms, ni ejecutar `atomc publish`, ni reiniciar `bauth.service`. Solo requiere actualizar el valor en `bauth_config_param` y el PDP lo resuelve en el siguiente ciclo de evaluación.

### §6.3 Verificación de integridad referencial

Antes de desactivar un parámetro, el compilador `atomc` debe verificar que ningún Atom activo en `bauth.privilege_atom_compiled` *(propuesto)* lo referencia:

```sql
-- Verificar referencias activas a un parámetro antes de desactivarlo
SELECT c.policy_id, c.compiled_at
FROM bauth.privilege_atom_compiled c    -- tabla propuesta (ver A.46 §6.1)
WHERE c.is_active = true
  AND c.ir_json::text ILIKE '%"key": "approval_threshold_tier1"%';
```

Si la consulta retorna resultados, el parámetro no puede desactivarse hasta que los Atoms que lo referencian sean actualizados y recompilados.

---

## §7 Estado de implementación

| Componente | Estado | Observación |
|---|---|---|
| Concepto `bauth_config_param` definido | ✅ L0 | Este anexo es la definición canónica |
| DDL `bauth_config_param` + `bauth_param_audit` | ~~diseñado~~ **REEMPLAZADO** | Ver §1.1 — los datos van en T-009 y T-114 (A.65.02). No se crea tabla separada. |
| T-009 `bauth.idn_tenant_config` como PIP tenant | ✅ Definido en A.65.02 | Parámetros `scope='tenant'`: approval thresholds, moneda, geo_drift, session timeouts |
| T-114 `bglobal.global_config` como PIP global | ✅ Definido en A.65.02 | Parámetros `scope='global'`: NIST, SIN Bolivia, max_sessions, risk thresholds |
| Catálogo inicial de parámetros (20 entries) | ✅ L0 | §3.2 de este anexo — mapeo a T-009/T-114 pendiente de migración HITL |
| Resolución PIP en evaluador (PDP nativo) | ❌ L0 | Requiere `atomc` implementado primero |
| Referenciación `@bauth_config_param.*` en `atomc` parser | ❌ L0 | Requiere `atomc` implementado |
| ATOMC-E-042/043 enforcement | ❌ L0 | Requiere `atomc` implementado |
| Migración de datos: Atoms existentes con literales → referencias | ⬜ Pendiente HITL | ~45 gaps en D1 solo (ver A.47 §6) |

---

## §8 Mapa anexo → manuales

| Sección | Respalda a | Qué sección |
|---|---|---|
| §2 (fundamento normativo PIP) | 2.13 §4.5, 2.14 §9 | Valor referenciado en Condition |
| §3 (qué valores van en bauth_config_param) | 2.13 §6, 2.14 §9 | Parametrización en el árbol |
| §4 (referenciación desde AtomLang) | 2.13 §4.5 | Constructo valor_ref |
| §5 (DDL propuesto) | DDLs compartidos | Migración pendiente HITL |
| §6 (gobernanza) | 2.14 §11 | Ciclo de mantenimiento — cambio de política |
| §7 (estado) | 2.13 §8, 2.14 §12 | Estado del arte — brechas P1/P2 |

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.1.0 | 2026-07-20 | **Decisión arquitectónica:** DDL §5 (`bauth_config_param` + `bauth_param_audit`) REEMPLAZADO. Los 20 parámetros del catálogo se almacenan en tablas ya definidas: `scope='tenant'` → T-009 `bauth.idn_tenant_config`; `scope='global'` → T-114 `bglobal.global_config`. Añadido §1.1 con tabla de decisión. §5 y §7 actualizados. Cabecera de estado actualizada. El concepto PIP, el catálogo y la sintaxis `@bauth_config_param.*` permanecen sin cambio. |
| 1.0.2 | 2026-07-14 | Actualización de cabecera: referencia a 2.13 v2.0. Sin cambios en el cuerpo. |
| 1.0.1 | 2026-07-13 | Correcciones por revisión: reemplazadas referencias `bos_*` inventadas — `bos_atom_compiled` → `bauth.privilege_atom_compiled *(propuesto)*` en consulta SQL §2 y en inventario §3.3; `bos_rol` → `bauth.privilege_role`; `bos_resource_catalog` → `bauth.privilege_resource *(propuesta)*`. Nota: las apariciones de `bos_config_param` en §1 (párrafo justificativo) y en el historial de v1.0.0 se conservan intencionalmente — son el texto canónico que justifica por qué NO se usa ese nombre. |
| 1.0.0 | 2026-07-13 | Primera edición. Define `bauth_config_param` como fuente PIP para valores de negocio configurables: 20 parámetros iniciales en §3.2 (AMOUNT, CURRENCY, INTEGER, NUMERIC_PERCENT, BOOLEAN), DDL completo con `bauth_param_audit` WORM, cadena de precedencia global→tenant→domain, gobernanza con rol `IAM_PARAM_ADMIN`, ciclo de cambio sin recompilación del árbol. Normas base: NIST SP 800-162 §5 (PIP authority), XACML 3.0 §7.2 (attribute retrieval), ISO 27001:2022 A.5.15 (access control policy basada en requisitos de negocio). Naming `bauth_config_param` (no `bos_config_param`) justificado en §1 párrafo final. Estado L0 — sin aplicar. |
