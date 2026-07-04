// Package wslib provides a minimal WebSocket implementation for bos.
// Replaces gorilla/websocket. Supports text frames + Unix socket dialing.
//
// Server: upgrade HTTP → WebSocket, read/write text frames.
// Client: dial over TCP/Unix, perform handshake, read/write text frames.
package wslib

import (
	"bufio"
	"crypto/rand"
	"crypto/sha1"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"
)

const (
	wsGUID  = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
	opText  = 1
	opClose = 8
)

// Conn envuelve una conexión WebSocket con métodos de lectura/escritura.
//
// Thread safety: WriteMessage/WriteJSON serializan escrituras con mu.Lock().
// ReadMessage/ReadJSON NO son seguros para uso concurrente (un lector a la vez).
type Conn struct {
	conn   net.Conn
	mu     sync.Mutex
	reader *bufio.Reader
}

// DialUnix conecta al daemon bos vía Unix socket con handshake WebSocket RFC 6455.
// timeout limita la fase de conexión + handshake (0 = sin límite).
//
// Callers conocidos:
//   - cmd/bosctl/main.go:wsRequest
//   - cmd/bosctl/install_ui.go:connectWS, RunAutoInstall
func DialUnix(socketPath string, timeout time.Duration) (*Conn, error) {
	return DialContext(func() (net.Conn, error) {
		if timeout > 0 {
			return net.DialTimeout("unix", socketPath, timeout)
		}
		return net.Dial("unix", socketPath)
	})
}

// DialContext establece una conexión WebSocket vía un dialer personalizado.
// El handshake sigue RFC 6455 §4.1.
//
// Recibe:
//   - netDial: func() (net.Conn, error) — dialer que crea la conexión TCP/Unix subyacente.
//
// Retorna: (*Conn, error). Error si el handshake falla o la clave Accept no coincide.
//
// Callers conocidos:
//   - cmd/bosctl/main.go:wsRequest — para conectar al Unix socket del daemon.
//
// Efectos secundarios: abre una conexión de red; el caller debe llamar Close().
func DialContext(netDial func() (net.Conn, error)) (*Conn, error) {
	conn, err := netDial()
	if err != nil {
		return nil, fmt.Errorf("wslib: dial: %w", err)
	}

	// Build WebSocket upgrade request
	key := make([]byte, 16)
	rand.Read(key)
	keyB64 := base64.StdEncoding.EncodeToString(key)

	req := fmt.Sprintf("GET /ws HTTP/1.1\r\n"+
		"Host: localhost\r\n"+
		"Upgrade: websocket\r\n"+
		"Connection: Upgrade\r\n"+
		"Sec-WebSocket-Key: %s\r\n"+
		"Sec-WebSocket-Version: 13\r\n"+
		"\r\n", keyB64)

	if _, err := conn.Write([]byte(req)); err != nil {
		conn.Close()
		return nil, fmt.Errorf("wslib: write handshake: %w", err)
	}

	// Read response
	resp, err := http.ReadResponse(bufio.NewReader(conn), nil)
	if err != nil {
		conn.Close()
		return nil, fmt.Errorf("wslib: read handshake: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusSwitchingProtocols {
		conn.Close()
		return nil, fmt.Errorf("wslib: upgrade rejected: %s", resp.Status)
	}

	// Verify accept key
	expectedAccept := computeAcceptKey(keyB64)
	if resp.Header.Get("Sec-WebSocket-Accept") != expectedAccept {
		conn.Close()
		return nil, fmt.Errorf("wslib: accept key mismatch")
	}

	return &Conn{conn: conn, reader: bufio.NewReader(conn)}, nil
}

// Upgrade eleva una conexión HTTP a WebSocket (handshake RFC 6455).
//
// Recibe:
//   - w: http.ResponseWriter — debe implementar http.Hijacker.
//   - r: *http.Request — solicitud con cabeceras Upgrade y Sec-WebSocket-Key.
//
// Retorna: *Conn lista para leer/escribir, o error si el handshake falla.
//
// Callers conocidos:
//   - internal/server/api.go — handler /ws.
//
// Efectos secundarios: hijackea la conexión TCP subyacente.
func Upgrade(w http.ResponseWriter, r *http.Request) (*Conn, error) {
	key := r.Header.Get("Sec-WebSocket-Key")
	if key == "" {
		return nil, fmt.Errorf("wslib: missing Sec-WebSocket-Key")
	}

	acceptKey := computeAcceptKey(key)

	hj, ok := w.(http.Hijacker)
	if !ok {
		return nil, fmt.Errorf("wslib: hijacker not available")
	}

	conn, bufrw, err := hj.Hijack()
	if err != nil {
		return nil, fmt.Errorf("wslib: hijack: %w", err)
	}

	resp := fmt.Sprintf("HTTP/1.1 101 Switching Protocols\r\n"+
		"Upgrade: websocket\r\n"+
		"Connection: Upgrade\r\n"+
		"Sec-WebSocket-Accept: %s\r\n"+
		"\r\n", acceptKey)

	if _, err := bufrw.WriteString(resp); err != nil {
		conn.Close()
		return nil, fmt.Errorf("wslib: write upgrade response: %w", err)
	}
	if err := bufrw.Flush(); err != nil {
		conn.Close()
		return nil, fmt.Errorf("wslib: flush upgrade: %w", err)
	}

	return &Conn{conn: conn, reader: bufrw.Reader}, nil
}

// ReadMessage lee un mensaje WebSocket completo.
// Solo text frames soportados; close frames retornan (0, nil, io.EOF).
//
// Efectos secundarios: consume bytes del lector subyacente.
func (c *Conn) ReadMessage() (int, []byte, error) {
	for {
		op, payload, err := c.readFrame()
		if err != nil {
			return 0, nil, err
		}
		switch op {
		case opText:
			return 1, payload, nil // websocket.TextMessage = 1
		case opClose:
			return 0, nil, io.EOF
		}
	}
}

// WriteMessage escribe un mensaje WebSocket. Solo tipo 1 (text) soportado.
//
// Efectos secundarios: escribe bytes en la conexión bajo mu.Lock().
func (c *Conn) WriteMessage(msgType int, data []byte) error {
	if msgType != 1 {
		return fmt.Errorf("wslib: only text messages supported")
	}
	return c.writeFrame(opText, data, false)
}

// WriteJSON serializa v como JSON y lo envía como un text frame.
//
// Efectos secundarios: escribe bytes en la conexión bajo mu.Lock().
func (c *Conn) WriteJSON(v interface{}) error {
	data, err := json.Marshal(v)
	if err != nil {
		return err
	}
	return c.WriteMessage(1, data)
}

// ReadJSON lee un text frame y lo deserializa en v.
func (c *Conn) ReadJSON(v interface{}) error {
	_, data, err := c.ReadMessage()
	if err != nil {
		return err
	}
	return json.Unmarshal(data, v)
}

// Close envía un close frame y termina la conexión.
//
// Efectos secundarios: escribe el frame de cierre y cierra el net.Conn subyacente.
func (c *Conn) Close() error {
	c.writeFrame(opClose, nil, false)
	return c.conn.Close()
}

// SetReadDeadline establece el deadline para operaciones de lectura.
func (c *Conn) SetReadDeadline(t time.Time) error {
	return c.conn.SetReadDeadline(t)
}

// SetWriteDeadline establece el deadline para operaciones de escritura.
func (c *Conn) SetWriteDeadline(t time.Time) error {
	return c.conn.SetWriteDeadline(t)
}

// readFrame reads a single WebSocket frame.
func (c *Conn) readFrame() (opcode byte, payload []byte, err error) {
	header := make([]byte, 2)
	if _, err := io.ReadFull(c.reader, header); err != nil {
		return 0, nil, err
	}

	opcode = header[0] & 0x0F
	masked := header[1]&0x80 != 0
	length := uint64(header[1] & 0x7F)

	switch {
	case length == 126:
		ext := make([]byte, 2)
		if _, err := io.ReadFull(c.reader, ext); err != nil {
			return 0, nil, err
		}
		length = uint64(binary.BigEndian.Uint16(ext))
	case length == 127:
		ext := make([]byte, 8)
		if _, err := io.ReadFull(c.reader, ext); err != nil {
			return 0, nil, err
		}
		length = binary.BigEndian.Uint64(ext)
	}

	var maskKey [4]byte
	if masked {
		if _, err := io.ReadFull(c.reader, maskKey[:]); err != nil {
			return 0, nil, err
		}
	}

	payload = make([]byte, length)
	if _, err := io.ReadFull(c.reader, payload); err != nil {
		return 0, nil, err
	}

	if masked {
		for i := range payload {
			payload[i] ^= maskKey[i%4]
		}
	}

	return opcode, payload, nil
}

// writeFrame writes a single WebSocket frame.
func (c *Conn) writeFrame(opcode byte, payload []byte, mask bool) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	fh := make([]byte, 2)
	fh[0] = 0x80 | opcode // FIN + opcode

	length := len(payload)
	switch {
	case length <= 125:
		fh[1] = byte(length)
	case length <= 65535:
		fh[1] = 126
	default:
		fh[1] = 127
	}

	if mask {
		fh[1] |= 0x80
	}

	if _, err := c.conn.Write(fh); err != nil {
		return err
	}

	switch {
	case length > 125 && length <= 65535:
		ext := make([]byte, 2)
		binary.BigEndian.PutUint16(ext, uint16(length))
		c.conn.Write(ext)
	case length > 65535:
		ext := make([]byte, 8)
		binary.BigEndian.PutUint64(ext, uint64(length))
		c.conn.Write(ext)
	}

	if mask {
		maskKey := make([]byte, 4)
		rand.Read(maskKey)
		c.conn.Write(maskKey)
		for i := range payload {
			payload[i] ^= maskKey[i%4]
		}
	}

	_, err := c.conn.Write(payload)
	return err
}

func computeAcceptKey(key string) string {
	h := sha1.New()
	h.Write([]byte(key + wsGUID))
	return base64.StdEncoding.EncodeToString(h.Sum(nil))
}

// IsUnexpectedCloseError retorna true si el error representa un cierre inesperado
// (no un cierre limpio o EOF normal). Compatible con gorilla/websocket.
func IsUnexpectedCloseError(err error, codes ...int) bool {
	if err == nil || errors.Is(err, io.EOF) {
		return false
	}
	if strings.Contains(err.Error(), "closed") {
		return false
	}
	if strings.Contains(err.Error(), "EOF") {
		return false
	}
	return true
}
