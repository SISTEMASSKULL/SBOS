// Subcomando de reporte de salud: bosctl health-report [--json].
package main

import (
	"encoding/json"
	"fmt"
	"os"

	"bos/internal/observability"
)

// cmdHealthReport recolecta y muestra el reporte completo de salud (Ubuntu + K8s + BOS).
func cmdHealthReport(args []string) int {
	jsonOutput := false
	for _, a := range args {
		if a == "--json" {
			jsonOutput = true
			break
		}
	}

	report := observability.CollectReport()

	if jsonOutput {
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		enc.Encode(report)
		return 0
	}

	fmt.Print(report.Format())
	return 0
}
