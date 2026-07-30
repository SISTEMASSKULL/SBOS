# A.68 — Catálogo de Propiedades de Átomos (RolTemplate)
**Versión:** 3.0 · **Fecha:** 2026-07-21 · **Estado:** ACTIVO  
**Fuente:** `src/desktop/lib/datos/rol_template_datos.dart` — 3 826 líneas, 282 `_ef()`, 291 átomos `_ev()`  
**Alineación normativa:** `SBOS-0XX-ATOM-CONFORMIDAD-XACML-ABAC.md` (documento de referencia canónico)

> **v3.0:** Alineación completa con SBOS-0XX-ATOM-CONFORMIDAD-XACML-ABAC.md — 6 correcciones
> estructurales: A.1 `clave`≠descripción (no-conformidad XACML §4.1), Target vs Condition explícito
> (§4.3), Obligation vs Advice separados (§4.4), categorías ABAC NIST 800-162 (§4.5), F.6 `clave`
> como slug (nueva clase de error), Sección J checklist de conformidad (§5). PIP / Context Plane
> identificado como cuarto punto funcional NIST SP 800-162.

---

## Propósito

Cataloga **todas** las propiedades que aparecen en los nodos `evaluacion` (átomo) del árbol
RolTemplate, con un ejemplo de valor representativo y su clasificación.  
**Propósitos:**  
1. Referencia completa para serializar el árbol a T-162 (`idn_roles_template`)  
2. Inventario de errores con correcciones exactas — base de trabajo para la reparación del árbol  
3. Verificación de alineación normativa contra XACML 3.0, NIST, ISO 27001, FIDO2, OAuth2/CAEP  
4. Propuesta de nueva capacidad: `TipoNodo.normativo` para citaciones explícitas a estándares

---

## Resumen de tipos de propiedad

| Tipo | Descripción corta | Nodo Dart | Columna T-162 principal |
|------|-------------------|-----------|-------------------------|
| **A** | Estructura XACML del átomo — `clave`/`help`/`id`, `verbo`, `combining_algorithm` | `enumerado` | `tipo`, `valor` |
| **B** | Condition XACML y atributos ABAC (prop · op · val) + categorías NIST 800-162 | `evaluacion` / `atributo` | `clave`, `valor` |
| **C** | Efecto, Obligaciones y Advice — con distinción vinculante/informativo (SBOS-0XX §4.4) | `evaluacion` (hijo de regla) | `valor`, `opciones[]` |
| **D** | Metadatos del bloque o átomo | `atributo` | `clave`, `valor` |
| **E** | Campos enumerados de estado | `enumerado` | `valor`, `opciones[]` |
| **F** | Errores detectados con correcciones exactas (F.1–F.6: 10 clases) | — | — (pre-reparación) |
| **G** | Mapa completo propiedad → columna T-162 (con corrección `clave`=slug, `help`=description) | — | Referencia de serialización |
| **H** | Alineación con 8 normas internacionales (XACML, NIST, ISO, FIDO2, OAuth, PCI, Ley 164) | — | Verificación normativa |
| **I** | Nueva observación: `TipoNodo.normativo` — citaciones normativas estructuradas | `normativo` (propuesta) | `normativo_refs[]` (propuesta) |
| **J** | Checklist de Conformidad SBOS-0XX §5 — estado árbol actual vs 8 criterios | — | Plan de reparación priorizado |
| **K** | Índice de dominios de propiedad (§B.1) — 49 namespaces catalogados | — | Referencia rápida de dominios |

---

## A — Estructura XACML del átomo

Estas propiedades definen **la identidad y topología** del átomo dentro del árbol de políticas.
Todo nodo `evaluacion` (átomo) las tiene o debería tenerlas.

### A.1 Identidad del átomo: `clave` (RuleId) vs `help` (Description)

> **⚠️ CORRECCIÓN CRÍTICA — SBOS-0XX §4.1:** el primer argumento de `_ev()` en el árbol
> Dart almacena **texto de negocio en español** (`'quórum de aprobadores'`). Según XACML 3.0,
> ese texto corresponde al elemento `<Description>` (mapea a `help` en T-162), **NO** al
> `RuleId` (mapea a `clave`). La `clave` debe ser un **slug técnico estable** en `snake_case`,
> sin tildes, sin espacios, no traducible — porque sirve para referenciar el átomo desde
> logs, auditoría y otras políticas.

#### A.1.1 `clave` — Identificador técnico estable (equivalente a `RuleId` XACML)

**Tipo:** identificador técnico (slug)  
**Nodo:** `evaluacion` (la clave del nodo en T-162)  
**Columna T-162:** `clave` — `snake_case`, ASCII, sin espacios, sin tildes, sin caracteres especiales  
**Regla:** estable, único por dominio, no editable por negocio, no traducible

| Texto de negocio actual (primer arg `_ev()`) | Slug propuesto para `clave` | Criterio de slug |
|-----------------------------------------------|----------------------------|-----------------|
| `'quórum de aprobadores'` | `quorum.aprobadores` | `.` como separador — no colisiona con identificadores Dart/Rust |
| `'verbo privilegiado'` | `verbo.privilegiado` | partes en minúsculas sin tildes |
| `'certificado mTLS presente → x509'` | `cert.mtls.x509` | jerarquía con puntos |
| `'riesgo bajo'` | `riesgo.bajo` | sin tildes |
| `'crm.lead — lectura de oportunidades'` | `crm.lead.read` | verbo al final cuando aplica |
| `'escalación automática'` | `escalacion.automatica` | sin tildes |
| `'zona sensible'` | `zona.sensible` | descriptor de condición |
| `'SLA de respuesta'` | `sla.respuesta` | acrónimo en minúsculas |

> **Formato de slug recomendado:**  
> `{dominio}.{acción_o_condición}` — ej: `d02.quorum.aprobadores`, `d01.cert.mtls.x509`.  
> El separador `.` distingue visualmente los slugs de los identificadores de código (variables
> en Dart/Rust son snake_case — el punto no es carácter válido en nombres de variable).
> El namespace por dominio previene colisiones entre D00–D13/D98/D99.

#### A.1.2 `help` — Descripción legible de negocio (equivalente a `Description` XACML)

**Tipo:** texto libre en español  
**Nodo:** `evaluacion` (parámetro `help:` de `_ev()`)  
**Columna T-162:** `help` — texto libre, legible por humanos, en español  
**Regla:** nunca sustituye a `clave`. Puede cambiar sin afectar referencias.

| Valor de `help` (rol = Description XACML) |
|--------------------------------------------|
| `'Quórum mínimo de aprobadores distintos para operación de alto valor'` |
| `'Verbo de acción privilegiado — requiere autenticación de hardware'` |
| `'Certificado mTLS presente — método de autenticación x509'` |
| `'Nivel de riesgo bajo — aplica policy estándar sin step-up'` |

> **En el árbol Dart actual:** el primer argumento de `_ev('texto', [...])` actúa como
> `Description` (va a `help`) y NO hay un slug explícito para `clave`. La reparación
> consiste en generar el slug en el proceso de compilación/serialización AtomLang → T-162,
> o bien hacerlo explícito en el árbol Dart con un parámetro `id:` adicional en `_ev()`.

#### A.1.3 `id` (UUIDv7) — Equivalente completo de `RuleId` XACML

**Tipo:** UUIDv7 (inmutable)  
**Columna T-162:** `id` — asignado por `SEQUENCE` gobernado, nunca ad-hoc  
**Norma:** SBOS-0XX §4.6 — "ningún átomo debe crearse fuera del flujo gobernado"

> La combinación `id` (estabilidad técnica) + `clave` (slug semántico estable) + `help`
> (descripción de negocio) implementa completamente el elemento `<Rule RuleId="..." Description="...">` de XACML 3.0 con separación de roles.

---

### A.2 `verbo` — Elemento `Target.Action` XACML 3.0

> **SBOS-0XX §4.3 — Target vs Condition:**  
> El `verbo` es el elemento de **indexación rápida (Target)** — determina si el átomo es
> *candidato* a evaluarse para el request. Es el equivalente del elemento XACML `<Target>
> → <AnyOf> → <AllOf> → <Match>` sobre el atributo de acción.  
> La lógica de evaluación real (prop+op+val) es la **Condition** — diferente e independiente.  
> Los motores XACML reales indexan por Target y solo evalúan Condition en átomos que
> pasaron el Target. Esta distinción tiene implicaciones directas en el PrivilegeEngine
> de bAuth (optimización de búsqueda en B-tree sobre `verb_id`).

**Tipo:** enumerado (15 valores)  
**Nodo:** `enumerado` (hijo directo de `evaluacion`)  
**Columna T-162:** `clave='verbo'`, `tipo='enumerado'`, `opciones[]`, `verb_id` (FK)  
**Origen Dart:** parámetro `verbo:` en `_ev()` o `NodoTemplate('verbo', ...)`

| Valor | Frecuencia | Descripción |
|-------|-----------|-------------|
| `read` | 88 | Lectura/consulta de recursos |
| `execute` | 39 | Ejecución de operaciones/métodos |
| `configure` | 38 | Configuración del sistema |
| `access` | 31 | Acceso a recursos o zonas |
| `login` | 22 | Inicio de sesión / autenticación |
| `create` | 13 | Creación de registros |
| `approve` | 10 | Aprobación de operaciones |
| `ANY` | 8 | Cualquier verbo (wildcard) |
| `write` | 8 | Escritura / modificación |
| `audit` | 5 | Auditoría / revisión |
| `delegate` | 5 | Delegación de permisos |
| `delete` | 3 | Eliminación de registros |
| `export` | 3 | Exportación de datos |
| `emit` | 3 | Emisión (firma, documento, token) |
| `validate` | 1 | Validación de entidades |

> **⚠️ REPARACIÓN:** 291 nodos `_ev()` no tienen parámetro `verbo:` explícito. El árbol
> actual crea nodos verbo manualmente con `NodoTemplate(...)` en algunos casos — esto es
> inconsistente. Al serializar a T-162, todo átomo debe tener un nodo `verbo` hijo.

---

### A.3 `combining_algorithm` — Algoritmo de combinación de efectos

**Tipo:** enumerado (4 valores)  
**Nodo:** `enumerado` (hijo de bloque o átomo)  
**Columna T-162:** `clave='combining_algorithm'`, `tipo='enumerado'`

| Valor | Frecuencia | Semántica XACML |
|-------|-----------|----------------|
| `deny-overrides` | 164 | Un DENY basta para bloquear (por defecto) |
| `first-applicable` | 9 | Primera regla que aplica gana |
| `aggregate-strictest` | 2 | Agrega el LoA más restrictivo |
| `permit-overrides` | 1 | Un PERMIT basta para permitir |

---

### A.4 `op_lógico` — Conector lógico entre evaluaciones

**Tipo:** enumerado (2 valores usados en árbol)  
**Nodo:** `enumerado` (conector entre dos `evaluacion` dentro de `regla`)  
**Columna T-162:** `clave='op_lógico'`, `tipo='enumerado'`

| Valor | Frecuencia | Semántica |
|-------|-----------|----------|
| `OR` | 8 | Al menos una condición debe cumplirse |
| `AND` | 7 | Todas las condiciones deben cumplirse |

> **Nota:** `MATCH_ALL` está definido en el vocabulario AtomLang pero no aparece en el árbol
> Dart actual. Los nodos `condiciones[]` del árbol fuente usan `valor: 'MATCH_ALL'` — cuando
> se compilen a Dart deben mapear a `AND`.

---

## B — Condition XACML y atributos ABAC del átomo

> **SBOS-0XX §4.3 — Condition** (distinto de Target):  
> El triplete `propiedad + operador + valor` implementa el elemento XACML `<Condition>` —
> la expresión booleana que, una vez que el átomo fue considerado **candidato** (por el Target
> `verbo`), decide si el efecto se dispara.  
> **En el árbol actual estos dos elementos están colapsados** en la misma lista de hijos de
> `_ev()`, sin distinción explícita. Esto es funcional pero no estrictamente conforme con
> XACML 3.0 que los define como estructuras separadas con roles diferentes.  
> La separación explícita permitiría al PrivilegeEngine indexar por `verb_id` (Target) antes
> de evaluar la lógica ABAC (Condition), optimizando el B-tree de evaluación.

> **SBOS-0XX §4.5 — Categorías ABAC (NIST SP 800-162):**  
> Cada propiedad (`_prop`) debe pertenecer a una de cuatro categorías. La categoría es
> relevante para trazabilidad de auditoría — un auditor IAM debe poder ver, por átomo,
> qué categorías de atributo participaron en la decisión.

| Categoría NIST SP 800-162 | Definición | Props del árbol |
|--------------------------|-----------|----------------|
| **Subject** | Entidad activa que solicita acceso (usuario, proceso, dispositivo) | `user.*`, `role.*`, `session.*`, `delegation.*`, `approval.*` |
| **Object/Resource** | Lo que el Subject solicita acceder | `record.*`, `field.*`, `zone.*`, `ui.*`, `invoice.*`, `contract.*` |
| **Operation/Action** | La función solicitada sobre el objeto | `action.*`, `contract.method_name` |
| **Environment** | Condiciones operacionales situacionales — Context Plane | `device.*`, `location.*`, `time.*`, `risk.*`, `connection.*`, `cert.*`, `gps_attestation.*`, `date.*`, `facility.*` |

> **PIP — Policy Information Point (SBOS-0XX §3):**  
> El `bos.GetContext()` del Context Plane actúa como **PIP** en el modelo NIST SP 800-162 —
> es el punto que resuelve y provee los valores de atributo al PDP (bAuth) en tiempo de
> evaluación. Las props de categoría `Environment` (device, location, risk, etc.) son
> provistas por el PIP, no almacenadas en T-162. Las de categoría `Subject` provienen
> de la sesión autenticada. Las de `Object/Resource` provienen del contexto del request.

### B.1 `propiedad` — Atributo del sujeto o contexto evaluado (XACML Condition term)

**Tipo:** atributo (path semántico)  
**Nodo:** `atributo` (clave='propiedad')  
**Columna T-162:** `clave='propiedad'`, `tipo='atributo'`  
**Total únicas:** 150  
**Categoría ABAC:** indicada entre corchetes en cada subdominio

#### B.1.a Dominio `account.*` — Cuenta de usuario
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `account.days_since_last_login` | `> 90` (días) |

#### B.1.b Dominio `action.*` — Acción solicitada
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `action.verb` | `IN [CONFIGURE, ADMIN, DELETE]` |
| `action.zone` | `== zone_financial` |

> **⚠️ REPARACIÓN:** `_prop('action.verb')` con `_op('IN')` sobre verbos privilegiados es
> redundante si el átomo ya tiene `verbo: 'configure'` como Target-gate. Ver comentario en
> línea 542: *"una condición secundaria sobre action.verb sería redundante y causaría
> case-sensitivity bugs"*. Candidato a eliminar del árbol.

#### B.1.c Dominio `api_request.*` — Solicitud API
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `api_request.dpop_header_present` | `== true` |

#### B.1.d Dominio `approval.*` — Flujo de aprobación
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `approval.count_distinct_approvers` | `>= 2` |
| `approval.elapsed_hours` | `<= @bauth_config_param.sla_timeout_hours` |
| `approver.hierarchy_level` | `> hierarchy_level del solicitante` |

#### B.1.e Dominio `audit.*` — Auditoría
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `audit.event_level` | `== CRITICAL` |
| `audit.event_type` | `IN [PERMISSIONS, AUTH_METHODS, DELEGATIONS, FINANCIAL_LIMITS, ...]` |
| `audit.retention_years` | `>= 7` |
| `audit_log.hash_chain_valid` | `== true` |

#### B.1.f Dominio `auth_request.*` — Solicitud de autenticación
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `auth_request.code_challenge_method` | `== S256 (SHA-256)` |

#### B.1.g Dominio `biometric.*` — Biometría
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `biometric.false_match_rate` | `<= [0.50, 0.70]` (rango BETWEEN) |

#### B.1.h Dominio `blockchain.*` — Transacciones blockchain
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `blockchain.transaction_value` | `<= B8.transaction_limits.single_transaction_limit` |

#### B.1.i Dominio `cert.*` — Certificados digitales
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `cert.days_until_expiry` | `> 7` |
| `cert.is_expired` | `== false` |
| `cert.issuer` | `IN [ADSIB, CA_TRUSTED_LIST_BOLIVIA]` |
| `cert.policy_type` | `IN [ADSIB-FD-POLT-015 v2.3, CA_TRUSTED_LIST_BOLIVIA]` |
| `cert.revoked` | `== false` |

#### B.1.j Dominio `conflict.*` — Conflictos SoD
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `conflict.check_scope` | `== REGIONAL` |
| `conflict.evaluation_timing` | `== REAL_TIME` |
| `conflict_declaration.days_since_last_submitted` | `<= 90` |

#### B.1.k Dominio `connection.*` — Conexión de red
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `connection.client_cert_present` | `== true` |
| `connection.client_cert_valid` | `== true` |
| `connection.token_binding_status` | `== CURRENT` |
| `connection.type` | `== REMOTE` |
| `connection.vpn_active` | `== true` |

#### B.1.l Dominio `context.*` — Contexto de evaluación
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `context.requires_aal3` | `== true` |
| `ctx.justificacion_presente` | `== true` |
| `ctx.subject_also_approver_in_zone` | `== false` |

#### B.1.m Dominio `contract.*` — Contrato de acceso
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `contract.access_mode` | `== APPEND_ONLY` |
| `contract.method_name` | `STARTS_WITH tryton.sale.configuration.` |

#### B.1.n Dominio `credential.*` — Credenciales
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `credential.binding_type` | `IN [DIRECT, INHERITED, DELEGATED]` |
| `credential.breach_detected` | `== false` |
| `credential.hash_algorithm` | `IN [Argon2id(t>=3,m>=64MB,p>=2)]` |

#### B.1.o Dominio `d4_temporal_ref` / `d6_geospatial_ref` — Delegaciones a dominios
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `d4_temporal_ref` | `== D4.B2.validity_period + D8.B17.context_signals` |
| `d6_geospatial_ref` | `== D6.B15.allowed_locations[]` |

> **Nota:** Estas propiedades no son condiciones booleanas — son referencias a otros dominios.
> Su operador es `==` pero el valor es una referencia semántica, no un literal evaluable.
> Clasificar como **prop de tipo REFERENCIA** en T-162 (diferente a prop de tipo COMPARACIÓN).

#### B.1.p Dominio `date.*` — Fecha
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `date.day_of_month` | `IN [13,14,15,28,29,30,31]` |

#### B.1.q Dominio `delegation.*` — Delegación de permisos
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `delegation.permission` | `IN [clientes.lista, clientes.ficha, clientes.editar, ...]` |
| `delegation.target_role.hierarchy_level` | `<= hierarchy_level del delegante` |

#### B.1.r Dominio `descuento.*` — Descuentos
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `descuento.porcentaje` | `<= @bauth_config_param.max_descuento_tier1` |

#### B.1.s Dominio `device.*` — Dispositivo del usuario
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `device.antivirus_active` | `== true` |
| `device.has_nfc_reader` | `== true` |
| `device.host_firewall_active` | `== true` |
| `device.mdm_enrolled` | `== true` |
| `device.os_patch_status` | `== CURRENT` |
| `device.storage_encrypted` | `== true` |

#### B.1.t Dominio `emergency.*` — Sesión de emergencia
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `emergency.distinct_approvals` | `>= 2` |
| `emergency.notification_sent` | `== true` |
| `emergency.session_duration_hours` | `<= 4` |

#### B.1.u Dominio `enrollment.*` — Registro/inscripción
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `enrollment.approval_count` | `>= 1` |
| `enrollment.liveness_check` | `== true` |
| `enrollment.mode` | `== CONTINUOUS` |

#### B.1.v Dominio `event.*` — Eventos de seguridad
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `event.dual_badge_sequence_detected` | `== true` |

#### B.1.w Dominio `facility.*` — Instalación física
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `facility.alert_level` | `IN [HIGH, CRITICAL]` |

#### B.1.x Dominio `field.*` — Campo de dato (enmascaramiento/acceso a nivel campo)
| Propiedad | Ejemplo valor | Nota |
|-----------|--------------|------|
| `field.account_invoice.internal_note` | `apply_mask lastFour` | Enmascarar dato |
| `field.account_payment.cbu` | `apply_mask lastFour` | CBU bancario |
| `field.contact.birthdate` | `apply_mask domain_only` | Fecha de nacimiento |
| `field.contact.email_address` | `apply_mask domain_only` | Email → solo dominio |
| `field.contact.national_id` | `apply_mask lastFour` | DNI/CI |
| `field.crm_lead.estimated_revenue` | `visible_to_role [DIRECTOR_VENTAS, ...]` | Visibilidad por rol |
| `field.crm_lead.expected_revenue` | `visible_to_role [DIRECTOR_VENTAS, HR_DIRECTOR]` | |
| `field.crm_lead.partner_phone` | `apply_mask lastFour` | Teléfono enmascarado |
| `field.crm_lead.phone` | `apply_mask lastFour` | |
| `field.employee.medical_details` | `apply_mask domain_only` | Datos médicos |
| `field.employee.national_id` | `apply_mask lastFour` | |
| `field.employee.salary` | `visible_to_role [FINANCE_DIRECTOR, CEO]` | Solo visibilidad |
| `field.notification.ctx_trace_id` | `visible_to_role [DIRECTOR_VENTAS, COMPLIANCE_OFFICER]` | |
| `field.pos_order.margin` | `apply_mask lastFour` | Margen POS |
| `field.res_partner.bank_account` | `apply_mask lastFour` | Cuenta bancaria |
| `field.res_partner.dni` | `apply_mask lastFour` | |
| `field.sale_line.unit_price` | `visible_to_role [DIRECTOR_VENTAS, COMPLIANCE_OFFICER]` | |
| `field.sale_sale.margin` | `visible_to_role [GERENTE_VENTAS]` | |
| `field.search_result.unit_price` | `apply_mask lastFour` | |

> **Nota:** Las props `field.*` son la interfaz de **Data Masking**. Usan operadores especiales:
> `apply_mask` y `visible_to_role` — no son comparaciones booleanas sino instrucciones de
> transformación. El valor de `apply_mask` es la política de máscara (ver `_val`).

#### B.1.y Dominio `gps_attestation.*` — Atestación GPS
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `gps_attestation.accuracy_meters` | `<= @bauth_config_param.gps_accuracy_meters` |

#### B.1.z Dominio `identity_proofing.*` — Prueba de identidad IAL
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `identity_proofing.level` | `IN [IAL1, IAL2, IAL3]` |

#### B.1.aa Dominio `invoice.*` — Factura
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `invoice.amount_total` | `> @bauth_config_param.financial_high_threshold` |

#### B.1.ab Dominio `location.*` — Ubicación
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `location.roaming` | `== false` |
| `location.type` | `IN [DATACENTER, VAULT, SERVER_ROOM]` |
| `location.velocity_km_h` | `<= @bauth_config_param.max_velocity_km_h` |

#### B.1.ac Dominio `login.*` — Intentos de login
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `login.attempt_window_minutes` | Referenciado en BETWEEN |
| `login.failed_attempts_in_window` | `>= @bauth_config_param.max_failed_attempts` |

#### B.1.ad Dominio `notification.*` — Notificaciones
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `notification.channel` | `== rocket_chat` |

#### B.1.ae Dominio `override.*` — Anulaciones
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `override.requested_by_role` | `IN [DIRECTOR_VENTAS, COMPLIANCE_OFFICER]` |

#### B.1.af Dominio `password.*` / `password_policy.*` — Contraseñas
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `password.in_breached_list` | `== false` |
| `password.in_history_last_N` | `== false` |
| `password.length` | `>= @bauth_config_param.password_min_length_mfa` |
| `password_policy.complexity_rules_enforced` | `== false` |
| `password_policy.hints_enabled` | `== false` |
| `password_policy.periodic_rotation_days` | `== (cualquier valor periódico)` |
| `password_policy.security_questions_enabled` | `== false` |

#### B.1.ag Dominio `permission.*` — Análisis de permisos
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `permission.days_since_last_review` | `<= 90` |
| `permission.unused_ratio` | `<= 0.50` |

#### B.1.ah Dominio `query.*` — Consultas
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `query.record_count` | `<= @bauth_config_param.max_query_records` |
| `query.result_count` | `<= @bauth_config_param.max_query_records` |

#### B.1.ai Dominio `record.*` — Registro de datos (row-level security)
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `record.account_id` | `== user.company_id` |
| `record.amount_total` | `<= @bauth_config_param.approval_threshold_tier2` |
| `record.assigned_user_id` | `== user.id` |
| `record.company_id` | `== user.company_id` |
| `record.date` | `IN [user.fiscal_year_start, user.fiscal_year_end]` |
| `record.department_id` | `IN user.managed_department_ids[]` |
| `record.employee_id` | `== user.employee_id` |
| `record.recipient_id` | `== user.id` |
| `record.requester_id` | `== user.id` |
| `record.salesperson_id` | `== user.id` |
| `record.session_id` | `== user.pos_session_id` |
| `record.supervisor_id` | `== user.employee_id` |
| `record.team_id` | `INTERSECT user.sales_team_ids[]` |
| `record.territory_code` | `IN user.territory_codes[]` |
| `record.user_id` | `== user.id` |
| `record.zone_classification` | `IN [INTERNAL, PUBLIC]` |

> **Nota:** Las props `record.*` implementan **Row-Level Security (RLS)** en bAuth. El valor
> siempre es una referencia al contexto del usuario autenticado (`user.*`). Son el puente
> entre los permisos de rol y el acceso a filas individuales de la base de datos.

#### B.1.aj Dominio `renewal.*` — Renovación de asignación
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `renewal.approver_role` | `IN [DIRECTOR_VENTAS, HR_DIRECTOR]` |
| `renewal.auto_renewal` | `== false` |

#### B.1.ak Dominio `request.*` — Solicitud HTTP/API
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `request.rate_per_minute` | `<= @bauth_config_param.rate_limit_per_minute` |
| `request.source_cidr` | `STARTS_WITH 192.168.` |

#### B.1.al Dominio `revocation.*` — Revocación de acceso
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `revocation.grace_period_days` | `<= 0` |
| `revocation.propagated_to` | `IN [vault, gateway_kong, cache_redis, session_store]` |
| `revocation.propagation_elapsed_seconds` | `<= 30` |

#### B.1.am Dominio `risk.*` — Puntuación de riesgo
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `risk.anomaly_detected` | `== false` |
| `risk.evaluation_mode` | `== CONTINUOUS` |
| `risk.score` | `<= 0.30` |

#### B.1.an Dominio `role.*` — Propiedades del rol activo
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `role.level_of_assurance` | `>= 2` |
| `role_assignment.renewal_count` | `<= 3` |

#### B.1.ao Dominio `schedule.*` — Ventana horaria
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `schedule.in_authorized_window` | `== true` |

#### B.1.ap Dominio `session.*` — Sesión activa
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `session.concurrent_active_count` | `<= 1` |
| `session.device_fingerprint_valid` | `== true` |
| `session.duration_minutes` | `<= @bauth_config_param.session_max_duration_minutes` |
| `session.idle_minutes` | `<= @bauth_config_param.session_reauth_minutes` |
| `session.mfa_enrolled` | `== true` |
| `session.minutes_since_last_auth` | `<= 30` |

#### B.1.aq Dominio `signing.*` — Firma digital
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `signing.algorithm` | `== ECDSA secp256k1` |
| `signing.direct_node_access` | `== false` |
| `signing.key_storage_location` | `== VAULT` |

#### B.1.ar Dominio `termination.*` — Baja de empleado
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `termination.approval_count` | `>= 2` |
| `termination.approver_role` | `IN [DIRECTOR_VENTAS, HR_DIRECTOR]` |
| `termination.notice_period_days` | `<= 30` |

#### B.1.as Dominio `time.*` — Hora local
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `time.hour_local` | `BETWEEN [09:00, 16:00]` |

#### B.1.at Dominio `transaction.*` — Monto de transacción
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `transaction.amount` | `<= @bauth_config_param.approval_threshold_tier2` |

#### B.1.au Dominio `ui.*` — Interfaz de usuario
| Propiedad | Ejemplo valor | Nota |
|-----------|--------------|------|
| `ui.action_id` | `max_access [bsearch.export_results]` | Limitar acciones UI |
| `ui.menu_id` | `max_access [bsearch.search_bar, bsearch.advanced_search, ...]` | Limitar menús UI |

> **Nota:** Las props `ui.*` con `max_access` controlan **visibilidad de UI** — no bloquean
> acceso a datos sino qué elementos de menú/acción son visibles. Son propiedades de
> presentación, no de autorización de datos.

#### B.1.av Dominio `user.*` — Contexto del usuario autenticado
| Propiedad | Ejemplo valor | Nota |
|-----------|--------------|------|
| `user.active_roles` | `NOT_INCLUDES_ALL [ROL_CREADOR_VENTA, ROL_APROBADOR_VENTA]` | SoD |
| `user.concurrent_roles` | `<= 64 (máximo aceptado)` | Límite u64 |
| `user.supervisor_relationship_degree` | `<= 2` | Grado de parentesco org |

#### B.1.aw Dominio `wallet.*` — Wallet cripto
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `wallet.compromised_flag` | `== false` |

#### B.1.ax Dominio `zone.*` — Zona de acceso
| Propiedad | Ejemplo valor |
|-----------|--------------|
| `zone.id` | `STARTS_WITH zone_financial` |
| `zone.physical_security_level` | `>= 3` |
| `zone.scope` | `== REGIONAL` |
| `zone.security_level` | `>= HIGH` |
| `zone.sensitivity` | `== CRITICAL` |
| `zone.type` | `IN [PHY_ROOM_SERVIDOR, PHY_ZONE_ALMACEN, PHY_ZONE_VENTAS]` |

---

### B.2 `operador` — Operador de comparación

**Tipo:** enumerado (16 valores)  
**Nodo:** `atributo` (clave='operador')  
**Columna T-162:** `clave='operador'`, `tipo='enumerado'`, `opciones[]`

| Operador | Frec. | Tipo | Ejemplo de uso |
|----------|-------|------|---------------|
| `==` | 96 | Igualdad | `risk.score == 0.30` |
| `>` | 31 | Mayor que | `approval.count_distinct_approvers > 2` |
| `IN` | 31 | Pertenencia a conjunto | `cert.issuer IN [ADSIB, ...]` |
| `NOT_IN` | 12 | No pertenencia | `connection.type NOT_IN [REMOTE]` |
| `visible_to_role` | 10 | Visibilidad por rol | `field.salary visible_to_role [CEO]` |
| `<=` | 9 | Menor o igual | `session.idle_minutes <= 30` |
| `BETWEEN` | 9 | Rango incluido | `time.hour_local BETWEEN [09:00, 16:00]` |
| `STARTS_WITH` | 7 | Prefijo de cadena | `contract.method_name STARTS_WITH tryton.` |
| `apply_mask` | 7 | Aplicar máscara | `field.national_id apply_mask lastFour` |
| `INTERSECT` | 5 | Intersección no vacía | `record.team_id INTERSECT user.sales_team_ids[]` |
| `<` | 8 | Menor que | `risk.score < 0.50` |
| `>=` | 4 | Mayor o igual | `role.level_of_assurance >= 2` |
| `!=` | 4 | Desigualdad | `risk.anomaly_detected != true` |
| `max_access` | 2 | Limitar a elementos UI | `ui.menu_id max_access [menús...]` |
| `NOT_INCLUDES_ALL` | 2 | No contiene todos | `user.active_roles NOT_INCLUDES_ALL [ROL_A, ROL_B]` |
| `IS_SET` | 1 | El atributo existe | `ctx.justificacion_presente IS_SET` |

> **Clasificación de operadores por naturaleza:**
> - **Comparación escalar:** `==`, `!=`, `>`, `>=`, `<`, `<=`
> - **Pertenencia/conjuntos:** `IN`, `NOT_IN`, `INTERSECT`, `NOT_INCLUDES_ALL`
> - **Cadenas:** `STARTS_WITH`
> - **Rangos:** `BETWEEN`
> - **Existencia:** `IS_SET`
> - **Transformación (no booleanos):** `apply_mask`, `max_access`, `visible_to_role`

---

### B.3 `valor` — Valor de comparación

**Tipo:** atributo (literal, referencia dinámica, rango, conjunto)  
**Nodo:** `atributo` (clave='valor')  
**Columna T-162:** `clave='valor'`, `tipo='atributo'`

#### B.3.a Literales booleanos
| Valor | Frec. | Ejemplo prop |
|-------|-------|-------------|
| `true` | 27 | `device.storage_encrypted == true` |
| `false` | 19 | `credential.breach_detected == false` |

#### B.3.b Literales numéricos
| Valor | Ejemplo prop |
|-------|-------------|
| `'2'` | `approval.count_distinct_approvers >= 2` |
| `'30'` | `session.idle_minutes <= 30` |
| `'90'` | `conflict_declaration.days_since_last_submitted <= 90` |
| `'365'` | `audit.retention_years >= 365` |
| `'0.30'` | `risk.score <= 0.30` |
| `'0.50'` | `permission.unused_ratio <= 0.50` |
| `'64 (máximo aceptado)'` | `user.concurrent_roles <= 64` |

> **⚠️ REPARACIÓN:** `'64 (máximo aceptado)'` no es un número válido — tiene texto entre
> paréntesis. Debe ser `'64'` con `help:` para la nota textual.

#### B.3.c Referencias dinámicas a parámetros de configuración
| Valor | Descripción |
|-------|-------------|
| `@bauth_config_param.approval_min_approvers` | Mínimo aprobadores (multi-tenant) |
| `@bauth_config_param.approval_threshold_tier1` | Umbral financiero tier 1 |
| `@bauth_config_param.approval_threshold_tier2` | Umbral financiero tier 2 (más frecuente: 8x) |
| `@bauth_config_param.biometric_confidence_threshold` | Umbral de confianza biométrica |
| `@bauth_config_param.escalation_timeout_hours` | Timeout de escalación |
| `@bauth_config_param.financial_high_threshold` | Umbral financiero alto |
| `@bauth_config_param.gps_accuracy_meters` | Precisión GPS mínima |
| `@bauth_config_param.inactivity_days` | Días de inactividad |
| `@bauth_config_param.lockout_duration_minutes` | Duración de bloqueo |
| `@bauth_config_param.lockout_reset_minutes` | Ventana de reseteo de lockout |
| `@bauth_config_param.max_descuento_tier1` | Descuento máximo tier 1 |
| `@bauth_config_param.max_failed_attempts` | Intentos fallidos máximos |
| `@bauth_config_param.max_query_records` | Límite de registros en consulta |
| `@bauth_config_param.max_velocity_km_h` | Velocidad de ubicación máxima |
| `@bauth_config_param.password_min_length_mfa` | Longitud mínima con MFA |
| `@bauth_config_param.password_min_length_solo` | Longitud mínima sin MFA |
| `@bauth_config_param.rate_limit_per_minute` | Rate limiting API |
| `@bauth_config_param.session_max_duration_minutes` | Duración máxima sesión |
| `@bauth_config_param.session_reauth_minutes` | Ventana de re-auth |
| `@bauth_config_param.sla_timeout_hours` | SLA de aprobación |

> **Clasificación:** Los valores `@bauth_config_param.*` son **referencias parametrizadas**.
> No son literales — se resuelven en runtime contra la tabla de configuración del tenant.
> En T-162 se almacenan como texto literal; el motor los interpreta como referencias.

#### B.3.d Valores de contexto del usuario (RLS)
| Valor | Descripción |
|-------|-------------|
| `user.id` | ID del usuario autenticado |
| `user.employee_id` | ID de empleado vinculado |
| `user.company_id` | Empresa del usuario |
| `user.sales_team_ids[]` | Equipos de ventas asignados |
| `user.account_ids[]` | Cuentas contables asignadas |
| `user.managed_department_ids[]` | Departamentos gestionados |
| `user.managed_team_ids[]` | Equipos gestionados |
| `user.pos_session_id` | Sesión POS activa |
| `user.territory_codes[]` | Territorios asignados |
| `user.fiscal_year_start` / `user.fiscal_year_end` | Año fiscal activo |

#### B.3.e Rangos (para BETWEEN)
| Valor | Prop de uso |
|-------|------------|
| `[0.50, 0.70]` | `biometric.false_match_rate` |
| `[0.70, 0.90]` | `biometric.false_match_rate` |
| `[09:00, 16:00]` | `time.hour_local` |
| `[1, 2]` / `[1, 3]` / `[4, 6]` / `[7, 10]` | Rangos de nivel/cantidad |

#### B.3.f Conjuntos para IN/NOT_IN (valores de mascara y visibilidad)
| Valor | Tipo |
|-------|------|
| `lastFour` | Máscara (mostrar últimos 4 caracteres) |
| `domain_only` | Máscara (mostrar solo dominio de email) |
| `[ADSIB, CA_TRUSTED_LIST_BOLIVIA]` | Lista de CAs autorizadas |
| `[hrm.my_leave, hrm.apply_leave, hrm.leave_balance]` | Menús HRM |
| `[facturacion.lista, facturacion.nueva, ...]` | Menús Facturación |
| `[ROL_CREADOR_VENTA, ROL_APROBADOR_VENTA]` | Roles SoD |
| `[vault, gateway_kong, cache_redis, session_store]` | Sistemas de revocación |

#### B.3.g Referencias semánticas cruzadas (no literales)
| Valor | Descripción | Nota |
|-------|-------------|------|
| `D4.B2.validity_period + D8.B17.context_signals` | Referencia a otros dominios | No evaluable directamente |
| `D6.B15.allowed_locations[]` | Referencia a lista del dominio D6 | |
| `B8.transaction_limits.single_transaction_limit (enlace a D3)` | Enlace cruzado entre dominios | |
| `allowed_ranges[]` | Referencia a lista externa | |
| `hierarchy_level del delegante` | Valor dinámico del actor | |
| `hierarchy_level del solicitante` | Valor dinámico del actor | |
| `zones_access_rules[] (lista anterior)` | Referencia a lista anterior | |
| `(cualquier valor periódico)` | Placeholder no definido | **⚠️ REPARAR** |

---

## C — Efecto, Obligaciones y Advice

> **SBOS-0XX §4.4 — Obligation vs Advice:**  
> XACML 3.0 distingue dos tipos de respuesta adicional a un Effect:
>
> - **`ObligationExpression`** — el PEP (Kong) **DEBE** ejecutarla. Si no puede, debe rechazar
>   la decisión. Ejemplo: `required_loa: 'AAL2'` — si Kong no puede verificar el LoA, no puede
>   conceder acceso.
> - **`AdviceExpression`** — el PEP **PUEDE ignorarla** sin consecuencia. Es información de
>   contexto para el PEP (logging, hints de UI, razonamiento para el operador).
>
> **Estado actual en el árbol:** todas las entradas en `obl:{}` se tratan como obligaciones
> vinculantes. No existe distinción formal entre vinculante e informativo. Algunos valores
> como `permit_reason: 'schedule_day_compliant'` o `audit_level: 'NORMAL'` son semánticamente
> *advice* (no bloquean al PEP si no se evalúan), no obligaciones.
>
> **Propuesta de DDL para T-171 (`privilege_resource_atom`):**
> ```sql
> -- Columna existente ya conforma Obligation XACML (vinculante para PEP):
> -- obligation JSONB NULL — PEP (Kong) DEBE ejecutarla
>
> -- Nueva columna propuesta para Advice (informativo, PEP puede ignorar):
> ALTER TABLE bauth.privilege_resource_atom
>     ADD COLUMN advice JSONB NULL;
>
> COMMENT ON COLUMN bauth.privilege_resource_atom.obligation IS
>     'ObligationExpression XACML 3.0 — vinculante. Kong DEBE ejecutarla.';
> COMMENT ON COLUMN bauth.privilege_resource_atom.advice IS
>     'AdviceExpression XACML 3.0 — informativo. Kong puede ignorarla con seguridad.';
> ```
>
> **Claves actuales clasificadas semánticamente:**

| Clave `obl:{}` actual | Clasificación XACML | Razón |
|-----------------------|--------------------|-------|
| `required_loa` | **Obligation** | Bloquea si Kong no puede verificar |
| `min_loa` | **Obligation** | Igual que anterior |
| `require_step_up_loa` | **Obligation** | Eleva el flujo — Kong debe actuar |
| `method` | **Obligation** | Kong debe requerir el método exacto |
| `amr` | **Obligation** | Kong valida el claim AMR en el JWT |
| `require_reauth` | **Obligation** | Kong debe forzar re-autenticación |
| `http_status` | **Obligation** | Kong emite el código HTTP especificado |
| `invalidate_sessions` | **Obligation** | Revocación activa — Kong cierra sesiones |
| `status` (LOCKED/SUSPENDED) | **Obligation** | Cambio de estado — debe ejecutarse |
| `alert` | **Advice** | CISO puede ser notificado fuera de banda |
| `notify` | **Advice** | Notificación informativa — no bloquea |
| `permit_reason` | **Advice** | Solo para logging — Kong no lo evalúa |
| `audit_level` | **Advice** | Hint de auditoría — no bloquea acceso |
| `siem` | **Advice** | Destino SIEM — informativo para el motor |
| `channel` | **Advice** | Canal de notificación — post-decisión |
| `successor` | **Advice** | Hint de migración — no bloquea |

El efecto se expresa como texto descriptivo en `_ef()` más un mapa de obligation keys.
Los valores clasificados como **Advice** deberían moverse a `advice:{}` cuando se
implemente la columna T-171 propuesta.

### C.1 Texto del efecto

**Tipo:** atributo (texto descriptivo del resultado de la regla)  
**Nodo:** hijo de `regla` (tipo `evaluacion` en árbol)  
**Columna T-162:** `clave='efecto'`, `tipo='atributo'`  
**Formato:** `PERMIT · <descripción>` o `DENY · <descripción>`

| Ejemplo | Tipo |
|---------|------|
| `PERMIT · método primario: contraseña` | PERMIT simple |
| `PERMIT · step-up triple factor PCI Req 8` | PERMIT con step-up |
| `PERMIT · delegar evaluación a D6 geoespacial` | PERMIT delegación |
| `DENY · lockout 15 min` | DENY con acción |
| `DENY request sin DPoP header válido · HTTP 401` | DENY con código HTTP |
| `DENY · render=HIDDEN · AC-6(10)` | DENY de UI (ocultar elemento) |

> **Total:** 136 efectos PERMIT, 146 DENY. 0 sin clasificar.

### C.2 Obligation keys

Las obligations son acciones que el PEP (Kong) o el motor bAuth deben ejecutar
**junto** con la decisión (PERMIT/DENY). Se almacenan en `obl:{...}` dentro de `_ef()`.

**Total de claves únicas:** 57

| Clave | Frec. | Ejemplos de valor | Descripción |
|-------|-------|------------------|-------------|
| `required_loa` | 17 | `'3'`, `'AAL2'` | Nivel de aseguramiento requerido |
| `alert` | 11 | `'CISO'`, `'CISO'` | Destinatario de alerta de seguridad |
| `notify` | 10 | `'user'`, `'role_owner,security_team'` | Destinatarios de notificación |
| `action` | 9 | `'auto_expire'`, `'reset_lockout_counter'` | Acción automática del motor |
| `audit` | 9 | `'true'` | Activar registro de auditoría |
| `method` | 7 | `'username_password'`, `'webauthn_platform\|x509_smartcard'` | Método de autenticación |
| `max_age_seconds` | 6 | `'0'`, `'300'`, `'600'` | Frescura máxima del token |
| `severity` | 5 | `'CRITICAL'` | Severidad de la alerta |
| `sso_protocol` | 5 | `'OIDC'` | Protocolo SSO |
| `require` | 4 | `'admin_unlock,MFA_verify'`, `'reactivacion_manual'` | Prerequisito para desbloqueo |
| `amr` | 3 | `'pwd'`, `'fpt\|sc'`, `'sc'` | Authentication Method Reference |
| `http_status` | 3 | `'429'`, `'403'` | Código HTTP de la respuesta |
| `min_loa` | 3 | `'2'`, `'3'` | LoA mínimo exigido |
| `require_reauth` | 3 | `'true'` | Forzar re-autenticación |
| `eligible_mfa` | 2 | `'totp,push_notification'`, `'webauthn_platform,...'` | Métodos MFA elegibles |
| `flag` | 2 | `'anomaly'`, `'privilege_creep_suspected'` | Flag de seguridad |
| `require_step_up_loa` | 2 | `'3'` | Step-up de LoA |
| `siem` | 2 | `'wazuh'` | Destino SIEM |
| `status` | 2 | `'LOCKED'`, `'SUSPENDED'` | Estado de cuenta resultante |
| `users_required` | 2 | `'1'`, `'2'` | Usuarios requeridos para operación |
| `audit_level` | 2 | `'NORMAL'`, `'CRITICAL'` | Nivel de registro de auditoría |
| `audit_table` | 2 | `'audit_violations'` | Tabla de auditoría destino |
| `channel` | 2 | `'bnotify'`, `'rocket_chat'` | Canal de notificación |
| `acr` | 1 | `'aal3'` | Authentication Context Class Reference |
| `alert_on_exceed` | 1 | `'true'` | Alerta al exceder límite |
| `block_on_expiry` | 1 | `'true'` | Bloquear al expirar |
| `block_scope` | 1 | `'financial_zones'` | Alcance del bloqueo |
| `bnotify_channel` | 1 | `'rocket_chat'` | Canal bNotify específico |
| `bnotify_recipients` | 1 | `'CISO,CEO,COMPLIANCE'` | Destinatarios bNotify |
| `caep_event` | 1 | `'session-revoked'` | Evento CAEP a emitir |
| `continue_if_passes` | 1 | `'true'` | Continuar evaluación si pasa |
| `escalate_to` | 1 | `'CISO,CEO'` | Escalar a rol(es) |
| `evaluate_on` | 1 | `'every_critical_request'` | Cuándo re-evaluar |
| `extension_hours` | 1 | `'2'` | Horas de extensión de sesión |
| `header` | 1 | `'Retry-After'` | Cabecera HTTP a incluir |
| `invalidate_pending_txs` | 1 | `'true'` | Invalidar transacciones pendientes |
| `invalidate_sessions` | 1 | `'true'` | Invalidar sesiones activas |
| `lockout_minutes` | 1 | `'15'` | Minutos de bloqueo |
| `log` | 1 | `'entry_exit'` | Tipo de log físico |
| `mantrap_required` | 1 | `'true'` | Requerir mantrap físico |
| `max_duration_minutes` | 1 | `'30'` | Duración máxima de operación |
| `min_concurrent_presence` | 1 | `'2'` | Presencia física simultánea mínima |
| `no_logout` | 1 | `'true'` | Re-auth sin cerrar sesión |
| `permit_reason` | 1 | `'schedule_day_compliant'` | Razón del PERMIT para auditoría |
| `purge_requires` | 1 | `'CISO_approval'` | Aprobación para purge |
| `renewable` | 1 | `'false'` | Si el contexto es renovable |
| `require_dual_signature` | 1 | `'true'` | Requerir doble firma |
| `required_additional` | 1 | `'fingerprint_hash'` | Factor adicional requerido |
| `required_method` | 1 | `'smartcard_x509+fingerprint_hash'` | Método de autenticación exacto |
| `retention_years` | 1 | `'7'` | Años de retención de log |
| `retry_after_formula` | 1 | `'(attempt-3)x60s'` | Fórmula de delay progresivo |
| `retry_interval_seconds` | 1 | `'5'` | Intervalo entre reintentos |
| `revoke` | 1 | `'oldest_session'` | Qué revocar |
| `scope_reduction` | 1 | `'APPROVE,CONFIGURE'` | Reducir alcance de permisos |
| `sla_hours` | 1 | `'@bauth_config_param.sla_timeout_hours'` | SLA de aprobación |
| `sla_seconds` | 1 | `'30'` | SLA en segundos |
| `step_up_required` | 1 | `'false'` | Indicador de step-up |
| `storage` | 1 | `'WORM'` | Tipo de almacenamiento |
| `successor` | 1 | `'dpop_rfc9449'` | Protocolo sucesor |
| `ttl_seconds` | 1 | `'30'` | TTL de la decisión |

---

## D — Atributos de metadatos (_a)

Los nodos `atributo` con `_a('clave', 'valor')` documentan propiedades del bloque
o átomo que **no son condiciones evaluadas** — son metadatos contextuales.

### D.1 Identificación del nodo
| Clave | Ejemplo valor |
|-------|--------------|
| `id` | `'RGV-001'` |
| `domain_code` | `'D01'` |
| `hierarchy_level` | `'2'` |
| `version_number` | `'7'` |
| `parent_id` | `'VEN-BASE-001'` |
| `parent_role` | `'VEN-BASE-001'` |
| `path_ids` | `'["VEN-BASE-001","RGV-001"]'` |
| `type_id` | `'TYPE-GERENCIA-REGIONAL'` |
| `created_at` | `'2024-01-01T00:00:00Z'` |
| `created_by` | `'ADMIN.SISTEMA'` |
| `updated_by` | `'DGV.CARLOS.RUIZ'` |
| `review_date` | `'2026-07-01T00:00:00Z'` |

### D.2 Descripción e internacionalización (bi18n)
| Clave | Ejemplo valor |
|-------|--------------|
| `es` | `'Gerente Regional de Ventas — Región Norte'` |
| `en` | `'Regional Sales Manager — Northern Region'` |
| `pt` | `'Gerente Regional de Vendas — Região Norte'` |
| `nota` | `'Passkey sincronizado = LoA 2 por riesgo de sync cloud'` |
| `evaluación` | `'NIST 800-207 §3.3 — todos deben ser true/CURRENT'` |
| `dominio` | `'D01 · Acceso Lógico'` |

### D.3 Normativo / Compliance
| Clave | Ejemplo valor | Estándar |
|-------|--------------|---------|
| `n1` | `'NIST SP 800-162 · ABAC environment attributes'` | Referencia primaria |
| `n2` | `'ISO 27001:2022 A.8.3 · information access restriction'` | Referencia secundaria |
| `n3` | `'NIST AC-4 · information flow enforcement'` | Referencia terciaria |
| `n4` | `'NGAC INCITS 565-2020 §4 · Object Attribute node'` | Referencia cuaternaria |
| `n5` | `'NGAC INCITS 565-2020 §4'` | Solo aparece 1 vez |
| `ISO_27001_2022` | `'A.8.15 logging · A.5.15 access control · revisión semestral'` | |
| `Ley_164_Bolivia` | `'firma digital · registros electrónicos · validez jurídica'` | |
| `PCI_DSS_4_0` | `'Req 7/8/10 · revisión anual certificación QSA'` | |
| `RGPD` | `'Art. 30 registro actividades · retention 365 d · DPO notificación'` | |
| `SOX` | `'§302 CEO/CFO · §404 control interno · evidencia 7 años'` | |
| `base` | `'AC-2g · PCI 7.2.5 — aprobación k-de-n'` | Norma base del bloque |

### D.4 Recursos y accesos
| Clave | Ejemplo valor | Descripción |
|-------|--------------|-------------|
| `resource` | `'bauth.app/tryton_erp'` | Recurso objetivo |
| `subject` | `'ANY'` / `'SET(vendedores)'` | Sujeto al que aplica |
| `zona` | `'zone_financial/ventas:APPROVE'` | Zona + verbo requerido |
| `app_code` | `'tryton_erp'` | Aplicación objetivo |
| `app_type` | `'ERP'` | Tipo de aplicación |
| `slug_prefix` | `'tryton'` | Prefijo de slug de app |
| `vendor` | `'Tryton (open source ERP)'` | Proveedor |
| `sbos:ventas:read` | `'lectura de oportunidades y pedidos'` | Permiso SBOS |
| `sbos:ventas:write` | `'crear y modificar pedidos propios'` | Permiso SBOS |
| `sbos:ventas:approve` | `'aprobar ventas ≤50 000 BOB (tier 2)'` | Permiso SBOS |
| `sbos:clientes:read` | `'lectura de ficha de cliente (PII)'` | Permiso SBOS |
| `sbos:financial:read` | `'consulta de límites y transacciones propias'` | Permiso SBOS |
| `registro` | `'bauth.privilege_application.app_code=tryton_erp'` | Registro de aplicación |

### D.5 Roles y conjuntos
| Clave | Ejemplo valor |
|-------|--------------|
| `ROL_GERENTE_REGIONAL_VENTAS` | `'tier BIZ_N2 — gerente regional'` |
| `ROL_EJECUTIVO_VENTAS` | `'tier BIZ_N2 — ejecutivo de cuenta'` |
| `ROL_DIRECTOR_VENTAS` | `'tier BIZ_N3 — director de ventas'` |
| `ROL_DIRECTOR_FINANCIERO` | `'tier BIZ_N4 — aprobación gerencial'` |
| `ROL_AUDITOR_INTERNO` | `'tier BIZ_N2 — auditoría interna'` |
| `ROL_AUDITOR_EXTERNO` | `'tier EXT_N0 — externo certificado'` |
| `ROL_AGENTE_ATENCION` | `'tier BIZ_N1 — agente de atención'` |
| `set_name` | `'Financieros Tier 2 — Aprobadores de ventas'` |
| `set_slug` | `'financieros_tier2'` |
| `members_scope` | `'todos los VEN-RGV del tenant'` |
| `child_roles` | `'["VEN-JUNIOR-001","VEN-TRAINEE-001"]'` |
| `bits_removed_from_parent` | `'["APPROVE_HIGH_VALUE","CONFIGURE_SYSTEM","AUDIT_FINANCIAL"]'` |
| `delegable_to_roles[]` | `'["VEN-JUNIOR-001","VEN-TRAINEE-001"]'` |
| `delegaciones_activas` | `'delegaciones vigentes y su uso'` |

### D.6 Seguridad y criptografía
| Clave | Ejemplo valor |
|-------|--------------|
| `motor_firma` | `'EXTERNAL_ADSIB (RSA-SHA256)'` / `'INTERNAL (EdDSA Ed25519) + sello_tiempo'` |
| `key_storage` | `'hardware (smartcard / HSM)'` |
| `certificate_policy` | `'ADSIB-FD-POLT-015 \| CA interna bAuth'` |
| `signature_evidence` | `'hash SHA-256 del documento + sello de tiempo RFC 3161 + aud_event'` |
| `network` | `'Besu QBFT · chain_id configurable'` |
| `post_quantum_planned` | `'CRYSTALS-Dilithium'` |
| `bitmask_64_ref` | `'capa 1 [31:0] sistema · capa 2 [63:32] negocio'` |
| `*_domain_mask_hex Q1-Q4` | `'lógico/físico/financiero/gobernanza (32 bits c/u)'` |

### D.7 Configuración de métodos de autenticación
| Clave | Ejemplo valor |
|-------|--------------|
| `method_id` | `'username_password \| x509_smartcard \| webauthn_platform \| passkey'` |
| `amr_value` | `'pwd'` / `'otp'` |
| `tipo` | `'MEMORIZED_SECRET'` / `'OTP'` |
| `algoritmo` | `'HMAC-SHA1 · 6 dígitos'` |
| `digits` | `'6'` |
| `time_step` | `'30 s'` |
| `entropy_bits` | `'48'` |
| `min_length` | `'15 caracteres (solo factor) · 8 (con MFA adicional)'` |
| `max_length` | `'64+ (soporte de passphrases)'` |
| `format` | `'XXXX-XXXX-XXXX (12 hex chars)'` |
| `count` | `'10 códigos de un solo uso'` |
| `binding` | `'user_id + timestamp + HMAC-SHA256'` |
| `authenticator_attachment` | `'platform (Touch ID, Windows Hello, Face ID)'` |
| `fmr` | `'1:10 000 mínimo'` |
| `liveness` | `'passive PAD'` |
| `cifrado` | `'AES-128 · mutua autenticación'` |
| `protocolo` | `'ISO 14443-A/B · MIFARE DESFire EV3'` |
| `almacenamiento` | `'Argon2id hash — NUNCA biométrico crudo'` |
| `replaces` | `'totp'` / `'webauthn_platform'` |
| `max_clock_drift` | `'±1 período (60 s total)'` |
| `issuer` | `'bAuth — etiqueta en app autenticadora'` |
| `openid` | `'siempre presente — identificación del sujeto'` |
| `profile` | `'nombre, cargo, foto, organización'` |

#### D.7.a Secuencia de métodos autenticadores (numerados)
Estos son atributos donde la clave incluye el número de orden en la cadena:

| Clave | Ejemplo valor |
|-------|--------------|
| `1 · fingerprint_hash` | `'biométrico OSDP · security_level 3 · amr=fpt'` |
| `1 · nfc_desfire` | `'re-tap de tarjeta en torniquete de salida/entrada'` |
| `1 · totp` | `'preferido AAL2 · amr=otp'` |
| `2 · qr_dynamic` | `'nuevo QR generado con TTL=30s'` |
| `2 · smartcard_x509` | `'PKCS#11 físico · security_level 4 · amr=sc'` |
| `2 · webauthn_platform` | `'preferido AAL3 · amr=fpt'` |
| `3 · pin_pad` | `'PIN OSDP · SOLO como 2.º factor (conocimiento) · amr=pin'` |
| `3 · push_notification` | `'push con number matching'` |
| `3 · webauthn_roaming` | `'alternativa hardware AAL3 · amr=hwk'` |
| `4 · push_notification` | `'push con number matching (verify_number) · amr=mfa'` |
| `5 · backup_codes` | `'ÚLTIMO RECURSO — solo emergencia · amr=otp'` |

> **⚠️ REPARACIÓN:** Las claves con `·` (interpunto) no son identificadores válidos en SQL.
> En T-162 se almacenan como `clave='1_fingerprint_hash'` o `clave='auth_step_1'`.
> El valor puede incluir el nombre del método. Requiere normalización antes de serializar.

### D.8 Gestión de tiempo y sesiones
| Clave | Ejemplo valor |
|-------|--------------|
| `start_date` | `'2026-01-01T00:00:00Z'` |
| `end_date` | `'2027-12-31T23:59:59Z'` |
| `ttl_minutes` | `'10'` |
| `ttl_seconds` | `'60'` / `'30 (rotación automática)'` |
| `idle_minutes` | `'15'` / `'0'` |
| `max_session_minutes` | `'480'` |
| `max_duration_days` | `'21'` |
| `reauth_interval_mins` | `'240'` |
| `validity` | `'not_before … not_after (1 año)'` |

> **⚠️ REPARACIÓN:** `'30 (rotación automática)'` mezcla número y texto. Debe ser `'30'`
> con `help:` para la nota.

### D.9 Configuración financiera
| Clave | Ejemplo valor |
|-------|--------------|
| `single_transaction_limit` | `'@bauth_config_param.approval_threshold_tier2'` |
| `daily_limit` | `'@bauth_config_param.financial_daily_limit'` |
| `monthly_limit` | `'@bauth_config_param.financial_monthly_limit'` |
| `requires_dual_approval_above` | `'@bauth_config_param.approval_threshold_tier2'` |
| `currency` | `'@bauth_config_param.default_currency'` |

### D.10 Límites y cuotas
| Clave | Ejemplo valor |
|-------|--------------|
| `max_uses` | `'3 consecutivos antes de bloqueo'` |
| `max_concurrent_delegations` | `'1'` |
| `max_subordinates` | `'10'` |
| `min_concurrent_presence` | Definido en `_ef(obl:...)` |
| `quorum_required` | `'2-de-N para alto valor'` |

### D.11 Datos de organización
| Clave | Ejemplo valor |
|-------|--------------|
| `department` | `'Ventas'` |
| `region` | `'NORTH'` |
| `territory_code` | `'VEN-NORTH-001'` |
| `cost_center` | `'VEN-NORTE'` |
| `job_family` | `'Sales'` |
| `job_level` | `'M2'` |
| `office` | `'192.168.1.0/24'` |
| `linea_1_negocio` | `'DIRECTOR_VENTAS'` |
| `linea_2_compliance` | `'COMPLIANCE_OFFICER'` |
| `linea_3_auditoria` | `'INTERNAL_AUDITOR'` |

### D.12 Estado interno del motor
| Clave | Ejemplo valor | Nota |
|-------|--------------|------|
| `bitmask_64_ref` | `'capa 1 [31:0] sistema · capa 2 [63:32] negocio'` | Metadato del motor |
| `computed_at / computed_by` | `'sello del PrivilegeEngine + ctx_id'` | **⚠️ clave con `/` y espacio** |
| `drift_details` | `'null'` | Placeholder — cambiar a `NULL` en DDL |
| `last_sync_at` | `'timestamp ISO 8601'` | Solo descriptor — no valor real |
| `*_domain_mask_hex Q1-Q4` | `'lógico/físico/financiero/gobernanza (32 bits c/u)'` | **⚠️ clave con `*` y espacio** |

> **⚠️ REPARACIÓN:** Las claves `computed_at / computed_by` y `*_domain_mask_hex Q1-Q4`
> contienen caracteres inválidos para columna SQL (`/`, `*`, espacios). Son descriptores
> de documentación, no campos reales. Deben dividirse en claves separadas o marcarse
> como nodos `atributo` de solo documentación (no sincronizados a T-162).

### D.13 Auditoría y trazabilidad
| Clave | Ejemplo valor |
|-------|--------------|
| `accesos_logicos` | `'entradas/salidas · intentos fallidos'` |
| `cambios_de_rol` | `'altas/bajas/modificaciones de asignaciones'` |
| `transacciones_financieras` | `'todas las ops financieras con monto y aprobador'` |
| `violaciones_sod` | `'intentos bloqueados por Conflict Matrix'` |
| `uso_permisos_efectivos` | `'qué permisos se usaron realmente (vs asignados)'` |

### D.14 Masking y PII
| Clave | Ejemplo valor | Estado |
|-------|--------------|--------|
| `masking_policy` | `'lastFourVisible(national_id,salary,medical)'` | OK |
| `masking_policy` | `'null'` | **⚠️ Placeholder** |
| `pii_access` | `'true'` | OK |
| `pii_override` | `'null'` | **⚠️ Placeholder** (x9) |
| `loa_override` | `'null'` | **⚠️ Placeholder** (x3) |
| `loa_override` | `'AAL3'` | OK |

### D.15 Propiedades sin clasificación definitiva

Las siguientes propiedades requieren clasificación adicional del usuario:

| Clave | Ejemplo valor | Hipótesis de tipo |
|-------|--------------|------------------|
| `bauth:token_info` | `'metadata del JWT (loa, ctx_id, domain_mask)'` | Metadato de token |
| `contingencia_plan` | `'modo offline + sincronización diferida ≤24 h'` | Metadato operativo |
| `channel` | `'SMTP cifrado — entrega vía bNotify'` | Metadato de canal (duplica `obl:channel`) |
| `numero_intent` | `'número aleatorio en pantalla para anti-fatiga MFA'` | Descripción de UX |
| `change_reason` | `'Ajuste por inflación — Resolución DIR-2026-003'` | Metadato de auditoría |
| `changes` | `'["Incremento límite L1 de 40k a 50k BOB"]'` | Metadato de auditoría |
| `rnnd_emisor` | `'NIT + código emisor SIN'` | Metadato SIN Bolivia |
| `peso_riesgo` | `'+0.20 al score si alguno falla'` | Parámetro del motor de riesgo |
| `propiedad` | `'device.patch_status, device.antivirus_active, ...'` | Lista de props evaluadas |
| `trigger` | `'reader_offline OR nfc_hardware_fault'` | Condición de fallback |

---

## E — Enumerados de estado (_en)

Los nodos `enumerado` creados con `_en('clave', 'valor')` son propiedades
de estado/configuración con vocabulario cerrado (no condiciones XACML).

**Total de claves únicas:** 45

| Clave | Valores observados | Descripción |
|-------|-------------------|-------------|
| `active` | `true` | Estado de activación |
| `alert_on_use` | `true`, `false` | Alertar al usar credencial |
| `algorithm` | `EdDSA_Ed25519` | Algoritmo de firma |
| `app_type` | `ERP`, `CRM`, `RRHH`, `SOBERANO` | Tipo de aplicación |
| `attestation` | `direct` | Modo de attestation FIDO2 |
| `authenticator_attachment` | `cross-platform` | Tipo de autenticador |
| `breach_check` | `true` | Verificar contra HaveIBeenPwned |
| `can_delegate` | `true` | Permiso de delegación |
| `classification` | `CONFIDENTIAL` | Clasificación de información |
| `device_compliance_required` | `true` | Requerir cumplimiento MDM |
| `drift_detected` | `false` | Estado de drift del motor |
| `enabled` | `false` | Estado habilitado |
| `financial_ops` | `DENY` | Restricción de operaciones financieras |
| `firma_electronica_required` | `true` | Requerir firma digital |
| `gps_attestation_required` | `false`, `true` | Requerir GPS |
| `hierarchy_level` | `2` | Nivel jerárquico del rol |
| `hints` | `PROHIBIDOS` | Estado de hints de contraseña |
| `inheritance_mode` | `AND_NOT` | Modo de herencia BitMask |
| `level_of_assurance` | `2` | Nivel de aseguramiento |
| `liveness` | `passive PAD` | Tipo de prueba de vida |
| `loa` | `1`, `2`, `3`, `4` | Nivel de LoA efectivo |
| `loa_required` | `AAL1`, `AAL2` | LoA mínimo requerido |
| `min_additional_loa` | `2` | LoA adicional mínimo |
| `min_loa` | `1`, `2` | LoA mínimo efectivo |
| `modalidad` | `EN_LINEA` | Modalidad de operación |
| `mtls_required` | `true` | Requerir mTLS |
| `notify_security` | `true` | Notificar al equipo de seguridad |
| `one_time_only` | `true` | Uso único |
| `paste_allowed` | `true` | Permitir pegar contraseñas |
| `pin_required` | `true` | Requerir PIN físico |
| `required_engine` | `INTERNAL` | Motor de firma requerido |
| `required_if` | `role.level_of_assurance >= 2` | Condición de activación |
| `requires_approval` | `true`, `false` | Requerir aprobación |
| `resident_key` | `required`, `preferred` | Modo de resident key FIDO2 |
| `review_frequency` | `QUARTERLY` | Frecuencia de revisión |
| `security_impact` | `LOW` | Impacto de seguridad |
| `security_level` | `2`, `1` | Nivel de seguridad del método |
| `status` | `ACTIVE` | Estado del recurso |
| `sync_status` | `SYNCED` | Estado de sincronización |
| `synced` | `true` | Indicador de sync |
| `type` | `FIXED` | Tipo de límite |
| `type_id` | `TYPE-GERENCIA-REGIONAL` | Tipo de rol |
| `user_verification` | `required` | Verificación de usuario FIDO2 |
| `vpn_required` | `false`, `true` | Requerir VPN |
| `zero_trust_mode` | `true` | Activar modo Zero Trust |

---

## F — Errores detectados — Correcciones propuestas (árbol Dart)

Cada corrección está documentada aquí antes de tocarse el árbol.
Las secciones F.1–F.3 son la referencia de trabajo para la fase de reparación.

---

### F.1 — Claves con caracteres inválidos para SQL/identificadores

Los nombres de clave de `_a()` se almacenan en la columna `clave VARCHAR` de T-162.
Aunque SQL permite cualquier texto en VARCHAR, las claves con `·`, `/`, `*` o espacios
rompen consultas y mapeos en Rust/código (`WHERE clave = '1 · fingerprint_hash'` funciona
pero genera mantenibilidad cero). Regla: **claves en `snake_case` ASCII, sin caracteres especiales.**

| # | Clave actual | Líneas en Dart | Problema | Clave propuesta |
|---|-------------|---------------|---------|----------------|
| F1.01 | `'*_domain_mask_hex Q1-Q4'` | 3803 | `*` y espacios | Dividir en 4 claves (ver detalle) |
| F1.02 | `'computed_at / computed_by'` | 3805 | `/` y espacios — 2 datos distintos | Dividir en `'computed.at'` + `'computed.by'` |
| F1.03 | `'1 · totp'` | 478, 552 | `·` y espacio | `'factor.1.totp'` |
| F1.04 | `'2 · webauthn_platform'` | 479, 553 | `·` y espacio | `'factor.2.webauthn.platform'` |
| F1.05 | `'3 · webauthn_roaming'` | 480 | `·` y espacio | `'factor.3.webauthn.roaming'` |
| F1.06 | `'4 · push_notification'` | 481 | `·` y espacio | `'factor.4.push.notification'` |
| F1.07 | `'5 · backup_codes'` | 482 | `·` y espacio | `'factor.5.backup.codes'` |
| F1.08 | `'3 · push_notification'` | 554 | `·` y espacio | `'factor.3.push.notification'` |
| F1.09 | `'1 · fingerprint_hash'` | 2642 | `·` y espacio | `'factor.1.fingerprint.hash'` |
| F1.10 | `'2 · smartcard_x509'` | 2643 | `·` y espacio | `'factor.2.smartcard.x509'` |
| F1.11 | `'3 · pin_pad'` | 2644 | `·` y espacio | `'factor.3.pin.pad'` |
| F1.12 | `'1 · nfc_desfire'` | 2687 | `·` y espacio | `'factor.1.nfc.desfire'` |
| F1.13 | `'2 · qr_dynamic'` | 2688 | `·` y espacio | `'factor.2.qr.dynamic'` |

> **Separador: siempre `.` entre partes del slug.** El punto no es carácter válido en
> identificadores Dart/Rust, por lo que un slug `factor.1.totp` nunca colisiona con
> un nombre de variable en el código.

**Detalle F1.01 — 4 claves de cuadrante SAM-128:**  
La clave actual `*_domain_mask_hex Q1-Q4` documenta UN descriptor de los 4 cuadrantes del SAM-128.
Corrección: reemplazar con 4 atributos separados:
```dart
// ANTES (1 nodo con clave inválida):
_a('*_domain_mask_hex Q1-Q4', 'lógico/físico/financiero/gobernanza (32 bits c/u)',
    help: 'SAM-128. G-B09: pendiente cálculo.'),

// DESPUÉS (4 nodos con claves válidas, separador `.`):
_a('domain.mask.q1.logico',       'pendiente cálculo', help: 'SAM-128 Q1. Bits D01–D09.'),
_a('domain.mask.q2.fisico',       'pendiente cálculo', help: 'SAM-128 Q2. Bits D10–D18.'),
_a('domain.mask.q3.financiero',   'pendiente cálculo', help: 'SAM-128 Q3. Bits D19–D27.'),
_a('domain.mask.q4.gobernanza',   'pendiente cálculo', help: 'SAM-128 Q4. Bits D28–D35.'),
```

**Detalle F1.02 — `computed.at` / `computed.by`:**
```dart
// ANTES (1 nodo, 2 datos distintos):
_a('computed_at / computed_by', 'sello del PrivilegeEngine + ctx_id'),

// DESPUÉS:
_a('computed.at',  '', help: 'Timestamp ISO 8601 del cálculo. READONLY — PrivilegeEngine.'),
_a('computed.by',  '', help: 'ctx_id del proceso que calculó el BitMask. READONLY.'),
```

---

### F.2 — Valores que mezclan dato+texto libre

Un valor en `_val()` o `_a()` debe ser un **dato puro** (número, booleano, enum, referencia).
El texto explicativo va en el parámetro `help:`. Cuando se mezclan, el motor no puede
comparar el valor programáticamente (ej. `64 (máximo aceptado)` no se puede parsear como int).

#### F.2.a — Valores en `_val()` (condición evaluada)

| # | Línea | Valor actual | Valor propuesto | `help:` a agregar |
|---|-------|-------------|----------------|------------------|
| F2.01 | 3337 | `'64 (máximo aceptado)'` | `'64'` | `'NIST 800-63B-4: sistema DEBE soportar ≥64 chars (passphrases).'` |
| F2.02 | 3350 | `'true (últimas 5 contraseñas)'` | `'true'` | `'Historial: últimas 5 contraseñas verificadas (NIST 800-63B-4 §5.1.1.2).'` |
| F2.03 | 3362 | `'(cualquier valor periódico)'` | **ELIMINAR nodo** | IS_SET no evalúa valor — ver F.3.a |
| F2.04 | — | `'B8.transaction_limits.single_transaction_limit (enlace a D3)'` | `'B8.transaction_limits.single_transaction_limit'` | `'Enlace cruzado a D3 Financiero. Ver bloque B8.'` |
| F2.05 | — | `'S256 (SHA-256)'` | `'S256'` | `'S256 = SHA-256. PKCE RFC 7636 §4.2.'` |
| F2.06 | — | `'zones_access_rules[] (lista anterior)'` | `'zones_access_rules[]'` | `'Referencia a la lista de reglas de la zona definida en el bloque anterior.'` |

> **✅ VÁLIDO** — `'[Argon2id(t>=3,m>=64MB,p>=2)]'`: sintaxis técnica de parámetros,
> no texto libre. Los paréntesis son parte del identificador del algoritmo. No corregir.

#### F.2.b — Valores en `_a()` (atributos de metadatos)

| # | Línea | Clave | Valor actual | Valor propuesto | `help:` a agregar |
|---|-------|-------|-------------|----------------|------------------|
| F2.07 | 568 | `max_uses` | `'3 consecutivos antes de bloqueo'` | `'3'` | `'Tres usos consecutivos antes de bloqueo automático.'` |
| F2.08 | 2588 | `ttl_seconds` | `'30 (rotación automática — más corto que D1=10min)'` | `'30'` | `'Rotación automática. TTL intencionalmente más corto que D1 (600 s) para reducir ventana de exposición.'` |
| F2.09 | 2703 | `max_uses` | `'5 consecutivos — luego requiere aprobación supervisor'` | `'5'` | `'Después de 5 usos consecutivos, requiere aprobación del supervisor.'` |
| F2.10 | 2714 | `max_uses` | `'3 consecutivos — luego requiere mantenimiento del sensor'` | `'3'` | `'Después de 3 lecturas, requiere mantenimiento del sensor biométrico.'` |
| F2.11 | 2722 | `max_uses` | `'1 (genera reporte automático a CISO)'` | `'1'` | `'Uso único de emergencia. La notificación al CISO va en obligation del _ef().'` |

---

### F.3 — Errores semánticos (lógica incorrecta)

Estos errores no son de formato sino de semántica: el árbol dice algo distinto
de lo que la norma o la arquitectura mandan.

#### F.3.a — IS_SET con valor de comparación (XACML 3.0 §7.3.2)

**Problema:** El átomo `rotación periódica forzada — PROHIBIDA` usa `_op('IS_SET')` y además
tiene un `_val('(cualquier valor periódico)')`. En XACML 3.0 la función `urn:oasis:names:tc:xacml:1.0:function:present` (equivalente a IS_SET) evalúa solo la **presencia** del atributo — no compara contra un valor. El tercer hijo `_val()` es semánticamente incorrecto y confunde al lector.

```dart
// ANTES (líneas 3359-3364) — _val no tiene sentido con IS_SET:
_ev('rotación periódica forzada — PROHIBIDA', [
  _prop('password_policy.periodic_rotation_days'),
  _op('IS_SET'),
  _val('(cualquier valor periódico)'),   // ← ELIMINAR
  _ef('DENY configuración · NIST 800-63B-4 eliminó rotación periódica'),
], verbo: 'configure'),

// DESPUÉS — solo prop + operador IS_SET + efecto:
_ev('rotación periódica forzada — PROHIBIDA', [
  _prop('password_policy.periodic_rotation_days'),
  _op('IS_SET'),
  _ef('DENY configuración · NIST 800-63B-4 §5.1.1.2 eliminó rotación periódica obligatoria'),
], verbo: 'configure'),
```

**Norma:** XACML 3.0 §7.3.2 — `present()` function takes only an `<AttributeDesignator>`,
no second argument. NIST 800-63B-4 §5.1.1.2 confirma: "Verifiers SHALL NOT require that
memorized secrets be changed arbitrarily (e.g., periodically)."

---

#### F.3.b — Error normativo CRÍTICO: longitud máxima de contraseña contradice NIST 800-63B-4

**Problema:** El átomo `longitud máxima` (línea 3334) DENIEGA contraseñas con
`password.length > 64`. Pero NIST SP 800-63B-4 §5.1.1.1 dice:

> *"Verifiers and CSPs SHOULD support passwords of at least 64 characters in length."*

El estándar exige **soportar AL MENOS 64 caracteres**, no **limitar a 64**. El átomo
actual implementa lo contrario: bloquea todo lo que supera los 64 caracteres,
prohibiendo exactamente las passphrases que NIST quiere fomentar.

```dart
// ANTES (líneas 3334-3340) — BLOQUEA contraseñas > 64 chars (INCORRECTO):
_ev('longitud máxima', [
  _prop('password.length'),
  _op('>'),
  _val('64 (máximo aceptado)',
      help: 'Sistema DEBE soportar ≥64 chars para passphrases (800-63B-4).'),
  _ef('DENY · "Máximo 64 caracteres" — ampliar si el sistema lo soporta'),
], verbo: 'configure'),

// DESPUÉS — bloquear sólo contraseñas absurdamente largas (OWASP sugiere 512):
_ev('longitud máxima — límite técnico', [
  _prop('password.length'),
  _op('>'),
  _val('512',
      help: 'NIST 800-63B-4 §5.1.1.1: soportar ≥64. OWASP ASVS v5 §2.1.2: '
            'límite técnico ≥64, recomendado 128–512. 64 es el mínimo, no el máximo.'),
  _ef('DENY · "Contraseña demasiado larga (máximo 512 caracteres)"'),
], verbo: 'configure'),
```

> **Severidad: CRÍTICA** — El árbol actual viola NIST SP 800-63B-4 en este punto.
> Un sistema que rechaza contraseñas de 65 caracteres no cumple el estándar.

---

#### F.3.c — Case-sensitivity en verbos privilegiados (línea 460)

**Problema:** El átomo `verbo privilegiado` verifica `action.verb IN [CONFIGURE, ADMIN, DELETE]`
con valores en MAYÚSCULAS. Pero los 15 verbos del catálogo (`verbo` enumerado) están en
minúsculas: `configure`, `delete`. Si el runtime envía el verbo en minúsculas y este átomo
espera mayúsculas, nunca coincidirán.

El comentario en línea 543 ya advierte sobre este riesgo: *"case-sensitivity bugs"*.

```dart
// ANTES (línea 460):
_ev('verbo privilegiado', [_prop('action.verb'), _op('IN'),
    _val('[CONFIGURE, ADMIN, DELETE]')]),

// DESPUÉS — valores en minúsculas, consistentes con el enumerado verbo:
_ev('verbo privilegiado', [_prop('action.verb'), _op('IN'),
    _val('[configure, delete, emit]',
         help: 'Verbos privilegiados. Consistente con el enumerado verbo (snake_case). '
               'admin no existe en el catálogo — fue reemplazado por configure+audit.')]),
```

> **Nota:** El valor `ADMIN` del original no existe en el catálogo de verbos canónico.
> Los 15 verbos son: read, write, create, delete, approve, execute, audit, configure,
> emit, login, delegate, export, void, validate, ANY.

---

#### F.3.d — Valores `'null'` placeholder (9 ocurrencias)

El string literal `'null'` no es `NULL` en SQL ni `nil` en Dart. Cuando se serialice a
T-162, se insertará el texto `"null"` en la columna `valor`, lo que rompe cualquier
lógica que compare `WHERE valor IS NULL` o `WHERE valor = ''`.

**Regla de sustitución por semántica:**

| Clave | Significado real | Valor propuesto | Razón |
|-------|----------------|----------------|-------|
| `masking_policy` | No hay política de masking para este perímetro | `'NONE'` | Enum explícito → motor sabe que no aplica masking |
| `loa_override` | Hereda el LoA de la zona padre | `'INHERIT'` | Enum explícito → motor NO sobreescribe el LoA heredado |
| `pii_override` | Hereda el pii_access de la zona padre | `'INHERIT'` | Enum explícito → motor NO cambia la herencia de PII |

**Tabla de correcciones por línea:**

| # | Línea | Clave | Valor actual | Valor propuesto | `help:` nuevo o a conservar |
|---|-------|-------|-------------|----------------|---------------------------|
| F3.01 | 1839 | `masking_policy` | `'null'` | `'NONE'` | `'Sin PII en este perímetro — sin política de máscara (RGPD Art. 4).'` |
| F3.02 | 1882 | `loa_override` | `'null'` | `'INHERIT'` | Conservar: `'INHERIT = hereda LoA de la zona. Solo puede endurecer (AAL3), nunca relajar.'` |
| F3.03 | 1884 | `pii_override` | `'null'` | `'INHERIT'` | `'INHERIT = hereda pii_access de la zona.'` |
| F3.04 | 1986 | `loa_override` | `'null'` | `'INHERIT'` | `'INHERIT = hereda LoA de la zona. Solo puede endurecer, nunca relajar.'` |
| F3.05 | 1987 | `pii_override` | `'null'` | `'INHERIT'` | `'INHERIT = hereda pii_access de la zona.'` |
| F3.06 | 2188 | `loa_override` | `'null'` | `'INHERIT'` | `'INHERIT = hereda LoA de la zona. Solo puede endurecer, nunca relajar.'` |
| F3.07 | 2189 | `pii_override` | `'null'` | `'INHERIT'` | Conservar: `'INHERIT pii_access=true de la zona. No puede relajarse a false (RGPD Art. 25).'` |
| F3.08 | 2359 | `masking_policy` | `'null'` | `'NONE'` | `'Sin PII en transacciones financieras per RGPD Art. 4(1).'` |
| F3.09 | 2401 | `pii_override` | `'null'` | `'INHERIT'` | `'INHERIT = hereda pii_access=false de la zona financiera.'` |

> **Vocabulario de enums a agregar a `opciones[]` en T-162:**  
> - `masking_policy`: `['NONE', 'LASTFOUR', 'DOMAIN_ONLY', 'FULL_MASK', 'INHERIT', 'CUSTOM']`  
> - `loa_override`: `['INHERIT', 'AAL1', 'AAL2', 'AAL3']`  
> - `pii_override`: `['INHERIT', 'true', 'false']`

---

### F.4 — Menor: átomos sin `verbo:` explícito

**Total:** 291 átomos `_ev()` sin parámetro `verbo:`.

**Criterio de resolución:** si el átomo vive dentro de un bloque funcional cuyo contexto
implica un verbo único (ej. todos los átomos de `session_policy{}` aplican a `access`),
heredarlo explícitamente. Los que verdaderamente aplican a cualquier verbo → `verbo: 'ANY'`.

Esta corrección es la más voluminosa (291 nodos) y requiere análisis semántico caso a caso.
Se documenta aquí pero la corrección en el árbol se hará en una pasada dedicada.

---

### F.5 — Menor: descriptores en lugar de valores en `_a()`

| Clave | Valor actual (descriptor) | Problema | Propuesta |
|-------|--------------------------|---------|----------|
| `last_sync_at` | `'timestamp ISO 8601'` | Tipo, no dato | `''` + `help: 'Timestamp ISO 8601. READONLY — reconcile loop.'` |
| `propiedad` (en algunos bloques) | `'device.patch_status, device.antivirus_active, ...'` | Lista en un campo | Dividir en nodos `_prop()` individuales |
| `evaluación` (algunos bloques) | `'NIST 800-207 §3.3 — todos deben ser true/CURRENT'` | Documentación, no dato | Mover a `help:` del bloque padre |

---

### F.6 — CRÍTICO: todos los `clave` de `_ev()` son descripciones de negocio, no slugs

> **No-conformidad XACML 3.0 §4.1 — SBOS-0XX §4.1 — afecta 291+ átomos.**

#### F.6.1 — Descripción del problema

El primer argumento de **todos** los `_ev()` del árbol es texto de negocio en español:

```dart
_ev('quórum de aprobadores', [...])       // ← texto de negocio = Description XACML
_ev('verbo privilegiado', [...])           // ← texto de negocio
_ev('certificado mTLS presente → x509', [...])  // ← texto con flecha y tildes
```

Según XACML 3.0, ese texto pertenece al elemento `<Description>` del `<Rule>` (mapea a
la columna `help` en T-162). El elemento `<RuleId>` (columna `clave`) debe ser un
**identificador técnico estable** — ASCII, sin tildes, sin espacios, no traducible,
no cambiable cuando cambia la descripción de negocio.

El árbol actual no tiene ningún slug en `clave` para ninguno de los 291 átomos.

#### F.6.2 — Por qué es crítico

| Consecuencia | Detalle |
|---|---|
| **Logs ilegibles para sistemas externos** | Un log que cita `"clave": "quórum de aprobadores"` no puede ser indexado ni correlacionado por un SIEM sin normalización previa |
| **Auditoría inestable** | Si la descripción de negocio cambia (`"mínimo de aprobadores"` → `"quórum"`) la referencia al átomo en logs históricos queda rota |
| **Sin B-tree optimization** | El PrivilegeEngine no puede usar el slug como clave de índice estable — el texto libre no es candidato a índice de performance |
| **Violación de XACML RuleId semántico** | El estándar dice que `RuleId` es para referencias cruzadas — texto con tildes y flechas no es referenceable |

#### F.6.3 — Reglas de generación de slugs

**Separador: `.`** (punto). No `_` (guión bajo — colisiona con identificadores Dart/Rust).  
**Charset:** `[a-z0-9.]` — todo minúsculas, sin tildes, sin espacios, sin caracteres especiales.  
**Formato:** `{dominio}.{descriptor}` donde dominio = código D00–D13/D98/D99.

| Regla de conversión | Ejemplo |
|---|---|
| Eliminar tildes | `aprobación` → `aprobacion` |
| Eliminar flechas y símbolos | `mTLS → x509` → `mtls.x509` |
| Espacios → `.` | `verbo privilegiado` → `verbo.privilegiado` |
| Preposiciones breves → eliminar | `quórum de aprobadores` → `quorum.aprobadores` |
| Acrónimos → minúsculas | `SLA` → `sla` |
| Guiones → `.` | `step-up` → `step.up` |
| Namespace de dominio → prefijo | `d02.quorum.aprobadores` |

#### F.6.4 — Ejemplos de conversión (muestra representativa)

| Texto actual (primer arg `_ev()`) | Slug propuesto (`clave`) | Dominio |
|----------------------------------|--------------------------|---------|
| `'quórum de aprobadores'` | `d04.quorum.aprobadores` | D04 Delegation |
| `'verbo privilegiado'` | `d01.verbo.privilegiado` | D01 Acceso Lógico |
| `'certificado mTLS presente → x509'` | `d01.cert.mtls.x509` | D01 Acceso Lógico |
| `'riesgo bajo'` | `d09.riesgo.bajo` | D09 Risk |
| `'step-up triple factor PCI Req 8'` | `d01.step.up.triple.factor.pci` | D01 |
| `'rotación periódica forzada — PROHIBIDA'` | `d03.password.rotacion.prohibida` | D03 Passwords |
| `'longitud máxima'` | `d03.password.longitud.maxima` | D03 Passwords |
| `'contraseña comprometida (breach check)'` | `d03.password.breach.check` | D03 Passwords |
| `'sesión concurrente — límite 1'` | `d01.sesion.concurrente.limite` | D01 |
| `'zona sensible — presencia física dual'` | `d11.zona.sensible.presencia.dual` | D11 Físico |

#### F.6.5 — Estrategia de corrección

**Opción A (recomendada): slug en el compilador `atomc`**  
El árbol Dart fuente no cambia. El compilador Rust `atomc` genera el slug a partir del
texto del primer arg de `_ev()`, aplicando las reglas de F.6.3, y lo escribe en `clave`.
El texto original va a `help`. Zero cambios en el árbol Dart.

**Opción B: parámetro explícito en `_ev()`**  
Añadir `id:` opcional al helper:
```dart
_ev('quórum de aprobadores', [...],
    id: 'd04.quorum.aprobadores',  // ← slug explícito en Dart
    verbo: 'approve'),
```
Requiere 291 modificaciones en el árbol. Más trabajo, pero el slug es auditablemente
presente en el código fuente.

**Decisión pendiente:** arquitectura de AtomLang — opción A (generación automática) vs
opción B (slug explícito). Esta decisión debe consultarse con el humano antes de
implementar.

#### F.6.6 — Impacto en T-162

```sql
-- El slug va en la columna 'clave' (no el texto de negocio):
-- clave = 'd04.quorum.aprobadores'  (RuleId técnico)
-- help  = 'Quórum mínimo de aprobadores distintos para operación de alto valor'  (Description)
-- tipo  = 'evaluacion'

-- Índice B-tree que se puede crear con slugs estables:
CREATE INDEX idx_t162_clave_evaluacion
    ON bauth.idn_roles_template (clave)
    WHERE tipo = 'evaluacion';
-- Con texto libre actual, este índice tendría cardinalidad baja y poca utilidad
```

---

## G — Mapa de propiedades → columnas T-162 (completo)

Referencia canónica para la serialización del árbol Dart a la base de datos.

### G.1 Nodos XACML estructurales

> **⚠️ CORRECCIÓN SBOS-0XX §4.1 — `clave` vs `help`:**  
> El primer argumento de `_ev()` en el árbol Dart actual (texto de negocio en español)
> mapea a `help` (XACML `<Description>`), **no** a `clave` (XACML `RuleId`).
> La columna `clave` debe contener un **slug técnico con separador `.`** (ej: `quorum.aprobadores`).

| Propiedad Dart | Columna T-162 | `tipo` en T-162 | `opciones[]` | Notas |
|----------------|---------------|-----------------|--------------|-------|
| Primer arg de `_ev()` — texto de negocio | `help` | `evaluacion` | — | Es `Description` XACML (texto legible, no slug) |
| Slug técnico generado (ej: `quorum.aprobadores`) | `clave` | `evaluacion` | — | Es `RuleId` XACML. Separador `.` — no colisiona con código |
| `verbo` | `verbo` | `enumerado` | 15 valores (§A.2) | `Target.Action` XACML 3.0 — indexación rápida |
| `combining_algorithm` | `combining_algorithm` | `enumerado` | 4 valores (§A.3) | Algoritmo de combinación |
| `op_logico` | `op_logico` | `enumerado` | AND, OR, MATCH_ALL | Conector lógico entre `_ev()` (Condition-level) |

### G.2 Condición de evaluación

| Propiedad Dart | `clave` en T-162 | `tipo` en T-162 | Observación |
|----------------|------------------|-----------------|-------------|
| `_prop('path')` | `propiedad` | `atributo` | Path semántico del atributo evaluado |
| `_op('operador')` | `operador` | `enumerado` | 16 valores (§B.2) |
| `_val('valor')` | `valor` | `atributo` | Literal / `@bauth_config_param.*` / referencia |

### G.3 Efecto y obligaciones

| Propiedad Dart | `clave` en T-162 | `tipo` en T-162 | Notas |
|----------------|------------------|-----------------|-------|
| `_ef('PERMIT/DENY · texto')` | `efecto` | `atributo` | Texto descriptivo de la decisión |
| `obl:{key: 'val'}` | hijo de `efecto` | `atributo` | Un nodo hijo por obligation key |

### G.4 Atributos de metadatos `_a()`

| Subcategoría | `clave` | `tipo` | Notas |
|---|---|---|---|
| Identificación | `id`, `domain_code`, `hierarchy_level`, `version_number`, `parent_id`, `path_ids`, `type_id` | `atributo` | Datos de registro |
| i18n | `es`, `en`, `pt`, `nota` | `atributo` | Descripciones multiidioma |
| Normativo | `n1`, `n2`, `n3`, `n4`, `n5` | `atributo` | Referencias normativas informales → ver §I |
| Compliance | `ISO_27001_2022`, `Ley_164_Bolivia`, `PCI_DSS_4_0`, `RGPD`, `SOX` | `atributo` | Citación de estándar completa |
| Recursos | `resource`, `subject`, `zona`, `app_code`, `slug_prefix` | `atributo` | Target del átomo |
| Roles | `ROL_*`, `set_name`, `set_slug`, `child_roles`, `bits_removed_from_parent` | `atributo` | Datos del rol |
| Autenticación | `method_id`, `amr_value`, `tipo`, `algoritmo`, `factor_N_*` | `atributo` | Factores y secuencias |
| Seguridad | `motor_firma`, `key_storage`, `certificate_policy`, `domain_mask_*` | `atributo` | Propiedades criptográficas |
| Tiempo/sesión | `start_date`, `end_date`, `ttl_seconds`, `ttl_minutes`, `idle_minutes` | `atributo` | Ventanas temporales |
| Financiero | `single_transaction_limit`, `daily_limit`, `currency` | `atributo` | Límites económicos |
| Organización | `department`, `region`, `territory_code`, `cost_center` | `atributo` | Datos de estructura org |
| Motor (READONLY) | `computed_at`, `computed_by`, `domain_mask_q*`, `bitmask_64_ref` | `atributo` | Calculado por PrivilegeEngine |
| Auditoría | `accesos_logicos`, `cambios_de_rol`, `uso_permisos_efectivos` | `atributo` | Eventos a registrar |
| Masking/PII | `masking_policy`, `pii_access`, `pii_override`, `loa_override` | `atributo` | Control de datos PII |

### G.5 Enumerados `_en()` y valores de estado

| `clave` | `tipo` | `opciones[]` representativas | Notas |
|---------|--------|------------------------------|-------|
| `loa` | `enumerado` | `[1, 2, 3, 4]` | LoA efectivo |
| `loa_required` | `enumerado` | `[AAL1, AAL2, AAL3]` | Nivel mínimo |
| `app_type` | `enumerado` | `[ERP, CRM, RRHH, SOBERANO]` | Tipo de app |
| `sync_status` | `enumerado` | `[PENDING, SYNCING, SYNCED, ERROR, DRIFT]` | Estado reconcile |
| `classification` | `enumerado` | `[PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED]` | ISO 27001 A.5.12 |
| `masking_policy` | `enumerado` | `[NONE, INHERIT, LASTFOUR, DOMAIN_ONLY, FULL_MASK]` | (propuesta tras F.3.d) |
| `loa_override` | `enumerado` | `[INHERIT, AAL1, AAL2, AAL3]` | (propuesta tras F.3.d) |

### G.6 Nodos que NO van a T-162

| Nodo Dart | Razón |
|-----------|-------|
| `diagnostico` | Linter-only. Inyectado por `atomlang_validador_datos.dart`. Efímero. |
| `_ef()` texto + `obl:{}` referenciados por `_norm()` | Ver §I — van a tabla T-177 normativo (propuesta) |

---

## H — Alineación con normas y estándares internacionales

Verificación independiente de cada tipo de propiedad del árbol contra los estándares
que el proyecto SBOS cita como normativos (CLAUDE.md, context/BOS_V8/).

---

### H.1 — XACML 3.0 (OASIS Standard, agosto 2013)

El árbol implementa un **subset de XACML 3.0** centrado en el modelo Rule-combining.

| Elemento XACML 3.0 | Equivalente en el árbol | Estado |
|--------------------|------------------------|--------|
| `PolicySet` | `dominio` | ✅ Correcto |
| `Policy` | `bloque` / `politica` | ✅ Correcto |
| `Rule` | `regla` | ✅ Correcto |
| `Target` → `AnyOf/AllOf/Match` | `verbo` como elemento independiente | ✅ Correcto — simplificado |
| `Condition` → `Apply` | triplete `propiedad + operador + valor` | ✅ Correcto |
| **Target vs Condition — separación explícita** | `verbo` + triplete conviven en lista de hijos sin distinción | ⚠️ **Gap — ver H.1.c** |
| `RuleId` (identificador técnico) | texto de negocio en primer arg de `_ev()` | ❌ **No-conformidad §4.1 — ver F.6** |
| `Description` | no hay campo separado; texto va en `clave` | ❌ **No-conformidad §4.1 — ver F.6** |
| `Effect` = Permit\|Deny | `_ef('PERMIT…'/'DENY…')` | ✅ Correcto |
| `Obligation` | `obl:{key: val}` — todos vinculantes | ✅ Correcto |
| `Advice` | texto libre en `_ef()` sin separación | ⚠️ Informal — ver H.1.a y §C |
| `CombiningAlgorithm` | `combining_algorithm` | ⚠️ Ver H.1.b |
| `VariableDefinition` | No existe | ❌ Gap (reusable expressions) |
| `ObligationExpression` | Solo valores literales | ⚠️ Sin expressions dinámicas |

#### H.1.c — Target vs Condition colapsados (SBOS-0XX §4.3)

El árbol coloca el nodo `verbo` (equivalente al `<Target>` XACML) y los nodos
`propiedad+operador+valor` (equivalentes al `<Condition>`) en la **misma lista plana**
de hijos de `_ev()`, sin distinción estructural. XACML 3.0 los define como elementos
hermanos en el `<Rule>`, no como hijos indistinguibles.

**Impacto:** funcional — la semántica es preservada. Pero impide que el PrivilegeEngine
optimice la evaluación usando el `verb_id` como índice de candidatura (Target) antes de
evaluar la lógica booleana (Condition). Un motor XACML real descarta reglas por Target
sin evaluar su Condition, reduciendo la cantidad de evaluaciones en el hot path.

**Propuesta de conformidad:** distinguir explícitamente en AtomLang compilado:
```dart
// ÁRBOL FUENTE (actual — funcional pero XACML no estricto):
_ev('quorum.aprobadores', [
  _prop('approval.count_distinct_approvers'), _op('>='), _val('2'),
], verbo: 'approve'),

// ÁRBOL COMPILADO (conformidad estricta — separación Target/Condition):
// Target: verb_id = 'approve' (en columna verb_id de T-162)
// Condition: prop=approval.count_distinct_approvers op=>= val=2 (en hijos de T-162)
```
La separación puede hacerse en el compilador Rust de AtomLang (`atomc`) sin cambiar el
árbol fuente Dart — el compilador distingue el hijo `verbo` del resto al serializar.

#### H.1.a — Advice no es formal

XACML 3.0 define `<Advice>` como un elemento estructurado con `AdviceId` y
`AttributeAssignment`. Nuestro árbol embebe el advice en el texto del `_ef()`.
**Impacto:** bajo — el advice es opcional en XACML y no afecta la decisión. Sin embargo,
dificulta la auditoría automatizada.  
**Propuesta:** nuevo campo `advice:` separado en `_ef()` → ya existe el parámetro
`help:` de `_ef()`. Formalizar como `advice:` string con formato `'audit · <texto>'`.

#### H.1.b — `aggregate-strictest` no es XACML estándar

Los 3 primeros algoritmos son XACML 3.0 estándar. `aggregate-strictest` es
**algoritmo custom de bAuth** (no existe en OASIS XACML 3.0).

| Algoritmo en árbol | URI XACML 3.0 estándar | Estado |
|--------------------|------------------------|--------|
| `deny-overrides` | `urn:oasis:names:tc:xacml:3.0:…:deny-overrides` | ✅ Estándar |
| `permit-overrides` | `urn:oasis:names:tc:xacml:3.0:…:permit-overrides` | ✅ Estándar |
| `first-applicable` | `urn:oasis:names:tc:xacml:3.0:…:first-applicable` | ✅ Estándar |
| `aggregate-strictest` | **No existe en XACML 3.0** | ⚠️ Custom bAuth |

**Propuesta:** Documentar `aggregate-strictest` como extensión con referencia clara en
el vocabulario AtomLang (`atomlang_datos.dart`). Agregar `help:` explicando que acumula
el LoA más restrictivo de un conjunto de atoms — es un algoritmo de dominación en LoA.

---

### H.2 — NIST SP 800-63B-4 (Digital Identity — Authentication)

El árbol implementa el dominio D02 (Autenticación) y D03 (Contraseñas).

| Requisito NIST 800-63B-4 | Implementación en árbol | Estado |
|--------------------------|------------------------|--------|
| §5.1.1.1 Longitud mínima ≥15 (AAL1 solo) | `_val('@bauth_config_param.password_min_length_solo')` | ✅ |
| §5.1.1.1 Longitud mínima ≥8 (con MFA) | `_val('@bauth_config_param.password_min_length_mfa')` | ✅ |
| §5.1.1.1 Longitud máxima ≥64 | Átomo `longitud máxima` deniega > 64 | ❌ **ERROR F.3.b** |
| §5.1.1.1 Caracteres Unicode permitidos | No hay átomo restrictor de charset | ✅ (implícito) |
| §5.1.1.2 Screening HIBP/equivalente | `password.in_breached_list == false` | ✅ |
| §5.1.1.2 Historial de contraseñas | `password.in_history_last_N == false` | ✅ |
| §5.1.1.2 Sin rotación periódica forzada | IS_SET → DENY | ✅ (con corrección F.3.a) |
| §5.1.1.2 Sin hints | `password_policy.hints_enabled == false` → DENY | ✅ |
| §5.1.1.2 Sin preguntas de seguridad | `security_questions_enabled == false` → DENY | ✅ |
| §5.1.1.2 Permitir paste | `paste_allowed == true` | ✅ |
| §4.2 AAL1 — factor único | `min_loa: '1'` | ✅ |
| §4.3 AAL2 — MFA requerido | `min_loa: '2'`, TOTP/WebAuthn | ✅ |
| §4.4 AAL3 — hardware MFA | `min_loa: '3'`, WebAuthn roaming/platform | ✅ |
| §6.1 Duración de sesión con inactividad | `session.idle_minutes` atoms | ✅ |
| RFC 9470 Step-Up Auth | `require_step_up_loa: '3'` en obligations | ✅ |

**Hallazgo crítico confirmado:** §5.1.1.1 especifica que sistemas **DEBERÍAN soportar ≥64**,
no que **deban limitar a 64**. El átomo actual viola este requisito. Ver corrección en F.3.b.

---

### H.3 — NIST SP 800-207 (Zero Trust Architecture)

| Principio ZTA | Implementación en árbol | Estado |
|--------------|------------------------|--------|
| §3.1 P1 — Todos los recursos como recurso | `resource:` en cada átomo | ✅ |
| §3.1 P2 — Todo tráfico cifrado | `mtls_required`, `connection.client_cert_valid` | ✅ |
| §3.1 P3 — Acceso per-request verificado | Motor re-evalúa en cada request | ✅ |
| §3.1 P4 — Acceso determinado por policy dinámica | `risk.score`, `session.*`, `device.*` atoms | ✅ |
| §3.1 P5 — Monitoreo de postura de todos los assets | `device.mdm_enrolled`, `device.os_patch_status` | ✅ |
| §3.1 P6 — Autenticación y autorización dinámicas | CAEP + `risk.anomaly_detected` | ✅ |
| §3.1 P7 — Recolección de datos para mejora | obligations `audit:true`, `siem:wazuh` | ✅ |
| §3.3 PDP/PEP separados | bAuth = PDP, Kong = PEP | ✅ |
| §3.4 Enhanced Identity Governance | BitMask Dual + DAG | ✅ |
| §4.1 Micro-segmentación | Zonas (`zone.*` atoms) | ✅ |
| §4.3 Software-defined perimeters | Linkerd `AuthorizationPolicy` | ✅ |

**Estado general H.3: ✅ Bien alineado.** No se detectan gaps críticos.

---

### H.4 — ISO 27001:2022

| Control ISO 27001:2022 | Implementación en árbol | Estado |
|------------------------|------------------------|--------|
| A.5.15 Access control | `verbo` Target-gate + `resource` | ✅ |
| A.5.16 Identity management | `identity_proofing.level IN [IAL1-IAL3]` | ✅ |
| A.5.18 Access rights | BitMask + `delegation.*` atoms | ✅ |
| A.8.2 Privileged access rights | `role.level_of_assurance`, SoD atoms | ✅ |
| A.8.3 Information access restriction | `field.*`, `record.*` atoms | ✅ |
| A.8.11 Data masking | `masking_policy`, `apply_mask` operator | ✅ |
| A.8.15 Logging | `audit: 'true'` obligations, WORM storage | ✅ |
| A.8.16 Monitoring | `risk.*`, `risk.anomaly_detected` | ✅ |
| A.8.17 Clock synchronization | `date.*`, `time.*` atoms + `max_clock_drift` | ✅ |
| A.8.28 Secure coding | Validado por linter AtomLang | ✅ |
| A.5.33 Protection of records | `storage: 'WORM'`, `retention_years: '7'` | ✅ |
| A.5.34 Privacy / PII | `pii_access`, `pii_override`, `RGPD` attrs | ✅ |

**Estado general H.4: ✅ Cobertura alta.**

---

### H.5 — FIDO2 / WebAuthn (W3C Recommendation, 2024)

| Requisito FIDO2/WebAuthn | Implementación en árbol | Estado |
|--------------------------|------------------------|--------|
| `authenticatorAttachment` | `authenticator_attachment` enum | ✅ |
| `residentKey` | `resident_key` enum: `required`/`preferred` | ✅ |
| `userVerification` | `user_verification: 'required'` | ✅ |
| `attestation` | `attestation: 'direct'` | ✅ |
| PAD (Presentation Attack Detection) | `liveness: 'passive PAD'` | ✅ |
| FMR (False Match Rate) | `fmr: '1:10 000 mínimo'` | ✅ |
| `rpId` (Relying Party ID) | **No existe en el árbol** | ❌ Gap |
| `credentialId` | **No existe en el árbol** | ❌ Gap (se gestiona en DB, no en árbol) |
| `extensionData` | No existe | ⚠️ Menor |

**Gaps H.5:**
- `rpId` debería ser un `_a()` en los objetos WebAuthn — identifica el dominio RP para
  prevenir ataques de phishing de credenciales entre diferentes RP.  
  **Propuesta:** `_a('rp_id', '@bauth_config_param.webauthn_rp_id')` en cada objeto
  `webauthn_platform{}` y `webauthn_roaming{}`.

---

### H.6 — OAuth 2.0 / OIDC / CAEP

| Requisito | Implementación | Estado |
|-----------|---------------|--------|
| RFC 6749 — Authorization Code | `auth_request.code_challenge_method == S256` | ✅ |
| RFC 7636 — PKCE | `api_request.dpop_header_present == true` | ✅ |
| RFC 9449 — DPoP | `connection.token_binding_status == CURRENT` | ✅ |
| RFC 9068 — JWT Profile | JWT compacto (resultado AND, no bitmask completo) | ✅ |
| OIDC Core 1.0 — `openid` scope | `openid:` attribute siempre presente | ✅ |
| CAEP 1.0 Final (OpenID, Sep 2025) | `caep_event: 'session-revoked'` obligation | ✅ |
| SSF 1.0 Final (OpenID, Sep 2025) | bAuth = SSF Transmitter | ✅ |
| FAPI 2.0 — Financial Grade | `required_loa: 'AAL3'` para operaciones financieras | ✅ |

**Estado general H.6: ✅ Bien alineado.**

---

### H.7 — PCI DSS 4.0

| Requisito PCI DSS 4.0 | Implementación | Estado |
|-----------------------|---------------|--------|
| Req 7 — Access control | BitMask + `resource` atoms | ✅ |
| Req 8 — Authentication | MFA atoms, AAL2/AAL3 para `zone_financial` | ✅ |
| Req 8.3.6 — Min password length 12 | `@bauth_config_param.password_min_length_solo` ≥15 | ✅ |
| Req 8.3.9 — Re-auth 15 min idle | `session.idle_minutes` atoms | ✅ |
| Req 10 — Audit logging | `audit_level: ENHANCED`, WORM storage | ✅ |
| Req 10.3 — Log integrity | `audit_log.hash_chain_valid == true` | ✅ |
| Req 6.4.4 — Remove test accounts | `role.level_of_assurance` atoms | ⚠️ Indirecto |

---

### H.8 — Resumen de estado de alineación

| Estándar | Cobertura | Gaps críticos | Gaps menores |
|----------|----------|--------------|-------------|
| XACML 3.0 | 82% | `clave` no es RuleId slug (F.6) · Target/Condition colapsados (H.1.c) | `Advice` informal, `aggregate-strictest` custom, sin `VariableDefinition` |
| NIST 800-63B-4 | 95% | **Longitud máxima 64 viola §5.1.1.1** | — |
| NIST SP 800-207 | 97% | — | — |
| ISO 27001:2022 | 95% | — | — |
| FIDO2/WebAuthn | 88% | `rpId` faltante en objetos WebAuthn | `credentialId`, extensions |
| OAuth2/OIDC/CAEP | 98% | — | — |
| PCI DSS 4.0 | 93% | — | Test accounts |
| Ley 164 Bolivia | 100% | — | — |

**Prioridad de correcciones normativas:**
1. 🔴 **CRÍTICO** — F.3.b: Longitud máxima de contraseña (viola NIST 800-63B-4 §5.1.1.1)
2. 🔴 **CRÍTICO** — F.6: Todos los 291+ `clave` son descripciones de negocio, no slugs (viola XACML 3.0 §4.1)
3. 🟠 **ALTO** — F.3.a: IS_SET sin valor (viola XACML 3.0 §7.3.2)
4. 🟠 **ALTO** — H.5: `rpId` faltante en WebAuthn (riesgo de phishing cross-RP)
5. 🟠 **ALTO** — H.1.c: Target vs Condition colapsados (performance + conformidad §4.3)
6. 🟡 **MEDIO** — H.1.b: `aggregate-strictest` custom no documentado como extensión
7. 🟡 **MEDIO** — F.3.c: Case-sensitivity en verbos (riesgo de comportamiento diferente en runtime)
8. 🟢 **BAJO** — F.1: Claves con caracteres inválidos (mantenibilidad)
9. 🟢 **BAJO** — F.2: Valores mixtos número+texto (parseo ambiguo)
10. 🟢 **BAJO** — F.3.d: `'null'` placeholders

---

## I — Nueva observación: Tipo Normativo (`TipoNodo.normativo`)

> **Esta es la observación de adecuación a normas internacionales** requerida para
> completar el catálogo. Propone una nueva capacidad del árbol que hace la alineación
> normativa **explícita, formal y auditable** — no solo implícita en atributos `n1-n5`.

---

### I.1 — Problema actual: citaciones normativas informales

El árbol usa dos mecanismos informales para citar normas:

**Mecanismo 1 — Atributos `n1` a `n5`:**
```dart
_a('n1', 'NIST SP 800-162 · ABAC environment attributes'),
_a('n2', 'ISO 27001:2022 A.8.3 · information access restriction'),
```
Problema: texto libre sin estructura. No se puede consultar "todos los átomos que citan
ISO 27001 A.8.3" sin parsing de texto.

**Mecanismo 2 — Atributos de compliance con nombre de estándar:**
```dart
_a('ISO_27001_2022', 'A.8.15 logging · A.5.15 access control'),
_a('Ley_164_Bolivia', 'firma digital · registros electrónicos'),
```
Problema: clave es el nombre del estándar (no canónico) y el valor mezcla cláusulas.
No es consultable ni relacionable con un catálogo normativo externo.

---

### I.2 — Propuesta: `TipoNodo.normativo` + helper `_norm()`

Un nuevo tipo de nodo que representa una **citación normativa estructurada** dentro del árbol:

```dart
/// Tipo de nodo para citaciones normativas formales dentro del árbol RolTemplate.
/// Permite auditoría automatizada de cobertura normativa por átomo.
/// Columna T-162: tipo='normativo', clave=<standard_id>, valor=<clause_id>
normativo,
```

```dart
/// Crea un nodo de citación normativa.
/// [standard] — identificador canónico del estándar (ej: 'NIST-800-63B-4')
/// [clause]   — cláusula específica (ej: '§5.1.1.1')
/// [text]     — descripción en español del requisito citado
NodoTemplate _norm(String standard, String clause, String text) =>
    NodoTemplate('$standard', TipoNodo.normativo,
        valor: clause,
        help: text);
```

---

### I.3 — Catálogo de identificadores canónicos de estándar

Estos IDs son los `clave` de los nodos `normativo` en T-162:

| ID canónico | Nombre completo | URI de referencia |
|------------|----------------|------------------|
| `NIST-800-63B-4` | NIST SP 800-63B Rev.4 (2024) | `https://doi.org/10.6028/NIST.SP.800-63B-4` |
| `NIST-800-207` | NIST SP 800-207 Zero Trust Architecture | `https://doi.org/10.6028/NIST.SP.800-207` |
| `NIST-800-53r5` | NIST SP 800-53 Rev.5 | `https://doi.org/10.6028/NIST.SP.800-53r5` |
| `NIST-800-162` | NIST SP 800-162 (ABAC) | `https://doi.org/10.6028/NIST.SP.800-162` |
| `ISO-27001-2022` | ISO/IEC 27001:2022 | `https://www.iso.org/standard/82875.html` |
| `XACML-30` | XACML 3.0 (OASIS) | `https://docs.oasis-open.org/xacml/3.0/xacml-3.0-core-spec-os-en.html` |
| `FIDO2-WEBAUTHN` | W3C WebAuthn Level 3 (2024) | `https://www.w3.org/TR/webauthn-3/` |
| `PCI-DSS-40` | PCI DSS v4.0 | `https://www.pcisecuritystandards.org/` |
| `RFC-9449` | DPoP (OAuth 2.0 Demonstrating Proof of Possession) | `https://www.rfc-editor.org/rfc/rfc9449` |
| `RFC-9470` | OAuth 2.0 Step Up Authentication Challenge Protocol | `https://www.rfc-editor.org/rfc/rfc9470` |
| `CAEP-10` | CAEP 1.0 Final (OpenID Foundation, Sep 2025) | `https://openid.net/specs/openid-caep-1_0.html` |
| `LEY-164-BOL` | Ley 164 Bolivia — Telecomunicaciones y TI | Bolivia normativa nacional |
| `ADSIB-FD-POLT-015` | ADSIB Política de Certificación v2.3 | Bolivia normativa nacional |
| `NGAC-INCITS-565` | NGAC INCITS 565-2020 (Next Generation AC) | `https://webstore.ansi.org/` |

---

### I.4 — Ejemplo de uso en el árbol

```dart
// ANTES (citación informal dispersa en _a()):
_ev('contraseña comprometida (breach check)', [
  _a('n1', 'NIST SP 800-63B-4 §5.1.1.1'),
  _prop('password.in_breached_list'),
  _op('=='),
  _val('true'),
  _ef('DENY · "Contraseña en base de filtraciones — elige otra"'),
], verbo: 'configure'),

// DESPUÉS (citación formal con _norm()):
_ev('contraseña comprometida (breach check)', [
  _norm('NIST-800-63B-4', '§5.1.1.1',
      'Screening obligatorio contra listas de credenciales comprometidas '
      '(ej. Have I Been Pwned). Requisito SHALL.'),
  _prop('password.in_breached_list'),
  _op('=='),
  _val('true'),
  _ef('DENY · "Contraseña encontrada en base de datos de filtraciones — elige otra"'),
], verbo: 'configure'),
```

---

### I.5 — Impacto en T-162: columna `normativo_refs[]`

Para almacenar las citaciones normativas sin romper el esquema actual, se propone
una nueva columna en `idn_roles_template (T-162)`:

```sql
-- Propuesta: nueva columna en T-162
normativo_refs  jsonb  NULL,
-- Ejemplo de valor:
-- [{"standard": "NIST-800-63B-4", "clause": "§5.1.1.1",
--   "text": "Screening obligatorio contra listas comprometidas"}]
```

Alternativamente (sin cambiar T-162), los nodos `normativo` se insertan como hijos
de tipo `normativo` en T-162, siendo hermanos de `propiedad`/`operador`/`valor`.

---

### I.6 — Beneficios del Tipo Normativo

| Beneficio | Descripción |
|-----------|-------------|
| **Auditoría ISO 27001** | Consulta directa: `WHERE tipo='normativo' AND clave='ISO-27001-2022'` retorna todos los átomos que citan ese estándar |
| **Cobertura normativa cuantificable** | `COUNT(DISTINCT clave) WHERE tipo='normativo'` = cobertura del árbol |
| **Compliance evidenciado** | Cada decisión de acceso traza a la norma que la respalda |
| **Gap detection** | Átomos sin nodo `normativo` = gaps de justificación normativa |
| **Reportes regulatorios** | Generar informe PCI DSS automáticamente desde el árbol |
| **Alineación bi18n** | El texto del `_norm()` en español + el `clause` como ID universal |

---

## J — Checklist de Conformidad XACML / ABAC

> **Fuente:** SBOS-0XX §5 — _Checklist de conformidad estricta para un átomo nuevo._  
> Esta tabla muestra el estado **actual** del árbol Dart para cada ítem del checklist.
> Es la base del plan de reparación — se completará a `✅` tras aplicar las correcciones
> documentadas en la Sección F.

### J.1 Checklist SBOS-0XX §5 — Estado del árbol actual

| # | Criterio de conformidad | Estado árbol actual | Corrección requerida |
|---|------------------------|--------------------|--------------------|
| **J-01** | `clave` es identificador técnico estable (slug con `.` — no texto de negocio) | ❌ **INCUMPLE** — 291 átomos tienen texto de negocio en `clave` | F.6 — generar slug en compilador `atomc` o parámetro `id:` en `_ev()` |
| **J-02** | `help` contiene la descripción legible de negocio (`Description` XACML) | ⚠️ **PARCIAL** — el texto existe (en primer arg de `_ev()`) pero en la columna errónea | F.6 — reasignar: primer arg de `_ev()` → columna `help` |
| **J-03** | `atom_position` asignado vía mecanismo gobernado (`SEQUENCE`) — nunca ad-hoc | ✅ **CONFORME** — T-162 usa `SEQUENCE` para `atom_position` (documentado en SBOS-0XX §4.6) | — |
| **J-04** | Efecto expresado estrictamente como `Permit` o `Deny` (sin overload semántico) | ✅ **CONFORME** — todos los `_ef()` usan prefijo `PERMIT ·` o `DENY ·` | — |
| **J-05** | Si tiene lógica de aplicabilidad: distingue `Target` (candidatura) de `Condition` (evaluación) | ⚠️ **PARCIAL** — `verbo` existe como columna `verb_id` separada en T-162; pero en árbol Dart están en lista plana sin distinción explícita | H.1.c — el compilador `atomc` debe separar `verbo` de los tripletes al serializar |
| **J-06** | Obligaciones en recurso (T-171) marcadas como `obligation` (vinculante) vs `advice` (informativo) | ⚠️ **PARCIAL** — todo va a `obligation`; claves informativas (`alert`, `notify`, `permit_reason`) no se distinguen de las vinculantes (`required_loa`, `invalidate_sessions`) | Sección C tabla — necesita columna `advice JSONB` en T-171 |
| **J-07** | Atributos en la lógica del átomo categorizados por tipo ABAC (Subject/Object/Operation/Environment) | ⚠️ **IMPLÍCITO** — la categoría puede inferirse por el namespace de la prop (`device.*` → Environment, `user.*` → Subject), pero no está declarada explícitamente en el árbol ni en T-162 | Sección B tabla de categorías — basta con inferencia por namespace en el compilador; no requiere columna nueva |
| **J-08** | El átomo nació a través del flujo gobernado — nunca insertado directamente sin reserva de `atom_position` | ✅ **CONFORME** (árbol Dart — la inserción real está gobernada por `SEQUENCE`) | — |

### J.2 Resumen de conformidad

| Estado | Criterios | Descripción |
|--------|----------|-------------|
| ✅ Conforme | J-03, J-04, J-08 | 3 de 8 criterios ya conformes |
| ⚠️ Parcial / Implícito | J-02, J-05, J-06, J-07 | 4 criterios conformes en semántica, no en estructura formal |
| ❌ Incumple | J-01 | 1 criterio con no-conformidad explícita que afecta 291 átomos |

**Resultado:** El árbol es **funcionalmente correcto** pero **estructuralmente no-conforme** con
XACML 3.0 en su representación de identidad de átomo (J-01/J-02). Las otras deficiencias
(J-05, J-06) son optimizaciones de conformidad que no afectan la corrección funcional.

**Plan de reparación en orden de prioridad:**
1. **F.3.b** (violación normativa CRÍTICA — antes del merge a producción)
2. **F.6 + J-01/J-02** (slug en compilador `atomc` — decisión arquitectónica pendiente)
3. **F.3.a** (IS_SET semántico — baja complejidad)
4. **H.5** (rpId WebAuthn — agregar atributo en 2 bloques)
5. **F.1** (normalizar claves con caracteres inválidos — 13 correcciones)
6. **F.2/F.3.d** (valores mixtos y null placeholders — 18 correcciones)
7. **J-06** (columna `advice` T-171 — DDL + reclasificación de claves)
8. **F.4** (291 `verbo:` faltantes — requiere análisis semántico caso a caso)
9. **J-07** (categorías ABAC — inferencia en compilador, sin cambio en árbol Dart)

---

## K — Índice de dominios de propiedad (§B.1) — organizado por plano de control

Los 49 namespaces de atributo catalogados en §B.1 asignados al plano de control
al que pertenecen (D00–D13 + D99) según `1.01_MANUAL-DOMINIOS-v1.0.md`.
El orden de filas sigue el pipeline de evaluación del DomainRegistry.

---

### K.1 D00 — Identidad Organizacional
_Pre-condición estructural · ISO 24760-2:2025_

| Subsección | Namespace | Descripción |
|------------|-----------|-------------|
| B.1.z | `identity_proofing.*` | Prueba de identidad IAL1–IAL3 |
| B.1.av | `user.*` | Contexto del usuario autenticado (identidad activa) |

---

### K.2 D1 — Acceso Lógico
_Fast-Path < 0.5 ns · NIST 800-63B-4 · RFC 9470 · CAEP_

| Subsección | Namespace | Descripción |
|------------|-----------|-------------|
| B.1.b | `action.*` | Acción solicitada (Target.Action del átomo) |
| B.1.j | `conflict.*` | Conflictos SoD — Conflict Matrix |
| B.1.m | `contract.*` | Contrato de acceso (modo APPEND_ONLY, etc.) |
| B.1.x | `field.*` | Campo de dato — enmascaramiento y acceso a nivel campo |
| B.1.ag | `permission.*` | Análisis de permisos — uso vs asignados (privilege creep) |
| B.1.ah | `query.*` | Consultas — límite de registros, rate limiting |
| B.1.ai | `record.*` | Registro de datos — Row-Level Security |
| B.1.an | `role.*` | Propiedades del rol activo (LoA, nivel jerárquico) |
| B.1.au | `ui.*` | Interfaz de usuario — visibilidad de menús y acciones |
| B.1.ax | `zone.*` | Zona de acceso — tipo, nivel de seguridad, sensibilidad |

---

### K.3 D2 — Acceso Físico
_Fast-Path + OSDP · IEC 60839-11-5 · OSDP v2.2.2 · SP 800-116_

| Subsección | Namespace | Descripción |
|------------|-----------|-------------|
| B.1.w | `facility.*` | Instalación física — presencia dual, mantrap, zona |

---

### K.4 D3 — Financiero
_Policy-Path · PCI DSS 4.0.1 · SOX §404 · COSO · ISO 20022_

| Subsección | Namespace | Descripción |
|------------|-----------|-------------|
| B.1.d | `approval.*` | Flujo de aprobación — quórum, SLA, jerarquía |
| B.1.r | `descuento.*` | Descuentos — porcentaje máximo por tier |
| B.1.aa | `invoice.*` | Factura — límites, modalidad, SIN Bolivia |
| B.1.at | `transaction.*` | Monto de transacción — límites y umbrales |

---

### K.5 D4 — Temporal
_Policy-Path (encadenado a D1) · GTRBAC · RFC 5545 · ISO 8601_

| Subsección | Namespace | Descripción |
|------------|-----------|-------------|
| B.1.p | `date.*` | Fecha — días del mes habilitados |
| B.1.ao | `schedule.*` | Ventana horaria — autorización por calendario |
| B.1.as | `time.*` | Hora local — rango de acceso autorizado |

---

### K.6 D5 — Biométrico
_External-Path · ISO/IEC 30107-3 · SP 800-63B §5.2.3_

| Subsección | Namespace | Descripción |
|------------|-----------|-------------|
| B.1.g | `biometric.*` | Biometría — FMR, liveness, PAD |

---

### K.7 D6 — Geoespacial
_External-Path (encadenado a D1) · OGC GeoFence · BeyondCorp_

| Subsección | Namespace | Descripción |
|------------|-----------|-------------|
| B.1.y | `gps_attestation.*` | Atestación GPS — precisión, velocidad, integridad |
| B.1.ab | `location.*` | Ubicación — país, ciudad, zona permitida |

---

### K.8 D7 — Red
_External-Path (vía Kong) · SP 800-207 ZTA · IEEE 802.1X · CAEP_

| Subsección | Namespace | Descripción |
|------------|-----------|-------------|
| B.1.c | `api_request.*` | Solicitud API — DPoP header, PKCE |
| B.1.k | `connection.*` | Conexión de red — mTLS, VPN, token binding |
| B.1.ak | `request.*` | Solicitud HTTP / API — método, rate, origen |

---

### K.9 D8 — Contexto / Sesión
_Pre-BitMask · SBOS-049 · W3C Trace Context · CAEP_

| Subsección | Namespace | Descripción |
|------------|-----------|-------------|
| B.1.l | `context.*` | Contexto de evaluación — ctx_id, justificación, sujeto |
| B.1.s | `device.*` | Dispositivo del usuario — MDM, parches, cifrado |
| B.1.t | `emergency.*` | Sesión de emergencia — aprobaciones, duración, notificación |
| B.1.am | `risk.*` | Puntuación de riesgo — score, anomaly, modo continuo |
| B.1.ap | `session.*` | Sesión activa — idle, concurrencia, fingerprint |

---

### K.10 D9 — Credenciales
_Pre-BitMask · SP 800-63B AAL1-3 · FIDO2 · WebAuthn_

| Subsección | Namespace | Descripción |
|------------|-----------|-------------|
| B.1.a | `account.*` | Cuenta de usuario — inactividad, estado |
| B.1.f | `auth_request.*` | Solicitud de autenticación — PKCE, code challenge |
| B.1.i | `cert.*` | Certificados digitales — emisor, expiración, revocación |
| B.1.n | `credential.*` | Credenciales — algoritmo hash, breach, binding |
| B.1.u | `enrollment.*` | Registro / inscripción — IAL, método registrado |
| B.1.ac | `login.*` | Intentos de login — fallos, lockout, rate |
| B.1.af | `password.*` / `password_policy.*` | Contraseñas — longitud, historial, screening |
| B.1.al | `revocation.*` | Revocación de acceso — propagación, grace period |

---

### K.11 D10 — Delegación
_Policy-Path (reducción AND) · INCITS 359 DSD · NIST AC-5_

| Subsección | Namespace | Descripción |
|------------|-----------|-------------|
| B.1.q | `delegation.*` | Delegación de permisos — scope, jerarquía, período |
| B.1.aj | `renewal.*` | Renovación de asignación — contador, aprobación |

---

### K.12 D11 — Auditoría
_Post-hoc · ISO 27001 A.8.15 · PCI 10.3.2 · NIST AU-2/3_

| Subsección | Namespace | Descripción |
|------------|-----------|-------------|
| B.1.e | `audit.*` | Auditoría — nivel, retención, hash-chain, eventos |
| B.1.v | `event.*` | Eventos de seguridad — tipo, severidad, destino SIEM |

---

### K.13 D12 — Blockchain / Anclaje
_External-Path · NIST IR 8202 · EIP-725/735 · W3C DID_

| Subsección | Namespace | Descripción |
|------------|-----------|-------------|
| B.1.h | `blockchain.*` | Transacciones blockchain — valor, límites, chain_id |
| B.1.aw | `wallet.*` | Wallet cripto — flag de compromiso |

---

### K.14 D13 — Firma Digital Externa
_Ley 164 Bolivia · ADSIB-FD-POLT-015 v2.3_

| Subsección | Namespace | Descripción |
|------------|-----------|-------------|
| B.1.aq | `signing.*` | Firma digital — algoritmo, key storage, motor ADSIB |

---

### K.15 D99 — Baseline Administrativo Global
_Fuera del BitMask · transversal a todos los dominios_

| Subsección | Namespace | Descripción |
|------------|-----------|-------------|
| B.1.ad | `notification.*` | Notificaciones — canal, destinatarios, bNotify |
| B.1.ae | `override.*` | Anulaciones — excepciones administrativas aprobadas |
| B.1.ar | `termination.*` | Baja de empleado — offboarding, aprobaciones, plazos |

---

### K.16 Referencias cruzadas entre dominios

| Subsección | Namespace | Descripción | Dominios referenciados |
|------------|-----------|-------------|----------------------|
| B.1.o | `d4_temporal_ref` | Referencia a período de validez temporal | D4 + D8 |
| B.1.o | `d6_geospatial_ref` | Referencia a lista de ubicaciones permitidas | D6 |

---

### K.17 Resumen de cobertura por dominio

| Dominio | Nombre | Namespaces | Cobertura |
|---------|--------|-----------|----------|
| D00 | Identidad Organizacional | `identity_proofing.*`, `user.*` | 2 |
| D1 | Acceso Lógico | `action.*`, `conflict.*`, `contract.*`, `field.*`, `permission.*`, `query.*`, `record.*`, `role.*`, `ui.*`, `zone.*` | 10 |
| D2 | Acceso Físico | `facility.*` | 1 |
| D3 | Financiero | `approval.*`, `descuento.*`, `invoice.*`, `transaction.*` | 4 |
| D4 | Temporal | `date.*`, `schedule.*`, `time.*` | 3 |
| D5 | Biométrico | `biometric.*` | 1 |
| D6 | Geoespacial | `gps_attestation.*`, `location.*` | 2 |
| D7 | Red | `api_request.*`, `connection.*`, `request.*` | 3 |
| D8 | Contexto / Sesión | `context.*`, `device.*`, `emergency.*`, `risk.*`, `session.*` | 5 |
| D9 | Credenciales | `account.*`, `auth_request.*`, `cert.*`, `credential.*`, `enrollment.*`, `login.*`, `password.*`, `revocation.*` | 8 |
| D10 | Delegación | `delegation.*`, `renewal.*` | 2 |
| D11 | Auditoría | `audit.*`, `event.*` | 2 |
| D12 | Blockchain / Anclaje | `blockchain.*`, `wallet.*` | 2 |
| D13 | Firma Digital Externa | `signing.*` | 1 |
| D99 | Baseline Global | `notification.*`, `override.*`, `termination.*` | 3 |
| —  | Referencias cruzadas | `d4_temporal_ref`, `d6_geospatial_ref` | 2 |
| **Total** | | | **51** |
