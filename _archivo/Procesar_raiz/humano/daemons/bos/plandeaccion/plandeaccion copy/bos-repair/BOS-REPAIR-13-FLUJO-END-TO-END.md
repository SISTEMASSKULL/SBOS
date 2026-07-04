# BOS-REPAIR-13 — Flujo End-to-End de Reparación
## La secuencia completa: lenguaje natural → sagas → verificación → usuario
## SKULL · SBOS · BOS-REPAIR · v1.0 · Junio 2026

**Cierra:** BOS-REPAIR Gap 4 — flujo end-to-end no documentado como secuencia coherente  
**Conecta:** BOS-REPAIR-01 (5 capas) + BOS-REPAIR-04 (sagas consulta) +
            BOS-REPAIR-08 (Context Plane) + BOS-REPAIR-09 (VDI) +
            BOS-REPAIR-10 (biaos) + BOS-REPAIR-11 (RBAC)  
**Marco normativo:** ITIL 4 Major Incident Management, W3C Trace Context,
                    ISO 27001 A.8.15, Google SRE InvD

---

## Por qué este documento existe

Los documentos del proyecto BOS-REPAIR describen cada componente con precisión.
Lo que ninguno describe es **cómo se mueven todos juntos** cuando ocurre un
incidente real: desde el momento en que el operador dice algo en lenguaje
natural hasta que el usuario puede trabajar de nuevo y el audit trail queda
completo en ISO 27001.

El Gap 4 es exactamente ese flujo completo. No es un componente nuevo — es
la **narración de secuencia** que conecta todo lo que ya está documentado.

---

## El marco ITIL 4 que estructura el flujo

ITIL 4 Major Incident Management define cuatro etapas obligatorias para
cualquier incidente significativo: identificación y registro, investigación
y diagnóstico, resolución y recuperación, y revisión post-incidente. Para el
SBOS estas cuatro etapas se mapean directamente a los componentes ya construidos.

Cada etapa tiene su responsable, sus herramientas y su criterio de salida.
El flujo end-to-end es la secuencia de estas etapas ejecutada por el bos.

### Tabla de mapeo ITIL 4 → SBOS

| Etapa ITIL 4 | Responsable SBOS | Herramienta | Criterio de salida |
|---|---|---|---|
| Identificación y registro | watchdog (automático) o operador (manual) | bos.query.system / biaos NL | Incidente registrado en audit log con ctx_id |
| Investigación y diagnóstico | biaos ReAct + bos.query.repair | Sagas de consulta paralelas | Causa raíz identificada con evidencia real |
| Resolución y recuperación | SagaEngine + ICAP + HITL | repair-ficha.yml / RBAC ADR-006 | C-0X verificado, ctx_id restaurado, usuario operativo |
| Revisión post-incidente | audit log + metrics | ISO 27001 A.8.15 | Registro completo con traceparent correlacionado |

---

## El flujo completo — caso canónico: "nextcloud no abre"

Este es el flujo más representativo porque involucra todas las capas:
infraestructura (Capa 1-2), Context Plane (Capa 3), VDI Layer (Capa 4)
y experiencia del usuario (Capa 5).

```
═══════════════════════════════════════════════════════════════════════
FLUJO END-TO-END — Incidente: nextcloud DEGRADADA
Iniciado por: operador via lenguaje natural
Duración típica: 8-12 minutos
Correlación: traceparent propagado en todos los eventos
═══════════════════════════════════════════════════════════════════════

ETAPA 0 — DETECCIÓN (t=0:00)
══════════════════════════════
  CASO A — Detección automática (watchdog):
    UnifiedWatchdog (tick 30s) detecta nextcloud probe FAIL
    → Estado: DEGRADADA en stateMgr
    → Antes de auto-repair: bos.query.repair {"ficha_id":"nextcloud"}
    → Si usuarios_afectados > 50: defer repair, emitir alerta HITL
    → audit.Log("WATCHDOG_DETECT", "ficha=nextcloud", "causa=OOMKilled")

  CASO B — Detección por operador (biaos NL):
    Operador: "bos, nextcloud no abre"
    → biaos.RunAgent() → intención: INVESTIGATE, target: nextcloud

──────────────────────────────────────────────────────────────────────

ETAPA 1 — INVESTIGACIÓN PARALELA (t=0:00 → t=0:02)
═════════════════════════════════════════════════════
  biaos ReAct — Iteración 1:
    Thought: "Necesito el estado completo antes de diagnosticar nextcloud"
    Action:  query_system_status {}

  bos dispatcher recibe bos.query.system
    → Thread 1: watchdog.CheckUbuntu()    → {cpu:45%, mem:62%}
    → Thread 2: watchdog.CheckK8s()       → {nodes: Ready}
    → Thread 3: stateMgr.Read()           → {nextcloud: DEGRADADA}
    → Thread 4: ctxSvc.ListByTenant()     → {ctx_activos: 12}
    → Thread 5: healthChecker.CheckAll()  → {nextcloud: FAIL}
    Agrega en paralelo → retorna en 1.8s

  Observation: {semaforo: "ROJO", nextcloud: "DEGRADADA", usuarios_afectados: 12}

  biaos ReAct — Iteración 2:
    Thought: "nextcloud DEGRADADA con 12 usuarios. Necesito diagnóstico específico"
    Action:  diagnose_ficha {"ficha_id": "nextcloud"}

  bos dispatcher recibe bos.query.repair
    → Thread 1: stateMgr.Get("nextcloud")      → state: DEGRADADA, 8m32s
    → Thread 2: healthChecker.Probe("nextcloud")→ probe FAIL, port 28300 refused
    → Thread 3: reconciler.GetHashes()          → no drift detectado
    → Thread 4: stateMgr.GetDependencies()      → postgresql OK, keycloak OK
    → Thread 5: audit.GetLastRepairs()          → 2 reparaciones previas exitosas
    → Thread 6: k8sCore.GetPodLogs("nextcloud") → "OOMKilled at 14:23:12"
    → Thread 7: ctxSvc.CountByFicha()           → 12 ctx_id activos
    → Thread 8: scaler.GetPolicy()              → memory_limit: 4Gi
    Agrega en paralelo → retorna en 2.1s

  Observation:
    causa_probable: "OOMKilled — memoria insuficiente (3.9/4.0 GB)"
    drift: false
    ctx_afectados: 12
    home_desmontado_en_pods: 3
    ultima_reparacion: "hace 2 días, exitosa"

──────────────────────────────────────────────────────────────────────

ETAPA 2 — ICAP + HITL (t=0:02 → t=0:04)
══════════════════════════════════════════
  biaos genera embedding de la consulta + diagnosis
    → Búsqueda coseno en action_catalog.yml:
      repair_ficha:      score 0.91 ← mejor coincidencia
      scale_deployment:  score 0.73
      get_logs:          score 0.44

  biaos enriquece TOP-2 con LLM (datos reales del diagnóstico):
    [1] repair_ficha — Coincidencia 91%
        Causa detectada: OOMKilled (3.9/4.0 GB)
        Impacto: 12 usuarios sin acceso, 3 homes desmontados
        Riesgo: downtime adicional ~5-8 minutos durante reparación
        Beneficio: servicio restaurado con estado limpio
        Parámetros: ficha_id=nextcloud

    [2] scale_deployment — Coincidencia 73%
        Ajustar memory_limit de 4Gi → 8Gi
        Riesgo: pod restart ~2-3 minutos
        Beneficio: previene recurrencia del OOMKilled
        Parámetros: ficha_id=nextcloud, memory_limit=8Gi

  biaos presenta al operador:
    "🔴 nextcloud — DEGRADADA (OOMKilled — 12 usuarios afectados)

     [1] repair_ficha (91%) — Reparación inmediata
         Downtime adicional: ~5-8 min | Restaura estado limpio
     [2] scale_deployment (73%) — Aumentar memoria a 8Gi
         Downtime: ~2-3 min | Previene recurrencia

     ¿Qué opción ejecuto? (1/2/cancelar)"

  VERIFICACIÓN RBAC (ADR-006) antes de mostrar opciones de acción:
    K8s impersonation check: ¿tiene el operador ClusterRole bos:operator?
      SÍ → opciones disponibles
      NO → "Acceso denegado: requiere ClusterRole bos:operator"

  Operador responde: "1"

  HITL confirmado → bos.ai.confirm:
    {session_id: "sess-abc123", selected: "repair_ficha",
     params: {ficha_id: "nextcloud"}, confirmed: true}

──────────────────────────────────────────────────────────────────────

ETAPA 3 — SAGA DE REPARACIÓN (t=0:04 → t=0:12)
═════════════════════════════════════════════════
  SagaEngine.Execute("repair-ficha", {ficha_id: "nextcloud"})

  El ctx_id del operador se propaga a CADA llamada RPC (W3C Trace Context):
    traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
    baggage: tenant.id=skull, ctx.id=ctx-88291-a4f9, saga.id=repair-ficha

  Paso 1: pre-diagnose (bos.query.repair) ← ya ejecutado, reusar resultado
    → diagnosis guardado: causa=OOMKilled, snapshot disponible
    ✓ audit.Log("SAGA_STEP_OK", "paso=pre-diagnose")

  Paso 2: validate-safe-to-repair (bos.query.system)
    → Verifica: ¿cluster tiene capacidad para absorber la reparación?
    → {cpu:45%, mem:62%, fichas_degradadas:1} → SÍ, es seguro
    ✓ audit.Log("SAGA_STEP_OK", "paso=validate")

  Paso 3: execute-repair (bos.ficha.repair)
    → 00_MASTER_INSTALL_SBOS.sh repair nextcloud
       Step: validate ✓
       Step: pre_install ✓
       Step: install (reinstala pod nextcloud) ...
       Step: post_install ✓
       Step: verify (probe nextcloud) ✓
    → repair_result.snapshot_id = "snap-abc-123"
    ✓ audit.Log("SAGA_STEP_OK", "paso=execute-repair", "duracion=7m14s")

  Paso 4: verify-recovery (bos.ficha.probe)
    → GET http://nextcloud:28300/status.php → {installed:true, maintenance:false}
    → healthy: true
    ✓ audit.Log("SAGA_STEP_OK", "paso=verify-recovery")

  stateMgr.Transition("nextcloud", StateInstalada)
  audit.Log("SAGA_COMPLETED", "ficha=nextcloud", "duracion=8m02s",
            "traceparent=00-4bf92...")

──────────────────────────────────────────────────────────────────────

ETAPA 4 — RESTAURACIÓN DEL CONTEXT PLANE (t=0:12 → t=0:13)
══════════════════════════════════════════════════════════════
  El repair de nextcloud restauró los pods. El Context Plane debe verificarse:

  Para cada pod nextcloud recién levantado:
    sbos-client.service arranca automáticamente
    sbos-client contacta bhnexus via mTLS
    bos recibe: nuevo dctx_id para el pod restaurado
    bos promueve: dctx_id → ctx_id de servicio (hardware_type: "service_pod")

  Para los 12 usuarios con ctx_id afectados:
    Los ctx_id previos siguen válidos en Redis DB1 (no se invalidaron)
    Los homes de Nextcloud se remontan automáticamente cuando el pod está Ready
    → ctxSvc.CountHomeMounted() → 3/3 (antes 0/3)

  Verificación Context Plane:
    bosctl query context --tenant=skull
    → ctx_activos: 12, dctx_activos: 1 (pod restaurado)
    → home_montado_pct: 100% ✓
    → bitmask_cero_count: 0 ✓

──────────────────────────────────────────────────────────────────────

ETAPA 5 — VERIFICACIÓN VDI LAYER (t=0:13 → t=0:14)
══════════════════════════════════════════════════════
  biaos ejecuta saga post-reparación para verificar que el VDI Layer
  está completamente operativo:

  bos.query.vdi {"tenant_id": "skull"}
    → Thread 1: k8sCore.GetPodsReady("nextcloud")  → 2/2 Running ✓
    → Thread 2: nextcloudClient.Health()           → installed:true ✓
    → Thread 3: ctxSvc.CountHomeMounted()          → 3/3 ✓
    → Thread 4: k8sCore.GetPodsReady("guacamole")  → 1/1 Running ✓
    → Thread 5: k8sCore.GetPodsReady("fedora-logico") → 3/3 Running ✓
    Agrega en 1.2s

  Resultado: semaforo_vdi: "VERDE"

  biaos responde al operador:
    "✅ nextcloud — REPARADO (8m02s)

     Estado post-reparación:
     • nextcloud: INSTALADA — 2/2 pods Running
     • 12 usuarios con acceso restaurado
     • 3/3 homes Nextcloud montados
     • VDI Layer: VERDE (todos los componentes operativos)

     Sugerencia: aumentar memory_limit a 8Gi para prevenir recurrencia:
     bosctl rpc bos.ficha.scale '{\"ficha_id\":\"nextcloud\",
       \"memory_limit\":\"8Gi\"}'

     Criterio C-09 verificado ✓"

──────────────────────────────────────────────────────────────────────

ETAPA 6 — VERIFICACIÓN POR EL OPERADOR (t=0:14 → t=0:16)
══════════════════════════════════════════════════════════
  Verificación rápida (< 30s):
    bosctl rpc bos.state.read | jq '.fichas.nextcloud'
    → {state: "INSTALADA", health: "OK"} ✓

  Verificación estándar (< 2min):
    bosctl bootstrap verify   → C-09: ✓ nextcloud
    bosctl query vdi --tenant=skull → semaforo_vdi: VERDE ✓

  Verificación de usuario real (C-14, opcional post-incidente mayor):
    bosctl vdi test-user --tenant=skull \
      --user=test@skull.com --password=testpass
    → 6/6 pasos OK ✓

──────────────────────────────────────────────────────────────────────

ETAPA 7 — AUDIT TRAIL COMPLETO (t=0:16)
═════════════════════════════════════════
  ISO 27001 A.8.15 requiere audit trail completo e inmutable.
  Todos los eventos del flujo están correlacionados por:
    traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-...
    ctx_id: ctx-88291-a4f9 (el operador que inició la reparación)
    saga_id: repair-ficha / exec_id: saga-exec-xyz

  /var/log/bos/audit.log (fragmento):
    14:23:12 WATCHDOG_DETECT    ficha=nextcloud cause=OOMKilled
    14:25:31 BIAOS_QUERY        method=bos.query.system caller=bosctl
    14:25:33 BIAOS_QUERY        method=bos.query.repair ficha=nextcloud
    14:27:11 ICAP_HITL_SHOWN    options=[repair_ficha,scale_deployment]
    14:27:44 RBAC_CHECK         user=ivan@sbos.local role=bos:operator OK
    14:27:44 HITL_CONFIRMED     action=repair_ficha user=ivan@sbos.local
    14:27:45 SAGA_START         id=repair-ficha ficha=nextcloud
    14:27:45 SAGA_STEP_OK       paso=pre-diagnose
    14:27:47 SAGA_STEP_OK       paso=validate
    14:27:48 SAGA_STEP_START    paso=execute-repair
    14:35:02 SAGA_STEP_OK       paso=execute-repair duracion=7m14s
    14:35:04 SAGA_STEP_OK       paso=verify-recovery healthy=true
    14:35:04 SAGA_COMPLETED     duracion=8m02s outcome=success
    14:35:12 CTX_HOME_MOUNTED   tenant=skull pods=3/3
    14:35:18 VDI_VERDE          tenant=skull semaforo=VERDE
    14:36:05 OPERATOR_VERIFIED  method=bosctl_query_vdi result=OK

═══════════════════════════════════════════════════════════════════════
FIN DEL FLUJO
Duración total: 13m02s (incluyendo verificación)
Reparación propiamente dicha: 8m02s
ITIL 4 MTTM: 8m02s (tiempo hasta servicio restaurado)
Usuarios afectados durante incidente: 12
Usuarios con acceso al finalizar: 12
Criterios C-09..C-14 verificados: ✓
Audit trail ISO 27001 A.8.15: ✓
traceparent W3C correlacionado: ✓
═══════════════════════════════════════════════════════════════════════
```

---

## Por qué el traceparent es el hilo conductor de todo el flujo

El W3C Trace Context define un enfoque unificado para la correlación de contexto y eventos dentro de sistemas distribuidos como entornos de microservicios. Un estándar así habilita el trazado de transacciones end-to-end dentro de aplicaciones distribuidas a través de distintas herramientas de monitoreo.

Para el SBOS, el `traceparent` cumple una función más profunda que el simple tracing técnico: es el identificador de correlación de auditoría de ISO 27001. Cada evento del flujo — desde la detección del watchdog hasta la verificación post-reparación — lleva el mismo `traceparent`. Un auditor puede reconstruir todo el incidente en orden cronológico con una sola consulta al audit log.

```
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
            |  |________________________________|  |______________|  |
           ver         trace-id (128-bit)         parent-id (64-bit) flags

Propagado en:
  bos.query.system   → header OTel Baggage
  bos.query.repair   → header OTel Baggage
  biaos.RunAgent()   → campo ctx de la sesión
  SagaEngine pasos   → campo RPCContext.TraceParent
  audit.Log()        → campo estructurado obligatorio
  bkernel WAL        → context_sessions.traceparent
```

---

## Los tres flujos alternativos

El caso canónico (nextcloud) cubre el flujo nominal. Hay dos flujos alternativos
importantes que el sistema debe manejar:

### Flujo alternativo 1 — Reparación automática sin operador

Cuando el watchdog detecta una ficha degradada con bajo impacto:

```
watchdog detecta redis DEGRADADA
  → bos.query.repair {"ficha_id":"redis"}
  → usuarios_afectados: 3 (< umbral 50)
  → sin sesiones HITL pendientes
  → auto-repair sin intervención humana
  → audit.Log("WATCHDOG_AUTO_REPAIR", "reason=low_impact")
  → post-repair: bos.query.system verifica estado
  → notificación WebSocket al operador (informativa, no bloqueante)
```

La diferencia clave con el flujo nominal: el operador recibe notificación
informativa en lugar de opciones HITL. El umbral de usuarios afectados (50
por defecto) es configurable en `bos.toml`.

### Flujo alternativo 2 — Reparación fallida con compensación

Cuando el paso `execute-repair` de la saga falla:

```
SagaEngine.Execute("repair-ficha") — paso execute-repair FALLA
  → Error: "reinstallation failed: disk quota exceeded"
  → compensar en orden inverso:
      ← compensar execute-repair: bos.ficha.rollback ← snapshot-id
  → ejec.Estado = EstadoCompensado
  → stateMgr permanece en DEGRADADA (no empeora el estado)
  → audit.Log("SAGA_COMPENSATED", "paso=execute-repair", "reason=disk_quota")

biaos responde al operador:
  "❌ Reparación fallida y revertida.
   Causa: disco al 89% — sin espacio para reinstalar nextcloud.

   Acción previa requerida:
   bosctl storage quota --cleanup --tenant=skull

   Luego: bosctl rpc bos.ficha.repair '{\"ficha_id\":\"nextcloud\"}'"
```

---

## Tabla de tiempos del flujo completo

| Etapa | Duración | Herramienta | SLO |
|---|---|---|---|
| Detección (watchdog) | 0-30s (próximo tick) | watchdog 30s | automático |
| Investigación paralela | < 4s | biaos + bos.query.* | p99 < 10s |
| ICAP + HITL | 30s-2min | biaos + operador | depende del operador |
| Saga reparación | 5-10 min | SagaEngine + 00_MASTER | < 10 min MTTR |
| Restauración Context Plane | < 60s | bos + ctxSvc | p99 < 2s por ctx |
| Verificación VDI | < 90s | bos.query.vdi | p99 < 3s |
| Verificación operador | 1-5 min | bosctl bootstrap verify | manual |
| **Total** | **8-15 min** | — | **MTTM < 10 min** |

---

## Correlación entre documentos BOS-REPAIR y etapas del flujo

| Etapa del flujo | Documentos que la especifican |
|---|---|
| Detección automática | BOS-REPAIR-01 §Capa 2, BOS-REPAIR-12 §F6.14 |
| Investigación paralela | BOS-REPAIR-04 (sagas consulta), BOS-REPAIR-12 §F6.7-F6.8 |
| ICAP + HITL | BOS-REPAIR-10 §ICAP Engine, BOS-REPAIR-11 §RBAC |
| Saga de reparación | BOS-REPAIR-10 §SagaEngine, JSON-RPC-09 §Patrón Saga |
| Restauración Context Plane | BOS-REPAIR-08 §7 (responsabilidad del bos) |
| Verificación VDI | BOS-REPAIR-09 §14, BOS-REPAIR-01 §Capa 4 |
| Verificación operador | BOS-REPAIR-01 §Capa 5, C-09..C-14 |
| Audit trail | BOS-REPAIR-07 (ADR-003), ISO 27001 A.8.15 |
| Propagación traceparent | BOS-REPAIR-08 §3 (W3C Trace Context) |
| Autorización HITL | BOS-REPAIR-11 §8 (Matriz operaciones — bos:operator) |

---

## Criterio de completitud del flujo end-to-end

El flujo está implementado correctamente cuando este test pasa:

```bash
# Test integración end-to-end (ejecutar en ambiente de staging)
bosctl vdi test-repair \
  --ficha=nextcloud \
  --tenant=skull \
  --trigger=oomkill-simulation \
  --verify-ctx-plane=true \
  --verify-vdi=true \
  --verify-audit=true \
  --output=json

# Salida esperada:
# {
#   "etapas": {
#     "deteccion":     {"ok":true, "duracion_s":12},
#     "diagnostico":   {"ok":true, "duracion_s":4, "causa":"OOMKilled"},
#     "icap_hitl":     {"ok":true, "duracion_s":45, "accion":"repair_ficha"},
#     "saga":          {"ok":true, "duracion_s":492, "outcome":"completed"},
#     "ctx_plane":     {"ok":true, "home_montados":"3/3"},
#     "vdi":           {"ok":true, "semaforo":"VERDE"},
#     "audit_trail":   {"ok":true, "traceparent":"correlacionado"},
#     "certificacion": {"ok":true, "c09":true}
#   },
#   "mttm_s": 482,
#   "slo_ok": true
# }
```

---

## Changelog

| Fecha | Versión | Cambio |
|---|---|---|
| Junio 2026 | 1.0 | Versión inicial — cierra Gap 4 con flujo end-to-end completo |

---

*BOS-REPAIR-13 — SKULL · SBOS · Junio 2026*  
*Cierra: Gap 4 — flujo end-to-end no documentado*  
*Marco normativo: ITIL 4 Major Incident Management, W3C Trace Context,*  
*ISO 27001 A.8.15, Google SRE InvD, JSON-RPC Parte 9 Patrón Saga*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
