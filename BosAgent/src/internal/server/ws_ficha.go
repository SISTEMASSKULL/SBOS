package server

// ws_ficha.go — Handlers de ciclo de vida de fichas (M-10, F6).

import (
	"os"

	"bos/internal/installer"
	"bos/internal/paths"
)

func (s *Server) wsHandleHealth(client *Client, req *Request) {
	if s.configPending {
		s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
			"version": s.daemonVersion(),
			"status":  "config_pending",
			"mode":    "staged",
			"message": "bos daemon waiting for bos-install.toml",
		}, "")
		return
	}
	s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
		"version":       s.daemonVersion(),
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
		installPath = paths.InstallToml
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
	if s.checkConfigPending(client, req.ID) {
		return
	}
	s.wsHub.sendResponse(client, req.ID, true, s.plugins.List(), "")
}

func (s *Server) wsHandleFichaDetail(client *Client, req *Request) {
	if s.checkConfigPending(client, req.ID) {
		return
	}
	fichaID, _ := req.Params["ficha"].(string)
	if fichaID == "" {
		s.wsHub.sendResponse(client, req.ID, false, nil, "ficha name required")
		return
	}
	if _, ok := s.plugins.Get(fichaID); !ok {
		s.wsHub.sendResponse(client, req.ID, false, nil, "ficha not found: "+fichaID)
		return
	}
	statusStr, err := s.installer.Status(fichaID)
	if err != nil {
		statusStr = err.Error()
	}
	s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
		"name": fichaID, "status": statusStr,
	}, "")
}

// checkConfigPending verifica si el daemon está en modo config-pending.
// Retorna true si la operación fue bloqueada — el caller debe hacer return inmediato.
func (s *Server) checkConfigPending(client *Client, reqID string) bool {
	if s.configPending {
		s.wsHub.sendResponse(client, reqID, false, nil, "config-pending mode")
		return true
	}
	return false
}

// wsHandleFichaOp unifica el patrón de los 4 handlers de ciclo de vida (install/update/repair/remove).
func (s *Server) wsHandleFichaOp(client *Client, req *Request, op string) {
	if s.checkConfigPending(client, req.ID) {
		return
	}
	fichaID, _ := req.Params["ficha"].(string)
	if fichaID == "" {
		s.wsHub.sendResponse(client, req.ID, false, nil, "ficha name required")
		return
	}
	version, _ := req.Params["version"].(string)
	if version == "" {
		version = "latest"
	}

	s.wsHub.Broadcast(Event{Type: EventSagaStart, Ficha: fichaID, Message: op + " starting"})

	var result *installer.SagaResult
	var err error
	switch op {
	case "install":
		result, err = s.installer.Install(fichaID, version)
	case "update":
		result, err = s.installer.Update(fichaID, version)
	case "repair":
		result, err = s.installer.Repair(fichaID)
	case "remove":
		result, err = s.installer.Remove(fichaID)
	default:
		s.wsHub.sendResponse(client, req.ID, false, nil, "operación desconocida: "+op)
		return
	}

	if err != nil {
		s.wsHub.Broadcast(Event{Type: EventSagaFail, Ficha: fichaID, Message: err.Error()})
		s.wsHub.sendResponse(client, req.ID, false, nil, op+" failed: "+err.Error())
		return
	}

	s.wsHub.Broadcast(Event{Type: EventSagaOK, Ficha: fichaID, Message: op + " complete"})
	s.wsHub.sendResponse(client, req.ID, true, result, "")
}

func (s *Server) wsHandleFichaInstall(client *Client, req *Request) { s.wsHandleFichaOp(client, req, "install") }
func (s *Server) wsHandleFichaUpdate(client *Client, req *Request)  { s.wsHandleFichaOp(client, req, "update") }
func (s *Server) wsHandleFichaRepair(client *Client, req *Request)  { s.wsHandleFichaOp(client, req, "repair") }
func (s *Server) wsHandleFichaRemove(client *Client, req *Request)  { s.wsHandleFichaOp(client, req, "remove") }
