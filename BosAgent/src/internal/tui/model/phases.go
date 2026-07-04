// Package model — phases.go: fases y fichas del DAG de instalación.
// Migrado de cmd/bosctl/install_ui_impl.go en BOS-REPAIR F3.MIGRATE.
package model

import "bos/internal/tui/util"

// DefaultPhases retorna las fases lógicas del DAG de instalación del SBOS.
func DefaultPhases() []InstallPhase {
	return []InstallPhase{
		{"N0 — Sistema Operativo", []string{"sbos-bootstrap-os"}},
		{"N1 — Kubernetes + Calico", []string{"sbos-bootstrap-k8s", "sbos-bootstrap-cni"}},
		{"N2 — Almacenamiento", []string{"postgresql", "redis", "minio", "sbos-bootstrap-storage"}},
		{"N3 — Seguridad Base", []string{"vault", "keycloak"}},
		{"N4 — Gateway + Mesh", []string{"oauth2-proxy", "kong", "nginx", "kyverno", "linkerd"}},
		{"N5 — Observabilidad", []string{"sbos-notifier", "prometheus", "grafana", "alertmanager", "alloy", "sbos-bootstrap-monitoring"}},
		{"N6 — Hardening Final", []string{"sbos-bootstrap-hard", "certbot"}},
	}
}

// FichaPhaseMap mapea cada ficha a su índice de fase.
var FichaPhaseMap = map[string]int{
	"sbos-bootstrap-os":  0,
	"sbos-bootstrap-k8s": 1, "sbos-bootstrap-cni": 1,
	"postgresql": 2, "redis": 2, "minio": 2, "sbos-bootstrap-storage": 2,
	"vault": 3, "keycloak": 3,
	"oauth2-proxy": 4, "kong": 4, "nginx": 4, "kyverno": 4, "linkerd": 4,
	"sbos-notifier": 5, "prometheus": 5, "grafana": 5, "alertmanager": 5,
	"alloy": 5, "sbos-bootstrap-monitoring": 5,
	"sbos-bootstrap-hard": 6, "certbot": 6,
}

// FichaVersions mapea fichas a su versión de visualización.
// Delega a util.FichaVersions — fuente canónica única (T-011).
// Los consumidores externos (ej: cmd/bosctl) pueden seguir usando tuimodel.FichaVersions.
var FichaVersions = util.FichaVersions

// InitFichas inicializa el mapa de fichas desde DefaultPhases.
func InitFichas() map[string]*FichaDetail {
	m := make(map[string]*FichaDetail)
	for _, ph := range DefaultPhases() {
		for _, fid := range ph.Fichas {
			m[fid] = &FichaDetail{ID: fid, Status: FichaPending}
		}
	}
	return m
}
