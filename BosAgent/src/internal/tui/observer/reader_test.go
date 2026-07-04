package observer

import (
	"context"
	"testing"
	"time"
)

// TestRead_RetornaTiposCorrectos verifica que Read() retorna un SystemSnap
// con tipos y rangos válidos — sin requerir /proc real (funciona en CI).
func TestRead_RetornaTiposCorrectos(t *testing.T) {
	snap := Read()

	// En entornos sin /proc (macOS/CI) los valores pueden ser cero — eso es OK.
	// Lo que no es OK es un pánico, corrupción o valores negativos.
	if len(snap.Cores) < 0 {
		t.Errorf("Cores.len negativo: %d", len(snap.Cores))
	}
	for i, c := range snap.Cores {
		if c < 0 || c > 100 {
			t.Errorf("Core[%d] fuera de rango: %.2f", i, c)
		}
	}
	if snap.Load1 < 0 {
		t.Errorf("Load1 negativo: %.2f", snap.Load1)
	}
	if snap.Uptime < 0 {
		t.Errorf("Uptime negativo: %v", snap.Uptime)
	}
	if snap.TotalGB < 0 {
		t.Errorf("TotalGB negativo: %.2f", snap.TotalGB)
	}
	if snap.UsedGB < 0 {
		t.Errorf("UsedGB negativo: %.2f", snap.UsedGB)
	}
	if snap.UsedGB > snap.TotalGB && snap.TotalGB > 0 {
		t.Errorf("UsedGB (%.2f) > TotalGB (%.2f)", snap.UsedGB, snap.TotalGB)
	}
}

// TestRead_DosLecturasConsecutivas verifica que dos llamadas seguidas
// producen deltas de CPU coherentes (no negativos, no > 100%).
func TestRead_DosLecturasConsecutivas(t *testing.T) {
	// Primera lectura inicializa prevStats.
	Read()
	// Pequeña pausa para que los contadores avancen.
	time.Sleep(50 * time.Millisecond)
	snap := Read()

	for i, c := range snap.Cores {
		if c < 0 || c > 100 {
			t.Errorf("Core[%d] fuera de rango tras delta: %.2f", i, c)
		}
	}
}

// TestStart_EnviaSnapshots verifica que Start() envía al menos 2 snaps
// en 1 segundo con interval de 200ms.
func TestStart_EnviaSnapshots(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 800*time.Millisecond)
	defer cancel()

	ch := make(chan SystemSnap, 10)
	go Start(ctx, 200*time.Millisecond, ch)

	count := 0
	deadline := time.After(900 * time.Millisecond)
loop:
	for {
		select {
		case <-ch:
			count++
		case <-deadline:
			break loop
		}
	}
	if count < 2 {
		t.Errorf("Start() envió menos de 2 snaps en 900ms: %d", count)
	}
}
