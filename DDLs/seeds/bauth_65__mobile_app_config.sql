-- seed_mobile_app_config.sql — Configuración inicial de apps cliente
SET lock_timeout = '5s'; TRUNCATE TABLE bauth.mobile_app_config RESTART IDENTITY CASCADE; REINDEX TABLE bauth.mobile_app_config;
INSERT INTO bauth.mobile_app_config (platform, min_app_version, latest_app_version, endpoints, feature_flags) VALUES
('ios','1.0.0','1.0.0','{"ws_url":"wss://sbos.app/ws","api_url":"https://api.sbos.app","auth_url":"https://auth.sbos.app"}','{"passkeys":true,"qr_transfer":true,"nfc_access":true,"biometric_lock":true}'),
('android','1.0.0','1.0.0','{"ws_url":"wss://sbos.app/ws","api_url":"https://api.sbos.app","auth_url":"https://auth.sbos.app"}','{"passkeys":true,"qr_transfer":true,"nfc_access":true,"biometric_lock":true}'),
('windows','1.0.0',null,'{"ws_url":"wss://sbos.app/ws","api_url":"https://api.sbos.app"}','{"passkeys":true,"windows_hello":true}'),
('macos','1.0.0',null,'{"ws_url":"wss://sbos.app/ws","api_url":"https://api.sbos.app"}','{"passkeys":true,"touch_id":true}'),
('linux','1.0.0',null,'{"ws_url":"wss://sbos.app/ws","api_url":"https://api.sbos.app"}','{"passkeys":true}');
