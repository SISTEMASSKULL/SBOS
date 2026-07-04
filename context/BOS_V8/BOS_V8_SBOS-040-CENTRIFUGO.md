# SBOS-040-CENTRIFUGO
## Bus WebSocket en Tiempo Real — Estándar HUMAN-DOC
### SKULL · SBOS · v1.0 · Abril 2026

---

## 1. Propósito

Centrifugo = bus de mensajería real-time del SBOS. WebSocket escalable para Core UI, VDI y apps web → actualizaciones instantáneas sin polling.

**Diferencia con bhnexus:** bhnexus gestiona WebSocket con banexus (agentes edge de seguridad). Centrifugo gestiona WebSocket con usuarios finales (browsers, Flutter).

## 2. Arquitectura

```
Centrifugo (Pod K8s sbos-comms)
  Backend: Redis (pub/sub para clustering)
  Auth: JWT de Keycloak (verificado vía JWKS endpoint)

Productores (Redis pub): bos, bkernel, bauth, bcompass, bsearch
Consumidores (WebSocket): Core UI (Flutter), SBOS VDI, apps web
```

## 3. Canales

| Canal | Productor | Consumidor | Contenido |
|---|---|---|---|
| bos:operations:{id} | PROGRESS_EMITTER daemon bos | Core UI | Progreso install/update/repair |
| bos:fichas:state | STATE_MANAGER daemon bos | Core UI | Cambios estado fichas |
| bos:alerts | HEALTH_CHECKER + GROWTH_DETECTOR | Core UI | Alertas sistema |
| bkernel:events | bkernel vía Redis | Core UI + bcompass | Eventos sincronización WAL |
| bauth:sync | bauth | Core UI | Cambios roles/templates |
| bsearch:results:{user} | bsearch | Core UI | Resultados búsqueda real-time |
| bcompass:analysis:{id} | bcompass | Core UI | Progreso análisis IA |
| app:{app}:notifications | Apps del stack | SBOS VDI | Notificaciones por app |

## 4. Autenticación

```
Usuario → KC → JWT → Core UI conecta wss://skull.io/ws (Bearer JWT)
Centrifugo verifica JWT vía JWKS endpoint KC
  sbos-admin → todos los canales
  sbos-operator → bos:*, bkernel:events, bauth:sync
  sbos-viewer → bos:fichas:state, bos:alerts
  JWT inválido → 401
```

## 5. Configuración

```json
{
  "port": 8000,
  "admin_port": 8001,
  "engine": "redis",
  "redis_address": "redis.sbos-data.svc:6379",
  "token_jwks_public_endpoint": "https://keycloak.sbos-identity.svc/realms/sbos/protocol/openid-connect/certs",
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

publish: false en todos → solo los daemons publican vía Redis Server API, nunca los clientes WebSocket.

---

## Trazabilidad

| Sección | Extraída de | Secciones originales |
|---|---|---|
| §1-2 | SBOS-037 v1.0 | §1-§2 (propósito, arquitectura, diferencia con bhnexus) |
| §3 Canales | SBOS-037 v1.0 | §4 (tabla 8 canales con productor/consumidor/contenido) |
| §4 Auth | SBOS-037 v1.0 | §3 (flujo JWT, permisos por rol) |
| §5 Config | SBOS-037 v1.0 | §5 (JSON completo con namespaces) |

---

---

# ENRIQUECIMIENTO V8 — SBOS-040-CENTRIFUGO

## V5 — Enriquecimiento desde BOS_V5_SBOS-037-CENTRIFUGO-v1_0

### V5 §1 — Arquitectura Expandida

```
                    ┌─────────────────────────────────────┐
                    │          SBOS CLUSTER (K8s)          │
                    │                                      │
  DAEMONS           │   ┌─────────────────────────────┐    │
  (systemd host)    │   │      Centrifugo Pod          │    │  CLIENTES
                    │   │  ┌───────────────────────┐   │    │
 bos ──┐            │   │  │   centrifugo:8000     │   │    │  ┌─────────┐
       │            │   │  │   WebSocket Server     │◄──┼────│ Core UI  │
 bkernel ──┐        │   │  └──────────┬────────────┘   │    │  (Flutter)│
          │         │   │             │                │    └─────────┘
 bauth ───┼─Redis───┼───►  Redis Pub  │                │    ┌─────────┐
          │         │   │  ┌──────────▼────────────┐   │    │SBOS VDI │
 bcompass ─┤        │   │  │  Redis Server API     │   │    │ (Fedora) │
          │         │   │  │  port: 8001            │   │    └─────────┘
 bsearch ──┘        │   │  └───────────────────────┘   │    ┌─────────┐
                    │   └─────────────────────────────┘    │ Apps Web│
                    │                                      └─────────┘
                    └─────────────────────────────────────┘
```

### V5 §2 — Flujo de Autenticación JWT Detallado

```
1. Usuario se autentica en Keycloak (realm sbos)
2. Keycloak emite JWT con claims:
   {
     "sub": "user-uuid",
     "preferred_username": "admin",
     "realm_roles": ["sbos-admin"],
     "centrifugo": {
       "sub": "user-uuid",
       "info": {"username": "admin", "tenant": "skull"}
     }
   }
3. Core UI recibe JWT y conecta WebSocket:
   wss://skull.io/ws?token=<JWT>
4. Centrifugo recibe conexión y verifica:
   a. JWT firmado RS256 (vía JWKS endpoint de Keycloak)
   b. Extrae centrifugo.sub para identificar al usuario
   c. Extrae centrifugo.info para metadatos
   d. Aplica permisos según realm_roles:
      - sbos-admin → subscripción a todos los canales
      - sbos-operator → subscripción a bos:*, bkernel:events
      - sbos-viewer → subscripción a bos:fichas:state, bos:alerts
5. Conexión establecida o 401 si JWT inválido/expirado
```

### V5 §3 — Canales Expandidos

| Canal | Productor | Consumidor | Formato payload | Frecuencia |
|---|---|---|---|---|
| bos:operations:{id} | bos daemon | Core UI | `{"type":"progress","pct":55,"status":"installing"}` | Cada 5% de avance |
| bos:fichas:state | bos STATE_MANAGER | Core UI | `{"ficha":"postgresql","status":"healthy","uptime":"48h"}` | Cada cambio de estado |
| bos:alerts | HEALTH_CHECKER | Core UI | `{"severity":"critical","alert":"PG down","runbook":"RK-001"}` | Evento |
| bkernel:events | bkernel | Core UI, bcompass | `{"event":"sync","source":"tryton","target":"saleor"}` | Evento WAL |
| bauth:sync | bauth | Core UI | `{"type":"rolemapping","user":"uuid","bits":"0x..."}` | Tras cambio rol |
| bsearch:results:{user} | bsearch | Core UI | `{"query":"factura-001","matches":3,"results":[...]}` | Por búsqueda |
| bcompass:analysis:{id} | bcompass | Core UI | `{"type":"progress","step":"2/5","status":"analyzing"}` | Cada paso |
| app:{app}:notifications | Apps stack | VDI, Core UI | `{"type":"email","from":"cliente@foo.com","subject":"..."}` | Evento |

---

## Smart* — Enriquecimiento desde Subproyectos SBOS

### Smart ORC — Integración con Centrifugo

SmartORC utiliza Centrifugo para tres tipos de notificaciones en tiempo real:

1. **Nuevo documento en buzón:** Cuando un documento es transferido a un funcionario, Centrifugo notifica el canal personal del funcionario
2. **Escalamiento por vencimiento:** Cuando un documento ROJO supera el plazo sin acción, Centrifugo emite alerta al canal del Gerente del área
3. **Cambio de prioridad automática:** El job de prioridad de SmartORC publica cambios de cuadrante en tiempo real

**Canal específico de ORC:** `orc:{tenant}:{empresa}:{user_id}` — canal privado por usuario con filtro de tenant. Suscripción verificada vía JWT para garantizar aislamiento entre empresas del mismo tenant.

### Smart Vault Flow — Integración con Centrifugo

SmartVault utiliza Centrifugo para el flujo de aprobación:

1. **Notificación de aprobación pendiente:** Cuando se inicia un flujo de aprobación, el firmante recibe notificación en tiempo real en el canal `vault:{user_id}`
2. **Escalamiento de paso vencido:** Si un paso de aprobación vence, Centrifugo notifica al canal del administrador
3. **Confirmación de entrega:** Cuando un destinatario confirma recepción de un activo, Centrifugo notifica al custodio

**Canal específico de Vault:** `vault:{tenant}:{user_id}` — canal privado para notificaciones de custodia y aprobación.

---

## Fuentes de Enriquecimiento V8

| Fuente | Archivo | Secciones utilizadas |
|---|---|---|
| V6 original | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V6_SBOS-040-CENTRIFUGO.md` | Documento completo (84 líneas) |
| V5 Centrifugo | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-037-CENTRIFUGO-v1_0.md` | §1 Arquitectura diagrama, §2 Flujo JWT detallado, §3 Canales expandidos con formatos payload |
| SmartORC Seguridad | `/opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart ORC/context/BOSORC-008-SEGURIDAD.md` | Canales ORC para notificaciones en tiempo real, clasificación de documentos por canal |
| SmartVault Operación | `/opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Vault Flow/context/SBOS-VAULT-009-OPERACION.md` | Integración Centrifugo para flujo de aprobación y escalamiento |

---

_SKULL · SBOS · SBOS-040-CENTRIFUGO · V8 (V6+V5+Smart*) · Mayo 2026_
