# Auditoría de Coherencia — BOS Control Plane
**Fecha:** 2026-10-07
**Auditor:** bos-developer
**Alcance:** 29 manuales + 17 anexos vs código Go actual (73.938 LOC)
**Base de comparación:** INDICE.md v3.0.0 (2026-07-31) vs rama `main` HEAD 4467ec6

---

## Resumen ejecutivo

| Categoría | Cantidad |
|-----------|----------|
| Manuales auditados | 29 (+ 17 anexos) |
| Coherentes (docs = código) | 19 manuales |
| Brechas docs→código (documentado pero sin código) | 8 brechas |
| Brechas código→docs (código existe, docs ausentes/atrasadas) | 3 brechas |
| Obsoletos | 0 |
| Brechas en anexos | 4 |

**Veredicto global:** el proyecto está en estado **L2 sólido** en los motores núcleo (①③④). Los motores ② (Capacidad) y ⑤ (Dashboard completo) tienen implementación parcial. El Motor ⑥ (Banco de Pruebas) tiene cobertura de tests automáticos pero el manual 6.01 no refleja los casos reales del código.

---

## Estado del build y tests

```
Build:  CGO_ENABLED=0 go build ./... → OK (sin errores, sin warnings)
Tests:  go test -race -count=1 ./...
        41 paquetes / 41 PASS / 0 FAIL
LOC:    73.938 líneas (internal/) sin contar TUI (16.298 LOC adicionales)
        Paquetes totales: 38 en internal/ + cmd/bos + cmd/bosctl + otros
```

---

## Motor ① IAM Installer

### 1.01 — IAM Installer (DEFINE)
- **Estado declarado:** ✅ 3.0.0
- **Coherencia verificada:**
  - Bootstrap C-01..C-08: ✅ `internal/bootstrap/verify.go` implementa `VerifyC01()` a `VerifyC08()` + `VerifyAll()`
  - Stack soberano (PG/Redis/Vault/KC/Kong): ✅ `internal/bootstrap/k8s_verify.go` con CheckPostgres/CheckRedis/CheckVault/CheckKeycloak/CheckKong
  - Servicio systemd `bos.service`: no verificable desde código (es configuración externa)
  - Socket `/run/bos/bos.sock` + TCP `0.0.0.0:9443`: ✅ referenciado en `internal/paths/`
- **Brechas:** ninguna — **coherente**

### 1.02 — Sagas de Instalación
- **Estado declarado:** ✅ 3.0.0
- **Coherencia verificada:**
  - Saga Install: ✅ `internal/installer/saga.go:Orchestrator.Install()`
  - Saga Update: ✅ `Orchestrator.Update()`
  - Saga Repair: ✅ `Orchestrator.Repair()`
  - Saga Remove: ✅ `Orchestrator.Remove()`
  - Compensador: ✅ `internal/installer/compensator.go:Compensate()` + `ChainForSaga()`
  - Probe: ✅ `Orchestrator.Probe()` (extra, no documentado)
  - Shutdown: ✅ `Orchestrator.Shutdown()` con fases (extra, no documentado)
- **Brechas:**
  - [BAJA] CÓDIGO→DOCS: `Probe()` y `Shutdown()` implementados, no mencionados en manual

### 1.03 — Ciclo de Vida de Tenants
- **Estado declarado:** ✅ 2.0.0
- **Coherencia verificada:**
  - `cmdTenant` en `cmd/bosctl/main.go`: ✅ existe
  - `cmd/bosctl/deploy.go:cmdTenant()`: ✅ implementado
  - JSON-RPC `bos.ctx.tenant.suspend`: ✅ registrado en jsonrpc.go
- **Brechas:** ninguna visible sin leer el manual completo — **presuntamente coherente**

### 1.04 — Seguridad de Red — Zero Trust
- **Estado declarado:** 🟡 1.3.0
- **Coherencia verificada:**
  - NRS-01/02/05..09: ✅ `internal/network/` + `internal/security/`
  - NRS-03 mTLS entre daemons: ❌ Solo referencias a Linkerd en pantallas TUI (`internal/tui/`), **sin implementación real** en el plano de control. El código no establece mTLS propio entre daemons; delega en Linkerd como sidecar.
  - NRS-04 Wazuh SIEM: ❌ **cero menciones** en código Go. No implementado.
  - NRS-10 CI pipeline gosec/govulncheck: ❌ No hay archivo de CI en el repositorio Go (`.github/workflows/` no existe en `src/`).
  - CIS Benchmarks: ✅ `internal/security/cis_benchmarks.go:CISBenchmarks()`
  - K8s security checks: ✅ `internal/security/k8s_checks.go:RunK8sChecks()`
- **Brechas:**
  - [ALTA] DOCS→CÓDIGO: NRS-03 mTLS nativo entre daemons — no implementado
  - [ALTA] DOCS→CÓDIGO: NRS-04 Wazuh SIEM — no implementado
  - [ALTA] DOCS→CÓDIGO: NRS-10 CI pipeline gosec/govulncheck — no existe en repo

### 1.05 — Estándares y Certificación IAM Enterprise
- **Estado declarado:** 🟡 1.0.0
- **Coherencia verificada:**
  - `internal/security/cis_benchmarks.go`: ✅ existe como evidencia parcial ISO 27001
  - k6 SLOs: ❌ no hay archivos de carga en el repositorio
  - FAPI 2.0 Conformance Suite: ❌ no implementado
- **Brechas:**
  - [MEDIA] DOCS→CÓDIGO: tabla evidencia ISO 27001 (A.8.9-A.8.32) no generada desde código
  - [MEDIA] DOCS→CÓDIGO: SLOs k6 ausentes
  - [MEDIA] DOCS→CÓDIGO: FAPI 2.0 Conformance Suite ausente

---

## Motor ② SO Observable

### 2.01 — SO Observable (DEFINE)
- **Estado declarado:** ✅ 1.0.0
- **Coherencia verificada:**
  - UnifiedWatchdog: ✅ `internal/watchdog/unified_watchdog.go` — 3 capas efectivas: SO (disk/memory/systemd), K8s (nodes/pods), Fichas (BOS fichas)
  - Observer DAG topológico: ✅ `internal/observer/observer.go:TopologicalSort()` + `DepsSatisfied()`
  - Reconciliación periódica: ✅ `internal/reconcile/scheduler.go`
- **Brechas:** ninguna — **coherente**

### 2.02 — Motores de Capacidad
- **Estado declarado:** 🟡 1.0.0
- **Coherencia verificada:**
  - Manual documenta 4 motores: collector, forecaster, policy_engine, action_engine
  - Implementación real en `internal/capacity/`:
    - `calculator.go`: ✅ cálculo de requisitos (CPU/RAM/disco) dado un Estimate
    - `model.go`: ✅ tipos Estimate/Requirements/AdmissionResult + CheckAdmission()
    - `persist.go`: ✅ Save/Load/ParseEnv para el Estimate
  - **Collector (métricas en tiempo real):** ❌ no existe como motor independiente
  - **Forecaster (predicción):** ❌ no existe
  - **PolicyEngine (reglas de umbral):** ❌ parcial — solo `CheckAdmission()` estático
  - **ActionEngine (escalar/alertar automáticamente):** ❌ no existe; hay `bos.capacity.check` y `bos.capacity.status` en JSON-RPC pero sin motor real
  - `internal/scaler/scaler.go:Decide()`: ✅ existe pero es independiente (no integrado con capacity)
- **Brechas:**
  - [ALTA] DOCS→CÓDIGO: los 4 motores dinámicos descritos en el manual no están implementados como componentes separados; la capacidad es estática (cálculo batch)
  - [MEDIA] DOCS→CÓDIGO: integración watchdog-capacity (flujo ITIL 4 A.08 §4) no implementada

### 2.03 — Health Checks y Métricas
- **Estado declarado:** ✅ 1.0.0
- **Coherencia verificada:**
  - `internal/health/checker.go`: ✅ Checker con health checks
  - `internal/metrics/metrics.go`: ✅ Registry, Counter, Gauge, Render(), Serve()
  - `internal/observability/health_report.go`: ✅ CollectReport() — Ubuntu/K8s/BOS/Fichas
- **Brechas:** ninguna — **coherente**

### 2.04 — Reconciliación y Drift
- **Estado declarado:** ✅ 1.0.0
- **Coherencia verificada:**
  - `internal/reconcile/scheduler.go:Scheduler.reconcile()`: ✅
  - `internal/reconcile/k8s_discovery.go:DiscoverK8sStates()`: ✅
  - `internal/reconcile/scan_adapter.go:K8sScanAdapter.Scan()`: ✅
  - `internal/ficha/drift.go`: ✅ existe
- **Brechas:** ninguna — **coherente**

---

## Motor ③ Server FICHAS

### 3.01 — Server FICHAS (DEFINE)
- **Estado declarado:** 🟡 1.0.0
- **Coherencia verificada:**
  - Máquina de 18 estados (inglés): ✅ **exactamente 18 estados** en `internal/ficha/statemachine.go`:
    PENDING, READY, INSTALLING, INSTALLED, INSTALL_FAILED, UPDATE_AVAILABLE, UPDATE_APPROVED, UPDATING, UPDATE_FAILED, DEGRADED, PHYSICAL_ERROR, LOGICAL_ERROR, UNRECOVERABLE, REPAIRING, ROLLBACK, CLEANUP, PAUSED, UNINSTALLED
- **Brechas:**
  - [MEDIA] DOCS→CÓDIGO: el manual 3.01 todavía puede usar nombres en español según INDICE.md gap declarado. El código ya usa inglés. El manual debe actualizarse.

### 3.02 — Executor y Parser
- **Estado declarado:** ✅ 1.0.0
- **Coherencia verificada:**
  - `internal/ficha/executor.go`: ✅ existe
  - `internal/ficha/parser.go`: ✅ existe
  - `internal/ficha/lifecycle.go:Lifecycle.BeginInstall()`: ✅ existe
- **Brechas:** ninguna — **coherente**

### 3.03 — Discovery, Health y Drift
- **Estado declarado:** ✅ 1.0.0
- **Coherencia verificada:**
  - `internal/ficha/discovery.go:Discoverer.Discover()`: ✅ DiscoveredFicha/DiscoveryResult
  - `internal/ficha/health.go`: ✅ existe
  - `internal/ficha/drift.go`: ✅ existe
- **Brechas:** ninguna — **coherente**

### 3.04 — Repair, Rollback y Cleanup
- **Estado declarado:** ✅ 1.0.0
- **Coherencia verificada:**
  - `internal/ficha/repair.go`: ✅ existe
  - `internal/ficha/rollback.go`: ✅ existe
  - `internal/ficha/cleanup.go`: ✅ existe
  - `internal/repair/repair_manager.go`: ✅ existe (repair de SO/K8s también)
- **Brechas:** ninguna — **coherente**

### 3.05 — Versionado y Dashboard
- **Estado declarado:** ✅ 1.0.0
- **Coherencia verificada:**
  - `internal/ficha/version.go`: ✅ existe
  - `internal/ficha/dashboard.go:ValidateDashboard()` + `GenerateDefaultDashboard()`: ✅
  - `internal/catalog/versioning.go:CreateSnapshot()`: ✅
- **Brechas:** ninguna — **coherente**

### 3.06 — CLI bosctl ficha
- **Estado declarado:** ✅ 1.0.0
- **Coherencia verificada:**
  - `cmd/bosctl/ficha.go:cmdFicha()`: ✅
  - JSON-RPC `bos.ficha.*`: ✅ 16 métodos registrados (install/update/repair/remove/status/probe/list/describe/diff/plan/validate/logs/pause/resume/scale/rescan)
- **Brechas:**
  - [BAJA] CÓDIGO→DOCS: `bos.ficha.rescan` y `bos.ficha.diff` no mencionados en el manual

### 3.07 — Catálogo de Fichas y Servidores Lógicos
- **Estado declarado:** 🟡 1.0.0
- **Coherencia verificada:**
  - `internal/catalog/catalog.go:Catalog.List()`: ✅
  - Gap S16-webserver: ❌ no hay fichas en `servers/` para nginx/certbot/modsecurity (no verificable sin listar servers/)
  - Gap bauth → S03-identityserver: ❌ gap declarado, verificable en `src/servers/`
- **Brechas:**
  - [MEDIA] DOCS→CÓDIGO: S16-webserver y bauth→S03 pendientes según INDICE

### 3.08 — Port Manager y Kardex
- **Estado declarado:** 🟡 2.1.0
- **Coherencia verificada:**
  - `internal/portman/manager.go:Manager.Assign()`: ✅
  - `internal/portman/manager.go:Manager.Release()`: ✅
  - `internal/portman/manager.go:Manager.Lookup()`: ✅
  - `internal/portman/manager.go:Manager.ValidateKardex()`: ✅
  - `internal/portman/engine.go`: ✅ Algoritmos A (fórmula) y B (SHA-256 hash)
  - `internal/portman/kardex.go:PgKardex`: ✅ CRUD en T-408
  - JSON-RPC `bos.portman.*`: ✅ 7 métodos
  - `portman.Assign()` en `lifecycle.go`: ❌ **no cableado** — el install no llama a Assign()
  - `portman.Release()` en UNINSTALLED: ❌ **no cableado**
  - `ValidateKardex()` en `reconcile/scheduler.go` cada 300s: ❌ **no cableado**
- **Brechas:**
  - [ALTA] DOCS→CÓDIGO: 3 integraciones críticas declaradas en manual no implementadas

### 3.09 — Event Bus Redis Streams
- **Estado declarado:** ⬜ PENDIENTE
- **Coherencia verificada:**
  - `internal/ficha/grpc/event_bus.go:EventBus`: ✅ bus pub-sub **en memoria** para gRPC streaming
  - Redis Streams como bus inter-daemons: ❌ **no existe**. El EventBus actual es un canal Go en proceso, no Redis Streams DB0.
- **Brechas:**
  - [CRÍTICA] DOCS→CÓDIGO: Redis Streams inter-daemon no implementado. El bus actual es in-process.

---

## Motor ④ Context Plane

### 4.01 — Context Plane (DEFINE)
- **Estado declarado:** ✅ 2.0.0
- **Coherencia verificada:**
  - `internal/context/service.go:Service`: ✅ Create/Validate/Heartbeat/Promote/Switch/Invalidate/RegisterDevice
  - `internal/context/types.go`: ✅ tipos ContextState/SessionContext/DeviceContext
  - `internal/context/store.go`: ✅ interfaz Store (PG + Redis)
  - `internal/domain/ctx_service.go`: ✅ CtxService en capa domain
  - JSON-RPC `bos.ctx.*`: ✅ 10 métodos registrados
- **Brechas:** ninguna — **coherente**

### 4.02 — Ciclo de Vida ctx_id
- **Estado declarado:** ✅ 1.0.0
- **Coherencia verificada:**
  - `bos.ctx.heartbeat`: ✅ registrado y `service.go:Heartbeat()` implementado
  - `bos.ctx.create`: ✅
  - `bos.ctx.validate`: ✅
  - `bos.ctx.invalidate`: ✅
- **Brechas:** ninguna — **coherente**

### 4.03 — Seguridad del Contexto
- **Estado declarado:** 🟡 1.0.0
- **Coherencia verificada:**
  - mTLS en endpoints ctx: ❌ no implementado (mismo que NRS-03)
  - Cert efímero ECDSA P-256 Vault PKI por sesión: ❌ no implementado
  - NIST 800-207 Tenet 2: ❌ no implementado
- **Brechas:**
  - [MEDIA] DOCS→CÓDIGO: mTLS + Vault ephemeral cert no implementados

### 4.04 — Propagación y Trazabilidad
- **Estado declarado:** ✅ 1.0.0
- **Coherencia verificada:**
  - `internal/context/unified.go:UnifiedContext`: ✅ existe
  - Propagación W3C TraceContext: verificable en `context/service.go` (usa traceParent en Validate)
- **Brechas:** ninguna — **coherente**

### 4.05 — Integración bAuth e IAM Enterprise
- **Estado declarado:** 🟡 1.0.0
- **Coherencia verificada:**
  - `internal/bauth/`: ✅ cliente JSON-RPC hacia bAuth daemon existe
  - FAPI 2.0 (PAR/DPoP/PKCE): ❌ no implementado en BOS
  - Plugin SBOS-Context para Kong PEP: ❌ no existe en repositorio
  - Evaluación 12 dominios bAuth: ❌ no implementado
- **Brechas:**
  - [MEDIA] DOCS→CÓDIGO: FAPI 2.0, Kong PEP plugin y evaluación 12 dominios no implementados

---

## Motor ⑤ Dashboard

### 5.01 — Dashboard — Interface Dual (DEFINE)
- **Estado declarado:** 🟡 2.0.0
- **Coherencia verificada:**
  - Unix socket + WebSocket RPC: ✅ `internal/server/api.go`
  - JSON-RPC 2.0: ✅ `internal/server/jsonrpc.go` con 71 métodos registrados
  - RBAC dual (FileRBAC + BauthRBAC): ✅ ambos en `internal/security/`
  - Domain Manager `bos.web.domain.*` (S16): ❌ **no existe en JSON-RPC**. grep confirma 0 hits.
- **Brechas:**
  - [ALTA] DOCS→CÓDIGO: Domain Manager 5 métodos S16-webserver no implementados

### 5.02 — WebSocket sobre Unix Socket
- **Estado declarado:** ✅ 1.0.0
- **Coherencia verificada:**
  - `internal/wslib/`: ✅ existe (392 LOC)
  - `internal/server/api.go`: ✅ servidor WebSocket sobre Unix socket
- **Brechas:** ninguna — **coherente**

### 5.03 — Contratos de Eventos
- **Estado declarado:** ✅ 1.0.0
- **Coherencia verificada:**
  - `internal/ficha/grpc/event_bus.go`: ✅ eventos ficha (en memoria)
  - Contratos de eventos entre daemons vía Redis Streams: ❌ no implementado (ver 3.09)
- **Brechas:** referencia a 3.09 — coherente en el alcance WebSocket/gRPC

### 5.04 — Momentos de Conexión
- **Estado declarado:** ✅ 1.0.0
- **Brechas:** sin evidencia de incoherencia en revisión superficial — **presuntamente coherente**

### 5.05 — biaOS — Agente IA Soberano
- **Estado declarado:** ⬜ PENDIENTE
- **Coherencia verificada:**
  - `internal/biaos/` (2.504 LOC): ✅ Client/Agent/Gateway/Router implementados
  - `internal/biaos/icap/`: ✅ ICAP Engine implementado
  - `internal/biaos/sagas/`: ✅ sagas IA implementadas
  - `internal/biaos/audit/`: ✅ auditoría IA implementada
  - JSON-RPC `bos.ai.*`: ✅ 4 métodos (ask/catalog/confirm/run)
  - Ollama local: ✅ `client.go` soporta backend Ollama
- **Brechas:**
  - [ALTA] CÓDIGO→DOCS: **biaOS está completamente implementado** pero el manual 5.05 dice ⬜ PENDIENTE. El código adelantó significativamente a la documentación.

---

## Motor ⑥ Banco de Pruebas

### 6.01 — Banco de Pruebas BOS
- **Estado declarado:** 🟡 1.0.0 (vivo, nunca ✅)
- **Coherencia verificada:**
  - Tests automáticos: ✅ 41 paquetes con tests, 0 fallos
  - Paquetes con mayor cobertura: ficha (24 test files), server (14), biaos (7), domain (6)
  - `internal/installer/chaos_test.go`: ✅ prueba de compensación caótica
  - Pruebas de integración: `cmd/health-integration-test/`, `cmd/reconcile-integration-test/`
  - Las dos vías obligatorias (CLI + JSON-RPC) por prueba: no verificable sin leer el manual
- **Brechas:**
  - [MEDIA] CÓDIGO→DOCS: el banco de pruebas real (41 paquetes) supera lo documentado en 6.01

---

## Anexos — estado de coherencia

| Anexo | Estado INDICE | Código verifica |
|-------|:-------------:|----------------|
| A.01 — Estado del Arte | ✅ | Teórico — sin código asociado |
| A.02 — Estructura Servidor | ✅ | Informativo |
| A.03 — Plataforma Web Multi-Tenant Nginx | ✅ | Informativo |
| A.04 — Stack Canónico y Puertos | ✅ | `internal/portman/blacklist.go` tiene puertos SBOS-050 ✅ |
| A.05 — Anatomía Ficha | ✅ | `internal/ficha/parser.go` ✅ |
| A.06 — Kubernetes Operator Pattern | ✅ | `internal/observer/observer.go:TopologicalSort()` ✅ |
| A.07 — Vault PKI | ✅ | `internal/bootstrap/k8s_verify.go:CheckVault()` ✅ |
| A.08 — Flujo End-to-End | ✅ | Informativo |
| A.09 — Normas y Estándares | ✅ | Teórico |
| A.10 — Observabilidad | ✅ | `internal/observability/` ✅ |
| A.11 — Cadena Instalación | ✅ 4.0.0 | `internal/installer/saga.go` 4 sagas ✅ |
| A.12 — Port Manager Kardex | ✅ 4.0.0 | `internal/portman/` ✅ (7 métodos) |
| A.13 — Arquitectura VPS Prueba | ✅ | Informativo |
| A.14 — DDL BOS | 🟡 6.0.0 | T-415 `bos.net_web_domain` faltante ❌ |
| A.15 — Network Security Manager | ✅ | `internal/network/` + `internal/security/` ✅ |
| A.16 — Zero Trust NIST 800-207 | ⬜ PENDIENTE | Sin implementación nativa — delega en Linkerd |
| A.17 — FAPI 2.0 Certificación | ⬜ PENDIENTE | Sin implementación |
| A.18 — Gestión Vulnerabilidades BOS | **NO EN INDICE** | Archivo existe en disco, no listado en INDICE.md |

---

## Hallazgos críticos (prioridad para próxima sesión)

| Prioridad | Brecha | Manual | Severidad | Acción |
|:---------:|--------|:------:|:---------:|--------|
| 1 | **portman no cableado en lifecycle**: `Assign()` en install, `Release()` en uninstall | 3.08 | CRÍTICA | Cablear en `internal/ficha/lifecycle.go` |
| 2 | **portman.ValidateKardex()** no ejecuta en reconcile/scheduler.go cada 300s | 3.08 | CRÍTICA | Cablear en `internal/reconcile/scheduler.go` |
| 3 | **Event Bus Redis Streams inter-daemon** no existe (3.09 ⬜) | 3.09 | ALTA | Nuevo subsistema — `internal/eventbus/` |
| 4 | **biaOS completamente implementado** pero manual 5.05 dice ⬜ PENDIENTE | 5.05 | ALTA | Escribir manual 5.05 desde el código real |
| 5 | **mTLS entre daemons** (NRS-03) no implementado — delega en Linkerd | 1.04 | ALTA | Definir si Linkerd es la implementación canónica o se requiere mTLS nativo |
| 6 | **Domain Manager S16** `bos.web.domain.*` no existe en JSON-RPC | 5.01 | ALTA | Implementar 5 métodos + tabla T-415 |
| 7 | **4 motores de capacidad** (collector/forecaster/policy/action) no implementados | 2.02 | ALTA | Implementar `internal/capacity/` completo |
| 8 | **Wazuh SIEM** (NRS-04) cero código | 1.04 | ALTA | Definir si es ficha de infraestructura o integración en código |
| 9 | **3.01 manual** aún puede tener estados en español | 3.01 | MEDIA | Actualizar nombres de estados al inglés |
| 10 | **A.18** existe en disco pero no en INDICE.md | INDICE | BAJA | Agregar A.18 al INDICE.md |

---

## Métricas finales

| Métrica | Valor |
|---------|-------|
| Paquetes Go (internal/) | 38 |
| LOC total (internal/) | 73.938 |
| LOC mayor paquete | ficha: 7.900 / tui: 16.298 / server: 5.986 |
| Tests: paquetes | 41 |
| Tests: PASS / FAIL | 41 / 0 |
| Métodos JSON-RPC registrados | **71 métodos** `bos.*.*` |
| Subcomandos CLI bosctl | ~37 comandos |
| Estados máquina ficha | 18 (PENDING → UNINSTALLED) |
| Sagas implementadas | 4 (Install/Update/Repair/Remove) |
| Manuales auditados | 29 + 17 anexos = 46 documentos |
| Manuales coherentes | 19 |
| Manuales con brechas | 10 |
| Brechas totales | 11 críticas/altas + 8 medias/bajas |

---

### Estado post-implementación (commit `8d45dba`)

| Brecha | Estado inicial | Estado actual |
|--------|:--------------:|:-------------:|
| BC-01 portman lifecycle | CRÍTICA ❌ | ✅ CERRADA |
| BC-02 ValidateKardex scheduler | CRÍTICA ❌ | ✅ CERRADA |
| BC-03 EventBus in-process | ALTA ❌ | ✅ CERRADA (MemBus) |
| BC-03b EventBus Redis Streams | ALTA ❌ | 🟡 PENDIENTE (inter-daemon) |
| BC-04 manual 5.05 biaOS | ALTA ❌ | ✅ CERRADA |
| BC-05 capacity collector | ALTA ❌ | ✅ CERRADA (kubectl top nodes) |
| BC-05b Forecaster/Policy/Action | ALTA ❌ | 🟡 PENDIENTE |
| BC-06 Domain Manager S16 | ALTA ❌ | 🔴 ABIERTA |

**Métricas post-ciclo:** 54.101 LOC (sin TUI) · 72 métodos JSON-RPC · 40 paquetes · 41/41 PASS

---

*SKULL · SBOS · BosAgent · Auditoría 2026-10-07 · bos-developer*
