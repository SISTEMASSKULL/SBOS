---
codigo: BNOTIFY-006
version: 1.0.0
estado: BORRADOR
gate: G0
depende_de: [BNOTIFY-000]
doctrina_que_ejerce: [D1, D2, D6, D12]
criterio_implementado: >
  Todo Cargo.toml, go.mod, pubspec.yaml y archivo de infraestructura del proyecto
  referencia exactamente las versiones declaradas aquí. CI rechaza cualquier
  dependencia no listada sin ADR aprobado en BNOTIFY-007.
---

# BNOTIFY-006 — Stack Tecnológico
## Versiones canónicas y fijadas de todo el stack del proyecto bNotify

**Versión:** 1.0.0 · **Gate:** G0 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §4.8, §6.1, Anexo B

**Regla (D1):** un agente jamás elige versión ni librería por su cuenta.
Consulta este documento. Agregar una dependencia nueva = ADR en BNOTIFY-007 primero.

---

## 1. Lenguajes y runtimes

| Componente | Versión fijada | Justificación |
|-----------|:--------------:|---------------|
| **Rust** (toolchain stable) | 1.85.0 | Coherencia con bAuth; MUSL para binarios estáticos |
| **Rust target** | `x86_64-unknown-linux-musl` | Binarios estáticos, sin dependencias de glibc |
| **Java** | 21 LTS | Solo en SPIs Keycloak (bAuth) — no en bNotify core |
| **Node.js** | 22.16.0 | Solo en bRocket (Rocket.Chat CE) |
| **Deno** | 1.43.5 | Solo en bRocket (Apps Engine de Rocket.Chat) |
| **Flutter** | 3.27.x (stable) | Cliente bChat — todas las plataformas |
| **Dart** | 3.6.x | Incluido con Flutter 3.27.x |

---

## 2. Librerías Rust — bNotify daemon

### 2.1 Runtime y servidor

| Crate | Versión | Uso |
|-------|:-------:|-----|
| `tokio` | 1.43 | Runtime async — features: `full` |
| `tonic` | 0.12 | gRPC (cliente y servidor) — comunicación inter-daemon |
| `prost` | 0.13 | Serialización Protocol Buffers para gRPC |
| `tower` | 0.5 | Middleware sobre tonic |
| `axum` | 0.8 | Solo en bChat motor (no en bNotify core) |

### 2.2 Base de datos

| Crate | Versión | Uso |
|-------|:-------:|-----|
| `sqlx` | 0.8 | PostgreSQL async — compile-time query checking |
| `bb8` | 0.9 | Pool de conexiones PostgreSQL |
| `bb8-postgres` | 0.9 | Adaptador bb8 para postgres |
| `redis` | 0.26 | Cliente Redis async — deduplicación y rate limit |

### 2.3 Serialización y configuración

| Crate | Versión | Uso |
|-------|:-------:|-----|
| `serde` | 1.0 | Serialización/deserialización — features: `derive` |
| `serde_json` | 1.0 | JSON |
| `toml` | 0.8 | Configuración del daemon |
| `config` | 0.14 | Carga jerárquica de configuración (archivo + env) |
| `uuid` | 1.11 | UUIDs v7 — features: `v7`, `serde` |
| `chrono` | 0.4 | Timestamps con zona horaria |

### 2.4 Observabilidad

| Crate | Versión | Uso |
|-------|:-------:|-----|
| `tracing` | 0.1 | Logging estructurado |
| `tracing-subscriber` | 0.3 | Salida JSON para Wazuh/Loki |
| `opentelemetry` | 0.27 | Trazas OpenTelemetry |
| `opentelemetry-otlp` | 0.27 | Exportador OTLP |
| `metrics` | 0.24 | Métricas Prometheus |

### 2.5 Seguridad y criptografía

| Crate | Versión | Uso |
|-------|:-------:|-----|
| `rustls` | 0.23 | TLS — nunca OpenSSL en el núcleo |
| `jsonwebtoken` | 9.3 | Verificación de JWT emitidos por bAuth |
| `ed25519-dalek` | 2.1 | Verificación de firmas Ed25519 (bAuth) |
| `argon2` | 0.5 | Solo si bNotify necesita hashear algo propio |
| `rand` | 0.8 | Generación de números aleatorios seguros |

### 2.6 Mensajería y bus

| Crate | Versión | Uso |
|-------|:-------:|-----|
| `async-nats` | 0.38 | Cliente NATS/JetStream — ingesta de eventos |

### 2.7 Canales externos (adaptadores)

| Crate | Versión | Uso |
|-------|:-------:|-----|
| `lettre` | 0.11 | SMTP (canal email) |
| `reqwest` | 0.12 | HTTP para adaptadores de frontera (bRocket REST, Twilio, FCM) |
| `livekit` | 0.4 | SDK Rust LiveKit (bChat voz/video) |

### 2.8 WASM runtime (módulos bChat)

| Crate | Versión | Uso |
|-------|:-------:|-----|
| `wasmtime` | 28.0 | Runtime WASM para módulos-plugin — sandbox con capacidades |

### 2.9 E2EE (gate G5 — bChat C5)

| Crate | Versión | Uso |
|-------|:-------:|-----|
| `openmls` | 0.6 | MLS/RFC 9420 — cifrado E2E grupal (alternativa: `mls-rs` 0.7) |

---

## 3. Infraestructura de datos

| Componente | Versión fijada | Rol en el sistema |
|-----------|:--------------:|-------------------|
| **PostgreSQL** | 17.x | Base de datos principal — esquema por dueño (D18) |
| **Redis** | 7.4.x | Cache, deduplicación, rate limiting, tokens push |
| **NATS** | 2.10.x | Bus de eventos — JetStream para persistencia |
| **MinIO** | RELEASE.2025-01-* | Almacenamiento de objetos (medios, respaldos) — vigilar licencias (AGPL) |

**Nota MinIO:** Anexo B señala vigilar cambios de licencia. Alternativas evaluadas: SeaweedFS, Garage.
Mantener compatibilidad S3 API en todo el código para poder migrar sin reescritura.

---

## 4. Infraestructura de identidad e integración

| Componente | Versión fijada | Rol |
|-----------|:--------------:|-----|
| **Keycloak** | 26.6.2 | IdP externo — backup de bAuth (ver D3: bAuth es el IdP primario) |
| **Kong** | 3.9.x | API Gateway + PEP (Policy Enforcement Point) |
| **Vault** | 1.18.x | Gestión de secretos, PKI interna, tokens de servicio |

---

## 5. Stack bRocket (interino — solo configuración, D7)

| Componente | Versión fijada | Nota |
|-----------|:--------------:|------|
| **Rocket.Chat CE** | 8.5.0 | **Congelado (R-3 de BNOTIFY-000 §5) — sin actualizaciones** |
| **MongoDB** | 8.0.x | Replica set obligatorio (mínimo 3 nodos) |
| **Jitsi Meet** | 2.0.9984 | Video grupal en bRocket — adaptador delgado (sala + JWT) |

---

## 6. Stack bChat motor propio (gates G2–G3)

| Componente | Versión | Nota |
|-----------|:-------:|------|
| **LiveKit Server** | 1.8.x | SFU para voz/video/reuniones — reemplaza Jitsi en bChat |
| **LiveKit SDK Flutter** | 2.3.x | Cliente Flutter para video/voz |
| **LiveKit SDK Rust** | 0.5.x | Para integraciones server-side |

---

## 7. Herramientas de desarrollo y CI

| Herramienta | Versión | Uso |
|-------------|:-------:|-----|
| **k6** | 0.55.x | Pruebas de carga y modelos de capacidad (D9) |
| **cargo-nextest** | 0.9.x | Test runner Rust — más rápido que cargo test |
| **sqlx-cli** | 0.8.x | Migraciones de base de datos |
| **refinery** | 0.8.x | Alternativa a sqlx-cli para migraciones versionadas |
| **protoc** | 3.x | Compilador Protocol Buffers |
| **docker** | 27.x | Imágenes para CI |

---

## 8. Plataforma de despliegue

| Componente | Versión | Rol |
|-----------|:-------:|-----|
| **Ubuntu Server** | 24.04 LTS | OS del host donde corren los daemons |
| **systemd** | 255.x | Gestión de daemons en el host (bNotify, bAuth, bKernel…) |
| **Kubernetes** | 1.32.x | Orquestación de servicios de infraestructura (PostgreSQL, Redis, NATS, Keycloak, Vault, Kong, bRocket) |
| **Helm** | 3.16.x | Charts K8s para infraestructura |

---

## 9. Reglas de gestión de dependencias

1. **Versión nueva = ADR en BNOTIFY-007.** No se actualiza una versión sin documentar por qué.
2. **CVE en una dependencia = tarea de emergencia** — se evalúa la severidad el mismo día y se escala a Ivan si es explotable en la red propia.
3. **Sin dependencias de conveniencia:** toda crate nueva debe justificarse. Si la funcionalidad puede implementarse con menos de 50 líneas usando la stdlib o crates ya listadas, no se agrega.
4. **Compatibilidad S3 API obligatoria** en todo acceso a almacenamiento de objetos — el proveedor concreto (MinIO, SeaweedFS, Garage) es intercambiable.
5. **Rust edition 2021** en todos los crates del proyecto.

---

*BNOTIFY-006 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*Un agente que agrega una librería sin ADR está introduciendo deuda de gobernanza — no solo técnica.*
