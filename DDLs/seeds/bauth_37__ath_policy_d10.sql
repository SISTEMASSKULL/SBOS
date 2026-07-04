-- seed_ath_policy_d10.sql — Políticas D10 Delegación
SET lock_timeout = '5s'; TRUNCATE TABLE bauth.ath_policy_d10 RESTART IDENTITY CASCADE; REINDEX TABLE bauth.ath_policy_d10;
INSERT INTO bauth.ath_policy_d10 (policy_code, policy_name, description, standard_ref, config) VALUES
('DELEGATION_MAX_7D','Delegación máxima 7 días','Una delegación no puede durar más de 168 horas. Auto-revoke al expirar.','{NIST SP 800-53 AC-5,ANSI INCITS 359-2004 DSD}','{"rule":"max_duration","max_hours":168,"auto_revoke":true}'),
('DELEGATION_NO_CHAIN','Sin re-delegación','El delegado NO puede delegar a su vez. Profundidad máxima de cadena: 1.','{NIST SP 800-53 AC-5}','{"rule":"no_redelegation","max_chain_depth":1}'),
('DELEGATION_NON_TRANSFERABLE','Permisos no delegables','Ciertos permisos nunca pueden ser delegados: config_system, user_management, audit_delete.','{ISO 27001 A.8.2}','{"rule":"non_delegable","permissions":["system_config","user_role_assignment","audit_log_delete"]}'),
('DELEGATION_APPROVAL_REQUIRED','Aprobación requerida','Toda delegación requiere aprobación de un supervisor del nivel superior.','{ISO 27001 A.8.2,NIST SP 800-53 AC-5}','{"rule":"requires_approval","approver_level":"SUPERIOR"}');
