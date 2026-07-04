INSERT INTO bauth.framework_raw (source_name, content) VALUES (
  'delegation_authority_d10',
  '{
    "delegation_access_controls_d10": {
      "description": "Delegation of authority, temporary access grants, and emergency break-glass for D10 Delegación domain",
      "delegation_framework": {
        "description": "Structured delegation of authority with time-bound and approval-gated grants",
        "types": {
          "temporary_access_grant": {"max_duration_hours": 8, "auto_revoke": true, "description": "Short-term access for specific task"},
          "vacation_coverage": {"max_duration_days": 14, "requires_peer_approval": true, "description": "Delegate authority during planned absence"},
          "emergency_delegation": {"max_duration_hours": 4, "requires_post_hoc_review": true, "description": "Crisis delegation when normal approvers unavailable"},
          "project_based_delegation": {"max_duration_days": 90, "requires_project_owner_approval": true, "description": "Longer-term delegation for project duration"}
        },
        "approval_chain": {
          "levels": ["self_service_low_risk", "peer_approval_medium", "manager_approval_high", "dual_approval_critical"],
          "auto_escalation_timeout_minutes": 15,
          "fallback_approver_required": true
        }
      },
      "break_glass_access": {
        "description": "Emergency access for critical incidents when normal processes fail",
        "triggers": ["idp_outage", "critical_service_outage", "security_breach_active", "data_integrity_threat"],
        "requirements": {
          "named_identity_only": true,
          "time_bound": true,
          "auto_revoke_after_resolution": true,
          "mfa_enforced": true,
          "full_session_recording": true,
          "post_incident_review_hours": 48,
          "credential_rotation_after_use": true
        },
        "physical_fallback": {
          "description": "For catastrophic failures where PAM systems unreachable",
          "offline_vault": true,
          "dual_control": "M-of-N authentication",
          "fireproof_safes": true,
          "pre_configured_recovery_credentials": true
        }
      },
      "separation_of_duties_delegation": {
        "cannot_delegate_to_self": true,
        "delegator_cannot_approve_own_delegation": true,
        "sod_check_before_grant": true,
        "conflicting_delegations_blocked": [
          {"delegation_a": "financial_approval", "delegation_b": "financial_initiation", "conflict": true},
          {"delegation_a": "security_config", "delegation_b": "security_audit", "conflict": true},
          {"delegation_a": "code_review", "delegation_b": "code_deploy", "conflict": true}
        ]
      },
      "audit_and_accountability": {
        "immutable_delegation_log": true,
        "retention_months": 12,
        "audit_fields": ["who_delegated", "to_whom", "what_permissions", "when_started", "when_expired", "approval_chain", "actions_performed"],
        "quarterly_delegation_review": true,
        "quarterly_authority_list_review": true
      },
      "just_in_time_vs_break_glass": {
        "separate_pathways": true,
        "jit_description": "Expected but infrequent privileged tasks: admin functions, troubleshooting",
        "break_glass_description": "Abnormal crisis: IdP outage, critical incident, security breach",
        "jit_requires_pre_approval": true,
        "break_glass_allows_post_hoc_review": true
      },
      "testing_and_readiness": {
        "quarterly_tabletop_exercises": true,
        "review_on_personnel_change": true,
        "retain_audit_logs_years": 3,
        "industry_adoption": "Standing privilege elimination reduces breach risk by 91%"
      },
      "compliance_alignment": ["SOX", "ISO 27001 A.5.16", "NIST 800-53 AC-2", "PCI DSS Req 7", "GDPR Art 32"]
    }
  }'::jsonb
);
