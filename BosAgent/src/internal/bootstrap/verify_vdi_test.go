// Package bootstrap — tests F9.9: criterios VDI C-09..C-14.
package bootstrap

import (
	"testing"
)

// TestVerifyVDI_SeisCriterios: VerifyVDI retorna exactamente C-09..C-14.
func TestVerifyVDI_SeisCriterios(t *testing.T) {
	res := VerifyVDI()
	if len(res) != 6 {
		t.Fatalf("VDI: want 6 criterios, got %d", len(res))
	}
	esperados := []string{"C-09", "C-10", "C-11", "C-12", "C-13", "C-14"}
	for i, c := range res {
		if c.ID != esperados[i] {
			t.Errorf("posición %d: want %s, got %s", i, esperados[i], c.ID)
		}
		if c.Detail == "" {
			t.Errorf("%s: detalle vacío", c.ID)
		}
	}
}

// TestVerifyC09C10_ConProbeStub: con un probe que simula servicios sanos,
// nextcloud y guacamole pasan; con error, fallan con detalle.
func TestVerifyC09C10_ConProbeStub(t *testing.T) {
	original := VDIProbe
	defer func() { VDIProbe = original }()

	// servicios sanos
	VDIProbe = func(url string) ProbeResult {
		if contiene(url, "status.php") {
			return ProbeResult{OK: true, Status: 200, Body: `{"installed":true,"version":"30"}`}
		}
		return ProbeResult{OK: true, Status: 200, Body: `["en","es"]`}
	}
	if ok, d := VerifyC09(); !ok {
		t.Errorf("C-09 con nextcloud sano debe pasar: %s", d)
	}
	if ok, d := VerifyC10(); !ok {
		t.Errorf("C-10 con guacamole sano debe pasar: %s", d)
	}

	// nextcloud instalado a medias (sin installed:true)
	VDIProbe = func(url string) ProbeResult {
		return ProbeResult{OK: true, Status: 200, Body: `{"installed":false}`}
	}
	if ok, _ := VerifyC09(); ok {
		t.Error("C-09 sin installed:true debe fallar")
	}

	// servicio caído
	VDIProbe = func(url string) ProbeResult {
		return ProbeResult{Err: errProbe}
	}
	if ok, _ := VerifyC09(); ok {
		t.Error("C-09 con nextcloud caído debe fallar")
	}
	if ok, _ := VerifyC10(); ok {
		t.Error("C-10 con guacamole caído debe fallar")
	}
}

// TestVerifyFull_CatorceCriterios: VerifyFull encadena C-01..C-14.
func TestVerifyFull_CatorceCriterios(t *testing.T) {
	res := VerifyFull()
	if len(res) != 14 {
		t.Fatalf("full: want 14 criterios, got %d", len(res))
	}
	if res[0].ID != "C-01" || res[13].ID != "C-14" {
		t.Errorf("orden: primero %s, último %s", res[0].ID, res[13].ID)
	}
}

var errProbe = &probeErr{}

type probeErr struct{}

func (*probeErr) Error() string { return "connection refused" }
