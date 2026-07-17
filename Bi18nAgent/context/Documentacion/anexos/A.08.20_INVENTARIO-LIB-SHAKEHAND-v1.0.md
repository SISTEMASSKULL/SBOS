# A.08.20 — Inventario de Exposición: shakehand 0.1.3

**Crate:** `shakehand`
**Versión en Cargo.toml:** 0.1.3
**Archivo handler:** (infra compile-time — sin handler ni RPC)
**Categoría:** Infra compile-time — proc-macro que genera código de localización desde archivos TOML
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/shakehand-0.1.3/src/`

---

## Inventario completo de exposición

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `locale!(path)` — macro proc-macro principal | — | — | ❌ Compile-time |
| 2 | `Languages` enum — generado por la macro en el crate consumidor | — | — | ❌ Compile-time |
| 3 | `set_lang(lang: Languages)` — generado por la macro | — | — | ❌ Compile-time |
| 4 | `lang() -> Languages` — generado por la macro | — | — | ❌ Compile-time |
| 5 | `FallbackSolver::try_fallback_once(lang)` — generado por la macro | — | — | ❌ Compile-time |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Compile-time — genera código en tiempo de compilación; no tiene runtime API exportada

---

## Notas de implementación

- shakehand es un **proc-macro puro** — no exporta tipos ni funciones en runtime. Todo su output existe en el crate consumidor, no en shakehand mismo.
- La macro `locale!("path/to/locales/")` lee los archivos TOML en el path indicado y genera:
  - Un enum `Languages` con una variante por cada locale encontrado
  - Una función `set_lang(lang: Languages)` para cambiar el locale activo
  - Una función `lang() -> Languages` para consultar el locale activo
  - `FallbackSolver::try_fallback_once(lang)` para intentar un fallback si la clave no existe en el locale actual
- shakehand no genera métodos RPC y no debe aparecer en el dispatcher.
- Su rol en bi18n: complementa a rust-i18n para la gestión compile-time de los locales disponibles.

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: REGISTRO-ESTADO-DOS.md Bloque C (infra) · no genera archivos handler*
