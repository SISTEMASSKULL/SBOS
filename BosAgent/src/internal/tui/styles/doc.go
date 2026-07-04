// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// Package styles centraliza todas las constantes de color y variables lipgloss
// del TUI del instalador bos. Es el único lugar donde se definen estilos.
//
// # Responsabilidades
//
// Exportar variables lipgloss reutilizables y constantes de color para que
// ningún otro paquete defina estilos inline:
//
//   - Constantes de color HEX: [ColorGreen], [ColorAccent], [ColorRed], etc.
//   - Estilos base: [Bold], [Dim], [Green], [Cyan], [Red], [Yellow], [Muted]
//   - Componentes estructurales: [TopBar], [Footer], [Box], [BoxActive]
//   - Estilos de pasos: [StepOK], [StepActive], [StepPending], [StepFail]
//   - Estilos de inputs: [InputActive], [InputInactive]
//   - Funciones de icono: [IconOK()], [IconRun()], [IconPend()], [IconErr()], [IconWarn()]
//
// # Fuera de alcance
//
// No importa bubbletea — este paquete no conoce el ciclo TEA. No define
// tipos de datos del modelo. No calcula dimensiones de viewport. No contiene
// lógica condicional — solo constantes y variables inmutables.
//
// # Dependencias
//
// Ninguna dependencia de otros paquetes internos. Zero import cycles.
// Dependencia externa única: github.com/charmbracelet/lipgloss.
//
// # Callers principales
//
// internal/tui/screens/*: cada archivo de pantalla importa styles para renderizar.
// internal/tui/model/doc.go: puede importar para tipos de Color (no estilos completos).
// cmd/bosctl/install_ui.go: usa los estilos directamente hasta que F3 complete la migración.
//
// # Estándares y referencias
//
// BOS-REPAIR-03 F3.1 — styles/styles.go como primer átomo de F3.
// install_ui.go L52-155 — definición actual de colores y estilos (referencia hasta F3.1).
// POLICY.md §2 — todo nuevo estilo va aquí, nunca inline en screens/.
//
// # Ejemplo de uso
//
//	import "bos/internal/tui/styles"
//
//	// En una función View de screens/:
//	header := styles.TopBar.Render("⬡ SBOS IAM Installer")
//	ok := styles.IconOK() + " " + styles.Green.Render("postgresql — instalada")
//	err := styles.IconErr() + " " + styles.Red.Render("vault — error")
package styles
