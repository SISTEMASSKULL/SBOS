INSERT INTO bauth.framework_raw (source_name, content) VALUES (
  'aws_iam_best_practices',
  '{
    "aws_iam_enterprise_policies": {
      "description": "AWS IAM best practices, SCPs, RCPs, and conditional access for enterprise 2025-2026",
      "least_privilege": {
        "grant_only_required": true,
        "avoid_wildcards": {"s3_example": "Use s3:GetObject instead of s3:*"},
        "explicit_deny": {"overrides_allow": true, "use_for_sensitive_actions": true},
        "modular_policies": {"reduces_complexity": "35%"},
        "managed_policy_limit": "6144 characters"
      },
      "conditional_access_keys": {
        "aws_SourceIp": {"description": "Restrict to corporate IP ranges"},
        "aws_MultiFactorAuthPresent": {"description": "Require MFA for sensitive actions"},
        "aws_CurrentTime": {"description": "Limit access to business hours"},
        "aws_ResourceTag": {"description": "ABAC — match principal tags to resource tags"},
        "aws_PrincipalTag": {"description": "ABAC — match based on principal attributes"},
        "aws_SecureTransport": {"description": "Enforce HTTPS only"},
        "gartner_stat": "Contextual permissions reduce unauthorized access attempts by over 40%"
      },
      "service_control_policies": {
        "major_update": "September 2025 — Full IAM policy language support for SCPs",
        "new_capabilities": ["Conditions in Allow statements", "Individual resource ARNs", "NotAction with Allow", "NotResource in Allow and Deny", "Wildcards anywhere in Action strings"],
        "strategies": {
          "deny_list": {"approach": "Block specific high-risk actions, FullAWSAccess attached by default", "best_for": "Lower risk, faster adoption"},
          "allow_list": {"approach": "Explicitly allow only certain services and actions", "best_for": "Highly regulated environments"}
        },
        "common_patterns": {
          "region_restriction": {"description": "Deny unapproved regions, exempt global services"},
          "prevent_leave_org": {"action": "organizations:LeaveOrganization"},
          "protect_security_services": {"description": "Deny disabling CloudTrail, Config, GuardDuty"},
          "restrict_root": {"principal": "arn:aws:iam::*:root", "deny_all_actions": true},
          "data_perimeter": {"combine": ["SCPs", "RCPs"], "objectives_achievable": "4 of 6"}
        }
      },
      "resource_control_policies": {
        "introduced": "November 2024",
        "scope": "Organization or OU level",
        "target": "Resources (not principals)",
        "controls": "Who can access resources, even from outside your org",
        "supported_services": ["S3", "STS", "KMS", "Secrets Manager", "SQS"]
      },
      "credential_management": {
        "mfa_all_humans": true,
        "hardware_keys_for_root": true,
        "never_use_root_daily": true,
        "use_roles_over_access_keys": true,
        "temporary_credentials_auto_rotate": true,
        "federation": "AWS IAM Identity Center (formerly AWS SSO) for centralized workforce identity"
      },
      "monitoring_tools": {
        "cloudtrail": "Full API auditing",
        "iam_access_analyzer": "Detect overly permissive policies and external access paths",
        "policy_simulator": "Test policies before deployment",
        "guardduty": "Continuous threat detection",
        "security_hub": "Centralized security posture"
      },
      "break_glass": {
        "management_account_role": "Keep break-glass IAM role with strong MFA and alerting",
        "scp_does_not_apply_to_management_account": true
      },
      "industry_stat": "85% of breaches involve privilege misuse (Verizon 2025 DBIR)"
    }
  }'::jsonb
);
