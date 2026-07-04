package main

// query.go — F6.13 (BOS-REPAIR-04): bosctl query <tipo> — frontend humano
// de las sagas de consulta bos.query.*.
//
//	bosctl query system  [--tenant=<t>]
//	bosctl query repair  <ficha> [--tenant=<t>]
//	bosctl query vdi     [--tenant=<t>]
//	bosctl query tenant  <tenant>
//	bosctl query node    <nodo>
//	bosctl query context --tenant=<t>
//
// Salida JSON identada (las sagas ya retornan vistas estructuradas).

import (
	"encoding/json"
	"fmt"
	"os"
)

// cmdQuery despacha `bosctl query ...`.
func cmdQuery(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, usageQuery)
		return 2
	}
	tipo := args[0]
	resto := args[1:]
	tenant := flagValor(resto, "--tenant")

	var metodo string
	params := map[string]interface{}{}

	switch tipo {
	case "system":
		metodo = "bos.query.system"
		if tenant != "" {
			params["tenant_id"] = tenant
		}
	case "repair":
		if len(resto) == 0 || resto[0] == "" || resto[0][0] == '-' {
			fmt.Fprintln(os.Stderr, "bosctl query repair: falta la ficha")
			return 2
		}
		metodo = "bos.query.repair"
		params["ficha_id"] = resto[0]
		if tenant != "" {
			params["tenant_id"] = tenant
		}
	case "vdi":
		metodo = "bos.query.vdi"
		if tenant != "" {
			params["tenant_id"] = tenant
		}
	case "tenant":
		if len(resto) == 0 {
			fmt.Fprintln(os.Stderr, "bosctl query tenant: falta el tenant")
			return 2
		}
		metodo = "bos.query.tenant"
		params["tenant_id"] = resto[0]
	case "node":
		if len(resto) == 0 {
			fmt.Fprintln(os.Stderr, "bosctl query node: falta el nodo")
			return 2
		}
		metodo = "bos.query.node"
		params["node"] = resto[0]
	case "context":
		if tenant == "" {
			fmt.Fprintln(os.Stderr, "bosctl query context: requiere --tenant=<t>")
			return 2
		}
		metodo = "bos.query.context"
		params["tenant_id"] = tenant
	case "--help", "-h", "help":
		fmt.Fprintln(os.Stderr, usageQuery)
		return 0
	default:
		fmt.Fprintf(os.Stderr, "bosctl query: tipo desconocido %q\n%s\n", tipo, usageQuery)
		return 2
	}

	var raw json.RawMessage
	if len(params) > 0 {
		raw, _ = json.Marshal(params)
	}
	return aiRPCImprimir(metodo, raw)
}

const usageQuery = `bosctl query — sagas de consulta multi-fuente (F6, <4s)

Uso:
  bosctl query system  [--tenant=<t>]   Ubuntu+K8s+fichas+ctx+certificación
  bosctl query repair  <ficha> [--tenant=<t>]   pre-diagnóstico de reparación
  bosctl query vdi     [--tenant=<t>]   VDI Layer con semáforo
  bosctl query tenant  <tenant>          snapshot completo del tenant
  bosctl query node    <nodo>            diagnóstico pre-mantenimiento
  bosctl query context --tenant=<t>      Context Plane: estados, TTLs, anomalías

Ejemplos:
  bosctl query system
  bosctl query repair nextcloud --tenant=skull
  bosctl query node vmi3346550`
