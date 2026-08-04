# DATOS — SBOS Nexus Host (bhnexus)

## Device Fichas (YAML en disco)

Directorio: `/etc/bos/blibs/bhnexus/devices/`

```yaml
# /etc/bos/blibs/bhnexus/devices/puerta-principal.yml
device:
  id: "AP-PUERTA-01"
  name: "Puerta Principal - Piso de Ventas"
  type: "access_point"
  protocol: "osdp"              # osdp | mqtt | onvif | wiegand | http
  connection: { host: "192.168.1.50", port: 9600 }
  zone: "ZONE-VENTAS"
  actuators:
    - id: "RELAY_01"
      type: "door_lock"
      action_on_grant: "OPEN"
      open_duration_ms: 3000
  health: { check_interval_seconds: 30, check_command: "osdp_poll" }
```

## Ubicacion Fisica en Device Fichas

Cada device declara su ubicacion segun la jerarquia de 11 niveles:

```yaml
device:
  id: "LAPAZ-SUC1-P3-VENTAS-CAJA1-LECTOR01"
  location:
    pais: "BO"
    ciudad: "La Paz"
    sucursal: "Sucursal Central"
    piso: 3
    zona: "Ventas"
    puesto: "Caja-01"
```

## Auth Cache (in-memory)

| Parametro | Valor |
|---|---|
| Estructura | sync.Map (concurrente, sin locks) |
| TTL | 30s (configurable en bhnexus.toml) |
| Capacidad | 100,000 entradas (~15MB RAM) |
| Eviccion | LRU cuando supera capacidad |
| Clave | node_id + input_type + credential_hash |

## Configuracion (bhnexus.toml)

```toml
[server]
websocket_port = 9444
tls_cert = "/etc/bos/tls/bhnexus.crt"
tls_key = "/etc/bos/tls/bhnexus.key"
ca_cert = "/etc/bos/tls/ca.crt"

[auth]
bauth_socket = "/run/bos/bauth.sock"
cache_ttl_seconds = 30
cache_capacity = 100000

[hardware]
devices_path = "/etc/bos/blibs/bhnexus/devices/"
osdp_enabled = true
mqtt_broker = "localhost:1883"
```

## Metricas Prometheus (puerto 9445)

| Metrica | Tipo | Descripcion |
|---|---|---|
| `nexus_agents_connected_total` | Gauge | Agentes actualmente conectados |
| `nexus_auth_requests_total` | Counter | Total de solicitudes de autenticacion |
| `nexus_auth_requests_duration_seconds` | Histogram | Duracion de evaluacion (buckets 1ms-100ms) |
| `nexus_auth_results_granted_total` | Counter | Autenticaciones concedidas |
| `nexus_auth_results_denied_total` | Counter | Autenticaciones denegadas |
| `nexus_auth_cache_hit_ratio` | Gauge | Ratio de aciertos de cache (0.0-1.0) |
| `nexus_hardware_errors_total` | Counter | Errores de comunicacion con hardware |
| `nexus_offline_sessions_seconds` | Gauge | Tiempo acumulado offline por agente |
| `nexus_actuator_commands_total` | Counter | Comandos de actuador ejecutados |

---

_Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS2, SS4, V5-SS1, V7-SS2, V7-SS6_
