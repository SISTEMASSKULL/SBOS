INSERT INTO bauth.framework_raw (source_name, content) VALUES (
  'nist_sp_800_63b_rev4',
  '{
    "password_policy_rev4": {
      "minimum_length": {
        "sole_authenticator": 15,
        "with_mfa": 8,
        "max_supported": 64,
        "standard_ref": "NIST SP 800-63B-4 §5.1.1.2"
      },
      "composition_rules": {
        "arbitrary_complexity": false,
        "require_uppercase": false,
        "require_numeric": false,
        "require_special": false,
        "allow_unicode": true,
        "allow_spaces": true,
        "standard_ref": "NIST SP 800-63B-4 §5.1.1.2"
      },
      "blocklist_screening": {
        "required": true,
        "sources": ["breached_passwords", "dictionary_words", "sequential_patterns", "context_specific_terms"],
        "context_terms": ["organization_name", "service_name", "username", "email"],
        "update_frequency": "daily",
        "standard_ref": "NIST SP 800-63B-4 §5.1.1.2"
      },
      "password_expiration": {
        "periodic_required": false,
        "change_on_compromise": true,
        "standard_ref": "NIST SP 800-63B-4 §5.1.1.2"
      },
      "mfa_requirements": {
        "aal1": {"mfa_required": false, "description": "Single-factor permitted for low-risk"},
        "aal2": {"mfa_required": true, "phishing_resistant_required": true, "synced_passkeys_allowed": true, "description": "Phishing-resistant MFA mandatory. Synced passkeys now AAL2-compliant"},
        "aal3": {"mfa_required": true, "phishing_resistant_required": true, "hardware_bound_required": true, "description": "Device-bound hardware key required. Non-exportable private keys"},
        "standard_ref": "NIST SP 800-63B-4 §5.2"
      },
      "risk_framework": {
        "model": "DIRM",
        "full_name": "Digital Identity Risk Management",
        "approach": "continuous_evaluation",
        "replaces": "checklist_compliance",
        "dynamic_ial_aal_fal": true,
        "standard_ref": "NIST SP 800-63-4"
      },
      "deepfake_controls": {
        "injection_attack_detection": true,
        "forged_media_protection": true,
        "presentation_attack_detection": true,
        "standard_ref": "NIST SP 800-63B-4"
      },
      "verifiable_credentials": {
        "subscriber_controlled_wallets": true,
        "mobile_drivers_license": true,
        "federation_model": "wallet_based",
        "standard_ref": "NIST SP 800-63C-4"
      },
      "implementation_date": "2025-07-01",
      "supersedes": "NIST SP 800-63B (2017, updated 2020)"
    }
  }'::jsonb
);
