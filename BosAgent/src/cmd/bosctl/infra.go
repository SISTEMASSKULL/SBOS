package main

// infra.go — F9.10: subcomandos de infraestructura del Operator Soberano.
//
//	bosctl node list
//	bosctl node cordon <nodo>
//	bosctl node uncordon <nodo>
//	bosctl node drain <nodo> [--real]      (dry-run salvo --real)
//	bosctl node maintain <nodo> [--real]   (saga cordon→drain→uncordon)
//
// Vía 2 de la Interface Dual (ADR-019): JSON-RPC bos.k8s.* / bos.maintenance.*.

import (
	"encoding/json"
	"fmt"
	"os"
)

// cmdNode despacha los subcomandos `bosctl node ...`.
func cmdNode(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, usageNode)
		return 2
	}
	sub := args[0]
	resto := args[1:]

	switch sub {
	case "list":
		return nodeList()
	case "cordon", "uncordon":
		if len(resto) < 1 {
			fmt.Fprintf(os.Stderr, "bosctl node %s: falta el nodo\n", sub)
			return 2
		}
		return nodeSimpleOp("bos.k8s.node."+sub, resto[0])
	case "drain":
		if len(resto) < 1 {
			fmt.Fprintln(os.Stderr, "bosctl node drain: falta el nodo")
			return 2
		}
		return nodeDrain(resto[0], tieneFlag(resto, "--real"))
	case "maintain":
		if len(resto) < 1 {
			fmt.Fprintln(os.Stderr, "bosctl node maintain: falta el nodo")
			return 2
		}
		return nodeMaintain(resto[0], tieneFlag(resto, "--real"))
	case "--help", "-h", "help":
		fmt.Fprintln(os.Stderr, usageNode)
		return 0
	default:
		fmt.Fprintf(os.Stderr, "bosctl node: subcomando desconocido %q\n%s\n", sub, usageNode)
		return 2
	}
}

func tieneFlag(args []string, flag string) bool {
	for _, a := range args {
		if a == flag {
			return true
		}
	}
	return false
}

func nodeList() int {
	resp, err := doRPCCall("bos.k8s.node.list", nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl node list: %v\n", err)
		return 6
	}
	if resp.Error != nil {
		fmt.Fprintf(os.Stderr, "error %d: %s\n", resp.Error.Code, resp.Error.Message)
		return 1
	}
	var data struct {
		Nodes []struct {
			Name        string `json:"name"`
			Ready       bool   `json:"ready"`
			Schedulable bool   `json:"schedulable"`
			Version     string `json:"version"`
			InternalIP  string `json:"internal_ip"`
		} `json:"nodes"`
	}
	if err := json.Unmarshal(resp.Result, &data); err != nil {
		fmt.Fprintf(os.Stderr, "respuesta inválida: %v\n", err)
		return 1
	}
	fmt.Printf("%-20s %-8s %-12s %-12s %s\n", "NODO", "READY", "SCHEDULABLE", "VERSIÓN", "IP")
	for _, n := range data.Nodes {
		ready, sched := "✓", "✓"
		if !n.Ready {
			ready = "✗"
		}
		if !n.Schedulable {
			sched = "✗ (cordon)"
		}
		fmt.Printf("%-20s %-8s %-12s %-12s %s\n", n.Name, ready, sched, n.Version, n.InternalIP)
	}
	return 0
}

func nodeSimpleOp(method, node string) int {
	params, _ := json.Marshal(map[string]string{"node": node})
	resp, err := doRPCCall(method, params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl: %v\n", err)
		return 6
	}
	if resp.Error != nil {
		fmt.Fprintf(os.Stderr, "error %d: %s\n", resp.Error.Code, resp.Error.Message)
		return 1
	}
	fmt.Printf("%s: %s OK\n", node, method)
	return 0
}

func nodeDrain(node string, real bool) int {
	params, _ := json.Marshal(map[string]interface{}{"node": node, "dry_run": !real})
	resp, err := doRPCCall("bos.k8s.node.drain", params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl node drain: %v\n", err)
		return 6
	}
	if resp.Error != nil {
		fmt.Fprintf(os.Stderr, "error %d: %s\n", resp.Error.Code, resp.Error.Message)
		return 1
	}
	modo := "dry-run (usar --real para drenar de verdad)"
	if real {
		modo = "REAL"
	}
	fmt.Printf("drain %s [%s]:\n", node, modo)
	var data struct {
		Output string `json:"output"`
	}
	_ = json.Unmarshal(resp.Result, &data)
	fmt.Println(data.Output)
	return 0
}

func nodeMaintain(node string, real bool) int {
	params, _ := json.Marshal(map[string]interface{}{"node": node, "dry_run_drain": !real})
	resp, err := doRPCCall("bos.maintenance.start", params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl node maintain: %v\n", err)
		return 6
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
	enc.Encode(json.RawMessage(resp.Result))
	return 0
}

const usageNode = `bosctl node — gobierno de nodos del cluster (Operator Soberano, F9)

Uso:
  bosctl node list                  nodos con estado Ready/schedulable
  bosctl node cordon <nodo>         marcar no-schedulable (mantenimiento)
  bosctl node uncordon <nodo>       liberar el nodo
  bosctl node drain <nodo>          evacuar pods (DRY-RUN salvo --real)
  bosctl node maintain <nodo>       saga: cordon→drain→uncordon garantizado

Flags:
  --real    drain real (por defecto todo drain es dry-run — en single-node
            un drain real deja el cluster sin capacidad)

Auth: las mutaciones exigen token (BOS_RPC_TOKEN o /etc/bos/rpc-token) y
rol RBAC. Auditadas en /var/log/bos/audit.log (ISO 27001 A.8.15).`
