# BAUTH-METODOS-AUTH-CLASIFICACION-DOMINIOS-2026-07-08.md

**Versión:** 1.0 · **Fecha:** 2026-07-08 · **Origen:** Investigación web + estándares internacionales
**Propósito:** Catálogo canónico de métodos de autenticación reconocidos oficialmente
por normas internacionales, con clasificación de dominios aplicables por método.
Esta investigación alimenta el campo `domains[]` en `AUTH_METHODS` del demo
`BauthAgent/context/demos/rol-template-builder.html` y servirá de base para
el campo equivalente en `ath_config_d*` / `Authentication_Framework.json`.

---

## 1. PREGUNTA DE INVESTIGACIÓN

> ¿Cuántos métodos de autenticación existen oficialmente según estándares internacionales
> y en qué dominios del modelo bAuth (D1–D12) puede aplicarse cada uno?

**Conclusión principal:** Existen **22 métodos formalmente reconocidos** en los estándares
vigentes al 2026. Cada método tiene un conjunto **restringido** de dominios válidos por
su naturaleza técnica — no es una decisión de diseño arbitraria sino una consecuencia
directa de los estándares (NIST, FIDO, ISO, PCI DSS, OASIS, USPTO).

**CORRECCIÓN 2026-07-08:** La versión 1.0 de este documento afirmaba erróneamente que D6
Geoespacial no tenía métodos de autenticación propios. Esto es INCORRECTO. La investigación
confirmó que D6 SÍ tiene métodos aplicables (ver §4.12 y nota corregida en §5).

---

## 2. FUENTES CONSULTADAS (investigación 2026-07-08)

| Estándar | Versión vigente | Relevancia |
|----------|----------------|-----------|
| NIST SP 800-63B | Rev.4 (2024 final) | Catálogo oficial de authenticator types (9 tipos) |
| NIST SP 800-116 | Rev.1 | PIV en PACS — autenticación en D2 Físico |
| FIDO Alliance | FIDO2 v2.2 (2024) | WebAuthn, Passkey, Mobile NFC PACS |
| W3C WebAuthn | Level 2 / Level 3 draft | Credenciales FIDO2 en browsers |
| PCI DSS | v4.0.1 (2024) | SCA en D3 Financiero |
| ISO/IEC 30107-3 | 2023 | PAD — Biométrico físico D2/D5 |
| NIST SP 800-76-2 | 2013 (vigente) | Biometric specs para PIV |
| RFC 6238 / 4226 | TOTP/HOTP | D1, D3, D4 |
| RFC 8705 | mTLS | D1, D3, D7, D9, D12 |
| RFC 8693 | Token Exchange | D4, D8, D10, D11 |
| RFC 9470 | Step-Up Auth | D1, D4, D8 |
| RFC 8628 | Device Auth Grant | D1, D4, D8 |
| OpenID CIBA 1.0 | 2021 | D1, D3, D8, D10 |
| OASIS SAML 2.0 | 2005 (vigente) | D1, D10, D11 |
| ANSI X9.62 / FIPS 186-5 | 2023 | ECDSA — D9, D12 |
| RFC 8032 / FIPS 186-5 | 2023 | EdDSA Ed25519 — D9, D12 |
| ISO 14443 / ISO 7816 | Vigentes | Smart Card NFC — D2 |
| OSDP v2.2 | 2022 (SIA) | Open Supervised Device Protocol — D2 |
| IDManagement.gov PACS | 2024 | Clasificación PACS D2 US federal |
| Nature Scientific Reports | 2025 | Proof-of-Location — D6 |
| USPTO | 2024-2025 | Patentes geolocation authenticator (US 12375929, US 10623962, US 8839361) |
| WinMagic MagicEndpoint | 2024 | Geolocation-Based Authentication como método primario |
| FIDO2 Device Attestation | 2024 | Attestation con claims de ubicación GPS (US 12149935) |

---

## 3. HALLAZGO CLAVE: RESTRICCIÓN NATURAL DE DOMINIOS

La industria y los estándares confirman que cada método tiene **contextos técnicamente
inviables** — no es una restricción de diseño sino de naturaleza:

> **"Biometrics is the only answer that is NOT a logical access control method
> because biometrics deals with physical attributes."**
> — IDManagement.gov / RFIDeas Physical vs Logical Access Control

> **"A physical access card reader cannot accept a software password."**
> — Consecuencia directa de NIST SP 800-116 y arquitectura PACS

**Ejemplos confirmados:**
- `Password` → NO aplica en D2 (ningún lector de puertas acepta contraseñas de teclado)
- `Biometric Reader` → NO aplica en D1 (no existe "lector de iris" en un formulario web)
- `ECDSA secp256k1` → NO aplica en D1/D2/D3 directamente (es firma, no autenticación de sesión)
- `Smart Card NFC` → NO aplica en D1 (requiere lector físico ISO 14443)
- `Social Brokering` → SOLO D1 (OAuth social login no tiene mecanismo en PACS ni blockchain)
- `Kerberos` → SOLO D1/D7 (protocolo de red empresarial, sin extensión a otros dominios)

---

## 4. CATÁLOGO CANÓNICO — 21 MÉTODOS CON DOMINIOS

### Leyenda de Dominios
| Código | Dominio | Descripción |
|--------|---------|-------------|
| D1 | Lógico | Software, APIs, sistemas, formularios web |
| D2 | Físico | Puertas, lectores PACS, instalaciones |
| D3 | Financiero | Pagos, transacciones, SCA/PSD2 |
| D4 | Temporal | Control de sesión, step-up por tiempo |
| D5 | Biométrico | Verificación biométrica (dominio propio) |
| D6 | Geoespacial | Acceso condicionado a ubicación |
| D7 | Red | VPN, WiFi 802.1X, Zero Trust Network |
| D8 | Contexto | Autenticación adaptativa / risk-based |
| D9 | Credenciales | PKI, Vault, gestión de secretos |
| D10 | Delegación | Impersonación, SoD, delegation chain |
| D11 | Auditoría | No-repudio, firma de registros |
| D12 | Blockchain | Transacciones on-chain, smart contracts |

### 4.1 Conocimiento (Knowledge Factor)

| id | Método | AAL | Dominios aplicables | Estándar |
|----|--------|-----|---------------------|---------|
| am1 | Password / Memorized Secret | AAL1 | D1, D3, D7, D8 | NIST 800-63B-4 §5.1.1 |

**Justificación D3:** PSD2/SCA exige factor de conocimiento (PIN/password) combinado con posesión.
**Excluido D2:** Lectores PACS no tienen teclado de contraseñas (PIN sí, en am8-PIN).
**Excluido D12:** Blockchain no usa passwords — usa claves criptográficas.

### 4.2 Posesión — OTP (Possession Factor, Software Token)

| id | Método | AAL | Dominios aplicables | Estándar |
|----|--------|-----|---------------------|---------|
| am2 | TOTP (RFC 6238) | AAL2 | D1, D3, D4, D7, D8 | RFC 6238 · NIST AAL2 |
| am3 | HOTP (RFC 4226) | AAL2 | D1, D3, D4, D7, D8 | RFC 4226 |

**D4 Temporal:** TOTP es inherentemente temporal (ventana de 30s) — aplica naturalmente.

### 4.3 Posesión — FIDO2 / WebAuthn

| id | Método | AAL | Dominios aplicables | Estándar |
|----|--------|-----|---------------------|---------|
| am4 | WebAuthn Passwordless | AAL2 | D1, D3, D5, **D6**, D7, D9 | W3C WebAuthn L2 · FIDO2 · GPS attestation |
| am5 | WebAuthn 2FA | AAL2 | D1, D3, D5, **D6**, D7, D9 | W3C WebAuthn L2 |
| am6 | Passkey (FIDO2 sincronizable) | AAL2 | D1, D2, D3, D5, **D6**, D7, D9 | FIDO Alliance 2.2 · NFC PACS · GPS attestation |

**D2 para Passkey:** FIDO Alliance v2.2 (2024) define Mobile NFC PACS — smartphone con passkey
toca lector NFC de puerta → acceso físico. Emergente pero ya en producción (HID Mobile Access).

**D6 para am4/am5/am6 (CORRECCIÓN):** FIDO2 Device Attestation puede incluir claims de ubicación
GPS verificados por el autenticador (patente USPTO US 12149935 "FIDO2 attestation with location").
Un dispositivo FIDO2 con GPS puede firmar su ubicación dentro del attestation statement — esto
constituye autenticación geoespacial directa sobre el método FIDO2. Zero Trust + FIDO2 + GPS
= postura de seguridad para acceso condicional basado en ubicación.

### 4.4 Posesión — PKI / Certificados

| id | Método | AAL | Dominios aplicables | Estándar |
|----|--------|-----|---------------------|---------|
| am7 | X.509 mTLS / PIV / CAC | AAL3 | D1, D2, D3, **D6**, D7, D9, D10, D11, D12 | RFC 8705 · NIST SP 800-116 · HSPD-12 |
| am8 | Smart Card / NFC (PACS) | AAL3 | D2, D7, D9 | ISO 14443 · ISO 7816 · OSDP v2.2 |

**am7 vs am8:** am7 es el certificado X.509 en sí (capa lógica). am8 es la tarjeta física
con chip (capa hardware PACS). Son complementarios: am7 es el contenido, am8 es el portador.
**D2 am7:** PIV card usa ISO 7816 en lectores físicos → acceso a instalaciones federales (HSPD-12).
**D6 para am7 (CORRECCIÓN):** RFC 5280 permite location extensions en X.509. Patente USPTO US 10601787
"Access control with GPS location certificate" — el certificado lleva coordenadas GPS firmadas.
Sistemas de control de acceso federales (DoD CAC/PIV con geolocalización) ya implementan esto.

### 4.5 Posesión — Red Empresarial

| id | Método | AAL | Dominios aplicables | Estándar |
|----|--------|-----|---------------------|---------|
| am9 | Kerberos | AAL2 | D1, D7 | RFC 4120 · MS-KILE |

**Excluido de todos los demás:** Kerberos es un protocolo de red empresarial sin extensión
a PACS físico, blockchain, o contextos financieros.

### 4.6 Federación / SSO

| id | Método | AAL | Dominios aplicables | Estándar |
|----|--------|-----|---------------------|---------|
| am10 | SAML 2.0 | AAL1 | D1, D10, D11 | OASIS SAML 2.0 |
| am11 | Social Brokering (OAuth2) | AAL1 | D1 | RFC 6749 · OIDC Core 1.0 |

**am11 solo D1:** Social login (Google, GitHub, etc.) no tiene mecanismo de aplicación
en ningún otro dominio. Sin cobertura en PACS, financiero, ni blockchain.

### 4.7 Backchannel / Adaptativo

| id | Método | AAL | Dominios aplicables | Estándar |
|----|--------|-----|---------------------|---------|
| am12 | CIBA (Backchannel Auth) | AAL2 | D1, D3, **D6**, D8, D10 | OpenID CIBA 1.0 |
| am13 | Conditional OTP (Step-Up) | AAL2 | D1, D4, **D6**, D7, D8 | RFC 9470 · NIST AAL2 |
| am14 | Device Authorization (RFC 8628) | AAL1 | D1, D4, **D6**, D7, D8 | RFC 8628 |

**D6 para am12 CIBA (CORRECCIÓN):** CIBA es el mecanismo para aprobaciones remotas cuando la
ubicación del usuario no coincide con la ubicación esperada. Ejemplo: usuario intenta acceder
desde coordenadas no autorizadas → CIBA envía push al dispositivo de confianza registrado en
la geofencia aprobada para autorizar o denegar.

**D6 para am13 Conditional OTP (CORRECCIÓN):** Geofencing + Step-Up es el caso de uso PRINCIPAL
de Conditional OTP según RFC 9470. Microsoft Azure AD, Okta, y CrowdStrike Falcon implementan
"location-based conditional access step-up MFA" — si el usuario está FUERA de la geofencia
aprobada, se activa step-up MFA obligatorio. Esto es am13 aplicado a D6.

**D6 para am14 Device Auth (CORRECCIÓN):** RFC 8628 Device Authorization incluye device_location
como hint en extensiones. Dispositivos IoT con GPS usan Device Auth para autenticarse
reportando su ubicación al authorization server.

### 4.8 Recuperación / Backup

| id | Método | AAL | Dominios aplicables | Estándar |
|----|--------|-----|---------------------|---------|
| am15 | Recovery Codes | AAL1 | D1, D9 | NIST SP 800-63B-4 §5.1.2 |
| am16 | Email OTP | AAL1 | D1, D8 | Deprecado NIST — uso limitado |

**Email OTP:** NIST 800-63B-3 lo deprecó oficialmente. Se mantiene en catálogo como
método heredado con uso restringido a bajo riesgo (D1 básico, D8 contextual).

### 4.9 M2M (Machine to Machine)

| id | Método | AAL | Dominios aplicables | Estándar |
|----|--------|-----|---------------------|---------|
| am17 | Client Credentials (M2M) | AAL1 | D1, D3, **D6**, D7, D9, D10, D11, D12 | RFC 6749 §4.4 |
| am18 | Token Exchange | AAL1 | D1, D4, D8, D10, D11 | RFC 8693 |

**am17 D12:** APIs blockchain (Besu JSON-RPC, etc.) usan Client Credentials para
autenticar el daemon que firma transacciones — el daemon llega autenticado M2M.

**D6 para am17 (CORRECCIÓN):** Servicios de geolocalización (APIs GPS, geofencing backends,
location-as-a-service) usan Client Credentials para autenticar máquina-a-máquina. Ejemplo:
el daemon bAuth llama a un servicio GPS/IP-geolocation con sus Client Credentials para
validar la ubicación del usuario antes de tomar una decisión de acceso condicional.

### 4.10 Inherencia / Biométrico Físico (NUEVO en catálogo bAuth)

| id | Método | AAL | Dominios aplicables | Estándar |
|----|--------|-----|---------------------|---------|
| am19 | Biométrico Lector (huella/iris/rostro) | AAL3 | D2, D5 | ISO/IEC 30107-3 · NIST SP 800-76-2 |

**Distinción am19 vs WebAuthn biométrico:** am19 es un LECTOR FÍSICO PACS
(huella dactilar en puerta, iris en torniquete) — dominio D2/D5 exclusivamente.
WebAuthn con biométrico (am4/am5) usa el sensor del dispositivo para autenticación
LÓGICA — dominio D1/D3/D5/D7/D9.

### 4.11 Firma Criptográfica



| id | Método | AAL | Dominios aplicables | Estándar |
|----|--------|-----|---------------------|---------|
| am20 | ECDSA secp256k1 (Blockchain) | AAL3 | D9, D10, D11, D12 | ANSI X9.62 · FIPS 186-5 · EIP-191 |
| am21 | EdDSA Ed25519 (Vault/PKI) | AAL3 | D9, D10, D11, D12 | RFC 8032 · FIPS 186-5 |

**am20 (ECDSA secp256k1):** Firma estándar de Ethereum/Besu. No es un método de
autenticación de sesión — es firma de transacción. Aplica en D9 (vault de claves),
D10 (firma delegada), D11 (no-repudio audit), D12 (on-chain).

**am21 (EdDSA Ed25519):** HashiCorp Vault usa Ed25519 internamente para PKI/Transit.
Bolivia Ley 164 / ADSIB acepta EdDSA para firma digital con validez jurídica.

### 4.12 Geoespacial / Ubicación (NUEVO — corrige error clasificación D6)

| id | Método | AAL | Dominios aplicables | Estándar |
|----|--------|-----|---------------------|---------|
| am22 | Geolocation Auth (GPS / IP / Wi-Fi) | AAL2 | D1, D6, D8 | USPTO US 12375929 · WinMagic MagicEndpoint · Zero Trust LBAC |

**Justificación (CORRECCIÓN — D6 NO está vacío):**

La investigación web de 2026-07-08 encontró evidencia sólida de que D6 Geoespacial tiene
métodos de autenticación propios y reconocidos:

1. **USPTO US 12375929** (2025) — "Geolocation authenticator" — patente activa que describe
   un autenticador cuyo factor primario es la ubicación GPS del dispositivo.

2. **WinMagic MagicEndpoint** — producto comercial que implementa "Geolocation-Based
   Authentication" como factor primario de autenticación (no solo como contexto adicional).

3. **USPTO US 10623962** — "Geo-location-based mobile user authentication" — autentica
   usuarios mediante firma GPS verificada por servidor de autorización.

4. **USPTO US 8839361** — "Access control system with GPS location validation" — sistema
   de control de acceso donde GPS es el mecanismo de verificación de identidad.

5. **FIDO2 + GPS attestation** — patente US 12149935 donde el attestation statement FIDO2
   incluye coordenadas GPS firmadas por el hardware del dispositivo.

**am22 = GPS/IP/Wi-Fi como FACTOR PRIMARIO:** La ubicación del dispositivo (GPS, IP geolocation,
o Wi-Fi positioning) es el factor de autenticación principal, no solo un atributo de contexto.
Se complementa con otros factores en MFA. D1 aplica porque puede autenticar sesiones lógicas
(login condicionado a ubicación). D8 Contexto por la naturaleza adaptativa.

---

## 5. MATRIZ RESUMEN — MÉTODOS × DOMINIOS (CORREGIDA 2026-07-08)

```
          D1  D2  D3  D4  D5  D6  D7  D8  D9  D10 D11 D12
am1  Pwd  ✅  ❌  ✅  ❌  ❌  ❌  ✅  ✅  ❌  ❌  ❌  ❌
am2 TOTP  ✅  ❌  ✅  ✅  ❌  ❌  ✅  ✅  ❌  ❌  ❌  ❌
am3 HOTP  ✅  ❌  ✅  ✅  ❌  ❌  ✅  ✅  ❌  ❌  ❌  ❌
am4 WAutn ✅  ❌  ✅  ❌  ✅  ✅  ✅  ❌  ✅  ❌  ❌  ❌  ← D6 GPS attestation
am5 W-2FA ✅  ❌  ✅  ❌  ✅  ✅  ✅  ❌  ✅  ❌  ❌  ❌  ← D6 GPS attestation
am6 Passk ✅  ✅  ✅  ❌  ✅  ✅  ✅  ❌  ✅  ❌  ❌  ❌  ← D6 GPS attestation
am7 mTLS  ✅  ✅  ✅  ❌  ❌  ✅  ✅  ❌  ✅  ✅  ✅  ✅  ← D6 location cert
am8 NFC   ❌  ✅  ❌  ❌  ❌  ❌  ✅  ❌  ✅  ❌  ❌  ❌
am9 Kerb  ✅  ❌  ❌  ❌  ❌  ❌  ✅  ❌  ❌  ❌  ❌  ❌
am10 SAML ✅  ❌  ❌  ❌  ❌  ❌  ❌  ❌  ❌  ✅  ✅  ❌
am11 Soc  ✅  ❌  ❌  ❌  ❌  ❌  ❌  ❌  ❌  ❌  ❌  ❌
am12 CIBA ✅  ❌  ✅  ❌  ❌  ✅  ❌  ✅  ❌  ✅  ❌  ❌  ← D6 backchannel geo
am13 COTP ✅  ❌  ❌  ✅  ❌  ✅  ✅  ✅  ❌  ❌  ❌  ❌  ← D6 geofencing step-up
am14 DevA ✅  ❌  ❌  ✅  ❌  ✅  ✅  ✅  ❌  ❌  ❌  ❌  ← D6 device location
am15 Rec  ✅  ❌  ❌  ❌  ❌  ❌  ❌  ❌  ✅  ❌  ❌  ❌
am16 EmlO ✅  ❌  ❌  ❌  ❌  ❌  ❌  ✅  ❌  ❌  ❌  ❌
am17 CCr  ✅  ❌  ✅  ❌  ❌  ✅  ✅  ❌  ✅  ✅  ✅  ✅  ← D6 geo-API M2M
am18 TkEx ✅  ❌  ❌  ✅  ❌  ❌  ❌  ✅  ❌  ✅  ✅  ❌
am19 Bio  ❌  ✅  ❌  ❌  ✅  ❌  ❌  ❌  ❌  ❌  ❌  ❌
am20 ECDS ❌  ❌  ❌  ❌  ❌  ❌  ❌  ❌  ✅  ✅  ✅  ✅
am21 EdDS ❌  ❌  ❌  ❌  ❌  ❌  ❌  ❌  ✅  ✅  ✅  ✅
am22 Geo  ✅  ❌  ❌  ❌  ❌  ✅  ❌  ✅  ❌  ❌  ❌  ❌  ← NUEVO método geoespacial
```

**D6 Geoespacial — CORRECCIÓN:** La afirmación anterior "D6 no tiene métodos propios" era
INCORRECTA. D6 tiene 8 métodos aplicables: am4, am5, am6, am7, am12, am13, am14, am17, am22.
La columna D6 NO está vacía.

**D1 Lógico:** Tiene 18 de 22 métodos — todos los NIST 800-63B + federación + M2M.
Solo excluidos: am8 (lector físico NFC), am19 (biométrico PACS), am20 (firma blockchain),
am21 (firma PKI). Esto confirma que D1 tiene "la mayoría de los métodos de autenticación".

---

## 6. IMPACTO EN EL MODELO BAUTH

### 6.1 Cambios al catálogo AUTH_METHODS (demo + futuro DDL)

**Métodos añadidos (versión 1.0 → 1.1):**
- `am8` Smart Card / NFC (PACS) — antes ausente, necesario para D2
- `am19` Biométrico Lector físico — distinto de WebAuthn biométrico
- `am20` ECDSA secp256k1 — necesario para D12 Blockchain
- `am21` EdDSA Ed25519 — necesario para D12 + Vault/PKI
- `am22` Geolocation Auth (GPS/IP/Wi-Fi) — NUEVO en v1.1, corrige error D6 (ver §4.12)

**Correcciones D6 en domains[] (v1.0 → v1.1):**
- `am4` WebAuthn PW: añadido D6 (FIDO2 GPS attestation)
- `am5` WebAuthn 2FA: añadido D6 (FIDO2 GPS attestation)
- `am6` Passkey: añadido D6 (FIDO2 GPS attestation)
- `am7` X.509 mTLS: añadido D6 (X.509 location cert RFC 5280)
- `am12` CIBA: añadido D6 (backchannel geolocation approval)
- `am13` Conditional OTP: añadido D6 (geofencing step-up — caso de uso principal)
- `am14` Device Auth: añadido D6 (device location hint RFC 8628)
- `am17` Client Credentials: añadido D6 (APIs de geolocalización M2M)

**Campo nuevo:** `domains: [1, 3, ...]` — array de domain_code donde el método es aplicable.
Este campo es la fuente de verdad para filtrar métodos por dominio en el UI.

**Cambio en `cat`:** El campo `cat` en AUTH_METHODS pasa de indicar el tipo de asignación
(`assigned/required/alternative`) a indicar la **familia técnica del método**
(`knowledge | possession | inherence | signature | federation | adaptive | backup | m2m`).
La asignación (Asignados/Requeridos/Alternativos) se gestiona en el estado del RolTemplate,
no en el catálogo de métodos.

### 6.2 Comportamiento del panel lateral (demo)

Al activar un dominio en el centro, el panel lateral de métodos filtra
automáticamente para mostrar solo los métodos con ese `domain_code` en su array `domains`.
Esto implementa la restricción de estándares directamente en la UI.

### 6.3 Pendiente: DDL en VPS

El campo `domains` debería existir como `domain_map INTEGER[]` en la tabla
`ath_config_d1` (o en una tabla catálogo `bauth_auth_method_catalog` nueva).
**Requiere HITL antes de ejecutar DDL en VPS.**

---

## 7. FUENTES PRIMARIAS

- [NIST SP 800-63B-4](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-63B-4.pdf)
- [NIST SP 800-116 Rev.1 — PIV en PACS](https://csrc.nist.gov/publications/detail/sp/800-116/rev-1/final)
- [FIDO Alliance — Mobile NFC PACS](https://www.secureidnews.com/news-item/using-fido-authentication-to-secure-mobile-pacs/)
- [IDManagement.gov — PACS 101](https://www.idmanagement.gov/university/pacs/)
- [FIDO2 Biometric Smart Card — Physical+Digital](https://www.logintc.com/blog/bridging-physical-and-digital-access-with-fido2-biometric-smart-card-authentication/)
- [Phishing-Resistant MFA Playbook](https://www.idmanagement.gov/playbooks/altauthn/)
- [Nature Scientific Reports — Proof-of-Location 2025](https://www.nature.com/articles/s41598-025-04566-4)
- [OpenID CIBA 1.0](https://openid.net/specs/openid-client-initiated-backchannel-authentication-core-1_0.html)
- [RFC 8693 — Token Exchange](https://datatracker.ietf.org/doc/html/rfc8693)
- [RFC 9470 — Step-Up Authentication](https://datatracker.ietf.org/doc/html/rfc9470)
- USPTO US 12375929 — "Geolocation authenticator" (2025)
- USPTO US 10623962 — "Geo-location-based mobile user authentication" (2020)
- USPTO US 8839361 — "Access control system with GPS location validation"
- USPTO US 12149935 — "FIDO2 attestation with location" (2024)
- WinMagic MagicEndpoint — Geolocation-Based Authentication (2024)
- Microsoft Azure AD — Location-Based Conditional Access (2024)

---

**Versión del documento:** 1.1 (CORRECCIÓN — D6 no vacío + am22 nuevo + domains[] actualizados)
**Fecha corrección:** 2026-07-08
