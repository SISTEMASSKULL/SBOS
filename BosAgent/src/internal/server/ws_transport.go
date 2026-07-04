package server

// ws_transport.go — handleWebSocket, pumps, dispatchRequest, daemonVersion, wsError (M-10, F6).

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"bos/internal/wslib"
)

// handleWebSocket hace el upgrade HTTP→WebSocket y lanza las goroutines de lectura/escritura.
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
		send:     make(chan []byte, DefaultClientSendBuf),
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

		var req Request
		if err := json.Unmarshal(msg, &req); err == nil && req.Type == "request" {
			s.dispatchRequest(client, &req)
			continue
		}

		var event Event
		if err := json.Unmarshal(msg, &event); err != nil {
			s.logger.Debug("ws: unparseable message", "err", err)
			continue
		}

		switch event.Type {
		case "ping":
			s.wsHub.BroadcastTo(client, Event{Type: "pong"})
		case EventIdentityWhoami:
			s.handleWSIdentityWhoami(client)
		case EventIdentityListUsers:
			s.handleWSIdentityListUsers(client)
		case EventIdentityListRoles:
			s.handleWSIdentityListRoles(client)
		case EventIdentitySetRole:
			s.handleWSIdentitySetRole(client, event)
		case EventIdentityRevoke:
			s.handleWSIdentityRevoke(client, event)
		default:
			s.logger.Debug("ws: unknown event type", "type", string(event.Type))
		}
	}
}

// dispatchRequest enruta un Request WebSocket al handler correspondiente.
func (s *Server) dispatchRequest(client *Client, req *Request) {
	switch req.Action {
	case ActionHealth:
		s.wsHandleHealth(client, req)
	case ActionStatus:
		s.wsHandleStatus(client, req)
	case "install_config":
		s.wsHandleInstallConfig(client, req)
	case ActionFichaList:
		s.wsHandleFichasList(client, req)
	case ActionFichaDetail:
		s.wsHandleFichaDetail(client, req)
	case ActionFichaInstall:
		s.wsHandleFichaInstall(client, req)
	case ActionFichaUpdate:
		s.wsHandleFichaUpdate(client, req)
	case ActionFichaRepair:
		s.wsHandleFichaRepair(client, req)
	case ActionFichaRemove:
		s.wsHandleFichaRemove(client, req)
	case ActionFichaProbe:
		s.wsHandleFichaProbe(client, req)
	case ActionFichaLogTail:
		s.wsHandleFichaLogTail(client, req)
	case ActionShutdown:
		s.wsHandleShutdown(client, req)
	case ActionSecurityScan:
		s.wsHandleSecurityScan(client, req)
	case ActionSecurityAudit:
		s.wsHandleSecurityAudit(client, req)
	case ActionBootstrapStart:
		s.wsHandleBootstrapStart(client, req)
	case "bootstrap_status":
		s.wsHandleBootstrapStatus(client, req)
	case "bootstrap_verify":
		s.wsHandleBootstrapVerify(client, req)
	case "bootstrap_resume":
		s.wsHandleBootstrapResume(client, req)
	case "bootstrap_reset":
		s.wsHandleBootstrapReset(client, req)
	case ActionReleaseCheck:
		s.wsHandleReleaseCheck(client, req)
	case ActionReleaseList:
		s.wsHandleReleaseList(client, req)
	case ActionPgAuxStart:
		s.wsHandlePgAuxiliarStart(client, req)
	case ActionPgAuxSync:
		s.wsHandlePgAuxiliarSync(client, req)
	case ActionPgAuxStatus:
		s.wsHandlePgAuxiliarStatus(client, req)
	case ActionPgAuxCleanup:
		s.wsHandlePgAuxiliarCleanup(client, req)
	default:
		s.wsHub.sendResponse(client, req.ID, false, nil, "unknown action: "+req.Action)
	}
}

// daemonVersion retorna la versión del daemon desde Config, con fallback a la constante compilada.
func (s *Server) daemonVersion() string {
	if s.cfg.Version != "" {
		return s.cfg.Version
	}
	return DaemonVersion
}

// wsError envía un error HTTP con cuerpo JSON.
func wsError(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	fmt.Fprintf(w, `{"ok":false,"error":"%s","time":"%s"}`, msg, time.Now().Format(time.RFC3339))
}
