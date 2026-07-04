# SBOS-019 — Métodos de Autenticación en Keycloak
## Lista completa, límite de responsabilidad IdP y lo que necesita el SBOS por cada uno

**SKULL · SBOS — Sovereign Business Operating System**
**v3.0 · Marzo 2026 — Basado en Keycloak 26.x**

---

**Código:** SBOS-019
**Versión:** 2.0
**Estado:** ACTIVO
**Reemplaza a:** SBOS-016-KC-AUTH-METHODS v1.0 (SUPERSEDED)
**Clasificación:** Especificación Técnica — Gobierno de Identidad (SBOS-003)

---

## Tabla de Contenidos

1. [El principio que organiza todo](#1-el-principio-que-organiza-todo)
2. [Los métodos agrupados por categoría](#2-los-métodos-agrupados-por-categoría)
3. [Análisis detallado por método](#3-análisis-detallado-por-método)
4. [Los 5 SPIs que el SBOS debe construir](#4-los-5-spis-que-el-sbos-debe-construir)
5. [Tabla de referencia definitiva](#5-tabla-de-referencia-definitiva)
6. [Mapa final: métodos del SBOS → implementación Keycloak](#6-mapa-final-métodos-del-sbos--implementación-keycloak)
7. [Conclusión: la frontera real de Keycloak](#7-conclusión-la-frontera-real-de-keycloak)

---

## 1. El principio que organiza todo

Antes de la lista, hay que entender el principio que define hasta dónde llega Keycloak en cada método. Se puede resumir en una sola frase:

> **Keycloak verifica la prueba criptográfica de identidad. Lo que está antes de esa prueba — el hardware, el sensor, el PIN, el dedo — es responsabilidad del dispositivo del usuario, no de Keycloak.**

Keycloak nunca toca un lector de huella. Nunca lee una tarjeta física. Nunca llama a una red de telefonía. Lo que hace es recibir una **afirmación criptográfica** de que ese usuario completó ese factor, y la valida contra lo que tiene registrado.

Con ese principio claro, la lista tiene sentido.

---

## 2. Los métodos agrupados por categoría

```
CATEGORÍA 1 — BASADOS EN CONOCIMIENTO (algo que sabes)
  1.  Username + Password
  2.  TOTP — Time-based One Time Password
  3.  HOTP — Counter-based One Time Password
  4.  Recovery Codes (códigos de recuperación)
  5.  Security Questions (preguntas de seguridad) — vía SPI

CATEGORÍA 2 — BASADOS EN POSESIÓN (algo que tienes)
  6.  WebAuthn / FIDO2 — Hardware Security Keys (YubiKey, etc.)
  7.  Passkeys (WebAuthn sincronizadas entre dispositivos)
  8.  X.509 Client Certificate (tarjeta inteligente / smart card)
  9.  Magic Link (enlace por email)
  10. SMS OTP — vía SPI / proveedor externo
  11. Email OTP

CATEGORÍA 3 — BASADOS EN INHERENCIA (algo que eres)
  12. WebAuthn Biométrico — huella / FaceID / Windows Hello
      (el sensor es del dispositivo; Keycloak recibe la firma WebAuthn)

CATEGORÍA 4 — BASADOS EN CONTEXTO (dónde estás / quién eres ya)
  13. Kerberos / SPNEGO — SSO de red corporativa
  14. Social Login / Identity Brokering (Google, Azure AD, LDAP, SAML, OIDC)
  15. LDAP / Active Directory Federation

CATEGORÍA 5 — SPI CUSTOM (lo que el SBOS construye)
  16. Cualquier método propio vía Authenticator SPI de Keycloak
```

---

## 3. Análisis detallado por método

### 1. Username + Password

**Qué hace Keycloak:**
Almacena el hash de la contraseña (bcrypt/PBKDF2). Cuando el usuario ingresa la contraseña, Keycloak la hashea y compara. Emite sesión si coincide. Gestiona políticas de contraseña: longitud mínima, caracteres especiales, historial, expiración, no repetición, lista negra de contraseñas comunes. Gestiona brute-force protection: bloqueo temporal por intentos fallidos.

**Responsabilidad de Keycloak:**
✓ Almacenamiento seguro del hash | ✓ Validación criptográfica en login | ✓ Políticas de contraseña configurables | ✓ Brute force protection (bloqueo por IP / usuario) | ✓ Flujo de recuperación (forgot password via email) | ✓ Expiración y fuerza de contraseña

✗ No controla gestores de contraseñas externos | ✗ No detecta si la contraseña fue filtrada en brechas externas (HaveIBeenPwned)

**Firma de interfaz Java — SPI relevante: `CredentialProvider`**

```java
// Interfaz: org.keycloak.credential.CredentialProvider<T extends CredentialModel>
// Clase de implementación SBOS: SkbosPasswordBreachCheckProvider

public interface CredentialProvider<T extends CredentialModel> {

    // Tipo de credencial que gestiona este provider
    String getType();

    // Valida la credencial — punto de extensión para check HaveIBeenPwned
    boolean isValid(RealmModel realm,
                    UserModel user,
                    CredentialInput input);

    // Crea/actualiza la credencial del usuario
    CredentialModel createCredential(RealmModel realm,
                                     UserModel user,
                                     UserCredentialModel credentialModel);

    // Elimina la credencial del usuario
    boolean deleteCredential(RealmModel realm,
                              UserModel user,
                              String credentialId);

    // Condición de fallo: isValid() devuelve false → Keycloak ejecuta el flujo
    // de error configurado (mensaje de contraseña inválida o bloqueo temporal)
}
```

**Relevancia para el SBOS:** Base de todos los Authentication Flows. Siempre presente como primer factor. El SBOS usa `username_password` en todos los dominios.

---

### 2. TOTP — Time-based One Time Password

**Qué hace Keycloak:** Genera un secreto compartido al momento del enrolamiento. Lo muestra como QR Code. El usuario lo escanea con Google Authenticator, FreeOTP, Authy, etc. En cada login, Keycloak calcula el TOTP esperado (hash de secreto + tiempo actual), lo compara con el que ingresó el usuario. Ventana de validación configurable (±30s). Algoritmos: SHA1 (default), SHA256, SHA512. Longitud: 6 u 8 dígitos. Intervalo: 30 segundos (configurable). Múltiples dispositivos TOTP por usuario con nombres únicos (KC 26.3+).

**Responsabilidad de Keycloak:**
✓ Generación y almacenamiento del secreto compartido | ✓ Generación del QR Code de enrolamiento | ✓ Validación matemática del código en el tiempo correcto | ✓ Gestión de ventana de tiempo para desfase de reloj | ✓ Múltiples dispositivos TOTP por usuario

✗ No controla la app del usuario | ✗ No verifica que el teléfono sea el correcto | ✗ No detecta si el secreto fue comprometido en el dispositivo

**Relevancia para el SBOS:** `2fa_app` en `requiredMethods` del dominio `logical_access`. Segundo factor estándar para acceso lógico.

---

### 3. HOTP — Counter-based One Time Password

**Qué hace Keycloak:** Igual que TOTP pero usa un contador incremental en lugar del tiempo. El código cambia solo cuando se usa exitosamente. Keycloak almacena y sincroniza el contador. Look-ahead window para resincronización si el usuario genera códigos sin usarlos.

**Relevancia para el SBOS:** Alternativa a TOTP para usuarios con problemas de sincronización de tiempo. Menos recomendado para el dominio financiero por su ventana de validez más amplia.

---

### 4. Recovery Codes

**Qué hace Keycloak:** Genera una lista de códigos de un solo uso al momento del enrolamiento del 2FA. Cada código es válido solo una vez — Keycloak lo marca como usado. Almacena hashes, no códigos en claro. Advertencia cuando quedan pocos códigos.

**Relevancia para el SBOS:** Corresponde al concepto `alternativeMethods` del SBOS — método de emergencia preconfigurado.

---

### 5. Security Questions — vía SPI

No hay soporte nativo completo en KC 26. Se implementa vía Authenticator SPI custom. El SBOS no las incluye en sus `availableMethods` por defecto — son consideradas un método débil.

---

### 6. WebAuthn / FIDO2 — Hardware Security Keys

**Qué es FIDO2 / WebAuthn:** FIDO2 es el estándar abierto. WebAuthn es la API del navegador. Criptografía de clave pública: el dispositivo tiene una clave privada que nunca sale de él. Keycloak guarda la clave pública.

**Qué hace Keycloak:** Actúa como **WebAuthn Relying Party (RP)**. Genera challenges criptográficos. Almacena la clave pública del autenticador. Verifica firmas. Verifica el signature counter (detecta clonación). Gestiona múltiples autenticadores por usuario. Revocación de autenticador específico.

**Responsabilidad de Keycloak:**
✓ Generación de challenges criptográficos (nonce único por sesión) | ✓ Almacenamiento de la clave pública | ✓ Verificación de la firma | ✓ Signature counter anti-clonación | ✓ Políticas de attestation y user verification | ✓ Gestión y revocación por autenticador

✗ No toca el hardware | ✗ No controla lo que el autenticador pide al usuario (PIN, toque, biometría)

**Firma de interfaz Java — SPI relevante: `WebAuthnAuthenticator`**

```java
// Interfaz: org.keycloak.authentication.Authenticator
// Clase de implementación SBOS: SkbosWebAuthnSecurityKeyAuthenticator
// Extiende: WebAuthnAuthenticator (org.keycloak.authentication.authenticators.browser)

public interface Authenticator {

    // Genera el challenge y prepara el contexto de autenticación
    void authenticate(AuthenticationFlowContext context);

    // Procesa la respuesta del autenticador hardware (firma WebAuthn)
    // Verifica firma, signature counter, user verification policy
    void action(AuthenticationFlowContext context);

    // Indica si el autenticador requiere interacción del usuario
    boolean requiresUser();

    // Indica si el autenticador es válido para el usuario actual
    // (tiene al menos un autenticador WebAuthn registrado)
    boolean configuredFor(KeycloakSession session,
                          RealmModel realm,
                          UserModel user);

    // Establece datos requeridos en el usuario antes de autenticar
    void setRequiredActions(KeycloakSession session,
                             RealmModel realm,
                             UserModel user);

    // Condición de fallo: action() falla → context.failure(AuthenticationFlowError.INVALID_CREDENTIALS)
    // Resultado: mensaje de error + incremento de brute-force counter
}
```

**Relevancia para el SBOS:** `smart_card_logical` y `security_key` en `availableMethods` usan WebAuthn.

---

### 7. Passkeys

**Qué son:** Credenciales FIDO2 sincronizadas entre dispositivos del mismo usuario via sistema operativo (iCloud Keychain, Google Password Manager, Windows Hello). Son WebAuthn — la diferencia es que no están atadas a un solo dispositivo físico.

**Qué hace Keycloak (KC 26.4+):** Todo lo de WebAuthn más UI condicional (el navegador sugiere la passkey automáticamente), UI modal (el usuario elige activamente), y re-autenticación con passkey (step-up).

✗ No gestiona la sincronización entre dispositivos — eso es Apple/Google/Microsoft | ✗ No controla si la passkey fue sincronizada a un dispositivo no autorizado

**Relevancia para el SBOS:** Método ideal para acceso lógico diario sin contraseña. `biometric_login` en `availableMethods` cuando se usa huella/FaceID vía passkey.

---

### 8. X.509 Client Certificate (Smart Card)

**Qué hace Keycloak:** Tres capas — Keycloak gestiona solo la capa 2.

**CAPA 1 — Reverse Proxy (nginx/HAProxy) — FUERA de Keycloak:** Solicita el certificado cliente. Verifica la cadena de certificación. Reenvía el certificado a Keycloak como header HTTP.

**CAPA 2 — Keycloak (su responsabilidad):** Recibe el certificado del header del proxy. Valida caducidad, revocación (CRL u OCSP), Key Usage, Extended Key Usage. Extrae la identidad del Subject DN via regex. Mapea esa identidad a un usuario del realm.

**CAPA 3 — PKI / CA — FUERA de Keycloak:** Emite y firma los certificados. Gestiona la CRL y el OCSP. Keycloak consulta la CRL/OCSP pero no la gestiona.

**Firma de interfaz Java — SPI relevante: `X509ClientCertificateAuthenticator`**

```java
// Interfaz: org.keycloak.authentication.Authenticator
// Clase de implementación SBOS: SkbosX509CertAuthenticator
// Extiende: AbstractX509ClientCertificateAuthenticator

public interface Authenticator {

    // Extrae el certificado del header HTTP (enviado por nginx)
    // Valida: caducidad, CRL/OCSP, Key Usage, Extended Key Usage
    // Extrae Subject DN → ejecuta regex configurable
    void authenticate(AuthenticationFlowContext context);

    // Procesa la confirmación del usuario (en flows con step de confirmación)
    void action(AuthenticationFlowContext context);

    // Verifica que el usuario tiene credencial X.509 registrada en el realm
    boolean configuredFor(KeycloakSession session,
                          RealmModel realm,
                          UserModel user);

    // Registra la acción requerida si no hay certificado configurado
    void setRequiredActions(KeycloakSession session,
                             RealmModel realm,
                             UserModel user);

    // Condición de fallo: certificado inválido, revocado, o DN sin mapeo →
    // context.failure(AuthenticationFlowError.INVALID_CREDENTIALS)
    // Caso especial: certificado expirado → error específico con mensaje descriptivo
}
```

✗ No gestiona la CA ni la emisión de certificados | ✗ No gestiona el smart card físico | ✗ No controla si el usuario tiene el PIN | ✗ No verifica si la tarjeta fue robada

**Relevancia para el SBOS:** `smart_card_logical` en `logical_access` y `smart_card` / `smart_card_pin` en `physical_access` y `financial_transactions`.

---

### 9. Magic Link (Enlace por Email)

**Qué hace Keycloak:** Genera un token de un solo uso, lo embebe en un URL, lo envía por email. Valida el token (TTL configurable) y emite la sesión. El token queda invalidado tras uso.

✗ No controla si el email del usuario fue comprometido | ✗ No verifica entregabilidad

**Relevancia para el SBOS:** `email_verification_code` en `alternativeMethods` de `logical_access`. No se usa como método primario.

---

### 10. SMS OTP — vía SPI

Keycloak no incluye SMS nativamente. Requiere Authenticator SPI custom conectado a proveedor externo (Twilio, AWS SNS, MessageBird).

**Firma de interfaz Java — SPI: `Authenticator` (para BOS-SMS-SPI)**

```java
// Interfaz: org.keycloak.authentication.Authenticator
// Clase de implementación SBOS: SkbosSmsOtpAuthenticator

public interface Authenticator {

    // Genera código OTP 6 dígitos → llama API proveedor SMS → almacena hash del código
    // con TTL en caché de sesión de Keycloak
    void authenticate(AuthenticationFlowContext context);

    // Lee el código ingresado por el usuario → hashea → compara con caché
    // Verifica TTL → invalida código tras primer uso exitoso
    void action(AuthenticationFlowContext context);

    boolean requiresUser();

    // Verifica que el usuario tiene número de teléfono registrado
    boolean configuredFor(KeycloakSession session,
                          RealmModel realm,
                          UserModel user);

    void setRequiredActions(KeycloakSession session,
                             RealmModel realm,
                             UserModel user);

    // Condición de fallo: código incorrecto o TTL expirado →
    // context.failure(AuthenticationFlowError.INVALID_CREDENTIALS)
    // Código incorrecto > 3 veces → context.failure(AuthenticationFlowError.ACCESS_DENIED)
}
```

✗ La entrega del SMS depende del proveedor externo | ✗ Vulnerable a SIM swapping

**Relevancia para el SBOS:** `mobile_token` en `financial_transactions.availableMethods`.

---

### 11. Email OTP

Disponible de forma nativa en KC 26. Similar al SMS OTP pero vía email. El SBOS usa `email_verification_code` en `alternativeMethods`.

---

### 12. WebAuthn Biométrico (Huella / FaceID / Windows Hello)

**Este es el método más importante de entender correctamente.**

WebAuthn Biométrico NO es que Keycloak lee la huella del usuario. Es WebAuthn donde el autenticador que firma el challenge es el sensor biométrico del dispositivo (Touch ID, Face ID, Windows Hello, lector de huella Android).

```
1. Keycloak genera un challenge
2. El navegador lo envía al autenticador de plataforma del dispositivo
3. El dispositivo pide al usuario: "Toca el sensor de huella" o "Mira a la cámara"
4. El sensor verifica la biometría LOCALMENTE en el chip del dispositivo (enclave seguro)
5. Si la biometría es correcta, el chip firma el challenge con la clave privada
6. La firma llega a Keycloak
7. Keycloak verifica la firma contra la clave pública registrada
```

**Keycloak NUNCA recibe la huella. NUNCA ve la imagen biométrica.**

**Responsabilidad de Keycloak:**
✓ Registro de la clave pública del autenticador biométrico | ✓ Generación y validación de challenges | ✓ Verificación de la firma | ✓ Signature counter | ✓ Política userVerification=REQUIRED

✗ No procesa ni almacena datos biométricos (por diseño FIDO2) | ✗ No controla el sensor biométrico

**Implicación para GDPR:** como Keycloak NUNCA recibe la biometría, no hay datos biométricos en Keycloak. Los datos biométricos están en el enclave seguro del dispositivo del usuario. Esta es la arquitectura correcta para cumplir con regulaciones.

**Relevancia para el SBOS:** `biometric_login` en `logical_access.availableMethods` y `biometric_validation` en `financial_transactions.availableMethods` son WebAuthn con userVerification=REQUIRED.

---

### 13. Kerberos / SPNEGO

**Qué hace Keycloak:** SSO transparente en red corporativa. Valida el ticket Kerberos usando el keytab configurado. Mapea el principal Kerberos al usuario del realm.

✗ No gestiona el KDC (Key Distribution Center) | ✗ Solo funciona en la red corporativa

**Relevancia para el SBOS:** Para empresas con Active Directory existente.

---

### 14. Social Login / Identity Brokering

**Qué hace Keycloak:** Federar con Google, Microsoft, GitHub, cualquier IdP OIDC o SAML 2.0. Valida el token/assertion recibido. Crea o mapea usuario local con atributos del proveedor. Sincroniza atributos.

✗ No controla la seguridad del proveedor externo | ✗ No puede revocar la autenticación del proveedor externo

**Relevancia para el SBOS:** Para empresas con Azure AD o Google Workspace existente.

---

### 15. LDAP / Active Directory Federation

**Qué hace Keycloak:** Bind LDAP para validar credenciales. Sincronización de usuarios y grupos. Mapeo de atributos LDAP a atributos del usuario. Mapeo de grupos LDAP a roles KC.

✗ No gestiona el servidor LDAP | ✗ Si LDAP cae, KC en modo read-only (usuarios en caché siguen funcionando)

**Relevancia para el SBOS:** Cuando la empresa tiene AD existente con usuarios.

---

## 4. Los 5 SPIs que el SBOS debe construir

Keycloak resuelve completamente: Username+Password, TOTP, WebAuthn/Passkeys, X.509, Magic Link, Email OTP, Kerberos, LDAP. El SBOS tiene que construir 5 SPIs adicionales para completar el modelo de dominios.

### BOS-Guard-SPI — el más crítico

```java
// Interfaz: org.keycloak.authentication.Authenticator
// Clase: SkbosGuardAuthenticator
// Se ejecuta PRIMERO en cada Authentication Flow

public interface Authenticator {

    // Lee bos_la_available / bos_ft_available del rol del usuario
    // Bloquea cualquier método que no esté en la lista del rol
    // Sin esto, un usuario podría saltar a un método no autorizado
    void authenticate(AuthenticationFlowContext context);

    void action(AuthenticationFlowContext context);

    boolean requiresUser();

    boolean configuredFor(KeycloakSession session,
                          RealmModel realm,
                          UserModel user);

    void setRequiredActions(KeycloakSession session,
                             RealmModel realm,
                             UserModel user);

    // Condición de fallo: método solicitado no está en bos_la_available del rol →
    // context.failure(AuthenticationFlowError.ACCESS_DENIED)
    // Mensaje específico indicando qué métodos están disponibles para el usuario
}
```

### BOS-FinancialPeriod-SPI

```java
// Interfaz: org.keycloak.authentication.Authenticator
// Clase: SkbosFinancialPeriodAuthenticator

public interface Authenticator {

    // Verifica bos_ft_periods del rol del usuario
    // Si no estamos en la ventana quincenal → denegar con próxima ventana disponible
    void authenticate(AuthenticationFlowContext context);

    void action(AuthenticationFlowContext context);

    boolean requiresUser();

    boolean configuredFor(KeycloakSession session,
                          RealmModel realm,
                          UserModel user);

    void setRequiredActions(KeycloakSession session,
                             RealmModel realm,
                             UserModel user);

    // Condición de fallo: fuera de ventana de período →
    // context.failure(AuthenticationFlowError.ACCESS_DENIED)
    // Payload del error incluye: próxima_ventana_inicio (ISO8601)
}
```

### BOS-GeoContext-SPI

```java
// Interfaz: org.keycloak.authentication.Authenticator
// Clase: SkbosGeoContextAuthenticator

public interface Authenticator {

    // Lee IP/red del contexto de login (context.getConnection().getRemoteAddr())
    // Compara con bos_la_geo y bos_ft_geo del rol del usuario
    // Si está fuera de ubicación permitida → denegar o requerir VPN
    void authenticate(AuthenticationFlowContext context);

    void action(AuthenticationFlowContext context);

    boolean requiresUser();

    boolean configuredFor(KeycloakSession session,
                          RealmModel realm,
                          UserModel user);

    void setRequiredActions(KeycloakSession session,
                             RealmModel realm,
                             UserModel user);

    // Condición de fallo: IP fuera de rango bos_la_geo →
    // context.failure(AuthenticationFlowError.ACCESS_DENIED)
    // Opción: context.challenge() para mostrar formulario de VPN requerido
}
```

### BOS-BehavioralScore-SPI

```java
// Interfaz: org.keycloak.authentication.Authenticator
// Clase: SkbosBehavioralScoreAuthenticator

public interface Authenticator {

    // Consulta bos_behavioral_score del usuario al momento del login
    // Si score < bos_score_threshold del rol → denegar con mensaje
    // Llama al BOS-Auth-Engine interno para evaluación del score (HTTP a servicio interno)
    void authenticate(AuthenticationFlowContext context);

    void action(AuthenticationFlowContext context);

    boolean requiresUser();

    boolean configuredFor(KeycloakSession session,
                          RealmModel realm,
                          UserModel user);

    void setRequiredActions(KeycloakSession session,
                             RealmModel realm,
                             UserModel user);

    // Condición de fallo: score < threshold →
    // context.failure(AuthenticationFlowError.ACCESS_DENIED)
    // Si el servicio BOS-Auth-Engine no responde → on_failure configurable:
    //   "deny_on_unavailable" (default seguro) o "allow_on_unavailable" (degraded mode)
}
```

### BOS-SmartCardPIN-SPI

```java
// Interfaz: org.keycloak.authentication.Authenticator
// Clase: SkbosSmartCardPinAuthenticator
// smart_card_pin = X.509 (nativo) + PIN adicional del chip vía PKCS#11

public interface Authenticator {

    // Asume que X.509 ya fue validado en fase anterior del flow
    // Solicita PIN al usuario → lo envía al middleware PKCS#11 del cliente
    // (requiere extensión del cliente o aplicación SBOS VDI)
    // Valida PIN contra el chip del smart card vía PKCS#11
    void authenticate(AuthenticationFlowContext context);

    void action(AuthenticationFlowContext context);

    boolean requiresUser();

    // Verifica que el usuario tiene smart card con PIN configurado
    boolean configuredFor(KeycloakSession session,
                          RealmModel realm,
                          UserModel user);

    void setRequiredActions(KeycloakSession session,
                             RealmModel realm,
                             UserModel user);

    // Condición de fallo: PIN incorrecto →
    // context.failure(AuthenticationFlowError.INVALID_CREDENTIALS)
    // PIN incorrecto 3 veces → tarjeta bloqueada (el hardware bloquea, KC registra el evento)
}
```

---

## 5. Tabla de referencia definitiva

| Método | Nativo KC 26 | KC gestiona | KC NO gestiona | Dominio SBOS |
|---|---|---|---|---|
| Username + Password | ✓ Completo | Hash, políticas, brute-force | Gestores externos, brechas | Todos |
| TOTP | ✓ Completo | Secreto, QR, validación matemática | App del usuario, teléfono | LA estándar, FT |
| HOTP | ✓ Completo | Contador, validación | App del usuario | LA alternativo |
| Recovery Codes | ✓ Completo | Generación, invalidación | Almacenamiento del usuario | Emergency fallback |
| WebAuthn/FIDO2 HW | ✓ Completo | Clave pública, challenge, firma | Hardware físico, PIN del key | LA high, FT high |
| Passkeys | ✓ KC 26.4 | Todo WebAuthn + UI condicional | Sincronización entre dispositivos | LA estándar |
| X.509 / Smart Card | ✓ Completo | Validación cert, CRL/OCSP, mapeo DN | CA, emisión certs, PKI, PIN chip | LA high, FT, PA |
| Magic Link | ✓ Completo | Token, email via SMTP, TTL | Entregabilidad, seguridad email | LA alternativo |
| SMS OTP | ✗ Requiere SPI | Generación código, TTL, validación | Entrega SMS (Twilio, AWS SNS) | FT estándar |
| Email OTP | ✓ KC 26 | Generación código, email, TTL | Seguridad email del usuario | LA alternativo |
| WebAuthn Biométrico | ✓ Completo | Clave pública, challenge, firma | Sensor, enclave seguro, biometría | LA high, FT high |
| Kerberos/SPNEGO | ✓ Completo | Validación ticket, mapeo principal | KDC, red corporativa | LA corporativo |
| Social Login / OIDC | ✓ Completo | Flujo OAuth2, mapeo, provisioning | Seguridad del IdP externo | Federación |
| LDAP / AD | ✓ Completo | Bind, sync, mapeo atributos | Servidor LDAP | Federación |
| Security Questions | ✗ Solo SPI | Via SPI custom | Todo | No recomendado |

**Dominio SBOS:** LA = logical_access, FT = financial_transactions, PA = physical_access

---

## 6. Mapa final: métodos del SBOS → implementación Keycloak

```
EstructuraRolFinal              → Implementación exacta en Keycloak
──────────────────────────────────────────────────────────────────────

username_password               → Username Password Form (nativo)
2fa_app                         → OTP Form / TOTP (nativo)
biometric_login                 → WebAuthn Passwordless Authenticator (nativo)
security_key                    → WebAuthn Authenticator (nativo)
hardware_token                  → WebAuthn Authenticator modo hardware (nativo)
email_verification_code         → Email OTP (nativo KC 26)
mobile_app_token                → TOTP via app (nativo) o SMS OTP (BOS-SMS-SPI)

smart_card_logical              → WebAuthn + YubiKey PIV / X.509 (nativo)
biometric_scan                  → WebAuthn biométrico (nativo) — SOLO digital
fingerprint                     → WebAuthn biométrico con userVerification=REQUIRED
proximity_card                  → Sistema físico externo → bridge
qr_code_access                  → Sistema físico externo → bridge
facial_recognition              → Sistema físico externo → bridge
mobile_device_authentication    → WebAuthn en móvil (nativo)

smart_card_pin                  → X.509 + PIN (X.509 nativo + BOS-SmartCardPIN-SPI)
mobile_token                    → SMS OTP (BOS-SMS-SPI) o TOTP app (nativo)
biometric_validation            → WebAuthn biométrico con userVerification=REQUIRED
digital_signature               → X.509 con KeyUsage=digitalSignature (nativo)
hardware_security_token         → WebAuthn Authenticator (nativo)
voice_authentication            → ✗ No disponible — requiere sistema externo completo
security_questions              → ✗ Débil — no recomendado
```

---

## 7. Conclusión: la frontera real de Keycloak

Keycloak es muy capaz como IdP. Gestiona completamente todos los métodos basados en conocimiento (contraseñas, OTP) y todos los métodos basados en criptografía de clave pública (WebAuthn, X.509, Passkeys).

Su frontera natural es el **mundo físico**: no controla hardware, no lee biometría, no abre puertas. Para todo eso, el SBOS usa el bridge como intermediario que traduce los atributos del rol almacenados en Keycloak hacia los sistemas físicos externos.

El SBOS tiene que construir **5 SPIs** para completar el modelo de dominios: Guard, FinancialPeriod, GeoContext, BehavioralScore, SmartCardPIN. El resto lo resuelve Keycloak nativo.

---

*SKULL · SBOS · SBOS-019-KC-AUTH-METHODS · v3.0 · Marzo 2026*
*Reemplaza: SBOS-016-KC-AUTH-METHODS v1.0 — SUPERSEDED*
-e 
---

## Catálogo de Configuración Keycloak y Kong por Aplicación Base

> **Integrado desde SBOS-019-001 en v3.0.**

```
Realm:       sbos (único realm para el tenant)
Domain:      {{DOMAIN}} (del seed file, ej: skull.io)
Client IDs:  nombre-de-la-app en lowercase
Roles KC:    {app}-admin, {app}-operator, {app}-viewer
Kong plugins: jwt (verificación JWT KC), rate-limiting (por defecto), cors
Namespace K8s: sbos-{servidor} (ej: sbos-erp, sbos-comms, sbos-apps)
```

---

## 2. Aplicaciones de Infraestructura (producto: bootstrap)

Estas apps se instalan con el bootstrap y ya tienen configuración de seguridad base.

### Grafana

```yaml
keycloak:
  client_id: "grafana"
  protocol: "openid-connect"
  root_url: "https://{{DOMAIN}}/grafana"
  redirect_uris: ["https://{{DOMAIN}}/grafana/*"]
  web_origins: ["https://{{DOMAIN}}"]
  roles: ["grafana-admin", "grafana-editor", "grafana-viewer"]
  default_role: "grafana-viewer"

kong:
  route: "/grafana"
  service: "grafana.sbos-monitor.svc:3000"
  plugins: ["jwt", "rate-limiting", "cors"]
  strip_path: false

postgresql:
  database: "grafana_db"
  owner: "grafana"
```

### PgAdmin 4

```yaml
keycloak:
  client_id: "pgadmin"
  protocol: "openid-connect"
  root_url: "https://{{DOMAIN}}/pgadmin"
  redirect_uris: ["https://{{DOMAIN}}/pgadmin/*"]
  roles: ["pgadmin-admin"]
  note: "Solo accesible por sbos-admin — no visible para usuarios normales"

kong:
  route: "/pgadmin"
  service: "pgadmin.sbos-data.svc:5050"
  plugins: ["jwt", "rate-limiting", "ip-restriction"]
  ip_restriction: ["10.0.0.0/8"]  # solo red interna

postgresql:
  database: "pgadmin_db"
  owner: "pgadmin"
```

---

## 3. Aplicaciones de Negocio Core

### Tryton ERP (producto: erp)

```yaml
keycloak:
  client_id: "tryton"
  protocol: "openid-connect"
  root_url: "https://{{DOMAIN}}/erp"
  redirect_uris: ["https://{{DOMAIN}}/erp/*"]
  web_origins: ["https://{{DOMAIN}}"]
  roles:
    - "tryton-admin"        # Full access
    - "tryton-accountant"   # Contabilidad + facturación
    - "tryton-sales"        # Ventas + inventario lectura
    - "tryton-warehouse"    # Inventario + compras
    - "tryton-viewer"       # Solo lectura global
  default_role: "tryton-viewer"
  auth_flow: "browser"
  required_actions: ["UPDATE_PASSWORD"]

kong:
  route: "/erp"
  service: "tryton.sbos-erp.svc:8000"
  plugins: ["jwt", "rate-limiting", "cors"]
  rate_limit: "100/minute"

postgresql:
  database: "tryton_db"
  owner: "tryton"

bauth:
  bitmask_bit: 2  # APP_TRYTON
  governance_category: 3  # operación destructiva requiere dual approval
```

### OrangeHRM (producto: hr)

```yaml
keycloak:
  client_id: "orangehrm"
  protocol: "openid-connect"
  root_url: "https://{{DOMAIN}}/hr"
  redirect_uris: ["https://{{DOMAIN}}/hr/*"]
  web_origins: ["https://{{DOMAIN}}"]
  roles:
    - "hr-admin"       # Full RRHH
    - "hr-manager"     # Gestión de equipo
    - "hr-employee"    # Portal del empleado (solo sus datos)
    - "hr-viewer"      # Solo lectura
  default_role: "hr-employee"
  note: "Usa MySQL como BD. SymmetricDS sincroniza con PostgreSQL para bKernel"

kong:
  route: "/hr"
  service: "orangehrm.sbos-apps.svc:80"
  plugins: ["jwt", "rate-limiting", "cors"]

postgresql:
  note: "OrangeHRM usa MySQL. La BD orangehrm_mysql es sincronizada por SymmetricDS"

bauth:
  bitmask_bit: 3  # APP_ORANGEHRM
```

---

## 4. Aplicaciones de Comunicación (producto: mail)

### Roundcube Webmail

```yaml
keycloak:
  client_id: "roundcube"
  protocol: "openid-connect"
  root_url: "https://{{DOMAIN}}/mail"
  redirect_uris: ["https://{{DOMAIN}}/mail/*"]
  roles: ["mail-user"]
  default_role: "mail-user"
  note: "Todos los empleados tienen acceso a correo por defecto"

kong:
  route: "/mail"
  service: "roundcube.sbos-comms.svc:8080"
  plugins: ["jwt", "cors"]
```

### PostfixAdmin

```yaml
keycloak:
  client_id: "postfixadmin"
  root_url: "https://{{DOMAIN}}/postfixadmin"
  redirect_uris: ["https://{{DOMAIN}}/postfixadmin/*"]
  roles: ["mail-admin"]
  note: "Solo accesible por administradores de correo"

kong:
  route: "/postfixadmin"
  service: "postfixadmin.sbos-comms.svc:8080"
  plugins: ["jwt", "rate-limiting", "ip-restriction"]
```

---

## 5. Aplicaciones de Observabilidad (producto: monitoring)

### Zabbix

```yaml
keycloak:
  client_id: "zabbix"
  root_url: "https://{{DOMAIN}}/zabbix"
  redirect_uris: ["https://{{DOMAIN}}/zabbix/*"]
  roles: ["zabbix-admin", "zabbix-viewer"]

kong:
  route: "/zabbix"
  service: "zabbix.sbos-monitor.svc:8080"
  plugins: ["jwt", "rate-limiting"]

postgresql:
  database: "zabbix_db"
  owner: "zabbix"
```

---

## 6. Aplicaciones de Gestión Documental (producto: documents)

### Paperless-NGX

```yaml
keycloak:
  client_id: "paperless"
  root_url: "https://{{DOMAIN}}/docs"
  redirect_uris: ["https://{{DOMAIN}}/docs/*"]
  roles: ["docs-admin", "docs-editor", "docs-viewer"]
  default_role: "docs-viewer"

kong:
  route: "/docs"
  service: "paperless.sbos-docs.svc:8000"
  plugins: ["jwt", "rate-limiting", "cors"]

postgresql:
  database: "paperless_db"
  owner: "paperless"
```

### DocuSeal (Firma digital)

```yaml
keycloak:
  client_id: "docuseal"
  root_url: "https://{{DOMAIN}}/sign"
  redirect_uris: ["https://{{DOMAIN}}/sign/*"]
  roles: ["sign-admin", "sign-signer"]

kong:
  route: "/sign"
  service: "docuseal.sbos-docs.svc:3000"
  plugins: ["jwt", "cors"]

postgresql:
  database: "docuseal_db"
  owner: "docuseal"
```

---

## 7. Aplicaciones de CI/CD y Backup (producto: devops)

### GitLab CE

```yaml
keycloak:
  client_id: "gitlab"
  root_url: "https://{{DOMAIN}}/gitlab"
  redirect_uris: ["https://{{DOMAIN}}/gitlab/*"]
  roles: ["gitlab-admin", "gitlab-developer", "gitlab-viewer"]
  note: "Solo accesible por equipo técnico del cliente"

kong:
  route: "/gitlab"
  service: "gitlab.sbos-ops.svc:80"
  plugins: ["jwt", "rate-limiting"]

postgresql:
  database: "gitlab_db"
  owner: "gitlab"
```

---

## 8. Aplicaciones Opcionales (IA, VDI)

### Open WebUI (producto: ai)

```yaml
keycloak:
  client_id: "openwebui"
  root_url: "https://{{DOMAIN}}/ai"
  redirect_uris: ["https://{{DOMAIN}}/ai/*"]
  roles: ["ai-admin", "ai-analyst", "ai-viewer"]

kong:
  route: "/ai"
  service: "open-webui.sbos-ai.svc:8080"
  plugins: ["jwt", "rate-limiting"]
```

### SBOS VDI (producto: vdi)

```yaml
keycloak:
  client_id: "kasm"
  root_url: "https://{{DOMAIN}}/desktop"
  redirect_uris: ["https://{{DOMAIN}}/desktop/*"]
  roles: ["vdi-admin", "vdi-user"]
  note: "VDI usa el RolTemplate completo para configurar el escritorio del usuario"

kong:
  route: "/desktop"
  service: "kasm.sbos-vdi.svc:443"
  plugins: ["jwt"]
```

---

## 9. Resumen: Mapa de Rutas y Bits

| Path | App | KC Client | BitMask Bit | Producto |
|------|-----|-----------|:-----------:|----------|
| `/erp` | Tryton | tryton | 2 | erp |
| `/hr` | OrangeHRM | orangehrm | 3 | hr |
| `/mail` | Roundcube | roundcube | — | mail |
| `/postfixadmin` | PostfixAdmin | postfixadmin | — | mail |
| `/docs` | Paperless-NGX | paperless | — | documents |
| `/sign` | DocuSeal | docuseal | — | documents |
| `/grafana` | Grafana | grafana | — | bootstrap |
| `/pgadmin` | PgAdmin 4 | pgadmin | — | bootstrap |
| `/zabbix` | Zabbix | zabbix | — | monitoring |
| `/gitlab` | GitLab | gitlab | — | devops |
| `/ai` | Open WebUI | openwebui | — | ai |
| `/desktop` | Kasm (VDI) | kasm | — | vdi |

---

## 10. Registro de Cambios

### v1.0 — Marzo 2026

Documento nuevo. Catálogo de configuración Keycloak (client, roles, flows) y Kong (rutas, plugins) para 12 aplicaciones base del stack, organizadas por producto. Incluye BDs PostgreSQL, bits de BitMask, y notas de integración.

---

*SKULL · SBOS · SBOS-019-001 · Anexo 001 · v1.0 · Marzo 2026*
