// bosctl db — DbInitService CLI (BC-07, C-04b).
//
// Interface Dual (ADR-020): estos comandos usan WebSocket RPC (Vía 1).
// Los mismos métodos están disponibles vía JSON-RPC 2.0 (Vía 2).
//
// Uso:
//
//	bosctl db init   [--ctx-id <id>]   — aplicar DDLs + seeds a SBOS_db
//	bosctl db status                   — consultar estado y conteos de tablas
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
)

// cmdDB enruta el subcomando db.
func cmdDB(args []string) int {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "bosctl db: subcomando requerido")
		fmt.Fprintln(os.Stderr, "  subcomandos: init, status")
		return 2
	}
	switch args[0] {
	case "init":
		return cmdDBInit(args[1:])
	case "status":
		return cmdDBStatus(args[1:])
	default:
		fmt.Fprintf(os.Stderr, "bosctl db: subcomando desconocido: %s\n", args[0])
		return 2
	}
}

// cmdDBInit aplica DDLs + seeds a SBOS_db.
//
//	bosctl db init [--ctx-id <id>]
func cmdDBInit(args []string) int {
	fs := flag.NewFlagSet("db init", flag.ContinueOnError)
	ctxID := fs.String("ctx-id", "", "contexto de auditoría (SBOS-049)")
	if err := fs.Parse(args); err != nil {
		return 2
	}

	params, _ := json.Marshal(map[string]string{
		"ctx_id": *ctxID,
	})
	resp, err := doRPCCall("bos.db.init", params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return 1
	}
	if resp.Error != nil {
		fmt.Fprintf(os.Stderr, "error RPC: %s\n", resp.Error.Message)
		return 1
	}
	printJSON(resp.Result)
	return 0
}

// cmdDBStatus consulta el estado de inicialización de SBOS_db.
//
//	bosctl db status
func cmdDBStatus(_ []string) int {
	resp, err := doRPCCall("bos.db.status", json.RawMessage("{}"))
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return 1
	}
	if resp.Error != nil {
		fmt.Fprintf(os.Stderr, "error RPC: %s\n", resp.Error.Message)
		return 1
	}
	printJSON(resp.Result)
	return 0
}
