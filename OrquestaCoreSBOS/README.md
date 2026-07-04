# OrquestaCoreSBOS
**Proyecto:** SBOS — Sovereign Business Operating System
**Árbol:** 26a83fa0-d71c-476b-b52c-4cb14bdd2929
**Nodo SKDATA:** Orquesta-Core-SBOS
**Perfil:** nativo
**Materializado:** 2026-05-12
**Construido:** 2026-05-12 — Sesión S-11

## Módulos

| Archivo | Descripción | Líneas |
|---|---|---|
| `src/sbos_build_config.py` | Configuración: 11 agentes, orden, CI gates por lenguaje, MAX_ITER | 180 |
| `src/ci_gates.py` | Validadores de CI gates para 8 lenguajes (Rust/Go/Java/Python/Bash/Dart/YAML/SQL) | 190 |
| `src/build_state.py` | Rastreador de estado de construcción con sync SKDATA | 190 |
| `src/orquesta_core_sbos.py` | Coordinador CLI: status, next, validate, agents, config | 95 |
| `src/__init__.py` | Package init | 3 |

**Total:** 658 líneas Python

## Stack Poliglota Soportado

| Lenguaje | CI Gates | Usado por |
|---|---|---|
| Rust | fmt → clippy → check → test → audit → build | bkernel-agent |
| Go | gofmt → golangci-lint → vet → test -race → build | bos-agent, bauth-agent, bintelligence-agent, bnexus-agent |
| Java | spotless → checkstyle → test → package | bauth-agent (5 Keycloak SPIs) |
| Python | ruff format → ruff check → mypy → pytest | Compositor-SBOS, Bibliotecario-SBOS, Orquesta-Core-SBOS |
| Bash | shellcheck | infra-agent (scripts) |
| Dart | dart format → flutter analyze → flutter test | bos-agent (Core UI) |
| YAML | yamllint | infra-agent, Observabilidad-SBOS |
| SQL | sqlfluff | Biblioteca-SBOS |

## Uso

```bash
cd /opt/skull/orquestador/proyectos/desarrollo/sbos/OrquestaCoreSBOS
python3 src/orquesta_core_sbos.py status     # Progreso global
python3 src/orquesta_core_sbos.py next       # Próximo agente a construir
python3 src/orquesta_core_sbos.py validate 5 # CI gates para bos-agent
python3 src/orquesta_core_sbos.py agents     # Lista de agentes
python3 src/orquesta_core_sbos.py config     # Configuración general
```
