# REGISTRO DE CONTRATOS — bhnexus ↔ bAuth

**Versión:** 1.0 · **Apertura:** 2026-08-04 · **Propietarios:** agente-bhnexus + agente-bauth  
**Propósito:** Registro formal de todo lo que bhnexus le pide a bAuth y viceversa — protocolos de integración,
formatos de mensaje, comportamiento de cache, gestión de emergencias, y cualquier cambio de contrato.
Nada se implementa sin pasar por aquí.

---

## ⚠️ NORMA IRRENUNCIABLE — DOCUMENTO HISTÓRICO

**Este documento es APPEND-ONLY. Solo se agrega. Nunca se borra. Nunca se edita lo ya escrito.**

| Permitido | Prohibido |
|-----------|-----------|
| ✅ Agregar nuevos contratos (C-BHNEXUS-NNN, C-BAUTH-NNN) | ❌ Borrar un contrato |
| ✅ Escribir en el campo `Respuesta` si está vacío | ❌ Editar el campo `Necesito` de otro agente |
| ✅ Marcar checkboxes de estado como completados | ❌ Desmarcar o reescribir checkboxes ya marcados |
| ✅ Agregar filas al `HISTORIAL DE ESTADOS` | ❌ Modificar o eliminar filas del historial |
| ✅ Actualizar el estado en la `TABLA MAESTRA` | ❌ Cambiar retroactivamente un estado ya registrado |

**Si una entrada tiene un error:** Se agrega una nota de corrección debajo de la entrada original
con la fecha y el agente que la corrige. La entrada incorrecta queda visible con `~~texto~~`.

---

## CÓMO USAR ESTE DOCUMENTO

### Ciclo de vida de un contrato

```
📝 PROPUESTO          El solicitante abre el contrato y describe lo que necesita.
        ↓
💬 EN DIÁLOGO         El receptor responde — puede pedir aclaraciones, proponer alternativas.
        ↓
✅ ACORDADO           Ambos firman: el solicitante acepta la respuesta. Listo para implementar.
        ↓
🔨 IMPLEMENTANDO      El responsable de implementación está codificando.
        ↓
📦 ENTREGADO          Implementado y verificado. Commit registrado.
```

**Salidas alternativas:**
```
❌ RECHAZADO          El receptor no puede o no va a implementar. Motivo obligatorio.
🔄 ALTERNATIVA        Rechazado en la forma original pero se propone algo distinto → nuevo contrato.
⏸  PAUSADO            Bloqueado por una dependencia externa. Se retoma cuando se desbloquea.
```

### Reglas

1. **Todo contrato tiene un ID único** en formato `C-{DAEMON_SOLICITANTE}-{NNN}` (ej: `C-BHNEXUS-001`)
2. **El solicitante abre el contrato** con el campo `Necesito` completo antes de pedir respuesta
3. **El receptor responde** en el campo `Respuesta` — nunca edita el campo `Necesito` del otro
4. **El estado solo avanza** cuando hay texto en el campo correspondiente
5. **ENTREGADO requiere commit** — sin número de commit no se puede marcar como entregado
6. **Ambos firman ACORDADO** — el solicitante escribe `✓ bhnexus acepta` o `✓ bAuth acepta` en la respuesta

---

## TABLA MAESTRA

| ID | Tipo | Solicitante | Receptor | Resumen | Estado | Commit |
|----|------|:-----------:|:--------:|---------|:------:|:------:|
| [C-BHNEXUS-001](#c-bhnexus-001) | PREGUNTA_ARCH | bhnexus | bAuth | Formato del bitmask_request para credenciales biométricas (sin user_id) | ✅ | — |
| [C-BHNEXUS-002](#c-bhnexus-002) | CONTRATO_API | bhnexus | bAuth | Schema exacto del canal privilegiado /run/bos/bauth-nexus.sock | ✅ | — |
| [C-BHNEXUS-003](#c-bhnexus-003) | PREGUNTA_ARCH | bhnexus | bAuth | Quién emite el nonce para los actuator_commands (anti-replay) | 📝 | — |
| [C-BAUTH-001](#c-bauth-hnx-001) | PREGUNTA_ARCH | bAuth | bhnexus | Comportamiento de bhnexus al recibir emergency_revoke con scope=all_nodes | ✅ | — |
| [C-BAUTH-002](#c-bauth-hnx-002) | CONTRATO_API | bAuth | bhnexus | Formato de node_online: qué estadísticas debe incluir bhnexus | ✅ | — |

---

## HISTORIAL DE ESTADOS

| Fecha | ID | De | A | Agente |
|-------|----|----|---|--------|
| 2026-08-04 | C-BHNEXUS-001 | — | ✅ ACORDADO | agente-bhnexus + agente-bauth |
| 2026-08-04 | C-BHNEXUS-002 | — | ✅ ACORDADO | agente-bhnexus + agente-bauth |
| 2026-08-04 | C-BHNEXUS-003 | — | 📝 PROPUESTO | agente-bhnexus |
| 2026-08-04 | C-BAUTH-001 | — | ✅ ACORDADO | agente-bauth + agente-bhnexus |
| 2026-08-04 | C-BAUTH-002 | — | ✅ ACORDADO | agente-bauth + agente-bhnexus |

---

## CONTRATOS bhnexus → bAuth

---

### C-BHNEXUS-001

**Tipo:** PREGUNTA_ARCH  
**Solicitante:** bhnexus  
**Receptor:** bAuth  
**Prioridad:** 🔴 BLOQUEANTE  
**Fecha apertura:** 2026-08-04

#### Necesito (escribe bhnexus)

El flujo de autenticación biométrica OSDP no permite conocer el user_id de antemano — el lector solo
provee el hash del template biométrico. Necesito saber exactamente cómo estructurar el `bitmask_request`
cuando no tengo el `user_id` y solo tengo el `biometric_hash`.

Opciones que veo:
1. Enviar `user_id: null` y agregar `query_type: "biometric"` + `biometric_hash: "<sha256>"`
2. Hacer un request previo de "lookup por hash" a bAuth, recibir el `user_id`, luego el bitmask normal
3. bAuth acepta el `biometric_hash` directamente como identificador de usuario en el campo `user_id`

¿Cuál es el contrato?

- [x] bhnexus propuso
- [ ] bAuth respondió

#### Respuesta (escribe bAuth)

**Opción 1 es la correcta.** bAuth acepta `bitmask_request` con `user_id: null` cuando viene acompañado
de `query_type: "biometric"` y `biometric_hash: "<sha256:hex>"`. Internamente bAuth resuelve el hash
contra `bauth.auth_biometric_template` y obtiene el `user_id` antes de evaluar la política.

La razón de esta elección sobre las alternativas:
- Opción 2 agrega una round-trip innecesaria (lookup + bitmask = 2 requests vs 1)
- Opción 3 mezcola un hash con un UUID en el mismo campo (type-unsafety, problemas de log)

**Schema definitivo para biométrico:**
```json
{
  "type":            "bitmask_request",
  "request_id":      "uuid-v4",
  "user_id":         null,
  "query_type":      "biometric",
  "biometric_hash":  "sha256:<hex64>",
  "node_id":         "string",
  "domain":          "D14",
  "operation":       "string",
  "credential_type": "biometric",
  "ctx_id":          "string",
  "timestamp":       "RFC3339"
}
```

Si el hash no encuentra ningún usuario: bAuth retorna `bitmask_error` con `code: user_not_found`.
Si el hash es ambiguo (colisión teórica): `code: biometric_hash_collision` — alerta SIEM.

✓ bAuth acepta este contrato. Documento: `2.02_MANUAL-PUERTA-2-BAUTH.md` §1 + `A.03_PROTOCOLO-WIRE-PUERTA-2.md` §1.3

- [x] bAuth respondió

**Estado:** ✅ ACORDADO

---

### C-BHNEXUS-002

**Tipo:** CONTRATO_API  
**Solicitante:** bhnexus  
**Receptor:** bAuth  
**Prioridad:** 🔴 BLOQUEANTE  
**Fecha apertura:** 2026-08-04

#### Necesito (escribe bhnexus)

Necesito el schema exacto y los requisitos del canal privilegiado `/run/bos/bauth-nexus.sock`:

1. ¿Quién crea el socket — bAuth o bhnexus?
2. ¿Quién conecta como cliente — bAuth o bhnexus?
3. ¿El framing es newline-delimited JSON en ambas direcciones?
4. ¿Hay un mensaje de handshake inicial?
5. ¿Qué pasa si el socket se rompe — quién reconecta?

- [x] bhnexus propuso
- [ ] bAuth respondió

#### Respuesta (escribe bAuth)

**Respuestas:**

1. **bhnexus crea el socket** (como servidor). bhnexus arranca antes o junto con bAuth (orden systemd).
   El socket vive en `/run/bos/bauth-nexus.sock`, permisos 0600 (solo bOS y bhnexus).

2. **bAuth conecta como cliente.** bAuth se conecta al socket que bhnexus expone.
   Esto mantiene bhnexus como el servidor central — bAuth es el que inicia el canal.

3. **Sí — newline-delimited JSON (`\n`) en ambas direcciones.** Sin longitud prefija.
   Máximo 8KB por mensaje. bhnexus cierra la conexión si recibe un mensaje > 8KB.

4. **No hay handshake explícito.** La autenticación ya está garantizada por los permisos del socket
   (0600 — solo procesos del grupo `bos` que ya son bOS y bhnexus). No se repite dentro del canal.

5. **bAuth reconecta.** Si la conexión se rompe, bAuth intenta reconectar al socket con backoff:
   1s → 5s → 30s → 30s (fijo). bhnexus encola los eventos que generaría durante la desconexión
   (hasta 1000 eventos; si supera: descarta los más antiguos con WARN en log).

✓ bAuth acepta este contrato. El contrato está implementado en:
  - `2.02_MANUAL-PUERTA-2-BAUTH.md` §2
  - `A.03_PROTOCOLO-WIRE-PUERTA-2.md` §2 y §3

- [x] bAuth respondió

**Estado:** ✅ ACORDADO

---

### C-BHNEXUS-003

**Tipo:** PREGUNTA_ARCH  
**Solicitante:** bhnexus  
**Receptor:** bAuth  
**Prioridad:** 🟡 MEDIA  
**Fecha apertura:** 2026-08-04

#### Necesito (escribe bhnexus)

Los `actuator_commands` que bAuth retorna en el `bitmask_response` son ejecutados por banexus sobre
hardware físico. Un atacante que pueda repetir un `auth_response` válido podría forzar la apertura
de una puerta o actuador sin credencial presente.

Necesito un mecanismo anti-replay para los `actuator_commands`. Opciones que veo:

1. bAuth incluye un `nonce` aleatorio en cada `bitmask_response`; banexus verifica que el nonce
   no haya sido usado antes (en una ventana de tiempo = TTL del SAM)
2. Los `actuator_commands` tienen su propio `expires_at` timestamp y banexus los rechaza si
   `now() > expires_at`
3. El `request_id` del `bitmask_request` actúa como nonce de correlación — banexus solo acepta
   una respuesta por `request_id`

¿Cuál es el mecanismo que bAuth debe implementar?

- [x] bhnexus propuso
- [ ] bAuth respondió

**Estado:** 📝 PROPUESTO

---

## CONTRATOS bAuth → bhnexus

---

### C-BAUTH-001 {#c-bauth-hnx-001}

**Tipo:** PREGUNTA_ARCH  
**Solicitante:** bAuth  
**Receptor:** bhnexus  
**Prioridad:** 🔴 BLOQUEANTE  
**Fecha apertura:** 2026-08-04

#### Necesito (escribe bAuth)

Cuando bAuth emite `emergency_revoke` con `scope: "all_nodes"`, necesito saber exactamente qué hace
bhnexus:

1. ¿bhnexus cierra activamente las conexiones WebSocket de los nodos banexus que tienen sesiones
   del usuario revocado? ¿O solo invalida el cache y espera que el próximo auth_request sea denegado?
2. Si hay una credencial siendo procesada en ese exacto momento (mid-flight) en bhnexus para ese usuario,
   ¿la cancela, la deja completar, o devuelve DENY?
3. ¿bhnexus propaga el `emergency_revoke` a los nodos banexus offline (en cola) o solo a los conectados?

- [x] bAuth propuso
- [ ] bhnexus respondió

#### Respuesta (escribe bhnexus)

**Respuestas:**

1. **bhnexus NO cierra las conexiones WebSocket de banexus.** Cierra la conexión WebSocket de un nodo
   solo si recibe `blacklist_node` (que es una operación diferente y más severa que `emergency_revoke`).
   Para `emergency_revoke`, bhnexus:
   - Elimina TODAS las entradas del Auth Cache para ese `user_id`
   - Envía `policy_update` con `action: invalidate_cache` a todos los nodos conectados que tienen
     sesiones activas del usuario
   - El próximo `auth_request` para ese usuario, en cualquier nodo, recibirá DENY (no hay cache → bAuth
     retorna `bitmask_error` o DENY según el motivo de la revocación)

2. **Si hay un auth_request mid-flight para ese usuario en bhnexus al momento del `emergency_revoke`:**
   - Si bhnexus ya envió el `bitmask_request` a bAuth y está esperando respuesta → deja completar
     (bAuth ya calculará DENY porque procesará la revocación primero)
   - Si bhnexus está evaluando el SAM-128 del cache → aplica DENY inmediato (cache ya fue invalidado)
   - Si bhnexus ya envió el `auth_response` GRANT al banexus pero el hardware no actuó → no puede
     cancelarlo (el comando ya está en tránsito). Esta es una ventana de < 5ms que se acepta como
     trade-off — la alternativa sería serialización global que destruiría la latencia.

3. **Sí — bhnexus propaga a nodos offline** (en cola). El mensaje `invalidate_cache` se encola para
   cada nodo desconectado. Al reconectar, bhnexus entrega los mensajes encolados en orden.
   Adicionalmente, cuando un nodo offline reconecta (S-01), bhnexus verifica si hay revocaciones
   pendientes para ese nodo antes de enviar el paquete de políticas.

✓ bhnexus acepta este contrato. Documentado en `5.03_MANUAL-OFFLINE-FAILSECURE.md` §5 y
  `2.04_MANUAL-SAGAS-NEXUS.md` §5.

- [x] bhnexus respondió

**Estado:** ✅ ACORDADO

---

### C-BAUTH-002 {#c-bauth-hnx-002}

**Tipo:** CONTRATO_API  
**Solicitante:** bAuth  
**Receptor:** bhnexus  
**Prioridad:** 🟠 ALTA  
**Fecha apertura:** 2026-08-04

#### Necesito (escribe bAuth)

Cuando bhnexus envía el evento `node_online` por el canal privilegiado (al reconectar tras un período
offline), necesito saber exactamente qué estadísticas debe incluir para que bAuth pueda:
1. Reconstruir el audit trail del período offline
2. Detectar si hubo accesos sospechosos durante el offline
3. Decidir si forzar una re-autenticación completa del nodo

¿Cuál es el schema exacto que bhnexus se compromete a enviar?

- [x] bAuth propuso
- [ ] bhnexus respondió

#### Respuesta (escribe bhnexus)

**Schema de `node_online` comprometido:**

```json
{
  "event":                  "node_online",
  "node_id":                "string",
  "offline_start":          "RFC3339",              // cuándo se perdió la conexión
  "offline_end":            "RFC3339",              // cuándo reconectó
  "offline_duration_s":     3600,
  "cache_age_at_disconnect_s": 1200,               // antigüedad del cache cuando se fue offline
  "cache_age_at_reconnect_s":  4800,               // antigüedad del cache al reconectar

  "offline_events_total":   47,                     // total de auth_request procesados offline
  "offline_cache_hits":     45,                     // resueltos desde cache
  "offline_cache_misses":   2,                      // denegados por cache miss o expirado
  "offline_denies_expired": 2,                      // DENY por policy_cache_expired

  "offline_audit_events": [                         // lista de eventos offline para audit trail
    {
      "user_id":    "uuid-v4",
      "credential": "nfc",
      "result":     "granted|denied",
      "deny_reason": "string | null",
      "ts":         "RFC3339",
      "cache_age_s": 1250
    }
  ],

  "cache_state_at_reconnect": "valid | expired | corrupted",
  "policy_hash_at_disconnect": "0x<hex4>",
  "policy_hash_at_reconnect":  "0x<hex4>",          // si cambió → bAuth fuerza policy reload

  "ts": "RFC3339"
}
```

bhnexus se compromete a:
- Enviar este evento dentro de los 2 segundos de completar el handshake S-01
- Incluir TODOS los `offline_audit_events` (no truncar la lista sin señalarlo)
- Si la lista supera 1000 eventos: truncar con `"truncated": true, "truncated_count": N`

bAuth puede, al recibir `node_online`:
- Si `policy_hash_at_disconnect != policy_hash_at_reconnect` → forzar una resincronización completa
- Si hay eventos sospechosos → emitir alerta SIEM y crear tarea de revisión en el audit log

✓ bhnexus acepta este contrato. Documentado en `A.03_PROTOCOLO-WIRE-PUERTA-2.md` §2.4 (evento `node_online`).

- [x] bhnexus respondió

**Estado:** ✅ ACORDADO

---

*SKULL · SBOS · bNexus · BHNEXUS-BAUTH-CONTRATOS · v1.0.0 · Agosto 2026*
