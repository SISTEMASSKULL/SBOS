# PLAN DE REPARACIÓN — BosAgent (Auditoría 2026-06-29)

**Basado en:** `INFORME-AUDITORIA-BOSAGENT-2026-06-29_1923.md`
**Hallazgos totales:** 105 (5 críticos, 28 altos, 38 medios, 34 bajos)
**Estrategia:** Una fase a la vez. Completar → committear → actualizar informe → siguiente fase.

---

## 📊 PROGRESO GENERAL

| Fase | Hallazgos | Estado | Commit | Fecha |
|------|:---------:|:------:|:------:|:-----:|
| [F1](#fase-1--contraseña-postgresql--zero-trust) | C1, C2, C5 | ⬜ Pendiente | — | — |
| [F2](#fase-2--deadlock-pipes--race-condition-sagas) | C2-executor, C4-sagas | ⬜ Pendiente | — | — |
| [F3](#fase-3--cryptorand-ignorado--errores-silenciados) | C3, E-IGNORE-2, E-IGNORE-3 | ⬜ Pendiente | — | — |
| [F4](#fase-4--hardcodeo-general) | 10 hallazgos H-URL-* | ⬜ Pendiente | — | — |
| [F5](#fase-5--archivos-monolíticos) | 8 hallazgos M-MONO-* | ⬜ Pendiente | — | — |
| [F6](#fase-6--parsers-artesanales) | S-YAML-1, S-YAML-2, S-SHELL-1 | ⬜ Pendiente | — | — |
| [F7](#fase-7--configuración-expuesta) | SEC-IP-1, SEC-SEED-1, H-SH-1 | ⬜ Pendiente | — | — |
| [F8](#fase-8--documentación-y-cierre) | D-CLAUDE-1, D-EMOJI-1, resto bajos | ⬜ Pendiente | — | — |

---

## FASE 1 — Contraseña PostgreSQL + Zero Trust

### Hallazgos
- **C5** `installer/pg_auxiliar.go:70` — `host all all 0.0.0.0/0 md5`
- **C1** `domain/pg_auxiliar_service.go:137` — `PGPASSWORD=sbos_aux_temp_pass`
- **C2** `domain/pg_auxiliar_service.go:305` — contraseña en YAML embebido

### Acciones
- [ ] Reemplazar `0.0.0.0/0` por IP del pod fuente obtenida dinámicamente
- [ ] Reemplazar `md5` por `scram-sha-256`
- [ ] Extraer `sbos_aux_temp_pass` a variable de entorno `PG_AUX_PASSWORD`
- [ ] Leer contraseña desde `os.Getenv` con fallback seguro
- [ ] Eliminar contraseña del YAML embebido
- [ ] Verificar: `grep -r "sbos_aux_temp_pass" src/internal/` debe retornar vacío

---

## FASE 2 — Deadlock pipes + Race condition sagas

### Hallazgos
- **C2** `ficha/executor.go:269-292` — lectura secuencial stdout→stderr
- **C4** `biaos/sagas/engine.go:115-133` — escritura concurrente sin mutex

### Acciones
- [ ] `executor.go`: leer stdout y stderr concurrentemente (goroutines + WaitGroup)
- [ ] `saga.go`: mismo fix en líneas 357-443
- [ ] `engine.go`: agregar `sync.Mutex`, proteger `ej.Pasos`
- [ ] Test: verificar que pipe > 64KB no causa deadlock
- [ ] `go test -race ./internal/biaos/sagas/`

---

## FASE 3 — crypto/rand ignorado + errores silenciados

### Hallazgos
- **C3** `server/traceparent.go:29` — `_, _ = rand.Read(...)`
- **E-IGNORE-2** `server/rpc_helpers.go:38` — `_ = enc.Encode(v)`
- **E-IGNORE-3** `server/unix.go:205-252` — 5× `b, _ := json.Marshal`

### Acciones
- [ ] `traceparent.go`: verificar error de `rand.Read`, loggear warning
- [ ] `rpc_helpers.go`: crear `mustMarshal` con log de error + fallback
- [ ] `unix.go`: reemplazar 5 ocurrencias por `mustMarshal`
- [ ] Verificar: `grep -r "b, _ := json.Marshal" src/internal/server/` debe retornar vacío

---

## FASE 4 — Hardcodeo general

### Hallazgos (10 prioritarios)
H-URL-3/4, H-URL-10, H-URL-11, H-URL-1, H-URL-2, H-URL-6, H-URL-5, H-URL-7

### Acciones
- [ ] Unificar versión con `-ldflags "-X main.version=$VERSION"`
- [ ] Timeouts HTTP configurables en `Config`
- [ ] Defaults PG centralizados en constantes `domain/`
- [ ] `cacheTTL` configurable en `bauth.Client`
- [ ] `fichasVDI` → array no mutable
- [ ] Usar `paths.*` en lugar de rutas hardcodeadas

---

## FASE 5 — Código monolítico: dividir archivos >500 líneas

### Hallazgos (10 archivos)

| # | Archivo | Líneas | Límite | Exceso |
|---|---------|--------|--------|--------|
| M1 | `internal/server/ws.go` | 1,041 | 200 | 5× |
| M2 | `internal/state/manager.go` | 723 | 200 | 3.6× |
| M3 | `internal/ficha/grpc/server.go` | 704 | 200 | 3.5× |
| M4 | `internal/server/query_handlers.go` | 672 | 200 | 3.3× |
| M5 | `internal/ficha/saga.go` | 477 | 200 | 2.4× |
| M6 | `internal/ficha/parser.go` | 474 | 200 | 2.4× |
| M7 | `internal/ficha/executor.go` | 467 | 200 | 2.3× |
| M8 | `internal/ficha/lifecycle.go` | 426 | 200 | 2.1× |
| M9 | `internal/context/store.go` | 353 | 200 | 1.8× |
| M10 | `cmd/bos/run_normal.go` (función) | 354 | 50 | 7× |

### Acciones
- [ ] M1: Dividir `ws.go` en `ws_types.go` + `ws_hub.go` + `ws_transport.go` + `ws_ficha_handlers.go` + `ws_identity_handlers.go`
- [ ] M2: Dividir `manager.go` en `state.go` (tipos) + `manager.go` (Manager) + `transitions.go`
- [ ] M3: Dividir `grpc/server.go` por operación: `ficha_install.go`, `ficha_update.go`, etc.
- [ ] M4: Dividir `query_handlers.go` en `query_system.go` + `query_repair.go` + `query_tenant.go` + `query_node.go`
- [ ] M5: Dividir `saga.go` por paso de saga (un archivo por paso)
- [ ] M6: Reemplazar parser artesanal en `parser.go` por `yaml.v3` (ver Fase 6)
- [ ] M7: Dividir `executor.go` en `executor.go` + `phase.go` + `signals.go`
- [ ] M8: Dividir `lifecycle.go` por operación (install, update, repair, remove)
- [ ] M9: Dividir `store.go` en `store.go` + `sql.go` + `query.go` + `migrate.go`
- [ ] M10: Extraer inicialización de subsistemas de `runNormal` a funciones constructoras
- [ ] Verificar: `find src/internal -name "*.go" -exec wc -l {} + | awk '$1>200{print $2, $1}' | wc -l` debe reducirse

---

## FASE 6 — Código espagueti: parsers artesanales + shell embebido

### Hallazgos (6)

| # | Archivo | Problema |
|---|---------|----------|
| S1 | `ficha/parser.go:123-244` | Parser YAML artesanal 122 líneas con `strings.Split` |
| S2 | `biaos/icap/catalog.go:66-151` | Parser YAML artesanal 85 líneas para action_catalog |
| S3 | `security/k8s_checks.go:54-55` | 8 funciones con `exec.Command("sh", "-c", ...)` |
| S4 | `k8s/core.go:176-205` | Manifiesto YAML construido con `fmt.Sprintf` (inyección) |
| S5 | `context/store.go:346-350` | Código muerto: mismo `cache.Del` en ambas ramas if/else |
| S6 | `ficha/logs.go:202-226` | Parser JSON manual con `strings.Index` (frágil) |

### Acciones
- [ ] S1: Reemplazar `ParseManifestStrict` por `yaml.Unmarshal` + structs tipados (ya tienes `gopkg.in/yaml.v3`)
- [ ] S2: Mismo approach para `parsearAcciones` en icap/catalog.go
- [ ] S3: Reemplazar `sh -c` por `exec.Command` con argumentos separados + `os.ReadFile` para archivos
- [ ] S4: Usar `text/template` o `yaml.Marshal` en vez de `fmt.Sprintf` para manifiestos K8s
- [ ] S5: Simplificar a una sola línea `_ = s.cache.Del("ctx:" + ctxID)` fuera del if
- [ ] S6: Reemplazar `extractJSONField` por `encoding/json` + `json.RawMessage`
- [ ] Verificar: `grep -rn "strings.Split\|strings.HasPrefix\|strings.Index" src/internal/ficha/parser.go` debe estar limpio
- [ ] Eliminar ~300 líneas de código frágil

---

## FASE 7 — Modularización: violaciones de arquitectura

### Hallazgos (8)

| # | Archivo | Problema |
|---|---------|----------|
| A1 | `server/api.go:165-166` | Doble Context Service (`domain.CtxService` + `bosctx.Service`) |
| A2 | `_legacy/` (15 archivos) | Código legacy + snapshots dentro de `src/` |
| A3 | `query/k8s.go:39` | Bypass del dispatcher K8s único (principio P1) |
| A4 | `observability/health_report.go:82` | Duplica fuentes de consulta ya en `internal/query/` |
| A5 | `domain/ficha_service.go:485` | `FichaService` con 16 métodos — viola SRP |
| A6 | `context/service.go:236-330` | `memStore` (test) en mismo archivo que lógica de producción |
| A7 | `security/file_rbac.go:14` | Struct documentado NO thread-safe pero usado concurrentemente |
| A8 | `repair/repair_manager.go:152-264` | 4 funciones `runPhase*` idénticas (violación DRY) |
| A9 | `state/manager.go:319-328` | `validate()` y `readLocked()` duplican lógica de decodificación |

### Acciones
- [ ] A1: Unificar en un solo `ContextService` — eliminar `domain.CtxService`, migrar sus métodos a `bosctx.Service`
- [ ] A2: Mover `_legacy/` y `_snapshots/` a `backups/BosAgent/` según ADR-016
- [ ] A3: Migrar `query.K8sNodesSummary` a usar `k8s.Core` en vez de `exec.Command("kubectl")`
- [ ] A4: Refactorizar `CollectReport()` para usar `query.Run()` con fuentes existentes
- [ ] A5: Dividir `FichaService` en `SagaService`, `CatalogService`, `ValidationService`, `ScaleService`
- [ ] A6: Mover `memStore` a `mem_store.go` o a `internal/context/memstore/`
- [ ] A7: Agregar `sync.RWMutex` a `FileRBAC`, proteger todos los accesos a mapas
- [ ] A8: Extraer `runPhase(name, fn)` genérica, eliminar 60 líneas duplicadas
- [ ] A9: Hacer que `validate()` llame a `readLocked()` y descarte resultado
- [ ] Verificar: `find src/_legacy src/_snapshots -type f | wc -l` debe ser 0

---

## FASE 8 — Documentación, emojis, naming, limpieza final

### Hallazgos (15+)

#### Documentación
- [ ] D1: Crear `BosAgent/CLAUDE.md` en raíz del proyecto (NO existe)
- [ ] D2: Mover créditos de autor/IA de `domain/doc.go:1-2` a `AUTHORS.md`
- [ ] D3: Agregar target `help` al Makefile listando todos los targets
- [ ] D4: Documentar timeouts y defaults en `server/timeout.go`

#### Logs y emojis
- [ ] D5: Eliminar emojis de logs estructurados en `ficha/diagnosis.go`, `reconcile.go`, `drift.go`, `status.go`, `statemachine.go` (~10 ocurrencias)
- [ ] D6: Reemplazar `🚨 HITL REQUERIDO` por `HITL_REQUIRED`

#### Nomenclatura y código redundante
- [ ] D7: Unificar snake_case vs camelCase en etiquetas JSON de `api.go`
- [ ] D8: Reemplazar `containsAny` artesanal por `strings.Contains` en `lifecycle.go:414`
- [ ] D9: Reemplazar `containsInSlice` por `slices.Contains` (Go 1.21+)

#### Manejo de errores restante
- [ ] D10: `server/auth.go:125` — cambiar fail-open → fail-close en token
- [ ] D11: `audit/log.go:53` — loggear error en vez de `//nolint:errcheck`
- [ ] D12: `ficha/logs.go:202` — verificar error de `fmt.Sscanf`
- [ ] D13: `ficha/cleanup.go:148` — implementar `verifyNoResidue` o eliminar stub
- [ ] D14: `server/ws.go:359` — loggear error de `os.Chown`

#### Concurrencia restante
- [ ] D15: `ficha/logs.go:102` — agregar `context.Context` a `FollowLog` para cancelación
- [ ] D16: `ficha/grpc/server.go:102` — capturar `debug.Stack()` en recoveryInterceptor
- [ ] D17: `biaos/audit/logger.go:76` — usar `select default` para no bloquear en Log()

#### Configuración expuesta
- [ ] D18: `docs/ENVIRONMENTS.md` — reemplazar IPs reales por placeholders
- [ ] D19: `servers/seed-skull.yml` — convertir en template con placeholders
- [ ] D20: `core/00_CLEANUP_SBOS.sh` — parametrizar rutas absolutas

---

## REGLAS

1. **Una fase a la vez** — no mezclar cambios
2. **Commit por fase** — `[AUDIT-F1] Fix: contraseñas hardcodeadas + Zero Trust`
3. **Actualizar informe** — tras cada fase, anotar resolución en el informe de auditoría
4. **Marcar checkboxes** — `[x]` al completar
5. **No romper tests** — `go test ./...` antes de commit
6. **Solo reparar** — sin refactors no solicitados

---

*Plan generado: 2026-06-29 · Ejecutor: agente-bos*
