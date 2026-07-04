package ai

import (
	"fmt"
	"os/exec"
	"strings"
	"time"

	"bos/internal/state"
)

// AIContext provides a summary snapshot of the system for the AI model.
type AIContext struct {
	Timestamp    string `json:"timestamp"`
	Hostname     string `json:"hostname"`
	StateSummary string `json:"state_summary"`
	DiskUsage    string `json:"disk_usage"`
	Memory       string `json:"memory"`
	K8sNodes     string `json:"k8s_nodes"`
}

// BuildContext collects system state for the AI prompt.
// All sub-commands have a 10s timeout and are capped at 100 lines.
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
			if f.State == state.StateInstalada || f.State == state.StateDegradada {
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

// Format builds the full user prompt with embedded system context.
func (c *AIContext) Format(prompt string) string {
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
	cmd := exec.Command(name, args...)
	cmd.WaitDelay = 3 * time.Second

	var buf strings.Builder
	cmd.Stdout = &buf
	cmd.Stderr = &buf

	if err := cmd.Start(); err != nil {
		return fmt.Sprintf("(%s: %v)", name, err)
	}

	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()

	select {
	case <-done:
	case <-time.After(10 * time.Second):
		cmd.Process.Kill()
		return fmt.Sprintf("(%s: timeout)", name)
	}

	out := buf.String()
	lines := strings.Split(out, "\n")
	if len(lines) > 100 {
		lines = append(lines[:100], "... (truncated)")
	}
	return strings.Join(lines, "\n")
}
