# A.08.21 — Inventario de Exposición: veil 0.3.0

**Crate:** `veil`
**Versión en Cargo.toml:** 0.3.0
**Archivo handler:** (infra compile-time — sin handler ni RPC)
**Categoría:** Infra compile-time — derive macro que redacta campos sensibles en logs/debug
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/veil-0.3.0/src/`

---

## Inventario completo de exposición

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `#[derive(Redact)]` — derive para structs que se imprimen en logs | — | — | ❌ Compile-time |
| 2 | `#[derive(Redactable)]` — derive para tipos que pueden ser redactados | — | — | ❌ Compile-time |
| 3 | `#[redact]` — atributo en campo: redacta con `[REDACTED]` | — | — | ❌ Compile-time |
| 4 | `#[redact(partial)]` — muestra primeros/últimos N chars | — | — | ❌ Compile-time |
| 5 | `#[redact(fixed)]` — siempre muestra longitud fija | — | — | ❌ Compile-time |
| 6 | `#[redact(hash)]` — muestra hash SHA del valor | — | — | ❌ Compile-time |
| 7 | `#[redact(skip)]` — no redactar este campo | — | — | ❌ Compile-time |
| 8 | `#[redact(with = "...")]` — carácter de redacción personalizado | — | — | ❌ Compile-time |
| 9 | `#[redact(variant)]` — redacta nombre de variante enum | — | — | ❌ Compile-time |
| 10 | `#[redact(all)]` — redactar todos los campos del struct | — | — | ❌ Compile-time |
| 11 | `Redactor` struct — `redact(value)` / `redact_in_place(value)` | — | — | ❌ Infra interna |
| 12 | `RedactorBuilder` — configuración del redactor | — | — | ❌ Infra interna |
| 13 | `RedactWrapped<T>` — wrapper que redacta el Display | — | — | ❌ Infra interna |
| 14 | `disable()` — desactiva la redacción globalmente (feature toggle) | — | — | ❌ Infra interna |
| 15 | `RedactionBehavior` enum | — | — | ❌ Infra interna |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Compile-time — funciona en tiempo de compilación vía derive; no tiene API RPC
- ❌ Infra interna — no se expone por RPC

---

## Notas de implementación

- veil es **infraestructura de seguridad interna** — no genera métodos RPC.
- Su rol: garantizar que campos sensibles de `ServidorConfig` (contraseñas, tokens, hashes admin) nunca aparezcan en logs de tracing/debug, cumpliendo ISO 27001 A.8.15.
- Uso planificado en Fase 2 (P5 del REGISTRO):
  ```rust
  #[derive(Debug, Serialize, Deserialize, Redact)]
  pub struct ServidorConfig {
      pub socket_path: String,
      #[redact(partial)]
      pub admin_hash: String,   // muestra primeros 8 chars + [REDACTED]
      #[redact]
      pub vault_token: String,  // [REDACTED] completo
  }
  ```
- La redacción afecta solo al output de `Debug`/`Display` — el valor real permanece accesible para el código.
- **API verificada en fuente** — comportamiento confirmado:
  - `#[derive(Redact)]` **reemplaza** `#[derive(Debug)]` — genera `impl Debug` con redacción
  - Si se pone `Debug` Y `Redact` en el mismo derive, habrá conflicto (Debug duplicado)
  - La sintaxis `#[derive(Clone, Serialize, Deserialize, veil::Redact)]` es correcta

## Estado de integración

Integrado en `1ab009d` — `#[derive(veil::Redact)]` aplicado en `ServidorConfig` de
`src/config/mod.rs`. Campos `admin_hash: Option<String>` (`#[redact(partial)]`) y
`vault_token: Option<String>` (`#[redact]`) agregados. `cargo check`: 0 errores.

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: src/config/mod.rs*
