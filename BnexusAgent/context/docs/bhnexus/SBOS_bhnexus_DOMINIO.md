# DOMINIO — SBOS Nexus Host (bhnexus)

## Entidades del Dominio

### Device Ficha

Unidad declarativa que representa un dispositivo fisico. Archivo YAML en `/etc/bos/blibs/bhnexus/devices/`.

```yaml
device:
  id: "AP-PUERTA-01"
  name: "Puerta Principal - Piso de Ventas"
  type: "access_point"
  protocol: "osdp"
  connection: { host: "192.168.1.50", port: 9600 }
  zone: "ZONE-VENTAS"
  actuators:
    - id: "RELAY_01"
      type: "door_lock"
      action_on_grant: "OPEN"
      open_duration_ms: 3000
  health: { check_interval_seconds: 30, check_command: "osdp_poll" }
```

### Agente (banexus instance)

Conexion remota de un edge agent. Estado: connected | disconnected | suspended | terminated.

### Auth Cache

Cache in-memory de BitMasks autorizadas. Clave: node_id + input_type + credential_hash. TTL: 30s configurable.

### CredentialEvent

Evento normalizado proveniente de cualquier lector de hardware:

```go
type CredentialEvent struct {
    SourceID    string      // ID del dispositivo fisico
    Credential  Credential  // Credencial normalizada
    CapturedAt  time.Time   // Timestamp de captura local
    FirmwareVer string      // Version del firmware del lector
}
```

### Credential (10 tipos)

qr | nfc | barcode | fingerprint | pin | smartcard | face | voice | ble | usb

## 6 Protocolos de Hardware Soportados

| Driver | Protocolo | Estandar | Conexion tipica |
|---|---|---|---|
| `driver_osdp` | OSDP v2.2 | SIA OSDP | RS-485 serial |
| `driver_wiegand` | Wiegand 26/34/37 bits | De facto industria | Cableado directo GPIO |
| `driver_mqtt` | MQTT v3.1.1/v5 | OASIS | TCP/IP a broker |
| `driver_onvif` | ONVIF Profile C/A | ONVIF | IP/ethernet |
| `driver_usbhid` | USB HID | USB-IF | USB directo |
| `driver_http` | REST API | Propietario | TCP/IP |

## 11 Niveles de Ubicacion Fisica

| Nivel | Descripcion |
|---|---|
| 0 | PLANETA (Tierra) |
| 1 | PAIS (ej: Bolivia) |
| 2 | CIUDAD (ej: La Paz) |
| 3 | SUCURSAL (ej: Sucursal Central) |
| 4 | PISO (ej: Piso 3) |
| 5 | ZONA (ej: Zona Ventas) |
| 6 | PUESTO (ej: Caja-01) |
| 7 | DISPOSITIVO (ej: Lector QR-01) |
| 8 | SUBDISPOSITIVO (ej: RELE-01) |
| 9 | SENSOR (ej: Contacto magnetico) |
| 10 | ACTUADOR (ej: Cerradura electrica) |

## HAL (Hardware Abstraction Layer) Interface

```go
type DeviceDriver interface {
    Init(config DeviceConfig) error
    ReadEvent(ctx context.Context) (CredentialEvent, error)
    WriteCommand(cmd ActuatorCommand) error
    Health() HealthStatus
    Close() error
}
```

## Reglas de Negocio

1. **Siempre verificar mTLS**: toda conexion WebSocket requiere certificado valido + Node-ID registrado
2. **Cache antes de bauth**: auth cache hit evita consulta a bauth (sub-5ms vs ~10ms)
3. **TTL maximo 30s en cache**: configurable pero nunca superior a 300s
4. **Sin fail-open**: si cache miss y bauth no responde -> DENY
5. **LRU eviction**: cache con capacidad 100,000 entradas (~15MB RAM)
6. **Policy update push**: cuando cambia un RolTemplate, bhnexus notifica a todos los agentes afectados
7. **Heartbeat cada 15s**: Ping/Pong para detectar desconexion en < 30s
8. **Backoff exponencial en reconexion**: 1s -> 5s -> 15s -> 30s -> 60s

---

_Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS2, SS4, V5-SS1-2, V7-SS1-4_
