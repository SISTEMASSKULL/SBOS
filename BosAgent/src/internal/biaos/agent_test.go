// Package biaos — tests F10.5/F10.6/F10.7: agente ReAct, HITL, guardrails.
// DoD ancla BOS-REPAIR-10: TestDomainGuard_RejectsBusinessData,
// TestHITL_ExpiresAfterTimeout, TestAudit_AlwaysBeforeToolExecution.
package biaos

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	"bos/internal/biaos/audit"
	"bos/internal/biaos/icap"
)

const catTest = `version: "1.0"
acciones:
  - id: query_system_status
    descripcion: "Estado del servidor: salud, diagnostico"
    metodo_rpc: bos.query.system
    parametros: []
    riesgo: bajo
    confirmacion_requerida: false
    contextos_relevantes: [diagnostico, salud, estado]
  - id: repair_ficha
    descripcion: "Reparar una ficha degradada"
    metodo_rpc: bos.ficha.repair
    parametros: [ficha_id]
    riesgo: medio
    confirmacion_requerida: true
    contextos_relevantes: [DEGRADADA, reparar]
  - id: drain_nodo
    descripcion: "Evacuar pods de un nodo"
    metodo_rpc: bos.k8s.node.drain
    parametros: [node]
    riesgo: alto
    confirmacion_requerida: true
    contextos_relevantes: [evacuar, drain, mantenimiento]
    compensacion: bos.k8s.node.uncordon
    advertencia: "single-node drain deja el cluster sin capacidad"
`

func agenteDePrueba(t *testing.T, exec RPCExecutor, rbac RBACPort) (*Agente, *sesionStore) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "cat.yml")
	os.WriteFile(path, []byte(catTest), 0644)
	cat, err := icap.CargarCatalogo(path, nil)
	if err != nil {
		t.Fatal(err)
	}
	ss := newSesionStore()
	return NewAgente(cat, exec, rbac, ss, nil), ss
}

// TestAgente_TipoA_EjecutaYConcluye: lectura corre directo y observa.
func TestAgente_TipoA_EjecutaYConcluye(t *testing.T) {
	var llamado string
	exec := func(m string, p map[string]interface{}) (interface{}, error) {
		llamado = m
		return map[string]interface{}{"semaforo": "VERDE"}, nil
	}
	ag, _ := agenteDePrueba(t, exec, nil)

	res, err := ag.Run("root", "dame un diagnostico de salud del servidor")
	if err != nil {
		t.Fatal(err)
	}
	if llamado != "bos.query.system" {
		t.Errorf("debe ejecutar query.system, llamó %q", llamado)
	}
	if !res.Completado || res.RequiereHITL {
		t.Errorf("TIPO A completa sin HITL: %+v", res)
	}
	if res.Conclusion == "" || res.Trayectoria[0].Metodo != "bos.query.system" {
		t.Errorf("trayectoria/conclusión: %+v", res)
	}
}

// TestAgente_TipoB_SeDetieneEnHITL: riesgo>bajo NO ejecuta — crea sesión.
func TestAgente_TipoB_SeDetieneEnHITL(t *testing.T) {
	var ejecutado bool
	exec := func(m string, p map[string]interface{}) (interface{}, error) {
		ejecutado = true
		return nil, nil
	}
	ag, ss := agenteDePrueba(t, exec, nil)

	res, err := ag.Run("root", "evacuar el nodo para mantenimiento")
	if err != nil {
		t.Fatal(err)
	}
	if ejecutado {
		t.Error("TIPO B NO debe ejecutar sin confirmación")
	}
	if !res.RequiereHITL || res.SesionHITL == "" {
		t.Fatalf("debe requerir HITL: %+v", res)
	}
	if len(ss.Pendientes()) != 1 {
		t.Error("la sesión debe quedar pendiente")
	}

	// confirmar → ahora sí ejecuta
	res2, err := ag.Confirmar("root", res.SesionHITL)
	if err != nil {
		t.Fatal(err)
	}
	if !ejecutado || !res2.Completado {
		t.Errorf("tras confirmar debe ejecutar: %+v", res2)
	}
	// la sesión es de un solo uso
	if _, err := ag.Confirmar("root", res.SesionHITL); !errors.Is(err, ErrSesionNoEncontrada) {
		t.Error("una sesión confirmada no puede reusarse")
	}
}

// TestDomainGuard_RejectsBusinessData (DoD ancla): intenciones de negocio
// se rechazan antes de tocar el ICAP.
func TestDomainGuard_RejectsBusinessData(t *testing.T) {
	ag, _ := agenteDePrueba(t, func(string, map[string]interface{}) (interface{}, error) {
		t.Fatal("no debe ejecutarse nada para datos de negocio")
		return nil, nil
	}, nil)

	for _, in := range []string{
		"muéstrame las ventas del mes",
		"cuántas facturas emitió el cliente skull",
		"el cálculo de impuestos del SIAT",
	} {
		if _, err := ag.Run("root", in); !errors.Is(err, ErrFueraDeDominio) {
			t.Errorf("%q debe rechazarse por dominio, got %v", in, err)
		}
	}
	// una intención de infraestructura sí pasa la guardia
	if err := GuardiaDominio("reiniciar el pod degradado"); err != nil {
		t.Errorf("intención de infra no debe rechazarse: %v", err)
	}
}

// TestAgente_RBACDeniega: sin permiso, la acción no se ejecuta.
func TestAgente_RBACDeniega(t *testing.T) {
	var ejecutado bool
	exec := func(string, map[string]interface{}) (interface{}, error) {
		ejecutado = true
		return nil, nil
	}
	ag, _ := agenteDePrueba(t, exec, rbacStub{deniega: true})

	res, _ := ag.Run("intruso", "diagnostico de salud del servidor")
	if ejecutado {
		t.Error("RBAC debe impedir la ejecución")
	}
	if res.Completado {
		t.Error("no puede completar si RBAC deniega")
	}
}

// TestAudit_AlwaysBeforeToolExecution (DoD ancla): el evento de ejecución
// se registra ANTES de llamar a la herramienta.
func TestAudit_AlwaysBeforeToolExecution(t *testing.T) {
	auditPath := filepath.Join(t.TempDir(), "ai-audit.jsonl")
	logger, err := audit.NewLogger(auditPath)
	if err != nil {
		t.Fatal(err)
	}

	orden := []string{}
	exec := func(m string, p map[string]interface{}) (interface{}, error) {
		orden = append(orden, "ejecuto:"+m)
		return map[string]interface{}{"ok": true}, nil
	}
	path := filepath.Join(t.TempDir(), "cat.yml")
	os.WriteFile(path, []byte(catTest), 0644)
	cat, _ := icap.CargarCatalogo(path, nil)
	ag := NewAgente(cat, exec, nil, newSesionStore(), logger)

	ag.Run("root", "diagnostico salud estado del servidor")
	logger.Close()

	data, _ := os.ReadFile(auditPath)
	contenido := string(data)
	// el evento "ejecucion" debe haberse escrito; y la ejecución ocurrió
	if len(orden) != 1 {
		t.Fatalf("la herramienta debe ejecutarse una vez: %v", orden)
	}
	if !contains(contenido, `"tipo":"ejecucion"`) || !contains(contenido, `"tipo":"intent"`) {
		t.Errorf("el audit debe registrar intent y ejecucion:\n%s", contenido)
	}
	if !contains(contenido, "bos.query.system") {
		t.Error("el método ejecutado debe quedar auditado")
	}
}

// TestHITL_ExpiresAfterTimeout (DoD ancla): una sesión vencida no se
// confirma.
func TestHITL_ExpiresAfterTimeout(t *testing.T) {
	orig := SesionTTL
	defer func() { SesionTTL = orig }()
	SesionTTL = 30 * time.Millisecond

	ag, _ := agenteDePrueba(t, func(string, map[string]interface{}) (interface{}, error) {
		t.Fatal("una sesión expirada no debe ejecutar")
		return nil, nil
	}, nil)

	res, _ := ag.Run("root", "reparar la ficha degradada")
	if !res.RequiereHITL {
		t.Fatal("debe crear sesión HITL")
	}
	time.Sleep(50 * time.Millisecond)
	if _, err := ag.Confirmar("root", res.SesionHITL); !errors.Is(err, ErrSesionExpirada) {
		t.Errorf("confirmar tras TTL debe dar ErrSesionExpirada, got %v", err)
	}
}

// TestListarHerramientas: el catálogo se introspecta (bos.ai.catalog).
func TestListarHerramientas(t *testing.T) {
	ag, _ := agenteDePrueba(t, func(string, map[string]interface{}) (interface{}, error) {
		return nil, nil
	}, nil)
	hs := ag.listarHerramientas()
	if len(hs) != 3 {
		t.Fatalf("want 3 herramientas, got %d", len(hs))
	}
	// las de riesgo>bajo marcan [HITL]
	var conHITL int
	for _, h := range hs {
		if contains(h, "[HITL]") {
			conHITL++
		}
	}
	if conHITL != 2 {
		t.Errorf("repair y drain deben marcar HITL: %d", conHITL)
	}
}

type rbacStub struct{ deniega bool }

func (r rbacStub) CanExecute(user, cmd string) error {
	if r.deniega {
		return errors.New("rol sin permiso para " + cmd)
	}
	return nil
}

func contains(s, sub string) bool {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}
