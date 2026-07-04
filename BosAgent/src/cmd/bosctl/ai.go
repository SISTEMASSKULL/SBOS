package main

// ai.go — F10.8/F10.9: bosctl ai — frontend del agente biaos.
//
//	bosctl ai run "<intención>"        agente ReAct (bos.ai.run)
//	bosctl ai confirm <sesion_id>      confirma una acción HITL (bos.ai.confirm)
//	bosctl ai catalog                  herramientas disponibles (bos.ai.catalog)
//	bosctl ai export-training [salida]  dataset SFT desde el audit JSONL (F10.9)

import (
	"encoding/json"
	"fmt"
	"os"

	"bos/internal/biaos/audit"
	"bos/internal/paths"
)

const defaultAIAuditLog = paths.AIAuditLog

// cmdAI despacha `bosctl ai ...`.
func cmdAI(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, usageAI)
		return 2
	}
	switch args[0] {
	case "run":
		return aiRun(args[1:])
	case "confirm":
		return aiConfirm(args[1:])
	case "catalog":
		return aiCatalog()
	case "export-training":
		return aiExportTraining(args[1:])
	case "--help", "-h", "help":
		fmt.Fprintln(os.Stderr, usageAI)
		return 0
	default:
		fmt.Fprintf(os.Stderr, "bosctl ai: subcomando desconocido %q\n%s\n", args[0], usageAI)
		return 2
	}
}

func aiRun(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "bosctl ai run: falta la intención")
		return 2
	}
	params, _ := json.Marshal(map[string]string{"intencion": args[0]})
	return aiRPCImprimir("bos.ai.run", params)
}

func aiConfirm(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "bosctl ai confirm: falta el sesion_id")
		return 2
	}
	params, _ := json.Marshal(map[string]string{"sesion_id": args[0]})
	return aiRPCImprimir("bos.ai.confirm", params)
}

func aiCatalog() int {
	return aiRPCImprimir("bos.ai.catalog", nil)
}

func aiRPCImprimir(method string, params json.RawMessage) int {
	resp, err := doRPCCall(method, params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ai: %v\n", err)
		return 6
	}
	if resp.Error != nil {
		fmt.Fprintf(os.Stderr, "error %d: %s\n", resp.Error.Code, resp.Error.Message)
		return 1
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	enc.SetEscapeHTML(false)
	enc.Encode(json.RawMessage(resp.Result))
	return 0
}

// aiExportTraining lee el audit JSONL local y escribe el dataset SFT (F10.9).
// Es una operación local (no RPC): lee /var/log/bos/ai-audit.jsonl.
func aiExportTraining(args []string) int {
	salida := "bos-ai-training.jsonl"
	if len(args) > 0 {
		salida = args[0]
	}
	eventos, err := audit.LeerEventos(defaultAIAuditLog)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ai export-training: no se pudo leer %s: %v\n", defaultAIAuditLog, err)
		return 1
	}
	ejemplos := audit.ExportarDataset(eventos)
	if err := audit.EscribirDataset(ejemplos, salida); err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ai export-training: escribir %s: %v\n", salida, err)
		return 1
	}
	fmt.Printf("Dataset de entrenamiento: %d ejemplos desde %d eventos → %s\n",
		len(ejemplos), len(eventos), salida)
	return 0
}

const usageAI = `bosctl ai — agente OS biaos (F10)

Uso:
  bosctl ai run "<intención>"        diagnóstico/acción vía agente ReAct
  bosctl ai confirm <sesion_id>      confirma una acción que requería HITL
  bosctl ai catalog                  herramientas del agente (acciones ICAP)
  bosctl ai export-training [salida] dataset SFT desde el audit (default: bos-ai-training.jsonl)

El agente NUNCA genera comandos: mapea la intención a una acción del
catálogo declarativo. Las acciones de riesgo>bajo requieren confirmación.

Ejemplos:
  bosctl ai run "diagnostica el estado del servidor"
  bosctl ai run "el pod kube-state-metrics está en CrashLoopBackOff"
  bosctl ai catalog`
