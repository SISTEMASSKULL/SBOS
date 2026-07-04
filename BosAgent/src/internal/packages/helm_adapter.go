package packages

import (
	"fmt"
	"os/exec"
	"strings"
)

// HelmAdapter envuelve helm para gestión de paquetes en Kubernetes.
//
// Thread safety: stateless salvo namespace — seguro para uso concurrente.
type HelmAdapter struct {
	namespace string
}

// NewHelmAdapter crea un adaptador helm para el namespace dado.
// Si namespace es vacío, usa "default".
func NewHelmAdapter(namespace string) *HelmAdapter {
	if namespace == "" {
		namespace = "default"
	}
	return &HelmAdapter{namespace: namespace}
}

// Install ejecuta helm install <release> <chart> en el namespace configurado.
//
// Recibe:
//   - pkg: string — formato "repo/chart" o "chart". Determina el release name automáticamente.
//
// Retorna: (output de helm, error si la instalación falla).
//
// Efectos secundarios: crea un release Helm en el cluster K8s.
func (h *HelmAdapter) Install(pkg string) (string, error) {
	// pkg format: "repo/chart" or just "chart"
	release := releaseName(pkg)
	chart := pkg

	cmd := exec.Command("helm", "install", release, chart,
		"--namespace", h.namespace, "--create-namespace")
	out, err := cmd.CombinedOutput()
	output := strings.TrimSpace(string(out))
	if err != nil {
		return output, fmt.Errorf("helm install %s: %w", pkg, err)
	}
	return output, nil
}

// Remove ejecuta helm uninstall. Si el release no existe, lo trata como éxito (idempotente).
func (h *HelmAdapter) Remove(pkg string) (string, error) {
	release := releaseName(pkg)
	cmd := exec.Command("helm", "uninstall", release, "--namespace", h.namespace)
	out, err := cmd.CombinedOutput()
	output := strings.TrimSpace(string(out))
	if err != nil {
		// Already uninstalled is not an error
		if strings.Contains(output, "not found") {
			return output, nil
		}
		return output, fmt.Errorf("helm uninstall %s: %w", pkg, err)
	}
	return output, nil
}

// Upgrade ejecuta helm upgrade <release> <chart> con la versión especificada.
// Si version es vacío, usa la versión más reciente del repositorio.
func (h *HelmAdapter) Upgrade(pkg, version string) (string, error) {
	release := releaseName(pkg)
	chart := pkg

	args := []string{"upgrade", release, chart, "--namespace", h.namespace}
	if version != "" {
		args = append(args, "--version", version)
	}

	cmd := exec.Command("helm", args...)
	out, err := cmd.CombinedOutput()
	output := strings.TrimSpace(string(out))
	if err != nil {
		return output, fmt.Errorf("helm upgrade %s: %w", pkg, err)
	}
	return output, nil
}

// IsInstalled verifica si un release Helm existe y está desplegado.
func (h *HelmAdapter) IsInstalled(pkg string) bool {
	release := releaseName(pkg)
	cmd := exec.Command("helm", "status", release, "--namespace", h.namespace)
	return cmd.Run() == nil
}

// InstalledVersion retorna la versión del chart instalado, o "" si no está instalado.
func (h *HelmAdapter) InstalledVersion(pkg string) string {
	release := releaseName(pkg)
	cmd := exec.Command("helm", "list", "--namespace", h.namespace,
		"-f", fmt.Sprintf("^%s$", release), "-o", "json")
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

// Name retorna el identificador del backend helm.
func (h *HelmAdapter) Name() string { return "helm" }

func releaseName(pkg string) string {
	name := pkg
	if idx := strings.Index(name, "/"); idx >= 0 {
		name = name[idx+1:]
	}
	name = strings.ReplaceAll(name, "_", "-")
	return name
}
