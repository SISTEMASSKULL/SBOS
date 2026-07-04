-- ============================================================================
-- SEED: Políticas por Dominio — ath_policy_d1 a ath_policy_d12
-- Fuente: Policies_Authentication_Framework_v4.json (104KB)
--         Authentication_Framework_v3.json (602KB)
--         MANUAL_DB_DDL.md v18.0 §6, §31
-- Idempotente: TRUNCATE + RESTART IDENTITY CASCADE + INSERT
-- ============================================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- D1 — DOMINIO LÓGICO: Control de acceso a aplicaciones y registros
-- Estándares: NIST RBAC §4.2, NIST SP 800-53 AC-3, ANSI/INCITS 359-2004
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_policy_d1 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_policy_d1 (policy_code, policy_name, description, standard_ref, config) VALUES
('POL-D1-RECORD-RULES', 'Reglas de acceso a registros por zona',
 'Define qué registros puede ver, crear, editar y eliminar cada rol dentro de una zona de negocio. Basado en el principio de mínimo privilegio: un rol solo ve los registros de su zona asignada.',
 ARRAY['NIST RBAC §4.2','NIST SP 800-53 AC-3','ANSI/INCITS 359-2004'],
 '{"scope":"record_level","default":"deny_all","zones":["sucursal","departamento","empresa","tenant"],"verbs":{"view":"zone_and_below","create":"own_zone_only","edit":"own_zone_only","delete":"none"}}'),

('POL-D1-FIELD-RULES', 'Restricción de campos por rol',
 'Define qué campos de cada modelo son visibles, editables u ocultos para cada rol. Campos sensibles como PII, datos financieros, o configuraciones de seguridad requieren permisos explícitos.',
 ARRAY['NIST SP 800-53 AC-3(4)','OWASP ASVS V4.1.1','RGPD Art.5'],
 '{"scope":"field_level","sensitive_fields":["tax_id","salary","health_data","bank_account"],"default_visibility":"label_only","rules":{"pii_fields":"require_explicit_grant","financial_fields":"view_only_by_default","security_fields":"admin_only"}}'),

('POL-D1-BUTTON-RULES', 'Control de botones y acciones por rol',
 'Define qué botones, acciones y operaciones están disponibles para cada rol en la interfaz. Las acciones críticas (aprobar, eliminar, exportar) requieren verificación adicional.',
 ARRAY['NIST SP 800-53 AC-3(2)','OWASP ASVS V4.1.2','SOX §404'],
 '{"scope":"action_level","critical_actions":["delete","approve","export_pii","change_security"],"require_dual_approval_for":["delete_bulk","export_full_db"],"hidden_actions_default":["impersonate","sudo","elevate_privilege"]}'),

('POL-D1-SCOPE', 'Alcance de acceso por jerarquía organizacional',
 'Define el alcance máximo de datos que un rol puede acceder según la jerarquía organizacional: tenant, empresa, sucursal, o punto de servicio. Limita la propagación de accesos.',
 ARRAY['NIST SP 800-53 AC-3(7)','ISO 27001 A.9.4'],
 '{"max_scope":"sucursal","propagation":"downward_only","cross_tenant":false,"cross_empresa":"require_explicit_grant","cross_sucursal":"same_empresa_only"}'),

('POL-D1-DATA-CLASSIFICATION', 'Clasificación de datos y control de acceso',
 'Define niveles de clasificación de datos (público, interno, confidencial, restringido) y los permisos requeridos para acceder a cada nivel.',
 ARRAY['ISO 27001 A.8.2','NIST SP 800-53 RA-2','RGPD Art.32'],
 '{"levels":["public","internal","confidential","restricted"],"default":"internal","access_requirements":{"confidential":"mfa_required","restricted":"aal3_required"},"audit_level":{"confidential":"full","restricted":"full_with_forensic"}}'),

('POL-D1-ZONE-ACCESS', 'Acceso a zonas lógicas de negocio',
 'Define las zonas lógicas de negocio (ventas, compras, contabilidad, RRHH, inventario) y qué roles pueden acceder a cada una. Una zona puede tener subzonas con herencia de permisos.',
 ARRAY['NIST RBAC §4.1','ANSI/INCITS 359-2004','ISO 24760-2:2025'],
 '{"zones":{"ventas":{"subzonas":["mostrador","ecommerce","mayorista"]},"compras":{"subzonas":["nacional","importacion","servicios"]},"contabilidad":{"subzonas":["general","costos","fiscal"]},"rrhh":{"subzonas":["personal","nomina","reclutamiento"]},"inventario":{"subzonas":["almacen","despacho","recepcion"]}},"default":"no_access"}');

-- ═══════════════════════════════════════════════════════════════════════════
-- D2 — DOMINIO FÍSICO: Acceso a espacios físicos, puertas y dispositivos
-- Estándares: IEC 60839-11-5 (OSDP v2.2.2), BS 5979, NIST SP 800-53 PE
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_policy_d2 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_policy_d2 (policy_code, policy_name, description, standard_ref, config) VALUES
('POL-D2-ANTI-PASSBACK', 'Anti-Passback: prevención de reingreso sin salida',
 'Impide que una credencial sea usada dos veces para entrar sin haber registrado salida. El sistema mantiene estado IN/OUT por usuario por zona. Si se detecta violación, se deniega el acceso y se genera alerta de seguridad.',
 ARRAY['IEC 60839-11-5','BS 5979:2007','NIST SP 800-53 PE-3'],
 '{"mode":"hard","zones_applicable":["zone_3","zone_4","zone_5"],"reset_policy":"midnight","violation_action":"deny_and_alert","grace_period_seconds":30}'),

('POL-D2-ESCORT', 'Escolta obligatorio para visitantes',
 'Visitantes y personal sin autorización plena deben ser escoltados por personal autorizado. El escolta debe autenticarse primero y luego el visitante. Si el escolta sale, el visitante debe salir también.',
 ARRAY['BS 5979:2007','NIST SP 800-53 PE-3(1)','ISO 27001 A.11.1'],
 '{"require_escort_for":["VISITOR","CONTRACTOR","TEMPORARY"],"escort_ratio":"1_escort_per_5_visitors","escort_must_authenticate_first":true,"escort_exit_revokes_visitor":true,"max_escort_duration_hours":8}'),

('POL-D2-TWO-PERSON', 'Regla de dos personas (four-eyes físico)',
 'Áreas de alta seguridad requieren mínimo 2 personas autenticadas simultáneamente para abrir. Ambas deben tener el átomo de acceso a esa zona. Si una sale, la otra puede permanecer hasta 15 minutos antes de requerir revalidación.',
 ARRAY['BS 5979:2007','NIST SP 800-53 PE-3(2)','PCI-DSS 9.5'],
 '{"min_persons":2,"zones_required":["boveda","data_center","armory"],"auth_window_seconds":30,"revalidation_timeout_minutes":15,"violation_action":"lockdown_and_alert"}'),

('POL-D2-MANTRAP', 'Esclusa de seguridad (mantrap)',
 'Puertas en esclusa: la puerta B no abre hasta que la puerta A cierra completamente. Sensores de peso/presencia detectan si más de una persona ingresó (tailgating). Si se detecta tailgating, ambas puertas se bloquean.',
 ARRAY['BS 5979:2007','IEC 60839-11-5','NIST SP 800-53 PE-3(3)'],
 '{"interlock_mode":"strict","max_occupancy_per_cycle":1,"tailgating_detection":true,"tailgating_action":"lock_both_doors_and_alert","door_a_close_timeout_seconds":10,"door_b_open_timeout_seconds":15}'),

('POL-D2-BIOMETRIC-ENROLLMENT', 'Enrolamiento biométrico seguro',
 'Define el procedimiento de registro biométrico: requiere testigo de seguridad, verificación de identidad previa, y almacenamiento cifrado del template. El template nunca sale del sistema en texto plano.',
 ARRAY['ISO/IEC 19794','NIST SP 800-53 IA-4','RGPD Art.9'],
 '{"require_witness":true,"identity_verification":"ial2_minimum","template_storage":"aes_256_gcm","template_retention":"delete_on_offboarding","quality_threshold":{"fingerprint":80,"face":85,"iris":90}}'),

('POL-D2-EMERGENCY-OVERRIDE', 'Anulación de emergencia física',
 'En situaciones de emergencia (incendio, brecha de seguridad, desastre natural), los controles de acceso físico pueden ser anulados. La anulación requiere autenticación de emergencia y genera auditoría completa.',
 ARRAY['BS 5979:2007','NIST SP 800-53 PE-17','ISO 27001 A.11.1.6'],
 '{"triggers":["fire_alarm","security_breach","natural_disaster","active_shooter"],"override_action":"unlock_all_emergency_exits","require_dual_authorization":true,"post_event_audit_required":true,"max_override_duration_minutes":120}'),

('POL-D2-VISITOR-ACCESS', 'Acceso de visitantes con vigencia temporal',
 'Visitantes reciben acceso temporal con fecha de expiración automática. El acceso se limita a zonas públicas y zonas autorizadas. Credencial temporal de un solo uso o día.',
 ARRAY['NIST SP 800-53 PE-2','ISO 27001 A.11.1.2'],
 '{"max_duration_hours":12,"auto_revoke_at":"23:59","allowed_zones":["reception","meeting_rooms","cafeteria"],"require_photo_id":true,"credential_type":"temporary_pin_or_qr","check_in_check_out_required":true}');

-- ═══════════════════════════════════════════════════════════════════════════
-- D3 — DOMINIO FINANCIERO: Límites, doble aprobación, segregación de deberes
-- Estándares: ISO 20022, NIST SP 800-53 AC-5, SOX §404, COSO, SIN Bolivia
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_policy_d3 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_policy_d3 (policy_code, policy_name, description, standard_ref, config) VALUES
('POL-D3-DUAL-APPROVAL', 'Doble aprobación financiera',
 'Transacciones financieras sobre un monto umbral requieren aprobación de un segundo usuario. El aprobador debe ser distinto del creador (SoD). La cadena de aprobación escala si el aprobador no responde en el tiempo configurado.',
 ARRAY['SOX §404','COSO','NIST SP 800-53 AC-5','SIN RND 102100000011'],
 '{"thresholds":[{"amount":1000,"currency":"BOB","requires":1,"level":"n1"},{"amount":10000,"currency":"BOB","requires":2,"level":"n2"},{"amount":100000,"currency":"BOB","requires":3,"level":"n3"}],"sod_enforced":true,"escalation_timeout_hours":4,"auto_escalate":true}'),

('POL-D3-SOD', 'Segregación de deberes financieros (SoD)',
 'Define pares de capacidades financieras incompatibles que no pueden ser asignadas al mismo usuario. SoD estático (no asignar) y dinámico (no activar simultáneamente en la misma sesión).',
 ARRAY['NIST SP 800-53 AC-5','SOX §302','COSO'],
 '{"static_pairs":[["FINANCIAL_CREATE","FINANCIAL_APPROVE"],["FINANCIAL_CREATE","FINANCIAL_RECONCILE"],["PURCHASE_CREATE","PURCHASE_APPROVE"],["PAYROLL_CREATE","PAYROLL_APPROVE"]],"dynamic_sod_enabled":true,"conflict_action":"block_assignment","audit_violations":true}'),

('POL-D3-TRANSACTION-LIMITS', 'Límites por tipo de transacción',
 'Define límites máximos por operación, día, y mes para cada tipo de transacción financiera. Los límites se configuran por rol, moneda y tipo de transacción.',
 ARRAY['ISO 20022','NIST SP 800-53 AC-3','SIN RND 102100000011'],
 '{"defaults":{"per_operation_bob":50000,"daily_bob":500000,"monthly_bob":5000000},"exceed_action":"require_dual_approval","accumulator_reset":"midnight_local","currency_conversion":"bcb_official_rate"}'),

('POL-D3-APPROVAL-CHAIN', 'Cadena de aprobación de N niveles',
 'Define cadenas de aprobación secuenciales para transacciones. Cada nivel tiene un role_id, max_amount y level_order. La cadena escala automáticamente si el aprobador no actúa.',
 ARRAY['SOX §404','COSO','ISO 20022'],
 '{"max_levels":5,"level_timeout_hours":24,"auto_escalate_after_timeout":true,"skip_level_if_absent":true,"require_final_level_approval":true,"notify_all_pending_every_hours":4}'),

('POL-D3-SIN-COMPLIANCE', 'Cumplimiento fiscal SIN Bolivia',
 'Toda factura electrónica debe cumplir con SIN RND 102100000011: CUFD diario, CUF único por factura, firma XAdES-BES con certificado ADSIB, envío al SIN dentro del plazo.',
 ARRAY['SIN RND 102100000011','Ley 164 Bolivia','ADSIB-FD-POLT-015 v2.3'],
 '{"cufd_renewal":"daily_00_05","cuf_algorithm":"mod11_base16","signature_standard":"xades_bes","certificate":"adsib_persona_juridica","sin_environment":"production","sin_timeout_seconds":30,"max_retries":3}'),

('POL-D3-CURRENCY-CONTROL', 'Control de monedas y tasas de cambio',
 'Define qué monedas están habilitadas, fuente de tasa de cambio, y frecuencia de actualización. Transacciones en moneda extranjera requieren verificación adicional.',
 ARRAY['ISO 4217','NIST SP 800-53 AC-3'],
 '{"default_currency":"BOB","enabled_currencies":["BOB","USD","EUR","ARS","BRL","CLP","PEN"],"exchange_source":"bcb_official","update_frequency_hours":6,"foreign_currency_threshold_usd":10000,"foreign_currency_requires_approval":true}'),

('POL-D3-RECONCILIATION', 'Reconciliación financiera',
 'Define la frecuencia y alcance de la reconciliación entre registros contables y transacciones. Detecta discrepancias y genera alertas automáticas.',
 ARRAY['ISO 20022','SOX §404','NIST SP 800-53 AU-7'],
 '{"frequency":"daily_23_59","tolerance_bob":1.00,"auto_resolve_minor":true,"discrepancy_alert_threshold_bob":100,"reconciliation_window_days":30,"require_sign_off":true}'),

('POL-D3-AUDIT-TRAIL', 'Registro de auditoría financiera inmutable',
 'Cada operación financiera debe registrar: quién, qué, cuándo, monto, moneda, resultado, y hash-chain SHA-256. Los registros son WORM (append-only, sin UPDATE/DELETE).',
 ARRAY['ISO 27001 A.8.15','PCI-DSS 10.3','SOX §404','SIN RND 102100000011'],
 '{"worm_storage":true,"hash_chain":"sha256","required_fields":["timestamp","user_uuid","operation_type","amount","currency","result","ctx_id","prev_hash","entry_hash"],"retention_years":10}'),

('POL-D3-FRAUD-DETECTION', 'Detección de fraude financiero',
 'Reglas de detección de patrones fraudulentos: transacciones inusualmente altas, secuencia anómala, fuera de horario, múltiples intentos fallidos de aprobación.',
 ARRAY['COSO','SOX §404','NIST SP 800-53 SI-4'],
 '{"rules":{"unusual_amount":{"factor":3,"baseline_days":90},"rapid_sequence":{"max_transactions_per_minute":5},"outside_business_hours":{"require_approval":true},"new_beneficiary":{"cooling_period_hours":24}},"response":{"block_and_alert":"critical","require_approval":"high","log_only":"low"}}'),

('POL-D3-BLOCKCHAIN-SETTLEMENT', 'Política de liquidación on-chain D12-B',
 'Liquidaciones entre entidades del consorcio se registran on-chain en red Besu QBFT. PostgreSQL es caché local; la verdad está en blockchain. Ver B29 para implementación.',
 ARRAY['D12 v2.1 §2','EVALUACION GB-13','ISO 20022'],
 '{"threshold_onchain_bob":100000,"confirmations_required":1,"high_value_confirmations":3,"high_value_threshold_bob":1000000,"reconciliation_frequency_minutes":15,"fallback_to_postgresql_if_chain_unavailable":true}');

-- ═══════════════════════════════════════════════════════════════════════════
-- D4 — DOMINIO TEMPORAL: Horarios, turnos, feriados, expiración
-- Estándares: RFC 5545 (iCalendar), ISO 8601, NIST SP 800-63B §7
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_policy_d4 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_policy_d4 (policy_code, policy_name, description, standard_ref, config) VALUES
('POL-D4-SCHEDULE', 'Horarios de acceso por rol y zona',
 'Define horarios permitidos para cada rol y zona. Fuera del horario configurado, el acceso se deniega o requiere step-up MFA. Soporta horarios múltiples por día (ej: mañana y tarde).',
 ARRAY['RFC 5545','ISO 8601','NIST SP 800-63B §7'],
 '{"access_mode":"schedule_restricted","outside_schedule_action":"deny_or_step_up","step_up_required_loa":3,"default_schedule":{"days":[1,2,3,4,5],"start":"08:00","end":"18:00","timezone":"America/La_Paz"}}'),

('POL-D4-HOLIDAYS', 'Feriados y días no laborables',
 'Define el comportamiento durante feriados nacionales, regionales y específicos del tenant. Acceso denegado por defecto excepto para roles de emergencia y seguridad.',
 ARRAY['RFC 5545 §3.8.5','ISO 8601'],
 '{"default_action":"deny","exempt_roles":["SU","SYS","SECURITY","EMERGENCY"],"feriados":"allow_with_step_up","country_code":"BO","include_regional":true,"auto_update_from_calendar":true}'),

('POL-D4-OVERTIME', 'Horas extra y trabajo fuera de horario',
 'Define política de horas extra: requiere aprobación previa, límite máximo de horas extra por día/semana/mes, y tarifa de pago. El acceso al sistema fuera de horario se registra como overtime.',
 ARRAY['ISO 8601','NIST SP 800-53 AC-3'],
 '{"require_pre_approval":true,"max_overtime":{"daily_hours":4,"weekly_hours":20,"monthly_hours":60},"overtime_rate":1.5,"outside_schedule_auto_logs_as_overtime":true,"require_manager_approval":true}'),

('POL-D4-BREAKS', 'Pausas y descansos laborales',
 'Define pausas programadas durante la jornada. Durante la pausa, el acceso al sistema puede restringirse parcialmente (modo descanso: sesión activa pero pantalla bloqueada).',
 ARRAY['ISO 8601','NIST SP 800-53 AC-11'],
 '{"breaks":[{"name":"desayuno","start":"10:00","duration_minutes":15},{"name":"almuerzo","start":"12:30","duration_minutes":60},{"name":"merienda","start":"16:00","duration_minutes":15}],"during_break":"session_lock","session_lock_timeout_seconds":300}'),

('POL-D4-SESSION-EXPIRY', 'Expiración de sesión por inactividad y tiempo máximo',
 'Define TTL máximo de sesión y timeout por inactividad. Cumple NIST SP 800-63B §7: máximo 12 horas de sesión, reautenticación cada 4 horas para operaciones sensibles.',
 ARRAY['NIST SP 800-63B §7','OWASP ASVS V3.3'],
 '{"max_session_duration_hours":8,"inactivity_timeout_minutes":15,"reauth_timeout_hours":4,"reauth_for_sensitive_operations":true,"extend_on_activity":true,"absolute_timeout_hours":12}'),

('POL-D4-ATTENDANCE', 'Control de asistencia por horario',
 'Registra entradas y salidas del sistema como eventos de asistencia laboral. Útil para integración con RRHH y nómina. Detecta ausencias no justificadas y llegadas tarde.',
 ARRAY['ISO 8601','NIST SP 800-53 AC-11'],
 '{"track_attendance":true,"late_threshold_minutes":15,"early_departure_threshold_minutes":15,"absence_alert_after_days":3,"integration_with_hr_system":true}');

-- ═══════════════════════════════════════════════════════════════════════════
-- D5 — DOMINIO BIOMÉTRICO: Autenticación biométrica, liveness, atestación
-- Estándares: ISO/IEC 19794, NIST SP 800-63B §5.2, FIDO Alliance, RGPD Art.9
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_policy_d5 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_policy_d5 (policy_code, policy_name, description, standard_ref, config) VALUES
('POL-D5-LIVENESS', 'Detección de vida (liveness detection)',
 'Verifica que la muestra biométrica pertenece a una persona viva presente (no foto, video, máscara 3D). Nivel activo: desafío-respuesta (parpadeo, giro, sonrisa). Nivel pasivo: análisis de textura y profundidad.',
 ARRAY['ISO/IEC 30107-3','NIST SP 800-63B §5.2','FIDO Alliance'],
 '{"mode":"active_and_passive","active_challenges":["blink","smile","turn_head"],"passive_checks":["texture_analysis","depth_consistency","micro_movements"],"score_threshold":0.95,"max_attempts":3}'),

('POL-D5-FMR-THRESHOLD', 'Umbral de tasa de falsa coincidencia (FMR)',
 'Define la tasa de falsa aceptación máxima permitida para cada tipo biométrico. Huella: FMR ≤ 0.01%. Rostro: FMR ≤ 0.1%. Iris: FMR ≤ 0.001%.',
 ARRAY['ISO/IEC 19795','NIST SP 800-63B §5.2','FIDO Biometrics'],
 '{"fingerprint":{"fmr":0.0001,"fnmr":0.01},"face":{"fmr":0.001,"fnmr":0.01},"iris":{"fmr":0.00001,"fnmr":0.001},"voice":{"fmr":0.01,"fnmr":0.05},"adaptive_threshold":{"enabled":true,"environment_factor":0.1}}'),

('POL-D5-ENROLLMENT', 'Procedimiento de enrolamiento biométrico',
 'Define el flujo de registro biométrico: verificación de identidad IAL2+, captura supervisada, control de calidad, cifrado AES-256-GCM del template, almacenamiento segregado.',
 ARRAY['ISO/IEC 19794','NIST SP 800-63-4 IAL2','RGPD Art.9'],
 '{"ial_required":"IAL2","require_supervisor":true,"quality_threshold":{"fingerprint":{"min_quality_score":80,"min_resolution_dpi":500},"face":{"min_resolution":"1080p","pose_tolerance_degrees":15}},"template_encryption":"aes_256_gcm","template_storage":"segregated_db","retention_policy":"delete_on_offboarding"}'),

('POL-D5-GDPR-CONSENT', 'Consentimiento GDPR para datos biométricos',
 'Los datos biométricos son categoría especial bajo RGPD Art.9. Requiere consentimiento explícito, revocable, con propósito específico. El consentimiento se registra con timestamp y canal.',
 ARRAY['RGPD Art.9','RGPD Art.7','ISO 27001 A.8.2'],
 '{"require_explicit_consent":true,"consent_purpose":"authentication_only","revocable":true,"revocation_action":"delete_template","consent_renewal_months":12,"minor_policy":"require_parental_consent_under_16"}'),

('POL-D5-DEVICE-ATTESTATION', 'Atestación de dispositivo biométrico',
 'Verifica que el dispositivo biométrico es genuino y no ha sido manipulado. Play Integrity (Android) / App Attest (iOS). Puntaje mínimo requerido para considerar el dispositivo confiable.',
 ARRAY['FIDO Alliance','NIST SP 800-63B §5.2','OWASP MASVS V8'],
 '{"android":{"play_integrity_required":true,"min_verdict":"MEETS_DEVICE_INTEGRITY"},"ios":{"app_attest_required":true,"min_attestation_score":0.9},"jailbreak_detection":"block","emulator_detection":"block","attestation_cache_ttl_minutes":60}');

-- ═══════════════════════════════════════════════════════════════════════════
-- D6 — DOMINIO GEOESPACIAL: Geo-fencing, verificación de velocidad, jurisdicción
-- Estándares: ISO 6709, NIST SP 800-207 ZTA, OWASP ASVS V2.8
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_policy_d6 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_policy_d6 (policy_code, policy_name, description, standard_ref, config) VALUES
('POL-D6-GEO-FENCE', 'Geo-cerca: perímetro virtual de acceso',
 'Define áreas geográficas donde el acceso está permitido. Si el usuario está fuera del geo-fence, se deniega el acceso o se requiere step-up. Radio configurable por zona.',
 ARRAY['ISO 6709','NIST SP 800-207','OWASP ASVS V2.8'],
 '{"default_radius_meters":100,"zones":[{"name":"oficina_central","center":{"lat":-16.5,"lon":-68.15},"radius_m":200},{"name":"sucursal_santa_cruz","center":{"lat":-17.78,"lon":-63.18},"radius_m":150}],"outside_fence_action":"deny_or_step_up","accuracy_required_meters":10}'),

('POL-D6-VELOCITY', 'Verificación de velocidad de viaje (impossible travel)',
 'Detecta viajes imposibles: si un usuario se autentica desde dos ubicaciones en un tiempo menor al necesario para viajar entre ellas (>900 km/h), se bloquea y alerta.',
 ARRAY['NIST SP 800-207','OWASP ASVS V2.8','NIST SP 800-63B §7'],
 '{"max_kmh":900,"grace_period_minutes":30,"action":"block_and_alert","track_history_hours":24,"ignored_networks":["vpn_corporate","satellite"]}'),

('POL-D6-LOCATION-TRUST', 'Niveles de confianza por ubicación',
 'Define tiers de confianza para ubicaciones: oficina (trust=alto), hogar registrado (trust=medio), IP móvil (trust=bajo), país extranjero (trust=muy_bajo). El trust level afecta el risk score.',
 ARRAY['NIST SP 800-207','ISO 27001 A.11.1'],
 '{"tiers":[{"name":"corporate_office","trust":0.95,"criteria":["known_ip_range","corporate_wifi","gps_match"]},{"name":"home_office","trust":0.80,"criteria":["registered_ip","known_device"]},{"name":"mobile","trust":0.60,"criteria":["cellular_ip","gps_match"]},{"name":"foreign","trust":0.30,"criteria":["foreign_country","new_ip"]}],"trust_threshold_for_access":0.50}'),

('POL-D6-JURISDICTION', 'Jurisdicción fiscal y restricciones geográficas',
 'Restringe acceso según país/jurisdicción. Algunas operaciones fiscales solo pueden realizarse desde Bolivia. Los datos de ciertas jurisdicciones no pueden cruzar fronteras (data residency).',
 ARRAY['RGPD Art.44-49','Ley 164 Bolivia','NIST SP 800-53 AC-3'],
 '{"restricted_operations_by_country":{"facturacion_sin":["BO"],"datos_fiscales_view":["BO"],"pii_export":[]},"data_residency":"bolivia","cross_border_data_transfer":"blocked_unless_explicitly_authorized"}'),

('POL-D6-IP-RANGE', 'Restricción por rangos IP',
 'Define rangos IP autorizados por tenant, sucursal o zona. Conexiones desde IPs fuera de los rangos autorizados son denegadas o requieren VPN + step-up MFA.',
 ARRAY['RFC 4632','NIST SP 800-207','OWASP ASVS V4.1'],
 '{"default":"deny_all","allowed_ranges":[],"vpn_required_for_outside":true,"ip_spoofing_detection":true,"dynamic_ip_grace_period_hours":4}');

-- ═══════════════════════════════════════════════════════════════════════════
-- D7 — DOMINIO RED: Device trust, VPN, mTLS, Zero Trust Network Access
-- Estándares: NIST SP 800-207 ZTA, SBOS-054, CIS Benchmarks, NSA/CISA K8s
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_policy_d7 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_policy_d7 (policy_code, policy_name, description, standard_ref, config) VALUES
('POL-D7-DEVICE-TRUST', 'Confianza de dispositivo',
 'Evalúa el nivel de confianza del dispositivo: SO actualizado, antivirus activo, firewall habilitado, disco cifrado. Si el puntaje de confianza es inferior al mínimo, se deniega o restringe acceso.',
 ARRAY['NIST SP 800-207','CIS Benchmarks','OWASP ASVS V9'],
 '{"min_trust_score":0.7,"checks":["os_patch_level","antivirus_active","firewall_enabled","disk_encrypted","screen_lock_enabled"],"scoring":{"os_patch_level":0.3,"antivirus":0.2,"firewall":0.2,"encryption":0.2,"screen_lock":0.1},"untrusted_action":"deny_or_vpn_only"}'),

('POL-D7-CIDR', 'Restricción por segmento de red (CIDR)',
 'Define segmentos de red autorizados para acceso a servicios SBOS. Deny-all por defecto. Los CIDR se asignan por tenant, sucursal y zona de seguridad.',
 ARRAY['RFC 4632','RFC 1918','SBOS-054 NRS-05'],
 '{"mode":"whitelist","default_action":"deny","segments":[{"cidr":"10.0.1.0/24","zone":"oficina_principal","trust":"high"},{"cidr":"10.0.2.0/24","zone":"sucursal","trust":"high"},{"cidr":"172.16.0.0/16","zone":"vpn","trust":"medium"}],"dynamic_ip_ttl_seconds":3600}'),

('POL-D7-VPN', 'Requerimiento de VPN para acceso remoto',
 'Acceso desde fuera de la red corporativa requiere VPN activa. Sin VPN, solo se permite acceso a recursos públicos (login page, status). La VPN debe usar mTLS con certificado de dispositivo.',
 ARRAY['NIST SP 800-207','SBOS-054 NRS-07','NSA/CISA K8s Hardening'],
 '{"require_vpn_for_external":true,"vpn_type":"wireguard_or_ipsec","mtls_required":true,"device_cert_required":true,"public_resources_without_vpn":["login","health","status"],"vpn_session_max_hours":12}'),

('POL-D7-MTLS', 'Mutual TLS para comunicación entre servicios',
 'Toda comunicación entre daemons SBOS requiere mTLS. Certificados emitidos por Vault PKI interna. Sin HTTP plano entre servicios (cumple SBOS-050 P9). Rotación automática cada 24h.',
 ARRAY['RFC 8705','SBOS-050 P9','NIST SP 800-52 Rev.2'],
 '{"require_mtls":true,"cert_issuer":"vault_pki_internal","cert_ttl_hours":24,"min_tls_version":"1.3","cipher_suites":["TLS_AES_256_GCM_SHA384","TLS_CHACHA20_POLY1305_SHA256"],"verify_client_cert":true,"crl_check":"ocsp_stapling"}'),

('POL-D7-ZTNA', 'Zero Trust Network Access',
 'Acceso Zero Trust: sin confianza implícita por IP o red. Cada request se autentica y autoriza independientemente. Microsegmentación entre servicios. Verificación continua de postura de seguridad.',
 ARRAY['NIST SP 800-207','SBOS-054 §4','CISA Zero Trust Maturity Model'],
 '{"mode":"strict","implicit_trust_zones":"none","per_request_authz":true,"continuous_verification_interval_seconds":300,"microsegmentation":"enforced_by_calico_network_policy","device_posture_check":"on_every_new_connection"}'),

('POL-D7-CONTINUOUS-VERIFICATION', 'Verificación continua de seguridad de red',
 'Reevalúa la postura de seguridad de la conexión cada N segundos. Si la postura se degrada (ej: desconexión de VPN, cambio de IP), se fuerza reautenticación.',
 ARRAY['NIST SP 800-207','SBOS-054','OWASP ASVS V9'],
 '{"interval_seconds":300,"reevaluate_on":{"ip_change":true,"network_change":true,"device_posture_change":true},"degraded_action":"force_reauth","grace_period_seconds":60}');

-- ═══════════════════════════════════════════════════════════════════════════
-- D8 — DOMINIO CONTEXTO: ctx_id, sesiones, reautenticación, CAEP events
-- Estándares: SBOS-049, NIST SP 800-207, W3C Trace Context, OpenID CAEP 1.0
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_policy_d8 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_policy_d8 (policy_code, policy_name, description, standard_ref, config) VALUES
('POL-D8-CTX-ID', 'Gestión del ctx_id (Context Plane)',
 'Define ciclo de vida del ctx_id: creación (post-auth), propagación (W3C traceparent), validación (Redis lookup), invalidación (logout/timeout). Todo evento del sistema incluye ctx_id.',
 ARRAY['SBOS-049','W3C Trace Context','NIST SP 800-207'],
 '{"ctx_id_format":"uuid_v7","propagation_header":"traceparent","propagation_format":"w3c","cache_ttl_seconds":28800,"validate_on_every_request":true,"invalidate_on_logout":true}'),

('POL-D8-SESSION-TTL', 'TTL de sesión y timeout de inactividad',
 'Define duración máxima de sesión y timeout por inactividad. Cumple NIST SP 800-63B §7: sesiones ≤ 12h, reautenticación cada 4h para operaciones sensibles, timeout inactividad 15min.',
 ARRAY['NIST SP 800-63B §7','OWASP ASVS V3.3','ISO 27001 A.9.4'],
 '{"session_ttl_max_seconds":28800,"inactivity_timeout_seconds":900,"reauth_timeout_seconds":14400,"sensitive_operation_reauth":true,"extend_on_activity":true,"absolute_timeout_seconds":43200}'),

('POL-D8-CONTEXT-SWITCHING', 'Cambio de contexto de sesión',
 'Permite a un usuario cambiar entre contextos (empresa, sucursal, rol activo). El cambio requiere revalidación y queda registrado. Límite de cambios por sesión.',
 ARRAY['SBOS-049','NIST SP 800-63B §7','ISO 27001 A.9.4'],
 '{"allow_context_switch":true,"max_switches_per_session":20,"require_reauth_after_switch":true,"log_every_switch":true,"allowed_switch_types":["empresa","sucursal","rol_activo"],"restricted_switch_types":["tenant"]}'),

('POL-D8-CAEP-EVENTS', 'Eventos CAEP (Continuous Access Evaluation Profile)',
 'Emite eventos CAEP al cambiar estado de seguridad: session-revoked, assurance-level-change, device-posture-change. Consumidos por PEPs (Kong, OAuth2-Proxy) para decisión en tiempo real.',
 ARRAY['OpenID CAEP 1.0','NIST SP 800-207','SBOS-049'],
 '{"event_types":["session-revoked","assurance-level-change","device-posture-change","ip-change","risk-score-change"],"propagation_method":"redis_pubsub","target_latency_ms":500,"require_ack_from_peps":true}'),

('POL-D8-CTX-PROMOTION', 'Promoción dctx_id → ctx_id',
 'Flujo de elevación de contexto: dispositivo arranca → bos crea dctx_id (pre-auth) → usuario login → bAuth promueve dctx_id → ctx_id (post-auth). dctx_id invalidado tras promoción.',
 ARRAY['SBOS-049 §3','NIST SP 800-207','W3C Trace Context'],
 '{"promotion_trigger":"successful_authentication","dctx_invalidation":"immediate_on_promotion","require_device_registration":true,"dctx_ttl_pre_auth_seconds":300,"reject_promotion_if_dctx_expired":true}');

-- ═══════════════════════════════════════════════════════════════════════════
-- D9 — DOMINIO CREDENCIALES: Contraseñas, MFA, recuperación, bloqueo, rotación
-- Estándares: NIST SP 800-63B Rev.4, OWASP ASVS V2, FIDO2, RFC 6238
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_policy_d9 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_policy_d9 (policy_code, policy_name, description, standard_ref, config) VALUES
('POL-D9-PASSWORD', 'Política de contraseñas (NIST 800-63B Rev.4)',
 'Define requisitos de contraseña por tier: longitud mínima (SU:20, SYS:15, BIZ:12, EXT:8), Argon2id params, cribado HIBP k-anonymity diario, prohibición de contraseñas comunes y contextuales.',
 ARRAY['NIST SP 800-63B §5.1.1.2','OWASP ASVS V2.1','ISO 27001 A.9.4'],
 '{"min_length":{"SU":20,"SYS":15,"BIZ":12,"EXT":8,"M2M":0},"hashing":"argon2id","argon2_params":{"SU":{"t":5,"m":128},"SYS":{"t":4,"m":64},"BIZ":{"t":3,"m":32},"EXT":{"t":2,"m":16}},"hibp_check":"daily","hibp_api":"k_anonymity","blocklist":["top100k","context_specific","previously_breached"],"no_forced_rotation_without_evidence":true}'),

('POL-D9-MFA', 'Autenticación multifactor (MFA)',
 'MFA requerido por tier y dominio. SU: FIDO2 HW (AAL3). SYS: TOTP mínimo, FIDO2 recomendado (AAL2). BIZ N4-N5: TOTP. BIZ N1-N3: TOTP opcional. EXT: Passkey opcional. M2M: mTLS.',
 ARRAY['NIST SP 800-63B §5.1','OWASP ASVS V2.8','FIDO2'],
 '{"tier_requirements":{"SU":{"required":true,"min_loa":"AAL3","allowed":["FIDO2_HW"]},"SYS":{"required":true,"min_loa":"AAL2","allowed":["TOTP","FIDO2","FIDO2_HW"]},"BIZ_N4_N5":{"required":true,"min_loa":"AAL2","allowed":["TOTP","FIDO2"]},"BIZ_N1_N3":{"required":false,"allowed":["TOTP"]},"EXT_N0":{"required":false,"allowed":["PASSKEY"]},"M2M":{"required":true,"method":"MTLS"}},"grace_period_days":7,"recovery_codes_count":10}'),

('POL-D9-RECOVERY', 'Recuperación de acceso',
 'Flujo de recuperación: verificación de identidad → link temporal (5min, single-use) → nueva contraseña. Recovery codes (10, SHA-256, single-use) como fallback MFA. Sin bypass de MFA.',
 ARRAY['NIST SP 800-63B §5.1.6','OWASP ASVS V2.5','RGPD Art.32'],
 '{"identity_verification":"ial_same_as_enrollment","recovery_link_ttl_minutes":5,"recovery_link_single_use":true,"recovery_codes":{"count":10,"hash":"sha256","single_use":true},"admin_reset_requires_approval":true,"notify_user_on_recovery":true}'),

('POL-D9-LOCKOUT', 'Política de bloqueo por intentos fallidos',
 'Bloqueo progresivo: 5 fallos → 15min. 10 fallos → 1h. 20 fallos → permanente (requiere admin). Rate limiting: 1 intento/segundo por cuenta. Notificación al usuario al ser bloqueado.',
 ARRAY['NIST SP 800-63B §5.2.2','OWASP ASVS V2.2','ISO 27001 A.9.4'],
 '{"thresholds":[{"attempts":5,"lockout_minutes":15},{"attempts":10,"lockout_minutes":60},{"attempts":20,"lockout":"permanent"}],"rate_limit":"1_per_second_per_account","counter_reset_minutes":30,"notify_user_on_lockout":true,"admin_unlock_requires_audit":true}'),

('POL-D9-ROTATION', 'Rotación de credenciales',
 'Define política de rotación por tipo: passwords de servicio (90 días), API keys (90 días con dual-credential), certificados mTLS (24h), TOTP seeds (solo en compromiso). Sin rotación forzada de passwords humanos.',
 ARRAY['NIST SP 800-63B §5.1.1.2','NIST SP 800-57','OWASP ASVS V6'],
 '{"service_passwords_days":90,"api_keys_days":90,"mtls_certs_hours":24,"totp_seeds":"on_compromise_only","human_passwords":"no_forced_rotation","rotation_method":"dual_credential_zero_downtime","alert_before_expiry_days":[30,14,7,1]}'),

('POL-D9-PHISHING-RESISTANCE', 'Resistencia a phishing (FIDO2/WebAuthn)',
 'FIDO2/WebAuthn es el estándar de autenticación resistente a phishing. Passkeys sincronizables (AAL2) o vinculadas a dispositivo (AAL3). El origen criptográfico se verifica en cada autenticación.',
 ARRAY['NIST SP 800-63B §5.1','FIDO2','W3C WebAuthn Level 2'],
 '{"require_phishing_resistant_for":{"SU":"AAL3_FIDO2_HW","SYS":"AAL2_FIDO2_or_TOTP","D3_above_10k_usd":"AAL3"},"passkey_syncable_allowed":true,"webauthn_attestation":"direct","rp_id":"sbos.skull.bo","user_verification":"required"}'),

('POL-D9-STEP-UP', 'Step-Up Authentication (RFC 9470)',
 'Elevación temporal de LoA para operaciones específicas. Cajero AAL2→AAL3 para arqueo. Máximo 15 minutos de elevación. Auditoría obligatoria de cada step-up.',
 ARRAY['RFC 9470','NIST SP 800-63B §5.1','OWASP ASVS V2.8'],
 '{"max_elevation_minutes":15,"triggers":[{"operation":"arqueo_caja","from":"AAL2","to":"AAL3"},{"operation":"aprobacion_monto_alto","from":"AAL2","to":"AAL3","threshold_bob":100000}],"require_audit":true,"reuse_elevation_within_window":false}'),

('POL-D9-M2M-CREDENTIALS', 'Credenciales Machine-to-Machine',
 'Identidades no humanas usan mTLS + client_credentials (OAuth 2.0). Sin password. Certificados de corta vida (24h) emitidos por Vault PKI. Rotación automática sin downtime.',
 ARRAY['RFC 8705','OAuth 2.0 RFC 6749','NIST SP 800-63-4 M2M'],
 '{"method":"mtls_plus_client_credentials","cert_ttl_hours":24,"rotation":"automatic_dual_credential","no_password":true,"allowed_grants":["client_credentials","token_exchange"],"require_signed_jwt":true}'),

('POL-D9-CIBA', 'Client-Initiated Backchannel Authentication (CIBA)',
 'Autenticación desacoplada para dispositivos sin navegador. El usuario recibe notificación push en su dispositivo y aprueba/deniega. Útil para POS, cajeros automáticos y flujos presenciales.',
 ARRAY['OpenID CIBA','RFC 8628','NIST SP 800-63B §5.1'],
 '{"auth_req_id_ttl_seconds":300,"polling_interval_seconds":5,"max_polling_duration_seconds":300,"push_notification_required":true,"user_verification":"biometric_or_pin"}'),

('POL-D9-TOKEN-BINDING', 'Binding de token a cliente (mTLS + DPoP)',
 'Tokens OAuth vinculados al cliente que los solicitó. mTLS binding (SU/M2M) o DPoP (SYS). PKCE obligatorio para todos los clientes públicos. Previene token theft y replay.',
 ARRAY['RFC 8705','RFC 9449','OAuth 2.1 BCP'],
 '{"binding_methods":{"SU":"mtls","SYS":"dpop","M2M":"mtls","BIZ":"pkce","EXT":"pkce"},"pkce_required_for_public_clients":true,"dpop_required_for_sys_tier":true,"token_replay_detection":true}'),

('POL-D9-AUTH-FLOW', 'Configuración de flujos de autenticación',
 'Define flujos de autenticación disponibles por tier y aplicación. Authorization Code + PKCE para todos. ROPC e Implicit deshabilitados. Device Flow para dispositivos sin navegador.',
 ARRAY['OAuth 2.0 RFC 6749','OAuth 2.1 BCP','OpenID Connect 1.0'],
 '{"enabled_flows":["authorization_code","client_credentials","device_authorization","token_exchange","ciba"],"disabled_flows":["implicit","password"],"pkce_required":true,"pkce_challenge_method":"S256","require_consent_for_third_party":true}');

-- ═══════════════════════════════════════════════════════════════════════════
-- D10 — DOMINIO DELEGACIÓN: Delegación temporal, break-glass, auto-revocación
-- Estándares: NIST SP 800-53 AC-2, ISO 27001 A.9.2, OWASP ASVS V4.3
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_policy_d10 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_policy_d10 (policy_code, policy_name, description, standard_ref, config) VALUES
('POL-D10-MAX-DURATION', 'Duración máxima de delegación',
 'Define duración máxima de delegación por tipo: estándar (21 días), extendida (90 días con aprobación), emergencia (4 horas). Auto-revocación al expirar. Notificación al delegado y delegante.',
 ARRAY['NIST SP 800-53 AC-2(2)','ISO 27001 A.9.2','OWASP ASVS V4.3'],
 '{"max_durations":{"standard_days":21,"extended_days":90,"emergency_hours":4},"extended_requires_approval":true,"auto_revoke_on_expiry":true,"notify_both_parties":true,"renewal_allowed":false}'),

('POL-D10-NON-DELEGABLE', 'Capacidades no delegables',
 'Define átomos y capacidades que NUNCA pueden ser delegados: SuperUser, break-glass, cambio de seguridad, aprobación de auditoría, modificación de políticas.',
 ARRAY['NIST SP 800-53 AC-5','ISO 27001 A.9.2','SOX §404'],
 '{"non_delegable_atoms":["SU_ACTIVATE","BREAK_GLASS","CHANGE_SECURITY_POLICY","APPROVE_AUDIT","MODIFY_SOD_MATRIX","DELETE_AUDIT_LOG"],"non_delegable_roles":["SU","S002","S003"],"violation_action":"block_delegation_and_alert"}'),

('POL-D10-CHAIN-DEPTH', 'Profundidad máxima de cadena de delegación',
 'Limita la profundidad de redelegación. Default: 1 nivel (no se puede redelegar). Máximo: 2 niveles con aprobación de seguridad. Previene cadenas de delegación incontrolables.',
 ARRAY['NIST SP 800-53 AC-2','ISO 27001 A.9.2'],
 '{"max_chain_depth":1,"depth_2_requires_security_approval":true,"depth_3_and_above":"blocked","log_entire_chain":true,"visualize_chain_in_ui":true}'),

('POL-D10-AUTO-REVOKE', 'Auto-revocación por eventos',
 'Revoca delegación automáticamente cuando: (1) delegante sale de vacaciones, (2) delegante es desactivado, (3) delegante cambia de rol, (4) se detecta uso anómalo, (5) conflicto SoD sobreviviente.',
 ARRAY['NIST SP 800-53 AC-2','ISO 27001 A.9.2','SOX §404'],
 '{"auto_revoke_triggers":["granter_vacation","granter_deactivated","granter_role_changed","anomalous_usage_detected","sod_conflict_surfaces"],"revocation_delay_seconds":0,"notify_granter_and_grantee":true,"log_auto_revoke_reason":true}');

-- ═══════════════════════════════════════════════════════════════════════════
-- D11 — DOMINIO AUDITORÍA: Retención, hash-chain, revisión, cumplimiento
-- Estándares: ISO 27001 A.8.15, NIST SP 800-53 AU, PCI-DSS 10, SOX §404
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_policy_d11 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_policy_d11 (policy_code, policy_name, description, standard_ref, config) VALUES
('POL-D11-RETENTION', 'Retención de registros de auditoría',
 'Define períodos de retención: auth events (12 meses), audit events (10 años fiscal Bolivia), datos personales (GDPR: mínimo necesario). Purgado automático al expirar retención con DROP PARTITION.',
 ARRAY['ISO 27001 A.8.15','PCI-DSS 10.7','SOX §404','Ley 2492 Bolivia','RGPD Art.17'],
 '{"retention_periods":{"auth_events_months":12,"audit_events_years":10,"pii_data":"minimum_necessary"},"purge_method":"drop_partition","anonymize_before_delete":true,"fiscal_retention_bolivia_days":2555,"require_legal_hold_override":true}'),

('POL-D11-HASH-CHAIN', 'Hash-chain SHA-256 para integridad de auditoría',
 'Cada evento de auditoría incluye hash del evento anterior (SHA-256). La cadena completa es verificable. Cualquier alteración rompe la cadena y dispara alerta P1.',
 ARRAY['ISO 27001 A.8.15','PCI-DSS 10.5','NIST SP 800-53 AU-9'],
 '{"algorithm":"sha256","chain_per_ctx_id":true,"verification_frequency_hours":1,"chain_broken_action":"alert_p1","recalculate_hash_on_insert":true,"prev_hash_column":"prev_hash","entry_hash_column":"entry_hash"}'),

('POL-D11-REVIEW-FREQUENCY', 'Frecuencia de revisión de accesos',
 'Define frecuencia de revisión: SU y SYS (mensual), BIZ N4-N5 (trimestral), BIZ N1-N3 (semestral), EXT N0 (anual), M2M (trimestral). Campañas automáticas con notificación al manager.',
 ARRAY['ISO 27001 A.9.2.5','NIST SP 800-53 AC-6','SOX §404'],
 '{"review_frequencies":{"SU":"monthly","SYS":"monthly","BIZ_N4_N5":"quarterly","BIZ_N1_N3":"semi_annual","EXT_N0":"annual","M2M":"quarterly"},"auto_launch_campaigns":true,"escalation_timeout_days":14,"auto_revoke_if_no_response":true}'),

('POL-D11-REGULATORY-MAPPING', 'Mapeo de controles a marcos regulatorios',
 'Mapea cada evento de auditoría a controles específicos de: ISO 27001, PCI-DSS, SOX, GDPR. Facilita la generación de reportes de cumplimiento y la respuesta a auditorías externas.',
 ARRAY['ISO 27001','PCI-DSS 4.0','SOX §404','RGPD','NIST SP 800-53'],
 '{"frameworks":{"iso_27001":{"controls":["A.8.15","A.8.16","A.9.2","A.12.4"]},"pci_dss":{"controls":["10.1","10.2","10.3","10.5"]},"sox":{"controls":["302","404"]},"gdpr":{"controls":["Art.30","Art.33"]}},"auto_generate_compliance_report":true,"export_format":["pdf","csv","json"]}');

-- ═══════════════════════════════════════════════════════════════════════════
-- D12 — DOMINIO BLOCKCHAIN: Anclaje Merkle, DIDs, proof types, smart contracts
-- Estándares: RFC 6962, NIST IR 8202, EIP-1559, EVALUACION v2.2 §16
-- ═══════════════════════════════════════════════════════════════════════════
TRUNCATE bauth.ath_policy_d12 RESTART IDENTITY CASCADE;

INSERT INTO bauth.ath_policy_d12 (policy_code, policy_name, description, standard_ref, config) VALUES
('POL-D12-MERKLE-ANCHOR', 'Anclaje Merkle en Arbitrum One L2',
 'Cada hora, los eventos de auditoría se empaquetan en un árbol Merkle (Keccak-256). La raíz se ancla en Arbitrum One vía smart contract. Gold tier: anclaje cada 1h. Verificable sin acceso a BD.',
 ARRAY['RFC 6962','NIST IR 8202','EIP-1559'],
 '{"tier":"gold","batch_interval_seconds":3600,"hash_algorithm":"keccak256","tree_structure":"binary_rfc6962","domain_separation":{"leaf":"0x00","node":"0x01"},"gas_limit":100000,"max_priority_fee_gwei":1}'),

('POL-D12-DID-METHOD', 'Identificadores Descentralizados (DID)',
 'Soporte para DID methods: did:web (resolución vía HTTPS), did:ion (Sidetree sobre Bitcoin). Credenciales verificables en formatos JWT-VC y LDP-VC. Planeado para release futuro.',
 ARRAY['W3C DID Core','W3C VC Data Model','did:ion Sidetree'],
 '{"status":"planned","target_release":"2027","supported_methods":["did:web","did:ion"],"vc_formats":["jwt_vc","ldp_vc"],"resolution_cache_minutes":60,"algorithm":"EdDSA_Ed25519"}'),

('POL-D12-PROOF-TYPES', 'Tipos de prueba de integridad soportados',
 'Define los tipos de prueba que el sistema puede generar y verificar: Merkle inclusion proof (evento pertenece al lote), Merkle consistency proof (lote A es prefijo de lote B), on-chain verification.',
 ARRAY['RFC 6962 §2.1','NIST IR 8202','EVALUACION GA-04'],
 '{"proof_types":{"merkle_inclusion":{"description":"Prueba que un evento está en un lote anclado","complexity":"O(log n)"},"merkle_consistency":{"description":"Prueba que el lote A es prefijo del lote B","complexity":"O(log n)"},"onchain_verification":{"description":"Verificar directamente en Arbitrum One","requires_rpc":true}},"verification_modes":["online","offline_cli","wasm_browser"]}'),

('POL-D12-SMART-CONTRACT', 'Smart contract de anclaje (AuditAnchor.sol)',
 'Contrato Solidity 0.8.26 desplegado en Arbitrum One. Función anchor(bytes32,uint256,uint256) y verify(uint256,bytes32). Gas optimizado (~45K por anclaje). Address verificado en Arbiscan.',
 ARRAY['EIP-1559','Solidity 0.8.x','OpenZeppelin'],
 '{"contract_name":"AuditAnchor","solidity_version":"0.8.26","network":"arbitrum_one","functions":{"anchor":"anchor(bytes32 merkleRoot, uint256 batchNumber, uint256 timestamp)","verify":"verify(uint256 batchNumber, bytes32 merkleRoot) returns (bool)"},"gas_per_anchor":45000,"verified_on_arbiscan":true}'),

('POL-D12-SETTLEMENT', 'Liquidación on-chain (Variante B — Besu QBFT)',
 'Red Hyperledger Besu QBFT con 4 validadores. Liquidaciones entre entidades del consorcio se ejecutan on-chain. PostgreSQL es caché local. Reconciliación cada 15 minutos.',
 ARRAY['EVALUACION GB-01','Hyperledger Besu QBFT','EIP-1559'],
 '{"status":"variant_b","network":"besu_qbft_private","validators":4,"consensus":"qbft","block_period_seconds":2,"gas_limit":134217727,"min_gas_price":0,"settlement_time_seconds":2,"reconciliation_frequency_minutes":15}'),

('POL-D12-RECONCILIATION', 'Reconciliación on-chain ↔ PostgreSQL',
 'Compara estado on-chain con PostgreSQL cada 15min. Si diff > umbral → forensic replay (reprocesar eventos SettlementExecuted desde último bloque reconciliado). Doble contabilidad durante migración.',
 ARRAY['EVALUACION GB-11','ISO 20022','NIST IR 8202'],
 '{"frequency_minutes":15,"diff_tolerance_bob":0.01,"forensic_replay_on_diff":true,"double_entry_during_migration":true,"reconciliation_log_table":"blk_reconciliation","alert_if_diff_exceeds_tolerance":true}');

COMMIT;
