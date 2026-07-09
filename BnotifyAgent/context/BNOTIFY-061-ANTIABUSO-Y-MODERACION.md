---
codigo: BNOTIFY-061
version: 1.0.0
estado: BORRADOR
gate: G5
depende_de: [BNOTIFY-004, BNOTIFY-042]
doctrina_que_ejerce: [D11, D14, D15]
criterio_implementado: >
  Un usuario que supera el límite de mensajes por minuto recibe error de rate limit.
  Un reporte de contenido por un usuario genera un evento de auditoría clase A (WORM).
  Un moderador puede silenciar a un usuario y el sistema lo registra con ctx_id.
  Un usuario con 3 strikes por violaciones recibe suspensión temporal.
  Verificado con verificar_afirmacion.sh en VPS.
---

# BNOTIFY-061 — Antiabuso y Moderación
## Átomos REGLA, strikes, workflow de reportes, rendición de cuentas WORM

**Versión:** 1.0.0 · **Gate:** G5 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-004 (eventos y auditoría), BNOTIFY-042 (atención al cliente), BNOTIFY-000 §D.11

---

## 1. Principios de moderación (D11)

El sistema de moderación aplica el principio de **proporcionalidad** de D11:

- **Contenido:** nunca se analiza automáticamente el contenido de mensajes para moderación. Solo se actúa sobre reportes de usuarios o metadatos objetivos (rate, volumen).
- **Metadatos:** sí se analizan (quién envía, cuántos mensajes, a qué velocidad, desde qué sala)
- **Rendición de cuentas:** toda acción de moderación queda registrada en auditoría WORM clase A con el ctx_id del moderador — los moderadores también son auditados
- **Apelación:** un usuario sancionado puede apelar — el proceso de apelación también queda registrado

---

## 2. Átomos bAuth para moderación

Los átomos de moderación son de tipo `REGLA` en la nomenclatura de bAuth:

| Átomo | Holder típico | Descripción |
|-------|--------------|-------------|
| `D15.chat.moderation.REPORT_VIEW` | Moderador | Puede ver reportes de contenido |
| `D15.chat.moderation.USER_SILENCE` | Moderador | Puede silenciar usuarios en una sala |
| `D15.chat.moderation.USER_BAN` | Moderador | Puede banear usuarios de una sala |
| `D15.chat.moderation.GLOBAL_BAN` | Admin | Puede banear usuarios del tenant entero |
| `D15.chat.moderation.STRIKE_APPLY` | Moderador | Puede aplicar strikes manuales |
| `D15.chat.moderation.APPEAL_RESOLVE` | Admin | Puede resolver apelaciones |

---

## 3. Rate limiting por usuario

Los límites se aplican en el motor bChat **antes** de procesar el mensaje:

```rust
// services/message.rs — verificación de rate limit
pub async fn check_rate_limit(
    redis: &RedisPool,
    user_id: &Uuid,
    room_id: &Uuid,
    tenant_id: &str,
) -> Result<(), BchatError> {
    let key = format!("rate:msg:{}:{}", tenant_id, user_id);
    let count: i64 = redis.incr(&key).await?;
    if count == 1 {
        redis.expire(&key, 60).await?;  // Ventana de 1 minuto
    }
    // Límites según tier KYC (ver BNOTIFY-062)
    let limit = get_rate_limit_for_tier(user_id).await?;
    if count > limit {
        return Err(BchatError::RateLimitExceeded);
    }
    Ok(())
}
```

| Tier | Mensajes / minuto | Mensajes / hora |
|------|:-----------------:|:---------------:|
| T0 | 20 | 100 |
| T1 | 60 | 500 |
| T2 | 200 | 2000 |

---

## 4. Sistema de strikes

Un **strike** es una violación de los términos de uso registrada contra un usuario. Los strikes se acumulan y tienen consecuencias automáticas:

```sql
-- Schema: bchat
CREATE TABLE bchat.user_strike (
    id              UUID    NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       TEXT    NOT NULL,
    bauth_user_id   UUID    NOT NULL,
    ctx_id          UUID    NOT NULL,

    reason          TEXT    NOT NULL,  -- Descripción de la violación
    severity        TEXT    NOT NULL,  -- 'LEVE', 'GRAVE', 'MUY_GRAVE'
    issued_by       UUID    NOT NULL,  -- bauth_user_id del moderador (o 'system' para automáticos)
    issued_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    expires_at      TIMESTAMPTZ NULL,  -- NULL = permanente
    appeal_status   TEXT    NULL       -- NULL | 'APELADO' | 'RESUELTO'
);
```

### 4.1 Consecuencias automáticas

| Strikes activos | Consecuencia |
|:---------------:|--------------|
| 1 strike leve | Solo registro — aviso en perfil |
| 2 strikes leves | Silencio temporal 24h en todos los canales |
| 3 strikes leves | Suspensión temporal 7 días — requiere revisión por admin |
| 1 strike grave | Suspensión temporal 72h |
| 1 strike muy grave | Suspensión inmediata — revisión manual obligatoria |

La suspensión se implementa revocando el átomo `D1.chat.message.SEND` en bAuth para el usuario — no es una lista negra en bChat, es el control de acceso soberano de bAuth.

---

## 5. Workflow de reportes de contenido

```
Usuario reporta un mensaje
│  bchat.moderation.report({ message_id, reason, description })
▼
Motor bChat
│  → Crea bnotify.moderation_report
│  → Auditoría clase A: report.CREATED (WORM — incluye message_id, reporter_id, ctx_id)
│  → Notifica a moderadores disponibles vía bNotify
▼
Moderador revisa
│  bchat.moderation.report.review({ report_id, decision, action })
│  Decisiones posibles:
│    - 'DESESTIMAR': el reporte no tiene fundamento
│    - 'ADVERTIR': se advierte al autor del mensaje
│    - 'ELIMINAR_MENSAJE': se borra lógicamente el mensaje
│    - 'SILENCIAR_USUARIO': silencio temporal en la sala
│    - 'APLICAR_STRIKE': strike formal al usuario
▼
Registro de auditoría clase A (WORM)
│  → Decisión del moderador con ctx_id, timestamp, motivo
│  → Inmutable — no puede borrarse ni modificarse
```

### 5.1 Tabla de reportes

```sql
CREATE TABLE bnotify.moderation_report (
    id              UUID    NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       TEXT    NOT NULL,
    ctx_id          UUID    NOT NULL,

    message_id      UUID    NOT NULL,   -- bchat.message.id
    room_id         UUID    NOT NULL,
    reported_user_id UUID   NOT NULL,
    reporter_id     UUID    NOT NULL,

    reason          TEXT    NOT NULL,   -- 'SPAM', 'ACOSO', 'CONTENIDO_INAPROPIADO', etc.
    description     TEXT    NULL,

    status          TEXT    NOT NULL DEFAULT 'PENDIENTE',
    reviewer_id     UUID    NULL,
    review_decision TEXT    NULL,
    review_notes    TEXT    NULL,
    reviewed_at     TIMESTAMPTZ NULL,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## 6. Auditoría de acciones de moderación (WORM)

Toda acción de moderación genera un evento de auditoría clase A (WORM individual, retención 7 años):

```json
{
  "event_type": "chat.moderation.ACTION",
  "ctx_id": "{ctx_id_del_moderador}",
  "timestamp": "2026-07-06T10:00:00Z",
  "moderator_id": "{bauth_user_id}",
  "target_user_id": "{bauth_user_id}",
  "action": "APLICAR_STRIKE",
  "severity": "LEVE",
  "reason": "Spam en canal #general",
  "report_id": "{UUID}",
  "tenant_id": "{tenant_id}"
}
```

Los moderadores también son auditados — ninguna acción de moderación escapa al registro.

---

*BNOTIFY-061 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*Los moderadores moderan con transparencia. Todo lo que aplican, queda registrado. La rendición de cuentas es bidireccional.*
