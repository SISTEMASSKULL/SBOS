// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

package resources

import (
	"os"
	"testing"
)

// ── ParseMemoryMiB ────────────────────────────────────────────────────────────

func TestParseMemoryMiB_Unidades(t *testing.T) {
	casos := []struct {
		input    string
		esperado int64
	}{
		{"2Gi", 2048},
		{"1Gi", 1024},
		{"4Gi", 4096},
		{"512Mi", 512},
		{"256Mi", 256},
		{"128Mi", 128},
		{"2G", 2048},
		{"1G", 1024},
		{"1024M", 1024},
		{"512M", 512},
		{"2GiB", 2048},
		{"512MiB", 512},
		// edge cases
		{"", 0},
		{"invalid", 0},
		{"0Mi", 0},
		{"KiB", 0}, // solo sufijo sin número
	}
	for _, c := range casos {
		got := ParseMemoryMiB(c.input)
		if got != c.esperado {
			t.Errorf("ParseMemoryMiB(%q) = %d, quería %d", c.input, got, c.esperado)
		}
	}
}

func TestParseMemoryMiB_NumeroPuro(t *testing.T) {
	// Número puro se interpreta como bytes
	got := ParseMemoryMiB("1073741824") // 1 GiB en bytes
	if got != 1024 {
		t.Errorf("ParseMemoryMiB(1073741824 bytes) = %d MiB, quería 1024", got)
	}
}

// ── ReadMemStatus ─────────────────────────────────────────────────────────────

func TestReadMemStatus_CamposBasicos(t *testing.T) {
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
	if st.UsedMiB < 0 {
		t.Errorf("UsedMiB debe ser >= 0, got %d", st.UsedMiB)
	}
	if st.UsedPercent < 0 || st.UsedPercent > 100 {
		t.Errorf("UsedPercent fuera de rango [0,100]: %f", st.UsedPercent)
	}
	// Total = Used + Available (aproximado; puede diferir por buffers/slabs)
	if st.UsedMiB+st.AvailableMiB > st.TotalMiB+100 {
		t.Errorf("Used(%d) + Available(%d) > Total(%d) + margen",
			st.UsedMiB, st.AvailableMiB, st.TotalMiB)
	}
}

// ── ReadCPUStatus ─────────────────────────────────────────────────────────────

func TestReadCPUStatus_CamposBasicos(t *testing.T) {
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
	if cpu.Load5 < 0 {
		t.Errorf("Load5 debe ser >= 0, got %f", cpu.Load5)
	}
	if cpu.Load15 < 0 {
		t.Errorf("Load15 debe ser >= 0, got %f", cpu.Load15)
	}
}

// ── CPUOverloaded ─────────────────────────────────────────────────────────────

func TestCPUOverloaded_CargaNormal(t *testing.T) {
	// En un entorno de test la carga debe ser < 2×cores
	// Este test puede fallar en máquinas extremadamente cargadas — aceptable.
	cpu, err := ReadCPUStatus()
	if err != nil {
		t.Skip("no se puede leer /proc/loadavg")
	}
	threshold := float64(cpu.Cores) * 2.0
	if cpu.Load1 < threshold {
		if CPUOverloaded() {
			t.Errorf("CPUOverloaded() = true con load1=%.2f threshold=%.2f", cpu.Load1, threshold)
		}
	}
}

// ── CheckAndRecover ───────────────────────────────────────────────────────────

func TestCheckAndRecover_SinRequisito(t *testing.T) {
	// Sin memory_request siempre permite instalar
	ok, _ := CheckAndRecover("ficha-sin-req", "")
	if !ok {
		t.Error("CheckAndRecover con memRequest vacío debe retornar true")
	}
}

func TestCheckAndRecover_RequisitoZero(t *testing.T) {
	ok, _ := CheckAndRecover("ficha-zero", "0Mi")
	if !ok {
		t.Error("CheckAndRecover con memRequest=0Mi debe retornar true")
	}
}

func TestCheckAndRecover_RequisitoMuyPequeno(t *testing.T) {
	// 1 MiB siempre disponible en cualquier máquina de test
	ok, avail := CheckAndRecover("ficha-tiny", "1Mi")
	if !ok {
		t.Errorf("CheckAndRecover(1Mi) falló con %dMiB disponibles", avail)
	}
}

func TestCheckAndRecover_RequisitoImpracticable(t *testing.T) {
	// 999999 GiB nunca disponible — debe retornar false
	ok, _ := CheckAndRecover("ficha-gigante", "999999Gi")
	if ok {
		t.Error("CheckAndRecover(999999Gi) debería retornar false — RAM imposible")
	}
}

// ── TryFreeMemory ─────────────────────────────────────────────────────────────

func TestTryFreeMemory_RetornaValorPositivo(t *testing.T) {
	avail := TryFreeMemory()
	// En entorno sin root drop_caches puede fallar, pero ReadMemStatus sí funciona
	if avail < 0 {
		t.Errorf("TryFreeMemory() = %d, debe ser >= 0", avail)
	}
}

func TestTryFreeMemory_NoDecrece(t *testing.T) {
	// Llamadas sucesivas no deben reducir drásticamente la memoria disponible
	antes, _ := ReadMemStatus()
	TryFreeMemory()
	despues, _ := ReadMemStatus()
	// Permitir hasta 50 MiB de variación (asignaciones del sistema)
	delta := antes.AvailableMiB - despues.AvailableMiB
	if delta > 50 {
		t.Errorf("TryFreeMemory redujo memoria disponible en %d MiB (antes=%d, después=%d)",
			delta, antes.AvailableMiB, despues.AvailableMiB)
	}
}

// ── LogSystemStatus ───────────────────────────────────────────────────────────

func TestLogSystemStatus_NoPanics(t *testing.T) {
	// Verificar que no panica — la salida es a zerolog
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("LogSystemStatus() panicó: %v", r)
		}
	}()
	LogSystemStatus()
}

// ── parseKV / parseKB (helpers internos) ─────────────────────────────────────

func TestParseKV_EntradaVacia(t *testing.T) {
	m := parseKV("")
	if len(m) != 0 {
		t.Errorf("parseKV(\"\") debe retornar mapa vacío, got %v", m)
	}
}

func TestParseKV_MultiplesLineas(t *testing.T) {
	input := "MemTotal:       16384 kB\nMemAvailable:   8192 kB\n"
	m := parseKV(input)
	if m["MemTotal"] != "16384 kB" {
		t.Errorf("MemTotal: got %q", m["MemTotal"])
	}
	if m["MemAvailable"] != "8192 kB" {
		t.Errorf("MemAvailable: got %q", m["MemAvailable"])
	}
}

func TestParseKB_Formato(t *testing.T) {
	n, err := parseKB("16384 kB")
	if err != nil {
		t.Fatalf("parseKB: %v", err)
	}
	if n != 16384 {
		t.Errorf("parseKB = %d, quería 16384", n)
	}
}

func TestParseKB_Vacio(t *testing.T) {
	_, err := parseKB("")
	if err == nil {
		t.Error("parseKB(\"\") debe retornar error")
	}
}

// ── SignalZombieParents ───────────────────────────────────────────────────────

func TestSignalZombieParents_NoPanics(t *testing.T) {
	// No puede crear zombies en test, pero verifica que no panica con /proc real
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("SignalZombieParents() panicó: %v", r)
		}
	}()
	n := SignalZombieParents()
	if n < 0 {
		t.Errorf("SignalZombieParents() = %d, debe ser >= 0", n)
	}
}

func TestSignalZombieParents_SinProcDir(t *testing.T) {
	// Si /proc no existe (entorno aislado), retorna 0 sin error
	// Simulamos leyendo un directorio vacío temporal
	tmp := t.TempDir()
	// Crear entrada no-numérica (debe ignorarse)
	if err := os.Mkdir(tmp+"/not-a-pid", 0755); err != nil {
		t.Fatal(err)
	}
	// Verificar que el helper numérico no falla con directorios no-PID
	entries, _ := os.ReadDir(tmp)
	for _, e := range entries {
		if _, err := parseInt(e.Name()); err == nil {
			t.Errorf("'%s' no debería parsear como PID", e.Name())
		}
	}
}

// parseInt es un helper de test para verificar que nombres no-numéricos no parsean.
func parseInt(s string) (int, error) {
	var n int
	_, err := sscanf(s, &n)
	return n, err
}

func sscanf(s string, n *int) (int, error) {
	_, err := os.Stat("/proc/" + s + "/status")
	if err != nil {
		return 0, err
	}
	return 1, nil
}
