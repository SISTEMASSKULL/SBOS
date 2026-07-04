// Package server — tests F10.8: handlers bos.ai.* + ToolExecutor.
// DoD: bos.ai.run completa el flujo (ICAP → ejecuta vía dispatcher real).
package server

import (
	"os"
	"path/filepath"
	"testing"

	"bos/internal/biaos"
	"bos/internal/biaos/icap"
)

const catAIServer = `version: "1.0"
acciones:
  - id: query_system_status
    descripcion: "Estado del servidor: salud diagnostico estado"
    metodo_rpc: bos.query.system
    parametros: []
    riesgo: bajo
    confirmacion_requerida: false
    contextos_relevantes: [salud, diagnostico, estado]
  - id: repair_ficha
    descripcion: "Reparar una ficha degradada"
    metodo_rpc: bos.ficha.repair
    parametros: [ficha_id]
    riesgo: medio
    confirmacion_requerida: true
    contextos_relevantes: [DEGRADADA, reparar]
`

// makeAIServer arma un server con fichaSvc real (installer OK) + agente
// biaos cuyo ejecutor ES el dispatcher del propio server (ToolExecutor),
// de modo que bos.ficha.repair funcione al confirmar HITL.
func makeAIServer(t *testing.T) *Server {
	t.Helper()
	s := makeRPCServer(true)
	path := filepath.Join(t.TempDir(), "cat.yml")
	os.WriteFile(path, []byte(catAIServer), 0644)
	cat, err := icap.CargarCatalogo(path, nil)
	if err != nil {
		t.Fatal(err)
	}
	ag := biaos.NewAgente(cat, s.ToolExecutor, nil, nil, nil)
	s.SetAIAgent(ag)
	return s
}

// TestAIRun_FlujoCompleto es el DoD de F10.8: bos.ai.run con intención de
// lectura ejecuta query.system VÍA EL DISPATCHER REAL y devuelve la
// trayectoria con la observación del semáforo.
func TestAIRun_FlujoCompleto(t *testing.T) {
	s := makeAIServer(t)

	resp := s.rpcAIRun(buildRPC("bos.ai.run", map[string]string{
		"intencion": "dame un diagnostico de salud del servidor", "user": "root",
	}))
	if resp.Error != nil {
		t.Fatalf("bos.ai.run: %v", resp.Error)
	}
	res := resp.Result.(*biaos.Resultado)
	if !res.Completado {
		t.Errorf("la intención de lectura debe completarse: %+v", res)
	}
	if len(res.Trayectoria) == 0 || res.Trayectoria[0].Metodo != "bos.query.system" {
		t.Errorf("trayectoria debe ejecutar query.system: %+v", res.Trayectoria)
	}
	// la observación real del dispatcher trae el semáforo
	if res.Conclusion == "" {
		t.Error("conclusión vacía")
	}
}

// TestAIRun_TipoB_HITL: una intención de escritura no ejecuta — devuelve
// requiere_hitl con sesión.
func TestAIRun_TipoB_HITL(t *testing.T) {
	s := makeAIServer(t)

	// el ICAP elige la acción; el caller provee el target estructurado (params)
	resp := s.rpcAIRun(buildRPC("bos.ai.run", map[string]interface{}{
		"intencion": "reparar la ficha degradada",
		"user":      "root",
		"params":    map[string]interface{}{"ficha_id": "redis"},
	}))
	if resp.Error != nil {
		t.Fatal(resp.Error)
	}
	res := resp.Result.(*biaos.Resultado)
	if !res.RequiereHITL || res.SesionHITL == "" {
		t.Errorf("TIPO B debe requerir HITL: %+v", res)
	}

	// confirmar vía bos.ai.confirm → ejecuta repair vía dispatcher
	conf := s.rpcAIConfirm(buildRPC("bos.ai.confirm", map[string]string{
		"sesion_id": res.SesionHITL, "user": "root",
	}))
	if conf.Error != nil {
		t.Fatalf("bos.ai.confirm: %v", conf.Error)
	}
	if !conf.Result.(*biaos.Resultado).Completado {
		t.Error("tras confirmar debe completarse")
	}
}

// TestAICatalog_YGuards: catálogo introspectable; sin agente → ErrInternal;
// params inválidos → InvalidParams.
func TestAICatalog_YGuards(t *testing.T) {
	s := makeAIServer(t)

	cat := s.rpcAICatalog(buildRPC("bos.ai.catalog", nil))
	if cat.Error != nil || cat.Result.(map[string]interface{})["total"] != 2 {
		t.Errorf("catalog: %+v", cat)
	}

	bad := s.rpcAIRun(buildRPC("bos.ai.run", map[string]string{}))
	if bad.Error == nil || bad.Error.Code != ErrInvalidParams {
		t.Errorf("sin intencion: want InvalidParams, got %+v", bad)
	}

	sinAgente := makeCtxTestServer()
	if r := sinAgente.rpcAIRun(buildRPC("bos.ai.run", map[string]string{"intencion": "x"})); r.Error == nil || r.Error.Code != ErrInternal {
		t.Error("sin agente debe dar ErrInternal")
	}
}

// TestToolExecutor_Directo: el ejecutor despacha al registry y mapea errores.
func TestToolExecutor_Directo(t *testing.T) {
	s := makeRPCServer(true)

	out, err := s.ToolExecutor("bos.query.system", nil)
	if err != nil {
		t.Fatalf("query.system vía ToolExecutor: %v", err)
	}
	if _, ok := out.(map[string]interface{})["semaforo"]; !ok {
		t.Error("la salida debe traer el semáforo")
	}

	if _, err := s.ToolExecutor("bos.metodo.inexistente", nil); err == nil {
		t.Error("método inexistente debe fallar")
	}
}
