// Subcomando top: bosctl top — métricas unificadas CPU/mem/disco + K8s + fichas.
package main

import (
	"fmt"

	"bos/internal/observability"
)

// cmdTop recolecta un snapshot de métricas del sistema y lo imprime en formato tabla.
func cmdTop(args []string) int {
	snap := observability.CollectTopSnapshot()
	fmt.Println(snap.Format())
	return 0
}
