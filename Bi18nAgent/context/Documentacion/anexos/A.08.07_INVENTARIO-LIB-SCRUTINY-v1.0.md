# A.08.07 — Inventario de Exposición: scrutiny 0.1.2

**Crate:** `scrutiny`
**Versión en Cargo.toml:** 0.1.2
**Archivo handler:** `src/server/handlers/lib_scrutiny.rs`
**Categoría:** Validación estructural exhaustiva — 50+ funciones standalone + derive
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/scrutiny-0.1.2/src/`

---

## Inventario completo de exposición

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `is_uuid(value)` | `bi18n.validate.uuid` | 2 | ✅ Implementado |
| 2 | `is_ulid(value)` | `bi18n.validate.ulid` | 2 | ✅ Implementado |
| 3 | `is_mac_address(value)` | `bi18n.validate.mac_address` | 2 | ✅ Implementado |
| 4 | `is_hex_color(value)` | `bi18n.validate.hex_color` | 2 | ✅ Implementado |
| 5 | `from_json::<T>(bytes)` / `deserialize_json::<T>(bytes)` | — | — | ❌ Infra interna |
| 6 | `is_email(value)` | — | — | 🔮 Futuro (cubierto por validator) |
| 7 | `is_url(value)` | — | — | 🔮 Futuro (cubierto por validator) |
| 8 | `is_ip(value)` / `is_ipv4(value)` / `is_ipv6(value)` | — | — | 🔮 Futuro (cubierto por validator) |
| 9 | `is_timezone(value)` | `bi18n.validate.timezone` | 2 | ✅ Implementado |
| 10 | `is_json(value)` | `bi18n.validate.is_json` | 2 | ✅ Implementado |
| 11 | `is_ascii(value)` | — | — | 🔮 Futuro |
| 12 | `is_alpha(value)` | — | — | 🔮 Futuro |
| 13 | `is_alpha_num(value)` | — | — | 🔮 Futuro |
| 14 | `is_alpha_dash(value)` | — | — | 🔮 Futuro |
| 15 | `is_uppercase(value)` | — | — | 🔮 Futuro |
| 16 | `is_lowercase(value)` | — | — | 🔮 Futuro |
| 17 | `is_integer(value)` | — | — | 🔮 Futuro |
| 18 | `is_numeric(value)` | — | — | 🔮 Futuro |
| 19 | `is_filled(value)` | — | — | 🔮 Futuro |
| 20 | `starts_with(value, prefix)` | — | — | 🔮 Futuro |
| 21 | `ends_with(value, suffix)` | — | — | 🔮 Futuro |
| 22 | `doesnt_start_with(value, prefix)` | — | — | 🔮 Futuro |
| 23 | `doesnt_end_with(value, suffix)` | — | — | 🔮 Futuro |
| 24 | `contains(value, needle)` | — | — | 🔮 Futuro |
| 25 | `doesnt_contain(value, needle)` | — | — | 🔮 Futuro |
| 26 | `matches_regex(value, pattern)` | — | — | 🔮 Futuro |
| 27 | `not_matches_regex(value, pattern)` | — | — | 🔮 Futuro |
| 28 | `is_in(value, list)` | — | — | 🔮 Futuro |
| 29 | `is_not_in(value, list)` | — | — | 🔮 Futuro |
| 30 | `is_same(a, b)` / `is_different(a, b)` | — | — | 🔮 Futuro |
| 31 | `is_distinct(values)` | — | — | 🔮 Futuro |
| 32 | `is_in_array(value, array)` | — | — | 🔮 Futuro |
| 33 | `is_gt(a, b)` / `is_gte(a, b)` / `is_lt(a, b)` / `is_lte(a, b)` | — | — | 🔮 Futuro |
| 34 | `is_accepted(value)` / `is_accepted_bool(value)` | — | — | 🔮 Futuro |
| 35 | `is_declined(value)` / `is_declined_bool(value)` | — | — | 🔮 Futuro |
| 36 | `is_multiple_of(value, n)` | — | — | 🔮 Futuro |
| 37 | `is_iso_date(value)` | — | — | 🔮 Futuro |
| 38 | `is_iso_datetime(value)` | — | — | 🔮 Futuro |
| 39 | `is_after(value, other)` / `is_after_or_equal(value, other)` | — | — | 🔮 Futuro |
| 40 | `is_before(value, other)` / `is_before_or_equal(value, other)` | — | — | 🔮 Futuro |
| 41 | `is_date_equals(value, other)` | — | — | 🔮 Futuro |
| 42 | `is_present_option(value)` | — | — | 🔮 Futuro |
| 43 | `check_min(value, min)` / `check_max(value, max)` | — | — | 🔮 Futuro |
| 44 | `check_between(value, min, max)` | — | — | 🔮 Futuro |
| 45 | `check_min_length(value, min)` / `check_max_length(value, max)` | — | — | 🔮 Futuro |
| 46 | `check_between_length(value, min, max)` | — | — | 🔮 Futuro |
| 47 | `check_size(value, size)` | — | — | 🔮 Futuro |
| 48 | `check_digits(value, count)` / `check_digits_between(value, min, max)` | — | — | 🔮 Futuro |
| 49 | `check_decimal(value, min_places, max_places)` | — | — | 🔮 Futuro |
| 50 | `trait Validate::validate(&self)` + `#[derive(Validate)]` | — | — | ❌ Infra interna |
| 51 | `ValidationError::new(rule, message).with_param(k, v)` | — | — | ❌ Infra interna |
| 52 | `ValidationErrors::messages()` / `first_messages()` / `field_errors()` | — | — | ❌ Infra interna |
| 53 | `FieldValue` enum (Str/Integer/Float/Bool/Null/Array) | — | — | ❌ Infra interna |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Infra interna — no se expone por RPC

---

## Notas de implementación

- Fase 2 expone los 6 métodos más diferenciadores de scrutiny (uuid, ulid, mac, hex_color, timezone, json) — los que validator no cubre.
- Las funciones que duplican validator (`is_email`, `is_url`, `is_ip`) marcadas 🔮 Futuro para evitar métodos RPC redundantes.
- Las 35+ funciones 🔮 Futuro son candidatas para una Fase 3 de validación exhaustiva — están todas disponibles en el crate sin ninguna dependencia adicional.
- `from_json`/`deserialize_json` son infra interna: se usan para parsear los DTOs de entrada en handlers.

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: REGISTRO-ESTADO-DOS.md Bloque H · src/server/handlers/lib_scrutiny.rs*
