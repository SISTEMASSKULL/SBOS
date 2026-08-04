# README — SBOS Nexus Host (bhnexus)

## Identidad Rapida

| Campo | Valor |
|---|---|
| Daemon | `bhnexus` |
| Servicio | `bhnexus.service` (systemd en host) |
| Lenguaje | Go (alta concurrencia WebSocket) |
| Puerto WebSocket | 9444 (mTLS) |
| Puerto metricas | 9445 (Prometheus) |
| Funcion | Proxy de Hardware Universal |
| Directorio devices | `/etc/bos/blibs/bhnexus/devices/` |
| Max conexiones | 10,000+ agentes concurrentes |

## Dependencias

- **SBOS Auth Enforce (bauth)**: evaluacion BitMask via Unix socket
- **SBOS IAM Installer (bos)**: crea device fichas, recibe health
- **SBOS Nexus Agent (banexus)**: agentes edge conectados via WebSocket mTLS
- **PostgreSQL**: (opcional) registro de eventos de auditoria
- **Hardware**: soporte OSDP, MQTT, ONVIF, Wiegand, USB HID, HTTP

## Comandos basicos

```bash
# Estado del daemon
systemctl status bhnexus

# Ver agentes conectados
curl http://localhost:9445/metrics | grep nexus_agents_connected

# Ver devices registrados
ls /etc/bos/blibs/bhnexus/devices/

# Cache hit ratio
curl http://localhost:9445/metrics | grep nexus_auth_cache_hit_ratio

# Ultimos eventos de autenticacion
journalctl -u bhnexus.service -n 20 | grep "auth_request"
```

## Relaciones con otros daemons

| Daemon | Relacion |
|---|---|
| SBOS Nexus Agent (banexus) | WebSocket mTLS -> broker central de todos los agentes |
| SBOS Auth Enforce (bauth) | Evalua BitMask via Unix socket (directo) |
| SBOS IAM Installer (bos) | Crea device fichas, recibe health |
| SBOS Data Kernel (bkernel) | Lee audit_events desde WAL |
| SBOS Data RAG (bsearch) | Indexa eventos de autenticacion para busqueda |

---

_Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS1-4, V5-SS1, V7-SS1, V7-SS7_
