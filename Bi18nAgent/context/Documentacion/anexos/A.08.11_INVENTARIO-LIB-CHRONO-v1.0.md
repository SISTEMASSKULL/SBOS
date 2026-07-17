# A.08.11 — Inventario de Exposición: chrono 0.4.45

**Crate:** `chrono`
**Versión en Cargo.toml:** 0.4.45
**Archivo handler:** `src/server/handlers/lib_chrono.rs`
**Categoría:** Fecha y hora — strftime/RFC3339/RFC2822 + formateo localizado (unstable-locales)
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/chrono-0.4.45/src/`

---

## Inventario completo de exposición

### DateTime\<Tz\> — instante con timezone

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `DateTime::parse_from_rfc3339(s)` | `bi18n.datetime.chrono_parse_rfc3339` | 2 | 📋 Fase 2 |
| 2 | `DateTime::parse_from_rfc2822(s)` | `bi18n.datetime.chrono_parse_rfc2822` | 2 | 📋 Fase 2 |
| 3 | `dt.to_rfc3339()` | `bi18n.datetime.chrono_to_rfc3339` | 2 | 📋 Fase 2 |
| 4 | `dt.to_rfc2822()` | `bi18n.datetime.chrono_to_rfc2822` | 2 | 📋 Fase 2 |
| 5 | `dt.format(fmt).to_string()` | `bi18n.datetime.chrono_format` | 2 | 📋 Fase 2 |
| 6 | `dt.format_localized(fmt, Locale::es_ES).to_string()` — feature: unstable-locales | `bi18n.datetime.chrono_format_localized` | 2 | 📋 Fase 2 |
| 7 | `dt.timestamp()` / `timestamp_millis()` | `bi18n.datetime.chrono_to_unix` | 2 | 📋 Fase 2 |
| 8 | `dt.checked_add_signed(TimeDelta::hours(N))` | — | — | 🔮 Futuro |
| 9 | `dt.checked_sub_signed(TimeDelta)` | — | — | 🔮 Futuro |
| 10 | `dt.signed_duration_since(dt2)` | — | — | 🔮 Futuro |
| 11 | `dt.with_timezone(&Utc)` / `to_utc()` | — | — | ❌ Infra interna |
| 12 | `dt.date_naive()` / `dt.time()` / `dt.weekday()` | — | — | ❌ Infra interna |
| 13 | `DateTime::parse_from_str(s, fmt)` | — | — | 🔮 Futuro |

### NaiveDate — fecha sin zona horaria

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 14 | `NaiveDate::from_ymd_opt(y, m, d)?.leap_year()` | `bi18n.datetime.chrono_leap_year` | 2 | 📋 Fase 2 |
| 15 | `NaiveDate::parse_from_str(s, fmt)` | `bi18n.datetime.chrono_naive_parse` | 2 | 📋 Fase 2 |
| 16 | `NaiveDate::from_ymd_opt(y,m,d)` / `from_yo_opt` / `from_isoywd_opt` | — | — | ❌ Infra interna |
| 17 | `date.succ_opt()` / `pred_opt()` | — | — | 🔮 Futuro |
| 18 | `date.iter_days()` / `iter_weeks()` | — | — | 🔮 Futuro |
| 19 | `date.format_localized(fmt, locale)` | — | — | 🔮 Futuro |
| 20 | `date.checked_add_signed/sub_signed/add_months/sub_months/add_days/sub_days` | — | — | ❌ Infra interna |

### TimeDelta — duración con signo

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 21 | `TimeDelta::try_days(N)?.num_hours()` | `bi18n.datetime.chrono_timedelta_total` | 2 | 📋 Fase 2 |
| 22 | `TimeDelta::try_weeks/try_hours/try_minutes/try_seconds` | — | — | ❌ Infra interna |
| 23 | `td.num_days()` / `num_hours()` / `num_minutes()` / `num_seconds()` | — | — | ❌ Infra interna |
| 24 | `TimeDelta::zero()` / `max_value()` / `min_value()` | — | — | ❌ Infra interna |

### Trait Datelike / Timelike

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 25 | `Datelike::year/month/day/weekday/ordinal/quarter` | — | — | ❌ Infra interna |
| 26 | `Datelike::num_days_in_month()` | — | — | 🔮 Futuro |
| 27 | `Timelike::hour/minute/second/nanosecond` | — | — | ❌ Infra interna |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Infra interna — no se expone por RPC

---

## Notas de implementación

- chrono complementa a jiff: chrono cubre strftime/RFC3339/RFC2822 y formateo **localizado** (nombres de días/meses en el locale del request). jiff cubre IANA timezones y DST-aware arithmetic.
- `bi18n.datetime.chrono_format_localized` usa `format_localized(fmt, Locale::es_ES)` — requiere feature `unstable-locales` en Cargo.toml. Locale aquí es el enum de chrono (no BCP-47).
- `bi18n.datetime.chrono_timedelta_total` recibe `days?`, `hours?`, `minutes?` y `unit:"hours|minutes|seconds"` → retorna el total como i64.
- `from_timestamp` está **deprecado** en chrono — usar `DateTime::from_timestamp(secs, 0)` solo si está disponible, preferir conversión via NaiveDateTime.
- Los métodos 🔮 Futuro de NaiveDate (`iter_days`, `succ_opt`) son candidatos para una Fase 3 de iteración de calendarios.

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: REGISTRO-ESTADO-DOS.md Bloque L · src/server/handlers/lib_chrono.rs*
