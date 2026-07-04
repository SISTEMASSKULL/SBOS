# BOS-REPAIR — Plan Maestro de Reparación del Daemon `bos`
## Versión 3.0 — Documento Definitivo · Granularidad Atómica Completa · Gestión de Conocimiento

**Proyecto:** BosAgent / SBOS · SKULL  
**Versión:** 3.0 · Junio 2026  
**Evaluación de partida:** 3.5 / 10 → objetivo: 10 / 10  
**Átomos totales:** 85 · distribuidos en 11 fases  
**Metodología:** Strangler Fig Pattern · DoD por átomo · Informe de Cierre · Memoria de Proyecto

---

## PARTE I — DIAGNÓSTICO: ¿Qué documentación tenemos y qué falta?

### 1.1 Inventario de documentación existente

El proyecto cuenta con **14 documentos BOS-REPAIR** de alta calidad, **9 partes del manual JSON-RPC**, **6 ADRs**, y todo el código fuente revisado estáticamente. A continuación la evaluación de cobertura:

| Área | Documentación existente | Cobertura | Qué falta para iniciar |
|---|---|---|---|
| **Auditoría técnica** | BOS-REPAIR-00: 16 problemas con evidencia de código | ✅ 100% | Nada — base sólida |
| **Bugs críticos** | P1..P16 documentados con riesgo operativo | ✅ 100% | Nada |
| **ADR de roles y privilegios** | ADR-002 (BOS-REPAIR-06) | ✅ 100% | Nada |
| **ADR de documentación** | ADR-003 (BOS-REPAIR-07) con 6 niveles y reglas | ✅ 100% | Nada |
| **ADR de RBAC delegado** | ADR-006 (BOS-REPAIR-11) con política sudoers completa | ✅ 100% | Nada |
| **ADR de Operator Soberano** | ADR-004 (BOS-REPAIR-02) con Fase 9 completa | ✅ 100% | Nada |
| **ADR de abstracción bosctl** | ADR-005 (BOS-REPAIR-03) con CRDs y vocabulario | ✅ 100% | Nada |
| **Context Plane** | BOS-REPAIR-08 con DDL, API, estados, 15 preguntas | ✅ 95% | DDL exacto para aplicar en bkernel_db |
| **VDI Layer** | BOS-REPAIR-09 + SBOS-052 con criterios C-09..C-14 | ✅ 100% | Nada |
| **biaos** | BOS-REPAIR-10 con ICAP, SagaEngine, entrenamiento | ✅ 90% | Spec de `action_catalog.yml` completo |
| **Sagas de consulta** | BOS-REPAIR-04 (6 sagas) + BOS-REPAIR-12 (marco normativo) | ✅ 100% | Nada |
| **Efectividad y verificación** | BOS-REPAIR-01 con 5 capas, C-01..C-14, SLIs/SLOs | ✅ 100% | Nada |
| **Flujo end-to-end** | BOS-REPAIR-13 con flujo NL → sagas → usuario | ✅ 100% | Nada |
| **Código fuente** | cmd/ + internal/ completo, go.mod, config | ✅ 100% | Nada — todo está en el knowledge |
| **Propuesta internal/** | reporte__03_propuesta_internal.md con boilerplate inicial | ✅ 80% | Completar con todos los paquetes |
| **Tests** | Sin tests actuales en cmd/ — cero cobertura | ❌ 0% | Crear a medida que avancen los átomos |
| **Pipeline CI/CD** | No existe — ningún documento lo especifica | ❌ 0% | **GAP 1 — necesita especificación** |
| **Entornos: dev/staging/prod** | No documentado | ❌ 0% | **GAP 2 — necesita especificación** |
| **Runbooks operacionales** | No existen — solo BOS-REPAIR-01 como referencia | ❌ 20% | **GAP 3 — necesita runbooks por incidente** |
| **`action_catalog.yml` biaos** | Solo mencionado, sin contenido | ❌ 0% | **GAP 4 — necesita spec completa** |

### 1.2 Análisis de los 4 Gaps documentales

#### GAP 1 — Pipeline CI/CD no especificado

**Impacto:** Sin pipeline CI/CD, el `go test -race` no se ejecuta automáticamente en cada commit, y la race condition P6/P14 puede reintroducirse silenciosamente. Todo el valor de los tests atómicos se pierde sin automatización.

**Qué se necesita:**
```yaml
# .github/workflows/bos-repair.yml (spec mínima)
# O equivalente en GitLab CI / local runner

Pasos obligatorios en cada commit:
  1. go build ./...              → compilación limpia
  2. go vet ./...               → análisis estático
  3. gofmt -l . | wc -l = 0    → formato Go
  4. go test -race -count=10 ./... → tests con race detector (×10 repeticiones)
  5. go test -cover ./internal/... → cobertura mínima 60%

Gates de calidad que bloquean merge:
  - go build falla → ❌ no merge
  - DATA RACE detectado → ❌ no merge (el más importante)
  - Cobertura < 60% en paquetes críticos → ⚠️ warning (no bloquea hasta Fase 8)
```

**Resolución:** Átomo F0.5 en este plan.

#### GAP 2 — Entornos de desarrollo no documentados

**Impacto:** Sin definición de entornos, cualquier átomo que modifique config del sistema (paths, sudoers, K8s) puede afectar producción accidentalmente.

**Qué se necesita:**
```
DEV:     laptop/VM del desarrollador — BOS_ENV=development
         - BOS_DEV_SKIP_ROOT=1 (ya existe en código)
         - sin systemd real, mocks para K8s
         - tests unitarios y de integración

STAGING: servidor idéntico a producción con tenant "test"
         - todos los átomos se validan aquí antes de producción
         - bosctl bootstrap verify --full debe pasar

PROD:    servidor skull con tenant real
         - solo átomos certificados en staging llegan aquí
         - cambios vía feature flags (SFP-03)
```

**Resolución:** Átomo F0.6 en este plan.

#### GAP 3 — Runbooks operacionales faltantes

**Impacto:** Sin runbooks, un operador que recibe una alerta a las 3am no sabe exactamente qué hacer. El BOS-REPAIR-01 define los criterios pero no el procedimiento paso a paso.

**Qué se necesita (3 runbooks mínimos):**
- `RB-01-FICHA-DEGRADADA.md` — qué hacer cuando una ficha está en DEGRADADA
- `RB-02-RACE-CONDITION-DETECTADA.md` — qué hacer si se detecta DATA RACE en logs
- `RB-03-CONTEXT-PLANE-DOWN.md` — qué hacer cuando el Context Plane falla

**Resolución:** Átomo F7.8 en este plan.

#### GAP 4 — `action_catalog.yml` de biaos sin especificar

**Impacto:** biaos depende del catálogo ICAP para saber qué acciones puede proponer. Sin el catálogo, el agente no puede funcionar. BOS-REPAIR-10 menciona el catálogo pero no da su contenido.

**Qué se necesita:**
```yaml
# Estructura mínima de action_catalog.yml
# Cada acción tiene: id, descripcion, metodo_rpc, parametros, confirmacion_requerida, riesgo

acciones:
  - id: repair_ficha
    descripcion: "Reparar una ficha degradada"
    metodo_rpc: bos.ficha.repair
    parametros: [ficha_id]
    confirmacion_requerida: false
    riesgo: bajo

  - id: cordon_nodo
    descripcion: "Aislar un nodo para mantenimiento"
    metodo_rpc: bos.k8s.node.cordon
    parametros: [node_name]
    confirmacion_requerida: true
    riesgo: alto
    compensacion: bos.k8s.node.uncordon
```

**Resolución:** Átomo F10.0 en este plan.

---

## PARTE II — POLÍTICAS GLOBALES DEL PLAN

### 2.1 Política de Migración Segura — Strangler Fig Pattern

Todo código existente es **preservado, no eliminado**. El código nuevo crece alrededor del legado hasta certificarse.

```
REGLA SFP-01 — Nunca borrar, siempre archivar
  Antes de modificar cualquier bloque de código:
  cp <archivo_origen> _legacy/YYYY-MM-DD_<fase>_<descripción>.go
  El archivo en _legacy/ se comenta con: // ARCHIVADO: <razón> <fecha> <fase>

REGLA SFP-02 — Coexistencia verificada
  El código nuevo compila y pasa tests ANTES de tocar el archivo origen.
  El origen se vacía (no se borra) solo cuando el nuevo pasa todos los tests.

REGLA SFP-03 — Feature flags de migración
  Cada extracción mayor usa variable de entorno:
    BOS_OBSERVER_V2=true  → usa internal/observer/ (nuevo)
    BOS_OBSERVER_V2=false → usa función inline de main.go (legado)
  El legado permanece disponible hasta validación en staging.

REGLA SFP-04 — Un átomo = un commit semántico
  Formato: [FASE-X.Y] tipo: descripción_breve
  Ejemplos:
    [F1.1] feat: migrar auditLog() a internal/audit/log.go
    [F1.5] fix: agregar mutex anti-race en internal/observer/
    [F3.2] refactor: extraer Screen enum a internal/tui/model/types.go
  El cuerpo del commit incluye el número de Informe de Cierre.

REGLA SFP-05 — Sin regresión de compilación
  go build ./... debe pasar VERDE en CADA commit.
  Si rompe: git revert inmediato, análisis, nueva estrategia.

REGLA SFP-06 — Preservación como memoria
  _legacy/README.md es el índice del conocimiento histórico del proyecto.
  Cada archivo archivado tiene entrada: fecha, fase, qué problema resolvía,
  por qué se migró, enlace al Informe de Cierre.
  Este directorio es la "memoria del proyecto" — nunca se borra.
```

### 2.2 Definition of Done (DoD) Universal

Todo átomo debe cumplir estos criterios antes de marcarse ✅:

```bash
# DoD-Universal — ejecutar antes de cerrar cualquier átomo
go build ./...         && echo "✅ BUILD"
go vet ./...           && echo "✅ VET"
gofmt -l . | wc -l | grep "^0$" && echo "✅ FORMAT"
go test -race -count=10 ./... && echo "✅ TESTS SIN RACE (×10)"

# Godoc presente en todo código nuevo exportado
grep -rn "^// [A-Z]" <paquete_nuevo>/*.go | wc -l | grep -E "^[1-9]" && echo "✅ GODOC"

# Código legado archivado si se extrajo algo
ls _legacy/*$(date +%Y-%m-%d)* 2>/dev/null && echo "✅ LEGACY ARCHIVADO" || echo "⚠️ SIN LEGACY"

# Feature flag presente si es extracción mayor
# (aplica solo a F1.x, F2.x, F3.x, F4.x)
```

### 2.3 Plantilla de Informe de Cierre de Átomo

```markdown
## INFORME DE CIERRE — Átomo [FASE-X.Y]
**ID:** [FASE-X.Y] — [nombre del átomo]
**Estado:** ✅ CERRADO
**Inicio:** YYYY-MM-DD HH:MM | **Cierre:** YYYY-MM-DD HH:MM | **Duración real:** Xh (est. Yh)
**Commit:** [hash corto]

### Resumen ejecutivo
[2-3 oraciones: qué se hizo, qué problema resolvió, resultado]

### Cambios realizados
| Archivo | Acción | Líneas Δ |
|---|---|---|
| path/to/nuevo.go | CREADO | +N |
| path/to/origen.go | VACIADO | -N |
| _legacy/fecha_desc.go | ARCHIVADO | ref |

### Código preservado en `_legacy/`
- `_legacy/YYYY-MM-DD_FX.Y_nombre.go` — [qué contenía, por qué importa conservarlo]

### Evidencia de validación
```bash
# Output exacto del DoD-Universal ejecutado
go build ./...    # ✅ ok
go test -race ... # ✅ ok  (N tests, N segundos)
```

### Problemas encontrados y resolución
[Si hubo problemas, cómo se resolvieron. Si no hubo, "Ninguno."]

### Decisiones tomadas
[Decisiones no obvias que afectarán átomos futuros]

### Lecciones aprendidas
[Qué se aprendió — útil para átomos similares en el futuro]

### Señal de retoma
[Si el trabajo fue interrumpido: exactamente dónde continuar]

### Impacto en átomos dependientes
[Qué átomos posteriores dependen de este, si aplica]
```

### 2.4 Política de Calidad de Código

```
POLÍTICA-CÓDIGO-01 — Godoc según ADR-003
  Todo identificador exportado tiene comentario godoc.
  Todo doc.go tiene las 6 secciones: Responsabilidades, Fuera de alcance,
  Dependencias, Callers principales, Estándares, Ejemplo de uso.
  Verificación: go vet ./... + go doc ./internal/<paquete>/

POLÍTICA-CÓDIGO-02 — Errores con contexto (ADR-003 R2)
  Nunca: return nil, err
  Siempre: return nil, fmt.Errorf("paquete: operacion %s: %w", id, err)

POLÍTICA-CÓDIGO-03 — Sin paths hardcodeados (P16)
  Todos los paths canónicos en internal/paths/paths.go
  Verificación: grep -rn '"/var/lib/bos"' --include="*.go" cmd/ = vacío

POLÍTICA-CÓDIGO-04 — Sin estado global mutable no protegido (P7, P15)
  Variables globales mutables → sync.Once o sync.RWMutex
  Verificación: go test -race -count=50 ./... sin DATA RACE

POLÍTICA-CÓDIGO-05 — TEA puro en BubbleTea (P3)
  Todos los handlers del TUI son funciones puras:
  func handleXxx(m model, msg tea.Msg) (model, tea.Cmd)
  Verificación: grep -rn "func (m \*model)" internal/tui/ = vacío

POLÍTICA-CÓDIGO-06 — Módulos Go ≤ 300 líneas por archivo
  Excepción documentada si un archivo supera 300 líneas.
  Verificación: find internal/ -name "*.go" -exec wc -l {} \; | awk '$1>300'
```

---

## PARTE III — MAPA ARQUITECTÓNICO OBJETIVO

### 3.1 Estado actual (mapeo completo del código)

```
cmd/
├── bos/
│   └── main.go              1,417 líneas ← P4: infraestructura en main
└── bosctl/
    ├── install_ui.go        4,834 líneas ← P1: monolito TUI
    ├── main.go                639 líneas ← P7,P15: RBAC global, WS
    ├── bootstrap.go           648 líneas ← P5: kubeconfig x6, check*
    ├── ask.go                ~150 líneas  OK
    ├── app.go                ~100 líneas  OK
    ├── packages.go           ~100 líneas  OK
    ├── repair.go              ~30 líneas  stub
    ├── rpc.go                ~100 líneas  OK
    ├── identity.go           ~100 líneas  OK
    ├── set.go                 ~80 líneas  OK
    ├── release.go             ~80 líneas  OK
    ├── security.go            ~50 líneas  OK
    ├── top.go                  ~5 líneas  stub
    └── health_report.go       ~10 líneas  stub

internal/                     ← bien estructurado (60% del código)
├── ai/client.go              ~200 líneas  OK → migrar a biaos/
├── ai/model_router.go         465 líneas  OK → migrar a biaos/
├── config/config.go           342 líneas  ✅ correcto
├── domain/bootstrap_service.go ~200 líneas OK
├── domain/pg_auxiliar.go     ~150 líneas  OK
├── domain/types.go            ~80 líneas  OK — CtxID incompleto
├── health/checker.go          ~200 líneas  ✅ correcto
├── installer/compensator.go   125 líneas  ✅ correcto
├── installer/saga.go          413 líneas  ✅ correcto
├── k8s/core.go                ~300 líneas  OK — falta Scale/Cordon/Drain
├── packages/                  ✅ OK
├── plugin/loader.go           ~400 líneas  ✅ correcto
├── reconcile/scheduler.go     ~250 líneas  ✅ correcto (drift SHA-256)
├── repair/repair_manager.go   240 líneas  ✅ correcto
├── security/rbac_provider.go  ~100 líneas  ❌ eliminar (ADR-006)
├── server/api.go              ~200 líneas  OK
├── server/bootstrap_go.go     ~200 líneas  OK
├── server/jsonrpc.go          671 líneas  OK → extender con 20+ métodos
├── server/ws.go               962 líneas  OK → cohesivo
├── state/manager.go           599 líneas  ✅ correcto (18 estados)
├── watchdog/unified_watchdog.go ~300 líneas ✅ correcto
└── wslib/websocket.go         299 líneas  ✅ correcto (nunca usado por cmd/)

Faltantes en internal/ (0 líneas):
├── audit/          ← a crear (F1.1)
├── bootstrap/      ← a crear (F1.2)
├── cgroup/         ← a crear (F1.3)
├── network/        ← a crear (F1.4)
├── observer/       ← a crear (F1.5) — CRÍTICO: mutex anti-race
├── context/        ← a crear (F5.x) — Context Plane completo
├── biaos/          ← a crear (F10.x) — agente OS + gateway IA
├── scaler/         ← a crear (F9.3) — escalado anti-death-spiral
├── maintenance/    ← a crear (F9.4) — saga cordon→drain→uncordon
├── metrics/        ← a crear (F9.6) — Prometheus
└── paths/          ← a crear (F1.7) — centraliza todos los paths
```

### 3.2 Arquitectura objetivo post-reparación

```
cmd/
├── bos/
│   └── main.go              ≤200 líneas — SOLO orquestación y señales OS
└── bosctl/
    ├── main.go              ≤120 líneas — SOLO router CLI
    ├── install_ui.go         ≤80 líneas — SOLO entry points TUI
    ├── bootstrap.go         ≤100 líneas — SOLO CLI parsing
    ├── context.go            ≤80 líneas — bosctl context subcomandos
    ├── infra.go              ≤80 líneas — bosctl node/scale/maintain
    └── [resto existente OK sin cambios]

internal/
├── audit/          auditLog centralizado con godoc ADR-003
├── bootstrap/      autoBootstrap + kubeconfig + check* + paths
├── cgroup/         verifyCgroupDelegation + isBareMetal
├── network/        nftables + bridge
├── observer/       runObserverLoop + DAG topológico + mutex sync.Mutex
├── paths/          todas las constantes de paths canónicos
├── context/        Context Plane completo: dctx_id + ctx_id (SBOS-049)
├── tui/
│   ├── model/      struct model (campo único screen), handlers TEA puros
│   ├── styles/     lipgloss constants — sin deps bubbletea
│   ├── screens/    un archivo por pantalla (15 archivos)
│   └── demo/       modo simulación
├── biaos/
│   ├── gateway.go  singleton LLM (sync.Once) + circuit breaker
│   ├── agent.go    loop ReAct en Go puro
│   ├── icap/       ICAP Engine + action_catalog.yml + embeddings
│   ├── sagas/      SagaEngine con DAG, compensación, persistencia
│   └── safety.go   guardrails RBAC + HITL
├── scaler/         escalado coordinado HPA+VPA anti-death-spiral
├── maintenance/    saga cordon→drain→op→uncordon con compensación
├── metrics/        exportación Prometheus de SLOs
├── k8s/core.go     extendido con Scale/Cordon/Uncordon/Drain/Evict
├── security/       [rbac_provider.go eliminado por ADR-006]
└── server/jsonrpc.go extendido con 20+ nuevos métodos

_legacy/            código original preservado como memoria del proyecto
.github/workflows/  pipeline CI/CD con go test -race obligatorio
docs/runbooks/      RB-01, RB-02, RB-03 operacionales
```

---

## PARTE IV — PLAN DE REPARACIÓN: 11 FASES, 85 ÁTOMOS

### CONVENCIONES DE ESTA SECCIÓN

Cada átomo usa esta estructura:
```
### Átomo F[X.Y] — [nombre]
**Objetivo:** [una oración]
**Problema que resuelve:** [Px o descripción]
**Requiere previo:** [átomo anterior si aplica]
**Archivos:** [archivo principal afectado]
**Tarea:** [los pasos exactos]
**DoD específico:** [criterios adicionales al DoD-Universal]
**Script de validación:** [comando bash exacto]
**Informe de Cierre:** requerido ✅
```

---

## FASE 0 — Fundación e Infraestructura del Plan
**Estimado:** 4 horas | **Estado:** 🔴 NO INICIADA | **Bloquea:** TODO

---

### Átomo F0.1 — Directorio `_legacy/` y memoria del proyecto

**Objetivo:** Crear la infraestructura de preservación de código antes de tocar cualquier archivo.

**Tarea:**
```bash
mkdir -p _legacy/
cat > _legacy/README.md << 'EOF'
# _legacy/ — Memoria del Proyecto BOS-REPAIR

Este directorio preserva todo el código original extraído durante la reparación.
NUNCA eliminar archivos de aquí. Son la referencia histórica y fuente de recuperación.

## Índice de archivos archivados

| Archivo | Fase | Origen | Fecha | Qué resolvía | Informe de Cierre |
|---|---|---|---|---|---|
| (vacío — se completa en cada átomo) | | | | | |
EOF
```

**DoD específico:**
```
[ ] _legacy/README.md existe con tabla de índice
[ ] _legacy/ está trackeado en git (no en .gitignore)
[ ] go build ./... pasa (el directorio no interfiere con el módulo Go)
```

**Script de validación:**
```bash
[ -f _legacy/README.md ] && echo "✅" || echo "❌"
grep "_legacy" .gitignore 2>/dev/null && echo "❌ en gitignore" || echo "✅ no en gitignore"
go build ./... && echo "✅ build OK"
```

---

### Átomo F0.2 — Estructura de paquetes vacíos (`doc.go` × 11)

**Objetivo:** Crear los 11 paquetes `internal/` nuevos con sus `doc.go` de godoc completo.

**Tarea:** Para cada paquete, crear el `doc.go` siguiendo la estructura de 6 secciones de ADR-003:
```
internal/audit/doc.go      — audit log ISO 27001 A.8.15
internal/bootstrap/doc.go  — bootstrap + criterios C-01..C-08
internal/cgroup/doc.go     — delegación cgroups K8s
internal/network/doc.go    — reglas nftables K8s
internal/observer/doc.go   — loop reactivo + mutex anti-race P6/P14
internal/paths/doc.go      — paths canónicos centralizados (P16)
internal/context/doc.go    — Context Plane SBOS-049
internal/biaos/doc.go      — gateway IA + agente OS
internal/scaler/doc.go     — escalado anti-death-spiral ADR-004
internal/maintenance/doc.go— saga cordon→drain→uncordon ADR-004
internal/metrics/doc.go    — métricas Prometheus SLOs
```

**DoD específico:**
```
[ ] 11 archivos doc.go creados
[ ] Cada doc.go tiene las 6 secciones de ADR-003
[ ] Cada doc.go referencia el ADR o documento SBOS relevante
[ ] go build ./internal/... pasa (paquetes vacíos compilan)
```

**Script de validación:**
```bash
for pkg in audit bootstrap cgroup network observer paths context biaos scaler maintenance metrics; do
  [ -f "internal/$pkg/doc.go" ] \
    && grep -q "Responsabilidades" "internal/$pkg/doc.go" \
    && echo "✅ $pkg" || echo "❌ $pkg"
done
go build ./internal/... && echo "✅ todos compilan"
```

---

### Átomo F0.3 — `internal/tui/` — estructura de subpaquetes

**Objetivo:** Crear la estructura del paquete TUI según la arquitectura objetivo.

**Tarea:**
```
internal/tui/doc.go          — Package tui: interfaz de terminal del instalador
internal/tui/model/doc.go    — Package model: modelo TEA puro (P3, P11)
internal/tui/styles/doc.go   — Package styles: variables lipgloss sin bubbletea
internal/tui/screens/doc.go  — Package screens: renderizado por pantalla
internal/tui/demo/doc.go     — Package demo: modo simulación sin daemon
```

Además crear `internal/tui/POLICY.md` con:
- Inventario de las 15 pantallas actuales con grupo y viewport asignado
- Política de adición de nuevas pantallas (7 reglas)
- Proceso de modificación de pantallas existentes

**DoD específico:**
```
[ ] 5 archivos doc.go en internal/tui/
[ ] internal/tui/POLICY.md con inventario completo de 15 pantallas
[ ] go build ./internal/tui/... pasa
```

---

### Átomo F0.4 — `internal/paths/paths.go` — centralización de paths (P16)

**Objetivo:** Eliminar P16 — paths hardcodeados en 12+ lugares. Un único archivo con todas las constantes.

**Tarea:**
```go
// internal/paths/paths.go
package paths

// Paths canónicos del sistema bos — R16 Zero Hardcoding (config.go).
// NUNCA usar strings literales de paths en otros paquetes.
// Si falta un path, agregarlo aquí, no en el caller.
const (
  VarLibBos      = "/var/lib/bos"
  VarLogBos      = "/var/log/bos"
  AuditLog       = "/var/log/bos/audit.log"
  AIAuditLog     = "/var/log/bos/ai-audit.log"
  EtcBos         = "/etc/bos"
  InstallToml    = "/etc/bos/bos-install.toml"
  BosToml        = "/etc/bos/bos.toml"
  RunBos         = "/run/bos"
  SocketPath     = "/run/bos/bos.sock"
  PidFile        = "/run/bos/bos.pid"
  StatePath      = "/etc/bos/.sbos_state.json"
  KubeconfigPath = "/etc/bos/.kube/config"
  CorePath       = "/opt/bos/core"
  BinPath        = "/opt/bos/bin"
  SagasStore     = "/var/lib/bos/ai/sagas"
  CatalogVectors = "/var/lib/bos/ai/catalog-vectors.bin"
  ServersPath    = "/etc/bos/blibs/servers"
  MasterScript   = "/opt/bos/core/00_MASTER_INSTALL_SBOS.sh"
)
```

**DoD específico:**
```
[ ] internal/paths/paths.go con ≥15 constantes
[ ] TestPaths_ConstantesNoVacias pasa
[ ] go test ./internal/paths/ pasa
```

**Script de validación:**
```bash
grep -c "= \"/var\|= \"/etc\|= \"/opt\|= \"/run" internal/paths/paths.go | grep -E "^[1-9][0-9]" && echo "✅ ≥10 paths"
go test ./internal/paths/ && echo "✅ tests OK"
```

---

### Átomo F0.5 — Pipeline CI/CD (cierra GAP 1)

**Objetivo:** Crear pipeline que ejecute `go test -race` en cada commit.

**Tarea:** Crear `.github/workflows/bos-repair.yml` (o equivalente según el sistema de CI del proyecto):
```yaml
name: BOS-REPAIR Quality Gates
on: [push, pull_request]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version: '1.25' }
      - name: Build
        run: go build ./...
      - name: Vet
        run: go vet ./...
      - name: Format check
        run: gofmt -l . | wc -l | grep "^0$"
      - name: Race tests (×10)
        env: { GORACE: "halt_on_error=1" }
        run: go test -race -count=10 -timeout=5m ./...
      - name: Coverage internal/
        run: |
          go test -cover ./internal/... 2>&1 | \
          awk '/coverage:/ && $2+0 < 60 {found=1; print "LOW COVERAGE: "$0} END {exit found}'
```

**DoD específico:**
```
[ ] Archivo de pipeline creado
[ ] GORACE=halt_on_error=1 configurado (falla al primer DATA RACE)
[ ] Timeout configurado (evita que el pipeline cuelgue indefinidamente)
[ ] Documentado en _legacy/README.md como "infraestructura del plan"
```

---

### Átomo F0.6 — Documentación de entornos (cierra GAP 2)

**Objetivo:** Documentar los 3 entornos y las variables de feature flags.

**Tarea:** Crear `docs/ENVIRONMENTS.md`:
```markdown
# Entornos BOS-REPAIR

## DEV — laptop/VM del desarrollador
Variables: BOS_ENV=development, BOS_DEV_SKIP_ROOT=1
Feature flags de migración: BOS_OBSERVER_V2=false (por defecto)
Tests: go test -race ./... ejecuta en local antes de cada commit

## STAGING — servidor de validación
Variables: BOS_ENV=staging
Feature flags: activar uno a uno para validar cada extracción
Criterio de paso: bosctl bootstrap verify --full → 14/14 OK

## PROD — servidor skull
Variables: BOS_ENV=production
Solo átomos certificados en staging llegan aquí
Cambios via: feature flags + bosctl vdi test-repair
```

---

### Átomo F0.7 — Limpieza pre-reparación: archivar residuos a `_legacy/`

**Objetivo:** Eliminar la colisión entre código residual no documentado y el nuevo
código modular que el agente construirá en fases F1-F10. Los paquetes archivados
son **solo referencia de lógica** — el agente implementador DEBE construir desde
cero usando el `doc.go` de cada nuevo paquete como contrato irrenunciable.

**Estrategia:** COPY (no mover) — los originales se mantienen en `internal/` para
que el build siga verde. Las copias en `_legacy/` son la referencia. Las fases
correspondientes eliminarán los originales al crear los reemplazos.

**⛔ ADVERTENCIA PARA EL AGENTE IMPLEMENTADOR:**
El código en `_legacy/` NO se copia ni se refactoriza. Es referencia de lógica
únicamente. Ver `_legacy/2026-06-09_F0.7_*/LEEME-ADVERTENCIA.md` para las reglas.

**Archivos archivados:**

| Copia en `_legacy/` | Origen | Fase que elimina original | Nuevo paquete |
|---|---|---|---|
| `2026-06-09_F0.7_ai/` | `internal/ai/` | F10.2 | `internal/biaos/` |
| `2026-06-09_F0.7_observability/` | `internal/observability/` | F9.6 | `internal/metrics/` |
| `2026-06-09_F0.7_repair/` | `internal/repair/` | F9.3-F9.4 | `internal/scaler/` + `internal/maintenance/` |
| `2026-06-09_F0.7_server_api.go` | `internal/server/api.go` | F2 | `internal/server/ws.go` extendido |
| `2026-06-09_F0.7_server_bootstrap.go` | `internal/server/bootstrap.go` | F1.2 | `internal/bootstrap/` |
| `2026-06-09_F0.7_security_rbac_provider.go` | `internal/security/rbac_provider.go` | F4.4 | bAuth asume RBAC |
| `2026-06-09_F0.7_security_identity_provider.go` | `internal/security/identity_provider.go` | F4.4 | bAuth asume identidad |

**Qué lógica rescatar (referencia únicamente):**
- `_legacy/.../ai/` → Circuit breaker 3-tiers, cliente Anthropic/Ollama/OpenAI, context builder
- `_legacy/.../observability/` → Estructura HealthReport por capas (Ubuntu/K8s/BOS)
- `_legacy/.../repair/` → RepairManager multi-fase, OSRepairer, K8sNodeRepairer, HealthVerifier

**Verificación:**
```bash
# Los archivos originales siguen presentes (build verde):
[ -f internal/ai/client.go ] && echo "✅ original ai/ presente" || echo "❌"
[ -f internal/repair/repair_manager.go ] && echo "✅ original repair/ presente" || echo "❌"

# Las copias de referencia existen:
[ -d _legacy/2026-06-09_F0.7_ai ] && echo "✅ copia ai/" || echo "❌"
[ -d _legacy/2026-06-09_F0.7_repair ] && echo "✅ copia repair/" || echo "❌"
[ -f _legacy/2026-06-09_F0.7_ai/LEEME-ADVERTENCIA.md ] && echo "✅ advertencia" || echo "❌"

# Build sigue verde:
go build ./... && echo "✅ build OK"
```

---

### Verificación de Cierre de Fase 0

```bash
echo "=== CIERRE FASE 0 ==="
ls _legacy/README.md && echo "✅ _legacy/" || echo "❌"
find internal/ -name "doc.go" | wc -l | grep -E "^1[6-9]|^[2-9][0-9]" && echo "✅ ≥16 doc.go" || echo "❌"
[ -f internal/paths/paths.go ] && echo "✅ paths" || echo "❌"
[ -f docs/ENVIRONMENTS.md ] && echo "✅ entornos" || echo "❌"
go build ./... && echo "✅ build OK" || echo "❌"
```

---

## FASE 1 — Extraer Infraestructura de `cmd/bos/main.go`
**Estimado:** 2-3 días | **Estado:** 🔴 | **Requiere:** F0 completa | **Problemas:** P4, P6/P14, P12, P15, P16

---

### Átomo F1.1 — `auditLog()` → `internal/audit/`

**Objetivo:** La función `auditLog()` dispersa en `main.go` pasa a paquete propio.

**Archivos afectados:**
- CREA: `internal/audit/log.go`, `internal/audit/log_test.go`
- MODIFICA: `cmd/bos/main.go` (vacía la función, agrega import)
- ARCHIVA: `_legacy/YYYY-MM-DD_F1.1_audit_log_original.go`

**Tarea:**
```
PASO 1: cp <bloque auditLog de main.go> _legacy/YYYY-MM-DD_F1.1_audit_log_original.go
PASO 2: Crear internal/audit/log.go con godoc 6-secciones ADR-003
PASO 3: Crear internal/audit/log_test.go:
        - TestLog_EscribeEnArchivo
        - TestLog_FormatoISO27001 (timestamp + user + operation + result)
        - TestLog_CreaArchivoSiNoExiste
        - TestLog_IdempotenteConcurrencia (goroutines paralelas)
PASO 4: go test -race -count=20 ./internal/audit/ → verde
PASO 5: En main.go: import "bos/internal/audit"; reemplazar auditLog() por audit.Log()
PASO 6: La función original queda: func auditLog(...) { /* migrado a internal/audit F1.1 */ }
PASO 7: go build ./... → verde
PASO 8: Actualizar _legacy/README.md con la entrada de F1.1
```

**DoD específico:**
```
[ ] _legacy/YYYY-MM-DD_F1.1_audit_log_original.go existe
[ ] TestLog_EscribeEnArchivo pasa
[ ] TestLog_FormatoISO27001 pasa — el log tiene timestamp, user, op, result
[ ] TestLog_IdempotenteConcurrencia pasa con -race -count=20
[ ] cmd/bos/main.go usa audit.Log() — no define auditLog() con lógica
[ ] Godoc en internal/audit/ referencia ISO 27001 A.8.15
```

**Script de validación:**
```bash
go test -race -count=20 -v ./internal/audit/ && echo "✅ audit 20×OK"
grep "audit.Log" cmd/bos/main.go | wc -l | grep -E "^[1-9]" && echo "✅ usando nuevo paquete"
grep -c "func auditLog" cmd/bos/main.go | grep "^1$" && echo "✅ función stub presente"
```

---

### Átomo F1.2 — `autoBootstrap()` → `internal/bootstrap/`

**Objetivo:** Extraer la lógica de preparación del sistema operativo a su paquete propio.

**Archivos afectados:**
- CREA: `internal/bootstrap/bootstrap.go`, `internal/bootstrap/bootstrap_test.go`
- ARCHIVA: `_legacy/YYYY-MM-DD_F1.2_auto_bootstrap.go`

**Tarea:**
```
PASO 1: Archivar autoBootstrap() y funciones auxiliares en _legacy/
PASO 2: Crear internal/bootstrap/bootstrap.go:
        func AutoBootstrap(cfg Config) error
        func VerifyC01() (bool, string)  -- sbos-bootstrap-os
        func VerifyC02() (bool, string)  -- sbos-bootstrap-k8s
        ...hasta VerifyC08()
PASO 3: Tests:
        - TestAutoBootstrap_IdempotentEnSegundaEjecucion
        - TestVerifyC01_SysctlPresente
        - TestVerifyC02_KubeconfigPresente
        - TestVerifyAll_C01aLC08
PASO 4: Feature flag: BOS_BOOTSTRAP_V2=true activa nuevo paquete
PASO 5: go test -race ./internal/bootstrap/ → verde
```

**DoD específico:**
```
[ ] TestAutoBootstrap_IdempotentEnSegundaEjecucion pasa — idempotencia verificada
[ ] TestVerifyC01 .. TestVerifyC08 pasan
[ ] Feature flag BOS_BOOTSTRAP_V2 funciona
[ ] Godoc referencia criterios C-01..C-08 de BOS-REPAIR-01
```

---

### Átomo F1.3 — `verifyCgroupDelegation()` → `internal/cgroup/`

**Objetivo:** Extraer la lógica de cgroups para K8s.

**Tests requeridos:**
```
- TestCgroup_IsBareMetal — detecta bare metal correctamente
- TestCgroup_IsContainer — detecta contenedor correctamente
- TestCgroupDelegate_ConfiguraSystemd — verifica la configuración
```

---

### Átomo F1.4 — `ensureBridgeNetwork()` → `internal/network/`

**Objetivo:** Extraer reglas nftables del main.

**Tests requeridos:**
```
- TestNetwork_DetectaSubnet — detecta la subnet del host
- TestNetwork_ReglaNftables_Formato — la regla tiene el formato correcto
```

---

### Átomo F1.5 — Observer loop → `internal/observer/` CON MUTEX (P6/P14 — crítico)

**Objetivo:** Resolver la race condition más crítica del sistema. El observer y el reconciler no pueden disparar Repair() en paralelo sobre la misma ficha.

**Este es el átomo de mayor impacto del plan.**

**Archivos afectados:**
- CREA: `internal/observer/observer.go`, `internal/observer/observer_test.go`
- ARCHIVA: `_legacy/YYYY-MM-DD_F1.5_observer_loop_sin_mutex.go`
- ARCHIVA: `_legacy/YYYY-MM-DD_F1.5_topological_sort_duplicado.go`

**Estructura del código nuevo:**
```go
// internal/observer/observer.go
type Observer struct {
    mu         sync.Mutex  // protege contra repair paralelo con reconciler
    orchestrator installer.Orchestrator
    loader      *plugin.Loader
    stateMgr    *state.Manager
    stopCh      chan struct{}
    logger      *slog.Logger
}

// Run inicia el loop de observación. El mutex garantiza que
// Repair() nunca se ejecuta en paralelo desde observer ni desde reconciler.
// Ver: P6/P14 en BOS-REPAIR-00, ADR-021.
func (o *Observer) Run() { ... }

// RepairFicha adquiere el mutex antes de reparar.
// Garantía: si reconciler.Scheduler llama Repair() al mismo tiempo,
// uno de los dos espera — no se ejecutan en paralelo.
func (o *Observer) RepairFicha(fichaID string) error {
    o.mu.Lock()
    defer o.mu.Unlock()
    // ...
}
```

**Tests críticos (deben pasar 100/100 con -race):**
```go
// TestObserver_NoParallelRepair — el test más importante del proyecto
func TestObserver_NoParallelRepair(t *testing.T) {
    // Simular: 2 goroutines intentan reparar la misma ficha simultáneamente
    // Verificar: Repair() se ejecuta exactamente UNA vez, no dos
    // Métrica: contador de llamadas debe ser == 1 al final
}

// TestTopologicalSort_DAGDe22Fichas
func TestTopologicalSort_DAGDe22Fichas(t *testing.T) {
    // postgresql ANTES que keycloak
    // sbos-bootstrap-k8s ANTES que postgresql
    // Todas las 22 fichas en el orden correcto
}

// TestObserver_MutexPreventsDoubleRepair — test de stress
func TestObserver_MutexPreventsDoubleRepair(t *testing.T) {
    // 10 goroutines intentan reparar al mismo tiempo
    // Exactamente 1 reparación exitosa
}
```

**DoD específico (el más estricto del plan):**
```
[ ] go test -race -count=100 ./internal/observer/ = 100/100 sin DATA RACE
[ ] TestObserver_NoParallelRepair pasa 100/100
[ ] TestTopologicalSort_DAGDe22Fichas pasa con las 22 fichas del stack
[ ] El godoc menciona explícitamente P6/P14 y el mutex como solución
[ ] _legacy/ tiene AMBOS archivos archivados: loop y topological_sort
```

**Script de validación:**
```bash
echo "Test crítico de race condition:"
go test -race -count=100 -timeout=10m -v ./internal/observer/ \
  -run TestObserver_NoParallelRepair 2>&1 | \
  grep -E "PASS|FAIL|DATA RACE" | tail -5
echo "(debe mostrar PASS 100 veces, NUNCA DATA RACE)"
```

---

### Átomo F1.6 — Activar `startWatchdog()` (P12)

**Objetivo:** Corregir P12 — `startWatchdog()` existe pero nunca se llama. Sin esto, systemd puede matar el daemon si `WatchdogSec` está configurado.

**Tarea:**
```
PASO 1: En cmd/bos/main.go:runNormal() agregar: go startWatchdog(stopCh)
        Posición: ANTES de go unifiedWatchdog.Run()
PASO 2: Crear test: TestStartWatchdog_EnviaWATCHDOG1
PASO 3: Documentar en el Informe de Cierre: por qué nunca fue llamada
```

**DoD específico:**
```
[ ] grep "startWatchdog" cmd/bos/main.go muestra la llamada en runNormal()
[ ] TestStartWatchdog_EnviaWATCHDOG1 pasa
[ ] Informe incluye: "Análisis de por qué P12 ocurrió: bug de omisión durante refactor de main.go"
```

---

### Átomo F1.7 — Reducir `cmd/bos/main.go` a ≤350 líneas (progreso F1)

**Objetivo:** Verificar el progreso al final de Fase 1. El objetivo final (≤200 líneas) se alcanza en Fase 4, pero al terminar F1 debe estar en ≤350.

**Tarea:**
```bash
# Verificar progreso
wc -l cmd/bos/main.go
echo "(objetivo al cierre de F1: ≤350 líneas)"
echo "(objetivo final F4: ≤200 líneas)"

# Si superó 350: identificar qué funciones aún están en main.go
# y crear átomos adicionales F1.8, F1.9 para extraerlas
```

---

### Verificación de Cierre de Fase 1

```bash
echo "=== CIERRE FASE 1 ==="
go test -race -count=10 ./internal/audit/ ./internal/bootstrap/ \
  ./internal/cgroup/ ./internal/network/ ./internal/observer/ \
  && echo "✅ todos los tests pasan sin race conditions"
wc -l cmd/bos/main.go
echo "(debe ser ≤350 al cierre de F1)"
ls _legacy/*F1.*.go | wc -l
echo "(debe ser ≥5 archivos archivados)"
grep "startWatchdog" cmd/bos/main.go | grep -v "func " && echo "✅ watchdog activo"
```

---

## FASE 2 — Unificar WebSocket
**Estimado:** 1 día | **Requiere:** F1 | **Problemas:** P2, P8

---

### Átomo F2.1 — Extender `internal/wslib/` con capacidades faltantes

**Objetivo:** Antes de migrar, verificar que wslib puede reemplazar gorilla completamente.

**Tarea:**
```
Capacidades que usa cmd/bosctl/ de gorilla:
  A) Conexión síncrona (wsRequest): dial + send + recv + close
  B) Conexión persistente async (connectWS): goroutines + canal de eventos
  C) Reconexión automática tras error

Verificar que wslib tiene A, B, C. Si falta algo:
  → Agregar a wslib (NO a cmd/)
  → Tests: TestDialSync_SendRecv, TestDialAsync_CanalEventos, TestDial_Reconecta
```

**DoD específico:**
```
[ ] wslib puede hacer A, B y C documentado en godoc
[ ] TestDialSync_SendRecv pasa
[ ] TestDial_Reconecta pasa con go test -race -count=20
```

---

### Átomo F2.2 — Migrar `wsRequest()` de bosctl a wslib

**Tarea:**
```
PASO 1: Archivar wsRequest() con gorilla en _legacy/
PASO 2: Reescribir usando wslib
PASO 3: go test -race -count=20 en bosctl
```

---

### Átomo F2.3 — Migrar `connectWS/sendWS/awaitWS` de install_ui a wslib

**Nota crítica:** El comentario original documenta un comportamiento específico de gorilla: "tras error en ReadMessage NO volver a llamar ReadMessage". Verificar si wslib tiene el mismo comportamiento y documentarlo explícitamente en wslib/doc.go.

**Tests requeridos:**
```
TestConnectWS_ReconectaTrasError — reconexión automática
TestAwaitWS_NoSePierdenEventos  — garantía de no pérdida
```

---

### Átomo F2.4 — Eliminar gorilla de go.mod

**Tarea:**
```bash
# Solo cuando F2.2 y F2.3 están ✅
go mod tidy
grep "gorilla/websocket" go.mod && echo "❌" || echo "✅ eliminado"
go build ./... && echo "✅"
```

---

## FASE 3 — Partir `install_ui.go` (4,834 → ≤80 líneas)
**Estimado:** 4-5 días | **Requiere:** F0.3 + F2 | **Problemas:** P1, P3, P7, P10, P11

El orden de extracción sigue la regla de dependencias: de menos a más dependencias.

---

### Átomo F3.1 — Extraer `internal/tui/styles/styles.go`

**Objetivo:** Colores, estilos lipgloss, helpers visuales — sin dependencia en bubbletea.

**Contenido a extraer:**
```
De install_ui.go:
  - Constantes cGreenS, cCyanS, cBlackS, cBg2S, ... (≈15 constantes)
  - Variables lipgloss cGreen, cCyan, sBold, sBox, sTopBar, ... (≈20 variables)
  - Funciones: icOk(), icRun(), icPend(), icErr(), icWarn(), icBos()
  - Helpers: badge(), renderMFARow()
```

**Tests:**
```
TestStyles_TodosLosIconosRetornanString — ningún icono retorna vacío
TestStyles_ColoresNoVacios              — ninguna constante de color vacía
TestStyles_SinDependenciaBubbleTea      — import no incluye bubbletea
```

---

### Átomo F3.2 — Crear `internal/tui/model/types.go` — Screen como única verdad (P11)

**Objetivo:** Definir el tipo `Screen` con 15 constantes y las funciones de clasificación. Eliminar el alias `stepID` incorrecto y el campo `step` duplicado.

**Contenido:**
```go
// types.go — Screen es LA única fuente de verdad para la pantalla activa.
// El campo model.step (antiguo) se elimina en F3.3.
// El alias stepID = Screen y las constantes step* se eliminan aquí.

type Screen int
const (
  ScreenWelcome    Screen = iota  // S00 — splash inicial
  ScreenWizardP1                   // S01 — bienvenida wizard
  ScreenWizardP2                   // S02 — datos empresa
  ScreenWizardP3                   // S03 — cuenta admin + MFA
  ScreenWizardP4                   // S04 — confirmación
  ScreenInstalling                  // S05 — instalación 3 columnas
  ScreenInstallLog                  // S06 — log completo
  ScreenInstallErr                  // S07 — panel de error
  ScreenInstallDone                 // S08 — completada
  ScreenReboot                      // S09 — cuenta regresiva
  ScreenBoot                        // S10 — arranque
  ScreenDashboard                   // S11 — panel permanente
  ScreenLogs                        // S12 — logs con filtros
  ScreenShutdown                    // S13 — apagado
  ScreenGoodbye                     // S14 — splash de cierre
)

// Group clasifica cada pantalla — determina layout y viewport.
func (s Screen) Group() ScreenGroup { ... }
// NeedsStepper retorna true para el wizard (S01-S05).
func (s Screen) NeedsStepper() bool { ... }
// ViewportKind retorna el viewport asignado a cada pantalla.
func (s Screen) ViewportKind() string { ... }
```

**Tests:**
```
TestScreen_15ConstantesRegistradas
TestScreen_GruposCorrectos     — S00,S14 = Splash; S01-S04 = Wizard; etc.
TestScreen_ViewportKindCorrectos — S05 → "vpABC"; S11 → "vpDash"
TestScreen_StepIDAliasEliminado — compilar sin stepID
```

---

### Átomo F3.3 — `internal/tui/model/model.go` — campo único `screen` + `setScreen()` pura

**Objetivo:** Struct `model` con UN solo campo para la pantalla activa. `setScreen()` es función pura.

**Tests:**
```
TestSetScreen_CampoUnicoScreen     — m.step NO existe en el nuevo modelo
TestSetScreen_ShowStepperCorrecto  — wizard P1-P4 + installing = true
TestSetScreen_ActualizaBodyHeight  — height recalculado al cambiar pantalla
```

---

### Átomo F3.4 — `internal/tui/model/events.go` — tipos de mensajes WS

**Objetivo:** Separar los tipos de mensajes del modelo.

```go
// events.go define los mensajes que fluyen por el canal WS del TUI.
type wsEventMsg struct { evType, ficha, step, msg string; total int; ... }
type wsReadyMsg  struct { conn net.Conn }
type wsErrorMsg  struct { err error }
type sysInfoMsg  struct { info sysInfo }
```

---

### Átomo F3.5 — `internal/tui/demo/demo.go` — modo simulación

**Objetivo:** El modo demo a su propio paquete.

**Tests:**
```
TestDemo_GeneraEventosCorrectos — los eventos del demo siguen el formato wsEventMsg
TestDemo_CubireTodasLasFichas   — el demo genera eventos para las 22 fichas
```

---

### Átomo F3.6 — Corrección TEA: handlers como funciones puras (P3) — CRÍTICO

**Objetivo:** Resolver P3 — la violación del patrón TEA. El bug central: `handleWS()` y handlers usan receptor `*model` mutando estado. Deben ser funciones puras.

**Crear `internal/tui/model/ws_handlers.go`:**
```go
// ws_handlers.go — TODOS los handlers son funciones puras.
// Política TEA (POLÍTICA-CÓDIGO-05): reciben model por valor, retornan model nuevo.
// NINGUNA función aquí usa receptor *model.

func handleWS(m model, ev wsEventMsg) model { ... }
func handleBootstrapStatus(m model, data map[string]interface{}) model { ... }
func handleFichaUpdate(m model, ev wsEventMsg) model { ... }
func handleBootstrapComplete(m model, ev wsEventMsg) model { ... }
```

**Tests críticos:**
```go
// TestHandleWS_NoMutaModeloOriginal — el test canónico de pureza TEA
func TestHandleWS_NoMutaModeloOriginal(t *testing.T) {
    m1 := newTestModel()
    m2 := handleWS(m1, wsEventMsg{evType: "saga_ok", ficha: "redis"})
    assert.Equal(t, 0, m1.fichasOK, "modelo original no debe cambiar")
    assert.Equal(t, 1, m2.fichasOK, "modelo nuevo debe tener el cambio")
    assert.NotSame(t, &m1, &m2, "son objetos distintos")
}
TestHandleWS_20EventosConcurrentes — go test -race -count=50
```

**DoD específico:**
```
[ ] grep -rn "func (m \*model)" internal/tui/ retorna VACÍO
[ ] TestHandleWS_NoMutaModeloOriginal pasa
[ ] go test -race -count=50 ./internal/tui/model/ pasa 50/50
```

---

### Átomo F3.7 — `internal/tui/model/viewport.go` — punto de verdad único (P10)

**Objetivo:** `ViewportManager` sincroniza todos los viewports desde una única fuente de verdad.

**Tests:**
```
TestViewportManager_SyncAllConsistente — vpA,vpB,vpC tienen mismo height post-sync
TestViewportManager_NoPuedeDiverger    — imposible que vpA tenga datos viejos
```

---

### Átomo F3.8 — `internal/tui/screens/` — 15 archivos, uno por pantalla

**Objetivo:** Un archivo de rendering por cada pantalla del inventario.

**Sub-átomos por grupo** (cada sub-átomo tiene sus propios tests):

```
F3.8.A — Grupo Splash (2 archivos):
  screen_welcome.go  — viewSplashWelcome()
  screen_goodbye.go  — viewSplashGoodbye()
  Test por archivo: TestScreen<N>_RenderSinPanic, TestScreen<N>_AnchoMinimo40

F3.8.B — Grupo Wizard (4 archivos):
  screen_wizard_p1.go  — viewWelcome()
  screen_wizard_p2.go  — viewFormTenant() + validación
  screen_wizard_p3.go  — viewFormAdmin() + MFA
  screen_wizard_p4.go  — viewConfirm()
  Test por archivo: +TestScreen<N>_FormValidacion

F3.8.C — Grupo Install (3 archivos):
  screen_installing.go  — viewInstalling() + buildColA/B/C
  screen_install_log.go — viewFullLog()
  screen_install_err.go — viewInstallErr()
  Test: TestScreenInstalling_TresColumnasConsistentes

F3.8.D — Grupo Post (3 archivos):
  screen_install_done.go, screen_reboot.go, screen_boot.go
  Test: TestScreenReboot_CuentaRegressivaDecrementa

F3.8.E — Grupo Runtime (3 archivos):
  screen_dashboard.go, screen_logs.go, screen_shutdown.go
  Test: TestScreenLogs_FiltrosAplicados, TestScreenDashboard_MuestraEstado
```

**DoD F3.8:**
```
[ ] 15 archivos en internal/tui/screens/
[ ] Cada archivo ≤200 líneas
[ ] TestScreen<N>_RenderSinPanic para cada pantalla
[ ] go test -race ./internal/tui/screens/ pasa
```

---

### Átomo F3.9 — `internal/tui/model/keys.go` — navegación por teclado

**Objetivo:** La función `handleKey()` desglosada por grupo de pantalla, como funciones puras.

```go
func handleKey(m model, msg tea.KeyMsg) (model, tea.Cmd)
func handleKeyWizard(m model, msg tea.KeyMsg) (model, tea.Cmd)
func handleKeyInstalling(m model, msg tea.KeyMsg) (model, tea.Cmd)
func handleKeyRuntime(m model, msg tea.KeyMsg) (model, tea.Cmd)
```

---

### Átomo F3.10 — Reducir `install_ui.go` a ≤80 líneas

**Objetivo:** El archivo final solo contiene entry points CLI.

**Tarea:**
```
Contenido final de install_ui.go:
  - cmdInstallUI() — cobra command
  - runInteractiveTUI() — inicializa tea.Program
  - runUnattended() — modo no interactivo
  Total: ≤80 líneas, CERO funciones de rendering o lógica

Archivar versión completa en:
  _legacy/YYYY-MM-DD_F3.10_install_ui_original_4834_lineas.go
  (el archivo más importante de _legacy/ — referencia histórica del proyecto)
```

**Script de validación de Cierre de Fase 3:**
```bash
echo "=== CIERRE FASE 3 ==="
wc -l cmd/bosctl/install_ui.go
echo "(debe ser ≤80)"
ls internal/tui/screens/screen_*.go | wc -l
echo "(debe ser 15)"
grep -rn "func (m \*model)" internal/tui/ && echo "❌ TEA violado" || echo "✅ TEA puro"
grep -rn "step   Screen\|m\.step " internal/tui/ && echo "❌ step presente" || echo "✅ step eliminado"
go test -race -count=20 ./internal/tui/... && echo "✅ TUI tests OK"
bosctl install --demo --dry-run && echo "✅ demo funciona"
```

---

## FASE 4 — Limpiar `cmd/bosctl/` y Eliminar RBAC Propio
**Estimado:** 2 días | **Requiere:** F3 | **Problemas:** P5, P7, P9, P15, ADR-006

---

### Átomo F4.1 — Centralizar kubeconfig (P5 — duplicación ×6)

```
PASO 1: Archivar las 6 versiones en _legacy/YYYY-MM-DD_F4.1_kubeconfig_x6.go
PASO 2: Crear internal/bootstrap/kubeconfig.go:
        func ResolveKubeconfig(cfg *config.Config) string
        Prioridad: KUBECONFIG env > bos.toml > cfg.Install.KubeconfigPath > paths.KubeconfigPath
PASO 3: Tests:
        TestResolveKubeconfig_UsaEnvVar
        TestResolveKubeconfig_UsaToml
        TestResolveKubeconfig_UsaDefault
        TestResolveKubeconfig_IgnoraVacioYUsaSiguiente
PASO 4: grep -rn "kubeconfig := os.Getenv" cmd/ = vacío
```

---

### Átomo F4.2 — Corregir `ensureDaemonRunning()` con rollback (P9)

**Tests:**
```
TestEnsureDaemonRunning_NoSobrescribeProduccion — si install.toml tiene datos reales, no sobreescribe
TestEnsureDaemonRunning_RollbackEnFallo         — si falla a mitad, hace rollback de directorios
TestEnsureDaemonRunning_NoMataProcesoLegitimo   — no kill -9 si el proceso en :9443 no es bos
```

---

### Átomo F4.3 — Corregir `bosRBAC` global (P15)

```go
// ANTES (P15 — nil interface → panic):
var bosRBAC security.RBACProvider

// DESPUÉS (thread-safe):
var (
  rbacOnce sync.Once
  rbacInst security.RBACProvider
)
func getBosRBAC() security.RBACProvider {
  rbacOnce.Do(func() { rbacInst = initRBAC() })
  return rbacInst
}
```

---

### Átomo F4.4 — Implementar ADR-006: eliminar `rbac_provider.go`

**Sub-átomos:**

**F4.4.1 — Crear `/etc/sudoers.d/bos`** con política exacta de ADR-006:
```bash
# Los 4 grupos + denegaciones explícitas de ADR-006 §6.8
bosd ALL=(bos-readonly) NOPASSWD: /usr/bin/journalctl -u bos-* --no-pager
bosd ALL=(bos-operators) NOPASSWD: /usr/bin/systemctl restart bos-*
bosd ALL=(bos-maintenance) NOPASSWD: /usr/bin/systemctl stop bos-*
bosd ALL=(ALL) !/bin/bash
bosd ALL=(ALL) !/bin/sh
```

**F4.4.2 — Crear ClusterRole `bos-daemon-impersonator`** (ADR-006 §7.1)

**F4.4.3 — Archivar y eliminar `rbac_provider.go`:**
```bash
cp internal/security/rbac_provider.go _legacy/YYYY-MM-DD_F4.4_rbac_provider_eliminado.go
# Agregar al archivo: // ELIMINADO: reemplazado por ADR-006 — Ubuntu PAM + K8s RBAC
rm internal/security/rbac_provider.go
go build ./... # debe pasar sin errores
```

**Tests:**
```
TestRBAC_DelegadoUbuntu  — bosd puede ejecutar como bos-operators
TestRBAC_DelegadoK8s     — impersonation funciona correctamente
TestRBAC_DenegacionesSudoers — bosd NO puede ejecutar /bin/bash
```

---

### Átomo F4.5 — Reducir `cmd/bosctl/main.go` (≤120 líneas)

```
Extraer a cmd/bosctl/os_commands.go:
  cmdExec, cmdLS, cmdCat, cmdTail, cmdSystemctl, cmdJournalctl
Verificar:
  wc -l cmd/bosctl/main.go ≤ 120
  wc -l cmd/bosctl/bootstrap.go ≤ 100
```

---

## FASE 5 — Context Plane Completo (SBOS-049)
**Estimado:** 3-4 días | **Requiere:** F4 | **Entregable:** criterio C-13 verde

---

### Átomo F5.1 — `internal/context/types.go`

```
DeviceContext (dctx_id): hostname, tenant_id, node_k8s, ip, bitmask=0
SessionContext (ctx_id): tenant+empresa+sucursal+pos+user, bitmask>0, TTL
ContextState: PENDIENTE|ACTIVO|SUSPENDIDO|BLOQUEADO|INVALIDADO|EXPIRADO|ARCHIVADO
BitMask: uint64 — flags de permisos del usuario autenticado

Tests:
  TestContextState_7EstadosDefinidos
  TestBitMask_OperacionesBasicas (AND, OR, NOT)
  TestDeviceContext_BitMaskCero    — pre-autenticación tiene bitmask=0
  TestSessionContext_BitMaskPositivo — post-autenticación tiene bitmask>0
```

---

### Átomo F5.2 — `internal/context/service.go`

```
RegisterDevice(tenant, hostname) (*DeviceContext, error)
Promote(dctxID string, p PromoteParams) (*SessionContext, error)
Switch(ctxID string, p SwitchParams) (*SessionContext, error)
Invalidate(ctxID string) error
InvalidateAllByTenant(tenant string) (int, error)
Get(ctxID string) (*SessionContext, error)
ListByTenant(tenant string) ([]*SessionContext, error)

Tests:
  TestRegisterDevice_RetornaContextoOS
  TestPromote_EnriqueceBitMask        — bitmask 0 → positivo
  TestInvalidate_CtxYaNoValido
  TestTTL_MinimoYMaximo               — dispositivos 8h, sesiones 12h (ISO 27001 A.9.4.2)
  TestInvalidateAllByTenant_LimpiaSesiones
  TestRegisterDevice_Idempotente      — mismo hostname → mismo dctx_id
```

---

### Átomo F5.3 — `internal/context/store.go` — PostgreSQL + Redis

```
Store para DeviceContext y SessionContext:
  - Persistencia en bkernel_db (tablas registered_devices, context_sessions)
  - Cache en Redis DB1 con TTL
  - W3C Trace Context: cada operación propaga traceparent

Tests:
  TestStore_TTLExpira         — el TTL expira el contexto automáticamente
  TestStore_CacheRedis        — segunda lectura viene de Redis (< 5ms)
  TestStore_TraceparentPropagado — todas las entradas tienen traceparent
```

---

### Átomo F5.4 — 7 métodos JSON-RPC para Context Plane

```
Registrar en internal/server/jsonrpc.go:
  "bos.ctx.device.register" → rpcCtxDeviceRegister
  "bos.ctx.promote"         → rpcCtxPromote
  "bos.ctx.switch"          → rpcCtxSwitch
  "bos.ctx.invalidate"      → rpcCtxInvalidate
  "bos.ctx.get"             → rpcCtxGet
  "bos.ctx.list"            → rpcCtxList
  "bos.ctx.tenant.suspend"  → rpcCtxTenantSuspend

Tests de integración:
  TestRPC_CtxDeviceRegister_RetornaEnMenos2s — SLO C-13
  TestRPC_CtxPromote_BitMaskPositivo
  TestRPC_CtxInvalidate_YaNoValido
```

---

### Átomo F5.5 — `cmd/bosctl/context.go` — subcomandos CLI

```
bosctl ctx list [--tenant=skull]
bosctl ctx get <dctx_id_o_ctx_id>
bosctl ctx invalidate <ctx_id>
bosctl ctx stats [--tenant=skull]
```

---

### Átomo F5.6 — W3C Trace Context en todos los handlers

```
Verificar que todos los métodos RPC propagan traceparent y ctx_id.
Test: TestTraceContext_PropagadoEnTodosLosMetodos
Criterio: tail /var/log/bos/audit.log | jq .traceparent | grep -v null = 100%
```

**Verificación de Cierre de Fase 5:**
```bash
time bosctl rpc bos.ctx.device.register '{"tenant_id":"skull","hostname":"test"}'
echo "(debe responder en < 2000ms — SLO C-13)"
bosctl bootstrap verify --only=C-13 && echo "✅ C-13 OK"
go test -race ./internal/context/... && echo "✅ context plane testeado"
```

---

## FASE 6 — JSON-RPC Robusto + 6 Sagas de Consulta
**Estimado:** 2-3 días | **Requiere:** F5 | **Base normativa:** BOS-REPAIR-04 + BOS-REPAIR-12

---

### Átomos F6.1 a F6.5 — Robustez del protocolo

| ID | Átomo | DoD mínimo |
|---|---|---|
| F6.1 | Auth en métodos destructivos (repair/cordon/maintenance) | Sin token válido → -32600 Unauthorized |
| F6.2 | Timeout por categoría: 5s lectura, 30s escritura, 600s sagas | TestTimeout_LecturaExpira5s |
| F6.3 | Batch paralelo: array JSON-RPC → goroutines | TestBatch_3MetodosEnTiempoDeUno |
| F6.4 | `bos.state.read` sin hashes SHA-256 internos | jq 'has("hashes")' → false |
| F6.5 | Validación TTL ctx_id en métodos que lo requieren | Ctx expirado → -32001 ContextExpired |

---

### Átomos F6.6 a F6.11 — Las 6 sagas de consulta (BOS-REPAIR-04)

Cada saga ejecuta múltiples consultas en paralelo vía batch JSON-RPC. Tiempo objetivo: < 4s.

| ID | Método | Fuentes paralelas | Test de validación |
|---|---|---|---|
| F6.6 | `bos.query.system` | Ubuntu + K8s + fichas + config | TestQuerySystem_MenosDe4s |
| F6.7 | `bos.query.repair` | watchdog + stateMgr + healthCheck + audit | TestQueryRepair_CausaProbable |
| F6.8 | `bos.query.vdi` | Nextcloud + Guacamole + fedora-logico + home | TestQueryVdi_SemaforoVerde |
| F6.9 | `bos.query.tenant` | tenants activos + contextos + fichas por tenant | TestQueryTenant_TodosLosTenants |
| F6.10 | `bos.query.node` | nodos K8s + recursos + pods por nodo | TestQueryNode_TodosReady |
| F6.11 | `bos.query.context` | contextos activos + BitMasks + TTLs restantes | TestQueryContext_TTLsValidos |

**Script de validación de Cierre de Fase 6:**
```bash
for saga in system repair vdi tenant node context; do
  echo -n "bos.query.$saga: "
  time bosctl rpc bos.query.$saga >/dev/null 2>&1
done
echo "(ninguna debe superar 4s)"
go test -race ./internal/server/... && echo "✅ JSON-RPC testeado"
```

---

## FASE 7 — Documentación y Runbooks
**Duración:** Continua (paralela a Fases 5-10) | **Base:** ADR-003 + GAP 3

---

### Átomos F7.1 a F7.7 — Godoc por paquete

| ID | Paquete | Criterio |
|---|---|---|
| F7.1 | `internal/observer/` | Mutex y P6/P14 documentados; go doc muestra ≥3 funciones |
| F7.2 | `internal/context/` | 7 estados documentados con ejemplos; referencia SBOS-049 |
| F7.3 | `internal/bootstrap/` | Criterios C-01..C-08 en comentarios de cada VerifyC0X() |
| F7.4 | `internal/tui/model/` | Política TEA documentada; referencia a POLICY.md |
| F7.5 | `cmd/bos/README.md` | ≥50 líneas: qué es, compilar, ejecutar, env vars, modos |
| F7.6 | `cmd/bosctl/README.md` | Lista completa de subcomandos con ejemplos reales |
| F7.7 | `_legacy/README.md` | Tabla completa de todo el código archivado (≥15 entradas) |

---

### Átomo F7.8 — 3 Runbooks operacionales (cierra GAP 3)

**Crear:**
```
docs/runbooks/RB-01-FICHA-DEGRADADA.md
  Síntoma: ficha en estado DEGRADADA
  Paso 1: bosctl rpc bos.query.repair → identificar causa
  Paso 2: bosctl rpc bos.ficha.repair '{"ficha_id":"<id>"}' → reparar
  Paso 3: bosctl bootstrap verify --only=C-0X → certificar
  Tiempo esperado: < 10 minutos (SLO MTTR)

docs/runbooks/RB-02-DATA-RACE-EN-LOGS.md
  Síntoma: "DATA RACE" en /var/log/bos/bos.log
  Causa probable: F1.5 no completada o mutex removido
  Paso 1: Verificar que internal/observer/ tiene sync.Mutex
  Paso 2: go test -race -count=100 ./internal/observer/
  Paso 3: Revertir al último commit verde si la race persiste

docs/runbooks/RB-03-CONTEXT-PLANE-DOWN.md
  Síntoma: C-13 falla, dctx_id no se crea en < 2s
  Causa probable: Redis DB1 caído o PostgreSQL no accesible
  Paso 1: bosctl rpc bos.query.context → ver errores
  Paso 2: bosctl rpc bos.health.check → verificar redis y postgresql
  Paso 3: bosctl rpc bos.ficha.repair '{"ficha_id":"redis"}' si está DEGRADADA
```

---

## FASE 8 — Tests y Cobertura
**Estimado:** 2-3 días | **Requiere:** Fases 3, 5, 6

---

### Átomos de Fase 8 por criticidad

| Prioridad | ID | Test | Comando |
|---|---|---|---|
| 🔴 Crítico | T8.1 | Race condition observer | `go test -race -count=100 ./internal/observer/` |
| 🔴 Crítico | T8.2 | TEA purity TUI | `go test -race -count=50 ./internal/tui/model/` |
| 🔴 Alto | T8.3 | Context Plane completo | `go test -race ./internal/context/...` |
| 🟡 Medio | T8.4 | Bootstrap criterios | `go test ./internal/bootstrap/...` |
| 🟡 Medio | T8.5 | JSON-RPC timeouts y auth | `go test ./internal/server/...` |
| 🟡 Bajo | T8.6 | Cobertura ≥60% | `go test -cover ./internal/...` |

**Átomo especial T8.7 — Chaos mínimo:**
```bash
# Simular kill -9 al daemon durante una saga de reparación
# Verificar que el SagaEngine recupera el estado desde /var/lib/bos/ai/sagas/
bosctl vdi test-repair --trigger=kill-during-saga --verify-recovery=true
```

**Verificación de Cierre de Fase 8:**
```bash
go test -race -count=100 ./internal/observer/ && echo "✅ observer 100/100 sin race"
go test -race ./... && echo "✅ TODOS sin race"
go test -cover ./internal/... | awk '/coverage/ && $2+0 < 60 {exit 1}' && echo "✅ cobertura ≥60%"
```

---

## FASE 9 — Operator Soberano: Escalado + VDI
**Estimado:** 4-5 días | **Requiere:** Fases 6, 8 | **Base:** ADR-004, BOS-REPAIR-02, BOS-REPAIR-09

---

### Átomos de Fase 9

| ID | Átomo | Archivo | DoD |
|---|---|---|---|
| F9.1 | Schema `manifest.yml` con `scaling`+`maintenance`+`slos` | manifest schema | `bosctl rpc bos.ficha.describe \| jq .slos` |
| F9.2 | `internal/k8s/core.go` extendido | Scale/Cordon/Uncordon/Drain/Evict | go test -race ./internal/k8s/ |
| F9.3 | `internal/scaler/` anti-death-spiral | scaler.go | TestScaleCoordinated_NoDeathSpiral 50/50 |
| F9.4 | `internal/maintenance/` saga con compensación | maintenance.go | TestMaintenanceSaga_UncordonSiempre (incluso tras crash) |
| F9.5 | JSON-RPC `bos.k8s.*` (8 métodos) | jsonrpc.go | Cada método con test |
| F9.6 | JSON-RPC `bos.maintenance.*` (3 métodos) | jsonrpc.go | TestMaintenanceStart_SagaCompleta |
| F9.7 | `internal/metrics/` — Prometheus (≥15 métricas) | metrics.go | `curl localhost:9090/metrics \| grep bos_ \| wc -l ≥15` |
| F9.8 | ClusterRole `bosagent` least privilege (CIS 4.1.1) | bosagent-clusterrole.yaml | kubectl auth can-i --list (mínimo) |
| F9.9 | VDI Layer C-09..C-14 (BOS-REPAIR-09) | k8s fichas | bosctl vdi verify → 6/6 OK |
| F9.10 | `cmd/bosctl/infra.go` subcomandos | infra.go | bosctl node list/cordon/drain funciona |

---

## FASE 10 — biaos: Agente OS + Gateway IA
**Estimado:** 5-7 días | **Requiere:** Fases 6, 9 | **Base:** BOS-REPAIR-10, BOS-REPAIR-13

---

### Átomo F10.0 — `action_catalog.yml` completo (cierra GAP 4)

**Objetivo:** Crear el catálogo completo de acciones que biaos puede proponer.

**Estructura del archivo:**
```yaml
# /etc/bos/action_catalog.yml — catálogo ICAP de biaos
# Cada acción tiene embeddings pre-calculados en /var/lib/bos/ai/catalog-vectors.bin

version: "1.0"
acciones:
  - id: repair_ficha
    descripcion: "Reparar una ficha degradada o en error"
    metodo_rpc: bos.ficha.repair
    parametros: [ficha_id]
    confirmacion_requerida: false
    riesgo: bajo
    contextos_relevantes: [DEGRADADA, ERROR_LOGICO, ERROR_FISICO]
    compensacion: null

  - id: cordon_nodo
    descripcion: "Aislar un nodo K8s para mantenimiento"
    metodo_rpc: bos.k8s.node.cordon
    parametros: [node_name]
    confirmacion_requerida: true
    riesgo: alto
    compensacion: bos.k8s.node.uncordon
    advertencia: "El nodo no aceptará nuevos pods hasta uncordon"

  - id: drain_nodo
    descripcion: "Vaciar un nodo K8s antes de mantenimiento"
    metodo_rpc: bos.k8s.node.drain
    parametros: [node_name, ignore_daemonsets, delete_emptydir]
    confirmacion_requerida: true
    riesgo: alto
    compensacion: bos.k8s.node.uncordon
    requisito_previo: cordon_nodo

  - id: restart_pod
    descripcion: "Reiniciar un pod específico"
    metodo_rpc: bos.k8s.pod.restart
    parametros: [namespace, pod_name]
    confirmacion_requerida: false
    riesgo: medio

  # ... 15+ acciones más cubriendo todos los módulos JSON-RPC
```

---

### Átomos F10.1 a F10.9

| ID | Átomo | Archivo | DoD |
|---|---|---|---|
| F10.1 | Gateway LLM singleton (sync.Once) + circuit breaker | `internal/biaos/gateway.go` | bosctl rpc bos.ai.ask responde con model_used |
| F10.2 | Migrar `internal/ai/` → `internal/biaos/` | router.go, client.go | Sin referencias a internal/ai/ |
| F10.3 | ICAP Engine + action_catalog + embeddings Ollama | `internal/biaos/icap/catalog.go` | catalog-vectors.bin existe; se invalida por SHA-256 |
| F10.4 | SagaEngine Go: DAG + paralelo + compensación + persistencia | `internal/biaos/sagas/engine.go` | TestSagaEngine_CompensatesOnCrash pasa |
| F10.5 | Agente ReAct en Go puro: Thought→Action→Observation | `internal/biaos/agent.go` | bosctl ia "estado del sistema" retorna diagnóstico |
| F10.6 | HITL: confirmación antes de acciones destructivas | `internal/biaos/hitl.go` | Acciones con riesgo=alto esperan confirmación explícita |
| F10.7 | Safety guardrails (ADR-006 RBAC + audit log) | `internal/biaos/safety.go` | Intento sin permiso: registrado en ai-audit.log con auid |
| F10.8 | JSON-RPC `bos.ai.*` (5 métodos) | jsonrpc.go | bosctl ia "repara nextcloud" completa flujo end-to-end |
| F10.9 | Exportar trayectorias ReAct como JSONL (training Fase 1) | export.go | bosctl ai export-training genera archivo válido |

---

### Verificación de Cierre de Fase 10 (= criterio definitivo del plan)

```bash
# Test end-to-end completo — BOS-REPAIR-13 flujo canónico
bosctl vdi test-repair \
  --ficha=nextcloud \
  --tenant=skull \
  --trigger=oomkill-simulation \
  --verify-ctx-plane=true \
  --verify-vdi=true \
  --verify-audit=true \
  --output=json | jq '{
    deteccion:   .etapas.deteccion.ok,
    diagnostico: .etapas.diagnostico.ok,
    hitl:        .etapas.icap_hitl.ok,
    saga:        .etapas.saga.ok,
    ctx_plane:   .etapas.ctx_plane.ok,
    vdi:         .etapas.vdi.ok,
    audit:       .etapas.audit_trail.ok,
    mttm_s:      .mttm_s,
    slo_ok:      .slo_ok
  }'
# Resultado esperado: todo true, mttm_s < 600
```

---

## PARTE V — CRITERIO DEFINITIVO: 10 / 10

```bash
#!/bin/bash
# BOS-REPAIR — Verificación 10/10
# Ejecutar en staging con tenant skull activo
set -e

echo "═══════════════════════════════════════════════"
echo "BOS-REPAIR Criterio 10/10 — $(date '+%Y-%m-%d %H:%M')"
echo "═══════════════════════════════════════════════"

echo "--- BLOQUE 1: Calidad de código ---"
go build ./... && echo "✅ build"
go vet ./... && echo "✅ vet"
gofmt -l . | wc -l | grep "^0$" && echo "✅ format"
go test -race -count=10 ./... && echo "✅ tests ×10 sin race"
[ $(wc -l < cmd/bos/main.go) -le 200 ] && echo "✅ bos/main ≤200"
[ $(wc -l < cmd/bosctl/install_ui.go) -le 80 ] && echo "✅ install_ui ≤80"
[ ! -f internal/security/rbac_provider.go ] && echo "✅ rbac_provider eliminado"
grep "gorilla/websocket" go.mod && echo "❌" || echo "✅ gorilla eliminado"
grep -rn "func (m \*model)" internal/tui/ && echo "❌ TEA violado" || echo "✅ TEA puro"
grep -rn "step   Screen\|m\.step " internal/tui/ && echo "❌ step presente" || echo "✅ campo único"

echo "--- BLOQUE 2: Seguridad ---"
[ -f /etc/sudoers.d/bos ] && echo "✅ sudoers.d/bos" || echo "❌"
kubectl get clusterrole bos-daemon-impersonator &>/dev/null && echo "✅ ClusterRole OK" || echo "❌"
ls _legacy/*.go | wc -l | grep -E "^[1-9][0-9]" && echo "✅ ≥10 archivos en _legacy"

echo "--- BLOQUE 3: Efectividad ---"
bosctl bootstrap verify --full | grep -c "✓" | grep "^14$" && echo "✅ C-01..C-14 todos OK"
bosctl vdi verify --tenant=skull | grep "6/6" && echo "✅ VDI 6/6 OK"

echo "--- BLOQUE 4: SLOs ---"
bosctl rpc bos.ctx.stats | jq '.p99_latency_ms < 2000' | grep "true" && echo "✅ Context p99 < 2s"
bosctl rpc bos.query.repair | jq '.ultimas_reparaciones[0].duracion_s < 600' | grep "true" && echo "✅ MTTR < 10min"
curl -s localhost:9090/metrics | grep -c "^bos_" | grep -E "^[1-9][0-9]" && echo "✅ ≥10 métricas"

echo "--- BLOQUE 5: biaos activo ---"
bosctl rpc bos.ai.ask '{"prompt":"estado"}' | jq '.model_used' | grep -v "null" && echo "✅ biaos activo"

echo "═══════════════════════════════════════════════"
echo "✅ = 10/10  |  ❌ = pendiente"
echo "═══════════════════════════════════════════════"
```

---

## PARTE VI — REGISTRO DE ESTADO

| Fase | Nombre | Estado | Átomos | ✅/Total | Próximo átomo |
|---|---|---|---|---|---|
| F0 | Fundación e infraestructura | 🟡 | 8 | 4/8 | F0.3 |
| F1 | Extraer cmd/bos/main.go | 🔴 | 7 | 0/7 | F1.1 (requiere F0) |
| F2 | Unificar WebSocket | 🔴 | 4 | 0/4 | F2.1 (requiere F1) |
| F3 | Partir install_ui.go | 🔴 | 10 | 0/10 | F3.1 (requiere F0.3+F2) |
| F4 | Limpiar bosctl + RBAC | 🔴 | 5 | 0/5 | F4.1 (requiere F3) |
| F5 | Context Plane | 🔴 | 6 | 0/6 | F5.1 (requiere F4) |
| F6 | JSON-RPC robusto + sagas | 🔴 | 11 | 0/11 | F6.1 (requiere F5) |
| F7 | Documentación + runbooks | 🔴 | 8 | 0/8 | Paralela a F5-F10 |
| F8 | Tests y cobertura | 🔴 | 7 | 0/7 | Post F3+F5+F6 |
| F9 | Operator Soberano + VDI | 🔴 | 10 | 0/10 | F9.1 (requiere F6+F8) |
| F10 | biaos agente OS + gateway IA | 🟡 | 10 | 1/10 | F10.1 (requiere F6+F9) |
| **TOTAL** | | 🟡 | **87 átomos** | **5/87** | **F0.3** |

**Estados:** 🔴 NO INICIADA · 🟡 EN PROGRESO · 🟢 COMPLETA · ⚠️ BLOQUEADA

**Duración estimada total:** 30-45 días de desarrollo enfocado

---

## PARTE VII — REFERENCIAS NORMATIVAS COMPLETAS

| Referencia | Aplicación en el plan |
|---|---|
| **BOS-REPAIR-00** (Auditoría — 16 problemas) | Base de todos los átomos de F1-F4 |
| **BOS-REPAIR-01** (Efectividad — C-01..C-14) | Criterios de verificación F5, F9 |
| **BOS-REPAIR-02** (ADR-004 Operator Soberano) | Toda la Fase 9 |
| **BOS-REPAIR-03** (ADR-005 Abstracción bosctl) | F4.5, F9.10, CRDs |
| **BOS-REPAIR-04** (Sagas de consulta) | F6.6..F6.11 |
| **BOS-REPAIR-05** (Plan maestro original) | Base histórica |
| **BOS-REPAIR-06** (ADR-002 Roles) | F1.5, F5.2, F6.1 |
| **BOS-REPAIR-07** (ADR-003 Documentación) | F7.1..F7.7, POLÍTICA-CÓDIGO-01 |
| **BOS-REPAIR-08** (Context Plane SBOS-049) | F5.x completa |
| **BOS-REPAIR-09** (VDI Layer SBOS-052) | F9.9 |
| **BOS-REPAIR-10** (biaos) | F10.x completa |
| **BOS-REPAIR-11** (ADR-006 RBAC delegado) | F4.4 |
| **BOS-REPAIR-12** (Fundamentos sagas) | F6.6..F6.11 marco normativo |
| **BOS-REPAIR-13** (Flujo end-to-end) | Criterio definitivo F10 |
| **internal/state/manager.go** | 18 estados — referencia para todos los tests |
| **internal/repair/repair_manager.go** | RepairManager existente — base de F9 |
| **internal/installer/saga.go + compensator.go** | Orchestrator existente — base de F10.4 |
| **internal/config/config.go** | Configuración — base de F0.4, F1.7 |
| **JSON-RPC-01..09** | Manual completo — base de toda la Fase 6 |
| **Strangler Fig Pattern** (Fowler) | SFP-01..06 |
| **Definition of Done** (Agile/Scrum) | DoD-Universal por átomo |
| **Post-mortem Engineering** (Google SRE) | Plantilla Informe de Cierre |
| **Go Race Detector** | `go test -race -count=100` en CI |
| **NIST SP 800-53 (PoLP)** | F4.4, ClusterRole least privilege |
| **NIST SP 800-207 (Zero Trust)** | F5 — Context Plane como PEP |
| **ISO/IEC 27001:2022 A.8.15** | Audit log en cada átomo |
| **ISO/IEC 27001:2022 A.9.4.2** | TTL máximo 12h sesiones (F5.2) |
| **CIS Ubuntu 24.04 LTS** | F4.4.1 sudoers.d/bos |
| **CIS Kubernetes Benchmark v1.9** | F9.8 ClusterRole bosagent |
| **W3C Trace Context** | F5.6 traceparent en todos los logs |
| **OpenTelemetry CNCF** | F6.6 bos.query.system agrega señales |
| **Google SRE InvD (44% MTTM)** | F6.7 bos.query.repair diagnóstico paralelo |
| **ITIL 4 Incident Management** | BOS-REPAIR-13 flujo end-to-end |
| **Chaos Engineering 2025** | T8.7 test de crash durante saga |

---

*BOS-REPAIR-PLAN-MAESTRO v3.0 · SKULL · SBOS · 07 de Junio 2026*  
*85 átomos · 11 fases · Strangler Fig Pattern · DoD + Informe de Cierre por átomo*  
*Diagnóstico de 4 gaps documentales + política de migración segura + memoria del proyecto*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
