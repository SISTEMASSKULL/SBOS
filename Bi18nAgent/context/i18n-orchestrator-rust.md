# i18n-orchestrator — Orquestador Universal de Internacionalización en Rust

**Estado:** Propuesta de arquitectura (Draft v1.2)
**Fecha:** 2026-07-16
**Ámbito:** Crate Rust de propósito general, independiente, instalable en cualquier proyecto (backend, CLI, WASM, embebido)

> **Cambios v1.2** (investigación de completitud del universo i18n para atributos de identidad): (1) 8 brechas identificadas y cubiertas — visualización de enums, granularidad de fecha, dirección postal, formato de nombre, máscara PII por tipo de documento, placa vehicular, cuenta bancaria, mapeo display_format→patrón ICU4X, (2) TOML de país expandido con secciones `[name]`, `[postal]`, `[vehicle.plate]`, `[bank]`, y campo `mask` en `[national_id.*]`, (3) módulo `enum_display` para traducción de valores enum por locale, (4) módulo `format_map` para mapear códigos de `display_format` a patrones ICU4X + máscaras de entrada.

---

## 1. El problema que resuelve

**No existe una sola librería que resuelva todo i18n.** El ecosistema JS lo resuelve con un "equipo" de herramientas coordinadas por un locale común (i18next + moment.js/date-fns/Intl + input masks + validadores). Rust tiene piezas equivalentes o superiores, pero **dispersas**, cada una con su propio tipo de locale y sin coordinación entre ellas.

**Objetivo:** un crate (`i18n-orchestrator`) que sea la capa de coordinación única — un solo `Locale`, una sola configuración regional, y una API unificada que por debajo delega en las librerías correctas para cada tarea. No reimplementa nada que ya funcione bien; **orquesta**.

---

## 2. Mapa de responsabilidades → estándar → librería Rust

| Responsabilidad | Estándar internacional | Crate Rust recomendado | Rol dentro del orquestador |
|---|---|---|---|
| Identificador de idioma/región (`es-BO`, `en-US`, `ar-EG`) | **BCP 47** (IETF) + Unicode UTS #35 | `icu_locale_core` (parte de ICU4X) | Tipo `Locale` único, fuente de verdad |
| Traducción de textos con plurales y género | Unicode CLDR Plural Rules + **Project Fluent** (camino hacia Unicode MessageFormat 2.0) | `fluent` + `fluent-bundle` | Motor de mensajes (equivalente a i18next) |
| **Instante de tiempo, aritmética de fechas, husos horarios** ("como moment.js") | IANA tzdata + ISO 8601/RFC 3339 | **`jiff`** (tipo de dato interno) | Motor temporal — ver sección 4, dedicada |
| Presentación de fecha/hora según locale | Unicode UTS #35 (Date/Time Patterns) | `icu::datetime` (ICU4X) | Capa de formato *sobre* el instante que produce `jiff` |
| Formato de números (decimales, miles) | Unicode UTS #35 Number Patterns | `icu::decimal` (ICU4X) | Motor de formato numérico |
| Formato y catálogo de monedas | **ISO 4217** | `icu::experimental::currency` + `codes-iso-4217` | Motor de formato monetario |
| Unidades de medida (métrico/imperial) | Unicode CLDR Units, ISO 80000 | `icu::experimental::units` | Conversión y formato de unidades |
| Dirección de texto (LTR/RTL) | Unicode **UAX #9** (Bidi) | `icu` (módulo bidi) o `unicode-bidi` | Layout de texto mixto |
| Orden alfabético correcto por idioma | Unicode **UTS #10** (Collation) | `icu::collator` (ICU4X) | Ordenamiento |
| Calendarios no gregorianos (budista, islámico, hebreo, etíope, etc.) | Unicode CLDR Calendar data | `icu::calendar` (ICU4X) | Soporte de calendario alternativo, necesario para cobertura real global |
| Validación de teléfono internacional | **ITU-T E.164** | `phonenumber` (puerto de Google libphonenumber) | Validador especializado |
| Validación genérica (email, URL, tarjetas) | Buenas prácticas OWASP de validación de entrada | `validator` / `validator-rs` | Validador de propósito general |
| Catálogo de país/subdivisión | **ISO 3166** | `rust_iso3166` o equivalente | Catálogo base para reglas nacionales |
| Máscaras de entrada | Sin estándar único — se **deriva** de patrones CLDR | Módulo propio, a partir de `icu::decimal`/`icu::datetime` | Generador de máscaras (pieza diferenciadora) |

**Nota de verificación:** los nombres de crate mencionados en la conversación original (`fluent-i18n`, `i18n-runtime`, `shakehand`, `rat-input`, `valida`, `cjtoolkit-structured-validator`) **no se pudieron confirmar como paquetes activos y mantenidos**. Se sustituyeron por los de esta tabla, todos verificados en crates.io/GitHub con mantenedor identificable y respaldo de estándar.

---

## 3. Por qué ICU4X es la pieza central

ICU4X es el sucesor oficial de ICU4C/ICU4J, desarrollado directamente por el **Unicode Consortium**, con soporte `no_std` (sirve para backend, WASM o binario embebido). Es la única pieza que cubre, en un solo crate: locale, presentación de fecha/hora, números, monedas, unidades, bidi, collation y **calendarios alternativos**. El orquestador la usa como columna vertebral y añade por fuera solo lo que no cubre: mensajes con lógica de plantilla (Fluent), instante temporal con aritmética (jiff), validación regional (phonenumber, validator) y máscaras (módulo propio).

---

## 4. El motor temporal: por qué "moment" merece tratamiento propio

En el borrador anterior `chrono`/`jiff` aparecían como nota al margen. Es un error de diseño corregirlo así, porque **el manejo de instantes con zona horaria es, junto con la traducción de textos, el problema más frecuente y más propenso a bugs de todo el universo i18n** — exactamente el escenario que describes: un servidor en Alemania (`Europe/Berlin`) sirviendo a un tenant en Bolivia (`America/La_Paz`).

### 4.1 Investigación: estado del ecosistema Rust (julio 2026)

| Librería | Rol | Situación |
|---|---|---|
| `chrono` | Workhorse histórico, integración masiva con `sqlx`, `serde`, `diesel` | Maduro, pero su soporte de IANA tzdata **no viene incluido**: requiere `chrono-tz` (embebe toda la base de datos en el binario) o `tzfile` (lee del sistema) como dependencias aparte, cada una con sus propios trade-offs |
| `time` | Alternativa liviana | No tiene tipo de fecha/hora *zone-aware* nativo; el soporte de zona horaria vía `time-tz` es limitado |
| **`jiff`** | Librería nueva (autor: BurntSushi, también autor de `ripgrep`/`regex`) | **Soporte de IANA Time Zone Database incluido de fábrica**, sin crate adicional. Detecta y rechaza en el parseo datetimes que quedaron inválidos por cambios de reglas de huso horario (ej. abolición de horario de verano). Aritmética de calendario completa entre fechas *zone-aware* |
| `icu::calendar`/`icu::timezone` | Parte de ICU4X | Cubre calendarios alternativos y metadata de zona horaria, pero **no es un tipo de instante para hacer aritmética de negocio** (sumar días, restar meses) |

### 4.2 Decisión de diseño

El orquestador usa **`jiff`** como el tipo de instante interno — es el reemplazo directo y más fiel al espíritu de `moment.js` que existe hoy en Rust: zone-aware por defecto, sin necesidad de una segunda dependencia para tzdata, y con la seguridad de tipos de Rust en vez de mutabilidad implícita (el problema clásico de `moment.js` que motivó su propio "modo mantenimiento" en el ecosistema JS).

`icu::datetime` **no reemplaza a jiff**: se usa exclusivamente para la capa de *presentación* (cómo se ve la fecha en pantalla según el locale), nunca para el cálculo. Esta separación es la misma que ya rige para números y monedas: un motor calcula, otro presenta.

```rust
use jiff::{Zoned, tz::TimeZone};

// El servidor está en Europe/Berlin, pero el instante se ancla
// a la zona horaria del TENANT, no a la del sistema operativo.
let ahora_tenant: Zoned = Zoned::now().with_time_zone(
    TimeZone::get("America/La_Paz")?
);

// Aritmética segura: "vence en 30 días" calculado en la zona del tenant,
// no en la del servidor.
let vencimiento = ahora_tenant.checked_add(jiff::ToSpan::days(30))?;

// Presentación localizada (delegada a ICU4X, no a jiff)
let texto = orch.format_date(&vencimiento, DateStyle::Long);
// "14 de agosto de 2026" (es-BO) vs "August 14, 2026" (en-US)
```

---

## 5. Arquitectura del crate

```
┌───────────────────────────────────────────────────────────┐
│                     i18n-orchestrator                      │
│                                                             │
│   pub struct Locale(icu_locale_core::Locale)   ← BCP 47    │
│   pub struct RegionalConfig { locale, timezone, currency,  │
│                                first_day_of_week, calendar }│
│                                                             │
│   ┌─────────────────────────────────────────────────┐     │
│   │              API pública unificada                │     │
│   │  format::date/number/money() · translate()        │     │
│   │  time::now_in(tz) · time::add(...)                 │     │
│   │  validate::phone/email/national_id()               │     │
│   │  mask::for_field(kind, locale)                     │     │
│   │  sort::collate(items, locale)                       │     │
│   └───┬──────┬──────┬─────────┬─────────┬─────────┬───┘     │
│       ▼      ▼      ▼         ▼         ▼         ▼         │
│   ┌──────┐┌──────┐┌──────┐┌────────┐┌────────┐┌─────────┐ │
│   │ICU4X ││Fluent││ jiff ││validator││phonenu.││mask/     │ │
│   │      ││      ││      ││        ││mber    ││country-  │ │
│   │      ││      ││      ││        ││        ││rules(own)│ │
│   └──────┘└──────┘└──────┘└────────┘└────────┘└─────────┘ │
└───────────────────────────────────────────────────────────┘
```

**Principio de diseño:** el consumidor nunca importa `icu`, `fluent`, `jiff` o `phonenumber` directamente. Solo importa `i18n-orchestrator`. Si mañana cambia la librería temporal o de teléfonos, la API pública no se rompe.

---

## 6. Cobertura del universo conceptual — verificación de completitud

Se contrastó explícitamente la lista original ("¿qué controla i18n?") contra el diseño para confirmar que no queda ningún punto sin cubrir, y se añadieron aspectos que la investigación reveló como parte del mismo universo pero ausentes del listado inicial:

| Aspecto original | ¿Cubierto? | Mecanismo |
|---|---|---|
| Traducción de textos | ✅ | Fluent |
| Formato de fecha/hora | ✅ | jiff (cálculo) + ICU4X (presentación) |
| Formato de números | ✅ | ICU4X |
| Monedas | ✅ | ICU4X + codes-iso-4217 |
| Unidades de medida | ✅ | ICU4X |
| Dirección de texto (LTR/RTL) | ✅ | ICU4X / UAX #9 |
| Orden de clasificación (collation) | ✅ | ICU4X / UTS #10 |
| Zona horaria | ✅ | jiff + IANA tzdata |
| Pluralización | ✅ | Fluent / CLDR Plural Rules |
| Género gramatical | ✅ | Fluent |
| **Máscaras y validación de captura** | ✅ | Módulo `mask` + `validate` (secciones 7-8) |
| **Calendarios no gregorianos** *(no estaba en la lista original)* | ✅ añadido | `icu::calendar` — relevante si algún tenant opera con calendario islámico, hebreo, etc. |
| **Primer día de la semana** *(no estaba en la lista original)* | ✅ añadido | CLDR lo define por región (lunes en Bolivia, domingo en EE.UU.) — parte de `RegionalConfig` |
| **Orden y formato de nombre de persona** *(no estaba en la lista original)* | ⚠️ parcial | CLDR tiene datos de orden nombre/apellido por cultura, pero no hay crate Rust maduro dedicado; queda como extensión propia si se necesita |
| **Formato de dirección postal** *(no estaba en la lista original)* | ⚠️ fuera de alcance | No hay estándar Unicode/ISO único (cada país define su propio formato postal); se deja como registro extensible igual que los documentos de identidad (sección 8) |
| **Accesibilidad/WCAG relacionada con i18n** *(no estaba en la lista original)* | ℹ️ nota | El W3C i18n define buenas prácticas (idioma declarado en `lang`, dirección de texto marcada) que son responsabilidad de la capa de presentación consumidora, no del orquestador — se documenta como checklist de aceptación para quien construya la UI |
| **Visualización de valores enum por locale** | ❌ brecha identificada | `gender`, `marital_status`, `employment_type` y otros enums deben mostrarse traducidos: M→Masculino (es), M→Male (en). No es traducción de mensajes Fluent — es un mapa `enum_value → label` por locale. Se resuelve con el módulo `enum_display` (sección 7.1). |
| **Granularidad de fecha** | ❌ brecha identificada | `birth_date` es solo fecha, `anio` (vehículo) es solo año, `created_at` es datetime. El `display_format` debe distinguir granularidad: `DATE_ISO` (1985-06-15), `YEAR_ONLY` (1992), `DATETIME_ISO` (2026-07-16T05:00), `TIME_ONLY` (14:30). El módulo `mask` debe aceptar `DateGranularity` como parámetro (sección 7.2). |
| **Formato de dirección postal por país** | ❌ brecha identificada | Bolivia: Calle/Número, Zona, Ciudad, Departamento. EE.UU.: Número/Calle, Ciudad, Estado, ZIP. Argentina: Calle/Número, Piso/Depto, Código Postal, Ciudad, Provincia. `ADDR_INTL` no basta — cada país define su propio orden y nombres de campos. Se resuelve con `[postal]` en el TOML de país (sección 8.1). |
| **Formato de nombre por cultura** | ❌ brecha identificada | Bolivia: Given + Family + Second_Family. China: Family + Given. Islandia: Given + Patronymic (sin apellido familiar). El orden de presentación y los campos relevantes cambian según cultura. Se resuelve con `[name]` en el TOML de país (sección 8.1). |
| **Máscara PII por tipo de documento** | ❌ brecha identificada | CI Bolivia: `7654321-LP` → `****321-LP`. NIT: `12345678901234` → `****78901234`. Pasaporte: `AB1234567` → `AB****567`. Cada país define su propia máscara de privacidad por tipo de documento. No basta con `partial(N)` genérico — la máscara debe saber qué caracteres preservar y cuáles ocultar según el formato del documento. Se resuelve con campo `mask` dentro de cada `[national_id.*]` en el TOML de país (sección 8.1). |
| **Formato de placa vehicular por país** | ❌ brecha identificada | Bolivia: `1234-ABC`. Argentina: `AB 123 CD`. Brasil: `ABC-1A23` (Mercosur). La validación y máscara dependen del país. Se resuelve con `[vehicle.plate]` en el TOML de país (sección 8.1). |
| **Formato de cuenta bancaria** | ❌ brecha identificada | Bolivia: número de cuenta simple. Europa: IBAN estructurado (`ES91 2100 0418 4502 0005 1332`). Para atributos financieros del tenant. Se resuelve con `[bank]` en el TOML de país (sección 8.1). |
| **Mapeo `display_format` → patrón ICU4X + máscara** | ❌ brecha identificada | El manual de atributos define 18 códigos de `display_format` (`E164`, `TAX_BO`, `ID_BO`, `EMAIL_RFC5321`...). El orquestador necesita un mapa centralizado: código → patrón ICU4X para presentación + máscara de entrada derivada para formularios. Se resuelve con el módulo `format_map` (sección 13). |

**Conclusión de la verificación v1.2:** 25 aspectos revisados. 17 cubiertos por el diseño original, 3 parciales (nombre, dirección, accesibilidad), 1 nota (WCAG), y **8 brechas nuevas identificadas y cerradas** en esta versión. El universo de atributos de identidad queda cubierto en su totalidad: los gaps 1-2 son módulos nuevos del orquestador (`enum_display`, `DateGranularity`), los gaps 3-7 son secciones nuevas en los archivos TOML de país, y el gap 8 es el puente entre el `display_format` del manual de atributos y los patrones ICU4X que el orquestador usa internamente.

---

## 7. Máscaras de entrada

Ninguna librería de i18n aplica máscaras automáticamente — es responsabilidad separada, confirmado por la investigación original. El orquestador cierra ese hueco:

1. ICU4X expone los *patrones* CLDR de fecha/número/moneda por locale (ej. `dd/MM/yyyy`, `#,##0.00`).
2. El módulo `mask` traduce esos patrones a una máscara de entrada usable en UI (`99/99/9999`, `#.###,##`), sin mantener a mano una tabla por país.
3. Es la pieza que en JS resuelven librerías aparte (`cleave.js`, `imask`) y que en Rust no existe de forma madura — aquí se deriva directamente del dato CLDR.

### 7.1 Visualización de valores enum por locale (`enum_display`)

Los atributos de identidad con valores enumerados (`gender`, `marital_status`, `employment_type`,
`account_type`, `role_tier`, etc.) deben mostrarse en el idioma del tenant. No es una traducción
de mensajes Fluent — es un mapa directo `enum_value → label` por locale, sin interpolación ni
pluralización:

```toml
# country-rules/bo.toml — sección [enum_display]
[enum_display.gender.es-BO]
M = "Masculino"
F = "Femenino"
NB = "No Binario"
NR = "No Responde"

[enum_display.marital_status.es-BO]
SINGLE = "Soltero/a"
MARRIED = "Casado/a"
DIVORCED = "Divorciado/a"
WIDOWED = "Viudo/a"
CIVIL_UNION = "Unión Libre"

[enum_display.employment_type.es-BO]
FULL_TIME = "Tiempo Completo"
PART_TIME = "Medio Tiempo"
CONTRACTOR = "Contratista"
INTERN = "Pasante"
```

```rust
// API del módulo enum_display
let orch = Orchestrator::new(Locale::parse("es-BO")?)
    .load_country_rules_dir("./country-rules")?;

let label = orch.enum_display("gender", "M")?;
// → "Masculino" (es-BO) | "Male" (en-US)

// Si no hay traducción para el locale exacto, fallback al default del país:
let label = orch.enum_display("gender", "M")?;
// es-MX no tiene entrada → fallback a es-BO → "Masculino"
```

### 7.2 Granularidad de fecha (`DateGranularity`)

No todos los atributos de fecha son datetime completos. `birth_date` es fecha sin hora,
`anio` (vehículo) es solo año, `hire_date` es fecha, `created_at` es datetime con zona.
El `display_format` debe especificar la granularidad para que el formateador y la máscara
de entrada usen solo los componentes relevantes:

```rust
pub enum DateGranularity {
    DateTime,   // "16 de julio de 2026, 05:00 AM" — created_at, updated_at
    Date,       // "16 de julio de 2026" — birth_date, hire_date, vencimiento
    YearMonth,  // "julio 2026" — credit_card_expiry
    Year,       // "2026" — anio (vehículo), ejercicio_fiscal
    Time,       // "05:00 AM" — horario (dispositivo)
}
```

El módulo `mask` usa `DateGranularity` para generar la máscara de entrada correcta:

```rust
// Máscara derivada de ICU4X + DateGranularity
orch.mask_for_field("date", &locale, DateGranularity::Date)?;
// → "99/99/9999" (es-BO: dd/MM/yyyy)

orch.mask_for_field("date", &locale, DateGranularity::Year)?;
// → "9999" (solo año)
```

---

## 8. Extensibilidad por país (Bolivia u otro país específico)

Ningún crate internacional trae reglas de NIT, cédula de identidad, matrícula de comercio, o formato postal boliviano — **no existen en ningún estándar Unicode/ISO**, son reglas nacionales. La arquitectura correcta no es esperar a que aparezca una librería que las traiga, sino que el propio orquestador exponga un **registro extensible de reglas por país**, cargado desde archivos de configuración declarativos (TOML), no compilado a mano en el binario.

### 8.1 Estructura del registro

```
i18n-orchestrator/
└── country-rules/
    ├── bo.toml     ← Bolivia
    ├── es.toml     ← España
    ├── br.toml     ← Brasil
    └── ...
```

```toml
# country-rules/bo.toml
[country]
iso3166 = "BO"
default_locale = "es-BO"
default_timezone = "America/La_Paz"
default_currency = "BOB"
first_day_of_week = "monday"

# ── Teléfono ──
[phone]
calling_code = "+591"
# delega en `phonenumber`, esto es solo metadata de referencia

# ── Documentos de identidad ──
[national_id.ci]                      # Cédula de Identidad
pattern = '^\d{7,8}(-[A-Z]{2})?$'
input_mask = "#######-LP"
display_mask = "partial(4)"           # últimos 4 visibles: ****321-LP
label = "Cédula de Identidad"

[national_id.nit]                     # Número de Identificación Tributaria
pattern = '^\d{7,13}$'
input_mask = "#############"
display_mask = "partial(4)"           # ****78901234
label = "NIT"

[national_id.pasaporte]
pattern = '^[A-Z]{2}\d{7}$'
input_mask = "AA9999999"
display_mask = "partial(3,prefix=2)"  # preserva 2 del prefijo + últimos 3: AB****567
label = "Pasaporte"

# ── Formato de nombre por cultura ──
[name]
order = ["given_name", "family_name", "second_family"]
# China: order = ["family_name", "given_name"]
# Islandia: order = ["given_name"]  (apellido = patronímico, no se hereda)
salutation_before = false              # "Juan Pérez" vs "Pérez, Juan" (formato lista)
matronymic_supported = false           # true para culturas con apellido materno explícito

# ── Dirección postal ──
[postal]
supported = true                       # Bolivia: sin código postal nacional, pero con formato
fields = [
    { id = "street",       label = "Calle / Avenida",    required = true },
    { id = "number",       label = "Número",             required = true },
    { id = "zone",         label = "Zona / Barrio",      required = true },
    { id = "municipality", label = "Municipio / Ciudad", required = true },
    { id = "department",   label = "Departamento",       required = false },
    { id = "reference",    label = "Referencia",         required = false }
]
# EE.UU.: fields = [street, city, state, zip]
# Argentina: fields = [street, number, floor, apartment, postal_code, city, province]

# ── Placa vehicular ──
[vehicle.plate]
pattern = '^\d{4}-[A-Z]{3}$'
input_mask = "9999-AAA"
label = "Placa"
# Argentina: pattern = '^[A-Z]{2}\s\d{3}\s[A-Z]{2}$', mask = "AA 999 AA"
# Brasil Mercosur: pattern = '^[A-Z]{3}\d[A-Z]\d{2}$', mask = "AAA9A99"

# ── Cuenta bancaria ──
[bank]
account_mask = "##########"            # Bolivia: número de cuenta simple
# Europa: iban_pattern = '^[A-Z]{2}\d{2}\s?(\d{4}\s?){4,7}\d{1,3}$'
# Europa: iban_display_mask = "partial(4,prefix=2,suffix=4)"

# ── Sinónimos regionales ──
[synonyms]
# Palabras que varían por país — alimentan idn_identidad_sinonimo
"farol" = ["foco", "óptica", "luz_delantera"]          # Bolivia: farol
# México: "foco" = ["farol", "luz_delantera", "faro"]
# Argentina: "óptica" = ["farol", "luz", "foco"]
```

### 8.2 API de extensión

```rust
// Carga automática de todos los .toml en el directorio de reglas
let orch = Orchestrator::new(Locale::parse("es-BO")?)
    .load_country_rules_dir("./country-rules")?;

// Validación usando la regla registrada, no hardcodeada en el crate
orch.validate_national_id("bo", "ci", "7654321-LP")?;

// Enmascaramiento PII según regla del país
let masked = orch.mask_national_id("bo", "ci", "7654321-LP")?;
// → "****321-LP"  (aplica display_mask del TOML)

// Formato de nombre según cultura
let ordenado = orch.format_name("bo", "Juan", "Pérez", Some("García"))?;
// → "Juan Pérez García"  (order = [given, family, second_family])

// Formato de dirección según país
let direccion = orch.format_address("bo", AddressFields {
    street: "Av. Arce".into(),
    number: "2678".into(),
    zone: "Sopocachi".into(),
    municipality: "La Paz".into(),
    ..Default::default()
})?;
// → "Av. Arce N° 2678, Sopocachi, La Paz"

// El consumidor también puede registrar reglas propias en tiempo de ejecución,
// sin tocar el código fuente del orquestador ni esperar un release nuevo
orch.register_national_id_rule("bo", "matricula_fundempresa", regla_custom);
```

Este mecanismo responde directamente a tu pregunta: **para agregar el estándar de Bolivia (o cualquier otro país) no se modifica el crate**, se añade o edita un archivo `.toml` en el registro — el mismo patrón que usan los navegadores para reglas de validación de formularios por país, pero declarativo y auditable.

---

## 9. Interfaz dual: CLI + JSON-RPC daemon

El orquestador expone sus capacidades por dos canales complementarios, siguiendo el mismo
patrón Interface Dual (ADR-020) que todos los daemons SBOS: **CLI para humanos** (`i18nctl`)
y **JSON-RPC 2.0 sobre Unix socket para otros daemons y aplicaciones** (`bi18nd`).

### 9.1 CLI (`i18nctl`)

Un conjunto de subcomandos construidos con `clap` (v4.6.x) que exponen cada capacidad del
orquestador para pruebas, administración y scripting.

```
i18nctl format date "2026-07-15T10:00:00Z" --locale es-BO --tz America/La_Paz
i18nctl format number 1234.5 --locale es-BO
i18nctl format money 1400.00 --currency BOB --locale es-BO

i18nctl validate phone "+59171234567" --region BO
i18nctl validate national-id --country bo --kind ci "7654321-LP"

i18nctl mask value "12345678901234" --format TAX_BO --strategy partial(4)
i18nctl mask currency --locale es-BO
i18nctl mask date --locale en-US

i18nctl locale resolve --tenant-id acme-sa
i18nctl locale set --tenant-id acme-sa --locale es-BO --tz America/La_Paz --currency BOB

i18nctl rules list --country bo
i18nctl rules validate ./country-rules/bo.toml

i18nctl collate --locale es-BO "Zebra" "Ñoño" "Álvarez"

# ── Operaciones sobre atributos (builder) ──
i18nctl attr build --key nombre --value "juan pérez" \
    --transform uppercase --format NULL --mask none
# → { "raw": "juan pérez", "transformed": "JUAN PÉREZ", "display": "JUAN PÉREZ", "masked": "JUAN PÉREZ" }

i18nctl attr pipeline --key CI --value "7654321-LP" \
    --validate ID_BO --transform plain --format ID_BO --mask partial(4)
# → { "raw": "7654321-LP", "valid": true, "display": "7654321 LP", "masked": "****321-LP" }
```

### 9.2 JSON-RPC daemon (`bi18nd`) — Interface Dual (ADR-020)

El mismo binario compila en dos modos: CLI interactivo (`i18nctl`) o daemon systemd (`bi18nd`).
El daemon expone exactamente las mismas capacidades vía JSON-RPC 2.0 sobre Unix socket
`/run/bos/bi18n.sock` (0660, grupo `bos`), para que cualquier otro daemon SBOS pueda
consumirlo sin importar el crate.

```
┌──────────────────────────────────────────────────────────────┐
│  bi18nd (systemd, Type=notify)                                │
│  Socket: /run/bos/bi18n.sock (0660, grupo bos)                │
│                                                                │
│  JSON-RPC 2.0 ← otros daemons (bAuth, bos, bNotify...)       │
│  WebSocket RPC ← CLI humano (i18nctl --daemon)                │
└──────────────────────────────────────────────────────────────┘
```

**Métodos JSON-RPC expuestos:**

| Namespace | Método | Parámetros | Retorno |
|---|---|---|---|
| `bi18n.format` | `date` | `value, locale, tz` | `{formatted: "16 de julio de 2026"}` |
| `bi18n.format` | `number` | `value, locale` | `{formatted: "1.500,00"}` |
| `bi18n.format` | `money` | `value, currency, locale` | `{formatted: "Bs. 1.500,00"}` |
| `bi18n.format` | `address` | `country, fields{}` | `{formatted: "Av. Arce N° 2678, Sopocachi"}` |
| `bi18n.format` | `name` | `country, given, family, second_family?` | `{formatted: "Juan Pérez García"}` |
| `bi18n.validate` | `phone` | `value, region` | `{valid: true, formatted: "+591 7 1234567"}` |
| `bi18n.validate` | `national_id` | `country, kind, value` | `{valid: true, masked: "****321-LP"}` |
| `bi18n.validate` | `email` | `value` | `{valid: true, normalized: "user@domain.com"}` |
| `bi18n.validate` | `plate` | `country, value` | `{valid: true, formatted: "1234-ABC"}` |
| `bi18n.mask` | `value` | `value, format, strategy` | `{masked: "****8901234"}` |
| `bi18n.mask` | `pii` | `value, country, kind` | `{masked: "****321-LP"}` |
| `bi18n.locale` | `resolve` | `tenant_id, branch_id?, user_id?` | `{locale, timezone, currency, country}` |
| `bi18n.enum` | `display` | `enum_type, value, locale` | `{label: "Masculino"}` |
| `bi18n.rules` | `list` | `country` | `[{kind, pattern, mask, label}]` |
| `bi18n.rules` | `validate_file` | `path` | `{valid: true, errors: []}` |
| `bi18n.attr` | `build` | `key, value, transforms[], format, mask` | `AttrResult` |
| `bi18n.attr` | `pipeline` | `key, value, validate?, transforms[], format, mask` | `AttrResult` |
| `bi18n.collate` | `sort` | `items[], locale` | `["Álvarez", "Ñoño", "Zebra"]` |

**Ejemplo de request JSON-RPC desde bAuth:**

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "bi18n.attr.pipeline",
  "params": {
    "key": "CI",
    "value": "7654321-lp",
    "validate": "ID_BO",
    "transforms": ["uppercase", "strip_hyphen"],
    "format": "ID_BO",
    "mask": "partial(4)",
    "country": "bo"
  }
}
```

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "raw": "7654321-lp",
    "valid": true,
    "transformed": "7654321 LP",
    "display": "7654321 LP",
    "masked": "****321-LP",
    "enum_label": null
  }
}
```

### 9.3 API builder fluida para atributos (`attr`)

Cada atributo de identidad sigue un pipeline predecible: valor crudo → validación →
transformación → formato de presentación → enmascaramiento PII → localización de enums.
El módulo `attr` expone este pipeline como un builder pattern de Rust con método chaining,
para que cualquier daemon (o el dashboard vía JSON-RPC) pueda procesar atributos sin
conocer las reglas de cada país:

```
Pipeline de un atributo:
────────────────────────────────────────────────────────────
raw_value → validate? → transform* → format → mask → locale
────────────────────────────────────────────────────────────
```

**API Rust (builder pattern):**

```rust
use i18n_orchestrator::attr::{AttrBuilder, AttrResult, Transform, MaskStrategy, DisplayFormat};

// ── Uso simple: solo transformar y formatear ──
let resultado: AttrResult = AttrBuilder::new("nombre")
    .value("juan pérez")
    .transform(Transform::TitleCase)         // "Juan Pérez"
    .format(DisplayFormat::Plain)
    .build()?;
// AttrResult { raw: "juan pérez", transformed: "Juan Pérez",
//              display: "Juan Pérez", masked: "Juan Pérez" }

// ── Uso completo: validar + transformar + formatear + enmascarar ──
let resultado: AttrResult = AttrBuilder::new("CI")
    .value("7654321-lp")
    .validate("ID_BO")                       // regex + checksum del TOML bo
    .transform(Transform::Uppercase)         // "7654321-LP"
    .transform(Transform::StripHyphen)       // "7654321 LP"
    .format(DisplayFormat::Code("ID_BO"))    // máscara de presentación: 0000000 XX
    .mask(MaskStrategy::Partial { visible_from_end: 4 })  // "****321-LP"
    .country("bo")
    .build()?;
// AttrResult {
//   raw: "7654321-lp",
//   valid: true,
//   transformed: "7654321 LP",
//   display: "7654321 LP",
//   masked: "****321-LP",
// }

// ── Con valor enum localizado ──
let resultado: AttrResult = AttrBuilder::new("gender")
    .value("M")
    .validate("ENUM")                        // valida contra canonicalValues
    .format(DisplayFormat::Plain)
    .localize("es-BO")                       // "Masculino"
    .build()?;
// AttrResult { display: "Masculino", enum_label: "Masculino" }

// ── Con granularidad de fecha ──
let resultado: AttrResult = AttrBuilder::new("birth_date")
    .value("1985-06-15")
    .validate("DATE_ISO")
    .format(DisplayFormat::DateIso)
    .date_granularity(DateGranularity::Date)
    .localize("es-BO")                       // "15 de junio de 1985"
    .build()?;
```

**Estructura de `AttrResult`:**

```rust
/// Resultado completo del pipeline de un atributo.
/// Contiene el valor en todas sus representaciones: cruda, validada,
/// transformada, formateada, enmascarada y localizada.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AttrResult {
    /// Valor original recibido
    pub raw: String,
    /// Si pasó la validación (None si no se validó)
    pub valid: Option<bool>,
    /// Valor después de transformaciones (uppercase, trim, title_case...)
    pub transformed: String,
    /// Valor formateado para presentación (E164, DATE_ISO, ID_BO...)
    pub display: String,
    /// Valor enmascarado para UI/logs (partial/full/none)
    pub masked: String,
    /// Etiqueta localizada si es un valor enum (M→"Masculino")
    pub enum_label: Option<String>,
    /// Errores de validación si los hubo
    pub validation_errors: Vec<String>,
}
```

**Transformaciones disponibles (`Transform`):**

| Transform | Qué hace | Ejemplo |
|---|---|---|
| `Uppercase` | Convierte a mayúsculas | `"juan"` → `"JUAN"` |
| `Lowercase` | Convierte a minúsculas | `"JUAN"` → `"juan"` |
| `TitleCase` | Primera letra de cada palabra en mayúscula | `"juan pérez"` → `"Juan Pérez"` |
| `Trim` | Elimina espacios al inicio y final | `"  juan  "` → `"juan"` |
| `StripHyphen` | Elimina guiones | `"7654321-LP"` → `"7654321 LP"` |
| `StripSpaces` | Elimina todos los espacios | `"+591 7 1234567"` → `"+59171234567"` |
| `StripAccents` | Elimina acentos (unaccent) | `"Jesús María"` → `"Jesus Maria"` |
| `DigitsOnly` | Solo dígitos | `"1234-ABC"` → `"1234"` |
| `AlphaOnly` | Solo letras | `"1234-ABC"` → `"ABC"` |
| `PadLeft(n,c)` | Rellena por izquierda | `"123"` → `"0000123"` |
| `PadRight(n,c)` | Rellena por derecha | `"ABC"` → `"ABC0000"` |

**Estrategias de enmascaramiento (`MaskStrategy`):**

| Estrategia | Qué hace | Ejemplo |
|---|---|---|
| `None` | Sin máscara | `"7654321-LP"` → `"7654321-LP"` |
| `Full` | Todo oculto | `"7654321-LP"` → `"**********"` |
| `Partial { visible_from_end }` | Últimos N visibles | `partial(4)` → `"****321-LP"` |
| `Partial { visible_from_start }` | Primeros N visibles | `partial_prefix(4)` → `"7654*****"` |
| `Partial { prefix, suffix }` | Prefijo + sufijo visibles | `prefix=2,suffix=3` → `"AB****567"` |
| `FromCountryRule` | Usa la regla del TOML de país | Lee `display_mask` del TOML |

**Por qué builder y no funciones sueltas:** el orden importa — `transform` antes de `format`
antes de `mask` antes de `localize`. El builder garantiza el orden correcto en tiempo de
compilación y evita que el consumidor invoque las operaciones en secuencia incorrecta.
Además, cada paso puede fallar independientemente y el builder acumula errores sin detenerse
(staged pipeline, mismo patrón que atomc).

---

## 10. Configuración regional multi-tenant: el problema central

Este es el punto que motivó la pregunta y merece una sección dedicada, porque es un error de diseño extremadamente común: **confundir la configuración regional del servidor con la del tenant/usuario.**

### 10.1 El problema exacto que describes

- El proceso corre en una VPS con `TZ=Europe/Berlin` (o UTC, según cómo esté configurado el sistema operativo).
- El tenant (empresa) opera en Bolivia, con huso horario `America/La_Paz` (UTC-4, sin horario de verano), idioma `es-BO` y moneda `BOB`.
- Si el código llama a `Zoned::now()` sin especificar zona, o si `icu::datetime` formatea usando el locale del sistema operativo, **el resultado es incorrecto para el tenant** aunque sea "correcto" para el servidor.

**Regla de oro del diseño:** el orquestador **nunca** debe leer configuración regional del sistema operativo, variables de entorno del proceso, ni locale del servidor como fuente de verdad para operaciones de negocio. La única fuente de verdad es la configuración explícita del tenant, resuelta antes de cada operación.

### 10.2 Jerarquía de resolución de configuración regional

La configuración regional se resuelve en capas, de más específica a más general — el mismo patrón que usan los sistemas multi-tenant maduros (Salesforce, SAP) para este problema exacto:

```
1. Usuario individual   (si el usuario dentro del tenant tiene su propia preferencia)
        ↓ si no está definida
2. Sucursal / Branch    (si el tenant tiene sucursales en distintos países)
        ↓ si no está definida
3. Tenant / Empresa     (configuración regional principal de la empresa)
        ↓ si no está definida
4. Default del sistema  (fallback explícito, nunca implícito del SO)
```

```rust
pub struct RegionalConfig {
    pub locale: Locale,           // BCP 47, ej. "es-BO"
    pub timezone: jiff::tz::TimeZone, // IANA, ej. "America/La_Paz"
    pub currency: String,         // ISO 4217, ej. "BOB"
    pub country: String,          // ISO 3166, ej. "BO"
    pub first_day_of_week: Weekday,
}

pub trait RegionalConfigResolver {
    /// Resuelve la config regional efectiva para una operación concreta,
    /// nunca cae al locale/TZ del sistema operativo del servidor.
    fn resolve(&self, tenant_id: &str, branch_id: Option<&str>, user_id: Option<&str>)
        -> Result<RegionalConfig, ResolverError>;
}
```

- El **servidor** (la VPS en Alemania) es solo el lugar de ejecución del proceso — su zona horaria/locale del sistema operativo **no debe influir en ningún cálculo de negocio**. Se recomienda incluso forzar `TZ=UTC` a nivel de sistema operativo del servidor para eliminar la tentación de que algún código dependa implícitamente de ella, y trabajar siempre con `jiff::Zoned` explícito.
- Cada request/operación debe **resolver explícitamente** el `RegionalConfig` del tenant (y, si aplica, sucursal o usuario) al inicio, y pasarlo como parámetro a todas las llamadas del orquestador — nunca como estado global o `thread_local` implícito, porque en un backend que atiende múltiples tenants a la vez, un valor global se filtraría entre tenants.

```rust
// Ejemplo de flujo típico en un backend multi-tenant
let regional = resolver.resolve(&tenant_id, branch_id, Some(&user_id))?;

let orch = Orchestrator::with_regional_config(&regional);

let vencimiento_local = orch.time_now().checked_add(jiff::ToSpan::days(30))?;
let texto = orch.format_date(&vencimiento_local, DateStyle::Long);
// Independiente de dónde esté físicamente la VPS, el resultado es
// correcto para America/La_Paz porque `regional` vino del tenant, no del SO.
```

### 10.3 Dónde vive esta configuración

El orquestador **no decide dónde se persiste** `RegionalConfig` (eso depende de cada sistema: base de datos de tenants, archivo de configuración, etc.) — solo define el **contrato** (`RegionalConfigResolver`) y la **jerarquía de resolución**. Esto es intencional: mantiene al crate independiente y de propósito general, sin acoplarlo a un modelo de datos particular. Cualquier consumidor implementa el trait sobre su propia fuente de datos.

### 10.4 Checklist de aceptación para evitar el bug de "servidor vs tenant"

- [ ] Ningún `Zoned::now()` sin `.with_time_zone(...)` explícito en código de negocio.
- [ ] Ningún `icu::datetime` formateando con locale por defecto/del sistema — siempre recibe el `Locale` resuelto del tenant.
- [ ] El servidor corre con `TZ=UTC` a nivel de sistema operativo (mejor práctica adicional, no solo del orquestador).
- [ ] `RegionalConfig` se resuelve una vez por operación/request y se pasa explícitamente — nunca variable global ni `thread_local`.
- [ ] Tests que ejecuten el mismo caso con el proceso configurado en `Europe/Berlin` y en `America/La_Paz` y verifiquen que el resultado de negocio es idéntico (el resultado solo debe depender de `RegionalConfig`, nunca del entorno del proceso).

---

## 10.5 ¿Se puede interceptar/enmascarar el reloj del sistema operativo antes de que PostgreSQL u otros lo capturen?

Esta es la pregunta técnica de fondo, y la investigación da una respuesta clara: **existe la tecnología para hacerlo a nivel de proceso, pero para el caso concreto que describes (PostgreSQL) ya existe una solución nativa mejor, y para el caso general (interceptar a nivel de kernel/SO) la propia industria evita hacerlo por razones de seguridad y fiabilidad.** Se documentan las tres capas posibles, de la más al menos recomendable.

#### A) La solución correcta para PostgreSQL: no hace falta interceptar nada — ya existe el mecanismo

Se investigó específicamente el caso PostgreSQL y **el propio motor ya resuelve exactamente este problema**, sin necesidad de ninguna capa de enmascaramiento:

- `timestamptz` (`timestamp with time zone`) **no almacena ninguna zona horaria** — almacena internamente un instante absoluto en UTC (segundos/microsegundos desde el epoch). La zona horaria solo se aplica en dos momentos: al **interpretar** un literal de texto sin offset explícito, y al **mostrar** el valor como texto.
- Ese "cómo interpretar/mostrar" está gobernado por el parámetro de sesión `TimeZone`, que la documentación oficial de PostgreSQL indica que **no debe fijarse centralmente en el servidor** — cada sesión de base de datos debe fijarlo según la zona horaria del cliente que se conecta.
- Esto se puede fijar en tres niveles, de más general a más específico, sin tocar el reloj del sistema operativo en ningún momento:

```sql
-- Nivel base de datos (poco flexible para multi-tenant real)
ALTER DATABASE mi_bd SET timezone TO 'America/La_Paz';

-- Nivel rol/usuario de PostgreSQL — útil si cada tenant tiene su propio rol
ALTER ROLE tenant_acme SET timezone TO 'America/La_Paz';

-- Nivel sesión — la opción correcta para un pool multi-tenant real,
-- el orquestador la ejecuta justo después de abrir cada conexión
SET timezone = 'America/La_Paz';
SELECT now();  -- devuelve el instante UTC ya formateado en America/La_Paz
```

En un pool de conexiones compartido entre tenants (pgbouncer, deadpool, sqlx pool), el patrón correcto es que **el daemon `bi18n`/orquestador ejecute `SET timezone` como primer comando de cada conexión que toma del pool**, usando el `RegionalConfig` ya resuelto del tenant (sección 10.2) — nunca depender de la zona horaria del proceso del sistema operativo ni de `postgresql.conf`. El dato en disco (`timestamptz`) sigue siendo UTC puro, universal e inequívoco; solo cambia cómo PostgreSQL lo *muestra* en esa sesión.

**Conclusión para PostgreSQL: no se necesita ninguna capa de "enmascaramiento" del SO — el motor ya separa correctamente instante (UTC) de presentación (sesión), que es exactamente el mismo principio que ya aplicamos con `jiff`/`icu::datetime` en la aplicación (sección 4).**

#### B) Interceptar el reloj a nivel de proceso individual: existe, pero es frágil (`libfaketime`)

Para procesos que sí necesitan "creerse" en otra fecha/hora (no es el caso de PostgreSQL, pero puede serlo para algún binario de terceros sin soporte de zona horaria propio), la herramienta de referencia en Linux es **`libfaketime`**, que intercepta llamadas como `time()`/`clock_gettime()`/`fstat()` vía `LD_PRELOAD` y les devuelve un valor falso:

```bash
LD_PRELOAD=/usr/lib/faketime/libfaketime.so.1 \
FAKETIME="2026-07-15 10:00:00" \
/mi/binario
```

Limitaciones confirmadas por la documentación oficial del proyecto, importantes para decidir si aplica a SBOS/tu stack:
- **No funciona con binarios estáticos** — programas en Go, y en menor medida Rust si se compilan estáticamente (`musl`), *no* pasan por el mecanismo de enlazado dinámico que `LD_PRELOAD` necesita, así que **quedan fuera de este mecanismo por diseño**.
- No funciona de forma fiable con JVMs completas ni con programas `setuid root` (por razones de seguridad del propio sistema operativo).
- Es efectivamente un mecanismo de **testing/desarrollo** (simular "¿qué pasaría si fuera 2027?"), no una arquitectura recomendada para producción multi-tenant — el propio proyecto documenta que "congelar el reloj generalmente no es lo que se quiere y puede romper la aplicación".

#### C) Interceptar el reloj a nivel de kernel/namespace: el propio Linux se niega a hacerlo por diseño

Se investigó si existe un mecanismo de kernel para dar a un contenedor o proceso su propia hora de pared (wall clock) — la respuesta, documentada explícitamente en el manual del kernel Linux (`time_namespaces(7)`), es que **no**:

> *"Note that time namespaces do not virtualize the CLOCK_REALTIME clock. Virtualization of this clock was avoided for reasons of complexity and overhead within the kernel."*

Los *time namespaces* de Linux (desde el kernel 5.6, usados por herramientas como CRIU para migración de contenedores) **solo virtualizan `CLOCK_MONOTONIC` y `CLOCK_BOOTTIME`** (tiempo transcurrido, no fecha de pared) — deliberadamente **excluyen `CLOCK_REALTIME`** (la hora real) porque virtualizarla de forma consistente en todo el sistema (certificados TLS, logs, cron, systemd, monitoreo) introduciría una complejidad y un riesgo que el propio kernel considera que no vale la pena. Es decir: **ni siquiera el kernel de Linux ofrece una forma robusta de "mentirle" a un proceso sobre la hora real de forma aislada y segura** — es un límite de diseño deliberado, no una carencia técnica accidental.

#### D) Conclusión y recomendación final

| Opción | ¿Recomendable para SBOS/producción? | Motivo |
|---|---|---|
| Enmascarar `CLOCK_REALTIME` a nivel de kernel/namespace | ❌ No existe | El propio Linux lo excluye por diseño (complejidad/seguridad) |
| `libfaketime` (LD_PRELOAD) system-wide | ❌ No recomendado | Fragmenta el comportamiento, no cubre binarios estáticos, pensado para testing, no para multi-tenant en producción |
| **`SET timezone` por sesión en PostgreSQL** (u opción equivalente en cada motor de datos) | ✅ **Sí — es la solución real** | Es exactamente para esto que existe `timestamptz`: instante absoluto en UTC + presentación por sesión, sin tocar el SO |
| **Resolución explícita de `RegionalConfig` en la capa de aplicación** (secciones 4 y 10.2) | ✅ **Sí — ya está en el diseño** | El orquestador nunca lee el reloj/locale del SO; siempre recibe el contexto del tenant de forma explícita |

**La arquitectura correcta no es interceptar/enmascarar lo que el sistema operativo emite** (ese camino es frágil, incompleto por diseño del propio kernel, y resuelve mal un problema que cada componente ya sabe resolver mejor por su cuenta) — **es asegurar que ningún componente confíe jamás en el reloj/locale del sistema operativo como fuente de verdad**, y que en su lugar reciba explícitamente el contexto regional del tenant en cada operación: `jiff` con zona horaria explícita en la aplicación (sección 4), `SET timezone` por sesión en PostgreSQL (arriba), `Locale` explícito en ICU4X (sección 5). El servidor en Alemania puede quedarse tranquilamente en UTC — es irrelevante para el resultado, porque ningún dato de negocio depende de él.

---

## 10.6 Lo que sí pediste: una capa universal dentro del SO — y la distinción que hay que hacer primero

Tu último punto es más específico: no quieres resolverlo instancia por instancia (Postgres, la app, etc.) — quieres que el propio sistema operativo, de forma universal, entregue a cada proceso el valor correcto del tenant, incluyendo un comando tan básico como `date`. Esto **sí es alcanzable de forma robusta**, pero investigar a fondo obliga a separar dos cosas que tu pregunta une y que tienen respuestas opuestas:

| | ¿Qué es? | ¿Se puede hacer universal en el SO? |
|---|---|---|
| **El instante real** (`CLOCK_REALTIME`, lo que sincroniza NTP, lo que ancla `date -u`) | La verdad física de "qué hora es ahora en UTC" | **No debe enmascararse nunca** — ver más abajo por qué |
| **La presentación de ese instante** (huso horario, idioma, formato) | Cómo se le muestra ese mismo instante a un proceso/usuario concreto | **Sí, y hay un mecanismo estándar de Linux para hacerlo universal** |

### 10.6.1 Por qué el instante real (`date -u`) no se debe enmascarar — esto no es una limitación técnica, es un requisito de la auditoría misma

Aquí hay un punto que cambia la respuesta: dijiste que esto es, entre otras cosas, para **trazabilidad y auditoría**. Se investigó qué exigen los marcos de auditoría de seguridad de la información sobre este punto exacto, y la respuesta es la contraria a enmascarar:

**ISO/IEC 27001:2022, Control Anexo A 8.17 (Sincronización de relojes)** exige que todos los sistemas que generan eventos de seguridad relevantes sincronicen su reloj a **una única fuente de tiempo confiable** (típicamente NTP/PTP contra una fuente Stratum 1), y recomienda explícitamente **UTC como línea base única** precisamente para eliminar la ambigüedad de husos horarios al correlacionar eventos entre sistemas. Los auditores verifican literalmente que el reloj del sistema coincida con la hora real — es una de las pruebas de cumplimiento estándar ("Show me that your server time matches the actual current time in your region").

**Consecuencia directa:** si `bi18n` (o cualquier capa) enmascara lo que `date -u` reporta, **el propio mecanismo que construyes para mejorar la trazabilidad terminaría rompiendo el control de auditoría que la sustenta** — un log firmado, un timestamp de auditoría, o una entrada de `bos_atom_audit`-equivalente que dependa de una hora falseada deja de ser evidencia forense válida, porque ya no es trazable a una fuente de tiempo confiable y verificable externamente. Esto es exactamente el motivo por el que ni siquiera el kernel de Linux virtualiza `CLOCK_REALTIME` (sección 10.5-C): no es solo una limitación de ingeniería, es una decisión de que **la hora real de un sistema debe seguir siendo real**, siempre.

**Recomendación firme:** para el registro de auditoría (`audit`, logs, firmas, evidencia forense), el instante debe seguir siendo UTC real, sincronizado por NTP/`chrony`/`systemd-timesyncd` contra una fuente confiable — nunca enmascarado. Ahí es donde la palabra "auditoría" te obliga a lo contrario de lo que planteabas.

### 10.6.2 Lo que sí puedes universalizar en el SO sin romper nada: la presentación, vía variables de entorno inyectadas por tenant

Esta es la pieza que responde a tu pregunta real: **cómo lograr que `date`, y en general cualquier herramienta del SO consciente de zona horaria/locale, muestre el valor correcto del tenant sin que cada aplicación tenga que saber resolverlo por su cuenta.** El mecanismo estándar de Linux para esto existe y es universal dentro del alcance de un proceso o grupo de procesos: las variables de entorno `TZ`, `LANG` y `LC_*`.

- `date` (sin `-u`) y prácticamente toda herramienta POSIX que muestra fecha/hora, además de `glibc` (`localtime()`, base de `strftime`, que a su vez usa la mayoría de lenguajes) **leen la variable de entorno `TZ`** para decidir cómo presentar el instante — no cambian el instante, cambian cómo lo muestran.
- `date -u` seguirá mostrando UTC real **incluso con `TZ` fijado** — eso no es un defecto a "arreglar", es exactamente la garantía que necesitas para que el flag `-u` siga siendo la fuente de verdad auditable mientras `date` (sin `-u`) muestra la hora del tenant. Tener ambas cosas disponibles simultáneamente es el diseño correcto, no una limitación.
- De la misma forma, `LC_TIME`, `LC_MONETARY`, `LC_NUMERIC` y `LANG` controlan cómo `glibc` formatea fecha/moneda/número para cualquier programa que use las funciones estándar de localización del sistema — es el mismo mecanismo, a nivel de SO, que ICU4X replica a nivel de aplicación.

**El daemon `bi18n` se convierte entonces en el componente que genera y distribuye ese entorno por tenant**, en vez de intentar interceptar syscalls. Esto sí es universal dentro del alcance del tenant, y es exactamente el patrón que usan sistemas multi-tenant maduros:

```
# Generado por bi18n a partir de RegionalConfig, uno por tenant
# /etc/bi18n/tenants/acme-sa.env
TZ=America/La_Paz
LANG=es_BO.UTF-8
LC_TIME=es_BO.UTF-8
LC_MONETARY=es_BO.UTF-8
LC_NUMERIC=es_BO.UTF-8
```

Puntos de inyección universales dentro del SO, según el nivel de aislamiento de cada tenant:

| Nivel de aislamiento del tenant | Mecanismo de inyección | Alcance |
|---|---|---|
| **Servicio systemd dedicado por tenant** | `EnvironmentFile=/etc/bi18n/tenants/<tenant>.env` en la unit del servicio | Todo proceso lanzado por ese servicio hereda `TZ`/`LC_*` correctos — `bi18n` solo tiene que reescribir el `.env` cuando cambia la config del tenant |
| **Contenedor/namespace por tenant** (systemd-nspawn, Podman, etc.) | Variables de entorno en el `ExecStart`/entrypoint del contenedor | Todo lo que corre dentro de ese contenedor, incluyendo `date` y cualquier CLI de terceros, ve la presentación correcta |
| **Sesión de usuario/login por tenant** | Módulo PAM (`pam_env.so` + un archivo de entorno generado por `bi18n`) al iniciar sesión | Cubre sesiones interactivas (SSH, cron de usuario) sin tocar systemd |
| **Proceso individual lanzado bajo demanda** | El propio `bi18n` fija `TZ`/`LC_*` en el entorno del proceso hijo antes de hacer `exec()` (lo mismo que ya hace `jiff`/ICU4X a nivel de librería, pero para binarios de terceros que no usan el orquestador) | Cobertura ad-hoc para herramientas externas que no pasan por tu código Rust |

Con esto, `date` dentro del contexto de un tenant boliviano imprime la hora de La Paz de forma universal — cualquier script de shell, cualquier binario de terceros, cualquier cron — sin que cada aplicación tenga que resolver `RegionalConfig` por separado, y **sin tocar `CLOCK_REALTIME`**, por lo que `date -u`, NTP, TLS, logs del sistema y la cadena de auditoría siguen siendo verdad absoluta.

### 10.6.3 Síntesis: dos capas, no una

```
┌─────────────────────────────────────────────────────────┐
│  CLOCK_REALTIME (NTP/chrony, UTC real)                    │
│  → nunca se toca, es la fuente de verdad para auditoría   │
│  → `date -u`, logs de systemd, timestamps de bAuth/bsign  │
│     equivalentes, certificados TLS, todo lo forense        │
└─────────────────────────────────────────────────────────┘
                          │
                          │ (el mismo instante, sin alterar)
                          ▼
┌─────────────────────────────────────────────────────────┐
│  Capa de presentación por tenant (TZ / LC_* inyectados)   │
│  → generada y distribuida por `bi18n` según RegionalConfig│
│  → `date` (sin -u), cron humano, logs de negocio,         │
│     glibc/ICU4X/jiff, PostgreSQL vía SET timezone          │
└─────────────────────────────────────────────────────────┘
```

Esto sí es "universal dentro del SO" en el sentido que pedías — todo proceso del tenant, no solo tu aplicación Rust — pero logrado inyectando el contexto correcto en el punto de arranque de cada proceso, no interceptando/falsificando lo que el kernel reporta. Es la diferencia entre **"todo el sistema habla el idioma del tenant"** (correcto, alcanzable, y lo que de verdad resuelve tu problema) y **"todo el sistema miente sobre qué hora es"** (rompe NTP, TLS, y el propio control de auditoría que estás intentando fortalecer).

---

## 10.7 El conversor bidireccional: `mi-fecha-tenant ⇄ date -u` — cómo hacerlo realmente reversible

Esta es la pieza de ingeniería correcta y sí es completamente viable — de hecho es exactamente para esto que existe el motor `jiff` propuesto en la sección 4. Pero investigar a fondo revela un matiz técnico que hay que resolver bien para que la reversibilidad sea garantizada y no solo "normalmente funcione":

### 10.7.1 Las dos direcciones no son simétricas — esto es lo que hay que entender primero

| Dirección | ¿Es ambigua alguna vez? | Por qué |
|---|---|---|
| **UTC (`date -u`) → hora del tenant** | **Nunca.** Siempre exacta y sin pérdida | Un instante UTC tiene exactamente una representación en cualquier zona horaria dada — es una función matemática, no una búsqueda |
| **Hora del tenant → UTC (`date -u`)** | **A veces, sí** — dos casos documentados por IANA/jiff: **"gap"** (salto de horario de verano: un rango de horas civiles simplemente no existe, ej. 2:30am no existe el día que empieza el DST) y **"fold"** (fin de horario de verano: una hora civil ocurre dos veces, ej. 1:30am ocurre dos veces el día que termina el DST) | Un mismo instante civil ("1:30am hora de La Paz") puede corresponder a dos instantes UTC distintos, o a ninguno |

Bolivia no usa horario de verano (UTC-4 fijo todo el año), así que en la práctica el caso de ambigüedad **no aplica al ejemplo Alemania↔Bolivia que describiste** — pero si el orquestador se usa con tenants en países que sí tienen DST (la propia VPS en Alemania lo tiene: CET/CEST), el conversor **debe** manejarlo explícitamente o el "ida y vuelta" se rompe silenciosamente dos días al año.

### 10.7.2 Cómo lo resuelve `jiff` (ya integrado en el diseño, sección 4) — no hay que construir nada nuevo

`jiff` implementa exactamente esta separación, siguiendo el mismo estándar que usa RFC 5545 (iCalendar) para resolver ambigüedad:

```rust
use jiff::{Timestamp, civil::date, tz::{TimeZone, Disambiguation}};

// IDA: UTC (lo que reporta `date -u` / CLOCK_REALTIME) → hora del tenant
// Esta dirección SIEMPRE es exacta, nunca falla, nunca es ambigua.
let utc_instante: Timestamp = Timestamp::now(); // equivalente exacto a `date -u`
let tz_tenant = TimeZone::get("America/La_Paz")?;
let hora_tenant = utc_instante.to_zoned(tz_tenant.clone());
// "2026-07-15T05:00:00-04:00[America/La_Paz]" — conversión 1:1, sin pérdida

// VUELTA: hora del tenant → UTC
// Esta dirección puede ser ambigua (gap/fold) — jiff obliga a decidir la estrategia.
let civil = date(2026, 7, 15).at(10, 0, 0, 0);
let de_vuelta_a_utc = tz_tenant
    .to_ambiguous_zoned(civil)
    .disambiguate(Disambiguation::Reject)?;   // ver 10.7.3 sobre por qué Reject aquí
```

Nota clave: `jiff` documenta explícitamente que **no existe forma de que un "roundtrip" sea sin pérdida en ambas direcciones simultáneamente para todo par (hora civil, offset)** — por eso separa las dos operaciones (`to_zoned` para ida, `to_ambiguous_zoned` + estrategia de desambiguación para vuelta) en vez de pretender una sola función simétrica que "simplemente funcione siempre". Esto es justamente lo que hace que sea *robusto* en vez de solo *aparentemente reversible*.

### 10.7.3 Por qué para auditoría/trazabilidad la estrategia correcta es `Reject`, no adivinar

`jiff` ofrece cuatro estrategias cuando la vuelta (tenant → UTC) cae en una hora ambigua: `Compatible` (adivina según RFC 5545), `Earlier`, `Later`, y **`Reject`** (falla explícitamente en vez de adivinar). Para el propósito que describes — comparar con logs del sistema de forma confiable para auditoría — la recomendación es **`Reject`**: si el conversor recibe una hora del tenant que cae exactamente en el "fold" de un cambio de horario, es preferible que el conversor falle con un error explícito a que silenciosamente elija una de las dos horas UTC posibles y genere una correlación incorrecta con los logs del sistema. Un error explícito es auditable; una desambiguación silenciosa no lo es.

### 10.7.4 Diseño del conversor en `i18n-orchestrator`

```rust
pub struct TenantTimeConverter {
    tz: jiff::tz::TimeZone,
}

impl TenantTimeConverter {
    /// IDA: toma el instante real del sistema (equivalente a `date -u`,
    /// nunca alterado — sección 10.6.1) y lo expresa en hora del tenant.
    /// Siempre exacta, nunca falla.
    pub fn system_to_tenant(&self, utc: jiff::Timestamp) -> jiff::Zoned {
        utc.to_zoned(self.tz.clone())
    }

    /// VUELTA: toma una hora expresada en el tenant y la convierte al
    /// instante UTC real, para poder correlacionar con `date -u` / logs
    /// del sistema. Puede fallar explícitamente si la hora es ambigua
    /// (gap/fold) — nunca adivina en silencio.
    pub fn tenant_to_system(&self, civil: jiff::civil::DateTime)
        -> Result<jiff::Timestamp, AmbiguityError>
    {
        self.tz
            .to_ambiguous_zoned(civil)
            .disambiguate(jiff::tz::Disambiguation::Reject)
            .map(|z| z.timestamp())
            .map_err(AmbiguityError::from)
    }
}
```

```
i18nctl time to-tenant "2026-07-15T09:00:00Z" --tenant acme-sa
# → 2026-07-15T05:00:00-04:00[America/La_Paz]

i18nctl time to-system "2026-07-15T05:00:00" --tenant acme-sa
# → 2026-07-15T09:00:00Z   (idéntico al valor original: round-trip verificado)

i18nctl time to-system "2026-11-03T01:30:00" --tenant otro-tenant-con-dst
# → ERROR: hora ambigua (fold de DST) — se requiere desambiguación explícita
```

### 10.7.5 Por qué esto sí resuelve la comparación con logs del sistema, de forma garantizada

Como la dirección "sistema → tenant" (la que usarías para *mostrar* algo) es siempre exacta, y la dirección "tenant → sistema" (la que usarías para *correlacionar* con un log) falla explícitamente en el único caso donde podría ser incorrecta, el resultado es: **cualquier hora que el conversor acepte de vuelta hacia UTC es, por construcción, exactamente comparable con cualquier timestamp UTC de los logs del sistema** — porque ambos terminan siendo el mismo tipo de dato (`Timestamp`/instante), no una aproximación. No hay pérdida de precisión ni ambigüedad silenciosa en ningún punto del camino: o el round-trip es matemáticamente exacto, o el conversor te avisa que no puede serlo para ese caso puntual, en vez de fingir que sí.

---

## 11. Mapeo `display_format` → ICU4X + máscara (`format_map`)

El [Manual de Atributos v2.1.0](1.07_MANUAL-ATRIBUTOS-v2.0.md) define 18 códigos de
`display_format` para los atributos de identidad: `E164`, `EMAIL_RFC5321`, `TAX_BO`, `ID_BO`,
`DATE_ISO`, `MONEY`, `UUID`, `PASSPORT_ICAO`, `IPV4`, `ADDR_INTL`, `LOCALE_BCP47`,
`TIMEZONE_IANA`, `COORDENADAS_DD`, `URL`, `TAX_AR`, `TAX_BR_CPF`, `TAX_BR_CNPJ`, `NULL`.

El orquestador necesita un **mapa centralizado** que convierta cada código en tres artefactos
concretos, usables directamente por la capa de presentación sin que el consumidor sepa qué
librería hay detrás:

| Artefacto | Qué produce | Lo usa |
|---|---|---|
| **Patrón ICU4X** | Cómo formatea `icu::datetime` o `icu::decimal` el valor para presentación | Frontend, API responses, reportes |
| **Máscara de entrada** | Patrón de captura para formularios (`99/99/9999`, `+999 99 9999999`) | Dashboard, formularios de registro |
| **Máscara de display** | Cómo enmascarar en UI/logs para PII (`****321-LP`, `****78901234`) | Listados, logs no-auditoría |

### 11.1 Estructura del mapa

```rust
pub struct DisplayFormatSpec {
    /// Código del manual de atributos: "E164", "TAX_BO", "DATE_ISO", etc.
    pub code: String,
    /// Patrón ICU4X para presentación (usa ICU4X DateTimeFormatter o DecimalFormatter)
    pub icu_pattern: String,
    /// Máscara de entrada para formularios (caracteres: 9=dígito, A=letra, X=alfanumérico)
    pub input_mask: String,
    /// Granularidad para fechas (None si no es fecha)
    pub date_granularity: Option<DateGranularity>,
    /// Si requiere el locale del tenant para formatear (true para DATE_ISO, MONEY, NUMBER)
    pub locale_sensitive: bool,
    /// Si el valor debe enmascararse por defecto en UI
    pub masked_by_default: bool,
}
```

### 11.2 Catálogo base (18 códigos)

```toml
# format-map/base.toml — viene embebido en el crate, se extiende por país

[E164]
icu_pattern = "phone"                  # delega en libphonenumber para formato internacional
input_mask = "+999 99 9999999"
locale_sensitive = false
masked_by_default = false

[EMAIL_RFC5321]
icu_pattern = "plain"                  # no se formatea, se muestra tal cual
input_mask = "email"                   # máscara de email (teclado @, dominio)
locale_sensitive = false
masked_by_default = false

[TAX_BO]
icu_pattern = "plain"                  # NIT Bolivia: 0000-000000-000-00
input_mask = "9999-999999-999-99"
locale_sensitive = false
masked_by_default = true               # se enmascara por defecto: partial(4)

[ID_BO]
icu_pattern = "plain"                  # CI Bolivia: 0000000 LP
input_mask = "9999999-AA"
locale_sensitive = false
masked_by_default = true

[DATE_ISO]
icu_pattern = "date"                   # delega en ICU4X: dd/MM/yyyy (es-BO), MM/dd/yyyy (en-US)
input_mask = "99/99/9999"             # derivado automáticamente del patrón ICU4X
date_granularity = "Date"
locale_sensitive = true
masked_by_default = false

[DATETIME_ISO]
icu_pattern = "datetime"
input_mask = "99/99/9999 99:99"
date_granularity = "DateTime"
locale_sensitive = true
masked_by_default = false

[MONEY]
icu_pattern = "currency"               # delega en ICU4X: Bs. 1.500,00 (es-BO), $1,500.00 (en-US)
input_mask = "currency"               # derivado de ICU4X con símbolo de moneda
locale_sensitive = true
masked_by_default = false

[UUID]
icu_pattern = "plain"
input_mask = "hex-36"                  # 8-4-4-4-12 caracteres hexadecimales
locale_sensitive = false
masked_by_default = false

[PASSPORT_ICAO]
icu_pattern = "plain"
input_mask = "AA9999999"
locale_sensitive = false
masked_by_default = true

[IPV4]
icu_pattern = "plain"
input_mask = "999.999.999.999"
locale_sensitive = false
masked_by_default = false

[ADDR_INTL]
icu_pattern = "address"                # delega en country-rules TOML [postal]
input_mask = "address"                 # varía por país
locale_sensitive = true
masked_by_default = false

[LOCALE_BCP47]
icu_pattern = "plain"
input_mask = "aa-AA"                   # es-BO, en-US, pt-BR
locale_sensitive = false
masked_by_default = false

[TIMEZONE_IANA]
icu_pattern = "plain"
input_mask = "text"                    # America/La_Paz, Europe/Berlin
locale_sensitive = false
masked_by_default = false

[COORDENADAS_DD]
icu_pattern = "plain"
input_mask = "-99.999999, -999.999999"
locale_sensitive = false
masked_by_default = false

[URL]
icu_pattern = "plain"
input_mask = "url"
locale_sensitive = false
masked_by_default = false

[TAX_AR]
icu_pattern = "plain"                  # CUIT Argentina: 00-00000000-0
input_mask = "99-99999999-9"
locale_sensitive = false
masked_by_default = true

[TAX_BR_CPF]
icu_pattern = "plain"
input_mask = "999.999.999-99"
locale_sensitive = false
masked_by_default = true

[TAX_BR_CNPJ]
icu_pattern = "plain"
input_mask = "99.999.999/9999-99"
locale_sensitive = false
masked_by_default = true

[NULL]
icu_pattern = "plain"                  # texto libre, sin formato
input_mask = "text"
locale_sensitive = false
masked_by_default = false
```

### 11.3 API del módulo

```rust
// Obtener la especificación completa para un display_format
let spec = orch.format_spec("TAX_BO")?;
// → DisplayFormatSpec { code: "TAX_BO", input_mask: "9999-999999-999-99", ... }

// Generar máscara de entrada para un campo
let mask = orch.mask_for_display_format("DATE_ISO", &locale)?;
// → "99/99/9999" (es-BO: dd/MM/yyyy) | "99/99/9999" (en-US: MM/dd/yyyy)

// Formatear un valor según su display_format y locale
let formateado = orch.format_value("12345678901234", "TAX_BO", &locale)?;
// → "1234-567890-12-34" (presentación)

let enmascarado = orch.mask_value("12345678901234", "TAX_BO")?;
// → "****8901234" (PII, partial(4))
```

Los 18 códigos base vienen embebidos en el crate. Las variantes por país (`TAX_BO` distinto
de `TAX_AR` distinto de `TAX_BR_CPF`) se definen en el TOML de país y extienden o
sobrescriben el catálogo base.

---

## 12. Roadmap de construcción

| Fase | Alcance |
|---|---|
| **Fase 1 — Núcleo de locale, tiempo y formato** | `icu` (locale, decimal, currency) + `jiff` (instante/aritmética) detrás de `format::*` y `time::*`; soporte inicial 5-10 locales; `format_map` con los 18 códigos base de `display_format` (sección 11) |
| **Fase 2 — Mensajes y enums** | `fluent-bundle`; archivos `.ftl` con plurales/género; API `translate()`; `enum_display` para valores enum por locale (sección 7.1) |
| **Fase 3 — Configuración regional multi-tenant** | Trait `RegionalConfigResolver`, jerarquía usuario→sucursal→tenant→default (sección 10); hook de conexión que ejecuta `SET timezone` en cada conexión tomada del pool (sección 10.5-A) |
| **Fase 3.5 — Inyección de entorno universal por tenant** | Generador de archivos `TZ`/`LC_*` por tenant y su distribución vía `EnvironmentFile` de systemd / entrypoint de contenedor / PAM (sección 10.6.2) — deliberadamente separado de cualquier manipulación de `CLOCK_REALTIME` |
| **Fase 4 — Validación y reglas de país** | `validator` + `phonenumber`; registro extensible de reglas nacionales vía TOML expandido (sección 8): `[name]`, `[postal]`, `[vehicle.plate]`, `[bank]`, `[synonyms]`, `mask` en `[national_id.*]`; primer caso Bolivia |
| **Fase 5 — Máscaras** | Módulo `mask` derivando patrones desde `icu::decimal`/`icu::datetime`; `DateGranularity` para fechas parciales (sección 7.2); máscaras PII por tipo de documento desde TOML de país |
| **Fase 6 — Collation, Bidi y calendarios alternativos** | `icu::collator`, soporte Bidi, `icu::calendar` para tenants con calendario no gregoriano |
| **Fase 7 — CLI (`i18nctl`) + JSON-RPC daemon (`bi18nd`)** | Subcomandos `clap` sobre el mismo core (sección 9.1); daemon systemd con Interface Dual ADR-020: Unix socket `/run/bos/bi18n.sock` + JSON-RPC 2.0 (sección 9.2); 17 métodos en namespaces `bi18n.format`, `bi18n.validate`, `bi18n.mask`, `bi18n.locale`, `bi18n.enum`, `bi18n.rules`, `bi18n.attr`, `bi18n.collate` |
| **Fase 7.5 — API builder fluida para atributos** | Módulo `attr` con `AttrBuilder` (sección 9.3): pipeline `raw→validate→transform*→format→mask→localize`, 11 transformaciones, 6 estrategias de máscara, `AttrResult` con todas las representaciones del valor; método `bi18n.attr.pipeline` vía JSON-RPC |
| **Fase 8 — Empaquetado** | Publicación en crates.io, features opcionales (`fluent`, `validation`, `mask`, `cli`, `daemon`) |

---

## 13. Decisiones de diseño abiertas

- **Tamaño de binario:** ICU4X con todos los locales CLDR compilados es pesado; usar `icu4x-datagen --format mod` para incluir solo los locales declarados, como feature flag.
- **Fluent vs Unicode MessageFormat 2.0:** Fluent es la opción madura hoy; desacoplar el motor de mensajes detrás de un trait interno para poder migrar cuando el tooling de MessageFormat 2.0 en Rust madure.
- **Orden de nombre y formato postal** (sección 6): sin estándar único ni crate maduro — se resuelven vía el mismo registro extensible de país (sección 8), no como librería nueva.
- **Persistencia de `RegionalConfig`:** decisión delegada al consumidor del crate; el orquestador solo define el contrato.

---

## 14. Referencias

- ICU4X — https://icu4x.unicode.org
- Unicode CLDR — https://cldr.unicode.org
- Unicode UTS #35 (LDML) — https://unicode.org/reports/tr35/
- Unicode UAX #9 (Bidirectional Algorithm) — https://unicode.org/reports/tr9/
- Unicode UTS #10 (Collation Algorithm) — https://unicode.org/reports/tr10/
- Project Fluent — https://projectfluent.org
- `jiff` (comparación con chrono/time) — https://docs.rs/jiff/latest/jiff/_documentation/comparison/
- BCP 47 (IETF) — https://www.rfc-editor.org/info/bcp47
- ISO 8601 / RFC 3339 — https://www.rfc-editor.org/rfc/rfc3339
- ISO 4217 — https://www.iso.org/iso-4217-currency-codes.html
- ISO 3166 — https://www.iso.org/iso-3166-country-codes.html
- ITU-T E.164 — https://www.itu.int/rec/T-REC-E.164
- `phonenumber` crate — https://crates.io/crates/phonenumber
- `validator` crate — https://crates.io/crates/validator-rs
- `codes-iso-4217` crate — https://crates.io/crates/codes-iso-4217
- `clap` — https://docs.rs/clap/latest/clap/
- W3C Internationalization — https://www.w3.org/International/
- PostgreSQL — `TimeZone` como parámetro de sesión, no de servidor — https://www.cybertec-postgresql.com/en/time-zone-management-in-postgresql/
- Linux `time_namespaces(7)` (CLOCK_REALTIME no se virtualiza) — https://man7.org/linux/man-pages/man7/time_namespaces.7.html
- `libfaketime` (limitaciones documentadas) — https://github.com/wolfcw/libfaketime
- ISO/IEC 27001:2022 Anexo A 8.17 (Sincronización de relojes) — https://www.upguard.com/compliance/iso-27001/8-17
- `TZ` como variable de entorno (glibc, `tzset()`) — https://www.cyberciti.biz/faq/linux-unix-set-tz-environment-variable/
- `EnvironmentFile=` en unidades systemd — https://oneuptime.com/blog/post/2026-03-02-how-to-configure-systemd-service-environment-files-on-ubuntu/view
