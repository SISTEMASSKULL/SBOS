# A.44 — Anexo de Arquitectura y Completitud de los Métodos de Autenticación

**Manual madre:** `2.02` · **Versión:** 1.3.0 · **Fecha:** 2026-07-11
**Relacionado:** 2.01 §3 (motor `MethodRegistry`) · 1.08 §5 (UserTemplate) · 1.09 B4 (RolTemplate) · 2.04 (firma) · A.42 §10.ter (Módulo Criptográfico) · ADR-012

---

## 0. Para qué sirve este anexo — cómo leerlo

El manual 2.02 **describe** cada método. Este anexo lo **especifica como operación**: qué recibe, qué
consume **exactamente** de cada plantilla, qué devuelve, cómo se evalúa, un **ejemplo de la vida
real**, y **cómo validar** que está completo y cumple la norma. Es la verificación de completitud
método por método.

**El formato de cada ficha:**

| Campo | Qué dice |
|-------|----------|
| **Petición →** | Datos que llegan en la solicitud (el código tecleado, la firma recibida). |
| **← UserTemplate §5** | Los **campos exactos** del usuario que consume (su autenticador enrolado). |
| **← RolTemplate B4** | Los **campos exactos** del rol que consume (la exigencia: LoA, `requiredMethods`, step-up). |
| **Devuelve →** | El veredicto + evidencia (AAL alcanzado, motivo si falla). |
| **Verificar** | Cómo bAuth evalúa la prueba, según la norma. |
| **🌍 Ejemplo real** | Un caso concreto del mundo real. |
| **✔ Validar** | Cómo comprobar **completitud** (qué debe estar) y **cumplimiento de norma** (qué prueba/vector). |
| **Capas · Estado** | `motor`→`cripto`→`bóveda` + archivo real + ✅/🔄/⬜/🚫. |

---

## 1. El Motor de Métodos — el punto ÚNICO de validación

### 1.1 El principio: un solo motor, cero validación dispersa (la reparación)

bAuth **no valida ningún método por su cuenta ni invoca criptografía suelta**. Existe **un motor
único** —el `MethodRegistry` (2.01 §3.3, patrón PAM)— donde se **registran los 47 métodos** y por el
que pasa **toda** validación. bAuth **acude al motor** para *usar, aplicar o consultar* un método, y
recibe **un** resultado (`VeredictoAuth`) para el cliente. Es al método de autenticación lo que el
**Gestor de Canales** (2.12) es al transporte y el **Módulo Criptográfico** (ADR-012) al cifrado:
centralizar lo que hoy está disperso.

> **Regla dura:** si algo valida un método, invoca un OTP o comprueba una firma **fuera de este
> motor**, es un defecto a reparar. El motor es la **única puerta** de los métodos.

### 1.2 La fachada única — cómo bAuth habla con el motor

Un solo punto de entrada; nada fuera de aquí valida métodos:

```rust
pub trait MotorDeMetodos {
    /// APLICAR un método (o combinación) para autenticar → el veredicto para el cliente.
    async fn aplicar(&self, sol: SolicitudAuth) -> Result<VeredictoAuth, MotorError>;
    /// ENROLAR / REVOCAR — ciclo de vida del método para un usuario.
    async fn enrolar(&self, usuario: &Uuid, metodo: MetodoId, params: ParamsEnrol) -> Result<EnrollResult, MotorError>;
    async fn revocar(&self, usuario: &Uuid, instancia: InstanciaId) -> Result<(), MotorError>;
    /// CONSULTAR — inventario: qué métodos hay, cuáles tiene el usuario, cuáles exige el rol.
    fn consultar(&self, filtro: FiltroMetodos) -> Vec<InfoMetodo>;
}
```

Entra **un** tipo (`SolicitudAuth{usuario, rol, metodo, peticion}`), sale **un** tipo
(`VeredictoAuth{valida, aal_alcanzado, motivo}`). El cliente no conoce el mecanismo interno del método.

### 1.3 El flujo de punta a punta — todo ocurre DENTRO del motor

```
bAuth ──► motor.aplicar(SolicitudAuth{usuario, rol, metodo, petición})
            1. lee RolTemplate B4  → requiredMethods, LoA exigido, step-up
            2. lee UserTemplate §5 → el autenticador enrolado (por credential_id)
            3. despacha al método registrado  (o a la SAGA si el rol exige varios)
            4. el método usa el MÓDULO CRIPTOGRÁFICO (capa interna) para la primitiva
            5. arma VeredictoAuth y lo contrasta con B4 (aal ≥ exigido · método ∈ pool)
       ◄── VeredictoAuth   (permite · exige step-up · rechaza)
```

Las **combinaciones** (AAL2 = contraseña + OTP) son **sagas internas** del motor (2.01 §9); el
**Módulo Criptográfico** es su **capa interna** de primitivas. Ni las sagas ni la cripto son piezas
sueltas: **son partes del motor**, invisibles para quien lo llama.

### 1.4 Las tres capas — todas DENTRO del motor
```
  MOTOR DE MÉTODOS   → sabe el PROTOCOLO de la norma (qué bytes se arman, qué se compara).
        │
  MÓDULO CRIPTOGRÁFICO → EJECUTA la primitiva (firmar/verificar/hash/HMAC). — A.42 §10.ter, ADR-012
        │
  BÓVEDA (Vault)       → CUSTODIA las claves. La clave nunca sale.
```
La criptografía **no está afuera**: es la capa de abajo del motor. **Regla de oro:** el motor conoce
la norma; el módulo cripto, el algoritmo; la bóveda, la clave.

### 1.5 Todo método es un par: **producir** (genera la prueba) y **verificar** (la evalúa + dicta AAL); más **enrolar**/**revocar** (ciclo de vida).

### 1.6 De dónde salen los datos: **identidad vs autoridad** (qué consume el motor de cada plantilla)

Al aplicar un método, el motor consume **dos cosas de dos plantillas** (separación normada, 1.08 §4.1 / NIST 800-63B):

- **El autenticador enrolado → UserTemplate §5** (`keycloak_credentials`, nombre *legacy*; contenido
  nativo). El sujeto **posee** los autenticadores (NIST §5). Campos: `has_password/has_totp/
  has_webauthn/…`, listas `totp_devices[]`, `webauthn_credentials[]{credential_id,type,aaguid,
  user_verification,attestation_verified}`, `backup_codes.remaining_codes`, y el bloque de
  auto-chequeo `credentials_compliance{covers_required_methods,missing_methods}`.
  > **El material secreto NO está en el template plano** (`password → [NEVER RETURNED]`, 1.08 §8): el
  > `secret` TOTP y la `public_key` COSE se resuelven por `credential_id` contra el almacén de
  > credenciales nativo. El template lleva el **inventario y metadatos**, no la clave.
- **La exigencia → RolTemplate B4** (`logical_access`). La autoridad **exige** un nivel (NIST §4).
  Campos: `requiredMethods[]{method,order,loa}` (qué métodos, en qué orden, con qué LoA),
  el nivel `loa` (1=pwd · 2=MFA · 3=MFA fuerte · 4=WebAuthn+quórum), y `step_up_rules[]{trigger,
  required_loa,max_age_seconds}` (RFC 9470).

**El flujo:** el método verifica la petición contra el autenticador de §5, produce `VeredictoAuth{aal_alcanzado}`, y bAuth lo contrasta con B4: `aal_alcanzado ≥ loa_exigido` **y** `método ∈ requiredMethods` → PERMITE; si falta AAL y `step_up_rules` aplica → eleva.

### 1.7 Meta de diseño (contrato a cerrar)
Hoy el trait recibe `&serde_json::Value` (`mod.rs:62`) — entrada sin tipar. Objetivo: **entradas/
salidas tipadas por método** (`SolicitudAuth`/`VeredictoAuth`, que un campo faltante **no compile**).
Las fichas de abajo son ese contrato objetivo — el registro que el motor único despacha.

### 1.8 Caso transversal — firma digital (2.04)
No autentica, pero usa la misma maquinaria. **Firmar** = cifrar el hash con la clave **privada**;
**verificar** = recalcular el hash y comprobar con la **pública** + validar el certificado (cadena,
vigencia, revocación). Doble motor Ed25519 interno + ADSIB RSA externo (Ley 164, ADR-006; externo ⬜, A.08).

---

## 2. Categoría A — Conocimiento (algo que sabes)

### A.1 — Contraseña + Argon2id · AAL1 · NIST 800-63B §3.1.1 · ✅
- **Código:** `credential.rs` + `password/` · **Petición →** `contraseña`
- **← UserTemplate §5:** `has_password`, `password_expires_at`, `password_strength_score`; el `PHC` se resuelve en el almacén nativo (nunca en el template).
- **← RolTemplate B4:** `requiredMethods[]{method:"password"}`, `loa` (params Argon2id por **tier**).
- **Devuelve →** `VeredictoAuth{valida, aal:1}`
- **Verificar:** recalcular Argon2id con la sal del PHC y comparar en **tiempo constante**; antes, cribado HIBP.
- **🌍 Ejemplo real:** María teclea su contraseña al entrar al ERP; bAuth recalcula el hash Argon2id y coincide con el PHC guardado → AAL1.
- **✔ Validar:** *completitud* → PHC Argon2id, sal única, comparación tiempo-constante, cribado HIBP presentes. *Norma* → parámetros ≥ los de tier (SU: t=5,m=128MB,p=2); `cargo test credential`.
- **Capas:** motor → cripto (`verificar_password`) → sin bóveda.

### A.2 — PIN numérico · AAL1 · FIPS 201 (contexto) · 🔄 P3
- **Petición →** `pin: 6–8 dígitos`
- **← UserTemplate §5:** hash del PIN (por `credential_id` en almacén nativo).
- **← RolTemplate B4:** `requiredMethods[]{method:"pin"}` (tiers de terminal/kiosko) + política de bloqueo.
- **Devuelve →** `VeredictoAuth{valida, aal:1, intentos_restantes}`
- **Verificar:** como contraseña, espacio reducido → **bloqueo tras 3 intentos** obligatorio.
- **🌍 Ejemplo real:** un cajero en un POS sin teclado completo ingresa su PIN de 6 dígitos para abrir turno.
- **✔ Validar:** *completitud* → método `BAUTH_PIN`, contador de bloqueo. *Norma* → lockout ≤ 3 (OWASP ASVS 2.2.1).
- **Capas:** motor → cripto (PBKDF2) → sin bóveda. **Brecha:** falta `pin.rs`.

### A.3 — Patrón gráfico (swipe) · AAL1 · — · ⬜ P4
- **Petición →** `secuencia_puntos:[u8]` · **← UserTemplate §5:** hash de la secuencia · **← RolTemplate B4:** raramente en `requiredMethods` (entropía baja).
- **Devuelve →** `VeredictoAuth{valida, aal:1}` · **Verificar:** normalizar a bytes, tratar como PIN.
- **🌍 Ejemplo real:** desbloqueo de una tablet de inventario en almacén con un trazo.
- **✔ Validar:** *norma* → entropía mínima documentada; mitigación de smudge attacks. **Estado:** no implementado.

### A.4 — Recovery Codes · AAL1 · NIST 800-63B §3.1.2 · ✅
- **Código:** `recovery.rs` · **Petición →** `codigo: 12 chars Base32`
- **← UserTemplate §5:** `backup_codes{generated, remaining_codes, exhausted_at}`; los `SHA-256` en almacén nativo.
- **← RolTemplate B4:** habilitado como **recuperación**, no factor primario.
- **Devuelve →** `VeredictoAuth{valida, aal:1, codigos_restantes}`
- **Verificar:** hashear el recibido, buscar entre no usados, **marcar usado** (uso único, anti-replay).
- **🌍 Ejemplo real:** María perdió el teléfono; usa uno de sus 10 códigos de respaldo impresos; queda con 7.
- **✔ Validar:** *completitud* → 10 códigos, SHA-256, marca de uso único. *Norma* → un solo uso comprobado; `cargo test recovery`.
- **Capas:** motor → cripto (`SHA-256`) → sin bóveda.

### A.5 — Security Questions · — · 🚫 PROHIBIDO
- **Eliminadas** (NIST 800-63B-4, OWASP ASVS 5.0 §2.5): respuestas OSINT-eables. No se enrolan en §5 ni entran en `requiredMethods`. **✔ Validar:** `grep` no debe hallar ningún método de preguntas. Constancia del veto.

---

## 3. Categoría B — Posesión (algo que tienes)

### B.6 — TOTP · AAL2 · RFC 6238 · ✅
- **Código:** `totp.rs` · **Petición →** `codigo: 6 dígitos` · `t: tiempo`
- **← UserTemplate §5:** `has_totp`, `totp_devices[].credential_id` → resuelve el `secret` cifrado + algoritmo/dígitos en el almacén nativo.
- **← RolTemplate B4:** `requiredMethods[]{method:"totp", loa:2}`, exige `loa ≥ 2`.
- **Devuelve →** `VeredictoAuth{valida, aal:2}`
- **Verificar:** recalcular `trunca(HMAC-SHA1(secret,⌊t/30⌋))` para ventana **±1** y comparar en tiempo constante.
- **🌍 Ejemplo real:** María abre Google Authenticator, ve `482913`, lo teclea; bAuth calcula el código del paso de 30 s actual y coincide → AAL2.
- **✔ Validar:** *completitud* → ventana ±1, comparación tiempo-constante, secret cifrado. *Norma* → **vectores RFC 6238 Appendix B** pasan; `cargo test totp`.
- **Capas:** motor (secret+tiempo) → cripto (`HMAC-SHA1/256/512`) → sin bóveda.

### B.7 — HOTP · AAL2 · RFC 4226 · ✅
- **Código:** `hotp.rs` · **Petición →** `codigo: 6 dígitos`
- **← UserTemplate §5:** `has_totp`/instancia HOTP → `secret` + **contador** por `credential_id`.
- **← RolTemplate B4:** `requiredMethods[]{method:"hotp", loa:2}`.
- **Devuelve →** `VeredictoAuth{valida, aal:2, contador_nuevo}`
- **Verificar:** ventana de re-sincronización de 10 pasos adelante; al acertar, fijar el contador.
- **🌍 Ejemplo real:** un token físico Feitian muestra `739104` al pulsarlo; el usuario lo teclea y bAuth resincroniza el contador.
- **✔ Validar:** *completitud* → ventana look-ahead, contador persistido. *Norma* → **vectores RFC 4226** pasan; `cargo test hotp`.
- **Capas:** motor (ventana) → cripto (`HMAC-SHA1`) → sin bóveda.

### B.8 — WebAuthn / FIDO2 Passkey · AAL2-3 · W3C WebAuthn L3 §7.2 · ✅
- **Código:** `webauthn.rs` (corregido 2026-07-11) · **Petición →** `client_data_json` · `authenticator_data` · `signature` · `rp_id`
- **← UserTemplate §5:** `webauthn_credentials[]{credential_id, type, aaguid, user_verification, attestation_verified}` → la `public_key` COSE por `credential_id`.
- **← RolTemplate B4:** `requiredMethods[]{method:"webauthn", loa:3}`; exige `loa ≥ 2` (o `3` si `UV`/hardware).
- **Devuelve →** `VeredictoAuth{valida, aal:(UV?3:2), user_verified}`
- **Verificar (§7.2):** 1) `clientData.type=="webauthn.get"`+challenge; 2) `rpIdHash==SHA-256(rp_id)`+flag `UP`; 3) **verificar firma** con la `public_key` (ES256/Ed25519); 4) `aal=3` si flag `UV`.
- **🌍 Ejemplo real:** María toca su YubiKey 5 al iniciar sesión; el llavero firma el reto; bAuth verifica la firma con la clave pública que ella registró → AAL3.
- **✔ Validar:** *completitud* → verificación real de firma (no `len≥16`), rpIdHash, flags UP/UV. *Norma* → tests fail-closed (firma inválida ⇒ rechazo); `cargo test webauthn`. *Brecha:* attestation (aaguid/FIDO MDS) + signature counter (🔄 AM-12).
- **Capas:** motor (bloque §7.2) → cripto (`verificar_firma`) → sin bóveda.

### B.9 — FIDO2 Security Key (hardware-bound) · AAL2-3 · W3C · ✅
- WebAuthn (B.8) con `webauthn_credentials[].type=="security_key"` y autenticador no exportable. Mismo consumo de templates. **🌍 Ejemplo:** llave física exigida para un admin de dominio. **✔ Validar:** AAL3 requiere `attestation_verified==true` (🔄).

### B.10 — Email OTP · AAL1 (restricted) · NIST 800-63B §3.1.4 · ✅
- **Código:** `email_otp.rs` · **Petición →** `codigo` · `otp_id`
- **← UserTemplate §5:** `has_email_otp` + el correo del usuario (bloque contacto); hash del OTP y TTL en almacén.
- **← RolTemplate B4:** `requiredMethods[]{method:"email_otp"}` — típicamente **solo `EXT_N0`**.
- **Devuelve →** `VeredictoAuth{valida, aal:1}`
- **Verificar:** comparar con el hash guardado; marcar usado; respetar TTL (10 min).
- **🌍 Ejemplo real:** un proveedor externo recibe un código de 6 dígitos en su correo para consultar una factura.
- **✔ Validar:** *completitud* → TTL, uso único, rate-limit 5/h. *Norma* → marcado `restricted` y riesgo en `audit_event`.
- **Capas:** motor (TTL/rate-limit) → cripto (hash+`aleatorio_seguro`) → canal correo (PLT-17).

### B.11 — SMS OTP · 🚫 DEPRECADO
- No se implementa (SS7/SIM-swapping, GSMA FS.40). Fuera de `requiredMethods` salvo excepción registrada (Bolivia rural, TTL ≤ 2 min). **✔ Validar:** no debe existir método SMS activo.

### B.12 — Push Challenge (Ed25519) · AAL2 · FIDO-like · ✅
- **Código:** `push.rs` · **Petición →** `challenge_id` · `firma: Ed25519`
- **← UserTemplate §5:** la `public_key` Ed25519 del dispositivo (por `credential_id`).
- **← RolTemplate B4:** `requiredMethods[]{method:"push", loa:2}`.
- **Devuelve →** `VeredictoAuth{valida, aal:2}`
- **Verificar:** comprobar la firma del challenge (32 B, TTL 120 s) con la clave pública enrolada.
- **🌍 Ejemplo real:** María recibe en su móvil una notificación «¿Autorizas el ingreso?»; toca *Sí*; su teléfono firma el reto y bAuth lo valida.
- **✔ Validar:** *completitud* → firma **asimétrica** (no HMAC compartido), TTL. *Norma* → clave privada no exportable (FIDO); `cargo test push`.
- **Capas:** motor (challenge+TTL) → cripto (`verificar_firma` Ed25519) → canal de entrega push (notificación al dispositivo).

### B.13 — Smart Card / PIV · AAL3 · FIPS 201 · 🔄 P1
- **Petición →** `certificado_PIV` · `firma_del_reto` · `PIN`
- **← UserTemplate §5:** `has_x509_smartcard` + `subject`/huella del certificado PIV.
- **← RolTemplate B4:** `requiredMethods[]{method:"smartcard_x509", loa:4}` (tiers privilegiados).
- **Devuelve →** `VeredictoAuth{valida, aal:3}`
- **Verificar:** como mTLS con certificado en hardware; validar cadena, vigencia, revocación, firma del reto (PIN activa la tarjeta).
- **🌍 Ejemplo real:** un funcionario inserta su carnet con chip y teclea el PIN para firmar una resolución.
- **✔ Validar:** *norma* → cadena RFC 5280 + revocación OCSP; PIV FIPS 201. **Brecha:** falta flujo PIV (reusa mTLS).
- **Capas:** motor (X.509) → cripto (`verificar_firma`+cadena) → bóveda (CA, A.08).

### B.14 — Hardware OTP Token (OATH) · AAL2 · OATH · 🔄 P2
- TOTP/HOTP con **semilla en token físico**. **← §5:** instancia OATH. **← B4:** `requiredMethods{method:"oath"}`. **🌍 Ejemplo:** token bancario que muestra un código cada 60 s. **✔ Validar:** import de seeds OATH + vectores TOTP/HOTP. **Brecha:** aprovisionamiento de semillas.

### B.15 — Magic Link · AAL1 · — · ⬜ P2
- **Petición →** `token_firmado` (en el enlace) · **← §5:** correo del usuario · **← B4:** acceso débil/`EXT_N0`.
- **Devuelve →** `VeredictoAuth{valida, aal:1}` · **Verificar:** validar firma + TTL del token; marcar usado.
- **🌍 Ejemplo real:** un invitado hace clic en «Entrar» de un correo y accede sin contraseña.
- **✔ Validar:** *norma* → token firmado, TTL corto, uso único (variante de Email OTP con token en URL).

### B.16 — QR Code challenge (cross-device) · AAL1-2 · — · 🔄 P2
- **Petición →** `challenge_id` (del QR) + prueba del dispositivo autenticado · **← §5:** autenticador del móvil aprobador · **← B4:** `loa` del rol.
- **Devuelve →** `VeredictoAuth{valida, aal}` · **Verificar:** el móvil autenticado aprueba el challenge del QR; bAuth correlaciona sesión-QR.
- **🌍 Ejemplo real:** María escanea con su móvil el QR de la pantalla de login del quiosco y este la deja entrar.
- **✔ Validar:** *norma* → binding sesión↔QR, TTL. **Brecha:** orquestador cross-device (relacionado E.35/E.37).

### B.17 — NFC / RFID tap · AAL2 · — · 🔄 P2
- **Petición →** `uid`/`certificado_NFC` + reto firmado · **← §5:** `uid`/certificado NFC enrolado · **← B4:** `requiredMethods{method:"nfc_mifare_desfire", loa:2}`.
- **Devuelve →** `VeredictoAuth{valida, aal:2}` · **Verificar:** tarjeta con chip → firma de reto (como B.20); UID plano → posesión débil. El lector físico (edge) capta la tarjeta y transporta el reto al núcleo por el canal interno.
- **🌍 Ejemplo real:** un empleado acerca su credencial a un lector para fichar entrada.
- **✔ Validar:** *norma* → tarjetas con cripto (DESFire), no UID plano. **Brecha:** método en `auth_methods/`.

### B.18 — BLE proximity · AAL2 · — · ⬜ P3
- **← §5:** clave del dispositivo · **← B4:** raramente (relay attacks). **Verificar:** firma de reto + umbral de proximidad (distance-bounding). **🌍 Ejemplo:** puerta que se abre al acercarse el teléfono. **✔ Validar:** mitigación de relay. Baja prioridad.

### B.19 — Wearable (smartwatch) · AAL2 · — · ⬜ P3
- Variante de Push (B.12) con reto firmado desde el reloj. Mismo consumo de templates. **🌍 Ejemplo:** aprobar login desde el Apple Watch. **✔ Validar:** igual que Push.

### B.20 — mTLS X.509 · AAL3 · RFC 8705 · ✅
- **Código:** `mtls.rs` · **Petición →** `certificado_cliente` · `cadena` · reto TLS
- **← UserTemplate §5:** `has_x509_smartcard`/certificado + `subject`/huella enrolada.
- **← RolTemplate B4:** `requiredMethods[]{method:"smartcard_x509"|"mtls", loa:4}` (M2M, tiers privilegiados).
- **Devuelve →** `VeredictoAuth{valida, aal:3, subject}`
- **Verificar:** cadena a CA (RFC 5280), vigencia, revocación (OCSP/CRL), binding al token (`cnf`/x5t — AM-11).
- **🌍 Ejemplo real:** un servicio backend sin usuario humano (cliente confidencial) abre una conexión **TLS 1.3 mutua** y presenta su certificado X.509; bAuth valida la cadena contra la CA, comprueba revocación y **liga el token emitido a ese certificado** (`cnf`/x5t) — un token robado no sirve sin presentar el mismo certificado.
- **✔ Validar:** *completitud* → validación de cadena + revocación. *Norma* → RFC 8705 `cnf` binding (⬜ AM-11); `cargo test mtls`.
- **Capas:** motor (X.509) → cripto (`verificar_firma`+cadena) → bóveda (CA/PKI, A.08).

---

## 4. Categoría C — Inherencia (algo que eres)

> **Principio soberano de la biometría:** bAuth **no recibe ni almacena biometría cruda** (privacidad
> + soberanía). La biometría **física** se canaliza por **WebAuthn platform authenticator** (B.8)
> con `user_verification` biométrico → el *match ocurre en el dispositivo* (Touch ID, Face ID,
> Windows Hello) y a bAuth solo llega una **firma**, nunca la huella/rostro. La biometría
> **conductual** alimenta el **Risk Engine** (E.40) como señal, no como factor primario.

### C.21 — Huella digital · AAL2-3 · FIDO2 platform · 🔄 P1
- **Petición →** (vía WebAuthn) `signature` del platform authenticator.
- **← UserTemplate §5:** `webauthn_credentials[].type=="platform_biometric"`, `user_verification=="required"`.
- **← RolTemplate B4:** `requiredMethods[]{method:"fingerprint_hash", loa:3}` (el contrato lo nombra así).
- **Devuelve →** `VeredictoAuth{valida, aal:3, user_verified:true}`
- **Verificar:** es B.8 con UV biométrico; bAuth verifica la **firma**, no la huella (match-on-device).
- **🌍 Ejemplo real:** María apoya el dedo en el Touch ID de su MacBook; el equipo verifica la huella localmente y firma el reto; bAuth valida la firma → AAL3.
- **✔ Validar:** *norma* → nunca llega biometría cruda al servidor (ISO 24745, GDPR); UV=required. **Brecha:** enforcement de `attestation` para AAL3 (🔄, como B.8).

### C.22 — Reconocimiento facial · AAL2-3 · FIDO2 platform · 🔄 P2
- Igual que C.21 con Face ID / Windows Hello (`platform_biometric`). Mismo consumo de templates.
- **🌍 Ejemplo real:** un ejecutivo mira su iPhone y Face ID lo autentica ante el CRM. **✔ Validar:** liveness en el dispositivo; match-on-device.

### C.23 — Iris / Retina · AAL3 · — · ⬜ P3
- **← §5:** `platform_biometric` (si el dispositivo lo soporta). **← B4:** `loa:3`. **🌍 Ejemplo:** control de acceso a un datacenter con escáner de iris. **✔ Validar:** solo vía hardware certificado; no en servidor. Baja prioridad.

### C.24 — Voz · AAL2 · — · ⬜ P3
- **🌍 Ejemplo:** autenticación telefónica por frase hablada. **✔ Validar:** exige anti-spoofing (liveness); alta tasa de error → no como factor único. No implementado.

### C.25 — Palm vein · AAL3 · — · ⬜ P3
- **🌍 Ejemplo:** lector de venas de palma en un banco. **✔ Validar:** hardware dedicado; match-on-device. No implementado.

### C.26 — Biometría conductual: keystroke · AAL2+ · — · ⬜ P2 (señal de riesgo)
- **Petición →** patrón de tecleo (cadencia). **← §5:** perfil conductual de referencia. **← B4:** alimenta `step_up_rules` (no `requiredMethods`).
- **Devuelve →** `score_riesgo` (no un veredicto binario) → E.40.
- **🌍 Ejemplo real:** si alguien teclea muy distinto al patrón de María, el Risk Engine exige un segundo factor.
- **✔ Validar:** *norma* → señal para step-up (NIST 800-207 continuo), nunca factor primario.

### C.27 — Biometría conductual: ratón/touchpad · AAL2+ · — · ⬜ P3
- Como C.26 con dinámica de puntero. Señal de riesgo → E.40. **🌍 Ejemplo:** detección de sesión secuestrada por movimiento anómalo del cursor.

### C.28 — Biometría conductual continua (AI/ML) · AAL2+ · — · ⬜ P2 (UEBA)
- **Petición →** telemetría de sesión continua. **← §5:** línea base del usuario. **← B4:** `step_up_rules`.
- **Devuelve →** `score` continuo → E.40/E.41. **🌍 Ejemplo real:** el sistema detecta que el comportamiento cambió a media sesión y fuerza reautenticación.
- **✔ Validar:** *norma* → UEBA (Pilar ITDR); modelo auditable, sin sesgo. **Brecha:** no existe motor UEBA.

---

## 5. Categoría D — Federación e identidad externa

> Aquí bAuth actúa como **Service Provider / Relying Party**: confía en un IdP externo que ya
> autenticó al usuario y **verifica su aserción/token**. Consume del UserTemplate el **vínculo
> federado** y del RolTemplate **qué IdP acepta** para ese rol.

### D.29 — SAML 2.0 (SP) · AAL1-2 · OASIS SAML 2.0 · ✅ 🔄
- **Código:** `saml.rs` + `saml_signature.rs` · **Petición →** `SAMLResponse` (aserción firmada)
- **← UserTemplate §5/identidad:** `federated_subject` (NameID) que liga al usuario local.
- **← RolTemplate B4:** IdP/emisor confiable permitido para el rol.
- **Devuelve →** `VeredictoAuth{valida, aal, subject}`
- **Verificar:** validar **firma XML-DSig** del emisor, `Conditions` (NotBefore/NotOnOrAfter), `Audience`, y mapear NameID → usuario.
- **🌍 Ejemplo real:** un empleado entra desde el portal corporativo (IdP) y bAuth acepta su aserción SAML sin pedir contraseña de nuevo.
- **✔ Validar:** *completitud* → firma verificada, condiciones temporales. *Norma* → **protección XSW** (XML Signature Wrapping) — **brecha 🔄** (AM-17); `cargo test saml`.

### D.30 — OIDC Social Login (Google/Apple/GitHub) · AAL1-2 · OIDC Core · 🔄 P1
- **Código:** `idp_external.rs` (esqueleto) · **Petición →** `id_token` (JWT del IdP)
- **← UserTemplate §5/identidad:** `federated_identity{issuer, sub}`.
- **← RolTemplate B4:** lista de `issuers` aceptados para el rol (típico `EXT_N0`).
- **Devuelve →** `VeredictoAuth{valida, aal:1-2, subject}`
- **Verificar:** validar firma del `id_token` contra el **JWKS** del IdP, `iss`, `aud`, `exp`, `nonce`.
- **🌍 Ejemplo real:** un proveedor entra con «Iniciar sesión con Google» al portal de facturas.
- **✔ Validar:** *norma* → `nonce` anti-replay, `iss/aud` exactos. **Brecha:** flujo de brokering incompleto (🔄).

### D.31 — Kerberos / SPNEGO · AAL2 · RFC 4559 · ⬜ P2
- **Petición →** ticket SPNEGO (GSS-API). **← §5:** `principal` Kerberos vinculado. **← B4:** realm confiable.
- **Devuelve →** `VeredictoAuth{valida, aal:2}` · **Verificar:** validar el ticket contra el KDC (clave de servicio).
- **🌍 Ejemplo real:** un usuario ya logueado en el dominio Windows entra al ERP sin volver a autenticarse (SSO corporativo).
- **✔ Validar:** *norma* → validación de ticket + reloj sincronizado. No implementado.

### D.32 — LDAP (autenticación directa) · AAL1 · RFC 4511 · ⬜ P2
- **Petición →** `usuario` + `contraseña`. **← §5:** DN vinculado. **← B4:** servidor LDAP confiable.
- **Verificar:** `bind` LDAP contra el directorio; éxito = credencial válida. **🌍 Ejemplo:** login contra el Active Directory de la empresa. **✔ Validar:** *norma* → bind sobre canal cifrado (LDAPS/mTLS, PLT-17). No implementado.

### D.33 — Windows Integrated Auth (WIA) · AAL2 · — · ⬜ P3
- Variante de Kerberos/NTLM en entorno Windows. **🌍 Ejemplo:** SSO transparente en equipos unidos al dominio. **✔ Validar:** como D.31. No implementado.

### D.34 — SCIM (provisioning + authn) · — · RFC 7643/7644 · 🔄
- **Petición →** operación SCIM (`POST/PATCH /Users`). **← UserTemplate:** es el **destino** — SCIM crea/actualiza el UserTemplate. **← RolTemplate:** mapea grupos SCIM → roles.
- **Devuelve →** recurso SCIM + estado. **Verificar:** token de servicio del cliente SCIM + esquema.
- **🌍 Ejemplo real:** RRHH da de alta a un empleado en su sistema y SCIM lo provisiona automáticamente en bAuth.
- **✔ Validar:** *norma* → esquema RFC 7643, filtros; **bidireccional** (in/out). **Brecha:** SCIM saliente + `idn_identidad_atributo` (A.31, 🔄).

---

## 6. Categoría E — Flujos especiales y contexto

### E.35 — CIBA (backchannel) · AAL2 · OpenID CIBA · 🔄 P1
- **Petición →** `auth_req_id` (iniciado por un tercero). **← §5:** el dispositivo de aprobación del usuario (push, B.12). **← B4:** `requiredMethods` + `loa`.
- **Devuelve →** `VeredictoAuth{valida, aal}` tras aprobación fuera de banda.
- **Verificar:** el usuario aprueba en su dispositivo (backchannel); bAuth correlaciona `auth_req_id` y valida la prueba.
- **🌍 Ejemplo real:** un cajero inicia un pago y el **cliente** lo aprueba en su propio móvil antes de completarse.
- **✔ Validar:** *norma* → binding `auth_req_id`↔usuario, TTL. **Brecha:** orquestador CIBA (reusa push B.12).

### E.36 — Step-Up Authentication · AAL2-3 · RFC 9470 · ✅
- **Código:** 2.01 §10 · **Petición →** `acr_values`/`max_age` exigidos por el recurso.
- **← UserTemplate §5:** los autenticadores fuertes disponibles del usuario.
- **← RolTemplate B4:** `step_up_rules[]{trigger, required_loa, max_age_seconds}` (**campo exacto verificado**).
- **Devuelve →** exige un método adicional hasta alcanzar `required_loa`.
- **Verificar:** si `aal_sesión < required_loa` para la acción → dispara otro método (WebAuthn/push) y re-evalúa.
- **🌍 Ejemplo real:** María navega con AAL1, pero al **aprobar una transferencia grande** el sistema le pide su YubiKey (eleva a AAL3) solo para esa operación.
- **✔ Validar:** *completitud* → elevación temporal + expiración (`max_age_seconds`). *Norma* → RFC 9470 `acr`/`auth_time`.

### E.37 — Device Authorization Grant · AAL1-2 · RFC 8628 · 🔄 P1
- **Petición →** `device_code` + `user_code`. **← §5:** el autenticador con que el usuario aprueba en otro dispositivo. **← B4:** `loa`.
- **Devuelve →** token tras aprobación. **Verificar:** el usuario ingresa el `user_code` en un dispositivo con teclado y aprueba; bAuth correlaciona.
- **🌍 Ejemplo real:** al configurar la app de bAuth en una **smart TV**, esta muestra un código que el usuario aprueba desde su teléfono.
- **✔ Validar:** *norma* → `user_code` de un uso, TTL, polling con backoff. **Brecha:** flujo device (🔄).

### E.38 — Token Exchange · — · RFC 8693 · 🔄 P2
- **Código:** `token_protocols.rs` · **Petición →** `subject_token` + `requested_token_type`.
- **← Templates:** no consume credencial nueva; **delega** la identidad ya probada (impersonation/delegation).
- **Devuelve →** token derivado con scope acotado. **Verificar:** validar el `subject_token`, la política de intercambio y el `actor`.
- **🌍 Ejemplo real:** un servicio de reportes que ya posee el token de un usuario solicita (por RFC 8693, sobre el canal interno JSON-RPC) un **token derivado con scope reducido** (solo lectura) para actuar **en nombre de** ese usuario ante otro servicio; bAuth valida el `subject_token` y la política de delegación antes de emitirlo.
- **✔ Validar:** *norma* → `may_act`/delegación, scope reducido; auditar el intercambio.

### E.39 — DPoP · — · RFC 9449 · ⬜ P2 (BA2)
- **Petición →** `DPoP` proof (JWT firmado por la clave del cliente) + token.
- **← Templates:** liga el token a la clave del cliente (`cnf.jkt`), no a un autenticador de §5.
- **Devuelve →** token **sender-constrained** (no reutilizable si es robado).
- **Verificar (12 pasos, A.42 §2):** firma del proof, `htm`/`htu`, `iat` fresco, `jti` anti-replay, `ath` = hash del token.
- **🌍 Ejemplo real:** aunque un atacante robe el token de María, no puede usarlo porque no tiene su clave DPoP.
- **✔ Validar:** *norma* → **hoy es un stub que MIENTE** (retorna `true` sin verificar — A.28); debe implementar los 12 pasos (⬜ BA2); `cargo test dpop`.

### E.40 — Autenticación adaptativa / Risk-based · AAL2+ · NIST 800-207 · ⬜ P1
- **Código:** `risk.rs` (existe, **dead_code** — A.26) · **Petición →** señales (IP, dispositivo, hora, geo, conducta C.26-28).
- **← UserTemplate §5:** línea base del usuario. **← RolTemplate B4:** `step_up_rules{trigger, required_loa}`.
- **Devuelve →** `score_riesgo` → decide permitir / step-up / bloquear.
- **Verificar:** combinar factores → score; si supera umbral, disparar E.36 (step-up) o denegar.
- **🌍 Ejemplo real:** María entra desde un país nuevo a las 3 a.m.; el score sube y el sistema le exige WebAuthn.
- **✔ Validar:** *completitud* → los 4 factores de `risk.rs` **cableados** (hoy 0 invocaciones). *Norma* → PEP/PDP 800-207; decisión auditable.

### E.41 — Autenticación continua (sesión) · AAL2+ · NIST 800-207 · ⬜ P2
- **Petición →** re-evaluación periódica durante la sesión. **← §5/B4:** como E.40 + `max_age`. **Devuelve →** mantener / re-autenticar.
- **🌍 Ejemplo real:** la sesión se re-valida cada 15 min; si el contexto cambió, pide reautenticación.
- **✔ Validar:** *norma* → NIST 800-63B §7 (timeouts) + Zero Trust continuo. No implementado.

### E.42 — Detección de liveness (AI) · AAL2-3 · ISO 30107 · ⬜ P2
- Complemento anti-spoofing de la biometría (C). Idealmente **on-device**. **🌍 Ejemplo:** el móvil verifica que es un rostro real y no una foto antes de firmar. **✔ Validar:** ISO 30107 PAD; on-device.

### E.43 — Silent / Ambient (BLE/NFC geofencing) · AAL1 · — · ⬜ P3
- **Petición →** señales de proximidad/ubicación. **← B4:** solo como factor de **contexto** (nunca único). **🌍 Ejemplo:** el acceso se facilita si el teléfono está dentro de la oficina. **✔ Validar:** factor contextual de bajo peso; anti-relay.

---

## 7. Categoría F — Identidad descentralizada y emergente

### F.44 — W3C DID + Verifiable Credentials · AAL2-3 · W3C DID/VC · ⬜ P2
- **Petición →** una **Verifiable Presentation** (credencial firmada por su emisor).
- **← UserTemplate §5/identidad:** el `DID` del sujeto vinculado. **← RolTemplate B4:** emisores/esquemas VC aceptados.
- **Devuelve →** `VeredictoAuth{valida, claims}` · **Verificar:** resolver el DID, validar la firma del emisor y el estado (no revocada).
- **🌍 Ejemplo real:** un ciudadano presenta su credencial de título profesional emitida por la universidad, sin llamar a la universidad.
- **✔ Validar:** *norma* → W3C VC Data Model, revocación; alineado con D12 (blockchain, A.12). No implementado.

### F.45 — eIDAS 2.0 Wallet · AAL2-3 · eIDAS 2.0 / ARF · ⬜ P2
- **Petición →** presentación desde la **EU Digital Identity Wallet**. **← §5:** vínculo del wallet. **← B4:** confianza del wallet/PID provider.
- **Devuelve →** `VeredictoAuth{valida, claims}` · **Verificar:** validar el PID/atestación según el Architecture Reference Framework.
- **🌍 Ejemplo real:** un ciudadano europeo se identifica con su cartera de identidad nacional. **✔ Validar:** ARF eIDAS 2.0; selective disclosure. No implementado.

### F.46 — Blockchain identity (DID:ethr) · AAL2-3 · — · ⬜ P3
- Variante de F.44 con DID anclado en cadena (relacionado D12, A.12). **🌍 Ejemplo:** identidad verificable anclada en el libro mayor soberano. **✔ Validar:** resolución on-chain + firma ECDSA. No implementado.

### F.47 — Post-cuántico (ML-KEM / ML-DSA) · — · FIPS 203/204 · 🔄 P2
- **No es un método de autenticación nuevo**: es la **migración del algoritmo** de firma/KEM que
  usan los demás (WebAuthn, mTLS, push, firma). Se habilita en el **Módulo Criptográfico** (CORE-11,
  ADR-012) como variante de enum, no como método aparte.
- **← Templates:** transparente (los métodos no cambian su contrato).
- **🌍 Ejemplo real:** cuando llegue la amenaza cuántica, las firmas Ed25519 migran a ML-DSA **sin
  tocar los 46 métodos** — solo el módulo cripto.
- **✔ Validar:** *norma* → FIPS 203/204/205; agilidad criptográfica en un punto (CNSA 2.0, 2030).

---

## 8. Referencias
- RFC 6238/4226 (TOTP/HOTP) · W3C WebAuthn L3 §7.2 · RFC 8705 (mTLS) · NIST SP 800-63B Rev.4 (§4 AAL exigido / §5 autenticadores) · RFC 9470 (step-up) · FIPS 140-3 · RFC 5280 (X.509) · OWASP ASVS 5.0
- 2.02 · 2.01 §3 · **1.08 §5** · **1.09 B4** · 2.04 · A.42 §10.ter · A.43 §1 · ADR-006 · ADR-012

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Doctrina (3 capas + producir/verificar) + fichas A (5) y B (15). |
| 1.1.0 | 2026-07-11 | + consumo de plantillas por método (`UserTemplate §5` / `RolTemplate B4`), identidad(§5)/autoridad(§4). |
| 1.2.0 | 2026-07-11 | + **campos exactos** de cada plantilla (verificados en el contrato v6.0: `requiredMethods[]{method,order,loa}`, `webauthn_credentials[]{aaguid,user_verification}`, `backup_codes.remaining_codes`…), **🌍 ejemplo de la vida real** y **✔ forma de validar completitud + cumplimiento de norma** en cada ficha. |
| 1.3.0 | 2026-07-11 | **Completadas las categorías C-F** en el mismo molde: **C** Inherencia (#21-28, con el principio soberano de biometría match-on-device vía WebAuthn), **D** Federación (#29-34: SAML, OIDC social, Kerberos, LDAP, WIA, SCIM), **E** Flujos (#35-43: CIBA, step-up, device grant, token exchange, DPoP, risk-based, continua, liveness, ambient), **F** Emergente (#44-47: DID/VC, eIDAS wallet, blockchain, PQC). **Los 47 métodos de 2.02 §2.1 quedan especificados** con petición → consumo exacto de plantillas → devuelve, ejemplo real y validación de completitud/norma. |
| 1.4.0 | 2026-07-11 | **§1 reescrita como MOTOR ÚNICO** (reparación): un solo motor (`MethodRegistry`) es la **única puerta** de validación; bAuth acude a él para *aplicar/enrolar/consultar/revocar* y recibe **un** `VeredictoAuth`. Fachada `MotorDeMetodos` (§1.2), flujo de punta a punta (§1.3) y las 3 capas **dentro** del motor (§1.4): las **sagas** (combinaciones) y el **Módulo Criptográfico** son **partes internas**, no piezas sueltas. Regla dura: validar un método fuera del motor = defecto. Ejemplos de daemons SBOS reemplazados por casos reales genéricos con su conexión explicada (mTLS, Token Exchange, push, NFC). |

*A.44 · bAuth Identity Core v3.0 · 2026-07-11*
