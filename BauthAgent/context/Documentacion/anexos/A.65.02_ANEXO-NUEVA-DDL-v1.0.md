# A.65.02 — Nueva DDL · Inventario de Tablas

**Versión:** 2.1  **Fecha:** 2026-08-01  **Estado:** v2.1 — nombres canónicos inglés corregidos (47 reemplazos); 8 tablas sin DDL marcadas ⚠️; T-562/T-563 nuevas. 134 tablas documentadas.

## Propósito

Inventario limpio de tablas para el rediseño completo de la DDL de `bauth`.
Partimos desde cero — las tablas marcadas ELIMINAR en A.65 v1.5 no se incluyen aquí.
Cada entrada define: código, nombre canónico definitivo, y propósito.
El diseño DDL (columnas, constraints, índices) se desarrolla en sesiones posteriores.

## Convenciones

- Todos los PKs: `uuidv7()` — orden temporal nativo, sin secuencias.
- Schema `bglobal`: catálogos globales compartidos por todo el ecosistema SBOS.
- Schema `bauth`: tablas propias del daemon bAuth.
- Toda tabla con historial auditado: hash-chain WORM append-only (ISO 27001 A.8.15).
- Tablas con historia temporal: `WITHOUT OVERLAPS` PG18 (no tablas `*_version_log`).

---

## GLOBAL

> Catálogos de referencia compartidos por todo el ecosistema. Sin lógica de negocio. Valores ISO y parámetros de sistema.

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-001 | `bglobal.global_language` | Catálogo ISO 639-1/3 de idiomas — fuente de verdad para la internacionalización del sistema |
| T-002 | `bglobal.global_country` | Catálogo ISO 3166-1 de países — FK en tablas de identidad y geolocalización |
| T-003 | `bglobal.global_currency` | Catálogo ISO 4217 de monedas — referencia para facturación y límites financieros por dominio |
| T-004 | `bglobal.geo_timezone` | Catálogo IANA de zonas horarias — base para restricciones de validez temporal (D4/B2) |
| T-059 | `bglobal.menu_item` | Ítems de menú de aplicación — catálogo de opciones navegables del dashboard por módulo |
| T-060 | `bglobal.menu_context` | Contextos de menú — agrupa ítems de menú por contexto de rol y dominio |
| T-061 | `bglobal.menu_item_atom` | Relación ítem↔átomo de privilegio — puente entre visibilidad de menú (B7 CAPA 2) y el motor BitMask |
| T-114 | `bglobal.global_config` | Parámetros globales del sistema — configuración de infra no ligada a ningún tenant ni rol. Cubre el `scope='global'` del PIP `@bauth_config_param` (suelo del sistema: NIST, SIN Bolivia, límites de seguridad estándar). Ver A.48. |

---

## TENANT

> Infraestructura de multi-tenancy. Cada tenant es una organización cliente aislada. Estas tablas son el piso mínimo que el Motor de Identidad (D00) crea al registrar un nuevo tenant.

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-005 | `bauth.idn_tenant` | Ancla de gobernanza — cada tenant es una fila aquí; toda FK de la DDL arranca desde `tenant_id` |
| T-006 | `bauth.idn_tenant_currencies` | Monedas habilitadas por tenant — determina en qué monedas opera el tenant (default: BOB) |
| T-007 | `bauth.idn_tenant_languages` | Idiomas habilitados por tenant — determina los idiomas disponibles en el dashboard y las APIs |
| T-008 | `bauth.idn_tenant_verification` | Estado de verificación del tenant — nivel IAL alcanzado, documentos validados, fecha de expiración |
| T-009 | `bauth.idn_tenant_config` | Configuración específica por tenant — fuente de verdad de `@bauth_config_param` en el árbol de políticas |
| T-010 | `bauth.idn_tenant_domain` | Dominios DNS del tenant — prefijo del `ctx_id` interno/externo (capa 1 de SBOS-049) |
| T-011 | `bauth.idn_tenant_network` | Redes autorizadas por tenant — CIDRs permitidos para acceso; validados por el PEP en D7 |
| T-013 | `bauth.idn_tenant_calendar_assignment` | Calendarios asignados al tenant — horarios laborales y feriados que condicionan la validez temporal de roles |

> **Nota PIP — `@bauth_config_param.*`:** La sintaxis `@bauth_config_param.<clave>` en AtomLang es una referencia PIP resuelta en runtime — **no se crea ninguna tabla separada** `bauth_config_param`. El Motor de Identidad (PDP) resuelve la referencia en cascada: primero busca en **T-009** (`bauth.idn_tenant_config`, parámetros del tenant — techo y piso por organización), y si no encuentra, en **T-114** (`bglobal.global_config`, parámetros globales cross-daemon — suelo del sistema). El catálogo de 20 parámetros, la sintaxis de referencia y la gobernanza del ciclo de cambio se documentan en A.48.

---

## ROLES

> Identidad de los roles y árbol de políticas. Dos tablas distintas: T-041 guarda el QUIÉN (548 roles con su jerarquía), T-162 guarda el QUÉ PUEDE (el árbol de políticas compartido). Son complementarias, no redundantes.

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-040 | `bauth.idn_roles_rol_type` | Catálogo de tipos de cuenta — 10 tipos (INDIVIDUAL, M2M, SYSTEM, GROUP, TEMPLATE, VIRTUAL, BOT, DEVICE, SERVICE, EMERGENCY) que clasifican todo rol del sistema |
| T-041 | `bauth.idn_roles_rol_hierarchical` | Registro de identidad de roles — árbol de los 548 roles con jerarquía parent/child, tier, status, nombre, versión y metadatos B1. **B02:** columnas `validity_type / valid_from / valid_until / duration_interval / max_renewals / renewal_count` + trigger `trg_irrh_b02_validity`. Es el QUIÉN del sistema. |
| T-B02L | `bauth.idn_roles_rol_lifecycle_event` | Log WORM de transiciones de estado del rol (B02 §lifecycle) — registra cada cambio de estado con `trigger_type` (MANUAL/AUTO_EXPIRY/RECONCILE/IGA_REVIEW/BREAKGLASS/BOOTSTRAP), actor, razón y snapshot de vigencia. REVOKE UPDATE/DELETE. Equivalente a T-187 para NHI. |
| T-042 | `bauth.idn_roles_rol_tier` | Parámetros de autenticación por tier — LOA requerido, métodos MFA disponibles, timeouts de sesión, max_sessions, step_up y referencia NIST AAL. PIP del PDP al evaluar D1/D9. |
| T-063 | `bauth.idn_roles_rol_closure` | Closure table del DAG de herencia OR — materializa todas las rutas ancestro→descendiente para calcular la máscara BitMask acumulada en O(1) |
| T-161b | `bauth.idn_policy_node_type` | Catálogo de tipos de nodo del árbol de políticas — fuente única de verdad para presentación (color, fuente, badge), abreviatura y descripción bilingüe. El cliente Flutter renderiza el árbol consultando esta tabla sin hardcoding. Reemplaza el CHECK chk_irt_tipo de T-162. |
| T-162 | `bauth.idn_roles_template` | Árbol jerárquico de políticas — UN árbol compartido por todos los roles; cada nodo es dominio, bloque, política, regla, evaluación, átomo u obligación. Es la fábrica de átomos del motor BitMask. El QUÉ PUEDE el sistema. |
| T-163 | `bauth.idn_roles_template_history` | Historial WORM del árbol de políticas — cada cambio al árbol T-162 genera una entrada inmutable aquí para trazabilidad forense |
| T-194 | `bauth.idn_roles_iga_category` | Categorías de gobernanza IGA para el ciclo de vida de roles — determina frecuencia de certificación (`review_cycle_days`) y si requiere campaña PAM trimestral (`is_privileged`). 7 categorías: BUSINESS, IT_INFRASTRUCTURE, APPLICATION, PRIVILEGED, EMERGENCY, SERVICE, STANDARD. |

---

## VERSIONADO

> Motor de Versionado Universal (MVU 1.13) — gobierna el ciclo de vida de las definiciones de rol. Cuatro tablas que responden juntas: ¿cómo era?, ¿qué se propone?, ¿hasta cuándo se guarda?, ¿qué cambió en el contrato?

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-152 | `bauth.idn_roles_ver_b01_audit_log` | Historia WORM de versiones cerradas de T-041 — responde "¿cómo era el rol X el día Y?" con delta por bloque normado; ancla MAJOR con snapshot completo; no-solape `WITHOUT OVERLAPS` PG18 + btree_gist. REVOKE UPDATE/DELETE. `[B01 §audit.change_history[]]` |
| T-153 | `bauth.idn_roles_ver_b03_approval_queue` | Cola de cambios MAJOR pendientes de quórum N-de-M sobre T-041 — la versión vigente sigue rigiendo mientras `status=PENDING`; dual control (`resolved_by ≠ proposed_by` NIST AC-5); SLA con escalación. `[B03 §approval_workflow]` |
| T-154 | `bauth.idn_roles_ver_b01_retention_policy` | Política de retención legal por entidad C1 — `hot_window` (historia viva), `compaction_policy` (KEEP_ALL/KEEP_ANCHORS/KEEP_LAST_N), piso irrenunciable ≥ 365 días (D99); `legal_hold=true` suspende toda purga. `[B01 §audit gobernanza]` |
| T-155 | `bauth.idn_roles_ver_contract_revision_log` | Changelog estructural del contrato RolTemplate entre versiones (v5.0→v6.0) — registra bloques cambiados, normas que entran/salen, compatibilidad BREAKING/COMPATIBLE; append-only histórico. `[Plano A — contratos]` |

---

## IDENTIDAD

> Motor de Identidad D00 v2.0 — catálogo universal de actores y sus atributos. Reemplaza las tablas org_empresa/org_sucursal/org_pos_logico (eliminadas) con un modelo jerárquico unificado de 5 niveles.
>
> **Estado de completitud D00 (2026-07-28 — A.65.03.01.01_COMPLETITUD_D00.md v2.0.0):**
> D00 **COMPLETO** — 9/9 bloques satisfechos. DDL v2.6.0 implementada en VPS SBOSDB.
> Las 10 tablas de D00 (T-156..T-159 + T-165..T-168 + T-160..T-161) cubren todos los bloques B01-B09.
>
> **Decisión de diseño PENDIENTE (HITL) — modelo de metadatos de `idn_identity_attribute`:**
> El modelo de 25 metadatos (1.07 §4.0 — SCIM 2.0, NIST SP 800-63A, GDPR, OIDC4IDA) define columnas como `classification`, `mask`, `retention`, `mutability`, `required`, `uniqueness`, `source`, `ial` que aún no están en el DDL actual. Son constantes por `(category, attr_key, type)`. Se debe elegir entre:
> - **Opción A** — columnas directas en `idn_identity_attribute` (una por fila, redundantes pero simples).
> - **Opción B** — tabla catálogo separada `idn_identity_attribute_catalog (category, attr_key, type, mutability, returned, uniqueness, required, ial, source, classification, mask, retention, …)` que el Motor de Identidad consulta para obtener las reglas de validación por tipo de atributo.
> Esta decisión afecta solo el diseño de columnas, no el listado de tablas de esta sección.

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-156 | `bauth.idn_identity_entity` | Catálogo universal de entidades — árbol de 5 niveles: `tenant → bdomain → bsubdomain → pos → actor`. Todo actor del sistema (humano, servicio, rol, dispositivo, bot) es una fila aquí. Los niveles 2/3/4 son las capas del `ctx_id` (SBOS-049 §3.1). |
| T-157 | `bauth.idn_identity_attribute` | Atributos extensibles EAV de cualquier entidad — almacena sin ALTER TABLE: NIT, razón social, correos, teléfonos, documentos de identidad, códigos SIN, certificados. `atom_code` vincula cada atributo con el motor BitMask para gobernanza vía D00. |
| T-158 | `bauth.idn_identity_attribute_history` | Historial WORM de cambios de atributos — append-only, particionado por mes (RANGE changed_at, 6 particiones); registra INSERT/UPDATE/SOFT_DELETE en T-157 con hash-chain SHA-256. REVOKE UPDATE/DELETE. Cumplimiento: ISO 27001 A.8.15, PCI DSS 10.3.2, GDPR Art. 30. ✅ IMPLEMENTADA v2.5.0 |
| T-159 | `bauth.idn_identity_requirement` | Completitud mínima por tipo de entidad y nivel IAL — define qué atributos son obligatorios antes de crear una entidad según su tipo y el nivel IAL requerido (IAL1/IAL2/IAL3). Validado por el Motor de Identidad antes de cualquier INSERT. Seeds: 8 filas para Bolivia. ✅ IMPLEMENTADA v2.4.0 |
| T-165 | `bauth.idn_identity_proofing` | Proceso de Identity Proofing por usuario (actor). Registra: tipo de proofing (SELF_ASSERTED/REMOTE/IN_PERSON/TRUSTED_REFEREE), evidencias FAIR/STRONG/SUPERIOR (NIST SP 800-63A-4 §5), IAL alcanzado, revisor (obligatorio IAL3), vigencia y fecha de re-proofing. El Motor de Identidad consulta la fila más reciente status=PASSED para determinar el IAL actual del actor. ✅ IMPLEMENTADA v2.6.0 |
| T-166 | `bauth.idn_identity_consent` | Registro WORM del consentimiento de privacidad por sujeto de datos. Otorgamiento y retirada en la misma fila; REVOKE DELETE (evidencia forense). Bases legales: CONSENT/CONTRACT/LEGAL_OBLIGATION/VITAL_INTEREST/PUBLIC_TASK/LEGITIMATE_INTEREST (GDPR Art. 6). Ley 1174 Bolivia Art. 12-15. ✅ IMPLEMENTADA v2.6.0 |
| T-167 | `bauth.idn_identity_vc` | Ciclo de vida de Verifiable Credentials emitidas por bAuth (Issuer) o verificadas (Verifier). Formatos: W3C VCDM 2.0 (Rec mayo 2025), VCDM 1.1 (legacy), SD-JWT VC (selective disclosure). Soporte W3C VC Status List 2021 para revocación escalable. Trazabilidad al proofing origen vía FK T-165. ✅ IMPLEMENTADA v2.6.0 |
| T-168 | `bauth.idn_tenant_fal_config` | Configuración del Federation Assurance Level (FAL) por Relying Party — FAL1 (aserción firmada) · FAL2 (DPoP bound) · FAL3 (mTLS holder-of-key). Constraints garantizan coherencia FAL↔controles (FAL2→DPoP/mTLS · FAL3→mTLS obligatorio). Motor OIDC consulta esta tabla al construir el authorization_endpoint response. ✅ IMPLEMENTADA v2.6.0 |
| T-160 | `bauth.idn_identity_synonym` | Sinónimos y abreviaturas para búsqueda difusa — fuente de verdad de archivos `.syn` de PostgreSQL para el motor de búsqueda D93. Administrable desde el dashboard. |
| T-161 | `bauth.idn_identity_synonym_sync` | Control de sincronización de diccionarios — registra cuándo se regeneraron los archivos `.syn`; evita recarga innecesaria cuando no hubo cambios en T-160 desde el último sync. |

> **NHI — Identidades No-Humanas (G-21..G-24 · GAPS-DDL-PRIVILEGIOS-II.md):**
> Los daemons de SBOS y cualquier identidad máquina del ecosistema son NHI gobernadas aquí.
> `idn_roles_nhi_identity` es la entidad raíz; `idn_roles_nhi_lifecycle_event` e `idn_roles_nhi_certification`
> son su ciclo de vida y evidencia de revisión periódica. `idn_roles_nhi_agent_identity` especializa los NHI
> de tipo agente IA autónomo con control de scope y profundidad de orquestación.

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-186 | `bauth.idn_roles_nhi_identity` | Entidad raíz de toda identidad máquina — daemons, pipelines CI/CD, bots, agents IA. `system_ref` es el identificador único por tenant; `owner_id` = humano responsable (accountability). `last_used_at` actualizado en cada autenticación del NHI; `review_at` define cadencia de revisión (30d CI/CD · 90d service account). Seeds: un NHI por daemon SBOS activo al inicializar el tenant. ✅ G-21 |
| T-187 | `bauth.idn_roles_nhi_lifecycle_event` | Log WORM de eventos del ciclo de vida de un NHI — PROVISIONED, CERTIFIED, ROTATED, SUSPENDED, REACTIVATED, DECOMMISSIONED, OWNER_CHANGED. Un trigger en T-186 inserta automáticamente en cada cambio de estado. Fuente forense del historial completo del NHI. ✅ G-22 |
| T-188 | `bauth.idn_roles_nhi_certification` | Certificación periódica mensual del NHI — evidencia de que el propietario técnico revisó el NHI, verificó su uso (`access_count`) y tomó una decisión (CERTIFY / DECOMMISSION / REDUCE_SCOPE). `decision='DECOMMISSION'` dispara la baja en T-186. ✅ G-22 |
| T-190 | `bauth.idn_roles_nhi_agent_identity` | Especialización de NHI para agentes IA autónomos — extiende T-186 con `max_permission_scope` (techo de dominios del agente), `orchestrator_id` (padre en la cadena), `can_spawn_agents` + `max_spawn_depth`. ⚠️ BLOQUEADO por decisión HITL pendiente: herencia de permisos padre→hijo. ✅ G-24 |

---

## CALENDARIO

> Infraestructura temporal del sistema. Schema `bcalendar` — tablas que gobiernan años fiscales, horarios laborales, días festivos y eventos que condicionan la validez de roles (D4/B2) y ventanas de transacciones financieras (D3).
> La asignación de un calendario a un tenant/empresa vive en `bauth.idn_tenant_calendar_assignment` (T-013, sección TENANT).

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-012 | `bcalendar.cal_fiscal_year` | Años fiscales por tenant — define el inicio y fin del año fiscal para cierres contables y ventanas de autorización financiera |
| T-014 | `bcalendar.cal_calendar` | Calendarios laborales — cada calendario nombrado (ej. "Bolivia Estándar") con su zona horaria y reglas base; D4/B2 enlaza un calendario a cada rol |
| T-015 | `bcalendar.cal_event` | Eventos de calendario — fechas especiales que afectan ventanas de acceso o procesamiento (cierre mensual, auditoría anual) |
| T-016 | `bcalendar.cal_alarm` | Alarmas de eventos — D4 `review_date` dispara alerta 30 días antes del vencimiento del rol para revisión de acceso |
| T-017 | `bcalendar.cal_notification_log` | Log de notificaciones de calendario — registro de alertas enviadas vía bNotify para trazabilidad de revisiones periódicas |
| T-018 | `bcalendar.cal_holiday` | Días festivos y no laborables — fuente de verdad de feriados bolivianos + feriados propios del tenant; D3 `transaction_schedule` depende de días hábiles reales |
| T-019 | `bcalendar.cal_schedule` | Horarios laborales — ventanas horarias por tenant/turno (09:00–16:00); D3 y D1 los consultan para restricciones de operación |
| T-124 | `bcalendar.cal_overtime_policy` | Políticas de horas extra — define si el acceso fuera de horario requiere override de emergencia (D3) y qué aprobaciones activa |
| T-125 | `bcalendar.cal_break_policy` | Políticas de descanso — ventanas de pausa que suspenden sesiones activas; soporte de D4 temporal y gestión de sesión D1 |

---

## USUARIOS

> Registro de cuentas de usuario (subscriber accounts). **Separado de las entidades D00** (`idn_identity_entity` — jerarquía organizacional) — aquí vive la cuenta digital del actor: identificador de login, estado del ciclo de vida (ACTIVE / LOCKED / SUSPENDED / DEACTIVATED), nivel IAL alcanzado, perfil SCIM 2.0, datos de recuperación y vínculos con el actor D00 y los roles asignados.
>
> Un actor D00 puede tener 0, 1 o N cuentas de usuario. Esta distinción sigue el modelo NIST SP 800-63-4 §3 que separa la **identidad** (evidencia del mundo real → D00), el **subscriber account** (cuenta digital → esta sección) y el **authenticator** (dispositivo/secreto de prueba → sección AUTENTICACIÓN). Una cuenta puede estar vinculada a múltiples tenants con roles distintos sin duplicar la identidad.
>
> **Estándares:** NIST SP 800-63-4 §3 (subscriber accounts), SCIM 2.0 RFC 7643/7644 (user resource schema), ISO/IEC 24760-2:2025 §6.2 (identity account lifecycle), ISO 27001 A.5.15-16 (access rights, privileged access), OWASP ASVS v5.0 §2.1 (password security)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-320 | `bauth.idn_user` | Cuenta de usuario (subscriber account) — identificador de login, estado del ciclo de vida (ACTIVE/LOCKED/SUSPENDED/DEACTIVATED), nivel IAL alcanzado, perfil SCIM 2.0, FK a `idn_identity_entity` (actor D00). Un actor D00 puede tener 0, 1 o N cuentas. Separado de la identidad D00 (evidencia del mundo real) y del authenticator (secreto de prueba). `username` UNIQUE por tenant. |
| T-321 | `bauth.idn_user_history` | Historial WORM de cambios de cuenta — registra cada cambio de estado, nombre de usuario, IAL, email o teléfono de recuperación con hash-chain SHA-256. REVOKE UPDATE/DELETE. Particionada por mes. Cumplimiento: ISO 27001 A.8.15, NIST SP 800-63-4 §3 (audit trail de cuenta). |
| T-322 | `bauth.idn_user_recovery` | Datos de recuperación de cuenta — email/teléfono de recuperación (cifrados AES-256-GCM en Vault), códigos de recuperación (hash SHA-256 en BD), estado de uso, fecha de último uso y fecha de expiración. Un usuario puede tener N métodos de recuperación activos. NIST SP 800-63B-4 §5.4 (memorized secret recovery). |

---

## AUTENTICACIÓN

> El **Motor de Métodos** (`MethodRegistry`, patrón PAM — A.44 §1) es el punto ÚNICO de validación: ningún componente del daemon valida un método fuera de él. El universo de autenticación 2026 comprende **47 métodos** en 6 categorías (A=conocimiento, B=posesión, C=inherencia, D=federación, E=flujos especiales, F=identidad descentralizada — 2.02 §2). Implementados hoy: 9 (19%); meta mínima: 24 (parity Keycloak); meta completa: 38 (parity Okta/Ping).
>
> Esta sección de la DDL almacena el **estado persistente** de cada authenticator por cuenta: hashes Argon2id, seeds TOTP/HOTP cifrados (AES-256-GCM), credenciales FIDO2/Passkey (public key DER + AAGUID), certificados X.509 mTLS (fingerprint SHA-256), bindings SAML 2.0, social brokering tokens, Push Ed25519 public keys, recovery codes (SHA-256), intentos fallidos, lockout progresivo y ciclo de vida completo (registro, activación, suspensión, revocación < 30s, revisión trimestral). Incluye el **framework declarativo** (7 tablas: `auth_method`, `auth_policy`, `auth_config`, `crypto_algorithm`, `federation_protocol`, `saga_catalog`, `compliance_map` — 110+ registros que gobiernan el motor sin recompilar el daemon — 2.01 §7).
>
> Esta sección es la fuente de verdad del **PIP** del PDP al evaluar el LoA disponible y los requisitos de step-up (RFC 9470). Los datos son binarios/criptográficos — **bi18n no aplica** aquí.
>
> **Estándares:** NIST SP 800-63B-4 §5 (authenticator lifecycle), FIDO2/WebAuthn W3C Level 3 (passkeys AAL2/AAL3), RFC 9470 (step-up), PCI DSS 4.0 Req 8 (auth controls), ISO 27001 A.9.4, OWASP ASVS v5.0 §2.2–2.5

**Authenticators por cuenta (estado persistente de cada método):**

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-330 | `bauth.auth_credential` | Cabecera de authenticator por cuenta — tipo (PASSWORD/TOTP/HOTP/FIDO2/X509/RECOVERY_CODE/PUSH), estado (ACTIVE/SUSPENDED/REVOKED/EXPIRED), LoA que provee (AAL1/AAL2/AAL3), `phishing_resistant` boolean, fecha de registro y de último uso, FK a `idn_user`. Un usuario puede tener N credentials de distintos tipos. |
| T-331 | `bauth.auth_credential_secret` | Hash de secretos de conocimiento — contraseña Argon2id (m=64MB, t=3, p=4 — NIST 800-63B-4 §5.1.1), seeds TOTP/HOTP cifrados en Vault (AES-256-GCM, vault_path no el valor). `version` para rotación sin invalidar tokens activos. REVOKE UPDATE en `bauth_app_role` — solo append de nueva versión. |
| T-332 | `bauth.auth_credential_fido2` | Credenciales FIDO2/Passkey — public key DER, AAGUID del authenticator, sign_count (replay detection), attestation_object, BackupEligible/BackupState (passkey sync). FK a `bauth.idn_device` (attestation del dispositivo). `transport_hints TEXT[]` (usb/nfc/ble/internal). WebAuthn L3 §6.1. |
| T-333 | `bauth.auth_credential_x509` | Certificados X.509 para mTLS — fingerprint SHA-256, subject DN, issuer DN, PEM (cifrado en Vault), serial, not_before, not_after, estado de revocación (OCSP). FK a T-351 `sig_certificate` cuando es emitido por el motor interno. RFC 8705 (mTLS client auth). |
| T-334 | `bauth.auth_attempt_log` | Log WORM de intentos de autenticación — particionado por mes (RANGE `attempted_at`). Registra: `user_id NULL-able` (intentos de usuarios inexistentes), `method_type`, `outcome` (SUCCESS/FAILURE/LOCKOUT/STEP_UP_REQUIRED), `ip_hash` (GDPR anonimizado), `user_agent_hash`, `failure_reason`. `method_code` sin FK nativa (usuarios inexistentes). REVOKE UPDATE/DELETE. |

**Framework declarativo — MethodRegistry (7 catálogos, 110+ registros):**

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-335 | `bauth.auth_method` | Catálogo de métodos de autenticación — fuente de verdad del MethodRegistry. 47 métodos en 6 categorías (A=conocimiento, B=posesión, C=inherencia, D=federación, E=especial, F=descentralizada). Campos: `method_code PK`, `category`, `aal_provided` (AAL1/AAL2/AAL3), `phishing_resistant`, `hardware_bound`, `standards TEXT[]`, `status` (ACTIVE/DEPRECATED). Seeds: 47 filas. |
| T-336 | `bauth.auth_policy` | Políticas de autenticación por context — MFA_REQUIRED, SESSION_DURATION, MAX_ATTEMPTS, LOCKOUT_DURATION, STEP_UP_METHODS por tier y dominio. Coexiste con T-042 (que define LOA requerido por tier); T-336 define los parámetros operacionales de cada método por contexto. |
| T-337 | `bauth.auth_config` | Configuración de parámetros de cada método — valores de Argon2id (m/t/p), TTL TOTP (30s/60s), tolerancia TOTP (1/2 ventanas), payload máx FIDO2, OCSP TTL. Editable en runtime sin recompilar. FK a `auth_method`. |
| T-338 | `bauth.auth_crypto_algorithm` | Catálogo de algoritmos criptográficos usados — nombre (Ed25519, RSA-SHA256, Argon2id, AES-256-GCM, ECDSA-P256, ML-KEM-768, SLH-DSA-SHA2-128f), tipo (SIGNATURE/KDF/SYMMETRIC/KEM), `is_pqc` boolean, estándar (FIPS 186-5, FIPS 205, NIST 800-186), `deprecated_at`. Motor de decisión de rotación. |
| T-384 | `bauth.auth_federation_protocol` | Catálogo de protocolos de federación soportados — SAML_2_0, OIDC_CORE_1_0, OAUTH2_PKCE, OAUTH2_DEVICE, OAUTH2_TOKEN_EXCHANGE, CIBA, FAPI_2_0, CAEP_RFC9396. Campos: `protocol_code PK`, `spec_url`, `aal_max` (AAL máximo que puede proveer), `fal_supported TEXT[]`, `status`. Seeds: 8 protocolos. |
| T-385 | `bauth.auth_saga_catalog` | Catálogo de sagas de autenticación — flujos orquestados multi-paso del MethodRegistry: PASSWORD_MFA, PASSWORDLESS_FIDO2, SOCIAL_BROKER, SAML_SSO, DEVICE_AUTH, STEP_UP_AAL2→AAL3, BREAKGLASS_EMERGENCY, RECOVERY_FLOW, CIBA_PUSH, TOKEN_EXCHANGE, CLIENT_CREDENTIALS, M2M_MTLS. Campos: `saga_code PK`, `steps JSONB` (secuencia de pasos y condiciones), `timeout_seconds`, `aal_required`, `aal_produced`. 12 sagas. |
| T-386 | `bauth.auth_compliance_map` | Mapa de cobertura normativa del sistema de autenticación — qué controles de qué estándares cubre el motor. Distinto de T-098 `aud_compliance_map` que opera a nivel SISTEMA (D11); este mapea AUTENTICACIÓN: NIST 800-63B §5 (MFA obligatorio), PCI DSS 4.0 Req 8 (lockout, MFA), OWASP ASVS §2.2 (phishing-resistant). `(standard, control_id, method_codes TEXT[])`. 24 filas. |

---

## SESIÓN

> Gestión de sesiones activas y su ciclo de vida completo. Almacena el `ctx_id` de 6 capas (SBOS-049 §3.1), el usuario autenticado, el LoA alcanzado (AAL1/AAL2/AAL3), los métodos de autenticación utilizados, la expiración, el estado de revocación y los tokens de acceso/refresco emitidos. Soporte de SSO multi-aplicación con sincronización de revocación en tiempo real vía CAEP.
>
> El motor **CAEP** (RFC 9396 — Continuous Access Evaluation Protocol) emite eventos de sesión a esta sección cuando el contexto de seguridad cambia: `credential_change`, `token_claims_change`, `session_revoked`, `assurance_level_change`, `ip_change`. El PDP evalúa estos eventos en tiempo real sin esperar la expiración del JWT (sub-segundo). Integra con la sección RIESGO/ITDR para elevar automáticamente el LoA requerido ante señales de amenaza.
>
> **Estándares:** SBOS-049 §3.1 (Context Plane — ctx_id 6 capas), CAEP RFC 9396 (Continuous Access Evaluation Protocol), OpenID Connect Session Management 1.0, OAuth 2.0 Token Introspection RFC 7662, NIST SP 800-207 §3.3 (Zero Trust session management), NIST SP 800-63B-4 §7 (session management and reauthentication)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-181 | `bauth.ses_session_log` | Esqueleto persistente de sesión en PostgreSQL — complementa Redis (store activo) con historial que sobrevive reinicios. Registra: usuario, método auth, `loa_initial`, `loa_peak` (LoA máximo alcanzado en la sesión, incluyendo step-up), IP, user_agent, `started_at`, `terminated_at`, `termination_reason`. Redis no persiste — esta tabla es la fuente de forensia histórica. Candidata a particionamiento por mes. ✅ G-16 |
| T-191 | `bauth.ses_caep_event_log` | Log WORM de eventos CAEP entrantes — registra cada evento recibido de transmitters externos (IdPs federados, MDMs, SIEMs): tipo, subject, transmitter, payload JSONB completo, estado de procesamiento (RECEIVED/PROCESSING/APPLIED/FAILED/IGNORED), `grants_affected[]` (UUIDs de T-170 afectados). Evidencia forense de qué señal disparó cada revocación. Candidata a particionamiento por fecha en deployments con múltiples transmitters. ✅ G-25 |
| T-192 | `bauth.ses_ssf_stream` | Configuración de streams SSF para transmisión de eventos CAEP — reemplaza la config hardcodeada en TOML/ENV con filas editables en runtime. Por stream: receiver_name, endpoint, delivery_method (PUSH/POLL), event_types[], `auth_vault_path` (referencia al token de auth en Vault — nunca el valor). El daemon carga esta tabla al arrancar y recarga vía CAEP sobre Unix socket. ✅ G-26 |
| T-193 | `bauth.ses_ssf_delivery_log` | Log WORM de intentos de entrega por stream SSF — una fila por intento. Registra: stream_id, event_type, delivered_at, delivery_status (SUCCESS/FAILED/RETRYING/ABANDONED), http_status, retry_count, error_message. Índice parcial en filas FAILED/RETRYING para el job de reintento. ✅ G-26 |

---

## PRIVILEGIOS

> Motor BitMask engine — registro permanente de átomos de privilegio, asignaciones rol/usuario, mapeo de recursos para Kong (PEP) y estado operacional de delegaciones y excepciones. Estas tablas son la materialización en BD del modelo NIST RBAC Nivel 3 Constrained bajo el patrón XACML 3.0 PAP/PDP/PEP/PIP.
>
> **Separación conceptual con la sección ROLES:**
> - **T-162** (ROLES) define el árbol de políticas — QUÉ es cada átomo, su jerarquía D01→bloque→política→módulo→evaluación, sus efectos PERMIT/DENY, sus obligaciones. Es la fuente de política.
> - **PRIVILEGIOS** custodia la posición de bit permanente de cada átomo, las asignaciones rol/usuario, el mapeo recurso→átomo para el PEP (Kong) y el estado operacional en runtime.
>
> **Decisiones de diseño — ver A.65.02.01 para el análisis completo.**
>
> **Fábrica de átomos (flujo vigente — A.65.02.01 v1.2):** `T-162 (política + atom_position vía SEQUENCE roles_atom_position_sequential) → FK compuesta en T-170 → RolBitMask → JWT → Kong verifica bit`
>
> **Corrección arquitectónica (A.65.02.01 v1.2):** `atom_position` vive en T-162 (columna en nodos `tipo='evaluacion'`), no en T-170. T-170 la lee vía FK compuesta — nunca la genera. T-170b (`privilege_atom_audit`) es la tabla WORM separada de T-170 para cumplir ISO 27001 A.8.15.
>
> **SoD (G-03):** conflictividad entre verbos declarada en T-174/T-175. Trigger en T-170 verifica SoD en cada INSERT. Ambas tablas son **solo validación** — no participan en el BitMask ni en autenticación.
>
> **Estándares:** ANSI INCITS 359-2004 §4 (RBAC N3 Constrained), XACML 3.0 OASIS (PAP/PDP/PEP/PIP), NIST SP 800-53 Rev.5 AC-2/AC-3/AC-6 (account management, enforcement, least privilege), NIST SP 800-207 §2.1 (Zero Trust — todo recurso requiere decisión explícita), ISO/IEC 24760-2:2025 §7 (authorization model), OpenID AuthZEN 1.0 (API estándar PEP↔PDP — gap P2), RFC 9068 (JWT Profile OAuth 2.0)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-170 | `bauth.privilege_atom_grant` | Grants **per-user**: una fila por usuario por átomo — no existen filas de rol. SET/UNSET de AtomLang materializa N filas individuales (una por usuario); UNSET cambia solo la fila del usuario excluido sin tocar las demás. Lee `atom_position` de T-162 vía FK compuesta — nunca la genera. Incluye `tenant_id` (aislamiento multi-tenant), `valid_from`/`valid_until` (acceso JIT, NIST AC-2(6)). **`grant_type text DEFAULT 'STANDARD' CHECK ('STANDARD'\|'JIT'\|'BREAKGLASS')`** (G-20 D1): clasificador semántico del grant — `STANDARD` es el caso ordinario; `JIT` para grants temporales del flujo JIT (T-182/T-182b); `BREAKGLASS` para grants de emergencia (solo tier SU/EMERGENCY, requiere AAL3 + aprobación dual, máx. 2 por tenant). Distinto de `reassess`: `grant_type` clasifica el origen; `reassess` gobierna la inmunidad CAEP. Trigger `trg_validate_breakglass_grant` impone reglas D1/D2/D3. Índice parcial `idx_pag_grant_type_breakglass`. Cuatro índices IGA (G-09): `idx_pag_atom_access` (átomo→usuarios), `idx_pag_user_entitlement` (usuario→átomos, offboarding), `idx_pag_tenant_sweep` (tenant→certificación), `idx_pag_valid_until` (expiración NIST AC-2(6)). REPLICA IDENTITY FULL para daemon WAL `bauth-reactor`. |
| T-170b | `bauth.privilege_atom_audit` | Tabla WORM append-only: hash-chain SHA-256 de cada INSERT/UPDATE en T-170. Separada de T-170 para garantizar inmutabilidad real (ISO 27001 A.8.15). REVOKE UPDATE/DELETE en `bauth_app_role`. Trigger `fn_worm_append` con `pg_advisory_xact_lock`. |
| T-171 | `bauth.privilege_resource_atom` | Mapeo PAP per-tenant (G-06): `(tenant_id + tipo_protocolo + recurso + operación)` → `id_atom`. Columna `obligation JSONB NULL` (G-04): si NOT NULL, Kong verifica `required_loa` contra sesión activa antes de PERMIT. UNIQUE `(tenant_id, tipo_protocolo, recurso, operacion)`. Cargado en memoria al arrancar; recargado vía CAEP sobre Unix socket. |
| T-172 | `bauth.privilege_delegation` | **Solo auditoría y trazabilidad** (G-08): registro de asignaciones de rol auxiliar temporal. La delegación real es asignación de rol por admin → T-170 + merge_roles Rust. T-172 responde "¿quién autorizó esta asignación y por qué?". Campos: `role_id`, `assignee_id`, `assigned_by`, `reason`, `valid_from`/`valid_until`. Sin `depth_limit` ni `chain_root`. Pendiente: widget de delegación en bAuth Desktop. DDL en A.65.02.01 §6.5. |
| T-173 | `bauth.privilege_override` | Excepciones DENY→PERMIT / PERMIT→DENY per-tenant (G-06). `tenant_id NOT NULL`, `approver_id` + `reason` obligatorios, `audit_event_id` forense, `valid_until` obligatorio. Partial unique: un override activo por (tenant, átomo, usuario, tipo). DDL en A.65.02.01 §6.6. |
| T-174 | `bauth.privilege_verb` | Catálogo de verbos válidos del sistema. **Solo validación** — FK referenciada por `idn_roles_template.verb_id`. No participa en BitMask ni autenticación. Verbo debe existir aquí antes de usarse en cualquier átomo del árbol. |
| T-175 | `bauth.privilege_verb_conflict` | Matriz de conflictividad entre pares de verbos (SOD_ESTATICO / SOD_DINAMICO / AFINIDAD). **Solo validación** — consultada por trigger SoD en T-170 y compilador AtomLang. FK nativas a T-174. Cada par almacenado una sola vez (`verb_a < verb_b`). |
| T-176 | `bauth.privilege_assurance_audit` | Auditoría de evaluación de obligaciones de LoA (decisión G-04 · SBOS-0XX-G04-LOA-AAL-OBLIGACIONES.md). Poblada exclusivamente por Kong (PEP) — no por bAuth. Registra por request: `grant_id`, `resource_id`, `required_loa`, `presented_loa`, `outcome` (PERMIT/STEP_UP_REQUIRED/DENIED), `session_id`. Separada de T-170b: T-170b audita *qué se otorgó*; T-176 audita *cómo se ejerció*. Volumen por request → candidata a particionamiento por fecha y retención propia. |
| T-179 | `bauth.privilege_exception_record` | Gobernanza de excepciones a políticas — documenta el CONTEXTO de aprobación detrás de un override en T-173: política violada, tipo (SOD/TIER/SCOPE), justificación de negocio (≥ 50 chars), aprobador, `valid_until` y `review_at` obligatorios. El trigger SoD en T-170 consulta esta tabla antes de rechazar un INSERT — si existe excepción activa para el par (usuario, átomo), permite el grant. Job diario expira y revoca excepciones vencidas. ✅ G-14 |

---

## AUDITORÍA

> Log de eventos de seguridad append-only WORM con hash-chain, particionado por mes. Centraliza toda la trazabilidad del sistema: autenticaciones exitosas/fallidas, autorizaciones evaluadas (PERMIT/DENY), cambios de privilegios y roles, operaciones sobre identidades, revisiones periódicas de acceso IGA (access certification campaigns), resultados de recertificación de roles, exportación a SIEM (Wazuh syslog UDP) y evidencia de cumplimiento normativo.
>
> El log es la fuente primaria para la **forensia** (quién hizo qué, cuándo y desde dónde) y para las **auditorías ISO 27001 / PCI DSS**. Cada evento tiene: `subject_id`, `action`, `resource`, `outcome`, `ctx_id`, `timestamp`, `ip`, `device_id`, y el hash de la entrada anterior (hash-chain WORM). La retención mínima se rige por `idn_roles_ver_b01_retention_policy` (Ley 843 Bolivia: 10 años, PCI DSS: 12 meses mínimo).
>
> **Estándares:** ISO 27001:2022 A.8.15 (information system audit logging), PCI DSS 4.0 Req 10 (log management and review), NIST SP 800-53 Rev. 5 AU-2/AU-3/AU-12 (event logging, content, monitoring), SOX Section 404 (internal controls evidence), GDPR Art. 30 (records of processing activities), NIST SP 800-53 AC-6(9) (privileged function use logging)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-177 | `bauth.aud_certification_campaign` | Cabecera de campaña de certificación de accesos IGA — define alcance (TENANT/USER/ROLE/ATOM), tipo (QUARTERLY/ANNUAL/OFFBOARDING/INCIDENT/SOD_REVIEW), ventana (started_at → due_date) y responsable. WORM: INSERT only; cierre → `status='COMPLETED'`. Job cron la crea trimestralmente para todos los tenants. Fuente que dispara revisiones en T-178. ✅ G-13 |
| T-178 | `bauth.aud_certification_review` | Evidencia auditable de revisión IGA — una fila por (campaña, grant) con la decisión del revisor (CERTIFY/REVOKE/ESCALATE/DEFER). `decision='REVOKE'` escribe `revocation_at` y dispara UPDATE en T-170 `status='REVOKED'`. Esta tabla es la que presenta el auditor ISO 27001 como prueba de revisión periódica de accesos (A.8.2). ✅ G-13 |

---

## FIRMA DIGITAL

> Ciclo de vida de certificados y llaves criptográficas del **doble motor de firma** (`SBOS-BAUTH-DIGITAL-SIGNATURE-ENGINES.md` v1.0). Este es el plano de control **D13 — Firma Digital Externa** del DomainRegistry (36 átomos diseñados: 5929–5964, módulos `chain`/`did`/`legalsg`, `min_trust=Critical`, `blockchain_anchored=1` — 1.01 §6). Gestiona dos motores independientes y complementarios:
>
> — **Motor interno (Vault Ed25519 — `domain/signature.rs`):** pares de llaves EdDSA, certificados PKI internos emitidos por Vault, firma de JWTs (`sign_jwt_internal`), estado de revocación (OCSP), rotación de llaves programada.  
> — **Motor externo (ADSIB RSA-SHA256 — D13):** certificados emitidos por ADSIB/SIN Bolivia con validez jurídica (Ley 164), log de operaciones de firma forense (`sign_document_adsib`), timestamps calificados, OCSP stapling, cadena de custodia de documentos firmados.
>
> Los documentos firmados con D13 pueden además anclarse en **D12 Blockchain** (Forma A) para verificabilidad externa — los átomos D13 llevan `blockchain_anchored=1` precisamente por esto. Los dos dominios se complementan: D13 prueba la voluntad jurídica, D12 prueba que el registro no fue alterado (1.01 §9).
>
> Almacena también el registro de documentos firmados por su hash SHA-256, los CRL activos, y el historial de revocación certificada.
>
> **Estándares:** Ley 164 Bolivia (firma digital con validez jurídica), eIDAS 2.0 Reg. 910/2014 (qualified electronic signatures), ADSIB-FD-POLT-015 v2.3 (certificación digital Bolivia), SIN RND 102100000011 (facturación electrónica Bolivia), RFC 5280 (X.509 PKI certificates), RFC 8037 (EdDSA/Ed25519), ISO/IEC 9796-2 (digital signature schemes), PCI DSS 4.0 Req 4 (transmission security)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-350 | `bauth.sig_key` | Par de llaves criptográficas — Ed25519 interno (Vault) o RSA-2048/4096 externo (ADSIB). Campos: `key_id UUID PK`, `tenant_id`, `key_type` (INTERNAL_ED25519/EXTERNAL_RSA), `vault_path` (ruta en Vault — nunca el valor), `key_status` (ACTIVE/ROTATED/REVOKED/EXPIRED), `created_at`, `expires_at`, `next_rotation_at`. Job de rotación lee `next_rotation_at`. |
| T-351 | `bauth.sig_certificate` | Certificados X.509 asociados a una llave — emitidos por Vault PKI (interno) o ADSIB (externo). Campos: `cert_id`, `key_id FK T-350`, `subject_dn`, `issuer_dn`, `serial_number`, `not_before`, `not_after`, `fingerprint_sha256`, `cert_pem` (cifrado en Vault — solo referencia), `ocsp_url`, `status` (ACTIVE/REVOKED/EXPIRED). FK desde T-333 y T-383. |
| T-352 | `bauth.sig_crl` | Registro de CRL — Certificate Revocation Lists publicadas por el motor PKI interno. Campos: `crl_id`, `key_id FK T-350`, `issued_at`, `next_update`, `crl_data` (binario DER). Consulta de vigencia por `next_update`. |
| T-353 | `bauth.sig_operation_log` | Log WORM de operaciones de firma — una fila por operación ejecutada (`sign_jwt_internal` / `sign_document_adsib` / `verify_external`). REVOKE UPDATE/DELETE. Campos: `operation_id`, `tenant_id`, `key_id`, `cert_id`, `document_hash` (SHA-256 del payload), `operation_type`, `outcome`, `ctx_id`, `executed_at`. FK a T-354 y T-355. |
| T-354 | `bauth.sig_document_hash` | Registro WORM de hashes de documentos firmados — un documento por hash SHA-256. Permite verificar integridad sin almacenar el documento. Campos: `hash_id`, `document_hash SHA-256 UNIQUE`, `hash_algorithm`, `document_type` (JWT/PDF/XML/FACTURA/VC), `first_seen_at`. Candidato a anclaje D12 Forma A. |
| T-355 | `bauth.sig_timestamp` | Timestamps calificados (RFC 3161) emitidos sobre operaciones de firma — vincula `operation_id` con un timestamp externo de TSA. Campos: `timestamp_id`, `operation_id FK T-353`, `tsa_url`, `token_base64`, `issued_at`, `serial_number`. Requerido por eIDAS 2.0 para firma calificada. |
| T-356 | `bauth.sig_adsib_lifecycle` | Log WORM del ciclo de vida del certificado ADSIB — transiciones de estado (REQUESTED/ISSUED/ACTIVE/SUSPENDED/REVOKED/EXPIRED) con evidencia documental. REVOKE UPDATE/DELETE. Cumplimiento: ADSIB-FD-POLT-015 v2.3, Ley 164 Bolivia Art. 14. |
| T-357 | `bauth.sig_document_policy` | Política de motores de firma por tenant o global — qué motor usar para qué tipo de documento: JWT→internal_ed25519, FACTURA_SIN→adsib_rsa, VC→internal_ed25519+blockchain_anchor. `policy_scope` (GLOBAL/TENANT), `document_type`, `engine` (INTERNAL/EXTERNAL/BOTH), `require_timestamp`, `require_blockchain_anchor`. |

---

## FEDERACIÓN / OIDC

> Registro de relying parties y proveedores de identidad externos del **OIDC Provider propio de bAuth** (ADR-010 — el único emisor de tokens del ecosistema). Gestiona el catálogo de clientes OAuth2/OIDC (scopes, redirect URIs, configuración PKCE, DPoP binding, FAPI 2.0 security profile), proveedores federados externos (SAML 2.0 IdP enterprise, social brokering: Google/GitHub/LinkedIn), tokens de acceso emitidos con su estado de revocación, refresh tokens con rotación forzada, tokens de intercambio (RFC 8693), y sesiones de Device Authorization Grant (RFC 8628).
>
> Incluye también la configuración del OIDC Discovery endpoint (`.well-known/openid-configuration`) y los JWKs públicos para verificación externa.
>
> **Estándares:** RFC 6749 (OAuth 2.0 Authorization Framework), RFC 7636 (PKCE), RFC 8705 (mTLS client certificate binding), RFC 9449 (DPoP — Demonstrating Proof of Possession), RFC 8693 (OAuth 2.0 Token Exchange), RFC 8628 (Device Authorization Grant), OpenID Connect Core 1.0, FAPI 2.0 Security Profile, SAML 2.0 OASIS, NIST SP 800-63-4 §6 (federation assurance levels FAL1/FAL2/FAL3)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-365 | `bauth.fed_client` | Relying parties registradas — clientes OAuth2/OIDC del OIDC Provider propio de bAuth. Campos: `client_id TEXT PK`, `tenant_id`, `client_name`, `client_secret_vault_path` (confidential clients — ruta Vault), `redirect_uris TEXT[]`, `scopes TEXT[]`, `token_endpoint_auth_method`, `require_pkce`, `require_dpop`, `fapi_profile` (FAPI_1_0/FAPI_2_0/NONE), `fal_level` (1/2/3 FK T-168). |
| T-366 | `bauth.fed_provider_ext` | Proveedores de identidad externos — IdPs SAML 2.0 enterprise y social brokering (Google/GitHub/LinkedIn/Microsoft/Apple). Campos: `provider_id`, `tenant_id`, `provider_type` (SAML2/OIDC/SOCIAL), `issuer_url`, `metadata_url`, `client_id_vault_path`, `signing_cert_fingerprint`, `status`, `attribute_mapping JSONB`. |
| T-367 | `bauth.fed_token_issued` | Tokens de acceso/refresco emitidos — particionado por mes (RANGE `issued_at`). Registra: `jti UUID PK`, `client_id`, `user_id`, `scopes TEXT[]`, `token_type` (ACCESS/REFRESH/ID/EXCHANGE), `expires_at`, `revoked_at`, `revocation_reason`, `dpop_jkt` (thumbprint JWK DPoP-bound), `auth_method_used`. REVOKE UPDATE/DELETE (WORM). Índice parcial en tokens activos. |
| T-368..T-374 | *(en A.65.02.05)* | `fed_device_code`, `fed_jwks_key`, `fed_par_request`, `fed_discovery_cfg`, `fed_logout_session`, `fed_token_exchange_log`, `fed_saml_assertion_log` — 7 tablas detalladas en A.65.02.05 (secciones avanzadas de FEDERACIÓN/OIDC). |

---

## BILLETERA DIGITAL

> **Billetera soberana de identidad digital** — almacén del actor para sus Verifiable Credentials (W3C VCDM 2.0), llaves criptográficas FIDO2/Passkey, certificados X.509 mTLS y DIDs. La billetera pertenece al actor (FK a `idn_identity_entity`) y es portable entre tenants. El **protocolo de emisión** sigue OpenID4VCI (OpenID for Verifiable Credential Issuance), el de **presentación** sigue OID4VP (OpenID for Verifiable Presentations). El actor decide qué comparte y con quién — el sistema registra cada presentación con trazabilidad forense.
>
> **Estándares:** W3C VCDM 2.0 Rec. 2025 (Verifiable Credentials Data Model), OID4VP (OpenID for Verifiable Presentations), OpenID4VCI (OpenID for Verifiable Credential Issuance), SD-JWT VC (selective disclosure), W3C DID Core 1.0, W3C VC Status List 2021 (revocación escalable), GDPR Art. 7.3 (retirada de consentimiento y portabilidad)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-380 | `bauth.wallet` | Billetera soberana del actor — una por actor D00 (`entity_id FK T-156`), portátil entre tenants. Campos: `wallet_id UUID PK`, `entity_id`, `did TEXT UNIQUE` (Decentralized Identifier del actor), `status` (ACTIVE/SUSPENDED/REVOKED), `created_at`. El DID es el identificador externo del actor en redes de confianza descentralizadas. |
| T-381 | `bauth.wallet_item` | Ítems almacenados en la billetera — referencias tipadas a credenciales y llaves del actor: `item_type` (VC/FIDO2/X509/DID/SIG_CERT), FK polimórfica por tipo (`vc_id→T-167`, `fido2_id→T-332`, `x509_id→T-333`, `did_id→T-169`, `cert_id→T-351`), `alias` (nombre amigable), `pinned` (ítem destacado en el dashboard), `added_at`. |
| T-382 | `bauth.wallet_presentation_log` | Log WORM de presentaciones VP — registra cada vez que el actor comparte credenciales. REVOKE UPDATE/DELETE. Campos: `presentation_id UUID PK`, `wallet_id FK T-380`, `verifier_id` (FK a `fed_client` T-365), `vp_type` (OIDC_VP/DIRECT_PRESENTATION), `credentials_shared UUID[]`, `outcome` (ACCEPTED/REJECTED/PARTIAL), `presented_at`. GDPR Art. 7.3: evidencia de qué compartió el actor con quién. |
| T-383 | `bauth.wallet_issuance_log` | Log WORM de emisión de VCs — registra cada VC emitida por bAuth vía OpenID4VCI. REVOKE UPDATE/DELETE. Campos: `issuance_id UUID PK`, `wallet_id FK T-380`, `tenant_id`, `vc_id FK T-167 (idn_identity_vc)`, `issuer_did`, `credential_type`, `protocol` (OPENID4VCI/DIRECT_ISSUE/IMPORTED), `outcome` (ISSUED/REJECTED/PENDING), `issued_at`. |

---

## RIESGO / ITDR

> Motor de riesgo adaptativo e **Identity Threat Detection & Response (ITDR)**. Registra señales de comportamiento por sesión (velocidad geográfica, anomalía de dispositivo, hora inusual, frecuencia de requests), scores de riesgo calculados por el motor PDP, eventos de amenaza de identidad detectados (credential stuffing, AiTM/adversary-in-the-middle, impossible travel, privilege escalation, brute force) y los triggers de step-up RFC 9470 disparados en respuesta.
>
> Integra bidireccional con la sección SESIÓN vía **CAEP** (RFC 9396): ante amenaza confirmada, ITDR emite un evento `session_revoked` que el PDP procesa en tiempo real para invalidar la sesión activa. Cuando el score supera el umbral configurado por tier, el PDP eleva el LoA requerido o bloquea la sesión sin intervención humana (Zero Trust continuous verification).
>
> **Estándares:** NIST SP 800-207 §2.1 (Zero Trust — continuous verification of all requests), MITRE ATT&CK for Enterprise TA0006 (Credential Access techniques), CAEP RFC 9396 (risk signals and continuous evaluation), ISO/IEC 27035:2023 (incident management), NIST SP 800-63B-4 §5.2.2 (phishing-resistant authentication requirements), IDPro IAM Reference Architecture v2 — RCTX (Risk Context domain)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-180 | `bauth.ses_risk_policy` | Reglas de política de riesgo adaptativo por tenant — define QUÉ HACE el PDP al recibir un evento CAEP específico. Cada regla: `trigger_event` (6 tipos CAEP), `condition` JSONB (ej. `{"risk_score": {"gte": 70}}`), `action` (STEP_UP/REVOKE/SUSPEND/NOTIFY/REQUIRE_MFA), `required_loa` (solo si STEP_UP), `priority` (menor = mayor prioridad). El PDP evalúa en orden de prioridad y aplica la primera regla que coincide. Reemplaza reglas hardcodeadas en el daemon — editable en runtime sin recompilar. Seeds por defecto en bootstrap del tenant según tier. ✅ G-15 |

---

## PAM

> Gestión de Acceso Privilegiado (Privileged Access Management) para los tiers EMERGENCY (T0) y SYS (T1). Cubre el ciclo de vida completo de las cuentas privilegiadas: sesiones elevadas **JIT (Just-In-Time)** con ventana temporal limitada, vaulting de credenciales privilegiadas y secretos de servicio M2M (llaves API, certificados de servicio, tokens de larga duración), grabación de sesiones administrativas (session recording con hash de integridad), y workflows de aprobación **N-de-M quórum** obligatorio para activar cuentas de emergencia (break-glass).
>
> El **quórum N-de-M** (bloque B3 del árbol de políticas T-162) se aplica a: activación de cuentas EMERGENCY, elevación SU temporal, y acceso a recursos de nivel crítico. Ninguna sesión privilegiada puede iniciarse sin aprobación registrada en esta sección.
>
> **Estándares:** NIST SP 800-53 Rev. 5 AC-6(9) (auditing of privileged function use), NIST SP 800-53 AC-17 (remote access controls), NIST SP 800-207 §3.3 (ZTA privileged access), ISO 27001 A.5.18 (access rights management), IEC 62443-2-1 (industrial PAM), CIS Control 5 (account management), NIST SP 800-53 AC-2(4) (automated audit actions for privileged accounts)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-182 | `bauth.pam_jit_request` | Solicitud de acceso temporal privilegiado (Zero Standing Privilege) — cabecera del workflow JIT. Estados: PENDING → APPROVED → ACTIVE → EXPIRED/REVOKED. `justification` ≥ 50 chars obligatorio; `requested_duration` ≤ `max_duration` del tier. `niveles_requeridos` define cuántos niveles de aprobación secuencial exige el tier del acceso solicitado. Al completarse todos los niveles en T-182b → daemon crea grant en T-170 con `valid_from`/`valid_until`. Job de expiración revisa cada minuto filas `status='ACTIVE'` con `valid_until < now()`. WORM: INSERT only. ✅ G-17 |
| T-182b | `bauth.pam_jit_approval` | **Aprobación secuencial multi-nivel** de solicitudes JIT — una fila por nivel de aprobación requerido. Nivel 1 es notificado primero; el Nivel 2 solo es notificado cuando Nivel 1 aprueba. `required_role` define qué rol puede decidir en ese nivel. Si cualquier nivel rechaza → la solicitud queda REJECTED y los niveles superiores nunca son notificados. Índice parcial en filas sin decisión para el job notificador. Permite 1, 2 o N aprobadores sin cambiar el DDL — solo se agrega una fila de nivel. ✅ G-17 |
| T-183 | `bauth.pam_credential_ref` | Referencias a credenciales privilegiadas en Vault — inventario de metadatos de rotación. NUNCA almacena el valor de la credencial; solo la ruta en Vault (`vault_path`). Cubre humanos Y NHI (`owner_type=NHI` conecta con T-186 `idn_roles_nhi_identity`). Job de rotación lee el índice `idx_pcref_rotation` y ejecuta rotación en Vault cuando `next_rotation_at <= now()`. ✅ G-18 |
| T-184 | `bauth.pam_session_record` | Metadatos de sesión de acceso privilegiado — registra CÓMO se ejerció el privilegio: recurso, tipo de acceso (SSH/RDP/API/CONSOLE/DB/CLI/VAULT), credencial usada, duración (GENERATED ALWAYS), comandos ejecutados, referencia a grabación en MinIO. `jit_request_id` vincula con el JIT que habilitó la sesión. Solo escritura del daemon — el frontend es solo lectura. ✅ G-19 |
| T-185 | `bauth.pam_breakglass_activation` | Ciclo de vida completo de activaciones break-glass (grants `grant_type='BREAKGLASS'` en T-170, G-20 D1). Ciclo: `PENDING_APPROVAL → ACTIVE → DEACTIVATED → REVIEWED`. Dual control obligatorio: `approver_id`/`approved_at` — el estado `ACTIVE` solo se alcanza cuando un segundo SU distinto al activador aprueba (`chk_pbga_dual_control`). `auth_method text CHECK('MTLS_X509'\|'WEBAUTHN_ROAMING'\|'WEBAUTHN_PLATFORM')` registra el método AAL3 usado — el PDP verifica que el método sea declarado en el RolTemplate B4 de la cuenta EMERGENCY. `auth_loa IN (2,3)`: normalmente 3; solo 2 cuando se usa el alternativo degradado `WEBAUTHN_PLATFORM` (compensado con dual control). `post_review_due_at = activated_at + 24h` (NIST AC-2(4)) — índice `idx_pbga_review_pending` alimenta el job de alertas al CISO. TTL de activación: 4h (job `breakglass_expiry.rs` auto-desactiva). Máx. 2 grants BREAKGLASS activos por tenant (D3 — trigger en T-170). 5 métodos JSON-RPC: `solicitar`, `aprobar`, `listar`, `desactivar`, `revisar`. ✅ G-20 |
| T-189 | `bauth.pam_nhi_secret_ref` | Referencias a secretos de NHI en Vault — igual que T-183 pero para secretos de alta frecuencia de rotación (7-30 días vs 90 días). `rotation_policy='ON_USE'` rota en cada uso (patrón para pipelines CI/CD). NUNCA almacena el valor del secreto. Al descomisionar un NHI → todos sus secretos pasan a `status='REVOKED'`. ✅ G-23 |

---

## DISPOSITIVOS

> Registro de dispositivos confiables y su postura de compliance (Zero Trust device verification). Almacena: attestation FIDO2 de dispositivos (`aaguid`, `attestation_certificate`, `trust_model` — Basic/AttCA/ECDAA), certificados X.509 de dispositivo emitidos por Vault, postura MDM (compliant/non-compliant/unknown), vínculos usuario↔dispositivo con historial de revocación, y políticas de acceso condicional por postura de dispositivo (compliant-required, managed-required, domain-joined).
>
> El PEP del Context Plane verifica la postura del dispositivo antes de autorizar el JWT en cada request (NIST SP 800-207 device-based signal). Las credenciales FIDO2/Passkeys de la sección AUTENTICACIÓN referencian los dispositivos registrados aquí para validar la attestation antes de activar el authenticator. Soporte de **OSDP v2.2** para control de acceso físico (lectores de tarjeta, torniquetes).
>
> **Estándares:** FIDO2/WebAuthn W3C Level 2 (device attestation model), NIST SP 800-207 §3.2 (device compliance as ZTA signal), NIST SP 800-63B-4 §5.1 (FIDO2 passkeys at AAL2/AAL3), IEEE 802.1X (port-based network access control), OSDP v2.2 (physical access control), ISO/IEC 27001 A.6.2 (mobile device policy), ISO/IEC 24760-2:2025 §6.3 (device identity)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-390 | `bauth.auth_device` | Registro central de dispositivos — cubre dispositivos lógicos ZTA (NIST SP 800-207 §4.2), llaves FIDO2/hardware (por AAGUID), y lectores físicos OSDP v2.2 (SIA). Campos clave: `category` (DESKTOP/MOBILE/SERVER/IOT/SECURITY_KEY/OSDP_READER), `platform`, `trust_level` (TRUSTED/CONDITIONALLY_TRUSTED/UNTRUSTED/QUARANTINE), `is_managed` + `mdm_device_id`, `is_osdp` + `osdp_address` + `osdp_version` (v1.0/v2.1/v2.2), `aaguid` para matching FIDO2. Un dispositivo puede existir sin usuario (M2M/IoT/lector físico). |
| T-391 | `bauth.auth_device_posture` | Snapshot de postura MDM/ZTA — evaluación periódica del estado de compliance de dispositivos lógicos. Campos: `disk_encrypted`, `screen_lock_enabled`, `antivirus_active`, `os_patches_current`, `is_jailbroken`, `mdm_enrolled` + `mdm_provider`, `mdm_compliance`, `risk_score` (0-100), `compliance_status` (COMPLIANT/NON_COMPLIANT/UNKNOWN/EXEMPTED), `posture_source` (MDM/EDR/AGENT/SELF_REPORTED/MANUAL), `valid_until` (4h TTL — el PDP rechaza si expiró, NIST SP 800-207 §3.3.1). `risk_score` alimenta el PIP de riesgo del motor de políticas. |
| T-392 | `bauth.auth_device_credential_binding` | WORM. Binding dispositivo ↔ credencial — relación M:N entre T-390 y T-330. Tipos: FIDO2_RESIDENT (passkey almacenada), FIDO2_CROSS_PLATFORM (llave física YubiKey/etc.), X509_MTLS, SOFT_TOTP, PUSH_NOTIFICATION, OSDP_CARD. Permite revocar todas las credenciales de un dispositivo perdido/decomisionado con un solo UPDATE en T-390 `status=REVOKED`. El daemon propaga la revocación a T-330 en cascada. |

---

## BLOCKCHAIN D12

> El plano de control **D12** del DomainRegistry — capa de confianza verificable de bAuth. Código implementado: `src/domain/blockchain.rs` (evaluador D12 en el pipeline External-Path) y `src/domain/merkle.rs` (motor Merkle Keccak-256/RFC 6962, 8/8 tests verificados). Opera en **dos formas complementarias** (5.02 MANUAL-BLOCKCHAIN-D12):
>
> — **Forma A — Ancla de auditoría (refuerzo de D11):** eventos críticos de auditoría se agrupan en lotes → árbol Merkle (Keccak-256, hasta 1M hojas, domain separation RFC 6962) → raíz anclada on-chain en Arbitrum (pública, verificable externamente sin confiar en bAuth). El binario `bos-verify` (MUSL 1.2MB, cero dependencias runtime) verifica inclusión offline. Patrón: Certificate Transparency RFC 6962 aplicado a identidad.  
> — **Forma B — Motor de liquidación (refuerzo de D3):** liquidación de valor entre entidades sobre Besu QBFT privado (4 validadores, finalidad inmediata ~1000 TPS). Contrato `SettlementEngine.sol` **probado** en VPS real (6 operaciones en bloques #38-42: freeze/settle/revert/anti-replay verificados, B29 2026-06-22).
>
> Las **5 tablas `blk_*`** están diseñadas en el DDL legacy (`sbos_00:3733`), verificadas en VPS (Capa 2) y operativas: `blk_anchor`, `blk_merkle_batch`, `blk_merkle_leaf`, `blk_account`, `blk_reconciliation`. La integración con D11 se materializa en columnas Merkle dentro de la propia fila de `privilege_atom_audit` (`merkle_batch_id`, `merkle_proof[]`, `onchain_tx_hash`) — el anclaje no es una tabla aparte, es un atributo del evento. Las tablas se incorporan a esta nueva DDL con revisión de naming canónico.
>
> **Nota:** D12 (anclaje/liquidación) y D13 (firma legal ADSIB) se complementan — un documento D13 puede anclarse en D12 Forma A para verificabilidad temporal; D12 no reemplaza la firma (eso es D13) ni el BitMask (eso es D1, variante C descartada por latencia). bi18n no aplica — los hashes y direcciones blockchain son binarios.
>
> **Estándares:** RFC 6962 (Certificate Transparency — Merkle inclusion proof), FIPS 202 (Keccak-256/SHA-3), NIST IR 8202 (blockchain best practices), QBFT/IBFT 2.0 (Byzantine fault-tolerant consensus ≥2/3 super-mayoría), ISO 27001:2022 A.8.15 (integridad de auditoría), W3C DID Core 1.0 (identidad descentralizada — P3), EIP-712 (structured data signing), Regulación boliviana blockchain (declaración previa requerida para Forma B — gap P2)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-358 | `bauth.blk_anchor` | Ancla on-chain Merkle — registra la raíz Merkle (Keccak-256) del lote de eventos auditados y el hash de transacción on-chain (Arbitrum L2 / Besu QBFT). Campos: `anchor_id UUID PK`, `merkle_root BYTEA`, `batch_id FK T-359`, `chain` (ARBITRUM/BESU_QBFT), `tx_hash TEXT`, `block_number BIGINT`, `anchored_at`. Inmutable post-INSERT. |
| T-359 | `bauth.blk_merkle_batch` | Lote de eventos a anclar — agrupación de hasta 1M hojas (eventos de `privilege_atom_audit`) en un árbol Merkle. Campos: `batch_id UUID PK`, `tenant_id`, `leaf_count INTEGER`, `merkle_root BYTEA`, `status` (BUILDING/SEALED/ANCHORED), `sealed_at`, `anchor_id FK T-358 NULL`. Motor `domain/merkle.rs` construye el árbol y sella el lote. |
| T-360 | `bauth.blk_merkle_leaf` | Hojas del árbol Merkle — referencias a eventos de `privilege_atom_audit` incluidos en un lote. Las columnas `merkle_batch_id`, `merkle_proof[]` y `onchain_tx_hash` viven en la propia fila de `privilege_atom_audit` (T-170b) — esta tabla solo materializa el índice leaf→batch para el binario `bos-verify`. |
| T-361 | `bauth.blk_account` | Cuenta blockchain del tenant en Besu QBFT — dirección Ethereum, saldo de gas, estado (ACTIVE/FROZEN/DECOMMISSIONED). Un tenant puede tener N cuentas por red. Campos: `account_id UUID PK`, `tenant_id`, `chain` (BESU_QBFT), `address TEXT UNIQUE`, `status`, `created_at`. |
| T-362 | `bauth.blk_reconciliation` | Reconciliación periódica del saldo on-chain — diferencia entre saldo declarado (`blk_account.balance`) y saldo en cadena consultado vía RPC. `SettlementEngine.sol` Besu QBFT (6 operaciones verificadas en VPS 2026-06-22: freeze/settle/revert/anti-replay). |

---

## CONTEXT PLANE (bos)

> Schema `bos` — Policy Administrator NIST SP 800-207 §3.2. Sesión de INFRAESTRUCTURA. Complementa —no duplica— las tablas de sesión de IDENTIDAD en `bauth` (S9). Redis DB1 como store activo O(1); PostgreSQL como fuente de verdad persistente. Archivo: `bos_01__control_plane.sql`.

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-395 | `bos.ctx_registered_device` | Dispositivos pre-auth — BitMask=0, TTL 8h, heartbeat 30s. Capa INFRAESTRUCTURA (≠ `auth_device` T-390, capa IDENTIDAD). |
| T-396 | `bos.ctx_context_session` | Sesiones post-auth — ctx_id 6 capas (SBOS-049 §3.1) con BitMask>0. TTL 12h. Redis DB1 O(1) para Kong PEP. |
| T-397 | `bos.ctx_context_audit` | Auditoría WORM hash-chain SHA-256 de toda operación del Context Plane. 16 tipos de operación. REVOKE UPDATE/DELETE. |
| T-398 | `bos.ctx_context_switch_log` | Historial WORM de cambios de contexto sin reautenticación. Forensia ITDR: detección de switches anómalos. |
| T-399 | `bos.ctx_context_policy` | Políticas TTL/seguridad por tenant. Complementa `idn_tenant` (TTL identidad ≠ TTL infraestructura). |
| T-400 | `bos.ctx_device_heartbeat` | Heartbeats de dispositivos. Alta escritura, 24h retención. Tabla separada para evitar write amplification. |
| T-401 | `bos.ctx_context_transfer` | Transferencia WORM de contexto entre dispositivos. Tipos: USER_INITIATED, AUTO_CONTINUITY, ADMIN_TRANSFER, BREAKGLASS. |
| T-402 | `bos.ctx_context_emergency` | Break-glass de contexto (D08-B04). Control dual NIST AC-17(3). TTL 2h fijo. Revisión post-hoc 24h. WORM. |

---

## BIBLIOTECA DE REFERENCIA (bauth)

> Tabla T-999 — Catálogo unificado de políticas, reglas, configuraciones y métodos. **SOLO LECTURA — sin lógica de negocio.** 16 fuentes normativas. 13 dominios D1-D12+SEC. REVOKE UPDATE/DELETE.

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-999 | `bauth.cfg_policy_library` | Biblioteca jerárquica de referencia. Estructura: section→group→policy→config. 16 fuentes normativas, 13 dominios D1-D12+SEC. 29 columnas de clasificación. REVOKE UPDATE/DELETE. |
| T-999b | `bauth.framework_raw` | Carga de JSON fuente para CTE recursivo. 16 fuentes normativas (NIST, ISO, FIDO2, OAuth, PCI DSS, SOC2, etc.). Una fila por fuente con content JSONB. |
| T-999c | `bauth.cfg_key_translation` | Mapeo ~221 claves JSON inglés→español para traducción automática de `content_es` vía `translate_keys_en_es()`. |
| — | `bauth.jsonb_explode(jsonb)` | Función IMMUTABLE: descompone nodos JSONB (objetos→jsonb_each, arrays→jsonb_array_elements) para CTE recursivo. |
| — | `bauth.translate_keys_en_es(jsonb)` | Función IMMUTABLE: recorre JSONB recursivamente y traduce claves usando `cfg_key_translation`. Usa camelCase y snake_case decomposition. |

## BOS CONTROL PLANE — Motores FCH · INS · CAP · PRT · NET · REL · WDG

> Schema `bos` — 12 tablas para los 7 subsistemas operacionales del daemon BOS. Estas tablas proveen persistencia a los motores que no tenían cobertura en BD: máquina de estados de fichas, registro de bootstrap, observabilidad de capacidad, kardex de puertos, Network Security Manager, release plane y watchdog. Todas forman parte de `bos_01__control_plane.sql` (mismo archivo que el grupo CTX). Total schema `bos`: 20 tablas · 8 WORM · 8 grupos. **Naming 100% inglés** para tablas y columnas; comentarios en español.

### Grupo FCH — Motor ③ Server FICHAS (ADR-021)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-403 | `bos.fch_ficha_state` | Estado actual de cada ficha declarativa — máquina de 18 estados (ADR-021). `(ficha_name, server_id)` UNIQUE. Sin `tenant_id`: las fichas son infraestructura compartida. `hashes` JSONB con SHA-256 de artefactos para drift detection. `backend` CHECK (bash\|k8s\|binary\|python). |
| T-404 | `bos.fch_ficha_event` | Historial WORM de todos los cambios de estado de fichas — append-only, REVOKE UPDATE/DELETE. Hash-chain SHA-256 (`prev_hash`). `tenant_id` = tenant que disparó el evento (auditoría), no dueño. `actor_id + ip_address` → NIST AU-3. `saga_id` agrupa todos los eventos de una misma saga install/update/repair/remove. |

### Grupo INS — Motor ① IAM Installer (ADR-040)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-405 | `bos.ins_bootstrap_event` | WORM del bootstrap progresivo de 6 capas (C-01..C-09). `bootstrap_run_id` agrupa un intento completo. `tenant_id` NUNCA NULL: capas 0-2 usan el tenant raíz; capas 3-5 el tenant del cliente. `layer` CHECK (0..5). `verification_code` CHECK (C-NN). REVOKE UPDATE/DELETE. |
| T-412 | `bos.ins_saga_execution` | Tracking mutable de sagas generales del Installer — install, update, repair, remove, deploy_tenant, remove_tenant, suspend_tenant. `state` CHECK (RUNNING\|COMPLETED\|FAILED\|COMPENSATING\|COMPENSATED). `compensated_steps` JSONB array de pasos que hicieron rollback. |

### Grupo CAP — Motor ② SO Observable / Capacidad (SBOS-BOS-CAP-001)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-406 | `bos.cap_sistema_snapshot` | Instantáneas periódicas (~60s) de 30+ métricas del sistema (Motor ② M5.1). PARTITION BY RANGE (captured_at) — partición mensual `_YYYY_MM`. Purga: DROP TABLE sobre particiones > 90 días (instantáneo). PK compuesta `(snapshot_id, captured_at)`. `scope` CHECK (GLOBAL\|TENANT). No WORM: telemetría operativa. |
| T-407 | `bos.cap_tenant_policy` | Política de capacidad por tenant (Motor ② M5.3). UNIQUE por tenant. Fallback: Motor M5.3 usa la fila del tenant raíz si el tenant no tiene la propia. `policy_mode` CHECK (autonomous\|recommend\|block_and_alert\|emergency). Umbrales CPU/mem/disco/RPS/sesiones + horizonte de proyección. |

### Grupo PRT — Port Manager · A.12 · RFC 6335 BCP 165

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-408 | `bos.prt_port_assignment` | Kardex de puertos — inventario de activos de red (ISO 27001 A.8.20). Inmutabilidad lógica: filas nunca se eliminan, solo transicionan `assigned→released→revoked`. UNIQUE `(port, port_type, namespace)`. `port_type` CHECK (HOST_PHYSICAL\|HOST_LOGICAL\|K8S_NODE_PORT\|K8S_CLUSTER_IP\|K8S_LOAD_BALANCER). `transport` CHECK (TCP\|UDP\|SCTP\|DCCP). |

### Grupo NET — Network Security Manager · A.15 · A.12

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-413 | `bos.net_cert_inventory` | Kardex de certificados TLS — ISO 27001 A.8.24. Un registro por certificado activo: daemons host (Vault PKI), fichas K8s (cert-manager), SVIDs SPIFFE/SPIRE (24h), externos (Let's Encrypt). `days_remaining` GENERATED ALWAYS (sin trigger). UNIQUE `(fingerprint_sha256)`. `cert_type` CHECK (daemon_host\|ficha_k8s\|spiffe_svid\|external_wildcard\|kong_tls\|ca_internal). `issued_at` ≠ `valid_from`. `last_renewed_at` para trazabilidad de renovaciones. Inmutabilidad lógica: active→expiring_soon→expired→revoked. |
| T-414 | `bos.net_security_events` | Log de eventos de seguridad de red — ISO 27001 A.8.21 / NIST SP 800-41. PARTITION BY RANGE(event_time) — partición mensual + default. 27 `event_type` CHECK (port_assigned/released/conflict · cert_issued/renewed/expiring/revoked · fw_rule_added/removed/netpol_synced/fw_drift_detected · ips_block/unblock/port_scan_detected · crowdsec_ban/unban · fail2ban_ban/unban · ddos_detected · brute_force_detected · replay_detected). `src_ip INET` — búsquedas por red nativas. `source` CHECK (portman\|certman\|fwman\|ips\|crowdsec\|fail2ban\|psad\|bos_daemon). Alta escritura: miles de eventos/día. Retención 90 días. |

### Grupo REL — Release Plane (SBOS-RELEASE-001 · Ed25519)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-409 | `bos.rel_release_manifest` | Catálogo de versiones disponibles por daemon y canal (canary\|early\|stable). UNIQUE `(daemon_name, version, channel)`. `artifact_sha256 + signature_ed25519` verificados antes de desplegar. `is_rollback_target` marca versiones validadas para rollback. Pull-only desde SKULL Release Server. |
| T-410 | `bos.rel_release_event` | WORM de operaciones de actualización/rollback. `operation` CHECK (INSTALL\|UPDATE\|ROLLBACK). `triggered_by` CHECK (scheduler\|watchdog\|human). FK a `rel_release_manifest`. Registra versión anterior (`from_version`) y error en caso de falla. REVOKE UPDATE/DELETE. |

### Grupo WDG — Motor ② SO Observable / Watchdog

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-411 | `bos.wdg_watchdog_event` | WORM de verificaciones del watchdog de 3 capas. `check_layer` CHECK (ubuntu_host\|k8s_cluster\|bos_fichas). `severity` CHECK (INFO\|WARN\|ERROR\|CRITICAL). `action_taken` CHECK (auto_repair\|hitl_escalated\|daemon_restart\|rollback\|none). REVOKE UPDATE/DELETE. Watchdog corre cada 30s por capa. |

---

## Resumen de tablas por sección

| Sección | Tablas | Estado | Tipo |
|---------|--------|--------|------|
| GLOBAL | 8 (T-001..T-004 · T-059..T-061 · T-114) | ✅ Definidas | Catálogos de referencia (`bglobal`) |
| TENANT | 8 (T-005..T-013) | ✅ Definidas | Infraestructura multi-tenancy (`bauth`) |
| ROLES | 9 (T-040..T-042 · T-063 · T-B02L · T-161b · T-162..T-163 · T-194) | ✅ Definidas | Identidad de roles + árbol + lifecycle WORM + catálogos (`bauth`) |
| VERSIONADO | 4 (T-152..T-155) | ✅ Definidas | Motor MVU 1.13 (`bauth`) |
| IDENTIDAD | 14 (T-156..T-161 + T-165..T-168 + T-186..T-188 · T-190) | ✅ Definidas ✅ D00 COMPLETO | Motor D00 v2.0 + NHI — actores, atributos, proofing, consentimiento, VC, FAL (`bauth`) |
| CALENDARIO | 9 (T-012 · T-014..T-019 · T-124..T-125) | ✅ Definidas | Infraestructura temporal (`bcalendar`) |
| USUARIOS | 3 (T-320..T-322) | ✅ Definidas | Subscriber accounts SCIM 2.0 + historial WORM + recuperación (`bauth`) |
| AUTENTICACIÓN | 12 (T-330..T-338 · T-384..T-386) | ✅ Definidas ✅ Implementadas | Authenticators (5) + MethodRegistry declarativo (7 catálogos, 34+ seeds) (`bauth`) |
| SESIÓN | 4 (T-181 · T-191..T-193) | ✅ Definidas | Sesiones persistentes + CAEP + SSF (`bauth`) |
| PRIVILEGIOS | 9 (T-170 · T-170b · T-171..T-176 · T-179) | ✅ Definidas | Motor BitMask engine + excepciones (`bauth`) |
| AUDITORÍA | 2 (T-177..T-178) | ✅ Definidas | Campañas IGA + revisiones de certificación (`bauth`) |
| FIRMA DIGITAL (D13) | 8 (T-350..T-357) | ✅ Definidas | PKI: llaves + certificados + CRL + op_log + hashes + timestamps + ciclo ADSIB + política (`bauth`) |
| FEDERACIÓN / OIDC | 3+7 (T-365..T-367 · T-368..T-374 en A.65.02.05) | ✅ Definidas (parcial) | OAuth2/OIDC/SAML + tokens + avanzadas en A.65.02.05 (`bauth`) |
| BILLETERA DIGITAL | 4 (T-380..T-383) | ✅ Definidas | W3C VCDM 2.0 + OID4VP/VCI + presentación WORM + emisión WORM (`bauth`) |
| RIESGO / ITDR | 1 (T-180) | ✅ Definidas | Política de riesgo adaptativo — `ses_risk_policy` (`bauth`) |
| **CONTEXT PLANE** | **8 (T-395..T-402)** | ✅ Definidas | **Policy Administrator NIST 800-207 — ctx_id 6 capas — 4 WORM hash-chain (`bos`)** |
| **BIBLIOTECA REFERENCIA** | **3+2 (T-999, T-999b, T-999c + 2 funciones)** | ✅ Definida | **`cfg_policy_library` + `framework_raw` + `cfg_key_translation` + `jsonb_explode()` + `translate_keys_en_es()` (`bauth`)** |
| **REVOCACIÓN** | **1 (T-364)** | ✅ Definida | **`idn_credencial_revocacion` — D09-B05 · PCI DSS Req 8.2.8 (`bauth`)** |
| **INTROSPECCIÓN** | **1 (T-368)** | ✅ Definida | **`idn_credencial_introspeccion` — D09-B09 · RFC 7662 (`bauth`)** |
| **PAM INVENTARIO** | **1 (T-460)** | ✅ Definida | **`pam_cuenta_privilegiada` — D14-B01 · CIS Controls v8 §5.1 (`bauth`)** |
| **MONITOREO** | **1 (VIEW)** | ✅ Definida | **`mv_audit_dashboard` — D11-B04 · 5 métricas unificadas (`bauth`)** |
| PAM | 6 (T-182 · T-182b · T-183..T-185 · T-189) | ✅ Definidas | JIT + aprobación multi-nivel + credenciales + sesión privilegiada + break-glass + secretos NHI (`bauth`) |
| DISPOSITIVOS | 3 (T-390..T-392) | ✅ Definidas ✅ Implementadas | Registro ZTA + postura MDM + binding FIDO2/OSDP WORM (`bauth`) |
| BLOCKCHAIN D12 | 5 (T-358..T-362) | ✅ Naming canónico | Anclaje Merkle + liquidación Besu (`bauth`) |
| **BOS CONTROL PLANE** | **12 (T-403..T-414)** | ✅ Definidas ✅ Commiteadas | **FCH 18-state + INS bootstrap/sagas + CAP snapshots/policies + PRT port kardex + NET cert/security + REL release + WDG watchdog — schema `bos` — naming 100% inglés** |
| **Total definido** | **130** | — | *18 secciones ✅ · 0 pendientes · D00 COMPLETO v2.6.0 · bos schema 20 tablas · v2.0* |

---

## Próximos pasos

1. **Catálogo completo** — 17 secciones con 118 tablas definidas. 0 secciones pendientes. ✅
   - FEDERACIÓN/OIDC — 7 tablas avanzadas (T-368..T-374) en A.65.02.05

2. **Implementar Fase 1 (GAPS-DDL-PRIVILEGIOS-II.md):** G-21 → G-17 → G-20 → G-13 (orden de dependencia).
   - Dependen de SESIÓN: RIESGO/ITDR · PAM
   - PRIVILEGIOS ✅ cerrado (T-170, T-170b, T-171–T-176 · doctrina en A.65.02.01 v1.5 · extensión AtomLang en A.65.02.02 · G-04 en SBOS-0XX-G04-LOA-AAL-OBLIGACIONES.md · G-06/G-09 en GAPS-DDL-PRIVILEGIOS.md)
   - BLOCKCHAIN D12 ✅ naming canónico resuelto (T-358..T-362)

3. **Diseñar DDL detallado de secciones inventariadas en v1.7** (columnas, constraints, índices):
   - Nuevas en v1.7: USUARIOS (T-320..T-322) · AUTENTICACIÓN (T-330..T-338 · T-384..T-386) · FIRMA DIGITAL (T-350..T-357) · FEDERACIÓN (T-365..T-367) · BILLETERA (T-380..T-383)
   - Referencia DDL bosquejo: A.65.02.04 §2-6 (columnas detalladas y constraints)

4. Cada tabla diseñada → migración `bauth_NN__<tabla>.sql` numerada

5. Seeds: migrar datos de VPS legacy con `INSERT INTO new SELECT FROM old` donde aplique

6. Validar con `verificar_afirmacion.sh` antes de declarar cualquier tabla completa

---

## Catálogo de Seeds (25 archivos)

**Convención:** `<schema>_<T-CODE>__<nombre_tabla>.sql`  
**Idempotencia:** TRUNCATE + INSERT (legacy) o INSERT + ON CONFLICT DO NOTHING (nuevos)  
**Directorio:** `DDLs/seeds/`

### bglobal (4 seeds)

| Archivo | Tabla | Filas | Descripción |
|---------|-------|:-----:|-------------|
| `bglobal_T001__global_language.sql` | `global_language` | ~120 | Idiomas del mundo (BCP 47, ISO 639) |
| `bglobal_T002__global_country.sql` | `global_country` | 196 | Países ISO 3166-1 + datos demográficos |
| `bglobal_T004__geo_timezone.sql` | `geo_timezone` | ~400 | Zonas horarias IANA |
| `bglobal_T060__menu_context.sql` | `menu_context` | ~200 | Contextos de menú y ENUMs del sistema |

### bcalendar (3 seeds)

| Archivo | Tabla | Filas | Descripción |
|---------|-------|:-----:|-------------|
| `bcalendar_T012__cal_calendar.sql` | `cal_calendar` | ~5 | Calendarios base (Bolivia, estándar) |
| `bcalendar_T014__cal_schedule.sql` | `cal_schedule` | ~10 | Horarios y turnos |
| `bcalendar_T015__cal_holiday_complete.sql` | `cal_holiday` | ~50 | Feriados Bolivia + regionales |

### bauth (17 seeds)

| Archivo | Tabla | Filas | Descripción |
|---------|-------|:-----:|-------------|
| `bauth_T005__idn_tenant.sql` | `idn_tenant` | 1 | Tenant skull (Sistemas SKULL) |
| `bauth_T040__idn_roles_rol_type.sql` | `idn_roles_rol_type` | 10 | Tipos de cuenta (INDIVIDUAL, M2M, SYSTEM...) |
| `bauth_T042__idn_roles_rol_tier.sql` | `idn_roles_rol_tier` | 11 | Tiers de seguridad (SU, T0, T1, BIZ_N1..N5...) |
| `bauth_T154__idn_roles_ver_b01_retention_policy.sql` | `idn_roles_ver_b01_retention_policy` | 1 | Política de retención legal |
| `bauth_T156__idn_identity_entity.sql` | `idn_identity_entity` | 1 | Entidad skull (BAUTH_SYSTEM) |
| `bauth_T159__idn_identity_requirement.sql` | `idn_identity_requirement` | 54 | Requisitos de identidad por tipo IAL |
| `bauth_T161b__idn_policy_node_type.sql` | `idn_policy_node_type` | 12 | Tipos de nodo del árbol (tenant, domain, block...) |
| `bauth_T162__idn_roles_template.sql` | `idn_roles_template` | 179 | Árbol de políticas RolTemplate v6.0 |
| `bauth_T168__idn_tenant_fal_config.sql` | `idn_tenant_fal_config` | 1 | Federation Assurance Level config |
| `bauth_T174__privilege_verb.sql` | `privilege_verb` | 64 | Verbos de privilegio atómicos |
| `bauth_T175__privilege_verb_conflict.sql` | `privilege_verb_conflict` | 53 | Matriz de conflictos SoD |
| `bauth_T187__idn_scim_attribute_map.sql` | `idn_scim_attribute_map` | 10 | Mapeo SCIM 2.0 ↔ atributos locales |
| `bauth_T194__idn_roles_iga_category.sql` | `idn_roles_iga_category` | 7 | Categorías IGA (BUSINESS, PRIVILEGED...) |
| `bauth_T384__auth_federation_protocol.sql` | `auth_federation_protocol` | 8 | Protocolos de federación (SAML, OIDC, FAPI...) |
| `bauth_T385__auth_saga_catalog.sql` | `auth_saga_catalog` | 12 | Catálogo de sagas de autenticación |
| `bauth_T386__auth_compliance_map.sql` | `auth_compliance_map` | 14 | Mapa de cumplimiento normativo |
| `bauth_T999__cfg_policy_library.sql` | `cfg_key_translation` | 221 | Traducción inglés→español + seed framework |

---

## NUEVOS DOMINIOS — Implementados en migración v1.0 (2026-07-31)

### D07 — Control de Red / ZTA (T-195..T-201)
> T-codes CORREGIDOS: T-320..T-326 tomados por USUARIOS → reasignados a T-195..T-201

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-195 | `bauth.idn_network_connection_policy` | Política de conexión (TLS min, mTLS, DPoP, PKCE) por tenant |
| T-196 | `bauth.idn_network_dpop_binding` | DPoP binding — sender-constraining RFC 9449 · FAPI 2.0 · WORM |
| T-197 | `bauth.idn_network_rate_policy` | Política de rate limiting por scope (IP, USER, CLIENT, GLOBAL) |
| T-198 | `bauth.idn_network_posture_policy` | Postura de dispositivo ZTA — NIST SP 800-207 §3.3 |
| T-199 | `bauth.idn_network_segment` | Segmentos de red con nivel de confianza — ISO 27001 A.8.22 |
| T-200 | `bauth.idn_network_dlp_policy` | DLP de inspección de payload — NIST SP 800-53 R5 SI-3 |
| T-201 | `bauth.idn_network_context_propagation` | Configuración propagación ctx_id — SBOS-049 · W3C Trace Context v2 |

### D09 — Gaps de Credenciales (T-202, T-363)
| T-562 | `bauth.idn_credencial_introspeccion` | Log de introspección de tokens — registra cada llamada RFC 7662 `/token/introspect`: cliente, hash token evaluado, resultado (ACTIVE/INACTIVE/INVALID), campos devueltos, `ctx_id`, timestamp. Fuente forense del uso inter-servicio de tokens. ✅ IMPLEMENTADA |
> T-202 CORREGIDO: T-360 tomado por sig_document_hash → reasignado a T-202

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-202 | `bauth.idn_credential_password_history` | Historial de contraseñas — NIST SP 800-63B-4 §5.1.1.2 |
| T-363 | `bauth.idn_credential_token_issued` | Registro tokens emitidos — ciclo de vida + DPoP binding · PARTICIONADA |

### D02 — Control de Acceso Físico (T-220..T-228)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-220 | `bauth.idn_physical_access_location` | Catálogo de instalaciones físicas — ISO 27001 A.7.1 |
| T-221 | `bauth.idn_physical_access_reader` | Lectores de acceso físico OSDP v2.2.2 |
| T-222 | `bauth.idn_physical_access_presence` | Estado de presencia actual (anti-passback state) |
| T-223 | `bauth.idn_physical_access_event_log` | Log eventos acceso físico · PARTICIONADA |
| T-224 | `bauth.idn_physical_access_visit` | Registro de visitas — ISO 27001 A.7.2 |
| T-225 | `bauth.idn_physical_access_emergency` | Acceso de emergencia físico — NIST SP 800-116 R2 §5.4 |
| T-226 | `bauth.idn_physical_access_evacuation` | Evacuación y mustering — ISO 27001 A.7.4 |
| T-228 | `bauth.idn_physical_access_credential` | Credenciales físicas vinculadas a identidad digital — FIPS 201-3 |

### D03 — Control Financiero (T-240..T-248)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-240 | `bauth.idn_financial_limit` | Límites transaccionales por rol/actor — PCI DSS 4.0 Req 8.2 |
| T-241 | `bauth.idn_financial_approval` | Solicitud de aprobación dual financiera — COSO 2013 CC6.3 |
| T-242 | `bauth.idn_financial_sod_rule` | Reglas SoD financiero — NIST AC-5 · SOX §404 | ⚠️ DDL pendiente — no implementado en SBOS_db_V2_DDL.sql
| T-243 | `bauth.idn_financial_invoice_authorization` | Autorización de factura electrónica SIN — Ley 164 Bolivia | ⚠️ DDL pendiente — no implementado en SBOS_db_V2_DDL.sql
| T-244 | `bauth.idn_financial_report` | Reportes financieros de control — SOX §302/§404 | ⚠️ DDL pendiente — no implementado en SBOS_db_V2_DDL.sql
| T-245 | `bauth.idn_financial_fraud_alert` | Alertas de fraude financiero — PCI DSS 4.0 Req 10.7 | ⚠️ DDL pendiente — no implementado en SBOS_db_V2_DDL.sql
| T-246 | `bauth.idn_financial_reconciliation` | Conciliación financiera — ISO 20022 §5 | ⚠️ DDL pendiente — no implementado en SBOS_db_V2_DDL.sql
| T-247 | `bauth.idn_financial_tpp_consent` | Consentimiento TPP / Open Banking — FAPI 2.0 · RFC 9449 |
| T-248 | `bauth.idn_financial_approval_vote` | Voto individual de aprobación dual (sub-tabla de T-241) |

### D04 — Control Temporal GTRBAC (T-260..T-265)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-260 | `bauth.idn_temporal_window` | Ventanas de tiempo de acceso — GTRBAC §3.2 |
| T-261 | `bauth.idn_temporal_period` | Períodos temporales — GTRBAC §4 |
| T-262 | `bauth.idn_temporal_calendar` | Asociación de calendarios a ventanas (FK → bcalendar) |
| T-263 | `bauth.idn_temporal_shift` | Turnos de trabajo — NIST AC-2(2) |
| T-264 | `bauth.idn_temporal_shift_assignment` | Asignación de turno a actor |
| T-265 | `bauth.idn_temporal_exception` | Excepciones temporales — NIST AC-17(1) |

### D05 — Control Biométrico (T-280..T-285)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-280 | `bauth.idn_biometric_enrollment` | Enrolamiento biométrico — NIST SP 800-76-2 §4 |
| T-281 | `bauth.idn_biometric_verification_log` | Log de verificaciones biométricas · PARTICIONADA |
| T-282 | `bauth.idn_biometric_pad_policy` | Política PAD (Presentation Attack Detection) — ISO/IEC 30107-3:2023 |
| T-283 | `bauth.idn_biometric_identification_log` | Log identificación 1:N · PARTICIONADA |
| T-284 | `bauth.idn_biometric_quality_policy` | Política de calidad de muestra — ISO/IEC 29794-1:2024 |
| T-285 | `bauth.idn_biometric_revocation` | Revocación de template biométrico — ISO/IEC 24745:2022 | ⚠️ DDL pendiente — no implementado en SBOS_db_V2_DDL.sql

### D06 — Control Geoespacial (T-300..T-305)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-300 | `bauth.idn_geospatial_geofence` | Geocercas — RFC 7946 §3.1 · OGC GeoSPARQL |
| T-301 | `bauth.idn_geospatial_location_log` | Log de ubicaciones · PARTICIONADA · GDPR Art. 5(1)(c) |
| T-302 | `bauth.idn_geospatial_velocity_policy` | Política de velocidad geográfica (viaje imposible) |
| T-303 | `bauth.idn_geospatial_velocity_event` | Eventos de viaje imposible detectados |
| T-304 | `bauth.idn_geospatial_data_residency` | Residencia de datos y soberanía geográfica — GDPR Art. 44-49 |
| T-305 | `bauth.idn_geospatial_device_fleet` | Flota de dispositivos móviles con trazabilidad geoespacial |

### D10 — Delegación de Identidad (T-415..T-420)
> T-codes CORREGIDOS: T-380..T-385 tomados por BILLETERA+AUTH → reasignados a T-415..T-420

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-415 | `bauth.idn_delegation_grant` | Delegación de identidad base — RFC 8693 §3 · NIST AC-2(5) |
| T-416 | `bauth.idn_delegation_renewal` | Renovación de delegación — RFC 8693 §4.2 |
| T-417 | `bauth.idn_delegation_restriction` | Restricciones sobre el scope delegado — NIST AC-5 |
| T-418 | `bauth.idn_delegation_chain` | Cadena de delegación sub-delegated — ANSI INCITS 359-2004 §4.5 |
| T-419 | `bauth.idn_delegation_usage_log` | Log de uso de delegaciones · PARTICIONADA |
| T-420 | `bauth.idn_delegation_rar_request` | Rich Authorization Request — RFC 9396 §3 |

### D11 — Gaps de Auditoría y SIEM (T-421..T-424)
> T-codes CORREGIDOS: T-400..T-403 tomados por CONTEXT PLANE+BOS → reasignados a T-421..T-424

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-421 | `bauth.idn_audit_retention_policy` | Política de retención de logs — SOX §802 · GDPR Art. 5(1)(e) |
| T-422 | `bauth.idn_audit_alert_rule` | Reglas de alerta de auditoría — NIST AU-6 |
| T-423 | `bauth.idn_audit_siem_target` | Destinos SIEM (Wazuh por defecto) — NIST AU-9(2) |
| T-424 | `bauth.idn_audit_event_log` | Evento de auditoría unificado multi-dominio · PARTICIONADA · WORM |

### D12 — Blockchain extra (T-425..T-429)
> T-codes CORREGIDOS: T-420..T-424 solapaban con D10 → reasignados a T-425..T-429

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-425 | `bauth.idn_blockchain_anchor_ext` | Extensión de anclaje blockchain (complementa blk_anchor T-358) |
| T-426 | `bauth.idn_blockchain_transaction` | Registro de transacciones Besu QBFT |
| T-427 | `bauth.idn_blockchain_wallet` | Wallet blockchain por tenant — BIP-32/39/44 · EIP-712 |
| T-428 | `bauth.idn_blockchain_merkle_proof` | Pruebas de inclusión Merkle — RFC 6962 §2.1.1 |
| T-429 | `bauth.idn_blockchain_node` | Nodos del consenso Besu QBFT — EIP-225 |

### D13 — Firma Digital gaps (T-440..T-446)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-440 | `bauth.idn_signature_request` | Solicitud de firma digital — PAdES EN 319 132 · Ley 164 Bolivia |
| T-441 | `bauth.idn_signature_ca_chain` | Cadena de certificación CA — RFC 5280 §6 · ADSIB |
| T-442 | `bauth.idn_signature_timestamp` | Timestamp calificado de firma — RFC 3161 §2 · Ley 164 Bolivia |
| T-443 | `bauth.idn_signature_verification_log` | Log de verificaciones de firma · WORM |
| T-444 | `bauth.idn_signature_revocation_cache` | Cache de estado de revocación OCSP/CRL — RFC 6960 |
| T-445 | `bauth.idn_signature_ltv_evidence` | Evidencia LTV — ETSI EN 319 102-2 §5.6 · WORM |
| T-446 | `bauth.idn_signature_eudi_wallet` | Integración EUDI Wallet — eIDAS 2.0 · ARF 1.4 |

### D14 — PAM gaps (T-461)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-461 | `bauth.pam_session_recording` | Referencia a grabaciones de sesiones privilegiadas — NIST AU-14 |

### D15 — NHI gaps (T-480..T-481)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-480 | `bauth.idn_nhi_rotation_policy` | Política de rotación de secretos NHI — NIST SP 800-57 Pt1 R5 |
| T-481 | `bauth.idn_nhi_svid` | SPIFFE SVID para daemons SBOS — SPIFFE Spec v1.0 §8 |

### D98 — Meta-Registro (T-500..T-502)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-500 | `bauth.idn_registry_attribute_schema` | Schema registry de atributos EAV — SCIM 2.0 RFC 7643 |
| T-501 | `bauth.idn_registry_atom_catalog` | Catálogo de átomos del motor BitMask — NIST SP 800-162 |
| T-502 | `bauth.idn_registry_bitmask_version` | Versiones del árbol BitMask — ISO 9001:2015 §7.5 |

### D99 — Admin Global Soberano (T-510..T-515)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-510 | `bauth.idn_global_admin` | Administradores globales del sistema (separación tenant/super-admin) |
| T-511 | `bauth.idn_global_notification` | Notificaciones globales del sistema |
| T-512 | `bauth.idn_global_hitl_exception` | Excepciones HITL — NIST AI RMF 1.0 §3.6 |
| T-513 | `bauth.idn_global_crypto_params` | Catálogo de parámetros criptográficos — NIST SP 800-131A R2 + PQC FIPS 203/204/205 |
| T-514 | `bauth.idn_global_compliance_control` | Mapa de controles de cumplimiento normativo |
| T-515 | `bauth.idn_global_sbom` | SBOM — Software Bill of Materials — EU Cyber Resilience Act |

---



## TABLAS NUEVAS — T-516..T-561 (2026-08-01)

Tablas identificadas desde `pg_catalog.pg_constraint` presentes en SBOSDB pero
no documentadas en A.65.02 previo. Nombres canónicos en inglés (convención global del DDL).

### D00 — Identidad / DID / DPIA / SCIM

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-516 | `bauth.idn_access_contract` | Contratos de acceso: condiciones negociadas por identidad |
| T-517 | `bauth.idn_attribute_schema` | Esquema de atributos de identidad (definición de tipos) |
| T-529 | `bauth.idn_did_document` | Documentos DID (Decentralized Identifier) W3C |
| T-545 | `bauth.idn_identidad_lifecycle_event` | Eventos del ciclo de vida de identidad |
| T-530 | `bauth.idn_dpia_registro` | Registro DPIA (Data Privacy Impact Assessment) |
| T-555 | `bauth.idn_scim_attribute_map` | Mapeo de atributos SCIM 2.0 a atributos internos |

### D02 — Control de Acceso Físico (tablas nuevas)

| Código | Tabla | Propósito |
|--------|-------|-----------|

### D03 — Control Financiero (tablas nuevas)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-534 | `bauth.idn_financial_invoice_auth` | Autorización de facturas electrónicas (SIN Bolivia) |

### D04 — Control Temporal (tablas nuevas)

| Código | Tabla | Propósito |
|--------|-------|-----------|

### D05 — Control Biométrico (tablas nuevas)

| Código | Tabla | Propósito |
|--------|-------|-----------|

### D06 — Control Geoespacial (tablas nuevas)

| Código | Tabla | Propósito |
|--------|-------|-----------|

### D09 — Credenciales (tablas nuevas)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-525 | `bauth.idn_credencial_revocacion` | Registro de revocaciones de credenciales |

### D10 — Delegación de Identidad (tablas nuevas)

| Código | Tabla | Propósito |
|--------|-------|-----------|

### D11 — Auditoría (tablas nuevas)

| Código | Tabla | Propósito |
|--------|-------|-----------|

### D12 — Blockchain (tablas nuevas)

| Código | Tabla | Propósito |
|--------|-------|-----------|

### D13 — Firma Digital (tablas nuevas)

| Código | Tabla | Propósito |
|--------|-------|-----------|

### D14 — PAM (tablas nuevas)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-560 | `bauth.pam_cuenta_privilegiada` | Cuentas privilegiadas gestionadas por el motor PAM |

### D15 — NHI (tablas nuevas)

| Código | Tabla | Propósito |
|--------|-------|-----------|
| T-546 | `bauth.idn_nhi_identity` | Identidades No Humanas (NHI): M2M, bots, APIs | ⚠️ DDL pendiente — no implementado en SBOS_db_V2_DDL.sql

### D98 — Meta-Registro (tablas nuevas)

| Código | Tabla | Propósito |
|--------|-------|-----------|

### D99 — Admin Global (tablas nuevas)

| Código | Tabla | Propósito |
|--------|-------|-----------|

## Notas técnicas de implementación (migración v1.0)

- **Tablas particionadas (7):** PK compuesta `(id, <partition_key>)` — requerimiento PostgreSQL 18
- **WORM (8 tablas):** `REVOKE UPDATE, DELETE ON <tabla> FROM bauth_app_role`
- **FKs a tablas particionadas:** no FK directa — integridad a nivel aplicación (PostgreSQL no soporta FK a PK compuesta de particionada sin incluir partition key)
- **Seeds cargados:** T-513 (22 algoritmos incluyendo ML-KEM-768, ML-DSA-65, SLH-DSA-SHA2-128s), T-421 (7 políticas de retención base), T-423 (Wazuh destino)
- **Archivo de migración:** `DDLs/migrations/bauth_dominios_pendientes_v1.0.sql`
- **Idempotencia verificada:** 2 pasadas sobre SBOSDB_copia → 0 errores · 2026-07-31
