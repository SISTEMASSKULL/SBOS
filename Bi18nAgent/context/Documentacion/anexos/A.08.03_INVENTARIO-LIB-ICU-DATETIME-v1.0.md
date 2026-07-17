# A.08.03 — Inventario de Exposición: icu_datetime 2.2.0

**Crate:** `icu_datetime`
**Versión en Cargo.toml:** 2.2.0
**Archivo handler:** `src/server/handlers/lib_icu_datetime.rs`
**Categoría:** Formato de fechas y horas con reglas ICU/CLDR por locale
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/icu_datetime-2.2.0/src/`

⚠️ API 2.x completamente distinta de 1.x: los formatters son genéricos sobre field-sets. No usar documentación de versiones anteriores.

---

## Inventario completo de exposición

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `DateTimeFormatter::try_new(prefs, YMDT::medium()).format(dt)` | `bi18n.format.datetime_icu` | 2 | ✅ Implementado |
| 2 | `DateTimeFormatter` con `DateFieldSet::YMD` (longitud variable) | `bi18n.format.date_icu` | 2 | ✅ Implementado |
| 3 | `NoCalendarFormatter` con `T::hm()` / `T::hms()` | `bi18n.format.time_icu` | 2 | ✅ Implementado |
| 4 | `DateTimeFormatter` con `DateFieldSet::E::long()` (weekday standalone) | `bi18n.format.weekday_name` | 2 | ✅ Implementado |
| 5 | `DateTimeFormatter` con `CalendarPeriodFieldSet::YM::long()` | `bi18n.format.month_name` | 2 | ✅ Implementado |
| 6 | `DateTimeFormatter` con `DateAndTimeFieldSet::YMDET` | `bi18n.format.datetime_with_time` | 2 | ✅ Implementado |
| 7 | `DateTimeFormatter::try_new_unstable(provider, prefs, field_set)` | — | — | ❌ Infra interna |
| 8 | `DateTimeFormatter::format_same_calendar(dt)` | — | — | 🔮 Futuro |
| 9 | `DateTimeFormatter::try_into_typed_formatter::<C>()` | — | — | ❌ Infra interna |
| 10 | `DateTimeFormatter::cast_into_fset::<FSet2>()` | — | — | ❌ Infra interna |
| 11 | `DateTimeFormatter::calendar()` | — | — | ❌ Infra interna |
| 12 | `DateTimeFormatter::to_field_set_builder()` | — | — | ❌ Infra interna |
| 13 | `FixedCalendarDateTimeFormatter::try_new(prefs, field_set)` | — | — | ❌ Infra interna |
| 14 | `FixedCalendarDateTimeFormatter::format(input)` | — | — | ❌ Infra interna |
| 15 | `FixedCalendarDateTimeFormatter::into_formatter(calendar)` | — | — | ❌ Infra interna |
| 16 | `FormattedDateTime::pattern()` → `DateTimePattern` | — | — | ❌ Infra interna |
| 17 | `fieldsets::YMD::short/medium/long/full()` | — | — | ❌ Infra interna |
| 18 | `fieldsets::YMDHM / YMDHMS / HM / HMS` | — | — | ❌ Infra interna |
| 19 | `fieldsets::YMD::medium().with_time_hm()` | — | — | ❌ Infra interna |
| 20 | `FieldSetBuilder::new().year().month()...build()` | — | — | ❌ Infra interna |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Infra interna — no se expone por RPC (se usa dentro del handler, no como operación directa)

---

## Notas de implementación

- Todos los métodos RPC reciben `locale` (BCP-47: `"es-BO"`) y `ts_unix` (Unix timestamp i64).
- El handler construye el `DateTimeFormatterPreferences` desde el locale del request.
- La longitud (`length`) acepta: `"short"`, `"medium"` (default), `"long"`, `"full"`.
- `bi18n.format.weekday_name` y `bi18n.format.month_name` usan fieldsets con componente extendido (YMDE / YM) y extraen la parte textual del resultado formateado.
- `format_same_calendar` marcado como 🔮 Futuro: útil para multi-calendario (gregoriano/islámico/etc.) pero no en plan actual.
- `icu_compactdecimal` (CompactDecimalFormatter) **no está en Cargo.toml** — no implementar aquí.

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: REGISTRO-ESTADO-DOS.md Bloque D · src/server/handlers/lib_icu_datetime.rs*
