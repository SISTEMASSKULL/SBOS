# INFORME DE CIERRE — FASE 10: biaos (Agente OS + Gateway IA)
## BOS-REPAIR · SKULL · SBOS · 2026-06-11 — FASE FINAL DEL PLAN

**Agente:** Claude Fable 5 · **Operador:** skull
**Átomos:** F10.0–F10.9 (10/10 ✅ en código) · **Commits:** f472d28 → b8f65a7
**Base:** BOS-REPAIR-10 (arquitectura completa), BOS-REPAIR-12 §7
**⚠️ Validación en servidor real: PENDIENTE** (acceso SSH bloqueado — ver §Pendiente)

---

## Resumen ejecutivo

F10 entrega biaos: el agente de infraestructura del bos. Su principio
rector — demostrado por test, no declarado — es que **el agente JAMÁS genera
comandos**: mapea la intención del operador a una acción del catálogo
declarativo (ICAP), y cada acción referencia un método JSON-RPC que existe
en el rpcRegistry (las sagas F6 y el Operator F9 son sus herramientas).
Riesgo>bajo se detiene en HITL. Todo intento queda auditado en JSONL antes
de ejecutarse, y ese audit es la semilla del dataset de entrenamiento.

## Átomos

| Átomo | Entregable | Garantía verificada por test |
|---|---|---|
| F10.0 | `docs/biaos/action_catalog.yml` — 17 acciones | Todos los metodo_rpc existen; riesgo>bajo ⇒ HITL |
| F10.1 | Gateway singleton + circuit breaker | sync.Once; 3 fallos→cooldown; reset por éxito |
| F10.2 | `internal/ai` → `internal/biaos` | Originales en _legacy (SFP-01); bosctl ask redirigido |
| F10.3 | ICAP: catálogo + coseno/términos | **NeverGeneratesCommands** — ni con "rm -rf /" |
| F10.4 | SagaEngine: DAG+paralelo+compensación+persistencia | **CompensatesOnCrash** — recuperación post-muerte del daemon |
| F10.5 | Agente ReAct | TIPO A ejecuta y observa; trayectoria registrada |
| F10.6 | HITL | TTL 5min, sesión de un solo uso, **ExpiresAfterTimeout** |
| F10.7 | Guardrails | **DomainGuard_RejectsBusinessData** (ventas/facturas → rechazo); RBAC; **Audit_AlwaysBeforeToolExecution** |
| F10.8 | `bos.ai.ask/run/confirm/catalog` + ToolExecutor | Flujo completo ICAP→dispatcher real en test de integración |
| F10.9 | `bosctl ai export-training` | Audit JSONL → ejemplos SFT agrupados por intención |

## Decisiones técnicas no obvias

1. **ToolExecutor = el propio dispatcher**: las herramientas del agente son
   los métodos del rpcRegistry invocados internamente como caller confiable
   (biaos ya aplicó dominio+RBAC+HITL). Sin duplicar transporte ni auth.
2. **El agente no inventa parámetros**: el ICAP elige la ACCIÓN; los
   argumentos estructurados (ficha_id, node…) los provee el caller
   (`params` en bos.ai.run). Un LLM que adivina ficha_ids es un riesgo, no
   una comodidad.
3. **LLM opcional por diseño**: sin API keys ni Ollama, el ICAP degrada a
   coincidencia por términos (determinista). La seguridad nunca depende de
   la disponibilidad del LLM; solo la calidad de redacción.
4. **Auditoría que no se pierde**: canal buffereado que BLOQUEA si se llena
   (descartar auditoría violaría A.8.15) y drena al cerrar.

## DoD del cierre (local)

```
go build ./...                              ✅
go vet ./...                                ✅
gofmt (sin _legacy)                         ✅ 0
go test -race ./...                         ✅ 27 paquetes, 0 FAIL
TestICAPEngine_NeverGeneratesCommands       ✅
TestSagaEngine_CompensatesOnCrash           ✅
TestDomainGuard_RejectsBusinessData         ✅
TestHITL_ExpiresAfterTimeout                ✅
TestAudit_AlwaysBeforeToolExecution         ✅
TestAIRun_FlujoCompleto (dispatcher real)   ✅
```

## ⚠️ Pendiente — validación en servidor real

El VPS 13.140.128.230 bloqueó el acceso SSH (2026-06-10/11) por la
intensidad de conexiones del ciclo deploy-validación de F9/F10. El servidor
quedó ESTABLE con el binario F9 (shutdown seguro F9.0; cluster Ready).

Al recuperar acceso, ejecutar **scripts/DEPLOY-VALIDACION-F10.sh** — hace
todo EN UNA SOLA sesión SSH: backup, deploy de binarios+catálogo, restart,
y la batería completa (bos.ai.catalog, bos.ai.run del caso real
kube-state-metrics, HITL confirm, export-training, métricas, regresión F6/F9).
Lección aprendida codificada: nunca más 20 conexiones SSH en una sesión.

## Estado final del plan

**90/90 átomos en código — TODAS las fases completas.** El criterio
definitivo del Plan Maestro (PARTE V, flujo end-to-end `bosctl vdi
test-repair`) requiere el VDI Layer desplegado y queda enlazado a la
validación pendiente + bootstrap completo del VDI.

---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*
*Co-Autor (IA): Claude Fable 5 — Anthropic*
