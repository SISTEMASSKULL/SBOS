INSERT INTO bauth.framework_raw (source_name, content) VALUES (
  'zero_trust_nsa_2026',
  '{
    "zero_trust_architecture_2026": {
      "foundation": "NIST SP 800-207",
      "supplemented_by": ["NIST SP 1800-35 (June 2025)", "NIST SP 800-207A"],
      "nsa_zigs_2026": {
        "date": "2026-01",
        "total_activities": 77,
        "total_capabilities": 64,
        "phases": {
          "discovery": {"activities": 14, "capabilities": 13, "focus": "visibility, baselines, asset inventory"},
          "phase_one": {"activities": 36, "capabilities": 30, "focus": "identity foundation, device posture, segmentation"},
          "phase_two": {"activities": 41, "capabilities": 34, "focus": "advanced integration, analytics, automation"}
        },
        "dod_deadline": "FY 2027",
        "alignments": ["NIST SP 800-207", "CISA Zero Trust Maturity Model v2.0"]
      },
      "ai_zero_trust": {
        "microsoft_zt4ai": {
          "date": "2026-03",
          "agent_identity_token": {"purpose": "Encode agent identity, system prompt hash, knowledge base version"},
          "confidential_computing": {"technologies": ["AMD SEV", "Intel TDX"], "purpose": "Model weight isolation during inference"},
          "trust_boundaries": ["user to inference API", "inference to model", "model to tools", "tools to data", "agent to agent", "pipeline to external services"]
        },
        "nhi_statistics": {"ratio_to_human": "45:1 to 500:1", "excessive_privileges": "97%"},
        "bsi_anssi_principles": {
          "date": "2026",
          "principles": ["authentication_per_interaction", "input_output_restrictions", "sandboxing", "monitoring", "threat_intelligence_integration", "stakeholder_awareness"]
        }
      },
      "browser_as_pep": {
        "source": "Cloud Security Alliance (CSA)",
        "date": "2026-01",
        "controls": ["phishing_resistant_mfa_fido2_passkeys", "device_health_validation_before_token", "remote_browser_isolation_high_risk", "continuous_verification_adaptive_step_up"]
      },
      "acme_device_attestation": {
        "status": "IETF draft device-attest-01",
        "replaces": "SCEP shared-password model",
        "mechanism": "TPM/Secure Enclave cryptographic verification",
        "purpose": "Automated hardware-bound certificate issuance",
        "co_developers": ["Smallstep", "Google"]
      },
      "cisa_maturity_model": "v2.0",
      "maturity_stages": ["Traditional", "Initial", "Advanced", "Optimal"],
      "pillars": ["Identity", "Devices", "Networks", "Applications and Workloads", "Data"],
      "industry_adoption_forecast": "85% of Fortune 500 by 2028 (Gartner)"
    }
  }'::jsonb
);
