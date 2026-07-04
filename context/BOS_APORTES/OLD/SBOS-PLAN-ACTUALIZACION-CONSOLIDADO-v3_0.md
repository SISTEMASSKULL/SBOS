# SBOS — Plan de Actualización Consolidado del Sistema de Autenticación
## Versión Definitiva: Integración de Métodos de Autenticación, Dominios y Keycloak
### SKULL · SBOS — Sovereign Business Operating System
### v3.0 · Abril 2026 · CONFIDENCIAL

---

| Campo | Valor |
|---|---|
| **Documento** | SBOS-PLAN-ACTUALIZACION-CONSOLIDADO-v3_0 |
| **Consolida** | SBOS-PLAN-ACTUALIZACION-v1_0 + SBOS-PLAN-ACTUALIZACION-VALIDADO-v2_0 |
| **Complementa** | FrameworkAuthentication_Configuraciones_Metodos_de_Autenticacion_completo.txt |
| **Fuentes adicionales** | Investigación de integración Keycloak con sistemas externos (Abril 2026) |
| **Custodio** | Principal Systems Architect — SKULL |
| **Estado** | LISTO PARA REVISIÓN ARB |
| **Estándares** | NIST SP 800-63B-4 (Ago 2025) · NIST SP 800-63C-4 · ISO/IEC 27001:2022 · ANSI/INCITS 359-2004 · OASIS XACML 3.0 · IEEE 802.1X-2020 · FIDO2/WebAuthn W3C · RGPD Art.9 · RFC 9470 Step-Up |

---

## Tabla de Contenidos

1. [Resumen Ejecutivo Consolidado](#1-resumen-ejecutivo-consolidado)
2. [Correcciones Críticas del Plan v1.0 (validadas en v2.0)](#2-correcciones-criticas)
3. [Los 15 Métodos de Autenticación Canónicos del SBOS](#3-metodos-de-autenticacion)
4. [Integración Keycloak: Nativo vs Extensiones vs Externo](#4-integracion-keycloak)
5. [Estándares de Autenticación: Mapeo Completo](#5-estandares-de-autenticacion)
6. [Brechas Identificadas y Estado](#6-brechas-identificadas)
7. [Plan de Acción por Fases (Corregido y Definitivo)](#7-plan-de-accion)
8. [Especificaciones Técnicas por Artefacto](#8-especificaciones-tecnicas)
9. [Authentication_Framework.json — Versión Consolidada v3.0](#9-authentication-framework)
10. [Policies_Authentication_Framework.json — Versión Consolidada v3.0](#10-policies-framework)
11. [deploy.yml — Configuración Regional (Nuevo Artefacto)](#11-deploy-yml)
12. [bauth.toml — Secciones Migradas](#12-bauth-toml)
13. [Correcciones al RolTemplate y SAM-128](#13-correcciones-roltemplate)
14. [Decision Log Consolidado](#14-decision-log)
15. [Criterios de Aceptación por Fase](#15-criterios-aceptacion)
16. [Estimación de Esfuerzo](#16-estimacion-esfuerzo)
17. [Apéndice A: Mapa de Responsabilidades](#17-apendice-a)
18. [Apéndice B: Tabla de Estándares](#18-apendice-b)

---

## 1. Resumen Ejecutivo Consolidado

Este documento consolida el `SBOS-PLAN-ACTUALIZACION-v1_0.md` y el `SBOS-PLAN-ACTUALIZACION-VALIDADO-v2_0.md`, incorporando el catálogo completo de métodos de autenticación del `Authentication_Framework` y la investigación sobre integración de Keycloak con sistemas externos para soportar todos los métodos requeridos.

### 1.1 Estado del Sistema de Autenticación

```
ESTADO ACTUAL                          ESTADO OBJETIVO (v3.0 consolidado)
─────────────────────────────────      ────────────────────────────────────────────
✅ Dominio Lógico (parcial)            ✅ Dominio Lógico (completo — 9 dominios)
✅ Dominio Físico (completo)           ✅ Dominio Físico (sin cambios)
⚠️  Dominio Financiero (sin máscara)   ✅ Dominio Financiero (FinancialDomainMask)
❌ Dominio de Red (ausente)            ✅ Dominio de Red (network_domain)
❌ Dominio de Aplicación (ausente)     ✅ Dominio de Aplicación (application_domain)
⚠️  Dominio Biométrico (mezclado)      ✅ Dominio Biométrico (separado política/datos)
❌ Dominio Federado (ausente)          ✅ Dominio Federado (federation_domain)
⚠️  Dominio Organizacional (disperso)  ✅ Dominio Organizacional (unificado)
⚠️  Dominio Normativo (parcial)        ✅ Dominio Normativo (deploy.yml — corrección v2.0)

5 métodos de autenticación             15 métodos canónicos documentados
modelados en el framework              con integración Keycloak especificada

bos_bitmask 64-bit legacy             BitmaskBundle: Physical + Logical + Financial
Jurisdicción en RolTemplate (❌)       Jurisdicción en deploy.yml (✅ corrección v2.0)
```

### 1.2 Hallazgos Críticos del Plan v2.0 (Mantenidos)

**ERROR CRÍTICO CORREGIDO — Jurisdicción en módulo de autenticación:**
El plan v1.0 colocaba incorrectamente `regulatory_frameworks.jurisdiction_triggers` (Bolivia, Argentina, México) dentro del RolTemplate y bits `GOV_NORMATIVE_BO/AR/MX` en el SAM-128. Esta violación del principio de responsabilidad única fue corregida en v2.0: la jurisdicción pertenece exclusivamente a `deploy.yml`. Este plan consolida esa corrección.

**INCONSISTENCIA CORREGIDA — Política de contraseñas:**
NIST SP 800-63B-4 (agosto 2025) establece mínimo de 15 caracteres cuando la contraseña es el único autenticador, y elimina la rotación periódica obligatoria. El plan v1.0 especificaba 12 caracteres y rotación a 90 días. Corregido en este documento.

**NUEVO — Catálogo completo de métodos de autenticación:**
Este documento consolida por primera vez el catálogo completo de 15 métodos de autenticación del `Authentication_Framework` con su mapeo a implementaciones de Keycloak (nativo, SPI, o integración externa).

---

## 2. Correcciones Críticas del Plan v1.0

### 2.1 Error J1: Jurisdicción en RolTemplate → Movida a deploy.yml

**Incorrecto (plan v1.0):**
```json
"regulatory_frameworks": {
  "auto_activate_from_seed": true,
  "jurisdiction_triggers": {
    "BO": { "bits": ["GOV_NORMATIVE_BO"], "connectors": ["SIAT"] },
    "AR": { "bits": ["GOV_NORMATIVE_AR"], "connectors": ["AFIP"] }
  }
}
```

**Correcto (plan v3.0):**
La jurisdicción regional no es una propiedad de identidad del usuario. Es una propiedad de la instalación del sistema. El SBOS instalado en Bolivia aplica normativa boliviana a TODOS los usuarios, independientemente de su rol. Esto pertenece exclusivamente a `deploy.yml` y activa módulos regionales en Tryton, bkernel, y conectores fiscales — nunca en bAuth.

### 2.2 Error J2: Bits GOV_NORMATIVE_BO/AR/MX en SAM-128 → Eliminados

El SAM-128 es un vector de autorización de acceso, no un registro de cumplimiento normativo regional. Los bits jurisdiccionales han sido eliminados. En su lugar, se reemplazaron con:
- `GOV_AUDIT_PCI` (Bit 110): rol sujeto a auditoría PCI-DSS
- `GOV_AUDIT_GDPR_BIO` (Bit 111): rol con datos biométricos RGPD

### 2.3 Error J6: Política de contraseñas desactualizada

| Parámetro | Plan v1.0 (incorrecto) | Plan v3.0 (NIST SP 800-63B-4) |
|---|---|---|
| Longitud mínima (factor único) | 12 chars | **15 chars** |
| Longitud mínima (con MFA) | 12 chars | **8 chars** |
| Rotación periódica | `max_age_days: 90` | **Solo ante compromiso detectado** |
| Reglas de complejidad | Mayúsculas + símbolos | **Screening de contraseñas comprometidas** |

### 2.4 Corrección Fase 4 → Cancelada

La Fase 4 del plan v1.0 (reorganización SAM-128 Q4 para bits jurisdiccionales AR/MX) se cancela completamente. Resultado: **ahorro de 2 semanas** en el cronograma.

---

## 3. Los 15 Métodos de Autenticación Canónicos del SBOS

El `Authentication_Framework` define 15 métodos en 5 categorías. Esta sección los consolida con su implementación en Keycloak, LoA asignado, y estatus NIST SP 800-63B-4.

### Categoría 1 — Basados en Conocimiento

#### Método 1: Username + Password

| Atributo | Valor |
|---|---|
| **ID canónico** | `username_password` |
| **LoA** | 1 (factor único); 2 (combinado con MFA) |
| **Resistente a phishing** | No |
| **NIST SP 800-63B-4** | PERMITTED — mínimo 15 chars como único factor |
| **Keycloak** | **Nativo** — Username Password Form |
| **SPI requerido** | Ninguno |
| **Configuración clave** | `password_policy` en KC realm; `global_minimums.password_min_length_sole_authenticator: 15` |

**Notas de implementación:** NIST SP 800-63B-4 §5.1.1 elimina reglas de complejidad arbitrarias (mayúsculas, símbolos) en favor de screening contra listas de contraseñas comprometidas (HaveIBeenPwned API o equivalente). El `Authentication_Framework` debe reflejar esto.

#### Método 2: TOTP (Time-based One-Time Password)

| Atributo | Valor |
|---|---|
| **ID canónico** | `totp` |
| **LoA** | 2 (combinado con contraseña) |
| **Resistente a phishing** | No (vulnerable a intercepción en tiempo real) |
| **NIST SP 800-63B-4** | PERMITTED — AAL2 |
| **Estándar** | RFC 6238 |
| **Keycloak** | **Nativo** — OTP Form |
| **SPI requerido** | Ninguno |
| **Configuración clave** | `otpPolicyType: "totp"`, `otpPolicyPeriod: 30` en KC |

#### Método 3: HOTP (HMAC-based One-Time Password)

| Atributo | Valor |
|---|---|
| **ID canónico** | `hotp` |
| **LoA** | 2 |
| **NIST SP 800-63B-4** | PERMITTED |
| **Estándar** | RFC 4226 |
| **Keycloak** | **Nativo** — OTP Form modo counter |
| **Uso recomendado** | Dispositivos sin reloj (tokens físicos sin batería) |

#### Método 4: Códigos de Recuperación (Backup Codes)

| Atributo | Valor |
|---|---|
| **ID canónico** | `backup_codes` |
| **LoA** | 1 (recuperación únicamente) |
| **NIST SP 800-63B-4** | PERMITTED_RECOVERY_ONLY |
| **Keycloak** | **Nativo** — Recovery Codes |
| **Restricción crítica** | Nunca como factor principal o segundo factor habitual |

#### Método 5: Security Questions

| Atributo | Valor |
|---|---|
| **ID canónico** | `security_questions` |
| **LoA** | Ninguno (solo recuperación de cuenta — débil) |
| **NIST SP 800-63B-4** | NOT RECOMMENDED — NIST desaconseja como mecanismo de seguridad |
| **Keycloak** | Via SPI solamente — no recomendado |
| **Restricción crítica** | Nunca como factor de autenticación — solo recuperación limitada |

### Categoría 2 — Basados en Posesión

#### Método 6: WebAuthn / FIDO2 (Hardware Key — Roaming Authenticator)

| Atributo | Valor |
|---|---|
| **ID canónico** | `webauthn_roaming` |
| **LoA** | 3 |
| **Resistente a phishing** | **Sí** — vinculado criptográficamente al origen |
| **NIST SP 800-63B-4** | PERMITTED — AAL3 |
| **Estándar** | FIDO2/WebAuthn W3C (2023) |
| **Keycloak** | **Nativo** desde KC 21+ — WebAuthn Authenticator |
| **Dispositivos** | YubiKey, Nitrokey, Google Titan, Token2 |
| **SPI requerido** | Ninguno para uso básico; BOS-SmartCardPIN-SPI para PIV |

**Configuración KC:**
```
Authentication Flow: webauthn-authenticator
userVerification: required
attestation: direct (para alta seguridad)
```

#### Método 7: Passkeys (Syncable Authenticators)

| Atributo | Valor |
|---|---|
| **ID canónico** | `passkey` |
| **LoA** | 2 |
| **Resistente a phishing** | **Sí** |
| **NIST SP 800-63B-4** | **PERMITTED — AAL2** (Apéndice B, agosto 2025) |
| **Estándar** | FIDO2/WebAuthn W3C con sincronización |
| **Keycloak** | **Nativo** desde KC 26.4+ — modo sync habilitado |
| **Plataformas** | iCloud Keychain, Google Password Manager, Windows Hello |
| **Nota importante** | AAL2 válido desde publicación final NIST SP 800-63B-4 (agosto 2025) |

#### Método 8: X.509 / Smart Card (Logical)

| Atributo | Valor |
|---|---|
| **ID canónico** | `x509_smartcard` |
| **LoA** | 3–4 |
| **Resistente a phishing** | **Sí** |
| **NIST SP 800-63B-4** | PERMITTED — AAL3 |
| **Keycloak** | **Nativo** — X.509 Client Certificate authenticator |
| **SPI adicional** | `BOS-SmartCardPIN-SPI` para validación PIN del chip |
| **Protocolo** | CCID (USB), contactless PIV |

#### Método 9: Magic Link (Email)

| Atributo | Valor |
|---|---|
| **ID canónico** | `magic_link` |
| **LoA** | 1 |
| **NIST SP 800-63B-4** | PERMITTED |
| **Keycloak** | **Nativo** — Magic Link authenticator |
| **TTL recomendado** | 5 minutos |
| **Restricción** | Solo LoA1; no usar como segundo factor principal |

#### Método 10: SMS OTP

| Atributo | Valor |
|---|---|
| **ID canónico** | `sms_otp` |
| **LoA** | 1 |
| **Resistente a phishing** | No (SIM swapping, SS7 vulnerabilities) |
| **NIST SP 800-63B-4** | **RESTRICTED** — §5.2.10 Restricted Authenticators |
| **Keycloak** | **No nativo** — requiere `BOS-SMS-SPI` + proveedor externo |
| **Proveedores compatibles** | Twilio, AWS SNS, Vonage — integrados via SPI Java |
| **Obligación documental** | Análisis de riesgo documentado + notificación al usuario de riesgos |

**Código de ejemplo BOS-SMS-SPI:**
```java
// SPI: BOS-SMS-SPI — implementa ConditionalAuthenticator
// Requiere proveedor externo de SMS (Twilio, AWS SNS, etc.)
public class BOSSmsAuthenticator implements Authenticator {
    @Override
    public void authenticate(AuthenticationFlowContext context) {
        String phoneNumber = context.getUser().getFirstAttribute("phone_number");
        String otp = generateOTP();
        smsProvider.send(phoneNumber, "Su código SBOS: " + otp);
        // Almacenar OTP cifrado en sesión KC...
        context.challenge(createOTPForm());
    }
}
```

#### Método 11: Email OTP

| Atributo | Valor |
|---|---|
| **ID canónico** | `email_otp` |
| **LoA** | 1 |
| **NIST SP 800-63B-4** | **RESTRICTED_AS_SOLE_SECOND_FACTOR** |
| **Keycloak** | **Nativo** desde KC 26+ — Email OTP authenticator |
| **Restricción crítica** | **PROHIBIDO** como único segundo factor cuando el primero es contraseña |
| **Uso permitido** | Factor adicional en flujos de 3+ factores |

#### Método 12: Push Notification (App Móvil)

| Atributo | Valor |
|---|---|
| **ID canónico** | `push_notification` |
| **LoA** | 2 |
| **NIST SP 800-63B-4** | PERMITTED |
| **Keycloak** | **No nativo** — requiere `BOS-Push-SPI` |
| **Riesgo** | MFA fatigue si no se implementa número de transacción visible |
| **Implementación** | Firebase Cloud Messaging (FCM) / APNs + app SBOS |

### Categoría 3 — Basados en Inherencia

#### Método 13: WebAuthn Biométrico (Platform Authenticator)

| Atributo | Valor |
|---|---|
| **ID canónico** | `webauthn_platform` |
| **LoA** | 2 |
| **Resistente a phishing** | **Sí** — vinculado al dispositivo y al origen |
| **NIST SP 800-63B-4** | PERMITTED — AAL2 con `userVerification: required` |
| **Keycloak** | **Nativo** desde KC 21+ — WebAuthn Passwordless |
| **Dispositivos** | Face ID, Touch ID, Windows Hello, Android biometric |
| **Importante** | KC procesa la firma criptográfica; el sensor biométrico opera localmente — KC nunca recibe datos biométricos |

### Categoría 4 — Basados en Contexto

#### Método 14: Kerberos / SPNEGO

| Atributo | Valor |
|---|---|
| **ID canónico** | `kerberos_spnego` |
| **LoA** | 2 |
| **Resistente a phishing** | **Sí** — en redes corporativas |
| **NIST SP 800-63B-4** | PERMITTED |
| **Keycloak** | **Nativo** — Kerberos authenticator + keytab |
| **Caso de uso** | Entornos Active Directory / on-premise |
| **Configuración** | `kerberosPrincipal`, `kerberosRealm`, keytab file |

#### Método 15: Social Login / OIDC Federation / LDAP

| Atributo | Valor |
|---|---|
| **ID canónico** | `federated_identity` |
| **LoA** | Variable (hereda LoA del IdP externo) |
| **Keycloak** | **Nativo** — Identity Brokering + LDAP federation |
| **Estándar** | OAuth 2.0 RFC 6749, OIDC, SAML 2.0 |
| **Caso de uso** | SSO con otros sistemas empresariales, Google Workspace, Azure AD |

### Categoría 5 — Dominio Físico (Canal bhnexus — Fuera del Alcance KC)

Estos métodos operan en el canal `banexus → bhnexus → bAuth`. Keycloak no los procesa directamente.

#### Método F1: QR Dinámico

| Atributo | Valor |
|---|---|
| **ID canónico** | `qr_dynamic_physical` |
| **LoA** | 1–2 |
| **Generado por** | bAuth (HMAC-SHA256, TTL 30s) |
| **Validado por** | bhnexus — verifica HMAC y TTL |
| **KC involucrado** | No en tiempo real; el JWT se valida post-autenticación |

#### Método F2: Hash Biométrico Físico (Lector OSDP)

| Atributo | Valor |
|---|---|
| **ID canónico** | `fingerprint_hash_physical` / `face_hash_physical` |
| **LoA** | 3 |
| **Procesado por** | Lector biométrico OSDP v2.2.2 (enclave seguro del chip) |
| **Enviado** | Solo el hash PBKDF2-SHA256 — nunca el raw biometric |
| **Validado por** | bAuth contra `bauth_biometric_templates` |
| **RGPD** | Compliant — raw biometric nunca sale del chip del lector |

---

## 4. Integración Keycloak: Nativo vs Extensiones vs Externo

### 4.1 Tabla de Soporte Completo

| Método | Keycloak Nativo | SPI Requerido | Sistema Externo | Notas |
|---|---|---|---|---|
| `username_password` | ✅ | — | — | Configurar min 15 chars (NIST) |
| `totp` | ✅ | — | — | RFC 6238 |
| `hotp` | ✅ | — | — | RFC 4226 |
| `backup_codes` | ✅ | — | — | Solo recuperación |
| `security_questions` | ⚠️ via SPI | SPI básico | — | No recomendado |
| `webauthn_roaming` | ✅ KC 21+ | — | — | YubiKey, hardware keys |
| `passkey` | ✅ KC 26.4+ | — | — | AAL2 válido (NIST 2025) |
| `x509_smartcard` | ✅ | BOS-SmartCardPIN-SPI | — | Para validación PIN del chip |
| `magic_link` | ✅ | — | SMTP configurado | TTL 5 min |
| `sms_otp` | ❌ | BOS-SMS-SPI | Twilio / AWS SNS / Vonage | Restricted authenticator |
| `email_otp` | ✅ KC 26+ | — | SMTP | Prohibido como único 2do factor |
| `push_notification` | ❌ | BOS-Push-SPI | FCM / APNs + app SBOS | Riesgo MFA fatigue |
| `webauthn_platform` | ✅ KC 21+ | — | — | Face ID, Touch ID, Windows Hello |
| `kerberos_spnego` | ✅ | — | AD / Kerberos realm | Entornos on-premise |
| `federated_identity` | ✅ | — | IdP externo (OIDC/SAML) | Azure AD, Google Workspace |
| `qr_dynamic_physical` | ❌ | — | Canal bhnexus | Fuera del alcance de KC |
| `fingerprint_hash_physical` | ❌ | — | Canal bhnexus + lector OSDP | Fuera del alcance de KC |
| Biometría avanzada multimodal | ❌ | — | FaceTec, BioID vía OIDC/SAML | Federado como IdP externo |
| IoT/M2M certificates | ⚠️ parcial | — | Plataforma IoT + Keycloak tokens | KC como servidor de autorización |
| Quantum-resistant crypto | ❌ | — | liboqs / Open Quantum Safe | Capa criptográfica JVM |

### 4.2 Los 5 SPIs del SBOS para Keycloak

El SBOS despliega 5 SPIs personalizados que cubren las condiciones contextuales que Keycloak nativo no soporta. Se implementan en Java como `org.keycloak.authentication.Authenticator`.

#### SPI-1: BOS-Guard — SkbosGuardAuthenticator

**Responsabilidad:** Se ejecuta primero en cada Authentication Flow. Lee `availableMethods` del RolTemplate (vía User Attributes del grupo KC) y bloquea cualquier método que no esté autorizado para el rol.

```java
public class SkbosGuardAuthenticator implements ConditionalAuthenticator {
    public static final String PROVIDER_ID = "bos-guard-authenticator";

    @Override
    public boolean matchCondition(AuthenticationFlowContext context) {
        String requestedMethod = context.getAuthenticationSession()
                                        .getClientNote("requested_method");
        Set<String> allowedMethods = getUserAllowedMethods(context.getUser());
        if (requestedMethod != null && !allowedMethods.contains(requestedMethod)) {
            context.getEvent().error("method_not_authorized_for_role");
            return false;
        }
        return true;
    }
}
```

#### SPI-2: BOS-GeoContext — SkbosGeoContextAuthenticator

**Responsabilidad:** Verifica que el usuario se conecta desde una red autorizada por su RolTemplate. Lee `allowed_networks` del User Attribute (sincronizado desde `RolTemplate.logical_access.geospatial_control`).

```java
public class SkbosGeoContextAuthenticator implements ConditionalAuthenticator {
    public static final String PROVIDER_ID = "bos-geocontext-authenticator";

    @Override
    public boolean matchCondition(AuthenticationFlowContext context) {
        String allowedNetworks = context.getUser().getFirstAttribute("allowed_networks");
        if (allowedNetworks == null) return true;

        String remoteAddr = context.getConnection().getRemoteAddr();
        boolean inAllowedNetwork = Arrays.stream(allowedNetworks.split(","))
                                         .anyMatch(cidr -> isInCidr(remoteAddr, cidr.trim()));
        if (!inAllowedNetwork) {
            context.getEvent().error("login_from_unauthorized_network");
            return false;
        }
        return true;
    }
    // isInCidr(): implementación con InetAddress — ver SBOS-008-001
}
```

#### SPI-3: BOS-FinancialPeriod — SkbosFinancialPeriodAuthenticator

**Responsabilidad:** Verifica `transaction_schedule` del RolTemplate. Deniega operaciones financieras fuera de la ventana declarada (quincenas de pago, horario bancario).

#### SPI-4: BOS-RoleValidity — SkbosRoleValidityAuthenticator

**Responsabilidad:** Verifica que `validity_period.end_date` del RolTemplate no ha expirado. Si el rol venció, deniega el login con mensaje descriptivo.

```java
public class SkbosRoleValidityAuthenticator implements ConditionalAuthenticator {
    @Override
    public boolean matchCondition(AuthenticationFlowContext context) {
        String validUntil = context.getUser().getFirstAttribute("role_valid_until");
        if (validUntil == null) return true;
        try {
            Instant expiresAt = Instant.parse(validUntil);
            if (Instant.now().isAfter(expiresAt)) {
                context.getEvent().error("role_expired");
                return false;
            }
        } catch (DateTimeParseException e) {
            context.getEvent().detail("warning", "role_valid_until_parse_error");
        }
        return true;
    }
}
```

#### SPI-5: BOS-SmartCardPIN — SkbosSmartCardPINAuthenticator

**Responsabilidad:** Gestiona flujo X.509 + PIN para tarjetas inteligentes corporativas. Complementa el X.509 nativo de KC con validación del PIN del chip.

### 4.3 Estrategia para Métodos Avanzados (Biometría Multimodal, IoT, Quantum)

#### Biometría Avanzada Multimodal (ISO 19794)

Keycloak no procesa biometría directamente. La estrategia correcta es:

1. **Proveedor externo** (FaceTec, BioID, Aware, Innovatrics) valida la biometría.
2. El proveedor externo actúa como IdP federado via OIDC/SAML hacia Keycloak.
3. KC recibe el assertion de identidad del proveedor externo (ya autenticado biométricamente).
4. KC emite el JWT final con los claims `bos_*` del SBOS.

**Ejemplo de integración FaceTec + KC:**
```
Usuario → FaceTec (3D face liveness) → OIDC assertion
  → KC Identity Broker (confía en FaceTec como IdP externo)
  → KC emite JWT con acr="loa3" + amr=["face_biometric"]
  → bAuth valida que el rol permite `biometric_login`
```

#### IoT / M2M Authentication

Para dispositivos IoT, Keycloak actúa como servidor de autorización (Resource Server en OAuth 2.1):

1. **Certificados X.509 del dispositivo:** gestionados por una PKI dedicada (HashiCorp Vault PKI, EJBCA, Let's Encrypt para IoT).
2. **Token JWT para el dispositivo:** Keycloak emite tokens con `client_credentials` flow.
3. **Gestión de flota:** Plataforma IoT (AWS IoT Core, Azure IoT Hub, Eclipse Mosquitto con auth plugin) gestiona el ciclo de vida del dispositivo.
4. **bAuth sincroniza:** los permisos del dispositivo (tratado como service account) via UserTemplate con `account_type: "SERVICE"`.

```yaml
# Flujo IoT con Keycloak:
device → mTLS (certificado X.509) → Keycloak client_credentials
  → JWT con claims de permisos del dispositivo
  → bAuth evalúa SAM-128 del service account
  → banexus / bhnexus ejecutan con los permisos del dispositivo
```

#### Quantum-Resistant Cryptography

Keycloak (v26.x) aún depende de algoritmos clásicos (RSA, ECC) en la JVM. La ruta de migración:

1. **Corto plazo (v0.9–v1.0):** Modo híbrido — `CRYSTALS-Kyber-1024` + `ECDH-P521` en bAuth para firma de templates. KC sigue usando RSA/EC para sus propias operaciones.
2. **Mediano plazo (v1.5):** Integrar `Open Quantum Safe (liboqs)` como proveedor JCA/JCE en la JVM de Keycloak. KC puede usar algoritmos PQC cuando la JVM lo soporte.
3. **Largo plazo (v2.0+):** Cuando OpenJDK incluya soporte nativo para NIST PQC standards (Kyber, Dilithium), KC los adoptará automáticamente.

**Recurso:** [Open Quantum Safe — liboqs-java](https://github.com/open-quantum-safe/liboqs-java) permite integración JVM.

### 4.4 Keycloak como Orquestador Central

La arquitectura correcta del SBOS posiciona Keycloak como el **punto central de federación y emisión de tokens**, delegando las capacidades avanzadas a sistemas especializados:

```
                    ┌─────────────────────────────────┐
                    │         bAuth (orquestador)     │
                    │    RolTemplate → SAM-128 → KC   │
                    └──────────────┬──────────────────┘
                                   │ sincroniza
                    ┌──────────────▼──────────────────┐
                    │           KEYCLOAK               │
                    │    (núcleo de federación)        │
                    │  • Autenticación nativa (pwd,    │
                    │    TOTP, WebAuthn, passkeys)     │
                    │  • Authentication Flows + SPIs   │
                    │  • Emisión de JWT firmados       │
                    │  • Identity Brokering (OIDC/SAML)│
                    └──┬──────┬──────┬────────┬───────┘
                       │      │      │        │
              ┌────────▼─┐  ┌─▼───┐ ┌▼──────┐ ┌▼──────────┐
              │ FaceTec  │  │LDAP/│ │ Open  │ │ Plataforma │
              │ BioID    │  │AD   │ │Quantum│ │ IoT + PKI  │
              │(biometría│  │(SSO)│ │Safe   │ │(dispositivos│
              │ multimod)│  │     │ │(PQC)  │ │ X.509)     │
              └──────────┘  └─────┘ └───────┘ └────────────┘
```

---

## 5. Estándares de Autenticación: Mapeo Completo

### 5.1 FIDO2 / WebAuthn (ISO 19794 + W3C)

El `Authentication_Framework` define un sistema biométrico FIDO2-compliant. Mapeo a implementación:

| Elemento del Framework | Implementación SBOS | Componente |
|---|---|---|
| `multimodalAuthentication.fusionEngine` | BitmaskBundle evalúa múltiples factores | bAuth PrivilegeEngine |
| `facialRecognition.neuralEngine.minimumAccuracy: 0.999` | `biometric_enrollment_policy.fmr_threshold: "1:10000"` | RolTemplate |
| `livenessDetection.methods: [microexpression, eyeReflection, skinTexture]` | Delegado al proveedor biométrico externo (FaceTec) | Integración OIDC |
| `fingerprintRecognition.imagingSystem.resolution: "16000dpi"` | Especificación del lector físico OSDP | Device ficha bhnexus |
| `spoofingPrevention.materialAnalysis.sensors: [capacitive, optical, ultrasonic]` | Hardware del lector biométrico OSDP v2.2.2 | Infraestructura física |

**Nota crítica:** Todo el procesamiento biométrico avanzado (redes neuronales, fusión multimodal) ocurre en el hardware del lector o en el sistema externo. El SBOS solo almacena y verifica el hash derivado (PBKDF2-SHA256).

### 5.2 WebAuthn / FIDO2 Standards

El `Policies_Authentication_Framework` define políticas FIDO2 completas:

```json
// De Policies_Authentication_Framework.json — correctamente mapeado
"webauthn_fido2": {
  "authenticator_policies": {
    "platform_authenticator": {
      "requirements": {
        "tpm_verification": true,         // → KC: attestation = "direct"
        "secure_element": true,           // → KC: authenticator bound
        "biometric_capability": true      // → KC: userVerification = "required"
      }
    },
    "roaming_authenticator": {
      "requirements": {
        "fido2_certification": true,      // → AAGUID validation
        "minimum_key_size": 256,          // → KC key size validation
        "user_verification": true         // → KC: userVerification = "required"
      }
    }
  },
  "registration_policies": {
    "attestation": {
      "policy": "direct",                 // → KC attestation policy
      "trusted_roots": ["FIDO_CERTIFIED", "APPLE", "GOOGLE"] // → KC trusted attestation roots
      "format_preferences": ["packed", "tpm", "android-key", "android-safetynet"]
    }
  }
}
```

**Implementación en Keycloak:**
```
Authentication Flow: SBOS-WebAuthn-Flow
  Execution 1: [REQUIRED] Username Form (nativo)
  Execution 2: [REQUIRED] WebAuthn Authenticator (nativo)
    - attestationConveyancePreference: direct
    - userVerificationRequirement: required
    - rpId: "auth.empresa-acme.com"
    - rpName: "SBOS Empresa ACME"
```

### 5.3 Passwordless Standards

El framework define 3 métodos passwordless con mapeo completo:

**Magic Links:**
- Token: JWT, TTL: 300s, single-use: true
- KC: Magic Link authenticator nativo
- Protección phishing: `domain_binding: true`, `click_tracking: true`

**Push Notification:**
- Verificación: challenge-response (número de transacción)
- Protección: `man_in_middle_protection: true`, `replay_prevention: true`, `device_attestation: true`
- KC: BOS-Push-SPI → FCM/APNs

**Biometric Passwordless:**
- Métodos: fingerprint (FMR ≥ 0.95), facial (3D mapping + anti-spoofing), iris (NIR scanning)
- KC: WebAuthn Passwordless con `userVerification: required` para plataforma; proveedor externo para multimodal

### 5.4 Quantum-Resistant Authentication

El framework define algoritmos PQC. Implementación actual vs objetivo:

| Algoritmo | Propósito | Estado SBOS v1.0 | Estado SBOS v2.0 |
|---|---|---|---|
| CRYSTALS-Kyber-1024 | Key exchange | Parcial (bAuth templates) | Completo (bAuth + modo híbrido) |
| NTRU HPS-4096-821 | Fallback key exchange | Definido | Implementar en bauth.toml |
| CRYSTALS-Dilithium | Firma digital | Templates bAuth | Firma de JWT |
| SPHINCS+ | Backup signatures | Definido | Integrar cuando JVM soporte |
| Hybrid mode ECDH-P521 | Transición clásico→PQC | Activo | Mantener hasta v2.0 |

### 5.5 IoT y M2M Authentication

El framework define seguridad IoT con:

**Device Authentication:**
- Certificados X.509 permanentes en secure element
- JWT de larga duración con renovación automática
- mTLS para comunicación bidireccional

**Fleet Management:**
- Zero-touch provisioning
- Rotación automática de certificados
- Detección de anomalías por dispositivo

**Implementación SBOS:**
- KC como servidor de autorización OAuth 2.1 (`client_credentials` flow)
- HashiCorp Vault PKI para gestión de certificados
- bAuth maneja service accounts (UserTemplate `account_type: "SERVICE"`)
- banexus/bhnexus para dispositivos físicos (lectores, relés)

### 5.6 Continuous Authentication (Behavioral Biometrics)

El framework define autenticación continua basada en comportamiento. Implementación:

| Métrica comportamental | Implementación KC | Evaluador |
|---|---|---|
| Keyboard dynamics (keystroke timing) | SPI SkbosGuardAuthenticator monitorea sesión | bAuth ML engine |
| Mouse movements (speed, patterns) | SPI contextual | bAuth ML engine |
| Gesture analysis (touch pressure) | Requiere SDK móvil + SPI | Futuro v2.0 |
| App interaction patterns | bkernel event correlation | bkernel |

**KC Integration:** El SPI `SkbosGuardAuthenticator` puede emitir un challenge de step-up (RFC 9470) cuando la puntuación comportamental cae por debajo del umbral (`confidence_threshold: 0.90`), sin terminar la sesión completa.

---

## 6. Brechas Identificadas y Estado

### 6.1 Brechas Críticas

| Brecha | Plan v1.0 | Plan v2.0 | Estado en v3.0 |
|---|---|---|---|
| Jurisdicción en RolTemplate | ❌ Presente | ✅ Movida a deploy.yml | ✅ **CORREGIDO** |
| Bits GOV_NORMATIVE en SAM-128 | ❌ Presente | ✅ Eliminados | ✅ **CORREGIDO** |
| Longitud mínima contraseña (12 vs 15) | ❌ Incorrecto | ✅ Corregido a 15 | ✅ **CORREGIDO** |
| Rotación periódica contraseñas | ❌ 90 días | ✅ Solo por compromiso | ✅ **CORREGIDO** |
| SMS OTP como "alto riesgo" | ⚠️ Impreciso | ✅ "Restricted Authenticator" | ✅ **CORREGIDO** |

### 6.2 Brechas de Diseño

| Brecha | Estado en v3.0 | Fase |
|---|---|---|
| Dominio de Aplicación ausente (application_domain) | 🔧 A implementar | Fase 1 |
| Dominio de Red ausente (network_domain) | 🔧 A implementar | Fase 1 |
| Biometría mezclada (política + datos) | 🔧 A separar | Fase 1 |
| Dominio Financiero sin máscara propia | 🔧 A implementar | Fase 1 |
| Dominio Federado ausente (federation_domain) | 🔧 A implementar | Fase 2 |
| Dominio Organizacional fragmentado | 🔧 A unificar | Fase 2 |
| LogicalDomainEvaluator faltante | 🔧 A construir | Fase 3 |
| 6 aplicaciones sin integración bAuth | 🔧 A integrar | Fase 3 |
| JSON de autenticación con triple responsabilidad | 🔧 A refactorizar | Fase 0 |
| 15 métodos sin mapeo KC completo | ✅ **RESUELTO en este doc** | — |

### 6.3 Brechas de Implementación KC

| Capacidad | Estado KC actual | Solución |
|---|---|---|
| SMS OTP | No nativo | BOS-SMS-SPI + proveedor externo |
| Push Notification | No nativo | BOS-Push-SPI + FCM/APNs |
| Biometría multimodal avanzada | No nativo | Integración IdP externo (OIDC/SAML) |
| Quantum-resistant crypto | No disponible | liboqs-java en JVM (futuro) |
| Passkeys | Nativo desde KC 26.4+ | Actualizar KC a 26.4+ |
| Email OTP | Nativo desde KC 26+ | Verificar versión KC desplegada |

---

## 7. Plan de Acción por Fases (Corregido y Definitivo)

### Visión General de Fases

```
Pre-v0.9           v0.9 Beta          v0.9 GA            v1.0
(3-4 días)         (1 semana)         (1 semana)         (3-4 semanas)
    │                  │                   │                   │
    ▼                  ▼                   ▼                   ▼
FASE 0             FASE 1             FASE 2             FASE 3
Refactorizar       Dominios           Federación         Evaluadores
JSON corregidos    Faltantes          y Org Domain       e Integraciones
+ deploy.yml       + 15 métodos KC    + deploy.yml       6 apps + JWT
+ bauth.toml       mapeados           jurisdicción       migración
+ Schema v3        + Keycloak SPIs    en producción      + Passkeys KC
                   + Biometría sep.
```

**Fase 4 (plan v1.0) — CANCELADA:** Los bits jurisdiccionales fueron eliminados. Ahorro de 2 semanas.

### Fase 0 — Refactorización Base (Pre-v0.9, 3-4 días)

**Objetivo:** Eliminar ambigüedades en los JSON, corregir política de contraseñas, crear deploy.yml.

**Tareas:**

1. **Refactorizar `Authentication_Framework.json`** → 5 secciones (ver Sección 9)
   - Eliminar todo contenido de política de rol y normativa regional
   - Incorporar los 15 métodos canónicos con status NIST SP 800-63B-4
   - Actualizar `global_minimums.password_min_length_sole_authenticator: 15`
   - Eliminar `max_age_days` de política de contraseñas

2. **Refactorizar `Policies_Authentication_Framework.json`** → 3 secciones (ver Sección 10)
   - Solo políticas mínimas del realm aplicables a todos los roles
   - Eliminar toda referencia a SIAT, AFIP, SAT, LEY_843

3. **Crear `deploy.yml`** (ver Sección 11)
   - Definir estructura `jurisdiction` + `regional_modules` + `data_retention`
   - Este es el ÚNICO lugar donde vive la configuración regional

4. **Crear `bauth.toml`** con secciones migradas (ver Sección 12)
   - Política de contraseñas conforme NIST SP 800-63B-4
   - Sin configuraciones de normativa regional
   - Incluir configuración de los 5 SPIs KC

5. **Actualizar `roltemplate_schema.json`**
   - Agregar validación de nuevos bloques (network_domain, application_domain, federation_domain)
   - Rechazar `regulatory_frameworks.jurisdiction_triggers`
   - Rechazar `email_otp` como único segundo factor
   - Rechazar `password_min_length < 15` cuando es factor único

6. **Crear `migrations/003_add_domains.sql`**
   - Índices GIN para nuevos bloques de dominio
   - Columna `sam128_financial` en bos_rol_template
   - Tabla `bos_zone_application_map`

### Fase 1 — Dominios Faltantes (v0.9 Beta, 1 semana)

**Objetivo:** Agregar los dominios arquitectónicos faltantes al RolTemplate y UserTemplate.

**Tareas:**

1. **Crear SBOS-ROLTEMPLATE-v5_1.md** con bloques nuevos:
   - `network_domain` — IEEE 802.1X, VLANs, protocolos bloqueados
   - `application_domain` — zonas × aplicaciones (OASIS XACML 3.0)
   - `biometric_domain` — política biométrica separada de datos individuales
   - Actualizar SAM-128 Q4: eliminar GOV_NORMATIVE_BO, agregar GOV_AUDIT_PCI/GDPR_BIO

2. **Crear SBOS-USERTEMPLATE-v5_1.md** con bloques nuevos:
   - `financial_limits` — overrides individuales aprobados
   - `biometric_domain.enrolled_templates` — hashes biométricos (separados de physical_credentials)

3. **Crear `zone_application_map.yaml`** — mapeo canónico zona → aplicaciones

4. **Implementar `LogicalDomainEvaluator` básico**
   - Endpoint REST: `POST /api/v1/authorize/logical`
   - Resolución: zona → aplicaciones via zone_application_map.yaml

5. **Configurar los 5 SPIs KC** en el realm de staging
   - Compilar `bauth-spi-1.0.0.jar` con Maven (ver pom.xml en Sección 8)
   - Desplegar en `/opt/keycloak/providers/`
   - Ejecutar `kc.sh build`

6. **Actualizar KC sync en bAuth** para propagar `network_domain`:
   - Leer `allowed_vlans` → escribir User Attribute `bos_vlan_assignment` en KC
   - Extender SkbosGeoContextAuthenticator para verificar VLAN activa

### Fase 2 — Federación y Dominio Organizacional (v0.9 GA, 1 semana)

**Objetivo:** Formalizar federación, unificar dominio organizacional, implementar deploy.yml en producción.

**Tareas:**

1. **Agregar `federation_domain` al RolTemplate:**
   - FAL Level (1–3)
   - Token binding (DPoP — RFC 9449)
   - Trusted identity providers
   - Cross-tenant access controls

2. **Agregar claim `bos_federation_level` al JWT:**
   - KC enriquece el token según `federation_domain.fal_level` del RolTemplate
   - Extensión del SPI SkbosGuardAuthenticator o nuevo token mapper KC

3. **Unificar `organizational_domain` en RolTemplate:**
   - Reemplaza campos fragmentados: `compliance_audit`, `group_management`, `conflict_management`
   - Ciclo de vida completo: onboarding → access_review → offboarding

4. **Implementar `deploy.yml` en producción:**
   - Tenant boliviano: `jurisdiction: "BO"` activa módulos SIAT en Tryton
   - Verificar que bAuth NO recibe ninguna configuración de jurisdicción
   - Validar: `bos_sam128` de usuario normal NO contiene bits jurisdiccionales

5. **Activar Passkeys** en realm de prueba (requiere KC 26.4+):
   - Verificar versión KC desplegada
   - Habilitar WebAuthn Passwordless con sync
   - Documentar en authentication_methods_catalog: `loa: 2, nist_status: "PERMITTED_AAL2"`

### Fase 3 — Evaluadores e Integraciones (v1.0, 3-4 semanas)

**Objetivo:** Completar todos los evaluadores de dominio e integrar 6 aplicaciones.

**Tareas:**

1. **Implementar `LogicalDomainEvaluator` completo:**
   - Todos los verbos universales (READ, WRITE, DELETE, APPROVE, EXECUTE, CONFIGURE, AUDIT, EMIT)
   - Resolución a aplicaciones via `zone_application_map.yaml`
   - Cache Redis con TTL 30s

2. **Implementar `FinancialDomainEvaluator`:**
   - Verificación de límites por tier (0–5)
   - Evaluación SoD en tiempo real
   - Integración con Button Rules de Tryton

3. **Integrar 6 aplicaciones nuevas:**

| Aplicación | Protocolo | Zonas mapeadas | Integración KC |
|---|---|---|---|
| **Saleor** | OIDC + GraphQL API | zone_logical/ventas | Client KC: saleor-storefront |
| **EspoCRM** | OIDC + REST API | zone_logical/ventas, clientes | Client KC: espocrm-api |
| **Zammad** | SAML 2.0 + REST API | zone_logical/soporte | Client KC: zammad-sbos |
| **OrangeHRM** | OIDC + SCIM 2.0 | zone_logical/rrhh | Client KC: orangehrm-sbos |
| **Superset** | OIDC + FAB roles | zone_logical/reportes | Client KC: superset-sbos |
| **Paperless-ngx** | OIDC + REST API | Todas las zonas con READ | Client KC: paperless-sbos |

4. **Migrar JWT — Eliminar `bos_bitmask` legacy:**
   - Emitir exclusivamente: `bos_physical_mask`, `bos_logical_mask`, `bos_financial_mask`
   - Actualizar `trytond-auth-keycloak` → leer `bos_logical_mask`
   - Actualizar `banexus` → leer `bos_physical_mask`
   - Migración JWT: `migrations/004_jwt_legacy_removal.sql`

5. **Eliminar legacy `physical_credentials.biometric_templates`:**
   - Datos migrados a `biometric_domain.enrolled_templates`
   - `migrations/005_biometric_domain_migration.sql`

---

## 8. Especificaciones Técnicas por Artefacto

### 8.1 pom.xml — Proyecto Maven de SPIs KC

```xml
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>bo.skull.sbos</groupId>
  <artifactId>bauth-spi</artifactId>
  <version>1.0.0</version>
  <packaging>jar</packaging>

  <properties>
    <keycloak.version>26.0.0</keycloak.version>
    <java.version>17</java.version>
    <maven.compiler.source>17</maven.compiler.source>
    <maven.compiler.target>17</maven.compiler.target>
  </properties>

  <dependencies>
    <dependency>
      <groupId>org.keycloak</groupId>
      <artifactId>keycloak-core</artifactId>
      <version>${keycloak.version}</version>
      <scope>provided</scope>
    </dependency>
    <dependency>
      <groupId>org.keycloak</groupId>
      <artifactId>keycloak-server-spi</artifactId>
      <version>${keycloak.version}</version>
      <scope>provided</scope>
    </dependency>
    <dependency>
      <groupId>org.keycloak</groupId>
      <artifactId>keycloak-server-spi-private</artifactId>
      <version>${keycloak.version}</version>
      <scope>provided</scope>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <version>3.11.0</version>
      </plugin>
    </plugins>
  </build>
</project>
```

**Archivos META-INF/services requeridos:**
```
META-INF/services/org.keycloak.authentication.AuthenticatorFactory:
  bo.skull.sbos.keycloak.spi.SkbosGuardAuthenticatorFactory
  bo.skull.sbos.keycloak.spi.SkbosGeoContextAuthenticatorFactory
  bo.skull.sbos.keycloak.spi.SkbosFinancialPeriodAuthenticatorFactory
  bo.skull.sbos.keycloak.spi.SkbosRoleValidityAuthenticatorFactory
  bo.skull.sbos.keycloak.spi.SkbosSmartCardPINAuthenticatorFactory
```

### 8.2 zone_application_map.yaml

```yaml
# /etc/bos/blibs/bauth/zone_application_map.yaml
# Fuente canónica: zona de negocio → aplicaciones del ecosistema SBOS
# Actualizar con cada nueva integración de aplicación
zones:
  zone_logical/ventas:
    description: "Operaciones comerciales y gestión de clientes"
    applications:
      - app: tryton
        modules: [sale, sale.opportunity, party]
        client_id: tryton-sbos
        scopes: ["sale.sale:read,write", "party.party:read"]
      - app: saleor
        client_id: saleor-storefront
        scopes: ["orders:read,write"]
      - app: espocrm
        client_id: espocrm-api
        scopes: ["accounts:read,write", "contacts:read,write"]

  zone_logical/contabilidad:
    description: "Registros contables, facturación y pagos"
    applications:
      - app: tryton
        modules: [account, account_invoice, account_payment]
        client_id: tryton-sbos
        scopes: ["account.invoice:read,write"]
      - app: superset
        dashboards: [contabilidad_regional, facturacion_mensual]
        client_id: superset-sbos
        scopes: ["dashboard:read"]
      - app: paperless
        tags: [factura, comprobante, fiscal]
        client_id: paperless-sbos
        scopes: ["document:read"]

  zone_logical/rrhh:
    description: "Gestión de personal, nómina y contratos"
    applications:
      - app: orangehrm
        client_id: orangehrm-sbos
        scopes: ["employee:read,write"]
      - app: tryton
        modules: [payroll, leave]
        client_id: tryton-sbos
      - app: paperless
        tags: [contrato, personal]
        client_id: paperless-sbos

  zone_logical/soporte:
    description: "Gestión de tickets y atención al cliente"
    applications:
      - app: zammad
        client_id: zammad-sbos
        scopes: ["ticket:read,write"]

  zone_logical/reportes:
    description: "Business Intelligence y análisis"
    applications:
      - app: superset
        client_id: superset-sbos
        scopes: ["dashboard:read", "chart:read"]
      - app: tryton
        modules: [account_statement]
        client_id: tryton-sbos

  zone_logical/facturacion:
    description: "Facturación electrónica y documentos fiscales"
    applications:
      - app: tryton
        modules: [account_invoice, account]
        client_id: tryton-sbos
      - app: superset
        dashboards: [facturacion_mensual]
        client_id: superset-sbos
      - app: paperless
        tags: [factura, nota_credito]
        client_id: paperless-sbos
```

### 8.3 migrations/003_add_domains.sql

```sql
-- Agregar índices GIN para los nuevos bloques de dominio
CREATE INDEX IF NOT EXISTS idx_brt_network_domain
  ON bos_rol_template USING GIN((template->'network_domain') jsonb_path_ops)
  WHERE template ? 'network_domain';

CREATE INDEX IF NOT EXISTS idx_brt_application_domain
  ON bos_rol_template USING GIN((template->'application_domain') jsonb_path_ops)
  WHERE template ? 'application_domain';

CREATE INDEX IF NOT EXISTS idx_brt_federation_domain
  ON bos_rol_template USING GIN((template->'federation_domain') jsonb_path_ops)
  WHERE template ? 'federation_domain';

-- Columna para FinancialDomainMask
ALTER TABLE bos_rol_template
  ADD COLUMN IF NOT EXISTS sam128_financial BIGINT;

-- Tabla de mapeo zona → aplicaciones (respaldo de zone_application_map.yaml)
CREATE TABLE IF NOT EXISTS bos_zone_application_map (
    zone_id      TEXT NOT NULL,
    app_id       TEXT NOT NULL,
    app_scopes   TEXT[],
    client_id    TEXT,
    modules      TEXT[],
    active       BOOLEAN DEFAULT true,
    last_updated TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (zone_id, app_id)
);

CREATE INDEX IF NOT EXISTS idx_zam_zone ON bos_zone_application_map(zone_id);

-- Corregir columna sam128_hi para eliminar bits GOV_NORMATIVE que no deben existir
-- (Migración de datos existentes — recalcular Q4 sin bits jurisdiccionales)
-- NOTA: Ejecutar PrivilegeEngine.recalculate_all() tras este script
```

---

## 9. Authentication_Framework.json — Versión Consolidada v3.0

```json
{
  "authenticationFramework": {
    "metadata": {
      "version": "3.0.0",
      "last_updated": "2026-04-16T00:00:00Z",
      "environment": "production",
      "classification": "CONFIDENTIAL",
      "schema_version": "3.0.0",
      "encryption_level": "HIGH",
      "compliance_status": "COMPLIANT",
      "supersedes": "2.0.0",
      "standards_basis": [
        "NIST SP 800-63B-4 (Aug 2025)",
        "NIST SP 800-63C-4 (Aug 2025)",
        "ISO/IEC 27001:2022",
        "FIDO2/WebAuthn W3C (2023)",
        "ANSI/INCITS 359-2004 H-RBAC",
        "IEEE 802.1X-2020",
        "OASIS XACML 3.0",
        "RFC 9449 DPoP",
        "RFC 9470 Step-Up Authentication"
      ]
    },

    "loa_definitions": {
      "loa1": {
        "name": "AAL1 — Assurance Level 1",
        "nist_ref": "NIST SP 800-63B-4 §4.1",
        "min_authenticators": 1,
        "phishing_resistant": false,
        "acceptable_methods": ["username_password", "totp", "hotp", "backup_codes", "magic_link"],
        "use_cases": ["Acceso información pública interna", "Operaciones bajo riesgo"]
      },
      "loa2": {
        "name": "AAL2 — Assurance Level 2",
        "nist_ref": "NIST SP 800-63B-4 §4.2",
        "min_authenticators": 2,
        "phishing_resistant": false,
        "acceptable_methods": [
          "username_password+totp", "username_password+webauthn_platform",
          "passkey", "webauthn_roaming", "push_notification"
        ],
        "use_cases": ["Acceso datos confidenciales", "Operaciones financieras estándar"]
      },
      "loa3": {
        "name": "AAL3 — Assurance Level 3",
        "nist_ref": "NIST SP 800-63B-4 §4.3",
        "min_authenticators": 2,
        "phishing_resistant": true,
        "acceptable_methods": ["webauthn_roaming+hardware_key", "x509_smartcard+pin"],
        "use_cases": ["Aprobaciones alto valor", "Configuración sistema"]
      },
      "loa4_sbos": {
        "name": "LoA4 — Extensión SBOS (quórum)",
        "nist_ref": "Extensión sobre NIST SP 800-63B-4 §4.3",
        "min_authenticators": 2,
        "phishing_resistant": true,
        "quorum_required": true,
        "min_quorum_approvers": 2,
        "use_cases": ["Cierre período fiscal", "Pagos sobre límite máximo"]
      }
    },

    "authentication_methods_catalog": {
      "_note": "Catálogo de referencia de solo lectura. Las políticas de uso por rol se definen en RolTemplate.",
      "methods": [
        {
          "id": "username_password", "category": "KNOWLEDGE", "loa": 1,
          "phishing_resistant": false, "nist_status": "PERMITTED",
          "keycloak": { "native": true, "implementation": "Username Password Form" },
          "notes": "Mínimo 15 chars como factor único (NIST SP 800-63B-4). Sin reglas complejidad — usar screening."
        },
        {
          "id": "totp", "category": "POSSESSION", "loa": 2,
          "phishing_resistant": false, "nist_status": "PERMITTED",
          "keycloak": { "native": true, "implementation": "OTP Form" },
          "standard": "RFC 6238"
        },
        {
          "id": "hotp", "category": "POSSESSION", "loa": 2,
          "phishing_resistant": false, "nist_status": "PERMITTED",
          "keycloak": { "native": true, "implementation": "OTP Form (counter mode)" },
          "standard": "RFC 4226"
        },
        {
          "id": "backup_codes", "category": "KNOWLEDGE", "loa": 1,
          "phishing_resistant": false, "nist_status": "PERMITTED_RECOVERY_ONLY",
          "keycloak": { "native": true, "implementation": "Recovery Codes" },
          "restriction": "Solo recuperación de cuenta. Nunca como factor habitual."
        },
        {
          "id": "security_questions", "category": "KNOWLEDGE", "loa": 0,
          "phishing_resistant": false, "nist_status": "NOT_RECOMMENDED",
          "keycloak": { "native": false, "implementation": "SPI básico", "recommended": false },
          "restriction": "NIST desaconseja. Solo recuperación muy limitada."
        },
        {
          "id": "webauthn_roaming", "category": "POSSESSION", "loa": 3,
          "phishing_resistant": true, "nist_status": "PERMITTED_AAL3",
          "keycloak": { "native": true, "version": "KC 21+", "implementation": "WebAuthn Authenticator" },
          "standard": "FIDO2/WebAuthn W3C",
          "devices": ["YubiKey 5 NFC", "Nitrokey FIDO2", "Google Titan"]
        },
        {
          "id": "passkey", "category": "POSSESSION+INHERENCE", "loa": 2,
          "phishing_resistant": true, "nist_status": "PERMITTED_AAL2",
          "nist_ref": "NIST SP 800-63B-4 Appendix B",
          "keycloak": { "native": true, "version": "KC 26.4+", "implementation": "WebAuthn Passwordless (sync)" },
          "platforms": ["iCloud Keychain", "Google Password Manager", "Windows Hello"],
          "notes": "AAL2 válido desde publicación final NIST SP 800-63B-4 (agosto 2025)"
        },
        {
          "id": "x509_smartcard", "category": "POSSESSION+KNOWLEDGE", "loa": 3,
          "phishing_resistant": true, "nist_status": "PERMITTED_AAL3",
          "keycloak": { "native": true, "implementation": "X.509 Certificate + BOS-SmartCardPIN-SPI" }
        },
        {
          "id": "magic_link", "category": "POSSESSION", "loa": 1,
          "phishing_resistant": false, "nist_status": "PERMITTED",
          "keycloak": { "native": true, "implementation": "Magic Link Authenticator" },
          "ttl_seconds": 300, "single_use": true
        },
        {
          "id": "email_otp", "category": "POSSESSION", "loa": 1,
          "phishing_resistant": false, "nist_status": "RESTRICTED_AS_SOLE_SECOND_FACTOR",
          "keycloak": { "native": true, "version": "KC 26+", "implementation": "Email OTP" },
          "restriction": "PROHIBIDO como único segundo factor con contraseña como primero."
        },
        {
          "id": "sms_otp", "category": "POSSESSION", "loa": 1,
          "phishing_resistant": false, "nist_status": "RESTRICTED",
          "nist_ref": "NIST SP 800-63B-4 §5.2.10",
          "keycloak": {
            "native": false,
            "implementation": "BOS-SMS-SPI",
            "external_providers": ["Twilio", "AWS SNS", "Vonage"]
          },
          "restriction": "Restricted Authenticator. Requiere análisis de riesgo documentado + notificación al usuario."
        },
        {
          "id": "push_notification", "category": "POSSESSION", "loa": 2,
          "phishing_resistant": false, "nist_status": "PERMITTED",
          "keycloak": {
            "native": false,
            "implementation": "BOS-Push-SPI",
            "external_providers": ["Firebase Cloud Messaging", "APNs"]
          },
          "risk": "MFA fatigue — implementar número de transacción visible"
        },
        {
          "id": "webauthn_platform", "category": "POSSESSION+INHERENCE", "loa": 2,
          "phishing_resistant": true, "nist_status": "PERMITTED_AAL2",
          "keycloak": { "native": true, "version": "KC 21+", "implementation": "WebAuthn Passwordless" },
          "devices": ["Face ID", "Touch ID", "Windows Hello", "Android biometric"],
          "note": "KC nunca recibe datos biométricos — solo la firma criptográfica del enclave"
        },
        {
          "id": "kerberos_spnego", "category": "POSSESSION", "loa": 2,
          "phishing_resistant": true, "nist_status": "PERMITTED",
          "keycloak": { "native": true, "implementation": "Kerberos authenticator + keytab" },
          "use_case": "Entornos Active Directory / on-premise"
        },
        {
          "id": "federated_identity", "category": "CONTEXT", "loa": "variable",
          "phishing_resistant": "variable",
          "nist_status": "PERMITTED",
          "keycloak": { "native": true, "implementation": "Identity Brokering OIDC/SAML" },
          "notes": "LoA hereda del IdP externo. Verificar FAL del IdP antes de confiar."
        }
      ]
    },

    "cryptographic_catalog": {
      "_note": "Algoritmos soportados por el SBOS. La selección activa se configura en bauth.toml.",
      "post_quantum": {
        "key_exchange": ["CRYSTALS-Kyber-1024"],
        "fallback_key_exchange": ["NTRU-HPS-4096-821"],
        "digital_signatures": ["CRYSTALS-Dilithium", "SPHINCS+", "FALCON"],
        "hybrid_mode": {
          "enabled": true,
          "classical_fallback": "ECDH-P521",
          "combination_method": "XOR"
        },
        "status": "NIST_PQC_FINAL_STANDARDS_2024",
        "jvm_support": "Via liboqs-java (Open Quantum Safe)"
      },
      "classical": {
        "symmetric": ["AES-256-GCM", "ChaCha20-Poly1305"],
        "asymmetric": ["RSA-4096", "ECDSA-P384", "EdDSA-Ed25519"],
        "hash": ["SHA-384", "SHA-512", "BLAKE3"],
        "key_derivation": ["Argon2id", "PBKDF2-SHA256", "HKDF"]
      },
      "tls": {
        "allowed_versions": ["1.3"],
        "forbidden_versions": ["1.0", "1.1", "1.2"],
        "preferred_cipher_suites": [
          "TLS_AES_256_GCM_SHA384",
          "TLS_CHACHA20_POLY1305_SHA256"
        ]
      }
    },

    "global_minimums": {
      "_note": "Pisos absolutos del realm. Ningún RolTemplate puede ser más permisivo.",
      "_standard_ref": "NIST SP 800-63B-4 §5.1, §5.1.1",
      "min_loa_realm": 1,
      "max_session_ttl_seconds": 86400,
      "password_min_length_sole_authenticator": 15,
      "password_min_length_with_mfa": 8,
      "password_rotation": "on_compromise_only",
      "password_complexity_rules": "NONE",
      "password_complexity_note": "NIST SP 800-63B-4 §5.1.1 elimina reglas arbitrarias. Usar screening de contraseñas comprometidas.",
      "compromised_password_screening": "required",
      "mfa_required_for_loa2_and_above": true,
      "prohibited_as_sole_second_factor": ["email_otp"],
      "restricted_authenticators": ["sms_otp"],
      "restricted_authenticator_policy": "Requiere análisis de riesgo documentado per NIST SP 800-63B-4 §5.2.10"
    }
  }
}
```

---

## 10. Policies_Authentication_Framework.json — Versión Consolidada v3.0

```json
{
  "PoliciesAuthenticationFramework": {
    "_purpose": "Políticas mínimas que aplican a TODOS los roles del realm. Los RolTemplates pueden ser más restrictivos pero nunca más permisivos. La normativa fiscal regional NO pertenece aquí — pertenece a deploy.yml.",
    "_version": "3.0.0",
    "_standard_refs": ["NIST SP 800-63B-4", "ISO/IEC 27001:2022 A.5.15", "PCI-DSS v4.0 Req.8"],

    "global_auth_policy": {
      "min_loa": 1,
      "max_concurrent_sessions": 3,
      "session_ttl_max_seconds": 28800,
      "mfa_required_for_financial_operations": true,
      "mfa_grace_period_seconds": 0,
      "step_up_required_for_critical_operations": true,
      "quantum_hybrid_mode": true
    },

    "realm_session_policy": {
      "force_logout_on_idle_seconds": 900,
      "concurrent_sessions_default": false,
      "token_refresh_strategy": "sliding",
      "access_token_ttl_minutes": 60,
      "refresh_token_ttl_days": 7,
      "refresh_token_rotation": "single_use"
    },

    "compliance_floor": {
      "_note": "Requisitos de cumplimiento que afectan directamente la autenticación. La normativa fiscal regional NO pertenece aquí.",
      "mfa_required_for_loa_above": 1,
      "prohibited_sole_second_factor": ["email_otp"],
      "restricted_authenticators": {
        "sms_otp": {
          "status": "RESTRICTED",
          "requirement": "Análisis de riesgo documentado + notificación al usuario per NIST SP 800-63B-4 §5.2.10",
          "use_allowed": true
        }
      },
      "password_policy": {
        "min_length_sole_authenticator": 15,
        "min_length_with_mfa": 8,
        "rotation_policy": "on_compromise_only",
        "complexity_rules": "NONE",
        "compromised_password_screening": "required",
        "compromised_password_source": "configurable_per_deployment"
      },
      "pci_dss_authentication": {
        "applicable_to_roles_with_cardholder_data_access": true,
        "mfa_required": true,
        "min_password_length": 12,
        "max_session_duration_minutes": 15,
        "pci_dss_ref": "PCI-DSS v4.0 Req.8.3, 8.4"
      },
      "gdpr_biometric": {
        "explicit_consent_required": true,
        "gdpr_ref": "RGPD Art.9 §2(a)",
        "raw_biometric_storage_prohibited": true,
        "only_derived_hashes_permitted": true,
        "hash_algorithm": "PBKDF2-SHA256",
        "min_iterations": 310000
      }
    }
  }
}
```

---

## 11. deploy.yml — Configuración Regional (Nuevo Artefacto)

```yaml
# deploy.yml — Configuración de despliegue regional del SBOS
# ═══════════════════════════════════════════════════════════════
# ESTE ARCHIVO es la ÚNICA fuente de verdad para la jurisdicción.
# bAuth NO lee este archivo — solo lo leen los módulos regionales
# (módulo fiscal de Tryton, conectores fiscales, bkernel retention, etc.)
# ═══════════════════════════════════════════════════════════════

tenant:
  id:             "empresa-acme"
  realm_name:     "empresa-acme"
  display_name:   "Empresa ACME S.R.L."

  # ── JURISDICCIÓN REGIONAL ──────────────────────────────────────────
  # Afecta: módulo fiscal Tryton, conector SIAT/AFIP/SAT, retención de
  # logs operativos, moneda base, IVA, nómina, plan contable.
  # NO afecta: bAuth, RolTemplates, UserTemplates, SAM-128.
  jurisdiction: "BO"

  regional_config:
    country_code:    "BO"
    currency:        "BOB"
    timezone:        "America/La_Paz"
    locale:          "es-BO"
    fiscal_year:     "CALENDAR"
    tax_system:      "SIAT_BO"
    payroll_system:  "PAYROLL_BO"
    accounting_plan: "PCGE_BO"

  regional_modules:
    fiscal_connector: "SIAT"
    applicable_laws:
      - id: "LEY_843"
        name: "Ley del Régimen Tributario Boliviano"
        log_retention_years: 10
      - id: "LEY_PROTECCION_DATOS_BO"
        name: "Ley de Protección de Datos Bolivia"
        log_retention_years: 5
    vat_rate:       13
    vat_it_rate:    3

  # Retención de datos de negocio — responsabilidad de bkernel
  # NO es responsabilidad de bAuth (bAuth gestiona solo logs de autenticación)
  data_retention:
    audit_logs_years:          10
    financial_records_years:   10
    employee_records_years:     5
    operational_logs_years:     2

  # Excepciones operacionales al regional_config base
  jurisdiction_overrides:
    currency: "USD"  # Si la empresa opera internamente en dólares

# ── CONFIGURACIÓN DE INFRAESTRUCTURA AUTH ────────────────────────────
# Esta sección alimenta bauth.toml, NO el RolTemplate ni el SAM-128.
auth_infrastructure:
  keycloak_realm: "empresa-acme"
  keycloak_url:   "https://auth.sbos.internal"
  smtp_host:      "smtp.sbos.internal"
  smtp_port:      587
  smtp_from:      "noreply@empresa-acme.com"
```

**Configuraciones para otras jurisdicciones:**

```yaml
# Argentina
jurisdiction: "AR"
regional_config:
  country_code: "AR"
  currency: "ARS"
  timezone: "America/Argentina/Buenos_Aires"
  tax_system: "AFIP"
  vat_rate: 21
  accounting_plan: "PCGA_AR"

# México
jurisdiction: "MX"
regional_config:
  country_code: "MX"
  currency: "MXN"
  timezone: "America/Mexico_City"
  tax_system: "SAT"
  vat_rate: 16
  accounting_plan: "NIF_MX"
```

---

## 12. bauth.toml — Secciones Migradas

```toml
# bauth.toml — Configuración de infraestructura del daemon bAuth
# ═══════════════════════════════════════════════════════════════
# NO contiene normativa regional — esa es responsabilidad de deploy.yml.
# NO contiene políticas de rol — esas son responsabilidad del RolTemplate.
# ═══════════════════════════════════════════════════════════════

[metadata]
version     = "1.0.0"
environment = "production"
log_level   = "info"
log_format  = "json"

[keycloak]
url                      = "https://auth.sbos.internal"
realm                    = "master"
client_id                = "bauth-admin"
client_secret_source     = "vault"
vault_path               = "secret/bauth/keycloak"
vault_field              = "client_secret"
token_refresh_interval_s = 240
admin_api_timeout_ms     = 5000
admin_api_retry_count    = 3
keycloak_version         = "26.0.0"  # Mínimo requerido para Email OTP + Passkeys

[tryton]
url       = "http://tryton.sbos.internal:8000"
db        = "tryton_db"
user      = "admin"
pool_size = 10
timeout_ms = 3000

[postgres]
dsn          = "postgres://bauth:${BAUTH_PG_PASSWORD}@localhost:5432/bauth_db?sslmode=require"
max_conns    = 20
min_conns    = 5

[redis]
enabled           = true
addr              = "localhost:6379"
cache_ttl_seconds = 30
cache_max_entries = 10000

[socket]
path               = "/run/bos/bauth.sock"
permissions        = "0660"
owner_group        = "bos"
request_timeout_ms = 1000
max_connections    = 100

# ── SEGURIDAD ──────────────────────────────────────────────────────────

[security.post_quantum]
primary_algorithm    = "CRYSTALS-Kyber-1024"
fallback_algorithm   = "NTRU-HPS-4096-821"
hybrid_mode_enabled  = true
classical_fallback   = "ECDH-P521"
signature_algorithm  = "CRYSTALS-Dilithium"
signature_version    = "5"
jvm_pqc_library      = "liboqs-java"  # Requerido para operación PQC

[security.password]
# NIST SP 800-63B-4 (agosto 2025) — versión vigente
min_length_sole_authenticator = 15
min_length_with_mfa           = 8
rotation_policy               = "on_compromise_only"
complexity_rules              = "NONE"
# No se imponen reglas de complejidad arbitrarias — solo screening
compromised_password_check    = true
compromised_password_source   = "haveibeenpwned_api"
# Alternativas: archivo local, servicio interno anonimizado

# ── KEYCLOAK SPIs ──────────────────────────────────────────────────────

[keycloak.spis]
spi_jar_path      = "/opt/bos/lib/bauth-spi-1.0.0.jar"
spi_jar_sha256    = "/opt/bos/lib/bauth-spi-1.0.0.jar.sha256"
auto_deploy       = true
providers = [
  "bos-guard-authenticator",
  "bos-geocontext-authenticator",
  "bos-financial-period-authenticator",
  "bos-role-validity-authenticator",
  "bos-smartcard-pin-authenticator"
]

# ── IA Y COMPORTAMIENTO ────────────────────────────────────────────────

[ai_security.anomaly_detection]
model_type           = "ensemble"
components           = ["random_forest", "neural_network", "gradient_boosting"]
confidence_threshold = 0.90
false_positive_rate  = 0.01
retraining_frequency = "continuous"
min_samples          = 10000

[ai_security.behavioral]
keyboard_dynamics_enabled = true
mouse_dynamics_enabled    = true
min_samples               = 1000
update_frequency          = "continuous"
confidence_threshold_step_up = 0.75
# Si el score cae por debajo de este umbral → step-up challenge (RFC 9470)

# ── BIOMÉTRICO ────────────────────────────────────────────────────────

[biometric]
hash_algorithm        = "PBKDF2-SHA256"
iterations            = 310000
fmr_threshold_loa2    = "1:10000"
fmr_threshold_loa3    = "1:100000"
liveness_required     = true
liveness_method       = "passive"
# raw biometric NUNCA se almacena — solo el hash
qr_ttl_seconds        = 30
qr_hmac_algorithm     = "HMAC-SHA256"
qr_key_rotation_days  = 90

# ── AUDITORÍA ─────────────────────────────────────────────────────────

[audit]
# Solo logs de AUTENTICACIÓN — los logs de negocio son responsabilidad de bkernel
access_log_retention_days     = 365
security_event_retention_days = 1095  # 3 años
critical_event_retention_days = 2555  # 7 años

# ── ALERTAS ───────────────────────────────────────────────────────────

[alerts]
mechanism    = "syslog"
syslog_addr  = "wazuh-manager.sbos.internal:514"
syslog_proto = "tcp"
log_file     = "/var/log/bos/bauth-alerts.log"

# ── RECONCILE LOOP ────────────────────────────────────────────────────

[reconcile]
global_interval_seconds = 60
min_interval_seconds    = 30
drift_auto_correct      = true
drift_alert_severity    = "HIGH"
```

---

## 13. Correcciones al RolTemplate y SAM-128

### 13.1 Nuevo Bloque network_domain en RolTemplate v5.1

```json
"network_domain": {
  "ieee8021x": {
    "required": true,
    "eap_method": "EAP-TLS",
    "certificate_required": true
  },
  "allowed_vlans": ["VLAN-VENTAS", "VLAN-INTERNET-FILTERED"],
  "denied_vlans": ["VLAN-SERVIDORES", "VLAN-DIRECCION"],
  "dynamic_vlan_assignment": {
    "enabled": true,
    "attribute": "Tunnel-Private-Group-ID",
    "default_vlan": "VLAN-QUARANTINE"
  },
  "blocked_protocols": ["P2P", "TOR", "SSH_REVERSE", "TELNET"],
  "bandwidth_profile": "HIGH_PERFORMANCE",
  "bandwidth_limits": {
    "download_mbps": 100,
    "upload_mbps": 50
  }
}
```

### 13.2 Nuevo Bloque application_domain en RolTemplate v5.1

```json
"application_domain": {
  "zone_mappings": [
    {
      "zone_id": "zone_logical/ventas",
      "verbs": ["READ", "WRITE", "APPROVE"],
      "required_loa": 2,
      "applications": [
        {"app": "tryton",  "scope": "sale.sale:read,write", "client_id": "tryton-sbos"},
        {"app": "saleor",  "scope": "orders:read,write",    "client_id": "saleor-storefront"},
        {"app": "espocrm", "scope": "accounts:read,write",  "client_id": "espocrm-api"}
      ]
    }
  ],
  "access_control_model": "ABAC",
  "evaluation_mode": "deny_override"
}
```

### 13.3 Nuevo Bloque biometric_domain en RolTemplate v5.1 (separado de physical_access)

```json
"biometric_domain": {
  "policy": {
    "mode": "hybrid",
    "liveness_required": true,
    "liveness_method": "passive",
    "fallback_method": "qr_dynamic",
    "max_failed_attempts": 3,
    "hash_algorithm": "PBKDF2-SHA256",
    "iterations": 310000,
    "fmr_threshold": "1:10000",
    "consent_required": true,
    "consent_mechanism": "electronic_signature",
    "gdpr_note": "Categoría especial RGPD Art.9. Consentimiento explícito obligatorio."
  }
}
```

### 13.4 SAM-128 Q4 Corregido — Sin Bits Jurisdiccionales

```
Q4: SOBERANÍA Y AUDITORÍA (bits 96–127) — VERSIÓN CORREGIDA v3.0

Zona 1 — Nivel de Autoridad (bits 96–103):
  Bits 96–99:  GOV_LOA_LEVEL    — Level of Assurance de la sesión (1–4)
  Bits 100–103: GOV_ROLE_TIER   — jerarquía del rol (Operativo/Supervisor/Gerencia/Dirección)

Zona 2 — Auditoría Forzada (bits 104–111):
  Bit 104: GOV_AUDIT_ALL        — TODAS las acciones auditadas
  Bit 105: GOV_AUDIT_FINANCE    — acciones financieras auditadas
  Bit 106: GOV_AUDIT_ACCESS     — accesos físicos auditados
  Bit 107: GOV_AUDIT_CONFIG     — cambios de configuración auditados
  Bit 108: GOV_IMMUTABLE_LOG    — logs inmutables para este rol
  Bit 109: GOV_ALERT_HIGH       — acciones generan alertas HIGH en Wazuh
  Bit 110: GOV_AUDIT_PCI        — rol sujeto a auditoría PCI-DSS
  Bit 111: GOV_AUDIT_GDPR_BIO   — rol con datos biométricos (RGPD Art.9)

Zona 3 — Identidad Especial (bits 112–127):
  Bit 112: GOV_IS_SUPERUSER     — Superusuario (Q1-Q3 en cero por defecto)
  Bit 113: GOV_CONTEXT_ACTIVE   — Asunción de contexto activa
  Bit 114: GOV_IS_MACHINE       — Service account (no humano)
  Bit 115: GOV_EMERGENCY        — Acceso de emergencia activo (rompe SoD)
  Bit 116: GOV_DELEGATE_ACTIVE  — Delegación temporal activa
  Bit 117: GOV_BIOMETRIC_REQ    — Rol requiere biométrico obligatorio
  Bit 118: GOV_STEP_UP_PENDING  — Step-up de LoA pendiente en sesión
  Bits 119–127: GOV_CUSTOM      — Definibles por admin del tenant

ELIMINADOS vs plan v1.0:
  ❌ GOV_NORMATIVE_BO (bit 110 original) → Pertenece a deploy.yml
  ❌ GOV_NORMATIVE_PCI (bit 111 original) → Reemplazado por GOV_AUDIT_PCI
  ❌ GOV_NORMATIVE_AR → Nunca existió — eliminado antes de implementar
  ❌ GOV_NORMATIVE_MX → Nunca existió — eliminado antes de implementar
```

### 13.5 compliance_audit en RolTemplate — Versión Corregida

```json
"compliance_audit": {
  "review_frequency": "QUARTERLY",
  "reviewers": ["DIRECTOR_VENTAS", "COMPLIANCE_OFFICER", "INTERNAL_AUDIT"],

  "auth_compliance": {
    "_note": "SOLO normativa que afecta directamente la autenticación de este rol. La normativa fiscal está en deploy.yml.",
    "pci_dss": {
      "applicable": true,
      "reason": "Este rol accede a datos de tarjetahabiente",
      "requirements_enforced": ["Req.8.3 MFA", "Req.8.4 Password Policy"],
      "session_max_minutes": 15
    },
    "gdpr_biometric": {
      "applicable": true,
      "reason": "Este rol usa autenticación biométrica",
      "consent_documented": true,
      "gdpr_ref": "Art.9 §2(a)"
    }
  }
}
```

---

## 14. Decision Log Consolidado

| # | Pregunta | Decisión | Origen | Estado |
|---|---|---|---|---|
| A1 | end_date null en FIXED | Permitido; FIXED sin end_date = error | v1.0 | ✅ Cerrado |
| A2 | limit_tier rango | Estricto 0–5 (4 bits SAM-128) | v1.0 | ✅ Cerrado |
| A3 | sod_cannot_also formato | Doble formato: model.button o zone:VERB | v1.0 | ✅ Cerrado |
| A4 | approval_workflow coherencia | Validación runtime (422 temprano) | v1.0 | ✅ Cerrado |
| A5 | metadata.region ubicación | Solo en RolTemplate, no UserTemplate | v1.0 | ✅ Cerrado |
| B1–B4 | bauth.toml estructura | Jerarquía Vault→env→file; Redis recomendado | v1.0 | ✅ Cerrado |
| C1–C3 | Protocolo Unix socket | Solo bhnexus; length-prefix JSON; singleflight | v1.0 | ✅ Cerrado |
| D1–D4 | KC Admin API y Maven | Opción B (retry Tryton); KC 26.x; deploy automático | v1.0 | ✅ Cerrado |
| E1–E4 | Schema SQL bauth_db | bauth_db exclusivo; WORM historial; ambas columnas | v1.0 | ✅ Cerrado |
| F1–F5 | Correcciones v4.0 | Renombrar VDI/ERP; FinancialMask; TTL contexto; Wazuh syslog | v1.0 | ✅ Cerrado |
| G1–G5 | Gaps coherencia | AR/MX via JWT claim; jurisdicción por tenant; HMAC por tenant; break-glass; SMTP en KC | v1.0 | ✅ Cerrado |
| H1–H8 | Dominios y zonas | network_domain en RolTemplate; zone_application_map.yaml; JSON reducidos; FAL en RolTemplate | v1.0 | ✅ Cerrado |
| **J1** | Jurisdicción en RolTemplate | **NO** — pertenece a deploy.yml únicamente | **v2.0** | ✅ **CORREGIDO** |
| **J2** | Bits GOV_NORMATIVE en SAM-128 | **NO** — SAM-128 es vector de autorización, no cumplimiento regional | **v2.0** | ✅ **CORREGIDO** |
| **J3** | Fase 4 (reorganización Q4) | **CANCELADA** — innecesaria tras J1/J2 | **v2.0** | ✅ **CERRADO** |
| **J4** | Propósito Authentication_Framework.json | Catálogo técnico de referencia de solo lectura | **v2.0** | ✅ **CERRADO** |
| **J5** | Propósito Policies_Authentication_Framework.json | Políticas mínimas del realm para todos los roles | **v2.0** | ✅ **CERRADO** |
| **J6** | Longitud mínima contraseña | 15 chars (factor único); 8 con MFA — NIST SP 800-63B-4 | **v2.0** | ✅ **CORREGIDO** |
| **J7** | Rotación periódica contraseñas | Solo ante compromiso detectado — NIST SP 800-63B-4 | **v2.0** | ✅ **CORREGIDO** |
| **J8** | SMS OTP "alto riesgo" | "Restricted Authenticator" — terminología NIST exacta | **v2.0** | ✅ **CORREGIDO** |
| **J9** | Passkeys como AAL2 | Confirmado — NIST SP 800-63B-4 Apéndice B (agosto 2025) | **v2.0** | ✅ **CONFIRMADO** |
| **J10** | Email OTP prohibido como factor único | Confirmado — NIST SP 800-63B-4 | **v2.0** | ✅ **CONFIRMADO** |
| **J11** | deploy.yml como nuevo artefacto | Nuevo — único lugar de configuración regional | **v2.0** | ✅ **NUEVO** |
| **K1** | Biometría multimodal avanzada en KC | Integración via IdP externo (FaceTec, BioID) + OIDC/SAML | **v3.0** | ✅ **NUEVO** |
| **K2** | SMS OTP implementation en KC | BOS-SMS-SPI + proveedor externo (Twilio / AWS SNS) | **v3.0** | ✅ **NUEVO** |
| **K3** | Push Notification en KC | BOS-Push-SPI + FCM/APNs + app SBOS móvil | **v3.0** | ✅ **NUEVO** |
| **K4** | Quantum-resistant en KC | liboqs-java vía JVM; KC nativo en futuro cuando JDK lo soporte | **v3.0** | ✅ **NUEVO** |
| **K5** | Keycloak como orquestador central | KC = núcleo de federación; sistemas especializados para capacidades avanzadas | **v3.0** | ✅ **NUEVO** |
| **K6** | IoT/M2M authentication strategy | KC como servidor autorización; PKI externa (Vault); plataforma IoT dedicada | **v3.0** | ✅ **NUEVO** |
| **K7** | Behavioral biometrics en sesión | SPI SkbosGuardAuthenticator emite step-up cuando score < threshold | **v3.0** | ✅ **NUEVO** |

---

## 15. Criterios de Aceptación por Fase

### Fase 0 (Pre-v0.9)

- [ ] `Authentication_Framework.json` v3.0 — exactamente 5 secciones. Cero referencias a normativa fiscal. Los 15 métodos documentados con status NIST SP 800-63B-4.
- [ ] `Policies_Authentication_Framework.json` v3.0 — exactamente 3 secciones. Cero referencias a SIAT, AFIP, SAT, LEY_843.
- [ ] `bauth.toml` contiene `password_min_length_sole_authenticator = 15` y `rotation_policy = "on_compromise_only"`.
- [ ] `bauth.toml` NO contiene `max_age_days`.
- [ ] `deploy.yml` de referencia creado con estructura correcta.
- [ ] `roltemplate_schema.json` rechaza: `regulatory_frameworks.jurisdiction_triggers`, `email_otp` como único 2do factor, `password_min_length < 15` como factor único.
- [ ] `roltemplate_schema.json` acepta: `network_domain`, `application_domain`, `federation_domain`, `biometric_domain`.
- [ ] `migrations/003_add_domains.sql` ejecuta sin errores. NO incluye columnas jurisdiccionales.
- [ ] Todos los RolTemplates v5.0 existentes pasan el nuevo JSON Schema.

### Fase 1 (v0.9 Beta)

- [ ] SBOS-ROLTEMPLATE-v5_1.md publicado sin `jurisdiction_triggers`. Con `network_domain`, `application_domain`, `biometric_domain`.
- [ ] SBOS-USERTEMPLATE-v5_1.md con `financial_limits` y `biometric_domain.enrolled_templates` (separado de `physical_credentials`).
- [ ] `zone_application_map.yaml` creado con las 6 zonas de negocio principales.
- [ ] `LogicalDomainEvaluator` básico funcional: `CanAccessZone(jwt, "zone_logical/ventas", "READ")` → `true` para RGV-001.
- [ ] `bauth-spi-1.0.0.jar` compilado y desplegado en KC staging. Los 5 SPIs registrados.
- [ ] SAM-128 Q4 corregido: Bits GOV_AUDIT_PCI (110) y GOV_AUDIT_GDPR_BIO (111) activos. Sin bits GOV_NORMATIVE.
- [ ] KC sync en bAuth propaga `allowed_vlans` → User Attribute `bos_vlan_assignment` en KC.
- [ ] Test KC: usuario con RGV-001 no puede autenticarse fuera del horario configurado (SPI temporal activo).
- [ ] Test KC: usuario con RGV-001 no puede autenticarse desde red no autorizada (SPI geo activo).

### Fase 2 (v0.9 GA)

- [ ] JWT incluye claim `bos_federation_level` con valor FAL del RolTemplate.
- [ ] `deploy.yml` de producción para tenant boliviano activa módulos SIAT en Tryton. bAuth NO recibe configuración de jurisdicción.
- [ ] Test negativo: `bos_sam128` de cualquier usuario normal NO contiene bits GOV_NORMATIVE.
- [ ] `organizational_domain` agregado al RolTemplate v5.1. Campos legacy marcados deprecated.
- [ ] Passkeys funcionales en realm de prueba (requiere KC 26.4+ verificado).
- [ ] Conector SIAT activo para tenant BO — activado por deploy.yml, no por bAuth.

### Fase 3 (v1.0)

- [ ] 9 dominios de autenticación evaluables via `/run/bos/bauth.sock` y `/api/v1/authorize/*`.
- [ ] 6 aplicaciones integradas: Saleor, EspoCRM, Zammad, OrangeHRM, Superset, Paperless-ngx.
- [ ] JWT emite exclusivamente: `bos_physical_mask`, `bos_logical_mask`, `bos_financial_mask`.
- [ ] `trytond-auth-keycloak` actualizado para leer `bos_logical_mask`.
- [ ] `banexus` actualizado para leer `bos_physical_mask`.
- [ ] `physical_credentials.biometric_templates` eliminado (migración ejecutada).
- [ ] Prueba NIST: contraseña de 14 chars rechazada como factor único. 15 chars aceptada.
- [ ] Prueba NIST: contraseña comprometida (HaveIBeenPwned) rechazada.
- [ ] SMS OTP configurado con BOS-SMS-SPI + documentación de análisis de riesgo.
- [ ] Test de integración biométrica avanzada: FaceTec fedado via OIDC → KC emite JWT con `acr: "loa3"`.

---

## 16. Estimación de Esfuerzo

| Fase | Duración | Recursos | Entregables clave |
|---|---|---|---|
| **Fase 0** — Refactorización + deploy.yml + JSON v3.0 | 3-4 días | 1 arquitecto + 1 dev | JSON v3.0, deploy.yml, bauth.toml NIST-conforme, Schema v3 |
| **Fase 1** — Dominios + SPIs KC + 15 métodos | 1 semana | 1 Go dev + 1 Java dev | RolTemplate v5.1, UserTemplate v5.1, zone_map, SPIs desplegados |
| **Fase 2** — Federación + Org Domain + deploy.yml prod | 1 semana | 1 Go dev | federation_domain, organizational_domain, validación prod |
| **Fase 3** — Evaluadores + 6 integraciones + JWT migrado | 3-4 semanas | 2 Go devs + integraciones | 9 dominios completos, 6 apps, JWT migrado |
| ~~Fase 4~~ | ~~CANCELADA~~ | — | Ahorro de 2 semanas |
| **TOTAL** | **~6-7 semanas** | | **9 dominios, 15 métodos mapeados, 6 integraciones, JSON corregidos** |

---

## 17. Apéndice A: Mapa de Responsabilidades

| Decisión / Configuración | Sistema Responsable | Archivo |
|---|---|---|
| ¿Qué país/región es esta instalación? | Despliegue regional | `deploy.yml` |
| ¿Qué normativa fiscal aplica (SIAT/AFIP/SAT)? | Tryton (módulo fiscal) | `deploy.yml` → módulo fiscal |
| ¿Cuántos años se retienen documentos contables? | bkernel + archivado | `deploy.yml → data_retention` |
| ¿Cuántos años se retienen logs de autenticación? | bAuth | `bauth.toml [audit.retention]` |
| ¿Qué métodos de autenticación existen? | bAuth (catálogo) | `Authentication_Framework.json` |
| ¿Qué métodos son mínimos para todo el realm? | bAuth (políticas globales) | `Policies_Authentication_Framework.json` |
| ¿Qué métodos requiere un rol específico? | bAuth (contrato de rol) | `RolTemplate.logical_access.requiredMethods` |
| ¿Qué puede hacer un usuario en el sistema? | bAuth (SAM-128) | `RolTemplate` → bitmask calculado |
| ¿Cómo se conecta bAuth con Keycloak? | bAuth (infraestructura) | `bauth.toml [keycloak]` |
| ¿PCI-DSS aplica a este rol? | bAuth (contrato de rol) | `RolTemplate.compliance_audit.auth_compliance.pci_dss` |
| ¿Este usuario tiene datos biométricos? | bAuth (identidad) | `UserTemplate.biometric_domain.enrolled_templates` |
| ¿Keycloak soporta SMS OTP? | KC + SPI externo | `BOS-SMS-SPI` + Twilio/AWS |
| ¿Keycloak soporta biometría avanzada? | IdP externo federado | FaceTec/BioID vía OIDC/SAML |
| ¿Keycloak soporta quantum-resistant? | JVM + liboqs-java | `bauth.toml [security.post_quantum]` |
| ¿Keycloak soporta IoT/M2M? | KC como Auth Server | PKI externa + `client_credentials` flow |
| ¿Dónde va la jurisdicción Bolivia/Argentina/México? | `deploy.yml` | **NUNCA en RolTemplate ni SAM-128** |

---

## 18. Apéndice B: Tabla de Estándares

| Área | Estándar | Versión | Aplicación |
|---|---|---|---|
| Autenticación / LoA | NIST SP 800-63B-4 | **Agosto 2025** (final) | 15 chars contraseña, sin rotación periódica, passkeys AAL2 |
| Federación / FAL | NIST SP 800-63C-4 | **Agosto 2025** (final) | federation_domain, FAL 1–3 |
| H-RBAC | ANSI/INCITS 359-2004 | Vigente | Herencia AND NOT, Conflict Matrix |
| Gestión de Identidad | ISO/IEC 24760-1 | 2019 | Ciclo de vida UserTemplate |
| Control de Acceso | ISO/IEC 27001:2022 A.5.3/A.5.15 | 2022 | SoD, RBAC, audit |
| WebAuthn / FIDO2 | FIDO2/WebAuthn W3C | 2023 | Todos los métodos WebAuthn |
| Biometría | ISO/IEC 30107-3 | 2023 | Liveness detection, FMR |
| Protección datos biométricos | RGPD Art.9 | Vigente | Solo hashes, consentimiento |
| Control Acceso Granular | OASIS XACML 3.0 | 2013 | LogicalDomainEvaluator, PAP/PIP/PDP/PEP |
| Red corporativa | IEEE 802.1X-2020 | 2020 | network_domain, VLAN assignment |
| Step-Up Auth | RFC 9470 | 2023 | step_up_rules en RolTemplate |
| Token Binding | RFC 9449 (DPoP) | 2023 | federation_domain.token_binding |
| Post-Quantum Crypto | NIST PQC Standards | 2024 (final) | CRYSTALS-Kyber-1024, Dilithium |
| Contraseñas seguras | NIST SP 800-63B-4 §5.1.1 | **Agosto 2025** | 15 chars solo, no rotación |
| Restricted Authenticators | NIST SP 800-63B-4 §5.2.10 | **Agosto 2025** | SMS OTP requiere análisis de riesgo |
| PCI-DSS Autenticación | PCI-DSS v4.0 Req.8 | 2022 | compliance_floor, pci_dss en RolTemplate |
| SoD | ISACA COBIT 2019, NIST AC-5 | Vigente | Conflict Matrix |
| **Jurisdicción Bolivia** | **Ley 843 Bolivia** | Vigente | **deploy.yml → módulo fiscal Tryton** |
| **Jurisdicción Argentina** | **CComercial AR, Ley 25.506** | Vigente | **deploy.yml → módulo fiscal Tryton** |
| **Jurisdicción México** | **CFF México, LFPDPPP** | Vigente | **deploy.yml → módulo fiscal Tryton** |

---

> **⚠️ REQUIERE APROBACIÓN ARB**
>
> Las decisiones J1–J11 y K1–K7 representan cambios arquitectónicos que requieren ratificación formal del Architecture Review Board. Las decisiones jurisdiccionales (J1–J3) son particularmente urgentes ya que corrigen una violación del principio de responsabilidad única presente en el plan v1.0.
>
> La cancelación de Fase 4 y la clarificación de la integración KC con sistemas externos (K1–K7) reducen el esfuerzo total en 2 semanas y eliminan ambigüedades de implementación.

---

*SKULL · SBOS · SBOS-PLAN-ACTUALIZACION-CONSOLIDADO-v3_0 · Abril 2026*
*Consolida: SBOS-PLAN-ACTUALIZACION-v1_0 + SBOS-PLAN-ACTUALIZACION-VALIDADO-v2_0*
*Complementa: FrameworkAuthentication_Configuraciones_Metodos_de_Autenticacion_completo + Investigación KC integración*
*Todos los pendientes J1–J11 cerrados. Decisiones K1–K7 nuevas. Modelo de métodos completo.*
*Estándares: NIST SP 800-63B-4 (ago 2025) · NIST SP 800-63C-4 · IEEE 802.1X-2020 · OASIS XACML 3.0 · ISO/IEC 27001:2022 · ANSI/INCITS 359-2004 · RGPD Art.9 · RFC 9470 · RFC 9449 DPoP · FIDO2/WebAuthn W3C · ISO/IEC 30107-3 · PCI-DSS v4.0*
