# REGISTRO-ESTADO V2 — Plan de Acción BOS-REPAIR (Continuación)
## Estado actual de cada átomo · Actualizar en cada Informe de Cierre

**Última actualización:** 2026-06-30 · **Versión:** V2 · **Progreso:** 15✅ / 9🟡 / 54🔴
**Estados:** 🔴 NO INICIADA · 🟡 EN PROGRESO · ✅ COMPLETA · ⚠️ BLOQUEADA
**Revisión (columna Rev):** ☐ = pendiente · ☑ = verificado
**Historial completado:** ver `REGISTRO-ESTADO.md` (V1 — 449✅)

**Categorías:** BOS IAM Installer · BOS SO Observable · BOS Server FICHAS · BOS Context Plane · BOS Dashboard
**Orden de ejecución:** primer 🔴 dentro de cada categoría, priorizando IAM Installer → Context Plane → SO Observable → Server FICHAS → Dashboard.

---

## ① BOS IAM Installer
> Responsabilidad: bootstrap del sistema, despliegue del stack de identidad (Keycloak, Vault, Kong, bAuth), ciclo de vida de tenants, sagas de instalación, hardening de red.

| Átomo | Descripción | Estado | Hash | Notas |
|-------|------------|--------|------|-------|
| M2.2 | Stack Alpha en VPS: PG 18.4 + Redis 8.6.2 instalados via Ficha Engine | 🔴 | — | Fichas en servers/S01/postgresql/ y servers/S01/redis/ ya existen. Verificar C-03..C-04 |
| M2.3 | bosctl bootstrap verify: 8 criterios verificables con salida de estado real en VPS | 🟡 | 9e4d017 | Comando funcional. Stack no instalado → 0/8. Pasa a OK cuando PG+Redis+Vault+KC+Kong estén desplegados |
| M2.4 | bosctl deploy: saga 7 pasos. Paso 1-2 OK, paso 3 Redis falla (falta adaptación K8s). Compensación automática funciona | 🟡 | 6923ab7 | 9 BDs creadas · Realm KC · Namespace K8s · Vault paths · Redis DB1 · Bloqueado por M2.2 |
| M6.2 | Tenant deploy menor a 30s P50 · menor a 90s P99 verificado con k6 | 🔴 | — | SLO duro SBOS-PERF-001 |
| M6.4 | FAPI 2.0 test suite contra KC staging (PAR, DPoP, PKCE, algoritmos) | 🔴 | — | SBOS-CERT-001 §3 · staging con dominio público |
| M7.1 | DDL bAuth completa (155 tablas): migrar 46 tablas antiguas + crear 57 nuevas + seeds 103 tablas · 12 dominios D1-D12 | 🔴 | — | DDL en BauthAgent/db/migrations/DDL_skSBOS_db.sql |
| M7.2 | Templates de rol por dominio: 12 tablas idn_role_d* · N roles pre-configurados por dominio · herramienta merge · Tablas T-400 a T-411 | 🔴 | — | — |
| M7.3 | Políticas por dominio: 12 tablas ath_policy_d* · colección de políticas seleccionables · Tablas T-350 a T-361 | 🔴 | — | — |
| M7.4 | Configuraciones por dominio: 12 tablas ath_config_d* · configuraciones por defecto · Tablas T-370 a T-381 | 🔴 | — | — |
| M7.6 | Mover menu_* de bauth a bglobal: T-090, T-091, T-092 · bauth.menu_* → bglobal.menu_* · actualizar FKs y seeds | 🔴 | — | — |
| M7.7 | ath_method con domain_classification: columna JSONB para clasificar método por dominios aplicables · T-065 | 🔴 | — | — |
| F13.1 | Ficha keycloak: KC 26.6.2 · realm sbos · cliente bos · SPIs bAuth cargados · C-05 verificado | 🔴 | — | servers/S03/keycloak/ |
| F13.2 | Ficha vault: Vault 2.0.1 · auto-unseal · PKI root CA + intermediate · Ed25519 key · C-06 verificado | 🔴 | — | servers/S03/vault/ |
| F13.3 | Ficha kong: Kong 3.9.x LTS · plugins OIDC + rate-limit + ctx-inject · rutas base · C-07 verificado | 🔴 | — | servers/S03/kong/ |
| F13.4 | Ficha bauth: daemon bAuth MUSL · /run/bos/bauth.sock · integrado KC + Vault · C-08 verificado | 🔴 | — | servers/S03/bauth/ |
| F21.1 | NetworkPolicy Calico: deny-all ingress por defecto · solo puertos declarados abiertos (NRS-01 Zero Trust) | 🔴 | — | — |
| F21.2 | TLS 1.3 obligatorio en todos los endpoints externos 0.0.0.0:9443 (NRS-05) | 🔴 | — | — |
| F21.3 | mTLS entre daemons via Linkerd o certs Vault (NRS-07) | 🔴 | — | — |
| F21.4 | Wazuh agente instalado + reglas SBOS: alertas en acceso no autorizado a sockets (ISO 27001 A.8.16) | 🔴 | — | — |
| F22.1 | bosctl setup instala TODO desde cero sin intervención manual (R1-R4 del ADR-022 verificados e2e) | 🔴 | — | — |
| F22.4 | bosctl deploy --seed ./seed.yml completa las 7 fases sin error en VPS limpio (golden path e2e) | 🔴 | — | — |

---

## ② BOS SO Observable
> Responsabilidad: observar el estado de Ubuntu, Kubernetes y el propio BOS en tiempo real. Detectar drift de configuración, errores físicos y lógicos. Medir y proyectar capacidad. Reparar automáticamente. Auditar seguridad.

| Átomo | Descripción | Estado | Hash | Notas |
|-------|------------|--------|------|-------|
| M1.CAP | Modelo de capacidad dinámico: wizard P3B + bos-preflight real + observer + admisión JSON-RPC | 🟡 | 2dca9e6 | Código listo + build OK — pendiente prueba en vivo por operador (pantalla P3B, capacity.yaml, bos.capacity.check) |
| M4.2 | bos.query.system funcional con K8s real + Ubuntu real (kubectl sin stub): pods, nodos, estado de fichas reales | 🔴 | — | — |
| M5.1 | Motor Observación: recolección cada 60s de 30+ métricas (Redis, PG, bKernel, Kong, bAuth, K8s) · internal/capacity/collector.go | 🔴 | — | SBOS-BOS-CAP-001 §3 |
| M5.2 | Motor Proyección: regresión lineal + horizonte 7/30/90 días + intervalo de confianza · internal/capacity/forecaster.go | 🔴 | — | SBOS-BOS-CAP-001 §4 |
| M5.3 | Motor Políticas: evaluación declarativa YAML cada 60s (autonomous / recommend / block_and_alert) · internal/capacity/policy_engine.go | 🔴 | — | SBOS-BOS-CAP-001 §5 |
| M5.4 | Motor Acción: scaling HPA + alertas graduadas + control de admisión · internal/capacity/action_engine.go | 🔴 | — | — |
| M5.5 | bosctl capacity forecast: proyección 7/30/90 días con confianza · salida: componente · valor · tendencia/h · tiempo a WARNING · tiempo a CRITICAL | 🔴 | — | — |
| M6.1 | k6 Escenario 2 Beta (50 tenants, 5K RPS): todos los SLOs de SBOS-PERF-001 verificados · JSON-RPC P99 menor a 150ms · ctx_id P99 menor a 5ms | 🔴 | — | — |
| M6.5 | Evidencia técnica ISO 27001: audit_events, ctx_id en logs, Vault secretos, Wazuh alertas · 15 controles con artefacto | 🔴 | — | SBOS-CERT-001 §2.2 |
| F8.4 | go test -race -count=10 ./... sin DATA RACE en observer, reconciler, watchdog | 🔴 | — | — |
| F21.5 | bosctl security scan + bosctl security audit funcionales contra daemon real · salida estructurada verificable | 🔴 | — | — |

---

## ③ BOS Server FICHAS
> Responsabilidad: motor administrador de fichas (aplicaciones/servicios). Instala, actualiza, repara y remueve fichas en el cluster K8s con sagas compensadas. Gestiona el ciclo de vida de cada aplicación del ecosistema.

### Motor de Fichas — Implementación Core

| Átomo | Descripción | Estado | Hash | Notas |
|-------|------------|--------|------|-------|
| ENG-1 | Máquina 18 estados (ADR-021): statemachine.go · todos los estados/transiciones · CanInstall/CanRepair/CanUpdate/CanRemove · tests 392 líneas | ✅ | — | internal/ficha/statemachine.go 471 lns |
| ENG-2 | Ciclo de vida fichas (lifecycle.go): BeginInstall/Update/Repair/Remove · timeouts install(30m)/update(15m)/repair(10m) · compensación automática LISTA→FALLA→LIMPIEZA/ROLLBACK | ✅ | — | lifecycle.go 420 · lifecycle_test.go 842 lns |
| ENG-3 | Executor task_catalog.sh: executor.go · ejecución por fases · parseo señales SBOS (__SBOS__STEP_START__ etc.) · timeouts por fase · observer de progreso | ✅ | — | internal/ficha/executor.go 480 lns |
| ENG-4 | Parser manifest.yml estricto: allowlist SAN-10 por sección · semver validation · licencia OSI · dashboard.json requerido | ✅ | — | internal/ficha/parser.go 442 · parser_test.go 400 lns |
| ENG-5 | Discovery + Drift detection: discovery.go escanea servers/ · drift.go SHA-256 por archivo · DetectAll multi-ficha · DriftReport changed/added/removed | ✅ | — | discovery.go 331 · drift.go 342 lns |
| ENG-6 | Health Checker: health.go · probes command/HTTP/TCP · HealthTracker consecutive failures · CheckAll multi-ficha · escalación HITL tras 3 fallos | ✅ | — | internal/ficha/health.go 378 lns |
| ENG-7 | Repair/Rollback/Cleanup: repair.go 3 reintentos · rollback.go restaura N-1 · cleanup.go verifyNoResidue · diagnosis.go clasifica ERROR_FISICO/LOGICO | ✅ | — | repair.go + rollback.go + cleanup.go + diagnosis.go |
| ENG-8 | FichaService domain: domain/ficha_service.go · Install/Update/Repair/Remove/Probe/Status/List · puertos InstallerPort/StatePort/CatalogPort | ✅ | — | ficha_service.go 485 · test 446 lns |
| ENG-9 | JSON-RPC bos.ficha.* 16 métodos: install/update/repair/remove/status/probe/list/describe/plan/diff/validate/scale/pause/resume/rescan/logs | ✅ | — | rpc_ficha.go 269 + rpc_ficha_f11.go 198 lns |
| ENG-10 | CLI bosctl ficha (638 líneas): subcomandos install/update/repair/remove/status/list/describe/probe/logs · buildFichaSvc() local | ✅ | — | cmd/bosctl/ficha.go |
| ENG-11 | Plugin loader SHA-256 integrity: plugin/loader.go · Scan(servers/) · FichaManifest con Scaling/SLO policies · thread-safe RWMutex | ✅ | — | internal/plugin/loader.go 467 lns |
| ENG-12 | Observer DAG + Reconcile scheduler wired: observer.InitializeFichaStates() + New() + reconcile.NewScheduler().WithK8sDiscovery() — conectados en run_normal.go | ✅ | — | internal/observer/ + internal/reconcile/ |
| ENG-13 | Log reader de fichas: ficha/logs.go · ReadTail(fichaID, n) · FollowLog streaming canal · JSON Lines · /var/log/bos/fichas/<name>.log | ✅ | — | internal/ficha/logs.go |
| ENG-14 | Tests motor de fichas: 7 paquetes OK — ficha(1.4s) · installer · plugin · state · domain · observer · reconcile · go build ./... verde | ✅ | — | go test ./internal/ficha/... etc. |

### Fichas Declarativas

| Átomo | Descripción | Estado | Hash | Notas |
|-------|------------|--------|------|-------|
| F12.1 | Ficha postgresql: task_catalog.sh 820 lns ✅ · PG 18.4 · 10 BDs · WAL logical · PVC Retain · pendiente C-03 verificado en VPS (depende M2.2) | 🟡 | — | servers/S01/postgresql/ · C-03 requiere VPS activo |
| F12.2 | Ficha redis: task_catalog.sh 584 lns ✅ · Redis 8.6.2 · 3 DBs (cache/ctx_id/streams) · Streams en DB2 · pendiente C-04 verificado en VPS | 🟡 | — | servers/S01/redis/ · C-04 requiere VPS activo |
| F12.3 | Ficha minio: task_catalog.sh 605 lns ✅ · 3 buckets (sbos-backups con versioning + sbos-assets + sbos-documents) · pendiente ejecución en VPS | 🟡 | — | servers/S01/minio/ · bucket naming: sbos-* (no bos-*) |
| F12.4 | Ficha postgis: extension PostGIS para tablas D6 geoespaciales · servers/S01/postgis/ a crear desde cero (manifest.yml + task_catalog.sh) | 🔴 | — | CREATE EXTENSION postgis; SELECT PostGIS_Version() · depende postgresql ✅ |
| F12.5 | Ficha tryton: task_catalog.sh 164 lns ✅ básico (BD + StatefulSet + repair/test) · falta: inicialización datos ERP y configuración admin tryton | 🟡 | — | servers/S01/tryton/ · pendiente: tryton-admin --config=... init |
| F14.1 | Ficha sbos-bkernel: manifest.yml + task_catalog.sh 259 lns · systemd daemon Rust MUSL · health via systemctl is-active bkernel | ✅ | — | servers/S-HOST/sbos-bkernel/ completo |
| F14.2 | Ficha sbos-biedata: manifest.yml + task_catalog.sh · instala biedata daemon systemd · /run/bos/biedata.sock · health: biedata.health.check | 🔴 | — | servers/S-HOST/sbos-biedata/ a crear |
| F14.3 | Ficha sbos-bsearch: manifest.yml + task_catalog.sh · instala bsearch daemon systemd · /run/bos/bsearch.sock · health: bsearch.health.check | 🔴 | — | servers/S-HOST/sbos-bsearch/ a crear |
| F14.4 | Ficha sbos-bnotify: manifest.yml + task_catalog.sh · instala bnotify daemon systemd · /run/bos/bnotify.sock · health: bnotify.health.check | 🔴 | — | servers/S-HOST/sbos-bnotify/ a crear |
| F14.5 | Ficha sbos-bhnexus: manifest.yml + task_catalog.sh · instala bhnexus daemon systemd · Unix socket + TCP :9444 · health: bhnexus.health.check | 🔴 | — | servers/S-HOST/sbos-bhnexus/ a crear |
| F22.2 | bos-preflight: 10 system_packages BOS ✅ · verificación RAM/CPU/Disk/Ports · dirs /etc/bos /run/bos · permisos bosagent · pendiente: agregar containerd y cri-tools | 🟡 | — | manifest.yml + task_catalog.sh ✅ · rev: ¿containerd en packages? |
| F22.3 | Auto-repair: bosctl ficha repair <nombre> · repair_manager.go wired en run_normal.go · rpcFichaRepair handler · ADR-021 estados 8-11 · pendiente prueba en VPS | 🟡 | — | repair_manager.go + run_normal.go:201 ✅ · pendiente: VPS con ficha degradada |

### Infraestructura de Eventos y Logs

| Átomo | Descripción | Estado | Hash | Notas |
|-------|------------|--------|------|-------|
| F3.C.2 | Redis Streams event bus: internal/eventbus/redis_streams.go · stream bos:saga:{tenant_id} · max len 10K · consumer group por tipo de consumidor · eventos persistentes | 🔴 | — | internal/eventbus/ no existe · requiere Redis activo (M2.2) |
| F3.C.3 | Log rotation infrastructure: /etc/logrotate.d/bos-fichas (10MB × 5 archivos) en bos-preflight task_catalog.sh · writer JSON Lines ya presente en executor.go | 🔴 | — | Reader ✅ (ficha/logs.go) · Falta: logrotate.d config en bos-preflight |

### Verificación y SLOs

| Átomo | Descripción | Estado | Hash | Notas |
|-------|------------|--------|------|-------|
| M6.3 | Ficha install menor a 60s P50 · menor a 180s P99 verificado en VPS (SLO duro SBOS-PERF-001) | 🔴 | — | Depende M2.2 — postgresql en VPS real con K8s activo |
| F8.2 | Test integración: daemon bos real + bosctl client + ciclo completo install/verify/remove de ficha postgresql en VPS | 🔴 | — | Requiere VPS con daemon bos corriendo + K8s operativo |


---

## ④ BOS Context Plane
> Responsabilidad: administrar, observar, proveer y validar el ctx_id. Registrar dispositivos, promover contextos de dispositivo a sesión autenticada, cachear en Redis, integrar con bAuth para evaluación de 12 dominios.

| Átomo | Descripción | Estado | Hash | Notas |
|-------|------------|--------|------|-------|
| M3.1 | bos.ctx.device.register menor a 2s con PG+Redis reales · dctx_id registrado en Redis DB1 | 🔴 | — | Depende M2.2 |
| M3.2 | ctx_id lookup en Redis menor a 1ms P50 · menor a 5ms P99 (SLO SBOS-PERF-001) | 🔴 | — | k6: 50 dispositivos · 10 promovidos |
| M3.3 | context.promoted end-to-end menor a 15ms P50 · menor a 40ms P99 · dctx → ctx_id vía bAuth (/run/bos/bauth.sock) → bos.ctx.promote | 🔴 | — | — |
| M3.4 | bosctl ctx list muestra ctx_id y dctx_id reales del tenant skull (validación CLI completa) | 🔴 | — | — |
| M7.5 | Context API :9443 — bos.GetContext(): GET /api/v1/context/{ctx_id} → JSON unificado (identidad + dispositivo + ubicación + permisos) · P99 menor a 5ms con Redis cache | 🔴 | — | — |
| M7.8 | Context Plane → bAuth integration: bos.ctx.resolve → /run/bos/bauth.sock → bAuth evalúa 12 dominios → BOS cachea resultado en Redis DB1 (TTL 30s) | 🔴 | — | — |

---

## ⑤ BOS Dashboard
> Responsabilidad: dotar al dashboard GUI (Flutter) de toda la información del BOS para control y monitoreo. Exponer métodos JSON-RPC especializados para el dashboard. Proveer la infraestructura de comunicación (WebSocket, Interface Dual, contratos de eventos).

| Átomo | Descripción | Estado | Hash | Notas |
|-------|------------|--------|------|-------|
| M4.1 | Todos los métodos JSON-RPC probados contra daemon real → RPC-CATALOG.md · 50+ métodos · auth, timeouts, batch verificados | 🔴 | — | — |
| M4.3 | Implementar métodos bos.dashboard.*: bos.dashboard.metrics · bos.dashboard.fichas · bos.dashboard.tenants · bos.dashboard.health · bos.dashboard.capacity · consumidos por GUI via /run/bos/bos.sock | 🔴 | — | No es TUI — es API para Flutter |
| M4.4 | JSON-RPC P99 menor a 150ms bajo carga Alpha (5 tenants, 500 RPS) · k6 Escenario 1 SBOS-PERF-001 | 🔴 | — | — |
| F3.C.1 | WebSocket sobre Unix socket: internal/server/ws.go · upgrade HTTP→WS en /run/bos/bos.sock · frame max 64KB · CheckOrigin solo localhost · max 50 conexiones · idle timeout 60s | 🔴 | — | ADR-020 mismo socket que JSON-RPC |
| F3.C.4 | Interface Dual: registro central internal/server/rpc_registry.go · auth por método · timeout por categoría · batch paralelo · errores estándar JSON-RPC 2.0 | 🔴 | — | — |
| F3.C.5 | Paquete contracts/events/: tipos puros compartidos entre daemon y clientes · seed_params.go + saga_event.go + command.go + snapshot.go · sin imports externos | 🔴 | — | go list -deps verifica que contracts/ no importa nada de bos/ |
| F8.1 | Cobertura mínima 70% en internal/ · go test -race -coverprofile=coverage.out ./internal/... | 🔴 | — | — |
| F8.3 | Test de carga: k6 contra JSON-RPC · 100 usuarios concurrentes · 5 min · P99 menor a 150ms | 🔴 | — | — |
| F8.5 | Benchmarks: BenchmarkCtxCreate + BenchmarkFichaInstall + BenchmarkJSONRPC · go test -bench=. -benchmem | 🔴 | — | — |

---

## Banco de Pruebas BOS (documento vivo — nunca se cierra)

| Átomo | Descripción | Estado | Hash | Rev |
|-------|------------|--------|------|-----|
| BOS-BANCO-PRUEBAS | **Crear y mantener `BOS-BANCO-PRUEBAS.md`** — Documento vivo que centraliza todas las pruebas verificables del daemon BOS. Cubre comandos bosctl, métodos JSON-RPC, fichas, sagas, bootstrap, contexto, seguridad y observabilidad. **Regla obligatoria: cada prueba DEBE tener exactamente dos formas de ejecución — Vía 1 (bosctl CLI sobre WebSocket) y Vía 2 (JSON-RPC 2.0 directo sobre Unix socket). Ambas son obligatorias.** Permite medir la completitud del BOS y ser ejecutado por cualquier persona. **Regla de actualización:** cada átomo completado que afecte un comando o comportamiento del BOS actualiza este documento en el mismo commit. Este átomo nunca pasa a ✅ — es permanentemente 🟡 mientras el BOS evolucione. | 🔴 | — | ☐ |

> **Ruta:** `context/sbos/Procesar/humano/daemons/bos/plandeaccion/plandeaccion/BOS-BANCO-PRUEBAS.md`
>
> **Estructura de cada prueba:**
> ```
> ## BP-NNN — Nombre de la prueba
> **Categoría:** IAM Installer | SO Observable | Server FICHAS | Context Plane | Dashboard
> **Persigue:** qué funcionalidad o comportamiento verifica
> **Prerequisito:** estado del sistema necesario
> **Datos de entrada:** parámetros, seed, tenant, IDs, etc.
>
> ### Vía 1 — bosctl CLI (WebSocket RPC)
> bosctl <comando> <args>
>
> ### Vía 2 — JSON-RPC 2.0 directo (Unix socket)
> echo '{"jsonrpc":"2.0","method":"bos.<modulo>.<op>","params":{...},"id":1}' | socat - UNIX-CONNECT:/run/bos/bos.sock
>
> **Resultado esperado:** (igual para ambas vías)
> **Resultado obtenido Vía 1:** (rellenar al ejecutar)
> **Resultado obtenido Vía 2:** (rellenar al ejecutar)
> **Estado Vía 1:** PASA / FALLA / NO EJECUTADA
> **Estado Vía 2:** PASA / FALLA / NO EJECUTADA
> ```
