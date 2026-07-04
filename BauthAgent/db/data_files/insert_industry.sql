INSERT INTO bauth.framework_raw (source_name, content) VALUES (
  'industry_enterprise',
  '{
    "enterprise_authentication_practices_2026": {
      "okta_policy_framework": {
        "three_layer_model": {
          "global_session_policies": {
            "description": "First line of defense for all authentications",
            "best_practices": ["Set default policy as strict fallback denying access", "Require MFA at every sign-in or after MFA lifetime expires", "Disable persistent session cookies across browser sessions", "Set maximum session lifetimes to prevent gaps"],
            "mfa_prompt": "at every sign-in (not just new devices)"
          },
          "authentication_policies": {
            "description": "App-specific access control",
            "best_practices": ["Implement catch-all deny rule in default policy", "Enforce phishing-resistant MFA for critical applications", "Organize by risk: Low (general), Medium (sensitive), Critical (admin consoles)"],
            "auto_assign_new_apps_to_default": true
          },
          "oauth_authorization_policies": {
            "description": "Machine-to-machine security",
            "best_practices": ["Disable ROPC and implicit grant types", "Create specific tightly controlled policies for legacy apps"]
          }
        },
        "express_configuration": {"description": "5-click SSO deployment down from 25+ steps", "features": ["OIDC", "SCIM", "Universal Logout"], "status": "GA 2025-2026"},
        "universal_logout": {"description": "Real-time session revocation via Global Token Revocation and OIDC back-channel logout", "trigger": "Identity Threat Protection (compromised credentials, anomalous behavior, insider threats)"}
      },
      "google_beyondcorp": {
        "description": "Verify identity, device posture, and contextual risk before granting access",
        "device_trust_factors": ["patch_level", "compliance_status", "os_state"],
        "integrations": ["Crowdstrike Falcon ZTA", "Microsoft Intune"],
        "access_levels": "Custom based on combined device posture data",
        "chrome_enterprise_premium": true
      },
      "microsoft_entra_id": {
        "zero_trust_pillars": ["Identity", "Device", "Apps", "Data", "Infrastructure", "Network", "Visibility and Automation"],
        "passkey_support": "First-class feature in 2026.04.0 release",
        "temporary_access_pass": {"description": "Time-limited, single-use, IT-issued for recovery", "max_duration": "8 hours", "use_once": true}
      },
      "passkey_deployment_model": {
        "hybrid_model": {"adoption_rate": "47% per FIDO Alliance survey"},
        "consumer_apps": "synced passkeys",
        "employee_productivity": "synced passkeys on managed devices",
        "admin_privileged_access": "device-bound hardware security keys",
        "regulated_workflows": "device-bound with smart card form factor"
      },
      "recovery_architecture": {
        "options_ranked_by_security": [
          {"rank": 1, "method": "Backup passkey on secondary device", "description": "Encourage enrollment during initial flow"},
          {"rank": 2, "method": "Backup codes generated at enrollment", "description": "Stored offline by user"},
          {"rank": 3, "method": "Hardware security key as backup", "description": "For high-assurance environments"},
          {"rank": 4, "method": "Temporary Access Pass", "description": "Microsoft Entra model, time-limited single-use"},
          {"rank": 5, "method": "Email/phone re-verification", "description": "Use carefully - reintroduces phishing surface"}
        ],
        "recovery_must_not_be_easier_than_auth": true
      },
      "enrollment_best_practices": {
        "auto_triggered_prompt": {"conversion": "75% of enrollments", "trigger": "after successful biometric check"},
        "background_upgrade": {"conversion": "15%"},
        "manual_navigation": {"conversion": "10%"},
        "copy_text": "Sign in faster with your fingerprint — avoid technical jargon"
      },
      "industry_stats_2026": {
        "passkey_accounts_global": "15 billion+",
        "enterprise_deployment": "87% actively deploying",
        "login_success_passkeys": "93%",
        "login_success_traditional": "63%",
        "help_desk_reduction": "81%",
        "fortune_500_zero_trust_by_2028": "85% (Gartner)",
        "apps_per_enterprise": "101 (Okta Businesses at Work 2025)",
        "okta_integrations": "8000+ pre-vetted"
      }
    }
  }'::jsonb
);
