// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// Package model contiene el modelo TEA (The Elm Architecture) del instalador,
// los tipos de datos, el enum de pantallas y los mensajes de BubbleTea.
//
// # Responsabilidades
//
// Definir y mantener el estado completo del TUI en un único struct [Model]:
//   - [Screen] enum con las 15 pantallas (P0 a P14/ScreenGoodbye)
//   - [Model] con campos por grupo de pantalla (no campos planos mezclados)
//   - Método Update(msg) puro — sin efectos secundarios (corrige P3)
//   - Método Init() que devuelve solo los comandos iniciales
//   - Navegación de pantallas vía [Model.SetScreen] con recálculo de viewports
//   - Un único campo [Model.CurrentScreen] para la pantalla activa (corrige P11)
//
// # Fuera de alcance
//
// No renderiza nada — eso es [screens]. No define estilos lipgloss — eso es
// [styles]. No abre conexiones WebSocket — eso es [wslib]. No conoce paths del
// sistema de archivos — eso es [internal/paths].
//
// # Dependencias
//
// internal/tui/styles: tipos de estilos usados en campos del modelo (solo tipos).
// internal/wslib:      tipo wsEventMsg importado como dependencia de datos.
//
// Dependencias externas: github.com/charmbracelet/bubbletea (tipos de mensaje),
// github.com/charmbracelet/bubbles (viewport, spinner, progress, textinput, help).
//
// # Callers principales
//
// internal/tui/doc.go: importa [New] para construir el modelo inicial.
// internal/tui/screens/: importa [Model] y [Screen] para View pura.
// cmd/bosctl/install_ui_impl.go: entry point del wizard (F3.10 — 62 líneas).
//
// # Política TEA del paquete (ver internal/tui/POLICY.md)
//
// POLICY.md, en la raíz de internal/tui/, es la norma completa del TUI:
// inventario de las 15 pantallas y las 7 reglas TEA obligatorias. Resumen
// de la invariante central (P3):
//
//	Update() NUNCA llama funciones con efectos secundarios (log, os.*,
//	time.Now fuera de msgs). Solo devuelve (Model, tea.Cmd). Si necesita
//	un efecto, devuelve un Cmd que lo ejecuta fuera del Update.
//
// Toda pantalla nueva debe registrarse en POLICY.md antes de implementarse.
//
// # Estándares y referencias
//
// internal/tui/POLICY.md — norma TEA del paquete: 15 pantallas, 7 reglas.
// BOS-REPAIR-03 F3.2 — Screen enum en types.go (corrige P11: tipo Screen roto).
// BOS-REPAIR-03 F3.3 — campo único CurrentScreen en model.go (corrige P11).
// BOS-REPAIR-03 F3.6 — handlers Update puros sin side effects (corrige P3).
// BOS-REPAIR-03 F3.7 — viewport.go con recálculo responsivo (corrige P10).
//
// # Ejemplo de uso
//
//	// Crear modelo inicial con valores por defecto:
//	m := model.New(model.Config{
//	    SocketPath: "/run/bos/bos.sock",
//	    DemoMode:   false,
//	})
//	// Cambiar pantalla:
//	m.SetScreen(model.ScreenWizardP2)
//	// Consultar pantalla activa:
//	if m.CurrentScreen == model.ScreenInstalling { ... }
package model
