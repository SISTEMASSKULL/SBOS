---
codigo: BNOTIFY-007
version: 1.0.0
estado: BORRADOR
gate: G0
depende_de: [BNOTIFY-000]
doctrina_que_ejerce: [D14]
criterio_implementado: >
  Toda decisión tomada en BNOTIFY-000 está retro-documentada como ADR aquí.
  Toda nueva desviación de un documento aprobado tiene ADR aprobado por Ivan
  antes de que exista código que la implemente.
---

# BNOTIFY-007 — ADR Registro de Decisiones
## Architecture Decision Records del proyecto bNotify

**Versión:** 1.0.0 · **Gate:** G0 · **Estado:** BORRADOR
**Formato:** MADR (context → opciones → decisión → consecuencias)
**Regla:** inmutable — una decisión se supersede con un ADR nuevo, nunca se edita.

---

## Cómo agregar un ADR

1. Copiar la plantilla del §1
2. Asignar el siguiente número correlativo (ADR-NNN)
3. Completar todos los campos
4. Presentar a Ivan para aprobación antes de implementar
5. Una vez aprobado, actualizar el estado a `APROBADO` (solo Ivan)
6. Si en el futuro se supersede: nuevo ADR que referencia al anterior + marcar el viejo como `SUPERSEDIDO por ADR-NNN`

---

## §1. Plantilla

```markdown
### ADR-NNN — Título de la decisión

**Estado:** BORRADOR | EN REVISIÓN | APROBADO | SUPERSEDIDO por ADR-NNN
**Fecha:** YYYY-MM-DD
**Principio de doctrina:** DX

#### Contexto
Qué situación forzó tomar esta decisión. Cuál es el problema.

#### Opciones consideradas
1. Opción A — descripción breve
2. Opción B — descripción breve

#### Decisión
Cuál se eligió y por qué en una frase.

#### Consecuencias
- ✅ Lo que gana el sistema con esta decisión
- ⚠️ Lo que cuesta o se sacrifica
```

---

## §2. Registro de ADRs

---

### ADR-001 — Cero REST entre daemons del núcleo

**Estado:** APROBADO (retro-documentado desde BNOTIFY-000 §3, D4)
**Fecha:** 2026-07-06
**Principio de doctrina:** D4

#### Contexto
Los daemons del ecosistema SBOS necesitan comunicarse entre sí de forma confiable y tipada.
REST/HTTP es la opción default en la industria pero trae overhead de negociación HTTP,
contratos débiles (sin schema enforcement en runtime), y dificultad para streaming bidireccional.

#### Opciones consideradas
1. REST/HTTP (JSON) — ubicuo, fácil de depurar, sin dependencias de codegen
2. gRPC sobre mTLS — contratos tipados con proto, streaming bidireccional, menos overhead
3. NATS mensajes — desacoplado, pero sin request-reply tipado nativo

#### Decisión
gRPC entre daemons, NATS para eventos de bus. REST confinado a adaptadores de frontera
con el mundo exterior (webhooks, Twilio, FCM) — el único lugar donde vive HTTP.

#### Consecuencias
- ✅ Contratos tipados — un cambio de interfaz rompe en compilación, no en producción
- ✅ Streaming bidireccional nativo — crítico para despacho de notificaciones de alta frecuencia
- ✅ mTLS obligatorio — autenticación mutua entre servicios sin configuración adicional
- ⚠️ Requiere protoc y codegen en el proceso de build
- ⚠️ Flutter web no soporta gRPC puro — los clientes usan WebSocket + JSON-RPC 2.0 (ver ADR-002)

---

### ADR-002 — WebSocket + JSON-RPC 2.0 para clientes Flutter

**Estado:** APROBADO (retro-documentado desde BNOTIFY-000 Anexo B §B.1)
**Fecha:** 2026-07-06
**Principio de doctrina:** D4

#### Contexto
Flutter puede usar gRPC nativo en Android/iOS/desktop. Pero Flutter **web** no puede hacer
gRPC puro porque el navegador no expone acceso TCP raw. Se necesita un protocolo cliente
que funcione en todas las plataformas sin excepción, coherente con D4.

#### Opciones consideradas
1. gRPC puro — funciona en todas las plataformas excepto web (requiere gRPC-web proxy)
2. REST — simple, pero vetado en el núcleo por D4
3. WebSocket + JSON-RPC 2.0 — funciona en todas las plataformas, formato conocido (patrón Tryton)

#### Decisión
WebSocket persistente con JSON-RPC 2.0 para todos los clientes Flutter — mismo protocolo
en todas las plataformas, sin excepciones ni proxies especiales.

#### Consecuencias
- ✅ Un protocolo para todas las plataformas (Android/iOS/desktop/web) sin bifurcaciones
- ✅ Misma API que usa Tryton — patrón probado en producción
- ✅ Permite deltas/subscripciones sobre la misma conexión persistente
- ⚠️ Más verboso que gRPC binario — aceptable dado que el cliente es el boundary externo

---

### ADR-003 — bRocket congelado: solo configuración, cero desarrollo

**Estado:** APROBADO (retro-documentado desde BNOTIFY-000 §5, D7)
**Fecha:** 2026-07-06
**Principio de doctrina:** D7

#### Contexto
Se necesita una solución de chat funcional mientras se construye bChat (motor propio).
Rocket.Chat CE 8.5.0 cumple el requisito funcional. La pregunta es: ¿cuánta inversión
de desarrollo se le dedica a la solución interina?

#### Opciones consideradas
1. Hacer fork de Rocket.Chat y personalizarlo profundamente
2. Usar Rocket.Chat CE sin modificar — solo configuración
3. Construir bChat desde cero antes de tener cualquier chat funcional

#### Decisión
Rocket.Chat CE 8.5.0 sin modificar, versión congelada. Cero apps propias,
cero personalizaciones de código. Solo configuración (OIDC, variables de entorno, K8s).
Todo esfuerzo de construcción va a bChat.

#### Consecuencias
- ✅ Operativo en semanas — compra tiempo para construir bChat correctamente
- ✅ Sin costo de mantenimiento de fork
- ✅ La inversión no se tira — el reemplazo (bChat) absorbe los mismos usuarios
- ⚠️ CVEs del upstream no se parchean automáticamente (mitigación: solo red interna/VPN)
- ⚠️ Features EE ausentes (mitigados por bAuth + bNotify)
- ⚠️ MongoDB como isla de datos — se elimina en G3 con la migración

---

### ADR-004 — LiveKit en lugar de Jitsi para bChat

**Estado:** APROBADO (retro-documentado desde BNOTIFY-000 Anexo B §B.2)
**Fecha:** 2026-07-06
**Principio de doctrina:** D1

#### Contexto
bChat necesita voz, video 1:1 y salas de reuniones tipo Meet. Jitsi Meet es la
solución self-hosted más conocida. Rocket.Chat (bRocket) ya usa Jitsi. La pregunta
es si bChat debe usar el mismo motor o si existe una rueda mejor.

#### Opciones consideradas
1. Jitsi Meet — maduro, self-hosted, ya validado por bRocket. Pero es una *app terminada*
   y opinionada — personalizarla requiere forkear su frontend React
2. LiveKit — SFU open source en Go sobre Pion, SDKs para 11 plataformas (Flutter y Rust incluidos),
   E2EE de primera clase, grabación (Egress), SIP. Está pensado como *infraestructura* para
   incrustar video en un producto propio

#### Decisión
LiveKit en bChat para voz y video desde la fase C2. Jitsi permanece en bRocket
(ya lo trae integrado sin trabajo adicional). Un solo motor de video para bChat.

#### Consecuencias
- ✅ SDK Flutter oficial — integración nativa sin bridges ni WebViews
- ✅ SDK Rust oficial — integraciones server-side directas
- ✅ E2EE de primera clase en web/iOS/Android (D12)
- ✅ Las salas tipo Meet se construyen con superficie propia en Flutter — no heredamos UX de Jitsi
- ⚠️ Menos maduro que Jitsi para deployments de producción grandes — mitigado por objetivos
  de capacidad de BNOTIFY-070

---

### ADR-005 — MLS/RFC 9420 para E2EE en bChat

**Estado:** APROBADO (retro-documentado desde BNOTIFY-000 Anexo B, D12)
**Fecha:** 2026-07-06
**Principio de doctrina:** D12

#### Contexto
bChat necesitará E2EE en la fase C5 (grado consumo masivo). Existen varias opciones
para cifrado de extremo a extremo en mensajería grupal.

#### Opciones consideradas
1. Signal Protocol (X3DH + Double Ratchet) — probado en producción masiva, pero solo para
   conversaciones 1:1 o grupos pequeños. Escala pobremente en grupos de miles
2. MLS (RFC 9420, Message Layer Security) — estándar IETF diseñado para grupos de 2 a
   millones de miembros, forward secrecy + post-compromise security. Adopción 2026:
   Google Messages, Apple Messages, Discord voz/video
3. Implementación criptográfica propia — prohibida por D12

#### Decisión
MLS/RFC 9420 con OpenMLS (Phoenix R&D) o mls-rs (AWS) — ambas en Rust, conformidad
RFC completa. Decisión entre las dos implementaciones se toma en BNOTIFY-060 con
evaluación de madurez al momento de implementar.

#### Consecuencias
- ✅ Estándar IETF — no criptografía propia (D12)
- ✅ Escala de 2 a miles de miembros en un grupo
- ✅ Forward secrecy + post-compromise security — propiedades más fuertes que Signal Protocol
- ⚠️ El "delivery service" (distribución de key packages, welcomes, commits, multi-dispositivo)
  es construcción propia sobre la librería — es trabajo de implementación, no trivial
- ⚠️ Requiere revisión externa antes de producción — planificada en BNOTIFY-060

---

### ADR-006 — Clúster PostgreSQL compartido con esquema por dueño

**Estado:** APROBADO (retro-documentado desde BNOTIFY-000 §4.7c, D18)
**Fecha:** 2026-07-06
**Principio de doctrina:** D18

#### Contexto
Los daemons de SBOS necesitan acceder a datos de otros daemons (bNotify necesita
identidades de bAuth, membresías de salas del chat). Existen dos enfoques: base de
datos por daemon (microservicio puro) o base de datos compartida con esquemas separados.

#### Opciones consideradas
1. Una base de datos por daemon — aislamiento total, pero toda lectura cruzada es RPC con latencia
2. Clúster PostgreSQL compartido con un esquema por dueño y vistas de solo lectura — el
   fan-out se expande en SQL sin RPC, cada daemon solo escribe en su esquema

#### Decisión
Un clúster PostgreSQL, esquema por dueño (`bauth`, `bnotify`, `bchat`, correo).
Vistas de solo lectura cruzadas con GRANTs exactos definidos en BNOTIFY-008.
Solo el dueño escribe en su esquema.

#### Consecuencias
- ✅ El fan-out (expandir sala → miembros → UUIDs de bAuth) en SQL, sin RPC
- ✅ Transacciones cruzadas posibles cuando el modelo de negocio lo exige
- ✅ Un solo sistema a operar, respaldar y monitorear
- ⚠️ Acoplamiento de datos — mitigado por la regla de que solo el dueño escribe
- ⚠️ Salvedad temporal: bRocket usa MongoDB — durante el interinato la expansión de salas
  va por el adaptador de chat (RPC). Migra a vista nativa cuando exista el esquema `bchat`

---

### ADR-007 — Motor de módulos sin recompilar el binario principal

**Estado:** APROBADO (retro-documentado desde BNOTIFY-000 §B.4, D6)
**Fecha:** 2026-07-06
**Principio de doctrina:** D6

#### Contexto
bChat necesitará mini-aplicaciones (formularios, atención al cliente, wallet, firma digital).
La pregunta es cómo integrar nuevas funcionalidades sin recompilar y redesplegar el servidor.

#### Opciones consideradas
1. Compilar cada mini-app dentro del binario principal — simple, pero requiere recompilación
   y redespliegue por cada nueva mini-app
2. Módulo-servicio gRPC — corre como proceso externo, el core solo enruta
3. Módulo-plugin WASM — archivo .wasm cargado en caliente por wasmtime embebido
4. Apps Engine como Rocket.Chat (Deno embebido) — probado, pero Deno es runtime externo

#### Decisión
Dos mecanismos coexistentes según la complejidad del módulo: módulo-servicio gRPC para
lógica pesada con base de datos propia, módulo-plugin WASM (wasmtime) para lógica ligera.
Apertura automática en clientes vía negociación de capacidades. Recompilar el main para
agregar una app es error de arquitectura.

#### Consecuencias
- ✅ El motor de bChat se compila una vez — las mini-apps se instalan como configuración
- ✅ Sandbox WASM con capacidades declaradas — aislamiento de seguridad por diseño
- ✅ Módulos-servicio con base de datos propia — sin contaminación del esquema core
- ⚠️ Mayor complejidad inicial — justificada por el objetivo de plataforma (C3-C4)

---

### ADR-008 — bNotify como orquestador, bRocket y bChat como canales intercambiables

**Estado:** APROBADO (retro-documentado desde BNOTIFY-000 §1, §4.7, D5)
**Fecha:** 2026-07-06
**Principio de doctrina:** D5

#### Contexto
El reemplazo bRocket → bChat debe ser invisible para todos los daemons que emiten
notificaciones. Si cada daemon conoce al chat directamente, el reemplazo requiere
cambiar todos los emisores.

#### Opciones consideradas
1. Cada daemon llama directamente a la API del chat — simple, pero acoplado
2. bNotify como capa intermedia — los daemons hablan con bNotify, nunca con el chat

#### Decisión
bNotify es el único punto de contacto entre el ecosistema y cualquier canal de notificación.
Los daemons emiten intents a bNotify. bNotify decide el canal. El adaptador de canal encapsula
la API concreta (REST de RC hoy, gRPC de bChat mañana).

#### Consecuencias
- ✅ El reemplazo bRocket → bChat es invisible para todos los emisores — cambia el adaptador,
  no el contrato con los emisores
- ✅ Un solo punto de auditoría para todas las notificaciones
- ✅ Un solo punto de aplicación de políticas (rate limiting, quiet hours, prioridades)
- ⚠️ bNotify es un punto único de fallo para las notificaciones — mitigado por D15
  (degradación aislada: si bNotify cae, los daemons encolan y reintentan)

---

### ADR-009 — NATS/JetStream como bus de eventos interno

**Estado:** APROBADO (retro-documentado desde BNOTIFY-000 §4.8, Anexo B)
**Fecha:** 2026-07-06
**Principio de doctrina:** D1, D2

#### Contexto
Los daemons necesitan publicar y consumir eventos de dominio de forma asíncrona y persistente.

#### Opciones consideradas
1. Redis Pub/Sub — simple pero sin persistencia garantizada ni consumer groups robustos
2. Kafka — muy maduro, pero operacionalmente pesado para el tamaño actual de SBOS
3. NATS + JetStream — ligero, self-hosted, persistencia de streams, consumer groups,
   ya elegido por Rocket.Chat en su versión enterprise

#### Decisión
NATS 2.10.x con JetStream para persistencia. Mismo stack que el resto de SBOS.

#### Consecuencias
- ✅ Operacionalmente ligero — corre en K8s sin overhead de Kafka/ZooKeeper
- ✅ JetStream da persistencia at-least-once y consumer groups
- ✅ Coherencia con el stack validado por Rocket.Chat CE enterprise
- ⚠️ Menos ecosystem que Kafka — aceptable en el tamaño actual de SBOS

---

*BNOTIFY-007 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*Una decisión documentada es una decisión que puede revisarse. Una decisión en el código es una trampa.*
