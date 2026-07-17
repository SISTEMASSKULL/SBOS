# A.08.01 — Inventario de Exposición: fluent-bundle 0.15.3

**Crate:** `fluent-bundle`
**Versión en Cargo.toml:** 0.15.3
**Archivo handler:** `src/server/handlers/lib_fluent.rs`
**Categoría:** Traducción directa (Fluent Project — Mozilla)
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/fluent-bundle-0.15.3/src/`

---

## Inventario completo de exposición

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `FluentBundle::has_message(id)` | `bi18n.translate.has_message` | 2 | ✅ Implementado |
| 2 | `FluentBundle::get_message(id)` + `format_pattern(pattern, args, errors)` | `bi18n.translate.message` | 2 | ✅ Implementado |
| 3 | `FluentBundle::get_message(id)` múltiples ids | `bi18n.translate.batch` | 2 | ✅ Implementado |
| 4 | mensajes activos del bundle | `bi18n.translate.list_messages` | 2 | ✅ Implementado |
| 5 | `FluentBundle::format_pattern` con `FluentArgs` | `bi18n.translate.message_with_args` | 2 | ✅ Implementado |
| 6 | `FluentMessage::attributes()` — atributos `.label`, `.placeholder` | `bi18n.translate.attribute` | 2 | ✅ Implementado |
| 7 | `FluentBundle::new(locales)` / `new_concurrent(locales)` | — | — | ❌ Infra interna |
| 8 | `FluentBundle::add_resource(res)` | — | — | ❌ Infra interna |
| 9 | `FluentBundle::add_resource_overriding(res)` | — | — | ❌ Infra interna |
| 10 | `FluentBundle::set_use_isolating(v)` | — | — | ❌ Infra interna |
| 11 | `FluentBundle::set_transform(f)` | — | — | ❌ Infra interna |
| 12 | `FluentBundle::set_formatter(f)` | — | — | ❌ Infra interna |
| 13 | `FluentBundle::add_function(name, f)` | — | — | ❌ Infra interna |
| 14 | `FluentBundle::add_builtins()` | — | — | ❌ Infra interna |
| 15 | `FluentBundle::write_pattern(w, pattern, args, errors)` | — | — | ❌ Infra interna |
| 16 | `FluentResource::try_new(source)` | — | — | ❌ Infra interna |
| 17 | `FluentArgs::new()` / `args.set(key, val)` | — | — | ❌ Infra interna |
| 18 | `FluentMessage::value()` / `attributes()` / `attribute(name)` | — | — | ❌ Infra interna |
| 19 | `FluentAttribute::id()` / `value()` | — | — | ❌ Infra interna |
| 20 | `FluentValue` enum | — | — | ❌ Infra interna |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Infra interna — no se expone por RPC (uso interno del daemon)

---

## Notas de implementación

- Los métodos `FluentBundle::new`, `add_resource`, `format_pattern` son piezas internas del daemon — el handler `lib_fluent.rs` los usa pero no los expone directamente.
- Los 6 métodos RPC operan sobre el bundle cargado en memoria (hot-reload via `ArcSwap` — ya implementado en Fase 1, `c92e20b`).
- `bi18n.translate.message` acepta `args` opcionales como objeto JSON `{"nombre": "Pedro"}`.
- `bi18n.translate.batch` acepta un array de ids y devuelve un mapa `{id: texto}`.
- Error si el mensaje no existe: código FTL `translate-message-not-found`.
- Locale del request determina qué bundle se usa (campo `locale` en params o locale activo del daemon).

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: REGISTRO-ESTADO-DOS.md Bloque A · src/server/handlers/lib_fluent.rs*
