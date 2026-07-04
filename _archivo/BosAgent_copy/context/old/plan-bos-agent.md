# Plan — bos-agent · IAM Installer + Core UI
## Planner: Claude · Proyecto SBOS · Fase C.2b · 2026-05-12

---

## 1. Alcance

Construir el **IAM Installer** (`bos.service`), el daemon PID 1 del SBOS. Es un sistema políglota con 4 componentes:

| # | Componente | Lenguaje | Tipo | Estimación |
|---|---|---|---|---|
| C1 | **bos** — daemon binario | Go 1.22+ | systemd service | ~800 líneas |
| C2 | **bosctl** — CLI administrativa | Go 1.22+ | binario CLI | ~400 líneas |
| C3 | **Core SP-01** — 4 archivos Bash | Bash 5.x | scripts OS | ~600 líneas |
| C4 | **Core UI** — interfaz administrativa | Dart/Flutter | web + desktop | ~1,500 líneas |

## 2. Arquitectura de Componentes

### C1 — bos (daemon Go)

```
bos (binario Go, systemd)
├── cmd/bos/main.go          # entrada: flags, config, signal handlers
├── internal/
│   ├── server/              # HTTP :9443 + WebSocket
│   │   ├── api.go           # REST endpoints: /health, /status, /fichas
│   │   └── ws.go            # WebSocket para Core UI (eventos)
│   ├── installer/           # Saga orchestrator
│   │   ├── saga.go          # Install/Update/Repair/Uninstall sagas
│   │   └── compensator.go   # Rollback compensation chain
│   ├── state/               # STATE_MANAGER (único escritor)
│   │   └── manager.go       # fcntl flock, transiciones atómicas
│   ├── k8s/                 # sbos_k8s_core() — único kubectl apply
│   │   └── core.go          # Wrapper kubectl con --dry-run previo
│   ├── health/              # HEALTH_CHECKER (cada 30s)
│   │   └── checker.go       # Pollea fichas, clasifica estado
│   ├── reconcile/           # RECONCILE_SCHEDULER (cada 300s)
│   │   └── scheduler.go     # Compara estado declarado vs actual
│   ├── release/             # RELEASE_MANAGER (pull-only)
│   │   └── manager.go       # HTTP GET al SKULL Release Plane
│   ├── plugin/              # PLUGIN_LOADER
│   │   └── loader.go        # Escanea servers/, hashes SHA-256
│   └── config/
│       └── config.go        # bos.toml parsing (BurntSushi/toml)
├── go.mod
├── go.sum
└── Makefile
```

**CI gates Go:** gofmt → golangci-lint → go vet → go test -race (>=80%) → go build -ldflags='-s -w'

### C2 — bosctl (CLI Go)

```
bosctl/
├── cmd/bosctl/main.go       # entrada: subcomandos install/update/repair/remove/status/probe
├── internal/
│   ├── client/              # Cliente HTTP al Unix socket /run/bos/bos.sock
│   └── output/              # Formateo de salida (tabla, JSON, YAML)
├── go.mod
└── Makefile
```

### C3 — Core SP-01 (4 Bash)

```
/opt/bos/core/
├── 00_MASTER_INSTALL_SBOS.sh    # Entry point: comando + ficha_id
├── 00_TASK_CATALOG_SBOS.sh      # Funciones genéricas (nunca nombra apps)
├── 00_YAML_ENGINE_SBOS.sh       # Intérprete declarativo vía yq
└── 00_ARCHITECTURE_SBOS.yml     # Mapeo nombre_tarea → función_bash
```

**14 principios a validar:** P1 (único kubectl apply), P2 (pre_install ABORT), P3 (sin nombres de apps), P4 (Core no crece), P5 (pull-only), P6 (auto-rollback), P7 (Absorber/Ejecutar/Liberar), P8 (STATE_MANAGER único escritor), P9 (idempotencia), P10 (--dry-run previo), P11 (diagnosis_first), P12 (compensación), P13 (timeouts), P14 (verificación post-op).

### C4 — Core UI (Flutter)

```
core_ui/
├── lib/
│   ├── main.dart               # Entry point
│   ├── app.dart                 # MaterialApp + router
│   ├── screens/
│   │   ├── dashboard.dart       # Health overview
│   │   ├── fichas_list.dart     # Ficha catalog
│   │   ├── ficha_detail.dart    # Install/update/repair/remove
│   │   ├── operations_log.dart  # bos_operation_log viewer
│   │   └── settings.dart        # bos.toml editor
│   ├── services/
│   │   ├── api_client.dart      # REST client to :9443
│   │   └── ws_client.dart       # WebSocket for live events
│   ├── models/
│   │   ├── ficha.dart           # Ficha data model
│   │   └── operation.dart       # Operation log model
│   └── widgets/
│       ├── health_card.dart     # Ficha health status card
│       └── progress_bar.dart    # Saga progress indicator
├── pubspec.yaml
└── test/
```

**CI gates Dart:** dart format → flutter analyze → flutter test (>=70%)

## 3. Criterios de Aceptación (Gate)

1. **Bootstrap:** `bos.service` arranca y ejecuta `bosctl install` 3 veces consecutivas sin error
2. **Health check:** HEALTH_CHECKER reporta estado de 10+ fichas
3. **Saga install:** Una ficha instalada con compensación funcional
4. **Saga repair:** diagnosis_first → repair → verificación
5. **CI gates Go:** gofmt clean, golangci-lint 0 issues, go test -race >=80%
6. **CI gates Bash:** shellcheck 0 issues en los 4 scripts
7. **CI gates Flutter:** flutter analyze clean, flutter test >=70%
8. **14 principios:** validate_sp01.py EXIT 0

## 4. Orden de Construcción

```
Semana 1: C1 (bos daemon Go) — estado, health, config
Semana 2: C3 (Core SP-01 Bash) — scripts maestros
Semana 3: C2 (bosctl CLI Go) — cliente administrativo
Semana 4: C4 (Core UI Flutter) — interfaz gráfica
```

## 5. Dependencias

- Biblioteca-SBOS: DDL bos_db (operativo ✅)
- Orquesta-Core-SBOS: motor PGE (operativo ✅)
- infra-agent: K8s disponible (pendiente — construir en paralelo)

## Fuentes

SBOS-018-DAEMON-BOS.md (completo), bos-agent.yml (manifest), partitura-maestra.md §2.3
