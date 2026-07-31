// Package biaos — tests de la capa LLM migrada en F10.2 (router 3 niveles,
// cliente multi-backend con httptest, builder de contexto operativo).
package biaos

import (
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"

	"bos/internal/state"
)

// limpiarEnvIA aísla los tests de las variables BOS_AI_* del entorno.
func limpiarEnvIA(t *testing.T) {
	t.Helper()
	for _, k := range []string{"BOS_AI_API_KEY", "DEEPSEEK_API_KEY", "ANTHROPIC_API_KEY",
		"BOS_AI_LOCAL_ENDPOINT", "BOS_AI_LOCAL_TYPE", "BOS_AI_LOCAL_MODEL",
		"BOS_AI_LOCAL_API_KEY", "BOS_AI_PRIMARY_MODEL", "BOS_AI_FALLBACK_MODEL",
		"OLLAMA_HOST", "BOS_AI_TIMEOUT_SECONDS"} {
		t.Setenv(k, "")
	}
}

// TestRouter_TresNivelesYRateLimit: sin API keys el router cae al backend
// local; con primary configurado lo prefiere; un 429 degrada de nivel y
// Stats lo refleja.
func TestRouter_TresNivelesYRateLimit(t *testing.T) {
	limpiarEnvIA(t)

	// sin keys → local (ollama)
	r, err := NewRouter()
	if err != nil {
		t.Fatal(err)
	}
	if b := r.Route(); !b.IsLocal {
		t.Errorf("sin API keys debe rutear al local, got %+v", b)
	}

	// con primary key → deepseek primero
	t.Setenv("BOS_AI_API_KEY", "sk-test")
	r2, _ := NewRouter()
	b := r2.Route()
	if b.Name != "deepseek" {
		t.Fatalf("con key primaria debe rutear a deepseek, got %s", b.Name)
	}

	// 429 en primary → degrada (a local: no hay key de anthropic)
	r2.ReportRateLimit("deepseek", "429 too many requests")
	if b := r2.Route(); b.Name == "deepseek" {
		t.Error("tras rate-limit el primary no debe rutearse de inmediato")
	}
	r2.ReportSuccess(128)
	if r2.Stats().TotalTokens != 128 {
		t.Errorf("stats: %+v", r2.Stats())
	}
	if r2.ActiveBackendName() == "" {
		t.Error("ActiveBackendName vacío")
	}
}

// TestRouter_Override: el override manual consume un solo Route().
func TestRouter_Override(t *testing.T) {
	limpiarEnvIA(t)
	r, _ := NewRouter()
	r.SetOverride("qwen3:14b")
	if b := r.Route(); b.Model != "qwen3:14b" {
		t.Errorf("override debe resolver al modelo pedido: %+v", b)
	}
	// consumido: el siguiente Route vuelve a la selección normal
	if b := r.Route(); b.Model == "" {
		t.Errorf("segundo route: %+v", b)
	}
}

// TestClient_AskViaOllamaFake: el cliente completa una pregunta contra un
// endpoint Ollama simulado (httptest) — cubre callOllama + Ask.
func TestClient_AskViaOllamaFake(t *testing.T) {
	limpiarEnvIA(t)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		if strings.Contains(req.URL.Path, "generate") || strings.Contains(req.URL.Path, "chat") {
			w.Write([]byte(`{"response":"semáforo VERDE — sistema sano","done":true}`))
			return
		}
		w.Write([]byte(`{}`))
	}))
	defer srv.Close()
	t.Setenv("BOS_AI_LOCAL_ENDPOINT", srv.URL)
	t.Setenv("BOS_AI_TIMEOUT_SECONDS", "5")

	c, err := NewClient()
	if err != nil {
		t.Fatal(err)
	}
	resp, err := c.Ask("¿estado del sistema?", nil, "")
	if err != nil {
		t.Fatalf("Ask vía ollama fake: %v", err)
	}
	if !strings.Contains(resp, "VERDE") {
		t.Errorf("respuesta del backend: %q", resp)
	}
	if c.ActiveBackend() == "" {
		t.Error("ActiveBackend vacío tras Ask")
	}
}

// TestGateway_AskConBreakerYBackendCaido: un backend que siempre falla
// alimenta el breaker a través de la ruta pública Gateway.Ask.
func TestGateway_AskConBreakerYBackendCaido(t *testing.T) {
	limpiarEnvIA(t)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, "boom", 500)
	}))
	defer srv.Close()
	t.Setenv("BOS_AI_LOCAL_ENDPOINT", srv.URL)
	t.Setenv("BOS_AI_TIMEOUT_SECONDS", "3")

	c, err := NewClient()
	if err != nil {
		t.Fatal(err)
	}
	g := newGatewayParaTest(c)
	for i := 0; i < breakerMaxFallos; i++ {
		if _, err := g.Ask("x", nil, ""); err == nil {
			t.Fatal("backend 500 debe fallar")
		}
	}
	if _, err := g.Ask("x", nil, ""); err == nil || !strings.Contains(err.Error(), "circuito abierto") {
		t.Errorf("el circuito debe estar abierto: %v", err)
	}
}

// TestBuildContext_YFormat: el contexto operativo agrega fichas del estado
// real (TempDir) y Format produce el prompt con secciones.
func TestBuildContext_YFormat(t *testing.T) {
	mgr, err := state.NewManager(filepath.Join(t.TempDir(), "state.json"))
	if err != nil {
		t.Fatal(err)
	}
	defer mgr.Close()
	mgr.Register("redis", state.StateInstalled, "8.6.2", true, "dataserver", 1, "helm")
	mgr.Register("vault", state.StatePending, "2.0.1", true, "secserver", 1, "helm")

	ctx := BuildContext(mgr)
	if ctx == nil || ctx.Hostname == "" || ctx.Timestamp == "" {
		t.Fatalf("contexto incompleto: %+v", ctx)
	}

	prompt := ctx.Format("¿qué fichas están activas?")
	if !strings.Contains(prompt, "redis") {
		t.Errorf("el prompt debe incluir la ficha activa:\n%s", prompt)
	}
	if !strings.Contains(prompt, "¿qué fichas están activas?") {
		t.Error("el prompt debe incluir la pregunta")
	}
}
