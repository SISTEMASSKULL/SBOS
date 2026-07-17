# A.08.10 — Inventario de Exposición: jiff 0.2.32

**Crate:** `jiff`
**Versión en Cargo.toml:** 0.2.32
**Archivo handler:** `src/server/handlers/lib_jiff.rs`
**Categoría:** Fecha y hora moderna — IANA timezones, DST-aware, spans, series
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/jiff-0.2.32/src/`

---

## Inventario completo de exposición

### Timestamp (instante absoluto UTC)

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `Timestamp::now()` | `bi18n.datetime.now_utc` | 2 | 📋 Fase 2 |
| 2 | `Timestamp::now().to_zoned(TimeZone::get(tz)?)` | `bi18n.datetime.now_tz` | 2 | 📋 Fase 2 |
| 3 | `Timestamp::strptime(fmt, s)` ⚠️ (no `parse`) | `bi18n.datetime.parse_jiff` | 2 | 📋 Fase 2 |
| 4 | `Timestamp::from_second(secs)` | `bi18n.datetime.from_unix` | 2 | 📋 Fase 2 |
| 5 | `Timestamp::from_millisecond(ms)` | — | — | 🔮 Futuro |
| 6 | `Timestamp::from_microsecond(us)` | — | — | 🔮 Futuro |
| 7 | `Timestamp::as_second()` / `as_millisecond()` | — | — | ❌ Infra interna |
| 8 | `Timestamp::series(span)` | `bi18n.datetime.series` | 2 | 📋 Fase 2 |
| 9 | `Timestamp::strftime(fmt)` | `bi18n.datetime.format_jiff` | 2 | 📋 Fase 2 |

### Zoned (instante con timezone IANA)

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 10 | `z.checked_add(Span::new().hours(N))` | `bi18n.datetime.add_span` | 2 | 📋 Fase 2 |
| 11 | `z.checked_sub(span)` | `bi18n.datetime.sub_span` | 2 | 📋 Fase 2 |
| 12 | `z1.until(&z2)` | `bi18n.datetime.diff_span` | 2 | 📋 Fase 2 |
| 13 | `z.with_time_zone(TimeZone::get(tz2)?)` | `bi18n.datetime.convert_tz` | 2 | 📋 Fase 2 |
| 14 | `z.round(SpanRound::new().smallest(Unit::Minute))` | `bi18n.datetime.round` | 2 | 📋 Fase 2 |
| 15 | `z.weekday()` | `bi18n.datetime.weekday_of_date` | 2 | 📋 Fase 2 |
| 16 | `z.strftime(fmt)` | — | — | ❌ Infra interna |
| 17 | `Zoned::now()` / `z.year()` / `z.month()` etc. | — | — | ❌ Infra interna |

### civil::Date

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 18 | `civil::Date::new(y,m,1)?.days_in_month()` | `bi18n.datetime.days_in_month` | 2 | 📋 Fase 2 |
| 19 | `civil::Date::new(y,1,1)?.in_leap_year()` | `bi18n.datetime.is_leap_year` | 2 | 📋 Fase 2 |
| 20 | `date.nth_weekday_of_month(n, weekday)` | `bi18n.datetime.nth_weekday` | 2 | 📋 Fase 2 |
| 21 | `date.series(Span::new().days(1)).take(N)` | — | — | 🔮 Futuro |
| 22 | `date.first_of_month()` / `date.last_of_month()` | — | — | 🔮 Futuro |
| 23 | `date.tomorrow()` / `date.yesterday()` | — | — | 🔮 Futuro |
| 24 | `date.strptime(fmt, s)` / `date.strftime(fmt)` | — | — | ❌ Infra interna |

### Span

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 25 | `span.total(Unit::Hours)` | `bi18n.datetime.span_total` | 2 | 📋 Fase 2 |
| 26 | `Span::new().years(N).months(N).days(N)...` | — | — | ❌ Infra interna |
| 27 | `span.get_years/get_months/get_days/...` | — | — | ❌ Infra interna |
| 28 | `span.abs()` / `span.negate()` / `span.signum()` | — | — | 🔮 Futuro |
| 29 | `span.checked_mul(N)` / `checked_add()` / `checked_sub()` | — | — | 🔮 Futuro |

### TimeZone

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 30 | `TimeZone::get("America/La_Paz")?.iana_name()` | `bi18n.datetime.tz_info` | 2 | 📋 Fase 2 |
| 31 | `TimeZone::system()` / `try_system()` | — | — | ❌ Infra interna |
| 32 | `tz.to_datetime(ts)` / `to_offset(ts)` / `to_fixed_offset()` | — | — | ❌ Infra interna |
| 33 | `tz.preceding(ts)` / `following(ts)` — transiciones DST | — | — | 🔮 Futuro |

### SignedDuration

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 34 | `SignedDuration::from_secs(n)` / `as_secs()` / `as_millis()` | — | — | 🔮 Futuro |
| 35 | `sd.checked_add/sub/mul` / `saturating_*` | — | — | 🔮 Futuro |
| 36 | `sd.abs()` / `is_zero()` / `as_secs_f64()` | — | — | 🔮 Futuro |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Infra interna — no se expone por RPC

---

## Notas de implementación

- ⚠️ El método de parsing de Timestamp es `strptime(fmt, s)` — **no** `parse(fmt, s)`.
- Todos los métodos RPC que reciben timestamps usan Unix epoch i64 (segundos).
- `bi18n.datetime.series` recibe `from_unix`, `tz`, `step_days`, `count` → retorna array de timestamps.
- `bi18n.datetime.span_total` acepta `days?`, `hours?`, `minutes?` y `unit:"hours|days|minutes|seconds"`.
- La aritmética DST-aware es la ventaja principal de jiff sobre chrono: sumar `1.month()` respeta cambios de horario.
- `civil::Date::series` marcado 🔮 Futuro — ya cubierto por `bi18n.datetime.series` via Timestamp.
- `SignedDuration` marcado 🔮 Futuro — útil para operaciones de duración ISO 8601 pero no en plan actual.

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: REGISTRO-ESTADO-DOS.md Bloque K · src/server/handlers/lib_jiff.rs*
