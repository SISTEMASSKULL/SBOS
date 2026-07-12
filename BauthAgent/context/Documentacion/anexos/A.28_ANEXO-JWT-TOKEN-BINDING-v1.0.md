# Anexo A.28 — El JWT propio y el token binding: DPoP es un stub, mTLS-binding ausente
## Documento de respaldo de sustentación: el estado crudo del binding de tokens contra RFC 9449/8705

**Tipo:** ANEXO — respaldo de sustentación (tipo **D** verificación de código + **C** decisión)
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Respalda a:** MANUAL-TOKENS (2.03) · A.15 (stack) · A.16 (superficie) · MANUAL-AUTENTICACION (2.01 §6 claims)
**Verificación de código:** `jwt_builder.rs` (377) + `jwt_signer.rs` (177) + `token_protocols.rs` (DPoP/exchange/introspect) — leída 2026-07-11
**Normas base:** RFC 7519 (JWT) · RFC 7515 (JWS) · RFC 9449 (DPoP) · RFC 8705 (mTLS-bound) · RFC 7662 (introspection) · RFC 8693 (token exchange)

---

## 1. Propósito

Estado crudo del JWT propio y del **token binding** (prueba de posesión). **Cómo citarlo:**
`A.28 §3` (el DPoP stub).

## 2. Lo que está bien — el JWT propio y la introspección

| Capacidad | Evidencia | Estado |
|---|---|---|
| JWT propio firmado Ed25519 | `jwt_builder.rs` (377) + `jwt_signer.rs` (177) | ✅ real — la independencia (A.15): sin crate JOSE de terceros |
| Claims RolBitMask + ctx_id + risk_score(opt) | `jwt_builder.rs` | ✅ estructura completa |
| Introspection RFC 7662 | `token_protocols.rs:TokenIntrospectHandler` — **verifica de verdad** (`signer.verify` + exp) | ✅ real |
| Token Exchange RFC 8693 | `token_protocols.rs` | ✅ presente |

## 3. ⚠️ HALLAZGO DE SEGURIDAD — DPoP es un stub que miente

`token_protocols.rs:DpopHandler` (RFC 9449) hace esto:

```rust
let parts: Vec<&str> = dpop_proof.split('.').collect();
if parts.len() != 3 { return Err(...) }          // ← solo cuenta que "parece un JWT"
Ok(json!({"dpop_verified": true, "binding": "sha256"}))  // ← retorna true SIN verificar nada
```

**El problema:** retorna `"dpop_verified": true` **verificando únicamente que el proof tenga 3
segmentos separados por puntos**. NO verifica: (a) la firma criptográfica del proof con la clave
pública de su header (`jwk`), (b) el hash del access token (`ath`), (c) el método/URI HTTP
(`htm`/`htu`), (d) el `jti` anti-replay, (e) el `iat` dentro de ventana. **Un DPoP que declara
`verified:true` sin verificación criptográfica es peor que no tenerlo:** da falsa garantía de
sender-constrained token — un atacante con un access token robado adjunta cualquier string de 3
partes y pasa. Contradice fail-closed y el propósito mismo de RFC 9449.

**Resolución (P1 seguridad):** implementar la verificación completa del proof DPoP (firma con la
`jwk` del header + `ath` + `htm`/`htu` + `jti` en store anti-replay + ventana `iat`), o —si no
está listo— que el handler **falle cerrado** (`dpop_verified: false` / error), nunca `true`.

## 4. mTLS-bound tokens (RFC 8705) — ausente

`grep cnf/x5t#S256 jwt_builder.rs` → **0**. El JWT no lleva el claim `cnf` (confirmation) para
certificate-bound tokens. La superficie usa mTLS como método (`mtls.rs`, A.15) pero **el token
emitido no queda ligado al certificado** — falta el binding RFC 8705.

## 5. Lo que FALTA — específico

| # | Brecha | Exigencia | Prioridad |
|---|---|---|:---:|
| **T1** | **DPoP stub** (§3) — `verified:true` sin criptografía | RFC 9449 · fail-closed | **P1 seguridad** |
| T2 | **mTLS-bound (`cnf`/`x5t#S256`) ausente** | RFC 8705 (FAPI 2.0) | P2 |
| T3 | Rotación de claves de firma (verificar política) | NIST · A.08 | P2 |
| T4 | `jti` anti-replay store (necesario para T1 y en general) | RFC 9449 | P1 (parte de T1) |

## 6. Verificación de completitud

| Verificación | Resultado |
|---|---|
| JWT propio + firma Ed25519 | ✅ real (independencia) |
| Introspection/Exchange | ✅ presentes (introspection verifica de verdad) |
| DPoP | ❌ **stub que retorna true sin verificar** — hallazgo P1 |
| mTLS-binding | ❌ ausente (T2) |

## 7. Referencias e historial

**Del código:** `src/domain/{jwt_builder,jwt_signer}.rs` · `src/server/handlers/token_protocols.rs`.
**Industria:** [RFC 9449 DPoP](https://datatracker.ietf.org/doc/html/rfc9449) · [RFC 8705 mTLS](https://datatracker.ietf.org/doc/html/rfc8705) · [RFC 7662](https://datatracker.ietf.org/doc/html/rfc7662) · [FAPI 2.0](https://openid.net/specs/fapi-2_0-security-profile.html)

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Anexo inicial (tipo D+C): el JWT propio Ed25519 real (independencia, sin JOSE de terceros) e introspección que verifica de verdad, pero **hallazgo de seguridad P1: DPoP es un stub que retorna `dpop_verified:true` verificando solo que el proof tenga 3 segmentos** — sin firma, `ath`, `htm/htu`, `jti` ni ventana (RFC 9449); falsa garantía de sender-constrained token. Y **mTLS-bound (RFC 8705) ausente** (sin claim `cnf`). Brechas T1 (DPoP real o fail-closed, P1), T2 (cnf/x5t), T3 (rotación), T4 (jti anti-replay). |
