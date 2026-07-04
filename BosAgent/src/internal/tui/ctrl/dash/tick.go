package dash

import (
	"time"

	"bos/internal/tui/observer"
)

// DashTickMsg transporta una captura real del sistema al modelo del dashboard.
// Se emite periódicamente desde el bucle BubbleTea cuando el dashboard está activo.
type DashTickMsg struct {
	Snap observer.SystemSnap
	Time time.Time
}

// ApplyTick actualiza el DashModel con datos reales de una observación del sistema.
// Reemplaza los campos que se conocen desde el SO; el resto conserva su valor
// (datos K8s, logs, fichas — alimentados por otros observadores en M2-M4).
func (dm DashModel) ApplyTick(tick DashTickMsg) DashModel {
	dm.Now = tick.Time

	// ── CPU ────────────────────────────────────────────────────────────────
	if len(tick.Snap.Cores) > 0 {
		dm.CPU.Cores = tick.Snap.Cores
	}
	dm.CPU.Load1 = tick.Snap.Load1
	dm.CPU.Load5 = tick.Snap.Load5
	dm.CPU.Load15 = tick.Snap.Load15
	if tick.Snap.Procs > 0 {
		dm.CPU.Procs = tick.Snap.Procs
	}
	if tick.Snap.Uptime > 0 {
		dm.CPU.Uptime = tick.Snap.Uptime
	}

	// ── Memoria ────────────────────────────────────────────────────────────
	if tick.Snap.TotalGB > 0 {
		dm.Mem.TotalGB = tick.Snap.TotalGB
		dm.Mem.UsedGB = tick.Snap.UsedGB
		dm.Mem.FreeGB = tick.Snap.FreeGB
		dm.Mem.BuffGB = tick.Snap.BuffGB
		dm.Mem.SwapTotal = tick.Snap.SwapTotal
		dm.Mem.SwapUsed = tick.Snap.SwapUsed
	}

	// ── Red ─────────────────────────────────────────────────────────────────
	if tick.Snap.Iface != "" {
		dm.Net.Iface = tick.Snap.Iface
		dm.Net.TXBytesS = tick.Snap.TXBytesS
		dm.Net.RXBytesS = tick.Snap.RXBytesS
		dm.Net.TXTotalGB = tick.Snap.TXTotalGB
		dm.Net.RXTotalGB = tick.Snap.RXTotalGB
	}

	// ── Sparklines (30 puntos) ─────────────────────────────────────────────
	avgCPU := 0.0
	if len(tick.Snap.Cores) > 0 {
		for _, c := range tick.Snap.Cores {
			avgCPU += c
		}
		avgCPU /= float64(len(tick.Snap.Cores))
	}

	ramPct := 0.0
	if tick.Snap.TotalGB > 0 {
		ramPct = tick.Snap.UsedGB / tick.Snap.TotalGB * 100
	}

	netMBs := (tick.Snap.TXBytesS + tick.Snap.RXBytesS) / 1024 / 1024

	dm.MonCPU = shiftAppend(dm.MonCPU, avgCPU, 30)
	dm.MonRAM = shiftAppend(dm.MonRAM, ramPct, 30)
	dm.MonNet = shiftAppend(dm.MonNet, netMBs, 30)

	return dm
}

// shiftAppend desplaza el slice a la izquierda, añade v al final y lo limita a maxLen.
func shiftAppend(s []float64, v float64, maxLen int) []float64 {
	if len(s) >= maxLen {
		s = s[1:]
	}
	return append(s, v)
}
