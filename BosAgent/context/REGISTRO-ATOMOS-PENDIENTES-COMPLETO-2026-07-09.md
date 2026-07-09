# REGISTRO DE ÁTOMOS PENDIENTES — Auditoría Completa
## BosAgent · 2026-07-09 · Átomo por átomo contra código real

---

## ① BOS IAM Installer

### FASE M — Milestones

**M1.1** ✅ — Observer host /proc. `internal/tui/observer/reader.go` EXISTE.
**M1.2** ✅ — writeDefaultService User=bosagent. `system_install.go` EXISTE.
**M1.3** ✅ — bos.service socket. `staging/bos.service` EXISTE.
**M1.4** ✅ — Context API :9443. `api.go:handleContextLookup` EXISTE (5 refs).
**M1.5** ✅ — DDL auto-apply. `run_normal.go:AutoMigrate` EXISTE (4 refs).
**M1.CAP** 🟡 — Modelo capacidad. `internal/capacity/` 3 archivos (modelo, calculadora, persist). **Faltan 4 motores:** collector.go, forecaster.go, policy_engine.go, action_engine.go NO EXISTEN.
**M2.1** ✅ — Ficha Engine resolver Kahn. `internal/ficha/resolver.go` EXISTE (9 refs).
**M2.2** 🔴 — Stack Alpha VPS. Requiere VPS con PG+Redis instalados. CÓDIGO LISTO (fichas existen), VPS NO DISPONIBLE.
**M2.3** 🟡 — bootstrap verify funcional. `internal/bootstrap/verify.go` EXISTE (39 refs C-01..C-08). Requiere VPS.
**M2.4** 🟡 — bosctl deploy saga 7 pasos. `deploy.go` EXISTE (5 refs). Bug Redis/k3s. CÓDIGO LISTO.
**M2.5** 🔴 — **REGISTRO DICE ✅ PERO ES FALSO.** `s05_instalando.go` tiene 0 referencias a WebSocket/eventos.
**M3.1-M3.4** 🔴 — Context Plane real. CÓDIGO LISTO (`internal/context/`). Requiere VPS+Redis.
**M4.1** 🔴 — 50+ métodos JSON-RPC probados. CÓDIGO LISTO (65 métodos registrados, `RPC-CATALOG.md` existe). No probados contra daemon real.
**M4.2** 🔴 — bos.query.system K8s real. CÓDIGO LISTO (`internal/query/`). No probado.
**M4.3** 🔴 — Dashboard TUI métricas reales. NO IMPLEMENTADO.
**M4.4** 🔴 — JSON-RPC P99 < 150ms. NO MEDIDO.
**M5.1-M5.5** 🔴 — 4 motores capacidad + forecast. `internal/capacity/collector.go`, `forecaster.go`, `policy_engine.go`, `action_engine.go` NO EXISTEN.
**M6.1-M6.5** 🔴 — Certificación SLOs + FAPI 2.0 + ISO 27001. NO IMPLEMENTADO.
**M7.1-M7.8** 🔴 — bAuth DDL 155 tablas + templates + políticas + configs + menú + domain_classification + bos.GetContext + bAuth integration. NO IMPLEMENTADO.

### FASE 3.C — Contratos BOS↔TUI (43 átomos)

**F3.C.1** 🔴→🟡 — WebSocket Unix socket. `ws_transport.go` + `ws_hub.go` + `ws_types.go` EXISTEN. Código parcial.
**F3.C.2** 🔴 — Redis Streams eventbus. `internal/eventbus/` NO EXISTE.
**F3.C.3** 🔴 — File tail log_reader. `log_reader.go` NO EXISTE.
**F3.C.4** 🔴→🟡 — Interface Dual rpc_registry. 65 métodos en `jsonrpc.go`. `rpc_registry.go` independiente NO EXISTE.
**F3.C.5** 🔴 — contracts/events/. NO EXISTE.
**F3.C.6-F3.C.43** 🔴 — 38 átomos (eventos SAGA_STARTED a SAGA_COMPLETED, comandos START_SAGA a SUBSCRIBE_LOGS, SEED_PARAMS, 3 momentos conexión, DC-01 a DC-10, anti-patrones CI). NINGUNO IMPLEMENTADO.

### FASE 10.B — Instalador Funcional

**F10.B.0** ✅ — Norma ADR-022 en CLAUDE.md.
**F10.B.1** 🔴 — **REGISTRO DICE ✅ (≤15 líneas).** install.sh = 49 líneas. **FALSO.**
**F10.B.2** ✅ — system_install.go 393 líneas.
**F10.B.3** ✅ — bos-preflight declarativa. manifest.yml + task_catalog.sh EXISTEN.
**F10.B.4** ✅ — env_loader.go EXISTE.
**F10.B.5** 🔴 — **REGISTRO DICE ✅. writeTenantConf() NO EXISTE en código. FALSO.**
**F10.B.6-F10.B.8** ✅ — setup.go fix, bos.service, writeDefaultService.
**F10.B.9** 🔴 — TUI ScreenInstalling eventos. NO IMPLEMENTADO.
**F10.B.10** ✅ — bos-preflight durante ScreenWelcome.
**F10.B.11** ✅ — Context API :9443 handleContextLookup.
**F10.B.12** ✅ — DDL auto-apply AutoMigrate.

### FASE 10.C — Ciclo Tenants

**F10.C.1-F10.C.10** ✅ — seed.yml, saga 7 pasos, compensación, deploy CLI. CÓDIGO EXISTE.
**F10.C.11** 🟡 — tenant suspend. Esqueleto listo, falta invalidación real.
**F10.C.12** 🟡 — tenant remove. Esqueleto listo, falta implementar remove.
**F10.C.13** 🔴 — product install. NO IMPLEMENTADO.
**F10.C.14** 🔴 — Validación e2e VPS. Requiere VPS.

### FASE 13 — Capa 4 Identidad (13 átomos 🔴)

**F13.1** 🔴→🟡 — Ficha keycloak. task_catalog.sh + manifest.yml EXISTEN en servers/S03/keycloak/.
**F13.2** 🔴→🟡 — Ficha vault. task_catalog.sh + manifest.yml EXISTEN en servers/S02/vault/.
**F13.3** 🔴→🟡 — Ficha kong. task_catalog.sh + manifest.yml EXISTEN en servers/S02/kong/.
**F13.4** 🔴 — Ficha bauth. NO EXISTE servers/S03/bauth/.
**F13.5-F13.13** 🔴 — Kong Plugin, JWT claims, FAPI 2.0, Step-Up, Linkerd, Kyverno, Kong rutas gRPC, error mapping, certificación. NO IMPLEMENTADO.

### FASE 14 — Daemons Stubs (8 átomos 🔴)

**F14.1-F14.8** 🔴 — bauth-stub, bhnexus-stub, banexus-stub, bkernel-stub, biedata-stub, bsearch-stub, bcompass-stub, certificación. NINGUNO IMPLEMENTADO.

### FASE 21 — Seguridad de Red (16 átomos 🔴)

**F21.1-F21.4 (V2), F21.A.1-F21.D.5** 🔴 — NetworkPolicy, TLS 1.3, mTLS, Wazuh, sanitize package, rate limiter, WebSocket hardening, anti-enumeration, CI security, Prometheus security metrics, audit log, dependency check, HTTP prohibition. NINGUNO IMPLEMENTADO.

### FASE 22 — Soberanía de Fichas (14 átomos 🔴)

**F22.1-F22.4 (V2), F22.A.1-F22.D.2** 🔴 — bosctl setup e2e, golden path, auditoría comandos manuales, auditoría install.sh, auditoría recursos, auditoría paquetes, CI checks SOV, fichas bos-certs/bos-firewall/bos-logrotate/bos-ntp, docs SOV-COMPLIANCE. NINGUNO IMPLEMENTADO.

### FASE 23 — Blockchain S12 (12 átomos 🔴)

**F23.A.1-F23.F.2** 🔴 — Servidor S12, NetworkPolicy, besu-genesis (manifest+task), besu-validator (manifest+task+keys), besu-rpc (manifest+task), bauth-blockchain-config (manifest+task), StorageClass, monitoreo. NINGUNO IMPLEMENTADO.

### FASE 24 — Cierre bAuth (5 átomos 🔴)

**F24.A.1-F24.B.4** 🔴 — Ficha postgis, widgets MapPointPicker, temporales, seguridad, menu_context. NINGUNO IMPLEMENTADO.

---

## ② BOS SO Observable

### FASE M5 — 4 Motores Capacidad

**M5.1** 🔴 — Motor Observación. `internal/capacity/collector.go` NO EXISTE.
**M5.2** 🔴 — Motor Proyección. `internal/capacity/forecaster.go` NO EXISTE.
**M5.3** 🔴 — Motor Políticas. `internal/capacity/policy_engine.go` NO EXISTE.
**M5.4** 🔴 — Motor Acción. `internal/capacity/action_engine.go` NO EXISTE.
**M5.5** 🔴 — bosctl capacity forecast. NO EXISTE.

### FASE 11.B — 18 Estados Ficha Engine

**F11.B.1** 🔴 — Estados base (5): PENDIENTE→LISTA→INSTALADA. State machine code EXISTE (74 refs en state/types.go, ficha/statemachine.go 471 líneas). Pero el átomo V1 dice 🔴 — hay código parcial.
**F11.B.2** 🔴 — Estados instalación (3). CÓDIGO PARCIAL.
**F11.B.3** 🔴 — Estados actualización (4). NO IMPLEMENTADO.
**F11.B.4** 🔴 — Estados error (3). diagnosis.go EXISTE (202 líneas). Parcial.
**F11.B.5** 🔴 — Estados transición (3). rollback.go (144) + cleanup.go (159) EXISTEN. Parcial.

### STUBS en FichaService

**Pause()** — `domain/ficha_service.go:382`. TODO(F11.C.5). Retorna éxito falso.
**Resume()** — `domain/ficha_service.go:395`. TODO(F11.C.5). Retorna éxito falso.
**Diff()** — `domain/ficha_service.go:321`. TODO(F11.D.2). Retorna sin drift.
**Rescan()** — `domain/ficha_service.go:439`. TODO(F11.A.5). Retorna discovered=0.
**ResetState()** — `domain/ficha_service.go:456`. TODO(F11.B). Retorna éxito falso.
**Validate()** — `domain/ficha_service.go:371`. validateManifestStrict placeholder.

---

## ③ BOS Server FICHAS

### FASE 11 — Ficha Engine (átomos con código)

**F11.A.1** ✅ — Auditoría Ficha Engine. `docs/FICHA-ENGINE-GAP.md` EXISTE.
**F11.A.2** 🟡 — Parser manifest.yml estricto. validateManifestStrict() stub. Parcial.
**F11.PROTO** ✅ — ficha.proto con 18 RPCs. `proto/bos/ficha/v1/ficha.proto` EXISTE.
**F11.GRPC** ✅ — Servidor gRPC. `internal/ficha/grpc/server_core.go` EXISTE.
**F11.JSONRPC** ✅ — 8 handlers. `rpc_ficha_f11.go` EXISTE (16 refs).
**F11.A.3** 🟡 — DEPENDENCY_RESOLVER Kahn. `ficha/resolver.go` EXISTE. Falta integración con Plan().
**F11.A.4** ✅ — Executor 5 fases. `ficha/executor.go` EXISTE (42 refs fases/señales).
**F11.A.5** ✅ — Descubrimiento automático. `ficha/discovery.go` EXISTE (331 líneas).
**F11.B.6** ✅ — Estado DEGRADADA. `ficha/lifecycle.go` DegradedHandler EXISTE.
**F11.C.1** 🟡 — bosctl ficha install. CLI funcional. Falta ejecutor 5 fases.
**F11.C.2** 🟡 — bosctl ficha update. domain Update() existe. CLI no implementado.
**F11.C.3** 🟡 — bosctl ficha repair. CLI funcional.
**F11.C.4** 🟡 — bosctl ficha remove. domain Remove() existe. CLI no implementado.
**F11.C.5** ✅ → ⚠️ — **REGISTRO DICE ✅. Pause/Resume son STUBS.** State manager integration pendiente.
**F11.C.6** 🟡 — bosctl ficha scale. Stub.
**F11.D.1** ✅ — Health checker declarativo. `ficha/health.go` EXISTE (34 refs probes).
**F11.D.2** ✅ — Drift detection. `ficha/drift.go` EXISTE (342 líneas).
**F11.D.3** ✅ — Reconciliación automática. `ficha/reconcile.go` EXISTE (12 refs políticas).
**F11.D.4** ✅ — bosctl ficha status. `ficha/status.go` EXISTE.
**F11.E.1** ✅ — Versionado semver. `ficha/version.go` EXISTE.
**F11.E.2** ✅ — Dashboard.json. `ficha/dashboard.go` EXISTE.
**F11.E.3** 🔴 — Capacidades automáticas (SSO, ctx_id, mTLS, métricas, secretos). NO IMPLEMENTADO.
**F11.E.4** 🔴 — NetworkPolicy Calico. NO IMPLEMENTADO.
**F11.F.1** ✅ — bosctl ficha UX 11 subcomandos. `cmd/bosctl/ficha.go` EXISTE.
**F11.F.2** 🟡 — bosctl ficha logs. CLI stub funcional.
**F11.F.3** 🔴 — bosctl ficha describe. NO IMPLEMENTADO.
**F11.F.4** 🔴 — Matriz administración. NO IMPLEMENTADO.
**F11.F.5** 🔴 — Governance Dual-Control. ⛔ GATE. NO IMPLEMENTADO.
**F11.G.1** ✅ — Corrección ficha nginx. manifest.yml+task_catalog.sh+resources EXISTEN.
**F11.G.2** ✅ — Consistencia 18 estados. `ficha/doc.go` actualizado.
**F11.G.3** ✅ — Timeouts por tipo. `ficha/timeouts.go` EXISTE.

### FASE 12 — Capa 3 Datos

**F12.1-F12.3** 🔴→✅ — postgresql, 9 BDs, redis. task_catalog.sh + manifest.yml EXISTEN. CÓDIGO COMPLETO. VPS pendiente.
**F12.4** 🔴 — Ficha vault init+unseal. task_catalog.sh + manifest.yml EXISTEN en servers/S02/vault/.
**F12.5-F12.10** 🔴 — Vault PKI, bkernel_db DDL, WAL, backups, bos.query.system, certificación. NO IMPLEMENTADO.

### FASE 12.B — Bootstrap k3s

**F12.B.1** ✅ — Adaptar redis k3s. task_catalog.sh EXISTE.
**F12.B.2** ✅ — bosctl ficha install redis. VPS verificado.
**F12.B.3** ✅ — Adaptar minio k3s. task_catalog.sh EXISTE.
**F12.B.4** 🔴 — Health check Capa 2. NO IMPLEMENTADO.
**F12.B.5-F12.B.10** ✅ — vault, keycloak, kong k3s adaptados. task_catalog.sh EXISTEN.
**F12.B.11-F12.B.12** ✅ — bootstrap verify 8/8, deploy seed funcional.
**F12.B.13** 🔴 — Documentar regla capas ADR-040. NO IMPLEMENTADO.
**F12.B.14** 🟡 — Instalar kubeadm Calico VPS. CÓDIGO LISTO.
**F12.B.15-F12.B.25** 🔴 — 11 átomos. NO IMPLEMENTADO.

### Fichas NO EXISTENTES

- `servers/S01/postgis/` ❌ — requerido por F12.4 y F24.A.1
- `servers/S-HOST/sbos-biedata/` ❌ — requerido por F14.2
- `servers/S-HOST/sbos-bsearch/` ❌ — requerido por F14.3
- `servers/S-HOST/sbos-bnotify/` ❌ — requerido por F14.4
- `servers/S-HOST/sbos-bhnexus/` ❌ — requerido por F14.5
- `servers/S03/bauth/` ❌ — requerido por F13.4

### FASE 15 — Capa 6 Aplicación (7 átomos 🔴)

**F15.1** 🔴 — Ficha bnotify S06. task_catalog.sh EXISTE en servers/S06/sbos-notifier/. Parcial.
**F15.2-F15.7** 🔴 — Tryton, pos-service, inventario-service, facturacion-service SIAT, DAG, certificación. NO IMPLEMENTADO.

### FASE 16 — VDI Layer

**F16.1** 🔴 — Ficha nextcloud. NO EXISTE en servers/.
**F16.2** 🟡 — Ficha guacamole. EXISTE en `SBOS/servers/S11-vdiserver/guacamole/` (4 archivos). Falta despliegue real.
**F16.3-F16.14** 🔴 — Imagen fedora-logico, ficha fedora-logico, sbos-client, identity WS, session, ciclo, tests, pods, home, ISO, vdi verify, e2e. NINGUNO IMPLEMENTADO. `cmd/sbos-client/` NO EXISTE.

---

## ④ BOS Context Plane

### FASE 5.B-5.H — Context Plane Extendido

**F5.B.1** ✅ — device.register. `rpc_ctx.go` EXISTE.
**F5.B.2** 🔴 — dctx_id heartbeat. NO IMPLEMENTADO.
**F5.B.3** 🔴 — TTL enforcement Kong. NO IMPLEMENTADO.
**F5.B.4** 🔴 — dctx_id→ctx_id promotion. NO IMPLEMENTADO.
**F5.C.1-F5.C.4, F5.C.6** ✅ — promote, get, switch, invalidate, list_by_tenant. CÓDIGO EXISTE.
**F5.C.5** 🔴 — invalidate_all_by_tenant. NO IMPLEMENTADO.
**F5.D.1-F5.D.6** 🔴 — Seguridad ctx_id (UUID, anti-enumeration, bitmask, cross-tenant, sanitización, rate limiting). NO IMPLEMENTADO.
**F5.E.1-F5.E.4** 🔴 — Propagación (Kong, gRPC, WAL, Loki). NO IMPLEMENTADO.
**F5.F.1-F5.F.3** 🔴 — Auditoría (audit_events, métricas Prometheus, retención 7 años). NO IMPLEMENTADO.
**F5.G.1-F5.G.3** 🔴 — Performance SLOs. NO IMPLEMENTADO.
**F5.H.1-F5.H.3** 🔴 — Operación (runbook RB-03, health check C-13, recuperación post-crash). NO IMPLEMENTADO.

### FASE 5.I — bAuth DDL (26 átomos 🔴)

**F5.I.1a-F5.I.12c** 🔴 — 26 átomos. Migración 46 tablas, 57 tablas nuevas, seeds 103 tablas, secciones dominio, templates rol, políticas dominio, configuraciones, domain_classification, bos.GetContext, bAuth integration, auth_flow, zonas, calendario, riesgo sesión CAEP, ZTNA, SoD. NINGUNO IMPLEMENTADO.

### FASE 5.A.5 — OpenTelemetry Baggage

**F5.A.5** 🔴→⚠️ — **REGISTRO DICE ✅. W3C Trace Context EXISTE. OpenTelemetry Baggage NO EXISTE.** Cero referencias en código.

---

## ⑤ BOS Dashboard

### Métodos JSON-RPC Faltantes (15)

**bos.dashboard.metrics** 🔴 — NO EXISTE.
**bos.dashboard.fichas** 🔴 — NO EXISTE.
**bos.dashboard.tenants** 🔴 — NO EXISTE.
**bos.dashboard.health** 🔴 — NO EXISTE.
**bos.dashboard.capacity** 🔴 — NO EXISTE.
**bos.vdi.pool.list** 🔴 — NO EXISTE.
**bos.vdi.pool.scale** 🔴 — NO EXISTE.
**bos.vdi.session.list** 🔴 — NO EXISTE.
**bos.vdi.session.kill** 🔴 — NO EXISTE.
**bos.storage.quota.set** 🔴 — NO EXISTE.
**bos.storage.quota.usage** 🔴 — NO EXISTE.
**bos.device.revoke** 🔴 — NO EXISTE.
**bos.iso.status** 🔴 — NO EXISTE.
**bos.iso.download** 🔴 — NO EXISTE.
**bos.iso.verify** 🔴 — NO EXISTE.

### Calidad y Pruebas

**F8.1** 🔴 — Cobertura ≥70%. NO VERIFICADO.
**F8.3** 🔴 — Test carga k6. NO EXISTE.
**F8.5** 🔴 — Benchmarks. NO EXISTEN.
**BOS-BANCO-PRUEBAS** 🔴 — Documento vivo de pruebas. NO EXISTE.

### Paquetes NO EXISTENTES

1. `internal/eventbus/`
2. `contracts/events/`
3. `internal/capacity/collector.go`
4. `internal/capacity/forecaster.go`
5. `internal/capacity/policy_engine.go`
6. `internal/capacity/action_engine.go`
7. `cmd/sbos-client/`

---

## APÉNDICE — Fases no categorizadas en V2

### FASE 17 — Estándares (17 átomos 🔴)

CIS Kubernetes, CIS Ubuntu, NIST SP 800-190, NIST SSDF, SLSA L2, SBOM, ISO 27001, ISO 25010, OTel Collector, Wazuh, .proto fuente verdad, buf lint, gRPC interceptors, Kyverno, verificación CI, bootstrap verify 14/14, informe final. NINGUNO IMPLEMENTADO.

### FASE 18 — Web Platform (10 átomos 🔴)

Routing table Kong, Domain Resolver, CTX Resolver, cookie __sbos_dctx, Website Engine, ficha website-engine, context.promoted event, flujo e2e, bosctl web domain, certificación. NINGUNO IMPLEMENTADO.

### FASE 19 — bSearch + bCompass (7 átomos 🔴)

Índice GIN PostgreSQL, ficha bsearch, WebSocket :9493, search-as-you-type, bCompass socket, integración LLM, certificación. NINGUNO IMPLEMENTADO.

### FASE 20 — Desacoplamiento (19 átomos 🔴)

contracts/events/, SAGA_SNAPSHOT, Command validation, test DTC-05, verificación DTC-10, persistencia pre-saga, TUI post-instalación, suites DC-01 a DC-10, modo híbrido seed.yml, Gate 2+4 automatizados, dashboard métricas CI, monitor señales, verificaciones DTC-01/02/04/08. NINGUNO IMPLEMENTADO.

---

## ÁTOMOS MARCADOS ✅ QUE SON FALSOS O ENGAÑOSOS

| Átomo | Registro | Realidad |
|-------|----------|----------|
| M2.5 | ✅ TUI recibe eventos WebSocket | 0 referencias a eventos en s05_instalando.go |
| F3.10 | ✅ ≤80 líneas (62L) | 147 líneas |
| F4.5 | ✅ ≤120 líneas (107L) | 131 líneas |
| F5.A.5 | ✅ W3C + OpenTelemetry Baggage | Baggage NO EXISTE |
| F10.B.1 | ✅ ≤15 líneas install.sh | 49 líneas |
| F10.B.5 | ✅ writeTenantConf() | NO EXISTE |
| F11.C.5 | ✅ Pause/Resume | STUBS con TODO — retornan éxito falso |
| F0.5 | ✅ branch-protection.md | NO EXISTE |
| F1.5 | ✅ MUTEX anti-race | sync.Once, sin sync.Mutex |

## ÁTOMOS MARCADOS 🔴 QUE YA ESTÁN IMPLEMENTADOS

| Átomo | Realidad |
|-------|----------|
| F3.C.1 | ws_transport.go + ws_hub.go + ws_types.go EXISTEN |
| F3.C.4 | 65 métodos en rpcRegistry con auth/timeout/batch |
| F6.12 | RPC-CATALOG.md generado 2026-06-29 |
| F8.4 | 29 paquetes sin DATA RACE (verificado hoy) |
| F12.1 | postgresql task_catalog.sh 820 líneas |
| F12.2 | redis task_catalog.sh 584 líneas |
| F12.3 | minio task_catalog.sh 605 líneas |
| F13.1 | keycloak task_catalog.sh + manifest.yml |
| F13.2 | vault task_catalog.sh + manifest.yml |
| F13.3 | kong task_catalog.sh + manifest.yml |
