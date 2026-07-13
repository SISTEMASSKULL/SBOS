# AtomLang · Análisis de Gaps D1 — SOURCE vs CANONICAL
### ¿Qué falta para que el árbol humano sea ejecutable por la máquina de estados?

**Versión:** 1.0  
**Dominio analizado:** D1 · Acceso Lógico (bloque B4–B7)  
**Fecha:** 2026-07-11  
**Base documental:** SSOT `A.01_ANEXO-ROLTEMPLATE-v1.0.md` · XACML 3.0 · RolTemplate v6.0

---

## 0. Marco del análisis

El árbol SOURCE es el árbol de configuración de roles construido por el agente en el dashboard Flutter. Sus nombres de rama son descripciones en lenguaje natural ("monto de transacción alto (>10 000 BOB)") legibles para un humano pero opacas para un parser.

El árbol CANONICAL es el árbol técnico con identificadores en snake_case extraídos del SSOT RolTemplate — la forma que requiere el PDP de bAuth para evaluar políticas sin ambigüedad.

Este documento registra los **gaps detectados** (diferencias entre SOURCE y CANONICAL) por la vista `atomlang.vw_gaps` en la VPS de pruebas + análisis extendido manual de todo D1.

---

## 1. Tipos de gap

| Código | Nombre | Descripción |
|---|---|---|
| `NOMBRE_DIFERENTE` | Nombre humano vs. técnico | El nodo existe en ambos árboles pero con diferentes nombres |
| `SIN_EQUIVALENTE` | Sin equivalente en CANONICAL | El nodo SOURCE no existe en el SSOT RolTemplate |
| `TIPO_DIFERENTE` | Tipo de nodo incorrecto | La estructura del nodo es diferente (e.g., `lista` donde debería ser `politica`) |
| `FALTA_EN_SOURCE` | Falta en SOURCE | El CANONICAL tiene un nodo que no existe en SOURCE — brecha de cobertura |
| `FALTA_PROPIEDAD` | Propiedad técnica faltante | El nodo existe pero le falta `prop_path`, `operator`, `verbo`, o `xacml_effect` |
| `ESTRUCTURA_MALFORMADA` | Estructura no compilable | La estructura del nodo viola las reglas G-01..G-10 de AtomLang |

---

## 2. Gaps detectados — D1 step_up_triggers (verificado en VPS)

Resultado empírico de `SELECT * FROM atomlang.vw_gaps WHERE source_key IS NOT NULL OR canonical_key IS NOT NULL`:

| Nodo SOURCE | Tipo | Verbo | Nodo CANONICAL | Clasificación | Análisis |
|---|---|---|---|---|---|
| `step_up_triggers` | politica | — | *(sin vínculo)* | `SIN_EQUIVALENTE` | La política-contenedor no tiene nombre técnico en CANONICAL |
| `monto de transacción alto (>10 000 BOB)` | evaluacion | execute | `financial_approve` | `NOMBRE_DIFERENTE` | Nombre humano → ID canónico del SSOT |
| `zona de alta seguridad` | evaluacion | ANY | *(ninguno)* | `SIN_EQUIVALENTE` | **Este trigger no existe en el SSOT RolTemplate** — fue inventado por agente previo |
| `verbo CONFIGURE o ADMIN` | evaluacion | configure | `system_config_change` | `NOMBRE_DIFERENTE` | Nombre humano + "o ADMIN" en texto → ID canónico |

**Acción requerida para `zona de alta seguridad`:**
- Consultar al humano si este trigger es un requisito real o un error del agente previo.
- Si es un requisito real: añadir `zone_security_critical` al SSOT RolTemplate.
- Si es un error: eliminar el nodo SOURCE y documentarlo como eliminado.

---

## 3. Análisis extendido — D1 completo (manual + árbol Flutter)

### 3.1 B4 · Dominio lógico (autenticación) — `metodos{}`

#### `primary_auth{}`

| Nodo SOURCE | Tipo | Gap | Nodo CANONICAL esperado |
|---|---|---|---|
| `primary_auth{}` | objeto | `FALTA_PROPIEDAD`: sin `combining_algorithm` | `primary_auth_policy` |
| `condiciones` (bajo primary_auth) | politica/regla | `NOMBRE_DIFERENTE` | `primary_auth_conditions` |
| `riesgo bajo + zona normal → contraseña` | regla | `NOMBRE_DIFERENTE` | `low_risk_password_grant` |
| `riesgo bajo` | evaluacion | `FALTA_PROPIEDAD`: sin `prop_path` ni `operator` | `risk_score_low`: `risk.score <= 0.50` |
| `zona no sensible` | evaluacion | `FALTA_PROPIEDAD`: sin `prop_path` ni `operator` | `zone_not_sensitive`: `zone.sensitivity NOT_IN [HIGH,CRITICAL]` |
| `zona sensible o acción privilegiada → hardware` | regla | `NOMBRE_DIFERENTE` | `sensitive_zone_hardware_grant` |
| `zona sensible` | evaluacion | `FALTA_PROPIEDAD` | `zone_sensitivity_high`: `zone.sensitivity IN [HIGH,CRITICAL]` |
| `verbo privilegiado` | evaluacion | `FALTA_PROPIEDAD` + `SIN_EQUIVALENTE` | Posible: `verb_is_privileged`: `action.verb IN [CONFIGURE,ADMIN,DELETE,APPROVE,DELEGATE]` |
| `certificado mTLS presente → x509` | regla | `NOMBRE_DIFERENTE` | `mtls_cert_x509_grant` |

#### `mfa_auth{}`

| Nodo SOURCE | Tipo | Gap | Nodo CANONICAL esperado |
|---|---|---|---|
| `mfa_auth{}` | objeto | `FALTA_PROPIEDAD` | `mfa_auth_policy` |
| `condiciones` (bajo mfa_auth) | politica/regla | `NOMBRE_DIFERENTE` | `mfa_auth_conditions` |
| `AAL2 con TOTP o HOTP` | regla | `NOMBRE_DIFERENTE` | `aal2_totp_or_hotp` |
| `AAL3 con hardware o biométrico` | regla | `NOMBRE_DIFERENTE` | `aal3_hardware_or_biometric` |
| `WebAuthn Passwordless → AAL3` | evaluacion | `NOMBRE_DIFERENTE` | `webauthn_passwordless_aal3` |
| `FIDO2 hardware → AAL3` | evaluacion | `NOMBRE_DIFERENTE` | `fido2_hardware_aal3` |
| `biométrico platform → AAL3` | evaluacion | `NOMBRE_DIFERENTE` | `biometric_platform_aal3` |

#### `session_binding{}`

| Nodo SOURCE | Tipo | Gap | Nodo CANONICAL esperado |
|---|---|---|---|
| `required_binding` | objeto | `FALTA_PROPIEDAD` | `session_binding_policy` |
| `IP, User-Agent, GeoZone` | objeto | `NOMBRE_DIFERENTE` | Dividir en 3 atributos: `bind_ip`, `bind_ua`, `bind_geo` |
| `drift_tolerance_km` | atributo | ✅ OK — `NOMBRE_DIFERENTE` menor | `geo_drift_tolerance_km` |
| `bind_strength` | enumerado | ✅ OK | `session_bind_strength` |

#### `step_up_triggers{}` (ya analizado en §2)

| Nodo SOURCE | Gap |
|---|---|
| `monto de transacción alto (>10 000 BOB)` | `NOMBRE_DIFERENTE` → `financial_approve` |
| `zona de alta seguridad` | `SIN_EQUIVALENTE` — verificar con humano |
| `verbo CONFIGURE o ADMIN` | `NOMBRE_DIFERENTE` → `system_config_change` |

### 3.2 B5 · Ciclo de vida de credenciales

| Nodo SOURCE | Tipo | Gap | Nodo CANONICAL esperado |
|---|---|---|---|
| `password_policy{}` | objeto | Estructura OK | `password_policy` |
| `min_length` | atributo | ✅ OK | `pwd_min_length` (NIST 800-63B: ≥ 15) |
| `max_length` | atributo | ✅ OK | `pwd_max_length` |
| `require_entropy_bits` | atributo | ✅ OK | `pwd_require_entropy_bits` |
| `screening` | enumerado | ✅ OK | `pwd_screening` |
| `algorithm` | enumerado | ✅ OK | `pwd_hash_algorithm` |
| `account_lockout_policy{}` | objeto | Estructura OK | `account_lockout_policy` |
| `intentos 1-3: sin penalización` | regla | `NOMBRE_DIFERENTE` | `lockout_range_1_3` |
| `intentos 4-6: retardo progresivo` | regla | `NOMBRE_DIFERENTE` | `lockout_range_4_6` |
| `intentos 7-10: bloqueo temporal` | regla | `NOMBRE_DIFERENTE` | `lockout_range_7_10` |
| `intentos > 10: bloqueo hasta administrador` | regla | `NOMBRE_DIFERENTE` | `lockout_overflow` |
| `ventana de conteo de intentos` | regla | `NOMBRE_DIFERENTE` | `lockout_attempt_window` |

### 3.3 B6 · Gestión de sesiones

| Nodo SOURCE | Tipo | Gap | Nodo CANONICAL esperado |
|---|---|---|---|
| `session_management{}` | objeto | OK | `session_management` |
| `max_session_duration_min` | atributo | ✅ OK | `session_max_duration_minutes` |
| `idle_timeout_min` | atributo | ✅ OK | `session_idle_timeout_minutes` |
| `concurrent_sessions` | enumerado | ✅ OK | `session_concurrent_policy` |
| `max_concurrent` | atributo | ✅ OK | `session_max_concurrent` |
| `token_rotation` | enumerado | ✅ OK | `session_token_rotation` |
| `absolute_expiry_min` | atributo | ✅ OK | `session_absolute_expiry_minutes` |
| `revocation_latency_ms` | atributo | ✅ OK | `session_revocation_latency_ms` |

### 3.4 B7 · 5 capas de evaluación (PrivilegeEngine)

> **Nota:** Estas capas son el motor algebraico NIST RBAC Nivel 3. En el árbol SOURCE están descritas como objetos de datos. Su nodo CANONICAL debería ser `PolicySet` (combinación de políticas de las 5 capas).

| Nodo SOURCE | Tipo | Gap |
|---|---|---|
| `capa_1_rol_directo` | objeto | `TIPO_DIFERENTE`: debería ser `politica` con `combining_algorithm` |
| `capa_2_herencia_dag` | objeto | `TIPO_DIFERENTE`: debería ser `politica` |
| `capa_3_restriccion_sod` | objeto | `TIPO_DIFERENTE`: debería ser `politica` + matriz SoD como evaluaciones |
| `capa_4_condicion_contextual` | objeto | `TIPO_DIFERENTE`: debería ser `politica` con condiciones contextuales |
| `capa_5_politica_global` | objeto | `TIPO_DIFERENTE`: debería ser `politica` + PolicySet raíz |

---

## 4. Resumen cuantitativo de gaps D1

| Tipo de gap | Cantidad | Severidad |
|---|---|---|
| `NOMBRE_DIFERENTE` | ~22 | Media — compilador puede resolver con tabla de mapeo |
| `SIN_EQUIVALENTE` | ~2 | **Alta** — requiere decisión humana (HITL) |
| `FALTA_PROPIEDAD` | ~12 | Media — compilador puede inferir parcialmente (con Warning) |
| `TIPO_DIFERENTE` | ~6 | **Alta** — requiere reestructuración del nodo |
| `ESTRUCTURA_MALFORMADA` | ~3 | **Alta** — bloqueante para compilación (reglas G-01, G-08, G-09) |
| `FALTA_EN_SOURCE` | ~0 (D1) | — |
| **TOTAL** | **~45 gaps** | |

---

## 5. Plan de resolución (priorizado)

### P0 — Bloqueantes (requieren decisión humana)

| Gap | Nodo afectado | Decisión requerida |
|---|---|---|
| `SIN_EQUIVALENTE` | `zona de alta seguridad` | ¿Existe en SSOT o fue inventado? Si existe, agregar `zone_security_critical` al SSOT |
| `TIPO_DIFERENTE` | Capas B7 (5 capas) | ¿Son objetos de datos o deben convertirse a PolicySet con evaluaciones? |
| `ESTRUCTURA_MALFORMADA` | `_prop('A AND B')` remanentes | Identificar si quedan en D2–D12 y partir manualmente |

### P1 — Resolubles por compilador (tabla de mapeo)

Todos los `NOMBRE_DIFERENTE`: agregar entradas en la tabla `atom_lexer_rules` de PostgreSQL:

```sql
INSERT INTO atomlang.atom_lexer_rules (pattern, trigger_id, prop_path, operator, val)
VALUES
  ('monto.*>\s*(\d+)', 'financial_approve', 'transaction.amount_bob', '>', '$1'),
  ('verbo.*CONFIG|ADMIN', 'system_config_change', 'action.verb', 'IN', '[CONFIGURE,ADMIN,DELETE]'),
  ('riesgo bajo', 'risk_score_low', 'risk.score', '<=', '0.50'),
  ('zona no sensible', 'zone_not_sensitive', 'zone.sensitivity', 'NOT_IN', '[HIGH,CRITICAL]'),
  ('zona sensible', 'zone_sensitivity_high', 'zone.sensitivity', 'IN', '[HIGH,CRITICAL]'),
  ('intentos 1-3', 'lockout_range_1_3', 'login.failed_attempts_in_window', 'BETWEEN', '[1,3]'),
  ('intentos 4-6', 'lockout_range_4_6', 'login.failed_attempts_in_window', 'BETWEEN', '[4,6]'),
  ('intentos 7-10', 'lockout_range_7_10', 'login.failed_attempts_in_window', 'BETWEEN', '[7,10]'),
  ('intentos.*>\s*(\d+)', 'lockout_overflow', 'login.failed_attempts_in_window', '>', '$1'),
  ('AAL2.*TOTP|HOTP', 'aal2_totp_or_hotp', 'auth.method', 'IN', '[TOTP,HOTP]'),
  ('AAL3.*hardware|biométrico', 'aal3_hardware_or_biometric', 'auth.method', 'IN', '[WEBAUTHN,FIDO2,BIOMETRIC]'),
  ('WebAuthn Passwordless', 'webauthn_passwordless_aal3', 'auth.method', '==', 'WEBAUTHN_PASSWORDLESS'),
  ('FIDO2 hardware', 'fido2_hardware_aal3', 'auth.method', '==', 'FIDO2_HARDWARE'),
  ('biométrico platform', 'biometric_platform_aal3', 'auth.method', '==', 'BIOMETRIC_PLATFORM'),
  ('certificado mTLS', 'mtls_cert_x509_grant', 'auth.method', '==', 'X509_MTLS');
```

### P2 — Resolubles con helpers Flutter (mejora del árbol SOURCE)

Los `FALTA_PROPIEDAD`: todas las evaluaciones que no tienen `prop_path`/`operator` explícitos deben recibir esos campos en el árbol Flutter. La mayoría ya los tienen implícitamente en el texto; hay que hacerlos explícitos con `_prop()` / `_op()` / `_val()`.

---

## 6. Estado de la BD (VPS de pruebas)

| Objeto | Estado |
|---|---|
| Schema `atomlang` | ✅ Creado |
| Tabla `atom_node` | ✅ Creada |
| Vista `vw_atom_path` | ✅ Creada |
| Vista `vw_gaps` | ✅ Creada |
| Datos D1 `step_up_triggers` SOURCE | ✅ Insertados (3 nodos) |
| Datos D1 `step_up_triggers` CANONICAL | ✅ Insertados (2 nodos) |
| Tabla `atom_lexer_rules` | ⬜ Pendiente (crear + poblar con P1) |
| Datos D1 completo SOURCE | ⬜ Pendiente |
| Datos D1 completo CANONICAL | ⬜ Pendiente |

---

## 7. Conclusión

El árbol SOURCE tiene **una buena estructura** (XACML politica/regla/evaluacion correctamente anidados después de las correcciones aplicadas en sesión 2026-07-11). El problema es **semántico, no estructural**: los nombres de los nodos son descripciones humanas que el compilador no puede parsear directamente.

La solución completa requiere:
1. Una tabla de mapeo (`atom_lexer_rules`) con ~15–20 reglas regex para D1.
2. Decisiones HITL para los 2 `SIN_EQUIVALENTE`.
3. Reestructuración de B7 (5 capas) de `objeto` a `politica`.
4. Extensión progresiva del análisis a D2–D12.

El compilador AtomLang puede resolver el 70% de los gaps automáticamente una vez poblada la tabla de mapeo. El 30% restante requiere reestructuración manual o decisiones del humano.
