-- ============================================================
-- Seed: bauth.auth_crypto_algorithm (T-338)
-- Catálogo canónico de algoritmos criptográficos con estado NIST.
--
-- Fuente de verdad: FIPS 140-3, FIPS 197, FIPS 186-5, NIST SP 800-131A R2,
--   FIPS 203 (ML-KEM), FIPS 204 (ML-DSA), FIPS 205 (SLH-DSA),
--   NIST SP 800-227 (PQC transition), RFC 9106 (Argon2).
--
-- Tipos (MC-0067 → A.65.04):
--   KDF            — Derivación de clave (Argon2id, PBKDF2, HKDF, scrypt)
--   SYMMETRIC      — Cifrado simétrico y MACs con clave (AES-256-GCM, ChaCha20, HMAC)
--   ASYMMETRIC_SIG — Firma asimétrica clásica (Ed25519, ECDSA, RSA)
--   ASYMMETRIC_KEM — Intercambio de clave clásico (X25519, ECDH)
--   HASH           — Funciones de hash sin clave (SHA-2, SHA-3, BLAKE3)
--   PQC            — Algoritmos post-cuánticos FIPS 203/204/205 (is_pqc=TRUE)
--
-- Status (MC-0066 → A.65.04):
--   APPROVED   — Seguro para uso en producción
--   DEPRECATED — En transición; aceptado en lectura, NO en nuevos registros
--   FORBIDDEN  — Prohibido; el motor Rust rechaza operaciones con este algoritmo
--
-- Idempotente: ON CONFLICT (code) DO UPDATE
-- ============================================================

BEGIN;

-- ────────────────────────────────────────────────────────────
-- KDF — Derivación de clave
-- ────────────────────────────────────────────────────────────

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('ARGON2ID', 'KDF', FALSE,
     '{"t_cost": 3, "m_cost": 65536, "p_cost": 4, "output_len": 32,
       "nota": "Parámetros OWASP 2024. SU: t=5 m=131072; BIZ: t=2 m=19456"}',
     'APPROVED',
     'RFC 9106 · OWASP Password Storage Cheat Sheet 2024')

ON CONFLICT (code) DO UPDATE SET
    type          = EXCLUDED.type,
    is_pqc        = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params,
    status        = EXCLUDED.status,
    nist_ref      = EXCLUDED.nist_ref,
    deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('HKDF-SHA256', 'KDF', FALSE,
     '{"hash": "SHA-256", "output_len": 32}',
     'APPROVED',
     'RFC 5869 · NIST SP 800-56C Rev.2')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('PBKDF2-SHA256', 'KDF', FALSE,
     '{"iterations": 600000, "hash": "SHA-256", "output_len": 32,
       "nota": "NIST mín 600k iter 2023; solo para compatibilidad legacy"}',
     'DEPRECATED',
     'NIST SP 800-132 · OWASP 2024')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

-- ────────────────────────────────────────────────────────────
-- SYMMETRIC — Cifrado simétrico y MACs autenticados
-- ────────────────────────────────────────────────────────────

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('AES-256-GCM', 'SYMMETRIC', FALSE,
     '{"key_len_bits": 256, "iv_len_bits": 96, "tag_len_bits": 128}',
     'APPROVED',
     'NIST FIPS 197 · NIST SP 800-38D')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('CHACHA20-POLY1305', 'SYMMETRIC', FALSE,
     '{"key_len_bits": 256, "nonce_len_bits": 96, "tag_len_bits": 128}',
     'APPROVED',
     'RFC 8439 · IETF TLS 1.3')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('HMAC-SHA256', 'SYMMETRIC', FALSE,
     '{"hash": "SHA-256", "key_len_min_bits": 256, "output_len_bits": 256}',
     'APPROVED',
     'NIST FIPS 198-1 · RFC 2104')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('HMAC-SHA512', 'SYMMETRIC', FALSE,
     '{"hash": "SHA-512", "key_len_min_bits": 512, "output_len_bits": 512}',
     'APPROVED',
     'NIST FIPS 198-1 · RFC 2104')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref, deprecated_at)
VALUES
    ('AES-128-CBC', 'SYMMETRIC', FALSE,
     '{"key_len_bits": 128, "block_len_bits": 128,
       "nota": "Sin autenticación integrada — DEPRECATED a favor de AES-256-GCM"}',
     'DEPRECATED',
     'NIST FIPS 197 · NIST SP 800-38A',
     '2024-01-01 00:00:00+00')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref, deprecated_at)
VALUES
    ('DES', 'SYMMETRIC', FALSE,
     '{"key_len_bits": 56, "nota": "PROHIBIDO — clave de 56 bits; roto en segundos"}',
     'FORBIDDEN',
     'NIST SP 800-131A R2 §2 — desaprobado',
     '1998-01-01 00:00:00+00')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref, deprecated_at)
VALUES
    ('3DES', 'SYMMETRIC', FALSE,
     '{"key_len_bits": 112, "nota": "PROHIBIDO desde 2023 — Sweet32 attack; 64-bit block"}',
     'FORBIDDEN',
     'NIST SP 800-131A R2 §2 — desaprobado desde 2023',
     '2023-01-01 00:00:00+00')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

-- ────────────────────────────────────────────────────────────
-- ASYMMETRIC_SIG — Firmas asimétricas clásicas
-- ────────────────────────────────────────────────────────────

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('ED25519', 'ASYMMETRIC_SIG', FALSE,
     '{"curve": "Curve25519", "sig_len_bytes": 64, "pk_len_bytes": 32,
       "uso": "JWT-Ed25519 interno; firma de bAuth tokens"}',
     'APPROVED',
     'RFC 8032 · NIST SP 800-186 · FIPS 186-5')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('ECDSA-P384', 'ASYMMETRIC_SIG', FALSE,
     '{"curve": "P-384", "hash": "SHA-384", "sig_len_bytes": 96, "security_bits": 192}',
     'APPROVED',
     'NIST FIPS 186-5 · NIST SP 800-186')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('RSA-4096-PSS', 'ASYMMETRIC_SIG', FALSE,
     '{"key_len_bits": 4096, "padding": "PSS", "hash": "SHA-256",
       "nota": "Válido solo para interoperabilidad PKI externa; preferir Ed25519 internamente"}',
     'DEPRECATED',
     'NIST SP 800-131A R2 · FIPS 186-5')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref, deprecated_at)
VALUES
    ('RSA-PKCS1-v1_5', 'ASYMMETRIC_SIG', FALSE,
     '{"padding": "PKCS1-v1_5", "nota": "PROHIBIDO — padding determinista; vulnerable a Bleichenbacher"}',
     'FORBIDDEN',
     'NIST SP 800-131A R2 — desaprobado',
     '2020-01-01 00:00:00+00')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref, deprecated_at)
VALUES
    ('RSA-1024', 'ASYMMETRIC_SIG', FALSE,
     '{"key_len_bits": 1024, "nota": "PROHIBIDO — factorizable con hardware actual"}',
     'FORBIDDEN',
     'NIST SP 800-131A R2 §3 — desaprobado desde 2010',
     '2010-01-01 00:00:00+00')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

-- ────────────────────────────────────────────────────────────
-- ASYMMETRIC_KEM — Intercambio de clave clásico
-- ────────────────────────────────────────────────────────────

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('X25519', 'ASYMMETRIC_KEM', FALSE,
     '{"curve": "Curve25519", "pk_len_bytes": 32, "shared_secret_len_bytes": 32,
       "uso": "ECDH efímero para TLS 1.3 y protocolos internos"}',
     'APPROVED',
     'RFC 7748 · NIST SP 800-186')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('ECDH-P384', 'ASYMMETRIC_KEM', FALSE,
     '{"curve": "P-384", "shared_secret_len_bytes": 48, "security_bits": 192}',
     'APPROVED',
     'NIST SP 800-56A Rev.3 · NIST SP 800-186')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

-- ────────────────────────────────────────────────────────────
-- HASH — Funciones de hash sin clave
-- ────────────────────────────────────────────────────────────

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('SHA-256', 'HASH', FALSE,
     '{"output_len_bits": 256, "block_len_bits": 512}',
     'APPROVED',
     'NIST FIPS 180-4')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('SHA-384', 'HASH', FALSE,
     '{"output_len_bits": 384, "block_len_bits": 1024}',
     'APPROVED',
     'NIST FIPS 180-4')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('SHA-512', 'HASH', FALSE,
     '{"output_len_bits": 512, "block_len_bits": 1024}',
     'APPROVED',
     'NIST FIPS 180-4')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('SHA3-256', 'HASH', FALSE,
     '{"output_len_bits": 256, "sponge_rate_bits": 1088, "capacity_bits": 512}',
     'APPROVED',
     'NIST FIPS 202')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('SHA3-512', 'HASH', FALSE,
     '{"output_len_bits": 512, "sponge_rate_bits": 576, "capacity_bits": 1024}',
     'APPROVED',
     'NIST FIPS 202')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('BLAKE3', 'HASH', FALSE,
     '{"output_len_bits": 256, "nota": "Alternativa moderna a SHA-256; velocidad 3-8x superior"}',
     'APPROVED',
     'BLAKE3 spec 2020 · IETF draft-aumasson-blake3')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref, deprecated_at)
VALUES
    ('SHA-1', 'HASH', FALSE,
     '{"output_len_bits": 160, "nota": "PROHIBIDO — colisiones prácticas desde 2017 (SHAttered)"}',
     'FORBIDDEN',
     'NIST SP 800-131A R2 §9 — desaprobado para firmas desde 2011',
     '2011-01-01 00:00:00+00')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref, deprecated_at)
VALUES
    ('MD5', 'HASH', FALSE,
     '{"output_len_bits": 128, "nota": "PROHIBIDO — colisiones triviales; roto completamente"}',
     'FORBIDDEN',
     'NIST SP 800-131A R2 — desaprobado',
     '2005-01-01 00:00:00+00')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

-- ────────────────────────────────────────────────────────────
-- PQC — Algoritmos post-cuánticos FIPS 203/204/205
-- ────────────────────────────────────────────────────────────

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('ML-KEM-768', 'PQC', TRUE,
     '{"variant": "ML-KEM-768", "security_level": 3,
       "pk_len_bytes": 1184, "sk_len_bytes": 2400,
       "ct_len_bytes": 1088, "shared_secret_len_bytes": 32,
       "uso": "Key encapsulation — reemplaza X25519/ECDH para cifrado post-cuántico"}',
     'APPROVED',
     'NIST FIPS 203 (agosto 2024) — Module-Lattice-Based Key-Encapsulation Mechanism')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('ML-DSA-65', 'PQC', TRUE,
     '{"variant": "ML-DSA-65", "security_level": 3,
       "pk_len_bytes": 1952, "sk_len_bytes": 4032, "sig_len_bytes": 3309,
       "uso": "Firma digital — reemplaza Ed25519/ECDSA para firmas post-cuánticas"}',
     'APPROVED',
     'NIST FIPS 204 (agosto 2024) — Module-Lattice-Based Digital Signature Standard')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('SLH-DSA-SHA2-128S', 'PQC', TRUE,
     '{"variant": "SLH-DSA-SHA2-128s", "security_level": 1,
       "pk_len_bytes": 32, "sk_len_bytes": 64, "sig_len_bytes": 7856,
       "uso": "Firma basada en hash — alternativa conservadora SLH-DSA sin lattices"}',
     'APPROVED',
     'NIST FIPS 205 (agosto 2024) — Stateless Hash-Based Digital Signature Standard')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

INSERT INTO bauth.auth_crypto_algorithm
    (code, type, is_pqc, default_params, status, nist_ref)
VALUES
    ('ML-KEM-1024', 'PQC', TRUE,
     '{"variant": "ML-KEM-1024", "security_level": 5,
       "pk_len_bytes": 1568, "sk_len_bytes": 3168,
       "ct_len_bytes": 1568, "shared_secret_len_bytes": 32,
       "uso": "Nivel máximo de seguridad post-cuántica para datos clasificados"}',
     'APPROVED',
     'NIST FIPS 203 (agosto 2024) — Module-Lattice-Based Key-Encapsulation Mechanism')

ON CONFLICT (code) DO UPDATE SET
    type = EXCLUDED.type, is_pqc = EXCLUDED.is_pqc,
    default_params = EXCLUDED.default_params, status = EXCLUDED.status,
    nist_ref = EXCLUDED.nist_ref, deprecated_at = EXCLUDED.deprecated_at;

COMMIT;

-- ── Verificación rápida post-insert ───────────────────────────
-- SELECT type, status, COUNT(*) AS n, is_pqc
-- FROM bauth.auth_crypto_algorithm
-- GROUP BY type, status, is_pqc ORDER BY type, status;
