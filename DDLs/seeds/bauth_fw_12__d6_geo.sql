INSERT INTO bauth.framework_raw (source_name, content) VALUES (
  'geo_location_d6',
  '{
    "geolocation_access_controls_d6": {
      "description": "Location-based access control and geo-fencing for D6 Geolocalización domain",
      "geo_fencing": {
        "enabled": true,
        "signals": {
          "gps": {"enabled": true, "precision_meters": 10, "description": "Precise device GPS coordinates"},
          "ip_geolocation": {"enabled": true, "provider": "MaxMind GeoIP2", "description": "IP-based country/city detection at edge gateway"},
          "wifi_triangulation": {"enabled": true, "description": "Indoor location for offices and facilities"},
          "network_geolocation": {"enabled": true, "description": "Secure network-based location verification"},
          "device_metadata": {"enabled": true, "description": "Device-reported timezone, locale, region"}
        },
        "anti_spoofing": {
          "tls_mandatory": true,
          "never_trust_client_headers": true,
          "trusted_geolocation_databases_only": true,
          "gps_spoofing_detection": true,
          "vpn_proxy_detection": true
        }
      },
      "region_aware_rbac": {
        "description": "Permissions granted only when role AND region pass",
        "rules": [
          {"region": "eu_eea", "allow_data_access": true, "require_eu_residency": true, "description": "GDPR personal data restricted to EEA"},
          {"region": "sanctioned_countries", "allow_data_access": false, "http_response": "403 Forbidden", "description": "OFAC sanctioned countries blocked at gateway"},
          {"region": "home_country_only", "allow_data_access": true, "description": "Some financial data restricted to home jurisdiction"},
          {"region": "office_premises", "allow_sensitive_access": true, "gps_verified": true, "description": "Highly sensitive data requires physical presence"}
        ]
      },
      "data_sovereignty": {
        "gdpr_articles_44_49": {"description": "Cross-border transfer restrictions", "adequacy_decisions_required": true},
        "post_schrems_ii": {"customer_controlled_encryption": true, "keys_held_exclusively_in_eea": true, "description": "EDPB Recommendation 01/2020 — technical measure sufficient for CLOUD Act protection"},
        "nis2_directive": {"transposed": "2024-10", "supply_chain_sovereignty": true},
        "dora": {"enforceable": "2025-01", "financial_sector_sovereignty": true}
      },
      "employee_location_privacy": {
        "gdpr_art_5_1_c": {"data_minimization": true, "description": "Systematic precise location tracking violates data minimization"},
        "gdpr_art_4_11": {"consent_not_valid_for_employees": true, "description": "Imbalance of power — employee consent not freely given"},
        "gdpr_art_35": {"dpia_required": true, "description": "Data Protection Impact Assessment mandatory for location tracking"},
        "italian_dpa_2025": {"ruling": "GPS tracking of remote employees violates GDPR", "date": "2025-03"}
      },
      "implementation_patterns": {
        "gateway_edge": {"add_header": "X-Geo-Country", "provider": "MaxMind", "action": "before_forwarding_requests"},
        "routing": {"region_aware_load_balancers": true, "example": "if geo.country == DE → api-frankfurt.internal"},
        "policy_engine": {"declarative_geo_rules": true, "at_gateway_or_service_mesh": true},
        "audit": {"immutable_geo_access_logs": true, "gdpr_art_30_compliant": true}
      },
      "compliance_frameworks": ["GDPR Articles 44-49", "NIS 2 Directive", "DORA", "COPPA 2025 (geolocation as personal info)", "OFAC Sanctions", "EDPB Age Assurance 2025"]
    }
  }'::jsonb
);
