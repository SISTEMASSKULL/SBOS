# CLAUDE.md — BosAgent (SBOS IAM Installer)

## Idioma — INMUTABLE
**Español obligatorio.** Todo comentario, log, error y comunicación debe estar en español.

## Identidad del módulo

**BosAgent** es el daemon `bos` — SBOS IAM Installer, Infrastructure Provisioning & Lifecycle Orchestrator.
Es el plano de control soberano del SBOS (día 0/1/2).

- **Binario:** Go 1.25+ estático (`CGO_ENABLED=0`), ~12 MB
- **Servicio:** `bos.service` (systemd, user=bosagent, root capabilities)
- **Socket:** `/run/bos/bos.sock` (SBOS-050 P9 — sin HTTP entre daemons)
- **TCP:** `0.0.0.0:9443` (HTTPS/TLS 1.3 — Kong + readiness probes)

## Directorio de trabajo

```
BosAgent/
└── src/                        ← raíz Go (go.mod: module bos)
    ├── cmd/bos/                ← daemon main + runNormal + config_pending
    ├── cmd/bosctl/             ← CLI cliente (WebSocket RPC)
    ├── internal/
    │   ├── audit/              ← audit.Log — /var/log/bos/audit.log
    │   ├── bauth/              ← cliente JSON-RPC hacia bAuth daemon
    │   ├── biaos/              ← cliente IA (Anthropic/DeepSeek/Ollama)
    │   ├── bootstrap/          ← verificación C-01..C-08
    │   ├── context/            ← bosctx.Service — Context Plane (SBOS-049)
    │   ├── domain/             ← servicios de dominio puros (sin protocolo)
    │   ├── ficha/              ← parser manifest.yml + gRPC + capabilities
    │   ├── health/             ← health checker
    │   ├── installer/          ← sagas install/update/repair/remove
    │   ├── k8s/                ← ÚNICO dispatcher kubectl (Principio P1)
    │   ├── observer/           ← observer loop DAG topológico
    │   ├── paths/              ← constantes de rutas del sistema
    │   ├── plugin/             ← loader de fichas desde servers/
    │   ├── query/              ← fuentes de consulta (ubuntu, k8s, semáforo)
    │   ├── reconcile/          ← drift detection
    │   ├── repair/             ← repair manager
    │   ├── scaler/             ← escalado automático de fichas
    │   ├── security/           ← RBAC (FileRBAC + BauthRBAC)
    │   ├── server/             ← API WebSocket RPC + JSON-RPC 2.0
    │   ├── state/              ← manager .sbos_state.json (fcntl.flock)
    │   ├── system/             ← syscall helpers
    │   ├── tui/                ← Terminal UI (Bubble Tea)
    │   └── watchdog/           ← watchdog daemon + release rollback
    └── servers/                ← 22 fichas declarativas (manifest.yml + task_catalog.sh)
```

## Comandos esenciales

```bash
# Compilar (desde src/)
CGO_ENABLED=0 /home/skull/sdk/go/bin/go build ./...

# Tests con race detector (obligatorio antes de commit)
/home/skull/sdk/go/bin/go test -race -count=2 ./...

# Formato
/home/skull/sdk/go/bin/gofmt -l .

# Vet
/home/skull/sdk/go/bin/go vet ./...
```

## Principios de diseño (P1-P14)

| # | Principio | Descripción |
|---|-----------|-------------|
| P1 | K8s dispatch único | Toda operación kubectl DEBE pasar por `internal/k8s.Core` |
| P2 | Interface Dual (ADR-020) | WebSocket RPC (Vía 1) + JSON-RPC 2.0 (Vía 2) en mismo Unix socket |
| P3 | Domain separation | `domain/` nunca importa `server/`; server importa domain |
| P4 | Fail-close auth | `validSharedToken` retorna false si token ausente |
| P5 | Zero Trust | pg_hba solo IP específica, listen_addresses vinculado, TLS 1.3 |
| P6 | Sin credenciales hardcodeadas | Siempre env vars (PG_AUX_PASSWORD, BAUTH_SOCKET, etc.) |
| P7 | ctx_id obligatorio | Toda operación incluye ctx_id (SBOS-049, ISO 27001 A.8.15) |
| P8 | State manager único | Solo `state.Manager` escribe .sbos_state.json (fcntl.flock) |
| P9 | Sin HTTP entre daemons | Solo Unix socket o WebSocket (SBOS-050 P9) |
| P10 | Dry-run antes de Apply | Toda operación kubectl apply va precedida de --dry-run |
| P11 | Ports catalog | Puertos de SBOS-050; verificar antes de asignar |
| P12 | Fichas declarativas | Dependencias del SO via manifest.yml, no install.sh |
| P13 | Sin intervención manual | BOS provee todo; humano solo aprueba HITL |
| P14 | Sagas con compensación | Install/Update/Repair/Remove con rollback explícito |

## Convenciones de código

- **Nombres en español** para mensajes, logs y comentarios explicativos
- **Un átomo = un commit** semántico: `[FX.Y] tipo: descripcion`
- **Build verde en cada commit** — si se rompe: `git revert HEAD`
- **Sin mock de BD en tests** — usar interfaces (PgAuxK8sPort, StatePort, etc.)
- **Archivos ≤ 200 líneas** — dividir si se excede (DOC-SBOS-001 N3)
- **JSON-RPC naming:** `bos.<modulo>.<operacion>` (bos.ctx.create, bos.ficha.install, etc.)

## Variables de entorno relevantes

| Variable | Uso |
|----------|-----|
| `BOS_NO_RPC_TOKEN=true` | Modo dev — omite verificación de token RPC |
| `BOS_DOMAIN` | Dominio base SBOS (default: `sbos.app`) |
| `PG_AUX_PASSWORD` | Password del pod PG auxiliar (requerida en Start) |
| `BOS_PG_AUX_POD` | Override nombre del pod PG auxiliar |
| `BOS_PG_AUX_NS` | Override namespace del pod PG auxiliar |
| `BOS_PG_AUX_IMAGE` | Override imagen del pod PG auxiliar |
| `BAUTH_SOCKET` | Override socket de bAuth (default: `/run/bos/bauth.sock`) |
| `BOS_AI_TIMEOUT_SECONDS` | Timeout del cliente IA en segundos |
| `BOS_PG_DSN` | DSN PostgreSQL para Context Plane |

## Interface Dual (ADR-019/020)

Todo feature nuevo sigue este patrón sin excepción:

```
domain/<servicio>.go     ← lógica pura (sin protocolo)
server/jsonrpc.go        ← handler JSON-RPC (bos.<modulo>.<op>)
cmd/bosctl/<cmd>.go      ← comando CLI (WebSocket RPC)
```

**Sin JSON-RPC, el feature NO EXISTE** para biedata, bAuth ni agentes IA.

## Rutas canónicas

| Recurso | Ruta |
|---------|------|
| State file | `/etc/bos/.sbos_state.json` (`paths.StatePath`) |
| Audit log | `/var/log/bos/audit.log` (`paths.AuditLog`) |
| RBAC roles | `/etc/bos/rbac/roles.json` (`paths.RBACRoles`) |
| bos.toml | `/etc/bos/bos.toml` (`paths.BosToml`) |
| bos-install.toml | `/etc/bos/bos-install.toml` (`paths.BosInstallToml`) |
| TLS cert | `/etc/bos/tls/bos.crt` (`paths.CertFile`) |
| TLS key | `/etc/bos/tls/bos.key` (`paths.KeyFile`) |
| Fichas | `/etc/bos/servers/` |

## Documentación normativa

**Raíz documental:** `/opt/skull/orquestador/proyectos/SBOS/context/`

| Ruta | Contenido |
|------|-----------|
| `BOS_V8/BOS_V8_SBOS-018-DAEMON-BOS.md` | Especificación completa del daemon bos |
| `BOS_V8/BOS_V8_SBOS-050-PORT-CATALOG.md` | Catálogo de puertos (norma irrenunciable) |
| `BOS_V8/BOS_V8_SBOS-049-CONTEXT-PLANE.md` | Plano de contexto distribuido |
| `daemons/bos/SBOS-BOOTSTRAP-MANUAL.md` | Manual de bootstrap 6 capas |
| `daemons/bos/plandeaccion/` | Plan de reparación del daemon (Plan Maestro v3, REGISTRO-ESTADO, informes) |
| `daemons/bos/plandeaccion/INFORME-AUDITORIA-BOSAGENT-*.md` | Informe de auditoría técnica (referencia de fases activas) |
| `context/contracts/BOS-BAUTH-CONTRATOS.md` | Contratos de integración BOS ↔ bAuth |
