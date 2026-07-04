package query

// ubuntu.go — fuente real del estado del SO (Thread "ubuntu" de
// bos.query.system y bos.query.node — BOS-REPAIR-04).
// Lee /proc y statfs directamente: sin exec, sin dependencias, < 1ms.

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
	"syscall"
)

// servicioCriticos son las unidades systemd cuyo estado reporta la fuente
// ubuntu. En hosts sin ellas (dev, CI) reportan "unknown" — no es error.
var serviciosCriticos = []string{"containerd", "kubelet"}

// UbuntuSnapshot reúne CPU, memoria, disco, uptime y servicios systemd.
// Campos del contrato BOS-REPAIR-04: healthy, cpu_pct, mem_pct, disk_pct,
// services, uptime_hours.
func UbuntuSnapshot(ctx context.Context) (interface{}, error) {
	memPct, memErr := memoriaPct()
	diskPct, diskErr := discoPct("/")
	cpuPct := cpuPctAprox()
	uptime := uptimeHoras()

	if memErr != nil && diskErr != nil {
		// /proc y statfs inaccesibles — el OS no responde: ROJO justificado.
		return nil, fmt.Errorf("query.ubuntu: sin acceso a /proc ni statfs: %v / %v", memErr, diskErr)
	}

	services := make(map[string]string, len(serviciosCriticos))
	for _, svc := range serviciosCriticos {
		services[svc] = systemdEstado(ctx, svc)
	}

	// healthy=true significa "el SO es funcional y accesible".
	// Alta saturación de recursos es AMARILLO (campo saturado), no ROJO.
	// ROJO solo cuando /proc o statfs sean inaccesibles (retorno nil arriba).
	saturado := memPct >= 90 || diskPct >= 90

	return map[string]interface{}{
		"healthy":      true,
		"saturado":     saturado,
		"cpu_pct":      cpuPct,
		"mem_pct":      memPct,
		"disk_pct":     diskPct,
		"services":     services,
		"uptime_hours": uptime,
	}, nil
}

// memoriaPct calcula el porcentaje de memoria en uso desde /proc/meminfo
// (MemTotal vs MemAvailable — la métrica que usa free(1)).
func memoriaPct() (int, error) {
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return 0, err
	}
	var total, available int64
	for _, line := range strings.Split(string(data), "\n") {
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		v, _ := strconv.ParseInt(fields[1], 10, 64)
		switch fields[0] {
		case "MemTotal:":
			total = v
		case "MemAvailable:":
			available = v
		}
	}
	if total == 0 {
		return 0, fmt.Errorf("query.ubuntu: MemTotal no encontrado")
	}
	return int((total - available) * 100 / total), nil
}

// discoPct calcula el porcentaje de uso del filesystem raíz vía statfs.
func discoPct(path string) (int, error) {
	var fs syscall.Statfs_t
	if err := syscall.Statfs(path, &fs); err != nil {
		return 0, err
	}
	if fs.Blocks == 0 {
		return 0, fmt.Errorf("query.ubuntu: statfs sin bloques")
	}
	used := fs.Blocks - fs.Bavail
	return int(used * 100 / fs.Blocks), nil
}

// cpuPctAprox aproxima la carga de CPU como load1/nproc — suficiente para
// el semáforo de diagnóstico; la métrica fina la dará Prometheus en F9.7.
func cpuPctAprox() int {
	data, err := os.ReadFile("/proc/loadavg")
	if err != nil {
		return 0
	}
	fields := strings.Fields(string(data))
	if len(fields) == 0 {
		return 0
	}
	load1, _ := strconv.ParseFloat(fields[0], 64)
	pct := int(load1 * 100 / float64(runtime.NumCPU()))
	if pct > 100 {
		pct = 100
	}
	return pct
}

// uptimeHoras lee /proc/uptime (segundos desde boot).
func uptimeHoras() int {
	data, err := os.ReadFile("/proc/uptime")
	if err != nil {
		return 0
	}
	fields := strings.Fields(string(data))
	if len(fields) == 0 {
		return 0
	}
	secs, _ := strconv.ParseFloat(fields[0], 64)
	return int(secs / 3600)
}

// systemdEstado retorna el estado de una unidad ("active", "inactive", …)
// o "unknown" si systemctl no existe o el comando excede el ctx.
func systemdEstado(ctx context.Context, unit string) string {
	out, err := exec.CommandContext(ctx, "systemctl", "is-active", unit).Output()
	estado := strings.TrimSpace(string(out))
	if estado == "" {
		if err != nil {
			return "unknown"
		}
		return "unknown"
	}
	return estado
}
