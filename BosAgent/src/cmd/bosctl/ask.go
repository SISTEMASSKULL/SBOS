// Subcomando de IA: bosctl ia <pregunta|diagnose|explain|plan|ls> [--model=<m>].
package main

import (
	"fmt"
	"os"
	"strings"

	ai "bos/internal/biaos"
	"bos/internal/catalog"
	"bos/internal/state"
)

// cmdAsk es el dispatcher del subcomando "bosctl ia" con soporte a --model= y subcomandos.
func cmdAsk(args []string) int {
	// Parse --model= flag. Must appear before the subcommand or query.
	modelOverride := ""
	filtered := make([]string, 0, len(args))
	for _, a := range args {
		if strings.HasPrefix(a, "--model=") {
			modelOverride = strings.TrimPrefix(a, "--model=")
		} else {
			filtered = append(filtered, a)
		}
	}

	if len(filtered) == 0 {
		fmt.Fprintln(os.Stderr, "Usage: bosctl ia [--model=<m>] <ls|diagnose|explain|plan|<pregunta>>")
		fmt.Fprintln(os.Stderr, "  bosctl ia ls                 Listar modelos IA disponibles")
		fmt.Fprintln(os.Stderr, "  --model=deepseek             Forzar DeepSeek (primary)")
		fmt.Fprintln(os.Stderr, "  --model=claude               Forzar Claude (fallback)")
		fmt.Fprintln(os.Stderr, "  --model=local                Forzar Ollama local")
		return 1
	}

	switch filtered[0] {
	case "ls", "list":
		return cmdAskList(modelOverride)
	case "diagnose":
		return runAskWithModel("Diagnostica el estado actual del BOS. Revisa las fichas, estados, uso de recursos, y dime si hay algo que requiera atencion. Si todo esta bien, dilo claramente.", "", modelOverride)
	case "explain":
		if len(filtered) < 2 {
			fmt.Fprintln(os.Stderr, "Usage: bosctl ask explain <ficha-id>")
			return 1
		}
		fichaID := filtered[1]
		prompt := fmt.Sprintf("Explica que es la ficha '%s', que hace, como esta configurada y cual es su rol en el sistema BOS.", fichaID)
		return runAskWithModel(prompt, fichaID, modelOverride)
	case "plan":
		if len(filtered) < 2 {
			fmt.Fprintln(os.Stderr, "Usage: bosctl ask plan <objetivo...>")
			return 1
		}
		objetivo := strings.Join(filtered[1:], " ")
		prompt := fmt.Sprintf("Propon un plan de accion paso a paso para: %s. Usa comandos bosctl siempre que sea posible. Indica riesgos y alternativas.", objetivo)
		return runAskWithModel(prompt, "", modelOverride)
	default:
		return runAskWithModel(strings.Join(filtered, " "), "", modelOverride)
	}
}

// runAskWithModel envía prompt al modelo IA con contexto BOS y escribe la respuesta a stdout.
// NUNCA registrar contraseñas ni tokens en logs (ADR-003 Level 3 Efectos).
func runAskWithModel(prompt, fichaFocus, modelOverride string) int {
	mgr, err := state.NewManager(statePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ask: open state: %v\n", err)
		return 1
	}
	defer mgr.Close()

	ctx := ai.BuildContext(mgr)

	if fichaFocus != "" {
		cat := catalog.New(mgr)
		cf, err := cat.GetFicha(fichaFocus)
		if err != nil {
			fmt.Fprintf(os.Stderr, "bosctl ask: ficha %s: %v\n", fichaFocus, err)
			return 1
		}
		if cf == nil {
			fmt.Fprintf(os.Stderr, "bosctl ask: ficha %s not found\n", fichaFocus)
			return 3
		}
		ctx.StateSummary = fmt.Sprintf("Ficha enfocada: %s v=%s state=%s backend=%s server=%s category=%d",
			cf.Name, cf.Version, cf.State, cf.Backend, cf.Server, cf.Category)
	}

	client, err := ai.NewClient()
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ask: %v\n", err)
		fmt.Fprintln(os.Stderr, "  Configure: ANTHROPIC_API_KEY, DEEPSEEK_API_KEY, or ensure OLLAMA_HOST is reachable")
		return 1
	}

	// Set model override before checking stats (so pre-call display is accurate).
	if modelOverride != "" {
		client.SetModelOverride(modelOverride)
	}

	// Show which backend will be used.
	preStats := client.RouterStats()
	fmt.Fprintf(os.Stderr, "→ %s [tier=%s]", preStats.ActiveModel, preStats.State)
	if preStats.PrimaryLimited {
		fmt.Fprintf(os.Stderr, " [primary cooldown: %s]", preStats.PrimaryCooldownRem)
	}
	if preStats.FallbackLimited {
		fmt.Fprintf(os.Stderr, " [fallback cooldown: %s]", preStats.FallbackCooldownRem)
	}
	fmt.Fprintln(os.Stderr)

	response, err := client.Ask(prompt, ctx, modelOverride)
	if err != nil {
		// Friendly message: tell the operator exactly what's wrong.
		fmt.Fprintln(os.Stderr, "sin conexion o sin tokens disponibles")
		return 1
	}

	// Si ocurrió cascade (sin override manual), mostrar el modelo que se usó realmente.
	postStats := client.RouterStats()
	if modelOverride == "" && postStats.State != preStats.State {
		fmt.Fprintf(os.Stderr, "  ↳ cascaded to %s [tier=%s]\n", postStats.ActiveModel, postStats.State)
	}

	fmt.Println(response)
	return 0
}

// cmdAskList muestra los modelos IA disponibles con estado de cooldown y tokens usados.
func cmdAskList(modelOverride string) int {
	client, err := ai.NewClient()
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl ia ls: %v\n", err)
		return 1
	}

	stats := client.RouterStats()

	fmt.Println("MODELOS IA DISPONIBLES")
	fmt.Println("======================")
	fmt.Println()

	// ── Tier 1: Primary ──
	status1 := "disponible"
	if stats.PrimaryLimited {
		status1 = fmt.Sprintf("agotado (cooldown: %s)", stats.PrimaryCooldownRem)
	}
	hasKey1 := " (sin API key)"
	if status1 == "disponible" {
		hasKey1 = ""
	}
	fmt.Printf("  [1] PRIMARY   : deepseek (%s) %s%s\n", stats.PrimaryModel, status1, hasKey1)
	fmt.Printf("      alias     : bosctl ia --model=deepseek\n")

	// ── Tier 2: Fallback ──
	status2 := "disponible"
	if stats.FallbackLimited {
		status2 = fmt.Sprintf("agotado (cooldown: %s)", stats.FallbackCooldownRem)
	}
	hasKey2 := " (sin API key)"
	if status2 == "disponible" {
		hasKey2 = ""
	}
	fmt.Printf("  [2] FALLBACK  : claude (%s) %s%s\n", stats.FallbackModel, status2, hasKey2)
	fmt.Printf("      alias     : bosctl ia --model=claude\n")

	// ── Tier 3: Local ──
	localLabel := "ollama"
	if stats.LocalType != "" && stats.LocalType != "ollama" {
		localLabel = stats.LocalType
	}
	fmt.Printf("  [3] LOCAL     : %s (%s)\n", localLabel, stats.LocalModel)
	fmt.Printf("      alias     : bosctl ia --model=local\n")

	// ── Active ──
	fmt.Println()
	fmt.Printf("  → activo ahora : %s [tier=%s]\n", stats.ActiveModel, stats.State)
	if stats.TotalTokens > 0 {
		fmt.Printf("  → tokens usados: %d  |  fallbacks: %d  |  local: %d\n",
			stats.TotalTokens, stats.FallbackCount, stats.LocalCount)
	}
	if stats.LastError != "" {
		fmt.Printf("  → ultimo error : %s\n", stats.LastError)
	}

	fmt.Println()
	fmt.Println("Alias rapidos: bosctl ia --model=deepseek | claude | local")
	return 0
}
