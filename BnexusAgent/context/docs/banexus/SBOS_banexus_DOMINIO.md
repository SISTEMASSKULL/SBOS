# DOMINIO — SBOS Nexus Agent (banexus)

## Entidades del Dominio

### Credencial

Representa un evento de autenticacion capturado desde hardware fisico.

```go
type Credential struct {
    Type   CredentialType   // qr | nfc | barcode | fingerprint | pin | smartcard | face | voice | ble | usb
    Raw    []byte           // Datos crudos del lector
    Parsed string           // Interpretacion (ej: "sbos://auth/user/uuid")
    Hash   [32]byte         // SHA-256 del raw (para integridad)
}
```

### AuthRequest

Solicitud de autenticacion enviada a bhnexus.

```json
{"type":"auth_request","node_id":"Ventas-01","input_type":"qr","payload":"sbos://auth/..."}
```

### Policy Cache Entry

BitMask cacheadas localmente para operacion offline.

```go
type CacheEntry struct {
    BitMask    uint64
    ExpiresAt  time.Time
    CreatedAt  time.Time
    NodeID     string
    CredentialHash [32]byte
}
```

### ActuatorCommand

Comando para un actuador fisico.

```go
type ActuatorCommand struct {
    Target     string // "RELAY_01"
    Action     string // "OPEN" | "CLOSE" | "TOGGLE"
    DurationMs int    // 3000 (auto-close)
}
```

## 10 Tipos de Credencial Soportados

| # | Tipo | Tecnologia | Uso tipico |
|---|---|---|---|
| 1 | QR | Codigo QR dinamico | Acceso a puesto, autenticacion rapida |
| 2 | NFC | ISO 14443A/B | Tarjeta de empleado, tag de activo |
| 3 | Barcode | Codigo de barras 1D/2D | Documentos, inventario |
| 4 | Fingerprint | Escaner biometrico capacitivo/optico | Autenticacion fuerte |
| 5 | PIN | Teclado numerico | Backup, modo offline |
| 6 | Smartcard | PKCS#11/PIV | Firma digital, acceso privilegiado |
| 7 | Face | Camara RGB/IR | Control de acceso sin contacto |
| 8 | Voice | Microfono + liveness detection | Autenticacion por voz (future) |
| 9 | BLE | Bluetooth Low Energy | Proximidad, beacon |
| 10 | USB | HID bulk transfer | Conexion directa de hardware |

## Reglas de Negocio

1. **Input hooking antes de evdev**: banexus captura datos USB ANTES de que el SO genere eventos de teclado. Evita inyeccion de eventos maliciosos via /dev/input/*
2. **Firma HMAC en auth_request**: todo payload enviado a bhnexus va firmado con HMAC
3. **Cache local AES-256-GCM**: clave derivada del certificado mTLS
4. **TTL cache offline**: maximo 4 horas configurable. TTL individual: lo que restaba del original (max 30s)
5. **Fail-secure siempre**: sin conexion + cache miss = DENY. Nunca fail-open
6. **Reconexion backoff**: 1s -> 5s -> 15s -> 30s -> 60s (maximo)
7. **Reconexion -> invalidar cache**: al reconectar, limpiar cache local y recibir resumen offline
8. **Shell Sentinel fail-open bloqueante**: Si PAM module timeout -> PAM_SUCCESS (fail-open) + consulta cache local. Esto es la unica excepcion a fail-secure para no bloquear terminal del usuario

---

_Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS5-6, V5-SS3, V7-SS3, V7-SS5_
