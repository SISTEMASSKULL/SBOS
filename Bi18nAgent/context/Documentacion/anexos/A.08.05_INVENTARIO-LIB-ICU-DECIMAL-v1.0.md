# A.08.05 — Inventario de Exposición: icu_decimal 2.2.0

**Crate:** `icu_decimal`
**Versión en Cargo.toml:** 2.2.0
**Archivo handler:** `src/server/handlers/lib_icu_decimal.rs`
**Categoría:** Formato de números con dígitos locales (árabe, thai, devanagari, etc.)
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/icu_decimal-2.2.0/src/`

⚠️ `CompactDecimalFormatter` (números "1.2M", "3B") pertenece al crate `icu_compactdecimal` que **NO está en el Cargo.toml** de bi18n. No implementar métodos que dependan de él.

---

## Inventario completo de exposición

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `DecimalFormatter::try_new(prefs, opts)` con `GroupingStrategy::Auto` | `bi18n.format.number_icu` | 2 | ✅ Implementado |
| 2 | `DecimalFormatter` con `GroupingStrategy::Never` | `bi18n.format.number_no_grouping` | 2 | ✅ Implementado |
| 3 | `DecimalFormatter` con `GroupingStrategy::Always` | `bi18n.format.number_grouping_always` | 2 | ✅ Implementado |
| 4 | `DecimalFormatter` con `GroupingStrategy::Min2` | `bi18n.format.number_grouping_min2` | 2 | ✅ Implementado |
| 5 | `DecimalFormatter::try_new_unstable(provider, prefs, opts)` | — | — | ❌ Infra interna |
| 6 | `DecimalFormatter::try_new_with_buffer_provider(provider, prefs, opts)` | — | — | ❌ Infra interna |
| 7 | `DecimalFormatter::format(value: &Decimal)` → `FormattedDecimal` | — | — | ❌ Infra interna |
| 8 | `DecimalFormatter::format_to_string(value: &Decimal)` | — | — | ❌ Infra interna |
| 9 | `DecimalFormatterPreferences { locale_preferences, numbering_system }` | — | — | ❌ Infra interna |
| 10 | `GroupingStrategy::Auto / Never / Always / Min2` | — | — | ❌ Infra interna |
| 11 | `Decimal::from(42i64)` / `Decimal::from_str("3.14")` | — | — | ❌ Infra interna |
| 12 | `Decimal::multiply_pow10(-2)` (ajustar punto decimal) | — | — | ❌ Infra interna |
| 13 | `NumberingSystem` (sistema de numeración específico) | — | — | 🔮 Futuro |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Infra interna — no se expone por RPC

---

## Notas de implementación

- Todos los métodos RPC reciben `locale` (BCP-47) y `number` (i64 o f64).
- `bi18n.format.number_icu` usa `GroupingStrategy::Auto` — sigue las convenciones del locale (separador de miles).
- Para locales árabes (`ar-EG`): `12345` → `"١٢٬٣٤٥"` automáticamente con `Auto`.
- `NumberingSystem` marcado 🔮 Futuro: permite forzar un sistema distinto al del locale (e.g. forzar `latn` en locale árabe).
- El tipo `Decimal` (de `fixed_decimal`) acepta tanto enteros como decimales: `Decimal::from(42i64)`, `"3.14".parse::<Decimal>()`.
- El handler construye el `DecimalFormatter` desde `DecimalFormatterPreferences { locale_preferences: locale.into(), numbering_system: None }`.

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: REGISTRO-ESTADO-DOS.md Bloque F · src/server/handlers/lib_icu_decimal.rs*
