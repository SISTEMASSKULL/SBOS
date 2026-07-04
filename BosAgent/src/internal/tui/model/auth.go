// Package model — auth.go: forms de autenticación y comandos JSON-RPC para bauth.
//
// VALIDACIÓN EN FORMS (huh v1.0.0):
//   - Validate(func(string) error) se dispara en Tab/Enter y al perder foco
//   - Los errores aparecen en el footer del Group (bajo todos los campos)
//   - El form bloquea la navegación al siguiente campo hasta que la validación pase
//   - Para errores de red (login fallido) se usa m.AuthErr (renderizado en la screen)
//
// NOTIFICACIONES (investación 2026-06-14):
//   - No existe librería de toast/overlay compatible con BubbleTea v1.x
//   - github.com/ceffo/toast requiere BubbleTea v2 (incompatible)
//   - Patrón recomendado: NotifyBar() de styles/ en el pie del View() via m.AuthErr
package model

import (
	"encoding/json"
	"fmt"
	"net"
	"strings"
	"time"
	"unicode"

	tea "github.com/charmbracelet/bubbletea"
	"bos/internal/tui/styles"
	"github.com/charmbracelet/huh"
)

// ── Validadores reutilizables ────────────────────────────────────────────────

// validateNotEmpty retorna error si el campo está vacío.
func validateNotEmpty(label string) func(string) error {
	return func(s string) error {
		if strings.TrimSpace(s) == "" {
			return fmt.Errorf("%s no puede estar vacío", label)
		}
		return nil
	}
}

// validateEmail retorna error si el string no tiene formato de email básico.
func validateEmail(s string) error {
	s = strings.TrimSpace(s)
	if s == "" {
		return fmt.Errorf("el usuario no puede estar vacío")
	}
	if !strings.Contains(s, "@") || !strings.Contains(s, ".") {
		return fmt.Errorf("ingresa un correo válido (ejemplo: admin@empresa.local)")
	}
	at := strings.LastIndex(s, "@")
	if at == 0 || at == len(s)-1 {
		return fmt.Errorf("formato de correo inválido")
	}
	return nil
}

// validatePassword valida que la contraseña no esté vacía y cumpla requisitos mínimos.
func validatePassword(s string) error {
	if s == "" {
		return fmt.Errorf("la contraseña no puede estar vacía")
	}
	if len(s) < 8 {
		return fmt.Errorf("la contraseña debe tener al menos 8 caracteres")
	}
	hasUpper, hasDigit := false, false
	for _, r := range s {
		if unicode.IsUpper(r) {
			hasUpper = true
		}
		if unicode.IsDigit(r) {
			hasDigit = true
		}
	}
	if !hasUpper || !hasDigit {
		return fmt.Errorf("la contraseña debe contener al menos una mayúscula y un número")
	}
	return nil
}

// validatePIN valida el campo de contraseña/PIN para step-up (mínimo 4 chars).
func validatePIN(s string) error {
	if s == "" {
		return fmt.Errorf("debes ingresar tu contraseña o PIN")
	}
	if len(s) < 4 {
		return fmt.Errorf("mínimo 4 caracteres requeridos")
	}
	return nil
}

// ── Constructores de formularios ─────────────────────────────────────────────

// NewAuthLoginForm construye el huh.Form de login con validación inline.
// Vincula &m.AuthUser y &m.AuthPass — los errores de validación aparecen en el
// footer del group automáticamente (huh v1.0.0 comportamiento nativo).
func NewAuthLoginForm(m *Model) *huh.Form {
	return huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Usuario").
				Placeholder("admin@empresa.local").
				Value(&m.AuthUser).
				Validate(validateEmail),
			huh.NewInput().
				Title("Contraseña").
				EchoMode(huh.EchoModePassword).
				Value(&m.AuthPass).
				Validate(validatePassword),
		),
	).WithWidth(60).WithKeyMap(styles.HuhKeyMap()).WithTheme(styles.HuhTheme())
}

// NewAuthConfirmForm construye el huh.Form de step-up LoA 3.
// Muestra la acción solicitada (m.AuthConfirmAction) y valida el PIN/contraseña.
func NewAuthConfirmForm(m *Model) *huh.Form {
	action := m.AuthConfirmAction
	if action == "" {
		action = "acción privilegiada"
	}
	return huh.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title("Confirmar acción privilegiada").
				Description(action).
				Affirmative("Confirmar").
				Negative("Cancelar").
				Value(&m.AuthConfirmOK),
			huh.NewInput().
				Title("Contraseña / PIN").
				EchoMode(huh.EchoModePassword).
				Value(&m.AuthStepUpPass).
				Validate(validatePIN),
		),
	).WithWidth(60).WithKeyMap(styles.HuhKeyMap()).WithTheme(styles.HuhTheme())
}

// ── Comandos de autenticación ────────────────────────────────────────────────

// LoginCmd autentica al usuario contra bauth vía JSON-RPC 2.0 sobre Unix socket.
// En caso de error retorna AuthResultMsg{Err} — nunca bloquea más de 5 segundos.
func LoginCmd(user, pass string) tea.Cmd {
	return func() tea.Msg {
		conn, err := net.DialTimeout("unix", "/run/bos/bauth.sock", 3*time.Second)
		if err != nil {
			return AuthResultMsg{Err: "bauth no disponible — ¿está el sistema instalado?"}
		}
		defer conn.Close()
		conn.SetDeadline(time.Now().Add(5 * time.Second)) //nolint:errcheck

		req := map[string]interface{}{
			"jsonrpc": "2.0",
			"method":  "bauth.session.login",
			"params":  map[string]interface{}{"username": user, "password": pass},
			"id":      1,
		}
		if err := json.NewEncoder(conn).Encode(req); err != nil {
			return AuthResultMsg{Err: "error enviando credenciales: " + err.Error()}
		}

		var resp struct {
			Result *struct {
				LoA   int    `json:"loa"`
				Token string `json:"token"`
			} `json:"result"`
			Error *struct {
				Message string `json:"message"`
			} `json:"error"`
		}
		if err := json.NewDecoder(conn).Decode(&resp); err != nil {
			return AuthResultMsg{Err: "error leyendo respuesta de bauth: " + err.Error()}
		}
		if resp.Error != nil {
			return AuthResultMsg{Err: resp.Error.Message}
		}
		if resp.Result == nil {
			return AuthResultMsg{Err: "respuesta vacía de bauth"}
		}
		return AuthResultMsg{LoA: resp.Result.LoA, Token: resp.Result.Token}
	}
}

// StepUpCmd eleva el LoA del operador a 3 vía JSON-RPC bauth.session.step_up.
func StepUpCmd(user, pass string) tea.Cmd {
	return func() tea.Msg {
		conn, err := net.DialTimeout("unix", "/run/bos/bauth.sock", 3*time.Second)
		if err != nil {
			return StepUpResultMsg{Err: "bauth no disponible"}
		}
		defer conn.Close()
		conn.SetDeadline(time.Now().Add(5 * time.Second)) //nolint:errcheck

		req := map[string]interface{}{
			"jsonrpc": "2.0",
			"method":  "bauth.session.step_up",
			"params":  map[string]interface{}{"username": user, "password": pass, "target_loa": 3},
			"id":      1,
		}
		if err := json.NewEncoder(conn).Encode(req); err != nil {
			return StepUpResultMsg{Err: "error enviando solicitud: " + err.Error()}
		}
		var resp struct {
			Result *struct{ OK bool `json:"ok"` } `json:"result"`
			Error  *struct{ Message string `json:"message"` } `json:"error"`
		}
		if err := json.NewDecoder(conn).Decode(&resp); err != nil {
			return StepUpResultMsg{Err: "error leyendo respuesta: " + err.Error()}
		}
		if resp.Error != nil {
			return StepUpResultMsg{Err: resp.Error.Message}
		}
		return StepUpResultMsg{}
	}
}
