// Package system — tests T8.6 (F8): ExecAsRoot y SystemctlCmd.
package system

import "testing"

// TestExecAsRoot: sin comando falla; `true` retorna nil; `false` retorna error.
func TestExecAsRoot(t *testing.T) {
	if err := ExecAsRoot(nil); err == nil {
		t.Error("sin comando debe fallar")
	}
	if err := ExecAsRoot([]string{"true"}); err != nil {
		t.Errorf("`true` debe retornar nil: %v", err)
	}
	if err := ExecAsRoot([]string{"false"}); err == nil {
		t.Error("`false` (exit 1) debe retornar error")
	}
}

// TestSystemctlCmd_UnidadInexistente: el contrato es error con exit != 0 —
// se cumple tanto si systemctl no existe (entorno CI) como si la unidad
// no existe (host con systemd).
func TestSystemctlCmd_UnidadInexistente(t *testing.T) {
	if err := SystemctlCmd("is-active", "unidad-que-no-existe-bos-test.service"); err == nil {
		t.Error("unidad inexistente debe retornar error")
	}
}
