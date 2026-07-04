// Package ficha — Dashboard mínimo por ficha (F11.E.2).
// BOS-REPAIR Plan Maestro v3.
//
// Cada ficha DEBE incluir resources/dashboard.json con un dashboard Grafana mínimo.
// El parser rechaza fichas sin dashboard.json (SAN-10 — contrato obligatorio).
//
// Paneles mínimos requeridos:
//   - health:   estado del pod (Running, Ready, Restarts)
//   - resources: CPU, memoria, disco (requests/limits/usage)
//   - traffic:   requests por segundo, latencia P50/P90/P99, errores 4xx/5xx
//   - errors:    tasa de error, últimos errores, stack traces
//
// El dashboard se integra automáticamente en Grafana al instalar la ficha
// vía ConfigMap → Grafana dashboard provider.
//
// Estándares: Grafana Dashboard JSON Model 2025, SBOS-019 §manifest.ports,
// Prometheus metrics naming convention, ISO 27001 A.8.15.
package ficha

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// ── Tipos ────────────────────────────────────────────────────────────

// DashboardDef define el esquema mínimo de un dashboard Grafana por ficha.
type DashboardDef struct {
	Title       string            `json:"title"`       // "PostgreSQL — SBOS"
	Description string            `json:"description"` // "Métricas de PostgreSQL 18.4"
	Panels      []DashboardPanel  `json:"panels"`
	Tags        []string          `json:"tags,omitempty"`        // ["sbos", "postgresql", "database"]
	Refresh     string            `json:"refresh,omitempty"`     // "30s", "1m"
	SchemaVersion int             `json:"schemaVersion"`         // 16 (Grafana 11+)
	Variables   []DashboardVariable `json:"variables,omitempty"` // variables de filtro
}

// DashboardPanel representa un panel individual dentro del dashboard.
type DashboardPanel struct {
	ID          int      `json:"id"`
	Title       string   `json:"title"`
	Type        string   `json:"type"`        // "stat", "graph", "gauge", "table", "heatmap"
	Description string   `json:"description,omitempty"`
	Targets     []PanelTarget `json:"targets"`
	GridPos     PanelGridPos  `json:"gridPos"`
	FieldConfig *PanelFieldConfig `json:"fieldConfig,omitempty"`
}

// PanelTarget define una consulta de datos para un panel (PromQL).
type PanelTarget struct {
	Expr         string `json:"expr"`         // PromQL: "bos_ficha_health{id=\"postgresql\"}"
	LegendFormat string `json:"legendFormat,omitempty"`
	RefID        string `json:"refId"`        // "A", "B", "C"
}

// PanelGridPos define la posición del panel en la cuadrícula.
type PanelGridPos struct {
	X int `json:"x"`
	Y int `json:"y"`
	W int `json:"w"` // width (columns, max 24)
	H int `json:"h"` // height (rows)
}

// PanelFieldConfig define la configuración visual de un panel.
type PanelFieldConfig struct {
	Unit  string            `json:"unit,omitempty"`  // "percent", "bytes", "s"
	Min   *float64          `json:"min,omitempty"`
	Max   *float64          `json:"max,omitempty"`
	Thresholds *PanelThresholds `json:"thresholds,omitempty"`
}

// PanelThresholds define umbrales de color (verde/amarillo/rojo).
type PanelThresholds struct {
	Mode  string    `json:"mode"`  // "absolute"
	Steps []ThresholdStep `json:"steps"`
}

// ThresholdStep define un paso de umbral.
type ThresholdStep struct {
	Value float64 `json:"value"`
	Color string  `json:"color"` // "green", "yellow", "red"
}

// DashboardVariable define una variable de filtro del dashboard.
type DashboardVariable struct {
	Name    string   `json:"name"`    // "ficha_id", "namespace", "pod"
	Type    string   `json:"type"`    // "query", "constant"
	Query   string   `json:"query"`   // PromQL para opciones
	Current string   `json:"current"` // valor actual
	Options []string `json:"options,omitempty"`
}

// ── Paneles requeridos ────────────────────────────────────────────────

// RequiredPanelTypes lista los tipos de paneles que toda ficha DEBE tener.
var RequiredPanelTypes = []string{"health", "resources", "traffic", "errors"}

// RequiredPanelTitles mapea tipo de panel → título por defecto.
var RequiredPanelTitles = map[string]string{
	"health":    "Health",
	"resources": "Recursos",
	"traffic":   "Tráfico",
	"errors":    "Errores",
}

// ── Validador ─────────────────────────────────────────────────────────

// ValidateDashboard verifica que el dashboard.json de una ficha cumpla el contrato.
// Retorna los paneles faltantes y errores de parseo.
func ValidateDashboard(fichaPath string) ([]string, error) {
	dashboardPath := filepath.Join(fichaPath, "resources", "dashboard.json")

	data, err := os.ReadFile(dashboardPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("dashboard.json no encontrado en %s", dashboardPath)
		}
		return nil, fmt.Errorf("leer dashboard.json: %w", err)
	}

	if len(data) == 0 {
		return nil, fmt.Errorf("dashboard.json vacío en %s", dashboardPath)
	}

	var dash DashboardDef
	if err := json.Unmarshal(data, &dash); err != nil {
		return nil, fmt.Errorf("dashboard.json inválido: %w", err)
	}

	return validateDashboardContent(&dash), nil
}

// validateDashboardContent verifica los paneles requeridos.
func validateDashboardContent(dash *DashboardDef) []string {
	if dash.Title == "" {
		return []string{"dashboard sin título"}
	}

	found := make(map[string]bool)
	for _, panel := range dash.Panels {
		// Detectar tipo de panel por título o por los targets
		panelType := detectPanelType(panel)
		found[panelType] = true
	}

	var missing []string
	for _, required := range RequiredPanelTypes {
		if !found[required] {
			missing = append(missing, required)
		}
	}

	return missing
}

// detectPanelType infiere el tipo de panel por su título y métricas.
func detectPanelType(panel DashboardPanel) string {
	title := strings.ToLower(panel.Title)

	switch {
	case strings.Contains(title, "health") || strings.Contains(title, "salud"),
		strings.Contains(title, "ready") || strings.Contains(title, "running"):
		return "health"

	case strings.Contains(title, "cpu") || strings.Contains(title, "mem") ||
		strings.Contains(title, "recurso") || strings.Contains(title, "disco"):
		return "resources"

	case strings.Contains(title, "rps") || strings.Contains(title, "latencia") ||
		strings.Contains(title, "tráfico") || strings.Contains(title, "request"):
		return "traffic"

	case strings.Contains(title, "error") || strings.Contains(title, "4xx") ||
		strings.Contains(title, "5xx") || strings.Contains(title, "fallo"):
		return "errors"
	}

	return ""
}

// ── Generador ─────────────────────────────────────────────────────────

// GenerateDefaultDashboard crea un dashboard.json mínimo para una ficha.
// Útil para bootstrapping rápido. Los paneles tienen queries PromQL genéricas.
func GenerateDefaultDashboard(fichaID, description string) *DashboardDef {
	return &DashboardDef{
		Title:         fmt.Sprintf("%s — SBOS", fichaID),
		Description:   description,
		SchemaVersion: 16,
		Refresh:       "30s",
		Tags:          []string{"sbos", fichaID},
		Panels:        defaultPanels(fichaID),
	}
}

// defaultPanels genera los 4 paneles mínimos con queries PromQL genéricas.
func defaultPanels(fichaID string) []DashboardPanel {
	return []DashboardPanel{
		{
			ID:    1,
			Title: "Health",
			Type:  "stat",
			Description: "Estado de salud del pod",
			GridPos: PanelGridPos{X: 0, Y: 0, W: 6, H: 4},
			Targets: []PanelTarget{
				{Expr: fmt.Sprintf("bos_ficha_health{id=\"%s\"}", fichaID), RefID: "A"},
			},
		},
		{
			ID:    2,
			Title: "Recursos",
			Type:  "graph",
			Description: "CPU, memoria y disco",
			GridPos: PanelGridPos{X: 6, Y: 0, W: 12, H: 8},
			Targets: []PanelTarget{
				{Expr: fmt.Sprintf("bos_ficha_cpu_usage{id=\"%s\"}", fichaID), LegendFormat: "CPU", RefID: "A"},
				{Expr: fmt.Sprintf("bos_ficha_mem_usage{id=\"%s\"}", fichaID), LegendFormat: "RAM", RefID: "B"},
			},
		},
		{
			ID:    3,
			Title: "Tráfico",
			Type:  "graph",
			Description: "Requests por segundo y latencia",
			GridPos: PanelGridPos{X: 0, Y: 4, W: 12, H: 8},
			Targets: []PanelTarget{
				{Expr: fmt.Sprintf("rate(bos_ficha_requests_total{id=\"%s\"}[5m])", fichaID), LegendFormat: "RPS", RefID: "A"},
				{Expr: fmt.Sprintf("histogram_quantile(0.99, bos_ficha_latency{id=\"%s\"})", fichaID), LegendFormat: "P99", RefID: "B"},
			},
		},
		{
			ID:    4,
			Title: "Errores",
			Type:  "stat",
			Description: "Tasa de error y últimos errores",
			GridPos: PanelGridPos{X: 18, Y: 0, W: 6, H: 4},
			Targets: []PanelTarget{
				{Expr: fmt.Sprintf("rate(bos_ficha_errors_total{id=\"%s\"}[5m])", fichaID), RefID: "A"},
			},
			FieldConfig: &PanelFieldConfig{
				Unit: "percent",
				Thresholds: &PanelThresholds{
					Mode: "absolute",
					Steps: []ThresholdStep{
						{Value: 0, Color: "green"},
						{Value: 1, Color: "yellow"},
						{Value: 5, Color: "red"},
					},
				},
			},
		},
	}
}

// ── Persistencia ──────────────────────────────────────────────────────

// WriteDashboard escribe un dashboard.json en el directorio resources/ de una ficha.
func WriteDashboard(fichaPath string, dash *DashboardDef) error {
	resourcesDir := filepath.Join(fichaPath, "resources")
	if err := os.MkdirAll(resourcesDir, 0755); err != nil {
		return fmt.Errorf("crear resources/: %w", err)
	}

	data, err := json.MarshalIndent(dash, "", "  ")
	if err != nil {
		return fmt.Errorf("serializar dashboard: %w", err)
	}

	dashboardPath := filepath.Join(resourcesDir, "dashboard.json")
	if err := os.WriteFile(dashboardPath, data, 0644); err != nil {
		return fmt.Errorf("escribir dashboard.json: %w", err)
	}

	return nil
}

// HasDashboard verifica si una ficha tiene dashboard.json.
func HasDashboard(fichaPath string) bool {
	dashboardPath := filepath.Join(fichaPath, "resources", "dashboard.json")
	info, err := os.Stat(dashboardPath)
	return err == nil && !info.IsDir() && info.Size() > 0
}
