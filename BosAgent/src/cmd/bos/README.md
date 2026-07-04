# cmd/bos — Daemon del SBOS IAM Installer

`bos` es el **plano de control soberano del SBOS**: daemon residente
(systemd) que transforma un Ubuntu virgen en un cluster K8s con el stack
completo (Day 0), administra las fichas en operación (Day 1) y reconcilia
drift multi-capa (Day 2). Especificación: SBOS-018-DAEMON-BOS.

## Compilar

```bash
cd BosAgent/src
export PATH=$PATH:/home/skull/go-dist/go/bin   # Go 1.25+
CGO_ENABLED=0 go build -o bin/bos ./cmd/bos    # binario estático
```

## Ejecutar

```bash
# Producción (systemd — unidad bos.service, user bosagent):
sudo systemctl start bos

# Manual con config explícita:
bos -config /etc/bos/bos.toml

# Desarrollo sin root (sockets en ruta alternativa):
BOS_DEV_SKIP_ROOT=1 BOS_DEV_RUN_PATH=/tmp/bos-dev ./bin/bos
```

## Flags

| Flag | Default | Descripción |
|---|---|---|
| `-config` | `/etc/bos/bos.toml` | Ruta del archivo de configuración TOML |

## Variables de entorno

| Variable | Propósito |
|---|---|
| `BOS_ROOT_USER` / `BOS_ROOT_PASSWORD` | Credencial inicial del bootstrap. La contraseña se lee una sola vez y se elimina del entorno (`os.Unsetenv`) — nunca se registra en logs |
| `BOS_TENANT_ID` / `BOS_TENANT_NAME` / `BOS_TENANT_DOMAIN` | Identidad del tenant durante el bootstrap |
| `BOS_HOST_IP` | IP del host para la red del cluster |
| `BOS_CGROUP_PATH` | Override de la ruta cgroup (entornos contenedorizados) |
| `BOS_DEV_SKIP_ROOT=1` | Modo desarrollo: omite verificación de root |
| `BOS_DEV_RUN_PATH` | Ruta alternativa para sockets en desarrollo |
| `NOTIFY_SOCKET` / `WATCHDOG_USEC` | Inyectadas por systemd — sd_notify y watchdog (P12) |

Las variables de bootstrap también se cargan desde `bos-bootstrap.env`
(orden de búsqueda: `/etc/bos/`, `/etc/bos/core/`, `/opt/bos/`,
`/opt/bos/core/`, `/tmp/`, `./`).

## Modos de operación

| Modo | Cuándo | Comportamiento |
|---|---|---|
| **Normal** (`runNormal`) | `bos.toml` existe | API completa: WebSocket (Vía 1) + JSON-RPC 2.0 (Vía 2) sobre `/run/bos/bos.sock` y TCP `:9443`; observer loop; reconcile scheduler; watchdog systemd |
| **Config-pending** (`runConfigPending`) | falta `bos-install.toml` | Solo acepta `install_config` por WebSocket hasta recibir la configuración |

## Interface Dual (ADR-019/ADR-020)

Mismo Unix socket `/run/bos/bos.sock` (0660, grupo `bosagent`), dos vías:

- **Vía 1 — WebSocket RPC** (`/ws`): `bosctl`, Core UI (humanos).
- **Vía 2 — JSON-RPC 2.0** (`/rpc`): biedata, bkernel, bauth, bsearch,
  agentes IA. Métodos `bos.<modulo>.<operacion>` — catálogo vivo en
  `system.listMethods`. Métodos destructivos requieren `Authorization`
  (F6.1); plazos por categoría 5s/30s/600s (F6.2); sagas de consulta
  `bos.query.*` (F6.6–F6.11).

## Arquitectura interna

`main.go` (118 líneas) solo orquesta; la lógica vive en `internal/`:
`observer` (loop de fichas), `reconcile` (drift), `installer` (sagas con
compensación), `state` (STATE_MANAGER, único escritor de
`.sbos_state.json`), `server` (transporte dual), `context` (Context Plane
SBOS-049), `query` (sagas de consulta F6), `bootstrap` (criterios C-01..C-08),
`audit` (ISO 27001 A.8.15), `system` (sd_notify/watchdog).

## Señales y ciclo de vida

- `SIGTERM`/`SIGINT` → shutdown ordenado (servers + observer + scheduler).
- Watchdog systemd: `WATCHDOG=1` cada `WATCHDOG_USEC/2` (ver
  `internal/system`).
- Logs: zerolog a stderr + archivo; auditoría en el audit log con ctx_id.
