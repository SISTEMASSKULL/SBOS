// Package domain — tests T8.6 (F8): PgAuxiliarService (Parte V-B).
// El puerto K8s se sustituye por un stub — sin cluster real.
package domain

import (
	"errors"
	"strings"
	"testing"
	"time"
)

// pgAuxK8sStub implementa PgAuxK8sPort fallando en CreatePodFromManifest —
// cubre la ruta de error temprano de Start (failResult + limpieza).
type pgAuxK8sStub struct{ createErr error }

func (s pgAuxK8sStub) CreatePodFromManifest(string, string) error { return s.createErr }
func (s pgAuxK8sStub) DeletePod(string, string) error             { return nil }
func (s pgAuxK8sStub) WaitForPodReady(string, string, time.Duration) error {
	return errors.New("no usado")
}
func (s pgAuxK8sStub) ExecInPod(string, string, string, string) (string, error) {
	return "", errors.New("no usado")
}

// TestPgAuxiliar_ConstructorYStatus: arranca en fase idle y Status retorna
// una copia (mutarla no afecta el interno).
func TestPgAuxiliar_ConstructorYStatus(t *testing.T) {
	svc := NewPgAuxiliarService(pgAuxK8sStub{})

	st := svc.Status()
	if st.Phase != "idle" {
		t.Errorf("fase inicial: want idle, got %s", st.Phase)
	}
	st.Phase = "mutada"
	if svc.Status().Phase != "idle" {
		t.Error("Status debe retornar copia — la mutación externa no puede afectar")
	}
}

// TestPgAuxiliar_StartFalla_EstadoError: si K8s no puede crear el pod, la
// operación falla limpiamente y el estado queda en error (reintetable).
func TestPgAuxiliar_StartFalla_EstadoError(t *testing.T) {
	t.Setenv("PG_AUX_PASSWORD", "test-password") // necesario para alcanzar CreatePodFromManifest
	svc := NewPgAuxiliarService(pgAuxK8sStub{createErr: errors.New("sin cluster")})

	result, err := svc.Start("postgresql-0", "sbos-data", nil)
	if err == nil {
		t.Fatal("Start sin cluster debe fallar")
	}
	if result == nil || result.Success {
		t.Errorf("el resultado debe reportar el fallo: %+v", result)
	}
	if svc.Status().Phase != "error" {
		t.Errorf("fase tras fallo: want error, got %s", svc.Status().Phase)
	}

	// desde fase error se permite reintentar (no queda bloqueado)
	if _, err := svc.Start("postgresql-0", "sbos-data", nil); err == nil {
		t.Fatal("el reintento también falla con el stub, pero debe ser invocable")
	}
}

// TestPgAuxiliar_EnProgresoRechazaConcurrencia: una operación en curso
// (fase ≠ idle/error) rechaza un segundo Start con ErrPgAuxiliarInProgress.
func TestPgAuxiliar_EnProgresoRechazaConcurrencia(t *testing.T) {
	svc := NewPgAuxiliarService(pgAuxK8sStub{})
	svc.status.Phase = "backup" // simula operación en curso (mismo paquete)

	_, err := svc.Start("postgresql-0", "sbos-data", nil)
	if !errors.Is(err, ErrPgAuxiliarInProgress) {
		t.Errorf("want ErrPgAuxiliarInProgress, got %v", err)
	}
}

// TestPgAuxiliar_HelpersPuros: cleanIP y auxPodManifest.
func TestPgAuxiliar_HelpersPuros(t *testing.T) {
	if got := cleanIP(" 10.42.0.15\r\n"); got != "10.42.0.15" {
		t.Errorf("cleanIP: want 10.42.0.15, got %q", got)
	}
	if got := cleanIP("\t \n"); got != "" {
		t.Errorf("cleanIP de blancos: want vacío, got %q", got)
	}

	m := auxPodManifest("sbos-pg-auxiliar", "sbos-data", "postgres:18.4-alpine", "secreto")
	for _, frag := range []string{"kind: Pod", "name: sbos-pg-auxiliar",
		"namespace: sbos-data", "postgres:18.4-alpine"} {
		if !strings.Contains(m, frag) {
			t.Errorf("manifest sin %q:\n%s", frag, m)
		}
	}
}
