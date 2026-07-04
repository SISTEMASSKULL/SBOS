// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Package wslib provee una implementación WebSocket mínima para el daemon bos.
// Reemplaza gorilla/websocket eliminando la dependencia externa. Soporta
// text frames RFC 6455, handshake server/client, y dial sobre Unix socket.
//
// # Responsabilidades
//
//   - Servidor: Upgrade() para elevar HTTP → WebSocket (Conn desde net.Conn).
//   - Cliente: DialContext() para conectar vía dialer personalizado (TCP/Unix).
//   - Leer y escribir text frames con framing RFC 6455 (no binario, no fragmentado).
//   - Exponer WriteJSON()/ReadJSON() para el protocolo bosctl ↔ bos.
//
// # Fuera de alcance
//
//   - Binary frames, compression, permessage-deflate.
//   - Fragmentación de mensajes grandes (SBOS no envía payloads >1MB).
//   - Autenticación WebSocket — resuelta a nivel OS por el socket Unix.
//
// # Dependencias
//
//   - Solo stdlib Go: crypto/sha1, encoding/base64, net, net/http.
//
// # Callers principales
//
//   - internal/server/api.go — Upgrade() en el handler /ws.
//   - cmd/bosctl/app.go — DialContext() via Unix socket /run/bos/bos.sock.
//
// # Estándares y referencias
//
//   - RFC 6455 — The WebSocket Protocol.
//   - ADR-019 — Vía 1 WebSocket RPC para CLI y Core UI.
//   - SBOS-050 P9 — sin HTTP entre daemons; WebSocket sobre Unix socket.
//
// # Ejemplo de uso
//
//	// Servidor
//	conn, err := wslib.Upgrade(w, r)
//	msg, _ := conn.ReadMessage()
//
//	// Cliente
//	conn, err := wslib.DialContext(func() (net.Conn, error) {
//	    return net.Dial("unix", paths.UnixSocket)
//	})
package wslib
