-- =============================================================================
-- SEED: bglobal_T060__menu_context.sql
-- Tablas : bglobal.menu_context · bglobal.menu_item
-- Versión: 3.0.0 — generado desde pg_enum real (58 ENUMs de SBOSDB)
-- Fecha  : 2026-08-01
-- Origen : Extraído con pg_catalog.pg_enum + information_schema.columns
-- =============================================================================
-- MODELO:
--   menu_context (CONTEXTUAL) — un registro por ENUM de la BD
--     ↳ code        = nombre normalizado del ENUM (sin sufijo _enum / schema)
--     ↳ description = tablas y columnas que usan este ENUM en el DDL
--   menu_item depth=0 (is_leaf=false) — ancla/raíz del ENUM
--   menu_item depth=1 (is_leaf=true)  — un ítem por valor del ENUM
--
-- El frontend usa menu_context.code para localizar el dropdown y
-- menu_item.parent_id para cargar las opciones del selector.
-- Cada ítem lleva metadata.value con el valor técnico real del ENUM.
-- =============================================================================

TRUNCATE TABLE bglobal.menu_item_atom RESTART IDENTITY CASCADE;
TRUNCATE TABLE bglobal.menu_item      RESTART IDENTITY CASCADE;
TRUNCATE TABLE bglobal.menu_context   RESTART IDENTITY CASCADE;

INSERT INTO bglobal.menu_context (code, name, menu_type, description, is_active, sort_order)
VALUES
  -- [MC-0005] rol_vigencia · Tabla: bauth.idn_roles_rol_hierarchical.validity_type · Kardex: A.65.04
  ('rol_vigencia', '{"es": "Vigencia del Rol", "en": "Role Validity"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0005] Kardex: A.65.04 · Tabla: bauth.idn_roles_rol_hierarchical.validity_type — Define si la validez temporal de un rol es indefinida, acotada a fechas o ligada a un contrato. Controla la expiración automática y activa el reconcile loop cuando un rol vence.', true, 10),
  -- [MC-0001] ver_canal · Tabla: bauth.idn_roles_rol_hierarchical.change_channel, bauth.idn_roles_ver_b01_audit_log.change_channel · Kardex: A.65.04
  ('ver_canal', '{"es": "Canal de Cambio (Versionado)", "en": "Change Channel (Versioning)"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0001] Kardex: A.65.04 · Tabla: bauth.idn_roles_rol_hierarchical.change_channel, bauth.idn_roles_ver_b01_audit_log.change_channel — Identifica por qué canal llegó un cambio de versión de rol: editor humano, API, sincronización IGA o script de sistema. Trazabilidad del origen de cada modificación.', true, 20),
  -- [MC-0002] ver_compactacion · Tabla: bauth.idn_roles_ver_b01_retention_policy.compaction_policy · Kardex: A.65.04
  ('ver_compactacion', '{"es": "Política de Compactación (Versionado)", "en": "Compaction Policy (Versioning)"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0002] Kardex: A.65.04 · Tabla: bauth.idn_roles_ver_b01_retention_policy.compaction_policy — Política de retención histórica de versiones de rol: conservar todas, solo anclas MAJOR, o únicamente las N últimas. Equilibra cumplimiento forense y espacio en disco.', true, 30),
  -- [MC-0003] ver_estado_propuesta · Tabla: bauth.idn_roles_ver_b03_approval_queue.status · Kardex: A.65.04
  ('ver_estado_propuesta', '{"es": "Estado de Propuesta (Versionado)", "en": "Proposal Status (Versioning)"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0003] Kardex: A.65.04 · Tabla: bauth.idn_roles_ver_b03_approval_queue.status — Estado del workflow de aprobación de cambios MAJOR: pendiente de quórum, aprobado, rechazado o expirado. Controla el ciclo dual-control NIST AC-5.', true, 40),
  -- [MC-0004] ver_tipo_cambio · Tabla: bauth.idn_roles_ver_b01_audit_log.change_type · Kardex: A.65.04
  ('ver_tipo_cambio', '{"es": "Tipo de Cambio Semver (Versionado)", "en": "Semver Change Type (Versioning)"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0004] Kardex: A.65.04 · Tabla: bauth.idn_roles_ver_b01_audit_log.change_type — Impacto semver de una modificación de rol: MAJOR (ruptura), MINOR (adición compatible) o PATCH (corrección). Determina si se exige quórum de aprobación.', true, 50),
  -- [MC-0055] canal_alarma · Tabla: bcalendar.cal_alarm.channel, bcalendar.cal_notification_log.channel · Kardex: A.65.04
  ('canal_alarma', '{"es": "Canal de Alarma", "en": "Alarm Channel"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0055] Kardex: A.65.04 · Tabla: bcalendar.cal_alarm.channel, bcalendar.cal_notification_log.channel — Canal por el que se envía una alarma de calendario: correo electrónico, notificación push o evento interno del sistema. Configurable por evento y destinatario.', true, 60),
  -- [MC-0006] nivel_auditoria · Tabla: bauth.idn_tenant.audit_level · Kardex: A.65.04
  ('nivel_auditoria', '{"es": "Nivel de Auditoría", "en": "Audit Level"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0006] Kardex: A.65.04 · Tabla: bauth.idn_tenant.audit_level — Granularidad del registro de auditoría por tenant: básico (accesos), estándar (operaciones) o forense (cada cambio de estado con diff completo). Determina el volumen de logs y el costo de retención.', true, 70),
  -- [MC-0035] estado_breakglass · Tabla: bauth.pam_breakglass_activation.status · Kardex: A.65.04
  ('estado_breakglass', '{"es": "Estado de Acceso Break-Glass", "en": "Break-Glass Access Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0035] Kardex: A.65.04 · Tabla: bauth.pam_breakglass_activation.status — Fase de una activación de acceso de emergencia: pendiente de aprobación dual, activa, desactivada o revisada post-uso. Garantiza trazabilidad del acceso privilegiado de último recurso.', true, 80),
  -- [MC-0042] caep_tipo_evento · Tabla: bauth.ses_caep_event_log.event_type · Kardex: A.65.04
  ('caep_tipo_evento', '{"es": "Tipo de Evento CAEP", "en": "CAEP Event Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0042] Kardex: A.65.04 · Tabla: bauth.ses_caep_event_log.event_type — Tipo de señal de seguridad continua (CAEP/RFC 9396): cambio de credencial, revocación de sesión, cambio de claims, nivel de aseguramiento o cambio de IP. El PDP actúa en sub-segundo.', true, 90),
  -- [MC-0043] caep_estado_proceso · Tabla: bauth.ses_caep_event_log.proc_status · Kardex: A.65.04
  ('caep_estado_proceso', '{"es": "Estado de Procesamiento CAEP", "en": "CAEP Processing Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0043] Kardex: A.65.04 · Tabla: bauth.ses_caep_event_log.proc_status — Estado de procesamiento de un evento CAEP recibido: recibido, en proceso, aplicado, fallido o ignorado. Permite auditar por qué una señal de amenaza no produjo efecto.', true, 100),
  -- [MC-0052] calendario_tipo_propietario · Tabla: bauth.idn_tenant_calendar_assignment.owner_type · Kardex: A.65.04
  ('calendario_tipo_propietario', '{"es": "Tipo de Propietario de Calendario", "en": "Calendar Owner Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0052] Kardex: A.65.04 · Tabla: bauth.idn_tenant_calendar_assignment.owner_type — Tipo de actor al que se asigna un calendario laboral: tenant, empresa, sucursal o rol específico. Define el alcance de las restricciones horarias en el Motor de Identidad.', true, 110),
  -- [MC-0051] calendario_rol · Tabla: bauth.idn_tenant_calendar_assignment.role · Kardex: A.65.04
  ('calendario_rol', '{"es": "Rol en Calendario", "en": "Calendar Role"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0051] Kardex: A.65.04 · Tabla: bauth.idn_tenant_calendar_assignment.role — Función que cumple el calendario en la asignación: horario laboral base, festivos nacionales o festivos propios del tenant. Cada asignación puede combinar múltiples roles.', true, 120),
  -- [MC-0050] tipo_calendario · Tabla: bcalendar.cal_calendar.calendar_type · Kardex: A.65.04
  ('tipo_calendario', '{"es": "Tipo de Calendario", "en": "Calendar Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0050] Kardex: A.65.04 · Tabla: bcalendar.cal_calendar.calendar_type — Categoría del calendario: laboral estándar, fiscal, académico o de mantenimiento. Determina qué reglas de validez temporal aplica el Motor de Identidad en D04.', true, 130),
  -- [MC-0031] campana_alcance · Tabla: bauth.aud_certification_campaign.scope · Kardex: A.65.04
  ('campana_alcance', '{"es": "Alcance de Campaña IGA", "en": "IGA Campaign Scope"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0031] Kardex: A.65.04 · Tabla: bauth.aud_certification_campaign.scope — Alcance de una campaña de certificación IGA: todos los tenants, un rol específico, un usuario o un átomo de privilegio. Define qué grants deben ser revisados en el ciclo.', true, 140),
  -- [MC-0032] campana_estado · Tabla: bauth.aud_certification_campaign.status · Kardex: A.65.04
  ('campana_estado', '{"es": "Estado de Campaña IGA", "en": "IGA Campaign Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0032] Kardex: A.65.04 · Tabla: bauth.aud_certification_campaign.status — Fase del ciclo de vida de una campaña IGA: programada, activa, esperando decisiones, completada o cancelada. Controla qué acciones puede tomar el administrador en cada fase.', true, 150),
  -- [MC-0033] campana_tipo · Tabla: bauth.aud_certification_campaign.campaign_type · Kardex: A.65.04
  ('campana_tipo', '{"es": "Tipo de Campaña IGA", "en": "IGA Campaign Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0033] Kardex: A.65.04 · Tabla: bauth.aud_certification_campaign.campaign_type — Origen o motivo de la campaña de certificación: revisión trimestral, anual, de offboarding, post-incidente o revisión de conflictos SoD. Determina el SLA y el nivel de urgencia.', true, 160),
  -- [MC-0044] credencial_tipo_propietario · Tabla: bauth.auth_credential.owner_type · Kardex: A.65.04
  ('credencial_tipo_propietario', '{"es": "Tipo de Propietario de Credencial", "en": "Credential Owner Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0044] Kardex: A.65.04 · Tabla: bauth.auth_credential.owner_type — Categoría del actor que posee la credencial: usuario humano o identidad no humana (NHI). Separa las políticas de rotación y revocación para humanos vs servicios automatizados.', true, 170),
  -- [MC-0045] credencial_tipo_ref · Tabla: bauth.pam_credential_ref.credential_type · Kardex: A.65.04
  ('credencial_tipo_ref', '{"es": "Tipo de Credencial", "en": "Credential Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0045] Kardex: A.65.04 · Tabla: bauth.pam_credential_ref.credential_type — Tipo de secreto almacenado en la referencia de credencial: contraseña hash, certificado X.509, token de acceso de larga duración o clave API. Governa la política de rotación.', true, 180),
  -- [MC-0013] dominio_estado · Tabla: bauth.idn_tenant_domain.deploy_status, bauth.idn_tenant_domain.health_status · Kardex: A.65.04
  ('dominio_estado', '{"es": "Estado de Dominio DNS/TLS", "en": "Domain DNS/TLS Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0013] Kardex: A.65.04 · Tabla: bauth.idn_tenant_domain.deploy_status, bauth.idn_tenant_domain.health_status — Estado operativo de un dominio DNS del tenant: validando, activo, expirado, con error de certificado TLS o suspendido. El Motor de Identidad bloquea el ctx_id si el dominio no está activo.', true, 190),
  -- [MC-0014] dominio_tipo · Tabla: bauth.idn_tenant_domain.domain_type · Kardex: A.65.04
  ('dominio_tipo', '{"es": "Tipo de Dominio Web", "en": "Web Domain Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0014] Kardex: A.65.04 · Tabla: bauth.idn_tenant_domain.domain_type — Categoría del dominio web del tenant: principal, alias, de staging o de portal de empleados. Determina qué hosts son válidos en el campo redirect_uri de los clientes OIDC.', true, 200),
  -- [MC-0016] entidad_nivel · Tabla: bauth.idn_identity_entity.level, bauth.idn_identity_requirement.entity_type · Kardex: A.65.04
  ('entidad_nivel', '{"es": "Nivel de Entidad Organizacional", "en": "Organizational Entity Level"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0016] Kardex: A.65.04 · Tabla: bauth.idn_identity_entity.level, bauth.idn_identity_requirement.entity_type — Nivel jerárquico de la entidad en el árbol organizacional D00: tenant, dominio de negocio, subdominio, posición o actor. Define la profundidad del ctx_id y las FK de gobernanza.', true, 210),
  -- [MC-0053] anio_fiscal_estado · Tabla: bcalendar.cal_fiscal_year.status · Kardex: A.65.04
  ('anio_fiscal_estado', '{"es": "Estado del Año Fiscal", "en": "Fiscal Year Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0053] Kardex: A.65.04 · Tabla: bcalendar.cal_fiscal_year.status — Fase del año fiscal: abierto, en cierre, cerrado o bloqueado para ajustes. Las ventanas de transacciones financieras D03 no se pueden abrir si el año fiscal está cerrado.', true, 220),
  -- [MC-0048] param_global_alcance · Tabla: bglobal.global_config.scope · Kardex: A.65.04
  ('param_global_alcance', '{"es": "Alcance del Parámetro Global", "en": "Global Parameter Scope"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0048] Kardex: A.65.04 · Tabla: bglobal.global_config.scope — Alcance de aplicación de un parámetro global del sistema: todo el ecosistema SBOS, un schema específico o solo el daemon bAuth. Determina qué componentes aplican el valor.', true, 230),
  -- [MC-0049] param_global_tipo · Tabla: bglobal.global_config.value_type · Kardex: A.65.04
  ('param_global_tipo', '{"es": "Tipo de Valor de Parámetro Global", "en": "Global Parameter Value Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0049] Kardex: A.65.04 · Tabla: bglobal.global_config.value_type — Tipo de valor del parámetro global: entero, texto, booleano, JSON o duración. El Motor de Identidad usa el tipo para validar y convertir el valor antes de aplicarlo.', true, 240),
  -- [MC-0029] grant_estado · Tabla: bauth.privilege_atom_grant.status · Kardex: A.65.04
  ('grant_estado', '{"es": "Estado del Grant de Privilegio", "en": "Privilege Grant Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0029] Kardex: A.65.04 · Tabla: bauth.privilege_atom_grant.status — Estado de un grant de privilegio por usuario: activo, suspendido, revocado, expirado o pendiente de certificación IGA. Solo los grants ACTIVE participan en el cálculo del BitMask.', true, 250),
  -- [MC-0030] grant_tipo · Tabla: bauth.privilege_atom_grant.grant_type · Kardex: A.65.04
  ('grant_tipo', '{"es": "Tipo de Grant de Privilegio", "en": "Privilege Grant Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0030] Kardex: A.65.04 · Tabla: bauth.privilege_atom_grant.grant_type — Origen del grant de privilegio: STANDARD (asignación ordinaria), JIT (Just-In-Time temporal) o BREAKGLASS (emergencia con dual-control AAL3). Governa las reglas de expiración y auditoría.', true, 260),
  -- [MC-0017] nivel_ial · Tabla: bauth.idn_identity_entity.ial_min, bauth.idn_identity_proofing.ial_achieved · Kardex: A.65.04
  ('nivel_ial', '{"es": "Nivel de Proofing de Identidad (IAL)", "en": "Identity Assurance Level (IAL)"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0017] Kardex: A.65.04 · Tabla: bauth.idn_identity_entity.ial_min, bauth.idn_identity_proofing.ial_achieved — Nivel de aseguramiento de identidad (NIST SP 800-63-4): IAL1 auto-declarado, IAL2 evidencia remota, IAL3 verificación presencial. Determina qué operaciones puede ejecutar el actor.', true, 270),
  -- [MC-0007] nivel_aislamiento · Tabla: bauth.idn_tenant.isolation_level · Kardex: A.65.04
  ('nivel_aislamiento', '{"es": "Nivel de Aislamiento de Tenant", "en": "Tenant Isolation Level"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0007] Kardex: A.65.04 · Tabla: bauth.idn_tenant.isolation_level — Grado de separación de datos entre tenants: compartido, dedicado o air-gapped. Define si el tenant puede co-residir en tablas con otros o requiere instancias exclusivas de PostgreSQL.', true, 280),
  -- [MC-0036] jit_estado · Tabla: bauth.pam_jit_request.status · Kardex: A.65.04
  ('jit_estado', '{"es": "Estado de Acceso Just-in-Time (JIT)", "en": "JIT Access Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0036] Kardex: A.65.04 · Tabla: bauth.pam_jit_request.status — Fase del flujo Just-In-Time de acceso privilegiado: pendiente de aprobación, aprobado, activo, expirado o revocado. El daemon crea el grant en T-170 solo al alcanzar APPROVED.', true, 290),
  -- [MC-0020] idioma_alcance · Tabla: bglobal.global_language.scope · Kardex: A.65.04
  ('idioma_alcance', '{"es": "Alcance de Idioma (ISO 639)", "en": "Language Scope (ISO 639)"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0020] Kardex: A.65.04 · Tabla: bglobal.global_language.scope — Alcance normativo del idioma ISO 639: oficial de estado, regional, de patrimonio o de trabajo. Determina qué idiomas se ofrecen en la interfaz del tenant.', true, 300),
  -- [MC-0021] idioma_tipo · Tabla: bglobal.global_language.language_type · Kardex: A.65.04
  ('idioma_tipo', '{"es": "Tipo de Idioma (ISO 639)", "en": "Language Type (ISO 639)"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0021] Kardex: A.65.04 · Tabla: bglobal.global_language.language_type — Clasificación lingüística del idioma: vivo, extinto, artificial o de señas. Filtra los idiomas disponibles en el perfil de usuario.', true, 310),
  -- [MC-0056] menu_tipo · Tabla: bglobal.menu_context.menu_type · Kardex: A.65.04
  ('menu_tipo', '{"es": "Tipo de Menú", "en": "Menu Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0056] Kardex: A.65.04 · Tabla: bglobal.menu_context.menu_type — Categoría funcional del menú contextual: CONTEXTUAL (opciones de columna de BD), NAVEGACION (menú de aplicación) o CONFIGURACION (parámetros de sistema). Define cómo lo procesa el dashboard.', true, 320),
  -- [MC-0015] red_tipo · Tabla: bauth.idn_tenant_network.network_type · Kardex: A.65.04
  ('red_tipo', '{"es": "Tipo de Red", "en": "Network Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0015] Kardex: A.65.04 · Tabla: bauth.idn_tenant_network.network_type — Tipo de red autorizada para el tenant: LAN corporativa, VPN, CIDR de datacenter o rango de IP de oficina remota. El PEP verifica que la IP de origen del request esté en una red autorizada.', true, 330),
  -- [MC-0040] nhi_decision_cert · Tabla: bauth.idn_roles_nhi_certification.decision · Kardex: A.65.04
  ('nhi_decision_cert', '{"es": "Decisión de Certificación NHI", "en": "NHI Certification Decision"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0040] Kardex: A.65.04 · Tabla: bauth.idn_roles_nhi_certification.decision — Decisión del propietario técnico en la certificación periódica de una NHI: CERTIFY (sigue activa y en uso), DECOMMISSION (dar de baja) o REDUCE_SCOPE (reducir permisos). Exigida mensualmente.', true, 340),
  -- [MC-0041] nhi_tipo_evento · Tabla: bauth.idn_roles_nhi_lifecycle_event.event_type · Kardex: A.65.04
  ('nhi_tipo_evento', '{"es": "Tipo de Evento de Ciclo de Vida NHI", "en": "NHI Lifecycle Event Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0041] Kardex: A.65.04 · Tabla: bauth.idn_roles_nhi_lifecycle_event.event_type — Evento en el ciclo de vida de una identidad no humana: provisionada, certificada, rotada (credencial), suspendida, reactivada, descomisionada o con cambio de propietario.', true, 350),
  -- [MC-0038] nhi_estado · Tabla: bauth.idn_nhi_identity.status · Kardex: A.65.04
  ('nhi_estado', '{"es": "Estado de Identidad No Humana (NHI)", "en": "Non-Human Identity (NHI) Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0038] Kardex: A.65.04 · Tabla: bauth.idn_nhi_identity.status — Estado operativo de una identidad no humana: activa, suspendida, en revisión o descomisionada. Solo las NHI activas pueden autenticarse y obtener tokens.', true, 360),
  -- [MC-0039] nhi_tipo · Tabla: bauth.idn_nhi_identity.nhi_type · Kardex: A.65.04
  ('nhi_tipo', '{"es": "Tipo de Identidad No Humana (NHI)", "en": "Non-Human Identity (NHI) Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0039] Kardex: A.65.04 · Tabla: bauth.idn_nhi_identity.nhi_type — Categoría funcional de la identidad no humana: daemon SBOS, pipeline CI/CD, bot, agente IA autónomo o dispositivo IoT. Determina la política de rotación de credenciales.', true, 370),
  -- [MC-0037] pam_tipo_acceso · Tabla: bauth.pam_cuenta_privilegiada.access_type · Kardex: A.65.04
  ('pam_tipo_acceso', '{"es": "Tipo de Acceso Privilegiado (PAM)", "en": "Privileged Access Type (PAM)"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0037] Kardex: A.65.04 · Tabla: bauth.pam_cuenta_privilegiada.access_type — Modo de acceso privilegiado en la sesión PAM: SSH, RDP, consola BD, API admin, CLI, acceso Vault o consola K8s. Registrado en la grabación de sesión para trazabilidad forense.', true, 380),
  -- [MC-0008] plan_nivel · Tabla: bauth.idn_tenant.plan_tier · Kardex: A.65.04
  ('plan_nivel', '{"es": "Nivel de Plan de Suscripción", "en": "Subscription Plan Tier"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0008] Kardex: A.65.04 · Tabla: bauth.idn_tenant.plan_tier — Tier del plan de suscripción del tenant: STARTER, PROFESSIONAL, ENTERPRISE o GOVERNMENT. Define los límites operativos (número de usuarios, métodos MFA, niveles de SLA y funciones disponibles).', true, 390),
  -- [MC-0046] propuesta_estado · Tabla: bauth.idn_financial_approval.status · Kardex: A.65.04
  ('propuesta_estado', '{"es": "Estado de Propuesta de Cambio", "en": "Change Proposal Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0046] Kardex: A.65.04 · Tabla: bauth.idn_financial_approval.status — Estado de una solicitud de aprobación financiera: borrador, enviada, en revisión, aprobada, rechazada o expirada. Controla el flujo de dual-control en operaciones financieras de alto valor.', true, 400),
  -- [MC-0012] tenant_estado_provisionamiento · Tabla: bauth.idn_tenant.provisioning_status · Kardex: A.65.04
  ('tenant_estado_provisionamiento', '{"es": "Estado de Provisionamiento de Tenant", "en": "Tenant Provisioning Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0012] Kardex: A.65.04 · Tabla: bauth.idn_tenant.provisioning_status — Fase de provisionamiento inicial del tenant: iniciando, instalando servicios, configurando identidad, completado o con error. Bloquea operaciones hasta que el provisionamiento sea completado.', true, 410),
  -- [MC-0034] revision_decision · Tabla: bauth.aud_certification_review.decision · Kardex: A.65.04
  ('revision_decision', '{"es": "Decisión de Revisión de Acceso (IGA)", "en": "Access Review Decision (IGA)"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0034] Kardex: A.65.04 · Tabla: bauth.aud_certification_review.decision — Decisión del revisor IGA: CERTIFY (acceso correcto, sigue activo), REVOKE (revocar el grant) o ESCALATE (elevar a revisor senior). La decisión queda en evidencia auditable ISO 27001.', true, 420),
  -- [MC-0047] riesgo_accion · Tabla: bauth.ses_risk_policy.action_on_trigger · Kardex: A.65.04
  ('riesgo_accion', '{"es": "Acción ante Riesgo de Sesión", "en": "Session Risk Action"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0047] Kardex: A.65.04 · Tabla: bauth.ses_risk_policy.action_on_trigger — Acción que ejecuta el PDP al detectar una señal de riesgo en la sesión: exigir step-up de autenticación, revocar la sesión, suspender el usuario, notificar al CISO o registrar sin actuar.', true, 430),
  -- [MC-0028] nivel_riesgo · Tabla: bauth.idn_roles_rol_hierarchical.risk_classification · Kardex: A.65.04
  ('nivel_riesgo', '{"es": "Nivel de Riesgo", "en": "Risk Level"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0028] Kardex: A.65.04 · Tabla: bauth.idn_roles_rol_hierarchical.risk_classification — Clasificación del impacto de seguridad: BAJO (rutinario), MEDIO (impacto limitado), ALTO (puede afectar múltiples tenants) o CRÍTICO (requiere aprobación dual y revisión post-uso). Governa el quórum PAM.', true, 440),
  -- [MC-0026] rol_tipo_cuenta · Tabla: bauth.idn_roles_template.account_type · Kardex: A.65.04
  ('rol_tipo_cuenta', '{"es": "Tipo de Cuenta de Rol", "en": "Role Account Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0026] Kardex: A.65.04 · Tabla: bauth.idn_roles_template.account_type — Categoría de la cuenta asociada al rol: INDIVIDUAL, M2M, SYSTEM, GROUP, TEMPLATE, VIRTUAL, BOT, DEVICE, SERVICE o EMERGENCY. Determina las políticas de autenticación y el ciclo de vida aplicable.', true, 450),
  -- [MC-0024] rol_estado · Tabla: bauth.idn_roles_rol_hierarchical.status · Kardex: A.65.04
  ('rol_estado', '{"es": "Estado del Rol", "en": "Role Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0024] Kardex: A.65.04 · Tabla: bauth.idn_roles_rol_hierarchical.status — Estado del rol en su ciclo de vida: DEFINIDO, PENDIENTE_APROBACION, ACTIVO, SUSPENDIDO, EN_REVISION, DEPRECADO o RETIRADO. Solo los roles ACTIVOS pueden ser asignados y generan BitMask.', true, 460),
  -- [MC-0025] rol_tier · Tabla: bauth.idn_roles_rol_hierarchical.tier · Kardex: A.65.04
  ('rol_tier', '{"es": "Tier de Rol (Jerarquía)", "en": "Role Tier (Hierarchy)"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0025] Kardex: A.65.04 · Tabla: bauth.idn_roles_rol_hierarchical.tier — Nivel jerárquico del rol: SU, SYS, BIZ_N1-N5, EXT_N0, M2M o VISITANTE. Determina el LoA requerido, los métodos MFA disponibles y el tiempo máximo de sesión.', true, 470),
  -- [MC-0054] horario_estado · Tabla: bcalendar.cal_schedule.status · Kardex: A.65.04
  ('horario_estado', '{"es": "Estado de Horario", "en": "Schedule Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0054] Kardex: A.65.04 · Tabla: bcalendar.cal_schedule.status — Estado de un horario laboral del tenant: activo, en revisión, suspendido o archivado. El Motor Temporal D04 solo aplica restricciones de ventanas horarias de horarios en estado activo.', true, 480),
  -- [MC-0027] etiqueta_sensibilidad · Tabla: bauth.idn_roles_rol_hierarchical.sensitivity_label · Kardex: A.65.04
  ('etiqueta_sensibilidad', '{"es": "Etiqueta de Sensibilidad de Datos", "en": "Data Sensitivity Label"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0027] Kardex: A.65.04 · Tabla: bauth.idn_roles_rol_hierarchical.sensitivity_label — Nivel de sensibilidad de los datos que maneja el rol: PÚBLICO, INTERNO, CONFIDENCIAL, RESTRINGIDO o SECRETO. Determina qué DLP y controles de exportación aplican el PDP y Kong PEP.', true, 490),
  -- [MC-0057] ssf_metodo_entrega · Tabla: bauth.ses_ssf_stream.delivery_method · Kardex: A.65.04
  ('ssf_metodo_entrega', '{"es": "Método de Entrega de Eventos SSF", "en": "SSF Event Delivery Method"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0057] Kardex: A.65.04 · Tabla: bauth.ses_ssf_stream.delivery_method — Protocolo de entrega de eventos SSF al receptor CAEP externo: PUSH (el daemon envía al endpoint del receptor) o POLL (el receptor consulta periódicamente). RFC 8936.', true, 500),
  -- [MC-0058] ssf_estado_entrega · Tabla: bauth.ses_ssf_delivery_log.delivery_status · Kardex: A.65.04
  ('ssf_estado_entrega', '{"es": "Estado de Entrega de Evento SSF", "en": "SSF Event Delivery Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0058] Kardex: A.65.04 · Tabla: bauth.ses_ssf_delivery_log.delivery_status — Estado de la entrega de un evento SSF: enviado exitosamente, fallido (con reintentos pendientes), reintentando o abandonado tras agotar reintentos. Alimenta el job de alertas de entrega.', true, 510),
  -- [MC-0009] suscripcion_estado · Tabla: bauth.idn_tenant.subscription_status · Kardex: A.65.04
  ('suscripcion_estado', '{"es": "Estado de Suscripción de Tenant", "en": "Tenant Subscription Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0009] Kardex: A.65.04 · Tabla: bauth.idn_tenant.subscription_status — Estado de la suscripción comercial del tenant: TRIAL, ACTIVE, PAST_DUE, SUSPENDED o CANCELLED. El Motor de Identidad bloquea el login si la suscripción no está activa.', true, 520),
  -- [MC-0010] tenant_estado · Tabla: bauth.idn_tenant.status · Kardex: A.65.04
  ('tenant_estado', '{"es": "Estado de Tenant", "en": "Tenant Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0010] Kardex: A.65.04 · Tabla: bauth.idn_tenant.status — Estado operativo del tenant: activo, suspendido temporalmente, en proceso de baja o archivado. Solo los tenants activos pueden autenticar usuarios y emitir tokens.', true, 530),
  -- [MC-0011] tenant_tipo · Tabla: bauth.idn_tenant.tenant_type · Kardex: A.65.04
  ('tenant_tipo', '{"es": "Tipo de Tenant", "en": "Tenant Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0011] Kardex: A.65.04 · Tabla: bauth.idn_tenant.tenant_type — Categoría funcional del tenant: EMPRESA (organización cliente), GOBIERNO (entidad pública), TEST (entorno de pruebas del cliente) o INTERNAL (infraestructura propia de SBOS).', true, 540),
  -- [MC-0022] idioma_direccion · Tabla: bglobal.global_language.direction · Kardex: A.65.04
  ('idioma_direccion', '{"es": "Dirección de Escritura del Idioma", "en": "Language Text Direction"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0022] Kardex: A.65.04 · Tabla: bglobal.global_language.direction — Dirección de escritura del idioma: LTR (izquierda a derecha), RTL (derecha a izquierda) o BIDI (bidireccional). Controla la renderización del dashboard para idiomas como árabe o hebreo.', true, 550),
  -- [MC-0023] traduccion_estado · Tabla: bauth.idn_tenant_languages.translation_status · Kardex: A.65.04
  ('traduccion_estado', '{"es": "Estado de Traducción", "en": "Translation Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0023] Kardex: A.65.04 · Tabla: bauth.idn_tenant_languages.translation_status — Estado de la traducción del idioma en el tenant: habilitada y activa, en proceso de validación o deshabilitada. Solo los idiomas en estado activo aparecen en el selector del perfil de usuario.', true, 560),
  -- [MC-0018] verificacion_estado · Tabla: bauth.idn_tenant_verification.status · Kardex: A.65.04
  ('verificacion_estado', '{"es": "Estado de Verificación de Tenant", "en": "Tenant Verification Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0018] Kardex: A.65.04 · Tabla: bauth.idn_tenant_verification.status — Estado del proceso de verificación de identidad del tenant: pendiente de documentos, en revisión, aprobado, rechazado o expirado (re-proofing requerido). Determina el IAL máximo alcanzable.', true, 570),
  -- [MC-0019] verificacion_paso · Tabla: bauth.idn_tenant_verification.step · Kardex: A.65.04
  ('verificacion_paso', '{"es": "Paso del Proceso de Verificación", "en": "Verification Process Step"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   '[MC-0019] Kardex: A.65.04 · Tabla: bauth.idn_tenant_verification.step — Paso actual en el proceso de verificación: subida de documentos, validación automática, revisión manual, videoconferencia o resultado final. Controla el progreso en el wizard de onboarding.', true, 580);

-- ── menu_item: raíz (depth=0) + valores del ENUM (depth=1) ─────────────────
DO $$
DECLARE
    v_rol_vigencia UUID;
    v_ver_canal UUID;
    v_ver_compactacion UUID;
    v_ver_estado_propuesta UUID;
    v_ver_tipo_cambio UUID;
    v_canal_alarma UUID;
    v_nivel_auditoria UUID;
    v_estado_breakglass UUID;
    v_caep_tipo_evento UUID;
    v_caep_estado_proceso UUID;
    v_calendario_tipo_propietario UUID;
    v_calendario_rol UUID;
    v_tipo_calendario UUID;
    v_campana_alcance UUID;
    v_campana_estado UUID;
    v_campana_tipo UUID;
    v_credencial_tipo_propietario UUID;
    v_credencial_tipo_ref UUID;
    v_dominio_estado UUID;
    v_dominio_tipo UUID;
    v_entidad_nivel UUID;
    v_anio_fiscal_estado UUID;
    v_param_global_alcance UUID;
    v_param_global_tipo UUID;
    v_grant_estado UUID;
    v_grant_tipo UUID;
    v_nivel_ial UUID;
    v_nivel_aislamiento UUID;
    v_jit_estado UUID;
    v_idioma_alcance UUID;
    v_idioma_tipo UUID;
    v_menu_tipo UUID;
    v_red_tipo UUID;
    v_nhi_decision_cert UUID;
    v_nhi_tipo_evento UUID;
    v_nhi_estado UUID;
    v_nhi_tipo UUID;
    v_pam_tipo_acceso UUID;
    v_plan_nivel UUID;
    v_propuesta_estado UUID;
    v_tenant_estado_provisionamiento UUID;
    v_revision_decision UUID;
    v_riesgo_accion UUID;
    v_nivel_riesgo UUID;
    v_rol_tipo_cuenta UUID;
    v_rol_estado UUID;
    v_rol_tier UUID;
    v_horario_estado UUID;
    v_etiqueta_sensibilidad UUID;
    v_ssf_metodo_entrega UUID;
    v_ssf_estado_entrega UUID;
    v_suscripcion_estado UUID;
    v_tenant_estado UUID;
    v_tenant_tipo UUID;
    v_idioma_direccion UUID;
    v_traduccion_estado UUID;
    v_verificacion_estado UUID;
    v_verificacion_paso UUID;
BEGIN

    -- bauth.role_validity_type → rol_vigencia
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('rol_vigencia', $j${"es": "Vigencia del Rol", "en": "Role Validity"}$j$, 0, false, $j${"pg_type": "bauth.role_validity_type", "columns": ["bauth.idn_roles_rol_hierarchical.validity_type"]}$j$)
    RETURNING item_id INTO v_rol_vigencia;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_rol_vigencia, 'rol_vigencia.INDEFINITE', $j${"es": "Indefinida", "en": "Indefinite"}$j$, 1, true, 10, $j${"value": "INDEFINITE"}$j$),
        (v_rol_vigencia, 'rol_vigencia.FIXED', $j${"es": "Fija (fecha fin)", "en": "Fixed (end date)"}$j$, 1, true, 20, $j${"value": "FIXED"}$j$),
        (v_rol_vigencia, 'rol_vigencia.PROJECT_BASED', $j${"es": "Por proyecto", "en": "Project-based"}$j$, 1, true, 30, $j${"value": "PROJECT_BASED"}$j$),
        (v_rol_vigencia, 'rol_vigencia.TEMPORARY', $j${"es": "Temporal", "en": "Temporary"}$j$, 1, true, 40, $j${"value": "TEMPORARY"}$j$),
        (v_rol_vigencia, 'rol_vigencia.EMERGENCY', $j${"es": "Emergencia", "en": "Emergency"}$j$, 1, true, 50, $j${"value": "EMERGENCY"}$j$);

    -- bauth.ver_channel_enum → ver_canal
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('ver_canal', $j${"es": "Canal de Cambio (Versionado)", "en": "Change Channel (Versioning)"}$j$, 0, false, $j${"pg_type": "bauth.ver_channel_enum", "columns": ["bauth.idn_roles_rol_hierarchical.change_channel", "bauth.idn_roles_ver_b01_audit_log.change_channel"]}$j$)
    RETURNING item_id INTO v_ver_canal;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_ver_canal, 'ver_canal.API', $j${"es": "API", "en": "API"}$j$, 1, true, 10, $j${"value": "API"}$j$),
        (v_ver_canal, 'ver_canal.CLI', $j${"es": "Interfaz de línea de comandos", "en": "CLI"}$j$, 1, true, 20, $j${"value": "CLI"}$j$),
        (v_ver_canal, 'ver_canal.BOOTSTRAP', $j${"es": "Bootstrap", "en": "Bootstrap"}$j$, 1, true, 30, $j${"value": "BOOTSTRAP"}$j$),
        (v_ver_canal, 'ver_canal.RECONCILE', $j${"es": "Reconciliación", "en": "Reconcile"}$j$, 1, true, 40, $j${"value": "RECONCILE"}$j$);

    -- bauth.ver_compaction_enum → ver_compactacion
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('ver_compactacion', $j${"es": "Política de Compactación (Versionado)", "en": "Compaction Policy (Versioning)"}$j$, 0, false, $j${"pg_type": "bauth.ver_compaction_enum", "columns": ["bauth.idn_roles_ver_b01_retention_policy.compaction_policy"]}$j$)
    RETURNING item_id INTO v_ver_compactacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_ver_compactacion, 'ver_compactacion.KEEP_ALL', $j${"es": "Conservar todo", "en": "Keep all"}$j$, 1, true, 10, $j${"value": "KEEP_ALL"}$j$),
        (v_ver_compactacion, 'ver_compactacion.KEEP_ANCHORS', $j${"es": "Conservar anclas", "en": "Keep anchors"}$j$, 1, true, 20, $j${"value": "KEEP_ANCHORS"}$j$),
        (v_ver_compactacion, 'ver_compactacion.KEEP_LAST_N', $j${"es": "Conservar últimos N", "en": "Keep last N"}$j$, 1, true, 30, $j${"value": "KEEP_LAST_N"}$j$);

    -- bauth.ver_proposal_status_enum → ver_estado_propuesta
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('ver_estado_propuesta', $j${"es": "Estado de Propuesta (Versionado)", "en": "Proposal Status (Versioning)"}$j$, 0, false, $j${"pg_type": "bauth.ver_proposal_status_enum", "columns": ["bauth.idn_roles_ver_b03_approval_queue.status"]}$j$)
    RETURNING item_id INTO v_ver_estado_propuesta;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_ver_estado_propuesta, 'ver_estado_propuesta.PENDING', $j${"es": "Pendiente", "en": "Pending"}$j$, 1, true, 10, $j${"value": "PENDING"}$j$),
        (v_ver_estado_propuesta, 'ver_estado_propuesta.APPROVED', $j${"es": "Aprobado", "en": "Approved"}$j$, 1, true, 20, $j${"value": "APPROVED"}$j$),
        (v_ver_estado_propuesta, 'ver_estado_propuesta.REJECTED', $j${"es": "Rechazado", "en": "Rejected"}$j$, 1, true, 30, $j${"value": "REJECTED"}$j$),
        (v_ver_estado_propuesta, 'ver_estado_propuesta.EXPIRED', $j${"es": "Expirado", "en": "Expired"}$j$, 1, true, 40, $j${"value": "EXPIRED"}$j$),
        (v_ver_estado_propuesta, 'ver_estado_propuesta.CANCELLED', $j${"es": "Cancelado", "en": "Cancelled"}$j$, 1, true, 50, $j${"value": "CANCELLED"}$j$);

    -- bauth.ver_semver_change_enum → ver_tipo_cambio
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('ver_tipo_cambio', $j${"es": "Tipo de Cambio Semver (Versionado)", "en": "Semver Change Type (Versioning)"}$j$, 0, false, $j${"pg_type": "bauth.ver_semver_change_enum", "columns": ["bauth.idn_roles_ver_b01_audit_log.change_type", "bauth.idn_roles_ver_b03_approval_queue.change_type"]}$j$)
    RETURNING item_id INTO v_ver_tipo_cambio;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_ver_tipo_cambio, 'ver_tipo_cambio.MAJOR', $j${"es": "Mayor (cambio incompatible)", "en": "Major (breaking change)"}$j$, 1, true, 10, $j${"value": "MAJOR"}$j$),
        (v_ver_tipo_cambio, 'ver_tipo_cambio.MINOR', $j${"es": "Menor (nueva función)", "en": "Minor (new feature)"}$j$, 1, true, 20, $j${"value": "MINOR"}$j$),
        (v_ver_tipo_cambio, 'ver_tipo_cambio.PATCH', $j${"es": "Parche (corrección)", "en": "Patch (fix)"}$j$, 1, true, 30, $j${"value": "PATCH"}$j$);

    -- public.alarm_channel_enum → canal_alarma
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('canal_alarma', $j${"es": "Canal de Alarma", "en": "Alarm Channel"}$j$, 0, false, $j${"pg_type": "public.alarm_channel_enum", "columns": ["bcalendar.cal_alarm.channel", "bcalendar.cal_notification_log.channel"]}$j$)
    RETURNING item_id INTO v_canal_alarma;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_canal_alarma, 'canal_alarma.EMAIL', $j${"es": "Correo electrónico", "en": "Email"}$j$, 1, true, 10, $j${"value": "EMAIL"}$j$),
        (v_canal_alarma, 'canal_alarma.SMS', $j${"es": "SMS", "en": "SMS"}$j$, 1, true, 20, $j${"value": "SMS"}$j$),
        (v_canal_alarma, 'canal_alarma.WHATSAPP', $j${"es": "WhatsApp", "en": "WhatsApp"}$j$, 1, true, 30, $j${"value": "WHATSAPP"}$j$),
        (v_canal_alarma, 'canal_alarma.PUSH', $j${"es": "Notificación push", "en": "Push notification"}$j$, 1, true, 40, $j${"value": "PUSH"}$j$),
        (v_canal_alarma, 'canal_alarma.CHAT', $j${"es": "Chat interno", "en": "Internal chat"}$j$, 1, true, 50, $j${"value": "CHAT"}$j$),
        (v_canal_alarma, 'canal_alarma.UI', $j${"es": "Interfaz de usuario", "en": "UI"}$j$, 1, true, 60, $j${"value": "UI"}$j$);

    -- public.audit_level_enum → nivel_auditoria
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('nivel_auditoria', $j${"es": "Nivel de Auditoría", "en": "Audit Level"}$j$, 0, false, $j${"pg_type": "public.audit_level_enum", "columns": ["bauth.idn_tenant.audit_level"]}$j$)
    RETURNING item_id INTO v_nivel_auditoria;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_nivel_auditoria, 'nivel_auditoria.basic', $j${"es": "Básico", "en": "Basic"}$j$, 1, true, 10, $j${"value": "basic"}$j$),
        (v_nivel_auditoria, 'nivel_auditoria.full', $j${"es": "Completo", "en": "Full"}$j$, 1, true, 20, $j${"value": "full"}$j$);

    -- public.breakglass_status_enum → estado_breakglass
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('estado_breakglass', $j${"es": "Estado de Acceso Break-Glass", "en": "Break-Glass Access Status"}$j$, 0, false, $j${"pg_type": "public.breakglass_status_enum", "columns": ["bauth.pam_breakglass_activation.status"]}$j$)
    RETURNING item_id INTO v_estado_breakglass;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_estado_breakglass, 'estado_breakglass.PENDING_APPROVAL', $j${"es": "Pendiente de aprobación", "en": "Pending approval"}$j$, 1, true, 10, $j${"value": "PENDING_APPROVAL"}$j$),
        (v_estado_breakglass, 'estado_breakglass.ACTIVE', $j${"es": "Activo", "en": "Active"}$j$, 1, true, 20, $j${"value": "ACTIVE"}$j$),
        (v_estado_breakglass, 'estado_breakglass.DEACTIVATED', $j${"es": "Desactivado", "en": "Deactivated"}$j$, 1, true, 30, $j${"value": "DEACTIVATED"}$j$),
        (v_estado_breakglass, 'estado_breakglass.REVIEWED', $j${"es": "Revisado", "en": "Reviewed"}$j$, 1, true, 40, $j${"value": "REVIEWED"}$j$);

    -- public.caep_event_type_enum → caep_tipo_evento
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('caep_tipo_evento', $j${"es": "Tipo de Evento CAEP", "en": "CAEP Event Type"}$j$, 0, false, $j${"pg_type": "public.caep_event_type_enum", "columns": ["bauth.ses_caep_event_log.event_type"]}$j$)
    RETURNING item_id INTO v_caep_tipo_evento;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_caep_tipo_evento, 'caep_tipo_evento.credential_change', $j${"es": "Cambio de credencial", "en": "Credential change"}$j$, 1, true, 10, $j${"value": "credential_change"}$j$),
        (v_caep_tipo_evento, 'caep_tipo_evento.token_claims_change', $j${"es": "Cambio de claims en token", "en": "Token claims change"}$j$, 1, true, 20, $j${"value": "token_claims_change"}$j$),
        (v_caep_tipo_evento, 'caep_tipo_evento.session_revoked', $j${"es": "Sesión revocada", "en": "Session revoked"}$j$, 1, true, 30, $j${"value": "session_revoked"}$j$),
        (v_caep_tipo_evento, 'caep_tipo_evento.assurance_level_change', $j${"es": "Cambio de nivel de garantía", "en": "Assurance level change"}$j$, 1, true, 40, $j${"value": "assurance_level_change"}$j$),
        (v_caep_tipo_evento, 'caep_tipo_evento.ip_change', $j${"es": "Cambio de IP", "en": "IP change"}$j$, 1, true, 50, $j${"value": "ip_change"}$j$),
        (v_caep_tipo_evento, 'caep_tipo_evento.risk_score_change', $j${"es": "Cambio de score de riesgo", "en": "Risk score change"}$j$, 1, true, 60, $j${"value": "risk_score_change"}$j$);

    -- public.caep_proc_status_enum → caep_estado_proceso
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('caep_estado_proceso', $j${"es": "Estado de Procesamiento CAEP", "en": "CAEP Processing Status"}$j$, 0, false, $j${"pg_type": "public.caep_proc_status_enum", "columns": ["bauth.ses_caep_event_log.proc_status"]}$j$)
    RETURNING item_id INTO v_caep_estado_proceso;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_caep_estado_proceso, 'caep_estado_proceso.RECEIVED', $j${"es": "Recibido", "en": "Received"}$j$, 1, true, 10, $j${"value": "RECEIVED"}$j$),
        (v_caep_estado_proceso, 'caep_estado_proceso.PROCESSING', $j${"es": "Procesando", "en": "Processing"}$j$, 1, true, 20, $j${"value": "PROCESSING"}$j$),
        (v_caep_estado_proceso, 'caep_estado_proceso.APPLIED', $j${"es": "Aplicado", "en": "Applied"}$j$, 1, true, 30, $j${"value": "APPLIED"}$j$),
        (v_caep_estado_proceso, 'caep_estado_proceso.FAILED', $j${"es": "Fallido", "en": "Failed"}$j$, 1, true, 40, $j${"value": "FAILED"}$j$),
        (v_caep_estado_proceso, 'caep_estado_proceso.IGNORED', $j${"es": "Ignorado", "en": "Ignored"}$j$, 1, true, 50, $j${"value": "IGNORED"}$j$);

    -- public.calendar_owner_type_enum → calendario_tipo_propietario
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('calendario_tipo_propietario', $j${"es": "Tipo de Propietario de Calendario", "en": "Calendar Owner Type"}$j$, 0, false, $j${"pg_type": "public.calendar_owner_type_enum", "columns": ["bauth.idn_tenant_calendar_assignment.owner_type"]}$j$)
    RETURNING item_id INTO v_calendario_tipo_propietario;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_calendario_tipo_propietario, 'calendario_tipo_propietario.TENANT', $j${"es": "Tenant", "en": "Tenant"}$j$, 1, true, 10, $j${"value": "TENANT"}$j$),
        (v_calendario_tipo_propietario, 'calendario_tipo_propietario.COMPANY', $j${"es": "Empresa", "en": "Company"}$j$, 1, true, 20, $j${"value": "COMPANY"}$j$),
        (v_calendario_tipo_propietario, 'calendario_tipo_propietario.BRANCH', $j${"es": "Sucursal", "en": "Branch"}$j$, 1, true, 30, $j${"value": "BRANCH"}$j$),
        (v_calendario_tipo_propietario, 'calendario_tipo_propietario.USER', $j${"es": "Usuario", "en": "User"}$j$, 1, true, 40, $j${"value": "USER"}$j$);

    -- public.calendar_role_enum → calendario_rol
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('calendario_rol', $j${"es": "Rol en Calendario", "en": "Calendar Role"}$j$, 0, false, $j${"pg_type": "public.calendar_role_enum", "columns": ["bauth.idn_tenant_calendar_assignment.role"]}$j$)
    RETURNING item_id INTO v_calendario_rol;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_calendario_rol, 'calendario_rol.OWNER', $j${"es": "Propietario", "en": "Owner"}$j$, 1, true, 10, $j${"value": "OWNER"}$j$),
        (v_calendario_rol, 'calendario_rol.EDITOR', $j${"es": "Editor", "en": "Editor"}$j$, 1, true, 20, $j${"value": "EDITOR"}$j$),
        (v_calendario_rol, 'calendario_rol.VIEWER', $j${"es": "Lector", "en": "Viewer"}$j$, 1, true, 30, $j${"value": "VIEWER"}$j$);

    -- public.calendar_type_enum → tipo_calendario
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('tipo_calendario', $j${"es": "Tipo de Calendario", "en": "Calendar Type"}$j$, 0, false, $j${"pg_type": "public.calendar_type_enum", "columns": ["bcalendar.cal_calendar.calendar_type"]}$j$)
    RETURNING item_id INTO v_tipo_calendario;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_tipo_calendario, 'tipo_calendario.WORK', $j${"es": "Laboral", "en": "Work"}$j$, 1, true, 10, $j${"value": "WORK"}$j$),
        (v_tipo_calendario, 'tipo_calendario.FISCAL', $j${"es": "Fiscal", "en": "Fiscal"}$j$, 1, true, 20, $j${"value": "FISCAL"}$j$),
        (v_tipo_calendario, 'tipo_calendario.PROCESS', $j${"es": "Proceso", "en": "Process"}$j$, 1, true, 30, $j${"value": "PROCESS"}$j$),
        (v_tipo_calendario, 'tipo_calendario.COMPLIANCE', $j${"es": "Cumplimiento", "en": "Compliance"}$j$, 1, true, 40, $j${"value": "COMPLIANCE"}$j$),
        (v_tipo_calendario, 'tipo_calendario.HOLIDAY', $j${"es": "Festivos", "en": "Holiday"}$j$, 1, true, 50, $j${"value": "HOLIDAY"}$j$),
        (v_tipo_calendario, 'tipo_calendario.MAINTENANCE', $j${"es": "Mantenimiento", "en": "Maintenance"}$j$, 1, true, 60, $j${"value": "MAINTENANCE"}$j$);

    -- public.campaign_scope_enum → campana_alcance
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('campana_alcance', $j${"es": "Alcance de Campaña IGA", "en": "IGA Campaign Scope"}$j$, 0, false, $j${"pg_type": "public.campaign_scope_enum", "columns": ["bauth.aud_certification_campaign.scope"]}$j$)
    RETURNING item_id INTO v_campana_alcance;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_campana_alcance, 'campana_alcance.TENANT', $j${"es": "Tenant completo", "en": "Full tenant"}$j$, 1, true, 10, $j${"value": "TENANT"}$j$),
        (v_campana_alcance, 'campana_alcance.USER', $j${"es": "Por usuario", "en": "By user"}$j$, 1, true, 20, $j${"value": "USER"}$j$),
        (v_campana_alcance, 'campana_alcance.ROLE', $j${"es": "Por rol", "en": "By role"}$j$, 1, true, 30, $j${"value": "ROLE"}$j$),
        (v_campana_alcance, 'campana_alcance.ATOM', $j${"es": "Por átomo", "en": "By atom"}$j$, 1, true, 40, $j${"value": "ATOM"}$j$);

    -- public.campaign_status_enum → campana_estado
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('campana_estado', $j${"es": "Estado de Campaña IGA", "en": "IGA Campaign Status"}$j$, 0, false, $j${"pg_type": "public.campaign_status_enum", "columns": ["bauth.aud_certification_campaign.status"]}$j$)
    RETURNING item_id INTO v_campana_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_campana_estado, 'campana_estado.ACTIVE', $j${"es": "Activa", "en": "Active"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_campana_estado, 'campana_estado.COMPLETED', $j${"es": "Completada", "en": "Completed"}$j$, 1, true, 20, $j${"value": "COMPLETED"}$j$),
        (v_campana_estado, 'campana_estado.CANCELLED', $j${"es": "Cancelada", "en": "Cancelled"}$j$, 1, true, 30, $j${"value": "CANCELLED"}$j$),
        (v_campana_estado, 'campana_estado.OVERDUE', $j${"es": "Vencida", "en": "Overdue"}$j$, 1, true, 40, $j${"value": "OVERDUE"}$j$);

    -- public.campaign_type_enum → campana_tipo
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('campana_tipo', $j${"es": "Tipo de Campaña IGA", "en": "IGA Campaign Type"}$j$, 0, false, $j${"pg_type": "public.campaign_type_enum", "columns": ["bauth.aud_certification_campaign.campaign_type"]}$j$)
    RETURNING item_id INTO v_campana_tipo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_campana_tipo, 'campana_tipo.QUARTERLY', $j${"es": "Trimestral", "en": "Quarterly"}$j$, 1, true, 10, $j${"value": "QUARTERLY"}$j$),
        (v_campana_tipo, 'campana_tipo.ANNUAL', $j${"es": "Anual", "en": "Annual"}$j$, 1, true, 20, $j${"value": "ANNUAL"}$j$),
        (v_campana_tipo, 'campana_tipo.OFFBOARDING', $j${"es": "Baja de empleado", "en": "Offboarding"}$j$, 1, true, 30, $j${"value": "OFFBOARDING"}$j$),
        (v_campana_tipo, 'campana_tipo.INCIDENT', $j${"es": "Incidente de seguridad", "en": "Security incident"}$j$, 1, true, 40, $j${"value": "INCIDENT"}$j$),
        (v_campana_tipo, 'campana_tipo.SOD_REVIEW', $j${"es": "Revisión SoD", "en": "SoD review"}$j$, 1, true, 50, $j${"value": "SOD_REVIEW"}$j$);

    -- public.credential_owner_type_enum → credencial_tipo_propietario
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('credencial_tipo_propietario', $j${"es": "Tipo de Propietario de Credencial", "en": "Credential Owner Type"}$j$, 0, false, $j${"pg_type": "public.credential_owner_type_enum", "columns": ["bauth.auth_credential.owner_type", "bauth.pam_credential_ref.owner_type"]}$j$)
    RETURNING item_id INTO v_credencial_tipo_propietario;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_credencial_tipo_propietario, 'credencial_tipo_propietario.HUMAN', $j${"es": "Humano", "en": "Human"}$j$, 1, true, 10, $j${"value": "HUMAN"}$j$),
        (v_credencial_tipo_propietario, 'credencial_tipo_propietario.NHI', $j${"es": "Identidad no humana (NHI)", "en": "Non-human identity (NHI)"}$j$, 1, true, 20, $j${"value": "NHI"}$j$);

    -- public.credential_ref_type_enum → credencial_tipo_ref
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('credencial_tipo_ref', $j${"es": "Tipo de Credencial", "en": "Credential Type"}$j$, 0, false, $j${"pg_type": "public.credential_ref_type_enum", "columns": ["bauth.pam_credential_ref.credential_type", "bauth.auth_credential_secret.secret_type"]}$j$)
    RETURNING item_id INTO v_credencial_tipo_ref;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_credencial_tipo_ref, 'credencial_tipo_ref.PASSWORD', $j${"es": "Contraseña", "en": "Password"}$j$, 1, true, 10, $j${"value": "PASSWORD"}$j$),
        (v_credencial_tipo_ref, 'credencial_tipo_ref.API_KEY', $j${"es": "Clave API", "en": "API key"}$j$, 1, true, 20, $j${"value": "API_KEY"}$j$),
        (v_credencial_tipo_ref, 'credencial_tipo_ref.CERTIFICATE', $j${"es": "Certificado X.509", "en": "X.509 certificate"}$j$, 1, true, 30, $j${"value": "CERTIFICATE"}$j$),
        (v_credencial_tipo_ref, 'credencial_tipo_ref.SSH_KEY', $j${"es": "Clave SSH", "en": "SSH key"}$j$, 1, true, 40, $j${"value": "SSH_KEY"}$j$),
        (v_credencial_tipo_ref, 'credencial_tipo_ref.SERVICE_TOKEN', $j${"es": "Token de servicio", "en": "Service token"}$j$, 1, true, 50, $j${"value": "SERVICE_TOKEN"}$j$),
        (v_credencial_tipo_ref, 'credencial_tipo_ref.OAUTH_TOKEN', $j${"es": "Token OAuth 2.0", "en": "OAuth 2.0 token"}$j$, 1, true, 60, $j${"value": "OAUTH_TOKEN"}$j$);

    -- public.domain_status_enum → dominio_estado
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('dominio_estado', $j${"es": "Estado de Dominio DNS/TLS", "en": "Domain DNS/TLS Status"}$j$, 0, false, $j${"pg_type": "public.domain_status_enum", "columns": ["bauth.idn_tenant_domain.deploy_status", "bauth.idn_tenant_domain.health_status"]}$j$)
    RETURNING item_id INTO v_dominio_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_dominio_estado, 'dominio_estado.PENDING', $j${"es": "Pendiente", "en": "Pending"}$j$, 1, true, 10, $j${"value": "PENDING"}$j$),
        (v_dominio_estado, 'dominio_estado.VERIFIED', $j${"es": "Verificado", "en": "Verified"}$j$, 1, true, 20, $j${"value": "VERIFIED"}$j$),
        (v_dominio_estado, 'dominio_estado.FAILED', $j${"es": "Fallido", "en": "Failed"}$j$, 1, true, 30, $j${"value": "FAILED"}$j$),
        (v_dominio_estado, 'dominio_estado.DEPLOYING', $j${"es": "Desplegando", "en": "Deploying"}$j$, 1, true, 40, $j${"value": "DEPLOYING"}$j$),
        (v_dominio_estado, 'dominio_estado.DEPLOYED', $j${"es": "Desplegado", "en": "Deployed"}$j$, 1, true, 50, $j${"value": "DEPLOYED"}$j$),
        (v_dominio_estado, 'dominio_estado.HEALTHY', $j${"es": "Saludable", "en": "Healthy"}$j$, 1, true, 60, $j${"value": "HEALTHY"}$j$),
        (v_dominio_estado, 'dominio_estado.DEGRADED', $j${"es": "Degradado", "en": "Degraded"}$j$, 1, true, 70, $j${"value": "DEGRADED"}$j$),
        (v_dominio_estado, 'dominio_estado.UNHEALTHY', $j${"es": "No saludable", "en": "Unhealthy"}$j$, 1, true, 80, $j${"value": "UNHEALTHY"}$j$),
        (v_dominio_estado, 'dominio_estado.UNKNOWN', $j${"es": "Desconocido", "en": "Unknown"}$j$, 1, true, 90, $j${"value": "UNKNOWN"}$j$);

    -- public.domain_type_enum → dominio_tipo
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('dominio_tipo', $j${"es": "Tipo de Dominio Web", "en": "Web Domain Type"}$j$, 0, false, $j${"pg_type": "public.domain_type_enum", "columns": ["bauth.idn_tenant_domain.domain_type"]}$j$)
    RETURNING item_id INTO v_dominio_tipo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_dominio_tipo, 'dominio_tipo.WEB', $j${"es": "Web principal", "en": "Main web"}$j$, 1, true, 10, $j${"value": "WEB"}$j$),
        (v_dominio_tipo, 'dominio_tipo.API', $j${"es": "API REST/GraphQL", "en": "API REST/GraphQL"}$j$, 1, true, 20, $j${"value": "API"}$j$),
        (v_dominio_tipo, 'dominio_tipo.POS', $j${"es": "Punto de venta", "en": "Point of sale"}$j$, 1, true, 30, $j${"value": "POS"}$j$),
        (v_dominio_tipo, 'dominio_tipo.ADMIN', $j${"es": "Panel de administración", "en": "Admin panel"}$j$, 1, true, 40, $j${"value": "ADMIN"}$j$),
        (v_dominio_tipo, 'dominio_tipo.PORTAL', $j${"es": "Portal de clientes", "en": "Customer portal"}$j$, 1, true, 50, $j${"value": "PORTAL"}$j$),
        (v_dominio_tipo, 'dominio_tipo.STATIC', $j${"es": "Recursos estáticos", "en": "Static assets"}$j$, 1, true, 60, $j${"value": "STATIC"}$j$),
        (v_dominio_tipo, 'dominio_tipo.MAIL', $j${"es": "Correo (MX)", "en": "Mail (MX)"}$j$, 1, true, 70, $j${"value": "MAIL"}$j$);

    -- public.entidad_nivel_enum → entidad_nivel
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('entidad_nivel', $j${"es": "Nivel de Entidad Organizacional", "en": "Organizational Entity Level"}$j$, 0, false, $j${"pg_type": "public.entidad_nivel_enum", "columns": ["bauth.idn_identity_entity.level", "bauth.idn_identity_requirement.entity_type"]}$j$)
    RETURNING item_id INTO v_entidad_nivel;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_entidad_nivel, 'entidad_nivel.tenant', $j${"es": "Tenant (raíz)", "en": "Tenant (root)"}$j$, 1, true, 10, $j${"value": "tenant"}$j$),
        (v_entidad_nivel, 'entidad_nivel.bdomain', $j${"es": "Dominio de negocio", "en": "Business domain"}$j$, 1, true, 20, $j${"value": "bdomain"}$j$),
        (v_entidad_nivel, 'entidad_nivel.bsubdomain', $j${"es": "Subdominio de negocio", "en": "Business subdomain"}$j$, 1, true, 30, $j${"value": "bsubdomain"}$j$),
        (v_entidad_nivel, 'entidad_nivel.pos', $j${"es": "Punto de operación", "en": "Point of operation"}$j$, 1, true, 40, $j${"value": "pos"}$j$),
        (v_entidad_nivel, 'entidad_nivel.actor', $j${"es": "Actor externo", "en": "External actor"}$j$, 1, true, 50, $j${"value": "actor"}$j$);

    -- public.fiscal_year_status_enum → anio_fiscal_estado
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('anio_fiscal_estado', $j${"es": "Estado del Año Fiscal", "en": "Fiscal Year Status"}$j$, 0, false, $j${"pg_type": "public.fiscal_year_status_enum", "columns": ["bcalendar.cal_fiscal_year.status"]}$j$)
    RETURNING item_id INTO v_anio_fiscal_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_anio_fiscal_estado, 'anio_fiscal_estado.OPEN', $j${"es": "Abierto", "en": "Open"}$j$, 1, true, 10, $j${"value": "OPEN"}$j$),
        (v_anio_fiscal_estado, 'anio_fiscal_estado.CLOSED', $j${"es": "Cerrado", "en": "Closed"}$j$, 1, true, 20, $j${"value": "CLOSED"}$j$),
        (v_anio_fiscal_estado, 'anio_fiscal_estado.CLOSED_WITH_ADJUSTMENTS', $j${"es": "Cerrado con ajustes", "en": "Closed with adjustments"}$j$, 1, true, 30, $j${"value": "CLOSED_WITH_ADJUSTMENTS"}$j$),
        (v_anio_fiscal_estado, 'anio_fiscal_estado.ARCHIVED', $j${"es": "Archivado", "en": "Archived"}$j$, 1, true, 40, $j${"value": "ARCHIVED"}$j$);

    -- public.global_param_scope_enum → param_global_alcance
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('param_global_alcance', $j${"es": "Alcance del Parámetro Global", "en": "Global Parameter Scope"}$j$, 0, false, $j${"pg_type": "public.global_param_scope_enum", "columns": ["bglobal.global_config.scope"]}$j$)
    RETURNING item_id INTO v_param_global_alcance;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_param_global_alcance, 'param_global_alcance.global', $j${"es": "Global (todo el sistema)", "en": "Global (system-wide)"}$j$, 1, true, 10, $j${"value": "global"}$j$),
        (v_param_global_alcance, 'param_global_alcance.security', $j${"es": "Seguridad", "en": "Security"}$j$, 1, true, 20, $j${"value": "security"}$j$),
        (v_param_global_alcance, 'param_global_alcance.calendar', $j${"es": "Calendario", "en": "Calendar"}$j$, 1, true, 30, $j${"value": "calendar"}$j$),
        (v_param_global_alcance, 'param_global_alcance.auth', $j${"es": "Autenticación", "en": "Authentication"}$j$, 1, true, 40, $j${"value": "auth"}$j$),
        (v_param_global_alcance, 'param_global_alcance.policy', $j${"es": "Políticas", "en": "Policy"}$j$, 1, true, 50, $j${"value": "policy"}$j$),
        (v_param_global_alcance, 'param_global_alcance.billing', $j${"es": "Facturación", "en": "Billing"}$j$, 1, true, 60, $j${"value": "billing"}$j$);

    -- public.global_param_type_enum → param_global_tipo
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('param_global_tipo', $j${"es": "Tipo de Valor de Parámetro Global", "en": "Global Parameter Value Type"}$j$, 0, false, $j${"pg_type": "public.global_param_type_enum", "columns": ["bglobal.global_config.value_type"]}$j$)
    RETURNING item_id INTO v_param_global_tipo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_param_global_tipo, 'param_global_tipo.TEXT', $j${"es": "Texto", "en": "Text"}$j$, 1, true, 10, $j${"value": "TEXT"}$j$),
        (v_param_global_tipo, 'param_global_tipo.INTEGER', $j${"es": "Entero", "en": "Integer"}$j$, 1, true, 20, $j${"value": "INTEGER"}$j$),
        (v_param_global_tipo, 'param_global_tipo.BOOLEAN', $j${"es": "Booleano", "en": "Boolean"}$j$, 1, true, 30, $j${"value": "BOOLEAN"}$j$),
        (v_param_global_tipo, 'param_global_tipo.JSON', $j${"es": "JSON", "en": "JSON"}$j$, 1, true, 40, $j${"value": "JSON"}$j$),
        (v_param_global_tipo, 'param_global_tipo.DECIMAL', $j${"es": "Decimal", "en": "Decimal"}$j$, 1, true, 50, $j${"value": "DECIMAL"}$j$);

    -- public.grant_status_enum → grant_estado
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('grant_estado', $j${"es": "Estado del Grant de Privilegio", "en": "Privilege Grant Status"}$j$, 0, false, $j${"pg_type": "public.grant_status_enum", "columns": ["bauth.privilege_atom_grant.status"]}$j$)
    RETURNING item_id INTO v_grant_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_grant_estado, 'grant_estado.ACTIVE', $j${"es": "Activo", "en": "Active"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_grant_estado, 'grant_estado.INACTIVE', $j${"es": "Inactivo", "en": "Inactive"}$j$, 1, true, 20, $j${"value": "INACTIVE"}$j$),
        (v_grant_estado, 'grant_estado.REVOKED', $j${"es": "Revocado", "en": "Revoked"}$j$, 1, true, 30, $j${"value": "REVOKED"}$j$),
        (v_grant_estado, 'grant_estado.EXPIRED', $j${"es": "Expirado", "en": "Expired"}$j$, 1, true, 40, $j${"value": "EXPIRED"}$j$);

    -- public.grant_type_enum → grant_tipo
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('grant_tipo', $j${"es": "Tipo de Grant de Privilegio", "en": "Privilege Grant Type"}$j$, 0, false, $j${"pg_type": "public.grant_type_enum", "columns": ["bauth.privilege_atom_grant.grant_type"]}$j$)
    RETURNING item_id INTO v_grant_tipo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_grant_tipo, 'grant_tipo.STANDARD', $j${"es": "Estándar", "en": "Standard"}$j$, 1, true, 10, $j${"value": "STANDARD"}$j$),
        (v_grant_tipo, 'grant_tipo.JIT', $j${"es": "Just-in-Time (JIT)", "en": "Just-in-Time (JIT)"}$j$, 1, true, 20, $j${"value": "JIT"}$j$),
        (v_grant_tipo, 'grant_tipo.BREAKGLASS', $j${"es": "Break-glass (emergencia)", "en": "Break-glass (emergency)"}$j$, 1, true, 30, $j${"value": "BREAKGLASS"}$j$);

    -- public.ial_level_enum → nivel_ial
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('nivel_ial', $j${"es": "Nivel de Proofing de Identidad (IAL)", "en": "Identity Assurance Level (IAL)"}$j$, 0, false, $j${"pg_type": "public.ial_level_enum", "columns": ["bauth.idn_identity_entity.ial_min", "bauth.idn_identity_proofing.ial_achieved", "bauth.idn_identity_requirement.ial_level", "bauth.idn_roles_rol_hierarchical.ial_min", "bauth.idn_tenant_verification.ial_achieved"]}$j$)
    RETURNING item_id INTO v_nivel_ial;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_nivel_ial, 'nivel_ial.IAL1', $j${"es": "IAL1 — Autoafirmado", "en": "IAL1 — Self-asserted"}$j$, 1, true, 10, $j${"value": "IAL1"}$j$),
        (v_nivel_ial, 'nivel_ial.IAL2', $j${"es": "IAL2 — Verificado remotamente", "en": "IAL2 — Remote verification"}$j$, 1, true, 20, $j${"value": "IAL2"}$j$),
        (v_nivel_ial, 'nivel_ial.IAL3', $j${"es": "IAL3 — Verificado presencialmente", "en": "IAL3 — In-person verification"}$j$, 1, true, 30, $j${"value": "IAL3"}$j$);

    -- public.isolation_level_enum → nivel_aislamiento
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('nivel_aislamiento', $j${"es": "Nivel de Aislamiento de Tenant", "en": "Tenant Isolation Level"}$j$, 0, false, $j${"pg_type": "public.isolation_level_enum", "columns": ["bauth.idn_tenant.isolation_level"]}$j$)
    RETURNING item_id INTO v_nivel_aislamiento;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_nivel_aislamiento, 'nivel_aislamiento.ROW_LEVEL', $j${"es": "Fila por fila (RLS)", "en": "Row-level (RLS)"}$j$, 1, true, 10, $j${"value": "ROW_LEVEL"}$j$),
        (v_nivel_aislamiento, 'nivel_aislamiento.SCHEMA_PER_TENANT', $j${"es": "Schema por tenant", "en": "Schema per tenant"}$j$, 1, true, 20, $j${"value": "SCHEMA_PER_TENANT"}$j$),
        (v_nivel_aislamiento, 'nivel_aislamiento.DB_PER_TENANT', $j${"es": "Base de datos por tenant", "en": "Database per tenant"}$j$, 1, true, 30, $j${"value": "DB_PER_TENANT"}$j$);

    -- public.jit_status_enum → jit_estado
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('jit_estado', $j${"es": "Estado de Acceso Just-in-Time (JIT)", "en": "JIT Access Status"}$j$, 0, false, $j${"pg_type": "public.jit_status_enum", "columns": ["bauth.pam_jit_request.status", "bauth.pam_jit_approval.decision"]}$j$)
    RETURNING item_id INTO v_jit_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_jit_estado, 'jit_estado.PENDING', $j${"es": "Pendiente de aprobación", "en": "Pending approval"}$j$, 1, true, 10, $j${"value": "PENDING"}$j$),
        (v_jit_estado, 'jit_estado.APPROVED', $j${"es": "Aprobado", "en": "Approved"}$j$, 1, true, 20, $j${"value": "APPROVED"}$j$),
        (v_jit_estado, 'jit_estado.ACTIVE', $j${"es": "Activo", "en": "Active"}$j$, 1, true, 30, $j${"value": "ACTIVE"}$j$),
        (v_jit_estado, 'jit_estado.EXPIRED', $j${"es": "Expirado", "en": "Expired"}$j$, 1, true, 40, $j${"value": "EXPIRED"}$j$),
        (v_jit_estado, 'jit_estado.REVOKED', $j${"es": "Revocado", "en": "Revoked"}$j$, 1, true, 50, $j${"value": "REVOKED"}$j$),
        (v_jit_estado, 'jit_estado.REJECTED', $j${"es": "Rechazado", "en": "Rejected"}$j$, 1, true, 60, $j${"value": "REJECTED"}$j$);

    -- public.language_scope_enum → idioma_alcance
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('idioma_alcance', $j${"es": "Alcance de Idioma (ISO 639)", "en": "Language Scope (ISO 639)"}$j$, 0, false, $j${"pg_type": "public.language_scope_enum", "columns": ["bglobal.global_language.scope"]}$j$)
    RETURNING item_id INTO v_idioma_alcance;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_idioma_alcance, 'idioma_alcance.individual', $j${"es": "Individual", "en": "Individual"}$j$, 1, true, 10, $j${"value": "individual"}$j$),
        (v_idioma_alcance, 'idioma_alcance.macrolanguage', $j${"es": "Macrolenguaje", "en": "Macrolanguage"}$j$, 1, true, 20, $j${"value": "macrolanguage"}$j$),
        (v_idioma_alcance, 'idioma_alcance.special', $j${"es": "Especial", "en": "Special"}$j$, 1, true, 30, $j${"value": "special"}$j$),
        (v_idioma_alcance, 'idioma_alcance.collection', $j${"es": "Colección", "en": "Collection"}$j$, 1, true, 40, $j${"value": "collection"}$j$);

    -- public.language_type_enum → idioma_tipo
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('idioma_tipo', $j${"es": "Tipo de Idioma (ISO 639)", "en": "Language Type (ISO 639)"}$j$, 0, false, $j${"pg_type": "public.language_type_enum", "columns": ["bglobal.global_language.language_type"]}$j$)
    RETURNING item_id INTO v_idioma_tipo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_idioma_tipo, 'idioma_tipo.living', $j${"es": "Vivo", "en": "Living"}$j$, 1, true, 10, $j${"value": "living"}$j$),
        (v_idioma_tipo, 'idioma_tipo.extinct', $j${"es": "Extinto", "en": "Extinct"}$j$, 1, true, 20, $j${"value": "extinct"}$j$),
        (v_idioma_tipo, 'idioma_tipo.ancient', $j${"es": "Antiguo", "en": "Ancient"}$j$, 1, true, 30, $j${"value": "ancient"}$j$),
        (v_idioma_tipo, 'idioma_tipo.constructed', $j${"es": "Construido", "en": "Constructed"}$j$, 1, true, 40, $j${"value": "constructed"}$j$),
        (v_idioma_tipo, 'idioma_tipo.historic', $j${"es": "Histórico", "en": "Historic"}$j$, 1, true, 50, $j${"value": "historic"}$j$);

    -- public.menu_type_enum → menu_tipo
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('menu_tipo', $j${"es": "Tipo de Menú", "en": "Menu Type"}$j$, 0, false, $j${"pg_type": "public.menu_type_enum", "columns": ["bglobal.menu_context.menu_type"]}$j$)
    RETURNING item_id INTO v_menu_tipo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_menu_tipo, 'menu_tipo.HIERARCHICAL', $j${"es": "Jerárquico (navegación)", "en": "Hierarchical (navigation)"}$j$, 1, true, 10, $j${"value": "HIERARCHICAL"}$j$),
        (v_menu_tipo, 'menu_tipo.CONTEXTUAL', $j${"es": "Contextual (acciones sobre entidad)", "en": "Contextual (entity actions)"}$j$, 1, true, 20, $j${"value": "CONTEXTUAL"}$j$);

    -- public.network_type_enum → red_tipo
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('red_tipo', $j${"es": "Tipo de Red", "en": "Network Type"}$j$, 0, false, $j${"pg_type": "public.network_type_enum", "columns": ["bauth.idn_tenant_network.network_type"]}$j$)
    RETURNING item_id INTO v_red_tipo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_red_tipo, 'red_tipo.LAN', $j${"es": "Red de área local (LAN)", "en": "Local area network (LAN)"}$j$, 1, true, 10, $j${"value": "LAN"}$j$),
        (v_red_tipo, 'red_tipo.WAN', $j${"es": "Red de área amplia (WAN)", "en": "Wide area network (WAN)"}$j$, 1, true, 20, $j${"value": "WAN"}$j$),
        (v_red_tipo, 'red_tipo.VPN', $j${"es": "Red privada virtual (VPN)", "en": "Virtual private network (VPN)"}$j$, 1, true, 30, $j${"value": "VPN"}$j$),
        (v_red_tipo, 'red_tipo.DMZ', $j${"es": "Zona desmilitarizada (DMZ)", "en": "Demilitarized zone (DMZ)"}$j$, 1, true, 40, $j${"value": "DMZ"}$j$),
        (v_red_tipo, 'red_tipo.GUEST', $j${"es": "Red de invitados", "en": "Guest network"}$j$, 1, true, 50, $j${"value": "GUEST"}$j$),
        (v_red_tipo, 'red_tipo.MANAGEMENT', $j${"es": "Red de gestión", "en": "Management network"}$j$, 1, true, 60, $j${"value": "MANAGEMENT"}$j$);

    -- public.nhi_cert_decision_enum → nhi_decision_cert
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('nhi_decision_cert', $j${"es": "Decisión de Certificación NHI", "en": "NHI Certification Decision"}$j$, 0, false, $j${"pg_type": "public.nhi_cert_decision_enum", "columns": ["bauth.idn_roles_nhi_certification.decision"]}$j$)
    RETURNING item_id INTO v_nhi_decision_cert;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_nhi_decision_cert, 'nhi_decision_cert.CERTIFY', $j${"es": "Certificar (mantener acceso)", "en": "Certify (keep access)"}$j$, 1, true, 10, $j${"value": "CERTIFY"}$j$),
        (v_nhi_decision_cert, 'nhi_decision_cert.DECOMMISSION', $j${"es": "Desactivar (eliminar)", "en": "Decommission (remove)"}$j$, 1, true, 20, $j${"value": "DECOMMISSION"}$j$),
        (v_nhi_decision_cert, 'nhi_decision_cert.REDUCE_SCOPE', $j${"es": "Reducir alcance", "en": "Reduce scope"}$j$, 1, true, 30, $j${"value": "REDUCE_SCOPE"}$j$);

    -- public.nhi_event_type_enum → nhi_tipo_evento
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('nhi_tipo_evento', $j${"es": "Tipo de Evento de Ciclo de Vida NHI", "en": "NHI Lifecycle Event Type"}$j$, 0, false, $j${"pg_type": "public.nhi_event_type_enum", "columns": ["bauth.idn_roles_nhi_lifecycle_event.event_type"]}$j$)
    RETURNING item_id INTO v_nhi_tipo_evento;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_nhi_tipo_evento, 'nhi_tipo_evento.PROVISIONED', $j${"es": "Aprovisionado", "en": "Provisioned"}$j$, 1, true, 10, $j${"value": "PROVISIONED"}$j$),
        (v_nhi_tipo_evento, 'nhi_tipo_evento.CERTIFIED', $j${"es": "Certificado", "en": "Certified"}$j$, 1, true, 20, $j${"value": "CERTIFIED"}$j$),
        (v_nhi_tipo_evento, 'nhi_tipo_evento.ROTATED', $j${"es": "Credencial rotada", "en": "Credential rotated"}$j$, 1, true, 30, $j${"value": "ROTATED"}$j$),
        (v_nhi_tipo_evento, 'nhi_tipo_evento.SUSPENDED', $j${"es": "Suspendido", "en": "Suspended"}$j$, 1, true, 40, $j${"value": "SUSPENDED"}$j$),
        (v_nhi_tipo_evento, 'nhi_tipo_evento.REACTIVATED', $j${"es": "Reactivado", "en": "Reactivated"}$j$, 1, true, 50, $j${"value": "REACTIVATED"}$j$),
        (v_nhi_tipo_evento, 'nhi_tipo_evento.DECOMMISSIONED', $j${"es": "Desactivado definitivamente", "en": "Decommissioned"}$j$, 1, true, 60, $j${"value": "DECOMMISSIONED"}$j$),
        (v_nhi_tipo_evento, 'nhi_tipo_evento.OWNER_CHANGED', $j${"es": "Propietario cambiado", "en": "Owner changed"}$j$, 1, true, 70, $j${"value": "OWNER_CHANGED"}$j$);

    -- public.nhi_status_enum → nhi_estado
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('nhi_estado', $j${"es": "Estado de Identidad No Humana (NHI)", "en": "Non-Human Identity (NHI) Status"}$j$, 0, false, $j${"pg_type": "public.nhi_status_enum", "columns": ["bauth.idn_nhi_identity.status", "bauth.idn_roles_nhi_identity.status"]}$j$)
    RETURNING item_id INTO v_nhi_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_nhi_estado, 'nhi_estado.ACTIVE', $j${"es": "Activo", "en": "Active"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_nhi_estado, 'nhi_estado.SUSPENDED', $j${"es": "Suspendido", "en": "Suspended"}$j$, 1, true, 20, $j${"value": "SUSPENDED"}$j$),
        (v_nhi_estado, 'nhi_estado.DECOMMISSIONED', $j${"es": "Desactivado definitivamente", "en": "Decommissioned"}$j$, 1, true, 30, $j${"value": "DECOMMISSIONED"}$j$);

    -- public.nhi_type_enum → nhi_tipo
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('nhi_tipo', $j${"es": "Tipo de Identidad No Humana (NHI)", "en": "Non-Human Identity (NHI) Type"}$j$, 0, false, $j${"pg_type": "public.nhi_type_enum", "columns": ["bauth.idn_nhi_identity.nhi_type", "bauth.idn_roles_nhi_identity.nhi_type"]}$j$)
    RETURNING item_id INTO v_nhi_tipo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_nhi_tipo, 'nhi_tipo.DAEMON', $j${"es": "Daemon del sistema", "en": "System daemon"}$j$, 1, true, 10, $j${"value": "DAEMON"}$j$),
        (v_nhi_tipo, 'nhi_tipo.PIPELINE', $j${"es": "Pipeline CI/CD", "en": "CI/CD Pipeline"}$j$, 1, true, 20, $j${"value": "PIPELINE"}$j$),
        (v_nhi_tipo, 'nhi_tipo.BOT', $j${"es": "Bot automatizado", "en": "Automated bot"}$j$, 1, true, 30, $j${"value": "BOT"}$j$),
        (v_nhi_tipo, 'nhi_tipo.SERVICE_ACCOUNT', $j${"es": "Cuenta de servicio", "en": "Service account"}$j$, 1, true, 40, $j${"value": "SERVICE_ACCOUNT"}$j$),
        (v_nhi_tipo, 'nhi_tipo.AGENT_AI', $j${"es": "Agente de IA", "en": "AI agent"}$j$, 1, true, 50, $j${"value": "AGENT_AI"}$j$),
        (v_nhi_tipo, 'nhi_tipo.DEVICE', $j${"es": "Dispositivo IoT/hardware", "en": "IoT/hardware device"}$j$, 1, true, 60, $j${"value": "DEVICE"}$j$);

    -- public.pam_access_type_enum → pam_tipo_acceso
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('pam_tipo_acceso', $j${"es": "Tipo de Acceso Privilegiado (PAM)", "en": "Privileged Access Type (PAM)"}$j$, 0, false, $j${"pg_type": "public.pam_access_type_enum", "columns": ["bauth.pam_cuenta_privilegiada.access_type", "bauth.pam_session_record.access_type"]}$j$)
    RETURNING item_id INTO v_pam_tipo_acceso;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_pam_tipo_acceso, 'pam_tipo_acceso.SSH', $j${"es": "SSH", "en": "SSH"}$j$, 1, true, 10, $j${"value": "SSH"}$j$),
        (v_pam_tipo_acceso, 'pam_tipo_acceso.RDP', $j${"es": "Escritorio remoto (RDP)", "en": "Remote desktop (RDP)"}$j$, 1, true, 20, $j${"value": "RDP"}$j$),
        (v_pam_tipo_acceso, 'pam_tipo_acceso.API', $j${"es": "API", "en": "API"}$j$, 1, true, 30, $j${"value": "API"}$j$),
        (v_pam_tipo_acceso, 'pam_tipo_acceso.CONSOLE', $j${"es": "Consola", "en": "Console"}$j$, 1, true, 40, $j${"value": "CONSOLE"}$j$),
        (v_pam_tipo_acceso, 'pam_tipo_acceso.DB', $j${"es": "Base de datos", "en": "Database"}$j$, 1, true, 50, $j${"value": "DB"}$j$),
        (v_pam_tipo_acceso, 'pam_tipo_acceso.CLI', $j${"es": "Línea de comandos", "en": "CLI"}$j$, 1, true, 60, $j${"value": "CLI"}$j$),
        (v_pam_tipo_acceso, 'pam_tipo_acceso.VAULT', $j${"es": "Vault (secretos)", "en": "Vault (secrets)"}$j$, 1, true, 70, $j${"value": "VAULT"}$j$);

    -- public.plan_tier_enum → plan_nivel
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('plan_nivel', $j${"es": "Nivel de Plan de Suscripción", "en": "Subscription Plan Tier"}$j$, 0, false, $j${"pg_type": "public.plan_tier_enum", "columns": ["bauth.idn_tenant.plan_tier"]}$j$)
    RETURNING item_id INTO v_plan_nivel;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_plan_nivel, 'plan_nivel.BASIC', $j${"es": "Básico", "en": "Basic"}$j$, 1, true, 10, $j${"value": "BASIC"}$j$),
        (v_plan_nivel, 'plan_nivel.PRO', $j${"es": "Profesional", "en": "Professional"}$j$, 1, true, 20, $j${"value": "PRO"}$j$),
        (v_plan_nivel, 'plan_nivel.ENTERPRISE', $j${"es": "Empresarial", "en": "Enterprise"}$j$, 1, true, 30, $j${"value": "ENTERPRISE"}$j$);

    -- public.proposal_status_enum → propuesta_estado
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('propuesta_estado', $j${"es": "Estado de Propuesta de Cambio", "en": "Change Proposal Status"}$j$, 0, false, $j${"pg_type": "public.proposal_status_enum", "columns": ["bauth.idn_financial_approval.status"]}$j$)
    RETURNING item_id INTO v_propuesta_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_propuesta_estado, 'propuesta_estado.DRAFT', $j${"es": "Borrador", "en": "Draft"}$j$, 1, true, 10, $j${"value": "DRAFT"}$j$),
        (v_propuesta_estado, 'propuesta_estado.PENDING_QUORUM', $j${"es": "Esperando quórum de aprobación", "en": "Pending quorum"}$j$, 1, true, 20, $j${"value": "PENDING_QUORUM"}$j$),
        (v_propuesta_estado, 'propuesta_estado.APPROVED', $j${"es": "Aprobado", "en": "Approved"}$j$, 1, true, 30, $j${"value": "APPROVED"}$j$),
        (v_propuesta_estado, 'propuesta_estado.REJECTED', $j${"es": "Rechazado", "en": "Rejected"}$j$, 1, true, 40, $j${"value": "REJECTED"}$j$),
        (v_propuesta_estado, 'propuesta_estado.EXPIRED', $j${"es": "Expirado", "en": "Expired"}$j$, 1, true, 50, $j${"value": "EXPIRED"}$j$);

    -- public.provisioning_status_enum → tenant_estado_provisionamiento
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('tenant_estado_provisionamiento', $j${"es": "Estado de Provisionamiento de Tenant", "en": "Tenant Provisioning Status"}$j$, 0, false, $j${"pg_type": "public.provisioning_status_enum", "columns": ["bauth.idn_tenant.provisioning_status"]}$j$)
    RETURNING item_id INTO v_tenant_estado_provisionamiento;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_tenant_estado_provisionamiento, 'tenant_estado_provisionamiento.PENDING', $j${"es": "Pendiente", "en": "Pending"}$j$, 1, true, 10, $j${"value": "PENDING"}$j$),
        (v_tenant_estado_provisionamiento, 'tenant_estado_provisionamiento.INFRA_PROVISIONING', $j${"es": "Aprovisionando infraestructura", "en": "Provisioning infrastructure"}$j$, 1, true, 20, $j${"value": "INFRA_PROVISIONING"}$j$),
        (v_tenant_estado_provisionamiento, 'tenant_estado_provisionamiento.SCHEMA_CREATED', $j${"es": "Schema creado", "en": "Schema created"}$j$, 1, true, 30, $j${"value": "SCHEMA_CREATED"}$j$),
        (v_tenant_estado_provisionamiento, 'tenant_estado_provisionamiento.IDP_CONFIGURED', $j${"es": "IdP configurado", "en": "IdP configured"}$j$, 1, true, 40, $j${"value": "IDP_CONFIGURED"}$j$),
        (v_tenant_estado_provisionamiento, 'tenant_estado_provisionamiento.COMPLETED', $j${"es": "Completado", "en": "Completed"}$j$, 1, true, 50, $j${"value": "COMPLETED"}$j$),
        (v_tenant_estado_provisionamiento, 'tenant_estado_provisionamiento.FAILED', $j${"es": "Fallido", "en": "Failed"}$j$, 1, true, 60, $j${"value": "FAILED"}$j$);

    -- public.review_decision_enum → revision_decision
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('revision_decision', $j${"es": "Decisión de Revisión de Acceso (IGA)", "en": "Access Review Decision (IGA)"}$j$, 0, false, $j${"pg_type": "public.review_decision_enum", "columns": ["bauth.aud_certification_review.decision"]}$j$)
    RETURNING item_id INTO v_revision_decision;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_revision_decision, 'revision_decision.CERTIFY', $j${"es": "Certificar (mantener)", "en": "Certify (keep)"}$j$, 1, true, 10, $j${"value": "CERTIFY"}$j$),
        (v_revision_decision, 'revision_decision.REVOKE', $j${"es": "Revocar", "en": "Revoke"}$j$, 1, true, 20, $j${"value": "REVOKE"}$j$),
        (v_revision_decision, 'revision_decision.ESCALATE', $j${"es": "Escalar", "en": "Escalate"}$j$, 1, true, 30, $j${"value": "ESCALATE"}$j$),
        (v_revision_decision, 'revision_decision.DEFER', $j${"es": "Diferir", "en": "Defer"}$j$, 1, true, 40, $j${"value": "DEFER"}$j$);

    -- public.risk_action_enum → riesgo_accion
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('riesgo_accion', $j${"es": "Acción ante Riesgo de Sesión", "en": "Session Risk Action"}$j$, 0, false, $j${"pg_type": "public.risk_action_enum", "columns": ["bauth.ses_risk_policy.action_on_trigger"]}$j$)
    RETURNING item_id INTO v_riesgo_accion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_riesgo_accion, 'riesgo_accion.STEP_UP', $j${"es": "Step-up de autenticación", "en": "Authentication step-up"}$j$, 1, true, 10, $j${"value": "STEP_UP"}$j$),
        (v_riesgo_accion, 'riesgo_accion.REVOKE', $j${"es": "Revocar sesión", "en": "Revoke session"}$j$, 1, true, 20, $j${"value": "REVOKE"}$j$),
        (v_riesgo_accion, 'riesgo_accion.SUSPEND', $j${"es": "Suspender cuenta", "en": "Suspend account"}$j$, 1, true, 30, $j${"value": "SUSPEND"}$j$),
        (v_riesgo_accion, 'riesgo_accion.NOTIFY', $j${"es": "Notificar al usuario", "en": "Notify user"}$j$, 1, true, 40, $j${"value": "NOTIFY"}$j$),
        (v_riesgo_accion, 'riesgo_accion.REQUIRE_MFA', $j${"es": "Exigir MFA", "en": "Require MFA"}$j$, 1, true, 50, $j${"value": "REQUIRE_MFA"}$j$);

    -- public.risk_level_enum → nivel_riesgo
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('nivel_riesgo', $j${"es": "Nivel de Riesgo", "en": "Risk Level"}$j$, 0, false, $j${"pg_type": "public.risk_level_enum", "columns": ["bauth.idn_roles_rol_hierarchical.risk_classification", "bauth.idn_roles_rol_hierarchical.security_impact", "bauth.idn_roles_ver_b01_audit_log.security_impact", "bauth.idn_roles_ver_b03_approval_queue.security_impact"]}$j$)
    RETURNING item_id INTO v_nivel_riesgo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_nivel_riesgo, 'nivel_riesgo.LOW', $j${"es": "Bajo", "en": "Low"}$j$, 1, true, 10, $j${"value": "LOW"}$j$),
        (v_nivel_riesgo, 'nivel_riesgo.MEDIUM', $j${"es": "Medio", "en": "Medium"}$j$, 1, true, 20, $j${"value": "MEDIUM"}$j$),
        (v_nivel_riesgo, 'nivel_riesgo.HIGH', $j${"es": "Alto", "en": "High"}$j$, 1, true, 30, $j${"value": "HIGH"}$j$),
        (v_nivel_riesgo, 'nivel_riesgo.CRITICAL', $j${"es": "Crítico", "en": "Critical"}$j$, 1, true, 40, $j${"value": "CRITICAL"}$j$);

    -- public.rol_account_type_enum → rol_tipo_cuenta
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('rol_tipo_cuenta', $j${"es": "Tipo de Cuenta de Rol", "en": "Role Account Type"}$j$, 0, false, $j${"pg_type": "public.rol_account_type_enum", "columns": ["bauth.idn_roles_template.account_type"]}$j$)
    RETURNING item_id INTO v_rol_tipo_cuenta;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_rol_tipo_cuenta, 'rol_tipo_cuenta.INDIVIDUAL', $j${"es": "Individual (persona)", "en": "Individual (person)"}$j$, 1, true, 10, $j${"value": "INDIVIDUAL"}$j$),
        (v_rol_tipo_cuenta, 'rol_tipo_cuenta.M2M', $j${"es": "Máquina a máquina (M2M)", "en": "Machine-to-machine (M2M)"}$j$, 1, true, 20, $j${"value": "M2M"}$j$),
        (v_rol_tipo_cuenta, 'rol_tipo_cuenta.SYSTEM', $j${"es": "Sistema", "en": "System"}$j$, 1, true, 30, $j${"value": "SYSTEM"}$j$),
        (v_rol_tipo_cuenta, 'rol_tipo_cuenta.GROUP', $j${"es": "Grupo", "en": "Group"}$j$, 1, true, 40, $j${"value": "GROUP"}$j$),
        (v_rol_tipo_cuenta, 'rol_tipo_cuenta.TEMPLATE', $j${"es": "Plantilla", "en": "Template"}$j$, 1, true, 50, $j${"value": "TEMPLATE"}$j$),
        (v_rol_tipo_cuenta, 'rol_tipo_cuenta.VIRTUAL', $j${"es": "Virtual", "en": "Virtual"}$j$, 1, true, 60, $j${"value": "VIRTUAL"}$j$),
        (v_rol_tipo_cuenta, 'rol_tipo_cuenta.BOT', $j${"es": "Bot", "en": "Bot"}$j$, 1, true, 70, $j${"value": "BOT"}$j$),
        (v_rol_tipo_cuenta, 'rol_tipo_cuenta.DEVICE', $j${"es": "Dispositivo", "en": "Device"}$j$, 1, true, 80, $j${"value": "DEVICE"}$j$),
        (v_rol_tipo_cuenta, 'rol_tipo_cuenta.SERVICE', $j${"es": "Servicio", "en": "Service"}$j$, 1, true, 90, $j${"value": "SERVICE"}$j$),
        (v_rol_tipo_cuenta, 'rol_tipo_cuenta.EMERGENCY', $j${"es": "Emergencia", "en": "Emergency"}$j$, 1, true, 100, $j${"value": "EMERGENCY"}$j$);

    -- public.rol_status_enum → rol_estado
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('rol_estado', $j${"es": "Estado del Rol", "en": "Role Status"}$j$, 0, false, $j${"pg_type": "public.rol_status_enum", "columns": ["bauth.idn_roles_rol_hierarchical.status", "bauth.idn_roles_rol_lifecycle_event.from_status", "bauth.idn_roles_rol_lifecycle_event.to_status"]}$j$)
    RETURNING item_id INTO v_rol_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_rol_estado, 'rol_estado.ACTIVE', $j${"es": "Activo", "en": "Active"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_rol_estado, 'rol_estado.INACTIVE', $j${"es": "Inactivo", "en": "Inactive"}$j$, 1, true, 20, $j${"value": "INACTIVE"}$j$),
        (v_rol_estado, 'rol_estado.DEPRECATED', $j${"es": "Obsoleto", "en": "Deprecated"}$j$, 1, true, 30, $j${"value": "DEPRECATED"}$j$),
        (v_rol_estado, 'rol_estado.ARCHIVED', $j${"es": "Archivado", "en": "Archived"}$j$, 1, true, 40, $j${"value": "ARCHIVED"}$j$),
        (v_rol_estado, 'rol_estado.SUSPENDED', $j${"es": "Suspendido", "en": "Suspended"}$j$, 1, true, 50, $j${"value": "SUSPENDED"}$j$),
        (v_rol_estado, 'rol_estado.IN_REVIEW', $j${"es": "En revisión", "en": "In review"}$j$, 1, true, 60, $j${"value": "IN_REVIEW"}$j$);

    -- public.rol_tier_enum → rol_tier
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('rol_tier', $j${"es": "Tier de Rol (Jerarquía)", "en": "Role Tier (Hierarchy)"}$j$, 0, false, $j${"pg_type": "public.rol_tier_enum", "columns": ["bauth.idn_roles_rol_hierarchical.tier", "bauth.idn_roles_rol_tier.tier"]}$j$)
    RETURNING item_id INTO v_rol_tier;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_rol_tier, 'rol_tier.SU', $j${"es": "Superusuario (SU)", "en": "Superuser (SU)"}$j$, 1, true, 10, $j${"value": "SU"}$j$),
        (v_rol_tier, 'rol_tier.T0', $j${"es": "Tier 0 — Infraestructura crítica", "en": "Tier 0 — Critical infrastructure"}$j$, 1, true, 20, $j${"value": "T0"}$j$),
        (v_rol_tier, 'rol_tier.T1', $j${"es": "Tier 1 — Administración de plataforma", "en": "Tier 1 — Platform administration"}$j$, 1, true, 30, $j${"value": "T1"}$j$),
        (v_rol_tier, 'rol_tier.BIZ_N1', $j${"es": "N1 — Alta dirección", "en": "N1 — Senior management"}$j$, 1, true, 40, $j${"value": "BIZ_N1"}$j$),
        (v_rol_tier, 'rol_tier.BIZ_N2', $j${"es": "N2 — Dirección", "en": "N2 — Director level"}$j$, 1, true, 50, $j${"value": "BIZ_N2"}$j$),
        (v_rol_tier, 'rol_tier.BIZ_N3', $j${"es": "N3 — Gerencia", "en": "N3 — Management"}$j$, 1, true, 60, $j${"value": "BIZ_N3"}$j$),
        (v_rol_tier, 'rol_tier.BIZ_N4', $j${"es": "N4 — Operativo", "en": "N4 — Operational"}$j$, 1, true, 70, $j${"value": "BIZ_N4"}$j$),
        (v_rol_tier, 'rol_tier.BIZ_N5', $j${"es": "N5 — Especialista", "en": "N5 — Specialist"}$j$, 1, true, 80, $j${"value": "BIZ_N5"}$j$),
        (v_rol_tier, 'rol_tier.EXT_N0', $j${"es": "EXT_N0 — Externo", "en": "EXT_N0 — External"}$j$, 1, true, 90, $j${"value": "EXT_N0"}$j$),
        (v_rol_tier, 'rol_tier.M2M', $j${"es": "M2M — Máquina a máquina", "en": "M2M — Machine to machine"}$j$, 1, true, 100, $j${"value": "M2M"}$j$),
        (v_rol_tier, 'rol_tier.VISITANTE', $j${"es": "Visitante (acceso mínimo)", "en": "Visitor (minimum access)"}$j$, 1, true, 110, $j${"value": "VISITANTE"}$j$);

    -- public.schedule_status_enum → horario_estado
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('horario_estado', $j${"es": "Estado de Horario", "en": "Schedule Status"}$j$, 0, false, $j${"pg_type": "public.schedule_status_enum", "columns": ["bcalendar.cal_schedule.status"]}$j$)
    RETURNING item_id INTO v_horario_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_horario_estado, 'horario_estado.OPEN', $j${"es": "Abierto (en horario)", "en": "Open (in schedule)"}$j$, 1, true, 10, $j${"value": "OPEN"}$j$),
        (v_horario_estado, 'horario_estado.CLOSED', $j${"es": "Cerrado", "en": "Closed"}$j$, 1, true, 20, $j${"value": "CLOSED"}$j$),
        (v_horario_estado, 'horario_estado.LUNCH', $j${"es": "Almuerzo", "en": "Lunch"}$j$, 1, true, 30, $j${"value": "LUNCH"}$j$),
        (v_horario_estado, 'horario_estado.BREAK', $j${"es": "Descanso", "en": "Break"}$j$, 1, true, 40, $j${"value": "BREAK"}$j$),
        (v_horario_estado, 'horario_estado.OVERTIME', $j${"es": "Horas extra", "en": "Overtime"}$j$, 1, true, 50, $j${"value": "OVERTIME"}$j$);

    -- public.sensitivity_label_enum → etiqueta_sensibilidad
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('etiqueta_sensibilidad', $j${"es": "Etiqueta de Sensibilidad de Datos", "en": "Data Sensitivity Label"}$j$, 0, false, $j${"pg_type": "public.sensitivity_label_enum", "columns": ["bauth.idn_roles_rol_hierarchical.sensitivity_label"]}$j$)
    RETURNING item_id INTO v_etiqueta_sensibilidad;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_etiqueta_sensibilidad, 'etiqueta_sensibilidad.PUBLIC', $j${"es": "Público", "en": "Public"}$j$, 1, true, 10, $j${"value": "PUBLIC"}$j$),
        (v_etiqueta_sensibilidad, 'etiqueta_sensibilidad.INTERNAL', $j${"es": "Interno", "en": "Internal"}$j$, 1, true, 20, $j${"value": "INTERNAL"}$j$),
        (v_etiqueta_sensibilidad, 'etiqueta_sensibilidad.CONFIDENTIAL', $j${"es": "Confidencial", "en": "Confidential"}$j$, 1, true, 30, $j${"value": "CONFIDENTIAL"}$j$),
        (v_etiqueta_sensibilidad, 'etiqueta_sensibilidad.RESTRICTED', $j${"es": "Restringido", "en": "Restricted"}$j$, 1, true, 40, $j${"value": "RESTRICTED"}$j$),
        (v_etiqueta_sensibilidad, 'etiqueta_sensibilidad.SECRET', $j${"es": "Secreto", "en": "Secret"}$j$, 1, true, 50, $j${"value": "SECRET"}$j$);

    -- public.ssf_delivery_method_enum → ssf_metodo_entrega
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('ssf_metodo_entrega', $j${"es": "Método de Entrega de Eventos SSF", "en": "SSF Event Delivery Method"}$j$, 0, false, $j${"pg_type": "public.ssf_delivery_method_enum", "columns": ["bauth.ses_ssf_stream.delivery_method"]}$j$)
    RETURNING item_id INTO v_ssf_metodo_entrega;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_ssf_metodo_entrega, 'ssf_metodo_entrega.PUSH', $j${"es": "Push (servidor envía)", "en": "Push (server sends)"}$j$, 1, true, 10, $j${"value": "PUSH"}$j$),
        (v_ssf_metodo_entrega, 'ssf_metodo_entrega.POLL', $j${"es": "Poll (cliente consulta)", "en": "Poll (client pulls)"}$j$, 1, true, 20, $j${"value": "POLL"}$j$);

    -- public.ssf_delivery_status_enum → ssf_estado_entrega
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('ssf_estado_entrega', $j${"es": "Estado de Entrega de Evento SSF", "en": "SSF Event Delivery Status"}$j$, 0, false, $j${"pg_type": "public.ssf_delivery_status_enum", "columns": ["bauth.ses_ssf_delivery_log.delivery_status"]}$j$)
    RETURNING item_id INTO v_ssf_estado_entrega;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_ssf_estado_entrega, 'ssf_estado_entrega.SUCCESS', $j${"es": "Exitoso", "en": "Success"}$j$, 1, true, 10, $j${"value": "SUCCESS"}$j$),
        (v_ssf_estado_entrega, 'ssf_estado_entrega.FAILED', $j${"es": "Fallido", "en": "Failed"}$j$, 1, true, 20, $j${"value": "FAILED"}$j$),
        (v_ssf_estado_entrega, 'ssf_estado_entrega.RETRYING', $j${"es": "Reintentando", "en": "Retrying"}$j$, 1, true, 30, $j${"value": "RETRYING"}$j$),
        (v_ssf_estado_entrega, 'ssf_estado_entrega.ABANDONED', $j${"es": "Abandonado", "en": "Abandoned"}$j$, 1, true, 40, $j${"value": "ABANDONED"}$j$);

    -- public.subscription_status_enum → suscripcion_estado
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('suscripcion_estado', $j${"es": "Estado de Suscripción de Tenant", "en": "Tenant Subscription Status"}$j$, 0, false, $j${"pg_type": "public.subscription_status_enum", "columns": ["bauth.idn_tenant.subscription_status"]}$j$)
    RETURNING item_id INTO v_suscripcion_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_suscripcion_estado, 'suscripcion_estado.TRIAL', $j${"es": "Prueba", "en": "Trial"}$j$, 1, true, 10, $j${"value": "TRIAL"}$j$),
        (v_suscripcion_estado, 'suscripcion_estado.ACTIVE', $j${"es": "Activo", "en": "Active"}$j$, 1, true, 20, $j${"value": "ACTIVE"}$j$),
        (v_suscripcion_estado, 'suscripcion_estado.PAST_DUE', $j${"es": "Vencido (deuda pendiente)", "en": "Past due"}$j$, 1, true, 30, $j${"value": "PAST_DUE"}$j$),
        (v_suscripcion_estado, 'suscripcion_estado.CANCELLED', $j${"es": "Cancelado", "en": "Cancelled"}$j$, 1, true, 40, $j${"value": "CANCELLED"}$j$);

    -- public.tenant_status_enum → tenant_estado
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('tenant_estado', $j${"es": "Estado de Tenant", "en": "Tenant Status"}$j$, 0, false, $j${"pg_type": "public.tenant_status_enum", "columns": ["bauth.idn_tenant.status"]}$j$)
    RETURNING item_id INTO v_tenant_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_tenant_estado, 'tenant_estado.PENDING_VERIFICATION', $j${"es": "Pendiente de verificación", "en": "Pending verification"}$j$, 1, true, 10, $j${"value": "PENDING_VERIFICATION"}$j$),
        (v_tenant_estado, 'tenant_estado.ACTIVE', $j${"es": "Activo", "en": "Active"}$j$, 1, true, 20, $j${"value": "ACTIVE"}$j$),
        (v_tenant_estado, 'tenant_estado.SUSPENDED', $j${"es": "Suspendido", "en": "Suspended"}$j$, 1, true, 30, $j${"value": "SUSPENDED"}$j$),
        (v_tenant_estado, 'tenant_estado.MAINTENANCE', $j${"es": "En mantenimiento", "en": "In maintenance"}$j$, 1, true, 40, $j${"value": "MAINTENANCE"}$j$),
        (v_tenant_estado, 'tenant_estado.SOFT_DELETED', $j${"es": "Eliminado lógicamente", "en": "Soft deleted"}$j$, 1, true, 50, $j${"value": "SOFT_DELETED"}$j$),
        (v_tenant_estado, 'tenant_estado.TERMINATED', $j${"es": "Terminado", "en": "Terminated"}$j$, 1, true, 60, $j${"value": "TERMINATED"}$j$),
        (v_tenant_estado, 'tenant_estado.PURGED', $j${"es": "Purgado (eliminación total)", "en": "Purged"}$j$, 1, true, 70, $j${"value": "PURGED"}$j$);

    -- public.tenant_type_enum → tenant_tipo
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('tenant_tipo', $j${"es": "Tipo de Tenant", "en": "Tenant Type"}$j$, 0, false, $j${"pg_type": "public.tenant_type_enum", "columns": ["bauth.idn_tenant.tenant_type"]}$j$)
    RETURNING item_id INTO v_tenant_tipo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_tenant_tipo, 'tenant_tipo.STANDARD', $j${"es": "Estándar", "en": "Standard"}$j$, 1, true, 10, $j${"value": "STANDARD"}$j$),
        (v_tenant_tipo, 'tenant_tipo.REGULATED', $j${"es": "Regulado (sector financiero/salud)", "en": "Regulated (financial/health)"}$j$, 1, true, 20, $j${"value": "REGULATED"}$j$),
        (v_tenant_tipo, 'tenant_tipo.HIGH_SENSITIVITY', $j${"es": "Alta sensibilidad (gobierno/defensa)", "en": "High sensitivity (gov/defense)"}$j$, 1, true, 30, $j${"value": "HIGH_SENSITIVITY"}$j$);

    -- public.text_direction_enum → idioma_direccion
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('idioma_direccion', $j${"es": "Dirección de Escritura del Idioma", "en": "Language Text Direction"}$j$, 0, false, $j${"pg_type": "public.text_direction_enum", "columns": ["bglobal.global_language.direction"]}$j$)
    RETURNING item_id INTO v_idioma_direccion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_idioma_direccion, 'idioma_direccion.ltr', $j${"es": "Izquierda a derecha (LTR)", "en": "Left to right (LTR)"}$j$, 1, true, 10, $j${"value": "ltr"}$j$),
        (v_idioma_direccion, 'idioma_direccion.rtl', $j${"es": "Derecha a izquierda (RTL)", "en": "Right to left (RTL)"}$j$, 1, true, 20, $j${"value": "rtl"}$j$),
        (v_idioma_direccion, 'idioma_direccion.ttb', $j${"es": "Arriba a abajo (TTB)", "en": "Top to bottom (TTB)"}$j$, 1, true, 30, $j${"value": "ttb"}$j$);

    -- public.translation_status_enum → traduccion_estado
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('traduccion_estado', $j${"es": "Estado de Traducción", "en": "Translation Status"}$j$, 0, false, $j${"pg_type": "public.translation_status_enum", "columns": ["bauth.idn_tenant_languages.translation_status"]}$j$)
    RETURNING item_id INTO v_traduccion_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_traduccion_estado, 'traduccion_estado.COMPLETE', $j${"es": "Completa", "en": "Complete"}$j$, 1, true, 10, $j${"value": "COMPLETE"}$j$),
        (v_traduccion_estado, 'traduccion_estado.PARTIAL', $j${"es": "Parcial", "en": "Partial"}$j$, 1, true, 20, $j${"value": "PARTIAL"}$j$),
        (v_traduccion_estado, 'traduccion_estado.MACHINE_TRANSLATED', $j${"es": "Traducido por máquina", "en": "Machine translated"}$j$, 1, true, 30, $j${"value": "MACHINE_TRANSLATED"}$j$),
        (v_traduccion_estado, 'traduccion_estado.NOT_TRANSLATED', $j${"es": "Sin traducir", "en": "Not translated"}$j$, 1, true, 40, $j${"value": "NOT_TRANSLATED"}$j$);

    -- public.verification_status_enum → verificacion_estado
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('verificacion_estado', $j${"es": "Estado de Verificación de Tenant", "en": "Tenant Verification Status"}$j$, 0, false, $j${"pg_type": "public.verification_status_enum", "columns": ["bauth.idn_tenant_verification.status"]}$j$)
    RETURNING item_id INTO v_verificacion_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_verificacion_estado, 'verificacion_estado.PENDING', $j${"es": "Pendiente", "en": "Pending"}$j$, 1, true, 10, $j${"value": "PENDING"}$j$),
        (v_verificacion_estado, 'verificacion_estado.IN_PROGRESS', $j${"es": "En progreso", "en": "In progress"}$j$, 1, true, 20, $j${"value": "IN_PROGRESS"}$j$),
        (v_verificacion_estado, 'verificacion_estado.PASSED', $j${"es": "Aprobado", "en": "Passed"}$j$, 1, true, 30, $j${"value": "PASSED"}$j$),
        (v_verificacion_estado, 'verificacion_estado.FAILED', $j${"es": "Fallido", "en": "Failed"}$j$, 1, true, 40, $j${"value": "FAILED"}$j$);

    -- public.verification_step_enum → verificacion_paso
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('verificacion_paso', $j${"es": "Paso del Proceso de Verificación", "en": "Verification Process Step"}$j$, 0, false, $j${"pg_type": "public.verification_step_enum", "columns": ["bauth.idn_tenant_verification.step"]}$j$)
    RETURNING item_id INTO v_verificacion_paso;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_verificacion_paso, 'verificacion_paso.IDENTITY_CHECK', $j${"es": "Verificación de identidad", "en": "Identity check"}$j$, 1, true, 10, $j${"value": "IDENTITY_CHECK"}$j$),
        (v_verificacion_paso, 'verificacion_paso.LEGAL_CHECK', $j${"es": "Verificación legal", "en": "Legal check"}$j$, 1, true, 20, $j${"value": "LEGAL_CHECK"}$j$),
        (v_verificacion_paso, 'verificacion_paso.TECHNICAL_SETUP', $j${"es": "Configuración técnica", "en": "Technical setup"}$j$, 1, true, 30, $j${"value": "TECHNICAL_SETUP"}$j$),
        (v_verificacion_paso, 'verificacion_paso.SECURITY_REVIEW', $j${"es": "Revisión de seguridad", "en": "Security review"}$j$, 1, true, 40, $j${"value": "SECURITY_REVIEW"}$j$),
        (v_verificacion_paso, 'verificacion_paso.FINAL_APPROVAL', $j${"es": "Aprobación final", "en": "Final approval"}$j$, 1, true, 50, $j${"value": "FINAL_APPROVAL"}$j$);

END $$;

-- ── Verificación ──────────────────────────────────────────────────────────────
SELECT resumen FROM (
  SELECT 1 AS ord, 'menu_context: '  || COUNT(*) || ' ENUMs registrados' AS resumen FROM bglobal.menu_context
  UNION ALL
  SELECT 2, 'menu_item raíz: ' || COUNT(*) || ' ítems (depth=0)' FROM bglobal.menu_item WHERE depth=0
  UNION ALL
  SELECT 3, 'menu_item valores: ' || COUNT(*) || ' opciones de ENUM (depth=1)' FROM bglobal.menu_item WHERE depth=1
) t ORDER BY ord;
