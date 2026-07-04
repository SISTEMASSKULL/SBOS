// Package ficha — Información de workload para probe K8s (M2.2).
//
// Este archivo proporciona ParseWorkloadInfo que extrae kind/runtime/namespace
// de los manifiestos de una ficha. La lógica de probe K8s real vive en
// internal/reconcile/k8s_discovery.go para evitar dependencias circulares.
//
// Estándares: SBOS-055 SOV-01..08, ADR-021 (18 estados), SBOS-018 P1.
package ficha

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// WorkloadInfo resume la información extraída de los manifiestos de una ficha.
type WorkloadInfo struct {
	FichaID   string // identity.id (nombre del workload en K8s)
	Kind      string // workload.type: StatefulSet, Deployment, DaemonSet, Job, Pod
	Runtime   string // workload.runtime: kubernetes, host, bare-metal
	Namespace string // namespace extraído de yaml_engine.yml
}

// IsKubernetes retorna true si el workload debe correr en Kubernetes.
func (w *WorkloadInfo) IsKubernetes() bool {
	return strings.EqualFold(w.Runtime, "kubernetes")
}

// CanProbe retorna true si hay suficiente información para hacer un probe K8s.
func (w *WorkloadInfo) CanProbe() bool {
	return w.IsKubernetes() && w.Namespace != "" && w.Kind != "" && w.FichaID != ""
}

// ParseWorkloadInfo extrae la información de workload de los manifiestos de una ficha.
// Lee manifest.yml (kind, runtime, id) y yaml_engine.yml (namespace).
//
// Retorna error solo si manifest.yml no existe o no es legible.
// La ausencia de yaml_engine.yml no es error — namespace queda vacío.
//
// Callers conocidos:
//   - internal/reconcile/k8s_discovery.go:DiscoverK8sStates
func ParseWorkloadInfo(fichaPath string) (*WorkloadInfo, error) {
	info := &WorkloadInfo{}

	manifestData, err := os.ReadFile(filepath.Join(fichaPath, "manifest.yml"))
	if err != nil {
		return nil, fmt.Errorf("workload_info: leer manifest.yml en %s: %w", fichaPath, err)
	}
	content := string(manifestData)

	info.FichaID = extractYAMLField(content, "id")
	info.Kind = extractYAMLField(content, "type")
	info.Runtime = extractYAMLField(content, "runtime")

	// namespace está en yaml_engine.yml (opcional — no falla si no existe)
	if yamlData, err := os.ReadFile(filepath.Join(fichaPath, "yaml_engine.yml")); err == nil {
		info.Namespace = extractYAMLField(string(yamlData), "namespace")
	}

	return info, nil
}

// extractYAMLField extrae el valor de un campo YAML sin parser completo.
// Busca la primera línea que empiece con `campo:` en cualquier nivel de indentación.
// Suficiente para campos únicos como namespace, type, runtime, id.
func extractYAMLField(content, field string) string {
	prefix := field + ":"
	for _, line := range strings.Split(content, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, prefix) {
			value := strings.TrimPrefix(trimmed, prefix)
			return strings.Trim(strings.TrimSpace(value), `"'`)
		}
	}
	return ""
}
