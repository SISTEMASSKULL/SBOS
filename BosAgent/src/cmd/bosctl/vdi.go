package main

// vdi.go — F9.9: bosctl vdi verify — certificación del VDI Layer (C-09..C-14).
// Vía 2 (JSON-RPC): bos.query.vdi para el estado agregado del layer.

import (
	"encoding/json"
	"fmt"
	"os"
)

// cmdVdi despacha `bosctl vdi ...`.
func cmdVdi(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, usageVdi)
		return 2
	}
	switch args[0] {
	case "verify":
		return vdiVerify(args[1:])
	case "status":
		return vdiStatus(args[1:])
	case "--help", "-h", "help":
		fmt.Fprintln(os.Stderr, usageVdi)
		return 0
	default:
		fmt.Fprintf(os.Stderr, "bosctl vdi: subcomando desconocido %q\n%s\n", args[0], usageVdi)
		return 2
	}
}

// vdiVerify llama bos.query.vdi y reporta el semáforo del VDI Layer.
func vdiVerify(args []string) int {
	tenant := flagValor(args, "--tenant")
	var params json.RawMessage
	if tenant != "" {
		params, _ = json.Marshal(map[string]string{"tenant_id": tenant})
	}
	resp, err := doRPCCall("bos.query.vdi", params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl vdi verify: %v\n", err)
		return 6
	}
	if resp.Error != nil {
		fmt.Fprintf(os.Stderr, "error %d: %s\n", resp.Error.Code, resp.Error.Message)
		return 1
	}
	var data map[string]interface{}
	if err := json.Unmarshal(resp.Result, &data); err != nil {
		fmt.Fprintf(os.Stderr, "respuesta inválida: %v\n", err)
		return 1
	}
	sem, _ := data["semaforo_vdi"].(string)
	fmt.Printf("VDI Layer — semáforo: %s\n", sem)
	for _, ficha := range []string{"nextcloud", "guacamole", "fedora_logico"} {
		if f, ok := data[ficha].(map[string]interface{}); ok {
			estado := "?"
			if h, ok := f["healthy"].(bool); ok {
				if h {
					estado = "✓ healthy"
				} else {
					estado = "✗ degradado"
				}
			}
			if e, ok := f["error"].(string); ok {
				estado = "✗ " + e
			}
			fmt.Printf("  %-16s %s\n", ficha, estado)
		}
	}
	if sem == "VERDE" {
		return 0
	}
	return 1
}

func vdiStatus(args []string) int {
	return vdiVerify(args) // mismo origen de datos; alias semántico
}

func flagValor(args []string, flag string) string {
	for _, a := range args {
		if len(a) > len(flag)+1 && a[:len(flag)+1] == flag+"=" {
			return a[len(flag)+1:]
		}
	}
	return ""
}

const usageVdi = `bosctl vdi — certificación del VDI Layer (F9.9, C-09..C-14)

Uso:
  bosctl vdi verify [--tenant=<t>]   semáforo del VDI Layer (nextcloud/guacamole/fedora)
  bosctl vdi status [--tenant=<t>]   alias de verify

Exit 0 si el semáforo es VERDE, 1 en caso contrario.`
