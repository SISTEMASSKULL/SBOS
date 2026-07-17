# A.08.04 — Inventario de Exposición: icu_locale_core 2.2.0 + icu_locale 2.2.0

**Crates:** `icu_locale_core` (tipos BCP-47) + `icu_locale` (canonicalización, expansión, fallback)
**Versión en Cargo.toml:** 2.2.0
**Archivo handler:** `src/server/handlers/lib_icu_locale.rs`
**Categoría:** Locales BCP-47 — parsing, canonicalización, negociación, fallback
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/icu_locale_core-2.2.0/src/` · `icu_locale-2.2.0/src/`

⚠️ `Locale::canonicalize()` **NO existe** en `icu_locale_core`. La canonicalización vive en `LocaleCanonicalizer` del crate `icu_locale`.

---

## Inventario completo de exposición

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `Locale::try_from_str(s)` — parsear y validar locale BCP-47 | `bi18n.locale.parse_bcp47` | 2 | 📋 Fase 2 |
| 2 | `LocaleCanonicalizer::canonicalize(&self, &mut locale)` — crate `icu_locale` | `bi18n.locale.canonicalize` | 2 | 📋 Fase 2 |
| 3 | `LocaleFallbacker::for_config(cfg).fallback_for(locale)` — iteración de fallback | `bi18n.locale.negotiate` | 2 | 📋 Fase 2 |
| 4 | parsear subtags: `locale.id.language`, `.script`, `.region`, `.variants` | `bi18n.locale.subtags` | 2 | 📋 Fase 2 |
| 5 | `Locale::normalize(input)` | — | — | 🔮 Futuro |
| 6 | `Locale::normalizing_eq(&self, other)` | — | — | 🔮 Futuro |
| 7 | `Locale::strict_cmp(&self, other)` | — | — | ❌ Infra interna |
| 8 | `LanguageIdentifier::try_from_str(s)` | — | — | ❌ Infra interna |
| 9 | `LanguageIdentifier::normalize(input)` | — | — | ❌ Infra interna |
| 10 | `LocaleCanonicalizer::try_new_common_unstable(provider)` | — | — | ❌ Infra interna |
| 11 | `LocaleCanonicalizer::try_new_extended_unstable(provider)` | — | — | ❌ Infra interna |
| 12 | `LocaleExpander::maximize(&mut langid)` — añadir script y región | — | — | 🔮 Futuro |
| 13 | `LocaleExpander::minimize(&mut langid)` — quitar subtags redundantes | — | — | 🔮 Futuro |
| 14 | `LocaleExpander::minimize_favor_script(&mut langid)` | — | — | 🔮 Futuro |
| 15 | `LocaleFallbacker::try_new_unstable(provider)` | — | — | ❌ Infra interna |
| 16 | `LocaleFallbacker::new_without_data()` | — | — | ❌ Infra interna |
| 17 | `LocaleFallbackIterator::get()` / `step()` / `take()` | — | — | ❌ Infra interna |
| 18 | `Locale::UNKNOWN` (constante "und") | — | — | ❌ Infra interna |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Infra interna — no se expone por RPC

---

## Notas de implementación

- `bi18n.locale.canonicalize` recibe `locale_str: "zh-TW"` → retorna `{"canonical": "zh-Hant-TW"}`. Usa `LocaleCanonicalizer::try_new_common_unstable` internamente.
- `bi18n.locale.negotiate` recibe `preferences: ["es-BO", "es"]` y `available: ["es-BO", "en-US"]` → retorna `{"best": "es-BO"}` usando `LocaleFallbackIterator`.
- `bi18n.locale.subtags` retorna `{"language": "es", "script": null, "region": "BO", "variants": []}`.
- `LocaleExpander::maximize/minimize` marcados 🔮 Futuro: útiles para maximización `"es" → "es-Latn-ES"` pero no en plan actual.
- El handler inicializa `LocaleCanonicalizer` y `LocaleFallbacker` una sola vez al arrancar el daemon (costoso — proveedor ICU4X).

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: REGISTRO-ESTADO-DOS.md Bloque E · src/server/handlers/lib_icu_locale.rs*
