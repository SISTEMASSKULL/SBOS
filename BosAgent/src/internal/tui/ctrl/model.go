// Package ctrl — dashboard de control SBOS.
// Este archivo re-exporta tipos de dash para compatibilidad externa.
// El código real vive en ctrl/dash/ (types, model, menu, widgets).
package ctrl

import (
	"bos/internal/tui/ctrl/dash"
)

// ── Alias de tipos públicos ─────────────────────────────────────────────────
// Estos alias hacen que ctrl.DashModel sea el MISMO tipo que dash.DashModel,
// permitiendo que install_ui_impl.go siga usando ctrl.DashModel sin cambios.

type DashModel = dash.DashModel
type DashAction = dash.DashAction

const (
	DashActionNone     = dash.DashActionNone
	DashActionReboot   = dash.DashActionReboot
	DashActionShutdown = dash.DashActionShutdown
)

// New construye un DashModel con datos mock y dimensiones iniciales.
func New(w, h int) DashModel {
	return dash.New(w, h)
}
