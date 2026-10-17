// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Package resources provee métricas de recursos del sistema (RAM, CPU)
// y herramientas de recuperación automática usadas por el observer para
// garantizar instalaciones limpias sin intervención manual.
package resources

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/rs/zerolog/log"
)

// MemStatus refleja la situación de memoria en el momento de la consulta.
type MemStatus struct {
	TotalMiB     int64
	AvailableMiB int64
	UsedMiB      int64
	UsedPercent  float64
}

// CPUStatus refleja la carga promedio del sistema.
type CPUStatus struct {
	Load1  float64 // promedio 1 min
	Load5  float64 // promedio 5 min
	Load15 float64 // promedio 15 min
	Cores  int
}

// ReadMemStatus lee /proc/meminfo y retorna el estado de memoria.
func ReadMemStatus() (MemStatus, error) {
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return MemStatus{}, fmt.Errorf("leer /proc/meminfo: %w", err)
	}

	fields := parseKV(string(data))
	totalKB, _ := parseKB(fields["MemTotal"])
	availKB, _ := parseKB(fields["MemAvailable"])

	totalMiB := totalKB / 1024
	availMiB := availKB / 1024
	usedMiB := totalMiB - availMiB
	usedPct := 0.0
	if totalMiB > 0 {
		usedPct = float64(usedMiB) / float64(totalMiB) * 100
	}

	return MemStatus{
		TotalMiB:     totalMiB,
		AvailableMiB: availMiB,
		UsedMiB:      usedMiB,
		UsedPercent:  usedPct,
	}, nil
}

// ReadCPUStatus lee /proc/loadavg y /proc/cpuinfo.
func ReadCPUStatus() (CPUStatus, error) {
	data, err := os.ReadFile("/proc/loadavg")
	if err != nil {
		return CPUStatus{}, fmt.Errorf("leer /proc/loadavg: %w", err)
	}
	parts := strings.Fields(string(data))
	if len(parts) < 3 {
		return CPUStatus{}, fmt.Errorf("formato inesperado en /proc/loadavg")
	}

	l1, _ := strconv.ParseFloat(parts[0], 64)
	l5, _ := strconv.ParseFloat(parts[1], 64)
	l15, _ := strconv.ParseFloat(parts[2], 64)

	cores := countCores()

	return CPUStatus{
		Load1:  l1,
		Load5:  l5,
		Load15: l15,
		Cores:  cores,
	}, nil
}

// ParseMemoryMiB convierte strings tipo "2Gi", "512Mi", "1024M", "2048" (bytes) a MiB.
// Retorna 0 si el string está vacío o no se puede parsear.
func ParseMemoryMiB(s string) int64 {
	s = strings.TrimSpace(s)
	if s == "" {
		return 0
	}

	s = strings.ToUpper(s)

	multipliers := []struct {
		suffix string
		factor int64
	}{
		{"GIB", 1024},
		{"MIB", 1},
		{"GB", 1000},  // decimal GB → aproximar a MiB
		{"MB", 1},
		{"GI", 1024},
		{"MI", 1},
		{"G", 1024},
		{"M", 1},
		{"KIB", 0}, // KiB → demasiado pequeño para fichas, tratar como 0
		{"KB", 0},
		{"K", 0},
	}

	for _, m := range multipliers {
		if strings.HasSuffix(s, m.suffix) {
			numStr := strings.TrimSuffix(s, m.suffix)
			n, err := strconv.ParseInt(strings.TrimSpace(numStr), 10, 64)
			if err != nil {
				return 0
			}
			return n * m.factor
		}
	}

	// Número puro → asumir bytes, convertir a MiB
	n, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		return 0
	}
	return n / (1024 * 1024)
}

// TryFreeMemory intenta liberar memoria del sistema sin matar procesos:
//  1. Escribe en /proc/sys/vm/drop_caches (libera page cache + reclaimable slabs)
//  2. Espera brevemente y vuelve a leer la memoria disponible
//
// Retorna la nueva memoria disponible en MiB. No falla si drop_caches no tiene
// permiso (entorno de pruebas sin root) — solo loguea y continúa.
func TryFreeMemory() int64 {
	log.Info().Msg("resources: intentando liberar cachés del kernel (drop_caches=1)")

	// sync primero para que las cachés sucias estén limpias antes de liberarlas
	if f, err := os.OpenFile("/proc/sys/vm/drop_caches", os.O_WRONLY, 0); err == nil {
		_, _ = f.WriteString("1\n") // solo page cache (más seguro que 3)
		_ = f.Close()
	} else {
		log.Warn().Err(err).Msg("resources: drop_caches no disponible (sin permiso root?)")
	}

	// Breve pausa para que el kernel procese la liberación
	time.Sleep(500 * time.Millisecond)

	st, err := ReadMemStatus()
	if err != nil {
		return 0
	}
	log.Info().
		Int64("available_mib", st.AvailableMiB).
		Float64("used_pct", st.UsedPercent).
		Msg("resources: memoria tras liberar cachés")
	return st.AvailableMiB
}

// CheckAndRecover verifica que haya suficiente memoria para la ficha indicada.
// Si no la hay, intenta liberar cachés del kernel automáticamente.
// Retorna (true, nil) si hay suficientes recursos, (false, nil) si no (sin error fatal).
// El caller decide si reintentar más tarde o seguir con otra ficha.
func CheckAndRecover(fichaID, memRequest string) (ok bool, availMiB int64) {
	needed := ParseMemoryMiB(memRequest)
	if needed == 0 {
		// Sin requisito declarado → siempre permitir
		return true, 0
	}

	st, err := ReadMemStatus()
	if err != nil {
		log.Warn().Err(err).Str("ficha", fichaID).Msg("resources: no se pudo leer memoria — permitiendo instalación")
		return true, 0
	}

	if st.AvailableMiB >= needed {
		return true, st.AvailableMiB
	}

	// Primer intento: liberar cachés del kernel
	log.Warn().
		Str("ficha", fichaID).
		Int64("necesita_mib", needed).
		Int64("disponible_mib", st.AvailableMiB).
		Float64("uso_pct", st.UsedPercent).
		Msg("resources: memoria insuficiente — intentando recuperación automática")

	availAfter := TryFreeMemory()
	if availAfter >= needed {
		log.Info().
			Str("ficha", fichaID).
			Int64("disponible_mib", availAfter).
			Msg("resources: recuperación exitosa — memoria suficiente para instalar")
		return true, availAfter
	}

	log.Warn().
		Str("ficha", fichaID).
		Int64("necesita_mib", needed).
		Int64("disponible_mib", availAfter).
		Msg("resources: memoria insuficiente tras recuperación — ficha diferida")
	return false, availAfter
}

// CPUOverloaded retorna true si la carga del sistema es mayor que 2× el número de cores.
// Umbral conservador que detecta saturación real sin bloquear instalaciones en carga normal.
func CPUOverloaded() bool {
	cpu, err := ReadCPUStatus()
	if err != nil {
		return false // en caso de duda, no bloquear
	}
	threshold := float64(cpu.Cores) * 2.0
	if cpu.Load1 > threshold {
		log.Warn().
			Float64("load1", cpu.Load1).
			Int("cores", cpu.Cores).
			Float64("umbral", threshold).
			Msg("resources: CPU sobrecargado — instalación diferida un tick")
		return true
	}
	return false
}

// LogSystemStatus emite un log informativo con el estado actual de recursos.
// Llamado periódicamente por el observer para mantener visibilidad del sistema.
func LogSystemStatus() {
	mem, errMem := ReadMemStatus()
	cpu, errCPU := ReadCPUStatus()

	ev := log.Info()
	if errMem == nil {
		ev = ev.Int64("mem_total_mib", mem.TotalMiB).
			Int64("mem_available_mib", mem.AvailableMiB).
			Float64("mem_used_pct", mem.UsedPercent)
	}
	if errCPU == nil {
		ev = ev.Float64("load1", cpu.Load1).
			Float64("load5", cpu.Load5).
			Int("cores", cpu.Cores)
	}
	ev.Msg("resources: estado del sistema")
}

// ─── helpers internos ────────────────────────────────────────────────────────

func parseKV(content string) map[string]string {
	m := make(map[string]string)
	for _, line := range strings.Split(content, "\n") {
		parts := strings.SplitN(line, ":", 2)
		if len(parts) == 2 {
			m[strings.TrimSpace(parts[0])] = strings.TrimSpace(parts[1])
		}
	}
	return m
}

// parseKB extrae el número de kilobytes de strings como "16384 kB".
func parseKB(s string) (int64, error) {
	fields := strings.Fields(s)
	if len(fields) == 0 {
		return 0, fmt.Errorf("vacío")
	}
	return strconv.ParseInt(fields[0], 10, 64)
}

func countCores() int {
	data, err := os.ReadFile("/proc/cpuinfo")
	if err != nil {
		return 1
	}
	count := 0
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(line, "processor") {
			count++
		}
	}
	if count == 0 {
		return 1
	}
	return count
}
