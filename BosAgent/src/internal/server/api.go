// Package server implements the bos WebSocket API over Unix socket and HTTP.
// Fase B: toda la comunicación es vía WebSocket (request/response + eventos).
// No se exponen endpoints REST — solo /ws para upgrade WebSocket.
//
// Modes:
//   - Normal: WebSocket API completa
//   - Config-pending: WebSocket con acciones limitadas (solo install_config)
package server

import (
	"context"
	"crypto/tls"

	"net"
	"fmt"
	"encoding/json"
	"net/http"
	"os"
	"strings"
	"os/user"
	"strconv"
	"sync"
	"time"

	bosctx "bos/internal/context"
	"bos/internal/domain"
	"bos/internal/installer"
	"bos/internal/paths"
	"bos/internal/maintenance"
	"bos/internal/metrics"
	"bos/internal/plugin"
	"bos/internal/query"
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
	Reload() int
}

// HealthChecker es la interfaz para consultar el estado de salud de las fichas.
// TODO(F9): definir métodos CheckPodHealth, CheckNodeHealth, CheckServiceHealth
// cuando el Operator K8s provea health checks nativos del cluster.
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

// K8sScanner dispara un descubrimiento de estado K8s bajo demanda y aplica
// los resultados al state manager. Implementado por reconcile.K8sScanAdapter.
// Nil-safe: si no se inyecta, bos.ficha.rescan solo recarga el catálogo.
type K8sScanner interface {
	Scan() (probed, skipped, errors int)
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

// Server gestiona los servidores WebSocket (HTTP en :9443 y Unix socket).
//
// Thread safety: mu protege el estado de shutdown. Los handlers WebSocket se
// ejecutan en goroutines distintas — acceden a los servicios de dominio que
// tienen su propia sincronización interna.
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
	bosCtxSvc    *bosctx.Service           // Context Plane + Create/Validate (M-14, SBOS-049)
	pgAuxSvc     *domain.PgAuxiliarService // PG Auxiliar (Parte V-B)
	k8sQuerier   *query.K8sQuerier         // dispatch kubectl vía k8s.Core (M-15 — SetK8sQuerier)
	k8sOp        K8sOperator               // Operator Soberano (F9.5 — SetK8sOperator)
	k8sScanner   K8sScanner                // descubrimiento on-demand (SetK8sScanner)
	maintSvc     *maintenance.Service      // sagas de mantenimiento (F9.6 — SetMaintenanceService)
	metrics      *metrics.Registry         // métricas Prometheus (F9.7 — SetMetrics, nil-safe)
	aiAgent      AIAgent                   // agente biaos (F10.8 — SetAIAgent, nil-safe)
		releaseMgr   ReleaseChecker // SKULL Release Plane — pull-only, verificación Ed25519

	httpServer *http.Server
	unixServer *http.Server
	logger     *slog.Logger
	wsHub      *Hub

	// ShutdownCh is closed when the daemon receives a shutdown request via WS.
	ShutdownCh chan struct{}
}

// Config define los parámetros de transporte del servidor WebSocket.
// El servidor escucha en Unix socket (/run/bos/bos.sock) por defecto (SBOS-050 P9).
// Si HTTPPort > 0, también expone HTTPS en 0.0.0.0:<puerto> para Kong y readiness probes.
//
// Nota: las etiquetas JSON usan snake_case — intencional para compatibilidad directa
// con los archivos bos.toml y bos-install.toml (TOML usa snake_case por convención).
type Config struct {
	HTTPPort         int           `json:"http_port"`                    // puerto HTTPS (0 = solo Unix socket)
	UnixSocket       string        `json:"unix_socket"`                  // ruta del socket Unix (default: /run/bos/bos.sock)
	Version          string        `json:"version,omitempty"`            // versión del daemon, inyectable via -ldflags
	HTTPReadTimeout  time.Duration `json:"http_read_timeout,omitempty"`  // default 2s
	HTTPWriteTimeout time.Duration `json:"http_write_timeout,omitempty"` // default 2s
	HTTPIdleTimeout  time.Duration `json:"http_idle_timeout,omitempty"`  // default 30s
}

// NewServer crea el servidor en modo normal (API WebSocket completa).
//
// Callers conocidos:
//   - cmd/bos/main.go:runNormal — paso 7.
//
// Efectos secundarios: inicia la goroutine wsHub.Run().
//
// Estándares: ADR-019, ADR-020 — Interface Dual obligatoria.
func NewServer(cfg Config, stateMgr StateManager, plugins PluginLoader, healthCheck HealthChecker, installer Installer, rbac security.RBACProvider, identity security.IdentityProvider, logger *slog.Logger, pgAuxSvc *domain.PgAuxiliarService, ctxSvc *bosctx.Service) *Server {
	if ctxSvc == nil {
		ctxSvc = bosctx.NewServiceWithMemStore()
	}
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
		fichaSvc:     domain.NewFichaService(installer, stateMgr, plugins),
		bootstrapSvc: domain.NewBootstrapService(stateMgr),
		bosCtxSvc:    ctxSvc,
		pgAuxSvc:     pgAuxSvc,
	}

	go s.wsHub.Run()
	return s
}

// NewConfigPendingServer crea el servidor en modo config-pending (staged):
// solo acepta la acción install_config hasta que bos-install.toml exista.
//
// Callers conocidos:
//   - cmd/bos/main.go:runConfigPending — cuando bos-install.toml falta.
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

// AutoMigrateContextPlane ejecuta el DDL del Context Plane (F10.B.12, M1.5).
// Verifica bos.registered_device + bos.context_session en sbos_db (schema bos).
// Con memStore es no-op. Con PGRedisStore verifica existencia (DDL_bos_schema.sql).
func (s *Server) AutoMigrateContextPlane(ctx context.Context) error {
	return s.bosCtxSvc.AutoMigrate(ctx)
}

// SetReleaseManager inyecta el Release Checker del SKULL Release Plane (ADR-019).
// El ReleaseChecker consulta periódicamente al Release Server de SKULL para detectar
// actualizaciones disponibles de fichas, verificando firma Ed25519 + SHA-256.
// Canales: canary → early → stable. Pull-only — BOS nunca escribe en el Release Plane.
func (s *Server) SetReleaseManager(mgr ReleaseChecker) {
	s.releaseMgr = mgr
}

// SetK8sScanner inyecta el scanner de estado K8s para descubrimiento on-demand.
// Llamado por bos.ficha.rescan para actualizar el state manager con estado K8s real
// sin esperar el próximo ciclo de reconciliación (300s).
func (s *Server) SetK8sScanner(sc K8sScanner) {
	s.k8sScanner = sc
}

// SetK8sQuerier inyecta el K8sQuerier que despacha operaciones kubectl vía k8s.Core.
// Debe llamarse justo después de NewServer cuando el Core está disponible (run_normal.go).
// Sin inyección, las fuentes de consulta usan exec directo (degradado seguro).
func (s *Server) SetK8sQuerier(q *query.K8sQuerier) {
	s.k8sQuerier = q
}

// handleContextLookup responde a GET /api/v1/context/{ctx_id} para Kong (C-5).
// Retorna 200 con datos del contexto si es valido, 404 si no existe o expiro.
// Solo acepta GET — escritura sigue en Unix socket JSON-RPC.
//
// Seguridad (SBOS-054 §7, §10):
//   - UUID v4 strict validation (SAN-09): rechazar cualquier formato no-UUID
//   - X-SBOS-Source header requerido (SAN-12): solo Kong autorizado
//   - Anti-enumeration: misma respuesta para "no encontrado" y "expirado"
//   - Response mínimo (NRS-06): solo ctx_id, tenant_id, bitmask, ttl_s, loa
func (s *Server) handleContextLookup(w http.ResponseWriter, r *http.Request) {
	// Solo GET — el método más restrictivo (SBOS-054 §7.3)
	if r.Method != http.MethodGet {
		writeContextJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	// Validar header X-SBOS-Source (SAN-12, SBOS-054 §7.2)
	if r.Header.Get("X-SBOS-Source") != "kong" {
		writeContextJSON(w, http.StatusForbidden, map[string]string{"error": "forbidden"})
		return
	}

	// Extraer ctx_id del path
	ctxID := strings.TrimPrefix(r.URL.Path, "/api/v1/context/")
	if ctxID == "" || ctxID == "health" {
		writeContextJSON(w, http.StatusBadRequest, map[string]string{"error": "missing ctx_id"})
		return
	}

	// UUID v4 strict validation (SAN-09, SBOS-054 §10.3)
	if !isValidUUIDv4(ctxID) {
		writeContextJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid ctx_id format"})
		return
	}

	// Buscar en Context Service (Redis cache-first → PostgreSQL)
	ctx, err := s.bosCtxSvc.Get(ctxID)
	if err != nil {
		// Anti-enumeration: misma respuesta para "no encontrado" y "expirado"
		// SBOS-054 §8.3: no revelar si el ID existe o no
		writeContextJSON(w, http.StatusNotFound, map[string]interface{}{
			"valid":  false,
			"ctx_id": ctxID,
			"error":  "not_found_or_expired",
		})
		return
	}

	// Response mínimo (NRS-06): solo campos que Kong necesita
	// Nunca exponer: user_id, session_kc, datos de infraestructura
	writeContextJSON(w, http.StatusOK, map[string]interface{}{
		"valid":     true,
		"ctx_id":    ctx.CtxID,
		"tenant_id": ctx.TenantID,
		"bitmask":   fmt.Sprintf("0x%X", uint64(ctx.BitMask)),
		"ttl_s":     max(0, int64(time.Until(ctx.ExpiresAt).Seconds())),
		"loa":       int(ctx.LoA),
	})
}

// isValidUUIDv4 verifica que s sea un UUID versión 4 válido (SAN-09).
func isValidUUIDv4(s string) bool {
	if len(s) != 36 {
		return false
	}
	// Formato: 8-4-4-4-12 hex chars
	if s[8] != '-' || s[13] != '-' || s[18] != '-' || s[23] != '-' {
		return false
	}
	// Versión 4: posición 14 debe ser '4'
	if s[14] != '4' {
		return false
	}
	// Variant: posición 19 debe ser '8','9','a','b'
	switch s[19] {
	case '8', '9', 'a', 'b', 'A', 'B':
	default:
		return false
	}
	// Verificar hex chars
	for i, c := range s {
		if i == 8 || i == 13 || i == 18 || i == 23 {
			continue
		}
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
			return false
		}
	}
	return true
}

// writeJSON escribe una respuesta JSON con el status code dado.
func writeContextJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

// ListenAndServe starts both HTTP and Unix socket listeners.
// Only serves /ws for WebSocket upgrade — no REST endpoints.
func (s *Server) ListenAndServe() error {
	mux := http.NewServeMux()
	mux.HandleFunc("/ws", s.handleWebSocket)
	mux.HandleFunc("/rpc", s.handleJSONRPC) // JSON-RPC 2.0 — ADR-019
	mux.HandleFunc("/api/v1/context/", s.handleContextLookup) // C-5: Kong ctx_id validation

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
		// Dar acceso al grupo bosagent. Si no existe, falla silencioso.
		if grp, err := user.LookupGroup("bosagent"); err == nil {
			if gid, err := strconv.Atoi(grp.Gid); err == nil {
				_ = os.Chown(s.cfg.UnixSocket, -1, gid)
			}
		}
		wsServer := &http.Server{Handler: handler}
		s.unixServer = wsServer
		s.logger.Info("unix dual socket (Vía1=WS Vía2=JSON-RPC)", "socket", s.cfg.UnixSocket)
		go s.listenUnixDual(unixListener, wsServer)
	}

	// HTTP :9443 — Context API para Kong (C-5) + WebSocket + JSON-RPC
	// SBOS-054 §7.5: TLS 1.3 obligatorio, cipher suites restrictivas, timeouts anti-slowloris
	if s.cfg.HTTPPort > 0 {
		addr := fmt.Sprintf(":%d", s.cfg.HTTPPort)
		// M-05: timeouts configurables desde Config, con defaults anti-slowloris (SBOS-054 §7.5)
		readTimeout := s.cfg.HTTPReadTimeout
		if readTimeout == 0 {
			readTimeout = 2 * time.Second
		}
		writeTimeout := s.cfg.HTTPWriteTimeout
		if writeTimeout == 0 {
			writeTimeout = 2 * time.Second
		}
		idleTimeout := s.cfg.HTTPIdleTimeout
		if idleTimeout == 0 {
			idleTimeout = 30 * time.Second
		}
		s.httpServer = &http.Server{
			Addr:         addr,
			Handler:      handler,
			ReadTimeout:  readTimeout,
			WriteTimeout: writeTimeout,
			IdleTimeout:  idleTimeout,
		}

		// TLS 1.3 con cipher suites restrictivas (NRS-01, SBOS-054 §7.5)
		certFile := paths.CertFile
		keyFile := paths.KeyFile
		if _, err := os.Stat(certFile); err == nil {
			if _, err := os.Stat(keyFile); err == nil {
				s.httpServer.TLSConfig = &tls.Config{
					MinVersion: tls.VersionTLS13,
					CipherSuites: []uint16{
						tls.TLS_AES_256_GCM_SHA384,
						tls.TLS_AES_128_GCM_SHA256,
					},
				}
				s.logger.Info("ws https server listening (TLS 1.3)", "addr", addr)
				return s.httpServer.ListenAndServeTLS(certFile, keyFile)
			}
		}

		// Fallback: HTTP sin TLS (modo dev, staging sin certificado aún)
		s.logger.Warn("ws http server listening (sin TLS — generar "+paths.CertFile+", "+paths.KeyFile+")", "addr", addr)
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
