---
codigo: BNOTIFY-042
version: 1.0.0
estado: BORRADOR
gate: G3
depende_de: [BNOTIFY-040]
doctrina_que_ejerce: [D1, D6, D14, D15]
criterio_implementado: >
  Un cliente anónimo (T0) puede abrir un ticket desde el widget web.
  El ticket llega a la bandeja del agente en bChat.
  El agente puede responder y el cliente ve la respuesta en el widget.
  La transferencia de ticket entre agentes funciona.
  El cierre del ticket queda registrado con tiempo de resolución.
  Verificado con verificar_afirmacion.sh en VPS.
---

# BNOTIFY-042 — Módulo Atención al Cliente
## Bandeja omnichannel first-party: cola, agentes, transferencias, métricas, widget web

**Versión:** 1.0.0 · **Gate:** G3 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-040 (manifiesto módulos) · BNOTIFY-041 (runtime WASM)
**Equivalencia:** reemplaza Livechat de bRocket

---

## 1. Propósito

Este módulo implementa la funcionalidad de **atención al cliente / soporte** que en bRocket era Livechat. A diferencia de Livechat, este módulo:

- Corre nativo en bChat como módulo first-party (no una integración externa)
- Soporta clientes anónimos (T0) sin necesidad de crear cuenta en SBOS
- Conecta canales entrantes: widget web, email entrante (cuando esté BNOTIFY-044 activo), SMS entrante (futura integración)
- Expone métricas de cola y resolución en tiempo real

---

## 2. Actores del módulo

| Actor | Tier | Descripción |
|-------|------|-------------|
| **Visitante** | T0 (anónimo) | Abre ticket desde widget web sin cuenta |
| **Cliente** | T0-T2 | Usuario registrado que abre ticket |
| **Agente** | T1 | Empleado que atiende tickets en la bandeja |
| **Supervisor** | T2 | Puede ver todos los tickets y transferir entre agentes |

---

## 3. Ciclo de vida de un ticket

```
NUEVO
  │ Agente toma el ticket o es asignado por auto-distribución
  ▼
EN ATENCIÓN
  │ Conversación entre agente y cliente
  ▼
TRANSFERIDO (opcional — supervisor o agente lo mueve)
  │
  ▼
RESUELTO
  │ Agente marca como resuelto
  ▼
CERRADO
  │ Automático tras 24h sin respuesta del cliente
  ▼
ARCHIVADO
```

---

## 4. Esquema de datos del módulo

El módulo usa el schema `bchat` (es un módulo bChat, no bNotify):

```sql
CREATE TABLE bchat.ticket (
    id              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       TEXT        NOT NULL,
    ctx_id          UUID        NOT NULL,

    room_id         UUID        NOT NULL REFERENCES bchat.room(id),
    visitor_email   TEXT        NULL,     -- Para visitantes anónimos
    visitor_name    TEXT        NULL,
    bauth_user_id   UUID        NULL,     -- NULL si es anónimo

    -- Asignación
    agent_id        UUID        NULL,     -- bauth_user_id del agente
    department_id   UUID        NULL,

    -- Estado
    status          TEXT        NOT NULL DEFAULT 'NUEVO',
    priority        TEXT        NOT NULL DEFAULT 'NORMAL',  -- 'BAJA', 'NORMAL', 'ALTA'

    -- Métricas de resolución
    first_response_at TIMESTAMPTZ NULL,
    resolved_at     TIMESTAMPTZ NULL,
    closed_at       TIMESTAMPTZ NULL,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ticket_tenant_status ON bchat.ticket (tenant_id, status)
    WHERE status NOT IN ('CERRADO', 'ARCHIVADO');
CREATE INDEX idx_ticket_agent ON bchat.ticket (agent_id, status)
    WHERE agent_id IS NOT NULL;
```

---

## 5. Widget web

El widget web es un componente JavaScript incrustable en cualquier sitio del cliente:

```html
<!-- Incrustación del widget en el sitio del cliente -->
<script src="https://sbos.{dominio_cliente}/bchat-widget.js"></script>
<script>
  BchatWidget.init({
    tenant: '{tenant_id}',
    department: 'soporte',  // Opcional
    color: '#0066CC',
    welcome: '¿En qué podemos ayudarte?'
  });
</script>
```

El widget:
- Abre una conexión WebSocket al motor bChat como usuario anónimo (genera un `visitor_id` efímero)
- Permite conversar con agentes sin crear cuenta
- Persiste la sesión con `localStorage` para reanudar conversaciones
- Es responsive (funciona en móvil)

### 5.1 Identificación de visitantes anónimos

```
Visitante → Widget → bchat.atencion.open_ticket(visitor_name, visitor_email, mensaje_inicial)
                     ↓
                Motor bChat
                  - Crea sala tipo 'direct' con nombre "Ticket #{id}"
                  - Crea registro en bchat.ticket (bauth_user_id = NULL)
                  - Asigna a la cola del department o al siguiente agente disponible
                  - Notifica a agentes disponibles via bNotify
```

---

## 6. Métodos RPC del módulo

| Método | Actor | Descripción |
|--------|-------|-------------|
| `atencion.ticket.abrir` | Visitante/Cliente | Abre nuevo ticket con mensaje inicial |
| `atencion.ticket.responder` | Agente | Responde en el ticket (es un mensaje normal de bChat) |
| `atencion.ticket.transferir` | Agente/Supervisor | Transfiere a otro agente o departamento |
| `atencion.ticket.resolver` | Agente | Marca ticket como resuelto |
| `atencion.ticket.cerrar` | Agente/Supervisor | Cierre definitivo |
| `atencion.cola.estado` | Agente/Supervisor | Estado de la cola en tiempo real |
| `atencion.agente.disponibilidad` | Agente | Marca disponible/no disponible |
| `atencion.metricas.resumen` | Supervisor | CSAT, tiempo medio de respuesta, tickets por estado |

---

## 7. Auto-distribución de tickets

Cuando un ticket entra y hay agentes disponibles, el módulo lo asigna automáticamente por round-robin:

```
Cola de tickets NUEVO
  → Agentes disponibles (estado = 'disponible')
  → Selección: el agente con menor número de tickets activos
  → Asignación + notificación al agente vía bNotify
```

Si no hay agentes disponibles, el ticket permanece en cola `NUEVO` y el visitante ve un mensaje de espera. Cuando un agente se pone disponible, el módulo le asigna el primer ticket de la cola.

---

*BNOTIFY-042 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*El widget web es la cara del módulo. La bandeja del agente es el corazón. Los tickets son la memoria.*
