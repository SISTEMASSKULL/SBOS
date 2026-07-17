# A.08.02 — Inventario de Exposición: rust-i18n 4.x

**Crate:** `rust-i18n`
**Versión en Cargo.toml:** 4.x
**Archivo handler:** `src/server/handlers/lib_rust_i18n.rs`
**Categoría:** Runtime locale — macro i18n + backend
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/rust-i18n-*/src/`

---

## Inventario completo de exposición

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `rust_i18n::locale()` | `bi18n.i18n.locale_activo` | 2 | ✅ Implementado |
| 2 | `rust_i18n::set_locale("es-BO")` | `bi18n.i18n.set_locale` | 2 | ✅ Implementado |
| 3 | `available_locales!()` | `bi18n.i18n.available_locales` | 2 | ✅ Implementado |
| 4 | `t!("key", locale = "es-BO", arg = val)` | `bi18n.i18n.translate` | 2 | ✅ Implementado |
| 5 | `i18n!("locales/", fallback = "en-US")` | — | — | ❌ Infra interna |
| 6 | `tkv!("key", key1 = val1, key2 = val2)` | — | — | ❌ Infra interna |
| 7 | `extend!(backend)` | — | — | ❌ Infra interna |
| 8 | `replace_patterns(text, args)` | — | — | ❌ Infra interna |
| 9 | `trait Backend::available_locales()` | — | — | ❌ Infra interna |
| 10 | `trait Backend::translate(locale, key)` | — | — | ❌ Infra interna |
| 11 | `trait Backend::messages_for_locale(locale)` | — | — | ❌ Infra interna |
| 12 | `SimpleBackend` struct | — | — | ❌ Infra interna |
| 13 | `NamespacedBackend` struct | — | — | ❌ Infra interna |
| 14 | `CowStr` / `AtomicStr` | — | — | ❌ Infra interna |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Infra interna — no se expone por RPC (uso interno del daemon)

---

## Notas de implementación

- `bi18n.i18n.set_locale` cambia el locale activo del daemon para el contexto del request — no es un cambio global persistente entre requests.
- `bi18n.i18n.translate` es equivalente a `t!()` pero invocable por RPC con `locale` explícito.
- `bi18n.i18n.available_locales` retorna la lista de locales cargados: `["es-BO", "en-US", "pt-BR"]`.
- El locale activo global lo gestiona `ArcSwap` (ya implementado — `c92e20b`); rust-i18n complementa con sus propias traducciones TOML/YAML para el caso donde no se usa Fluent.
- Las macros `i18n!`, `tkv!`, `extend!` son compile-time — no tienen equivalente RPC.

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: REGISTRO-ESTADO-DOS.md Bloque B · src/server/handlers/lib_rust_i18n.rs*
