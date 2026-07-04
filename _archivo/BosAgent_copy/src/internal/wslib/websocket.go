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
	wsGUID    = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
	opText    = 1
	opClose   = 8
)

// Conn wraps a WebSocket connection with read/write methods.
type Conn struct {
	conn   net.Conn
	mu     sync.Mutex
	reader *bufio.Reader
}

// DialContext establishes a WebSocket connection via a custom dialer
// over the given address. The ctx parameter is ignored in this minimal
// implementation — use SetDeadline on the underlying net.Conn for timeouts.
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

// Upgrade upgrades an HTTP connection to WebSocket.
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

// ReadMessage reads a complete WebSocket message.
// Returns message type and payload. Only text frames supported.
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

// WriteMessage writes a WebSocket message. Only text messages (type 1) supported.
func (c *Conn) WriteMessage(msgType int, data []byte) error {
	if msgType != 1 {
		return fmt.Errorf("wslib: only text messages supported")
	}
	return c.writeFrame(opText, data, false)
}

// WriteJSON marshals v as JSON and sends it as a text frame.
func (c *Conn) WriteJSON(v interface{}) error {
	data, err := json.Marshal(v)
	if err != nil {
		return err
	}
	return c.WriteMessage(1, data)
}

// ReadJSON reads a text frame and unmarshals it into v.
func (c *Conn) ReadJSON(v interface{}) error {
	_, data, err := c.ReadMessage()
	if err != nil {
		return err
	}
	return json.Unmarshal(data, v)
}

// Close sends a close frame and terminates the connection.
func (c *Conn) Close() error {
	c.writeFrame(opClose, nil, false)
	return c.conn.Close()
}

// SetReadDeadline sets the deadline for read operations.
func (c *Conn) SetReadDeadline(t time.Time) error {
	return c.conn.SetReadDeadline(t)
}

// SetWriteDeadline sets the deadline for write operations.
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

// IsUnexpectedCloseError checks whether the error is a normal close.
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
