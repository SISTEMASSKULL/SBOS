# Motor 3 — Hardware (Normalizar-HAL)
## HAL: 6 drivers que producen un CredentialEvent uniforme

**Versión:** 1.0.0  
**Fecha:** 2026-08-04  
**Motor en MOTORES-INDEX:** `M-03`  
**Respalda:** `3.01_MANUAL-HAL.md` + `3.02_MANUAL-DRIVERS.md` + `3.03_MANUAL-FLUJOS-CREDENCIAL.md` + `A.07_HAL-INVENTARIO-DRIVERS.md`

---

## Responsabilidad del motor

El Motor de Hardware (HAL — Hardware Abstraction Layer) **normaliza** los eventos de todos los dispositivos físicos a un único tipo `CredentialEvent`, independientemente del protocolo físico subyacente.

**Verbo central:** `Normalizar` — convierte el lenguaje del hardware al lenguaje de bAuth.

## Qué hace

1. **Escucha** eventos de hardware en 6 protocolos distintos simultáneamente
2. **Normaliza** cada evento a `CredentialEvent { event_id, credential_type, payload, device_id, ... }`
3. **Aplica** anti-replay: bloom filter de 10,000 event_ids, ventana 60s
4. **Envía** el `CredentialEvent` al Motor de Identidad bAuth (Puerta 2)
5. **Recibe** `ActuatorCommand` y los ejecuta en el hardware correspondiente
6. **Monitorea** la salud de cada dispositivo y emite `device_tamper` si detecta anomalías

## Los 6 drivers

| Driver | Protocolo | Estándar | Seguridad | Dónde corre |
|--------|-----------|----------|-----------|:-----------:|
| OsdpDriver | OSDP v2.2.2 | SIA / IEC 60839-11-5 | AES-128 SC ✅ | bhnexus |
| WiegandDriver | Wiegand 26/34/37-bit | N/A ⚠️ | Sin cifrado ❌ | bhnexus |
| MqttDriver | MQTT 5.0 | OASIS | TLS 1.3 + mTLS ✅ | bhnexus |
| OnvifDriver | ONVIF Profile S/T/C | ONVIF 22.12 | HTTPS ✅ | bhnexus |
| UsbHidDriver | USB HID 1.11 | USB-IF | udev exclusivo ✅ | banexus |
| HttpDriver | REST HTTPS | RFC 7230/9113 | mTLS ✅ | bhnexus |

## Lo que NO hace

- No descifra el payload de credencial (el sector DESFire, el hash biométrico) — eso es bAuth
- No valida HMAC ni firmas — eso es bAuth
- No almacena templates biométricos — el hash viaja cifrado y se descarta tras usarse

## Principio de extensibilidad

```
Agregar un nuevo protocolo de hardware = implementar DeviceDriver trait en Rust:
  fn protocol()    → &str
  fn connect()     → Result<>
  fn listen()      → impl Stream<Item=CredentialEvent>
  fn send_command()→ Result<>
  fn health_check()→ DeviceHealth
  fn disconnect()  → Result<>

+ registrar en DriverRegistry
→ soporte completo sin modificar el resto del sistema
```

---

*SKULL · SBOS · bNexus · MOTORES/motor-hardware · v1.0.0 · Agosto 2026*
