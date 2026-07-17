# A.08.17 — Inventario de Exposición: clipass_rs 0.1.0

**Crate:** `clipass_rs`
**Versión en Cargo.toml:** 0.1.0
**Archivo handler:** `src/bin/bi18nctl.rs` (CLI — no es un handler RPC)
**Categoría:** CLI — lectura segura de contraseñas en terminal (solo para bi18nctl)
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/clipass_rs-0.1.0/src/`

⚠️ NO hay funciones libres `read_password()`, `verify_hash()` — la API es a través del struct `CliPass`. Verificado en source.

---

## Inventario completo de exposición

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `CliPass::new()` | — | — | ❌ Solo CLI |
| 2 | `CliPass::set_prompt_label(label)` | — | — | ❌ Solo CLI |
| 3 | `CliPass::set_no_label(label)` | — | — | ❌ Solo CLI |
| 4 | `CliPass::set_no_visibility(bool)` | — | — | ❌ Solo CLI |
| 5 | `CliPass::set_prompt_mask_token(token)` | — | — | ❌ Solo CLI |
| 6 | `CliPass::launch_prompt() -> io::Result<String>` | — | — | ❌ Solo CLI |
| 7 | `CliPass::hash_sha256_internal()` | — | — | ❌ Solo CLI |
| 8 | `CliPass::hash_sha256_external()` | — | — | ❌ Solo CLI |
| 9 | `CliPass::hash_md5_internal()` | — | — | ❌ Solo CLI |
| 10 | `CliPass::hash_md5_external()` | — | — | ❌ Solo CLI |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Solo CLI — no se expone por RPC; uso exclusivo en `bi18nctl`
- ❌ Infra interna — no se expone por RPC

---

## Notas de implementación

- clipass_rs **no genera métodos RPC** — su uso es exclusivo de `bi18nctl` para autenticar operaciones administrativas desde terminal.
- Flujo típico en `bi18nctl`:
  ```rust
  use clipass_rs::CliPass;
  let mut session = CliPass::new();
  session.set_prompt_label("Contraseña admin: ");
  session.set_no_visibility(true);
  session.set_prompt_mask_token("*");
  let password = session.launch_prompt()?;
  let hash = session.hash_sha256_internal();
  // Comparar hash contra ServidorConfig.admin_hash
  ```
- **No existe `verify_hash()`** en la librería — la verificación se hace comparando el hash producido por `hash_sha256_internal()` contra el hash almacenado.
- Los métodos de hash (`hash_sha256_internal`, `hash_sha256_external`, `hash_md5_internal`, `hash_md5_external`) son métodos de instancia en `CliPass`, no funciones libres.
- El daemon bi18n valida el hash de admin contra `ServidorConfig.admin_hash` sin generar tokens de sesión.
- **API verificada en fuente** — correcciones críticas confirmadas:
  - `set_no_visibility()` — **NO toma `bool`**, es sin parámetros (el ejemplo del anexo era incorrecto)
  - `set_prompt_mask_token('*')` — espera `char`, **NO** `&str`

## Estado de integración

Integrado en `1ab009d` — subcomando `Admin` agregado en `src/bin/i18nctl.rs` con
función `ejecutar_admin()`. Lee contraseña con `CliPass`, genera hash con
`hash_sha256_internal()` y lo envía como `admin_token` al daemon. `cargo check`: 0 errores.

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: src/bin/i18nctl.rs · src/config/mod.rs (admin_hash)*
