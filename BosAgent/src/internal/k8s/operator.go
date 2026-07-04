package k8s

// operator.go — F9.2: operaciones del Operator Soberano (BOS-REPAIR-02,
// ADR-004). El bos gobierna el cluster vía kubectl: cordon/uncordon/drain,
// evicción y reinicio controlado de pods, escalado y rollouts.
//
// Riesgo operativo (gate F9.2): en cluster single-node un drain real deja
// el nodo sin capacidad — Drain expone dryRun y el llamador decide. La
// auditoría de cada operación es responsabilidad del handler RPC (A.8.15).

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"time"
)

// NodeInfo es la vista resumida de un nodo para bos.k8s.node.list.
type NodeInfo struct {
	Name        string `json:"name"`
	Ready       bool   `json:"ready"`
	Schedulable bool   `json:"schedulable"`
	Version     string `json:"version"`
	InternalIP  string `json:"internal_ip"`
}

// GetNodes lista los nodos del cluster con estado Ready y schedulable.
func (c *Core) GetNodes() ([]NodeInfo, error) {
	ctx, cancel := context.WithTimeout(context.Background(), c.timeout)
	defer cancel()
	out, err := c.kubectl(ctx, "get", "nodes", "-o", "json")
	if err != nil {
		return nil, err
	}
	var list struct {
		Items []struct {
			Metadata struct {
				Name string `json:"name"`
			} `json:"metadata"`
			Spec struct {
				Unschedulable bool `json:"unschedulable"`
			} `json:"spec"`
			Status struct {
				Conditions []struct {
					Type   string `json:"type"`
					Status string `json:"status"`
				} `json:"conditions"`
				NodeInfo struct {
					KubeletVersion string `json:"kubeletVersion"`
				} `json:"nodeInfo"`
				Addresses []struct {
					Type    string `json:"type"`
					Address string `json:"address"`
				} `json:"addresses"`
			} `json:"status"`
		} `json:"items"`
	}
	if err := json.Unmarshal([]byte(out), &list); err != nil {
		return nil, fmt.Errorf("k8s: parsear nodos: %w", err)
	}
	nodes := make([]NodeInfo, 0, len(list.Items))
	for _, n := range list.Items {
		info := NodeInfo{
			Name:        n.Metadata.Name,
			Schedulable: !n.Spec.Unschedulable,
			Version:     n.Status.NodeInfo.KubeletVersion,
		}
		for _, cond := range n.Status.Conditions {
			if cond.Type == "Ready" && cond.Status == "True" {
				info.Ready = true
			}
		}
		for _, a := range n.Status.Addresses {
			if a.Type == "InternalIP" {
				info.InternalIP = a.Address
			}
		}
		nodes = append(nodes, info)
	}
	return nodes, nil
}

// Cordon marca el nodo como no-schedulable (preparación de mantenimiento).
// Reversible con Uncordon — la saga de mantenimiento garantiza el uncordon.
func (c *Core) Cordon(node string) error {
	if node == "" {
		return fmt.Errorf("k8s: cordon requiere nodo")
	}
	ctx, cancel := context.WithTimeout(context.Background(), c.timeout)
	defer cancel()
	_, err := c.kubectl(ctx, "cordon", node)
	return err
}

// Uncordon libera el nodo tras el mantenimiento.
func (c *Core) Uncordon(node string) error {
	if node == "" {
		return fmt.Errorf("k8s: uncordon requiere nodo")
	}
	ctx, cancel := context.WithTimeout(context.Background(), c.timeout)
	defer cancel()
	_, err := c.kubectl(ctx, "uncordon", node)
	return err
}

// Drain evacúa los pods del nodo. dryRun=true usa --dry-run=server: muestra
// qué se evacuaría SIN tocar nada (obligatorio en single-node — F6.10
// advierte que un drain real deja el cluster sin capacidad).
func (c *Core) Drain(node string, timeout time.Duration, dryRun bool) (string, error) {
	if node == "" {
		return "", fmt.Errorf("k8s: drain requiere nodo")
	}
	if timeout == 0 {
		timeout = 120 * time.Second
	}
	args := []string{"drain", node,
		"--ignore-daemonsets", "--delete-emptydir-data",
		"--grace-period=30", "--timeout=" + timeout.String()}
	if dryRun {
		args = append(args, "--dry-run=server")
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout+30*time.Second)
	defer cancel()
	return c.kubectl(ctx, args...)
}

// EvictPod elimina un pod con grace period — el ReplicaSet/Deployment crea
// el reemplazo (reinicio controlado, bos.k8s.pod.restart usa esto mismo).
func (c *Core) EvictPod(namespace, pod string, gracePeriod int) error {
	if namespace == "" || pod == "" {
		return fmt.Errorf("k8s: evict requiere namespace y pod")
	}
	if gracePeriod <= 0 {
		gracePeriod = 30
	}
	ctx, cancel := context.WithTimeout(context.Background(), c.timeout)
	defer cancel()
	_, err := c.kubectl(ctx, "delete", "pod", pod, "-n", namespace,
		"--grace-period="+strconv.Itoa(gracePeriod))
	return err
}

// ScaleDeployment fija las réplicas de un deployment. La decisión coordinada
// (anti death spiral) vive en internal/scaler — esto es solo el actuador.
func (c *Core) ScaleDeployment(namespace, deployment string, replicas int) error {
	if namespace == "" || deployment == "" {
		return fmt.Errorf("k8s: scale requiere namespace y deployment")
	}
	if replicas < 0 {
		return fmt.Errorf("k8s: réplicas no puede ser negativo: %d", replicas)
	}
	ctx, cancel := context.WithTimeout(context.Background(), c.timeout)
	defer cancel()
	_, err := c.kubectl(ctx, "scale", "deployment", deployment,
		"-n", namespace, "--replicas="+strconv.Itoa(replicas))
	return err
}

// RolloutStatus reporta el estado del rollout de un deployment.
func (c *Core) RolloutStatus(namespace, deployment string) (string, error) {
	if namespace == "" || deployment == "" {
		return "", fmt.Errorf("k8s: rollout status requiere namespace y deployment")
	}
	ctx, cancel := context.WithTimeout(context.Background(), c.timeout)
	defer cancel()
	return c.kubectl(ctx, "rollout", "status", "deployment/"+deployment,
		"-n", namespace, "--timeout=10s")
}

// RolloutUndo revierte el deployment a la revisión anterior (principio de
// reversibilidad — ADR-021).
func (c *Core) RolloutUndo(namespace, deployment string) error {
	if namespace == "" || deployment == "" {
		return fmt.Errorf("k8s: rollout undo requiere namespace y deployment")
	}
	ctx, cancel := context.WithTimeout(context.Background(), c.timeout)
	defer cancel()
	_, err := c.kubectl(ctx, "rollout", "undo", "deployment/"+deployment, "-n", namespace)
	return err
}

// SetResources actualiza requests/limits de los contenedores del deployment
// (actuador del escalado vertical — VPA por decisión coordinada).
func (c *Core) SetResources(namespace, deployment, cpu, memory string) error {
	if namespace == "" || deployment == "" {
		return fmt.Errorf("k8s: set resources requiere namespace y deployment")
	}
	if cpu == "" && memory == "" {
		return fmt.Errorf("k8s: set resources requiere cpu o memoria")
	}
	limits := ""
	requests := ""
	if cpu != "" {
		limits += "cpu=" + cpu
		requests += "cpu=" + cpu
	}
	if memory != "" {
		if limits != "" {
			limits += ","
			requests += ","
		}
		limits += "memory=" + memory
		requests += "memory=" + memory
	}
	ctx, cancel := context.WithTimeout(context.Background(), c.timeout)
	defer cancel()
	_, err := c.kubectl(ctx, "set", "resources", "deployment/"+deployment,
		"-n", namespace, "--limits="+limits, "--requests="+requests)
	return err
}
