# BAUTH-ARQUITECTURA-ATOMICA-FINAL — Documento Consolidado
## Arquitectura Unificada de Átomos para bAuth · 2026-06-30 (rev. 2026-07-01)

**Versión:** 1.1.0 · **Autor:** sbos-coordinador · **Estado:** ARQUITECTURA APROBADA PARA IMPLEMENTACIÓN

**Changelog v1.1.0 (2026-07-01):**
- §2.4: `idn_atributo` añadida como tercera tabla de identidad; nuevo §2.4.1 con catálogos bglobal verificados en producción (196 países, 125 idiomas, 319 zonas horarias, 143 monedas)
- §7.2: Actualizado MANTIENEN con `idn_atributo` y bglobal.*
- D00 Tablas operativas: fila `idn_atributo` con referencia a `BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0.md`
- D00 Estándares normativos: añadidos ISO 3166-1:2020, ISO 639-1/2/3, IETF BCP 47, IANA tzdata, ITU-T E.164, ISO 4217, ISO/IEC 29115:2013
- D00 Átomos REGLA: validaciones internacionales; 5812/5814/5815/5816 usan `display_format=TAX_XX/E164/ID_XX` dinámico por país; 5823/5826 ENUM con NONE/STUDENT; 5827/5828 referenciados contra bglobal; nota de internacionalización
- D00 Cobertura de templates: expandida de 11 a 36 filas cubriendo los 16 bloques UserTemplate v6.0 y 14 bloques RolTemplate v6.0; leyenda de almacenamiento (columna/idn_atributo/FK)

**Documentos fuente que este documento REEMPLAZA y CONSOLIDA:**
- `BAUTH-PLAN-CANONIZACION-TABLAS.md` — Plan de canonización
- `BAUTH-AUDITORIA-DDL-POLITICAS.md` — Auditoría de solapamientos
- `BAUTH-AUDITORIA-DDL-FRAMEWORK.md` — Análisis del framework
- `BAUTH-AUDITORIA-REGLAS-POLITICAS.md` — Cadena políticas→reglas→templates
- `BAUTH-PROPUESTA-ATOMIZACION-REGLAS.md` — Propuesta de atomización
- `BAUTH-EVALUACION-VIABILIDAD-ATOMIZACION.md` — Evaluación de viabilidad

**Estándares verificados:** ISO 27001:2022 A.8.9/A.5.1 · NIST SP 800-53 CM-3 · PCI DSS 4.0 6.5.1/10.5 · SOC 2 CC8.1

---

## PARTE 1 — EL ÁTOMO

### 1.1 Definición

> **Un átomo es la unidad mínima e indivisible de identidad, permiso, regla o método**
> **en un sistema de control de acceso. Representa un hecho atómico que puede ser**
> **asignado, evaluado, auditado y revocado de forma independiente.**

Un átomo se define mediante **N coordenadas dimensionales** que lo posicionan de forma única
en el espacio de control. En bAuth usamos 4 coordenadas, pero el modelo admite cualquier
número de dimensiones según la complejidad del dominio:

```
                    d₁  .  d₂   .  d₃   .  d₄    .  ...  .  dₙ
                    ───    ────    ────    ────            ────
                      │      │       │       │               │
                      │      │       │       │               └── Dimensión N
                      │      │       │       └── Dimensión 4: verbo/operación
                      │      │       └── Dimensión 3: agrupación funcional
                      │      └── Dimensión 2: sistema/contexto
                      └── Dimensión 1: dominio/ámbito
```

**En bAuth, las 4 dimensiones son:** `dominio . aplicación . módulo . verbo`

Cada combinación de valores dimensionales produce UN átomo. Cada átomo ocupa UNA posición
en un vector de bits (BitMask). La presencia o ausencia de ese bit determina si el átomo
está activo para un rol o usuario. El valor asociado al átomo (si aplica) define el
parámetro concreto de evaluación.

### 1.2 Propiedades universales de un átomo

Todo átomo, independientemente de su tipo, posee estas propiedades:

| Propiedad | Descripción |
|-----------|------------|
| **Coordenadas** | N valores dimensionales que lo identifican unívocamente en el espacio de control |
| **Posición** | Índice en el vector de bits (BitMask). La posición es estable y no se reutiliza. |
| **Tipo** | Clasificación que determina su comportamiento en evaluación: binario, con valor, con estado |
| **Validación** | Reglas que definen qué valores son aceptables para este átomo (formato, rango, patrón) |
| **Trazabilidad** | Origen (estándar, documento, autor), ciclo de vida (draft→proposed→active→deprecated), auditoría |

### 1.3 Principio de asignación

Un átomo no otorga privilegios por sí mismo. Es un **hecho declarativo**.
El privilegio surge de la **asignación** de ese átomo a un rol, y del rol a un usuario:

```
átomo (d.a.m.v) ─── asignado a ───► rol ─── heredado por ───► usuario
     │                                  │                         │
     │  "Existe la operación            │  "El rol CAJERO        │  "jperez PUEDE
     │   CREATE en ventas/tryton"        │   incluye este átomo"   │   ejecutar CREATE
     │                                  │                         │   en ventas/tryton"
     │                                  │                         │
     └──────────────────────────────────┴─────────────────────────┘
                      La asignación es transitiva: átomo → rol → usuario
```

### 1.4 Tipos de átomo según su comportamiento

El TIPO de un átomo no está en sus coordenadas dimensionales, sino en su **verbo**.
El verbo define la naturaleza de lo que el átomo representa:

| Tipo | El verbo es... | Evaluación | Ejemplo |
|------|---------------|------------|---------|
| **ACCIÓN** | Una operación atómica | Binaria: ¿está el bit activo? → ALLOW/DENY | `CREATE`, `READ`, `DELETE`, `VIEW`, `ENVIAR` |
| **REGLA** | Un parámetro con valor | Comparativa: ¿el valor asignado cumple la condición del contexto? | `max_daily`, `min_length`, `ttl_max`, `vpn_required` |
| **MÉTODO** | Un procedimiento de verificación | Con estado: ¿está disponible, es requerido, es alternativa en este contexto? | `PASSWORD`, `TOTP`, `WEBAUTHN_PWDLESS`, `PASSKEY` |
| **IDENTIDAD** | Una propiedad del sujeto | Binaria o con valor: ¿pertenece a este ámbito? ¿cuál es su valor? | `CAJERO`, `EMPRESA`, `PERSONA`, `SUCURSAL`, `nombre`, `nit`, `email` |

El verbo es la **dimensión semántica** del átomo. Las demás dimensiones lo ubican
en el espacio de control. El verbo define **qué significa** ese punto en el espacio.

### 1.5 Universalidad del modelo

El modelo atómico NO está atado a bAuth. Es aplicable a cualquier sistema que requiera
control de acceso, configuración o políticas con trazabilidad dimensional:

| Dominio de aplicación | Dimensiones posibles | Ejemplo de átomo |
|----------------------|---------------------|-----------------|
| **IAM / RBAC** (bAuth) | dominio . app . módulo . verbo | `D3.tryton.ventas.CREATE` |
| **Kubernetes RBAC** | apiGroup . resource . namespace . verb | `apps.deployments.prod.create` |
| **AWS IAM** | service . resource . region . action | `s3.bucket.us-east-1.GetObject` |
| **Google Zanzibar** | namespace . object . relation . user | `doc.invoice-123.editor.jperez` |
| **Firewall** | zone . protocol . port . action | `dmz.tcp.443.allow` |
| **ERP / SAP** | module . transaction . org_unit . activity | `FI.FB01.1000.post` |

En todos los casos, el principio es el mismo: **coordenadas dimensionales que identifican
unívocamente un hecho atómico en un espacio de control, asignable, evaluable y auditable.**

### 1.6 Estructura de almacenamiento (AtomBitMask 64-bit en bAuth)

La implementación concreta en bAuth empaqueta 8 componentes en 64 bits para
evaluación O(1) en hardware:

```
┌─────────────────────── AtomBitMask(u64) ───────────────────────────┐
│                                                                     │
│  CONTEXTUAL MASK (32 bits superiores)    LOGICAL MASK (32 bits inf) │
│  ╔══════╦══════╦═══════╦═══════════╗    ╔══════╦══════╦═════╦══════╗ │
│  ║device║domain║  app  ║  group    ║    ║trust ║token ║blk  ║verb  ║ │
│  ║ 8b   ║ 4b   ║ 9b    ║  11b      ║    ║ 3b   ║bind  ║anch ║24b   ║ │
│  ╚══════╩══════╩═══════╩═══════════╝    ╚══════╩══════╩═════╩══════╝ │
│                                                                     │
│  ROLBITMASK (N-bit one-hot):                                        │
│  [0][1][0][1][1]...[1][0][1]   — acceso O(1) al bit N              │
│   42 43 44 50 ... 2000 3001    — posición = índice en privilege_atom │
└─────────────────────────────────────────────────────────────────────┘
```

---

## PARTE 2 — LAS TABLAS

### 2.1 Tablas centrales (3)

| Tabla | Propósito | Columnas clave |
|-------|-----------|---------------|
| **privilege_atom** | Catálogo unificado de TODOS los átomos | `domain_code`, `app_code`, `group_code`, `verb_code`, `atom_type`, `atom_position`, `validation`, `standard_ref` |
| **privilege_role_atom** | Asignación de átomos a roles | `role_id`, `atom_id`, `allowed`, `value`, `customized` |
| **privilege_user_atom** | Asignación directa usuario↔átomo (sobrescritura) | `user_uuid`, `atom_id`, `allowed`, `value`, `reason` |

### 2.2 Tablas de apoyo — Construcción del árbol (4)

| Tabla | Catálogo de | Cardinalidad | Ejemplos |
|-------|-----------|:---:|------|
| **privilege_domain** | Dominios D1-D12 | 12 fijos | D1=Lógico, D2=Físico, D3=Financiero... |
| **privilege_application** | Aplicaciones del ecosistema | ~15 | tryton, bauth, superset, mattermost, nexus, kong... |
| **privilege_group** | Módulos/grupos funcionales | ~50 | ventas, financial, password, method, session, org... |
| **privilege_verb** | Verbos/acciones | ~200 | CREATE, READ, DELETE, max_daily, PASSWORD, TOTP, CAJERO... |

### 2.3 Tablas de referencia documental (3)

| Tabla | Propósito | ¿Runtime? |
|-------|-----------|:---:|
| **cfg_policy_library** | Biblioteca unificada de 9,142 normas (NIST, ISO, PCI, FIDO2...) | ❌ Solo referencia y consulta admin |
| **framework_raw** | 16 documentos JSON fuente, inmutables | ❌ Solo carga inicial |
| **cfg_key_translation** | Traducción 221+ claves EN→ES | ❌ Solo build time |

### 2.4 Tablas de identidad (3)

| Tabla | Propósito |
|-------|-----------|
| **idn_role_template** | Agrupación visual de átomos para el admin. NO almacena reglas — solo organiza la presentación de los átomos asignados al rol. |
| **idn_user_template** | Usuario + roles asignados + RolBitMask precomputado. |
| **idn_atributo** | Tabla genérica extensible de atributos de identidad (emails, teléfonos, documentos, direcciones, perfil profesional). Reemplaza `org_contacto`, `org_documento`, `org_direccion`. Extensible sin DDL — solo insertar filas. Cubre entidades D00-D12. Campos clave: `display_format` (COUNTRY_CODE / LOCALE_BCP47 / TIMEZONE_IANA / E164 / ID_XX / TAX_XX / ...) y `validation_policy JSONB`. Ver `BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0.md` §12 para catálogo completo. |

### 2.4.1 Catálogos globales — Schema `bglobal` (verificado en SBOS_db, 2026-07-01)

Los catálogos de referencia global viven en el schema `bglobal`. Son la fuente de verdad
para países, idiomas, zonas horarias y monedas. Ningún agente los hardcodea.

| Tabla | Registros | Estándar | Uso en `idn_atributo` |
|-------|:---------:|---------|----------------------|
| `bglobal.global_country` | **196** | ISO 3166-1 alpha-2/3 · ITU-T E.164 · UN M.49 | `display_format='COUNTRY_CODE'` → `iso_alpha2` como FK implícita |
| `bglobal.global_language` | **125** | ISO 639-1/2/3 · IETF BCP 47 | `display_format='LOCALE_BCP47'` → `locale` como FK implícita |
| `bglobal.geo_timezone` | **319** | IANA Timezone Database (tzdata) | `display_format='TIMEZONE_IANA'` → `timezone_id` como FK implícita |
| `bglobal.global_currency` | **143** | ISO 4217 alpha-3/numeric | `display_format='MONEY'` + `idn_tenant_currencies.currency_code` |

### 2.5 Tablas operativas por dominio (se mantienen)

| Dominio | Prefijo | Tablas | Propósito |
|---------|---------|--------|-----------|
| D1 — Lógico | `log_` `zone_` | log_zone, zone_application_map, zone_record_rule, zone_field_restriction, zone_button_rule, zone_data_policy | Zonas lógicas, apps, menús |
| D2 — Físico | `fis_` | fis_access_zone, fis_controller, fis_device, fis_location, fis_zone_method_requirement, fis_emergency_config | Control de acceso físico |
| D3 — Financiero | `fin_` | fin_approval_chain, fin_decision_matrix, fin_sod_rule, fin_document_operation | Aprobaciones, SoD |
| D4 — Temporal | `cal_` (bcalendar) | cal_calendar, cal_event, cal_holiday, cal_schedule, cal_alarm | Calendario, horarios |
| D5 — Biométrico | — | (absorbido en privilege_atom tipo REGLA) | Parámetros biométricos |
| D6 — Geoespacial | `geo_` | geo_fence, geo_trust_tier, geo_velocity_policy, geo_location_log | Geocercas, confianza |
| D7 — Red | `net_` | net_device, net_ztna_policy | Dispositivos de red, ZTNA |
| D8 — Contexto | `ses_` | ses_context, ses_context_switch, ses_ses_risk_policy, ses_caep_config | Sesiones, riesgo |
| D9 — Credenciales | `ath_` | ath_method, ath_login_attempt, ath_mfa_enrollment, ath_binding, ath_password_history, ath_recovery_method, etc. | Métodos, MFA, recovery |
| D10 — Delegación | `dlg_` | dlg_delegation | Delegación temporal |
| D11 — Auditoría | `aud_` | aud_event, aud_review, aud_compliance_map, aud_ghost_account | Eventos WORM, compliance |
| D12 — Blockchain | `blk_` | blk_anchor, blk_merkle_batch, blk_merkle_leaf, blk_account, blk_reconciliation | Anclaje, liquidación |

### 2.6 Tablas de ecosistema compartido (bglobal + bcalendar)

| Schema | Tablas | Propósito |
|--------|--------|-----------|
| **bglobal** | global_config, global_country, global_language, global_currency, menu_item, menu_context, menu_item_atom, geo_timezone | Configuración y datos compartidos por todos los daemons |
| **bcalendar** | cal_calendar, cal_event, cal_holiday, cal_schedule, cal_alarm, cal_notification_log, cal_overtime_policy, cal_break_policy, cal_fiscal_year | Subsistema de calendario |

---

## PARTE 3 — MAPEO DE TEMPLATES A ÁTOMOS

### 3.1 RolTemplate: 14 secciones → átomos

| Sección | Dominio | App | Módulo | Verbos (ejemplos) | Tipo |
|---------|:---:|------|--------|--------|:---:|
| logical_access | D1 | tryton, superset... | ventas, dashboard... | CREATE, READ, VIEW... | ACCIÓN |
| logical_access | D1 | bauth | logical | scope, data_classification | REGLA |
| physical_access | D2 | nexus | edificio | acceder | ACCIÓN |
| physical_access | D2 | bauth | physical | max_security_zone, requires_escort | REGLA |
| financial_limits | D3 | tryton | facturacion | emitir | ACCIÓN |
| financial_limits | D3 | bauth | financial | max_daily, requires_dual, currency | REGLA |
| temporal_schedule | D4 | bauth | temporal | schedule_id, allow_overtime | REGLA |
| biometric | D5 | bauth | biometric | fmr_threshold, liveness_required | REGLA |
| geospatial | D6 | bauth | geo | allowed_countries, cross_border | REGLA |
| network | D7 | bauth | network | vpn_required, mtls_required | REGLA |
| session_context | D8 | bauth | session | ttl_max, inactivity_timeout | REGLA |
| credential_policy | D9 | bauth | password | min_length, hibp_enabled | REGLA |
| credential_policy | D9 | bauth | method | PASSWORD, TOTP, PASSKEY... | MÉTODO |
| delegation | D10 | bauth | delegation | enabled, max_duration_days | REGLA |
| audit | D11 | bauth | audit | level, retention_days | REGLA |
| blockchain | D12 | bauth | blockchain | enabled, variant, anchor_freq | REGLA |
| sync_metadata | — | bauth | sync | kc_composite_role, sync_status | REGLA |
| conflict_management | — | bauth | sod | validation_config | REGLA |

### 3.2 UserTemplate: 15 secciones → átomos

| Sección | Dominio | App | Módulo | Verbos (ejemplos) | Tipo |
|---------|:---:|------|--------|--------|:---:|
| identity | D1 | org | rol, bDomain, bSubDomain, pos | CAJERO, SKULL, NORTE | IDENTIDAD |
| identity | D1 | bauth | identity | username, email, account_type | REGLA |
| personal_info | D1 | bauth | personal | first_name, document_type, dob | REGLA |
| professional_info | D1 | bauth | professional | department, job_title, employee_id | REGLA |
| roles_assignments | — | bauth | role | assigned, primary | (FK a átomos IDENTIDAD) |
| keycloak_creds | D9 | bauth | credential | enrolled_methods, aal_level | MÉTODO/REGLA |
| physical_creds | D2 | bauth | physical_cred | access_cards, biometric_templates | REGLA |
| device_registry | D9 | bauth | device | bound, max_devices | IDENTIDAD/REGLA |
| session_state | D8 | bauth | session | max_concurrent, ttl_seconds | REGLA |
| location_profile | D6 | bauth | location | country_code, latitude, timezone | REGLA |
| temporal_profile | D4 | bauth | work | schedule_days, start_hour | REGLA |
| network_profile | D7 | bauth | network_profile | vpn_profile_id, allowed_ips | REGLA |
| audit_profile | D11 | bauth | audit_profile | enabled, retention_days | REGLA |
| external_services | — | bauth | external | linked_services, federation | REGLA |
| compliance | — | bauth | compliance | data_classification, gdpr | REGLA |
| lifecycle | — | bauth | lifecycle | status, created_at, expires_at | REGLA |

---

## PARTE 4 — FLUJO DE EVALUACIÓN (RUNTIME)

```
bauth.access.evaluate(atom_slug, user_uuid, context)
  │
  ├── 1. RESOLVER ÁTOMO
  │   atom = privilege_atom.resolve(atom_slug)
  │   position = atom.atom_position
  │
  ├── 2. FASTPATH (<0.5ns)
  │   if !user.rol_bitmask[position]:
  │       return DENY                          ← ni siquiera tiene el bit
  │
  ├── 3. LEER VALOR (si aplica)
  │   value = privilege_role_atom.get(user.role, atom.id).value
  │
  ├── 4. EVALUAR SEGÚN TIPO
  │   match atom.atom_type:
  │       ACTION   → ALLOW                     ← binario
  │       IDENTITY → ALLOW                     ← binario
  │       RULE     → comparar(value, context)  ← numérico/texto/bool
  │       METHOD   → verificar_estado(value, auth_context) ← required/available/alternative
  │
  └── 5. RETORNAR VEREDICTO
      ALLOW / DENY / STEP_UP
```

---

## PARTE 4.1 — VENTAJA DE RENDIMIENTO: TODO PASA POR FASTPATH

### 4.1.1 El problema del modelo actual

En el modelo actual, solo los átomos de ACCIÓN se benefician del FastPath O(1).
Las reglas y políticas se evalúan mediante un proceso multi-paso que involucra
múltiples consultas SQL y conversiones por cada evaluación.

### 4.1.2 Comparativa de rendimiento

```
═══════════════════════════════════════════════════════════════════════
MODELO ACTUAL — ÁTOMOS DE ACCIÓN (ya es rápido)
═══════════════════════════════════════════════════════════════════════

bauth.access.evaluate("factura.emitir", "jperez")
  │
  ├── 1. Resolver atom_slug → atom_position           ~0.1ms  (SQL: SELECT atom_position FROM privilege_atom)
  ├── 2. Cargar RolBitMask del usuario                ~0.5ms  (SQL: SELECT rol_bitmask_base64 FROM idn_user_template)
  ├── 3. FastPath: rol_bitmask[position]?             <0.5ns   (memoria: acceso directo al bit)
  │
  └── TOTAL: ~0.6ms


═══════════════════════════════════════════════════════════════════════
MODELO ACTUAL — REGLAS Y POLÍTICAS (lento, multi-paso)
═══════════════════════════════════════════════════════════════════════

bauth.policy.domain.evaluate("D3", context)
  │
  ├── 1. Cargar TODAS las políticas de D3             ~2ms     (SQL: SELECT * FROM ath_policy_d3 WHERE is_active=true)
  ├── 2. Convertir cada política a PolicyRule         ~0.5ms   (ath_converter: 62 rule types)
  ├── 3. Evaluar UNA por UNA contra el contexto       ~1ms     (PolicyEngine: eval_condition + eval_rule)
  │
  └── TOTAL: ~3.5ms


═══════════════════════════════════════════════════════════════════════
MODELO NUEVO — ÁTOMOS UNIFICADOS (todo es FastPath)
═══════════════════════════════════════════════════════════════════════

bauth.access.evaluate("D3.bauth.financial.max_daily", "jperez", context)
  │
  ├── 1. Resolver atom_slug → atom_position           <0.5ns   (catálogo en memoria, sin SQL)
  ├── 2. FastPath: rol_bitmask[2000]?                 <0.5ns   (memoria: acceso directo al bit)
  │       → bit = 1 ✅
  │
  ├── 3. Es REGLA → leer valor asignado al rol        ~0.5ms   (1 SQL por PK compuesta, 1 sola fila)
  │       → value = 100000
  │
  ├── 4. Comparar: request_amount ≤ value?            <0.5ns   (CPU: operación aritmética)
  │       → 5000 ≤ 100000 → true
  │
  └── TOTAL: ~0.5ms
```

### 4.1.3 Tabla comparativa

| Tipo de átomo | Modelo actual | Modelo nuevo | Mejora |
|:---|:---:|:---:|:---:|
| **ACCIÓN** (permiso) | ~0.6ms | <0.5ns | **~1000x más rápido** |
| **REGLA** (política con valor) | ~3.5ms (ath_loader + converter + evaluate) | ~0.5ms (FastPath + 1 SQL) | **~7x más rápido** |
| **MÉTODO** (autenticación) | ~3ms (consulta ath_method + evalúa contra RoleTemplate JSONB) | ~0.5ms (FastPath + 1 SQL) | **~6x más rápido** |
| **IDENTIDAD** (rol/empresa/sucursal) | ~0.6ms | <0.5ns | **~1000x más rápido** |

### 4.1.4 Por qué es más rápido

| Factor | Modelo actual | Modelo nuevo |
|--------|-------------|-------------|
| **Catálogo de átomos** | 1 SQL por evaluación (`SELECT FROM privilege_atom WHERE atom_slug=...`) | En memoria desde el arranque. Resolución <0.5ns. |
| **Políticas del dominio** | Carga TODAS las activas (`SELECT * FROM ath_policy_dN WHERE is_active=true`) por cada evaluación | No aplica. Cada átomo es independiente. |
| **Conversión de políticas** | 62 rule types en `ath_converter` se ejecutan por cada política cargada | No aplica. El tipo ya está definido en el átomo. |
| **Evaluación** | Itera sobre todas las políticas del dominio, evalúa condición por condición | Una sola comparación directa contra el valor del átomo. |
| **Cantidad de SQL** | 3-5 consultas por evaluación | 0-1 consultas (el catálogo está en memoria, el BitMask también) |

### 4.1.5 El principio fundamental

> **El RolBitMask ya SABE todo lo que el usuario puede hacer.**
> **No hay que preguntarle a ninguna tabla de políticas en runtime.**
> **El bit YA está calculado desde el momento en que se asignó el átomo al rol.**

```
privilege_role_atom:
  rol CAJERO ↔ átomo max_daily (#2000), value = 100000

En ESE momento:
  → RolBitMask[CAJERO][2000] = 1       (se activa el bit)
  → RolBitMask[jperez] hereda de CAJERO (herencia DAG por OR)

En runtime:
  → rol_bitmask[2000]? → 1 → leer value → 100000 → comparar → ALLOW
  → CERO consultas a tablas de políticas.
  → CERO conversiones de reglas.
  → CERO iteraciones sobre políticas del dominio.
```

---

## PARTE 4.2 — ADMINISTRACIÓN DEL CTX_ID EN EL MODELO ATÓMICO

### 4.2.1 ¿Qué es el ctx_id?

El ctx_id (Context Plane, SBOS-049) es el identificador universal de sesión en el SBOS.
Representa el contexto completo de una operación: quién, dónde, desde qué dispositivo,
con qué nivel de confianza, bajo qué empresa y sucursal.

En el modelo atómico, el ctx_id es la **activación temporal de un conjunto de átomos
de IDENTIDAD para una sesión específica**.

### 4.2.2 Componentes del ctx_id como átomos

```
ctx_id = uuidv7 + CONJUNTO DE ÁTOMOS DE IDENTIDAD ACTIVOS

  USUARIO:   jperez
  │
  ├── D1.org.tenant.SKULL              → átomo IDENTIDAD #4300
  ├── D1.org.bDomain.skull-corp         → átomo IDENTIDAD #4100 (tipo=EMPRESA)
  ├── D1.org.bSubDomain.norte           → átomo IDENTIDAD #4101 (tipo=SUCURSAL)
  ├── D1.org.pos.caja-01               → átomo IDENTIDAD #4200 (tipo=CAJA)
  ├── D1.org.rol.CAJERO                → átomo IDENTIDAD #4000
  │
  ├── D9.bauth.device.MOBILE-A1        → átomo IDENTIDAD (dispositivo vinculado)
  │
  └── CONTEXTO DE SESIÓN (no son átomos, son ESTADO):
      ├── trust_level: 85               → derivado de device attestation
      ├── loa: 2                        → AAL2 (PASSWORD + TOTP)
      ├── risk_score: 12                → calculado por RiskEngine
      ├── session_ttl: 28800            → del átomo REGLA D8.bauth.session.ttl_max
      └── created_at, expires_at        → timestamps de sesión
```

### 4.2.3 Átomos de IDENTIDAD — Flexibles, no monolíticos

Cada átomo de IDENTIDAD es autodescriptivo. No hay columnas fijas en la tabla
para "nombre", "nit", "dirección". Cada propiedad es un VERBO con formato y validación:

```
privilege_atom (átomos de IDENTIDAD para bDomain):
┌────────────────────────────────────────────────────────────────────┐
│ d.a.m.v                          │ tipo   │ formato  │ validación  │
├──────────────────────────────────┼────────┼──────────┼─────────────┤
│ D1.bauth.bDomain_type            │ REGLA  │ ENUM     │ EMPRESA, PERSONA, HOGAR, DESARROLLADOR │
│ D1.bauth.bDomain_name            │ REGLA  │ TEXT     │ len: 2-128 │
│ D1.bauth.bDomain_nit             │ REGLA  │ TEXT     │ ^\d{8,12}$ │
│ D1.bauth.bDomain_ci              │ REGLA  │ TEXT     │ ^\d{6,8}-\w{2}$ │
│ D1.bauth.bDomain_email           │ REGLA  │ TEXT     │ format: email │
│ D1.bauth.bDomain_phone           │ REGLA  │ TEXT     │ digits: 7-15 │
│ D1.bauth.bDomain_address         │ REGLA  │ TEXT     │ len: 5-256 │
│ D1.bauth.bDomain_first_name      │ REGLA  │ TEXT     │ len: 2-64  │
│ D1.bauth.bDomain_last_name       │ REGLA  │ TEXT     │ len: 2-64  │
│ D1.bauth.bDomain_date_of_birth   │ REGLA  │ DATE     │ YYYY-MM-DD │
│ D1.bauth.bDomain_website         │ REGLA  │ TEXT     │ format: url │
│ D1.bauth.bDomain_logo_url        │ REGLA  │ TEXT     │ format: url │
│ ...                              │ ...    │ ...      │ ...         │
└──────────────────────────────────┴────────┴──────────┴─────────────┘

ASIGNACIÓN (privilege_role_atom):
  bDomain "skull-corp" (tipo=EMPRESA):
    ├── bDomain_type = EMPRESA
    ├── bDomain_name = "SKULL Corp"
    ├── bDomain_nit  = "123456789"
    ├── bDomain_email = "contacto@skull.bo"
    └── bDomain_ci   = (no asignado — no aplica a EMPRESA)

  bDomain "jperez" (tipo=PERSONA):
    ├── bDomain_type = PERSONA
    ├── bDomain_first_name = "Juan"
    ├── bDomain_last_name = "Perez"
    ├── bDomain_ci = "1234567-LP"
    ├── bDomain_date_of_birth = "1990-01-15"
    └── bDomain_nit = (no asignado — no aplica a PERSONA)
```

**Ventaja:** Agregar un nuevo campo de identidad (ej: `passport_number`, `tax_id`, `license_plate`)
es crear un átomo. Sin ALTER TABLE. Sin migración. El árbol del Dashboard muestra automáticamente
los átomos disponibles según el `bDomain_type`.

### 4.2.4 Flujo de vida del ctx_id

```
CREACIÓN (BOS → bAuth):
  BOS recibe solicitud de autenticación
  → Resuelve tenant (skull o external, mismo código)
  → Crea ctx_id = UUIDv7
  → Envía a bAuth para registro
  bAuth: almacena en ses_context + Redis DB0

VALIDACIÓN:
  │
  ├── 1. Recibir ctx_id en el request (header W3C traceparent)
  ├── 2. Buscar en Redis DB0 → si existe y no expiró → OK
  ├── 3. Si no está en Redis → buscar en ses_context (PostgreSQL)
  ├── 4. Verificar que el usuario aún posee los átomos de IDENTIDAD del ctx_id
  │       → fastpath: rol_bitmask[ID_ATOM_ROL] = 1 ?
  │       → ¿sigue en la misma empresa/sucursal?
  ├── 5. Verificar que el dispositivo sigue siendo confiable
  │       → fastpath: rol_bitmask[ID_ATOM_DEVICE] = 1 ?
  │       → device_attestation_log.trust_score ≥ threshold ?
  └── 6. Retornar: válido/expirado/inválido + trust_level + loa

PROMOCIÓN (bauth.ctx.promote) — Step-Up RFC 9470
  │
  ├── 1. Recibir ctx_id + nuevo método de autenticación (ej: PASSKEY)
  ├── 2. Validar que el usuario tiene el átomo de MÉTODO requerido
  │       → fastpath: rol_bitmask[ID_PASSKEY] = 1 ?
  │       → ¿state=required para el contexto actual?
  ├── 3. Autenticar con el nuevo método (AAL3)
  ├── 4. Actualizar ctx_id: loa = 3, trust_level += step_up_bonus
  ├── 5. Actualizar ses_context + Redis
  └── 6. Emitir CAEP event: assurance-level-change

INVALIDACIÓN (bauth.ctx.invalidate)
  │
  ├── 1. Recibir ctx_id
  ├── 2. Marcar ses_context.state = 'EXPIRED'
  ├── 3. Eliminar de Redis DB0
  ├── 4. Registrar en aud_event: session_revoked
  └── 5. Emitir CAEP event: session-revoked

PROPAGACIÓN (bauth.ctx.propagate / bauth.ctx.transfer)
  │
  ├── 1. Recibir ctx_id + from_device + to_device + método (QR/NFC/BLE/UWB)
  ├── 2. Verificar from_device tiene el átomo de IDENTIDAD activo
  ├── 3. Verificar to_device está registrado (átomo de IDENTIDAD en privilege_user_atom)
  ├── 4. Generar challenge + firma del dispositivo origen
  ├── 5. Crear nuevo ctx_id para to_device con los MISMOS átomos de IDENTIDAD
  ├── 6. Registrar en ctx_transfer_log
  └── 7. Emitir CAEP event: context-transferred
```

### 4.2.5 DOS TIPOS DE TENANT, UN SOLO DUEÑO DEL CONTEXTO

```
═══════════════════════════════════════════════════════════════════════
MODELO DE TENANTS — Interno y Externo
═══════════════════════════════════════════════════════════════════════

  ┌─────────────────────────────────────────────────────────────────┐
  │  TENANT INTERNO (SBOS)                                          │
  │                                                                 │
  │  Somos NOSOTROS — el ecosistema SBOS.                           │
  │  • Empleados en Fedora VDI                                      │
  │  • Administradores del Dashboard                                │
  │  • Daemons M2M (bAuth, bKernel, biedata, bSearch, bhnexus)     │
  │  • Tenant = skull (is_external=false)                            │
  └─────────────────────────────────────────────────────────────────┘

  ┌─────────────────────────────────────────────────────────────────┐
  │  TENANT EXTERNO — Cada entidad externa es un tenant              │
  │                                                                 │
  │  • Un desarrollador externo = UN tenant (aunque sea 1 persona)  │
  │  • Una empresa que contrata bAuth = UN tenant                   │
  │  • Un comercio que usa nuestro POS = UN tenant                  │
  │  • Una persona con acceso a su casa = UN tenant                 │
  │  • Tenant = external (is_external=true)                         │
  │                                                                 │
  │  CADA tenant externo tiene SU PROPIA estructura de árbol:        │
  │  ┌──────────────────────────────────────────────────────┐      │
  │  │  Tenant: "desarrollador-jperez"                      │      │
  │  │  ├── bDomain: "jperez" (tipo=PERSONA)                │      │
  │  │  │   ├── bSubDomain: "oficina" (tipo=OFICINA)        │      │
  │  │  │   │   └── Pos: "desarrollo"                       │      │
  │  │  │   └── Roles: ADMIN, DESARROLLADOR, CLIENTE        │      │
  │  │  └── bDomain: "casa-jperez" (tipo=HOGAR)             │      │
  │  │      ├── bSubDomain: "principal" (tipo=CASA)          │      │
  │  │      │   └── Pos: "entrada"                          │      │
  │  │      └── Roles: RESIDENTE, DELIVERY                  │      │
  │  └──────────────────────────────────────────────────────┘      │
  └─────────────────────────────────────────────────────────────────┘
```

#### BOS SIEMPRE es el dueño del Context Plane

No hay "dos modos". BOS es el dueño del Context Plane siempre. La distinción
interno/externo NO está en el ctx_id — está en el TENANT al que pertenece el usuario.

```
idn_tenant:
┌─────────────────────────────────────────────────────────────────┐
│ tenant_slug    │ tenant_name      │ is_external │ descripción   │
├────────────────┼──────────────────┼─────────────┼───────────────┤
│ skull          │ SKULL Internal   │ false (0)   │ Tenant interno │
│ external       │ External Hub     │ true (1)    │ Tenant externo │
└────────────────┴──────────────────┴─────────────┴───────────────┘
```

El instalador (BOS) puebla AMBOS tenants en el seed inicial. Es solo UNA columna
booleana en `idn_tenant`: `is_external BOOLEAN DEFAULT false`.

```sql
-- Seed idn_tenant (bosctl setup)
INSERT INTO bauth.idn_tenant (tenant_slug, tenant_name, is_external, config)
VALUES
  ('skull',    'SKULL Internal',     false, '{"locale":"es-BO","timezone":"America/La_Paz","currency":"BOB","theme":"sbos-dark"}'::jsonb),
  ('external', 'External Hub',       true,  '{"locale":"en-US","timezone":"UTC","currency":"USD","theme":"sbos-light"}'::jsonb)
ON CONFLICT (tenant_slug) DO NOTHING;

-- BOS crea automáticamente la estructura org BASE para cada tenant:
-- Para skull:
INSERT INTO bauth.org_bDomain (bdomain_slug, bdomain_name, bdomain_type, tenant_slug)
  VALUES ('skull-corp', 'SKULL Corp', 'EMPRESA', 'skull');
INSERT INTO bauth.org_bSubDomain (bsubdomain_slug, bsubdomain_name, bsubdomain_type, bdomain_slug)
  VALUES ('norte', 'Sucursal Norte', 'SUCURSAL', 'skull-corp'),
         ('centro', 'Centro', 'SUCURSAL', 'skull-corp'),
         ('sur', 'Sur', 'SUCURSAL', 'skull-corp');
INSERT INTO bauth.org_pos_logico (pos_slug, pos_name, bsubdomain_slug)
  VALUES ('caja-01', 'Caja 01', 'norte'),
         ('admin', 'Administración', 'centro');

-- Para external (vacío — cada tenant externo crea sus propios bDomains):
-- Un bDomain puede ser EMPRESA, PERSONA, HOGAR, DESARROLLADOR, etc.
-- Un bSubDomain puede ser SUCURSAL, OFICINA, CASA, DEPENDENCIA, etc.
-- Cada uno tiene sus átomos de IDENTIDAD con formato y validación propios.
```

```
ctx_id (estructura idéntica para ambos):
  INTERNO:  tenant=skull     .bDomain=skull-corp  .bSubDomain=norte  .pos=caja-01
  EXTERNO:  tenant=external  .bDomain=jperez       .bSubDomain=oficina .pos=desarrollo

  La estructura es LA MISMA. bDomain puede ser EMPRESA, PERSONA, HOGAR.
  bSubDomain puede ser SUCURSAL, OFICINA, CASA, DEPENDENCIA.
  Cada uno con sus átomos de IDENTIDAD: nombre, valor, formato, validación.
```

#### El mismo flujo para ambos

```
BOS (dueño del Context Plane — SIEMPRE)
  │
  ├── Recibe solicitud de autenticación
  ├── Resuelve el tenant (skull o external, mismo código)
  ├── Resuelve átomos de IDENTIDAD (tenant . empresa . sucursal . pos . rol)
  ├── Crea ctx_id = UUIDv7 (sin campos especiales)
  ├── Envía a bAuth para registro
  │
  └── bAuth:
        ├── Almacena en ses_context (misma tabla)
        ├── Cachea en Redis DB0 (mismo TTL)
        └── Evalúa con el MISMO FastPath O(1)

  El usuario YA sabe a cuál adherirse:
  • Pertenezco al ecosistema SBOS → tenant skull
  • Soy externo (desarrollador, cliente, delivery) → tenant external
```

```
═══════════════════════════════════════════════════════════════════════
ESCENARIO CONCRETO — Delivery con acceso temporal
═══════════════════════════════════════════════════════════════════════

  jperez está en el tenant "external" (is_external=true), con dos bDomains:
  "jperez" (tipo=PERSONA) y "casa-jperez" (tipo=HOGAR)

  ┌────────────────────────────────────────────────────────────────┐
  │  PASO 1 — jperez crea permiso temporal                          │
  │                                                                 │
  │  jperez (tenant=external, bDomain=casa-jperez, rol=RESIDENTE)   │
  │  "Autorizo acceso a mi casa por 1 hora para delivery"           │
  │                                                                 │
  │  BOS → bAuth: crear rol temporal DELEGADO_DELIVERY:             │
  │    privilege_role_atom:                                         │
  │      ├── D1.org.tenant.jperez-externo     → IDENTIDAD          │
  │      ├── D1.org.bDomain.casa-jperez       → IDENTIDAD (HOGAR)  │
  │      ├── D1.org.bSubDomain.principal      → IDENTIDAD (CASA)   │
  │      ├── D1.org.pos.entrada               → IDENTIDAD           │
  │      ├── D2.fis.door.ENTRADA.UNLOCK       → ACCIÓN              │
  │      ├── D4.bauth.temporal.ttl            → REGLA, value=3600   │
  │      └── D10.bauth.delegation.source      → REGLA, value=jperez │
  └────────────────────────────────────────────────────────────────┘
                              │
                              ▼
  ┌────────────────────────────────────────────────────────────────┐
  │  PASO 2 — repartidor se autentica (QR o magic link)             │
  │                                                                 │
  │  BOS (dueño del contexto):                                      │
  │    1. Recibe magic-link con token de delegación                 │
  │    2. Resuelve tenant EXTERNAL "external"                       │
  │    3. Crea ctx_id = UUIDv7 con tenant=external                  │
  │    4. Átomos: DELEGADO_DELIVERY, casa-jperez, principal, entrada│
  │    5. Envía a bAuth para registro                               │
  │                                                                 │
  │  bAuth:                                                         │
  │    1. Almacena en ses_context (TTL = 3600)                      │
  │    2. Cachea en Redis DB0 (TTL = 3600)                          │
  │    3. Emite JWT con ctx_id                                      │
  └────────────────────────────────────────────────────────────────┘
                              │
                              ▼
  ┌────────────────────────────────────────────────────────────────┐
  │  PASO 3 — repartidor abre la puerta                             │
  │                                                                 │
  │  bAuth.access.evaluate("D2.fis.door.ENTRADA.UNLOCK", ctx_id):   │
  │    1. fastpath: rol_bitmask[ID_UNLOCK] = 1 ✅                   │
  │    2. ctx_id.expires_at > now() ✅                              │
  │    → ALLOW                                                      │
  └────────────────────────────────────────────────────────────────┘
                              │
                              ▼
  ┌────────────────────────────────────────────────────────────────┐
  │  PASO 4 — expiración automática (60s reconcile loop)            │
  │                                                                 │
  │  ctx_id expira → Redis lo elimina → reconcile marca EXPIRED     │
  │  Repartidor ya NO puede abrir la puerta.                        │
  └────────────────────────────────────────────────────────────────┘
```

### 4.2.6 Tabla resumen

| Aspecto | INTERNO | EXTERNO |
|--------|:---:|:---:|
| **Tenant** | SBOS (nosotros) | Cada entidad externa es un tenant |
| **Tipo de tenant** | `idn_tenant.is_external = false` (skull) | `idn_tenant.is_external = true` (external) |
| **Seed inicial** | Poblado por BOS: tenant `skull` | Poblado por BOS: tenant `external` |
| **Dueño del ctx_id** | BOS | BOS (el mismo) |
| **Quién crea el ctx_id** | BOS | BOS (el mismo) |
| **Estructura del ctx_id** | `tenant . empresa . sucursal . pos` | `tenant . empresa . sucursal . pos` (idéntica) |
| **Roles y usuarios** | Definidos por el tenant | Definidos por el tenant (idéntico) |
| **Átomos IDENTIDAD** | `D1.org.bDomain.*`, `D1.org.bSubDomain.*`, `D1.org.pos.*` — cada verbo con nombre, valor, formato y validación | Mismos |
| **Tabla ses_context** | Misma | Misma |
| **BitMask** | Mismo | Mismo |
| **Evaluación** | Mismo FastPath O(1) | Mismo FastPath O(1) |
| **Diferencia** | NINGUNA en código. Solo el tenant define el scope. | NINGUNA. |

### 4.2.7 El ctx_id y el BitMask

```
┌─────────────────────────────────────────────────────────────────┐
│  RELACIÓN CTX_ID ↔ ROLBITMASK                                   │
│                                                                 │
│  El ctx_id NO reemplaza al RolBitMask. Lo COMPLEMENTA:          │
│                                                                 │
│  RolBitMask (permanente):                                       │
│    • Qué átomos tiene el USUARIO por sus ROLES                  │
│    • Se recalcula cuando cambia la asignación de roles           │
│    • Es la VERDAD de lo que el usuario PUEDE hacer              │
│                                                                 │
│  ctx_id (temporal):                                              │
│    • Qué átomos de IDENTIDAD están ACTIVOS en ESTA sesión       │
│    • Trust level, LoA, risk_score del MOMENTO                   │
│    • Dispositivo desde el que se opera                          │
│    • Expira (session_ttl) o se invalida (logout, compromiso)   │
│                                                                 │
│  EVALUACIÓN COMPLETA:                                           │
│    rol_bitmask[atom] = 1          → el usuario PUEDE            │
│    AND ctx_id.trust_level ≥ atom.min_trust → nivel suficiente   │
│    AND ctx_id.loa ≥ atom.min_loa          → LoA suficiente      │
│    AND ctx_id.expires_at > now()          → sesión no expirada  │
│    → ALLOW                                                      │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2.8 Átomos relacionados con el contexto

| Átomo | Tipo | Propósito |
|-------|:---:|------|
| `D1.org.tenant.{id}` | IDENTIDAD | Tenant activo en esta sesión |
| `D1.org.bDomain.{id}` | IDENTIDAD | bDomain activo (EMPRESA, PERSONA, HOGAR...) |
| `D1.org.bSubDomain.{id}` | IDENTIDAD | bSubDomain activo (SUCURSAL, OFICINA, CASA...) |
| `D1.org.pos.{id}` | IDENTIDAD | Punto de facturación/venta/acceso activo |
| `D9.bauth.device.{id}` | IDENTIDAD | Dispositivo vinculado a la sesión |
| `D8.bauth.session.ttl_max` | REGLA | Tiempo máximo de sesión para este rol |
| `D8.bauth.session.inactivity_timeout` | REGLA | Timeout por inactividad |
| `D8.bauth.session.max_contexts` | REGLA | Máximo de contextos simultáneos |
| `D8.bauth.session.context_switch_allowed` | REGLA | ¿Puede cambiar de contexto? |

### 4.2.9 Simplificación de tablas

Con el modelo atómico, la administración de contexto se simplifica:

```
ACTUAL:
  ses_context + ses_context_switch + ses_ses_risk_policy + ses_caep_config
  + ses_superuser_context + Redis DB0 manual

NUEVO:
  ses_context (ctx_id + identity_atoms[] + state + timestamps)
  + Redis DB0 (cache automática desde ses_context)
  + privilege_atom (átomos de IDENTIDAD y REGLA para sesión)
  + privilege_role_atom (valores de reglas de sesión por rol)

  ❌ ses_context_switch   → absorbido por ctx.transfer
  ❌ ses_ses_risk_policy      → absorbido por átomos REGLA + RiskEngine
  ❌ ses_caep_config      → absorbido por átomos REGLA D8
  ❌ ses_superuser_context → absorbido por ctx_id + identity atoms
```

---

## PARTE 5 — WORKFLOW DE APROBACIÓN

```
┌─────────────────────────────────────────────────────────────────┐
│  FLUJO DE VIDA DE UN ÁTOMO (REGLA o MÉTODO)                      │
│                                                                 │
│  1. PROPUESTA (Admin de Dominio)                                │
│     INSERT privilege_atom (atom_type=RULE, lifecycle='proposed')  │
│     → NO aparece en runtime                                      │
│                                                                 │
│  2. REVISIÓN (Admin de Seguridad)                                │
│     Revisa: estándar, SoD, conflictos, impacto                   │
│     → Aprueba: lifecycle='active', approved_by=sec_admin         │
│     → Rechaza: lifecycle='draft', rejection_reason=...           │
│                                                                 │
│  3. PROPAGACIÓN (Reconcile loop, 60s)                            │
│     lifecycle='active' → reconcile loop actualiza runtime        │
│     Registra en sync_log                                         │
│                                                                 │
│  4. ASIGNACIÓN (Admin de Dominio)                                │
│     privilege_role_atom (rol, atom, value, customized=false)     │
│     → Se recalcula RolBitMask del rol                            │
│     → Se propaga a todos los usuarios con ese rol               │
│                                                                 │
│  5. RUNTIME                                                      │
│     El átomo ya evalúa en producción                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## PARTE 6 — PROTECCIÓN DE LA FORTALEZA

`cfg_policy_library` y `privilege_atom` comparten 4 anillos de protección:

| Anillo | Protección | Mecanismo |
|:---:|------|------|
| **1** | Trazabilidad | `proposed_by`, `approved_by`, `approved_at` + auditoría WORM + hash-chain SHA-256 + Merkle D12 |
| **2** | Autenticación | AAL3 + Passkey HW para modificar, AAL2 para leer, Step-Up <60s por operación |
| **3** | Autorización | Solo SU/SYS/Admin Seguridad. SoD: proponente ≠ aprobador. |
| **4** | Auditoría | `privilege_atom_audit` WORM + `sync_log` + `cfg_policy_library_audit` + Hash-chain + Merkle proof verificable externamente |

---

## PARTE 7 — CONSOLIDACIÓN DE TABLAS

### 7.1 Tablas que se ELIMINAN (~32)

```
ath_policy_d1..d12      (12)  → absorbidas por privilege_atom (REGLA)
ath_config_d1..d12      (12)  → absorbidas por privilege_atom (REGLA)
ath_config              (1)   → absorbida por privilege_atom (REGLA)
ath_policy              (1)   → ya vacía, legacy
ath_credential_policy   (1)   → absorbida por privilege_atom (REGLA) + privilege_role_atom.value
cfg_validation_rule     (1)   → absorbida por privilege_atom.validation JSONB
fin_limit               (1)   → absorbida por privilege_role_atom.value
fin_transaction_type    (1)   → absorbida por privilege_atom (catálogo de grupos)
bos_permiso_logico      (1)   → legacy, sin handler activo
```

### 7.2 Tablas que se MANTIENEN

```
NÚCLEO:          privilege_atom, privilege_role_atom, privilege_user_atom
APOYO:           privilege_domain, privilege_application, privilege_group, privilege_verb
REFERENCIA:      cfg_policy_library, framework_raw, cfg_key_translation
IDENTIDAD:       idn_role_template, idn_user_template, idn_atributo
DOMINIOS:        40+ tablas operativas (fin_*, fis_*, ses_*, aud_*, blk_*, geo_*, net_*, dlg_*, ath_*, idn_*, org_*, sec_*)
ECOSISTEMA:      bglobal.* (global_country×196, global_language×125, geo_timezone×319, global_currency×143), bcalendar.* (cal_schedule, cal_calendar, cal_event, cal_holiday, cal_alarm...)
```

---

## PARTE 8 — CUMPLIMIENTO NORMATIVO

| Estándar | Control | Cumplimiento |
|---------|---------|:---:|
| ISO 27001:2022 A.8.9 | Configuration Management | ✅ Baseline documentada, change control, monitoreo |
| ISO 27001:2022 A.5.1 | Policies for Information Security | ✅ Definidas, aprobadas, comunicadas, revisadas |
| ISO 27001:2022 A.8.2 | Privileged Access Rights | ✅ Solo SU/SYS/Admin Seguridad + SoD |
| ISO 27001:2022 A.8.15 | Logging | ✅ WORM + hash-chain SHA-256 + Merkle D12 |
| NIST SP 800-53 CM-3 | Configuration Change Control | ✅ Workflow + aprobación + auditoría |
| NIST SP 800-53 CM-3(2) | Test/Validate/Document | ✅ simulate antes de activar |
| NIST SP 800-53 CM-3(5) | Auto Security Response | ✅ Reconcile loop anti-drift |
| NIST SP 800-53 CM-3(6) | Cryptography Management | ✅ SHA-256 chain + Merkle + blockchain |
| PCI DSS 4.0 6.5.1 | Change Control Procedures | ✅ 5-step workflow + rollback |
| PCI DSS 4.0 10.5 | Secure Audit Trails | ✅ WORM inmutable + verificación externa |
| SOC 2 CC8.1 | Change Management | ✅ Baseline + testing + SoD + emergency |

---

## PARTE 9 — PLAN DE MIGRACIÓN

| Fase | Acción | Impacto | Esfuerzo |
|:---:|------|:---:|:---:|
| **1** | Extender `privilege_atom` con `atom_type`, `data_type`, `validation`, `lifecycle`, `proposed_by`, `approved_by` | Nulo (ALTER TABLE) | 2h |
| **2** | Extender `privilege_role_atom` con `value`, `customized` | Nulo | 1h |
| **3** | Migrar `ath_policy_d*` existentes → átomos REGLA | Bajo (escript SQL) | 4h |
| **4** | Migrar valores de RoleTemplate → `privilege_role_atom` | Medio (escript SQL + verificación) | 6h |
| **5** | Reescribir `bauth.policy.domain.evaluate` para usar átomos | Alto (cambio de handler) | 4h |
| **6** | Unificar Dashboard: acciones + reglas + métodos en árbol `d.a.m.v` | Medio (frontend Flutter) | 8h |
| **7** | Marcar tablas obsoletas como `[DEPRECADO]` | Nulo | 1h |
| **8** | Eliminar tablas deprecadas (siguiente release) | Bajo | 2h |

**Esfuerzo total estimado:** ~28 horas
**Riesgo:** BAJO — todas las fases son incrementales y no rompen runtime.

---

## PARTE 10 — RESUMEN VISUAL

```
┌─────────────────────────────────────────────────────────────────────┐
│                    BAUTH — ARQUITECTURA ATÓMICA                       │
│                                                                     │
│  TABLAS DE APOYO (catálogos)                                        │
│  ┌──────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐  │
│  │ domain   │ │ application  │ │ group        │ │ verb         │  │
│  │ D1..D12  │ │ tryton,bauth │ │ ventas,      │ │ CREATE,      │  │
│  │ 12 fijos │ │ superset...  │ │ financial... │ │ max_daily... │  │
│  └────┬─────┘ └──────┬───────┘ └──────┬───────┘ └──────┬───────┘  │
│       │              │               │                │           │
│       └──────────────┴───────────────┴────────────────┘           │
│                          │                                         │
│                          ▼                                         │
│  TABLA CENTRAL                                                     │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │                    privilege_atom                              │ │
│  │  d.a.m.v → posición N en RolBitMask                           │ │
│  │  4 TIPOS: ACCIÓN | REGLA | MÉTODO | IDENTIDAD                 │ │
│  └──────────────────────────┬───────────────────────────────────┘ │
│                             │                                      │
│              ┌──────────────┴──────────────┐                      │
│              ▼                             ▼                      │
│  ┌──────────────────────┐    ┌──────────────────────────────────┐ │
│  │ privilege_role_atom  │    │ privilege_user_atom               │ │
│  │ rol ↔ átomo + valor  │    │ user ↔ átomo (sobrescritura)     │ │
│  └──────────────────────┘    └──────────────────────────────────┘ │
│                             │                                      │
│                             ▼                                      │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  ROLBITMASK (N-bit one-hot) → FastPath O(1)                   │ │
│  │  [0][1][0][1]...[1][0][1][0]...[1]                            │ │
│  │   ACCIÓN          REGLA        MÉTODO    IDENTIDAD            │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  REFERENCIA DOCUMENTAL                                        │ │
│  │  cfg_policy_library (9,142 normas) ← NO runtime, solo consulta│ │
│  │  framework_raw (16 JSON fuente) ← inmutables                  │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  PROTECCIÓN (4 anillos)                                       │ │
│  │  Trazabilidad · Autenticación AAL3 · Autorización SoD         │ │
│  │  Auditoría WORM + SHA-256 + Merkle D12                         │ │
│  └──────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

---

## PARTE 11 — CONTABILIDAD DIMENSIONAL DE LA IDENTIDAD

### El átomo como cuenta analítica

La arquitectura atómica de bAuth es funcionalmente idéntica a la **contabilidad dimensional**
con cuentas analíticas. Cada átomo es una "cuenta" que puede ser consultada, auditada y
analizada desde múltiples dimensiones independientes:

```
CONTABILIDAD DIMENSIONAL               ARQUITECTURA ATÓMICA BAUTH
─────────────────────────              ──────────────────────────
Cuenta contable                        Átomo (d.a.m.v)
Dimensión 1: Centro de costo           Dimensión 1: Dominio (D1-D12)
Dimensión 2: Proyecto                  Dimensión 2: Aplicación
Dimensión 3: Región                    Dimensión 3: Módulo/Grupo
Dimensión 4: Tipo de operación         Dimensión 4: Verbo
Dimensión 5: Período                   Dimensión 5: Tiempo (created_at, expires_at)
Dimensión 6: Responsable               Dimensión 6: Usuario (ctx_id, user_uuid)
```

### Auditoría desde cualquier dimensión

```
ANALIZAR POR DOMINIO:
  SELECT count(*) FROM privilege_atom WHERE domain_code = 3
  → "150 átomos en D3 — Financiero"
  → "12 roles tienen átomos D3 asignados"
  → "jperez usó átomos D3 45 veces hoy"

ANALIZAR POR APLICACIÓN:
  SELECT count(*) FROM privilege_atom WHERE app_code = 1
  → "320 átomos en tryton"
  → "Contador es el rol con más átomos en tryton"
  → "La aplicación más usada es tryton (85% de evaluaciones)"

ANALIZAR POR TIPO DE ÁTOMO:
  SELECT count(*) FROM privilege_atom WHERE atom_type = 'REGLA'
  → "200 átomos de tipo REGLA definidos"
  → "15 reglas personalizadas por admins (customized=true)"
  → "NIST SP 800-63B cubre el 60% de las reglas D9"

ANALIZAR POR TIEMPO:
  SELECT count(*) FROM privilege_atom_audit WHERE created_at > now() - interval '30 days'
  → "23 cambios de políticas en los últimos 30 días"
  → "5 aprobaciones pendientes (lifecycle='proposed')"
  → "2 rollbacks ejecutados por incidentes"

ANALIZAR POR USUARIO:
  SELECT * FROM privilege_atom_audit WHERE changed_by = 'admin-mgomez'
  → "mgomez propuso 8 políticas este mes"
  → "3 fueron aprobadas, 2 rechazadas, 3 pendientes"
  → "Todas en D3 — Financiero"
```

### Trazabilidad completa

Cada operación sobre un átomo queda registrada en MÚLTIPLES dimensiones simultáneamente,
permitiendo reconstruir EXACTAMENTE qué pasó desde cualquier ángulo:

```
EVENTO: "jperez emitió factura #1234 por $5,000"
  │
  ├── DIMENSIÓN DOMINIO:    D3 — Financiero
  ├── DIMENSIÓN APP:        tryton
  ├── DIMENSIÓN MÓDULO:     facturacion
  ├── DIMENSIÓN VERBO:      emitir
  ├── DIMENSIÓN IDENTIDAD:  jperez (tenant=skull, bDomain=skull-corp, bSubDomain=norte, pos=caja-01, rol=CAJERO)
  ├── DIMENSIÓN REGLA:      max_daily_limit = $100,000 → $5,000 ≤ $100,000 → ALLOW
  ├── DIMENSIÓN MÉTODO:     PASSWORD + TOTP (AAL2)
  ├── DIMENSIÓN DISPOSITIVO: MOBILE-A1, trust=85
  ├── DIMENSIÓN TIEMPO:     2026-06-30 14:23:45
  ├── DIMENSIÓN CTX_ID:     0193-...-a1b2c3
  ├── DIMENSIÓN AUDITORÍA:  aud_event #8842, hash SHA-256: a3f2...
  └── DIMENSIÓN BLOCKCHAIN:  blk_merkle_batch #42, tx_hash: 0x7a3b..., verificado en Arbiscan
```

### Lo que esto permite

| Capacidad | Ejemplo |
|-----------|---------|
| **Auditoría forense** | "Dado ctx_id X, reconstruir TODO lo ocurrido: quién, qué, cuándo, dónde, cómo, con qué permisos, bajo qué políticas" |
| **Análisis de riesgo** | "¿Cuántos usuarios tienen acceso a emitir facturas por más de $100,000?" → consulta átomos REGLA + valores asignados |
| **Detección de anomalías** | "jperez normalmente accede desde sucursal Norte a las 14:00. Hoy accedió desde otra IP a las 03:00." |
| **Cumplimiento normativo** | "Mostrar todas las políticas D3 activas con su estándar de referencia y última fecha de revisión" |
| **Optimización de roles** | "¿Qué átomos REGLA están asignados a CAJERO pero nunca se evalúan?" (átomos huérfanos) |
| **SoD verification** | "¿Hay algún usuario con átomos de EMITIR_FACTURA y APROBAR_PAGO simultáneamente?" |

---

## PARTE 12 — ESTRUCTURA DE POLÍTICAS POR DOMINIO

### Propósito

Esta sección define, para cada uno de los 12 dominios de control, los **estándares
normativos internacionales** que lo gobiernan, las **tablas operativas** que lo implementan,
los **átomos REGLA/MÉTODO** que lo parametrizan por rol, y las **entradas de `cfg_policy_library`**
que deben existir como fuente de verdad normativa.

**Principio rector:** Ningún parámetro de un dominio puede existir en el sistema sin
estar respaldado por al menos un estándar internacional. Esta sección es el puente
entre la normativa y el modelo atómico, y es la base para el rediseño de la BD.

**Estructura por dominio:**
```
Estándares → definen QUÉ se debe controlar y CON QUÉ umbrales
     ↓
Tablas operativas → almacenan la INFRAESTRUCTURA del dominio (configuración del sistema)
     ↓
Átomos REGLA/MÉTODO → almacenan los PARÁMETROS POR ROL en privilege_atom
     ↓
cfg_policy_library → fuente de verdad normativa (referencia inmutable, no runtime)
```

---

### D00 — IDENTIDAD ORGANIZACIONAL

> **Solo para estandarización interna (SBOS-MODEL-D00).** Este dominio no alinea con
> estándares de autenticación externa (OIDC, SAML, OAuth 2.0) — esos pertenecen a D9.
> Define QUÉ ES la entidad que opera, no QUÉ PUEDE HACER. Establece el árbol
> organizacional: `tenant → bDomain → bSubDomain → pos_logico → actor`, que es
> exactamente la estructura del `ctx_id` del Context Plane (SBOS-049 §5.3).
>
> **Nota de diseño:** Los átomos de D00 son tipo **REGLA** — cada átomo tiene un verbo
> (la dimensión d₄) y un valor con validación. El verbo es `type`, `nombre`, `nit`, etc.
> El valor es `empresa`, `DEPO srl`, `12345678`, etc. EMPRESA/PERSONA no son verbos —
> son valores del átomo `D00.org.bdomain.type`.

#### Estándares normativos

| Estándar | Control | Qué define | Atributo / tabla afectada |
|----------|---------|-----------|--------------------------|
| **SBOS-MODEL-D00 v1.0** | — | Taxonomía interna: tipos de bDomain, bSubDomain, pos, actor y sus atributos | Todos los átomos D00 |
| ISO 24760-2:2025 | §4.1–4.3 | Identity management reference architecture: entidad, atributos, dominios de identidad | `idn_atributo`, `idn_user_template` |
| ISO 9001:2015 | §3.2.4 | Definición de cliente: actores externos con requisitos diferenciados de los internos | `D00.org.bdomain.type` |
| ISO/IEC 27001:2022 | A.5.15 | Políticas de gestión de identidad y acceso como base de toda autorización | Todos los átomos D00 |
| ISO/IEC 29115:2013 | §6 | Entity Authentication Assurance Framework: niveles IAL1-3 | `idn_atributo` (cat=documento) |
| ISO 3166-1:2020 | alpha-2 | Códigos de país de 2 letras — fuente de `display_format=COUNTRY_CODE` y `ID_XX` / `TAX_XX` | `bglobal.global_country.iso_alpha2`, átomos 5812, 5814, 5815 |
| ISO 639-1/2/3:2023 | — | Códigos de idioma — fuente de `display_format=LOCALE_BCP47` | `bglobal.global_language.locale`, átomo 5827 |
| IETF BCP 47 (RFC 5646) | §2 | Etiquetas de idioma/región (ej: `es-BO`) combinando ISO 639 + ISO 3166-1 | `bglobal.global_language.locale`, átomo 5827 |
| IANA Timezone DB (tzdata) | — | Identificadores de zona horaria (ej: `America/La_Paz`) — `display_format=TIMEZONE_IANA` | `bglobal.geo_timezone.timezone_id`, átomo 5828 |
| ITU-T E.164 (2010) | §5–7 | Formato de números telefónicos internacionales — `display_format=E164` | `bglobal.global_country.itu_calling_code`, átomo 5814 |
| ISO 4217:2015 | — | Códigos de moneda de 3 letras — `display_format=MONEY` | `bglobal.global_currency.currency_code`, `idn_tenant_currencies` |
| SCIM 2.0 RFC 7643 | §4.1–4.3 | Atributos canónicos de usuario: userName, emails, gender, locale, timezone | `idn_atributo` (cat=contacto/personal), átomos 5823–5828 |
| SBOS-049 v3.0 | §4.2 / §5.3 | Estructura canónica del ctx_id: interno.tenant.bdomain.bsubdomain | `idn_tenant`, `org_empresa`, `org_sucursal`, `org_pos_logico` |

#### Tablas operativas (prefijos `idn_` / `org_`)

| Tabla | Propósito | Norma base |
|-------|-----------|-----------|
| `idn_tenant` | Tenants del sistema. Columna `is_internal boolean` distingue skull (true) de externos (false) | SBOS-049 §7 |
| `idn_tenant_domain` | Subdominios declarados por tenant (empresa, persona, hogar, desarrollador, m2m) | SBOS-MODEL-D00 |
| `org_empresa` | bDomain tipo empresa: organización comercial con NIT, sector CAEB, tipo societario | ISO 9001:2015 §3.2.4 |
| `org_sucursal` | bSubDomain tipo sucursal/oficina: división territorial o funcional del bDomain | ISO 24760-2:2025 §4.2 |
| `org_pos_logico` | Punto de operación: caja/terminal/puerta/sensor/actuador. Gestionado por bos (SBOS-018) | SBOS-049 §6.1 |
| `idn_user_template` | Actor que opera: empleado interno, cliente externo, visitante, servicio, dispositivo M2M | ISO 24760-2:2025 §4.1 |
| `idn_atributo` | **Tabla genérica extensible.** Almacena cualquier atributo de identidad de cualquier entidad D00-D12 (emails, teléfonos, documentos, direcciones, idiomas, horarios...) sin DDL adicional. Reemplaza `org_contacto`, `org_documento`, `org_direccion`. `display_format` referencia catálogos `bglobal.*`. `atom_code` FK a `privilege_atom` para control BitMask. Ver `BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0.md`. | ISO 24760-2:2025 §6 · SCIM 2.0 RFC 7643 §2.4 |

#### Grupos de la aplicación `org` (app_code=13)

| group_code | group_name | Entidades que representa |
|:----------:|-----------|------------------------|
| g1 | Tenant | El tenant (skull interno o externo) |
| g2 | bDomain | La "empresa": empresa, persona, hogar, desarrollador, m2m, edificio |
| g3 | bSubDomain | La "sucursal": sucursal, dependiente, familiar, oficina |
| g4 | Pos | El punto de acceso lógico: caja, terminal, puerta, sensor, actuador |
| g5 | Actor | El actor individual: datos personales y profesionales del usuario |

#### Átomos REGLA en `privilege_atom` (D00)

> Cada átomo = `d.a.m.v` donde `v` es el **verbo** (la dimensión que varía), no el tipo.
> El verbo `type` porta el valor enumerado; los demás verbos portan el dato textual con validación.
> Posiciones en BD: 5809–5828 (después de los 5,808 átomos de D1-D12).

| Átomo `d.a.m.v` | Tipo | Valor / Validación | pos BD |
|-----------------|:----:|-------------------|:------:|
| `D00.org.tenant.type` | REGLA | ENUM: `interno` / `externo` | 5809 |
| `D00.org.bdomain.type` | REGLA | ENUM: `empresa` / `persona` / `hogar` / `desarrollador` / `m2m` / `edificio` | 5810 |
| `D00.org.bdomain.nombre` | REGLA | TEXT 2-128 chars (ej: `DEPO srl` para empresa, `Juan Pérez` para persona) | 5811 |
| `D00.org.bdomain.nit` | REGLA | TEXT tributario fiscal del bDomain. Formato dinámico según país del tenant: `display_format=TAX_XX` donde XX = `bglobal.global_country.iso_alpha2`. Ej: `TAX_BO` → `^\d{8,12}$`; `TAX_AR` → `^\d{2}-\d{8}-\d$`. Valor almacenado en `idn_atributo`. | 5812 |
| `D00.org.bdomain.email` | REGLA | TEXT formato RFC 5321. `display_format=EMAIL`. Almacenado en `idn_atributo` (permite múltiples emails por entidad) | 5813 |
| `D00.org.bdomain.telefono` | REGLA | TEXT E.164 (`+[código_país][número]`). `display_format=E164`. Prefijo desde `bglobal.global_country.itu_calling_code`. Almacenado en `idn_atributo` | 5814 |
| `D00.org.bdomain.ci` | REGLA | TEXT documento de identidad nacional del bDomain (tipo=persona). Formato dinámico según país: `display_format=ID_XX` donde XX = `bglobal.global_country.iso_alpha2`. Almacenado en `idn_atributo` | 5815 |
| `D00.org.bdomain.direccion` | REGLA | TEXT dirección postal. `display_format=TEXTO_LIBRE`. Almacenado en `idn_atributo` (permite múltiples direcciones por tipo: work/home/fiscal/registered) | 5816 |
| `D00.org.bsubdomain.type` | REGLA | ENUM: `sucursal` / `dependiente` / `familiar` / `oficina` | 5817 |
| `D00.org.bsubdomain.nombre` | REGLA | TEXT 2-128 chars (ej: `Sucursal La Paz`) | 5818 |
| `D00.org.bsubdomain.direccion` | REGLA | TEXT dirección postal de la sucursal. `display_format=TEXTO_LIBRE`. Almacenado en `idn_atributo` | 5819 |
| `D00.org.pos.type` | REGLA | ENUM: `caja` / `terminal` / `puerta` / `sensor` / `actuador` / `punto_virtual` | 5820 |
| `D00.org.pos.nombre` | REGLA | TEXT 2-64 chars (ej: `POS-23`, `CAJA-01`) | 5821 |
| `D00.org.actor.type` | REGLA | ENUM: `HUMAN` / `SERVICE` / `DEVICE` / `BOT` | 5822 |
| `D00.org.actor.employee_type` | REGLA | ENUM: `FULL_TIME` / `PART_TIME` / `CONTRACTOR` / `INTERN` / `NONE` / `STUDENT` (SCIM Enterprise §4.3). `NONE` para BOT/DEVICE/SERVICE | 5823 |
| `D00.org.actor.gender` | REGLA | ENUM: `M` / `F` / `NB` / `NR` (SCIM 2.0 RFC 7643 §4.1.2) | 5824 |
| `D00.org.actor.marital_status` | REGLA | ENUM: `SINGLE` / `MARRIED` / `DIVORCED` / `WIDOWED` / `CIVIL_UNION` | 5825 |
| `D00.org.actor.id_doc_type` | REGLA | ENUM dinámico — derivado de `bglobal.global_country`: `CI` / `DNI` / `CC` / `DUI` / `CURP` / `CPF` / `PASSPORT` / `NONE` (NONE para DEVICE/BOT/SERVICE). FK implícita a `bglobal.global_country.iso_alpha2` para resolver el tipo correcto | 5826 |
| `D00.org.actor.locale` | REGLA | TEXT IETF BCP 47 (ej: `es-BO`, `en-US`, `pt-BR`). `display_format=LOCALE_BCP47`. Validado contra `bglobal.global_language.locale` — 125 idiomas | 5827 |
| `D00.org.actor.timezone` | REGLA | TEXT identificador IANA (ej: `America/La_Paz`, `Europe/Madrid`). `display_format=TIMEZONE_IANA`. Validado contra `bglobal.geo_timezone.timezone_id` — 319 zonas | 5828 |

> **Nota de internacionalización (v1.3.0):** Los átomos 5812 (`nit`), 5814 (`telefono`),
> 5815 (`ci`) y 5816 (`direccion`) usan formato dinámico por país — NO están hardcodeados
> para Bolivia. El `display_format` y `validation_policy` se resuelven en runtime según
> `bglobal.global_country.iso_alpha2` del tenant. El valor canónico almacenado en
> `idn_atributo.value_text` siempre es el dato en formato de almacenamiento (sin separadores
> visuales). Ver catálogo completo en `BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0.md §2.4`.

#### Cobertura de templates (UserTemplate v6.0 / RolTemplate v6.0)

> **Leyenda de almacenamiento:**
> - **columna** = columna directa en `idn_user_template` (cardinalidad 1:1 por actor)
> - **idn_atributo** = tabla genérica extensible (cardinalidad 1:N, múltiples valores por actor)
> - **FK** = clave foránea a otra tabla del sistema

| Bloque template | Campo | Átomo D00 / Mapeo | Almacenamiento | `display_format` |
|----------------|-------|-------------------|:--------------:|:----------------:|
| **BLOQUE 0 — identity** | `tenantId` | `idn_tenant.uuid` | FK | — |
| **BLOQUE 0 — identity** | `empresaId` | `idn_user_template.empresa_id` | FK → `org_empresa` | — |
| **BLOQUE 0 — identity** | `sucursalId` | `idn_user_template.sucursal_id` | FK → `org_sucursal` | — |
| **BLOQUE 0 — identity** | `posLogico` | `idn_user_template.pos_logico` | FK → `org_pos_logico` | — |
| **BLOQUE 0 — identity** | `actorType` | `D00.org.actor.type` | columna | ENUM |
| **BLOQUE 2 — personal_info** | `gender` | `D00.org.actor.gender` | columna | ENUM |
| **BLOQUE 2 — personal_info** | `maritalStatus` | `D00.org.actor.marital_status` | columna | ENUM |
| **BLOQUE 2 — personal_info** | `birthDate` | `idn_atributo` (cat=personal, key=birth_date) | idn_atributo | `DATE_ISO` |
| **BLOQUE 2 — personal_info** | `nationality` | `idn_atributo` (cat=personal, key=nationality) | idn_atributo | `COUNTRY_CODE` → `bglobal.global_country` |
| **BLOQUE 2 — personal_info** | `locale` | `D00.org.actor.locale` | columna | `LOCALE_BCP47` → `bglobal.global_language` |
| **BLOQUE 2 — personal_info** | `zoneinfo` | `D00.org.actor.timezone` | columna | `TIMEZONE_IANA` → `bglobal.geo_timezone` |
| **BLOQUE 2 — personal_info** | `idDocumentType` | `D00.org.actor.id_doc_type` | columna | ENUM dinámico por país |
| **BLOQUE 2 — personal_info** | `idDocumentNumber` | `idn_atributo` (cat=documento, key=id_doc) | idn_atributo | `ID_XX` según `bglobal.global_country` |
| **BLOQUE 2 — personal_info** | `emails[ ]` | `idn_atributo` (cat=contacto, key=email) | idn_atributo | `EMAIL` (RFC 5321) |
| **BLOQUE 2 — personal_info** | `phones[ ]` | `idn_atributo` (cat=contacto, key=telefono) | idn_atributo | `E164` (ITU-T E.164) |
| **BLOQUE 2 — personal_info** | `addresses[ ]` | `idn_atributo` (cat=ubicacion, key=direccion) | idn_atributo | `TEXTO_LIBRE` |
| **BLOQUE 2 — personal_info** | `photo` | `idn_atributo` (cat=personal, key=photo_url) | idn_atributo | `URL_HTTPS` |
| **BLOQUE 2 — personal_info** | `bio` | `idn_atributo` (cat=personal, key=bio) | idn_atributo | `TEXTO_LIBRE` |
| **BLOQUE 3 — professional** | `employeeType` | `D00.org.actor.employee_type` | columna | ENUM (SCIM Enterprise §4.3) |
| **BLOQUE 3 — professional** | `organization` | `idn_user_template.empresa_id` | FK | — |
| **BLOQUE 3 — professional** | `department` | `idn_atributo` (cat=profesional, key=departamento) | idn_atributo | `TEXTO_LIBRE` |
| **BLOQUE 3 — professional** | `title` | `idn_atributo` (cat=profesional, key=cargo) | idn_atributo | `TEXTO_LIBRE` |
| **BLOQUE 4 — roles** | `rolTemplates[ ]` | `idn_user_template.roles_jsonb` | columna JSONB | — |
| **BLOQUE 5 — devices** | `devices[ ]` | `ath_device_registration` | FK → D5 | — |
| **BLOQUE 6 — credentials** | `mfaMethods[ ]` | Keycloak `required_actions`, KC credential store | KC externo | — |
| **BLOQUE 7 — location** | `defaultLocation` | `idn_atributo` (cat=ubicacion, key=loc_default) | idn_atributo | `COORDENADAS_DD` |
| **BLOQUE 8 — temporal** | `scheduleId` | `ath_policy_d8` → `bcalendar.cal_schedule` | FK → D8 | — |
| **BLOQUE 9 — network** | `allowedIPs[ ]` | `ath_policy_d9` | columna JSONB D9 | — |
| **BLOQUE 10 — audit** | `auditEvents` | `audit_event` (append-only) | FK → D10 | — |
| **BLOQUE 11 — external_services** | `externalIdps[ ]` | `idn_atributo` (cat=tecnologia, key=idp_external) | idn_atributo | `TEXTO_LIBRE` |
| **BLOQUE 12 — compliance** | `consentRecords[ ]` | `ath_policy_d12` | columna JSONB D12 | — |
| **BLOQUE 13 — lifecycle** | `status` | `idn_user_template.status` | columna | ENUM |
| **BLOQUE 14 — bitmask** | `rolBitMask` | `bitmask_bundle` (cache Redis) | columna + Redis | — |
| **BLOQUE 15 — sync** | `kcUserId` | `idn_user_template.keycloak_id` | columna | — |
| **RolTemplate BLOQUE 1** | `roleCode` | `idn_role_template.role_code` | columna | — |
| **RolTemplate BLOQUE 1** | `rolBitMask` | `bitmask_bundle` | columna | — |
| **RolTemplate BLOQUE 2–14** | `lógica de acceso` | Átomos D1-D12 por dominio | `ath_policy_dN` | — |

> **Conclusión de cobertura:** Los 16 bloques del UserTemplate v6.0 y los 14 bloques del
> RolTemplate v6.0 tienen cobertura completa con la arquitectura D00 + `idn_atributo` + `bglobal.*`.
> La tabla `idn_atributo` cubre en exclusiva todos los campos de cardinalidad 1:N (emails,
> teléfonos, direcciones, documentos, fotos, redes sociales) sin necesidad de DDL adicional.
> Las columnas directas en `idn_user_template` cubren los campos 1:1 (gender, locale, timezone,
> employee_type). Los campos de otros dominios (D5-D12) usan sus tablas `ath_policy_dN` propias.

#### SQL de implementación (6 pasos, ejecutar en orden)

```sql
-- PASO 1: Agregar is_internal a idn_tenant
ALTER TABLE bauth.idn_tenant
  ADD COLUMN IF NOT EXISTS is_internal boolean NOT NULL DEFAULT true;
-- skull es interno (true); tenants externos tendrán is_internal=false

-- PASO 2: Habilitar domain_code=0 e insertar D00
ALTER TABLE bauth.privilege_domain
  DROP CONSTRAINT IF EXISTS ck_domain_code;
ALTER TABLE bauth.privilege_domain
  ADD CONSTRAINT ck_domain_code CHECK (domain_code >= 0 AND domain_code <= 15);
INSERT INTO bauth.privilege_domain (domain_code, domain_name, is_normative, description)
VALUES (0, 'Identidad Organizacional', false,
  'Tipos y atributos de tenant, bDomain, bSubDomain, pos y actor. '
  'Pre-condición estructural del ctx_id (SBOS-049). SBOS-MODEL-D00.');

-- PASO 3: Insertar aplicación org (app_code=13)
INSERT INTO bauth.privilege_application (app_code, app_name, app_slug, tenant_id, active)
VALUES (13, 'Org', 'org',
  (SELECT uuid FROM bauth.idn_tenant WHERE tenant_slug = 'skull'), true);

-- PASO 4: Insertar grupos de org
INSERT INTO bauth.privilege_group (group_code, app_code, group_name) VALUES
  (1, 13, 'Tenant'),
  (2, 13, 'bDomain'),
  (3, 13, 'bSubDomain'),
  (4, 13, 'Pos'),
  (5, 13, 'Actor');

-- PASO 5: Insertar verbos de identidad (verb_code 51-63)
INSERT INTO bauth.privilege_verb (verb_code, verb_name, verb_slug) VALUES
  (51, 'Tipo',            'type'),
  (52, 'Nombre',          'nombre'),
  (53, 'NIT',             'nit'),
  (54, 'Email',           'email'),
  (55, 'Teléfono',        'telefono'),
  (56, 'Carnet',          'ci'),
  (57, 'Dirección',       'direccion'),
  (58, 'Tipo empleo',     'employee_type'),
  (59, 'Género',          'gender'),
  (60, 'Estado civil',    'marital_status'),
  (61, 'Tipo documento',  'id_doc_type'),
  (62, 'Locale',          'locale'),
  (63, 'Zona horaria',    'timezone');

-- PASO 6: Insertar átomos D00 (posiciones 5809-5828)
INSERT INTO bauth.privilege_atom
  (app_code, group_code, domain_code, verb_code, atom_name, atom_slug, atom_pos)
VALUES
  (13, 1, 0, 51, 'Org · Tenant     · Identidad Org · type',        'org.g1.d0.type',        5809),
  (13, 2, 0, 51, 'Org · bDomain    · Identidad Org · type',        'org.g2.d0.type',        5810),
  (13, 2, 0, 52, 'Org · bDomain    · Identidad Org · nombre',      'org.g2.d0.nombre',      5811),
  (13, 2, 0, 53, 'Org · bDomain    · Identidad Org · nit',         'org.g2.d0.nit',         5812),
  (13, 2, 0, 54, 'Org · bDomain    · Identidad Org · email',       'org.g2.d0.email',       5813),
  (13, 2, 0, 55, 'Org · bDomain    · Identidad Org · telefono',    'org.g2.d0.telefono',    5814),
  (13, 2, 0, 56, 'Org · bDomain    · Identidad Org · ci',          'org.g2.d0.ci',          5815),
  (13, 2, 0, 57, 'Org · bDomain    · Identidad Org · direccion',   'org.g2.d0.direccion',   5816),
  (13, 3, 0, 51, 'Org · bSubDomain · Identidad Org · type',        'org.g3.d0.type',        5817),
  (13, 3, 0, 52, 'Org · bSubDomain · Identidad Org · nombre',      'org.g3.d0.nombre',      5818),
  (13, 3, 0, 57, 'Org · bSubDomain · Identidad Org · direccion',   'org.g3.d0.direccion',   5819),
  (13, 4, 0, 51, 'Org · Pos        · Identidad Org · type',        'org.g4.d0.type',        5820),
  (13, 4, 0, 52, 'Org · Pos        · Identidad Org · nombre',      'org.g4.d0.nombre',      5821),
  (13, 5, 0, 51, 'Org · Actor      · Identidad Org · type',        'org.g5.d0.type',        5822),
  (13, 5, 0, 58, 'Org · Actor      · Identidad Org · employee_type','org.g5.d0.employee_type',5823),
  (13, 5, 0, 59, 'Org · Actor      · Identidad Org · gender',      'org.g5.d0.gender',      5824),
  (13, 5, 0, 60, 'Org · Actor      · Identidad Org · marital_status','org.g5.d0.marital_status',5825),
  (13, 5, 0, 61, 'Org · Actor      · Identidad Org · id_doc_type', 'org.g5.d0.id_doc_type', 5826),
  (13, 5, 0, 62, 'Org · Actor      · Identidad Org · locale',      'org.g5.d0.locale',      5827),
  (13, 5, 0, 63, 'Org · Actor      · Identidad Org · timezone',    'org.g5.d0.timezone',    5828);
```

#### Entradas para `cfg_policy_library` (D00)

| Clave | Estándar | Valor de referencia |
|-------|----------|---------------------|
| `D00.tenant.is_internal.valores` | SBOS-MODEL-D00 | `true` (skull interno) / `false` (externo) |
| `D00.bdomain.type.valores` | SBOS-MODEL-D00 / ISO 9001:2015 | `empresa`, `persona`, `hogar`, `desarrollador`, `m2m`, `edificio` |
| `D00.bsubdomain.type.valores` | SBOS-MODEL-D00 | `sucursal`, `dependiente`, `familiar`, `oficina` |
| `D00.pos.type.valores` | SBOS-MODEL-D00 | `caja`, `terminal`, `puerta`, `sensor`, `actuador`, `punto_virtual` |
| `D00.actor.type.valores` | ISO 24760-2:2025 §4.1 | `HUMAN`, `SERVICE`, `DEVICE`, `BOT` |
| `D00.actor.employee_type.valores` | SCIM Enterprise §4.3 | `FULL_TIME`, `PART_TIME`, `CONTRACTOR`, `INTERN` |
| `D00.actor.gender.valores` | SCIM 2.0 RFC 7643 §4.1.2 | `M`, `F`, `NB` (no-binario), `NR` (no revelado) |
| `D00.actor.locale.formato` | BCP 47 / SCIM 2.0 | `es-BO`, `en-US`, `pt-BR` |
| `D00.actor.timezone.formato` | IANA TZ / SCIM 2.0 | `America/La_Paz`, `America/Santiago` |
| `D00.ctxid.formato` | SBOS-049 §5.3 | `interno.tenant.bdomain.bsubdomain` (4 segmentos) |
| `D00.ctxid.profundidad` | SBOS-MODEL-D00 | 4 niveles: is_internal · tenant_uuid · bdomain_uuid · bsubdomain_uuid |

---

### D1 — LÓGICO (Acceso Lógico / RBAC)

#### Estándares normativos

| Estándar | Control | Qué define |
|----------|---------|-----------|
| NIST SP 800-53 Rev.5 | AC-1 a AC-25 | Marco completo de control de acceso: MAC, DAC, RBAC, ABAC |
| NIST SP 800-53 Rev.5 | AC-2 | Gestión de cuentas: creación, revisión, desactivación |
| NIST SP 800-53 Rev.5 | AC-3(7) | Role-Based Access Control obligatorio |
| NIST SP 800-53 Rev.5 | AC-6 | Menor privilegio: acceso mínimo necesario |
| NIST SP 800-53 Rev.5 | AC-12 | Terminación de sesión por inactividad |
| ANSI INCITS 359-2004 | — | Estándar RBAC: roles, sesiones, permisos, jerarquía |
| ISO 27001:2022 | A.9.1 | Política de control de acceso |
| ISO 27001:2022 | A.9.2.5 | Revisión periódica de derechos de acceso (≥ anual) |
| ISO 27001:2022 | A.9.2.6 | Revocación de acceso al terminar empleo |
| NIST SP 800-207 | §2-3 | Zero Trust: identidad como perímetro, verificación continua |

#### Tablas operativas (prefijo `log_` / `zone_`)

| Tabla | Propósito | Norma base |
|-------|-----------|-----------|
| `log_zone` | Zonas lógicas de acceso (tenant, empresa, sucursal, pos) | ISO 27001 A.9.1 |
| `zone_application_map` | Aplicaciones accesibles por zona | NIST AC-3 |
| `zone_record_rule` | Reglas SQL de filtrado por zona (row-level security) | NIST AC-4 |
| `zone_field_restriction` | Campos ocultos o enmascarados por zona | NIST AC-3(6) |
| `zone_button_rule` | Botones/acciones habilitados por zona en UI | NIST AC-3 |
| `zone_data_policy` | Políticas de datos por zona (clasificación, retención) | ISO 27001 A.8.1 |

#### Átomos REGLA en `privilege_atom` (D1, parametrizan por rol)

| Átomo `d.a.m.v` | Tipo | Valor de referencia normativo |
|-----------------|:----:|------------------------------|
| `D1.bauth.logical.max_sessions` | REGLA | 1-5 (NIST AC-10: límite de sesiones simultáneas) |
| `D1.bauth.logical.privilege_review_days` | REGLA | 90 (ISO 27001 A.9.2.5: revisión trimestral) |
| `D1.bauth.logical.dormant_account_days` | REGLA | 90 (NIST AC-2(3): desactivar cuentas inactivas) |
| `D1.bauth.logical.data_classification` | REGLA | PUBLIC/INTERNAL/CONFIDENTIAL/SECRET |
| `D1.bauth.logical.least_privilege_enforced` | REGLA | true (NIST AC-6: obligatorio) |
| `D1.bauth.logical.scope` | REGLA | tenant/empresa/sucursal/pos |

#### Entradas para `cfg_policy_library` (nuevas si no existen)

| Clave | Estándar | Valor de referencia |
|-------|----------|---------------------|
| `D1.account.dormant_threshold_days` | NIST AC-2(3) | 90 |
| `D1.access.review_frequency_days` | ISO 27001 A.9.2.5 | 90 |
| `D1.privilege.least_privilege_required` | NIST AC-6 | true |
| `D1.session.max_concurrent` | NIST AC-10 | 3 (por defecto) |
| `D1.rbac.hierarchy_enabled` | ANSI INCITS 359 §3.1 | true |
| `D1.zt.continuous_verification` | NIST SP 800-207 §2.1 | true |

---

### D2 — FÍSICO (Control de Acceso Físico)

#### Estándares normativos

| Estándar | Control | Qué define |
|----------|---------|-----------|
| ISO 27001:2022 | A.7.1 | Perímetros de seguridad física (vallas, muros, puertas, vigilancia) |
| ISO 27001:2022 | A.7.2 | Entrada física: RFID, biometría, llaves — verificación de identidad |
| ISO 27001:2022 | A.7.3 | Seguridad de oficinas, salas e instalaciones |
| ISO 27001:2022 | A.7.4 | Monitoreo físico continuo (cámaras, sensores) |
| ANSI/SIA OSDP v2.2 | — | Open Supervised Device Protocol: comunicación cifrada con controladores |
| NIST SP 800-116 Rev.1 | — | PIV para control de acceso físico y lógico (PACS) |
| IEC 62443-3-3 | SR 2.1 | Control de acceso físico en sistemas industriales |

#### Tablas operativas (prefijo `fis_`)

| Tabla | Propósito | Norma base |
|-------|-----------|-----------|
| `fis_access_zone` | Zonas físicas (niveles 0=público … 3=máxima seguridad) | ISO 27001 A.7.1 |
| `fis_controller` | Controladores OSDP (readers, paneles) | ANSI/SIA OSDP v2.2 |
| `fis_device` | Dispositivos: lectores RFID, cámaras, sensores PIR | ISO 27001 A.7.4 |
| `fis_location` | Ubicaciones físicas georreferenciadas | NIST SP 800-116 |
| `fis_zone_method_requirement` | Método de autenticación requerido por zona | ISO 27001 A.7.2 |
| `fis_emergency_config` | Configuración de emergencia (fail-safe vs fail-secure) | IEC 62443-3-3 SR 2.1 |

#### Átomos REGLA en `privilege_atom` (D2, parametrizan por rol)

| Átomo `d.a.m.v` | Tipo | Valor de referencia normativo |
|-----------------|:----:|------------------------------|
| `D2.bauth.physical.max_security_zone` | REGLA | 0-3 (zona máxima accesible) |
| `D2.bauth.physical.requires_escort` | REGLA | true/false (ISO 27001 A.7.2) |
| `D2.bauth.physical.anti_passback` | REGLA | true (previene re-entrada sin salida) |
| `D2.bauth.physical.mantrap_required` | REGLA | true/false (zonas de máxima seguridad) |
| `D2.bauth.physical.entry_method` | REGLA | RFID/BIOMETRIC/PIN/MANTRAP |
| `D2.bauth.physical.tailgating_detection` | REGLA | true/false |

#### Entradas para `cfg_policy_library`

| Clave | Estándar | Valor de referencia |
|-------|----------|---------------------|
| `D2.pacs.osdp_required` | ANSI/SIA OSDP v2.2 | true (comunicación cifrada) |
| `D2.pacs.anti_passback_enabled` | ISO 27001 A.7.2 | true |
| `D2.pacs.log_audit_frequency_days` | ISO 27001 A.7.4 | 30 (revisión mensual de logs) |
| `D2.pacs.escort_required_zone` | ISO 27001 A.7.2 | 3 (zona 3 = escolta obligatoria) |
| `D2.pacs.fail_safe_default` | IEC 62443-3-3 SR 2.1 | open (incendio → abrir puertas) |

---

### D3 — FINANCIERO

#### Estándares normativos

| Estándar | Control | Qué define |
|----------|---------|-----------|
| PCI DSS 4.0 | Req. 7 | Restricción de acceso a datos de pago según necesidad |
| PCI DSS 4.0 | Req. 7.1.1 | Acceso mínimo necesario para funciones de negocio |
| PCI DSS 4.0 | Req. 10 | Registro y monitoreo de accesos a recursos financieros |
| SOX §302/§404 | — | SoD en sistemas de información financiera; controles internos auditables |
| SWIFT CSP v2025 | Control 5.1 | Restricción de acceso a sistema SWIFT por función |
| SWIFT CSP v2025 | Control 5.4 | Registro de transacciones con trazabilidad de operador |
| NIST SP 800-53 | AC-5 | Separación de deberes: autorización ≠ registro ≠ custodia ≠ reconciliación |
| ISO 27001:2022 | A.8.2 | Gestión de acceso privilegiado en operaciones financieras |
| SIN Bolivia RND 102100000011 | — | Facturación electrónica: firma digital del emisor, trazabilidad por NIT |

#### Tablas operativas (prefijo `fin_`)

| Tabla | Propósito | Norma base |
|-------|-----------|-----------|
| `fin_approval_chain` | Cadena de aprobación por monto (N niveles) | SOX §404, SWIFT CSP 5.1 |
| `fin_decision_matrix` | Matriz: monto × tipo operación → nivel aprobación requerido | PCI DSS 7.1.1 |
| `fin_sod_rule` | Pares de roles en conflicto SoD (EMITIR ≠ APROBAR) | NIST AC-5, SOX §302 |
| `fin_document_operation` | Operaciones permitidas por tipo de documento contable | SIN RND 102100000011 |

#### Átomos REGLA en `privilege_atom` (D3, parametrizan por rol)

| Átomo `d.a.m.v` | Tipo | Valor de referencia normativo |
|-----------------|:----:|------------------------------|
| `D3.bauth.financial.max_daily` | REGLA | Límite diario en BOB (configurable por rol) |
| `D3.bauth.financial.max_transaction` | REGLA | Monto máximo por transacción |
| `D3.bauth.financial.requires_dual_approval` | REGLA | true/false (SOX: aprobación dual para montos altos) |
| `D3.bauth.financial.approval_levels` | REGLA | 1-4 (niveles de aprobación requeridos) |
| `D3.bauth.financial.currency` | REGLA | BOB/USD/EUR (ISO 4217) |
| `D3.bauth.financial.sod_enforced` | REGLA | true (NIST AC-5: obligatorio) |

#### Entradas para `cfg_policy_library`

| Clave | Estándar | Valor de referencia |
|-------|----------|---------------------|
| `D3.sod.emitir_vs_aprobar` | NIST AC-5, SOX §302 | conflicto: EMITIR_FACTURA ∩ APROBAR_PAGO = ∅ |
| `D3.sod.crear_vs_autorizar` | NIST AC-5 | conflicto: CREAR_ORDEN ∩ AUTORIZAR_PAGO = ∅ |
| `D3.approval.dual_threshold_bob` | SOX §404 | 50000 (aprobación dual > BOB 50,000) |
| `D3.audit.transaction_log_required` | PCI DSS Req. 10 | true |
| `D3.access.min_need_principle` | PCI DSS 7.1.1 | true |

---

### D4 — TEMPORAL

#### Estándares normativos

| Estándar | Control | Qué define |
|----------|---------|-----------|
| ISO 27001:2022 | A.9.1.1 | Política de control de acceso incluye restricciones horarias |
| ISO 27001:2022 | Control 8.17 | Sincronización de relojes: NTP obligatorio, fuente confiable |
| NIST SP 800-53 | AC-2(9) | Cuentas con restricción de tiempo: acceso solo en horario autorizado |
| NIST SP 800-53 | AC-11 | Bloqueo de sesión por inactividad (relacionado con horario) |
| ISO 8601 | — | Formato estándar de fecha/hora: YYYY-MM-DDTHH:MM:SSZ |
| IANA Timezone DB | — | Zonas horarias: America/La_Paz, UTC, etc. |
| ILO Convention 1 (1919) | — | Jornada laboral máxima: 8h/día, 48h/semana (referencia laboral) |

#### Tablas operativas (prefijo `cal_` en schema `bcalendar`)

| Tabla | Propósito | Norma base |
|-------|-----------|-----------|
| `cal_calendar` | Calendarios por tenant (laboral, fiscal, académico) | ISO 8601 |
| `cal_event` | Eventos específicos (mantenimiento, fechas especiales) | ISO 8601 |
| `cal_holiday` | Feriados nacionales y regionales por tenant | ILO + Ley laboral Bolivia |
| `cal_schedule` | Horarios de trabajo: días, horas, turnos | NIST AC-2(9) |
| `cal_alarm` | Alarmas de acceso y notificaciones de expiración | ISO 27001 A.9.1.1 |
| `cal_overtime_policy` | Política de horas extra (requiere autorización) | ILO Convention 1 |
| `cal_fiscal_year` | Año fiscal por tenant (Bolivia: enero-diciembre) | SIN Bolivia |

#### Átomos REGLA en `privilege_atom` (D4, parametrizan por rol)

| Átomo `d.a.m.v` | Tipo | Valor de referencia normativo |
|-----------------|:----:|------------------------------|
| `D4.bauth.temporal.schedule_id` | REGLA | UUID del horario asignado (cal_schedule) |
| `D4.bauth.temporal.allow_overtime` | REGLA | false (NIST AC-2(9): acceso solo en horario) |
| `D4.bauth.temporal.timezone` | REGLA | America/La_Paz (IANA — ISO 8601) |
| `D4.bauth.temporal.allow_holidays` | REGLA | false (por defecto) |
| `D4.bauth.temporal.grace_period_minutes` | REGLA | 5 (tolerancia de ingreso/salida) |
| `D4.bauth.temporal.max_session_hours` | REGLA | 8 (ILO: jornada estándar) |

#### Entradas para `cfg_policy_library`

| Clave | Estándar | Valor de referencia |
|-------|----------|---------------------|
| `D4.clock.ntp_sync_required` | ISO 27001 Control 8.17 | true |
| `D4.clock.max_drift_seconds` | ISO 27001 Control 8.17 | 5 |
| `D4.schedule.overtime_requires_auth` | NIST AC-2(9) | true |
| `D4.schedule.holiday_access_denied` | NIST AC-2(9) | true (por defecto) |
| `D4.datetime.format_standard` | ISO 8601 | YYYY-MM-DDTHH:MM:SSZ |

---

### D5 — BIOMÉTRICO

#### Estándares normativos

| Estándar | Control | Qué define |
|----------|---------|-----------|
| NIST SP 800-63B Rev.4 | §5.2.3 | FMR ≤ 1/1000 obligatorio; liveness detection para AAL2 y AAL3 |
| NIST SP 800-76-2 | — | Especificaciones biométricas PIV: huella, iris, cara — formatos, resolución, calidad |
| ISO/IEC 30107-3 | — | PAD (Presentation Attack Detection): APCER, BPCER; Nivel 1 y Nivel 2 |
| ISO/IEC 24745:2022 | §6.2-6.4 | Protección de plantillas: irreversibilidad, desvinculabilidad, renovabilidad |
| ISO/IEC 19794 (serie) | — | Formatos de datos biométricos por modalidad (huella, iris, cara, voz, vena) |
| ISO/IEC 19795-10:2024 | — | Performance biométrico por grupos demográficos (equidad) |
| FIDO2 / WebAuthn W3C | §5 | Biometría local como factor "algo que eres" para autenticadores FIDO2 |
| GDPR Art. 9 | — | Biometría = categoría especial; consentimiento explícito + minimización |

#### Tablas operativas (prefijo `bio_`) — **NUEVAS: no existen en BD actual**

| Tabla | Propósito | Norma base |
|-------|-----------|-----------|
| `bio_modal_config` | Modalidades disponibles por sistema (FINGERPRINT, IRIS, FACE, VOICE, VEIN, PALM) y sus parámetros técnicos | ISO/IEC 19794 |
| `bio_enrollment_policy` | Políticas de enrolamiento: calidad mínima, muestras requeridas, intentos máximos | NIST SP 800-76-2 |
| `bio_matching_threshold` | Umbrales FMR/FNMR/FAR/FRR por modalidad y caso de uso | NIST SP 800-63B §5.2.3 |
| `bio_pad_policy` | Anti-spoofing: APCER/BPCER máximos, nivel PAD requerido (1 o 2) | ISO/IEC 30107-3 |
| `bio_template_policy` | Protección de plantillas: algoritmo cifrado, irreversibilidad, unlinkability, renovabilidad | ISO/IEC 24745:2022 |

#### Átomos REGLA en `privilege_atom` (D5, parametrizan por rol)

| Átomo `d.a.m.v` | Tipo | Valor de referencia normativo |
|-----------------|:----:|------------------------------|
| `D5.bauth.biometric.fmr_threshold` | REGLA | 0.001 (NIST SP 800-63B: FMR ≤ 1/1000) |
| `D5.bauth.biometric.pad_level_required` | REGLA | 2 (ISO 30107-3 Nivel 2 para AAL3) |
| `D5.bauth.biometric.liveness_required` | REGLA | true (NIST SP 800-63B AAL2+) |
| `D5.bauth.biometric.allowed_modalities` | REGLA | FINGERPRINT,IRIS (separado por coma) |
| `D5.bauth.biometric.max_attempts` | REGLA | 3 (antes de bloqueo) |
| `D5.bauth.biometric.template_retention_days` | REGLA | 365 (GDPR Art. 5(1)(e)) |

#### Entradas para `cfg_policy_library`

| Clave | Estándar | Valor de referencia |
|-------|----------|---------------------|
| `D5.matching.fmr_max` | NIST SP 800-63B Rev.4 §5.2.3 | 0.001 |
| `D5.pad.apcer_max_level1` | ISO/IEC 30107-3 | 0.20 |
| `D5.pad.apcer_max_level2` | ISO/IEC 30107-3 | 0.01 |
| `D5.pad.bpcer_max` | ISO/IEC 30107-3 | 0.05 |
| `D5.template.irreversible` | ISO/IEC 24745:2022 §6.2 | true |
| `D5.template.unlinkable` | ISO/IEC 24745:2022 §6.3 | true |
| `D5.template.renewable` | ISO/IEC 24745:2022 §6.4 | true |
| `D5.gdpr.special_category` | GDPR Art. 9 | explicit_consent |
| `D5.liveness.aal2_required` | NIST SP 800-63B §5.2.3 | true |
| `D5.liveness.aal3_required` | NIST SP 800-63B §5.2.3 | true |
| `D5.enrollment.min_quality_score` | NIST SP 800-76-2 §2 | 0.70 |
| `D5.equity.demographic_parity` | ISO/IEC 19795-10:2024 | FMR igual entre grupos demográficos |

---

### D6 — GEOESPACIAL

#### Estándares normativos

| Estándar | Control | Qué define |
|----------|---------|-----------|
| NIST SP 800-207 | §3.3 | Location como señal de riesgo contextual en Zero Trust |
| NIST SP 800-53 | AC-17 | Acceso remoto: control y monitoreo por origen geográfico |
| ISO 27001:2022 | A.9.1 | Política de acceso incluye restricciones por ubicación |
| GDPR Art. 44-46 | — | Restricciones a transferencias internacionales de datos personales |
| ISO 3166-1 alpha-2 | — | Códigos de país estándar (BO, US, BR, etc.) |
| IANA Timezone DB | — | Zonas horarias ligadas a ubicación geográfica |
| EBA ICT Risk Guidelines | §4.3 | Para instituciones financieras: geo-restricciones en acceso a sistemas críticos |

#### Tablas operativas (prefijo `geo_`)

| Tabla | Propósito | Norma base |
|-------|-----------|-----------|
| `geo_fence` | Geocercas definidas (polígonos lat/lon, radios) | NIST SP 800-207 §3.3 |
| `geo_trust_tier` | Niveles de confianza por zona geográfica (local, nacional, internacional) | NIST SP 800-207 |
| `geo_velocity_policy` | Velocidad máxima de desplazamiento (anti impossible travel) | EBA ICT Risk Guidelines |
| `geo_location_log` | Log de ubicaciones de autenticación (auditoría forense) | ISO 27001 A.8.15 |

#### Átomos REGLA en `privilege_atom` (D6, parametrizan por rol)

| Átomo `d.a.m.v` | Tipo | Valor de referencia normativo |
|-----------------|:----:|------------------------------|
| `D6.bauth.geo.allowed_countries` | REGLA | BO (ISO 3166-1; por defecto solo Bolivia) |
| `D6.bauth.geo.cross_border_allowed` | REGLA | false (GDPR Art. 44: restricción transferencia) |
| `D6.bauth.geo.geo_velocity_max_kmh` | REGLA | 800 (impossible travel: > 800 km/h = alerta) |
| `D6.bauth.geo.fence_id` | REGLA | UUID de geocerca asignada |
| `D6.bauth.geo.vpn_bypass_allowed` | REGLA | false (VPN no evade georestrición) |
| `D6.bauth.geo.trust_tier` | REGLA | LOCAL/NATIONAL/INTERNATIONAL |

#### Entradas para `cfg_policy_library`

| Clave | Estándar | Valor de referencia |
|-------|----------|---------------------|
| `D6.zt.location_as_risk_signal` | NIST SP 800-207 §3.3 | true |
| `D6.velocity.impossible_travel_kmh` | EBA ICT Risk Guidelines | 800 |
| `D6.gdpr.cross_border_restriction` | GDPR Art. 44 | restricted |
| `D6.remote.geo_restricted_by_default` | NIST SP 800-53 AC-17 | true |
| `D6.country.default_allowed` | ISO 3166-1 | BO |

---

### D7 — RED

#### Estándares normativos

| Estándar | Control | Qué define |
|----------|---------|-----------|
| NIST SP 800-207 | — | Zero Trust Architecture: "Never trust, always verify" — verificar identidad antes de red |
| NIST SP 800-207A | — | Zero Trust para aplicaciones cloud-nativas y multi-cloud |
| ISO 27001:2022 | A.8.20 | Seguridad de redes: segmentación, monitoreo |
| ISO 27001:2022 | A.8.21 | Seguridad de servicios de red: SLAs, cifrado en tránsito |
| ISO 27001:2022 | A.8.22 | Segregación de redes (VLAN, microsegmentación) |
| CIS Controls v8 | Control 12 | Network Infrastructure Management: inventario, segmentación, monitoreo |
| NSA/CISA ZTNA | — | Zero Trust Maturity Model: pilares de identidad, dispositivo, red, aplicación, datos |
| RFC 8705 | — | mTLS para OAuth 2.0 (certificate-bound tokens) — obligatorio para transacciones de alto valor |
| RFC 9449 | — | DPoP: Demonstrating Proof of Possession — vinculación criptográfica de token a dispositivo |
| NIST SP 800-53 | SC-7 | Boundary Protection: firewalls, DMZ, flujo de tráfico |

#### Tablas operativas (prefijo `net_`)

| Tabla | Propósito | Norma base |
|-------|-----------|-----------|
| `net_device` | Dispositivos de red registrados (endpoints, VPN gateways) | NIST SP 800-207, CIS Control 12 |
| `net_ztna_policy` | Políticas ZTNA: segmentos, microsegmentación, acceso condicional | NSA/CISA ZTNA |

#### Átomos REGLA en `privilege_atom` (D7, parametrizan por rol)

| Átomo `d.a.m.v` | Tipo | Valor de referencia normativo |
|-----------------|:----:|------------------------------|
| `D7.bauth.network.vpn_required` | REGLA | true/false (NIST SP 800-207) |
| `D7.bauth.network.mtls_required` | REGLA | true (RFC 8705: alta seguridad) |
| `D7.bauth.network.min_tls_version` | REGLA | TLS1.3 (NSA/CISA recomendación 2024) |
| `D7.bauth.network.allowed_ips` | REGLA | CIDR blocks autorizados |
| `D7.bauth.network.device_compliance_required` | REGLA | true (NSA/CISA ZTNA) |
| `D7.bauth.network.dpop_required` | REGLA | true (RFC 9449: token binding a dispositivo) |

#### Entradas para `cfg_policy_library`

| Clave | Estándar | Valor de referencia |
|-------|----------|---------------------|
| `D7.zt.never_trust_always_verify` | NIST SP 800-207 §2 | true |
| `D7.tls.min_version` | NSA/CISA ZTNA 2024 | TLS1.3 |
| `D7.mtls.required_high_value` | RFC 8705 | true |
| `D7.dpop.enabled` | RFC 9449 | true |
| `D7.network.segmentation_required` | CIS Control 12.2, ISO 27001 A.8.22 | true |
| `D7.device.compliance_check` | NSA/CISA ZTNA | true |

---

### D8 — CONTEXTO (Sesiones y Riesgo)

#### Estándares normativos

| Estándar | Control | Qué define |
|----------|---------|-----------|
| NIST SP 800-63B Rev.4 | §7.1 | Session binding obligatorio a autenticador |
| NIST SP 800-63B Rev.4 | §7.2 | Reauthenticación periódica: AAL1 ≤ 30d, AAL2 ≤ 12h, AAL3 ≤ 12h con HW |
| NIST SP 800-63B Rev.4 | §7.3 | Terminación de sesión: logout, expiración, revocación por incidente |
| NIST SP 800-53 | AC-12 | Session termination: timeout por inactividad |
| OpenID Connect Core 1.0 | §7 | Session Management: front-channel y back-channel logout |
| CAEP (RFC draft) | — | Continuous Access Evaluation Protocol: revocación en tiempo real por evento de riesgo |
| OWASP Session Mgmt | §3.3 | Session ID ≥ 128 bits; HttpOnly; Secure; SameSite=Strict |
| ISO 27001:2022 | A.8.2 | Gestión de acceso privilegiado: sesiones de admins con timeout estricto |

#### Tablas operativas (prefijo `ses_`)

| Tabla | Propósito | Norma base |
|-------|-----------|-----------|
| `ses_context` | Contexto de sesión activo: ctx_id, identity atoms, estado, timestamps | NIST SP 800-63B §7 |
| `ses_context_switch` | Historial de cambios de contexto (empresa/sucursal) | NIST SP 800-63B §7.3 |
| `ses_ses_risk_policy` | Política de riesgo: umbral para Step-Up, fuentes de riesgo | CAEP, NIST SP 800-207 |
| `ses_caep_config` | Configuración CAEP: streams, suscriptores, eventos | CAEP RFC draft |

#### Átomos REGLA en `privilege_atom` (D8, parametrizan por rol)

| Átomo `d.a.m.v` | Tipo | Valor de referencia normativo |
|-----------------|:----:|------------------------------|
| `D8.bauth.session.ttl_max` | REGLA | 43200 (12h en segundos — NIST SP 800-63B §7.2 AAL2) |
| `D8.bauth.session.inactivity_timeout` | REGLA | 1800 (30min — NIST SP 800-53 AC-11) |
| `D8.bauth.session.max_contexts` | REGLA | 1 (un contexto activo por usuario por defecto) |
| `D8.bauth.session.context_switch_allowed` | REGLA | true/false (¿puede cambiar empresa/sucursal?) |
| `D8.bauth.session.risk_threshold` | REGLA | 70 (score > 70 → Step-Up obligatorio) |
| `D8.bauth.session.caep_enabled` | REGLA | true (revocación continua) |

#### Entradas para `cfg_policy_library`

| Clave | Estándar | Valor de referencia |
|-------|----------|---------------------|
| `D8.session.ttl_aal1_seconds` | NIST SP 800-63B §7.2 | 2592000 (30 días) |
| `D8.session.ttl_aal2_seconds` | NIST SP 800-63B §7.2 | 43200 (12h) |
| `D8.session.ttl_aal3_seconds` | NIST SP 800-63B §7.2 | 43200 (12h con HW) |
| `D8.session.inactivity_timeout_seconds` | NIST SP 800-53 AC-11 | 1800 |
| `D8.session.id_min_bits` | OWASP Session Mgmt §3.3 | 128 |
| `D8.caep.realtime_revocation` | CAEP RFC draft | true |
| `D8.session.binding_required` | NIST SP 800-63B §7.1 | true |

---

### D9 — CREDENCIALES

#### Estándares normativos

| Estándar | Control | Qué define |
|----------|---------|-----------|
| NIST SP 800-63B Rev.4 | §5.1.1 | Memorized Secrets: mínimo 15 caracteres, sin expiración periódica obligatoria |
| NIST SP 800-63B Rev.4 | §5.1.1.2 | Verificar contra listas de contraseñas comprometidas (HIBP) |
| NIST SP 800-63B Rev.4 | §5.1.7 | Lookback verification: contraseña no repetida (últimas N) |
| NIST SP 800-63A Rev.4 | §4 | Identity Proofing: IAL1 (self-assertion), IAL2 (remote), IAL3 (in-person) |
| FIDO2 / WebAuthn W3C | — | Passkeys: autenticador criptográfico sin contraseña; hardware-bound o synced |
| RFC 9470 | — | Step-Up Authentication: promover sesión a LoA superior sin re-login completo |
| OWASP ASVS v5.0 | §2.1-2.5 | Requisitos de verificación: passwords, MFA, lookback, hibp |
| NIST SP 800-132 | — | Password-Based Key Derivation: Argon2id como algoritmo preferido |
| RFC 6238 | — | TOTP: Time-Based One-Time Password (Google Authenticator compatible) |
| RFC 4226 | — | HOTP: HMAC-Based One-Time Password |

#### Tablas operativas (prefijo `ath_`)

| Tabla | Propósito | Norma base |
|-------|-----------|-----------|
| `ath_method` | Métodos de autenticación disponibles por sistema | NIST SP 800-63B |
| `ath_login_attempt` | Intentos de login: éxito, fallo, bloqueo | OWASP ASVS §2.2 |
| `ath_mfa_enrollment` | Enrolamientos MFA por usuario y método | NIST SP 800-63B §6 |
| `ath_binding` | Vinculación de dispositivos (device-bound authenticators) | FIDO2, RFC 9449 |
| `ath_password_history` | Historial de contraseñas (lookback) | NIST SP 800-63B §5.1.7 |
| `ath_recovery_method` | Métodos de recuperación registrados | NIST SP 800-63B §6.1.2.3 |

#### Átomos REGLA/MÉTODO en `privilege_atom` (D9, parametrizan por rol)

| Átomo `d.a.m.v` | Tipo | Valor de referencia normativo |
|-----------------|:----:|------------------------------|
| `D9.bauth.credential.min_length` | REGLA | 15 (NIST SP 800-63B Rev.4 §5.1.1) |
| `D9.bauth.credential.max_length` | REGLA | 128 (NIST: permitir contraseñas largas) |
| `D9.bauth.credential.hibp_enabled` | REGLA | true (NIST SP 800-63B §5.1.1.2) |
| `D9.bauth.credential.history_lookback` | REGLA | 5 (últimas 5 contraseñas prohibidas) |
| `D9.bauth.credential.argon2id_enabled` | REGLA | true (NIST SP 800-132) |
| `D9.bauth.method.PASSWORD` | MÉTODO | AAL1 |
| `D9.bauth.method.TOTP` | MÉTODO | AAL2 (RFC 6238) |
| `D9.bauth.method.HOTP` | MÉTODO | AAL2 (RFC 4226) |
| `D9.bauth.method.WEBAUTHN_PWDLESS` | MÉTODO | AAL2-AAL3 (FIDO2) |
| `D9.bauth.method.WEBAUTHN_2FA` | MÉTODO | AAL2-AAL3 (FIDO2) |
| `D9.bauth.method.PASSKEY` | MÉTODO | AAL2-AAL3 (FIDO2 synced) |
| `D9.bauth.method.X509_MTLS` | MÉTODO | AAL3 (RFC 8705) |

#### Entradas para `cfg_policy_library`

| Clave | Estándar | Valor de referencia |
|-------|----------|---------------------|
| `D9.password.min_length` | NIST SP 800-63B Rev.4 §5.1.1 | 15 |
| `D9.password.max_length` | NIST SP 800-63B Rev.4 §5.1.1 | 128 |
| `D9.password.no_periodic_expiry` | NIST SP 800-63B Rev.4 §5.1.1 | true (NO rotar obligatoriamente) |
| `D9.password.hibp_check` | NIST SP 800-63B §5.1.1.2 | true |
| `D9.password.kdf_algorithm` | NIST SP 800-132 | Argon2id |
| `D9.mfa.aal2_required_by_default` | NIST SP 800-63B §4.2 | true |
| `D9.ial.remote_proofing_level` | NIST SP 800-63A §4.2 | IAL2 |
| `D9.passkey.preferred_authenticator` | FIDO2 W3C | platform (device-bound preferred) |
| `D9.stepup.rfc_9470_enabled` | RFC 9470 | true |

---

### D10 — DELEGACIÓN

#### Estándares normativos

| Estándar | Control | Qué define |
|----------|---------|-----------|
| RFC 8693 | §2.1 | OAuth 2.0 Token Exchange: semántica de delegación e impersonación; claim `act` |
| RFC 7519 | §4.1 | JWT claims estándar; `act` claim para delegación en cadena |
| RFC 8705 | — | mTLS para tokens de delegación (certificate-bound) |
| ISO 27001:2022 | A.5.3 | Segregación de deberes: delegación NO puede crear conflictos SoD |
| NIST SP 800-53 | AC-6 | Menor privilegio: no se pueden delegar más privilegios de los que se tienen |
| NIST SP 800-53 | AC-2 | Gestión de cuentas delegadas: revisión y revocación |
| ISO 29115:2013 | — | Entity Authentication Assurance: delegación preserva LoA del origen |

#### Tablas operativas (prefijo `dlg_`)

| Tabla | Propósito | Norma base |
|-------|-----------|-----------|
| `dlg_delegation` | Delegaciones activas e históricas: delegante, receptor, átomos delegados, TTL | RFC 8693, NIST AC-2 |

#### Átomos REGLA en `privilege_atom` (D10, parametrizan por rol)

| Átomo `d.a.m.v` | Tipo | Valor de referencia normativo |
|-----------------|:----:|------------------------------|
| `D10.bauth.delegation.enabled` | REGLA | true/false (¿el rol puede delegar?) |
| `D10.bauth.delegation.max_depth` | REGLA | 2 (RFC 8693: cadena máxima de 2 saltos) |
| `D10.bauth.delegation.max_duration_days` | REGLA | 30 (NIST AC-2: revisión periódica) |
| `D10.bauth.delegation.source` | REGLA | UUID del delegante (claim `act`) |
| `D10.bauth.delegation.requires_mfa` | REGLA | true (AAL2 mínimo para delegar) |
| `D10.bauth.delegation.revocable_anytime` | REGLA | true (delegante puede revocar en cualquier momento) |

#### Entradas para `cfg_policy_library`

| Clave | Estándar | Valor de referencia |
|-------|----------|---------------------|
| `D10.delegation.max_privilege_escalation` | NIST AC-6 | false (no delegar más de lo que se tiene) |
| `D10.delegation.sod_check_required` | ISO 27001 A.5.3 | true (verificar conflictos SoD en delegación) |
| `D10.delegation.act_claim_required` | RFC 8693 §2.1 | true |
| `D10.delegation.loa_preserved` | ISO 29115:2013 | true (LoA origen ≥ LoA delegado) |
| `D10.delegation.revocation_propagation_seconds` | NIST AC-2 | 30 (revocación en < 30s) |
| `D10.delegation.max_chain_depth` | RFC 8693 | 2 |

---

### D11 — AUDITORÍA

#### Estándares normativos

| Estándar | Control | Qué define |
|----------|---------|-----------|
| ISO 27001:2022 | A.8.15 | Logging: producir, proteger, almacenar y analizar eventos. WORM obligatorio |
| ISO 27001:2022 | A.8.17 | Sincronización de relojes: NTP para timestamps de auditoría |
| NIST SP 800-92 Rev.1 | — | Cybersecurity Log Management: generación, protección, retención, análisis |
| NIST SP 800-53 | AU-1 a AU-16 | Familia completa de auditoría y responsabilidad |
| NIST SP 800-53 | AU-9 | Protección de información de auditoría: WORM, hash-chain |
| NIST SP 800-53 | AU-11 | Retención de registros de auditoría: mínimo 12 meses online + 36 meses total |
| PCI DSS 4.0 | Req. 10 | Log y monitoreo: protección de logs de modificación; retención 12 meses mínimo |
| PCI DSS 4.0 | 10.3.3 | Logs respaldados en sistema separado del que los origina |
| SOX §404 | — | Audit trail para información financiera: inmutable, con timestamp, acceso controlado |
| GDPR Art. 5(1)(e) | — | Limitación de almacenamiento: no más de lo necesario para el propósito |
| NIST IR 8403 | — | Blockchain for Access Control Systems: inmutabilidad criptográfica |

#### Tablas operativas (prefijo `aud_`)

| Tabla | Propósito | Norma base |
|-------|-----------|-----------|
| `aud_event` | Eventos auditados WORM: quién, qué, cuándo, desde dónde, resultado | ISO 27001 A.8.15, NIST AU-2 |
| `aud_review` | Revisiones periódicas de acceso y privilegios | ISO 27001 A.9.2.5, SOX §404 |
| `aud_compliance_map` | Mapeo de eventos a controles normativos (ISO, NIST, PCI) | NIST AU-1 |
| `aud_ghost_account` | Cuentas fantasma detectadas (activas sin uso) | NIST AC-2(3), ISO 27001 A.9.2.6 |

#### Átomos REGLA en `privilege_atom` (D11, parametrizan por rol)

| Átomo `d.a.m.v` | Tipo | Valor de referencia normativo |
|-----------------|:----:|------------------------------|
| `D11.bauth.audit.level` | REGLA | MINIMAL/STANDARD/VERBOSE/FORENSIC |
| `D11.bauth.audit.retention_days` | REGLA | 365 (PCI DSS Req. 10 mínimo) |
| `D11.bauth.audit.immutability_required` | REGLA | true (ISO 27001 A.8.15, NIST AU-9) |
| `D11.bauth.audit.hash_chain_enabled` | REGLA | true (integridad SHA-256) |
| `D11.bauth.audit.siem_export_enabled` | REGLA | true (NIST AU-6: revisión de logs) |
| `D11.bauth.audit.review_frequency_days` | REGLA | 30 (NIST AU-6: revisión mensual mínima) |

#### Entradas para `cfg_policy_library`

| Clave | Estándar | Valor de referencia |
|-------|----------|---------------------|
| `D11.log.worm_required` | ISO 27001 A.8.15, NIST AU-9 | true |
| `D11.log.hash_algorithm` | NIST SP 800-175B | SHA-256 |
| `D11.log.retention_hot_days` | PCI DSS 10.7, NIST AU-11 | 90 |
| `D11.log.retention_cold_days` | NIST AU-11, PCI DSS 10.7 | 365 |
| `D11.log.backup_separate_system` | PCI DSS 10.3.3 | true |
| `D11.log.ntp_sync_required` | ISO 27001 A.8.17 | true |
| `D11.review.frequency_days` | NIST AU-6 | 30 |
| `D11.event.min_required_fields` | NIST AU-3 | user_id,action,timestamp,ip,result,ctx_id |

---

### D12 — BLOCKCHAIN

#### Estándares normativos

| Estándar | Control | Qué define |
|----------|---------|-----------|
| NIST IR 8403 (2022) | — | Blockchain for Access Control Systems: integridad, trazabilidad, no-repudio |
| NIST SP 800-175B Rev.1 | — | Cryptographic Standards: SHA-256 para nodos Merkle, Ed25519 para firmas |
| NIST SP 800-209 | — | Security Guidelines for Storage: inmutabilidad de almacenamiento de evidencia |
| ISO/TC 307 — ISO 22739 | — | Blockchain: terminología y conceptos fundamentales |
| ISO/TC 307 — ISO 23257 | — | Distributed Ledger Technologies: arquitectura de referencia |
| IEEE 2418.2 | — | Standard for Data Format for Blockchain Systems |
| W3C DID Core v1.0 | — | Decentralized Identifiers: identidad autodescriptiva en blockchain |
| eIDAS 2.0 (UE) | — | Firma electrónica con valor legal en registros inmutables distribuidos |
| Ley 164 Bolivia | Art. 5 | Firma digital con validez jurídica: equivale a firma manuscrita |

#### Tablas operativas (prefijo `blk_`)

| Tabla | Propósito | Norma base |
|-------|-----------|-----------|
| `blk_anchor` | Anclas de integridad: hash de lote + tx_hash en blockchain externo | NIST IR 8403 |
| `blk_merkle_batch` | Lotes de eventos para árbol Merkle | NIST SP 800-175B |
| `blk_merkle_leaf` | Hojas del árbol Merkle (hash individual de cada evento) | NIST SP 800-175B |
| `blk_account` | Cuentas blockchain para firmar transacciones (ECDSA secp256k1) | W3C DID |
| `blk_reconciliation` | Reconciliación de anclas: verificación periódica de integridad | NIST SP 800-209 |

#### Átomos REGLA en `privilege_atom` (D12, parametrizan por rol)

| Átomo `d.a.m.v` | Tipo | Valor de referencia normativo |
|-----------------|:----:|------------------------------|
| `D12.bauth.blockchain.enabled` | REGLA | true/false (obligatorio para roles SU/SYS) |
| `D12.bauth.blockchain.anchor_freq_events` | REGLA | 1000 (anclar cada 1000 eventos) |
| `D12.bauth.blockchain.anchor_freq_seconds` | REGLA | 3600 (anclar cada 1h como mínimo) |
| `D12.bauth.blockchain.merkle_enabled` | REGLA | true (NIST SP 800-175B) |
| `D12.bauth.blockchain.variant` | REGLA | ARBITRUM/ETHEREUM/HYPERLEDGER |
| `D12.bauth.blockchain.public_verification` | REGLA | true (pruebas verificables externamente) |

#### Entradas para `cfg_policy_library`

| Clave | Estándar | Valor de referencia |
|-------|----------|---------------------|
| `D12.merkle.hash_algorithm` | NIST SP 800-175B | SHA-256 |
| `D12.anchor.frequency_events` | NIST IR 8403 | 1000 |
| `D12.anchor.frequency_seconds` | NIST IR 8403 | 3600 |
| `D12.anchor.public_verifiable` | NIST IR 8403 | true |
| `D12.did.standard` | W3C DID Core v1.0 | did:ethr (Ethereum DID method) |
| `D12.signature.algorithm` | NIST SP 800-175B | Ed25519 (interno) + ECDSA secp256k1 (externo) |
| `D12.legal.bolivia_ley164` | Ley 164 Bolivia Art. 5 | firma digital con validez jurídica |

---

### 12.1 Resumen: Tablas nuevas requeridas por dominio

Las siguientes tablas **no existen actualmente en la BD** y deben crearse en el rediseño:

| Dominio | Tablas nuevas | Justificación |
|---------|--------------|---------------|
| D5 — Biométrico | `bio_modal_config`, `bio_enrollment_policy`, `bio_matching_threshold`, `bio_pad_policy`, `bio_template_policy` | ISO 30107-3, ISO 24745:2022, NIST SP 800-76-2 |
| D12 — Blockchain | (tablas `blk_*` ya existen — verificar completitud) | NIST IR 8403 |

Las tablas de D1, D2, D3, D4, D6, D7, D8, D9, D10, D11, D12 **ya existen** según el catálogo actual.
El trabajo en estos dominios es **verificar que los átomos REGLA/MÉTODO correspondientes
existan en `privilege_atom` con los valores normativos correctos** y que `cfg_policy_library`
contenga las entradas de referencia normativa para cada dominio.

### 12.2 Entradas faltantes en `cfg_policy_library`

Con base en esta investigación, las entradas de `cfg_policy_library` que **deben verificarse
y agregarse si no existen** son las definidas en las tablas de cada dominio bajo "Entradas
para `cfg_policy_library`" de esta sección. En total: **~65 entradas nuevas** distribuidas
en los 12 dominios.

### 12.3 Corrección a §2.5 del documento

La fila original de D5 en §2.5:

> ~~D5 — Biométrico | — | (absorbido en privilege_atom tipo REGLA) | Parámetros biométricos~~

**Se reemplaza por:**

| Dominio | Prefijo | Tablas | Propósito |
|---------|---------|--------|-----------|
| D5 — Biométrico | `bio_` | `bio_modal_config`, `bio_enrollment_policy`, `bio_matching_threshold`, `bio_pad_policy`, `bio_template_policy` | Enrolamiento; umbrales FMR/FNMR (NIST SP 800-76-2); anti-spoofing PAD APCER/BPCER (ISO 30107-3); protección de plantillas ISO 24745:2022 (irreversibilidad, unlinkability, renovabilidad); GDPR Art. 9 |

---

*BAUTH-ARQUITECTURA-ATOMICA-FINAL.md v3.0 · 2026-06-30*
*Arquitectura de contabilidad dimensional para identidad y acceso · 12 partes*
*Parte 12 agregada: Estructura de Políticas por Dominio — 12 dominios, 65+ entradas normativas*
