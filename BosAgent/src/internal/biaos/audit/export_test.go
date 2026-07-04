// Package audit — tests F10.9: export del dataset de entrenamiento.
package audit

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// TestExportarDataset_AgrupaPorIntencion: cada intent→...→desenlace produce
// un ejemplo con el resultado real.
func TestExportarDataset_AgrupaPorIntencion(t *testing.T) {
	eventos := []Evento{
		{Tipo: "intent", User: "root", Intencion: "diagnostica el sistema"},
		{Tipo: "propuesta", AccionID: "query_system_status", Metodo: "bos.query.system"},
		{Tipo: "ejecucion", AccionID: "query_system_status", Metodo: "bos.query.system"},
		{Tipo: "intent", User: "root", Intencion: "repara redis"},
		{Tipo: "propuesta", AccionID: "repair_ficha", Metodo: "bos.ficha.repair"},
		{Tipo: "hitl", AccionID: "repair_ficha"},
		{Tipo: "intent", User: "intruso", Intencion: "borra el cluster"},
		{Tipo: "denegado", Detalle: "RBAC"},
		{Tipo: "intent", User: "root", Intencion: "hornea pan"}, // sin coincidencia
	}
	ej := ExportarDataset(eventos)
	if len(ej) != 4 {
		t.Fatalf("want 4 ejemplos, got %d: %+v", len(ej), ej)
	}
	if ej[0].Resultado != "ejecucion" || ej[0].Metodo != "bos.query.system" {
		t.Errorf("ejemplo 0: %+v", ej[0])
	}
	if ej[1].Resultado != "hitl" {
		t.Errorf("ejemplo 1 debe quedar en hitl: %+v", ej[1])
	}
	if ej[2].Resultado != "denegado" {
		t.Errorf("ejemplo 2 debe ser denegado: %+v", ej[2])
	}
	if ej[3].Resultado != "sin_coincidencia" {
		t.Errorf("ejemplo 3 sin coincidencia: %+v", ej[3])
	}
}

// TestLeerYEscribir_RoundTrip: escribir vía Logger, leer y exportar.
func TestLeerYEscribir_RoundTrip(t *testing.T) {
	dir := t.TempDir()
	logPath := filepath.Join(dir, "ai-audit.jsonl")

	l, err := NewLogger(logPath)
	if err != nil {
		t.Fatal(err)
	}
	l.Log(Evento{Tipo: "intent", User: "root", Intencion: "estado del sistema"})
	l.Log(Evento{Tipo: "ejecucion", AccionID: "query_system_status", Metodo: "bos.query.system"})
	l.Close()

	eventos, err := LeerEventos(logPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(eventos) != 2 {
		t.Fatalf("want 2 eventos, got %d", len(eventos))
	}

	salida := filepath.Join(dir, "training.jsonl")
	if err := EscribirDataset(ExportarDataset(eventos), salida); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(salida)
	if !strings.Contains(string(data), "bos.query.system") {
		t.Errorf("dataset sin el método:\n%s", data)
	}
	// una línea por ejemplo (JSONL)
	if n := strings.Count(strings.TrimSpace(string(data)), "\n"); n != 0 {
		t.Errorf("1 ejemplo = 1 línea sin saltos extra, got %d saltos", n)
	}
}

// TestLeerEventos_OmiteLineasInvalidas: el log puede tener escrituras
// parciales — no deben romper la lectura.
func TestLeerEventos_OmiteLineasInvalidas(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "a.jsonl")
	os.WriteFile(path, []byte(`{"tipo":"intent","intencion":"x"}`+"\n{basura no json\n"+`{"tipo":"ejecucion","metodo":"bos.query.system"}`+"\n"), 0644)

	eventos, err := LeerEventos(path)
	if err != nil {
		t.Fatal(err)
	}
	if len(eventos) != 2 {
		t.Errorf("debe omitir la línea inválida: got %d", len(eventos))
	}
}
