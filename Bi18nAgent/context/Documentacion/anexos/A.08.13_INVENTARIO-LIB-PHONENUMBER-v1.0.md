# A.08.13 — Inventario de Exposición: phonenumber 0.3.10

**Crate:** `phonenumber`
**Versión en Cargo.toml:** `0.3.10+9.0.33`
**Archivo handler:** `src/server/handlers/lib_phonenumber.rs`
**Categoría:** Teléfonos internacionales — parsing, validación, formateo (ITU-T E.164)
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/phonenumber-0.3.10+9.0.33/src/`

⚠️ El enum de tipo se llama `Type` (no `PhoneNumberType`). El método es `number_type(&database)` (no `get_number_type()`). `is_viable` toma un string, no un PhoneNumber.

---

## Inventario completo de exposición

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `phonenumber::parse(region, phone_str)?.format().mode(Mode::E164).to_string()` | `bi18n.phone.parse_e164` | 2 | 📋 Fase 2 |
| 2 | `phonenumber::is_valid(&num)` | `bi18n.validate.phone` ✅ | 1 | ✅ Implementado |
| 3 | `num.format().mode(Mode::International).to_string()` | `bi18n.phone.format` | 2 | 📋 Fase 2 |
| 4 | `num.number_type(&database) -> Type` | `bi18n.phone.type` | 2 | 📋 Fase 2 |
| 5 | `phonenumber::is_viable(raw_str: S)` ⚠️ (toma string, no PhoneNumber) | `bi18n.phone.is_viable` | 2 | 📋 Fase 2 |
| 6 | combinación de campos del PhoneNumber parseado | `bi18n.phone.info` | 2 | 📋 Fase 2 |
| 7 | `num.format().mode(Mode::National).to_string()` | `bi18n.phone.parse_national` | 2 | 📋 Fase 2 |
| 8 | `num.format().mode(Mode::Rfc3966).to_string()` | `bi18n.phone.parse_rfc3966` | 2 | 📋 Fase 2 |
| 9 | `num.code().code() -> u16` (código numérico del país) | `bi18n.phone.country_code` | 2 | 📋 Fase 2 |
| 10 | `phonenumber::parse(None, phone_str)` — sin región (requiere `+`) | — | — | ❌ Infra interna |
| 11 | `num.national() -> &NationalNumber` | — | — | ❌ Infra interna |
| 12 | `num.code() -> &country::Code` | — | — | ❌ Infra interna |
| 13 | `num.extension() -> Option<&Extension>` | — | — | 🔮 Futuro |
| 14 | `num.carrier() -> Option<&Carrier>` | — | — | 🔮 Futuro |
| 15 | `num.format().mode(Mode::E164)` / `International` / `National` / `Rfc3966` | — | — | ❌ Infra interna |
| 16 | `phonenumber::is_valid_with(&num, validation)` | — | — | 🔮 Futuro |
| 17 | `enum Type` — 17 variantes: FixedLine, Mobile, Voip, TollFree, etc. | — | — | ❌ Infra interna |
| 18 | `enum Mode` — 4 variantes: E164, International, National, Rfc3966 | — | — | ❌ Infra interna |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Infra interna — no se expone por RPC

---

## Notas de implementación

- `bi18n.validate.phone` ya existe en Fase 1 (usa `phonenumber::is_valid`). Los 8 métodos nuevos de Fase 2 amplían la cobertura.
- `bi18n.phone.info` retorna: `{"valid": bool, "viable": bool, "type": "Mobile", "e164": "+59171234567", "national": "71234567", "country_code": 591}`.
- `bi18n.phone.type` requiere cargar `phonenumber::metadata::DATABASE` — costoso en memoria, inicializar una sola vez al arrancar el daemon.
- `bi18n.phone.is_viable` recibe el string crudo (e.g. `"+59171234567"`), NO el `PhoneNumber` parseado — esta es la firma real: `is_viable<S: AsRef<str>>(string: S) -> bool`.
- `num.code()` retorna `&country::Code` cuyo método `.code()` retorna `u16` (código numérico, e.g. 591 para Bolivia).
- `num.national()` retorna `&NationalNumber` (no `national_number()`) — diferencia de nombre confirmada en source.

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: REGISTRO-ESTADO-DOS.md Bloque N · src/server/handlers/lib_phonenumber.rs*
