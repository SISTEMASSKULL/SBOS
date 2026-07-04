# SBOS-060 — ESTÁNDAR DE DOCUMENTACIÓN DE CÓDIGO
## Nivel DOC-SBOS-001 · N3 ("Némesis Nivel 3")

**Versión:** 1.0 · **Fecha:** 2026-06-19 · **Estado:** VIGENTE
**Ámbito:** TODO el código del ecosistema SBOS (BosAgent, BkernelAgent, BauthAgent, BiedataAgent, BintelligenceAgent, BnexusAgent, InfraAgent)
**Idioma:** Español obligatorio (regla inmutable del proyecto)

---

## 1. Nombre del estándar

**DOC-SBOS-001 · N3 ("Némesis Nivel 3")**

"Némesis" porque es implacable con el código indocumentado. "Nivel 3" porque
define 3 niveles de profundidad de documentación.

---

## 2. Los 3 niveles de documentación

### N1 — Cabecera de módulo (mínimo obligatorio)

Todo archivo `.rs`, `.go`, `.sh`, `.py`, `.yml` debe tener una cabecera que explique:

```rust
//! Nombre del módulo — qué hace (una línea).
//!
//! # Propósito
//! Explicación de 2-3 líneas del rol de este módulo en la arquitectura.
//!
//! # Flujo de datos
//! De dónde vienen los datos, qué transformación sufren, a dónde van.
//!
//! # Referencias
//! - SBOS-XXX · norma aplicable
//! - ADR-XXX · decisión de arquitectura relacionada
```

### N2 — Funciones y structs documentados

Toda función pública (`pub fn`, `pub async fn`) debe tener `///` con:

```rust
/// Breve descripción de lo que hace (una línea).
///
/// # Parámetros
/// * `param1` — Tipo y propósito.
/// * `param2` — Tipo y propósito.
///
/// # Retorna
/// Descripción del valor de retorno y su significado.
///
/// # Errores
/// `Err(BkernelError::XXX)` si ocurre tal condición.
```

Todo struct público debe tener `///` en el struct y en CADA campo:

```rust
/// Descripción del struct y su rol.
pub struct MiStruct {
    /// Descripción del campo. De dónde viene, qué valores puede tener.
    pub campo: Tipo,
}
```

### N3 — Arquitectura y contexto (nivel excelencia)

El módulo `mod.rs` o el archivo principal debe documentar:

```rust
//! ── Arquitectura ───────────────────────────────────────────
//! Diagrama de flujo y relación entre submódulos.
//!
//! ── Submódulos ─────────────────────────────────────────────
//! mod x: descripción de una línea de qué hace.
//!
//! ── Re-exportaciones ───────────────────────────────────────
//! TipoReexportado: quién lo usa, para qué, de dónde viene.
```

---

## 3. Reglas no negociables

| # | Regla | Consecuencia |
|---|-------|-------------|
| R1 | **Español obligatorio.** Ningún comentario `//` o `///` en inglés. | Código rechazado en revisión. |
| R2 | **N1 es mínimo.** Ningún archivo sin cabecera de propósito. | El build CI falla (gate de documentación). |
| R3 | **N2 para todo `pub`.** Toda función pública sin `///` es un bug. | Bloquea el merge. |
| R4 | **N3 en `mod.rs` raíz de cada subsistema.** | Requerido para aceptar el módulo. |
| R5 | **Parámetros, retorno y errores siempre.** `///` sin `# Parámetros` está incompleto. | Marcado como `TODO(docs)` en revisión. |
| R6 | **Valores hardcodeados extraídos.** Números mágicos → constantes con nombre. | Violación de R16 (Zero Hardcoding). |
| R7 | **Modularidad.** Sin archivos monolíticos de >500 líneas sin buena razón. | Refactorización requerida. |

---

## 4. Ejemplo canónico: server/mod.rs (DOC-SBOS-001 N3)

```rust
//! Servidor JSON-RPC 2.0 para bkernel-daemon (G2.E1.T2).
//! ADR-020: Interface Dual — gRPC + JSON-RPC sobre Unix socket /run/bos/bkernel.sock.
//! SBOS-050 P9: SIN HTTP entre daemons — solo Unix socket.
//!
//! Este módulo expone el registro de destinos (DestinationRegistry) a través de
//! una interfaz JSON-RPC 2.0. Otros daemons (biedata, agentes IA) y el CLI
//! (bosctl) invocan estos métodos para administrar los destinos de enrutamiento
//! sin necesidad de conectarse directamente a PostgreSQL.
//!
//! El pool de conexiones PostgreSQL se inyecta en BkernelRpc desde main.rs
//! durante la inicialización del daemon.
//!
//! Flujo de una llamada RPC:
//!   Cliente → Unix socket → BkernelRpc::dispatch() → DestinationRegistry → PostgreSQL
//!
//! Métodos expuestos:
//!   bkernel.dest.add     — Registrar nuevo destino (INSERT/upsert)
//!   bkernel.dest.list    — Listar todos los destinos
//!   ...

pub mod jsonrpc;

// BkernelRpc: manejador principal. Recibe el pool PostgreSQL de main.rs.
// RpcRequest: estructura de solicitud JSON-RPC 2.0.
// RpcResponse: estructura de respuesta JSON-RPC 2.0.
// RpcError: objeto de error estándar (código + mensaje).
pub use jsonrpc::{BkernelRpc, RpcRequest, RpcResponse, RpcError};
```

---

## 5. Aplicación por proyecto

| Proyecto | Lenguaje | Estado DOC-SBOS-001 |
|----------|----------|---------------------|
| **BkernelAgent** | Rust | 🔄 En migración (60% completado, agentes trabajando) |
| **BosAgent** | Go | 🔴 Pendiente |
| **BauthAgent** | Go + Java | 🔴 Pendiente |
| **BiedataAgent** | Rust | 🔴 Pendiente |
| **BintelligenceAgent** | Go | 🔴 Pendiente |
| **BnexusAgent** | Go | 🔴 Pendiente |
| **InfraAgent** | Bash + YAML | 🔴 Pendiente |

---

## 6. Verificación en CI

```yaml
# Gate de documentación en pipeline CI
docs-check:
  script:
    - cargo doc --no-deps --document-private-items
    - |
      for f in $(find src -name "*.rs"); do
        header=$(head -1 "$f")
        if ! echo "$header" | grep -q "//!"; then
          echo "❌ $f: falta cabecera DOC-SBOS-001 N1"
          exit 1
        fi
      done
    - |
      undoc=$(grep -rn "pub fn" src/ | while read line; do
        if ! echo "$line" | grep -B1 "///"; then echo "$line"; fi
      done)
      if [ -n "$undoc" ]; then
        echo "❌ Funciones sin documentar N2:"
        echo "$undoc"
        exit 1
      fi
```

---

## 7. Adopción

Este estándar es de cumplimiento **obligatorio** para todo código nuevo.
El código existente debe migrarse progresivamente, empezando por los módulos
más críticos de cada daemon.

La migración de BkernelAgent a DOC-SBOS-001 N3 comenzó el 2026-06-19 y está
en progreso (3 agentes paralelos documentando 22 archivos).

---
*SBOS-060 v1.0 · 2026-06-19 · SKULL*
