# A.65 — Inventario de Tablas DDL · Revisión de Diseño

**Versión:** 1.5  **Fecha:** 2026-07-19  **Estado:** BORRADOR

## Principio rector

El árbol `rol_template_datos.dart` se persiste en la **tabla jerárquica del RolTemplate** (nodos tipados: dominio, bloque, política, regla, evaluación, objeto, lista, atributo, enumerado). Esa tabla almacena TODO el árbol — políticas, reglas, efectos, combining_algorithm, obligations, datos de B1-B14 y dominios D0-D13+D98+D99.

**Consecuencia directa:** toda tabla DDL que modele **política del rol** en forma relacional duplica lo que ya vive en la tabla jerárquica → **ELIMINAR**.

Solo sobreviven:
- **Catálogos de referencia** — valores ISO, métodos, verbos, algoritmos
- **Estado dinámico** — sesiones activas, logs, eventos, instancias en vuelo
- **Infraestructura operacional** — claves, dispositivos, certificados, registros reales

---

## Leyenda — Tipo

| Tipo | Significado |
|------|-------------|
| `[K]` | Existente |
| `[N]` | Nueva — propuesta, no existe aún |
| `[?]` | Revisión especial (legacy, propósito dudoso) |
| `PART.` | Partición — decisión ligada a la tabla padre |

## Leyenda — Recomendación

| Valor | Significado |
|-------|-------------|
| `CONSERVAR` | Catálogo, estado dinámico o infraestructura — el árbol no la reemplaza |
| `ELIMINAR` | Política del rol ya en la tabla jerárquica — tabla relacional duplica |

## Columnas de decisión (humano)

- **Decisión:** `MANTENER` · `ELIMINAR` · `RENOMBRAR` · `MOVER` · `PENDIENTE`
- **Observación:** nota breve

---

## GLOBAL

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-001 | `bglobal.global_language` | `[K]` | Catálogo ISO 639-1/3 de idiomas | **CONSERVAR** | Catálogo de referencia — B1 name i18n lo referencia | MANTENER | |
| T-002 | `bglobal.global_country` | `[K]` | Catálogo ISO 3166-1 de países | **CONSERVAR** | Catálogo de referencia — FK en identidad y geolocalización | MANTENER | |
| T-003 | `bglobal.global_currency` | `[K]` | Catálogo ISO 4217 de monedas | **CONSERVAR** | Catálogo de referencia — D3/B8 facturación Bolivia | MANTENER | |
| T-004 | `bglobal.geo_timezone` | `[K]` | Catálogo IANA de zonas horarias | **CONSERVAR** | Catálogo de referencia — D4/B2 validity_period | MANTENER | |
| T-059 | `bglobal.menu_item` | `[K]` | Ítems de menú de aplicación | **CONSERVAR** | Catálogo — B7 CAPA 2 visible_actions referencia menu_id | MANTENER | |
| T-060 | `bglobal.menu_context` | `[K]` | Contextos de menú | **CONSERVAR** | Catálogo — soporte de B7 CAPA 2 | MANTENER | |
| T-061 | `bglobal.menu_item_atom` | `[K]` | Relación ítem↔átomo de privilegio | **CONSERVAR** | Catálogo — puente B7 CAPA 2 con privilege_atom | MANTENER | |
| T-114 | `bglobal.global_config` | `[K]` | Parámetros globales del sistema | **CONSERVAR** | Infraestructura — parámetros de sistema, no política de rol | MANTENER | |

---

## IDENTIDAD

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-005 | `bauth.idn_tenant` | `[K]` | Multi-tenancy: ancla de gobernanza FK de toda la DDL | **CONSERVAR** | Infraestructura — ancla referencial irreemplazable | MANTENER | `[DEL]` realm_kc/realm_kc_ext/domain/session_ttl_max/token_ttl_seconds/rate_limit_rps · `[N]` is_internal · `[?]` purge_after sin default (trigger) |
| T-006 | `bauth.idn_tenant_currencies` | `[K]` | Monedas habilitadas por tenant | **CONSERVAR** | Infraestructura — piso mínimo de completitud del tenant | MANTENER | Actualizada por Motor de Identidad |
| T-007 | `bauth.idn_tenant_languages` | `[K]` | Idiomas habilitados por tenant | **CONSERVAR** | Infraestructura — piso mínimo | MANTENER | Actualizada por Motor de Identidad |
| T-008 | `bauth.idn_tenant_verification` | `[K]` | Estado de verificación de tenant | **CONSERVAR** | Infraestructura — piso mínimo IAL del tenant | MANTENER | Actualizada por Motor de Identidad |
| T-009 | `bauth.idn_tenant_config` | `[K]` | Configuración específica por tenant | **CONSERVAR** | Infraestructura — fuente de verdad de `@bauth_config_param` | MANTENER | Actualizada por Motor de Identidad |
| T-010 | `bauth.idn_tenant_domain` | `[K]` | Dominios DNS del tenant | **CONSERVAR** | Infraestructura — prefijo ctx_id interno/externo | MANTENER | Actualizada por Motor de Identidad |
| T-011 | `bauth.idn_tenant_network` | `[K]` | Redes autorizadas por tenant | **CONSERVAR** | Infraestructura — CIDRs reales del tenant | MANTENER | Actualizada por Motor de Identidad |
| T-013 | `bauth.idn_tenant_calendar_assignment` | `[K]` | Calendarios asignados a tenant/empresa | **CONSERVAR** | Infraestructura — asignación real de calendario | MANTENER | Actualizada por Motor de Identidad |

---

## ROLES

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-040 | `bauth.idn_roles_rol_type`<br>↳ `bauth.idn_roles_rol_type` | `[N]` | Catálogo de 10 tipos de cuenta (INDIVIDUAL, M2M, SYSTEM…) | **CONSERVAR** | Catálogo — B1 `type_id` referencia estos 10 tipos (A.01 §B1 · G-B01-03). Solo lectura en runtime | CONSERVAR | |
| T-041 | `bauth.idn_role_template`<br>↳ `bauth.idn_roles_rol_hierarchical` | `[K]` | **Registro de identidad de roles** — jerarquía de los 548 roles con campos B1: id, parent_id, tier, status, name, metadata, version, audit. Es el QUIÉN del sistema. El árbol de políticas (QUÉ PUEDE cada rol) vive en T-162 `idn_roles_templates`. **B02:** columnas `validity_type / valid_from / valid_until / duration_interval / max_renewals / renewal_count` + trigger `trg_irrh_b02_validity` (auto-expiración TEMPORARY/EMERGENCY). ENUM `rol_status_enum` extendido con `IN_REVIEW`. | **CONSERVAR** | Catálogo de roles — fuente de verdad de la identidad de cada rol. El PDP lo lee para resolver membresía a SETs y tier. A.01 §B1 · A.61 §2 | CONSERVAR | B02 aplicado en VPS 2026-07-25 |
| T-B02L | `bauth.idn_roles_rol_lifecycle_event` | `[K]` | **Log WORM de transiciones de estado del rol (B02 §lifecycle)** — registra cada cambio de estado con `trigger_type` (MANUAL/AUTO_EXPIRY/RECONCILE/IGA_REVIEW/BREAKGLASS/BOOTSTRAP), actor, razón y snapshot de vigencia. REVOKE UPDATE/DELETE. Equivalente a T-160 para NHI. | **CONSERVAR** | Auditoría forense de ciclo de vida del rol. ISO 27001 A.8.15 · NIST AC-2(2) · PCI DSS Req 10.2. | MANTENER | Aplicado en VPS 2026-07-25 |
| T-042 | `bauth.idn_tier_policy`<br>↳ `bauth.idn_roles_rol_tier` | `[K]` | Métodos de autenticación y parámetros de sesión por tier (LOA, mfa_methods[], session_timeout, max_sessions, step_up_allowed, nist_aal_ref) | **CONSERVAR** | Catálogo de configuración de tier — parámetros de autenticación que el árbol de políticas consulta al evaluar D1/D9. PIP del PDP. `bauth_11__idn_tier_policy.sql` | CONSERVAR | |
| T-043 | `bauth.bos_rol_template_history` | `[?]` | Historial de cambios de rol template (pre-MVU) | **ELIMINAR** | Superada por `ver_history` (T-152, MVU 1.13): historia WORM con hash-chain, WITHOUT OVERLAPS PG18, MAJOR/MINOR/PATCH. F2 del MVU la salda. El historial del árbol VIVE en `ver_history` | ELIMINAR | Reemplazo: T-152 `ver_history` |
| T-063 | `bauth.idn_role_closure`<br>↳ `bauth.idn_roles_rol_closure` | `[K]` | Closure table del DAG de herencia OR de roles | **CONSERVAR** | Infraestructura BitMask — B11 `inheritance_mode` requiere closure para calcular máscara acumulada. Recalculada automáticamente por el MVU post-commit. A.01 §B11 · A.61 §2 | CONSERVAR | |
| T-064 | `bauth.idn_rolestpl_atom_config` | `[N]` | Atributos extensibles de átomos (EAV) | **ELIMINAR** | Extensibilidad nativa al árbol jerárquico T-162: agregar un nodo hijo en `idn_roles_templates` con el atributo extendido. A.01 §B2 | ELIMINAR | |
| T-065 | `bauth.idn_rolestpl_atom_history` | `[N]` | Trazabilidad de cambios de átomos (particionada) | **ELIMINAR** | `ver_history` (T-152) es la UNA tabla de historia. Cambio de átomo = cambio de nodo en T-162 `idn_roles_templates` → `ver_history`. C3 → `aud_event` | ELIMINAR | Reemplazo: T-152 + T-091 |
| T-066 | `bauth.idn_rolestpl_atom_history_2026_07` | `[N]` | Partición jul-2026 de T-065 | **ELIMINAR** | Partición de tabla eliminada | ELIMINAR | |
| T-067 | `bauth.idn_rolestpl_atom_history_2026_08` | `[N]` | Partición ago-2026 de T-065 | **ELIMINAR** | Partición de tabla eliminada | ELIMINAR | |
| T-068 | `bauth.idn_rolestpl_requisito` | `[N]` | Completitud mínima de atributos por dominio | **ELIMINAR** | La gramática AtomLang (A.46) valida la completitud al compilar: nodos obligatorios declarados en la gramática, no en una tabla de requisitos separada | ELIMINAR | |
| T-162 | `bauth.idn_roles_templates`<br>↳ `bauth.idn_roles_template` | `[N]` | **Árbol jerárquico de políticas** — UN árbol compartido por todos los roles. Cada fila es un nodo del árbol del dart (dominio, policy_set, policy, rule, atom, obligation, property). El nodo sabe a qué roles aplica mediante `subject` (SET/ROL/ALL) y `unset[]`. El PDP filtra el árbol por rol para obtener su política efectiva | **CONSERVAR** | **Tabla central del QUÉ PUEDE** — materializa el árbol `rol_template_datos.dart` en filas relacionales jerárquicas. Un solo árbol compartido (no uno por rol) — enormemente más eficiente para 1500+ roles. A.64 §7 · dart `rol_template_datos.dart` | CONSERVAR | DDL nuevo: `bauth_65__idn_roles_templates.sql` · Adjacency list con path ltree + GIN sobre subject |

---

## VERSIONADO (Motor de Versionado Universal — MVU 1.13)

> Las 4 tablas del MVU gobiernan el ciclo de vida de `idn_role_template` e `idn_roles_templates`. Migraciones: `bauth_45__version_engine_core.sql` + `bauth_46__ver_history.sql`. Estado: **[N] — diseñadas, sin DDL aplicado en VPS (madurez L1)**.

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-152 | `bauth.idn_roles_ver_b01_audit_log` | `[N]` | Historia universal WORM de definiciones gobernadas C1 — piloto: `idn_role_template` + `idn_roles_templates`; F5 extiende a todo C1. "¿CÓMO ERA Y CÓMO QUEDÓ?" | **CONSERVAR** | C2 — delta por bloque normado + `standard_ref` + fotografía ancla en MAJOR; no-solape `WITHOUT OVERLAPS` PG18; hash-chain WORM. La respuesta a "¿cómo era el rol X el 15 de marzo?" — as-of en segundos (1.13 §8.5) | MANTENER | migración bauth_46 |
| T-153 | `bauth.idn_roles_ver_b03_approval_queue` | `[N]` | Propuestas de cambio MAJOR pendientes de quórum — la definición propuesta espera aquí mientras el quórum del B3 del artefacto se completa; la vigente sigue rigiendo hasta aprobación | **CONSERVAR** | Estado dinámico — implementa el B3 `approval_workflow` del contrato (quórum N-de-M, SLA, escalación). NIST CM-3/AC-5 | MANTENER | migración bauth_45 |
| T-154 | `bauth.idn_roles_ver_b01_retention_policy` | `[N]` | Calendario de retención legal — plazos legales bolivianos + PCI + ISO como tabla consultable. `legal_hold` congela purgas ante litigio | **CONSERVAR** | Infraestructura — CHECK impide plazos bajo el piso D99 (≥365 días). `idn_role_template` = 10 años (Ley 843). AU-11/A.5.33 | MANTENER | migración bauth_45 |
| T-155 | `bauth.idn_roles_ver_contract_revision_log` | `[N]` | Changelog estructural del contrato RolTemplate — transiciones entre versiones (v5.0→v6.0): bloques agregados/removidos, normas que entran/salen, compatibilidad BREAKING/COMPATIBLE, DDL que lo materializó | **CONSERVAR** | Infraestructura — eje `template_version` del MVU (1.13 §5). Jamás copia del contrato — solo el delta estructural | MANTENER | migración bauth_45 |

---

## USUARIOS

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-090 | `bauth.dlg_delegation` | `[K]` | Delegaciones de permiso entre usuarios | **CONSERVAR** | Estado dinámico — instancias activas de delegación; D10/B10 define la política, esta tabla almacena las instancias | PENDIENTE | |
| T-105 | `bauth.idn_user_template` | `[K]` | Identidad SCIM 2.0 de usuarios | **CONSERVAR** | Infraestructura — contrato del usuario, simétrico al rol | PENDIENTE | |
| T-106 | `bauth.idn_user_role` | `[K]` | Asignación usuario↔rol con vigencia temporal | **CONSERVAR** | Estado dinámico — asignaciones activas con fechas reales | PENDIENTE | |

---

## PRIVILEGIOS

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-045 | `bauth.privilege_domain` | `[K]` | Dominios XACML D00-D13 | **CONSERVAR** | Catálogo — registro de dominios D0–D13+D98+D99 | PENDIENTE | |
| T-046 | `bauth.privilege_application` | `[K]` | Aplicaciones dentro de cada dominio | **CONSERVAR** | Catálogo — registro de apps (crm, hrms, bnotify); B7 referencia app_code | PENDIENTE | |
| T-047 | `bauth.privilege_group` | `[K]` | Grupos de átomos (SAM-128) | **CONSERVAR** | Catálogo — B9 SAM-128 Q1/Q2/Q3/Q4 masks | PENDIENTE | |
| T-048 | `bauth.privilege_verb` | `[K]` | Verbos de acción atómica | **CONSERVAR** | Catálogo — verbos (read/write/approve/emit…) enumerados en todo el árbol | PENDIENTE | |
| T-049 | `bauth.bos_permiso_logico` | `[?]` | Alias de átomos por aplicación | **ELIMINAR** | El árbol usa slug directo `app.crm/crm.lead` — capa de alias no añade valor con este esquema | PENDIENTE | |
| T-050 | `bauth.privilege_atom` | `[K]` | Definición de átomos 24-bit | **CONSERVAR** | Infraestructura — cada `_ev()` del árbol compila a un átomo aquí | PENDIENTE | |
| T-051 | `bauth.privilege_role` | `[K]` | Roles de privilegio (vínculo BitMask↔rol) | **CONSERVAR** | Infraestructura — motor BitMask 64-bit | PENDIENTE | |
| T-052 | `bauth.privilege_role_atom` | `[K]` | Asignación átomo→rol con máscara 64-bit | **CONSERVAR** | Infraestructura — materialización del BitMask | PENDIENTE | |
| T-053 | `bauth.privilege_user_atom` | `[N]` | Sobrescrituras individuales usuario→átomo | **CONSERVAR** | Estado dinámico — overrides por usuario, no por rol | PENDIENTE | |
| T-054 | `bauth.privilege_atom_compiled` | `[N]` | IR compilado de átomos por rol (output atomc) | **CONSERVAR** | Infraestructura — salida del compilador AtomLang; fast-path PDP <0.5ns | PENDIENTE | |
| T-055 | `bauth.privilege_atom_policy` | `[K]` | Políticas JSONB formales por átomo | **CONSERVAR** | Infraestructura — almacena el JSONB del árbol por átomo; fuente de verdad del PDP | PENDIENTE | |
| T-056 | `bauth.privilege_atom_audit` | `[K]` | Auditoría de evaluaciones de átomo (particionada) | **CONSERVAR** | Estado dinámico — log WORM de evaluaciones; D11/B13 lo exige | PENDIENTE | |
| T-057 | `bauth.privilege_atom_audit_2026_06` | PART. | Partición jun-2026 | **CONSERVAR** | Partición de T-056 | PENDIENTE | |
| T-058 | `bauth.privilege_atom_audit_2026_07` | PART. | Partición jul-2026 | **CONSERVAR** | Partición de T-056 | PENDIENTE | |
| T-062 | `bauth.zone_application_map` | `[K]` | Mapa zona↔aplicación | **CONSERVAR** | Infraestructura — B6 zonas necesitan saber qué apps pertenecen a cada perímetro | PENDIENTE | |

---

## SOD

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-069 | `bauth.fin_sod_rule` | `[K]` | Reglas de Separación de Deberes | **ELIMINAR** | D10/B12 `incompatible_roles` tiene todas las reglas SoD como átomos DENY con INTERSECT en el árbol | PENDIENTE | |
| T-070 | `bauth.fin_decision_matrix` | `[K]` | Matriz de decisiones financieras por rol | **ELIMINAR** | D3/B8 `sod_rules` + `transaction_limits` en el árbol — política financiera completa | PENDIENTE | |
| T-129 | `bauth.sod_validation_config` | `[K]` | Configuración de validación SoD | **ELIMINAR** | D10/B12 `conflict_validation` en el árbol: `evaluation_timing=REAL_TIME`, `check_scope=[DIRECT,INHERITED,DELEGATED]` | PENDIENTE | |
| T-130 | `bauth.conflict_interest_policy` | `[K]` | Política de conflicto de interés | **ELIMINAR** | D10/B12 `interest_conflicts` en el árbol: parentesco grado ≤2, declaración anual SOX §302 | PENDIENTE | |

---

## AUTENTICACIÓN

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-034 | `bauth.ath_config` | `[K]` | Configuración global de autenticación | **CONSERVAR** | Infraestructura — parámetros de infra de auth, no política de rol | PENDIENTE | |
| T-038 | `bauth.ath_policy` | `[K]` | Políticas de autenticación por contexto | **ELIMINAR** | D1/B4 del árbol contiene la política de autenticación completa por rol (métodos, lockout, session, DPoP, scopes) | PENDIENTE | |
| T-039 | `bauth.ath_method` | `[K]` | Catálogo de 18 métodos de autenticación | **CONSERVAR** | Catálogo — D1/D2 `available_methods[]` referencia method_id; necesita registro canónico | PENDIENTE | |
| T-074 | `bauth.ath_credential_policy` | `[K]` | Política de credenciales (NIST 800-63B) | **ELIMINAR** | D9/B18 `password_policy` + `enrollment_policy` + `rotation_policy` + `revocation_policy` en el árbol — política completa NIST 800-63B-4 | PENDIENTE | |
| T-075 | `bauth.ath_password_history` | `[K]` | Historial de contraseñas (no repetición) | **CONSERVAR** | Estado dinámico — historial real de contraseñas por usuario | PENDIENTE | |
| T-076 | `bauth.ath_password_screening` | `[K]` | Screening de contraseñas comprometidas | **CONSERVAR** | Estado operacional — log de breach checks ejecutados | PENDIENTE | |
| T-077 | `bauth.ath_mfa_enrollment` | `[K]` | Enrolamiento de factores MFA | **CONSERVAR** | Estado dinámico — enrolamientos MFA reales por usuario | PENDIENTE | |
| T-078 | `bauth.ath_recovery_method` | `[K]` | Métodos de recuperación de cuenta | **CONSERVAR** | Estado dinámico — métodos de recuperación activos por usuario | PENDIENTE | |
| T-079 | `bauth.ath_recovery_challenge` | `[K]` | Desafíos de recuperación activos | **CONSERVAR** | Estado efímero — desafíos en vuelo | PENDIENTE | |
| T-080 | `bauth.ath_binding` | `[K]` | Vinculación token↔dispositivo (mTLS/DPoP) | **CONSERVAR** | Estado dinámico — vinculaciones DPoP/mTLS activas | PENDIENTE | |
| T-081 | `bauth.ath_revocation` | `[K]` | Revocaciones de token/credencial | **CONSERVAR** | Estado dinámico — registro de revocaciones activas; SLA ≤30s | PENDIENTE | |
| T-082 | `bauth.ath_login_attempt` | `[K]` | Log de intentos de login (particionada) | **CONSERVAR** | Estado dinámico — D1 `account_lockout_policy` necesita contar intentos en ventana | PENDIENTE | |
| T-083 | `bauth.ath_login_attempt_2026_07` | PART. | Partición jul-2026 | **CONSERVAR** | Partición de T-082 | PENDIENTE | |
| T-084 | `bauth.ath_login_attempt_2026_08` | PART. | Partición ago-2026 | **CONSERVAR** | Partición de T-082 | PENDIENTE | |
| T-085 | `bauth.ath_consent` | `[K]` | Consentimientos OAuth2 de usuario | **CONSERVAR** | Estado dinámico — consentimientos reales por usuario/cliente | PENDIENTE | |
| T-086 | `bauth.ath_rotation_log` | `[K]` | Log de rotación de credenciales | **CONSERVAR** | Estado operacional — log de rotaciones ejecutadas | PENDIENTE | |
| T-087 | `bauth.ath_token_delivery` | `[K]` | Entrega de tokens por canal | **CONSERVAR** | Estado operacional — registro de entregas | PENDIENTE | |
| T-088 | `bauth.ath_enrollment_log` | `[K]` | Log de enrolamientos de métodos auth | **CONSERVAR** | Estado operacional — log de enrolamientos ejecutados | PENDIENTE | |
| T-089 | `bauth.ath_federation_protocol` | `[K]` | Protocolos de federación (SAML, OIDC) | **CONSERVAR** | Catálogo — protocolos de federación; T-141/T-142 dependen | PENDIENTE | |
| T-115 | `bauth.ath_auth_flow` | `[K]` | Flujos de autenticación (secuencias AAL) | **ELIMINAR** | D1/D2 `required_methods{}` en el árbol: 4 sub-grupos ordenados (primary→mfa→step_up→re_auth) | PENDIENTE | |
| T-116 | `bauth.ath_auth_flow_method` | `[K]` | Métodos dentro de cada flujo | **ELIMINAR** | D1/D2 `available_methods[]` en el árbol: pool de métodos por dominio | PENDIENTE | |
| T-117 | `bauth.ath_step_up_rule` | `[K]` | Reglas de step-up autenticación (RFC 9470) | **ELIMINAR** | D1/D2 `step_up_triggers` en el árbol con `aggregate-strictest` RFC 9470 — implementación completa | PENDIENTE | |

---

## SESIÓN

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-071 | `bauth.ses_context` | `[K]` | Contextos de sesión activa (SBOS-049) | **CONSERVAR** | Estado dinámico — ctx_id activos en tiempo real; obligatorio SBOS-049 | PENDIENTE | |
| T-072 | `bauth.ses_context_switch` | `[K]` | Historial de cambios de contexto de sesión | **CONSERVAR** | Estado dinámico — trazabilidad de ctx_id | PENDIENTE | |
| T-073 | `bauth.ses_superuser_context` | `[K]` | Contextos de superusuario | **CONSERVAR** | Estado dinámico — contextos SU activos | PENDIENTE | |
| T-127 | `bauth.ses_risk_policy` | `[K]` | Política de riesgo de sesión | **ELIMINAR** | D8/B17 `adaptive_policies` en el árbol: 3 umbrales de riesgo (0.50/0.70/0.90) con efectos y obligations | PENDIENTE | |
| T-128 | `bauth.ses_caep_config` | `[K]` | Configuración CAEP (RFC 9396) | **CONSERVAR** | Infraestructura — endpoints, secretos HMAC y suscripciones CAEP; no es política de rol | PENDIENTE | |

---

## IDENTIDAD D00 — Catálogo Universal

> Tablas `[K]` eliminadas de este grupo: T-107 `org_empresa` · T-108 `org_sucursal` · T-109 `org_pos_logico` — redundantes con `idn_identity_entity` (1.06 §4 · SBOS-049 §3.1)

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-107 | `bauth.org_empresa` | `[K]` | Empresas dentro del tenant | **ELIMINAR** | `idn_identity_entity` con `nivel='bdomain', tipo='empresa'` ES el catálogo de empresas (1.06 §4 · ctx_id capa 2 = `bdomain_id`). NIT y atributos fiscales van en `idn_identity_attribute`. La tabla duplica lo que el motor de identidad D00 ya registra | ELIMINAR | |
| T-108 | `bauth.org_sucursal` | `[K]` | Sucursales de empresa | **ELIMINAR** | `idn_identity_entity` con `nivel='bsubdomain', tipo='sucursal'` ES el catálogo de sucursales (1.06 §4 · ctx_id capa 3 = `bsubdomain_id`). SBOS-049 §3.1: `ctx_id = tenant_id:empresa_id:sucursal_id:pos_logico:user_id:traceparent`. La tabla duplica el árbol D00 | ELIMINAR | |
| T-109 | `bauth.org_pos_logico` | `[K]` | Puntos de operación lógica (SIN Bolivia) | **ELIMINAR** | `idn_identity_entity` con `nivel='pos', tipo='caja'` o `tipo='punto_virtual'` ES el POS lógico (1.06 §4 · ctx_id capa 4 = `pos_logico`). Código SIN, NIT emisor van en `idn_identity_attribute` con `category='tributario'`. La tabla duplica el árbol D00 | ELIMINAR | |
| T-156 | `bauth.idn_identity_entity` | `[N]` | Catálogo universal de entidades — árbol de 5 niveles (tenant/bdomain/bsubdomain/pos/actor) con `tipo` variable | **CONSERVAR** | Motor D00 — reemplaza org_empresa/sucursal/pos_logico. ctx_id capas 2/3/4 son `entity_id` de esta tabla (SBOS-049 §3.1). A.56 §2 · 1.06 §3/§4 | CONSERVAR | DDL: `bauth_47__idn_identity_entity.sql` |
| T-157 | `bauth.idn_identity_attribute` | `[N]` | Atributos extensibles EAV de cualquier entidad — sin ALTER TABLE. `atom_code` vincula con BitMask | **CONSERVAR** | Motor D00 — almacena NIT, razón social, código SIN, dirección, etc. de cualquier entidad. Particionado HASH por tenant_id. A.56 §3 · 1.07 §3 | CONSERVAR | DDL: `bauth_47__idn_identity_entity.sql` · Columnas generadas: `value_normalized` + `value_search` |
| T-158 | `bauth.idn_identity_attribute_history` | `[N]` | Historial WORM de cambios de atributos — append-only, particionado por mes | **CONSERVAR** | C3 trazabilidad — ISO 27001 A.8.15 · PCI DSS 10.3.2 · GDPR Art. 30. Trigger automático en INSERT/UPDATE/DELETE de T-157. A.56 §3.5 | CONSERVAR | DDL: `bauth_47__idn_identity_entity.sql` · Partición: RANGE (changed_at) mensual |
| T-159 | `bauth.idn_identity_requirement` | `[N]` | Completitud mínima por tipo de entidad y nivel (IAL1/IAL2/IAL3) | **CONSERVAR** | Garantía del Motor de Identidad — valida ANTES de crear cualquier entidad. D93 governa los tipos válidos. A.56 §3.6 | CONSERVAR | DDL: `bauth_47__idn_identity_entity.sql` |
| T-160 | `bauth.idn_identity_synonym` | `[N]` | Sinónimos y abreviaturas para fuzzy search — fuente de verdad de archivos `.syn` de PostgreSQL | **CONSERVAR** | Motor de búsqueda D93 — "foco del izq" → "Farol Delantero Izquierdo". Administrable desde dashboard D93. A.56 §3.9 | CONSERVAR | DDL: `bauth_47__idn_identity_entity.sql` |
| T-161 | `bauth.idn_identity_synonym_sync` | `[N]` | Control de sincronización: regenera archivos `.syn` cuando `updated_at > last_sync_at` | **CONSERVAR** | Infraestructura de búsqueda — evita recarga innecesaria de diccionarios. A.56 §3.9 | CONSERVAR | DDL: `bauth_47__idn_identity_entity.sql` |

---

## FINANCIERO

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-027 | `bauth.fin_transaction_type` | `[K]` | Tipos de transacción financiera | **CONSERVAR** | Catálogo — D3/B8 referencia tipos de operación | PENDIENTE | |
| T-028 | `bauth.fin_limit` | `[K]` | Límites financieros por rol/dominio | **ELIMINAR** | D3/B8 `transaction_limits` en el árbol: single/daily/monthly/dual_approval via `@bauth_config_param` | PENDIENTE | |
| T-029 | `bauth.fin_approval_chain` | `[K]` | Cadenas de aprobación financiera | **ELIMINAR** | D0/B3 `approval_workflow` en el árbol: quórum, nivel jerárquico, SLA, escalación, canal bNotify | PENDIENTE | |
| T-030 | `bauth.fin_approval_level` | `[K]` | Niveles de aprobación | **ELIMINAR** | D3/B8 `requiredMethods_financial` en el árbol: 3 niveles por monto con step-up y doble aprobación | PENDIENTE | |
| T-031 | `bauth.fin_approval` | `[K]` | Instancias de aprobación | **CONSERVAR** | Estado dinámico — aprobaciones en vuelo; instancias reales, no política | PENDIENTE | |
| T-032 | `bauth.fin_document_operation` | `[K]` | Operaciones sobre documentos financieros | **CONSERVAR** | Estado operacional — registro de operaciones ejecutadas | PENDIENTE | |
| T-033 | `bauth.fin_role_permission` | `[K]` | Permisos financieros por rol | **ELIMINAR** | D1/B7 CAPA 1 `model_access` en el árbol: CRUD por modelo por aplicación | PENDIENTE | |

---

## FÍSICO

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-020 | `bauth.fis_location` | `[K]` | Jerarquía de ubicaciones físicas | **ELIMINAR** | D2 `zones_access_rules` (dart:1431-1458) define cada zona como nodo con sus reglas, duración y obligaciones embebidas. D0 `metadata.region`/`territory_code` (dart:249-250) cubre la jerarquía organizacional-territorial. Jerarquía de ubicaciones = jerarquía de zonas en el árbol | PENDIENTE | Reemplazo: nodos de zona en D2 + D0 metadata |
| T-021 | `bauth.fis_location_closure` | `[K]` | Closure table de ubicaciones físicas | **ELIMINAR** | Closure de T-020 (ELIMINAR). La herencia de permisos por jerarquía física está en el árbol D2 vía `deny-overrides` + `DENIED explícito` que niega aunque zona padre permita | PENDIENTE | Eliminada con su padre T-020 |
| T-022 | `bauth.fis_area_config` | `[K]` | Configuración de áreas físicas | **ELIMINAR** | `physical_security_level` de cada área es atributo del nodo de zona en D2. `physical_security_controls` (dart:1460-1481) define reglas por `zone.type` (VAULT, DATACENTER, SERVER_ROOM). `mfa_auth{}` (dart:1340) evalúa `zone.physical_security_level >= 3` — ese valor es atributo del nodo de zona en el árbol, no de una tabla separada | PENDIENTE | Reemplazo: atributos del nodo de zona en D2 |
| T-023 | `bauth.fis_device` | `[K]` | Dispositivos físicos (lectores, torniquetes) | **CONSERVAR** | Inventario de hardware OSDP real — serial, firmware, ubicación, estado. El árbol referencia `device.has_nfc_reader` (dart:1332) como PIP; el valor de esa propiedad viene de este catálogo. Hardware físico instalado no es política del rol | PENDIENTE | |
| T-024 | `bauth.fis_controller` | `[K]` | Controladores físicos | **CONSERVAR** | Inventario de controladores OSDP físicos — IP, puerto, lista de dispositivos gestionados. El árbol define protocolos (OSDP 2.2) pero no cataloga hardware específico instalado | PENDIENTE | |
| T-025 | `bauth.fis_access_zone` | `[K]` | Zonas de acceso físico | **ELIMINAR** | Catálogo de zonas = los nodos `_ev(zone.id == 'PHY_ZONE_VENTAS')` en D2 `zones_access_rules` (dart:1431-1458). Cada zona es un nodo con efecto PERMIT/DENY, obligaciones (audit_level, max_duration_minutes, alert) y default-deny implícito. El árbol ES el catálogo de zonas | PENDIENTE | Reemplazo: nodos en D2 `zones_access_rules` |
| T-026 | `bauth.fis_zone_member` | `[K]` | Miembros de zona física | **ELIMINAR** | Membresía rol→zona = exactamente `zones_access_rules` en D2 (dart:1431-1458): PHY_ZONE_VENTAS → PERMIT, PHY_ZONE_ALMACEN → PERMIT 30 min, PHY_ROOM_SERVIDOR → DENY. Esa IS la asignación. No hay asignación separada de "el rol es miembro de esta zona" — el árbol ya lo declara | PENDIENTE | Reemplazo: D2 `zones_access_rules` en el árbol |
| T-122 | `bauth.fis_zone_method_requirement` | `[K]` | Requerimientos de método auth por zona física | **ELIMINAR** | D2/B5 `mfa_auth{}` (dart:1340-1365): `required_if=zone.physical_security_level >= 3` con `eligible_methods[]` completo — biométrico para level 3, SmartCard+biométrico para level 4 | PENDIENTE | |
| T-123 | `bauth.fis_emergency_config` | `[K]` | Configuración de emergencia física | **ELIMINAR** | D2/B5 `alternative_methods[].alt_emergencia_override` (dart:1419-1427): `requires_approval=true`, `max_uses=1 (reporte automático a CISO)`, `loa=degraded`, `doble autorización` — configuración completa en el árbol | PENDIENTE | |

---

## GEOLOCALIZACIÓN

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-132 | `bauth.geo_trust_tier` | `[K]` | Nivel de confianza geográfica | **ELIMINAR** | D6/B15 `allowed_locations[]` en el árbol define security_level por tipo de ubicación (office=2, vpn=2, home=1) | PENDIENTE | |
| T-133 | `bauth.geo_velocity_policy` | `[K]` | Política de velocidad geográfica (impossible travel) | **ELIMINAR** | D6 `velocidad imposible` en el árbol con `@bauth_config_param.max_velocity_km_h` — política completa | PENDIENTE | |
| T-134 | `bauth.geo_fence` | `[K]` | Geocercas de acceso | **ELIMINAR** | D6/B15 `allowed_locations[]` en el árbol: office/vpn_remoto/home_office con CIDRs y reglas de validación | PENDIENTE | |
| T-135 | `bauth.geo_location_log` | `[K]` | Log de ubicaciones de usuario | **CONSERVAR** | Estado dinámico — ubicaciones reales registradas en tiempo real | PENDIENTE | |
| T-136 | `bauth.geo_evaluation_log` | `[K]` | Log de evaluaciones geográficas | **CONSERVAR** | Estado dinámico — log de evaluaciones geográficas ejecutadas | PENDIENTE | |

---

## RED/ZTNA

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-113 | `bauth.net_device` | `[K]` | Dispositivos de red registrados | **CONSERVAR** | Infraestructura — registro real de dispositivos; D7/B16 compliance_checks evalúa sobre estos | PENDIENTE | |
| T-126 | `bauth.net_ztna_policy` | `[K]` | Política ZTNA por segmento de red | **ELIMINAR** | D7/B16 en el árbol: `device_compliance_checks` (5 controles) + `api_gateway_rules` (rate_limit, CIDR, mTLS) — política ZTNA completa | PENDIENTE | |

---

## AUDITORÍA

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-091 | `bauth.aud_event` | `[K]` | Eventos de auditoría ISO 27001 A.8.15 (particionada) | **CONSERVAR** | **C3 — Primera mitad de la trazabilidad** (5.01 §2.1): "¿QUÉ OCURRIÓ?" — 24 col, 30 tipos, iso_control[] en origen, hash-chain WORM, ctx_id+traceparent, particionada mensual. El MVU complementa con C2 (versiones) — son capas distintas, no redundantes | MANTENER | Revisado vs 5.01+1.13: irreemplazable; `ver_history` es la otra mitad (qué decía la definición), no un sustituto |
| T-092 | `bauth.aud_event_2026_07` | PART. | Partición jul-2026 | **CONSERVAR** | Partición mensual de T-091 | MANTENER | |
| T-093 | `bauth.aud_event_2026_08` | PART. | Partición ago-2026 | **CONSERVAR** | Partición mensual de T-091 | MANTENER | |
| T-094 | `bauth.aud_review` | `[K]` | Revisiones periódicas de acceso | **CONSERVAR** | Estado dinámico — instancias reales de revisión trimestral (ISO A.9.2.5/AC-2); D11/B13 define la política `review_frequency`, esta tabla las instancias ejecutadas | MANTENER | |
| T-095 | `bauth.aud_ghost_account` | `[K]` | Detección de cuentas fantasma | **CONSERVAR** | Estado dinámico — resultados de corridas de privilege_creep detection; no es política del rol sino resultados operacionales en tiempo real | MANTENER | |
| T-096 | `bauth.aud_policy_change` | `[K]` | Log de cambios de política | **ELIMINAR** | Redundante con `ver_history.fields_changed` + `aud_event(POLICY_CHANGE)`. El árbol B1 `audit.change_history[]` define el contrato semántico `{version, changed_by, approved_by, changes[], reason, security_impact}` — ya materializado en `ver_history` (delta por bloque) y en `aud_event.details` (old_params/new_params). Tres sitios para el mismo dato | ELIMINAR | Reemplazo: T-091 `aud_event` tipo POLICY_CHANGE + T-152 `ver_history.fields_changed` |
| T-097 | `bauth.aud_policy_version` | `[?]` | Versiones de política (WORM) | **ELIMINAR** | El árbol B1 define `audit.version_number + change_history[]` — contrato semántico del historial. `ver_history` (T-152) lo materializa como WORM con `WITHOUT OVERLAPS` PG18. En F5 del MVU `ver_history` cubrirá `cfg_policy_library` y subsumirá completamente esta tabla. MANTENER con retención ≥7 años hasta que F5 esté aplicado en VPS | ELIMINAR (F5) | ELIMINAR cuando F5 del MVU esté aplicado — hasta entonces retención ≥7 años. Reemplazo: T-152 `ver_history` |
| T-098 | `bauth.aud_compliance_map` | `[K]` | Mapa de cumplimiento normativo | **CONSERVAR** | Infraestructura de nivel SISTEMA — qué controles cubre bAuth en conjunto (A.8.15, AU-3, AC-2, PCI Req 10...). Distinto de D11/B13 `regulatory_frameworks` que opera a nivel ROL (qué marcos debe cumplir este rol). El árbol dice "el rol VENDEDOR debe cumplir PCI Req 7/8/10"; este mapa dice "el sistema bAuth cubre el control AU-3 en su totalidad" | MANTENER | Distinción crítica: D11/B13 = política del ROL · esta tabla = cobertura del SISTEMA |

---

## BLOCKCHAIN

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-100 | `bauth.blk_anchor` | `[K]` | Anclas blockchain para integridad (Besu) | **CONSERVAR** | Infraestructura — anclas reales en Besu QBFT | PENDIENTE | |
| T-101 | `bauth.blk_merkle_batch` | `[K]` | Lotes Merkle de auditoría | **CONSERVAR** | Estado dinámico — lotes Merkle generados; D12 AuditLog.appendEntry | PENDIENTE | |
| T-102 | `bauth.blk_merkle_leaf` | `[K]` | Hojas del árbol Merkle | **CONSERVAR** | Estado dinámico — hojas individuales por evento de auditoría | PENDIENTE | |
| T-103 | `bauth.blk_account` | `[K]` | Cuentas blockchain vinculadas | **CONSERVAR** | Infraestructura — wallets reales por rol; D12 `wallet_policy` las administra | PENDIENTE | |
| T-104 | `bauth.blk_reconciliation` | `[K]` | Reconciliación blockchain↔bAuth | **CONSERVAR** | Estado dinámico — registro de reconciliaciones ejecutadas; B14 drift_detected | PENDIENTE | |

---

## SEGURIDAD

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-035 | `bauth.bos_crypto_algorithm` | `[K]` | Catálogo de algoritmos criptográficos | **CONSERVAR** | Catálogo — B1 digital_signature referencia EdDSA/RSA-SHA256/Dilithium | PENDIENTE | |
| T-110 | `bauth.sec_key_inventory` | `[K]` | Inventario de claves criptográficas (Vault) | **CONSERVAR** | Infraestructura — claves reales en Vault; D12 `signing.key_storage_location` | PENDIENTE | |
| T-111 | `bauth.sec_key_rotation` | `[K]` | Rotación de claves criptográficas | **CONSERVAR** | Estado dinámico — log de rotaciones de claves ejecutadas | PENDIENTE | |
| T-112 | `bauth.sec_key_recovery` | `[K]` | Recuperación de claves criptográficas | **CONSERVAR** | Infraestructura — procedimiento de recuperación; D12 `rotate_in_vault` | PENDIENTE | |

---

## DISPOSITIVOS

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-137 | `bauth.user_client_device` | `[K]` | Dispositivos cliente registrados (FIDO2) | **CONSERVAR** | Infraestructura — registro de dispositivos conocidos; D8 `new_device` evalúa contra este registro | PENDIENTE | |
| T-138 | `bauth.ctx_transfer_log` | `[K]` | Log de transferencia de contexto entre dispositivos | **CONSERVAR** | Estado dinámico — transferencias reales de ctx_id | PENDIENTE | |
| T-139 | `bauth.qr_challenge_registry` | `[K]` | Registro de desafíos QR (autenticación móvil) | **CONSERVAR** | Estado efímero — desafíos QR activos TTL=30s; D2 `qr_dynamic` | PENDIENTE | |
| T-140 | `bauth.mobile_heartbeat_log` | `[K]` | Heartbeat de aplicaciones móviles | **CONSERVAR** | Estado dinámico — heartbeat real de apps; D8 `device_posture` | PENDIENTE | |
| T-147 | `bauth.mobile_app_config` | `[K]` | Configuración de apps móviles | **CONSERVAR** | Infraestructura — config real de app móvil por tenant | PENDIENTE | |
| T-148 | `bauth.device_attestation_log` | `[K]` | Log de atestación de dispositivos | **CONSERVAR** | Estado dinámico — atestaciones ejecutadas; D7 MDM enrolled | PENDIENTE | |
| T-149 | `bauth.push_token_registry` | `[K]` | Registro de tokens push (notificaciones) | **CONSERVAR** | Infraestructura — tokens FCM/APNs reales por dispositivo | PENDIENTE | |
| T-150 | `bauth.certificate_pin_config` | `[K]` | Configuración de certificate pinning | **CONSERVAR** | Infraestructura — config de pinning real por app | PENDIENTE | |
| T-151 | `bauth.token_refresh_log` | `[K]` | Log de renovación de tokens | **CONSERVAR** | Estado dinámico — renovaciones de sesión ejecutadas | PENDIENTE | |

---

## ZONAS-UI

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-118 | `bauth.zone_field_restriction` | `[K]` | Restricción de campos por zona de acceso | **ELIMINAR** | D1/B7 CAPA 3 `field_restrictions` en el árbol: margin/cost_price ocultos, credit_limit read-only | PENDIENTE | |
| T-119 | `bauth.zone_button_rule` | `[K]` | Reglas de botones/acciones por zona | **ELIMINAR** | D1/B7 CAPA 4 `button_rules` en el árbol: tiers con PYSON, SoD en pagos, first-applicable | PENDIENTE | |
| T-120 | `bauth.zone_record_rule` | `[K]` | Reglas de registros visibles por zona | **ELIMINAR** | D1/B7 CAPA 5 `record_rules` en el árbol: filtros SQL territory_code/owner_id/team_id | PENDIENTE | |
| T-121 | `bauth.zone_data_policy` | `[K]` | Políticas de datos por zona | **ELIMINAR** | D1/B6 en el árbol: masking PII clientes, anti-exfiltración ventas, SoD financiero — política completa por zona | PENDIENTE | |

---

## CALENDARIO

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-012 | `bcalendar.cal_fiscal_year` | `[K]` | Años fiscales por tenant | **CONSERVAR** | Infraestructura — años fiscales reales del tenant | PENDIENTE | |
| T-014 | `bcalendar.cal_calendar` | `[K]` | Calendarios laborales | **CONSERVAR** | Infraestructura — calendarios reales; D4/B2 enlaza calendario al rol | PENDIENTE | |
| T-015 | `bcalendar.cal_event` | `[K]` | Eventos de calendario | **CONSERVAR** | Infraestructura — eventos reales del calendario | PENDIENTE | |
| T-016 | `bcalendar.cal_alarm` | `[K]` | Alarmas de eventos | **CONSERVAR** | Infraestructura — D4 review_date alerta 30 días antes | PENDIENTE | |
| T-017 | `bcalendar.cal_notification_log` | `[K]` | Log de notificaciones de calendario | **CONSERVAR** | Estado dinámico — log de alertas enviadas | PENDIENTE | |
| T-018 | `bcalendar.cal_holiday` | `[K]` | Días festivos y no laborables | **CONSERVAR** | Infraestructura — D3 `transaction_schedule` depende de días hábiles reales | PENDIENTE | |
| T-019 | `bcalendar.cal_schedule` | `[K]` | Horarios laborales | **CONSERVAR** | Infraestructura — horarios reales por tenant; D3 ventana 09:00-16:00 | PENDIENTE | |
| T-124 | `bcalendar.cal_overtime_policy` | `[K]` | Políticas de horas extra | **CONSERVAR** | Infraestructura — D3 override de emergencia fuera de horario | PENDIENTE | |
| T-125 | `bcalendar.cal_break_policy` | `[K]` | Políticas de descanso | **CONSERVAR** | Infraestructura — soporte de D4 temporal y ventanas de sesión | PENDIENTE | |

---

## OIDC/IDP

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-141 | `bauth.idp_client` | `[K]` | Clientes OIDC/OAuth2 registrados | **CONSERVAR** | Infraestructura del servidor OIDC — el árbol define scopes del ROL; esta tabla registra la APP cliente (client_id, client_secret, redirect_uris, grant_types). Entidades distintas — no duplica | MANTENER | Revisado vs árbol: el árbol es dimensión ROL; esta tabla es dimensión CLIENTE — el servidor OIDC intersecta ambas |
| T-142 | `bauth.idp_client_policy` | `[K]` | Políticas de cliente OIDC | **CONSERVAR** | Infraestructura del servidor OIDC — superposición parcial con D1 `oauth_scopes` pero son capas ortogonales: árbol=scopes del ROL, esta tabla=scopes que puede pedir el CLIENTE. DPoP/PKCE del árbol es política del rol; aquí es config por cliente | MANTENER | Revisado vs árbol: dos capas distintas del protocolo OAuth2 — no duplica |
| T-143 | `bauth.idp_token_config` | `[K]` | Configuración de tokens por cliente | **CONSERVAR** | Infraestructura del servidor OIDC — árbol tiene `re_auth_policy` (política del ROL, 480 min sesión); esta tabla tiene TTL de access_token/refresh_token/id_token por cliente (parámetros del servidor). Capas distintas del protocolo | MANTENER | Revisado vs árbol: `re_auth_policy` ≠ `access_token_ttl` — no duplica |

---

## SINCRONIZACIÓN

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-099 | `bauth.sync_log` | `[?]` | Log de sincronización | **ELIMINAR** | D99/B14 `sync_status/drift_details` en el árbol + `aud_event` ya capturan sincronización — duplica ambos | PENDIENTE | |

---

## CONFIG

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-036 | `bauth.cfg_validation_rule` | `[K]` | Reglas de validación de datos | **ELIMINAR** | El nodo `evaluacion` AtomLang (propiedad+operador+valor+efecto) cubre todos los patrones de validación: IS_SET, BETWEEN, IN, NOT_IN, INCLUDES_ALL, STARTS_WITH, visible_to_role — tabla relacional duplica exactamente el árbol | PENDIENTE | |
| T-037 | `bauth.cfg_validation_log` | `[K]` | Log de validaciones ejecutadas | **ELIMINAR** | Duplica T-056 `privilege_atom_audit` (log WORM de evaluaciones PDP) + T-091 `aud_event` — sin razón de existir si T-036 se elimina | PENDIENTE | |

---

## EMERGENCIA

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-144 | `bauth.emergency_override_policy` | `[K]` | Política de override de emergencia | **ELIMINAR** | D8 `emergency_access` + D2 `emergency_override` en el árbol: doble aprobación, duración 4h, auditoría WORM CISO — política completa | PENDIENTE | |

---

## VISITANTES

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-145 | `bauth.visitor_access_policy` | `[K]` | Política de acceso de visitantes | **ELIMINAR** | D2/B5 `re_auth_policy` en el árbol: re-verificación cada 4h para visitantes/proveedores, max_session=480min | PENDIENTE | |
| T-146 | `bauth.external_session_registry` | `[K]` | Registro de sesiones externas | **CONSERVAR** | Estado dinámico — sesiones activas de usuarios externos (EXT_N0) | PENDIENTE | |

---

## LEGADO

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-131 | `bauth.tryton_action_visibility` | `[?]` | Tryton eliminado ADR-010 | **ELIMINAR** | ADR-010 — Tryton eliminado; no aparece en ningún dominio del árbol | ELIMINAR | Sin reemplazo |

---

## VARIOS

| Código | Tabla | Tipo | Descripción | Recomendación | Razón | Decisión | Observación |
|--------|-------|------|-------------|---------------|-------|----------|-------------|
| T-044 | `bauth.log_zone` | `[?]` | Log de zonas de acceso (¿propósito definido?) | **ELIMINAR** | Propósito indefinido — no referenciado en ningún dominio del árbol; aud_event cubre logs de zona | PENDIENTE | |

---

## Resumen de recomendaciones

| Recomendación | Cantidad | Tablas |
|---------------|----------|--------|
| **CONSERVAR** | 115 | Catálogos, estado dinámico, infraestructura de hardware + T-152/153/154/155 (MVU — ahora en sección ROLES) + 6 tablas D00 (T-156 a T-161) + T-162 `idn_roles_templates` árbol jerárquico compartido de políticas + T-B02L `idn_roles_rol_lifecycle_event` (log WORM ciclo de vida B02) |
| **ELIMINAR** | 48 | T-020, T-021, T-022, T-025, T-026, T-028, T-029, T-030, T-033, T-036, T-037, T-038, T-043, T-044, T-049, T-064, T-065, T-066, T-067, T-068, T-069, T-070, T-074, T-096, T-097, T-099, T-107, T-108, T-109, T-115, T-116, T-117, T-118, T-119, T-120, T-121, T-122, T-123, T-126, T-127, T-129, T-130, T-131, T-132, T-133, T-134, T-144, T-145 |

> **Columna Decisión** = del humano. · **Columna Recomendación** = del agente basada en el árbol RolTemplate v6.0, el principio rector de tabla jerárquica, el manual 5.01 (Auditoría) y el manual 1.13 (MVU).

### Clasificación por clase de información (MVU 1.13 §7)

| Clase | Tablas representativas | Tratamiento |
|-------|------------------------|-------------|
| **C1** — Definiciones gobernadas | `idn_role_template`, `idn_roles_templates`, `idn_user_template`, `idn_tenant`, `privilege_atom`, `ath_method` | Motor de Versionado Universal — `ver_history` guarda su historia |
| **C2** — Historia de versiones | `ver_history`, `ver_proposal`, `ver_retention_schedule`, `ver_template_changelog` (en sección ROLES) | WORM + hash-chain + retención §10 del MVU |
| **C3** — Evidencia de auditoría | `aud_event`, `privilege_atom_audit`, `ath_login_attempt` | Hash-chain WORM + particiones + retención 5.01 §9 — **no se versiona: se encadena** |
| **C4** — Estado efímero | `ses_context`, `ath_recovery_challenge`, `qr_challenge_registry` | TTL parametrizado; su rastro relevante ya está en C3 |

---

**Total tablas:** 155 (151 originales + 4 MVU) · **Secciones:** VERSIONADO eliminada — T-152/153/154/155 integradas en ROLES · **Nuevas `[N]`:** 13 (incluye T-162) · **Particiones:** 6 · **Revisión especial `[?]`:** 5
