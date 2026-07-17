# A.08.14 — Inventario de Exposición: prism3-core 0.2.0

**Crate:** `prism3-core`
**Versión en Cargo.toml:** 0.2.0
**Archivo handler:** `src/server/handlers/lib_prism3.rs`
**Categoría:** Guardas / Precondiciones — validación de argumentos en runtime con mensajes precisos
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/prism3-core-0.2.0/src/`

---

## Inventario completo de exposición

### Funciones standalone

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `check_bounds(offset, length, total_length)` | `bi18n.guard.check_bounds` | 2 | 📋 Fase 2 |
| 2 | `check_element_index(index, size)` | `bi18n.guard.check_element_index` | 2 | 📋 Fase 2 |
| 3 | `check_position_index(index, size)` | `bi18n.guard.check_position_index` | 2 | 📋 Fase 2 |
| 4 | `require_equal(name1, v1, name2, v2)` / `require_not_equal(...)` | `bi18n.guard.num_compare` | 2 | 📋 Fase 2 |
| 5 | `check_argument(condition)` | — | — | ❌ Infra interna |
| 6 | `check_argument_with_message(condition, msg)` | — | — | ❌ Infra interna |
| 7 | `check_argument_fmt(condition, message)` | — | — | ❌ Infra interna |
| 8 | `check_state(condition)` / `check_state_with_message(condition, msg)` | — | — | ❌ Infra interna |
| 9 | `check_position_indexes(start, end, size)` | — | — | 🔮 Futuro |
| 10 | `require_element_non_null(name, collection)` | — | — | 🔮 Futuro |
| 11 | `require_null_or(name, value, predicate, error_msg)` | — | — | 🔮 Futuro |

### Trait NumericArgument

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 12 | `value.require_positive(name)` | `bi18n.guard.num_positive` | 2 | 📋 Fase 2 |
| 13 | `value.require_non_negative(name)` | `bi18n.guard.num_non_negative` | 2 | 📋 Fase 2 |
| 14 | `value.require_in_closed_range(name, min, max)` | `bi18n.guard.num_in_range` | 2 | 📋 Fase 2 |
| 15 | `value.require_zero(name)` | — | — | 🔮 Futuro |
| 16 | `value.require_non_zero(name)` | — | — | 🔮 Futuro |
| 17 | `value.require_negative(name)` | — | — | 🔮 Futuro |
| 18 | `value.require_non_positive(name)` | — | — | 🔮 Futuro |
| 19 | `value.require_less(name, max)` | — | — | 🔮 Futuro |
| 20 | `value.require_less_equal(name, max)` | — | — | 🔮 Futuro |
| 21 | `value.require_greater(name, min)` | — | — | 🔮 Futuro |
| 22 | `value.require_greater_equal(name, min)` | — | — | 🔮 Futuro |
| 23 | `value.require_in_open_range(name, min, max)` | — | — | 🔮 Futuro |
| 24 | `value.require_in_left_open_range(name, min, max)` | — | — | 🔮 Futuro |
| 25 | `value.require_in_right_open_range(name, min, max)` | — | — | 🔮 Futuro |

### Trait StringArgument

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 26 | `s.require_non_blank(name)` | `bi18n.guard.str_non_blank` | 2 | 📋 Fase 2 |
| 27 | `s.require_length_in_range(name, min, max)` | `bi18n.guard.str_length_range` | 2 | 📋 Fase 2 |
| 28 | `s.require_match(name, &regex)` | `bi18n.guard.str_match` | 2 | 📋 Fase 2 |
| 29 | `s.require_length_be(name, length)` | — | — | 🔮 Futuro |
| 30 | `s.require_length_at_least(name, min)` | — | — | 🔮 Futuro |
| 31 | `s.require_length_at_most(name, max)` | — | — | 🔮 Futuro |
| 32 | `s.require_not_match(name, &regex)` | — | — | 🔮 Futuro |

### Trait CollectionArgument

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 33 | `col.require_non_empty(name)` | `bi18n.guard.col_non_empty` | 2 | 📋 Fase 2 |
| 34 | `col.require_length_in_range(name, min, max)` | `bi18n.guard.col_length_range` | 2 | 📋 Fase 2 |
| 35 | `col.require_length_be(name, length)` | — | — | 🔮 Futuro |
| 36 | `col.require_length_at_least(name, min)` | — | — | 🔮 Futuro |
| 37 | `col.require_length_at_most(name, max)` | — | — | 🔮 Futuro |

### Trait OptionArgument / Tipos utilitarios

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 38 | `opt.require_non_null(name)` | — | — | ❌ Infra interna |
| 39 | `Pair<F,S>` / `Triple<F,S,T>` structs | — | — | ❌ Infra interna |
| 40 | `DataType` enum (16 variantes) | — | — | ❌ Infra interna |
| 41 | `ArgumentError::new(msg)` / `ArgumentResult<T>` | — | — | ❌ Infra interna |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Infra interna — no se expone por RPC

---

## Notas de implementación

- 12 métodos RPC en Fase 2 cubren los casos más frecuentes: bounds, element index, comparación numérica, rangos, strings, colecciones.
- Las 15+ funciones 🔮 Futuro del trait NumericArgument son candidatas Fase 3 — ya disponibles sin dependencias adicionales.
- `check_argument` / `check_state` son infra interna — se usan dentro de handlers para validar precondiciones internas, no como servicios RPC.
- `ArgumentResult<T> = Result<T, ArgumentError>` — el handler mapea los errores a mensajes FTL (`guard-*-error`).
- `Pair<F,S>` y `Triple<F,S,T>` son tipos utilitarios genéricos — no tienen sentido como RPC standalone.

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: REGISTRO-ESTADO-DOS.md Bloque Ω · src/server/handlers/lib_prism3.rs*
