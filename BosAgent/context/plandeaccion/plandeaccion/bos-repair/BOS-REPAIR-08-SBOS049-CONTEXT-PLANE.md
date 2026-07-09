# BOS-REPAIR-08 — SBOS-049 Context Plane
## Plano de Contexto Distribuido: Semántica, Trazabilidad y Observabilidad Operacional
## Estándar HUMAN-DOC · SKULL · SBOS · v2.0 · Mayo 2026

**Prefijo BOS-REPAIR:** Este documento es parte del proyecto de reparación del BosAgent.  
**Relevancia para BOS-REPAIR:** El bos es el responsable del Context Plane. Toda reparación del bos debe preservar y restaurar el Context Plane correctamente. Los criterios C-13 y C-14 del BOS-REPAIR-01 dependen directamente de este documento.  
**Referencia cruzada:** BOS-REPAIR-01 §Capa 3, BOS-REPAIR-05 §Fase 5, BOS-REPAIR-06 §Rol C

---

## 1. Propósito

Este documento formaliza la arquitectura del **Plano de Contexto Distribuido** del SBOS: la capa que dota de significado empresarial a todo lo que ocurre en la infraestructura.

El problema central que resuelve:

> Ubuntu sabe qué máquina existe.  
> Kubernetes sabe qué pod corre.  
> Keycloak sabe quién es el usuario.  
> **SBOS sabe qué significa todo eso junto.**

**Corrección v2.0:** La responsabilidad de inicializar, mantener y destruir el Context Plane pertenece al **bos** como parte de su rol de Infrastructure Provisioning & Lifecycle Orchestrator.

---

## 2. Validación contra Estándares Internacionales

### 2.1 OpenTelemetry + W3C Trace Context

El estándar **W3C Trace Context** define el formato universal para propagar identidad de traza entre servicios mediante los headers HTTP `traceparent` y `tracestate`. **OpenTelemetry** (CNCF graduado) lo extiende con **Baggage**: pares clave-valor que viajan junto al contexto de traza a través de todas las fronteras de servicio.

```
Baggage: tenant.id=skull, empresa.id=maya, sucursal.id=lapaz,
         pos.id=POS-23, user.id=3397708, ctx.id=ctx-88291-a4f9
```

Compatible con el principio de **cero invasión**: cualquier servicio del stack lee este baggage automáticamente sin modificar su código.

**Referencias:** W3C Trace Context Level 1 (2019); OpenTelemetry Baggage API Specification; CNCF OpenTelemetry Project.

### 2.2 NIST SP 800-207 — Zero Trust Architecture

**NIST SP 800-207** establece tres componentes obligatorios:

| Componente NIST 800-207 | Equivalente en SBOS |
|---|---|
| Policy Engine (PE) | bAuth — evalúa BitMask, RolTemplate, ctx activo |
| Policy Administrator (PA) | **bos** — provisiona y destruye contextos de tenant |
| Policy Enforcement Point (PEP) | Kong API Gateway + plugin SBOS-Context |

Alineación con **Tenet 3**: *"Grant per-session access to follow least-privilege, ensuring privileges are time-bound."*

### 2.3 ISO/IEC 27001:2022 — Controles A.8.15 y A.8.16

- **A.8.15 (Logging):** cada entrada de log debe tener timestamp, usuario, acción, recurso, resultado y **contexto de sesión**. Un audit log sin `ctx_id` no puede demostrar en qué empresa o POS ocurrió un evento.
- **A.8.16 (Monitoring):** detección de comportamiento anómalo en tiempo real. Sin contexto distribuido, imposible distinguir si un evento es anómalo dentro del contexto correcto.

### 2.4 Patrón Control Plane / Data Plane

```
Ubuntu (Hardware Abstraction Layer)
    ↓  aporta: IP, hostname, MAC, nodo físico, filesystem
Kubernetes (Distributed Execution Engine)
    ↓  aporta: pod, namespace, labels, deployment, cluster
Keycloak (Identity Provider)
    ↓  aporta: usuario, roles, claims, sesión, permisos
bos IAM Installer (Sovereign Control Plane) ← RESPONSABLE DEL CONTEXT PLANE
    ↓  aporta: provisión, ciclo de vida tenant, Context Sessions
SBOS Context Plane (capa transversal activada por bos)
    ↓  aporta: tenant, empresa, sucursal, POS, ctx_id,
              trazabilidad, auditoría, correlación, semántica
Aplicaciones / Fichas / POS / ERP / Servicios
```

---

## 3. Los Dos Identificadores de Contexto

### dctx_id — Device Context ID (pre-autenticación)

Cuando un dispositivo Fedora arranca y `sbos-client` se activa, el bos crea automáticamente un `dctx_id`. Registra toda actividad del dispositivo antes de que el usuario se autentique. El usuario no sabe que existe.

```json
{
  "dctx_id": "dctx-device-991",
  "device_id": "DEVICE-991",
  "hostname": "caja-lpz-23",
  "ip": "10.0.0.55",
  "mac": "AA:BB:CC:DD:EE:FF",
  "hardware_type": "physical",
  "tenant": "skull",
  "node_k8s": "node-02",
  "status": "pre-auth",
  "bitmask": "0x0",
  "created_at": "2026-05-20T14:30:00Z"
}
```

### ctx_id — Context Session ID (post-autenticación)

Cuando el usuario se autentica con Keycloak, bAuth evalúa los tres dominios y calcula el BitMask. El bos eleva el `dctx_id` → `ctx_id` (evento `context.promoted`).

```json
{
  "ctx_id": "ctx-88291-a4f9",
  "dctx_id_prev": "dctx-device-991",

  "tenant": "skull",
  "empresa": "maya",
  "sucursal": "lapaz",
  "pos_logico": "POS-23",

  "user_id": "3397708",
  "session_kc": "kc-sess-7fab12",
  "bitmask": "0x00000000008C87FF",

  "pod": "pos-api-77fa",
  "namespace": "skull-maya",
  "node": "node-02",
  "cluster": "cluster-bolivia",
  "vps": "vps-lapaz-01",
  "geo": "La Paz, Bolivia",

  "traceparent": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",

  "created_at": "2026-05-20T14:32:00Z",
  "expires_at": "2026-05-20T22:32:00Z",
  "status": "active"
}
```

---

## 4. El Árbol de Contextos Permitidos

Un usuario posee un árbol de contextos autorizados según sus claims en Keycloak:

```
usuario 3397708
├── skull/maya/lapaz/pos23    ← contexto activo actual
├── skull/maya/lapaz/pos24
├── skull/maya/santacruz/pos2
├── skull/inka/lapaz/pos7
└── skull/admin/global
```

Ruta canónica: `/dist/{tenant}/emp/{empresa}/suc/{sucursal}/user/{user_id}/pos/{pos_id}`

---

## 5. Máquina de Estados del Context Plane

Basado en NIST 800-207, SCIM RFC 7644, ISO 27001 A.9.4.2 y ADR-002:

```
Estado         Descripción                              Transiciones posibles
─────────────────────────────────────────────────────────────────────────────
PRE_AUTH      Dispositivo sin usuario. BitMask=0x0.    → ACTIVO (via promote)
ACTIVO        Usuario autenticado. BitMask>0.           → SUSPENDIDO, BLOQUEADO,
                                                         STEP_UP, SWITCHED,
                                                         INVALIDADO
SUSPENDIDO    Idle timeout (ISO 27001: 15min sensible)  → ACTIVO (reactivar)
              o admin suspende. BitMask preservado.
BLOQUEADO     Anomalía detectada (NIST 800-207).        → ACTIVO (step-up KC)
              Step-up requerido. BitMask preservado.    → INVALIDADO
STEP_UP       Operación alto riesgo. Re-auth KC.        → ACTIVO (re-auth OK)
              Temporal.                                 → BLOQUEADO (re-auth fail)
SWITCHED      Context switch: nueva empresa/sucursal.   Terminal
              ctx_id anterior marcado SWITCHED.
INVALIDADO    Logout, TTL expirado, admin invalida.     Terminal
              Audit trail preservado SIEMPRE.
─────────────────────────────────────────────────────────────────────────────
```

### Privilegios por estado

| Estado | BitMask | Acceso |
|---|---|---|
| PRE_AUTH | 0x0 | Solo recursos públicos del tenant |
| ACTIVO | > 0x0 | Según BitMask calculado por bAuth |
| SUSPENDIDO | preservado | Sin acceso hasta reactivación |
| BLOQUEADO | preservado | Sin acceso hasta step-up |
| STEP_UP | parcial | Solo operaciones de re-autenticación |
| SWITCHED | 0x0 | Sin acceso (terminal) |
| INVALIDADO | 0x0 | Sin acceso (terminal) |

---

## 6. Flujo Completo: Dispositivo → Usuario → Trabajo

### Fase 1 — Dispositivo activo sin usuario (Pre-Auth)

```
Terminal Fedora arranca
      ↓ sbos-client.service inicia
      ↓ sbos-client contacta bhnexus via mTLS
      ↓ bhnexus notifica al bos: nuevo dispositivo {device_uuid}
      ↓ bos verifica: ¿device_uuid autorizado para el tenant?
        SÍ → registra en .sbos_state.json
             crea dctx_id (hardware_type: "physical")
             emite certificado mTLS via Vault PKI
        NO  → rechaza, emite alerta: device.unauthorized_registration
      ↓ dctx_id activo: contexto OS disponible (Ubuntu+K8s+tenant)
        BitMask = 0x0 — nadie autenticado
```

### Fase 2 — Usuario se autentica

```
Usuario presenta credencial (NFC/QR/password) en GNOME login
      ↓ PAM Keycloak autentica
      ↓ Keycloak emite JWT con bos_contexts claim
      ↓ bos recibe notificación de login
      ↓ bAuth calcula BitMask (3 dominios)
      ↓ bos promueve dctx_id → ctx_id (context.promoted event)
      ↓ ctx_id almacenado en Redis DB1 (TTL = duración sesión KC)
      ↓ ctx_id persistido en bkernel_db.context_sessions
      ↓ sbos-client aplica BitMask al escritorio:
        - Políticas dconf activadas
        - Apps habilitadas según BitMask
        - Home Nextcloud montado en ~/
        - Zona física activa en banexus
```

### Fase 3 — Trabajo del usuario

```
ctx_id propagado en TODOS los requests via OTel Baggage:
  traceparent: 00-{traceId}-{spanId}-01
  baggage: tenant.id=skull, empresa.id=maya, ctx.id=ctx-88291-a4f9

Kong (PEP): valida ctx_id en Redis en cada request (<2ms)
bAuth: verifica BitMask coherente con operación
biedata: adjunta ctx_id a operaciones fiscales (SIAT/AFIP/SAT)
bkernel: registra en audit_events con ctx_id (ISO 27001 A.8.15)
bsearch: aísla búsquedas por tenant_ctx
```

### Fase 4 — Logout o expiración

```
Usuario hace logout (o TTL expira)
      ↓ ctx_id → estado INVALIDADO
      ↓ Redis DB1: ctx_id eliminado (ya no válido para Kong)
      ↓ bkernel_db.context_sessions: status='invalid', invalidated_at=NOW()
        (NUNCA se elimina — ISO 27001 A.8.15 audit trail)
      ↓ sbos-client: revoca políticas dconf
      ↓ Home Nextcloud desmontado
      ↓ banexus: zona física desactivada
      ↓ Pod Fedora Lógico vuelve al pool disponible
```

---

## 7. Responsabilidad del bos sobre el Context Plane

| Momento | Acción del bos | Resultado |
|---|---|---|
| `bosctl deploy` — alta tenant | Inicializa Context Registry (Redis DB1 + bkernel_db) | Registry disponible para el tenant |
| Arranque de dispositivo | Crea dctx_id al detectar sbos-client via bhnexus | Contexto OS activo |
| Login de usuario | Promueve dctx_id → ctx_id, almacena en Redis+bkernel_db | ctx_id activo con BitMask |
| Context switch | Invalida ctx_id anterior, crea nuevo ctx_id | Trazabilidad limpia por empresa/POS |
| Idle timeout (15 min) | Transiciona ctx_id → SUSPENDIDO | Cumple ISO 27001 A.9.4.2 |
| Anomalía detectada | Transiciona ctx_id → BLOQUEADO | Step-up requerido (NIST 800-207) |
| `bosctl tenant suspend` | Invalida TODOS los ctx_id del tenant | Context Sessions destruidas |

---

## 8. API del Context Plane expuesta por el bos

### REST (HTTPS :9443)

```
POST   /api/v1/context/device/register    → registra dispositivo, crea dctx_id
POST   /api/v1/context/promote            → dctx_id → ctx_id (post-auth)
POST   /api/v1/context/switch             → context switching (nueva empresa/sucursal)
DELETE /api/v1/context/{ctx_id}           → invalidar ctx (logout)
GET    /api/v1/context/{ctx_id}           → lookup O(1) via Redis (usado por Kong)
GET    /api/v1/context/tenant/{tenant}    → listar ctx activos del tenant
POST   /api/v1/context/tenant/{tenant}/invalidate-all → suspensión de tenant
```

### JSON-RPC (Unix socket /run/bos/bos.sock)

```
bos.ctx.device.register  → registra dispositivo, retorna dctx_id
bos.ctx.promote          → dctx_id → ctx_id con BitMask
bos.ctx.switch           → cambio de empresa/sucursal/POS
bos.ctx.invalidate       → logout forzado
bos.ctx.get              → lookup de ctx_id (para Kong, biedata, etc.)
bos.ctx.list             → contextos activos de un tenant
bos.ctx.tenant.suspend   → invalidar todos los ctx de un tenant
bos.query.context        → saga de consulta: diagnóstico completo del Context Plane
```

### Comandos bosctl

```bash
bosctl context list --tenant=skull
bosctl context inspect ctx-88291-a4f9
bosctl context invalidate ctx-88291-a4f9
bosctl context history --user=3397708 --days=7
bosctl rpc bos.ctx.device.register '{"tenant_id":"skull","hostname":"caja-01"}'
bosctl rpc bos.ctx.promote '{"dctx_id":"dctx-device-991","kc_token":"eyJ..."}'
bosctl query context --tenant=skull
```

---

## 9. Integración con los Daemons Soberanos

| Daemon | Rol en el Context Plane |
|---|---|
| **bos** | **Dueño del Context Plane.** Crea/destruye Context Registry por tenant. Expone API ctx_id. Gestiona árbol organizacional. |
| **bkernel** | Persiste eventos contextuales en `audit_events`. Propaga `context.created`, `context.switched`, `context.expired` vía WAL. Mantiene `context_sessions` particionada. |
| **bAuth** | Consulta árbol de contextos del usuario al emitir JWT. Invalida contextos cuando cambian roles o BitMask. Verifica coherencia ctx activo vs BitMask. |
| **Kong (PEP)** | Plugin SBOS-Context: extrae ctx_id del baggage, llama bos Context API para lookup O(1), inyecta headers X-SBOS-* internos. |
| **bcompass** | Enruta workflows con contexto completo. Rutas de aprobación conocen tenant/empresa/sucursal del solicitante. |
| **bsearch** | Indexa con `tenant_ctx` para aislamiento de búsqueda por tenant. |
| **biedata** | Adjunta `ctx_id` a operaciones fiscales (SIAT/AFIP/SAT). |
| **bhnexus/banexus** | Usa ctx_id para validar acceso físico según POS/sucursal activo del usuario. Recibe registro de sbos-client al arranque. |

---

## 10. Modelo de Datos — DDL

### context_sessions (nueva tabla en bkernel_db)

```sql
CREATE TABLE context_sessions (
    ctx_id          VARCHAR(64)  PRIMARY KEY,
    dctx_id_prev    VARCHAR(64),               -- DeviceContext que fue promovido
    user_id         VARCHAR(128) NOT NULL,
    kc_session_id   VARCHAR(128) NOT NULL,

    tenant          VARCHAR(64)  NOT NULL,
    empresa         VARCHAR(64),
    sucursal        VARCHAR(64),
    pos_logico      VARCHAR(64),
    device_id       VARCHAR(128),

    hardware_type   VARCHAR(20)
                    CHECK (hardware_type IN ('physical','logical_pod','wsl','web_only')),

    pod             VARCHAR(128),
    namespace       VARCHAR(64),
    node            VARCHAR(64),
    cluster         VARCHAR(64),
    vps             VARCHAR(64),
    geo             VARCHAR(128),

    traceparent     VARCHAR(128),   -- W3C Trace Context al momento de creación
    bitmask         VARCHAR(20),    -- BitMask calculado por bAuth en hex

    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ  NOT NULL,
    switched_at     TIMESTAMPTZ,
    invalidated_at  TIMESTAMPTZ,
    status          VARCHAR(20)  NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','suspended','blocked','step_up',
                                      'switched','expired','invalid'))
) PARTITION BY RANGE (created_at);

CREATE INDEX idx_ctx_sessions_user    ON context_sessions (user_id, status);
CREATE INDEX idx_ctx_sessions_tenant  ON context_sessions (tenant, empresa, status);
CREATE INDEX idx_ctx_sessions_active  ON context_sessions (expires_at) WHERE status='active';
CREATE INDEX idx_ctx_sessions_dctx    ON context_sessions (dctx_id_prev);
```

### registered_devices (nueva tabla en bkernel_db — SBOS-052)

```sql
CREATE TABLE registered_devices (
    device_uuid          VARCHAR(128) PRIMARY KEY,
    tenant               VARCHAR(64)  NOT NULL,
    hostname             VARCHAR(128),
    hardware_type        VARCHAR(20)  NOT NULL
                         CHECK (hardware_type IN ('physical','logical_pod','wsl')),
    ip_last              INET,
    mac_address          VARCHAR(17),
    os_version           VARCHAR(64),
    sbos_client_version  VARCHAR(32),
    cert_serial          VARCHAR(128),
    registered_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at         TIMESTAMPTZ,
    revoked_at           TIMESTAMPTZ,
    status               VARCHAR(20) NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','revoked','suspended'))
) PARTITION BY LIST (tenant);

CREATE INDEX idx_devices_tenant ON registered_devices (tenant, status);
CREATE INDEX idx_devices_active ON registered_devices (last_seen_at) WHERE status='active';
```

### Extensiones a context_sessions para VDI Layer (SBOS-052)

```sql
ALTER TABLE context_sessions ADD COLUMN IF NOT EXISTS
  guacamole_session_id    VARCHAR(128);  -- solo para hardware_type='logical_pod'

ALTER TABLE context_sessions ADD COLUMN IF NOT EXISTS
  nextcloud_home_mounted  BOOLEAN DEFAULT FALSE;
```

---

## 11. Observabilidad Semántica

### El problema sin Context Plane

Kubernetes reporta:
```
pod/pos-api-77fa   CrashLoopBackOff   node-02
```

### Con Context Plane

```
El POS 23 ("Caja Norte") de la sucursal La Paz
del tenant skull / empresa maya,
operado por el usuario 3397708 (Juan García),
perdió conectividad a las 14:47 UTC
durante el procesamiento de la venta #V-2026-00891.
Pod: pos-api-77fa | Node: node-02 | VPS: vps-lapaz-01
ctx_id: ctx-88291-a4f9 | trace_id: 4bf92f3577b34da6a3ce929d0e0e4736
```

### Time Travel Observability (ISO 27001 A.8.15)

```sql
-- ¿Qué contextos estaban activos el 20 de mayo a las 14:47?
SELECT ctx_id, user_id, tenant, empresa, sucursal, pos_logico, pod, node
FROM context_sessions
WHERE tenant = 'skull'
  AND created_at <= '2026-05-20T14:47:00Z'
  AND (expires_at > '2026-05-20T14:47:00Z' OR switched_at > '2026-05-20T14:47:00Z')
ORDER BY created_at;
```

---

## 12. Tecnologías que habilitan el Context Plane

| Tecnología | Versión | Contribución |
|---|---|---|
| **OpenTelemetry Collector** | Stack SBOS-005 | Baggage Processor: inyecta ctx en todos los spans/logs automáticamente |
| **Redis DB1** | Stack SBOS-005 | Context Registry cache — O(1) lookup, TTL sincronizado con KC |
| **Kong OSS** | 3.9.x LTS | Plugin Lua SBOS-Context: extrae baggage, lookup bos, inyecta headers |
| **Keycloak** | 26.6.2 | JWT con `bos_contexts` claim: árbol de contextos autorizados |
| **Loki** | Stack SBOS-005 | Indexa por `ctx_id` como label; búsqueda por tenant/empresa/POS |
| **Grafana** | Stack SBOS-005 | Dashboard: contextos activos por tenant, distribución geográfica |
| **bkernel_db** | SBOS-023 §14 | Nueva tabla `context_sessions`; `audit_events` ya existente |

### Lo que requiere implementación nueva

| Componente | Tipo | Ubicación |
|---|---|---|
| Context Service | Go, en bos daemon | `internal/context/service.go` |
| Kong Plugin SBOS-Context | Lua | `fichas/netserver/kong/plugins/sbos-context/` |
| OTel Baggage Processor config | YAML | `fichas/monitorserver/otelcollector/config/` |
| DDL context_sessions | SQL migration | `migrations/bkernel_db/` |
| Reglas bKernel ctx | YAML rules | `blibs/bkernel/rules/context/` |
| bosctl context subcommands | Go | `cmd/bosctl/context.go` |

---

## 13. Principios de Diseño

| # | Principio | Justificación | Estándar |
|---|---|---|---|
| P1 | **El contexto es responsabilidad del bos** | Único componente con visión completa del árbol organizacional | NIST 800-207 (Policy Administrator) |
| P2 | **El contexto no vive en los pods** | K8s mueve pods; el contexto debe sobrevivir | SBOS-004 |
| P3 | **ctx_id inmutable una vez creado** | Trazabilidad limpia; el pod puede cambiar, el ctx_id no | ISO 27001 A.8.15 |
| P4 | **Context Switch = nueva sesión** | Trazabilidad limpia por empresa/POS | NIST 800-207 Tenet 3 |
| P5 | **Propagación via OTel Baggage** | Estándar de industria, cero invasión a fichas | W3C / CNCF |
| P6 | **Aislamiento estricto por tenant** | Ningún ctx_id de tenant A accede a datos de tenant B | ISO 27001 A.8.3 |
| P7 | **Degradación elegante** | Si Redis no disponible, bos sirve desde bkernel_db | Disponibilidad |
| P8 | **Audit trail inmutable** | context_sessions nunca se elimina; solo se marca invalidada | ISO 27001 A.8.15 |

---

## 14. Implementación en el código bos — estado actual vs objetivo

### Estado actual (30% implementado)

```go
// internal/domain/types.go — el struct existe
type CtxID struct {
    TenantID, EmpresaID, SucursalID, PosLogico string
    UserID, TraceParent, SpanID string
    CreatedAt, ExpiresAt time.Time
    Source string
}

// internal/server/jsonrpc.go — solo 2 métodos
"bos.ctx.create":   (*Server).rpcCtxCreate,
"bos.ctx.validate": (*Server).rpcCtxValidate,
```

### Objetivo (BOS-REPAIR-05 Fase 5)

```go
// internal/context/service.go — nuevo paquete
type Service struct {
    mu       sync.RWMutex
    devices  map[string]*DeviceContext   // dctx_id → DeviceContext
    sessions map[string]*SessionContext  // ctx_id → SessionContext
    logger   *slog.Logger
}

func (s *Service) RegisterDevice(...) (*DeviceContext, error)
func (s *Service) Promote(dctxID string, p PromoteParams) (*SessionContext, error)
func (s *Service) Switch(ctxID string, p SwitchParams) (*SessionContext, error)
func (s *Service) Invalidate(ctxID string) error
func (s *Service) Get(ctxID string) (*SessionContext, error)
func (s *Service) ListByTenant(tenant string) ([]*SessionContext, error)
func (s *Service) InvalidateAllByTenant(tenant string) (int, error)
func (s *Service) Validate(traceParent, tenantID string) (*ValidateResult, error)

// internal/server/jsonrpc.go — 7 nuevos métodos
"bos.ctx.device.register" → rpcCtxDeviceRegister
"bos.ctx.promote"         → rpcCtxPromote
"bos.ctx.switch"          → rpcCtxSwitch
"bos.ctx.invalidate"      → rpcCtxInvalidate
"bos.ctx.get"             → rpcCtxGet
"bos.ctx.list"            → rpcCtxList
"bos.ctx.tenant.suspend"  → rpcCtxTenantSuspend
```

---

## 15. Checklist de implementación (BOS-REPAIR)

```
Context Plane está completamente implementado cuando:

Infraestructura:
  ☐ DDL context_sessions aplicado en bkernel_db
  ☐ DDL registered_devices aplicado en bkernel_db
  ☐ Redis DB1 configurado como Context Registry
  ☐ Kong plugin SBOS-Context desplegado

Código bos:
  ☐ internal/context/types.go — DeviceContext, SessionContext, PromoteEvent
  ☐ internal/context/service.go — Service con todos los métodos
  ☐ internal/server/jsonrpc.go — 7 métodos bos.ctx.* registrados
  ☐ cmd/bosctl/context.go — subcomandos bosctl context

Verificación:
  ☐ bosctl rpc bos.ctx.device.register retorna dctx_id en <2s
  ☐ bosctl rpc bos.ctx.promote retorna ctx_id con bitmask>0
  ☐ bosctl rpc bos.ctx.get retorna contexto completo
  ☐ bosctl rpc bos.ctx.invalidate marca status=INVALIDADO
  ☐ bosctl query context retorna saga de diagnóstico completa
  ☐ Criterio C-13 del BOS-REPAIR-01: PASS
```

---

## 16. Preguntas que el Context Plane puede responder

```
¿Quién?        → usuario 3397708 (Juan García)
¿Desde dónde?  → POS 23 ("Caja Norte"), La Paz
¿Qué tenant?   → skull
¿Qué empresa?  → maya
¿Qué pod?      → pos-api-77fa
¿Qué nodo?     → node-02
¿Qué VPS?      → vps-lapaz-01
¿Qué región?   → Bolivia / La Paz
¿Cuándo?       → 2026-05-20T14:47:33.291Z
¿Sobre qué?    → Venta #V-2026-00891 (ERP Tryton)
¿Con qué rol?  → sales (BitMask 0x00000000008C87FF)
¿Evidencia?    → audit_events row #8812991 (ISO 27001 A.8.15)
```

---

*BOS-REPAIR-08 — SKULL · SBOS · Junio 2026*  
*Basado en: SBOS-049-CONTEXT-PLANE v2.0 (Mayo 2026)*  
*Referencia: BOS-REPAIR-01 §Capa 3, BOS-REPAIR-05 §Fase 5, BOS-REPAIR-06 §Rol C*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
