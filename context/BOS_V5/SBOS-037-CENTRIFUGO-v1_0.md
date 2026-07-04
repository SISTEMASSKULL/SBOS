# SBOS-037-CENTRIFUGO
## Centrifugo: Bus WebSocket en Tiempo Real del SBOS
### SP-07 · Infraestructura de Mensajería

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

## 1. Propósito

Centrifugo es el bus de mensajería en tiempo real del SBOS. Proporciona WebSocket escalable para que el Core UI, el SBOS VDI, y las aplicaciones web del stack reciban actualizaciones instantáneas sin polling.

Es DIFERENTE del WebSocket de bhnexus: bhnexus gestiona conexiones con banexus (agentes de seguridad edge), mientras que Centrifugo gestiona conexiones con usuarios finales (navegadores, apps Flutter).

---

## 2. Arquitectura

```
┌──────────────────────────────────────────┐
│              Centrifugo                  │
│         (Pod K8s en sbos-comms)          │
│                                          │
│  Canales:                                │
│    bos:operations:{id}     ← progreso de instalación (Core UI)
│    bos:fichas:state        ← cambios de estado de fichas
│    bos:alerts              ← alertas del sistema
│    bkernel:events          ← eventos de sincronización
│    bauth:sync              ← cambios de roles/permisos
│    bsearch:results:{user}  ← resultados de búsqueda en tiempo real
│    bcompass:analysis:{id}  ← progreso de análisis IA
│    app:{app_name}:updates  ← notificaciones por app
│                                          │
│  Backend: Redis (pub/sub para clustering)│
│  Auth: JWT de Keycloak (verificado)      │
└──────────┬───────────────────────────────┘
           │
    ┌──────┴──────┐
    │  Productores │  bos, bkernel, bauth, bcompass, bsearch
    │  (Redis pub) │  publican eventos en Redis
    └─────────────┘
    ┌──────┴──────┐
    │  Consumidores│  Core UI (Flutter), SBOS VDI, apps web
    │  (WebSocket) │  suscritos a canales específicos
    └─────────────┘
```

---

## 3. Autenticación

```
Usuario se autentica en Keycloak → obtiene JWT
  │
  ▼
Core UI conecta a Centrifugo: wss://skull.io/ws
  Header: Authorization: Bearer <JWT>
  │
  ▼
Centrifugo verifica JWT con la clave pública de Keycloak
  │
  ├── JWT válido → conexión aceptada
  │   Canales permitidos basados en claims del JWT:
  │     sbos-admin → todos los canales
  │     sbos-operator → bos:*, bkernel:events, bauth:sync
  │     sbos-viewer → bos:fichas:state, bos:alerts
  │
  └── JWT inválido → 401, conexión rechazada
```

---

## 4. Canales y Productores

| Canal | Productor | Consumidor | Contenido |
|-------|-----------|------------|-----------|
| `bos:operations:{id}` | PROGRESS_EMITTER del daemon bos | Core UI | Progreso de install/update/repair |
| `bos:fichas:state` | STATE_MANAGER del daemon bos | Core UI | Cambios de estado de fichas |
| `bos:alerts` | HEALTH_CHECKER + GROWTH_DETECTOR | Core UI | Alertas del sistema |
| `bkernel:events` | bkernel via Redis | Core UI + bcompass | Eventos de sincronización WAL |
| `bauth:sync` | bauth | Core UI | Cambios de roles/templates |
| `bsearch:results:{user_id}` | bsearch | Core UI | Resultados de búsqueda |
| `bcompass:analysis:{id}` | bcompass | Core UI | Progreso de análisis IA |
| `app:{app}:notifications` | Aplicaciones del stack | SBOS VDI | Notificaciones por app |

---

## 5. Configuración

```json
{
  "port": 8000,
  "admin": true,
  "admin_port": 8001,
  "engine": "redis",
  "redis_address": "redis.sbos-data.svc:6379",
  "token_jwks_public_endpoint": "https://keycloak.sbos-identity.svc/realms/sbos/protocol/openid-connect/certs",
  "allowed_origins": ["https://skull.io"],
  "namespaces": [
    { "name": "bos", "publish": false },
    { "name": "bkernel", "publish": false },
    { "name": "bauth", "publish": false },
    { "name": "bsearch", "publish": false },
    { "name": "bcompass", "publish": false },
    { "name": "app", "publish": false }
  ]
}
```

---

## 6. Registro de Cambios

### v1.0 — Marzo 2026

Documento nuevo. Especificación del bus WebSocket con arquitectura de canales, autenticación JWT, productores/consumidores por daemon, y diferenciación con bhnexus WebSocket.

---

*SKULL · SBOS · SBOS-037-CENTRIFUGO · v1.0 · Marzo 2026*
