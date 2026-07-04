INSERT INTO bauth.bos_global_config (config_key, config_value, data_type, category, description, purpose, default_value, version)
VALUES 
('system.database_url', '{"env":"DATABASE_URL","format":"postgres://user:pass@host:5432/bauth_db","required":true}', 'jsonb', 'general', 'URL de conexión a PostgreSQL requerida para todos los binarios bAuth', 'Conexión a bauth_db — NUNCA hardcodear credenciales en código', '{"env":"DATABASE_URL"}', 1),
('system.socket_path',  '{"default":"/run/bos/bauth.sock","permissions":"0660","group":"bosagent"}', 'jsonb', 'general', 'Ruta del socket Unix del daemon bAuth (Interface Dual ADR-020)', 'Transporte JSON-RPC + WebSocket sobre MISMO socket', '{"default":"/run/bos/bauth.sock"}', 1),
('system.max_connections','{"default":1000,"min":10,"max":10000}', 'jsonb', 'general', 'Máximo de conexiones concurrentes al socket Unix', 'Control de recursos — prevenir DoS', '{"default":1000}', 1),
('system.preflight.min_fd','{"default":4096,"reason":"NIST SP 800-53 Rev.5 CM-6"}', 'jsonb', 'general', 'Mínimo de file descriptors requeridos para arrancar', 'Preflight validator — chequeo de recursos del SO', '{"default":4096}', 1),
('system.log_level',    '{"default":"info","options":["trace","debug","info","warn","error"],"env":"RUST_LOG"}', 'jsonb', 'general', 'Nivel de logging del daemon — configurable vía variable de entorno RUST_LOG', 'Observabilidad — tracing-subscriber EnvFilter', '{"default":"info"}', 1)
ON CONFLICT (config_key) DO UPDATE SET config_value = EXCLUDED.config_value, version = EXCLUDED.version, updated_at = now();
