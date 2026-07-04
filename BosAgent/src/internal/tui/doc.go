// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// Package tui es el punto de entrada del instalador de terminal del daemon bos.
//
// # Responsabilidades
//
// Orquestar los subpaquetes del TUI para producir la interfaz de instalación
// completa según el patrón The Elm Architecture (TEA) de BubbleTea:
//
//   - Exportar [model.New] como constructor del modelo raíz
//   - Componer las 15 pantallas definidas en [model.Screen] en una sola aplicación
//   - Delegar el renderizado a [screens] según la pantalla activa
//   - Garantizar que [styles] sea el único lugar donde se definen colores y estilos
//   - Exponer [demo.Run] para simulación sin daemon
//
// # Fuera de alcance
//
// No implementa lógica de negocio — solo presenta el estado que recibe del daemon
// vía WebSocket. No toma decisiones sobre sagas, fichas ni estados. No escribe
// en disco ni llama comandos del sistema operativo directamente.
//
// # Dependencias
//
// internal/tui/model:   tipos, Screen enum, Model TEA, mensajes
// internal/tui/styles:  variables lipgloss centralizadas
// internal/tui/screens: renderizado por pantalla (View pura)
// internal/tui/demo:    modo simulación sin daemon
// internal/wslib:       transporte WebSocket con el daemon
//
// Dependencias externas: github.com/charmbracelet/bubbletea,
// github.com/charmbracelet/lipgloss, github.com/charmbracelet/bubbles
//
// # Callers principales
//
// cmd/bosctl/install_ui.go: punto de entrada del comando `bosctl setup`.
// Crea el modelo inicial con [model.New], arranca bubbletea.NewProgram y espera
// el resultado final.
//
// # Estándares y referencias
//
// BOS-REPAIR-03 — Fase 3: partir install_ui.go (F3.1 a F3.10).
// ADR-003 — Documentación obligatoria 6-secciones en cada subpaquete.
// install_ui.go L407-427 — Screen enum de las 15 pantallas (fuente de verdad hasta F3).
// POLICY.md (este directorio) — reglas de adición y modificación de pantallas.
//
// # Ejemplo de uso
//
//	// Desde cmd/bosctl/install_ui.go (después de F3):
//	m := tui.NewModel(tui.Config{SocketPath: "/run/bos/bos.sock"})
//	p := bubbletea.NewProgram(m, bubbletea.WithAltScreen())
//	if _, err := p.Run(); err != nil {
//	    fmt.Fprintln(os.Stderr, err)
//	    os.Exit(1)
//	}
package tui
