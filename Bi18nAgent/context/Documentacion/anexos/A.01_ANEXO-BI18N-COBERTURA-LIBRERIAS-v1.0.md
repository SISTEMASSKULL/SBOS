# A.01 — Cobertura de Librerías del Orquestador bi18n

**Tipo:** D — verificación de librerías existentes y su cobertura
**Versión del anexo:** 2.1.0
**Fecha:** 2026-07-16
**Respalda a:** [1.01 (bi18n Arquitectura)](../1.01_MANUAL-BI18N-ARQUITECTURA-v1.0.md) · [1.07 (Atributos v2.0)](../../../BauthAgent/context/Documentacion/1.07_MANUAL-ATRIBUTOS-v2.0.md) · [2.15 (Motor Identidad)](../../../BauthAgent/context/Documentacion/2.15_MANUAL-MOTOR-IDENTIDAD-v1.0.md)
**Fuentes:** crates.io · docs.rs · GitHub · verificaciones 2026-07-16

---

## §1 Propósito

Este anexo lista **todas** las librerías Rust que bi18n orquesta, agrupadas por necesidad.
Cobertura: **100%.** Cada necesidad tiene al menos una librería asignada.
No hay gaps de librería — lo que falta son datos declarativos por país (TOML).

---

## §2 Mapa completo de cobertura

### §2.1 Traducción (i18n)

| Librería | Versión | Rol |
|---|---|---|
| `fluent` / `fluent-bundle` | 0.16 | Motor de mensajes con plurales y género (Project Fluent, camino a Unicode MessageFormat 2.0) |
| `rust-i18n` | 4.0 | Traducción tipo-safe con derive macros, archivos YAML/JSON/TOML, fallback en cadena |
| `shakehand` | — | Traducción en tiempo de compilación desde TOML, genera enum Languages |

### §2.2 Fechas, horas y cálculo temporal

| Librería | Versión | Rol |
|---|---|---|
| `jiff` | 0.2.32 | Cálculo temporal zone-aware. IANA tzdata completa (596 zonas) compilada. Reemplazo de `moment.js`. |
| `icu_datetime` | 2.2 | Presentación de fecha/hora localizada vía CLDR (1000+ locales) |
| `chrono` | 0.4 | Workhorse histórico. Integración masiva con `sqlx`, `serde`. Requiere `chrono-tz` para IANA. |

### §2.3 Formatos regionales (CLDR)

| Librería | Versión | Rol |
|---|---|---|
| `icu_locale_core` | 2.2 | Validación BCP 47. Parseo de locale. Tipo `DataLocale`. |
| `icu_datetime` | 2.2 | Formato fecha/hora con patrones CLDR |
| `icu_decimal` | 2.2 | Formato de números con separadores por locale |
| `prism3-core` | 0.2.0 | Validación de argumentos con API fluida: rangos, patrones, constraints |

### §2.4 Validación de atributos

| Librería | Versión | Rol |
|---|---|---|
| `valida` | 1.1.2 | Validación con derive macros (`#[Validatable]`, `#[validate(email, min_length(5))]`). Soporta i18n (10 idiomas), anidamiento, async, JSON/árbol de errores. |
| `validy` | 1.2.4 | Validación, modificación y parsing con derive macros (`#[derive(Validate)]`). Reglas: email, length, pattern, url, ip, range. Modificaciones: trim, lowercase, snake_case. Integración con Axum. |
| `validator` | 0.19 | Validación de propósito general: email, URL, longitud, rango, regex, crédito. |
| `scrutiny` | 0.1 | Validación de reglas de negocio (usado en bAuth). |
| `phonenumber` | 0.3 | Validación E.164 vía Google libphonenumber (200+ países). |
| `prism3-core` | 0.2.0 | Validación de argumentos con chequeo de estado y bounds. |
| `regex` | 1.x | Validación de documentos nacionales contra patrones TOML. |

### §2.5 Enmascaramiento PII

| Librería | Versión | Rol |
|---|---|---|
| `mask-pii` | 0.2.0 | Enmascaramiento de emails y teléfonos. Builder pattern: `.mask_emails().mask_phones()`. |
| `veil` | 0.3.0 | Redacción de campos sensibles en logs (`#[derive(Redact)]`, `#[redact(partial)]`). 116k descargas/mes. |
| `universal_mask` | 0.1.0 | Formateo de datos con máscara estructural: SSN `XXX-XX-XXXX`, teléfono `(XXX) XXX-XXXX`. |

### §2.6 Máscaras de entrada (UI)

| Librería | Versión | Rol |
|---|---|---|
| `rat-input` | 0.16 | Widget `MaskedInput` para **TUI/CLI interactivo únicamente** (ratatui). Patrones: `99/99/9999`, `+999 99 9999999`. **No cubre frontends de UI real** (web, Flutter, nativos) — esa cobertura la da el adapter por plataforma documentado en A.02 §3.5. |
| `clipass_rs` | 0.1.0 | Lectura enmascarada para CLI (contraseñas, tokens). |

### §2.7 Serialización

| Librería | Versión | Rol |
|---|---|---|
| `serde` + `serde_json` | 1.x | Serialización JSON para JSON-RPC 2.0 |
| `serde_with` | 3.x | Anotaciones avanzadas de serde: formatos de fecha, base64, máscaras en serialización |
| `toml` | 0.8 | Lectura de country-rules/*.toml y bi18n.toml |

### §2.8 Catálogo de referencia (SBOS)

| Fuente | Tipo | Rol |
|---|---|---|
| `bglobal.global_country` | PostgreSQL | 196 países: ISO, calling codes, moneda, idiomas, timezones |
| `bglobal.global_language` | PostgreSQL | Locale BCP 47, ISO 639, dirección LTR/RTL, nombres multi-idioma |
| `bglobal.global_currency` | PostgreSQL | 143 monedas: símbolo local, símbolo intl, decimales, nombres JSONB |
| `bglobal.geo_timezone` | PostgreSQL | 319 zonas IANA: UTC offset, DST, ciudad principal |

### §2.9 Datos declarativos por país (TOML)

Estos NO son gaps de librería — son **datos** que ningún estándar internacional define.
Cada país los define por su cuenta. bi18n los carga desde `country-rules/{iso}.toml`.

| Sección TOML | Qué contiene | Ejemplo Bolivia |
|---|---|---|
| `[national_id.*]` | Patrón regex, máscara de entrada, estrategia PII | CI: `^\d{7,8}(-[A-Z]{2})?$` · NIT: `^\d{7,14}$` |
| `[postal]` | Campos de dirección ordenados por país | Calle/Número → Zona → Municipio → Departamento |
| `[vehicle]` | Patrón regex de placa, máscara de entrada | `^\d{4}-[A-Z]{3}$` → `1234-ABC` |
| `[synonyms]` | Sinónimos regionales para fuzzy search | `farol = ["foco", "optica", "luz_delantera"]` |
| `[enum_display]` | Traducción de enums de negocio por locale | `gender.M = "Masculino"` (es-BO) |

---

## §3 Resumen: 9 categorías, 23 librerías, 0 gaps

| Categoría | Librerías | Cobertura |
|---|---|---|
| Traducción | fluent, rust-i18n, shakehand | 100% |
| Fechas y horas | jiff, icu_datetime, chrono | 100% |
| Formatos regionales | icu_locale_core, icu_datetime, icu_decimal, prism3-core | 100% |
| Validación | valida, validator, scrutiny, phonenumber, prism3-core, regex | 100% |
| Enmascaramiento PII | mask-pii, veil, universal_mask | 100% |
| Máscaras de entrada (TUI/CLI) | rat-input, clipass_rs | 100% |
| Serialización | serde, serde_with, toml | 100% |
| Catálogo referencia | bglobal (4 tablas PostgreSQL) | 100% |
| Datos por país | country-rules/*.toml (5 secciones) | 100% |

---

## §4 Estado de materialización

| Librería | Estado | Cargo.toml |
|---|---|---|
| icu_locale_core 2.2 | ✅ Verificada | `icu_locale_core = "2"` |
| icu_datetime 2.2 | ✅ Verificada | `icu_datetime = "2"` |
| icu_decimal 2.2 | ✅ Verificada | `icu_decimal = "2"` |
| jiff 0.2.32 | ✅ Verificada | `jiff = { version = "0.2", features = ["tzdb-bundle-platform", "serde"] }` |
| phonenumber 0.3 | ✅ Verificada | `phonenumber = "0.3"` |
| regex 1.x | ✅ Verificada | `regex = "1"` |
| fluent 0.16 | ✅ Verificada | `fluent = "0.16"` |
| rust-i18n 4.0 | ✅ Verificada | `rust-i18n = "4"` |
| validator 0.19 | ✅ Verificada | `validator = "0.19"` |
| veil 0.3 | ✅ Verificada | `veil = "0.3"` |
| mask-pii 0.2 | ✅ Verificada | `mask-pii = "0.2"` |
| universal_mask 0.1 | ✅ Verificada | `universal_mask = "0.1"` |
| valida 1.1 | ✅ Verificada | `valida = "1.1"` |
| scrutiny 0.1 | ✅ Verificada | `scrutiny = "0.1"` |
| serde_with 3.x | ✅ Verificada | `serde_with = "3"` |
| prism3-core 0.2 | ✅ Verificada | `prism3-core = "0.2"` |
| chrono 0.4 | ✅ Verificada | `chrono = { version = "0.4", features = ["serde"] }` |
| rat-input 0.16 | ✅ Verificada | `rat-input = "0.16"` |
| serde 1.x + toml 0.8 + clap 4.x + tokio 1.x + tracing 0.1 + thiserror 2 | ✅ | Stack común SBOS |

---

## Historial

| Versión | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-16 | Anexo inicial. 17 necesidades, 12 cubiertas, 5 gaps. |
| 2.0.0 | 2026-07-16 | Cobertura 100%. 23 librerías verificadas. 0 gaps. Datos por país en TOML (no son gaps de librería). |
| 2.1.0 | 2026-07-16 | Reclasificado `rat-input` como cobertura exclusiva TUI/CLI (no frontend UI). Agregado `validy` 1.2.4 a validación. Corregida fuente de monedas: `bglobal` (ICU4X no tiene soporte de monedas). |
