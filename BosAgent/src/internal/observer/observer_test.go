// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

package observer

import (
	"testing"

	"bos/internal/plugin"
	"bos/internal/state"
)

// ── helpers de construcción ──────────────────────────────────────────

func fichaConEstado(s state.FichaState) *state.Ficha {
	return &state.Ficha{State: s}
}

func nuevaManifest(id string, order int, deps []string, autoInstall bool) *plugin.FichaManifest {
	return &plugin.FichaManifest{
		ID:             id,
		ExecutionOrder: order,
		Dependencies:   deps,
		AutoInstall:    autoInstall,
		Version:        "1.0.0",
	}
}

// ── DepsSatisfied ────────────────────────────────────────────────────

// TestDepsSatisfied_SinDependencias verifica que una ficha sin deps siempre está lista.
func TestDepsSatisfied_SinDependencias(t *testing.T) {
	t.Parallel()
	st := &state.SBOSState{Fichas: map[string]*state.Ficha{}}
	if !DepsSatisfied(nil, st) {
		t.Error("sin dependencias, DepsSatisfied debe retornar true")
	}
	if !DepsSatisfied([]string{}, st) {
		t.Error("lista vacía de dependencias, DepsSatisfied debe retornar true")
	}
}

// TestDepsSatisfied_TodosInstalados verifica que retorna true cuando todas las deps
// están en INSTALADA.
func TestDepsSatisfied_TodosInstalados(t *testing.T) {
	t.Parallel()
	st := &state.SBOSState{
		Fichas: map[string]*state.Ficha{
			"postgresql": fichaConEstado(state.StateInstalada),
			"redis":      fichaConEstado(state.StateInstalada),
		},
	}
	if !DepsSatisfied([]string{"postgresql", "redis"}, st) {
		t.Error("todas las deps en INSTALADA — DepsSatisfied debe retornar true")
	}
}

// TestDepsSatisfied_FaltaUno verifica que retorna false si al menos una dep
// no está en INSTALADA.
func TestDepsSatisfied_FaltaUno(t *testing.T) {
	t.Parallel()
	st := &state.SBOSState{
		Fichas: map[string]*state.Ficha{
			"postgresql": fichaConEstado(state.StateInstalada),
			"redis":      fichaConEstado(state.StatePendiente), // ← no satisfecha
		},
	}
	if DepsSatisfied([]string{"postgresql", "redis"}, st) {
		t.Error("redis en PENDIENTE — DepsSatisfied debe retornar false")
	}
}

// TestDepsSatisfied_DepNoRegistrada verifica que retorna false si una dep
// no está registrada en el estado.
func TestDepsSatisfied_DepNoRegistrada(t *testing.T) {
	t.Parallel()
	st := &state.SBOSState{
		Fichas: map[string]*state.Ficha{},
	}
	if DepsSatisfied([]string{"postgresql"}, st) {
		t.Error("dep no registrada — DepsSatisfied debe retornar false")
	}
}

// ── FindNextAutoInstall ───────────────────────────────────────────────

// TestFindNextAutoInstall_RetornaNilSinCandidatos verifica que retorna nil
// cuando no hay fichas en estado LISTA.
func TestFindNextAutoInstall_RetornaNilSinCandidatos(t *testing.T) {
	t.Parallel()
	st := &state.SBOSState{
		Fichas: map[string]*state.Ficha{
			"postgresql": fichaConEstado(state.StatePendiente),
		},
	}
	index := map[string]*plugin.FichaManifest{
		"postgresql": nuevaManifest("postgresql", 100, nil, true),
	}
	if FindNextAutoInstall(st, index) != nil {
		t.Error("sin fichas LISTA — debe retornar nil")
	}
}

// TestFindNextAutoInstall_EligePrimerPorOrden verifica que entre varias candidatas
// se elige la de menor ExecutionOrder.
func TestFindNextAutoInstall_EligePrimerPorOrden(t *testing.T) {
	t.Parallel()
	st := &state.SBOSState{
		Fichas: map[string]*state.Ficha{
			"keycloak":   fichaConEstado(state.StateLista),
			"postgresql": fichaConEstado(state.StateLista),
			"redis":      fichaConEstado(state.StateLista),
		},
	}
	index := map[string]*plugin.FichaManifest{
		"postgresql": nuevaManifest("postgresql", 100, nil, true),
		"redis":      nuevaManifest("redis", 110, nil, true),
		"keycloak":   nuevaManifest("keycloak", 140, nil, true),
	}
	next := FindNextAutoInstall(st, index)
	if next == nil {
		t.Fatal("debe haber al menos una candidata")
	}
	if next.ID != "postgresql" {
		t.Errorf("se esperaba postgresql (orden 100), se obtuvo %s (orden %d)", next.ID, next.ExecutionOrder)
	}
}

// TestFindNextAutoInstall_IgnoraNoAutoInstall verifica que fichas sin auto_install
// no se incluyen como candidatas aunque estén en LISTA.
func TestFindNextAutoInstall_IgnoraNoAutoInstall(t *testing.T) {
	t.Parallel()
	st := &state.SBOSState{
		Fichas: map[string]*state.Ficha{
			"ficha-opcional": fichaConEstado(state.StateLista),
		},
	}
	index := map[string]*plugin.FichaManifest{
		"ficha-opcional": nuevaManifest("ficha-opcional", 50, nil, false),
	}
	if FindNextAutoInstall(st, index) != nil {
		t.Error("ficha sin auto_install no debe ser candidata")
	}
}

// TestFindNextAutoInstall_IgnoraDepNoSatisfecha verifica que fichas LISTA con
// dependencias no satisfechas no se seleccionan.
func TestFindNextAutoInstall_IgnoraDepNoSatisfecha(t *testing.T) {
	t.Parallel()
	st := &state.SBOSState{
		Fichas: map[string]*state.Ficha{
			"keycloak":   fichaConEstado(state.StateLista),
			"postgresql": fichaConEstado(state.StatePendiente), // dep de keycloak, no satisfecha
		},
	}
	index := map[string]*plugin.FichaManifest{
		"keycloak":   nuevaManifest("keycloak", 140, []string{"postgresql"}, true),
		"postgresql": nuevaManifest("postgresql", 100, nil, true),
	}
	if FindNextAutoInstall(st, index) != nil {
		t.Error("keycloak tiene dep no satisfecha — no debe ser candidata")
	}
}

// ── TopologicalSort ──────────────────────────────────────────────────

// TestTopologicalSort_SinDependencias verifica que con fichas sin deps el orden
// resultante es por ExecutionOrder.
func TestTopologicalSort_SinDependencias(t *testing.T) {
	t.Parallel()
	fichas := []*plugin.FichaManifest{
		nuevaManifest("redis", 110, nil, true),
		nuevaManifest("postgresql", 100, nil, true),
		nuevaManifest("keycloak", 140, nil, true),
	}
	sorted := TopologicalSort(fichas)
	if len(sorted) != 3 {
		t.Fatalf("se esperaban 3 fichas, se obtuvieron %d", len(sorted))
	}
	if sorted[0].ID != "postgresql" {
		t.Errorf("primera debe ser postgresql (orden 100), se obtuvo %s", sorted[0].ID)
	}
	if sorted[1].ID != "redis" {
		t.Errorf("segunda debe ser redis (orden 110), se obtuvo %s", sorted[1].ID)
	}
	if sorted[2].ID != "keycloak" {
		t.Errorf("tercera debe ser keycloak (orden 140), se obtuvo %s", sorted[2].ID)
	}
}

// TestTopologicalSort_RespetaDependencias verifica que una ficha con dep aparece
// después de su dependencia en el resultado.
func TestTopologicalSort_RespetaDependencias(t *testing.T) {
	t.Parallel()
	fichas := []*plugin.FichaManifest{
		nuevaManifest("keycloak", 140, []string{"postgresql"}, true),
		nuevaManifest("postgresql", 100, nil, true),
	}
	sorted := TopologicalSort(fichas)
	if len(sorted) != 2 {
		t.Fatalf("se esperaban 2 fichas, se obtuvieron %d", len(sorted))
	}

	posPostgres, posKeycloak := -1, -1
	for i, f := range sorted {
		switch f.ID {
		case "postgresql":
			posPostgres = i
		case "keycloak":
			posKeycloak = i
		}
	}
	if posPostgres >= posKeycloak {
		t.Errorf("postgresql (pos %d) debe aparecer antes que keycloak (pos %d)", posPostgres, posKeycloak)
	}
}

// TestTopologicalSort_ListaVacia verifica que con una slice vacía retorna
// slice no nil y de longitud 0.
func TestTopologicalSort_ListaVacia(t *testing.T) {
	t.Parallel()
	sorted := TopologicalSort([]*plugin.FichaManifest{})
	if sorted == nil {
		t.Error("TopologicalSort no debe retornar nil — debe retornar slice vacía")
	}
	if len(sorted) != 0 {
		t.Errorf("se esperaba slice vacía, se obtuvieron %d elementos", len(sorted))
	}
}
