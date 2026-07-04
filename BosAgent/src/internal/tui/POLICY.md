# POLICY.md — Política de Pantallas del TUI de bos

*Aplica a: `internal/tui/screens/`, `internal/tui/model/types.go`*

---

## §1 — Inventario de las 15 pantallas

### Grupo SPLASH (sin viewport — fullscreen simple)

| ID | Constante | Archivo en screens/ | Viewport | Descripción |
|---|---|---|---|---|
| P0 | `ScreenWelcome` | `welcome.go` | ninguno | Splash inicial — logo SBOS + barra de progreso de arranque. Se salta automáticamente cuando bootPct ≥ 1.0 |
| P14 | `ScreenGoodbye` | `goodbye.go` | ninguno | Splash de cierre — mensaje de despedida. Aparece tras shutdown completado |

### Grupo WIZARD (viewport: bodyVP global)

| ID | Constante | Archivo en screens/ | Viewport | Descripción |
|---|---|---|---|---|
| P1 | `ScreenWizardP1` | `wizard_p1.go` | bodyVP | Bienvenida al instalador — dos botones: Comenzar / Salir. Muestra condiciones mínimas |
| P2 | `ScreenWizardP2` | `wizard_p2.go` | bodyVP | Datos de la empresa — 4 campos: Razón Social, NIT, País, Dominio |
| P3 | `ScreenWizardP3` | `wizard_p3.go` | bodyVP | Cuenta admin — 4 campos: Email, Nombre, Password, Confirm + toggle MFA |
| P3B | `ScreenWizardCapacity` | `wizard.go` | bodyVP | Estimados de capacidad — 4 campos: tenants, empresas, sucursales, usuarios + panel cálculo en tiempo real |
| P4 | `ScreenWizardP4` | `wizard_p4.go` | bodyVP | Confirmación — resumen de datos + 3 botones: Instalar / Auto / Volver |

### Grupo INSTALACIÓN

| ID | Constante | Archivo en screens/ | Viewport | Descripción |
|---|---|---|---|---|
| P5 | `ScreenInstalling` | `installing.go` | vpA + vpB + vpC | Instalación en progreso — 3 columnas: árbol de fases/fichas, pasos del activo, log en vivo |
| P5B | `ScreenInstallLog` | `install_log.go` | vpC (fullscreen) | Log completo fullscreen — accesible con L desde P5 |
| P5C | `ScreenInstallErr` | `install_err.go` | vpC + menú lateral | Panel de error con 4 acciones: Reintentar / Saltar / Log / Cancelar |
| P6 | `ScreenInstallDone` | `done.go` | sectionVP | Instalación completada — 4 secciones: Tenant, Ubuntu, K8s, SBOS/bos |

### Grupo LIFECYCLE (viewport: bodyVP)

| ID | Constante | Archivo en screens/ | Viewport | Descripción |
|---|---|---|---|---|
| P7 | `ScreenReboot` | `reboot.go` | bodyVP | Cuenta regresiva de reinicio (10s) — Enter para acelerar, Esc para volver |
| P8 | `ScreenBoot` | `boot.go` | bodyVP | Animación de arranque del sistema — progreso 0..100% con mensajes |
| P11 | `ScreenShutdown` | `shutdown.go` | bodyVP | Progreso de apagado/reinicio — modo "shutdown" o "restart" |

### Grupo OPERACIONAL

| ID | Constante | Archivo en screens/ | Viewport | Descripción |
|---|---|---|---|---|
| P9 | `ScreenDashboard` | `dashboard.go` | vpDash | Dashboard permanente post-instalación — estado de daemons, uptime, resumen |
| P10 | `ScreenLogs` | `logs.go` | vpLog | Logs puros — filtro por nivel (logLevel) y fuente (bos/bkernel/bauth/etc.) |

---

## §2 — Política de estilos

**Regla 2.1 — Zero inline.** Ningún archivo de `screens/` define estilos lipgloss
inline. Toda variable `lipgloss.NewStyle()...` va en `styles/styles.go`.

**Regla 2.2 — Nomenclatura.** Los estilos exportados siguen la convención:
- Colores: `Color<Nombre>` (ej: `ColorGreen`, `ColorCyan`)
- Estilos de texto: `Style<Contexto>` (ej: `StyleBold`, `StyleDim`)
- Componentes: nombre descriptivo (ej: `TopBar`, `Footer`, `Box`, `BoxActive`)
- Iconos: funciones `Icon<Nombre>()` (ej: `IconOK()`, `IconErr()`)

**Regla 2.3 — Un solo archivo.** Todos los estilos viven en `styles/styles.go`.
Si el archivo supera 300 líneas, separar en `styles/colors.go` y `styles/components.go`.

---

## §3 — Proceso de modificación de pantallas existentes

Antes de modificar cualquier pantalla:
1. Verificar que el archivo `screens/<pantalla>.go` existe y tiene doc ADR-003
2. Leer el inventario §1 para entender el viewport asignado
3. NO cambiar el viewport asignado sin actualizar este documento
4. Toda modificación visual que cambie el layout debe verificarse en:
   - 80 columnas (mínimo)
   - 120 columnas (normal)
   - 200 columnas (ancho)
5. Actualizar el DoD en el INFORME-CIERRE correspondiente

---

## §4 — Política de adición de nuevas pantallas

**Regla 4.1 — Aprobación previa.** Una nueva pantalla requiere:
- ADR aprobado por sbos-coordinador
- Actualización de este POLICY.md antes de escribir código

**Regla 4.2 — Contrato previo.** Antes de implementar `screens/<nueva>.go`:
1. Añadir la constante al enum `Screen` en `model/types.go`
2. Añadir el archivo `screens/<nueva>.go` con solo el `doc.go` ADR-003
3. Añadir la entrada al dispatcher `screens/dispatcher.go`
4. Agregar la pantalla al inventario §1 de este documento
5. Solo entonces implementar el cuerpo

**Regla 4.3 — Viewport obligatorio.** Toda pantalla debe tener un viewport
asignado explícitamente. "ninguno" es válido solo para splashes fullscreen simples.

**Regla 4.4 — Sin lógica de negocio.** El archivo de pantalla solo llama funciones
de render. Si necesita cálculos, estos van en `model/` como métodos de Model.

**Regla 4.5 — Demo obligatorio.** La nueva pantalla debe estar cubierta por `demo/`.
Añadir el evento sintético correspondiente a `demo/simulate.go`.

**Regla 4.6 — Tests obligatorios.** Crear `screens/<nueva>_test.go` con al menos:
- Test con modelo en estado mínimo (no panea)
- Test con modelo en estado completo (renderiza sin truncar)
- Test de responsividad: width 80 y width 200

**Regla 4.7 — Grupo asignado.** La pantalla debe pertenecer a uno de los 5 grupos
del §1. Si no encaja, proponer un grupo nuevo al sbos-coordinador antes de proceder.

---

## §5 — Regla de viewport por grupo

| Grupo | Viewport(s) | Recálculo en WindowSizeMsg |
|---|---|---|
| SPLASH | ninguno | no aplica |
| WIZARD | bodyVP | sí — recalcBodyHeight() |
| INSTALACIÓN P5/P5B/P5C | vpA + vpB + vpC | sí — vpDims() |
| INSTALACIÓN P6 | sectionVP | sí — bodyHeight - 1 por tabs |
| LIFECYCLE | bodyVP | sí — recalcBodyHeight() |
| OPERACIONAL P9 | vpDash | sí — width-4, bodyHeight |
| OPERACIONAL P10 | vpLog | sí — width-4, bodyHeight |

**Regla crítica (corrige P10):** Todo resize de terminal DEBE recalcular TODOS los
viewports, incluso los de pantallas inactivas. Un viewport con altura 0 produce
panic en BubbleTea. Ver install_ui.go L1115-1165 para la implementación actual.

---

---

## §6 — Procedimiento con generador (bosctl dev new-screen) — 7 pasos

Desde F3.17, el generador automatiza los pasos 1–5. Ejecutar en `BosAgent/src/`:

**Paso 1 — Ejecutar el generador**
```bash
bosctl dev new-screen <NombrePascalCase> [--group=<grupo>]
```
Crea automáticamente: archivo de pantalla, test básico; parcha types.go,
dispatcher.go y keys.go.

**Paso 2 — Implementar el cuerpo**
Editar `internal/tui/screens/<grupo>.go`: reemplazar el stub en `build<Nombre>Body`.
Seguir el patrón de pantallas existentes (assembleScreen, Mode, summaryRow).

**Paso 3 — Actualizar test guardián**
En `dispatcher_test.go`, agregar a `knownScreens`:
```go
{"Screen<Nombre>", tuimodel.Screen<Nombre>},
```

**Paso 4 — Ajustar keybindings**
En `internal/tui/model/keys.go`, completar el `case Screen<Nombre>:` insertado por el generador.

**Paso 5 — DoD Universal**
```bash
go build ./... && go vet ./... && gofmt -l . | wc -l | grep "^0$" && go test -race -count=10 ./...
```

**Paso 6 — Actualizar PARIDAD.md y POLICY.md §1**
Agregar fila en `PARIDAD.md` y en la tabla §1 de este archivo.

**Paso 7 — Commit semántico**
```
[Fx.y] feat: pantalla Screen<Nombre> — <descripción>
```

### Reglas invariantes del generador

| # | Regla |
|---|-------|
| R1 | `Render<N>` es pura: `Model` → `string`, sin efectos secundarios |
| R2 | Todo screen usa `assembleScreen(m, body)` salvo splash (S00/S14) |
| R3 | Toda pantalla tiene test `SinPanic` + race×10 |
| R4 | `gofmt` antes de commit — cero archivos mal formateados |
| R5 | El dispatcher solo crece (nunca eliminar un caso) — SFP-01 |
| R6 | Nueva Screen siempre antes de `ScreenGoodbye` en types.go |
| R7 | `TestScreens_TodasRegistradasEnDispatcher` debe pasar antes del commit |

*POLICY.md v1.0 · BOS-REPAIR F0.3 · 2026-06-09*

---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
