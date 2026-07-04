-- seed_privilege_domain.sql — 12 dominios de soberanía D1-D12
-- IDEMPOTENCIA: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: BauthAgent/src/bitmask/catalog.rs líneas 153-166 (SEED_DOMAINS)
-- Alineado con schema real: domain_code SMALLINT PK, domain_name, requires_policy, description
-- ═══════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bauth.privilege_domain RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.privilege_domain;

INSERT INTO bauth.privilege_domain (domain_code, domain_name, requires_policy, description) VALUES
  (1,  'Lógico',      false, 'Apps y recursos digitales. Fast-Path: verbo suficiente.'),
  (2,  'Físico',      false, 'Zonas y hardware. OSDP Secure Channel AES-128.'),
  (3,  'Financiero',  true,  'Límites, SoD, dual-approval. Policy-Path.'),
  (4,  'Temporal',    true,  'Horarios, turnos, feriados. Encadenado a D1.'),
  (5,  'Biométrico',  false, 'Huella, rostro, iris. External-Path vía Keycloak.'),
  (6,  'Geoespacial', true,  'Ubicación, viaje imposible (900 km/h). Encadenado a D1.'),
  (7,  'Red',         true,  'CIDR, VPN, mTLS, device posture. External-Path vía Kong.'),
  (8,  'Contexto',    false, 'ctx_id en Redis. Pre-condición del BitMask.'),
  (9,  'Credenciales',false, 'Passwords, MFA, certificados. Pre-BitMask vía Keycloak.'),
  (10, 'Delegación',  true,  'Privilegios temporales. AND reduction.'),
  (11, 'Auditoría',   false, 'WORM. No evalúa — solo registra. Post-hoc.'),
  (12, 'Blockchain',  true,  'Var A: Merkle anchoring. Var B: liquidación Besu QBFT.');

-- SELECT count(*) FROM bauth.privilege_domain; -- debe ser 12
