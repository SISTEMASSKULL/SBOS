package domain

import (
	"errors"
	"fmt"
	"testing"
	"time"

	"bos/internal/installer"
	"bos/internal/state"
)

// ── helper local ──────────────────────────────────────────────────

func newSvc(ins InstallerPort, st StatePort, cat CatalogPort) *FichaService {
	return NewFichaService(ins, st, cat)
}

// ── Install ───────────────────────────────────────────────────────

func TestFichaService_Install(t *testing.T) {
	t.Run("ok — resultado correcto", func(t *testing.T) {
		result, err := newSvc(okIns(), okState(), emptyCat()).Install("postgresql", "18.4")
		if err != nil {
			t.Fatalf("error inesperado: %v", err)
		}
		if result.FichaID != "postgresql" {
			t.Errorf("FichaID=%q, quería 'postgresql'", result.FichaID)
		}
		if result.Command != "install" {
			t.Errorf("Command=%q, quería 'install'", result.Command)
		}
		if !result.Success {
			t.Error("Success debería ser true")
		}
		if result.StepCount != 2 {
			t.Errorf("StepCount=%d, quería 2", result.StepCount)
		}
		if result.Duration != 42*time.Millisecond {
			t.Errorf("Duration=%v, quería 42ms", result.Duration)
		}
	})

	t.Run("version vacía defaults a 'latest'", func(t *testing.T) {
		var gotVersion string
		ins := &mockInstaller{
			installFn: func(id, ver string) (*installer.SagaResult, error) {
				gotVersion = ver
				return okSaga("install", id), nil
			},
		}
		if _, err := newSvc(ins, okState(), emptyCat()).Install("redis", ""); err != nil {
			t.Fatal(err)
		}
		if gotVersion != "latest" {
			t.Errorf("version=%q, quería 'latest'", gotVersion)
		}
	})

	t.Run("ficha_id vacío → ErrFichaIDRequired", func(t *testing.T) {
		_, err := newSvc(okIns(), okState(), emptyCat()).Install("", "1.0")
		if !errors.Is(err, ErrFichaIDRequired) {
			t.Errorf("error=%v, quería ErrFichaIDRequired", err)
		}
	})

	t.Run("installer nil → ErrInstallerUnavailable", func(t *testing.T) {
		_, err := newSvc(nil, okState(), emptyCat()).Install("redis", "latest")
		if !errors.Is(err, ErrInstallerUnavailable) {
			t.Errorf("error=%v, quería ErrInstallerUnavailable", err)
		}
	})

	t.Run("saga falla → SagaError con exit code", func(t *testing.T) {
		ins := &mockInstaller{
			installFn: func(id, ver string) (*installer.SagaResult, error) {
				return failedSaga("install", id, 3), nil
			},
		}
		_, err := newSvc(ins, okState(), emptyCat()).Install("vault", "2.0")
		if err == nil {
			t.Fatal("esperaba error, got nil")
		}
		if !IsSagaFailed(err) {
			t.Errorf("error=%v, debería ser SagaFailed", err)
		}
		var sagaErr *SagaError
		if !errors.As(err, &sagaErr) {
			t.Fatal("esperaba *SagaError")
		}
		if sagaErr.ExitCode != 3 {
			t.Errorf("ExitCode=%d, quería 3", sagaErr.ExitCode)
		}
	})

	t.Run("error del installer se envuelve en ErrSagaFailed", func(t *testing.T) {
		ins := &mockInstaller{
			installFn: func(id, ver string) (*installer.SagaResult, error) {
				return nil, fmt.Errorf("script not found")
			},
		}
		_, err := newSvc(ins, okState(), emptyCat()).Install("kong", "3.9")
		if !errors.Is(err, ErrSagaFailed) {
			t.Errorf("error=%v, quería ErrSagaFailed", err)
		}
	})
}

// ── Update ────────────────────────────────────────────────────────

func TestFichaService_Update(t *testing.T) {
	t.Run("ok", func(t *testing.T) {
		result, err := newSvc(okIns(), okState(), emptyCat()).Update("redis", "8.6.2")
		if err != nil {
			t.Fatal(err)
		}
		if result.Command != "update" {
			t.Errorf("Command=%q", result.Command)
		}
	})

	t.Run("ficha_id vacío → ErrFichaIDRequired", func(t *testing.T) {
		_, err := newSvc(okIns(), okState(), emptyCat()).Update("", "1.0")
		if !errors.Is(err, ErrFichaIDRequired) {
			t.Errorf("error=%v", err)
		}
	})

	t.Run("version vacía → ErrVersionRequired", func(t *testing.T) {
		_, err := newSvc(okIns(), okState(), emptyCat()).Update("redis", "")
		if !errors.Is(err, ErrVersionRequired) {
			t.Errorf("error=%v", err)
		}
	})

	t.Run("saga falla → SagaError", func(t *testing.T) {
		ins := &mockInstaller{
			updateFn: func(id, ver string) (*installer.SagaResult, error) {
				return failedSaga("update", id, 1), nil
			},
		}
		_, err := newSvc(ins, okState(), emptyCat()).Update("redis", "8.6.2")
		if !IsSagaFailed(err) {
			t.Errorf("error=%v, debería ser SagaFailed", err)
		}
	})
}

// ── Repair ────────────────────────────────────────────────────────

func TestFichaService_Repair(t *testing.T) {
	t.Run("ok", func(t *testing.T) {
		result, err := newSvc(okIns(), okState(), emptyCat()).Repair("keycloak")
		if err != nil {
			t.Fatal(err)
		}
		if result.Command != "repair" {
			t.Errorf("Command=%q", result.Command)
		}
		if !result.Success {
			t.Error("Success debería ser true")
		}
	})

	t.Run("ficha_id vacío → ErrFichaIDRequired", func(t *testing.T) {
		_, err := newSvc(okIns(), okState(), emptyCat()).Repair("")
		if !errors.Is(err, ErrFichaIDRequired) {
			t.Errorf("error=%v", err)
		}
	})

	t.Run("installer nil → ErrInstallerUnavailable", func(t *testing.T) {
		_, err := newSvc(nil, okState(), emptyCat()).Repair("postgresql")
		if !errors.Is(err, ErrInstallerUnavailable) {
			t.Errorf("error=%v", err)
		}
	})

	t.Run("repair devuelve success=false sin error de dominio", func(t *testing.T) {
		ins := &mockInstaller{
			repairFn: func(id string) (*installer.SagaResult, error) {
				return &installer.SagaResult{FichaID: id, Command: "repair", Success: false, ExitCode: 1}, nil
			},
		}
		result, err := newSvc(ins, okState(), emptyCat()).Repair("postgresql")
		if err != nil {
			t.Fatalf("error inesperado: %v", err)
		}
		if result.Success {
			t.Error("Success debería ser false")
		}
	})
}

// ── Remove ────────────────────────────────────────────────────────

func TestFichaService_Remove(t *testing.T) {
	t.Run("ok", func(t *testing.T) {
		result, err := newSvc(okIns(), okState(), emptyCat()).Remove("minio")
		if err != nil {
			t.Fatal(err)
		}
		if result.Command != "remove" {
			t.Errorf("Command=%q", result.Command)
		}
	})

	t.Run("ficha_id vacío → ErrFichaIDRequired", func(t *testing.T) {
		_, err := newSvc(okIns(), okState(), emptyCat()).Remove("")
		if !errors.Is(err, ErrFichaIDRequired) {
			t.Errorf("error=%v", err)
		}
	})
}

// ── Probe ─────────────────────────────────────────────────────────

func TestFichaService_Probe(t *testing.T) {
	t.Run("ok — FailedSteps no es nil aunque vacío", func(t *testing.T) {
		result, err := newSvc(okIns(), okState(), emptyCat()).Probe("vault")
		if err != nil {
			t.Fatal(err)
		}
		if result.Command != "probe" {
			t.Errorf("Command=%q", result.Command)
		}
		if !result.Success {
			t.Error("Success debería ser true")
		}
		if result.FailedSteps == nil {
			t.Error("FailedSteps no debería ser nil")
		}
	})

	t.Run("ficha_id vacío → ErrFichaIDRequired", func(t *testing.T) {
		_, err := newSvc(okIns(), okState(), emptyCat()).Probe("")
		if !errors.Is(err, ErrFichaIDRequired) {
			t.Errorf("error=%v", err)
		}
	})
}

// ── Status ────────────────────────────────────────────────────────

func TestFichaService_Status(t *testing.T) {
	st := &mockState{
		readFn: func() (*state.SBOSState, error) {
			return stateWith(map[string]state.FichaState{
				"postgresql": state.StateInstalada,
				"redis":      state.StateInstalando,
			}), nil
		},
	}

	t.Run("con ficha_id — retorna FichaInfo individual", func(t *testing.T) {
		single, all, err := newSvc(okIns(), st, emptyCat()).Status("postgresql")
		if err != nil {
			t.Fatal(err)
		}
		if single == nil {
			t.Fatal("single debería ser non-nil")
		}
		if all != nil {
			t.Error("all debería ser nil cuando se pide una ficha específica")
		}
		if single.ID != "postgresql" {
			t.Errorf("ID=%q", single.ID)
		}
		if single.State != string(state.StateInstalada) {
			t.Errorf("State=%q, quería INSTALADA -- OK", single.State)
		}
	})

	t.Run("sin ficha_id — retorna mapa completo", func(t *testing.T) {
		single, all, err := newSvc(okIns(), st, emptyCat()).Status("")
		if err != nil {
			t.Fatal(err)
		}
		if single != nil {
			t.Error("single debería ser nil cuando se pide todas")
		}
		if all == nil {
			t.Fatal("all debería ser non-nil")
		}
		if len(all) != 2 {
			t.Errorf("len(all)=%d, quería 2", len(all))
		}
		if pg := all["postgresql"]; pg == nil || pg.State != string(state.StateInstalada) {
			t.Errorf("postgresql state incorrecto: %v", pg)
		}
		if r := all["redis"]; r == nil || r.State != string(state.StateInstalando) {
			t.Errorf("redis state incorrecto: %v", r)
		}
	})

	t.Run("ficha no encontrada → ErrFichaNotFound", func(t *testing.T) {
		_, _, err := newSvc(okIns(), st, emptyCat()).Status("vault")
		if err == nil {
			t.Fatal("esperaba error")
		}
		if !errors.Is(err, ErrFichaNotFound) {
			t.Errorf("error=%v, quería ErrFichaNotFound", err)
		}
		if err.Error() == "" || !containsStr(err.Error(), "vault") {
			t.Errorf("error debería mencionar 'vault': %v", err)
		}
	})

	t.Run("estado no disponible → ErrStateUnavailable", func(t *testing.T) {
		badState := &mockState{
			readFn: func() (*state.SBOSState, error) {
				return nil, fmt.Errorf("disco lleno")
			},
		}
		_, _, err := newSvc(okIns(), badState, emptyCat()).Status("postgresql")
		if !errors.Is(err, ErrStateUnavailable) {
			t.Errorf("error=%v, quería ErrStateUnavailable", err)
		}
	})
}

// ── List ──────────────────────────────────────────────────────────

func TestFichaService_List(t *testing.T) {
	t.Run("catálogo vacío → slice no nil, longitud 0", func(t *testing.T) {
		result := newSvc(okIns(), okState(), emptyCat()).List()
		if result == nil {
			t.Error("resultado no debe ser nil")
		}
		if len(result) != 0 {
			t.Errorf("len=%d, quería 0", len(result))
		}
	})

	t.Run("devuelve todas las fichas del catálogo", func(t *testing.T) {
		cat := catalogWith("sbos-bootstrap-os", "postgresql", "redis", "vault")
		result := newSvc(okIns(), okState(), cat).List()
		if len(result) != 4 {
			t.Fatalf("len=%d, quería 4", len(result))
		}
		got := map[string]bool{}
		for _, f := range result {
			got[f.ID] = true
		}
		for _, want := range []string{"sbos-bootstrap-os", "postgresql", "redis", "vault"} {
			if !got[want] {
				t.Errorf("ficha %q no encontrada en resultado", want)
			}
		}
	})

	t.Run("execution_order y dependencies se preservan", func(t *testing.T) {
		cat := catalogWith("postgresql")
		result := newSvc(okIns(), okState(), cat).List()
		if len(result) != 1 {
			t.Fatal("esperaba 1 ficha")
		}
		if result[0].ExecutionOrder != 10 {
			t.Errorf("ExecutionOrder=%d, quería 10", result[0].ExecutionOrder)
		}
		if result[0].Dependencies == nil {
			t.Error("Dependencies no debe ser nil")
		}
	})
}

// ── ExecuteSaga ───────────────────────────────────────────────────

func TestFichaService_ExecuteSaga(t *testing.T) {
	calls := map[string]bool{}
	ins := &mockInstaller{
		installFn: func(id, ver string) (*installer.SagaResult, error) {
			calls["install"] = true
			return okSaga("install", id), nil
		},
		updateFn: func(id, ver string) (*installer.SagaResult, error) {
			calls["update"] = true
			return okSaga("update", id), nil
		},
		repairFn: func(id string) (*installer.SagaResult, error) {
			calls["repair"] = true
			return okSaga("repair", id), nil
		},
		removeFn: func(id string) (*installer.SagaResult, error) {
			calls["remove"] = true
			return okSaga("remove", id), nil
		},
		probeFn: func(id string) (*installer.SagaResult, error) { calls["probe"] = true; return okSaga("probe", id), nil },
	}
	service := newSvc(ins, okState(), emptyCat())

	for _, cmd := range []string{"install", "update", "repair", "remove", "probe"} {
		cmd := cmd
		t.Run("despacha "+cmd, func(t *testing.T) {
			result, err := service.ExecuteSaga("redis", cmd, "8.6.2")
			if err != nil {
				t.Fatalf("error inesperado: %v", err)
			}
			if result.Command != cmd {
				t.Errorf("Command=%q, quería %q", result.Command, cmd)
			}
			if !calls[cmd] {
				t.Errorf("mockInstaller.%sFn no fue llamado", cmd)
			}
		})
	}

	t.Run("command inválido → ErrCommandInvalid", func(t *testing.T) {
		_, err := service.ExecuteSaga("redis", "destroy", "")
		if err == nil {
			t.Fatal("esperaba error")
		}
		if !errors.Is(err, ErrCommandInvalid) {
			t.Errorf("error=%v, quería ErrCommandInvalid", err)
		}
	})

	t.Run("ficha_id vacío → ErrFichaIDRequired", func(t *testing.T) {
		_, err := service.ExecuteSaga("", "install", "")
		if !errors.Is(err, ErrFichaIDRequired) {
			t.Errorf("error=%v", err)
		}
	})

	t.Run("command vacío → ErrCommandRequired", func(t *testing.T) {
		_, err := service.ExecuteSaga("redis", "", "")
		if !errors.Is(err, ErrCommandRequired) {
			t.Errorf("error=%v", err)
		}
	})
}

// ── helper ───────────────────────────────────────────────────────

func containsStr(s, sub string) bool {
	return len(s) >= len(sub) && (s == sub || len(s) > 0 && containsSubstr(s, sub))
}

func containsSubstr(s, sub string) bool {
	for i := 0; i <= len(s)-len(sub); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}
