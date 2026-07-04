package server

// ws_system.go — Handlers de sistema: log tail, probe, shutdown, security scan/audit (M-10, F6).

import (
	"os"
	"strings"

	"bos/internal/paths"
	"bos/internal/security"
)

// wsHandleFichaLogTail envía las últimas N líneas del log de una ficha como eventos ficha_log.
// La TUI lo llama cuando detecta una ficha en INSTALANDO pero no tiene logs en memoria
// (caso: TUI conectó tarde y perdió los eventos anteriores).
func (s *Server) wsHandleFichaLogTail(client *Client, req *Request) {
	fichaID, _ := req.Params["ficha"].(string)
	if fichaID == "" {
		s.wsHub.sendResponse(client, req.ID, false, nil, "ficha requerida")
		return
	}
	nLines := DefaultLogTailLines
	if n, ok := req.Params["lines"].(float64); ok && int(n) > 0 {
		nLines = int(n)
	}

	logPath := paths.LogFile("fichas/" + fichaID + ".log")
	data, err := os.ReadFile(logPath)
	if err != nil {
		s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{"lines": 0}, "")
		return
	}

	lines := strings.Split(strings.TrimRight(string(data), "\n"), "\n")
	if len(lines) > nLines {
		lines = lines[len(lines)-nLines:]
	}

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
	if s.checkConfigPending(client, req.ID) {
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
	if s.checkConfigPending(client, req.ID) {
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
	logPath := paths.AuditLog
	n := DefaultAuditTailLines
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
