# Guía del Desarrollador — BosAgent

**Versión:** 1.1
**Fecha:** 2026-05-20 (S-33)
**Audiencia:** Desarrolladores del BOS Agent
**Código base:** 12,379+ líneas Go · 20 paquetes internos

---

## 1. Estructura del Proyecto

```
BosAgent/
├── src/                        ← Código fuente Go
│   ├── cmd/
│   │   ├── bos/main.go         ← Entry point del daemon (1314 líneas)
│   │   ├── bosctl/             ← CLI (un archivo por comando)
│   │   │   ├── main.go         ← Dispatch, WebSocket helpers, OS-layer commands
│   │   │   ├── top.go          ← bosctl top
│   │   │   ├── health_report.go← bosctl health-report
│   │   │   ├── logs.go         ← bosctl logs
│   │   │   ├── identity.go     ← bosctl identity
│   │   │   ├── packages.go     ← bosctl install/remove/upgrade
│   │   │   ├── repair.go       ← bosctl repair
│   │   │   ├── security.go     ← bosctl security
│   │   │   ├── app.go          ← bosctl app (list, history, rollback)
│   │   │   ├── ask.go          ← bosctl ia (diagnose, explain, plan)
│   │   │   └── set.go          ← bosctl set apikey
│   │   └── bosmin/main.go      ← Daemon mínimo para testing
│   │
│   ├── internal/               ← Lógica de negocio
│   │   ├── config/             ← Carga de bos.toml + defaults
│   │   ├── state/              ← State manager: .sbos_state.json
│   │   ├── installer/          ← Saga pattern: compensator + saga engine
│   │   ├── health/             ← Health checker periódico
│   │   ├── reconcile/          ← Drift detection + topological sort
│   │   ├── server/             ← HTTP API + WebSocket server
│   │   ├── plugin/             ← Cargador de manifiestos YAML
│   │   ├── k8s/                ← Cliente Kubernetes
│   │   ├── release/            ← Release manager
│   │   ├── wslib/              ← WebSocket client library
│   │   ├── toml/               ← TOML parser nativo
│   │   ├── security/           ← RBAC + CIS scanner (Fase A)
│   │   ├── repair/             ← OS + K8s repair (Fase B)
│   │   ├── packages/           ← apt/pip/helm unificados (Fase B)
│   │   ├── observability/      ← top + health-report (Fase C)
│   │   ├── catalog/            ← catálogo + snapshots + rollback (Fase D)
│   │   ├── ai/                 ← model router + client + context (Fase D)
│   │   └── watchdog/           ← UnifiedWatchdog 30s (Fase C)
│   │
│   ├── go.mod                  ← Dependencias: zerolog, testify, toml, websocket
│   └── go.sum
│
├── staging/                    ← Entorno de staging
│   ├── bos.toml                ← Config runtime
│   ├── bos.service             ← Unit file systemd
│   └── core/servers/           ← ~112 fichas (manifests + task_catalog.sh)
│
├── context/                    ← Documentación del proyecto
│   ├── MANUAL-SUPERVISOR-BOS-AGENT.md
│   ├── BOS-OS-ELEVATION-PLAN-v3.md
│   ├── plan-desarrollo-bos-elevacion.md
│   ├── BOS-LIFECYCLE-PLAN-v2.md
│   ├── VERIFICACION-COMPLETITUD-FICHAS.md
│   ├── SOLUCIONES-ROOTLESS-K8S.md
│   ├── old/                    ← Documentos históricos
│   └── project/
│       └── developer/
│           └── guia-desarrollador.md  ← Este archivo
│
└── scripts/                    ← Scripts utilitarios
```

---

## 2. Convenciones de Código

### 2.1 Nombrado

- **Archivos:** `snake_case.go` — ej: `health_report.go`, `unified_watchdog.go`
- **Paquetes:** nombre corto en minúsculas — ej: `package watchdog`
- **Estructuras exportadas:** PascalCase — ej: `TopSnapshot`, `HealthReport`
- **Funciones exportadas:** PascalCase — ej: `CollectTopSnapshot()`, `NewManager()`
- **Funciones no exportadas:** camelCase — ej: `collectCPU()`, `autoBootstrap()`

### 2.2 Paquete internal/

Todo paquete en `internal/` sigue el patrón:

```go
// Constructora principal
func NewXxx(cfg *config.Config, ...) (*Xxx, error)

// Métodos principales
func (x *Xxx) Run() error        // inicia goroutine de fondo
func (x *Xxx) Stop()             // detiene limpiamente

// Estructuras de datos al inicio del archivo
type XxxSnapshot struct { ... }
```

### 2.3 Manejo de dependencias

- **Config siempre se inyecta** — nunca variable global
- **State manager es un singleton** dentro del daemon (pasado por referencia)
- **WebSocket** solo en `server/` y `wslib/` — el resto usa interfaces o comandos directos

---

## 3. Cómo Añadir un Comando bosctl

### 3.1 Crear el archivo del comando

```go
// src/cmd/bosctl/mi_comando.go
package main

import (
    "fmt"
    "os"
)

func cmdMiComando(args []string) int {
    // Lógica del comando
    fmt.Println("resultado")
    return 0
}
```

### 3.2 Registrar en el switch de main.go

```go
case "mi-comando":
    os.Exit(cmdMiComando(args))
```

### 3.3 Añadir a usage()

```go
fmt.Fprint(os.Stderr, `...
  bosctl mi-comando           Descripción del comando
...`)
```

---

## 4. Cómo Añadir un Paquete Internal

```go
// src/internal/mipaquete/mipaquete.go
package mipaquete

import "bos/internal/config"

type MiComponente struct {
    cfg   *config.Config
    stopCh chan struct{}
}

func New(cfg *config.Config) *MiComponente {
    return &MiComponente{
        cfg:    cfg,
        stopCh: make(chan struct{}),
    }
}

func (m *MiComponente) Run() {
    ticker := time.NewTicker(time.Duration(m.cfg.Watchdog.IntervalSeconds) * time.Second)
    defer ticker.Stop()
    for {
        select {
        case <-ticker.C:
            // trabajo periódico
        case <-m.stopCh:
            return
        }
    }
}

func (m *MiComponente) Stop() {
    close(m.stopCh)
}
```

### 4.1 Wiring en cmd/bos/main.go

```go
import "bos/internal/mipaquete"

// en runNormal():
miComp := mipaquete.New(cfg)
go miComp.Run()
defer miComp.Stop()
```

---

## 5. Cómo Añadir una Ficha

Cada ficha necesita 3 archivos en `staging/core/servers/<server>/<nombre-ficha>/`:

### 5.1 manifest.yml

```yaml
name: sbos-app-mi-ficha
version: "1.0.0"
order: 200
dependencies:
  - sbos-bootstrap-k8s
deployment_target: container
category: aplicacion
lifecycle:
  install: ficha_install
  uninstall: ficha_uninstall
  health: ficha_health
  repair: ficha_repair
health_check:
  type: kubectl
  resource: deployment/mi-ficha
  namespace: default
```

### 5.2 task_catalog.sh

```bash
#!/bin/bash
FICHA_ID="sbos-app-mi-ficha"

ficha_install() {
    kubectl apply -f "${SBOS_FICHA_DIR}/mi-ficha.k8s.yml"
}

ficha_uninstall() {
    kubectl delete -f "${SBOS_FICHA_DIR}/mi-ficha.k8s.yml" --ignore-not-found
}

ficha_health() {
    kubectl get deployment -n default mi-ficha -o json | jq -r '.status.conditions[] | select(.type=="Available") | .status'
}

ficha_repair() {
    kubectl rollout restart deployment/mi-ficha -n default
}
```

### 5.3 yaml_engine.yml

```yaml
phases:
  install:
    timeout_seconds: 120
    retry: 1
  health:
    timeout_seconds: 30
    retry: 3
```

---

## 6. Flujo de Trabajo

### 6.1 Ciclo diario

```
2. Modificar código en src/
3. Compilar: golang:1.22 container (ver MANUAL §12.1)
5. Verificar: bosctl top + bosctl health-report
6. Si OK: git commit + push
```

### 6.2 Compilación

Go 1.22 NO está instalado en el host. Usar siempre el contenedor:

```bash
S=/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src
mkdir -p /tmp/bos-build
podman run --rm -v "$S:/src:Z" -v /tmp/bos-build:/out:Z -w /src \
  -e CGO_ENABLED=0 golang:1.22 sh -c \
  'go build -o /out/bos ./cmd/bos && go build -o /out/bosctl ./cmd/bosctl'
```

### 6.3 Testing

```bash
# Unit tests
podman run --rm -v "$S:/src:Z" -w /src \
  -e CGO_ENABLED=0 golang:1.22 go test ./internal/... -v

# Desplegar y ejecutar:
```

---

## 7. Patrones Clave del Código

### 7.1 Stop Channel (patrón canónico para goroutines)

```go
type Component struct {
    stopCh chan struct{}
}

func (c *Component) Run() {
    ticker := time.NewTicker(interval)
    defer ticker.Stop()
    for {
        select {
        case <-ticker.C:
            c.work()
        case <-c.stopCh:
            return
        }
    }
}

func (c *Component) Stop() {
    close(c.stopCh)
}
```

### 7.2 WebSocket sobre Unix Socket

```go
// Cliente (bosctl → daemon)
dialer := websocket.Dialer{
    NetDialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
        var d net.Dialer
        return d.DialContext(ctx, "unix", "/run/bos/bos.sock")
    },
}
conn, _, _ := dialer.DialContext(ctx, "ws://unix/ws", nil)
```

### 7.3 State Manager con fcntl flock

```go
// Lectura atómica con lock compartido
func (m *Manager) Read() (*State, error) { ... }

// Escritura atómica: write-to-tmp → fsync → rename → copy-to-bak
func (m *Manager) Write(s *State) error { ... }
```

---

## 8. Fase D — Paquetes Construidos

### 8.1 Catálogo de Apps (`internal/catalog/`)

| Archivo | Propósito |
|---|---|
| `catalog.go` | Listado categorizado de fichas (SO Base, Orquestación, Observabilidad, Apps, Seguridad, IA) |
| `versioning.go` | Snapshots JSON en `/etc/bos/catalog/snapshots/` para historial de versiones |
| `rollback.go` | Rollback inteligente: Estrategia A (apt/pip/helm) y Estrategia B (fichas user-defined vía transición de estado) |

**Comandos CLI:**
- `bosctl app list` — listar todas las fichas agrupadas por categoría
- `bosctl app history <ficha>` — ver historial de snapshots
- `bosctl app rollback <ficha> --to=<version>` — rollback con snapshot pre-vuelta

### 8.2 Agente IA (`internal/ai/`)

| Archivo | Propósito |
|---|---|
| `model_router.go` | Router 3-tier con circuit breaker: Primary (DeepSeek) → Fallback (Claude) → Local |
| `client.go` | HTTP client multi-API: Anthropic Messages, Ollama native, OpenAI-compatible |
| `context_builder.go` | Construcción de contexto 3-capas: state file + recursos (df/free) + K8s nodes |

**Comandos CLI:**
- `bosctl ia <pregunta>` — consulta directa al modelo IA
- `bosctl ia diagnose` — diagnóstico autónomo del sistema
- `bosctl ia explain <ficha>` — explicar una ficha específica
- `bosctl ia plan <objetivo>` — proponer plan de acción paso a paso
- `bosctl ia ls` — listar modelos IA disponibles con estado y aliases

---

## 9. Guía del Agente IA (D4)

### 9.1 Arquitectura de Tiers con Circuit Breaker

```
Tier 1: DeepSeek V4 Pro (primary) ──→ on error/429 ──→ Tier 2
Tier 2: Claude Sonnet (fallback)    ──→ on error/429 ──→ Tier 3
Tier 3: Self-hosted (local) — Ollama o OpenAI-compatible
```

Cada tier que recibe un error 429 entra en **cooldown** (5 min por defecto). Al expirar, el router re-intenta automáticamente el tier superior. El operador puede forzar cualquier tier con `--model=`.

### 9.2 Modos de Uso

```bash
# Consulta directa (usa tier automático según disponibilidad)
bosctl ia "¿está el BOS saludable?"

# Forzar modelo específico
bosctl ia --model=deepseek "¿qué versión de k8s está corriendo?"
bosctl ia --model=claude "explica el estado del clúster"
bosctl ia --model=local "responde OK"

# Diagnóstico autónomo (sin prompt, el sistema arma el contexto)
bosctl ia diagnose

# Explicar una ficha
bosctl ia explain sbos-bootstrap-os

# Plan de acción
bosctl ia plan "migrar todos los pods a node-2"

# Listar modelos disponibles
bosctl ia ls
```

### 9.3 Configuración Cloud (DeepSeek / Claude)

Las API keys se configuran en `/etc/bos/.env` (cargado automáticamente por bosctl):

```bash
# Opción A: vía bosctl set apikey
bosctl set apikey deepseek=sk-7b6ca73dac7e4873a2d891c84b575be7
bosctl set apikey claude=sk-ant-api03-MpDEUBAWe82I0B28mDDND6Fwj...

# Opción B: editar /etc/bos/.env directamente
DEEPSEEK_API_KEY=sk-7b6ca73dac7e4873a2d891c84b575be7
ANTHROPIC_API_KEY=sk-ant-api03-MpDEUBAWe82I0B28mDDND6Fwj...
BOS_AI_PRIMARY_MODEL=deepseek-v4-pro
BOS_AI_FALLBACK_MODEL=claude-sonnet-4-20250514
```

**Variables de entorno cloud:**

| Variable | Default | Descripción |
|---|---|---|
| `DEEPSEEK_API_KEY` | — | API key para DeepSeek (Tier 1) |
| `ANTHROPIC_API_KEY` | — | API key para Anthropic/Claude (Tier 2) |
| `BOS_AI_PRIMARY_MODEL` | `deepseek-v4-pro` | Modelo primary |
| `BOS_AI_FALLBACK_MODEL` | `claude-sonnet-4-20250514` | Modelo fallback |
| `BOS_AI_BASE_URL` | `https://api.deepseek.com/anthropic` | Base URL alternativa para primary |
| `BOS_AI_COOLDOWN_MINUTES` | `5` | Minutos de cooldown tras rate-limit |
| `BOS_AI_TIMEOUT_SECONDS` | `120` | Timeout HTTP por llamada |

### 9.4 Configuración Self-Hosted (Ollama / vLLM / llama.cpp / LocalAI / LiteLLM)

El tier local soporta dos protocolos API, seleccionables con `BOS_AI_LOCAL_TYPE`:

#### Tipo `ollama` (default) — Ollama Native API

```bash
# .env
BOS_AI_LOCAL_TYPE=ollama
BOS_AI_LOCAL_MODEL=qwen3:14b
OLLAMA_HOST=localhost:11434
```

Usa el endpoint nativo `/api/generate` de Ollama. Compatible con cualquier instancia de Ollama.

#### Tipo `openai` — OpenAI-Compatible API

```bash
# .env
BOS_AI_LOCAL_TYPE=openai
BOS_AI_LOCAL_MODEL=mistral-7b
BOS_AI_LOCAL_ENDPOINT=http://192.168.1.100:8080/v1
BOS_AI_LOCAL_API_KEY=optional-token
```

Usa el endpoint `/v1/chat/completions`. Compatible con:

| Servidor | Endpoint típico | Notas |
|---|---|---|
| **vLLM** | `http://host:8000/v1` | Servidor OpenAI-compatible built-in |
| **llama.cpp** | `http://host:8080/v1` | Modo server con `--api` flag |
| **LocalAI** | `http://host:8080/v1` | Drop-in replacement OpenAI |
| **LiteLLM** | `http://host:4000/v1` | Proxy multi-modelo |
| **Ollama** | `http://host:11434/v1` | Ollama también expone endpoint OpenAI-compatible |

**Variables de entorno local:**

| Variable | Default | Descripción |
|---|---|---|
| `BOS_AI_LOCAL_TYPE` | `ollama` | Protocolo: `ollama` o `openai` |
| `BOS_AI_LOCAL_MODEL` | `qwen3:14b` | Nombre del modelo local |
| `BOS_AI_LOCAL_ENDPOINT` | `http://$OLLAMA_HOST` | Endpoint base (sin /v1) |
| `BOS_AI_LOCAL_API_KEY` | — | Token opcional para endpoint local |
| `OLLAMA_HOST` | `localhost:11434` | Host de Ollama (usado solo si type=ollama y no hay endpoint explícito) |

### 9.5 Configuración de API Keys (`bosctl set apikey`)

```bash
# Modelos soportados
bosctl set apikey claude=sk-ant-api03-...
bosctl set apikey deepseek=sk-7b6ca73dac7e4873a2d891c84b575be7
bosctl set apikey openai=sk-...
bosctl set apikey ollama=http://192.168.1.100:11434

# El comando escribe directamente en /etc/bos/.env (modo 0600)
# Las keys son efectivas inmediatamente (sin reiniciar)
```

### 9.6 Flujo Interno del Router

```
bosctl ia "pregunta"
  → godotenv.Load("/etc/bos/.env")     # carga API keys
  → ai.NewClient()                      # crea router desde env vars
  → client.Ask(prompt, ctx, override)
      → for tier in [0,1,2]:
          backend = router.Route()      # resuelve tier activo
          callBackend(backend, ...)     # dispatch por APIType
          if ok: return respuesta
          if rate-limit: router.ReportRateLimit()
      → return "sin conexion o sin tokens disponibles"
```

**Dispatch por tipo de backend:**

| Backend | APIType | Endpoint | Auth Header |
|---|---|---|---|
| DeepSeek | `anthropic` | `/v1/messages` | `x-api-key` |
| Claude | `anthropic` | `/v1/messages` | `x-api-key` + `anthropic-version` |
| Ollama | `ollama` | `/api/generate` | — |
| OpenAI-compatible | `openai` | `/v1/chat/completions` | `Authorization: Bearer <token>` |

### 9.7 Límites y Seguridad

- **Timeout HTTP:** 120s por defecto (configurable con `BOS_AI_TIMEOUT_SECONDS`)
- **Max tokens:** 1024 por respuesta
- **Temperature:** 0.3 (respuestas determinísticas para operaciones)
- **System prompt:** Instruye al modelo a responder en español, proponer comandos `bosctl`, nunca sugerir comandos destructivos
- **Rate limiting:** Solo el error 429 activa el circuit breaker; otros errores (timeout, 500) solo degradan sin bloquear el backend

---

## 10. Referencias

- [MANUAL-SUPERVISOR-BOS-AGENT.md](../MANUAL-SUPERVISOR-BOS-AGENT.md) — Guía operativa completa
- [BOS-OS-ELEVATION-PLAN-v3.md](../BOS-OS-ELEVATION-PLAN-v3.md) — Visión y arquitectura
- `src/cmd/bos/main.go` — Entry point del daemon (referencia de wiring)
- `src/cmd/bosctl/main.go` — Dispatch de comandos CLI
- `staging/bos.toml` — Configuración runtime con defaults
