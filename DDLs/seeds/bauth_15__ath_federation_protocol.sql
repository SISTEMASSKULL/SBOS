-- seed_ath_federation_protocol.sql — 16 protocolos de federación
SET lock_timeout = '5s'; TRUNCATE TABLE bauth.ath_federation_protocol RESTART IDENTITY CASCADE; REINDEX TABLE bauth.ath_federation_protocol;
INSERT INTO bauth.ath_federation_protocol (protocol_id, protocol_name, protocol_type, rfc_ref, flow, pkce_required, applies_to, bAuth_status) VALUES
('oauth2','OAuth 2.1 Authorization Code','authorization','RFC 6749, RFC 7636','authorization_code',true,'{web}','enabled'),
('oidc','OpenID Connect 1.0','authentication','OpenID Connect Core 1.0','authorization_code',true,'{web,mobile}','enabled'),
('saml2','SAML 2.0 Web SSO','federation','SAML 2.0 OASIS','redirect_post',false,'{web}','enabled'),
('ciba','Client-Initiated Backchannel Auth','authentication','OpenID CIBA','backchannel',false,'{mobile}','enabled'),
('fapi2','FAPI 2.0 Security Profile','authorization','FAPI 2.0','authorization_code',true,'{api}','planned'),
('dpop','DPoP Proof-of-Possession','token_exchange','RFC 9449','dpop',false,'{api}','enabled'),
('mtls','Mutual TLS OAuth 2.0','authentication','RFC 8705','mtls',false,'{api,m2m}','enabled'),
('jwt_profile','JWT Profile OAuth 2.0','token_exchange','RFC 7523, RFC 8693','jwt_bearer',false,'{api}','enabled'),
('token_exchange','Token Exchange','delegation','RFC 8693','token_exchange',false,'{api}','enabled'),
('device_flow','Device Authorization Grant','device','RFC 8628','device_code',false,'{iot,tv}','enabled'),
('ropc','Resource Owner Password Credentials','deprecated','RFC 6749','password',false,'{}','disabled_permanently'),
('implicit','Implicit Grant','deprecated','RFC 6749','implicit',false,'{}','disabled_permanently'),
('saml_ecp','SAML Enhanced Client Profile','deprecated','SAML 2.0 ECP','post',false,'{}','disabled_permanently'),
('ws_fed','WS-Federation','deprecated','WS-Federation 1.2','redirect',false,'{}','disabled_permanently'),
('kerberos','Kerberos SPNEGO','authentication','RFC 4559','negotiate',false,'{desktop}','enabled_controlled'),
('nTLM','NTLM SSO','authentication','MS-NLMP','ntlm',false,'{desktop}','enabled_controlled');
