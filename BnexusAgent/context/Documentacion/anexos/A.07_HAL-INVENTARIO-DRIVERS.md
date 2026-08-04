# A.07 — HAL: Inventario de Drivers y Tipos de Credencial
## Tabla completa con protocolos, LoA, timing y compatibilidad de hardware

**Versión:** 1.0.0  
**Fecha:** 2026-08-04  
**Respalda:** `3.01_MANUAL-HAL.md` + `3.02_MANUAL-DRIVERS.md`  

---

## 1. Inventario de drivers del HAL

| Driver | Archivo | Protocolo | Versión | Estándar | Dirección | Dónde corre |
|--------|---------|-----------|:-------:|----------|:---------:|:-----------:|
| OsdpDriver | `osdp_driver.rs` | OSDP | v2.2.2 | SIA / IEC 60839-11-5 | bhnexus → PD | bhnexus |
| WiegandDriver | `wiegand_driver.rs` | Wiegand | 26/34/37-bit | Sin estándar formal | PD → bhnexus GPIO | bhnexus |
| MqttDriver | `mqtt_driver.rs` | MQTT | 5.0 | OASIS MQTT 5.0 | Bidireccional | bhnexus |
| OnvifDriver | `onvif_driver.rs` | ONVIF | Profile S/T/C | ONVIF 22.12 | Pull o push | bhnexus |
| UsbHidDriver | `usb_hid_driver.rs` | USB HID | HID 1.11 | USB-IF HID 1.11 | Dispositivo → banexus | banexus |
| HttpDriver | `http_driver.rs` | REST HTTPS | HTTP/1.1 o 2 | RFC 7230 / RFC 9113 | Bidireccional | bhnexus |

---

## 2. Tipos de credencial — inventario completo

| CredentialType (enum) | Nombre | Driver principal | LoA mín. | LoA máx. | Timing (driver→bAuth) |
|-----------------------|--------|-----------------|:---------:|:---------:|:--------------------:|
| `QrDynamic` | QR Dinámico | UsbHidDriver | 1 | 2 | < 3ms |
| `NfcMifareDesfire` | NFC DESFire AES-128 | OsdpDriver | 2 | 3 | < 3ms |
| `NfcMifareClassic` | NFC Mifare Classic (legacy) | OsdpDriver | 1 | 1 | < 3ms |
| `Rfid125Khz` | RFID 125kHz Wiegand | WiegandDriver | 1 | 1 | < 5ms |
| `FingerprintHash` | Huella dactilar OSDP | OsdpDriver | 3 | 3 | < 3ms |
| `FaceHash` | Reconocimiento facial | OnvifDriver / OsdpDriver | 2 | 3 | < 5ms |
| `IrisHash` | Reconocimiento de iris | OsdpDriver | 3 | 4 | < 3ms |
| `SmartcardX509` | Smartcard PKI X.509 | OsdpDriver | 3 | 4 | < 3ms |
| `BleToken` | BLE Aliro CSA 2023 | banexus-sdk | 2 | 3 | < 10ms |
| `PinHash` | PIN numérico | OsdpDriver | 1 | 1 | < 3ms |
| `MtlsCert` | mTLS X.509 (cliente de software) | pam_banexus.so | 3 | 3 | < 5ms |

---

## 3. Compatibilidad driver × tipo de credencial

| Credencial | OSDP | Wiegand | MQTT | ONVIF | USB HID | HTTP |
|-----------|:----:|:-------:|:----:|:-----:|:-------:|:----:|
| QR Dinámico | ⚠️* | — | — | — | ✅ | ✅ |
| NFC DESFire | ✅ | — | — | — | ✅ (ACR122U) | — |
| NFC Mifare Classic | ✅ | — | — | — | ✅ | — |
| RFID 125kHz | ✅ | ✅ | — | — | — | — |
| Biométrico (hash) | ✅ (Biometric Profile) | — | — | ✅ (facial) | — | — |
| Smartcard X.509 | ✅ (Smart Card Profile) | — | — | — | ✅ (CCID) | — |
| BLE Aliro | — | — | — | — | — | ✅** |
| PIN | ✅ | — | — | — | — | — |
| Sensor IoT | — | — | ✅ | — | — | — |

*OSDP puede leer QR si el lector tiene cámara integrada con módulo OSDP + HDMI.  
**BLE Aliro llega a bhnexus a través del lector Aliro que usa HTTP o via banexus-sdk.

---

## 4. Tabla de hardware físico × driver

| Fabricante | Modelo | Driver | Protocolos | Tipos de credencial |
|-----------|--------|--------|------------|---------------------|
| **ZKTeco** | SF1000 | OsdpDriver | OSDP v2 | NFC, huella dactilar, PIN |
| **ZKTeco** | SB1000 | OsdpDriver | OSDP v2 Biometric | Huella, cara |
| **HID Global** | pivCLASS | OsdpDriver | OSDP v2 Smart Card | Smartcard X.509, NFC |
| **HID Global** | Proxpoint | WiegandDriver | Wiegand 26/34 | RFID 125kHz |
| **Suprema** | BioStation 3 | OsdpDriver | OSDP v2 Biometric | Huella, cara |
| **Allegion** | ENGAGE NDE | HttpDriver | REST + Aliro | BLE, NFC, PIN |
| **Honeywell** | Xenon 1900 | UsbHidDriver | USB HID | QR |
| **ACS** | ACR122U | UsbHidDriver | USB HID (NFC) | NFC DESFire, Mifare |
| **Hikvision** | DS-2CD2143G2-I | OnvifDriver | ONVIF Profile T | Face hash |
| **AXIS** | P3245-V | OnvifDriver | ONVIF Profile C | Face hash |
| **Genérico** | Sensor MQTT | MqttDriver | MQTT 5.0 | Sensor data → RFID/PIN |
| **Raspberry Pi** | Pi 5 + GPIO | WiegandDriver | GPIO Wiegand | RFID 125kHz |

---

## 5. Timing por driver — desglose detallado

Para cada tipo de credencial, el tiempo total end-to-end es:

```
Tiempo total = T_driver + T_eventbus + T_cache_lookup + T_bauth_round_trip + T_actuator

Donde:
  T_driver:         tiempo de captura en el driver (ver tabla abajo)
  T_eventbus:       < 0.1ms (tokio channel)
  T_cache_lookup:   O(1) < 0.1ms (cache hit) / 0ms (cache miss)
  T_bauth_round_trip: < 10ms (sub-canal A) — solo en cache miss
  T_actuator:       < 2ms (relé GPIO, OSDP command)
```

| Driver | T_driver (captura hasta CredentialEvent) |
|--------|:----------------------------------------:|
| OsdpDriver — NFC DESFire | 1-2ms (polling OSDP a 9600 baud) |
| OsdpDriver — biométrico | 1-3ms (template ya procesado en chip) |
| OsdpDriver — smartcard | 2-5ms (challenge-response APDU) |
| WiegandDriver | 25-100ms (duración de los 26 pulsos GPIO) |
| MqttDriver | < 1ms (mensaje ya en el topic) |
| OnvifDriver — push | 50-100ms (latencia de event subscription) |
| OnvifDriver — poll | 500-1000ms (intervalo de polling) |
| UsbHidDriver — QR | 1-2ms (datos en bulk transfer) |
| UsbHidDriver — NFC | 1-2ms (APDU completado en el lector) |
| HttpDriver — servidor | < 1ms (request ya recibida) |

---

## 6. Tabla de seguridad por driver

| Driver | Canal cifrado | Autenticación del dispositivo | Anti-replay | Tamper detection |
|--------|:-------------:|:----------------------------:|:-----------:|:----------------:|
| OsdpDriver | ✅ AES-128 SC | ✅ OSDP Secure Channel | ✅ SC sequence numbers | ✅ tamper bit |
| WiegandDriver | ❌ Sin cifrado | ❌ Ninguna | ❌ Clonable | ❌ Sin tamper |
| MqttDriver | ✅ TLS 1.3 | ✅ cert mTLS cliente | ✅ message_id | ⚠️ Firmware |
| OnvifDriver | ✅ HTTPS | ✅ auth digest o mTLS | ⚠️ timestamp | ⚠️ Firmware |
| UsbHidDriver | N/A (local) | ⚠️ udev rules | ✅ bloom filter | ⚠️ Físico |
| HttpDriver | ✅ TLS 1.3 | ✅ mTLS cliente | ✅ request_id | ⚠️ Firmware |

---

## 7. Capacidades de actuador por driver

| Driver | Relé GPIO | Cerradura OSDP | LED lector | Buzzer | Display | MQTT pub |
|--------|:---------:|:--------------:|:----------:|:------:|:-------:|:--------:|
| OsdpDriver | — | ✅ oCmd_OUT | ✅ oCmd_LEDER | ✅ oCmd_BUZZ | ✅ oCmd_TEXT | — |
| WiegandDriver | ✅ GPIO | — | — | — | — | — |
| MqttDriver | — | — | — | — | — | ✅ publish |
| OnvifDriver | — | — | — | — | — | — |
| UsbHidDriver | — | — | ✅ (si lector lo soporta) | ✅ | — | — |
| HttpDriver | — | — | — | — | — | ✅ REST call |

---

## 8. Requisitos mínimos de hardware para cada driver

| Driver | SO mínimo | Privilegios | Dependencias |
|--------|-----------|:-----------:|-------------|
| OsdpDriver | Linux + `/dev/ttyUSB*` | CAP_SYS_RAWIO | libosdp (Rust crate) |
| WiegandDriver | Linux + GPIO | CAP_SYS_RAWIO | libgpiod |
| MqttDriver | Cualquier | Sin privilegios especiales | rumqttc |
| OnvifDriver | Cualquier | Sin privilegios especiales | onvif (HTTP) |
| UsbHidDriver | Linux + udev | CAP_SYS_RAWIO o grupo usb | libusb-1.0 |
| HttpDriver | Cualquier | Sin privilegios especiales | reqwest (TLS) |

---

*SKULL · SBOS · bNexus · A.07_HAL-INVENTARIO-DRIVERS · v1.0.0 · Agosto 2026*
