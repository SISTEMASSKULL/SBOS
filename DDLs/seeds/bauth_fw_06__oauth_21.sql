INSERT INTO bauth.framework_raw (source_name, content) VALUES (
  'oauth_2_1',
  '{
    "oauth_2_1": {
      "draft_status": "draft-ietf-oauth-v2-1-14",
      "effective_standard": true,
      "description": "OAuth 2.1 consolidates OAuth 2.0 with security best practices. PKCE mandatory, implicit and ROPC removed.",
      "surviving_flows": ["client_credentials", "authorization_code_pkce", "device_authorization"],
      "removed_flows": ["implicit", "ropc_resource_owner_password", "plain_authorization_code"],
      "changes": {
        "pkce_mandatory": {
          "applies_to": "all_clients",
          "including": "confidential_clients",
          "code_challenge_method": "S256",
          "reject_if_not_advertised": true
        },
        "implicit_flow_removed": {"migration_path": "Authorization Code + PKCE"},
        "ropc_removed": {"migration_path": "Device Authorization Grant or Auth Code + PKCE"},
        "refresh_token_rotation": {"required_for": "public_clients", "recommended_for": "all_clients", "replay_detection": true},
        "redirect_uri": {"exact_match_only": true, "no_wildcards": true, "no_port_wildcards": true},
        "bearer_tokens_in_query": "prohibited",
        "bearer_tokens_in_header": "required"
      },
      "deferred_token_response": {
        "draft": "draft-gerber-oauth-deferred-token-response-00",
        "date": "2026-06",
        "description": "Asynchronous token issuance with deferral_code and polling interval",
        "use_cases": ["fraud_prevention_manual_review", "id_verification", "autonomous_agent_authorization", "enterprise_governance_workflows"]
      },
      "vendor_adoption": {
        "okta": true,
        "auth0": true,
        "microsoft_entra_id": true,
        "duende": true
      },
      "migration_timeline_weeks": 12,
      "migration_phases": [
        {"weeks": "1-2", "action": "Audit current grant types; identify implicit flow and ROPC users"},
        {"weeks": "3-4", "action": "Add PKCE to all authorization code flows"},
        {"weeks": "5-6", "action": "Implement refresh token rotation with replay detection"},
        {"weeks": "7-8", "action": "Migrate implicit flow clients to Authorization Code + PKCE"},
        {"weeks": "9-10", "action": "Deprecate ROPC; migrate to Device Authorization Grant"},
        {"weeks": "11-12", "action": "Audit and fix redirect URIs to exact-match only"}
      ]
    }
  }'::jsonb
);
