# sbos-stub-daemon

Stub mínimo para simular presencia de daemons SBOS en el servidor.
Responde a JSON-RPC 2.0 sobre Unix socket (HTTP).

## Uso

```bash
CGO_ENABLED=0 go build -o sbos-stub-daemon .

# Para bkernel:
DAEMON_NAME=bkernel DAEMON_SOCKET=/run/bos/bkernel.sock ./sbos-stub-daemon

# Para bhnexus:
DAEMON_NAME=bhnexus DAEMON_SOCKET=/run/bos/bhnexus.sock ./sbos-stub-daemon
```

## Variables de entorno

| Variable | Default | Descripción |
|----------|---------|-------------|
| `DAEMON_NAME` | `stub` | Nombre del daemon simulado |
| `DAEMON_SOCKET` | `/run/bos/stub.sock` | Ruta del Unix socket |
| `DAEMON_VERSION` | `0.1.0-stub` | Versión reportada en health check |

## Respuesta JSON-RPC

```json
{"jsonrpc":"2.0","result":{"daemon":"bkernel","version":"1.0.0-stub","status":"ok","mode":"stub"},"id":1}
```

Reemplazar por el daemon real cuando esté disponible.
