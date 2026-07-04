package main

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/user"
	"strings"
	"time"

	"bos/internal/paths"
)

// cmdRPC implementa 'bosctl rpc <method> [params_json]'
// Permite invocar cualquier método bos.* directamente desde la terminal.
//
// Ejemplos:
//
//	bosctl rpc bos.health.check
//	bosctl rpc bos.ficha.status '{"ficha_id":"postgresql"}'
//	bosctl rpc bos.saga.execute '{"ficha_id":"redis","command":"repair"}'
//	bosctl rpc bos.ctx.create '{"tenant_id":"acme","empresa_id":"e1"}'
func cmdRPC(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, usageRPC)
		return 2
	}

	method := args[0]
	if method == "--help" || method == "-h" {
		fmt.Fprintln(os.Stderr, usageRPC)
		return 0
	}

	var rawParams json.RawMessage
	if len(args) > 1 {
		rawParams = json.RawMessage(args[1])
		if !json.Valid(rawParams) {
			fmt.Fprintf(os.Stderr, "bosctl rpc: params inválidos (no es JSON válido): %s\n", args[1])
			return 2
		}
	}

	resp, err := doRPCCall(method, rawParams)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl rpc: %v\n", err)
		if strings.Contains(err.Error(), "connect") {
			return 6 // daemon no disponible
		}
		return 1
	}

	if resp.Error != nil {
		fmt.Fprintf(os.Stderr, "error %d: %s\n", resp.Error.Code, resp.Error.Message)
		if resp.Error.Data != nil {
			enc := json.NewEncoder(os.Stderr)
			enc.SetIndent("", "  ")
			enc.Encode(resp.Error.Data)
		}
		return 1
	}

	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	enc.SetEscapeHTML(false)
	enc.Encode(resp.Result)
	return 0
}

const usageRPC = `bosctl rpc — Invocación JSON-RPC 2.0 al daemon bos (ADR-019)

Uso:
  bosctl rpc <method> [params_json]

Métodos disponibles (bos.<modulo>.<operacion>):

  Fichas:
    bos.ficha.list
    bos.ficha.status      '{"ficha_id":"<id>"}'
    bos.ficha.install     '{"ficha_id":"<id>","version":"<ver>"}'
    bos.ficha.update      '{"ficha_id":"<id>","version":"<ver>"}'
    bos.ficha.repair      '{"ficha_id":"<id>"}'
    bos.ficha.remove      '{"ficha_id":"<id>"}'
    bos.ficha.probe       '{"ficha_id":"<id>"}'

  Bootstrap:
    bos.bootstrap.status
    bos.bootstrap.start   '{"mode":"unattended"}'
    bos.bootstrap.verify
    bos.bootstrap.resume

  Sagas (invocación directa):
    bos.saga.execute      '{"ficha_id":"<id>","command":"install|repair|update|remove|probe"}'

  Estado y salud:
    bos.state.read
    bos.health.check
    bos.health.check      '{"ficha_id":"<id>"}'

  Context Plane (SBOS-049):
    bos.ctx.create        '{"tenant_id":"<t>","empresa_id":"<e>","user_id":"<u>"}'
    bos.ctx.validate      '{"traceparent":"00-...-...-01"}'
    bos.ctx.get           '{"ctx_id":"<ctx>"}'         (TTL vencido → -32001)
    bos.ctx.list          '{"tenant_id":"<t>"}'

  Sagas de consulta (F6 — multi-fuente en paralelo, <4s):
    bos.query.system      '{"tenant_id":"<t>"}'  Ubuntu+K8s+fichas+ctx+certificación
    bos.query.repair      '{"ficha_id":"<id>","tenant_id":"<t>"}'  pre-diagnóstico
    bos.query.vdi         '{"tenant_id":"<t>"}'  VDI Layer con semáforo
    bos.query.tenant      '{"tenant_id":"<t>"}'  snapshot del tenant
    bos.query.node        '{"node":"<nodo>"}'    diagnóstico pre-mantenimiento
    bos.query.context     '{"tenant_id":"<t>"}'  estados, anomalías, TTLs

Transporte: Unix socket /run/bos/bos.sock (HTTP POST /rpc)

Autenticación (métodos destructivos — install/update/repair/remove/saga/
bootstrap.start/ctx.invalidate/tenant.suspend):
  El header Authorization se construye automáticamente desde BOS_RPC_TOKEN
  (o el archivo /etc/bos/rpc-token; ruta alternativa en BOS_RPC_TOKEN_FILE).
  Usuario: BOS_USER o el usuario del SO. Sin token válido → error -32600.

Ejemplos:
  bosctl rpc bos.ficha.list
  bosctl rpc bos.ficha.status '{"ficha_id":"postgresql"}'
  bosctl rpc bos.saga.execute '{"ficha_id":"redis","command":"repair"}'
  bosctl rpc bos.bootstrap.verify
  bosctl rpc bos.query.system
  bosctl rpc bos.query.repair '{"ficha_id":"nextcloud","tenant_id":"skull"}'
  bosctl rpc bos.ctx.create '{"tenant_id":"acme","empresa_id":"emp-01","user_id":"admin"}'`

// rpcResponse es el sobre de respuesta JSON-RPC 2.0.
type rpcResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *struct {
		Code    int             `json:"code"`
		Message string          `json:"message"`
		Data    json.RawMessage `json:"data,omitempty"`
	} `json:"error,omitempty"`
	ID interface{} `json:"id"`
}

// doRPCCall envía una solicitud JSON-RPC 2.0 al daemon por Unix socket.
func doRPCCall(method string, params json.RawMessage) (*rpcResponse, error) {
	socket := socketPath()

	payload := map[string]interface{}{
		"jsonrpc": "2.0",
		"method":  method,
		"id":      1,
	}
	if params != nil {
		payload["params"] = params
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("marshal: %w", err)
	}

	client := &http.Client{
		Transport: &http.Transport{
			DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
				return (&net.Dialer{Timeout: 5 * time.Second}).DialContext(ctx, "unix", socket)
			},
		},
		Timeout: 120 * time.Second,
	}

	req, err := http.NewRequest(http.MethodPost, "http://unix/rpc", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	if h := rpcAuthHeader(); h != "" {
		req.Header.Set("Authorization", h)
	}

	httpResp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("daemon no disponible en %s: %w", socket, err)
	}
	defer httpResp.Body.Close()

	var resp rpcResponse
	if err := json.NewDecoder(httpResp.Body).Decode(&resp); err != nil {
		return nil, fmt.Errorf("respuesta inválida: %w", err)
	}
	return &resp, nil
}

// rpcAuthHeader construye "Authorization: Basic base64(user:id:token)" para
// métodos destructivos (F6.1). El token sale de BOS_RPC_TOKEN o del archivo
// /etc/bos/rpc-token (legible solo por root y grupo bosagent). Sin token
// retorna "" — los métodos de lectura no lo requieren.
func rpcAuthHeader() string {
	token := os.Getenv("BOS_RPC_TOKEN")
	if token == "" {
		path := os.Getenv("BOS_RPC_TOKEN_FILE")
		if path == "" {
			path = paths.RpcTokenFile
		}
		if data, err := os.ReadFile(path); err == nil {
			token = strings.TrimSpace(string(data))
		}
	}
	if token == "" {
		return ""
	}
	username := os.Getenv("BOS_USER")
	if username == "" {
		if u, err := user.Current(); err == nil {
			username = u.Username
		}
	}
	raw := username + ":0:" + token
	return "Basic " + base64.StdEncoding.EncodeToString([]byte(raw))
}
