// Package bauth — client.go: cliente JSON-RPC 2.0 del BOS hacia BauthAgent.
// M7.8 — BOS-REPAIR Plan Maestro v3 · ADR-020 Interface Dual.
//
// Protocolo acordado en C-BOS-005 (BOS-BAUTH-CONTRATOS.md):
//   - Transporte: Unix socket stream (SOCK_STREAM)
//   - Detección: primer byte '{' → JSON-RPC 2.0 (Vía 2)
//   - Delimitación: un objeto JSON completo por línea, terminado en '\n'
//   - Sin prefijo de longitud (el bauth_rbac.go antiguo usaba 4 bytes — NO usar aquí)
//   - Autenticación: OS-level (grupo bosagent). No token adicional.
//   - "_caller" incluido en cada request para trazabilidad de auditoría.
//
// SBOS-050 P9: HTTP vetado entre daemons — solo Unix socket.
package bauth

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"sync"
	"sync/atomic"
	"time"
)

// DefaultSocket es el path del socket Unix de bAuth.
const DefaultSocket = "/run/bos/bauth.sock"

// callerID se incluye en todos los requests para trazabilidad (C-BOS-005).
const callerID = "bos.service"

// cacheTTL es el TTL del cache en memoria para resultados de context.evaluate (C-BAUTH-002).
const cacheTTL = 30 * time.Second

type cacheEntry struct {
	result    *ContextEvaluateResult
	expiresAt time.Time
}

// Client es el cliente JSON-RPC 2.0 del BOS hacia bAuth.
// Una conexión Unix por llamada — stateless, sin pool.
// Cache en memoria evita round-trips innecesarios al socket (cacheTTL).
type Client struct {
	socketPath string
	callerID   string        // identificador en _caller para trazabilidad (C-BOS-005)
	cacheTTL   time.Duration // TTL del cache context.evaluate (C-BAUTH-002)
	mu         sync.Mutex
	cache      map[string]*cacheEntry
	nextID     atomic.Int64
}

// NewClient crea un cliente hacia bAuth usando el socket Unix especificado.
// Si socketPath es "", usa la variable de entorno BAUTH_SOCKET.
// Si BAUTH_SOCKET tampoco está definida, usa DefaultSocket (/run/bos/bauth.sock).
// En staging la VPS usa /tmp/bauth/bauth.sock — configurar via BAUTH_SOCKET o bauth.toml.
// Acordado en C-BOS-007: ruta no hardcodeada, configurable en cada entorno.
func NewClient(socketPath string) *Client {
	if socketPath == "" {
		if env := os.Getenv("BAUTH_SOCKET"); env != "" {
			socketPath = env
		} else {
			socketPath = DefaultSocket
		}
	}
	return &Client{
		socketPath: socketPath,
		callerID:   callerID,
		cacheTTL:   cacheTTL,
		cache:      make(map[string]*cacheEntry),
	}
}

// rpcRequest es el envelope JSON-RPC 2.0 enviado a bAuth.
type rpcRequest struct {
	JSONRPC string `json:"jsonrpc"`
	Method  string `json:"method"`
	Params  any    `json:"params"`
	ID      int64  `json:"id"`
	Caller  string `json:"_caller,omitempty"`
}

// rpcResponse es el envelope de respuesta JSON-RPC 2.0 recibido de bAuth.
type rpcResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *rpcErr         `json:"error,omitempty"`
	ID      int64           `json:"id"`
}

type rpcErr struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

func (e *rpcErr) Error() string {
	return fmt.Sprintf("bauth rpc %d: %s", e.Code, e.Message)
}

// call ejecuta un método JSON-RPC en bAuth y deserializa la respuesta en out.
// Si out es nil, descarta el campo result.
func (c *Client) call(ctx context.Context, method string, params any, out any) error {
	req := rpcRequest{
		JSONRPC: "2.0",
		Method:  method,
		Params:  params,
		ID:      c.nextID.Add(1),
		Caller:  c.callerID,
	}
	line, err := json.Marshal(req)
	if err != nil {
		return fmt.Errorf("bauth: serializar %s: %w", method, err)
	}
	line = append(line, '\n')

	var d net.Dialer
	conn, err := d.DialContext(ctx, "unix", c.socketPath)
	if err != nil {
		return fmt.Errorf("bauth: conectar %s: %w", c.socketPath, err)
	}
	defer conn.Close()

	if dl, ok := ctx.Deadline(); ok {
		if err := conn.SetDeadline(dl); err != nil {
			return fmt.Errorf("bauth: deadline: %w", err)
		}
	}

	if _, err := conn.Write(line); err != nil {
		return fmt.Errorf("bauth: escribir %s: %w", method, err)
	}

	scanner := bufio.NewScanner(conn)
	if !scanner.Scan() {
		if err := scanner.Err(); err != nil {
			return fmt.Errorf("bauth: leer respuesta %s: %w", method, err)
		}
		return fmt.Errorf("bauth: conexión cerrada sin respuesta para %s", method)
	}

	var resp rpcResponse
	if err := json.Unmarshal(scanner.Bytes(), &resp); err != nil {
		return fmt.Errorf("bauth: deserializar respuesta %s: %w", method, err)
	}
	if resp.Error != nil {
		return resp.Error
	}
	if out != nil && len(resp.Result) > 0 {
		if err := json.Unmarshal(resp.Result, out); err != nil {
			return fmt.Errorf("bauth: deserializar result %s: %w", method, err)
		}
	}
	return nil
}

// EvaluateContext evalúa los 12 dominios (D1–D12) para el ctx_id dado.
// Respuesta cacheada 30s en memoria.
// El ctx_id debe ser el formato compuesto post-promote de bAuth.
// atomSlug vacío usa el default de bAuth: "sistema.sesion.activa".
func (c *Client) EvaluateContext(ctx context.Context, ctxID, atomSlug string) (*ContextEvaluateResult, error) {
	if atomSlug == "" {
		atomSlug = "sistema.sesion.activa"
	}
	key := ctxID + ":" + atomSlug

	c.mu.Lock()
	if e, ok := c.cache[key]; ok && time.Now().Before(e.expiresAt) {
		r := e.result
		c.mu.Unlock()
		return r, nil
	}
	c.mu.Unlock()

	params := map[string]string{"ctx_id": ctxID, "atom_slug": atomSlug}
	var result ContextEvaluateResult
	if err := c.call(ctx, "bauth.context.evaluate", params, &result); err != nil {
		return nil, fmt.Errorf("EvaluateContext: %w", err)
	}

	c.mu.Lock()
	c.cache[key] = &cacheEntry{result: &result, expiresAt: time.Now().Add(c.cacheTTL)}
	c.mu.Unlock()
	return &result, nil
}

// GetSession obtiene los datos de sesión de bauth.ses_context.
// Método ligero: sin evaluación de dominios. Ideal para health checks y validación rápida.
// Acordado en C-BOS-006.
func (c *Client) GetSession(ctx context.Context, ctxID string) (*SessionData, error) {
	var result SessionData
	if err := c.call(ctx, "bauth.ctx.get_session", map[string]string{"ctx_id": ctxID}, &result); err != nil {
		return nil, fmt.Errorf("GetSession: %w", err)
	}
	return &result, nil
}

// CreateCtx registra un nuevo contexto pre-auth en bAuth.
// BOS pasa todos los datos organizacionales y de dispositivo para que bAuth los almacene
// en CtxPlane. Acordado en C-BAUTH-001.
func (c *Client) CreateCtx(ctx context.Context, req *CreateCtxRequest) (*CreateCtxResponse, error) {
	var result CreateCtxResponse
	if err := c.call(ctx, "bauth.ctx.create", req, &result); err != nil {
		return nil, fmt.Errorf("CreateCtx: %w", err)
	}
	return &result, nil
}

// PromoteCtx eleva un dctx_id pre-auth a ctx_id post-auth con bitmask calculado.
// bAuth calcula bitmask_hex sincrónicamente en la misma transacción (C-BOS-004).
// Después de PromoteCtx, el cache de EvaluateContext del dctx_id queda invalidado.
func (c *Client) PromoteCtx(ctx context.Context, req *PromoteCtxRequest) (*PromoteCtxResponse, error) {
	var result PromoteCtxResponse
	if err := c.call(ctx, "bauth.ctx.promote", req, &result); err != nil {
		return nil, fmt.Errorf("PromoteCtx: %w", err)
	}
	c.InvalidateCache(req.CtxID)
	return &result, nil
}

// InvalidateCtx invalida explícitamente un ctx_id activo (logout, revocación).
func (c *Client) InvalidateCtx(ctx context.Context, ctxID string) error {
	if err := c.call(ctx, "bauth.ctx.invalidate", map[string]string{"ctx_id": ctxID}, nil); err != nil {
		return fmt.Errorf("InvalidateCtx: %w", err)
	}
	c.InvalidateCache(ctxID)
	return nil
}

// InvalidateCache elimina del cache todas las entradas que comienzan con el ctx_id dado.
// Llamar siempre después de promover o invalidar un contexto.
func (c *Client) InvalidateCache(ctxID string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	for k := range c.cache {
		if len(k) >= len(ctxID) && k[:len(ctxID)] == ctxID {
			delete(c.cache, k)
		}
	}
}
