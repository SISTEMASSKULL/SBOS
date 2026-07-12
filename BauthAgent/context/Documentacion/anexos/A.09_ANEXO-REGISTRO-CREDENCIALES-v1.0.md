# Anexo A.09 — Registro de Usuarios y Ciclo de Vida de Credenciales v1.0
## Documento de respaldo: identity proofing IAL 1–3, credenciales iniciales, auto-gestión y recuperación

**Tipo:** ANEXO — documento de respaldo del corpus
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Estatus:** FUENTE AUTOSUFICIENTE — contiene las políticas COMPLETAS (traslado fiel, §4)
**Respalda a:** MANUAL-AUTENTICACION (2.01) · MANUAL-USER-TEMPLATE (1.08 §7 JML) · A.02 §19.2-U1 (`identity_proofing` — este diseño es su fuente interna) · MANUAL-CALIDAD (7.02)
**Fuentes de origen (cita histórica):** `SBOS-BAUTH-USER-REGISTRATION-CREDENTIAL-LIFECYCLE` v1.0
**Normas base:** NIST SP 800-63A (IAL 1–3) · NIST SP 800-63B (credenciales, recuperación) · OWASP ASVS 5.0 §2.1–2.5 · ISO 24760

---

## 1. Propósito y cómo citarlo

Respaldo de las políticas de **entrada de la identidad al sistema**: cómo se verifica quién es
(proofing IAL 1–3), cómo nacen sus credenciales (aleatorias — diceware), cómo las auto-gestiona
y cómo se recupera el acceso (contraseña + MFA perdido) con notificaciones de seguridad
obligatorias. **Cómo citarlo:** `A.09 §2` (IAL) · `A.09 §5` (recuperación — del traslado).

**Este diseño es la fuente interna de la resolución A.02 U1** (`identity_proofing` del
UserTemplate): los niveles IAL, los métodos de verificación y la evidencia que aquí se
especifican son los que la sección del sujeto registra.

**Autosuficiencia:** todo el ciclo lo ejecuta bAuth nativamente (motor 2.01 + almacén `ath_*`);
menciones de época bajo ADR-010 (**Keycloak y Tryton eliminados de la solución**).

## 2. El ciclo en una vista

| Fase | Contenido normado | Norma |
|---|---|---|
| Identity proofing | IAL1 (auto-declarado) · IAL2 (evidencia verificada, remoto o presencial) · IAL3 (presencial con verificador) — por tipo de cuenta y tier | 800-63A |
| Credenciales iniciales | **Aleatorias (diceware)** — jamás predecibles ni derivadas del usuario; entrega segura; cambio forzado en primer uso | 800-63B §5.1.1 · ASVS 2.1 |
| Auto-gestión | Cambio de contraseña, enrolamiento/retiro de MFA, gestión de dispositivos — self-service con re-autenticación | ASVS 2.5 |
| Recuperación | Contraseña (canal verificado) y **MFA perdido** (verificación reforzada + aprobación) — sin preguntas débiles | 800-63B §6.1.2.3 · ASVS 2.5 |
| Notificaciones de seguridad | Obligatorias en todo evento de credencial (cambio, enrolamiento, recuperación) — por el daemon de notificación | ASVS 2.2.3 |
| Reglas no negociables | Las 7 del diseño (traslado §4 sección 7) — fail-closed en todo el ciclo | — |

## 3. Verificación de completitud

| Verificación | Resultado |
|---|---|
| Cobertura del ciclo de entrada (proofing→credencial→gestión→recuperación→notificación) | ✅ íntegro en §4 |
| Coherencia con A.02 U1 | ✅ — los IAL de este diseño alimentan `identity_proofing` |
| Coherencia con la industria | ✅ — el registro del proofing con evidencia/método/atestación es la práctica verificada (A.02 §19.2-U1: Entra Verified ID, Okta IDV) |
| Rotación de contraseña | Coherente con 800-63B Rev.4: sin rotación forzada; trigger-on-breach (A.01 §17.2-B18) |

## 4. Traslado fiel — las políticas completas

### SBOS — Registro de Usuarios y Ciclo de Vida de Credenciales v1.0
#### Políticas de Registro, Autenticación Inicial, Auto-Gestión y Recuperación
##### SKULL · SBOS · Junio 2026 · Alineado con bAuth v2.0

---

| Campo | Valor |
|---|---|
| **Código** | SBOS-BAUTH-USER-REGISTRATION-v1_0 |
| **Versión** | 1.0 |
| **Estado** | ACTIVO |
| **Propósito** | Definir políticas y procedimientos para registro de usuarios, verificación de identidad, generación de credenciales iniciales, auto-gestión, cambio de contraseñas, y recuperación de acceso |
| **Estándares** | NIST SP 800-63B Rev.4 · NIST SP 800-63-4 (IAL1-3) · OWASP ASVS v5.0 §2.1-2.5 · ISO 27001:2022 A.9.2 · ISO/IEC 24760-2:2025 · SCIM 2.0 RFC 7643/7644 · RGPD Art.4/9/17 |
| **Integra** | SBOS-USERTEMPLATE-v6_0 · Policies_Authentication_Framework_v4.json · Authentication_Framework_v3.json · BAUTH-CATALOGO-ROLES-EMPRESARIALES v2.0 |

---

#### 1. PRINCIPIO ABSOLUTO

> **El nivel de verificación de identidad debe ser proporcional al riesgo del acceso concedido.**
> Un cliente que solo recibe facturas (EXT_N0) no necesita la misma verificación que un
> administrador de sistema (SYS). La auto-gestión de credenciales es un derecho del usuario,
> no un privilegio — pero siempre debe estar protegida por verificación de identidad.

---

#### 2. VERIFICACIÓN DE IDENTIDAD (IDENTITY PROOFING) — IAL 1-3

##### 2.1 Niveles de Aseguramiento de Identidad (IAL) — NIST SP 800-63-4

| Nivel | Requisito | Aplica a | Método de Verificación | Tiempo |
|-------|----------|---------|----------------------|--------|
| **IAL1** | Sin evidencia de identidad requerida | EXT_N0, VISITANTE | Email verification + CAPTCHA. Sin acceso a PII ni operaciones financieras. | Automático, < 1 min |
| **IAL2** | Evidencia de identidad con documento oficial | BIZ_N1-N3, SYS_N3 | Documento identidad (SEGIP/SERECI API) + selfie biométrico (liveness detection) + proof of address (factura servicios). | Semi-automático, < 24h |
| **IAL3** | Verificación presencial o equivalente supervisada | SU, SYS_N1-N2, BIZ_N4-N5 | In-person verification o video call con agente autorizado. Hardware token binding (FIDO2/WebAuthn). | Manual, < 72h |

##### 2.2 Flujo de Verificación IAL2 (el más común — empleados)

```
1. Usuario completa formulario de registro (username, email, documento identidad)
2. Sistema valida documento contra SEGIP/SERECI API (nombre, apellido, fecha nacimiento)
3. Sistema solicita selfie biométrico con liveness detection (ISO/IEC 30107-3)
4. Sistema compara selfie vs foto del documento (face match threshold ≥ 95%)
5. Sistema valida proof of address (factura de servicios < 3 meses)
6. Si todo OK → IAL2 aprobado → proceder a generación de credenciales
7. Si falla → notificar motivo → permitir reintento (máx 3 intentos)
8. Si agotados reintentos → escalar a verificación manual (admin tenant)
```

##### 2.3 Requisitos Técnicos del Sistema de Verificación

- Liveness detection: ISO/IEC 30107-3 compliant (presentation attack detection)
- Face match: NIST FRVT top-20 algorithm, threshold ≥ 95% TAR @ 0.1% FAR
- Document validation: SEGIP/SERECI API con certificado digital ADSIB
- Rate limiting: máximo 3 intentos por documento por día
- PII storage: AES-256-GCM en reposo, desencriptado solo en memoria durante verificación
- Retention: datos biométricos de verificación se eliminan tras 90 días (RGPD Art.9)

---

#### 3. GENERACIÓN DE CREDENCIALES INICIALES

##### 3.1 Política de Contraseñas Iniciales — OWASP ASVS 2.5.8

Toda cuenta nueva recibe credenciales generadas por el sistema que:
- Son **aleatorias** (CSPRNG, ≥ 256 bits entropía)
- Usan **diccionario diceware** (6-8 palabras separadas por guiones) para legibilidad
- **Expiran en 24 horas** o en el **primer uso** (lo que ocurra primero)
- **Fuerzan cambio** de contraseña en el primer login
- **NUNCA** se convierten en la contraseña permanente del usuario
- Se entregan por **canal seguro** (email con magic link TTL 5 min O presencial con QR TTL 30s)

| Tier | Formato | Longitud | TTL | Canal de Entrega |
|------|---------|----------|-----|-----------------|
| SU | Diceware 8 palabras | ~40 caracteres | 4h | Presencial + HW token FIDO2 |
| SYS | Diceware 6 palabras | ~30 caracteres | 8h | Email cifrado + presencial |
| BIZ N1-N5 | Diceware 5 palabras | ~25 caracteres | 24h | Email con magic link |
| EXT N0 | Diceware 4 palabras | ~20 caracteres | 72h | Email o SMS (SMS solo si no hay email) |

##### 3.2 Flujo de Primer Login con MFA Enrollment

```
1. Usuario recibe credenciales temporales por canal seguro
2. Usuario accede a URL de primer login (bauth.sbos.skull.bo/first-login)
3. Ingresa credenciales temporales
4. Sistema fuerza cambio de contraseña:
   - Nueva contraseña validada contra HIBP + top100k + contexto + historial
   - NIST 800-63B Rev.4: sin reglas de complejidad, longitud mínima según tier
5. Sistema requiere enrollment MFA (si aplica al tier):
   - TOTP: mostrar QR + código de verificación (RFC 6238, SHA-256, 6 dígitos, 30s)
   - FIDO2/WebAuthn: registrar platform authenticator (Face ID, Windows Hello) o roaming (YubiKey)
   - Passkey: para EXT_N0 y BIZ_N1 (opcional)
6. Sistema genera 10 recovery codes (SHA-256 hash, single-use)
7. Usuario debe guardar recovery codes (descarga PDF o copia texto)
8. Sistema verifica MFA: solicitar código TOTP o tocar FIDO2 key
9. Primer login completado → sesión activa con credenciales permanentes
```

---

#### 4. AUTO-GESTIÓN DE CREDENCIALES (SELF-SERVICE)

##### 4.1 Portal de Auto-Gestión — OWASP ASVS 2.1.5-2.1.6

Todo usuario autenticado puede acceder a `bauth.sbos.skull.bo/self-service` para:

| Funcionalidad | Requisito de Seguridad | Estándar |
|--------------|----------------------|---------|
| Ver perfil (username, email, roles, tenant) | Autenticación estándar | OWASP ASVS 2.1.1 |
| Cambiar contraseña | Requiere contraseña actual + nueva validada | OWASP ASVS 2.1.6 |
| Ver historial de login (últimos 30 días) | Autenticación estándar | OWASP ASVS 2.2.3 |
| Administrar métodos MFA (agregar/quitar) | Requiere MFA actual para modificar | NIST 800-63B §5.1.3 |
| Ver sesiones activas + dispositivos | Autenticación estándar | OWASP ASVS 2.2.4 |
| Cerrar sesiones remotas | Requiere MFA + notificación | OWASP ASVS 2.2.4 |
| Descargar datos personales (portabilidad RGPD) | Requiere MFA + 30 días processing | RGPD Art.20 |
| Solicitar eliminación de cuenta (derecho al olvido) | Requiere MFA + aprobación admin tenant | RGPD Art.17 |
| Ver recovery codes / regenerar | Requiere MFA actual | OWASP ASVS 2.5.7 |

##### 4.2 Cambio de Contraseña

```
POST /bauth.self-service/password/change
Body: { current_password, new_password }
Validaciones:
  1. current_password es correcta (verify hash)
  2. new_password != current_password
  3. new_password cumple política del tier (longitud mínima)
  4. new_password NO está en HIBP (k-anonymity check)
  5. new_password NO está en top 100K comunes
  6. new_password NO contiene username, email, tenant, empresa
  7. new_password NO está en historial (últimas 10)
  8. Si todas OK → hash con Argon2id → actualizar KC → notificar usuario (email)
  9. Invalidar refresh tokens (forzar re-login en otros dispositivos)
```

##### 4.3 Admin-Initiated Password Reset — OWASP ASVS 2.5.10

```
Admin (SYS_N3 o BIZ_N4+) puede iniciar reset para usuario de su tenant:
  1. Admin NO puede elegir/ver la nueva contraseña del usuario
  2. Sistema genera magic link TTL 1h, single-use
  3. Usuario recibe email/SMS con link
  4. Usuario elige nueva contraseña (validación completa)
  5. Admin recibe confirmación de que el reset fue completado
  6. Audit: admin_id, user_id, timestamp, motivo, IP
```

---

#### 5. RECUPERACIÓN DE ACCESO

##### 5.1 Recuperación de Contraseña Olvidada — OWASP ASVS 2.5.6

```
POST /bauth.self-service/password/recover
Body: { username_or_email }

Flujo:
  1. Usuario solicita recuperación (username o email)
  2. Sistema NO revela si la cuenta existe (respuesta genérica: "Si la cuenta existe, recibirás un email")
  3. Sistema verifica identity proofing al nivel IAL del enrollment:
     - IAL1 (EXT_N0): email magic link TTL 5 min, single-use
     - IAL2 (BIZ): email magic link + código SMS/notificación app
     - IAL3 (SU/SYS): email + código físico + aprobación admin superior
  4. Usuario accede al link → verificación adicional si IAL≥2
  5. Usuario elige nueva contraseña (validación completa)
  6. Sistema invalida todas las sesiones existentes
  7. Sistema envía notificación: "Tu contraseña fue cambiada. Si no fuiste tú, contacta a seguridad."
  8. Audit event registrado con ctx_id

Rate limiting:
  - Máximo 3 solicitudes por cuenta por hora
  - Máximo 5 solicitudes por IP por hora
  - Bloqueo tras 10 intentos fallidos consecutivos (15 min auto-unlock)
```

##### 5.2 Recuperación de Dispositivo MFA Perdido — OWASP ASVS 2.5.7

```
Flujo:
  1. Usuario indica que perdió su dispositivo MFA
  2. Sistema requiere identity proofing ≥ nivel del enrollment original
  3. Si IAL2+: documento identidad + selfie biométrico (re-verificación)
  4. Si IAL3: verificación presencial o video call
  5. Si identity proofing OK:
     a. Sistema revoca método MFA anterior
     b. Sistema genera nuevos recovery codes
     c. Usuario re-enrolla nuevo MFA (TOTP/FIDO2)
  6. Notificación: "Método MFA cambiado. Si no fuiste tú, contacta a seguridad."
  7. Audit event con ctx_id + motivo

Alternativa con recovery codes:
  - Si usuario tiene recovery code válido → puede saltar identity proofing
  - Recovery code es single-use → se regeneran tras uso
```

##### 5.3 Desbloqueo de Cuenta — NIST SP 800-63B §5.2.2

```
Causas de bloqueo:
  - 10 intentos fallidos consecutivos de contraseña
  - 5 intentos fallidos consecutivos de MFA
  - 3 solicitudes de recuperación fallidas

Desbloqueo:
  - Auto-unlock tras 15 minutos (solo contraseña)
  - Admin unlock (SYS_N3 o BIZ_N4+): requiere identity proofing del usuario
  - Rate limiting: 1 intento por segundo durante bloqueo
  - Notificación al usuario: "Tu cuenta fue bloqueada por intentos fallidos. Auto-unlock en 15 min."
```

---

#### 6. NOTIFICACIONES DE SEGURIDAD — OWASP ASVS 2.2.3

Todo cambio en credenciales o métodos de autenticación DEBE generar notificación:

| Evento | Canal | Inmediatez |
|--------|-------|-----------|
| Cambio de contraseña | Email + in-app | Inmediato |
| Cambio/agregado de MFA | Email + in-app | Inmediato |
| Recuperación de contraseña | Email + SMS | Inmediato |
| Login desde nuevo dispositivo | Email | Inmediato |
| Login desde nueva ubicación | Email + in-app | Inmediato |
| Múltiples intentos fallidos | Email | Tras 5° intento |
| Bloqueo de cuenta | Email + SMS | Inmediato |
| Cambio de email/username | Email (a dirección anterior Y nueva) | Inmediato |

---

#### 7. REGLAS NO NEGOCIABLES

| # | Regla | Fundamento |
|---|-------|-----------|
| R1 | Credenciales iniciales siempre aleatorias (CSPRNG, ≥ 256 bits entropía) | OWASP ASVS 2.5.8 |
| R2 | Credenciales iniciales expiran en 24h o primer uso | OWASP ASVS 2.5.8 |
| R3 | Cambio de contraseña requiere contraseña actual | OWASP ASVS 2.1.6 |
| R4 | Admin NUNCA ve ni elige la contraseña del usuario | OWASP ASVS 2.5.10 |
| R5 | Recuperación requiere identity proofing ≥ nivel enrollment | OWASP ASVS 2.5.6-2.5.7 |
| R6 | Sin KBA (preguntas de seguridad) — deprecado por NIST | NIST SP 800-63B Rev.4 §5.1.1.2 |
| R7 | Cada cambio de credenciales → notificación al usuario | OWASP ASVS 2.2.3 |
| R8 | Cada cambio de credenciales → audit_event con ctx_id | ISO 27001 A.8.15 |
| R9 | Rate limiting en todos los endpoints de autenticación | NIST SP 800-63B §5.2.2 |
| R10 | PII y datos biométricos: AES-256-GCM en reposo, nunca en logs | RGPD Art.9 |

---

*SKULL · SBOS · SBOS-BAUTH-USER-REGISTRATION-v1_0 · Junio 2026*
*Estándares: NIST SP 800-63B Rev.4 · NIST SP 800-63-4 · OWASP ASVS v5.0 · ISO 27001:2022 · ISO/IEC 24760-2:2025 · RGPD Art.4/9/17/20*


---

## 4.bis Estado de materialización en código (verificado 2026-07-11)

| Pieza | Evidencia | Estado |
|---|---|---|
| Argon2id (credencial inicial + cambio) | `argon2` en Cargo.toml + `password/` (A.15) | ✅ real |
| Diceware (credencial aleatoria) | por verificar módulo dedicado | ⚠️ |
| `credential.rs` (ciclo de vida) | **solo 61 líneas** — delgado | ⚠️ parcial |
| **Identity proofing (IAL 1-3)** | **sin módulo dedicado** (grep IAL → menciones sueltas, no un `proofing.rs`); `identity_proofing` del UserTemplate no existe aún (A.02 U1) | ❌ el registro IAL no está implementado |
| Recuperación de acceso (password + MFA perdido) | `recovery.rs` (auth_methods, 101 líneas) + `credential.rs` | ⚠️ parcial |

**Hallazgo crudo:** el ciclo de credenciales tiene las primitivas (Argon2id, recovery codes)
pero **el identity proofing IAL 1-3 — el corazón de este anexo — no tiene código**. Es la fuente
de la resolución A.02 U1 (`identity_proofing`), que sigue siendo especificación. `credential.rs`
(61 líneas) es delgado para el ciclo de vida completo que 800-63B §6 exige.

**Brechas de código:** IAL proofing ausente (P1, pilar Directory/AM) · `credential.rs` delgado (P2) · diceware por verificar (P2).

## 5. Referencias e historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.1.0 | 2026-07-11 | **Añadida verificación de código real** (§4.bis: Argon2id+recovery reales pero IAL proofing SIN código (fuente de A.02 U1); credential.rs delgado 61 líneas). |
| 1.0.0 | 2026-07-11 | Anexo inicial: el ciclo de entrada de la identidad (proofing IAL 1–3, diceware, self-service, recuperación con verificación reforzada, notificaciones ASVS 2.2.3), su papel como fuente de la resolución A.02 U1, verificación de completitud y traslado fiel íntegro. |
