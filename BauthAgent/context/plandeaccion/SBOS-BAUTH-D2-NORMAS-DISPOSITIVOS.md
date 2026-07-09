# SBOS — Normas y Estándares de Gestión de Dispositivos Físicos en Sistemas de Autenticación
## Investigación Profesional para el Dominio Físico (D2)
### SKULL · SBOS · Junio 2026 · v1.0

**Propósito:** Compilación de estándares internacionales, protocolos y mejores prácticas para la gestión de dispositivos físicos en sistemas de autenticación y control de acceso. Referencia normativa para el dominio D2 (Físico) de bAuth.

**Código:** SBOS-BAUTH-D2-NORMAS-DISPOSITIVOS-v1.0
**Complementa:** `SBOS-MANUAL-BAUTH-COMPONENT-ROLES.md` v1.7, `SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md`

---

## 1. OSDP v2.2.2 — Protocolo Estándar para Dispositivos de Control de Acceso

### 1.1 ¿Qué es OSDP?

**Open Supervised Device Protocol (OSDP)** es el estándar de la industria de seguridad para comunicación entre lectores, periféricos y controladores de acceso. Desarrollado por la Security Industry Association (SIA), aprobado como estándar internacional **IEC 60839-11-5** (Mayo 2020). La versión **2.2.2** (Octubre 2024) es la más reciente.

### 1.2 Características Clave

| Característica | Wiegand (legacy) | OSDP v2.2.2 |
|---------------|-----------------|-------------|
| **Comunicación** | Unidireccional | Bidireccional |
| **Cifrado** | Ninguno (texto plano) | **AES-128** (Secure Channel) |
| **Supervisión** | No | Sí — monitoreo constante de cableado |
| **Distancia** | 150m | 1,200m (RS-485) |
| **Multidrop** | No | Sí — múltiples dispositivos en un bus |
| **Firmware update** | No | Sí — transferencia segura de archivos |
| **Anti-tamper** | No | Sí — detección de manipulación y eavesdropping |
| **Certificación** | No | **SIA OSDP Verified** (certificación independiente) |

### 1.3 Secure Channel (AES-128)

OSDP Secure Channel establece un canal cifrado entre el lector y el controlador:
- **AES-128 CBC** para cifrado de datos
- **Derivación de claves** por sesión (ephemeral keys)
- **Requerido** para aplicaciones gubernamentales (FICAM/PKI)
- **Previene:** sniffing de credenciales, device spoofing, replay attacks

### 1.4 Certificación OSDP Verified (2025-2026)

Múltiples fabricantes obtuvieron certificación basada en v2.2.2:
- **Armatura** (Diciembre 2025): ACUs, módulos I/O, lectores EP series
- **ZKTeco USA**: EP series, Atlas controllers, IO boards
- **U-PROX**: SE series readers

### 1.5 Implementación Open Source

Existe una implementación portable en **C11/Rust** (Z-bit Systems) con soporte para:
- Peripheral Device (PD) y Access Control Unit (ACU) state machines
- OSDP Secure Channel handshake
- Interoperabilidad con dispositivos certificados

**Aplicación en SBOS:** B15.T06 (Hardware Bridge) y B15.T10 (osdp_driver) deben implementar OSDP v2.2.2 con Secure Channel AES-128.

---

## 2. RFC 9944 — SCIM Device Schema Extensions (Mayo 2026)

### 2.1 Visión General

**RFC 9944** (Standards Track, Mayo 2026) define extensiones de esquema SCIM para **dispositivos**. Permite el aprovisionamiento estandarizado de dispositivos IoT y de autenticación en sistemas de gestión de identidad.

### 2.2 Métodos de Bootstrapping Soportados

| Método | Descripción | Aplicación en SBOS |
|--------|------------|-------------------|
| **FIDO Device Onboard (FDO)** | Vouchers de propiedad para onboarding automático | Registro de banexus con TPM |
| **Wi-Fi Easy Connect** | Configuración de red sin pantalla | Terminales Fedora sin interfaz de red previa |
| **BLE Passcode** | Emparejamiento Bluetooth | Dispositivos móviles de autenticación |
| **MAC Authenticated Bypass (MAB)** | Autenticación por dirección MAC | Dispositivos legacy sin soporte FDO |

### 2.3 Esquema Device

RFC 9944 define un nuevo tipo de recurso `Device` para SCIM con atributos:
- `deviceUuid` — identificador único del dispositivo
- `attestationId` — identificador de atestación FDO
- `deviceModel` — modelo/fabricante
- `firmwareVersion` — versión de firmware
- `ownershipVoucher` — voucher de propiedad FDO
- `bootstrappingMethods` — métodos de bootstrap soportados

**Aplicación en SBOS:** B15.T17 (DeviceRegistry) debe alinearse con el esquema Device de RFC 9944 para interoperabilidad futura.

---

## 3. FIDO Device Onboard (FDO) + Enterprise Attestation

### 3.1 FIDO Device Onboard

Protocolo de la **FIDO Alliance** para onboarding automático de dispositivos IoT:
- **Ownership Voucher:** documento firmado que prueba propiedad del dispositivo
- **Service Ready:** el dispositivo se conecta automáticamente a la plataforma correcta
- **Zero-touch:** sin intervención manual para configurar credenciales de red o plataforma

### 3.2 Enterprise Attestation (HID, 2025)

**HID Global** implementó Enterprise Attestation para FIDO authenticators:
- Durante el registro, verifica un **certificado** que vincula el authenticator a un dispositivo conocido y autorizado por la empresa
- Si el certificado está ausente → **el enrollment es bloqueado por política**
- Alineado con: **NIS2 Directive, DORA, Zero Trust**
- Soportado en: HID Crescendo FIDO2 smart cards + PingOne

### 3.3 Open-Source FIDO2 Authenticator (Pico FIDO v7.x, 2026)

Firmware open-source para Raspberry Pi Pico / ESP32:
- **CTAP 2.1 + WebAuthn**
- **Self attestation + Enterprise attestation**
- **Secure Boot + Secure Lock** (RP2350, ESP32-S3)
- **OTP-stored master key** — cifra todas las claves privadas
- Credenciales descubribles (resident keys)
- Paquete enterprise: inventario de dispositivos, trazabilidad, revocación segura, anti-clonación, PQC

**Aplicación en SBOS:** Los banexus podrían usar FDO para onboarding automático y Enterprise Attestation para verificar que solo dispositivos autorizados se conecten.

---

## 4. Aliro — Estándar de Credenciales Basadas en Certificados (Febrero 2026)

### 4.1 ¿Qué es Aliro?

Estándar abierto de la **Connectivity Standards Alliance** para credenciales móviles y acceso físico usando protocolos basados en certificados. Lanzado en Febrero 2026.

### 4.2 Características

- **Certificados X.509** como credencial de identidad física
- **PKI empresarial** — alineado con Zero Trust
- **Interoperabilidad multi-vendor** — sin compartir secretos entre organizaciones
- **Federación de identidad cross-organizacional**
- **Post-quantum readiness**
- **Safetrust** proyecta que los próximos 12-24 meses son "la ventana crítica de decisión" para adopción

### 4.3 LEAF Verified (2026)

Complemento de Aliro usando **NXP MIFARE DUOX**:
- **Criptografía asimétrica** embebida en el chip durante fabricación
- Clave pública para compartir, clave privada sellada en el chip
- **Clonación casi imposible**
- Cumple: SOC 2, PCI-DSS, HIPAA, FIPS

**Aplicación en SBOS:** Las credenciales físicas (NFC/RFID) de banexus deben evolucionar hacia Aliro/LEAF para máxima seguridad.

---

## 5. NIST SP 800-53 Rev.5 — Controles para Dispositivos Físicos

### 5.1 Controles del Dominio Físico (D2)

| Control | Nombre | Requisito | Átomo SBOS |
|---------|--------|----------|------------|
| **PE-3** | Physical Access Control | Verificar autorización individual antes de acceso físico. Mantener logs de auditoría. | B2.T04-T05, B15.T04 |
| **PE-4** | Access Control for Transmission Medium | Proteger cables y puntos de conexión física | OSDP Secure Channel AES-128 |
| **PE-6** | Monitoring Physical Access | Monitorear eventos de acceso físico en tiempo real | B15.T20 (DeviceHealthMonitor) |
| **AC-19** | Access Control for Mobile Devices | Cifrado full-device o container-based | B21.T08 (EdgePolicyCache AES-256-GCM) |
| **IA-9** | Service Identification & Authentication | M2M authentication models | B15.T18 (mTLS certificates) |
| **CM-5** | Access Restrictions for Change | Solo personal autorizado accede para cambios | B15.T19 (firmware signed) |

### 5.2 Zero Trust para Dispositivos Físicos (2026)

Tendencias clave del sector PACS en 2026:
1. **Autenticación de dispositivos** — no solo usuarios. Validación mutua host↔controller↔edge.
2. **Secure Boot** — firmware firmado digitalmente, verificado en cada arranque.
3. **SBOM visibility** — Software Bill of Materials para cada dispositivo.
4. **Monitorización continua de CVEs** — respuesta automatizada ante vulnerabilidades.
5. **Zero Trust físico** — sin confianza implícita por ubicación (estar dentro del edificio no garantiza acceso).

---

## 6. Ciclo de Vida del Dispositivo Físico

### 6.1 Modelo Estándar (Alineado con Mercury Security + SecuriThings 2026)

```
┌─────────────────────────────────────────────────────────────────┐
│           CICLO DE VIDA DEL DISPOSITIVO FÍSICO                    │
│                                                                   │
│  1. PROVISIONING                                                  │
│     ├── Registro en inventario (device_id, serial, modelo)       │
│     ├── Emisión de certificado mTLS (Vault PKI)                  │
│     ├── Configuración de claves de cifrado (OSDP Secure Channel) │
│     └── Asignación a zona física (D2)                            │
│                                                                   │
│  2. ONBOARDING                                                    │
│     ├── Bootstrap de red (FDO / Wi-Fi Easy Connect)              │
│     ├── Verificación de atestación (Enterprise Attestation)      │
│     ├── Handshake mTLS con bhnexus                               │
│     └── Heartbeat inicial → estado ACTIVE                        │
│                                                                   │
│  3. OPERATION                                                     │
│     ├── Heartbeat cada 30s                                       │
│     ├── Health metrics (latencia, errores, uptime)               │
│     ├── Policy updates push desde bAuth                          │
│     └── Auditoría continua de eventos físicos                    │
│                                                                   │
│  4. MAINTENANCE                                                   │
│     ├── Firmware update (signed + checksum)                      │
│     ├── Rotación de certificados (cada 24h, sin downtime)        │
│     ├── Rotación de claves OSDP (por sesión)                     │
│     └── Sincronización de configuración                          │
│                                                                   │
│  5. DECOMMISSIONING                                               │
│     ├── Revocación de certificado mTLS                           │
│     ├── Wipe de credenciales (factory reset remoto)              │
│     ├── Export de auditoría del dispositivo                      │
│     ├── Marcar como DECOMMISSIONED en inventario                 │
│     └── Auditoría obligatoria de decommissioning                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. Matriz de Conformidad SBOS D2 vs Estándares

| # | Estándar | Requisito | Átomo(s) SBOS |
|---|----------|----------|---------------|
| D01 | **OSDP v2.2.2** | Bidireccional + AES-128 + supervisión | B15.T06, B15.T10 |
| D02 | **OSDP Secure Channel** | Canal cifrado reader↔controller | B15.T10 (osdp_driver) |
| D03 | **RFC 9944 (SCIM Device)** | Device schema para aprovisionamiento | B15.T17 (DeviceRegistry) |
| D04 | **FIDO Device Onboard** | Zero-touch onboarding con Ownership Voucher | B15.T18, B21 (banexus) |
| D05 | **FIDO Enterprise Attestation** | Verificar certificado de dispositivo al registrar | B15.T18 (certificate check) |
| D06 | **Aliro (2026)** | Credenciales físicas basadas en certificados X.509 | Futuro: NFC/RFID → Aliro |
| D07 | **LEAF Verified** | Criptografía asimétrica en chip (anti-clonación) | Futuro: credenciales físicas |
| D08 | **NIST SP 800-53 PE-3** | Verificar autorización individual antes de acceso físico | B2.T04-T05 (PhysicalEvaluator) |
| D09 | **NIST SP 800-53 PE-6** | Monitoreo de acceso físico en tiempo real | B15.T20 (DeviceHealthMonitor) |
| D10 | **NIST SP 800-53 AC-19** | Cifrado en dispositivos móviles | B21.T08 (EdgePolicyCache) |
| D11 | **NIST SP 800-53 IA-9** | M2M authentication | B15.T18 (mTLS certificates) |
| D12 | **NIST SP 800-53 CM-5** | Solo personal autorizado para cambios | B15.T19 (firmware signed) |
| D13 | **NIST SP 800-207 (Zero Trust)** | Sin confianza implícita por ubicación | B15 (todo el motor) |
| D14 | **Mercury Security (2026)** | Secure boot + SBOM + CVE monitoring | B15.T19, B15.T20 |
| D15 | **ISO 27001 A.8.1** | Inventario de activos (dispositivos) | B15.T17 (DeviceRegistry) |
| D16 | **ISO 27001 A.8.3** | Devolución segura de activos | B15.T21 (DeviceDecommission) |

---

## 8. Referencias

- [SIA OSDP v2.2.2 Standard](https://www.securityindustry.org/industry-standards/open-supervised-device-protocol/)
- [OSDP Embedded (C11/Rust open-source)](https://github.com/Z-bit-Systems-LLC/OSDP-Embedded)
- [RFC 9944 — SCIM Device Schema Extensions](https://datatracker.ietf.org/doc/html/rfc9944) (Mayo 2026)
- [RFC 9943 — SCITT Architecture](https://www.rfc-editor.org/authors/rfc9943.html) (Abril 2026)
- [FIDO Device Onboard (FDO) Specification](https://fidoalliance.org/intro-to-fido-device-onboard/)
- [HID Enterprise Attestation for FIDO](https://fidoalliance.org/benchmark-hid-adds-governance-layer-to-fido-authenticators-with-enterprise-attestation/) (2025)
- [Pico FIDO v7.x — Open-Source FIDO2 Authenticator](https://github.com/polhenarejos/pico-fido)
- [Aliro — Certificate-Based Physical Identity Standard](https://www.globenewswire.com/fr/news-release/2026/06/03/3306343/0/en/safetrust-hosts-expert-briefing-on-aliro-the-enterprise-standard-for-certificate-based-physical-identity.html) (Feb 2026)
- [LEAF Verified Credential](https://www.securityinfowatch.com/access-identity/access-control/product/55359714/leaf-community-debuts-leaf-verified-credential-with-asymmetric-encryption) (2026)
- [NIST SP 800-53 Rev.5](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)
- [Mercury Security — PACS Cybersecurity 2026](http://www.securitysa.com/26544r)
- [SecuriThings — PKI Certificate Lifecycle for PACS](https://securithings.com/it-cyber-partners/)
- [AMAG Symmetry CONNECT 2.0 — Unified PACS Identity](https://amag.com/showcase-award/) (ISC West 2026)
- [Ambient.ai — PACS Architecture Guide 2026](https://www.ambient.ai/learn/what-is-physical-access-control)

---

*SKULL · SBOS · SBOS-BAUTH-D2-NORMAS-DISPOSITIVOS-v1.0 · Junio 2026*
*Confidencial — Propiedad de SKULL Desarrollo de Software*
