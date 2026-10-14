// sbos-stub-daemon — daemon stub que simula presencia de un daemon SBOS.
// Responde a JSON-RPC 2.0 sobre Unix socket (HTTP).
// Uso: DAEMON_NAME=bkernel DAEMON_SOCKET=/run/bos/bkernel.sock ./sbos-stub-daemon
package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"time"
)

var (
	daemonName    = getEnv("DAEMON_NAME", "stub")
	socketPath    = getEnv("DAEMON_SOCKET", "/run/bos/stub.sock")
	daemonVersion = getEnv("DAEMON_VERSION", "0.1.0-stub")
)

func getEnv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

type rpcRequest struct {
	JSONRPC string          `json:"jsonrpc"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params"`
	ID      interface{}     `json:"id"`
}

type rpcResponse struct {
	JSONRPC string      `json:"jsonrpc"`
	Result  interface{} `json:"result,omitempty"`
	Error   interface{} `json:"error,omitempty"`
	ID      interface{} `json:"id"`
}

func handler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/rpc" || r.Method != http.MethodPost {
		http.NotFound(w, r)
		return
	}

	var req rpcRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}

	result := map[string]interface{}{
		"daemon":  daemonName,
		"version": daemonVersion,
		"status":  "ok",
		"mode":    "stub",
		"method":  req.Method,
		"time":    time.Now().UTC().Format(time.RFC3339),
	}

	resp := rpcResponse{JSONRPC: "2.0", Result: result, ID: req.ID}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func main() {
	os.Remove(socketPath)

	ln, err := net.Listen("unix", socketPath)
	if err != nil {
		log.Fatalf("stub %s: escuchar %s: %v", daemonName, socketPath, err)
	}
	defer ln.Close()

	if err := os.Chmod(socketPath, 0660); err != nil {
		log.Printf("stub %s: chmod socket: %v", daemonName, err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/rpc", handler)
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, `{"status":"ok","daemon":"%s"}`, daemonName)
	})

	log.Printf("stub %s operativo en %s", daemonName, socketPath)
	srv := &http.Server{Handler: mux}
	if err := srv.Serve(ln); err != nil {
		log.Fatalf("stub %s: %v", daemonName, err)
	}
}
