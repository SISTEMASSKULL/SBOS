// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// Package demo implementa el modo de simulación del instalador: permite
// recorrer todas las pantallas del TUI sin daemon ni comandos reales.
//
// # Responsabilidades
//
// Proveer una fuente de eventos sintéticos que reemplace al daemon bos durante
// el desarrollo y las pruebas de la interfaz:
//
//   - [Run](cfg Config) arranca el TUI en modo demo sin conexión WebSocket
//   - [Simulate] genera la secuencia de eventos de una instalación completa
//     (saga_start → step_start → step_ok × N → saga_ok) para todas las fichas
//   - Tiempos ajustables: pausa entre fichas, entre pasos, duración de pasos
//   - Las 22 fichas del DAG se instalan en secuencia respetando los grupos N0–N6
//
// # Fuera de alcance
//
// No ejecuta comandos reales del sistema operativo. No abre conexiones de red
// ni sockets Unix. No persiste estado en disco. No valida datos del formulario
// del wizard — en demo todos los valores son válidos.
//
// # Dependencias
//
// internal/tui/model: [Model], [Screen], tipos de mensajes WS
//
// Dependencias externas: github.com/charmbracelet/bubbletea.
//
// # Callers principales
//
// cmd/bosctl/install_ui.go: activa demo cuando --demo o BOS_DEMO=1.
//
//	var demoMode bool  (install_ui.go L793 — migrar a este paquete en F3.5)
//
// # Estándares y referencias
//
// BOS-REPAIR-03 F3.5 — demo/demo.go como quinto átomo de F3.
// install_ui.go L793 — demoMode global actual (referencia hasta F3.5).
// POLICY.md §4 — regla: demo DEBE cubrir los 5 grupos de pantallas.
//
// # Ejemplo de uso
//
//	// Desde cmd/bosctl/install_ui.go (después de F3.5):
//	if os.Getenv("BOS_DEMO") == "1" || demoFlag {
//	    demo.Run(demo.Config{
//	        PauseBetweenFichas: 200 * time.Millisecond,
//	        PauseBetweenSteps:  50 * time.Millisecond,
//	    })
//	    return
//	}
package demo
