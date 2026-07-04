# PROPOSITO — BauthAgent (bAuth)

**Rol:** Identity Control Plane — Orquestador central de identidad
**Plano:** Identidad · **Stack:** Rust 1.85+ (MUSL) + Java 21 (5 SPIs) · **Doc:** `context/BOS_V8/BOS_V8_SBOS-021-DAEMON-BAUTH.md`

## Contrato de consulta (lo que los hermanos pueden leer de mí)
- **Qué hago:** Enruta credenciales a los motores (Keycloak OIDC/SAML/WebAuthn, Vault PKI/Ed25519, Besu ECDSA), aplica BitMask Dual 64-bit + DomainRegistry 12 dominios + PolicyChain + SoD + DAG, y emite JWT unificado con RolBitMask + ctx_id + firma. Doble motor de firmas (Vault Ed25519 interno + ADSIB RSA-SHA256 externo). PAP/PIP/PDP/PEP. 47 handlers JSON-RPC.
- **Socket:** `/run/bos/bauth.sock` · **Namespace JSON-RPC:** `bauth.*` · **Puerto:** 9450-9453
- **Métodos principales:**
  - `bauth.roltemplate.sync`
  - `bauth.token.issue`
  - `bauth.token.validate`
  - `bauth.policy.evaluate`

Los hermanos me consultan por este contrato — nunca por mi código interno (ORQUESTA-051 §6).
