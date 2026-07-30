# REGISTRO-ESTADO — Plan de Acción BOS-REPAIR
## Estado actual de cada átomo · Actualizar en cada Informe de Cierre

**Última actualización:** 2026-06-22 · **Progreso:** 184✅ / 0🟡 / 265🔴 · FASE 23 (S12) + B35-B42 bAuth
**Estados:** 🔴 NO INICIADA · 🟡 EN PROGRESO · ✅ COMPLETA · ⚠️ BLOQUEADA
**Revisión (columna Rev):** ☐ = pendiente · ☑ = verificado contra Master v2.1 + DTC + Gates
**Gate (columna G):** 0=build · 1=tests · 2=diseño(Beck+SOLID) · 3=docs · 4=ADR
**DTC (columna D):** reglas SBOS-053 aplicables (DTC-01 a DTC-13) — ver §6 del spec

**Documentos normativos activos (brújula del proyecto):**
- `bos-repair/SBOS_Proyecto_Master.md` v2.1 — arquitectura completa del SBOS
- `bos-repair/BOS-CONTRATOS-SBOS.md` v1.0 — 7 contratos que el BOS debe cumplir
  - C-1 Context Plane · C-2 Ciclo Tenants · C-3 Fichas DAG · C-4 Interface Dual
  - C-5 Context API :9443 · C-6 bosctl CLI · C-7 Reconciliación
- `bos-repair/BOS_V8_SBOS-051-TENANT-SPEC.md` v2.0 — Modelo A/B de Tenant
- `CONCEPCION-BOS-Y-FASES-M.md` v1.0 — qué es el BOS, rol de la TUI, escalera M
- `bos-repair/DATOS-TUI-INSTALACION.md` v1.0 — 📘 DOCUMENTO VIVO de instalación
- **`SBOS-053-DAEMON-TUI-DECOUPLING.md` v1.2** — 13 reglas DTC + 10 casos DC + headless-first
- **`SBOS-054-NETWORK-SECURITY.md` v1.2** — 🔒 10 NRS + 12 SAN + ctx_id token security + STRIDE + Zero Trust + defensa en profundidad
- **`SBOS-055-FICHA-SOVEREIGNTY.md`** v1.0 — 🏛️ 8 reglas SOV + soberanía de fichas + cero intervención manual
- **`Dev_Control_Certification_Method.md` v1.0** — 4 reglas Beck + SOLID + 5 Gates de certificación

**Sistema dual de tracking (Opción C — 2026-06-17):**
- **FASE M (M1–M6)** = orden de ejecución. 24 hitos agrupados. Qué hacer AHORA.
- **FASE 0–19** = granularidad de implementación. 232 átomos. Dónde vive el código.
- **Regla:** un M completado → todos sus átomos F referenciados obtienen Rev ☑
- **Progress** se mide en átomos F (los M son hitos, no átomos)
- **Rev ☑** = verificado contra SBOS_Proyecto_Master.md v2.1 y normas activas
- **Gate** = punto de control Dev_Control_Certification_Method: 0=build, 1=tests, 2=diseño, 3=docs, 4=ADR
- **DTC** = regla SBOS-053 verificable (DTC-01 a DTC-13)

**Orden de ejecución:** el siguiente átomo es siempre el primer 🔴 de FASE M (leyendo
de arriba hacia abajo). Cada átomo M implementa código **y simultáneamente** hace Rev ☑
de los átomos históricos relacionados — dos avances en un solo paso.
Ver FASE M al final de este documento para el plan coordinado.

---

## FASE M — BOS Vivo y Certificado (Estrategia 2026-06-13)

**Concepto real del BOS** (documentos SBOS-PERF-001, SBOS-BOS-CAP-001, SBOS-PERF-002,
SBOS-CERT-001 como brújula normativa):

El BOS es un **Autómata de Capacidad Soberana** — no solo un instalador con TUI.
Sus responsabilidades reales son:
- **Day 0:** Bootstrap de Ubuntu virgen → stack completo K8s en ~48 min
- **Day 1:** Instalar tenants en < 30s. Instalar fichas en < 60s. Manejar GA v1:
  500 tenants · 2.6M ctx_id concurrentes · 26.4M RPS · 440K WAL eventos/s
- **Day 2:** 4 motores corriendo cada 60s (Observación → Proyección → Políticas → Acción).
  Proyección dinámica a 7/30/90 días. Bloqueo de admisión antes de degradar.
  Control autónomo de capacidad con intervalo de confianza.
- **Certificación:** FAPI 2.0 (KC 26.x). ISO 27001:2022 (20 controles).

Cada fase M implementa código Y simultáneamente hace Rev ☑ de los átomos históricos
relacionados. La TUI es OBSERVADOR (SBOS-053 §2: headless-first, UI-as-observer), no
el motor. El BOS funciona sin TUI vía `bosctl deploy seed.yml` (DTC-01, DTC-09).
El sustrato es el autómata multitenante — la TUI solo lo representa (DTC-03, DTC-13).

---

### M1 — BOS Daemon Vivo: cimiento mínimo funcional

| ID | Átomo | Estado | Commit | Notas | Rev activa |
|---|---|---|---|---|---|
| M1.1 | Observer host: CPU/RAM/Disco/Red desde `/proc` → panel recursos del host (secundario) | ✅ | b135af4 | `internal/tui/observer/reader.go` + `ctrl/dash/tick.go` · race×3 ✅ · Nota: /proc = métricas secundarias. Métricas primarias (ctx_id, Redis%, WAL lag, Kong RPS) → M4.3 | F3.16, F3.18 |
| M1.2 | Fix `writeDefaultService()`: `User=root` en lugar de `bosagent` (ADR-001) | ✅ | d741716 | Código confirmado + prueba en vivo VPS: `bos.service` usa `User=bosagent`, daemon corriendo con socket /run/bos/bos.sock | F10.B.0, F10.B.1, F10.B.2, F10.B.8 | G0-1 | DTC-01 |
| M1.3 | `bos.service` arranca sin errores + socket `/run/bos/bos.sock` creado en VPS | ✅ | d741716 | systemd enabled + active (running). Socket root:bosagent 0660. JSON-RPC responde. User=root + BOS_DEV_SKIP_ROOT=1 (staging). restart=always | F10.B.3..B.7 | G0-1 | DTC-01, DTC-13 |
| M1.4 | Context API `:9443`: 1 endpoint GET + TLS 1.3 + UUID validation + anti-enumeration | ✅ | — | Verificado en VPS: TLS 1.3, 403 sin header, 400 UUID inválido, 404 anti-enumeration. Log: "ws https server listening (TLS 1.3)". C-5 ✅ | F5.1..F5.4, F5.6, F10.B.11 | G0-2 | NRS-01,NRS-05,NRS-07,SAN-09,SAN-12 |
| M1.5 | DDL context_sessions + device_contexts auto-apply al arrancar | ✅ | — | AutoMigrate integrado en runNormal. Verificado en VPS: "Context Plane DDL verificado (AutoMigrate OK)". memStore=no-op, PGRedisStore=CREATE TABLE IF NOT EXISTS (M2.2) | F5.5, F10.B.12 | G0-1 | DTC-03 |
| M1.CAP | Modelo capacidad dinámico: wizard P3B + bos-preflight real + observer + admisión JSON-RPC | 🟡 | 2dca9e6 | Código listo + build + race×3 ✅ — **pendiente prueba en vivo por operador** (pantalla P3B, capacity.yaml, bos.capacity.check) | — |

**DoD M1:** `systemctl status bos` → active · `curl -k https://localhost:9443/api/v1/context/{ctx_id}` → 200
· `bos.ctx.device.register` retorna `dctx_id` · socket presente.
· **Nota M1.4 (SBOS-054):** 1 solo endpoint, no 6. Health check = TCP connect a :9443, sin HTTP.

---

### M2 — Primer Tenant Real: `bosctl deploy` < 30s

| ID | Átomo | Estado | Commit | Notas | Rev activa |
|---|---|---|---|---|---|
| M2.1 | Ficha Engine: DEPENDENCY_RESOLVER (Kahn) + bosctl ficha plan/list. 24 fichas en orden topológico sin ciclos | ✅ | b9029c5 | internal/ficha/resolver.go (grafo+Kahn+oleadas). postgresql manifest: deps vs runtime_deps. VPS verificado. Parser inDeps fix | F11.A.2, F11.A.3, F11.A.5 | G0-2 | DTC-09 |
| M2.2 | Stack Alpha en VPS: PG 18.4 + Redis 8.6.2 instalados via Ficha Engine | 🔴 | — | fichas postgresql + redis · C-03..C-04 verificados | F9.4, F9.5, F11.4, F11.6 |
| M2.3 | bosctl bootstrap verify funcional: 8 criterios verificables, salida estado real VPS (0/8) | 🟡 | 9e4d017 | Comando funcional con runLocalVerify (sin daemon). C-01..C-08 muestran estado real. Stack no instalado → 0/8. Pasarán a ✓ cuando PG+Redis+Vault+KC+Kong estén desplegados (M2.4) | F9.1..F9.10, F1.2, F1.3 | G0-1 | — |
| M2.4 | bosctl deploy: saga 7 pasos ejecuta. Paso 1-2 OK, paso 3 Redis falla (falta adaptación k3s). Compensación automática funciona | 🟡 | 6923ab7 | 9 BDs creadas · Realm KC · Namespace K8s · Vault paths · Redis DB1 · C-2 ✓ | F10.C.1..F10.C.10 |
| M2.5 | TUI ScreenInstalling recibe eventos reales WebSocket (step_start/ok/fail) durante deploy | ✅ | 247fca9 | 3 columnas con eventos reales (no mock) · Implementa F10.B.9 | F3.14, F3.15, F10.B.9, F10.B.10 |

**DoD M2:** ✅ 8/8 APROBADA — `bosctl bootstrap verify`: C-01..C-08 todos ✅. Stack mínimo completo. · 9 BDs presentes en PG · Realm skull en KC
· `bosctl tenant list` muestra skull · C-01..C-08 green.

---

### M3 — Context Plane Real: ctx_id < 5ms P99

| ID | Átomo | Estado | Commit | Notas | Rev activa |
|---|---|---|---|---|---|
| M3.1 | `bos.ctx.device.register` < 2s con PG+Redis reales · dctx_id en Redis DB1 | 🔴 | — | Implementa F5.7 · Depende M2.2 | F5.1..F5.4, F5.7 |
| M3.2 | ctx_id lookup Redis < 1ms P50 · < 5ms P99 (SLO SBOS-PERF-001) | 🔴 | — | k6 escenario ligero: 50 disp · 10 prom · medir P50/P99 | F5.6, F5.8, F6.5 |
| M3.3 | context.promoted end-to-end < 15ms P50 · < 40ms P99 | 🔴 | — | dctx → ctx_id vía login KC → bos.ctx.promote | F6.11, F6.9 |
| M3.4 | `bosctl ctx list` muestra ctx_id y dctx_id reales del tenant skull | 🔴 | — | Validación CLI completa | F5.5, F6.9 |

**DoD M3:** k6 smoke contra VPS real · P99 ctx_id lookup < 5ms confirmado · audit_events en bkernel_db ✓

---

### M4 — JSON-RPC Certificado y Dashboard Soberano

| ID | Átomo | Estado | Commit | Notas | Rev activa |
|---|---|---|---|---|---|
| M4.1 | Todos los métodos JSON-RPC probados contra daemon real → `RPC-CATALOG.md` | 🔴 | — | Implementa F6.12 · 50+ métodos verificados · auth, timeouts, batch | F6.1..F6.7, F6.12 |
| M4.2 | `bos.query.system` con K8s real + Ubuntu real (kubectl no-stub) | 🔴 | — | Escenario real: pods, nodos, estado de fichas reales | F6.6, F6.8, F6.10 |
| M4.3 | Dashboard TUI muestra métricas reales del ecosistema: ctx_id activos · RPS · WAL lag · Redis % · bAuth cache miss | 🔴 | — | NO solo /proc — métricas del autómata: Prometheus scrape + bos.query.system | F3.16, F3.18, T8.1, T8.2 |
| M4.4 | JSON-RPC P99 < 150ms bajo carga Alpha (5 tenants, 500 RPS) | 🔴 | — | k6 Escenario 1 de SBOS-PERF-001 · SLO verificado | F6.2, F6.3 |

**DoD M4:** RPC-CATALOG.md generado · P99 JSON-RPC < 150ms en k6 Escenario 1 · Dashboard muestra métricas ecosistema (no solo CPU host).

---

### M5 — Autómata de Capacidad: 4 Motores Operativos

| ID | Átomo | Estado | Commit | Notas | Rev activa |
|---|---|---|---|---|---|
| M5.1 | Motor Observación: recolección 60s de 30+ métricas (Redis, PG, bKernel, Kong, bAuth, K8s) | 🔴 | — | `internal/capacity/collector.go` · escribe en cap_db · SBOS-BOS-CAP-001 §3 | F3.18, F7.2 |
| M5.2 | Motor Proyección: regresión lineal + horizonte 7/30/90 días + intervalo confianza | 🔴 | — | `internal/capacity/forecaster.go` · SBOS-BOS-CAP-001 §4 | — |
| M5.3 | Motor Políticas: evaluación declarativa YAML cada 60s (autonomous/recommend/block_and_alert) | 🔴 | — | `internal/capacity/policy_engine.go` · SBOS-BOS-CAP-001 §5 | — |
| M5.4 | Motor Acción: scaling HPA + alertas graduadas + control admisión | 🔴 | — | `internal/capacity/action_engine.go` · `bosctl capacity status` | F6.6 |
| M5.5 | `bosctl capacity forecast` muestra proyección 7/30/90 días con confianza | 🔴 | — | Salida: componente · valor actual · tendencia/h · tiempo a WARNING · tiempo a CRITICAL | — |

**DoD M5:** ciclo 60s corriendo · `bosctl capacity status` muestra estado de cada componente · forecast genera proyección real con datos de cap_db.

---

### M6 — Certificación: SLOs reales + Compliance

| ID | Átomo | Estado | Commit | Notas | Rev activa |
|---|---|---|---|---|---|
| M6.1 | k6 Escenario 2 Beta (50 tenants, 5K RPS): todos los SLOs de SBOS-PERF-001 | 🔴 | — | JSON-RPC P99<150ms · ctx_id lookup P99<5ms · WAL<50ms P99 | F5.7, F5.8 |
| M6.2 | Tenant deploy < 30s P50 · < 90s P99 verificado con k6 | 🔴 | — | SLO duro de SBOS-PERF-001 | F10.C.14 |
| M6.3 | Ficha install < 60s P50 · < 180s P99 verificado en VPS | 🔴 | — | SLO duro de SBOS-PERF-001 | F11.10 |
| M6.4 | FAPI 2.0 test suite contra KC staging (PAR, DPoP, PKCE, algoritmos) | 🔴 | — | SBOS-CERT-001 §3 · staging con dominio público | F13.2, F13.9 |
| M6.5 | Evidencia técnica ISO 27001: audit_events, ctx_id en logs, Vault secretos, Wazuh alertas | 🔴 | — | SBOS-CERT-001 §2.2 · 15 controles con artefacto verificado | F7.8, F8.x |

**DoD M6:** BOS certificado Alpha listo para staging real · SLOs verificados empíricamente ·
FAPI 2.0 y evidencia ISO 27001 generadas · `INFORME-CERTIFICACION-ALPHA.md` producido.

---

**Naturaleza post-M6 → F11+ en REGISTRO-ESTADO:**
Al completar M6, el BOS está certificado para Alpha (5 tenants reales).
F11 (Ficha Engine completo) + F10.C (Ciclo Tenants) ya habrán avanzado en M2.
El camino natural es hacia Beta (50 tenants) y GA v1 (500 tenants).

---

### M7 — Context Plane Vision: bAuth DDL + Templates + SDK (Junio 2026)

**Objetivo:** Materializar la visión del Context Plane (`SBOS-CONTEXT-PLANE-VISION.md`). El BOS debe
proveer la infraestructura de datos (DDL) y los contratos de identidad (templates) para que bAuth
pueda resolver contexto en <5ms y el desarrollador reciba `bos.GetContext()` en una sola llamada.

**Documentos fuente:**
- `bauth/plandeaccion/bauth/SBOS-CONTEXT-PLANE-VISION.md` — Visión fundacional
- `bauth/plandeaccion/bauth/BAUTH-INVENTARIO-TABLAS-DECISION.md` — 155 tablas con switches
- `bauth/plandeaccion/bauth/BAUTH-ROLTEMPLATE-SECCIONES.md` — Template v6.0 (14 secciones)
- `bauth/plandeaccion/bauth/BAUTH-GAP-VISION-vs-INVENTARIO.md` — Verificación de cobertura

| ID | Átomo | E | Estado | Commit | Notas | Rev activa |
|---|---|---|---|---|---|---|
| **M7.1** | **Aplicar DDL bAuth completa (155 tablas)** — Migrar 46 tablas del DDL antiguo + crear 57 nuevas + seeds para 103 tablas. El DDL debe cubrir los 12 dominios D1-D12 y estar organizado por secciones de dominio. | 5d | 🔴 | — | Fuente: `BAUTH-INVENTARIO-TABLAS-DECISION.md` BLOQUES 2 y 4. El DDL final debe estar en `BauthAgent/db/migrations/DDL_skSBOS_db.sql`. Sin este DDL, bAuth no tiene datos que evaluar. | F5.I.1–F5.I.12 |
| **M7.2** | **Templates de rol por dominio (12 tablas `idn_role_d*`)** — Cada dominio D1-D12 tiene N roles pre-configurados. La herramienta de merge conjuga configuraciones de dominios para armar un RolTemplate completo. | 3d | 🔴 | — | Fuente: `BAUTH-ROLTEMPLATE-SECCIONES.md` v6.0. Tablas T-400 a T-411. El admin selecciona 1 template por dominio y el sistema los combina. | F5.I.4 |
| **M7.3** | **Políticas por dominio (12 tablas `ath_policy_d*`)** — Cada dominio tiene su colección de políticas pre-diseñadas seleccionables. El admin elige políticas del dominio correspondiente al armar el rol. | 2d | 🔴 | — | Fuente: Autentication_Framework.json + Policies_Authentication_Framework.json. Tablas T-350 a T-361. Las políticas existentes en `ath_policy` se migran a sus tablas de dominio. | F5.I.5 |
| **M7.4** | **Configuraciones por dominio (12 tablas `ath_config_d*`)** — Cada dominio tiene sus propias configuraciones por defecto. Separadas para evitar "plato de espaguetis". | 1d | 🔴 | — | Tablas T-370 a T-381. Las configuraciones existentes en `ath_config` se migran a sus tablas de dominio. | F5.I.6 |
| **M7.5** | **Context API `:9443` — `bos.GetContext()`** — Endpoint que recibe ctx_id y retorna el contexto unificado: user, tenant, branch, trust, permissions. Una sola llamada. | 2d | 🔴 | — | GET /api/v1/context/{ctx_id} → JSON con identidad + dispositivo + ubicación + horario + confianza + empresa + sucursal + permisos. P99 < 5ms (Redis cache). F5.A–F5.H ya existentes. | F5.A.2, F5.C.2 |
| **M7.6** | **Mover `menu_*` de `bauth` a `bglobal`** — El sistema de menús es de propósito global, no solo de autenticación. | 0.5d | 🔴 | — | T-090, T-091, T-092. `bauth.menu_*` → `bglobal.menu_*`. Actualizar FKs y seeds. | F5.I.8 |
| **M7.7** | **`ath_method` con `domain_classification`** — Agregar columna JSONB para clasificar cada método de autenticación por los dominios donde aplica. | 0.5d | 🔴 | — | T-065. Columna: `domain_classification JSONB DEFAULT '{}'`. Ej: `{"D1":true,"D2":true,"D9":true}`. El admin filtra métodos por dominio al configurar un rol. | F5.I.9 |
| **M7.8** | **Context Plane → bAuth integration** — El BOS propaga el contexto resuelto a bAuth vía Unix socket `/run/bos/bauth.sock` para que bAuth lo use en la evaluación de políticas. | 2d | 🔴 | — | `bos.ctx.resolve` → envía ctx_id a bAuth → bAuth evalúa 12 dominios contra el RolTemplate → retorna DomainResult. El BOS cachea el resultado en Redis DB1 (TTL 30s). | F5.I.10 |

**DoD M7:** `bos.GetContext(ctx_id)` retorna contexto unificado con las 9 dimensiones de la visión ·
DDL de 155 tablas aplicado en PostgreSQL · Templates de rol por dominio funcionales ·
Políticas y configuraciones organizadas por dominio · Menú en bglobal.

---

## FASE 0 — Fundación e Infraestructura

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F0.0 | Snapshot pre-reparación | ✅ | 3dade7c | tag: pre-repair-2026-06-09 · 79 archivos Go | ☐ |
| F0.1 | Directorio `_legacy/` y README | ✅ | 39d1f37 | SFP-01 activo | ☐ |
| F0.2 | `doc.go` × 11 paquetes nuevos | ✅ | 4f95388 | 11 contratos ADR-003 · race P6/P14 documentada | ☐ |
| F0.3 | `internal/tui/` subpaquetes + POLICY.md | ✅ | 37a1716 | 5 doc.go + POLICY.md — 15 pantallas inventariadas, 7 reglas | ☐ |
| F0.4 | `internal/paths/paths.go` | ✅ | ea4b625 | 29 constantes + 3 helpers · -race -count=3 PASS | ☐ |
| F0.5 | Pipeline CI/CD | ✅ | 635a421 | ci.yml 4 jobs · validate.sh fix GOROOT/bin · branch-protection.md · race ✅ | ☐ |
| F0.6 | Entornos DEV/STAGING/PROD + runner | ✅ | c53f9dc | ENVIRONMENTS.md + staging-runner-setup.sh + deploy-staging job | ☐ |
| F0.6.S | Usuario bos en staging (deuda seguridad) | ✅ | b135af4 | bosagent uid=999 creado en VPS · install.sh pasos 1-5 completos | ☐ |
| F0.7 | Limpieza pre-reparación: archivar residuos a `_legacy/` | ✅ | 64f26f1 | 7 paquetes/archivos archivados — SOLO REFERENCIA DE LÓGICA | ☐ |

## FASE 1 — Extraer `cmd/bos/main.go`

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F1.1 | `auditLog()` → `internal/audit/` | ✅ | 78a186c | 4 tests race -count=20 ✅ · 18 llamadas migradas · stub presente | ☐ |
| F1.2 | `autoBootstrap()` → `internal/bootstrap/` | ✅ | a3cfe9a | setup.go + verify.go + bootstrap_test.go · SRP + testabilidad | ☐ |
| F1.3 | `verifyCgroupDelegation()` → `internal/cgroup/` | ✅ | de278fb | cgroup.go + cgroup_test.go · isBareMetal + configureSystemdDelegate | ☐ |
| F1.4 | `ensureBridgeNetwork()` → `internal/network/` | ✅ | 465f574 | network.go + network_test.go · detectNetworkSubnet + nftables + bridge | ☐ |
| F1.5 | Observer loop → `internal/observer/` + MUTEX | ✅ | 3679b15 | observer.go + startup.go + observer_test.go · race P6/P14 corregida | ☐ |
| F1.6 | Activar `startWatchdog()` (P12) | ✅ | f1a7aac | stopCh + defer close · 2 tests race ✅ · P12 corregido | ☐ |
| F1.7 | Extraer helpers OS + adaptador release → `internal/system/` + `internal/release/` | ✅ | 62a524c | ExecAsRoot, SystemctlCmd, SDNotify, StartWatchdog, Adapter — main.go 618L | ☐ |
| F1.8 | Extraer `runConfigPending()` → `cmd/bos/config_pending.go` | ✅ | 5c1553a | runConfigPending en archivo propio | ☐ |
| F1.9 | Dividir `runNormal()` + verificación main.go ≤350 líneas | ✅ | 5c1553a | env.go+auto_bootstrap.go+run_normal.go+shutdown.go · 118L final | ☐ |

## FASE 2 — Unificar WebSocket

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F2.1 | Extender `internal/wslib/` — agregar `DialUnix` | ✅ | c389262 | DialUnix(path, timeout) — net.DialTimeout + RFC 6455 | ☐ |
| F2.2 | Migrar `wsRequest()` de bosctl | ✅ | c389262 | gorilla → wslib.DialUnix · imports context/net eliminados | ☐ |
| F2.3 | Migrar `connectWS/sendWS/awaitWS` | ✅ | c389262 | *wslib.Conn en wsReadyMsg/model/sendWS/RunAutoInstall | ☐ |
| F2.4 | Eliminar gorilla de go.mod | ✅ | c389262 | go mod tidy — gorilla removido completo | ☐ |

## FASE 3 — TUI: Partir `install_ui.go` y pantallas reales

### 3.A — Arquitectura modular (extracción del monolito)

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F3.1 | `internal/tui/styles/styles.go` | ✅ | 483af30 | 11 colores + 25 estilos + 6 iconos + Badge + RenderMFAToggle | ☐ |
| F3.2 | `internal/tui/model/types.go` — Screen enum | ✅ | 806a2b5 | Screen(15)+StepStatus(5)+FichaStatus(4)+LogLevel(5) · P11 parcial | ☐ |
| F3.3 | `internal/tui/model/model.go` — campo único | ✅ | dab18da | Model+Config+SeedData+New()+Init()+SetScreen() · P11 corregido | ☐ |
| F3.4 | `internal/tui/model/events.go` | ✅ | 8b77fbb | WsReadyMsg+WsErrorMsg+SysInfoMsg+TickMsg+TickCmd() | ☐ |
| F3.5 | `internal/tui/demo/demo.go` | ✅ | f4dce2e | DemoSubComponents+DemoLogLine+RunDemo; 4898→4710L | ☐ |
| F3.6 | Corrección TEA — handlers puros | ✅ | 1e10d94 | P3 corregido: ts en awaitWS Cmd, no en Update; startDemoCmd; handleWS usa ev.ts | ☐ |
| F3.7 | `internal/tui/model/viewport.go` | ✅ | 65beafa | VpDims+VScrollbar+HScrollbar extraídos; install_ui.go usa wrappers 1-línea | ☐ |
| F3.8 | `internal/tui/screens/` — estructura 15 pantallas | ✅ | e284397 | dispatcher.go + helpers.go + 15 archivos (renders como stubs → se completan en 3.B) | ☐ |
| F3.9 | `internal/tui/model/keys.go` | ✅ | 79a2602 | ScreenKeyMap+IsNavKey()+KeysFor(s Screen) — 15 casos, help.KeyMap | ☐ |
| F3.10 | `install_ui.go` ≤80 líneas | ✅ | 6525771 | 62L entry point · impl.go + unattended.go · legacy archivado SFP-01 | ☐ |

### 3.B — Renders reales con paridad visual (completa F3.8)

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F3.11 | Auditoría de paridad: stub vs legacy → `internal/tui/PARIDAD.md` | ✅ | cd3a12b | 15 pantallas mapeadas · 51 campos · 28 estilos · plan F3.12–F3.17 | ☐ |
| F3.12 | Renders reales Grupo Splash (S00 welcome, S14 goodbye) | ✅ | 05b70dc | 14 tests · race×20 goroutines · paridad S00/S14 · renderGoodbyeAt determinista | ☐ |
| F3.13 | Renders reales Grupo Wizard (S01-S04) + validación de formularios | ✅ | 67c3a88 | shared.go+wizard.go · 30 tests · MFA toggle · race×10 · assembleScreen | ☐ |
| F3.14 | Renders reales Grupo Install (S05 3-columnas vpA/B/C, S06 log, S07 error) | ✅ | 5d8cc5a | installing.go · 40 tests · scriptTag · BuildColA/B/C · race×10 | ☐ |
| F3.15 | Renders reales Grupo Post (S08 done, S09 countdown, S10 boot) | ✅ | 1f89321 | postinstall.go · 35 tests · 4 tabs S06 · countdown bar S07 · boot seq S08 · race×10 | ☐ |
| F3.16 | Renders reales Grupo Runtime (S11 dashboard, S12 logs+filtros, S13 shutdown) | ✅ | f9171a6 | dashboard.go · 38 tests · daemon grid · LIVE log · toolbar dual · shutdown seq · race×10 | ☐ |
| F3.17 | Modularidad: `bosctl dev new-screen` + plantilla + test guardián | ✅ | a4e8871 | cmd/bosctl/dev.go · POLICY.md §6 · _template.go.tmpl · dispatcher_test.go guardián · DoD Demo: ScreenDemo creada+verificada+eliminada | ☐ |
| F3.18 | Dashboard ctrl completo — 23 vistas + flujo boot + botones poder | ✅ | ae24afb | internal/tui/ctrl/ nuevo paquete · doc.go · DashAction (reboot/shutdown) · viewBoot/Shutdown/Reboot layout dual · dims_test 23/23 ✅ | ☐ |

> **Rev F3.16 y F3.18** se validan con M1.1–M1.3 (observer real) y M2.3 (TUI ScreenInstalling eventos reales)

**DoD del bloque 3.B:** cada pantalla con `TestScreen<N>_ParidadGolden` ·
`bosctl install --demo` muestra renders reales · race ×10 · POLICY.md con
procedimiento de adición en 7 pasos.

### 3.C — Contratos de Comunicación BOS ↔ TUI (SBOS-053 + ADR-019/020 + C-4 + C-6)

**Objetivo:** Implementar el protocolo completo de comunicación entre el daemon (BOS) y su
interfaz visual (TUI) según SBOS-053. La TUI es OBSERVADOR (Rol A) y RECOLECTOR (Rol B).
El daemon es PRODUCTOR de eventos y VALIDADOR de comandos. La comunicación usa TRES capas
de transporte (Unix socket WebSocket, Redis Streams, File tail) y DOS interfaces (WebSocket
RPC + JSON-RPC 2.0 sobre el MISMO socket — ADR-019/020). Cada tipo de mensaje, cada regla
DTC y cada caso DC es un átomo independiente.

**Documentos fuente:** SBOS-053 §3, §6, §7, §8, §9, §10 · ADR-019/020 · BOS-CONTRATOS-SBOS C-4, C-6
**Estándares:** W3C WebSocket RFC 6455 · JSON-RPC 2.0 · OpenTelemetry Baggage · debconf frontend/backend

#### 3.C.1 — Infraestructura de Transporte (3 capas físicas + Interface Dual)

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F3.C.1 | **Capa 1 — WebSocket sobre Unix socket:** `internal/server/ws.go`. Upgrade HTTP→WS en `/run/bos/bos.sock`. Eventos + comandos + seed_params. Mismo socket que JSON-RPC (ADR-020). Sin TCP externo. SBOS-050 P9 | 🔴 | — | Frame size max 64KB. CheckOrigin estricto (solo localhost). Max 50 conexiones concurrentes. Idle timeout 60s. Heartbeat 5s | ☐ |
| F3.C.2 | **Capa 2 — Redis Streams:** `internal/eventbus/redis_streams.go`. Eventos persistentes multi-tenant. Daemon XADD, TUI/bnotify/audit XREAD. Sin pérdida de eventos si la TUI se desconecta. Consumer groups por tipo de consumidor | 🔴 | — | Stream: `bos:saga:{tenant_id}`. Max len 10K. Consumer group: `tui-{saga_id}`. Patrón: sbos-notifier (pub/sub vía Redis Streams). DTC-04 | ☐ |
| F3.C.3 | **Capa 3 — File tail:** `internal/tui/model/log_reader.go`. TUI lee FICHA_LOG desde disco (tail -f). Sin buffer en memoria. Log sobrevive sin TUI. Legible vía `bosctl ficha logs`. DTC-08 | 🔴 | — | `/var/log/bos/fichas/<name>.log`. Rotación: 10MB por archivo, 5 archivos. Formato: JSON Lines (un JSON por línea). Timestamp UTC | ☐ |
| F3.C.4 | **Interface Dual (ADR-019/020):** WebSocket RPC + JSON-RPC 2.0 sobre el MISMO socket `/run/bos/bos.sock`. Vía 1 (WS RPC) → CLI, humanos. Vía 2 (JSON-RPC 2.0) → daemons, scripts, agentes IA. Namespace: `bos.<modulo>.<operacion>` | 🔴 | — | Registro central de métodos en `internal/server/rpc_registry.go`. Auth por método. Timeout por categoría. Batch paralelo. Errores estándar JSON-RPC | ☐ |
| F3.C.5 | **Paquete `contracts/events/`:** tipos puros compartidos entre `cmd/bos/` y `internal/tui/`. Sin lógica de negocio, sin imports externos. `seed_params.go` + `saga_event.go` + `command.go` + `snapshot.go` | 🔴 | — | `go list -deps` verifica: contracts/ NO importa nada de bos/ ni tui/. SBOS-053 §10. DTO/domain split estricto. DTC-11 | ☐ |

#### 3.C.2 — Catálogo Completo de Eventos (Daemon → TUI)

| ID | Átomo | Estado | Commit | Notas | Rev | DTC |
|---|---|---|---|---|---|---|
| F3.C.6 | `SAGA_STARTED` — Saga iniciada. Contiene: saga_id, saga_type, total_steps, tenant_id, ctx_id | 🔴 | — | Emitido por `installer/saga.go:Start()`. TUI pasa de ScreenWelcome/P4 → ScreenInstalling. Inicia spinner | ☐ | DTC-04 |
| F3.C.7 | `STEP_STARTED` — Paso de saga iniciado. Contiene: saga_id, step, step_total, ficha, ctx_id | 🔴 | — | Emitido antes de task_catalog.sh. TUI: spinner + "Instalando {ficha}..." | ☐ | DTC-04 |
| F3.C.8 | `STEP_COMPLETED` — Paso exitoso. Contiene: saga_id, step, duration_ms, detail (ej: "RD-01..06 OK") | 🔴 | — | Emitido tras exit code 0. TUI: ✅ checkmark + detail + tiempo | ☐ | DTC-04 |
| F3.C.9 | `STEP_FAILED` — Paso fallido. Contiene: saga_id, step, error, exit_code, detail | 🔴 | — | Emitido tras exit code ≠ 0. TUI: ❌ + diagnóstico 3-partes. Dispara compensación automática. DC-02 | ☐ | DTC-04 |
| F3.C.10 | `STEP_SKIPPED` — Paso saltado (idempotente). Contiene: saga_id, step, reason | 🔴 | — | TUI: ⏭️ + reason. Sin acción requerida | ☐ | DTC-04 |
| F3.C.11 | `COMPENSATION_STARTED` — Rollback iniciado. Contiene: saga_id, failed_step, steps_to_compensate[] | 🔴 | — | TUI muestra: "↩️ Revirtiendo pasos 3,2,1...". Daemon ejecuta compensación inversa | ☐ | DTC-04 |
| F3.C.12 | `COMPENSATION_COMPLETED` — Rollback exitoso. Contiene: saga_id, compensated_steps[], duration_ms | 🔴 | — | TUI: ✅ "Rollback completado. Sistema en estado limpio." | ☐ | DTC-04 |
| F3.C.13 | `SAGA_COMPLETED` — Saga finalizada 7/7. Contiene: saga_id, total_duration_ms | 🔴 | — | TUI pasa a ScreenDone. Muestra health check H-01..H-10 | ☐ | DTC-04 |
| F3.C.14 | `SAGA_SNAPSHOT` — Snapshot completo al reconectar. Contiene: current_step, steps_completed[], steps_failed[], active_compensations[], ctx_id | 🔴 | — | Daemon consulta bkernel_db.saga_state. TUI renderiza estado real. DC-03. DTC-06 + DTC-13. Event Sourcing Snapshot pattern | ☐ | DTC-06, DTC-13 |
| F3.C.15 | `HEARTBEAT` — Latido cada 5s. Contiene: uptime_s, memory_mb | 🔴 | — | Timeout 15s → TUI muestra "reconectando...". Backoff 1→2→4→8→30s. 5 reintentos máx | ☐ | DTC-05 |
| F3.C.16 | `LOG_LINE` — Línea de log en streaming. Contiene: level, message, ficha, timestamp | 🔴 | — | TUI panel de log (columna 2). Auto-scroll con Ctrl+F. Pausa con 's' | ☐ | DTC-08 |
| F3.C.17 | `DASHBOARD_DATA` — Datos para dashboard post-instalación. Contiene: fichas_ok, fichas_degraded, health_score, uptime | 🔴 | — | TUI en modo observabilidad (DC-10). Se recibe cada 30s. Paneles: overview, monitoreo, logs | ☐ | DTC-13 |

#### 3.C.3 — Catálogo Completo de Comandos (TUI → Daemon)

| ID | Átomo | Estado | Commit | Notas | Rev | DTC |
|---|---|---|---|---|---|---|
| F3.C.18 | `START_SAGA` — Iniciar saga con seed_params. Payload: seed_params (≡ seed.yml schema). Rol B → Rol A | 🔴 | — | TUI envía al confirmar P4. Daemon persiste en bkernel_db ANTES de lanzar saga (DTC-12). Respuesta: saga_id + "accepted" | ☐ | DTC-09, DTC-12 |
| F3.C.19 | `RETRY_STEP` — Reintentar paso fallido. Payload: saga_id, step | 🔴 | — | Daemon valida: ¿estado=FAIL? ¿sin compensación activa? ¿step ≤ current_step? Rechazo con código error si inválido (DTC-07) | ☐ | DTC-07 |
| F3.C.20 | `ABORT_SAGA` — Abortar saga y compensar. Payload: saga_id, reason | 🔴 | — | Daemon ejecuta compensación inversa completa → LIMPIEZA. TUI recibe COMPENSATION_STARTED → COMPLETED | ☐ | DTC-07 |
| F3.C.21 | `GET_SNAPSHOT` — Solicitar estado actual. Payload: ?saga_id (opcional) | 🔴 | — | Idempotente. Daemon consulta bkernel_db, retorna SAGA_SNAPSHOT. Usado en reconexión y polling | ☐ | DTC-06 |
| F3.C.22 | `GET_DASHBOARD` — Solicitar datos del dashboard. Payload: ?tenant_id (opcional) | 🔴 | — | Daemon consulta state manager + health checker. Retorna DASHBOARD_DATA. Usado por TUI post-instalación | ☐ | DTC-13 |
| F3.C.23 | `SUBSCRIBE_LOGS` — Suscribirse a streaming de logs. Payload: ficha (opcional, todas si no) | 🔴 | — | TUI recibe LOG_LINE para la(s) ficha(s) suscritas. Unsubscribe al desconectar | ☐ | DTC-08 |

#### 3.C.4 — Parámetros Pre-Saga (Rol B → Daemon, Contrato seed.yml)

| ID | Átomo | Estado | Commit | Notas | Rev | DTC |
|---|---|---|---|---|---|---|
| F3.C.24 | `SEED_PARAMS` — Payload de parámetros de instalación. Schema idéntico a seed.yml (SBOS-051 §14.1-14.2). Incluye: enterprise_tenant, identity, infrastructure, databases, vault, redis, context_plane, fichas, users | 🔴 | — | TUI construye desde formularios P1-P4. Validado contra schema antes de enviar. Campos desconocidos → rechazar (SAN-10). DTC-11: todo campo TUI tiene equivalente seed.yml | ☐ | DTC-11, SAN-10 |
| F3.C.25 | Persistencia pre-saga: SEED_PARAMS → `bkernel_db.seed_params` + materializar `seed.yml` en disco antes de lanzar saga | 🔴 | — | Si TUI se cierra post-confirmar → params no se pierden. Daemon lee de bkernel_db al iniciar saga. DC-07. DTC-12. Write-ahead pattern | ☐ | DTC-12 |
| F3.C.26 | `VALIDATE_SEED` — Validar seed_params sin ejecutar. Payload: seed_params. Respuesta: errores de validación o "valid" | 🔴 | — | Usado por TUI en P4 antes de confirmar. Dry-run de validación. También disponible como `bosctl deploy --dry-run` | ☐ | DTC-09 |

#### 3.C.5 — Tres Momentos de Conexión (SBOS-053 §3.4)

| ID | Átomo | Estado | Commit | Notas | Rev | DTC |
|---|---|---|---|---|---|---|
| F3.C.27 | **Pre-instalación:** TUI detecta daemon idle (sin saga activa) → presenta wizard (Rol B). Consulta `GET_SNAPSHOT` → sin saga → ScreenWizardP1 | 🔴 | — | `internal/tui/model/preflight.go`. Si hay seed.yml → modo híbrido (cargar defaults). Si no → wizard vacío. DTC-13 | ☐ | DTC-13 |
| F3.C.28 | **Durante instalación:** TUI detecta saga activa → recibe SAGA_SNAPSHOT → muestra progreso real → Rol A (solo observar). Sin reiniciar nada | 🔴 | — | `internal/tui/model/ws.go:onConnect()`. Si snapshot.current_step > 0 → ScreenInstalling. Si snapshot.current_step = 7 → ScreenDone. DC-03 | ☐ | DTC-06, DTC-13 |
| F3.C.29 | **Post-instalación:** TUI se conecta 24h después → daemon idle, fichas instaladas → dashboard (Rol A). Sin ofrecer reinstalar | 🔴 | — | GET_DASHBOARD → fichas_status, health_score. Modo observabilidad continua. DC-10. Sin pantalla de bienvenida vacía | ☐ | DTC-13 |

#### 3.C.6 — Pruebas de Desacoplamiento (DC-01 a DC-10, SBOS-053 §9)

| ID | Átomo | Estado | Commit | Notas | Rev | DTC |
|---|---|---|---|---|---|---|
| F3.C.30 | DC-01: Instalación sin TUI — `bosctl deploy seed.yml` completa 7/7 sin TUI abierta | 🔴 | — | CI test: levantar daemon, deploy seed vía JSON-RPC (no WebSocket TUI), verificar H-01..H-10. Zero dependencia de TUI | ☐ | DTC-01 |
| F3.C.31 | DC-02 + DC-03: Cierre y reconexión — kill -9 TUI paso 3/7, daemon completa, reconectar → snapshot 7/7 | 🔴 | — | Test: `kill -9 $(pgrep bosctl)`, sleep 30, iniciar nueva TUI, verificar SAGA_SNAPSHOT.current_step = 7. Daemon nunca bloqueó | ☐ | DTC-05, DTC-06 |
| F3.C.32 | DC-04: 2 TUIs simultáneas → mismo progreso, sin interferencia | 🔴 | — | Test: 2 goroutines WebSocket, mismo saga_id. Ambas reciben mismos eventos. Ninguna afecta al daemon ni a la otra | ☐ | DTC-04 |
| F3.C.33 | DC-05: Comando inválido → rechazo explícito. TUI reconectada (7/7) envía RETRY_STEP 3 → daemon rechaza con error code | 🔴 | — | Test: saga completada, enviar RETRY_STEP. Verificar respuesta: `{"error":{"code":-32007,"message":"step already completed"}}` | ☐ | DTC-07 |
| F3.C.34 | DC-06: Secreto no transita por TUI → inspeccionar payloads WS, zero secretos | 🔴 | — | CI grep: `grep -E '(password|token|secret|key)'` en dumps WS de test. Zero matches. Vault como única fuente | ☐ | DTC-10 |
| F3.C.35 | DC-07: Parámetros persisten → confirmar P4, kill TUI antes de paso 1, daemon completa saga con params correctos | 🔴 | — | Test: enviar SEED_PARAMS, kill TUI inmediatamente, verificar `bkernel_db.seed_params` tiene los datos, saga completa 7/7 | ☐ | DTC-12 |
| F3.C.36 | DC-08: Equivalencia wizard vs seed.yml → instalar 2× (wizard y CLI) → diff = vacío | 🔴 | — | Test: instalar tenant con wizard, exportar seed.yml, instalar con CLI, comparar estado final (CRs, DB schemas, health checks) | ☐ | DTC-09 |
| F3.C.37 | DC-09: Modo híbrido → `bosctl setup --seed partial.yml` → wizard defaults + campos faltantes | 🔴 | — | Test: seed con solo legal_name y realm → wizard muestra esos valores, resto vacíos. Confirmar → deploy idéntico a seed completo | ☐ | DTC-09, DTC-11 |
| F3.C.38 | DC-10: Conexión post-instalación → TUI conecta 24h después, muestra dashboard, no wizard | 🔴 | — | Test: completar instalación, esperar (simular 24h), conectar TUI → GET_DASHBOARD, sin ScreenWizardP1, sin ofrecer reinstalar | ☐ | DTC-13 |

#### 3.C.7 — Anti-Patrones Prohibidos (SBOS-053 §11)

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F3.C.39 | CI check: `go list -deps ./cmd/bos/ | grep tui` → CERO matches. Bos NUNCA importa tui/ | 🔴 | — | `.github/workflows/ci.yml`: job `decoupling-check`. Si encuentra import → falla el PR. SBOS-053 §10 | ☐ |
| F3.C.40 | CI check: `grep -r "tui.InstallFicha\|tui.ExecuteStep"` → CERO matches. TUI NUNCA ejecuta lógica de saga | 🔴 | — | La TUI envía comandos, no ejecuta funciones del daemon. Verificar en cada PR | ☐ |
| F3.C.41 | CI check: `grep -r "select {.*tuiConfirmChan\|<-.*tuiReady"` → CERO matches. Daemon NUNCA bloquea esperando TUI | 🔴 | — | Fuera de gates HITL explícitos (tenant remove), el daemon no depende de la TUI. DTC-02 | ☐ |
| F3.C.42 | CI check: `grep -r "sagaInUse\|lock.*saga\|exclusive.*tui"` → CERO matches. Sin lock exclusivo de TUI | 🔴 | — | Múltiples observadores permitidos. Sin "saga en uso". DC-04. DTC-04 | ☐ |
| F3.C.43 | CI check: secretos en payloads WS → `grep -E '(password|token|secret|key|shamir)'` en test dumps → CERO matches | 🔴 | — | DTC-10. ISO 27001 A.8.12. Secretos solo via Vault, nunca en canal de eventos | ☐ |

---

## FASE 4 — Limpiar `cmd/bosctl/` y eliminar RBAC propio

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F4.1 | Centralizar kubeconfig (P5 ×6) | ✅ | 58d2da6 | ResolveKubeconfig() — 5 tests -race ✅ · 7 inst. → 1 | ☐ |
| F4.2 | `ensureDaemonRunning()` con rollback (P9) | ✅ | 58d2da6 | rollback de dirs creados · no sobreescribir toml · kill solo "bos" | ☐ |
| F4.3 | Corregir `bosRBAC` global (P15) | ✅ | 58d2da6 | sync.Once — rbacOnce/rbacInst en rbac.go | ☐ |
| F4.4 | Eliminar `rbac_provider.go` (ADR-006) | ✅ | 58d2da6 | → interfaces.go · legacy archivado SFP-01 | ☐ |
| F4.5 | `cmd/bosctl/main.go` ≤120 líneas | ✅ | 58d2da6 | 107L · +5 archivos separados (daemon/os/ws/rbac/usage) | ☐ |

## FASE 5 — Context Plane: Especificación Atómica Completa (SBOS-049 + SBOS-054 §8 + RB-03)

**Objetivo:** El Context Plane es el plano de significado empresarial del SBOS. Cada operación sobre
un ctx_id es un átomo independiente porque cada una tiene implicaciones de seguridad, auditoría y
performance distintas. Basado en SBOS-049 §5 (flujo ctx_id), SBOS-054 §8 (seguridad), RB-03 (operación).

**Documentos fuente:** SBOS-049-CONTEXT-PLANE §5 · SBOS-054 §8 · ADR-033 · RB-03-CONTEXT-PLANE-DOWN
**Estándares:** W3C Trace Context · OpenTelemetry Baggage · NIST SP 800-207 Tenet 3 · ISO 27001 A.8.15/A.9.4.2

### 5.A — Núcleo: Tipos, Servicio y Persistencia

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F5.A.1 | `internal/context/types.go` — DeviceContext, SessionContext, ContextState, BitMask, LoA | ✅ | ffdaab3 | Tipos base del Context Plane. BitMask 64-bit. ContextState enum (PENDIENTE, ACTIVO, EXPIRADO, INVALIDADO, SWITCHEADO). 4 tests race ✅ | ☐ |
| F5.A.2 | `internal/context/service.go` — Service layer: RegisterDevice, Promote, Switch, Invalidate, Get, List | ✅ | f070556 | 11 métodos. memStore para tests unitarios. Validación de estado (no promover expirado, no invalidar ya inválido). 6 tests race ✅ | ☐ |
| F5.A.3 | `internal/context/store.go` — PGRedisStore: PostgreSQL (fuente de verdad) + Redis DB1 (cache O(1)) | ✅ | 21f1576 | Cache-first: leer Redis → fallback PostgreSQL. SQLExecutor+RedisClient interfaces para testabilidad. 3 tests race ✅ | ☐ |
| F5.A.4 | `internal/context/store.go` — AutoMigrate: DDL `context_sessions` + `registered_devices` | ✅ | 9ceeb68 | CREATE TABLE IF NOT EXISTS. Particionado por tenant_id. Índices: idx_ctx_tenant, idx_ctx_expires. F10.B.12 | ☐ |
| F5.A.5 | W3C Trace Context + OpenTelemetry Baggage: propagación de ctx_id en todos los canales | ✅ | c294555 | IsValidTraceparent/NewTraceparent/Extract/Inject. Baggage keys: ctx.id, tenant.id, empresa.id, sucursal.id, pos.id, user.id. TestTraceContext race ✅ | ☐ |

### 5.B — Ciclo de Vida del dctx_id (Device Context — Pre-autenticación)

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F5.B.1 | `bos.ctx.device.register` — Registrar dispositivo anónimo. Recibe: hostname, tenant_id, node_k8s, ip. Retorna: dctx_id | ✅ | e3951d5 | Crea DeviceContext con bitmask=0x0, state=PENDIENTE. TTL inicial 30min (renovable). Redis DB1 + bkernel_db | ☐ |
| F5.B.2 | dctx_id heartbeat — Renovar TTL del dispositivo. Si no hay heartbeat en 30min → state=EXPIRADO | 🔴 | — | `bos.ctx.device.heartbeat`. El dispositivo (sbos-client, VDI) llama cada 30s. Sin heartbeat → dctx_id expira y no puede promoverse | ☐ |
| F5.B.3 | dctx_id TTL enforcement — Kong verifica dctx_id antes de servir contenido público. Expirado → nuevo dctx_id | 🔴 | — | Kong Plugin: si dctx_id expirado, generar nuevo automáticamente (cookie __sbos_dctx). Sin interrumpir navegación anónima | ☐ |
| F5.B.4 | dctx_id → ctx_id promotion (precondición de login). Validar que dctx_id no esté expirado ni ya promovido | 🔴 | — | `bos.ctx.device.promote`: dctx_id + user_id + empresa_id + sucursal_id + pos_logico → ctx_id. Un dctx_id solo se promueve UNA vez | ☐ |

### 5.C — Ciclo de Vida del ctx_id (Context Session — Post-autenticación)

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F5.C.1 | `bos.ctx.promote` — Crear Context Session desde Device Context. Recibe: dctx_id, empresa, sucursal, pos_logico, user_id, LoA | ✅ | f070556 | Genera ctx_id (UUID v4). Calcula BitMask según LoA + RolTemplate. TTL = duración sesión Keycloak. Almacena en Redis DB1 + bkernel_db | ☐ |
| F5.C.2 | `bos.ctx.get` — Obtener ctx_id por ID. Validar TTL. Si expirado → state=EXPIRADO, retornar error -32001 ContextExpired | ✅ | 66f26b3 | Cache-first: Redis DB1 → PostgreSQL fallback. F6.5: ErrContextExpired = -32001. Sin diferenciar "no encontrado" de "expirado" (anti-enumeration) | ☐ |
| F5.C.3 | `bos.ctx.switch` — Cambiar de contexto (empresa/sucursal/POS) sin re-login. Invalidar ctx_id anterior, crear nuevo | ✅ | f070556 | Validar que el usuario tiene acceso al nuevo contexto (BitMask). Preservar user_id y session_kc. Nuevo ctx_id con TTL heredado del anterior | ☐ |
| F5.C.4 | `bos.ctx.invalidate` — Invalidar un ctx_id específico (logout). Marcar state=INVALIDADO, TTL=0 en Redis, audit_event | ✅ | f070556 | Llamado por Keycloak Event Listener en logout. Si el ctx_id ya estaba expirado → no error (idempotente) | ☐ |
| F5.C.5 | `bos.ctx.invalidate_all_by_tenant` — Invalidar TODOS los ctx_id de un tenant (suspend/remove) | 🔴 | — | `bosctl tenant suspend` dispara este método. Redis: eliminar todas las keys del tenant. bkernel_db: UPDATE state=INVALIDADO WHERE tenant_id=X. Audit event por cada invalidación | ☐ |
| F5.C.6 | `bos.ctx.list_by_tenant` — Listar ctx_id activos de un tenant. Solo para administradores del tenant | ✅ | f070556 | Filtro: state=ACTIVO. Sin exponer session_kc ni user_id completo. Paginación (max 100 por página). Rate limit: 10 req/min | ☐ |

### 5.D — Seguridad del ctx_id (SBOS-054 §8)

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F5.D.1 | UUID v4 estricto en ctx_id — Validar formato en TODOS los endpoints que reciben ctx_id. Rechazar cualquier otro formato con 400 | 🔴 | — | Regex: `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`. SAN-09. Anti-injection | ☐ |
| F5.D.2 | Anti-enumeration: respuesta idéntica para ctx_id "no encontrado" y "expirado". Mismo HTTP status, mismo mensaje, misma latencia | 🔴 | — | `handleContextLookup`: 404 para ambos casos. Mensaje: "context not found or expired". Sin revelar si el ID existe. Rate limit 100 req/s | ☐ |
| F5.D.3 | dctx_id pre-auth security: bitmask=0x0 NO autoriza acceso a recursos. Kong verifica bitmask > 0 antes de forward | 🔴 | — | Kong Plugin: si solo hay dctx_id (sin ctx_id), solo rutas públicas. Si bitmask=0x0 → 401. bAuth: rechazar bitmask=0x0 para toda operación | ☐ |
| F5.D.4 | ctx_id cross-tenant validation: verificar que tenant_id del request coincide con tenant_id del ctx_id. Prevenir escalación cross-tenant | 🔴 | — | `bos.ctx.validate`: recibir ctx_id + tenant_id. Si no coinciden → -32001. Kong inyecta X-SBOS-Tenant, el servicio verifica contra ctx_id | ☐ |
| F5.D.5 | Sanitización de ctx_id en logs: nunca loguear ctx_id completo. Solo primeros 8 chars + hash. Nunca loguear session_kc | 🔴 | — | `logSanitize(ctxID)`: "ctx-88291***". SAN-07. ISO 27001 A.8.15. Validar con grep en logs de staging | ☐ |
| F5.D.6 | Rate limiting en Context API :9443: 100 req/s por IP. Response 429 con retry_after_s. Timeout 2s | 🔴 | — | Token bucket en Go. Métricas: bos_context_validations_total, bos_rate_limit_exceeded_total. Alerta si >50 fallos/min | ☐ |

### 5.E — Propagación y Trazabilidad

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F5.E.1 | Propagación Kong→servicios: headers X-SBOS-Tenant, X-SBOS-Empresa, X-SBOS-Sucursal, X-SBOS-Ctx-Id, X-SBOS-Bitmask inyectados por Kong | 🔴 | — | Kong Plugin SBOS-Context (Lua). Headers inyectados en cada request forward. Servicio los recibe automáticamente. F13.6 prerequisito | ☐ |
| F5.E.2 | Propagación gRPC: RequestContext campo 1 en todos los mensajes (ADR-033). ctx_id + tenant_id obligatorios | 🔴 | — | `.proto` files: RequestContext como campo 1. Interceptor extrae y valida. Sin ctx_id → codes.InvalidArgument. ADR-033 | ☐ |
| F5.E.3 | Propagación WAL→bKernel: ctx_id en cada evento CDC. bkernel_db.audit_events con columna ctx_id | 🔴 | — | PostgreSQL wal_level=logical. bkernel extrae ctx_id del evento y lo propaga al stream Redis. F12.7 prerequisito | ☐ |
| F5.E.4 | Propagación logs (Loki): ctx_id como atributo vía OTel Baggage Processor. Sin modificar código de las fichas (cero invasión) | 🔴 | — | OTel Collector con Baggage Processor. Extrae ctx.id del baggage y lo inyecta como atributo en todos los spans y logs. SBOS-049 §2.1 | ☐ |

### 5.F — Auditoría y Cumplimiento

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F5.F.1 | audit_event por cada operación del Context Plane: device.register, promote, switch, invalidate, get, validate | 🔴 | — | Tabla `bkernel_db.audit_events`. Campos: ctx_id, operation, tenant_id, user_id, source_ip, result, timestamp, traceparent. ISO 27001 A.8.15 | ☐ |
| F5.F.2 | Métricas Prometheus del Context Plane: validations_total{result}, validation_duration_seconds, active_contexts, expired_contexts | 🔴 | — | `bos_context_validations_total{result="valid|expired|not_found|invalid"}`. Dashboard Grafana con SLO: P99 < 5ms. Alerta: >50 fallos/min | ☐ |
| F5.F.3 | Retención de audit_events: 90 días online (bkernel_db), 7 años offline (backups/S01/postgresql/). Cumplimiento fiscal LATAM | 🔴 | — | Particionado por mes. pg_partman para auto-particionado. Backup pg_dump programado. SBOS-044-FISCAL-CONTABLE-LATAM | ☐ |

### 5.G — Performance y SLOs

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F5.G.1 | ctx_id lookup P99 < 5ms (Redis cache). Medido con k6: 50 disp, 10 prom, 100 validaciones/s | 🔴 | — | SBOS-PERF-001 SLO. Si Redis cae → PostgreSQL P99 < 50ms (degradado pero funcional). RB-03 CASO A | ☐ |
| F5.G.2 | device.register < 2s P99 (C-13). Medido con PostgreSQL+Redis reales. Timeout máximo: 5s | 🔴 | — | F5.7. Incluye: validar tenant existe, crear DeviceContext, persistir en PG, cachear en Redis. Si timeout → retry 1 vez | ☐ |
| F5.G.3 | Context Plane bajo carga: 500 dispositivos concurrentes, 100 promociones/s, 50 switch/s ×60s. Zero bitmask_cero_count | 🔴 | — | F5.8. k6 escenario. Sin deadlocks. Sin race conditions. Métricas estables. Redis DB1 sin saturación (<70% memoria) | ☐ |

### 5.H — Operación y Recuperación

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F5.H.1 | Runbook RB-03: diagnóstico y reparación de Context Plane caído (5 casos: Redis down, PG down, F5 pendiente, bug, TTL expirado) | 🔴 | — | RB-03-CONTEXT-PLANE-DOWN.md validado contra código real. Tiempo de resolución: 5-20 min. Procedimiento documentado para cada caso | ☐ |
| F5.H.2 | Health check C-13: `bosctl bootstrap verify --only=C-13`. device.register < 2s. Redis DB1 responde. PostgreSQL responde | 🔴 | — | Integrado en watchdog 30s. Si falla 3 veces consecutivas → alerta. Degradación: sin Redis → PostgreSQL directo (lento pero funcional) | ☐ |
| F5.H.3 | Recuperación post-crash: al reiniciar bos.service, reconstruir cache Redis desde PostgreSQL. Sin pérdida de ctx_id activos | 🔴 | — | Startup reconcile: leer context_sessions WHERE state=ACTIVO, cargar en Redis DB1. Tiempo estimado: <30s para 10K ctx_id | ☐ |

### 5.I — Integración bAuth: DDL + Templates + Context Resolution (Visión Context Plane · Junio 2026)

**Objetivo:** Materializar los contratos de la visión del Context Plane. El BOS debe aplicar
el DDL completo de bAuth (155 tablas), crear los templates de rol por dominio, y proveer
la API `bos.GetContext()` que resuelve las 9 dimensiones del contexto en una sola llamada.

**Documentos fuente:**
- `bauth/plandeaccion/bauth/SBOS-CONTEXT-PLANE-VISION.md` — Visión fundacional
- `bauth/plandeaccion/bauth/BAUTH-INVENTARIO-TABLAS-DECISION.md` — 155 tablas con switches
- `bauth/plandeaccion/bauth/BAUTH-ROLTEMPLATE-SECCIONES.md` — Template v6.0 (14 secciones, ~900 atributos)
- `bauth/plandeaccion/bauth/BAUTH-GAP-VISION-vs-INVENTARIO.md` — Verificación de cobertura
- `bauth/plandeaccion/bauth/BAUTH-COMPLETITUD-DOMINIOS-STANDARDS.md` — 42+ estándares

#### 5.I.1 — DDL bAuth: Migración de 46 tablas del DDL antiguo

| ID | Átomo | E | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|---|
| **F5.I.1a** | Extraer y normalizar 46 tablas del DDL antiguo (`001_bauth_pendientes.sql`). Cambiar `bos_` → `bauth.`, TEXT PK → UUIDv7, español → inglés, agregar `ctx_id`, `created_at`, `updated_at`. Insertar en `DDL_skSBOS_db_test.sql`. | 4d | 🔴 | — | Ver `BAUTH-CLASIFICACION-TABLAS-PENDIENTES.md`. Lotes: D1(4) + D3(2) + D8(3) + D9(14) + D10(1) + D11(7) + D12(5) + User(3) + Org(3) + Sec(3) + Red(2) | ☐ |
| **F5.I.1b** | Crear 57 tablas nuevas sin antecedente en DDL antiguo. 12 `ath_policy_d*` + 12 `ath_config_d*` + 12 `idn_role_d*` + 4 `zone_*` + 2 `ath_auth_flow*` + 1 `ath_step_up_rule` + 2 `fis_*` + 2 D4 + 1 D7 + 2 D8 + 2 D14 | 3d | 🔴 | — | Ver `BAUTH-INVENTARIO-TABLAS-DECISION.md` BLOQUE 4. Cada tabla con COMMENT ON [ISO/NIST/RFC], UUIDv7 PKs, snake_case en inglés. | ☐ |
| **F5.I.1c** | Crear seeds para las 103 tablas nuevas/migradas. Datos reales desde estándares internacionales, no datos de prueba VPS. Idempotentes: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT. | 3d | 🔴 | — | Ver `BAUTH-SEED-PLAN.md`. Fuentes: ISO 4217, ISO 3166-1, IANA TZ, SAP ACTVT, NIST 800-63B-4, OWASP ASVS V2, RFC 9470. | ☐ |
| **F5.I.1d** | Organizar DDL final por secciones de dominio. 18 secciones: SECCIÓN 0 (Preámbulo) a SECCIÓN 18 (Sistema Global). Cada sección con separador claro y referencias a estándares. | 1d | 🔴 | — | Ver estructura en `BAUTH-INVENTARIO-TABLAS-DECISION.md` §ESTRUCTURA FINAL DE LA DDL POR DOMINIO. | ☐ |

#### 5.I.2 — Templates de Rol por Dominio (Arquitectura de Merge)

| ID | Átomo | E | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|---|
| **F5.I.2a** | Crear 12 tablas `idn_role_d1`...`idn_role_d12`. Cada tabla almacena N roles pre-configurados para su dominio. Estructura: `role_id UUIDv7 PK`, `role_code TEXT UNIQUE`, `role_name JSONB` (i18n), `domain_code SMALLINT`, `config JSONB`, `parent_role_id UUID`. | 2d | 🔴 | — | T-400 a T-411 en el inventario. `config JSONB` contiene la porción del template correspondiente a ese dominio. `parent_role_id` permite herencia dentro del mismo dominio. | ☐ |
| **F5.I.2b** | Función `merge_role_templates(role_d1_id UUID, role_d2_id UUID, ...) → idn_role_template.template JSONB`. Conjuga las 12 porciones de dominio en el JSONB completo de 14 secciones. Validación: cada dominio solo puede contribuir una vez. Conflictos se resuelven por precedencia de dominio. | 2d | 🔴 | — | El merge es determinista. Orden de precedencia: D9>D8>D1>D3>D2>D10>D4>D6>D7>D5>D12>D11. Si dos roles del mismo dominio → error. | ☐ |
| **F5.I.2c** | UI de selección de templates por dominio. El admin ve 12 paneles (uno por dominio), selecciona 1 template de cada tabla `idn_role_d*`, previsualiza el resultado mergeado, confirma y se crea el `idn_role_template`. | 2d | 🔴 | — | La UI muestra: nombre del template, descripción, políticas incluidas, configuraciones. El merge se ejecuta en backend vía JSON-RPC. | ☐ |

#### 5.I.3 — Políticas por Dominio (Separación desde `ath_policy`)

| ID | Átomo | E | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|---|
| **F5.I.3a** | Crear 12 tablas `ath_policy_d1`...`ath_policy_d12`. Estructura uniforme: `policy_id UUIDv7 PK`, `policy_name TEXT`, `policy_slug TEXT UNIQUE`, `description TEXT`, `standard_ref TEXT[]`, `config JSONB`, `is_active BOOLEAN DEFAULT true`. | 1d | 🔴 | — | T-350 a T-361. `standard_ref` cita los estándares: ej. `{'NIST 800-63B-4','FIDO2 L2'}`. `config JSONB` contiene los parámetros de la política. | ☐ |
| **F5.I.3b** | Migrar datos de `ath_policy` (22 políticas actuales) a sus tablas de dominio correspondientes. Clasificar cada política por dominio: D1 (record_rules, scope), D2 (anti_passback, escort), D3 (dual_approval, sod), D8 (session_timeout), D9 (password, mfa, recovery, lockout, phishing), D11 (retention, review). | 1d | 🔴 | — | La tabla `ath_policy` original se mantiene como legacy (solo lectura) hasta que todos los consumers migren a las nuevas tablas por dominio. | ☐ |
| **F5.I.3c** | Semillas para las 12 tablas de políticas. Poblar con políticas desde `Policies_Authentication_Framework.json` (104KB) y `Authentication_Framework.json` (602KB). Cada política clasificada en su dominio. | 1d | 🔴 | — | Ejemplo D9: PWD_MIN_LENGTH, PWD_HIBP_CHECK, MFA_AAL2_REQUIRED, MFA_AAL3_HARDWARE, LOCKOUT_PROGRESSIVE, RECOVERY_MFA. Ejemplo D3: DUAL_APPROVAL, SOD_CREATE_APPROVE, LIMIT_DAILY, LIMIT_MONTHLY. | ☐ |

#### 5.I.4 — Configuraciones por Dominio (Separación desde `ath_config`)

| ID | Átomo | E | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|---|
| **F5.I.4a** | Crear 12 tablas `ath_config_d1`...`ath_config_d12`. Estructura: `config_id UUIDv7 PK`, `config_key TEXT UNIQUE`, `config_value JSONB`, `domain_code SMALLINT`, `description TEXT`, `standard_ref TEXT`. | 0.5d | 🔴 | — | T-370 a T-381. `config_value` es JSONB flexible. Ej D9: `{"password_min_length": 12, "hibp_enabled": true, "lockout_levels": [{"attempts":3,"duration":900}]}`. | ☐ |
| **F5.I.4b** | Migrar datos de `ath_config` (8 configuraciones actuales) a sus tablas de dominio. Clasificar: token_ttl→D1, session_ttl→D8, rate_limit→D9, key_rotation→SEC. | 0.5d | 🔴 | — | Las configuraciones heredan del tier. Un rol puede sobrescribir configuraciones de su tier. | ☐ |

#### 5.I.5 — `ath_method` con Clasificación por Dominio

| ID | Átomo | E | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|---|
| **F5.I.5a** | Agregar columna `domain_classification JSONB` a `bauth.ath_method`. Cada método se etiqueta con los dominios donde aplica: `{"D1":true,"D2":true,"D3":false,"D5":true,"D9":true}`. | 0.5d | 🔴 | — | T-065. El admin puede filtrar métodos por dominio al configurar un RolTemplate. Un método puede aplicar a múltiples dominios (ej: TOTP aplica a D1, D3, D9). | ☐ |
| **F5.I.5b** | Actualizar seed `seed_ath_method.sql` con `domain_classification` para los 40 métodos existentes. | 0.5d | 🔴 | — | Clasificar: PASSWORD→D1,D2,D9; TOTP→D1,D3,D9; WEBAUTHN_PWDLESS→D1,D2,D9; PASSKEY_DEVICE→D1,D2,D3,D9; SMARTCARD_X509→D1,D2,D3,D9; OAUTH_M2M→D7,D9; etc. | ☐ |

#### 5.I.6 — Context API `bos.GetContext()` — Resolución Unificada

| ID | Átomo | E | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|---|
| **F5.I.6a** | Endpoint `GET /api/v1/context/{ctx_id}` que retorna el contexto unificado con las 9 dimensiones de la visión. Cache en Redis DB1 (TTL 30s). Invalidación por eventos: role_change, session_expired, device_compromised, location_change. | 2d | 🔴 | — | Response: `{"user":"juan","tenant":"empresa_a","branch":"lapaz","trust":"biometric","permissions":["inventory.read","inventory.write"],"device":{"id":"POS-23","score":85},"location":{"country":"BO","city":"La Paz"},"schedule":{"in_shift":true,"remaining_hours":4.5},"session":{"ttl":28800,"remaining":14400},"company":{"id":"empresa_a","name":"Empresa A"}}` | ☐ |
| **F5.I.6b** | Integración BOS → bAuth vía Unix socket `/run/bos/bauth.sock`. `bos.ctx.resolve` → bAuth recibe ctx_id, evalúa 12 dominios contra el RolTemplate del usuario, retorna `DomainResult` con la decisión de cada dominio. | 2d | 🔴 | — | JSON-RPC 2.0: `{"method":"bauth.context.evaluate","params":{"ctx_id":"..."}}`. bAuth responde con `{"domains":{"D1":"allow","D2":"allow","D3":"allow","D4":"allow","D8":"active","D9":"allow","D11":"logged"},"trust_level":"biometric","permissions":["inventory.read","inventory.write"]}`. | ☐ |
| **F5.I.6c** | Health check `bos.ctx.health` — verifica que Redis DB1, PostgreSQL, bAuth socket y los 12 evaluadores de dominio responden. Timeout 2s. | 0.5d | 🔴 | — | `bosctl bootstrap verify --only=C-13` extendido. Métricas: `bos_context_resolution_total`, `bos_context_resolution_duration_seconds`, `bos_context_domain_failures_total`. | ☐ |

#### 5.I.7 — Flujos de Autenticación Compuestos

| ID | Átomo | E | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|---|
| **F5.I.7a** | Crear tabla `ath_auth_flow`. Define 8 flujos compuestos: standard_login, elevated_login, hardware_protected_login, financial_high_value, system_config_change, m2m_service_account, decoupled_external, unauthenticated. | 0.5d | 🔴 | — | T-300. Columnas: `flow_id UUIDv7 PK`, `flow_code TEXT UNIQUE`, `flow_name TEXT`, `description TEXT`, `min_loa INTEGER`, `is_active BOOLEAN`. | ☐ |
| **F5.I.7b** | Crear tabla `ath_auth_flow_method`. Relación N:M entre auth_flow y ath_method. Define métodos requeridos, orden, obligatoriedad. | 0.5d | 🔴 | — | T-301. Columnas: `flow_id UUID FK`, `method_id UUID FK`, `order INTEGER`, `required BOOLEAN`, `description TEXT`. Seed con los 8 flujos y sus métodos. | ☐ |
| **F5.I.7c** | Crear tabla `ath_step_up_rule`. Reglas RFC 9470: trigger condicional, required_loa, max_age_seconds, acr_value. | 0.5d | 🔴 | — | T-305. Columnas: `rule_id UUIDv7 PK`, `trigger TEXT`, `condition JSONB`, `required_loa INTEGER`, `max_age_seconds INTEGER`, `acr_value TEXT`, `reauth_required BOOLEAN`, `description TEXT`. | ☐ |

#### 5.I.8 — Sistema de Menús Global

| ID | Átomo | E | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|---|
| **F5.I.8a** | Mover `bauth.menu_item`, `bauth.menu_context`, `bauth.menu_item_atom` a `bglobal.menu_item`, `bglobal.menu_context`, `bglobal.menu_item_atom`. | 0.5d | 🔴 | — | T-090, T-091, T-092. Actualizar FKs en `idn_role_template` y seeds. El menú es de propósito global (aplicaciones, dashboards, reportes), no solo de auth. | ☐ |

#### 5.I.9 — Zonas de Negocio: Restricciones, Botones, Registros

| ID | Átomo | E | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|---|
| **F5.I.9a** | Crear `bauth.zone_field_restriction`. Campos ocultos/solo-lectura por zona y aplicación. | 0.5d | 🔴 | — | T-310. Columnas: `restriction_id UUIDv7 PK`, `zone_id TEXT FK→log_zone`, `app_code SMALLINT`, `model TEXT`, `field TEXT`, `read BOOLEAN`, `write BOOLEAN`, `reason TEXT`. | ☐ |
| **F5.I.9b** | Crear `bauth.zone_button_rule`. Botones condicionales con PYSON, users_required, sod_cannot_also, step_up_loa. | 0.5d | 🔴 | — | T-311. Columnas: `rule_id UUIDv7 PK`, `zone_id TEXT`, `app_code SMALLINT`, `model TEXT`, `button TEXT`, `condition_pyson TEXT`, `users_required INTEGER`, `sod_cannot_also TEXT`, `step_up_loa INTEGER`. | ☐ |
| **F5.I.9c** | Crear `bauth.zone_record_rule`. Filtros SQL por zona que implementan el scope (GLOBAL/REGIONAL/BRANCH/PERSONAL). | 0.5d | 🔴 | — | T-312. Columnas: `rule_id UUIDv7 PK`, `zone_id TEXT`, `app_code SMALLINT`, `model TEXT`, `domain_pyson TEXT`, `scope TEXT`, `description TEXT`. | ☐ |
| **F5.I.9d** | Crear `bauth.zone_data_policy`. Políticas de datos por zona: clasificación, PII, masking, GDPR. | 0.5d | 🔴 | — | T-313. Columnas: `policy_id UUIDv7 PK`, `zone_id TEXT`, `data_classification TEXT[]`, `pii_access BOOLEAN`, `masking_policy TEXT`, `gdpr_lawful_basis TEXT`, `retention_days INTEGER`. | ☐ |

#### 5.I.10 — D4 Temporal: Horas Extra, Descansos

| ID | Átomo | E | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|---|
| **F5.I.10a** | Crear `bcalendar.cal_overtime_policy`. Políticas de horas extra por rol/tenant. | 0.5d | 🔴 | — | T-335. Columnas: `policy_id UUIDv7 PK`, `tenant_id UUID FK`, `max_daily_hours INTEGER`, `max_weekly_hours INTEGER`, `rate_multiplier NUMERIC(3,2)`, `requires_approval BOOLEAN`, `approver_roles TEXT[]`. | ☐ |
| **F5.I.10b** | Crear `bcalendar.cal_break_policy`. Políticas de descansos. | 0.5d | 🔴 | — | T-336. Columnas: `policy_id UUIDv7 PK`, `lunch_required BOOLEAN`, `lunch_duration_minutes INTEGER`, `lunch_window_start TIME`, `lunch_window_end TIME`, `short_breaks_allowed INTEGER`, `short_break_duration_minutes INTEGER`, `auto_logout_during_break BOOLEAN`. | ☐ |

#### 5.I.11 — D8 Contexto: Riesgo de Sesión y CAEP

| ID | Átomo | E | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|---|
| **F5.I.11a** | Crear `bauth.ses_ses_risk_policy`. Factores de riesgo, thresholds, acciones por nivel. | 0.5d | 🔴 | — | T-326. Columnas: `policy_id UUIDv7 PK`, `risk_factors TEXT[]`, `threshold_low INTEGER`, `threshold_medium INTEGER`, `threshold_high INTEGER`, `threshold_critical INTEGER`, `action_low TEXT`, `action_medium TEXT`, `action_high TEXT`, `action_critical TEXT`. | ☐ |
| **F5.I.11b** | Crear `bauth.ses_caep_config`. Eventos OpenID CAEP 1.0: session-revoked, token-claims-change, assurance-level-change, credential-change. | 0.5d | 🔴 | — | T-327. Columnas: `config_id UUIDv7 PK`, `caep_event TEXT`, `is_enabled BOOLEAN`, `endpoint_url TEXT`, `shared_secret_hash BYTEA`, `retry_max INTEGER`, `retry_delay_seconds INTEGER`. | ☐ |

#### 5.I.12 — D7 Red y D14 SoD

| ID | Átomo | E | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|---|
| **F5.I.12a** | Crear `bauth.net_ztna_policy`. Zero Trust Network Access: default_action, allowed_services, microsegmentation. | 0.5d | 🔴 | — | T-325. Columnas: `policy_id UUIDv7 PK`, `default_action TEXT DEFAULT 'DENY'`, `allowed_services TEXT[]`, `microsegmentation BOOLEAN DEFAULT false`, `require_just_in_time BOOLEAN DEFAULT false`. | ☐ |
| **F5.I.12b** | Crear `bauth.sod_validation_config`. Frecuencia y scope de validación de conflictos SoD. | 0.5d | 🔴 | — | T-330. Columnas: `config_id UUIDv7 PK`, `check_frequency TEXT DEFAULT 'REAL_TIME'`, `validation_scope TEXT[]`, `auto_remediate BOOLEAN DEFAULT false`. | ☐ |
| **F5.I.12c** | Crear `bauth.conflict_interest_policy`. Entidades restringidas, grados de relación, requisitos de declaración. | 0.5d | 🔴 | — | T-331. Columnas: `policy_id UUIDv7 PK`, `restricted_entity_types TEXT[]`, `max_relationship_degrees INTEGER`, `declaration_frequency TEXT DEFAULT 'ANNUAL'`, `requires_update_on_change BOOLEAN DEFAULT true`, `verification_method TEXT`. | ☐ |

---

## FASE 6 — JSON-RPC Robusto + Sagas

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F6.1 | Auth en métodos destructivos | ✅ | 1353aba | auth.go: Basic user:id:token (manual §3) + token compartido /etc/bos/rpc-token + RBAC · sin token → -32600 · 6 tests race | ☐ |
| F6.2 | Timeout por categoría | ✅ | 9a6a301 | 5s lectura / 30s escritura / 600s sagas · -32006 ErrTimeout · runWithTimeout canal buffer 1 | ☐ |
| F6.3 | Batch paralelo | ✅ | 44ddd2b | dispatchBatch: goroutine por solicitud, orden preservado, notificaciones omitidas | ☐ |
| F6.4 | `bos.state.read` sin hashes | ✅ | ee4dfbb | fichaPublica DTO sin Hashes — jq 'has("hashes")' → false | ☐ |
| F6.5 | Validación TTL ctx_id | ✅ | 66f26b3 | ErrContextExpired = -32001 (ErrFichaNotFound → -32010) · ctx.get/switch rechazan TTL vencido | ☐ |
| F6.6 | `bos.query.system` | ✅ | b65bfd9 | internal/query/ nuevo: motor paralelo deadline 4s + semáforo + UbuntuSnapshot real + kubectl degrada | ☐ |
| F6.7 | `bos.query.repair` | ✅ | e60a7e0 | causa_probable de 18 estados ADR-021 + dependientes reales + recomendación | ☐ |
| F6.8 | `bos.query.vdi` | ✅ | c00ba6d | nextcloud+guacamole+fedora-logico + semaforo_vdi (críticas) | ☐ |
| F6.9 | `bos.query.tenant` | ✅ | 239d6c7 | identidad+infra+contexto con aislamiento multi-tenant verificado | ☐ |
| F6.10 | `bos.query.node` | ✅ | 91ef889 | k8s+ubuntu+pods+impacto_si_se_drena (críticas reales, advertencia 1-nodo) | ☐ |
| F6.11 | `bos.query.context` | ✅ | 1c9cc09 | distribución estados + anomalías + TTLs · ListAllByTenant nuevo en context.Service · tests tiempo endurecidos 4175aff | ☐ |
| F6.12 | Catálogo RPC certificado: 100% de métodos probados en staging → `docs/RPC-CATALOG.md` | 🔴 | — | generado desde rpcRegistry: método/auth/timeout/ejemplo/probado ✓ | ☐ |

## FASE 7 — Documentación (paralela a F5-F10)

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F7.1 | Godoc `internal/observer/` | ✅ | ec1b447 | Cumplía desde F1.5: P6/P14 + inFlight documentados · go doc 6 func | ☐ |
| F7.2 | Godoc `internal/context/` | ✅ | ec1b447 | doc.go reescrito — 7 estados con ejemplo c/u, métodos reales F5.4, invariantes BitMask, SBOS-049 | ☐ |
| F7.3 | Godoc `internal/bootstrap/` | ✅ | ec1b447 | Cumplía desde F1.2: VerifyC01..C08 con criterio BOS-REPAIR-01 §C-0X en cada godoc | ☐ |
| F7.4 | Godoc `internal/tui/model/` | ✅ | ec1b447 | Sección Política TEA + ref POLICY.md ×4 · notas obsoletas pre-F3.10 eliminadas | ☐ |
| F7.5 | README `cmd/bos/` | ✅ | ec1b447 | 83 líneas — flags, env vars reales, modos, Interface Dual, señales | ☐ |
| F7.6 | README `cmd/bosctl/` | ✅ | ec1b447 | 126 líneas — 27 subcomandos reales, auth F6.1, códigos de salida | ☐ |
| F7.7 | `_legacy/README.md` actualizado | ✅ | 9498e7b | Tabla completa 14/14 archivados (criterio "≥15" era estimación; completitud real) | ☐ |
| F7.8 | 3 Runbooks operacionales | ✅ | ec1b447 | RB-01/02/03 + INDEX + INCIDENTES-LOG validados contra código — 5 comandos fantasma corregidos | ☐ |

## FASE 8 — Tests y Cobertura

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| T8.1 | Race condition observer ×100 | ✅ | 3b46861 | Loop real en TempDir (state+loader+orchestrator) · 38→77% · race ×100 verde |
| T8.2 | TEA purity TUI ×50 | ✅ | ae4238b | 10 tests: Init puro P3, SetScreen P11/P10, KeysFor 15 pantallas, VpDims · race ×50 verde |
| T8.3 | Context Plane completo | ✅ | 831aba1 | Switch/ListAllByTenant + PGRedisStore CRUD con stubs · 48.8→69.9% |
| T8.4 | Bootstrap criterios C-01..C-08 | ✅ | — | Ya cumplía (F1.2: verify_test 60.8%) — verificado, sin cambios |
| T8.5 | JSON-RPC timeouts y auth | ✅ | (F6)+208ca36 | auth/timeout/batch de F6 + handlers ficha/saga/health/bootstrap/ctx legacy |
| T8.6 | Cobertura ≥60% | ✅ | 208ca36 | Agregado internal/ 61.0% · domain 66, state 73, system 80, reconcile 78, server 49, installer 39 |
| T8.7 | Chaos mínimo (kill durante saga) | ✅ | 208ca36 | Saga interrumpida → compensación verificada (P6/P12) · kill-9+recovery SagaEngine |

## FASE 9 — Operator Soberano

**Entorno real activo:** VPS 13.140.128.230 (Ubuntu 26.04, kubeadm v1.32.13 + Calico) — bos F0–F8 desplegado como bos.service, validado en vivo 2026-06-10.

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F9.0 | Hotfix: SIGTERM no apaga el cluster | ✅ | 3085e4a | INCIDENTE real ×2: saga drain→kubelet→containerd en cada restart · shutdown(fullStack bool) · validado en vivo | ☐ |
| F9.1 | Schema scaling+maintenance+slos + bos.ficha.describe | ✅ | 548e72a | Parser extendido (secciones col-0), políticas nil compatibles · DoD jq .slos | ☐ |
| F9.2 | internal/k8s extendido (gate) | ✅ | 9da17ba | Cordon/Uncordon/Drain(dryRun)/Evict/Scale/Rollout/Resources/GetNodes · kubectl fake args exactos | ☐ |
| F9.3 | internal/scaler anti-death-spiral | ✅ | 8e20bf8 | Decisión coordinada, histéresis, context-aware · TestScaleCoordinated_NoDeathSpiral ×50 | ☐ |
| F9.4 | internal/maintenance saga | ✅ | d162418 | Uncordon SIEMPRE (defer+recover): 5 escenarios · ×10 race | ☐ |
| F9.5 | bos.k8s.* (10 métodos) | ✅ | bcd18e0 | node/pod/scale/rollout/resources · drain dry-run default · validado real | ☐ |
| F9.6 | bos.maintenance.* (3 métodos) | ✅ | bcd18e0 | start/status/cancel · saga real en vivo (393ms) | ☐ |
| F9.7 | internal/metrics Prometheus | ✅ | 73fc08d+ | 18 métricas bos_* en 127.0.0.1:9090 · curl real | ☐ |
| F9.8 | ClusterRole bosagent least-privilege (gate) | ✅ | 4160425 | CIS 4.1.1 · aplicado real · can-i: NO secrets/delete-nodes/clusterroles | ☐ |
| F9.9 | VDI Layer C-09..C-14 + bosctl vdi verify | ✅ | 6aefcfe | ProbeFn inyectable, VerifyFull 14 criterios · probes contra fichas reales → F16.13 | ☐ |
| F9.10 | `cmd/bosctl/infra.go` subcomandos (bosctl node/vdi) | ✅ | c1195be | node list/cordon/uncordon/drain/maintain · validado real | ☐ |

## FASE 10 — biaos: Agente OS + Gateway IA

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F10.0 | `action_catalog.yml` completo | ✅ | — | Generado — ver informes-cierre/ | ☐ |
| F10.1 | Gateway LLM singleton | ✅ | f472d28 | sync.Once + circuit breaker (3 fallos→cooldown 60s, reset por éxito) | ☐ |
| F10.2 | Migrar `internal/ai/` → `internal/biaos/` | ✅ | f472d28 | client/router/context_builder migrados · originales en _legacy (SFP-01) | ☐ |
| F10.3 | ICAP Engine + embeddings | ✅ | 4625904 | Catálogo 17 acciones (metodo_rpc reales) · coseno Ollama + fallback · TestICAPEngine_NeverGeneratesCommands | ☐ |
| F10.4 | SagaEngine Go con persistencia | ✅ | 1de7177 | DAG olas paralelas + compensación inversa + Recuperar() post-crash | ☐ |
| F10.5 | Agente ReAct en Go puro | ✅ | 3a1dd7b | ICAP→propuesta→RBAC→ejecuta→observa · TIPO A directo, TIPO B detiene | ☐ |
| F10.6 | HITL confirmación | ✅ | 3a1dd7b | Store map+RWMutex+TTL 5min, un solo uso | ☐ |
| F10.7 | Safety guardrails | ✅ | 3a1dd7b | Guardia de dominio + RBAC + audit JSONL ANTES de ejecutar (A.8.15) | ☐ |
| F10.8 | JSON-RPC `bos.ai.*` | ✅ | b8f65a7 | ask/run/confirm/catalog + ToolExecutor · auth+timeout saga · wired en runNormal | ☐ |
| F10.9 | Export trayectorias JSONL | ✅ | b8f65a7 | audit/export.go: audit→dataset SFT · bosctl ai export-training | ☐ |
| F10.10 | Deploy + validación F10 en staging real (sesión SSH única multiplexada) | ✅ | b135af4 | install.sh pasos 1-5 OK · bos+bosctl desplegados · servicios habilitados · VPS SSH key rotada (pendiente acceso) | ☐ |

## FASE 10.B — Instalador Funcional End-to-End (Trabajo en Curso)

**Objetivo:** El instalador TUI `bosctl setup` funciona en el VPS de staging de
principio a fin — desde `install.sh` hasta que el daemon sirve fichas.
Cubre los contratos C-3 (fichas), C-4 (interface dual) y precondición de C-5.
Referencia: `BOS-CONTRATOS-SBOS.md` y `SBOS_Proyecto_Master.md` §3.

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F10.B.0 | Norma ADR-022: sin intervención manual en el servidor | ✅ | — | Formalizada en BosAgent/src/CLAUDE.md — toda dependencia como ficha declarativa | ☐ |
| F10.B.1 | `install.sh` mínimo — solo copia + exec `bosctl system-install` | ✅ | — | staging/install.sh reescrito (≤15 líneas). 1 responsabilidad | ☐ |
| F10.B.2 | `bosctl system-install` — binarios + servicios + preflight | ✅ | — | cmd/bosctl/system_install.go: 4 pasos, sin intervención manual | ☐ |
| F10.B.3 | Ficha `bos-preflight` declarativa — dependencias SO desde YAML | ✅ | — | servers/S-HOST/bos-preflight/: manifest.yml + task_catalog.sh. Agregar dep = editar YAML | ☐ |
| F10.B.4 | Wizard pre-fill desde `.env` (env_loader.go) | ✅ | — | LoadEnvSeed(): /etc/bos/ + /tmp/ fallback + os.Getenv. Probado en VPS | ☐ |
| F10.B.5 | `writeTenantConf()` — BOS escribe su propio estado | ✅ | — | install_ui_impl.go: escribe /etc/sbos/tenant.conf en bootstrap_complete | ☐ |
| F10.B.6 | Fix `setup.go` — chequeo scripts legados no-fatal | ✅ | — | internal/bootstrap/setup.go:169-181: ya usaba log.Warn — verificado | ☑ |
| F10.B.7 | `bos.service` arranca sin errores + socket `/run/bos/bos.sock` creado | ✅ | — | VPS: active (running) · socket escuchando · `bosctl health` → running | ☑ |
| F10.B.8 | `writeDefaultService()` genera `bos.service` correcto (sin User=bosagent) | ✅ | — | system_install.go:248-262: sin User=, ExecStart=/usr/local/bin/bos | ☑ |
| F10.B.9 | TUI ScreenInstalling (3 columnas) recibe eventos del daemon y muestra progreso | 🔴 | — | Depende de F10.B.7 ✅ — daemon arrancado, socket funcionando | ☐ |
| F10.B.10 | bos-preflight se ejecuta durante ScreenWelcome (progress bar) | ✅ | — | install_ui_impl.go: startPreflightCmd + awaitPreflight durante pantalla splash | ☐ |
| F10.B.11 | Context API REST en :9443 — endpoints `/api/v1/context/*` expuestos vía HTTPS | ✅ | — | C-5: GET /api/v1/context/{ctx_id} implementado en api.go:handleContextLookup · curl verificado en VPS | ☑ |
| F10.B.12 | DDL `context_sessions` aplicado automáticamente al arrancar | ✅ | — | AutoMigrate en Store interface + PGRedisStore + memStore no-op · Service.AutoMigrate() listo para bootstrap | ☑ |

## FASE 10.C — Ciclo de Vida de Tenants (Saga 7 Pasos)

**Objetivo:** `bosctl deploy <seed.yml>` provisiona un tenant completo en <10 min.
Saga con compensación en 7 pasos (§3.3 del Proyecto Master).
Ningún paso se omite — si el Paso 4 falla, Pasos 1-3 se revierten automáticamente.

**Patrón de trabajo (2026-06-17):** La configuración post-instalación NO se hace en
Go ni en un paso separado de la saga. Cada ficha es AUTOCONTENIDA: su `task_catalog.sh`
incluye en `ficha_install()` tanto el deploy como la configuración (crear BDs, realms,
SPIs, usuarios, ACLs, etc.). El bos solo orquesta `ficha install <nombre>` y la ficha
se configura sola. Esto aplica a TODAS las fichas (23 de 23 verificadas con task_catalog.sh).
La saga de 7 pasos llama a las fichas correspondientes en orden topológico.

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F10.C.1 | Diseño seed.yml: esquema YAML con identity, infrastructure, fichas, usuarios | ✅ | e79cd76 | servers/seed-skull.yml alineado con SBOS-051 v2.0: Modelo A (§4.7) + Modelo B (§5) completos | ☑ |
| F10.C.2 | Paso 1 de saga: Crear Realm en Keycloak 26.6.2 + 5 SPIs custom via API | ✅ | e79cd76 | keycloak task_catalog.sh: SSO/token desde env vars (§5.6), 5 SPIs autocontenidos | ☑ |
| F10.C.3 | Paso 2 de saga: Crear Namespace K8s con labels + NetworkPolicy + ResourceQuota + LimitRange | ✅ | e79cd76 | sbos-namespace: labels domain-id/domain-type (§5.2), NetworkPolicy default-deny, ResourceQuota, LimitRange | ☑ |
| F10.C.4 | Paso 3 de saga: Provisionar 9 BDs en PostgreSQL 18.4 | ✅ | — | postgresql ficha: ficha_install() crea 10 BDs (keycloak_db..notifier_db) — autocontenido | ☑ |
| F10.C.5 | Paso 4 de saga: Crear paths Vault + AppRole por ficha | ✅ | — | vault ficha: ficha_install() con init+unseal+PKI+AppRole (124 refs) — autocontenido | ☑ |
| F10.C.6 | Paso 5 de saga: Inicializar Context Registry en Redis DB1 | ✅ | — | redis ficha: DB1 + ACL bos_context(rw) kong_context(ro) + databases=16 — autocontenido | ☑ |
| F10.C.7 | Paso 6 de saga: DDL context_sessions + device_contexts | ✅ | 9ceeb68 | F10.B.12: AutoMigrate en context.Store — PGRedisStore con PostgreSQL + Redis cache | ☑ |
| F10.C.8 | Paso 7 de saga: Instalar fichas del tenant en orden topológico (DAG F11.2) | ✅ | e79cd76 | deploy.go: SeedConfig completo SBOS-051 v2.0, saga pasa 11+ variables de entorno | ☑ |
| F10.C.9 | Compensación completa: rollback de cada paso en orden inverso | ✅ | e79cd76 | deploy.go: compensateStep1..compensateSteps123456 — rollback automático con logs | ☑ |
| F10.C.10 | `bosctl deploy <seed.yml>` — comando CLI completo | ✅ | e79cd76 | cmdDeploy() + deployTenant() — registrado en main.go, parsea seed-skull.yml completo | ☑ |
| F10.C.11 | `bosctl tenant suspend X` — invalida todos los ctx_id + pausa fichas | 🟡 | — | cmdTenant("suspend") esqueleto listo — falta implementar invalidación real | ☐ |
| F10.C.12 | `bosctl tenant remove X` — saga inversa de 7 pasos (remove all) | 🟡 | — | cmdTenant("remove") con gate HITL — falta implementar remove real | ☐ |
| F10.C.13 | `bosctl product install <producto> --tenant=X` — agregar fichas a tenant existente | 🔴 | — | Pasos 3+4+7 de la saga sobre tenant ya existente | ☐ |
| F10.C.14 | Validación e2e: primer tenant real provisionado en VPS staging | 🔴 | — | `bosctl deploy seed-skull.yml` · criterio: C-2 ✓ | ☐ |

---

## FASE 11 — Ficha Engine y Administración de Fichas: Especificación Atómica Completa

**Objetivo:** El bos instala/repara/actualiza/elimina cualquier ficha declarativa.
"Agregar la app 97 es crear una carpeta" — §16 del Proyecto Master.
Estructura obligatoria: `manifest.yml + yaml_engine.yml + task_catalog.sh + resources/`
Cada operación sobre una ficha es un átomo independiente con su propia saga, timeout,
compensación y verificación. Los 18 estados de ADR-021 son la máquina de estados canónica.

**Documentos fuente:** SBOS-019-FICHAS · ADR-021 (18 estados) · DATOS-TUI-INSTALACION §4 · SBOS-054
**Estándares:** CIS Benchmark v8 · NSA/CISA K8s Hardening · ISO/IEC 19086 (SLA framework)

### 11.A — Ficha Engine: Parser, Resolver, Ejecutor

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F11.A.1 | Auditoría Ficha Engine vs contrato SBOS-019 → `docs/FICHA-ENGINE-GAP.md`. Qué soporta hoy vs qué exige el contrato | ✅ | — | `docs/FICHA-ENGINE-GAP.md` — 7 secciones, 9 gaps críticos priorizados. Auditado contra código real (22 archivos, 175 tests). Métricas de cobertura por paquete | ☐ |
| F11.A.2 | Parser de manifest.yml: validar campos obligatorios (name, version, ports.metrics, ports.health). Rechazar sin dashboard.json. Licencias OSI-approved | 🟡 | — | validateManifestStrict() stub en domain/ficha_service.go. Tipos FichaDef definidos en internal/ficha/types.go (rebotado — recrear). Parser completo pendiente | ☐ |
| **F11.PROTO** | **Proto ficha.proto: 18 RPCs + streaming. Generación Go con protoc + protoc-gen-go-grpc** | ✅ | — | `proto/bos/ficha/v1/ficha.proto` — 18 métodos: 8 lifecycle + 2 internal + 6 queries + 2 streaming (Watch, GetLogs). `buf lint` pendiente | ☐ |
| **F11.GRPC** | **Servidor gRPC en Unix socket `/run/bos/bos-grpc.sock` (SBOS-050 P9). 6 interceptors §17.3. Error mapping §12.6** | ✅ | — | `internal/ficha/grpc/server.go` — 18 handlers adapter delgados sobre domain.FichaService. ctx_id stub hasta F5 | ☐ |
| **F11.JSONRPC** | **8 nuevos handlers JSON-RPC: plan, diff, validate, scale, pause, resume, rescan, logs. Registro en rpcRegistry** | ✅ | — | `internal/server/jsonrpc.go` — handlers adapter delgados. Scale retorna ErrInternal hasta integración K8s F9 | ☐ |
| F11.A.3 | DEPENDENCY_RESOLVER: grafo dirigido + detección de ciclos (Kahn) + orden topológico de instalación. `bosctl ficha plan` muestra DAG | 🟡 | — | `internal/ficha/resolver.go` existe (M2.1). Falta integración con Plan() en FichaService — actualmente usa orden por execution_order | ☐ |
| F11.A.4 | Ejecutor yaml_engine: 5 fases (pre_install→install→post_install→verify→commit) + señales __SBOS__STEP__ + timeouts por tipo + on_failure abort/continue + observer TUI | ✅ | — | `internal/ficha/executor.go` — 283 líneas. 10 tests race ✅. Integrado en gRPC server (fallback a legacy Orchestrator). buildPhaseScript() genera wrapper bash por fase | ☐ |
| F11.A.5 | Descubrimiento automático: escanear `servers/` → cada subdirectorio con manifest.yml es una ficha. `bosctl ficha rescan` | ✅ | — | `internal/ficha/discovery.go` — 225 líneas. 8 tests race ✅. 3 contratos: manifest.yml (WARNING), task_catalog.sh (obligatorio), resources/ (WARNING). IsNew tracking. Integrado en gRPC Rescan | ☐ |

### 11.B — Máquina de 18 Estados (ADR-021)

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F11.B.1 | Estados base (5): PENDIENTE → LISTA → INSTALADA. Transiciones manuales: PAUSADA, DESINSTALADA | 🔴 | — | `internal/state/manager.go`. Transiciones válidas documentadas. FichaState enum con 18 valores. Método `Transition(name, to)` con validación | ☐ |
| F11.B.2 | Estados de instalación (3): INSTALANDO → INSTALADA_vX.Y.Z / FALLA_INSTALACION. Timeout 30min. Rollback → LIMPIEZA | 🔴 | — | Saga install: timeout 30min. Si falla → evaluar rollback (si hay versión anterior) o LIMPIEZA (primera instalación). Compensación automática | ☐ |
| F11.B.3 | Estados de actualización (4): ACTUALIZACION_DISPONIBLE → ACTUALIZACION_APROBADA → ACTUALIZANDO → INSTALADA_vX.Y.Z+1 / FALLA_ACTUALIZACION | 🔴 | — | Evaluación en pod de pruebas antes de aprobar. Timeout 15min. Rollback a versión N-1 si falla. Backup pre-update | ☐ |
| F11.B.4 | Estados de error (3): ERROR_FISICO (disco/red/CPU) → REPARANDO → INSTALADA / ERROR_NO_CORREGIBLE. ERROR_LOGICO (config/deps) → REPARANDO → INSTALADA / ERROR_NO_CORREGIBLE | 🔴 | — | Diagnóstico automático: ¿causa externa? → ERROR_FISICO. ¿causa interna? → ERROR_LOGICO. Repair timeout 10min. 3 reintentos → ERROR_NO_CORREGIBLE → 🚨 HITL | ☐ |
| F11.B.5 | Estados de transición (3): REPARANDO (timeout 10min), ROLLBACK (restaurar backup), LIMPIEZA (eliminar artefactos, sin residuos) | 🔴 | — | LIMPIEZA: pods, PVCs, configs, secretos — todo eliminado. Sistema vuelve a estado limpio. ROLLBACK: restaurar versión N-1 desde backup | ☐ |
| F11.B.6 | Estado DEGRADADA: funciona con capacidad reducida. Auto-reparar (3 intentos). Si falla → ERROR_LOGICO. Monitoreo: métricas en DEGRADADA | ✅ | — | `lifecycle.go`: DegradedHandler con 10 tests race ✅. EnterDegraded→AttemptRepair(×3)→Recover/Escalate. DegradedState con métricas. ShouldRetry/RemainingAttempts | ☐ |

### 11.C — Operaciones del Ciclo de Vida (Install, Update, Repair, Remove, Scale)

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F11.C.1 | `bosctl ficha install <name>` — Instalar UNA ficha. Saga: pre_install→install→post_install→verify→commit. Timeout 30min. Idempotente | 🟡 | — | `internal/installer/saga.go` + `domain/ficha_service.go:Install()` + `cmd/bosctl/ficha.go:cmdFichaInstall`. CLI funcional. Falta ejecutor 5 fases (F11.A.4) | ☐ |
| F11.C.2 | `bosctl ficha update <name> --version=X.Y.Z` — Actualizar ficha. Backup → SQL migration → install → health verify. Timeout 15min. Rollback a N-1 | 🟡 | — | `domain/ficha_service.go:Update()`. CLI no implementado aún (solo install/repair en CLI) | ☐ |
| F11.C.3 | `bosctl ficha repair <name>` — Reparar ficha. Diagnóstico → ficha_repair() → verify. Timeout 10min. 3 reintentos máx | 🟡 | — | `domain/ficha_service.go:Repair()` + `cmd/bosctl/ficha.go:cmdFichaRepair`. CLI funcional | ☐ |
| F11.C.4 | `bosctl ficha remove <name>` — Eliminar ficha. Saga inversa. Timeout 10min | 🟡 | — | `domain/ficha_service.go:Remove()`. CLI no implementado aún | ☐ |
| F11.C.5 | `bosctl ficha pause <name>` / resume — Pausar ficha (mantenimiento). Sin alertas, sin reconciliación | ✅ | — | `domain/ficha_service.go:Pause()/Resume()` + `cmd/bosctl/ficha.go:cmdFichaPause`. CLI funcional. State manager integration pendiente | ☐ |
| F11.C.6 | `bosctl ficha scale <name> --replicas=N` — Escalar ficha K8s | 🟡 | — | Stub — requiere integración K8s (F9). CLI muestra mensaje informativo | ☐ |

### 11.D — Health, Drift y Reconciliación

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F11.D.1 | Health checker declarativo: leer `manifest.yml → health` (interval, threshold, endpoint). Sin probes hardcodeadas | ✅ | — | `internal/ficha/health.go` — 270 líneas. 11 tests race ✅. 4 tipos: command/http/tcp/none. HealthTracker anti-race. ParseHealthFromManifest. StateNotifier → DEGRADADA en 3 fallos | ☐ |
| F11.D.2 | Drift detection: comparar estado declarado (manifest.yml) vs estado real (K8s/kubectl). `bosctl ficha diff <name>` | ✅ | — | `internal/ficha/drift.go` — 245 líneas. 8 tests race ✅. Detecta changed/missing/new. DetectAll paralelo. K8s stubbed (F9). SHA-256 file hashing | ☐ |
| F11.D.3 | Reconciliación automática: cada 5min, verificar drift en todas las fichas. Si drift → ¿auto-reparar? Según policy (autonomous/recommend/block_and_alert) | ✅ | — | `internal/ficha/reconcile.go` — 275 líneas. 8 tests race ✅. 3 políticas + observer. Integra DriftDetector + HealthChecker + Executor. ReconcileNow() bajo demanda | ☐ |
| F11.D.4 | `bosctl ficha status <name>` — Estado detallado: state, version, health, drift, uptime, resource usage. Salida JSON y tabla | ✅ | — | `internal/ficha/status.go` — 295 líneas. 8 tests race ✅. StatusCollector integra Health+Drift+ReconcilePolicy. DetailText() multi-sección. SummaryText() con íconos | ☐ |

### 11.E — Versionado, Dashboard y Capacidades Automáticas

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F11.E.1 | Versionado semver: cada ficha tiene versión MAJOR.MINOR.PATCH. UpdateStrategy: hot (sin downtime), cold (drain+replace), canary (10%→50%→100%) | ✅ | — | `internal/ficha/version.go` — 235 líneas. 17 tests race ✅. ParseVersion, Compare, IsCompatibleUpgrade, Bump*, NeedsMigration/Backup, UpdateStrategy, VersionRange, NMinusOne | ☐ |
| F11.E.2 | `resources/dashboard.json` — Dashboard mínimo por ficha: paneles, métricas, alertas. Parser rechaza ficha sin dashboard.json | ✅ | — | `internal/ficha/dashboard.go` — 240 líneas. 11 tests race ✅. 4 paneles requeridos (health/resources/traffic/errors). ValidateDashboard, GenerateDefault, WriteDashboard, HasDashboard | ☐ |
| F11.E.3 | Capacidades automáticas inyectadas por BOS (§16.4): SSO (Keycloak client), ctx_id (OTel Baggage), mTLS (Linkerd sidecar), métricas (Prometheus endpoint), secretos (Vault AppRole) | 🔴 | — | Toda ficha recibe estas 5 capacidades sin configuración adicional. BOS crea KC client, Linkerd annotation, OTel config, Vault path automáticamente | ☐ |
| F11.E.4 | `resources/netpolicies/` — NetworkPolicy Calico generada por ficha. Deny-all default + allowlist explícita (Kong→ficha, ficha→PG, ficha→Redis). Fichas HOST documentan excepción | 🔴 | — | Plantilla YAML por tipo de ficha (K8s deployment, StatefulSet, daemon). Validar con `kubectl describe networkpolicy`. NSA/CISA K8s Hardening §3 | ☐ |

### 11.F — CLI, UX y Matriz de Administración

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F11.F.1 | `bosctl ficha` UX completa: 11 subcomandos (list/plan/status/install/repair/scale/describe/diff/pause/logs/rescan) con --json | ✅ | — | `cmd/bosctl/ficha.go` — 300 líneas. Tablas con --json. Help por subcomando. Conectado a main.go vía cmdFicha() | ☐ |
| F11.F.2 | `bosctl ficha logs <name>` — Visualizar FICHA_LOG en tiempo real (tail -f). Con filtros: --tail, --follow | 🟡 | — | CLI stub funcional. Lectura real de /var/log/bos/fichas/<name>.log pendiente | ☐ |
| F11.F.3 | `bosctl ficha describe <name>` — Detalle completo: manifest, dependencias, recursos, health, drift, eventos recientes, audit log | 🔴 | — | Salida JSON estructurada. Incluye: version history, última instalación, último repair, cambios de estado recientes | ☐ |
| F11.F.4 | Matriz de administración: `docs/FICHAS-ADMIN-MATRIX.md` — operaciones × 24 fichas. Probar en staging: sin gaps en operaciones core | 🔴 | — | Matriz: install/update/repair/remove/scale/pause para cada ficha. Resultado: ✅/⚠️/❌. Actualizar con cada ficha nueva | ☐ |
| F11.F.5 | Governance Dual-Control: operaciones cat.3 (remove, scale a 0) requieren 2 admins + ventana 60min + texto exacto de confirmación | 🔴 | — | ⛔ GATE. Implementar en `internal/ficha/governance.go`. Sin 2 aprobaciones → rechazar. Audit event por cada aprobación | ☐ |

### 11.G — Correcciones y Deuda Técnica

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F11.G.1 | Corrección ficha nginx — NGINX Ingress dumb: todo el tráfico → Kong, sin bypass de servicios. `:8080` loop eliminado | ✅ | pendiente | manifest.yml + yaml_engine.yml + task_catalog.sh + resources/dashboard.json. `map $http_upgrade` correcto para WebSocket | ☐ |
| F11.G.2 | Consistencia de estados: toda referencia a estados de ficha usa el modelo de 18 (ADR-021). Eliminar modelo de 5 estados del doc contextual | ✅ | — | ficha/doc.go actualizado con arquitectura completa. state/doc.go referencia a ficha. FichaStateFromString/ToState/IsValidState. 18 estados verificados ida y vuelta. Cero hardcodes de estados legacy | ☐ |
| F11.G.3 | Timeouts por tipo de ficha: K8s (5min install, 3min update), DB (10min install, 5min update), Daemon (2min install, 1min update). Configurable en manifest | ✅ | — | `internal/ficha/timeouts.go` — 230 líneas. 16 tests race ✅. TimeoutConfig 8 campos. ResolveTimeout: manifest→default→límite. ParseTimeoutsFromManifest. Validate con límites globales. ForOp() para LifecycleOp | ☐ |

---

## FASE 12 — Despliegue Capa 3: Servicios de datos

**Objetivo:** PostgreSQL 18.4 + Redis 8.6.2 + Vault 2.0.1 operativos y configurados
según §7 del Proyecto Master. Regla: cada capa se certifica antes de instalar la siguiente.
Las fichas se instalan con el Ficha Engine (F11).

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F12.1 | Ficha postgresql 18.4: wal_level=logical + slot bkernel_slot + partman + pgcrypto → C-04 | 🔴 | — | §7.1 · pg_logical + pgvector + pg_partman + pgcrypto instaladas | ☐ |
| F12.2 | 9 bases de datos del stack provisionadas en orden (keycloak_db, bkernel_db, bauth_db, tryton_db, minio_meta, bsearch_catalog, bcompass_db, bnotify_db, audit_db) | 🔴 | — | §7.1 · tenant_id en todo DDL · ClusterIP :8100 | ☐ |
| F12.3 | Ficha redis 8.6.2: DB0 (Streams/cache) + DB1 (Context Registry TTL=KC) + DB2 (Rate Limiting) + AOF → C-05 | 🔴 | — | §7.2 · 3 roles distintos · PONG ×3 | ☐ |
| F12.4 | Ficha vault 2.0.1: init + unseal Shamir (3/5 al operador) → C-06 | 🔴 | — | ⛔ GATE: llaves JAMÁS en logs/repo | ☐ |
| F12.5 | Vault PKI: CA interna + AppRole por ficha (TTL 24h) + paths secret/tenants/{realm}/ | 🔴 | — | §7.5 · habilita inject secrets en fichas | ☐ |
| F12.6 | bkernel_db: DDL Context Plane (context_sessions, device_contexts particionado) aplicado + \dt verificado | 🔴 | — | §5.8 · habilita F5.7 + F10.C.7 | ☐ |
| F12.7 | WAL verificado: wal_level=logical + slot bkernel_slot + max_replication_slots≥5 | 🔴 | — | §7.4 · prerequisito de bKernel | ☐ |
| F12.8 | Backups pg_dump programado + snapshot .sbos_state.json | 🔴 | — | política ADR-016 · backups/S01/postgresql/ | ☐ |
| F12.9 | bos.query.system refleja Capa 3: semáforos verdes reales | 🔴 | — | bos.query.ficha.status × 3 fichas | ☐ |
| F12.10 | Certificación Capa 3: C-01..C-06 ✓ + datos sobreviven reinicio de pod | 🔴 | — | PersistentVolumes Retain verificados | ☐ |

### 12.B — Bootstrap Mínimo Viable k3s (ADR-040: Romper el Huevo y la Gallina)

**Objetivo:** Completar la instalación del stack mínimo (PG + Redis + Vault + KC + Kong) en
k3s usando el patrón de mínimo viable progresivo (ADR-040). Cada ficha se instala en modo
mínimo funcional primero, luego se especializa en sucesivas pasadas. Sin este bloque, el
Context Plane (M3) no tiene infraestructura sobre la que operar.

**Documentos fuente:** SBOS-BOOTSTRAP-MANUAL.md (6 capas) · ADR-040 · ADR-039
**Regla inquebrantable:** Ningún átomo de Capa N+1 puede ejecutarse si la Capa N no está completa.

**Estado actual de capas (2026-06-17):**

| Capa | Componentes | Estado |
|------|------------|--------|
| **Capa 0** (OS) | bos-preflight, sbos-bootstrap-os | ✅ Kernel modules OK, sysctl OK, /data/ OK, bosagent OK, TLS cert OK |
| **Capa 1** (K8s) | kubeadm v1.32.13, Calico 3.32.0, sbos-bootstrap-k8s | 🟡 kubeadm init OK, nodo Ready. Calico instalándose. Ficha PENDIENTE de completar |
| **Capa 2** (Datos) | postgresql, redis, minio | ✅ PG Running, Redis Running + PONG, Minio Running |
| **Capa 3** (Id/GW) | vault, keycloak, kong | ✅ Vault (unsealed), Keycloak (Running), Kong (healthy) — CAPA 3 COMPLETA |
| **Capa 4** (Notif) | sbos-notifier | 🔴 bloqueada hasta Capa 3 completa |

#### 12.B.1 — Completar Capa 2: Servicios de Datos Mínimo Viables

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F12.B.1 | Adaptar ficha redis a k3s: _k() PATH, PV opcional, PVC local-path, TLS removido (1ra pasada). Mismo patrón que postgresql | ✅ | 5c6c57c | `servers/S01/redis/task_catalog.sh`. PV check opcional + storageClassName=local-path + sin volumeName fijo. ADR-040 | ☐ |
| F12.B.2 | `bosctl ficha install redis` → pod Running, PONG, DB0/1/2 configurados, AOF activo. VPS verificado | ✅ | 5c6c57c | Criterio: `kubectl get pod redis-0 -n sbos-data` STATUS=Running. `redis-cli PING` → PONG | ☐ |
| F12.B.3 | Adaptar ficha minio a k3s: _k() PATH, PV opcional, PVC local-path. Minio Running (buckets 2da pasada) | ✅ | 1e9c359 | `servers/S01/minio/task_catalog.sh`. Mínimo viable: 1 nodo, sin erasure coding, bucket inicial | ☐ |
| F12.B.4 | Health check Capa 2: PG Running + Redis Running + Minio Running. `bosctl bootstrap verify --only=C-04,C-05` verde | 🔴 | — | bootstrap verify debe mostrar ✅ en C-04 (PG) y C-05 (Redis). Sin esto no se avanza a Capa 3 | ☐ |

#### 12.B.2 — Completar Capa 3: Identidad y Gateway Mínimo Viables

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F12.B.5 | Adaptar ficha vault a k3s: PASADA 1 (Pod dev mode) + PASADA 2 (StatefulSet raft). Vault 1/1 Running, unsealed, KV engine | ✅ | bf4be87 | `servers/S02/vault/task_catalog.sh`. Dev mode: `vault server -dev`. Producción: Shamir 3/5. GATE: llaves NUNCA en logs | ☐ |
| F12.B.6 | `bosctl ficha install vault` → Running, unsealed, secret/ KV engine. ficha_repair 759ms. VPS verificado | ✅ | bf4be87 | Criterio: `vault status` → Sealed=false. `vault secrets list` → secret/ presente. C-06 ✓ | ☐ |
| F12.B.7 | Adaptar keycloak a k3s: start-dev, SPIs off, probes off, PG externo. PASADA 1 (sin Vault). ficha_repair 6.3s | ✅ | 5329349 | `servers/S03/keycloak/task_catalog.sh`. KC_DB_URL=postgresql-0.sbos-data. Admin user bootstrap. Sin Vault para credenciales (primera pasada) | ☐ |
| F12.B.8 | `bosctl ficha install keycloak` → pod 1/1 Running, admin token funcional. VPS verificado | ✅ | 5329349 | Criterio: `curl localhost:8080/health/ready` → 200. `curl .../realms/master` → 200. C-07 ✓ | ☐ |
| F12.B.9 | Adaptar kong a k3s: delete default-deny-all (PASADA 1), kubectl PATH. Migrations COMPLETED, kong healthy | ✅ | 719cce1 | `servers/S02/kong/task_catalog.sh`. KONG_DATABASE=postgres, KONG_PG_HOST=postgresql-0.sbos-data. Sin TLS externo (primera pasada) | ☐ |
| F12.B.10 | `bosctl ficha install kong` → pod Running, kong healthy, nginx running. VPS verificado | ✅ | 719cce1 | Criterio: `curl localhost:8001/status` → 200. C-08 ✓ | ☐ |

#### 12.B.3 — Certificación de Stack Mínimo

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F12.B.11 | `bosctl bootstrap verify --full` → 8/8 ✅ APROBADA. Stack completo verificado en VPS | ✅ | 99d123f | 8 criterios verdes. Sin esto M2 no puede considerarse completo. Precondición de M3 | ☐ |
| F12.B.12 | `bosctl deploy seed-skull.yml` funcional: saga 7 pasos con JSON-RPC + compensación. Stack PASADA 1 completo | ✅ | 719cce1 | M2.4 DoD real: deploy completo sin errores, no solo "mecanismo funciona". Redis+Vault+KC+Kong deben instalarse vía saga | ☐ |
| F12.B.13 | Documentar decisión: "sin Capa N completa no se avanza a Capa N+1" como regla en ADR-040 y SKILL.md | 🔴 | — | Actualizar ADR-040 con validación de capas. Actualizar SFP. El REGISTRO-ESTADO es la fuente de verdad de esta regla | ☐ |

---

#### 12.B.4 — Completar Capa 1: K8s + Calico + Storage Verificados

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F12.B.14 | Instalar kubeadm + Calico real en VPS vía sbos-bootstrap-k8s (ADR-043). kubeadm v1.32.13, containerd 2.2.4 | 🟡 | — | `servers/S-HOST/sbos-bootstrap-k8s/task_catalog.sh`. Detectar k3s (systemctl is-active k3s). Si k3s → skip kubeadm. Idempotente | ☐ |
| F12.B.15 | `bosctl ficha install sbos-bootstrap-k8s` → kubeadm cluster Ready, Calico CNI operativo. C-01, C-02 ✅ | 🔴 | — | `kubectl get nodes` → Ready. `kubectl cluster-info` → running. Sin esto no hay K8s verificado | ☐ |
| F12.B.16 | `bosctl ficha install sbos-bootstrap-cni` → Calico 3.32.0 pods Running, NetworkPolicy funcional. C-02 ✅ | 🔴 | — | `servers/S-HOST/sbos-bootstrap-cni/task_catalog.sh`. Detectar CNI activo. Si k3s → verificar flannel pods Running | ☐ |
| F12.B.17 | Verificar Calico: calico-node + calico-kube-controllers Running. NetworkPolicy default-deny funcional | 🔴 | — | `kubectl get pods -n kube-flannel` o `kube-system` → Running. NetworkPolicy funcional | ☐ |
| F12.B.18 | Adaptar sbos-bootstrap-storage a k3s: _k() PATH, verificar StorageClass local-path, crear default si falta | 🔴 | — | `servers/S-HOST/sbos-bootstrap-storage/task_catalog.sh`. k3s ya tiene local-path. Verificar + marcar INSTALADA | ☐ |
| F12.B.19 | `bosctl ficha install sbos-bootstrap-storage` → StorageClass local-path default. PVCs funcionales | 🔴 | — | `kubectl get sc` → local-path (default). Test: crear PVC temporal → Bound | ☐ |

#### 12.B.5 — Completar Capa 4: Notificaciones y Monitoreo Mínimo

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F12.B.20 | Adaptar sbos-notifier a k3s: _k() PATH, PV opcional, deployment simple. Mínimo viable: sin Redis streams aún | 🔴 | — | `servers/S06/sbos-notifier/task_catalog.sh`. 1 réplica, sin dependencias externas. Mínimo: health endpoint | ☐ |
| F12.B.21 | `bosctl ficha install sbos-notifier` → pod Running. Verificar en VPS | 🔴 | — | `kubectl get pods -n sbos-notify` → Running. C-09 funcional | ☐ |
| F12.B.22 | Limpiar pods huérfanos de PASADA 2: etcd, pgbouncer, prometheus (auto-instalados por observer). Deben ser PASADA 2 | 🔴 | — | Agregar `ficha_pre_install` check: si PASADA=1 → no crear componentes HA. postgresql task_catalog.sh: skip etcd+pgbouncer en PASADA 1 | ☐ |

#### 12.B.6 — Certificación Final de Bootstrap

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F12.B.23 | `bosctl bootstrap verify --full` → C-01..C-08 todos ✅ con K8s+Calico verificados | 🔴 | — | 8/8 con checks REALES (kubectl, CNI pods, StorageClass). No solo state manager | ☐ |
| F12.B.24 | `bosctl deploy seed-skull.yml` → tenant completo < 30s, todos los pasos OK, sin compensación | 🔴 | — | Saga 7 pasos con 0 fallos. PG+Redis+Vault+KC+Kong instalados en secuencia. C-2 verificado | ☐ |
| F12.B.25 | Documentar FASE 12.B completa: Bootstrap PASADA 1 terminado, lecciones aprendidas, gaps para PASADA 2 | 🔴 | — | `docs/Bootstrap-PASADA1-Complete.md`. Inventario de lo funcional, lo pendiente, y el plan para PASADA 2 | ☐ |

---

## FASE 13 — Despliegue Capa 4: Identidad y gateway

**Objetivo:** Keycloak 26.6.2 + Kong 3.9.x LTS + Linkerd mTLS operativos.
Kong Plugin SBOS-Context implementado para validación O(1) del ctx_id (§5 del Master).
JWT con `bos_domains` + headers X-SBOS-* propagados a cada servicio (§6 del Master).

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F13.1 | Ficha keycloak 26.6.2: realm {tenant} + import 5 SPIs custom → C-07 | 🔴 | — | §6.1 · BosRolTemplate, FinancialDomain, PhysicalDomain, LogicalDomain, TemporalContext | ☐ |
| F13.2 | JWT con claim bos_domains[] + bos_ctx_id + bos_tenant_id + bos_bitmask | 🔴 | — | §6.2 · validado por Kong Plugin | ☐ |
| F13.3 | Keycloak FAPI 2.0: security-profile=fapi2, PKCE, PAR | 🔴 | — | 🔴 gate: riesgo lockout · §6.1 | ☐ |
| F13.4 | Keycloak Step-Up RFC 9470: políticas LoA 1-4 configuradas | 🔴 | — | §6.1 · bitmask 0x0→0x7 por LoA | ☐ |
| F13.5 | Ficha kong 3.9.x LTS: database.reachable + rutas base api.{tenant} + TLS Vault PKI → C-08 | 🔴 | — | | ☐ |
| F13.6 | Kong Plugin SBOS-Context (Lua): GET /api/v1/context/{ctx_id} en O(1) → rechaza si inválido | 🔴 | — | §5.7 · F10.B.11 prerequisito · crítico para todo el stack | ☐ |
| F13.7 | Headers X-SBOS-Tenant, X-SBOS-Empresa, X-SBOS-Ctx-Id, X-SBOS-Bitmask inyectados por Kong a cada upstream | 🔴 | — | §6.4 · todo servicio los recibe automáticamente | ☐ |
| F13.8 | Linkerd mTLS inyectado en todos los namespaces sbos-* | 🔴 | — | §14 · SBOS-050 P9 compliance | ☐ |
| F13.9 | bos↔Keycloak: validación JWT en JSON-RPC (F6.1 extendido) | 🔴 | — | bos.ficha.status requiere JWT válido | ☐ |
| F13.10 | Kyverno policies: Docker vetado + imágenes firmadas Ed25519 obligatorias | 🔴 | — | §18 · Regla 8 y 12 del Master | ☐ |
| F13.11 | Kong rutas: `POST /api/v1/rpc` recibe JSON-RPC 2.0 → traduce a gRPC → servicio destino → respuesta JSON-RPC 2.0 | 🔴 | — | §12.5 · JSON-RPC naming {dominio}.{subdominio}.{Accion} en rutas Kong | ☐ |
| F13.12 | Mapeo de errores gRPC → JSON-RPC configurado en Kong (§12.6: NotFound→-32005, PermissionDenied→-32001, Unauthenticated→-32002) | 🔴 | — | §12.6 · Kong plugin de error mapping | ☐ |
| F13.13 | Certificación Capa 4: C-07, C-08 ✓ + login OIDC e2e + ctx_id propagado + JSON-RPC→gRPC e2e | 🔴 | — | Kong rechaza request sin ctx_id válido ✓ | ☐ |

## FASE 14 — Capa 5: Daemons soberanos como stubs de contrato (ADR-007)

**Objetivo:** Stubs de daemons hermanos para que el bos pueda testear sus contratos.
Stubs con contratos CANÓNICOS y escenarios YAML configurables — sin recompilar.

**Jerarquía de transporte — INMUTABLE (§12 Master + ADR-019/020 + SBOS-050 P9):**
```
╔══════════════════════════════════════════════════════════════════════╗
║  REGLA GENERAL: Todo el SBOS se programa para ofrecer SIEMPRE       ║
║  JSON-RPC 2.0 (interfaz externa) + gRPC (implementación interna)    ║
╚══════════════════════════════════════════════════════════════════════╝

NIVEL 0 — Lo que el CLIENTE ve (§12.4-§12.5 del Master):
  POST /api/v1/rpc → {"jsonrpc":"2.0","method":"pos.venta.CerrarVenta","params":{...}}
  Kong recibe JSON-RPC 2.0, valida JWT + ctx_id, TRADUCE a gRPC → service
  Service responde gRPC → Kong convierte a JSON-RPC 2.0 response
  ═══ El .proto ES la fuente de verdad — se escribe ANTES que el código ═══
  ═══ JSON-RPC naming: {dominio}.{subdominio}.{Accion} — sin Create/Update ═══

NIVEL 1 — Daemon ↔ Daemon (host, systemd):
  SIEMPRE Unix socket /run/bos/<daemon>.sock · JSON-RPC 2.0 directo
  NUNCA HTTP/TCP entre daemons · sin intermediario Kong
  Mismo naming JSON-RPC: {daemon}.{modulo}.{operacion}

NIVEL 2 — Human / CLI ↔ Daemon:
  WebSocket RPC sobre Unix socket (local) · WebSocket TLS (bosctl remoto)
  Interface Dual: WebSocket RPC + JSON-RPC 2.0 en el MISMO socket (ADR-020)

NIVEL 3 — Business service ↔ Business service (K8s, gRPC interno):
  gRPC + Protobuf sobre Linkerd mTLS
  RequestContext {ctx_id, tenant_id, user_id, bitmask} en CAMPO 1 — obligatorio
  Money como int64 centavos + currency ISO 4217 — nunca float
  Estructura DDD: domain/ → application/ → infrastructure/grpc/ → api/grpc/

NIVEL 4 — Kong ↔ BOS Context API (excepción única):
  GET /api/v1/context/{ctx_id} HTTPS :9443 — valida ctx_id en O(1)
  Justificación: Kong en K8s, BOS en host — no comparten filesystem

NIVEL 5 — Prometheus ↔ /metrics:
  HTTP scraping → /metrics (monitoreo puro — no datos de negocio)

Puertos numéricos (:9460, :9470, etc.) = K8s ClusterIP o métricas
NO son endpoints REST de negocio · NO se usan para daemon-to-daemon
```

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F14.1 | bauth-stub: Unix socket `/run/bos/bauth.sock` + JSON-RPC 2.0 + escenarios SAM-128 (granted/AUTH_003/AUTH_004/SRV_002) | 🔴 | — | §10.4 · :9450-:9453 = métricas/health K8s · habilita F11.5 | ☐ |
| F14.2 | bhnexus-stub: WebSocket mTLS `:9444` (hardware bridge) + Unix socket + push context.promoted/expired a bos | 🔴 | — | 🔴 gate · §10.7 · bhnexus usa WS porque recibe 10K+ conexiones físicas | ☐ |
| F14.3 | banexus-stub: Unix socket + flujo soberano (auth_request HMAC → SAM <50ms) · sin HTTP | 🔴 | — | §10.7 · banexus --user service · interceptor en edge | ☐ |
| F14.4 | bkernel-stub: Unix socket `/run/bos/bkernel.sock` + :9460 (solo Prometheus metrics) + DDL bkernel_db | 🔴 | — | §10.2 · **sin API REST** · sin endpoint de negocio | ☐ |
| F14.5 | biedata-stub: Unix socket `/run/bos/biedata.sock` + JSON-RPC 2.0 · :9470 = ClusterIP K8s hacia biedata (no HTTP) | 🔴 | — | §10.3 · bajo demanda · biedata es el único gateway externo autorizado | ☐ |
| F14.6 | bsearch-stub: Unix socket `/run/bos/bsearch.sock` + WebSocket wss:// `:9493` exclusivo (sin REST) | 🔴 | — | §10.6 · wss:// para search-as-you-type · PostgreSQL 18+ nativo | ☐ |
| F14.7 | bcompass-stub: Unix socket `/run/bos/bcompass.sock` + `:9480` (métricas) + HITL event simulado | 🔴 | — | §10.5 · Fase 4 concept | ☐ |
| F14.8 | Certificación Capa 5: suite e2e del bos contra 7 stubs sin bloqueos (dctx pre-auth <2s) | 🔴 | — | validar: 0 llamadas HTTP entre daemons en los logs | ☐ |

## FASE 15 — Despliegue Capa 6: Fichas de aplicación

**Objetivo:** Set mínimo de fichas del seed file operativo. §19 Roadmap Fase 2 del Master.
bNotify es CRÍTICO (MFA depende de él). Fichas en S06 (puerto base 28200-28205).

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F15.1 | Ficha bnotify (sbos-notifier): push MFA + notificaciones — puerto :28200-:28205 (S06) | 🔴 | — | ⛔ CRÍTICO · sin bnotify no hay MFA real | ☐ |
| F15.2 | Ficha Tryton (ERP base) para validación del ciclo de negocio C-14 | 🔴 | — | §19 Fase 2 · BD tryton_db F12.2 prerequisito | ☐ |
| F15.3 | Ficha pos-service (Punto de Venta SBOS): seed → install → health | 🔴 | — | §19 Fase 2 · usa biedata como gateway | ☐ |
| F15.4 | Ficha inventario-service: stock, almacenes, movimientos | 🔴 | — | §19 Fase 2 | ☐ |
| F15.5 | Ficha facturacion-service SIAT: DTE Bolivia + firma electrónica | 🔴 | — | §19 Fase 2 · §44 FISCAL-CONTABLE-LATAM | ☐ |
| F15.6 | Verificación DAG en vivo: DEPENDENCY_RESOLVER F11.2 ordenó instalación correcta | 🔴 | — | F11.2 prerequisito | ☐ |
| F15.7 | Certificación Capa 6: seed completo INSTALADA + probe ✓ × todas las fichas | 🔴 | — | bNotify: push real ✓ · Tryton: login ✓ | ☐ |

## FASE 16 — Capa 7: VDI Layer — LA CÚSPIDE

Spec: SBOS-052 + bos-repair/BOS-REPAIR-14-SBOS-CLIENT-SPEC.md (sbos-client).

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F16.1 | Ficha nextcloud: db + OIDC + PVC 500Gi + carpetas + Kong files.{tenant} → C-09 | 🔴 | — | | ☐ |
| F16.2 | Ficha guacamole: db + OIDC + pool VNC + Kong vdi.{tenant} → C-10 | 🟡 | 6a2d9fe | Ficha YAML creada (manifest+task_catalog+k8s) — falta despliegue real e integración OIDC verificada en cluster | ☐ |
| F16.3 | Imagen fedora-logico (Fedora 42 + GNOME + TigerVNC + nextcloud-client) en CI | 🔴 | — | registry interno | ☐ |
| F16.4 | Ficha fedora-logico: HPA min=2/max=20 + mTLS Vault PKI | 🔴 | — | | ☐ |
| F16.5 | sbos-client en el MONOREPO: src/cmd/sbos-client/ + internal/sbosclient/ (reutiliza wslib/paths/audit) · 3 modos autodetectados | 🔴 | — | spec: BOS-REPAIR-14 v2.0 | ☐ |
| F16.6 | identity: WS mTLS :9444 → device_register → dctx_id pre-auth (bitmask 0x0) + heartbeat 30s + backoff 1→60s | 🔴 | — | fail-secure | ☐ |
| F16.7 | session: PUSH context.promoted → dconf (apps por BitMask) + montar home Nextcloud + env ctx_id (+banexus en PHYSICAL) | 🔴 | — | noexec/nosuid | ☐ |
| F16.8 | ciclo: context.expired → limpiar dconf + desmontar (disco local VACÍO) + pool · TTL sin conexión = fail-secure | 🔴 | — | systemd + supervisor pod | ☐ |
| F16.9 | tests: modos PHYSICAL/LOGICAL/WSL + promoted/expired + reconexión + fail-secure (bhnexus stub WS) | 🔴 | — | 6 tests DoD BOS-REPAIR-14 §8 | ☐ |
| F16.10 | Pods fedora-logico ≥2 Running + registrados → C-11 | 🔴 | — | | ☐ |
| F16.11 | Home montado (ls ~/Documentos) → C-12 · device.register <2s → C-13 | 🔴 | — | | ☐ |
| F16.12 | sbos-fedora.iso CON datos del tenant pre-configurados: kickstart + lorax CI + SHA256 + firma Ed25519 · descargable via bosctl iso download Y desde el escritorio Fedora del pod | 🔴 | — | 🔴 gate clave privada · B1/B4: el cliente instala, el equipo se enlaza automático al bos (bauth+KC) y recibe su Context Plane — 3 dominios | ☐ |
| F16.13 | `bosctl vdi verify --tenant=skull` → 6/6 contra fichas REALES | 🔴 | — | reemplaza probe stubs F9.9 | ☐ |
| F16.14 | C-14 e2e: test-user → login web → Keycloak → GNOME <10s → archivo persiste en Nextcloud | 🔴 | — | ✦ LA CÚSPIDE: "El SBOS está instalado" ✦ | ☐ |

## FASE 17 — Estándares internacionales + certificación final

**Objetivo:** Cumplimiento normativo verificable en CI. §17 + §18 del Proyecto Master.
Incluye observabilidad semántica completa (OTel Collector), hardening, SLSA L2.

Detalle del marco normativo: bos-repair/BOS-REPAIR-15-ESTANDARES-INTERNACIONALES.md

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F17.1 | CIS Kubernetes Benchmark v1.12: kube-bench en CI · L1 ≥95% | 🔴 | — | 🔴 gate: flags API server | ☐ |
| F17.2 | CIS benchmark host Ubuntu 26.04 (Lynis/CIS-CAT) | 🔴 | — | | ☐ |
| F17.3 | NIST SP 800-190: imágenes trivy+cosign, registry TLS, digest, seccomp | 🔴 | — | VNC solo interno | ☐ |
| F17.4 | NIST SSDF 800-218: mapeo PO/PS/PW/RV + gosec + govulncheck en CI | 🔴 | — | docs/compliance/SSDF-MAP.md | ☐ |
| F17.5 | SLSA L2: provenance firmada Ed25519 (bos/bosctl/sbos-client/imagen/iso) | 🔴 | — | §18 Regla 12 · Release Plane SKULL | ☐ |
| F17.6 | SBOM automático por release (syft → CycloneDX JSON) | 🔴 | — | | ☐ |
| F17.7 | ISO 27001:2022: matriz de controles técnicos — A.8.15 ✓ (F1.1), A.9 ✓ (F5), A.10 ✓ (F12.4) | 🔴 | — | conformidad ≠ certificación org. | ☐ |
| F17.8 | ISO 25010: 7 gates de calidad medibles en CI (disponibilidad/MTTR/cobertura/latencias) | 🔴 | — | | ☐ |
| F17.9 | OTel Collector con Baggage Processor: ctx_id como atributo en todos los spans + logs | 🔴 | — | §13 · sin ctx_id en span → alerta | ☐ |
| F17.10 | Wazuh DaemonSet en todos los namespaces sbos-* (HIDS/SIEM) | 🔴 | — | §19 Fase 0 · ISMS control A.8.16 | ☐ |
| F17.11 | `.proto` como fuente de verdad: ANTES de cualquier línea de Go, se escribe el .proto (§12.1) | 🔴 | — | §12.1 · RequestContext campo 1 siempre · Money como int64 | ☐ |
| F17.12 | buf lint + buf breaking en CI: ningún cambio de .proto rompe contratos existentes | 🔴 | — | §12 · buf.gen.yaml + buf.work.yaml en cada servicio | ☐ |
| F17.13 | gRPC interceptors chain por §17.3: Recovery→Context→Auth→Logging→Tracing→Metrics en TODOS los servicios gRPC | 🔴 | — | §17.3 · sin excepción · Context extrae ctx_id del metadata | ☐ |
| F17.13 | Kyverno policies: Docker vetado, imágenes firmadas, no-root obligatorio | 🔴 | — | §18 Reglas 8+12 · F13.10 prerequisito | ☐ |
| F17.14 | Verificación §18 reglas inquebrantables en CI: script de compliance automático | 🔴 | — | 12 reglas del Master → 12 checks automatizados | ☐ |
| F17.15 | `bosctl bootstrap verify --full` → 14/14 ✓ + reporte certificación | 🔴 | — | | ☐ |
| F17.16 | Informe final del proyecto + actualización documentación completa | 🔴 | — | MAPA-NAVEGACION, runbooks, READMEs | ☐ |

---

## FASE 18 — Web Platform Soberana (§8 del Proyecto Master)

**Objetivo:** El SBOS sirve sitios web por dominio, empresa y sucursal. Toda petición
web es interceptada por Kong, el Domain Resolver identifica el tenant/empresa/sucursal
a partir del dominio, el CTX Resolver crea un `dctx_id` anónimo si no hay sesión activa,
y el Website Engine sirve el contenido correcto.

> **ATENCIÓN:** Esta fase es compleja por su intersección con el Context Plane.
> Los flujos dctx_id → ctx_id están definidos con precisión en §5 del Master y
> en SBOS-049. Todo átomo de esta fase debe leerse contra esos docs antes de implementar.

**Jerarquía de dominios (§8.1):** `{tenant}.sbos.app` > `{empresa}.{tenant}.sbos.app` > `{sucursal}.{empresa}.{tenant}.sbos.app`

**Flujo de una petición web (§8.2):**
1. Petición llega a Kong (puerto 443, TLS Vault PKI)
2. Kong invoca Kong Plugin SBOS-Context
3. Plugin consulta: ¿hay ctx_id válido en cookie/header? → Si sí: valida contra Context API F10.B.11
4. Si no hay ctx_id activo → Domain Resolver identifica tenant/empresa/sucursal por dominio
5. CTX Resolver crea un `dctx_id` anónimo vía `bos.ctx.device.register` con bitmask=0x0
6. dctx_id se entrega como cookie segura `__sbos_dctx` (HttpOnly, Secure, SameSite=Strict)
7. Website Engine sirve contenido del tenant/empresa/sucursal configurado
8. Cuando el usuario hace login → Keycloak emite JWT → `context.promoted` event → ctx_id nuevo

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F18.1 | Diseño routing table en Kong: reglas host-based por tenant/empresa/sucursal → `docs/WEB-PLATFORM-ROUTING.md` | 🔴 | — | §8.1 · prerequisito de todos los demás átomos de F18 | ☐ |
| F18.2 | Domain Resolver: tabla `web_domains` en bkernel_db (domain, tenant_id, empresa_id, sucursal_id) + `bos.web.domain.resolve` JSON-RPC | 🔴 | — | §8.2 · consulta O(1) por clave de dominio · DDL versionado | ☐ |
| F18.3 | CTX Resolver: crea `dctx_id` anónimo vía bos.ctx.device.register si no hay ctx_id activo | 🔴 | — | §8.3 · F5.4 prerequisito · bitmask=0x0 · TTL configurable | ☐ |
| F18.4 | Cookie `__sbos_dctx`: HttpOnly + Secure + SameSite=Strict + TTL 30min | 🔴 | — | §8.3 · no persistir en JS · rotación en cada promoted | ☐ |
| F18.5 | Website Engine: cluster de pods por tenant (HPA min=2), sirve contenido YAML-declarado | 🔴 | — | §8.4 · ficha declarativa en servers/ | ☐ |
| F18.6 | Ficha website-engine: manifest.yml + rutas Kong + health + métricas + dashboard.json | 🔴 | — | F11.12-F11.15 compliance | ☐ |
| F18.7 | `context.promoted` event: dctx_id queda enlazado al ctx_id en context_sessions (FK no-destrucción) | 🔴 | — | §5.5 · FK: dctx_id queda en historial · ctx_id es inmutable post-promoted | ☐ |
| F18.8 | Flujo completo verificado e2e: visita anónima → dctx_id → login → ctx_id → contenido autorizado | 🔴 | — | §8 · §5 · criterio: bitmask correcto en cada paso | ☐ |
| F18.9 | `bosctl web domain add {dominio} --tenant=X --empresa=Y --sucursal=Z` | 🔴 | — | §8.1 · actualiza routing table + recarga Kong sin downtime | ☐ |
| F18.10 | Certificación Web Platform: 3 dominios distintos → 3 tenants distintos → contenidos distintos · ctx_id correcto en cada sesión | 🔴 | — | §8 completo | ☐ |

---

## FASE 19 — bSearch + bCompass (Fase 4 del Master, §10.5 y §10.6)

**Objetivo:** Motor de Búsqueda Soberano (bSearch) sobre PostgreSQL 18+ nativo.
bCompass es el daemon HITL de IA (asistencia humana). Ambos son **Fase 4 del Roadmap**
(§19, semanas 37-48). No bloquean las fases anteriores, pero su arquitectura
base debe estar definida desde ahora para que los stubs F14.6-F14.7 sean correctos.

> **bSearch usa EXCLUSIVAMENTE PostgreSQL 18+ nativo:** GIN, tsvector, pg_trgm.
> **NO usa** Typesense, Elasticsearch, Meilisearch, ni Qdrant en su implementación actual.
> pgvector/Qdrant son un concepto de Fase 5 (vector search futuro), no parte de esta fase.

| ID | Átomo | Estado | Commit | Notas | Rev |
|---|---|---|---|---|---|
| F19.1 | bSearch: diseño del índice GIN universal `busqueda_universal` en PostgreSQL 18+ | 🔴 | — | §10.6 · particionado por tenant_id · pg_trgm + tsvector | ☐ |
| F19.2 | bSearch: ficha declarativa con Redis Stream `bkernel:index_queue` configurado | 🔴 | — | §10.6 · bkernel alimenta el índice vía WAL | ☐ |
| F19.3 | bSearch: WebSocket exclusivo wss:// en `:9493` + Unix socket `/run/bos/bsearch.sock` | 🔴 | — | §10.6 · sin HTTP REST (SBOS-050 P9) | ☐ |
| F19.4 | bSearch: search-as-you-type con ranking por tenant (GIN score) | 🔴 | — | §10.6 · latencia P99 < 50ms para 1M registros | ☐ |
| F19.5 | bCompass: Unix socket `/run/bos/bcompass.sock` + `:9480-:9481` + HITL event loop | 🔴 | — | §10.5 · contexto IA asistida · Fase 4 | ☐ |
| F19.6 | bCompass: integración con LLM (modelo configurable, no hardcodeado) | 🔴 | — | §10.5 · ADR anti-alucinación obligatorio | ☐ |
| F19.7 | Certificación bSearch: query de 3 tenants distintos → resultados aislados ✓ | 🔴 | — | §10.6 · tenant isolation verificado | ☐ |

---

## FASE 20 — Verificación de Desacoplamiento y Certificación Continua

**Objetivo:** Cerrar los 13 gaps de cobertura detectados al incorporar SBOS-053-DAEMON-TUI-DECOUPLING
(13 reglas DTC, 10 casos DC) y Dev_Control_Certification_Method (5 Gates, métricas, alarmas).
Sin esta fase, el BOS viola el principio headless-first (DTC-01) y la TUI permanece acoplada al daemon.

**Documentos fuente:**
- `SBOS-053-DAEMON-TUI-DECOUPLING.md` v1.1 — 13 reglas DTC + 10 casos DC
- `Dev_Control_Certification_Method.md` v1.0 — 4 reglas Beck + SOLID + 5 Gates + métricas + alarmas

### Bloque A — Desacoplamiento BOS ↔ TUI (SBOS-053 §6, §9, §10)
**Prioridad:** ALTA — impacta la arquitectura. Precondición para certificar M2.

| ID | Átomo | Estado | Commit | Notas | Rev | Gate | DTC |
|---|---|---|---|---|---|---|---|
| F20.A.1 | `contracts/events/` — paquete compartido de tipos puros (seed_params.go + saga_event.go). Cero lógica, solo structs. Verifica DTC-11 | 🔴 | — | Patrón Go: contracts package sin imports de negocio. `go list -deps` verifica zero coupling. Referencia: ginmill pattern, DTO/domain split | ☐ | G0-2 | DTC-11 |
| F20.A.2 | SAGA_SNAPSHOT — mensaje de resync al reconectar TUI. Implementa DTC-06 + DC-03 | 🔴 | — | Patrón Event Sourcing Snapshot (MS Patterns 2025): cargar último snapshot + replay eventos posteriores. Evita replay de historia completa | ☐ | G0-2 | DTC-06, DTC-13 |
| F20.A.3 | Command validation en daemon — comandos TUI validados por el daemon, no por la UI. Implementa DTC-07 + DC-05 | 🔴 | — | Patrón CQRS: commands pueden ser rechazados por el aggregate. TUI envía, daemon decide. Rechazo con código de error explícito | ☐ | G0-2 | DTC-07 |
| F20.A.4 | Test DTC-05 automatizado: kill -9 TUI en paso 3/7 → daemon completa saga. Verifica DTC-05 + DC-02 | 🔴 | — | Test de integración: levantar daemon, iniciar saga, SIGKILL a TUI, verificar saga completa vía JSON-RPC | ☐ | G0-1 | DTC-05 |
| F20.A.5 | Verificación DTC-10: inspección de payloads WebSocket. Secretos nunca en tránsito por canal de eventos | 🔴 | — | CI check: grep prohibido en payloads WS. Vault como única fuente de secretos. Referencia: ISO 27001 A.8.15 | ☐ | G0-1 | DTC-10 |
| F20.A.6 | Persistencia pre-saga: seed_params → bkernel_db ANTES de lanzar saga. Implementa DTC-12 + DC-07 | 🔴 | — | Patrón: write-ahead para parámetros. Si TUI se cierra post-confirmación, daemon ya tiene los params. Transactional outbox | ☐ | G0-2 | DTC-12 |
| F20.A.7 | TUI post-instalación — snapshot real del daemon. Implementa DTC-13 + DC-10 | 🔴 | — | Conectar TUI a daemon con 24h de uptime → mostrar estado real (fichas instaladas, health), no ScreenWelcome vacío | ☐ | G0-2 | DTC-13 |

### Bloque B — Casos de Prueba de Desacoplamiento (SBOS-053 §9)
**Prioridad:** ALTA — validación empírica de las 13 reglas DTC.

| ID | Átomo | Estado | Commit | Notas | Rev | Gate | DTC |
|---|---|---|---|---|---|---|---|
| F20.B.1 | Suite DC-01 a DC-05: deploy sin TUI, cierre a mitad, reconexión, multi-observador, comando inválido | 🔴 | — | 5 tests automatizados en `internal/decoupling/`. DC-01: deploy sin TUI. DC-02: kill TUI en paso 3. DC-03: reconectar y verificar snapshot. DC-04: 2 TUIs simultáneas. DC-05: comando rechazado | ☐ | G0-1 | DTC-01..07 |
| F20.B.2 | Suite DC-06 a DC-10: secreto no transita, parámetros persisten, equivalencia wizard/seed, modo híbrido, conexión post-instalación | 🔴 | — | 5 tests automatizados. DC-06: scan de payloads. DC-08: diff entre wizard y seed.yml. DC-09: wizard pre-rellenado. DC-10: TUI tras 24h | ☐ | G0-1 | DTC-08..13 |

### Bloque C — Modo Híbrido (SBOS-053 §3.3, §3.4)
**Prioridad:** MEDIA — funcionalidad no implementada. Habilita CI/CD + revisión humana.

| ID | Átomo | Estado | Commit | Notas | Rev | Gate | DTC |
|---|---|---|---|---|---|---|---|
| F20.C.1 | `bosctl setup --seed seed.yml` — wizard pre-rellenado desde seed.yml | 🔴 | — | TUI carga seed.yml → defaults en formularios → usuario solo completa campos faltantes. Verifica DTC-09 + DC-09 | ☐ | G0-2 | DTC-09, DTC-11 |
| F20.C.2 | Materialización de seed.yml desde wizard — al confirmar P4, generar seed.yml con los parámetros | 🔴 | — | El wizard produce seed.yml como subproducto. Útil para CI/CD: revisar, versionar, reutilizar | ☐ | G0-2 | DTC-11 |

### Bloque D — Certificación Continua (Dev_Control_Certification_Method §4, §6, §7)
**Prioridad:** MEDIA — calidad automatizada. No bloquea funcionalidad pero previene regresiones.

| ID | Átomo | Estado | Commit | Notas | Rev | Gate | DTC |
|---|---|---|---|---|---|---|---|
| F20.D.1 | Gate 2 automatizado — lint de diseño en CI: golangci-lint + gocyclo (max 15) + funlen (100 líneas) + dupl (<3%) | 🔴 | — | `.golangci.yml` con cyclop, funlen, gocognit, dupl. CI rechaza PRs que violan umbrales. Baseline: complejidad ≤15, función ≤100L, duplicación <3% | ☐ | G2 | — |
| F20.D.2 | Gate 4 automatizado — ADR requerido para decisiones de diseño no obvias | 🔴 | — | CI check: nuevo paquete/interfaz/protocolo → requiere ADR en docs/decisions/. Plantilla ADR según §9 del método | ☐ | G4 | — |
| F20.D.3 | Dashboard de métricas de código en CI — cobertura, complejidad, duplicación | 🔴 | — | Reporte automatizado post-CI: cobertura por paquete, top-10 funciones complejas, clones detectados. Visible en cada PR | ☐ | G1-2 | — |
| F20.D.4 | Monitor de señales de alarma (Roja/Amarilla/Azul) — CI alerta según umbrales §7 | 🔴 | — | Alarma Roja: tests rotos en main, deps cíclicas, secretos. Amarilla: complejidad>10, cobertura<60%. Azul: tests lentos, archivos creciendo | ☐ | G1-2 | — |

### Bloque E — Refuerzo de DTC con cobertura parcial
**Prioridad:** BAJA — funcionalidad existe, falta verificación formal.

| ID | Átomo | Estado | Commit | Notas | Rev | Gate | DTC |
|---|---|---|---|---|---|---|---|
| F20.E.1 | Verificación formal DTC-01: deploy sin TUI en CI automatizado | 🔴 | — | CI: `bosctl deploy seed-skull.yml` en contenedor sin display. Verifica: saga 7/7 completa, health gates verdes | ☐ | G1 | DTC-01 |
| F20.E.2 | Verificación DTC-02: daemon no bloquea por ausencia de TUI | 🔴 | — | Test: iniciar saga, nunca conectar TUI, verificar saga completa vía JSON-RPC. Sin timeouts por falta de observador | ☐ | G1 | DTC-02 |
| F20.E.3 | Verificación DTC-04: pub/sub con N suscriptores simultáneos | 🔴 | — | Test: 3 TUIs + 1 bnotify + 1 audit → mismo stream. Verificar que todos reciben mismos eventos, sin locks | ☐ | G1 | DTC-04 |
| F20.E.4 | Verificación DTC-08: FICHA_LOG legible sin TUI | 🔴 | — | `bosctl ficha logs postgresql` → log completo. Verificar que el log existe y es legible aunque la TUI nunca se haya abierto | ☐ | G1 | DTC-08 |

---

## FASE 21 — Implementación de Controles de Seguridad de Red (SBOS-054)

**Objetivo:** Construir los controles de seguridad de red especificados en SBOS-054 v1.3.
Cubre 20 gaps detectados: las reglas NRS y SAN están documentadas pero no implementadas en código.

**Documento fuente:** `SBOS-054-NETWORK-SECURITY.md` v1.3 (10 NRS + 12 SAN + ctx_id security + Rate Limiting)
**Estándares:** NIST SP 800-207 · OWASP ASVS v5.0 · CWE-20/116/78/22/89 · ISO 27001 A.8.15/A.9.4.2

### Bloque A — Infraestructura TLS/mTLS y Hardening de Red
**Prioridad:** ALTA — sin TLS 1.3 y mTLS, la Context API :9443 viaja en texto plano.

| ID | Átomo | Estado | Commit | Notas | Rev | NRS | SAN |
|---|---|---|---|---|---|---|---|
| F21.A.1 | Implementar TLS 1.3 en :9443: cipher suites ECDHE+AES-256-GCM+SHA384, `tls.Config.MinVersion = tls.VersionTLS13`, timeouts (read/write 2s, idle 30s). Cert autofirmado en staging | 🔴 | — | Modificar `internal/server/api.go:ListenAndServe`. Sin TLS 1.2, sin SSL. NIST SP 800-52 Rev 2 | ☐ | NRS-01 | — |
| F21.A.2 | mTLS para Kong→BOS: BOS requiere certificado cliente de Kong. `tls.Config.ClientAuth = tls.RequireAndVerifyClientCert` | 🔴 | — | Kong y BOS comparten CA interna (Vault PKI en M2.2). Por ahora: certificados autofirmados en ambos lados | ☐ | NRS-03 | — |
| F21.A.3 | NetworkPolicy hardening: template YAML para deny-all por namespace con allowlist explícita (Kong→BOS, Prometheus→metrics, etc.) | 🔴 | — | `servers/S-HOST/sbos-namespace/resources/netpolicies/`. Validar con `kubectl describe networkpolicy` | ☐ | NRS-04 | — |

### Bloque B — Librería de Sanitización (12 reglas SAN)
**Prioridad:** ALTA — sin sanitización centralizada, cada handler valida a su manera (o no valida).

| ID | Átomo | Estado | Commit | Notas | Rev | NRS | SAN |
|---|---|---|---|---|---|---|---|
| F21.B.1 | `internal/sanitize/` — paquete centralizado de validación: UUIDv4, Slug, Email, IPAddr, FilePath, JSONPayload, HeaderValidate, truncate | 🔴 | — | Implementar según SBOS-054 §11.4. Con tests unitarios (≥90% coverage). Cero dependencias externas | ☐ | — | SAN-01..SAN-12 |
| F21.B.2 | Integrar sanitize en todos los handlers JSON-RPC: `json.Decoder.DisallowUnknownFields()`, validación de UUID en ctx_id/tenant_id, límites de longitud | 🔴 | — | Modificar `internal/server/jsonrpc.go`: cada handler recibe input ya validado. Anti-mass-assignment (SAN-10) | ☐ | NRS-07 | SAN-05, SAN-06, SAN-09, SAN-10 |
| F21.B.3 | Validación de headers HTTP en Context API: `X-SBOS-Source: kong` obligatorio, `Authorization: Bearer` validado, rechazar headers desconocidos | 🔴 | — | `handleContextLookup` en api.go: validar headers antes de procesar. Sin header correcto → 403 | ☐ | — | SAN-12 |
| F21.B.4 | Response mínimo enforcement: DTOs separados de domain models. Nunca retornar el objeto completo. `omitempty` en campos no esenciales | 🔴 | — | Crear DTOs para cada response de API. Test: response JSON no contiene campos del domain model que no estén en el DTO | ☐ | NRS-06 | — |
| F21.B.5 | Sanitización de logs: nunca loguear `session_kc`, `user_id` completo, tokens, o secretos. Implementar `logSanitize()` wrapper | 🔴 | — | Modificar boslog para sanitizar automáticamente campos marcados como `security:"secret"` en structs | ☐ | NRS-10 | SAN-07 |

### Bloque C — Rate Limiting + Endurecimiento WebSocket
**Prioridad:** MEDIA — protege contra DoS y ataques de enumeración.

| ID | Átomo | Estado | Commit | Notas | Rev | NRS | SAN |
|---|---|---|---|---|---|---|---|
| F21.C.1 | Rate Limiter en Context API: token bucket 100 req/s por IP. Response 429 con `retry_after_s`. Timeouts: read/write 2s | 🔴 | — | Implementar `internal/server/ratelimit.go` según SBOS-054 §10.2. Tests con `hey -n 1000` | ☐ | NRS-08 | — |
| F21.C.2 | Endurecimiento WebSocket: `CheckOrigin` estricto, frame size max 64KB, max 50 conexiones/IP, idle timeout 60s, validación de mensajes JSON Schema | 🔴 | — | Modificar `internal/wslib/websocket.go`. Anti-CSWSH (Origin validation). Anti-frame-injection (JSON Schema) | ☐ | — | — |
| F21.C.3 | Anti-enumeración: respuesta idéntica para ctx_id no encontrado y expirado. Sin diferenciar en mensaje de error. Sin endpoint de listado | 🔴 | — | `handleContextLookup`: mismo status 404 y mismo mensaje para "not found" y "expired". GCRA rate limit por IP | ☐ | NRS-07 | SAN-04 |

### Bloque D — CI/CD Security + Métricas + Auditoría
**Prioridad:** MEDIA — automatiza la verificación de las reglas de seguridad en cada PR.

| ID | Átomo | Estado | Commit | Notas | Rev | NRS | SAN |
|---|---|---|---|---|---|---|---|
| F21.D.1 | CI security scanning: `gosec` (vulnerabilidades), `govulncheck` (deps), `gitleaks` (secretos hardcodeados). Bloqueante en PR | 🔴 | — | `.github/workflows/ci.yml`: nuevo job `security-scan`. Zero findings permitidos en gosec HIGH | ☐ | NRS-10 | — |
| F21.D.2 | Prometheus security metrics: `bos_context_validations_total{result}`, `bos_context_validation_duration_seconds`, `bos_rate_limit_exceeded_total` | 🔴 | — | `internal/metrics/security.go`: 5 métricas específicas de seguridad. Dashboard Grafana con alertas (>50 errores/min) | ☐ | NRS-09 | — |
| F21.D.3 | Audit log de seguridad: `audit_event` por cada validación de ctx_id, error 404/429, TLS handshake. Con `ctx_id`, `source_ip`, `result`, `timestamp` | 🔴 | — | `internal/audit/security.go`: `LogContextValidation()`, `LogRateLimitExceeded()`, `LogTLSHandshake()`. ISO 27001 A.8.15 | ☐ | NRS-09 | — |
| F21.D.4 | Dependency check: verificar versión mínima de Go (1.25+), dependencias sin CVEs, licencias OSI-approved. CI bloqueante | 🔴 | — | `govulncheck ./...` en CI. Rechazar dependencias con CVEs Critical/High sin mitigación documentada | ☐ | — | — |
| F21.D.5 | HTTP prohibition CI check: `go list -deps` verifica que ningún daemon importa `net/http` para servidores (solo bos :9443). Excepción documentada requerida | 🔴 | — | Script en CI: `grep -r "http.ListenAndServe" --include="*.go" | grep -v "api.go"`. Si encuentra → falla | ☐ | NRS-02 | — |

---

## FASE 22 — Soberanía de Fichas y Cero Intervención Manual (SBOS-055)

**Objetivo:** Implementar y verificar las 8 reglas SOV. Toda tarea manual de instalación,
configuración o mantenimiento DEBE estar declarada en una ficha. "Si un humano tiene que
escribirlo, una ficha debe existir para ello." Sin esta fase, la norma SBOS-055 es papel.

**Documento fuente:** `SBOS-055-FICHA-SOVEREIGNTY.md` v1.0 (8 reglas SOV)
**Estándares:** ISO/IEC 27001 A.8.9 (configuration management) · CIS Benchmark v8 §4.1 · Debian Policy (debconf)

### Bloque A — Auditoría de Soberanía (¿qué tareas manuales existen hoy?)
**Prioridad:** ALTA — sin auditoría no sabemos qué fichas faltan.

| ID | Átomo | Estado | Commit | Notas | Rev | SOV |
|---|---|---|---|---|---|---|
| F22.A.1 | Auditoría de comandos manuales en VPS staging: historial de `ssh root@vps` ejecutados fuera de `bosctl`. Identificar toda tarea manual recurrente | 🔴 | — | Revisar `~/.bash_history` de la VPS. Clasificar cada comando: ¿tiene ficha? ¿es troubleshooting? ¿es configuración? Generar `docs/SOV-GAP-ANALYSIS.md` | ☐ | SOV-07 |
| F22.A.2 | Auditoría de `install.sh`: verificar ≤25 líneas, sin `apt-get`, `useradd`, `mkdir`, `openssl`, `systemctl`. Si viola → reducir a copia de binarios + exec | 🔴 | — | `wc -l staging/install.sh`. `grep -E "apt|useradd|mkdir|openssl|systemctl|chown|chmod" staging/install.sh`. Cero matches requerido (SOV-05) | ☐ | SOV-05 |
| F22.A.3 | Auditoría de recursos del sistema: `find /etc/bos /run/bos /var/log/bos` → cada archivo/directorio debe ser creado por una ficha. Si no → asignar ficha responsable | 🔴 | — | Inventario completo de `/etc/bos/`. Para cada archivo: ¿qué ficha lo crea? Huérfanos → nueva ficha o paso en ficha existente | ☐ | SOV-02, SOV-08 |
| F22.A.4 | Auditoría de paquetes instalados vs declarados: `dpkg -l` vs `manifest.yml → system_packages`. Todo paquete instalado debe estar declarado en alguna ficha | 🔴 | — | Script: `diff <(dpkg -l | awk '/^ii/{print $2}') <(grep -rh "system_packages" servers/ -A 20 | grep "^  - " | sed 's/  - //')`. Sin diff → OK | ☐ | SOV-01 |

### Bloque B — Automatización de Verificación (CI + Checks)
**Prioridad:** ALTA — sin CI, las reglas SOV se violan por accidente.

| ID | Átomo | Estado | Commit | Notas | Rev | SOV |
|---|---|---|---|---|---|---|
| F22.B.1 | CI check SOV-05: `install.sh` no contiene comandos de sistema. Si `grep` encuentra `apt`/`useradd`/`mkdir`/`openssl`/`systemctl` → PR rechazado | 🔴 | — | `.github/workflows/ci.yml`: job `sov-check`. Bloqueante. Error claro: "install.sh viola SOV-05. Mover este comando a una ficha." | ☐ | SOV-05 |
| F22.B.2 | CI check SOV-01: todo `system_packages` declarado en `manifest.yml` tiene su `task_catalog.sh` que lo instala. Sin paquetes huérfanos | 🔴 | — | Script: para cada ficha con system_packages, verificar que task_catalog.sh contiene `apt-get install` o equivalente para cada paquete | ☐ | SOV-01 |
| F22.B.3 | CI check SOV-02/SOV-03: `grep -r "mkdir -p /etc|useradd|chown|openssl req"` en documentación de instalación → cero resultados (solo dentro de task_catalog.sh) | 🔴 | — | Si aparece en README, instructivo, o script fuera de `servers/` → warning. La documentación nunca debe decir "ejecuta este comando manual" | ☐ | SOV-02, SOV-03 |
| F22.B.4 | CI check de idempotencia: cada ficha con `ficha_install()` debe tener `ficha_test()` que verifica el estado post-install. Ejecutar install 2 veces = mismo resultado | 🔴 | — | Test: `ficha_install && ficha_test && ficha_install && ficha_test`. Ambas ejecuciones de test deben dar OK. Sin errores en la segunda install | ☐ | SOV-01..SOV-04 |

### Bloque C — Fichas Faltantes (convertir tareas manuales en fichas)
**Prioridad:** MEDIA — según resultados de auditoría Bloque A.

| ID | Átomo | Estado | Commit | Notas | Rev | SOV |
|---|---|---|---|---|---|---|
| F22.C.1 | Ficha `bos-certs`: generación y renovación de certificados TLS para :9443 y comunicación interna. Actualmente en bos-preflight — evaluar si debe ser ficha separada | 🔴 | — | Si el cert necesita rotación automática (ej: 30 días antes de expirar) → ficha separada con su propio health check. Si es solo inicial → bos-preflight es suficiente | ☐ | SOV-02, SOV-08 |
| F22.C.2 | Ficha `bos-firewall`: configuración de UFW/nftables para puertos SBOS. Política deny-all + allowlist explícita. Actualmente no existe — ¿se hace manual? | 🔴 | — | `servers/S-HOST/bos-firewall/`. Puertos: 22 (SSH), 443 (Kong), 9443 (BOS Context API). Todo lo demás → deny. NSA/CISA K8s Hardening | ☐ | SOV-02, SOV-08 |
| F22.C.3 | Ficha `bos-logrotate`: rotación de logs en `/var/log/bos/`. Tamaño máximo, compresión, retención. Actualmente no existe — los logs crecen sin límite | 🔴 | — | `servers/S-HOST/bos-logrotate/`. Configuración declarativa: max_size, keep_days, compress. ISO 27001 A.8.15 (log protection) | ☐ | SOV-02, SOV-08 |
| F22.C.4 | Ficha `bos-ntp`: sincronización de reloj. `systemd-timesyncd` o `chrony`. Crítico para TLS, JWT, audit logs. Actualmente depende del SO base | 🔴 | — | `servers/S-HOST/bos-ntp/`. Verificar que NTP está activo y sincronizado. Sin reloj correcto → TLS falla, JWT expiran mal, audit logs inconsistentes | ☐ | SOV-02, SOV-08 |

### Bloque D — Documentación y Capacitación
**Prioridad:** BAJA — cultural, no técnico.

| ID | Átomo | Estado | Commit | Notas | Rev | SOV |
|---|---|---|---|---|---|---|
| F22.D.1 | `docs/SOV-COMPLIANCE.md` — guía para desarrolladores: cómo crear una ficha que cumpla SOV, template de task_catalog.sh, checklist pre-commit | 🔴 | — | Documento vivo. Cada nueva ficha sigue este template. Incluye: estructura de directorios, funciones obligatorias, pruebas requeridas, idempotencia | ☐ | SOV-01..SOV-08 |
| F22.D.2 | Actualizar `INSTRUCCIONES-DE-USO.md` y `MAPA-NAVEGACION.md` con referencia a SBOS-055. Todo nuevo desarrollador debe leer SOV antes de tocar código | 🔴 | — | Agregar SBOS-055 a la lista de "lectura obligatoria antes de empezar". Mismo nivel que SBOS-049 y SBOS-050 | ☐ | — |

---


## Resumen

| Fase | Total átomos | ✅ | 🟡 | 🔴 |
|---|---|---|---|---|
| F0 — Fundación | 9 | 8 | 0 | 1 |
| F1 — main.go | 9 | 9 | 0 | 0 |
| F2 — WebSocket | 4 | 4 | 0 | 0 |
| F3 — TUI (pantallas + renders + contratos comunicación) | 61 | 18 | 0 | 43 |
| F4 — bosctl/RBAC | 5 | 5 | 0 | 0 |
| F5 — Context Plane (SBOS-049 + SBOS-054 §8 + RB-03) | 34 | 5 | 0 | 29 |
| F6 — JSON-RPC | 12 | 11 | 0 | 1 |
| F7 — Documentación | 8 | 8 | 0 | 0 |
| F8 — Tests | 7 | 7 | 0 | 0 |
| F9 — Operator | 11 | 11 | 0 | 0 |
| F10 — biaos | 11 | 10 | 0 | 1 |
| **F10.B — Instalador ADR-022** | **12** | **10** | **0** | **2** |
| **F10.C — Ciclo Tenants (saga 7 pasos)** | **14** | **10** | **2** | **2** |
| F11 — Ficha Engine + Admin (ADR-021, 18 estados) | 36 | 11 | 2 | 23 |
| F12 — Capa 3 datos + Bootstrap Mínimo Viable k3s (ADR-040) | 35 | 0 | 0 | 35 |
| F13 — Capa 4 identidad (KC 26.6.2 + Kong + JSON-RPC→gRPC) | 13 | 0 | 0 | 13 |
| F14 — Capa 5 daemons stubs | 8 | 0 | 0 | 8 |
| F15 — Capa 6 aplicación | 7 | 0 | 0 | 7 |
| F16 — Capa 7 VDI ✦ | 14 | 0 | 1 | 13 |
| F17 — Estándares + OTel + Wazuh + gRPC/proto | 17 | 0 | 0 | 17 |
| **F18 — Web Platform Soberana** | **10** | **0** | **0** | **10** |
| **F19 — bSearch + bCompass (Fase 4)** | **7** | **0** | **0** | **7** |
| **F20 — Desacoplamiento + Certificación (SBOS-053 + Dev_Control)** | **19** | **0** | **0** | **19** |
| **F21 — Seguridad de Red (SBOS-054: NRS + SAN + mTLS + Rate Limit)** | **16** | **0** | **0** | **16** |
| **F22 — Soberanía de Fichas (SBOS-055: SOV-01..SOV-08)** | **14** | **0** | **0** | **14** |
| **TOTAL** | **382** | **137** | **0** | **245** |

**Contratos BOS-CONTRATOS-SBOS.md (estado a 2026-06-17):**

| Contrato | Descripción | Estado |
|----------|-------------|--------|
| C-1 | Context Plane | ✅ 85% — JSON-RPC completo · AutoMigrate ✅ · REST :9443 pendiente (F10.B.11) |
| C-2 | Ciclo vida tenants | ✅ 50% — saga engine ✅ · deploy.go alineado SBOS-051 v2.0 · `tenant suspend/remove` 🟡 |
| C-3 | Gestión fichas 18 estados | ✅ 75% — sagas ✅ · 5 fichas alineadas SBOS-051 · daemons pendientes |
| C-4 | Interface Dual JSON-RPC | ✅ 90% — 50+ métodos · Unix socket ✅ · bos.tenant.* pendiente |
| C-5 | Context API HTTPS :9443 | 🔴 30% — **CRÍTICO para Kong** · F10.B.11 |
| C-6 | bosctl CLI completa | ✅ 80% — 23+ comandos · `deploy` ✅ · `tenant suspend/remove` 🟡 |
| C-7 | Reconciliación Day 2 | ✅ 80% — scheduler ✅ · 15 min configurable ✅ |

**Próximo átomo:** M1.4 — Context API REST `:9443` — 6 endpoints `/api/v1/context/*` (CRÍTICO para Kong).
**Orden de ejecución (2026-06-17):**
1. M1.3→M1.4→M1.5 (daemon foundation)
2. F20.A.1 (contracts/events/) en paralelo con M1.4
3. M2.1→M2.5 (primer tenant real, requiere DTC-01 de F20.A)
4. F20.A.2→F20.E (verificación, híbrido, métricas — post-M2)
5. FASE 20 es TRANSVERSAL: no reemplaza el orden M1→M6, lo verifica.
**Decisiones arquitectónicas 2026-06-17:**
1. El bos es el Control Plane soberano dueño del ciclo de vida del tenant (Modelo A + Modelo B, SBOS-051 v2.0). No existe `bcompass` como registro maestro — el bos almacena tenants en `bkernel_db.enterprise_tenants` y expone vía JSON-RPC 2.0. Patrón: CRD + Operator (AWS Control Plane, Stakater MTO).
2. **Documento vivo de instalación:** `DATOS-TUI-INSTALACION.md` es la fuente de verdad para todo lo relacionado con instalación de tenants y fichas. SFP-07 obliga a actualizarlo ante cualquier cambio en fichas, comandos, puertos, apps, pantallas o ayudas. SFP-08 obliga a basar toda decisión en estándares internacionales (ISO, NIST, NSA/CISA, CIS, WCAG, W3C, IANA, RFC).
3. **Cero warnings `go vet`:** corregidos 2 unreachable code en `update.go` (case PreflightMsg sin default, return inalcanzable al final del switch). Build + vet + tests verificados limpios en cada commit.

---

*REGISTRO-ESTADO.md v2.0 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
*Actualizar la columna Estado + Commit en cada Informe de Cierre*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*

---

## FASE 23 — Servidor S12 Blockchain + Fichas D12 (12 átomos · ~42h)

**Objetivo:** Crear el servidor lógico S12/blockchain con fichas declarativas para la red Besu QBFT. **DoD:** Fichas compiladas, validadas contra SBOS-055, desplegables vía `bosctl ficha install`.

**SSOT:** `BAUTH-D12-INFRAESTRUCTURA-BLOCKCHAIN.md` · `AuditAnchor.sol` · `SBOS-055-FICHA-SOVEREIGNTY.md`

### Bloque A — Servidor Lógico S12

| ID | Átomo | E | Estado | Commit | Solución / Bitácora | Rev | G | D |
|---|---|---|---|---|---|---|---|---|
| **F23.A.1** | Servidor lógico `S12/blockchain` — crear estructura en `servers/` | 2h | 🔴 | — | 📝 `servers/S12/blockchain/README.md` con propósito: "Red Besu QBFT privada para liquidaciones on-chain y anclaje de auditoría". Catálogo de fichas: besu-genesis, besu-validator, besu-rpc. Sin apps de usuario — solo infraestructura. | ☐ | SOV-02 | BAUTH-D12 |
| **F23.A.2** | NetworkPolicy S12 — aislamiento de red blockchain | 2h | 🔴 | — | 📝 `servers/S12/blockchain/resources/netpolicies/deny-all-allow-besu.yaml`. Solo permitir: (1) tráfico entre validadores Besu (p2p:30303, rpc:8545), (2) bAuth → besu-rpc:8545 (solo lectura y envío de tx), (3) Prometheus → métricas Besu. Denegar todo lo demás. NSA/CISA K8s Hardening. | ☐ | NRS-04 | BAUTH-D12 |

### Bloque B — Ficha besu-genesis (Job único)

| ID | Átomo | E | Estado | Commit | Solución / Bitácora | Rev | G | D |
|---|---|---|---|---|---|---|---|---|
| **F23.B.1** | `besu-genesis/manifest.yml` | 2h | 🔴 | — | 📝 Tipo: Job (ejecutar una vez). Dependencias: ninguna. Configuración QBFT: 4 validadores, blockperiod=2s, gasLimit=0x1fffffffffffff, min-gas-price=0. Contrato de permissioning: nodes + accounts. Archivo `genesis.json` generado con `besu operator generate-blockchain-config`. | ☐ | SOV-01, SOV-02 | BAUTH-D12 |
| **F23.B.2** | `besu-genesis/task_catalog.sh` | 3h | 🔴 | — | 📝 Funciones: `ficha_install()` → ejecuta job K8s que corre `besu genesis` y almacena el resultado en ConfigMap `besu-genesis`. `ficha_test()` → verifica que ConfigMap existe y contiene `genesis.json` válido. `ficha_status()` → muestra hash del genesis. Idempotente: si ConfigMap ya existe, no regenerar (--skip-if-exists). | ☐ | SOV-01, SOV-04 | BAUTH-D12 |

### Bloque C — Ficha besu-validator (StatefulSet)

| ID | Átomo | E | Estado | Commit | Solución / Bitácora | Rev | G | D |
|---|---|---|---|---|---|---|---|---|
| **F23.C.1** | `besu-validator/manifest.yml` | 4h | 🔴 | — | 📝 Tipo: StatefulSet (4 réplicas). Imagen: `hyperledger/besu:24.12`. Recursos: 2000m CPU, 4Gi RAM, 50Gi almacenamiento (StorageClass `bos-blockchain`). Puertos: 30303 (p2p), 8545 (rpc), 8546 (ws), 9545 (métricas). Comando: `besu --config-file=/etc/besu/config.toml --identity={VALIDADOR_ID}`. Variables de entorno: `BESU_PRIVATE_KEY_FILE=/etc/besu/keys/key`. | ☐ | SOV-01, SOV-02 | BAUTH-D12 |
| **F23.C.2** | `besu-validator/task_catalog.sh` | 5h | 🔴 | — | 📝 `ficha_install()`: crear StatefulSet, esperar 4 pods Ready. `ficha_test()`: verificar que los 4 validadores están activos (QBFT consensus) vía `besu qbft validators`. `ficha_status()`: altura de bloque, validadores activos, gas usado. `ficha_reconcile()`: detectar validador caído → alerta. Health check: readiness probe en `/liveness`. | ☐ | SOV-01, SOV-04 | BAUTH-D12 |
| **F23.C.3** | `besu-validator/keys/` — gestión de claves ECDSA secp256k1 | 3h | 🔴 | — | 📝 Las claves se almacenan en Vault (`pki/keys/besu-validator-{i}`). `ficha_install()`: (1) verificar que Vault tiene las 4 claves, (2) crear Secret K8s `besu-validator-key-{i}` desde Vault, (3) montar en `/etc/besu/keys/` con `readOnly: true`. La clave NUNCA sale del HSM. Rotación cada 180 días con período de transición 7 días. NIST SP 800-57. | ☐ | SOV-02, SOV-08 | NIST SP 800-57 |

### Bloque D — Ficha besu-rpc (Nodos públicos)

| ID | Átomo | E | Estado | Commit | Solución / Bitácora | Rev | G | D |
|---|---|---|---|---|---|---|---|---|
| **F23.D.1** | `besu-rpc/manifest.yml` | 3h | 🔴 | — | 📝 Tipo: Deployment (2 réplicas). Imagen: `hyperledger/besu:24.12`. Recursos: 1000m CPU, 2Gi RAM. Puertos: 8545 (rpc), 8546 (ws). Comando: `besu --rpc-http-enabled --rpc-http-api=ETH,NET,QBFT --host-allowlist="*"`. Sin participación en consenso — solo lectura y envío de tx. NetworkPolicy: solo bAuth y monitoreo. | ☐ | SOV-01, SOV-02 | BAUTH-D12 |
| **F23.D.2** | `besu-rpc/task_catalog.sh` | 4h | 🔴 | — | 📝 `ficha_install()`: crear Deployment, Service ClusterIP `besu-rpc.sbos-blockchain:8545`. `ficha_test()`: `curl besu-rpc:8545 -d '{"jsonrpc":"2.0","method":"eth_blockNumber","id":1}'` → responde con altura de bloque. `ficha_status()`: conectado a validador, altura sincronizada, latencia RPC. | ☐ | SOV-01, SOV-04 | BAUTH-D12 |

### Bloque E — Ficha bauth-blockchain-config (bAuth → Besu)

| ID | Átomo | E | Estado | Commit | Solución / Bitácora | Rev | G | D |
|---|---|---|---|---|---|---|---|---|
| **F23.E.1** | `bauth-blockchain-config/manifest.yml` | 2h | 🔴 | — | 📝 Tipo: Config (sin pods). Propósito: inyectar configuración de blockchain en `bauth.toml`. Sección `[blockchain]`: `arbitrum_rpc`, `besu_rpc`, `anchor_contract`, `settlement_contract`. Dependencia: besu-rpc debe estar operativo antes. Valida que la dirección del contrato existe en la red. | ☐ | SOV-02, SOV-08 | BAUTH-D12 |
| **F23.E.2** | `bauth-blockchain-config/task_catalog.sh` | 2h | 🔴 | — | 📝 `ficha_install()`: (1) leer `genesis.json` del ConfigMap, (2) extraer dirección del contrato deployado, (3) escribir en `/etc/bos/bauth.toml` sección `[blockchain]`. `ficha_test()`: verificar que bAuth puede conectar a Besu RPC (`curl besu-rpc:8545`). `ficha_reconcile()`: si cambia la dirección del contrato, actualizar. | ☐ | SOV-01, SOV-08 | BAUTH-D12 |

### Bloque F — Storage + Monitoreo

| ID | Átomo | E | Estado | Commit | Solución / Bitácora | Rev | G | D |
|---|---|---|---|---|---|---|---|---|
| **F23.F.1** | StorageClass `bos-blockchain` — 50Gi persistentes para datos de cadena | 1h | 🔴 | — | 📝 `servers/S12/blockchain/resources/storage-class.yaml`. Provisioner: `local-path` (k3s default). 50Gi por validador. Retain policy (no borrar datos al desinstalar). Backup diario a MinIO (S01). | ☐ | SOV-02 | BAUTH-D12 |
| **F23.F.2** | Monitoreo Besu — Prometheus metrics + Grafana dashboard | 3h | 🔴 | — | 📝 Métricas: `besu_blockchain_height`, `besu_qbft_validators_active`, `besu_gas_used`, `besu_peer_count`, `besu_block_time_seconds`. Alertas: `AnchorDown` (P1, sin anclajes en 2h), `ValidatorDown` (P1, validador caído), `GasBalanceCritical` (P1, < 0.01 ETH). Dashboard Grafana: altura, validadores, gas, peers, bloques/minuto. | ☐ | NRS-06, SOV-08 | BAUTH-D12 |

---

**Total FASE 23:** ~30h (12 átomos) · Servidor lógico S12 con 4 fichas declarativas · Cero intervención manual · Cumple SBOS-055.

## Resumen de Servidores Lógicos Actualizado

| Servidor | Propósito | Fichas instaladas | Fichas planificadas |
|----------|---------|------------------|-------------------|
| **S-HOST** | Host físico | bos, bos-preflight | bos-certs, bos-firewall, bos-ntp |
| **S01** | Datos | postgresql, redis, minio | — |
| **S03** | Autenticación | keycloak, vault, bauth | bauth-blockchain-config |
| **S06** | Aplicaciones | bsearch, kong | bnotify |
| **S12** | Blockchain 🆕 | — | besu-genesis, besu-validator, besu-rpc |
| **S15** | Monitoreo | prometheus, grafana, loki | — |

---

## FASE 24 — Cierre bAuth: Infraestructura Geoespacial + Frontend Widgets (5 átomos · ~14h)

**Objetivo:** Proveer la infraestructura y herramientas de frontend que bAuth necesita para
completar los dominios D6 (Geoespacial), D4 (Temporal), D7 (Red), D5 (Biométrico), y D3 (Financiero).
Sin estas herramientas, los datos espaciales, biométricos y financieros no pueden ser capturados.

**Documentos fuente:**
- `bauth/plandeaccion/bauth/BAUTH-D6-GEOESPACIAL-PROYECTO.md` — Solución PostGIS + Flutter Map
- `bauth/plandeaccion/bauth/BAUTH-FRONTEND-HERRAMIENTAS-POR-DOMINIO.md` — 13 herramientas, $0 costo
- `bauth/plandeaccion/bauth/BAUTH-TAREAS-PENDIENTES.md` — 11 tareas pendientes

### Bloque A — Infraestructura PostGIS (1 átomo)

| ID | Átomo | E | Estado | Commit | Notas | Rev activa |
|---|---|---|---|---|---|---|
| **F24.A.1** | **Ficha `postgis`** — `servers/S01/postgis/manifest.yml` + `task_catalog.sh`. Instalar extensión PostgreSQL: `CREATE EXTENSION postgis; CREATE EXTENSION postgis_topology;`. Verificación: `SELECT PostGIS_Version();`. Sin esta ficha, las 5 tablas D6 (geo_trust_tier, geo_velocity_policy, geo_fence, geo_location_log, geo_evaluation_log) no pueden usar tipos POINT/POLYGON. | 2h | 🔴 | — | Dependencia: postgresql (ficha 100, S01). Prioridad: 🔴 Crítico para D6. | F5.I.1 |

### Bloque B — Frontend: Widgets de Captura de Datos (4 átomos)

| ID | Átomo | E | Estado | Commit | Notas | Rev activa |
|---|---|---|---|---|---|---|
| **F24.B.1** | **Widget `MapPointPicker` + `MapPolygonDrawer`** — Integrar `flutter_map` + OpenStreetMap en el Core UI. Permite: tocar punto en mapa → (lat, lon), dibujar polígono para geo-fence, buscar dirección → coordenadas (Nominatim). Sin este widget, los campos `POINT` y `POLYGON` en la DDL no pueden ser poblados. | 4h | 🔴 | — | Dependencias Flutter: `flutter_map ^7.0.0`, `latlong2 ^0.9.1`. Licencia BSD/MIT, $0, sin API key. | F5.I.2 |
| **F24.B.2** | **Widgets temporales** — `DatePicker`, `TimePicker`, `DateTimeZonePicker`, `RecurrencePicker` (RFC 5545). Integrar con `showDatePicker` nativo + `rrule` Dart package. Sin estos widgets, los campos `DATE`, `TIME`, `TIMESTAMPTZ`, `rrule` no pueden ser poblados. | 3h | 🔴 | — | Dependencias: `rrule` Dart (BSD), `flutter_native_timezone` (MIT). | F5.I.2 |
| **F24.B.3** | **Widgets de seguridad** — `BiometricEnrollment` (local_auth), `CertificateUpload` (file_picker + x509), `SignaturePad` (signature), `DocumentScanner` (google_mlkit). Sin estos widgets, los campos `BYTEA`, certificados X.509, firmas digitales y documentos de identidad no pueden ser capturados. | 3h | 🔴 | — | Dependencias: `local_auth` (BSD), `file_picker` (MIT), `signature` (MIT), `google_mlkit_document_scanner` (Apache 2.0). | F5.I.2 |
| **F24.B.4** | **Poblar `menu_context` con entradas de widget** — 12+ entradas en `bglobal.menu_context` mapeando `entity_type` → `widget_type`. El Core UI consulta esta tabla para saber qué widget renderizar para cada campo de cada tabla. Sin esto, los widgets existen pero la UI no sabe cuándo usarlos. | 2h | 🔴 | — | Entradas: `geo.point.picker`, `geo.polygon.drawer`, `geo.address.search`, `cal.recurrence.picker`, `cal.datetime.picker`, `net.cidr.input`, `sec.cert.upload`, `fin.currency.input`, `user.photo.capture`, `user.document.scan`, `jsonb.policy.editor`, `menu.tree.editor`. | F5.I.8 |

---
**Total FASE 24:** ~14h (5 átomos) · Infraestructura PostGIS + 4 widgets de captura + menu_context.
**Impacto:** Completa la capa de captura de datos para los 12 dominios. Sin esto, ~30 campos en la DDL
no pueden ser poblados por un humano.

## Resumen de Servidores Lógicos Actualizado

| Servidor | Propósito | Fichas instaladas | Fichas planificadas |
|----------|---------|------------------|-------------------|
| **S-HOST** | Host físico | bos, bos-preflight | bos-certs, bos-firewall, bos-ntp |
| **S01** | Datos | postgresql, redis, minio | **postgis** 🆕 |
| **S03** | Autenticación | keycloak, vault, bauth | bauth-blockchain-config |
| **S06** | Aplicaciones | bsearch, kong | bnotify |
| **S12** | Blockchain 🆕 | — | besu-genesis, besu-validator, besu-rpc |
| **S15** | Monitoreo | prometheus, grafana, loki | — |
