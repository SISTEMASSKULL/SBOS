package query

// k8s.go — fuente del estado de Kubernetes vía K8sQuerier (M-15).
// K8sQuerier despacha vía k8s.Core si está disponible; cae al exec directo
// en entornos dev/CI sin cluster. El Server inyecta el querier tras iniciar
// el Core (run_normal.go — Principio P1).

import (
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
)

// k8sCore es la interfaz mínima que K8sQuerier necesita de k8s.Core.
// Desacopla query de internal/k8s para evitar dependencias circulares.
type k8sCore interface {
	GetRawJSON(ctx context.Context, args ...string) ([]byte, error)
}

// K8sQuerier despacha operaciones kubectl vía k8s.Core o exec directo.
type K8sQuerier struct {
	core k8sCore
}

// NewK8sQuerier crea un K8sQuerier con el Core inyectado (Principio P1).
// core nil → exec directo (dev/CI sin cluster).
func NewK8sQuerier(core k8sCore) *K8sQuerier {
	return &K8sQuerier{core: core}
}

// nodeList es el subconjunto del JSON de `kubectl get nodes` que la saga usa.
type nodeList struct {
	Items []struct {
		Metadata struct {
			Name string `json:"name"`
		} `json:"metadata"`
		Status struct {
			Conditions []struct {
				Type   string `json:"type"`
				Status string `json:"status"`
			} `json:"conditions"`
			NodeInfo struct {
				KubeletVersion string `json:"kubeletVersion"`
			} `json:"nodeInfo"`
		} `json:"status"`
		Spec struct {
			Unschedulable bool `json:"unschedulable"`
		} `json:"spec"`
	} `json:"items"`
}

// parseNodesSummary convierte el JSON de kubectl get nodes al contrato BOS-REPAIR-04.
func parseNodesSummary(raw []byte) (interface{}, error) {
	var list nodeList
	if err := json.Unmarshal(raw, &list); err != nil {
		return nil, fmt.Errorf("query.k8s: parsear nodos: %w", err)
	}
	nodes := make([]map[string]interface{}, 0, len(list.Items))
	ready := 0
	for _, n := range list.Items {
		status := "NotReady"
		for _, c := range n.Status.Conditions {
			if c.Type == "Ready" && c.Status == "True" {
				status = "Ready"
				ready++
				break
			}
		}
		nodes = append(nodes, map[string]interface{}{
			"name":        n.Metadata.Name,
			"status":      status,
			"schedulable": !n.Spec.Unschedulable,
			"version":     n.Status.NodeInfo.KubeletVersion,
		})
	}
	return map[string]interface{}{
		"healthy":     ready == len(list.Items) && len(list.Items) > 0,
		"nodes":       nodes,
		"nodes_ready": ready,
		"nodes_total": len(list.Items),
	}, nil
}

// NodesSummary consulta los nodos del cluster.
// Contrato BOS-REPAIR-04: healthy, nodes[], nodes_ready, nodes_total.
func (q *K8sQuerier) NodesSummary(ctx context.Context) (interface{}, error) {
	var raw []byte
	var err error
	if q.core != nil {
		raw, err = q.core.GetRawJSON(ctx, "get", "nodes", "-o", "json")
	} else {
		raw, err = exec.CommandContext(ctx, "kubectl", "get", "nodes", "-o", "json").Output()
	}
	if err != nil {
		return nil, fmt.Errorf("query.k8s: kubectl no disponible o sin cluster: %w", err)
	}
	return parseNodesSummary(raw)
}

// PodsOnNode lista los pods que corren en un nodo (saga bos.query.node).
func (q *K8sQuerier) PodsOnNode(ctx context.Context, node string) (interface{}, error) {
	var raw []byte
	var err error
	if q.core != nil {
		raw, err = q.core.GetRawJSON(ctx, "get", "pods",
			"--all-namespaces", "-o", "json",
			"--field-selector", "spec.nodeName="+node)
	} else {
		raw, err = exec.CommandContext(ctx, "kubectl", "get", "pods",
			"--all-namespaces", "-o", "json",
			"--field-selector", "spec.nodeName="+node).Output()
	}
	if err != nil {
		return nil, fmt.Errorf("query.k8s: pods del nodo %s: %w", node, err)
	}
	var list struct {
		Items []struct {
			Metadata struct {
				Name      string `json:"name"`
				Namespace string `json:"namespace"`
			} `json:"metadata"`
			Status struct {
				Phase string `json:"phase"`
			} `json:"status"`
		} `json:"items"`
	}
	if err := json.Unmarshal(raw, &list); err != nil {
		return nil, fmt.Errorf("query.k8s: parsear pods: %w", err)
	}
	pods := make([]map[string]string, 0, len(list.Items))
	for _, p := range list.Items {
		pods = append(pods, map[string]string{
			"pod":       p.Metadata.Name,
			"namespace": p.Metadata.Namespace,
			"phase":     p.Status.Phase,
		})
	}
	return map[string]interface{}{"pods": pods, "total": len(pods)}, nil
}

// PodLogs retorna las últimas n líneas de logs de un pod por etiqueta de
// ficha (saga bos.query.repair, Thread 6).
func (q *K8sQuerier) PodLogs(ctx context.Context, fichaID string, lines int) (interface{}, error) {
	args := []string{"logs", "-l", "app=" + fichaID, "--all-namespaces=false",
		"--tail", fmt.Sprint(lines), "--prefix"}
	var raw []byte
	var err error
	if q.core != nil {
		raw, err = q.core.GetRawJSON(ctx, args...)
	} else {
		raw, err = exec.CommandContext(ctx, "kubectl", args...).CombinedOutput()
	}
	if err != nil {
		return nil, fmt.Errorf("query.k8s: logs de %s: %w", fichaID, err)
	}
	return map[string]interface{}{"lines": string(raw)}, nil
}

// ── Funciones de conveniencia (exec directo, sin Core) ────────────────────
// Mantenidas para compatibilidad con callers que no tienen querier inyectado.

// K8sNodesSummary consulta los nodos del cluster con exec directo.
// Preferir K8sQuerier.NodesSummary cuando k8s.Core esté disponible.
func K8sNodesSummary(ctx context.Context) (interface{}, error) {
	raw, err := exec.CommandContext(ctx, "kubectl", "get", "nodes", "-o", "json").Output()
	if err != nil {
		return nil, fmt.Errorf("query.k8s: kubectl no disponible o sin cluster: %w", err)
	}
	return parseNodesSummary(raw)
}

// K8sPodsOnNode lista los pods de un nodo con exec directo.
// Preferir K8sQuerier.PodsOnNode cuando k8s.Core esté disponible.
func K8sPodsOnNode(ctx context.Context, node string) (interface{}, error) {
	raw, err := exec.CommandContext(ctx, "kubectl", "get", "pods",
		"--all-namespaces", "-o", "json",
		"--field-selector", "spec.nodeName="+node).Output()
	if err != nil {
		return nil, fmt.Errorf("query.k8s: pods del nodo %s: %w", node, err)
	}
	var list struct {
		Items []struct {
			Metadata struct {
				Name      string `json:"name"`
				Namespace string `json:"namespace"`
			} `json:"metadata"`
			Status struct {
				Phase string `json:"phase"`
			} `json:"status"`
		} `json:"items"`
	}
	if err := json.Unmarshal(raw, &list); err != nil {
		return nil, fmt.Errorf("query.k8s: parsear pods: %w", err)
	}
	pods := make([]map[string]string, 0, len(list.Items))
	for _, p := range list.Items {
		pods = append(pods, map[string]string{
			"pod":       p.Metadata.Name,
			"namespace": p.Metadata.Namespace,
			"phase":     p.Status.Phase,
		})
	}
	return map[string]interface{}{"pods": pods, "total": len(pods)}, nil
}

// K8sPodLogs retorna las últimas n líneas de logs con exec directo.
// Preferir K8sQuerier.PodLogs cuando k8s.Core esté disponible.
func K8sPodLogs(ctx context.Context, fichaID string, lines int) (interface{}, error) {
	raw, err := exec.CommandContext(ctx, "kubectl", "logs",
		"-l", "app="+fichaID, "--all-namespaces=false",
		"--tail", fmt.Sprint(lines), "--prefix").CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("query.k8s: logs de %s: %w", fichaID, err)
	}
	return map[string]interface{}{"lines": string(raw)}, nil
}
