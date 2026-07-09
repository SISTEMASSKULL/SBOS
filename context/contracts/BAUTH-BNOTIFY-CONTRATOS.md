# REGISTRO DE CONTRATOS — bAuth ↔ bNotify

**Versión:** 1.0.0 · **Apertura:** 2026-07-06 · **Propietarios:** agente-bauth + agente-bnotify
**Propósito:** Registro formal de las obligaciones recíprocas entre bAuth (Identity Control Plane)
y bNotify (Orquestador de Notificaciones) — credenciales OIDC, eventos CAEP, verificación JWT,
perfil CONSUMER_MOBILE. Nada se implementa sin pasar por aquí.

---

## ⚠️ NORMA IRRENUNCIABLE — DOCUMENTO HISTÓRICO

**Este documento es APPEND-ONLY. Solo se agrega. Nunca se borra. Nunca se edita lo ya escrito.**

| Permitido | Prohibido |
|-----------|-----------|
| ✅ Agregar nuevos contratos (C-BAUTH-NNN, C-BNOTIFY-NNN) | ❌ Borrar un contrato |
| ✅ Escribir en el campo `Respuesta` si está vacío | ❌ Editar el campo `Necesito` del otro agente |
| ✅ Marcar checkboxes de estado como completados | ❌ Desmarcar o reescribir checkboxes ya marcados |
| ✅ Agregar filas al `HISTORIAL DE ESTADOS` | ❌ Modificar o eliminar filas del historial |
| ✅ Actualizar el estado en la `TABLA MAESTRA` | ❌ Cambiar retroactivamente un estado ya registrado |

**Por qué:** Este registro es evidencia técnica del proceso de integración entre los dos daemons
más críticos de la capa de identidad y comunicación. Cada acuerdo y rechazo queda trazado
con fecha. Si algo fue rechazado y luego se reconsideró, se abre un contrato nuevo — el rechazo
original permanece visible.

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

1. **Todo contrato tiene un ID único** en formato `C-{DAEMON_SOLICITANTE}-{NNN}` (ej: `C-BAUTH-001`)
2. **El solicitante abre el contrato** con el campo `Necesito` completo antes de pedir respuesta
3. **El receptor responde** en el campo `Respuesta` — nunca edita el campo `Necesito` del otro
4. **El estado solo avanza** cuando hay texto en el campo correspondiente
5. **ENTREGADO requiere commit** — sin número de commit no se puede marcar como entregado
6. **Ambos firman ACORDADO** — el solicitante escribe `✓ bAuth acepta` o `✓ bNotify acepta` en la respuesta

---

## TABLA MAESTRA

| ID | Tipo | Solicitante | Receptor | Resumen | Estado | Commit |
|----|------|:-----------:|:--------:|---------|:------:|:------:|
| [C-BAUTH-001](#c-bauth-001) | CONTRATO_API | bAuth | bNotify | Superficie OIDC — 5 endpoints (BNOTIFY-002 §2) | 📝 | — |
| [C-BAUTH-002](#c-bauth-002) | CONTRATO_API | bAuth | bNotify | Claims JWT obligatorios — sub/iss/aud/sbos_roles/ctx_id/kyc_tier | 📝 | — |
| [C-BAUTH-003](#c-bauth-003) | CONTRATO_API | bAuth | bNotify | Perfil CONSUMER_MOBILE — TTLs y política de sesión | 📝 | — |
| [C-BAUTH-004](#c-bauth-004) | CONTRATO_API | bAuth | bNotify | 5 eventos CAEP vía gRPC ReceiveCaepEvent | 📝 | — |
| [C-BNOTIFY-001](#c-bnotify-001) | CONTRATO_API | bNotify | bAuth | Endpoint gRPC ReceiveCaepEvent en socket bNotify | 📝 | — |
| [C-BNOTIFY-002](#c-bnotify-002) | CONTRATO_API | bNotify | bAuth | Suspensión de entregas en <30s ante session-revoked | 📝 | — |
| [C-BNOTIFY-003](#c-bnotify-003) | CONTRATO_API | bNotify | bAuth | Verificación JWT via /auth/oidc/jwks (sin hardcode) | 📝 | — |
| [C-BNOTIFY-004](#c-bnotify-004) | CONTRATO_API | bNotify | bAuth | Lectura de perfil usuario via /auth/oidc/userinfo | 📝 | — |

---

## Sección bAuth → bNotify

*bAuth solicita — bNotify responde y cumple*

---

### C-BAUTH-001

**ID:** C-BAUTH-001
**Tipo:** CONTRATO_API
**Prioridad:** 🔴 BLOQUEANTE (bloquea gate G0 de bNotify)
**Fecha apertura:** 2026-07-06
**Referencia:** BNOTIFY-002 §2 · BNOTIFY-000 §8 R2

#### Necesito (escribe bAuth)

bNotify necesita que bAuth exponga la superficie OIDC completa para que bRocket y bChat
puedan autenticar usuarios. Sin estos endpoints, ningún cliente puede iniciar sesión.

Los 5 endpoints requeridos son:

| Endpoint | Método | Ruta |
|----------|:------:|------|
| Discovery | GET | `/.well-known/openid-configuration` |
| Authorization | GET | `/auth/oidc/authorize` |
| Token | POST | `/auth/oidc/token` |
| UserInfo | GET | `/auth/oidc/userinfo` |
| JWKS | GET | `/auth/oidc/jwks` |

**Requisitos adicionales:**
- Discovery debe retornar JSON válido con todos los campos de BNOTIFY-002 §2.1
- Authorization debe soportar PKCE con `code_challenge_method=S256` (RFC 7636)
- Token debe soportar `grant_type=authorization_code` y `refresh_token`
- JWKS debe publicar la clave pública Ed25519 activa de Vault PKI
- Al rotar claves: publicar nueva + mantener anterior activa durante TTL de tokens en circulación (mín. 1 hora)
- Issuer canónico: `https://bauth.sbos.internal`

**Criterio de verificación:**
```bash
curl -s https://bauth.sbos.internal/.well-known/openid-configuration | python3 -m json.tool
# Debe retornar JSON con todos los campos listados en BNOTIFY-002 §2.1
```

#### Estado

- [x] bAuth propuso (2026-07-06)
- [ ] bNotify respondió
- [ ] ACORDADO

#### Respuesta (escribe bNotify)

*Pendiente*

---

### C-BAUTH-002

**ID:** C-BAUTH-002
**Tipo:** CONTRATO_API
**Prioridad:** 🔴 BLOQUEANTE
**Fecha apertura:** 2026-07-06
**Referencia:** BNOTIFY-002 §3

#### Necesito (escribe bAuth)

bNotify necesita que los tokens JWT emitidos por bAuth contengan claims específicos
para poder enrutar notificaciones, verificar roles, y trazar sesiones.

**Claims obligatorios en TODOS los tokens para bRocket/bChat:**

| Claim | Tipo | Descripción |
|-------|------|-------------|
| `sub` | string (UUID) | Identificador único del usuario en bAuth |
| `iss` | string | Siempre `https://bauth.sbos.internal` |
| `aud` | string | Audiencia del cliente (`rocketchat-{tenant_id}` o `bchat-{tenant_id}`) |
| `exp` | number | Expiración Unix timestamp |
| `iat` | number | Emisión Unix timestamp |
| `email` | string | Email corporativo del usuario |
| `name` | string | Nombre completo |
| `sbos_roles` | array[string] | Roles SBOS activos (`["CONSUMER_T0", "FINANCIERO_N1"]`) |
| `sbos_tenant` | string | ID del tenant |
| `ctx_id` | string (UUID) | Context ID de la sesión (SBOS-049) — obligatorio para auditoría |
| `kyc_tier` | string | `"T0"`, `"T1"` o `"T2"` — determina capacidades en bChat |

**Claims opcionales (cuando scope `sbos_roles` está presente):**
`locale`, `zoneinfo`, `phone_number`, `phone_number_verified`

**Algoritmo de firma:** EdDSA (Ed25519). `alg` en JWT header: `"EdDSA"`.

#### Estado

- [x] bAuth propuso (2026-07-06)
- [ ] bNotify respondió
- [ ] ACORDADO

#### Respuesta (escribe bNotify)

*Pendiente*

---

### C-BAUTH-003

**ID:** C-BAUTH-003
**Tipo:** CONTRATO_API
**Prioridad:** 🟠 ALTA
**Fecha apertura:** 2026-07-06
**Referencia:** BNOTIFY-002 §5 · BNOTIFY-062 §2

#### Necesito (escribe bAuth)

Para usuarios de bChat móvil (perfil CONSUMER_MOBILE — KYC tier T0+), bNotify necesita
que bAuth aplique los siguientes parámetros de sesión que garantizan experiencia fluida
sin comprometer seguridad:

| Parámetro | Valor requerido | Justificación |
|-----------|:--------------:|---------------|
| `access_token` TTL | 1 hora | Estándar OIDC para apps móviles |
| `refresh_token` TTL | 30 días | Doctrine D8: `bauth.session.ttl_consumer` |
| `refresh_token` rotante | Sí (RFC 6819 §5.2.1) | Cada uso invalida el anterior — CAEP-compatible |
| Máx. sesiones concurrentes | 5 dispositivos | Política anti-compartición de cuenta |
| Renovación silenciosa | Sí | El cliente renueva en background sin interrumpir |

**Invariante crítica:** el `ctx_id` persiste durante toda la duración del `refresh_token`.
Al revocar, bAuth publica `session-revoked` (CAEP) y bNotify suspende entregas en <30s.

**Identificación del perfil:** el `client_id` del cliente bChat tiene formato `bchat-{tenant_id}`.
bAuth aplica el perfil CONSUMER_MOBILE a todos los tokens emitidos para ese `client_id`.

#### Estado

- [x] bAuth propuso (2026-07-06)
- [ ] bNotify respondió
- [ ] ACORDADO

#### Respuesta (escribe bNotify)

*Pendiente*

---

### C-BAUTH-004

**ID:** C-BAUTH-004
**Tipo:** CONTRATO_API
**Prioridad:** 🔴 BLOQUEANTE (bloquea entrega de notificaciones post-revocación)
**Fecha apertura:** 2026-07-06
**Referencia:** BNOTIFY-002 §6 · BNOTIFY-001 proto

#### Necesito (escribe bAuth)

bNotify necesita que bAuth emita 5 eventos CAEP hacia el endpoint gRPC
`NotifyDispatcher.ReceiveCaepEvent` de bNotify cuando ocurran los siguientes eventos
de sesión/credencial:

| Evento `event_type` | Cuando | Acción esperada de bNotify |
|--------------------|--------|---------------------------|
| `session-revoked` | Offboarding, suspensión, violación de seguridad | Suspender todas las entregas pendientes al `ctx_id`. <30s. |
| `credential-change` | Cambio de password o nuevo MFA registrado | Notificar al usuario por canal secundario (email/SMS) |
| `assurance-level-change` | Promoción KYC T0→T1→T2 | Habilitar canales/funcionalidades nuevos para ese usuario |
| `device-compliance-change` | Jailbreak detectado, MDM fuera de compliance | Revocar token de push del dispositivo específico |
| `risk-level-change` | RiskEngine detecta anomalía | Escalar prioridad de notificaciones de seguridad |

**Proto del mensaje (extensión de BNOTIFY-001):**
```protobuf
message CaepEvent {
  string event_type    = 1;  // uno de los 5 eventos arriba
  string subject_ctx_id = 2; // ctx_id de la sesión afectada (SBOS-049)
  string subject_user_id = 3; // UUID bAuth del usuario
  string tenant_id     = 4;
  string occurred_at   = 5;  // RFC3339
  map<string, string> event_data = 6; // datos adicionales del evento
}
message CaepAck {
  bool received = 1;
}
```

**Transporte:** gRPC sobre Unix socket `/run/bos/bnotify.sock` (ADR-001 — cero REST entre daemons).
**Garantía:** bAuth DEBE esperar el `CaepAck` antes de considerar el evento entregado.
Si bNotify no responde en 5s, reintento con backoff exponencial (3 intentos máx).

#### Estado

- [x] bAuth propuso (2026-07-06)
- [ ] bNotify respondió
- [ ] ACORDADO

#### Respuesta (escribe bNotify)

*Pendiente*

---

## Sección bNotify → bAuth

*bNotify solicita — bAuth responde y cumple*

---

### C-BNOTIFY-001

**ID:** C-BNOTIFY-001
**Tipo:** CONTRATO_API
**Prioridad:** 🔴 BLOQUEANTE (bAuth lo necesita para emitir eventos CAEP)
**Fecha apertura:** 2026-07-06
**Referencia:** BNOTIFY-001 proto §4 · BNOTIFY-002 §6.1

#### Necesito (escribe bNotify)

bAuth necesita que bNotify exponga el método gRPC `ReceiveCaepEvent` en su socket Unix
para poder entregarle los eventos CAEP de sesión.

**Contrato del endpoint:**
- Socket: `/run/bos/bnotify.sock` (grupo `bos`, modo 0660)
- Servicio: `bnotify.v1.NotifyDispatcher`
- Método: `ReceiveCaepEvent(CaepEvent) returns (CaepAck)`
- SLA de respuesta: ACK en <1 segundo (procesamiento asíncrono permitido)
- Si bNotify no puede procesar: retornar `received = false` con error gRPC en metadata

**Disponibilidad:** el endpoint debe estar activo desde el arranque del daemon
(`bnotify.service` Type=notify). Si bAuth llama antes de que bNotify esté listo,
bNotify puede retornar `UNAVAILABLE` — bAuth reintenta con backoff.

#### Estado

- [x] bNotify propuso (2026-07-06)
- [ ] bAuth respondió
- [ ] ACORDADO

#### Respuesta (escribe bAuth)

*Pendiente*

---

### C-BNOTIFY-002

**ID:** C-BNOTIFY-002
**Tipo:** CONTRATO_API
**Prioridad:** 🔴 BLOQUEANTE (seguridad — evitar entregas a sesiones revocadas)
**Fecha apertura:** 2026-07-06
**Referencia:** BNOTIFY-002 §6 · BNOTIFY-000 D16

#### Necesito (escribe bNotify)

Al recibir un evento CAEP `session-revoked` con un `subject_ctx_id`, bNotify necesita
que la implementación del lado de bAuth garantice que:

1. El evento se emite en <5s desde que se ejecuta la revocación en bAuth
2. El `ctx_id` en el evento corresponde exactamente al ctx_id de la sesión revocada
3. El evento no se re-emite si ya fue entregado (idempotencia — usar `event_id` único)

Por su parte, bNotify garantiza que suspende todas las entregas pendientes a ese `ctx_id`
en <30s desde la recepción del evento.

**SLA completo extremo a extremo:**
```
bAuth revoca sesión → emite CAEP en <5s → bNotify recibe y suspende en <30s
Total: <35s desde la revocación hasta cero entregas en vuelo
```

#### Estado

- [x] bNotify propuso (2026-07-06)
- [ ] bAuth respondió
- [ ] ACORDADO

#### Respuesta (escribe bAuth)

*Pendiente*

---

### C-BNOTIFY-003

**ID:** C-BNOTIFY-003
**Tipo:** CONTRATO_API
**Prioridad:** 🟠 ALTA
**Fecha apertura:** 2026-07-06
**Referencia:** BNOTIFY-002 §2.5

#### Necesito (escribe bNotify)

bNotify verifica los JWT que recibe de clientes bChat consultando las claves públicas
de bAuth en JWKS. Para que esto funcione correctamente:

1. bAuth DEBE publicar su clave pública Ed25519 activa en `/auth/oidc/jwks`
2. Al rotar la clave de firma: publicar la nueva Y mantener la anterior durante
   el TTL máximo de access_tokens en circulación (mínimo 1 hora)
3. Cada JWK DEBE tener `kid` estable durante la vigencia de esa clave
4. bNotify cachea el JWKS con TTL de 15 minutos. Si bAuth rota sin aviso,
   bNotify re-fetcha el JWKS al recibir un `kid` desconocido (protocolo estándar)

**Lo que bNotify NO hace:**
- Hardcodear ninguna clave pública de bAuth en su configuración
- Aceptar tokens sin verificar firma
- Aceptar tokens con `alg: none`

#### Estado

- [x] bNotify propuso (2026-07-06)
- [ ] bAuth respondió
- [ ] ACORDADO

#### Respuesta (escribe bAuth)

*Pendiente*

---

### C-BNOTIFY-004

**ID:** C-BNOTIFY-004
**Tipo:** CONTRATO_API
**Prioridad:** 🟡 MEDIA
**Fecha apertura:** 2026-07-06
**Referencia:** BNOTIFY-002 §2.4 · §3.1

#### Necesito (escribe bNotify)

Para ciertos flujos internos (ej: personalizar notificaciones con nombre del usuario,
verificar kyc_tier en tiempo real sin esperar renovación de JWT), bNotify necesita
poder consultar el perfil del usuario vía `/auth/oidc/userinfo`:

```http
GET /auth/oidc/userinfo
Authorization: Bearer {access_token_del_usuario}
```

**Respuesta esperada** (mismos claims que el JWT):
```json
{
  "sub": "uuid-del-usuario",
  "email": "usuario@empresa.com",
  "name": "Nombre Completo",
  "sbos_roles": ["CONSUMER_T0"],
  "sbos_tenant": "empresa-abc",
  "ctx_id": "ctx-xyz",
  "kyc_tier": "T0"
}
```

**Condición:** bNotify solo llama a `/userinfo` con un `access_token` válido obtenido
por el propio usuario (nunca inventa tokens). No se trata de consulta administrativa.

#### Estado

- [x] bNotify propuso (2026-07-06)
- [ ] bAuth respondió
- [ ] ACORDADO

#### Respuesta (escribe bAuth)

*Pendiente*

---

## HISTORIAL DE ESTADOS

| Fecha | ID | Estado anterior | Estado nuevo | Actor | Nota |
|-------|-----|:--------------:|:------------:|-------|------|
| 2026-07-06 | C-BAUTH-001 | — | 📝 PROPUESTO | agente-bauth | Apertura del contrato bilateral |
| 2026-07-06 | C-BAUTH-002 | — | 📝 PROPUESTO | agente-bauth | Apertura del contrato bilateral |
| 2026-07-06 | C-BAUTH-003 | — | 📝 PROPUESTO | agente-bauth | Apertura del contrato bilateral |
| 2026-07-06 | C-BAUTH-004 | — | 📝 PROPUESTO | agente-bauth | Apertura del contrato bilateral |
| 2026-07-06 | C-BNOTIFY-001 | — | 📝 PROPUESTO | agente-bnotify | Apertura del contrato bilateral |
| 2026-07-06 | C-BNOTIFY-002 | — | 📝 PROPUESTO | agente-bnotify | Apertura del contrato bilateral |
| 2026-07-06 | C-BNOTIFY-003 | — | 📝 PROPUESTO | agente-bnotify | Apertura del contrato bilateral |
| 2026-07-06 | C-BNOTIFY-004 | — | 📝 PROPUESTO | agente-bnotify | Apertura del contrato bilateral |

---

## Documentos de referencia

| Documento | Ruta | Relevancia |
|-----------|------|-----------|
| BNOTIFY-001 | `BnotifyAgent/context/BNOTIFY-001-CONTRATO-GRPC-ORQUESTADOR-ADAPTADORES.md` | Proto completo del NotifyDispatcher + ReceiveCaepEvent |
| BNOTIFY-002 | `BnotifyAgent/context/BNOTIFY-002-BAUTH-OIDC-SUPERFICIE-D9.md` | Especificación completa de la superficie OIDC requerida |
| BNOTIFY-062 | `BnotifyAgent/context/BNOTIFY-062-KYC-TIERS-Y-VALOR.md` | Capacidades por KYC tier — afecta claims `kyc_tier` |

---

*BAUTH-BNOTIFY-CONTRATOS.md v1.0.0 · SBOS/context/contracts/ · 2026-07-06*
*Custodiado por: Bibliotecario SBOS*
