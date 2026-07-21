# SBOS_db_V2_DDL_MANUAL.md
## Manual Operativo de la Base de Datos — SBOS Identity Platform V2

**Versión:** 2.0.0 · **Fecha:** 2026-07-21  
**Base de datos:** `SBOS_db` · **PostgreSQL:** 18.4 · **UUIDv7:** RFC 9562  
**Estándar de documentación:** ISO/IEC 11179 · DAMA DMBOK v2 · ISO 24760-2:2025

---

## Índice de Secciones

| Sección | Tablas | Descripción |
|---------|--------|-------------|
| [S1 — Global](#s1--catálogos-globales-bglobal) | T-001..T-004, T-059, T-060, T-061, T-114 | Catálogos ISO compartidos |
| [S2 — Tenant](#s2--infraestructura-tenant-bauth) | T-005..T-011, T-013 | Multi-tenancy base |
| [S3 — Calendario](#s3--calendario-bcalendar) | T-012, T-014..T-019, T-124, T-125 | Calendario fiscal y turnos |
| [S4 — Roles](#s4--roles-bauth) | T-040, T-041, T-042, T-063 | Catálogo y jerarquía de roles |
| [S5 — Versionado](#s5--versionado-bauth) | T-152..T-155 | Temporal constraints PG18 |
| [S6 — Árbol de políticas](#s6--árbol-de-políticas-bauth) | T-162, T-163, T-174, T-175 | XACML/RBAC N3 PAP |
| [S7 — Identidad D00](#s7--identidad-d00-bauth) | T-156..T-161 | Jerarquía de entidades + NHI |
| [S8 — Privilegios](#s8--privilegios-bauth) | T-170..T-172, T-176, T-179 | Grants, overrides, SoD |
| [S9 — Sesión](#s9--sesión-bauth) | T-181, T-191..T-193 | Sesiones activas + CAEP + SSF |
| [S10 — Auditoría](#s10--auditoría-access-review-bauth) | T-177, T-178 | Campañas de revisión |
| [S11 — Riesgo / ITDR](#s11--riesgo--itdr-bauth) | T-180 | Identity Threat Detection |
| [S12 — PAM](#s12--pam-privileged-access-management-bauth) | T-182..T-185, T-189 | JIT, Break-glass, Vault |

---

## Convenciones de este manual

| Símbolo | Significado |
|---------|-------------|
| 🔑 PK | Clave primaria (UUIDv7) |
| 🔗 FK | Clave foránea |
| 🔒 WORM | Append-only · REVOKE UPDATE/DELETE |
| 📦 PART | Tabla particionada por mes |
| 🌱 SEED | Tabla con datos semilla en la DDL |
| ⚡ TRIGGER | Lógica automática en INSERT/UPDATE |
| 🔄 REPLICA | REPLICA IDENTITY FULL para WAL/CDC |

---

## S1 — Catálogos Globales (bglobal)

### T-001 · `bglobal.global_language`

**Propósito:** Catálogo canónico de idiomas. Fuente única de verdad de todos los locales BCP 47 del ecosistema SBOS. Evita que cada daemon mantenga su propia lista de idiomas y garantiza coherencia en bi18n.

**¿Qué registra?** Un idioma por fila: código BCP 47, familia ISO 639-1/2/3, script IANA, dirección de texto, estado de activación.

**¿Cuándo se alimenta?** Una sola vez, durante el bootstrap del sistema (migración de datos). Actualizaciones puntuales cuando IANA publica nuevas subetiquetas (infrecuente).

**Relaciones:**
- `idn_tenant_languages.locale` → FK a `global_language.locale`
- `idn_tenant_config.locale_default` referencia el locale
- bi18n daemon consume esta tabla como catálogo base

**Procesos necesarios:**
- Job de sincronización anual con IANA Language Subtag Registry
- bi18n service lo consulta en cache caliente (Redis, TTL 24h)

**¿Necesita interfaz en el frontend?** Sí — selector de idioma en configuración de tenant. El frontend carga solo `WHERE is_active = true` via API bi18n.

**Dependencias:** Ninguna (tabla raíz sin FKs entrantes de schema).

---

### T-002 · `bglobal.global_country`

**Propósito:** Catálogo ISO 3166-1 de países. Referenciado por monedas, zonas horarias, y configuración regional de tenant.

**¿Qué registra?** Código alpha-2, alpha-3, numérico; nombre multi-locale (JSONB CLDR); región/subregión UN M.49; prefijo telefónico; TLD; moneda y zona horaria principal.

**¿Cuándo se alimenta?** Bootstrap. Actualizaciones anuales cuando ISO 3166 cambia (cambios de nombre de país, nuevos países).

**Relaciones:**
- `global_currency.country_id` → FK
- `idn_tenant.country` → código alpha-2

**¿Necesita interfaz en el frontend?** Sí — selector de país en registro de tenant, formularios de dirección.

---

### T-003 · `bglobal.global_currency`

**Propósito:** Catálogo ISO 4217 de monedas. Fuente única de códigos de moneda, símbolo, decimales, y tasa de cambio vs moneda funcional.

**¿Qué registra?** Código ISO, nombre multi-locale, símbolo, número de decimales, país emisor, monedas retiradas (withdrawn_at), criptomonedas (is_cryptocurrency=true).

**¿Cuándo se alimenta?** Bootstrap. Bolivia usa BOB (Boliviano) + USD. El banco central (BCB) alimenta exchange_rate diariamente via job.

**Relaciones:**
- `idn_tenant_currencies.currency_code` → FK NATURAL KEY
- `idn_tenant_config.currency_default` referencia el código

**Procesos necesarios:**
- Job diario de sincronización de tipo de cambio con BCB API (bcb.gob.bo/api/)
- biedata puede ser el puente que ejecuta este job (JSON-RPC)

**¿Necesita interfaz en el frontend?** Sí — configuración de monedas del tenant, reportes financieros.

---

### T-004 · `bglobal.geo_timezone`

**Propósito:** Catálogo IANA TZ Database de zonas horarias. Crítico para calendario, validez temporal de roles y evaluación de horarios de acceso.

**¿Qué registra?** Identificador IANA (America/La_Paz), offset UTC en texto y en minutos (para aritmética), observancia DST, ciudad principal.

**¿Cuándo se alimenta?** Bootstrap. IANA publica actualizaciones varias veces al año (cambios de DST, renombramientos). Job de actualización automática.

**Relaciones:**
- `idn_tenant_config.timezone_default` referencia timezone_id
- `bcalendar.cal_calendar.timezone` referencia timezone_id

**Código:** El Motor de Identidad (D00) usa `utc_offset_min` para aritmética temporal al evaluar condiciones D3/D4 del árbol de políticas.

**¿Necesita interfaz en el frontend?** Sí — selector de zona horaria en configuración de tenant.

---

### T-059 · `bglobal.menu_item`

**Propósito:** Árbol de ítems de menú del dashboard bAuth. Define la navegación del frontend con soporte multi-idioma (JSONB).

**¿Qué registra?** Código único del ítem (dashboard.home, iam.roles.list), label JSONB multi-idioma, ruta frontend, profundidad en el árbol, icono.

**¿Cuándo se alimenta?** Bootstrap del sistema + al agregar nuevas funciones al dashboard. Nunca eliminación — solo is_active=false.

**Relaciones:**
- `privilege_menu_atom(item_id)` — liga el ítem con el átomo de privilegio que lo protege
- `menu_item_context` — liga el ítem con sus contextos de aparición (N:M)
- `parent_id` → auto-referencia (árbol de adyacencia)

**Procesos necesarios:**
- Al crear un nuevo ítem, el administrador DEBE agregar la ligadura en `privilege_menu_atom` para que el PEP de menú lo controle.

**Código:** El frontend consulta el árbol via API `bauth.menu.build` (JSON-RPC) que devuelve solo los ítems con PERMIT en el BitmaskBundle del usuario.

**¿Necesita interfaz en el frontend?** Sí — configurador de menú para administradores del sistema.

---

### T-060 · `bglobal.menu_context`

**Propósito:** Catálogo de contextos de menú (sidebar, toolbar, contextual, quick-actions). Define en qué parte de la UI puede aparecer un ítem.

**¿Qué registra?** Código del contexto, nombre JSONB, tipo de menú (HIERARCHICAL, CONTEXTUAL).

**¿Cuándo se alimenta?** Bootstrap. Raramente cambia — los contextos son estructurales.

**Relaciones:**
- `menu_item_context` — tabla N:M con menu_item

---

### T-061 · `bglobal.menu_item_context`

**Propósito:** Tabla de asociación N:M entre ítems de menú y sus contextos. Un ítem puede aparecer en sidebar Y en quick-actions con sort_order diferente por contexto.

**¿Cuándo se alimenta?** Al registrar o mover ítems de menú entre contextos.

---

### T-114 · `bglobal.global_config`

**Propósito:** Parámetros globales del sistema. Es el **piso** del PIP `@bauth_config_param.*` en el árbol de políticas: si un tenant no tiene el parámetro en `idn_tenant_config.params_policy`, el Motor de Identidad (PDP) cae aquí.

**¿Qué registra?** `param_key` → `param_value`. Aproximadamente 20 parámetros del sistema (A.48): `max_sessions`, `loa_default`, `argon2id_t`, `session_ttl_max`, `mfa_grace_minutes`, etc.

**¿Cuándo se alimenta?** Bootstrap. Solo el administrador SBOS puede modificar estos parámetros (no los tenants).

**Relaciones:**
- `idn_tenant_config.params_policy` → JSONB que puede sobrescribir cada parámetro de global_config para un tenant específico

**Procesos necesarios:**
- Al evaluar `@bauth_config_param.<clave>` en el árbol T-162, el Motor de Identidad:
  1. Busca en `idn_tenant_config.params_policy->>clave` del tenant actual
  2. Si no encuentra → consulta aquí
  3. `is_overridable=false` = el tenant no puede sobrescribir (piso de seguridad)

**Código:** La función PIP del Motor de Identidad: `pip_resolve_config_param(tenant_id, key)`.

**¿Necesita interfaz en el frontend?** Sí — panel de configuración global para administradores SBOS (solo visibles para tier SU/T0).

---

## S2 — Infraestructura Tenant (bauth)

### T-005 · `bauth.idn_tenant`

**Propósito:** Ancla de gobernanza del sistema. TODA FK en la DDL arranca desde `tenant_id`. Sin una fila aquí, ningún recurso puede existir. Es el primer registro que se crea al provisionar un nuevo cliente.

**¿Qué registra?** Identidad legal del tenant, estado del ciclo de vida (7 estados: PENDING_VERIFICATION → ACTIVE → SUSPENDED → MAINTENANCE → SOFT_DELETED → TERMINATED → PURGED), datos legales de Bolivia (tax_id, número de registro), configuración de seguridad base (mfa_required, session_ttl_max, isolation_level), datos de suscripción y plan.

**REPARACIONES vs sbos_00 (ADR-010):**
- ✗ Eliminados: `realm_kc`, `realm_kc_ext` — Keycloak eliminado
- ✗ Eliminados: `namespace_k8s` — K8s es infra de BOS, no de bauth
- ✗ Eliminados: `database_name`, `database_schema` — infra BOS
- ✗ Eliminados: `kong_consumer_id` — Kong PEP config es BOS
- ✓ Agregado: `vault_path` — única referencia de infra que bauth conserva (Vault PKI es nativo)

**¿Cuándo se alimenta?** El daemon BOS (IAM Installer) crea la fila al registrar un nuevo tenant via `bos.tenant.provision` JSON-RPC.

**Relaciones (20+ FKs entrantes):**
- `idn_tenant_currencies`, `idn_tenant_languages`, `idn_tenant_verification`, `idn_tenant_config`, `idn_tenant_domain`, `idn_tenant_network` (config del tenant)
- `idn_roles_rol_hierarchical`, `idn_identidad_entidad` (identidades del tenant)
- `privilege_atom_grant`, `pam_jit_request`, `pam_breakglass_request` (PAM)
- `aud_access_review_campaign`, `risk_score_event` (auditoría/riesgo)
- Todas las tablas bcalendar con `tenant_id`

**Procesos necesarios:**
- BOS Saga de instalación: crea idn_tenant → idn_tenant_config → idn_tenant_verification → idn_roles_rol_tier defaults → idn_roles_template membresía inicial
- Job de purga: `WHERE status = 'TERMINATED' AND purge_after < NOW()` → PURGE y anonimización GDPR

**Código:** Usado en toda query que filtra por tenant. Siempre incluir `tenant_id` en WHERE (RLS Row Level Security en producción).

**¿Necesita interfaz en el frontend?** Sí — panel de administración de tenants para SU/T0.

---

### T-006 · `bauth.idn_tenant_currencies`

**Propósito:** Habilita las monedas que el tenant puede operar. Un tenant boliviano opera con BOB (default) y puede habilitar USD, EUR para operaciones internacionales.

**¿Qué registra?** Moneda habilitada + si es default + tasa de cambio vs moneda funcional + fuente de la tasa (BCB, ECB, MANUAL).

**¿Cuándo se alimenta?** Al registrar el tenant (BOS Saga). Actualizaciones de tasa de cambio: job diario automatizado.

**Procesos necesarios:**
- Job diario: `UPDATE idn_tenant_currencies SET exchange_rate = <BCB_API_RATE>, exchange_updated_at = NOW() WHERE exchange_source = 'BCB'`

**¿Necesita interfaz en el frontend?** Sí — sección "Monedas" en configuración del tenant.

---

### T-007 · `bauth.idn_tenant_languages`

**Propósito:** Idiomas habilitados por tenant. Permite que SBOS genere documentos, notificaciones y UI en los idiomas que el tenant soporta.

**¿Qué registra?** Locale BCP 47, si es default, proveedor de traducción (sbos_i18n, external_api), estado de completitud de la traducción.

**¿Cuándo se alimenta?** Al registrar el tenant. Los tenants bolivianos inician con es-BO (default) + qu-BO (quechua) + ay-BO (aymara).

**¿Necesita interfaz en el frontend?** Sí — sección "Idiomas" en configuración.

---

### T-008 · `bauth.idn_tenant_verification`

**Propósito:** Proceso KYC/IAL del tenant. 5 pasos secuenciales que determinan el nivel IAL del tenant (IAL1=solo declara, IAL2=verificado remotamente, IAL3=verificado presencialmente).

**¿Qué registra?** Un fila por paso por tenant (UNIQUE tenant_id, step). Estado (PENDING/IN_PROGRESS/PASSED/FAILED), evidencia en JSONB, nivel IAL alcanzado, vencimiento de documentos.

**¿Cuándo se alimenta?** Al registrar el tenant (paso IDENTITY_CHECK automático). Los demás pasos los ejecuta el equipo de onboarding SBOS.

**Procesos necesarios:**
- Job de alerta: `WHERE expires_at < NOW() + INTERVAL '30 days'` → notificar vía bNotify que los documentos de verificación están por vencer
- Al completar FINAL_APPROVAL: actualizar `idn_tenant.status = 'ACTIVE'` y `verified_at = NOW()`

**¿Necesita interfaz en el frontend?** Sí — panel de onboarding para el equipo SBOS y checklist de verificación visible al tenant.

---

### T-009 · `bauth.idn_tenant_config`

**Propósito:** Configuración regional del tenant (idioma, zona horaria, moneda, calendario) + parámetros PIP del árbol de políticas. Relación 1:1 con idn_tenant.

**¿Qué registra?** Locale/timezone/moneda default en JSONB (snapshots listos para serializar). Formato de fecha/hora/número. Configuración del calendario fiscal. Parámetros de política (`params_policy` JSONB) que sobrescriben `global_config` para este tenant.

**¿Cuándo se alimenta?** Automáticamente al crear idn_tenant (BOS Saga). El administrador del tenant puede actualizar via `bauth.tenant.config.update`.

**Relaciones:**
- `bglobal.global_language` (via locale_default)
- `bglobal.geo_timezone` (via timezone_default)
- `bglobal.global_currency` (via currency_default)
- `bglobal.global_config` (piso de params_policy)

**Código crítico:** `params_policy` es el primer lugar donde el PIP busca `@bauth_config_param.<clave>`:

```rust
// Motor de Identidad — PIP resolver
async fn pip_config_param(tenant_id: Uuid, key: &str) -> Option<String> {
    // 1. Buscar en idn_tenant_config.params_policy del tenant
    let tenant_val = db.query_opt("SELECT params_policy->>$1 FROM bauth.idn_tenant_config WHERE tenant_id=$2", &[&key, &tenant_id]).await?;
    if let Some(v) = tenant_val { return Some(v); }
    // 2. Fallback: global_config (piso del sistema)
    db.query_opt("SELECT param_value FROM bglobal.global_config WHERE param_key=$1", &[&key]).await
}
```

**¿Necesita interfaz en el frontend?** Sí — "Configuración regional" y "Parámetros de política" en el panel del tenant.

---

### T-010 · `bauth.idn_tenant_domain`

**Propósito:** Dominios DNS del tenant. El dominio primary es la capa 1 del `ctx_id` (SBOS-049). Registra configuraciones de DNS, SSL, CORS y email por dominio.

**REPARACIONES vs sbos_00:**
- ✗ Eliminados: `nginx_config`, `k8s_hpa_config`, `health_config` — infra BOS, no bauth
- ✓ Agregado: `ctx_prefix TEXT` — segmento del ctx_id aportado por este dominio (skull.sbos.bo)

**¿Qué registra?** FQDN único, tipo de dominio (WEB/API/POS/ADMIN/PORTAL), estado de deployment y health, configuraciones en JSONB (dns_config, ssl_config, security_config, redirect_config, email_config, contacts).

**¿Cuándo se alimenta?** Al registrar el tenant. Puede agregarse más dominios (ej: API separado de portal web).

**Procesos necesarios:**
- Verificación DNS: job que valida periódicamente que el dominio resuelve correctamente
- Rotación SSL: trigger via ACME/Let's Encrypt 30 días antes de expirar

**Código:** El `ctx_prefix` se usa al construir el `ctx_id` (SBOS-049 capa 1): `ctx_id = {ctx_prefix}.{session_id}.{operation_id}.{correlation_id}.{user_id}.{timestamp}`.

**¿Necesita interfaz en el frontend?** Sí — sección "Dominios" del panel del tenant.

---

### T-011 · `bauth.idn_tenant_network`

**Propósito:** Redes CIDR autorizadas por tenant para Zero Trust (NIST 800-207). El PEP verifica que el IP del request esté en al menos un CIDR activo del tenant.

**¿Qué registra?** Nombre descriptivo, tipo de red (LAN/WAN/VPN/DMZ/GUEST/MANAGEMENT), CIDR (tipo nativo PG), gateway, DNS servers, VLAN.

**¿Cuándo se alimenta?** Al registrar el tenant (red LAN del cliente). El CTO del cliente registra sus redes adicionales.

**Procesos necesarios:**
- El Motor de Identidad valida: `SELECT 1 FROM idn_tenant_network WHERE tenant_id=$1 AND cidr >>= $2::inet AND is_active=true`
- {} en `allowed_ip_ranges` de idn_tenant = sin restricción de red

**¿Necesita interfaz en el frontend?** Sí — sección "Redes" para administradores T1/BIZ_N1.

---

### T-013 · `bauth.idn_calendar_assignment`

**Propósito:** Puente entre entidades bauth y calendarios bcalendar. Implementa herencia jerárquica: el tenant asigna un calendario, las empresas lo heredan, las sucursales lo heredan.

**REPARACIÓN vs sbos_00:** calendar_id ahora tiene FK real a `bcalendar.cal_calendar` (antes era UUID huérfano sin constraint).

**¿Qué registra?** (calendar_id, owner_type, owner_id) UNIQUE. Role: OWNER puede gestionar, EDITOR modifica eventos, VIEWER solo lee.

**¿Cuándo se alimenta?** Al crear un tenant/empresa/sucursal, BOS Saga crea la asignación del calendario fiscal correspondiente.

---

## S3 — Calendario (bcalendar)

### T-012 · `bcalendar.cal_fiscal_year`

**Propósito:** Gestión de años fiscales con 12 períodos mensuales. Soporta multi-gestión (corriente + anteriores simultáneas). Crítico para facturación SIN y reportes NIC/IAS.

**¿Qué registra?** Año fiscal (entero), estado (OPEN/CLOSED/CLOSED_WITH_ADJUSTMENTS/ARCHIVED), fecha de inicio, 12 períodos JSONB con estado individual, si es la gestión corriente.

**¿Cuándo se alimenta?** BOS Saga al crear el tenant. El módulo de contabilidad crea la gestión del año siguiente antes del cierre.

**Relaciones:** `tenant_id` + `company_id` (opcional, para empresas subsidiarias del tenant)

**Procesos necesarios:**
- Job de cierre automático a fin de año (configurable: día/mes de cierre fiscal Bolivia = 31-12)
- Validación: solo UN año con `is_current=true` por (tenant, company)
- Los módulos contables validan `WHERE status='OPEN' AND is_current=true` antes de registrar transacciones

**Código:** El árbol de políticas D5/D6 (fiscal) consulta esta tabla para determinar si el período contable está abierto.

**¿Necesita interfaz en el frontend?** Sí — módulo de gestión fiscal, dashboard de cierre de año.

---

### T-014 · `bcalendar.cal_calendar`

**Propósito:** Colecciones de calendarios por tenant. Un calendario agrupa eventos, alarmas y horarios del mismo tipo (WORK, FISCAL, PROCESS, COMPLIANCE, HOLIDAY, MAINTENANCE).

**¿Qué registra?** Nombre, tipo, zona horaria IANA, color para UI, si es de sistema (no borrable).

**¿Cuándo se alimenta?** Bootstrap (calendarios de sistema predefinidos). Los administradores crean calendarios adicionales.

**Procesos necesarios:**
- Al crear tenant: seed de calendarios base (Calendario Laboral Bolivia, Calendario Fiscal, Calendario de Compliance)

**¿Necesita interfaz en el frontend?** Sí — vista de calendarios del tenant, selector de calendario.

---

### T-015 · `bcalendar.cal_event`

**Propósito:** Eventos maestros con soporte de recurrencia RFC 5545. Una fila = un evento o una serie recurrente completa. Las ocurrencias se expanden on-demand.

**¿Qué registra?** Título, fechas, regla de recurrencia (rrule TEXT RFC 5545), fechas excluidas (exdate[]), duración, estado (CONFIRMED/TENTATIVE/CANCELLED).

**¿Cuándo se alimenta?** Cuando un administrador o el sistema crea eventos (feriados, cierres, vencimientos).

**Código:** El evaluador D3 temporal del árbol de políticas consulta eventos para determinar si un acceso cae en un período controlado.

**¿Necesita interfaz en el frontend?** Sí — vista de calendario tipo Google Calendar.

---

### T-016 · `bcalendar.cal_alarm`

**Propósito:** Alarmas asociadas a eventos. Define cuándo y por qué canal bNotify envía la notificación.

**¿Qué registra?** `trigger_seconds` (negativo = antes del evento), canal (EMAIL/SMS/WHATSAPP/PUSH/CHAT/UI), template, receptor, próximo disparo.

**Procesos necesarios:**
- Job polling: `WHERE next_trigger_at <= NOW() AND is_active = true`
- Al disparar: insertar en `cal_notification_log` + llamar a bNotify via JSON-RPC

---

### T-017 · `bcalendar.cal_notification_log` 🔒 WORM

**Propósito:** Registro inmutable de notificaciones enviadas. Evidencia de que las alarmas se dispararon (compliance y auditoría).

**¿Cuándo se alimenta?** Automáticamente al disparar cada alarma. No tiene UPDATE/DELETE.

---

### T-018 · `bcalendar.cal_holiday`

**Propósito:** Feriados fijos y móviles por país/tenant. Bolivia tiene 26 feriados nacionales por ley + feriados departamentales. El evaluador D3 consulta esta tabla para horarios laborales reales.

**¿Qué registra?** Nombre del feriado, fecha, si es recurrente anual, país, región (departamento).

**¿Cuándo se alimenta?** Bootstrap (feriados nacionales Bolivia) + administrador de tenant para feriados propios.

**Procesos necesarios:**
- Job anual: cargar feriados móviles del año siguiente (Carnaval, Semana Santa cuyas fechas cambian cada año)

---

### T-019 · `bcalendar.cal_schedule`

**Propósito:** Horarios de trabajo y turnos por tenant. Define ventanas de acceso permitido. El evaluador D3 usa esto para validar si el acceso ocurre en horario laboral.

**¿Qué registra?** Días de la semana ({1=lun..7=dom}), hora de inicio/fin, turnos JSONB (mañana/tarde/noche), comportamiento fuera de horario (BLOCKED/PERMITTED/REQUIRES_APPROVAL).

**¿Cuándo se alimenta?** Al registrar el tenant (horario laboral estándar 8-18 Lun-Vie). Puede personalizarse para turnos especiales.

**Código:** El Motor de Identidad evalúa: `SELECT access_outside_schedule FROM cal_schedule WHERE tenant_id=$1 AND is_default=true`.

**¿Necesita interfaz en el frontend?** Sí — configurador de horarios y turnos.

---

### T-124 · `bcalendar.cal_overtime_policy` ⭐ NUEVA

**Propósito:** Políticas de horas extra. Define si el acceso fuera del horario normal requiere override, qué aprobaciones activa, y qué LoA mínimo exige el PDP.

**¿Qué registra?** Máximo de horas extra diarias/semanales, si requiere solicitud de override y aprobación gerencial, LoA requerido para el override, tiers a los que aplica.

**¿Cuándo se alimenta?** Al registrar el tenant o cuando Recursos Humanos configura la política.

**Relaciones:** `schedule_id` → `cal_schedule` (schedule base al que aplica la política)

**Código:** Cuando el PDP detecta acceso fuera de horario:
1. Consulta `cal_overtime_policy` del tenant/schedule
2. Si `requires_override_request=true` → redirige a flujo JIT (T-182)
3. Si `loa_required_for_override=2` → exige AAL2 antes de aprobar el override

---

### T-125 · `bcalendar.cal_break_policy` ⭐ NUEVA

**Propósito:** Políticas de pausa (almuerzo, descanso). Define si el sistema suspende sesiones activas durante el break y si el usuario debe re-autenticarse al volver.

**¿Qué registra?** Ventana de pausa (start/end TIME), si suspende sesiones, si permite reanudar, si re-autenticación es requerida, tiers a los que aplica.

**¿Cuándo se alimenta?** Al registrar el tenant. El horario de almuerzo (12:00-14:00) es el caso más común.

**Procesos necesarios:**
- Job al inicio del break: `UPDATE idn_sesion_activa SET is_active=false WHERE user_id IN (usuarios del tenant en pausa) AND is_active=true` (si `suspend_active_sessions=true`)
- Evento CAEP: `session_revoked` para notificar al frontend via SSF

---

## S4 — Roles (bauth)

### T-040 · `bauth.idn_roles_rol_type` 🌱

**Propósito:** Catálogo cerrado de 10 tipos de cuenta. Permite que el sistema aplique políticas diferenciadas según si la identidad es humana (INDIVIDUAL), no-humana (BOT, DEVICE, SERVICE), de emergencia (EMERGENCY), etc.

**¿Qué registra?** Code único, nombre JSONB. Inmutable una vez creado (historicidad).

**¿Cuándo se alimenta?** Bootstrap. Los 10 tipos vienen en los SEEDs de la DDL. No se agregan tipos nuevos sin análisis de impacto en el PDP.

**Relaciones:**
- `idn_roles_rol_hierarchical.type_id` → FK
- El PDP aplica reglas distintas por tipo (ej: EMERGENCY siempre requiere quórum T-183)

**¿Necesita interfaz en el frontend?** Solo lectura — selector al crear un rol.

---

### T-042 · `bauth.idn_roles_rol_tier` 🌱

**Propósito:** Parámetros de seguridad por tier. 11 tiers con niveles de aseguramiento, timeouts de sesión, MFA obligatorio y límites de sesiones concurrentes distintos.

**¿Qué registra?** Por tier: LoA requerido (AAL1/2/3), session_timeout_minutes, max_sessions, step_up_loa, si MFA es obligatorio, métodos MFA permitidos.

**¿Cuándo se alimenta?** Bootstrap. Los 11 tiers vienen en los SEEDs. SU requiere LoA3+MFA con solo 1 sesión concurrente. VISITANTE requiere LoA1 con 30 minutos de timeout.

**Código:** Al emitir el JWT, el Motor de Identidad consulta el tier del rol activo para establecer el `exp` (expiración) del token.

---

### T-041 · `bauth.idn_roles_rol_hierarchical`

**Propósito:** Árbol de roles por tenant (adjacency list). Es el catálogo de roles empresariales: 368 roles en 7 tiers, 66 plantillas base, 21 sectores CAEB. Complementado por T-063 (closure table) para herencia DAG-OR eficiente.

**¿Qué registra?** Rol con su tier, tipo, código único por tenant, nombre JSONB, profundidad, estado (ACTIVE/INACTIVE/DEPRECATED/ARCHIVED/SUSPENDED), sector CAEB, versión, referencia a nodo en el árbol de políticas (template_id).

**¿Cuándo se alimenta?** Al registrar el tenant, BOS Saga crea los roles base según el sector CAEB del cliente. El administrador crea roles adicionales.

**Relaciones:**
- `parent_id` → auto-referencia (nodo padre en la jerarquía)
- `type_id` → T-040 (tipo de cuenta)
- `template_id` → T-162 (nodo DOMAIN del árbol de políticas) — DEFERRABLE INITIALLY DEFERRED
- `idn_roles_rol_closure` → closure table de herencia

**¿Necesita interfaz en el frontend?** Sí — visor del árbol de roles con drag-and-drop. Es una de las interfaces más complejas del dashboard bAuth.

---

### T-063 · `bauth.idn_roles_rol_closure`

**Propósito:** Closure table del DAG de herencia de roles (OR-inheritance: un rol hereda los privilegios de TODOS sus ancestros). Permite consultas O(1) de ancestros y descendientes.

**¿Qué registra?** Tripleta (ancestor_id, descendant_id, depth). depth=0 = rol es ancestro de sí mismo. depth=1 = hijo directo. depth=N = N niveles de herencia transitiva.

**¿Cuándo se alimenta?** Por triggers en idn_roles_rol_hierarchical al insertar o cambiar parent_id. Nunca manualmente.

**Procesos necesarios:**
- Trigger `trg_irrh_closure_insert`: al insertar un rol, inserta las tripletas de reflexividad + herencia transitiva
- Trigger `trg_irrh_closure_update_parent`: al cambiar parent_id, recalcula toda la subárbol

**Código:** El PrivilegeEngine usa esta tabla para compilar el BitmaskBundle:

```sql
-- Todos los roles heredados por un usuario via DAG-OR
SELECT rc.ancestor_id
FROM idn_roles_rol_closure rc
WHERE rc.descendant_id = $user_role_id
  AND EXISTS (
    SELECT 1 FROM idn_roles_rol_hierarchical r
    WHERE r.id = rc.ancestor_id AND r.is_inheritable = true AND r.status = 'ACTIVE'
  );
```

**¿Necesita interfaz en el frontend?** No — solo la lógica interna del PrivilegeEngine la accede directamente.

---

## S5 — Versionado (bauth)

### T-152 · `bauth.idn_rol_version`

**Propósito:** Versiones temporales de roles con constraint de no-solapamiento (`EXCLUDE USING GIST`). Permite auditar qué versión de un rol estaba activa en cualquier momento histórico.

**¿Qué registra?** `(role_id, valid_range)` con exclusión: no pueden existir dos versiones del mismo rol con rangos de fecha superpuestos. `snapshot` contiene el estado completo del rol en JSONB.

**¿Cuándo se alimenta?** Automáticamente por trigger al modificar un rol en `idn_roles_rol_hierarchical`.

**Código crítico:** La constraint `EXCLUDE USING GIST (role_id WITH =, valid_range WITH &&)` es el WITHOUT OVERLAPS de PG18: garantiza integridad temporal a nivel de base de datos.

---

### T-153 · `bauth.idn_policy_version`

**Propósito:** Versiones temporales de nodos del árbol de políticas T-162. Base de forensia: qué regla estaba activa al momento de un incidente de seguridad.

**¿Cuándo se alimenta?** Por trigger al modificar nodos en `idn_roles_template`. El proceso pasa primero por `pam_tree_change_proposal` (T-189) con quórum.

---

### T-154 · `bauth.idn_rol_assignment_version`

**Propósito:** Versiones de asignaciones de rol a usuario. Garantiza que un usuario no pueda tener el mismo rol asignado dos veces con rangos de tiempo superpuestos.

**¿Qué registra?** (user_id, role_id, valid_range) con exclusión GIST. `grant_type`: STANDARD/JIT/BREAKGLASS.

**¿Cuándo se alimenta?** Al asignar o revocar un rol a un usuario.

**Código:** Base de reportes de "¿qué roles tenía este usuario el día X?" para auditorías NIST AC-2(7).

---

### T-155 · `bauth.idn_privilege_version`

**Propósito:** Snapshots versionados del BitmaskBundle compilado por el PrivilegeEngine para cada usuario. Permite reconstruir los privilegios exactos de un usuario en cualquier momento histórico.

**¿Qué registra?** `bitmask_bundle` JSONB: `{D01:"0x...", D02:"0x...", ..., D12:"0x..."}`. Un int64 por dominio representa el OR de todos los átomos activos del usuario en ese dominio.

**¿Cuándo se alimenta?** Cada vez que el PrivilegeEngine recompila el bundle de un usuario (cambio de rol, cambio de grant, CAEP event).

**Código:** `is_current=true` = versión en Redis. Al revocar, el bundle anterior queda archivado con `valid_until` = timestamp de la revocación.

---

## S6 — Árbol de Políticas (bauth)

### T-174 · `bauth.privilege_verb`

**Propósito:** Catálogo de verbos atómicos del sistema. Un verbo = una acción elemental controlada por el PDP (READ, WRITE, DELETE, APPROVE, SIGN, EXPORT, AUDIT_VIEW, ADMIN_CONFIG).

**¿Qué registra?** `code` único, nombre JSONB, estado de activación. Los verbos nunca se eliminan — se desactivan para mantener trazabilidad histórica.

**¿Cuándo se alimenta?** Bootstrap. Los verbos base vienen de la especificación de dominios D01..D37.

**¿Necesita interfaz en el frontend?** Solo lectura — visible al configurar átomos en el árbol.

---

### T-175 · `bauth.privilege_verb_conflict`

**Propósito:** Matriz SoD (Separation of Duties). Define pares de verbos que no pueden coexistir en el mismo usuario. Garantiza separación de funciones NIST AC-5 / ISO 27001 A.6.1.2.

**¿Qué registra?** Par (verb_a_id, verb_b_id) con tipo de conflicto:
- `SOD_ESTATICO`: prohibición permanente (ej: APPROVE + SIGN del mismo documento)
- `SOD_DINAMICO`: prohibición solo si ambos activos en la misma sesión (ej: AUDIT_VIEW + DELETE)
- `AFINIDAD`: los verbos se complementan (requerimiento conjunto, no conflicto)

La constraint `chk_pvc_order (verb_a_id < verb_b_id)` elimina duplicados (A,B) = (B,A).

**Procesos necesarios:**
- El PDP consulta esta tabla al compilar el BitmaskBundle para detectar conflictos SoD antes de emitir el JWT
- Las excepciones SoD aprobadas viven en `privilege_sod_exception` (T-176)

---

### T-162 · `bauth.idn_roles_template` ⚡ TRIGGER

**Propósito:** El árbol de políticas compartido del sistema bAuth. UN solo árbol (sin tenant_id). Es el PAP (Policy Administration Point) del XACML 3.0: define qué permisos existen, cómo se estructuran, y qué condiciones AtomLang los rigen.

**¿Qué registra?** Nodos del árbol jerárquico DOMAIN > BLOCK > POLICY > MODULE > EVALUATION > ATOM/OBLIGATION:
- `DOMAIN`: raíz de un dominio de control (D01..D37). Tiene `domain_number`.
- `BLOCK`: agrupación dentro del dominio (B1, B2, etc.)
- `POLICY`: política específica (P-AUTH-001)
- `MODULE`: módulo funcional dentro de una política
- `EVALUATION`: átomo evaluable. **Solo estos nodos tienen `atom_position`** (posición de bit en el BitMask 64-bit)
- `ATOM`: sub-átomo de un EVALUATION
- `OBLIGATION`: acción obligatoria al aplicar el efecto

**El trigger `trg_irt_atom_position`** asigna automáticamente `atom_position` desde `roles_atom_position_seq` a cada nodo EVALUATION en INSERT. La posición es inmutable una vez asignada.

**¿Qué es `atom_position`?** Es la posición del bit en el BitMask 64-bit del dominio correspondiente. El PrivilegeEngine compila el BitmaskBundle: para cada usuario, hace OR de los atom_position de todos los EVALUATION que tiene PERMIT → resultado es un int64 por dominio. Evaluación: `bitmask & (1 << atom_position) != 0` → en < 0.5ns.

**¿Cuándo se alimenta?** Por el PAP (administrador de políticas SBOS) mediante propuestas con quórum (T-189). Nunca directamente.

**`condition_expr`:** JSON AST de la condición AtomLang compilada. Ejemplo: `{"op":"AND","left":{"ref":"@current_time","op":"BETWEEN","range":["08:00","18:00"]},"right":{"ref":"@tenant.status","op":"EQ","val":"ACTIVE"}}`.

**`path`:** Camino materializado único: `D01.B1.P001.E001`. Permite lookup directo O(1).

**¿Necesita interfaz en el frontend?** Sí — visor del árbol de políticas (solo lectura para BIZ_N1+, edición para T0/SU con quórum).

---

### T-163 · `bauth.idn_roles_template_audit` 🔒 WORM

**Propósito:** Registro inmutable de cambios al árbol de políticas. Todo INSERT, UPDATE o DEACTIVATE en T-162 queda registrado aquí con hash-chain SHA-256.

**¿Cuándo se alimenta?** Por trigger en `idn_roles_template`. No tiene UPDATE/DELETE.

**Código hash-chain:** `SHA-256(prev_hash || node_id || operation || JSONB(new_data) || created_at::text)`. El primer evento tiene `prev_hash = '000...0'`.

---

## S7 — Identidad D00 (bauth)

### T-156 · `bauth.idn_identidad_entidad`

**Propósito:** Raíz del modelo D00 de identidad. Toda identidad en SBOS es una entidad aquí. La jerarquía de 5 niveles modela la estructura organizacional de cualquier empresa boliviana.

**¿Qué registra?** Entidad con su nivel (tenant/bdomain/bsubdomain/pos/actor), código único por tenant, nombre JSONB, profundidad en el árbol, path materializado, IAL mínimo requerido.

**Jerarquía D00:**
- `tenant`: el tenant SBOS (ej: "skull")
- `bdomain`: empresa subsidiaria (ej: "skull-corp")
- `bsubdomain`: sucursal o división (ej: "skull-corp-la-paz")
- `pos`: punto de venta o unidad operativa (ej: "pos-01")
- `actor`: identidad humana o NHI que porta credenciales

**¿Cuándo se alimenta?** BOS Saga al registrar el tenant (crea el nodo tenant). El administrador crea empresas, sucursales, puntos y actores.

**Código:** `user_id` en todas las demás tablas de bauth es el `entidad_id` de un nodo tipo `actor` en esta tabla.

**¿Necesita interfaz en el frontend?** Sí — árbol organizacional con gestión de entidades. Vista más importante del módulo IAM.

---

### T-157 · `bauth.idn_identidad_atributo`

**Propósito:** Atributos de identidad por entidad. Modelo EAV controlado (namespace.key=value). Permite almacenar atributos verificables (cédula de identidad, NIT, biometría) y no verificables (preferencias), con niveles IAL distintos.

**¿Qué registra?** Namespace + clave + valor JSONB + si está verificado + fuente de verificación + vigencia.

**Namespaces:**
- `core`: nombre, CI, fecha de nacimiento
- `professional`: cargo, empresa, sector
- `verification`: documentos IAL2/3
- `security`: dispositivos MFA, IPs de confianza
- `contact`: email, teléfono, dirección
- `fiscal`: NIT, actividad económica CAEB

**Procesos necesarios:**
- Al actualizar un atributo: crear nueva fila con nueva vigencia (no UPDATE del valor)
- IAL2/IAL3: el proceso de verificación marca `verified=true` + `verified_by` + evidencia

**¿Necesita interfaz en el frontend?** Sí — perfil de identidad del actor con secciones por namespace.

---

### T-158 · `bauth.idn_identidad_dominio`

**Propósito:** Registra en qué dominios del árbol de políticas (D01..D37) tiene membresía cada entidad. El DomainRegistry controla a qué subconjunto del árbol de políticas accede cada actor.

**¿Qué registra?** (entidad_id, domain_number) UNIQUE. Tipo de grant (STANDARD/JIT/BREAKGLASS), vigencia.

**Código:** Al compilar el BitmaskBundle, el PrivilegeEngine solo considera dominios donde `idn_identidad_dominio.is_active=true` para el usuario. Los dominios sin membresía tienen BitmaskBundle = 0 (acceso denegado).

---

### T-159 · `bauth.idn_nhi_identity`

**Propósito:** Non-Human Identities (NHI). Registra daemons, pipelines, bots, service accounts, y AI agents que necesitan credenciales para operar en SBOS. Son identidades que no tienen usuario humano detrás.

**¿Qué registra?** Tipo (DAEMON/PIPELINE/BOT/SERVICE_ACCOUNT/AGENT_AI/DEVICE), propietario humano, equipo responsable, período de rotación de credenciales, scopes OAuth, ruta en Vault, score de riesgo ITDR.

**¿Cuándo se alimenta?** Al registrar un nuevo daemon o integración. Ej: al instalar bkernel en un servidor, se crea el NHI `bkernel-s03` con sus scopes WAL.

**Procesos necesarios:**
- Job de rotación: `WHERE next_rotation_at <= NOW() AND status='ACTIVE'` → rotar credencial en Vault y actualizar last/next_rotated_at
- Certificación trimestral: crear campaña de certificación NHI (T-161) cada 90 días
- ITDR: job de scoring que actualiza `risk_score` basado en comportamiento (accesos inusuales, escapes de scope)

---

### T-160 · `bauth.idn_nhi_lifecycle_event` 🔒 WORM

**Propósito:** Ciclo de vida completo de cada NHI. Registro forense inmutable de cada transición de estado.

**¿Cuándo se alimenta?** Por trigger en `idn_nhi_identity` al cambiar status. No tiene UPDATE/DELETE.

---

### T-161 · `bauth.idn_nhi_certification`

**Propósito:** Certificaciones periódicas de NHI. El propietario revisa si el NHI sigue necesitando sus scopes actuales. Obligatorio cada 90 días (NIST AC-2(7)).

**¿Qué registra?** Decisión (CERTIFY/DECOMMISSION/REDUCE_SCOPE), razón, cambios de scope propuestos, vencimiento de la certificación.

---

## S8 — Privilegios (bauth)

### T-170 · `bauth.privilege_atom_grant` 🔄 REPLICA

**Propósito:** Grant de átomos de privilegio **por usuario** (no por rol genérico). Es la tabla central del motor de privilegios: registra qué átomos EVALUATION del árbol de políticas tiene activados cada usuario, con qué efecto (PERMIT/DENY) y de qué tipo (STANDARD/JIT/BREAKGLASS).

`REPLICA IDENTITY FULL`: bkernel-reactor recibe todos los cambios vía WAL/CDC para actualizar el BitmaskBundle en Redis.

---

#### Modelo 5 columnas (G-12)

El corazón de la tabla. Cinco columnas trabajan en conjunto para representar el estado de cada grant y evitar ambigüedades en la evaluación del PDP:

| Columna | Tipo | Semántica |
|---|---|---|
| `effect` | `BOOLEAN NOT NULL DEFAULT false` | Espejo del nodo EVALUATION en T-162. `true`=PERMIT, `false`=DENY. **Nunca editar directamente** — lo sincroniza `trg_t162_sync_effect_to_grants`. |
| `general` | `BOOLEAN NOT NULL DEFAULT true` | Control de precedencia. `true` (valor al crear) → el árbol manda: `effect` prevalece sobre `access`. `false` → el grant manda: `access` prevalece sobre `effect`. |
| `local` | `BOOLEAN GENERATED ALWAYS AS (NOT general) STORED` | Derivado de `general`. Columna calculada por PostgreSQL, solo para legibilidad visual. No tiene lógica propia. |
| `access` | `BOOLEAN NOT NULL DEFAULT true` | Override del operador. Forzado a `true` por trigger cuando `general=true`. Solo es editable con semántica real cuando `general=false`. |
| `reassess` | `BOOLEAN NULL` | Elegibilidad CAEP reactiva. `NULL`=hereda el default del tier del tenant (via `idn_tier_policy`). `true`=elegible para reevaluación. `false`=inmune (siempre en BREAKGLASS). |

**Flujo de decisión del PDP:**

```
¿general = true?
  ├─ SÍ → usa effect   (árbol manda; access está forzado a true por trigger)
  └─ NO → usa access   (grant manda; effect ignorado)

Si access = false (solo posible con general = false):
  └─ reassess = true está BLOQUEADO por chk_pag_reassess_coherencia
```

---

#### Constraint de coherencia

```sql
CONSTRAINT chk_pag_reassess_coherencia CHECK (
    NOT (access = false AND reassess = true)
)
```

Prohíbe la combinación `access=false AND reassess=true`. Un grant que ya está vetado explícitamente por el operador no puede ser candidato a reevaluación CAEP — no tiene sentido reevaluar algo que ya es DENY.

---

#### Índice parcial CAEP/risk (`idx_pag_reassess_eligible`)

```sql
CREATE INDEX IF NOT EXISTS idx_pag_reassess_eligible
    ON bauth.privilege_atom_grant(tenant_id, user_id)
    WHERE reassess = true
      AND status   = 'ACTIVE'
      AND (
          (general = true  AND effect = true)
          OR
          (general = false AND access = true)
      );
```

Cubre únicamente los grants que **están dando acceso efectivo** y son elegibles para reevaluación. El reactor CAEP y el evaluador de riesgo consultan este índice directamente sin escanear la tabla completa.

---

#### Triggers del modelo 5 columnas

**`trg_t162_sync_effect_to_grants`** — propaga `effect` del árbol a los grants

- Dispara: `AFTER UPDATE ON bauth.idn_roles_template`
- Función: `fn_sync_effect_from_tree()`
- Lógica: si el árbol modifica el `effect` de un nodo `tipo=evaluacion`, actualiza `effect` en todos los grants `ACTIVE/SUSPENDED` de ese átomo. Mantiene T-170 sincronizado con T-162 sin JOIN en el PDP.

**`trg_t170_sync_access_general`** — fuerza `access=true` cuando `general=true`

- Dispara: `BEFORE INSERT OR UPDATE ON bauth.privilege_atom_grant`
- Función: `fn_sync_access_to_general()`
- Lógica: si `general=true`, fija `access := true`. Previene que `access=false` aparezca cuando el árbol manda, lo cual sería un DENY visual falso que confundiría al PDP.

**`trg_validate_breakglass_grant`** — valida invariantes D1/D2/D3 en BREAKGLASS (G-20)

- Dispara: `BEFORE INSERT OR UPDATE OF grant_type, status ON bauth.privilege_atom_grant`
- Función: `fn_validate_breakglass_grant()`
- Lógica:
  - **D1** — fuerza `reassess := false` en todo grant BREAKGLASS (inmune a CAEP — RFC 9396)
  - **D2** — verifica que el rol sea de tier `SU` o tipo `EMERGENCY` (NIST AC-2(2)); rechaza con `BREAKGLASS_TIER_VIOLATION` si no cumple
  - **D3** — verifica que el tenant no tenga más de 2 grants BREAKGLASS activos (`ACTIVE` o `INACTIVE`); rechaza con `BREAKGLASS_LIMIT_EXCEEDED` si ya alcanzó el límite

---

#### `grant_type` — tipos de grant

| Valor | Semántica |
|---|---|
| `STANDARD` | Asignación normal por BOS Saga o panel de administración |
| `JIT` | Just-in-time: requiere `pam_jit_request` aprobada (T-182); tiene `valid_until` obligatorio |
| `BREAKGLASS` | Emergencia con dual control; fuerza `reassess=false`; máximo 2 por tenant |

---

#### ¿Cuándo se alimenta?

- **STANDARD**: al asignar un rol a un usuario (BOS Saga o admin panel)
- **JIT**: al aprobar `pam_jit_request` (T-182)
- **BREAKGLASS**: al activar `pam_breakglass_activation` (T-185)

#### Procesos necesarios

- **Job de expiración**: `WHERE valid_until <= NOW() AND status='ACTIVE'` → `UPDATE status='EXPIRED'`
- **CAEP reactor**: al recibir evento CAEP, busca grants con `reassess=true` via `idx_pag_reassess_eligible` y evalúa si revocar
- **bkernel CDC**: cada `INSERT/UPDATE/DELETE` → WAL → Redis actualización del BitmaskBundle

---

### T-170b · `bauth.privilege_atom_audit` 🔒 WORM 📦 PART

**Propósito:** Registro inmutable de cambios en grants con hash-chain SHA-256. Detecta alteración forense de la historia de privilegios.

**¿Cuándo se alimenta?** Por trigger en `privilege_atom_grant` al INSERT/UPDATE/DELETE. Particionada por mes para alta volumetría (millones de cambios/mes en producción).

**Hash-chain:** `SHA-256(prev_audit_hash || grant_id || operation || JSONB(new_data) || created_at)`. Permite detectar si alguien eliminó o modificó un registro de auditoría.

---

### T-171 · `bauth.privilege_override`

**Propósito:** Overrides de efecto de un átomo para un usuario específico. Permite excepciones controladas: DENY_TO_PERMIT (excepción aprobada a una negación) o PERMIT_TO_DENY (restricción adicional a un permiso).

**¿Cuándo se alimenta?** Por el administrador al aprobar una excepción específica documentada. Requiere `approved_by` + `valid_until` obligatorio.

**Código:** El Motor de Identidad aplica overrides DESPUÉS de evaluar el grant base:
1. Evaluar BitmaskBundle (resultado base)
2. Buscar overrides activos para (user_id, atom_id)
3. Si existe DENY_TO_PERMIT → forzar PERMIT aunque el bit esté en 0
4. Si existe PERMIT_TO_DENY → forzar DENY aunque el bit esté en 1

---

### T-172 · `bauth.privilege_assurance_log` 📦 PART

**Propósito:** Log de evaluaciones de aseguramiento del PDP. Cada decisión PERMIT/STEP_UP_REQUIRED/DENIED queda registrada con el LoA presentado vs el LoA requerido. Base del ITDR (T-180) para detectar intentos de acceso con LoA insuficiente.

**¿Cuándo se alimenta?** Por cada evaluación de acceso del Motor de Identidad. Alta volumetría — particionada por mes.

---

### T-176 · `bauth.privilege_sod_exception`

**Propósito:** Excepciones aprobadas a reglas SoD. Cuando el negocio necesita que un usuario tenga dos verbos en conflicto (ej: jefe único en empresa pequeña que debe APPROVE y SIGN), puede solicitarse una excepción con quórum de aprobadores.

**¿Cuándo se alimenta?** Al aprobar una solicitud de excepción SoD (flujo separado). La constraint `chk_pse_quorum` garantiza que `len(approved_by) >= approval_quorum` antes de activar.

**Toda excepción SoD tiene `valid_until` obligatorio.** No existen excepciones permanentes.

---

### T-179 · `bauth.privilege_menu_atom`

**Propósito:** Liga ítems de menú (T-059) con átomos del árbol de políticas (T-162). El PEP de frontend filtra la UI: un ítem es visible si el usuario tiene PERMIT en el atom_id correspondiente según su BitmaskBundle.

**¿Cuándo se alimenta?** Al registrar un nuevo ítem de menú (admin panel). Toda funcionalidad nueva debe estar ligada a un átomo para que quede bajo control del PDP.

**Código (frontend PEP):**
```typescript
// El BitmaskBundle llega en el JWT
const canSee = (itemCode: string): boolean => {
  const menuAtoms = menuAtomMap[itemCode]; // cargado al inicializar
  return menuAtoms.some(atomId => bitmask.hasPermit(atomId));
};
```

---

## S9 — Sesión (bauth)

### T-181 · `bauth.idn_sesion_activa`

**Propósito:** Sesiones activas — proyección de Redis en PostgreSQL para persistencia y auditoría. La fuente operativa de sesiones es Redis (BitmaskBundle + sesión data); esta tabla es el failsafe ante falla de Redis y la fuente de auditoría permanente.

**¿Qué registra?** `session_id`, usuario, tenant, rol activo, LoA, métodos de auth usados, IP, user-agent, JTI del JWT, token hash, fechas de inicio/expiración/última actividad, score de riesgo, step-up válido hasta.

**¿Cuándo se alimenta?** En cada autenticación exitosa. `last_activity_at` se actualiza en cada request autenticado. `step_up_valid_until` se establece al completar step-up RFC 9470.

**Procesos necesarios:**
- Job de limpieza: `WHERE expires_at < NOW() OR revoked_at IS NOT NULL` → archivar en `idn_sesion_audit` y DELETE
- Kong PEP: valida `jti` en Redis (cache caliente) y en esta tabla (fallback)

**¿Necesita interfaz en el frontend?** Sí — "Mis sesiones activas" para el usuario + panel de sesiones para administradores.

---

### T-191 · `bauth.idn_caep_event`

**Propósito:** Eventos CAEP recibidos por bAuth desde sistemas externos o detectados internamente. CAEP (RFC 8935) es el protocolo para comunicar cambios de estado de seguridad en tiempo real.

**¿Qué registra?** Tipo de evento (credential_change, session_revoked, risk_score_change, etc.), payload JSONB, origen, estado de procesamiento, resultado de la acción aplicada.

**¿Cuándo se alimenta?** Cuando bkernel-CDC detecta cambios relevantes (via WAL) o cuando sistemas externos envían señales CAEP. El cliente CAEP de bAuth (commit 409095b) inserta aquí.

**Procesos necesarios:**
- Reactor bAuth: procesa eventos `WHERE processing_status='RECEIVED'` → aplica acción (revocar sesión, exigir step-up, etc.) → actualiza `processing_status='APPLIED'`

---

### T-192 · `bauth.idn_ssf_delivery`

**Propósito:** Entrega de señales SSF (Shared Signals Framework, RFC 8936) a receptores externos. bAuth puede actuar como emisor de señales hacia otros sistemas que necesitan saber de cambios de seguridad.

**¿Cuándo se alimenta?** Cuando un evento CAEP debe notificarse a un receptor SSF registrado. El job de entrega maneja reintentos con backoff exponencial.

---

### T-193 · `bauth.idn_sesion_audit` 🔒 WORM 📦 PART

**Propósito:** Registro inmutable de eventos de sesión: LOGIN, LOGOUT, STEP_UP, REVOKE, IDLE_TIMEOUT. Evidencia forense de todo el ciclo de vida de cada sesión.

**¿Cuándo se alimenta?** Por trigger en `idn_sesion_activa`. Particionada por mes. No tiene UPDATE/DELETE.

---

## S10 — Auditoría Access Review (bauth)

### T-177 · `bauth.aud_access_review_campaign`

**Propósito:** Campañas de revisión periódica de accesos (User Access Review / Certification). NIST 800-53 AC-2(7) requiere que se revisen los accesos de usuarios privilegiados al menos trimestralmente.

**¿Qué registra?** Nombre, alcance (TENANT/USER/ROLE/ATOM), tipo (QUARTERLY/ANNUAL/OFFBOARDING/INCIDENT/SOD_REVIEW), fechas, recordatorios, responsable.

**¿Cuándo se alimenta?** El administrador de seguridad crea campañas. Las campañas QUARTERLY pueden generarse automáticamente por job trimestral.

**Procesos necesarios:**
- Al crear una campaña: el sistema genera filas en `aud_access_review_item` para cada combinación (usuario, grant) dentro del scope
- Job de recordatorio: envía notificaciones via bNotify N días antes de `ends_at`
- Job de cierre: al llegar `ends_at`, si hay ítems sin decisión y `auto_revoke_on_expiry=true` → revocar grants

---

### T-178 · `bauth.aud_access_review_item`

**Propósito:** Ítems individuales de revisión de acceso. Un revisor toma una decisión (CERTIFY/REVOKE/ESCALATE/DEFER) por cada ítem.

**¿Qué registra?** (campaign_id, user_id, grant_id o role_id o atom_id), revisor asignado, decisión, razón, fecha de decisión, deadline.

**Procesos necesarios:**
- Al tomar decisión REVOKE: `UPDATE privilege_atom_grant SET status='REVOKED' WHERE id=grant_id`
- Al ESCALATE: notificar al supervisor del revisor via bNotify
- Al DEFER: extender `decision_deadline` (máximo 1 extensión)

**¿Necesita interfaz en el frontend?** Sí — bandeja de revisión para cada revisor asignado.

---

## S11 — Riesgo / ITDR (bauth)

### T-180 · `bauth.risk_score_event` 📦 PART

**Propósito:** ITDR (Identity Threat Detection and Response). Detecta anomalías de comportamiento y asigna un score de riesgo 0-100. Un score > 70 dispara una acción automática.

**¿Qué registra?** Score de riesgo, factores individuales que lo componen (JSONB), acción disparada (STEP_UP/REVOKE/SUSPEND/NOTIFY/REQUIRE_MFA), si la acción fue aplicada.

**¿Cuándo se alimenta?** El motor de riesgo bAuth evalúa cada request autenticado y genera un evento cuando el score supera umbrales configurados.

**Señales de riesgo típicas (risk_factors):**
- `impossible_travel`: el usuario se autenticó desde Bolivia hace 5 minutos y ahora desde Europa (+40 puntos)
- `credential_stuffing`: múltiples intentos fallidos previos al login exitoso (+30 puntos)
- `ua_anomaly`: user-agent nuevo nunca visto para este usuario (+15 puntos)
- `velocity`: 100 requests en 1 segundo desde la misma sesión (+20 puntos)
- `outside_schedule`: acceso fuera del horario habitual del usuario (+10 puntos)

**Procesos necesarios:**
- Motor de riesgo: evalúa en cada request, inserta aquí si score > umbral
- Si score > 70: dispatcher automático → STEP_UP, REVOKE, o SUSPEND según configuración del tier
- Actualiza `idn_sesion_activa.risk_score` con el último score

**¿Necesita interfaz en el frontend?** Sí — dashboard ITDR con timeline de eventos de riesgo para administradores de seguridad.

---

## S12 — PAM Privileged Access Management (bauth)

### T-182 · `bauth.pam_jit_request`

**Propósito:** Solicitudes JIT (Just-In-Time) de acceso elevado temporal. En lugar de dar privilegios permanentes, el usuario solicita acceso cuando lo necesita, especifica la justificación y duración, y uno o más gerentes aprueban.

**¿Qué registra?** Solicitante, rol/átomos target, justificación, duración solicitada, estado (PENDING/APPROVED/ACTIVE/EXPIRED/REVOKED/REJECTED), aprobadores, FK al grant JIT creado.

**¿Cuándo se alimenta?** Cuando un usuario necesita acceso temporal elevado (ej: acceso a una base de datos de producción para debugging).

**Flujo:**
1. Usuario crea solicitud → status=PENDING
2. Gerente(s) aprueban (N >= quorum) → status=APPROVED
3. bAuth crea `privilege_atom_grant(grant_type='JIT', valid_until=now()+duration)` → status=ACTIVE
4. Al expirar → status=EXPIRED, grant revocado automáticamente

**¿Necesita interfaz en el frontend?** Sí — bandeja de solicitudes JIT + panel de aprobaciones.

---

### T-182b · `bauth.pam_jit_audit` 🔒 WORM

**Propósito:** Registro inmutable de cada acción en el ciclo de vida de solicitudes JIT. Hash-chain para detección de alteración forense.

---

### T-183 · `bauth.pam_breakglass_request`

**Propósito:** Acceso de emergencia (break-glass). Para situaciones de crisis donde los procesos normales son insuficientes por urgencia. Quórum mínimo: 2 aprobadores (nunca autoaprobación).

**¿Qué registra?** `incident_ref` (ticket de incidente), justificación, estado, aprobadores, timestamps de activación/desactivación, revisión post-incidente obligatoria.

**Flujo:**
1. Usuario declara emergencia → status=PENDING_APPROVAL + alerta inmediata a equipo de seguridad
2. 2+ personas aprueban → status=ACTIVE → grant BREAKGLASS creado (reassess=false)
3. Al resolver el incidente → DEACTIVATE → grant revocado
4. Revisión post-incidente < 24h → reviewed_at + review_outcome

**¿Por qué `reassess=false`?** El grant BREAKGLASS es inmune a CAEP durante la emergencia — no se revoca automáticamente por señales de riesgo, requiere desactivación manual.

**¿Necesita interfaz en el frontend?** Sí — panel de emergencias con botón de activación grande y visible + alerta a todos los administradores.

---

### T-184 · `bauth.pam_privileged_access_log` 🔒 WORM 📦 PART

**Propósito:** Log inmutable de sesiones de acceso privilegiado activo (cuando el JIT o break-glass está activo). Incluye referencia a grabación de sesión (session recording) para forensia.

**¿Cuándo se alimenta?** En cada acción del usuario durante una sesión JIT o break-glass activa.

**¿Necesita interfaz en el frontend?** Sí — visor de logs de acceso privilegiado para auditores.

---

### T-185 · `bauth.pam_credential_vault_ref`

**Propósito:** Punteros a credenciales rotatorias en HashiCorp Vault. El secreto NUNCA se almacena en PostgreSQL. Esta tabla registra dónde viven las credenciales y cuándo deben rotarse.

**¿Qué registra?** Propietario (HUMAN o NHI), tipo de credencial (PASSWORD/API_KEY/CERTIFICATE/SSH_KEY/SERVICE_TOKEN/OAUTH_TOKEN), ruta Vault, versión, período de rotación.

**Procesos necesarios:**
- Job de rotación: `WHERE next_rotation_at <= NOW() AND status='ACTIVE'` → llamar API Vault para rotar → actualizar vault_version y timestamps

---

### T-189 · `bauth.pam_tree_change_proposal`

**Propósito:** Propuestas de cambio al árbol de políticas T-162 con quórum de aprobación. **Ningún cambio al árbol se aplica directamente.** Primero pasa por una propuesta con quórum (mínimo 2 aprobadores para cambios al PAP).

**¿Qué registra?** Tipo de cambio (ADD_NODE/MODIFY_NODE/DEACTIVATE_NODE/ADD_VERB/MODIFY_VERB/ADD_SOD_RULE), nodo target, payload del cambio (JSONB completo), estado (DRAFT/PENDING_QUORUM/APPROVED/REJECTED/EXPIRED).

**Flujo:**
1. Administrador crea propuesta → status=DRAFT
2. Envía a revisión → status=PENDING_QUORUM + notificación a aprobadores
3. Al alcanzar quórum (N >= quorum_required) → status=APPROVED
4. bAuth aplica el cambio en T-162 → crea registro en T-163 → status=APPLIED

**La clave `quorum_slug`** usa separador punto (no guión bajo): `quorum.aprobadores`. Es la convención del árbol de políticas T-162 (separador de path materializado = punto).

**¿Necesita interfaz en el frontend?** Sí — panel de gestión del árbol de políticas con flujo de aprobación.

---

## Apéndice A — Tablas WORM del sistema

| Tabla | Motivo WORM | Particionada |
|-------|-------------|--------------|
| `bcalendar.cal_notification_log` | Evidencia de alarmas enviadas | No |
| `bauth.idn_roles_template_audit` | Cambios al árbol de políticas | No |
| `bauth.privilege_atom_audit` | Cambios en grants de privilegio | Sí (por mes) |
| `bauth.idn_sesion_audit` | Eventos de sesión | Sí (por mes) |
| `bauth.idn_nhi_lifecycle_event` | Ciclo de vida NHI | No |
| `bauth.pam_jit_audit` | Ciclo de vida JIT | No |
| `bauth.pam_privileged_access_log` | Accesos privilegiados activos | Sí (por mes) |

---

## Apéndice B — Dependencias de creación

El orden de creación de la DDL es:

```
1. Extensiones + ENUMs + SEQUENCE
2. bglobal.global_language, global_country, global_currency, geo_timezone (catálogos raíz)
3. bglobal.menu_item, global_config
4. bauth.idn_tenant
5. bauth.idn_tenant_currencies, languages, verification, config, domain, network
6. bcalendar.cal_fiscal_year, cal_calendar, cal_event, cal_alarm, cal_notification_log, cal_holiday, cal_schedule, cal_overtime_policy, cal_break_policy
7. bauth.idn_calendar_assignment
8. bauth.idn_roles_rol_type, idn_roles_rol_tier
9. bauth.privilege_verb, privilege_verb_conflict
10. bauth.idn_roles_template (+trigger) [FK DEFERIDA a idn_roles_rol_hierarchical]
11. bauth.idn_roles_rol_hierarchical [FK DEFERIDA a idn_roles_template]
12. bauth.idn_roles_rol_closure
13. bauth.idn_roles_template_audit
14. bauth.idn_rol_version, idn_policy_version, idn_rol_assignment_version, idn_privilege_version
15. bauth.idn_identidad_entidad, idn_identidad_atributo, idn_identidad_dominio
16. bauth.idn_nhi_identity, idn_nhi_lifecycle_event, idn_nhi_certification
17. bauth.privilege_atom_grant (+REPLICA IDENTITY FULL), privilege_atom_audit (particionada)
18. bauth.privilege_override, privilege_assurance_log (particionada), privilege_sod_exception, privilege_menu_atom
19. bglobal.menu_context, menu_item_context
20. bauth.idn_sesion_activa, idn_caep_event, idn_ssf_delivery, idn_sesion_audit (particionada)
21. bauth.aud_access_review_campaign, aud_access_review_item
22. bauth.risk_score_event (particionada)
23. bauth.pam_jit_request, pam_jit_audit, pam_breakglass_request
24. bauth.pam_privileged_access_log (particionada), pam_credential_vault_ref, pam_tree_change_proposal
```

---

## Apéndice C — FK deferida idn_roles_hierarchical ↔ idn_roles_template

Existe una dependencia circular entre T-041 y T-162:
- T-041 (`idn_roles_rol_hierarchical.template_id`) → FK a T-162
- T-162 (`idn_roles_template.verb_id`) → FK a T-174 (no circular)

La DDL resuelve esto con `DEFERRABLE INITIALLY DEFERRED` en la FK de T-041 → T-162. Esto permite crear T-162 primero, luego T-041, y luego agregar la constraint deferida. PostgreSQL valida la FK al COMMIT de la transacción (no en cada INSERT).

---

## Apéndice D — Normas y estándares aplicados

| Norma | Aplicación en SBOS_db_V2 |
|-------|--------------------------|
| **ISO/IEC 11179** | Documentación de columnas con nombre, tipo, significado, uso |
| **DAMA DMBOK v2** | Gestión del ciclo de vida de datos, lineage, calidad |
| **NIST RBAC N3 (INCITS 359)** | Modelo de roles, herencia DAG, SoD, closure table |
| **NIST SP 800-63B-4** | Políticas de contraseña, LoA/AAL 1-3, MFA, timeouts |
| **NIST SP 800-63A** | IAL1-3, verificación de identidad, atributos verificados |
| **NIST SP 800-53 Rev.5** | AC-2(7) access review, AC-5 SoD, AU-9 WORM, IA-3 NHI |
| **NIST SP 800-207** | Zero Trust Architecture, DomainRegistry, Policy Engine |
| **XACML 3.0** | PAP (árbol de políticas T-162), PDP, PEP, PIP (T-114/T-009) |
| **ISO 27001:2022** | A.5.15-18 access control, A.8.15 logging, A.8.22 PAM |
| **ISO 24760-2:2025** | Identity management reference architecture (D00) |
| **RFC 9562** | UUIDv7 como PK de todas las tablas |
| **RFC 8935/8936** | CAEP (T-191) y SSF delivery (T-192) |
| **RFC 9470** | Step-Up Authentication (T-181.step_up_valid_until) |
| **RFC 5545** | iCalendar (T-015 rrule, T-016 VALARM) |
| **BCP 47 / RFC 5646** | Tags de idioma (T-001) |
| **ISO 4217** | Códigos de moneda (T-003) |
| **IANA TZ Database** | Zonas horarias (T-004) |
| **Ley 2492 Bolivia** | Retención de datos 7 años (idn_tenant.data_retention_days=2555) |
| **SIN RND 102100000011** | Facturación electrónica Bolivia (cal_fiscal_year) |
| **PCI DSS 4.0** | Seguridad de datos de pago (privilege_atom_audit hash-chain) |

---

*Fin del manual — SBOS_db_V2_DDL_MANUAL.md — v2.0.0*
