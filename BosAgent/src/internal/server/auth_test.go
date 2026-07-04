// Package server — tests F6.1: auth en métodos JSON-RPC destructivos.
// DoD: sin token válido → -32600 Unauthorized.
package server

import (
	"encoding/base64"
	"errors"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

// stubRBAC implementa security.RBACProvider para tests: niega todo a "intruso".
type stubRBAC struct{}

func (stubRBAC) CanExecute(user, cmd string) error {
	if user == "intruso" {
		return errors.New("rol readonly no permite " + cmd)
	}
	return nil
}
func (stubRBAC) GetRole(user string) string { return "admin" }

func basicAuth(user, id, token string) rpcAuth {
	return rpcAuth{User: user, ID: id, Token: token}
}

// TestAuth_DestructivoSinToken_DenegadoFailClose: sin archivo rpc-token configurado
// y sin BOS_NO_RPC_TOKEN=true, los métodos destructivos se rechazan (fail-close A-06).
func TestAuth_DestructivoSinToken_DenegadoFailClose(t *testing.T) {
	// Asegurar que no hay token file ni modo dev activos en este test
	t.Setenv("BOS_RPC_TOKEN_FILE", "/nonexistent/path/rpc-token")
	t.Setenv("BOS_NO_RPC_TOKEN", "")

	s := makeCtxTestServer()

	resp := s.dispatchRPC(buildRPC("bos.ctx.invalidate",
		map[string]string{"ctx_id": "ctx-deadbeef"}), rpcAuth{})

	if resp == nil || resp.Error == nil {
		t.Fatal("sin token file debe retornar error")
	}
	// A-06: fail-close — sin token file configurado → Unauthorized
	if resp.Error.Code != ErrInvalidRequest {
		t.Errorf("sin token file debe ser Unauthorized (-32600), got %v", resp.Error)
	}
}

// TestAuth_DestructivoConCredencial_Ejecuta verifica que con token file + token
// correcto el handler se ejecuta (el error posterior es de dominio, no auth).
func TestAuth_DestructivoConCredencial_Ejecuta(t *testing.T) {
	dir := t.TempDir()
	tokenFile := filepath.Join(dir, "rpc-token")
	os.WriteFile(tokenFile, []byte("token-valido"), 0600)
	t.Setenv("BOS_RPC_TOKEN_FILE", tokenFile)

	s := makeCtxTestServer()

	resp := s.dispatchRPC(buildRPC("bos.ctx.invalidate",
		map[string]string{"ctx_id": "ctx-inexistente"}),
		basicAuth("operador", "1", "token-valido"))

	if resp == nil || resp.Error == nil {
		t.Fatal("ctx inexistente debe retornar error de dominio")
	}
	if resp.Error.Code == ErrInvalidRequest {
		t.Errorf("con credencial no debe ser Unauthorized: %v", resp.Error)
	}
}

// TestAuth_LecturaSinToken_Pasa: los métodos de lectura no exigen credencial.
func TestAuth_LecturaSinToken_Pasa(t *testing.T) {
	s := makeCtxTestServer()

	resp := s.dispatchRPC(buildRPC("system.listMethods", nil), rpcAuth{})

	if resp == nil {
		t.Fatal("respuesta nil")
	}
	if resp.Error != nil {
		t.Errorf("lectura sin token no debe fallar: %v", resp.Error)
	}
}

// TestAuth_SinRBACPropio_TokenValidoPasa: ADR-006 / F4.4 eliminó RBAC propio.
// La autorización se hereda de Ubuntu (Unix socket 0660) y K8s RBAC.
// Con token compartido válido, los métodos destructivos se autorizan.
func TestAuth_SinRBACPropio_TokenValidoPasa(t *testing.T) {
	dir := t.TempDir()
	tokenFile := filepath.Join(dir, "rpc-token")
	os.WriteFile(tokenFile, []byte("token-valido"), 0600)
	t.Setenv("BOS_RPC_TOKEN_FILE", tokenFile)

	s := makeCtxTestServer()

	resp := s.dispatchRPC(buildRPC("bos.ctx.invalidate",
		map[string]string{"ctx_id": "ctx-inexistente"}),
		basicAuth("operador", "1", "token-valido"))

	if resp == nil || resp.Error == nil {
		t.Fatal("ctx inválido debe retornar error de dominio, no de auth")
	}
	// Con token válido NO debe ser error de auth
	if resp.Error.Code == ErrInvalidRequest {
		t.Errorf("token válido no debe rechazar: %v", resp.Error)
	}
}

// TestAuth_TokenCompartidoInvalido_32600: con /etc/bos/rpc-token configurado
// (vía BOS_RPC_TOKEN_FILE), un token distinto se rechaza con -32600.
func TestAuth_TokenCompartidoInvalido_32600(t *testing.T) {
	dir := t.TempDir()
	tokenFile := filepath.Join(dir, "rpc-token")
	if err := os.WriteFile(tokenFile, []byte("secreto-real\n"), 0600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("BOS_RPC_TOKEN_FILE", tokenFile)

	s := makeCtxTestServer()

	bad := s.dispatchRPC(buildRPC("bos.ctx.invalidate",
		map[string]string{"ctx_id": "ctx-x"}),
		basicAuth("operador", "1", "secreto-falso"))
	if bad == nil || bad.Error == nil || bad.Error.Code != ErrInvalidRequest {
		t.Errorf("token incorrecto debe dar -32600, got %+v", bad)
	}

	// con el token correcto pasa la barrera de auth (error posterior es de dominio)
	good := s.dispatchRPC(buildRPC("bos.ctx.invalidate",
		map[string]string{"ctx_id": "ctx-x"}),
		basicAuth("operador", "1", "secreto-real"))
	if good == nil || good.Error == nil {
		t.Fatal("ctx inexistente debe retornar error de dominio")
	}
	if good.Error.Code == ErrInvalidRequest {
		t.Errorf("token correcto no debe ser Unauthorized: %v", good.Error)
	}
}

// TestParseRPCAuth_HeaderBasic verifica el parseo del esquema del manual
// JSON-RPC Parte 2 §3: Basic base64(user:id:token).
func TestParseRPCAuth_HeaderBasic(t *testing.T) {
	r := httptest.NewRequest("POST", "/rpc", nil)
	raw := base64.StdEncoding.EncodeToString([]byte("ana:7:tok123"))
	r.Header.Set("Authorization", "Basic "+raw)

	got := parseRPCAuth(r)
	if got.User != "ana" || got.ID != "7" || got.Token != "tok123" {
		t.Errorf("parseRPCAuth: got %+v", got)
	}

	// header ausente → rpcAuth vacío
	empty := parseRPCAuth(httptest.NewRequest("POST", "/rpc", nil))
	if empty.User != "" || empty.Token != "" {
		t.Errorf("sin header debe ser vacío: %+v", empty)
	}

	// header malformado → rpcAuth vacío
	bad := httptest.NewRequest("POST", "/rpc", nil)
	bad.Header.Set("Authorization", "Basic no-es-base64!!!")
	if a := parseRPCAuth(bad); a.User != "" {
		t.Errorf("base64 inválido debe ser vacío: %+v", a)
	}
}
