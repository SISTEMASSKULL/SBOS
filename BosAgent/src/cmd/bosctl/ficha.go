// Subcomandos de administración de fichas — F11.
//
//	bosctl ficha list|plan|status|install|update|repair|remove|scale|describe|diff|pause|resume|logs|rescan
//
// Interface Dual (ADR-020): estos comandos usan WebSocket RPC (Vía 1).
// Los mismos métodos están disponibles vía JSON-RPC 2.0 (Vía 2) y gRPC.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"

	"bos/internal/domain"
	"bos/internal/plugin"
	"bos/internal/state"
	"bos/internal/paths"

	"log/slog"
)

// cmdFicha enruta el subcomando de ficha al handler correspondiente.
func cmdFicha(args []string) int {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "bosctl ficha: subcomando requerido")
		fmt.Fprintln(os.Stderr, "  subcomandos: list, plan, status, install, update, repair, remove, scale, describe, diff, pause, resume, logs, rescan")
		return 2
	}

	sub := args[0]
	rest := args[1:]

	switch sub {
	case "list":
		return cmdFichaList(rest)
	case "plan":
		return cmdFichaPlan(rest)
	case "status":
		return cmdFichaStatus(rest)
	case "install":
		return cmdFichaInstall(rest)
	case "update":
		return cmdFichaUpdate(rest)
	case "repair":
		return cmdFichaRepair(rest)
	case "remove":
		return cmdFichaRemove(rest)
	case "scale":
		return cmdFichaScale(rest)
	case "describe":
		return cmdFichaDescribe(rest)
	case "diff":
		return cmdFichaDiff(rest)
	case "pause":
		return cmdFichaPause(rest)
	case "resume":
		return cmdFichaResume(rest)
	case "logs":
		return cmdFichaLogs(rest)
	case "rescan":
		return cmdFichaRescan(rest)
	default:
		fmt.Fprintf(os.Stderr, "bosctl ficha: subcomando desconocido: %s\n", sub)
		return 2
	}
}

func buildFichaSvc() (*domain.FichaService, error) {
	stateMgr, err := state.NewManager(paths.StatePath)
	if err != nil {
		return nil, fmt.Errorf("abrir state manager: %w", err)
	}

	logger := slog.New(slog.NewTextHandler(os.Stderr, nil))
	loader := plugin.NewLoader(paths.ServersPath, logger)
	loader.Scan()

	return domain.NewFichaService(nil, stateMgr, loader), nil
}

func printJSON(v interface{}) {
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	enc.Encode(v)
}

func printTable(headers []string, rows [][]string) {
	widths := make([]int, len(headers))
	for i, h := range headers {
		widths[i] = len(h)
	}
	for _, row := range rows {
		for i, cell := range row {
			if i < len(widths) && len(cell) > widths[i] {
				widths[i] = len(cell)
			}
		}
	}
	for i, h := range headers {
		fmt.Printf("%-*s  ", widths[i], strings.ToUpper(h))
	}
	fmt.Println()
	for _, w := range widths {
		fmt.Print(strings.Repeat("-", w) + "  ")
	}
	fmt.Println()
	for _, row := range rows {
		for i, cell := range row {
			if i < len(widths) {
				fmt.Printf("%-*s  ", widths[i], cell)
			}
		}
		fmt.Println()
	}
}

func cmdFichaList(args []string) int {
	fs := flag.NewFlagSet("ficha list", flag.ExitOnError)
	jsonOut := fs.Bool("json", false, "salida JSON")
	fs.Parse(args)

	svc, err := buildFichaSvc()
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha list: %v\n", err)
		return 1
	}

	details := svc.List()
	if *jsonOut {
		printJSON(map[string]interface{}{"fichas": details, "total": len(details)})
		return 0
	}

	if len(details) == 0 {
		fmt.Println("(no hay fichas en el catálogo)")
		return 0
	}

	headers := []string{"ID", "VERSION", "SERVIDOR", "ORDEN", "AUTO"}
	rows := make([][]string, 0, len(details))
	for _, d := range details {
		auto := "no"
		if d.AutoInstall {
			auto = "si"
		}
		rows = append(rows, []string{d.ID, d.Version, d.Server, fmt.Sprintf("%d", d.ExecutionOrder), auto})
	}
	printTable(headers, rows)
	fmt.Printf("\nTotal: %d fichas\n", len(details))
	return 0
}

func cmdFichaPlan(args []string) int {
	fs := flag.NewFlagSet("ficha plan", flag.ExitOnError)
	jsonOut := fs.Bool("json", false, "salida JSON")
	fs.Parse(args)

	svc, err := buildFichaSvc()
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha plan: %v\n", err)
		return 1
	}

	result, err := svc.Plan()
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha plan: %v\n", err)
		return 1
	}

	if *jsonOut {
		printJSON(result)
		return 0
	}

	if result.HasCycles {
		fmt.Println("⚠️  CICLOS DETECTADOS en el grafo de dependencias")
		return 1
	}

	fmt.Printf("Plan topológico — %d fichas en %d oleadas:\n\n", result.Total, len(result.Waves))
	for i, wave := range result.Waves {
		fmt.Printf("Oleada %d (%d fichas):\n", i, len(wave))
		for _, id := range wave {
			fmt.Printf("  - %s\n", id)
		}
	}
	return 0
}

func cmdFichaStatus(args []string) int {
	fs := flag.NewFlagSet("ficha status", flag.ExitOnError)
	jsonOut := fs.Bool("json", false, "salida JSON")
	fs.Parse(args)

	fichaID := ""
	if fs.NArg() > 0 {
		fichaID = fs.Arg(0)
	}

	svc, err := buildFichaSvc()
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha status: %v\n", err)
		return 1
	}

	single, all, err := svc.Status(fichaID)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha status: %v\n", err)
		return 1
	}

	if *jsonOut {
		if single != nil {
			printJSON(single)
		} else {
			printJSON(all)
		}
		return 0
	}

	if single != nil {
		fmt.Printf("Ficha: %s\n", single.ID)
		fmt.Printf("  Estado:  %s\n", single.State)
		fmt.Printf("  Version: %s\n", single.Version)
		fmt.Printf("  Health:  %s\n", single.Health)
		fmt.Printf("  Servidor: %s\n", single.Server)
		return 0
	}

	headers := []string{"ID", "ESTADO", "VERSION", "HEALTH", "SERVIDOR"}
	rows := make([][]string, 0, len(all))
	for _, f := range all {
		rows = append(rows, []string{f.ID, f.State, f.Version, f.Health, f.Server})
	}
	printTable(headers, rows)
	fmt.Printf("\nTotal: %d fichas\n", len(all))
	return 0
}

func cmdFichaInstall(args []string) int {
	fs := flag.NewFlagSet("ficha install", flag.ExitOnError)
	version := fs.String("version", "", "version a instalar")
	fs.Parse(args)

	if fs.NArg() < 1 {
		fmt.Fprintln(os.Stderr, "bosctl ficha install: ficha_id requerido")
		return 2
	}

	svc, err := buildFichaSvc()
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha install: %v\n", err)
		return 1
	}

	outcome, err := svc.Install(fs.Arg(0), *version)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha install: %v\n", err)
		return 1
	}

	if outcome.Success {
		fmt.Printf("✅ %s instalado (%v)\n", fs.Arg(0), outcome.Duration)
	} else {
		fmt.Printf("❌ %s falló (exit %d)\n", fs.Arg(0), outcome.ExitCode)
		return 1
	}
	return 0
}

func cmdFichaRepair(args []string) int {
	fs := flag.NewFlagSet("ficha repair", flag.ExitOnError)
	fs.Parse(args)

	if fs.NArg() < 1 {
		fmt.Fprintln(os.Stderr, "bosctl ficha repair: ficha_id requerido")
		return 2
	}

	svc, err := buildFichaSvc()
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha repair: %v\n", err)
		return 1
	}

	outcome, err := svc.Repair(fs.Arg(0))
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha repair: %v\n", err)
		return 1
	}

	if outcome.Success {
		fmt.Printf("✅ %s reparado (%v)\n", fs.Arg(0), outcome.Duration)
	} else {
		fmt.Printf("❌ repair de %s falló\n", fs.Arg(0))
		return 1
	}
	return 0
}

func cmdFichaScale(args []string) int {
	fs := flag.NewFlagSet("ficha scale", flag.ExitOnError)
	replicas := fs.Int("replicas", 1, "numero de replicas")
	fs.Parse(args)

	if fs.NArg() < 1 {
		fmt.Fprintln(os.Stderr, "bosctl ficha scale: ficha_id requerido")
		return 2
	}

	fmt.Printf("⚠️  Scale de %s a %d replicas — requiere integracion K8s (F9)\n", fs.Arg(0), *replicas)
	fmt.Println("   Use gRPC o JSON-RPC para esta operacion.")
	return 1
}

func cmdFichaDescribe(args []string) int {
	fs := flag.NewFlagSet("ficha describe", flag.ExitOnError)
	jsonOut := fs.Bool("json", false, "salida JSON")
	fs.Parse(args)

	if fs.NArg() < 1 {
		fmt.Fprintln(os.Stderr, "bosctl ficha describe: ficha_id requerido")
		return 2
	}
	fichaID := fs.Arg(0)

	svc, err := buildFichaSvc()
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha describe: %v\n", err)
		return 1
	}

	// Obtener detalle del catálogo
	manifests := svc.List()
	var manifest *domain.FichaDetail
	for _, m := range manifests {
		if m.ID == fichaID {
			manifest = &m
			break
		}
	}

	// Obtener estado
	single, _, err := svc.Status(fichaID)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha describe: %v\n", err)
		return 1
	}

	if *jsonOut {
		result := map[string]interface{}{
			"ficha":  single,
		}
		if manifest != nil {
			result["manifest"] = map[string]interface{}{
				"auto_install":    manifest.AutoInstall,
				"execution_order": manifest.ExecutionOrder,
				"dependencies":    manifest.Dependencies,
			}
		}
		printJSON(result)
		return 0
	}

	// ── Salida detallada ──────────────────────────────────────────
	stateIcon := "✅"
	switch single.State {
	case "DEGRADADA":
		stateIcon = "🟡"
	case "ERROR_FISICO", "ERROR_LOGICO", "ERROR_NO_CORREGIBLE":
		stateIcon = "🔴"
	case "PAUSADA":
		stateIcon = "⏸️"
	case "INSTALANDO", "REPARANDO", "ACTUALIZANDO":
		stateIcon = "⏳"
	}

	fmt.Printf("%s %s — %s v%s\n\n", stateIcon, fichaID, single.State, single.Version)

	fmt.Println("── Identidad ──")
	fmt.Printf("  Servidor:       %s\n", single.Server)
	fmt.Printf("  Health:         %s\n", single.Health)
	if manifest != nil {
		fmt.Printf("  Auto-install:   %v\n", manifest.AutoInstall)
		fmt.Printf("  Orden:          %d\n", manifest.ExecutionOrder)
		if len(manifest.Dependencies) > 0 {
			fmt.Printf("  Dependencias:   %s\n", strings.Join(manifest.Dependencies, ", "))
		}
	}

	fmt.Println("\n── Ciclo de vida ──")
	if !single.InstalledAt.IsZero() {
		fmt.Printf("  Instalada:      %s\n", single.InstalledAt.Format("2006-01-02 15:04:05"))
	}
	fmt.Printf("  Actualizada:    %s\n", single.UpdatedAt.Format("2006-01-02 15:04:05"))

	fmt.Println("\n── Archivos ──")
	fmt.Printf("  Config:         /etc/bos/servers/%s/%s/\n", single.Server, fichaID)
	fmt.Printf("  Log:            /var/log/bos/fichas/%s.log\n", fichaID)
	fmt.Printf("  Dashboard:      resources/dashboard.json\n")

	fmt.Println("\n── Operaciones ──")
	fmt.Printf("  Instalar:       bosctl ficha install %s\n", fichaID)
	fmt.Printf("  Reparar:        bosctl ficha repair %s\n", fichaID)
	fmt.Printf("  Estado:         bosctl ficha status %s\n", fichaID)
	fmt.Printf("  Logs:           bosctl ficha logs %s\n", fichaID)
	fmt.Printf("  Diff:           bosctl ficha diff %s\n", fichaID)
	fmt.Printf("  Pausar:         bosctl ficha pause %s\n", fichaID)

	return 0
}

func cmdFichaDiff(args []string) int {
	fs := flag.NewFlagSet("ficha diff", flag.ExitOnError)
	jsonOut := fs.Bool("json", false, "salida JSON")
	fs.Parse(args)

	fichaID := ""
	if fs.NArg() > 0 {
		fichaID = fs.Arg(0)
	}

	svc, err := buildFichaSvc()
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha diff: %v\n", err)
		return 1
	}

	single, summary, err := svc.Diff(fichaID)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha diff: %v\n", err)
		return 1
	}

	if *jsonOut {
		if single != nil {
			printJSON(single)
		} else {
			printJSON(summary)
		}
		return 0
	}

	if single != nil {
		if single.HasDrift {
			fmt.Printf("⚠️  Drift detectado en %s:\n", single.FichaID)
			for _, item := range single.Items {
				fmt.Printf("  - %s: declarado=%s actual=%s\n", item.Path, item.Declared, item.Actual)
			}
		} else {
			fmt.Printf("✅ %s: sin drift\n", single.FichaID)
		}
		return 0
	}

	fmt.Printf("Resumen de drift — %d fichas:\n", summary.TotalFichas)
	fmt.Printf("  ✅ Sin drift: %d\n", summary.OkFichas)
	fmt.Printf("  ⚠️  Con drift: %d\n", summary.DriftedFichas)
	return 0
}

func cmdFichaPause(args []string) int {
	fs := flag.NewFlagSet("ficha pause", flag.ExitOnError)
	fs.Parse(args)

	if fs.NArg() < 1 {
		fmt.Fprintln(os.Stderr, "bosctl ficha pause: ficha_id requerido")
		return 2
	}

	svc, err := buildFichaSvc()
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha pause: %v\n", err)
		return 1
	}

	outcome, err := svc.Pause(fs.Arg(0))
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha pause: %v\n", err)
		return 1
	}

	if outcome.Success {
		fmt.Printf("⏸️  %s pausado\n", fs.Arg(0))
	} else {
		fmt.Printf("❌ no se pudo pausar %s\n", fs.Arg(0))
		return 1
	}
	return 0
}

func cmdFichaLogs(args []string) int {
	fs := flag.NewFlagSet("ficha logs", flag.ExitOnError)
	tail := fs.Int("tail", 50, "ultimas N lineas")
	fs.Parse(args)

	if fs.NArg() < 1 {
		fmt.Fprintln(os.Stderr, "bosctl ficha logs: ficha_id requerido")
		return 2
	}

	fichaID := fs.Arg(0)

	rawParams, _ := json.Marshal(map[string]interface{}{
		"ficha_id":   fichaID,
		"tail_lines": *tail,
	})
	resp, err := doRPCCall("bos.ficha.logs", rawParams)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha logs: %v\n", err)
		return 6
	}
	if resp.Error != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha logs: error %d: %s\n", resp.Error.Code, resp.Error.Message)
		return 1
	}

	data, _ := json.Marshal(resp.Result)
	var result struct {
		FichaID string `json:"ficha_id"`
		Lines   []struct {
			Ts      string `json:"ts"`
			Level   string `json:"level"`
			Message string `json:"message"`
			LineNo  int    `json:"line_no"`
		} `json:"lines"`
	}
	if err := json.Unmarshal(data, &result); err != nil || len(result.Lines) == 0 {
		fmt.Printf("(sin entradas de log para %s)\n", fichaID)
		return 0
	}
	for _, e := range result.Lines {
		fmt.Printf("[%s] %-5s %s\n", e.Ts, e.Level, e.Message)
	}
	return 0
}

func cmdFichaRescan(args []string) int {
	fs := flag.NewFlagSet("ficha rescan", flag.ExitOnError)
	jsonOut := fs.Bool("json", false, "salida JSON")
	fs.Parse(args)

	svc, err := buildFichaSvc()
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha rescan: %v\n", err)
		return 1
	}

	result, err := svc.Rescan()
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha rescan: %v\n", err)
		return 1
	}

	if *jsonOut {
		printJSON(result)
		return 0
	}

	fmt.Printf("🔍 Rescan completado:\n")
	fmt.Printf("  Descubiertas: %d\n", result.Discovered)
	fmt.Printf("  Total: %d\n", result.Total)
	if len(result.Added) > 0 {
		fmt.Printf("  Nuevas:\n")
		for _, id := range result.Added {
			fmt.Printf("    - %s\n", id)
		}
	}
	return 0
}

func cmdFichaUpdate(args []string) int {
	fs := flag.NewFlagSet("ficha update", flag.ExitOnError)
	version := fs.String("version", "", "version a actualizar (obligatorio)")
	fs.Parse(args)

	if fs.NArg() < 1 {
		fmt.Fprintln(os.Stderr, "bosctl ficha update: ficha_id requerido")
		return 2
	}
	if *version == "" {
		fmt.Fprintln(os.Stderr, "bosctl ficha update: --version requerido")
		return 2
	}

	svc, err := buildFichaSvc()
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha update: %v\n", err)
		return 1
	}

	outcome, err := svc.Update(fs.Arg(0), *version)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha update: %v\n", err)
		return 1
	}

	if outcome.Success {
		fmt.Printf("✅ %s actualizado a %s (%v)\n", fs.Arg(0), *version, outcome.Duration)
	} else {
		fmt.Printf("❌ update de %s falló (exit %d)\n", fs.Arg(0), outcome.ExitCode)
		return 1
	}
	return 0
}

func cmdFichaRemove(args []string) int {
	fs := flag.NewFlagSet("ficha remove", flag.ExitOnError)
	fs.Parse(args)

	if fs.NArg() < 1 {
		fmt.Fprintln(os.Stderr, "bosctl ficha remove: ficha_id requerido")
		return 2
	}

	svc, err := buildFichaSvc()
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha remove: %v\n", err)
		return 1
	}

	outcome, err := svc.Remove(fs.Arg(0))
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha remove: %v\n", err)
		return 1
	}

	if outcome.Success {
		fmt.Printf("✅ %s eliminado (%v)\n", fs.Arg(0), outcome.Duration)
	} else {
		fmt.Printf("❌ remove de %s falló\n", fs.Arg(0))
		return 1
	}
	return 0
}

func cmdFichaResume(args []string) int {
	fs := flag.NewFlagSet("ficha resume", flag.ExitOnError)
	fs.Parse(args)

	if fs.NArg() < 1 {
		fmt.Fprintln(os.Stderr, "bosctl ficha resume: ficha_id requerido")
		return 2
	}

	svc, err := buildFichaSvc()
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha resume: %v\n", err)
		return 1
	}

	outcome, err := svc.Resume(fs.Arg(0))
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ficha resume: %v\n", err)
		return 1
	}

	if outcome.Success {
		fmt.Printf("▶️  %s reanudado\n", fs.Arg(0))
	} else {
		fmt.Printf("❌ no se pudo reanudar %s\n", fs.Arg(0))
		return 1
	}
	return 0
}
