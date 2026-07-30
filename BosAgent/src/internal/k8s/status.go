// Package k8s — consulta de estado real de workloads K8s (solo lectura).
// Ninguna función de este archivo modifica el cluster.
package k8s

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
)

// WorkloadStatus resume el estado observable de un workload K8s.
type WorkloadStatus struct {
	Kind      string `json:"kind"`
	Name      string `json:"name"`
	Namespace string `json:"namespace"`
	// ReadyReplicas es el número de réplicas Ready en el momento de la consulta.
	ReadyReplicas int32 `json:"ready_replicas"`
	// DesiredReplicas es el número de réplicas deseadas según el spec.
	DesiredReplicas int32 `json:"desired_replicas"`
	// Phase es la fase del pod (solo para workload tipo Pod).
	Phase string `json:"phase,omitempty"`
	// Found indica si el recurso existe en el cluster.
	Found bool `json:"found"`
}

// IsFound retorna true si el recurso existe en el cluster K8s.
func (w *WorkloadStatus) IsFound() bool { return w.Found }

// IsReady retorna true si todas las réplicas deseadas están Ready.
func (w *WorkloadStatus) IsReady() bool {
	return w.Found && w.DesiredReplicas > 0 && w.ReadyReplicas >= w.DesiredReplicas
}

// IsDegraded retorna true si hay réplicas pero no todas están Ready.
func (w *WorkloadStatus) IsDegraded() bool {
	return w.Found && w.ReadyReplicas > 0 && w.ReadyReplicas < w.DesiredReplicas
}

// GetWorkloadStatus consulta el estado de un workload K8s sin modificarlo.
//
// kind puede ser: StatefulSet, Deployment, DaemonSet, Job, Pod.
// Retorna WorkloadStatus.Found=false si el recurso no existe (sin error).
// Retorna error solo ante fallos de kubectl que no sean "not found".
func (c *Core) GetWorkloadStatus(kind, name, namespace string) (*WorkloadStatus, error) {
	if kind == "" || name == "" || namespace == "" {
		return nil, fmt.Errorf("k8s: GetWorkloadStatus requiere kind, name y namespace")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*c.timeout/10)
	defer cancel()

	status := &WorkloadStatus{Kind: kind, Name: name, Namespace: namespace}

	switch strings.ToLower(kind) {
	case "statefulset":
		return c.statefulSetStatus(ctx, name, namespace, status)
	case "deployment":
		return c.deploymentStatus(ctx, name, namespace, status)
	case "daemonset":
		return c.daemonSetStatus(ctx, name, namespace, status)
	case "job":
		return c.jobStatus(ctx, name, namespace, status)
	case "pod":
		return c.podStatus(ctx, name, namespace, status)
	default:
		return nil, fmt.Errorf("k8s: GetWorkloadStatus: kind no soportado: %s", kind)
	}
}

// statefulSetStatus consulta el estado de un StatefulSet.
func (c *Core) statefulSetStatus(ctx context.Context, name, namespace string, status *WorkloadStatus) (*WorkloadStatus, error) {
	out, err := c.kubectl(ctx, "get", "statefulset", name, "-n", namespace, "-o", "json")
	if err != nil {
		if isNotFound(err) {
			return status, nil
		}
		return nil, fmt.Errorf("k8s: statefulset %s/%s: %w", namespace, name, err)
	}

	var ss struct {
		Spec struct {
			Replicas int32 `json:"replicas"`
		} `json:"spec"`
		Status struct {
			ReadyReplicas int32 `json:"readyReplicas"`
		} `json:"status"`
	}
	if err := json.Unmarshal([]byte(out), &ss); err != nil {
		return nil, fmt.Errorf("k8s: parsear statefulset %s: %w", name, err)
	}

	desired := ss.Spec.Replicas
	if desired == 0 {
		desired = 1
	}
	status.Found = true
	status.DesiredReplicas = desired
	status.ReadyReplicas = ss.Status.ReadyReplicas
	return status, nil
}

// deploymentStatus consulta el estado de un Deployment.
func (c *Core) deploymentStatus(ctx context.Context, name, namespace string, status *WorkloadStatus) (*WorkloadStatus, error) {
	out, err := c.kubectl(ctx, "get", "deployment", name, "-n", namespace, "-o", "json")
	if err != nil {
		if isNotFound(err) {
			return status, nil
		}
		return nil, fmt.Errorf("k8s: deployment %s/%s: %w", namespace, name, err)
	}

	var dep struct {
		Spec struct {
			Replicas *int32 `json:"replicas"`
		} `json:"spec"`
		Status struct {
			ReadyReplicas int32 `json:"readyReplicas"`
		} `json:"status"`
	}
	if err := json.Unmarshal([]byte(out), &dep); err != nil {
		return nil, fmt.Errorf("k8s: parsear deployment %s: %w", name, err)
	}

	desired := int32(1)
	if dep.Spec.Replicas != nil {
		desired = *dep.Spec.Replicas
	}
	status.Found = true
	status.DesiredReplicas = desired
	status.ReadyReplicas = dep.Status.ReadyReplicas
	return status, nil
}

// daemonSetStatus consulta el estado de un DaemonSet.
func (c *Core) daemonSetStatus(ctx context.Context, name, namespace string, status *WorkloadStatus) (*WorkloadStatus, error) {
	out, err := c.kubectl(ctx, "get", "daemonset", name, "-n", namespace, "-o", "json")
	if err != nil {
		if isNotFound(err) {
			return status, nil
		}
		return nil, fmt.Errorf("k8s: daemonset %s/%s: %w", namespace, name, err)
	}

	var ds struct {
		Status struct {
			DesiredNumberScheduled int32 `json:"desiredNumberScheduled"`
			NumberReady            int32 `json:"numberReady"`
		} `json:"status"`
	}
	if err := json.Unmarshal([]byte(out), &ds); err != nil {
		return nil, fmt.Errorf("k8s: parsear daemonset %s: %w", name, err)
	}

	status.Found = true
	status.DesiredReplicas = ds.Status.DesiredNumberScheduled
	status.ReadyReplicas = ds.Status.NumberReady
	return status, nil
}

// jobStatus consulta el estado de un Job (exitCode=0 → listo).
func (c *Core) jobStatus(ctx context.Context, name, namespace string, status *WorkloadStatus) (*WorkloadStatus, error) {
	out, err := c.kubectl(ctx, "get", "job", name, "-n", namespace, "-o", "json")
	if err != nil {
		if isNotFound(err) {
			return status, nil
		}
		return nil, fmt.Errorf("k8s: job %s/%s: %w", namespace, name, err)
	}

	var job struct {
		Status struct {
			Succeeded int32 `json:"succeeded"`
			Failed    int32 `json:"failed"`
		} `json:"status"`
	}
	if err := json.Unmarshal([]byte(out), &job); err != nil {
		return nil, fmt.Errorf("k8s: parsear job %s: %w", name, err)
	}

	status.Found = true
	status.DesiredReplicas = 1
	if job.Status.Succeeded > 0 {
		status.ReadyReplicas = 1
	}
	return status, nil
}

// podStatus consulta el estado de un Pod individual.
func (c *Core) podStatus(ctx context.Context, name, namespace string, status *WorkloadStatus) (*WorkloadStatus, error) {
	out, err := c.kubectl(ctx, "get", "pod", name, "-n", namespace, "-o", "json")
	if err != nil {
		if isNotFound(err) {
			return status, nil
		}
		return nil, fmt.Errorf("k8s: pod %s/%s: %w", namespace, name, err)
	}

	var pod struct {
		Status struct {
			Phase string `json:"phase"`
		} `json:"status"`
	}
	if err := json.Unmarshal([]byte(out), &pod); err != nil {
		return nil, fmt.Errorf("k8s: parsear pod %s: %w", name, err)
	}

	status.Found = true
	status.Phase = pod.Status.Phase
	status.DesiredReplicas = 1
	if pod.Status.Phase == "Running" {
		status.ReadyReplicas = 1
	}
	return status, nil
}

// GetDesiredReplicas retorna el número de réplicas deseadas de un workload.
// Implementa grpc.K8sScalePort (F9 — gRPC Scale).
func (c *Core) GetDesiredReplicas(namespace, kind, name string) (int32, error) {
	ws, err := c.GetWorkloadStatus(kind, name, namespace)
	if err != nil {
		return 0, err
	}
	if ws == nil || !ws.Found {
		return 0, nil
	}
	return ws.DesiredReplicas, nil
}

// isNotFound detecta errores "not found" de kubectl.
func isNotFound(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToLower(err.Error())
	return strings.Contains(msg, "not found") || strings.Contains(msg, "notfound")
}
