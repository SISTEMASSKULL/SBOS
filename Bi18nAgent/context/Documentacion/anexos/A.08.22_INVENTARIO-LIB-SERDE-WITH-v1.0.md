# A.08.22 — Inventario de Exposición: serde_with 3.21.0

**Crate:** `serde_with`
**Versión en Cargo.toml:** 3.21.0
**Archivo handler:** (infra compile-time — sin handler ni RPC)
**Categoría:** Infra compile-time — adaptadores de serialización serde para tipos especiales
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/serde_with-3.21.0/src/`

---

## Inventario completo de exposición

### Macros / atributos

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `#[serde_as]` — atributo de módulo para activar `as = "..."` en campos | — | — | ❌ Compile-time |
| 2 | `#[skip_serializing_none]` — omite campos `Option::None` en JSON | — | — | ❌ Compile-time |
| 3 | `serde_conv!` macro — define conversores personalizados inline | — | — | ❌ Compile-time |

### Conversores de timestamps y duraciones

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 4 | `TimestampSeconds` / `TimestampMilliSeconds` / `TimestampMicroSeconds` / `TimestampNanoSeconds` | — | — | ❌ Infra interna |
| 5 | `TimestampSecondsWithFrac` / `TimestampMilliSecondsWithFrac` | — | — | ❌ Infra interna |
| 6 | `DurationSeconds` / `DurationMilliSeconds` / `DurationMicroSeconds` / `DurationNanoSeconds` | — | — | ❌ Infra interna |
| 7 | `DurationSecondsWithFrac` / `DurationMilliSecondsWithFrac` | — | — | ❌ Infra interna |

### Conversores de encoding y formato

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 8 | `Base64` / `Hex` — serializar bytes como base64 o hex | — | — | ❌ Infra interna |
| 9 | `JsonString` — serializar `T` embebido como string JSON | — | — | ❌ Infra interna |
| 10 | `KeyValueMap` — serializar map como lista de `{key, value}` | — | — | ❌ Infra interna |
| 11 | `EnumMap` — serializar enum variant como map | — | — | ❌ Infra interna |
| 12 | `OneOrMany` — deserializar T o Vec\<T\> indistintamente | — | — | ❌ Infra interna |
| 13 | `StringWithSeparator` — Vec serializado como string delimitado | — | — | ❌ Infra interna |

### Conversores de control de flujo

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 14 | `DefaultOnError` / `DefaultOnNull` — valor por defecto ante error/null | — | — | ❌ Infra interna |
| 15 | `SetPreventDuplicates` / `MapPreventDuplicates` — error en duplicados | — | — | ❌ Infra interna |
| 16 | `VecSkipError` / `MapSkipError` — ignorar elementos inválidos | — | — | ❌ Infra interna |
| 17 | `BoolFromInt` — deserializar 0/1 como bool | — | — | ❌ Infra interna |

### Conversores de transformación

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 18 | `FromInto<T>` / `TryFromInto<T>` — conversión via From/TryFrom | — | — | ❌ Infra interna |
| 19 | `WithPrefix` / `WithSuffix` — añadir prefijo/sufijo a claves | — | — | ❌ Infra interna |
| 20 | `Uppercase` / `Lowercase` — transformar strings al serializar | — | — | ❌ Infra interna |
| 21 | `Strict` / `Flexible` / `Padded` — formatos de tiempo estricto/flexible | — | — | ❌ Infra interna |
| 22 | `CommaSeparator` / `SemicolonSeparator` / `SpaceSeparator` / `ColonSeparator` | — | — | ❌ Infra interna |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Compile-time — funciona vía atributos serde; no tiene API RPC
- ❌ Infra interna — no se expone por RPC

---

## Notas de implementación

- serde_with es **infraestructura de serialización interna** — no genera métodos RPC.
- Su rol: controlar cómo los tipos Rust se serializan a JSON en las respuestas RPC.
- Uso planificado en Fase 2 (P5 del REGISTRO):
  ```rust
  #[serde_as]
  #[derive(Serialize)]
  struct DatetimeResponse {
      #[serde_as(as = "TimestampSeconds<i64>")]
      unix: i64,
      #[serde_as(as = "Option<_>")]
      #[skip_serializing_none]
      formatted: Option<String>,
  }
  ```
- `TimestampSeconds` es el conversor más relevante para bi18n: permite serializar `jiff::Timestamp` o `chrono::DateTime` directamente como Unix timestamp i64 sin conversión manual.
- `DefaultOnNull` es útil para campos opcionales en respuestas donde `null` debe tratarse como valor por defecto.

## Estado de integración

Integrado en `1ab009d` — `#[serde_as]` + `#[skip_serializing_none]` aplicados en
`ParseBcp47Resp` de `src/server/handlers/lib_icu_locale.rs`. Los campos `script: Option<String>`
y `region: Option<String>` se omiten del JSON cuando son `None` en lugar de emitir `null`.
`cargo check`: 0 errores. Nota: `TimestampSeconds` para tipos de fecha queda como Fase 3
(requiere feature `chrono_0_4` en `serde_with`).

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: src/server/handlers/lib_icu_locale.rs*
