# BAUTH — Catálogo de Átomos de la Aplicación bChat / bNotify v1.0
## bChat y bNotify como aplicaciones-herramienta gobernadas por bAuth

**Versión:** 1.0.0 · **Fecha:** 2026-07-10 · **Autor:** bauth-developer
**Estado:** DISEÑO — pendiente aprobación DDL (HITL, schema `bauth`) y ratificación por agente-bnotify
**Referencia de modelo:** MANUAL-ATOMOS §4.5 (dos clases de átomo) · MANUAL-DOMINIOS §2 · 2.08_MANUAL-MENU-CONTEXTUAL
**Fuente bNotify (SSOT de la app):** `BnotifyAgent/context/` — BNOTIFY-000 (doctrina), 030 (protocolo cliente),
061 (antiabuso/moderación), 062 (KYC tiers), 060 (E2EE-MLS), 041/045 (módulos/marketplace)
**Contrato bilateral:** `context/contracts/BAUTH-BNOTIFY-CONTRATOS.md`

---

## 0. Propósito y encuadre — por qué existe este catálogo

bNotify evoluciona hacia **bChat**, una plataforma de mensajería nivel WeChat (chat + llamadas +
formularios + mini-aplicaciones + pagos). Como **toda aplicación del ecosistema, bChat NO decide
quién puede hacer qué dentro de ella — eso lo decide bAuth** (doctrina bNotify D16, patrón PDP/PEP
de NIST SP 800-207: *bAuth decide, bNotify aplica*). El propio protocolo de bChat ya lo asume:

> BNOTIFY-030 §7: `bchat.room.create` «verifica átomo **D1.bchat.room.CREATE**» ·
> `bchat.message.edit` «verifica **D1.bchat.message.EDIT_OWN**» ·
> §9: «cada método verifica el átomo correspondiente contra bAuth antes de ejecutar» ·
> error `4003 Forbidden` = «átomo bAuth rechazó».

Para que bAuth pueda **usar bChat como herramienta** (gobernarla, no solo integrarla) necesita
declarar formalmente en su modelo los **cuatro artefactos de gobierno** de esa aplicación:

| Artefacto | Qué es para bChat | Sección |
|-----------|-------------------|:-------:|
| **Dominio** | ¿Bajo qué plano de soberanía viven sus operaciones? → **D1 Lógico** | §2 |
| **Átomos** | El permiso atómico de cada operación (enviar, crear sala, videollamar, moderar…) | §3–§4 |
| **Políticas** | Los límites y condiciones que modulan cada átomo (matriz KYC-tier, SoD, strikes, scopes) | §5 |
| **Rutas** | El ruteo método→átomo (enforcement) y las entradas de menú contextual (navegación) | §6 |

Sin estos cuatro, bChat quedaría autogobernándose —violando D16 y la soberanía de identidad—, o
peor, cada método quedaría sin control de acceso real (el `4003` sin catálogo detrás es letra muerta).

### 0.1 Inconsistencias de nomenclatura que este catálogo canoniza (⚠️ corrección)

Los documentos de bNotify gesticulan hacia átomos de bAuth pero con **nomenclatura inconsistente**
que bAuth —dueño del DomainRegistry y del catálogo de átomos— debe fijar de forma canónica:

| Aparece en bNotify | Problema | Canónico bAuth (este catálogo) |
|--------------------|----------|--------------------------------|
| `D1.bchat.room.CREATE` (BNOTIFY-030) | app `bchat` ✅ | `D1.bchat.room.CREATE_GROUP` |
| `D1.chat.message.SEND` (BNOTIFY-061 §4.1) | app `chat` ≠ `bchat` (dos nombres) | `D1.bchat.message.SEND` |
| `D15.chat.moderation.REPORT_VIEW` (BNOTIFY-061 §2) | **D15 no existe** en el DomainRegistry de bAuth (D1–D13 + D00 + D99). «D15» es un nº de *doctrina bNotify*, mal usado como prefijo de *dominio bAuth* | `D1.bchat.moderation.REPORT_VIEW` |

**Regla:** el prefijo `D{n}` de un átomo es SIEMPRE un dominio del DomainRegistry de bAuth
(D1–D13, D00, D99), nunca un número de doctrina de otro daemon. La app de mensajería se llama
**`bchat`** en singular canónico (no `chat`). Esta corrección se comunica a agente-bnotify vía el
buzón del Bibliotecario para alinear BNOTIFY-030/061.

---

## 1. El modelo — bChat es una app de OPERACIÓN (D1), no un dominio-elemento

MANUAL-ATOMOS §4.5 distingue **dos clases de átomo**:

- **Átomo de ELEMENTO** (D00, D2–D13): el verbo *es* un elemento semántico del plano de control
  (`nit`, `max_daily`, `zone_access`); el CRUD **no** aplica; el valor vive en `role_atom.value`.
- **Átomo de OPERACIÓN** (D1 Lógico): apps reales donde `create` ≠ `read` sobre un registro; el
  verbo *es* una operación legítima. **bChat cae aquí** — enviar un mensaje, crear una sala,
  iniciar una videollamada son operaciones, no elementos.

Por tanto **bChat vive en D1 Lógico**, junto a las demás aplicaciones reales del ecosistema, y sus
átomos se codifican en la **capa lógica** del BitMask como `(app_code, grupo, verbo)`, no como una
posición-elemento fija (6001…). Notación:

```
Átomo de operación bChat = D1 . bchat . {módulo} . {OPERACIÓN}
                           │     │        │            └── verbo = operación (SEND, CREATE_GROUP, CALL_VIDEO…)
                           │     │        └── módulo de la app (grupo): room, message, media, rtc, moderation…
                           │     └── la aplicación: bchat (mensajería) · bnotify (notificador)
                           └── dominio D1 Lógico (operaciones sobre apps reales)
```

### 1.1 Alineación con el estado del arte de la industria (chat + notificador)

El modelo no se inventa: replica —y supera en soberanía— lo que hacen las plataformas de referencia.

| Concepto de bChat | Referente de industria | Cómo lo hace bAuth (soberano) |
|-------------------|------------------------|-------------------------------|
| Roles de sala (Dueño/Moderador/Miembro) | **Rocket.Chat**: roles *room-scoped* (Moderator, Owner) además de roles globales; permisos granulares para editar/crear/archivar salas | Átomos `D1.bchat.*` con **alcance por `ctx_id`/sala** (context-scoped), no solo globales |
| Niveles de poder por sala | **Matrix**: *power levels* numéricos por sala | Matriz rol→átomo (§7) resuelta por el PrivilegeEngine O(1), con SoD *en el momento* |
| Mini-apps con permisos que el usuario concede | **WeChat**: mini-programs piden *scopes*; el usuario autoriza; existen *permission sets mutuamente excluyentes* (uno solo por proveedor) | Átomos `D1.bchat.module.*` + scopes delegados (§5.4), SoD estático para sets excluyentes |
| Centro de preferencias / opt-in por canal | **Preference centers** (OneSignal, Courier, Osano): control per-canal, consentimiento GDPR *freely given*, propagación automática | Átomos `D1.bnotify.prefs.*` de **autoservicio** + consentimiento como REGLA con valor (§4) |
| Suspensión = quitar el permiso, no lista negra | Práctica de *notification systems* (enforcement en la fuente, no batch) | Revocar `D1.bchat.message.SEND` en bAuth (< 30 s, vía CAEP) — control soberano, no negro en bChat |

> Fuentes de industria consultadas: Rocket.Chat *Roles & Permissions* / *Security Overview*; Matrix
> *power levels* (federación); WeChat *Mini Program permission set* / *authorization scopes* y el
> estudio académico *SoK: Decoding the Super App Enigma* (arXiv 2306.07495); guías de *notification
> preference center* (SuprSend 2026, Courier, Osano/Ethyca) y consentimiento GDPR/GPC. Enlaces al pie.

---

## 2. Asignación de dominio, aplicaciones y códigos

| Aplicación | Dominio | app_code (propuesto — HITL) | Naturaleza |
|-----------|:-------:|:---------------------------:|-----------|
| **`bchat`** | D1 Lógico | asignar libre en rango 1–511 | Mensajería (chat, salas, medios, RTC, moderación, mini-apps) |
| **`bnotify`** | D1 Lógico | asignar libre en rango 1–511 | Notificador (preferencias, canales, audiencias, difusión, consentimiento) |

> Nota de codificación (D1 ≠ dominios-elemento): en D1 el átomo **no** ocupa una posición escalar
> del mapa 6001–6220 (ese mapa es para átomos-elemento D2–D12). Un átomo D1 se identifica por la
> terna `(app_code, grupo, verbo)` en la capa lógica del BitMask (`[9 app][11 grupo][24 verbo]`).
> Los códigos de grupo/verbo de las tablas §3–§4 son **propuestas** a ratificar en el seed DDL.

### 2.1 Módulos (grupos) de la app `bchat`

| Grupo | Código (prop.) | Cubre |
|-------|:--------------:|-------|
| `session` | 1 | Conexión, sincronización, presencia base |
| `room` | 2 | Salas y canales (ciclo de vida, membresía, roles de sala) |
| `message` | 3 | Mensajes (enviar, editar, borrar, reenviar, reaccionar, fijar) |
| `media` | 4 | Subida/descarga de archivos |
| `presence` | 5 | Estado en línea, escribiendo, visto por última vez |
| `rtc` | 6 | Voz, video, salas Meet, grabación |
| `e2ee` | 7 | Cifrado de extremo a extremo (MLS), firma de mensajes |
| `moderation` | 8 | Reportes, silenciar, banear, strikes, apelaciones |
| `pay` | 9 | Puente a bPay en conversación (enviar/solicitar pago) |
| `module` | 10 | Mini-apps / módulos WASM (instalar, ejecutar, publicar) |

---

## 3. Catálogo de átomos — aplicación `bchat`

> **Alcance (scope):** la columna «Alcance» distingue **G**=global (vale en todo el tenant) de
> **S**=por sala (context-scoped: el átomo se posee *respecto de una sala concreta* vía `ctx_id`).
> Es la distinción Rocket.Chat entre rol global y rol de sala, expresada en el Context Plane de bAuth.
> **Rol mínimo:** el tier/rol más bajo que porta el átomo por defecto (ver matriz §7).
> **Gating:** política adicional que condiciona el átomo (ver §5) — típicamente el `kyc_tier`.

### 3.1 Módulo `session`

| Átomo | Tipo | Descripción | Alcance | Rol mín. | Gating |
|-------|:----:|-------------|:-------:|:--------:|--------|
| `D1.bchat.session.ACCESS` | ACCIÓN | Conectar al motor bChat (`bchat.connect`) | G | Miembro (EXT_N0/T0) | JWT válido + `kyc_tier≥T0` |
| `D1.bchat.session.MULTIDEVICE` | REGLA | Nº de dispositivos simultáneos permitidos | G | Miembro | valor por tier (2/5/10) |

### 3.2 Módulo `room`

| Átomo | Tipo | Descripción | Alcance | Rol mín. | Gating |
|-------|:----:|-------------|:-------:|:--------:|--------|
| `D1.bchat.room.LIST` | ACCIÓN | Listar salas propias (`bchat.room.list`) | G | Miembro | — |
| `D1.bchat.room.READ` | ACCIÓN | Suscribir/leer historial de una sala | S | Miembro | membresía de la sala |
| `D1.bchat.room.CREATE_GROUP` | ACCIÓN | Crear sala de grupo (`bchat.room.create`) | G | Miembro | `T1+` (T0 no crea); tamaño máx. por tier |
| `D1.bchat.room.CREATE_CHANNEL` | ACCIÓN | Crear canal | G | Dueño | `T1+`; nº canales por tier (5/∞) |
| `D1.bchat.room.JOIN` | ACCIÓN | Unirse a una sala | S | Miembro | invitación o sala pública |
| `D1.bchat.room.LEAVE` | ACCIÓN | Salir de una sala | S | Miembro | — |
| `D1.bchat.room.INVITE` | ACCIÓN | Invitar miembros a la sala | S | Dueño de sala | — |
| `D1.bchat.room.MANAGE` | ACCIÓN | Editar nombre/tema/config de la sala | S | Dueño/Moderador | — |
| `D1.bchat.room.ARCHIVE` | ACCIÓN | Archivar/desarchivar sala | S | Dueño de sala | — |
| `D1.bchat.room.ASSIGN_ROLE` | ACCIÓN | Asignar roles de sala (moderador, dueño) | S | Dueño de sala | — |

### 3.3 Módulo `message`

| Átomo | Tipo | Descripción | Alcance | Rol mín. | Gating |
|-------|:----:|-------------|:-------:|:--------:|--------|
| `D1.bchat.message.SEND` | ACCIÓN | Enviar mensaje (`bchat.message.send`) — **el átomo que se revoca en suspensión (§5.3)** | S | Miembro | rate-limit por tier (§5.1) |
| `D1.bchat.message.EDIT_OWN` | ACCIÓN | Editar mensaje propio (`bchat.message.edit`) | S | Miembro | — |
| `D1.bchat.message.DELETE_OWN` | ACCIÓN | Borrar mensaje propio | S | Miembro | — |
| `D1.bchat.message.DELETE_ANY` | ACCIÓN | Borrar mensaje de cualquiera (moderación) | S | Moderador | — |
| `D1.bchat.message.FORWARD` | ACCIÓN | Reenviar mensaje | S | Miembro | — |
| `D1.bchat.message.REACT` | ACCIÓN | Reaccionar (emoji) | S | Miembro | — |
| `D1.bchat.message.PIN` | ACCIÓN | Fijar mensaje en la sala | S | Moderador | — |
| `D1.bchat.message.SEARCH` | ACCIÓN | Buscar en el historial | G | Miembro | `T1+` (T0 sin búsqueda, §5.1) |

### 3.4 Módulo `media`

| Átomo | Tipo | Descripción | Alcance | Rol mín. | Gating |
|-------|:----:|-------------|:-------:|:--------:|--------|
| `D1.bchat.media.UPLOAD` | ACCIÓN | Subir archivo | S | Miembro | tamaño/tipo/cuota por tier (§5.2) |
| `D1.bchat.media.DOWNLOAD` | ACCIÓN | Descargar archivo | S | Miembro | membresía de la sala |

### 3.5 Módulo `presence`

| Átomo | Tipo | Descripción | Alcance | Rol mín. | Gating |
|-------|:----:|-------------|:-------:|:--------:|--------|
| `D1.bchat.presence.SET` | ACCIÓN | Publicar propio estado (online/away/offline) | G | Miembro | — |
| `D1.bchat.presence.VIEW` | ACCIÓN | Ver presencia/último visto de otros | S | Miembro | respeta privacidad del observado |

### 3.6 Módulo `rtc` (tiempo real — BNOTIFY-035 LiveKit)

| Átomo | Tipo | Descripción | Alcance | Rol mín. | Gating |
|-------|:----:|-------------|:-------:|:--------:|--------|
| `D1.bchat.rtc.CALL_VOICE` | ACCIÓN | Llamada de voz 1:1 | S | Miembro | `T1+` (T0 sin llamadas) |
| `D1.bchat.rtc.CALL_VIDEO` | ACCIÓN | Videollamada 1:1 | S | Miembro | `T1+` |
| `D1.bchat.rtc.MEET_HOST` | ACCIÓN | Crear sala Meet grupal | S | Miembro | `T1+`; aforo por tier (16/100) |
| `D1.bchat.rtc.MEET_JOIN` | ACCIÓN | Unirse a sala Meet | S | Miembro | invitación |
| `D1.bchat.rtc.CALL_RECORD` | ACCIÓN | Grabar llamada (con consentimiento) | S | Miembro | `T2` + consentimiento de partes (SoD, §5.5) |

### 3.7 Módulo `e2ee` (BNOTIFY-060 — MLS RFC 9420)

| Átomo | Tipo | Descripción | Alcance | Rol mín. | Gating |
|-------|:----:|-------------|:-------:|:--------:|--------|
| `D1.bchat.e2ee.ENABLE` | MÉTODO | Activar cifrado E2EE (MLS) en una sala | S | Miembro | `T1` opt-in DM · `T2` todas las salas |
| `D1.bchat.e2ee.SIGN` | MÉTODO | Firmar mensajes con Ed25519 | S | Miembro | `T2` opt-in |
| `D1.bchat.e2ee.KEY_ROTATE` | ACCIÓN | Rotar clave de grupo MLS | S | Dueño de sala | material de clave gestionado vía **D9 Credenciales** (§7) |

### 3.8 Módulo `moderation` (BNOTIFY-061 — corrige D15→D1)

| Átomo | Tipo | Descripción | Alcance | Rol mín. | Gating |
|-------|:----:|-------------|:-------:|:--------:|--------|
| `D1.bchat.moderation.REPORT_CREATE` | ACCIÓN | Reportar un mensaje/usuario | S | Miembro | — |
| `D1.bchat.moderation.REPORT_VIEW` | ACCIÓN | Ver reportes de contenido | S | Moderador | — |
| `D1.bchat.moderation.MESSAGE_REMOVE` | ACCIÓN | Eliminar (lógico) mensaje reportado | S | Moderador | genera auditoría WORM clase A |
| `D1.bchat.moderation.USER_SILENCE` | ACCIÓN | Silenciar usuario en la sala | S | Moderador | temporal, registrado con `ctx_id` |
| `D1.bchat.moderation.USER_BAN` | ACCIÓN | Banear usuario de la sala | S | Moderador | — |
| `D1.bchat.moderation.GLOBAL_BAN` | ACCIÓN | Banear del tenant completo | G | Admin | — |
| `D1.bchat.moderation.STRIKE_APPLY` | ACCIÓN | Aplicar strike formal | G | Moderador | consecuencias automáticas (§5.3) |
| `D1.bchat.moderation.APPEAL_RESOLVE` | ACCIÓN | Resolver apelación | G | Admin | el moderador también es auditado |

### 3.9 Módulo `pay` (puente a bPay — BNOTIFY-062 §3)

| Átomo | Tipo | Descripción | Alcance | Rol mín. | Gating |
|-------|:----:|-------------|:-------:|:--------:|--------|
| `D1.bchat.pay.SEND` | ACCIÓN | Enviar pago en conversación (abre formulario bPay) | S | Miembro | `T1+`; **encadena a los átomos de bPay (D3)** (§7) |
| `D1.bchat.pay.REQUEST` | ACCIÓN | Solicitar pago a otro usuario | S | Miembro | `T1+` |

### 3.10 Módulo `module` (mini-apps — BNOTIFY-041/045, modelo WeChat)

| Átomo | Tipo | Descripción | Alcance | Rol mín. | Gating |
|-------|:----:|-------------|:-------:|:--------:|--------|
| `D1.bchat.module.RUN` | ACCIÓN | Ejecutar una mini-app en el chat | S | Miembro | scope concedido por el usuario (§5.4) |
| `D1.bchat.module.INSTALL` | ACCIÓN | Instalar mini-app en un espacio/tenant | G | Admin | revisión de marketplace |
| `D1.bchat.module.PUBLISH` | ACCIÓN | Publicar mini-app en el marketplace | G | Desarrollador | firma + revisión |
| `D1.bchat.module.GRANT_SCOPE` | ACCIÓN | Conceder un scope solicitado por una mini-app | S | Miembro (dueño del dato) | SoD para sets excluyentes (§5.4) |

---

## 4. Catálogo de átomos — aplicación `bnotify` (el notificador)

El **notificador** es dominio propio de bNotify (perfil de notificación: preferencias, canales,
tokens de push, horas de silencio — BNOTIFY-000 §4.3), pero **quién puede hacer qué sobre él lo
gobierna bAuth**. La regla rectora del centro de preferencias (industria + doctrina): *el emisor
propone, bNotify gobierna, el usuario dispone* → los átomos de preferencia son de **autoservicio**.

### 4.1 Módulo `prefs` (centro de preferencias — autoservicio del usuario)

| Átomo | Tipo | Descripción | Alcance | Rol mín. | Gating |
|-------|:----:|-------------|:-------:|:--------:|--------|
| `D1.bnotify.prefs.SELF_MANAGE` | ACCIÓN | Gestionar las propias preferencias de notificación | G | Miembro | solo sobre sí mismo |
| `D1.bnotify.prefs.CHANNEL_OPTIN` | REGLA | Opt-in/opt-out por canal (chat/email/SMS/push) | G | Miembro | consentimiento *freely given* (GDPR) |
| `D1.bnotify.prefs.QUIET_HOURS` | REGLA | Definir horas de silencio | G | Miembro | valor: rango horario |
| `D1.bnotify.prefs.CONSENT` | REGLA | Consentimiento por tópico de dato (GDPR/GPC) | G | Miembro | revocable en cualquier momento |

### 4.2 Módulo `audience` / `broadcast` (administración — anti-spam)

| Átomo | Tipo | Descripción | Alcance | Rol mín. | Gating |
|-------|:----:|-------------|:-------:|:--------:|--------|
| `D1.bnotify.audience.MANAGE` | ACCIÓN | Crear/editar audiencias y tópicos ("operadores de guardia") | G | Admin | — |
| `D1.bnotify.broadcast.SEND` | ACCIÓN | Difundir a una audiencia | G | Admin | **respeta el opt-in de cada destinatario**; auditado |
| `D1.bnotify.emit.SYSTEM` | ACCIÓN | Emitir notificación de sistema/seguridad (no rechazable) | G | M2M/SYS | reservado a eventos críticos (D15 «lo crítico llega») |

> **Frontera clave:** un daemon emisor (bAuth, bPay) **no** posee `broadcast.SEND` de negocio; posee
> `emit.SYSTEM` para lo transaccional/seguridad (OTP, alertas), que por doctrina D15 no se silencia.
> Lo comercial siempre pasa por el opt-in del usuario. Esto materializa el «emisor propone / usuario
> dispone» y evita que el ecosistema entrene a sus usuarios a ignorar las notificaciones.

---

## 5. Políticas — lo que modula los átomos (NO son átomos)

Un átomo dice *si* la operación existe para el sujeto; una **política** dice *bajo qué condiciones y
con qué límite*. Las políticas de bChat se resuelven en la PolicyChain de bAuth, keadas por el claim
`kyc_tier` (y por rol/`ctx_id`). **No se catalogan como átomos** — son parámetros de política.

### 5.1 Matriz de límites por KYC-tier (mensajería) — BNOTIFY-062 §2.1

| Parámetro de política | T0 (IAL1) | T1 (IAL2) | T2 (IAL3) |
|-----------------------|:---------:|:---------:|:---------:|
| `bchat.msg.rate_per_min` | 20 | 60 | 200 |
| `bchat.msg.rate_per_hour` | 100 | 500 | 2000 |
| `bchat.history.visible` | 7 días | 1 año | completo |
| `bchat.history.search` | ✗ | ✓ | ✓ |
| `bchat.room.create_group` | ✗ | ≤50 miembros | ≤500 |
| `bchat.room.create_channel` | ✗ | ≤5 | ∞ |

### 5.2 Matriz de medios y RTC por tier — BNOTIFY-062 §2.2–2.4

| Parámetro | T0 | T1 | T2 |
|-----------|:--:|:--:|:--:|
| `bchat.media.max_file` | 10 MB | 100 MB | 1 GB |
| `bchat.media.storage` | 500 MB | 5 GB | 50 GB |
| `bchat.rtc.voice_video` | ✗ | ✓ | ✓ |
| `bchat.rtc.meet_size` | ✗ | 16 | 100 |
| `bchat.e2ee` | ✗ | opt-in DM | todas |
| `bchat.session.devices` | 2 | 5 | 10 |

> El tier llega como claim `kyc_tier` en el JWT (contrato C-BAUTH-002) — **bAuth lo determina y
> certifica, bChat solo lo consulta** (< 50 ms desde caché). Al promover T0→T1→T2, bAuth emite el
> evento CAEP `assurance-level-change` y los límites se elevan en el próximo refresh de JWT.

### 5.3 Strikes y suspensión — enforcement soberano (BNOTIFY-061 §4)

La suspensión **no** es una lista negra dentro de bChat: es la **revocación del átomo
`D1.bchat.message.SEND`** en bAuth (BNOTIFY-061 §4.1), propagada en < 30 s vía CAEP `session-revoked`.
Política de consecuencias automáticas por strikes acumulados (2 leves → silencio 24 h; 3 leves →
suspensión 7 d; 1 muy grave → suspensión inmediata). Toda acción de moderación → auditoría WORM clase A.

### 5.4 Scopes de mini-apps (modelo WeChat) — BNOTIFY-041/045

Una mini-app declara los **scopes** que necesita (leer perfil, usar cámara, iniciar pago…). El átomo
`D1.bchat.module.GRANT_SCOPE` permite al usuario **conceder** ese scope; bAuth guarda la concesión
como delegación acotada (dominio **D10 Delegación**, §7). Del estudio de super-apps se adopta la regla
de **permission sets mutuamente excluyentes**: dos scopes en conflicto (p. ej. dos módulos de pago
sobre la misma billetera) **no** se conceden simultáneamente — SoD estático en la Conflict Matrix.

### 5.5 SoD (Separación de Deberes) aplicable a bChat

| Regla SoD | Tipo | Razón |
|-----------|:----:|-------|
| `pay.SEND` requiere `kyc_tier ≥ T1` | Estático | Un T0 sin verificar no mueve dinero |
| `rtc.CALL_RECORD` requiere consentimiento de todas las partes | Dinámico (en el momento) | Ley de privacidad; grabar sin consentimiento es sanción |
| Moderador **no** modera salas donde es parte en disputa | Dinámico | Imparcialidad; el moderador también es auditado |
| Dos scopes de pago excluyentes (mini-apps) no coexisten | Estático | Evita doble-gasto / code overwrite (super-app) |

---

## 6. Rutas — el ruteo de gobierno de bChat

«Ruta» tiene dos sentidos, ambos gobernados por bAuth:

### 6.1 Ruta de enforcement: método del protocolo → átomo que verifica (BNOTIFY-030 §7)

Cada método JSON-RPC del protocolo bChat verifica **exactamente un átomo** contra bAuth antes de
ejecutar. Esta es la tabla de ruteo que convierte el `4003 Forbidden` en control real:

| Método (BNOTIFY-030) | Átomo bAuth que verifica |
|----------------------|--------------------------|
| `bchat.connect` | `D1.bchat.session.ACCESS` |
| `bchat.room.list` | `D1.bchat.room.LIST` |
| `bchat.room.subscribe` / `.history` / `.members` | `D1.bchat.room.READ` (por sala) |
| `bchat.room.create` | `D1.bchat.room.CREATE_GROUP` |
| `bchat.message.send` | `D1.bchat.message.SEND` |
| `bchat.message.edit` | `D1.bchat.message.EDIT_OWN` |
| `bchat.message.delete` | `D1.bchat.message.DELETE_OWN` **o** `.DELETE_ANY` (moderación) |
| `bchat.presence.set` | `D1.bchat.presence.SET` |
| `bchat.moderation.report` | `D1.bchat.moderation.REPORT_CREATE` |
| `bchat.moderation.report.review` | `D1.bchat.moderation.REPORT_VIEW` (+ acción específica) |
| `bchat.session.revoked` (S→C) | *ninguno* — es consecuencia del CAEP `session-revoked` de bAuth |

### 6.2 Ruta de navegación: menú contextual (2.08_MANUAL-MENU-CONTEXTUAL)

Las entradas de menú de bChat viven en `bglobal.menu_item` (multi-daemon, **no** migran a bAuth), con:
- **`owner_daemon = 'bchat'`** (propietario del menú — 2.08 §5.3).
- **`menu_item_atom`** que compuerta cada entrada por `atom_code` + `min_loa` + `step_up_flow`
  (p. ej. la entrada «Enviar pago» exige `D1.bchat.pay.SEND` + `min_loa=AAL2`).
- **`menu_context`** declara el propósito y —regla dura de 2.08— **todo enum de bChat** (tipos de
  sala, roles de sala, tipos de reporte, estados de strike) debe estar **declarado en `menu_context`**,
  no hardcodeado. Así cada daemon sabe qué menús de bChat puede usar y de dónde se originan.

---

## 7. Enlaces cruzados con otros dominios (bChat no vive aislado)

| Enlace | Dominio destino | Naturaleza |
|--------|:---------------:|-----------|
| KYC-tier T0/T1/T2 = IAL1/2/3 | **D00 Identidad** + proofing IAL | El tier es un hecho de identidad certificado por bAuth (claim `kyc_tier`) |
| Material de clave E2EE/MLS, firma Ed25519 | **D9 Credenciales** | Las claves de `e2ee.*` se gestionan en el ciclo de vida de credenciales de bAuth |
| Pago en conversación (`pay.*`) | **D3 Financiero** (bPay) | `bchat.pay.SEND` **encadena** a los átomos/límites financieros de bPay (SoD, dual-approval) |
| Scopes de mini-apps | **D10 Delegación** | Conceder un scope = delegar un permiso acotado y revocable |
| Toda acción de moderación / broadcast | **D11 Auditoría** | Eventos WORM clase A con `ctx_id` (los moderadores también se auditan) |
| Suspensión / revocación de sesión | **D8 Contexto** + CAEP | Revocar `message.SEND` y propagar `session-revoked` en < 30 s |
| Cifrado de mensajes con validez jurídica | **D13 Firma** | `e2ee.SIGN` puede escalar a firma Ed25519 con valor probatorio (Ley 164) |

---

## 8. Cumplimiento normativo cubierto

| Estándar | Cómo lo cubre este catálogo |
|----------|------------------------------|
| **NIST SP 800-207** (Zero Trust PDP/PEP) | bAuth PDP decide cada átomo; bChat PEP aplica (D16) |
| **NIST SP 800-63A** (IAL1-3) | KYC-tier ↔ IAL; el tier gobierna capacidades (§5.1–5.2) |
| **NIST RBAC Nivel 3** (ANSI INCITS 359) | Roles de sala + globales, SoD estático y dinámico (§5.5) |
| **RFC 9420** (MLS) | Átomos `e2ee.*` gobiernan el cifrado de grupo |
| **GDPR / GPC** (consentimiento) | `prefs.CONSENT` *freely given*, revocable, propagación automática vía CAEP |
| **ISO 27001 A.8.15** (logging) | Toda moderación/broadcast → auditoría WORM clase A |
| **CAEP / Shared Signals** (OpenID) | `assurance-level-change`, `session-revoked` gobiernan tier y suspensión |

---

## 9. Brechas y tareas de reparación (P1/P2/P3)

| # | Tarea | Prioridad | Depende de |
|---|-------|:---------:|-----------|
| B1 | Ratificar app_codes de `bchat`/`bnotify` y códigos grupo/verbo en seed DDL (`bauth_06` generativo) | **P1** | HITL schema `bauth` |
| B2 | Implementar el handler de verificación de átomo por método (la tabla §6.1) del lado que valide bChat contra bAuth | **P1** | contrato C-BAUTH-002 (claims) |
| B3 | Definir las políticas KYC-tier (§5.1–5.2) como parámetros de PolicyChain keados por `kyc_tier` | **P1** | claim `kyc_tier` operativo |
| B4 | Modelar los roles de sala (Dueño/Moderador/Miembro) como **context-scoped** en el Context Plane | **P2** | D8 Contexto |
| B5 | Delegación de scopes de mini-apps (§5.4) sobre D10 + Conflict Matrix para sets excluyentes | **P2** | D10 Delegación |
| B6 | Emitir a agente-bnotify (buzón Bibliotecario) las correcciones de nomenclatura §0.1 (bchat/chat, D15→D1) | **P1** | — |
| B7 | Registrar en `bglobal.menu_item` el menú de bChat (`owner_daemon='bchat'`) con enums en `menu_context` | **P3** | 2.08 · HITL bglobal |

---

## 10. Resumen ejecutivo

**bChat entra al gobierno de bAuth como aplicación de operación del dominio D1 Lógico**, con dos
namespaces (`bchat` la mensajería, `bnotify` el notificador), **~40 átomos de operación** organizados
en 10 módulos, una **matriz de políticas keada por KYC-tier** (no átomos), reglas de **SoD** (pago,
grabación, moderación, scopes), y **rutas** en dos planos (método→átomo para enforcement, menú
contextual para navegación). Con esto bAuth **usa bChat como herramienta soberana**: decide cada
operación (D16), la audita (D11, WORM), la revoca en < 30 s (CAEP), y respeta el consentimiento del
usuario (GDPR). El catálogo **canoniza** la nomenclatura que los docs de bNotify usaban de forma
inconsistente y la devuelve alineada al DomainRegistry real de bAuth.

---

## Fuentes de industria consultadas (chat + notificador)

- Rocket.Chat — *Roles & Permissions*: https://docs.rocket.chat/docs/roles-in-rocketchat
- Rocket.Chat — *Security Overview (Zero-Trust)*: https://docs.rocket.chat/docs/security-overview
- Rocket.Chat — *Roles in Federated Rooms* (room-scoped): https://docs.rocket.chat/docs/assign-roles-for-users-in-federated-rooms
- WeChat — *Mini Program permission set*: https://developers.weixin.qq.com/doc/oplatform/en/Third-party_Platforms/2.0/product/miniprogram_authority.html
- WeChat — *Authorization scopes*: https://developers.weixin.qq.com/doc/oplatform/en/Third-party_Platforms/2.0/api/Before_Develop/Authorization_Process_Technical_Description.html
- *SoK: Decoding the Super App Enigma* (mecanismos de seguridad de super-apps): https://arxiv.org/pdf/2306.07495
- Notification preference center — patrones UX/GDPR (2026): https://www.suprsend.com/post/notification-preference-center
- Courier — *Preferences Overview*: https://www.courier.com/docs/platform/preferences/preferences-overview
- Osano — *What Is a Preference Center*: https://www.osano.com/articles/preference-center

---

*BAUTH-CATALOGO-ATOMOS-BCHAT-v1.0.0 · BauthAgent/context/plandeaccion/REPARACIONBAUTH/ · 2026-07-10*
*bAuth decide, bChat aplica (D16). El chat es una herramienta; la soberanía de identidad es de bAuth.*
