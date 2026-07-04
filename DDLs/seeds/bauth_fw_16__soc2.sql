INSERT INTO bauth.framework_raw (source_name, content) VALUES (
  'soc2_type_ii',
  '{
    "soc2_trust_services_criteria": {
      "framework_version": "2017 TSC with 2022 revised points of focus",
      "status_2026": "Stable — no major overhaul announced",
      "criteria": {
        "security": {"mandatory": true, "common_criteria": ["CC1 Control Environment", "CC2 Communication and Information", "CC3 Risk Assessment", "CC4 Monitoring Activities", "CC5 Control Activities", "CC6 Logical and Physical Access Controls", "CC7 System Operations", "CC8 Change Management", "CC9 Risk Mitigation"]},
        "availability": {"optional": true, "controls": ["A1.1 Capacity management and monitoring", "A1.2 Environmental protections and backups", "A1.3 Regular recovery testing"]},
        "confidentiality": {"optional": true, "controls": ["C1.1 Identify and classify confidential info", "C1.2 Protect from unauthorized access with encryption and access restrictions"]},
        "processing_integrity": {"optional": true, "controls": ["Input validation", "Accurate processing", "Output delivery", "Data storage integrity"]},
        "privacy": {"optional": true, "controls": ["Notice", "Consent", "Collection", "Use retention disposal", "Access", "Disclosure", "Quality", "Monitoring of PII"]}
      },
      "cc6_authentication_controls": {
        "description": "CC6 — Logical and Physical Access Controls (core for authentication)",
        "mfa_enforced": {"scope": "All administrative access and sensitive systems", "phishing_resistant_recommended": true},
        "sso_required": {"description": "Centralized identity management across all systems"},
        "rbac_required": {"principle": "Least privilege permissions based on job function"},
        "access_request_approval": {"documented_process": true, "description": "Formal process for granting credentials"},
        "access_reviews": {"frequency": "quarterly", "sign_off_required": true},
        "offboarding": {"immediate_revocation": true, "description": "Access removed immediately upon termination"},
        "password_policies": {"strong_rules": true, "limited_legacy_auth": true}
      },
      "type_ii_evidence": {
        "observation_period": "3-12 months",
        "tests_operating_effectiveness": true,
        "enterprise_preference": "Type II strongly preferred over Type I by enterprise buyers",
        "vendor_mandate": "42% of organizations mandate SOC 2 or ISO 27001 from vendors"
      },
      "control_scope_by_size": {
        "small_startup": "40-70 controls",
        "mid_size_saas": "70-120 controls",
        "security_only": "35-50 controls",
        "all_five_criteria": "60-93 controls"
      },
      "hipaa_alignment": {"overlap_with_security_tsc": "60-85%"},
      "automation": {"evidence_collection": "40-50% can be automated"},
      "ai_governance_emerging": {"description": "AI integrations and third-party data flows increasingly in scope for SOC 2 audits"}
    }
  }'::jsonb
);
