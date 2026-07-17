# A.08.09 — Inventario de Exposición: universal_mask 0.1.0

**Crate:** `universal_mask`
**Versión en Cargo.toml:** 0.1.0
**Archivo handler:** `src/server/handlers/lib_universal_mask.rs`
**Categoría:** Máscaras estructurales — formateo posicional de strings (CI, RUC, tarjetas, teléfonos)
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/universal_mask-0.1.0/src/`

---

## Inventario completo de exposición

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `mask(text, "(XXX) XXX-XXXX")` — máscara teléfono US | `bi18n.format.structural_mask` | 2 | 📋 Fase 2 |
| 2 | `mask(text, "XX.XXX.XXX/XXXX-XX")` — máscara CNPJ Brasil | `bi18n.format.mask_cnpj` | 2 | 📋 Fase 2 |
| 3 | `mask(text, "XXX.XXX.XXX-XX")` — máscara CPF Brasil | `bi18n.format.mask_cpf` | 2 | 📋 Fase 2 |
| 4 | `mask(text, "XXXX-XXXX-XXXX-XXXX")` — máscara tarjeta crédito | `bi18n.format.mask_card` | 2 | 📋 Fase 2 |
| 5 | `mask(text, "XXXXXXX|XXXXXXXX")` — máscara CI Bolivia (7 u 8 dígitos) | `bi18n.format.mask_ci_bo` | 2 | 📋 Fase 2 |
| 6 | `pub fn mask(text: &str, format_patterns: &str) -> String` — función base | — | — | ❌ Infra interna |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Infra interna — no se expone por RPC

---

## Notas de implementación

- La librería exporta **una sola función pública**: `mask(text, format_patterns)`.
- Semántica del patrón:
  - `X` → consume y emite el siguiente carácter del input
  - Cualquier otro carácter → emite ese carácter literalmente (separador: `-`, `/`, `.`, espacio, `(`, `)`)
  - `|` → separa patrones alternativos; elige el que tenga más `X` sin exceder la longitud del input
  - Desbordamiento: caracteres sobrantes descartados silenciosamente (warning a stderr, no panic)
- Los 5 métodos RPC son atajos con patrones fijos para los formatos más usados en el ecosistema SBOS (BO/AR/BR).
- `bi18n.format.structural_mask` es el método genérico: recibe `text` y `pattern` arbitrario — permite cualquier máscara personalizada.
- No hay función inversa de desenmascarado en la librería.

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: REGISTRO-ESTADO-DOS.md Bloque J · src/server/handlers/lib_universal_mask.rs*
