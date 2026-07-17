# PLAN DE IMPLEMENTACIÓN — FASE 2
## Exposición de 22 librerías como métodos JSON-RPC — bi18n (i18n-orchestrator)

**Versión:** 1.0.0
**Fecha:** 2026-07-17
**Estado:** ACTIVO — en ejecución
**Fuentes:** REGISTRO-ESTADO-DOS v3.0.0 · Anexos A.08.01–A.08.22 · INDICE v1.9.0

---

## Principio rector

**Un anexo = una librería = un handler Rust.**

Cada librería de `Cargo.toml` tiene:
1. Un inventario de exposición `A.08.XX` — define qué se expone y qué es infra interna
2. Un archivo handler dedicado `src/server/handlers/lib_<nombre>.rs` — implementa solo los métodos RPC de esa librería
3. Arms en `src/server/dispatcher.rs` — registra los métodos en el dispatcher central

Los handlers se implementan **en orden de anexo** — A.08.01 primero, A.08.14 último.
Los anexos A.08.15–A.08.22 son infraestructura interna: 0 métodos RPC, no generan handler.

---

## Mapa completo: anexo → handler → métodos RPC

| Orden | Anexo | Librería | Handler Rust | RPC nuevos | Estado |
|:-----:|-------|----------|--------------|:----------:|:------:|
| 1 | A.08.01 | `fluent-bundle 0.15.3` | `lib_fluent.rs` | 6 | ✅ Implementado |
| 2 | A.08.02 | `rust-i18n 4.x` | `lib_rust_i18n.rs` | 4 | ✅ Implementado |
| 3 | A.08.03 | `icu_datetime 2.2.0` | `lib_icu_datetime.rs` | 6 | ✅ Implementado |
| 4 | A.08.04 | `icu_locale_core 2.2.0` | `lib_icu_locale.rs` | 4 | ✅ Implementado |
| 5 | A.08.05 | `icu_decimal 2.2.0` | `lib_icu_decimal.rs` | 4 | ✅ Implementado |
| 6 | A.08.06 | `validator 0.19.0` | `lib_validator.rs` | 12 | ⏳ Pendiente |
| 7 | A.08.07 | `scrutiny 0.1.2` | `lib_scrutiny.rs` | 4 | ⏳ Pendiente |
| 8 | A.08.08 | `mask-pii 0.2.0` | `lib_mask_pii.rs` + FIX `mask.rs:81` | 4 | ⏳ Pendiente |
| 9 | A.08.09 | `universal_mask 0.1.0` | `lib_universal_mask.rs` | 5 | ⏳ Pendiente |
| 10 | A.08.10 | `jiff 0.2.32` | `lib_jiff.rs` | 18 | ⏳ Pendiente |
| 11 | A.08.11 | `chrono 0.4.45` | `lib_chrono.rs` | 15 | ⏳ Pendiente |
| 12 | A.08.12 | `regex 1.13.1` | `lib_regex.rs` | 6 | ⏳ Pendiente |
| 13 | A.08.13 | `phonenumber 0.3.10` | `lib_phonenumber.rs` | 8 | ⏳ Pendiente |
| 14 | A.08.14 | `prism3-core 0.2.0` | `lib_prism3.rs` | 12 | ⏳ Pendiente |
| — | A.08.15 | `validy 1.2.4` | — (derive macro, 0 RPC) | 0 | ❌ Sin handler |
| — | A.08.16 | `valida 1.1.2` | — (RulesBuilder, 0 RPC) | 0 | ❌ Sin handler |
| — | A.08.17 | `clipass_rs 0.1.0` | — (solo bi18nctl CLI) | 0 | ❌ Sin handler |
| — | A.08.18 | `arc-swap 1.9.2` | — (ya impl. Fase 1) | 0 | ✅ Fase 1 |
| — | A.08.19 | `notify 6.1.1` | — (ya impl. Fase 1) | 0 | ✅ Fase 1 |
| — | A.08.20 | `shakehand 0.1.3` | — (proc-macro compile-time) | 0 | ❌ Sin handler |
| — | A.08.21 | `veil 0.3.0` | — (derive macro de logs) | 0 | ❌ Sin handler |
| — | A.08.22 | `serde_with 3.21.0` | — (adaptadores serde) | 0 | ❌ Sin handler |
| | **TOTAL** | | **14 handlers nuevos** | **108** | |

---

## Protocolo de trabajo — un handler por vez

Para cada anexo A.08.XX con métodos RPC (órdenes 1–14):

```
1. LEER el inventario A.08.XX — entender qué métodos expone y cuáles son internos
2. CREAR src/server/handlers/lib_<nombre>.rs
   - Encabezado doc: propósito, librería, métodos expuestos, dependencias
   - Una función pública por método RPC del inventario
   - Nombre de función: snake_case del método RPC (bi18n.translate.message → translate_message)
   - Sin unwrap() — Result<Value, Bi18nError> en todo
   - Sin clone() innecesario
   - ≤ 200 líneas por archivo
3. REGISTRAR en src/server/dispatcher.rs
   - Agregar arms en el bloque correspondiente al namespace (translate, i18n, format, validate…)
   - Sin cambiar la lógica de validación de ctx_id existente
4. REGISTRAR en src/server/handlers/mod.rs
   - pub mod lib_<nombre>;
5. COMPILAR — cargo check (evidencia obligatoria C12)
6. ACTUALIZAR el inventario A.08.XX — cambiar 📋 → ✅ en los métodos implementados
7. ACTUALIZAR la tabla de tracking de este plan
8. COMMIT con mensaje: "feat(bi18n): A.08.XX lib_<nombre> — N métodos RPC"
```

---

## Convención de naming de métodos RPC

| Namespace | Handler | Patrón de método |
|-----------|---------|-----------------|
| `bi18n.translate.*` | `lib_fluent.rs` | A.08.01 |
| `bi18n.i18n.*` | `lib_rust_i18n.rs` | A.08.02 |
| `bi18n.format.datetime_icu` · `date_icu` · `time_icu` · `weekday_name` · `month_name` · `datetime_with_time` | `lib_icu_datetime.rs` | A.08.03 |
| `bi18n.locale.parse_bcp47` · `canonicalize` · `negotiate` · `subtags` | `lib_icu_locale.rs` | A.08.04 |
| `bi18n.format.number_icu` · `number_no_grouping` · `number_grouping_always` · `number_grouping_min2` | `lib_icu_decimal.rs` | A.08.05 |
| `bi18n.validate.email_html5` · `url` · `ip` · `ipv4` · `ipv6` · `length` · `range` · `contains` · `does_not_contain` · `regex_match` · `required` · `must_match` | `lib_validator.rs` | A.08.06 |
| `bi18n.validate.from_json` · `struct_errors` · `ulid` · `hex_color` | `lib_scrutiny.rs` | A.08.07 |
| `bi18n.mask.email_in_text` · `phone_in_text` · `pii_in_text` · `pii_with_char` | `lib_mask_pii.rs` | A.08.08 |
| `bi18n.format.structural_mask` · `mask_ssn` · `mask_card` · `mask_date_iso` · `mask_ci_bo` | `lib_universal_mask.rs` | A.08.09 |
| `bi18n.datetime.now_utc` · `now_tz` · `parse_jiff` · `format_jiff` · `add_span` · `sub_span` · `diff_span` · `convert_tz` · `from_unix` · `round` · `days_in_month` · `is_leap_year` · `first_of_month` · `nth_weekday` · `series` · `span_total` · `tz_info` · `weekday_of_date` | `lib_jiff.rs` | A.08.10 |
| `bi18n.datetime.chrono_*` (15 métodos) | `lib_chrono.rs` | A.08.11 |
| `bi18n.text.regex_match` · `regex_extract` · `regex_extract_all` · `regex_match_set` · `regex_split` · `regex_replace` | `lib_regex.rs` | A.08.12 |
| `bi18n.phone.format` · `type` · `is_viable` · `info` · `parse_e164` · `parse_national` · `parse_rfc3966` · `country_code` | `lib_phonenumber.rs` | A.08.13 |
| `bi18n.guard.*` (12 métodos) | `lib_prism3.rs` | A.08.14 |

---

## Estructura del dispatcher por namespace

El dispatcher `src/server/dispatcher.rs` agrupa los arms por namespace. La Fase 2 agrega:

```
Existentes (Fase 1):
  bi18n.health.* · bi18n.locale.resolve · bi18n.validate.{email,phone,national_id}
  bi18n.mask.{value,pii} · bi18n.format.{date,number,money} · bi18n.enum.display
  bi18n.regional.snapshot · bi18n.attr.* · bi18n.admin.*

Nuevos (Fase 2):
  bi18n.translate.*      → lib_fluent.rs         (A.08.01 — 6 arms)
  bi18n.i18n.*           → lib_rust_i18n.rs      (A.08.02 — 4 arms)
  bi18n.format.*_icu     → lib_icu_datetime.rs   (A.08.03 — 6 arms)
  bi18n.locale.*         → lib_icu_locale.rs     (A.08.04 — 4 arms)
  bi18n.format.number_*  → lib_icu_decimal.rs    (A.08.05 — 4 arms)
  bi18n.validate.*       → lib_validator.rs      (A.08.06 — 12 arms)
  bi18n.validate.*       → lib_scrutiny.rs       (A.08.07 — 4 arms)
  bi18n.mask.*           → lib_mask_pii.rs       (A.08.08 — 4 arms)
  bi18n.format.*_mask    → lib_universal_mask.rs (A.08.09 — 5 arms)
  bi18n.datetime.*       → lib_jiff.rs           (A.08.10 — 18 arms)
  bi18n.datetime.chrono_*→ lib_chrono.rs         (A.08.11 — 15 arms)
  bi18n.text.*           → lib_regex.rs          (A.08.12 — 6 arms)
  bi18n.phone.*          → lib_phonenumber.rs    (A.08.13 — 8 arms)
  bi18n.guard.*          → lib_prism3.rs         (A.08.14 — 12 arms)
```

---

## Tabla de progreso (actualizar tras cada commit)

| Orden | Handler | Métodos | Commit | Estado |
|:-----:|---------|:-------:|--------|:------:|
| 1 | `lib_fluent.rs` | 6 | `143fb19` | ✅ |
| 2 | `lib_rust_i18n.rs` | 4 | pendiente commit | ✅ |
| 3 | `lib_icu_datetime.rs` | 6 | `3930f53`+1 | ✅ |
| 4 | `lib_icu_locale.rs` | 4 | pendiente commit | ✅ |
| 5 | `lib_icu_decimal.rs` | 4 | pendiente commit | ✅ |
| 6 | `lib_validator.rs` | 12 | `a2b988b` | ✅ |
| 7 | `lib_scrutiny.rs` | 6 | `701bdd7` | ✅ |
| 8 | `lib_mask_pii.rs` + FIX | 3+FIX | `1cb3445` | ✅ |
| 9 | `lib_universal_mask.rs` | 5 | `739e6e1` | ✅ |
| 10 | `lib_jiff.rs` | 17 | `1e353f4` | ✅ |
| 11 | `lib_chrono.rs` | 10 | `0e0f370` | ✅ |
| 12 | `lib_regex.rs` | 6 | `5caad2e` | ✅ |
| 13 | `lib_phonenumber.rs` | 8 | `88f6361` | ✅ |
| 14 | `lib_prism3.rs` | 12 | `af243d3` | ✅ |
| **—** | **Acumulado** | **108** | | |

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-17 | Plan inicial. Formaliza el protocolo de trabajo, el mapa A.08.XX→handler, la convención de naming y la tabla de progreso. |
