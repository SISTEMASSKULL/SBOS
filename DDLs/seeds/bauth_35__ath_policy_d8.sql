-- seed_ath_policy_d8.sql — Políticas D8 Contexto
SET lock_timeout = '5s'; TRUNCATE TABLE bauth.ath_policy_d8 RESTART IDENTITY CASCADE; REINDEX TABLE bauth.ath_policy_d8;
INSERT INTO bauth.ath_policy_d8 (policy_code, policy_name, description, standard_ref, config) VALUES
('CTX_ID_REQUIRED','ctx_id obligatorio','Toda operación requiere ctx_id válido. Sin ctx_id → DENY. SBOS-049 §2.','{SBOS-049,W3C Trace Context}','{"rule":"ctx_id_required","validation":"strict"}'),
('SESSION_TTL_8H','Sesión 8 horas','Timeout absoluto de sesión: 28800 segundos. Inactividad: 900 segundos.','{NIST SP 800-63B-4 §7}','{"rule":"session_ttl","max_seconds":28800,"idle_seconds":900}'),
('REAUTH_4H','Reautenticación cada 4h','Requiere reautenticación biométrica cada 14400 segundos aunque la sesión esté activa.','{NIST SP 800-63B-4 §7.2}','{"rule":"reauth","interval_seconds":14400}'),
('CONTEXT_SWITCH_AUDIT','Auditar cambio de contexto','Todo cambio de empresa/sucursal/POS genera audit_event y ctx_transfer_log.','{SBOS-049 §5,ISO 27001 A.8.15}','{"rule":"context_switch_audit","log_all":true}'),
('CAEP_SESSION_REVOKED','CAEP: session-revoked','Emitir evento CAEP cuando la sesión es revocada. Notificar a RPs suscritos.','{OpenID CAEP 1.0}','{"rule":"caep","events":["session-revoked","assurance-level-change"]}');
