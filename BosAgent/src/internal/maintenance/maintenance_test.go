// Package maintenance — tests F9.4.
// DoD: TestMaintenanceSaga_UncordonSiempre (incluso tras crash de la op).
package maintenance

import (
	"errors"
	"strings"
	"sync"
	"testing"
	"time"
)

// k8sFake registra las operaciones y permite inyectar fallos por paso.
type k8sFake struct {
	mu        sync.Mutex
	llamadas  []string
	cordonErr error
	drainErr  error
}

func (f *k8sFake) registrar(op string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.llamadas = append(f.llamadas, op)
}
func (f *k8sFake) Cordon(node string) error { f.registrar("cordon:" + node); return f.cordonErr }
func (f *k8sFake) Drain(node string, _ time.Duration, dry bool) (string, error) {
	f.registrar("drain:" + node)
	return "ok", f.drainErr
}
func (f *k8sFake) Uncordon(node string) error { f.registrar("uncordon:" + node); return nil }

func (f *k8sFake) tiene(op string) bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	for _, l := range f.llamadas {
		if l == op {
			return true
		}
	}
	return false
}

// TestMaintenanceSaga_UncordonSiempre es el DoD de F9.4: el uncordon se
// ejecuta en TODOS los desenlaces — éxito, fallo del drain, fallo de la
// operación y PÁNICO de la operación (crash).
func TestMaintenanceSaga_UncordonSiempre(t *testing.T) {
	// 1. Éxito completo
	fake := &k8sFake{}
	svc := NewService(fake)
	res, err := svc.Ejecutar("nodo-01", time.Minute, true, func() error { return nil })
	if err != nil || !res.Exito {
		t.Fatalf("saga exitosa: err=%v res=%+v", err, res)
	}
	if !res.Uncordoned || !fake.tiene("uncordon:nodo-01") {
		t.Error("éxito: uncordon debe ejecutarse")
	}

	// 2. Fallo del drain → uncordon igual
	fake = &k8sFake{drainErr: errors.New("pdb bloquea la evicción")}
	svc = NewService(fake)
	res, err = svc.Ejecutar("nodo-01", time.Minute, false, nil)
	if err == nil || res.Exito {
		t.Fatal("drain fallido debe reportar error")
	}
	if !res.Uncordoned {
		t.Error("drain fallido: uncordon debe ejecutarse igual (garantía)")
	}

	// 3. Fallo de la operación → uncordon igual
	fake = &k8sFake{}
	svc = NewService(fake)
	res, _ = svc.Ejecutar("nodo-01", time.Minute, true, func() error {
		return errors.New("apt upgrade falló")
	})
	if !res.Uncordoned {
		t.Error("operación fallida: uncordon debe ejecutarse igual")
	}

	// 4. PÁNICO de la operación (crash) → recover + uncordon + error, sin
	// tumbar el proceso
	fake = &k8sFake{}
	svc = NewService(fake)
	res, err = svc.Ejecutar("nodo-01", time.Minute, true, func() error {
		panic("kernel panic simulado del script de mantenimiento")
	})
	if err == nil || !strings.Contains(res.Error, "pánico") {
		t.Fatalf("el pánico debe capturarse como error: err=%v res=%+v", err, res)
	}
	if !res.Uncordoned || !fake.tiene("uncordon:nodo-01") {
		t.Error("CRASH: uncordon debe ejecutarse igual — la garantía central")
	}

	// 5. Cordon fallido: no hay drain ni op, pero el uncordon defensivo corre
	fake = &k8sFake{cordonErr: errors.New("apiserver no responde")}
	svc = NewService(fake)
	res, _ = svc.Ejecutar("nodo-01", time.Minute, true, nil)
	if fake.tiene("drain:nodo-01") {
		t.Error("con cordon fallido no debe drenarse")
	}
	if !res.Uncordoned {
		t.Error("incluso con cordon fallido el uncordon defensivo corre")
	}
}

// TestMaintenanceSaga_MutexYCancelacion: una saga a la vez; la cancelación
// corta entre pasos y el estado se publica/limpia correctamente.
func TestMaintenanceSaga_MutexYCancelacion(t *testing.T) {
	bloqueo := make(chan struct{})
	enOp := make(chan struct{})
	fake := &k8sFake{}
	svc := NewService(fake)

	go svc.Ejecutar("nodo-01", time.Minute, true, func() error {
		close(enOp)
		<-bloqueo
		return nil
	})
	<-enOp

	if est := svc.Estado(); !est.Activa || est.Node != "nodo-01" {
		t.Errorf("estado durante saga: %+v", est)
	}
	if _, err := svc.Ejecutar("nodo-02", time.Minute, true, nil); !errors.Is(err, ErrEnCurso) {
		t.Errorf("segunda saga simultánea: want ErrEnCurso, got %v", err)
	}
	if !svc.Cancelar() {
		t.Error("cancelar con saga activa debe retornar true")
	}
	close(bloqueo)

	// esperar el cierre de la saga
	for i := 0; i < 100 && svc.Estado().Activa; i++ {
		time.Sleep(5 * time.Millisecond)
	}
	if svc.Estado().Activa {
		t.Error("el estado debe limpiarse al terminar")
	}
	if svc.Cancelar() {
		t.Error("cancelar sin saga activa retorna false")
	}

	// sin nodo → error inmediato
	if _, err := svc.Ejecutar("", time.Minute, true, nil); err == nil {
		t.Error("nodo vacío debe fallar")
	}
}
