package domain

import (
	"errors"
	"testing"
)

func TestSentinelErrors_AreDistinct(t *testing.T) {
	sentinels := []error{
		ErrFichaIDRequired,
		ErrVersionRequired,
		ErrCommandRequired,
		ErrFichaNotFound,
		ErrInstallerUnavailable,
		ErrStateUnavailable,
		ErrBootstrapInProgress,
		ErrCommandInvalid,
		ErrSagaFailed,
		ErrTraceparentRequired,
		ErrTenantIDRequired,
	}

	for i, a := range sentinels {
		for j, b := range sentinels {
			if i != j && errors.Is(a, b) {
				t.Errorf("errores[%d]=%v y errores[%d]=%v no deben ser iguales", i, a, j, b)
			}
		}
	}
}

func TestIsFichaNotFound(t *testing.T) {
	if !IsFichaNotFound(ErrFichaNotFound) {
		t.Error("IsFichaNotFound(ErrFichaNotFound) debe ser true")
	}
	if IsFichaNotFound(ErrSagaFailed) {
		t.Error("IsFichaNotFound(ErrSagaFailed) debe ser false")
	}
	if IsFichaNotFound(nil) {
		t.Error("IsFichaNotFound(nil) debe ser false")
	}
}

func TestIsSagaFailed(t *testing.T) {
	if !IsSagaFailed(ErrSagaFailed) {
		t.Error("IsSagaFailed(ErrSagaFailed) debe ser true")
	}
	if IsSagaFailed(ErrFichaNotFound) {
		t.Error("IsSagaFailed(ErrFichaNotFound) debe ser false")
	}
}

func TestIsBootstrapInProgress(t *testing.T) {
	if !IsBootstrapInProgress(ErrBootstrapInProgress) {
		t.Error("IsBootstrapInProgress(ErrBootstrapInProgress) debe ser true")
	}
	if IsBootstrapInProgress(ErrSagaFailed) {
		t.Error("IsBootstrapInProgress(ErrSagaFailed) debe ser false")
	}
}

func TestSagaError_Error(t *testing.T) {
	se := &SagaError{Command: "install", ExitCode: 3}
	msg := se.Error()
	if msg == "" {
		t.Error("SagaError.Error() no debe ser vacío")
	}
	// El mensaje debe mencionar el command
	found := false
	for i := 0; i <= len(msg)-len("install"); i++ {
		if msg[i:i+len("install")] == "install" {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("SagaError.Error() = %q, debería contener 'install'", msg)
	}
}

func TestSagaError_UnwrapsToErrSagaFailed(t *testing.T) {
	se := &SagaError{Command: "install", ExitCode: 3}
	if !errors.Is(se, ErrSagaFailed) {
		t.Error("SagaError debe envolver ErrSagaFailed")
	}
	if !IsSagaFailed(se) {
		t.Error("IsSagaFailed debe reconocer SagaError")
	}
}

func TestSagaError_ErrorsAs(t *testing.T) {
	se := &SagaError{Command: "update", ExitCode: 1, FailedSteps: []string{"step1"}}
	var target *SagaError
	if !errors.As(se, &target) {
		t.Fatal("errors.As debe extraer *SagaError")
	}
	if target.ExitCode != 1 {
		t.Errorf("ExitCode=%d, quería 1", target.ExitCode)
	}
	if target.Command != "update" {
		t.Errorf("Command=%q, quería 'update'", target.Command)
	}
}
