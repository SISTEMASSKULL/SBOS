package server

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"bos/internal/security"

	"bos/internal/wslib"
	"log/slog"
)

// ── Event types (broadcast) ───────────────────────────────────────

type EventType string

const (
	EventSagaStart  EventType = "saga_start"
	EventSagaOK     EventType = "saga_ok"
	EventSagaFail   EventType = "saga_fail"
	EventStepStart  EventType = "step_start"
	EventStepOK     EventType = "step_ok"
	EventStepFail   EventType = "step_fail"
	EventHealth     EventType = "health_update"
	EventReload     EventType = "reload"
	EventReconcile  EventType = "reconcile"

	// Fase B — Identity
	EventIdentityConnected EventType = "identity_connected"
	EventIdentityChanged   EventType = "identity_changed"

	// PG Auxiliar Anti-Pérdida (Parte V-B)
	EventPgAuxiliarStart EventType = "pg_auxiliar_start"
	EventPgAuxiliarStep  EventType = "pg_auxiliar_step"
	EventPgAuxiliarOK    EventType = "pg_auxiliar_ok"
	EventPgAuxiliarFail  EventType = "pg_auxiliar_fail"
	EventPgAuxiliarSync  EventType = "pg_auxiliar_sync"

	// SKULL Release Plane
	EventReleaseCheck     EventType = "release_check"
	EventReleaseAvailable EventType = "release_available"
	EventReleaseApplied   EventType = "release_applied"

	// Log en tiempo real desde scripts bash — para streaming al TUI
	EventFichaLog EventType = "ficha_log"
)

// Event is a broadcast message sent to all or specific clients.
type Event struct {
	Type      EventType   `json:"type"`
	Ficha     string      `json:"ficha,omitempty"`
	Step      string      `json:"step,omitempty"`
	Message   string      `json:"message,omitempty"`
	Timestamp time.Time   `json:"timestamp"`
	User      string      `json:"user,omitempty"`
	Role      string      `json:"role,omitempty"`
	Data      interface{} `json:"data,omitempty"`
}

// ── Request / Response (WebSocket RPC) ────────────────────────────

// Request is a client-to-server RPC call over WebSocket.
type Request struct {
	Type   string                 `json:"type"`   // "request"
	ID     string                 `json:"id"`     // correlation ID
	Action string                 `json:"action"` // operation name
	Params map[string]interface{} `json:"params,omitempty"`
}

// Response is a server-to-client RPC result over WebSocket.
type Response struct {
	Type  string      `json:"type"`            // "response"
	ID    string      `json:"id"`              // correlation ID
	OK    bool        `json:"ok"`              // success flag
	Data  interface{} `json:"data,omitempty"`  // result payload
	Error string      `json:"error,omitempty"` // error message
	Time  time.Time   `json:"time"`
}

// ── Client ─────────────────────────────────────────────────────────

type Client struct {
	hub      *Hub
	conn     *wslib.Conn
	send     chan []byte

	// Fase B — Identity
	User     string
	Role     string
	rbac     security.RBACProvider
	identity security.IdentityProvider
}

// Hub manages all active WebSocket clients and event broadcasting.
type Hub struct {
	mu         sync.RWMutex
	clients    map[*Client]bool
	broadcast  chan []byte
	register   chan *Client
	unregister chan *Client
	logger     *slog.Logger
}

func NewHub(logger *slog.Logger) *Hub {
	return &Hub{
		clients:    make(map[*Client]bool),
		broadcast:  make(chan []byte, 256),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		logger:     logger,
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			count := len(h.clients)
			h.mu.Unlock()
			h.logger.Debug("ws client connected", "clients", count, "user", client.User)

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
			}
			count := len(h.clients)
			h.mu.Unlock()
			h.logger.Debug("ws client disconnected", "clients", count, "user", client.User)

		case message := <-h.broadcast:
			h.mu.RLock()
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					close(client.send)
					delete(h.clients, client)
				}
			}
			h.mu.RUnlock()
		}
	}
}

func (h *Hub) Broadcast(event Event) {
	event.Timestamp = time.Now()
	data, err := json.Marshal(event)
	if err != nil {
		h.logger.Error("ws: failed to marshal event", "err", err)
		return
	}
	h.broadcast <- data
}

func (h *Hub) BroadcastTo(client *Client, event Event) {
	event.Timestamp = time.Now()
	data, err := json.Marshal(event)
	if err != nil {
		h.logger.Error("ws: failed to marshal event", "err", err)
		return
	}
	select {
	case client.send <- data:
	default:
	}
}

func (h *Hub) sendResponse(client *Client, id string, ok bool, data interface{}, errMsg string) {
	resp := Response{
		Type: "response",
		ID:   id,
		OK:   ok,
		Data: data,
		Error: errMsg,
		Time: time.Now(),
	}
	payload, _ := json.Marshal(resp)
	select {
	case client.send <- payload:
	default:
	}
}

func (h *Hub) ClientCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

// ── WebSocket upgrade ──────────────────────────────────────────────

func (s *Server) handleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := wslib.Upgrade(w, r)
	if err != nil {
		s.logger.Debug("ws upgrade skipped (non-WebSocket client)", "err", err)
		http.Error(w, "WebSocket upgrade required", http.StatusBadRequest)
		return
	}

	user := r.Header.Get("BOS-User")
	role := ""
	if user != "" && s.rbac != nil {
		role = s.rbac.GetRole(user)
	}

	client := &Client{
		hub:      s.wsHub,
		conn:     conn,
		send:     make(chan []byte, 64),
		User:     user,
		Role:     role,
		rbac:     s.rbac,
		identity: s.identity,
	}

	s.wsHub.register <- client

	if user != "" {
		s.wsHub.BroadcastTo(client, Event{
			Type:    EventIdentityConnected,
			User:    user,
			Role:    role,
			Message: "identity resolved",
		})
	}

	go s.wsWritePump(client)
	go s.wsReadPump(client)
}

func (s *Server) wsWritePump(client *Client) {
	defer func() {
		client.conn.Close()
		s.wsHub.unregister <- client
	}()

	for message := range client.send {
		if err := client.conn.WriteMessage(1, message); err != nil {
			s.logger.Debug("ws write error", "err", err)
			return
		}
	}
}

func (s *Server) wsReadPump(client *Client) {
	defer func() {
		client.conn.Close()
		s.wsHub.unregister <- client
	}()

	for {
		_, msg, err := client.conn.ReadMessage()
		if err != nil {
			if wslib.IsUnexpectedCloseError(err) {
				s.logger.Debug("ws read error", "err", err)
			}
			break
		}

		// Try request envelope first
		var req Request
		if err := json.Unmarshal(msg, &req); err == nil && req.Type == "request" {
			s.dispatchRequest(client, &req)
			continue
		}

		// Legacy event envelope (ping, identity_*)
		var event Event
		if err := json.Unmarshal(msg, &event); err != nil {
			s.logger.Debug("ws: unparseable message", "err", err)
			continue
		}

		switch event.Type {
		case "ping":
			s.wsHub.BroadcastTo(client, Event{Type: "pong"})
		case "identity_whoami":
			s.handleWSIdentityWhoami(client)
		case "identity_list_users":
			s.handleWSIdentityListUsers(client)
		case "identity_list_roles":
			s.handleWSIdentityListRoles(client)
		case "identity_set_role":
			s.handleWSIdentitySetRole(client, event)
		case "identity_revoke":
			s.handleWSIdentityRevoke(client, event)
		default:
			s.logger.Debug("ws: unknown event type", "type", string(event.Type))
		}
	}
}

// ── Request dispatcher ─────────────────────────────────────────────

func (s *Server) dispatchRequest(client *Client, req *Request) {
	switch req.Action {
	case "health":
		s.wsHandleHealth(client, req)
	case "status":
		s.wsHandleStatus(client, req)
	case "install_config":
		s.wsHandleInstallConfig(client, req)
	case "fichas_list":
		s.wsHandleFichasList(client, req)
	case "ficha_detail":
		s.wsHandleFichaDetail(client, req)
	case "ficha_install":
		s.wsHandleFichaInstall(client, req)
	case "ficha_update":
		s.wsHandleFichaUpdate(client, req)
	case "ficha_repair":
		s.wsHandleFichaRepair(client, req)
	case "ficha_remove":
		s.wsHandleFichaRemove(client, req)
	case "ficha_probe":
		s.wsHandleFichaProbe(client, req)
	case "ficha_log_tail":
		s.wsHandleFichaLogTail(client, req)
	case "shutdown":
		s.wsHandleShutdown(client, req)
	case "security_scan":
		s.wsHandleSecurityScan(client, req)
	case "security_audit":
		s.wsHandleSecurityAudit(client, req)

	// Bootstrap — motor de instalación 19 fichas (Iteración 1)
	case "bootstrap_start":
		s.wsHandleBootstrapStart(client, req)
	case "bootstrap_status":
		s.wsHandleBootstrapStatus(client, req)
	case "bootstrap_verify":
		s.wsHandleBootstrapVerify(client, req)
	case "bootstrap_resume":
		s.wsHandleBootstrapResume(client, req)
	case "bootstrap_reset":
		s.wsHandleBootstrapReset(client, req)

	case "release_check":
		s.wsHandleReleaseCheck(client, req)
	case "release_list":
		s.wsHandleReleaseList(client, req)

		case "pg_auxiliar_start":
			s.wsHandlePgAuxiliarStart(client, req)
		case "pg_auxiliar_sync":
			s.wsHandlePgAuxiliarSync(client, req)
		case "pg_auxiliar_status":
			s.wsHandlePgAuxiliarStatus(client, req)
		case "pg_auxiliar_cleanup":
			s.wsHandlePgAuxiliarCleanup(client, req)

	default:
		s.wsHub.sendResponse(client, req.ID, false, nil, "unknown action: "+req.Action)
	}
}

// ── WS Action Handlers ─────────────────────────────────────────────

func (s *Server) wsHandleHealth(client *Client, req *Request) {
	if s.configPending {
		s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
			"version": "0.1.0",
			"status":  "config_pending",
			"mode":    "staged",
			"message": "bos daemon waiting for bos-install.toml",
		}, "")
		return
	}
	s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
		"version":       "0.1.0",
		"status":        "running",
		"fichas_loaded": s.plugins.Count(),
	}, "")
}

func (s *Server) wsHandleStatus(client *Client, req *Request) {
	if s.configPending {
		s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
			"status":  "config_pending",
			"message": "Waiting for bos-install.toml",
		}, "")
		return
	}
	st, err := s.stateMgr.Read()
	if err != nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, "failed to read state: "+err.Error())
		return
	}
	s.wsHub.sendResponse(client, req.ID, true, st, "")
}

func (s *Server) wsHandleInstallConfig(client *Client, req *Request) {
	bodyStr, _ := req.Params["body"].(string)
	if bodyStr == "" {
		s.wsHub.sendResponse(client, req.ID, false, nil, "body is required")
		return
	}

	installPath := os.Getenv("BOS_INSTALL_TOML")
	if installPath == "" {
		installPath = "/etc/bos/bos-install.toml"
	}

	if err := os.WriteFile(installPath, []byte(bodyStr), 0600); err != nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, "failed to write: "+err.Error())
		return
	}

	s.logger.Info("bos-install.toml received via WS", "path", installPath)

	s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
		"message": "bos-install.toml written. Send SIGHUP or restart to apply.",
		"path":    installPath,
	}, "")
}

func (s *Server) wsHandleFichasList(client *Client, req *Request) {
	if s.configPending {
		s.wsHub.sendResponse(client, req.ID, false, nil, "config-pending mode")
		return
	}
	fichas := s.plugins.List()
	s.wsHub.sendResponse(client, req.ID, true, fichas, "")
}

func (s *Server) wsHandleFichaDetail(client *Client, req *Request) {
	if s.configPending {
		s.wsHub.sendResponse(client, req.ID, false, nil, "config-pending mode")
		return
	}
	fichaID, _ := req.Params["ficha"].(string)
	if fichaID == "" {
		s.wsHub.sendResponse(client, req.ID, false, nil, "ficha name required")
		return
	}

	_, ok := s.plugins.Get(fichaID)
	if !ok {
		s.wsHub.sendResponse(client, req.ID, false, nil, "ficha not found: "+fichaID)
		return
	}

	status, err := s.installer.Status(fichaID)
	if err != nil {
		status = err.Error()
	}

	s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
		"name":   fichaID,
		"status": status,
	}, "")
}

func (s *Server) wsHandleFichaInstall(client *Client, req *Request) {
	if s.configPending {
		s.wsHub.sendResponse(client, req.ID, false, nil, "config-pending mode")
		return
	}
	fichaID, _ := req.Params["ficha"].(string)
	version, _ := req.Params["version"].(string)
	if fichaID == "" {
		s.wsHub.sendResponse(client, req.ID, false, nil, "ficha name required")
		return
	}
	if version == "" {
		version = "latest"
	}

	s.wsHub.Broadcast(Event{Type: "saga_start", Ficha: fichaID, Message: "install starting"})

	result, err := s.installer.Install(fichaID, version)
	if err != nil {
		s.wsHub.Broadcast(Event{Type: "saga_fail", Ficha: fichaID, Message: err.Error()})
		s.wsHub.sendResponse(client, req.ID, false, nil, "install failed: "+err.Error())
		return
	}

	s.wsHub.Broadcast(Event{Type: "saga_ok", Ficha: fichaID, Message: "install complete"})
	s.wsHub.sendResponse(client, req.ID, true, result, "")
}

func (s *Server) wsHandleFichaUpdate(client *Client, req *Request) {
	if s.configPending {
		s.wsHub.sendResponse(client, req.ID, false, nil, "config-pending mode")
		return
	}
	fichaID, _ := req.Params["ficha"].(string)
	version, _ := req.Params["version"].(string)
	if fichaID == "" {
		s.wsHub.sendResponse(client, req.ID, false, nil, "ficha name required")
		return
	}

	s.wsHub.Broadcast(Event{Type: "saga_start", Ficha: fichaID, Message: "update starting"})

	result, err := s.installer.Update(fichaID, version)
	if err != nil {
		s.wsHub.Broadcast(Event{Type: "saga_fail", Ficha: fichaID, Message: err.Error()})
		s.wsHub.sendResponse(client, req.ID, false, nil, "update failed: "+err.Error())
		return
	}

	s.wsHub.Broadcast(Event{Type: "saga_ok", Ficha: fichaID, Message: "update complete"})
	s.wsHub.sendResponse(client, req.ID, true, result, "")
}

func (s *Server) wsHandleFichaRepair(client *Client, req *Request) {
	if s.configPending {
		s.wsHub.sendResponse(client, req.ID, false, nil, "config-pending mode")
		return
	}
	fichaID, _ := req.Params["ficha"].(string)
	if fichaID == "" {
		s.wsHub.sendResponse(client, req.ID, false, nil, "ficha name required")
		return
	}

	s.wsHub.Broadcast(Event{Type: "saga_start", Ficha: fichaID, Message: "repair starting"})

	result, err := s.installer.Repair(fichaID)
	if err != nil {
		s.wsHub.Broadcast(Event{Type: "saga_fail", Ficha: fichaID, Message: err.Error()})
		s.wsHub.sendResponse(client, req.ID, false, nil, "repair failed: "+err.Error())
		return
	}

	s.wsHub.Broadcast(Event{Type: "saga_ok", Ficha: fichaID, Message: "repair complete"})
	s.wsHub.sendResponse(client, req.ID, true, result, "")
}

func (s *Server) wsHandleFichaRemove(client *Client, req *Request) {
	if s.configPending {
		s.wsHub.sendResponse(client, req.ID, false, nil, "config-pending mode")
		return
	}
	fichaID, _ := req.Params["ficha"].(string)
	if fichaID == "" {
		s.wsHub.sendResponse(client, req.ID, false, nil, "ficha name required")
		return
	}

	s.wsHub.Broadcast(Event{Type: "saga_start", Ficha: fichaID, Message: "remove starting"})

	result, err := s.installer.Remove(fichaID)
	if err != nil {
		s.wsHub.Broadcast(Event{Type: "saga_fail", Ficha: fichaID, Message: err.Error()})
		s.wsHub.sendResponse(client, req.ID, false, nil, "remove failed: "+err.Error())
		return
	}

	s.wsHub.Broadcast(Event{Type: "saga_ok", Ficha: fichaID, Message: "remove complete"})
	s.wsHub.sendResponse(client, req.ID, true, result, "")
}

// wsHandleFichaLogTail envía las últimas N líneas del log de una ficha como eventos ficha_log.
// La TUI lo llama cuando detecta una ficha en INSTALANDO pero no tiene logs en memoria
// (caso: TUI conectó tarde y perdió los eventos anteriores).
func (s *Server) wsHandleFichaLogTail(client *Client, req *Request) {
	fichaID, _ := req.Params["ficha"].(string)
	if fichaID == "" {
		s.wsHub.sendResponse(client, req.ID, false, nil, "ficha requerida")
		return
	}
	nLines := 80
	if n, ok := req.Params["lines"].(float64); ok && int(n) > 0 {
		nLines = int(n)
	}

	logPath := "/var/log/bos/fichas/" + fichaID + ".log"
	data, err := os.ReadFile(logPath)
	if err != nil {
		s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{"lines": 0}, "")
		return
	}

	lines := strings.Split(strings.TrimRight(string(data), "\n"), "\n")
	if len(lines) > nLines {
		lines = lines[len(lines)-nLines:]
	}

	// Emitir cada línea como ficha_log hacia el cliente específico
	for _, line := range lines {
		if line == "" {
			continue
		}
		s.wsHub.BroadcastTo(client, Event{
			Type:    EventFichaLog,
			Ficha:   fichaID,
			Message: line,
		})
	}
	s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{"lines": len(lines)}, "")
}

func (s *Server) wsHandleFichaProbe(client *Client, req *Request) {
	if s.configPending {
		s.wsHub.sendResponse(client, req.ID, false, nil, "config-pending mode")
		return
	}
	fichaID, _ := req.Params["ficha"].(string)
	if fichaID == "" {
		s.wsHub.sendResponse(client, req.ID, false, nil, "ficha name required")
		return
	}

	result, err := s.installer.Probe(fichaID)
	if err != nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, "probe failed: "+err.Error())
		return
	}
	s.wsHub.sendResponse(client, req.ID, true, result, "")
}

func (s *Server) wsHandleShutdown(client *Client, req *Request) {
	s.logger.Info("shutdown requested via WebSocket", "user", client.User)
	close(s.ShutdownCh)
	s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
		"message": "shutdown initiated",
	}, "")
}

func (s *Server) wsHandleSecurityScan(client *Client, req *Request) {
	if s.configPending {
		s.wsHub.sendResponse(client, req.ID, false, nil, "config-pending mode: security scan not available")
		return
	}
	report := security.RunFullScan(s.rbac)
	s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
		"text":  security.FormatReport(report),
		"score": report.Summary.ScorePercent,
		"pass":  report.Summary.OverallPass,
		"total": report.Summary.OverallTotal,
	}, "")
}

func (s *Server) wsHandleSecurityAudit(client *Client, req *Request) {
	logPath := "/var/log/bos/audit.log"
	n := 50
	if v, ok := req.Params["n"].(float64); ok {
		n = int(v)
	}

	if _, err := os.Stat(logPath); os.IsNotExist(err) {
		s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
			"lines": []string{}, "count": 0, "message": "audit log not found",
		}, "")
		return
	}

	data, err := os.ReadFile(logPath)
	if err != nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, "cannot read audit log: "+err.Error())
		return
	}

	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	if n > len(lines) {
		n = len(lines)
	}
	if n <= 0 {
		s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
			"lines": []string{}, "count": 0,
		}, "")
		return
	}

	s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
		"lines": lines[len(lines)-n:],
		"count": len(lines),
	}, "")
}

// ── Fase B — Identity WS Handlers ──────────────────────────────────

func (s *Server) handleWSIdentityWhoami(client *Client) {
	if client.User == "" {
		s.wsHub.BroadcastTo(client, Event{
			Type:    "identity_whoami",
			Message: "unauthenticated — no BOS-User header",
		})
		return
	}
	s.wsHub.BroadcastTo(client, Event{
		Type: "identity_whoami",
		User: client.User,
		Role: client.Role,
	})
}

func (s *Server) handleWSIdentityListUsers(client *Client) {
	if client.identity == nil {
		s.wsHub.BroadcastTo(client, Event{
			Type:    "identity_list_users",
			Message: "identity provider not available",
		})
		return
	}
	users, err := client.identity.ListUsers()
	if err != nil {
		s.wsHub.BroadcastTo(client, Event{
			Type:    "identity_list_users",
			Message: err.Error(),
		})
		return
	}
	s.wsHub.BroadcastTo(client, Event{
		Type: "identity_list_users",
		Data: users,
	})
}

func (s *Server) handleWSIdentityListRoles(client *Client) {
	if client.identity == nil {
		s.wsHub.BroadcastTo(client, Event{
			Type:    "identity_list_roles",
			Message: "identity provider not available",
		})
		return
	}
	roles, err := client.identity.ListRoles()
	if err != nil {
		s.wsHub.BroadcastTo(client, Event{
			Type:    "identity_list_roles",
			Message: err.Error(),
		})
		return
	}
	s.wsHub.BroadcastTo(client, Event{
		Type: "identity_list_roles",
		Data: roles,
	})
}

func (s *Server) handleWSIdentitySetRole(client *Client, event Event) {
	if client.rbac != nil {
		if err := client.rbac.CanExecute(client.User, "identity set-role"); err != nil {
			s.wsHub.BroadcastTo(client, Event{
				Type:    "identity_set_role",
				Message: "access denied: " + err.Error(),
			})
			return
		}
	}
	if client.identity == nil {
		s.wsHub.BroadcastTo(client, Event{
			Type:    "identity_set_role",
			Message: "identity provider not available",
		})
		return
	}

	targetUser := event.User
	targetRole := event.Role
	if m, ok := event.Data.(map[string]interface{}); ok {
		if u, _ := m["user"].(string); u != "" {
			targetUser = u
		}
		if r, _ := m["role"].(string); r != "" {
			targetRole = r
		}
	}
	if targetUser == "" || targetRole == "" {
		s.wsHub.BroadcastTo(client, Event{
			Type:    "identity_set_role",
			Message: "user and role required",
		})
		return
	}

	if err := client.identity.SetRole(targetUser, targetRole); err != nil {
		s.wsHub.BroadcastTo(client, Event{
			Type:    "identity_set_role",
			Message: err.Error(),
		})
		return
	}

	s.wsHub.BroadcastTo(client, Event{
		Type:    "identity_set_role",
		User:    targetUser,
		Role:    targetRole,
		Message: "role assigned",
	})
	s.wsHub.Broadcast(Event{
		Type: EventIdentityChanged,
		User: targetUser,
		Role: targetRole,
	})
}

func (s *Server) handleWSIdentityRevoke(client *Client, event Event) {
	if client.rbac != nil {
		if err := client.rbac.CanExecute(client.User, "identity revoke"); err != nil {
			s.wsHub.BroadcastTo(client, Event{
				Type:    "identity_revoke",
				Message: "access denied: " + err.Error(),
			})
			return
		}
	}
	if client.identity == nil {
		s.wsHub.BroadcastTo(client, Event{
			Type:    "identity_revoke",
			Message: "identity provider not available",
		})
		return
	}

	targetUser := event.User
	if targetUser == "" {
		s.wsHub.BroadcastTo(client, Event{
			Type:    "identity_revoke",
			Message: "user required",
		})
		return
	}

	if err := client.identity.RemoveUser(targetUser); err != nil {
		s.wsHub.BroadcastTo(client, Event{
			Type:    "identity_revoke",
			Message: err.Error(),
		})
		return
	}

	s.wsHub.BroadcastTo(client, Event{
		Type:    "identity_revoke",
		User:    targetUser,
		Message: "user revoked",
	})
	s.wsHub.Broadcast(Event{
		Type: EventIdentityChanged,
		User: targetUser,
	})
}

// ── Error helpers ──────────────────────────────────────────────────

func wsError(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	fmt.Fprintf(w, `{"ok":false,"error":"%s","time":"%s"}`, msg, time.Now().Format(time.RFC3339))
}

// ── Release Plane WS Handlers ────────────────────────────────────────

func (s *Server) wsHandleReleaseCheck(client *Client, req *Request) {
	if s.releaseMgr == nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, "release manager not available")
		return
	}
	ficha, _ := req.Params["ficha"].(string)
	version, _ := req.Params["version"].(string)
	if ficha == "" {
		ficha = "*"
	}
	if version == "" {
		version = "0.0.0"
	}

	s.wsHub.Broadcast(Event{Type: EventReleaseCheck, Message: "checking for updates..."})
	releases, err := s.releaseMgr.CheckAvailable(ficha, version)
	if err != nil {
		s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
			"updates": []interface{}{}, "offline": true, "error": err.Error(),
		}, "")
		return
	}
	if len(releases) > 0 {
		latest := releases[0]
		s.wsHub.Broadcast(Event{
			Type:    EventReleaseAvailable,
			Ficha:   latest.Ficha,
			Message: fmt.Sprintf("%s %s available (channel: %s)", latest.Ficha, latest.Version, latest.Channel),
		})
	}
	s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
		"updates": releases, "count": len(releases), "offline": false,
	}, "")
}

func (s *Server) wsHandleReleaseList(client *Client, req *Request) {
	if s.releaseMgr == nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, "release manager not available")
		return
	}
	releases, err := s.releaseMgr.ListAll()
	if err != nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, err.Error())
		return
	}
	s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
		"releases": releases, "count": len(releases),
	}, "")
}

func (s *Server) wsHandlePgAuxiliarStart(client *Client, req *Request) {
	if s.pgAuxSvc == nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, "pg_auxiliar service not available")
		return
	}
	sourcePod, _ := req.Params["source_pod"].(string)
	sourceNS, _ := req.Params["source_ns"].(string)
	if sourcePod == "" { sourcePod = "postgresql-0" }
	if sourceNS == "" { sourceNS = "sbos-data" }

	result, err := s.pgAuxSvc.Start(sourcePod, sourceNS, nil)
	if err != nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, err.Error())
		return
	}
	s.wsHub.sendResponse(client, req.ID, true, result, "")
}

func (s *Server) wsHandlePgAuxiliarSync(client *Client, req *Request) {
	if s.pgAuxSvc == nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, "pg_auxiliar service not available")
		return
	}
	targetPod, _ := req.Params["target_pod"].(string)
	targetNS, _ := req.Params["target_ns"].(string)
	database, _ := req.Params["database"].(string)
	if targetPod == "" { targetPod = "postgresql-0" }
	if targetNS == "" { targetNS = "sbos-data" }
	if database == "" { database = "postgres" }

	result, err := s.pgAuxSvc.Sync(targetPod, targetNS, database)
	if err != nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, err.Error())
		return
	}
	s.wsHub.sendResponse(client, req.ID, true, result, "")
}

func (s *Server) wsHandlePgAuxiliarStatus(client *Client, req *Request) {
	if s.pgAuxSvc == nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, "pg_auxiliar service not available")
		return
	}
	s.wsHub.sendResponse(client, req.ID, true, s.pgAuxSvc.Status(), "")
}

func (s *Server) wsHandlePgAuxiliarCleanup(client *Client, req *Request) {
	if s.pgAuxSvc == nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, "pg_auxiliar service not available")
		return
	}
	if err := s.pgAuxSvc.Cleanup(); err != nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, err.Error())
		return
	}
	s.wsHub.sendResponse(client, req.ID, true, map[string]bool{"cleaned": true}, "")
}
