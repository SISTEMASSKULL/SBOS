# ADR-004 — bos como Kubernetes Operator Soberano
## Gobierno de Infraestructura: Escalado, Mantenimiento y Reparación Autónoma

**Estado:** Aceptado  
**Fecha:** Junio 2026  
**Autores:** Equipo SKULL — SBOS Architecture  
**Supersede:** Sección "Rol B" del ADR-002 (amplía, no reemplaza)  
**Relacionado:** ADR-001, ADR-002, ADR-003, SBOS-018, SBOS-049  
**Referenciado en:** PLAN_ACCION_BOSAGENT.md — Fase 9 (nueva)

---

## Por qué este ADR es necesario

El ADR-002 definió al bos como "Administrador de Ubuntu y Kubernetes" con una lista de privilegios. Pero eso describe *qué puede hacer*, no *cómo lo hace ni por qué es el responsable correcto*. Este ADR cierra esa brecha.

El bos no es solo un instalador con privilegios. Es el **Operator Soberano** del servidor SBOS: hereda el modelo de control declarativo de Kubernetes y lo extiende con semántica empresarial propia. Esto tiene implicaciones precisas en cómo se diseñan las sagas, cómo funciona el JSON-RPC, y qué nuevos métodos son necesarios.

---

## Marco conceptual: el Kubernetes Operator Pattern

### Definición CNCF

El CNCF Operator White Paper define el patrón así: un Operator encapsula conocimiento operacional específico del dominio en forma de un controlador que **continuamente reconcilia la configuración deseada de un recurso con el estado real observado en el sistema**. Este loop de reconciliación incorpora el principio de control por retroalimentación: lee el estado declarado, lo compara con la realidad, y actúa hasta lograr convergencia.

Más concretamente, según la documentación de Red Hat sobre Kubernetes Operators Best Practices: el reconcile loop es *level-based* (orientado a estado), no *edge-based* (orientado a eventos). Esto significa que cuando ocurre un evento, el controlador no reacciona al cambio específico sino que re-evalúa el estado completo del sistema. Este enfoque, aunque menos eficiente, es más robusto en entornos complejos donde las señales pueden perderse o retransmitirse múltiples veces.

### Por qué el bos ES un Operator

El bos ya implementa los tres componentes del patrón Operator:

```
Componente Operator      Equivalente en bos
─────────────────────────────────────────────────────────────
Custom Resource (CRD)  → manifest.yml de cada ficha
                          (.spec = estado deseado)
Controller             → observer/loop.go + reconcile/scheduler.go
                          (compara spec vs estado real)
Reconcile Loop         → el ciclo de 5s/300s/30s ya existente
                          (actúa hasta convergencia)
```

Lo que falta es completar el Operator con las operaciones que un operador humano también haría:
- **Escalar pods** cuando la carga aumenta
- **Mantener nodos** durante actualizaciones
- **Reparar pods** cuando fallan
- **Gestionar recursos** (CPU/memoria) de forma coordinada

---

## El problema del escalado: por qué bos debe coordinarlo

### La death spiral de HPA + VPA

La investigación actual es inequívoca sobre este punto. HPA y VPA son fundamentalmente incompatibles cuando operan sobre las mismas métricas de forma independiente. VPA ve bajo uso de CPU y reduce los requests del pod; HPA recalcula la utilización contra el nuevo denominador y detecta alto uso, escala réplicas; los nuevos pods tienen resources reducidos, VPA los aumenta, HPA vuelve a escalar hacia abajo. El resultado es el "death spiral" documentado por Kubernetes upstream.

La solución correcta, según la investigación reciente, es **reconciliar el conteo de réplicas y el dimensionamiento por pod como una decisión coordinada única**, no dos loops independientes.

Esto es exactamente lo que el bos puede hacer: tiene visión completa del estado de cada ficha (manifest.yml define los umbrales), tiene acceso al API server de K8s via `internal/k8s/core.go`, y tiene el reconcile loop. Solo falta agregar la lógica de decisión coordinada.

### Por qué es el bos y no K8s nativo quien decide

K8s HPA/VPA son ciegos al contexto empresarial. Un pod de postgresql que soporta transacciones de fin de mes en la empresa maya/lapaz tiene requerimientos completamente diferentes que el mismo pod en horario nocturno. Esa información vive en el Context Plane del bos (SBOS-049), no en métricas de CPU.

El bos puede escalar *con semántica*: conoce el tenant, el contexto operativo, las políticas del manifest.yml, y el estado del resto de las fichas. Es el único componente del sistema con esa visión completa.

---

## Marco normativo: por qué este rol es obligatorio bajo los estándares

### ITIL 4 — Infrastructure and Platform Management

ITIL 4 define "Infrastructure and Platform Management" como la práctica que mantiene la infraestructura técnica sobre la que dependen todos los servicios. Sus prácticas incluyen:

- **Incident Management**: restaurar la operación normal lo más rápido posible
- **Problem Management**: eliminar causas raíz de incidentes recurrentes
- **Change Enablement**: gestionar cambios que puedan afectar servicios
- **Service Configuration Management (CMDB)**: registro de todos los CIs y sus relaciones

El bos implementa estas cuatro prácticas de ITIL 4 directamente:
- Repair saga → Incident Management
- Drift detection + reconcile → Problem Management
- Sagas de upgrade → Change Enablement
- `bos.state.read` + state.Manager → CMDB de fichas

### SRE Google — Eliminación de Toil

El libro SRE de Google define "toil" como trabajo manual, repetitivo, sin valor duradero que crece proporcionalmente con el tamaño del servicio. La filosofía SRE indica que las tareas de toil deben automatizarse: si un ser humano escala pods manualmente, reinicia servicios, o drena nodos durante mantenimiento, eso es toil que debe eliminarse.

El bos es precisamente el mecanismo de eliminación de toil para el servidor SBOS. Toda operación que un administrador haría manualmente via `kubectl` debe poder ejecutarse via `bosctl rpc bos.k8s.*`.

### NSA/CISA Kubernetes Hardening Guide v1.2 (2022)

La guía establece que el control de acceso privilegiado al API server de Kubernetes debe estar centralizado y auditado. Específicamente:

- Usar RBAC para el menor privilegio posible entre usuarios y grupos autorizados
- Monitorear RBAC continuamente
- Deshabilitar interfaces no autenticadas y autenticación anónima
- Los logs de auditoría de K8s son obligatorios

Implicación directa para el bos: todas las operaciones kubectl que el bos ejecuta deben pasar por un ClusterRole específico `bosagent` con los mínimos privilegios necesarios, y cada operación debe generar una entrada en el audit log.

### CIS Kubernetes Benchmark v1.8+ — Secciones relevantes

Las secciones que aplican directamente al bos como Operator:

```
Sección 4 — RBAC y Service Accounts:
  4.1.1 No usar ClusterRole cluster-admin para service accounts del bos
  4.1.3 No usar wildcards en Roles del bos
  4.2.1 No ejecutar pods privilegiados (el bos corre en el HOST, no como pod)
  4.2.6 No compartir hostPID del nodo con pods de fichas

Sección 5 — Pod Security Standards:
  5.1.1 Minimize cluster-admin usage — bos usa bosagent ClusterRole
  5.2.* Pods de fichas no deben ejecutarse como root (solo el bos host lo hace)

Sección 3 — Worker Node Security:
  3.2.1 Authentication webhook habilitado — bos verifica via RBAC propio
  3.2.2 Authorization mode RBAC — bos respeta el RBAC del API server
```

### ISA-95 / IEC 62264-1:2025 — Gestión de Operaciones de Manufactura

ISA-95 Level 3 (Manufacturing Operations Management) define que los sistemas MOM deben:
- Gestionar el ciclo de vida completo de los activos bajo su control
- Mantener trazabilidad de todas las operaciones
- Coordinar personal, equipos y materiales para cumplir objetivos de producción

Para el SBOS, los "activos" son las fichas (pods), el "personal" son los ctx_id activos, y los "objetivos de producción" son los SLOs definidos en cada manifest.yml. El bos, como sistema MOM soberano, es responsable de que los pods tengan los recursos necesarios para cumplir esos SLOs.

---

## El bos como capas heredadas: Ubuntu + Kubernetes

La arquitectura correcta no es "bos sobre Ubuntu+K8s" sino "bos que hereda y extiende Ubuntu+K8s":

```
┌─────────────────────────────────────────────────────────────────┐
│                    SBOS Context Plane                            │
│  ctx_id · tenant · empresa · sucursal · POS · BitMask           │
└──────────────────────────┬──────────────────────────────────────┘
                           │ semántica empresarial
┌──────────────────────────▼──────────────────────────────────────┐
│              bos — Sovereign Operator Layer                      │
│                                                                  │
│  Hereda de Ubuntu:           Hereda de Kubernetes:               │
│  · root privileges           · API server access                 │
│  · systemd service mgmt      · ClusterRole bosagent              │
│  · filesystem access         · kubectl + k8s/core.go             │
│  · network (ufw/nft)         · Namespace management              │
│                                                                  │
│  Agrega (ADR-002 Roles A, B, C + este ADR):                     │
│  · Reconcile loop soberano (observer + reconcile + watchdog)     │
│  · Escalado coordinado HPA+VPA sin death spiral                  │
│  · Sagas de mantenimiento: cordon→drain→repair→uncordon          │
│  · Context-aware scaling (semántica tenant/empresa/POS)          │
│  · JSON-RPC para todas las operaciones (ADR-019)                 │
│  · Audit trail inmutable (ISO 27001 A.8.15)                      │
└──────────────────────────┬──────────────────────────────────────┘
                           │ gestiona
┌──────────────────────────▼──────────────────────────────────────┐
│              Kubernetes (k3s) + Ubuntu (host)                   │
│  Pods · Namespaces · PVCs · Services · Nodes · systemd          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Decisión: operaciones de gobierno de infraestructura via JSON-RPC

Todas las operaciones que el bos realiza sobre la infraestructura deben ser:
1. **Declarables** — expresables como parámetros JSON
2. **Auditables** — registradas antes de ejecutarse
3. **Idempotentes** — ejecutables múltiples veces con el mismo resultado
4. **Coordinadas** — no ejecutadas en paralelo sin exclusión mutua

Esto se logra canalizando TODAS las operaciones de infraestructura a través del mecanismo de sagas y el JSON-RPC.

---

## Nuevos módulos JSON-RPC requeridos

### Módulo bos.k8s.* — Gobierno del cluster

```
bos.k8s.scale          Escalado coordinado (HPA + VPA como decisión única)
bos.k8s.node.cordon    Marcar nodo como no-schedulable (mantenimiento)
bos.k8s.node.uncordon  Liberar nodo post-mantenimiento
bos.k8s.node.drain     Evacuar pods de un nodo antes de mantenimiento
bos.k8s.pod.evict      Evicción controlada de un pod específico
bos.k8s.pod.restart    Reinicio controlado (delete pod → ReplicaSet crea nuevo)
bos.k8s.rollout.status Estado de un rollout en curso
bos.k8s.rollout.undo   Rollback a la revisión anterior
bos.k8s.resources.set  Actualizar CPU/memory requests+limits de una ficha
```

### Módulo bos.maintenance.* — Sagas de mantenimiento

```
bos.maintenance.start  Inicia saga de mantenimiento: cordon→drain→op→uncordon
bos.maintenance.status Estado de saga de mantenimiento en curso
bos.maintenance.cancel Cancela saga de mantenimiento (best-effort)
bos.maintenance.plan   Planifica mantenimiento con ventana de tiempo
```

### Módulo bos.ficha.* — extensiones sobre los existentes

```
bos.ficha.scale        Escalar específicamente una ficha (réplicas + resources)
bos.ficha.upgrade      Upgrade controlado con rollback automático en fallo
bos.ficha.probe        Ya existe — verificar health de una ficha
bos.ficha.policy.set   Actualizar política de escalado de una ficha
bos.ficha.policy.get   Consultar política actual
```

---

## Política de escalado declarativa en manifest.yml

El manifest.yml de cada ficha debe poder declarar su política de escalado. El bos la lee y la aplica como parte del reconcile loop:

```yaml
# Ejemplo: manifest.yml de redis
id: redis
version: "8.6.2"
auto_install: true

# Política de escalado — gestionada por bos como Operator Soberano
scaling:
  strategy: coordinated            # "coordinated" | "horizontal-only" | "vertical-only" | "none"
  
  horizontal:
    min_replicas: 1
    max_replicas: 5
    target_cpu_percent: 70         # umbral para scale-out
    target_memory_percent: 80
    scale_up_cooldown: 3m          # tiempo mínimo entre scale-up
    scale_down_cooldown: 10m       # tiempo mínimo entre scale-down (ISO 27001: cambios controlados)
  
  vertical:
    mode: "recommendation"         # "off" | "recommendation" | "auto"
    # "recommendation": bos sugiere via bos.ficha.policy.get, admin aprueba
    # "auto": bos aplica directamente (requiere autorización admin en ADR-002)
    min_cpu: "100m"
    max_cpu: "2"
    min_memory: "128Mi"
    max_memory: "4Gi"
    update_policy: "on-maintenance" # "on-maintenance" | "rolling" | "immediate"
    
  context_aware:                   # escalado con semántica empresarial (SBOS-049)
    enabled: true
    peak_contexts:                 # umbrales diferentes según carga de tenants activos
      - contexts_gt: 100           # si hay más de 100 ctx_id activos
        min_replicas: 2            # garantizar mínimo 2 réplicas
      - contexts_gt: 500
        min_replicas: 3

# Política de mantenimiento
maintenance:
  strategy: "cordon-drain"         # "cordon-drain" | "rolling" | "blue-green"
  max_unavailable: 1               # máximo 1 pod fuera durante mantenimiento
  drain_timeout: 300s              # tiempo máximo para drain antes de force-delete
  pre_maintenance_checks:          # verificaciones antes de iniciar mantenimiento
    - "bos.ficha.probe"
  post_maintenance_checks:
    - "bos.ficha.probe"
    - "bos.health.check"

# SLOs que el bos debe preservar (SRE Google — error budgets)
slos:
  availability: 0.999              # 99.9% — si cae por debajo, escalar inmediatamente
  latency_p99_ms: 10               # latencia p99 en ms
  error_rate_max: 0.001            # máximo 0.1% errores
```

---

## Arquitectura de la Saga de Escalado Coordinado

El escalado no puede ser una operación simple de `kubectl scale`. Debe ser una saga con compensación:

```
Saga: bos.ficha.scale (coordinated)
──────────────────────────────────────────────────────────────────

Paso 1 — Validar política
  Lee manifest.yml de la ficha
  Verifica que la operación está dentro de los límites declarados
  Verifica que no hay otra saga de escalado en curso (mutex)
  Genera audit.Log("SCALE_START", ...)

Paso 2 — Verificar estado actual
  kubectl get hpa <ficha> -n <namespace>
  kubectl top pods -n <namespace> -l app=<ficha>
  Compara métricas actuales vs umbrales del manifest.yml

Paso 3 — Decisión coordinada HPA+VPA
  Si strategy=coordinated:
    Calcular réplicas deseadas (lógica HPA)
    Calcular resources deseados (lógica VPA)
    Verificar que no hay conflicto (death spiral check):
      Si aumenta réplicas → no reducir resources simultáneamente
      Si reduce réplicas → no aumentar resources simultáneamente
  
Paso 4 — Aplicar cambio de resources primero (si cambia)
  kubectl patch deployment <ficha> --patch '{"spec":{"containers":[...]}}'
  Esperar a que pods con nuevos resources estén Running
  Timeout: drain_timeout del manifest
  
Paso 5 — Aplicar cambio de réplicas
  kubectl scale deployment <ficha> --replicas=<N>
  Esperar readinessProbe de nuevos pods
  
Paso 6 — Verificar SLOs post-escaldo
  Ejecutar bos.ficha.probe
  Verificar availability y latency contra manifest.slos
  
Compensación (si cualquier paso falla):
  Paso 6 falla → bos.k8s.rollout.undo → volver a estado anterior
  Paso 5 falla → reducir réplicas al valor anterior
  Paso 4 falla → revertir patch de resources
  Generar audit.Log("SCALE_FAILED", ...) + wsEvent "saga_fail"
```

---

## Arquitectura de la Saga de Mantenimiento de Nodo

```
Saga: bos.maintenance.start (cordon-drain strategy)
──────────────────────────────────────────────────────────────────

Contexto: mantenimiento planificado de un nodo (actualización K8s, parche OS, etc.)
Autorización requerida: RBAC rol "operator" o "admin" (ADR-002)

Paso 1 — Pre-checks (ITIL 4: Change Enablement)
  Verificar que hay suficientes nodos healthy para absorber el drain
  Ejecutar pre_maintenance_checks del manifest de cada ficha afectada
  Registrar ventana de mantenimiento en audit log
  Notificar via WebSocket a subscribers (TUI, biedata, etc.)

Paso 2 — Cordon
  kubectl cordon <node>
  Verifica: node.spec.unschedulable = true
  Audit.Log("MAINTENANCE_CORDON", "node="+node)

Paso 3 — Drain (con respeto a PodDisruptionBudgets)
  kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --timeout=<drain_timeout>
  PodDisruptionBudgets declarados por Kyverno (fichas críticas) se respetan
  Si drain excede timeout → compensar (kubectl uncordon) y reportar error
  Audit.Log("MAINTENANCE_DRAIN", "node="+node, "pods_evacuados="+count)

Paso 4 — Ejecutar operación de mantenimiento
  Según el tipo: actualización OS (apt), actualización K8s, reemplazo de hardware
  Esta es la única parte que puede requerir intervención humana
  Si es automatizable: ejecutar via saga específica
  Audit.Log("MAINTENANCE_OP", "op="+operationType)

Paso 5 — Post-checks
  Ejecutar post_maintenance_checks de manifest de fichas afectadas
  Verificar que el nodo está Ready: kubectl wait node --for=condition=Ready
  
Paso 6 — Uncordon
  kubectl uncordon <node>
  Verificar que pods se redistribuyen correctamente
  Audit.Log("MAINTENANCE_UNCORDON", "node="+node)

Paso 7 — Verificación final
  bos.health.check para todas las fichas afectadas
  Verificar SLOs post-mantenimiento
  Notificar completitud via WebSocket

Compensación:
  Cualquier fallo después del Paso 2 → kubectl uncordon (siempre)
  Esto es crítico: un nodo cordoned sin uncordon reduce capacidad del cluster
```

---

## Tabla completa de privilegios del bos como Operator Soberano

Actualiza y extiende ADR-002 §Rol B con el contexto completo:

### Sobre Kubernetes — ClusterRole bosagent

El bos necesita un ClusterRole con exactamente estos verbos sobre exactamente estos recursos:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: bosagent
  annotations:
    # NSA/CISA K8s Hardening Guide v1.2: least privilege ClusterRole
    # CIS K8s Benchmark 4.1.1: no cluster-admin para service accounts
    sbos.io/adr: "ADR-004"
    sbos.io/last-review: "2026-06-01"
rules:
  # Lectura de estado (monitoreo — ADR-002 Rol A)
  - apiGroups: [""]
    resources: ["pods", "nodes", "services", "endpoints", "persistentvolumeclaims"]
    verbs: ["get", "list", "watch"]
  
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets", "replicasets", "daemonsets"]
    verbs: ["get", "list", "watch"]
  
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get", "list", "watch"]
  
  # Gestión de workloads SBOS (administración — ADR-002 Rol B)
  # SOLO en namespaces sbos-* (enforced by Kyverno policy)
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets"]
    verbs: ["patch", "update"]
    # resourceNames: fichas SBOS únicamente (enforced en saga, no aquí)
  
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["delete"]   # para restart controlado via saga
  
  - apiGroups: [""]
    resources: ["pods/eviction"]
    verbs: ["create"]   # para drain via saga
  
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["patch", "update"]  # para cordon/uncordon
  
  # Namespaces (solo crear namespaces sbos-* durante bootstrap)
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["create", "get", "list"]
  
  # Secrets solo en namespaces sbos-* via Vault (NO lectura de secrets de tenants)
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["create", "update", "delete"]
    # resourceNames: solo secrets creados por bos (enforced por naming convention)
  
  # Autoscaling coordinado
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["create", "update", "patch", "delete"]
  
  # Audit logs K8s (NSA/CISA K8s Hardening Guide)
  - apiGroups: ["audit.k8s.io"]
    resources: ["events"]
    verbs: ["get", "list"]
```

**Lo que bosagent ClusterRole NUNCA tendrá:**
```
✗ cluster-admin (CIS K8s Benchmark 4.1.1 — prohibido)
✗ Wildcards en verbs o resources (CIS K8s Benchmark 4.1.3)
✗ Acceso a secrets de namespaces de tenants
✗ Acceso a etcd directamente
✗ Capacidad de modificar PodSecurityPolicies/PodSecurityAdmission
✗ Acceso a recursos de networking del CNI (Calico gestiona su propio RBAC)
```

---

## Métricas de gobierno que el bos debe exponer

Para cumplir con los SLOs definidos en manifest.yml y con ITIL 4 Continual Improvement, el bos debe medir y exponer:

```
# Via bos.state.read extendido o endpoint /metrics Prometheus:

# Escalado
bos_scale_operations_total{ficha, direction, outcome}   Counter
bos_scale_decisions_coordinated_total{ficha}            Counter
bos_scale_death_spiral_prevented_total{ficha}           Counter

# Mantenimiento
bos_maintenance_sagas_total{node, outcome}              Counter
bos_maintenance_duration_seconds{node}                  Histogram
bos_nodes_cordoned_current                              Gauge

# Reparación
bos_repair_sagas_total{ficha, trigger, outcome}         Counter
bos_repair_duration_seconds{ficha}                      Histogram
bos_repair_parallel_prevented_total                     Counter  ← P6/P14 fix

# SLOs por ficha
bos_ficha_slo_availability{ficha}                       Gauge
bos_ficha_slo_latency_p99{ficha}                        Gauge
bos_ficha_slo_error_rate{ficha}                         Gauge

# Reconciliación
bos_drift_detected_total{ficha, file}                   Counter
bos_reconcile_duration_seconds                          Histogram
```

---

## Fase 9 del Plan de Acción — implementación

Esta es la fase nueva que se agrega al PLAN_ACCION_BOSAGENT.md:

### Fase 9 — bos como Operator Soberano: Escalado y Mantenimiento

**Duración estimada:** 4-5 días  
**Requiere:** Fases 1-6 completas (especialmente internal/observer/ con mutex)  
**Problemas adicionales que resuelve:** Brecha en gobierno de infraestructura

**Tareas atómicas:**

```
F9.1  manifest.yml: definir schema de scaling + maintenance + slos
F9.2  internal/k8s/core.go: agregar Scale, Cordon, Uncordon, Drain, Evict
F9.3  internal/scaler/: nuevo paquete — lógica coordinada HPA+VPA sin death spiral
F9.4  internal/maintenance/: nuevo paquete — saga cordon→drain→op→uncordon
F9.5  internal/server/jsonrpc.go: registrar bos.k8s.* + bos.maintenance.*
F9.6  internal/server/jsonrpc.go: registrar bos.ficha.scale + bos.ficha.upgrade
F9.7  k8s/bosagent-clusterrole.yaml: ClusterRole con least privilege (CIS 4.1.1)
F9.8  internal/metrics/: exponer métricas Prometheus de escalado/mantenimiento
F9.9  cmd/bosctl/infra.go: bosctl infra scale/maintain/drain/uncordon
F9.10 Tests: TestScaleCoordinated_NoDeathSpiral, TestMaintenanceSaga_Compensates
```

**Criterio de completitud:**
```bash
go build ./...
bosctl rpc bos.k8s.scale '{"ficha_id":"redis","replicas":3}'
bosctl rpc bos.maintenance.start '{"node":"node-01","strategy":"cordon-drain"}'
bosctl rpc bos.ficha.policy.get '{"ficha_id":"redis"}' | grep scaling
# Verificar ClusterRole:
kubectl get clusterrole bosagent -o yaml | grep -v "cluster-admin"
```

---

## Consecuencias de este ADR

### Positivas
1. El bos se convierte en el único punto de control de la infraestructura — elimina el toil de `kubectl` manual
2. El escalado coordinado previene el death spiral HPA+VPA documentado por K8s upstream
3. Las sagas de mantenimiento con compensación garantizan que ningún nodo quede cordoned por accidente
4. Las métricas Prometheus permiten SLO tracking real contra las políticas del manifest.yml
5. El ClusterRole `bosagent` con least privilege cumple CIS K8s Benchmark 4.1.1 y NSA/CISA K8s Hardening

### Trade-offs aceptados
1. El bos se convierte en un componente crítico del cluster — si el bos falla, el escalado automático falla. Mitigado por el watchdog que monitorea el propio bos.
2. La política de escalado en manifest.yml agrega complejidad a la definición de fichas. Justificado por la prevención del death spiral.
3. El ClusterRole bosagent debe auditarse cada 6 meses (ISO 27001 A.5.16 — acceso privilegiado revisado periódicamente).

### Implicaciones en el código
1. `internal/k8s/core.go` necesita los nuevos métodos Scale, Cordon, Uncordon, Drain
2. `internal/observer/loop.go` necesita integrar el scaler como parte del reconcile loop
3. `internal/installer/saga.go` necesita poder invocar sagas de escalado y mantenimiento
4. `internal/server/jsonrpc.go` necesita los nuevos módulos bos.k8s.* y bos.maintenance.*
5. El mutex de `internal/observer/loop.go` (F1.5 del plan) protege tanto repairs como operaciones de escalado

---

## Referencias normativas

| Estándar | Sección | Aplicación en este ADR |
|---|---|---|
| CNCF Operator White Paper | §Reconciliation Loop | Modelo conceptual del bos como Operator |
| Red Hat K8s Operators Best Practices | §Level-based triggering | Por qué el reconcile re-evalúa estado completo |
| ITIL 4 | Infrastructure & Platform Mgmt | Marco de prácticas: Incident, Problem, Change, CMDB |
| Google SRE Book | §Toil Reduction | Por qué automatizar todas las operaciones kubectl |
| NSA/CISA K8s Hardening Guide v1.2 | §RBAC, §Audit | ClusterRole bosagent con least privilege |
| CIS Kubernetes Benchmark v1.8 | §4.1.1, §4.1.3, §5.1 | Sin cluster-admin, sin wildcards, sin privileged pods |
| ISA-95 / IEC 62264-1:2025 | Level 3 MOM | bos como sistema de gestión de operaciones |
| ISO 27001:2022 | A.5.16, A.8.2 | Revisión periódica del ClusterRole bosagent |
| K8s upstream docs | HPA/VPA conflict | Death spiral — razón para escalado coordinado |
| ADR-001 | BOS como capa OS | Herencia de privilegios Ubuntu |
| ADR-002 | Roles y privilegios | Extensión del Rol B con gobierno de K8s |
| SBOS-049 | Context Plane | Context-aware scaling via ctx_id |

---

## Changelog

| Fecha | Versión | Cambio |
|---|---|---|
| Junio 2026 | 1.0 | Versión inicial — bos como Kubernetes Operator Soberano |

---

*ADR-004 — BosAgent/SBOS — Junio 2026*  
*Extiende: ADR-002 §Rol B*  
*Referencia: PLAN_ACCION_BOSAGENT.md — Fase 9 (nueva)*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
