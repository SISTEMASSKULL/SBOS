# GLOSARIO — SBOS Nexus Agent (banexus)

## Terminos Tecnicos

| Termino | Definicion |
|---|---|
| **banexus** | Daemon Nexus Agent. Edge Sentinel que intercepta inputs fisicos y comandos shell |
| **bhnexus** | Daemon Nexus Host. Proxy de Hardware Universal, broker central WebSocket |
| **Edge Sentinel** | Punto de presencia fisico de SBOS en cada estacion de trabajo |
| **Input Hooking** | Captura de datos USB en crudo via libusb antes que evdev genere eventos |
| **Shell Sentinel** | Modulo PAM que intercepta comandos sensibles y consulta autorizacion |
| **Policy Cache Efimero** | Cache local de BitMasks cifrado con AES-256-GCM para modo offline |
| **Fail-Secure** | Politica de seguridad: sin conexion + sin cache = DENY siempre |
| **pam_banexus.so** | Modulo PAM que implementa el Shell Sentinel en auth phase |
| **ActuatorCommand** | Comando para actuador fisico (rele, cerradura, alarma) |
| **Backoff Exponencial** | Estrategia de reconexion: 1s -> 5s -> 15s -> 30s -> 60s |
| **Resumen Offline** | Buffer de eventos perdidos durante desconexion que bhnexus envia al reconectar |

## 10 Tipos de Credencial

| # | Tipo | Tecnologia |
|---|---|---|
| 1 | QR | Codigo QR dinamico |
| 2 | NFC | ISO 14443A/B |
| 3 | Barcode | Codigo de barras 1D/2D |
| 4 | Fingerprint | Escaner biometrico capacitivo/optico |
| 5 | PIN | Teclado numerico |
| 6 | Smartcard | PKCS#11/PIV |
| 7 | Face | Camara RGB/IR |
| 8 | Voice | Microfono + liveness detection |
| 9 | BLE | Bluetooth Low Energy |
| 10 | USB | HID bulk transfer |

## Estados de Conexion

| Estado | Significado |
|---|---|
| connected | Conexion activa con bhnexus |
| disconnected | Desconexion detectada (cache local activo) |
| suspended | Host suspendio al agente |
| terminated | Agente dado de baja |

## Reglas de Cache

| Condicion | Decision |
|---|---|
| Cache HIT + TTL valido | GRANTED |
| Cache MISS + conectado | Consulta bhnexus |
| Cache MISS + desconectado | DENIED |
| TTL expirado | DENIED |
| Shell Sentinel timeout | PAM_SUCCESS + cache local |

---

_Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS1, SS5-6, V5-SS3, V7-SS3, V7-SS5_
