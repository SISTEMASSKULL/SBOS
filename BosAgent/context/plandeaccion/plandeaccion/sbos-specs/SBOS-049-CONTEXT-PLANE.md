# SBOS-049-CONTEXT-PLANE
## Plano de Contexto Distribuido: Semántica, Trazabilidad y Observabilidad Operacional
## Estándar HUMAN-DOC
### SKULL · SBOS · v2.0 · Mayo 2026

---

## 1. Propósito del Documento

Este documento formaliza la arquitectura del **Plano de Contexto Distribuido** de SBOS: la capa que dota de significado empresarial a todo lo que ocurre en la infraestructura. Consolida el razonamiento conceptual desarrollado y lo integra con los componentes ya definidos en el corpus técnico HUMAN-DOC, validado contra estándares internacionales y tecnologías de la industria.

El problema central que resuelve esta capa:

> Ubuntu sabe qué máquina existe.  
> Kubernetes sabe qué pod corre.  
> Keycloak sabe quién es el usuario.  
> **SBOS sabe qué significa todo eso junto.**

**Corrección v2.0 respecto a v1.0:** La responsabilidad de inicializar, mantener y destruir el Context Plane pertenece al **bos (IAM Installer)** como parte de su rol de Infrastructure Provisioning & Lifecycle Orchestrator. Las secciones §10 y §11 han sido corregidas en consecuencia.

---

## 2. Validación contra Estándares Internacionales y la Industria

Antes de describir la arquitectura, este documento establece su base normativa y tecnológica. El Context Plane de SBOS no es una invención aislada: cada uno de sus componentes tiene respaldo en estándares activos y en tecnologías de producción probadas.

### 2.1 OpenTelemetry + W3C Trace Context (CNCF / W3C)

El estándar **W3C Trace Context** (Recomendación W3C) define el formato universal para propagar identidad de traza entre servicios mediante los headers HTTP `traceparent` y `tracestate`. **OpenTelemetry** (proyecto CNCF graduado) lo implementa nativamente y lo extiende con el mecanismo **Baggage**: pares clave-valor que viajan junto al contexto de traza a través de todas las fronteras de servicio.

El Baggage de OpenTelemetry es exactamente el mecanismo que SBOS necesita para el `ctx_id`:

```
Baggage: tenant.id=skull, empresa.id=maya, sucursal.id=lapaz,
         pos.id=POS-23, user.id=3397708, ctx.id=ctx-88291-a4f9
```

Cualquier servicio del stack (Go, Rust, Python) puede leer este baggage automáticamente. El OpenTelemetry Collector puede configurarse con un **Baggage Processor** que inyecta estos valores como atributos en todos los spans, logs y métricas — sin modificar el código de cada aplicación. Esto es compatible con el principio de **cero invasión** (ADR-001, P2 SBOS-004).

**Referencias:** W3C Trace Context Level 1 (2019); OpenTelemetry Baggage API Specification; CNCF OpenTelemetry Project.

### 2.2 NIST SP 800-207 — Zero Trust Architecture

El estándar **NIST SP 800-207** (Zero Trust Architecture) establece que el acceso a recursos debe concederse **por sesión**, basado en política dinámica que incorpora: nivel de identidad, postura del dispositivo, contexto de sesión (tiempo, red, ubicación como señal) y comportamiento reciente. Define tres componentes obligatorios:

| Componente NIST 800-207 | Equivalente en SBOS |
|---|---|
| Policy Engine (PE) | bAuth — evalúa BitMask, RolTemplate, ctx activo |
| Policy Administrator (PA) | bos IAM Installer — provisiona y destruye contextos de tenant |
| Policy Enforcement Point (PEP) | Kong API Gateway + plugin SBOS-Context |

El `ctx_id` de SBOS implementa la verificación continua por sesión que exige el estándar: cada request lleva el ctx_id, Kong valida su existencia en el Context Registry (Redis), y bAuth verifica que el contexto activo sea coherente con el BitMask del usuario. Esto se alinea directamente con el **Tenet 3** de NIST 800-207: *"Grant per-session access to follow least-privilege, ensuring privileges are time-bound."*

**Referencia:** NIST Special Publication 800-207 (2020), National Institute of Standards and Technology.

### 2.3 ISO/IEC 27001:2022 — Controles A.8.15 y A.8.16

Los controles de logging y monitoreo de **ISO/IEC 27001:2022** exigen:

- **A.8.15 (Logging):** producir, almacenar, proteger y analizar logs con contexto completo. Los auditores exigen que cada entrada de log tenga: timestamp, usuario, acción, recurso afectado, resultado y contexto de sesión. Un audit log sin `ctx_id` no puede demostrar en qué empresa o POS ocurrió un evento — falla la auditoría.
- **A.8.16 (Monitoring activities):** detección de comportamiento anómalo en tiempo real. Sin el contexto distribuido, es imposible distinguir si un evento es anómalo dentro del contexto correcto.

La tabla `audit_events` de `bkernel_db` (ya definida en SBOS-023) es el mecanismo de cumplimiento de A.8.15. El `ctx_id` en cada fila es lo que permite el análisis cruzado que exige A.8.16.

**Referencia:** ISO/IEC 27001:2022, Annex A Controls 8.15 y 8.16.

### 2.4 Patrón Control Plane / Data Plane (industria)

La separación en **planos** (Control Plane, Data Plane, Management Plane) es el patrón fundamental de sistemas distribuidos modernos. Kubernetes lo implementa de forma canónica. El IAM Installer de SBOS ya aplica este patrón (SBOS-018): es el Control Plane soberano que gestiona el ciclo de vida de la infraestructura. El Context Plane es una extensión natural de esa responsabilidad hacia la dimensión semántica empresarial.

La arquitectura **IAM multi-tenant** con un Control Plane centralizado que gestiona Data Planes dedicados por cliente (como Cloud-IAM, Kamaji, o el modelo Entra de Microsoft) es el patrón establecido en la industria para sistemas que sirven múltiples organizaciones desde una infraestructura compartida.

**Referencia:** CNCF Kubernetes Operator Pattern; "Three Layers of Modern Software Architecture: Control, Data, and Management Planes" (Parashar, 2025).

### 2.5 Identity Lifecycle como Security Control Plane

La arquitectura de identidad moderna (Gartner, KuppingerCole 2025) establece que el **ciclo de vida de identidad es un security control plane** que abarca desde el aprovisionamiento hasta el desaprovisionamiento, e incluye la gestión del contexto operativo activo. La provisión del tenant como unidad de contexto (realm KC + namespace K8s + bases de datos) es una práctica establecida, donde el IAM Installer actúa como el orquestador de ese ciclo.

**Referencia:** KuppingerCole "2025 Identity Fabric and IAM Reference Architecture"; IBM IAM Deployment Guide (2026).

---

## 3. Filosofía de Capas: Separación de Responsabilidades

SBOS no reemplaza ninguna capa del stack existente. Se apoya en ellas y agrega la dimensión que ninguna posee individualmente: **semántica empresarial distribuida**.

```
Ubuntu (Hardware Abstraction Layer)
    ↓  aporta: IP, hostname, MAC, nodo físico, filesystem
Kubernetes (Distributed Execution Engine)
    ↓  aporta: pod, namespace, labels, deployment, cluster
Keycloak (Identity Provider)
    ↓  aporta: usuario, roles, claims, sesión, permisos
bos IAM Installer (Sovereign Control Plane) ← RESPONSABLE DEL CONTEXT PLANE
    ↓  aporta: provisionamiento, ciclo de vida tenant, inicialización
              y destrucción de Context Sessions, Context Registry
SBOS Context Plane (capa transversal activada por bos)
    ↓  aporta: tenant, empresa, sucursal, POS, ctx_id,
              trazabilidad, auditoría, correlación, semántica
Aplicaciones / Fichas / POS / ERP / Servicios
```

### Tabla de Responsabilidades

| Capa | Entiende | NO entiende |
|---|---|---|
| Ubuntu | Máquinas, procesos, red | Tenants, empresas, POS |
| Kubernetes | Pods, namespaces, labels | Qué empresa representa un pod |
| Keycloak | Usuarios, roles, sesiones | Dónde opera el usuario ahora mismo |
| **bos IAM Installer** | **Ciclo de vida completo: infraestructura + contexto** | Scheduling, networking, container orchestration |
| **SBOS Context Plane** | **Semántica empresarial distribuida en tiempo real** | Aprovisionamiento inicial (ese es el bos) |

**Principio fundamental:** el sistema no debe preguntarse `¿dónde corre este pod?` sino `¿qué contexto empresarial representa este pod ahora mismo?`

---

## 4. El Contexto Operativo como Objeto de Primera Clase

### 4.1 Definición

El **Contexto Operativo** es la combinación de dimensiones que responde: quién opera, desde dónde, sobre qué tenant, en qué empresa, en qué sucursal, desde qué POS, en qué pod, en qué nodo, en qué instante exacto.

Ruta canónica:

```
/dist/{tenant}/emp/{empresa}/suc/{sucursal}/user/{user_id}/pos/{pos_id}
```

Ejemplo real:

```
/dist/skull/emp/maya/suc/lapaz/user/3397708/pos/23
```

### 4.2 Dos Dimensiones del Contexto

**Identity Context** — quién es; gestionado por Keycloak; no cambia frecuentemente:
```json
{
  "user_id": "3397708",
  "roles": ["admin", "sales"],
  "bos_contexts": ["skull/maya/lapaz", "skull/inka/lapaz"]
}
```

**Execution Context** — dónde opera ahora mismo; gestionado por SBOS Context Plane; cambia dinámicamente:
```json
{
  "tenant": "skull",
  "empresa": "maya",
  "sucursal": "lapaz",
  "pos": "23",
  "activo_desde": "2026-05-20T14:32:00Z"
}
```

Keycloak entrega el árbol de contextos autorizados en el JWT. El bos IAM Installer crea la Context Session cuando el usuario activa un contexto. El bos mantiene el Context Registry como parte de su estado operacional del tenant.

### 4.3 Árbol de Contextos Permitidos

Un usuario posee un árbol de contextos autorizados según sus claims en Keycloak:

```
usuario 3397708
├── skull/maya/lapaz/pos23    ← contexto activo actual
├── skull/maya/lapaz/pos24
├── skull/maya/santacruz/pos2
├── skull/inka/lapaz/pos7
└── skull/admin/global
```

---

## 5. Context Session, ctx_id y Propagación

### 5.1 Responsabilidad del bos IAM Installer

El bos IAM Installer es responsable del Context Plane en tres momentos del ciclo de vida del tenant:

| Momento | Acción del bos | Resultado |
|---|---|---|
| `bosctl deploy` (alta de tenant) | Inicializa el Context Registry del tenant (tablas Redis + bkernel_db) | Context Registry disponible para el tenant |
| Login de usuario | API interna del bos crea la Context Session y genera el `ctx_id` | ctx_id almacenado en Redis + bkernel_db |
| `bosctl tenant suspend/remove` | Invalida todos los ctx_id activos del tenant | Context Sessions destruidas, audit trail preservado |

El bos IAM Installer ya gestiona el realm KC, el namespace K8s y las bases de datos del tenant (SBOS-018 §18.1). El Context Registry es una extensión natural de esa responsabilidad: el bos sabe que el tenant existe, sabe qué empresas y sucursales tiene configuradas, y es el único componente con visión completa del árbol organizacional.

### 5.2 Flujo de Creación del ctx_id

```
Usuario Login
      ↓
Keycloak autentica → emite JWT con bos_contexts
      ↓
Kong extrae JWT → llama bos Context API
      ↓
bos valida árbol de contextos del usuario contra .sbos_state.json del tenant
      ↓
bos crea Context Session → genera ctx_id
      ↓
bos almacena ctx_id en Redis (TTL = duración sesión KC)
bos persiste en bkernel_db.context_sessions
      ↓
ctx_id retorna al cliente → se propaga en todos los requests subsiguientes
```

### 5.3 Estructura del ctx_id

```json
{
  "ctx_id": "ctx-88291-a4f9",

  "tenant": "skull",
  "empresa": "maya",
  "sucursal": "lapaz",
  "pos_logico": "POS-23",

  "user_id": "3397708",
  "session_kc": "kc-sess-7fab12",

  "pod": "pos-api-77fa",
  "namespace": "skull-maya",
  "node": "node-02",
  "cluster": "cluster-bolivia",
  "vps": "vps-lapaz-01",
  "geo": "La Paz, Bolivia",

  "created_at": "2026-05-20T14:32:00Z",
  "expires_at": "2026-05-20T22:32:00Z"
}
```

### 5.4 Propagación del ctx_id (via OpenTelemetry Baggage)

La propagación del contexto sigue el estándar **OpenTelemetry Baggage + W3C Trace Context**. En cada request saliente de Kong se inyectan dos headers complementarios:

```
traceparent: 00-{trace_id_32hex}-{parent_id_16hex}-01   ← W3C Trace Context
baggage: ctx.id=ctx-88291-a4f9,tenant.id=skull,empresa.id=maya,
         sucursal.id=lapaz,pos.id=POS-23,user.id=3397708
```

El **OTel Collector** (ya en el stack de observabilidad, SBOS-005) con el **Baggage Processor** activo extrae automáticamente `tenant.id`, `empresa.id`, `pos.id` y `ctx.id` como atributos en todos los spans y logs — sin modificar el código de las fichas. Esto implementa cero invasión sobre el plano de observabilidad.

| Canal | Mecanismo |
|---|---|
| APIs REST (Kong) | Header `baggage` + `traceparent` (W3C) |
| WAL → bKernel | Campo `ctx_id` en el evento CDC |
| WebSocket (Centrifugo) | Metadato del canal de sesión |
| Logs (Loki) | Atributo `ctx_id` vía OTel Baggage Processor |
| Auditoría (bkernel_db.audit_events) | Columna `ctx_id` en cada registro |
| bCompass workflows | Atributo de contexto de la ruta |
| bSearch | Campo `tenant_ctx` en el documento indexado |

### 5.5 Context Switching

El usuario puede cambiar de contexto operativo sin cerrar sesión:

```
POST /api/v1/context/switch
{
  "target": "skull/inka/lapaz/pos7"
}
```

El bos:
1. Invalida el `ctx_id` anterior en Redis (marca como `switched` en bkernel_db)
2. Verifica que el target esté en el árbol autorizado del usuario (JWT claims)
3. Crea nueva Context Session con nuevo `ctx_id`
4. Emite evento `context.switched` → bKernel lo propaga al audit_events
5. Centrifugo notifica al frontend del nuevo contexto activo

---

## 6. POS Lógico vs POS Físico

### 6.1 POS Lógico

Identidad empresarial. Existe independientemente del hardware:

```json
{
  "pos_id": "POS-23",
  "nombre": "Caja Norte",
  "tenant": "skull",
  "empresa": "maya",
  "sucursal": "lapaz",
  "estado": "activo"
}
```

Creado y gestionado por el **bos IAM Installer** como parte del seed file del tenant (SBOS-037).

### 6.2 POS Físico

Hardware real con propiedades de red e infraestructura. Registrado por **banexus** (SBOS-039) cuando detecta el dispositivo en la red:

```json
{
  "device_id": "DEVICE-991",
  "hostname": "caja-lpz-23",
  "ip": "10.0.0.55",
  "mac": "00:1A:2B:3C:4D:5E",
  "geo": "La Paz, Bolivia",
  "nodo_k8s": "node-02"
}
```

### 6.3 Asociación Dinámica

El bos vincula lógico ↔ físico al momento del despliegue y cuando banexus detecta nuevo hardware:

```json
{
  "pos_id": "POS-23",
  "device_id": "DEVICE-991",
  "ctx_id": "ctx-88291-a4f9",
  "vinculado_en": "2026-05-20T14:32:00Z"
}
```

Si el hardware cambia, el POS Lógico se reasigna. El `pos_id` permanece estable; el `device_id` cambia. El bos registra la reasignación en `.sbos_state.json` y emite `pos.reattached`.

---

## 7. Tenant Lógico vs Tenant Físico

Un tenant lógico (`skull`, `inka`) corresponde a: realm Keycloak + namespace K8s + bases de datos dedicadas. El bos IAM Installer crea y destruye esa unidad completa (SBOS-018 §18.1).

Un tenant físico es la infraestructura que lo aloja. La separación es fundamental:

```
Tenant "skull" (lógico — creado por bos)
  ├── bAuth     → VPS La Paz  (identityserver)
  ├── POS API   → VPS La Paz  (netserver)
  └── Analytics → VPS Miami   (monitorserver)

VPS La Paz (físico — gestionado por K8s)
  ├── namespace skull-*  (tenant skull)
  ├── namespace inka-*   (tenant inka)
  └── namespace maya-*   (tenant maya)
```

**Regla invariante:** nunca asumir `tenant_lógico == servidor_físico`. El bos conoce el mapeo completo en `.sbos_state.json`. Kubernetes no entiende tenants — solo namespaces y labels.

---

## 8. Context Registry Distribuido

### 8.1 Responsabilidad del bos sobre el Registry

El bos IAM Installer es el dueño del Context Registry. Al crear un tenant, el bos:
- Inicializa la partición Redis para el tenant (`ctx:{tenant}:*`)
- Crea la partición de `context_sessions` en bkernel_db para el tenant
- Configura el TTL máximo de ctx_id alineado con el `ssoSessionMaxLifespan` del realm KC

Al suspender o eliminar un tenant, el bos:
- Invalida masivamente todos los ctx_id activos del tenant en Redis
- Marca todas las context_sessions del tenant como `invalidated` en bkernel_db (no las elimina — son evidencia de auditoría)

### 8.2 Flujo de Lookup en cada Request

```
Request llega a Kong con header baggage: ctx.id=ctx-88291-a4f9
         ↓
Kong Plugin SBOS-Context extrae ctx_id
         ↓
Redis GET ctx:skull:ctx-88291-a4f9    (lookup O(1))
         ↓
¿Encontrado y TTL > 0?
  SÍ → adjuntar contexto completo como headers internos al servicio destino
  NO → HTTP 401 + evento context.invalid emitido vía bKernel
```

### 8.3 Almacenamiento Dual

| Componente | Almacenamiento | Propósito |
|---|---|---|
| ctx_id → datos completos | Redis (TTL = sesión KC) | Lookup O(1) en tiempo real |
| Árbol de contextos del usuario | bkernel_db.context_sessions | Historial, auditoría, time travel |
| Historial de context switches | bkernel_db.context_sessions | Trazabilidad ISO 27001 A.8.15 |

---

## 9. Observabilidad Semántica

### 9.1 El Problema sin Contexto

Kubernetes reporta:
```
pod/pos-api-77fa   CrashLoopBackOff   node-02
```

SBOS Context Plane, gracias al ctx_id y al OTel Baggage Processor, enriquece ese evento hasta:

```
El POS 23 ("Caja Norte") de la sucursal La Paz
del tenant skull / empresa maya,
operado por el usuario 3397708 (Juan García),
perdió conectividad a las 14:47 UTC
durante el procesamiento de la venta #V-2026-00891.
Pod: pos-api-77fa | Node: node-02 | VPS: vps-lapaz-01
trace_id: ctx-88291-a4f9-1716220847391-f3a1
```

### 9.2 Correlation ID (trace_id)

Compatible con W3C Trace Context `traceparent`:

```
trace_id = {32 hex chars del traceparent}
parent_id = {16 hex chars del traceparent}
ctx_id = ctx-88291-a4f9   (en baggage, correlacionado)
```

El trace_id de W3C es la trazabilidad técnica. El ctx_id es la trazabilidad empresarial. Ambos viajan juntos. Jaeger/Tempo reconstruye el span técnico. bkernel_db.audit_events reconstruye el contexto empresarial.

### 9.3 Time Travel Observability

bkernel_db.context_sessions + audit_events permiten reconstruir el estado completo del sistema en cualquier instante pasado:

```sql
-- ¿Qué contextos estaban activos el 20 de mayo a las 14:47?
SELECT ctx_id, user_id, tenant, empresa, sucursal, pos_logico, pod, node
FROM context_sessions
WHERE tenant = 'skull'
  AND status = 'active'
  AND created_at <= '2026-05-20T14:47:00Z'
  AND (expires_at > '2026-05-20T14:47:00Z' OR switched_at > '2026-05-20T14:47:00Z')
ORDER BY created_at;
```

Esto cumple con el requisito de auditoría forense de **ISO 27001:2022 A.8.15**: audit trails con contexto completo que permiten reconstruir eventos post-incidente.

---

## 10. Responsabilidad del bos IAM Installer sobre el Context Plane

El bos es el único componente del sistema con visión completa de todos los tenants, sus empresas, sucursales y POS. Es el natural responsable del Context Plane por las siguientes razones:

| Razón | Detalle |
|---|---|
| **Ya conoce el árbol organizacional** | El seed file (SBOS-037) define empresas, sucursales y POS desde el despliegue |
| **Ya gestiona el ciclo de vida del tenant** | Crea realm KC + namespace K8s + BDs. El Context Registry es una extensión de esa responsabilidad |
| **Ya tiene .sbos_state.json** | El estado del Context Registry puede persistir como sección adicional en el state file del bos |
| **Ya es el Control Plane soberano** | Patrón arquitectónico establecido (NIST 800-207 Policy Administrator) |
| **Alineación con IAM lifecycle** | Industria establece que el provisioner es responsable del contexto de sesión desde alta hasta baja del tenant |

### 10.1 API del Context Plane expuesta por el bos

El bos expone los siguientes endpoints de Context Plane en su API REST (HTTPS `0.0.0.0:9443`):

```
POST   /api/v1/context/create          → crea ctx_id al login
POST   /api/v1/context/switch          → context switching
DELETE /api/v1/context/{ctx_id}        → invalidar ctx (logout)
GET    /api/v1/context/{ctx_id}        → lookup (usado por Kong plugin)
GET    /api/v1/context/tenant/{tenant} → listar ctx activos del tenant
POST   /api/v1/context/tenant/{tenant}/invalidate-all  → suspensión de tenant
```

### 10.2 Nuevos Comandos bosctl

```bash
bosctl context list --tenant=skull          # ctx_id activos
bosctl context inspect ctx-88291-a4f9       # detalle completo
bosctl context invalidate ctx-88291-a4f9    # forzar logout
bosctl context history --user=3397708 --days=7  # historial de sesiones
```

---

## 11. Integración con los Daemons Soberanos

| Daemon | Rol en el Context Plane |
|---|---|
| **bos (IAM Installer)** | **Dueño del Context Plane.** Crea/destruye Context Registry por tenant. Expone API de ctx_id. Gestiona árbol organizacional. |
| **bkernel** | Persiste eventos contextuales en `audit_events`. Propaga `context.created`, `context.switched`, `context.expired` vía WAL. Mantiene `context_sessions` particionada. |
| **bauth** | Consulta el árbol de contextos del usuario al emitir el JWT. Invalida contextos cuando cambian los roles o el BitMask. Verifica coherencia ctx activo vs BitMask. |
| **Kong (PEP)** | Plugin SBOS-Context: extrae ctx_id del baggage, llama bos Context API para lookup, inyecta contexto completo en headers internos. |
| **bcompass** | Enruta workflows con contexto completo. Las rutas de aprobación conocen el tenant/empresa/sucursal del solicitante. |
| **bsearch** | Indexa con `tenant_ctx` para garantizar aislamiento de búsqueda por tenant. |
| **biedata** | Adjunta `ctx_id` a todas las operaciones fiscales para trazabilidad de auditoría externa (requerimiento SIAT/AFIP/SAT). |
| **bhnexus / banexus** | Usa el contexto para validar acceso físico según el POS/sucursal activo del usuario. |
| **Centrifugo** | Notifica en tiempo real los cambios de contexto al frontend (Core UI / SBOS VDI). |

---

## 12. Modelo de Datos — context_sessions

Nueva tabla en `bkernel_db` (DDL propuesto):

```sql
CREATE TABLE context_sessions (
    ctx_id          VARCHAR(64)  PRIMARY KEY,
    user_id         VARCHAR(128) NOT NULL,
    kc_session_id   VARCHAR(128) NOT NULL,

    tenant          VARCHAR(64)  NOT NULL,
    empresa         VARCHAR(64),
    sucursal        VARCHAR(64),
    pos_logico      VARCHAR(64),
    device_id       VARCHAR(128),

    pod             VARCHAR(128),
    namespace       VARCHAR(64),
    node            VARCHAR(64),
    cluster         VARCHAR(64),
    vps             VARCHAR(64),
    geo             VARCHAR(128),

    -- OTel Trace Context
    traceparent     VARCHAR(128),   -- W3C traceparent al momento de creación

    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ  NOT NULL,
    switched_at     TIMESTAMPTZ,
    invalidated_at  TIMESTAMPTZ,
    status          VARCHAR(20)  NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','switched','expired','invalid'))
) PARTITION BY RANGE (created_at);

CREATE INDEX idx_ctx_sessions_user    ON context_sessions (user_id, status);
CREATE INDEX idx_ctx_sessions_tenant  ON context_sessions (tenant, empresa, status);
CREATE INDEX idx_ctx_sessions_active  ON context_sessions (expires_at) WHERE status = 'active';
```

---

## 13. Tecnologías Existentes que Habilitan el Context Plane

Este plano no se construye desde cero. Se apoya en componentes ya presentes en el stack SBOS:

| Tecnología | Versión en SBOS | Contribución al Context Plane |
|---|---|---|
| **OpenTelemetry Collector** | Stack observabilidad SBOS-005 | Baggage Processor: inyecta ctx automáticamente en todos los spans/logs |
| **Redis** | Stack SBOS-005 | Context Registry cache (O(1) lookup, TTL sincronizado con KC) |
| **Kong OSS** | ADR-010 (3.9.x LTS) | Plugin Lua SBOS-Context: extrae baggage, llama bos API, inyecta headers internos |
| **Keycloak** | SBOS-029 | JWT con `bos_contexts` claim: árbol de contextos autorizados |
| **Loki** | Stack observabilidad SBOS-005 | Indexa por `ctx_id` como label; búsqueda semántica por tenant/empresa/POS |
| **Grafana** | Stack observabilidad SBOS-005 | Dashboard: contextos activos por tenant, distribución geográfica |
| **Jaeger/Tempo** | Stack observabilidad SBOS-005 | Visualización de traces correlacionados con ctx_id |
| **bkernel_db** | SBOS-023 §14 | Nueva tabla `context_sessions`; audit_events ya existente |
| **Centrifugo** | SBOS-040 | Notificación real-time de cambios de contexto al frontend |

### Lo que requiere implementación nueva

| Componente | Tipo | Ubicación en el monorepo |
|---|---|---|
| Context API (módulo bos) | Go, integrado en el binario bos | `src/cmd/bos/context/` |
| Kong Plugin SBOS-Context | Lua (Kong plugin) | `fichas/netserver/kong/plugins/sbos-context/` |
| OTel Collector config (baggage processor) | YAML config | `fichas/monitorserver/otelcollector/config/` |
| DDL context_sessions | SQL migration | `migrations/bkernel_db/` |
| Reglas bKernel para eventos ctx | YAML rules | `blibs/bkernel/rules/context/` |
| bosctl context subcommands | Go, integrado en bosctl | `src/cmd/bosctl/context/` |

---

## 14. Principios de Diseño

| # | Principio | Justificación | Estándar |
|---|---|---|---|
| P1 | **El contexto es responsabilidad del bos** | Es el único componente con visión completa del árbol organizacional y ciclo de vida del tenant | NIST 800-207 (Policy Administrator) |
| P2 | **El contexto no vive en los pods** | Kubernetes mueve pods; el contexto debe sobrevivir | SBOS-004 Principios |
| P3 | **ctx_id inmutable una vez creado** | Trazabilidad limpia; el pod puede cambiar, el ctx_id no | ISO 27001 A.8.15 |
| P4 | **Context Switch = nueva sesión** | Trazabilidad limpia por empresa/POS | NIST 800-207 Tenet 3 |
| P5 | **Propagación via OTel Baggage** | Estándar de industria, cero invasión a fichas | W3C / CNCF OpenTelemetry |
| P6 | **Aislamiento estricto por tenant** | Ningún ctx_id de tenant A puede acceder a datos de tenant B | ISO 27001 A.8.3 |
| P7 | **Degradación elegante** | Si Redis no está disponible, bos sirve desde bkernel_db (mayor latencia) | Disponibilidad |
| P8 | **Audit trail inmutable** | context_sessions nunca se elimina; solo se marca invalidada | ISO 27001 A.8.15 |

---

## 15. Preguntas que el Context Plane Puede Responder

El objetivo arquitectónico concreto: dado cualquier evento del sistema, poder responder:

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
¿Con qué rol?  → sales (BitMask activa en contexto skull/maya)
¿Evidencia?    → audit_events row #8812991 (ISO 27001 A.8.15)
```

---

## Trazabilidad

| Sección | Fuente | Relación |
|---|---|---|
| §1 Propósito | Documento conceptual (sesión Mayo 2026) + corrección v2.0 | Corrección: bos como responsable del Context Plane |
| §2.1 OTel + W3C | W3C Trace Context Rec. (2019); OpenTelemetry Baggage API Spec; CNCF | Validación externa — mecanismo técnico de propagación |
| §2.2 NIST 800-207 | NIST SP 800-207 (2020) | Validación ZTA: PE/PA/PEP mapean directamente a bAuth/bos/Kong |
| §2.3 ISO 27001 | ISO/IEC 27001:2022 A.8.15, A.8.16 | audit_events + ctx_id como evidencia de auditoría |
| §2.4 Planos | Parashar (2025) "Three Layers of Modern Software Architecture"; CNCF K8s Operator Pattern | Patrón Control/Data/Management Plane validado en industria |
| §2.5 IAM Lifecycle | KuppingerCole 2025 Identity Fabric; IBM IAM Deployment Guide 2026 | IAM provisioner como responsable del contexto de sesión |
| §3–§9 Arquitectura | Documento conceptual (sesión Mayo 2026) + SBOS-002, SBOS-018, SBOS-023, SBOS-030 | Formalizado con tipos, flujos y estructuras JSON |
| §10 Responsabilidad bos | SBOS-018-DAEMON-BOS v1.2 §18.1 + NIST 800-207 + corrección v2.0 | Corrección de v1.0: bos como dueño, no capacidad transversal |
| §11 Daemons | SBOS-018, SBOS-023, SBOS-021, SBOS-027, SBOS-026, SBOS-024, SBOS-039, SBOS-040 | Cada daemon revisado para su rol en el Context Plane |
| §12 DDL | SBOS-023 §14 (bkernel_db schema) | Nueva tabla, agrega columna `traceparent` vs v1.0 |
| §13 Tecnologías | SBOS-005 stack; ADR-010; SBOS-040; SBOS-029 | Reutilización máxima del stack existente |
| §14 Principios | SBOS-004-RULES; NIST 800-207; ISO 27001:2022; W3C/CNCF | Principios mapeados a estándares internacionales |

---

_SKULL · SBOS · SBOS-049-CONTEXT-PLANE · HUMAN-DOC v2.0 · Mayo 2026_
_Reemplaza: v1.0 (Mayo 2026)_
_Correcciones v2.0: bos IAM Installer como responsable del Context Plane; validación contra OTel/W3C/NIST/ISO; §2 Validación añadida; §10 reescrito; P1 añadido_

---

## 16. Ciclo de Vida Real de una Sesión — Desde Fedora hasta el POS

Esta sección describe el ciclo completo tal como ocurre en producción, desde que el dispositivo arranca hasta que el usuario opera contabilidad, chapas y el cajón del POS.

### 16.1 Fase 1 — Dispositivo Activo sin Usuario (Pre-Autenticación)

El nodo Fedora arranca. banexus levanta como servicio `systemd --user` y se registra con bhnexus vía mTLS. El bos IAM Installer detecta el dispositivo y crea un **Device Context**:

```json
{
  "dctx_id": "dctx-device-991",
  "device_id": "DEVICE-991",
  "hostname": "caja-lpz-23",
  "ip": "10.0.0.55",
  "mac": "00:1A:2B:3C:4D:5E",
  "nodo_k8s": "node-02",
  "tenant": "skull",
  "status": "pre-auth",
  "bitmask": "0x0000000000000000",   ← cero: nadie autenticado
  "usuario": null
}
```

**Lo que el usuario puede hacer en este estado:**
- Usar aplicaciones que no pasan por banexus ni bAuth: navegador web (YouTube), herramientas de oficina (LibreOffice/Excel), etc.
- Todo lo que NO requiera BitMask: el OS funciona normalmente.

**Lo que el usuario NO puede hacer:**
- Abrir chapas (Bit 16/17/18 = 0)
- Abrir el cajón del POS (Bit 15 = 0)
- Acceder a Tryton/contabilidad (Bit 12 = 0)
- Operar el POS (Bit 14 = 0)

El bos registra toda la actividad del dispositivo bajo `dctx_id`. Hay trazabilidad — pero sin identidad de usuario.

### 16.2 Fase 2 — Autenticación con Keycloak vía bAuth (Promoción de Contexto)

El usuario se autentica (QR, NFC, huella, contraseña — según el LoA requerido). El flujo es:

```
Usuario presenta credencial
      ↓
banexus intercepta (udev + libusb, ANTES de que Fedora vea el input)
      ↓
banexus → bhnexus (WebSocket mTLS, ~2ms)
      ↓
bhnexus → Keycloak (valida credencial)
      ↓
Keycloak emite JWT con bos_contexts = [skull/maya/lapaz/pos23]
      ↓
bhnexus → bAuth (Unix socket, ~3ms)
      ↓
bAuth evalúa 3 dominios simultáneos:
  Dominio Lógico:    ¿red autorizada? ¿LoA suficiente? ¿apps permitidas?
  Dominio Físico:    ¿zona autorizada? ¿dentro de horario laboral?
  Dominio Financiero: ¿límites transaccionales?
      ↓
bAuth calcula BitMask 64 bits para este usuario en este contexto
      ↓
bos crea Context Session:
  ctx_id: ctx-88291-a4f9
  vincula dctx_id_previo: dctx-device-991   ← historia pre-auth preservada
  status: active
      ↓
bhnexus envía BitMask a banexus (~15ms total desde presentar credencial)
```

### 16.3 Fase 3 — Contexto Activo: El BitMask Habilita Capacidades Reales

Una vez autenticado, el BitMask de 64 bits define exactamente qué puede hacer el usuario. Cada bit corresponde a una capacidad física o lógica real:

```
BITMASK EJEMPLO — cajero de turno, sucursal La Paz:

Bit 10: SESSION_VALID    = 1  → sesión activa y verificada
Bit 11: SHELL_UNLOCK     = 1  → Fedora desbloqueado para este usuario
Bit 12: APP_TRYTON       = 1  → puede abrir contabilidad / ERP
Bit 14: APP_SALEOR       = 1  → puede operar ventas / e-commerce
Bit 15: DRAWER_OPEN      = 1  → puede abrir el cajón del POS (relé físico)
Bit 16: DOOR_ZONE_A      = 1  → puede abrir chapas de Zona Ventas
Bit 17: DOOR_ZONE_B      = 0  → NO puede entrar al almacén
Bit 18: DOOR_ZONE_C      = 0  → NO puede entrar a zona restringida
Bit 21: NETWORK_EXTERNAL = 1  → puede navegar internet
Bit 23: ADMIN_PANEL      = 0  → NO es administrador
```

**En la vida real, esto significa:**

| Acción del usuario | Lo que ocurre | Componente |
|---|---|---|
| Presenta QR en la chapa de Zona Ventas | banexus evalúa Bit 16=1 → envía OPEN_RELAY al controlador serial → chapa abre en 3 segundos | banexus → serial |
| Abre el cajón del POS | banexus evalúa Bit 15=1 → RELAY_01 OPEN → cajón abre | banexus → actuador |
| Abre Tryton (contabilidad) | banexus evalúa Bit 12=1 → libera acceso → Tryton valida JWT de KC | banexus + Kong |
| Intenta entrar al almacén | banexus evalúa Bit 17=0 → DENY → chapa no abre → evento `access.denied` | banexus |
| Intenta abrir panel admin | Bit 23=0 → interfaz bloqueada → evento `unauthorized_attempt` | banexus + Kong |
| Usa YouTube sin autenticar | No pasa por banexus → disponible siempre | OS |

### 16.4 Lo que el bos Sabe Durante Todo el Ciclo

El bos IAM Installer, a través del ctx_id activo y los eventos en audit_events, sabe en todo momento:

```json
{
  "ctx_id": "ctx-88291-a4f9",
  "estado": "activo",

  "quién": "usuario 3397708 (Juan García)",
  "desde": "DEVICE-991 — caja-lpz-23 — La Paz",
  "tenant": "skull / empresa maya / sucursal lapaz / POS-23",

  "autenticado_en": "2026-05-20T14:32:00Z",
  "método_auth": "NFC_MIFARE_DESFIRE (LoA 2)",

  "historia_pre_auth": {
    "dctx_id": "dctx-device-991",
    "dispositivo_activo_desde": "2026-05-20T08:15:00Z",
    "actividad_anónima": "registrada"
  },

  "capacidades_activas": {
    "chapas_zona_ventas": true,
    "cajon_pos": true,
    "contabilidad_tryton": true,
    "ventas_saleor": true,
    "almacen": false,
    "admin": false
  },

  "eventos_recientes": [
    "14:32:01 — context.promoted (pre-auth → authenticated)",
    "14:32:15 — door.opened (ZONE-A, AP-PUERTA-01)",
    "14:33:02 — app.accessed (tryton)",
    "14:35:47 — drawer.opened (POS-23, RELAY_01)",
    "14:41:20 — sale.processed (#V-2026-00891, BOB 450)"
  ]
}
```

### 16.5 Evento context.promoted — La Elevación de Contexto

El momento exacto en que el `dctx_id` anónimo se convierte en `ctx_id` autenticado es el evento **`context.promoted`**. Este evento es crítico para la trazabilidad forense:

```json
{
  "event": "context.promoted",
  "timestamp": "2026-05-20T14:32:00.847Z",

  "dctx_id_anterior": "dctx-device-991",
  "ctx_id_nuevo":     "ctx-88291-a4f9",

  "usuario":          "3397708",
  "metodo_auth":      "NFC_MIFARE_DESFIRE",
  "loa_alcanzado":    2,
  "bitmask":          "0x00000000008C87FF",

  "actividad_pre_auth_preservada": true,
  "duracion_pre_auth_segundos":    22605
}
```

Permite responder: *"¿Qué hizo este dispositivo antes de que alguien se autenticara?"* — dato crítico para investigaciones de seguridad.

### 16.6 Cuando el Usuario Cierra Sesión o el Turno Termina

```
Logout / Fin de turno / Timeout de sesión KC
      ↓
bos invalida ctx_id en Redis
bos emite context.expired o context.logout
      ↓
bAuth notifica a bhnexus: invalidar BitMask del usuario
      ↓
bhnexus propaga a banexus: limpiar cache del usuario
      ↓
banexus: BitMask = 0 para el usuario
      ↓
Resultado:
  - Chapas ya no responden a sus credenciales
  - Cajón del POS bloqueado
  - Tryton/Saleor: sesión expirada
  - Dispositivo vuelve a estado pre-auth (otro usuario puede autenticarse)
      ↓
bos preserva en audit_events la sesión completa:
  inicio, todas las acciones, fin — con ctx_id como hilo conductor
```

---

## Trazabilidad — Sección §16 (adición v3.0)

| Subsección | Fuente | Relación |
|---|---|---|
| §16.1 Pre-auth | SBOS-039 (banexus: udev intercept, mTLS) + SBOS-018 (bos Device Context) | BitMask cero = estado pre-auth definido en SBOS-021 §8 |
| §16.2 Autenticación | SBOS-039 §6 (flujo soberano ~15ms) + SBOS-021 (3 dominios: lógico/físico/financiero) | Latencia y secuencia verificada contra el corpus |
| §16.3 BitMask capacidades | SBOS-021 §8 (Tabla Maestra BitMask 64-bit, bits 10-23) | Bits exactos del corpus, no inventados |
| §16.4 Lo que el bos sabe | SBOS-023 §14 (audit_events) + §10 este doc (Context API bos) | Evento structure de audit_events existente |
| §16.5 context.promoted | Patrón "Session Context Promotion" validado en §2 + corpus SBOS-039 | Nuevo evento, coherente con catálogo §9 |
| §16.6 Logout | SBOS-039 §15 (política update flow < 10s) + SBOS-021 (invalidación KC) | Flujo de invalidación ya documentado |

---

_SKULL · SBOS · SBOS-049-CONTEXT-PLANE · HUMAN-DOC v3.0 · Mayo 2026_
_Reemplaza: v2.0 (Mayo 2026)_
_Adiciones v3.0: §16 Ciclo de Vida Real (pre-auth → auth → operación → logout); evento context.promoted; tabla BitMask → capacidades reales; relación explícita con banexus/bhnexus/bAuth_
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
