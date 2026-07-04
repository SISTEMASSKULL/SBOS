# SBOS — Administración y Gestión de Tokens de Autenticación
## Investigación Profesional: QR, NFC, TOTP, Push — Ciclo de Vida Completo
### SKULL · SBOS · Junio 2026 · v1.0

**Propósito:** Documentar estándares, mejores prácticas y arquitectura para la administración y gestión de tokens de autenticación (QR, NFC, TOTP/HOTP, Push) en sistemas de control de acceso. Cubre el ciclo de vida completo: generación → aprovisionamiento → entrega al interesado → activación → uso → rotación → revocación.

**Código:** SBOS-BAUTH-TOKEN-ADMINISTRACION-v1.0
**Complementa:** B22 (Authentication Document Provider), B9 (Authentication Policies)

---

## 1. Principios Fundamentales (NIST SP 800-63B Rev.4)

### 1.1 Jerarquía de Métodos de Autenticación

NIST SP 800-63B Rev.4 establece una jerarquía clara de métodos, del más seguro al menos:

| Nivel | Método | Canal de Entrega | AAL |
|-------|--------|-----------------|-----|
| **AAL3** | FIDO2/WebAuthn (hardware security key) | Físico (USB/NFC/BLE) | Máxima seguridad |
| **AAL3** | Passkey (platform authenticator con User Verification) | Integrado en SO (TouchID, Windows Hello) | Alta seguridad |
| **AAL2** | TOTP (RFC 6238) vía app authenticator | QR otpauth:// escaneado en app | Requiere posesión del dispositivo |
| **AAL2** | HOTP (RFC 4226) para hardware tokens | Físico (token hardware) | Secuencial, no basado en tiempo |
| **AAL1** | OTP vía SMS (DEPRECADO por NIST) | SMS | Vulnerable a SIM-swap, interceptación |
| **AAL1** | OTP vía email | Email | Vulnerable a phishing, account takeover |

### 1.2 Reglas No Negociables de Entrega (NIST SP 800-63B §5.1)

| Regla | Fundamento |
|-------|-----------|
| **Nunca enviar el secreto y el canal de autenticación por la misma vía** | Si el atacante compromete un canal, no compromete ambos |
| **QR nunca por SMS/email** — solo presencial o app | SMS/email no son canales seguros para secretos criptográficos |
| **Cribado obligatorio** de contraseñas contra HIBP antes de emitir | NIST §5.1.1.2 |
| **Recovery codes** hasheados con SHA-256, nunca en texto plano | ISO 27001 A.8.2 |
| **Forzar cambio** en primer uso (forced password change) | NIST AC-2 |

---

## 2. Ciclo de Vida del Token de Autenticación

```
┌─────────────────────────────────────────────────────────────────┐
│           CICLO DE VIDA DEL TOKEN DE AUTENTICACIÓN               │
│                                                                   │
│  1. SOLICITUD                                                     │
│     ├── Admin o sistema solicita token para usuario              │
│     ├── Validar identidad del usuario (SEGIP, onboarding KYC)    │
│     └── Definir tipo de token según tier del rol                │
│                                                                   │
│  2. GENERACIÓN                                                    │
│     ├── TOTP: generar secret (RFC 6238) + QR otpauth://         │
│     ├── HOTP: generar secret (RFC 4226) + counter=0             │
│     ├── NFC: generar NDEF record + HMAC-SHA256 tag              │
│     ├── QR físico: generar PDF con QR + código de verificación  │
│     ├── Push: registrar device_token en FCM/APNs                │
│     └── Recovery codes: generar 10 códigos, SHA-256 hash        │
│                                                                   │
│  3. APROVISIONAMIENTO                                             │
│     ├── Digital (app): mostrar QR en pantalla → escanear        │
│     ├── Físico (NFC): escribir en tag vía NFC Writer            │
│     ├── Impreso (QR): generar PDF → imprimir → entregar         │
│     ├── Transmitido (SMS): enviar OTP (solo 1 uso, TTL 5min)   │
│     ├── Transmitido (email): enviar link/OTP (TTL 15min)        │
│     └── Transmitido (Push): FCM/APNs → notificación             │
│                                                                   │
│  4. ENTREGA AL INTERESADO                                         │
│     ├── Presencial: validar identidad + entregar token físico   │
│     ├── Remoto seguro: canal cifrado + autenticación previa     │
│     ├── Self-service: portal de autogestión (B11.T26)           │
│     └── Registro de entrega: timestamp, destinatario, canal     │
│                                                                   │
│  5. ACTIVACIÓN                                                    │
│     ├── TOTP: usuario escanea QR → app genera primer código     │
│     ├── NFC: usuario presenta tag → sistema valida HMAC         │
│     ├── Recovery codes: usuario confirma recepción              │
│     └── Verificación: probar el token → marcar ACTIVO           │
│                                                                   │
│  6. USO                                                           │
│     ├── Validación en cada autenticación                        │
│     ├── Anti-replay: nonce + timestamp por uso                  │
│     ├── Rate limiting: 5 intentos → bloqueo                     │
│     └── Auditoría: cada uso registrado con ctx_id               │
│                                                                   │
│  7. ROTACIÓN                                                      │
│     ├── TOTP: regen secret cada 90 días (opcional)              │
│     ├── NFC: reescribir tag con nuevo HMAC                      │
│     ├── Recovery codes: regenerar al usar 50% de códigos        │
│     └── Período de transición: ambos tokens válidos 24h         │
│                                                                   │
│  8. REVOCACIÓN                                                    │
│     ├── Manual: admin revoca token (offboarding, pérdida)       │
│     ├── Automática: expiración, inactividad, sospecha           │
│     ├── Invalidación inmediata de todas las sesiones            │
│     └── Auditoría obligatoria de revocación                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Tipos de Token — Estándares y Mejores Prácticas

### 3.1 Token TOTP (RFC 6238) — QR Code

**Estándar:** RFC 6238 (TOTP: Time-Based One-Time Password Algorithm)

**Generación del secreto:**
```
secret = random_bytes(20)  // 160 bits (recomendado por RFC 6238 §4)
secret_base32 = base32_encode(secret)
qr_uri = "otpauth://totp/SBOS:{username}?secret={secret_base32}&issuer=SBOS&algorithm=SHA256&digits=6&period=30"
```

**Entrega del QR:**
- **PRESENCIAL:** Mostrar QR en pantalla durante onboarding. El usuario escanea con app authenticator (Google Authenticator, Authy, Bitwarden).
- **REMOTO SEGURO:** Portal de autogestión (B11.T26) — solo accesible con sesión válida y MFA previo.
- **NUNCA por email/SMS:** El QR contiene el secreto en texto plano (base32). Enviarlo por email expone el secreto.

**Almacenamiento del secreto:**
- Secreto encriptado con AES-256-GCM en `bauth_mfa_enrollments`
- Clave de cifrado en Vault Transit
- Nunca en texto plano en BD

**Verificación:**
```
TOTP = HMAC-SHA256(secret, floor(unix_time / 30))
code = TOTP % 10^6  // 6 dígitos
valid = (input_code == code)
```

### 3.2 Token HOTP (RFC 4226) — Hardware Token / NFC

**Estándar:** RFC 4226 (HOTP: An HMAC-Based One-Time Password Algorithm)

**Generación:**
```
secret = random_bytes(20)
counter = 0  // persistido en BD, incrementa en cada uso
HOTP = HMAC-SHA256(secret, counter)
code = dynamic_truncate(HOTP) % 10^6
```

**Aprovisionamiento NFC:**
- Grabar en tag NFC (NTAG424DNA con Secure Dynamic Messaging)
- NDEF Type 4: URL con otpauth:// (como TOTP pero con counter)
- AES-128 en el canal NFC (NFC Forum Type 4 Tag)
- Anti-clonación: NTAG424DNA usa autenticación mutua

**Estándares NFC relevantes:**
- **GlobalPlatform** — gestión de Secure Element, OTA provisioning
- **MIFARE4Mobile v2.1.1** — interoperabilidad de servicios MIFARE en SE
- **Apple SecureElementCredential** — credenciales en Secure Element de iOS
- **ISO 7816** — APDU commands para smart cards

### 3.3 Token QR Físico — Impreso en Papel

**Caso de uso:** Usuarios sin smartphone (común en Bolivia, ~40% de la población).

**Generación:**
```
qr_data = {
  user_id: uuid,
  token_id: uuid,
  secret: base32_secret,  // cifrado con clave derivada de user_password
  issued_at: ISO8601,
  expires_at: ISO8601,
  issuer: "SBOS - SKULL"
}
qr_image = generate_qr(qr_data, error_correction=H)
pdf = render_pdf(qr_image, user_name, instructions)
```

**Entrega física:**
- Imprimir en papel de seguridad (marca de agua, microtexto)
- Entregar en persona con verificación de identidad
- Registrar: `token_delivery_log (token_id, user_id, delivered_by, delivered_at, signature)`
- El usuario firma recepción (firma digital vía B25 o firma manuscrita escaneada)

**Uso:**
- Usuario presenta el QR impreso al lector
- Lector escanea QR → extrae secret → calcula TOTP → valida
- El QR físico NO contiene el secret en texto plano — cifrado con clave derivada
- Reuso detectado: nonce en cada uso previene replay

**Invalidación:**
- Marcar como `revoked` en BD
- QR físico: notificar al usuario que destruya el papel
- Si el QR se pierde: revocar inmediatamente + emitir nuevo token

### 3.4 Token Push Notification — FCM/APNs

**Estándar:** Firebase Cloud Messaging (FCM) / Apple Push Notification Service (APNs)

**Registro del dispositivo:**
```
POST /bauth/device/register
{
  user_id: uuid,
  device_token: "fcm_token_or_apns_token",
  platform: "android" | "ios",
  device_name: "Samsung Galaxy S25"
}
```

**Flujo de autenticación Push:**
1. Usuario intenta login → bAuth envía push al dispositivo registrado
2. Usuario recibe notificación: "¿Estás intentando iniciar sesión? [Aprobar] [Denegar]"
3. Usuario presiona [Aprobar] → dispositivo envía firma criptográfica a bAuth
4. bAuth verifica firma → login exitoso

**Seguridad:**
- El push NO contiene secretos — solo un challenge nonce
- La respuesta del usuario está firmada con clave del dispositivo (TPM/Secure Enclave)
- Anti-replay: nonce único por challenge
- Timeout: 60 segundos

### 3.5 Recovery Codes — Respaldo de Emergencia

**Estándar:** NIST SP 800-63B §5.1.6 (Look-up Secrets)

**Generación:**
```
for i in 1..10:
  code = random_bytes(4)  // 8 caracteres hexadecimales
  store(code_hash[i] = SHA-256(code))
  show_to_user(code)  // UNA SOLA VEZ
```

**Entrega:**
- Mostrar en pantalla durante onboarding — UNA SOLA VEZ
- El usuario debe guardarlos (imprimir, anotar, password manager)
- NUNCA almacenar en texto plano en BD — solo SHA-256 hashes
- Si el usuario pierde los códigos → regenerar set completo (invalida anteriores)

**Uso:**
- Cada código es de UN SOLO USO
- Al usar: verificar `SHA-256(input) == stored_hash` → marcar como USADO
- Umbral de alerta: cuando quedan ≤3 códigos sin usar → sugerir regenerar

---

## 4. Entrega al Interesado — Procedimientos por Canal

### 4.1 Entrega Presencial

```
1. Verificar identidad del interesado (documento SEGIP, biometría)
2. Generar token según tipo y tier del rol
3. Entregar token físicamente:
   - NFC: entregar tag NFC programado
   - QR impreso: entregar hoja impresa
   - App TOTP: mostrar QR en pantalla para escanear
   - Recovery codes: mostrar en pantalla UNA SOLA VEZ
4. Registrar entrega: token_delivery_log
5. Interesado firma recepción (digital o manuscrita)
6. Activar token: probar funcionamiento
7. Auditoría: token_delivery_audit_event
```

### 4.2 Entrega Remota Segura

```
1. Usuario autentica en portal de autogestión (B11.T26)
   con credenciales existentes + MFA previo
2. Usuario solicita nuevo token (ej: TOTP para nuevo teléfono)
3. Sistema verifica identidad vía canal alterno:
   - Si ya tiene sesión activa: autorizar
   - Si no: enviar código de verificación a email/teléfono registrado
4. Mostrar QR en pantalla (HTTPS, sin cache, no almacenar en servidor)
5. Usuario escanea QR con su app authenticator
6. Usuario ingresa primer código TOTP para verificar
7. Registrar entrega: token_delivery_log (canal=remote_secure)
```

### 4.3 Entrega Self-Service (B11.T26)

```
1. Usuario hace login en portal de autogestión
2. Navega a "Mis Dispositivos" → "Agregar Authenticator"
3. Sistema muestra QR en pantalla
4. Usuario escanea → verifica → token activo
```

---

## 5. Almacenamiento Seguro de Tokens

| Token | Dónde se almacena | Cifrado |
|-------|------------------|---------|
| **TOTP secret** | `bauth_mfa_enrollments` | AES-256-GCM, clave en Vault Transit |
| **HOTP secret + counter** | `bauth_mfa_enrollments` | AES-256-GCM, counter en texto plano (no es secreto) |
| **NFC HMAC key** | Tag NFC (NTAG424DNA) | AES-128 Secure Dynamic Messaging en chip |
| **Push device_token** | `bauth_push_tokens` | AES-256-GCM |
| **Recovery codes** | `bauth_recovery_codes` | SHA-256 hash (solo hash, nunca texto plano) |
| **QR físico secret** | `bauth_qr_tokens` | AES-256-GCM, clave derivada de user_password + salt |
| **Certificados mTLS** | Vault PKI | Clave privada nunca sale del HSM |

---

## 6. Matriz de Conformidad con B22 (REGISTRO-ESTADO)

| Átomo B22 | Tipo de Token | Canal de Entrega | Estándar |
|-----------|--------------|-----------------|----------|
| B22.T01 | `QrDocument` — QR dinámico | Pantalla (presencial/remoto) | RFC 6238 |
| B22.T02 | `NfcDocument` — NFC físico | Escritura en tag NFC | ISO 7816, NFC Forum |
| B22.T03 | `TokenDocument` — TOTP/HOTP | App authenticator (QR) | RFC 6238, RFC 4226 |
| B22.T04 | `QrPhysicalDocument` — QR impreso | Impresión en papel | ISO 18004 (QR Code) |
| B22.T05 | `TokenSmsDocument` — SMS (DEPRECADO) | SMS | Solo para AAL1 legacy |
| B22.T06 | `TokenEmailDocument` — Email | Email cifrado (TLS) | Solo para AAL1 |
| B22.T07 | `PushDocument` — Push notification | FCM/APNs | AAL2 (firma criptográfica) |
| B22.T08 | `IdentityDocument` — Credencial NFC/QR | Tag NFC / QR impreso | HMAC-SHA256 |
| B22.T09 | `RecoveryCodeDocument` — Códigos de recuperación | Pantalla (una sola vez) | SHA-256 hash |
| B22.T10 | `BatchQrDocument` — QR masivo para múltiples usuarios | PDF multi-página | ISO 18004 |
| B22.T11 | Tests + anti-replay integrales | Todos los canales | BAUTH-050 |

**Faltante en B22:** GAP — Falta un átomo para `TokenDeliveryAudit` (registro de entrega con firma del interesado) y `TokenRotationEngine` (rotación de tokens con período de transición).

---

## 7. Referencias

- [RFC 6238 — TOTP: Time-Based One-Time Password Algorithm](https://datatracker.ietf.org/doc/html/rfc6238)
- [RFC 4226 — HOTP: An HMAC-Based One-Time Password Algorithm](https://datatracker.ietf.org/doc/html/rfc4226)
- [NIST SP 800-63B Rev.4 — Digital Identity Guidelines](https://csrc.nist.gov/pubs/sp/800/63/b/final)
- [GlobalPlatform — Secure Element Management](https://globalplatform.org/)
- [MIFARE4Mobile v2.1.1](https://www.mifare4mobile.org/)
- [Apple SecureElementCredential Framework](https://developer.apple.com/documentation/SecureElementCredential)
- [NFC Forum — Type 4 Tag Specification](https://nfc-forum.org/)
- [NTAG424DNA — Secure Dynamic Messaging](https://www.nxp.com/products/rfid-nfc/nfc-hf/ntag-for-tags-labels/ntag-424-dna:NTAG424DNA)
- [ISO/IEC 18004:2015 — QR Code Bar Code Symbology](https://www.iso.org/standard/62021.html)
- [ISO 7816 — Smart Card Standard](https://www.iso.org/standard/54001.html)
- [FIDO2/WebAuthn W3C Recommendation](https://www.w3.org/TR/webauthn-3/)
- [OWASP — Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)

---

*SKULL · SBOS · SBOS-BAUTH-TOKEN-ADMINISTRACION-v1.0 · Junio 2026*
*Confidencial — Propiedad de SKULL Desarrollo de Software*
