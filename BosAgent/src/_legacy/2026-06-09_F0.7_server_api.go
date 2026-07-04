// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// SOLO REFERENCIA DE LÓGICA — NO IMPORTAR, NO COPIAR COMO ESTÁ.
//
// Origen: internal/server/api.go (archivado en F0.7)
// Destino: internal/server/ws.go extendido (Fase 2)
// Razón: handlers REST deben migrarse a WebSocket RPC según ADR-019/ADR-020.
//
// Package server implementa la API WebSocket del daemon bos sobre Unix socket y HTTP.
// Fase B: toda la comunicación es vía WebSocket (request/response + eventos).
// No se exponen endpoints REST — solo /ws para upgrade WebSocket.
package server

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"os"
	"sync"
	"time"

	"bos/internal/domain"
	"bos/internal/installer"
	"bos/internal/plugin"
	"bos/internal/security"
	"bos/internal/state"

	"log/slog"
)

// StateManager is the interface to the STATE_MANAGER.
type StateManager interface {
	Read() (*state.SBOSState, error)
	Transition(name string, to state.FichaState) error
	SetHealth(name, status string) error
}

// PluginLoader is the interface for listing known fichas.
type PluginLoader interface {
	List() []*plugin.FichaManifest
	Get(id string) (*plugin.FichaManifest, bool)
	Count() int
}

// HealthChecker is the interface for querying health status.
type HealthChecker interface{}

// Installer is the interface for triggering saga operations.
type Installer interface {
	Install(fichaID, version string) (*installer.SagaResult, error)
	Update(fichaID, version string) (*installer.SagaResult, error)
	Repair(fichaID string) (*installer.SagaResult, error)
	Remove(fichaID string) (*installer.SagaResult, error)
	Probe(fichaID string) (*installer.SagaResult, error)
	Status(fichaID string) (string, error)
}

// ReleaseChecker is the port for the SKULL Release Plane (pull-only).
type ReleaseChecker interface {
	CheckAvailable(ficha, currentVersion string) ([]ReleaseInfo, error)
	GetLatest(ficha string) (*ReleaseInfo, error)
	ListAll() ([]ReleaseInfo, error)
}

// ReleaseInfo is a lightweight copy of release.ReleaseInfo for the server package.
type ReleaseInfo struct {
	Ficha       string `json:"ficha"`
	Version     string `json:"version"`
	Channel     string `json:"channel"`
	ReleaseDate string `json:"release_date"`
	MinBosVer   string `json:"min_bos_version"`
	Checksum    string `json:"checksum"`
	Breaking    bool   `json:"breaking"`
	Notes       string `json:"notes"`
}

// Server holds the WebSocket servers (HTTP + Unix socket).
type Server struct {
	mu            sync.Mutex
	cfg           Config
	stateMgr      StateManager
	plugins       PluginLoader
	installer     Installer
	healthCheck   HealthChecker
	rbac          security.RBACProvider
	identity      security.IdentityProvider
	configPending bool
	bosConfigPath string

	// Servicios de dominio (ORQUESTA-043 §2 — Capa de Dominio)
	fichaSvc     *domain.FichaService
	bootstrapSvc *domain.BootstrapService
	ctxSvc       *domain.CtxService
	pgAuxSvc     *domain.PgAuxiliarService // PG Auxiliar (Parte V-B)
	releaseMgr   interface {
		CheckAvailable(ficha, currentVersion string) ([]ReleaseInfo, error)
		GetLatest(ficha string) (*ReleaseInfo, error)
		ListAll() ([]ReleaseInfo, error)
	}

	httpServer *http.Server
	unixServer *http.Server
	logger     *slog.Logger
	wsHub      *Hub

	// ShutdownCh is closed when the daemon receives a shutdown request via WS.
	ShutdownCh chan struct{}
}

// Config for the WebSocket server.
type Config struct {
	HTTPPort   int
	UnixSocket string
}

// NewServer creates the server in normal mode.
func NewServer(cfg Config, stateMgr StateManager, plugins PluginLoader, healthCheck HealthChecker, installer Installer, rbac security.RBACProvider, identity security.IdentityProvider, logger *slog.Logger, pgAuxSvc *domain.PgAuxiliarService) *Server {
	s := &Server{
		cfg:         cfg,
		stateMgr:    stateMgr,
		plugins:     plugins,
		healthCheck: healthCheck,
		installer:   installer,
		rbac:        rbac,
		identity:    identity,
		logger:      logger,
		wsHub:       NewHub(logger),
		ShutdownCh:  make(chan struct{}),
		// Servicios de dominio — inyectados aquí, usados por los handlers RPC (ORQUESTA-043 §2)
		fichaSvc:     domain.NewFichaService(installer, stateMgr, plugins),
		bootstrapSvc: domain.NewBootstrapService(stateMgr),
		ctxSvc:       domain.NewCtxService(),
		pgAuxSvc:     pgAuxSvc,
	}

	go s.wsHub.Run()
	return s
}

// NewConfigPendingServer creates the server in config-pending (staged) mode.
func NewConfigPendingServer(cfg Config, bosConfigPath string, logger *slog.Logger) *Server {
	s := &Server{
		cfg:           cfg,
		configPending: true,
		bosConfigPath: bosConfigPath,
		logger:        logger,
		wsHub:         NewHub(logger),
		ShutdownCh:    make(chan struct{}),
	}

	go s.wsHub.Run()
	return s
}

// BroadcastStepEvent transmite un evento de paso (step_start/step_ok/step_fail) al TUI.
func (s *Server) BroadcastStepEvent(evType EventType, fichaID, stepName, errMsg string) {
	s.wsHub.Broadcast(Event{
		Type:    evType,
		Ficha:   fichaID,
		Step:    stepName,
		Message: errMsg,
	})
}

// SetReleaseManager inyecta el Release Plane después de construir el Server.
// BroadcastFichaLog transmite una línea de log cruda del script bash al TUI via WebSocket.
// Llamado por el logObserver del orchestrator en tiempo real.
func (s *Server) BroadcastFichaLog(fichaID, line string) {
	s.wsHub.Broadcast(Event{
		Type:    EventFichaLog,
		Ficha:   fichaID,
		Message: line,
	})
}

func (s *Server) SetReleaseManager(mgr interface {
	CheckAvailable(ficha, currentVersion string) ([]ReleaseInfo, error)
	GetLatest(ficha string) (*ReleaseInfo, error)
	ListAll() ([]ReleaseInfo, error)
}) {
	s.releaseMgr = mgr
}

// ListenAndServe starts both HTTP and Unix socket listeners.
// Only serves /ws for WebSocket upgrade — no REST endpoints.
func (s *Server) ListenAndServe() error {
	mux := http.NewServeMux()
	mux.HandleFunc("/ws", s.handleWebSocket)
	mux.HandleFunc("/rpc", s.handleJSONRPC) // JSON-RPC 2.0 — ADR-019

	handler := s.withLogging(mux)

	// Unix socket
	if s.cfg.UnixSocket != "" {
		os.Remove(s.cfg.UnixSocket)
		unixListener, err := net.Listen("unix", s.cfg.UnixSocket)
		if err != nil {
			return fmt.Errorf("server: unix socket %s: %w", s.cfg.UnixSocket, err)
		}
		if err := os.Chmod(s.cfg.UnixSocket, 0660); err != nil {
			return fmt.Errorf("server: chmod %s: %w", s.cfg.UnixSocket, err)
		}
		s.unixServer = &http.Server{Handler: handler}
		s.logger.Info("ws unix socket listening", "socket", s.cfg.UnixSocket)
		go func() {
			if err := s.unixServer.Serve(unixListener); err != nil && err != http.ErrServerClosed {
				s.logger.Error("unix socket error", "err", err)
			}
		}()
	}

	// HTTP (solo WebSocket upgrade en /ws)
	if s.cfg.HTTPPort > 0 {
		addr := fmt.Sprintf(":%d", s.cfg.HTTPPort)
		s.httpServer = &http.Server{
			Addr:         addr,
			Handler:      handler,
			ReadTimeout:  15 * time.Second,
			WriteTimeout: 60 * time.Second,
			IdleTimeout:  120 * time.Second,
		}
		s.logger.Info("ws http server listening", "addr", addr)
		return s.httpServer.ListenAndServe()
	}

	// Block on unix socket if no HTTP port
	if s.unixServer != nil {
		select {}
	}
	return nil
}

// Shutdown gracefully stops both servers.
func (s *Server) Shutdown() {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if s.httpServer != nil {
		s.httpServer.Shutdown(ctx)
	}
	if s.unixServer != nil {
		s.unixServer.Shutdown(ctx)
	}
	s.logger.Info("ws server shut down")
}

func (s *Server) withLogging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		s.logger.Debug("request", "method", r.Method, "path", r.URL.Path, "duration", time.Since(start))
	})
}
