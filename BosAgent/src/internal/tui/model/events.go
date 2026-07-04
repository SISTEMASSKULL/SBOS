// Package model — events.go: mensajes TEA del TUI del instalador bos.
// Extraído de cmd/bosctl/install_ui.go en F3.4 (BOS-REPAIR).
package model

import (
	"time"

	"bos/internal/tui/tuilog"
	"bos/internal/wslib"

	tea "github.com/charmbracelet/bubbletea"
)

// WsReadyMsg se envía cuando la conexión WebSocket al daemon bos está lista.
type WsReadyMsg struct{ Conn *wslib.Conn }

// WsErrorMsg se envía cuando la conexión WebSocket falla o se cierra.
type WsErrorMsg struct{ Err error }

// SysInfoMsg se envía cuando detectSystemInfo() completa la detección del OS host.
type SysInfoMsg struct{ Info SysInfo }

// PreflightMsg transporta el progreso de bos-preflight al TEA loop.
type PreflightMsg struct {
	Pct      float64
	Msg      string
	Done     bool
	Err      string   // error del paso actual (no fatal — continúa)
	Warnings []string // resumen final de todos los errores (solo en Done:true)
}

// TickMsg dispara animaciones de TUI cada 100ms (spinner, countdown, progress).
type TickMsg time.Time

// TickCmd devuelve un tea.Cmd que emite un TickMsg tras 100ms.
func TickCmd() tea.Cmd {
	return tea.Tick(100*time.Millisecond, func(t time.Time) tea.Msg {
		return TickMsg(t)
	})
}

// StepUpResultMsg transporta el resultado del step-up LoA 3 contra bauth.
type StepUpResultMsg struct {
	Err string // vacío = elevación exitosa; m.AuthLoA se sube a 3
}

// AuthResultMsg transporta el resultado de la autenticación contra bauth.
type AuthResultMsg struct {
	LoA   int    // Level of Assurance obtenido (RFC 9470)
	Token string // JWT efímero de sesión TUI
	Err   string // mensaje de error si la autenticación falló (vacío = éxito)
}

// JournalEntryMsg transporta una entrada leída de journalctl al modelo TEA.
// El handler debe encadenar tuilog.FollowCmd(m.JournalCh) para continuar leyendo.
type JournalEntryMsg = tuilog.JournalEntryMsg

// JournalErrMsg indica que journalctl terminó o tuvo un error.
type JournalErrMsg = tuilog.JournalErrMsg
