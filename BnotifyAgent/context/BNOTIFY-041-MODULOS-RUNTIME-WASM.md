---
codigo: BNOTIFY-041
version: 1.0.0
estado: BORRADOR
gate: G3
depende_de: [BNOTIFY-040]
doctrina_que_ejerce: [D6, D12, D14]
criterio_implementado: >
  Un módulo WASM compilado desde Rust (con target wasm32-wasi) carga en el runtime
  sin errores. Una llamada RPC al módulo retorna respuesta en < 200ms.
  Un módulo que supera el límite de CPU es terminado con error, sin afectar el motor.
  Un módulo que solicita una capacidad no otorgada recibe error de permisos.
  Verificado con verificar_afirmacion.sh en VPS.
---

# BNOTIFY-041 — Módulos: Runtime WASM
## wasmtime embebido: capacidades, sandbox, carga en caliente, límites de recursos

**Versión:** 1.0.0 · **Gate:** G3 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-040 (manifiesto) · BNOTIFY-006 (wasmtime 28.0.x) · ADR-007

---

## 1. Por qué WASM/wasmtime (ADR-007)

Los módulos bChat son extensiones de terceros y de primera parte que corren dentro del motor. El sandbox WASM garantiza:

- **Aislamiento de memoria:** cada módulo tiene su propio heap lineal, sin acceso a la memoria del motor
- **Capacidades explícitas:** WASI 0.2 con model de capabilities — el módulo no puede hacer syscalls no autorizados
- **Carga en caliente:** un módulo se carga y descarga sin reiniciar el motor Rust
- **Portabilidad:** cualquier lenguaje que compile a WASM (Rust, AssemblyScript, Go via TinyGo) puede ser un módulo

La alternativa (plugins en forma de `.so` cargados con `dlopen`) fue descartada en ADR-007 por la imposibilidad de aislar correctamente la memoria y los permisos.

---

## 2. Arquitectura del runtime

```
Motor bChat (Rust)
├── wasmtime::Engine      # Motor WASM compartido — inicializado una vez
├── wasmtime::Linker      # Registra las host functions que los módulos pueden llamar
│
└── Por módulo activo:
    ├── wasmtime::Module  # Bytecode WASM compilado (cache AOT si el hash coincide)
    └── wasmtime::Store   # Estado de ejecución + límites de recursos
        └── wasmtime::Instance  # Instancia del módulo
```

### 2.1 Configuración del Engine

```rust
// runtime/engine.rs
fn create_engine() -> Result<wasmtime::Engine, BchatError> {
    let mut config = wasmtime::Config::new();
    config
        .wasm_component_model(true)          // WASI 0.2 component model
        .async_support(true)                 // Para módulos con I/O asíncrono
        .fuel_consumption(true)              // Para limitar CPU por módulo
        .epoch_interruption(true);           // Para timeouts por módulo
    wasmtime::Engine::new(&config).map_err(BchatError::WasmEngineInit)
}
```

---

## 3. Host functions (ABI del módulo)

Los módulos llaman a host functions para interactuar con el motor. Las host functions son la única interfaz entre el módulo WASM y el motor Rust.

```rust
// runtime/host_functions.rs
// Registradas en el Linker antes de instanciar cada módulo

// Enviar un mensaje a una sala (requiere capacidad: can_send_messages)
fn bchat_send_message(
    caller: Caller<'_, ModuleContext>,
    room_id_ptr: i32,
    room_id_len: i32,
    text_ptr: i32,
    text_len: i32,
) -> i32;  // 0 = éxito, código de error si falla

// Leer metadatos del usuario actual (requiere capacidad: can_access_user_data)
fn bchat_get_user_info(
    caller: Caller<'_, ModuleContext>,
    out_ptr: i32,
    out_len: i32,
) -> i32;

// Log estructurado (siempre disponible — no requiere capacidad)
fn bchat_log(
    caller: Caller<'_, ModuleContext>,
    level_ptr: i32,
    level_len: i32,
    msg_ptr: i32,
    msg_len: i32,
);
```

Cada host function verifica que la capacidad requerida está en el manifest del módulo llamante. Si no está, retorna `BCHAT_ERR_PERMISSION_DENIED` (-1).

---

## 4. Límites de recursos por módulo

```rust
// runtime/limits.rs
pub struct ModuleLimits {
    /// Memoria máxima (del manifiesto) — wasmtime limita heap del módulo
    pub max_memory_bytes: usize,

    /// Combustible de wasmtime (unidades de CPU sintéticas)
    /// Configurado para ~200ms de ejecución a velocidad de host
    pub fuel_per_call: u64,

    /// Timeout de wall-clock (epoch interruption)
    pub timeout_ms: u64,
}

impl Default for ModuleLimits {
    fn default() -> Self {
        Self {
            max_memory_bytes: 64 * 1024 * 1024,  // 64 MB
            fuel_per_call: 10_000_000,             // ~200ms
            timeout_ms: 500,                        // 500ms hard timeout
        }
    }
}
```

Cuando un módulo supera el fuel (CPU) o el timeout:
1. `wasmtime` interrumpe la ejecución (sin panic)
2. El motor retorna error `{"error": {"code": -32500, "message": "Módulo excedió límite de CPU"}}` al cliente
3. El evento se registra en auditoría con el `module_id` y el tiempo de ejecución

---

## 5. Carga en caliente

```rust
// runtime/loader.rs
pub async fn hot_reload_module(
    engine: &wasmtime::Engine,
    linker: &wasmtime::component::Linker<ModuleContext>,
    entry: &ModuleCatalogEntry,
) -> Result<LoadedModule, BchatError> {
    // 1. Descargar .wasm desde MinIO
    let wasm_bytes = minio_download(&entry.wasm_s3_key).await?;

    // 2. Verificar SHA256
    verify_sha256(&wasm_bytes, &entry.wasm_sha256)?;

    // 3. Verificar firma Ed25519
    verify_ed25519_signature(&wasm_bytes, &entry.signature_ed25519)?;

    // 4. Compilar (o recuperar de caché AOT)
    let module = wasmtime::component::Component::new(engine, &wasm_bytes)?;

    // 5. Registrar en el router
    Ok(LoadedModule { module, manifest: entry.manifest.clone() })
}
```

La compilación AOT (Ahead Of Time) es la primera vez que se carga el módulo. El resultado compilado se guarda en caché en disco (`/var/cache/bchat/modules/`), indexado por SHA256 del binario WASM. Las recargas posteriores del mismo hash no recompilan.

---

## 6. SDK para desarrolladores de módulos

Para facilitar el desarrollo de módulos bChat en Rust, se provee un crate `bchat-module-sdk`:

```rust
// Ejemplo de módulo "hola mundo" usando el SDK
use bchat_module_sdk::prelude::*;

#[bchat_module]
pub mod mi_modulo {
    #[rpc_method("mi_modulo.saludar")]
    pub async fn saludar(ctx: &ModuleCtx, params: SaludarParams) -> Result<SaludarResult> {
        ctx.log_info("Método saludar llamado").await;
        Ok(SaludarResult { mensaje: format!("Hola, {}!", params.nombre) })
    }
}
```

El macro `#[bchat_module]` genera el código de serialización/deserialización y los bindings con las host functions. El módulo compila con `cargo build --target wasm32-wasi --release`.

---

*BNOTIFY-041 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*El sandbox no es una restricción: es la garantía que hace posible confiar en código de terceros.*
