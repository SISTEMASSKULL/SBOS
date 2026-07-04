-- ============================================================
-- bauth.bos_global_config — Catálogo Central de Parámetros
-- NIST SP 800-53 CM-6 (Configuration Settings)
-- ISO 27001:2022 A.8.9 (Configuration Management)
-- AWS SSM Parameter Store / Vault KV v2 pattern
--
-- Cada parámetro es UNA fila autodescriptiva con:
--   - Clave única, valor JSONB, tipo de dato
--   - Propósito, referencia normativa, valor por defecto
--   - Trazabilidad (quién, cuándo, versión)
-- ============================================================

DROP TABLE IF EXISTS bauth.bos_global_config CASCADE;

CREATE TABLE bauth.bos_global_config (
    config_key    VARCHAR(128) PRIMARY KEY,
    config_value  JSONB NOT NULL,
    data_type     VARCHAR(32) NOT NULL DEFAULT 'jsonb',
    category      VARCHAR(64) NOT NULL DEFAULT 'general',
    description   TEXT NOT NULL DEFAULT '',
    purpose       TEXT NOT NULL DEFAULT '',
    standard_ref  TEXT NOT NULL DEFAULT '',
    default_value JSONB,
    version       INTEGER NOT NULL DEFAULT 1,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by    VARCHAR(64),
    CONSTRAINT ck_config_category CHECK (category IN (
        'financial', 'authentication', 'authorization', 'network',
        'session', 'audit', 'blockchain', 'performance', 'general'
    )),
    CONSTRAINT ck_config_data_type CHECK (data_type IN (
        'jsonb', 'string', 'integer', 'float', 'boolean', 'array'
    ))
);

COMMENT ON TABLE bauth.bos_global_config IS 'Catálogo central de parámetros del sistema. Fuente única de verdad para toda configuración modificable en runtime. NIST SP 800-53 CM-6.';

-- ============================================================
-- Parámetros financieros
-- ============================================================
INSERT INTO bauth.bos_global_config (config_key, config_value, data_type, category, description, purpose, standard_ref, default_value) VALUES
('financial.decimal_places', '13', 'integer', 'financial',
 'Precisión decimal mínima para montos monetarios.',
 'Garantizar integridad de cálculos financieros sin redondeo.',
 'ISO 20022 ActiveCurrencyAnd13DecimalAmount · FATF Rec.16 (Jun 2025) · PCI-DSS 4.0.1 §7',
 '13'),

('financial.default_currency', '"BOB"', 'string', 'financial',
 'Moneda por defecto para operaciones financieras.',
 'Establecer moneda base cuando no se especifica.',
 'ISO 4217 · SIN RND 102100000011',
 '"BOB"'),

('financial.max_transaction_limit', '1000000.0000000000000', 'float', 'financial',
 'Límite máximo global por transacción en moneda base.',
 'Prevenir fraudes por montos excesivos.',
 'PCI-DSS 4.0.1 §7 · FATF Rec.16',
 '1000000.0000000000000'),

-- ============================================================
-- Parámetros de autenticación
-- ============================================================
('auth.session_ttl_seconds', '28800', 'integer', 'authentication',
 'TTL máximo de sesión en segundos (8 horas por defecto).',
 'Limitar exposición de sesiones activas.',
 'NIST SP 800-63B Rev.4 §7 · ISO 27001 A.9.2.5',
 '28800'),

('auth.max_failed_attempts', '5', 'integer', 'authentication',
 'Intentos fallidos de autenticación antes de bloqueo temporal.',
 'Prevenir fuerza bruta sobre credenciales.',
 'NIST SP 800-63B Rev.4 §5.2.2 · OWASP ASVS V2.1',
 '5'),

('auth.lockout_duration_seconds', '900', 'integer', 'authentication',
 'Duración del bloqueo tras exceder max_failed_attempts (15 min).',
 'Desincentivar ataques de diccionario sin bloquear permanentemente.',
 'NIST SP 800-63B Rev.4 §5.2.2',
 '900'),

('auth.mfa_required', 'true', 'boolean', 'authentication',
 'MFA obligatorio para todos los usuarios.',
 'Cumplir AAL2 como mínimo según NIST.',
 'NIST SP 800-63B Rev.4 AAL2 · PCI-DSS 4.0.1 §8',
 'true'),

('auth.password_min_length', '12', 'integer', 'authentication',
 'Longitud mínima de contraseña.',
 'Cumplir requisitos NIST de longitud sobre complejidad.',
 'NIST SP 800-63B Rev.4 §5.1.1.2',
 '12'),

-- ============================================================
-- Parámetros de autorización y políticas
-- ============================================================
('policy.evaluation_timeout_ms', '100', 'integer', 'authorization',
 'Timeout máximo para evaluación de políticas por dominio.',
 'Prevenir bloqueos por evaluación lenta de políticas.',
 'NIST SP 800-162 ABAC · SBOS-BAUTH-MOTORES-DOMINIO.md §2',
 '100'),

('policy.max_policies_per_atom', '10', 'integer', 'authorization',
 'Máximo de políticas encadenadas por átomo.',
 'Prevenir degradación por exceso de políticas.',
 'SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md §8',
 '10'),

('policy.fastpath_max_ns', '1', 'integer', 'authorization',
 'Latencia máxima en nanosegundos para Fast-Path (D1, D2).',
 'Garantizar que la evaluación no degrade el hot path.',
 'SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md §6.1',
 '1'),

-- ============================================================
-- Parámetros de red
-- ============================================================
('network.cidr_corporate', '["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]', 'array', 'network',
 'Rangos CIDR corporativos permitidos.',
 'Restringir acceso a IPs internas.',
 'SBOS-054-NETWORK-SECURITY.md NRS-01 · NIST SP 800-207 ZTNA',
 '["10.0.0.0/8","172.16.0.0/12","192.168.0.0/16"]'),

('network.max_connections_per_ip', '100', 'integer', 'network',
 'Máximo de conexiones concurrentes por IP.',
 'Prevenir DoS desde una sola dirección.',
 'SBOS-054 NRS-07 · OWASP ASVS V4.7',
 '100'),

-- ============================================================
-- Parámetros de auditoría
-- ============================================================
('audit.retention_days', '365', 'integer', 'audit',
 'Días de retención de eventos de auditoría.',
 'Cumplir requisitos legales de trazabilidad.',
 'ISO 27001 A.8.15 · Ley 164 Bolivia · PCI-DSS 4.0.1 §10',
 '365'),

('audit.worm_enabled', 'true', 'boolean', 'audit',
 'Protección WORM habilitada (solo INSERT, sin UPDATE/DELETE).',
 'Garantizar inmutabilidad del registro de auditoría.',
 'ISO 27001 A.8.15 · NIST SP 800-53 AU-9',
 'true'),

-- ============================================================
-- Parámetros de blockchain
-- ============================================================
('blockchain.min_gas_balance_eth', '0.005', 'float', 'blockchain',
 'Balance mínimo de ETH para operaciones de anclaje.',
 'Prevenir fallos de transacción por gas insuficiente.',
 'SBOS-MANUAL-BAUTH-D12-BLOCKCHAIN-WALLET-CONTROL.md §5',
 '0.005'),

('blockchain.anchor_interval_hours', '1', 'integer', 'blockchain',
 'Intervalo de anclaje Merkle en horas.',
 'Frecuencia de publicación de raíces Merkle en Arbitrum.',
 'RFC 6962 · SBOS-D12 §3',
 '1');

SELECT config_key, data_type, category FROM bauth.bos_global_config ORDER BY category, config_key;
