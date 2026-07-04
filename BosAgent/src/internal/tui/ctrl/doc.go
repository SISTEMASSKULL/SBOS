// Package ctrl implementa el dashboard de control completo del daemon bos.
//
// # Arquitectura
//
// El paquete sigue el patrón Model-Update-View (BubbleTea) pero de forma
// autocontenida: DashModel tiene su propio Update() y se renderiza con Render().
// El código externo (install_ui_impl.go) lo embebe en el model principal y
// delega las teclas de navegación. Las acciones de sistema (reboot, shutdown)
// se comunican vía DashModel.PendingAction para que el código externo las ejecute.
//
// # Archivos
//
//   - model.go   — DashModel, tipos de datos, menuDef, subTabMax(), loadMock()
//   - render.go  — Render(), TopBar, BottomBar, Menu, Container (layout maestro)
//   - views.go   — 23 funciones render*, una por cada viewKey del menuDef
//   - widgets.go — helpers reutilizables: gauge, miniBar, sparklineASCII, subTabs
//   - dims_test.go — TestDims: verifica que cada vista produce exactamente h líneas
//
// # Reglas de layout (Lipgloss v1.1.0, validadas empíricamente)
//
//   - Box.Width(w)  → ancho visual = w+2  (el borde agrega 2; el padding va dentro de w)
//   - Box.Height(h) → alto visual  = h+2  (el borde agrega 2)
//   - Contenido interior: ancho = w-2  (padding 0,1 consume 2)
//
// # Grilla 12 columnas
//
// El dashboard usa una grilla proporcional de 12 columnas:
//
//   - Menú:       3/12 del ancho total (mínimo 24 cols)
//   - Contenedor: 9/12 restantes
//
// # DashAction — comunicación de acciones de sistema
//
// Cuando el usuario presiona Ctrl+R (reboot) o Ctrl+P (shutdown), Update()
// asigna DashModel.PendingAction. El llamador debe leer esta campo después de
// cada Update() y ejecutar la acción correspondiente. Se limpia automáticamente
// al inicio de cada ciclo de Update().
//
// # Tests
//
// dims_test.go itera automáticamente todos los ítems navegables de menuDef y
// verifica que Render() produce exactamente h líneas para w=100, h=30. Añadir
// un nuevo viewKey al menuDef sin su función render* falla el test.
package ctrl
