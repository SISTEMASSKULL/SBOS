---
codigo: BNOTIFY-040
version: 1.0.0
estado: BORRADOR
gate: G3
depende_de: [BNOTIFY-030, BNOTIFY-032]
doctrina_que_ejerce: [D6, D14, D15]
criterio_implementado: >
  El motor bChat carga un módulo WASM de prueba (hola-mundo) desde el catálogo.
  El módulo responde a un método JSON-RPC de prueba desde el cliente Flutter.
  El catálogo RPC retorna la lista de módulos instalados con sus versiones.
  Un módulo con manifiesto inválido es rechazado con error descriptivo.
  Verificado con verificar_afirmacion.sh en VPS.
---

# BNOTIFY-040 — Módulos: Manifiesto y Catálogo
## Contrato del manifiesto, registro RPC, catálogo versionado, apertura y gobernanza

**Versión:** 1.0.0 · **Gate:** G3 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §C.0 (mini-apps), §A.0.7 (ADR-007: WASM via wasmtime) · BNOTIFY-006 (wasmtime 28.0.x)

---

## 1. Qué es un módulo bChat

Un **módulo** es una extensión de funcionalidad que se ejecuta dentro del motor bChat en un sandbox WASM. Cada módulo:

- Tiene un **manifiesto** que declara su identidad, capacidades solicitadas, y métodos que expone
- Se compila a **WebAssembly** (WASM) con interface WASI
- Se carga en caliente sin reiniciar el motor (D6 — carga en caliente)
- Está firmado digitalmente — solo el motor verifica la firma al cargar
- Corre en un sandbox con límites de memoria, CPU, y capacidades (D6 — sandbox)

Los módulos first-party (atención al cliente, formularios, correo) son desarrollados por SKULL y se distribuyen con el instalador SBOS. Los módulos third-party requieren revisión y firma (BNOTIFY-045).

---

## 2. Estructura del manifiesto

```toml
# module.toml — Manifiesto de módulo bChat
[module]
id         = "atencion-cliente"       # Identificador único, kebab-case
name       = "Atención al Cliente"    # Nombre legible
version    = "1.0.0"                  # SemVer
author     = "SKULL / SBOS"
description = "Bandeja omnichannel para gestión de atención al cliente"

[module.entrypoint]
wasm_file  = "atencion_cliente.wasm"  # Compilado desde Rust/AssemblyScript
sha256     = "{hash-del-wasm}"        # Verificado al cargar

[module.capabilities]
# Lista de capacidades que el módulo solicita al motor
# El motor las otorga o las rechaza al instalar
can_send_messages        = true   # Puede enviar mensajes como bot
can_read_room_history    = true   # Puede leer historial de salas asignadas
can_manage_rooms         = false  # NO puede crear/archivar salas
can_access_user_data     = true   # Puede leer nombre y email del usuario
can_call_external_apis   = false  # NO puede hacer llamadas HTTP al exterior
can_read_other_modules   = false  # NO puede acceder a datos de otros módulos

[module.rpc_methods]
# Métodos JSON-RPC que expone al cliente Flutter
expose = [
  "atencion.chat.open_ticket",
  "atencion.chat.transfer_to_agent",
  "atencion.chat.close_ticket",
  "atencion.chat.get_queue_status",
]

[module.rooms]
# Tipos de sala donde el módulo puede activarse
allowed_in = ["channel", "group"]
auto_activate_for = ["livechat_*"]  # Prefijo de nombres de sala

[module.limits]
max_memory_mb  = 64     # Límite de memoria WASM
max_cpu_ms_per_req = 200  # Tiempo máximo por llamada RPC
```

---

## 3. Catálogo de módulos — tabla PostgreSQL

```sql
-- Schema: bnotify (el orquestador es dueño del catálogo de módulos)
CREATE TABLE bnotify.module_catalog (
    id              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       TEXT        NOT NULL,
    module_id       TEXT        NOT NULL,      -- "atencion-cliente"
    version         TEXT        NOT NULL,      -- "1.0.0"

    manifest_toml   TEXT        NOT NULL,      -- Manifiesto completo
    wasm_s3_key     TEXT        NOT NULL,      -- Ruta al .wasm en MinIO
    wasm_sha256     TEXT        NOT NULL,      -- Hash para verificación en carga

    -- Estado
    state           TEXT        NOT NULL DEFAULT 'PENDING_REVIEW',
    -- 'PENDING_REVIEW' | 'ACTIVE' | 'DISABLED' | 'REVOKED'

    -- Autoría y firma
    signed_by       TEXT        NOT NULL,      -- "SKULL" | "third-party:nombre"
    signature_ed25519 TEXT      NOT NULL,      -- Firma Ed25519 del binario

    installed_at    TIMESTAMPTZ NULL,
    installed_by    UUID        NOT NULL,      -- bauth_user_id del admin

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (tenant_id, module_id, version)
);

CREATE INDEX idx_module_catalog_tenant_state ON bnotify.module_catalog (tenant_id, state);
```

---

## 4. Registro RPC del módulo en el motor

Cuando el motor bChat carga un módulo:

```
1. Leer manifiesto (bnotify.module_catalog WHERE state = 'ACTIVE')
2. Descargar .wasm desde MinIO
3. Verificar SHA256 del binario contra manifest
4. Verificar firma Ed25519 del binario
5. Crear instancia wasmtime con límites del manifiesto
6. Registrar los métodos RPC del módulo en el router JSON-RPC:
   "atencion.chat.open_ticket" → WasmModuleHandler("atencion-cliente", "open_ticket")
7. Publicar evento: módulo cargado en NATS (topic bnotify.module.loaded)
```

### 4.1 Router JSON-RPC con módulos

El router del motor bChat tiene dos niveles:
- **Métodos nativos** (`bchat.*`): implementados en Rust, siempre disponibles
- **Métodos de módulo** (`<module_prefix>.*`): delegados al módulo WASM correspondiente

Un método desconocido retorna error `-32601 Método no encontrado`.

---

## 5. Ciclo de vida de un módulo

```
PENDING_REVIEW → ACTIVE → DISABLED → REVOKED
                    ↑
              (revisión aprobada)
```

| Estado | Significado | Efecto en el motor |
|--------|-------------|-------------------|
| `PENDING_REVIEW` | Instalado, pendiente de revisión | No cargado |
| `ACTIVE` | Aprobado y en uso | Cargado en wasmtime |
| `DISABLED` | Desactivado por admin | Descargado sin eliminar |
| `REVOKED` | Revocado por seguridad o incumplimiento | Descargado, binario eliminado |

La transición `PENDING_REVIEW → ACTIVE` **solo puede hacerla un usuario con átomo bAuth `D6.module.APPROVE`**. Ningún módulo llega a `ACTIVE` sin revisión explícita de un humano con el privilegio correcto.

---

## 6. Módulos first-party del catálogo inicial

| ID de módulo | Documento | Estado |
|--------------|-----------|:------:|
| `atencion-cliente` | BNOTIFY-042 | BORRADOR |
| `motor-formularios` | BNOTIFY-043 | BORRADOR |
| `correo` | BNOTIFY-044 | BORRADOR |

Los módulos third-party están gobernados por BNOTIFY-045.

---

*BNOTIFY-040 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*El manifiesto es el contrato. El sandbox es la frontera. La firma es la garantía.*
