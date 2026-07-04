package packages

import (
	"fmt"
	"os/exec"
	"strings"
)

// HelmAdapter wraps helm for Kubernetes package management.
type HelmAdapter struct {
	namespace string
}

// NewHelmAdapter creates a helm backend adapter.
func NewHelmAdapter(namespace string) *HelmAdapter {
	if namespace == "" {
		namespace = "default"
	}
	return &HelmAdapter{namespace: namespace}
}

// Install runs helm install <name> <chart> or helm repo add + install.
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

// Remove runs helm uninstall <release>.
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

// Upgrade runs helm upgrade <release> <chart>.
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

// IsInstalled checks whether a helm release exists.
func (h *HelmAdapter) IsInstalled(pkg string) bool {
	release := releaseName(pkg)
	cmd := exec.Command("helm", "status", release, "--namespace", h.namespace)
	return cmd.Run() == nil
}

// InstalledVersion returns the installed chart version.
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

// Name returns the backend identifier.
func (h *HelmAdapter) Name() string { return "helm" }

func releaseName(pkg string) string {
	name := pkg
	if idx := strings.Index(name, "/"); idx >= 0 {
		name = name[idx+1:]
	}
	name = strings.ReplaceAll(name, "_", "-")
	return name
}
