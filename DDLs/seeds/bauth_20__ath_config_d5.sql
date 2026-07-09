-- =============================================================================
-- bauth_20__ath_config_d5.sql — Configuraciones operativas biométricas D5
-- =============================================================================
-- Propósito  : Poblar ath_config_d5 con configuraciones operativas de los
--              métodos biométricos de SBOS. Cada valor es trazable a una norma
--              o estándar publicado hasta 2026.
-- Normas     : ISO/IEC 19794-2:2011/AMD.1:2013 (huella - formato de intercambio)
--              ISO/IEC 19794-5:2011/AMD.1:2013 (rostro - formato de intercambio)
--              ISO/IEC 19794-6:2011/AMD.1:2013 (iris - formato de intercambio)
--              ISO/IEC 29794-1:2024  (calidad de muestras - framework general)
--              ISO/IEC 29794-4:2017  (calidad de huella dactilar)
--              ISO/IEC 29794-5:2010  (calidad de imagen facial)
--              ISO/IEC 29794-6:2015  (calidad de imagen de iris - 12 métricas)
--              ISO/IEC 30107-3:2023  (PAD - metodología de prueba anti-spoofing)
--              ISO/IEC 24745:2022    (protección de plantillas biométricas)
--              NIST SP 800-76-2      (especificaciones biométricas para PIV)
--              NIST IR 8382          (NFIQ2 - algoritmo de calidad de huella)
--              NIST SP 800-63B-4     (Ago 2024 - autenticación digital)
--              NIST SP 800-63A-4     (Sep 2024 - verificación de identidad)
--              NIST SP 800-88r2      (Sep 2025 - sanitización de medios)
--              OWASP Password Storage Cheat Sheet (2024) - Argon2id
--              GDPR Art.9 / Art.17 / RGPD UE 2016/679
-- Fase       : Reparación v3.0 — T2.4a
-- HITL       : Pendiente aprobación de Iván
-- Idempotente: Sí — TRUNCATE + INSERT explícito
-- =============================================================================
-- NOTA CORRECTIVA: La versión anterior hacía un SELECT dinámico desde
-- cfg_policy_library WHERE domain_map @> ARRAY['D5'], lo que insertaba 20 filas
-- de configuración FIDO2/WebAuthn que pertenecen a D9 (Credenciales), no a D5.
-- Este archivo reemplaza esa lógica con inserts explícitos de config biométrica.
-- El contenido FIDO2 debe migrarse a ath_config_d9 (ver T2.3 del plan de reparación).
-- =============================================================================
SET lock_timeout = '5s';
TRUNCATE TABLE bauth.ath_config_d5 RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.ath_config_d5;

INSERT INTO bauth.ath_config_d5 (config_key, config_value, description, standard_ref) VALUES

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. CAPTURA DE HUELLA DACTILAR
-- Fuente de cada valor:
--   500 DPI     → NIST SP 800-76-2 §3.1.1: requisito mínimo de resolución PIV
--   NFIQ2 ≥ 60  → NIST IR 8382 §4: score 0=sin utilidad, 100=máxima utilidad;
--                  60 es umbral operativo SBOS (norma no fija un valor mínimo,
--                  establece el algoritmo — umbral es decisión implementadora)
--   minutiae ≥ 12 → FBI EBTS §7.7: mínimo 12 puntos para matching AFIS
--   ISO_19794_2   → ISO/IEC 19794-2:2011 formato de intercambio de minutiae
-- ─────────────────────────────────────────────────────────────────────────────
(
  'fingerprint_capture',
  '{
    "sensor_types"          : ["capacitive", "optical", "ultrasonic"],
    "min_resolution_dpi"    : 500,
    "min_nfiq2_score"       : 60,
    "max_enroll_samples"    : 3,
    "template_format"       : "ISO_19794_2_2011",
    "minutiae_min"          : 12,
    "finger_index_default"  : ["right_index", "left_index"],
    "_sources": {
      "min_resolution_dpi"  : "NIST SP 800-76-2 §3.1.1",
      "min_nfiq2_score"     : "NIST IR 8382 §4 — umbral operativo SBOS",
      "minutiae_min"        : "FBI EBTS §7.7",
      "template_format"     : "ISO/IEC 19794-2:2011",
      "max_enroll_samples"  : "NIST SP 800-76-2 §3.1.3 — múltiples muestras enrollment"
    }
  }',
  'Captura de huella dactilar. Sensor ≥500 DPI (NIST SP 800-76-2). '
  'Calidad NFIQ2 ≥60/100 (NIST IR 8382). ≥12 minutiae (FBI EBTS §7.7). '
  'Template en formato ISO/IEC 19794-2:2011. '
  '3 muestras para enrolamiento (NIST SP 800-76-2 §3.1.3).',
  ARRAY[
    'NIST SP 800-76-2',
    'NIST IR 8382 (NFIQ2)',
    'ISO/IEC 19794-2:2011',
    'ISO/IEC 29794-4:2017'
  ]
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. RECONOCIMIENTO FACIAL 3D
-- Fuente de cada valor:
--   IED ≥ 90 px  → ISO/IEC 19794-5:2011 §6.3: inter-eye distance mínimo
--   ±5° pose     → ISO/IEC 19794-5:2011 §5.2: token frontal ≤ ±5° en roll/pitch
--   3D preferred → ISO/IEC 30107-3:2023: 3D resiste mejor ataques de presentación
--   deepfake     → ISO/IEC 30107-3:2023 §5.3: digital injection attacks (cat. PA-2)
-- NOTA: Para captura en tiempo real con sensores 3D, tolerancia ampliada a ±15°
--       es práctica de industria (no ISO 19794-5 token). Se documenta explícitamente.
-- ─────────────────────────────────────────────────────────────────────────────
(
  'face_recognition',
  '{
    "modalities"               : ["3d_structured_light", "3d_tof"],
    "min_interocular_distance_px": 90,
    "pose_tolerance_deg_iso_token": 5,
    "pose_tolerance_deg_3d_live"  : 15,
    "deepfake_detection"       : true,
    "template_format"          : "ISO_19794_5_2011",
    "quality_standard"         : "ISO_29794_5",
    "prefer_3d"                : true,
    "fallback_2d_nir_allowed"  : false,
    "_sources": {
      "min_interocular_distance_px": "ISO/IEC 19794-5:2011 §6.3 — IED min 90 px",
      "pose_tolerance_deg_iso_token": "ISO/IEC 19794-5:2011 §5.2 — ±5° token frontal",
      "pose_tolerance_deg_3d_live"  : "Práctica de industria 3D — no mandato ISO",
      "deepfake_detection"          : "ISO/IEC 30107-3:2023 §5.3 — PA-2 digital injection",
      "template_format"             : "ISO/IEC 19794-5:2011"
    }
  }',
  'Reconocimiento facial 3D. IED mínimo 90 px (ISO/IEC 19794-5 §6.3). '
  'Token frontal ISO: ±5°. Captura 3D en vivo: tolerancia ±15°. '
  'Detección deepfake obligatoria (ISO 30107-3:2023 §5.3 ataques PA-2). '
  '2D sin NIR no habilitado como método primario. '
  'Template: ISO/IEC 19794-5:2011.',
  ARRAY[
    'ISO/IEC 19794-5:2011',
    'ISO/IEC 29794-5:2010',
    'ISO/IEC 30107-3:2023'
  ]
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. RECONOCIMIENTO DE IRIS
-- Fuente de cada valor:
--   NIR 850 nm   → ISO/IEC 19794-6:2011 §5.1: iluminación 700–900 nm banda NIR
--   pupil_iris   → ISO/IEC 29794-6:2015 métrica PUPIL_IRIS_RATIO: rango 0.2–0.7
--                  (valores fuera de rango indican pupila dilatada/contraída en exceso)
--   resolution   → ISO/IEC 19794-6:2011 §6.2: resolución mínima 2 lp/mm al 60% contraste
-- ─────────────────────────────────────────────────────────────────────────────
(
  'iris_recognition',
  '{
    "camera_spectrum"      : "nir_850nm",
    "spectral_range_nm"    : {"min": 700, "max": 900},
    "pupil_iris_ratio"     : {"min": 0.2, "max": 0.7},
    "min_resolution_lpmm"  : 2,
    "contrast_pct"         : 60,
    "template_format"      : "ISO_19794_6_2011",
    "quality_standard"     : "ISO_29794_6",
    "glasses_allowed"      : false,
    "contact_lens_flag"    : "warn_and_log",
    "_sources": {
      "camera_spectrum"    : "ISO/IEC 19794-6:2011 §5.1 — 700-900 nm NIR",
      "pupil_iris_ratio"   : "ISO/IEC 29794-6:2015 métrica PUPIL_IRIS_RATIO",
      "min_resolution_lpmm": "ISO/IEC 19794-6:2011 §6.2 — 2 lp/mm al 60% contraste",
      "template_format"    : "ISO/IEC 19794-6:2011"
    }
  }',
  'Reconocimiento de iris con cámara NIR 700–900 nm (ISO/IEC 19794-6 §5.1). '
  'PUPIL_IRIS_RATIO entre 0.2–0.7 (ISO/IEC 29794-6 métrica Q3). '
  'Resolución mínima 2 lp/mm al 60% contraste (ISO/IEC 19794-6 §6.2). '
  'Template: ISO/IEC 19794-6:2011.',
  ARRAY[
    'ISO/IEC 19794-6:2011',
    'ISO/IEC 29794-6:2015'
  ]
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. VERIFICACIÓN DE VOZ
-- Fuente de cada valor:
--   ISO_19794_13 → ISO/IEC 19794-13:2018 formato de intercambio de datos de voz
--   MFCC_39      → práctica de industria GMM-UBM (13 static + 13 delta + 13 Δ²);
--                  no mandato ISO, sino consenso técnico ETSI STQ WG2
--   SNR ≥ 20 dB  → ITU-T P.563 §4: SNR mínimo para buena calidad de habla
--   max_aal AAL2 → decisión SBOS: voz es susceptible a replay sin hardware bound;
--                  NIST SP 800-63B-4 §5.2 no certifica voz como AAL3
-- ─────────────────────────────────────────────────────────────────────────────
(
  'voice_verification',
  '{
    "sample_min_seconds"   : 3,
    "sample_max_seconds"   : 10,
    "feature_extraction"   : "MFCC_39",
    "channel"              : "telephony_narrowband_g711",
    "min_snr_db"           : 20,
    "template_format"      : "ISO_19794_13",
    "max_aal"              : "AAL2",
    "use_as_primary"       : false,
    "use_as_secondary"     : true,
    "_sources": {
      "feature_extraction" : "ETSI STQ WG2 — práctica GMM-UBM 13+13+13 MFCC",
      "min_snr_db"         : "ITU-T P.563 §4 — SNR mínimo calidad de habla",
      "template_format"    : "ISO/IEC 19794-13:2018",
      "max_aal"            : "SBOS-decisión: NIST SP 800-63B-4 §5.2 no certifica voz AAL3"
    }
  }',
  'Verificación de voz. SNR ≥20 dB (ITU-T P.563 §4). '
  'MFCC-39 extracción de características (práctica ETSI STQ WG2). '
  'Solo como factor secundario — máximo AAL2 (SBOS-decisión basada en NIST SP 800-63B-4 §5.2). '
  'No certificable AAL3 por vulnerabilidad a replay sin hardware vinculado.',
  ARRAY[
    'ISO/IEC 19794-13:2018',
    'NIST SP 800-63B-4 §5.2',
    'ITU-T P.563'
  ]
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. ALMACENAMIENTO DE PLANTILLAS BIOMÉTRICAS
-- Fuente de cada valor:
--   hash_only    → ISO/IEC 24745:2022 §6.2: never store raw biometric
--   Argon2id     → OWASP Password Storage 2024: Argon2id es el recomendado
--   t=3,m=65536  → OWASP 2024 perfil recomendado: m=64 MiB, t=3, p=1 (mínimo)
--   p=2          → más conservador que OWASP (p=1 mínimo). SBOS-decisión.
--   salt=16 bytes→ OWASP: mínimo 128 bits = 16 bytes de sal aleatoria
--   AES-256-GCM  → NIST SP 800-38D: modo GCM autenticado para cifrado en reposo
--   crypto_erase → NIST SP 800-88r2 §2.5 (Sep 2025): Purge via crypto-erase para
--                  SSD/NVMe. Multi-pass overwrite NO válido (wear-leveling hace
--                  inaccesibles las celdas de over-provisioning). Ver r2 §2.5 tabla A-1.
-- ─────────────────────────────────────────────────────────────────────────────
(
  'template_storage',
  '{
    "store_raw_biometric"  : false,
    "store_template"       : false,
    "store_hash_only"      : true,
    "hash_algorithm"       : "Argon2id",
    "argon2_time_cost"     : 3,
    "argon2_memory_kb"     : 65536,
    "argon2_parallelism"   : 2,
    "argon2_salt_bytes"    : 16,
    "argon2_hash_bytes"    : 32,
    "encryption_at_rest"   : "AES-256-GCM",
    "key_vault_path"       : "bauth/biometric/template-key",
    "deletion_method"      : "cryptographic_erasure",
    "_sources": {
      "store_hash_only"    : "ISO/IEC 24745:2022 §6.2 — never store raw biometric",
      "hash_algorithm"     : "OWASP Password Storage Cheat Sheet 2024",
      "argon2_time_cost"   : "OWASP 2024 — t=3 perfil recomendado",
      "argon2_memory_kb"   : "OWASP 2024 — m=64 MiB (65536 KiB) perfil recomendado",
      "argon2_parallelism" : "SBOS-decisión — p=2 > p=1 mínimo OWASP",
      "argon2_salt_bytes"  : "OWASP — mínimo 16 bytes (128 bits)",
      "encryption_at_rest" : "NIST SP 800-38D — GCM autenticado",
      "deletion_method"    : "NIST SP 800-88r2 §2.5 — crypto-erase para SSD/NVMe"
    }
  }',
  'Solo se almacena el hash Argon2id de la plantilla — nunca la biométrica cruda '
  '(ISO/IEC 24745:2022 §6.2). '
  'Argon2id: t=3, m=64 MiB, p=2, sal=16 bytes, hash=32 bytes (OWASP 2024). '
  'Cifrado adicional AES-256-GCM en reposo (NIST SP 800-38D). '
  'Borrado: crypto-erase (NIST SP 800-88r2 §2.5 — único método válido para SSD/NVMe).',
  ARRAY[
    'ISO/IEC 24745:2022',
    'OWASP Password Storage Cheat Sheet 2024',
    'NIST SP 800-38D',
    'NIST SP 800-88r2'
  ]
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. DETECCIÓN DE VIDA (ANTI-SPOOFING / PAD)
-- Fuente de cada valor:
--   ISO 30107-3  → Define APCER y BPCER como métricas PAD (§7.1)
--   PAD Level 2  → iBeta PAD testing (ISO 30107-3 metodología):
--                  Level 1: APCER ≤ 20%, Level 2: APCER ≤ 15%
--   APCER ≤ 1%   → UMBRAL DE DESPLIEGUE SBOS — más estricto que Level 2 iBeta
--   BPCER ≤ 5%   → UMBRAL DE DESPLIEGUE SBOS — igual al Level 2 iBeta
--   Liveness pasiva → ISO 30107-3:2023 §5.2 recomienda PAD sin desafío activo
-- ─────────────────────────────────────────────────────────────────────────────
(
  'liveness_detection',
  '{
    "pad_level_iso_reference"  : 2,
    "pad_level_sbos_deployment": "stricter_than_ibeta_level_2",
    "passive_liveness_enabled" : true,
    "active_liveness_enabled"  : false,
    "attack_types_covered"     : [
      "print_attack",
      "replay_attack",
      "3d_mask",
      "digital_injection_deepfake"
    ],
    "max_apcer_operational"    : 0.01,
    "max_bpcer_operational"    : 0.05,
    "ibeta_level2_apcer_ref"   : 0.15,
    "fail_action"              : "DENY_AND_ALERT_SIEM",
    "_sources": {
      "pad_level"              : "ISO/IEC 30107-3:2023 — Level 2 iBeta",
      "max_apcer_operational"  : "SBOS-decisión — más estricto que Level 2 (≤15%)",
      "max_bpcer_operational"  : "SBOS-decisión — igual a Level 2 iBeta",
      "attack_types"           : "ISO/IEC 30107-3:2023 §5.3 categorías PA-1..PA-4",
      "passive_liveness"       : "ISO/IEC 30107-3:2023 §5.2"
    }
  }',
  'Detección de vida anti-spoofing ISO 30107-3:2023. PAD Level 2 (referencia iBeta). '
  'APCER operacional ≤1% (más estricto que certificación Level 2 iBeta: ≤15%). '
  'BPCER operacional ≤5%. Liveness pasiva (sin desafío activo). '
  'Tipos de ataque: print, replay, 3D mask, deepfake/digital injection. '
  'Nota: APCER/BPCER son umbrales de despliegue SBOS, ISO 30107-3 define las métricas '
  'y metodología de prueba pero no fija valores de despliegue.',
  ARRAY[
    'ISO/IEC 30107-3:2023',
    'ISO/IEC 30107-1:2016'
  ]
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. CALIDAD MÍNIMA DE MUESTRA
-- Fuente de cada valor:
--   NFIQ2 ≥ 60   → NIST IR 8382 (NFIQ2): algoritmo oficial NIST, escala 0-100.
--                  Umbral 60 = decisión SBOS (NIST no fija un umbral universal).
--   face/iris    → ISO/IEC 29794-1:2024 framework general; las partes 5 y 6
--                  definen métricas pero no fijan umbrales numéricos universales.
--                  Los valores 70/65 son SBOS-decisión dentro del framework.
--   SNR ≥ 20 dB  → ITU-T P.563 §4 (calidad de habla).
-- ─────────────────────────────────────────────────────────────────────────────
(
  'quality_threshold',
  '{
    "fingerprint_nfiq2_min"   : 60,
    "face_quality_min_sbos"   : 70,
    "iris_quality_min_sbos"   : 65,
    "voice_snr_min_db"        : 20,
    "max_retries_on_low_q"    : 3,
    "low_quality_action"      : "RETRY_WITH_GUIDANCE",
    "fail_action_after_max"   : "DENY_AND_LOG",
    "_sources": {
      "fingerprint_nfiq2_min" : "NIST IR 8382 — algoritmo NFIQ2; umbral 60 = SBOS-decisión",
      "face_quality_min_sbos" : "ISO/IEC 29794-5:2010 framework — umbral 70 = SBOS-decisión",
      "iris_quality_min_sbos" : "ISO/IEC 29794-6:2015 framework — umbral 65 = SBOS-decisión",
      "voice_snr_min_db"      : "ITU-T P.563 §4",
      "max_retries"           : "ISO/IEC 29794-1:2024 §7 — reintentos permitidos"
    }
  }',
  'Umbrales de calidad de muestra biométrica. '
  'Huella NFIQ2 ≥60 (NIST IR 8382 algoritmo; umbral es decisión SBOS). '
  'Rostro ≥70, Iris ≥65 (ISO/IEC 29794 framework; valores son decisión SBOS). '
  'Voz SNR ≥20 dB (ITU-T P.563). '
  'Máximo 3 reintentos por muestra de baja calidad.',
  ARRAY[
    'NIST IR 8382 (NFIQ2)',
    'ISO/IEC 29794-1:2024',
    'ISO/IEC 29794-4:2017',
    'ISO/IEC 29794-5:2010',
    'ISO/IEC 29794-6:2015',
    'ITU-T P.563'
  ]
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. PROCESO DE ENROLAMIENTO
-- Fuente de cada valor:
--   min_samples_fp:3   → NIST SP 800-76-2 §3.1.3: ≥3 capturas para enrollment
--   min_samples_face:5 → práctica de industria 3D (no mandato ISO) — SBOS-decisión
--   min_samples_iris:2 → práctica (1 por ojo) — SBOS-decisión
--   supervisor,ial=2   → NIST SP 800-63A-4 §4.4.1: IAL2 requiere presencia supervisada
--   consent            → GDPR Art.9(2)(a): consentimiento explícito para biométrico
-- ─────────────────────────────────────────────────────────────────────────────
(
  'enrollment_process',
  '{
    "min_samples_fingerprint"  : 3,
    "min_samples_face"         : 5,
    "min_samples_iris"         : 2,
    "supervisor_required"      : true,
    "ial_minimum"              : 2,
    "enrollment_ttl_minutes"   : 30,
    "max_concurrent_sessions"  : 1,
    "user_consent_required"    : true,
    "consent_revocable"        : true,
    "approval_mode"            : "hybrid",
    "_sources": {
      "min_samples_fingerprint": "NIST SP 800-76-2 §3.1.3 — ≥3 muestras enrollment",
      "min_samples_face"       : "SBOS-decisión — práctica industria 3D",
      "min_samples_iris"       : "SBOS-decisión — 1 por ojo mínimo",
      "supervisor_required"    : "NIST SP 800-63A-4 §4.4.1 — IAL2 presencia supervisada",
      "ial_minimum"            : "NIST SP 800-63A-4 §4.4 — Identity Assurance Level 2",
      "user_consent_required"  : "GDPR Art.9(2)(a) — consentimiento explícito biométrico"
    }
  }',
  'Proceso de enrolamiento biométrico. '
  'Huella: 3 muestras (NIST SP 800-76-2 §3.1.3). '
  'Supervisor obligatorio (IAL2 — NIST SP 800-63A-4 §4.4.1). '
  'Consentimiento explícito y revocable (GDPR Art.9(2)(a)). '
  'Sesión de enrolamiento: máximo 30 minutos.',
  ARRAY[
    'NIST SP 800-76-2',
    'NIST SP 800-63A-4',
    'GDPR Art.9',
    'ISO/IEC 30107-3:2023'
  ]
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. PARÁMETROS GLOBALES DEL SUBSISTEMA BIOMÉTRICO
-- Fuente de cada valor:
--   enabled_methods      → decisión SBOS (voice deshabilitada por riesgo AAL)
--   revocation_seconds   → SBOS-SLA (no mandato ISO; basado en NIST SP 800-53 AC-2(2))
--   audit_events         → ISO 27001:2022 A.8.15: registrar eventos de acceso
--   data_residency       → SBOS-soberanía + GDPR Art.44-46 (no transferencia fuera UE)
-- ─────────────────────────────────────────────────────────────────────────────
(
  'biometric_system',
  '{
    "enabled_methods"           : ["FINGERPRINT", "FACE_3D", "IRIS"],
    "disabled_methods"          : ["VOICE"],
    "max_enrolled_per_user"     : 3,
    "revocation_max_seconds"    : 30,
    "audit_biometric_events"    : true,
    "cross_tenant_share"        : false,
    "data_residency"            : "tenant_server_only",
    "external_service_allowed"  : false,
    "compliance_frameworks"     : [
      "ISO_27001_2022_A8_22",
      "GDPR_Art9",
      "NIST_SP_800_63B4",
      "ISO_IEC_24745_2022"
    ],
    "_sources": {
      "enabled_methods"         : "SBOS-decisión: voz deshabilitada por riesgo replay",
      "revocation_max_seconds"  : "SBOS-SLA — NIST SP 800-53 AC-2(2) provee base",
      "audit_biometric_events"  : "ISO 27001:2022 A.8.15 — registro de eventos de acceso",
      "data_residency"          : "SBOS-soberanía + GDPR Art.44 — sin transferencia internacional"
    }
  }',
  'Parámetros globales del subsistema biométrico SBOS. '
  'Métodos habilitados: huella, rostro 3D, iris (voz deshabilitada). '
  'Revocación en <30 s (SBOS-SLA). '
  'Auditoría de eventos biométricos (ISO 27001:2022 A.8.15). '
  'Datos exclusivamente en servidor del tenant — soberanía total (GDPR Art.44).',
  ARRAY[
    'ISO 27001:2022 A.8.22',
    'ISO/IEC 24745:2022',
    'GDPR Art.9',
    'GDPR Art.44',
    'NIST SP 800-63B-4 §5.2'
  ]
);

-- Verificación: debe retornar 9 filas
SELECT COUNT(*) AS total_configs_d5,
       string_agg(config_key, E'\n  ' ORDER BY config_key) AS claves
FROM bauth.ath_config_d5;
