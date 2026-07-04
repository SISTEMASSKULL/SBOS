# cmd/bosctl — CLI del daemon bos

`bosctl` es la herramienta de administración humana del daemon `bos`.
Habla con el daemon por el Unix socket `/run/bos/bos.sock` mediante las dos
vías de la Interface Dual (ADR-019): WebSocket RPC para los comandos
interactivos y JSON-RPC 2.0 vía `bosctl rpc`.

## Compilar

```bash
cd BosAgent/src
export PATH=$PATH:/home/skull/go-dist/go/bin
go build -o bin/bosctl ./cmd/bosctl
```

## Variables de entorno

| Variable | Propósito |
|---|---|
| `BOS_SOCKET` | Path al socket Unix (default `/run/bos/bos.sock`) |
| `BOS_USER` | Identidad para RBAC (vacío = caller confiable del grupo bosagent) |
| `BOS_RPC_TOKEN` | Token para métodos JSON-RPC destructivos (F6.1) |
| `BOS_RPC_TOKEN_FILE` | Ruta alternativa al archivo de token (default `/etc/bos/rpc-token`) |
| `KUBECONFIG` | Lo resuelve `ResolveKubeconfig()` — no hace falta exportarlo (F4.1) |

## Subcomandos

### Bootstrap (Day 0)

```bash
bosctl bootstrap start          # inicia el bootstrap completo (6 capas)
bosctl bootstrap status         # progreso de fichas del bootstrap
bosctl bootstrap verify         # certificación C-01..C-08
bosctl bootstrap resume         # reanuda un bootstrap interrumpido
bosctl bootstrap reset          # reinicia el estado del bootstrap
bosctl install                  # instalador TUI interactivo (wizard 15 pantallas)
bosctl setup                    # configuración inicial guiada
```

### Ciclo de vida del daemon y fichas (Day 1)

```bash
bosctl status                   # estado del daemon y las fichas
bosctl release                  # consulta el SKULL Release Plane (pull-only)
bosctl remove <ficha>           # desinstala una ficha
bosctl upgrade <ficha>          # actualiza una ficha
bosctl repair <ficha>           # repara una ficha degradada
bosctl shutdown                 # apagado ordenado del daemon
bosctl logs                     # logs del daemon
bosctl reload                   # recarga configuración
bosctl health                   # health check global
```

### Observabilidad (Day 2)

```bash
bosctl top                      # vista tipo top de fichas y recursos
bosctl health-report            # reporte de salud multi-capa (SO/K8s/fichas)
```

### Identidad y seguridad

```bash
bosctl identity whoami|users|roles
bosctl identity set-role <usuario> <admin|operator|readonly>
bosctl identity revoke <usuario>
bosctl security scan            # escaneo CIS (Ubuntu + K8s)
bosctl security audit           # auditoría de seguridad
```

### Catálogo de aplicaciones

```bash
bosctl app list                 # fichas registradas
bosctl app history <ficha>      # historial de versiones
bosctl app rollback <ficha>     # rollback a la versión anterior
```

### Context Plane (SBOS-049)

```bash
bosctl ctx list --tenant=skull  # sesiones activas del tenant
bosctl ctx get <ctx_id>         # detalle de una sesión
bosctl ctx invalidate <ctx_id>  # revoca una sesión (logout administrativo)
bosctl ctx stats                # métricas del Context Plane
```

### JSON-RPC 2.0 directo (Vía 2 — scripts y diagnóstico)

```bash
bosctl rpc system.listMethods                 # catálogo vivo de métodos
bosctl rpc bos.ficha.status '{"ficha_id":"postgresql"}'
bosctl rpc bos.query.system                   # saga: Ubuntu+K8s+fichas+ctx (<4s)
bosctl rpc bos.query.repair '{"ficha_id":"nextcloud","tenant_id":"skull"}'
bosctl rpc bos.query.vdi '{"tenant_id":"skull"}'
bosctl rpc --help                             # catálogo completo con auth
```

Los métodos destructivos (`install/update/repair/remove`, `saga.execute`,
`bootstrap.start`, `ctx.invalidate`, `tenant.suspend`) exigen token (F6.1):
se toma de `BOS_RPC_TOKEN` o `/etc/bos/rpc-token` automáticamente.

### Agente IA y configuración

```bash
bosctl ask "¿por qué está degradado nextcloud?"   # alias: bosctl ia
bosctl set apikey <modelo>=<key>
```

### Capa OS (reemplazan sudo — auditados con ctx_id)

```bash
bosctl exec <comando>           # ejecuta como root vía daemon (auditado)
bosctl ls|cat|tail <ruta>       # lectura de archivos del sistema
bosctl systemctl <args>         # systemctl vía daemon
bosctl journalctl <args>        # journalctl vía daemon
```

## Códigos de salida

| Código | Significado |
|---|---|
| 0 | Éxito |
| 1 | Error de la operación (el daemon respondió con error) |
| 2 | Uso incorrecto (argumentos inválidos) |
| 6 | Daemon no disponible (socket no responde) |
