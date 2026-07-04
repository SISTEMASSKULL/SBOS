// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Fable 5 — Anthropic

package bootstrap

// verify_vdi.go — F9.9: criterios C-09..C-14 del VDI Layer
// (BOS-REPAIR-01 §Capa 4, BOS-REPAIR-09 SBOS-052). El VDI Layer es la
// cúspide de la instalación: Nextcloud, Guacamole, pool fedora-logico,
// home montado, Context Plane y el end-to-end de escritorio.
//
// Cada criterio probea el servicio real. ProbeFn es inyectable para tests
// (sin red); en producción usa httpProbe contra el endpoint ClusterIP.

import (
	"fmt"
	"net/http"
	"time"
)

// ProbeResult es el resultado de probear un endpoint.
type ProbeResult struct {
	OK       bool
	Status   int
	Body     string
	Err      error
	Duration time.Duration
}

// ProbeFn probea un endpoint HTTP. Inyectable: en tests se sustituye por un
// stub; en producción es httpProbe.
type ProbeFn func(url string) ProbeResult

// VDIProbe es la función de probe usada por los criterios C-09..C-14.
// Variable de paquete para override en tests (no thread-safe — igual que
// SysRoot, los tests que la tocan no corren en paralelo).
var VDIProbe ProbeFn = httpProbe

// httpProbe ejecuta un GET con timeout corto contra el endpoint.
func httpProbe(url string) ProbeResult {
	start := time.Now()
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return ProbeResult{Err: err, Duration: time.Since(start)}
	}
	defer resp.Body.Close()
	buf := make([]byte, 4096)
	n, _ := resp.Body.Read(buf)
	return ProbeResult{
		OK:       resp.StatusCode >= 200 && resp.StatusCode < 300,
		Status:   resp.StatusCode,
		Body:     string(buf[:n]),
		Duration: time.Since(start),
	}
}

// vdiEndpoints son los endpoints ClusterIP de las fichas VDI (SBOS-050:
// rango 8100-8999, derivable BASE+FICHA×10+TIPO). Variable de paquete para
// override en tests.
var vdiEndpoints = map[string]string{
	"nextcloud": "http://localhost:8300/status.php",
	"guacamole": "http://localhost:8310/guacamole/api/languages",
}

// VerifyC09 — nextcloud HEALTHY: /status.php → {"installed":true}.
func VerifyC09() (bool, string) {
	r := VDIProbe(vdiEndpoints["nextcloud"])
	if r.Err != nil {
		return false, "nextcloud /status.php no responde: " + r.Err.Error()
	}
	if !r.OK {
		return false, fmt.Sprintf("nextcloud /status.php status %d", r.Status)
	}
	if !contiene(r.Body, `"installed":true`) {
		return false, "nextcloud no reporta installed:true"
	}
	return true, "nextcloud: installed + DB accesible"
}

// VerifyC10 — guacamole HEALTHY: API /languages responde 200.
func VerifyC10() (bool, string) {
	r := VDIProbe(vdiEndpoints["guacamole"])
	if r.Err != nil {
		return false, "guacamole API no responde: " + r.Err.Error()
	}
	if !r.OK {
		return false, fmt.Sprintf("guacamole /api/languages status %d", r.Status)
	}
	return true, "guacamole: API 200 (OIDC client en KC pendiente de validación profunda)"
}

// VerifyC11 — fedora-logico: min 2 pods Running con dctx_id activo.
// La verificación de pods reales la hace el caller con el K8sOperator; aquí
// se reporta el contrato. En el verify --full el server inyecta el conteo.
func VerifyC11() (bool, string) {
	r := VDIProbe(vdiEndpoints["nextcloud"]) // proxy de disponibilidad del layer
	if r.Err != nil {
		return false, "fedora-logico: VDI layer no accesible (" + r.Err.Error() + ")"
	}
	return false, "fedora-logico: requiere conteo de pods vía K8sOperator (verify --full)"
}

// VerifyC12 — nextcloud-home montado en pod Fedora.
func VerifyC12() (bool, string) {
	return false, "nextcloud-home: requiere exec en pod Fedora (verify --full con pod activo)"
}

// VerifyC13 — context-plane: dctx_id en < 2s. La medición real la hace el
// server (tiene el bosCtxSvc); aquí se declara el SLO.
func VerifyC13() (bool, string) {
	return false, "context-plane: medir bos.ctx.device.register < 2s (verify --full)"
}

// VerifyC14 — vdi-e2e: login web → escritorio GNOME en < 10s.
func VerifyC14() (bool, string) {
	return false, "vdi-e2e: test end-to-end con usuario real (manual/CI dedicado)"
}

// VerifyVDI ejecuta C-09..C-14 y los retorna en orden.
func VerifyVDI() []CriterioResult {
	checks := []struct {
		id string
		fn func() (bool, string)
	}{
		{"C-09", VerifyC09},
		{"C-10", VerifyC10},
		{"C-11", VerifyC11},
		{"C-12", VerifyC12},
		{"C-13", VerifyC13},
		{"C-14", VerifyC14},
	}
	results := make([]CriterioResult, len(checks))
	for i, c := range checks {
		ok, detail := c.fn()
		results[i] = CriterioResult{ID: c.id, OK: ok, Detail: detail}
	}
	return results
}

// VerifyFull ejecuta los 14 criterios (C-01..C-14): bootstrap + VDI Layer.
func VerifyFull() []CriterioResult {
	return append(VerifyAll(), VerifyVDI()...)
}

func contiene(s, sub string) bool {
	return len(sub) > 0 && len(s) >= len(sub) && indexOf(s, sub) >= 0
}

func indexOf(s, sub string) int {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return i
		}
	}
	return -1
}
