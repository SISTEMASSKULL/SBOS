// Package util — ficha.go: versiones canónicas de fichas (ADR-017).
// Fuente única de verdad. Elimina la copia privada en screens/helpers.go
// y unifica con model/phases.go:FichaVersions.
package util

// FichaVersions mapea ID de ficha → versión canónica visualizada en el TUI.
// Para agregar o actualizar una versión: editar solo aquí.
var FichaVersions = map[string]string{
	"postgresql":   "18.4",
	"redis":        "8.6.2",
	"minio":        "RELEASE.2025-05-24",
	"vault":        "2.0.1",
	"keycloak":     "26.6.2",
	"kong":         "3.9.0",
	"nginx":        "1.27",
	"certbot":      "2.11",
	"linkerd":      "2.16.0",
	"kyverno":      "1.13.0",
	"prometheus":   "3.4.0",
	"grafana":      "12.0.1",
	"alertmanager": "0.28.1",
	"alloy":        "1.8.3",
}

// VersionSuffix retorna " vX.Y" para la ficha id, o "" si no tiene versión canónica.
func VersionSuffix(id string) string {
	if v, ok := FichaVersions[id]; ok {
		return " " + v
	}
	return ""
}
