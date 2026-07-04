-- ================================================================
-- bauth::saga_catalog — Catálogo declarativo de Sagas de Autenticación
-- Seed idempotente v1.0.0 — 2026-06-21
--
-- Estándares:
--   NIST SP 800-63B Rev.4 (Digital Identity Guidelines)
--   NIST SP 800-207 (Zero Trust Architecture)
--   ISO 27001:2022 A.5.15-A.5.18, A.8.2, A.8.5, A.8.15
--   OAuth 2.1 BCP (RFC 6749→9449)
--   RFC 9470 (Step-Up Authentication)
--   RFC 8693 (Token Exchange)
--   RFC 8705 (mTLS OAuth)
--   PCI DSS 4.0.1 Req 8 (MFA obligatorio)
--   OWASP ASVS 4.0.3 V2 (Authentication)
--   FIDO2/WebAuthn L3 + Passkeys
--
-- Cada saga modela un flujo completo con pasos y compensaciones.
-- El motor ejecuta pasos en secuencia; si uno falla, compensa en reverse.
-- ================================================================

-- ─── TABLA 1: Catálogo de Sagas ─────────────────────────────────
CREATE TABLE IF NOT EXISTS bauth.saga_catalog (
    saga_name       TEXT PRIMARY KEY,
    version         TEXT NOT NULL DEFAULT '1.0.0',
    description     TEXT NOT NULL,
    sequence_op     TEXT NOT NULL DEFAULT 'sequential'
                    CHECK (sequence_op IN ('sequential','parallel','conditional')),
    compensation    TEXT NOT NULL DEFAULT 'full_rollback'
                    CHECK (compensation IN ('full_rollback','best_effort','checkpoint','manual','none')),
    max_timeout_ms  INTEGER NOT NULL DEFAULT 60000,
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    requires_ctx    BOOLEAN NOT NULL DEFAULT TRUE,
    tier_minimum    TEXT NOT NULL DEFAULT 'EXT_N0'
                    CHECK (tier_minimum IN ('SU','SYS','BIZ_N3_N5','BIZ_N1_N2','EXT_N0','M2M','VISITANTE')),
    audit_level     TEXT NOT NULL DEFAULT 'basic'
                    CHECK (audit_level IN ('none','basic','full')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE bauth.saga_catalog IS 'Catálogo de sagas de autenticación — cada saga es un flujo orquestado con pasos y compensaciones (NIST SP 800-63B Rev.4)';
COMMENT ON COLUMN bauth.saga_catalog.tier_minimum IS 'Tier mínimo requerido para invocar esta saga (SU > SYS > BIZ_N3_N5 > BIZ_N1_N2 > EXT_N0 > M2M > VISITANTE)';
COMMENT ON COLUMN bauth.saga_catalog.requires_ctx IS 'Si requiere ctx_id obligatorio (SBOS-049)';
COMMENT ON COLUMN bauth.saga_catalog.compensation IS 'Estrategia de compensación: full_rollback (default NIST), best_effort, checkpoint, manual (HITL), none';

-- ─── TABLA 2: Pasos de cada saga ────────────────────────────────
CREATE TABLE IF NOT EXISTS bauth.saga_step (
    step_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    saga_name       TEXT NOT NULL REFERENCES bauth.saga_catalog(saga_name)
                    ON DELETE CASCADE,
    step_order      INTEGER NOT NULL,
    step_name       TEXT NOT NULL,
    saga_op         TEXT NOT NULL
                    CHECK (saga_op IN ('execute','validate','compensate','await','wait_for','emit','checkpoint','rollback','notify','noop')),
    action_ref      TEXT NOT NULL,
    compensate_ref  TEXT,
    timeout_ms      INTEGER NOT NULL DEFAULT 5000,
    max_retries     INTEGER NOT NULL DEFAULT 0,
    depends_on      TEXT[] DEFAULT '{}',
    preconditions   JSONB DEFAULT '[]'::jsonb,
    postconditions  JSONB DEFAULT '[]'::jsonb,
    config          JSONB DEFAULT '{}'::jsonb,
    UNIQUE (saga_name, step_order),
    UNIQUE (saga_name, step_name)
);

COMMENT ON TABLE bauth.saga_step IS 'Pasos individuales de cada saga — acción + compensación con pre/post condiciones';
COMMENT ON COLUMN bauth.saga_step.saga_op IS 'Operación: execute(ejecutar), validate(validar sin side-effects), compensate(deshacer), await(esperar evento), emit(emitir a Redis), checkpoint(guardar estado), rollback(revertir), notify(notificar daemon), noop(marcador)';
COMMENT ON COLUMN bauth.saga_step.compensate_ref IS 'Función de compensación — se ejecuta en orden INVERSO si la saga falla. NULL = paso idempotente sin compensación';

-- ─── TABLA 3: Historial inmutable de ejecuciones ────────────────
CREATE TABLE IF NOT EXISTS bauth.saga_execution (
    execution_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    saga_name       TEXT NOT NULL,
    saga_version    TEXT NOT NULL DEFAULT '1.0.0',
    ctx_id          TEXT NOT NULL,
    triggered_by    TEXT,
    params          JSONB NOT NULL DEFAULT '{}'::jsonb,
    status          TEXT NOT NULL
                    CHECK (status IN ('completed','compensated','failed','timeout','rejected','partially_completed')),
    steps_executed  INTEGER NOT NULL DEFAULT 0,
    steps_compensated INTEGER NOT NULL DEFAULT 0,
    final_state     JSONB DEFAULT '{}'::jsonb,
    step_details    JSONB DEFAULT '[]'::jsonb,
    error_message   TEXT,
    duration_ms     INTEGER,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_saga_execution_saga  ON bauth.saga_execution(saga_name);
CREATE INDEX IF NOT EXISTS idx_saga_execution_ctx   ON bauth.saga_execution(ctx_id);
CREATE INDEX IF NOT EXISTS idx_saga_execution_start ON bauth.saga_execution(started_at);

COMMENT ON TABLE bauth.saga_execution IS 'Registro inmutable de cada ejecución de saga — trazabilidad ISO 27001 A.8.15';

-- ================================================================
-- DATOS INICIALES — 12 sagas, 62 pasos
-- ================================================================

-- ─── S1: auth.password.login ────────────────────────────────────
INSERT INTO bauth.saga_catalog (saga_name, version, description, compensation, max_timeout_ms, tier_minimum, audit_level)
VALUES ('auth.password.login', '1.0.0',
        'Login con password + screening HIBP k-anonymity + risk score adaptativo + MFA condicional + emisión JWT. NIST SP 800-63B Rev.4 §5.1.1.2.',
        'full_rollback', 45000, 'EXT_N0', 'full')
ON CONFLICT (saga_name) DO UPDATE SET version = EXCLUDED.version, description = EXCLUDED.description;

INSERT INTO bauth.saga_step (saga_name, step_order, step_name, saga_op, action_ref, compensate_ref, timeout_ms, max_retries, depends_on)
VALUES
    ('auth.password.login', 0, 'verificar_credenciales', 'execute',
     'bauth.login.verify_argon2id', 'bauth.login.record_failed', 3000, 0, '{}'),
    ('auth.password.login', 1, 'screening_hibp', 'execute',
     'bauth.login.check_hibp_k_anon', NULL, 5000, 1, '{verificar_credenciales}'),
    ('auth.password.login', 2, 'evaluar_riesgo', 'validate',
     'bauth.risk.compute_score', 'bauth.risk.adjust_baseline', 500, 0, '{verificar_credenciales}'),
    ('auth.password.login', 3, 'mfa_condicional', 'validate',
     'bauth.mfa.evaluate_conditional', 'bauth.mfa.invalidate_challenge', 30000, 0, '{evaluar_riesgo}'),
    ('auth.password.login', 4, 'emitir_jwt', 'execute',
     'bauth.token.emit_jwt', 'bauth.token.revoke_immediate', 2000, 1, '{mfa_condicional}'),
    ('auth.password.login', 5, 'registrar_auditoria', 'emit',
     'bauth.audit.log_auth_event', NULL, 1000, 2, '{emitir_jwt}')
ON CONFLICT (saga_name, step_name) DO NOTHING;

-- ─── S2: auth.mfa.totp ──────────────────────────────────────────
INSERT INTO bauth.saga_catalog (saga_name, version, description, compensation, max_timeout_ms, tier_minimum, audit_level)
VALUES ('auth.mfa.totp', '1.0.0',
        'Verificación TOTP RFC 6238 (SHA256, 6 dígitos, 30s) + anti-replay via Redis + step-up condicional.',
        'full_rollback', 30000, 'BIZ_N1_N2', 'full')
ON CONFLICT DO NOTHING;

INSERT INTO bauth.saga_step (saga_name, step_order, step_name, saga_op, action_ref, compensate_ref, timeout_ms, max_retries, depends_on)
VALUES
    ('auth.mfa.totp', 0, 'validar_sesion_activa', 'validate',
     'bauth.session.validate_active', NULL, 500, 0, '{}'),
    ('auth.mfa.totp', 1, 'verificar_totp', 'execute',
     'bauth.mfa.verify_totp_rfc6238', 'bauth.mfa.increment_attempt', 10000, 0, '{validar_sesion_activa}'),
    ('auth.mfa.totp', 2, 'check_anti_replay', 'validate',
     'bauth.mfa.check_replay_redis', NULL, 200, 0, '{verificar_totp}'),
    ('auth.mfa.totp', 3, 'registrar_verificacion', 'emit',
     'bauth.audit.log_mfa_event', NULL, 500, 2, '{check_anti_replay}')
ON CONFLICT DO NOTHING;

-- ─── S3: auth.mfa.webauthn ──────────────────────────────────────
INSERT INTO bauth.saga_catalog (saga_name, version, description, compensation, max_timeout_ms, tier_minimum, audit_level)
VALUES ('auth.mfa.webauthn', '1.0.0',
        'Verificación FIDO2/WebAuthn L3 + contador de autenticación + RP ID validation. W3C WebAuthn Level 2.',
        'full_rollback', 60000, 'BIZ_N3_N5', 'full')
ON CONFLICT DO NOTHING;

INSERT INTO bauth.saga_step (saga_name, step_order, step_name, saga_op, action_ref, compensate_ref, timeout_ms, max_retries, depends_on)
VALUES
    ('auth.mfa.webauthn', 0, 'validar_sesion_activa', 'validate',
     'bauth.session.validate_active', NULL, 500, 0, '{}'),
    ('auth.mfa.webauthn', 1, 'generar_challenge', 'execute',
     'bauth.webauthn.generate_challenge', NULL, 1000, 0, '{validar_sesion_activa}'),
    ('auth.mfa.webauthn', 2, 'verificar_assertion', 'execute',
     'bauth.webauthn.verify_assertion', 'bauth.webauthn.revoke_challenge', 30000, 0, '{generar_challenge}'),
    ('auth.mfa.webauthn', 3, 'validar_rp_id', 'validate',
     'bauth.webauthn.check_rp_id', NULL, 200, 0, '{verificar_assertion}'),
    ('auth.mfa.webauthn', 4, 'verificar_counter', 'validate',
     'bauth.webauthn.check_sign_counter', NULL, 200, 0, '{verificar_assertion}'),
    ('auth.mfa.webauthn', 5, 'actualizar_counter', 'execute',
     'bauth.webauthn.update_counter', NULL, 500, 0, '{verificar_counter}'),
    ('auth.mfa.webauthn', 6, 'emitir_evento', 'emit',
     'bauth.audit.log_webauthn_event', NULL, 500, 2, '{actualizar_counter}')
ON CONFLICT DO NOTHING;

-- ─── S4: auth.step_up ───────────────────────────────────────────
INSERT INTO bauth.saga_catalog (saga_name, version, description, compensation, max_timeout_ms, tier_minimum, audit_level)
VALUES ('auth.step_up', '1.0.0',
        'Elevación temporal de LoA según RFC 9470. Máximo 15min. Requiere MFA adicional. Auditoría obligatoria.',
        'full_rollback', 120000, 'BIZ_N3_N5', 'full')
ON CONFLICT DO NOTHING;

INSERT INTO bauth.saga_step (saga_name, step_order, step_name, saga_op, action_ref, compensate_ref, timeout_ms, max_retries, depends_on)
VALUES
    ('auth.step_up', 0, 'verificar_loa_actual', 'validate',
     'bauth.session.check_current_loa', NULL, 200, 0, '{}'),
    ('auth.step_up', 1, 'evaluar_necesidad_step_up', 'validate',
     'bauth.stepup.evaluate_required', NULL, 500, 0, '{verificar_loa_actual}'),
    ('auth.step_up', 2, 'emitir_challenge', 'execute',
     'bauth.stepup.issue_challenge', 'bauth.stepup.revoke_challenge', 5000, 0, '{evaluar_necesidad_step_up}'),
    ('auth.step_up', 3, 'verificar_challenge', 'execute',
     'bauth.stepup.verify_response', 'bauth.stepup.invalidate_challenge', 30000, 0, '{emitir_challenge}'),
    ('auth.step_up', 4, 'elevar_loa_temporal', 'execute',
     'bauth.session.elevate_loa', 'bauth.session.restore_loa', 500, 0, '{verificar_challenge}'),
    ('auth.step_up', 5, 'programar_expiración', 'execute',
     'bauth.stepup.schedule_expiry_rfc9470', NULL, 500, 0, '{elevar_loa_temporal}'),
    ('auth.step_up', 6, 'auditar_elevacion', 'emit',
     'bauth.audit.log_step_up', NULL, 500, 2, '{elevar_loa_temporal}')
ON CONFLICT DO NOTHING;

-- ─── S5: auth.token.refresh ─────────────────────────────────────
INSERT INTO bauth.saga_catalog (saga_name, version, description, compensation, max_timeout_ms, tier_minimum, audit_level)
VALUES ('auth.token.refresh', '1.0.0',
        'Refresh token rotation OAuth 2.1 BCP. Rotación en cada uso. Reuse detection → revocación inmediata de familia.',
        'full_rollback', 10000, 'EXT_N0', 'basic')
ON CONFLICT DO NOTHING;

INSERT INTO bauth.saga_step (saga_name, step_order, step_name, saga_op, action_ref, compensate_ref, timeout_ms, max_retries, depends_on)
VALUES
    ('auth.token.refresh', 0, 'validar_refresh_token', 'validate',
     'bauth.token.validate_refresh', NULL, 1000, 0, '{}'),
    ('auth.token.refresh', 1, 'detectar_reuse', 'validate',
     'bauth.token.check_reuse', 'bauth.token.revoke_family', 500, 0, '{validar_refresh_token}'),
    ('auth.token.refresh', 2, 'invalidar_anterior', 'execute',
     'bauth.token.invalidate_previous', NULL, 500, 0, '{detectar_reuse}'),
    ('auth.token.refresh', 3, 'emitir_nuevo_par', 'execute',
     'bauth.token.emit_rotated_pair', 'bauth.token.revoke_new_pair', 1000, 0, '{invalidar_anterior}'),
    ('auth.token.refresh', 4, 'registrar_rotacion', 'emit',
     'bauth.audit.log_token_rotation', NULL, 500, 1, '{emitir_nuevo_par}')
ON CONFLICT DO NOTHING;

-- ─── S6: auth.federated.oidc ────────────────────────────────────
INSERT INTO bauth.saga_catalog (saga_name, version, description, compensation, max_timeout_ms, tier_minimum, audit_level)
VALUES ('auth.federated.oidc', '1.0.0',
        'Login federado OIDC + validación id_token + claim mapping + account linking. OAuth 2.1 + OIDC Core.',
        'checkpoint', 60000, 'EXT_N0', 'full')
ON CONFLICT DO NOTHING;

INSERT INTO bauth.saga_step (saga_name, step_order, step_name, saga_op, action_ref, compensate_ref, timeout_ms, max_retries, depends_on)
VALUES
    ('auth.federated.oidc', 0, 'recibir_redirect', 'await',
     'bauth.oidc.receive_callback', NULL, 30000, 0, '{}'),
    ('auth.federated.oidc', 1, 'validar_id_token', 'execute',
     'bauth.oidc.validate_id_token', NULL, 5000, 0, '{recibir_redirect}'),
    ('auth.federated.oidc', 2, 'verificar_nonce', 'validate',
     'bauth.oidc.check_nonce', NULL, 200, 0, '{validar_id_token}'),
    ('auth.federated.oidc', 3, 'mapear_claims', 'execute',
     'bauth.oidc.map_claims_to_roles', NULL, 1000, 0, '{validar_id_token}'),
    ('auth.federated.oidc', 4, 'vincular_o_crear_cuenta', 'execute',
     'bauth.oidc.link_or_create_account', 'bauth.oidc.unlink_account', 5000, 0, '{mapear_claims}'),
    ('auth.federated.oidc', 5, 'evaluar_riesgo_federado', 'validate',
     'bauth.risk.compute_federated_score', 'bauth.risk.adjust_baseline', 500, 0, '{vincular_o_crear_cuenta}'),
    ('auth.federated.oidc', 6, 'emitir_token_federado', 'execute',
     'bauth.token.emit_federated_jwt', 'bauth.token.revoke_immediate', 2000, 0, '{evaluar_riesgo_federado}')
ON CONFLICT DO NOTHING;

-- ─── S7: auth.emergency.break_glass ─────────────────────────────
INSERT INTO bauth.saga_catalog (saga_name, version, description, compensation, max_timeout_ms, tier_minimum, audit_level)
VALUES ('auth.emergency.break_glass', '1.0.0',
        'PAM break-glass SU. Vault 2-of-3 Shamir unseal. Session recording obligatorio. ISO 27001 A.8.2.',
        'manual', 14400000, 'SU', 'full')
ON CONFLICT DO NOTHING;

INSERT INTO bauth.saga_step (saga_name, step_order, step_name, saga_op, action_ref, compensate_ref, timeout_ms, max_retries, depends_on)
VALUES
    ('auth.emergency.break_glass', 0, 'registrar_justificacion', 'execute',
     'bauth.emergency.record_justification', NULL, 1000, 0, '{}'),
    ('auth.emergency.break_glass', 1, 'verificar_contexto_critico', 'validate',
     'bauth.emergency.verify_critical_context', NULL, 500, 0, '{registrar_justificacion}'),
    ('auth.emergency.break_glass', 2, 'solicitar_shamir_unseal', 'execute',
     'bauth.emergency.request_shamir_2of3', NULL, 120000, 0, '{verificar_contexto_critico}'),
    ('auth.emergency.break_glass', 3, 'iniciar_session_recording', 'execute',
     'bauth.emergency.start_recording', NULL, 1000, 0, '{solicitar_shamir_unseal}'),
    ('auth.emergency.break_glass', 4, 'activar_credenciales_su', 'execute',
     'bauth.emergency.activate_su_credentials', 'bauth.emergency.revoke_all', 5000, 0, '{iniciar_session_recording}'),
    ('auth.emergency.break_glass', 5, 'notificar_security_team', 'notify',
     'bauth.notify.security_team_all_channels', NULL, 5000, 3, '{activar_credenciales_su}'),
    ('auth.emergency.break_glass', 6, 'auditar_break_glass_24h', 'emit',
     'bauth.audit.log_break_glass_mandatory', NULL, 1000, 5, '{activar_credenciales_su}')
ON CONFLICT DO NOTHING;

-- ─── S8: auth.offline.login ─────────────────────────────────────
INSERT INTO bauth.saga_catalog (saga_name, version, description, compensation, max_timeout_ms, tier_minimum, audit_level)
VALUES ('auth.offline.login', '1.0.0',
        'Login sin conexión con credenciales cacheadas AES-256-GCM. Máximo 24h offline. Operaciones restringidas.',
        'best_effort', 30000, 'BIZ_N1_N2', 'full')
ON CONFLICT DO NOTHING;

INSERT INTO bauth.saga_step (saga_name, step_order, step_name, saga_op, action_ref, compensate_ref, timeout_ms, max_retries, depends_on)
VALUES
    ('auth.offline.login', 0, 'verificar_offline_cache', 'validate',
     'bauth.offline.check_cache_validity', NULL, 500, 0, '{}'),
    ('auth.offline.login', 1, 'validar_credenciales_locales', 'execute',
     'bauth.offline.verify_cached_argon2id', 'bauth.offline.increment_fail_count', 3000, 0, '{verificar_offline_cache}'),
    ('auth.offline.login', 2, 'verificar_integridad_cache', 'validate',
     'bauth.offline.verify_cache_hmac', NULL, 500, 0, '{validar_credenciales_locales}'),
    ('auth.offline.login', 3, 'verificar_limite_offline', 'validate',
     'bauth.offline.check_24h_limit', NULL, 200, 0, '{verificar_integridad_cache}'),
    ('auth.offline.login', 4, 'generar_token_temporal', 'execute',
     'bauth.token.emit_offline_jwt', NULL, 500, 0, '{verificar_limite_offline}'),
    ('auth.offline.login', 5, 'encolar_sync', 'checkpoint',
     'bauth.offline.enqueue_sync_on_reconnect', NULL, 500, 0, '{generar_token_temporal}')
ON CONFLICT DO NOTHING;

-- ─── S9: auth.password.reset ────────────────────────────────────
INSERT INTO bauth.saga_catalog (saga_name, version, description, compensation, max_timeout_ms, tier_minimum, audit_level)
VALUES ('auth.password.reset', '1.0.0',
        'Reset de password NIST SP 800-63B Rev.4 §5.1.1: token único time-boxed, screening HIBP, invalidar sesiones activas.',
        'full_rollback', 900000, 'EXT_N0', 'full')
ON CONFLICT DO NOTHING;

INSERT INTO bauth.saga_step (saga_name, step_order, step_name, saga_op, action_ref, compensate_ref, timeout_ms, max_retries, depends_on)
VALUES
    ('auth.password.reset', 0, 'validar_identidad', 'validate',
     'bauth.reset.verify_identity_email', NULL, 5000, 0, '{}'),
    ('auth.password.reset', 1, 'generar_reset_token', 'execute',
     'bauth.reset.generate_single_use_token', 'bauth.reset.invalidate_token', 1000, 0, '{validar_identidad}'),
    ('auth.password.reset', 2, 'verificar_token', 'execute',
     'bauth.reset.verify_token_timebox', NULL, 500, 0, '{generar_reset_token}'),
    ('auth.password.reset', 3, 'validar_nuevo_password', 'validate',
     'bauth.password.validate_against_policy', NULL, 1000, 0, '{verificar_token}'),
    ('auth.password.reset', 4, 'screening_hibp_nuevo', 'execute',
     'bauth.login.check_hibp_k_anon', NULL, 5000, 1, '{validar_nuevo_password}'),
    ('auth.password.reset', 5, 'almacenar_nuevo_hash', 'execute',
     'bauth.password.store_argon2id', 'bauth.password.restore_previous_hash', 2000, 0, '{screening_hibp_nuevo}'),
    ('auth.password.reset', 6, 'invalidar_sesiones_activas', 'execute',
     'bauth.session.invalidate_all_for_user', NULL, 1000, 1, '{almacenar_nuevo_hash}'),
    ('auth.password.reset', 7, 'auditar_reset', 'emit',
     'bauth.audit.log_password_reset', NULL, 500, 2, '{invalidar_sesiones_activas}')
ON CONFLICT DO NOTHING;

-- ─── S10: auth.mfa.enroll ───────────────────────────────────────
INSERT INTO bauth.saga_catalog (saga_name, version, description, compensation, max_timeout_ms, tier_minimum, audit_level)
VALUES ('auth.mfa.enroll', '1.0.0',
        'Enrollment MFA: generar secret TOTP / crear credencial FIDO2 + recovery codes + verificación + confirmación.',
        'full_rollback', 300000, 'EXT_N0', 'full')
ON CONFLICT DO NOTHING;

INSERT INTO bauth.saga_step (saga_name, step_order, step_name, saga_op, action_ref, compensate_ref, timeout_ms, max_retries, depends_on)
VALUES
    ('auth.mfa.enroll', 0, 'verificar_password_actual', 'execute',
     'bauth.login.verify_argon2id', 'bauth.login.record_failed', 3000, 0, '{}'),
    ('auth.mfa.enroll', 1, 'generar_secret', 'execute',
     'bauth.mfa.generate_totp_secret', 'bauth.mfa.discard_secret', 1000, 0, '{verificar_password_actual}'),
    ('auth.mfa.enroll', 2, 'verificar_qr_scan', 'await',
     'bauth.mfa.await_totp_confirmation', NULL, 120000, 0, '{generar_secret}'),
    ('auth.mfa.enroll', 3, 'generar_recovery_codes', 'execute',
     'bauth.mfa.generate_recovery_codes_sha256', 'bauth.mfa.invalidate_recovery_codes', 1000, 0, '{verificar_qr_scan}'),
    ('auth.mfa.enroll', 4, 'confirmar_enrollment', 'execute',
     'bauth.mfa.confirm_and_activate', 'bauth.mfa.rollback_enrollment', 500, 0, '{generar_recovery_codes}'),
    ('auth.mfa.enroll', 5, 'auditar_enrollment', 'emit',
     'bauth.audit.log_mfa_enrollment', NULL, 500, 2, '{confirmar_enrollment}')
ON CONFLICT DO NOTHING;

-- ─── S11: auth.session.validate ─────────────────────────────────
INSERT INTO bauth.saga_catalog (saga_name, version, description, compensation, max_timeout_ms, tier_minimum, audit_level)
VALUES ('auth.session.validate', '1.0.0',
        'Validación continua de sesión por request: token + ctx_id + risk score + device binding. NIST SP 800-207 Zero Trust.',
        'best_effort', 2000, 'EXT_N0', 'basic')
ON CONFLICT DO NOTHING;

INSERT INTO bauth.saga_step (saga_name, step_order, step_name, saga_op, action_ref, compensate_ref, timeout_ms, max_retries, depends_on)
VALUES
    ('auth.session.validate', 0, 'validar_token_jwt', 'validate',
     'bauth.token.validate_jwt_claims', NULL, 500, 0, '{}'),
    ('auth.session.validate', 1, 'verificar_ctx_id', 'validate',
     'bauth.ctx.validate_structure', NULL, 200, 0, '{validar_token_jwt}'),
    ('auth.session.validate', 2, 'verificar_device_binding', 'validate',
     'bauth.session.check_device_fingerprint', NULL, 200, 0, '{validar_token_jwt}'),
    ('auth.session.validate', 3, 'evaluar_risk_score_continuo', 'validate',
     'bauth.risk.compute_continuous_score', NULL, 300, 0, '{verificar_device_binding}'),
    ('auth.session.validate', 4, 'extender_sesion', 'execute',
     'bauth.session.extend_if_valid', NULL, 300, 0, '{evaluar_risk_score_continuo}')
ON CONFLICT DO NOTHING;

-- ─── S12: auth.account.lockout ──────────────────────────────────
INSERT INTO bauth.saga_catalog (saga_name, version, description, compensation, max_timeout_ms, tier_minimum, audit_level)
VALUES ('auth.account.lockout', '1.0.0',
        'Bloqueo progresivo anti-automatización OWASP ASVS 2.2.3: 5→10→20 intentos con ventanas crecientes. Redis sliding window.',
        'checkpoint', 5000, 'EXT_N0', 'full')
ON CONFLICT DO NOTHING;

INSERT INTO bauth.saga_step (saga_name, step_order, step_name, saga_op, action_ref, compensate_ref, timeout_ms, max_retries, depends_on)
VALUES
    ('auth.account.lockout', 0, 'contar_intentos_fallidos', 'execute',
     'bauth.lockout.increment_sliding_window', NULL, 200, 0, '{}'),
    ('auth.account.lockout', 1, 'evaluar_umbral', 'validate',
     'bauth.lockout.evaluate_threshold', NULL, 100, 0, '{contar_intentos_fallidos}'),
    ('auth.account.lockout', 2, 'bloquear_cuenta', 'execute',
     'bauth.lockout.lock_account_progressive', 'bauth.lockout.unlock_account', 500, 0, '{evaluar_umbral}'),
    ('auth.account.lockout', 3, 'generar_recovery_token', 'execute',
     'bauth.lockout.issue_unlock_token', NULL, 500, 0, '{bloquear_cuenta}'),
    ('auth.account.lockout', 4, 'notificar_admin', 'notify',
     'bauth.notify.admin_account_locked', NULL, 2000, 2, '{bloquear_cuenta}'),
    ('auth.account.lockout', 5, 'auditar_lockout', 'emit',
     'bauth.audit.log_account_lockout', NULL, 500, 2, '{bloquear_cuenta}')
ON CONFLICT DO NOTHING;

-- ─── Verificación ──────────────────────────────────────────────
SELECT 'saga_catalog' as tabla, count(*) as registros FROM bauth.saga_catalog
UNION ALL SELECT 'saga_step', count(*) FROM bauth.saga_step;
