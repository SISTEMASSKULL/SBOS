# Registro de Estado — BOS Control Plane
**Fecha:** 2026-10-07 (actualizado post-ciclo)
**Basado en:** `context/Documentacion/AUDITORIA-COHERENCIA-2026-10-07.md`
**Rama:** `main` · HEAD `8d45dba`
**Build:** ✅ OK · **Tests:** 41/41 PASS · **LOC:** 54.101 (sin TUI) · 72 métodos JSON-RPC · 40 paquetes

---

## Estado por motor (semáforo)

| Motor | Estado | Madurez | Bloqueante | Próxima acción obligatoria |
|-------|:------:|:-------:|:----------:|---------------------------|
| ① IAM Installer | 🟡 | L2 | NRS-03/04/10 sin código | Decidir: Linkerd = canónico para mTLS o implementar propio |
| ② SO Observable | 🟡 | L1-L2 | Forecaster/Policy/Action pendientes | BC-05 cerrado — Collector real; faltan §3-§6 |
| ③ Server FICHAS | 🟢 | L2 | BC-06 Domain Manager S16 | BC-01/02/03 cerrados — portman+eventbus cableados |
| ④ Context Plane | 🟢 | L2 | FAPI 2.0 no urgente | Actualizar 4.03 con decisión sobre mTLS |
| ⑤ Dashboard | 🟢 | L2 | Domain Manager S16 sin code | BC-04 cerrado — manual 5.05 biaOS ✅ 2.0.0 |
| ⑥ Banco de Pruebas | 🟢 | L2 | 6.01 no refleja tests reales | Actualizar 6.01 con los 41 paquetes de tests |

---

## Inventario de paquetes Go

| Paquete | LOC | Archivos test | Estado | Madurez |
|---------|----:|:-------------:|--------|:-------:|
| `internal/ficha` | 7.900 | 24 | Máquina 18 estados completa | L2 ✅ |
| `internal/tui` | 16.298 | 21 | **TUI descontinuada** (ver nota) | L0 |
| `internal/server` | 5.986 | 14 | 71 métodos JSON-RPC | L2 ✅ |
| `internal/biaos` | 2.504 | 7 | Client+Agent+ICAP+Router | L2 ✅ |
| `internal/domain` | 1.635 | 6 | Bootstrap/Ctx/PgAux/Ficha services | L2 ✅ |
| `internal/context` | 1.356 | 4 | ctx_id full lifecycle + PG+Redis | L2 ✅ |
| `internal/bootstrap` | 1.041 | 3 | C-01..C-08 + K8s stack checks | L2 ✅ |
| `internal/installer` | 935 | 1 | 4 sagas + compensador | L2 ✅ |
| `internal/portman` | 873 | 1 | 7 métodos, Kardex PG, Alg A+B | L2 🟡 (sin cablear) |
| `internal/repair` | 883 | 0 | OS+K8s repair manager | L1 (sin tests) |
| `internal/k8s` | 801 | 1 | Core dispatcher único kubectl (P1) | L2 ✅ |
| `internal/security` | 1.221 | 0 | FileRBAC+BauthRBAC+CIS+K8s checks | L1 (sin tests) |
| `internal/state` | 729 | 2 | State Manager fcntl.flock | L2 ✅ |
| `internal/observability` | 578 | 0 | HealthReport + top | L1 (sin tests) |
| `internal/observer` | 660 | 2 | DAG topológico + P15Reconcile | L2 ✅ |
| `internal/reconcile` | 579 | 2 | Scheduler + K8sDiscovery + Drift | L2 ✅ |
| `internal/release` | 555 | 0 | Manager + Ed25519 verifier | L1 (sin tests) |
| `internal/catalog` | 398 | 0 | Versioning + Snapshots + Catalog | L1 (sin tests) |
| `internal/health` | 399 | 1 | Health checker | L2 ✅ |
| `internal/config` | 428 | 1 | Config loader bos.toml | L2 ✅ |
| `internal/capacity` | 276 | 0 | Cálculo estático — 4 motores pendientes | L0 |
| `internal/watchdog` | 493 | 1 | UnifiedWatchdog 3-capas | L2 ✅ |
| `internal/metrics` | 222 | 1 | Registry Counter/Gauge Prometheus | L2 ✅ |
| `internal/plugin` | 570 | 2 | Loader fichas servers/ | L2 ✅ |
| `internal/network` | 192 | 1 | NRS-01/02/05..09 | L2 ✅ |
| `internal/sanitize` | 175 | 1 | Input sanitization | L2 ✅ |
| `internal/ratelimit` | 147 | 1 | Rate limiter | L2 ✅ |
| `internal/bauth` | 359 | 2 | Cliente JSON-RPC hacia bAuth | L2 ✅ |
| `internal/scaler` | 177 | 1 | Scaler policy (desconectado de capacity) | L1 |
| `internal/packages` | 670 | 0 | OS packages manager | L1 (sin tests) |
| `internal/maintenance` | 240 | 1 | Maintenance mode | L2 ✅ |
| `internal/cgroup` | 254 | 1 | cgroup helpers | L2 ✅ |
| `internal/query` | 550 | 1 | Query sources (node/tenant/system/vdi) | L2 ✅ |
| `internal/wslib` | 392 | 0 | WebSocket lib | L1 (sin tests) |
| `internal/audit` | 108 | 1 | audit.Log | L2 ✅ |
| `internal/paths` | 193 | 1 | Constantes rutas canónicas | L2 ✅ |
| `internal/toml` | 220 | 0 | TOML parser bos-install.toml | L1 |
| `internal/system` | 130 | 2 | syscall helpers | L2 ✅ |

> **Nota TUI:** `internal/tui/` (16.298 LOC) está descontinuada por decisión de arquitectura (ver memoria `bos-tui-descontinuado.md`). La única interfaz válida es bosctl (CLI) + JSON-RPC 2.0. No se extiende ni se cuentan sus TODOs.

---

## Métodos JSON-RPC implementados (71 métodos)

### Módulo `bos.ai.*` (4 métodos)
- `bos.ai.ask` · `bos.ai.catalog` · `bos.ai.confirm` · `bos.ai.run`

### Módulo `bos.bootstrap.*` (8 métodos)
- `bos.bootstrap.start` · `bos.bootstrap.status` · `bos.bootstrap.verify` · `bos.bootstrap.resume`
- `bos.bootstrap.pg_auxiliar_start` · `bos.bootstrap.pg_auxiliar_status` · `bos.bootstrap.pg_auxiliar_sync` · `bos.bootstrap.pg_auxiliar_cleanup`

### Módulo `bos.capacity.*` (2 métodos)
- `bos.capacity.check` · `bos.capacity.status`

### Módulo `bos.ctx.*` (10 métodos)
- `bos.ctx.create` · `bos.ctx.get` · `bos.ctx.validate` · `bos.ctx.heartbeat` · `bos.ctx.invalidate`
- `bos.ctx.list` · `bos.ctx.promote` · `bos.ctx.switch` · `bos.ctx.auto_migrate` · `bos.ctx.device.register`
- `bos.ctx.tenant.suspend`

### Módulo `bos.ficha.*` (16 métodos)
- `bos.ficha.install` · `bos.ficha.update` · `bos.ficha.repair` · `bos.ficha.remove`
- `bos.ficha.status` · `bos.ficha.probe` · `bos.ficha.list` · `bos.ficha.describe`
- `bos.ficha.diff` · `bos.ficha.plan` · `bos.ficha.validate` · `bos.ficha.logs`
- `bos.ficha.pause` · `bos.ficha.resume` · `bos.ficha.scale` · `bos.ficha.rescan`

### Módulo `bos.health.*` (1 método)
- `bos.health.check`

### Módulo `bos.k8s.*` (11 métodos)
- `bos.k8s.node.list` · `bos.k8s.node.cordon` · `bos.k8s.node.drain` · `bos.k8s.node.uncordon`
- `bos.k8s.pod.evict` · `bos.k8s.pod.restart`
- `bos.k8s.scale` · `bos.k8s.resources.set`
- `bos.k8s.rollout.status` · `bos.k8s.rollout.undo`

### Módulo `bos.maintenance.*` (3 métodos)
- `bos.maintenance.start` · `bos.maintenance.status` · `bos.maintenance.cancel`

### Módulo `bos.portman.*` (7 métodos)
- `bos.portman.assign` · `bos.portman.release` · `bos.portman.lookup` · `bos.portman.check`
- `bos.portman.list` · `bos.portman.validate` · `bos.portman.export`

### Módulo `bos.query.*` (6 métodos)
- `bos.query.node` · `bos.query.tenant` · `bos.query.system` · `bos.query.context`
- `bos.query.repair` · `bos.query.vdi`

### Módulo `bos.release.*` (2 métodos)
- `bos.release.check` · `bos.release.list`

### Módulo `bos.saga.*` (1 método)
- `bos.saga.execute`

### Módulo `bos.state.*` (1 método)
- `bos.state.read`

> **Faltante declarado:** módulo `bos.web.domain.*` (Domain Manager S16-webserver, 5 métodos) — **no implementado**

---

## CLI bosctl — subcomandos implementados (~37 comandos)

```
dashboard/dash  status       setup/install  release     remove
upgrade         repair       shutdown       logs        reload
health          top          health-report  identity    security
app             ask/ia       set            exec        ls
cat             tail         systemctl      journalctl  ctx
node            vdi          ai             query       ficha
deploy          tenant       bootstrap      port        rpc
system-install  dev          help
```

---

## Brechas críticas (bloqueantes para avanzar)

### ~~BC-01 — Port Manager sin cablear en lifecycle~~ ✅ CERRADA (`8d45dba`)
- `domain.PortAssignerPort` + `server.fichaPortAdapter` — `AssignFicha` en Install, `ReleaseFicha` en Remove
- Wiring en `server/api.go:SetPortManager()` → `NewFichaPortAdapter(pm)`

### ~~BC-02 — ValidateKardex no ejecuta en reconciliación~~ ✅ CERRADA (`8d45dba`)
- `reconcile.KardexValidator` interface + `WithPortManager()` + ticker 300s + `validateKardex()`

### ~~BC-03 — Event Bus in-process~~ ✅ CERRADA (in-process) — BC-03b inter-daemon PENDIENTE
- `internal/eventbus/`: `MemBus`, `NoopBus`, `Event`, constantes `EvFicha*`
- `server.fichaEventAdapter` + `EventPublisherPort` en `FichaService`: Install/Repair/Remove publican eventos
- **BC-03b pendiente:** Redis Streams DB0 para bus inter-daemon (manual 3.09)

### ~~BC-04 — biaOS manual 5.05 inexistente~~ ✅ CERRADA (`8d45dba`)
- `5.05_MANUAL-DASHBOARD-BIAOS.md` v2.0.0: Router 3-tiers, Gateway, ciclo ReAct ≤6, ICAP, HITL, 4 métodos JSON-RPC
- INDICE.md: 5.05 ✅ 2.0.0

### ~~BC-05 — Motores de capacidad stub~~ ✅ PARCIALMENTE CERRADA (`8d45dba`)
- `capacity.Collector` con `kubectl top nodes`: `Collect()`, `CheckAdmission()`, `parseKubectlTop()`
- **BC-05b pendiente:** Forecaster / PolicyEngine / ActionEngine (§3-§6 del manual 2.02)

### ~~BC-06 — Domain Manager S16-webserver~~ ✅ CERRADA (2026-10-07)
- `internal/domain/webdomain_service.go`: `WebDomainService.Add/Remove/List/Resolve/SSLStatus`, interfaces `WebDomainPort` + `WebNginxPort`
- `internal/domain/webdomain_infra.go`: `MemWebDomain` (thread-safe), `NoopNginx` (test stub), `NginxManager` (nginx+certbot+openssl)
- `internal/domain/webdomain_service_test.go`: 6 tests — Add, AddDuplicate, AddInvalidDomain, List, Resolve, Remove, SSLNotProvisioned
- `internal/server/rpc_web.go`: 5 handlers — rpcWebDomainAdd/Remove/List/Resolve/SSLStatus
- `internal/server/api.go`: campo `webDomain` + `SetWebDomainService()`
- `internal/server/jsonrpc.go`: 5 métodos `bos.web.domain.*` registrados
- `cmd/bosctl/web.go`: `cmdWeb` → `cmdWebDomain` → 5 subcomandos (add/remove/list/resolve/ssl-status)
- `cmd/bosctl/main.go`: `case "web":` dispatcher
- `context/Documentacion/PROPUESTA-T415-net_web_domain.md`: DDL T-415 — **HITL pendiente**
- **Pendiente HITL:** aprobación de T-415 `bos.net_web_domain` en SBOSDB + implementar `PgWebDomain`

---

## Deuda técnica identificada

| ID | Descripción | Paquete | Severidad |
|----|-------------|---------|:---------:|
| DT-01 | `internal/repair/` sin tests (883 LOC, 0 test files) | repair | MEDIA |
| DT-02 | `internal/security/` sin tests (1.221 LOC, 0 test files) | security | MEDIA |
| DT-03 | `internal/release/` sin tests (555 LOC, 0 test files) | release | MEDIA |
| DT-04 | `internal/catalog/` sin tests (398 LOC, 0 test files) | catalog | BAJA |
| DT-05 | `internal/scaler/` desconectado de `internal/capacity/` — no integrados | scaler+capacity | MEDIA |
| DT-06 | `internal/tui/` (16.298 LOC) es código muerto descontinuado — consume contexto de tests | tui | BAJA |
| DT-07 | A.18 existe en disco (`Anexos/A.18_ANEXO-GESTION-VULNERABILIDADES-BOS.md`) pero no está en INDICE.md | docs | BAJA |
| DT-08 | `3.01_MANUAL-SERVER-FICHAS.md` puede tener estados en español (código ya usa inglés) | docs | BAJA |

---

## Plan de siguiente sesión (orden de prioridad)

### ~~Fase I — COMPLETADA (commit `8d45dba`)~~

BC-01/02/03/04/05 cerradas. Ver sección "Ciclo de implementación 2026-10-07 — CERRADO" al final.

### Fase III — Event Bus Redis Streams (3.09)

**Tarea III.A — Diseñar subsistema eventbus** (~3h)
1. Crear `internal/eventbus/` con cliente Redis Streams
2. Definir contratos de eventos: ficha.installed / ficha.degraded / ficha.repaired / ficha.uninstalled / ctx.promoted / ctx.invalidated
3. Publicar desde lifecycle.go al completar transiciones críticas
4. Escribir manual 3.09

### Fase II — Próxima sesión (brechas abiertas)

**Tarea II.A — BC-06: Domain Manager S16-webserver** (~3h)
1. Crear `internal/domain/webdomain_service.go` — 5 operaciones: create/update/delete/list/status
2. Agregar 5 métodos `bos.web.domain.*` en `internal/server/jsonrpc.go`
3. Crear tabla T-415 `bos.net_web_domain` en `DDLs/SBOS_db_V2_DDL.sql`
4. Agregar subcomandos `bosctl web domain` en `cmd/bosctl/`

**Tarea II.B — DT-01: Tests repair/** (~2h)
- Crear `internal/repair/repair_manager_test.go` — cubrir `RepairOS`, `RepairK8s`, `RepairFicha`

**Tarea II.C — BC-05b: Forecaster de capacidad** (~2h)
- Crear `internal/capacity/forecaster.go` — tendencia lineal sobre histórico de métricas
- Integrar con `Collector` para predicción de agotamiento (ETA en horas)

**Tarea II.D — BC-03b: EventBus Redis Streams** (~4h)
- Crear `internal/eventbus/redis_bus.go` — cliente Redis Streams DB0
- Migrar `FichaService` para usar `RedisBus` en producción y `MemBus` en tests

---

## Hitos completados (historial reciente)

| Commit | Descripción | Relevancia |
|--------|-------------|------------|
| `8d45dba` | feat(bos): portman+eventbus+capacity+manual 5.05 | ✅ BC-01..BC-05 cerradas |
| `e9df9a2` | docs(bos): auditoría coherencia docs↔código | Auditoría inicial |
| `4467ec6` | docs: REGISTRO-ESTADO.md — auditoría S-47 | Documentación |
| `380cd69` | feat(portman): Motor de Asignación de Puertos SBOS-050 | ✅ Portman completo |
| `a05da47` | docs(plan): 0.01 v3.0.0 | Plan completitud |

---

## Contexto arquitectónico rápido

```
SKULL Release Plane (pull-only, Ed25519+SHA-256)
    ↓
BOS IAM Installer (host systemd, /run/bos/bos.sock)
    ├── Unix socket WebSocket RPC (bosctl CLI)  [Vía 1]
    ├── Unix socket JSON-RPC 2.0 (daemons/IA)  [Vía 2]
    └── TCP 0.0.0.0:9443 HTTPS/TLS 1.3 (Kong + probes)
         ↓
Kubernetes Cluster
    ├── PostgreSQL 18.4 (bos schema 20 tablas)
    ├── Redis 8.6.2
    ├── Vault 2.0.1
    ├── Keycloak 26.6.2
    └── Kong 3.9.x LTS
         ↓
22 fichas declarativas en servers/ (manifest.yml + task_catalog.sh)
```

**Patrones obligatorios en todo código nuevo:**
1. `doRPCCall()` en bosctl para toda llamada RPC
2. `domain/<servicio>.go` → `server/jsonrpc.go` → `cmd/bosctl/<cmd>.go` (ADR-020)
3. `k8s.Core` es el único dispatcher kubectl (P1 — nunca kubectl directo)
4. Todo commit: `[FX.Y] tipo: descripcion` + build verde + tests pasando

---

---

## Ciclo de implementación 2026-10-07 — CERRADO

### Brechas cerradas (commit `8d45dba`)

| Brecha | Descripción | Archivos clave | Estado |
|--------|-------------|----------------|:------:|
| BC-01 | portman cableado en FichaService | `domain/ficha_service.go` + `server/portman_adapter.go` | ✅ CERRADA |
| BC-02 | ValidateKardex ticker 300s en Scheduler | `reconcile/scheduler.go` | ✅ CERRADA |
| BC-03 | EventBus MemBus in-process | `internal/eventbus/` + `server/eventbus_adapter.go` | ✅ CERRADA |
| BC-04 | Manual 5.05 biaOS v2.0.0 | `Documentacion/5.05_MANUAL-DASHBOARD-BIAOS.md` | ✅ CERRADA |
| BC-05 | Capacity Collector kubectl top nodes | `internal/capacity/collector.go` | ✅ CERRADA |

**Métricas post-ciclo:** 54.101 LOC (sin TUI) · 72 métodos JSON-RPC · 40 paquetes · 41/41 tests PASS

### Brechas abiertas para próximo ciclo

| Brecha | Descripción | Prioridad |
|--------|-------------|:---------:|
| BC-06 | `bos.web.domain.*` Domain Manager S16-webserver (5 métodos, T-415) | ALTA |
| BC-03b | EventBus Redis Streams inter-daemon (reemplazar MemBus in-process) | ALTA |
| BC-05b | Motores capacidad §3-§6: Forecaster / PolicyEngine / ActionEngine | ALTA |
| DT-01 | `internal/repair/` sin tests (883 LOC, 0 archivos _test.go) | MEDIA |
| DT-02 | `internal/security/` sin tests (1.221 LOC, 0 archivos _test.go) | MEDIA |
| DT-03 | `internal/release/` sin tests (555 LOC, 0 archivos _test.go) | MEDIA |
| DT-05 | `internal/scaler/` desconectado de `internal/capacity/` | MEDIA |

---

*SKULL · SBOS · BosAgent · Registro de Estado 2026-10-07 · bos-developer*
