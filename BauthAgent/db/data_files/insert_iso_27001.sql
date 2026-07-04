INSERT INTO bauth.framework_raw (source_name, content) VALUES (
  'iso_27001_2022',
  '{
    "iso_27001_2022_authentication_controls": {
      "transition_deadline": "2025-10-31",
      "annex_a_structure": {"domains": 4, "controls": 93, "previous_domains": 14, "previous_controls": 114},
      "key_controls": {
        "a_5_16": {
          "title": "Identity Management",
          "requirements": ["Full lifecycle management of human and non-human identities", "Unique identities linked to named individuals", "Documented provisioning, modification, de-provisioning processes"],
          "frequency": "continuous"
        },
        "a_5_17": {
          "title": "Authentication Information",
          "requirements": ["Formal management of passwords, tokens, keys, biometric data", "Secure issuance and storage with encryption", "TLS/HTTPS for credential transmission", "Rotation and revocation policies", "No shared credentials via spreadsheets or email"],
          "quarterly_reviews_required": true,
          "separation_of_duties": "No single person can create/approve and use/review privileged credentials",
          "immediate_revocation": "Upon exit, role change, or project closure",
          "rotation_schedules": {"privileged": "30 days", "service_accounts": "90 days", "user_passwords": "365 days"}
        },
        "a_5_18": {
          "title": "Access Rights",
          "requirements": ["Provisioning via formal process", "Quarterly reviews of privileged accounts", "Post-incident review of access rights"],
          "frequency": "quarterly for privileged, annually for standard"
        },
        "a_8_4": {
          "title": "Authentication Mechanisms",
          "requirements": ["Risk-based authentication appropriate to information sensitivity", "MFA determined by risk assessment", "Documented technology choice justification"],
          "mfa_not_explicitly_mandated": true,
          "risk_assessment_drives_mfa": true
        },
        "a_8_5": {
          "title": "Secure Authentication",
          "requirements": ["Secure authentication procedures based on access control policy", "MFA where technically feasible", "Lockout after failed attempts", "Session timeouts"],
          "lockout_threshold": "5-10 failed attempts",
          "session_timeout": "15 minutes idle, 8 hours absolute"
        }
      },
      "common_audit_findings": ["MFA deployed for remote but not on-premise", "Inconsistent MFA across systems", "No documented risk justification for MFA technology choice", "MFA recovery processes not formalized", "MFA logs not integrated into security event monitoring"],
      "new_controls_2022": ["A.5.7 Threat Intelligence", "A.5.23 Cloud Services", "A.5.30 ICT Readiness", "A.7.4 Physical Security Monitoring", "A.8.9 Configuration Management", "A.8.10 Information Deletion", "A.8.11 Data Masking", "A.8.12 Data Leakage Prevention", "A.8.16 Monitoring Activities", "A.8.23 Web Filtering", "A.8.28 Secure Coding"],
      "china_equivalent": "GB/T 22080-2025 (effective 2026-01-01)"
    }
  }'::jsonb
);
