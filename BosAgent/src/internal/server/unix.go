// Package server — unix.go: Interface Dual ADR-020.
//
// Mismo socket /run/bos/bos.sock, dos vías paralelas:
//
//   Vía 1: primer byte != '{' (típicamente 'G' en HTTP GET WebSocket upgrade)
//           → WebSocket RPC → bosctl CLI, Core UI, humanos
//
//   Vía 2: primer byte '{'
//           → JSON-RPC 2.0 raw (una línea '\n' por request)
//           → biedata, bkernel, bAuth, bSearch, agentes IA, sagas
//
// Protocolo Vía 2 (acordado en C-BOS-005, mismo que bAuth unix_socket.rs):
//   - Un objeto JSON por línea, terminado en '\n'
//   - Batch (array JSON) — ejecución paralela por goroutines
//   - Auth vía campo "_token" top-level; OS-level 0660 es la barrera primaria
//   - "_caller" identifica el daemon llamador para trazabilidad de auditoría
//
// SBOS-050 P9: HTTP vetado entre daemons — solo Unix socket + WebSocket.
package server

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"sync"
)

// ── peekedConn ─────────────────────────────────────────────────────────────

// peekedConn re-inyecta el primer byte ya leído en el flujo de la conexión.
// Necesario porque net.Conn no tiene Peek: leer el primer byte lo consume.
type peekedConn struct {
	net.Conn
	prefix []byte
}

func (c *peekedConn) Read(b []byte) (int, error) {
	if len(c.prefix) > 0 && len(b) > 0 {
		n := copy(b, c.prefix)
		c.prefix = c.prefix[n:]
		return n, nil
	}
	return c.Conn.Read(b)
}

// ── chanListener ───────────────────────────────────────────────────────────

// chanListener entrega conexiones ya aceptadas a un http.Server sin abrir un
// nuevo socket. Permite reusar el mux WebSocket/HTTP existente (Vía 1) con
// conexiones que ya pasaron la detección de protocolo.
type chanListener struct {
	ch   chan net.Conn
	addr net.Addr
	done chan struct{}
}

func newChanListener(addr net.Addr) *chanListener {
	return &chanListener{
		ch:   make(chan net.Conn, 128),
		addr: addr,
		done: make(chan struct{}),
	}
}

func (l *chanListener) Accept() (net.Conn, error) {
	select {
	case conn, ok := <-l.ch:
		if !ok {
			return nil, fmt.Errorf("chanListener: cerrado")
		}
		return conn, nil
	case <-l.done:
		return nil, fmt.Errorf("chanListener: cerrado")
	}
}

func (l *chanListener) Close() error {
	select {
	case <-l.done:
	default:
		close(l.done)
	}
	return nil
}

func (l *chanListener) Addr() net.Addr { return l.addr }

// ── Listener dual ──────────────────────────────────────────────────────────

// listenUnixDual arranca el loop de detección de protocolo sobre el listener
// Unix. wsServer es el http.Server para WebSocket (Vía 1) ya asignado a
// s.unixServer por el caller (ListenAndServe) antes de lanzar esta goroutine.
func (s *Server) listenUnixDual(l net.Listener, wsServer *http.Server) {
	cl := newChanListener(l.Addr())
	go func() {
		if err := wsServer.Serve(cl); err != nil && err != http.ErrServerClosed {
			s.logger.Error("unix ws server error", "err", err)
		}
	}()

	for {
		conn, err := l.Accept()
		if err != nil {
			select {
			case <-cl.done:
			default:
				s.logger.Error("unix accept error", "err", err)
			}
			return
		}
		go s.handleUnixConn(conn, cl)
	}
}

// handleUnixConn lee el primer byte y despacha a la vía correcta.
//
//	'{' → Vía 2: JSON-RPC 2.0 raw → serveJSONRPCConn
//	otro → Vía 1: WebSocket/HTTP → chanListener → wsServer
func (s *Server) handleUnixConn(conn net.Conn, cl *chanListener) {
	var buf [1]byte
	if n, err := conn.Read(buf[:]); err != nil || n == 0 {
		conn.Close()
		return
	}

	pconn := &peekedConn{Conn: conn, prefix: buf[:]}

	if buf[0] == '{' || buf[0] == '[' {
		s.serveJSONRPCConn(pconn)
	} else {
		select {
		case cl.ch <- pconn:
		case <-cl.done:
			pconn.Close()
		}
	}
}

// ── Servidor JSON-RPC raw (Vía 2) ─────────────────────────────────────────

// rpcRequestRaw es el envelope JSON-RPC 2.0 extendido para la Vía 2.
// "_token" y "_caller" son extensiones SBOS; no violan la spec JSON-RPC 2.0.
type rpcRequestRaw struct {
	JSONRPC string          `json:"jsonrpc"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
	ID      interface{}     `json:"id"`
	Token   string          `json:"_token,omitempty"`
	Caller  string          `json:"_caller,omitempty"`
}

func (r *rpcRequestRaw) toRequest() (*RPCRequest, rpcAuth) {
	req := &RPCRequest{
		JSONRPC: r.JSONRPC,
		Method:  r.Method,
		Params:  r.Params,
		ID:      r.ID,
	}
	caller := r.Caller
	if caller == "" {
		caller = "_daemon"
	}
	return req, rpcAuth{User: caller, Token: r.Token}
}

// serveJSONRPCConn procesa una conexión JSON-RPC 2.0 raw (Vía 2, SBOS-050 P9).
//
// Protocolo: un objeto JSON por línea terminada en '\n'.
// Soporta llamada individual y batch, con ejecución paralela para batch.
// La conexión se mantiene abierta hasta que el cliente la cierre o haya error.
func (s *Server) serveJSONRPCConn(conn net.Conn) {
	defer conn.Close()

	scanner := bufio.NewScanner(conn)
	scanner.Buffer(make([]byte, 256*1024), 256*1024)

	for scanner.Scan() {
		line := bytes.TrimSpace(scanner.Bytes())
		if len(line) == 0 {
			continue
		}

		var out []byte
		if line[0] == '[' {
			out = s.handleRawBatch(line)
		} else {
			out = s.handleRawSingle(line)
		}

		if len(out) > 0 {
			if _, err := conn.Write(append(out, '\n')); err != nil {
				return
			}
		}
	}
}

// handleRawSingle despacha una llamada JSON-RPC individual (Vía 2).
func (s *Server) handleRawSingle(line []byte) []byte {
	var raw rpcRequestRaw
	if err := json.Unmarshal(line, &raw); err != nil {
		return mustMarshal(rpcFail(nil, rpcError(ErrParse, "JSON inválido: "+err.Error())))
	}
	req, auth := raw.toRequest()
	resp := s.dispatchRPC(req, auth)
	if resp == nil {
		return nil // notificación — sin respuesta (spec §4.1)
	}
	return mustMarshal(resp)
}

// handleRawBatch despacha un batch JSON-RPC en paralelo (Vía 2).
// Mismo patrón que dispatchBatch pero con rpcRequestRaw para soportar "_token".
func (s *Server) handleRawBatch(line []byte) []byte {
	var rawReqs []rpcRequestRaw
	if err := json.Unmarshal(line, &rawReqs); err != nil {
		return mustMarshal(rpcFail(nil, rpcError(ErrParse, "batch JSON inválido: "+err.Error())))
	}
	if len(rawReqs) == 0 {
		return mustMarshal(rpcFail(nil, rpcError(ErrInvalidRequest, "batch vacío")))
	}

	slots := make([]*RPCResponse, len(rawReqs))
	var wg sync.WaitGroup
	for i := range rawReqs {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			req, auth := rawReqs[i].toRequest()
			slots[i] = s.dispatchRPC(req, auth)
		}(i)
	}
	wg.Wait()

	responses := make([]RPCResponse, 0, len(rawReqs))
	for _, r := range slots {
		if r != nil {
			responses = append(responses, *r)
		}
	}
	if len(responses) == 0 {
		return nil // todas eran notificaciones
	}
	return mustMarshal(responses)
}
