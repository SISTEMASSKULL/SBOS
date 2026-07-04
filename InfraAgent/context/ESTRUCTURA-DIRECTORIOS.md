# ESTRUCTURA DE DIRECTORIOS — Fábrica ORQUESTA
**Fecha de creación:** 2026-07-01
**Estado:** BORRADOR — pendiente de revisión y aprobación

---

## Principio rector

**Cada agente es soberano de su contexto.**
Todo lo que pertenece a un agente vive dentro de su propio directorio.
Ningún agente busca su documentación fuera de su carpeta.

---

## Nivel 1 — La Fábrica

```
DESORGANIZADO

fabrica/
├── CLAUDE.md                            ← 15 líneas: reglas universales + puntero a doctrina
│
├── context-fabrica/                     ← conocimiento transversal — nadie lo duplica
│   ├── doctrina/                        ← ORQUESTA-XXX: arquitectura, ADRs globales,
│   │   ├── ORQUESTA-000-INDEX.md        │  protocolos entre agentes, stack tecnológico
│   │   ├── ORQUESTA-001-VISION.md       │  Solo el Bibliotecario escribe aquí
│   │   ├── ORQUESTA-002-ARCH.md         │
│   │   └── ...                          ← (47 documentos ORQUESTA)
│   ├── protocolos/                      ← protocolos operativos entre agentes
│   ├── plantillas/                      ← plantillas de documentos reutilizables
│   └── _legado/                         ← doctrina obsoleta — solo consulta histórica
│
├── .claude/                             ← configuración de Claude Code para toda la fábrica
│   ├── settings.json                    ← hooks SessionStart/Stop + servidores MCP (un solo archivo)
│   ├── agents/                          ← identidad técnica de cada agente
│   │   ├── bibliotecario.md             │  Qué tools tiene, qué modelo usa, descripción breve Bibliotecario de la
│   │   ├── bauth-developer.md           │  NO contiene doctrina — solo la ficha técnica del agente
│   │   ├── bkernel-developer.md         │
│   │   ├── bos-developer.md             │
│   │   ├── coordinador.md               │
│   │   └── ...                          ← (17 agentes)
│   └── skills/                          ← protocolos de operación invocables
│       ├── orquesta-coordinador/        │  Cada skill es un protocolo paso a paso
│       ├── orquesta-bibliotecario/      │  para una operación específica
│       └── ...                          ← (5 skills actuales)
│
├── scripts/                             ← scripts operativos de la fábrica
│   └── agente_enviar.sh                 ← función de comunicación entre agentes (C-m garantizado)
│
└── proyectos/                           ← un subdirectorio por proyecto activo
    └── desarrollo/
        └── sbos/                        ← proyecto SBOS (ver Nivel 2)
```

DESORGANIZADO

fabrica/
├── CLAUDE.md                            ← 15 líneas: reglas universales + puntero a doctrina
│
├── context-fabrica/                     ← conocimiento transversal — nadie lo duplica
│   ├── doctrina/                        ← ORQUESTA-XXX: arquitectura, ADRs globales,
│   │   ├── ORQUESTA-000-INDEX.md        │  protocolos entre agentes, stack tecnológico
│   │   ├── ORQUESTA-001-VISION.md       │  Solo el Bibliotecario escribe aquí
│   │   ├── ORQUESTA-002-ARCH.md         │
│   │   └── ...                          ← (47 documentos ORQUESTA)
│   ├── protocolos/                      ← protocolos operativos entre agentes
│   ├── plantillas/                      ← plantillas de documentos reutilizables
│   └── _legado/                         ← doctrina obsoleta — solo consulta histórica
│
├── .claude/                             ← configuración de Claude Code para toda la fábrica
│   ├── settings.json                    ← hooks SessionStart/Stop + servidores MCP (un solo archivo)
│   ├── agents/                          ← identidad técnica de cada agente
│   │   ├── bibliotecario.md             │  Qué tools tiene, qué modelo usa, descripción breve Bibliotecario de la FABRICA
│   │   ├── coordinador.md               │  Coordinador de Agentes provee contexto resuelve dudas transmite informacion de uno a otro agente etc.
│   │   └── ...                          ← (17 agentes)
│   └── skills/                          ← protocolos de operación invocables
│       ├── orquesta-coordinador/        │  Cada skill es un protocolo paso a paso
│       ├── orquesta-bibliotecario/      │  para una operación específica
│       └── ...                          ← (5 skills actuales)
│
├── scripts/                             ← scripts operativos de la fábrica
│   └── agente_enviar.sh                 ← función de comunicación entre agentes (C-m garantizado)
│
└── proyectos/                           ← un subdirectorio por proyecto activo
    └── SBOS/                            ← proyecto 1 SBOS (ver Nivel 2)
    └── PROYECTO "2"/                    ← Otro proyecto 
    └── PROYECTO "N"/                    ← Otro proyecto N   
```


**Qué vive aquí y por qué:**

| Directorio | Quién escribe | Quién lee | Propósito |
|---|---|---|---|
| `CLAUDE.md` | Humano / Bibliotecario | Todos los agentes al arrancar | Reglas universales — máximo 15 líneas |
| `context-fabrica/doctrina/` | Solo el Bibliotecario | Cualquier agente bajo demanda | Conocimiento transversal del ecosistema |
| `.claude/agents/` | Humano / Bibliotecario | Claude Code al instanciar el agente | Ficha técnica: tools, modelo, descripción |
| `.claude/skills/` | Humano / Bibliotecario | El agente cuando invoca la skill | Protocolos de operación paso a paso |
| `.claude/settings.json` | Humano / Bibliotecario | Claude Code en cada sesión | Hooks automáticos + servidores MCP |

---

## Nivel 2 — El proyecto SBOS

```
DESORGANIZADO

/opt/skull/orquestador/proyectos/desarrollo/sbos/
│
├── CLAUDE.md                            ← 10 líneas: puntero al coordinador SBOS + reglas SBOS
│
├── InfraAgent/                          ← Bibliotecario
├── BauthAgent/                          ← daemon bAuth
├── BkernelAgent/                        ← daemon bKernel
├── BiedataAgent/                        ← daemon biedata
├── BintelligenceAgent/                  ← daemon bSearch
├── BosAgent/                            ← IAM Installer BOS  (ver Nivel 3)
├── BnexusAgent/                         ← daemon bNexus
├── BnotifyAgent/                        ← daemon bNotify
│
├── context/                             ← contexto transversal del proyecto SBOS
│   └── sbos/Procesar/humano/
│       ├── BOS_V8/                      ← 51 documentos normativos (fuente de verdad del SBOS)
│       └── daemons/                     ← docs conceptuales por daemon
│
└── backups/                             ← backups organizados por servidor lógico
    ├── S01/postgresql/
    ├── S03/keycloak/
    └── ...
```

ORGANIZADO

/opt/skull/orquestador/proyectos/SBOS/
│
├── CLAUDE.md                            ← 10 líneas: puntero al coordinador SBOS + reglas SBOS
│
├── InfraAgent/                          ← Bibliotecario del SBOS
├── BauthAgent/                          ← daemon bAuth
├── BkernelAgent/                        ← daemon bKernel
├── BiedataAgent/                        ← daemon biedata
├── BintelligenceAgent/                  ← daemon bSearch
├── BosAgent/                            ← IAM Installer BOS  (ver Nivel 3)
├── BnexusAgent/                         ← daemon bNexus
├── BnotifyAgent/                        ← daemon bNotify
│
├── context/                             ← contexto transversal del proyecto SBOS
│                                        ← 51 documentos normativos (fuente de verdad del SBOS)
│                                          Docuemntacion Compltea del proyecto Especificaciones Globales 
└── backups/                             ← backups organizados por servidor lógico
    ├── BauthAgent/
    ├── BkernelAgent/
    └── ...
```
/opt/skull/orquestador/proyectos/Proyecto "N"/
│
├── CLAUDE.md                            ← 10 líneas: puntero al coordinador SBOS + reglas SBOS
│
├── InfraAgent/                          ← Bibliotecario del Proyecto "N"
├── Subproycto1Agent/                    ← daemon Subproycto1
├── Subproycto2Agent/                    ← daemon Subproycto2
├── Subproycto...Agent/                  ← daemon Subproycto...
├── SubproyctoNAgent/                    ← daemon SubproyctoN
│
├── context/                             ← contexto transversal del proyecto SBOS
│                                        ← 51 documentos normativos (fuente de verdad del SBOS)
│                                          Docuemntacion Compltea del proyecto Especificaciones Globales 
└── backups/                             ← backups organizados por servidor lógico
    ├── Subproycto1Agent/
    ├── Subproycto2Agent/
    └── ...
```
---

## Nivel 3 — BosAgent (estado real actual)

```
BosAgent/
│
├── CLAUDE.md                            ← identidad del agente bOS
│
├── context/                             ← contexto del agente (hoy desorganizado)
│   ├── old/                             ← archivos antiguos sin criterio claro de archivo
│   └── project/
│       └── developer/                   ← bitácora del developer (incompleta)
│
├── retroalimentacion/                   ← feedback acumulado de sesiones
│
├── scripts/                             ← scripts operativos de bOS
│
├── src/                                 ← código fuente Go
│   ├── bin/                             ← binarios compilados
│   ├── cmd/                             ← puntos de entrada de los ejecutables
│   │   ├── bos/                         ← daemon principal
│   │   ├── bosctl/                      ← CLI de administración
│   │   ├── bosmin/                      ← interfaz mínima
│   │   ├── ctrltest/                    ← herramienta de pruebas de control
│   │   ├── firetest/                    ← herramienta de pruebas de red
│   │   ├── firetest-httpd/
│   │   ├── health-integration-test/
│   │   └── reconcile-integration-test/
│   ├── core/                            ← lógica central compartida
│   ├── core_ui/                         ← UI Flutter del panel de administración
│   │   └── lib/
│   │       ├── models/
│   │       ├── screens/
│   │       │   ├── audit/
│   │       │   ├── catalog/
│   │       │   ├── dashboard/
│   │       │   ├── growth/
│   │       │   ├── identity/
│   │       │   └── progress/
│   │       ├── services/
│   │       └── widgets/
│   ├── deploy/
│   │   └── rbac/
│   ├── docs/                            ← docs dentro de src (no deberían estar aquí)
│   │   ├── biaos/sagas/
│   │   └── ci/
│   ├── internal/                        ← paquetes internos Go
│   │   ├── audit/
│   │   ├── bauth/
│   │   ├── biaos/
│   │   │   ├── ai/
│   │   │   ├── audit/
│   │   │   ├── icap/
│   │   │   └── sagas/
│   │   ├── bootstrap/
│   │   ├── boslog/
│   │   ├── capacity/
│   │   ├── catalog/
│   │   ├── cgroup/
│   │   ├── config/
│   │   ├── context/
│   │   ├── domain/
│   │   ├── ficha/
│   │   │   └── grpc/
│   │   ├── health/
│   │   ├── installer/
│   │   ├── k8s/
│   │   ├── keycloak/
│   │   ├── maintenance/
│   │   ├── metrics/
│   │   ├── network/
│   │   ├── observability/
│   │   ├── observer/
│   │   ├── packages/
│   │   ├── paths/
│   │   ├── plugin/
│   │   ├── query/
│   │   ├── reconcile/
│   │   ├── release/
│   │   ├── repair/
│   │   ├── scaler/
│   │   ├── security/
│   │   ├── server/
│   │   ├── state/
│   │   ├── system/
│   │   ├── toml/
│   │   ├── tui/                         ← TUI (terminal UI) del daemon
│   │   │   ├── app/
│   │   │   ├── assets/
│   │   │   ├── components/
│   │   │   │   ├── button/
│   │   │   │   ├── floating/
│   │   │   │   ├── focus/
│   │   │   │   ├── panel/
│   │   │   │   └── spacer/
│   │   │   ├── ctrl/
│   │   │   │   ├── dash/
│   │   │   │   ├── data/
│   │   │   │   ├── k8s/
│   │   │   │   ├── panel/
│   │   │   │   ├── sistema/
│   │   │   │   ├── views/
│   │   │   │   └── widgets/
│   │   │   ├── demo/
│   │   │   ├── model/
│   │   │   ├── observer/
│   │   │   ├── screens/
│   │   │   ├── styles/
│   │   │   ├── tuilog/
│   │   │   └── util/
│   │   ├── watchdog/
│   │   └── wslib/
│   ├── proto/
│   │   └── bos/ficha/v1/               ← definiciones protobuf
│   ├── scripts/
│   └── servers/                         ← fichas declarativas YAML por servidor
│       ├── S-HOST/                      ← servidor host (bootstrap, CNI, K8s, etc.)
│       │   ├── bos-preflight/resources/
│       │   ├── sbos-bkernel/resources/
│       │   ├── sbos-bootstrap-cni/resources/
│       │   ├── sbos-bootstrap-hard/resources/
│       │   ├── sbos-bootstrap-k8s/resources/
│       │   ├── sbos-bootstrap-monitoring/resources/
│       │   ├── sbos-bootstrap-os/resources/
│       │   ├── sbos-bootstrap-storage/resources/
│       │   └── sbos-namespace/resources/
│       ├── S01/                         ← dataserver (PostgreSQL, Redis, MinIO, Tryton)
│       │   ├── minio/resources/
│       │   ├── postgresql/resources/
│       │   ├── redis/resources/
│       │   └── tryton/resources/
│       ├── S02/                         ← gatewayserver (Kong, Vault, NGINX, Besu)
│       │   ├── besu-qbft/resources/
│       │   ├── certbot/resources/
│       │   ├── kong/resources/
│       │   ├── nginx/resources/
│       │   ├── oauth2-proxy/resources/
│       │   └── vault/resources/
│       ├── S03/                         ← identityserver (Keycloak, Kyverno, Linkerd)
│       │   ├── keycloak/resources/
│       │   ├── kyverno/resources/
│       │   └── linkerd/resources/
│       ├── S06/                         ← appsserver (notifier, Mattermost, etc.)
│       │   ├── calcom/resources/
│       │   ├── ferretdb/resources/
│       │   ├── mattermost/resources/
│       │   ├── novu/resources/
│       │   └── sbos-notifier/resources/
│       ├── S10/mattermost/
│       └── S12/                         ← monitorserver (Grafana, Prometheus, Alloy)
│           ├── alertmanager/resources/
│           ├── alloy/resources/
│           ├── grafana/resources/
│           └── prometheus/resources/
│
├── staging/                             ← entorno de staging del instalador
│   ├── containers/
│   │   ├── sbos-build-rust/
│   │   └── sbos-k8s/
│   ├── core/
│   │   ├── docs/
│   │   └── servers/                     ← fichas de staging (espejo ampliado de src/servers/)
│   ├── run/
│   └── state/
│
├── _legacy/                             ← código legado archivado (dentro de src/)
│   ├── 2026-06-09_F0.7_ai/
│   ├── 2026-06-09_F0.7_observability/
│   └── 2026-06-09_F0.7_repair/
│
└── tests/                               ← tests de integración
```

### Problemas detectados en BosAgent (estado actual vs estructura objetivo)

| Problema actual | Ubicación | Debe ir en |
|---|---|---|
| Docs dentro de `src/docs/` | `src/docs/biaos/`, `src/docs/ci/` | `context/` |
| `context/old/` sin criterio | `context/old/` | `context/_archivo/` |
| `retroalimentacion/` fuera de `context/` | `retroalimentacion/` | `context/_archivo/retroalimentacion/` |
| Sin `context/DOCTRINA.md` | — | Crear |
| Sin `context/ESTADO.md` | — | Crear (reemplaza los docs dispersos) |
| `src/_legacy/` dentro de código fuente | `src/_legacy/` | `context/_archivo/legacy/` o eliminar |

**Qué vive en cada archivo y por qué:**

| Archivo | Quién lo escribe | Con qué frecuencia cambia | Contenido |
|---|---|---|---|
| `CLAUDE.md` | Humano / Bibliotecario | Rara vez | 20 líneas: identidad + puntero a SKDATA + 3 reglas |
| `context/DOCTRINA.md` | Humano / Bibliotecario | Solo cuando cambia el diseño | Propósito, responsabilidades, límites del agente |
| `context/ESTADO.md` | El agente mismo | Cada sesión | Qué está hecho, qué falta, qué está en curso |
| `context/ADR/` | Humano + agente | Al tomar decisiones | Decisiones irrevocables con su justificación |
| `context/_archivo/` | El agente mismo | Al cerrar bloques | Historial — nunca se borra, solo se mueve aquí |

---

## Regla del CLAUDE.md

El `CLAUDE.md` de cada agente tiene **máximo 20 líneas** y solo contiene:

```markdown
# <Nombre del agente>

## Quién soy
<1 línea: mi rol en el ecosistema>

## Mi código
<ruta exacta de src/>

## Al iniciar sesión — leer esto primero
psql 'postgresql://root@localhost:5402/SKDATA' -t -A -c \
  "SELECT donde_quede, que_falta FROM perfiles.bitacora_agente WHERE agente_id='<id>'"

## Mis reglas (3 máximo)
1. <regla crítica 1>
2. <regla crítica 2>
3. <regla crítica 3>

## Doctrina completa
context/DOCTRINA.md
```

Todo lo demás va en `context/DOCTRINA.md` o se consulta bajo demanda en SKDATA.

---

## Lo que NO se hace

| Prohibido | Por qué |
|---|---|
| Documentación de un agente fuera de `<AgentDir>/context/` | El agente no sabe dónde buscar lo suyo |
| `REGISTRO-ESTADO.md` con historial acumulado de 1000+ líneas | Se archiva en `_archivo/`, el activo en `ESTADO.md` |
| Copias de documentación (`BosAgent copy/`, `plandeaccion copy/`) | Genera ambigüedad sobre cuál es la fuente de verdad |
| Dos carpetas `context/` para la misma fábrica (`context/` y `context-fabrica/`) | Un solo lugar por nivel |
| CLAUDE.md que carga automáticamente documentos completos | Solo punteros — el agente lee lo que necesita |

---

## Mapa de agentes actuales y su ruta canónica

| Agente | Directorio | `context/DOCTRINA.md` existe hoy |
|---|---|---|
| Bibliotecario (biblio) | `InfraAgent/` | No — disperso en 4 rutas |
| bAuth developer | `BauthAgent/` | No — disperso en 4 rutas |
| bKernel developer | `BkernelAgent/` | No |
| biedata developer | `BiedataAgent/` | No |
| bSearch developer | `BintelligenceAgent/` | No |
| bOS developer | `BosAgent/` | No |
| bNexus developer | `BnexusAgent/` | No |

---

## Registro de estado

| Tarea | Estado | Notas |
|---|---|---|
| Definir estructura (este documento) | EN REVISIÓN | |
| Formalizar en `.claude/agents/*.md` | PENDIENTE | |
| Formalizar en `.claude/skills/` | PENDIENTE | |
| Formalizar en `.claude/settings.json` | PENDIENTE | |
| Crear `context/DOCTRINA.md` por agente | PENDIENTE | El humano reorganiza manualmente |
| Reducir CLAUDE.md a 20 líneas por agente | PENDIENTE | |

---

## Árbol completo — Estado real actual (para reorganizar)

```
/opt/skull/orquestador/
│
├── proyectos/
│   │
│   ├── fabrica/                                     ← FÁBRICA ORQUESTA
│   │   ├── CLAUDE.md                                ← doctrina universal de la fábrica
│   │   ├── PROYECTO-ESTADO.md
│   │   │
│   │   ├── .claude/
│   │   │   ├── settings.local.json
│   │   │   ├── agents/                              ← 17 definiciones de agentes
│   │   │   │   ├── bauth-developer.md
│   │   │   │   ├── bkernel-developer.md
│   │   │   │   ├── bos-developer.md
│   │   │   │   ├── biedata-developer.md
│   │   │   │   ├── bintelligence-developer.md
│   │   │   │   ├── bnexus-developer.md
│   │   │   │   ├── bibliotecario.md
│   │   │   │   ├── coordinador.md
│   │   │   │   ├── compositor.md
│   │   │   │   ├── documentador.md
│   │   │   │   ├── operador.md
│   │   │   │   ├── sbos-coordinador.md
│   │   │   │   ├── sbos-operador.md
│   │   │   │   └── ...
│   │   │   └── skills/
│   │   │       ├── orquesta-bibliotecario/
│   │   │       ├── orquesta-compositor/
│   │   │       ├── orquesta-coordinador/
│   │   │       ├── orquesta-planificador/
│   │   │       └── sbos-staging-security-monitor/
│   │   │
│   │   ├── context-fabrica/                         ← doctrina transversal de la fábrica
│   │   │   ├── doctrina/                            ← ORQUESTA-000 … ORQUESTA-047
│   │   │   │   ├── _legado/
│   │   │   │   └── json-RPC/
│   │   │   ├── aprendizajes-fabrica/
│   │   │   │   ├── auditorias/
│   │   │   │   └── por-proyecto/
│   │   │   ├── ontologias-meta/
│   │   │   ├── plantillas/
│   │   │   ├── procesos/
│   │   │   ├── protocolos/
│   │   │   └── sistema-documentacion/
│   │   │
│   │   ├── context/                                 ⚠️ DUPLICADO — coexiste con context-fabrica/
│   │   │   ├── arbol/
│   │   │   │   ├── artefactos-pge/
│   │   │   │   ├── manifests/
│   │   │   │   ├── ontologias/
│   │   │   │   └── propuestas-skill/
│   │   │   ├── humano/mejora-continua/
│   │   │   ├── ia/
│   │   │   ├── ontologias/
│   │   │   ├── resources/
│   │   │   │   ├── ddl/
│   │   │   │   └── normas/
│   │   │   └── sintetizado/
│   │   │
│   │   ├── bibliotecario-agent/                     ← código Python del Bibliotecario
│   │   │   ├── bibliotecario/
│   │   │   ├── logs/
│   │   │   ├── output/
│   │   │   ├── src/
│   │   │   └── tests/
│   │   │
│   │   ├── compositor-agent/                        ← código Python del Compositor
│   │   │   ├── .claude/
│   │   │   ├── bin/
│   │   │   ├── logs/
│   │   │   ├── observabilidad/
│   │   │   ├── orquesta/
│   │   │   │   ├── coordinador/
│   │   │   │   ├── core/
│   │   │   │   ├── db/
│   │   │   │   ├── eval/
│   │   │   │   ├── schemas/
│   │   │   │   ├── security/
│   │   │   │   ├── testing/
│   │   │   │   └── tools/templates/
│   │   │   ├── output/sbos-compilado/
│   │   │   ├── src/
│   │   │   ├── tests/casos/
│   │   │   └── trazas/
│   │   │
│   │   ├── schemas/
│   │   ├── scripts/sql/
│   │   └── trazas/checkpoints/
│   │
│   └── desarrollo/
│       └── sbos/                                    ← PROYECTO SBOS
│           ├── CLAUDE.md
│           │
│           ├── context/                             ⚠️ DUPLICADO de Procesar/
│           │   ├── .checkpoints/
│           │   ├── arbol/
│           │   ├── ia/                              ← 18 docs de contexto IA
│           │   ├── ia_backup/                       ⚠️ backup sin limpiar
│           │   └── sbos/Procesar/humano/
│           │       ├── BOS_V8/                      ← 51 docs normativos
│           │       └── daemons/                     ← docs conceptuales por daemon
│           │
│           ├── Procesar/                            ⚠️ DUPLICADO de context/sbos/Procesar/
│           │   └── humano/daemons/
│           │       ├── bauth/plandeaccion/
│           │       ├── bkernel/plandeaccion/
│           │       ├── bos/
│           │       │   ├── plandeaccion/
│           │       │   └── plandeaccion copy/       ⚠️ COPIA sin limpiar
│           │       └── ...
│           │
│           ├── backups/                             ← backups por servidor lógico
│           │   ├── S-HOST/ … S15/
│           │
│           ├── cache/                               ⚠️ propósito poco claro
│           ├── out/                                 ⚠️ artefactos Solidity sin contexto
│           ├── scripts/
│           ├── staging/core/
│           │
│           ├── BosAgent/                            ← IAM Installer (Go 1.22+)
│           │   ├── CLAUDE.md
│           │   ├── context/
│           │   │   ├── old/                         ⚠️ sin criterio de archivo
│           │   │   └── project/developer/
│           │   ├── retroalimentacion/               ⚠️ fuera de context/
│           │   ├── scripts/
│           │   ├── src/
│           │   │   ├── bin/
│           │   │   ├── cmd/
│           │   │   │   ├── bos/
│           │   │   │   ├── bosctl/
│           │   │   │   ├── bosmin/
│           │   │   │   └── ...tests/
│           │   │   ├── core/
│           │   │   ├── core_ui/lib/
│           │   │   │   ├── models/
│           │   │   │   ├── screens/
│           │   │   │   ├── services/
│           │   │   │   └── widgets/
│           │   │   ├── deploy/rbac/
│           │   │   ├── docs/                        ⚠️ docs dentro de src/
│           │   │   ├── internal/
│           │   │   │   ├── audit/ bootstrap/ catalog/
│           │   │   │   ├── ficha/ health/ installer/
│           │   │   │   ├── k8s/ keycloak/ repair/
│           │   │   │   ├── tui/
│           │   │   │   │   ├── app/ assets/ components/
│           │   │   │   │   ├── ctrl/ model/ screens/
│           │   │   │   │   └── styles/
│           │   │   │   └── ...
│           │   │   ├── proto/bos/ficha/v1/
│           │   │   ├── scripts/
│           │   │   └── servers/
│           │   │       ├── S-HOST/ S01/ S02/ S03/
│           │   │       ├── S06/ S10/ S12/
│           │   │   ├── _legacy/                     ⚠️ legado dentro de src/
│           │   │   └── _snapshots/                  ⚠️ snapshots dentro de src/
│           │   ├── staging/
│           │   │   ├── containers/
│           │   │   ├── core/servers/                ← fichas de staging (espejo)
│           │   │   ├── run/
│           │   │   └── state/
│           │   └── tests/
│           │
│           ├── BosAgent copy/                       ⚠️ COPIA LITERAL sin limpiar
│           │
│           ├── BauthAgent/                          ← daemon bAuth (Rust 1.85+)
│           │   ├── CLAUDE.md                        ⚠️ NO existe — doctrina dispersa
│           │   ├── context/                         ⚠️ VACÍO
│           │   ├── retroalimentacion/               ⚠️ fuera de context/
│           │   ├── benches/
│           │   ├── contracts/
│           │   │   ├── out/AuditAnchor.sol/
│           │   │   └── out/SettlementEngine.sol/
│           │   ├── db/
│           │   │   ├── backups/
│           │   │   ├── data_files/
│           │   │   ├── migrations/
│           │   │   └── seeds/
│           │   ├── proto/
│           │   ├── servers/S12/blockchain/
│           │   ├── src/
│           │   │   ├── audit/ bitmask/ blockchain/
│           │   │   ├── catalog/ config/ context/
│           │   │   ├── db/ engine/ public/ saga/
│           │   │   ├── sdk/ server/handlers/
│           │   │   ├── spi/src/ sync/ util/
│           │   │   ├── bAuthDEV/                    ← tool de desarrollo Flutter
│           │   │   ├── desktop/                     ← UI desktop Flutter
│           │   │   └── domain/
│           │   │       ├── auth_methods/
│           │   │       ├── password/ policy/ sod/
│           │   └── tests/
│           │
│           ├── BkernelAgent/                        ← daemon bKernel (Rust 1.85+)
│           │   ├── context/                         ⚠️ VACÍO
│           │   ├── retroalimentacion/               ⚠️ fuera de context/
│           │   ├── examples/
│           │   ├── fixtures/fichas/
│           │   ├── src/
│           │   │   ├── cdc/ cluster/ config/
│           │   │   ├── engine/ grpc/ rules/core/
│           │   │   ├── server/ specs/ state/
│           │   │   ├── systemd/ writers/
│           │   │   └── tests/integration/
│           │   └── tests/
│           │
│           ├── BiedataAgent/                        ← daemon biedata (Rust 1.85+)
│           │   └── src/                             ⚠️ sin context/ ni retroalimentacion/
│           │
│           ├── BintelligenceAgent/                  ← daemon bSearch (Go 1.22+)
│           │   ├── context/                         ⚠️ VACÍO
│           │   ├── retroalimentacion/               ⚠️ fuera de context/
│           │   ├── src/
│           │   │   ├── bin/ configs/ systemd/
│           │   │   ├── cmd/
│           │   │   │   ├── bcompass/ bintelligence/
│           │   │   │   ├── bintelligenctl/ bsearch/
│           │   │   └── internal/
│           │   │       ├── compass/ config/ database/
│           │   │       ├── models/ search/ server/
│           │   └── tests/
│           │
│           ├── BnexusAgent/                         ← daemon bNexus (Go 1.22+)
│           │   ├── context/                         ⚠️ VACÍO
│           │   ├── retroalimentacion/               ⚠️ fuera de context/
│           │   ├── src/
│           │   │   ├── bin/
│           │   │   ├── cmd/banexus/ cmd/bhnexus/
│           │   │   └── internal/
│           │   │       ├── bauth/ cache/ client/
│           │   │       ├── config/ device/ models/
│           │   │       ├── server/ ws/
│           │   └── tests/
│           │
│           ├── BnotifyAgent/                        ← daemon bNotify (en desarrollo)
│           │   └── src/
│           │
│           ├── InfraAgent/                          ← Bibliotecario SBOS
│           │   ├── CLAUDE.md
│           │   ├── context/                         ← aquí estamos trabajando
│           │   │   ├── ESTRUCTURA-DIRECTORIOS.md    ← este archivo
│           │   │   ├── PLAN-REESTRUCTURACION-FABRICA.md
│           │   │   └── PLAN-IMPLEMENTACION-AGENTES-IA.md
│           │   ├── retroalimentacion/               ⚠️ fuera de context/
│           │   ├── src/servers/                     ← fichas de infraestructura
│           │   │   ├── kyverno/ linkerd/ minio/
│           │   │   ├── postgresql/ redis/ vault/
│           │   │   ├── sbos-bootstrap-hardening/
│           │   │   ├── sbos-bootstrap-k8s/
│           │   │   ├── sbos-bootstrap-os/
│           │   │   ├── sbos-bootstrap-platform/
│           │   │   └── sbos-k8s-network-validator/
│           │   └── tests/
│           │
│           ├── BcmsAgent/                           ← CMS (en desarrollo)
│           │   └── src/
│           │
│           ├── BpayAgent/                           ← Smart Pay (en desarrollo)
│           │   └── src/
│           │
│           ├── BrateAgent/                          ← Smart Rates (en desarrollo)
│           │   └── src/
│           │
│           ├── BtaxAgent/                           ← Smart Tax (en desarrollo)
│           │   └── src/
│           │
│           ├── bkernel-common/                      ← librería compartida bKernel
│           │   └── src/
│           │
│           ├── bnotify/                             ⚠️ DUPLICADO de BnotifyAgent/?
│           │
│           ├── BibliotecaSBOS/                      ⚠️ propósito solapado con InfraAgent
│           │   ├── context/
│           │   ├── retroalimentacion/
│           │   ├── src/
│           │   └── tests/
│           │
│           ├── BibliotecarioSBOS/                   ⚠️ propósito solapado con InfraAgent
│           │   ├── context/
│           │   ├── retroalimentacion/
│           │   ├── src/
│           │   └── tests/
│           │
│           ├── CompositorSBOS/
│           │   ├── context/
│           │   ├── retroalimentacion/
│           │   ├── src/
│           │   └── tests/
│           │
│           ├── ObservabilidadSBOS/
│           │   ├── context/
│           │   ├── retroalimentacion/
│           │   ├── src/
│           │   └── tests/
│           │
│           └── OrquestaCoreSBOS/
│               ├── context/
│               ├── retroalimentacion/
│               ├── src/
│               └── tests/
│
├── backups/
├── datos/
├── observabilidad/
└── platform/
```

### Leyenda

| Símbolo | Significado |
|---|---|
| ⚠️ | Problema detectado — requiere decisión o limpieza |
| (vacío) | Sin problemas detectados en esta carpeta |

### Problemas globales detectados en el árbol

| # | Problema | Afecta |
|---|---|---|
| 1 | `context/` VACÍO en casi todos los daemons | BauthAgent, BkernelAgent, BintelligenceAgent, BnexusAgent |
| 2 | `retroalimentacion/` fuera de `context/` en todos los agentes | Todos |
| 3 | `context/` duplicado — raíz sbos + `context/sbos/Procesar/` | sbos/ raíz |
| 4 | `Procesar/` duplicado en raíz de sbos | sbos/ raíz |
| 5 | `BosAgent copy/` y `plandeaccion copy/` sin limpiar | BosAgent, Procesar/bos/ |
| 6 | `bnotify/` duplicado de `BnotifyAgent/` | sbos/ raíz |
| 7 | `BibliotecaSBOS/` y `BibliotecarioSBOS/` solapan con `InfraAgent/` | sbos/ raíz |
| 8 | `src/docs/` dentro del código fuente de BosAgent | BosAgent/src/ |
| 9 | `src/_legacy/` y `src/_snapshots/` dentro del código fuente | BosAgent/src/ |
| 10 | `context-fabrica/` y `context/` coexisten en fabrica/ | fabrica/ |
| 11 | `ia_backup/` sin limpiar | sbos/context/ |
| 12 | Sin `DOCTRINA.md` ni `ESTADO.md` en ningún agente | Todos |
```

---
*Documento vivo — corregir aquí antes de formalizar en la configuración*


## Árbol completo — REOGANIZADO

```
/opt/skull/orquestador/
│
├── proyectos/
│   │
│   ├── fabrica/                                     ← FÁBRICA ORQUESTA
│   │   ├── CLAUDE.md                                ← doctrina universal de la fábrica
│   │   ├── PROYECTO-ESTADO.md
│   │   │
│   │   ├── .claude/
│   │   │   ├── settings.local.json
│   │   │   ├── agents/                              ← 17 definiciones de agentes
│   │   │   │   ├── bauth-developer.md
│   │   │   │   ├── bkernel-developer.md
│   │   │   │   ├── bos-developer.md
│   │   │   │   ├── biedata-developer.md
│   │   │   │   ├── bintelligence-developer.md
│   │   │   │   ├── bnexus-developer.md
│   │   │   │   ├── bibliotecario.md
│   │   │   │   ├── coordinador.md
│   │   │   │   ├── compositor.md
│   │   │   │   ├── documentador.md
│   │   │   │   ├── operador.md
│   │   │   │   ├── sbos-coordinador.md
│   │   │   │   ├── sbos-operador.md
│   │   │   │   └── ...
│   │   │   └── skills/
│   │   │       ├── orquesta-bibliotecario/                         ← razon de la exitencia del bibliotecario
│   │   │       ├── orquesta-compositor/                         ← razon de la exitencia del compositot
│   │   │       ├── orquesta-coordinador/                         ← razon de la exitencia del coordinador
│   │   │       ├── orquesta-planificador/                         ← razon de la exitencia del palnificador
│   │   │       ├── orquesta-documentador/                         ← razon de la exitencia del documenttar
│   │   │       ├── orquesta-revisor/                         ← razon de la exitencia del revisor
│   │   │       └── orquesta-testeador/                         ← razon de la exitencia del testeador
│   │   │
│   │   ├── context-fabrica/                         ← doctrina transversal de la fábrica
│   │   │   ├── doctrina/                            ← ORQUESTA-000 … ORQUESTA-047
│   │   │   │   ├── _legado/
│   │   │   │   └── json-RPC/                        ← este tipo de carpetas que e usuario agregue y el bibliote cario los encuentre deber formalizarlos ya hacer que todos los agentes lo conzcna en este caso todos los agentres de todos los proyectos deben saber que deben programara utilizando RPC como norma de la fabrica, y asi se inegraran dcouemntacion de doctrinas, en este momento nigun agente lo conoce
│   │   │   ├── aprendizajes-fabrica/
│   │   │   │   ├── auditorias/                     ← Aqui el bibliotecario deberia hacer auditorias contsantes es ir corrigiendo el comportamiento de la fabrica deebria elaborara propuestas de reparacion o crecimento para qeu el usurio los apruebe en la carpeta /propuestas
│   │   │   │   └── propuestas/
│   │   │   │   └── procesadas/                     ← Aqui van las propuestas aceptadas por el humano para que el biblitecario mejore la fabrica
│   │   │   ├── ontologias-meta/
│   │   │   ├── mejora-continua/                     ← propuestas del humano para mejorrara la fabrica que el biblitecario debe revisar constantemente y propner al humano trabajarlo juntos en base a programacion
│   │   │   ├── plantillas/
│   │   │   ├── procesos/
│   │   │   ├── protocolos/
│   │   │   ├── resources/
│   │   │   │   ├── ddl/
│   │   │   │   └── normas/
│   │   │   └── bblioteca_normas_estandares/         ← El bibliotecario deberia documentar todas las normas y estandares de los proyectos en desarrollo y fromalizarlas y caninizarlas para el desarrollo de todos los proyectos 
│   │   │
│   │   │
│   │   ├── bibliotecario-agent/                     ← código Python del Bibliotecario
│   │   │   ├── bibliotecario/
│   │   │   ├── logs/
│   │   │   ├── output/
│   │   │   ├── src/
│   │   │   └── tests/
│   │   │
│   │   ├── compositor-agent/                        ← código Python del Compositor
│   │   │   ├── .claude/
│   │   │   ├── bin/
│   │   │   ├── logs/
│   │   │   ├── observabilidad/
│   │   │   ├── orquesta/
│   │   │   │   ├── coordinador/
│   │   │   │   ├── core/
│   │   │   │   ├── db/
│   │   │   │   ├── eval/
│   │   │   │   ├── schemas/
│   │   │   │   ├── security/
│   │   │   │   ├── testing/
│   │   │   │   └── tools/templates/
│   │   │   ├── output/sbos-compilado/
│   │   │   ├── src/
│   │   │   ├── tests/casos/
│   │   │   └── trazas/
│   │   ├── coordinador-agent/                     ← Nuevo para desarrollar - coordina todos loa agentes activos
│   │   ├── planificador-agent/                     ← Nuevo para desarrollar - palnifaca las tareas del agente que comitea o cierra para continuar la sesion o cerra la sesion del agente 
│   │   ├── documentador-agent/                     ← Nuevo para desarrollar - cuando una gente comitea o cierra debria este agente agrra la codumentacion del agente y de su subproyecto y actualizar la docuemntacion del proyecto
│   │   ├── revisor-agent/                     ← Nuevo para desarrollar - revisar codigo, cunplimiento de normas como cero codigo monolitico, cero codigo estagueti docuemntacion detallada se gun norma ya establecida, auditar el codigo detectar fallas, alucinaciones, o fraudes del agente, cera valores harcodeados estc,
│   │   ├── testeador-agent/                     ← Nuevo para desarrollar - testear o ejecutra la cpruebas en la vps de pruebas muy aparte de las pruebas que realice el agente de su propio proyecto, el objetivo es decertar estafas errores probar el real funcionamientop de codigo, verificar qeu lo que ele agente afirma es verdad o mentira etc. se axctica siempre que el humado le pida al bibliotecario que lo invoque pero que el bibliotecario dlege que no lo haga el.
│   │   │
│   │   ├── schemas/
│   │   ├── scripts/sql/
│   │   └── trazas/checkpoints/

│   │
│   └── desarrollo/
│       └── sbos/                                    ← PROYECTO SBOS
│           ├── CLAUDE.md
│           │
│           ├── context/                         ← esta carpeta debe contener la docuemntacion dl proyecto nada de subproyectos
│           │   ├── BOS_V8/                      ← 51 docs normativos version 8, el agente documentador debe actualizar esta documentacion en euna nueva version cons alineandolos con la docuemntacion de cad agente
│           │   └── BOS_V1/                      ← 48 docs normativos version original
│           ├── scripts/
│           ├── staging/core/
│           │
│           ├── BosAgent/                            ← IAM Installer (Go 1.22+)
│           │   ├── CLAUDE.md
│           │   ├── context/                        ← IAM Installer Documentacion oficial por daemon
│           │   │   ├── docs/                       ← IAM Installer documentos normastivos, normas estandares, pdf, leyes, decretos estc que apoyan las resoluciones tomadas en el desarrolo del proyecto 
│           │   │   └── revisiones/                 ← IAM Installer Documentacion para revisiones de codigo o revison del royecto, una vez terminado el agente deb pedirle al docuemntador que acytulice losdocuemnetos con las desiciones tomdas en ese periodo una ves que el agente documente todo en los docuemntso ofociales debe respaldar lso docuentos con fecha en backups del proyecto y borrar el contenido de la carpeta para una nueva revision si se presentara
│           │   ├── scripts/
│           │   ├── src/
│           │   │   ├── bin/
│           │   │   ├── cmd/
│           │   │   │   ├── bos/
│           │   │   │   ├── bosctl/
│           │   │   │   ├── bosmin/
│           │   │   │   └── ...tests/
│           │   │   ├── core/
│           │   │   ├── core_ui/lib/
│           │   │   │   ├── models/
│           │   │   │   ├── screens/
│           │   │   │   ├── services/
│           │   │   │   └── widgets/
│           │   │   ├── deploy/rbac/
│           │   │   ├── internal/
│           │   │   │   ├── audit/ bootstrap/ catalog/
│           │   │   │   ├── ficha/ health/ installer/
│           │   │   │   ├── k8s/ keycloak/ repair/
│           │   │   │   ├── tui/
│           │   │   │   │   ├── app/ assets/ components/
│           │   │   │   │   ├── ctrl/ model/ screens/
│           │   │   │   │   └── styles/
│           │   │   │   └── ...
│           │   │   ├── proto/bos/ficha/v1/
│           │   │   ├── scripts/
│           │   │   └── servers/
│           │   │       ├── S-HOST/ S01/ S02/ S03/
│           │   │       ├── S06/ S10/ S12/
│           │   │   └── _snapshots/                  ← Respaldo de todo el subproyecto almomento del commit y cierre
│           │   ├── staging/
│           │   │   ├── containers/
│           │   │   ├── core/servers/                ← fichas de staging (espejo)
│           │   │   ├── run/
│           │   │   └── state/
│           │   └── tests/
│           │
│           ├── BosAgent copy/                       ⚠️ Eliminar mover a │           │   │   └── _snapshots/
│           │
│           ├── BauthAgent/                          ← daemon bAuth (Rust 1.85+)
│           │   ├── CLAUDE.md                        ⚠️ NO existe — doctrina dispersa
│           │   ├── context/                        ← IAM Installer Documentacion oficial por daemon
│           │   │   ├── docs/                       ← IAM Installer documentos normastivos, normas estandares, pdf, leyes, decretos estc que apoyan las resoluciones tomadas en el desarrolo del proyecto 
│           │   │   └── revisiones/                 ← IAM Installer Documentacion para revisiones de codigo o revison del royecto, una vez terminado el agente deb pedirle al docuemntador que acytulice losdocuemnetos con las desiciones tomdas en ese periodo una ves que el agente documente todo en los docuemntso ofociales debe respaldar lso docuentos con fecha en backups del proyecto y borrar el contenido de la carpeta para una nueva revision si se presentara
│           │   ├── retroalimentacion/               ⚠️ fuera de context/ es del proyecto habria qeu dejarle que hace ahi mejor no tocar nada por ahora de ahi no afecta
│           │   ├── benches/
│           │   ├── contracts/
│           │   │   ├── out/AuditAnchor.sol/
│           │   │   └── out/SettlementEngine.sol/
│           │   ├── db/                                ⚠️ fuera de context/ deebriamos poner dentro de context para docuemntos qeu se generan para rectificar desiciones o definir nuevos lieaminetos del propyeto y con esos documentos del docuemntador deberia actualizar los docuemntso del context
│           │   │   ├── backups/
│           │   │   ├── data_files/
│           │   │   ├── migrations/
│           │   │   └── seeds/
│           │   ├── proto/
│           │   ├── servers/S12/blockchain/
│           │   ├── src/
│           │   │   ├── audit/ bitmask/ blockchain/
│           │   │   ├── catalog/ config/ context/
│           │   │   ├── db/ engine/ public/ saga/
│           │   │   ├── sdk/ server/handlers/
│           │   │   ├── spi/src/ sync/ util/
│           │   │   ├── bAuthDEV/                    ← tool de desarrollo Flutter
│           │   │   ├── desktop/                     ← UI desktop Flutter
│           │   │   └── domain/
│           │   │       ├── auth_methods/
│           │   │       ├── password/ policy/ sod/
│           │   └── tests/
│           │
│           ├── BkernelAgent/                        ← daemon bKernel (Rust 1.85+)
│           │   ├── context/                         ⚠️ VACÍO
│           │   ├── retroalimentacion/               ⚠️ fuera de context/
│           │   ├── examples/
│           │   ├── fixtures/fichas/
│           │   ├── src/
│           │   │   ├── cdc/ cluster/ config/
│           │   │   ├── engine/ grpc/ rules/core/
│           │   │   ├── server/ specs/ state/
│           │   │   ├── systemd/ writers/
│           │   │   └── tests/integration/
│           │   └── tests/
│           │
│           ├── BiedataAgent/                        ← daemon biedata (Rust 1.85+)
│           │   └── src/                             ⚠️ sin context/ ni retroalimentacion/
│           │
│           ├── BintelligenceAgent/                  ← daemon bSearch (Go 1.22+)
│           │   ├── context/                         ⚠️ VACÍO
│           │   ├── retroalimentacion/               ⚠️ fuera de context/
│           │   ├── src/
│           │   │   ├── bin/ configs/ systemd/
│           │   │   ├── cmd/
│           │   │   │   ├── bcompass/ bintelligence/
│           │   │   │   ├── bintelligenctl/ bsearch/
│           │   │   └── internal/
│           │   │       ├── compass/ config/ database/
│           │   │       ├── models/ search/ server/
│           │   └── tests/
│           │
│           ├── BnexusAgent/                         ← daemon bNexus (Go 1.22+)
│           │   ├── context/                         ⚠️ VACÍO
│           │   ├── retroalimentacion/               ⚠️ fuera de context/
│           │   ├── src/
│           │   │   ├── bin/
│           │   │   ├── cmd/banexus/ cmd/bhnexus/
│           │   │   └── internal/
│           │   │       ├── bauth/ cache/ client/
│           │   │       ├── config/ device/ models/
│           │   │       ├── server/ ws/
│           │   └── tests/
│           │
│           ├── BnotifyAgent/                        ← daemon bNotify (en desarrollo)
│           │   └── src/
│           │
│           ├── InfraAgent/                          ← Bibliotecario SBOS
│           │   ├── CLAUDE.md
│           │   ├── context/                         ← aquí estamos trabajando
│           │   │   ├── ESTRUCTURA-DIRECTORIOS.md    ← este archivo
│           │   │   ├── PLAN-REESTRUCTURACION-FABRICA.md
│           │   │   └── PLAN-IMPLEMENTACION-AGENTES-IA.md
│           │   ├── retroalimentacion/               ⚠️ fuera de context/
│           │   ├── src/servers/                     ← fichas de infraestructura
│           │   │   ├── kyverno/ linkerd/ minio/
│           │   │   ├── postgresql/ redis/ vault/
│           │   │   ├── sbos-bootstrap-hardening/
│           │   │   ├── sbos-bootstrap-k8s/
│           │   │   ├── sbos-bootstrap-os/
│           │   │   ├── sbos-bootstrap-platform/
│           │   │   └── sbos-k8s-network-validator/
│           │   └── tests/
│           │
│           ├── BcmsAgent/                           ← CMS (en desarrollo)
│           │   └── src/
│           │
│           ├── BpayAgent/                           ← Smart Pay (en desarrollo)
│           │   └── src/
│           │
│           ├── BrateAgent/                          ← Smart Rates (en desarrollo)
│           │   └── src/
│           │
│           ├── BtaxAgent/                           ← Smart Tax (en desarrollo)
│           │   └── src/
│           │
│           ├── bkernel-common/                      ← librería compartida bKernel
│           │   └── src/
│           │
│           ├── bnotify/                             ⚠️ DUPLICADO de BnotifyAgent/?
│           │
│           ├── BibliotecaSBOS/                      ⚠️ propósito solapado con InfraAgent
│           │   ├── context/
│           │   ├── retroalimentacion/
│           │   ├── src/
│           │   └── tests/
│           │
│           ├── BibliotecarioSBOS/                   ⚠️ propósito solapado con InfraAgent
│           │   ├── context/
│           │   ├── retroalimentacion/
│           │   ├── src/
│           │   └── tests/
│           │
│           ├── CompositorSBOS/
│           │   ├── context/
│           │   ├── retroalimentacion/
│           │   ├── src/
│           │   └── tests/
│           │
│           ├── ObservabilidadSBOS/
│           │   ├── context/
│           │   ├── retroalimentacion/
│           │   ├── src/
│           │   └── tests/
│           │
│           └── OrquestaCoreSBOS/
│               ├── context/
│               ├── retroalimentacion/
│               ├── src/
│               └── tests/
│
├── backups/
├── datos/
├── observabilidad/
└── platform/
```

### Leyenda

| Símbolo | Significado |
|---|---|
| ⚠️ | Problema detectado — requiere decisión o limpieza |
| (vacío) | Sin problemas detectados en esta carpeta |

### Problemas globales detectados en el árbol

| # | Problema | Afecta |
|---|---|---|
| 1 | `context/` VACÍO en casi todos los daemons | BauthAgent, BkernelAgent, BintelligenceAgent, BnexusAgent |
| 2 | `retroalimentacion/` fuera de `context/` en todos los agentes | Todos |
| 3 | `context/` duplicado — raíz sbos + `context/sbos/Procesar/` | sbos/ raíz |
| 4 | `Procesar/` duplicado en raíz de sbos | sbos/ raíz |
| 5 | `BosAgent copy/` y `plandeaccion copy/` sin limpiar | BosAgent, Procesar/bos/ |
| 6 | `bnotify/` duplicado de `BnotifyAgent/` | sbos/ raíz |
| 7 | `BibliotecaSBOS/` y `BibliotecarioSBOS/` solapan con `InfraAgent/` | sbos/ raíz |
| 8 | `src/docs/` dentro del código fuente de BosAgent | BosAgent/src/ |
| 9 | `src/_legacy/` y `src/_snapshots/` dentro del código fuente | BosAgent/src/ |
| 10 | `context-fabrica/` y `context/` coexisten en fabrica/ | fabrica/ |
| 11 | `ia_backup/` sin limpiar | sbos/context/ |
| 12 | Sin `DOCTRINA.md` ni `ESTADO.md` en ningún agente | Todos |
```

---
*Documento vivo — corregir aquí antes de formalizar en la configuración*


---

## PROPUESTA FINAL — Árbol objetivo reorganizado

> Sintetiza: la visión REORGANIZADO del humano + investigación de mejores prácticas
> de la industria 2026. Esta es la versión a implementar. No borra nada — el humano
> reorganiza manualmente proyecto por proyecto.

### Hallazgos de la investigación que validan las decisiones tomadas

| Práctica del ecosistema 2026 | Cómo se aplica en esta fábrica |
|---|---|
| **AGENTS.md anidado** — estándar leído por Claude Code, Codex, Cursor, Aider, Devin. Cada subdirectorio tiene su propio archivo de instrucciones. | Nuestros `CLAUDE.md` por daemon son exactamente ese patrón. La industria lo valida. |
| **Working memory isolation** — cada agente ve solo lo necesario para su paso actual, no el historial completo. | `context/` soberano por agente. Un agente nunca lee el `context/` de otro. |
| **Hierarchical summaries** — resumen activo en BD + historial archivado en disco. | `perfiles.bitacora_agente` en SKDATA (activo) + `context/_archivo/` (historial en disco). |
| **5 roles estándar de fábrica** validados en literatura 2026: Orchestrator, Programmer, Reviewer, Tester, Documenter. | Los 5 agentes nuevos que propone el humano son exactamente esos roles. El modelo es correcto. |
| **MCP como protocolo de conexión** entre agentes y herramientas externas (BD, filesystem, APIs). | postgres-mcp + SKDATA: memoria persistente sin leer archivos gigantes. |
| **Software Factory pattern** (Addy Osmani 2026) — cada ingeniero gestiona agentes que escriben, testean, revisan y despliegan. | Es exactamente lo que construye esta fábrica. La arquitectura de grid tmux es coherente. |
| **Schema-per-service** (AWS Prescriptive Guidance, microservices.io 2026) — una BD compartida, un schema PostgreSQL por daemon, más un schema global para tablas comunes. Esto es exactamente el patrón `bGlobal` + schema por daemon. | DDL centralizado en `SBOS/DDLs/`, BOS como migration orchestrator, golang-migrate una instancia por schema. La URL de conexión vincula el schema: `...@host/sbos?search_path=bauth`. |

### El árbol objetivo

```
/opt/skull/orquestador/
│
├── proyectos/
│   │
│   ├── fabrica/                          ← FÁBRICA ORQUESTA — transversal a todos los proyectos
│   │   │
│   │   ├── CLAUDE.md                     ← MÁXIMO 15 líneas: idioma + puntero a doctrina + 3 reglas
│   │   │
│   │   ├── .claude/
│   │   │   ├── settings.json             ← hooks SessionStart/Stop + servidores MCP
│   │   │   ├── agents/                   ← ficha técnica de cada agente (qué tools usa, modelo, descripción)
│   │   │   │   ├── bibliotecario.md
│   │   │   │   ├── compositor.md
│   │   │   │   ├── coordinador.md        ← NUEVO
│   │   │   │   ├── planificador.md       ← NUEVO
│   │   │   │   ├── documentador.md       ← NUEVO
│   │   │   │   ├── revisor.md            ← NUEVO
│   │   │   │   ├── testeador.md          ← NUEVO
│   │   │   │   ├── bos-developer.md
│   │   │   │   ├── bauth-developer.md
│   │   │   │   ├── bkernel-developer.md
│   │   │   │   ├── biedata-developer.md
│   │   │   │   ├── bintelligence-developer.md
│   │   │   │   └── bnexus-developer.md
│   │   │   └── skills/                   ← protocolo operativo de cada agente (el "cómo trabajo")
│   │   │       ├── orquesta-bibliotecario/
│   │   │       ├── orquesta-coordinador/
│   │   │       ├── orquesta-compositor/
│   │   │       ├── orquesta-planificador/
│   │   │       ├── orquesta-documentador/
│   │   │       ├── orquesta-revisor/
│   │   │       └── orquesta-testeador/
│   │   │
│   │   ├── context-fabrica/              ← ÚNICO lugar de doctrina transversal (fusiona context/ + context-fabrica/)
│   │   │   ├── doctrina/                 ← ORQUESTA-000…047 + ADRs globales
│   │   │   │   └── json-RPC/             ← norma fábrica: todo daemon usa RPC. Todos los proyectos deben cumplirla.
│   │   │   ├── normas-estandares/        ← normas internacionales para todos los proyectos
│   │   │   │                             ← ISO 27001, IANA, CIS, NSA, NIST, W3C, OTel, OIDC
│   │   │   │                             ← El Bibliotecario las formaliza; todos los agentes las consultan aquí
│   │   │   ├── aprendizajes/
│   │   │   │   ├── auditorias/           ← hallazgos del Bibliotecario/Revisor
│   │   │   │   ├── propuestas/           ← mejoras propuestas, esperando aprobación del humano
│   │   │   │   └── procesadas/           ← propuestas aprobadas y ejecutadas (historial)
│   │   │   ├── mejora-continua/          ← ideas del humano que el Bibliotecario revisa y propone implementar
│   │   │   ├── plantillas/               ← plantillas reutilizables de documentos, fichas, CLAUDE.md
│   │   │   ├── protocolos/               ← protocolos operativos entre agentes (agente_enviar.sh, etc.)
│   │   │   └── recursos/
│   │   │       └── ddl/                  ← DDL de SKDATA (base de datos de la fábrica)
│   │   │
│   │   ├── bibliotecario-agent/          ← código Python del Bibliotecario (existe)
│   │   │   ├── src/
│   │   │   └── tests/
│   │   ├── compositor-agent/             ← código Python del Compositor (existe)
│   │   │   ├── src/
│   │   │   └── tests/
│   │   ├── coordinador-agent/            ← NUEVO — gestiona grafo tareas, resuelve bloqueos
│   │   │   ├── src/
│   │   │   └── tests/
│   │   ├── planificador-agent/           ← NUEVO — planifica sesión al cierre, prepara contexto
│   │   │   ├── src/
│   │   │   └── tests/
│   │   ├── documentador-agent/           ← NUEVO — actualiza docs al commit/cierre del agente
│   │   │   ├── src/
│   │   │   └── tests/
│   │   ├── revisor-agent/                ← NUEVO — audita código: normas, monolíticos, hardcodes
│   │   │   ├── src/
│   │   │   └── tests/
│   │   ├── testeador-agent/              ← NUEVO — verifica en VPS independiente lo que el agente afirma
│   │   │   ├── src/
│   │   │   └── tests/
│   │   │
│   │   └── scripts/
│   │       └── agente_enviar.sh
│   │
│   └── SBOS/                            ← PROYECTO SBOS (patrón replicable para cualquier proyecto)
│       │
│       ├── CLAUDE.md                    ← 10 líneas: puntero a doctrina SBOS + 3 reglas críticas
│       │
│       ├── context/                     ← documentación del PROYECTO (no de subproyectos)
│       │   ├── BOS_V8/                  ← 51 docs normativos versión actual (fuente de verdad)
│       │   └── BOS_V1/                  ← docs versión original (referencia histórica)
│       │
│       ├── config/                      ← CONFIGURACIONES DEL PROYECTO — parámetros concretos de entorno
│       │   ├── entornos/
│       │   │   ├── staging.yml          ← VPS de pruebas: IP, puertos, credenciales SSH, rutas remotas
│       │   │   ├── prod.yml             ← servidor de producción (cuando exista)
│       │   │   └── local.yml            ← entorno local del desarrollador
│       │   ├── paths.yml                ← rutas canónicas del proyecto (dónde vive cada cosa en el SO)
│       │   ├── versions.yml             ← versiones canónicas del stack: PG18.4, Redis8.6.2, KC26.6.2…
│       │   └── normas-proyecto.md       ← normas globales específicas de SBOS (no de la fábrica)
│       │                                ← Ejemplo: "todo binario compilado va a /opt/skull/sbos/bin/"
│       │                                ← Ejemplo: "el VPS de staging es el único entorno autorizado para F9+"
│       │
│       ├── backups/                     ← backups por agente — NO por servidor lógico
│       │   ├── BosAgent/
│       │   ├── BauthAgent/
│       │   ├── BkernelAgent/
│       │   └── ...
│       │
│       ├── scripts/
│       │
│       ├── DDLs/                        ← PUNTO ÚNICO de toda la DDL del proyecto SBOS
│       │   ├── main.sql                 ← orquesta todo en orden topológico: crea schemas, ejecuta migrations
│       │   │                            ← BOS lo invoca al instalar. golang-migrate, una instancia por schema.
│       │   ├── migrations/
│       │   │   ├── 000_bGlobal/         ← schema bGlobal: tablas compartidas por TODOS los daemons
│       │   │   │                        ← catálogos CAEB, países, monedas, ctx_id registry, tipos base, dominios
│       │   │   │                        ← Se ejecuta PRIMERO — ningún otro schema puede referenciarlo sin que exista
│       │   │   ├── 100_bos/             ← control de fichas, estados del bootstrap, DAG de instalación
│       │   │   ├── 200_bauth/           ← identidad, roles, bitmask, dominios, BitMask 64-bit, SPIs
│       │   │   ├── 300_bkernel/         ← CDC metadata, replication slots, event log
│       │   │   ├── 400_biedata/         ← fichas declarativas, task_catalog, saga_log
│       │   │   ├── 500_bsearch/         ← índices GIN, tsvector, configuración de búsqueda particionada
│       │   │   ├── 600_bnexus/          ← dispositivos OSDP/MQTT/ONVIF, auth cache, hardware registry
│       │   │   └── 700_bnotify/         ← plantillas de notificación, canales, push tokens, MFA log
│       │   └── seeds/
│       │       ├── global/              ← seeds de bGlobal (catálogos, roles base, dominios raíz, tipos)
│       │       │                        ← Se ejecutan DESPUÉS del DDL bGlobal, ANTES que seeds de daemons
│       │       ├── bos/
│       │       ├── bauth/
│       │       ├── bkernel/
│       │       ├── biedata/
│       │       ├── bsearch/
│       │       ├── bnexus/
│       │       └── bnotify/
│       │
│       ├── BosAgent/                    ← daemon bos / IAM Installer (Go 1.22+)
│       │   ├── CLAUDE.md                ← 20 líneas máximo: quién soy + leer SKDATA + 3 reglas
│       │   ├── context/
│       │   │   ├── docs/                ← normas y estándares que respaldan decisiones del daemon
│       │   │   ├── revisiones/          ← espacio temporal de trabajo (se vacía al cerrar ciclo)
│       │   │   └── _archivo/            ← historial inmutable por fecha — nunca se borra
│       │   ├── src/
│       │   │   ├── bin/
│       │   │   ├── cmd/ bos/ bosctl/ bosmin/
│       │   │   ├── core/
│       │   │   ├── core_ui/lib/
│       │   │   ├── internal/ (audit, bootstrap, catalog, ficha, health, installer, k8s, tui...)
│       │   │   ├── proto/
│       │   │   ├── scripts/
│       │   │   └── servers/ S-HOST/ S01/ S02/ S03/ S06/
│       │   ├── staging/
│       │   │   ├── containers/
│       │   │   ├── core/servers/
│       │   │   ├── run/
│       │   │   └── state/
│       │   ├── _snapshots/              ← backup completo al momento del commit/cierre de sesión
│       │   └── tests/
│       │
│       ├── BauthAgent/                  ← daemon bAuth (Rust 1.85+)
│       │   ├── CLAUDE.md
│       │   ├── context/
│       │   │   ├── docs/
│       │   │   ├── revisiones/
│       │   │   └── _archivo/
│       │   ├── src/ (audit, bitmask, blockchain, catalog, domain, engine, saga, server, spi...)
│       │   │   ← Sin db/ propio. Migrations → DDLs/migrations/200_bauth/  Seeds → DDLs/seeds/bauth/
│       │   ├── _snapshots/
│       │   └── tests/
│       │
│       ├── BkernelAgent/                ← daemon bKernel (Rust 1.85+)
│       │   ├── CLAUDE.md
│       │   ├── context/ docs/ revisiones/ _archivo/
│       │   ├── src/ (cdc, cluster, config, engine, rules, server, writers...)
│       │   ├── _snapshots/
│       │   └── tests/
│       │
│       ├── BiedataAgent/                ← daemon biedata (Rust 1.85+)
│       │   ├── CLAUDE.md
│       │   ├── context/ docs/ revisiones/ _archivo/
│       │   ├── src/
│       │   ├── _snapshots/
│       │   └── tests/
│       │
│       ├── BintelligenceAgent/          ← daemon bSearch (Go 1.22+)
│       │   ├── CLAUDE.md
│       │   ├── context/ docs/ revisiones/ _archivo/
│       │   ├── src/ (cmd/bsearch, internal/search...)
│       │   ├── _snapshots/
│       │   └── tests/
│       │
│       ├── BnexusAgent/                 ← daemon bNexus (Go 1.22+)
│       │   ├── CLAUDE.md
│       │   ├── context/ docs/ revisiones/ _archivo/
│       │   ├── src/ (cmd/banexus, cmd/bhnexus, internal...)
│       │   ├── _snapshots/
│       │   └── tests/
│       │
│       ├── BnotifyAgent/                ← daemon bNotify
│       │   ├── CLAUDE.md
│       │   ├── context/ docs/ revisiones/ _archivo/
│       │   ├── src/
│       │   └── _snapshots/
│       │
│       ├── InfraAgent/                  ← Bibliotecario del SBOS (aquí mismo)
│       │   ├── CLAUDE.md
│       │   ├── context/
│       │   │   ├── docs/                ← normas de infraestructura que aplican al SBOS
│       │   │   ├── revisiones/
│       │   │   ├── _archivo/
│       │   │   ├── ESTRUCTURA-DIRECTORIOS.md     ← este archivo
│       │   │   ├── PLAN-REESTRUCTURACION-FABRICA.md
│       │   │   └── PLAN-IMPLEMENTACION-AGENTES-IA.md
│       │   ├── src/servers/             ← fichas YAML de infraestructura
│       │   │   ├── postgresql/ redis/ vault/ minio/ kyverno/ linkerd/
│       │   │   └── sbos-bootstrap-*/
│       │   ├── _snapshots/
│       │   └── tests/
│       │
│       └── bkernel-common/              ← librería compartida (sin agentes, sin context/ de sesión)
│           ├── context/docs/            ← solo docs de referencia, no estado de sesión
│           └── src/
│
├── backups/                             ← backups de plataforma y SO (no de daemons)
├── datos/
├── observabilidad/
└── platform/
```

### Reglas de la estructura propuesta

| Regla | Descripción |
|---|---|
| **R1 — Soberanía de contexto** | Todo lo de un agente vive en `<AgentDir>/context/`. Sin excepciones. Un agente nunca lee el `context/` de otro. |
| **R2 — CLAUDE.md como puntero** | Máximo 20 líneas. Solo: quién soy, dónde está mi código, cómo leer mi estado en SKDATA. |
| **R3 — `context/docs/`** | Normas, PDFs, leyes, estándares que respaldan decisiones. El Documentador los actualiza al commit. |
| **R4 — `context/revisiones/`** | Espacio temporal de trabajo activo. Se vacía y archiva al cerrar el ciclo de trabajo. |
| **R5 — `context/_archivo/`** | Historial inmutable fechado. Solo crece. Nunca se borra. Solo se consulta. |
| **R6 — `_snapshots/`** | Backup completo del agente al commit o cierre de sesión. El Planificador lo activa. |
| **R7 — Doctrina en fábrica** | Las normas transversales van en `fabrica/context-fabrica/`. Cada proyecto solo tiene su spec. |
| **R8 — json-RPC es norma de fábrica** | Todos los agentes de todos los proyectos deben conocer Interface Dual (ADR-020). El Bibliotecario lo formaliza en `context-fabrica/doctrina/json-RPC/`. |
| **R9 — Un solo `context/` por nivel** | Fábrica: `context-fabrica/`. Proyecto: `context/`. Agente: `context/`. Sin duplicados. |
| **R10 — Backups por agente** | `backups/<NombreAgente>/` dentro del proyecto. No por servidor lógico S01-S15. |
| **R11 — DDL centralizado en el proyecto** | Ningún daemon tiene `db/` propio. Toda DDL y seeds viven en `<Proyecto>/DDLs/`. BOS es el único que ejecuta migrations. Un schema por daemon + schema `bGlobal` compartido. El schema se vincula en la URL de conexión del daemon, nunca con `SET search_path`. |
| **R12 — `config/` por proyecto** | Cada proyecto tiene su propia `config/` con parámetros de entorno concretos: IPs/puertos de VPS, rutas canónicas, versiones del stack, normas específicas del proyecto. No va en `context/` (que es doctrina), no va en cada daemon (que es código). Es el puente entre la doctrina y el entorno real. |

### Lo que se elimina — lista para el humano

| Directorio problemático | Acción |
|---|---|
| `BosAgent copy/` | Revisar → mover contenido único a `BosAgent/_snapshots/` → eliminar |
| `plandeaccion copy/` | Revisar → consolidar en `context/_archivo/` → eliminar |
| `Procesar/` en raíz sbos | Verificar cuál está más actualizado → eliminar el duplicado |
| `context/ia_backup/` | Comparar con `context/ia/` → eliminar si es idéntico |
| `bnotify/` en raíz sbos | Consolidar en `BnotifyAgent/` → eliminar |
| `BibliotecaSBOS/` y `BibliotecarioSBOS/` | Consolidar en `InfraAgent/` → eliminar las dos |
| `sbos/out/` (artefactos Solidity) | Mover a `BauthAgent/context/_archivo/blockchain/` |
| `sbos/cache/` | Investigar → eliminar si es caché de compilación |
| `fabrica/context/` | Fusionar en `fabrica/context-fabrica/` → eliminar `fabrica/context/` |
| `BosAgent/src/docs/` | Mover a `BosAgent/context/docs/` → eliminar de src/ |
| `BosAgent/src/_legacy/` y `src/_snapshots/` | Mover a `BosAgent/_snapshots/` → eliminar de src/ |
| `retroalimentacion/` en todos los agentes | Revisar → mover útil a `context/_archivo/` → eliminar |
| `BauthAgent/db/` (y cualquier `db/` en otros agentes) | Mover migrations → `DDLs/migrations/200_bauth/`, seeds → `DDLs/seeds/bauth/`, backups → `backups/BauthAgent/` → eliminar `db/` del agente |

---
*Propuesta lista para implementar — el humano reorganiza manualmente, el Bibliotecario formaliza en `.claude/`*
