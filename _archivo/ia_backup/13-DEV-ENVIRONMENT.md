# Entorno de Desarrollo

**Generado por:** Compositor S-29 (reprocesamiento SBOS)
**Fecha:** 2026-05-18
**Proyecto:** SBOS
**Fuentes:** SBOS-011-DEV-ENV (v6)
**Jerarquia aplicada:** bauth > v6 > v5 > humano

## Desde donde se desarrolla
- **SO del desarrollador:** Windows (Claude Code via SSH) o Ubuntu 24.04 LTS (VPS)
- **IDE principal:** Claude Code (agente IA en terminal), VS Code
- **Terminal:** bash
- **Acceso:** SSH al VPS de desarrollo (144.91.76.130)

## Para donde se desarrolla
- **SO de destino:** Ubuntu Server 24.04 LTS
- **Runtime de contenedores:** Kubernetes (CRI-O, Calico, MetalLB)
- **Daemons soberanos:** systemd nativo en el host

## Compiladores disponibles

| Herramienta | Host | Estrategia |
|---|---|---|
| Python 3.14 | Si, nativo | Host nativo (.venv) |
| Go | No | Contenedor golang:1.22 (podman) |
| Rust / cargo | No | Contenedor rust:1.78 (podman) |
| Node.js | Si, 22.x | Host nativo |
| Java | No | Contenedor maven |

## Stack de contenedores
- **Motor:** Podman rootless exclusivamente
- **Compilacion Go:** `podman run --rm -v "$SRC:/src:Z" -w /src golang:1.22 sh -c "go build ./..."` 
- **Compilacion Rust:** `podman run --rm -v "$SRC:/src:Z" -w /src rust:1.78 sh -c "cargo build --release"`

## Herramientas del host

| Herramienta | Proposito |
|---|---|
| Python 3.14.4 | Lenguaje principal de la fabrica |
| Podman 4.x | Gestion de contenedores (vetado Docker) |
| psql 15+ | Cliente PostgreSQL |
| Git 2.x | Control de versiones |
| Make 4.x | Automatizacion de comandos |
| jq 1.6+ | Procesamiento JSON |
| Claude Code | Interfaz del agente |

## Variables de entorno criticas

| Variable | Proposito |
|---|---|
| ANTHROPIC_API_KEY | API key de Anthropic |
| DEEPSEEK_API_KEY | API key de DeepSeek |
| MODEL_ROUTER_POLICY | Modo del router de modelos (development/production/economic) |
| DAILY_BUDGET_USD | Limite de gasto diario |
| HEALTH_PORT | Puerto del health endpoint (8099) |
| LOG_LEVEL | Nivel de logging |

## Reglas de entorno para el agente
- Usar Podman, nunca Docker
- Autenticacion a BD via ~/.pgpass -- nunca password en URLs
- .venv activado antes de ejecutar comandos Python
- No hardcodear modelos -- usar model_router.py
- Fabrica (fabrica/) y proyectos (desarrollo/sbos/) no se mezclan nunca
