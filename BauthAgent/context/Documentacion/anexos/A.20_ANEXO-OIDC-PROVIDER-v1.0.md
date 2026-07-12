# Anexo A.20 — El OIDC Provider nativo: qué expone y qué falta para la conformance
## Documento de respaldo de sustentación (tipo D+B)

**Versión:** 1.0.0 · **Fecha:** 2026-07-11 · **Respalda a:** MANUAL-AUTENTICACION (2.01 §11) · MANUAL-TOKENS (2.03) · A.16
**Verificación de código:** `src/server/handlers/oidc_provider.rs` + `token_jwks.rs` — leída 2026-07-11
**Normas:** OIDC Core 1.0 · OAuth 2.1 · RFC 8414 (discovery) · RFC 7517 (JWKS) · FAPI 2.0

## 1. Estado real — OIDC Provider nativo existe (la independencia)
bAuth **es** su propio OIDC Provider — no delega en un IdP externo (ADR-010): `oidc_provider.rs`
(discovery `.well-known/openid-configuration`, endpoints) + `token_jwks.rs` (publicación de
claves JWKS RFC 7517). Es la pieza que hace a bAuth un IdP soberano, no un cliente de uno.

## 2. Lo que FALTA — contra la conformance OIDC/FAPI
| # | Brecha | Exigencia | Prioridad |
|---|---|---|:---:|
| O1 | **Suite de conformance OIDC no pasada** — la certificación exige la batería oficial | OIDC Conformance | P2 |
| O2 | **FAPI 2.0 / PAR (RFC 9126) / DPoP** — perfil de seguridad financiera; DPoP es stub (A.28-T1) | FAPI 2.0 | P2 |
| O3 | Federación ENTRANTE (social/LDAP/Kerberos) — brecha declarada del pilar AM (0.00 §8) | OIDC/SAML brokering | P1 (pilar AM) |
| O4 | Verificar cobertura de flujos (auth code + PKCE, client credentials, device, CIBA) | OIDC/OAuth 2.1 | P2 |

## 3. Verificación de completitud
OIDC Provider nativo ✅ (discovery + JWKS reales) · conformance/FAPI ⏳ · federación entrante ❌ (O3, P1).

**Industria:** [OIDC Core](https://openid.net/specs/openid-connect-core-1_0.html) · [Conformance](https://openid.net/certification/) · [FAPI 2.0](https://openid.net/specs/fapi-2_0-security-profile.html) · [RFC 8414](https://datatracker.ietf.org/doc/html/rfc8414)

| Ver. | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-11 | OIDC Provider nativo verificado (discovery+JWKS, IdP soberano); brechas O1 conformance, O2 FAPI/PAR/DPoP-stub, O3 federación entrante (P1 pilar AM), O4 flujos. |
