# _legacy/ — Memoria del Proyecto BOS-REPAIR

Este directorio preserva todo el código original extraído durante la reparación.
**NUNCA eliminar archivos de aquí.** Son referencia histórica y fuente de recuperación.

---

## ⛔ REGLA DE ORO — Solo referencia de lógica

**El código archivado aquí NO se copia, NO se reutiliza tal como está.**

Su único propósito es que el agente implementador pueda:
1. **Entender** qué lógica existía antes
2. **Evaluar** qué algoritmos siguen siendo válidos
3. **Reimplementar** desde el `doc.go` del nuevo paquete, adaptando solo lo que aplica

Copiar código de `_legacy/` al nuevo paquete **está prohibido**. Si la lógica es válida,
se reescribe limpiamente con documentación ADR-003 y modularización correcta.

---

## Regla de archivo (SFP-01)

Antes de modificar cualquier bloque de código existente:
```bash
cp <archivo_origen> _legacy/YYYY-MM-DD_F<X.Y>_<descripcion>.go
```

El archivo archivado lleva este header:
```go
// ARCHIVADO: F<X.Y> — YYYY-MM-DD
// Origen: <ruta original>
// Razón: <por qué se extrae/modifica>
// Informe de Cierre: informes-cierre/INFORME-CIERRE-F<X.Y>-*.md
```

---

## Índice de archivos archivados

| Elemento | Fase | Origen | Nuevo paquete | Qué lógica extraer | Informe |
|---|---|---|---|---|---|
| `2026-06-09_F0.7_ai/` | F0.7 | `internal/ai/` | `internal/biaos/` (F10.2) | Circuit breaker 3-tiers, cliente Anthropic/Ollama/OpenAI, context builder | INFORME-CIERRE-F0.7 |
| `2026-06-09_F0.7_observability/` | F0.7 | `internal/observability/` | `internal/metrics/` (F9.6) | Estructura HealthReport por capas (Ubuntu/K8s/BOS), top.go | INFORME-CIERRE-F0.7 |
| `2026-06-09_F0.7_repair/` | F0.7 | `internal/repair/` | `internal/scaler/` + `internal/maintenance/` (F9.3-F9.4) | RepairManager multi-fase, OSRepairer, K8sNodeRepairer, HealthVerifier | INFORME-CIERRE-F0.7 |
| `2026-06-09_F0.7_server_api.go` | F0.7 | `internal/server/api.go` | `internal/server/ws.go` extendido (F2) | Handlers REST → migrar a WebSocket RPC | INFORME-CIERRE-F0.7 |
| `2026-06-09_F0.7_server_bootstrap.go` | F0.7 | `internal/server/bootstrap.go` | `internal/bootstrap/` (F1.2) | Handlers de bootstrap del servidor | INFORME-CIERRE-F0.7 |
| `2026-06-09_F0.7_security_rbac_provider.go` | F0.7 | `internal/security/rbac_provider.go` | bAuth asume RBAC (F4.4) | Roles canónicos: admin/operator/readonly | INFORME-CIERRE-F0.7 |
| `2026-06-09_F0.7_security_identity_provider.go` | F0.7 | `internal/security/identity_provider.go` | bAuth asume identidad (F4.4) | Interface IdentityProvider | INFORME-CIERRE-F0.7 |
| `2026-06-09_F1.1_audit_log_original.go` | F1.1 | `cmd/bos/main.go` (func auditLog) | `internal/audit/log.go` | Firma drop-in: Log(path, category, kvs...); O_APPEND atómico en Linux | — |
| `2026-06-09_F1.2_auto_bootstrap.go` | F1.2 | `cmd/bos/main.go` (autoBootstrap + copyDir + detectContainerMapping) | `internal/bootstrap/setup.go` | Setup() idempotente, retorna error en vez de os.Exit; SysRoot override para tests; pasos 8/8.5 quedan en main.go hasta F1.3/F1.4 | — |
| `2026-06-09_F1.3_cgroup_original.go` | F1.3 | `cmd/bos/main.go` (verifyCgroupDelegation + isBareMetal + configureSystemdDelegate + detectContainerMapping) | `internal/cgroup/cgroup.go` | ProcRoot/SystemdDir como variables de paquete para override en tests; Probe/IsBareMetal/ConfigureSystemdDelegate/DetectContainerMapping con godoc ADR-003 completo | — |
| `2026-06-09_F1.4_network_original.go` | F1.4 | `cmd/bos/main.go` (detectNetworkSubnet + ensureNftablesForwardRule + ensureBridgeNetwork) | `internal/network/network.go` | Renombradas a DetectSubnet/EnsureNftablesForwardRule/EnsureBridgeNetwork; audit.Log usa paths.AuditLog (P16); mensajes en español; godoc ADR-003 completo | — |
| `2026-06-09_F1.5_observer_original.go` | F1.5 | `cmd/bos/main.go` (initializeFichaStates + startupReconcile + runObserverLoop + findNextAutoInstall + depsSatisfied + topologicalSort) | `internal/observer/observer.go` + `startup.go` | Loop struct con Run/Stop (sync.Once); SystemctlFn inyectable en StartupReconcile; funciones puras exportadas; race P6/P14 corregida en reconcile/scheduler.go con inFlight sync.Map | — |
| `cmd_bosctl_install_ui_pre_F310_2026-06-10.go` | F3.10 | `cmd/bosctl/install_ui.go` (monolito 4,834 líneas) | `internal/tui/` (styles/model/screens/demo) + `cmd/bosctl/install_ui.go` 62L | Wizard completo, dashboard, 15 pantallas, scrollbars, demo — reimplementado modular en F3.1–F3.10 | INFORME-CIERRE-F3 |
| `internal_security_rbac_provider_pre_F44_2026-06-10.go` | F4.4 | `internal/security/rbac_provider.go` | `interfaces.go` (RBACProvider) + `file_rbac.go` + `bauth_rbac.go` — bAuth asume RBAC (ADR-006) | Roles admin/operator/readonly, persistencia roles.json — la interfaz quedó; la implementación se delega a PAM/K8s/bAuth | INFORME-CIERRE-F4 |
| `2026-06-10_F10.2_ai_client.go` / `_ai_model_router.go` / `_ai_context_builder.go` | F10.2 | `internal/ai/` | `internal/biaos/` (client.go, router.go, context_builder.go) | Cliente LLM multi-backend (Anthropic/Ollama/OpenAI), router con cooldown, builder de contexto — migrados con package biaos; gateway singleton F10.1 los envuelve | INFORME-CIERRE-F10 |

---

*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
