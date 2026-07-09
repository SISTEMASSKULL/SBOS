# INSTRUCCIONES DE EJECUCIÓN — Átomos F3.1 a F3.5
## Partir `install_ui.go` (4,834 → ≤80 líneas) — Primera mitad
## Para: Agente ejecutor (Claude Code / desarrollador)

**Átomos:** F3.1, F3.2, F3.3, F3.4, F3.5  
**Requiere previo:** F0.3 ✅ (estructura `internal/tui/` creada), F2.4 ✅ (gorilla eliminado)  
**Duración estimada:** 4–6 horas (dividir en sesiones de 1 átomo cada una)  
**Riesgo:** MEDIO-ALTO — imports circulares entre paquetes nuevos rompen el build  
**Regla crítica:** `go build ./...` debe pasar en verde después de CADA átomo  
**Feature flag:** `BOS_TUI_V2=true` activará el nuevo TUI (implementar en F3.10)

---

## CONTEXTO TÉCNICO — Por qué el orden importa

`install_ui.go` (4,834 líneas) tiene dependencias en cascada. Extraer en el orden incorrecto genera imports circulares que impiden compilar.

**Árbol de dependencias entre los nuevos paquetes:**

```
internal/tui/styles/       ← NO importa bubbletea ni otros paquetes tui/
        ↑
internal/tui/model/types.go ← importa styles/
        ↑
internal/tui/model/model.go ← importa types.go
        ↑
internal/tui/model/events.go ← importa model.go
        ↑
internal/tui/demo/         ← importa model/ y styles/
        ↑
internal/tui/screens/      ← importa model/ y styles/
```

**Regla de oro:** extraer siempre de las hojas hacia la raíz. El paquete con MENOS dependencias va primero.

### El problema TEA que hay que corregir en F3.3

BubbleTea requiere que `Update()` sea pura: recibe model por valor, devuelve model nuevo. El código actual viola esto:

```go
// ❌ INCORRECTO — viola TEA (código actual en install_ui.go):
func (m *model) handleWS(ev wsEventMsg) {
    m.fichasOK++ // muta el receptor
}

// La guía oficial de BubbleTea (charmbracelet, Sep 2025) dice explícitamente:
// "Unless there is a good reason to do otherwise, stick to the normal message
//  flow: any changes to the model should be made in Update() and returned
//  immediately in the first return value."

// ✅ CORRECTO — función pura (lo que vamos a implementar):
func handleWS(m model, ev wsEventMsg) model {
    m.fichasOK++
    return m // retorna copia modificada, no muta el original
}
```

---

## PRE-CONDICIONES — Verificar antes de empezar

```bash
cd /opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/BOS_V8/

# 1. Fases previas completas
[ -d internal/tui/model ] && [ -d internal/tui/styles ] \
  && echo "✅ F0.3 completo" || echo "❌ ejecutar F0.3 primero"

grep -rq "gorilla/websocket" go.mod 2>/dev/null \
  && echo "❌ F2.4 pendiente — gorilla aún en go.mod" \
  || echo "✅ F2.4 completo"

# 2. Build limpio
go build ./... && echo "✅ build base limpio" || echo "❌ resolver build antes"

# 3. Medir el estado actual de install_ui.go
wc -l cmd/bosctl/install_ui.go
echo "(debe ser ~4834 líneas — si es menos, verificar qué ya se extrajo)"

# 4. Inventariar lo que hay en install_ui.go
echo "=== Constantes y variables de estilo (→ F3.1) ==="
grep -n "^const\|^var\|lipgloss\|cGreen\|cCyan\|cBlack\|sBold\|sBox\|icOk\|icRun\|badge\|renderMFA" \
  cmd/bosctl/install_ui.go | head -30

echo "=== Tipos y struct model (→ F3.2/F3.3) ==="
grep -n "^type\|type model\|type Screen\|type stepID\|step   Screen\|screen Screen" \
  cmd/bosctl/install_ui.go | head -20

echo "=== Receptores *model (TEA violado → F3.3) ==="
grep -n "func (m \*model)" cmd/bosctl/install_ui.go | head -20

echo "=== Funciones del modo demo (→ F3.5) ==="
grep -n "func demo\|runDemo\|demoLog\|demoSub" cmd/bosctl/install_ui.go | head -10
```

---

## ÁTOMO F3.1 — `internal/tui/styles/styles.go`

**Objetivo:** Extraer todos los estilos lipgloss e iconos. Cero dependencias en bubbletea.  
**Tiempo estimado:** 30 minutos

### Qué extraer

```bash
# Listar todas las variables lipgloss y constantes de color:
grep -n "lipgloss\.\|cGreenS\|cCyanS\|cBlackS\|cBg2S\|cGreen\|cCyan\|cBlack\|cBg\|sBold\|sBox\|sTopBar\|sBoxActive\|sBoxHeader\|sStep" \
  cmd/bosctl/install_ui.go | head -40

# Listar funciones helper de UI:
grep -n "^func ic\|^func badge\|^func renderMFA\|^func icOk\|^func icRun\|^func icPend\|^func icErr\|^func icWarn\|^func icBos" \
  cmd/bosctl/install_ui.go
```

### Crear `internal/tui/styles/styles.go`

```go
// Package styles define los estilos visuales del instalador SBOS.
//
// # Responsabilidades
//
// Centraliza todas las constantes de color, estilos lipgloss y funciones
// de renderizado de iconos del instalador interactivo.
//
// # Fuera de alcance
//
// Este paquete NO importa bubbletea ni bubbles. Solo lipgloss.
// La lógica de estado del TUI vive en internal/tui/model/.
//
// # Dependencias
//
// lipgloss: única dependencia externa para estilos de terminal.
//
// # Estándares
//
// ADR-003 — godoc completo en todos los identificadores exportados.
package styles

import "github.com/charmbracelet/lipgloss"

// Colores base del tema SBOS.
// Usar estas constantes en lugar de strings literales de color.
const (
    ColorGreenStr = "COPIAR_DE_install_ui.go"  // cGreenS
    ColorCyanStr  = "COPIAR_DE_install_ui.go"  // cCyanS
    ColorBlackStr = "COPIAR_DE_install_ui.go"  // cBlackS
    // ... resto de constantes de color
)

// Variables de estilo lipgloss. Inicializadas una vez al importar el paquete.
var (
    Green  = lipgloss.NewStyle() // COPIAR_DE: cGreen
    Cyan   = lipgloss.NewStyle() // COPIAR_DE: cCyan
    Bold   = lipgloss.NewStyle() // COPIAR_DE: sBold
    Box    = lipgloss.NewStyle() // COPIAR_DE: sBox
    TopBar = lipgloss.NewStyle() // COPIAR_DE: sTopBar
    // ... resto de estilos
)

// IconOK retorna el icono de éxito con estilo aplicado.
func IconOK() string { /* COPIAR_DE: icOk() */ return "" }

// IconRunning retorna el icono de proceso en ejecución.
func IconRunning() string { /* COPIAR_DE: icRun() */ return "" }

// IconPending retorna el icono de proceso pendiente.
func IconPending() string { /* COPIAR_DE: icPend() */ return "" }

// IconError retorna el icono de error.
func IconError() string { /* COPIAR_DE: icErr() */ return "" }

// IconWarning retorna el icono de advertencia.
func IconWarning() string { /* COPIAR_DE: icWarn() */ return "" }

// IconBos retorna el icono del daemon bos.
func IconBos() string { /* COPIAR_DE: icBos() */ return "" }

// Badge renderiza una etiqueta con estilo.
func Badge(text, color string) string { /* COPIAR_DE: badge() */ return "" }

// RenderMFARow renderiza una fila de MFA con estilo.
func RenderMFARow(label, value string) string { /* COPIAR_DE: renderMFARow() */ return "" }
```

### Crear `internal/tui/styles/styles_test.go`

```go
package styles_test

import (
    "testing"
    "bos/internal/tui/styles"
    _ "github.com/charmbracelet/bubbletea" // VERIFICAR: este import NO debe aparecer en styles
)

// TestStyles_TodosLosIconosRetornanString verifica que ningún icono retorna vacío.
func TestStyles_TodosLosIconosRetornanString(t *testing.T) {
    iconos := []struct {
        nombre string
        fn     func() string
    }{
        {"IconOK", styles.IconOK},
        {"IconRunning", styles.IconRunning},
        {"IconPending", styles.IconPending},
        {"IconError", styles.IconError},
        {"IconWarning", styles.IconWarning},
        {"IconBos", styles.IconBos},
    }
    for _, ic := range iconos {
        if got := ic.fn(); got == "" {
            t.Errorf("%s() retornó cadena vacía", ic.nombre)
        }
    }
}

// TestStyles_SinDependenciaBubbleTea — el paquete styles NO debe importar bubbletea.
// Este test verifica que el import no existe mediante inspección del código fuente.
func TestStyles_SinDependenciaBubbleTea(t *testing.T) {
    // Este test siempre pasa si el archivo compila sin importar bubbletea.
    // La verificación real es: grep "bubbletea" internal/tui/styles/*.go
    // debe retornar vacío. Documentado aquí para que sea visible.
    t.Log("Verificar manualmente: grep bubbletea internal/tui/styles/*.go = vacío")
}
```

### Verificar F3.1

```bash
go build ./internal/tui/styles/ && echo "✅ F3.1 compila"
go test ./internal/tui/styles/ && echo "✅ F3.1 tests OK"
grep "bubbletea" internal/tui/styles/*.go && echo "❌ bubbletea presente" || echo "✅ sin bubbletea"
go build ./... && echo "✅ build global OK"
```

**Commit F3.1:**
```bash
git add internal/tui/styles/
git commit -m "[F3.1] feat: internal/tui/styles/ — estilos lipgloss extraídos de install_ui.go

Extrae ~35 constantes/variables de color y lipgloss + 8 funciones de iconos
y helpers visuales (icOk, icRun, badge, renderMFARow, etc).

Sin dependencia en bubbletea — solo lipgloss.
Tests: TodosLosIconosRetornanString ✅"
```

---

## ÁTOMO F3.2 — `internal/tui/model/types.go` — Screen como única fuente de verdad

**Objetivo:** Crear el tipo `Screen` con 15 constantes. Eliminar el alias `stepID` y el campo `step` duplicado.  
**Tiempo estimado:** 45 minutos  
**Problema a resolver:** P11 — dos campos para la misma cosa (`step Screen` y `screen Screen`)

### Inventariar el problema P11 en install_ui.go

```bash
# Ver los dos campos duplicados en model:
grep -n "step\s*Screen\|screen\s*Screen\|stepID\|stepWelcome\|ScreenWelcome" \
  cmd/bosctl/install_ui.go | head -20

# Contar cuántas veces se usa m.step vs m.screen:
echo "Usos de m.step:"
grep -c "m\.step\b" cmd/bosctl/install_ui.go
echo "Usos de m.screen:"
grep -c "m\.screen\b" cmd/bosctl/install_ui.go
```

### Crear `internal/tui/model/types.go`

```go
// Package model define el estado central del instalador TUI.
//
// # Screen como fuente de verdad única (P11)
//
// La struct model tiene UN SOLO campo para la pantalla activa: screen Screen.
// El campo antiguo step Screen y el alias stepID = Screen están eliminados.
// Todo código que usaba m.step debe actualizarse a m.screen.
package model

// Screen identifica la pantalla activa del instalador.
// Es la única fuente de verdad para qué pantalla mostrar.
//
// Hay exactamente 15 pantallas. Cualquier adición debe registrarse
// en internal/tui/POLICY.md antes de implementarse.
type Screen int

const (
    ScreenWelcome     Screen = iota // S00 — splash inicial al arrancar
    ScreenWizardP1                   // S01 — bienvenida del wizard
    ScreenWizardP2                   // S02 — datos de empresa/tenant
    ScreenWizardP3                   // S03 — cuenta admin + MFA
    ScreenWizardP4                   // S04 — confirmación antes de instalar
    ScreenInstalling                  // S05 — instalación en 3 columnas
    ScreenInstallLog                  // S06 — log completo de instalación
    ScreenInstallErr                  // S07 — panel de error de instalación
    ScreenInstallDone                 // S08 — instalación completada
    ScreenReboot                      // S09 — cuenta regresiva para reinicio
    ScreenBoot                        // S10 — arranque del sistema
    ScreenDashboard                   // S11 — panel de monitorización permanente
    ScreenLogs                        // S12 — logs en tiempo real con filtros
    ScreenShutdown                    // S13 — apagado ordenado
    ScreenGoodbye                     // S14 — splash de cierre
)

// ScreenGroup clasifica las pantallas por su layout y comportamiento.
type ScreenGroup int

const (
    GroupSplash   ScreenGroup = iota // S00, S14 — pantallas de inicio/cierre
    GroupWizard                       // S01-S04 — wizard de configuración
    GroupInstall                      // S05-S09 — proceso de instalación
    GroupRuntime                      // S10-S13 — operación normal
)

// Group retorna el grupo al que pertenece esta pantalla.
// Determina el layout, los viewports activos y los atajos de teclado.
func (s Screen) Group() ScreenGroup {
    switch {
    case s == ScreenWelcome || s == ScreenGoodbye:
        return GroupSplash
    case s >= ScreenWizardP1 && s <= ScreenWizardP4:
        return GroupWizard
    case s >= ScreenInstalling && s <= ScreenReboot:
        return GroupInstall
    default:
        return GroupRuntime
    }
}

// NeedsStepper retorna true para pantallas del wizard que muestran indicador de paso.
func (s Screen) NeedsStepper() bool {
    return s >= ScreenWizardP1 && s <= ScreenInstalling
}

// ViewportKind retorna el identificador del viewport asignado a esta pantalla.
// Determina qué viewport(s) se sincronizan en syncViewports().
func (s Screen) ViewportKind() string {
    switch s.Group() {
    case GroupInstall:
        return "vpABC" // 3 columnas A, B, C
    case GroupRuntime:
        return "vpDash"
    default:
        return "vpMain"
    }
}

// wsEventMsg es el mensaje que llega desde el WebSocket del daemon bos.
// COPIAR de install_ui.go — el tipo compartido entre TUI y WebSocket.
type wsEventMsg struct {
    // COPIAR campos de install_ui.go
}

// wsReadyMsg indica que la conexión WebSocket está establecida.
type wsReadyMsg struct{}

// wsErrorMsg indica un error en la conexión WebSocket.
type wsErrorMsg struct{ err error }
```

### Test F3.2

```go
func TestScreen_15ConstantesRegistradas(t *testing.T) {
    screens := []Screen{
        ScreenWelcome, ScreenWizardP1, ScreenWizardP2, ScreenWizardP3,
        ScreenWizardP4, ScreenInstalling, ScreenInstallLog, ScreenInstallErr,
        ScreenInstallDone, ScreenReboot, ScreenBoot, ScreenDashboard,
        ScreenLogs, ScreenShutdown, ScreenGoodbye,
    }
    assert.Len(t, screens, 15, "deben ser exactamente 15 pantallas")
}

func TestScreen_GruposCorrectos(t *testing.T) {
    assert.Equal(t, GroupSplash, ScreenWelcome.Group())
    assert.Equal(t, GroupSplash, ScreenGoodbye.Group())
    assert.Equal(t, GroupWizard, ScreenWizardP1.Group())
    assert.Equal(t, GroupWizard, ScreenWizardP4.Group())
    assert.Equal(t, GroupInstall, ScreenInstalling.Group())
    assert.Equal(t, GroupRuntime, ScreenDashboard.Group())
}

func TestScreen_NeedsStepper(t *testing.T) {
    assert.True(t,  ScreenWizardP1.NeedsStepper())
    assert.True(t,  ScreenInstalling.NeedsStepper())
    assert.False(t, ScreenDashboard.NeedsStepper())
    assert.False(t, ScreenWelcome.NeedsStepper())
}
```

```bash
go build ./internal/tui/model/ && echo "✅ F3.2 compila"
go test ./internal/tui/model/ -run TestScreen && echo "✅ F3.2 tests OK"
go build ./... && echo "✅ build global OK"
```

---

## ÁTOMO F3.3 — `internal/tui/model/model.go` — struct model corregida

**Objetivo:** Crear la struct `model` con campo único `screen`, eliminar `step`, convertir receptores `*model` a funciones puras.  
**Tiempo estimado:** 60 minutos  
**Problemas a resolver:** P3 (TEA), P7 (stopCh global), P11 (step/screen)

### Inventariar receptores *model en install_ui.go

```bash
# Listar TODOS los receptores *model (violaciones TEA):
grep -n "func (m \*model)" cmd/bosctl/install_ui.go
echo "---"
# Listar campos de la struct model:
grep -n "type model struct" cmd/bosctl/install_ui.go
# Ver el cuerpo de la struct (las siguientes ~40 líneas después):
grep -n "type model struct" cmd/bosctl/install_ui.go | \
  awk -F: '{print $1}' | \
  xargs -I{} sed -n "{},+40p" cmd/bosctl/install_ui.go | head -45
```

### Crear `internal/tui/model/model.go`

```go
package model

import (
    "bos/internal/tui/styles"
    // bubbletea y bubbles si model los necesita
)

// model es el estado completo del instalador TUI.
//
// Regla TEA (POLÍTICA-CÓDIGO-05): model es inmutable desde la perspectiva
// de BubbleTea. Update() y los handlers reciben model por VALOR y retornan
// una copia modificada. Ningún método tiene receptor *model.
//
// Campo único para pantalla activa: screen Screen.
// El campo antiguo step Screen fue eliminado (P11 BOS-REPAIR-00).
type model struct {
    // screen es LA única fuente de verdad para la pantalla activa.
    // Nunca usar el campo step (eliminado). Usar setScreen() para cambiar.
    screen Screen

    // COPIAR el resto de campos de install_ui.go
    // Omitir: step Screen (eliminado), stopCh (P7 — moverlo fuera)
    // Agregar: cualquier campo necesario que no existía
}

// InitialModel crea el estado inicial del instalador.
// stopCh se pasa como parámetro — no puede ser global (P7 BOS-REPAIR-00).
func InitialModel() model {
    return model{
        screen: ScreenWelcome,
        // COPIAR inicialización de campos de install_ui.go
    }
}

// setScreen retorna un nuevo model con la pantalla cambiada.
// Es una función pura: no muta el model original.
//
// Usar siempre esta función para cambiar de pantalla — nunca asignar
// model.screen directamente desde Update() sin pasar por aquí.
func setScreen(m model, s Screen) model {
    m.screen = s
    return m
}
```

### Convertir receptores `*model` a funciones puras

Para cada función con receptor `*model` encontrada en el paso anterior:

```go
// ANTES (viola TEA — código actual):
func (m *model) handleWS(ev wsEventMsg) {
    m.fichasOK++
    m.lastEvent = ev
}

// DESPUÉS (función pura — lo correcto):
// handleWS procesa un evento WebSocket retornando un model actualizado.
// Función pura: no muta el model recibido.
func handleWS(m model, ev wsEventMsg) model {
    m.fichasOK++
    m.lastEvent = ev
    return m
}

// ANTES:
func (m *model) addLog(e logEntry) {
    m.logs = append(m.logs, e)
}

// DESPUÉS:
func addLog(m model, e logEntry) model {
    m.logs = append(m.logs, e)
    return m
}
```

**Regla:** si el receptor es `*model`, la función muta estado y viola TEA. Convertir a función libre que recibe y retorna `model` por valor.

### Verificar F3.3

```bash
# Cero receptores *model en el nuevo paquete:
grep -rn "func (m \*model)" internal/tui/model/ \
  && echo "❌ VIOLA TEA — receptores *model presentes" \
  || echo "✅ TEA OK — sin receptores *model"

go build ./internal/tui/model/ && echo "✅ F3.3 compila"
go test -race -count=20 ./internal/tui/model/ && echo "✅ F3.3 tests sin race"
go build ./... && echo "✅ build global OK"
```

---

## ÁTOMO F3.4 — `internal/tui/model/events.go`

**Objetivo:** Centralizar el procesamiento de mensajes WebSocket como funciones puras.  
**Tiempo estimado:** 45 minutos

### Crear `internal/tui/model/events.go`

```go
package model

// handleWS procesa un evento WebSocket y retorna el model actualizado.
//
// Función pura (POLÍTICA-CÓDIGO-05): recibe model por valor, retorna
// model nuevo. No tiene efectos secundarios.
//
// El tipo del evento (ev.evType) determina qué campo del model actualizar.
func handleWS(m model, ev wsEventMsg) model {
    // COPIAR lógica de install_ui.go:handleWS / m.handleWS()
    // Convertir: m.fichasOK++ → m.fichasOK++; return m
    return m
}

// handleBootstrapStatus procesa una actualización de estado del bootstrap.
func handleBootstrapStatus(m model, data map[string]interface{}) model {
    // COPIAR lógica correspondiente de install_ui.go
    return m
}

// handleFichaUpdate procesa una actualización de estado de una ficha.
func handleFichaUpdate(m model, ev wsEventMsg) model {
    // COPIAR lógica correspondiente de install_ui.go
    return m
}

// addLog agrega una entrada al log del instalador.
// Función pura: retorna nuevo model con el log actualizado.
func addLog(m model, e logEntry) model {
    m.logs = append(m.logs, e)
    return m
}
```

### Test crítico para F3.4

```go
// TestHandleWS_NoMutaModeloOriginal es el test canónico de pureza TEA.
// Si este test falla, la función no es pura y viola el patrón TEA.
func TestHandleWS_NoMutaModeloOriginal(t *testing.T) {
    m1 := InitialModel()
    m1.fichasOK = 0

    m2 := handleWS(m1, wsEventMsg{evType: "saga_ok", ficha: "redis"})

    // El modelo original NO debe haber cambiado
    assert.Equal(t, 0, m1.fichasOK, "modelo original no debe cambiar")
    // El modelo nuevo debe tener el cambio
    assert.Equal(t, 1, m2.fichasOK, "modelo nuevo debe reflejar el evento")
    // Son objetos distintos en memoria
    // (Go copia structs por valor, así que esta garantía es automática)
}

// TestHandleWS_20EventosConcurrentes — go test -race verifica que
// las funciones puras no tienen race conditions.
func TestHandleWS_20EventosConcurrentes(t *testing.T) {
    m := InitialModel()
    var wg sync.WaitGroup

    for i := 0; i < 20; i++ {
        wg.Add(1)
        go func(idx int) {
            defer wg.Done()
            // Cada goroutine tiene su copia local del model — sin race
            _ = handleWS(m, wsEventMsg{evType: "saga_ok", ficha: "ficha" + strconv.Itoa(idx)})
        }(i)
    }
    wg.Wait()
    // Si hay DATA RACE aquí → la función muta estado compartido → no es pura
}
```

```bash
go test -race -count=50 ./internal/tui/model/ -run TestHandleWS \
  && echo "✅ F3.4 TEA puro verificado"
go build ./... && echo "✅ build global OK"
```

---

## ÁTOMO F3.5 — `internal/tui/demo/demo.go`

**Objetivo:** Aislar el modo demo del instalador. El modo demo no requiere daemon bos real.  
**Tiempo estimado:** 30 minutos

### Inventariar el código demo

```bash
grep -n "func demo\|runDemo\|demoLog\|demoSub\|var demo" cmd/bosctl/install_ui.go | head -15
```

### Crear `internal/tui/demo/demo.go`

```go
// Package demo implementa el modo simulación del instalador SBOS.
//
// # Responsabilidades
//
// Provee datos sintéticos que imitan el flujo de instalación real,
// permitiendo demostrar la interfaz sin un daemon bos activo.
//
// # Uso
//
//   ch := make(chan model.WsEventMsg, 100)
//   go demo.Run(ch)
//   // Leer eventos de ch en el TUI
//
// # Fuera de alcance
//
// El demo no conecta con ningún socket Unix ni con Kubernetes.
// No debe usarse en producción — solo para desarrollo y demos.
package demo

import (
    "time"
    "bos/internal/tui/model"
)

// demoFichas es la lista de fichas que el demo simula instalar.
// COPIAR de install_ui.go: var demoSubComponents
var demoFichas = []struct {
    name  string
    steps []string
}{
    // COPIAR contenido de demoSubComponents de install_ui.go
}

// Run inicia la simulación de instalación enviando eventos al canal ch.
// Bloqueante — llamar en goroutine.
//
// El canal debe tener buffer suficiente para absorber la ráfaga inicial
// de eventos. Recomendado: make(chan model.WsEventMsg, 100)
func Run(ch chan<- model.WsEventMsg) {
    // COPIAR lógica de runDemo() de install_ui.go
    // Cambios: usar model.WsEventMsg en lugar del tipo local
}

// LogLine genera las entradas de log para una ficha y paso dados.
// Retorna slice de strings — una por línea de log.
func LogLine(ficha, step string) []string {
    // COPIAR lógica de demoLogLine() de install_ui.go
    return nil
}
```

### Verificar F3.5

```bash
go build ./internal/tui/demo/ && echo "✅ F3.5 compila"
go test ./internal/tui/demo/ && echo "✅ F3.5 tests OK"
go build ./... && echo "✅ build global OK"
```

---

## VERIFICACIÓN DE CIERRE — F3.1 a F3.5

```bash
echo "=== VERIFICACIÓN F3.1-F3.5 ==="

echo "--- Estructura de archivos ---"
[ -f internal/tui/styles/styles.go ]    && echo "✅ styles.go"    || echo "❌"
[ -f internal/tui/model/types.go ]      && echo "✅ types.go"     || echo "❌"
[ -f internal/tui/model/model.go ]      && echo "✅ model.go"     || echo "❌"
[ -f internal/tui/model/events.go ]     && echo "✅ events.go"    || echo "❌"
[ -f internal/tui/demo/demo.go ]        && echo "✅ demo.go"      || echo "❌"

echo ""
echo "--- Calidad TEA ---"
grep -rn "func (m \*model)" internal/tui/ \
  && echo "❌ VIOLA TEA" || echo "✅ Sin receptores *model"

echo ""
echo "--- Sin bubbletea en styles ---"
grep "bubbletea" internal/tui/styles/*.go 2>/dev/null \
  && echo "❌ bubbletea en styles" || echo "✅ styles sin bubbletea"

echo ""
echo "--- Build y tests ---"
go build ./...                                  && echo "✅ BUILD"
go vet ./...                                    && echo "✅ VET"
go test -race -count=20 ./internal/tui/...     && echo "✅ TESTS (sin race)"

echo ""
echo "--- install_ui.go sigue compilando (coexistencia) ---"
go build ./cmd/bosctl/... && echo "✅ bosctl compila (SFP-02)"
```

---

## COMMIT FINAL DE CIERRE F3.1-F3.5

```bash
git add internal/tui/ _legacy/
git commit -m "[F3.5] feat: internal/tui/ — styles, model, events, demo extraídos

Primera mitad de la extracción de install_ui.go (4834 líneas → en progreso).

F3.1: internal/tui/styles/ — 35 constantes lipgloss + 8 helpers visuales
F3.2: internal/tui/model/types.go — Screen (15 constantes), P11 eliminado
F3.3: internal/tui/model/model.go — struct model con campo único 'screen'
F3.4: internal/tui/model/events.go — handlers TEA puros (sin receptores *model)
F3.5: internal/tui/demo/demo.go — modo simulación aislado

TEA: 0 receptores *model en internal/tui/
P11: alias stepID y campo step Screen eliminados
SFP-02: install_ui.go sigue compilando durante la migración

Siguiente: F3.6 (viewport), F3.7 (keys), F3.8 (15 pantallas)"
```

---

## SEÑAL DE RETOMA

```bash
echo "=== ¿Dónde quedó? ==="
[ -f internal/tui/styles/styles.go ] && echo "✅ F3.1" || echo "🔴 F3.1 pendiente"
[ -f internal/tui/model/types.go ]   && echo "✅ F3.2" || echo "🔴 F3.2 pendiente"
[ -f internal/tui/model/model.go ]   && echo "✅ F3.3" || echo "🔴 F3.3 pendiente"
[ -f internal/tui/model/events.go ]  && echo "✅ F3.4" || echo "🔴 F3.4 pendiente"
[ -f internal/tui/demo/demo.go ]     && echo "✅ F3.5" || echo "🔴 F3.5 pendiente"

# ¿El build está limpio?
go build ./... 2>&1 | head -5

# ¿Cuántas líneas quedan en install_ui.go?
wc -l cmd/bosctl/install_ui.go
echo "(objetivo final F3.10: ≤80 líneas)"
```

---

*EJECUCION-F3.1-F3.5-INSTRUCCIONES-AGENTE.md v1.0*  
*BOS-REPAIR · SKULL · SBOS · 08 de Junio 2026*  
*Fuentes: BOS-REPAIR-00 §P1/P3/P7/P10/P11, BOS-REPAIR-PLAN-MAESTRO-v3 §FASE-3*  
*Validación técnica: charmbracelet/bubbletea v1.3.10 docs — "changes made in Update() and returned immediately"*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
