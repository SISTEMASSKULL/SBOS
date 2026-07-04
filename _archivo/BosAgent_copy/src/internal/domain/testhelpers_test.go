package domain

import (
	"time"

	"bos/internal/installer"
	"bos/internal/plugin"
	"bos/internal/state"
)

// ── StatePort helpers ─────────────────────────────────────────────

type mockState struct {
	readFn func() (*state.SBOSState, error)
}

func (m *mockState) Read() (*state.SBOSState, error) { return m.readFn() }

func emptyState() *state.SBOSState {
	return &state.SBOSState{Fichas: map[string]*state.Ficha{}}
}

func stateWith(fichas map[string]state.FichaState) *state.SBOSState {
	st := emptyState()
	for id, s := range fichas {
		st.Fichas[id] = &state.Ficha{Name: id, State: s}
	}
	return st
}

func okState() StatePort {
	return &mockState{readFn: func() (*state.SBOSState, error) { return emptyState(), nil }}
}

// ── InstallerPort helpers ─────────────────────────────────────────

type mockInstaller struct {
	installFn func(id, ver string) (*installer.SagaResult, error)
	updateFn  func(id, ver string) (*installer.SagaResult, error)
	repairFn  func(id string) (*installer.SagaResult, error)
	removeFn  func(id string) (*installer.SagaResult, error)
	probeFn   func(id string) (*installer.SagaResult, error)
}

func (m *mockInstaller) Install(id, ver string) (*installer.SagaResult, error) {
	if m.installFn != nil {
		return m.installFn(id, ver)
	}
	return okSaga("install", id), nil
}
func (m *mockInstaller) Update(id, ver string) (*installer.SagaResult, error) {
	if m.updateFn != nil {
		return m.updateFn(id, ver)
	}
	return okSaga("update", id), nil
}
func (m *mockInstaller) Repair(id string) (*installer.SagaResult, error) {
	if m.repairFn != nil {
		return m.repairFn(id)
	}
	return okSaga("repair", id), nil
}
func (m *mockInstaller) Remove(id string) (*installer.SagaResult, error) {
	if m.removeFn != nil {
		return m.removeFn(id)
	}
	return okSaga("remove", id), nil
}
func (m *mockInstaller) Probe(id string) (*installer.SagaResult, error) {
	if m.probeFn != nil {
		return m.probeFn(id)
	}
	return okSaga("probe", id), nil
}

func okIns() InstallerPort { return &mockInstaller{} }

func okSaga(cmd, id string) *installer.SagaResult {
	return &installer.SagaResult{
		Command:  cmd,
		FichaID:  id,
		Success:  true,
		Duration: 42 * time.Millisecond,
		Steps: []installer.Step{
			{Name: "prepare", Status: "ok"},
			{Name: "execute", Status: "ok"},
		},
	}
}

func failedSaga(cmd, id string, exitCode int) *installer.SagaResult {
	return &installer.SagaResult{
		Command:  cmd,
		FichaID:  id,
		Success:  false,
		ExitCode: exitCode,
		Steps: []installer.Step{
			{Name: "execute", Status: "fail"},
		},
	}
}

// ── CatalogPort helpers ───────────────────────────────────────────

type mockCatalog struct {
	manifests []*plugin.FichaManifest
}

func (c *mockCatalog) List() []*plugin.FichaManifest { return c.manifests }
func (c *mockCatalog) Get(id string) (*plugin.FichaManifest, bool) {
	for _, m := range c.manifests {
		if m.ID == id {
			return m, true
		}
	}
	return nil, false
}

func emptyCat() CatalogPort { return &mockCatalog{} }

func catalogWith(ids ...string) CatalogPort {
	manifests := make([]*plugin.FichaManifest, len(ids))
	for i, id := range ids {
		manifests[i] = &plugin.FichaManifest{
			ID:             id,
			ExecutionOrder: 10,
			Dependencies:   []string{},
		}
	}
	return &mockCatalog{manifests: manifests}
}
