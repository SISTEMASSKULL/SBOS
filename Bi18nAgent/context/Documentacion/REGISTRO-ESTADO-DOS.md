# REGISTRO DE ESTADO — FASE 2
## Exposición completa de las 23 librerías de bi18n como métodos RPC

**Versión:** 3.0.0
**Estado:** VERIFICADO — datos extraídos directamente de código fuente en `~/.cargo/registry/src/` (sin inferencia ni agentes externos)
**Última actualización:** 2026-07-17
**Base:** Cargo.toml verificado — 23 librerías en 9 categorías

---

## Resumen ejecutivo

| Bloque | Librerías | Métodos RPC nuevos | Categoría |
|:---:|---|:---:|---|
| A | fluent-bundle 0.15 | 6 | Traducción directa |
| B | rust-i18n 4 | 4 | Runtime locale |
| C | shakehand 0.1 · veil 0.3 · serde_with 3 | 0 | Infraestructura compile-time |
| D | icu_datetime 2 | 6 | Formato de fechas ICU |
| E | icu_locale_core 2 | 4 | Locales BCP-47 |
| F | icu_decimal 2 | 4 | Números con dígitos locales |
| G | validator 0.19 | 12 | Validación de tipos |
| H | scrutiny 0.1 | 4 | Validación estructural + JSON |
| I | mask-pii 0.2 | 4 | Enmascaramiento PII (+ FIX TODO) |
| J | universal_mask 0.1 | 5 | Máscaras estructurales |
| K | jiff 0.2 | 18 | Fecha/hora moderna (IANA) |
| L | chrono 0.4 | 15 | Fecha/hora strftime + locales |
| M | regex 1 | 6 | Expresiones regulares |
| N | phonenumber 0.3 | 8 | Teléfonos internacionales |
| Ω | prism3-core 0.2 · validy 1.2 · valida 1.1 · clipass_rs 0.1 | 12 | Guardas + CLI + Servidor Web |
| — | arc-swap 1 · notify 6 | 0 | Infraestructura interna (ya implementada) |

**Total Fase 1 (existentes):** 18 métodos RPC
**Total Fase 2 (nuevos):** 108 métodos RPC (los 2 de `CompactDecimalFormatter` fueron reemplazados por `number_grouping_always` y `number_grouping_min2`, que sí usan `GroupingStrategy` de `icu_decimal`)
**Total acumulado:** 126 métodos RPC

**Servidor Web de Traducciones (puerto 9456):** 5 endpoints HTTP
**CLI bi18nctl:** 108 subcomandos nuevos correspondientes a los métodos RPC nuevos

---

## BLOQUE A — fluent-bundle 0.15

### API verificada

```rust
// FluentBundle — contenedor de traducciones para un locale
FluentBundle::new(locales: Vec<LanguageIdentifier>) -> Self
FluentBundle::new_concurrent(locales) -> Self           // thread-safe ArcSwap
bundle.add_resource(res: &FluentResource) -> Result<(), Vec<FluentError>>
bundle.has_message(id: &str) -> bool
bundle.get_message(id: &str) -> Option<FluentMessage>
bundle.add_function(id: &str, func: FluentFunction) -> Result<(), FluentError>
bundle.format_pattern(pattern, args, errors) -> Cow<str>

// FluentMessage — mensaje individual
message.value() -> Option<&Pattern>
message.get_attribute(key: &str) -> Option<FluentAttribute>
message.attributes() -> impl Iterator<Item=FluentAttribute>

// FluentResource — archivo FTL parseado
FluentResource::try_new(source: String) -> Result<Self, (Self, Vec<ParserError>)>

// FluentArgs — argumentos de interpolación
FluentArgs::new() -> Self
args.set(id: impl Into<Cow<str>>, val: FluentValue)
args.get(id: &str) -> Option<&FluentValue>
args.iter() -> impl Iterator

// FluentValue — valor tipado para args
FluentValue::from("texto")
FluentValue::from(42.0f64)           // número
FluentValue::None
```

### Métodos RPC a implementar

| Método RPC | Llamada Rust | Params entrada | Retorno |
|---|---|---|---|
| `bi18n.translate.message` | `bundle.get_message(id).and_then(\|m\| m.value()).map(\|p\| bundle.format_pattern(p, None, &mut errors))` | `ctx_id`, `locale`, `id` | `{ "text": "..." }` |
| `bi18n.translate.message_with_args` | mismo + `FluentArgs` construido de los params | `ctx_id`, `locale`, `id`, `args: {}` | `{ "text": "..." }` |
| `bi18n.translate.batch` | loop sobre lista de ids | `ctx_id`, `locale`, `ids: []` | `{ "texts": {"id": "..."} }` |
| `bi18n.translate.has_message` | `bundle.has_message(id)` | `ctx_id`, `locale`, `id` | `{ "exists": bool }` |
| `bi18n.translate.list_messages` | iterar `bundle` y recolectar ids | `ctx_id`, `locale` | `{ "ids": ["..."] }` |
| `bi18n.translate.message_attribute` | `bundle.get_message(id)?.get_attribute(attr)` | `ctx_id`, `locale`, `id`, `attr` | `{ "text": "..." }` |

---

## BLOQUE B — rust-i18n 4

### API verificada

```rust
// Macros de traducción (compile-time key checking)
t!("key")                                   // locale activo
t!("key", locale = "es-BO")                 // locale explícito
t!("key", name = "Alice", age = 30)         // con interpolación
t!("key", locale = "es-BO", x = val)        // locale + args

// Funciones runtime
rust_i18n::locale() -> String               // locale activo actual
rust_i18n::set_locale(locale: &str)         // cambiar locale global
rust_i18n::available_locales!() -> &[&str]  // locales cargados (macro)

// Backend trait (extensible)
pub trait Backend: Sync + Send {
    fn available_locales(&self) -> Vec<&str>
    fn translate(&self, locale: &str, key: &str) -> Option<Cow<str>>
}
// Ejemplo: backend en PostgreSQL, Redis, API — cualquier fuente externa
```

### Métodos RPC a implementar

| Método RPC | Llamada Rust | Params entrada | Retorno |
|---|---|---|---|
| `bi18n.i18n.locale_activo` | `rust_i18n::locale()` | `ctx_id` | `{ "locale": "es-BO" }` |
| `bi18n.i18n.locales_disponibles` | wrapper de `available_locales!()` | `ctx_id` | `{ "locales": ["es-BO","en-US"] }` |
| `bi18n.i18n.set_locale` | `rust_i18n::set_locale(&locale)` | `ctx_id`, `locale` | `{ "ok": true }` |
| `bi18n.i18n.t` | `t!("key", locale = locale, ...)` | `ctx_id`, `key`, `locale?`, `args?:{}` | `{ "text": "..." }` |

---

## BLOQUE C — shakehand 0.1 · veil 0.3 · serde_with 3 (infraestructura)

### Rol en bi18n

**shakehand 0.1** — i18n compile-time con `enum Languages` y strings `&'static str`. Infraestructura interna del daemon para mensajes fijos en binario. **No expone RPC.**

**veil 0.3** — Redacción de datos sensibles en logs. `#[derive(Redact)]` con flags `Hide`/`Partial`/`Fixed`/`With`/`Skip`/`Toggle`. Se aplica a structs de configuración y contexto (tokens, secrets, passwords) para evitar fugas en tracing. **No expone RPC — es derive macro compile-time.**

**serde_with 3** — Conversores de serialización: `#[serde_as]` para timestamps (Seconds/Milliseconds/Microseconds/Nanoseconds), Base64, Hex, DisplayFromStr, BoolFromInt, DefaultOnError, MapSkipError. Se usa en las structs de request/response de los handlers. **No expone RPC — es infraestructura de serialización.**

**Acciones de implementación:**
- Aplicar `#[derive(Redact)]` a `ServidorConfig` (campos: secret_key, db_url)
- Usar `#[serde_as(as = "TimestampSeconds<i64>")]` en respuestas datetime
- `shakehand` ya compila sin fricción (ADR-010 compliant)

---

## BLOQUE D — icu_datetime 2

### API verificada

```rust
// DateTimeFormatter — requiere DataProvider
use icu_datetime::DateTimeFormatter;
use icu_datetime::fieldsets;
use icu_provider_compiled::Baked;  // compiled_data feature — sin compilación manual

// Fieldsets disponibles:
fieldsets::T       { time }                  // solo hora
fieldsets::D       { date }                  // solo fecha sin año
fieldsets::MD      { date }                  // mes + día
fieldsets::YM      { date }                  // año + mes
fieldsets::YMD     { date }                  // año + mes + día (el más común)
fieldsets::YMDE    { date, weekday }         // fecha + nombre día semana
fieldsets::DT      { date, time }            // fecha + hora
fieldsets::MDE     { date, weekday }         // mes + día + weekday

// Longitudes:
::short()
::medium()
::long()
::full()

// Instanciación:
let fmt = DateTimeFormatter::try_new(
    &locale!("es-BO").into(),
    fieldsets::YMD::medium(),
)?;

// Formato:
let resultado: String = fmt.format(&datetime).to_string();

// Calendarios soportados vía icu_calendar:
// gregorian, buddhist, chinese, coptic, dangi, ethiopian,
// hebrew, indian, islamic, japanese, persian, roc
```

### Métodos RPC a implementar

| Método RPC | Llamada Rust | Params entrada | Retorno |
|---|---|---|---|
| `bi18n.format.datetime_icu` | `DateTimeFormatter::try_new(locale, fieldsets::YMD::medium()).format(dt)` | `ctx_id`, `locale`, `ts_unix`, `granularity?:"medium"` | `{ "formatted": "17 jul. 2026" }` |
| `bi18n.format.date_icu` | fieldsets::YMD con longitud variable | `ctx_id`, `locale`, `ts_unix`, `length:"short\|medium\|long\|full"` | `{ "formatted": "..." }` |
| `bi18n.format.time_icu` | fieldsets::T | `ctx_id`, `locale`, `ts_unix`, `length` | `{ "formatted": "14:35" }` |
| `bi18n.format.weekday_name` | fieldsets::YMDE::long() — extraer parte weekday | `ctx_id`, `locale`, `ts_unix` | `{ "weekday": "jueves" }` |
| `bi18n.format.month_name` | fieldsets::YM::long() — extraer parte mes | `ctx_id`, `locale`, `month:1-12`, `year` | `{ "month": "julio" }` |
| `bi18n.format.datetime_with_time` | fieldsets::DT | `ctx_id`, `locale`, `ts_unix`, `length` | `{ "formatted": "17 jul. 2026, 14:35" }` |

---

## BLOQUE E — icu_locale_core 2

### API verificada

```rust
// Locale — representación BCP-47 completa
use icu_locale_core::Locale;
let loc = Locale::try_from_str("es-Latn-BO-u-ca-gregory").unwrap();
loc.id.language  // LanguageSubtag → "es"
loc.id.script    // Option<ScriptSubtag> → Some("Latn")
loc.id.region    // Option<RegionSubtag> → Some("BO")
loc.id.variants  // SubtagSet
loc.extensions   // Extensions (Unicode, transform, private, other)

// LanguageIdentifier — locale sin extensiones
use icu_locale_core::LanguageIdentifier;
let lid = LanguageIdentifier::try_from_str("es-BO").unwrap();

// canonicalize — normaliza y expande locales
// ⚠️ NO existe Locale::canonicalize() como método estático en icu_locale_core.
// La canonicalización vive en el crate icu_locale (hermano):
use icu_locale::LocaleCanonicalizer;
use icu_locale::TransformResult;
let canonicalizer = LocaleCanonicalizer::try_new_common_unstable(&provider)?;
// O bien la variante extendida (más completa):
let canonicalizer = LocaleCanonicalizer::try_new_extended_unstable(&provider)?;
let mut locale = Locale::try_from_str("zh-TW")?;
let result: TransformResult = canonicalizer.canonicalize(&mut locale); // locale queda "zh-Hant-TW"

// negotiate — LocaleFallbacker para fallback iterativo
use icu_locale::fallback::{LocaleFallbacker, LocaleFallbackerWithConfig};
let fallbacker = LocaleFallbacker::try_new_unstable(&provider)?;
let config = LocaleFallbackConfig::default();
let iter = fallbacker.for_config(config).fallback_for(locale.into());

// subtags
// LanguageSubtag, ScriptSubtag, RegionSubtag, VariantSubtag (todos de icu_locale_core)
```

### Métodos RPC a implementar

| Método RPC | Llamada Rust | Params entrada | Retorno |
|---|---|---|---|
| `bi18n.locale.parse_bcp47` | `Locale::try_from_str(s)` | `ctx_id`, `locale_str` | `{ "valid": bool, "language": "es", "region": "BO", "script": null }` |
| `bi18n.locale.canonicalize` | `LocaleCanonicalizer::try_new_common_unstable(&provider)?.canonicalize(&mut locale)` — crate `icu_locale` | `ctx_id`, `locale_str` | `{ "canonical": "zh-Hant-TW" }` |
| `bi18n.locale.negotiate` | `LocaleFallbacker::try_new_unstable(&provider)?.for_config(cfg).fallback_for(locale)` | `ctx_id`, `preferences: []`, `available: []` | `{ "best": "es-BO" }` |
| `bi18n.locale.subtags` | parsear subtags del locale | `ctx_id`, `locale_str` | `{ "language":"es","script":null,"region":"BO","variants":[] }` |

---

## BLOQUE F — icu_decimal 2

### API verificada

```rust
// DecimalFormatter — números con dígitos locales (arab, thai, deva, etc.)
use icu_decimal::DecimalFormatter;
use icu_decimal::options::{DecimalFormatterOptions, GroupingStrategy};
use fixed_decimal::FixedDecimal;

let fmt = DecimalFormatter::try_new(
    &locale!("ar-EG").into(),
    DecimalFormatterOptions::default(),
)?;
fmt.format(&FixedDecimal::from(12345i64)) // → "١٢٬٣٤٥"

// GroupingStrategy (afecta separadores de miles)
GroupingStrategy::Auto     // reglas del locale
GroupingStrategy::Never    // nunca separar
GroupingStrategy::Always   // siempre separar
GroupingStrategy::Min2     // solo si >= 4 dígitos

// ⚠️ CompactDecimalFormatter NO está disponible: pertenece al crate `icu_compactdecimal`
// que NO figura en el Cargo.toml de bi18n. No implementar métodos RPC que dependan de él.

// FixedDecimal — tipo interno que acepta enteros y decimales
FixedDecimal::from(42i64)
FixedDecimal::from_str("3.14159")
fixed_decimal.multiply_pow10(-2)  // ajustar punto decimal
```

### Métodos RPC a implementar

| Método RPC | Llamada Rust | Params entrada | Retorno |
|---|---|---|---|
| `bi18n.format.number_icu` | `DecimalFormatter::try_new(locale, opts).format(FixedDecimal::from(n))` | `ctx_id`, `locale`, `number`, `grouping?:"auto"` | `{ "formatted": "١٢٬٣٤٥" }` |
| `bi18n.format.number_no_grouping` | `DecimalFormatter` con `GroupingStrategy::Never` | `ctx_id`, `locale`, `number` | `{ "formatted": "12345" }` |
| `bi18n.format.number_grouping_always` | `DecimalFormatter` con `GroupingStrategy::Always` | `ctx_id`, `locale`, `number` | `{ "formatted": "12.345" }` |
| `bi18n.format.number_grouping_min2` | `DecimalFormatter` con `GroupingStrategy::Min2` | `ctx_id`, `locale`, `number` | `{ "formatted": "1234" }` (sin sep si < 4 cifras) |

---

## BLOQUE G — validator 0.19

### API verificada — 11 traits públicos

```rust
// ValidateEmail — HTML5 spec (NO RFC 5322)
pub trait ValidateEmail {
    fn validate_email(&self) -> bool
}
// Impl: String, &str, Cow<str>, Option<T>, Box<T>, Rc<T>, Arc<T>

// ValidateUrl
pub trait ValidateUrl {
    fn validate_url(&self) -> bool
}

// ValidateIp
pub trait ValidateIp {
    fn validate_ipv4(&self) -> bool    // solo IPv4
    fn validate_ipv6(&self) -> bool    // solo IPv6
    fn validate_ip(&self)   -> bool    // IPv4 o IPv6
}

// ValidateLength<T: PartialEq + PartialOrd>
pub trait ValidateLength<T: PartialEq + PartialOrd> {
    fn length(&self) -> Option<T>
    fn validate_length(&self, min: Option<T>, max: Option<T>, equal: Option<T>) -> bool
}
// NOTA: para String, length() = bytes (no chars Unicode)
// Impl: &str, String, Vec<_>, HashMap, BTreeMap, HashSet, VecDeque, arrays, slices

// ValidateRange<T>
pub trait ValidateRange<T> {
    fn validate_range(&self, min: Option<T>, max: Option<T>,
                      exc_min: Option<T>, exc_max: Option<T>) -> bool
}
// Impl: f32, f64, i8..i128, isize, u8..u128, usize, Option<T>

// ValidateContains
pub trait ValidateContains {
    fn validate_contains(&self, needle: &str) -> bool
}

// ValidateDoesNotContain
pub trait ValidateDoesNotContain {
    fn validate_does_not_contain(&self, needle: &str) -> bool
}

// ValidateRegex — NOT dyn compatible
pub trait ValidateRegex {
    fn validate_regex(&self, regex: impl AsRegex) -> bool
}

// ValidateRequired
pub trait ValidateRequired {
    fn validate_required(&self) -> bool   // Option → is_some()
}

// Función standalone
pub fn validate_must_match<T: Eq>(a: T, b: T) -> bool

// ValidationError — struct de error
pub struct ValidationError {
    pub code:    Cow<'static, str>,
    pub message: Option<Cow<'static, str>>,
    pub params:  HashMap<Cow<'static, str>, Value>,  // serde_json::Value
}
ValidationError::new("invalid_email")
    .with_message(Cow::from("Correo electrónico inválido"))
```

### Métodos RPC a implementar

| Método RPC | Llamada Rust | Params entrada | Retorno |
|---|---|---|---|
| `bi18n.validate.email_html5` | `s.validate_email()` | `ctx_id`, `value` | `{ "valid": bool, "error?": "..." }` |
| `bi18n.validate.url` | `s.validate_url()` | `ctx_id`, `value` | `{ "valid": bool }` |
| `bi18n.validate.ip` | `s.validate_ip()` | `ctx_id`, `value` | `{ "valid": bool, "version?": "v4\|v6" }` |
| `bi18n.validate.ipv4` | `s.validate_ipv4()` | `ctx_id`, `value` | `{ "valid": bool }` |
| `bi18n.validate.ipv6` | `s.validate_ipv6()` | `ctx_id`, `value` | `{ "valid": bool }` |
| `bi18n.validate.length` | `s.validate_length(min, max, equal)` | `ctx_id`, `value`, `min?`, `max?`, `equal?` | `{ "valid": bool, "length": N }` |
| `bi18n.validate.range` | `n.validate_range(min, max, exc_min, exc_max)` | `ctx_id`, `value`, `min?`, `max?`, `exclusive_min?`, `exclusive_max?` | `{ "valid": bool }` |
| `bi18n.validate.contains` | `s.validate_contains(needle)` | `ctx_id`, `value`, `needle` | `{ "valid": bool }` |
| `bi18n.validate.does_not_contain` | `s.validate_does_not_contain(needle)` | `ctx_id`, `value`, `needle` | `{ "valid": bool }` |
| `bi18n.validate.regex_match` | `s.validate_regex(&compiled_regex)` | `ctx_id`, `value`, `pattern` | `{ "valid": bool }` |
| `bi18n.validate.required` | `opt.validate_required()` | `ctx_id`, `value` | `{ "valid": bool }` |
| `bi18n.validate.must_match` | `validate_must_match(a, b)` | `ctx_id`, `value_a`, `value_b` | `{ "valid": bool }` |

---

## BLOQUE H — scrutiny 0.1

### API verificada — 70+ atributos de validación

```rust
// Trait principal
pub trait Validate {
    fn validate(&self) -> Result<(), ValidationErrors>;
}

// ValidationErrors — mapa de campo → mensajes
impl ValidationErrors {
    pub fn messages(&self) -> HashMap<String, Vec<String>>       // todos los mensajes
    pub fn first_messages(&self) -> HashMap<String, String>      // primer mensaje por campo
    pub fn merge_with_prefix(&mut self, prefix: &[str], other: Self)
    pub fn field_errors(&self) -> &HashMap<String, Vec<ValidationError>>
    pub fn is_empty(&self) -> bool
}

// Deserialización + validación en un paso
pub fn from_json<T: DeserializeOwned + Validate>(bytes: &[u8]) -> Result<T, ValidationErrors>
pub fn deserialize_json<T: DeserializeOwned>(bytes: &[u8]) -> Result<T, ValidationErrors>

// Atributos derive más relevantes para bi18n:
// required, string, email, url, ip, uuid, ulid, mac_address, hex_color, timezone
// alpha, alpha_num, alpha_dash, uppercase, lowercase
// min=N, max=N, between=(M,N), size=N, digits=N
// starts_with, ends_with, contains, doesnt_contain, regex(r"pat"), not_regex
// date, datetime, before("2027"), after("2020"), date_equals("2026-01-01")
// required_if(field,value), required_unless, required_with, required_without
// same, different, confirmed, gt, gte, lt, lte
// in_list("a","b","c"), not_in("x","y"), distinct
// nested, dive, custom, bail, prohibited, nullable, sometimes
// Axum integration: Valid<T> extractor → HTTP 422 en errores
```

### Métodos RPC a implementar

| Método RPC | Llamada Rust | Params entrada | Retorno |
|---|---|---|---|
| `bi18n.validate.from_json` | `scrutiny::deserialize::from_json::<SomeValidated>(bytes)` | `ctx_id`, `json_str`, `schema_id` | `{ "valid": bool, "errors?": {} }` |
| `bi18n.validate.struct_errors` | `obj.validate().err().map(\|e\| e.messages())` | `ctx_id`, (dispatch por schema) | `{ "errors": {"campo": ["msg"]} }` |
| `bi18n.validate.ulid` | scrutiny ulid rule | `ctx_id`, `value` | `{ "valid": bool }` |
| `bi18n.validate.hex_color` | scrutiny hex_color rule | `ctx_id`, `value` | `{ "valid": bool }` |

---

## BLOQUE I — mask-pii 0.2

### API verificada

```rust
pub struct Masker {
    mask_char: char,           // '*' por defecto
    do_mask_emails: bool,      // false por defecto
    do_mask_phones: bool,      // false por defecto
}

impl Masker {
    pub fn new() -> Self
    pub fn mask_emails(self) -> Self
    pub fn mask_phones(self) -> Self
    pub fn with_mask_char(self, c: char) -> Self
    pub fn process(&self, input: &str) -> String
}

// Comportamiento exacto:
// Emails: primer char del local-part visible, resto → mask_char, @dominio.tld intacto
//   "alice@example.com" → "a****@example.com"
// Teléfonos: últimos 4 dígitos visibles, todo lo anterior → mask_char
//   "090-1234-5678" → "***-****-5678"
// No existen: mask_ips(), mask_ssn(), mask_credit_cards(), mask_urls()
// No acepta regex custom. Límites de redacción son fijos en código fuente.
```

### FIX OBLIGATORIO — src/server/handlers/mask.rs:81

El TODO existente usa `regex::Regex` directamente en lugar del crate `mask-pii`.
**Reemplazar con:**
```rust
use mask_pii::Masker;
let resultado = Masker::new()
    .mask_emails()
    .mask_phones()
    .process(texto_entrada);
```

### Métodos RPC a implementar

| Método RPC | Llamada Rust | Params entrada | Retorno |
|---|---|---|---|
| `bi18n.mask.email_in_text` | `Masker::new().mask_emails().process(input)` | `ctx_id`, `text` | `{ "masked": "a****@example.com" }` |
| `bi18n.mask.phone_in_text` | `Masker::new().mask_phones().process(input)` | `ctx_id`, `text` | `{ "masked": "***-****-5678" }` |
| `bi18n.mask.pii_in_text` | `Masker::new().mask_emails().mask_phones().process(input)` | `ctx_id`, `text` | `{ "masked": "..." }` |
| `bi18n.mask.pii_with_char` | `.with_mask_char(c).process(input)` | `ctx_id`, `text`, `char:"X"` | `{ "masked": "aXXXX@example.com" }` |

---

## BLOQUE J — universal_mask 0.1

### API verificada

```rust
// Única función pública exportada
pub fn mask(text: &str, format_patterns: &str) -> String

// Sistema de patrones:
// 'X' → consume y emite el siguiente carácter del input
// Cualquier otro char → emite ese char literalmente (sin consumir input)
// '|' → separa patrones alternativos; elige el que más X tenga sin exceder input
// Desbordamiento: chars sobrantes del input se descartan (warning a stderr, no panic)

// Ejemplos:
mask("123456789", "XXX-XX-XXXX")         // → "123-45-6789"
mask("4532015112830366", "XXXX-XXXX-XXXX-XXXX")  // → "4532-0151-1283-0366"
mask("1234567890", "(XXX) XXX-XXXX")      // → "(123) 456-7890"
mask("20260717", "XXXX/XX/XX")            // → "2026/07/17"
```

### Métodos RPC a implementar

| Método RPC | Llamada Rust | Params entrada | Retorno |
|---|---|---|---|
| `bi18n.format.structural_mask` | `universal_mask::mask(text, pattern)` | `ctx_id`, `text`, `pattern` | `{ "masked": "..." }` |
| `bi18n.format.mask_ssn` | `mask(text, "XXX-XX-XXXX")` | `ctx_id`, `text` | `{ "masked": "123-45-6789" }` |
| `bi18n.format.mask_card` | `mask(text, "XXXX-XXXX-XXXX-XXXX")` | `ctx_id`, `text` | `{ "masked": "4532-0151-1283-0366" }` |
| `bi18n.format.mask_date_iso` | `mask(text, "XXXX-XX-XX")` | `ctx_id`, `text` | `{ "masked": "2026-07-17" }` |
| `bi18n.format.mask_ci_bo` | `mask(text, "X-XXXX-XXXXX")` | `ctx_id`, `ci` | `{ "masked": "1-2345-67890" }` |

---

## BLOQUE K — jiff 0.2

### API verificada — 68 capacidades identificadas

```rust
// === Timestamp — instante absoluto ===
Timestamp::now()                                   // ahora UTC
Timestamp::from_second(secs: i64)                  // desde Unix epoch
Timestamp::from_millisecond(ms: i64)
Timestamp::strptime(fmt, s) -> Result<Timestamp>   // formato custom (strptime, no parse)
ts.as_second() -> i64                              // a Unix epoch
ts.as_millisecond() -> i64
ts.strftime(fmt: &str) -> String                   // strftime custom

// === Zoned — instante con timezone IANA ===
Zoned::now()                                       // UTC
let tz = TimeZone::get("America/La_Paz")?;
let z = Timestamp::now().to_zoned(tz.clone());     // instante en timezone
z.strftime("%Y-%m-%dT%H:%M:%S%z")                 // format
z.year(), z.month(), z.day(), z.hour(), z.minute(), z.second()
z.weekday()                                        // Weekday enum
z.checked_add(Span::new().hours(2))?               // add duration
z.checked_sub(span)?                               // sub duration
z.until(&z2) -> Result<Span>                       // diff
z.with_time_zone(tz2)                              // convert timezone

// === Date — fecha sin hora ni timezone ===
Date::new(year, month, day)?
Date::today(TimeZone::UTC)?
date.days_in_month() -> u8
date.in_leap_year() -> bool
date.tomorrow() -> Date
date.yesterday() -> Date
date.checked_add(Span::new().days(N))?
date.until(&date2) -> Result<Span>

// === Span — duración ===
Span::new()
    .years(N).months(N).weeks(N).days(N)
    .hours(N).minutes(N).seconds(N)
    .milliseconds(N).microseconds(N).nanoseconds(N)
span.total(Unit::Hours) -> Result<f64>             // convertir a unidad
span.get_days() -> i64
span.get_hours() -> i64

// === Series e iteración ===
date.series(Span::new().days(1))                   // Iterator: cada día
ts.series(Span::new().hours(12))                   // cada 12 horas

// === Redondeo ===
z.round(SpanRound::new().smallest(Unit::Minute))

// === Navegación ===
date.nth_weekday_of_month(N, Weekday::Monday)?     // ej: 2do lunes del mes

// === TimeZone ===
TimeZone::get("America/La_Paz")?
TimeZone::UTC
tz.iana_name()                                     // → Option<&str>
```

### Métodos RPC a implementar

| Método RPC | Llamada Rust | Params entrada | Retorno |
|---|---|---|---|
| `bi18n.datetime.now_utc` | `Timestamp::now().as_second()` | `ctx_id` | `{ "unix": i64, "iso": "..." }` |
| `bi18n.datetime.now_tz` | `Timestamp::now().to_zoned(TimeZone::get(tz)?)` | `ctx_id`, `tz:"America/La_Paz"` | `{ "formatted": "2026-07-17T10:35:00-04:00", "unix": i64 }` |
| `bi18n.datetime.parse_jiff` | `Timestamp::strptime(fmt, s)` | `ctx_id`, `format`, `value` | `{ "unix": i64 }` |
| `bi18n.datetime.format_jiff` | `z.strftime(fmt)` | `ctx_id`, `unix`, `tz`, `format` | `{ "formatted": "..." }` |
| `bi18n.datetime.add_span` | `z.checked_add(Span::new().hours(N))` | `ctx_id`, `unix`, `tz`, `hours?`, `days?`, `months?` | `{ "unix": i64, "formatted": "..." }` |
| `bi18n.datetime.sub_span` | `z.checked_sub(span)` | `ctx_id`, `unix`, `tz`, `hours?`, `days?` | `{ "unix": i64 }` |
| `bi18n.datetime.diff_span` | `z1.until(&z2)` | `ctx_id`, `unix_from`, `unix_to`, `tz` | `{ "days": N, "hours": N, "total_hours": f64 }` |
| `bi18n.datetime.convert_tz` | `z.with_time_zone(TimeZone::get(tz2)?)` | `ctx_id`, `unix`, `from_tz`, `to_tz` | `{ "unix": i64, "formatted": "..." }` |
| `bi18n.datetime.from_unix` | `Timestamp::from_second(secs).to_zoned(tz)` | `ctx_id`, `unix`, `tz` | `{ "formatted": "..." }` |
| `bi18n.datetime.round` | `z.round(SpanRound::new().smallest(Unit::Minute))` | `ctx_id`, `unix`, `tz`, `unit:"minute\|hour\|day"` | `{ "unix": i64 }` |
| `bi18n.datetime.days_in_month` | `Date::new(y,m,1)?.days_in_month()` | `ctx_id`, `year`, `month` | `{ "days": u8 }` |
| `bi18n.datetime.is_leap_year` | `Date::new(y,1,1)?.in_leap_year()` | `ctx_id`, `year` | `{ "leap": bool }` |
| `bi18n.datetime.first_of_month` | `date.checked_add(Span)... day 1` | `ctx_id`, `year`, `month` | `{ "date": "2026-07-01" }` |
| `bi18n.datetime.nth_weekday` | `date.nth_weekday_of_month(n, weekday)` | `ctx_id`, `year`, `month`, `n:1-5`, `weekday:"monday"` | `{ "date": "2026-07-07" }` |
| `bi18n.datetime.series` | `date.series(Span::new().days(1)).take(N)` | `ctx_id`, `from_unix`, `tz`, `step_days`, `count` | `{ "dates": ["..."] }` |
| `bi18n.datetime.span_total` | `span.total(Unit::Hours)` | `ctx_id`, `days?`, `hours?`, `minutes?`, `unit:"hours\|days"` | `{ "total": f64 }` |
| `bi18n.datetime.tz_info` | `TimeZone::get(name)?.iana_name()` | `ctx_id`, `tz` | `{ "iana": "America/La_Paz", "valid": bool }` |
| `bi18n.datetime.weekday_of_date` | `z.weekday()` | `ctx_id`, `unix`, `tz` | `{ "weekday": "Thursday", "number": 4 }` |

---

## BLOQUE L — chrono 0.4

### API verificada — tipos principales

```rust
// DateTime<Tz> — instante con timezone
DateTime::<Utc>::now()                              // feature: now
DateTime::parse_from_rfc3339(s) -> ParseResult     // ISO 8601
DateTime::parse_from_rfc2822(s) -> ParseResult     // email date
DateTime::parse_from_str(s, fmt) -> ParseResult    // strftime custom
dt.format(fmt).to_string()                         // strftime format
dt.format_localized(fmt, Locale::es_ES).to_string()// feature: unstable-locales
dt.to_rfc3339() -> String
dt.to_rfc2822() -> String
dt.timestamp() -> i64                              // Unix seconds
dt.timestamp_millis() -> i64
dt.checked_add_signed(TimeDelta::hours(N))
dt.checked_sub_signed(TimeDelta)
dt.signed_duration_since(dt2) -> TimeDelta
dt.with_timezone(&Utc) -> DateTime<Utc>
dt.to_utc() -> DateTime<Utc>
dt.date_naive() -> NaiveDate
dt.weekday() -> Weekday
dt.quarter() -> u32                                // Datelike trait

// NaiveDate
NaiveDate::from_ymd_opt(y, m, d)
NaiveDate::parse_from_str(s, fmt)
date.succ_opt() -> Option<NaiveDate>
date.leap_year() -> bool
date.num_days_in_month() -> u8
date.iter_days()                                   // Iterator de días
date.iter_weeks()                                  // Iterator de semanas

// TimeDelta — duración
TimeDelta::try_weeks(N) -> Option<TimeDelta>       // versión segura
TimeDelta::try_days(N) -> Option<TimeDelta>
TimeDelta::try_hours(N) -> Option<TimeDelta>
TimeDelta::try_minutes(N) -> Option<TimeDelta>
TimeDelta::try_seconds(N) -> Option<TimeDelta>
td.num_days() -> i64
td.num_hours() -> i64
td.num_minutes() -> i64
td.num_seconds() -> i64
td.checked_add(&td2) -> Option<TimeDelta>
td.abs() -> TimeDelta

// Tokens strftime (40+ disponibles)
// %Y %m %d %H %M %S %F %T %R %z %:z %Z %a %A %b %B %j %U %V %s
// %3f (millis) %6f (micros) %9f (nanos)
// Modificadores: %-d (sin padding), %_d (espacio), %0d (cero)

// Locales (feature: unstable-locales)
// "es_ES".parse::<Locale>()
// dt.format_localized("%A, %d de %B de %Y", Locale::es_ES)
// → "jueves, 17 de julio de 2026"

// serde módulos (feature: serde)
// chrono::serde::ts_seconds           → #[serde(with = "chrono::serde::ts_seconds")]
// chrono::serde::ts_milliseconds
// chrono::serde::ts_microseconds
// chrono::serde::ts_nanoseconds
// + variantes _option para Option<DateTime<Utc>>
```

### Métodos RPC a implementar

| Método RPC | Llamada Rust | Params entrada | Retorno |
|---|---|---|---|
| `bi18n.datetime.chrono_parse_rfc3339` | `DateTime::parse_from_rfc3339(s)` | `ctx_id`, `value` | `{ "unix": i64, "offset": "+00:00" }` |
| `bi18n.datetime.chrono_parse_rfc2822` | `DateTime::parse_from_rfc2822(s)` | `ctx_id`, `value` | `{ "unix": i64 }` |
| `bi18n.datetime.chrono_parse_fmt` | `DateTime::parse_from_str(s, fmt)` | `ctx_id`, `value`, `format` | `{ "unix": i64 }` |
| `bi18n.datetime.chrono_format` | `dt.format(fmt).to_string()` | `ctx_id`, `unix`, `offset_secs?:0`, `format` | `{ "formatted": "..." }` |
| `bi18n.datetime.chrono_format_localized` | `dt.format_localized(fmt, locale.parse::<Locale>())` | `ctx_id`, `unix`, `offset_secs`, `format`, `locale:"es_ES"` | `{ "formatted": "jueves, 17 de julio" }` |
| `bi18n.datetime.chrono_add` | `dt.checked_add_signed(TimeDelta::try_hours(N)?)` | `ctx_id`, `unix`, `hours?`, `days?`, `weeks?`, `minutes?` | `{ "unix": i64 }` |
| `bi18n.datetime.chrono_sub` | `dt.checked_sub_signed(TimeDelta)` | `ctx_id`, `unix`, `hours?`, `days?` | `{ "unix": i64 }` |
| `bi18n.datetime.chrono_diff` | `dt1.signed_duration_since(dt2)` | `ctx_id`, `unix_from`, `unix_to` | `{ "days": i64, "hours": i64, "seconds": i64 }` |
| `bi18n.datetime.chrono_to_rfc3339` | `dt.to_rfc3339()` | `ctx_id`, `unix`, `offset_secs?:0` | `{ "rfc3339": "2026-07-17T14:35:00+00:00" }` |
| `bi18n.datetime.chrono_to_rfc2822` | `dt.to_rfc2822()` | `ctx_id`, `unix`, `offset_secs?:0` | `{ "rfc2822": "Thu, 17 Jul 2026 14:35:00 +0000" }` |
| `bi18n.datetime.chrono_weekday` | `dt.weekday()` | `ctx_id`, `unix` | `{ "weekday": "Thursday", "number": 4 }` |
| `bi18n.datetime.chrono_quarter` | `dt.quarter()` | `ctx_id`, `unix` | `{ "quarter": 3 }` |
| `bi18n.datetime.chrono_leap_year` | `NaiveDate::from_ymd_opt(y,1,1)?.leap_year()` | `ctx_id`, `year` | `{ "leap": bool }` |
| `bi18n.datetime.chrono_naive_parse` | `NaiveDate::parse_from_str(s, fmt)` | `ctx_id`, `value`, `format:"%Y-%m-%d"` | `{ "date": "2026-07-17" }` |
| `bi18n.datetime.chrono_timedelta_total` | `TimeDelta::try_days(d)?.num_hours()` | `ctx_id`, `days?`, `hours?`, `minutes?`, `unit:"hours\|minutes\|seconds"` | `{ "total": i64 }` |

---

## BLOQUE M — regex 1

### API verificada

```rust
// Regex — motor principal (NFA, no backtracking catastrófico)
use regex::Regex;
let re = Regex::new(r"(?P<year>\d{4})-(?P<month>\d{2})")?;
re.is_match(text)                                  // → bool
re.find(text) -> Option<Match>                     // primera coincidencia
re.find_iter(text) -> Matches                      // todas las coincidencias
re.captures(text) -> Option<Captures>              // grupos de captura
re.captures_iter(text) -> CaptureMatches           // todos los captures
re.split(text) -> SplitN                           // split por regex
re.replace(text, replacement)                      // reemplaza primera
re.replace_all(text, replacement)                  // reemplaza todas

// Captures — acceso por nombre
let caps = re.captures(text).unwrap();
caps["year"]                                       // acceso por nombre
caps.name("year") -> Option<Match>
caps.get(0)                                        // grupo 0 = match completo

// RegexSet — múltiples patrones eficientemente
use regex::RegexSet;
let set = RegexSet::new(&[r"\d+", r"[a-z]+"])?;
set.is_match(text)                                 // → bool (alguno hace match)
set.matches(text) -> SetMatches                    // qué patrones hicieron match
set.matches(text).iter()                           // → indices

// RegexBuilder — opciones avanzadas
use regex::RegexBuilder;
RegexBuilder::new(pattern)
    .case_insensitive(true)
    .multi_line(true)
    .dot_matches_new_line(true)
    .size_limit(bytes)
    .dfa_size_limit(bytes)
    .build()?
```

### Métodos RPC a implementar

| Método RPC | Llamada Rust | Params entrada | Retorno |
|---|---|---|---|
| `bi18n.text.regex_match` | `Regex::new(pat)?.is_match(text)` | `ctx_id`, `text`, `pattern`, `case_insensitive?:false` | `{ "matches": bool }` |
| `bi18n.text.regex_extract` | `re.captures(text)` con grupos nombrados | `ctx_id`, `text`, `pattern` | `{ "groups": {"year":"2026","month":"07"}, "full": "..." }` |
| `bi18n.text.regex_extract_all` | `re.find_iter(text).collect()` | `ctx_id`, `text`, `pattern` | `{ "matches": ["...", "..."] }` |
| `bi18n.text.regex_match_set` | `RegexSet::new(patterns)?.matches(text)` | `ctx_id`, `text`, `patterns: []` | `{ "any": bool, "matched_indices": [0, 2] }` |
| `bi18n.text.regex_split` | `re.split(text).collect::<Vec<_>>()` | `ctx_id`, `text`, `pattern` | `{ "parts": ["...", "..."] }` |
| `bi18n.text.regex_replace` | `re.replace_all(text, replacement)` | `ctx_id`, `text`, `pattern`, `replacement`, `all?:true` | `{ "result": "..." }` |

---

## BLOQUE N — phonenumber 0.3

### API verificada

```rust
// Parsing
use phonenumber::{parse, country};
let num = parse(Some(country::BO), "+59171234567")?;  // con región
let num = parse(None, "+59171234567")?;                // sin región (requiere +)

// Validación
phonenumber::is_valid(&num) -> bool
// ⚠️ is_viable NO toma un PhoneNumber — toma el string crudo:
phonenumber::is_viable(raw_phone_str: S) -> bool  // S: AsRef<str>

// Formateo — 4 modos
use phonenumber::Mode;
num.format().mode(Mode::International).to_string()  // "+591 71234567"
num.format().mode(Mode::National).to_string()       // "71234567"
num.format().mode(Mode::E164).to_string()           // "+59171234567"
num.format().mode(Mode::Rfc3966).to_string()        // "tel:+59171234567"

// Tipo de número — enum Type (17 variantes)
// ⚠️ El tipo se llama `Type`, no `PhoneNumberType`. El método requiere la base de datos.
use phonenumber::phone_number::Type;
num.number_type(&database: &Database) -> Type
// Variantes: FixedLine, Mobile, FixedLineOrMobile, TollFree, PremiumRate,
// SharedCost, Voip, PersonalNumber, Pager, UanNumber, Emergency,
// Voicemail, ShortCodeNumber, StandardRateNumber, CarrierSpecific, Sms, Unknown

// is_viable — toma un string, no un PhoneNumber parseado
// ⚠️ `phonenumber::is_viable(&num)` es incorrecto. La firma real:
phonenumber::is_viable<S: AsRef<str>>(string: S) -> bool

// Componentes del PhoneNumber parseado
num.national() -> &NationalNumber   // (no national_number())
num.code() -> &country::Code        // (no country_code())
num.extension() -> Option<&Extension>
```

### Métodos RPC a implementar

Los métodos `bi18n.validate.phone` y `bi18n.validate.national_id` ya existen en Fase 1.

| Método RPC | Llamada Rust | Params entrada | Retorno |
|---|---|---|---|
| `bi18n.phone.format` | `num.format().mode(Mode::International).to_string()` | `ctx_id`, `phone`, `region?:"BO"`, `mode:"international\|national\|e164\|rfc3966"` | `{ "formatted": "+591 71234567" }` |
| `bi18n.phone.type` | `parse(region, phone)?.number_type(&Database::load()?)` — retorna `Type` | `ctx_id`, `phone`, `region?` | `{ "type": "Mobile" }` |
| `bi18n.phone.is_viable` | `phonenumber::is_viable(raw_phone_string)` — toma el string crudo, no el parseado | `ctx_id`, `phone` | `{ "viable": bool }` |
| `bi18n.phone.info` | combinar: `is_valid`, `is_viable`, `number_type`, `format(E164)`, `national()`, `code()` | `ctx_id`, `phone`, `region?` | `{ "valid": bool, "viable": bool, "type": "Mobile", "e164": "+59171234567", "national": "71234567", "country_code": 591 }` |
| `bi18n.phone.parse_e164` | normalizar a E.164 | `ctx_id`, `phone`, `region?` | `{ "e164": "+59171234567" }` |
| `bi18n.phone.parse_national` | formato nacional | `ctx_id`, `phone`, `region?` | `{ "national": "71234567" }` |
| `bi18n.phone.parse_rfc3966` | formato URI RFC 3966 | `ctx_id`, `phone`, `region?` | `{ "uri": "tel:+59171234567" }` |
| `bi18n.phone.country_code` | extraer código de país | `ctx_id`, `phone` | `{ "code": 591, "region": "BO" }` |

---

## BLOQUE Ω — prism3-core · validy · valida · clipass_rs · Servidor Web · CLI

### prism3-core 0.2 — Guardas / Precondiciones

```rust
// Funciones standalone (módulo condition):
check_argument(condition: bool) -> ArgumentResult<()>
check_argument_with_message(condition: bool, message: &str) -> ArgumentResult<()>
check_state(condition: bool) -> ArgumentResult<()>
check_bounds(offset: usize, length: usize, total_length: usize) -> ArgumentResult<()>
check_element_index(index: usize, size: usize) -> ArgumentResult<usize>
check_position_index(index: usize, size: usize) -> ArgumentResult<usize>
check_position_indexes(start: usize, end: usize, size: usize) -> ArgumentResult<()>

// Funciones standalone (módulo numeric):
require_equal<T: PartialEq+Display>(name1, value1, name2, value2) -> ArgumentResult<()>
require_not_equal<T>(name1, value1, name2, value2) -> ArgumentResult<()>

// Trait NumericArgument (impl para i8..i128, u8..u128, f32, f64):
.require_zero("campo")             .require_non_zero("campo")
.require_positive("campo")         // > 0
.require_non_negative("campo")     // >= 0
.require_negative("campo")         // < 0
.require_non_positive("campo")     // <= 0
.require_in_closed_range("campo", min, max)     // [min, max]
.require_in_open_range("campo", min, max)       // (min, max)
.require_in_left_open_range("campo", min, max)  // (min, max]
.require_in_right_open_range("campo", min, max) // [min, max)
.require_less("campo", max)        // < max
.require_less_equal("campo", max)  // <= max
.require_greater("campo", min)     // > min
.require_greater_equal("campo", min)// >= min

// Trait StringArgument (impl para String, str):
.require_non_blank("campo")
.require_length_be("campo", length)
.require_length_at_least("campo", min)
.require_length_at_most("campo", max)
.require_length_in_range("campo", min, max)
.require_match("campo", &regex)
.require_not_match("campo", &regex)

// Trait CollectionArgument (impl para Vec<T>, [T]):
.require_non_empty("campo")
.require_length_be("campo", length)
.require_length_at_least("campo", min_length)
.require_length_at_most("campo", max_length)
.require_length_in_range("campo", min_length, max_length)

// Trait OptionArgument<T> (impl para Option<T>):
.require_non_null("campo") -> ArgumentResult<T>
.require_non_null_and("campo", predicate, error_msg) -> ArgumentResult<T>
.validate_if_present(validator) -> ArgumentResult<Option<T>>
```

### Métodos RPC de prism3-core

| Método RPC | Llamada Rust | Params entrada | Retorno |
|---|---|---|---|
| `bi18n.guard.check_bounds` | `check_bounds(offset, length, total)` | `ctx_id`, `offset`, `length`, `total` | `{ "valid": bool, "error?": "..." }` |
| `bi18n.guard.check_element_index` | `check_element_index(idx, size)` | `ctx_id`, `index`, `size` | `{ "valid": bool, "index?": N }` |
| `bi18n.guard.check_position_index` | `check_position_index(idx, size)` | `ctx_id`, `index`, `size` | `{ "valid": bool }` |
| `bi18n.guard.num_positive` | `value.require_positive("campo")` | `ctx_id`, `name`, `value` | `{ "valid": bool }` |
| `bi18n.guard.num_non_negative` | `value.require_non_negative("campo")` | `ctx_id`, `name`, `value` | `{ "valid": bool }` |
| `bi18n.guard.num_in_range` | `value.require_in_closed_range("campo", min, max)` | `ctx_id`, `name`, `value`, `min`, `max`, `open?:false` | `{ "valid": bool }` |
| `bi18n.guard.num_compare` | `require_equal/require_not_equal` | `ctx_id`, `name1`, `value1`, `name2`, `value2`, `op:"eq\|neq"` | `{ "valid": bool }` |
| `bi18n.guard.str_non_blank` | `s.require_non_blank("campo")` | `ctx_id`, `name`, `value` | `{ "valid": bool }` |
| `bi18n.guard.str_length_range` | `s.require_length_in_range("campo", min, max)` | `ctx_id`, `name`, `value`, `min`, `max` | `{ "valid": bool, "length": N }` |
| `bi18n.guard.str_match` | `s.require_match("campo", &re)` | `ctx_id`, `name`, `value`, `pattern` | `{ "valid": bool }` |
| `bi18n.guard.col_non_empty` | `col.require_non_empty("campo")` | `ctx_id`, `name`, `values: []` | `{ "valid": bool, "count": N }` |
| `bi18n.guard.col_length_range` | `col.require_length_in_range("campo", min, max)` | `ctx_id`, `name`, `values: []`, `min`, `max` | `{ "valid": bool }` |

---

### validy 1.2 y valida 1.1 — Uso interno

**validy 1.2** — Validar y normalizar strings de configuración regional (locale codes, format strings). Uso interno via `#[modificate(trim, lowercase)]` y `#[validate(pattern(pattern = r"^[a-z]{2}-[A-Z]{2}$"))]`. No expone RPC directa — es infraestructura de handlers.

**valida 1.1** — RulesBuilder para validar DTOs de configuración con mensajes en español vía soporte nativo de rust-i18n (feature: i18n). Los errores de validación se retornan en el locale activo del daemon.

---

### clipass_rs 0.1 — CLI: lectura segura de contraseñas

Uso en `bi18nctl` para autenticación de operaciones administrativas.
⚠️ API real verificada: NO hay funciones libres `read_password`, `verify_hash`. La API es a través de `CliPass` struct:

```rust
use clipass_rs::CliPass;

// Construcción y configuración
let mut session = CliPass::new();
session.set_prompt_label("Contraseña admin: ");  // etiqueta del prompt
session.set_no_label("Sin contraseña");           // etiqueta si el campo queda vacío
session.set_no_visibility(true);                  // ocultar input (máscara)
session.set_prompt_mask_token("*");               // carácter de máscara

// Lectura segura del input
let password: String = session.launch_prompt()?;  // io::Result<String>

// Hash — métodos de instancia, no funciones libres
let hash_interno = session.hash_sha256_internal();   // SHA-256 interno
let hash_externo = session.hash_sha256_external();   // SHA-256 externo
let hash_md5_int = session.hash_md5_internal();      // MD5 interno
let hash_md5_ext = session.hash_md5_external();      // MD5 externo
// ⚠️ NO existe verify_hash — la verificación se hace comparando hashes manualmente
```
El daemon valida el hash contra `ServidorConfig.admin_hash`. No genera tokens de sesión.

---

### Servidor Web de Traducciones — Puerto 9456

**Requerimiento:** A.06 §7 — edición runtime de traducciones sin reiniciar el daemon.

**Implementación:** `tokio::net::TcpListener` en `127.0.0.1:9456`, parser HTTP/1.1 manual (sin frameworks externos).

```
GET  /                              → HTML editor UI (inline, ~20KB)
GET  /api/locales                   → ["es-BO", "en-US", "pt-BR"]
GET  /api/messages?locale=es-BO    → {"id": "texto en FTL", ...}
POST /api/update                   → {locale, id, text} → actualiza FTL + ArcSwap reload
POST /api/reload                   → fuerza hot-reload de todos los bundles
```

**Flujo ArcSwap:**
1. POST /api/update → `{locale: "es-BO", id: "validate-email-error", text: "Correo inválido"}`
2. Escribe a `locales/es-BO/main.ftl`
3. `translations.store(Arc::new(nuevo_bundle))` — swap atómico sin bloquear lectores
4. Responde `{"ok": true, "reloaded_at": unix_ts}`

**Seguridad:** Solo escucha en `127.0.0.1`. Kong maneja el acceso autenticado desde el exterior.

---

### CLI bi18nctl — subcomandos nuevos

Todos los 108 métodos RPC nuevos tienen subcomando correspondiente. Patrón:
```
bi18nctl <namespace> <método> [--param valor ...]
```

Ejemplos representativos:
```bash
bi18nctl translate message --locale es-BO --id "validate-email-error"
bi18nctl translate batch --locale es-BO --ids "err1,err2,err3"
bi18nctl translate list-messages --locale es-BO
bi18nctl i18n locale-activo
bi18nctl i18n set-locale --locale en-US
bi18nctl validate email-html5 --value "alice@example.com"
bi18nctl validate url --value "https://example.com"
bi18nctl validate length --value "hola" --min 3 --max 50
bi18nctl validate range --value 75 --min 0 --max 100
bi18nctl mask email-in-text --text "Llama a bob@corp.com"
bi18nctl mask pii-with-char --text "alice@corp.com" --char "X"
bi18nctl format structural-mask --text "71234567" --pattern "(XXXXXXX)"
bi18nctl format number-icu --locale ar-EG --number 12345
bi18nctl format number-compact-short --locale es-BO --number 1500000
bi18nctl format datetime-icu --locale es-BO --ts-unix 1750000000
bi18nctl format weekday-name --locale es-BO --ts-unix 1750000000
bi18nctl locale parse-bcp47 --locale-str "es-Latn-BO"
bi18nctl locale canonicalize --locale-str "zh-TW"    # usa LocaleCanonicalizer de icu_locale
bi18nctl datetime now-tz --tz "America/La_Paz"
bi18nctl datetime diff-span --from 1750000000 --to 1750086400 --tz UTC
bi18nctl datetime series --from-unix 1750000000 --tz UTC --step-days 1 --count 7
bi18nctl datetime chrono-format-localized --unix 1750000000 --format "%A, %d de %B" --locale es_ES
bi18nctl text regex-match --text "hola2026" --pattern "\d+"
bi18nctl text regex-extract --text "2026-07-17" --pattern "(?P<year>\d{4})-(?P<month>\d{2})"
bi18nctl text regex-replace --text "hola mundo" --pattern "mundo" --replacement "Bolivia"
bi18nctl phone format --phone "+59171234567" --mode national
bi18nctl phone info --phone "+59171234567"
bi18nctl guard num-in-range --name "porcentaje" --value 75 --min 0 --max 100
bi18nctl guard str-match --name "ci" --value "1234567" --pattern "^\d{7,8}$"
bi18nctl guard col-non-empty --name "items" --values "a,b,c"
```

---

## FTL — Mensajes nuevos requeridos (es-BO + en-US)

```fluent
# Validación — validator
validate-url-error = URL inválida: { $value }
validate-ip-error = Dirección IP inválida: { $value }
validate-ipv4-error = Dirección IPv4 inválida: { $value }
validate-ipv6-error = Dirección IPv6 inválida: { $value }
validate-length-error = Longitud fuera de rango: se obtuvo { $length }, esperado { $expected }
validate-range-error = Valor fuera de rango: { $value } (rango: { $min }–{ $max })
validate-contains-error = El valor no contiene "{ $needle }"
validate-does-not-contain-error = El valor no debe contener "{ $needle }"
validate-regex-error = El valor no cumple el patrón requerido
validate-required-error = El campo es obligatorio
validate-must-match-error = Los valores no coinciden

# Validación — scrutiny
validate-ulid-error = ULID inválido: { $value }
validate-hex-color-error = Color hexadecimal inválido: { $value }

# Guardas — prism3-core
guard-bounds-error = Índice fuera de límites: offset { $offset } + length { $length } > total { $total }
guard-element-index-error = Índice inválido: { $index } (tamaño: { $size })
guard-positive-error = El campo "{ $name }" debe ser positivo (se obtuvo { $value })
guard-non-negative-error = El campo "{ $name }" debe ser no negativo (se obtuvo { $value })
guard-range-error = El campo "{ $name }" debe estar en [{ $min }, { $max }] (se obtuvo { $value })
guard-blank-error = El campo "{ $name }" no puede estar vacío
guard-match-error = El campo "{ $name }" no cumple el patrón requerido

# Fecha y hora
datetime-parse-error = Fecha inválida: "{ $value }" no coincide con el formato "{ $format }"
datetime-tz-error = Zona horaria desconocida: { $tz }
datetime-overflow-error = Operación de fecha genera desbordamiento

# Enmascaramiento
mask-empty-text-error = El texto no puede estar vacío
mask-invalid-char-error = Carácter de máscara inválido: { $char }

# Traducción
translate-message-not-found = Mensaje no encontrado: { $id } (locale: { $locale })
translate-locale-not-available = Locale no disponible: { $locale }
```

---

## Acciones de implementación por orden de prioridad

### P1 — FIX INMEDIATO (deuda técnica)
1. **FIX mask.rs:81** — reemplazar TODO regex manual por `Masker::new().mask_emails().mask_phones().process(input)`

### P2 — Nuevos handlers Rust
2. `src/server/handlers/translate.rs` — Bloque A (6 métodos fluent-bundle)
3. `src/server/handlers/i18n.rs` — Bloque B (4 métodos rust-i18n)
4. ampliar `src/server/handlers/validate.rs` — Bloque G (12 métodos validator) + Bloque H (4 scrutiny)
5. `src/server/handlers/datetime_jiff.rs` — Bloque K (18 métodos jiff)
6. `src/server/handlers/datetime_chrono.rs` — Bloque L (15 métodos chrono)
7. `src/server/handlers/text.rs` — Bloque M (6 métodos regex)
8. ampliar `src/server/handlers/phone.rs` — Bloque N (8 métodos phonenumber nuevos)
9. ampliar `src/server/handlers/format.rs` — Bloques D/E/F (14 métodos ICU)
10. ampliar `src/server/handlers/mask.rs` + nuevo `src/server/handlers/format_mask.rs` — Bloques I/J
11. `src/server/handlers/guard.rs` — Bloque Ω prism3-core (12 métodos)

### P3 — Dispatcher + CLI
12. `src/server/dispatcher.rs` — añadir 108 arms al match
13. `src/bin/bi18nctl.rs` — añadir 108 subcomandos

### P4 — Servidor Web
14. `src/server/http_traducciones.rs` — TcpListener 9456 + 5 endpoints
15. `src/config/mod.rs` — añadir `http_traducciones_bind: String` + `weblate_url: String`
16. `src/main.rs` — 8va rama en tokio::select!

### P5 — Infraestructura compile-time
17. Aplicar `#[derive(Redact)]` a `ServidorConfig` (veil)
18. Aplicar `#[serde_as]` a response structs datetime (serde_with)

---

## Tabla de tracking — estado de implementación

| Bloque | Librerías | Métodos nuevos | Estado | Commit |
|:---:|---|:---:|:---:|---|
| A | fluent-bundle | 6 | ✅ Completo | `143fb19` |
| B | rust-i18n | 4 | ✅ Completo | `3930f53` |
| C | shakehand · veil · serde_with | 0 (infra) | ✅ Completo | `1ab009d` |
| D | icu_datetime | 6 | ✅ Completo | `25bc89c` |
| E | icu_locale_core | 4 | ✅ Completo | `9d40bbb` |
| F | icu_decimal | 4 (solo GroupingStrategy — sin CompactDecimalFormatter) | ✅ Completo | `8d7488e` |
| G | validator | 12 | ✅ Completo | `a2b988b` |
| H | scrutiny | 6 | ✅ Completo | `701bdd7` |
| I | mask-pii + FIX | 3 + FIX | ✅ Completo | `1cb3445` |
| J | universal_mask | 5 | ✅ Completo | `739e6e1` |
| K | jiff | 17 | ✅ Completo | `1e353f4` |
| L | chrono | 10 | ✅ Completo | `0e0f370` |
| M | regex | 6 | ✅ Completo | `5caad2e` |
| N | phonenumber | 8 | ✅ Completo | `88f6361` |
| Ω | prism3-core · validy · valida · clipass_rs | 12 + infra | ✅ Completo | `af243d3` + `1ab009d` |
| — | arc-swap · notify | 0 (ya impl) | ✅ Fase 1 | `c92e20b` |
| **TOTAL** | **23 librerías** | **103 RPC + 5 HTTP (P4 pendiente)** | ✅ **103 RPC implementados** | |

> **Correcciones respecto al plan original:** H (scrutiny) 4→6 métodos reales · I (mask-pii) 4→3 métodos reales · K (jiff) 18→17 métodos reales · L (chrono) 15→10 métodos reales. Los 5 HTTP corresponden al servidor web P4 (`src/server/http_traducciones.rs`) — pendiente.

---

*v3.0.0 — Datos verificados directamente del código fuente en `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/`.*
*Correcciones aplicadas respecto a v2.0.0 (que usó docs.rs/GitHub):*
*· Bloque E: `Locale::canonicalize` no existe — correcto es `LocaleCanonicalizer::canonicalize` del crate `icu_locale`*
*· Bloque F: `CompactDecimalFormatter` eliminado — crate `icu_compactdecimal` NO está en Cargo.toml*
*· Bloque K: `Timestamp::parse` → `Timestamp::strptime`*
*· Bloque N: `get_number_type()→Option<PhoneNumberType>` → `number_type(&db)→Type`; `is_viable(&num)` → `is_viable(string: S)`*
*· Bloque Ω: `read_password`/`verify_hash` (libres) → `CliPass::new()...launch_prompt()` (struct)*
