// Package main — usage.go: texto de ayuda de bosctl.
package main

import (
	"fmt"
	"os"
)

func usage() {
	fmt.Fprint(os.Stderr, `bosctl — SBOS daemon control tool

Bootstrap:     bosctl bootstrap start|status|verify|resume|reset
JSON-RPC 2.0:  bosctl rpc bos.ficha.list | bos.health.check | ...
Daemon:        bosctl status|setup [--tui]|release|remove|upgrade|repair
                              bosctl shutdown|logs|reload|health
               bosctl setup --tui (TUI wizard)
Tenant:        bosctl deploy <seed.yml> | tenant suspend|remove|list <id>
Observability: bosctl top|health-report
Identity:      bosctl identity whoami|users|roles|set-role|revoke
Security:      bosctl security scan|audit
Catalog:       bosctl app list|history|rollback
Infra (F9):    bosctl node list|cordon|uncordon|drain|maintain <nodo> [--real]
Context Plane: bosctl ctx list --tenant=<t> | get <ctx_id> | invalidate <ctx_id> | stats
AI Agent:      bosctl ask|ia <pregunta>
Configuration: bosctl set apikey <modelo>=<key>
OS-layer:      bosctl exec|ls|cat|tail|systemctl|journalctl (reemplazan sudo)

BOS_SOCKET  Path al socket Unix (default: /run/bos/bos.sock)
BOS_USER    Identidad para RBAC (vacío = caller confiable)
`)
}
