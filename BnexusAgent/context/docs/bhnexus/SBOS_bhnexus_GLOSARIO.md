# GLOSARIO — SBOS Nexus Host (bhnexus)

## Terminos Tecnicos

| Termino | Definicion |
|---|---|
| **bhnexus** | Daemon Nexus Host. Proxy de Hardware Universal, broker central WebSocket |
| **banexus** | Daemon Nexus Agent. Edge Sentinel que intercepta inputs fisicos |
| **Hardware Bridge** | Componente que normaliza 6 protocolos fisicos bajo CredentialEvent comun |
| **HAL** | Hardware Abstraction Layer. Interfaz Go que todo driver de hardware debe implementar |
| **Auth Cache** | Cache in-memory de BitMasks con TTL 30s para respuesta sub-5ms |
| **Device Ficha** | Archivo YAML que declara un dispositivo, su protocolo y actuadores |
| **CredentialEvent** | Evento normalizado de cualquier lector de hardware |
| **ActuatorCommand** | Comando para actuador fisico (cerradura, rele, alarma) |
| **mTLS** | Mutual TLS. Autenticacion mutua con certificados en ambas direcciones |
| **Policy Cache Efimero** | Cache local en agente con AES-256-GCM para operacion offline |

## 6 Drivers de Hardware

| Driver | Protocolo | Conexion |
|---|---|---|
| driver_osdp | OSDP v2.2 | RS-485 serial |
| driver_wiegand | Wiegand 26/34/37 bits | GPIO |
| driver_mqtt | MQTT v3.1.1/v5 | TCP/IP |
| driver_onvif | ONVIF Profile C/A | IP/ethernet |
| driver_usbhid | USB HID | USB directo |
| driver_http | REST API | TCP/IP |

## 10 Tipos de Credencial

qr | nfc | barcode | fingerprint | pin | smartcard | face | voice | ble | usb

## 11 Niveles de Ubicacion Fisica

Nivel 0 (Planeta) a Nivel 10 (Actuador), con jerarquia completa: pais -> ciudad -> sucursal -> piso -> zona -> puesto -> dispositivo -> subdispositivo -> sensor -> actuador

## 4 Estados de Conexion del Agente

| Estado | Significado |
|---|---|
| connected | Conexion activa y funcional |
| disconnected | Desconexion detectada por timeout |
| suspended | Host suspendio al agente por policy |
| terminated | Agente dado de baja permanentemente |

## 8 Reglas Wazuh

NEXUS-001 a NEXUS-008, cubriendo desde denied rate hasta ejecucion no autorizada de actuadores.

---

_Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS1-4, V5-SS1, V7-SS1-6_
