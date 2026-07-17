# A.08.16 — Inventario de Exposición: valida 1.1.2

**Crate:** `valida`
**Versión en Cargo.toml:** 1.1.2
**Archivo handler:** (infra de handlers — sin handler propio)
**Categoría:** Infra interna — RulesBuilder para validación de DTOs con mensajes i18n
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/valida-1.1.2/src/`

---

## Inventario completo de exposición

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `RulesBuilder::<T,E>::new()` | — | — | ❌ Infra interna |
| 2 | `FieldBuilder::email(msg)` / `.url(msg)` / `.uuid(msg)` | — | — | ❌ Infra interna |
| 3 | `FieldBuilder::min_length(n, msg)` / `.max_length(n, msg)` | — | — | ❌ Infra interna |
| 4 | `FieldBuilder::regex_match(pattern, msg)` | — | — | ❌ Infra interna |
| 5 | `FieldBuilder::greater_than(v, msg)` / `.less_than(v, msg)` / `.range(min, max, msg)` | — | — | ❌ Infra interna |
| 6 | `FieldBuilder::positive(msg)` / `.negative(msg)` | — | — | ❌ Infra interna |
| 7 | `FieldBuilder::each(rules)` / `.min_items(n, msg)` / `.max_items(n, msg)` | — | — | ❌ Infra interna |
| 8 | `FieldBuilder::custom(fn, msg)` / `.custom_async(fn, msg)` | — | — | ❌ Infra interna |
| 9 | `ValidationErrors::to_json()` / `.to_json_form()` / `.to_json_dot()` / `.pretty_print()` | — | — | ❌ Infra interna |
| 10 | `StrengthLevel` enum / `UuidVersion` enum | — | — | ❌ Infra interna |
| 11 | 6 wrappers de anidamiento (nested validation) | — | — | ❌ Infra interna |
| 12 | Feature `i18n` — integración con rust-i18n para mensajes en el locale activo | — | — | ❌ Infra interna |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Infra interna — no se expone por RPC

---

## Notas de implementación

- valida es **exclusivamente infraestructura interna** — no genera métodos RPC.
- Su rol: construir reglas de validación complejas para DTOs de configuración del daemon con mensajes de error en el locale activo (via feature `i18n` que integra con rust-i18n).
- Ejemplo de uso típico para validar un DTO de configuración:
  ```rust
  let errors = RulesBuilder::new()
      .field("locale", &params.locale)
          .email("validate-email-error")
          .min_length(3, "validate-length-error")
      .build()
      .validate()?;
  ```
- Los mensajes de error usan las claves FTL definidas en `locales/es-BO/main.ftl` — se resuelven en el locale del request.
- La diferencia con validy: valida se usa para reglas complejas programáticas; validy se usa para reglas simples declarativas via derive.
- No crear `lib_valida.rs` — valida se usa como herramienta en los handlers que necesiten validación compleja.

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: REGISTRO-ESTADO-DOS.md Bloque Ω · uso transversal en src/server/handlers/*
