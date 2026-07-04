package catalog

import (
	"fmt"
	"os/exec"
	"strings"

	"bos/internal/state"
)

// Rollback reverts a ficha to a previous version.
// Strategy A (auto-packages, category 4): uses the backend directly (apt/pip/helm).
// Strategy B (user-defined fichas): transitions to NO_INSTALADA for reinstall by observer.
func Rollback(mgr *state.Manager, fichaID, targetVersion string) error {
	st, err := mgr.Read()
	if err != nil {
		return fmt.Errorf("catalog: read state: %w", err)
	}

	ficha, ok := st.Fichas[fichaID]
	if !ok {
		return fmt.Errorf("catalog: ficha %s not found", fichaID)
	}

	backend := ficha.Backend
	if backend == "" {
		backend = detectBackendHeuristic(fichaID)
	}

	// Strategy A: auto-generated packages (category 4) — use backend directly.
	if ficha.Category == 4 && backend != "" {
		pkgName := strings.TrimPrefix(fichaID, "sbos-app-")
		if pkgName == fichaID {
			pkgName = fichaID // fallback: usar ID completo
		}
		return rollbackPackage(pkgName, targetVersion, backend)
	}

	// Strategy B: user-defined ficha — set to DESINSTALANDO so observer reinstalls.
	return mgr.Transition(fichaID, state.StateDesinstalada)
}

func rollbackPackage(pkgName, targetVersion, backend string) error {
	var cmd *exec.Cmd
	switch backend {
	case "apt":
		if targetVersion != "" {
			cmd = exec.Command("apt-get", "install", "-y", "--allow-downgrades", pkgName+"="+targetVersion)
		} else {
			cmd = exec.Command("apt-get", "install", "-y", "--reinstall", pkgName)
		}
	case "pip":
		if targetVersion != "" {
			cmd = exec.Command("pip3", "install", pkgName+"=="+targetVersion)
		} else {
			cmd = exec.Command("pip3", "install", "--force-reinstall", pkgName)
		}
	case "helm":
		if targetVersion != "" {
			cmd = exec.Command("helm", "rollback", pkgName, targetVersion)
		} else {
			cmd = exec.Command("helm", "rollback", pkgName)
		}
	default:
		return fmt.Errorf("catalog: unknown backend %s", backend)
	}
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("catalog: rollback %s package %s: %s: %w", backend, pkgName, string(output), err)
	}
	return nil
}

// detectBackendHeuristic guesses the backend from the ficha name for legacy state files.
func detectBackendHeuristic(fichaID string) string {
	name := strings.ToLower(fichaID)
	if strings.Contains(name, "helm") || strings.Contains(name, "chart") || strings.Contains(name, "k8s") {
		return "helm"
	}
	if strings.Contains(name, "python") || strings.Contains(name, "pip") || strings.Contains(name, "python3") {
		return "pip"
	}
	return "apt"
}
