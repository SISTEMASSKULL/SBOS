---
codigo: BNOTIFY-004
version: 1.0.0
estado: BORRADOR
gate: G0
depende_de: [BNOTIFY-001]
doctrina_que_ejerce: [D2, D5, D11, D14]
criterio_implementado: >
  La tabla aud_compliance_map contiene al menos 25 event_types con su clase asignada.
  Un evento chat.message.sent genera un registro clase B (no entra a aud_event directo).
  Un evento chat.moderation.user_banned genera un registro clase A en aud_event.
  El pipeline Merkle procesa un lote de 1000 eventos clase B y produce un digest
  verificable sin errores. Todo lo anterior verificado con verificar_afirmacion.sh
  en la VPS de staging.
---

# BNOTIFY-004 — Modelo de Eventos y Auditoría
## Taxonomía canónica de eventos, clases A/B/C y pipeline de auditoría

**Versión:** 1.0.0 · **Gate:** G0 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §4.2, §4.3, ADR-009 (NATS/JetStream)
**Incorpora:** `07-incrementos-bauth-para-mensajeria.md` v1.0 (doc. 07 de REPARACIONBAUTH)

---

## 1. Propósito y alcance

Este documento define:
1. La taxonomía canónica de eventos del ecosistema (las familias `chat.*`, `notify.*`, `identity.*`)
2. Las **clases de auditoría A/B/C** — el incremento conceptual central del doc. 07 §3
3. El pipeline de procesamiento hacia `aud_event` y los lotes Merkle clase B
4. Las reglas de proporcionalidad de la auditoría (lo que no se registra)

**Principio D2 — La auditoría registra hechos, no intenciones.** Cada evento
tiene un `event_type` en un espacio de nombres estable. Los procesadores lo
consumen, clasifican y persisten. Ningún daemon genera eventos ad-hoc fuera de
esta taxonomía.

---

## 2. El problema de escala y la solución de tres clases

`aud_event` en bAuth es WORM con hash-chain — correcto para eventos de alto valor.
Inviable como destino directo de millones de eventos de mensajería diarios.

Con la meta de capacidad (doc. 07 §4.2: validaciones de ctx_id y pico de mensajería),
el sistema genera del orden de cientos de miles de eventos por minuto en carga alta.
Registrar todos individualmente como WORM bloquea la base de datos.

**La solución (doc. 07 §3.1): clases de auditoría por valor del evento.**

| Clase | Almacenamiento | Retención | Ejemplos canónicos |
|-------|:-------------:|:---------:|---------------------|
| **A — WORM directa** | `aud_event` individual + hash-chain + anclaje Merkle | 7–10 años | Autenticación, cambios de tier KYC, acciones de moderación, operaciones de wallet, cambios administrativos, accesos a contenido reportado |
| **B — WORM agregada (digest Merkle)** | Hojas en almacenamiento frío; solo el digest del lote (raíz Merkle + conteos) en `aud_event` | 90–365 días | Metadatos de mensajes (quién→quién, cuándo, tipo — nunca contenido), altas de sala, membresías |
| **C — Telemetría** | Métricas agregadas a Prometheus/analítica; sin garantía WORM | 7–30 días | Presencia, typing, lecturas, conexiones |

---

## 3. Taxonomía de eventos canónica

### 3.1 Convención de nombres

Formato: `{dominio}.{recurso}.{acción}`

- Dominio: `chat`, `notify`, `identity`, `wallet`, `system`, `mfa`, `calendar`, `invoice`
- Recurso: sustantivo del objeto afectado
- Acción: verbo en pasado (ej: `created`, `sent`, `banned`)

Todos los eventos del ecosistema SBOS siguen esta convención. Un event_type fuera
de esta taxonomía es rechazado por el clasificador de auditoría.

### 3.2 Familia `chat.*` — Mensajería

| event_type | Clase | Qué registra (no el contenido, solo metadatos) |
|-----------|:-----:|------------------------------------------------|
| `chat.room.created` | B | room_id, creator_user_id, tenant_id, ctx_id |
| `chat.room.member_added` | B | room_id, added_user_id, adder_user_id |
| `chat.room.member_removed` | B | room_id, removed_user_id, actor_user_id |
| `chat.room.ownership_transferred` | B | room_id, old_owner, new_owner |
| `chat.room.archived` | B | room_id, actor_user_id |
| `chat.message.sent` | B | message_id, room_id, sender_user_id, tipo (text/media/forwarded), tamaño_bytes — **nunca el contenido** |
| `chat.message.edited` | B | message_id, editor_user_id, timestamp |
| `chat.message.deleted_own` | B | message_id, user_id |
| `chat.message.deleted_any` | A | message_id, moderator_user_id — moderación directa |
| `chat.media.uploaded` | B | media_id, uploader_user_id, size_bytes, mime_type |
| `chat.media.downloaded` | B | media_id, downloader_user_id |
| `chat.moderation.report_filed` | A | report_id, reporter_user_id, reported_item_id, reason |
| `chat.moderation.reported_content_viewed` | A | report_id, moderator_user_id — **quién de moderación vio qué contenido, siempre WORM** |
| `chat.moderation.content_hidden` | A | report_id, moderator_user_id, action |
| `chat.moderation.user_suspended` | A | target_user_id, moderator_user_id, reason, duration |
| `chat.moderation.user_banned` | A | target_user_id, moderator_user_id, reason |
| `chat.moderation.appeal_resolved` | A | appeal_id, moderator_user_id, resolution |
| `chat.abuse.rate_limited` | A | user_id, event_count, window_seconds |
| `chat.abuse.auto_suspended` | A | user_id, strikes_count, trigger_atom |
| `chat.abuse.strike_added` | A | user_id, strike_reason, actor_user_id |

### 3.3 Familia `identity.*` — Ciclo de vida de la identidad

| event_type | Clase | Qué registra |
|-----------|:-----:|--------------|
| `identity.self_registered` | A | user_id, method (PHONE_OTP, EMAIL), tenant_id, ctx_id |
| `identity.phone_verified` | A | user_id, phone_hash (no el número — solo hash SHA256), ctx_id |
| `identity.tier_promoted` | A | user_id, from_tier, to_tier, evidence_ref |
| `identity.device_bound` | A | user_id, device_id, platform, ctx_id |
| `identity.session_revoked` | A | ctx_id, user_id, reason (CAEP event) |
| `identity.credential_changed` | A | user_id, credential_type, ctx_id |
| `identity.account_deleted` | A | user_id (opaco post-seudonimización), timestamp |

### 3.4 Familia `notify.*` — Ciclo de vida de las notificaciones

| event_type | Clase | Qué registra |
|-----------|:-----:|--------------|
| `notify.intent.accepted` | C | delivery_id, intent_id, event_type origen, priority |
| `notify.intent.rejected` | B | delivery_id, reason, intent_id |
| `notify.delivery.completed` | C | delivery_id, channel, latencia_ms |
| `notify.delivery.failed` | B | delivery_id, channel, reason, attempt_count |
| `notify.delivery.dlq` | A | delivery_id, all_channels_tried, final_state |
| `notify.caep.session_revoked` | A | ctx_id, received_at, deliveries_cancelled_count |

### 3.5 Familias de otros daemons (referencia para el clasificador)

| event_type (prefijo) | Clase | Daemon fuente |
|---------------------|:-----:|---------------|
| `mfa.*` | A | bAuth |
| `security.*` | A | bAuth / Kong |
| `wallet.*`, `payment.*` | A | bPay |
| `invoice.*` | B | Tryton / bIedata |
| `calendar.*` | B | bCalendar |
| `system.*` | C | múltiples |
| `presence.*` | C | bChat |

---

## 4. Pipeline de procesamiento de eventos

```
Daemon emisor
    │
    ▼ (NATS subject: bnotify.events.{dominio}.{clase})
NATS JetStream
    │
    ▼
Clasificador de auditoría (bNotify)
    │
    ├──── Clase A ──→ aud_event (PostgreSQL, INSERT WORM)
    │                      │
    │                      └──→ hash-chain (SHA256 del evento anterior)
    │
    ├──── Clase B ──→ audit_leaf_buffer (almacenamiento frío / S3)
    │                      │
    │                      └──→ (cada minuto) blk_merkle_batch (raíz Merkle del lote)
    │                                              │
    │                                              └──→ aud_event (solo el digest)
    │
    └──── Clase C ──→ Prometheus metrics (contadores, gauges)
                              │
                              └──→ Grafana / analítica
```

### 4.1 Frecuencia de los lotes Merkle (clase B)

- Lotes por minuto en régimen normal (no por evento — nunca esperar a acumular N eventos fijos)
- Cada lote contiene: `lote_id`, `started_at`, `ended_at`, `event_count`, `merkle_root`, `first_leaf_hash`, `last_leaf_hash`
- Las hojas individuales se almacenan en S3 (bucket `audit-leaves`) indexadas por `lote_id/leaf_seq`
- Un auditor puede reconstruir el árbol Merkle y verificar cualquier hoja contra el digest en `aud_event`

### 4.2 Invariantes del pipeline

1. **Orden de eventos en el lote:** los leaves se procesan en order de su timestamp de llegada al clasificador
2. **Sin pérdida de clase A:** si el INSERT de `aud_event` falla, el evento clase A se reencola en NATS — la entrega es at-least-once con deduplicación por `intent_id`
3. **Clase B y fallo:** si el writer S3 falla, el lote se marca `FAILED` en `blk_merkle_batch` y se reintenta; el lote nunca se descarta silenciosamente
4. **Clase C y fallo:** la pérdida de telemetría es aceptable — no requiere reintento

---

## 5. Principio de proporcionalidad — lo que NO se registra

(Formaliza la política de doc. 07 §3.3)

| Tipo de dato | ¿Se registra? | Justificación |
|-------------|:-------------:|---------------|
| Contenido de mensajes | **NO** | Privacidad; con E2EE el servidor no puede leerlos |
| Texto de mensajes borrados | **NO** | Idem; la baja está en clase B, no el contenido |
| Número de teléfono en texto plano | **NO** | Solo `SHA256(phone_number)` en identidad |
| Metadatos de sala + autor + timestamp | SÍ (clase B) | Necesario para trazabilidad |
| Acciones de moderación | SÍ (clase A) | Rendición de cuentas de moderadores |
| Acceso de moderador a contenido reportado | SÍ (clase A) | Quién vio qué — siempre WORM |

**Entrada en la base de políticas bAuth:**
- `D11.chat.content_logging = forbidden`
- `D11.chat.reported_content_access = worm_mandatory`
- `D11.chat.metadata_retention_days` — **pendiente de validación legal boliviana** (Ley de Telecomunicaciones, habeas data Art. 130 CPE); no asumir un número hasta asesoría legal

---

## 6. Derecho de supresión vs WORM

(Formaliza doc. 07 §7)

Cuando un usuario solicita la eliminación de su cuenta:

1. Sus atributos personales (`idn_atributo`) se anonimi-zan/eliminan del registro de identidad
2. Los eventos en `aud_event` que referencian `user_id` conservan el UUID opaco — el UUID ya no es resoluble a una persona
3. Las hojas clase B en S3 de sus mensajes conservan el `sender_id` como UUID opaco — sin atributos resolubles
4. **La cadena de integridad WORM no se rompe** — los hashes permanecen, la persona no es identificable a partir de ellos

**Políticas en bAuth:**
- `D11.privacy.erasure_strategy = pseudonymize`
- `D11.privacy.erasure_sla_days` — pendiente de validación legal boliviana

---

## 7. Tablas de base de datos (referencia — DDL canónico en BNOTIFY-008)

Las siguientes tablas implementan este modelo. El DDL completo con columnas, tipos,
índices y GRANTs está en BNOTIFY-008.

| Tabla | Schema | Propósito |
|-------|--------|-----------|
| `aud_event` | `bauth` | Eventos clase A — WORM, hash-chain |
| `aud_compliance_map` | `bauth` | Tabla de clasificación: event_type → clase |
| `blk_merkle_batch` | `bauth` | Manifesto de cada lote clase B (digest + conteos) |
| `notification_event` | `bnotify` | Log de cada intent: estado, canal, intentos, ctx_id |

**Vista cruzada requerida por bNotify:**
```sql
-- En schema bnotify, vista de solo lectura sobre bauth.aud_compliance_map
CREATE VIEW bnotify.v_audit_class AS
SELECT event_type, audit_class
FROM bauth.aud_compliance_map;
-- GRANT SELECT ON bnotify.v_audit_class TO bnotify_ro;
```

---

## 8. Modelo de capacidad — objetivos del pipeline (para BNOTIFY-070)

Los objetivos numéricos de capacidad del pipeline de auditoría deben derivarse del
pico de mensajería del proyecto. Se reservan estos slots en BNOTIFY-070:

| Métrica | Objetivo | Notas |
|---------|:--------:|-------|
| Eventos clase B procesados/segundo | ≥ pico de `chat.message.sent` | Definir en BNOTIFY-070 |
| Latencia INSERT clase A (p99) | < 50ms | Eventos de seguridad no pueden esperar |
| Tamaño del lote Merkle típico | ≥ 1.000 hojas | Balance entre sobrecarga y granularidad |
| Lotes Merkle por minuto en pico | TBD | Función del throughput de mensajes |

⚠️ El dimensionamiento real de Redis para validación ctx_id en reconexiones
concurrentes (doc. 07 §4.2: excepción estructural #1) y el pipeline Merkle de
alto volumen (doc. 07 §8: excepción estructural #2) se formalizan como tareas
FASE 7.X y FASE 11.X en el documento de expansión de REPARACIONBAUTH.

---

*BNOTIFY-004 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*La auditoría que calla es peor que la que miente. La que registra todo colapsa. Las tres clases son el equilibrio.*
