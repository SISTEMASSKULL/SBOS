# SBOS-0XX — G-04: LoA/AAL, Obligaciones de Recurso y Separación Bitmask/Sesión

**Estado:** Decidido
**Dominio:** bAuth · IAM · Step-up Authentication
**Tablas afectadas:** `bauth.privilege_resource_atom` (T-171)
**Relacionado con:** SBOS-0XX-BAUTH-ATOM-GRANT-CONSISTENCY.md, BAUTH-AUTHENTICATION-FRAMEWORK.md

---

## 1. Conceptos base: LoA y AAL

**LoA (Level of Assurance)** es el concepto genérico: qué tan seguro está el sistema de que la persona autenticada es quien dice ser. Es la idea paraguas — distintos marcos regulatorios lo formalizan de forma distinta (eIDAS usa low/substantial/high; NIST usa AAL).

**AAL (Authenticator Assurance Level)** es la formalización específica de **NIST SP 800-63B**, el marco ya citado en `BAUTH-AUTHENTICATION-FRAMEWORK.md`. Define tres niveles:

| Nivel | Requisito | Ejemplo |
|---|---|---|
| **AAL1** | Un solo factor | Usuario + contraseña |
| **AAL2** | Dos factores | Contraseña + OTP / push / TOTP |
| **AAL3** | Dos factores, uno resistente a phishing y hardware-backed | Llave física FIDO2/WebAuthn |

AAL3 es el nivel que ya figura como aspiración de largo plazo en el roadmap de bAuth ("NIST IAL3/AAL3").

**Step-up authentication** es el mecanismo operativo: el usuario inicia sesión en un nivel bajo (AAL1) y, al intentar una operación que exige más garantía, el sistema le solicita subir de nivel (ej. completar 2FA) **sin cerrar la sesión existente**. El caso de G-04 es exactamente esto: login en AAL1, intento de "aprobar venta" en Tryton exige AAL2, el usuario hace step-up, la sesión pasa a AAL2 sin necesidad de re-loguearse desde cero.

`obligation: {"required_loa": "AAL2"}` en un átomo significa: *este permiso específico exige que la sesión activa esté en AAL2, sin importar en qué nivel se hizo el login original.*

---

## 2. Aclaración importante: el bitmask en el JWT es una decisión previa, no de este documento

Existe un malentendido a corregir explícitamente, porque afecta cómo se debe implementar la Opción A de G-04.

**El RolBitMask viviendo como claim dentro del JWT es un diseño ya establecido de bAuth**, anterior a esta discusión — no es algo que se decida ni se cuestione acá.

Lo que sí es objeto de esta decisión es una cosa distinta: **dónde debe vivir el `current_loa`** (el nivel de garantía *actual* de la sesión, que puede cambiar dentro de la vida de un mismo token vía step-up).

| Dato | Dónde vive | Por qué |
|---|---|---|
| **RolBitMask** — qué permisos tiene el usuario | JWT, como claim | Cambia poco; se re-emite solo cuando cambia el rol/grant |
| **`current_loa`** — qué tan autenticado está *ahora* | Sesión activa (Redis / Context Plane) | Cambia dentro de la vida del mismo JWT, en cada step-up |

### El riesgo concreto que esta separación evita

Si `current_loa` se empaquetara como claim **dentro del mismo JWT** que ya trae el bitmask, cada step-up volvería a exigir re-emitir el token completo — reintroduciendo exactamente el problema que la Opción A de G-04 buscaba evitar (ver Sección 3). Por eso `current_loa` debe resolverse consultando la sesión en tiempo real (Kong contra Redis / `bos.GetContext()`), nunca leyendo un claim congelado del mismo JWT que contiene el bitmask.

**Conclusión de esta sección:** el bitmask sigue viviendo en el JWT, sin cambios respecto al diseño ya establecido. Lo único que se fija acá es que el LoA actual **no debe acompañarlo** en el mismo token.

---

## 3. Decisión G-04: Opción A (bit se emite, Kong custodia la obligación)

### 3.1 Las dos opciones evaluadas

**Opción A** — el bit del átomo se emite en el JWT independientemente del LoA actual del usuario. La obligación (`required_loa`) vive en T-171, asociada al recurso. Kong, como PEP, la evalúa en tiempo de request contra el LoA actual de la sesión.

**Opción B** — el bit no se emite hasta que el LoA se cumpla. bAuth debe consultar, al momento de emitir el JWT, si cada grant tiene una obligación de LoA pendiente, y excluir el bit si no se cumple. Al hacer step-up, bAuth re-emite un JWT nuevo con el bit ya activado.

### 3.2 Por qué Opción A es la correcta

El argumento decisivo **no es de separación de roles PAP/PDP/PEP** — en XACML/NIST ABAC, el PDP evaluando atributos de la política del recurso es justamente su función estándar; que bAuth conociera `required_loa` no violaría esa separación por sí solo.

El argumento real es de **staleness del token**: en la Opción B, cada cambio de LoA obliga a re-emitir el JWT completo. Esto ata a bAuth al camino síncrono de cada step-up, y puede producir dos JWTs válidos simultáneos representando distintos "snapshots" de entitlement durante la ventana de transición — una fuente de inconsistencia que la Opción A no tiene.

En la Opción A, el bit representa un hecho estático (¿existe el grant?) y la obligación representa una condición dinámica de contexto (¿se cumple el LoA ahora?). Mezclar ambos en la decisión de emisión del JWT fuerza a re-mintar el token en cada cambio de contexto — justamente lo que el Context Plane (`bos.GetContext()`) ya está diseñado para resolver de otra forma: el trust level se evalúa en tiempo de request, no se congela dentro del token.

Este patrón coincide con el estándar de la industria para step-up auth: **RFC 9470 (OAuth 2.0 Step Up Authentication Challenge Protocol)** — el recurso declara el `acr` (nivel de garantía) requerido, el resource server/gateway compara contra el `acr` actual de la sesión, y devuelve un challenge de step-up si no alcanza. El token no se re-emite; se re-evalúa la sesión.

### 3.3 DDL de T-171

La columna `obligation` debe ser parte del `CREATE TABLE` canónico de `privilege_resource_atom` (DDL completo en `A.65.02.01_ANEXO-OPERACION-TABLAS-DECISIONES-v1.0.md` §8). **No se usa ALTER TABLE** — la tabla se crea con esta columna desde el primer momento.

Columna a agregar en el `CREATE TABLE bauth.privilege_resource_atom`:

```sql
    -- Obligación de contexto para este recurso.
    -- Contrato del recurso, no del token.
    -- Ej: {"required_loa": "AAL2"} significa que Kong debe verificar que
    -- la sesión activa tiene LoA AAL2 antes de conceder acceso, incluso si
    -- el bit del RolBitMask está activo (bit=1 solo indica que el grant existe).
    -- NULL = sin obligación de contexto; el bit es suficiente.
    -- NUNCA se evalúa por bAuth al emitir el JWT — es responsabilidad exclusiva
    -- de Kong (PEP) contra el Context Plane / Redis en cada request.
    obligation   JSONB    NULL,
```

Restricción recomendada para validar la estructura del JSON:

```sql
    CONSTRAINT chk_pra_obligation_schema CHECK (
        obligation IS NULL
        OR (
            jsonb_typeof(obligation) = 'object'
            AND obligation ? 'required_loa'
            AND (obligation->>'required_loa') IN ('AAL1','AAL2','AAL3')
        )
    ),
```

### 3.4 Flujo operativo

```
1. Grant normal en T-170: access=true, status=ACTIVE
2. JWT emitido en AAL1: bit N = 1 (el grant existe, sin importar el LoA actual)
3. Kong (PEP) recibe el request:
   a. Lee bit N = 1 del RolBitMask (JWT)          ✓ grant existe
   b. Consulta T-171 → obligation.required_loa = AAL2
   c. Lee current_loa de la sesión activa (Redis / Context Plane) → AAL1
   d. AAL1 < AAL2 → redirect a step-up endpoint
4. Usuario completa 2FA → sesión pasa a AAL2 (current_loa actualizado en Redis)
5. Mismo JWT (el bit ya estaba, no cambió) → Kong re-verifica → current_loa AAL2 ≥ AAL2 → PERMIT
```

---

## 4. Riesgos operacionales que Opción A introduce, y su mitigación

Estos no invalidan la decisión, pero si no se resuelven, la Opción A se rompe en producción. Cada riesgo requiere un mecanismo de naturaleza distinta — no se cierran con una sola medida.

### 4.1 `current_loa` no puede vivir en el JWT

Ver Sección 2. Debe resolverse siempre contra la sesión activa (Context Plane / Redis), nunca como claim horneado en el mismo token que trae el bitmask.

**Mitigación arquitectónica (elimina el riesgo, no solo lo reduce):**

- El schema del JWT que emite bAuth **no debe tener ningún claim de LoA**, ni siquiera como campo opcional. Si el campo no existe en el schema, nadie puede empezar a llenarlo "por comodidad" más adelante.
- `current_loa` vive exclusivamente en el session store (Redis), **keyed por `session_id`, no por `user_id`** — un mismo usuario puede tener sesiones concurrentes en distintos niveles de LoA (ej. sesión mobile en AAL1 y sesión desktop recién hecha step-up a AAL2). Indexar por usuario colisionaría ambos estados.
- Kong lo resuelve en cada request contra ese session store, nunca contra el token.

**Mitigación de verificación (detecta si alguien lo rompe igual):**

- Test de contrato en CI sobre el emisor de JWT: falla el build si el payload del token contiene cualquier clave `loa`, `acr`, `assurance_level` o similar. Convierte el "no debería" en un gate automático que bloquea el merge, no en una convención de código.

### 4.2 El bit=1 no significa "permitido" — riesgo de bypass si algún componente lo trata como decisión final

En Opción A, `bit=1` significa **"el grant existe, sujeto a obligación"**, no "acceso permitido". Cualquier microservicio de SBOS que lea el JWT directamente y confíe en el bit sin pasar por Kong (PEP) para resolver la obligación, estaría otorgando acceso sin verificar el LoA requerido.

**Regla dura a establecer:** ningún componente de SBOS puede tratar el bitmask como decisión final de autorización cuando el átomo tiene `obligation IS NOT NULL`. Solo Kong, como único PEP del sistema, tiene autoridad para resolver la obligación antes de conceder acceso.

Este es el riesgo más difícil de cerrar porque es un problema de cumplimiento arquitectónico *distribuido* — cualquier servicio nuevo dentro de SBOS podría, sin mala intención, leer el JWT directo y confiar en el bit. Se cierra con capas, no con una sola medida:

**Capa 1 — Red: hacer el bypass topológicamente imposible, no solo indeseable.**
Con Linkerd (ya en el stack de SBOS) como service mesh, definir authorization policies que restrinjan qué servicios pueden llamar directamente a un recurso protegido (ej. Tryton). Si un recurso tiene átomos con `obligation`, su `NetworkPolicy`/`ServerAuthorization` en k3s solo permite tráfico entrante desde Kong — ningún otro pod puede alcanzarlo en la red, ni por error de código. Esta es la mitigación más fuerte: no depende de que el desarrollador "recuerde" pasar por el PEP, lo hace imposible de evitar a nivel de red.

**Capa 2 — SDK: el Context Plane nunca debe exponer un veredicto de "permitido".**
Cuando se publique el SDK de `bos.GetContext()` (Fase 2 del roadmap), la función que expone el bitmask al developer debe devolver **"el grant existe"**, nunca **"tenés permiso"**. Si el SDK no ofrece una función tipo `hasPermission()` que resuelva true/false a partir del bit solo — y en su lugar documenta explícitamente que, para recursos con obligación, la decisión final es de Kong — se reduce la tentación de que un developer construya su propio mini-PEP ad-hoc con el bit crudo.

**Capa 3 — Detección: lint/CI que busque el antipatrón.**
Chequeo estático (grep/AST) en los pipelines de la Fábrica SBOS que detecte código de aplicación leyendo claims del JWT relacionados al bitmask fuera de los módulos autorizados (Kong plugin, bAuth). No previene todo, pero atrapa el caso más común: un developer nuevo copiando un ejemplo viejo.

**Capa 4 — Auditoría cruzada (detecta si algo se coló pese a las capas anteriores).**
Cada acceso efectivo a un recurso con `obligation` debe dejar registro correlacionable en dos lados: el log de Kong (que evaluó la obligación) y el log de acceso del recurso mismo (Tryton, etc.). Un job periódico que compare "accesos registrados en el recurso" vs. "evaluaciones registradas en Kong" para ese mismo recurso, y alerte ante accesos sin evaluación correspondiente, da evidencia de que ocurrió un bypass incluso si las capas 1–3 fallaron.

### 4.3 Auditoría del cumplimiento de la obligación, no solo de la existencia del grant

El WORM en `privilege_atom_audit` (T-170b · ver SBOS-0XX-BAUTH-ATOM-GRANT-CONSISTENCY.md) audita cambios al grant — pero no audita eventos del tipo *"el usuario ejerció este permiso con AAL1 y tuvo que hacer step-up a AAL2"*, que es el tipo de evidencia que un auditor bajo NIST IAL3/AAL3 va a exigir ver.

Son dos evidencias de naturaleza distinta:
- **Qué se otorgó** → cubierto por `bos_atom_audit`.
- **Cómo se usó lo otorgado** (incluyendo eventos de step-up) → requiere su propio registro, con volumen y ciclo de vida distintos: crece con cada intento de acceso, no con cada cambio de grant.

**Mitigación: tabla de auditoría de evaluación de obligación**, poblada directamente por Kong (o el plugin PEP) en cada evaluación — no por bAuth, porque es evidencia de *uso en runtime*, no de *definición de política*:

```sql
CREATE TABLE bauth.privilege_assurance_audit (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    grant_id       UUID NOT NULL REFERENCES bauth.privilege_atom_grant(id),
    resource_id    TEXT NOT NULL,
    required_loa   TEXT NOT NULL,
    presented_loa  TEXT NOT NULL,
    outcome        TEXT NOT NULL CHECK (outcome IN ('PERMIT', 'STEP_UP_REQUIRED', 'DENIED')),
    session_id     UUID NOT NULL,
    evaluated_by   TEXT NOT NULL DEFAULT 'kong-pep',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_baa_grant   ON bauth.privilege_assurance_audit (grant_id);
CREATE INDEX idx_baa_session ON bauth.privilege_assurance_audit (session_id);
```

Dado que esta tabla crece con cada request evaluado (no con cada cambio de grant), es candidata a particionamiento por fecha (`created_at`) y a una política de retención propia, distinta de la de `bos_atom_audit`.

Esta tabla da tres beneficios directos:

1. **Trazabilidad completa del flujo de step-up:** *"el usuario X intentó aprobar la venta Y con AAL1 a las 14:32, se le exigió step-up, lo completó a las 14:33, se le permitió a las 14:33:05."*
2. **Insumo directo para el evento CAEP de step-up** (Sección 5): el CAEP puede emitirse en el mismo punto donde se inserta esta fila.
3. **Separación limpia respecto al WORM de grants:** uno audita *qué se otorgó y cuándo cambió*; el otro audita *cómo se ejerció lo otorgado*.

---

## 5. Trabajo de diseño abierto (a resolver como addenda de este mismo documento)

Los puntos de la Sección 4 quedan decididos a nivel de arquitectura y DDL, pero cada mitigación tiene un componente de implementación que todavía no está especificado. Se documentan acá como extensiones de este mismo archivo — no como un documento nuevo — para mantener toda la decisión de G-04 y sus mitigaciones en una sola fuente.

| # | Pendiente | Sección que lo origina |
|---|---|---|
| 1 | Diseño del lado Kong: cómo resuelve `current_loa` contra la sesión activa — plugin custom vs. mecanismo nativo de Kong Gateway. Debe incluir el punto exacto de inserción en `privilege_assurance_audit`. | 3.4 / 4.1 |
| 2 | Especificación formal del evento CAEP de step-up (`assurance-level-change` o equivalente), emitido en el mismo punto donde Kong escribe en `privilege_assurance_audit`. | 4.3 |
| 3 | Diseño de las `NetworkPolicy`/`ServerAuthorization` de Linkerd que restringen el acceso directo a recursos con `obligation` a solo Kong como origen permitido. | 4.2 — Capa 1 |
| 4 | Contrato del SDK (`bos.GetContext()`): debe quedar excluida cualquier función que resuelva un veredicto binario de autorización a partir del bit solo, para átomos con obligación. | 4.2 — Capa 2 |
| 5 | Regla de lint/CI que detecte lectura directa del bitmask del JWT fuera de los módulos autorizados (Kong plugin, bAuth). | 4.2 — Capa 3 |
| 6 | Job de auditoría cruzada Kong↔recurso: comparación periódica entre accesos registrados en el recurso y evaluaciones registradas en `privilege_assurance_audit`, con su cadencia de ejecución y umbral de alerta. | 4.2 — Capa 4 |
| 7 | Política de partición (por fecha) y retención de `privilege_assurance_audit`, dado su crecimiento por request en vez de por cambio de grant. | 4.3 |

Cada uno de estos puntos, al resolverse, debe agregarse como una nueva sección numerada (6, 7, 8...) de este mismo documento, manteniendo la trazabilidad completa de G-04 en un solo archivo en vez de fragmentarla entre múltiples documentos SBOS-0XX.

---

## 6. Plugin Kong — diseño del lado PEP (ítem 1 de §5)

### 6.1 Arquitectura del plugin

Kong Gateway ejecuta un **plugin Go** (preferido sobre Lua para lógica compleja con acceso a Redis). El plugin actúa en la fase `access` de cada request — antes de que Kong lo reenvíe al upstream.

El plugin nunca evalúa átomos individuales. Recibe del JWT el **resultado AND compacto** (bits generales emitidos por bAuth) y, para átomos con obligación, consulta el estado de la sesión en Redis.

```
Request → Kong
    ↓ fase access (plugin bauth-pep-go)
    1. Extraer JWT del header Authorization: Bearer <token>
    2. Validar firma JWT → JWKS desde bAuth (cacheado en Kong, TTL 5 min)
    3. Leer bits generales del claim `bauth_result`
       Si bauth_result = 0 → DENY 401 inmediato (sin consulta Redis)
    4. Leer `session_id` del claim JWT
    5. Leer resource_key del request (método + path → clave canónica)
    6. Consultar Redis: HGET bauth:resource:{resource_key} obligation
       Si obligation = nil → PERMIT (sin obligación declarada)
    7. Si obligation existe:
       a. Consultar Redis: GET bauth:session:{session_id}:loa → current_loa
       b. Comparar current_loa vs. required_loa (AAL1 < AAL2 < AAL3)
       c. Si current_loa >= required_loa:
            → Insertar en privilege_assurance_audit (outcome=PERMIT) — async
            → PERMIT (Kong reenvía al upstream)
       d. Si current_loa < required_loa:
            → Insertar en privilege_assurance_audit (outcome=STEP_UP_REQUIRED) — async
            → Emitir evento CAEP assurance-level-change (§7) — async
            → Responder HTTP 401 con cabecera de challenge (RFC 9470)
```

### 6.2 Claves Redis utilizadas por el plugin

| Clave Redis | Tipo | Contenido | TTL | Quién escribe |
|---|---|---|---|---|
| `bauth:session:{session_id}:loa` | String | `"AAL1"` / `"AAL2"` / `"AAL3"` | TTL de la sesión | bAuth al autenticar / step-up |
| `bauth:resource:{resource_key}:obligation` | Hash | `{required_loa: "AAL2"}` o vacío | Sin TTL (invalidado por WAL) | bAuth al cambiar T-171 |
| `bauth:jwks` | String | JSON con claves públicas de Vault | 5 min | bAuth al rotar claves |

La clave de sesión está indexada por `session_id`, **no por `user_id`** — un mismo usuario puede tener sesiones concurrentes en distintos LoA (mobile en AAL1, desktop recién hecho step-up en AAL2).

### 6.3 Punto exacto de inserción en `privilege_assurance_audit`

El plugin inserta en T-176 de forma **asíncrona** (goroutine con canal buffered) para no agregar latencia al camino crítico del request. La inserción es fire-and-forget con retry local en caso de fallo de conexión a PostgreSQL.

```go
// Inserción asíncrona en T-176
auditCh <- AssuranceAuditEvent{
    GrantID:      grantID,       // del JWT claim
    ResourceID:   resourceKey,
    RequiredLoA:  requiredLoA,   // de T-171 via Redis
    PresentedLoA: currentLoA,    // de Redis session store
    Outcome:      outcome,       // PERMIT | STEP_UP_REQUIRED | DENIED
    SessionID:    sessionID,     // del JWT claim
    EvaluatedBy:  "kong-pep",
}
```

### 6.4 Respuesta HTTP al cliente en caso de step-up requerido (RFC 9470)

```http
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Bearer
    error="insufficient_user_authentication",
    error_description="Se requiere AAL2 para este recurso",
    acr_values="AAL2",
    realm="bauth"
Content-Type: application/json

{
  "error": "insufficient_user_authentication",
  "required_loa": "AAL2",
  "step_up_url": "https://{tenant}.sbos.local/bauth/step-up"
}
```

---

## 7. Evento CAEP de step-up — especificación formal (ítem 2 de §5)

### 7.1 Tipo de evento

El estándar CAEP 1.0 (OpenID Foundation, Final — 2 sep 2025) define el tipo de evento
`assurance-level-change` para señalar cambios en el nivel de garantía de autenticación de
una sesión. Este es el evento correcto para el flujo de step-up de G-04.

URI canónica del tipo:
```
https://schemas.openid.net/secevent/caep/event-type/assurance-level-change
```

### 7.2 Flujo de emisión del evento

El evento CAEP de step-up **NO lo emite Kong** cuando detecta que el LoA es insuficiente.
Kong en ese punto devuelve el challenge HTTP 401 al cliente y registra en T-176.

El evento CAEP lo emite **bAuth** cuando el usuario completa el step-up exitosamente:

```
1. Kong detecta current_loa < required_loa
       → HTTP 401 + challenge RFC 9470 al cliente
       → INSERT en T-176 (outcome=STEP_UP_REQUIRED) — async

2. Cliente hace step-up con bAuth (completa 2FA / WebAuthn / etc.)
       → bAuth valida el factor adicional
       → bAuth actualiza Redis: SET bauth:session:{session_id}:loa "AAL2"
       → bAuth emite evento CAEP assurance-level-change → Kong (SSF Receiver)

3. Kong recibe el evento CAEP
       → Invalida su cache local del LoA para esa sesión
       → Próximo request del cliente pasa con current_loa=AAL2

4. Cliente reintenta el request original
       → Kong lee Redis → current_loa=AAL2 ≥ required_loa=AAL2
       → INSERT en T-176 (outcome=PERMIT) — async
       → PERMIT
```

### 7.3 Payload del evento CAEP

```json
{
  "iss": "https://{tenant}.sbos.local/bauth",
  "iat": 1721234567,
  "jti": "evt-{uuid}",
  "aud": ["kong-pep"],
  "events": {
    "https://schemas.openid.net/secevent/caep/event-type/assurance-level-change": {
      "subject": {
        "format":     "session_id",
        "session_id": "{session_id}"
      },
      "current_level":    "AAL2",
      "previous_level":   "AAL1",
      "change_direction": "increase",
      "initiating_entity": "subject",
      "event_timestamp":  1721234567890
    }
  }
}
```

El campo `change_direction` puede ser `"increase"` (step-up completado) o `"decrease"`
(downgrade de sesión, ej. por timeout de AAL2).

### 7.4 Canal de entrega

El evento se envía sobre la misma Interface Dual (Unix socket `/run/bos/bauth.sock`) que
bAuth ya usa para JSON-RPC. Kong tiene un SSF Receiver registrado como suscriptor del stream
de eventos de bAuth — no requiere infraestructura adicional de mensajería.

---

## 8. NetworkPolicy Linkerd — restricción topológica de red (ítem 3 de §5)

### 8.1 Principio

La Capa 1 de §4.2 exige que **ningún pod de SBOS pueda alcanzar directamente** un recurso
protegido con obligación (ej. Tryton). Solo Kong puede hacerlo. Esta restricción se implementa
a nivel de service mesh — no depende de que el desarrollador recuerde enrutar por Kong.

### 8.2 Recursos Linkerd a crear

```yaml
# Server: define el conjunto de pods protegidos (ej. Tryton)
apiVersion: policy.linkerd.io/v1beta3
kind: Server
metadata:
  name: tryton-protected
  namespace: sbos-core
  annotations:
    bauth.sbos/obligation-protected: "true"
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: tryton
  port: 8069
  proxyProtocol: HTTP/1

---
# AuthorizationPolicy: solo Kong puede acceder a pods protegidos con obligación
apiVersion: policy.linkerd.io/v1beta3
kind: AuthorizationPolicy
metadata:
  name: obligation-resources-kong-only
  namespace: sbos-core
spec:
  targetRef:
    group:    policy.linkerd.io
    kind:     Server
    name:     tryton-protected
  requiredAuthenticationRefs:
    - name:       kong-mtls-auth
      kind:       MeshTLSAuthentication
      group:      policy.linkerd.io

---
# MeshTLSAuthentication: identifica a Kong por su ServiceAccount mTLS
apiVersion: policy.linkerd.io/v1beta3
kind: MeshTLSAuthentication
metadata:
  name: kong-mtls-auth
  namespace: sbos-core
spec:
  identities:
    - "kong-gateway.sbos-gateway.serviceaccount.identity.linkerd.cluster.local"
```

### 8.3 Qué cubre y qué no cubre

| Escenario | Cubierto |
|---|---|
| Pod SBOS intenta llamar a Tryton directamente (por código o bug) | ✅ Bloqueado por Linkerd — TCP rechazado antes de llegar al pod |
| Developer conecta kubectl port-forward a Tryton | ❌ No cubierto — requiere control de acceso RBAC en k3s |
| Kong llama a Tryton con mTLS identity válida | ✅ Permitido |
| Otro servicio con ServiceAccount de Kong | ❌ No aplica — el ServiceAccount es del pod Kong, no compartible |

### 8.4 Cuándo aplicar

Crear estos recursos al desplegar cualquier recurso cuya tabla T-171 tenga al menos un átomo
con `obligation IS NOT NULL`. El anotador `bauth.sbos/obligation-protected: "true"` en el
Server es la señal que la automatización de despliegue puede usar para generar la policy.

---

## 9. Contrato del SDK `bos.GetContext()` (ítem 4 de §5)

### 9.1 Principio

El SDK que expone el contexto de autenticación/autorización a los desarrolladores de apps SBOS
**nunca debe ofrecer una función `isPermitted()`** que resuelva un veredicto binario a partir
del bit del bitmask solo, para átomos que tengan obligación declarada en T-171.

El motivo: si el SDK ofrece esa función, un desarrollador la usará — y si el átomo tiene
obligación, esa función daría un veredicto incorrecto (ignora el LoA requerido). El SDK debe
hacer imposible el antipatrón, no solo desaconsejarlo.

### 9.2 API pública permitida del SDK

```rust
/// Contexto de autenticación y grants del usuario actual.
pub struct BosContext {
    pub user_id:    Uuid,
    pub session_id: Uuid,
    pub tenant_id:  Uuid,
    // Acceso al resultado AND del bitmask (bits generales del JWT)
    bitmask_result: BitmaskResult,
}

impl BosContext {
    /// Retorna true si el grant del átomo existe para este usuario.
    /// NO indica que el acceso esté autorizado — para recursos con obligación
    /// de LoA, la decisión final es de Kong (PEP). Usar solo para UI (mostrar/ocultar).
    pub fn has_grant(&self, atom_slug: &str) -> bool { ... }

    /// Versión explícita para UI: "¿puede el usuario VER este elemento?"
    /// Semánticamente equivalente a has_grant() — el nombre aclara la intención.
    pub fn can_see(&self, atom_slug: &str) -> bool {
        self.has_grant(atom_slug)
    }

    /// PROHIBIDO exponer — nunca implementar:
    /// pub fn is_permitted(&self, atom_slug: &str) -> bool { ... }
    /// La autorización final con obligación es responsabilidad exclusiva de Kong.
}
```

### 9.3 Documentación obligatoria del SDK

Toda función del SDK que exponga el bitmask o el resultado AND debe incluir en su doc comment:

```rust
/// ⚠️  IMPORTANTE: este método indica que el grant *existe*, no que el acceso
/// *está autorizado*. Para recursos con obligación de LoA (ver T-171), la
/// autorización final es evaluada por Kong en cada request. No usar este
/// método para tomar decisiones de acceso en el servidor — solo para UI.
```

---

## 10. Regla de lint y CI — detección de acceso no autorizado al bitmask (ítem 5 de §5)

### 10.1 Qué detectar

El antipatrón a prevenir: código de aplicación que lee claims del JWT relacionados al bitmask
**fuera de los módulos autorizados** (Kong plugin y `src/domain/bitmask.rs` de bAuth).

### 10.2 Regla CI — script de detección (ejecuta en cada PR)

```bash
#!/usr/bin/env bash
# ci/lint-bitmask-access.sh
# Detecta acceso directo al bitmask fuera de módulos autorizados.
# Falla el build si encuentra el antipatrón.

set -euo pipefail

AUTHORIZED_PATHS=(
  "src/domain/bitmask"
  "src/engine"
  "plugins/kong"
  "src/server/auth"
)

# Construir patrón de exclusión
EXCLUDE_ARGS=()
for path in "${AUTHORIZED_PATHS[@]}"; do
  EXCLUDE_ARGS+=(--exclude-dir="$path")
done

# Buscar acceso al bitmask fuera de módulos autorizados
HITS=$(grep -rn \
  --include="*.rs" --include="*.lua" --include="*.go" \
  "${EXCLUDE_ARGS[@]}" \
  -E "bauth_result|rol_bitmask|atom_position.*bit|bitmask_bit|hasPermission|is_permitted" \
  . 2>/dev/null || true)

if [[ -n "$HITS" ]]; then
  echo "❌ LINT ERROR: acceso al bitmask/resultado fuera de módulos autorizados:"
  echo "$HITS"
  echo ""
  echo "Solo src/domain/bitmask, src/engine, plugins/kong y src/server/auth"
  echo "pueden leer el bitmask directamente. Ver SBOS-0XX-G04 §10."
  exit 1
fi

echo "✅ lint-bitmask-access: OK"
```

### 10.3 Integración en pipeline CI (GitHub Actions / Fábrica SBOS)

```yaml
# .github/workflows/security-lint.yml (extracto)
- name: Lint — acceso no autorizado al bitmask
  run: bash ci/lint-bitmask-access.sh
```

Esta regla debe ejecutarse en todo PR que modifique archivos `.rs`, `.lua` o `.go`. Su
fallo bloquea el merge — no es una advertencia opcional.

---

## 11. Job de auditoría cruzada Kong ↔ recurso (ítem 6 de §5)

### 11.1 Objetivo

Detectar accesos efectivos a un recurso protegido con obligación que **no tienen registro
correspondiente en `privilege_assurance_audit`** — evidencia de un bypass de Kong o una
falla en el mecanismo de registro.

Un acceso en el log del recurso sin PERMIT en T-176 es un **evento de seguridad P0**.

### 11.2 Lógica del job

```
Para cada recurso con obligation IS NOT NULL en T-171:
  1. Leer accesos exitosos (HTTP 2xx) del log del recurso en período P
     → fuente: log estructurado del pod (JSON) vía bkiernel o archivo
  2. Leer PERMIT en privilege_assurance_audit para el mismo recurso y período P
  3. Cruzar por (session_id, timestamp ±30s)
  4. Para cada acceso sin PERMIT correspondiente:
     → Emitir alerta SIEM (Wazuh syslog, nivel CRÍTICO)
     → Registrar en bauth.privilege_audit_anomaly (tabla de incidentes de seguridad)
  5. Métrica: porcentaje de cobertura = PERMIT / accesos_totales × 100
     → Si < 99.9% → alerta WARNING (posible pérdida de eventos)
```

### 11.3 Cadencia y retención

| Parámetro | Valor | Justificación |
|---|---|---|
| Cadencia del job | Cada 4 horas | Detecta bypasses antes del fin de jornada laboral |
| Ventana de análisis | Últimas 8 horas (overlapping) | Absorbe retardos de log y reinicios de pod |
| Umbral de alerta P0 | 1 acceso sin PERMIT | Cero tolerancia a bypasses |
| Umbral WARNING | Cobertura < 99.9% | Posible pérdida de eventos de auditoría |
| Retención de anomalías | 5 años | Evidencia forense de largo plazo |

### 11.4 Implementación

Job Rust compilado a binario estático (MUSL), ejecutado por systemd timer en el host del
daemon bAuth. Accede a PostgreSQL vía connection pool interno. Sin dependencias externas
adicionales al stack bAuth.

---

## 12. Particionamiento y retención de `privilege_assurance_audit` (ítem 7 de §5)

### 12.1 Por qué necesita tratamiento especial

`privilege_assurance_audit` (T-176) crece con cada request a un recurso con obligación —
no con cada cambio de grant como `privilege_atom_audit`. Su volumen es proporcional al
tráfico de la aplicación, no a la actividad administrativa. Sin particionamiento, la tabla
puede crecer hasta millones de filas en meses, degradando las consultas de auditoría.

### 12.2 DDL con particionamiento por rango mensual

```sql
-- T-176 · privilege_assurance_audit — tabla maestra particionada
CREATE TABLE bauth.privilege_assurance_audit (
    id             uuid        NOT NULL DEFAULT gen_random_uuid(),
    grant_id       uuid        NOT NULL REFERENCES bauth.privilege_atom_grant(id),
    resource_id    text        NOT NULL,
    required_loa   text        NOT NULL CHECK (required_loa IN ('AAL1','AAL2','AAL3')),
    presented_loa  text        NOT NULL CHECK (presented_loa IN ('AAL1','AAL2','AAL3')),
    outcome        text        NOT NULL CHECK (outcome IN ('PERMIT','STEP_UP_REQUIRED','DENIED')),
    session_id     uuid        NOT NULL,
    evaluated_by   text        NOT NULL DEFAULT 'kong-pep',
    created_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT privilege_assurance_audit_pkey PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Restricción de escritura: solo Kong puede insertar; bAuth y otros pueden leer
REVOKE INSERT, UPDATE, DELETE ON bauth.privilege_assurance_audit FROM bauth_app_role;
GRANT  INSERT ON bauth.privilege_assurance_audit TO kong_pep_role;
GRANT  SELECT ON bauth.privilege_assurance_audit TO bauth_app_role;

-- Partición inicial (mes corriente)
CREATE TABLE bauth.privilege_assurance_audit_2026_07
    PARTITION OF bauth.privilege_assurance_audit
    FOR VALUES FROM ('2026-07-01 00:00:00+00') TO ('2026-08-01 00:00:00+00');

-- Índices heredados por todas las particiones
CREATE INDEX idx_paa_grant_id    ON bauth.privilege_assurance_audit (grant_id);
CREATE INDEX idx_paa_session_id  ON bauth.privilege_assurance_audit (session_id);
CREATE INDEX idx_paa_resource    ON bauth.privilege_assurance_audit (resource_id, created_at);
CREATE INDEX idx_paa_outcome     ON bauth.privilege_assurance_audit (outcome, created_at)
    WHERE outcome IN ('STEP_UP_REQUIRED','DENIED');
```

### 12.3 Job de mantenimiento de particiones

Systemd timer mensual (ejecuta el día 25 de cada mes):

```bash
#!/usr/bin/env bash
# scripts/maintain-assurance-audit-partitions.sh
# Crea partición del mes siguiente y elimina particiones con más de 24 meses.

set -euo pipefail

NEXT_MONTH=$(date -d "+1 month" +%Y_%m)
NEXT_MONTH_START=$(date -d "+1 month" +%Y-%m-01)
NEXT_MONTH_END=$(date -d "+2 months" +%Y-%m-01)
CUTOFF_MONTH=$(date -d "-24 months" +%Y_%m)

psql "$BAUTH_DB_URL" <<SQL
-- Crear partición del mes siguiente (idempotente)
CREATE TABLE IF NOT EXISTS bauth.privilege_assurance_audit_${NEXT_MONTH}
    PARTITION OF bauth.privilege_assurance_audit
    FOR VALUES FROM ('${NEXT_MONTH_START}') TO ('${NEXT_MONTH_END}');

-- Eliminar partición de hace 24 meses (retención 2 años)
DROP TABLE IF EXISTS bauth.privilege_assurance_audit_${CUTOFF_MONTH};
SQL

echo "✅ Particiones de privilege_assurance_audit mantenidas."
```

### 12.4 Política de retención

| Período | Justificación normativa |
|---|---|
| **2 años** | ISO 27001:2022 A.8.15 (registros de auditoría de seguridad) · NIST SP 800-53 AU-11 |
| Eventos STEP_UP / DENIED | Misma retención — son evidencia de intentos de acceso |
| Extensión a 5 años | Solo si el tenant opera bajo PCI DSS 4.0 o regulación sectorial específica |

La política de retención de 2 años aplica por defecto a todos los tenants. Tenants con
requisitos adicionales pueden configurar retención extendida vía parámetro de tenant en
`idn_tier_policy` (columna a agregar: `audit_retention_months integer NOT NULL DEFAULT 24`).

---

**Historial de versiones**

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0 | 2026-07-19 | Decisión G-04 inicial (secciones 1-5) |
| 1.1 | 2026-07-20 | Addendas §6-§12: diseño Kong plugin, CAEP step-up, Linkerd, SDK, lint CI, auditoría cruzada, particionamiento T-176 |
