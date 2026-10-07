// bosctl web domain — Domain Manager S16-webserver (BC-06).
//
// Interface Dual (ADR-020): estos comandos usan WebSocket RPC (Vía 1).
// Los mismos métodos están disponibles vía JSON-RPC 2.0 (Vía 2).
//
// Uso:
//
//	bosctl web domain add    --domain <host> --target <destino> [--ssl]
//	bosctl web domain remove --domain <host>
//	bosctl web domain list
//	bosctl web domain resolve --domain <host>
//	bosctl web domain ssl-status --domain <host>
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
)

// cmdWeb enruta el subcomando web.
func cmdWeb(args []string) int {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "bosctl web: subcomando requerido")
		fmt.Fprintln(os.Stderr, "  subcomandos: domain")
		return 2
	}
	switch args[0] {
	case "domain":
		return cmdWebDomain(args[1:])
	default:
		fmt.Fprintf(os.Stderr, "bosctl web: subcomando desconocido: %s\n", args[0])
		return 2
	}
}

// cmdWebDomain enruta el subcomando web domain.
func cmdWebDomain(args []string) int {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "bosctl web domain: subcomando requerido")
		fmt.Fprintln(os.Stderr, "  subcomandos: add, remove, list, resolve, ssl-status")
		return 2
	}
	sub := args[0]
	rest := args[1:]
	switch sub {
	case "add":
		return cmdWebDomainAdd(rest)
	case "remove":
		return cmdWebDomainRemove(rest)
	case "list":
		return cmdWebDomainList(rest)
	case "resolve":
		return cmdWebDomainResolve(rest)
	case "ssl-status":
		return cmdWebDomainSSLStatus(rest)
	default:
		fmt.Fprintf(os.Stderr, "bosctl web domain: subcomando desconocido: %s\n", sub)
		return 2
	}
}

// cmdWebDomainAdd registra un dominio web.
//
//	bosctl web domain add --domain api.empresa.com --target 10.0.0.5:8080 [--ssl] [--ctx-id <id>]
func cmdWebDomainAdd(args []string) int {
	fs := flag.NewFlagSet("web domain add", flag.ContinueOnError)
	domain := fs.String("domain", "", "hostname RFC 1123 (ej: api.empresa.com)")
	target := fs.String("target", "", "IP o host:puerto de destino")
	ssl := fs.Bool("ssl", false, "provisionar SSL automáticamente (certbot)")
	ctxID := fs.String("ctx-id", "", "contexto de auditoría (SBOS-049)")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	if *domain == "" || *target == "" {
		fmt.Fprintln(os.Stderr, "bosctl web domain add: --domain y --target son requeridos")
		return 2
	}

	params, _ := json.Marshal(map[string]interface{}{
		"domain":   *domain,
		"target":   *target,
		"ssl_auto": *ssl,
		"ctx_id":   *ctxID,
	})
	resp, err := doRPCCall("bos.web.domain.add", params)
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

// cmdWebDomainRemove elimina un dominio web.
//
//	bosctl web domain remove --domain api.empresa.com [--ctx-id <id>]
func cmdWebDomainRemove(args []string) int {
	fs := flag.NewFlagSet("web domain remove", flag.ContinueOnError)
	domain := fs.String("domain", "", "hostname a eliminar")
	ctxID := fs.String("ctx-id", "", "contexto de auditoría")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	if *domain == "" {
		fmt.Fprintln(os.Stderr, "bosctl web domain remove: --domain es requerido")
		return 2
	}

	params, _ := json.Marshal(map[string]string{
		"domain": *domain,
		"ctx_id": *ctxID,
	})
	resp, err := doRPCCall("bos.web.domain.remove", params)
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

// cmdWebDomainList lista todos los dominios registrados.
//
//	bosctl web domain list
func cmdWebDomainList(_ []string) int {
	resp, err := doRPCCall("bos.web.domain.list", json.RawMessage("{}"))
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

// cmdWebDomainResolve retorna el registro completo de un dominio.
//
//	bosctl web domain resolve --domain api.empresa.com
func cmdWebDomainResolve(args []string) int {
	fs := flag.NewFlagSet("web domain resolve", flag.ContinueOnError)
	domain := fs.String("domain", "", "hostname a resolver")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	if *domain == "" {
		fmt.Fprintln(os.Stderr, "bosctl web domain resolve: --domain es requerido")
		return 2
	}

	params, _ := json.Marshal(map[string]string{"domain": *domain})
	resp, err := doRPCCall("bos.web.domain.resolve", params)
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

// cmdWebDomainSSLStatus consulta el estado del certificado TLS del dominio.
//
//	bosctl web domain ssl-status --domain api.empresa.com
func cmdWebDomainSSLStatus(args []string) int {
	fs := flag.NewFlagSet("web domain ssl-status", flag.ContinueOnError)
	domain := fs.String("domain", "", "hostname a consultar")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	if *domain == "" {
		fmt.Fprintln(os.Stderr, "bosctl web domain ssl-status: --domain es requerido")
		return 2
	}

	params, _ := json.Marshal(map[string]string{"domain": *domain})
	resp, err := doRPCCall("bos.web.domain.ssl_status", params)
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
