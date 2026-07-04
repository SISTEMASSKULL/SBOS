# Repositorios de Codigo

**Generado por:** Compositor S-29 (reprocesamiento SBOS)
**Fecha:** 2026-05-18
**Proyecto:** SBOS
**Fuentes:** SBOS-009-REPOS (v6)
**Jerarquia aplicada:** bauth > v6 > v5 > humano

## Mapa de repositorios

| Repo | Organizacion | Lenguajes | Componente |
|---|---|---|---|
| sbos | github.com/SISTEMASSKULL/sbos | Bash, Python, Go, Rust, Dart, YAML | Monorepo principal SBOS |
| skproject-factory | github.com/SISTEMASSKULL/skproject-factory | Python, SQL, YAML | Fabrica ORQUESTA |
| skproject-observabilidad | github.com/SISTEMASSKULL/skproject-observabilidad | YAML (Grafana/Loki/Alloy) | Observabilidad |

## Estructura del Monorepo SBOS

```
/opt/bos/
├── bos                    ← binario Go estatico (CGO_ENABLED=0)
└── bosctl                 ← CLI Go para administracion local

/etc/bos/
├── bos.toml               ← configuracion del daemon
├── .sbos_state.json       ← estado persistente (solo STATE_MANAGER.py escribe)
├── *.jsonl                ← eventos para replay WebSocket
└── blibs/
    ├── core/              ← 4 archivos maestros Bash
    │   ├── 00_MASTER_INSTALL_SBOS.sh
    │   ├── 00_TASK_CATALOG_SBOS.sh
    │   ├── 00_YAML_ENGINE_SBOS.sh
    │   └── 00_ARCHITECTURE_SBOS.yml
    └── servers/           ← fichas del catalogo (por servidor logico)
        ├── hostserver/    → sbos-bootstrap-os/
        ├── dataserver/    → postgresql/
        ├── identityserver/
        ├── gatewayserver/
        └── ... (16 servidores logicos)
```

Desarrollo local en `/opt/sbos-dev/` (staging/testbench).

## Estrategia de Ramas -- Trunk-Based Development (TBD)

Rama unica: `main` -- siempre deployable, siempre verde. Pull Requests cortos. GitFlow vetado.

## Estructura de daemons (codigo real)

| Daemon | Lenguaje | Archivos | Estado |
|---|---|---|---|
| BosAgent | Go | 22 | en-construccion |
| BauthAgent | Go | 27 | en-construccion |
| BintelligenceAgent | Go | 8 | en-construccion |
| BnexusAgent | Go | 10 | en-construccion |
| BkernelAgent | Rust | 0 | en-concepcion |
| InfraAgent | YAML | 8 | en-concepcion |
| BstyleAgent | -- | 0 | en-concepcion |

## Convenciones de codigo
- Commits: Conventional Commits (feat:, fix:, chore:, docs:)
- Go: gofmt -s, golangci-lint, go vet, CGO_ENABLED=0 en produccion
- Rust: #![deny(unsafe_code)], clippy --deny warnings
- CI/CD: GitHub Actions con path filters por directorio
