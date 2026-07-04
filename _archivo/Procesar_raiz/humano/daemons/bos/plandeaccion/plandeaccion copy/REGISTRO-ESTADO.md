# REGISTRO-ESTADO — Plan de Acción BOS-REPAIR
## Estado actual de cada átomo · Actualizar en cada Informe de Cierre

**Última actualización:** Junio 2026
**Estados:** 🔴 NO INICIADA · 🟡 EN PROGRESO · ✅ COMPLETA · ⚠️ BLOQUEADA

---

## FASE 0 — Fundación e Infraestructura

| ID | Átomo | Estado | Commit | Notas |
|---|---|---|---|---|
| F0.0 | Snapshot pre-reparación | ✅ | 3dade7c | tag: pre-repair-2026-06-09 · 79 archivos Go |
| F0.1 | Directorio `_legacy/` y README | ✅ | 39d1f37 | SFP-01 activo |
| F0.2 | `doc.go` × 11 paquetes nuevos | ✅ | 4f95388 | 11 contratos ADR-003 · race P6/P14 documentada |
| F0.3 | `internal/tui/` subpaquetes + POLICY.md | ✅ | 37a1716 | 5 doc.go + POLICY.md — 15 pantallas inventariadas, 7 reglas |
| F0.4 | `internal/paths/paths.go` | ✅ | ea4b625 | 29 constantes + 3 helpers · -race -count=3 PASS |
| F0.5 | Pipeline CI/CD | ✅ | 635a421 | ci.yml 4 jobs · validate.sh fix GOROOT/bin · branch-protection.md · race ✅ |
| F0.6 | Entornos DEV/STAGING/PROD + runner | ✅ | c53f9dc | ENVIRONMENTS.md + staging-runner-setup.sh + deploy-staging job |
| F0.6.S | Usuario bos en staging (deuda seguridad) | 🔴 | — | Antes de datos sensibles |
| F0.7 | Limpieza pre-reparación: archivar residuos a `_legacy/` | ✅ | 64f26f1 | 7 paquetes/archivos archivados — SOLO REFERENCIA DE LÓGICA |

## FASE 1 — Extraer `cmd/bos/main.go`

| ID | Átomo | Estado | Commit | Notas |
|---|---|---|---|---|
| F1.1 | `auditLog()` → `internal/audit/` | ✅ | 78a186c | 4 tests race -count=20 ✅ · 18 llamadas migradas · stub presente |
| F1.2 | `autoBootstrap()` → `internal/bootstrap/` | ✅ | a3cfe9a | setup.go + verify.go + bootstrap_test.go · SRP + testabilidad |
| F1.3 | `verifyCgroupDelegation()` → `internal/cgroup/` | ✅ | de278fb | cgroup.go + cgroup_test.go · isBareMetal + configureSystemdDelegate |
| F1.4 | `ensureBridgeNetwork()` → `internal/network/` | ✅ | 465f574 | network.go + network_test.go · detectNetworkSubnet + nftables + bridge |
| F1.5 | Observer loop → `internal/observer/` + MUTEX | ✅ | 3679b15 | observer.go + startup.go + observer_test.go · race P6/P14 corregida |
| F1.6 | Activar `startWatchdog()` (P12) | ✅ | f1a7aac | stopCh + defer close · 2 tests race ✅ · P12 corregido |
| F1.7 | Extraer helpers OS + adaptador release → `internal/system/` + `internal/release/` | ✅ | 62a524c | ExecAsRoot, SystemctlCmd, SDNotify, StartWatchdog, Adapter — main.go 618L |
| F1.8 | Extraer `runConfigPending()` → `cmd/bos/config_pending.go` | ✅ | 5c1553a | runConfigPending en archivo propio |
| F1.9 | Dividir `runNormal()` + verificación main.go ≤350 líneas | ✅ | 5c1553a | env.go+auto_bootstrap.go+run_normal.go+shutdown.go · 118L final |

## FASE 2 — Unificar WebSocket

| ID | Átomo | Estado | Commit | Notas |
|---|---|---|---|---|
| F2.1 | Extender `internal/wslib/` — agregar `DialUnix` | ✅ | c389262 | DialUnix(path, timeout) — net.DialTimeout + RFC 6455 |
| F2.2 | Migrar `wsRequest()` de bosctl | ✅ | c389262 | gorilla → wslib.DialUnix · imports context/net eliminados |
| F2.3 | Migrar `connectWS/sendWS/awaitWS` | ✅ | c389262 | *wslib.Conn en wsReadyMsg/model/sendWS/RunAutoInstall |
| F2.4 | Eliminar gorilla de go.mod | ✅ | c389262 | go mod tidy — gorilla removido completo |

## FASE 3 — Partir `install_ui.go`

| ID | Átomo | Estado | Commit | Notas |
|---|---|---|---|---|
| F3.1 | `internal/tui/styles/styles.go` | ✅ | 483af30 | 11 colores + 25 estilos + 6 iconos + Badge + RenderMFAToggle |
| F3.2 | `internal/tui/model/types.go` — Screen enum | ✅ | 806a2b5 | Screen(15)+StepStatus(5)+FichaStatus(4)+LogLevel(5) · P11 parcial |
| F3.3 | `internal/tui/model/model.go` — campo único | ✅ | dab18da | Model+Config+SeedData+New()+Init()+SetScreen() · P11 corregido |
| F3.4 | `internal/tui/model/events.go` | ✅ | 8b77fbb | WsReadyMsg+WsErrorMsg+SysInfoMsg+TickMsg+TickCmd() |
| F3.5 | `internal/tui/demo/demo.go` | ✅ | f4dce2e | DemoSubComponents+DemoLogLine+RunDemo; 4898→4710L |
| F3.6 | Corrección TEA — handlers puros | ✅ | 1e10d94 | P3 corregido: ts en awaitWS Cmd, no en Update; startDemoCmd; handleWS usa ev.ts |
| F3.7 | `internal/tui/model/viewport.go` | ✅ | 65beafa | VpDims+VScrollbar+HScrollbar extraídos; install_ui.go usa wrappers 1-línea |
| F3.8 | `internal/tui/screens/` — 15 pantallas | ✅ | e284397 | dispatcher.go + helpers.go + splash/wizard/installing/postinstall/dashboard (15 stubs) |
| F3.9 | `internal/tui/model/keys.go` | ✅ | 79a2602 | ScreenKeyMap+IsNavKey()+KeysFor(s Screen) — 15 casos, help.KeyMap |
| F3.10 | `install_ui.go` ≤80 líneas | ✅ | 6525771 | 62L entry point · impl.go + unattended.go · legacy archivado SFP-01 |

## FASE 4 — Limpiar `cmd/bosctl/` y eliminar RBAC propio

| ID | Átomo | Estado | Commit | Notas |
|---|---|---|---|---|
| F4.1 | Centralizar kubeconfig (P5 ×6) | ✅ | 58d2da6 | ResolveKubeconfig() — 5 tests -race ✅ · 7 inst. → 1 |
| F4.2 | `ensureDaemonRunning()` con rollback (P9) | ✅ | 58d2da6 | rollback de dirs creados · no sobreescribir toml · kill solo "bos" |
| F4.3 | Corregir `bosRBAC` global (P15) | ✅ | 58d2da6 | sync.Once — rbacOnce/rbacInst en rbac.go |
| F4.4 | Eliminar `rbac_provider.go` (ADR-006) | ✅ | 58d2da6 | → interfaces.go · legacy archivado SFP-01 |
| F4.5 | `cmd/bosctl/main.go` ≤120 líneas | ✅ | 58d2da6 | 107L · +5 archivos separados (daemon/os/ws/rbac/usage) |

## FASE 5 — Context Plane (SBOS-049)

| ID | Átomo | Estado | Commit | Notas |
|---|---|---|---|---|
| F5.1 | `internal/context/types.go` | ✅ | ffdaab3 | DeviceContext/SessionContext/ContextState/BitMask — 4 tests race ✅ |
| F5.2 | `internal/context/service.go` | ✅ | f070556 | RegisterDevice/Promote/Switch/Invalidate/List + memStore — 6 tests race ✅ |
| F5.3 | `internal/context/store.go` (PG+Redis) | ✅ | 21f1576 | PGRedisStore cache-first · SQLExecutor+RedisClient interfaces — 3 tests race ✅ |
| F5.4 | 7 métodos JSON-RPC ctx | ✅ | e3951d5 | device.register/promote/switch/invalidate/get/list/tenant.suspend — 3 tests race ✅ |
| F5.5 | `cmd/bosctl/context.go` | ✅ | 80cc1db | bosctl ctx list/get/invalidate/stats · main.go despacho |
| F5.6 | W3C Trace Context propagado | ✅ | c294555 | IsValidTraceparent/NewTraceparent/Extract/Inject — todos los handlers ctx · TestTraceContext race ✅ |

## FASE 6 — JSON-RPC Robusto + Sagas

| ID | Átomo | Estado | Commit | Notas |
|---|---|---|---|---|
| F6.1 | Auth en métodos destructivos | ✅ | 1353aba | auth.go: Basic user:id:token (manual §3) + token compartido /etc/bos/rpc-token + RBAC · sin token → -32600 · 6 tests race |
| F6.2 | Timeout por categoría | ✅ | 9a6a301 | 5s lectura / 30s escritura / 600s sagas · -32006 ErrTimeout · runWithTimeout canal buffer 1 |
| F6.3 | Batch paralelo | ✅ | 44ddd2b | dispatchBatch: goroutine por solicitud, orden preservado, notificaciones omitidas |
| F6.4 | `bos.state.read` sin hashes | ✅ | ee4dfbb | fichaPublica DTO sin Hashes — jq 'has("hashes")' → false |
| F6.5 | Validación TTL ctx_id | ✅ | 66f26b3 | ErrContextExpired = -32001 (ErrFichaNotFound → -32010) · ctx.get/switch rechazan TTL vencido |
| F6.6 | `bos.query.system` | ✅ | b65bfd9 | internal/query/ nuevo: motor paralelo deadline 4s + semáforo + UbuntuSnapshot real + kubectl degrada |
| F6.7 | `bos.query.repair` | ✅ | e60a7e0 | causa_probable de 18 estados ADR-021 + dependientes reales + recomendación |
| F6.8 | `bos.query.vdi` | ✅ | c00ba6d | nextcloud+guacamole+fedora-logico + semaforo_vdi (críticas) |
| F6.9 | `bos.query.tenant` | ✅ | 239d6c7 | identidad+infra+contexto con aislamiento multi-tenant verificado |
| F6.10 | `bos.query.node` | ✅ | 91ef889 | k8s+ubuntu+pods+impacto_si_se_drena (críticas reales, advertencia 1-nodo) |
| F6.11 | `bos.query.context` | ✅ | 1c9cc09 | distribución estados + anomalías + TTLs · ListAllByTenant nuevo en context.Service · tests tiempo endurecidos 4175aff |

## FASE 7 — Documentación (paralela a F5-F10)

| ID | Átomo | Estado | Commit | Notas |
|---|---|---|---|---|
| F7.1 | Godoc `internal/observer/` | ✅ | ec1b447 | Cumplía desde F1.5: P6/P14 + inFlight documentados · go doc 6 func |
| F7.2 | Godoc `internal/context/` | ✅ | ec1b447 | doc.go reescrito — 7 estados con ejemplo c/u, métodos reales F5.4, invariantes BitMask, SBOS-049 |
| F7.3 | Godoc `internal/bootstrap/` | ✅ | ec1b447 | Cumplía desde F1.2: VerifyC01..C08 con criterio BOS-REPAIR-01 §C-0X en cada godoc |
| F7.4 | Godoc `internal/tui/model/` | ✅ | ec1b447 | Sección Política TEA + ref POLICY.md ×4 · notas obsoletas pre-F3.10 eliminadas |
| F7.5 | README `cmd/bos/` | ✅ | ec1b447 | 83 líneas — flags, env vars reales, modos, Interface Dual, señales |
| F7.6 | README `cmd/bosctl/` | ✅ | ec1b447 | 126 líneas — 27 subcomandos reales, auth F6.1, códigos de salida |
| F7.7 | `_legacy/README.md` actualizado | ✅ | 9498e7b | Tabla completa 14/14 archivados (criterio "≥15" era estimación; completitud real) |
| F7.8 | 3 Runbooks operacionales | ✅ | ec1b447 | RB-01/02/03 + INDEX + INCIDENTES-LOG validados contra código — 5 comandos fantasma corregidos (bos.ctx.stats→bos.query.context etc.) |

## FASE 8 — Tests y Cobertura

| ID | Átomo | Estado | Commit | Notas |
|---|---|---|---|---|
| T8.1 | Race condition observer ×100 | ✅ | 3b46861 | Loop real en TempDir (state+loader+orchestrator) · 38→77% · race ×100 verde |
| T8.2 | TEA purity TUI ×50 | ✅ | ae4238b | 10 tests: Init puro P3, SetScreen P11/P10, KeysFor 15 pantallas, VpDims · race ×50 verde |
| T8.3 | Context Plane completo | ✅ | 831aba1 | Switch/ListAllByTenant + PGRedisStore CRUD con stubs · 48.8→69.9% |
| T8.4 | Bootstrap criterios C-01..C-08 | ✅ | — | Ya cumplía (F1.2: verify_test 60.8%) — verificado, sin cambios |
| T8.5 | JSON-RPC timeouts y auth | ✅ | (F6)+208ca36 | auth/timeout/batch de F6 + handlers ficha/saga/health/bootstrap/ctx legacy |
| T8.6 | Cobertura ≥60% | ✅ | 208ca36 | Agregado internal/ 61.0% · domain 66, state 73, system 80, reconcile 78, server 49, installer 39 |
| T8.7 | Chaos mínimo (kill durante saga) | ✅ | 208ca36 | Saga interrumpida → compensación verificada (P6/P12) · kill-9+recovery SagaEngine → F10.17/F10.19 |

## FASE 9 — Operator Soberano

**Entorno real activo:** VPS 13.140.128.230 (Ubuntu 26.04, kubeadm v1.32.13 + Calico) — bos F0–F8 desplegado como bos.service, validado en vivo 2026-06-10.

| ID | Átomo | Estado | Commit | Notas |
|---|---|---|---|---|
| F9.0 | Hotfix: SIGTERM no apaga el cluster | ✅ | 3085e4a | INCIDENTE real ×2: saga drain→kubelet→containerd en cada restart del daemon · shutdown(fullStack bool): señal=daemon_only, WS explícito=full_stack · validado en vivo (restart → nodo Ready) |
| F9.1 | Schema scaling+maintenance+slos + bos.ficha.describe | ✅ | 548e72a | Parser extendido (secciones col-0), políticas nil compatibles · DoD jq .slos |
| F9.2 | internal/k8s extendido (gate) | ✅ | 9da17ba | Cordon/Uncordon/Drain(dryRun)/Evict/Scale/Rollout/Resources/GetNodes · kubectl fake args exactos |
| F9.3 | internal/scaler anti-death-spiral | ✅ | 8e20bf8 | Decisión coordinada, histéresis, context-aware · TestScaleCoordinated_NoDeathSpiral ×50 |
| F9.4 | internal/maintenance saga | ✅ | d162418 | Uncordon SIEMPRE (defer+recover): éxito/drain fail/op fail/PÁNICO/cordon fail · ×10 race |
| F9.5 | bos.k8s.* (10 métodos) | ✅ | bcd18e0 | node/pod/scale/rollout/resources · drain dry-run default · scale valida política · validado real |
| F9.6 | bos.maintenance.* (3 métodos) | ✅ | bcd18e0 | start/status/cancel · saga real en vivo (cordon→drain dry→uncordon en 393ms) |
| F9.7 | internal/metrics Prometheus | ✅ | 73fc08d+ | 18 métricas bos_* en 127.0.0.1:9090 · curl real 18, nodes_ready desde cluster |
| F9.8 | ClusterRole bosagent least-privilege (gate) | ✅ | 4160425 | CIS 4.1.1 · aplicado real · can-i: NO secrets/delete-nodes/clusterroles |
| F9.9 | **Verificación** de criterios VDI (VerifyC09..C14) + bosctl vdi verify | ✅ | 6aefcfe | ⚠️ SOLO LA VERIFICACIÓN: ProbeFn inyectable + VerifyFull 14 criterios. El VDI Layer REAL (fichas nextcloud/guacamole/fedora-logico + ISO Fedora) NO está construido → **FASE 11**. Corrección de reporte 2026-06-11 |
| F9.10 | `cmd/bosctl/infra.go` subcomandos (bosctl node/vdi) | ✅ | c1195be | node list/cordon/uncordon/drain/maintain · validado real (list + maintain saga) |

## FASE 10 — biaos: Agente OS + Gateway IA

**⚠️ VALIDACIÓN EN SERVIDOR REAL PENDIENTE** (2026-06-11): el VPS 13.140.128.230 bloqueó el acceso SSH por las conexiones intensas del ciclo de deploy. El binario desplegado es el de F9 (estable). El deploy F10 + batería completa de validación se hará DE GOLPE en una sola sesión SSH con scripts/DEPLOY-VALIDACION-F10.sh al recuperar acceso.

| ID | Átomo | Estado | Commit | Notas |
|---|---|---|---|---|
| F10.0 | `action_catalog.yml` completo | ✅ | — | Generado — ver informes-cierre/ |

| F10.1 | Gateway LLM singleton | ✅ | f472d28 | sync.Once + circuit breaker (3 fallos→cooldown 60s, reset por éxito) |
| F10.2 | Migrar `internal/ai/` → `internal/biaos/` | ✅ | f472d28 | client/router/context_builder migrados · originales en _legacy (SFP-01) · internal/ai retirado |
| F10.3 | ICAP Engine + embeddings | ✅ | 4625904 | Catálogo 17 acciones (TODOS los metodo_rpc existen en rpcRegistry) · coseno Ollama + fallback términos · TestICAPEngine_NeverGeneratesCommands |
| F10.4 | SagaEngine Go con persistencia | ✅ | 1de7177 | DAG olas paralelas + compensación inversa + persistencia atómica · Recuperar() post-crash · TestSagaEngine_CompensatesOnCrash |
| F10.5 | Agente ReAct en Go puro | ✅ | 3a1dd7b | ICAP→propuesta→RBAC→ejecuta→observa · TIPO A directo, TIPO B detiene |
| F10.6 | HITL confirmación | ✅ | 3a1dd7b | Store map+RWMutex+TTL 5min, un solo uso · TestHITL_ExpiresAfterTimeout |
| F10.7 | Safety guardrails | ✅ | 3a1dd7b | Guardia de dominio + RBAC + audit JSONL ANTES de ejecutar (A.8.15) · TestDomainGuard_RejectsBusinessData |
| F10.8 | JSON-RPC `bos.ai.*` | ✅ | b8f65a7 | ask/run/confirm/catalog + ToolExecutor (herramientas = rpcRegistry) · auth+timeout saga · wired en runNormal |
| F10.9 | Export trayectorias JSONL | ✅ | b8f65a7 | audit/export.go: audit→dataset SFT por intención · bosctl ai export-training |

---

## FASE 11 — VDI Layer: Fedora Soberano (la cúspide del bootstrap)

**Base normativa:** BOS-REPAIR-09 (SBOS-052). El VDI Layer es el último hito:
la instalación no termina con K8s — termina con el escritorio Fedora accesible.
F9.9 entregó la *verificación*; F11 entrega el *layer real*.

| ID | Átomo | Estado | Commit | Notas |
|---|---|---|---|---|
| F11.1 | Ficha `nextcloud` (almacenamiento soberano, AGPL v3) | 🔴 | — | StatefulSet + PVC + OIDC KC + cuotas + ruta Kong (§9 paso 1, §12) |
| F11.2 | Ficha `guacamole` (gateway VDI HTML5, Apache 2.0) | ✅ | 6a2d9fe | 5 archivos completos · guacd+webapp+OIDC+guacamole_db · verificada con plugin.Loader real · fix parser comentarios inline |
| F11.3 | Ficha `fedora-logico` (pod OCI Fedora+GNOME) | 🔴 | — | Imagen OCI + escalado coordinado (min2/max20 concurrent_sessions) + mTLS Vault (§7) |
| F11.4 | `internal/iso/` — generador `sbos-fedora.iso` + firma Ed25519 | 🔴 | — | kickstart + sbos-firstboot (wizard 3 preguntas) + build diferido (§8). Requiere Fedora/lorax → build en servidor |
| F11.5 | JSON-RPC `bos.vdi.*` (pool/session) + `bosctl vdi pool/session` | 🔴 | — | pool list/scale, session list/kill (§9 comandos) |
| F11.6 | JSON-RPC `bos.storage.*` + `bos.device.revoke` + `bosctl storage/device` | 🔴 | — | quota set/usage, revocación de dispositivo (§9, §10) |
| F11.7 | JSON-RPC `bos.iso.*` + `bosctl iso` (status/download/verify) | 🔴 | — | firma Ed25519 verificable (§8 verificación) |
| F11.8 | Checklist de acoplamiento §12 cableado en `bosctl vdi verify --full` | 🔴 | — | C-09..C-14 reales contra el layer instalado |

## Resumen

| Fase | Total átomos | ✅ | 🟡 | 🔴 |
|---|---|---|---|---|
| F0 | 8 | 8 | 0 | 0 |
| F1 | 9 | 9 | 0 | 0 |
| F2 | 4 | 4 | 0 | 0 |
| F3 | 10 | 10 | 0 | 0 |
| F4 | 5 | 5 | 0 | 0 |
| F5 | 6 | 6 | 0 | 0 |
| F6 | 11 | 11 | 0 | 0 |
| F7 | 8 | 8 | 0 | 0 |
| F8 | 7 | 7 | 0 | 0 |
| F9 | 11 | 11 | 0 | 0 |
| F10 | 10 | 10 | 0 | 0 |
| F11 | 8 | 1 | 0 | 7 |
| **Total** | **98** | **91** | **0** | **7** |

---

*REGISTRO-ESTADO.md v1.0 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
*Actualizar la columna Estado + Commit en cada Informe de Cierre*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
