INSERT INTO bauth.framework_raw (source_name, content) VALUES (
  'cis_kubernetes_1_8',
  '{
    "kubernetes_security_cis_1_8": {
      "benchmark_version": "1.8.0",
      "target": "Kubernetes 1.29+",
      "total_checks": 145,
      "components": 14,
      "api_server_authentication": {
        "anonymous_auth": {"required": false, "check": "1.2.1", "level": 1},
        "basic_auth_file": {"must_not_be_set": true, "check": "1.2.2", "level": 1},
        "token_auth_file": {"must_not_be_set": true, "check": "1.2.3", "level": 1},
        "client_ca_file": {"must_be_configured": true, "check": "1.2.31", "level": 1}
      },
      "api_server_authorization": {
        "authorization_mode_not_always_allow": {"check": "1.2.7", "level": 1},
        "must_include_node": {"check": "1.2.8", "level": 1, "description": "Node authorizer required for kubelet access"},
        "must_include_rbac": {"check": "1.2.9", "level": 1, "description": "RBAC required for all API access"},
        "node_restriction_admission": {"must_be_enabled": true, "check": "1.2.17", "level": 1, "description": "Limits kubelet node object modifications"}
      },
      "rbac_policies": {
        "cluster_admin_restricted": {"check": "5.1.1", "level": 1, "description": "cluster-admin role only when strictly needed"},
        "minimize_secrets_access": {"check": "5.1.2", "level": 1, "description": "Use resourceNames to lock secrets to specific instances"},
        "minimize_wildcards": {"check": "5.1.3", "level": 1, "description": "No wildcards in Roles and ClusterRoles"},
        "default_service_accounts": {"check": "5.1.5", "level": 1, "description": "Default service accounts should not be actively used"},
        "auto_mount_disabled": {"check": "5.1.6", "level": 1, "description": "Service account tokens only mounted where necessary"},
        "prefer_namespace_scoped_roles": true,
        "review_frequency": "quarterly",
        "audit_improvement": "One firm reduced invalid RBAC bindings from 326 to 47 via quarterly audits"
      },
      "pod_security_standards": {
        "replaces": "PodSecurityPolicy (deprecated in K8s 1.25)",
        "replacement": "Pod Security Admission (PSA)",
        "profiles": {
          "restricted": {"recommended_as_default": true, "prohibits": ["privileged_containers", "root_user", "host_filesystem_mounts"]},
          "baseline": {"for_workloads_needing_exemptions": true},
          "privileged": {"only_where_absolutely_necessary": true}
        }
      },
      "network_policies": {
        "cni_must_support": {"check": "5.3.1", "level": 1},
        "all_namespaces_defined": {"check": "5.3.2", "level": 2, "description": "Every namespace must have a NetworkPolicy"},
        "default_deny_ingress": true,
        "default_deny_egress": true
      },
      "secrets_management": {
        "prefer_files_over_env": {"check": "5.4.1", "level": 1, "description": "Secrets as mounted files, not environment variables"},
        "external_secret_store": {"check": "5.4.2", "level": 2, "providers": ["HashiCorp Vault", "AWS KMS", "GCP Cloud KMS"]},
        "etcd_encryption_at_rest": {"mandatory": true, "description": "CIS Level 2 requirement"},
        "base64_not_encryption": {"note": "Native Kubernetes Secrets are NOT encrypted by default — only base64 encoded"}
      },
      "industry_stats_2026": {
        "owasp_k8s_top_10_2025": {"overly_permissive_rbac_rank": 2},
        "red_hat_report_2026": {"orgs_with_k8s_incidents": "76%", "internal_misconfigurations": "64%", "causes": ["excessive_permissions", "root_containers", "missing_resource_limits"]},
        "hipaa_workloads": {"target": "CIS Level 2", "adds": ["etcd_encryption", "audit_logging", "admission_controller_hardening"]}
      }
    }
  }'::jsonb
);
