# A.08.15 — Inventario de Exposición: validy 1.2.4

**Crate:** `validy`
**Versión en Cargo.toml:** 1.2.4
**Archivo handler:** (infra de handlers — sin handler propio)
**Categoría:** Infra interna — validación y modificación de campos con derive macros
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/validy-1.2.4/src/`

---

## Inventario completo de exposición

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `#[derive(Validate)]` con atributos de validación en structs de handler | — | — | ❌ Infra interna |
| 2 | `#[derive(Modificate)]` con atributos de transformación (trim, lowercase, etc.) | — | — | ❌ Infra interna |
| 3 | `#[validate(email)]` / `[validate(url)]` / `[validate(pattern(...))]` | — | — | ❌ Infra interna |
| 4 | `#[validate(length(min=N, max=N))]` | — | — | ❌ Infra interna |
| 5 | `#[validate(range(min=N, max=N))]` | — | — | ❌ Infra interna |
| 6 | `#[modificate(trim)]` / `[modificate(lowercase)]` / `[modificate(uppercase)]` | — | — | ❌ Infra interna |
| 7 | `#[modificate(strip_prefix="...")]` / `[modificate(strip_suffix="...")]` | — | — | ❌ Infra interna |
| 8 | `trait Validate::validate(&self) -> Result<(), ValidationErrors>` | — | — | ❌ Infra interna |
| 9 | `trait Modificate::modificate(&mut self)` | — | — | ❌ Infra interna |
| 10 | `FailureMode::FailFast` / `FailOncePerField` / `LastFailPerField` / `FullFail` | — | — | ❌ Infra interna |
| 11 | `ValidationErrorBuilder` / `ValidationSettings` | — | — | ❌ Infra interna |
| 12 | 22 traits adicionales de validación por campo | — | — | ❌ Infra interna |
| 13 | 35+ funciones de parsing/modificación en módulo functions | — | — | ❌ Infra interna |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Infra interna — no se expone por RPC

---

## Notas de implementación

- validy es **exclusivamente infraestructura interna** — no genera métodos RPC.
- Su rol: decorar los DTOs de entrada de los handlers con `#[validate(...)]` y `#[modificate(...)]` para que el dispatcher rechace parámetros inválidos antes de llegar al handler.
- Ejemplo de uso típico en un handler:
  ```rust
  #[derive(Deserialize, Validate, Modificate)]
  struct LocaleParams {
      #[modificate(trim, lowercase)]
      #[validate(pattern(pattern = r"^[a-z]{2}-[A-Z]{2}$"))]
      locale: String,
      ctx_id: String,
  }
  ```
- validy complementa a validator y scrutiny: estos exponen capacidades por RPC; validy las aplica internamente en los DTOs.
- No crear `lib_validy.rs` — validy se usa como derive en los módulos que lo necesitan.

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: REGISTRO-ESTADO-DOS.md Bloque Ω · uso transversal en src/server/handlers/*
