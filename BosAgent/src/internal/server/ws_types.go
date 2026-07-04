package server

// ws_types.go — Tipos Event, Request, Response, Client, Hub (M-10, F6).

import (
	"log/slog"
	"sync"
	"time"

	"bos/internal/security"
	"bos/internal/wslib"
)

// Event es un mensaje de difusión (broadcast) enviado a todos los clientes conectados
// o a un cliente específico. Representa eventos del ciclo de vida de fichas, cambios
// de identidad, progreso de sagas, y logs en tiempo real desde scripts bash.
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

// Request es una llamada RPC del cliente al servidor sobre WebSocket.
// Cada request lleva un ID de correlación para emparejar con su Response.
type Request struct {
	Type   string                 `json:"type"`
	ID     string                 `json:"id"`
	Action string                 `json:"action"`
	Params map[string]interface{} `json:"params,omitempty"`
}

// Response es el resultado RPC del servidor al cliente sobre WebSocket.
type Response struct {
	Type  string      `json:"type"`
	ID    string      `json:"id"`
	OK    bool        `json:"ok"`
	Data  interface{} `json:"data,omitempty"`
	Error string      `json:"error,omitempty"`
	Time  time.Time   `json:"time"`
}

// Client representa una conexión WebSocket activa con identidad resuelta.
//
// Thread safety: send es un canal buffered (64 mensajes). Un solo lector (wsReadPump)
// y un solo escritor (wsWritePump) por Client — sin acceso concurrente al conn.
type Client struct {
	hub  *Hub
	conn *wslib.Conn
	send chan []byte

	// Fase B — Identity
	User     string
	Role     string
	rbac     security.RBACProvider
	identity security.IdentityProvider
}

// Hub gestiona todos los clientes WebSocket activos y el broadcast de eventos.
//
// Thread safety: mu (RWMutex) protege el mapa de clients.
// Broadcast/BroadcastTo son seguros para llamar desde cualquier goroutine.
type Hub struct {
	mu         sync.RWMutex
	clients    map[*Client]bool
	broadcast  chan []byte
	register   chan *Client
	unregister chan *Client
	logger     *slog.Logger
}
