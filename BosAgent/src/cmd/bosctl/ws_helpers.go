// Package main — ws_helpers.go: tipos y helpers para comunicación con el daemon bos.
// Extraídos de main.go en F4.5 (BOS-REPAIR).
package main

import (
	"fmt"
	"os"
	"time"

	"bos/internal/wslib"
)

// wsResponse matches the server Response envelope over WebSocket.
type wsResponse struct {
	Type  string      `json:"type"`
	ID    string      `json:"id"`
	OK    bool        `json:"ok"`
	Data  interface{} `json:"data,omitempty"`
	Error string      `json:"error,omitempty"`
	Time  time.Time   `json:"time"`
}

// socketPath retorna la ruta al Unix socket del daemon (BOS_SOCKET > default).
func socketPath() string {
	if s := os.Getenv("BOS_SOCKET"); s != "" {
		return s
	}
	return defaultSocket
}

// wsRequest envía una solicitud al daemon bos vía WebSocket sobre Unix socket
// y retorna la respuesta parseada. Retorna error si el socket no está disponible (exit 6).
func wsRequest(action string, params map[string]interface{}) (*wsResponse, error) {
	socket := socketPath()
	conn, err := wslib.DialUnix(socket, 10*time.Second)
	if err != nil {
		return nil, fmt.Errorf("daemon not available at %s: %w", socket, err)
	}
	defer conn.Close()

	req := map[string]interface{}{
		"type":   "request",
		"id":     fmt.Sprintf("bosctl-%d", time.Now().UnixNano()),
		"action": action,
		"params": params,
	}

	conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
	if err := conn.WriteJSON(req); err != nil {
		return nil, fmt.Errorf("send request: %w", err)
	}

	conn.SetReadDeadline(time.Now().Add(30 * time.Second))
	var resp wsResponse
	if err := conn.ReadJSON(&resp); err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	if !resp.OK {
		return &resp, fmt.Errorf("%s", resp.Error)
	}
	return &resp, nil
}
