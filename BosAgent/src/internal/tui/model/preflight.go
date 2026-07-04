// Package model — preflight.go: lógica de bos-preflight (primera instalación).
// Migrado de cmd/bosctl/install_ui_impl.go en BOS-REPAIR F3.MIGRATE.
package model

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"bos/internal/boslog"

	tea "github.com/charmbracelet/bubbletea"
)

// preflightStep define una tarea del preflight con porcentaje y función.
type preflightStep struct {
	pct float64
	msg string
	fn  func() error
}

// PreflightNeeded informa si el preflight debe correr.
// Usa /etc/sbos/.preflight-done como marcador para no repetir en cada arranque.
func PreflightNeeded() bool {
	_, err := os.Stat("/etc/sbos/.preflight-done")
	return os.IsNotExist(err)
}

// preflightSteps devuelve las tareas del preflight con sus porcentajes.
func preflightSteps() []preflightStep {
	return []preflightStep{
		{0.08, "Verificando sistema operativo...", func() error { return nil }},
		{0.15, "Preparando la instalación — verificando entorno...", func() error { return nil }},
		{0.22, "Instalando dependencias del sistema...", func() error {
			return runPreflightBash("ficha_pre_install && ficha_install")
		}},
		{0.45, "Configurando usuario del instalador...", nil},
		{0.58, "Creando directorios del sistema BOS...", nil},
		{0.70, "Configurando cgroup v2 para contenedores...", nil},
		{0.80, "Aplicando permisos y políticas de seguridad...", func() error {
			_ = os.MkdirAll("/etc/bos", 0750)
			const dest = "/etc/bos/bos-bootstrap.env"
			if _, err := os.Stat(dest); os.IsNotExist(err) {
				const tpl = "# bos-bootstrap.env — completar con datos del tenant\n" +
					"BOS_TENANT_NAME=\nBOS_TENANT_NIT=\nBOS_TENANT_PAIS=BO\n" +
					"BOS_TENANT_DOMAIN=\nBOS_ROOT_USER=\nBOS_ADMIN_NOMBRE=\n" +
					"BOS_ROOT_PASSWORD=\nBOS_MFA_ENABLED=true\n"
				_ = os.WriteFile(dest, []byte(tpl), 0640)
			}
			return nil
		}},
		{0.90, "Cargando configuración del tenant...", func() error {
			_ = os.MkdirAll("/etc/sbos", 0750)
			_ = os.WriteFile("/etc/sbos/.preflight-done",
				[]byte(time.Now().UTC().Format(time.RFC3339)+"\n"), 0640)
			return nil
		}},
		{1.0, "Sistema listo — iniciando wizard de instalación ✓", nil},
	}
}

// runPreflightBash ejecuta funciones de task_catalog.sh de bos-preflight.
func runPreflightBash(funcs string) error {
	candidates := []string{
		"/opt/bos/core/servers/S-HOST/bos-preflight/task_catalog.sh",
		"servers/S-HOST/bos-preflight/task_catalog.sh",
	}
	if self, err := os.Executable(); err == nil {
		selfDir := filepath.Dir(self)
		candidates = append([]string{
			filepath.Join(selfDir, "servers/S-HOST/bos-preflight/task_catalog.sh"),
		}, candidates...)
	}

	catalog := ""
	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			catalog = c
			break
		}
	}
	if catalog == "" {
		return nil // Sin script disponible — continuar sin error (desarrollo/CI)
	}

	cmd := exec.Command("bash", "-c",
		fmt.Sprintf(`source %q && %s`, catalog, funcs),
	)
	cmd.Env = append(os.Environ(),
		"__SBOS__STEP_START__=",
		"__SBOS__STEP_OK__=",
		"__SBOS__STEP_FAIL__=",
		"__SBOS__STEP_SKIP__=",
		"FICHA_LOG=/var/log/bos/fichas/bos-preflight.log",
	)
	_ = os.MkdirAll("/var/log/bos/fichas", 0750)
	lf, _ := os.OpenFile("/var/log/bos/fichas/bos-preflight.log",
		os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0640)
	var outBuf bytes.Buffer
	if lf != nil {
		combined := io.MultiWriter(lf, &outBuf)
		cmd.Stdout = combined
		cmd.Stderr = combined
		defer lf.Close()
	} else {
		cmd.Stdout = &outBuf
		cmd.Stderr = &outBuf
	}
	err := cmd.Run()
	logPreflightFailures(outBuf.String())
	if err != nil {
		if summary := preflightFailSummary(outBuf.String()); summary != "" {
			return fmt.Errorf("%s", summary)
		}
		return err
	}
	return nil
}

func logPreflightFailures(output string) {
	for _, line := range strings.Split(output, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "__SBOS__STEP_FAIL__") {
			detail := strings.TrimSpace(strings.TrimPrefix(line, "__SBOS__STEP_FAIL__"))
			boslog.Error("preflight check FALLO", "check", detail)
			continue
		}
		if strings.Contains(line, "FALLO") && strings.Contains(line, "[bos-preflight]") {
			if idx := strings.Index(line, "] "); idx >= 0 {
				boslog.Warn("preflight", "msg", strings.TrimSpace(line[idx+2:]))
			}
		}
	}
}

func preflightFailSummary(output string) string {
	var fails []string
	for _, line := range strings.Split(output, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "__SBOS__STEP_FAIL__") {
			detail := strings.TrimSpace(strings.TrimPrefix(line, "__SBOS__STEP_FAIL__"))
			if detail != "" {
				fails = append(fails, detail)
			}
		}
	}
	return strings.Join(fails, " | ")
}

// StartPreflightCmd arranca el preflight en background y devuelve el primer mensaje.
// INVARIANTE: el goroutine SIEMPRE envía {Done:true} como último mensaje.
func StartPreflightCmd(ch chan PreflightMsg) tea.Cmd {
	return func() tea.Msg {
		go func() {
			var warnings []string
			for _, step := range preflightSteps() {
				ch <- PreflightMsg{Pct: step.pct, Msg: step.msg}
				if step.fn != nil {
					if err := step.fn(); err != nil {
						boslog.Warn("preflight step falló", "step", step.msg, "err", err)
						warnings = append(warnings, step.msg+": "+err.Error())
						ch <- PreflightMsg{Pct: step.pct, Msg: step.msg, Err: err.Error()}
					}
				}
			}
			finalMsg := "Sistema listo ✓"
			if len(warnings) > 0 {
				boslog.Warn("preflight completado con advertencias", "count", len(warnings))
				finalMsg = fmt.Sprintf("Completado con %d advertencia(s)", len(warnings))
			} else {
				boslog.Info("preflight completado OK")
			}
			ch <- PreflightMsg{Pct: 1.0, Msg: finalMsg, Done: true, Warnings: warnings}
		}()
		return <-ch
	}
}

// AwaitPreflight espera el siguiente mensaje del canal de preflight.
func AwaitPreflight(ch chan PreflightMsg) tea.Cmd {
	return func() tea.Msg { return <-ch }
}
