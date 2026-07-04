INSERT INTO bauth.framework_raw (source_name, content) VALUES (
  'fido2_ctap_2.2',
  '{
    "fido2_ctap_2_2": {
      "webauthn_level_3": {
        "status": "Candidate Recommendation",
        "date": "2025-03",
        "spec_url": "w3.org/TR/webauthn-3",
        "description": "W3C browser API for public-key authentication, jointly edited with FIDO Alliance"
      },
      "ctap_2_2_features": {
        "ppuat": {
          "full_name": "Persistent PIN/UV Auth Tokens",
          "enabled": true,
          "description": "Long-lived read-only tokens for credential enumeration without repeated PIN entry",
          "benefit": "Improves UX in enterprise SSO and password managers"
        },
        "pin_complexity_policies": {
          "enabled": true,
          "description": "Authenticators advertise and enforce PIN rules beyond minimum length",
          "alignment": "NIST SP 800-63B-aligned PIN policies"
        },
        "third_party_payment": {
          "enabled": true,
          "description": "Cross-domain credential assertion for regulated payment transactions",
          "compliance": "PSD2 Strong Customer Authentication (SCA)"
        },
        "hmac_secret_mc": {
          "enabled": true,
          "description": "Secret derivation during credential creation for immediate encryption with hardware-backed secrets"
        },
        "hybrid_transport": {
          "enabled": true,
          "mechanism": "QR code + BLE proximity pairing",
          "description": "Cross-device auth allowing phone authenticators to log desktops"
        },
        "json_messaging": {
          "enabled": true,
          "description": "JSON-based message format for Digital Credentials API over hybrid transport"
        },
        "attestation_formats_preference": {
          "enabled": true,
          "description": "Platform sends ordered list of preferred attestation statement formats"
        }
      },
      "enterprise_attestation": {
        "vendor": "HID Crescendo",
        "date": "2026-05",
        "description": "Governance layer checking certificate tying authenticator to company-issued device",
        "blocks_enrollment_if_absent": true,
        "compliance": ["EU NIS2 Directive", "DORA", "Zero Trust Architecture"],
        "adoption_barrier": "20% of organizations cite strict regulations as key barrier to passkey adoption"
      },
      "credential_exchange_protocol": {
        "status": "active",
        "date": "2025-2026",
        "description": "Secure portability of passkeys between credential managers without re-registering",
        "examples": ["Apple iCloud Keychain to Google Password Manager", "Cross-ecosystem passkey migration"]
      },
      "passkey_adoption_2026": {
        "eligible_accounts_global": "15 billion+",
        "enterprise_deployment_rate": "87%",
        "login_success_rate": "93%",
        "traditional_success_rate": "63%",
        "average_login_time_seconds": 8.5,
        "traditional_login_time_seconds": 31.2,
        "help_desk_reduction": "81%",
        "google_signin_improvement": "30% across 800 million users",
        "amazon_speedup": "6x faster than traditional methods"
      },
      "sdk_support": {
        "python_fido2": "v2.0.0+",
        "yubico_dotnet": "v1.14.0+",
        "yubikit_android": "v2.9.0+",
        "libfido2": "v1.17.0+"
      }
    }
  }'::jsonb
);
