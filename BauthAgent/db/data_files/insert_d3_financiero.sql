INSERT INTO bauth.framework_raw (source_name, content) VALUES (
  'pci_dss_4_0_financial',
  '{
    "financial_access_controls_d3": {
      "pci_dss_v4_0": {
        "status": "full_enforcement_march_2025",
        "description": "PCI DSS 4.0 financial transaction authorization and access controls"
      },
      "mfa_requirements": {
        "req_8_4_2": {
          "title": "MFA for all CDE access",
          "scope": "all_access_into_cardholder_data_environment",
          "not_just_remote": true,
          "phishing_resistant_encouraged": true,
          "fido2_tokens_accepted": true,
          "biometrics_accepted": true
        }
      },
      "password_requirements": {
        "req_8_3_6": {
          "min_length": 12,
          "previous_min_length": 7,
          "periodic_change_required": false,
          "monitor_for_compromise": true,
          "alignment": "NIST SP 800-63B"
        }
      },
      "unique_identification": {
        "shared_accounts_prohibited": true,
        "generic_logins_prohibited": true,
        "individual_attribution_required": true,
        "common_failure": "Shared POS terminals with one login across multiple staff"
      },
      "segregation_of_duties": {
        "req_7": {
          "default_deny": true,
          "least_privilege": true,
          "rbac_required": true,
          "quarterly_reviews": true,
          "immediate_termination": "Access removed immediately for terminated users",
          "access_creep_prevention": "Automated review of permission accumulation"
        }
      },
      "transaction_authorization_limits": {
        "defined_by": ["merchant_acquiring_agreements", "card_brand_rules", "business_risk_policies"],
        "velocity_checks": true,
        "amount_thresholds": "per_role_per_transaction",
        "cumulative_daily_limits": true,
        "fraud_monitoring": "real_time_anomaly_detection"
      },
      "sensitive_authentication_data": {
        "req_3": {
          "pan_storage_prohibited_after_auth": true,
          "cvv2_never_store": true,
          "pin_never_store_after_auth": true,
          "sad_handling_policies": true
        }
      },
      "logging_and_monitoring": {
        "req_10": {
          "retention_months": 12,
          "immediate_access_months": 3,
          "immutable_logs": true,
          "automated_alerting": true,
          "siem_integration": true
        }
      },
      "network_segmentation": {
        "req_11_4_5": {
          "annual_penetration_test": true,
          "validate_isolation": true,
          "assert_only_insufficient": true,
          "scope_reduction_strategies": ["tokenization", "p2pe", "network_isolation", "outbound_only_connections"]
        }
      },
      "sod_matrix": {
        "conflicting_roles": [
          {"role_a": "payment_initiator", "role_b": "payment_approver", "must_be_separate": true},
          {"role_a": "refund_processor", "role_b": "customer_service", "must_be_separate": true},
          {"role_a": "system_admin", "role_b": "audit_log_viewer", "must_be_separate": true},
          {"role_a": "security_configurator", "role_b": "security_monitor", "must_be_separate": true},
          {"role_a": "code_developer", "role_b": "code_deployer", "must_be_separate": true}
        ]
      }
    }
  }'::jsonb
);
