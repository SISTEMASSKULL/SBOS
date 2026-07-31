package biaos

import (
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"

	"bos/internal/state"
)

// AIContext provee un snapshot resumido del sistema para el modelo IA.
//
// Thread safety: inmutable tras ser creado por BuildContext().
type AIContext struct {
	Timestamp    string `json:"timestamp"`
	Hostname     string `json:"hostname"`
	StateSummary string `json:"state_summary"`
	DiskUsage    string `json:"disk_usage"`
	Memory       string `json:"memory"`
	K8sNodes     string `json:"k8s_nodes"`
}

// BuildContext recopila el estado del sistema para el prompt IA.
// Todos los subcomandos tienen timeout 10s y se truncan a 100 líneas.
//
// Recibe:
//   - mgr: *state.Manager — para leer fichas activas y bloqueadas.
//
// Retorna: *AIContext con snapshot de fichas, disco, memoria y K8s.
//
// Callers conocidos:
//   - cmd/bosctl/app.go:cmdAsk — construye el contexto antes de llamar a Client.Ask.
//
// Efectos secundarios: ejecuta df, free, kubectl get nodes con timeout 10s cada uno.
func BuildContext(mgr *state.Manager) *AIContext {
	ctx := &AIContext{
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Hostname:  hostname(),
	}

	if st, err := mgr.Read(); err == nil {
		var active, blocked []string
		for name, f := range st.Fichas {
			backend := f.Backend
			if backend == "" {
				backend = "-"
			}
			line := fmt.Sprintf("%s v=%s state=%s backend=%s", name, f.Version, f.State, backend)
			if f.State == state.StateInstalled || f.State == state.StateDegraded {
				active = append(active, line)
			} else {
				blocked = append(blocked, line)
			}
		}
		var parts []string
		parts = append(parts, active...)
		// Summarise blocked fichas: show first 5 + total count.
		if len(blocked) > 0 {
			parts = append(parts, fmt.Sprintf("... y %d fichas BLOQUEADA (primeras: %s)",
				len(blocked), strings.Join(blocked[:min(5, len(blocked))], ", ")))
		}
		if len(parts) == 0 {
			ctx.StateSummary = "(no fichas)"
		} else {
			ctx.StateSummary = strings.Join(parts, "\n")
		}
	} else {
		ctx.StateSummary = "(state unavailable)"
	}

	ctx.DiskUsage = runCmd("df", "-h", "/")
	ctx.Memory = runCmd("free", "-h")
	ctx.K8sNodes = runCmd("kubectl", "get", "nodes", "--no-headers")

	return ctx
}

// Format construye el prompt completo para el modelo con el contexto del sistema embebido.
//
// Nil-safe: con receptor nil retorna solo la pregunta — bug latente heredado
// cazado en tests F10 (Ask(prompt, nil, …) panicaba en los 3 backends).
//
// Retorna: string con secciones separadas (contexto del sistema + pregunta del operador).
func (c *AIContext) Format(prompt string) string {
	if c == nil {
		return prompt
	}
	var sb strings.Builder
	sb.WriteString("=== CONTEXTO DEL SISTEMA ===\n")
	sb.WriteString(fmt.Sprintf("Timestamp: %s\n", c.Timestamp))
	sb.WriteString(fmt.Sprintf("Hostname: %s\n", c.Hostname))
	sb.WriteString("\n--- State File ---\n")
	sb.WriteString(c.StateSummary)
	sb.WriteString("\n\n--- Disk Usage (df -h /) ---\n")
	sb.WriteString(c.DiskUsage)
	sb.WriteString("\n--- Memory (free -h) ---\n")
	sb.WriteString(c.Memory)
	sb.WriteString("\n--- K8s Nodes ---\n")
	sb.WriteString(c.K8sNodes)
	sb.WriteString("\n=== PREGUNTA DEL OPERADOR ===\n")
	sb.WriteString(prompt)
	return sb.String()
}

func hostname() string {
	out, err := exec.Command("hostname").Output()
	if err != nil {
		return "unknown"
	}
	return strings.TrimSpace(string(out))
}

func runCmd(name string, args ...string) string {
	// A-13: exec.CommandContext con cancelación limpia en lugar de implementación manual
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, name, args...)
	var buf strings.Builder
	cmd.Stdout = &buf
	cmd.Stderr = &buf
	if err := cmd.Run(); err != nil {
		if ctx.Err() != nil {
			return fmt.Sprintf("(%s: timeout)", name)
		}
		return fmt.Sprintf("(%s: %v)", name, err)
	}
	out := buf.String()
	lines := strings.Split(out, "\n")
	if len(lines) > 100 {
		lines = append(lines[:100], "... (truncated)")
	}
	return strings.Join(lines, "\n")
}
