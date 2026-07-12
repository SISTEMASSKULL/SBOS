# Anexo A.14 — El Context Plane B16 (proceso de desarrollo)
## Documento de respaldo: la investigación, arquitectura e implementación del ctx_id

**Tipo:** ANEXO — documento de respaldo del corpus
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Estatus:** FUENTE AUTOSUFICIENTE — contiene el proceso COMPLETO (traslado fiel, §3)
**Respalda a:** MANUAL-CONTEXT-PLANE (1.11) · MANUAL-AUDITORIA (5.01 §6 — doble hilo ctx_id+traceparent) · A.11 (ctx_id como token)
**Fuentes de origen (cita histórica):** `BAUTH-CONTEXT-PLANE-B16`
**Normas base:** NIST SP 800-207 (Policy Engine) · W3C Trace Context · OpenTelemetry Baggage · SBOS-049

---

## 1. Propósito y cómo citarlo

Respaldo del proceso de desarrollo del **Context Plane** (el bloque B16 del plan): la
investigación de estándares que lo fundó, la arquitectura de responsabilidades (quién emite,
quién valida, quién consume el `ctx_id`), los archivos implementados, el formato de invocación
JSON-RPC y la relación con el daemon de control (bos). **Cómo citarlo:** `A.14 §2` (del
traslado: arquitectura de responsabilidades).

**Autosuficiencia:** el Context Plane es nativo (SBOS-049); menciones de época bajo ADR-010
(**Keycloak y Tryton eliminados de la solución**).

## 2. Verificación de completitud

| Verificación | Resultado |
|---|---|
| Cobertura | Investigación (800-207, W3C Trace Context, Baggage) + arquitectura + implementación + API + relación con bos — íntegro en §3 |
| Coherencia con 1.11 | ✅ — 1.11 lleva la doctrina vigente del ctx_id (6 capas); este anexo respalda el proceso y la investigación de origen |
| Coherencia con el pipeline | ✅ — D8 pre-BitMask (¿ctx vivo?) — 1.01 §5 |

## 2.bis Estado de materialización en código (verificado 2026-07-11)

| Pieza | Evidencia | Estado |
|---|---|---|
| Módulo `context/` | `src/context/` = `plane.rs` (255) + `engine.rs` + `mod.rs` = **535 líneas** | ✅ **real** |
| `CtxPlane` (6 capas SBOS-049) | `plane.rs` | ✅ |
| Ciclo de vida (create/promote/invalidate) | `engine.rs` | ✅ |
| `ctx_id` en operaciones | presente en **47 archivos** (grep) | ✅ transversal |

**Veredicto:** el Context Plane es de los subsistemas **más completos y reales** (535 líneas +
ctx_id en 47 archivos). El proceso de desarrollo que documenta este anexo se materializó. Es un
✅ sólido — coherente con 1.11 (L3).

## 3. Traslado fiel — el proceso completo

### BAUTH-CONTEXT-PLANE-B16 — Documentación del Proceso de Desarrollo

**Versión:** 1.0.0 · **Fecha:** 2026-06-22 · **Autor:** sbos-coordinador + bauth  
**Commit:** `7fc1e6dd` · **Tests:** 18/18 pasando

---

#### 1. Investigación Previa — Estándares Internacionales

##### 1.1 W3C Trace Context Level 2 (Recomendación 2025)

El W3C Trace Context es el estándar de la industria para propagación de contexto
distribuido. Adoptado por OpenTelemetry como propagador por defecto en 2025.

| Componente | Header HTTP | Formato | Propósito |
|-----------|------------|---------|----------|
| **traceparent** | `traceparent` | `00-{trace_id(32 hex)}-{span_id(16 hex)}-{flags}` | Identificador único de traza |
| **tracestate** | `tracestate` | `vendor=value` | Metadatos del proveedor (sbos=tenant) |
| **baggage** | `baggage` | `key=value,key2=value2` | Contexto de negocio (ctx_id, user_id) |

**Implementación en SBOS:**
```rust
// Generación de traceparent W3C
pub fn generate_traceparent() -> String {
    let trace_id = Uuid::new_v4().to_string().replace('-', "");
    let span_id = &Uuid::new_v4().to_string().replace('-', "")[..16];
    format!("00-{}-{}-01", trace_id, span_id)
}

// Headers de propagación para daemons
let headers = vec![
    ("traceparent", ctx.traceparent),
    ("tracestate", format!("sbos={}", ctx.tenant_id)),
    ("baggage", format!("ctx_id={},user_id={},tier={}", ctx_id, user_id, tier)),
];
```

**Fuentes:**
- W3C Trace Context Recommendation: https://www.w3.org/TR/trace-context/
- OpenTelemetry Propagation: https://opentelemetry.io/docs/concepts/context-propagation/
- MCP SEP-414 (Abril 2025): estandarizó propagación OTel en Model Context Protocol
- Microsoft .NET 10 (2025): cambió propagador por defecto a W3C Trace Context

##### 1.2 OpenTelemetry Baggage

El header `baggage` transporta pares clave-valor de contexto de negocio a través
de todos los servicios. A diferencia de `traceparent` (que es solo para observabilidad),
`baggage` transporta datos que afectan la lógica de negocio.

**Mejores prácticas 2025:**
- Whitelist de keys: solo propagar keys explícitamente permitidas (evitar PII)
- Promover keys a span attributes para tail-sampling
- Límite de 8192 caracteres (W3C Baggage) vs 256 de X-Ray
- URL-encoding para valores con caracteres especiales

**Implementación en SBOS:**
```rust
// Header de baggage con datos de tenant y usuario
"baggage: ctx_id=tenant%3Aemp%3Asuc%3Apos%3Auser%3Atraceparent,user_id=<uuid>"
```

**Fuentes:**
- W3C Baggage Specification: https://www.w3.org/TR/baggage/
- AWS X-Ray Baggage Fix (Enero 2025): PR #1671 — separación X-Ray lineage vs W3C Baggage
- Broadcom Layer7 (Septiembre 2025): full baggage handling (read, update, delete, promote)

##### 1.3 NIST SP 800-207 — Zero Trust Architecture

El Context Plane implementa los 7 principios de Zero Trust:

| Principio ZTA | Implementación en SBOS |
|--------------|----------------------|
| 1. Todos los recursos son accesibles vía red | ctx_id requerido en cada request |
| 2. Comunicación segura independiente de ubicación | W3C traceparent en cada llamada entre daemons |
| 3. Acceso por sesión individual | ctx_id único por sesión con TTL |
| 4. Política dinámica basada en atributos | RiskScore + DomainRegistry por contexto |
| 5. Monitoreo continuo de integridad | validate_active() en cada request |
| 6. Autenticación y autorización estrictas | promote() solo post-auth, invalidate() inmediato |
| 7. Máxima telemetría | traceparent + baggage en cada request |

**Arquitectura PDP/PEP:**
```
Policy Decision Point (PDP) = bAuth (valida ctx_id, evalúa políticas)
Policy Enforcement Point (PEP) = Kong (valida X-SBOS-Context header)
Policy Administrator (PA) = bAuth (gestiona tokens de sesión)
```

**Fuentes:**
- NIST SP 800-207: https://csrc.nist.gov/publications/detail/sp/800-207/final
- CISA Zero Trust Maturity Model v2: 5 pilares × 4 etapas (Traditional→Optimal)
- Executive Order 14028: requiere Zero Trust en agencias federales USA
- OMB M-22-09: fecha límite FY2024 para capacidades ZTA definidas

##### 1.4 ISO 27001:2022 A.8.15 — Logging and Monitoring

Cada operación del ciclo de vida del ctx_id debe registrarse en auditoría WORM:

| Evento | Trigger | Datos registrados |
|--------|---------|------------------|
| `ctx.created` | BOS crea dctx_id | tenant_id, empresa_id, sucursal_id, pos_logico, nonce, timestamp |
| `ctx.validated` | Kong valida en cada request | ctx_id, resultado, latency_ns |
| `ctx.promoted` | bAuth eleva post-auth | dctx_id → ctx_id, user_id asignado, bitmask |
| `ctx.invalidated` | Logout / timeout / anomalía | ctx_id, motivo, user_id |
| `ctx.replay_alert` | Nonce reutilizado | ctx_id, nonce, timestamp (P1 security alert) |

**Fuentes:**
- ISO/IEC 27001:2022 A.8.15: https://www.iso.org/standard/27001
- SBOS-049 §8: ciclo de vida del contexto documentado

---

#### 2. Arquitectura de Responsabilidades

```
┌──────────────────────────────────────────────────────────────────┐
│                    CONTEXT PLANE (SBOS-049)                        │
│                                                                    │
│  ┌─────────────────────┐         ┌──────────────────────────────┐ │
│  │  BOS (IAM Installer) │         │  bAuth (Identity Core)        │ │
│  │                     │         │                              │ │
│  │  GOBIERNA ctx_id    │ dctx_id │  VALIDA + INYECTA            │ │
│  │  • create           │────────→│  • validate_structure()       │ │
│  │  • destroy          │         │  • validate_pre_auth()        │ │
│  │  • ciclo de vida    │         │  • promote(pre→post auth)     │ │
│  │                     │         │  • invalidate(logout)         │ │
│  └─────────────────────┘         │  • propagate(W3C headers)     │ │
│                                   └──────────────────────────────┘ │
│                                                                    │
│  ┌─────────────────────┐         ┌──────────────────────────────┐ │
│  │  Kong (API Gateway)  │         │  Todos los Daemons            │ │
│  │                     │         │                              │ │
│  │  ENFORCE (PEP)      │         │  PROPAGAN ctx_id              │ │
│  │  X-SBOS-Context     │         │  • traceparent header         │ │
│  │  → validar en cada  │         │  • tracestate: sbos=<tenant>  │ │
│  │    request          │         │  • baggage: ctx_id,user_id    │ │
│  └─────────────────────┘         └──────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

**Principio clave:** BOS es el **governor** del Context Plane — crea y destruye ctx_id.
bAuth es el **authenticator** — valida la estructura e inyecta los datos del tenant,
usuario y rol después de la autenticación exitosa en Keycloak. Kong es el **enforcer** —
valida el header `X-SBOS-Context` en cada request HTTP.

---

#### 3. Implementación — Archivos Creados

```
BauthAgent/src/context/
├── mod.rs              # Módulo context (B16)
├── plane.rs            # CtxPlane struct — 6 campos canónicos (SBOS-049 §3)
└── engine.rs           # CtxEngine — ciclo de vida completo

BauthAgent/src/server/handlers/
└── context_plane.rs    # 5 handlers JSON-RPC (create, validate, promote, invalidate, propagate)
```

##### 3.1 `plane.rs` — Estructura del ctx_id

**Campos canónicos (SBOS-049 §3):**
```
tenant_id:empresa_id:sucursal_id:pos_logico:user_id:traceparent
    ↓          ↓           ↓          ↓         ↓         ↓
  UUID v4    UUID v4    UUID|null   string   UUID v4   00-{trace}-{span}-01
```

**Anti-Replay Protection (NIST SP 800-63B §7):**
- `nonce`: UUID v4 único por sesión, verificado con Redis SETNX
- `created_at`: timestamp UTC para validación de TTL
- `sequence`: contador incremental por operación (detecta duplicados)

**W3C Trace Context:**
- `traceparent`: formato `00-{trace_id(32)}-{span_id(16)}-01`
- `tracestate`: `sbos={tenant_id}`
- `baggage`: `ctx_id=<encoded>,user_id=<uuid>`

**Tests (8):**
- Pendiente con user_id nil
- Promoción activa el contexto
- Roundtrip header → struct → header
- Expiración por TTL
- W3C traceparent formato válido (4 partes, 32+16 hex chars)

##### 3.2 `engine.rs` — Ciclo de Vida

| Método | Entrada | Salida | Estado |
|--------|---------|--------|--------|
| `validate_structure()` | ctx_header string | CtxPlane | — |
| `validate_pre_auth()` | CtxPlane | CtxResult | Pending → válido / rechazado |
| `promote()` | CtxPlane + user_id | CtxResult | Pending → Active |
| `validate_active()` | CtxPlane | CtxResult | Active → válido / rechazado |
| `invalidate()` | CtxPlane | CtxResult | * → Invalidated |
| `propagation_headers()` | CtxPlane | Vec<(String,String)> | Headers W3C |

**Máquina de estados:**
```
Pending ──promote()──→ Active ──invalidate()──→ Invalidated
   │                      │
   └──invalidate()──→ Invalidated
                          │
   Quarantined ←──────────┘ (anomalía)
```

**Tests (8):**
- Pre-auth acepta Pending
- Pre-auth rechaza expirado
- Promote activa el contexto
- Promote rechaza doble promoción
- Validate rechaza Pending (requiere Active)
- Validate acepta contexto válido
- Invalidate es idempotente
- Propagation headers en formato W3C

##### 3.3 `context_plane.rs` — Handlers JSON-RPC

| Método | Propósito | Consumidor |
|--------|----------|-----------|
| `bauth.ctx.create` | Crear dctx_id pre-auth | BOS (delegado) |
| `bauth.ctx.validate` | Validar ctx_id activo (PDP) | Kong, daemons |
| `bauth.ctx.promote` | Elevar dctx_id → ctx_id | bAuth (post-KC login) |
| `bauth.ctx.invalidate` | Invalidar ctx_id | bAuth (logout) |
| `bauth.ctx.propagate` | Headers W3C para daemons | biedata, bkernel, etc. |

---

#### 4. Formato de Invocación JSON-RPC

##### Crear dctx_id (pre-auth)
```json
{
  "method": "bauth.ctx.create",
  "params": {
    "tenant_id": "4c697f66-d204-45a5-ac36-c104f07c7046",
    "empresa_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "sucursal_id": "f9e8d7c6-b5a4-3210-fedc-ba9876543210",
    "pos_logico": "POS-01",
    "ttl_seconds": 3600
  }
}
```

##### Validar ctx_id (PDP en tiempo real)
```json
{
  "method": "bauth.ctx.validate",
  "params": {
    "ctx_id": "4c697f66-...:a1b2c3d4-...:f9e8d7c6-...:POS-01:11111111-...:00-0af76519...-b7ad6b71...-01"
  }
}
```

##### Promover post-autenticación
```json
{
  "method": "bauth.ctx.promote",
  "params": {
    "ctx_id": "4c697f66-...:a1b2c3d4-...:null:POS-01:00000000-...:00-...",
    "user_id": "11111111-2222-3333-4444-555555555555"
  }
}
```

---

#### 5. Relación con BOS

**BOS (IAM Installer) es el governor del Context Plane:**

1. **Creación:** BOS crea `dctx_id` cuando el dispositivo arranca. Lo almacena en Redis DB1 con TTL y estado `Pending`. bAuth NO crea ctx_id por sí mismo — solo puede crearlo bajo delegación de BOS vía `bauth.ctx.create`.

2. **Ciclo de vida:** BOS monitorea la salud del dispositivo. Si el dispositivo se apaga, BOS invalida todos los ctx_id asociados.

3. **Destrucción:** BOS destruye ctx_id al:
   - Apagar el dispositivo (graceful shutdown)
   - Detectar anomalía de hardware (tamper, desconexión)
   - Timeout del dispositivo (no heartbeat)

**bAuth (Identity Core) es el authenticator:**

1. **Validación:** Antes de permitir la autenticación en Keycloak, bAuth verifica que el `dctx_id` existe y está en estado `Pending` (B16.T15).

2. **Inyección:** Después de la autenticación exitosa, bAuth promueve el `dctx_id` → `ctx_id`:
   - Asigna `user_id` (del token JWT de Keycloak)
   - Asigna `bitmask` (calculado del RolTemplate)
   - Genera nuevo `traceparent` W3C
   - Reinicia `sequence` a 1

3. **Propagación:** bAuth provee los headers W3C para que todos los daemons propaguen el contexto.

---

#### 6. Referencias

| Documento | Ubicación |
|-----------|----------|
| SBOS-049 — Context Plane | `context/sbos/Procesar/humano/BOS_V8/BOS_V8_SBOS-049-CONTEXT-PLANE.md` |
| Código fuente | `BauthAgent/src/context/` |
| Handlers JSON-RPC | `BauthAgent/src/server/handlers/context_plane.rs` |
| REGISTRO-ESTADO | `plandeaccion/bauth/REGISTRO-ESTADO.md` (B16) |
| REGISTRO-HERRAMIENTAS | `plandeaccion/bauth/REGISTRO-HERRAMIENTAS-DESARROLLO.md` |


---

## 4. Referencias e historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.1.0 | 2026-07-11 | **Añadida verificación de código real** (§2.bis: Context Plane REAL (535 líneas + ctx_id en 47 archivos) — subsistema sólido L3). |
| 1.0.0 | 2026-07-11 | Anexo inicial: el proceso de desarrollo del Context Plane (investigación de estándares, arquitectura de responsabilidades, implementación, API, relación con bos) con verificación de coherencia (1.11, pipeline D8) y traslado fiel íntegro. |
