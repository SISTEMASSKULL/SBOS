// Package k8s — limpieza de pods bloqueados en estado Terminating.
package k8s

import (
	"context"
	"strings"
	"time"
)

// stuckTerminatingMinutos: tiempo mínimo en minutos para considerar que un pod
// está irrecuperablemente bloqueado en estado Terminating.
const stuckTerminatingMinutos = 5

// CleanStuckTerminating force-elimina pods que llevan más de stuckTerminatingMinutos
// en estado Terminating sin finalizers. Aplica a todos los namespaces porque un pod
// stuck Terminating sin finalizers es siempre seguro de eliminar — StatefulSet y
// Deployment crean un reemplazo automáticamente.
// Retorna (eliminados, error).
func (c *Core) CleanStuckTerminating() (int, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	out, err := c.kubectl(ctx, "get", "pods", "-A", "--no-headers",
		"-o", "custom-columns="+
			"NS:.metadata.namespace,"+
			"NAME:.metadata.name,"+
			"TS:.metadata.deletionTimestamp,"+
			"FINALIZERS:.metadata.finalizers")
	if err != nil {
		return 0, nil
	}

	eliminados := 0
	ahora := time.Now().UTC()

	for _, line := range splitOutput(out) {
		parts := strings.Fields(line)
		if len(parts) < 3 {
			continue
		}
		ns, name, tsStr := parts[0], parts[1], parts[2]
		if tsStr == "<none>" || tsStr == "" {
			continue
		}
		// Si hay finalizers activos, el pod está esperando por ellos — no forzar
		if len(parts) >= 4 && parts[3] != "<none>" {
			continue
		}

		ts, parseErr := time.Parse(time.RFC3339, tsStr)
		if parseErr != nil {
			continue
		}
		if ahora.Sub(ts) < time.Duration(stuckTerminatingMinutos)*time.Minute {
			continue
		}

		args := []string{"delete", "pod", name, "-n", ns, "--grace-period=0", "--force", "--ignore-not-found"}
		if _, delErr := c.kubectl(ctx, args...); delErr == nil {
			eliminados++
		}
	}
	return eliminados, nil
}
