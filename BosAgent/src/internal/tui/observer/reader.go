// Package observer proporciona un lector periódico de métricas del SO
// para alimentar el dashboard de control (ctrl.DashModel).
//
// Patrón obligatorio (SBOS_Backend_Development_Standards §7.4):
//   - Read() es pura — lee /proc, retorna datos, sin side effects.
//   - Start() corre en background — llama Read() periódicamente, envía DashTickMsg al canal.
//
// Separar Read() de Start() permite testear la lectura sin goroutines ni timers.
package observer

import (
	"bufio"
	"context"
	"os"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"bos/internal/capacity"
)

// SystemSnap es una captura puntual de métricas del sistema operativo.
type SystemSnap struct {
	// CPU
	Cores   []float64     // uso por core (0-100)
	Load1   float64       // load average 1 min
	Load5   float64       // load average 5 min
	Load15  float64       // load average 15 min
	Procs   int           // procesos totales en ejecución
	Uptime  time.Duration // tiempo desde el boot

	// Memoria
	TotalGB   float64
	UsedGB    float64
	FreeGB    float64
	BuffGB    float64
	SwapTotal float64
	SwapUsed  float64

	// Disco raíz
	DiskTotalGB float64
	DiskUsedGB  float64

	// Red (primera interfaz no-loopback)
	Iface     string
	TXBytesS  float64 // bytes/s transmitidos
	RXBytesS  float64 // bytes/s recibidos
	TXTotalGB float64
	RXTotalGB float64

	// Umbrales de capacidad (nulos si capacity.yaml no existe todavía)
	CapReqs *capacity.Requirements
}

// capacityCache guarda el Requirements cargado de capacity.yaml.
// Se carga una vez al arrancar (o al primer Read tras la creación del archivo).
var (
	capOnce sync.Once
	capReqs *capacity.Requirements
)

// cpuStat almacena los tiempos acumulados de un core desde /proc/stat.
type cpuStat struct {
	user, nice, sys, idle, iowait, irq, softirq, steal uint64
}

// prevStats guarda la lectura anterior para calcular delta de CPU.
// Accedido solo desde el bucle BubbleTea (goroutine única de la UI).
var prevStats []cpuStat
var prevNetRX, prevNetTX uint64
var prevNetTime time.Time

// loadCapacity intenta cargar capacity.yaml una vez. Si el archivo aún no existe
// (instalación en progreso), capReqs queda nil y se reintentará en el próximo tick.
func loadCapacity() {
	if e, err := capacity.Load(capacity.DefaultPath); err == nil {
		r := capacity.Calculate(e)
		capReqs = &r
	}
}

// ReloadCapacity fuerza una nueva lectura de capacity.yaml en el próximo tick.
// Llamar después de que el wizard guarde los estimados.
func ReloadCapacity() {
	capOnce = sync.Once{}
	capReqs = nil
}

// Read captura métricas del sistema en el momento de la llamada.
// Función pura respecto a efectos observables: lee /proc, no escribe estado externo.
// (El estado interno prevStats/prevNet es necesario para calcular deltas.)
func Read() SystemSnap {
	// Intentar cargar capacity.yaml si aún no se ha cargado (o fue reseteado).
	capOnce.Do(loadCapacity)
	// Si el archivo no existía al inicio pero ya fue creado, recargarlo.
	if capReqs == nil {
		loadCapacity()
	}

	snap := SystemSnap{}
	snap.Cores, snap.Load1, snap.Load5, snap.Load15, snap.Procs = readCPU()
	snap.Uptime = readUptime()
	snap.TotalGB, snap.UsedGB, snap.FreeGB, snap.BuffGB, snap.SwapTotal, snap.SwapUsed = readMem()
	snap.DiskTotalGB, snap.DiskUsedGB = readDisk("/")
	snap.Iface, snap.TXBytesS, snap.RXBytesS, snap.TXTotalGB, snap.RXTotalGB = readNet()
	snap.CapReqs = capReqs

	return snap
}

// Start llama Read() cada interval y envía los resultados a ch.
// Se detiene cuando ctx se cancela.
func Start(ctx context.Context, interval time.Duration, ch chan<- SystemSnap) {
	if interval <= 0 {
		interval = 3 * time.Second
	}
	// Primera lectura inmediata para inicializar el estado prev.
	ch <- Read()
	t := time.NewTicker(interval)
	defer t.Stop()
	for {
		select {
		case <-t.C:
			ch <- Read()
		case <-ctx.Done():
			return
		}
	}
}

// ── lectores de /proc ──────────────────────────────────────────────────────

func readCPU() (cores []float64, load1, load5, load15 float64, procs int) {
	// Leer /proc/stat para obtener tiempos por core.
	data, err := os.ReadFile("/proc/stat")
	if err != nil {
		// Sin acceso a /proc (test en macOS): devolver datos aproximados.
		ncpu := runtime.NumCPU()
		cores = make([]float64, ncpu)
		return
	}

	var curStats []cpuStat
	scanner := bufio.NewScanner(strings.NewReader(string(data)))
	for scanner.Scan() {
		line := scanner.Text()
		if !strings.HasPrefix(line, "cpu") || line == "" {
			continue
		}
		if strings.HasPrefix(line, "cpu ") {
			continue // línea "cpu " total — usamos por core
		}
		fields := strings.Fields(line)
		if len(fields) < 8 {
			continue
		}
		var s cpuStat
		s.user, _ = parseU(fields[1])
		s.nice, _ = parseU(fields[2])
		s.sys, _ = parseU(fields[3])
		s.idle, _ = parseU(fields[4])
		s.iowait, _ = parseU(fields[5])
		s.irq, _ = parseU(fields[6])
		s.softirq, _ = parseU(fields[7])
		if len(fields) > 8 {
			s.steal, _ = parseU(fields[8])
		}
		curStats = append(curStats, s)
	}

	cores = make([]float64, len(curStats))
	if len(prevStats) == len(curStats) {
		for i, cur := range curStats {
			prev := prevStats[i]
			totalDelta := (cur.user + cur.nice + cur.sys + cur.idle + cur.iowait +
				cur.irq + cur.softirq + cur.steal) -
				(prev.user + prev.nice + prev.sys + prev.idle + prev.iowait +
					prev.irq + prev.softirq + prev.steal)
			idleDelta := (cur.idle + cur.iowait) - (prev.idle + prev.iowait)
			if totalDelta > 0 {
				cores[i] = float64(totalDelta-idleDelta) / float64(totalDelta) * 100
			}
		}
	}
	prevStats = curStats

	// Load average y procs de /proc/loadavg.
	if la, err := os.ReadFile("/proc/loadavg"); err == nil {
		fields := strings.Fields(string(la))
		if len(fields) >= 3 {
			load1, _ = strconv.ParseFloat(fields[0], 64)
			load5, _ = strconv.ParseFloat(fields[1], 64)
			load15, _ = strconv.ParseFloat(fields[2], 64)
		}
		if len(fields) >= 4 {
			// Campo 4 es "running/total" — tomamos total.
			parts := strings.SplitN(fields[3], "/", 2)
			if len(parts) == 2 {
				p, _ := strconv.Atoi(parts[1])
				procs = p
			}
		}
	}
	return
}

func readUptime() time.Duration {
	data, err := os.ReadFile("/proc/uptime")
	if err != nil {
		return 0
	}
	fields := strings.Fields(string(data))
	if len(fields) == 0 {
		return 0
	}
	secs, _ := strconv.ParseFloat(fields[0], 64)
	return time.Duration(secs * float64(time.Second))
}

func readMem() (totalGB, usedGB, freeGB, buffGB, swapTotal, swapUsed float64) {
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return
	}
	m := parseKV(string(data))
	toGB := func(kib uint64) float64 { return float64(kib) / 1024 / 1024 }

	total := m["MemTotal"]
	avail := m["MemAvailable"]
	free := m["MemFree"]
	buffers := m["Buffers"]
	cached := m["Cached"]
	reclaimable := m["SReclaimable"]

	totalGB = toGB(total)
	freeGB = toGB(free)
	buffGB = toGB(buffers + cached + reclaimable)

	used := total - avail
	if total > 0 && used > total {
		used = 0
	}
	usedGB = toGB(used)

	swapTotal = toGB(m["SwapTotal"])
	swapFree := toGB(m["SwapFree"])
	swapUsed = swapTotal - swapFree
	return
}

func readDisk(path string) (totalGB, usedGB float64) {
	var fs syscall.Statfs_t
	if err := syscall.Statfs(path, &fs); err != nil {
		return
	}
	bsize := uint64(fs.Bsize)
	totalGB = float64(fs.Blocks*bsize) / 1024 / 1024 / 1024
	usedGB = float64((fs.Blocks-fs.Bavail)*bsize) / 1024 / 1024 / 1024
	return
}

func readNet() (iface string, txBytesS, rxBytesS, txTotalGB, rxTotalGB float64) {
	data, err := os.ReadFile("/proc/net/dev")
	if err != nil {
		return
	}
	now := time.Now()

	var bestTX, bestRX uint64
	scanner := bufio.NewScanner(strings.NewReader(string(data)))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if !strings.Contains(line, ":") {
			continue
		}
		parts := strings.SplitN(line, ":", 2)
		name := strings.TrimSpace(parts[0])
		if name == "lo" {
			continue
		}
		fields := strings.Fields(parts[1])
		if len(fields) < 10 {
			continue
		}
		rx, _ := parseU(fields[0])
		tx, _ := parseU(fields[8])
		if tx+rx > bestTX+bestRX {
			iface = name
			bestTX = tx
			bestRX = rx
		}
	}

	txTotalGB = float64(bestTX) / 1024 / 1024 / 1024
	rxTotalGB = float64(bestRX) / 1024 / 1024 / 1024

	if !prevNetTime.IsZero() && iface != "" {
		dt := now.Sub(prevNetTime).Seconds()
		if dt > 0 {
			txBytesS = float64(bestTX-prevNetTX) / dt
			rxBytesS = float64(bestRX-prevNetRX) / dt
			if txBytesS < 0 {
				txBytesS = 0
			}
			if rxBytesS < 0 {
				rxBytesS = 0
			}
		}
	}
	prevNetTX = bestTX
	prevNetRX = bestRX
	prevNetTime = now
	return
}

// ── helpers ────────────────────────────────────────────────────────────────

func parseU(s string) (uint64, error) {
	return strconv.ParseUint(strings.TrimSpace(s), 10, 64)
}

func parseKV(data string) map[string]uint64 {
	m := make(map[string]uint64)
	scanner := bufio.NewScanner(strings.NewReader(data))
	for scanner.Scan() {
		line := scanner.Text()
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		key := strings.TrimRight(fields[0], ":")
		v, err := strconv.ParseUint(fields[1], 10, 64)
		if err == nil {
			m[key] = v
		}
	}
	return m
}
