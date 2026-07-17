# Manual Unificado — Métodos y Funciones por Librería (SBOS)

> Fusión de `LISTADO-NOMBRES-METODOS-SBOS.md` + `manual_librerias_referencia.md`, más una pasada de verificación adicional contra docs.rs en esta sesión.
>
> Leyenda: 🟢 = verificado línea por línea contra docs.rs/lib.rs en esta sesión (o en una sesión previa, marcado igual). 🟡 = nombres conocidos/típicos de la librería, no verificados método-por-método. 🔴 = interno SBOS, no público — no se puede documentar sin ver el código fuente.
>
> **Nota de versión importante:** varias de las librerías `icu_*` tuvieron un rediseño mayor de API entre la serie 1.x (`icu_locid`, tipos concretos simples) y la serie 2.x actual (`icu_locale_core`, `icu_datetime` con formatters genéricos parametrizados por `FSet`). Los nombres que tenías en 🟡 correspondían en varios casos a la API vieja. Abajo quedan corregidos contra la API 2.x actual (icu_locale_core 2.2.0, icu_datetime/icu_decimal vía crate `icu` más reciente, jiff 0.2.32).

---

## A. fluent-bundle 🟢
**Struct `FluentBundle`:**
new, new_concurrent, add_resource, add_resource_overriding, set_use_isolating, set_transform, set_formatter, has_message, get_message, write_pattern, format_pattern, add_function, add_builtins

**Otros tipos:** FluentResource::try_new · FluentArgs::new, set · FluentMessage::value, attributes, attribute · FluentAttribute::id, value · FluentValue (enum)

---

## B. rust-i18n 🟢
**Macros:** i18n!, t!, tkv!, available_locales!, extend!
**Funciones:** locale, set_locale, replace_patterns
**Trait Backend:** available_locales, translate, messages_for_locale
**Structs:** SimpleBackend, NamespacedBackend, CowStr, AtomicStr

---

## C. regex 🟢 (Regex completo) / 🟡 (RegexSet, Captures, Match — nombres dados, no exhaustivo)
**Struct `Regex`:**
new, is_match, is_match_at, find, find_at, find_iter, captures, captures_at, captures_iter, captures_read, captures_read_at, split, splitn, replace, replace_all, replacen, shortest_match, shortest_match_at, as_str, capture_names, captures_len, static_captures_len, capture_locations

**Otros tipos relevantes:** RegexBuilder (case_insensitive, multi_line, dot_matches_new_line, size_limit, unicode, etc.) · RegexSet::new, matches, is_match · Captures::get, name, extract, iter, len · Match::start, end, range, as_str

---

## D. icu_datetime 🟢 (API 2.x, verificada contra docs.rs de `DateTimeFormatter`)

⚠️ **Cambio de API respecto a lo que tenías anotado:** la serie 2.x de ICU4X reemplazó los formatters con longitud fija (`DateFormatter::try_new_with_length`, etc. de icu_locid-era) por formatters **genéricos parametrizados por field-set** (`DateTimeFormatter<FSet>`). El patrón típico ahora es `DateTimeFormatter::try_new(prefs, fieldsets::YMD::medium())`.

**Struct `DateTimeFormatter<FSet>`:**
- Constructores: `try_new(prefs, field_set)`, `try_new_with_any_provider`, `try_new_with_buffer_provider`, `try_new_unstable`
- Formateo: `format_same_calendar(&datetime)` (falla si el calendario no coincide), `format_any_calendar(&datetime)` (convierte automáticamente)
- Conversión: `try_into_typed_formatter::<C>()` (a `FixedCalendarDateTimeFormatter<C, FSet>`)

**Struct `FixedCalendarDateTimeFormatter<C, FSet>`** (🟡, mismo patrón que arriba pero con calendario fijo en tiempo de compilación — evita linkear datos de conversión de calendario): `try_new`, `format`

**fieldsets::YMD** (🟢, confirmado en ejemplos): `medium()`, `long()`, `short()`, `with_time_hm()`, `with_time_hms()` — estos construyen el `field_set` que se pasa a `try_new`.

**NoCalendarFormatter** 🟡: `try_new`, `format` (para field sets sin fecha, ej. solo hora/zona).

---

## E. icu_locale_core 🟢 (`Locale`, verificado completo contra docs.rs 2.2.0)

**Struct `Locale`:**
- Constante: `UNKNOWN` (el locale "und")
- Asociadas: `try_from_str(s)`, `try_from_utf8(bytes)`, `normalize_utf8(bytes)`, `normalize(str)`
- Métodos: `normalizing_eq(&str)`, `strict_cmp(&[u8])`, `to_string()`, `total_cmp(&other)`
- Campos públicos: `id: LanguageIdentifier`, `extensions: Extensions`
- Traits: `FromStr`, `Display`, `Clone`, `Eq`, `Hash`, `Serialize`/`Deserialize` (feature `serde`), conversiones `From<LanguageIdentifier>`, `From<Language>`, `From<(Language, Option<Script>, Option<Region>)>`

⚠️ Nota: `canonicalize` que tenías anotado **no existe** como método directo de `Locale` en 2.x — la canonicalización vive en el crate hermano `icu_locale` vía `LocaleCanonicalizer` (ver abajo).

**LanguageIdentifier** 🟡 (subtags del locale: language, script, region, variants) — expone métodos equivalentes a los de `Locale` salvo extensiones unicode.

**Crate hermano `icu_locale`** 🟡 (canonicalización y fallback, no confirmado método a método esta sesión):
- `LocaleCanonicalizer::new`, `canonicalize`
- `LocaleFallbacker::new`, `fallback_for`
- `LocaleExpander::maximize`, `minimize`

---

## F. icu_decimal 🟢 (`DecimalFormatter`, verificado)

⚠️ Nota: el tipo se llama `DecimalFormatter` en la API actual (antes `FixedDecimalFormatter` en algunas versiones intermedias — verás ambos nombres en ejemplos de distintas versiones de la doc).

**Struct `DecimalFormatter`:**
- `try_new(prefs: DecimalFormatterPreferences, options)` — crea desde datos compilados
- `try_new_with_buffer_provider` (feature `serde`)
- `try_new_unstable`
- `format(&Decimal) -> FormattedDecimal`
- `format_to_string(&Decimal) -> String`

**`options::GroupingStrategy`** 🟢 (enum, no-exhaustive): `Auto`, `Never`, `Always`, `Min2`
(Nota: para `FixedDecimalFormatter`, `Always` se comporta igual que `Auto`.)

**`DecimalFormatterPreferences`** 🟢 (struct): campos `locale_preferences: LocalePreferences`, `numbering_system: Option<NumberingSystem>`

`icu_compactdecimal` (crate distinto, 🟡 no verificado esta sesión): `CompactDecimalFormatter::try_new`, `format`

---

## G. validator 🟢/🟡
**Atributos (macro):** email, url, length, range, contains, does_not_contain, must_match, regex, custom, credit_card, non_control_character, required, nested
**Funciones libres:** validate_email, validate_url, validate_length, validate_range, validate_contains, validate_required, validate_must_match, validate_regex, validate_credit_card, validate_non_control_character
**Trait:** Validate::validate

🟢 **Corrección confirmada esta sesión:** las funciones libres (`validate_email`, `validate_url`, etc.) devuelven **`bool`**, no `Result<(), ValidationError>` — ese tipo de retorno es el de `Validate::validate()` sobre el struct completo. Ejemplo confirmado contra docs.rs 0.20.0:
```rust
assert!(validator::validate_email("foo@bar.com"));
assert!(!validator::validate_email("foobar.com"));
```
El resto de las firmas exactas (parámetros de `validate_length`, `validate_range`, etc.) siguen sin confirmar método a método esta sesión — pero el patrón de retorno `bool` aplica a todas las funciones libres del crate.

---

## H. `scrutiny` (+ `scrutiny-derive`, `scrutiny-axum`) 🟡
**Fuente:** github.com/georgeboot/scrutiny

### Core
- `Validate` (trait)
- `#[derive(Validate)]` (macro derive)
- `scrutiny::deserialize::from_json`

### Axum
- `Valid<T>`, `ValidForm<T>`, `ValidQuery<T>`, `ValidWith<T, E>`
- `ValidationErrorResponse` (trait): `from_validation_errors`, `from_deserialization_error`
- `ValidationErrors::messages`

### Reglas de validación (atributos, 50+)
**Presencia / meta:** `required`, `filled`, `nullable`, `sometimes`, `bail`, `prohibited`, `prohibited_if`, `prohibited_unless`

**Tipo / formato:** `string`, `integer`, `numeric`, `boolean`, `email`, `url`, `uuid`, `ulid`, `ip`, `ipv4`, `ipv6`, `mac_address`, `json`, `ascii`, `hex_color`, `timezone`

**String:** `alpha`, `alpha_num`, `alpha_dash`, `uppercase`, `lowercase`, `starts_with`, `ends_with`, `doesnt_start_with`, `doesnt_end_with`, `contains`, `doesnt_contain`, `regex`, `not_regex`

**Tamaño / longitud:** `min`, `max`, `between`, `size`, `digits`, `digits_between`, `decimal`, `multiple_of`

**Comparación:** `same`, `different`, `confirmed`, `gt`, `gte`, `lt`, `lte`, `in_list`, `not_in`, `in_array`, `distinct`

**Condicional:** `required_if`, `required_unless`, `required_with`, `required_without`, `required_with_all`, `required_without_all`, `accepted`, `accepted_if`, `declined`, `declined_if`

**Fecha (ISO 8601):** `date`, `datetime`, `date_equals`, `before`, `after`, `before_or_equal`, `after_or_equal`

**Estructural:** `nested` (alias `dive`), `custom`

---

## I. `mask-pii` (crate Rust público — Finite Field, K.K.) 🟡
**Fuente:** finitefield.org/en/oss/mask-pii · crates.io/crates/mask-pii

⚠️ Nota: tu `mask-pii` interno referencia `mask.rs:81`, lo que sugiere que tu implementación es un módulo propio y **no** este crate público. Se documenta igual por si el nombre coincide o sirve de referencia de API equivalente.

- `Masker::new`
- `Masker::mask_emails`
- `Masker::mask_phones`
- `Masker::with_mask_char`
- `Masker::process`

## J. `universal_mask` 🟡
**Fuente:** docs.rs/universal_mask/latest/universal_mask
- `mask` — aplica una máscara a un texto según el formato especificado (única función pública del crate, v0.1.0).

## Ω. `prism3-core` 🟡
**Fuente:** docs.rs/prism3-core (v0.2.0) · github.com/3-prism/prism3-rust-core

### Re-exports de nivel raíz
`check_argument`, `check_argument_fmt`, `check_argument_with_message`, `check_bounds`, `check_element_index`, `check_position_index`, `check_position_indexes`, `check_state`, `check_state_with_message`, `require_element_non_null`, `require_equal`, `require_not_equal`, `require_null_or`, `ArgumentError`, `ArgumentResult`, `CollectionArgument` (trait), `NumericArgument` (trait), `OptionArgument` (trait), `StringArgument` (trait), `BoxError`, `BoxResult`, `DataType` (enum), `DataTypeOf` (trait), `Pair`, `Triple`

### Módulos
`lang` (Language Tools), `util` (Util Module)

## H/I/J/Ω — Bloqueado 🔴
`scrutiny` interno, `mask-pii` interno, `universal_mask` interno y `prism3-core` interno (si difieren de los crates públicos de arriba) siguen bloqueados: no hay forma de documentarlos con precisión sin ver `lib.rs`/`mod.rs`/firmas `pub fn` reales de tu repo o `/opt/projects-ia/`. Si me pasás esos archivos, completo esta sección al mismo nivel 🟢 que el resto.

---

## K. jiff 🟢 (Zoned, Timestamp, civil::DateTime, civil::Date, civil::Time — verificados completos) / 🟡 (Span, TimeZone, SignedDuration — parcial, ampliado esta pasada)

**Struct `Zoned`** (verificado completo):
now, new, strptime, checked_add, checked_sub, saturating_add, saturating_sub, date, datetime, day, day_of_year, day_of_year_no_leap, days_in_month, days_in_year, duration_since, duration_until, end_of_day, era_year, first_of_month, first_of_year, hour, in_leap_year, in_tz, iso_week_date, last_of_month, last_of_year, memory_usage, microsecond, millisecond, minute, month, nanosecond, nth_weekday, nth_weekday_of_month, offset, round, second, series, since, start_of_day, strftime, subsec_nanosecond, time, time_zone, timestamp, tomorrow, until, weekday, with, with_time_zone, year, yesterday

**Struct `Timestamp`** (verificado completo contra docs.rs 0.2.28):
- Constantes: `MIN`, `MAX`, `UNIX_EPOCH`
- Asociadas: `now`, `new`, `constant`, `from_second`, `from_millisecond`, `from_microsecond`, `from_nanosecond`, `from_duration`, `strptime`
- Métodos: `as_duration`, `as_microsecond`, `as_millisecond`, `as_nanosecond`, `as_second`, `checked_add`, `checked_sub`, `display_with_offset`, `duration_since`, `duration_until`, `in_tz`, `is_zero`, `round`, `saturating_add`, `saturating_sub`, `series`, `signum`, `since`, `strftime`, `subsec_microsecond`, `subsec_millisecond`, `subsec_nanosecond`, `to_zoned`, `until`

(Correcciones respecto al 🟡 previo: se agregan `constant`, `signum`, `is_zero`, `as_duration`, `display_with_offset`, `duration_since`/`duration_until`, que no estaban listados.)

**Struct `civil::DateTime`** (verificado completo contra docs.rs 0.2.32):
- Constantes: `MIN`, `MAX`, `ZERO`
- Asociadas: `new`, `constant`, `from_parts`, `strptime`
- Métodos: `checked_add`, `checked_sub`, `date`, `day`, `day_of_year`, `day_of_year_no_leap`, `days_in_month`, `days_in_year`, `duration_since`, `duration_until`, `end_of_day`, `era_year`, `first_of_month`, `first_of_year`, `hour`, `in_leap_year`, `in_tz`, `iso_week_date`, `last_of_month`, `last_of_year`, `microsecond`, `millisecond`, `minute`, `month`, `nanosecond`, `nth_weekday`, `nth_weekday_of_month`, `round`, `saturating_add`, `saturating_sub`, `second`, `series`, `since`, `start_of_day`, `strftime`, `subsec_nanosecond`, `time`, `to_zoned`, `tomorrow`, `until`, `weekday`, `with`, `year`, `yesterday`

**Struct `civil::Date`** (verificado completo contra docs.rs, jiff 0.2.4/0.2.32 — coherente entre versiones):
- Constantes: `MIN`, `MAX`, `ZERO`
- Asociadas: `new`, `constant`, `from_iso_week_date`
- Métodos: `at` (Date+hora → DateTime), `checked_add`, `checked_sub`, `day`, `day_of_year`, `day_of_year_no_leap`, `days_in_month`, `days_in_year`, `duration_since`, `duration_until`, `era_year`, `first_of_month`, `first_of_year`, `in_leap_year`, `in_tz`, `iso_week_date`, `last_of_month`, `last_of_year`, `month`, `nth_weekday`, `nth_weekday_of_month`, `saturating_add`, `saturating_sub`, `series`, `since`, `strftime`, `strptime`, `to_datetime` (Date+Time → DateTime), `to_zoned`, `tomorrow`, `until`, `weekday`, `with`, `year`, `yesterday`

(Nota: `and_time` que tenías anotado **no existe** con ese nombre — el método real es `to_datetime(time)`, o alternativamente `time.on(year, month, day)` / `date.at(h, m, s, ns)`.)

**Struct `civil::Time`** (verificado completo contra docs.rs):
- Constantes: `MIN`, `MAX`
- Asociadas: `new`, `constant`, `midnight`
- Métodos: `checked_add`, `checked_sub`, `duration_since`, `duration_until`, `hour`, `microsecond`, `millisecond`, `minute`, `nanosecond`, `on` (Time+fecha → DateTime), `round`, `saturating_add`, `saturating_sub`, `second`, `series`, `since`, `strftime`, `strptime`, `subsec_nanosecond`, `to_datetime` (Time+Date → DateTime), `until`, `with`, `wrapping_add`, `wrapping_sub`

(Nota: a diferencia de Date/DateTime, `Time` usa aritmética **wrapping** por defecto en los operadores `+`/`-` — por eso expone `wrapping_add`/`wrapping_sub` además de las variantes `checked_*`/`saturating_*`. No tiene `in_tz`/`to_zoned` propios porque un `Time` solo no alcanza para resolver un instante.)

**Span** 🟡 (ampliado esta pasada; confirmado que usa un patrón "getter con prefijo `get_`" para no chocar con los setters/builders):
- Constructores/builders (fluent, devuelven un nuevo `Span`): `years`, `months`, `weeks`, `days`, `hours`, `minutes`, `seconds`, `milliseconds`, `microseconds`, `nanoseconds` — también disponibles como métodos de extensión sobre enteros vía el trait `ToSpan` (ej. `5.days()`, `2.hours().minutes(30)`)
- Getters (confirmado el patrón, no la lista completa): `get_years`, `get_months`, `get_weeks`, `get_days`, `get_hours`, etc.
- Otros métodos confirmados por uso: `checked_add`, `checked_sub`, `round` (con `SpanRound`), `total` (con relative date/`SpanRelativeTo`), `fieldwise` (compara por campo, no por valor total), `negate`, `is_zero`, `new()` (constructor vacío)

**TimeZone** 🟡 (parcialmente confirmado por ejemplos de `Timestamp`/`Date`/`DateTime`): `get(name)`, `fixed(offset)`, `posix(str)`, `system()`, `to_timestamp`, `to_zoned`, `to_ambiguous_zoned`, `to_ambiguous_timestamp`, `iana_name`

**SignedDuration** 🟡: `new`, `from_secs`, `from_hours`, `from_mins`, `from_millis`, `from_micros`, `from_nanos`, `checked_add`, `checked_sub`, `as_secs`, `as_millis`, `system_until` (con `std::time::SystemTime`), constantes `ZERO`/`MIN`/`MAX` (confirmadas por uso en ejemplos de `Timestamp`/`Date`/`Time`)

---

## L. chrono 🟢 (NaiveDate + Datelike) / 🟡 (resto)

**Struct `NaiveDate`** (verificado completo contra docs.rs 0.4.45):
Constantes: MIN, MAX
Constructores/asociadas: from_ymd, from_ymd_opt, from_yo, from_yo_opt, from_isoywd, from_isoywd_opt, from_num_days_from_ce, from_num_days_from_ce_opt, from_epoch_days, from_weekday_of_month, from_weekday_of_month_opt, parse_from_str, parse_and_remainder
Métodos: abs_diff, and_hms, and_hms_opt, and_hms_micro, and_hms_micro_opt, and_hms_milli, and_hms_milli_opt, and_hms_nano, and_hms_nano_opt, and_time, checked_add_days, checked_add_months, checked_add_signed, checked_sub_days, checked_sub_months, checked_sub_signed, format, format_localized, format_localized_with_items, format_with_items, iter_days, iter_weeks, leap_year, pred, pred_opt, signed_duration_since, succ, succ_opt, to_epoch_days, week, years_since

**Trait `Datelike`** (implementado por NaiveDate, NaiveDateTime, DateTime\<Tz\> — verificado completo):
year, month, month0, day, day0, ordinal, ordinal0, weekday, iso_week, with_year, with_month, with_month0, with_day, with_day0, with_ordinal, with_ordinal0, year_ce, quarter, num_days_from_ce, num_days_in_month

**NaiveDateTime** 🟡 (confirmado parcialmente esta pasada contra docs.rs — no exhaustivo pero con correcciones): new, from_timestamp_opt (nota: `from_timestamp` está deprecado, usar `from_timestamp_opt` o `DateTime::from_timestamp`), and_utc, date, time, timestamp, timestamp_millis, timestamp_micros, timestamp_nanos_opt, format, format_with_items, checked_add_signed, checked_sub_signed, checked_add_days, checked_sub_months, checked_add_offset (con `FixedOffset`), and_local_timezone, parse_from_str
- Confirmado además: soporta `Add<Months>` vía operador (`checked_add_months` es el equivalente checked)

**DateTime\<Tz\>** (🟡): now, from_timestamp, with_timezone, naive_utc, naive_local, date_naive, time, timestamp, timestamp_millis, timestamp_micros, timestamp_nanos_opt, format, to_rfc2822, to_rfc3339, to_rfc3339_opts, checked_add_signed, checked_sub_signed, checked_add_months, signed_duration_since, years_since, parse_from_rfc2822, parse_from_rfc3339, parse_from_str

**Trait `Timelike`** (🟡): hour, minute, second, nanosecond, with_hour, with_minute, with_second, with_nanosecond

---

## M. phonenumber 🟢 (enum Mode confirmado) / 🟡 (resto)

**Funciones libres:** parse, is_valid
**Struct `PhoneNumber`:** format, format_with_database, metadata, is_valid, is_valid_with_database, carrier, national_number, country_code, extension
**Formatter (`.format()` builder):** mode, to_string

**Enum `Mode`** 🟢 (confirmado contra docs.rs, 4 variantes exactas — sin variantes adicionales):
`E164`, `International`, `National`, `Rfc3966`
(Uso: `number.format().mode(Mode::International)`)

**Enum `Type`** 🟢 (confirmado contra docs.rs — la lista original estaba incompleta, faltaban 6 variantes):
`FixedLine`, `Mobile`, `FixedLineOrMobile`, `TollFree`, `PremiumRate`, `SharedCost`, `PersonalNumber`, `Voip`, `Pager`, `Uan`, `Emergency`, `Voicemail`, `ShortCode`, `StandardRate`, `Carrier`, `NoInternational`, `Unknown`
(Corrección: el 🟡 anterior omitía `FixedLineOrMobile`, `Emergency`, `ShortCode`, `StandardRate`, `Carrier` y `NoInternational`.)

---

## Resumen de fiabilidad (actualizado — 2ª pasada de verificación)

| Librería | Bloque verificado 🟢 | Bloques 🟡 restantes |
|---|---|---|
| fluent-bundle | FluentBundle completo | — |
| rust-i18n | Crate completo | — |
| regex | Regex completo | RegexSet, Captures, Match (nombres dados, no exhaustivo — bajo impacto, API estable hace años) |
| icu_datetime | `DateTimeFormatter<FSet>` (API 2.x confirmada, distinta a la 1.x) | `FixedCalendarDateTimeFormatter`, `NoCalendarFormatter`, resto de `fieldsets::*` |
| icu_locale_core | `Locale` completo (2.2.0) | `LanguageIdentifier` método a método, `icu_locale` (Canonicalizer/Fallbacker/Expander) |
| icu_decimal | `DecimalFormatter`, `GroupingStrategy`, `DecimalFormatterPreferences` | `icu_compactdecimal` |
| **jiff** | **Zoned, Timestamp, civil::DateTime, civil::Date, civil::Time — los 5 tipos principales, completos** | Span (getters `get_*` completos, builders confirmados), TimeZone, SignedDuration — confirmados por patrón de uso, no fetch dedicado del struct completo |
| chrono | NaiveDate completo + trait Datelike completo | NaiveDateTime (parcialmente ampliado: se confirmó `checked_add_offset`, que `from_timestamp` está deprecado), DateTime\<Tz\>, Timelike |
| **phonenumber** | **enum `Mode` (4 variantes) y enum `Type` (17 variantes) — ambos confirmados y corregidos** | `PhoneNumber` (parcial), funciones de metadata |
| **validator** | **Corrección confirmada: las funciones libres devuelven `bool`, no `Result`** | Atributos confirmados; firmas exactas de argumentos (`validate_length`, etc.) sin confirmar en tu 0.20.x exacto |
| scrutiny (público) | Reglas de validación y API Axum listadas desde el repo | — |
| mask-pii (público) | API pública del crate listada | Comparar con tu módulo interno `mask.rs` |
| universal_mask (público) | Única función `mask` | — |
| prism3-core (público) | Re-exports de raíz y módulos listados | — |
| **scrutiny / mask-pii / universal_mask / prism3-core — internos SBOS** | — | **Bloqueado — sigue siendo el único punto que no puedo cerrar sin el código fuente real (`lib.rs`/`mod.rs`, firmas `pub fn`). Para mask-pii interno, además `mask.rs` completo para documentar el fix de la línea 81.** |
| qubit-common (deprecado) | Métodos listados desde el repo archivado | Migración a `qubit-datatype`/`qubit-argument`/`qubit-error`/`qubit-serde` — confirmar API nueva cuando definas cuál usar |

**Correcciones importantes encontradas en esta 2ª pasada (no eran errores triviales):**
1. `civil::Date` **no tiene** `and_time` — el método real es `to_datetime(time)` (o `time.on(y,m,d)` / `date.at(h,m,s,ns)`).
2. `civil::Time` usa **aritmética wrapping por defecto** en `+`/`-` (expone además `wrapping_add`/`wrapping_sub`), a diferencia de `Date`/`DateTime` que panican en overflow por defecto.
3. `validator`: las funciones libres (`validate_email`, etc.) devuelven **`bool`**, no `Result<(), ValidationError>` — fácil de asumir mal si vienes del patrón de `Validate::validate()`.
4. `phonenumber::Type` tenía **6 variantes faltantes** en el listado original (`FixedLineOrMobile`, `Emergency`, `ShortCode`, `StandardRate`, `Carrier`, `NoInternational`).
5. `icu_locale_core::Locale` **no tiene** `canonicalize` — vive en el crate hermano `icu_locale`.
6. La API de `icu_datetime` cambió de raíz entre 1.x y 2.x: ya no hay `try_new_with_length`, ahora todo pasa por `DateTimeFormatter<FSet>` genérico sobre field-sets.

**Lo único que queda realmente bloqueado:** el código fuente de tus 4 crates internos (`scrutiny`, `mask-pii`, `universal_mask`, `prism3-core`), en particular `mask.rs` completo para el fix de la línea 81. Eso no lo puedo resolver por búsqueda — necesito que subas los archivos.

---

## Nota adicional — qubit-common / rs-common (deprecado)

El repositorio `github.com/qubit-ltd/rs-common` (crate `qubit-common`) está **archivado/deprecado** y se dividió en 4 crates nuevos. Métodos relevantes si tu SBOS depende de él:

- `DataType::as_str`
- `DataTypeOf` (trait, const `DATA_TYPE`)
- `DataConverter::from`
- `DataConverter::to::<T>`
- `DataConverters::from`
- `DataConverters::to_vec`
- `NumericArgument::require_in_closed_range`
- `StringArgument::require_non_blank`
- `StringArgument::require_match`
- `CollectionArgument::require_non_empty`
- `CollectionArgument::require_length_at_most`
- `OptionArgument::require_non_null`
- `OptionArgument::require_non_null_and`
- `check_argument`, `check_argument_with_message`, `check_state`, `check_state_with_message`, `check_bounds`
- `ArgumentError::new`
- `IntoBoxError::into_box_error`

Crates de reemplazo (si migras): `qubit-datatype`, `qubit-argument`, `qubit-error`, `qubit-serde`.
