# BAUTH-GAP-VISION-vs-INVENTARIO.md — ¿El inventario cubre la visión?

**Fecha:** 2026-06-24 · **Versión:** 2.0 — corregida con feedback del humano
**Propósito:** Evaluar si las 155 tablas del inventario actual son suficientes para cumplir
la promesa del Context Plane documentada en `SBOS-CONTEXT-PLANE-VISION.md`.

---

## LA PROMESA

```
El desarrollador hace una sola llamada: ctx := bos.GetContext()
y recibe identidad, dispositivo, ubicación, horario, nivel de confianza,
empresa, sucursal, sesión laboral y recursos físicos en un solo objeto.
```

Para cumplir esta promesa, el sistema necesita tres capacidades:

| Capacidad | Qué significa | Quién lo resuelve |
|-----------|------|------|
| **ALMACENAR** | Tener los datos en tablas normalizadas, pobladas con seeds reales | **bAuth DDL** — eso es lo que estamos desarrollando ahora: modernizar y robustecer la DDL |
| **RESOLVER** | Evaluar los 12 dominios en orden determinista, en <5ms, y ensamblar un contexto unificado | **RolTemplate** — ya contiene todas las configuraciones y políticas por dominio. **bAuth PrivilegeEngine** — tiene el motor de análisis y evaluación de políticas. |
| **EXFILTRAR** | Entregar el contexto al desarrollador vía SDK/API sin que tenga que entender los 12 dominios | **banexus → bhnexus → bAuth** — la cadena de daemons Nexus resuelve la entrega al desarrollador |

---

## ANÁLISIS POR DIMENSIÓN DEL CONTEXTO

### Dimensión 1 — IDENTIDAD (`"user": "juan"`)

| Necesidad | ¿Cubierta? | Tablas | Gap | Quién lo resuelve |
|-----------|:---:|------|------|------|
| Quién es el usuario | ✅ | `idn_user_template` (T-170 a migrar) | Migración pendiente | bAuth — `idn_user_template` |
| Cómo se autenticó | ✅ | `ath_method` (T-065) + `ath_binding` (T-126) | `ath_binding` pendiente de migrar | bAuth — `ath_binding` + `ath_method` |
| Con qué nivel de garantía (AAL) | ✅ | `idn_tier_policy` (T-061) + `idn_role_template` (T-060) | OK | bAuth PrivilegeEngine — evalúa LoA desde el RolTemplate |
| Métodos MFA enrolados | ✅ | `ath_mfa_enrollment` (T-123 a migrar) | Migración pendiente | bAuth — `ath_mfa_enrollment` |
| Estado de sesión actual | ✅ | `ses_context` (T-110 a migrar) | Migración pendiente | bAuth — `ses_context` |

**Conclusión Identidad:** 🟡 Cubierta en diseño. 4 de 5 tablas pendientes de migración. **No se requieren tablas nuevas.**

### Dimensión 2 — DISPOSITIVO (`"trust": "biometric"`)

| Necesidad | ¿Cubierta? | Tablas | Gap | Quién lo resuelve |
|-----------|:---:|------|------|------|
| Desde qué dispositivo | ✅ | `net_device` (T-185 a migrar) | Migración pendiente | bAuth — `net_device` |
| Postura de seguridad | 🟡 | `net_device.metadata` JSONB | La metadata se almacena, el score lo calcula el motor | **Motor en bAuth** — el PrivilegeEngine evalúa la postura como parte de la evaluación de políticas |
| Scoring de confianza | 🟡 | No requiere tabla propia | El score es un CÁLCULO del motor, no un dato almacenado | **Motor en bAuth** — combina señales de: método auth + dispositivo + ubicación + comportamiento. El resultado se expone en el contexto, no se persiste. |
| Verificación continua | 🟡 | No requiere tabla propia | Es una FUNCIÓN del daemon, no una tabla | **banexus + bAuth** — banexus monitorea el dispositivo, bAuth re-evalúa las políticas cada 300s (ZTA). |
| Nivel de confianza unificado | 🟡 | No requiere tabla propia | Es el resultado del motor de evaluación | **bAuth + banexus** — el PrivilegeEngine emite el trust_level como parte del contexto resuelto |

**Conclusión Dispositivo:** 🟡 La dimensión está cubierta por el motor de bAuth y banexus. Las tablas almacenan los datos; los daemons calculan el score. **No se requieren tablas nuevas para scoring de confianza.** Sí se requiere migrar `net_device`.

### Dimensión 3 — UBICACIÓN (`"branch": "lapaz"`)

| Necesidad | ¿Cubierta? | Tablas | Gap | Quién lo resuelve |
|-----------|:---:|------|------|------|
| País / Región | ✅ | `global_country` (T-021) + `geo_timezone` (T-023) | OK | bGlobal |
| Geo-fence por sucursal | 🟡 | `fis_location.coordinates` + `geo_fence_radius_m` (T-070) | Datos OK. Evaluación la hace el motor. | **Dominio Geoespacial (D6)** — las tablas `geo_trust_tier` y `geo_velocity_policy` se incorporan como políticas del dominio D6 |
| Confianza por ubicación | 🟡 | — | Se resuelve con políticas D6 | **Dominio Geoespacial (D6)** — `ath_policy_d6` contendrá las políticas de confianza por ubicación (BeyondCorp: HIGH/MEDIUM/LOW) |
| Viaje imposible | 🟡 | — | Se resuelve con políticas D4 + D6 | **Dominio Temporal (D4) + Dominio Geoespacial (D6)** — `ath_policy_d4` + `ath_policy_d6` evalúan velocidad entre logins consecutivos |

**Conclusión Ubicación:** 🟡 Catálogos OK. Las políticas de evaluación geoespacial se incorporan como `ath_policy_d6`. **No se requieren tablas de runtime adicionales.** El motor de bAuth evalúa las políticas del dominio D6 en cada request.

### Dimensión 4 — HORARIO (dentro del turno)

| Necesidad | ¿Cubierta? | Tablas | Gap | Quién lo resuelve |
|-----------|:---:|------|------|------|
| Días laborales | ✅ | `cal_schedule` (T-035) | OK | bCalendar |
| Turnos por día | ✅ | `cal_schedule.shifts` JSONB | OK | bCalendar |
| Feriados | ✅ | `cal_holiday` (T-034) | OK | bCalendar |
| Horas extra | 🟡 | — | Se resuelve con políticas D4 | **Dominio Temporal (D4)** — `ath_policy_d4` contiene políticas de overtime: autorización por rol, tasa multiplicadora, max horas/día |
| Descansos | 🟡 | — | Se resuelve con políticas D4 | **Dominio Temporal (D4)** — `ath_policy_d4` contiene políticas de breaks: lunch requerido, duración, ventana |
| ¿Está en su turno AHORA? | 🟡 | No requiere tabla propia | Es una EVALUACIÓN del daemon, no una tabla | **bAuth es un demonio** — controla constantemente los contextos y sus eventos. Evalúa `NOW()` contra `cal_schedule` + `cal_holiday` + políticas D4 en cada ciclo del reconcile loop (60s). El resultado se expone en el contexto, no se persiste. |

**Conclusión Horario:** 🟡 Datos estáticos en bCalendar OK. La evaluación temporal en runtime la hace el demonio bAuth. Las políticas de overtime y breaks se incorporan como `ath_policy_d4`. **No se requieren tablas de runtime adicionales.**

### Dimensión 5 — EMPRESA Y SUCURSAL (`"tenant": "empresa_a", "branch": "lapaz"`)

| Necesidad | ¿Cubierta? | Tablas | Gap | Quién lo resuelve |
|-----------|:---:|------|------|------|
| Tenant | ✅ | `idn_tenant` (T-010) | OK | bAuth |
| Empresa | 🟡 | `org_empresa` (T-175 a migrar) | Migración pendiente | bAuth — `org_empresa` |
| Sucursal | 🟡 | `org_sucursal` (T-176 a migrar) | Migración pendiente | bAuth — `org_sucursal` |
| POS lógico | 🟡 | `org_pos_logico` (T-177 a migrar) | Migración pendiente | bAuth — `org_pos_logico` |
| Scope GLOBAL/REGIONAL/BRANCH/PERSONAL | 🟡 | — | Se resuelve en la DDL y políticas D1 | **Justamente debemos ajustar la DDL para que bAuth pueda administrarlo.** `zone_record_rule` (T-312) + `ath_policy_d1` definen reglas de scope. La jerarquía GLOBAL→REGIONAL→BRANCH→PERSONAL se implementa en `org_empresa` → `org_sucursal` → `org_pos_logico`. |

**Conclusión Empresa/Sucursal:** 🟡 Las 3 tablas necesitan migración. El scope se implementa con las tablas ya planificadas. **No se requieren tablas adicionales.** Ajustar las existentes para que bAuth pueda resolver scope.

### Dimensión 6 — PERMISOS (`"permissions": ["inventory.read", "inventory.write"]`)

| Necesidad | ¿Cubierta? | Tablas | Gap | Quién lo resuelve |
|-----------|:---:|------|------|------|
| Átomos de permiso | ✅ | `privilege_atom` (T-044) + `privilege_verb` (T-041) | OK | PrivilegeEngine |
| Roles asignados | 🟡 | `idn_user_role` (T-171 a migrar) | Migración pendiente | bAuth |
| BitMask efectiva | ✅ | `idn_user_template.mask_eff_hex` (T-170) | Calculado por PrivilegeEngine | bAuth PrivilegeEngine |
| Evaluación en runtime | ✅ | `privilege_atom_audit` (T-048) | WORM OK | bAuth |
| Resolución de scope | 🟡 | — | Se resuelve combinando D1 + D4 | **Dominio Temporal (D4) + Políticas del Dominio Lógico (D1)** — `zone_record_rule` (T-312) + `ath_policy_d1` + `ath_policy_d4` definen el alcance de cada permiso. |

**Conclusión Permisos:** 🟡 Motor de privilegios sólido. Scope se resuelve combinando políticas D1 + D4. **No se requieren tablas adicionales.**

---

## VEREDICTO FINAL: ¿EL INVENTARIO CUBRE LA VISIÓN?

### Respuesta: SÍ. Las 155 tablas del inventario cubren la visión.

**Los gaps que identifiqué inicialmente no eran gaps reales — eran malentendidos sobre la arquitectura:**

| Lo que creí que faltaba | Realidad |
|------|------|
| "Ensamblador de contexto" — `ctx_assembly_config` | **No es una tabla.** Es lo que hace el RolTemplate + PrivilegeEngine. Justamente estamos modernizando la DDL para que bAuth tenga todos los datos que necesita para ensamblar contexto. |
| "Evaluador de confianza" — `trust_score_config` | **No es una tabla.** Es una función del motor de bAuth. Calcula el score combinando señales de ath_method + net_device + geo + ses_risk. El resultado se expone en el contexto. |
| "Evaluador temporal runtime" | **No es una tabla.** bAuth es un demonio que controla constantemente los contextos y sus eventos. Evalúa horarios en cada ciclo del reconcile loop. |
| "Resolvedor de scope" — `ctx_scope_resolver` | **No es una tabla separada.** Se implementa en las tablas que ya tenemos planificadas: `org_empresa` → `org_sucursal` → `org_pos_logico` + `zone_record_rule` + `ath_policy_d1`. |
| "SDK clientes" — `sdk_client`, `sdk_api_key` | **Fase 2.** No corresponde a la Fase 1. Cuando lleguemos a Fase 2, se diseñarán. |

### Lo que REALMENTE falta para cumplir la visión:

| # | Qué falta | No es crear tablas nuevas — es | Prioridad |
|---|-----------|------|:---:|
| 1 | **Migrar las 46 tablas del DDL antiguo** | Los datos que bAuth necesita para resolver contexto están en el DDL antiguo sin migrar | 🔴 |
| 2 | **Crear las 12 `ath_policy_d*`** | Cada dominio necesita su colección de políticas pre-diseñadas para que el RolTemplate tenga ingredientes seleccionables | 🔴 |
| 3 | **Crear las 12 `ath_config_d*`** | Cada dominio necesita sus configuraciones por defecto | 🔴 |
| 4 | **Crear las 12 `idn_role_d*`** | Templates de rol por dominio para que la herramienta de merge pueda conjugarlos | 🔴 |
| 5 | **Ajustar `org_empresa` + `org_sucursal` + `org_pos_logico`** | Para que bAuth pueda resolver scope (GLOBAL→REGIONAL→BRANCH→PERSONAL) | 🔴 |
| 6 | **Crear `zone_record_rule` + `zone_field_restriction` + `zone_button_rule`** | Para que el scope se materialice en reglas SQL, campos ocultos y botones condicionales | 🔴 |
| 7 | **Crear `ath_auth_flow` + `ath_auth_flow_method`** | Para que el RolTemplate pueda orquestar flujos de autenticación compuestos | 🔴 |
| 8 | **Crear `ath_step_up_rule`** | Para que el motor pueda elevar LoA condicionalmente (RFC 9470) | 🔴 |
| 9 | **Migrar `ses_context` + `ses_context_switch`** | Para que bAuth tenga sesiones conscientes del contexto (SBOS-049) | 🔴 |

**Todo esto ya está en el inventario.** Son las 46 migraciones + 57 creaciones que tenemos planificadas. **Nada de esto es nuevo.**

---

## CORRECCIÓN AL INVENTARIO

Las "12 tablas adicionales" que propuse en la versión 1.0 de este documento (T-500 a T-522) **no se necesitan.** El ensamblaje, la resolución y la exfiltración del contexto son responsabilidades de los daemons (bAuth, banexus, bhnexus) y del motor de políticas (PrivilegeEngine), no de tablas adicionales.

**El inventario maestro (BAUTH-INVENTARIO-TABLAS-DECISION.md) se mantiene en 155 tablas.** No se agregan las 12 que propuse aquí.

---

## RESUMEN: QUÉ HACE CADA CAPA

| Capa | Responsable | Entrada | Salida |
|------|------------|------|------|
| **ALMACENAR** | 155 tablas DDL | Seeds poblados con datos reales | Datos normalizados, accesibles vía SQL |
| **RESOLVER** | RolTemplate + PrivilegeEngine (bAuth) | Datos de las 155 tablas + request en runtime | Contexto unificado con evaluación de 12 dominios en <5ms |
| **EXFILTRAR** | banexus → bhnexus → bAuth | Contexto resuelto | `bos.GetContext()` → JSON con identidad, dispositivo, ubicación, horario, confianza, empresa, sucursal, permisos |

---

*Análisis corregido 2026-06-24. Versión 2.0 con feedback del humano.*
*Conclusión: El inventario SÍ cubre la visión. No se requieren tablas adicionales para el Context Plane.*
*Los gaps reales están en la migración pendiente, no en la arquitectura.*
