-- =============================================================================
-- bauth_32__ath_policy_d5.sql — Políticas de acceso biométrico D5 (10 políticas)
-- =============================================================================
-- Propósito  : Poblar ath_policy_d5 con las reglas de control de acceso y
--              compliance del dominio biométrico. Cada valor trazable a norma.
-- Normas     : ISO/IEC 30107-3:2023  (PAD — anti-spoofing)
--              ISO/IEC 24745:2022    (protección de plantillas biométricas)
--              ISO/IEC 29794-1:2024  (calidad de muestras biométricas)
--              ISO/IEC 19792:2009    (evaluación de seguridad de sistemas bio.)
--              NIST SP 800-63B-4     (Ago 2024) §5.2.3 — biometric authenticators
--              NIST SP 800-63A-4     (Sep 2024) §4.4   — IAL2 enrollment
--              NIST SP 800-53 Rev.5  AC-2, AC-12, AU-9
--              GDPR Art.9, Art.17    — datos especiales / derecho de supresión
--              ISO 27001:2022 A.8.10 — borrado de información
--              ISO 27701:2019        — privacidad de la información
-- Fase       : Reparación v3.0 — T2.4b (enriquecimiento: 5 originales + 5 nuevas)
-- HITL       : Pendiente aprobación de Iván
-- Idempotente: Sí — TRUNCATE + INSERT completo con todas las 10 políticas
--
-- ARQUITECTURA D5 vs D2:
--   D5 = estándares de LA biometría misma (FMR, liveness, GDPR, calidad, plantilla)
--   D2 = proceso de acceso físico que USA biometría
--   Por eso BIOMETRIC_ENROLLMENT_HYBRID vive en ath_policy_d2 — es un proceso
--   de acceso físico en un checkpoint. Esta separación es intencional.
-- =============================================================================
SET lock_timeout = '5s';
TRUNCATE TABLE bauth.ath_policy_d5 RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.ath_policy_d5;

INSERT INTO bauth.ath_policy_d5 (policy_code, policy_name, description, standard_ref, config) VALUES

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Liveness pasiva obligatoria
-- Fuente: ISO/IEC 30107-3:2023 §5.2 — passive detection sin desafío activo
--         iBeta PAD Level 2 certification methodology
-- ─────────────────────────────────────────────────────────────────────────────
(
  'BIOMETRIC_LIVENESS_PASSIVE',
  'Liveness pasiva obligatoria',
  'Verificación de vida sin desafío activo. '
  'Anti-spoofing ISO 30107-3:2023 obligatorio para todos los métodos biométricos en SBOS. '
  'Applies to AAL2 y AAL3. Ataque detectado: DENY + alerta SIEM.',
  ARRAY['ISO/IEC 30107-3:2023', 'NIST SP 800-63B-4 §5.2.3'],
  '{
    "rule"               : "liveness_required",
    "method"             : "passive",
    "ibeta_pad_level_ref": 2,
    "applies_to_aal"     : ["AAL2", "AAL3"],
    "fail_action"        : "DENY_AND_ALERT_SIEM",
    "_source_pad_level"  : "ISO/IEC 30107-3:2023 metodología iBeta Level 2"
  }'
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. FMR máximo — LoA 2
-- Fuente: NIST SP 800-63B-4 §5.2.3 (Aug 2024):
--   "The biometric system SHALL have a False Match Rate (FMR) of 1:10,000 or better"
--   para Authentication Assurance Level 2.
--   FNMR <5% → mismo párrafo §5.2.3.
-- ─────────────────────────────────────────────────────────────────────────────
(
  'BIOMETRIC_FMR_1_10000',
  'FMR 1:10,000 — AAL2',
  'False Match Rate máximo 1:10,000 para Authentication Assurance Level 2. '
  'Requisito textual de NIST SP 800-63B-4 §5.2.3 (agosto 2024). '
  'FNMR (False Non-Match Rate) máximo 5% en el mismo estándar.',
  ARRAY['NIST SP 800-63B-4 §5.2.3'],
  '{
    "rule"          : "fmr_threshold",
    "fmr_max"       : "1:10000",
    "fnmr_max_pct"  : 5,
    "applies_to_aal": "AAL2",
    "_source"       : "NIST SP 800-63B-4 §5.2.3 (Aug 2024) — cita textual"
  }'
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. FMR máximo — LoA 3
-- Fuente: NIST SP 800-63B-4 §5.2.3 (Aug 2024):
--   "biometric system's FMR SHALL be 1 in 100,000 or better" para AAL3.
-- ─────────────────────────────────────────────────────────────────────────────
(
  'BIOMETRIC_FMR_1_100000',
  'FMR 1:100,000 — AAL3',
  'False Match Rate máximo 1:100,000 para Authentication Assurance Level 3. '
  'Requisito textual de NIST SP 800-63B-4 §5.2.3 (agosto 2024). '
  'Obligatorio para bóvedas, servidores, data centers. '
  'Debe combinarse con Two-Person Rule (ath_policy_d2) en zonas críticas.',
  ARRAY['NIST SP 800-63B-4 §5.2.3', 'IEC 60839-11-5'],
  '{
    "rule"          : "fmr_threshold",
    "fmr_max"       : "1:100000",
    "fnmr_max_pct"  : 10,
    "applies_to_aal": "AAL3",
    "_source"       : "NIST SP 800-63B-4 §5.2.3 (Aug 2024) — cita textual"
  }'
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Consentimiento GDPR para datos biométricos
-- Fuente: GDPR Art.9(1): datos biométricos = categoría especial
--         GDPR Art.9(2)(a): excepción por consentimiento explícito
--         GDPR Art.17(1)(b): derecho de supresión al retirar consentimiento
--         ISO 27701:2019 §8.4: privacidad en tratamiento de datos especiales
-- ─────────────────────────────────────────────────────────────────────────────
(
  'BIOMETRIC_GDPR_CONSENT',
  'Consentimiento explícito GDPR Art.9 para biométricos',
  'Datos biométricos son categoría especial GDPR Art.9(1). '
  'Solo tratables con consentimiento explícito Art.9(2)(a). '
  'El titular puede retirar el consentimiento → derecho de supresión Art.17(1)(b). '
  'Propósito único: control de acceso (no perfilado, no inferencia de salud/raza). '
  'Almacenamiento: solo hash Argon2id (ISO/IEC 24745:2022 §6.2).',
  ARRAY['GDPR Art.9', 'GDPR Art.17', 'ISO 27701:2019', 'ISO/IEC 24745:2022'],
  '{
    "rule"                  : "gdpr_consent",
    "data_category"         : "GDPR_Art9_special",
    "legal_basis"           : "explicit_consent_Art9_2_a",
    "requires_explicit"     : true,
    "revocable"             : true,
    "purpose_limitation"    : "ACCESS_CONTROL_ONLY",
    "no_profiling"          : true,
    "storage_format"        : "Argon2id_hash_only",
    "_source_consent"       : "GDPR Art.9(2)(a)",
    "_source_storage"       : "ISO/IEC 24745:2022 §6.2"
  }'
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Alternativa no biométrica obligatoria
-- Fuente: NIST SP 800-63B-4 §5.2.3 (Aug 2024):
--   "Biometric SHALL be used with another authentication factor"
--   "A fallback authenticator SHALL be available"
-- ─────────────────────────────────────────────────────────────────────────────
(
  'BIOMETRIC_ALTERNATIVE_REQUIRED',
  'Alternativa no biométrica obligatoria — NIST §5.2.3',
  'NIST SP 800-63B-4 §5.2.3: siempre debe existir un método alternativo '
  'no biométrico disponible. En SBOS: QR dinámico de un solo uso (OTP). '
  'Máximo 5 usos de alternativa por día antes de disparar revisión de acceso. '
  'La biometría nunca es el ÚNICO factor — siempre se usa con otro.',
  ARRAY['NIST SP 800-63B-4 §5.2.3', 'NIST SP 800-63A-4 §5.1'],
  '{
    "rule"              : "fallback_required",
    "fallback_method"   : "QR_DYNAMIC_OTP",
    "fallback_aal_max"  : "AAL2",
    "max_uses_per_day"  : 5,
    "alert_at_use"      : 3,
    "_source"           : "NIST SP 800-63B-4 §5.2.3 — fallback authenticator SHALL be available"
  }'
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Multi-biométrico opcional para AAL3 reforzado
-- Fuente: NIST SP 800-63B-4 §5.2.3: permite múltiples biométricos como
--         factores adicionales dentro de un FIDO2/hardware-bound authenticator.
--         ISO/IEC 30107-3:2023 §4.3: fusión de múltiples biométricos.
-- ─────────────────────────────────────────────────────────────────────────────
(
  'BIOMETRIC_MULTIMODAL_OPTIONAL',
  'Multi-biométrico opcional — AAL3 reforzado',
  'Combinación de dos biométricos (huella + rostro 3D) para escenarios AAL3 reforzado. '
  'No obligatorio a menos que el rol tenga require_multimodal=true. '
  'Fusión en modo AND: ambos biométricos deben superar sus umbrales FMR. '
  'NIST SP 800-63B-4 §5.2.3 permite múltiples biométricos dentro de hardware-bound auth.',
  ARRAY['NIST SP 800-63B-4 §5.2.3', 'ISO/IEC 30107-3:2023 §4.3', 'NIST SP 800-53 AC-3'],
  '{
    "rule"                  : "multimodal_biometric",
    "required_factors"      : 2,
    "allowed_combinations"  : [
      ["FINGERPRINT", "FACE_3D"],
      ["FINGERPRINT", "IRIS"],
      ["FACE_3D", "IRIS"]
    ],
    "fusion_strategy"       : "AND",
    "role_flag_activator"   : "require_multimodal",
    "min_aal_to_activate"   : 3,
    "_source_fusion"        : "ISO/IEC 30107-3:2023 §4.3",
    "_source_nist"          : "NIST SP 800-63B-4 §5.2.3"
  }'
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. Revocación de plantilla biométrica en < 30 s
-- Fuente: NIST SP 800-53 Rev.5 AC-2(2): "organization employs automated mechanisms
--         to support the management of information system accounts"
--         ISO/IEC 24745:2022 §7.4: biometric template deactivation on withdrawal
--         SBOS-SLA: 30 s (más estricto que mandato ISO)
-- ─────────────────────────────────────────────────────────────────────────────
(
  'BIOMETRIC_TEMPLATE_REVOCATION',
  'Revocación de plantilla en < 30 s',
  'Al desvincularse un usuario, su plantilla biométrica se marca REVOKED en ≤30 s. '
  'La plantilla no se borra físicamente hasta el período de retención GDPR/ISO, '
  'pero no puede ser comparada con ninguna muestra nueva. '
  'Propagación a todos los readers físicos D2 en el mismo SLA. '
  'ISO/IEC 24745:2022 §7.4: biometric template deactivation on consent withdrawal.',
  ARRAY['ISO/IEC 24745:2022', 'NIST SP 800-53 Rev.5 AC-2(2)', 'GDPR Art.17'],
  '{
    "rule"                     : "template_revocation",
    "max_revocation_seconds"   : 30,
    "propagate_to_d2_readers"  : true,
    "state_on_revoke"          : "REVOKED_NOT_DELETED",
    "physical_deletion_days"   : 30,
    "audit_revocation_event"   : true,
    "revocation_reason_codes"  : [
      "OFFBOARDING",
      "CONSENT_WITHDRAWN",
      "SECURITY_INCIDENT",
      "USER_REQUEST"
    ],
    "_source_deactivation"     : "ISO/IEC 24745:2022 §7.4",
    "_source_sbos_sla"         : "SBOS-SLA 30s — más estricto que AC-2(2) NIST"
  }'
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. Calidad mínima de muestra — ISO/IEC 29794
-- Fuente: ISO/IEC 29794-1:2024 §7 framework general de calidad
--         NIST IR 8382 NFIQ2: score 0-100 (0=sin utilidad, 100=máxima utilidad)
--         Umbrales numéricos son decisión SBOS dentro del framework ISO
-- ─────────────────────────────────────────────────────────────────────────────
(
  'BIOMETRIC_QUALITY_MINIMUM',
  'Calidad mínima de muestra — ISO/IEC 29794',
  'Muestras con calidad inferior al umbral son rechazadas durante enrolamiento '
  'y verificación. 3 reintentos antes de denegar. '
  'Algoritmo NFIQ2 para huella (NIST IR 8382). '
  'Nota: umbrales para rostro e iris son decisión SBOS dentro del framework '
  'ISO/IEC 29794; la norma define métricas pero no fija valores universales.',
  ARRAY['ISO/IEC 29794-1:2024', 'NIST IR 8382 (NFIQ2)', 'ISO/IEC 29794-4:2017'],
  '{
    "rule"                          : "quality_minimum",
    "fingerprint_nfiq2_min"         : 60,
    "face_quality_min_sbos"         : 70,
    "iris_quality_min_sbos"         : 65,
    "voice_snr_min_db"              : 20,
    "max_retries"                   : 3,
    "reject_action"                 : "RETRY_WITH_GUIDANCE",
    "fail_after_max_retries"        : "DENY_ENROLLMENT",
    "_source_fingerprint"           : "NIST IR 8382 — umbral 60 = decisión SBOS",
    "_source_face_iris"             : "ISO/IEC 29794 framework — umbrales son SBOS-decisión",
    "_source_voice"                 : "ITU-T P.563 §4"
  }'
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. PAD nivel 2 obligatorio para AAL3
-- Fuente: ISO/IEC 30107-3:2023 §7: PAD Level 2 metodología iBeta
--         NIST SP 800-63B-4 §5.2.3: "biometric system SHALL implement PAD"
--         APCER ≤1%: umbral SBOS de despliegue (más estricto que iBeta Level 2: ≤15%)
-- ─────────────────────────────────────────────────────────────────────────────
(
  'BIOMETRIC_SPOOFING_MANDATORY_AAL3',
  'PAD obligatorio Level 2 — AAL3',
  'Para zonas AAL3 (bóvedas, servidores, data centers) la detección PAD es obligatoria. '
  'Referencia ISO 30107-3:2023 Level 2 (metodología iBeta: APCER ≤15%). '
  'Umbral de despliegue SBOS más estricto: APCER ≤1%, BPCER ≤5%. '
  'Ataques cubiertos: print, replay, 3D mask, deepfake/digital injection. '
  'Detección de ataque: DENY + cierre de sesión activa + alerta SIEM.',
  ARRAY['ISO/IEC 30107-3:2023', 'NIST SP 800-63B-4 §5.2.3'],
  '{
    "rule"                         : "pad_mandatory",
    "ibeta_level_reference"        : 2,
    "ibeta_level2_apcer_threshold" : 0.15,
    "sbos_apcer_operational"       : 0.01,
    "sbos_bpcer_operational"       : 0.05,
    "applies_to_aal"               : "AAL3",
    "attack_categories"            : [
      "print_attack",
      "replay_attack",
      "3d_mask",
      "digital_injection_deepfake"
    ],
    "fail_action"                  : "DENY_REVOKE_SESSION_ALERT_SIEM",
    "_source_pad_level"            : "ISO/IEC 30107-3:2023 §7 — iBeta Level 2",
    "_source_nist"                 : "NIST SP 800-63B-4 §5.2.3 — PAD SHALL be implemented",
    "_note_thresholds"             : "APCER/BPCER son umbrales de despliegue SBOS, más estrictos que certificación"
  }'
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. Retención limitada de datos biométricos
-- Fuente: GDPR Art.5(1)(e): limitación del plazo de conservación
--         GDPR Art.17(1)(b): supresión al retirar consentimiento
--         GDPR Art.17(1)(a): supresión cuando datos ya no necesarios
--         Respuesta: "without undue delay" = práctica europea ≤ 30 días (Art.17)
--         Nota: 72 horas es Art.33 GDPR (notificación de brecha), NO Art.17
--         ISO 27001:2022 A.8.10: gestión del borrado de información
--         NIST SP 800-88r2 §2.5: crypto-erase para SSD/NVMe (Sep 2025)
-- ─────────────────────────────────────────────────────────────────────────────
(
  'BIOMETRIC_RETENTION_LIMIT',
  'Retención y borrado de datos biométricos — GDPR Art.5/17',
  'Los datos biométricos (hash de plantilla) se retienen máximo 365 días desde '
  'el último uso activo (GDPR Art.5(1)(e) — limitación del plazo de conservación). '
  'Solicitud de supresión por el usuario → respuesta ≤30 días (GDPR Art.17 — '
  '"without undue delay" = práctica europea 1 mes). '
  'NOTA: 72 horas es GDPR Art.33 (notificación de brecha a DPA), NO el plazo del Art.17. '
  'Método de borrado: crypto-erasure (NIST SP 800-88r2 §2.5 — único válido para SSD). '
  'Propósito: exclusivamente control de acceso.',
  ARRAY['GDPR Art.5', 'GDPR Art.17', 'ISO 27001:2022 A.8.10', 'NIST SP 800-88r2'],
  '{
    "rule"                           : "retention_limit",
    "max_retention_days"             : 365,
    "inactivity_trigger_days"        : 365,
    "user_deletion_response_days"    : 30,
    "auto_delete_on_expiry"          : true,
    "purpose_limitation"             : "ACCESS_CONTROL_ONLY",
    "no_profiling"                   : true,
    "audit_deletion"                 : true,
    "deletion_method"                : "cryptographic_erasure",
    "_source_retention"              : "GDPR Art.5(1)(e) — limitación del plazo",
    "_source_user_deletion"          : "GDPR Art.17 — without undue delay = 30 días práctica UE",
    "_note_72h_error"                : "72h es GDPR Art.33 brecha, NO Art.17 supresión",
    "_source_deletion_method"        : "NIST SP 800-88r2 §2.5 — crypto-erase para SSD/NVMe"
  }'
);

-- Verificación: debe retornar 10 filas
SELECT COUNT(*) AS total_politicas_d5,
       string_agg(policy_code, E'\n  ' ORDER BY policy_code) AS codigos
FROM bauth.ath_policy_d5;
