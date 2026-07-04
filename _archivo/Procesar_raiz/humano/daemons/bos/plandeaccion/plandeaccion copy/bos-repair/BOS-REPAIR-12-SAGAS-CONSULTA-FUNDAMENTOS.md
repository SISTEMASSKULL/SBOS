# BOS-REPAIR-12 — Fundamentos de las Sagas de Consulta JSON-RPC
## Marco normativo, estándares internacionales y evidencia de industria
## SKULL · SBOS · BOS-REPAIR · v1.0 · Junio 2026

**Cierra:** BOS-REPAIR Gap 3 — F6.6..F6.15 sin respaldo normativo en el plan maestro  
**Complementa:** BOS-REPAIR-04 (implementación técnica de las sagas)  
**Actualiza:** BOS-REPAIR-05 §Fase 6 y §Registro de Progreso  
**Conecta con:** BOS-REPAIR-10 (biaos usa estas sagas como herramientas primarias)

---

## Por qué este documento existe

BOS-REPAIR-04 define las 10 tareas F6.6..F6.15 de las sagas de consulta con
implementación técnica completa. Lo que faltaba era el respaldo normativo que
justifica por qué estas sagas no son opcionales sino una práctica obligatoria
de ingeniería de confiabilidad de sitio (SRE), y cómo se conectan con los
estándares ITIL 4, ISO 20000, OpenTelemetry CNCF y AIOps.

Este documento cierra ese vacío y actualiza el plan maestro con los fundamentos
que convierten las sagas de consulta de "funcionalidad deseable" a "componente
requerido por estándares de industria".

---

## Parte 1 — El estándar que lo define: OpenTelemetry CNCF (Graduado Mayo 2026)

### 1.1 El estándar de facto de observabilidad

El Cloud Native Computing Foundation anunció la graduación de OpenTelemetry como estándar de observabilidad vendor-neutral de facto para la recolección, procesamiento y exportación de telemetría. OpenTelemetry resuelve la fragmentación de herramientas y simplifica la observabilidad proveyendo un único estándar, permitiendo a las organizaciones cambiar herramientas de análisis sin reescribir código.

Para el SBOS esto tiene una implicación directa: las sagas de consulta `bos.query.*`
son la implementación del principio OpenTelemetry aplicado a la capa OS. En lugar
de fragmentar la observabilidad en 8 llamadas secuenciales a herramientas distintas,
el bos agrega métricas, logs y estado del sistema en una sola llamada estructurada
con correlación por `ctx_id` (W3C Trace Context).

### 1.2 OTel como "pegamento" de las sagas de consulta

OpenTelemetry provee un único conjunto de APIs, SDKs, Collector agent y convenciones semánticas, permitiendo a las organizaciones cambiar backends de observabilidad sin re-instrumentar todo su código.

Las sagas `bos.query.*` siguen exactamente este principio: el llamador obtiene
una vista compuesta sin importar si los datos provienen de Ubuntu (CPU/disco),
Kubernetes (pods/nodos) o el Context Plane (ctx_id activos). El `bos.query.system`
es el Collector de OpenTelemetry del SBOS — agrega múltiples señales en una
respuesta estructurada con el `traceparent` del contexto actual.

### 1.3 SLI/SLO: la obligación de medir

Un SLI representa una medición del comportamiento de un servicio desde la perspectiva del usuario. Un SLO representa el medio por el cual la confiabilidad se comunica a la organización. Esto se logra vinculando uno o más SLIs a valor de negocio.

Los SLOs definidos en BOS-REPAIR-01 y BOS-REPAIR-04 (postgresql 99.95%, VDI 99.0%,
Context Plane p99 < 2s) **solo pueden monitorearse** si existe una saga de consulta
que los exponga de forma estructurada. Sin `bos.query.system` emitiendo las métricas
correctas, los SLOs son compromisos sin verificación.

---

## Parte 2 — Google SRE: diagnóstico antes de remediar es la regla, no la excepción

### 2.1 El principio SRE que justifica bos.query.repair

Una táctica es intencionalmente retrasar el trabajo de toil para que las tareas se acumulen para procesamiento en batch o paralelo. Trabajar con toil en agregados más grandes reduce interrupciones y ayuda a identificar patrones de toil, que luego se pueden atacar para su eliminación.

La saga `bos.query.repair` implementa exactamente este principio. En lugar de
que el operador ejecute 8 comandos secuenciales para diagnosticar un fallo, el
bos ejecuta esas 8 consultas en paralelo y retorna el diagnóstico completo.
El toil de diagnóstico manual queda eliminado.

### 2.2 Google InvD: la referencia de producción más validada

Google's Investigation Dashboards (InvD) opera como un ecosistema extensible que integra más de cien "troubleshooters" especializados por dominio que ejecutan verificaciones automáticas de síntomas en paralelo. Una vez identificada la causa raíz con alta confianza, InvD facilita la recuperación rápida ejecutando acciones remediales directamente desde runbooks integrados. Por reemplazar la recolección manual de datos con detección de anomalías basada en ML, InvD entregó una reducción del 44% en el Mean Time to Mitigate (MTTM) para incidentes soportados.

El patrón de `bos.query.repair` es directamente análogo a InvD de Google:
múltiples "troubleshooters" especializados (watchdog, stateMgr, healthChecker,
audit log) ejecutando en paralelo, agregando resultados, e identificando la
causa raíz antes de presentar opciones de remediación al operador.

**La reducción de MTTM del 44% en Google justifica por sí sola la implementación
de las sagas de consulta.** Para el SBOS, con operadores de PYME boliviana sin
formación DevOps, el impacto es aún mayor.

### 2.3 SRE: diagnóstico sin datos reales es irresponsable

El toil es impulsado por interrupciones y reactivo, en lugar de estratégico y proactivo. Si tu servicio permanece en el mismo estado después de que finalizaste una tarea, la tarea probablemente fue toil. Si la tarea produjo una mejora permanente en tu servicio, probablemente no fue toil.

Ejecutar `bos.ficha.repair` sin primero ejecutar `bos.query.repair` es toil en
su forma más pura: reactivo, sin contexto, y con alta probabilidad de no resolver
la causa raíz. El estándar SRE exige diagnóstico antes de remediación.

---

## Parte 3 — AIOps: la industria converge en diagnóstico paralelo pre-remediación

### 3.1 AIOps como estándar emergente para K8s

El framework propuesto usa machine learning para detectar anomalías, identificar causas y predecir necesidades de escalado ANTES de ejecutar pasos de remediación automática. La metodología demuestra que AIOps puede mejorar la confiabilidad del sistema y reducir el toil operacional mientras optimiza la eficiencia de recursos mediante ciclos cerrados de observación-acción.

Las sagas de consulta del bos implementan el ciclo de observación del modelo AIOps:
primero `bos.query.system` observa, luego `bos.query.repair` analiza causas,
luego el ICAP Engine de biaos propone la acción correcta.

### 3.2 Runbooks ejecutables: el estándar que bos.query.repair implementa

Un runbook agéntico es un conjunto estructurado de pasos de diagnóstico y remediación que un agente de IA ejecuta autónomamente cuando se dispara una condición definida. Cuando un trigger dispara — un OOM kill, una interrupción Spot, o un CrashLoopBackOff — el agente ejecuta el runbook: verifica prerequisitos, reúne datos de diagnóstico, aplica el fix, verifica el resultado, y reporta. La investigación académica de Punniyamoorthy et al. (2025) demuestra que el autoscaling basado en señales SLO supera a los enfoques basados en umbrales tanto en confiabilidad como en costo.

`bos.query.repair` implementa la fase "reúne datos de diagnóstico" del runbook
agéntico. Sin ella, el agente biaos no tiene los datos necesarios para ejecutar
las fases siguientes del runbook.

### 3.3 Kubernaut: referencia de arquitectura más cercana al bos

Kubernaut cierra el ciclo desde la alerta de Kubernetes hasta la remediación automática. Cuando algo falla en el cluster, Kubernaut detecta la señal, la envía a un agente LLM que investiga la causa raíz usando bindings nativos client-go contra la API de Kubernetes, logs y endpoints de Prometheus, selecciona un workflow de remediación, y ejecuta el fix — o escala a un humano con un RCA completo cuando no puede resolverlo.

La arquitectura de Kubernaut (bindings nativos → investigación paralela → selección
de workflow → HITL cuando no puede resolverlo) es exactamente la arquitectura del
bos: `bos.query.*` (investigación paralela) → ICAP Engine (selección de workflow) →
HITL (confirmación del operador). Las sagas de consulta son la capa de investigación
de esta arquitectura.

---

## Parte 4 — ITIL 4 e ISO 20000: los estándares de gestión de servicios

### 4.1 ITIL 4: monitoreo antes de diagnóstico, diagnóstico antes de remediación

ITIL 4 define cuatro prácticas aplicables directamente a las sagas de consulta:

| Práctica ITIL 4 | Saga de consulta que la implementa |
|---|---|
| **Service Monitoring** — observación continua del estado del servicio | `bos.query.system` (cada 30s en watchdog) |
| **Incident Diagnosis** — identificar causa antes de remediar | `bos.query.repair` (pre-check del watchdog) |
| **Problem Management** — análisis de causa raíz de incidentes recurrentes | `bos.query.repair` con historial de reparaciones |
| **CMDB / Configuration Management** — registro de estado de CIs | `bos.query.system` como CMDB en tiempo real |

ITIL Service Level Management funciona como un ciclo continuo basado en: inputs (requerimientos de negocio y expectativas de servicio), acuerdos (SLAs respaldados por SLOs y OLAs), monitoreo de performance y mejora continua basada en datos reales del servicio.

Las sagas `bos.query.*` son el mecanismo de monitoreo de performance que permite
al bos ejecutar este ciclo ITIL. Sin ellas, los SLOs definidos en BOS-REPAIR-01
son compromisos sin datos.

### 4.2 ISO 20000: la obligación de diagnóstico correlacionado

ISO 20000 es el estándar internacional aplicable a organizaciones de todos los tamaños en todas las geografías. Las organizaciones que buscan auditar y revisar el performance de su sistema de gestión de servicios (SMS) utilizan ISO 20000 como benchmark para desarrollar procesos de gestión de servicios con mayor eficiencia y productividad.

Para una certificación ISO 20000 del SBOS, las sagas `bos.query.*` son el mecanismo
que produce los datos auditables requeridos. El `bos.query.repair` genera exactamente
el reporte de diagnóstico que un auditor ISO 20000 requeriría ver antes de una
operación de remediación.

---

## Parte 5 — Conexión con biaos: por qué F6.6..F6.15 bloquean la Fase 10

### 5.1 La dependencia de biaos en las sagas de consulta

biaos (BOS-REPAIR-10) no puede operar sin las sagas de consulta de la Fase 6.
El agente ReAct TIPO A usa obligatoriamente:

```
Primera iteración de CUALQUIER consulta:
  Action: query_system_status → bos.query.system (F6.7)

Diagnóstico de ficha degradada:
  Action: diagnose_ficha → bos.query.repair (F6.8)

Estado del VDI Layer:
  Action: vdi_status → bos.query.vdi (F6.9)

Diagnóstico de nodo antes de mantenimiento:
  Action: check_node → bos.query.node (F6.11)
```

Si la Fase 6 no implementa F6.6..F6.15, la Fase 10 (biaos) no puede compilar
correctamente — las herramientas de su catálogo ICAP apuntan a métodos RPC
que no existen.

### 5.2 El watchdog: F6.14 no es opcional

La tarea F6.14 (watchdog usa `bos.query.repair` antes de auto-repair) está
directamente respaldada por el principio AIOps de diagnóstico pre-remediación:

```go
// internal/watchdog/unified_watchdog.go — comportamiento requerido
func (w *UnifiedWatchdog) handleDegradada(fichaID string) {
    // SIN F6.14: el watchdog repara a ciegas — potencial de empeorar el estado
    // CON F6.14: diagnóstico completo primero (causa, impacto, usuarios afectados)
    //           → decisión informada de si reparar automáticamente o alertar al operador

    diagnosis, err := w.querySvc.Repair(fichaID, w.tenantID)
    if diagnosis.Impacto.UsuariosAfectados > 50 {
        // ISO 27001 A.8.15: registrar decisión antes de no actuar
        audit.Log("WATCHDOG_DEFER", "reason=high_impact", "users="+strconv.Itoa(...))
        // HITL obligatorio para alta impacto — no auto-reparar
        return
    }
    w.repairMgr.Repair(fichaID)
}
```

---

## Parte 6 — Actualización del Plan Maestro BOS-REPAIR-05

### 6.1 Sección §Fase 6 — agregar a la descripción existente

```
ADICIÓN A §Fase 6 — JSON-RPC robusto:

Además de F6.1..F6.5 (robustecimiento del dispatcher existente), la Fase 6
incluye la implementación del módulo bos.query.* — las sagas de consulta
multi-fuente en paralelo definidas en BOS-REPAIR-04.

Marco normativo que obliga su implementación:
  - OpenTelemetry CNCF (Graduado Mayo 2026): estándar de facto de observabilidad
  - Google SRE InvD: diagnóstico paralelo pre-remediación → 44% reducción MTTM
  - ITIL 4 Service Monitoring + Incident Diagnosis
  - ISO 20000: diagnóstico correlacionado requerido para auditoría
  - AIOps (Kubernaut, Cast AI 2025): ciclo observación→diagnóstico→acción
  - BOS-REPAIR-10 §biaos: dependencia directa de estas sagas como herramientas
    del agente ReAct

Prerequisito para Fase 10 (biaos): F6.6..F6.15 deben estar completas antes
de iniciar F10.1. El catálogo ICAP de biaos referencia bos.query.* como
herramientas primarias.
```

### 6.2 Tareas F6.6..F6.15 con checkboxes para el registro de progreso

```
Estado de las tareas F6.6..F6.15:
  F6.6  ☐ internal/query/ — paquete nuevo para sagas de consulta paralelas
  F6.7  ☐ jsonrpc: registrar bos.query.system (threads: ubuntu+k8s+fichas+ctx+health+cert)
  F6.8  ☐ jsonrpc: registrar bos.query.repair (threads: state+probe+hashes+deps+audit+logs+ctx+scaler)
  F6.9  ☐ jsonrpc: registrar bos.query.vdi (threads: nextcloud+guacamole+fedora+ctx+e2e+iso)
  F6.10 ☐ jsonrpc: registrar bos.query.tenant (threads: fichas+ctx+k8s+nc+kc+audit+devices)
  F6.11 ☐ jsonrpc: registrar bos.query.node (threads: k8s+ubuntu+fichas+events+audit+maint)
  F6.12 ☐ jsonrpc: registrar bos.query.context (threads: summary+anomalias+metricas)
  F6.13 ☐ cmd/bosctl/query.go — bosctl query <tipo> [--tenant=X] [--output=json|table]
  F6.14 ☐ internal/watchdog: usar bos.query.repair ANTES de auto-repair (diagnóstico previo)
  F6.15 ☐ Tests: TestQuerySystem_AllSourcesParallel
               TestQueryRepair_DiagnosisBefore_Repair
               TestQueryVdi_SemaforoCalculation
               TestQueryNode_CapacityCheck
               TestWatchdog_DiagnosesBeforeRepair
```

### 6.3 Señal de retoma para F6.6..F6.15

```bash
# Verificar estado de implementación de sagas de consulta:
echo "=== Sagas de Consulta (F6.6..F6.15) ==="
echo -n "F6.6 paquete internal/query: "
[ -d internal/query ] && echo "✅" || echo "❌"

echo -n "F6.7..F6.12 métodos RPC: "
grep -q "bos.query.system" internal/server/jsonrpc.go && echo "✅" || echo "❌"

echo -n "F6.13 bosctl query: "
[ -f cmd/bosctl/query.go ] && echo "✅" || echo "❌"

echo -n "F6.14 watchdog pre-diagnose: "
grep -q "querySvc.Repair" internal/watchdog/unified_watchdog.go && echo "✅" || echo "❌"

echo -n "F6.15 tests: "
[ -f internal/query/query_test.go ] && echo "✅" || echo "❌"
```

### 6.4 Criterio de completitud F6.6..F6.15

```bash
go build ./...
go test ./internal/query/...

# Verificar que las 6 sagas están registradas
bosctl rpc system.listMethods | grep "bos.query" | wc -l
# debe ser 6

# Verificar que bosctl query funciona
bosctl query system --output=json | jq '.semaforo'
bosctl query repair redis --tenant=skull | jq '.recomendacion'

# Verificar F6.14
grep -n "querySvc\|query.Repair" internal/watchdog/unified_watchdog.go
# debe retornar al menos 1 resultado

# SLOs de las sagas (según BOS-REPAIR-04):
# bos.query.system p99 < 5s
# bos.query.repair p99 < 5s
# bos.query.vdi    p99 < 3s
# bos.query.node   p99 < 3s
# bos.query.context p99 < 2s
```

---

## Parte 7 — Actualización de BOS-REPAIR-05 §Fase 10 (biaos F10.1..F10.24)

### 7.1 Por qué la Fase 10 también necesita estar en el plan maestro

BOS-REPAIR-10 define 24 tareas F10.1..F10.24 con especificación completa.
El plan maestro BOS-REPAIR-05 no las tiene. Un agente que trabaje solo con
BOS-REPAIR-05 nunca ejecutaría biaos.

### 7.2 Tareas F10.1..F10.24 para el registro de progreso

```
Estado de las tareas F10.1..F10.24 (biaos):
  F10.1  ☐ /etc/bos/ai/action_catalog.yml — catálogo ICAP (TIPO A y B)
  F10.2  ☐ /etc/bos/ai/sagas/repair-ficha.yml — saga con compensación
  F10.3  ☐ /etc/bos/ai/sagas/node-maintain.yml — saga con uncordon siempre
  F10.4  ☐ /etc/bos/ai/sagas/upgrade-ficha.yml — saga con rollback automático
  F10.5  ☐ /etc/bos/ai/Modelfile.biaos — especialización OS-only (Fase 1 entrenamiento)
  F10.6  ☐ internal/biaos/doc.go — godoc: propósito dual + frontera de dominio
  F10.7  ☐ internal/biaos/gateway.go — Gateway singleton sync.Once
  F10.8  ☐ internal/biaos/router.go — migrar de internal/ai/model_router.go
  F10.9  ☐ internal/biaos/client.go — migrar de internal/ai/client.go
  F10.10 ☐ internal/biaos/agent.go — ReAct loop TIPO A (lectura, ≤6 iter)
  F10.11 ☐ internal/biaos/safety.go — RBAC + guardia dominio (ADR-006)
  F10.12 ☐ internal/biaos/session.go — HITL state (map + RWMutex + TTL)
  F10.13 ☐ internal/biaos/prompt.go — System Prompt OS-only
  F10.14 ☐ internal/biaos/icap/catalog.go — carga YAML + pre-calcula vectores coseno
  F10.15 ☐ internal/biaos/icap/engine.go — ExecuteAction Absorb/Execute/Release
  F10.16 ☐ internal/biaos/icap/embed.go — embeddings Ollama API + cosine similarity
  F10.17 ☐ internal/biaos/sagas/engine.go — SagaEngine (Parte 9 JSON-RPC manual)
  F10.18 ☐ internal/biaos/sagas/loader.go — carga sagas/*.yml
  F10.19 ☐ internal/biaos/sagas/store.go — persistencia ejecuciones en filesystem
  F10.20 ☐ internal/biaos/audit/logger.go — ISO 27001 A.8.15 async canal buffereado
  F10.21 ☐ jsonrpc: bos.ai.ask + bos.ai.run + bos.ai.confirm + bos.ai.catalog
  F10.22 ☐ cmd/bosctl/ask.go → migrar a bos.ai.run via JSON-RPC
  F10.23 ☐ bosctl ai dataset build — extrae trayectorias del audit log para SFT
  F10.24 ☐ Tests: TestICAPEngine_NeverGeneratesCommands
               TestSaga_AlwaysUncordonOnFail
               TestBatchQuery_ExecutesParallel
               TestGateway_CompassCannotRunAgent
               TestDomainGuard_RejectsBusinessData
               TestAudit_AlwaysBeforeToolExecution
               TestHITL_ExpiresAfterTimeout
```

### 7.3 Señal de retoma para F10.1..F10.24

```bash
echo "=== biaos (F10.1..F10.24) ==="
echo -n "F10.1 action_catalog.yml: "
[ -f /etc/bos/ai/action_catalog.yml ] && echo "✅" || echo "❌"

echo -n "F10.5 Modelfile.biaos: "
ollama show biaos &>/dev/null && echo "✅" || echo "❌"

echo -n "F10.7 gateway singleton: "
grep -q "sync.Once" internal/biaos/gateway.go 2>/dev/null && echo "✅" || echo "❌"

echo -n "F10.8 model_router migrado: "
[ -f internal/biaos/router.go ] && echo "✅" || echo "❌"

echo -n "F10.14 catálogo ICAP: "
[ -f internal/biaos/icap/catalog.go ] && echo "✅" || echo "❌"

echo -n "F10.17 saga engine: "
[ -f internal/biaos/sagas/engine.go ] && echo "✅" || echo "❌"

echo -n "F10.21 bos.ai.ask RPC: "
grep -q "bos.ai.ask" internal/server/jsonrpc.go 2>/dev/null && echo "✅" || echo "❌"

echo -n "internal/ai eliminado: "
[ -d internal/ai ] && echo "❌ (pendiente migración)" || echo "✅"
```

---

## Resumen: los 3 estándares que hacen obligatorias las F6.6..F6.15

| Estándar | Mandato específico | Saga que lo cumple |
|---|---|---|
| **OpenTelemetry CNCF** (Graduado Mayo 2026) | Observabilidad unificada — métricas, logs y trazas en una sola señal | `bos.query.system` agrega Ubuntu+K8s+fichas+ctx |
| **Google SRE InvD** | Diagnóstico paralelo pre-remediación → 44% reducción MTTM | `bos.query.repair` agrega 8 fuentes antes del repair |
| **ITIL 4 + ISO 20000** | Service Monitoring + Incident Diagnosis como prácticas obligatorias de ITSM | `bos.query.*` como implementación del loop ITIL |
| **AIOps / Kubernaut 2025** | Ciclo observación→diagnóstico→selección de acción→HITL | `bos.query.*` como capa de observación del ciclo |
| **BOS-REPAIR-10 §biaos** | El agente ReAct no puede operar sin herramientas de consulta | F6.7..F6.12 son prerequisito de F10.1..F10.24 |

---

## Changelog

| Fecha | Versión | Cambio |
|---|---|---|
| Junio 2026 | 1.0 | Versión inicial — cierra Gap 3 con respaldo normativo completo |

---

*BOS-REPAIR-12 — SKULL · SBOS · Junio 2026*  
*Cierra: Gap 3 — F6.6..F6.15 sin respaldo normativo en el plan maestro*  
*Referencia: BOS-REPAIR-04 (implementación técnica), BOS-REPAIR-05 (plan maestro)*  
*Referencia: BOS-REPAIR-10 (biaos — dependencia de F6.6..F6.15)*  
*Estándares: OpenTelemetry CNCF, Google SRE InvD, ITIL 4, ISO 20000, AIOps 2025*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
