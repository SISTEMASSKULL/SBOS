// Subcomandos de gestión de puertos — Motor IAM Installer SBOS-050.
//
//	bosctl port lookup <port> [--type K8S_CLUSTER_IP] [--ns default]
//	bosctl port list   [--ficha <id>] [--limit 100]
//	bosctl port check  <port> [--type K8S_CLUSTER_IP] [--ns default]
//	bosctl port assign --ficha <id> --server <S00> --index 0 --types K8S_CLUSTER_IP,K8S_NODE_PORT
//	bosctl port release --ficha <id>
//	bosctl port validate
//	bosctl port export [--limit 500]
//
// Interface Dual (ADR-020): estos comandos usan JSON-RPC 2.0 (Vía 2) al daemon bos.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
)

func cmdPort(args []string) int {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, usagePort)
		return 2
	}

	sub := args[0]
	rest := args[1:]

	switch sub {
	case "lookup":
		return cmdPortLookup(rest)
	case "list":
		return cmdPortList(rest)
	case "check":
		return cmdPortCheck(rest)
	case "assign":
		return cmdPortAssign(rest)
	case "release":
		return cmdPortRelease(rest)
	case "validate":
		return cmdPortValidate(rest)
	case "export":
		return cmdPortExport(rest)
	case "--help", "-h":
		fmt.Fprintln(os.Stderr, usagePort)
		return 0
	default:
		fmt.Fprintf(os.Stderr, "bosctl port: subcomando desconocido: %s\n", sub)
		return 2
	}
}

const usagePort = `bosctl port — Motor de Asignación de Puertos SBOS-050

Subcomandos:
  lookup  <puerto>              Consultar quién ocupa un puerto
  list    [--ficha <id>]        Listar asignaciones del Kardex
  check   <puerto>              Verificar disponibilidad (3 capas)
  assign  --ficha <id>          Asignar puertos a una ficha
          --server <S00>
          --index 0
          --types K8S_CLUSTER_IP,K8S_NODE_PORT
  release --ficha <id>          Liberar puertos de una ficha
  validate                      Detectar drift Kardex vs K8s
  export  [--limit 500]         Exportar Kardex en Markdown

Flags comunes:
  --type  K8S_CLUSTER_IP        Tipo de puerto (default)
  --ns    default               Namespace K8s
  --limit 100                   Máximo de resultados`

// cmdPortLookup invoca bos.portman.lookup
func cmdPortLookup(args []string) int {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "bosctl port lookup: puerto requerido")
		return 2
	}
	port, err := strconv.Atoi(args[0])
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl port lookup: puerto inválido: %s\n", args[0])
		return 2
	}

	portType := "K8S_CLUSTER_IP"
	ns := "default"
	for i := 1; i < len(args); i++ {
		if args[i] == "--type" && i+1 < len(args) {
			portType = args[i+1]
			i++
		} else if args[i] == "--ns" && i+1 < len(args) {
			ns = args[i+1]
			i++
		}
	}

	params, _ := json.Marshal(map[string]interface{}{
		"port": port, "port_type": portType, "namespace": ns,
	})
	resp, err := doRPCCall("bos.portman.lookup", params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl port lookup: %v\n", err)
		return 1
	}
	return printRPCResult(resp)
}

// cmdPortList invoca bos.portman.list
func cmdPortList(args []string) int {
	fichaID := ""
	limit := 100
	for i := 0; i < len(args); i++ {
		if args[i] == "--ficha" && i+1 < len(args) {
			fichaID = args[i+1]
			i++
		} else if args[i] == "--limit" && i+1 < len(args) {
			if n, err := strconv.Atoi(args[i+1]); err == nil {
				limit = n
			}
			i++
		}
	}

	params, _ := json.Marshal(map[string]interface{}{
		"ficha_id": fichaID, "limit": limit,
	})
	resp, err := doRPCCall("bos.portman.list", params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl port list: %v\n", err)
		return 1
	}
	return printRPCResult(resp)
}

// cmdPortCheck invoca bos.portman.check
func cmdPortCheck(args []string) int {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "bosctl port check: puerto requerido")
		return 2
	}
	port, err := strconv.Atoi(args[0])
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl port check: puerto inválido: %s\n", args[0])
		return 2
	}

	portType := "K8S_CLUSTER_IP"
	ns := "default"
	for i := 1; i < len(args); i++ {
		if args[i] == "--type" && i+1 < len(args) {
			portType = args[i+1]
			i++
		} else if args[i] == "--ns" && i+1 < len(args) {
			ns = args[i+1]
			i++
		}
	}

	params, _ := json.Marshal(map[string]interface{}{
		"port": port, "port_type": portType, "namespace": ns,
	})
	resp, err := doRPCCall("bos.portman.check", params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl port check: %v\n", err)
		return 1
	}
	return printRPCResult(resp)
}

// cmdPortAssign invoca bos.portman.assign
func cmdPortAssign(args []string) int {
	fichaID := ""
	server := ""
	index := 0
	types := "K8S_CLUSTER_IP"
	ns := "default"
	ctxID := "system"

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--ficha":
			if i+1 < len(args) {
				fichaID = args[i+1]
				i++
			}
		case "--server":
			if i+1 < len(args) {
				server = args[i+1]
				i++
			}
		case "--index":
			if i+1 < len(args) {
				if n, err := strconv.Atoi(args[i+1]); err == nil {
					index = n
				}
				i++
			}
		case "--types":
			if i+1 < len(args) {
				types = args[i+1]
				i++
			}
		case "--ns":
			if i+1 < len(args) {
				ns = args[i+1]
				i++
			}
		case "--ctx":
			if i+1 < len(args) {
				ctxID = args[i+1]
				i++
			}
		}
	}

	if fichaID == "" || server == "" {
		fmt.Fprintln(os.Stderr, "bosctl port assign: --ficha y --server son requeridos")
		return 2
	}

	portTypes := strings.Split(types, ",")

	params, _ := json.Marshal(map[string]interface{}{
		"ficha_id":       fichaID,
		"ficha_index":    index,
		"logical_server": server,
		"port_types":     portTypes,
		"namespace":      ns,
		"ctx_id":         ctxID,
	})
	resp, err := doRPCCall("bos.portman.assign", params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl port assign: %v\n", err)
		return 1
	}
	return printRPCResult(resp)
}

// cmdPortRelease invoca bos.portman.release
func cmdPortRelease(args []string) int {
	fichaID := ""
	ctxID := "system"
	for i := 0; i < len(args); i++ {
		if args[i] == "--ficha" && i+1 < len(args) {
			fichaID = args[i+1]
			i++
		} else if args[i] == "--ctx" && i+1 < len(args) {
			ctxID = args[i+1]
			i++
		}
	}
	if fichaID == "" {
		fmt.Fprintln(os.Stderr, "bosctl port release: --ficha requerido")
		return 2
	}

	params, _ := json.Marshal(map[string]interface{}{
		"ficha_id": fichaID, "ctx_id": ctxID,
	})
	resp, err := doRPCCall("bos.portman.release", params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl port release: %v\n", err)
		return 1
	}
	return printRPCResult(resp)
}

// cmdPortValidate invoca bos.portman.validate
func cmdPortValidate(_ []string) int {
	resp, err := doRPCCall("bos.portman.validate", nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl port validate: %v\n", err)
		return 1
	}
	return printRPCResult(resp)
}

// cmdPortExport invoca bos.portman.export
func cmdPortExport(args []string) int {
	limit := 500
	for i := 0; i < len(args); i++ {
		if args[i] == "--limit" && i+1 < len(args) {
			if n, err := strconv.Atoi(args[i+1]); err == nil {
				limit = n
			}
			i++
		}
	}

	params, _ := json.Marshal(map[string]interface{}{"limit": limit})
	resp, err := doRPCCall("bos.portman.export", params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl port export: %v\n", err)
		return 1
	}
	if resp.Error != nil {
		fmt.Fprintf(os.Stderr, "error %d: %s\n", resp.Error.Code, resp.Error.Message)
		return 1
	}

	// Extraer el contenido Markdown del result.content
	var result struct {
		Content string `json:"content"`
	}
	if err := json.Unmarshal(resp.Result, &result); err == nil && result.Content != "" {
		fmt.Print(result.Content)
		return 0
	}

	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	enc.SetEscapeHTML(false)
	enc.Encode(resp.Result)
	return 0
}

// printRPCResult imprime el resultado JSON-RPC al stdout.
func printRPCResult(resp *rpcResponse) int {
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
