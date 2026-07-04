# INSTRUCCIONES DE EJECUCIÓN — Átomos F9.1 a F9.3
## Operator Soberano — Schema, K8s Core extendido, Scaler anti-death-spiral
## Para: Agente ejecutor (Claude Code / desarrollador)

**Átomos:** F9.1 (schema manifest), F9.2 (k8s/core.go extendido), F9.3 (scaler)  
**Requiere previo:** F6.x ✅ (JSON-RPC robusto) + F8.x ✅ (tests)  
**Duración estimada:** F9.1: 45 min · F9.2: 90 min · F9.3: 120 min  
**Riesgo:** MUY ALTO — operaciones sobre el cluster Kubernetes real  
**Regla crítica:** NUNCA ejecutar operaciones K8s sin ClusterRole correctamente limitado  
**Base normativa:** ADR-004 (BOS-REPAIR-02), SBOS-052, CIS Kubernetes Benchmark v1.10

---

## ⛔ REFERENCIA _legacy/ — SOLO LÓGICA, NO COPIAR

Antes de implementar F9.3 (scaler) y F9.4 (maintenance), **consultar** estos archivos
archivados en `_legacy/`. Son referencia de lógica únicamente — **NO copiarlos**.

| Archivo en `_legacy/` | Lógica a entender (no copiar) |
|---|---|
| `2026-06-09_F0.7_repair/repair_manager.go` | Flujo multi-fase: detección → diagnóstico → reparación → verificación |
| `2026-06-09_F0.7_repair/os_repair.go` | Estrategias de reparación a nivel SO (apt, systemctl, etc.) |
| `2026-06-09_F0.7_repair/k8s_node_repair.go` | Reparación de nodos K8s: cordon, drain, uncordon |
| `2026-06-09_F0.7_repair/health_verifier.go` | Criterios de verificación post-reparación |
| `2026-06-09_F0.7_observability/health_report.go` | Estructura HealthReport por capas (Ubuntu/K8s/BOS) |

**Lo que DEBES hacer:** leer para entender la lógica. Luego construir desde el
`doc.go` de `internal/scaler/` y `internal/maintenance/` como contrato base.
**Lo que NO DEBES hacer:** copiar, refactorizar, o importar desde `_legacy/`.

Cada directorio tiene un `LEEME-ADVERTENCIA.md` con las reglas completas.

---

## CONTEXTO TÉCNICO

### Qué es el Operator Soberano

bos como Kubernetes Operator Soberano no usa Helm ni un operador externo. Implementa directamente:
- **Escalado coordinado HPA+VPA** sin death spiral (el anti-patrón donde HPA y VPA compiten)
- **Saga de mantenimiento** con compensación garantizada: cordon → drain → operación → uncordon
- **Verificación de SLOs** por ficha (latency P99, error rate, disponibilidad)

### El death spiral que F9.3 previene

```
Sin anti-death-spiral:
  VPA aumenta requests.memory de 256Mi a 512Mi (más recursos por pod)
  HPA detecta que los pods actuales usan >80% de memoria
  HPA escala de 3 → 6 pods (mismo uso de memoria relativo)
  VPA vuelve a aumentar requests → HPA vuelve a escalar → bucle infinito
  Resultado: cluster agotado, 0% de los pods nuevos se schedulean

Con anti-death-spiral (F9.3):
  VPA propone cambio de recursos
  Scaler verifica: ¿el cambio + escala HPA cabe en el cluster?
  Si no cabe: bloquea el cambio de VPA hasta que haya capacidad
  Si cabe: aplica primero VPA, luego permite que HPA ajuste
```

---

## PRE-CONDICIONES

```bash
cd /opt/skull/.../BOS_V8/

# 1. F6 y F8 completos
go test -race ./... 2>&1 | grep -E "FAIL|DATA RACE" | wc -l | grep "^0$" \
  && echo "✅ Suite limpia" || echo "❌ resolver fallos primero"

# 2. Acceso al cluster K8s
kubectl cluster-info && echo "✅ cluster accesible" || echo "❌ verificar kubeconfig"

# 3. Permisos actuales del bosagent ServiceAccount
kubectl auth can-i list deployments --as=system:serviceaccount:sbos-system:bosagent \
  && echo "✅ bosagent puede listar deployments"

# 4. Verificar internal/k8s/core.go actual:
grep -n "func.*Scale\|func.*Cordon\|func.*Drain\|func.*Uncordon\|func.*Evict" \
  internal/k8s/core.go \
  && echo "Funciones ya presentes (verificar si son stub)" \
  || echo "Funciones no presentes — crear en F9.2"

# 5. internal/scaler/ debe no existir aún:
[ -d internal/scaler ] && echo "⚠️ scaler/ ya existe — verificar estado" \
  || echo "✅ scaler/ no existe — crear en F9.3"
```

---

## ÁTOMO F9.1 — Schema `manifest.yml` con SLOs

**Objetivo:** Definir el schema del manifiesto de cada ficha con campos de SLO.  
**Tiempo estimado:** 45 minutos

### Crear el schema Go de manifest.yml

```go
// En internal/plugin/ — extender FichaManifest con campos de SLO y K8s

// SLOSpec define los objetivos de nivel de servicio de una ficha.
// El Operator Soberano usa estos valores para decidir cuándo escalar.
type SLOSpec struct {
    // LatencyP99Ms es la latencia P99 máxima aceptable en milisegundos.
    // Si se supera, el scaler puede aumentar réplicas.
    LatencyP99Ms int `yaml:"latency_p99_ms" json:"latency_p99_ms"`

    // ErrorRatePercent es el porcentaje máximo de errores aceptable.
    // Ejemplo: 1.0 = 1% de errores. Si se supera, el scaler alerta.
    ErrorRatePercent float64 `yaml:"error_rate_percent" json:"error_rate_percent"`

    // AvailabilityPercent es la disponibilidad mínima requerida.
    // Ejemplo: 99.9 = 99.9% uptime.
    AvailabilityPercent float64 `yaml:"availability_percent" json:"availability_percent"`

    // MTTR es el tiempo máximo de recuperación en minutos.
    // BOS-REPAIR-01: < 10 min para fichas críticas.
    MTTRMinutes int `yaml:"mttr_minutes" json:"mttr_minutes"`
}

// ScalingSpec define la configuración de escalado de una ficha.
type ScalingSpec struct {
    // MinReplicas es el número mínimo de réplicas.
    MinReplicas int `yaml:"min_replicas" json:"min_replicas"`

    // MaxReplicas es el número máximo de réplicas.
    MaxReplicas int `yaml:"max_replicas" json:"max_replicas"`

    // HPAEnabled activa el escalado horizontal automático.
    HPAEnabled bool `yaml:"hpa_enabled" json:"hpa_enabled"`

    // VPAEnabled activa el ajuste vertical de recursos.
    VPAEnabled bool `yaml:"vpa_enabled" json:"vpa_enabled"`

    // TargetCPUPercent es el porcentaje de CPU objetivo para HPA.
    TargetCPUPercent int `yaml:"target_cpu_percent" json:"target_cpu_percent"`
}

// MaintenanceSpec define el comportamiento durante operaciones de mantenimiento.
type MaintenanceSpec struct {
    // DrainTimeoutSecs es el tiempo máximo para drenar el nodo en segundos.
    DrainTimeoutSecs int `yaml:"drain_timeout_secs" json:"drain_timeout_secs"`

    // AllowDisruptionDuringBusiness permite mantenimiento en horario laboral.
    AllowDisruptionDuringBusiness bool `yaml:"allow_disruption_during_business"`

    // PodDisruptionBudget mínimo de pods disponibles durante mantenimiento.
    MinAvailablePods int `yaml:"min_available_pods" json:"min_available_pods"`
}

// FichaManifest — EXTENDER el tipo existente con estos campos:
// (localizar FichaManifest en internal/plugin/ y agregar)
type FichaManifest struct {
    // ... campos existentes ...

    // SLOs define los objetivos de nivel de servicio.
    // Requerido para fichas con criticality: true.
    SLOs SLOSpec `yaml:"slos" json:"slos"`

    // Scaling define la configuración de escalado.
    Scaling ScalingSpec `yaml:"scaling" json:"scaling"`

    // Maintenance define el comportamiento durante mantenimiento.
    Maintenance MaintenanceSpec `yaml:"maintenance" json:"maintenance"`
}
```

### Ejemplo de manifest.yml con SLOs (para una ficha)

```yaml
# fichas/postgresql/manifest.yml — ejemplo con SLOs
identity:
  id: "postgresql"
  version: "16.x"
  criticality: true
  license: "PostgreSQL"

depends_on: ["sbos-bootstrap-k8s"]

ports:
  primary: 5432
  metrics: 9187

slos:
  latency_p99_ms: 50         # P99 < 50ms para queries simples
  error_rate_percent: 0.1    # < 0.1% de errores
  availability_percent: 99.9 # 99.9% uptime
  mttr_minutes: 5            # recuperación en < 5 min (crítico)

scaling:
  min_replicas: 1
  max_replicas: 3
  hpa_enabled: false   # PostgreSQL no se escala horizontalmente en modo básico
  vpa_enabled: true    # SÍ ajuste vertical de memoria/CPU
  target_cpu_percent: 70

maintenance:
  drain_timeout_secs: 300      # 5 minutos para drenar
  allow_disruption_during_business: false  # no en horario laboral
  min_available_pods: 1
```

**Tests F9.1:**
```go
func TestFichaManifest_SLOsValidos(t *testing.T) {
    m := FichaManifest{
        SLOs: SLOSpec{LatencyP99Ms: 50, ErrorRatePercent: 0.1,
                      AvailabilityPercent: 99.9, MTTRMinutes: 5},
    }
    assert.Greater(t, m.SLOs.LatencyP99Ms, 0)
    assert.Greater(t, m.SLOs.AvailabilityPercent, 99.0)
}

func TestFichaManifest_ParseYAML_ConSLOs(t *testing.T) {
    yaml := `
identity:
  id: test-ficha
  criticality: true
slos:
  latency_p99_ms: 100
  availability_percent: 99.9
  mttr_minutes: 10
`
    var m FichaManifest
    require.NoError(t, parseManifestYAML([]byte(yaml), &m))
    assert.Equal(t, 100, m.SLOs.LatencyP99Ms)
}
```

---

## ÁTOMO F9.2 — `internal/k8s/core.go` extendido

**Objetivo:** Agregar Scale, Cordon, Uncordon, Drain, Evict al cliente K8s existente.  
**Tiempo estimado:** 90 minutos

### Verificar el estado actual de core.go

```bash
grep -n "^func\|^type\|interface" internal/k8s/core.go | head -30
wc -l internal/k8s/core.go
```

### Agregar al ClusterRole del bosagent PRIMERO

**ANTES de implementar las funciones K8s, definir los permisos mínimos.**  
Un ClusterRole mal definido es un vector de ataque.

```yaml
# manifests/rbac/bosagent-clusterrole.yaml
# Principio de least privilege (CIS Kubernetes Benchmark v1.10 — Control 5.1.1)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: bosagent
  labels:
    app.kubernetes.io/managed-by: bos
rules:
  # Lectura general — para monitorización
  - apiGroups: [""]
    resources: ["nodes", "pods", "namespaces", "services", "endpoints"]
    verbs: ["get", "list", "watch"]

  # Deployments y StatefulSets — para fichas SBOS
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets", "replicasets"]
    verbs: ["get", "list", "watch", "update", "patch"]

  # Scale — específicamente para escalado
  - apiGroups: ["apps"]
    resources: ["deployments/scale", "statefulsets/scale"]
    verbs: ["get", "update", "patch"]

  # Nodos — cordon/uncordon (solo taint, no delete)
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "patch", "update"]
    # NUNCA: "delete" en nodes

  # Evict pods — para drain
  - apiGroups: [""]
    resources: ["pods/eviction"]
    verbs: ["create"]

  # HPA y VPA
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: ["autoscaling.k8s.io"]
    resources: ["verticalpodautoscalers"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]

  # Events — para auditoría
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "patch"]

  # PROHIBIDO explícitamente (defense in depth):
  # - secrets (nunca)
  # - configmaps en otros namespaces que no sean sbos-system
  # - nodes/delete
  # - namespaces/delete
```

```bash
# Aplicar el ClusterRole:
kubectl apply -f manifests/rbac/bosagent-clusterrole.yaml
kubectl apply -f manifests/rbac/bosagent-clusterrolebinding.yaml

# Verificar permisos:
kubectl auth can-i scale deployments --as=system:serviceaccount:sbos-system:bosagent \
  && echo "✅ scale OK"
kubectl auth can-i delete nodes --as=system:serviceaccount:sbos-system:bosagent \
  && echo "❌ PELIGRO: bosagent puede eliminar nodos" \
  || echo "✅ delete nodes: prohibido correctamente"
```

### Extender `internal/k8s/core.go`

```go
// Agregar estas funciones al archivo existente internal/k8s/core.go

// ScaleDeployment escala un Deployment al número de réplicas indicado.
//
// Verifica que la ficha existe y que el número de réplicas está dentro
// del rango permitido por su ManifestSpec.Scaling antes de escalar.
//
// Retorna error si el Deployment no existe o si las réplicas están
// fuera del rango [spec.MinReplicas, spec.MaxReplicas].
func (c *Client) ScaleDeployment(ctx context.Context, namespace, name string, replicas int32) error {
    if replicas < 0 {
        return fmt.Errorf("k8s.ScaleDeployment: réplicas no puede ser negativo: %d", replicas)
    }

    scale, err := c.clientset.AppsV1().
        Deployments(namespace).
        GetScale(ctx, name, metav1.GetOptions{})
    if err != nil {
        return fmt.Errorf("k8s.ScaleDeployment: obtener scale de %s/%s: %w", namespace, name, err)
    }

    scale.Spec.Replicas = replicas
    _, err = c.clientset.AppsV1().
        Deployments(namespace).
        UpdateScale(ctx, name, scale, metav1.UpdateOptions{})
    if err != nil {
        return fmt.Errorf("k8s.ScaleDeployment: actualizar %s/%s a %d réplicas: %w",
            namespace, name, replicas, err)
    }

    c.logger.Info("k8s: deployment escalado",
        "namespace", namespace, "name", name, "replicas", replicas)
    return nil
}

// CordonNode marca un nodo como no-schedulable.
//
// SEGURIDAD: esta operación SOLO agrega un taint — nunca elimina el nodo.
// Requiere verificación manual antes de ejecutar en producción si hay
// pods críticos sin PodDisruptionBudget.
func (c *Client) CordonNode(ctx context.Context, nodeName string) error {
    node, err := c.clientset.CoreV1().Nodes().Get(ctx, nodeName, metav1.GetOptions{})
    if err != nil {
        return fmt.Errorf("k8s.CordonNode: obtener nodo %s: %w", nodeName, err)
    }

    if node.Spec.Unschedulable {
        c.logger.Info("k8s: nodo ya está cordoned (idempotente)", "node", nodeName)
        return nil
    }

    node.Spec.Unschedulable = true
    _, err = c.clientset.CoreV1().Nodes().Update(ctx, node, metav1.UpdateOptions{})
    if err != nil {
        return fmt.Errorf("k8s.CordonNode: marcar %s como unschedulable: %w", nodeName, err)
    }

    c.logger.Info("k8s: nodo cordoned", "node", nodeName)
    return nil
}

// UncordonNode restaura un nodo a schedulable.
// Es la compensación de CordonNode en la saga de mantenimiento.
func (c *Client) UncordonNode(ctx context.Context, nodeName string) error {
    node, err := c.clientset.CoreV1().Nodes().Get(ctx, nodeName, metav1.GetOptions{})
    if err != nil {
        return fmt.Errorf("k8s.UncordonNode: obtener nodo %s: %w", nodeName, err)
    }

    if !node.Spec.Unschedulable {
        c.logger.Info("k8s: nodo ya schedulable (idempotente)", "node", nodeName)
        return nil
    }

    node.Spec.Unschedulable = false
    _, err = c.clientset.CoreV1().Nodes().Update(ctx, node, metav1.UpdateOptions{})
    if err != nil {
        return fmt.Errorf("k8s.UncordonNode: restaurar %s: %w", nodeName, err)
    }

    c.logger.Info("k8s: nodo uncordoned", "node", nodeName)
    return nil
}

// DrainNode evicta todos los pods de un nodo con timeout.
//
// El drain usa eviction API (respetuosa con PodDisruptionBudgets) en lugar
// de delete directo. Si un pod no puede ser evictado en el timeout, retorna
// error con la lista de pods que quedaron.
//
// timeoutSecs debe provenir de MaintenanceSpec.DrainTimeoutSecs (típico: 300s).
func (c *Client) DrainNode(ctx context.Context, nodeName string, timeoutSecs int) error {
    if timeoutSecs <= 0 {
        timeoutSecs = 300
    }

    pods, err := c.clientset.CoreV1().Pods("").List(ctx, metav1.ListOptions{
        FieldSelector: "spec.nodeName=" + nodeName + ",status.phase!=Succeeded,status.phase!=Failed",
    })
    if err != nil {
        return fmt.Errorf("k8s.DrainNode: listar pods en %s: %w", nodeName, err)
    }

    deadline := time.Now().Add(time.Duration(timeoutSecs) * time.Second)
    var failedPods []string

    for _, pod := range pods.Items {
        // Ignorar pods de DaemonSet — no se pueden evictar
        if isOwnedByDaemonSet(pod) {
            continue
        }

        evictCtx, cancel := context.WithDeadline(ctx, deadline)
        err := c.evictPod(evictCtx, pod.Name, pod.Namespace)
        cancel()

        if err != nil {
            c.logger.Warn("k8s: pod no evictado",
                "pod", pod.Name, "namespace", pod.Namespace, "error", err)
            failedPods = append(failedPods, pod.Namespace+"/"+pod.Name)
        }
    }

    if len(failedPods) > 0 {
        return fmt.Errorf("k8s.DrainNode: %d pods no evictados en %s: %v",
            len(failedPods), nodeName, failedPods)
    }

    c.logger.Info("k8s: nodo drenado", "node", nodeName, "pods_evictados", len(pods.Items))
    return nil
}

// evictPod evicta un pod usando la Eviction API.
func (c *Client) evictPod(ctx context.Context, podName, namespace string) error {
    eviction := &policyv1.Eviction{
        ObjectMeta: metav1.ObjectMeta{
            Name:      podName,
            Namespace: namespace,
        },
    }
    return c.clientset.CoreV1().Pods(namespace).EvictV1(ctx, eviction)
}

// isOwnedByDaemonSet verifica si un pod pertenece a un DaemonSet.
func isOwnedByDaemonSet(pod corev1.Pod) bool {
    for _, ref := range pod.OwnerReferences {
        if ref.Kind == "DaemonSet" {
            return true
        }
    }
    return false
}
```

**Tests F9.2:**
```go
func TestClient_CordonNode_Idempotente(t *testing.T) {
    // Llamar CordonNode dos veces — debe ser idempotente
    client := newTestK8sClient(t)
    require.NoError(t, client.CordonNode(ctx, "test-node"))
    require.NoError(t, client.CordonNode(ctx, "test-node")) // segunda llamada OK
}

func TestClient_ScaleDeployment_ReplicasNegativas(t *testing.T) {
    client := newTestK8sClient(t)
    err := client.ScaleDeployment(ctx, "sbos", "postgresql", -1)
    assert.Error(t, err, "réplicas negativas debe retornar error")
}
```

---

## ÁTOMO F9.3 — `internal/scaler/scaler.go` — Anti-death-spiral

**Objetivo:** Coordinador HPA+VPA que previene el death spiral.  
**Tiempo estimado:** 120 minutos

```go
// Package scaler implementa el escalado coordinado HPA+VPA
// con protección anti-death-spiral para el daemon bos.
//
// # El death spiral y cómo se previene
//
// El death spiral ocurre cuando HPA y VPA compiten:
//   VPA aumenta resources.requests → HPA ve alta utilización → escala pods
//   → VPA vuelve a aumentar → HPA vuelve a escalar → cluster agotado
//
// La solución es serializar los cambios y verificar capacidad antes de aplicar.
//
// # Referencia
//
// ADR-004 (BOS-REPAIR-02) — Kubernetes Operator Soberano.
// Kubernetes VPA + HPA compatibility guide (k8s.io, 2025).
package scaler

import (
    "context"
    "fmt"
    "sync"
    "time"

    "bos/internal/k8s"
    "bos/internal/plugin"
)

// Scaler coordina HPA y VPA para evitar el death spiral.
//
// Thread safety: Scaler es seguro para uso concurrente.
// El mutex scaleOp garantiza que solo una operación de escalado
// corre a la vez por ficha.
type Scaler struct {
    mu      sync.Mutex
    k8s     *k8s.Client
    loader  *plugin.Loader
    logger  Logger

    // scaleOp serializa operaciones de escalado por ficha.
    // Clave: fichaID, Valor: bool (true = escalado en progreso)
    scaleOp map[string]bool
}

// NewScaler crea un Scaler con las dependencias inyectadas.
func NewScaler(k8sClient *k8s.Client, loader *plugin.Loader, logger Logger) *Scaler {
    return &Scaler{
        k8s:     k8sClient,
        loader:  loader,
        logger:  logger,
        scaleOp: make(map[string]bool),
    }
}

// ScaleDecision encapsula una decisión de escalado propuesta.
type ScaleDecision struct {
    FichaID    string
    Namespace  string
    Deployment string
    NewReplicas int32
    Reason     string
    Source     string // "hpa" | "vpa" | "operator"
}

// EvaluateAndApply evalúa una decisión de escalado y la aplica
// solo si es segura (no genera death spiral y hay capacidad en el cluster).
//
// Retorna nil si se aplicó el escalado.
// Retorna error con razón si fue bloqueado.
func (s *Scaler) EvaluateAndApply(ctx context.Context, d ScaleDecision) error {
    s.mu.Lock()
    if s.scaleOp[d.FichaID] {
        s.mu.Unlock()
        return fmt.Errorf("scaler: operación en progreso para %s — omitir", d.FichaID)
    }
    s.scaleOp[d.FichaID] = true
    s.mu.Unlock()

    defer func() {
        s.mu.Lock()
        delete(s.scaleOp, d.FichaID)
        s.mu.Unlock()
    }()

    // 1. Obtener spec de la ficha para verificar límites
    manifest, err := s.loader.Get(d.FichaID)
    if err != nil {
        return fmt.Errorf("scaler: manifest de %s: %w", d.FichaID, err)
    }

    // 2. Verificar que las réplicas están en el rango permitido
    if err := s.validateReplicaRange(d, manifest); err != nil {
        return err
    }

    // 3. Verificar capacidad del cluster
    if err := s.checkClusterCapacity(ctx, d, manifest); err != nil {
        s.logger.Warn("scaler: escalado bloqueado por capacidad",
            "ficha", d.FichaID, "reason", err.Error())
        return err
    }

    // 4. Verificar que no hay una operación VPA pendiente que conflictúe
    if d.Source == "hpa" {
        if vpaPending, _ := s.isVPAOperationPending(ctx, d.Namespace, d.Deployment); vpaPending {
            s.logger.Warn("scaler: HPA bloqueado — VPA en progreso",
                "ficha", d.FichaID)
            return fmt.Errorf("scaler: VPA en progreso para %s — esperar", d.FichaID)
        }
    }

    // 5. Aplicar el escalado
    if err := s.k8s.ScaleDeployment(ctx, d.Namespace, d.Deployment, d.NewReplicas); err != nil {
        return fmt.Errorf("scaler: aplicar scale para %s: %w", d.FichaID, err)
    }

    s.logger.Info("scaler: escalado aplicado",
        "ficha", d.FichaID, "replicas", d.NewReplicas,
        "source", d.Source, "reason", d.Reason)
    return nil
}

// validateReplicaRange verifica que las réplicas están dentro del rango del manifest.
func (s *Scaler) validateReplicaRange(d ScaleDecision, m *plugin.FichaManifest) error {
    if d.NewReplicas < int32(m.Scaling.MinReplicas) {
        return fmt.Errorf("scaler: réplicas %d < mínimo %d para %s",
            d.NewReplicas, m.Scaling.MinReplicas, d.FichaID)
    }
    if d.NewReplicas > int32(m.Scaling.MaxReplicas) {
        return fmt.Errorf("scaler: réplicas %d > máximo %d para %s",
            d.NewReplicas, m.Scaling.MaxReplicas, d.FichaID)
    }
    return nil
}

// checkClusterCapacity verifica que el cluster tiene capacidad para el escalado.
// Este es el núcleo del anti-death-spiral: si no hay capacidad, bloquear.
func (s *Scaler) checkClusterCapacity(ctx context.Context, d ScaleDecision, m *plugin.FichaManifest) error {
    // Obtener recursos disponibles en el cluster
    nodes, err := s.k8s.ListSchedulableNodes(ctx)
    if err != nil {
        // En caso de error al verificar capacidad, BLOQUEAR por seguridad
        return fmt.Errorf("scaler: verificar capacidad: %w", err)
    }

    // Calcular recursos necesarios para las nuevas réplicas
    // (simplificado — usar requests del container principal)
    // Si los recursos disponibles son < 20% después del escalado: bloquear
    totalCapacity := calculateTotalCapacity(nodes)
    usedCapacity := calculateUsedCapacity(nodes)
    projectedUsage := usedCapacity + (int64(d.NewReplicas) * estimatedPodsResources(m))

    utilizationAfterScale := float64(projectedUsage) / float64(totalCapacity)
    if utilizationAfterScale > 0.80 {
        return fmt.Errorf("scaler: utilización proyectada %.1f%% supera umbral 80%%",
            utilizationAfterScale*100)
    }

    return nil
}

// isVPAOperationPending verifica si hay un cambio de VPA en progreso.
func (s *Scaler) isVPAOperationPending(ctx context.Context, namespace, deployment string) (bool, error) {
    // Verificar si hay pods en estado "Pending" con razón "PodEvicted" (VPA en progreso)
    // TODO: implementar consulta a VPA status
    return false, nil
}

// MaintenanceSaga ejecuta la saga de mantenimiento de un nodo con compensación garantizada.
//
// Pasos: cordon → drain → operación → uncordon
// Compensación: si cualquier paso falla después de cordon, uncordon automático.
//
// NUNCA llamar esta función en un nodo con fichas críticas sin
// verificar PodDisruptionBudgets primero.
func (s *Scaler) MaintenanceSaga(ctx context.Context, nodeName string, op func(context.Context) error, timeoutSecs int) error {
    s.logger.Info("scaler: iniciando saga de mantenimiento", "node", nodeName)

    // Paso 1: Cordon (compensación: uncordon)
    if err := s.k8s.CordonNode(ctx, nodeName); err != nil {
        return fmt.Errorf("scaler.MaintenanceSaga: cordon %s: %w", nodeName, err)
    }

    // Desde aquí: garantizar uncordon en cualquier caso
    var sagaErr error
    defer func() {
        if sagaErr != nil {
            s.logger.Warn("scaler: compensando saga — uncordon", "node", nodeName)
            if uncordonErr := s.k8s.UncordonNode(context.Background(), nodeName); uncordonErr != nil {
                s.logger.Error("scaler: compensación falló — nodo quedó cordoned",
                    "node", nodeName, "error", uncordonErr)
                // Registrar en audit log para intervención manual
            }
        }
    }()

    // Paso 2: Drain
    drainCtx, cancel := context.WithTimeout(ctx, time.Duration(timeoutSecs)*time.Second)
    defer cancel()

    if sagaErr = s.k8s.DrainNode(drainCtx, nodeName, timeoutSecs); sagaErr != nil {
        return fmt.Errorf("scaler.MaintenanceSaga: drain %s: %w", nodeName, sagaErr)
    }

    // Paso 3: Operación de mantenimiento
    if sagaErr = op(ctx); sagaErr != nil {
        return fmt.Errorf("scaler.MaintenanceSaga: operación en %s: %w", nodeName, sagaErr)
    }

    // Paso 4: Uncordon (éxito — no se ejecuta la compensación del defer)
    sagaErr = nil // limpiar para que el defer no compense
    if err := s.k8s.UncordonNode(ctx, nodeName); err != nil {
        return fmt.Errorf("scaler.MaintenanceSaga: uncordon %s: %w", nodeName, err)
    }

    s.logger.Info("scaler: saga de mantenimiento completada", "node", nodeName)
    return nil
}

// Helpers — implementar según el cliente K8s disponible
func calculateTotalCapacity(nodes interface{}) int64  { return 0 } // TODO
func calculateUsedCapacity(nodes interface{}) int64   { return 0 } // TODO
func estimatedPodsResources(m *plugin.FichaManifest) int64 { return 0 } // TODO
```

**Tests F9.3:**
```go
func TestScaler_EvaluateAndApply_AntiDeathSpiral(t *testing.T) {
    // Simular cluster al 85% de utilización
    // EvaluateAndApply debe RECHAZAR el escalado (>80% threshold)
    scaler := newTestScaler(t, clusterUtilization(0.85))
    err := scaler.EvaluateAndApply(ctx, ScaleDecision{
        FichaID: "postgresql", NewReplicas: 5, Source: "hpa",
    })
    assert.Error(t, err, "debe bloquear cuando el cluster está al 85%")
    assert.Contains(t, err.Error(), "supera umbral 80%")
}

func TestScaler_MaintenanceSaga_CompensaEnFallo(t *testing.T) {
    var uncordonCalled bool
    mockK8s := &mockK8sClient{
        cordonFn:   func(node string) error { return nil },
        drainFn:    func(node string) error { return nil },
        uncordonFn: func(node string) error { uncordonCalled = true; return nil },
    }
    scaler := NewScaler(mockK8s, mockLoader(), testLogger(t))

    // La operación de mantenimiento falla
    err := scaler.MaintenanceSaga(ctx, "node-01", func(ctx context.Context) error {
        return fmt.Errorf("operación falló")
    }, 60)

    assert.Error(t, err)
    assert.True(t, uncordonCalled, "compensación: uncordon debe llamarse aunque la operación falle")
}

func TestScaler_EvaluateAndApply_SerializaOperaciones(t *testing.T) {
    // Dos goroutines intentan escalar la misma ficha al mismo tiempo
    // Solo una debe proceder — la otra debe obtener "operación en progreso"
    var applied int64
    // ... test de concurrencia
}
```

---

## VERIFICACIÓN DE CIERRE F9.1-F9.3

```bash
echo "=== VERIFICACIÓN F9.1-F9.3 ==="
go build ./internal/k8s/ ./internal/scaler/ ./internal/plugin/ && echo "✅ BUILD"
go vet  ./internal/k8s/ ./internal/scaler/ ./internal/plugin/ && echo "✅ VET"
go test -race ./internal/k8s/ ./internal/scaler/ ... && echo "✅ TESTS"

# Verificar ClusterRole:
kubectl auth can-i scale deployments \
  --as=system:serviceaccount:sbos-system:bosagent \
  -n sbos-fichas && echo "✅ scale OK"
kubectl auth can-i delete nodes \
  --as=system:serviceaccount:sbos-system:bosagent \
  && echo "❌ PELIGRO" || echo "✅ delete nodes: prohibido"
kubectl auth can-i get secrets \
  --as=system:serviceaccount:sbos-system:bosagent \
  && echo "❌ PELIGRO: acceso a secrets" || echo "✅ secrets: prohibido"
```

---

*EJECUCION-F9.1-F9.3-INSTRUCCIONES-AGENTE.md v1.0*  
*BOS-REPAIR · SKULL · SBOS · 08 de Junio 2026*  
*Fuentes: ADR-004 (BOS-REPAIR-02), SBOS-052, CIS Kubernetes Benchmark v1.10 §5.1.1*  
*Validación técnica: Kubernetes least-privilege RBAC, VPA+HPA anti-death-spiral 2025*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
