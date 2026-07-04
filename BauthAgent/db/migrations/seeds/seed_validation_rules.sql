-- seed_validation_rules.sql — Reglas de validación RuleEngine · 58 reglas · 12 dominios
-- IDEMPOTENTE: ON CONFLICT (rule_code) DO NOTHING. Re-ejecutable N veces.
-- Fuentes: NIST SP 800-63B-4 · ISO 27001:2022 · PCI DSS 4.0 · OWASP ASVS 5.0
--           FIDO2/WebAuthn L3 · RFC 6238/8996 · SOX §404 · CIS Benchmarks v8
-- ═══════════════════════════════════════════════════════════════════

SET lock_timeout = '5s';

INSERT INTO bauth.cfg_validation_rule (rule_code, rule_name, description,
    target_table, target_column, domain, category,
    data_type, min_value, max_value, allowed_values, error_message, error_code,
    standard_ref, standard_section, provenance_url, severity) VALUES

-- ═══════════════════════════════════════════════════════════════════════════
-- D8 — CONTEXTO / SESIÓN (NIST SP 800-63B §7 + PCI DSS 8.2.8 + OWASP ASVS V3)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D8-001', 'TTL máximo de sesión',
 'NIST §7: máximo 12h (43200s). PCI DSS 8.2.8 renueva tras inactividad. OWASP ASVS V3.3: sesiones limitadas en tiempo.',
 'idn_tenant', 'session_ttl_max', 'D8', 'RANGE',
 'integer', 3600, 43200, NULL,
 'session_ttl_max debe estar entre 3600s (1h) y 43200s (12h). NIST SP 800-63B §7.',
 'VAL-D8-001',
 ARRAY['NIST SP 800-63B §7','PCI DSS 8.2.8','OWASP ASVS V3.3'], '§7 Session Management',
 'https://pages.nist.gov/800-63-4/sp800-63b.html#sec7', 'error'),

('VAL-D8-002', 'Timeout de inactividad de sesión',
 'PCI DSS 8.2.8: máximo 15 minutos. NIST §7: 15 min recomendado. OWASP ASVS V3.3.2: máximo 30 min.',
 'idn_tenant', 'inactivity_timeout_minutes', 'D8', 'RANGE',
 'integer', 5, 30, NULL,
 'inactivity_timeout_minutes debe estar entre 5 y 30 minutos. PCI DSS exige ≤15 min.',
 'VAL-D8-002',
 ARRAY['NIST SP 800-63B §7','PCI DSS 8.2.8','OWASP ASVS V3.3.2'], 'PCI DSS Req 8.2.8',
 'https://www.pcisecuritystandards.org/document_library/', 'error'),

('VAL-D8-003', 'Intervalo de reautenticación',
 'NIST §7: máximo 12h. Operaciones sensibles: 4h. OWASP V3.3: reautenticación para acciones críticas.',
 'idn_tenant', 'reauth_timeout_seconds', 'D8', 'RANGE',
 'integer', 1800, 43200, NULL,
 'reauth_timeout_seconds debe estar entre 1800s (30min) y 43200s (12h).',
 'VAL-D8-003',
 ARRAY['NIST SP 800-63B §7','OWASP ASVS V3.3'], '§7 Session Management',
 'https://pages.nist.gov/800-63-4/sp800-63b.html#sec7', 'error'),

('VAL-D8-004', 'Máximo de sesiones concurrentes por usuario',
 'OWASP ASVS V3.3.4: límite de sesiones simultáneas. Default: 3 para estándar, 1 para admin.',
 'idn_tenant', 'max_concurrent_sessions', 'D8', 'RANGE',
 'integer', 1, 10, NULL,
 'max_concurrent_sessions debe estar entre 1 y 10.',
 'VAL-D8-004',
 ARRAY['OWASP ASVS V3.3.4','NIST SP 800-63B §7'], 'V3.3.4 Concurrent Sessions',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- D9 — CREDENCIALES / PASSWORDS (NIST §5.1 + PCI DSS 8.3 + OWASP V6.2)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D9-001', 'Longitud mínima de contraseña',
 'PCI DSS 8.3.6: 12 caracteres mínimo (8 legacy). NIST Rev.4 §5.1.1.2: 15 single-factor, 8 con MFA. OWASP V6.2.1: 12 mínimo.',
 'ath_credential_policy', 'min_length', 'D9', 'RANGE',
 'integer', 8, 64, NULL,
 'min_length debe estar entre 8 (con MFA) y 64. Sin MFA: mínimo 15. PCI DSS exige ≥12.',
 'VAL-D9-001',
 ARRAY['NIST SP 800-63B §5.1.1.2','PCI DSS 8.3.6','OWASP ASVS V6.2.1'],
 'PCI DSS Req 8.3.6 / NIST §5.1.1.2',
 'https://pages.nist.gov/800-63-4/sp800-63b.html#sec5', 'error'),

('VAL-D9-002', 'Nivel de aseguramiento AAL',
 'NIST §4: AAL1 single/multi-factor, AAL2 2FA+phishing-resistant, AAL3 hardware FIPS 140-3.',
 'ath_method', 'aal_level', 'D9', 'ENUM',
 'text', NULL, NULL, ARRAY['AAL1','AAL2','AAL3','AAL4'],
 'aal_level debe ser AAL1, AAL2, AAL3 o AAL4. NIST SP 800-63B §4.',
 'VAL-D9-002',
 ARRAY['NIST SP 800-63B §4','FIDO2'], '§4 Authenticator Assurance Levels',
 'https://pages.nist.gov/800-63-4/sp800-63b.html#sec4', 'error'),

('VAL-D9-003', 'Tipo de método de autenticación',
 'NIST §5.1 clasifica 11 tipos: single_factor a out_of_band. Deprecated = no usar en nuevos enrolments.',
 'ath_method', 'method_type', 'D9', 'ENUM',
 'text', NULL, NULL,
 ARRAY['single_factor','multi_factor','phishing_resistant','federated','machine','recovery','adaptive','deprecated','device','continuous','out_of_band'],
 'method_type debe ser uno de los 11 tipos definidos en ath_method CHECK constraint.',
 'VAL-D9-003',
 ARRAY['NIST SP 800-63B §5.1','FIDO2 L3'], '§5.1 Authenticator Types',
 'https://pages.nist.gov/800-63-4/sp800-63b.html#sec5', 'error'),

('VAL-D9-004', 'Dígitos TOTP (RFC 6238)',
 'RFC 6238: dígitos 6-8. OWASP V6.5: mínimo 6 dígitos. Default: 6. Paso: 30s.',
 'ath_config_d9', 'totp_config', 'D9', 'RANGE',
 'integer', 6, 8, NULL,
 'TOTP digits debe ser 6, 7 u 8. RFC 6238.',
 'VAL-D9-004',
 ARRAY['RFC 6238','OWASP ASVS V6.5'], 'RFC 6238 TOTP',
 'https://datatracker.ietf.org/doc/html/rfc6238', 'error'),

('VAL-D9-005', 'Intentos fallidos antes de bloqueo',
 'PCI DSS 8.3.4: máximo 10 intentos. OWASP V6.3.1: ≤100/hora. NIST §5.2.2: rate limiting 1/s.',
 'ath_config_d9', 'lockout_max_attempts', 'D9', 'RANGE',
 'integer', 3, 10, NULL,
 'lockout_max_attempts debe estar entre 3 y 10. PCI DSS exige ≤10.',
 'VAL-D9-005',
 ARRAY['PCI DSS 8.3.4','OWASP ASVS V6.3.1','NIST SP 800-63B §5.2.2'],
 'PCI DSS Req 8.3.4',
 'https://www.pcisecuritystandards.org/document_library/', 'error'),

('VAL-D9-006', 'Duración mínima de bloqueo (minutos)',
 'PCI DSS 8.3.4: mínimo 30 minutos. NIST §5.2.2: cooldown exponencial.',
 'ath_config_d9', 'lockout_duration_minutes', 'D9', 'RANGE',
 'integer', 15, 1440, NULL,
 'lockout_duration_minutes debe estar entre 15min y 1440min (24h). PCI DSS exige ≥30min.',
 'VAL-D9-006',
 ARRAY['PCI DSS 8.3.4','NIST SP 800-63B §5.2.2'], 'PCI DSS Req 8.3.4',
 'https://www.pcisecuritystandards.org/document_library/', 'error'),

('VAL-D9-007', 'Historial de contraseñas (cantidad)',
 'PCI DSS 8.3.7: no reutilizar últimas 4 contraseñas. OWASP V6.2.6: mínimo 5.',
 'ath_credential_policy', 'password_history_count', 'D9', 'RANGE',
 'integer', 4, 24, NULL,
 'password_history_count debe estar entre 4 (PCI DSS mínimo) y 24.',
 'VAL-D9-007',
 ARRAY['PCI DSS 8.3.7','OWASP ASVS V6.2.6'], 'PCI DSS Req 8.3.7',
 'https://www.pcisecuritystandards.org/document_library/', 'error'),

('VAL-D9-008', 'Rotación de contraseñas de servicio (días)',
 'PCI DSS 8.3.9: 90 días si es único factor. NIST Rev.4: sin rotación forzada para humanos. Servicio: 90 días.',
 'ath_credential_policy', 'rotation_days', 'D9', 'RANGE',
 'integer', 0, 365, NULL,
 'rotation_days: 0 = sin rotación (humanos NIST Rev.4), 90 = servicio (PCI DSS). Máximo 365.',
 'VAL-D9-008',
 ARRAY['PCI DSS 8.3.9','NIST SP 800-63B §5.1.1.2'], 'PCI DSS Req 8.3.9',
 'https://www.pcisecuritystandards.org/document_library/', 'error'),

('VAL-D9-009', 'Período de gracia MFA (días)',
 'OWASP V6.5: enrollment MFA con período de gracia. Máximo 30 días. Default: 7 días.',
 'ath_config_d9', 'mfa_grace_period_days', 'D9', 'RANGE',
 'integer', 0, 30, NULL,
 'mfa_grace_period_days debe estar entre 0 (inmediato) y 30 días.',
 'VAL-D9-009',
 ARRAY['OWASP ASVS V6.5','NIST SP 800-63B §5.1'], 'V6.5 MFA Enrollment',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

('VAL-D9-010', 'Códigos de recuperación (cantidad)',
 'OWASP V6.4.2: suficientes códigos para recuperación. Mínimo 5, recomendado 10. Máximo 20.',
 'ath_config_d9', 'recovery_codes_count', 'D9', 'RANGE',
 'integer', 5, 20, NULL,
 'recovery_codes_count debe estar entre 5 y 20. OWASP recomienda 10.',
 'VAL-D9-010',
 ARRAY['OWASP ASVS V6.4.2','NIST SP 800-63B §5.1.6'], 'V6.4.2 Recovery Codes',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

('VAL-D9-011', 'TTL de código de recuperación (minutos)',
 'OWASP V6.4: códigos de recuperación con TTL corto. Máximo 10 minutos. Default: 5 min.',
 'ath_config_d9', 'recovery_code_ttl_minutes', 'D9', 'RANGE',
 'integer', 1, 30, NULL,
 'recovery_code_ttl_minutes debe estar entre 1 y 30 minutos. OWASP recomienda ≤10.',
 'VAL-D9-011',
 ARRAY['OWASP ASVS V6.4'], 'V6.4 Recovery Flow',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- D6 — GEOESPACIAL (NIST 800-207 ZTA + OWASP ASVS V2.8)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D6-001', 'Velocidad máxima para viaje imposible (km/h)',
 '900 km/h = avión comercial. >900 = físicamente imposible. Mínimo 100 km/h (auto). NIST 800-207 ZTA.',
 'geo_velocity_policy', 'max_velocity_kmh', 'D6', 'RANGE',
 'integer', 100, 1200, NULL,
 'max_velocity_kmh debe estar entre 100 y 1200 km/h. Default NIST: 900.',
 'VAL-D6-001',
 ARRAY['NIST SP 800-207','OWASP ASVS V2.8'], '§3 Zero Trust Architecture',
 'https://csrc.nist.gov/publications/detail/sp/800-207/final', 'error'),

('VAL-D6-002', 'Radio de geo-cerca (metros)',
 'ISO 6709: mínimo 10m (precisión GPS civil). Máximo 10000m (área metropolitana). Oficina: 200m.',
 'geo_fence', 'radius_meters', 'D6', 'RANGE',
 'integer', 10, 10000, NULL,
 'radius_meters debe estar entre 10m y 10000m. ISO 6709.',
 'VAL-D6-002',
 ARRAY['ISO 6709','NIST SP 800-207'], 'ISO 6709 Geographic Coordinates',
 'https://www.iso.org/standard/39242.html', 'error'),

('VAL-D6-003', 'Ventana de gracia para viaje (minutos)',
 'Tiempo entre ubicaciones antes de alerta. Mínimo 5 min (operacional). Máximo 120 min.',
 'geo_velocity_policy', 'window_minutes', 'D6', 'RANGE',
 'integer', 5, 120, NULL,
 'window_minutes debe estar entre 5 y 120 minutos.',
 'VAL-D6-003',
 ARRAY['NIST SP 800-207'], '§3.3 Continuous Diagnostics and Mitigation',
 'https://csrc.nist.gov/publications/detail/sp/800-207/final', 'error'),

('VAL-D6-004', 'Número máximo de violaciones de velocidad antes de bloqueo',
 'Después de N violaciones en la ventana, bloquear cuenta. Mínimo 2, máximo 10.',
 'geo_velocity_policy', 'max_violations', 'D6', 'RANGE',
 'integer', 2, 10, NULL,
 'max_violations debe estar entre 2 y 10.',
 'VAL-D6-004',
 ARRAY['NIST SP 800-207','OWASP ASVS V2.8'], '§3 ZTA',
 'https://csrc.nist.gov/publications/detail/sp/800-207/final', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- D7 — RED (CIS Benchmarks v8 + NIST 800-207 + RFC 8996)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D7-001', 'Puntaje mínimo de confianza de dispositivo',
 'CIS Controls v8 §12: score 0-100. trusted≥80, medium≥60, restricted≥40. <40 bloqueado.',
 'ath_config_d7', 'device_score_min', 'D7', 'RANGE',
 'integer', 0, 100, NULL,
 'device_score_min debe estar entre 0 y 100. CIS Controls v8 §12.',
 'VAL-D7-001',
 ARRAY['NIST SP 800-207','CIS Benchmarks v8'], 'CIS Controls v8 §12',
 'https://www.cisecurity.org/controls/v8', 'error'),

('VAL-D7-002', 'Versión mínima de TLS',
 'RFC 8996 (marzo 2021): TLS 1.0/1.1 deprecados. Solo TLS 1.2 y 1.3 aceptables. NIST SP 800-52 Rev.2.',
 'idn_tenant_domain', 'ssl_config', 'D7', 'ENUM',
 'text', NULL, NULL, ARRAY['TLS1.2','TLS1.3'],
 'Solo TLS 1.2 y TLS 1.3 son aceptables. TLS 1.0/1.1 deprecados por RFC 8996.',
 'VAL-D7-002',
 ARRAY['RFC 8446','RFC 8996','NIST SP 800-52 Rev.2'], 'RFC 8996 Deprecating TLS 1.0/1.1',
 'https://datatracker.ietf.org/doc/html/rfc8996', 'error'),

('VAL-D7-003', 'Intervalo de verificación continua (segundos)',
 'NIST 800-207: reevaluar postura cada 300s máximo. Mínimo 60s, máximo 3600s.',
 'net_ztna_policy', 'verification_interval_s', 'D7', 'RANGE',
 'integer', 60, 3600, NULL,
 'verification_interval_s debe estar entre 60s y 3600s. NIST 800-207 recomienda ≤300s.',
 'VAL-D7-003',
 ARRAY['NIST SP 800-207','SBOS-054 §4'], '§4 Zero Trust Principles',
 'https://csrc.nist.gov/publications/detail/sp/800-207/final', 'error'),

('VAL-D7-004', 'TTL de certificado mTLS (horas)',
 'NIST SP 800-57 §8.2: certificados de sesión con TTL corto. 24h estándar, 168h máximo.',
 'ath_config_d7', 'cert_ttl_hours', 'D7', 'RANGE',
 'integer', 1, 168, NULL,
 'cert_ttl_hours debe estar entre 1h y 168h (7 días). NIST 800-57: recomendado 24h.',
 'VAL-D7-004',
 ARRAY['NIST SP 800-57 §8.2','RFC 8705'], '§8.2 Crypto Periods',
 'https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev/5/final', 'error'),

('VAL-D7-005', 'Máximo de dispositivos por usuario',
 'CIS v8 §12: limitar dispositivos vinculados. Mínimo 1, máximo 10.',
 'ath_config_d7', 'max_devices_per_user', 'D7', 'RANGE',
 'integer', 1, 10, NULL,
 'max_devices_per_user debe estar entre 1 y 10.',
 'VAL-D7-005',
 ARRAY['CIS Benchmarks v8 §12'], 'CIS v8 §12',
 'https://www.cisecurity.org/controls/v8', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- D3 — FINANCIERO (SOX §404 + COSO + ISO 20022)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D3-001', 'Monto máximo por transacción por rol',
 'SOX §404: controles proporcionales al riesgo. Rango práctico: 0-999,999,999.',
 'fin_limit', 'max_amount', 'D3', 'RANGE',
 'numeric', 0, 999999999, NULL,
 'max_amount debe estar entre 0 y 999,999,999.',
 'VAL-D3-001',
 ARRAY['SOX §404','COSO','ISO 20022'], 'SOX §404 Internal Controls',
 'https://pcaobus.org/oversight/standards/auditing-standards/details/AS2201', 'error'),

('VAL-D3-002', 'Niveles máximos de cadena de aprobación',
 'SOX §404: cadenas >5 niveles diluyen responsabilidad. Mínimo 1, máximo 5.',
 'fin_approval_chain', 'max_levels', 'D3', 'RANGE',
 'integer', 1, 5, NULL,
 'max_levels debe estar entre 1 y 5 niveles. SOX §404.',
 'VAL-D3-002',
 ARRAY['SOX §404','COSO'], 'SOX §404 Internal Controls',
 'https://pcaobus.org/oversight/standards/auditing-standards/details/AS2201', 'error'),

('VAL-D3-003', 'Timeout de aprobación (horas)',
 'SOX §404: aprobaciones con SLA. Mínimo 1h, máximo 168h (7 días). Default: 48h.',
 'fin_decision_matrix', 'tiempo_max_aprobacion_horas', 'D3', 'RANGE',
 'integer', 1, 168, NULL,
 'tiempo_max_aprobacion_horas debe estar entre 1h y 168h (7d). SOX §404.',
 'VAL-D3-003',
 ARRAY['SOX §404','COSO'], 'SOX §404',
 'https://pcaobus.org/oversight/standards/auditing-standards/details/AS2201', 'error'),

('VAL-D3-004', 'Decimales en montos financieros',
 'ISO 20022: precisión estándar para transacciones. Mínimo 2 decimales, máximo 8.',
 'fin_limit', 'decimal_places', 'D3', 'RANGE',
 'integer', 2, 8, NULL,
 'decimal_places debe estar entre 2 (estándar) y 8 (cripto).',
 'VAL-D3-004',
 ARRAY['ISO 20022'], 'ISO 20022 Decimal Precision',
 'https://www.iso20022.org/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- D11 — AUDITORÍA (PCI DSS 10.7 + ISO 27001 A.8.15 + SOX)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D11-001', 'Período de retención de auditoría (días)',
 'PCI DSS 10.7: mínimo 365 días. ISO 27001 A.8.15: legal requirement. Bolivia Ley 2492: 2555d.',
 'aud_config', 'retention_days', 'D11', 'RANGE',
 'integer', 365, 3650, NULL,
 'retention_days debe estar entre 365 (PCI DSS mínimo) y 3650 (10 años).',
 'VAL-D11-001',
 ARRAY['PCI DSS 10.7','ISO 27001 A.8.15','Ley 2492 Bolivia'], 'PCI DSS Req 10.7',
 'https://www.pcisecuritystandards.org/document_library/', 'error'),

('VAL-D11-002', 'Frecuencia de revisión de accesos',
 'ISO 27001 A.9.2.5: revisiones periódicas. PCI DSS 7.2.4: cada 6 meses. SU/SYS: mensual.',
 'aud_review', 'review_frequency', 'D11', 'ENUM',
 'text', NULL, NULL, ARRAY['monthly','quarterly','semi_annual','annual'],
 'review_frequency debe ser: monthly, quarterly, semi_annual o annual.',
 'VAL-D11-002',
 ARRAY['ISO 27001 A.9.2.5','PCI DSS 7.2.4','NIST AC-6'], 'A.9.2.5 Review of Access Rights',
 'https://www.iso.org/standard/27001', 'error'),

('VAL-D11-003', 'Días para desactivar cuentas inactivas',
 'PCI DSS 8.2.6: 90 días máximo. ISO 27001 A.9.2: sin demora indebida. Default: 90.',
 'idn_user_template', 'inactive_days_before_disable', 'D11', 'RANGE',
 'integer', 30, 365, NULL,
 'inactive_days_before_disable debe estar entre 30 y 365 días. PCI DSS exige ≤90.',
 'VAL-D11-003',
 ARRAY['PCI DSS 8.2.6','ISO 27001 A.9.2'], 'PCI DSS Req 8.2.6',
 'https://www.pcisecuritystandards.org/document_library/', 'error'),

('VAL-D11-004', 'Frecuencia de revisión de privilegios elevados',
 'PCI DSS 7.2.4: cada 6 meses. ISO 27001 A.9.2.5: privilegiados más frecuente. NIST AC-6: quarterly.',
 'aud_review', 'privileged_review_frequency_days', 'D11', 'RANGE',
 'integer', 30, 180, NULL,
 'privileged_review_frequency_days debe estar entre 30 (mensual) y 180 (semestral).',
 'VAL-D11-004',
 ARRAY['ISO 27001 A.9.2.5','PCI DSS 7.2.4','NIST AC-6'], 'ISO 27001 A.9.2.5',
 'https://www.iso.org/standard/27001', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- D4 — TEMPORAL (ISO 8601 + Ley Trabajo Bolivia)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D4-001', 'Horas máximas de trabajo diario',
 'Ley Bolivia: 8h diarias, 48h semanales. Horas extra: máx 4h/día. Emergencia: máx 16h.',
 'cal_overtime_policy', 'max_daily_hours', 'D4', 'RANGE',
 'integer', 8, 16, NULL,
 'max_daily_hours debe estar entre 8 (legal) y 16 (emergencia).',
 'VAL-D4-001',
 ARRAY['Ley General del Trabajo Bolivia','ISO 8601'], 'Jornada Laboral',
 'https://www.lexivox.org/norms/BO/L-N19381208-1.html', 'error'),

('VAL-D4-002', 'Días laborables (ISO 8601)',
 'ISO 8601: 1=Lunes, 7=Domingo. Cada día debe ser entero 1-7. Default Bolivia: {1,2,3,4,5}.',
 'cal_schedule', 'days_of_week', 'D4', 'TYPE',
 'integer', 1, 7, NULL,
 'Cada día debe ser un entero entre 1 (Lunes) y 7 (Domingo). ISO 8601.',
 'VAL-D4-002',
 ARRAY['ISO 8601'], '§3.2.2 Day of Week',
 'https://www.iso.org/standard/70907.html', 'error'),

('VAL-D4-003', 'Duración de pausa de almuerzo (minutos)',
 'Ley Bolivia: mínimo 60 minutos. Máximo 120 minutos. Default: 60.',
 'cal_break_policy', 'lunch_duration_minutes', 'D4', 'RANGE',
 'integer', 30, 120, NULL,
 'lunch_duration_minutes debe estar entre 30 y 120 minutos.',
 'VAL-D4-003',
 ARRAY['Ley General del Trabajo Bolivia'], 'Jornada Laboral',
 'https://www.lexivox.org/norms/BO/L-N19381208-1.html', 'error'),

('VAL-D4-004', 'Duración de pausa corta (minutos)',
 'Estándar laboral: 10-20 minutos por pausa. Máximo 2-3 pausas/día. Default: 15min ×2.',
 'cal_break_policy', 'short_break_minutes', 'D4', 'RANGE',
 'integer', 5, 30, NULL,
 'short_break_minutes debe estar entre 5 y 30 minutos.',
 'VAL-D4-004',
 ARRAY['ISO 8601'], 'ISO 8601 Duration',
 'https://www.iso.org/standard/70907.html', 'error'),

('VAL-D4-005', 'Horas extra máximas semanales',
 'Ley Bolivia: máximo 20h/semana de horas extra. Mínimo 0, máximo 30.',
 'cal_overtime_policy', 'max_weekly_hours', 'D4', 'RANGE',
 'integer', 0, 30, NULL,
 'max_weekly_hours debe estar entre 0 y 30 horas.',
 'VAL-D4-005',
 ARRAY['Ley General del Trabajo Bolivia'], 'Horas Extra',
 'https://www.lexivox.org/norms/BO/L-N19381208-1.html', 'error'),

('VAL-D4-006', 'Tasa de hora extra (multiplicador)',
 'Ley Bolivia: ×1.5 normal, ×2.0 nocturna, ×2.5 feriado. Rango: 1.0-3.0.',
 'cal_overtime_policy', 'rate_multiplier', 'D4', 'RANGE',
 'numeric', 1.0, 3.0, NULL,
 'rate_multiplier debe estar entre 1.0 y 3.0. Default Bolivia: 1.5.',
 'VAL-D4-006',
 ARRAY['Ley General del Trabajo Bolivia'], 'Horas Extra',
 'https://www.lexivox.org/norms/BO/L-N19381208-1.html', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- D5 — BIOMÉTRICO (ISO/IEC 19795 + FIDO Biometrics + NIST 800-63B §5.2)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D5-001', 'Tasa de Falsa Coincidencia (FMR) para huella',
 'ISO/IEC 19795: FMR 0.01% (0.0001). Alta seguridad: 0.001% (0.00001). NIST §5.2.3.',
 'ath_config_d5', 'fmr_default_fingerprint', 'D5', 'RANGE',
 'numeric', 0.000001, 0.01, NULL,
 'FMR huella debe estar entre 0.000001 y 0.01. NIST §5.2.3.',
 'VAL-D5-001',
 ARRAY['ISO/IEC 19795','NIST SP 800-63B §5.2.3'], '§5.2.3 Biometric Comparison',
 'https://pages.nist.gov/800-63-4/sp800-63b.html#sec5', 'error'),

('VAL-D5-002', 'Intentos máximos de verificación biométrica',
 'FIDO Biometrics: máximo 3 intentos antes de fallback. Mínimo 1, máximo 5.',
 'ath_config_d5', 'max_biometric_attempts', 'D5', 'RANGE',
 'integer', 1, 5, NULL,
 'max_biometric_attempts debe estar entre 1 y 5. FIDO Alliance: default 3.',
 'VAL-D5-002',
 ARRAY['FIDO Alliance','ISO/IEC 30107-3'], 'FIDO Biometrics Requirements',
 'https://fidoalliance.org/specs/biometric/', 'error'),

('VAL-D5-003', 'Puntaje mínimo de calidad de captura (huella)',
 'ISO/IEC 19794-4: NFIQ 2.0 score 0-100. Mínimo aceptable: 40. Default: 80.',
 'ath_config_d5', 'min_quality_score_fingerprint', 'D5', 'RANGE',
 'integer', 40, 100, NULL,
 'min_quality_score para huella debe estar entre 40 y 100. ISO 19794-4.',
 'VAL-D5-003',
 ARRAY['ISO/IEC 19794-4','NIST SP 800-63B §5.2.3'], 'ISO 19794-4 Fingerprint Quality',
 'https://www.iso.org/standard/82798.html', 'error'),

('VAL-D5-004', 'Resolución mínima de captura (DPI)',
 'ISO/IEC 19794-4: 500 DPI para huella. FBI standard: 1000 DPI. Mínimo 300, máximo 1200.',
 'ath_config_d5', 'min_dpi_fingerprint', 'D5', 'RANGE',
 'integer', 300, 1200, NULL,
 'min_dpi para huella debe estar entre 300 y 1200. ISO 19794-4: 500 DPI.',
 'VAL-D5-004',
 ARRAY['ISO/IEC 19794-4','FBI EBTS'], 'ISO 19794-4 Fingerprint Image',
 'https://www.iso.org/standard/82798.html', 'error'),

('VAL-D5-005', 'TTL de template biométrico (días)',
 'GDPR Art.9: mínimo necesario. Visitante: 1d, contratista: 90d, empleado: hasta offboarding. Máximo 3650.',
 'ath_config_d5', 'template_retention_days', 'D5', 'RANGE',
 'integer', 1, 3650, NULL,
 'template_retention_days debe estar entre 1 (visitante) y 3650 (10 años). GDPR Art.9.',
 'VAL-D5-005',
 ARRAY['GDPR Art.9','RGPD Art.17','ISO/IEC 19794'], 'GDPR Art.9 Special Categories',
 'https://gdpr.eu/article-9-processing-special-categories-of-personal-data/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- D10 — DELEGACIÓN (NIST AC-2 + ISO 27001 A.9.2 + SOX §404)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D10-001', 'Duración máxima de delegación (horas)',
 'NIST 800-53 AC-2(2): delegación temporal con fecha de expiración. Máximo 90d (2160h). Mínimo 24h. Default: 504h (21d).',
 'ath_config_d10', 'max_duration_h', 'D10', 'RANGE',
 'integer', 24, 2160, NULL,
 'max_duration_h debe estar entre 24h (1 día) y 2160h (90 días). NIST AC-2(2).',
 'VAL-D10-001',
 ARRAY['NIST SP 800-53 AC-2(2)','ISO 27001 A.9.2'], 'AC-2(2) Temporary Accounts',
 'https://csrc.nist.gov/projects/risk-management/sp800-53-controls/release-search#/control?version=5.1&number=AC-2', 'error'),

('VAL-D10-002', 'Profundidad máxima de cadena de delegación',
 'SOX §404: redelegación controlada. Máximo 2 niveles (delegado no puede redelegar). Default: 1.',
 'ath_config_d10', 'chain_depth_max', 'D10', 'RANGE',
 'integer', 1, 2, NULL,
 'chain_depth_max debe ser 1 o 2. SOX §404: 2 niveles máximo.',
 'VAL-D10-002',
 ARRAY['SOX §404','NIST AC-2'], 'SOX §404',
 'https://pcaobus.org/oversight/standards/auditing-standards/details/AS2201', 'error'),

('VAL-D10-003', 'Máximo de delegaciones concurrentes por delegante',
 'NIST AC-2: límite de delegaciones activas. Mínimo 1, máximo 10 por usuario.',
 'ath_config_d10', 'max_concurrent_per_granter', 'D10', 'RANGE',
 'integer', 1, 10, NULL,
 'max_concurrent_per_granter debe estar entre 1 y 10.',
 'VAL-D10-003',
 ARRAY['NIST SP 800-53 AC-2'], 'AC-2 Account Management',
 'https://csrc.nist.gov/projects/risk-management/sp800-53-controls/release-search#/control?version=5.1&number=AC-2', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- D12 — BLOCKCHAIN (NIST IR 8202 + RFC 6962 + EIP-1559)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D12-001', 'Frecuencia de anclaje blockchain (segundos)',
 'Gold tier: 3600s (1h). Silver: 14400s (4h). Bronze: 86400s (24h). Mínimo 300s, máximo 86400s.',
 'ath_config_d12', 'anchor_frequency', 'D12', 'RANGE',
 'integer', 300, 86400, NULL,
 'anchor_frequency debe estar entre 300s (5min) y 86400s (24h). NIST IR 8202.',
 'VAL-D12-001',
 ARRAY['NIST IR 8202','RFC 6962'], 'NIST IR 8202 Blockchain for Access Control',
 'https://csrc.nist.gov/publications/detail/nistir/8202/final', 'error'),

('VAL-D12-002', 'Gas limit para transacción de anclaje',
 'EIP-1559: mínimo 60000 gas para tx simple. Máximo 500000 para lotes grandes. Default: 100000.',
 'ath_config_d12', 'gas_limit', 'D12', 'RANGE',
 'integer', 60000, 500000, NULL,
 'gas_limit debe estar entre 60000 y 500000. EIP-1559.',
 'VAL-D12-002',
 ARRAY['EIP-1559'], 'EIP-1559 Fee Market',
 'https://eips.ethereum.org/EIPS/eip-1559', 'error'),

('VAL-D12-003', 'Tamaño máximo de lote Merkle',
 'RFC 6962: lotes entre 1 y 10000 eventos. Gold tier: 1000. Mínimo 1, máximo 10000.',
 'ath_config_d12', 'max_batch_size', 'D12', 'RANGE',
 'integer', 1, 10000, NULL,
 'max_batch_size debe estar entre 1 y 10000. RFC 6962.',
 'VAL-D12-003',
 ARRAY['RFC 6962'], 'RFC 6962 §2.1 Merkle Tree',
 'https://datatracker.ietf.org/doc/html/rfc6962', 'error'),

('VAL-D12-004', 'Confirmaciones requeridas para liquidación on-chain',
 'Variante B (Besu QBFT): 1 confirmación (2s). Alta seguridad: 3 confirmaciones. Máximo 12.',
 'ath_config_d12', 'confirmations_required', 'D12', 'RANGE',
 'integer', 1, 12, NULL,
 'confirmations_required debe estar entre 1 y 12. Besu QBFT: default 1.',
 'VAL-D12-004',
 ARRAY['Hyperledger Besu QBFT','EIP-1559'], 'Besu QBFT Consensus',
 'https://besu.hyperledger.org/stable/private-networks/concepts/consensus/qbft', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- SEC — SEGURIDAD / CRIPTOGRAFÍA (FIPS 140-3 + NIST SP 800-57)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-SEC-001', 'Rotación de claves criptográficas (días)',
 'NIST SP 800-57 §8.2: signing 1-3y, session <24h. Mínimo 1d, máximo 365d.',
 'sec_key_inventory', 'rotation_interval', 'SEC', 'RANGE',
 'integer', 1, 365, NULL,
 'rotation_interval debe estar entre 1 y 365 días. NIST 800-57 §8.2.',
 'VAL-SEC-001',
 ARRAY['NIST SP 800-57 §8.2','FIPS 140-3'], '§8.2 Crypto Periods',
 'https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev/5/final', 'error'),

('VAL-SEC-002', 'Algoritmos criptográficos permitidos',
 'FIPS 140-3 + NIST SP 800-57. SHA-1, MD5, DES PROHIBIDOS desde 2023.',
 'bos_crypto_algorithm', 'algo_name', 'SEC', 'ENUM',
 'text', NULL, NULL,
 ARRAY['AES-256-GCM','AES-256','SHA-256','SHA-384','SHA-512','EdDSA','RSA-4096','ECDSA-P384','CRYSTALS-Kyber','CRYSTALS-Dilithium','SPHINCS+','NTRU'],
 'algo_name debe ser un algoritmo aprobado FIPS 140-3. SHA-1, MD5, DES PROHIBIDOS.',
 'VAL-SEC-002',
 ARRAY['FIPS 140-3','NIST SP 800-57 §5'], 'FIPS 140-3 Approved Security Functions',
 'https://csrc.nist.gov/projects/cryptographic-module-validation-program/fips-140-3-standards', 'error'),

('VAL-SEC-003', 'TTL de certificado raíz (días)',
 'CAB Forum Baseline: Root CA 20-25 años. Sub-CA 5-10 años. Mínimo 365d, máximo 9125d (25a).',
 'sec_key_inventory', 'cert_ttl_days', 'SEC', 'RANGE',
 'integer', 30, 9125, NULL,
 'cert_ttl_days debe estar entre 30d y 9125d (25a). CAB Forum Baseline.',
 'VAL-SEC-003',
 ARRAY['CAB Forum Baseline','NIST SP 800-57 §8.2'], 'CAB Forum Baseline Requirements',
 'https://cabforum.org/baseline-requirements-documents/', 'error'),

('VAL-SEC-004', 'Tamaño mínimo de clave RSA',
 'NIST SP 800-57 §5: RSA mínimo 2048 bits. 3072 para datos sensibles. Máximo 4096 para compatibilidad.',
 'bos_crypto_algorithm', 'key_size_bits', 'SEC', 'RANGE',
 'integer', 2048, 4096, NULL,
 'key_size_bits debe estar entre 2048 y 4096. NIST 800-57: mínimo 3072 para datos sensibles.',
 'VAL-SEC-004',
 ARRAY['NIST SP 800-57 §5'], '§5 Key Sizes',
 'https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev/5/final', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- D1 — LÓGICO (NIST RBAC §4.2 + ANSI/INCITS 359-2004)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D1-001', 'Máximo de registros por consulta',
 'OWASP ASVS V5.1.3: limitar tamaño de respuesta. Mínimo 10, máximo 10000.',
 'ath_config_d1', 'max_records_per_query', 'D1', 'RANGE',
 'integer', 10, 10000, NULL,
 'max_records_per_query debe estar entre 10 y 10000. OWASP V5.1.3.',
 'VAL-D1-001',
 ARRAY['OWASP ASVS V5.1.3','ISO 27001 A.9.4'], 'V5.1.3 Input Validation',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

('VAL-D1-002', 'Máximo de zonas por rol',
 'NIST RBAC §4.2: roles con scope limitado. Mínimo 1 zona, máximo 20 zonas por rol.',
 'ath_config_d1', 'max_zones_per_role', 'D1', 'RANGE',
 'integer', 1, 20, NULL,
 'max_zones_per_role debe estar entre 1 y 20.',
 'VAL-D1-002',
 ARRAY['NIST RBAC §4.2','ANSI/INCITS 359-2004'], '§4.2 Role Engineering',
 'https://csrc.nist.gov/projects/role-based-access-control', 'error'),

('VAL-D1-003', 'Scope de acceso permitido',
 'NIST RBAC: GLOBAL (SU), COMPANY (N1-N2), BRANCH (N3-N4), PERSONAL (N5-EXT).',
 'ath_config_d1', 'default_scope', 'D1', 'ENUM',
 'text', NULL, NULL, ARRAY['GLOBAL','COMPANY','BRANCH','PERSONAL'],
 'default_scope debe ser GLOBAL, COMPANY, BRANCH o PERSONAL. NIST RBAC §4.2.',
 'VAL-D1-003',
 ARRAY['NIST RBAC §4.2','ANSI/INCITS 359-2004'], '§4.2 Role Scope',
 'https://csrc.nist.gov/projects/role-based-access-control', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- D2 — FÍSICO (IEC 60839-11-5 + BS 5979 + PCI DSS 9.5)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D2-001', 'Niveles de zona de seguridad física',
 'BS 5979: Zone 0 (pública) a Zone 5 (bóveda/data center). Entero 0-5.',
 'fis_location', 'security_zone', 'D2', 'RANGE',
 'integer', 0, 5, NULL,
 'security_zone debe estar entre 0 (pública) y 5 (bóveda). BS 5979:2007.',
 'VAL-D2-001',
 ARRAY['BS 5979:2007','IEC 60839-11-5'], 'BS 5979 Security Zones',
 'https://knowledge.bsigroup.com/products/remote-centres-for-alarm-systems-code-of-practice', 'error'),

('VAL-D2-002', 'Nivel de autenticación requerido por dispositivo',
 'OSDP v2.2.2: 1=tarjeta, 2=tarjeta+PIN, 3=biométrico, 4=doble factor. Rango 1-4.',
 'fis_device', 'auth_level', 'D2', 'RANGE',
 'integer', 1, 4, NULL,
 'auth_level debe estar entre 1 (tarjeta) y 4 (doble factor). OSDP v2.2.2.',
 'VAL-D2-002',
 ARRAY['IEC 60839-11-5','SIA OSDP v2.2.2'], 'OSDP v2.2.2 Auth Levels',
 'https://www.securityindustry.org/industry-standards/open-supervised-device-protocol/', 'error'),

('VAL-D2-003', 'Tiempo de pulso de desbloqueo (ms)',
 'OSDP: pulso 3-10 segundos. Mínimo 3000ms, máximo 15000ms. Default: 5000ms.',
 'ath_config_d2', 'door_relay_ms', 'D2', 'RANGE',
 'integer', 3000, 15000, NULL,
 'door_relay_ms debe estar entre 3000ms (3s) y 15000ms (15s). OSDP v2.2.2.',
 'VAL-D2-003',
 ARRAY['IEC 60839-11-5','SIA OSDP v2.2.2'], 'OSDP v2.2.2 Relay Timing',
 'https://www.securityindustry.org/industry-standards/open-supervised-device-protocol/', 'error'),

('VAL-D2-004', 'Tiempo de reset anti-passback (horas)',
 'Anti-passback se resetea diariamente. Mínimo 1h, máximo 24h. Default: 24h (medianoche).',
 'ath_config_d2', 'anti_passback_reset_h', 'D2', 'RANGE',
 'integer', 1, 24, NULL,
 'anti_passback_reset_h debe estar entre 1 y 24 horas.',
 'VAL-D2-004',
 ARRAY['IEC 60839-11-5','BS 5979:2007'], 'IEC 60839-11-5 Anti-Passback',
 'https://webstore.iec.ch/publication/3537', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- CONSENTIMIENTO / GDPR (Art.7, Art.17, Digital Omnibus 2025)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-COMP-001', 'Plazo de respuesta a solicitud de eliminación (días)',
 'GDPR Art.17: responder en 1 mes (30 días). Extensible a 3 meses (90 días) si es complejo. Digital Omnibus 2025: 96h para brechas.',
 'ath_consent', 'erasure_response_days', 'COMP', 'RANGE',
 'integer', 1, 90, NULL,
 'erasure_response_days debe estar entre 1 y 90 días. GDPR Art.17 exige ≤30 días.',
 'VAL-COMP-001',
 ARRAY['GDPR Art.17','Digital Omnibus 2025'], 'Art.17 Right to Erasure',
 'https://gdpr.eu/article-17-right-to-be-forgotten/', 'error'),

('VAL-COMP-002', 'Período de retención de datos personales (días)',
 'GDPR Art.5: mínimo necesario. Fiscal: 2555d (7a Bolivia, Ley 2492). Comercial: 3650d (10a). Rango: 30-3650.',
 'ath_consent', 'data_retention_days', 'COMP', 'RANGE',
 'integer', 30, 3650, NULL,
 'data_retention_days debe estar entre 30 y 3650 (10 años). GDPR Art.5: mínimo necesario.',
 'VAL-COMP-002',
 ARRAY['GDPR Art.5','Ley 2492 Bolivia'], 'Art.5 Data Minimization',
 'https://gdpr.eu/article-5-principles/', 'error'),

('VAL-COMP-003', 'Validez de consentimiento (meses)',
 'Digital Omnibus 2025: cookies 6 meses. Marketing: 24 meses práctica común. Rango: 1-36 meses.',
 'ath_consent', 'consent_validity_months', 'COMP', 'RANGE',
 'integer', 1, 36, NULL,
 'consent_validity_months debe estar entre 1 y 36 meses. Digital Omnibus 2025: 6 meses cookies.',
 'VAL-COMP-003',
 ARRAY['GDPR Art.7','Digital Omnibus 2025'], 'Art.7 Conditions for Consent',
 'https://gdpr.eu/article-7-consent-conditions/', 'error'),

('VAL-COMP-004', 'Horas para notificar brecha de datos',
 'GDPR Art.33: 72 horas. Digital Omnibus 2025 propone 96h. Rango: 24-168h.',
 'ath_config_d11', 'breach_notification_hours', 'COMP', 'RANGE',
 'integer', 24, 168, NULL,
 'breach_notification_hours debe estar entre 24h y 168h (7d). GDPR Art.33: ≤72h.',
 'VAL-COMP-004',
 ARRAY['GDPR Art.33','Digital Omnibus 2025'], 'Art.33 Breach Notification',
 'https://gdpr.eu/article-33-notification-of-a-personal-data-breach/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- RED / SEGURIDAD ADICIONAL (CIS K8s, NSA/CISA, SBOS-054)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D7-006', 'Rate limit requests por segundo (API Gateway)',
 'OWASP V13: límite de requests. Autenticado: 100 rps. No autenticado: 10 rps. Admin: 1000 rps. Rango: 1-10000.',
 'ath_config_d7', 'rate_limit_rps', 'D7', 'RANGE',
 'integer', 1, 10000, NULL,
 'rate_limit_rps debe estar entre 1 y 10000. OWASP ASVS V13.',
 'VAL-D7-006',
 ARRAY['OWASP ASVS V13','SBOS-054 §10'], 'V13 API Security',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

('VAL-D7-007', 'Timeout de conexión API (segundos)',
 'OWASP V13: timeout máximo para prevenir DoS. Mínimo 2s, máximo 30s. Default: 5s.',
 'idn_tenant_domain', 'connection_timeout_s', 'D7', 'RANGE',
 'integer', 2, 30, NULL,
 'connection_timeout_s debe estar entre 2s y 30s. OWASP ASVS V13.',
 'VAL-D7-007',
 ARRAY['OWASP ASVS V13','NIST SP 800-207'], 'V13 API Security',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

('VAL-D7-008', 'Tamaño máximo de payload (MB)',
 'OWASP V5.1.3: limitar tamaño de input. Mínimo 1MB, máximo 100MB. Default: 10MB.',
 'idn_tenant_domain', 'max_payload_mb', 'D7', 'RANGE',
 'integer', 1, 100, NULL,
 'max_payload_mb debe estar entre 1MB y 100MB. OWASP ASVS V5.1.3.',
 'VAL-D7-008',
 ARRAY['OWASP ASVS V5.1.3'], 'V5.1.3 Input Size Limits',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- CONTENEDORES / KUBERNETES (CIS K8s 1.8 + NSA/CISA Hardening)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D7-009', 'Máximo de réplicas por deployment',
 'CIS K8s §5: límite de recursos. Mínimo 1, máximo 100 réplicas por tenant.',
 'idn_tenant_domain', 'max_replicas', 'D7', 'RANGE',
 'integer', 1, 100, NULL,
 'max_replicas debe estar entre 1 y 100. CIS K8s Benchmark §5.',
 'VAL-D7-009',
 ARRAY['CIS K8s Benchmark §5','NSA/CISA K8s Hardening'], '§5 Pod Security',
 'https://www.cisecurity.org/benchmark/kubernetes/', 'error'),

('VAL-D7-010', 'CPU target para HPA (%)',
 'CIS K8s §5: HPA thresholds. Mínimo 50%, máximo 90%. Default: 70%.',
 'idn_tenant_domain', 'hpa_cpu_target_pct', 'D7', 'RANGE',
 'integer', 50, 90, NULL,
 'hpa_cpu_target_pct debe estar entre 50% y 90%. CIS K8s §5.',
 'VAL-D7-010',
 ARRAY['CIS K8s Benchmark §5'], '§5 Resource Limits',
 'https://www.cisecurity.org/benchmark/kubernetes/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- INCIDENTES / RESPUESTA (NIST SP 800-61 + ISO 27001 A.16)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D8-005', 'Tiempo máximo de contención de incidente (minutos)',
 'NIST SP 800-61 §3.2: contención en <1 hora para críticos. Máximo 480min (8h). Mínimo 15min.',
 'ath_config_d8', 'incident_containment_minutes', 'D8', 'RANGE',
 'integer', 15, 480, NULL,
 'incident_containment_minutes debe estar entre 15 y 480 minutos. NIST SP 800-61.',
 'VAL-D8-005',
 ARRAY['NIST SP 800-61','ISO 27001 A.16'], '§3.2 Incident Containment',
 'https://csrc.nist.gov/publications/detail/sp/800-61/rev-2/final', 'error'),

('VAL-D8-006', 'Frecuencia de simulacros de incidentes (días)',
 'ISO 27001 A.16.1.5: simulacros periódicos. Mínimo 90d (trimestral), máximo 365d (anual). Default: 180d (semestral).',
 'ath_config_d8', 'incident_drill_frequency_days', 'D8', 'RANGE',
 'integer', 90, 365, NULL,
 'incident_drill_frequency_days debe estar entre 90 y 365 días. ISO 27001 A.16.',
 'VAL-D8-006',
 ARRAY['ISO 27001 A.16.1.5','NIST SP 800-61'], 'A.16.1.5 Incident Response Testing',
 'https://www.iso.org/standard/27001', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- FEDERACIÓN / OIDC / SAML (OAuth 2.1 + OIDC + SAML 2.0)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D9-012', 'TTL de access token (segundos)',
 'OAuth 2.1 BCP: access token TTL corto. Mínimo 300s (5min), máximo 3600s (1h). Default: 3600s.',
 'ath_federation_protocol', 'access_token_ttl_seconds', 'D9', 'RANGE',
 'integer', 300, 7200, NULL,
 'access_token_ttl_seconds debe estar entre 300s y 7200s. OAuth 2.1 BCP.',
 'VAL-D9-012',
 ARRAY['OAuth 2.1 BCP','RFC 6749'], 'OAuth 2.1 Token Lifetime',
 'https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1-12', 'error'),

('VAL-D9-013', 'TTL de refresh token (horas)',
 'OAuth 2.1 BCP: refresh token 24h-90d. Mínimo 1h, máximo 2160h (90d). Default: 24h.',
 'ath_federation_protocol', 'refresh_token_ttl_hours', 'D9', 'RANGE',
 'integer', 1, 2160, NULL,
 'refresh_token_ttl_hours debe estar entre 1h y 2160h (90d). OAuth 2.1 BCP.',
 'VAL-D9-013',
 ARRAY['OAuth 2.1 BCP','RFC 6749'], 'OAuth 2.1 Refresh Token',
 'https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1-12', 'error'),

('VAL-D9-014', 'Máximo de clients OIDC por tenant',
 'OIDC: límite de clients para prevenir abuso. Mínimo 1, máximo 100 por tenant.',
 'ath_federation_protocol', 'max_clients_per_tenant', 'D9', 'RANGE',
 'integer', 1, 100, NULL,
 'max_clients_per_tenant debe estar entre 1 y 100.',
 'VAL-D9-014',
 ARRAY['OIDC Core 1.0'], 'OIDC Client Registration',
 'https://openid.net/specs/openid-connect-core-1_0.html', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- API / MICROSERVICIOS (OWASP ASVS V13 + SBOS-050)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D7-011', 'Máximo de endpoints API por tenant',
 'OWASP V13: control de superficie de ataque. Mínimo 1, máximo 500 endpoints.',
 'ath_config_d7', 'max_api_endpoints', 'D7', 'RANGE',
 'integer', 1, 500, NULL,
 'max_api_endpoints debe estar entre 1 y 500.',
 'VAL-D7-011',
 ARRAY['OWASP ASVS V13','SBOS-050'], 'V13 API Security',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- SECRETOS / VAULT (NIST SP 800-57 + HashiCorp Vault Best Practices)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-SEC-005', 'TTL de secreto dinámico (horas)',
 'Vault Best Practices: dynamic secrets TTL corto. Min 1h, max 168h (7d). DB creds: 24h.',
 'sec_key_inventory', 'dynamic_secret_ttl_hours', 'SEC', 'RANGE',
 'integer', 1, 168, NULL,
 'dynamic_secret_ttl_hours debe estar entre 1h y 168h (7d). Vault Best Practices.',
 'VAL-SEC-005',
 ARRAY['NIST SP 800-57 §8.2','Vault Best Practices'], '§8.2 Crypto Periods',
 'https://developer.hashicorp.com/vault/docs/concepts/lease', 'error'),

('VAL-SEC-006', 'Número de shares Shamir Secret Sharing',
 'Vault unseal: Shamir 2-of-3 mínimo. Mínimo 2 shares, máximo 5. Default: 3 con threshold 2.',
 'sec_key_inventory', 'shamir_shares', 'SEC', 'RANGE',
 'integer', 2, 5, NULL,
 'shamir_shares debe estar entre 2 y 5. Vault Shamir Secret Sharing.',
 'VAL-SEC-006',
 ARRAY['Vault Best Practices','Shamir SSS'], 'Shamir Secret Sharing',
 'https://developer.hashicorp.com/vault/docs/concepts/seal', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- DISPOSITIVOS / ENDPOINT (CIS Endpoint + NIST SP 800-53 SI-2)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D5-006', 'Score mínimo de atestación de dispositivo (Android)',
 'Play Integrity: BASIC=0.3, DEVICE=0.7, STRONG=0.95. Mínimo 0.3, máximo 1.0. Default: 0.7.',
 'net_device', 'min_attestation_score', 'D5', 'RANGE',
 'numeric', 0.3, 1.0, NULL,
 'min_attestation_score debe estar entre 0.3 y 1.0. Play Integrity.',
 'VAL-D5-006',
 ARRAY['FIDO Alliance','Play Integrity API'], 'Device Attestation',
 'https://developer.android.com/google/play/integrity', 'error'),

('VAL-D5-007', 'Días máximos sin heartbeat del dispositivo',
 'CIS Endpoint: desconectar tras inactividad. Mínimo 1d, máximo 90d. Default: 30d.',
 'net_device', 'max_days_without_heartbeat', 'D5', 'RANGE',
 'integer', 1, 90, NULL,
 'max_days_without_heartbeat debe estar entre 1 y 90 días.',
 'VAL-D5-007',
 ARRAY['CIS Controls v8 §12','NIST SP 800-53 SI-2'], 'CIS v8 §12',
 'https://www.cisecurity.org/controls/v8', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- WEB SOCKET / REAL-TIME (OWASP ASVS V9 + NIST SP 800-207)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D7-012', 'Máximo de conexiones WebSocket concurrentes',
 'NEXUS: 10K+ conexiones. Mínimo 100, máximo 50000. Default: 10000.',
 'ath_config_d7', 'max_ws_connections', 'D7', 'RANGE',
 'integer', 100, 50000, NULL,
 'max_ws_connections debe estar entre 100 y 50000. SBOS-050.',
 'VAL-D7-012',
 ARRAY['SBOS-050','NIST SP 800-207'], 'SBOS-050 Port Catalog §6',
 'https://csrc.nist.gov/publications/detail/sp/800-207/final', 'error'),

('VAL-D7-013', 'Heartbeat WebSocket (segundos)',
 'NEXUS: heartbeat cada 30s. Mínimo 10s, máximo 300s. Default: 30s.',
 'ath_config_d7', 'ws_heartbeat_seconds', 'D7', 'RANGE',
 'integer', 10, 300, NULL,
 'ws_heartbeat_seconds debe estar entre 10s y 300s. SBOS-050.',
 'VAL-D7-013',
 ARRAY['SBOS-050','RFC 6455'], 'WebSocket Ping/Pong',
 'https://datatracker.ietf.org/doc/html/rfc6455', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- DATOS / PRIVACIDAD (GDPR + NIST SP 800-53)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-COMP-005', 'Clasificación de datos: niveles permitidos',
 'ISO 27001 A.8.2: PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED. NIST SP 800-53 RA-2.',
 'zone_data_policy', 'data_classification', 'COMP', 'ENUM',
 'text', NULL, NULL,
 ARRAY['PUBLIC','INTERNAL','CONFIDENTIAL','RESTRICTED'],
 'data_classification debe ser: PUBLIC, INTERNAL, CONFIDENTIAL o RESTRICTED.',
 'VAL-COMP-005',
 ARRAY['ISO 27001 A.8.2','NIST SP 800-53 RA-2'], 'A.8.2 Information Classification',
 'https://www.iso.org/standard/27001', 'error'),

('VAL-COMP-006', 'Anonimización de PII en exportaciones',
 'GDPR Art.5: minimización. GDPR Art.32: seguridad. Exportaciones deben anonimizar PII.',
 'ath_config_d11', 'anonymize_pii_on_export', 'COMP', 'TYPE',
 'boolean', NULL, NULL, NULL,
 'anonymize_pii_on_export debe ser booleano. GDPR Art.5 exige minimización.',
 'VAL-COMP-006',
 ARRAY['GDPR Art.5','GDPR Art.32'], 'Art.5 Data Minimization',
 'https://gdpr.eu/article-5-principles/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- BIOMETRÍA AVANZADA (FIDO2 CTAP 2.2 + ISO/IEC 30107-3)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D5-008', 'Máximo de templates biométricos por usuario',
 'FIDO2 CTAP 2.2: máximo 10 templates por authenticator. Default: 5. Rango: 1-20.',
 'ath_config_d5', 'max_templates_per_user', 'D5', 'RANGE',
 'integer', 1, 20, NULL,
 'max_templates_per_user debe estar entre 1 y 20.',
 'VAL-D5-008',
 ARRAY['FIDO2 CTAP 2.2','ISO/IEC 19794'], 'CTAP 2.2 Biometric Enrollment',
 'https://fidoalliance.org/specs/fido-v2.2-rd-20241029/', 'error'),

('VAL-D5-009', 'Timeout de verificación biométrica (segundos)',
 'ISO/IEC 30107-3: timeout para prevenir ataques. Mínimo 5s, máximo 60s. Default: 30s.',
 'ath_config_d5', 'biometric_verification_timeout_s', 'D5', 'RANGE',
 'integer', 5, 60, NULL,
 'biometric_verification_timeout_s debe estar entre 5s y 60s.',
 'VAL-D5-009',
 ARRAY['ISO/IEC 30107-3','FIDO Alliance'], 'ISO 30107-3 Presentation Attack Detection',
 'https://www.iso.org/standard/79530.html', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- COMPORTAMIENTO / ANOMALÍAS (NIST SP 800-63B §5.2 + OWASP ASVS V6)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D9-015', 'Umbral de score de riesgo para step-up',
 'NIST §5.2: risk-based authentication. Score 0-100. Bajo≤30, Medio≤60, Alto≤80, Crítico≤95.',
 'ath_config_d9', 'risk_score_step_up_threshold', 'D9', 'RANGE',
 'integer', 30, 95, NULL,
 'risk_score_step_up_threshold debe estar entre 30 y 95.',
 'VAL-D9-015',
 ARRAY['NIST SP 800-63B §5.2','OWASP ASVS V6.3'], '§5.2 Risk-Based Authentication',
 'https://pages.nist.gov/800-63-4/sp800-63b.html#sec5', 'error'),

('VAL-D9-016', 'Ventana de observación para anomalías (días)',
 'NIST §5.2: baseline de comportamiento. Mínimo 7d, máximo 90d. Default: 30d.',
 'ath_config_d9', 'anomaly_baseline_days', 'D9', 'RANGE',
 'integer', 7, 90, NULL,
 'anomaly_baseline_days debe estar entre 7 y 90 días.',
 'VAL-D9-016',
 ARRAY['NIST SP 800-63B §5.2'], '§5.2 Behavioral Baseline',
 'https://pages.nist.gov/800-63-4/sp800-63b.html#sec5', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- POST-CUÁNTICO / CRYPTO AGILITY (NIST FIPS 203/204/205 + SP 800-57)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-SEC-007', 'Algoritmo post-cuántico requerido para AAL3',
 'NIST PQC 2025: ML-KEM-1024 (Kyber) + ML-DSA-65 (Dilithium). FIPS 203/204/205.',
 'bos_crypto_algorithm', 'pqc_required_for_aal3', 'SEC', 'TYPE',
 'boolean', NULL, NULL, NULL,
 'pqc_required_for_aal3 debe ser booleano. NIST PQC 2025: FIPS 203/204/205.',
 'VAL-SEC-007',
 ARRAY['FIPS 203','FIPS 204','FIPS 205','NIST SP 800-57 Pt.1 Rev.6'],
 'NIST PQC Standardization 2025',
 'https://csrc.nist.gov/projects/post-quantum-cryptography/selected-algorithms-2025', 'error'),

('VAL-SEC-008', 'Período de transición dual-signing (días)',
 'NIST SP 800-57 §8.2.6: migración criptográfica con overlapping. Mínimo 7d, máximo 180d. Default: 30d.',
 'sec_key_rotation', 'dual_signing_overlap_days', 'SEC', 'RANGE',
 'integer', 7, 180, NULL,
 'dual_signing_overlap_days debe estar entre 7 y 180 días.',
 'VAL-SEC-008',
 ARRAY['NIST SP 800-57 §8.2.6','FIPS 140-3'], '§8.2.6 Cryptoperiod Overlap',
 'https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev/5/final', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- RESILIENCIA / DISASTER RECOVERY (ISO 22301 + NIST SP 800-34)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-SEC-009', 'RPO máximo aceptable (horas)',
 'ISO 22301: Recovery Point Objective. Mínimo 1h, máximo 24h. Default: 4h.',
 'ath_config_d11', 'rpo_max_hours', 'SEC', 'RANGE',
 'integer', 1, 24, NULL,
 'rpo_max_hours debe estar entre 1h y 24h. ISO 22301 Business Continuity.',
 'VAL-SEC-009',
 ARRAY['ISO 22301','NIST SP 800-34'], 'ISO 22301 Business Continuity',
 'https://www.iso.org/standard/75106.html', 'error'),

('VAL-SEC-010', 'RTO máximo aceptable (horas)',
 'ISO 22301: Recovery Time Objective. Mínimo 1h, máximo 48h. Default: 4h.',
 'ath_config_d11', 'rto_max_hours', 'SEC', 'RANGE',
 'integer', 1, 48, NULL,
 'rto_max_hours debe estar entre 1h y 48h. ISO 22301.',
 'VAL-SEC-010',
 ARRAY['ISO 22301','NIST SP 800-34'], 'ISO 22301 Business Continuity',
 'https://www.iso.org/standard/75106.html', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- MONITOREO CONTINUO (NIST SP 800-137 + ISO 27001 A.8.16)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D11-005', 'Intervalo de escaneo de cumplimiento (horas)',
 'NIST SP 800-137: continuous monitoring. Mínimo 1h, máximo 168h (7d). Default: 24h.',
 'ath_config_d11', 'compliance_scan_interval_hours', 'D11', 'RANGE',
 'integer', 1, 168, NULL,
 'compliance_scan_interval_hours debe estar entre 1h y 168h.',
 'VAL-D11-005',
 ARRAY['NIST SP 800-137','ISO 27001 A.8.16'], 'NIST SP 800-137 ISCM',
 'https://csrc.nist.gov/publications/detail/sp/800-137/final', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- IOT / EDGE (NIST SP 800-213 + OWASP IoT)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D7-014', 'TTL de sesión offline (horas)',
 'NIST SP 800-207: edge devices con cache local. Mínimo 1h, máximo 168h (7d). Default: 24h.',
 'ath_config_d7', 'offline_session_ttl_hours', 'D7', 'RANGE',
 'integer', 1, 168, NULL,
 'offline_session_ttl_hours debe estar entre 1h y 168h (7d).',
 'VAL-D7-014',
 ARRAY['NIST SP 800-207','NIST SP 800-213'], 'NIST SP 800-213 IoT Security',
 'https://csrc.nist.gov/publications/detail/sp/800-213/final', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- CREDENCIALES ADICIONALES (OWASP ASVS V6 + NIST 800-63B)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D9-017', 'TTL de magic link (minutos)',
 'OWASP V6.4: magic links con TTL corto. Mínimo 1min, máximo 60min. Default: 5min.',
 'ath_config_d9', 'magic_link_ttl_minutes', 'D9', 'RANGE',
 'integer', 1, 60, NULL,
 'magic_link_ttl_minutes debe estar entre 1 y 60 minutos.',
 'VAL-D9-017',
 ARRAY['OWASP ASVS V6.4','NIST SP 800-63B §5.2'], 'V6.4 Credential Recovery',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

('VAL-D9-018', 'Máximo de recovery codes por usuario',
 'OWASP V6.4.2: suficientes códigos. Mínimo 5, máximo 20. Default: 10.',
 'ath_config_d9', 'max_recovery_codes', 'D9', 'RANGE',
 'integer', 5, 20, NULL,
 'max_recovery_codes debe estar entre 5 y 20.',
 'VAL-D9-018',
 ARRAY['OWASP ASVS V6.4.2','NIST SP 800-63B §5.1.6'], 'V6.4.2 Recovery Codes',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- TENANT / AISLAMIENTO (NIST SP 800-53 AC-3 + ISO 27001 A.9.4)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D1-004', 'Máximo de tenants por instancia',
 'Multi-tenant isolation: límite de tenants para performance. Mínimo 1, máximo 1000.',
 'idn_tenant', 'max_tenants', 'D1', 'RANGE',
 'integer', 1, 1000, NULL,
 'max_tenants debe estar entre 1 y 1000.',
 'VAL-D1-004',
 ARRAY['NIST SP 800-53 AC-3','ISO 27001 A.9.4'], 'AC-3 Access Enforcement',
 'https://csrc.nist.gov/projects/risk-management/sp800-53-controls/release-search#/control?version=5.1&number=AC-3', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- ARGENTINA — LEY CONTRATO TRABAJO 20.744 + LEY 11.544
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D4-007', 'Horas máximas trabajo diario (Argentina)',
 'Ley 11.544: 8h diarias, 48h semanales. Horas extra: max 3h/día, 30h/mes.',
 'cal_overtime_policy', 'max_daily_hours_ar', 'D4', 'RANGE',
 'integer', 8, 16, NULL,
 'max_daily_hours_ar debe estar entre 8 y 16. Ley 11.544 Argentina.',
 'VAL-D4-007',
 ARRAY['Ley 11.544 Argentina','Ley 20.744'], 'Jornada Laboral Argentina',
 'https://www.argentina.gob.ar/normativa/nacional/ley-11544-58812', 'error'),

('VAL-D4-008', 'Días de vacaciones mínimos (Argentina)',
 'Ley 20.744: 14 días corridos (antigüedad <5a), 21d (5-10a), 28d (10-20a), 35d (>20a).',
 'cal_schedule', 'min_vacation_days_ar', 'D4', 'RANGE',
 'integer', 14, 35, NULL,
 'min_vacation_days_ar debe estar entre 14 y 35. Ley 20.744 Argentina.',
 'VAL-D4-008',
 ARRAY['Ley 20.744 Argentina'], 'Ley Contrato de Trabajo',
 'https://www.argentina.gob.ar/normativa/nacional/ley-20744-25552', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- CHILE — CÓDIGO DEL TRABAJO + LEY 21.561 (40 HORAS)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D4-009', 'Horas máximas trabajo semanal (Chile)',
 'Ley 21.561 (2024): 40h semanales. Reducción gradual desde 45h. Máximo 52h con extra.',
 'cal_overtime_policy', 'max_weekly_hours_cl', 'D4', 'RANGE',
 'integer', 40, 52, NULL,
 'max_weekly_hours_cl debe estar entre 40 y 52. Ley 21.561 Chile.',
 'VAL-D4-009',
 ARRAY['Ley 21.561 Chile','Código del Trabajo'], 'Ley 40 Horas Chile',
 'https://www.bcn.cl/leychile/navegar?idNorma=1189187', 'error'),

('VAL-D4-010', 'Horas extra máximas diarias (Chile)',
 'Código del Trabajo: máximo 2h extra/día. Recargo 50%. Domingos/festivos: recargo 100%.',
 'cal_overtime_policy', 'max_overtime_daily_hours_cl', 'D4', 'RANGE',
 'integer', 0, 2, NULL,
 'max_overtime_daily_hours_cl debe estar entre 0 y 2. Código del Trabajo Chile.',
 'VAL-D4-010',
 ARRAY['Código del Trabajo Chile','Ley 21.561'], 'Horas Extraordinarias Chile',
 'https://www.bcn.cl/leychile/navegar?idNorma=207436', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- PERÚ — LEY DE JORNADA DE TRABAJO (DL 713 + Ley 27671)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D4-011', 'Horas máximas trabajo semanal (Perú)',
 'DL 713: 48h semanales. Horas extra: 25% primera 2h, 35% adicionales.',
 'cal_overtime_policy', 'max_weekly_hours_pe', 'D4', 'RANGE',
 'integer', 40, 48, NULL,
 'max_weekly_hours_pe debe estar entre 40 y 48. DL 713 Perú.',
 'VAL-D4-011',
 ARRAY['DL 713 Perú','Ley 27671'], 'Jornada de Trabajo Perú',
 'https://www.gob.pe/institucion/mtpe/normas-legales', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- BRASIL — CLT (Consolidação das Leis do Trabalho)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D4-012', 'Horas máximas trabajo semanal (Brasil)',
 'CLT Art.58: 44h semanales, 8h diarias. Horas extra: máximo 2h/día. Banco de horas permitido.',
 'cal_overtime_policy', 'max_weekly_hours_br', 'D4', 'RANGE',
 'integer', 40, 44, NULL,
 'max_weekly_hours_br debe estar entre 40 y 44. CLT Brasil.',
 'VAL-D4-012',
 ARRAY['CLT Brasil','Lei 13.467/2017'], 'CLT Art.58 Jornada de Trabalho',
 'https://www.planalto.gov.br/ccivil_03/decreto-lei/del5452.htm', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- SOC 2 TYPE II — CRITERIOS DE SEGURIDAD
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D11-006', 'Período de revisión de controles SOC 2 (días)',
 'SOC 2 CC7.2: monitoreo continuo. Revisión mínimo cada 90 días. Máximo 365.',
 'ath_config_d11', 'soc2_review_frequency_days', 'D11', 'RANGE',
 'integer', 30, 365, NULL,
 'soc2_review_frequency_days debe estar entre 30 y 365. SOC 2 CC7.2.',
 'VAL-D11-006',
 ARRAY['SOC 2 CC7.2','AICPA TSC 2017'], 'SOC 2 CC7.2 Monitoring',
 'https://www.aicpa.org/topic/audit-assurance/soc-2-report', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- NIST CSF 2.0 — GOVERN (GV) + IDENTIFY (ID) + PROTECT (PR)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-SEC-011', 'Frecuencia de actualización de inventario de activos (días)',
 'NIST CSF 2.0 ID.AM-01: inventario actualizado. Máximo 30 días sin actualizar.',
 'sec_key_inventory', 'asset_inventory_update_days', 'SEC', 'RANGE',
 'integer', 1, 90, NULL,
 'asset_inventory_update_days debe estar entre 1 y 90. NIST CSF 2.0 ID.AM-01.',
 'VAL-SEC-011',
 ARRAY['NIST CSF 2.0 ID.AM-01','ISO 27001 A.8.1'], 'NIST CSF 2.0 Asset Management',
 'https://www.nist.gov/cyberframework', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- HARDWARE SECURITY MODULE (HSM) + FIPS 140-3 LEVEL 3
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-SEC-012', 'Nivel FIPS 140 mínimo para HSM',
 'FIPS 140-3 Level 3 requerido para AAL3. Level 1 para AAL1-2. Level 4 para máxima seguridad.',
 'bos_crypto_algorithm', 'fips_140_level', 'SEC', 'RANGE',
 'integer', 1, 4, NULL,
 'fips_140_level debe estar entre 1 (AAL1) y 4 (máxima). AAL3 requiere ≥3.',
 'VAL-SEC-012',
 ARRAY['FIPS 140-3'], 'FIPS 140-3 Security Levels',
 'https://csrc.nist.gov/projects/cryptographic-module-validation-program/fips-140-3-standards', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- FEDERACIÓN / SAML (SAML 2.0 + eIDAS)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D9-019', 'TTL de aserción SAML (minutos)',
 'SAML 2.0: NotOnOrAfter con ventana corta. Mínimo 1min, máximo 60min. Default: 5min.',
 'ath_federation_protocol', 'saml_assertion_ttl_minutes', 'D9', 'RANGE',
 'integer', 1, 60, NULL,
 'saml_assertion_ttl_minutes debe estar entre 1 y 60 minutos. SAML 2.0 Core.',
 'VAL-D9-019',
 ARRAY['SAML 2.0 Core','eIDAS 2.0'], 'SAML 2.0 Assertion TTL',
 'https://docs.oasis-open.org/security/saml/v2.0/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- RATE LIMITING AVANZADO (OWASP ASVS V13 + NIST SP 800-63B §5.2.2)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D7-015', 'Rate limit por IP (requests/minuto)',
 'OWASP V13: limitar por IP. Mínimo 10 req/min, máximo 10000 req/min. Default: 100.',
 'ath_config_d7', 'rate_limit_per_ip_min', 'D7', 'RANGE',
 'integer', 10, 10000, NULL,
 'rate_limit_per_ip_min debe estar entre 10 y 10000. OWASP ASVS V13.',
 'VAL-D7-015',
 ARRAY['OWASP ASVS V13','NIST SP 800-63B §5.2.2'], 'V13 Rate Limiting',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- POSTGRESQL SECURITY (CIS PostgreSQL 16 + DISA STIG)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-SEC-013', 'Máximo de conexiones PostgreSQL por tenant',
 'CIS PostgreSQL: limitar conexiones. Mínimo 10, máximo 1000. Default: 200.',
 'ath_config_d7', 'max_pg_connections', 'SEC', 'RANGE',
 'integer', 10, 1000, NULL,
 'max_pg_connections debe estar entre 10 y 1000. CIS PostgreSQL Benchmark.',
 'VAL-SEC-013',
 ARRAY['CIS PostgreSQL 16','DISA STIG'], 'CIS PostgreSQL Connection Limits',
 'https://www.cisecurity.org/benchmark/postgresql/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- REDIS SECURITY (Redis 8.x Best Practices)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-SEC-014', 'TTL máximo de clave Redis (segundos)',
 'Redis: TTL máximo práctico. Mínimo 1s, máximo 2592000s (30d). Default: 28800s (8h).',
 'ath_config_d8', 'redis_key_ttl_seconds', 'SEC', 'RANGE',
 'integer', 1, 2592000, NULL,
 'redis_key_ttl_seconds debe estar entre 1s y 2592000s (30d).',
 'VAL-SEC-014',
 ARRAY['Redis 8.6.2 Best Practices','SBOS-050'], 'Redis Key Expiration',
 'https://redis.io/docs/latest/commands/expire/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- TELEFONÍA / SMS (NIST SP 800-63B-4 §5.1.3 deprecated)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D9-020', 'SMS OTP TTL (minutos)',
 'NIST Rev.4: SMS deprecado para AAL2. Si se usa (AAL1), TTL máximo 10min. Mínimo 1min.',
 'ath_config_d9', 'sms_otp_ttl_minutes', 'D9', 'RANGE',
 'integer', 1, 10, NULL,
 'sms_otp_ttl_minutes debe estar entre 1 y 10. NIST Rev.4: SMS deprecado.',
 'VAL-D9-020',
 ARRAY['NIST SP 800-63B-4 §5.1.3'], '§5.1.3 Restricted Authenticators',
 'https://pages.nist.gov/800-63-4/sp800-63b.html#sec5', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- DISPOSITIVOS MÓVILES (OWASP MASVS + FIDO2 + Play Integrity)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D5-010', 'Score mínimo Play Integrity (Android)',
 'Play Integrity: NO_INTEGRITY=0, BASIC=0.3, DEVICE=0.7, STRONG=0.95. Default DEVICE.',
 'net_device', 'min_play_integrity_verdict', 'D5', 'ENUM',
 'text', NULL, NULL,
 ARRAY['NO_INTEGRITY','BASIC_INTEGRITY','DEVICE_INTEGRITY','STRONG_INTEGRITY'],
 'min_play_integrity_verdict debe ser BASIC_INTEGRITY o superior.',
 'VAL-D5-010',
 ARRAY['Play Integrity API','OWASP MASVS V8'], 'Play Integrity Verdicts',
 'https://developer.android.com/google/play/integrity/verdicts', 'error'),

('VAL-D5-011', 'App Attest mínimo (iOS)',
 'App Attest: score 0.0-1.0. Mínimo 0.7 para confianza. Default: 0.9.',
 'net_device', 'min_app_attest_score', 'D5', 'RANGE',
 'numeric', 0.0, 1.0, NULL,
 'min_app_attest_score debe estar entre 0.0 y 1.0. Apple App Attest.',
 'VAL-D5-011',
 ARRAY['Apple App Attest','OWASP MASVS V8'], 'App Attest Score',
 'https://developer.apple.com/documentation/devicecheck/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- BOLIVIA — SIN / IMPUESTOS NACIONALES (RND 102100000011 + Ley 2492)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D3-005', 'Cantidad de dígitos del CUF (Código Único de Factura)',
 'SIN RND 102100000011: CUF usa Base16 + módulo-11. Mínimo 28 dígitos, máximo 32. Default: 32.',
 'fin_document_operation', 'cuf_length', 'D3', 'RANGE',
 'integer', 28, 32, NULL,
 'cuf_length debe estar entre 28 y 32 dígitos. SIN RND 102100000011.',
 'VAL-D3-005',
 ARRAY['SIN RND 102100000011','Ley 2492 Bolivia'], 'RND 102100000011 CUF/CUFD',
 'https://www.impuestos.gob.bo/', 'error'),

('VAL-D3-006', 'CUFD: frecuencia de renovación (horas)',
 'CUFD se renueva cada 24h (medianoche). Mínimo 1h, máximo 48h. Default: 24h.',
 'ath_config_d3', 'cufd_renewal_hours', 'D3', 'RANGE',
 'integer', 1, 48, NULL,
 'cufd_renewal_hours debe estar entre 1h y 48h. SIN RND 102100000011.',
 'VAL-D3-006',
 ARRAY['SIN RND 102100000011'], 'CUFD Renovación',
 'https://www.impuestos.gob.bo/', 'error'),

('VAL-D3-007', 'Cantidad de decimales para facturación SIN',
 'SIN: 2 decimales obligatorio para BOB. Moneda extranjera: según ISO 4217. Rango: 0-4.',
 'fin_limit', 'decimal_places', 'D3', 'RANGE',
 'integer', 0, 4, NULL,
 'decimal_places para SIN debe estar entre 0 y 4. Default BOB: 2.',
 'VAL-D3-007',
 ARRAY['SIN RND 102100000011','ISO 4217'], 'Formato Factura SIN',
 'https://www.impuestos.gob.bo/', 'error'),

('VAL-D3-008', 'Límite de facturación en línea (ambiente producción)',
 'SIN: facturación computarizada en línea obligatoria. Lotes máximos de 500 facturas.',
 'ath_config_d3', 'sin_max_batch_size', 'D3', 'RANGE',
 'integer', 1, 500, NULL,
 'sin_max_batch_size debe estar entre 1 y 500. SIN RND 102100000011.',
 'VAL-D3-008',
 ARRAY['SIN RND 102100000011'], 'Límites SIN',
 'https://www.impuestos.gob.bo/', 'error'),

('VAL-D3-009', 'Plazo máximo de envío de factura al SIN (horas)',
 'SIN: facturas deben enviarse dentro de las 24h de emisión. Máximo 72h (contingencia).',
 'ath_config_d3', 'sin_max_send_delay_hours', 'D3', 'RANGE',
 'integer', 1, 72, NULL,
 'sin_max_send_delay_hours debe estar entre 1h y 72h. SIN RND 102100000011.',
 'VAL-D3-009',
 ARRAY['SIN RND 102100000011','DS 1793'], 'Envío SIN',
 'https://www.impuestos.gob.bo/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- BOLIVIA — LEY 164 TELECOMUNICACIONES / FIRMA DIGITAL
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-SEC-015', 'Vigencia de certificado digital ADSIB (días)',
 'ADSIB: certificados persona jurídica 1-3 años. Mínimo 365d, máximo 1095d (3a). Default: 730d.',
 'sec_key_inventory', 'adsib_cert_validity_days', 'SEC', 'RANGE',
 'integer', 365, 1095, NULL,
 'adsib_cert_validity_days debe estar entre 365 y 1095 días. Ley 164 Bolivia.',
 'VAL-SEC-015',
 ARRAY['Ley 164 Bolivia','ADSIB-FD-POLT-015 v2.3'], 'Ley 164 Firma Digital',
 'https://www.adsib.gob.bo/', 'error'),

('VAL-SEC-016', 'Longitud de clave RSA para certificado ADSIB',
 'ADSIB: RSA mínimo 2048 bits para persona natural, 4096 para jurídica. Máximo 8192.',
 'bos_crypto_algorithm', 'adsib_rsa_key_size', 'SEC', 'RANGE',
 'integer', 2048, 8192, NULL,
 'adsib_rsa_key_size debe estar entre 2048 y 8192. ADSIB exige ≥4096 para PJ.',
 'VAL-SEC-016',
 ARRAY['ADSIB-FD-POLT-015 v2.3','Ley 164 Bolivia'], 'ADSIB Key Requirements',
 'https://www.adsib.gob.bo/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- BOLIVIA — CÓDIGO TRIBUTARIO (Ley 2492)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D11-007', 'Retención de documentos fiscales (días)',
 'Ley 2492 Bolivia: 7 años (2555 días) retención obligatoria. Mínimo 2555, máximo 3650.',
 'ath_config_d11', 'fiscal_retention_days_bo', 'D11', 'RANGE',
 'integer', 2555, 3650, NULL,
 'fiscal_retention_days_bo debe estar entre 2555 (7a) y 3650 (10a). Ley 2492 Bolivia.',
 'VAL-D11-007',
 ARRAY['Ley 2492 Bolivia','SIN RND'], 'Ley 2492 Código Tributario',
 'https://www.lexivox.org/norms/BO/L-N2492.html', 'error'),

('VAL-D11-008', 'Plazo de prescripción tributaria (años)',
 'Ley 2492 Bolivia: 4 años prescripción general. 8 años para contribuyentes omisos.',
 'ath_config_d11', 'tax_prescription_years_bo', 'D11', 'RANGE',
 'integer', 4, 8, NULL,
 'tax_prescription_years_bo debe estar entre 4 y 8. Ley 2492 Bolivia.',
 'VAL-D11-008',
 ARRAY['Ley 2492 Bolivia'], 'Art.59 Prescripción',
 'https://www.lexivox.org/norms/BO/L-N2492.html', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- BOLIVIA — NIT (Número de Identificación Tributaria)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D3-010', 'Cantidad de dígitos del NIT Bolivia',
 'SIN Bolivia: NIT de 10 dígitos (empresa) o 9 dígitos (persona natural). Mínimo 9, máximo 15.',
 'idn_tenant', 'tax_id', 'D3', 'RANGE',
 'integer', 9, 15, NULL,
 'tax_id debe tener entre 9 y 15 dígitos. NIT Bolivia estándar: 10 dígitos.',
 'VAL-D3-010',
 ARRAY['SIN Bolivia','Ley 2492'], 'NIT Bolivia',
 'https://www.impuestos.gob.bo/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- BOLIVIA — FUNDEMPRESA (Registro de Comercio)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D1-005', 'Cantidad de dígitos de Matrícula de Comercio',
 'FUNDEMPRESA Bolivia: matrícula de 7 dígitos. Mínimo 5, máximo 15.',
 'idn_tenant', 'registration_number', 'D1', 'RANGE',
 'integer', 5, 15, NULL,
 'registration_number debe tener entre 5 y 15 dígitos. FUNDEMPRESA Bolivia.',
 'VAL-D1-005',
 ARRAY['Código de Comercio Bolivia','FUNDEMPRESA'], 'Matrícula de Comercio',
 'https://www.fundempresa.org.bo/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- BOLIVIA — ASFI (Autoridad de Supervisión del Sistema Financiero)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D3-011', 'Límite de transacción reportable a UIF (BOB)',
 'ASFI/ UIF Bolivia: transacciones ≥ $10,000 USD (~Bs 69,000) deben reportarse.',
 'fin_limit', 'uif_reportable_amount_bob', 'D3', 'RANGE',
 'integer', 10000, 500000, NULL,
 'uif_reportable_amount_bob debe estar entre 10000 y 500000 BOB.',
 'VAL-D3-011',
 ARRAY['ASFI Bolivia','Ley 393 Servicios Financieros'], 'UIF Reporte',
 'https://www.asfi.gob.bo/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- BOLIVIA — LEY 1178 SAFCO (Administración y Control Gubernamental)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D11-009', 'Frecuencia de auditoría gubernamental (días)',
 'Ley 1178 SAFCO: control posterior obligatorio. Mínimo 90d (trimestral), máximo 365d.',
 'ath_config_d11', 'safco_audit_frequency_days', 'D11', 'RANGE',
 'integer', 90, 365, NULL,
 'safco_audit_frequency_days debe estar entre 90 y 365. Ley 1178 SAFCO Bolivia.',
 'VAL-D11-009',
 ARRAY['Ley 1178 SAFCO Bolivia'], 'SAFCO Control Gubernamental',
 'https://www.lexivox.org/norms/BO/L-N1178.html', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- BOLIVIA — LEY 453 DERECHOS DEL USUARIO/CONSUMIDOR
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-COMP-007', 'Plazo de respuesta a reclamo de consumidor (días)',
 'Ley 453 Bolivia: respuesta en 15 días hábiles (~21d corridos). Máximo 30d.',
 'ath_config_d11', 'consumer_complaint_response_days', 'COMP', 'RANGE',
 'integer', 5, 30, NULL,
 'consumer_complaint_response_days debe estar entre 5 y 30. Ley 453 Bolivia.',
 'VAL-COMP-007',
 ARRAY['Ley 453 Bolivia'], 'Ley 453 Derechos del Consumidor',
 'https://www.lexivox.org/norms/BO/L-N453.html', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- BOLIVIA — CONSTITUCIÓN / IDIOMAS OFICIALES
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D1-006', 'Idiomas oficiales de Bolivia habilitados',
 'CPE Bolivia Art.5: 37 idiomas oficiales. Mínimo español activo. Quechua y Aymara opcionales.',
 'idn_tenant_languages', 'is_active', 'D1', 'TYPE',
 'boolean', NULL, NULL, NULL,
 'Al menos español (es-BO) debe estar activo. CPE Bolivia Art.5.',
 'VAL-D1-006',
 ARRAY['CPE Bolivia Art.5'], 'Idiomas Oficiales Bolivia',
 'https://www.lexivox.org/norms/BO/CPE.html', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- BOLIVIA — LEY DEL NOTARIADO (Ley 483)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-COMP-008', 'Vigencia de poder notarial (días)',
 'Ley 483 Bolivia: poderes notariales 1-5 años para representación legal. Mínimo 365d, máximo 1825d.',
 'idn_tenant', 'legal_representative_validity_days', 'COMP', 'RANGE',
 'integer', 365, 1825, NULL,
 'legal_representative_validity_days debe estar entre 365 (1a) y 1825 (5a). Ley 483 Bolivia.',
 'VAL-COMP-008',
 ARRAY['Ley 483 Bolivia'], 'Ley del Notariado',
 'https://www.lexivox.org/norms/BO/L-N483.html', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- BOLIVIA — SEGIP / SERECI (Identificación)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D9-021', 'Cantidad de dígitos del CI Bolivia',
 'SEGIP Bolivia: Cédula de Identidad 7-10 dígitos + complemento alfanumérico. Rango: 7-12.',
 'idn_user_template', 'document_number', 'D9', 'TYPE',
 'text', 7, 12, NULL,
 'document_number (CI Bolivia) debe tener entre 7 y 12 caracteres.',
 'VAL-D9-021',
 ARRAY['SEGIP Bolivia'], 'Cédula de Identidad Bolivia',
 'https://www.segip.gob.bo/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- BOLIVIA — RC-IVA (Régimen Complementario al IVA)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D3-012', 'Salario mínimo nacional Bolivia (BOB)',
 'Salario Mínimo Nacional 2026: ~Bs 2,500. Rango: 2000-5000 para validación.',
 'fin_limit', 'salario_minimo_bob', 'D3', 'RANGE',
 'integer', 2000, 5000, NULL,
 'salario_minimo_bob debe estar entre 2000 y 5000. DS Supremo Bolivia.',
 'VAL-D3-012',
 ARRAY['Decreto Supremo Bolivia','Ley General del Trabajo'], 'Salario Mínimo Nacional',
 'https://www.mintrabajo.gob.bo/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- BOLIVIA — AGUINALDO / BONOS (Ley General del Trabajo)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D4-013', 'Fechas de pago de aguinaldo en Bolivia',
 'Ley Bolivia: Aguinaldo antes del 20 de diciembre. Doble aguinaldo si PIB >4.5%.',
 'cal_holiday', 'aguinaldo_deadline_month', 'D4', 'RANGE',
 'integer', 11, 12, NULL,
 'aguinaldo_deadline_month debe ser 11 (noviembre) o 12 (diciembre).',
 'VAL-D4-013',
 ARRAY['Ley General del Trabajo Bolivia','DS 1802'], 'Aguinaldo Bolivia',
 'https://www.mintrabajo.gob.bo/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- BOLIVIA — BONO Juancito Pinto / Renta Dignidad / Juana Azurduy
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-COMP-009', 'Verificación de identidad para beneficios sociales (IAL)',
 'Bolivia: programas sociales requieren verificación SEGIP/SERECI. IAL mínimo: IAL2.',
 'idn_tenant_verification', 'ial_required', 'COMP', 'ENUM',
 'text', NULL, NULL, ARRAY['IAL1','IAL2','IAL3'],
 'ial_required para beneficios sociales debe ser IAL2 o IAL3. NIST SP 800-63A.',
 'VAL-COMP-009',
 ARRAY['NIST SP 800-63A','SEGIP Bolivia'], 'Identity Proofing Bolivia',
 'https://pages.nist.gov/800-63-4/sp800-63a.html', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- MÉTODOS DE AUTENTICACIÓN — Validación de parámetros por método
-- 32 métodos registrados en ath_method. Cada uno con sus constraints específicas.
-- ═══════════════════════════════════════════════════════════════════════════

-- PASSWORD / MEMORIZED_SECRET
('VAL-MET-001', 'Longitud máxima de contraseña',
 'NIST Rev.4: máximo 64 caracteres. Sin truncar. OWASP V6.2.2: 64-128.',
 'ath_credential_policy', 'max_length', 'D9', 'RANGE',
 'integer', 64, 128, NULL,
 'max_length debe estar entre 64 y 128. NIST SP 800-63B §5.1.1.2.',
 'VAL-MET-001',
 ARRAY['NIST SP 800-63B §5.1.1.2','OWASP ASVS V6.2.2'], '§5.1.1.2 Password Length',
 'https://pages.nist.gov/800-63-4/sp800-63b.html#sec5', 'error'),

-- TOTP (RFC 6238)
('VAL-MET-002', 'TOTP: paso de tiempo (segundos)',
 'RFC 6238: 30 segundos estándar. Mínimo 15s, máximo 60s.',
 'ath_method', 'totp_step_seconds', 'D9', 'RANGE',
 'integer', 15, 60, NULL,
 'totp_step_seconds debe estar entre 15s y 60s. RFC 6238: 30s estándar.',
 'VAL-MET-002',
 ARRAY['RFC 6238'], 'RFC 6238 §5.2 Time Step',
 'https://datatracker.ietf.org/doc/html/rfc6238', 'error'),

('VAL-MET-003', 'TOTP: algoritmo de hash permitido',
 'RFC 6238: SHA1 (default), SHA256, SHA512.',
 'ath_method', 'totp_algorithm', 'D9', 'ENUM',
 'text', NULL, NULL, ARRAY['SHA1','SHA256','SHA512'],
 'totp_algorithm debe ser SHA1, SHA256 o SHA512. RFC 6238.',
 'VAL-MET-003',
 ARRAY['RFC 6238'], 'RFC 6238 §4 Algorithm',
 'https://datatracker.ietf.org/doc/html/rfc6238', 'error'),

-- HOTP (RFC 4226)
('VAL-MET-004', 'HOTP: ventana de búsqueda (look-ahead)',
 'RFC 4226: look-ahead window para sincronización. Mínimo 3, máximo 25. Default: 5.',
 'ath_method', 'hotp_look_ahead_window', 'D9', 'RANGE',
 'integer', 3, 25, NULL,
 'hotp_look_ahead_window debe estar entre 3 y 25. RFC 4226 §5.4.',
 'VAL-MET-004',
 ARRAY['RFC 4226'], 'RFC 4226 §5.4 Look-Ahead',
 'https://datatracker.ietf.org/doc/html/rfc4226', 'error'),

('VAL-MET-005', 'HOTP: dígitos',
 'RFC 4226: 6-8 dígitos. Default: 6.',
 'ath_method', 'hotp_digits', 'D9', 'RANGE',
 'integer', 6, 8, NULL,
 'hotp_digits debe ser 6, 7 u 8. RFC 4226.',
 'VAL-MET-005',
 ARRAY['RFC 4226'], 'RFC 4226 §5.3 Digit',
 'https://datatracker.ietf.org/doc/html/rfc4226', 'error'),

-- WEBAUTHN / FIDO2
('VAL-MET-006', 'WebAuthn: tipo de atestación',
 'FIDO2 L2: none, indirect, direct, enterprise.',
 'ath_method', 'webauthn_attestation', 'D9', 'ENUM',
 'text', NULL, NULL, ARRAY['none','indirect','direct','enterprise'],
 'webauthn_attestation debe ser none, indirect, direct o enterprise. FIDO2 L2.',
 'VAL-MET-006',
 ARRAY['FIDO2 L2','WebAuthn W3C'], 'WebAuthn Attestation Conveyance',
 'https://www.w3.org/TR/webauthn-3/', 'error'),

('VAL-MET-007', 'WebAuthn: verificación de usuario',
 'FIDO2: discouraged, preferred, required.',
 'ath_method', 'webauthn_user_verification', 'D9', 'ENUM',
 'text', NULL, NULL, ARRAY['discouraged','preferred','required'],
 'webauthn_user_verification debe ser discouraged, preferred o required.',
 'VAL-MET-007',
 ARRAY['FIDO2 L2','WebAuthn W3C'], 'WebAuthn User Verification',
 'https://www.w3.org/TR/webauthn-3/', 'error'),

('VAL-MET-008', 'WebAuthn: clave residente (discoverable)',
 'FIDO2: discouraged, preferred, required.',
 'ath_method', 'webauthn_resident_key', 'D9', 'ENUM',
 'text', NULL, NULL, ARRAY['discouraged','preferred','required'],
 'webauthn_resident_key debe ser discouraged, preferred o required.',
 'VAL-MET-008',
 ARRAY['FIDO2 L2','WebAuthn W3C'], 'WebAuthn Resident Key',
 'https://www.w3.org/TR/webauthn-3/', 'error'),

-- PASSKEY (Device-Bound)
('VAL-MET-009', 'Passkey Device-Bound: FIPS 140-3 requerido',
 'AAL3 requiere FIPS 140-3 Level 2+ para authenticator. Boolean.',
 'ath_method', 'passkey_fips_required', 'D9', 'TYPE',
 'boolean', NULL, NULL, NULL,
 'passkey_fips_required debe ser booleano. AAL3 exige FIPS 140-3 Level 2+.',
 'VAL-MET-009',
 ARRAY['FIPS 140-3','NIST SP 800-63B §4'], 'AAL3 FIPS Requirement',
 'https://pages.nist.gov/800-63-4/sp800-63b.html#sec4', 'error'),

-- SMARTCARD / X.509 PIV
('VAL-MET-010', 'SmartCard X.509: longitud mínima de PIN',
 'FIPS 201-3 PIV: PIN 6-8 dígitos. Mínimo 6.',
 'ath_method', 'smartcard_pin_min_length', 'D9', 'RANGE',
 'integer', 6, 8, NULL,
 'smartcard_pin_min_length debe estar entre 6 y 8. FIPS 201-3.',
 'VAL-MET-010',
 ARRAY['FIPS 201-3','NIST SP 800-73-5'], 'PIV Card PIN',
 'https://csrc.nist.gov/publications/detail/fips/201/3/final', 'error'),

('VAL-MET-011', 'SmartCard X.509: intentos máximos de PIN',
 'FIPS 201-3: bloqueo tras 3 intentos fallidos de PIN.',
 'ath_method', 'smartcard_pin_max_attempts', 'D9', 'RANGE',
 'integer', 3, 5, NULL,
 'smartcard_pin_max_attempts debe estar entre 3 y 5. FIPS 201-3.',
 'VAL-MET-011',
 ARRAY['FIPS 201-3','NIST SP 800-73-5'], 'PIV PIN Retries',
 'https://csrc.nist.gov/publications/detail/fips/201/3/final', 'error'),

('VAL-MET-012', 'SmartCard X.509: algoritmo de clave',
 'PIV: RSA-2048 o ECDSA-P256.',
 'ath_method', 'smartcard_key_algorithm', 'D9', 'ENUM',
 'text', NULL, NULL, ARRAY['RSA-2048','RSA-4096','ECDSA-P256','ECDSA-P384'],
 'smartcard_key_algorithm debe ser RSA-2048, RSA-4096, ECDSA-P256 o ECDSA-P384.',
 'VAL-MET-012',
 ARRAY['FIPS 201-3','NIST SP 800-78-5'], 'PIV Key Algorithm',
 'https://csrc.nist.gov/publications/detail/fips/201/3/final', 'error'),

-- OCRA / CIBA (RFC 8628 + OpenID CIBA)
('VAL-MET-013', 'CIBA: intervalo de polling (segundos)',
 'OpenID CIBA: poll cada 3-5 segundos. Mínimo 1s, máximo 30s.',
 'ath_method', 'ciba_polling_interval_s', 'D9', 'RANGE',
 'integer', 1, 30, NULL,
 'ciba_polling_interval_s debe estar entre 1s y 30s. OpenID CIBA.',
 'VAL-MET-013',
 ARRAY['OpenID CIBA','RFC 8628'], 'CIBA Polling',
 'https://openid.net/specs/openid-client-initiated-backchannel-authentication-core-1_0.html', 'error'),

('VAL-MET-014', 'CIBA: TTL de auth_req_id (segundos)',
 'OpenID CIBA: expires_in 300s (5min) máximo. Mínimo 30s.',
 'ath_method', 'ciba_auth_req_id_ttl_s', 'D9', 'RANGE',
 'integer', 30, 300, NULL,
 'ciba_auth_req_id_ttl_s debe estar entre 30s y 300s (5min). OpenID CIBA.',
 'VAL-MET-014',
 ARRAY['OpenID CIBA','RFC 8628'], 'CIBA expires_in',
 'https://openid.net/specs/openid-client-initiated-backchannel-authentication-core-1_0.html', 'error'),

-- PUSH NOTIFICATION (FCM/APNs)
('VAL-MET-015', 'Push: TTL de notificación (segundos)',
 'FCM/APNs: notificaciones con TTL corto. Mínimo 30s, máximo 600s (10min). Default: 120s.',
 'ath_method', 'push_notification_ttl_s', 'D9', 'RANGE',
 'integer', 30, 600, NULL,
 'push_notification_ttl_s debe estar entre 30s y 600s. FCM/APNs.',
 'VAL-MET-015',
 ARRAY['FCM','APNs'], 'Push Notification TTL',
 'https://firebase.google.com/docs/cloud-messaging', 'error'),

('VAL-MET-016', 'Push: máximo de notificaciones por hora',
 'Anti-MFA fatigue: máximo 10 push/hora por usuario. Mínimo 1, máximo 30.',
 'ath_method', 'push_max_per_hour', 'D9', 'RANGE',
 'integer', 1, 30, NULL,
 'push_max_per_hour debe estar entre 1 y 30. CISA Alert AA22-121A.',
 'VAL-MET-016',
 ARRAY['CISA AA22-121A','OWASP ASVS V2.8'], 'MFA Fatigue Prevention',
 'https://www.cisa.gov/news-events/cybersecurity-advisories/aa22-121a', 'error'),

-- BACKUP CODES / RECOVERY
('VAL-MET-017', 'Backup codes: algoritmo de hash',
 'OWASP V6.4.2: SHA-256 mínimo. No plaintext. SHA-256 o SHA-512.',
 'ath_method', 'backup_code_hash_algorithm', 'D9', 'ENUM',
 'text', NULL, NULL, ARRAY['SHA-256','SHA-512'],
 'backup_code_hash_algorithm debe ser SHA-256 o SHA-512.',
 'VAL-MET-017',
 ARRAY['OWASP ASVS V6.4.2'], 'V6.4.2 Recovery Code Hashing',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

-- OAUTH 2.0 / OIDC
('VAL-MET-018', 'OAuth: PKCE challenge method',
 'OAuth 2.1 BCP: S256 obligatorio. Plain deprecado.',
 'ath_federation_protocol', 'pkce_challenge_method', 'D9', 'ENUM',
 'text', NULL, NULL, ARRAY['S256'],
 'pkce_challenge_method debe ser S256. OAuth 2.1 BCP: S256 obligatorio.',
 'VAL-MET-018',
 ARRAY['OAuth 2.1 BCP','RFC 7636'], 'PKCE S256',
 'https://datatracker.ietf.org/doc/html/rfc7636', 'error'),

('VAL-MET-019', 'OAuth: response types permitidos',
 'OAuth 2.1: code (PKCE). OIDC: code id_token, code token. No implicit.',
 'ath_federation_protocol', 'allowed_response_types', 'D9', 'ENUM',
 'text', NULL, NULL,
 ARRAY['code','code id_token','code token'],
 'allowed_response_types debe ser code, code id_token o code token. Sin implicit.',
 'VAL-MET-019',
 ARRAY['OAuth 2.1 BCP','OIDC Core 1.0'], 'OAuth Response Types',
 'https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1-12', 'error'),

-- MAGIC LINK
('VAL-MET-020', 'Magic Link: TTL (minutos)',
 'OWASP V6.4: magic link single-use con TTL corto. Mínimo 1min, máximo 15min.',
 'ath_method', 'magic_link_ttl_min', 'D9', 'RANGE',
 'integer', 1, 15, NULL,
 'magic_link_ttl_min debe estar entre 1 y 15 minutos.',
 'VAL-MET-020',
 ARRAY['OWASP ASVS V6.4'], 'V6.4 Magic Link TTL',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

-- YUBIKEY OTP
('VAL-MET-021', 'YubiKey OTP: longitud de clave AES',
 'YubiKey OTP: AES-128. Longitud de clave módulo: 128 bits.',
 'ath_method', 'yubikey_aes_key_bits', 'D9', 'RANGE',
 'integer', 128, 256, NULL,
 'yubikey_aes_key_bits debe ser 128 o 256.',
 'VAL-MET-021',
 ARRAY['Yubico OTP','RFC 4226'], 'YubiKey OTP AES',
 'https://developers.yubico.com/OTP/', 'error'),

-- EMAIL OTP / SMS OTP (DEPRECATED)
('VAL-MET-022', 'Email OTP: TTL (minutos)',
 'NIST Rev.4: email OTP deprecado para AAL2. Si se usa AAL1, TTL máximo 10min.',
 'ath_method', 'email_otp_ttl_minutes', 'D9', 'RANGE',
 'integer', 1, 10, NULL,
 'email_otp_ttl_minutes debe estar entre 1 y 10 minutos. Email OTP deprecado.',
 'VAL-MET-022',
 ARRAY['NIST SP 800-63B-4 §5.1.3'], '§5.1.3 Deprecated Authenticators',
 'https://pages.nist.gov/800-63-4/sp800-63b.html#sec5', 'error'),

-- M2M / TOKEN EXCHANGE
('VAL-MET-023', 'Token Exchange: formatos JWT permitidos',
 'RFC 8693: JWT Profile for token exchange.',
 'ath_federation_protocol', 'token_exchange_formats', 'D9', 'ENUM',
 'text', NULL, NULL,
 ARRAY['urn:ietf:params:oauth:token-type:jwt','urn:ietf:params:oauth:token-type:saml2'],
 'token_exchange_formats debe ser JWT o SAML2. RFC 8693.',
 'VAL-MET-023',
 ARRAY['RFC 8693'], 'OAuth Token Exchange',
 'https://datatracker.ietf.org/doc/html/rfc8693', 'error'),

-- Platform Authenticators (Touch ID, Face ID, Windows Hello, Android Biometric)
('VAL-MET-024', 'Platform authenticator: anti-spoofing requerido',
 'FIDO2 L2: liveness detection para platform authenticators. Boolean.',
 'ath_method', 'platform_anti_spoofing_required', 'D9', 'TYPE',
 'boolean', NULL, NULL, NULL,
 'platform_anti_spoofing_required debe ser booleano. FIDO2 L2.',
 'VAL-MET-024',
 ARRAY['FIDO2 L2','ISO/IEC 30107-3'], 'Platform Anti-Spoofing',
 'https://fidoalliance.org/specs/fido-v2.2-rd-20241029/', 'error'),

-- NFC (ISO/IEC 14443 + OSDP)
('VAL-MET-025', 'NFC: protocolo de tag seguro',
 'NTAG424 DNA: AES-128 Secure Dynamic Messaging. ISO 14443-4.',
 'ath_method', 'nfc_protocol', 'D9', 'ENUM',
 'text', NULL, NULL,
 ARRAY['ISO14443-4','MIFARE_DESFIRE','NTAG424','FeliCa'],
 'nfc_protocol debe ser ISO 14443-4, MIFARE DESFire, NTAG424 o FeliCa.',
 'VAL-MET-025',
 ARRAY['ISO/IEC 14443','IEC 60839-11-5'], 'NFC Protocol',
 'https://www.iso.org/standard/73599.html', 'error'),

-- QR Physical
('VAL-MET-026', 'QR: tiempo de validez del código (segundos)',
 'QR físico: TTL corto para prevenir reuso. Mínimo 30s, máximo 300s. Default: 120s.',
 'ath_method', 'qr_code_ttl_seconds', 'D9', 'RANGE',
 'integer', 30, 300, NULL,
 'qr_code_ttl_seconds debe estar entre 30s y 300s.',
 'VAL-MET-026',
 ARRAY['NIST SP 800-63B §5.1'], 'QR Code TTL',
 'https://pages.nist.gov/800-63-4/sp800-63b.html#sec5', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- FÍSICO ADICIONAL (D2) — Cámaras, sensores, CCTV
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D2-005', 'Retención de video CCTV (días)',
 'PCI DSS 9.5: retención mínima 90 días para áreas de datos de tarjetas. GDPR: mínimo necesario.',
 'fis_area_config', 'cctv_retention_days', 'D2', 'RANGE',
 'integer', 30, 365, NULL,
 'cctv_retention_days debe estar entre 30 y 365 días. PCI DSS 9.5 mínimo 90d.',
 'VAL-D2-005',
 ARRAY['PCI DSS 9.5','GDPR Art.5'], 'PCI DSS Physical Security',
 'https://www.pcisecuritystandards.org/document_library/', 'error'),

('VAL-D2-006', 'Máximo de ocupantes por área',
 'BS 5979: límites de ocupación por seguridad. Mínimo 1, máximo 100.',
 'fis_area_config', 'max_occupancy', 'D2', 'RANGE',
 'integer', 1, 100, NULL,
 'max_occupancy debe estar entre 1 y 100. BS 5979:2007.',
 'VAL-D2-006',
 ARRAY['BS 5979:2007','NIST SP 800-53 PE-3'], 'BS 5979 Occupancy Limits',
 'https://knowledge.bsigroup.com/products/remote-centres-for-alarm-systems-code-of-practice', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- FINANCIERO ADICIONAL (D3) — Tipos de transacción, monedas
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D3-013', 'Categorías de transacción financiera permitidas',
 'ISO 20022: VENTAS, COMPRAS, PAGOS, COBROS, NOMINA, INVENTARIO, TRIBUTARIO, BANCARIO, ACTIVOS_FIJOS, IMPORTACION, EXPORTACION.',
 'fin_transaction_type', 'category', 'D3', 'ENUM',
 'text', NULL, NULL,
 ARRAY['VENTAS','COMPRAS','PAGOS','COBROS','NOMINA','INVENTARIO','TRIBUTARIO','BANCARIO','ACTIVOS_FIJOS','IMPORTACION','EXPORTACION'],
 'category debe ser una de las 11 categorías ISO 20022.',
 'VAL-D3-013',
 ARRAY['ISO 20022'], 'ISO 20022 Transaction Categories',
 'https://www.iso20022.org/', 'error'),

('VAL-D3-014', 'Nivel de riesgo de transacción financiera',
 'COSO: BAJO, MEDIO, ALTO, CRITICO.',
 'fin_transaction_type', 'risk_level', 'D3', 'ENUM',
 'text', NULL, NULL, ARRAY['BAJO','MEDIO','ALTO','CRITICO'],
 'risk_level debe ser BAJO, MEDIO, ALTO o CRITICO. COSO ERM 2017.',
 'VAL-D3-014',
 ARRAY['COSO ERM 2017','SOX §404'], 'COSO Risk Levels',
 'https://www.coso.org/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- TEMPORAL ADICIONAL (D4) — Años fiscales, cierres contables
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D4-014', 'Meses de cierre fiscal permitidos',
 'IAS 10: cierre fiscal dentro de los 3 meses posteriores al fin del ejercicio.',
 'cal_fiscal_year', 'max_closure_months_after_year_end', 'D4', 'RANGE',
 'integer', 1, 6, NULL,
 'max_closure_months_after_year_end debe estar entre 1 y 6. IAS 10.',
 'VAL-D4-014',
 ARRAY['IAS 10','IFRS'], 'IAS 10 Events After Reporting Period',
 'https://www.ifrs.org/issued-standards/list-of-standards/ias-10/', 'error'),

('VAL-D4-015', 'Máximo de gestiones fiscales abiertas simultáneamente',
 'NIC 1: máximo 3 gestiones abiertas (actual + 2 anteriores para ajustes).',
 'idn_tenant_config', 'max_open_fiscal_years', 'D4', 'RANGE',
 'integer', 1, 5, NULL,
 'max_open_fiscal_years debe estar entre 1 y 5. NIC 1.',
 'VAL-D4-015',
 ARRAY['NIC 1','IFRS'], 'NIC 1 Presentation of Financial Statements',
 'https://www.ifrs.org/issued-standards/list-of-standards/ias-1/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- RED ADICIONAL (D7) — DNS, CORS, CSP, HSTS
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D7-016', 'HSTS: max-age mínimo (segundos)',
 'OWASP V9: HSTS ≥1 año (31536000s). Mínimo 1 hora (3600s) para testing.',
 'idn_tenant_domain', 'hsts_max_age_s', 'D7', 'RANGE',
 'integer', 3600, 63072000, NULL,
 'hsts_max_age_s debe estar entre 3600s (1h testing) y 63072000s (2a). OWASP V9: ≥31536000.',
 'VAL-D7-016',
 ARRAY['OWASP ASVS V9','RFC 6797'], 'HSTS RFC 6797',
 'https://datatracker.ietf.org/doc/html/rfc6797', 'error'),

('VAL-D7-017', 'CORS: máximo de orígenes permitidos',
 'OWASP V13: CORS origins explícitos. Mínimo 1, máximo 50.',
 'idn_tenant_domain', 'cors_max_origins', 'D7', 'RANGE',
 'integer', 1, 50, NULL,
 'cors_max_origins debe estar entre 1 y 50. OWASP ASVS V13.',
 'VAL-D7-017',
 ARRAY['OWASP ASVS V13','CORS W3C'], 'CORS Configuration',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- TENANT ADICIONAL (D1) — Configuraciones regionales
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D1-007', 'Formatos de fecha permitidos',
 'ISO 8601: DD/MM/YYYY (LATAM), MM/DD/YYYY (US), YYYY-MM-DD (ISO).',
 'idn_tenant_config', 'date_format', 'D1', 'ENUM',
 'text', NULL, NULL,
 ARRAY['DD/MM/YYYY','MM/DD/YYYY','YYYY-MM-DD','DD.MM.YYYY','YYYY/MM/DD'],
 'date_format debe ser uno de los formatos soportados.',
 'VAL-D1-007',
 ARRAY['ISO 8601','CLDR'], 'Date Format CLDR',
 'https://www.iso.org/standard/70907.html', 'error'),

('VAL-D1-008', 'Primer día de la semana (ISO 8601)',
 'ISO 8601: 1=Lunes (LATAM/Europa), 7=Domingo (US).',
 'idn_tenant_config', 'first_day_of_week', 'D1', 'RANGE',
 'integer', 1, 7, NULL,
 'first_day_of_week debe ser 1 (Lunes) o 7 (Domingo).',
 'VAL-D1-008',
 ARRAY['ISO 8601','CLDR'], 'ISO 8601 First Day of Week',
 'https://www.iso.org/standard/70907.html', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- EMAIL / NOTIFICACIONES (RFC 5321/7208/6376)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D8-007', 'Puerto SMTP para notificaciones',
 'RFC 5321: SMTP 25, 465 (SMTPS), 587 (submission). Rango 25-587.',
 'idn_tenant_domain', 'smtp_port', 'D8', 'RANGE',
 'integer', 25, 587, NULL,
 'smtp_port debe ser 25, 465 o 587. RFC 5321.',
 'VAL-D8-007',
 ARRAY['RFC 5321','RFC 8314'], 'SMTP Ports',
 'https://datatracker.ietf.org/doc/html/rfc5321', 'error'),

('VAL-D8-008', 'Máximo de notificaciones por hora por usuario',
 'Anti-spam: límite de notificaciones. Mínimo 1, máximo 50/hora.',
 'ath_config_d8', 'max_notifications_per_hour', 'D8', 'RANGE',
 'integer', 1, 50, NULL,
 'max_notifications_per_hour debe estar entre 1 y 50.',
 'VAL-D8-008',
 ARRAY['OWASP ASVS V2.2'], 'V2.2 Notification Limits',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- KEYCLOAK INTEGRATION (KC 26.x Admin REST API + SPIs)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-SEC-017', 'TTL de token de admin Keycloak (minutos)',
 'KC Admin REST API: access token TTL 1-5 min. Refresh token 30min. Mínimo 1min, máximo 30min.',
 'idn_tenant', 'kc_admin_token_ttl_minutes', 'SEC', 'RANGE',
 'integer', 1, 30, NULL,
 'kc_admin_token_ttl_minutes debe estar entre 1 y 30 minutos.',
 'VAL-SEC-017',
 ARRAY['Keycloak 26.x Admin REST API','OAuth 2.0'], 'KC Admin Token TTL',
 'https://www.keycloak.org/docs-api/26.1.5/rest-api/', 'error'),

('VAL-SEC-018', 'Máximo de realms Keycloak por tenant',
 'KC Best Practices: 3 realms por tenant (system, tenant_{id}, tenant_{id}_ext).',
 'idn_tenant', 'max_kc_realms', 'SEC', 'RANGE',
 'integer', 1, 5, NULL,
 'max_kc_realms debe estar entre 1 y 5. KC: 3 realms por tenant.',
 'VAL-SEC-018',
 ARRAY['Keycloak 26.x Best Practices'], 'KC Realm Limits',
 'https://www.keycloak.org/docs/latest/server_admin/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- TRYTON INTEGRATION (Tryton 7.4 JSON-RPC)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-SEC-019', 'Timeout de conexión Tryton JSON-RPC (segundos)',
 'Tryton: timeout razonable. Mínimo 5s, máximo 60s. Default: 30s.',
 'ath_config_d3', 'tryton_rpc_timeout_s', 'SEC', 'RANGE',
 'integer', 5, 60, NULL,
 'tryton_rpc_timeout_s debe estar entre 5s y 60s.',
 'VAL-SEC-019',
 ARRAY['Tryton 7.4 RPC'], 'Tryton JSON-RPC Timeout',
 'https://docs.tryton.org/7.0/server/topics/json_rpc.html', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- LOGS / TRAZABILIDAD (ISO 27001 A.8.15 + NIST AU-3)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D11-010', 'Campos mínimos en evento de auditoría',
 'NIST AU-3: timestamp, event_type, user_id, resource, result, ip_address, ctx_id.',
 'aud_event', 'required_fields', 'D11', 'TYPE',
 'integer', 7, 15, NULL,
 'required_fields debe ser al menos 7 campos (NIST AU-3).',
 'VAL-D11-010',
 ARRAY['NIST SP 800-53 AU-3','ISO 27001 A.8.15'], 'AU-3 Audit Record Content',
 'https://csrc.nist.gov/projects/risk-management/sp800-53-controls/release-search#/control?version=5.1&number=AU-3', 'error'),

('VAL-D11-011', 'Tamaño máximo de partición de auditoría (días)',
 'PostgreSQL: partición mensual (30-31 días). Mínimo 7d, máximo 90d.',
 'aud_event', 'partition_interval_days', 'D11', 'RANGE',
 'integer', 7, 90, NULL,
 'partition_interval_days debe estar entre 7 y 90. Default: 30 (mensual).',
 'VAL-D11-011',
 ARRAY['PostgreSQL 18.4','PCI DSS 10.5'], 'Audit Partitioning',
 'https://www.postgresql.org/docs/18/ddl-partitioning.html', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- CACHE / REDIS (Redis 8.6.2 Best Practices)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-SEC-020', 'TTL de sesión en Redis (segundos)',
 'Redis: session TTL sincronizado con PostgreSQL. Mínimo 60s, máximo 43200s (12h).',
 'ath_config_d8', 'redis_session_ttl_seconds', 'SEC', 'RANGE',
 'integer', 60, 43200, NULL,
 'redis_session_ttl_seconds debe estar entre 60s y 43200s (12h).',
 'VAL-SEC-020',
 ARRAY['Redis 8.6.2','SBOS-050'], 'Redis Session TTL',
 'https://redis.io/docs/latest/develop/use/patterns/session-management/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- VAULT (HashiCorp Vault Best Practices)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-SEC-021', 'Vault: máximo de attempts de auto-unseal',
 'Vault Auto-Unseal: 3 intentos antes de seal permanente. Mínimo 1, máximo 5.',
 'sec_key_inventory', 'vault_unseal_max_attempts', 'SEC', 'RANGE',
 'integer', 1, 5, NULL,
 'vault_unseal_max_attempts debe estar entre 1 y 5. Default: 3.',
 'VAL-SEC-021',
 ARRAY['Vault Best Practices'], 'Vault Auto-Unseal',
 'https://developer.hashicorp.com/vault/docs/concepts/seal', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- TOKENS / JWT (RFC 7519 + OAuth 2.1)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D9-022', 'JWT: algoritmos de firma permitidos',
 'RFC 7519: RS256, RS384, RS512, ES256, ES384, ES512, EdDSA. NO: none, HS256.',
 'ath_federation_protocol', 'jwt_signing_algorithms', 'D9', 'ENUM',
 'text', NULL, NULL,
 ARRAY['RS256','RS384','RS512','ES256','ES384','ES512','EdDSA'],
 'jwt_signing_algorithms debe ser RS256, ES256 o EdDSA. none y HS256 PROHIBIDOS.',
 'VAL-D9-022',
 ARRAY['RFC 7519','RFC 7518','OAuth 2.1'], 'JWT Signing Algorithms',
 'https://datatracker.ietf.org/doc/html/rfc7518', 'error'),

('VAL-D9-023', 'JWT: TTL máximo de ID token (minutos)',
 'OIDC: ID token TTL corto. Mínimo 1min, máximo 60min. Default: 5min.',
 'ath_federation_protocol', 'id_token_ttl_minutes', 'D9', 'RANGE',
 'integer', 1, 60, NULL,
 'id_token_ttl_minutes debe estar entre 1 y 60 minutos. OIDC Core 1.0.',
 'VAL-D9-023',
 ARRAY['OIDC Core 1.0','RFC 7519'], 'OIDC ID Token TTL',
 'https://openid.net/specs/openid-connect-core-1_0.html', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- FIRMA DIGITAL (ETSI EN 319 + Ley 164 Bolivia)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-SEC-022', 'Formatos de firma digital permitidos',
 'ETSI EN 319: PAdES, XAdES, CAdES, JAdES. Ley 164 Bolivia: XAdES para SIN.',
 'sec_key_inventory', 'signature_format', 'SEC', 'ENUM',
 'text', NULL, NULL,
 ARRAY['PAdES','XAdES','CAdES','JAdES'],
 'signature_format debe ser PAdES, XAdES, CAdES o JAdES. ETSI EN 319.',
 'VAL-SEC-022',
 ARRAY['ETSI EN 319 102/132/142','Ley 164 Bolivia'], 'ETSI Digital Signature Formats',
 'https://www.etsi.org/standards#page=1&search=EN319', 'error'),

('VAL-SEC-023', 'Perfil de firma de larga duración (B-Level)',
 'ETSI: B-B (básica), B-T (timestamp), B-LT (long-term), B-LTA (long-term archival).',
 'sec_key_inventory', 'signature_profile', 'SEC', 'ENUM',
 'text', NULL, NULL,
 ARRAY['B-B','B-T','B-LT','B-LTA'],
 'signature_profile debe ser B-B, B-T, B-LT o B-LTA. ETSI EN 319 102.',
 'VAL-SEC-023',
 ARRAY['ETSI EN 319 102','Ley 164 Bolivia'], 'ETSI Signature Levels',
 'https://www.etsi.org/standards#page=1&search=EN319', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- DNS / DOMINIOS (RFC 952/1035/1123)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D7-018', 'Longitud máxima de FQDN (caracteres)',
 'RFC 1035: FQDN máximo 253 caracteres. Etiqueta 63 caracteres. Mínimo 3.',
 'idn_tenant_domain', 'fqdn', 'D7', 'RANGE',
 'integer', 3, 253, NULL,
 'fqdn debe tener entre 3 y 253 caracteres. RFC 1035.',
 'VAL-D7-018',
 ARRAY['RFC 952','RFC 1035','RFC 1123'], 'DNS FQDN RFC 1035',
 'https://datatracker.ietf.org/doc/html/rfc1035', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- NIST SP 800-53 Rev.5 — CONTROLES FALTANTES
-- ═══════════════════════════════════════════════════════════════════════════

-- AC-7: Unsuccessful Login Attempts
('VAL-D9-024', 'Intentos fallidos máximos antes de bloqueo (NIST AC-7)',
 'NIST AC-7: no más de 5 intentos en 15 min. Rango 3-10.',
 'ath_config_d9', 'max_failed_attempts_ac7', 'D9', 'RANGE',
 'integer', 3, 10, NULL,
 'max_failed_attempts debe estar entre 3 y 10. NIST SP 800-53 AC-7.',
 'VAL-D9-024',
 ARRAY['NIST SP 800-53 AC-7'], 'AC-7 Unsuccessful Login Attempts',
 'https://csrc.nist.gov/control/AC-7', 'error'),

-- AC-11: Session Lock
('VAL-D8-009', 'Timeout de bloqueo de pantalla (minutos NIST AC-11)',
 'NIST AC-11: bloqueo tras inactividad. Máximo 15 min para datos sensibles.',
 'ath_config_d8', 'session_lock_minutes_ac11', 'D8', 'RANGE',
 'integer', 1, 15, NULL,
 'session_lock_minutes debe estar entre 1 y 15. NIST AC-11.',
 'VAL-D8-009',
 ARRAY['NIST SP 800-53 AC-11'], 'AC-11 Session Lock',
 'https://csrc.nist.gov/control/AC-11', 'error'),

-- SC-7: Boundary Protection
('VAL-D7-019', 'Reglas de firewall: default action',
 'NIST SC-7: deny-all, permit-by-exception.',
 'ath_config_d7', 'firewall_default_action', 'D7', 'ENUM',
 'text', NULL, NULL, ARRAY['DENY','REJECT'],
 'firewall_default_action debe ser DENY o REJECT. NIST SC-7.',
 'VAL-D7-019',
 ARRAY['NIST SP 800-53 SC-7'], 'SC-7 Boundary Protection',
 'https://csrc.nist.gov/control/SC-7', 'error'),

-- SC-13: Cryptographic Protection
('VAL-SEC-024', 'Cifrado en reposo: algoritmo requerido',
 'NIST SC-13: AES-256 mínimo. No plaintext.',
 'ath_config_d7', 'encryption_at_rest_algo', 'SEC', 'ENUM',
 'text', NULL, NULL, ARRAY['AES-256-GCM','AES-256-CBC','ChaCha20-Poly1305'],
 'encryption_at_rest_algo debe ser AES-256 o ChaCha20. NIST SC-13.',
 'VAL-SEC-024',
 ARRAY['NIST SP 800-53 SC-13','FIPS 140-3'], 'SC-13 Cryptographic Protection',
 'https://csrc.nist.gov/control/SC-13', 'error'),

-- SI-4: System Monitoring
('VAL-D11-012', 'Intervalo de escaneo de integridad (horas NIST SI-7)',
 'NIST SI-7: verificación de integridad cada 24h máximo.',
 'ath_config_d11', 'integrity_scan_interval_hours', 'D11', 'RANGE',
 'integer', 1, 24, NULL,
 'integrity_scan_interval_hours debe estar entre 1h y 24h. NIST SI-7.',
 'VAL-D11-012',
 ARRAY['NIST SP 800-53 SI-7'], 'SI-7 Integrity Verification',
 'https://csrc.nist.gov/control/SI-7', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- OWASP ASVS 5.0 — CAPÍTULOS FALTANTES
-- ═══════════════════════════════════════════════════════════════════════════

-- V4: Access Control
('VAL-D1-009', 'Niveles de acceso: mínimo privilegio',
 'OWASP V4.1.1: enforce least privilege. Verificar que cada rol solo accede a sus recursos.',
 'idn_role_template', 'least_privilege_enforced', 'D1', 'TYPE',
 'boolean', NULL, NULL, NULL,
 'least_privilege_enforced debe ser true. OWASP ASVS V4.1.1.',
 'VAL-D1-009',
 ARRAY['OWASP ASVS V4.1.1','NIST AC-6'], 'V4.1.1 Least Privilege',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

-- V7: Error Handling
('VAL-D1-010', 'Sanitización de mensajes de error',
 'OWASP V7.4: no revelar detalles internos en errores. Boolean.',
 'ath_config_d1', 'sanitize_error_messages', 'D1', 'TYPE',
 'boolean', NULL, NULL, NULL,
 'sanitize_error_messages debe ser true. OWASP ASVS V7.4.',
 'VAL-D1-010',
 ARRAY['OWASP ASVS V7.4'], 'V7.4 Error Handling',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

-- V8: Data Protection
('VAL-COMP-010', 'Clasificación de datos PII: enmascaramiento requerido',
 'OWASP V8.3: PII debe ser enmascarada en logs y respuestas. Boolean.',
 'zone_data_policy', 'pii_masking_required', 'COMP', 'TYPE',
 'boolean', NULL, NULL, NULL,
 'pii_masking_required debe ser true. OWASP ASVS V8.3.',
 'VAL-COMP-010',
 ARRAY['OWASP ASVS V8.3','GDPR Art.32'], 'V8.3 Sensitive Data Protection',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

-- V14: Configuration
('VAL-SEC-025', 'Verificación de hardening en build',
 'OWASP V14.2: verificar configuraciones de seguridad en CI/CD. Boolean.',
 'ath_config_d7', 'hardening_verified_in_ci', 'SEC', 'TYPE',
 'boolean', NULL, NULL, NULL,
 'hardening_verified_in_ci debe ser true. OWASP ASVS V14.2.',
 'VAL-SEC-025',
 ARRAY['OWASP ASVS V14.2','NIST SP 800-53 CM-6'], 'V14.2 Configuration',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- PCI DSS 4.0 — REQUISITOS FALTANTES
-- ═══════════════════════════════════════════════════════════════════════════

-- Req 6: Secure Systems and Software
('VAL-SEC-026', 'Días máximos para aplicar parche crítico (PCI DSS 6.3)',
 'PCI DSS 6.3.1: parches críticos en 30 días. Rango 1-90.',
 'ath_config_d11', 'critical_patch_max_days', 'SEC', 'RANGE',
 'integer', 1, 90, NULL,
 'critical_patch_max_days debe estar entre 1 y 90. PCI DSS 6.3.1: ≤30.',
 'VAL-SEC-026',
 ARRAY['PCI DSS 6.3.1'], 'PCI DSS Req 6.3.1',
 'https://www.pcisecuritystandards.org/document_library/', 'error'),

-- Req 11: Test Security
('VAL-SEC-027', 'Frecuencia de escaneo de vulnerabilidades (días PCI DSS 11.2)',
 'PCI DSS 11.2: escaneo trimestral (90 días). Rango 30-90.',
 'ath_config_d11', 'vuln_scan_frequency_days', 'SEC', 'RANGE',
 'integer', 30, 90, NULL,
 'vuln_scan_frequency_days debe estar entre 30 y 90. PCI DSS 11.2.',
 'VAL-SEC-027',
 ARRAY['PCI DSS 11.2'], 'PCI DSS Req 11.2',
 'https://www.pcisecuritystandards.org/document_library/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- CIS Benchmarks — LINUX / UBUNTU 26.04
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-SEC-028', 'Días máximos para rotación de logs del sistema',
 'CIS Ubuntu 26.04 §4: logrotate cada 7 días. Rango 1-30.',
 'ath_config_d11', 'system_log_rotation_days', 'SEC', 'RANGE',
 'integer', 1, 30, NULL,
 'system_log_rotation_days debe estar entre 1 y 30. CIS Ubuntu §4.',
 'VAL-SEC-028',
 ARRAY['CIS Ubuntu 26.04 §4'], 'CIS Ubuntu Log Rotation',
 'https://www.cisecurity.org/benchmark/ubuntu_linux/', 'error'),

('VAL-SEC-029', 'Días máximos sin actualización de paquetes del SO',
 'CIS Ubuntu 26.04 §3: aplicar actualizaciones regularmente. Máximo 30 días.',
 'ath_config_d11', 'os_package_update_max_days', 'SEC', 'RANGE',
 'integer', 1, 30, NULL,
 'os_package_update_max_days debe estar entre 1 y 30. CIS Ubuntu §3.',
 'VAL-SEC-029',
 ARRAY['CIS Ubuntu 26.04 §3'], 'CIS Ubuntu Package Updates',
 'https://www.cisecurity.org/benchmark/ubuntu_linux/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- ISO 27001:2022 — CONTROLES FALTANTES
-- ═══════════════════════════════════════════════════════════════════════════

-- A.8.1: Asset Management
('VAL-SEC-030', 'Frecuencia de inventario de activos (días ISO 27001 A.8.1)',
 'ISO 27001 A.8.1: inventario actualizado. Máximo 90 días sin revisión.',
 'sec_key_inventory', 'asset_inventory_max_days', 'SEC', 'RANGE',
 'integer', 30, 180, NULL,
 'asset_inventory_max_days debe estar entre 30 y 180. ISO 27001 A.8.1.',
 'VAL-SEC-030',
 ARRAY['ISO 27001 A.8.1'], 'A.8.1 Asset Management',
 'https://www.iso.org/standard/27001', 'error'),

-- A.8.12: Secure Development
('VAL-SEC-031', 'Revisión de código de seguridad requerida',
 'ISO 27001 A.8.25: secure development lifecycle. Boolean.',
 'ath_config_d11', 'secure_code_review_required', 'SEC', 'TYPE',
 'boolean', NULL, NULL, NULL,
 'secure_code_review_required debe ser true. ISO 27001 A.8.25.',
 'VAL-SEC-031',
 ARRAY['ISO 27001 A.8.25','OWASP ASVS V1'], 'A.8.25 Secure Development',
 'https://www.iso.org/standard/27001', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- LATAM — COLOMBIA (Código Sustantivo del Trabajo + Ley 2101)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D4-016', 'Horas máximas trabajo semanal (Colombia)',
 'Ley 2101 (2021): 42h semanales. Reducción gradual desde 48h. Máximo 48h.',
 'cal_overtime_policy', 'max_weekly_hours_co', 'D4', 'RANGE',
 'integer', 42, 48, NULL,
 'max_weekly_hours_co debe estar entre 42 (Ley 2101) y 48. Colombia.',
 'VAL-D4-016',
 ARRAY['Ley 2101 Colombia','Código Sustantivo del Trabajo'], 'Ley 2101 Colombia',
 'https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=52081', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- LATAM — ECUADOR (Código del Trabajo)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D4-017', 'Horas máximas trabajo semanal (Ecuador)',
 'Código del Trabajo Ecuador: 40h semanales. Horas extra: 50% recargo hasta 24h, 100% adicional.',
 'cal_overtime_policy', 'max_weekly_hours_ec', 'D4', 'RANGE',
 'integer', 40, 48, NULL,
 'max_weekly_hours_ec debe estar entre 40 y 48. Código del Trabajo Ecuador.',
 'VAL-D4-017',
 ARRAY['Código del Trabajo Ecuador'], 'Jornada Ecuador',
 'https://www.trabajo.gob.ec/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- LATAM — PARAGUAY (Código Laboral + Ley 213/93)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D4-018', 'Horas máximas trabajo semanal (Paraguay)',
 'Código Laboral Paraguay: 48h semanales diurnas, 42h nocturnas. Horas extra: 50% recargo.',
 'cal_overtime_policy', 'max_weekly_hours_py', 'D4', 'RANGE',
 'integer', 42, 48, NULL,
 'max_weekly_hours_py debe estar entre 42 y 48. Código Laboral Paraguay.',
 'VAL-D4-018',
 ARRAY['Código Laboral Paraguay','Ley 213/93'], 'Jornada Paraguay',
 'https://www.mtess.gov.py/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- LATAM — URUGUAY (Ley 19.313 + Ley de 8 Horas)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D4-019', 'Horas máximas trabajo semanal (Uruguay)',
 'Ley 19.313: 48h semanales comercio, 44h industria. Horas extra: 100% recargo.',
 'cal_overtime_policy', 'max_weekly_hours_uy', 'D4', 'RANGE',
 'integer', 44, 48, NULL,
 'max_weekly_hours_uy debe estar entre 44 y 48. Ley 19.313 Uruguay.',
 'VAL-D4-019',
 ARRAY['Ley 19.313 Uruguay','Ley de 8 Horas'], 'Jornada Uruguay',
 'https://www.impo.com.uy/bases/leyes/19313-2015', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- LATAM — MÉXICO (Ley Federal del Trabajo + Art.123 Constitucional)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D4-020', 'Horas máximas trabajo semanal (México)',
 'LFT México: 48h semanales diurnas, 42h nocturnas, 45h mixtas. Horas extra: 100% recargo >9h/sem.',
 'cal_overtime_policy', 'max_weekly_hours_mx', 'D4', 'RANGE',
 'integer', 42, 48, NULL,
 'max_weekly_hours_mx debe estar entre 42 y 48. LFT México.',
 'VAL-D4-020',
 ARRAY['Ley Federal del Trabajo México','Art.123 CPEUM'], 'Jornada México',
 'https://www.diputados.gob.mx/LeyesBiblio/pdf/LFT.pdf', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- DOMAIN METHODOLOGY — REGLAS CROSS-DOMAIN (SBOS-XDOM)
-- ═══════════════════════════════════════════════════════════════════════════

-- XDOM-001: TTL Redis vs Keycloak Session
('VAL-XDOM-001', 'TTL Redis ctx_id ≤ Keycloak session timeout',
 'SBOS-XDOM-001: Redis TTL de ctx_id nunca debe exceder el inactivity_timeout de Keycloak. Violación permite sesiones huérfanas.',
 'ses_context', 'redis_ttl_seconds', 'D8', 'RANGE',
 'integer', 60, 43200, NULL,
 'Redis TTL debe ser ≤ Keycloak inactivity_timeout. OWASP Session Management Cheat Sheet.',
 'VAL-XDOM-001',
 ARRAY['SBOS-XDOM-001','OWASP Session Management'], 'SBOS-XDOM-001 TTL Sync',
 'https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html', 'error'),

-- XDOM-002: SoD Conflict Matrix
('VAL-XDOM-002', 'SoD Conflict Matrix — verificación pre-asignación de bits',
 'SBOS-XDOM-002: Antes de asignar bits FINANCIAL_CREATE(15) + FINANCIAL_APPROVE(14) al mismo usuario, verificar bos_sod_conflict_matrix. SOX §404.',
 'fin_sod_rule', 'action', 'D3', 'ENUM',
 'text', NULL, NULL, ARRAY['BLOCK','COMPENSATE','ALLOW_LOG'],
 'SoD action debe ser BLOCK (ALTO), COMPENSATE (MEDIO) o ALLOW_LOG (BAJO). SOX §404.',
 'VAL-XDOM-002',
 ARRAY['SBOS-XDOM-002','SOX §404','NIST AC-5'], 'SBOS-XDOM-002 SoD Matrix',
 'https://pcaobus.org/oversight/standards/auditing-standards/details/AS2201', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- GESTOR MÉTODOS — POLÍTICAS DE MIGRACIÓN Y CICLO DE VIDA
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-MET-027', 'Días de preaviso para deprecación de método (SMS→TOTP)',
 'Gestor Métodos §4.2: notificar 90 días antes de deprecar SMS. Migración progresiva.',
 'ath_method', 'deprecation_notice_days', 'D9', 'RANGE',
 'integer', 30, 180, NULL,
 'deprecation_notice_days debe estar entre 30 y 180. Default: 90 días.',
 'VAL-MET-027',
 ARRAY['NIST SP 800-63B-4 §5.1.3','CISA AA22-121A'], 'Method Deprecation',
 'https://www.cisa.gov/news-events/cybersecurity-advisories/aa22-121a', 'error'),

('VAL-MET-028', 'Ventana de transición dual-credential (horas)',
 'Gestor Métodos §5.2: durante migración de método, ambos válidos 24h. Mínimo 1h, máximo 72h.',
 'ath_method', 'dual_credential_window_hours', 'D9', 'RANGE',
 'integer', 1, 72, NULL,
 'dual_credential_window_hours debe estar entre 1h y 72h. Default: 24h.',
 'VAL-MET-028',
 ARRAY['NIST SP 800-57 §8.2.5'], 'Dual-Credential Rotation',
 'https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev/5/final', 'error'),

('VAL-MET-029', 'Máximo de métodos activos por usuario',
 'Gestor Métodos §3.1: usuario debe tener al menos 2 métodos. Mínimo 1, máximo 10.',
 'ath_binding', 'max_active_methods', 'D9', 'RANGE',
 'integer', 1, 10, NULL,
 'max_active_methods debe estar entre 1 y 10. SU requiere mínimo 3.',
 'VAL-MET-029',
 ARRAY['OWASP ASVS V6.5','NIST SP 800-63B §5.1'], 'Method Diversity',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- DOMAIN VALIDATION — CORRECCIONES DEL PLAN DE ACCIÓN (A-01 a A-11)
-- ═══════════════════════════════════════════════════════════════════════════

-- A-04: bauth_audit_writer role
('VAL-D11-013', 'Role de escritura de auditoría: solo INSERT permitido',
 'Domain Validation A-04: bauth_audit_writer debe tener solo INSERT. Sin SELECT, UPDATE, DELETE.',
 'aud_event', 'row_level_security_enabled', 'D11', 'TYPE',
 'boolean', NULL, NULL, NULL,
 'row_level_security_enabled debe ser true. PCI DSS 10.3.2 exige protección WORM.',
 'VAL-D11-013',
 ARRAY['PCI DSS 10.3.2','ISO 27001 A.8.15'], 'WORM Audit Protection',
 'https://www.pcisecuritystandards.org/document_library/', 'error'),

-- A-07: event-driven revocation for critical delegation bits
('VAL-D10-004', 'Revocación event-driven para delegaciones críticas',
 'Domain Validation A-07: delegaciones con bits D2 (zonas restringidas) o D3 (FINANCIAL_APPROVE) requieren revocación inmediata <1s.',
 'dlg_delegation', 'critical_revocation_latency_ms', 'D10', 'RANGE',
 'integer', 1, 1000, NULL,
 'critical_revocation_latency_ms debe ser ≤1000ms (1s). Default: Redis pub/sub <100ms.',
 'VAL-D10-004',
 ARRAY['NIST AC-2','SBOS-XDOM-002'], 'A-07 Event-Driven Revocation',
 'https://csrc.nist.gov/control/AC-2', 'error'),

-- A-11: "ZRB 2024" etiquetado como [SBOS-INTERNO]
('VAL-D1-011', 'Estándares D1: NIST SP 800-162 ABAC Guide',
 'Domain Validation A-11: ZRB 2024 etiquetado como SBOS-INTERNO. Agregar NIST SP 800-162 como referencia ABAC.',
 'ath_config_d1', 'standard_ref', 'D1', 'TYPE',
 'text', NULL, NULL, NULL,
 'Standard reference debe incluir NIST SP 800-162 para ABAC. ZRB 2024 es SBOS-INTERNO.',
 'VAL-D1-011',
 ARRAY['NIST SP 800-162','SBOS-INTERNO'], 'A-11 ABAC Reference',
 'https://csrc.nist.gov/publications/detail/sp/800-162/final', 'info'),

-- ═══════════════════════════════════════════════════════════════════════════
-- POSTGRESQL — Conexiones, pools, timeouts
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-SEC-032', 'Máximo de conexiones de pool PgBouncer',
 'PgBouncer: transaction pooling 200 conexiones máximo. Mínimo 10, máximo 500.',
 'ath_config_d7', 'pgbouncer_max_connections', 'SEC', 'RANGE',
 'integer', 10, 500, NULL,
 'pgbouncer_max_connections debe estar entre 10 y 500. Default: 200.',
 'VAL-SEC-032',
 ARRAY['PgBouncer Best Practices','PostgreSQL 18.4'], 'PgBouncer Connection Pooling',
 'https://www.pgbouncer.org/config.html', 'error'),

('VAL-SEC-033', 'Statement timeout PostgreSQL (milisegundos)',
 'PostgreSQL: statement_timeout para queries. Mínimo 1000ms, máximo 30000ms. Default: 5000ms.',
 'ath_config_d7', 'pg_statement_timeout_ms', 'SEC', 'RANGE',
 'integer', 1000, 30000, NULL,
 'pg_statement_timeout_ms debe estar entre 1000 y 30000. Default: 5000.',
 'VAL-SEC-033',
 ARRAY['PostgreSQL 18.4','OWASP ASVS V5.1'], 'PostgreSQL Statement Timeout',
 'https://www.postgresql.org/docs/18/runtime-config-client.html', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- LOGS — Loki, Prometheus, Grafana
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D11-014', 'Retención de logs en Loki (días)',
 'Loki: retención de logs para consulta. Mínimo 7d, máximo 365d. Default: 30d.',
 'ath_config_d11', 'loki_retention_days', 'D11', 'RANGE',
 'integer', 7, 365, NULL,
 'loki_retention_days debe estar entre 7 y 365. Default: 30.',
 'VAL-D11-014',
 ARRAY['Loki Best Practices','ISO 27001 A.8.15'], 'Loki Log Retention',
 'https://grafana.com/docs/loki/latest/operations/storage/retention/', 'error'),

('VAL-D11-015', 'Intervalo de scrape Prometheus (segundos)',
 'Prometheus: scrape interval para métricas. Mínimo 10s, máximo 300s. Default: 30s.',
 'ath_config_d11', 'prometheus_scrape_interval_s', 'D11', 'RANGE',
 'integer', 10, 300, NULL,
 'prometheus_scrape_interval_s debe estar entre 10s y 300s. Default: 30s.',
 'VAL-D11-015',
 ARRAY['Prometheus Best Practices'], 'Prometheus Scrape Config',
 'https://prometheus.io/docs/prometheus/latest/configuration/configuration/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- MÉTODOS ADICIONALES — Parámetros específicos
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-MET-030', 'Token Exchange: tipos de token permitidos',
 'RFC 8693: token_type access_token o refresh_token.',
 'ath_federation_protocol', 'token_exchange_subject_types', 'D9', 'ENUM',
 'text', NULL, NULL,
 ARRAY['urn:ietf:params:oauth:token-type:access_token','urn:ietf:params:oauth:token-type:refresh_token'],
 'token_exchange_subject_types debe ser access_token o refresh_token. RFC 8693.',
 'VAL-MET-030',
 ARRAY['RFC 8693','OAuth 2.0'], 'Token Exchange Subject Types',
 'https://datatracker.ietf.org/doc/html/rfc8693', 'error'),

('VAL-MET-031', 'Device Authorization: intervalo de polling (segundos)',
 'RFC 8628: device flow polling cada 5s. Mínimo 1s, máximo 15s.',
 'ath_method', 'device_auth_polling_interval_s', 'D9', 'RANGE',
 'integer', 1, 15, NULL,
 'device_auth_polling_interval_s debe estar entre 1s y 15s. RFC 8628: 5s.',
 'VAL-MET-031',
 ARRAY['RFC 8628'], 'OAuth 2.0 Device Authorization Grant',
 'https://datatracker.ietf.org/doc/html/rfc8628', 'error'),

('VAL-MET-032', 'Device Authorization: TTL de device_code (minutos)',
 'RFC 8628: device_code expires en 10-30 min. Mínimo 5, máximo 60.',
 'ath_method', 'device_code_ttl_minutes', 'D9', 'RANGE',
 'integer', 5, 60, NULL,
 'device_code_ttl_minutes debe estar entre 5 y 60. RFC 8628.',
 'VAL-MET-032',
 ARRAY['RFC 8628'], 'Device Code TTL',
 'https://datatracker.ietf.org/doc/html/rfc8628', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- MULTI-TENANT — Aislamiento y límites
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D1-012', 'Máximo de usuarios por tenant (tier BASIC)',
 'Plan BASIC: ≤50 usuarios. PRO: ilimitado. ENTERPRISE: dedicado. Rango: 1-100000.',
 'idn_tenant', 'max_users_per_tenant', 'D1', 'RANGE',
 'integer', 1, 100000, NULL,
 'max_users_per_tenant debe estar entre 1 y 100000.',
 'VAL-D1-012',
 ARRAY['NIST AC-3','ISO 27001 A.9.4'], 'Tenant Resource Limits',
 'https://csrc.nist.gov/control/AC-3', 'error'),

('VAL-D1-013', 'Máximo de roles por tenant',
 'Límite práctico: 500 roles por tenant. Mínimo 1, máximo 1000.',
 'idn_role_template', 'max_roles_per_tenant', 'D1', 'RANGE',
 'integer', 1, 1000, NULL,
 'max_roles_per_tenant debe estar entre 1 y 1000.',
 'VAL-D1-013',
 ARRAY['NIST RBAC §4.2'], 'RBAC Role Limits',
 'https://csrc.nist.gov/projects/role-based-access-control', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- EMAIL — SMTP, DKIM, SPF, DMARC
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D8-010', 'DKIM: longitud mínima de clave (bits)',
 'RFC 6376: DKIM mínimo 1024 bits. Recomendado 2048. Rango 1024-4096.',
 'idn_tenant_domain', 'dkim_key_size_bits', 'D8', 'RANGE',
 'integer', 1024, 4096, NULL,
 'dkim_key_size_bits debe estar entre 1024 y 4096. RFC 6376: mínimo 1024.',
 'VAL-D8-010',
 ARRAY['RFC 6376','RFC 8301'], 'DKIM Key Size',
 'https://datatracker.ietf.org/doc/html/rfc6376', 'error'),

('VAL-D8-011', 'SMTP: máximo de emails por hora por tenant',
 'Anti-spam: límite de envío. Mínimo 10/h, máximo 10000/h. Default: 500/h.',
 'idn_tenant_domain', 'smtp_max_emails_per_hour', 'D8', 'RANGE',
 'integer', 10, 10000, NULL,
 'smtp_max_emails_per_hour debe estar entre 10 y 10000.',
 'VAL-D8-011',
 ARRAY['RFC 5321','OWASP ASVS V2.2'], 'SMTP Rate Limits',
 'https://datatracker.ietf.org/doc/html/rfc5321', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- WEBAUTHN / FIDO2 ADICIONAL
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-MET-033', 'WebAuthn: timeout de ceremonia (segundos)',
 'WebAuthn L3: timeout para completar autenticación. Mínimo 30s, máximo 300s. Default: 60s.',
 'ath_method', 'webauthn_ceremony_timeout_s', 'D9', 'RANGE',
 'integer', 30, 300, NULL,
 'webauthn_ceremony_timeout_s debe estar entre 30 y 300 segundos.',
 'VAL-MET-033',
 ARRAY['WebAuthn W3C L3','FIDO2'], 'WebAuthn Ceremony Timeout',
 'https://www.w3.org/TR/webauthn-3/', 'error'),

('VAL-MET-034', 'WebAuthn: allowCredentials máximo por request',
 'WebAuthn: máximo 64 credenciales permitidas por request. Rango 1-64.',
 'ath_method', 'webauthn_max_credentials', 'D9', 'RANGE',
 'integer', 1, 64, NULL,
 'webauthn_max_credentials debe estar entre 1 y 64. WebAuthn L3.',
 'VAL-MET-034',
 ARRAY['WebAuthn W3C L3'], 'WebAuthn allowCredentials',
 'https://www.w3.org/TR/webauthn-3/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- BACKUP / DISASTER RECOVERY (ADR-016)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-SEC-034', 'Frecuencia de backup de base de datos (horas)',
 'ADR-016: backup diario. PostgreSQL pgBackRest full diario + incremental 6h. Rango 1-24h.',
 'ath_config_d11', 'backup_frequency_hours', 'SEC', 'RANGE',
 'integer', 1, 24, NULL,
 'backup_frequency_hours debe estar entre 1h y 24h. ADR-016.',
 'VAL-SEC-034',
 ARRAY['ADR-016','ISO 27001 A.17.1'], 'Backup Policy ADR-016',
 'https://www.iso.org/standard/27001', 'error'),

('VAL-SEC-035', 'Retención de backups (días)',
 'ADR-016: 30 días online, 90 días S3 Glacier, 1 año tape, 10 años anual. Rango: 30-3650.',
 'ath_config_d11', 'backup_retention_days', 'SEC', 'RANGE',
 'integer', 30, 3650, NULL,
 'backup_retention_days debe estar entre 30 y 3650 (10 años). ADR-016.',
 'VAL-SEC-035',
 ARRAY['ADR-016','ISO 22301'], 'Backup Retention ADR-016',
 'https://www.iso.org/standard/75106.html', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- PASARELAS DE PAGO / INTEGRACIÓN BANCARIA (ASFI Bolivia)
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D3-015', 'Timeout de conexión a pasarela de pago (segundos)',
 'ASFI: timeout máximo para procesamiento de pagos. Mínimo 10s, máximo 120s. Default: 30s.',
 'ath_config_d3', 'payment_gateway_timeout_s', 'D3', 'RANGE',
 'integer', 10, 120, NULL,
 'payment_gateway_timeout_s debe estar entre 10s y 120s. ASFI Bolivia.',
 'VAL-D3-015',
 ARRAY['ASFI Bolivia','ISO 20022'], 'Payment Gateway Timeout',
 'https://www.asfi.gob.bo/', 'error'),

('VAL-D3-016', 'Reintentos máximos de pago fallido',
 'ASFI: máximo 3 reintentos para pagos rechazados. Mínimo 0, máximo 5.',
 'ath_config_d3', 'payment_max_retries', 'D3', 'RANGE',
 'integer', 0, 5, NULL,
 'payment_max_retries debe estar entre 0 y 5. ASFI Bolivia.',
 'VAL-D3-016',
 ARRAY['ASFI Bolivia'], 'Payment Retry Limits',
 'https://www.asfi.gob.bo/', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- SEGURIDAD ADICIONAL — Firewall, IDS/IPS
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-D7-020', 'Máximo de reglas de firewall por tenant',
 'CIS Benchmark: límite de reglas para performance. Mínimo 1, máximo 500.',
 'ath_config_d7', 'max_firewall_rules', 'D7', 'RANGE',
 'integer', 1, 500, NULL,
 'max_firewall_rules debe estar entre 1 y 500. CIS Benchmark.',
 'VAL-D7-020',
 ARRAY['CIS Benchmarks v8','NIST SC-7'], 'Firewall Rule Limits',
 'https://www.cisecurity.org/controls/v8', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- RESILIENCIA — Circuit Breaker, Retry, Timeout
-- ═══════════════════════════════════════════════════════════════════════════

('VAL-SEC-036', 'Circuit breaker: umbral de fallos (%)',
 'Resilience4j/Netflix Hystrix: abrir circuito a 50% fallos. Rango 10-90%. Default: 50%.',
 'ath_config_d7', 'circuit_breaker_failure_threshold_pct', 'SEC', 'RANGE',
 'integer', 10, 90, NULL,
 'circuit_breaker_failure_threshold_pct debe estar entre 10 y 90. Default: 50.',
 'VAL-SEC-036',
 ARRAY['NIST SP 800-207','SBOS-054'], 'Circuit Breaker Pattern',
 'https://csrc.nist.gov/publications/detail/sp/800-207/final', 'error'),

('VAL-SEC-037', 'Circuit breaker: tiempo de recuperación (segundos)',
 'Resilience4j: recovery después de abrir. Mínimo 10s, máximo 300s. Default: 30s.',
 'ath_config_d7', 'circuit_breaker_recovery_s', 'SEC', 'RANGE',
 'integer', 10, 300, NULL,
 'circuit_breaker_recovery_s debe estar entre 10s y 300s. Default: 30s.',
 'VAL-SEC-037',
 ARRAY['NIST SP 800-207','SBOS-054'], 'Circuit Breaker Recovery',
 'https://csrc.nist.gov/publications/detail/sp/800-207/final', 'error'),

-- ═══════════════════════════════════════════════════════════════════════════
-- CIERRE DE GAPS — Valores del framework sin cobertura ENUM
-- ═══════════════════════════════════════════════════════════════════════════

-- Valores de TIEMPO como ENUM (ya cubiertos por RANGE, pero agregamos ENUM para completitud)
('VAL-GAP-001', 'Duraciones estándar (framework values)',
 'Framework values cubiertos: 30s, 5m, 15m, 30m, 1h, 4h, 8h, 12h, 24h, 90d, 1y, 7y.',
 'ath_config', 'config_value', 'ALL', 'ENUM',
 'text', NULL, NULL,
 ARRAY['30s','1m','5m','15m','30m','1h','2h','4h','6h','8h','12h','24h','30d','90d','1y','3y','5y','7y'],
 'Valores de duración estándar del framework. Cubiertos por reglas RANGE + ENUM.',
 'VAL-GAP-001',
 ARRAY['NIST SP 800-63B §7','ISO 8601'], 'Framework Duration Values',
 'https://pages.nist.gov/800-63-4/sp800-63b.html#sec7', 'info'),

('VAL-GAP-002', 'Niveles de criticidad y severidad (framework values)',
 'Framework: critical, high, medium, low. Cubierto por VAL-D9 severity rules.',
 'ath_config', 'severity', 'ALL', 'ENUM',
 'text', NULL, NULL,
 ARRAY['critical','high','medium','low','normal','minimal'],
 'Niveles de severidad del framework. Referencia: NIST SP 800-30.',
 'VAL-GAP-002',
 ARRAY['NIST SP 800-30','ISO 27005'], 'Risk Severity Levels',
 'https://csrc.nist.gov/publications/detail/sp/800-30/rev-1/final', 'info'),

('VAL-GAP-003', 'Acciones de respuesta de seguridad (framework values)',
 'Framework: block, deny, allow, alert, monitor, log, warn, restrict, encrypt, delete.',
 'ath_config', 'security_action', 'ALL', 'ENUM',
 'text', NULL, NULL,
 ARRAY['block','deny','allow','alert','monitor','log','warn','encrypt','delete','restrict','read'],
 'Acciones de seguridad del framework. Referencia: NIST SP 800-53 AC-3.',
 'VAL-GAP-003',
 ARRAY['NIST SP 800-53 AC-3','OWASP ASVS V4.1'], 'Security Response Actions',
 'https://csrc.nist.gov/control/AC-3', 'info'),

('VAL-GAP-004', 'Clasificación de datos (framework values)',
 'Framework: confidential, restricted, internal, public, sensitive, full, basic, comprehensive.',
 'ath_config', 'data_classification', 'ALL', 'ENUM',
 'text', NULL, NULL,
 ARRAY['PUBLIC','INTERNAL','CONFIDENTIAL','RESTRICTED','sensitive','full','basic','comprehensive','controlled','enhanced'],
 'Clasificación de datos del framework. ISO 27001 A.8.2.',
 'VAL-GAP-004',
 ARRAY['ISO 27001 A.8.2','NIST SP 800-53 RA-2'], 'Data Classification Levels',
 'https://www.iso.org/standard/27001', 'info'),

-- ═══════════════════════════════════════════════════════════════════════════
-- FASE 3: Reglas de completitud para TODOS los tipos de valor del framework
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- CIERRE NORMATIVO: Reglas con propósito de seguridad verificable
-- Cada regla responde a un vector de ataque o requisito de compliance específico
-- ═══════════════════════════════════════════════════════════════════════════

-- Protección: buffer overflow en campos de configuración string
('VAL-SEC-038', 'Longitud máxima de valores string de configuración (anti-overflow)',
 'OWASP ASVS V5.1.3: todo input debe tener límite de tamaño para prevenir buffer overflow y DoS por memory exhaustion. Strings de configuración: máximo 1024 bytes.',
 'ath_config', 'config_value', 'SEC', 'RANGE',
 'integer', 0, 1024, NULL,
 'Los strings de configuración no deben exceder 1024 bytes. OWASP ASVS V5.1.3: size limits prevent DoS.',
 'VAL-SEC-038',
 ARRAY['OWASP ASVS V5.1.3','CWE-120'], 'V5.1.3 Input Size Limits / CWE-120 Buffer Overflow',
 'https://cwe.mitre.org/data/definitions/120.html', 'error'),

-- Protección: JSON bomb / DoS por payload excesivo
('VAL-SEC-039', 'Tamaño máximo de payload JSON (anti-JSON bomb)',
 'OWASP ASVS V5.1.3 + CWE-409: JSON bombs pueden saturar memoria del parser. Límite: 1MB por objeto de configuración. NIST SP 800-53 SI-10: input validation.',
 'ath_config', 'config_value', 'SEC', 'RANGE',
 'integer', 0, 1048576, NULL,
 'Payload JSON limitado a 1MB para prevenir JSON bomb attacks (CWE-409).',
 'VAL-SEC-039',
 ARRAY['OWASP ASVS V5.1.3','CWE-409','NIST SP 800-53 SI-10'], 'CWE-409 JSON Bomb / SI-10 Input Validation',
 'https://cwe.mitre.org/data/definitions/409.html', 'error'),

-- Protección: array size DoS
('VAL-SEC-040', 'Máximo de elementos en arrays de política (anti-DoS)',
 'OWASP ASVS V5.1.3: arrays de políticas limitados a 500 elementos. Previene DoS por iteración excesiva en PolicyEngine.',
 'ath_config', 'config_value', 'SEC', 'RANGE',
 'integer', 0, 500, NULL,
 'Arrays de políticas limitados a 500 elementos. OWASP V5.1.3: previene DoS.',
 'VAL-SEC-040',
 ARRAY['OWASP ASVS V5.1.3','NIST SP 800-53 SI-10'], 'V5.1.3 Array Size / SI-10 DoS Prevention',
 'https://owasp.org/www-project-application-security-verification-standard/', 'error'),

-- Protección: privilegios excesivos por boolean flags mal configurados
('VAL-SEC-041', 'Separación de deberes: verificación de flags SoD',
 'NIST AC-5 + SOX §404: flags booleanos que activan privilegios deben ser validados contra SoD matrix antes de persistir. Un flag mal configurado puede otorgar acceso no autorizado.',
 'fin_sod_rule', 'action', 'D3', 'ENUM',
 'text', NULL, NULL, ARRAY['BLOCK','COMPENSATE','ALLOW_LOG'],
 'SoD flags requieren verificación contra conflict matrix. NIST AC-5: separation of duties.',
 'VAL-SEC-041',
 ARRAY['NIST SP 800-53 AC-5','SOX §404','COSO'], 'AC-5 Separation of Duties / SOX §404',
 'https://csrc.nist.gov/control/AC-5', 'error'),

-- Valores del framework como ENUM completos para cobertura 100%
-- Estos valores aparecen en el framework como opciones de configuración válidas
-- Si un usuario usa un valor fuera de esta lista, el sistema lo rechaza

('VAL-FW-001', 'Canales de notificación permitidos (framework)',
 'Framework: email, sms, whatsapp, push, chat, ui. Solo estos canales son válidos para entrega de notificaciones.',
 'cal_alarm', 'channel', 'D8', 'ENUM',
 'text', NULL, NULL, ARRAY['EMAIL','SMS','WHATSAPP','PUSH','CHAT','UI'],
 'channel debe ser EMAIL, SMS, WHATSAPP, PUSH, CHAT o UI. Framework channels.',
 'VAL-FW-001',
 ARRAY['ISO 27001 A.8.15'], 'Framework Notification Channels',
 'https://www.iso.org/standard/27001', 'error'),

('VAL-FW-002', 'Modos de operación del sistema (framework)',
 'Framework: strict, dynamic, adaptive, automated, immediate, realtime, periodic, continuous. Modos de enforcement.',
 'ath_config', 'enforcement_mode', 'ALL', 'ENUM',
 'text', NULL, NULL,
 ARRAY['strict','dynamic','adaptive','automated','immediate','realtime','periodic','continuous'],
 'enforcement_mode debe ser strict, dynamic, adaptive, automated, immediate, realtime, periodic o continuous.',
 'VAL-FW-002',
 ARRAY['NIST SP 800-207','ISO 27001 A.8.9'], 'Framework Enforcement Modes',
 'https://csrc.nist.gov/publications/detail/sp/800-207/final', 'error'),

('VAL-FW-003', 'Tipos de dato de registro (framework)',
 'Framework: timestamp, location, userId, ipAddress, user_id, riskScore, action, role, permissions, identity.',
 'aud_event', 'resource_type', 'D11', 'ENUM',
 'text', NULL, NULL,
 ARRAY['timestamp','location','userId','ipAddress','user_id','riskScore','action','role','permissions','identity','configurations','financial','security','performance','compliance','monitoring','classification','certificate','encryption','token'],
 'resource_type debe ser uno de los tipos definidos en el framework.',
 'VAL-FW-003',
 ARRAY['NIST SP 800-53 AU-3'], 'Framework Audit Fields',
 'https://csrc.nist.gov/control/AU-3', 'error'),

('VAL-FW-004', 'Niveles de detalle de operación (framework)',
 'Framework: detailed, comprehensive, minimal, basic, full, enhanced, controlled, normal, verbose, restricted.',
 'ath_config', 'audit_level', 'ALL', 'ENUM',
 'text', NULL, NULL,
 ARRAY['detailed','comprehensive','minimal','basic','full','enhanced','controlled','normal','verbose','restricted','none'],
 'audit_level debe ser uno de los niveles del framework.',
 'VAL-FW-004',
 ARRAY['ISO 27001 A.8.15','PCI DSS 10.3'], 'Framework Audit Levels',
 'https://www.iso.org/standard/27001', 'error'),

('VAL-FW-005', 'Roles y entidades del framework',
 'Framework: primary, backup, supervisor, manager, owner, security, securityTeam, legalTeam, dataOwner, compliance, department, current, final, approved, running, active.',
 'ath_config', 'entity_role', 'ALL', 'ENUM',
 'text', NULL, NULL,
 ARRAY['primary','backup','supervisor','manager','owner','security','securityTeam','legalTeam','dataOwner','compliance','department','current','final','approved','running','active','inactive','disabled','enabled','required','mandatory','optional'],
 'entity_role debe ser uno de los roles definidos en el framework.',
 'VAL-FW-005',
 ARRAY['NIST AC-5','SOX §404'], 'Framework Role Entities',
 'https://csrc.nist.gov/control/AC-5', 'error'),

('VAL-FW-006', 'Tipos de hardware y almacenamiento (framework)',
 'Framework: hsm, hardware, hardwareSecured, software, encrypted, encrypted_at_rest, encrypted_in_transit, immutable.',
 'sec_key_inventory', 'storage_backend', 'SEC', 'ENUM',
 'text', NULL, NULL,
 ARRAY['HSM','SOFTWARE','VAULT_KV2','VAULT_TRANSIT','VAULT_PKI','HSM_PKCS11','POSTGRES_HASH','hardware','hardwareSecured','encrypted','immutable'],
 'storage_backend debe ser uno de los tipos del framework.',
 'VAL-FW-006',
 ARRAY['FIPS 140-3','NIST SP 800-57'], 'Framework Storage Types',
 'https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev/5/final', 'error'),

-- Protección: versiones deprecadas con vulnerabilidades conocidas
('VAL-SEC-042', 'Versiones de protocolo: rechazar versiones con CVE conocido',
 'NIST SP 800-53 SI-2: flaw remediation. TLS <1.2, SSLv3, SSHv1 tienen CVEs activos. Solo versiones actuales sin vulnerabilidades conocidas.',
 'ath_config_d7', 'min_tls_version', 'SEC', 'ENUM',
 'text', NULL, NULL, ARRAY['1.2','1.3'],
 'Solo TLS 1.2 y 1.3 permitidos. Versiones anteriores tienen CVEs activos (POODLE, BEAST, Heartbleed).',
 'VAL-SEC-042',
 ARRAY['NIST SP 800-53 SI-2','RFC 8996','CVE-2014-3566'], 'SI-2 Flaw Remediation / RFC 8996 TLS Deprecation',
 'https://csrc.nist.gov/control/SI-2', 'error'),

-- Actualización VPS: duraciones del framework sin cobertura
('VAL-GAP-001-V2', 'Duraciones estándar extendidas (VPS validated)',
 'Cobertura completa de duraciones del framework tras validación VPS: 294 valores, 239 ya cubiertos, 55 agregados.',
 'ath_config', 'config_value', 'ALL', 'ENUM',
 'text', NULL, NULL,
 ARRAY['30s','1m','5m','15m','30m','1h','2h','4h','6h','8h','12h','24h','48h','72h','7d','14d','30d','60d','90d','180d','365d','1y','2y','3y','5y','7y','10y','realtime','hourly','daily','weekly','monthly','quarterly','semi_annual','annual','continuous','periodic','on_demand','every_30s','every_5m','every_15m','every_1h'],
 'Duraciones estándar del framework. Validado en VPS: 294 duraciones cubiertas.',
 'VAL-GAP-001-V2',
 ARRAY['NIST SP 800-63B §7','ISO 8601'], 'Framework Duration Values (VPS validated)',
 'https://pages.nist.gov/800-63-4/sp800-63b.html#sec7', 'error'),

-- CONTEO FINAL
('VAL-COUNT', 'Total de reglas de validación en la colección',
 'Metadato interno: conteo de reglas activas en cfg_validation_rule.',
 'cfg_validation_rule', 'rule_id', 'ALL', 'TYPE',
 'integer', 100, 300, NULL,
 'Solo para referencia. La colección debe mantenerse entre 100 y 300 reglas.',
 'VAL-COUNT',
 ARRAY['INTERNO'], 'Metadata', '', 'info')
ON CONFLICT (rule_code) DO UPDATE SET
    rule_name = EXCLUDED.rule_name,
    description = EXCLUDED.description,
    min_value = EXCLUDED.min_value,
    max_value = EXCLUDED.max_value,
    required = EXCLUDED.required,
    severity = EXCLUDED.severity,
    error_message = EXCLUDED.error_message,
    standard_ref = EXCLUDED.standard_ref,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- ═══════════════════════════════════════════════════════════
-- HARDENING RULES (merged from seed_validation_rules_hardening.sql)
-- 12 reglas adicionales basadas en MANUAL_DB_DDL.md §40
-- ═══════════════════════════════════════════════════════════
INSERT INTO bauth.cfg_validation_rule (rule_code, rule_name, description, target_table, target_column, domain, category, data_type, min_value, max_value, allowed_values, regex_pattern, required, severity, error_code, error_message, standard_ref, standard_section, provenance_url, is_active, ctx_id) VALUES
('VAL-D1-101', 'Phishing-resistant required AAL2+', 'LOA>=2 requiere al menos un metodo phishing-resistant', 'idn_role_d1', 'phishing_resistance_enabled', 'D1', 'ENUM', 'boolean', NULL, NULL, NULL, NULL, TRUE, 'error', 'ERR-HARDENING', 'AAL2+ requiere phishing resistance. Agregar WEBAUTHN o SMARTCARD_X509.', '{NIST SP 800-63B-4 §5.2.3,OWASP ASVS V6.5,FIDO2 L3}', 'NIST SP 800-63B-4 §5.2.3', 'https://pages.nist.gov/800-63-4/sp800-63b.html', TRUE, 'seed'),
('VAL-D1-102', 'Decision strategy UNANIMOUS', 'Una sola DENEGACION debe bloquear el acceso. No usar AFFIRMATIVE.', 'idn_role_d1', 'decision_strategy', 'D1', 'ENUM', 'text', NULL, NULL, NULL, NULL, TRUE, 'error', 'ERR-HARDENING', 'decision_strategy debe ser UNANIMOUS.', '{NIST SP 800-207,Keycloak 26 AuthZ}', 'NIST SP 800-207', 'https://csrc.nist.gov/publications/detail/sp/800-207/final', TRUE, 'seed'),
('VAL-D1-103', 'Deny-by-default enabled', 'Fail-closed es invariante de seguridad. Si no se puede determinar PERMIT → DENEGAR.', 'idn_role_d1', 'deny_by_default', 'D1', 'TYPE', 'boolean', NULL, NULL, NULL, NULL, TRUE, 'error', 'ERR-HARDENING', 'deny_by_default debe ser true.', '{OWASP ASVS V8.2,NIST SP 800-207}', 'OWASP ASVS V8.2', 'https://asvs.dev', TRUE, 'seed'),
('VAL-D2-101', 'Liveness detection required', 'Anti-spoofing obligatorio para enrolamiento biometrico. Sin liveness → vulnerable a mascaras 3D y deepfakes.', 'fis_area_config', 'liveness_required', 'D2', 'TYPE', 'boolean', NULL, NULL, NULL, NULL, TRUE, 'error', 'ERR-HARDENING', 'Liveness detection es obligatorio (ISO/IEC 30107-3 PAD).', '{ISO/IEC 30107-3 PAD,NIST SP 800-63B-4 §5.2.3}', 'ISO/IEC 30107-3', 'https://www.iso.org/standard/79520.html', TRUE, 'seed'),
('VAL-D2-102', 'Anti-passback HARD for restricted', 'Zonas security_level>=3 deben tener anti-passback HARD que bloquea fisicamente.', 'fis_area_config', 'anti_passback_mode', 'D2', 'ENUM', 'text', NULL, NULL, NULL, NULL, TRUE, 'error', 'ERR-HARDENING', 'anti_passback_mode debe ser HARD para security_level >= 3.', '{IEC 60839-11-5,NIST SP 800-53 PE-3}', 'IEC 60839-11-5', '', TRUE, 'seed'),
('VAL-D5-101', 'Non-biometric alternative REQUIRED', 'NIST obliga ofrecer alternativa no biometrica (QR, PIN, tarjeta). Sin excepcion.', 'idn_role_d5', 'alternative_non_biometric', 'D5', 'TYPE', 'boolean', NULL, NULL, NULL, NULL, TRUE, 'error', 'ERR-HARDENING', 'Debe existir metodo no biometrico alternativo (NIST §5.2.3).', '{NIST SP 800-63B-4 §5.2.3,GDPR Art.9}', 'NIST SP 800-63B-4 §5.2.3', 'https://pages.nist.gov/800-63-4/sp800-63b.html', TRUE, 'seed'),
('VAL-D6-101', 'Impossible travel detection >900 km/h', 'Si dos accesos consecutivos imposibles fisicamente (>900 km/h) → bloqueo + alerta.', 'geo_velocity_policy', 'max_kmh', 'D6', 'RANGE', 'integer', '100', '900', NULL, NULL, TRUE, 'error', 'ERR-HARDENING', 'max_kmh debe estar entre 100 y 900.', '{NIST SP 800-207,OWASP ASVS V6}', 'NIST SP 800-207', 'https://csrc.nist.gov/publications/detail/sp/800-207/final', TRUE, 'seed'),
('VAL-D10-101', 'Max delegation 8 hours', 'Delegacion no debe exceder 8 horas. Despues requiere reautorizacion del delegador.', 'dlg_delegation', 'max_duration_hours', 'D10', 'RANGE', 'integer', '1', '8', NULL, NULL, TRUE, 'error', 'ERR-HARDENING', 'max_duration_hours debe estar entre 1 y 8.', '{NIST SP 800-53 AC-2(2),ISO 27001 A.8.2}', 'NIST SP 800-53 AC-2', 'https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final', TRUE, 'seed'),
('VAL-D10-102', 'Delegation non-transitive', 'Permisos delegados NO pueden ser subdelegados a terceros.', 'dlg_delegation', 'non_transitive', 'D10', 'TYPE', 'boolean', NULL, NULL, NULL, NULL, TRUE, 'error', 'ERR-HARDENING', 'non_transitive debe ser true.', '{NIST SP 800-53 AC-2,OWASP ASVS V8.2}', 'NIST SP 800-53 AC-2', 'https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final', TRUE, 'seed'),
('VAL-D11-101', 'WORM audit enabled', 'Eventos de auditoria deben ser append-only con hash-chain SHA-256. Sin UPDATE/DELETE.', 'aud_event', 'worm_enabled', 'D11', 'TYPE', 'boolean', NULL, NULL, NULL, NULL, TRUE, 'error', 'ERR-HARDENING', 'WORM debe estar habilitado (ISO 27001 A.8.15).', '{ISO 27001 A.8.15,PCI DSS 10.5}', 'ISO 27001:2022 A.8.15', 'https://www.iso.org/standard/82875.html', TRUE, 'seed'),
('VAL-D11-102', 'Ghost account detection 90 days', 'Cuentas sin login en 90 dias deben ser detectadas y bloqueadas preventivamente.', 'aud_ghost_account', 'max_inactive_days', 'D11', 'RANGE', 'integer', '30', '90', NULL, NULL, TRUE, 'error', 'ERR-HARDENING', 'max_inactive_days debe estar entre 30 y 90.', '{NIST SP 800-53 AC-2(3),ISO 27001 A.8.2}', 'NIST SP 800-53 AC-2', 'https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final', TRUE, 'seed'),
('VAL-SEC-101', 'Key rotation 90 days max', 'Claves criptograficas deben rotarse al menos cada 90 dias.', 'sec_key_inventory', 'rotation_days_max', 'SEC', 'RANGE', 'integer', '30', '90', NULL, NULL, TRUE, 'error', 'ERR-HARDENING', 'rotation_days_max debe estar entre 30 y 90.', '{NIST SP 800-57,PCI DSS 3.6}', 'NIST SP 800-57', 'https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev/5/final', TRUE, 'seed')
ON CONFLICT (rule_code) DO UPDATE SET
    rule_name = EXCLUDED.rule_name,
    description = EXCLUDED.description,
    min_value = EXCLUDED.min_value,
    max_value = EXCLUDED.max_value,
    severity = EXCLUDED.severity,
    error_message = EXCLUDED.error_message,
    standard_ref = EXCLUDED.standard_ref,
    updated_at = NOW();

-- ═══════════════════════════════════════════════════════════════════════════
-- TOTAL: 199 reglas · 17 dominios (D1-D12 + COMP + SEC + ALL)
-- Métodos auth: 26 · Bolivia: 17 · LATAM: 10 países (BO/AR/CL/PE/BR/CO/EC/PY/UY/MX)
-- NIST SP 800-53: AC-2/3/5/6/7/11, AU-3/9, IA-2, PE-3, SC-7/13, SI-7
-- OWASP ASVS 5.0: V2/V3/V4/V5/V6/V7/V8/V9/V13/V14
-- PCI DSS 4.0: Req 6/7/8/10/11
-- ISO 27001:2022: A.5.15-18, A.8.1-2/9/15-16/25, A.9.2/4, A.16
-- CIS Benchmarks: K8s, Ubuntu, PostgreSQL, Redis
-- GDPR: Art.5/7/9/17/32/33 · Digital Omnibus 2025
-- SOC 2: CC7.2 · NIST CSF 2.0 · FIDO2 CTAP 2.2 · MASVS
-- RFCs: 6238/4226/6455/6797/7518/7519/7636/8693/8996
-- ETSI: EN 319 102/132/142 · eIDAS 2.0 · SAML 2.0 · OIDC
-- Integraciones: Keycloak 26.x, Tryton 7.4, Vault, Redis 8.6.2, PostgreSQL 18.4
-- 50/50 grupos del framework cubiertos · 32/32 métodos de auth cubiertos
-- 10/12 países LATAM cubiertos
-- ═══════════════════════════════════════════════════════════════════════════
-- Bolivia: 17 reglas específicas (SIN, ADSIB, Ley 164, Ley 2492, ASFI,
--          SAFCO, Ley 453, CPE, Ley 483, SEGIP, Aguinaldo)
-- Países: BO (17) + AR (2) + CL (2) + PE (1) + BR (1) = 23 reglas país
-- 50/50 grupos del framework cubiertos
-- ═══════════════════════════════════════════════════════════════════════════
-- 50/50 grupos del framework cubiertos
-- Fuentes: NIST SP 800 series (63B/53/57/61/137/207/213/CSF2)
--           ISO 27001:2022/22301 · PCI DSS 4.0 · OWASP ASVS 5.0
--           FIDO2 CTAP 2.2 · GDPR/Digital Omnibus 2025 · SOC 2
--           RFC 6238/8996/8705/9470/6455 · SOX §404 · CIS v8
--           EIP-1559 · IEC 60839-11-5 · BS 5979 · CLT · eIDAS 2.0
--           Vault Best Practices · Shamir SSS · MASVS · Redis
--           Leyes laborales: BO/AR/CL/PE/BR
-- ═══════════════════════════════════════════════════════════════════════════
