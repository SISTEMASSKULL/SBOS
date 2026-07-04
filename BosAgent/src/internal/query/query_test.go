// Package query — tests del motor de sagas de consulta (F6.6–F6.11).
// TestQuerySystem_AllSourcesParallel valida el paralelismo del motor
// (BOS-REPAIR-04 §F6.15).
package query

import (
	"context"
	"errors"
	"testing"
	"time"
)

// TestQuerySystem_AllSourcesParallel: 4 fuentes de ~200ms deben agregarse
// en ~200ms (paralelo), no ~800ms (serie). El umbral de 600ms tolera el
// ruido de scheduler observado bajo -race -count=10 multi-paquete (~330ms)
// sin dejar de distinguir paralelo de serie.
func TestQuerySystem_AllSourcesParallel(t *testing.T) {
	lenta := func(ctx context.Context) (interface{}, error) {
		time.Sleep(200 * time.Millisecond)
		return map[string]interface{}{"healthy": true}, nil
	}
	sources := map[string]Source{
		"ubuntu": lenta, "kubernetes": lenta, "fichas": lenta, "context_plane": lenta,
	}

	start := time.Now()
	out := Run(context.Background(), sources)
	elapsed := time.Since(start)

	if elapsed > 600*time.Millisecond {
		t.Errorf("4 fuentes de 200ms deben correr en paralelo (~200ms), no en serie (800ms): tardó %v", elapsed)
	}
	for _, key := range []string{"ubuntu", "kubernetes", "fichas", "context_plane"} {
		if _, ok := out[key]; !ok {
			t.Errorf("falta la clave %s", key)
		}
	}
	if _, ok := out["duration_ms"]; !ok {
		t.Error("falta duration_ms")
	}
	if _, ok := out["timestamp"]; !ok {
		t.Error("falta timestamp")
	}
}

// TestRun_FuenteConErrorNoAbortaLaSaga: una fuente que falla aporta
// {"error": …} y las demás retornan datos (degradación elegante).
func TestRun_FuenteConErrorNoAbortaLaSaga(t *testing.T) {
	sources := map[string]Source{
		"ok": func(ctx context.Context) (interface{}, error) {
			return map[string]interface{}{"healthy": true}, nil
		},
		"rota": func(ctx context.Context) (interface{}, error) {
			return nil, errors.New("kubectl no disponible")
		},
	}
	out := Run(context.Background(), sources)

	rota, ok := out["rota"].(map[string]string)
	if !ok || rota["error"] == "" {
		t.Errorf(`fuente rota debe aportar {"error": …}, got %+v`, out["rota"])
	}
	if okData, ok := out["ok"].(map[string]interface{}); !ok || okData["healthy"] != true {
		t.Errorf("fuente sana debe aportar datos: %+v", out["ok"])
	}
}

// TestRun_DeadlineCortaFuentesColgadas: una fuente que nunca responde no
// retrasa la saga más allá del deadline; su clave reporta el error.
func TestRun_DeadlineCortaFuentesColgadas(t *testing.T) {
	parent, cancel := context.WithTimeout(context.Background(), 150*time.Millisecond)
	defer cancel()

	sources := map[string]Source{
		"colgada": func(ctx context.Context) (interface{}, error) {
			select {
			case <-time.After(10 * time.Second):
				return "nunca", nil
			case <-ctx.Done():
				return nil, ctx.Err()
			}
		},
		"rapida": func(ctx context.Context) (interface{}, error) {
			return "ok", nil
		},
	}

	start := time.Now()
	out := Run(parent, sources)
	elapsed := time.Since(start)

	if elapsed > time.Second {
		t.Errorf("la saga debe cortar al deadline del parent (~150ms), tardó %v", elapsed)
	}
	if m, ok := out["colgada"].(map[string]string); !ok || m["error"] == "" {
		t.Errorf("fuente colgada debe reportar error: %+v", out["colgada"])
	}
	if out["rapida"] != "ok" {
		t.Errorf("fuente rápida debe haber respondido: %+v", out["rapida"])
	}
}

// TestCalcSemaforo cubre las reglas VERDE/AMARILLO/ROJO.
func TestCalcSemaforo(t *testing.T) {
	verde := map[string]interface{}{
		"ubuntu": map[string]interface{}{"healthy": true},
		"fichas": map[string]interface{}{"degradada": 0},
	}
	if s := CalcSemaforo(verde, []string{"ubuntu"}); s != SemVerde {
		t.Errorf("want VERDE, got %s", s)
	}

	amarillo := map[string]interface{}{
		"ubuntu":     map[string]interface{}{"healthy": true},
		"kubernetes": map[string]string{"error": "sin cluster"},
	}
	if s := CalcSemaforo(amarillo, []string{"ubuntu"}); s != SemAmarillo {
		t.Errorf("want AMARILLO, got %s", s)
	}

	rojo := map[string]interface{}{
		"ubuntu": map[string]interface{}{"healthy": false},
	}
	if s := CalcSemaforo(rojo, []string{"ubuntu"}); s != SemRojo {
		t.Errorf("want ROJO, got %s", s)
	}

	// regresión de staging real: un CONTADOR llamado "error" (numérico) no
	// es una fuente caída — solo {"error": "<mensaje>"} (string) lo es
	contadorCero := map[string]interface{}{
		"fichas": map[string]interface{}{"healthy": true, "en_error": 0, "error": 0},
	}
	if s := CalcSemaforo(contadorCero, []string{"fichas"}); s != SemVerde {
		t.Errorf("contador numérico 'error' no debe teñir el semáforo: got %s", s)
	}
	fuenteCaida := map[string]interface{}{
		"fichas": map[string]interface{}{"error": "state manager no disponible"},
	}
	if s := CalcSemaforo(fuenteCaida, []string{"fichas"}); s != SemRojo {
		t.Errorf("error string en crítica debe dar ROJO: got %s", s)
	}
}

// TestUbuntuSnapshot_CamposDelContrato: la fuente real responde con los
// campos del contrato BOS-REPAIR-04 en cualquier host Linux.
func TestUbuntuSnapshot_CamposDelContrato(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	raw, err := UbuntuSnapshot(ctx)
	if err != nil {
		t.Fatalf("UbuntuSnapshot en host Linux no debe fallar: %v", err)
	}
	snap := raw.(map[string]interface{})
	for _, campo := range []string{"healthy", "cpu_pct", "mem_pct", "disk_pct", "services", "uptime_hours"} {
		if _, ok := snap[campo]; !ok {
			t.Errorf("falta el campo %s del contrato", campo)
		}
	}
	if pct := snap["mem_pct"].(int); pct < 0 || pct > 100 {
		t.Errorf("mem_pct fuera de rango: %d", pct)
	}
	if pct := snap["disk_pct"].(int); pct < 0 || pct > 100 {
		t.Errorf("disk_pct fuera de rango: %d", pct)
	}
}
