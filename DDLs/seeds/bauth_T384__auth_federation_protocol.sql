-- bauth_T384__auth_federation_protocol.sql — Seed generado de VPS SBOSDB
-- Filas: 8 · Idempotente: ON CONFLICT DO NOTHING
SET lock_timeout = '5s';

INSERT INTO bauth.auth_federation_protocol VALUES ('019fb478-64e8-76d1-8f4d-1cfa8a598f73', 'SAML_2_0', '{"en": "SAML 2.0", "es": "SAML 2.0"}', 'https://docs.oasis-open.org/security/saml/v2.0/', 'AAL2', '{FAL1,FAL2}', false, true, true, 'SUPPORTED', 10) ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_federation_protocol VALUES ('019fb478-64eb-7d19-8556-5cd96d86cc2a', 'OIDC_CORE_1_0', '{"en": "OpenID Connect Core 1.0", "es": "OpenID Connect Core 1.0"}', 'https://openid.net/specs/openid-connect-core-1_0.html', 'AAL2', '{FAL1,FAL2}', false, true, true, 'SUPPORTED', 20) ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_federation_protocol VALUES ('019fb478-64eb-7f2f-9b4a-91aa16aab4c7', 'OAUTH2_PKCE', '{"en": "OAuth 2.0 + PKCE", "es": "OAuth 2.0 + PKCE"}', 'https://www.rfc-editor.org/rfc/rfc7636', 'AAL2', '{FAL1,FAL2}', false, false, false, 'SUPPORTED', 30) ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_federation_protocol VALUES ('019fb478-64eb-7fff-8880-b68b71c9774c', 'OAUTH2_DEVICE', '{"en": "OAuth 2.0 Device Auth", "es": "OAuth 2.0 Device Auth"}', 'https://www.rfc-editor.org/rfc/rfc8628', 'AAL1', '{FAL1}', false, false, false, 'SUPPORTED', 40) ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_federation_protocol VALUES ('019fb478-64ec-70e3-af8c-e6d2489af156', 'OAUTH2_TOKEN_EXCHANGE', '{"en": "OAuth 2.0 Token Exchange", "es": "OAuth 2.0 Token Exchange"}', 'https://www.rfc-editor.org/rfc/rfc8693', 'AAL2', '{FAL1,FAL2}', false, false, false, 'SUPPORTED', 50) ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_federation_protocol VALUES ('019fb478-64ec-71a4-8936-7f2d15e47863', 'CIBA', '{"en": "CIBA", "es": "CIBA (Client-Initiated Backchannel Auth)"}', 'https://openid.net/specs/openid-client-initiated-backchannel-authentication-core-1_0.html', 'AAL2', '{FAL1,FAL2}', false, false, true, 'SUPPORTED', 60) ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_federation_protocol VALUES ('019fb478-64ec-726f-8c95-3017c6f910e7', 'FAPI_2_0', '{"en": "FAPI 2.0", "es": "FAPI 2.0 Security Profile"}', 'https://openid.net/specs/fapi-2_0-security-profile-1_0.html', 'AAL3', '{FAL2,FAL3}', true, true, true, 'SUPPORTED', 70) ON CONFLICT DO NOTHING;
INSERT INTO bauth.auth_federation_protocol VALUES ('019fb478-64ec-7309-a86e-a682b5de65d7', 'CAEP_RFC9396', '{"en": "CAEP / SSF (RFC 9396)", "es": "CAEP / SSF (RFC 9396)"}', 'https://www.rfc-editor.org/rfc/rfc9396', 'AAL2', '{FAL1,FAL2,FAL3}', false, false, true, 'SUPPORTED', 80) ON CONFLICT DO NOTHING;

SELECT 'T384__auth_federation_protocol: ' || 8 || ' filas' AS resultado;
