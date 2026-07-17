# A.08.08 — Inventario de Exposición: mask-pii 0.2.0

**Crate:** `mask-pii`
**Versión en Cargo.toml:** 0.2.0
**Archivo handler:** `src/server/handlers/lib_mask_pii.rs`
**Categoría:** Enmascaramiento PII — emails y teléfonos en texto libre
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/mask-pii-0.2.0/src/`

---

## Inventario completo de exposición

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `Masker::new().mask_emails().process(input)` | `bi18n.mask.email_in_text` | 2 | 📋 Fase 2 |
| 2 | `Masker::new().mask_phones().process(input)` | `bi18n.mask.phone_in_text` | 2 | 📋 Fase 2 |
| 3 | `Masker::new().mask_emails().mask_phones().process(input)` | `bi18n.mask.pii` | 2 | 📋 Fase 2 |
| 4 | `Masker::new().with_mask_char('X').mask_emails().process(input)` | `bi18n.mask.pii_with_char` | 2 | 📋 Fase 2 |
| 5 | `Masker::new()` constructor | — | — | ❌ Infra interna |
| 6 | `Masker::mask_emails(mut self)` builder | — | — | ❌ Infra interna |
| 7 | `Masker::mask_phones(mut self)` builder | — | — | ❌ Infra interna |
| 8 | `Masker::with_mask_char(mut self, c: char)` builder | — | — | ❌ Infra interna |
| 9 | `Masker::process(&self, input: &str) -> String` | — | — | ❌ Infra interna |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Infra interna — no se expone por RPC

---

## Notas de implementación

- **FIX OBLIGATORIO**: `src/server/handlers/mask.rs:81` contiene un `TODO` con regex manual — debe reemplazarse por `Masker::new().mask_emails().mask_phones().process(texto_entrada)`. Este fix es Prioridad 1 (P1) antes de cualquier implementación nueva.
- Comportamiento verificado de `Masker`:
  - **Emails**: 1er carácter del local-part visible + `mask_char` × resto + `@dominio.tld` intacto. Ejemplo: `alice@corp.com` → `a****@corp.com`.
  - **Teléfonos**: últimos 4 dígitos visibles, todo lo anterior → `mask_char`. Ejemplo: `+59171234567` → `*******4567`.
- La crate **NO exporta**: `mask_ips()`, `mask_ssn()`, `mask_credit_cards()`, `mask_urls()`, `mask_names()` — confirmado en source.
- Los 4 métodos RPC cubren el 100% de la API pública de la librería — no hay más funciones expuestas.

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: REGISTRO-ESTADO-DOS.md Bloque I · src/server/handlers/lib_mask_pii.rs*
