# styles-fix — Correcciones v1.1

## Archivos en este directorio

| Archivo | Reemplaza |
|---|---|
| `tokens_component.go` | `internal/tui/styles/tokens_component.go` |
| `theme.go` | `internal/tui/styles/theme.go` |

## Instrucciones

```bash
# Desde la raíz del proyecto
cp tokens_component.go internal/tui/styles/tokens_component.go
cp theme.go            internal/tui/styles/theme.go

# Verificar que compila
go build ./internal/tui/styles/...
```

## Qué cambió

### tokens_component.go

1. **`AppFrame` declarado** — `var AppFrame lipgloss.Style`
   al tope del archivo (sección nueva §3.4 AppFrame).
   La construcción ocurre en `rebuildThemeComponents()` de `theme.go`.

2. **`Subtitle` duplicado eliminado** — el bloque `var` suelto al
   final del archivo que redeclaraba `Subtitle` fue eliminado.
   `Subtitle` queda declarado UNA sola vez en el bloque de texto (T03).
   `SectionTitle = Subtitle` en los aliases sigue funcionando.

3. **`TextBold` y `Subtitle` integrados** al bloque de texto principal
   junto con el resto de la escala tipográfica — sin bloques var sueltos.

### theme.go

1. **`AccentLight`, `AccentDark`, `AccentBorder` agregados al struct `Theme`**
   Antes solo existían `Accent` y `AccentText`. Sin los tres nuevos campos,
   al cambiar a un tema no-cyan (esmeralda, indigo, fuchsia, ambar),
   los tokens `ColorAccentLight`/`ColorAccentDark`/`ColorAccentBorder`
   quedaban con los valores de cyan de la inicialización estática.

2. **`ApplyTheme()` muta los tres tokens nuevos**
   ```go
   ColorAccentLight  = t.AccentLight
   ColorAccentDark   = t.AccentDark
   ColorAccentBorder = t.AccentBorder
   ```

3. **`AppFrame` construido en `rebuildThemeComponents()`**
   Borde `NormalBorder` para temas corporativos (abyss/obsidian/pizarron).
   Borde `RoundedBorder` para temas expresivos (esmeralda/indigo/fuchsia/ambar).
   Width y Height se aplican al render en `View()` del Model raíz:
   ```go
   AppFrame.Width(m.frameW).Height(m.frameH).Render(inner)
   ```

4. **Todos los temas actualizados** con los tres campos nuevos de acento.

## Qué NO cambió

- `tokens_primitive.go` — sin tocar
- `tokens_state.go` — sin tocar
- `tokens_semantic.go` — sin tocar
- `grid.go` — sin tocar
- `icons.go` — sin tocar
- `huh_theme.go` — sin tocar
- `layout.go` — sin tocar
- `button.go` — sin tocar