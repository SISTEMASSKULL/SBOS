// Package main — dev.go: subcomando "bosctl dev" para desarrollo del TUI.
// bosctl dev new-screen <Nombre> [--group=<grupo>]
// Ver POLICY.md §6 para el procedimiento completo de 7 pasos.
package main

import (
	"fmt"
	"os"
	"strings"
	"unicode"
)

// cmdDev despacha los subcomandos de desarrollo.
func cmdDev(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "bosctl dev <subcomando>")
		fmt.Fprintln(os.Stderr, "  new-screen <Nombre> [--group=<grupo>]")
		return 2
	}
	switch args[0] {
	case "new-screen":
		return cmdDevNewScreen(args[1:])
	default:
		fmt.Fprintf(os.Stderr, "bosctl dev: subcomando desconocido: %s\n", args[0])
		return 2
	}
}

// Rutas relativas desde BosAgent/src/ (raíz del módulo, donde existe go.mod).
// El comando falla explícitamente si se ejecuta desde otro directorio.
const (
	devPathTypes      = "internal/tui/model/types.go"
	devPathDispatcher = "internal/tui/screens/dispatcher.go"
	devPathKeys       = "internal/tui/model/keys.go"
	devPathScreens    = "internal/tui/screens"
)

// devCheckModuleRoot verifica que CWD sea el directorio raíz del módulo Go.
func devCheckModuleRoot() bool {
	_, err := os.Stat("go.mod")
	return err == nil
}

func cmdDevNewScreen(args []string) int {
	if !devCheckModuleRoot() {
		fmt.Fprintln(os.Stderr, "bosctl dev: ejecutar desde BosAgent/src/ (donde existe go.mod)")
		return 1
	}
	var name, group string
	for i, a := range args {
		if strings.HasPrefix(a, "--group=") {
			group = strings.TrimPrefix(a, "--group=")
		} else if i == 0 && !strings.HasPrefix(a, "--") {
			name = a
		}
	}
	if name == "" {
		fmt.Fprintln(os.Stderr, "uso: bosctl dev new-screen <NombrePascalCase> [--group=<grupo>]")
		return 2
	}
	if !devValidName(name) {
		fmt.Fprintf(os.Stderr, "error: <Nombre> debe ser PascalCase, ej: MiPantalla. Recibido: %q\n", name)
		return 2
	}
	if group == "" {
		group = strings.ToLower(name)
	}

	type step struct {
		desc string
		fn   func(string, string) error
	}
	steps := []step{
		{"Crear archivo de pantalla", devCreateScreen},
		{"Crear archivo de tests", devCreateTest},
		{"Registrar Screen" + name + " en types.go", devPatchTypes},
		{"Registrar caso en dispatcher.go", devPatchDispatcher},
		{"Registrar keybinding en keys.go", devPatchKeys},
	}

	for _, s := range steps {
		if err := s.fn(name, group); err != nil {
			fmt.Fprintf(os.Stderr, "  ✗ %s: %v\n", s.desc, err)
			return 1
		}
		fmt.Printf("  ✓ %s\n", s.desc)
	}

	fmt.Printf("\n✓ Pantalla Screen%s generada en 5 pasos. Próximos pasos manuales:\n", name)
	fmt.Printf("  3. Agregar Screen%s en dispatcher_test.go (TestScreens_TodasRegistradasEnDispatcher)\n", name)
	fmt.Printf("  4. Implementar build%sBody() en %s/%s.go\n", name, devPathScreens, group)
	fmt.Printf("  5. Ajustar keybindings en %s — case Screen%s\n", devPathKeys, name)
	fmt.Printf("  6. go build ./... && go test -race ./internal/tui/...\n")
	return 0
}

// ── Paso 1 — Crear archivo de pantalla ────────────────────────────────────────

func devCreateScreen(name, group string) error {
	path := devPathScreens + "/" + group + ".go"
	if _, err := os.Stat(path); err == nil {
		path = devPathScreens + "/" + strings.ToLower(name) + ".go"
	}
	const tmpl = `// Package screens — %s.go: pantalla %s (generado por bosctl dev new-screen).
package screens

import tuimodel "bos/internal/tui/model"

// Render%s renderiza Screen%s: TODO completar descripción.
func Render%s(m tuimodel.Model) string {
	return assembleScreen(m, build%sBody(m))
}

// build%sBody construye el cuerpo de la pantalla %s.
// TODO: implementar con assembleScreen/Mode/summaryRow/estilos de styles/.
func build%sBody(m tuimodel.Model) string {
	_ = m
	return "Pantalla %s en construcción."
}
`
	content := fmt.Sprintf(tmpl,
		group, name,
		name, name, name, name, name, name, name, name,
	)
	return os.WriteFile(path, []byte(content), 0644)
}

// ── Paso 2 — Crear archivo de tests ───────────────────────────────────────────

func devCreateTest(name, group string) error {
	path := devPathScreens + "/" + strings.ToLower(name) + "_test.go"
	_ = group
	const tmpl = `package screens_test

import (
	"testing"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/screens"
)

func TestScreen%s_SinPanic_80x24(t *testing.T) {
	cfg := tuimodel.Config{DemoMode: true}
	m := *tuimodel.New(cfg, tuimodel.SeedData{})
	m.Width = 80
	m.Height = 24
	m.CurrentScreen = tuimodel.Screen%s
	if out := screens.Render%s(m); out == "" {
		t.Fatal("Render%s 80x24: retornoVacio")
	}
}

func TestScreen%s_Race(t *testing.T) {
	cfg := tuimodel.Config{DemoMode: true}
	m := *tuimodel.New(cfg, tuimodel.SeedData{})
	m.Width = 80
	m.Height = 24
	m.CurrentScreen = tuimodel.Screen%s
	for i := 0; i < 10; i++ {
		t.Run("", func(t *testing.T) {
			t.Parallel()
			if out := screens.Render%s(m); out == "" {
				t.Error("output vacio")
			}
		})
	}
}
`
	content := fmt.Sprintf(tmpl, name, name, name, name, name, name, name)
	return os.WriteFile(path, []byte(content), 0644)
}

// ── Paso 3 — Parchear types.go ────────────────────────────────────────────────

func devPatchTypes(name, _ string) error {
	// Inserta Screen<Name> en el bloque const antes de ScreenGoodbye.
	// La inserción empieza con \n para separar de la línea anterior.
	padded := "Screen" + name
	for len(padded) < 32 {
		padded += " "
	}
	insertion := "\n\t" + padded + "// pantalla generada — completar descripción"
	return devPatchFile(devPathTypes, "\n\tScreenGoodbye", insertion)
}

// ── Paso 4 — Parchear dispatcher.go ───────────────────────────────────────────

func devPatchDispatcher(name, _ string) error {
	// Inserta el caso antes del cierre del switch (justo antes de `\t}\n\treturn ""`).
	newCase := "\n\tcase tuimodel.Screen" + name + ":\n\t\treturn Render" + name + "(m)"
	return devPatchFile(devPathDispatcher, "\n\t}\n\treturn \"\"", newCase)
}

// ── Paso 5 — Parchear keys.go ─────────────────────────────────────────────────

func devPatchKeys(name, _ string) error {
	// Inserta un caso mínimo antes de `default:` en KeysFor.
	// La inserción empieza con \n para separar del caso anterior.
	newCase := "\n\tcase Screen" + name + ":\n" +
		"\t\treturn ScreenKeyMap{\n" +
		"\t\t\tkey.NewBinding(key.WithKeys(\"ctrl+c\"), key.WithHelp(\"ctrl+c\", \"salir\")),\n" +
		"\t\t}"
	return devPatchFile(devPathKeys, "\n\tdefault:", newCase)
}

// ── Helper de parcheo ─────────────────────────────────────────────────────────

// devPatchFile inserta insertBefore justo antes de la primera ocurrencia de marker.
func devPatchFile(path, marker, insertBefore string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("leer %s: %w", path, err)
	}
	content := string(data)
	idx := strings.Index(content, marker)
	if idx < 0 {
		return fmt.Errorf("marcador %q no encontrado en %s (¿archivo modificado?)", marker, path)
	}
	newContent := content[:idx] + insertBefore + content[idx:]
	if err := os.WriteFile(path, []byte(newContent), 0644); err != nil {
		return fmt.Errorf("escribir %s: %w", path, err)
	}
	return nil
}

// devValidName verifica que el nombre sea PascalCase (letra mayúscula inicial, solo letras/dígitos).
func devValidName(name string) bool {
	if len(name) == 0 {
		return false
	}
	for i, r := range name {
		if i == 0 && !unicode.IsUpper(r) {
			return false
		}
		if !unicode.IsLetter(r) && !unicode.IsDigit(r) {
			return false
		}
	}
	return true
}
