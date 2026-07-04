package ficha

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestGenerateDefaultDashboard(t *testing.T) {
	dash := GenerateDefaultDashboard("postgresql", "PostgreSQL 18.4 — motor de BD")

	if dash.Title != "postgresql — SBOS" {
		t.Errorf("título esperado postgresql — SBOS, obtenido %s", dash.Title)
	}
	if dash.SchemaVersion != 16 {
		t.Errorf("schemaVersion debe ser 16, obtenido %d", dash.SchemaVersion)
	}
	if dash.Refresh != "30s" {
		t.Errorf("refresh debe ser 30s, obtenido %s", dash.Refresh)
	}
	if len(dash.Panels) != 4 {
		t.Fatalf("esperado 4 paneles, obtenido %d", len(dash.Panels))
	}
	if !containsTag(dash.Tags, "sbos") || !containsTag(dash.Tags, "postgresql") {
		t.Error("tags deben contener sbos y postgresql")
	}
}

func TestDefaultPanels(t *testing.T) {
	panels := defaultPanels("redis")

	if len(panels) != 4 {
		t.Fatalf("esperado 4 paneles, obtenido %d", len(panels))
	}

	// Panel 1: Health
	if panels[0].Type != "stat" {
		t.Error("panel health debe ser stat")
	}
	if panels[0].Title != "Health" {
		t.Errorf("panel 0 título debe ser Health, obtenido %s", panels[0].Title)
	}

	// Panel 2: Recursos
	if panels[1].Type != "graph" {
		t.Error("panel recursos debe ser graph")
	}

	// Panel 3: Tráfico
	if len(panels[2].Targets) != 2 {
		t.Error("panel tráfico debe tener 2 targets (RPS + P99)")
	}

	// Panel 4: Errores con thresholds
	if panels[3].FieldConfig == nil {
		t.Error("panel errores debe tener fieldConfig con thresholds")
	}
}

func TestWriteAndValidateDashboard(t *testing.T) {
	dir := t.TempDir()
	fichaPath := filepath.Join(dir, "test-ficha")

	dash := GenerateDefaultDashboard("test-ficha", "Test dashboard")
	err := WriteDashboard(fichaPath, dash)
	if err != nil {
		t.Fatalf("WriteDashboard falló: %v", err)
	}

	// Verificar que el archivo existe
	dashboardPath := filepath.Join(fichaPath, "resources", "dashboard.json")
	if _, err := os.Stat(dashboardPath); os.IsNotExist(err) {
		t.Fatal("dashboard.json no fue creado")
	}

	// Validar
	missing, err := ValidateDashboard(fichaPath)
	if err != nil {
		t.Fatalf("ValidateDashboard falló: %v", err)
	}
	if len(missing) > 0 {
		t.Errorf("no deberían faltar paneles, faltan: %v", missing)
	}
}

func TestValidateDashboard_Missing(t *testing.T) {
	dir := t.TempDir()
	fichaPath := filepath.Join(dir, "no-dashboard")
	os.MkdirAll(filepath.Join(fichaPath, "resources"), 0755)

	_, err := ValidateDashboard(fichaPath)
	if err == nil {
		t.Error("debe fallar si no hay dashboard.json")
	}
}

func TestValidateDashboard_Empty(t *testing.T) {
	dir := t.TempDir()
	fichaPath := filepath.Join(dir, "empty-dashboard")
	resDir := filepath.Join(fichaPath, "resources")
	os.MkdirAll(resDir, 0755)
	os.WriteFile(filepath.Join(resDir, "dashboard.json"), []byte(""), 0644)

	_, err := ValidateDashboard(fichaPath)
	if err == nil {
		t.Error("debe fallar si dashboard.json está vacío")
	}
}

func TestValidateDashboard_InvalidJSON(t *testing.T) {
	dir := t.TempDir()
	fichaPath := filepath.Join(dir, "bad-json")
	resDir := filepath.Join(fichaPath, "resources")
	os.MkdirAll(resDir, 0755)
	os.WriteFile(filepath.Join(resDir, "dashboard.json"), []byte("{invalid}"), 0644)

	_, err := ValidateDashboard(fichaPath)
	if err == nil {
		t.Error("debe fallar si el JSON es inválido")
	}
}

func TestValidateDashboardContent_MissingPanels(t *testing.T) {
	dash := &DashboardDef{
		Title:  "test",
		Panels: []DashboardPanel{}, // sin paneles
	}

	missing := validateDashboardContent(dash)
	if len(missing) != 4 {
		t.Errorf("esperado 4 paneles faltantes, obtenido %d: %v", len(missing), missing)
	}
	// Deben faltar los 4 requeridos
	for _, required := range RequiredPanelTypes {
		if !containsStrInSlice(missing, required) {
			t.Errorf("debe faltar panel: %s", required)
		}
	}
}

func TestDetectPanelType(t *testing.T) {
	tests := []struct {
		title string
		want  string
	}{
		{"Pod Health", "health"},
		{"Salud del servicio", "health"},
		{"CPU Usage", "resources"},
		{"Memoria", "resources"},
		{"Disco", "resources"},
		{"Requests por segundo", "traffic"},
		{"Latencia P99", "traffic"},
		{"Tráfico HTTP", "traffic"},
		{"Errores 5xx", "errors"},
		{"Tasa de error", "errors"},
		{"Fallo en replicación", "errors"},
		{"Conexiones activas", ""}, // no reconocido
	}

	for _, tt := range tests {
		panel := DashboardPanel{Title: tt.title}
		got := detectPanelType(panel)
		if got != tt.want {
			t.Errorf("detectPanelType(%q): esperado %q, obtenido %q", tt.title, tt.want, got)
		}
	}
}

func TestHasDashboard(t *testing.T) {
	dir := t.TempDir()

	// Sin dashboard
	if HasDashboard(dir) {
		t.Error("sin archivo debe ser false")
	}

	// Con dashboard válido
	resDir := filepath.Join(dir, "resources")
	os.MkdirAll(resDir, 0755)
	os.WriteFile(filepath.Join(resDir, "dashboard.json"), []byte(`{"title":"test"}`), 0644)

	if !HasDashboard(dir) {
		t.Error("con archivo debe ser true")
	}
}

func TestDashboardJSON_Roundtrip(t *testing.T) {
	dash := GenerateDefaultDashboard("keycloak", "Keycloak 26.6.2")

	// Serializar
	data, err := json.Marshal(dash)
	if err != nil {
		t.Fatalf("marshal falló: %v", err)
	}

	// Deserializar
	var restored DashboardDef
	if err := json.Unmarshal(data, &restored); err != nil {
		t.Fatalf("unmarshal falló: %v", err)
	}

	if restored.Title != dash.Title {
		t.Error("roundtrip: título no coincide")
	}
	if len(restored.Panels) != len(dash.Panels) {
		t.Error("roundtrip: número de paneles no coincide")
	}
}

func containsTag(tags []string, tag string) bool {
	for _, t := range tags {
		if t == tag {
			return true
		}
	}
	return false
}

func containsStrInSlice(slice []string, s string) bool {
	for _, item := range slice {
		if item == s {
			return true
		}
	}
	return false
}

func TestRequiredPanels(t *testing.T) {
	if len(RequiredPanelTypes) != 4 {
		t.Errorf("debe haber 4 tipos de paneles requeridos, hay %d", len(RequiredPanelTypes))
	}
	expected := []string{"health", "resources", "traffic", "errors"}
	for _, e := range expected {
		found := false
		for _, r := range RequiredPanelTypes {
			if r == e {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("falta panel requerido: %s", e)
		}
	}
}
