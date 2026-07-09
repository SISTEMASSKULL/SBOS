# BNOTIFY-000 — Doctrina y Plan Maestro del Proyecto BNotify
## bNotify (orquestador) · bRocket (solución interina) · bChat (motor propio, destino WeChat)
**Código:** BNOTIFY-000 · **Versión:** 2.0 · **Fecha:** Julio 2026 · **Autor:** Ivan / SKULL · **Estado:** Doctrina rectora — todo documento BNOTIFY-0XX se subordina a este
**Reemplaza en jerarquía a:** docs 01–07 y SBOS-0XX-BNOTIFY (que pasan a ser material de referencia — ver §9)
**Naturaleza:** este documento es simultáneamente (a) la doctrina del proyecto — los principios que ningún documento posterior puede contradecir — y (b) el plan de implementación: la secuencia documental de la §10 ES el proyecto; consumar cada documento en orden es consumar BNotify.

---

## 0. Doctrina BNotify — los principios que gobiernan todo documento BNOTIFY-0XX

Cada principio nació de una decisión razonada en el diseño de este programa. Ningún documento, módulo o línea de código del proyecto puede contradecirlos; cualquier excepción exige enmienda formal de este documento, no una excepción silenciosa.

| # | Principio | Enunciado operativo |
|---|---|---|
| D1 | **No reinventar la rueda — en ambas direcciones** | Adoptar lo maduro que ya existe (LiveKit, MLS, NATS, PostgreSQL, S3); jamás conservar lo viejo por inercia. Toda pieza nueva exige demostrar que no existe rueda mejor |
| D2 | **Soberanía** | Todo self-hosted; identidad, pagos y datos son propios. Dependencia externa solo donde no existe alternativa física (APNs en iOS) y siempre encapsulada en un adaptador |
| D3 | **bAuth es el plano de identidad** | Identidad, autorización, sesión (ctx_id), dispositivos y auditoría viven en bAuth. Ninguna aplicación del ecosistema posee usuarios propios; solo proyecciones |
| D4 | **Cero REST en el núcleo** | gRPC entre daemons; JSON-RPC 2.0 sobre WebSocket hacia clientes; HTTP confinado a los adaptadores de frontera con el mundo exterior |
| D5 | **Orquestación sobre acoplamiento** | Los daemons hablan con bNotify, jamás con un canal directamente. Todo canal es un adaptador intercambiable; cambiar bRocket por bChat es invisible para el resto de SBOS |
| D6 | **El motor jamás se recompila** | Toda extensión se anexa en caliente: manifiesto declarativo + registro RPC; ejecución como módulo-servicio (gRPC) o módulo-plugin (WASM). Recompilar el main para agregar funcionalidad es un error de arquitectura |
| D7 | **Lo interino no recibe inversión** | En soluciones puente (bRocket) solo configuración, cero desarrollo. Todo esfuerzo de construcción va al destino (bChat), nunca al puente |
| D8 | **Clean-room absoluto** | Las ideas, comportamientos y especificaciones ajenas son libres de estudiar por fuentes limpias; el código propietario ajeno jamás se lee para implementar. Todo diseño propio se documenta con fecha y fuentes |
| D9 | **La escala se define con números** | "Grande" es una tabla de objetivos de capacidad con pruebas de carga, nunca un adjetivo. Nada se declara terminado sin su prueba; todo componente publica su modelo de capacidad |
| D10 | **Frontera de producto: transacción, no atención** | bChat es herramienta de negocios: conversar, transferir valor, procesar datos empresariales. Publicidad explícita prohibida por diseño; lo comercial vive dentro de la relación negocio-cliente |
| D11 | **Proporcionalidad de datos** | Se auditan metadatos con clases A/B/C (WORM directa, WORM agregada, telemetría); el contenido de mensajes jamás se registra. Todo acceso de moderación a contenido reportado es WORM |
| D12 | **Criptografía solo estándar** | Jamás inventar criptografía propia. E2EE = MLS (RFC 9420) con implementaciones auditables (OpenMLS / mls-rs) y revisión externa antes de producción |
| D13 | **Gates por demostración** | Las fases avanzan cuando el criterio de salida se demuestra funcionando, no cuando llega la fecha. Un gate no superado detiene la inversión de la fase siguiente |
| D14 | **El contrato precede al código** | Toda pieza se especifica como documento BNOTIFY-0XX versionado antes de implementarse. La secuencia documental de la §10 es el plan de implementación del proyecto |
| D15 | **Degradación aislada** | Un módulo o canal caído degrada solo su superficie. El núcleo de conversación jamás depende de ningún módulo, canal ni servicio externo para operar |
| D16 | **Separación decisión/aplicación (PDP/PEP)** | bAuth decide (Policy Decision Point: identidad, permisos, sesión); cada daemon aplica (Policy Enforcement Point) validando el ctx_id en su plano. Ningún daemon posee usuarios ni decide identidad — pero todo daemon es responsable de aplicar la decisión antes de actuar |
| D17 | **Herramientas ejecutoras, recepción soberana** | Los servidores del ecosistema (Dovecot, bPay, LiveKit) son herramientas independientes que ejecutan la distribución que bNotify direcciona hacia audiencias (individuo, grupo, sala) — p. ej. la planilla de sueldos hacia un grupo. Ninguna herramienta ni bNotify administra el dominio individual del usuario: el buzón, la billetera y las preferencias de recepción son soberanía de cada usuario |
| D18 | **Un clúster, dueños por esquema** | Los daemons comparten el mismo clúster PostgreSQL con un esquema por dueño (`bauth`, `bnotify`, `bchat`, correo) y **vistas de solo lectura** cruzadas: la identidad se lee "a la mano" desde las vistas de bAuth, la membresía de salas desde las del chat — pero **solo el dueño escribe en su esquema**. Compartir lectura no es compartir propiedad |

## 1. Visión del programa

Construir la capa de comunicaciones del ecosistema SBOS en tres piezas con roles distintos y ciclos de vida distintos:

1. **bNotify** — orquestador de notificaciones multi-canal en **Rust**: un router que recibe eventos de dominio de cualquier daemon (bAuth, bPay, bCms, Context Plane) y los direcciona a uno o varios canales (chat, email, SMS, push, webhook) según destinatario, preferencias y urgencia resueltos por `ctx_id`. Pieza permanente y central.
2. **bRocket** — despliegue de **Rocket.Chat Community sin modificar** como primera fuente de solución de chat: operativo en semanas, sirve como canal de bNotify y como chat funcional del ecosistema **mientras** se construye el motor propio. Pieza interina con fecha de demolición.
3. **bChat** — motor de mensajería **propio en Rust** (Axum/Tokio) sobre **PostgreSQL**, con cliente **Flutter**, identidad nativa bAuth/ctx_id, y las mismas herramientas externas ya validadas por Rocket.Chat (Jitsi para video, S3 para medios, NATS como bus). Destino de largo plazo: plataforma nivel WeChat — mensajería + formularios + mini-aplicaciones + correo integrado + servicios del ecosistema (bPay).

**Principio del programa:** bRocket compra tiempo; bChat compra futuro; bNotify es el contrato estable que permite que el reemplazo de uno por otro sea invisible para el resto de SBOS — porque los daemons hablan con bNotify, nunca directamente con el chat.

## 2. ⚠️ Advertencia de nombre (resolver antes de cualquier uso público)

**"bRocket" contiene la marca "Rocket"** y designa precisamente una instalación de Rocket.Chat. Como **nombre interno/codename** es inofensivo; como nombre público de un servicio (dominio, app, material de usuario) crea riesgo de infracción o confusión de marca con Rocket.Chat Technologies Corp. Regla del programa: bRocket es codename de infraestructura interna; si la instancia interina llega a exponerse a usuarios externos, se le da un nombre comercial propio sin referencia a Rocket. bChat no tiene este problema.

## 3. Arquitectura del programa

```
                         ┌────────────────────────────────────────┐
  bAuth ────────────────▶│                                        │
  bPay ─────────────────▶│              bNotify (Rust)            │
  bCms ─────────────────▶│   resuelve: destinatario (ctx_id),     │
  Context Plane ────────▶│   preferencias, canal(es), urgencia    │
                         └───────┬──────────┬─────────┬───────────┘
                                 │ gRPC     │ gRPC    │ gRPC   (contrato interno único)
              ┌──────────────────┼──────────┼─────────┼──────────────────┐
              ▼                  ▼          ▼         ▼                  ▼
        adaptador chat      adaptador   adaptador  adaptador       adaptador
              │              email        SMS       push            webhook
   ┌──────────┴──────────┐  Postfix/    Jasmin/   (fase Flutter:   CloudEvents
   │ HOY: bRocket        │  Dovecot     Kannel     UnifiedPush/     (externos)
   │ (Rocket.Chat CE     │  +Roundcube  (SMPP)     ntfy · APNs)
   │  sin modificar)     │
   │ MAÑANA: bChat       │   ◀── el adaptador cambia de backend; bNotify no se entera
   │ (motor Rust propio) │
   └─────────────────────┘
```

La regla de diseño existente se mantiene: **hacia adentro, gRPC entre bNotify y adaptadores; lo que cada adaptador haga hacia afuera es su problema encapsulado.**

## 4. Workstream 1 — bNotify: definición doctrinal del daemon

### 4.0 Definición canónica — qué es, qué hace, cómo, para qué y para quién

> **En una frase:** bNotify es el sistema nervioso de distribución del ecosistema SBOS — todo lo que el sistema necesita hacerle llegar a un humano pasa por bNotify, que decide *a quién, por dónde y cuándo*, mientras las herramientas ejecutoras realizan la entrega y cada usuario conserva la soberanía sobre su recepción.

**QUÉ ES.** Un daemon de sistema permanente — proceso Rust gestionado por systemd en el host Ubuntu, par de bAuth, bPay y bCms — que constituye el **plano de distribución** del ecosistema. No es un canal (los adaptadores entregan), no es el bus (NATS transporta), no es la identidad (bAuth decide), no es el chat (el chat es su canal primario): es la pieza estable que está por encima de todas ellas y las hace intercambiables.

**QUÉ HACE.** Recibe *intents* — eventos de dominio de cualquier daemon ("se pagó la planilla", "código de acceso", "nuevo pedido") — y los convierte en entregas confirmadas: **multiplexa** (un evento → N destinatarios × M canales), resuelve **a quién** (usuario bAuth, rol/grupo organizacional, audiencia/tópico propio, o sala del chat), **por dónde** (el canal que las preferencias del destinatario y la prioridad del evento dicten, con failover chat → push → email → SMS), **cuándo** (respetando silencios, topes de frecuencia y ventanas de digest), y administra el ciclo de vida completo de cada notificación hasta la confirmación o la dead-letter, dejando trazabilidad de quién fue notificado, cuándo y por qué canal.

**CÓMO LO HACE.** Por contrato y por doctrina: gRPC sobre mTLS con daemons y adaptadores, cero REST (D4); identidad y membresías leídas "a la mano" por vistas del clúster compartido — bAuth y el chat como dueños, bNotify como lector (D18); validación de cada despacho contra bAuth como punto de aplicación (PEP) de las decisiones del punto de decisión (PDP) (D16); entrega delegada a herramientas ejecutoras independientes vía adaptadores — Dovecot el correo, Jasmin el SMS, FCM/APNs/UnifiedPush el push, el chat lo suyo (D17); idempotencia con entrega at-least-once y efectos exactly-once, colas por prioridad, reintentos con backoff y DLQ; contenido purgado tras su propósito, metadatos auditados en clases A/B/C (D11); y contención anti-fatiga como política de primera clase.

**PARA QUÉ.** Para que ningún daemon del ecosistema tenga que saber jamás cómo se llega a un ser humano — un solo contrato estable que: (1) hace intercambiables los canales (el reemplazo bRocket→bChat será invisible para todos los emisores); (2) garantiza que lo crítico llega — el OTP de un pago sale por SMS aunque el chat esté caído (D15); (3) protege la atención del usuario — sin bNotify, cada daemon spamearía por su cuenta y el ecosistema entrenaría a sus usuarios a ignorarlo; y (4) da al negocio la trazabilidad de cumplimiento: reconstruir qué se comunicó, a quién y por dónde.

**PARA QUIÉN.** Para dos clientes con necesidades opuestas que bNotify reconcilia: **los daemons emisores** (bAuth, bPay, bCms, bChat, los módulos) — que obtienen entrega confiable, multi-canal y auditada emitiendo un solo intent sin conocer ningún canal; y **las personas destinatarias** (usuarios, grupos, salas, operadores de guardia) — que reciben lo relevante por el canal que ellas eligieron, cuando corresponde, y administran su recepción con soberanía total desde su centro de preferencias: el emisor propone, bNotify gobierna, el usuario dispone.

### 4.1 Naturaleza: un daemon del host, par entre pares

bNotify es un **daemon nativo del host Ubuntu**, hermano de bAuth, bPay y bCms en la misma máquina/flota SBOS: un servicio de sistema gestionado por **systemd** (unidad con hardening estándar: usuario dedicado sin privilegios, `ProtectSystem`, `PrivateTmp`, capacidades mínimas, límites de recursos), escrito en Rust, que arranca con el host, se supervisa y reinicia por systemd, y conversa con sus pares exclusivamente por **gRPC sobre mTLS** (doctrina D4). No es un SaaS, no es una función serverless, no es una dependencia externa: es infraestructura propia del sistema operativo del ecosistema.

### 4.2 Papel: el multiplexor y administrador del ciclo de vida de toda notificación

bNotify **multiplexa** — un evento de dominio entra, N destinatarios × M canales salen — y **administra el ciclo de vida completo** de cada notificación. Este ciclo es hoy un patrón consolidado del sector, y bNotify lo adopta íntegro como su contrato de comportamiento:

```
INTENT (evento de dominio de cualquier daemon)
  → VALIDACIÓN + IDEMPOTENCIA (clave única; el duplicado es no-op)
  → RESOLUCIÓN DE DESTINATARIO (ctx_id → bAuth) y PLANTILLA (tipo, canal, idioma)
  → POLÍTICAS Y PREFERENCIAS (opt-outs, horas de silencio, topes de frecuencia, prioridad)
  → DESPACHO ORQUESTADO (uno o varios canales; failover y escalamiento entre canales)
  → SEGUIMIENTO POR INTENTO + RECONCILIACIÓN asíncrona del veredicto del proveedor
  → MÉTRICAS, TABLEROS Y AUDITORÍA (quién fue notificado, cuándo, por qué canal)
```

Responsabilidades normadas del daemon (cada una tendrá su contrato en BNOTIFY-010):

| Responsabilidad | Norma de comportamiento |
|---|---|
| Idempotencia | Toda ingesta lleva clave de idempotencia; entrega **at-least-once** con efectos exactly-once (el reintento jamás duplica ante el usuario) |
| Prioridades | Colas separadas por clase (un OTP no espera detrás de un resumen semanal), con objetivos de latencia distintos por clase |
| Centro de preferencias | Perfil de notificación por usuario: canales preferidos, opt-in/out por tipo, **horas de silencio por zona horaria**, topes de frecuencia, idioma |
| Digest/batching | Agrupación de notificaciones de baja prioridad en resúmenes por ventana configurable |
| Failover multi-canal | Si el canal preferido falla o no confirma, escalamiento al siguiente según política (push → chat → email → SMS) |
| Reintentos y DLQ | Backoff exponencial con tope; lo inentregable va a dead-letter con alarma, nunca se pierde en silencio |
| Anti-fatiga | La disciplina más difícil del sector es la **contención**: sin métricas de entrega/apertura y topes de frecuencia, el sistema entrena a los usuarios a ignorarlo. La contención es política de primera clase, no un ajuste posterior |
| Trazabilidad de cumplimiento | Reconstrucción completa de quién fue notificado, cuándo y por qué canal — eventos a `aud_event` con las clases A/B/C del doc. 07 (la notificación transaccional/de seguridad es clase A) |

### 4.3 Relación con bAuth: bNotify aplica, bAuth decide (D16)

Aclaración doctrinal para que nunca haya ambigüedad: cuando se dice que bNotify "administra usuarios y validación **junto a bAuth**", el reparto exacto es el del modelo PDP/PEP de las arquitecturas Zero Trust (NIST SP 800-207):

| Plano | Dueño | Contenido |
|---|---|---|
| **Decisión (PDP)** | **bAuth** | Identidad (idn_*), credenciales, sesión (ctx_id), átomos de permiso, dispositivos, KYC. bNotify **no posee usuarios ni valida credenciales jamás** |
| **Aplicación (PEP)** | **bNotify** | En cada despacho: valida el ctx_id del destinatario contra bAuth, verifica que el emisor (daemon) tiene el átomo para notificar ese tipo de evento, y consume eventos **CAEP** de bAuth (sesión revocada → suspender entregas a ese contexto; dispositivo desvinculado → invalidar su token de push) |
| **Dominio propio de bNotify** | bNotify | El **perfil de notificación** del usuario: preferencias, canales, tokens de dispositivo de push, horas de silencio, idioma de plantilla. Esto es legítimamente suyo — es configuración del plano de notificaciones, no identidad — siempre indexado por el UUID de bAuth, nunca por credenciales propias |

### 4.4 Cifrado: la responsabilidad criptográfica de bNotify

Compartida "junto a bAuth" con fronteras precisas: **en tránsito**, mTLS en todo gRPC entre daemons y hacia adaptadores (certificados de la CA interna del ecosistema, rotados; material de claves gestionado por el almacén de secretos del host, no en archivos de configuración); **en reposo**, los payloads pendientes de entrega se cifran, y por proporcionalidad (D11) **el contenido de una notificación no sobrevive a su propósito**: se purga tras la entrega confirmada + ventana de reintento (TTL); lo que persiste para auditoría son los metadatos de entrega, jamás el contenido. bNotify no implementa criptografía propia (D12): consume la del canal (TLS del SMTP/SMPP, el cifrado de FCM/APNs, Web Push RFC 8030 con VAPID RFC 8292) y la del ecosistema (mTLS, bAuth).

### 4.5 Lo que bNotify NO es (anti-definición)

1. **No es el bus de mensajes:** NATS transporta; bNotify decide. bNotify es un *consumidor inteligente* del bus, no su reemplazo.
2. **No es la identidad:** bAuth (D3, D16).
3. **No es un canal:** los adaptadores entregan; bNotify orquesta. Nunca habla SMTP, SMPP ni FCM directamente.
4. **No compone contenido de negocio:** los daemons emiten *intents* con datos; bNotify resuelve plantilla e idioma. La lógica de "qué decir" es del dominio emisor; la de "a quién, cómo, cuándo y por dónde" es de bNotify.
5. **No es interino:** bRocket y hasta bChat son piezas con ciclo de vida; bNotify es permanente — el contrato estable que hace intercambiables a todos los demás (D5).

### 4.6 Estándares y referencias adoptados

| Estándar / referencia | Papel en bNotify |
|---|---|
| CloudEvents (CNCF) | Formato de eventos en la frontera exterior (canal webhook) |
| RFC 8030 (Web Push) + RFC 8292 (VAPID) | Push a navegadores sin depender de Google/Apple |
| SMPP | Canal SMS (Jasmin/Kannel) |
| NIST SP 800-207 (Zero Trust: PDP/PEP) | Modelo de reparto bAuth↔daemons (§4.3, D16) |
| Shared Signals / CAEP (OpenID) | Consumo de eventos de sesión/dispositivo desde bAuth |
| OpenTelemetry | Trazas y métricas del pipeline de despacho |
| systemd (unidades con hardening) | Gestión del daemon en el host Ubuntu |
| Ciclo de vida unificado de notificación (patrón de industria) | Contrato de comportamiento de §4.2 |

### 4.7 Modelo de direccionamiento: audiencias de primera clase (resolución de la cuestión "¿bNotify debería ser el chat?")

Cuestión planteada y resuelta: dado que las notificaciones se dirigen a usuarios, grupos y salas, ¿debería bNotify ser el propio servidor de chat y tomar sus entidades como base? **Decisión: no — por D3 (la identidad es de bAuth, no del chat), D5/D7 (el chat es un canal intercambiable y hoy es interino; bNotify es permanente) y D15 (si el orquestador vive dentro del chat, la caída del chat mata también SMS y email — el OTP de bPay debe llegar aunque el chat esté caído).** La prueba práctica: no se puede enviar un SMS "a una sala" — toda sala se expande a miembros, y los miembros son UUIDs de bAuth; el denominador común del direccionamiento es la identidad, no la sala. Pero la intuición de fondo es correcta y se incorpora como dos piezas de primera clase:

**(a) Tipos de destino de una notificación** (contrato en BNOTIFY-001/010):

| Tipo de destino | Fuente de verdad | Resolución |
|---|---|---|
| Usuario | bAuth (UUID/ctx_id) | Directa |
| Rol / grupo organizacional | bAuth (átomos, roles, tenant) | bNotify consulta bAuth y expande a UUIDs |
| Audiencia / tópico | **bNotify** (listas de suscripción propias: "operadores de guardia", "clientes del comercio X") | Dominio legítimo de bNotify, indexado por UUIDs de bAuth |
| **Destino nativo de canal** (una sala/grupo de chat, una lista de correo) | El canal dueño (bChat/bRocket, Dovecot) | Resolución **en el momento del despacho** vía RPC al adaptador: "expande la sala Z a miembros" o "entrega a la sala Z con tu mecánica propia (menciones, no-leídos)". bNotify jamás duplica salas — la copia se desincroniza; la fuente de verdad de cada dominio se consulta, no se replica |

**(b) Primacía de superficie del chat, sin propiedad de infraestructura:** el chat es el **canal primario y superficie por defecto** del ecosistema — la bandeja de notificaciones que el usuario ve vive en bChat, el orden de failover lo tiene primero (chat → push → email → SMS según política), y las demás herramientas se *experimentan* desde el chat (módulos B.4). Esa es la verdad de producto que la cuestión señalaba. La verdad de infraestructura es la inversa: el chat es un canal más del orquestador, para que su ciclo de vida (bRocket→bChat) y sus caídas jamás arrastren al resto. Y la independencia del usuario queda donde corresponde: en el **centro de preferencias** (§4.2), donde cada quien administra sus canales, silencios y frecuencias como mejor considere.

**(c) Topología de datos del direccionamiento (D18):** bNotify comparte el clúster PostgreSQL del ecosistema y lee por **vistas de solo lectura**: identidad y roles desde el esquema de bAuth (que Dovecot también consume de forma nativa vía su lookup SQL de usuarios — configuración estándar de Dovecot, no desarrollo), y membresías de salas/grupos desde el esquema del chat, porque la sala ya sabe quiénes son sus miembros: un conjunto de UUIDs de bAuth. El fan-out se expande en SQL, sin RPC ni réplicas. **Salvedad temporal:** bRocket guarda sus salas en MongoDB, fuera del clúster — durante el interinato la expansión de salas va por el adaptador de chat (RPC), y migra a vista nativa cuando exista el esquema `bchat`. Lo que bNotify controla como dueño en su propio esquema: sus **canales de distribución, audiencias/tópicos y la asignación de grupos/salas como destinos** — nunca la identidad (bAuth) ni la conversación (chat).

**(d) Patrón herramienta-ejecutora (D17):** el mismo modelo de audiencias sirve a todo el ecosistema — bNotify direcciona hacia la audiencia y una herramienta independiente ejecuta el acto de dominio: Dovecot entrega el correo (grupal, individual o por sala) pero no administra la recepción de nadie; bPay ejecuta los pagos direccionados a un grupo (la planilla) pero no administra la billetera individual de nadie. La individualidad del usuario — su buzón, su billetera, sus preferencias — queda siempre de su lado, administrada por él en el centro de preferencias (§4.2).

### 4.8 Alcance v1 y stack

| Aspecto | Definición |
|---|---|
| Alcance v1 | Ciclo de vida completo de §4.2 con canales chat (bRocket), email y SMS; PEP contra bAuth; trazabilidad a aud_event |
| Contrato | BNOTIFY-001 (gRPC orquestador↔adaptadores) — primer entregable del programa |
| Stack | Rust (Tokio/Tonic), PostgreSQL (preferencias, plantillas, log de despacho), NATS/JetStream (ingesta), Redis (dedupe/rate), systemd |
| Canales v1 | chat (bRocket), email (Postfix/Dovecot), SMS (Jasmin/Kannel). Push y webhook: BNOTIFY-014/015 |

## 5. Workstream 2 — bRocket (interino, sin fork)

**Decisión clave que simplifica todo lo anterior:** al usar Rocket.Chat **sin modificar**, desaparecen del camino crítico el whitelabel, la eliminación de `ee`, el rebranding de clientes, la publicación en tiendas y el mantenimiento de fork (docs 01–05 quedan como referencia). bRocket queda **congelado por decisión: ni personalización ni actualizaciones** — se usa tal como está, en la versión fijada, mientras se construye bChat.

| Tema | Definición |
|---|---|
| Despliegue | Docker/K8s, monolito CE, MongoDB 8.x replica set, S3/MinIO para medios, Jitsi self-hosted para video |
| Identidad | Login delegado en bAuth vía **OIDC custom** (capacidad estándar de RC por configuración). **Bloqueante:** especificar la superficie OIDC de bAuth en D9 (`authorize/token/userinfo/jwks`) — ya identificado en SBOS-0XX §2; es el primer pendiente de bAuth del programa |
| Rol | Canal chat de bNotify (el adaptador publica mensajes vía REST/webhook de RC) + chat de uso interno del ecosistema |
| Límites aceptados (por ser CE sin fork) | Push móvil por el gateway de Rocket.Chat con tope mensual del plan gratuito; features premium ausentes; escala acotada al monolito. **Aceptable porque el público de bRocket es interno/acotado, no consumo masivo** — el consumo masivo es de bChat |
| Verificación pendiente | Confirmar en la instancia real que OIDC custom self-hosted opera pleno en CE 8.x (tarea ya listada en SBOS-0XX §9) |
| Política de versión (decisión R-3) | **Congelamiento total:** versión fijada, sin actualizaciones ni personalizaciones. Consecuencia asumida: los CVE que el upstream corrija quedan abiertos en la instancia. **Controles compensatorios obligatorios:** bRocket opera solo en la red interna/VPN del ecosistema, jamás expuesto a internet público; monitoreo de avisos de seguridad del upstream; válvula única documentada — ante CVE crítico explotable en la red propia, se evalúa aplicar el hotfix de parche (misma versión menor, drop-in) como excepción aprobada |
| Fin de vida | bRocket se apaga cuando bChat alcance el hito de paridad interna (§6, Gate G3). Nada se construye *sobre* bRocket: cero apps-engine propias, cero personalizaciones — solo configuración. Todo lo que se quiera construir, se construye en bChat |

## 6. Workstream 3 — bChat (motor propio, destino WeChat)

### 6.1 Stack y principios
Rust (Axum/Tokio), PostgreSQL (esquema propio de mensajería: salas, mensajes, membresías, offline-queue, búsqueda FTS), NATS (eventos internos y hacia bNotify/aud), Redis (presencia/sesiones calientes), S3 (medios), **Jitsi como motor de video por adaptador delgado (sala+JWT — patrón validado; no se construye SFU propio)**, cliente **Flutter** único (Android/iOS/desktop/web), identidad y autorización **nativas** sobre bAuth (átomos + ctx_id, sin capa de traducción — la ventaja estructural sobre cualquier fork), Fuselage solo como **referencia visual** de design system (nada de su código es reutilizable en Flutter — verificado).

### 6.2 Fases de bChat (con estimaciones honestas)

| Fase | Alcance | Estimación (equipo actual) |
|---|---|---|
| **C1 — MVP mensajería** | 1:1 y grupos, texto+medios, entrega offline, sincronización multi-dispositivo, push (canal bNotify), cliente Flutter básico | 4–8 meses. Los subsistemas duros ya identificados: pub/sub de deltas, reconexión/reconciliación, cola offline, paginación/búsqueda — muchas piezas correctas que deben funcionar juntas |
| **C2 — Paridad interna** | Presencia, hilos, reacciones, búsqueda, video vía Jitsi, read receipts (nativos, no premium de nadie), administración. **Gate G3: bRocket se apaga; migración de usuarios/historial** | +4–6 meses |
| **C3 — Plataforma** | Motor de **formularios** (definidos como datos, renderizados por Flutter, respuestas como eventos al bus), **mini-aplicaciones** (catálogo de apps del ecosistema autorizadas por átomos bAuth, superficie embebida en el cliente), enganche con bPay | +6–12 meses |
| **C4 — Correo integrado** | Ver §6.3 | según opción |
| **C5 — Grado consumo masivo** | E2EE, anti-abuso/moderación (átomos ya especificados en doc. 07), objetivos de capacidad del doc. 04 §2 con pruebas de carga, hardening | El salto de "usable por SBOS" a "WeChat para el público" es trabajo de equipo por años, no de meses — se planifica formalmente al cerrar C3, con la matriz de paridad como criterio |

### 6.3 Correo dentro de bChat (decisión C4 en dos etapas)
- **Etapa 1 — incrustar Roundcube:** vista web embebida en el cliente Flutter con SSO bAuth contra el stack ya resuelto (Postfix/Dovecot). Costo bajo, entrega rápida, UX aceptable de arranque. Roundcube es GPL — al usarse como servicio web propio *no incrustado en el binario* no contamina la licencia de bChat; verificación formal en el gate.
- **Etapa 2 — cliente nativo:** módulo de correo Flutter contra IMAP/JMAP (evaluar en su momento servidor con JMAP para UX moderna), reutilizando el patrón visual de bChat. Solo si la etapa 1 se queda corta en experiencia — decisión por datos de uso, no por preferencia.

## 7. Roadmap consolidado del programa

| Hito | Contenido | Gate de decisión |
|---|---|---|
| **G0** (semanas 0–4) | Contrato gRPC bNotify↔adaptadores v1 · superficie OIDC de bAuth (D9) especificada · bRocket desplegado | ¿OIDC CE verificado en la instancia real? |
| **G1** (meses 1–3) | bNotify v1 en producción con canales chat+email+SMS · bRocket integrado a bAuth y operando como canal | ¿Entrega y trazabilidad de notificaciones medidas? |
| **G2** (meses 3–12) | bChat C1 (MVP) en dogfooding interno paralelo a bRocket | ¿MVP estable multi-dispositivo? |
| **G3** | bChat C2 · migración y apagado de bRocket | ¿Paridad interna demostrada? |
| **G4** | bChat C3 (formularios + mini-apps + bPay) | ¿Plataforma con primeras apps reales? |
| **G5** | Decisión de salto a consumo masivo (C5) con plan de equipo y capital | ¿El ecosistema lo justifica? |

## 8. Registro de riesgos del programa

| # | Riesgo | Mitigación |
|---|---|---|
| R1 | Nombre "bRocket" en uso público (marca) | Regla §2: codename interno; renombrar si se expone |
| R2 | OIDC D9 de bAuth se demora y bloquea la integración de bRocket | Es el primer entregable G0; bRocket puede arrancar con auth local temporal solo para pruebas |
| R3 | Construir "mientras tanto" sobre bRocket (apps, personalizaciones) que luego se tira | Prohibición explícita §5: en bRocket solo configuración |
| R4 | Subestimar C1/C2 (el error "semanas para MVP"): los subsistemas de sincronización son la dificultad real, no ninguna pieza aislada | Estimaciones de §6.2 + gates por demostración, no por fecha |
| R5 | bChat C5 (consumo masivo) requiere equipo que hoy no existe | G5 es gate de capital/equipo, no técnico; documentado desde ya |
| R6 | Dependencia MongoDB/Meteor de bRocket como isla en el stack | Aceptada por ser interina; se extingue en G3 |
| R7 | Licencia GPL de Roundcube en la integración | Patrón de servicio separado (§6.3) + verificación en gate C4 |

## 9. Reorganización del set documental

- **Este documento (08)** es la carta rectora del programa.
- **Docs 01–05 (estrategia fork):** archivados como referencia — el fork queda descartado; su contenido técnico (K8s, inventario ee/clientes, análisis de licencias) sirve como insumo de la matriz de paridad de bChat.
- **Doc 06 (bAuth↔chat):** vigente, reinterpretado: el patrón OIDC/aprovisionamiento aplica a bRocket hoy y a bChat nativo mañana (sin capa de traducción).
- **Doc 07 (incrementos bAuth):** vigente casi íntegro — átomos de mensajería, clases de auditoría A/B/C, KYC tiers, perfil de sesión de consumo y conector son requisitos de bChat (y parcialmente de bRocket vía OIDC).
- **SBOS-0XX (bNotify):** documento madre del workstream 1; actualizar en v0.6: corrección de llamadas (desde RC 8.0 la *voz* es motor WebRTC propio con historial y SIP — solo el *video* grupal sigue delegado a Jitsi) y la decisión de nombres de este documento.


## 10. Secuencia documental BNOTIFY-0XX — el plan de implementación del proyecto

> Consumar el proyecto = producir, aprobar e implementar estos documentos en orden. Cada uno es un **contrato**: se redacta bajo la doctrina §0, se versiona, se aprueba en su gate, y solo entonces se codifica. La numeración deja huecos por bloque para insertar documentos futuros sin renumerar.

**Convención:** `BNOTIFY-0XX-NOMBRE.md` · estados: `BORRADOR → EN REVISIÓN → APROBADO → IMPLEMENTADO → OBSOLETO` · todo documento declara: código, versión, gate, dependencias, principios de doctrina que ejerce, y criterio de "implementado".

### 10.0 Adecuación para desarrollo con agentes de IA

Este proyecto se construirá con agentes de IA como fuerza de implementación. Eso convierte a la documentación en el **entorno operativo de los agentes**, no solo en registro humano — y el estado del arte 2026 (spec-driven development, el estándar abierto AGENTS.md leído hoy nativamente por Claude Code, Codex, Cursor, Copilot, Gemini CLI y demás, los registros de decisión ADR/MADR y los índices legibles por máquina tipo llms.txt) dicta reglas precisas que se adoptan como parte de la gobernanza:

1. **Front-matter legible por máquina en todo documento BNOTIFY:** encabezado YAML con `codigo, version, estado, gate, depende_de, doctrina_que_ejerce, criterio_implementado`. Un agente debe poder resolver el grafo documental sin leer prosa.
2. **El agente entra por dos puertas, siempre:** la doctrina (§0) y el **navegador de documentos** (BNOTIFY-005). Ningún agente trabaja "a ciegas" sobre el repositorio.
3. **Capacidades, no rutas:** los documentos describen *qué hace* cada pieza y su vocabulario de dominio, no árboles de archivos — las rutas cambian y la estructura desactualizada envenena el contexto del agente; el vocabulario de dominio es estable.
4. **Curaduría humana obligatoria:** los archivos de contexto para agentes los escribe y revisa un humano — la evidencia del sector muestra que los generados por LLM degradan el desempeño del agente y suben el costo; los curados por humanos lo mejoran. Se versionan como código: cambio de convención = actualización en el mismo commit.
5. **AGENTS.md breve y jerárquico:** raíz ≤150 líneas, comandos primero (build, test, verificación), un AGENTS.md anidado por crate/módulo (el más cercano manda), `CLAUDE.md` como symlink para compatibilidad total. Enlaza a los BNOTIFY-0XX; jamás los duplica.
6. **Ciclo spec-driven por documento:** cada BNOTIFY-0XX aprobado se descompone en `spec → plan → tareas` ejecutables por agente, y ninguna tarea se cierra sin **prueba objetiva**: tests en verde, lint/tipos, diff confinado a rutas acordadas, y prueba de carga cuando la doctrina D9 aplique. La "definición de terminado" es verificable por máquina, no por opinión.
7. **Toda desviación es un ADR:** si durante la implementación un agente (o humano) necesita apartarse de un documento aprobado, el cambio nace como registro de decisión en BNOTIFY-007, nunca como código silencioso (extensión natural de la regla de enmienda de §0).

### Bloque 005–009 — Capa para agentes de IA (gate G0, junto a la fundación)

| Código | Documento | Qué establece como contrato | Depende de |
|---|---|---|---|
| BNOTIFY-005 | NAVEGADOR-DE-DOCUMENTOS | El índice maestro legible por humano y máquina (patrón llms.txt): lista viva de todos los BNOTIFY-0XX con estado, resumen de una línea, grafo de dependencias y "por dónde empezar" según la tarea. **Se actualiza en el mismo commit que cualquier documento** — un navegador desactualizado es peor que ninguno | 000 |
| BNOTIFY-006 | STACK-TECNOLOGICO | La lista canónica y **fijada por versión** de todo el stack: Rust/toolchain, Tokio/Tonic/Axum, PostgreSQL, NATS/JetStream, Redis, LiveKit, wasmtime, Flutter/SDKs, OpenMLS/mls-rs, systemd, herramientas de CI y carga (k6). Un agente jamás elige versión ni librería por su cuenta: consulta aquí; agregar dependencia = ADR | 000 |
| BNOTIFY-007 | ADR-REGISTRO-DE-DECISIONES | El registro de Architecture Decision Records (formato MADR: contexto → opciones → decisión → consecuencias), retro-documentando las decisiones ya tomadas en esta doctrina como ADR-001…N (cero REST, LiveKit sobre Jitsi, MLS, clúster compartido por esquemas, módulos sin recompilar, bRocket congelado…) y recibiendo toda decisión futura. Inmutable: una decisión se supersede con otro ADR, no se edita | 000 |
| BNOTIFY-008 | DDL-ESQUEMAS-DE-DATOS | El DDL versionado del clúster (D18): esquema por dueño (`bauth`, `bnotify`, `bchat`, correo), las **vistas de solo lectura cruzadas** con sus GRANTs exactos, convenciones (UUIDs bAuth, particionado, tipos), y migraciones como código (sqlx/refinery). Es el contrato de datos que los agentes consultan antes de tocar cualquier tabla | 000, 002 |
| BNOTIFY-009 | GLOSARIO-Y-ONTOLOGIA | El vocabulario de dominio estable del ecosistema (ctx_id, átomo, intent, audiencia, canal, adaptador, módulo, herramienta ejecutora, tier, clase de auditoría A/B/C…), con definición de una línea y documento de referencia. Es el anti-alucinación de los agentes: los conceptos de dominio son más estables que cualquier ruta de archivo | 000 |

**Artefactos de repositorio (no son documentos BNOTIFY, viven como archivos en la raíz y por crate):** `AGENTS.md` raíz (≤150 líneas, comandos primero) + anidados por crate + symlink `CLAUDE.md`; plantillas `spec/plan/tareas` por documento; y los hooks de verificación de CI que hacen ejecutable la "definición de terminado" del punto 6.


### Bloque 00X — Fundación (gate G0)

| Código | Documento | Qué establece como contrato | Depende de |
|---|---|---|---|
| BNOTIFY-000 | DOCTRINA-Y-PLAN-MAESTRO | Este documento: doctrina, arquitectura, gates, anexos A/B | — |
| BNOTIFY-001 | CONTRATO-GRPC-ORQUESTADOR-ADAPTADORES | El payload de evento común independiente del canal (proto): identidad del evento, ctx_id destinatario, plantilla+datos, urgencia, canales candidatos, TTL; respuesta de entrega, reintentos/backoff, dead-letter. **Primer artefacto técnico del proyecto** | 000 |
| BNOTIFY-002 | BAUTH-OIDC-SUPERFICIE-D9 | Endpoints authorize/token/userinfo/jwks de bAuth como IdP; emisión CAEP; perfil de sesión CONSUMER_MOBILE. Desbloquea bRocket y define el login de todo lo demás | 000 |
| BNOTIFY-003 | BROCKET-DESPLIEGUE-INTERINO | RC CE 8.x en K8s: MongoDB 8.x replica set, S3, Jitsi, livechat activado, OIDC contra bAuth verificado, límites CE aceptados y documentados, regla D7 (solo configuración) | 001, 002 |
| BNOTIFY-004 | MODELO-EVENTOS-Y-AUDITORIA | Taxonomía de eventos (chat.*, notify.*, identity.*), clases de auditoría A/B/C, pipeline hacia aud_event/lotes Merkle (incorpora doc. 07) | 001 |

### Bloque 01X — bNotify núcleo y canales (gates G1–G2)

| Código | Documento | Qué establece | Depende de |
|---|---|---|---|
| BNOTIFY-010 | NUCLEO-ORQUESTADOR | Motor Rust: resolución destinatario/preferencias/idioma/urgencia por ctx_id, plantillas multi-canal, deduplicación, rate, DLQ, esquema PostgreSQL propio | 001, 002, 004 |
| BNOTIFY-011 | CANAL-CHAT | Adaptador chat: hoy contra bRocket (REST/webhook de RC encapsulado — única excepción HTTP, muere con bRocket), mañana contra bChat (gRPC nativo) | 003, 010 |
| BNOTIFY-012 | CANAL-EMAIL | Adaptador Postfix/Dovecot; plantillas; decisión Roundcube vs Nextcloud Mail | 010 |
| BNOTIFY-013 | CANAL-SMS | Adaptador Jasmin/Kannel vía SMPP, solo salida | 010 |
| BNOTIFY-014 | CANAL-PUSH | FCM/APNs alta prioridad con credenciales propias, PushKit/CallKit (llamadas iOS), UnifiedPush/ntfy (Android soberano), registro de device tokens vía bAuth D9 | 002, 010 |
| BNOTIFY-015 | CANAL-WEBHOOK-EXTERIOR | Frontera con terceros: CloudEvents sobre HTTP, firma, reintentos — el único lugar del sistema donde vive HTTP | 010 |

### Bloque 03X — bChat motor y clientes (gates G2–G3)

| Código | Documento | Qué establece | Depende de |
|---|---|---|---|
| BNOTIFY-030 | BCHAT-PROTOCOLO-CLIENTE | **El documento más difícil del proyecto:** WS + JSON-RPC 2.0, suscripciones, deltas, reconciliación multi-dispositivo, cola offline, paginación. Se redacta con prototipo de validación | 000, 004 |
| BNOTIFY-031 | BCHAT-ESQUEMA-DATOS | PostgreSQL: salas, mensajes, membresías, particionado, FTS (pg_trgm), retención | 030 |
| BNOTIFY-032 | BCHAT-MOTOR-RUST | Axum/Tokio, NATS/JetStream, presencia, integración bAuth nativa (átomos, ctx_id, step-up), modelo de capacidad | 030, 031 |
| BNOTIFY-033 | BCHAT-CLIENTE-FLUTTER | Un código base (Android/iOS/desktop/web), Material 3 + tokens propios (Fuselage como referencia visual), notify integrado estilo WhatsApp | 030 |
| BNOTIFY-034 | BCHAT-MEDIA | Pipeline de medios: S3+CDN, miniaturas, límites por tier | 032 |
| BNOTIFY-035 | BCHAT-LIVEKIT | Llamadas 1:1, voz, y **salas de reuniones tipo Meet** (grilla, pantalla, lobby, enlaces persistentes, bCalendar) sobre SDK LiveKit | 032, 033 |
| BNOTIFY-036 | MIGRACION-BROCKET-A-BCHAT | Usuarios (vía bAuth, trivial por D3), historial, doble-corrida, apagado de bRocket — ejecuta el gate G3 | 032, 033 |

### Bloque 04X — Sistema de módulos y módulos first-party (gates G3–G4)

| Código | Documento | Qué establece | Depende de |
|---|---|---|---|
| BNOTIFY-040 | MODULOS-MANIFIESTO-Y-CATALOGO | **Segundo contrato fundacional:** esquema del manifiesto (identidad, permisos-átomos, plantillas UI, endpoints, eventos), registro RPC, catálogo versionado, apertura automática en clientes, gobernanza y revisión | 030, 032 |
| BNOTIFY-041 | MODULOS-RUNTIME-WASM | wasmtime embebido: capacidades, sandbox, ciclo de carga en caliente, límites de recursos | 040 |
| BNOTIFY-042 | MODULO-ATENCION-CLIENTE | La bandeja omnichannel first-party (cola, agentes, transferencias, enlatadas, métricas, widget web) — **estrena y valida toda la maquinaria de módulos** | 040 |
| BNOTIFY-043 | MODULOS-MOTOR-FORMULARIOS | Formularios/flujos declarativos (rfw/JSON-RPC): definición, render, respuestas como eventos | 040 |
| BNOTIFY-044 | MODULO-CORREO | Etapa 1 Roundcube embebido con SSO bAuth; etapa 2 cliente nativo (IMAP/JMAP) por datos de uso | 040, 012 |
| BNOTIFY-045 | MODULOS-TERCEROS-Y-MARKETPLACE | Apertura del catálogo a terceros: proceso de revisión, versionado, revocación (el "mini-programs" de C4) | 040, 041, 042 |

### Bloque 06X — Grado consumo (gate G5)

| Código | Documento | Qué establece | Depende de |
|---|---|---|---|
| BNOTIFY-060 | E2EE-MLS | MLS/RFC 9420 con OpenMLS o mls-rs: delivery service propio (key packages, welcome, commits), multi-dispositivo, plan de auditoría externa | 030, 032 |
| BNOTIFY-061 | ANTIABUSO-Y-MODERACION | Átomos y REGLA del doc. 07 (§1), strikes, workflow de reportes, rendición de cuentas de moderadores (WORM) | 004, 042 |
| BNOTIFY-062 | KYC-TIERS-Y-VALOR | Niveles T0/T1/T2 acoplados a límites D3; integración bPay en conversación | 002, doc. 07 §2 |

### Bloque 07X–09X — Transversales

| Código | Documento | Qué establece | Depende de |
|---|---|---|---|
| BNOTIFY-070 | CAPACIDAD-Y-PRUEBAS-DE-CARGA | Objetivos numéricos por componente (doctrina D9), pipeline k6/Gatling en CI, modelos de capacidad publicados | 000 |
| BNOTIFY-071 | OPERACIONES-K8S | Despliegue, observabilidad (Prometheus/Grafana), runbooks, respaldos, secretos | 000 |
| BNOTIFY-090 | GOBERNANZA-DOCUMENTAL-Y-DE-AGENTES | Esta convención completa: plantilla de documento con front-matter YAML, estados, versionado, proceso de enmienda de la doctrina, el ciclo spec→plan→tareas por documento, la definición de terminado verificable por máquina, y las reglas de trabajo de los agentes (§10.0) | 000, 005 |

**Orden de arranque (G0):** primero la capa que habilita a los agentes — BNOTIFY-005 (navegador), 090 (gobernanza), 006 (stack), 007 (ADRs retro-documentados), 009 (glosario) son cortos y multiplican la productividad de todo lo demás; en paralelo, los contratos técnicos BNOTIFY-001 → 002 → 003, y el 008 (DDL) apenas el 002 defina las vistas de bAuth. Con esa base, cada documento siguiente se redacta, descompone en spec→plan→tareas y se implementa por agentes bajo verificación objetiva.


---

## Anexo A — La meta: WeChat hoy (2026) vs proyección bChat

WeChat es la referencia de qué significa "súper-app" llevada a su máximo. Datos actuales (fuentes: Tencent, Business of Apps, guías de plataforma 2026): ~1.410 millones de usuarios activos mensuales y más de 79 minutos diarios de uso (≈35% del tiempo móvil en China); WeChat Pay con ~935 millones de usuarios y picos históricos de más de mil millones de transacciones diarias; Mini Programs con ~945 millones de usuarios mensuales (~410 millones diarios), millones de mini-programas activos y un GMV anual del orden de los cientos de miles de millones de dólares; en 2026 Tencent empuja IA en mini-programas (créditos de cómputo, pagos virtuales en iOS, analítica gratuita). La tabla define qué de eso es meta de bChat, en qué fase, y qué se descarta conscientemente:

| Capacidad de WeChat hoy (2026) | Qué es exactamente | Meta bChat | Fase |
|---|---|---|---|
| Mensajería núcleo + notas de voz (hábito dominante) + llamadas voz/video integradas | El centro de la app; todo lo demás se cuelga de la conversación | Paridad completa (voz/video vía Jitsi) | C1–C2 |
| Escala: 1.41B MAU, 79 min/día | Efecto de red nacional total | **Meta proporcional, no absoluta:** dominio del ecosistema SBOS primero; mercado boliviano después (objetivos numéricos del doc. 04 §2: 500k→5M registrados) | C2→C5 |
| WeChat Pay: QR, P2P, 935M usuarios, sobres rojos, pago de servicios | El dinero vive dentro del chat; identidad = método de pago | Integración **bPay** + QR interbancario boliviano; sobres/regalos como feature cultural adaptable | C3 (gancho) → C5 (masivo) |
| Mini Programs: apps sin instalación dentro del chat (framework propio WXML/WXSS, WeChat Login, pagos integrados) | La jugada maestra: WeChat como sistema operativo; los negocios ya no publican apps propias | **Sí — objetivo central de C3:** catálogo de mini-apps del ecosistema, permisos por átomos bAuth, identidad bAuth Login, pagos bPay. SDK propio (definir: Flutter embebido vs web-view controlada) | C3–C4 |
| Official Accounts (cuentas de negocio/contenido) | Canal editorial + servicio + CRM de marcas dentro del chat | Cuentas de negocio con catálogo y mensajería de servicio | C3 |
| Formularios/flows dentro del chat (equivalente: WhatsApp Flows) | Interacción estructurada sin salir de la conversación | Motor de formularios propio (datos → widgets Flutter → eventos al bus) | C3 |
| Correo NO existe en WeChat | — | **Diferenciador bChat:** correo integrado (Roundcube embebido → cliente nativo) | C4 |
| Moments (feed social) y Channels (video corto) | Capa social/entretenimiento | **Descartado conscientemente en el horizonte actual** — bChat prioriza utilidad (mensajes+pagos+apps); el feed social es otra guerra (Meta/TikTok) | — |
| Servicios de ciudad/gobierno, IA asistente, comercio livestream | Capas maduras de un ecosistema de 15 años | Horizonte post-C5 (trámites Bolivia sería el equivalente natural) | Futuro |

Lectura honesta del anexo: WeChat tardó ~15 años y decenas de miles de ingenieros. La proyección de bChat no es "alcanzar a WeChat" en absoluto — es **replicar su arquitectura de valor** (conversación + dinero + apps de terceros sobre una identidad única) a la escala del mercado propio, con bAuth/bPay/bNotify como la ventaja estructural que WeChat no regala a nadie: ser dueños del plano de identidad y pagos.

### A.1 — Frontera de producto (definición de identidad de bChat)

> **bChat es una herramienta de negocios: transferencia de valor económico y procesamiento de datos empresariales sobre una conversación. No es un producto de entretenimiento ni un soporte publicitario.**

| Dimensión | WeChat | bChat (decisión de producto) |
|---|---|---|
| Economía en la que compite | Atención **y** transacción (feed, video, inventario de anuncios en Moments/cuentas/mini-programas) | **Solo transacción.** Sin feed algorítmico, sin video de entretenimiento, sin inventario publicitario |
| Publicidad explícita (espacios de anuncios, CPM) | Sí, línea de ingresos central | **Prohibida por diseño.** No existe el concepto de "anuncio" en la plataforma |
| Mecánica comercial permitida | Ambas | **Disimulada en la relación de negocio:** promociones, descuentos y posicionamiento que una cuenta de negocio ofrece a *sus propios* clientes/seguidores, dentro de su canal — el usuario la recibe porque tiene relación con ese negocio, no porque un algoritmo vendió su atención |
| Modelo de ingresos | Publicidad + comisiones + servicios | Comisiones transaccionales (bPay), herramientas empresariales (cuentas de negocio, formularios, mini-apps, analítica de la propia empresa), servicios del ecosistema |
| Núcleo funcional | Comunicación + entretenimiento + comercio | **Conversar · transferir valor · procesar datos empresariales** (formularios, flujos de trabajo, mini-apps de negocio) |
| Consecuencia sobre datos | El modelo publicitario exige perfilar al usuario | **Sin incentivo estructural de vigilancia:** coherente con la proporcionalidad de auditoría (doc. 07 §3.3 — metadatos sí, contenido no) y la soberanía del ecosistema SBOS. La frontera de producto y la ética de datos se refuerzan mutuamente |

Regla de gobernanza derivada: cualquier propuesta futura de funcionalidad se evalúa contra esta frontera — si su valor depende de capturar atención o de vender espacios de exposición no solicitada, está fuera de bChat, sin excepción por atractivo comercial de corto plazo.

## Anexo B — Anatomía de Rocket.Chat "destripado": qué tiene adentro, qué hace bChat con cada pieza, y cuál es la mejor rueda existente hoy

### B.0 Principio rector: no reinventar la rueda — en ambas direcciones

Ni construir lo que ya existe maduro, ni conservar lo viejo por inercia. Bajo ese principio, **esto es lo mejor de Rocket.Chat que SÍ rescatamos** (como patrones y herramientas, nunca como código):

1. **Negociación de capacidades cliente↔servidor:** el cliente pregunta al conectarse qué está habilitado y construye su interfaz según la respuesta. Es el patrón de feature-gating que bChat adopta desde el día 1 (con átomos bAuth como fuente de verdad).
2. **Permisos declarados por app:** cada app del Apps-Engine declara en su manifiesto qué permisos necesita antes de instalarse. Ese contrato explícito es la base correcta para las mini-apps de C3.
3. **Mensajes interactivos por bloques declarativos** (su UIKit, estilo Slack Block Kit): la UI dentro del mensaje se describe como datos, no como código — el antecedente directo del motor de formularios de bChat.
4. **El concepto omnichannel** (no el módulo): la "bandeja de negocio" donde varios empleados atienden las conversaciones de una misma cuenta — exactamente lo que las cuentas de negocio de bChat necesitarán en C3 (ver B.3).
5. **El patrón adaptador delgado para video:** el chat no procesa media; genera sala + token y delega al motor especializado.
6. **Todo configurable en caliente:** los settings como datos modificables en runtime, no como constantes compiladas.
7. **Las herramientas externas que ya validó por nosotros:** S3 para medios, NATS como bus — y su elección de Jitsi, que hoy superamos con algo mejor (ver tabla).

### B.1 Regla de comunicación: CERO REST en el núcleo

> **Si se reconstruye, se reconstruye moderno: el núcleo de bChat no habla REST.**

| Tramo | Protocolo |
|---|---|
| Daemon ↔ daemon (bNotify, bAuth, bPay, bChat-Engine) | **gRPC** (Rust: tonic) — contratos tipados, streaming bidireccional |
| Cliente Flutter ↔ bChat-Engine | **WebSocket persistente con JSON-RPC 2.0** (el modelo Tryton) + canal de eventos/deltas por la misma conexión |
| Frontera con el mundo exterior (webhooks de terceros, pasarelas, tiendas) | Vive en los **adaptadores de borde de bNotify** (CloudEvents sobre HTTP) — el mundo exterior habla HTTP porque no le queda otra; el núcleo jamás |

Nota honesta de ingeniería: Flutter nativo habla gRPC sin problema; en Flutter web el gRPC puro no pasa por el navegador — la vía cliente es el WebSocket+JSON-RPC de todos modos, así que la regla se sostiene en todas las plataformas sin excepción.

### B.2 Tabla anatómica con veredicto y "lo mejor hoy (2026)"

| Pieza dentro de Rocket.Chat | Qué es, en vulgar | Veredicto para bChat | **Lo mejor hoy — ¿rueda existente o construcción propia?** |
|---|---|---|---|
| **Meteor + Node.js** (el chasis) | El framework que arranca todo y sincroniza datos "por magia"; esa magia es la razón de que sus clientes no sirvan con otro backend | NO se reutiliza | **Rust + Axum/Tokio** sigue siendo la elección moderna correcta; no hay rueda superior |
| **MongoDB** (la memoria) | Donde vive todo; las réplicas se coordinan espiando el registro de cambios de la base | NO | **PostgreSQL** (particionado nativo, replicación lógica) es hoy la respuesta estándar para chat+dinero; confirmado |
| **DDP/WebSocket + Minimongo** (el sistema nervioso) | Protocolo propio de Meteor: el cliente "se suscribe" y el servidor empuja cambios | NO el protocolo; SÍ la lección | **No existe rueda completa** para el protocolo de sincronización de un mensajero — cada grande construye el suyo. Lo que sí existe: JSON-RPC 2.0 como formato (Tryton), el diseño de sync de Matrix como referencia pública de estudio, y servidores de fan-out WebSocket open source (ej. Centrifugo) evaluables para la capa de difusión. La lógica de deltas/reconciliación es construcción propia — es EL subsistema difícil de C1 |
| **REST API** (la puerta formal) | Cómo se administra y opera desde fuera | **NO — prohibido por regla B.1** | gRPC interno + JSON-RPC 2.0/WS a clientes. bNotify es el primer consumidor gRPC |
| **Cuentas Meteor + OAuth + roles + ABAC (premium 8.0)** | Su login y permisos; el ABAC por atributos es su joya enterprise reciente | NO — reemplazado con ventaja | **bAuth** (átomos + ctx_id) ya es más expresivo que su ABAC premium; superficie estándar OIDC + CAEP. Aquí la rueda es nuestra |
| **Apps-Engine** (apps internas) | Código de terceros en caja de arena dentro del chat (hoy corre sobre runtime **Deno**, ya no el módulo VM de Node) | NO el motor; SÍ el patrón de permisos declarados | **Arquitectura de módulos estilo Tryton (ver B.4):** el motor de bChat **jamás se recompila** — las mini-apps se anexan en caliente por **manifiesto declarativo + registro RPC**, con apertura automática. Dos mecanismos de ejecución sin recompilación: servicio externo vía gRPC (módulos pesados con su propia base) y **plugins WASM en sandbox** (wasmtime — el estándar moderno de plugins en Rust, el equivalente nativo de lo que RC hizo con Deno). UI siempre declarativa (plantillas → Flutter; rueda candidata: rfw). Referencias del patrón: Tryton, WhatsApp Flows, Slack Block Kit |
| **Fuselage** (la cara) | Su catálogo de piezas visuales React | Solo referencia visual | **Material 3** en Flutter + design tokens propios (paleta/espaciados inspirables en Fuselage) |
| **Clientes web/RN/Electron** | Las tres apps del usuario, cosidas a Meteor/DDP | NO reutilizables (verificado pieza por pieza) | **Flutter único** — y con sinergia clave: LiveKit tiene SDK Flutter oficial |
| **Jitsi** (video grupal) + **voz WebRTC propia (8.0, Drachtio)** | Motor externo de video; y desde 8.0 su propia telefonía interna | El patrón sí (adaptador sala+token); sus motores no necesariamente | **⭐ LiveKit — el hallazgo moderno del anexo:** SFU open source escrito en Go sobre Pion, escala horizontal, SDKs para 11 plataformas (Flutter y Rust incluidos), E2EE de primera clase en web/iOS/Android, grabación (Egress) y SIP. La diferencia de fondo: Jitsi es una *app de reuniones terminada* y opinionada (para personalizar a fondo hay que forkear su frontend); LiveKit es *infraestructura* pensada para incrustar video en un producto propio — exactamente el caso bChat. Decisión: **bRocket usa Jitsi** (RC lo trae nativo); **bChat usa LiveKit** para voz y video desde C2, un solo motor. **Salas de reuniones tipo Meet: requisito confirmado** — interinamente Jitsi en bRocket ya da la sala terminada; en bChat la experiencia de sala (grilla de participantes, compartir pantalla, lobby, enlaces persistentes de sala, agenda vía bCalendar) se construye en Flutter sobre el SDK de LiveKit como superficie propia de C2–C3 |
| **Omnichannel / Livechat** | El mostrador de atención al cliente (ver B.3) | **SÍ — requisito confirmado del producto** | Interino: el livechat de bRocket sirve desde el día 1. En bChat se construye como **módulo first-party de la arquitectura B.4** — el candidato ideal para estrenar el sistema de módulos (ver B.3) |
| **S3/MinIO** (el archivero) | Fotos y documentos van a un almacén de objetos, no a la base | SÍ — mismo patrón (+CDN) | S3 API es el estándar; **vigilar el rumbo de MinIO** (recortes recientes a su edición community) y tener en el radar alternativas open source (SeaweedFS, Garage) — verificar licencias al decidir |
| **NATS** (solo en su modo enterprise) | Su mensajero interno entre microservicios de pago | SÍ — la misma herramienta, libre | **NATS + JetStream** (persistencia de streams) es el estado del arte ligero; confirmado como bus de todo SBOS |
| **Push** (paquete Meteor `raix` → FCM/APNs o su gateway) | Cómo despiertan al teléfono; sin abstracción propia | NO — el push de bChat es un **canal de bNotify** | **Requisito explícito: bChat despierta el teléfono estilo WhatsApp.** Cómo lo hace WhatsApp de verdad: socket persistente mientras la app vive + push de **alta prioridad** FCM (Android) / APNs (iOS) para despertarla, y **PushKit/CallKit** en iOS para que las llamadas suenen como llamadas. bChat replica ese patrón vía bNotify: FCM/APNs con credenciales propias (obligatorio: en iOS no existe alternativa a APNs, es regla de Apple), **UnifiedPush/ntfy** como opción soberana para Android sin Google, y el notify integrado en el cliente (badges, respuesta desde la notificación, canales por conversación) |
| **Búsqueda** (texto en Mongo; semántica premium) | Encontrar mensajes viejos | NO | **PostgreSQL FTS + pg_trgm** cubre C1–C2; si algún día se quiere búsqueda "inteligente": **Meilisearch** (motor open source en Rust) es la rueda existente — nunca construir un motor de búsqueda propio |
| **E2EE** (cifrado extremo a extremo) | Que ni el servidor pueda leer los mensajes | El requisito sí; su implementación no | **⭐ MLS (RFC 9420) — el segundo hallazgo moderno:** el estándar IETF de E2EE grupal (2 a miles de miembros, forward secrecy + post-compromise security). Adopción 2026: Google Messages y Apple Messages desplegándolo sobre RCS desde mayo 2026, Discord lo usa para cifrar voz/video, Matrix migrando. Implementaciones **en Rust listas para usar como bloque:** OpenMLS (Phoenix R&D/Cryspen) y mls-rs (AWS, conformidad RFC completa, WASM). Advertencia honesta: la librería resuelve la criptografía; el "delivery service" (distribución de key packages, welcomes, commits, multi-dispositivo) es construcción propia sobre ella. Regla absoluta: **jamás inventar criptografía propia** — MLS en C5 con revisión externa |
| **Omnichannel/Livechat, LDAP, federación Matrix** | Ver explicación llana en B.3 | Omnichannel **SÍ** (módulo propio, fila anterior); salas tipo Meet **SÍ**; LDAP no; Matrix anotado | B.3 |
| **Panel de administración** | La consola del operador | Propio | Sobre el mismo JSON-RPC/WS de bChat + átomos bAuth — sin excepción a la regla B.1 |

### B.3 Las tres piezas enterprise, explicadas en llano

**Omnichannel / Livechat — el mostrador de atención al cliente. REQUISITO CONFIRMADO.** Es el módulo con el que Rocket.Chat compite contra Zendesk/Intercom: un botoncito de chat que la empresa incrusta en su página web; los visitantes escriben, y del otro lado hay una **cola** que reparte cada conversación entre **agentes** humanos (soporte, ventas), con horarios, turnos, transferencias, respuestas enlatadas y métricas de atención. "Omnichannel" porque además del widget web puede recibir por otros canales. **Plan en dos tiempos:** (1) interino — el livechat de bRocket cubre la necesidad desde el día 1 sin construir nada; (2) definitivo — en bChat se construye la **bandeja de negocio** propia (cola, asignación a agentes, transferencias, respuestas enlatadas, métricas, todo auditado por átomos `D1.bchat.*` y con el widget web hablando el mismo WS/JSON-RPC), implementada como **módulo first-party sobre la arquitectura B.4** — deliberadamente el primero, porque es el caso de prueba perfecto del sistema de módulos: UI declarativa no trivial, permisos finos por rol de agente, y su propio ciclo de vida sin tocar el core.

**LDAP — el directorio telefónico corporativo.** El protocolo con el que las empresas guardan en un solo lugar a todos sus empleados con sus credenciales y grupos (la implementación famosa es Active Directory de Microsoft). Rocket.Chat lo integra para que una empresa "enchufe" a sus 5.000 empleados sin crearlos a mano. **Veredicto: no aplica** — en el ecosistema SBOS ese directorio central **es bAuth**; no hay directorio externo que sincronizar.

**Federación Matrix — que chats de casas distintas se hablen.** Federación significa que servidores de mensajería independientes intercambien mensajes entre sí, como el correo electrónico (alguien de Gmail escribe a alguien de Outlook sin pedir permiso a nadie). **Matrix** es el protocolo estándar abierto para lograr eso en chat, y Rocket.Chat 8.0 lo trae integrado en beta. **Veredicto: fuera de alcance por diseño** — bChat es una red cerrada del ecosistema (coherente con la frontera de producto A.1); si algún día el negocio exigiera interoperar con otras redes, Matrix es el estándar a evaluar. Queda anotado, no planificado.

### B.4 Arquitectura de módulos de bChat (modelo Tryton): anexar sin recompilar

> **Principio:** el motor de bChat se compila una vez y queda estable. Toda mini-aplicación se **anexa en caliente** mediante manifiesto declarativo + registro RPC, con apertura automática en los clientes. Recompilar el main para agregar una app es, por definición, un error de arquitectura.

**El ciclo de vida de un módulo (el "instalar módulo" de Tryton, traducido):**

1. **Manifiesto** (XML/JSON): identidad del módulo, versión, permisos que solicita (átomos bAuth que sus funciones requieren), plantillas de UI declarativas (vistas, formularios, acciones), endpoints RPC que expone, eventos del bus que emite/consume.
2. **Registro:** el módulo se da de alta en el **catálogo de módulos** de bChat vía RPC (o un operador lo aprueba desde el panel). El core valida el manifiesto, registra permisos en bAuth (`privilege_application`/átomos) y publica el módulo en el catálogo.
3. **Apertura automática:** los clientes Flutter, que negocian capacidades al conectar (patrón B.0.1), reciben el catálogo actualizado y renderizan la entrada del módulo — su UI se dibuja desde las plantillas del manifiesto (rfw/JSON-RPC), no desde código compilado en la app. Ni el servidor ni el cliente se recompilan.
4. **Ejecución** — dos mecanismos, ambos sin tocar el binario del core:
   - **Módulo-servicio (gRPC):** para módulos con lógica pesada o base de datos propia (la bandeja de atención, un módulo de bPay, un ERP ligero): corre como proceso/contenedor propio; el core solo enruta JSON-RPC del cliente hacia él y le entrega eventos del bus. Es el módulo Tryton llevado a microproceso.
   - **Módulo-plugin (WASM):** para lógica ligera que conviene ejecutar dentro del host (validaciones, transformaciones, comandos): archivo `.wasm` cargado en caliente por el runtime embebido (wasmtime), en sandbox con capacidades explícitas. Es el estándar moderno de plugins en Rust — el equivalente nativo del salto que Rocket.Chat dio al mover su Apps-Engine a Deno, pero dentro del proceso y con aislamiento de memoria por diseño.
5. **Desinstalación/actualización:** desregistrar o subir nueva versión del manifiesto+artefacto; el catálogo versiona, los clientes se actualizan en la siguiente negociación de capacidades. Rollback = volver a publicar la versión anterior.

**Reglas de gobernanza del sistema de módulos:** todo permiso que un módulo ejerce debe estar declarado en su manifiesto y concedido en bAuth (nada implícito); todo módulo de terceros pasa revisión antes de entrar al catálogo (el "marketplace" de C3/C4 es este catálogo con proceso de revisión); las acciones de los módulos se auditan con la misma taxonomía del doc. 07; y un módulo caído degrada solo su superficie — el chat nunca depende de ningún módulo para funcionar.

**Primer módulo first-party:** la bandeja de atención al cliente (B.3), que estrena y valida toda la maquinaria antes de abrirla a terceros.

**Síntesis del anexo B:** de Rocket.Chat se rescatan siete patrones probados (B.0) y las herramientas externas que él validó; ni una línea de su código. La regla cero-REST convierte a bChat en gRPC + JSON-RPC/WS de punta a punta (B.1). La investigación de modernidad deja dos actualizaciones — **LiveKit reemplaza a Jitsi en bChat** (infraestructura con SDK Flutter y E2EE, sobre la que también se construyen las **salas de reuniones tipo Meet**, requisito confirmado) y **MLS/RFC 9420 con OpenMLS o mls-rs en Rust** como estándar de cifrado de C5. Y la pieza arquitectónica central queda definida en B.4: el **sistema de módulos estilo Tryton** — el motor jamás se recompila; las mini-apps se anexan en caliente por manifiesto + registro RPC (módulo-servicio gRPC o módulo-plugin WASM), con apertura automática en los clientes — estrenado por el módulo first-party de **atención al cliente/omnichannel**, también requisito confirmado del producto.

---

**Próximos pasos inmediatos (G0):** (1) contrato gRPC bNotify↔adaptadores; (2) especificación OIDC de D9 en bAuth; (3) despliegue de bRocket y prueba OIDC en CE 8.x real.
