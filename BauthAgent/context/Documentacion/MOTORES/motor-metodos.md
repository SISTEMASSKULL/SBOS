# Motor de Métodos — *autenticar*

**Verbo:** autenticar · **Frontera:** `src/domain/auth_methods/` · **Estado:** 🔄 9/18 · **Rige:** ADR-013 · **Contrato:** CORE-12 (A.43)

---

## 1. Propósito
Punto **único** donde se validan TODOS los métodos de autenticación (los 47 de 2.02). bAuth acude
aquí para *aplicar, enrolar, consultar o revocar* un método y recibe **un** `VeredictoAuth`. Ningún
método se valida fuera de este motor.

## 2. El contrato del motor
- **Trait:** `AuthMethod` (`auth_methods/mod.rs:47`) — `validate`/`enroll`/`revoke`/`health_check`.
- **Registro:** `MethodRegistry` (`mod.rs:121`) — patrón PAM; despacha por `method_id`.
- **Fachada objetivo (A.44 §1.2):** `MotorDeMetodos{aplicar, enrolar, revocar, consultar}` con
  `SolicitudAuth → VeredictoAuth` (hoy la entrada es `&serde_json::Value` sin tipar — a cerrar).
- **Fail-closed:** firma/OTP inválido ⇒ rechazo; nunca `valid:true` por defecto.

## 3. Los códigos que se juntan (frontera: `src/domain/auth_methods/`)
| Archivo | Rol | Acción |
|---------|-----|:------:|
| `mod.rs` | trait + `MethodRegistry` | ✅ en frontera |
| `totp.rs` `hotp.rs` `webauthn.rs` `push.rs` `mtls.rs` `email_otp.rs` `recovery.rs` `saml.rs` `saml_signature.rs` | los 9 métodos | ✅ en frontera |
| **(faltan)** passkey, X.509-smartcard, Kerberos, social-brokering, CIBA, device-auth, conditional-OTP, client-credentials, token-exchange | 9 métodos | ⬜ crear bajo `AuthMethod` |
| **familias** | software · hardware-físico (vía edge) · federación · DID/VC | organizar (ADR-013 §criterio) |

> La **cripto** que estos métodos usan (`ring::hmac`, `ed25519`…) NO vive aquí: se pide al **Motor
> Criptográfico** (`src/crypto/`, CORE-11). Este motor conoce el protocolo; el cripto, el algoritmo.

## 4. Manuales de referencia (leer antes de tocar)
- **2.01** Autenticación (§3 el motor, §4 los 9 métodos, §10 step-up) — **madre**
- **2.02** Estado/industria/hoja de ruta de los 47 métodos
- **7.02** Calidad de autenticación
- **1.08 §5** UserTemplate (autenticador enrolado) · **1.09 B4** RolTemplate (AAL exigido)

## 5. Anexos y contratos
- **A.44** — arquitectura y completitud de los 47 métodos (petición→plantillas→devuelve, ejemplo, validación). **La referencia principal.**
- **A.15** — stack Rust de autenticación (RustCrypto/ring, cobertura por método).
- **A.43** — contrato **CORE-12** (completar 18) · pilar I AM (AM-01..AM-19).
- **A.41 §11 / A.42** — BA1 (WebAuthn ✅), fichas de métodos por desarrollar.

## 6. Estado real (verificado en código)
- ✅ 9 métodos implementados bajo el trait; **WebAuthn corregido** (firma real W3C §7.2).
- 🔄 entrada sin tipar (`Value` genérico); attestation WebAuthn + XSW SAML pendientes.
- ⬜ 9 métodos faltantes; familias hardware (edge) sin organizar.

## 7. Plan para completarlo
1. Cerrar el contrato tipado `SolicitudAuth`/`VeredictoAuth` (A.44 §1.4).
2. Registrar los 9 métodos faltantes bajo `AuthMethod` (prioridad P1: Smart Card, CIBA, Device Grant, Social OIDC).
3. Organizar las **familias** (software/hardware-edge/federación/DID) sin romper el punto único.
4. Consumir el **Motor Criptográfico** (no `ring` directo) cuando CORE-11 exista.

*Portada de motor · ADR-013 · 2026-07-12*
