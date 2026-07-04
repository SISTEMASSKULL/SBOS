# FICHA-ENGINE-GAP — Auditoría vs Contrato SBOS-019

**Versión:** 1.0 · **Fecha:** 2026-06-19 · **Autor:** sbos-coordinador + bos-developer
**Propósito:** Identificar qué soporta el Ficha Engine hoy vs qué exige el contrato SBOS-019.
**Metodología:** Comparación contra código real en `internal/ficha/`, no contra supuestos.

---

## Resumen ejecutivo

| Categoría | Implementado | Parcial/Stub | No implementado |
|-----------|-------------|-------------|-----------------|
| Contrato gRPC | 18 RPCs + 2 streaming | — | buf lint, breaking change check |
| Servidor gRPC | 18 handlers + 6 interceptors | — | Auth interceptor real (ctx_id stub) |
| JSON-RPC | 8 handlers legacy + 8 nuevos | Scale (stub K8s) | — |
| CLI | 11 subcomandos | Logs (lectura real stub) | Update, Remove CLI |
| Parser de manifiesto | Parseo básico (plugin/loader.go) | **Pendiente: parser estricto** | Validación schema, unknown fields (SAN-10) |
| Dependency Resolver | Kahn + oleadas (resolver.go) | Integración con Plan() | — |
| Ejecutor 5 fases | Pipeline + timeouts + observer | **Ejecución real pendiente** | Integración con task_catalog.sh real |
| 18 estados | StateMachine + Lifecycle + state.Manager | — | Transiciones automáticas vía K8s watch |
| Health checker | 4 tipos (command/http/tcp/none) | HTTP/TCP sin probar en VPS | Integración con observer loop |
| Drift detector | SHA-256 file comparison | **K8s resource drift stubbed** | Comparación pods/configmaps/secrets |
| Reconciliación | 3 políticas + ciclo 5min | **Auto-repair sin Executor real** | Integración K8s (F9) |
| Status collector | 25 campos multi-fuente | Runtime info (CPU/RAM stub) | K8s métricas reales |
| Versionado | SemVer + UpdateStrategy 3 tipos | — | — |
| Dashboard | 4 paneles + validador + generador | — | Integración Grafana automática |
| Capacidades auto | 5 capacidades + config generator | — | Aplicación real en install |
| NetworkPolicy | Deny-all + allowlist generada | — | Aplicación real en K8s |
| Discovery | Escaneo recursivo + 3 contratos | — | Integración con plugin.Loader |
| Governance | — | — | **Dual-control no implementado** |
| Timeouts por ficha | En Executor y Lifecycle | — | Configurable desde manifest (F11.G.3) |

---

## 1. Contratos de Transporte

### 1.1 gRPC Server
- **Archivo:** `internal/ficha/grpc/server.go` (651 líneas)
- **Estado:** ✅ 18 handlers implementados
- **Gaps:**
  - `buf lint` no ejecutado en CI
  - `buf breaking` no configurado
  - Auth interceptor usa ctx_id stub (`00000000-0000-4000-8000-000000000000`)
  - Streaming Watch/GetLogs: stubs (envían heartbeat y esperan disconnect)

### 1.2 JSON-RPC Handlers
- **Archivo:** `internal/server/jsonrpc.go` (+162 líneas)
- **Estado:** ✅ 16 métodos registrados (8 legacy + 8 nuevos)
- **Gaps:**
  - `bos.ficha.scale`: retorna ErrInternal (K8s no integrado)
  - `bos.ficha.logs`: retorna array vacío (lectura real stub)
  - `bos.ficha.update`, `bos.ficha.remove`: no tienen handler propio (usan saga.execute)

### 1.3 CLI (bosctl)
- **Archivo:** `cmd/bosctl/ficha.go` (513 líneas)
- **Estado:** ✅ 11 subcomandos
- **Gaps:**
  - `bosctl ficha logs`: muestra mensaje informativo (lectura real stub)
  - `bosctl ficha scale`: muestra advertencia K8s
  - `bosctl ficha update`: no implementado
  - `bosctl ficha remove`: no implementado
  - `bosctl ficha resume`: no implementado

---

## 2. Núcleo del Ficha Engine

### 2.1 Parser de manifiesto
- **Archivo actual:** `internal/plugin/loader.go:parseManifest()` (state-machine parser)
- **Archivo necesario:** `internal/ficha/parser.go` (parser estricto)
- **Estado:** 🟡 Parcial
- **Qué soporta hoy:**
  - Parseo de secciones: identity, workload, order, requirements, governance, meta, scaling, maintenance, slos
  - Extracción de dependencias con inline comments
  - Hash SHA-256 de archivos declarativos
- **Qué exige SBOS-019:**
  - Validación de campos obligatorios (name, version, ports.metrics, ports.health)
  - Rechazo de campos desconocidos (SAN-10 — anti-mass-assignment)
  - Validación de licencias OSI-approved
  - Schema JSON estricto con allowlist de campos
  - Rechazo de ficha sin dashboard.json (F11.E.2)
- **Archivos afectados:** `internal/ficha/parser.go` (no existe aún)

### 2.2 Dependency Resolver
- **Archivo:** `internal/ficha/resolver.go` (234 líneas)
- **Estado:** ✅ Implementado
- **Qué soporta:** Grafo dirigido, detección de ciclos (Kahn), orden topológico, oleadas paralelizables
- **Gaps:**
  - `FichaService.Plan()` no usa el resolver real (usa orden por execution_order)
  - Timeout de 5s para 100+ fichas no implementado
  - Sin caché del resultado del resolver

### 2.3 Ejecutor 5 fases
- **Archivo:** `internal/ficha/executor.go` (468 líneas)
- **Estado:** 🟡 Lógica implementada, ejecución real pendiente
- **Qué soporta:**
  - Pipeline pre_install→install→post_install→verify→commit
  - Timeouts por tipo de ficha (DB 10min, K8s 5min, daemon 2min)
  - OnFailure: abort / continue
  - PhaseObserver para TUI
  - buildPhaseScript(): wrapper bash que invoca ficha_<fase>()
  - parsePhaseSignals(): parser de señales __SBOS__STEP__
- **Gaps:**
  - `Executor.Execute()` no se usa en producción — solo en tests
  - `resolveTaskDir()` en gRPC server requiere integración con Discoverer
  - No hay integración con el installer.Orchestrator legacy
  - Las fases se simulan; no ejecutan task_catalog.sh real aún

---

## 3. Máquina de Estados (ADR-021)

### 3.1 StateMachine
- **Archivo:** `internal/ficha/statemachine.go` (471 líneas)
- **Estado:** ✅ 18 estados completos
- **Qué soporta:**
  - 18 FichaState constants
  - ValidTransitions completos (coinciden con state.Manager)
  - CanInstall/Update/Repair/Remove/Pause/Resume/Scale
  - NextAfter* para cada operación
  - Begin* para iniciar transiciones
  - StableStates (13) + TransitionalStates (5)
  - StateIcon (18 íconos) + StateDescription (18 descripciones)

### 3.2 Lifecycle Orchestrator
- **Archivo:** `internal/ficha/lifecycle.go` (790 líneas)
- **Estado:** ✅ Lógica de transiciones completa
- **Qué soporta:**
  - Install: LISTA→INSTALANDO→INSTALADA / FALLA_INST→ROLLBACK/LIMPIEZA
  - Update: INSTALADA→ACTUALIZANDO→INSTALADA / FALLA_ACT→ROLLBACK
  - Repair: DEGRADADA→REPARANDO→INSTALADA (3 reintentos→ERROR_NO_CORREGIBLE)
  - Remove: INSTALADA→DESINSTALADA
  - Rollback: 6 pasos canónicos
  - Cleanup: 7 pasos de limpieza
  - Diagnose(): 10 patrones de error
  - HITL escalation
- **Gaps:**
  - ExecuteRollback/ExecuteCleanup: simulación (no ejecutan task_catalog.sh real)
  - ExecuteRepair: simulación de éxito en 2do intento
  - Sin integración con state.Manager para persistir transiciones

---

## 4. Salud y Monitoreo

### 4.1 Health Checker
- **Archivo:** `internal/ficha/health.go` (378 líneas)
- **Estado:** ✅ 4 tipos implementados
- **Gaps:**
  - HTTP/TCP checks no probados contra VPS real
  - HealthDef no se lee del manifest.yml real (ParseHealthFromManifest es básico)
  - Sin integración con el observer loop del daemon

### 4.2 Drift Detector
- **Archivo:** `internal/ficha/drift.go` (342 líneas)
- **Estado:** ✅ Detección por hash implementada
- **Gaps:**
  - Solo compara archivos en disco (no recursos K8s)
  - K8s resource drift (imagen, réplicas, configmaps) stubbed para F9
  - Sin integración con reconcile loop automático

### 4.3 Reconciliador
- **Archivo:** `internal/ficha/reconcile.go` (366 líneas)
- **Estado:** ✅ 3 políticas implementadas
- **Gaps:**
  - `runCycle()` no obtiene datos reales del catálogo
  - Auto-repair no ejecuta Executor real
  - Sin persistencia de resultados de reconciliación

### 4.4 Status Collector
- **Archivo:** `internal/ficha/status.go` (383 líneas)
- **Estado:** ✅ Multi-fuente implementado
- **Gaps:**
  - Runtime info (CPU/RAM/réplicas): stub hasta F9
  - Sin caché de resultados

---

## 5. Extras

### 5.1 Versionado
- **Archivo:** `internal/ficha/version.go` (260 líneas)
- **Estado:** ✅ Completo, sin gaps

### 5.2 Dashboard
- **Archivo:** `internal/ficha/dashboard.go` (285 líneas)
- **Estado:** ✅ Completo
- **Gap:** Integración Grafana automática (crear ConfigMap en K8s al instalar)

### 5.3 Capacidades automáticas
- **Archivo:** `internal/ficha/capabilities.go` (246 líneas)
- **Estado:** ✅ Generador completo
- **Gap:** Aplicación real durante install (generar y aplicar configs)

### 5.4 NetworkPolicy
- **Archivo:** `internal/ficha/netpolicy.go` (320 líneas)
- **Estado:** ✅ Generador completo
- **Gap:** Aplicación real en K8s (kubectl apply durante install)

### 5.5 Discovery
- **Archivo:** `internal/ficha/discovery.go` (331 líneas)
- **Estado:** ✅ Escaneo + validación
- **Gap:** Integración con plugin.Loader existente

### 5.6 Governance Dual-Control
- **Estado:** 🔴 No implementado
- **Exige SBOS-019 §13:** Operaciones cat.3 requieren 2 admins + ventana 60min + texto exacto
- **Archivo necesario:** `internal/ficha/governance.go`

---

## 6. Roadmap de gaps críticos

| Prioridad | Gap | Impacto | Dependencia |
|-----------|-----|---------|------------|
| **ALTA** | Parser estricto (SAN-10, unknown fields) | Seguridad — sin esto, campos maliciosos en manifiesto no se detectan | — |
| **ALTA** | Integración Executor con task_catalog.sh real | Sin esto, las fichas no se instalan | resolverTaskDir() |
| **ALTA** | Integración Lifecycle con state.Manager | Las transiciones no se persisten | — |
| **ALTA** | Governance dual-control | Operaciones destructivas sin barrera de seguridad | F11.F.5 |
| **MEDIA** | K8s resource drift (F9) | Drift solo detecta archivos, no estado K8s | Operator F9 |
| **MEDIA** | Runtime metrics en Status (F9) | Status no muestra CPU/RAM/réplicas reales | Operator F9 |
| **MEDIA** | Watch/GetLogs streaming real | gRPC streaming es stub | Executor real |
| **BAJA** | buf lint + breaking change en CI | Calidad del contrato gRPC | CI pipeline |
| **BAJA** | Integración Grafana automática | Dashboards no se crean solos | K8s ConfigMap |

---

## 7. Métricas de cobertura

| Paquete | Archivos | Tests | Cobertura estimada |
|---------|---------|-------|-------------------|
| `internal/ficha/` | 22 | 175 | ~70% (lógica pura alta, integración baja) |
| `internal/ficha/grpc/` | 1 | 0 | 0% (compila, sin tests) |
| `internal/domain/` | 4 | 10 | ~60% |
| `cmd/bosctl/` | 1 | 0 | 0% (compila, sin tests) |

---

*FICHA-ENGINE-GAP.md v1.0 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
*Generado a partir de auditoría de código real en `internal/ficha/` (22 archivos, ~6,300 líneas).*
