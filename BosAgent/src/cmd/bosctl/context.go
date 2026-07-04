// Package main — context.go: subcomandos bosctl ctx (F5.5 — SBOS-049).
// Accede al Context Plane vía bos.ctx.* JSON-RPC 2.0 sobre /run/bos/bos.sock.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"
)

// ctxRPC envía un método bos.ctx.* al daemon usando la Vía 2 (JSON-RPC sobre Unix socket).
func ctxRPC(method string, params interface{}) (map[string]interface{}, error) {
	raw, err := json.Marshal(params)
	if err != nil {
		return nil, fmt.Errorf("marshal params: %w", err)
	}
	resp, err := doRPCCall(method, raw)
	if err != nil {
		return nil, err
	}
	if resp.Error != nil {
		return nil, fmt.Errorf("error %d: %s", resp.Error.Code, resp.Error.Message)
	}
	var data map[string]interface{}
	if err := json.Unmarshal(resp.Result, &data); err != nil {
		return nil, fmt.Errorf("respuesta inválida: %w", err)
	}
	return data, nil
}

// cmdCtx despacha los subcomandos: bosctl ctx <list|get|invalidate|stats>
func cmdCtx(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "bosctl ctx: subcomando requerido: list|get|invalidate|stats")
		return 2
	}
	sub := args[0]
	rest := args[1:]
	switch sub {
	case "list":
		return cmdCtxList(rest)
	case "get":
		return cmdCtxGet(rest)
	case "invalidate":
		return cmdCtxInvalidate(rest)
	case "stats":
		return cmdCtxStats(rest)
	default:
		fmt.Fprintf(os.Stderr, "bosctl ctx: subcomando desconocido: %s\n", sub)
		return 2
	}
}

// cmdCtxList lista los ctx_id activos de un tenant.
// bosctl ctx list --tenant=skull
func cmdCtxList(args []string) int {
	fs := flag.NewFlagSet("ctx list", flag.ContinueOnError)
	tenant := fs.String("tenant", "", "ID del tenant (obligatorio)")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	if *tenant == "" {
		fmt.Fprintln(os.Stderr, "bosctl ctx list: --tenant es obligatorio")
		return 2
	}
	data, err := ctxRPC("bos.ctx.list", map[string]string{"tenant_id": *tenant})
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ctx list: %v\n", err)
		return 1
	}
	total, _ := data["total"].(float64)
	fmt.Printf("ctx_id activos para tenant %q: %.0f\n", *tenant, total)
	sessions, _ := data["sessions"].([]interface{})
	for _, s := range sessions {
		if sess, ok := s.(map[string]interface{}); ok {
			ctxID, _ := sess["ctx_id"].(string)
			userID, _ := sess["user_id"].(string)
			empresa, _ := sess["empresa_id"].(string)
			state, _ := sess["state"].(string)
			fmt.Printf("  %-30s  user=%-20s  empresa=%-10s  %s\n",
				ctxID, userID, empresa, state)
		}
	}
	return 0
}

// cmdCtxGet recupera y muestra los campos de un ctx_id.
// bosctl ctx get <ctx_id>
func cmdCtxGet(args []string) int {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "bosctl ctx get: se requiere ctx_id")
		return 2
	}
	ctxID := args[0]
	data, err := ctxRPC("bos.ctx.get", map[string]string{"ctx_id": ctxID})
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ctx get: %v\n", err)
		if strings.Contains(err.Error(), "no encontrado") {
			return 3
		}
		return 1
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	if err := enc.Encode(data); err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ctx get: encode: %v\n", err)
		return 1
	}
	return 0
}

// cmdCtxInvalidate invalida uno o más ctx_id.
// bosctl ctx invalidate <ctx_id> [ctx_id2 ...]
// bosctl ctx invalidate --tenant=skull  (invalida todos los del tenant)
func cmdCtxInvalidate(args []string) int {
	fs := flag.NewFlagSet("ctx invalidate", flag.ContinueOnError)
	tenant := fs.String("tenant", "", "invalidar todos los ctx_id del tenant")
	if err := fs.Parse(args); err != nil {
		return 2
	}

	if *tenant != "" {
		data, err := ctxRPC("bos.ctx.tenant.suspend", map[string]string{"tenant_id": *tenant})
		if err != nil {
			fmt.Fprintf(os.Stderr, "bosctl ctx invalidate --tenant: %v\n", err)
			return 1
		}
		count, _ := data["invalidated"].(float64)
		fmt.Printf("tenant %q: %.0f ctx_id invalidados\n", *tenant, count)
		return 0
	}

	if len(fs.Args()) == 0 {
		fmt.Fprintln(os.Stderr, "bosctl ctx invalidate: se requiere ctx_id o --tenant")
		return 2
	}
	exitCode := 0
	for _, ctxID := range fs.Args() {
		data, err := ctxRPC("bos.ctx.invalidate", map[string]string{"ctx_id": ctxID})
		if err != nil {
			fmt.Fprintf(os.Stderr, "bosctl ctx invalidate %s: %v\n", ctxID, err)
			exitCode = 1
			continue
		}
		if inv, _ := data["invalidated"].(bool); inv {
			fmt.Printf("%s: invalidado\n", ctxID)
		}
	}
	return exitCode
}

// cmdCtxStats muestra estadísticas del Context Plane.
// bosctl ctx stats --tenant=skull
func cmdCtxStats(args []string) int {
	fs := flag.NewFlagSet("ctx stats", flag.ContinueOnError)
	tenant := fs.String("tenant", "", "tenant para estadísticas (vacío = global)")
	if err := fs.Parse(args); err != nil {
		return 2
	}

	params := map[string]string{}
	if *tenant != "" {
		params["tenant_id"] = *tenant
	}
	data, err := ctxRPC("bos.ctx.list", params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ctx stats: %v\n", err)
		return 1
	}
	total, _ := data["total"].(float64)
	fmt.Printf("Context Plane — %s\n", time.Now().Format("2006-01-02 15:04:05"))
	if *tenant != "" {
		fmt.Printf("  tenant:           %s\n", *tenant)
	}
	fmt.Printf("  sesiones activas: %.0f\n", total)
	return 0
}
