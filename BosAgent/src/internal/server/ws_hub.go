package server

// ws_hub.go — Hub: New, Run, Broadcast, BroadcastTo, sendResponse, ClientCount (M-10, F6).

import (
	"encoding/json"
	"log/slog"
	"time"
)

// NewHub crea un Hub con sus canales internos inicializados.
func NewHub(logger *slog.Logger) *Hub {
	return &Hub{
		clients:    make(map[*Client]bool),
		broadcast:  make(chan []byte, DefaultBroadcastBuf),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		logger:     logger,
	}
}

// Run inicia el loop selector del Hub. Bloquea hasta que el proceso termine.
// Cierra client.send al desregistrar — wsWritePump termina limpiamente.
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

// Broadcast serializa un Event como JSON y lo envía a todos los clientes conectados.
func (h *Hub) Broadcast(event Event) {
	event.Timestamp = time.Now()
	data, err := json.Marshal(event)
	if err != nil {
		h.logger.Error("ws: failed to marshal event", "err", err)
		return
	}
	h.broadcast <- data
}

// BroadcastTo envía un Event a un cliente específico (sin esperar si el canal está lleno).
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

// sendResponse envía una respuesta RPC al cliente WebSocket. Llamado por todos los handlers (30+).
func (h *Hub) sendResponse(client *Client, id string, ok bool, data interface{}, errMsg string) {
	resp := Response{
		Type:  "response",
		ID:    id,
		OK:    ok,
		Data:  data,
		Error: errMsg,
		Time:  time.Now(),
	}
	payload, _ := json.Marshal(resp)
	select {
	case client.send <- payload:
	default:
	}
}

// ClientCount retorna el número de clientes WebSocket actualmente conectados.
func (h *Hub) ClientCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}
