// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

package resources

import (
	"testing"
)

func TestParseMemoryMiB(t *testing.T) {
	casos := []struct {
		input    string
		esperado int64
	}{
		{"2Gi", 2048},
		{"1Gi", 1024},
		{"512Mi", 512},
		{"256Mi", 256},
		{"4Gi", 4096},
		{"1024M", 1024},
		{"2G", 2048},
		{"", 0},
		{"invalid", 0},
	}
	for _, c := range casos {
		got := ParseMemoryMiB(c.input)
		if got != c.esperado {
			t.Errorf("ParseMemoryMiB(%q) = %d, esperado %d", c.input, got, c.esperado)
		}
	}
}

func TestReadMemStatus(t *testing.T) {
	st, err := ReadMemStatus()
	if err != nil {
		t.Fatalf("ReadMemStatus() error: %v", err)
	}
	if st.TotalMiB <= 0 {
		t.Errorf("TotalMiB debe ser > 0, got %d", st.TotalMiB)
	}
	if st.AvailableMiB < 0 {
		t.Errorf("AvailableMiB debe ser >= 0, got %d", st.AvailableMiB)
	}
	if st.UsedPercent < 0 || st.UsedPercent > 100 {
		t.Errorf("UsedPercent fuera de rango: %f", st.UsedPercent)
	}
}

func TestReadCPUStatus(t *testing.T) {
	cpu, err := ReadCPUStatus()
	if err != nil {
		t.Fatalf("ReadCPUStatus() error: %v", err)
	}
	if cpu.Cores <= 0 {
		t.Errorf("Cores debe ser > 0, got %d", cpu.Cores)
	}
	if cpu.Load1 < 0 {
		t.Errorf("Load1 debe ser >= 0, got %f", cpu.Load1)
	}
}
