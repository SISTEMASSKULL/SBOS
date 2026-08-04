# OPERACION — SBOS Nexus Host (bhnexus)

## SLOs

| Operacion | SLO | Notas |
|---|---|---|
| Auth cache hit | < 5ms | Desde que llega auth_request hasta respuesta |
| Auth cache miss + bauth | < 15ms | Incluye consulta Unix socket a bauth |
| Flujo completo auth | ~15ms | Objetivo < 50ms desde QR a apertura |
| Desconexion detectada | < 30s | Ping/Pong cada 15s |
| Policy update push | < 500ms | Desde cambio RolTemplate hasta notificacion |
| Health check dispositivo | Segun intervalo | Configurable por device (default 30s) |

## Monitoreo

### Metricas Prometheus (puerto 9445)

| Metrica | Tipo | Descripcion |
|---|---|---|
| `nexus_agents_connected_total` | Gauge | Agentes actualmente conectados |
| `nexus_auth_requests_total` | Counter | Total de solicitudes de autenticacion |
| `nexus_auth_requests_duration_seconds` | Histogram | Duracion de evaluacion |
| `nexus_auth_results_granted_total` | Counter | Autenticaciones concedidas |
| `nexus_auth_results_denied_total` | Counter | Autenticaciones denegadas |
| `nexus_auth_cache_hit_ratio` | Gauge | Ratio de aciertos de cache |
| `nexus_hardware_errors_total` | Counter | Errores de comunicacion con hardware |
| `nexus_offline_sessions_seconds` | Gauge | Tiempo acumulado offline por agente |
| `nexus_actuator_commands_total` | Counter | Comandos de actuador ejecutados |

## Runbooks

### Verificar Estado de Agentes Conectados

```bash
# Agentes conectados
curl -s http://localhost:9445/metrics | grep nexus_agents_connected

# Ultimas conexiones/desconexiones
journalctl -u bhnexus.service -n 30 | grep -E "agent connected|agent disconnected|agent terminated"

# Cache hit ratio
curl -s http://localhost:9445/metrics | grep nexus_auth_cache_hit_ratio
```

### Diagnosticar Fallo de Hardware

```bash
# Verificar health de dispositivos
journalctl -u bhnexus.service -n 50 | grep -E "hardware_error|health_check"

# Verificar dispositivo especifico
cat /etc/bos/blibs/bhnexus/devices/puerta-principal.yml

# Probar comunicacion OSDP
osdp_poll --device /dev/ttyUSB0 --baud 9600

# Ver dispositivo desconectado
curl -s http://localhost:9445/metrics | grep nexus_hardware_errors_total
```

### Recovery ante Cache Corruption

```bash
# Cache se auto-gestiona via TTL (30s)
# No requiere intervencion manual

# Si se necesita reiniciar cache inmediatamente:
systemctl restart bhnexus

# Verificar que los agentes reconectan
journalctl -u bhnexus.service -n 20 | grep "agent connected"

# Verificar hit ratio post-reinicio
curl -s http://localhost:9445/metrics | grep nexus_auth_cache_hit_ratio
```

### Verificacion de Salud

```bash
# Health check del daemon
systemctl status bhnexus

# Verificar puerto WebSocket
ss -tlnp | grep 9444

# Verificar puerto metricas
curl -s http://localhost:9445/metrics | head -5

# Verificar conexion a bauth
ls -la /run/bos/bauth.sock

# Ver agentes conectados
curl -s http://localhost:9445/metrics | grep nexus_agents_connected
```

---

_Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS1-4, V5-SS1, V7-SS5-6_
