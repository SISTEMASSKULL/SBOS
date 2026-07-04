// bosctl — CLI de administración del daemon bos.
// Se comunica vía Unix socket (default /run/bos/bos.sock).
// Sobreescribible con variable de entorno BOS_SOCKET.
//
// ADR-001: bosctl es la CLI de capa OS — reemplaza sudo.
// Códigos de salida según SBOS-018 §12: 0 éxito · 1 error · 2 validación · 3 no encontrado ·
// 4 en progreso · 5 dependencia · 6 no disponible · 7 timeout · 8 denegado · 10 interno
package main

import (
	"fmt"
	"os"

	"bos/internal/boslog"
	"bos/internal/paths"
	"github.com/joho/godotenv"
)

const defaultSocket = paths.SocketPath

func main() {
	boslog.Init("bosctl")
	_ = godotenv.Load(paths.EtcBos + "/.env")
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}
	cmd := os.Args[1]
	args := os.Args[2:]
	switch cmd {
	case "dashboard", "dash":
		os.Exit(cmdDashboard(args))
	case "status":
		os.Exit(cmdStatus(args))
	case "preview", "theme-preview":
		os.Exit(cmdThemePreview(args))
	case "setup", "install":
		os.Exit(cmdInstallUI(args))
	case "release":
		os.Exit(cmdRelease(args))
	case "remove":
		os.Exit(cmdRemove(args))
	case "upgrade":
		os.Exit(cmdUpgrade(args))
	case "repair":
		os.Exit(cmdRepair(args))
	case "shutdown":
		os.Exit(cmdShutdown(args))
	case "logs":
		os.Exit(cmdLogs(args))
	case "reload":
		os.Exit(cmdReload(args))
	case "health":
		os.Exit(cmdHealth(args))
	case "top":
		os.Exit(cmdTop(args))
	case "health-report":
		os.Exit(cmdHealthReport(args))
	case "identity":
		os.Exit(cmdIdentity(args))
	case "security":
		os.Exit(cmdSecurity(args))
	case "app":
		os.Exit(cmdApp(args))
	case "ask", "ia":
		os.Exit(cmdAsk(args))
	case "set":
		os.Exit(cmdSet(args))
	case "exec":
		if code := rbacGuard("exec"); code != 0 {
			os.Exit(code)
		}
		os.Exit(cmdExec(args))
	case "ls":
		if code := rbacGuard("ls"); code != 0 {
			os.Exit(code)
		}
		os.Exit(cmdLS(args))
	case "cat":
		if code := rbacGuard("cat"); code != 0 {
			os.Exit(code)
		}
		os.Exit(cmdCat(args))
	case "tail":
		if code := rbacGuard("tail"); code != 0 {
			os.Exit(code)
		}
		os.Exit(cmdTail(args))
	case "systemctl":
		if code := rbacGuard("systemctl"); code != 0 {
			os.Exit(code)
		}
		os.Exit(cmdSystemctl(args))
	case "journalctl":
		if code := rbacGuard("journalctl"); code != 0 {
			os.Exit(code)
		}
		os.Exit(cmdJournalctl(args))
	case "ctx":
		os.Exit(cmdCtx(args))
	case "node":
		os.Exit(cmdNode(args))
	case "vdi":
		os.Exit(cmdVdi(args))
	case "ai":
		os.Exit(cmdAI(args))
	case "query":
		os.Exit(cmdQuery(args))
	case "ficha":
		os.Exit(cmdFicha(args))
	case "deploy":
		os.Exit(cmdDeploy(args))
	case "tenant":
		os.Exit(cmdTenant(args))
	case "bootstrap":
		os.Exit(cmdBootstrap(args))
	case "rpc":
		os.Exit(cmdRPC(args))
	case "system-install":
		os.Exit(cmdSystemInstall(args))
	case "dev":
		os.Exit(cmdDev(args))
	case "help", "-h", "--help":
		usage()
		os.Exit(0)
	default:
		fmt.Fprintf(os.Stderr, "bosctl: unknown command: %s\n", cmd)
		usage()
		os.Exit(2)
	}
}
