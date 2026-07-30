// Package grpc — tests del FichaServer gRPC + EventBus + LogReader.
// Cubre: handlers unarios (Pause/Resume/Status/List/Plan/Diff/Validate/Rescan/ResetState),
// streaming (Watch/GetLogs), EventBus y LogReader.
package grpc

import (
	"context"
	"log/slog"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"bos/internal/domain"
	"bos/internal/installer"
	"bos/internal/plugin"
	"bos/internal/state"
	pb "bos/proto/bos/ficha/v1"

	"google.golang.org/grpc/metadata"
)

// ── Stubs de dominio ──────────────────────────────────────────────

type grpcTestState struct {
	mu     sync.RWMutex
	fichas map[string]*state.Ficha
}

func (t *grpcTestState) Read() (*state.SBOSState, error) {
	t.mu.RLock()
	defer t.mu.RUnlock()
	return &state.SBOSState{Fichas: t.fichas}, nil
}
func (t *grpcTestState) Transition(fichaID string, to state.FichaState) error {
	t.mu.Lock()
	defer t.mu.Unlock()
	if f, ok := t.fichas[fichaID]; ok {
		f.State = to
	}
	return nil
}

type grpcTestCatalog struct {
	manifests []*plugin.FichaManifest
}

func (c *grpcTestCatalog) List() []*plugin.FichaManifest { return c.manifests }
func (c *grpcTestCatalog) Count() int                    { return len(c.manifests) }
func (c *grpcTestCatalog) Reload() int                   { return len(c.manifests) }
func (c *grpcTestCatalog) Get(id string) (*plugin.FichaManifest, bool) {
	for _, m := range c.manifests {
		if m.ID == id {
			return m, true
		}
	}
	return nil, false
}

type grpcTestInstaller struct{}

func (grpcTestInstaller) Install(id, v string) (*installer.SagaResult, error) {
	return &installer.SagaResult{Command: "install", FichaID: id, Success: true,
		Steps: []installer.Step{{Name: "prepare"}}}, nil
}
func (grpcTestInstaller) Update(id, v string) (*installer.SagaResult, error) {
	return &installer.SagaResult{Command: "update", FichaID: id, Success: true}, nil
}
func (grpcTestInstaller) Repair(id string) (*installer.SagaResult, error) {
	return &installer.SagaResult{Command: "repair", FichaID: id, Success: true}, nil
}
func (grpcTestInstaller) Remove(id string) (*installer.SagaResult, error) {
	return &installer.SagaResult{Command: "remove", FichaID: id, Success: true}, nil
}
func (grpcTestInstaller) Probe(id string) (*installer.SagaResult, error) {
	return &installer.SagaResult{Command: "probe", FichaID: id, Success: true}, nil
}

// silentLogger descarta todos los logs en tests.
func silentLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError + 100}))
}

// makeGRPCServer crea un FichaServer de prueba con redis=INSTALADA y vault=PAUSADA.
func makeGRPCServer() *FichaServer {
	st := &grpcTestState{fichas: map[string]*state.Ficha{
		"redis": {Name: "redis", Version: "8.6.2", State: state.StateInstalada, HealthStatus: "OK"},
		"vault": {Name: "vault", Version: "2.0.1", State: state.StatePausada, HealthStatus: "OK"},
	}}
	cat := &grpcTestCatalog{manifests: []*plugin.FichaManifest{
		{ID: "redis", Version: "8.6.2"},
		{ID: "vault", Version: "2.0.1"},
	}}
	svc := domain.NewFichaService(grpcTestInstaller{}, st, cat)
	return NewFichaServer(svc, nil, nil, cat, nil, nil, silentLogger())
}

// ── Mock streams ──────────────────────────────────────────────────

// syncWatchStream implementa pb.FichaService_WatchServer con señal tras primer Send.
type syncWatchStream struct {
	ctx    context.Context
	mu     sync.Mutex
	events []*pb.FichaEvent
	ready  chan struct{} // cerrado tras el primer Send (heartbeat)
	once   sync.Once
}

func newSyncWatchStream(ctx context.Context) *syncWatchStream {
	return &syncWatchStream{ctx: ctx, ready: make(chan struct{})}
}

func (m *syncWatchStream) Send(evt *pb.FichaEvent) error {
	m.mu.Lock()
	m.events = append(m.events, evt)
	m.mu.Unlock()
	m.once.Do(func() { close(m.ready) })
	return nil
}
func (m *syncWatchStream) sentCount() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return len(m.events)
}
func (m *syncWatchStream) first() *pb.FichaEvent {
	m.mu.Lock()
	defer m.mu.Unlock()
	if len(m.events) == 0 {
		return nil
	}
	return m.events[0]
}
func (m *syncWatchStream) Context() context.Context             { return m.ctx }
func (m *syncWatchStream) SetHeader(metadata.MD) error          { return nil }
func (m *syncWatchStream) SendHeader(metadata.MD) error         { return nil }
func (m *syncWatchStream) SetTrailer(metadata.MD)               {}
func (m *syncWatchStream) SendMsg(_ any) error                  { return nil }
func (m *syncWatchStream) RecvMsg(_ any) error                  { return nil }

// mockLogStream implementa pb.FichaService_GetLogsServer.
type mockLogStream struct {
	ctx   context.Context
	mu    sync.Mutex
	lines []*pb.LogLine
}

func newMockLogStream(ctx context.Context) *mockLogStream {
	return &mockLogStream{ctx: ctx}
}

func (m *mockLogStream) Send(line *pb.LogLine) error {
	m.mu.Lock()
	m.lines = append(m.lines, line)
	m.mu.Unlock()
	return nil
}
func (m *mockLogStream) lineCount() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return len(m.lines)
}
func (m *mockLogStream) Context() context.Context             { return m.ctx }
func (m *mockLogStream) SetHeader(metadata.MD) error          { return nil }
func (m *mockLogStream) SendHeader(metadata.MD) error         { return nil }
func (m *mockLogStream) SetTrailer(metadata.MD)               {}
func (m *mockLogStream) SendMsg(_ any) error                  { return nil }
func (m *mockLogStream) RecvMsg(_ any) error                  { return nil }

// ── EventBus tests ────────────────────────────────────────────────

func TestEventBus_PubSub_Basico(t *testing.T) {
	bus := NewEventBus()
	id, ch := bus.Subscribe()
	defer bus.Unsubscribe(id)

	evt := &pb.FichaEvent{EventId: "e1", FichaId: "redis",
		Type: pb.FichaEventType_FICHA_EVENT_TYPE_STATE_CHANGED}
	bus.Publish(evt)

	select {
	case got := <-ch:
		if got.EventId != "e1" {
			t.Errorf("event_id: got %q, want e1", got.EventId)
		}
	case <-time.After(200 * time.Millisecond):
		t.Fatal("timeout esperando evento publicado")
	}
}

func TestEventBus_Unsubscribe_CierraCanalLimpiamente(t *testing.T) {
	bus := NewEventBus()
	id, ch := bus.Subscribe()
	bus.Unsubscribe(id)

	// canal cerrado → receive inmediato con zero value
	select {
	case _, ok := <-ch:
		if ok {
			t.Error("canal debe estar cerrado tras Unsubscribe")
		}
	case <-time.After(200 * time.Millisecond):
		t.Fatal("timeout esperando cierre del canal")
	}
}

func TestEventBus_VariosSuscriptores(t *testing.T) {
	bus := NewEventBus()
	id1, ch1 := bus.Subscribe()
	id2, ch2 := bus.Subscribe()
	defer bus.Unsubscribe(id1)
	defer bus.Unsubscribe(id2)

	bus.Publish(&pb.FichaEvent{EventId: "broadcast"})

	recv := func(ch <-chan *pb.FichaEvent, nombre string) {
		select {
		case got := <-ch:
			if got.EventId != "broadcast" {
				t.Errorf("%s: event_id inesperado: %q", nombre, got.EventId)
			}
		case <-time.After(200 * time.Millisecond):
			t.Errorf("%s: timeout", nombre)
		}
	}
	recv(ch1, "sub1")
	recv(ch2, "sub2")
}

func TestEventBus_SlowSubscriber_NoBloquea(t *testing.T) {
	bus := NewEventBus()
	_, _ = bus.Subscribe() // suscriptor lento: nunca lee del canal

	// Publicar más eventos que el buffer (32) — no debe bloquear.
	done := make(chan struct{})
	go func() {
		for i := 0; i < subBufSize+5; i++ {
			bus.Publish(&pb.FichaEvent{EventId: "flood"})
		}
		close(done)
	}()

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("Publish bloqueó con suscriptor lento — debe desconectar y continuar")
	}
}

func TestEventBus_PublishSinSuscriptores(t *testing.T) {
	bus := NewEventBus()
	// No debe panear
	bus.Publish(&pb.FichaEvent{EventId: "nadie"})
}

// ── LogReader tests ───────────────────────────────────────────────

func TestLogReader_ReadLog_ArchivoInexistente(t *testing.T) {
	r := NewLogReader()
	entries, err := r.ReadLog("ficha-que-no-existe-xyz", 10)
	if err != nil {
		t.Fatalf("archivo inexistente no debe error: %v", err)
	}
	if len(entries) != 0 {
		t.Errorf("sin archivo: esperadas 0 entradas, obtenidas %d", len(entries))
	}
}

func TestLogReader_ReadLog_FichaIDVacia(t *testing.T) {
	r := NewLogReader()
	_, err := r.ReadLog("", 10)
	if err == nil {
		t.Fatal("fichaID vacío debe retornar error")
	}
}

func TestLogReader_ReadLog_ConArchivo(t *testing.T) {
	// Crear log temporal con rutas conocidas.
	dir := t.TempDir()
	logFile := filepath.Join(dir, "test-ficha.log")
	content := "2026-07-30T12:00:00Z INFO línea uno\n" +
		"2026-07-30T12:00:01Z WARN línea dos\n" +
		"2026-07-30T12:00:02Z ERROR línea tres\n"
	if err := os.WriteFile(logFile, []byte(content), 0o644); err != nil {
		t.Fatalf("escribir log: %v", err)
	}

	// Probar parseLine directamente sin abrir el archivo con ruta del sistema.
	e := parseLogLine("test-ficha", 1, "2026-07-30T12:00:00Z INFO mensaje de prueba")
	if e.Level != "INFO" {
		t.Errorf("nivel: got %q, want INFO", e.Level)
	}
	if e.Message != "mensaje de prueba" {
		t.Errorf("mensaje: got %q, want 'mensaje de prueba'", e.Message)
	}
	if e.FichaID != "test-ficha" {
		t.Errorf("fichaID: got %q, want test-ficha", e.FichaID)
	}
	if e.LineNumber != 1 {
		t.Errorf("lineNumber: got %d, want 1", e.LineNumber)
	}
}

func TestLogReader_ParseLine_FormatoInvalido(t *testing.T) {
	// Línea sin formato RFC3339 → Message = línea completa, Level = INFO (default)
	e := parseLogLine("ficha", 5, "línea de log sin formato estándar")
	if e.Message != "línea de log sin formato estándar" {
		t.Errorf("mensaje: got %q", e.Message)
	}
	if e.Level != "INFO" {
		t.Errorf("nivel default: got %q, want INFO", e.Level)
	}
	if e.LineNumber != 5 {
		t.Errorf("lineNumber: got %d, want 5", e.LineNumber)
	}
}

func TestLogReader_ParseLine_Niveles(t *testing.T) {
	casos := []struct{ input, wantLevel string }{
		{"2026-07-30T12:00:00Z DEBUG msg debug", "DEBUG"},
		{"2026-07-30T12:00:00Z INFO msg info", "INFO"},
		{"2026-07-30T12:00:00Z WARN msg warn", "WARN"},
		{"2026-07-30T12:00:00Z ERROR msg error", "ERROR"},
	}
	for _, c := range casos {
		e := parseLogLine("f", 1, c.input)
		if e.Level != c.wantLevel {
			t.Errorf("input=%q: nivel got %q, want %q", c.input, e.Level, c.wantLevel)
		}
	}
}

func TestLogReader_FollowLog_FichaIDVacia(t *testing.T) {
	r := NewLogReader()
	_, err := r.FollowLog("")
	if err == nil {
		t.Fatal("fichaID vacío debe retornar error")
	}
}

func TestLogReader_FollowLog_ArchivoInexistente(t *testing.T) {
	r := NewLogReader()
	ch, err := r.FollowLog("ficha-no-existe-xyz")
	if err != nil {
		t.Fatalf("FollowLog no debe error aunque el archivo no exista: %v", err)
	}
	// El canal se cierra inmediatamente porque el goroutine no pudo abrir el archivo.
	select {
	case _, ok := <-ch:
		if ok {
			t.Error("canal debe cerrarse si el archivo no existe")
		}
	case <-time.After(500 * time.Millisecond):
		t.Fatal("timeout esperando cierre del canal FollowLog")
	}
}

// ── FichaServer — handlers unarios ───────────────────────────────

func TestFichaServer_Pause_OK(t *testing.T) {
	srv := makeGRPCServer()
	resp, err := srv.Pause(context.Background(), &pb.PauseRequest{FichaId: "redis"})
	if err != nil {
		t.Fatalf("Pause redis: %v", err)
	}
	if !resp.Success {
		t.Error("Success debe ser true")
	}
	if resp.PrevState != "INSTALADA" {
		t.Errorf("PrevState: got %q, want INSTALADA", resp.PrevState)
	}
}

func TestFichaServer_Pause_FichaInexistente(t *testing.T) {
	srv := makeGRPCServer()
	_, err := srv.Pause(context.Background(), &pb.PauseRequest{FichaId: "fantasma"})
	if err == nil {
		t.Fatal("ficha inexistente debe retornar error gRPC")
	}
}

func TestFichaServer_Resume_OK(t *testing.T) {
	srv := makeGRPCServer()
	resp, err := srv.Resume(context.Background(), &pb.ResumeRequest{FichaId: "vault"})
	if err != nil {
		t.Fatalf("Resume vault: %v", err)
	}
	if !resp.Success {
		t.Error("Success debe ser true")
	}
	if resp.NewState != "INSTALADA" {
		t.Errorf("NewState: got %q, want INSTALADA", resp.NewState)
	}
}

func TestFichaServer_Status_Individual(t *testing.T) {
	srv := makeGRPCServer()
	resp, err := srv.Status(context.Background(), &pb.StatusRequest{FichaId: "redis"})
	if err != nil {
		t.Fatalf("Status redis: %v", err)
	}
	single, ok := resp.Result.(*pb.StatusResponse_Single)
	if !ok || single.Single == nil {
		t.Fatal("esperado StatusResponse_Single")
	}
	if single.Single.Id != "redis" {
		t.Errorf("ID: got %q", single.Single.Id)
	}
}

func TestFichaServer_Status_Global(t *testing.T) {
	srv := makeGRPCServer()
	resp, err := srv.Status(context.Background(), &pb.StatusRequest{FichaId: ""})
	if err != nil {
		t.Fatalf("Status global: %v", err)
	}
	all, ok := resp.Result.(*pb.StatusResponse_All)
	if !ok || all.All == nil {
		t.Fatal("esperado StatusResponse_All")
	}
	if all.All.Total != 2 {
		t.Errorf("Total: got %d, want 2", all.All.Total)
	}
}

func TestFichaServer_List_OK(t *testing.T) {
	srv := makeGRPCServer()
	resp, err := srv.List(context.Background(), &pb.ListRequest{})
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if resp.Total != 2 {
		t.Errorf("Total: got %d, want 2", resp.Total)
	}
}

func TestFichaServer_Plan_OK(t *testing.T) {
	srv := makeGRPCServer()
	resp, err := srv.Plan(context.Background(), &pb.PlanRequest{})
	if err != nil {
		t.Fatalf("Plan: %v", err)
	}
	if resp.Total != 2 {
		t.Errorf("Total: got %d, want 2", resp.Total)
	}
	if resp.HasCycles {
		t.Error("sin dependencias circulares: HasCycles debe ser false")
	}
}

func TestFichaServer_Diff_Individual(t *testing.T) {
	srv := makeGRPCServer()
	resp, err := srv.Diff(context.Background(), &pb.DiffRequest{FichaId: "redis"})
	if err != nil {
		t.Fatalf("Diff individual: %v", err)
	}
	single, ok := resp.Result.(*pb.DiffResponse_Single)
	if !ok {
		t.Fatal("esperado DiffResponse_Single")
	}
	if single.Single.FichaId != "redis" {
		t.Errorf("FichaId: %q", single.Single.FichaId)
	}
}

func TestFichaServer_Validate_Todas(t *testing.T) {
	srv := makeGRPCServer()
	resp, err := srv.Validate(context.Background(), &pb.ValidateRequest{FichaId: ""})
	if err != nil {
		t.Fatalf("Validate todas: %v", err)
	}
	if resp.TotalFichas != 2 {
		t.Errorf("TotalFichas: got %d, want 2", resp.TotalFichas)
	}
}

func TestFichaServer_Rescan_OK(t *testing.T) {
	srv := makeGRPCServer()
	resp, err := srv.Rescan(context.Background(), &pb.RescanRequest{})
	if err != nil {
		t.Fatalf("Rescan: %v", err)
	}
	if resp.Total != 2 {
		t.Errorf("Total: got %d, want 2", resp.Total)
	}
}

func TestFichaServer_ResetState_OK(t *testing.T) {
	srv := makeGRPCServer()
	resp, err := srv.ResetState(context.Background(), &pb.ResetStateRequest{
		FichaId:     "redis",
		TargetState: "DEGRADADA",
	})
	if err != nil {
		t.Fatalf("ResetState: %v", err)
	}
	if !resp.Success {
		t.Error("ResetState debe tener éxito")
	}
}

// ── FichaServer — Watch (streaming) ──────────────────────────────

func TestFichaServer_Watch_HeartbeatInicial(t *testing.T) {
	srv := makeGRPCServer()
	// Cancelar contexto de inmediato para no bloquear.
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	stream := newSyncWatchStream(ctx)
	_ = srv.Watch(&pb.WatchRequest{FichaId: "redis"}, stream)

	if stream.sentCount() < 1 {
		t.Fatal("Watch debe enviar heartbeat inicial antes del select")
	}
	if first := stream.first(); first.Type != pb.FichaEventType_FICHA_EVENT_TYPE_HEARTBEAT {
		t.Errorf("primer evento debe ser HEARTBEAT, got %v", first.Type)
	}
}

func TestFichaServer_Watch_ConBus_RecibEvento(t *testing.T) {
	srv := makeGRPCServer()
	srv.bus = NewEventBus()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	stream := newSyncWatchStream(ctx)
	done := make(chan error, 1)
	go func() {
		done <- srv.Watch(&pb.WatchRequest{FichaId: "redis"}, stream)
	}()

	// Esperar a que se envíe el heartbeat (goroutine está escuchando en el bus).
	select {
	case <-stream.ready:
	case <-time.After(2 * time.Second):
		t.Fatal("timeout esperando heartbeat de Watch")
	}

	// Publicar evento filtrado (ficha_id=redis coincide con el filtro).
	srv.bus.Publish(&pb.FichaEvent{
		EventId: "evt-redis",
		FichaId: "redis",
		Type:    pb.FichaEventType_FICHA_EVENT_TYPE_STATE_CHANGED,
	})

	// Publicar evento que no debe llegar (ficha_id=vault, filtro=redis).
	srv.bus.Publish(&pb.FichaEvent{
		EventId: "evt-vault",
		FichaId: "vault",
		Type:    pb.FichaEventType_FICHA_EVENT_TYPE_STATE_CHANGED,
	})

	// Dar tiempo al goroutine de Watch para procesar los eventos.
	time.Sleep(50 * time.Millisecond)
	cancel()

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("Watch no terminó tras cancelar el contexto")
	}

	// Debe tener heartbeat + evt-redis (evt-vault filtrado por fichaID).
	if stream.sentCount() < 2 {
		t.Errorf("esperados ≥2 eventos (heartbeat + redis), obtenidos %d", stream.sentCount())
	}
}

func TestFichaServer_Watch_SinBus_TerminaConContexto(t *testing.T) {
	srv := makeGRPCServer()
	// bus=nil ya está por defecto en makeGRPCServer

	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()

	stream := newSyncWatchStream(ctx)
	err := srv.Watch(&pb.WatchRequest{}, stream)
	if err == nil {
		t.Error("Watch sin bus con contexto cancelado debe retornar error de contexto")
	}
}

// ── FichaServer — GetLogs (streaming) ────────────────────────────

func TestFichaServer_GetLogs_SinLogReader(t *testing.T) {
	srv := makeGRPCServer()
	// logReader=nil → bloquea hasta context

	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()

	stream := newMockLogStream(ctx)
	err := srv.GetLogs(&pb.GetLogsRequest{FichaId: "redis", TailLines: 10}, stream)
	if err == nil {
		t.Error("GetLogs sin logReader con contexto expirado debe retornar error")
	}
}

func TestFichaServer_GetLogs_ConLogReader_SinArchivo(t *testing.T) {
	srv := makeGRPCServer()
	srv.logReader = NewLogReader() // logReader real, sin archivos de log

	ctx := context.Background()
	stream := newMockLogStream(ctx)
	err := srv.GetLogs(&pb.GetLogsRequest{
		FichaId:   "redis",
		TailLines: 10,
		Follow:    false, // sin follow → termina inmediatamente
	}, stream)
	if err != nil {
		t.Fatalf("GetLogs con logReader sin archivo: %v", err)
	}
	if stream.lineCount() != 0 {
		t.Errorf("sin archivo de log: esperadas 0 líneas, obtenidas %d", stream.lineCount())
	}
}

// ── FichaServer — Scale (F9) ──────────────────────────────────────

// grpcTestScaler implementa K8sScalePort para tests.
type grpcTestScaler struct {
	scaleErr error
	prevReps int32
}

func (k *grpcTestScaler) ScaleDeployment(ns, name string, replicas int) error {
	return k.scaleErr
}
func (k *grpcTestScaler) GetDesiredReplicas(ns, kind, name string) (int32, error) {
	return k.prevReps, nil
}

func TestFichaServer_Scale_SinK8sScaler(t *testing.T) {
	srv := makeGRPCServer()
	// k8sScaler=nil → Unavailable

	ctx := context.Background()
	_, err := srv.Scale(ctx, &pb.ScaleRequest{FichaId: "redis", Replicas: 3})
	if err == nil {
		t.Fatal("Scale sin k8sScaler debe retornar error")
	}
}

func TestFichaServer_Scale_FichaSinPath(t *testing.T) {
	srv := makeGRPCServer()
	srv.k8sScaler = &grpcTestScaler{}
	// catalog tiene redis con Path="" → ParseWorkloadInfo falla

	ctx := context.Background()
	_, err := srv.Scale(ctx, &pb.ScaleRequest{FichaId: "redis", Replicas: 2})
	if err == nil {
		t.Fatal("Scale con ficha sin path debe retornar error")
	}
}

func TestFichaServer_Scale_OK(t *testing.T) {
	dir := t.TempDir()
	_ = os.WriteFile(filepath.Join(dir, "manifest.yml"), []byte(`
identity:
  id: redis
  server: S01
  version: 8.6.2
workload:
  type: Deployment
  runtime: kubernetes
meta:
  backend: apt
`), 0o644)
	_ = os.WriteFile(filepath.Join(dir, "yaml_engine.yml"), []byte("namespace: sbos-data\n"), 0o644)

	srv := makeGRPCServer()
	srv.k8sScaler = &grpcTestScaler{prevReps: 2}
	// Reemplazar catalog con uno que tenga Path real
	srv.catalog = &grpcTestCatalog{manifests: []*plugin.FichaManifest{
		{ID: "redis", Version: "8.6.2", Path: dir},
	}}

	ctx := context.Background()
	resp, err := srv.Scale(ctx, &pb.ScaleRequest{FichaId: "redis", Replicas: 4})
	if err != nil {
		t.Fatalf("Scale OK: %v", err)
	}
	if !resp.Success {
		t.Error("success debe ser true")
	}
	if resp.NewReplicas != 4 {
		t.Errorf("new_replicas: want 4, got %d", resp.NewReplicas)
	}
	if resp.PrevReplicas != 2 {
		t.Errorf("prev_replicas: want 2, got %d", resp.PrevReplicas)
	}
}
