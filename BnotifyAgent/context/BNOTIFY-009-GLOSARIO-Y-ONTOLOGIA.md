---
codigo: BNOTIFY-009
version: 1.0.0
estado: BORRADOR
gate: G0
depende_de: [BNOTIFY-000]
doctrina_que_ejerce: [D14]
criterio_implementado: >
  Todo concepto de dominio usado en el código y los documentos del proyecto
  tiene definición en este glosario. Un agente puede resolver cualquier término
  del proyecto consultando este archivo sin necesidad de inferir su significado.
---

# BNOTIFY-009 — Glosario y Ontología
## Vocabulario de dominio estable del proyecto bNotify

**Versión:** 1.0.0 · **Gate:** G0 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 (fuente de verdad de todos los conceptos aquí definidos)

**Propósito:** los conceptos de dominio son más estables que las rutas de archivos o
los nombres de funciones. Este glosario es el anti-alucinación: antes de usar un término,
verificar su definición exacta aquí. Si el término no está, agregarlo antes de usarlo.

---

## A

**Adaptador** (`adapter`)
Componente que traduce entre el protocolo interno de bNotify (gRPC) y el protocolo
específico de un canal externo (REST de bRocket, SMTP, SMPP, FCM, HTTP webhook).
Cada canal tiene exactamente un adaptador. El adaptador es la única pieza que conoce
el canal concreto — el resto del sistema no.
→ Ver BNOTIFY-000 §3, BNOTIFY-011 a BNOTIFY-015

**Átomo** (`atom`, `privilege_atom`)
Unidad mínima e indivisible de permiso en el motor bAuth. Cada acción del sistema
tiene exactamente un átomo asignado. Los átomos se combinan en BitMasks para
evaluar permisos en tiempo constante (<0.5ns). Los átomos de mensajería tienen el
prefijo `D1.bchat.*`.
→ Ver bAuth CLAUDE.md §3, BNOTIFY-000 §4.3

**Audiencia** (`audience`)
Lista de suscripción propia de bNotify — un conjunto nombrado de usuarios (p.ej.
"operadores de guardia", "clientes del comercio X"). Es un tipo de destino de
notificación de primera clase. Se distingue de *rol* (que vive en bAuth) porque
la audiencia es configuración del plano de notificaciones, no identidad.
→ Ver BNOTIFY-000 §4.7

---

## B

**bAuth**
Daemon de identidad y autorización de SBOS. Es el PDP (Policy Decision Point) del
ecosistema. Emite JWT con claims de rol, valida ctx_id, gestiona átomos, y actúa
como OIDC Provider nativo. bNotify actúa como PEP (Policy Enforcement Point) —
aplica las decisiones de bAuth en cada despacho de notificación.
→ Ver BNOTIFY-000 §4.3, D3, D16

**bChat**
Motor de mensajería **propio en Rust** (Axum/Tokio) sobre PostgreSQL con cliente
Flutter — el destino de largo plazo del programa. **No es Rocket.Chat**. No existe
todavía (gates G2–G3). Es la plataforma tipo WeChat del ecosistema SBOS.
→ Ver BNOTIFY-000 §6, BNOTIFY-030 a 036

**bNotify**
El daemon orquestador central de notificaciones. No es un canal. No es el bus.
No es la identidad. Es la pieza estable que recibe intents y decide a quién,
por dónde y cuándo llega cada notificación. Ver definición completa en BNOTIFY-000 §4.0
→ Ver BNOTIFY-000 §4, BNOTIFY-010

**bRocket**
Nombre de infraestructura interna para la instancia de **Rocket.Chat CE 8.5.0 sin
modificar** que sirve como canal de chat mientras se construye bChat. Congelado en
versión fija. No recibe desarrollo — solo configuración (D7). Tiene fecha de apagado:
cuando bChat alcance paridad interna (gate G3).
⚠️ No es bChat. No es el producto final. Es el puente.
→ Ver BNOTIFY-000 §5, ADR-003

---

## C

**Canal** (`channel`)
Medio de entrega de una notificación: chat (bRocket/bChat), email, SMS, push, in-app,
webhook. bNotify soporta 6 canales. Cada canal tiene un adaptador.
El canal es intercambiable — cambiar bRocket por bChat es cambiar el adaptador,
no el contrato con los emisores.
→ Ver BNOTIFY-000 §3, BNOTIFY-011 a 015

**CAEP** (Continuous Access Evaluation Protocol)
Estándar OpenID (1.0 Final, septiembre 2025) para que bAuth emita eventos de sesión
en tiempo real: `session-revoked`, `credential-change`, `assurance-level-change`.
bNotify consume estos eventos para suspender entregas a contextos revocados.
→ Ver BNOTIFY-000 §4.3, EVALUACION-INTEGRAL-BAUTH §4.6

**ctx_id** (Context ID)
Identificador de contexto de sesión de SBOS-049. UUID obligatorio en toda operación
del ecosistema. En bNotify: todo intent entrante lleva ctx_id, todo despacho lo
propaga, toda fila en `bnotify.notification_event` tiene ctx_id NOT NULL.
→ Ver SBOS-049, BNOTIFY-000 §4.3

**Clase de auditoría** (A, B o C)
Nivel de criticidad y retención de un evento de auditoría:
- **Clase A:** WORM individual, 7-10 años. Eventos críticos (cambios de rol, MFA, wallet)
- **Clase B:** Digest Merkle batcheado, 90-365 días. Metadatos transaccionales
- **Clase C:** Best-effort, 7-30 días. Telemetría (presencia, lecturas, conexiones)
→ Ver BNOTIFY-000 §4.2, BNOTIFY-004

---

## D

**DLQ** (Dead Letter Queue)
Cola de destino para mensajes inentregables tras agotar todos los reintentos.
Un mensaje en DLQ genera alarma automática — nunca se pierde en silencio.
→ Ver BNOTIFY-000 §4.2

**Destino** (`destination`)
A quién va dirigida una notificación. Cuatro tipos: usuario (UUID bAuth), rol/grupo
organizacional (expandido por bAuth), audiencia (lista propia de bNotify), o
destino nativo de canal (sala/canal de chat — se expande en el momento del despacho).
→ Ver BNOTIFY-000 §4.7

---

## E

**Emisor** (`emitter`)
Cualquier daemon del ecosistema que produce un intent de notificación: bAuth (MFA),
bPay (transacción), bCms (contenido), bCalendar (alarma), Tryton (factura). Los
emisores hablan con bNotify mediante gRPC — nunca conocen el canal de destino.
→ Ver BNOTIFY-000 §4.0

---

## F

**Failover**
Mecanismo por el que bNotify escala al siguiente canal cuando el preferido falla o
no confirma entrega. Orden por defecto: chat → push → email → SMS (configurable
por tipo de evento y preferencias del usuario).
→ Ver BNOTIFY-000 §4.2

---

## G

**Gate** (G0 a G5)
Hito del programa definido en BNOTIFY-000 §7. Los gates avanzan por demostración
(D13), no por fecha. Un gate no superado detiene la inversión de la fase siguiente.
→ Ver BNOTIFY-000 §7

**gRPC**
Protocolo de comunicación entre daemons del ecosistema SBOS (ADR-001, D4).
Usa Protocol Buffers para serialización. mTLS obligatorio. **Nunca REST entre daemons.**
→ Ver BNOTIFY-000 D4, ADR-001, BNOTIFY-001

---

## H

**Herramienta ejecutora** (`tool`)
Servidor o servicio que realiza la entrega concreta de un dominio: Dovecot entrega
el correo, bPay ejecuta pagos, el motor de chat entrega mensajes. Las herramientas
ejecutoras son independientes — bNotify las dirige, no las administra.
→ Ver BNOTIFY-000 §4.7d, D17

---

## I

**Intent** (`notification_intent`)
Evento de dominio que un daemon emite hacia bNotify para solicitar la entrega de una
notificación. Es el mensaje de entrada del sistema: contiene qué ocurrió, quién es el
destinatario (ctx_id), datos para renderizar la plantilla, urgencia, y TTL.
El intent es independiente del canal — bNotify decide el canal.
→ Ver BNOTIFY-000 §4.2, BNOTIFY-001

**Idempotencia**
Propiedad de que un intent enviado múltiples veces produce el mismo efecto que
enviarlo una vez. bNotify garantiza entrega at-least-once con efectos exactly-once:
el usuario nunca recibe el mismo mensaje duplicado aunque el sistema reintente.
→ Ver BNOTIFY-000 §4.2

---

## K

**KYC Tier** (Know Your Customer)
Nivel de verificación de identidad de un usuario consumidor: T0 (solo teléfono, IAL1),
T1 (documento + verificación remota, IAL2), T2 (biométrico + verificación presencial, IAL3).
Gobierna los límites de acceso a funcionalidades financieras (bPay).
→ Ver BNOTIFY-000 §6.2 C5, BNOTIFY-062, EVALUACION-INTEGRAL-BAUTH §3.1

---

## L

**LiveKit**
Motor de video y voz de bChat — SFU open source con SDKs Flutter y Rust. Reemplaza
a Jitsi en bChat (ADR-004). bRocket continúa usando Jitsi (ya integrado en RC).
→ Ver BNOTIFY-000 Anexo B §B.2, BNOTIFY-035

---

## M

**MLS** (Message Layer Security, RFC 9420)
Estándar IETF de cifrado E2E grupal para bChat en fase C5. Implementado con OpenMLS
o mls-rs (ambos en Rust). No se implementa criptografía propia (D12).
→ Ver BNOTIFY-000 Anexo B, ADR-005, BNOTIFY-060

**Módulo** (`module`)
Mini-aplicación que se instala en bChat sin recompilar el motor. Existe en dos formas:
módulo-servicio (proceso gRPC externo) o módulo-plugin (archivo WASM cargado por wasmtime).
Todo módulo declara permisos en su manifiesto y los ejerce mediante átomos bAuth.
→ Ver BNOTIFY-000 §B.4, ADR-007, BNOTIFY-040 a 045

---

## O

**OIDC** (OpenID Connect)
Protocolo de autenticación sobre OAuth 2.0. bAuth actúa como OIDC Provider nativo
(no Keycloak) para bRocket y bChat. Los endpoints son: `authorize`, `token`,
`userinfo`, `jwks`. El claim `sbos_roles` en el id_token lleva los roles del usuario.
→ Ver BNOTIFY-000 §5, BNOTIFY-002

---

## P

**PDP / PEP**
Policy Decision Point / Policy Enforcement Point. Patrón de Zero Trust (NIST SP 800-207).
bAuth es el PDP (decide). Cada daemon es su propio PEP (aplica la decisión).
bNotify valida el ctx_id del destinatario contra bAuth antes de cada despacho.
→ Ver BNOTIFY-000 §4.3, D16

**Perfil de notificación** (`notification_profile`)
Configuración por usuario en el dominio de bNotify: canales preferidos por tipo de
evento, quiet hours por zona horaria, opt-in/out, topes de frecuencia, idioma de plantilla.
Es legítimamente de bNotify — es configuración del plano de notificaciones, no identidad.
→ Ver BNOTIFY-000 §4.2, §4.3

**Plantilla** (`template`)
Mensaje parametrizado por tipo de evento, canal e idioma. bNotify resuelve la plantilla
y la rellena con los datos del intent. El contenido de negocio ("qué decir") es del
emisor; la forma de decirlo ("por qué canal, en qué idioma, con qué formato") es de bNotify.
→ Ver BNOTIFY-000 §4.0, BNOTIFY-010

**Prioridad** (clase A / B / C en el contexto del dispatcher)
En el dispatcher de bNotify: separación de colas por urgencia del evento.
Un OTP de bPay (clase A) nunca espera detrás de un resumen semanal (clase C).
Distinto de las *clases de auditoría* aunque comparten la misma escala A/B/C.
→ Ver BNOTIFY-000 §4.2

---

## R

**Rate limiting**
Control de frecuencia de notificaciones por usuario y tipo de evento. bNotify lo
aplica antes del despacho — sin él, el sistema entrena a los usuarios a ignorarlo
(anti-fatiga, BNOTIFY-000 §4.2). Leaky bucket es el algoritmo estándar de facto.
→ Ver BNOTIFY-000 §4.2, EVALUACION-INTEGRAL-BAUTH §4.7

---

## S

**sbos_roles**
Claim del JWT de bAuth que lista los roles activos del usuario. bRocket lee este claim
del id_token OIDC para asignar roles en Rocket.Chat. Es el mecanismo que reemplaza
LDAP Role Mapping y Auto-join de Rocket.Chat EE.
→ Ver BNOTIFY-000 §5, BNOTIFY-002

---

## T

**Tier** (T0, T1, T2)
Ver *KYC Tier*.

---

## W

**WASM** (WebAssembly)
Formato binario portable para módulos-plugin de bChat. Ejecutado en sandbox por
wasmtime con capacidades declaradas en el manifiesto del módulo (D6).
→ Ver BNOTIFY-000 §B.4, ADR-007, BNOTIFY-041

---

*BNOTIFY-009 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*Si un término del proyecto no está aquí, agrégalo antes de usarlo.*
