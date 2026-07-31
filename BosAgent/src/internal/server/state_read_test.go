// Package server — tests F6.4: bos.state.read no expone hashes SHA-256.
// DoD: jq 'has("hashes")' → false en cada ficha de la respuesta.
package server

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	"bos/internal/state"
)

// stubStateManager implementa StateManager con una ficha que SÍ tiene hashes
// internos — el RPC debe filtrarlos.
type stubStateManager struct{}

func (stubStateManager) Read() (*state.SBOSState, error) {
	return &state.SBOSState{
		Version:     "1.0",
		Hostname:    "test-host",
		ClusterName: "sbos-test",
		UpdatedAt:   time.Now(),
		Fichas: map[string]*state.Ficha{
			"postgresql": {
				Name:    "postgresql",
				Version: "18.4",
				State:   state.StateInstalled,
				Hashes: map[string]string{
					"manifest.yml": "a3f8c2d1e9b4567890abcdef1234567890abcdef1234567890abcdef12345678",
				},
				HealthStatus: "OK",
			},
		},
	}, nil
}
func (stubStateManager) Transition(string, state.FichaState) error { return nil }
func (stubStateManager) SetHealth(string, string) error            { return nil }

// TestStateRead_SinHashes es el DoD de F6.4: la respuesta JSON de
// bos.state.read no contiene la clave "hashes" en ninguna ficha.
func TestStateRead_SinHashes(t *testing.T) {
	s := makeCtxTestServer()
	s.stateMgr = stubStateManager{}

	resp := s.rpcStateRead(buildRPC("bos.state.read", nil))
	if resp.Error != nil {
		t.Fatalf("bos.state.read: %v", resp.Error)
	}

	raw, err := json.Marshal(resp.Result)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(raw), `"hashes"`) {
		t.Errorf("la respuesta no debe contener la clave hashes:\n%s", raw)
	}

	// equivalente a jq '.fichas.postgresql | has("hashes")' → false
	var result struct {
		Fichas map[string]map[string]interface{} `json:"fichas"`
	}
	if err := json.Unmarshal(raw, &result); err != nil {
		t.Fatal(err)
	}
	pg, ok := result.Fichas["postgresql"]
	if !ok {
		t.Fatal("ficha postgresql ausente en la respuesta")
	}
	if _, has := pg["hashes"]; has {
		t.Error(`has("hashes") debe ser false`)
	}

	// los campos públicos siguen presentes
	if pg["version"] != "18.4" || pg["health_status"] != "OK" {
		t.Errorf("campos públicos perdidos: %+v", pg)
	}
}
