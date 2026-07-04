package context

// redis_client.go — mini-cliente Redis RESP2 sin dependencias externas.
//
// Implementa RedisClient usando solo la biblioteca estándar de Go (net).
// Solo los 4 comandos que necesita el Context Plane: SET (con EX), GET, DEL, EXISTS.
// Conexión por demanda con reconexión automática en cada operación.
//
// No es un cliente Redis general — es el mínimo viable para el Context Plane.

import (
	"bufio"
	"errors"
	"fmt"
	"net"
	"strconv"
	"strings"
	"time"
)

// SimpleRedisClient implementa RedisClient con protocolo RESP2 sobre TCP.
type SimpleRedisClient struct {
	addr    string        // host:port (ej: "192.168.144.135:6379")
	db      int           // base de datos Redis (default 0)
	timeout time.Duration // timeout por operación
}

// NewSimpleRedisClient crea un cliente Redis mínimo.
// addr: "host:port", db: índice de base de datos, timeout: por operación.
func NewSimpleRedisClient(addr string, db int, timeout time.Duration) *SimpleRedisClient {
	if timeout == 0 {
		timeout = 3 * time.Second
	}
	return &SimpleRedisClient{addr: addr, db: db, timeout: timeout}
}

// dial abre una conexión TCP a Redis y selecciona la base de datos.
func (c *SimpleRedisClient) dial() (net.Conn, *bufio.Reader, error) {
	conn, err := net.DialTimeout("tcp", c.addr, c.timeout)
	if err != nil {
		return nil, nil, fmt.Errorf("redis dial %s: %w", c.addr, err)
	}
	conn.SetDeadline(time.Now().Add(c.timeout))
	r := bufio.NewReader(conn)

	if c.db != 0 {
		if err := writeCmd(conn, "SELECT", strconv.Itoa(c.db)); err != nil {
			conn.Close()
			return nil, nil, fmt.Errorf("redis SELECT %d: %w", c.db, err)
		}
		if _, err := readSimpleString(r); err != nil {
			conn.Close()
			return nil, nil, fmt.Errorf("redis SELECT %d resp: %w", c.db, err)
		}
	}
	return conn, r, nil
}

// Set escribe key→value en Redis con TTL opcional (0 = sin expiración).
func (c *SimpleRedisClient) Set(key string, value []byte, ttl time.Duration) error {
	conn, r, err := c.dial()
	if err != nil {
		return err
	}
	defer conn.Close()

	if ttl > 0 {
		secs := strconv.FormatInt(int64(ttl.Seconds()), 10)
		if err := writeCmd(conn, "SET", key, string(value), "EX", secs); err != nil {
			return fmt.Errorf("redis SET: %w", err)
		}
	} else {
		if err := writeCmd(conn, "SET", key, string(value)); err != nil {
			return fmt.Errorf("redis SET: %w", err)
		}
	}
	_, err = readSimpleString(r)
	return err
}

// Get lee el valor de key. Retorna ErrRedisNil si no existe.
func (c *SimpleRedisClient) Get(key string) ([]byte, error) {
	conn, r, err := c.dial()
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	if err := writeCmd(conn, "GET", key); err != nil {
		return nil, fmt.Errorf("redis GET: %w", err)
	}
	return readBulkString(r)
}

// Del borra key. No es error si no existe.
func (c *SimpleRedisClient) Del(key string) error {
	conn, r, err := c.dial()
	if err != nil {
		return err
	}
	defer conn.Close()

	if err := writeCmd(conn, "DEL", key); err != nil {
		return fmt.Errorf("redis DEL: %w", err)
	}
	_, err = readInteger(r)
	return err
}

// Exists retorna true si key existe.
func (c *SimpleRedisClient) Exists(key string) (bool, error) {
	conn, r, err := c.dial()
	if err != nil {
		return false, err
	}
	defer conn.Close()

	if err := writeCmd(conn, "EXISTS", key); err != nil {
		return false, fmt.Errorf("redis EXISTS: %w", err)
	}
	n, err := readInteger(r)
	return n > 0, err
}

// ErrRedisNil indica que la clave no existe en Redis (bulk string nil).
var ErrRedisNil = errors.New("redis: nil")

// ── Protocolo RESP2 ──────────────────────────────────────────────────────────

// writeCmd serializa un comando Redis en formato RESP2 y lo envía.
func writeCmd(conn net.Conn, args ...string) error {
	var b strings.Builder
	fmt.Fprintf(&b, "*%d\r\n", len(args))
	for _, a := range args {
		fmt.Fprintf(&b, "$%d\r\n%s\r\n", len(a), a)
	}
	_, err := fmt.Fprint(conn, b.String())
	return err
}

// readSimpleString lee una respuesta "+OK\r\n" o "-ERR...\r\n".
func readSimpleString(r *bufio.Reader) (string, error) {
	line, err := r.ReadString('\n')
	if err != nil {
		return "", fmt.Errorf("redis read: %w", err)
	}
	line = strings.TrimRight(line, "\r\n")
	if strings.HasPrefix(line, "+") {
		return line[1:], nil
	}
	if strings.HasPrefix(line, "-") {
		return "", fmt.Errorf("redis error: %s", line[1:])
	}
	return "", fmt.Errorf("redis: respuesta inesperada %q", line)
}

// readBulkString lee un bulk string "$N\r\n<data>\r\n" o "$-1\r\n" (nil).
func readBulkString(r *bufio.Reader) ([]byte, error) {
	line, err := r.ReadString('\n')
	if err != nil {
		return nil, fmt.Errorf("redis read bulk: %w", err)
	}
	line = strings.TrimRight(line, "\r\n")
	if strings.HasPrefix(line, "-") {
		return nil, fmt.Errorf("redis error: %s", line[1:])
	}
	if !strings.HasPrefix(line, "$") {
		return nil, fmt.Errorf("redis: respuesta inesperada %q", line)
	}
	n, err := strconv.Atoi(line[1:])
	if err != nil {
		return nil, fmt.Errorf("redis bulk len: %w", err)
	}
	if n == -1 {
		return nil, ErrRedisNil
	}
	data := make([]byte, n+2) // +2 para \r\n final
	if _, err := r.Read(data); err != nil {
		return nil, fmt.Errorf("redis bulk data: %w", err)
	}
	return data[:n], nil
}

// readInteger lee una respuesta ":(number)\r\n".
func readInteger(r *bufio.Reader) (int64, error) {
	line, err := r.ReadString('\n')
	if err != nil {
		return 0, fmt.Errorf("redis read int: %w", err)
	}
	line = strings.TrimRight(line, "\r\n")
	if strings.HasPrefix(line, "-") {
		return 0, fmt.Errorf("redis error: %s", line[1:])
	}
	if !strings.HasPrefix(line, ":") {
		return 0, fmt.Errorf("redis: respuesta inesperada %q", line)
	}
	return strconv.ParseInt(line[1:], 10, 64)
}
