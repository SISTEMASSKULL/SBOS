# DATOS — SBOS Nexus Agent (banexus)

## Policy Cache Local

Almacenamiento de BitMasks cacheadas para operacion offline.

### Estructura en Disco

Directorio: `/etc/banexus/cache/`

```
/etc/banexus/cache/
|-- cache.db           # SQLite cifrado con AES-256-GCM
|-- cache.key          # Clave derivada del certificado mTLS (600 permisos)
|-- offline.log        # Registro de decisiones offline
```

### Schema del Cache

```sql
CREATE TABLE policy_cache (
    node_id TEXT NOT NULL,
    credential_hash BLOB NOT NULL,
    bitmask INTEGER NOT NULL,
    input_type TEXT NOT NULL,
    created_at INTEGER NOT NULL,     -- Unix timestamp
    expires_at INTEGER NOT NULL,     -- Unix timestamp
    granted BOOLEAN NOT NULL,
    cache_used BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (node_id, credential_hash)
);
```

### Parametros

| Parametro | Valor |
|---|---|
| Algoritmo cifrado | AES-256-GCM |
| Clave | Derivada del certificado mTLS (HKDF) |
| TTL maximo offline | 4 horas (configurable) |
| TTL por entrada | Lo que restaba del TTL original (max 30s) |
| Tamano maximo | 10,000 entradas |

## Configuracion (banexus.toml)

```toml
[agent]
node_id = "Ventas-01"
host_url = "wss://sbos-server:9444"
tls_cert = "/etc/banexus/tls/agent.crt"
tls_key = "/etc/banexus/tls/agent.key"
ca_cert = "/etc/banexus/tls/ca.crt"

[input]
intercept_usb = true
reader_devices = ["/dev/banexus/reader-*"]

[shell_sentinel]
sensitive_commands = ["apt-get","dnf","systemctl","rm -rf","sudo","passwd"]

[actuators]
relay_port = "/dev/ttyUSB0"

[cache]
enabled = true
encryption = "aes-256-gcm"
max_entries = 10000
max_offline_ttl_hours = 4
```

## Regla udev para Interceptacion USB

```bash
# /etc/udev/rules.d/99-banexus-intercept.rules
SUBSYSTEM=="usb", ATTR{idVendor}=="<vid>", ATTR{idProduct}=="<pid>", MODE="0660", GROUP="banexus"
```

## Estructura del AuthRequest

```json
{
  "type": "auth_request",
  "node_id": "Ventas-01",
  "input_type": "qr",
  "payload": "sbos://auth/user/uuid-hex",
  "signature": "hmac-sha256-base64",
  "timestamp": "2026-05-27T10:30:00Z",
  "firmware_ver": "1.0.0"
}
```

---

_Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS5-6, V5-SS3, V7-SS3, V7-SS5_
