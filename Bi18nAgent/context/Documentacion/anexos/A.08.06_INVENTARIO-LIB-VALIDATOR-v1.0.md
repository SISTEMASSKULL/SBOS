# A.08.06 — Inventario de Exposición: validator 0.19.0

**Crate:** `validator`
**Versión en Cargo.toml:** 0.19.0
**Archivo handler:** `src/server/handlers/lib_validator.rs`
**Categoría:** Validación de tipos y formatos estándar
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/validator-0.19.0/src/`

⚠️ **Cambio de API en 0.19**: NO hay funciones libres `validate_email(s)`, `validate_url(s)`, etc. En 0.19 son **traits**. La única función libre restante es `validate_must_match`.

---

## Inventario completo de exposición

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `trait ValidateEmail::validate_email(&self)` | `bi18n.validate.email_html5` | 2 | ✅ Implementado |
| 2 | `trait ValidateUrl::validate_url(&self)` | `bi18n.validate.url` | 2 | ✅ Implementado |
| 3 | `trait ValidateIp::validate_ip(&self)` | `bi18n.validate.ip` | 2 | ✅ Implementado |
| 4 | `trait ValidateIp::validate_ipv4(&self)` | `bi18n.validate.ipv4` | 2 | ✅ Implementado |
| 5 | `trait ValidateIp::validate_ipv6(&self)` | `bi18n.validate.ipv6` | 2 | ✅ Implementado |
| 6 | `trait ValidateLength::validate_length(min, max, equal)` | `bi18n.validate.length` | 2 | ✅ Implementado |
| 7 | `trait ValidateRange<f64>::validate_range(min, max, excl_min, excl_max)` | `bi18n.validate.range` | 2 | ✅ Implementado |
| 8 | `trait ValidateContains::validate_contains(needle)` | `bi18n.validate.contains` | 2 | ✅ Implementado |
| 9 | `trait ValidateDoesNotContain::validate_does_not_contain(needle)` | `bi18n.validate.not_contains` | 2 | ✅ Implementado |
| 10 | `trait ValidateRequired::validate_required(&self)` (sobre Option) | `bi18n.validate.required` | 2 | ✅ Implementado |
| 11 | `trait ValidateCreditCard::validate_credit_card(&self)` (feature card) | `bi18n.validate.credit_card` | 2 | ✅ Implementado |
| 12 | `fn validate_must_match<T: Eq>(a, b)` — única función libre | `bi18n.validate.must_match` | 2 | ✅ Implementado |
| 13 | `trait ValidateNonControlCharacter::validate_non_control_character(&self)` | — | — | 🔮 Futuro |
| 14 | `trait ValidateRegex::validate_regex(&self, regex)` | — | — | 🔮 Futuro |
| 15 | `trait AsRegex::as_regex(&self)` | — | — | ❌ Infra interna |
| 16 | `#[derive(Validate)]` con atributos (email, url, length, range, etc.) | — | — | ❌ Infra interna |
| 17 | `trait Validate::validate(&self) -> Result<(), ValidationErrors>` | — | — | ❌ Infra interna |
| 18 | `trait ValidateArgs::validate_with_args(&self, args)` | — | — | ❌ Infra interna |
| 19 | `ValidationError { code, message, params }` | — | — | ❌ Infra interna |
| 20 | `ValidationErrors` / `ValidationErrorsKind` | — | — | ❌ Infra interna |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Infra interna — no se expone por RPC

---

## Notas de implementación

- Todos los métodos RPC reciben `ctx_id` + `value` (string) y retornan `{"valid": bool, "error?": "mensaje FTL"}`.
- `bi18n.validate.email_html5` — valida según HTML5 spec (NO RFC 5322, más permisivo).
- `bi18n.validate.length` recibe `min?`, `max?`, `equal?` — todos opcionales.
- `bi18n.validate.range` recibe `min?`, `max?` como números — aplica a valores numéricos.
- `bi18n.validate.must_match` recibe `value1` y `value2` — retorna `{"match": bool}`.
- `ValidateNonControlCharacter` y `ValidateRegex` marcados 🔮 Futuro — útiles pero no en plan actual.
- El `#[derive(Validate)]` se usa internamente en los DTOs de los handlers, no se expone.

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: REGISTRO-ESTADO-DOS.md Bloque G · src/server/handlers/lib_validator.rs*
