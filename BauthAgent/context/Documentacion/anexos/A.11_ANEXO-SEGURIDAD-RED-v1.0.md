# Anexo A.11 — Seguridad de Redes y Comunicaciones Internas (SBOS-054) v1.3.0
## Documento de respaldo: superficie mínima, STRIDE, Zero Trust, las reglas NRS/SAN y el ctx_id como token

**Tipo:** ANEXO — documento de respaldo del corpus
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Estatus:** FUENTE AUTOSUFICIENTE — contiene la norma COMPLETA (traslado fiel, §4)
**Respalda a:** MANUAL-SEGURIDAD (2.09) · MANUAL-CONTEXT-PLANE (1.11 — el ctx_id) · MANUAL-TOKENS (2.03) · A.01 §17.2-B16 (política D7 del rol)
**Fuentes de origen (cita histórica):** `SBOS-054-NETWORK-SECURITY` v1.3.0
**Normas base:** NIST SP 800-207 (Zero Trust) · STRIDE · OWASP (WebSocket/API) · TLS 1.3 · SBOS-050 (puertos) · SBOS-049 (ctx_id)

---

## 1. Propósito y cómo citarlo

Respaldo de la norma de seguridad de red del ecosistema: el principio de **superficie mínima de
ataque**, el modelo de amenazas STRIDE, la defensa en profundidad, el Zero Trust en
comunicaciones internas, la comparativa WebSocket-vs-REST, las **reglas normativas NRS**, la
seguridad del **ctx_id como token de sesión**, el endurecimiento `wss://`, rate limiting/DoS,
sanitización y auditoría de red. **Cómo citarlo:** `A.11 §NRS-06` · `A.11 §8` (ctx_id — del
traslado).

**Autosuficiencia:** el enforcement de red lo gobiernan las reglas del ecosistema (Interface
Dual ADR-020: Unix sockets entre daemons — jamás HTTP/TCP interno); menciones de época a
componentes eliminados bajo ADR-010 (**Keycloak y Tryton fuera de la solución**). El gateway
del perímetro es infraestructura del stack (no un motor de identidad).

## 2. La norma en una vista

| Pieza | Contenido | Norma |
|---|---|---|
| Principio rector | Superficie mínima: deny-all, solo 22/80/443 expuestos, daemons por Unix socket | SBOS-050 |
| Modelo de amenazas | STRIDE aplicado al ecosistema (spoofing→elevation) | STRIDE |
| Defensa en profundidad | Capas: perímetro → gateway → daemon → dato | 800-207 |
| Zero Trust interno | Verificación por petición también ENTRE daemons | NIST SP 800-207 |
| WebSocket vs REST | Análisis comparativo de seguridad — sustento de la Interface Dual | OWASP |
| **Reglas NRS** | Las reglas normativas de seguridad de red (respuesta mínima NRS-06, secretos jamás retornados NRS-10, etc.) | La serie NRS |
| ctx_id como token | Seguridad del contexto de sesión: emisión, validación, invalidación, TTL | SBOS-049 · 1.11 |
| Endurecimiento wss:// | TLS 1.3, orígenes, subprotocolos | OWASP WS |
| Rate limiting / DoS · Sanitización · Auditoría de red · Checklist | Operativa completa | OWASP · AU-* |

## 3. Verificación de completitud

| Verificación | Resultado |
|---|---|
| Cobertura del plano D7 | ✅ — la norma es la fuente de la política de red que el rol declara (A.01 §17.2-B16) |
| Coherencia con Interface Dual | ✅ — WebSocket+JSON-RPC por Unix socket (ADR-020); jamás HTTP/TCP entre daemons |
| Coherencia con el Context Plane | ✅ — el ctx_id como token con su ciclo (1.11) |
| Referencias de época | Menciones puntuales a componentes eliminados en ejemplos del traslado — bajo la aclaración §1 |

## 3.bis Estado de materialización en código (verificado 2026-07-11)

| Pieza | Evidencia | Estado |
|---|---|---|
| Interface Dual sobre Unix socket | `unix_socket.rs` (`UnixListener` + discriminación por primer byte — A.16) | ✅ real |
| Anti-DoS (límite de request) | `unix_socket.rs` `max_request_bytes` (M-03) | ✅ |
| Evaluador de red D7 | `src/domain/network.rs` (**63 líneas** — muy delgado, A.21) | ⚠️ parcial |
| Reglas NRS materializadas | sin evidencia de las NRS como código enforcement (grep NRS → 0) | ⚠️ doctrina |
| RLS (aislamiento por red/tenant) | **0 policies** (A.22) | ❌ |

**Hallazgo crudo:** la superficie mínima (Unix socket, sin HTTP entre daemons) y el anti-DoS del
socket son reales. Pero el **evaluador D7 (red/ZTA) es delgado (63 líneas)** y las reglas NRS son
doctrina, no enforcement verificable en código. La red como disciplina propia (D7) es la más
inmadura de los planos (coherente con A.01 §17: "D7 ausente/parcial").

## 4. Traslado fiel — la norma completa

### SBOS-054 — Seguridad de Redes y Comunicaciones Internas

**Documento normativo de seguridad. Rige toda comunicación entre daemons, servicios y componentes del ecosistema SBOS.**

**Versión:** 1.3.0 · **Fecha:** 2026-06-17 · **Autor:** sbos-coordinador + bos-developer · BitMask Dual Jun 2026
**Alineado con:** SBOS-047-ISMS-ISO27001 · SBOS-049-CONTEXT-PLANE §5 · SBOS-050-PORT-CATALOG · SBOS-053-DAEMON-TUI-DECOUPLING · ADR-033 · RB-03-CONTEXT-PLANE-DOWN
**Estándares:** NIST SP 800-207 (Zero Trust) · NSA/CISA K8s Hardening Guide · CIS Benchmark v8 ·
OWASP API Security Top 10 (2023) · ISO/IEC 27001:2022 · STRIDE (Microsoft Threat Modeling)

---

> ⚠️ **CORRECCIÓN BITMASK — JUNIO 2026:** Las referencias al modelo BitMask (SAM-128, "2 capas", "BitmaskBundle") en este documento corresponden al diseño anterior. El modelo actual es el **BitMask Dual**: `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md`. Para desarrollo, consultar los manuales actualizados.

#### Tabla de Contenidos

1. [Principio Rector: Superficie Mínima de Ataque](#1-principio-rector-superficie-mínima-de-ataque)
2. [Modelo de Amenazas para SBOS (STRIDE)](#2-modelo-de-amenazas-para-sbos-stride)
3. [Arquitectura de Defensa en Profundidad](#3-arquitectura-de-defensa-en-profundidad)
4. [Zero Trust en Comunicaciones Internas (NIST SP 800-207)](#4-zero-trust-en-comunicaciones-internas-nist-sp-800-207)
5. [WebSocket vs REST: Análisis de Seguridad Comparativo](#5-websocket-vs-rest-análisis-de-seguridad-comparativo)
6. [Reglas Normativas de Seguridad de Red (NRS)](#6-reglas-normativas-de-seguridad-de-red-nrs)
7. [Especificación: Context API :9443 (Kong ↔ BOS)](#7-especificación-context-api-9443-kong--bos)
8. [Seguridad del ctx_id como Token de Sesión](#8-seguridad-del-ctx_id-como-token-de-sesión)
9. [Endurecimiento de WebSocket (wss://)](#9-endurecimiento-de-websocket-wss)
10. [Rate Limiting y Protección DoS](#10-rate-limiting-y-protección-dos)
11. [Sanitización de Parámetros y Datos](#11-sanitización-de-parámetros-y-datos)
12. [Auditoría de Seguridad de Red](#12-auditoría-de-seguridad-de-red)
13. [Checklist de Cumplimiento para Desarrolladores](#13-checklist-de-cumplimiento-para-desarrolladores)
14. [Referencias y Normas](#14-referencias-y-normas)

---

#### 1. Principio Rector: Superficie Mínima de Ataque

> **Cada endpoint, puerto y protocolo que un daemon expone es un vector de ataque potencial.**
> **El diseño seguro comienza eliminando todo lo que no es estrictamente necesario.**
> **Lo que no existe no puede ser atacado.**

##### 1.1 La Regla de Reducción

```
ANTES de implementar cualquier comunicación entre componentes, responder:

  1. ¿Es ABSOLUTAMENTE necesaria esta comunicación?
     Si no → eliminar el endpoint/puerto/protocolo.

  2. ¿Puede resolverse con un canal YA EXISTENTE?
     Si sí → usar el canal existente, no crear uno nuevo.

  3. ¿Cuál es la superficie MÍNIMA que necesita?
     Si REST → 1 endpoint, no 6.
     Si WebSocket → 1 tipo de mensaje, no 10.

  4. ¿Qué dato MÍNIMO necesita el consumidor?
     Si solo necesita "válido/no" → retornar booleano, no el objeto completo.
```

##### 1.2 Impacto en el Diseño de M1.4

La Context API originalmente planeaba 6 endpoints REST. Aplicando la Regla de Reducción:

| Endpoint propuesto | ¿Necesario? | Razón de eliminación |
|-------------------|-------------|---------------------|
| `/api/v1/context/health` | ❌ | Kong puede verificar salud con TCP connect a :9443 |
| `/api/v1/context/{ctx_id}` | ✅ | ÚNICO necesario — Kong solo necesita validar ctx_id |
| `/api/v1/context/{ctx_id}/tenant` | ❌ | El tenant_id ya está en la respuesta del endpoint único |
| `/api/v1/context/{ctx_id}/bitmask` | ❌ | El bitmask ya está en la respuesta del endpoint único |
| `/api/v1/context/{ctx_id}/ttl` | ❌ | El TTL ya está en la respuesta del endpoint único |
| `/api/v1/device/{dctx_id}` | ❌ | dctx_id se valida por Unix socket JSON-RPC, no por HTTP |

**Resultado: 6 endpoints → 1 endpoint. Reducción del 83% de la superficie de ataque.**

---

#### 2. Modelo de Amenazas para SBOS (STRIDE)

El modelo STRIDE (Microsoft Threat Modeling) aplicado a las comunicaciones internas de SBOS.

##### 2.1 Matriz de Amenazas

| Categoría | Amenaza | Vector de ataque | Control |
|-----------|---------|-----------------|---------|
| **S**poofing | Un pod malicioso suplanta a Kong | Conexión TCP a :9443 desde un namespace no autorizado | mTLS + NetworkPolicy (NRS-04) |
| **T**ampering | ctx_id modificado en tránsito entre Kong y BOS | MITM en red K8s | TLS 1.3 en todas las conexiones (NRS-01) |
| **R**epudiation | Validación de ctx_id sin registro | Operador niega acceso concedido | audit_event por cada validación (NRS-09) |
| **I**nformation Disclosure | Enumeración de ctx_ids válidos | GET /api/v1/context/{ctx_id} con UUIDs aleatorios | Rate limiting + sin listado (NRS-07) |
| **D**enial of Service | Saturación de :9443 con requests | 10,000 GET/segundo desde pod comprometido | Rate limit 100 req/s + timeout 2s (NRS-08) |
| **E**levation of Privilege | Usar ctx_id de tenant A para acceder a recursos de tenant B | ctx_id robado de logs/memoria | BitMask verificado en cada request; ctx_id con TTL corto (NRS-06) |

##### 2.2 Evaluación de Riesgo Residual

| Amenaza | Probabilidad | Impacto | Riesgo Inherente | Controles | Riesgo Residual |
|---------|-------------|---------|-----------------|-----------|----------------|
| Spoofing | Media | Crítico | ALTO | mTLS + NetworkPolicy | BAJO |
| Tampering | Baja | Crítico | MEDIO | TLS 1.3 | BAJO |
| Repudiation | Media | Alto | ALTO | audit_event | BAJO |
| Information Disclosure | Alta | Medio | ALTO | Rate limit + UUID validation | MEDIO |
| DoS | Alta | Medio | ALTO | Rate limit + timeout | MEDIO |
| Elevation | Media | Crítico | ALTO | BitMask + TTL + tenant isolation | BAJO |

---

#### 3. Arquitectura de Defensa en Profundidad

Cada comunicación en SBOS se protege en 5 capas independientes. Si una capa falla, las otras contienen el daño.

```
╔══════════════════════════════════════════════════════════════════════════╗
║                     DEFENSA EN PROFUNDIDAD SBOS                          ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║  CAPA 1 — RED (NetworkPolicy + Micro-segmentation)                       ║
║  ───────────────────────────────────────────────────                     ║
║  │ Calico NetworkPolicy: deny-all default                                ║
║  │ Solo el namespace/pod autorizado alcanza el puerto                    ║
║  │ East-West traffic: solo pods con label específico                     ║
║  │ Referencia: NSA/CISA K8s Hardening §3                                 ║
║                                                                          ║
║  CAPA 2 — TRANSPORTE (mTLS + TLS 1.3)                                    ║
║  ─────────────────────────────────────────                               ║
║  │ TLS 1.3 como mínimo (no TLS 1.2, no SSL)                             ║
║  │ mTLS donde ambos extremos tienen certificado (NRS-03)                 ║
║  │ Cipher suites: solo ECDHE + AES-256-GCM + SHA384                      ║
║  │ Referencia: NIST SP 800-52 Rev 2                                      ║
║                                                                          ║
║  CAPA 3 — APLICACIÓN (API mínima + validación estricta)                   ║
║  ─────────────────────────────────────────────────────                   ║
║  │ 1 endpoint, no 6 (NRS-05)                                             ║
║  │ Solo GET (método más restrictivo)                                     ║
║  │ UUID validation: rechazar cualquier input no-UUID                     ║
║  │ Response mínimo: solo campos necesarios (NRS-06)                      ║
║  │ Referencia: OWASP API Security Top 10 (API1:2023)                     ║
║                                                                          ║
║  CAPA 4 — DATOS (clasificación + mínima exposición)                       ║
║  ───────────────────────────────────────────────────                     ║
║  │ Secretos nunca en response (NRS-10)                                   ║
║  │ BitMask: solo bits relevantes para el consumidor                      ║
║  │ TTL expuesto solo si el consumidor lo necesita                        ║
║  │ Referencia: ISO/IEC 27001 A.8.12 (data masking)                       ║
║                                                                          ║
║  CAPA 5 — AUDITORÍA (registro inmutable + alertas)                        ║
║  ─────────────────────────────────────────────────                       ║
║  │ Cada validación/error → audit_event (NRS-09)                          ║
║  │ ctx_id en cada registro (W3C Trace Context)                           ║
║  │ Alerta si >50 validaciones fallidas en 60s                            ║
║  │ Referencia: ISO/IEC 27001 A.8.15 (audit logging)                      ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
```

---

#### 4. Zero Trust en Comunicaciones Internas (NIST SP 800-207)

##### 4.1 Los 7 Principios de Zero Trust Aplicados a SBOS

NIST SP 800-207 define 7 principios. Así se aplican a la comunicación entre daemons SBOS:

| # | Principio NIST 800-207 | Aplicación en SBOS |
|---|-----------------------|-------------------|
| 1 | Todo recurso se trata como externo | Kong no confía en BOS porque está en la misma red. Cada request se autentica. |
| 2 | Mínimo privilegio por sesión | Un ctx_id válido para tenant A NO autoriza acceso a tenant B. BitMask + tenant_id verificados. |
| 3 | Decisión dinámica (multi-factor) | Validación de ctx_id considera: TTL, bitmask, tenant_id, IP origen, rate limit actual. |
| 4 | Autenticación y autorización continuas | Cada request GET /api/v1/context/{ctx_id} es independiente. No hay "sesión establecida". |
| 5 | Monitoreo continuo de integridad | Watchdog verifica cada 30s: ¿responde :9443? ¿TLS válido? ¿mTLS funcional? |
| 6 | Política dinámica | Rate limit se ajusta dinámicamente: si >50 fallos/min → reducir a 10 req/s. |
| 7 | Recolección de datos para mejora | Métricas: bos_context_validations_total, bos_context_errors_total, latencia P99. |

##### 4.2 Componentes Lógicos ZTA en SBOS

```
┌──────────────────────────────────────────────────────────────┐
│                 ZTA Logical Components                       │
│                                                              │
│  Policy Engine (PE)          Policy Administrator (PA)       │
│  ──────────────────          ─────────────────────────       │
│  bkernel_db.saga_state       bos daemon (Context Service)    │
│  + Redis DB1 (cache)         Decide: ¿válido? ¿expirado?     │
│  Evalúa: TTL + BitMask       ¿tenant correcto?               │
│  + tenant_id + LoA                                          │
│         │                            │                      │
│         └──────────┬─────────────────┘                      │
│                    │                                         │
│                    ▼                                         │
│  Policy Enforcement Point (PEP)                              │
│  ─────────────────────────────                               │
│  Kong Plugin SBOS-Context (Lua)                              │
│  Intercepta cada request → valida ctx_id contra BOS          │
│  Si inválido → 401/403 sin llegar al servicio                │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

#### 5. WebSocket vs REST: Análisis de Seguridad Comparativo

##### 5.1 Cuándo usar cada uno

| Criterio | REST (HTTPS) | WebSocket (WSS) |
|----------|-------------|-----------------|
| **Propósito en SBOS** | Kong→BOS: validación única de ctx_id | TUI↔daemon: progreso en tiempo real; daemon↔daemon: comandos |
| **Superficie de ataque** | Pequeña — per-request, sin estado, fácil de auditar | Mayor — conexión persistente, puntos ciegos en WAF |
| **Autenticación** | Por request (JWT, mTLS) — cada GET es independiente | Solo en handshake — el túnel queda abierto sin re-validación |
| **Autorización** | Cada request verificado | Solo al inicio; riesgo de escalación si el token no expira |
| **WAF/SIEM** | Inspección completa de request/response | Muchos WAF dejan de inspeccionar después del upgrade |
| **DoS** | Fácil de rate-limitar por endpoint/IP | Conexiones persistentes consumen memoria; más difíciles de limitar |
| **Logging** | Cada request se registra automáticamente | Requiere logging explícito de frames |
| **Uso en SBOS** | SOLO para Kong↔BOS (validación ctx_id) y métricas Prometheus | TODO lo demás: TUI, daemon↔daemon, JSON-RPC, eventos |

##### 5.2 La Regla de Oro SBOS

> **REST/HTTP solo para: (1) Kong↔BOS Context API :9443 — la excepción documentada en SBOS-050 P9, (2) Prometheus /metrics scraping.**
> **Todo lo demás: WebSocket wss:// o Unix socket con JSON-RPC 2.0.**
> **HTTP entre daemons está PROHIBIDO (SBOS-050 P9).**

##### 5.3 Por qué REST es más seguro para la Context API específicamente

La validación de ctx_id es una operación **stateless de lookup puntual** — no necesita streaming, no necesita bidireccionalidad, no necesita persistencia de conexión. Para este caso de uso específico:

| Propiedad | REST | WebSocket |
|-----------|------|-----------|
| Cada validación es independiente | ✅ Natural | ❌ Overhead de mantener túnel |
| Auditoría por request | ✅ Automática | ❌ Requiere logging manual de frames |
| Rate limiting | ✅ Trivial por endpoint | ❌ Complejo por conexión |
| Firewall/WAF inspecciona | ✅ Todo el tráfico | ❌ Solo el handshake |
| Surface para enumeración | ⚠️ 1 endpoint | ⚠️ 1 tipo de mensaje |

**Conclusión:** Para la Context API :9443, REST con 1 solo endpoint es más seguro que WebSocket porque: (a) cada request se autentica y audita independientemente, (b) los WAF/SIEM pueden inspeccionar el tráfico completo, (c) el rate limiting es trivial, (d) no hay túnel persistente que un atacante pueda explotar.

---

#### 6. Reglas Normativas de Seguridad de Red (NRS)

Estas reglas son **obligatorias** para cualquier daemon, ficha o endpoint nuevo en SBOS. Se numeran `NRS` (Network Security Rule) para referencia cruzada desde ADRs.

##### 6.1 Reglas de Transporte

| # | Regla | Verificable por |
|---|-------|-----------------|
| **NRS-01** | Toda comunicación entre daemons usa TLS 1.3 como mínimo. Cipher suites: ECDHE+AES-256-GCM+SHA384 exclusivamente. Sin TLS 1.2, sin SSL. | `openssl s_client -connect host:port -tls1_3` |
| **NRS-02** | HTTP está PROHIBIDO entre daemons (SBOS-050 P9). Solo WebSocket wss:// o Unix socket. Excepción única: Kong→BOS Context API :9443. | Code review: sin `http.ListenAndServe` en daemons salvo bos :9443 |
| **NRS-03** | mTLS obligatorio donde ambos extremos tienen identidad verificable. BOS requiere certificado cliente de Kong. | `curl --cert client.crt --key client.key https://bos:9443/api/v1/context/test` |
| **NRS-04** | NetworkPolicy deny-all por defecto en cada namespace. Solo se permite tráfico explícitamente declarado. | `kubectl describe networkpolicy -n sbos-gateway` |

##### 6.2 Reglas de Superficie de Ataque

| # | Regla | Verificable por |
|---|-------|-----------------|
| **NRS-05** | Un endpoint por propósito. Si dos consumidores necesitan datos distintos, unificar en un solo response con todos los campos necesarios. Nunca crear endpoints separados para cada campo. | Code review: contar endpoints por daemon. Alertar si >3 por daemon. |
| **NRS-06** | Response mínimo: retornar SOLO los campos que el consumidor necesita. Nunca retornar el objeto completo "por si acaso". | Diff de structs: response DTO ≠ domain model. |
| **NRS-07** | Sin endpoints de listado/búsqueda sin autenticación. Si un endpoint acepta un ID, debe ser UUID válido — rechazar cualquier otro formato. | Test: GET /api/v1/context/admin → 400, no 404 (no revelar si existe). |
| **NRS-08** | Rate limiting en cada endpoint expuesto. Default: 100 req/s por IP. Ajustable por endpoint. | `hey -n 1000 -c 10 https://bos:9443/api/v1/context/test` → 429 después del límite. |

##### 6.3 Reglas de Auditoría

| # | Regla | Verificable por |
|---|-------|-----------------|
| **NRS-09** | Cada validación/error en endpoint de seguridad genera audit_event con ctx_id, timestamp, IP origen, resultado. | `SELECT count(*) FROM audit_events WHERE endpoint = '/api/v1/context/{ctx_id}'` |
| **NRS-10** | Secretos (tokens, passwords, claves Shamir) NUNCA en response de API. NUNCA en logs. NUNCA en URL query strings. | CI check: grep de patrones de secreto en responses de test. |

---

#### 7. Especificación: Context API :9443 (Kong ↔ BOS)

##### 7.1 Propósito

Validar ctx_id para Kong. Es el **único endpoint HTTP en todo el ecosistema SBOS** (excepción documentada en SBOS-050 P9, Nivel 4). Kong consulta este endpoint en cada request HTTP/HTTPS que llega al cluster para verificar que el ctx_id del usuario es válido.

##### 7.2 Endpoint Único

```
GET /api/v1/context/{ctx_id}

Headers:
  X-SBOS-Source: kong
  Authorization: Bearer <kong-service-token>

Response 200 OK:
  Content-Type: application/json
  {
    "valid": true,
    "ctx_id": "00dbfc97-e2f1-4e5a-8b3c-1f9a6d5e7b2c",
    "tenant_id": "1234567890",
    "bitmask": "0x00000000000000FF",
    "ttl_s": 3540,
    "loa": 2
  }

Response 404 Not Found:
  {
    "valid": false,
    "ctx_id": "00dbfc97-e2f1-4e5a-8b3c-1f9a6d5e7b2c",
    "error": "not_found_or_expired"
  }

Response 400 Bad Request:
  {
    "valid": false,
    "error": "invalid_ctx_id_format"
  }

Response 429 Too Many Requests:
  {
    "valid": false,
    "error": "rate_limit_exceeded",
    "retry_after_s": 1
  }
```

##### 7.3 Validaciones de Seguridad

| # | Validación | Código |
|---|-----------|--------|
| 1 | ctx_id debe ser UUID v4 válido (36 chars, formato 8-4-4-4-12) | 400 |
| 2 | Header X-SBOS-Source debe ser "kong" | 403 |
| 3 | Authorization Bearer token debe coincidir con /etc/bos/kong-token | 401 |
| 4 | ctx_id debe existir en bkernel_db O Redis DB1 (cache) | 404 |
| 5 | ctx_id no debe estar expirado (ExpiresAt > now) | 404 |
| 6 | Rate limit: 100 req/s desde IP de Kong | 429 |

##### 7.4 Configuración TLS

```bash
### Generar certificado autofirmado (staging)
openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
  -keyout /etc/bos/certs/bos.key \
  -out /etc/bos/certs/bos.crt \
  -subj "/CN=bos.sbos-system.svc.cluster.local" \
  -addext "subjectAltName=DNS:bos.sbos-system.svc.cluster.local,DNS:localhost,IP:127.0.0.1"

### En producción (M2.2): certificado emitido por Vault PKI
```

##### 7.5 Configuración del Servidor Go

```go
server := &http.Server{
    Addr:    ":9443",
    Handler: mux,
    TLSConfig: &tls.Config{
        MinVersion: tls.VersionTLS13,
        CipherSuites: []uint16{
            tls.TLS_AES_256_GCM_SHA384,
        },
        // En producción: requerir certificado cliente (mTLS)
        // ClientAuth: tls.RequireAndVerifyClientCert,
    },
    ReadTimeout:  2 * time.Second,  // anti-slowloris
    WriteTimeout: 2 * time.Second,
    IdleTimeout:  30 * time.Second,
}
```

---

#### 8. Seguridad del ctx_id como Token de Sesión

**Referencias:** SBOS-049-CONTEXT-PLANE §5 · ADR-033 (RequestContext Campo 1) ·
NIST SP 800-207 Tenet 3 (per-session access) · OWASP API2:2023 (Broken Authentication)

##### 8.1 El ctx_id es un Token de Sesión — Debe Protegerse Como Tal

El `ctx_id` no es un simple identificador — es el equivalente funcional de un **token de sesión** en el modelo Zero Trust de SBOS. Quien posee un `ctx_id` válido puede actuar en nombre del usuario dentro del tenant, empresa, sucursal y POS lógico que el contexto representa.

| Propiedad del ctx_id | Equivalente en OAuth 2.0 | Implicación de seguridad |
|----------------------|--------------------------|-------------------------|
| Identifica al usuario | `sub` claim | Suplantación de identidad si se roba |
| Tiene TTL (expira) | `exp` claim | Debe validarse en CADA request |
| Está ligado a un tenant | `aud` claim | No puede usarse cross-tenant |
| Se propaga en headers | Bearer token | Mismos riesgos de exposición en logs/proxies |
| Se invalida en logout/suspend | Token revocation | Debe invalidarse inmediatamente |

##### 8.2 Validación del ctx_id en Cada Request (Zero Trust Tenet 3)

NIST SP 800-207 exige verificación **por sesión, no por conexión**. Cada request que llega a Kong debe validar el ctx_id contra el Context Registry:

```
Request HTTP/HTTPS → Kong
    │
    ▼
1. Kong extrae ctx_id del header Baggage o cookie __sbos_ctx
    │
    ▼
2. Kong → GET https://bos:9443/api/v1/context/{ctx_id}
    │   (mTLS, TLS 1.3, red interna)
    ▼
3. BOS valida:
    ├─ ctx_id existe en Redis DB1 (cache O(1)) o bkernel_db
    ├─ ctx_id NO está expirado (ExpiresAt > now)
    ├─ ctx_id NO está invalidado (suspend/remove tenant)
    └─ Formato UUID válido (anti-injection)
    │
    ▼
4. BOS responde: { valid: true/false, tenant_id, bitmask, ttl_s }
    │
    ▼
5. Kong decide:
    ├─ Válido → forward al servicio con headers X-SBOS-*
    └─ Inválido → 401 Unauthorized (sin llegar al servicio)
```

##### 8.3 Riesgos Específicos del ctx_id

| Riesgo | Vector | Mitigación |
|--------|--------|-----------|
| **ctx_id expuesto en logs** | Proxy/load balancer loguea el header Baggage | El Baggage solo viaja en red interna (K8s). Kong NO loguea el valor completo del ctx_id — solo los primeros 8 chars + hash |
| **ctx_id reutilizado cross-tenant** | Atacante usa ctx_id del tenant A para acceder a tenant B | BOS valida tenant_id en cada request. Kong inyecta `X-SBOS-Tenant` y el servicio verifica que coincida con el ctx_id |
| **ctx_id robado de Redis** | Atacante con acceso a Redis DB1 lee ctx_ids activos | Redis DB1 solo accesible desde el namespace del bos (NetworkPolicy). ACL: solo bos puede leer. AOF encriptado |
| **ctx_id enumerado por fuerza bruta** | Atacante prueba UUIDs aleatorios en :9443 | Rate limit 100 req/s. Respuesta idéntica para "no existe" y "expirado" (no revelar estado). Sin endpoint de listado |
| **ctx_id no invalidado en logout** | Usuario cierra sesión pero ctx_id sigue válido | `bos.ctx.invalidate` llamado por Keycloak Event Listener en logout. TTL en Redis se reduce a 0 |
| **dctx_id pre-auth escalado** | Atacante usa dctx_id anónimo como ctx_id autenticado | dctx_id tiene bitmask=0x0 (sin permisos). Kong verifica bitmask > 0 antes de forward. bAuth rechaza bitmask=0x0 para cualquier operación |

##### 8.4 dctx_id vs ctx_id — Distinción de Seguridad

```
dctx_id (Device Context)              ctx_id (Context Session)
─────────────────────────              ─────────────────────────
Pre-autenticación                     Post-autenticación
Anónimo (bitmask = 0x0)               Autenticado (bitmask > 0)
Creado por: bos.ctx.device.register   Creado por: bos.ctx.promote
No da acceso a recursos               Da acceso según BitMask
TTL: 30 min (renovable)               TTL: duración sesión Keycloak
Cookie: __sbos_dctx                   Header: Baggage ctx.id
```

**Regla de seguridad:** Un request que solo tiene `dctx_id` (sin `ctx_id`) NUNCA debe acceder a recursos protegidos. Kong verifica: si solo hay `__sbos_dctx` y no hay `ctx_id` → solo rutas públicas (login, landing page).

##### 8.5 Invalidación Masiva por Suspensión de Tenant

Cuando un tenant se suspende (`bosctl tenant suspend`), TODOS los ctx_id activos de ese tenant deben invalidarse inmediatamente:

```go
// internal/context/service.go
func (svc *Service) InvalidateAllByTenant(tenantID string) (int, error) {
    // 1. Obtener todos los ctx_id activos del tenant desde Redis DB1
    // 2. Para cada ctx_id: marcar como invalidado en bkernel_db
    // 3. Eliminar de Redis DB1 (cache)
    // 4. Registrar audit_event por cada invalidación
    // 5. Retornar conteo de ctx_id invalidados
}
```

**Garantía de seguridad:** Entre el paso 1 y el paso 3, cualquier request que llegue con un ctx_id del tenant suspendido DEBE ser rechazado. Esto se logra con un flag `tenant_suspended` en Redis que Kong verifica antes de validar el ctx_id individual.

##### 8.6 Endurecimiento del Header Baggage

El header `baggage` de OpenTelemetry viaja en texto plano. En red interna de K8s esto es aceptable (TLS 1.3 protege el tránsito), pero deben aplicarse defensas adicionales:

| Defensa | Implementación |
|---------|---------------|
| **Validación de formato** | El valor de `ctx.id` en el baggage debe ser UUID válido. Cualquier otro formato → rechazar request |
| **No loguear completo** | Logs solo muestran `ctx_id=ctx-88291***` (últimos 4 chars ocultos) |
| **No en URL** | El ctx_id NUNCA viaja en query string. Solo en header Baggage o cookie |
| **Cookie HttpOnly** | `__sbos_ctx` es HttpOnly + Secure + SameSite=Strict. No accesible desde JavaScript |
| **TTL enforcement** | Kong verifica TTL. Si TTL < 60s, fuerza refresh de sesión contra Keycloak |

##### 8.7 Flujo de Creación del ctx_id (SBOS-049 §5.2)

El flujo completo desde el login hasta la propagación del ctx_id:

```
Usuario Login
      ↓
Keycloak autentica → emite JWT con claim bos_contexts
      ↓
Kong extrae JWT → llama GET /api/v1/context/{ctx_id} (BOS :9443)
      ↓
bos valida árbol de contextos del usuario contra .sbos_state.json del tenant
      ↓
bos crea Context Session → genera ctx_id (UUID v4)
      ↓
bos almacena ctx_id en Redis DB1 (TTL = duración sesión Keycloak)
bos persiste en bkernel_db.context_sessions (ISO 27001 A.8.15)
      ↓
ctx_id retorna al cliente → se propaga en todos los requests subsiguientes
```

**Implicaciones de seguridad:**
- El JWT de Keycloak se valida UNA vez en el login. Después, el ctx_id es el token de sesión.
- Si el JWT expira pero el ctx_id sigue vivo → Kong fuerza re-login (TTL sincronizado KC-Redis).
- Si el ctx_id se pierde (Redis flush) → el usuario debe re-login (no hay fallback).
- El `bos_contexts` claim del JWT contiene el árbol organizacional completo del usuario — validar que no exceda 4KB (límite de header HTTP).

##### 8.8 Estructura Completa del ctx_id (SBOS-049 §5.3)

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

**Clasificación de seguridad de cada campo:**

| Campo | Clasificación | ¿Se expone en API? | ¿Se loguea? |
|-------|-------------|-------------------|------------|
| `ctx_id` | Público (ID de sesión) | ✅ | Parcial (últimos 4 chars ocultos) |
| `tenant`, `empresa`, `sucursal`, `pos_logico` | Interno | ✅ (necesario para routing) | ✅ |
| `user_id` | Confidencial (PII) | ✅ (necesario para auditoría) | Parcial (hash en logs) |
| `session_kc` | Secreto (equivale a token) | ❌ NUNCA | ❌ NUNCA |
| `pod`, `namespace`, `node`, `cluster`, `vps`, `geo` | Interno (infraestructura) | ❌ (no necesario para Kong) | ✅ (diagnóstico) |
| `created_at`, `expires_at` | Interno | ✅ (TTL) | ✅ |

**Regla de exposición:** La respuesta del endpoint `/api/v1/context/{ctx_id}` retorna SOLO: `ctx_id`, `tenant_id`, `bitmask`, `ttl_s`, `loa`. NUNCA `user_id`, `session_kc`, ni datos de infraestructura.

##### 8.9 Propagación Segura del ctx_id (SBOS-049 §5.4 + W3C)

En cada request, Kong inyecta DOS headers complementarios:

```
traceparent: 00-{trace_id_32hex}-{parent_id_16hex}-01   ← W3C Trace Context (trazabilidad)
baggage: ctx.id=ctx-88291-a4f9,tenant.id=skull,empresa.id=maya,
         sucursal.id=lapaz,pos.id=POS-23,user.id=3397708
```

| Canal | Mecanismo de propagación | Seguridad |
|-------|--------------------------|-----------|
| **APIs REST (Kong)** | Header `baggage` + `traceparent` (W3C) | TLS 1.3 en tránsito. Solo red interna K8s |
| **WAL → bKernel** | Campo `ctx_id` en el evento CDC | Canal interno PostgreSQL. No expuesto en red |
| **WebSocket (daemon↔TUI)** | Metadato del canal de sesión | Unix socket local o wss:// con auth |
| **Logs (Loki)** | Atributo `ctx_id` vía OTel Baggage Processor | Procesado por el Collector. user_id hasheado |
| **Auditoría (bkernel_db)** | Columna `ctx_id` en cada registro | Acceso solo vía bkernel_db (Vault credentials) |
| **gRPC entre servicios** | `RequestContext` campo 1 (ADR-033) | mTLS + Linkerd. ctx_id y tenant_id obligatorios |

**Validación de seguridad del Baggage:**
- Kong verifica que el header `baggage` solo contenga claves conocidas (`ctx.id`, `tenant.id`, `empresa.id`, etc.)
- Cualquier clave desconocida en el baggage → se elimina antes de forward
- El valor de `ctx.id` debe ser UUID válido → si no, se rechaza el request
- El baggage NUNCA se reenvía a servicios externos (solo red interna K8s)

##### 8.10 TTL y Expiración (RB-03 + ISO 27001 A.9.4.2)

| Tipo de contexto | TTL mínimo | TTL máximo | Fuente |
|-----------------|-----------|-----------|--------|
| **DeviceContext (dctx_id)** | 30 min | **8 horas** | SBOS-049 §3, RB-03 |
| **SessionContext (ctx_id)** | 15 min (sesión KC) | **12 horas** | ISO 27001 A.9.4.2, RB-03 |

**Comportamiento por expiración:**

| Escenario | Qué ocurre | Acción requerida |
|-----------|-----------|-----------------|
| ctx_id expirado (normal) | Kong rechaza request → 401. Cliente debe re-login. | Ninguna. Operación normal. |
| dctx_id expirado (normal) | Visitante anónimo recibe nuevo dctx_id en siguiente request. | Ninguna. Operación normal. |
| Todos los ctx_id de un tenant expirados | Tenant sin sesiones activas. Nuevos logins crean nuevos ctx_id. | Ninguna (RB-03 CASO E). |
| ctx_id no invalidado post-logout | Usuario cierra sesión pero ctx_id sigue válido en Redis. | **Crítico.** Keycloak Event Listener DEBE llamar `bos.ctx.invalidate`. |

##### 8.11 Cadena de Dependencias del Context Plane (RB-03)

```
PostgreSQL (C-04) ──────┐
                         ├── internal/context/store.go ── bos.ctx.device.register
Redis DB1 (C-05) ───────┘         │
                                    └── dctx_id → ctx_id → VDI Layer (C-09..C-14)
                                                             │
                                              Fedora Lógico ← Usuario final
```

**Impacto de seguridad por fallo en cadena:**

| Componente caído | Impacto en seguridad | Mitigación |
|-----------------|---------------------|-----------|
| **Redis DB1 caído** | Cache inaccesible. Validación va directo a PostgreSQL → lenta (no insegura). | Ficha repair redis. Mientras: PostgreSQL responde consultas directas. |
| **PostgreSQL caído** | Context Plane SIN store persistente. Nuevos ctx_id no se crean. | **Crítico.** Sin PostgreSQL = sin sesiones nuevas. Repair urgente. |
| **Ambos caídos** | Context Plane DOWN. Kong rechaza TODOS los requests con ctx_id. | **Emergencia.** Reparar PostgreSQL primero, luego Redis. |
| **BOS :9443 caído** | Kong no puede validar ctx_id → todos los requests requieren re-login. | Reiniciar bos.service. Tiempo de recovery: <5s. |

---

#### 9. Endurecimiento de WebSocket (wss://)

##### 9.1 Vulnerabilidades Identificadas y Contramedidas

| Vulnerabilidad | Descripción | Contramedida SBOS |
|---------------|------------|-------------------|
| **CSWSH** (Cross-Site WebSocket Hijacking) | Navegador envía cookies en handshake; atacante puede secuestrar conexión | Validación estricta de Origin. Solo aceptar orígenes de la CLI/TUI local. |
| **Token en URL** | Tokens en query string son logueados por proxies y load balancers | Socket.IO v4 `auth` payload o header Authorization en handshake. NUNCA en URL. |
| **Sin auth por mensaje** | Después del handshake, el túnel acepta cualquier mensaje | Validar `ctx_id` en CADA mensaje recibido, no solo en el handshake. |
| **DoS por conexiones** | Cientos de conexiones abiertas consumen memoria y file descriptors | Límite de conexiones concurrentes: 50 por IP. Timeout de idle: 60s. |
| **Frame injection** | Frames maliciosos no detectados porque el WAF no inspecciona | Validar schema de cada mensaje (JSON Schema). Tamaño máximo de frame: 64KB. |
| **WAF bypass** | WAF ve el upgrade HTTP pero no los frames posteriores | Rate limiting a nivel de aplicación (mensajes/segundo). |

##### 9.2 Configuración Segura de WebSocket en Go

```go
var upgrader = websocket.Upgrader{
    ReadBufferSize:  4096,
    WriteBufferSize: 4096,
    // Validación estricta de origen
    CheckOrigin: func(r *http.Request) bool {
        origin := r.Header.Get("Origin")
        // Solo aceptar conexiones locales (CLI/TUI)
        return origin == "" || strings.HasPrefix(origin, "http://localhost")
    },
    // Limitar tamaño de handshake
    HandshakeTimeout: 5 * time.Second,
}
```

---

#### 10. Rate Limiting y Protección DoS

##### 10.1 Estrategia por Capa

| Capa | Herramienta | Límite | Propósito |
|------|-----------|--------|-----------|
| **Red** | Calico NetworkPolicy | — | Solo Kong puede llegar a :9443 |
| **Transporte** | TCP backlog del kernel | `net.core.somaxconn=128` | Limitar conexiones TCP pendientes |
| **Aplicación** | Token bucket en Go | 100 req/s por IP | Proteger BOS de Kong en sobrecarga |
| **Aplicación** | Timeout de request | 2s read/write | Anti-slowloris |
| **Monitoreo** | Alerta Prometheus | >50 errores/min | Detección temprana de ataque |

##### 10.2 Implementación de Rate Limiter en Go

```go
type RateLimiter struct {
    mu       sync.Mutex
    visitors map[string]*visitor
}

type visitor struct {
    tokens    float64
    lastCheck time.Time
}

func (rl *RateLimiter) Allow(ip string, rate float64) bool {
    rl.mu.Lock()
    defer rl.mu.Unlock()
    v, exists := rl.visitors[ip]
    if !exists {
        rl.visitors[ip] = &visitor{tokens: rate, lastCheck: time.Now()}
        return true
    }
    elapsed := time.Since(v.lastCheck).Seconds()
    v.tokens = math.Min(rate, v.tokens + elapsed * rate)
    v.lastCheck = time.Now()
    if v.tokens >= 1 {
        v.tokens--
        return true
    }
    return false
}
```

---

#### 11. Sanitización de Parámetros y Datos

**Fuentes:** OWASP Input Validation Cheat Sheet (2025) · OWASP API Security Top 10 (API1, API2, API3, API8) ·
OWASP ASVS v5.0 (V1: Encoding & Sanitization, V2: Validation) · CWE-20 (Improper Input Validation) ·
CWE-116 (Improper Encoding) · NIST SP 800-53 (SI-10: Information Input Validation) ·
ISO/IEC 27001:2022 A.8.23 (Web filtering).

##### 11.1 Principio Fundamental

> **Todo input es malicioso hasta que se demuestre lo contrario.**
> **Validar en el servidor. Nunca confiar en el cliente.**
> **Allowlist, nunca denylist. Rechazar por defecto, aceptar solo lo explícitamente permitido.**

##### 11.2 Reglas de Sanitización (SAN)

| # | Regla | Fuente |
|---|-------|--------|
| **SAN-01** | **Allowlist sobre denylist.** Definir exactamente qué caracteres/formatos se ACEPTAN. Todo lo demás se rechaza. No intentar adivinar qué es "peligroso". | OWASP Input Validation Cheat Sheet §2 |
| **SAN-02** | **Validación centralizada.** Todo input pasa por UNA función de validación. No hay validación dispersa en handlers. Un cambio en la política de validación = un cambio en el código. | OWASP Secure Coding Practices §1 |
| **SAN-03** | **Canonicalización antes de validar.** Convertir input a su forma canónica (UTF-8 NFC, path absoluto, URL decodificada UNA sola vez). Luego validar. Luego usar. | CWE-22, CWE-74 |
| **SAN-04** | **Rechazar en fallo.** Si la validación falla, rechazar el request con 400. Nunca "sanitizar silenciosamente" removiendo caracteres — eso enmascara ataques. | OWASP ASVS V2.1 |
| **SAN-05** | **Validación de tipo estricta.** No aceptar strings donde se esperan números. No aceptar objetos donde se esperan arrays. Usar JSON Schema o equivalente para validar estructura. | OWASP API Top 10 API3:2023 |
| **SAN-06** | **Límites de longitud en TODO.** Cada campo string tiene un máximo explícito en caracteres. Cada array tiene un máximo de elementos. Cada número tiene un rango [min, max]. | OWASP ASVS V2.3 |
| **SAN-07** | **Encoding de salida específico al contexto.** HTML → HTML entity encoding. SQL → parameterized queries. OS command → evitar completamente. JSON → json.Marshal (nunca concatenar strings). | OWASP ASVS V1.1 |
| **SAN-08** | **Sin input directo en comandos OS.** Nunca concatenar user input en exec.Command(). Usar args separados. Si es inevitable → allowlist de valores permitidos + validación antes. | CWE-78 (OS Command Injection) |
| **SAN-09** | **UUID/GUID validation estricta.** Si un parámetro es un ID, validar formato UUID v4 (36 chars, 8-4-4-4-12). Rechazar cualquier otra cosa. No usar IDs numéricos secuenciales. | OWASP API Top 10 API1:2023 (BOLA) |
| **SAN-10** | **Mass Assignment Protection.** Nunca hacer `json.Unmarshal(input, &domainObject)` directamente. Usar DTOs intermedios con solo los campos permitidos. Campos desconocidos → rechazar. | OWASP API Top 10 API3:2023 |
| **SAN-11** | **File upload sanitization.** Si se aceptan archivos: validar MIME type + magic bytes (no extensión), escanear con ClamAV, guardar fuera del web root, nombre generado por servidor (UUID). | OWASP ASVS V12 |
| **SAN-12** | **Header validation.** Validar Content-Type, Accept, Origin, X-SBOS-*. Rechazar requests con headers malformados o inesperados. | OWASP ASVS V14.4 |

##### 11.3 Matriz de Sanitización por Tipo de Dato en SBOS

| Tipo de dato | Validación | Ejemplo SBOS | CWE mitigado |
|-------------|-----------|-------------|-------------|
| **ctx_id** | UUID v4 regex: `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$` | `bos.ctx.get` | CWE-20, CWE-89 |
| **tenant_id** | NIT boliviano: 7-15 dígitos, o UUID si es tenant interno | `bosctl deploy` | CWE-20 |
| **domain_id** | Slug: `^[a-z0-9]([a-z0-9-]*[a-z0-9])?$`, 1-63 chars | seed.yml | CWE-20, CWE-78 |
| **realm** | Keycloak realm: `^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$` | seed.yml | CWE-78 |
| **email** | RFC 5321 + domain MX check | `bosctl identity` | CWE-20 |
| **IP/hostname** | `net.ParseIP()` o `^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\\-]*[A-Za-z0-9])$` | Kong routing | CWE-20, SSRF |
| **port** | uint16: 1–65535 | manifest.yml | CWE-20 |
| **JSON payload** | JSON Schema validation, `json.Decoder.DisallowUnknownFields()` | JSON-RPC 2.0 | CWE-20, API3:2023 |
| **file path** | `filepath.Clean()`, sin `..`, sin symlinks, base path prefix check | `FICHA_LOG` | CWE-22 |
| **bitmask** | `^0x[0-9A-Fa-f]{1,16}$`, rango uint64 | `bos.ctx.promote` | CWE-20 |

##### 11.4 Implementación en Go

```go
// sanitize.go — validación centralizada para SBOS (SAN-02)
package sanitize

import (
    "encoding/json"
    "fmt"
    "net"
    "net/mail"
    "path/filepath"
    "regexp"
    "strings"
)

// UUIDv4 valida formato UUID versión 4 (SAN-09)
var uuidV4Regex = regexp.MustCompile(
    `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`,
)

func UUIDv4(s string) error {
    if !uuidV4Regex.MatchString(strings.ToLower(s)) {
        return fmt.Errorf("uuid: formato inválido (debe ser UUID v4): %q", truncate(s, 50))
    }
    return nil
}

// Slug valida formato de identificador de dominio (SAN-05)
var slugRegex = regexp.MustCompile(`^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$`)

func Slug(s string, maxLen int) error {
    if len(s) > maxLen {
        return fmt.Errorf("slug: excede longitud máxima %d", maxLen)
    }
    if !slugRegex.MatchString(s) {
        return fmt.Errorf("slug: caracteres no permitidos (solo [a-z0-9-])")
    }
    return nil
}

// Email valida formato de correo electrónico (SAN-05)
func Email(s string) error {
    if len(s) > 254 { // RFC 5321
        return fmt.Errorf("email: excede longitud máxima 254")
    }
    if _, err := mail.ParseAddress(s); err != nil {
        return fmt.Errorf("email: formato inválido: %w", err)
    }
    return nil
}

// IPAddr valida dirección IP (previene SSRF)
func IPAddr(s string) error {
    if ip := net.ParseIP(s); ip == nil {
        return fmt.Errorf("ip: no es una dirección IP válida: %q", s)
    }
    return nil
}

// FilePath valida ruta de archivo (SAN-08, CWE-22)
func FilePath(s string, basePath string) error {
    cleaned := filepath.Clean(s)
    if strings.Contains(s, "..") {
        return fmt.Errorf("path: no se permite '..'")
    }
    absClean, err := filepath.Abs(cleaned)
    if err != nil {
        return fmt.Errorf("path: no se pudo resolver ruta absoluta")
    }
    absBase, _ := filepath.Abs(basePath)
    if !strings.HasPrefix(absClean, absBase) {
        return fmt.Errorf("path: fuera del directorio base permitido")
    }
    return nil
}

// JSONPayload valida y decodifica payload JSON con protección anti-mass-assignment (SAN-10)
func JSONPayload(data []byte, v interface{}) error {
    dec := json.NewDecoder(strings.NewReader(string(data)))
    dec.DisallowUnknownFields() // SAN-10: rechazar campos desconocidos
    if err := dec.Decode(v); err != nil {
        return fmt.Errorf("json: %w", err)
    }
    // Verificar que no hay datos adicionales después del objeto raíz
    if dec.More() {
        return fmt.Errorf("json: múltiples objetos no permitidos")
    }
    return nil
}

// HeaderValidate valida headers HTTP comunes (SAN-12)
func HeaderValidate(headers map[string]string) error {
    allowedContentTypes := map[string]bool{
        "application/json": true,
    }
    if ct, ok := headers["Content-Type"]; ok {
        if !allowedContentTypes[ct] {
            return fmt.Errorf("header: Content-Type no permitido: %q", ct)
        }
    }
    return nil
}

func truncate(s string, max int) string {
    if len(s) > max {
        return s[:max] + "..."
    }
    return s
}
```

##### 11.5 Flujo de Validación por Request

```
Request entrante
    │
    ▼
1. CANONICALIZAR (SAN-03)
   ├─ URL: decodificar %XX UNA vez, normalizar path (Clean)
   ├─ Unicode: NFC normalization
   └─ Headers: trim whitespace, lowercased keys
    │
    ▼
2. VALIDAR ESTRUCTURA (SAN-05, SAN-10)
   ├─ Content-Type es application/json
   ├─ JSON Schema validation (si aplica)
   ├─ DisallowUnknownFields (anti mass-assignment)
   └─ Tamaño máximo: 64KB para JSON, 4KB para query params
    │
    ▼
3. VALIDAR CAMPOS (SAN-01, SAN-04, SAN-06, SAN-09)
   ├─ Cada campo contra su allowlist/regex específica
   ├─ Longitudes, rangos, formatos
   ├─ UUID validation para IDs
   └─ Si falla → 400 Bad Request (nunca sanitizar silenciosamente)
    │
    ▼
4. VALIDAR CONTEXTO DE NEGOCIO (SAN-08)
   ├─ tenant_id pertenece al tenant del request
   ├─ ctx_id no está expirado
   ├─ BitMask cubre la operación solicitada
   └─ Rate limit no excedido
    │
    ▼
5. ENCODING DE SALIDA (SAN-07)
   ├─ JSON: solo json.Marshal (nunca concatenación de strings)
   ├─ Logs: sanitizar datos sensibles antes de loguear
   └─ HTML: html/template (nunca text/template con user input)
    │
    ▼
Response seguro
```

##### 11.6 Lo que NUNCA se debe hacer

| Anti-patrón | Por qué es peligroso | Qué hacer en su lugar |
|------------|---------------------|----------------------|
| `json.Unmarshal(input, &domainObj)` directo | Mass assignment: atacante puede setear campos como `isAdmin: true` | DTO intermedio con solo campos permitidos + `DisallowUnknownFields()` |
| `exec.Command("bash", "-c", userInput)` | OS command injection | args separados: `exec.Command("binary", arg1, arg2)`. O mejor: no usar comandos OS. |
| `db.Query("SELECT * FROM t WHERE id=" + userInput)` | SQL injection | Parameterized queries: `db.Query("... WHERE id=$1", userInput)` |
| `template.Execute(w, userInput)` (text/template) | XSS si el output va a HTML | `html/template` para HTML. `text/template` solo para texto plano (logs, email). |
| `log.Printf("ctx_id=%s", userCtxID)` sin validar | Log injection: atacante inyecta `\n` para falsificar entradas | Validar UUID ANTES de loguear. Si no es UUID → loguear como `invalid_input=<hash>` |
| "Sanitizar" removiendo `<script>` | Denylist es trivial de bypassear (`<scr<script>ipt>`) | Allowlist de caracteres seguros. Si no es seguro → rechazar, no "limpiar". |
| `filepath.Join("/var/www/uploads", userFilename)` | Path traversal: `../../../etc/passwd` | `filepath.Clean()` + verificar prefijo + nombre generado por servidor (UUID) |
| Confiar en validación del frontend | El atacante no usa tu frontend — envía requests directos con curl | Validar SIEMPRE en el servidor. La validación del cliente es UX, no seguridad. |

---

#### 12. Auditoría de Seguridad de Red

##### 12.1 Eventos de Auditoría Obligatorios

| Evento | Cuándo | Campos |
|--------|--------|--------|
| `context.validate` | Cada GET /api/v1/context/{ctx_id} | ctx_id, tenant_id, source_ip, result, timestamp, duration_ms |
| `context.validate.error` | ctx_id inválido/expirado/no encontrado | ctx_id, source_ip, error_code, timestamp |
| `context.validate.ratelimit` | Rate limit excedido | source_ip, timestamp |
| `tls.handshake` | Nueva conexión TLS | source_ip, cipher_suite, tls_version, timestamp |
| `websocket.connect` | Nuevo WebSocket | origin, source_ip, timestamp |

##### 12.2 Métricas Prometheus

```go
var (
    contextValidations = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "bos_context_validations_total",
            Help: "Total de validaciones de ctx_id por resultado",
        },
        []string{"result"}, // "valid", "expired", "not_found", "invalid_format"
    )
    contextValidationLatency = prometheus.NewHistogram(
        prometheus.HistogramOpts{
            Name:    "bos_context_validation_duration_seconds",
            Help:    "Latencia de validación de ctx_id",
            Buckets: []float64{.001, .005, .01, .025, .05, .1, .25, .5, 1},
        },
    )
)
```

---

#### 13. Checklist de Cumplimiento para Desarrolladores

Antes de mergear cualquier PR que agregue un endpoint, puerto o protocolo nuevo:

##### Bloque A — Justificación

- [ ] ¿Está documentado POR QUÉ este endpoint/puerto/protocolo es necesario?
- [ ] ¿Se consideró usar un canal YA EXISTENTE en lugar de crear uno nuevo?
- [ ] ¿Se aplicó la Regla de Reducción (§1.1)?

##### Bloque B — Superficie de Ataque

- [ ] ¿El endpoint expone SOLO los datos que el consumidor necesita? (NRS-06)
- [ ] ¿Es 1 endpoint en lugar de N? (NRS-05)
- [ ] ¿Acepta SOLO GET si es consulta, POST si es acción?
- [ ] ¿Valida estrictamente el formato de entrada (UUID, regex, rango)?

##### Bloque C — Transporte

- [ ] ¿Usa TLS 1.3? (NRS-01)
- [ ] ¿Usa Unix socket o WebSocket wss://? (NRS-02)
- [ ] ¿Si es REST, es la excepción documentada Kong→BOS?
- [ ] ¿Los cipher suites son solo ECDHE+AES-256-GCM+SHA384?

##### Bloque D — Autorización

- [ ] ¿Cada request se autentica independientemente? (Zero Trust §4)
- [ ] ¿Se verifica el tenant_id en cada request?
- [ ] ¿Rate limit está implementado? (NRS-08)

##### Bloque E — Sanitización

- [ ] ¿Todo input se valida con allowlist, no denylist? (SAN-01)
- [ ] ¿La validación está centralizada en UN solo paquete? (SAN-02)
- [ ] ¿Se canonicaliza el input antes de validar? (SAN-03)
- [ ] ¿Se rechaza el request en fallo de validación (nunca "sanitizar silenciosamente")? (SAN-04)
- [ ] ¿Cada campo tiene tipo estricto, longitud máxima, y rango definido? (SAN-05, SAN-06)
- [ ] ¿Se usa `DisallowUnknownFields()` en JSON decoding? (SAN-10)
- [ ] ¿Nunca se concatena user input en comandos OS, SQL, o paths? (SAN-07, SAN-08)
- [ ] ¿Los IDs son UUID v4? (SAN-09)
- [ ] ¿El encoding de salida es específico al contexto? (SAN-07)

##### Bloque F — Auditoría

- [ ] ¿Cada operación genera audit_event? (NRS-09)
- [ ] ¿Se registra ctx_id, source_ip, resultado, timestamp?
- [ ] ¿Los secretos están excluidos de logs y responses? (NRS-10)

---

#### 14. Referencias y Normas

##### Estándares Internacionales

| Estándar | Qué aporta |
|----------|-----------|
| **NIST SP 800-207** (Zero Trust Architecture) | 7 principios ZTA, componentes lógicos PE/PA/PEP, trust algorithm |
| **NSA/CISA K8s Hardening Guide** | NetworkPolicy deny-all, mTLS, Pod Security Admission, least privilege |
| **CIS Kubernetes Benchmark v8** | Controles 5.3.1 (NetworkPolicy), 5.4.1 (TLS), 5.7.x (RBAC) |
| **OWASP API Security Top 10 (2023)** | API1 (broken auth), API2 (broken authZ), API3 (data exposure), API4 (resource exhaustion) |
| **ISO/IEC 27001:2022** | A.8.12 (data masking), A.8.15 (audit logging), A.8.20 (network security), A.8.22 (web filtering) |
| **NIST SP 800-52 Rev 2** | TLS 1.3 cipher suites, certificate management |
| **STRIDE** (Microsoft Threat Modeling) | Spoofing, Tampering, Repudiation, Information Disclosure, DoS, Elevation |
| **OWASP Input Validation Cheat Sheet (2025)** | Allowlist, canonicalización, validación centralizada, rechazo en fallo |
| **OWASP API Security Top 10 (2023)** | API1 (BOLA), API2 (broken auth), API3 (mass assignment), API8 (injection) |
| **OWASP ASVS v5.0** | V1 (encoding/sanitization), V2 (validation), V12 (file upload), V14 (headers) |
| **CWE-20** (Improper Input Validation) | Validación de tipo, formato, rango, longitud en todo input |
| **CWE-116** (Improper Encoding) | Encoding de salida específico al contexto (HTML, SQL, OS, JSON) |
| **CWE-78** (OS Command Injection) | Prohibido concatenar user input en comandos OS |
| **CWE-22** (Path Traversal) | `filepath.Clean()` + verificación de prefijo + nombre UUID |
| **CWE-89** (SQL Injection) | Parameterized queries, nunca concatenación de strings |
| **NIST SP 800-53 SI-10** | Information Input Validation — validar precisión, completitud, validez, autenticidad |
| **W3C Trace Context** | ctx_id propagación en todos los logs de seguridad |

##### Documentación Interna SBOS

| Documento | Relación |
|-----------|----------|
| **SBOS-047-ISMS-ISO27001** | 20 controles ISO 27001, registro de riesgos |
| **SBOS-049-CONTEXT-PLANE** | ctx_id, dctx_id, propagación W3C |
| **SBOS-050-PORT-CATALOG** | P9: HTTP vetado entre daemons, excepción Kong→BOS |
| **SBOS-051-TENANT-SPEC** | Modelo A/B, aislamiento multi-tenant |
| **SBOS-053-DAEMON-TUI-DECOUPLING** | DTC-10 (secretos no transitan por canal), headless-first |
| **Dev_Control_Certification_Method** | §7 Alarmas de seguridad (secretos hardcodeados) |
| **DATOS-TUI-INSTALACION** | §14 DC-06 (secreto no transita por TUI) |

##### Fuentes de Investigación (2025)

- Hoop.dev — "What Zero Trust Means for REST APIs" (2025)
- Springfuse.com — "Zero Trust Microservices Security: Complete Implementation Guide" (Jul 2025)
- Thoropass — "About NIST 800-207 Compliance in 2025"
- HCLTech — "Micro-Segmentation: A Zero Trust Pillar for Controlling East-West Risk" (2025)
- Akshay Jain — "WebSocket Abuse: The Silent Threat Lurking in Modern Web Applications" (Jul 2025)
- Dev.to — "Securing Real-Time Pipelines: Auth, CORS, and DoS Protection" (2025)
- Atmosly — "Kubernetes Security Checklist: 50 Best Practices" (2025)

---

*SBOS-054-NETWORK-SECURITY.md v1.2 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
*v1.3: §8 ampliado con 5 subsecciones nuevas (8.7–8.11): flujo de creación ctx_id, estructura completa,*
*propagación W3C/OTel, TTL específicos DeviceContext(8h)/SessionContext(12h), cadena de dependencias.*
*Referencias completas: SBOS-049 §5.2-§5.4, ADR-033, RB-03-CONTEXT-PLANE-DOWN.*
*Este documento es normativo. Todo desarrollo que implique comunicación entre componentes DEBE cumplir las reglas NRS + SAN.*
*Actualizar cuando se agregue un nuevo vector de comunicación, se detecte una nueva amenaza, o se adopte un nuevo estándar.*


---

## 5. Referencias e historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.1.0 | 2026-07-11 | **Añadida verificación de código real** (§3.bis: Unix socket+anti-DoS reales pero evaluador D7 delgado (63 líneas), NRS doctrina). |
| 1.0.0 | 2026-07-11 | Anexo inicial: la norma SBOS-054 en una vista (superficie mínima, STRIDE, defensa en profundidad, ZT interno, NRS, ctx_id-token, wss, DoS, sanitización, auditoría, checklist), verificación de coherencia (D7, ADR-020, Context Plane) y traslado fiel íntegro. |
