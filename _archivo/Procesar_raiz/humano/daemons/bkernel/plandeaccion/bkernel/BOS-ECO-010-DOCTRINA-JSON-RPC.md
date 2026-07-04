# BOS-ECO-010 — DOCTRINA JSON-RPC
## JSON-RPC 2.0 como lengua franca del SBOS: perfil del protocolo, transporte por clase de soberanía y categorías de aplicaciones

---

## 0. Metadatos del documento

| Campo | Valor |
|---|---|
| **Documento** | BOS-ECO-010-DOCTRINA-JSON-RPC |
| **Versión** | 1.3 — incorpora D10: todos los nombres de aplicaciones de las tres series son variables ilustrativas, nunca constantes normativas; ajustes en mapa, soberanía, categorías y registro. Historial: v1.2 D9; v1.1 representación completa de biedata |
| **Estado** | VIGENTE — REDACTADO (pendiente de validación del arquitecto) |
| **Fase asociada** | G0 Fundaciones — Lote 1 de redacción |
| **Serie** | BOS-ECO |
| **Fuentes que absorbe** | Plano doctrinal de: Manual JSON-RPC Parte 1 (fundamentos, convenciones, transporte HTTP), Parte 8 (filosofía de ecosistema, categorías A/B/C, Fachada-RPC, gobernanza), Parte 9 (orquestación, Categoría D, sagas) · `DAEMON-BIEDATA-01-PROTOCOLO-RPC` §§1–2, 5–7 (mensaje, endpoint único, códigos de error — solo el plano ecosistémico) · `DAEMON-BIEDATA-00-MAESTRO` v3.0 (filosofía central y analogía Tryton) · decisiones D2/D4 y resoluciones C-13/C-15 de Fase 0 |
| **Documentos que supersede** | Ninguno. El **Manual JSON-RPC (partes 1–9) permanece como corpus normativo paralelo** y no se renombra (D4). Este documento lo PERFILA para el SBOS. En su punto de colisión, supersede al veto de transporte ADR-012 del `SBOS-MANUAL-ACOPLAMIENTO` v2.0 (ver §5.4) |
| **Prerequisitos de lectura** | → BOS-ECO-000 (doctrina D1–D8) |
| **Normas aplicables** | JSON-RPC 2.0 Specification (jsonrpc.org, 2010-03-26, actualizada 2013-01-04) — secciones 4, 4.1, 4.2, 5, 5.1, 6, 8, **verificada por búsqueda web el 2026-06-10** · RFC 8259 (JSON) · RFC 2119 (palabras clave normativas, invocada por la sección 2 de la spec) · RFC 9449:2023 (OAuth 2.0 DPoP), **verificado 2026-06-10** · RFC 7519 (JWT) · SPIFFE/SPIRE (X.509-SVID) · W3C Trace Context (header `traceparent`) |
| **Audiencia** | Doble: agentes que implementan o consumen cualquier endpoint del ecosistema; arquitecto y equipo humano |
| **Custodio** | Arquitecto del SBOS |
| **Fecha** | 2026-06-10 |

---

# PLANO COMPRENSIÓN (para el lector humano)

## 1. Por qué el SBOS necesita una lengua franca

Un ecosistema empresarial está hecho de docenas de sistemas que necesitan pedirse cosas:
"confirma esta venta", "crea este empleado", "genera esta factura ante el SIAT". Si cada
sistema habla su propio dialecto (REST aquí, SOAP allá, SQL directo más allá), cada
integración es un proyecto artesanal, cada auditoría una arqueología y cada agente de IA
un traductor a medida.

El SBOS resuelve esto con una **declaración de principios**, no solo con un formato:

> Toda la lógica de negocio vive en motores independientes de cualquier interfaz.
> Toda acción del ecosistema es una **orden de trabajo** expresada en un contrato único,
> predecible y auditable: **JSON-RPC 2.0**. Cualquier cliente — una interfaz web, un
> script nocturno, un daemon soberano o un agente de IA — pide la misma acción de la
> misma forma y recibe la respuesta en la misma estructura.

JSON-RPC encaja con el SBOS porque su modelo mental es el del negocio: se invocan
**acciones** (`fiscal.factura.anular.v1`), no se manipulan representaciones de recursos.
Confirmar una venta es una acción, no la edición de un documento. Además, el protocolo es
deliberadamente mínimo (define el mensaje, no el transporte), lo que permite que cada
clase de componente del SBOS lo lleve por el canal que su soberanía exige (§5).

## 2. La doctrina en cuatro frases

1. **El formato es uno:** todo mensaje de acción del SBOS es un objeto JSON-RPC 2.0
   conforme a la especificación de jsonrpc.org, con el perfil SBOS de §6.
2. **El transporte lo dicta la clase de soberanía** del componente que sirve la acción
   (§5): las aplicaciones y biedata lo sirven por HTTP; el bos lo sirve como Operator;
   bKernel no lo sirve — pero estructura intenciones compatibles (D2/D4).
3. **El método es la acción**, con nomenclatura jerárquica y versionada (§7).
   "El RPC siempre hace algo": no existen métodos decorativos.
4. **El nexo universal de datos es biedata** — *SBOS Data Gateway: Sovereign Data
   Exchange Engine* (identidad completa: → BOS-ECO-000 §2.2). Su servidor JSON-RPC
   `:9470` es la puerta única en ambas direcciones y para ambos mundos: el exterior
   (sistemas de terceros, bancos, pasarelas, organismos, legacy) y el interior del
   stack. D1 norma una de sus caras: toda escritura de negocio del ecosistema, incluso
   hacia aplicaciones nativas JSON-RPC, se ejecuta a través de su pipeline de fichas.
   El Patrón Fachada-RPC del Manual (Parte 8) se materializa en el SBOS como fichas de
   biedata, no como microservicios sueltos (§9.3).

## 3. El mapa: quién habla JSON-RPC y cómo

```
   MUNDO EXTERIOR
 entes regulados ◀──API HTTP──▶ APP AUTORIZADA (variable ilustrativa, D10 — p. ej. un
   │  ▲                          sistema de facturación: obtiene su autorización y
   │  │ datos: archivos legacy   escribe SOLO en SU propia BD; bKernel la escucha por
   │  │ (DBF/CSV/XLSX) · volúmenes   WAL como a toda BD del stack y organiza la
   ▼  │ import/export                actualización del ecosistema — D9/D10)
┌─────┴──────────────────────────────────────────────┐
│         biedata — SBOS DATA GATEWAY                │       CLIENTES INTERNOS
│         Sovereign Data Exchange Engine             │  Web UI · App móvil · scripts ·
│  CAJA CERRADA (D9): solo actualiza las BDs por     │  agentes IA · Core UI · btax ·
│  consumo y emisión de DATOS                        │  Smarts
│  A) gateway externo de datos (no de diálogos       │◀──────│ JSON-RPC POST /rpc
│     API regulados — esos son de cada app, D9)      │
│  B) ejecutor universal interno (100% escrituras,D1)│       ┌────────────────────┐
│  C) aduana de calidad (validation.yml)             │◀──────│  bos (IAM Operator)│
│  motor recursivo de fichas · tiers por tenant ·    │ RPC   │  bos.* · sagas (D8)│
│  entrega multi-formato · :9470 POST /rpc           │ (D8)  └────────────────────┘
└───────┬────────────────────────▲───────────────────┘
        │ escribe                │ Redis Streams
        │ origin='biedata'       │ bkernel:stream:biedata.* (intenciones)
        ▼                        │
┌───────────────┐            ┌───┴────────────────┐
│  APLICACIONES │ WAL/Binlog │      bKernel       │  NO sirve JSON-RPC (D2)
│  Cat. A/B/C   │───────────▶│ escucha · decide · │  cero puertos de entrada
│  Tryton, etc. │ (escucha)  │ estructura         │  inputs: CDC + señales
└───────────────┘            │ INTENCIONES        │  9460/9461 solo lectura
                             │ compatibles RPC    │
                             └────────────────────┘
```

La asimetría es deliberada y es la esencia de la arquitectura: **todos los componentes
hablan la lengua franca, pero no todos la *sirven***. bKernel la habla "por escrito"
(estructura intenciones en formato compatible y las publica a streams) sin abrir jamás
una puerta de entrada. Esa es su frontera literal: superficie de ataque cero.

---

# PLANO ESPECIFICACIÓN (para el agente)

## 4. Referencias normativas verificadas (D7)

Investigación de respaldo ejecutada el **2026-06-10** durante la redacción de este
documento, conforme a la regla D7 (toda resolución respaldada por investigación citada):

| Norma | Estado verificado | Uso en el SBOS |
|---|---|---|
| **JSON-RPC 2.0 Specification** — https://www.jsonrpc.org/specification | Verificada por fetch directo. Versión de origen 2010-03-26, última actualización 2013-01-04, JSON-RPC Working Group. Secciones: 1 Overview, 2 Conventions, 3 Compatibility, 4 Request object, 4.1 Notification, 4.2 Parameter Structures, 5 Response object, 5.1 Error object, 6 Batch, 7 Examples, 8 Extensions | Base normativa del sobre (§6). Las palabras clave MUST/SHOULD se interpretan según RFC 2119 (spec §2) |
| **RFC 8259** — The JavaScript Object Notation (JSON) Data Interchange Format | STD 90, diciembre 2017; obsoleta a RFC 7159, que obsoletó a RFC 4627 (el citado por la spec original) | Formato de serialización. El perfil SBOS exige UTF-8 (RFC 8259 §8.1: "MUST be encoded using UTF-8" para texto intercambiado entre sistemas) |
| **RFC 2119** — Key words for use in RFCs | BCP 14 | Interpretación de MUST/SHOULD/MAY en este documento y en la spec |
| **RFC 9449** — OAuth 2.0 Demonstrating Proof of Possession (DPoP) | Verificado: IETF Standards Track, septiembre 2023. Mecanismo a nivel de aplicación para ligar tokens de acceso y refresh a un par de claves del cliente mediante el header `DPoP` (un JWT de prueba); detecta replay de tokens | Autenticación daemon↔daemon sobre HTTP del plano RPC (§11): biedata acepta JWT client_credentials con prueba DPoP |
| **RFC 7519** — JSON Web Token | Standards Track, 2015 | Formato del Bearer y del DPoP proof |
| **SPIFFE / X.509-SVID** | Proyecto graduado CNCF; SVID = SPIFFE Verifiable Identity Document | Identidad de carga de trabajo de los daemons (`spiffe://sbos.skull/daemon/<nombre>`); mTLS interno y exterior |
| **W3C Trace Context** | Recommendation | Propagación `traceparent` end-to-end; el detalle vive en → BOS-ECO-030 |

Nota de vigencia: la especificación JSON-RPC 2.0 es estable desde 2013 y no tiene
sucesora; es la referencia activa de ecosistemas contemporáneos (p. ej. Model Context
Protocol y A2A la adoptan como capa de mensajería). El SBOS la adopta tal cual y la
restringe mediante el perfil de §6 — perfilar es legítimo, contradecirla no.

## 5. Doctrina de transporte por clase de soberanía (D4)

### 5.1 La regla

El formato del mensaje es invariante; el transporte NO. Cada clase de componente sirve
(o no sirve) JSON-RPC según lo que su soberanía permite exponer:

| Clase de soberanía | Componentes | ¿Sirve JSON-RPC? | Transporte de servicio | Puertos (norma SBOS-050, D5) |
|---|---|---|---|---|
| **Aplicación de negocio** (Cat. A/B, §9) | Tryton, apps nuevas del manual | SÍ | HTTP `POST /rpc/` dentro del mesh | el de cada app (p. ej. Tryton :8000) |
| **Gateway de datos soberano** | biedata (*SBOS Data Gateway: Sovereign Data Exchange Engine*) | SÍ — JSON-RPC 2.0 **exclusivo**: caja cerrada (D9) que solo actualiza las BDs por consumo y emisión de datos; ejecutor del 100% de las escrituras (D1), aduana de calidad, motor recursivo con tiers por tenant | HTTP `POST /rpc`, endpoint único; además canales de intercambio de DATOS propios de su dominio: file-watch, schedules, volúmenes import/export (→ BOS-biedata-080/090; intercambio de DATOS no regulado: dominio de biedata (D9/D10)). Los diálogos API HTTP exteriores regulados NO son suyos (D9) | **:9470** API JSON-RPC · :9471 métricas · :9472 healthcheck |
| **Aplicación con comunicación exterior regulada** | variable en el tiempo (D10): las que la ley autorice — un sistema de facturación es solo el ejemplo ilustrativo | sirve/consume lo que su catálogo defina como app del stack; hacia el ENTE exterior usa el protocolo que la norma estatal exige | API HTTP exterior PROPIA — excepción regulatoria a "cero HTTP" (D9). Hacia el stack escribe SOLO en SU propia BD; bKernel la escucha por WAL (D10) | los de cada aplicación |
| **Operator de infraestructura** | bos | SÍ — métodos `bos.*` (sagas de gobierno, fichas, tenants) | su API de Operator (:9440 familia) | :9440–:9443 según BOS-REPAIR/SBOS-050 |
| **Kernel del plano de datos** | bKernel | **NO** (D2) — ni HTTP, ni socket Unix (propuesta UDS RECHAZADA, R2) | n/a — *emite* intenciones compatibles JSON-RPC por Redis Streams `bkernel:stream:biedata.*` | :9460 métricas · :9461 healthcheck (ambos solo lectura, no son entrada de órdenes) |
| **Clientes** | UI, scripts, agentes IA, Core UI | No sirven: consumen | HTTP hacia apps/biedata/bos | n/a |

### 5.2 Reglas normativas del transporte HTTP (perfil SBOS)

Para todo componente que SÍ sirve JSON-RPC sobre HTTP:

1. Método HTTP: siempre `POST`. `Content-Type: application/json` obligatorio en ambas
   direcciones (capa 1 de seguridad, §11).
2. **Endpoint único** por motor: `POST /rpc` (biedata) o `POST /rpc/` (apps del manual).
   No existen paths de recurso (`/api/v1/...`): la operación la identifica el `method`.
3. La respuesta de negocio viaja SIEMPRE con HTTP 200; el éxito o el error van en el
   cuerpo JSON-RPC. Los códigos HTTP se reservan para infraestructura:
   `401` sesión/token inválido en la capa de transporte, `404` el endpoint no existe,
   `500` fallo de infraestructura del servidor.
4. Autenticación por header `Authorization` (Bearer JWT) más prueba `DPoP` cuando el
   caller es un daemon (§11). mTLS según la zona (mesh interno / conexiones al exterior).
5. El header `traceparent` (W3C Trace Context) se propaga en toda llamada; el `ctx_id`
   del Context Plane viaja en `params._ctx_id` (§6.4).

### 5.3 Reglas normativas de los streams (bKernel → biedata)

bKernel no transporta por HTTP: publica en **Redis Streams** (`bkernel:stream:biedata.*`).
La intención publicada es un objeto **compatible con JSON-RPC 2.0 Request** (§10), de modo
que biedata la procesa con el mismo pipeline conceptual que una llamada HTTP, previa
deduplicación en su Inbox (`_inbox`, `UNIQUE(event_id)`). El contrato de wire completo
(claves del stream, campos del sobre de intención, idempotencia bilateral, reintentos,
comportamiento ante caída) es SSOT de → BOS-ECO-020 y no se duplica aquí.

### 5.4 Supersesión registrada: ADR-012 del manual de acoplamiento v2.0

El `SBOS-MANUAL-ACOPLAMIENTO` v2.0 (mayo 2026) declaraba "HTTP entre daemons está vetado;
toda comunicación entre daemons usa WebSocket o Unix socket" (ADR-012). La doctrina D4,
dictada y validada por el arquitecto con posterioridad (R2, junio 2026, resolución C-13),
**supersede ese veto en el plano de acciones JSON-RPC**: el bos administra a biedata
mediante su RPC `:9470` sobre HTTP, y las aplicaciones sirven JSON-RPC sobre HTTP.
El espíritu del ADR-012 (minimizar superficie y canales ad-hoc) sobrevive donde importa:
bKernel sigue sin servir nada (D2) y los canales WebSocket/Unix socket existentes de otros
daemons (bAuth, Par Nexus, MCP sockets) no se ven afectados por esta doctrina.
No es un conflicto nuevo: es una decisión congelada ya validada que aquí queda
documentada con su alcance exacto.

## 6. El sobre JSON-RPC 2.0 — requisitos normativos y perfil SBOS

### 6.1 Request (spec §4)

Requisitos de la especificación (verbatim normativo mínimo, verificado 2026-06-10):

- `jsonrpc`: String; MUST ser exactamente `"2.0"`.
- `method`: String con el nombre del procedimiento. Los nombres que comienzan con `rpc.`
  (la palabra `rpc` seguida de punto, U+002E) están **reservados** para métodos y
  extensiones internas del protocolo y MUST NOT usarse para otra cosa (spec §4 y §8).
- `params`: valor estructurado (Array por posición u Object por nombre, spec §4.2);
  MAY omitirse.
- `id`: String, Number o Null si se incluye; si se omite, la petición es una
  **Notificación** (spec §4.1) y el servidor MUST NOT responderla. La spec desaconseja
  `id` Null (colisiona con la señal de "id desconocido" en errores) y desaconseja
  Numbers con parte fraccionaria.

**Perfil SBOS (restricciones adicionales, todas compatibles con la spec):**

| Regla | Valor SBOS | Justificación |
|---|---|---|
| `jsonrpc` | obligatorio siempre (no se omite como permitía el estilo didáctico del Manual Parte 1) | distingue 2.0 de 1.0 (spec §3); los validadores lo exigen |
| `id` | String UUID o identificador único de la sesión de trabajo (`"req-uuid-001"`); **nunca** Null en peticiones; obligatorio en toda acción de negocio | correlación, Inbox de biedata (`event_id`), auditoría forense |
| Notificaciones | permitidas SOLO para telemetría y logging; **prohibidas para acciones de negocio** | una escritura de negocio sin respuesta confirmable viola la auditabilidad (spec §4.1: las notificaciones no son confirmables por definición) |
| `params` | Object por nombre (by-name) en todo método del perfil SBOS (fichas biedata, bos.*); las apps Cat. A conservan su estilo nativo (Tryton: posicional) | legibilidad, evolución de contratos sin romper posiciones |
| `params._ctx_id` | obligatorio en toda acción de negocio: el ctx_id del Context Plane | trazabilidad SBOS-049; → BOS-ECO-030 |
| Extensión `delivery` | miembro raíz adicional del Request, exclusivo de biedata (directiva de entrega: `json-rpc` / `transform` / `document` / `relay`) | extensión compatible: la spec no prohíbe miembros adicionales; especificación completa en → BOS-biedata-060 |
| Codificación | UTF-8 obligatorio | RFC 8259 §8.1 |

### 6.2 Response (spec §5)

- El servidor MUST responder a toda petición con `id` (salvo notificaciones).
- Miembros: `jsonrpc` (MUST `"2.0"`), `id` (MUST igual al de la petición; Null solo si el
  `id` no pudo detectarse, p. ej. Parse error), y **exactamente uno** de:
  - `result` — REQUIRED en éxito; MUST NOT existir si hubo error;
  - `error` — REQUIRED en error; MUST NOT existir si no lo hubo; MUST ser un Object
    conforme a spec §5.1.
- Regla de oro de la spec §5: `result` y `error` son mutuamente excluyentes — uno de los
  dos MUST incluirse, ambos a la vez MUST NOT.

**Perfil SBOS:** las implementaciones del ecosistema NO emiten el estilo laxo
`{"result": true, "error": null}` del Manual didáctico: emiten el miembro presente y
omiten el ausente, conforme estricto a spec §5. Los catálogos de biedata añaden dentro de
`result` su estructura consistente de operación (`status`, `task_results`, `audit_id` —
SSOT en → BOS-biedata-060 §8).

### 6.3 Error object (spec §5.1) y doctrina de códigos

Estructura: `code` (Number, MUST ser entero), `message` (String, una frase concisa),
`data` (Primitivo o Estructurado, opcional, definido por el servidor).

Rango reservado por la spec: **-32768 a -32000** para errores predefinidos; el resto del
espacio queda para errores de aplicación. Tabla canónica del SBOS:

| Código | Nombre | Origen | Semántica SBOS |
|---|---|---|---|
| -32700 | Parse error | spec | JSON inválido o Content-Type incorrecto |
| -32600 | Invalid Request | spec | el objeto no es un Request válido |
| -32601 | Method not found | spec | no existe ficha/método con ese nombre |
| -32602 | Invalid params | spec | validación de parámetros rechazada (en biedata: `validation.yml`) |
| -32603 | Internal error | spec | error interno del pipeline |
| -32000 | Server error | rango impl. | BD no disponible — reintentar con backoff exponencial |
| -32001 | Unauthorized | rango impl. | JWT inválido/expirado o ctx_id no reconocido |
| -32002 | Forbidden | rango impl. | BitMask insuficiente para el método |
| -32003 | Rate limited | rango impl. | límite alcanzado — esperar y reintentar |
| -32004 | Gone | rango impl. | versión de método en sunset — migrar |
| -32005 | Payload too large | rango impl. | params supera el límite configurado |

Doctrina: **todo motor del ecosistema usa esta tabla**. Un motor MAY añadir códigos
propios dentro de -32006…-32099 registrándolos en su documento de protocolo y en el
registro del ecosistema (§12.2); MUST NOT resignificar los ya asignados.

### 6.4 Batch (spec §6) — posición doctrinal

La spec permite enviar un Array de Requests; el servidor MAY procesarlos con cualquier
paralelismo y responder en cualquier orden (correlación por `id`); un batch vacío o
inválido produce un único Response de error.

**Perfil SBOS:** los batches están permitidos en lecturas (outbound) y PROHIBIDOS para
acciones de escritura de negocio hacia biedata: las escrituras masivas se expresan con
métodos explícitos (`*.bulk_insertar.vN`, `*.bulk_sincronizar.vN`), porque el batch del
protocolo no define semántica transaccional ni de compensación, y el pipeline de fichas sí.

## 7. Doctrina de nomenclatura de métodos

### 7.1 Los espacios de nombres del ecosistema

| Espacio | Quién lo sirve | Forma | Ejemplos |
|---|---|---|---|
| `<dominio>.<recurso>.<accion>.vN` | **biedata** (fichas) | snake_case, verbo en infinitivo, **sufijo de versión SIEMPRE presente** | `fiscal.factura.anular.v1`, `inventario.producto.insertar.v2`, `ventas.pedido.generar.v3` |
| `bos.*` | **bos** (Operator) | `bos.<área>.<acción>` | `bos.ficha.install`, `bos.ficha.repair`, `bos.maintenance.enable`, `bos.tenant.suspend` |
| `common.*` / `system.*` | todo motor que sirve RPC | introspección y sesión | `common.server.version` (el "ping" estándar), `system.listMethods`, `system.methodHelp` |
| `model.<entidad>.*` / `wizard.*` / `report.*` | aplicaciones Cat. A/B | catálogo nativo de la app | `model.venta.confirm` (Tryton) |
| `flujo.*` | motores de orquestación Cat. D (§9.4) | flujos multi-motor expuestos como métodos | `flujo.empleado.alta` |
| `rpc.*` | **NADIE** | **reservado por la spec §8** — MUST NOT usarse | — |

### 7.2 Reglas del perfil

1. **El método ES la acción** ("el RPC siempre hace algo"). Nombres como `facturas.3451`
   (no es acción), `inventario.post` (verbo HTTP) o `update_invoice_data` (sin jerarquía)
   son no conformes.
2. **Versionado en el nombre, no en el endpoint.** El sufijo `.vN` es la versión de
   contrato visible al caller; solo cambia ante ruptura de contrato. La versión de
   implementación (SemVer interno del `manifest.yml`) es invisible al caller. El alias
   sin sufijo es un puntero dinámico al tier contratado por el tenant, no un método
   propio. Especificación completa del versionado: → BOS-biedata-060 y gobierno en
   → BOS-biedata-040.
3. **Acciones base de modelos (Cat. A/B):** `create / read / write / delete / search /
   search_read`, con nombres exactos; las transiciones de estado se nombran con el verbo
   de la transición (`confirm`, `cancel`, `process`).
4. **Catálogo de verbos de fichas biedata:** `insertar`, `actualizar`, `actualizar_datos`,
   `eliminar`, `anular`, `sincronizar` (upsert), `bulk_insertar`, `bulk_sincronizar`,
   `generar`, `obtener`, `listar`, `buscar` y verbos específicos de dominio
   (`obtener_cuf`, `persistir_cuf`, `resetear_password`). SSOT del catálogo completo:
   → BOS-biedata-060 §2.
5. La consistencia es contrato: quien sabe invocar `inventario.producto.insertar.v1`
   deduce `inventario.producto.actualizar.v1` sin documentación adicional.

## 8. El endpoint único y la verificación de vida

Todo motor que sirve JSON-RPC expone **exactamente un endpoint** de operaciones
(`POST /rpc`). El descubrimiento es por introspección (`system.listMethods`) y por el
registro del ecosistema (§12.2), nunca por enumeración de paths.

Verificación de vida estándar del ecosistema (sin autenticación):

```bash
curl -s -X POST https://<motor>/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":"ping-1","method":"common.server.version","params":{}}'
# → {"jsonrpc":"2.0","id":"ping-1","result":"<versión>"}
```

Los healthchecks de plataforma (Kubernetes/systemd/bos) NO usan el endpoint RPC: usan los
puertos de healthcheck del catálogo (biedata :9472, bKernel :9461), que son HTTP simples de
solo lectura. El endpoint RPC mide capacidad de servicio; el healthcheck mide vida del
proceso. No se mezclan.

## 9. Las categorías de aplicaciones y su materialización en el SBOS

### 9.1 Taxonomía (Manual Parte 8, perfilada)

| Cat. | Definición | Ejemplo SBOS | Estrategia |
|---|---|---|---|
| **A** | Nativa JSON-RPC | Tryton (ERP) | documentar y aprovechar su catálogo |
| **B** | Nueva, construida bajo el manual | subproyectos nuevos del SBOS | estándar desde el día 1 |
| **C** | Legada o externa sin JSON-RPC (REST/SOAP/propietaria/archivos) | OrangeHRM; sistemas legacy (FoxPro/DBF, Excel/CSV masivo); intercambio de datos con terceros | Fachada-RPC — en el SBOS: **ficha de biedata** (tareas RPC) o **caja de biedata** (import/export masivo) (§9.3). EXCLUIDOS por D9: los entes exteriores regulados (fiscal, etc.) — su diálogo API HTTP lo ejecuta la aplicación autorizada (btax), no una fachada de biedata; el reparto del resto del exterior se rige por D9/D10: regulado → la app; intercambio de datos → biedata |
| **D** | Motor de orquestación de flujos multi-motor | ver §9.4 | expone flujos como métodos `flujo.*` |

### 9.2 Principio de paridad y motores puros

Una aplicación del ecosistema es **exclusivamente un motor de procesamiento**: ejecuta
lógica, mantiene estado, valida, persiste y expone operaciones vía JSON-RPC. No renderiza,
no decide presentación, no distingue si el caller es humano, script o agente. La interfaz
propia no tiene privilegios: web, binario nativo y línea de comandos envían exactamente el
mismo JSON. Consecuencias verificables: cero lógica duplicada, integraciones = "qué
métodos llamo", testing de negocio directo contra el motor, agentes de IA operables con
solo el catálogo de métodos.

### 9.3 La corrección doctrinal D1: la fachada universal es biedata

El Manual (Parte 8 §§7–9) describe la Fachada-RPC como un servicio independiente que
envuelve a la app legada (su propio `main.py`, sus propios usuarios). **En el SBOS esa
materialización queda perfilada por D1:** biedata ES la fachada JSON-RPC universal del
ecosistema. Cada aplicación legada se envuelve como **ficha de biedata** (manifest +
validation + task_catalog), no como microservicio suelto:

```
Manual genérico (Parte 8):              Perfil SBOS (D1):
cliente ─RPC→ Fachada-OrangeHRM ─REST→  cliente/bKernel ─RPC/stream→ biedata
              (servicio propio)                       ficha rrhh.* ─REST OAuth2→ OrangeHRM
```

Esto vale TAMBIÉN para las aplicaciones Categoría A: aunque Tryton sirve JSON-RPC nativo,
las escrituras de negocio del ecosistema hacia Tryton pasan por la ficha de biedata que
invoca ese RPC nativo (D1: "sin excepciones"). El catálogo nativo de Tryton queda
disponible para lecturas y para sus propios clientes de interfaz; la **escritura
orquestada por el ecosistema** tiene un solo ejecutor. Beneficios que la doctrina compra:
credenciales de TODAS las apps destino en un solo scope Vault (biedata), un solo punto de
auditoría de escritura, un solo emisor de `origin='biedata'` para el anti-loop (D3).

**La fachada opera en ambas direcciones y hacia ambos mundos.** No es solo "escritura
interna": las fichas *outbound* (SELECT-only, frontera F4 de biedata) exponen lecturas
compuestas del stack al exterior y a los Smarts; las cajas exportan hacia destinos
externos (HTTP/SOAP mTLS, SFTP, archivos) y las cajas/fichas inbound importan desde el
exterior (file-watch, webhooks, APIs) — todo bajo la misma aduana de calidad y la misma
auditoría. La analogía canónica del corpus N1 lo resume: **biedata es el Tryton JSON-RPC
del ecosistema completo** — el motor de procesamiento al que todo el mundo, interno o
externo, le ordena trabajo.

### 9.4 Categoría D en el SBOS: quién orquesta qué

El Manual Parte 9 define el motor de orquestación (sagas con compensación, flujos
declarativos YAML, propagación de contexto). En el SBOS esa responsabilidad se reparte
por soberanía — no existe un "orquestador" monolítico:

| Plano | Orquestador | Qué coordina | Dónde se especifica |
|---|---|---|---|
| Datos / negocio | **bKernel** (como DECISOR: construye la secuencia de intenciones, sagas y compensaciones; jamás ejecuta) | flujos derivados de eventos CDC que cruzan varias apps | → BOS-bKernel-090 · contrato en → BOS-ECO-020 |
| Ejecución | **biedata** (pipeline de tareas encadenadas dentro de una ficha; compensaciones locales) | los pasos internos de una orden de trabajo | → BOS-biedata-070 / -120 |
| Gobierno / infraestructura | **bos** (sagas `bos.*` con compensación, p. ej. alta de tenant en 7 pasos) | ciclo de vida de fichas, tenants, daemons | → BOS-ECO-030 · BOS-REPAIR (referencia) |

El patrón Saga (consistencia sin transacciones distribuidas, compensaciones idempotentes,
contexto inmutable a través de los pasos) es doctrina común a los tres planos; cada plano
lo implementa en su documento SSOT.

## 10. La intención estructurada de bKernel (doctrina)

bKernel "habla" la lengua franca sin servirla: el payload de cada intención que publica en
`bkernel:stream:biedata.*` **ES un objeto compatible con JSON-RPC 2.0 Request**, envuelto
en el sobre de evento del contrato bilateral. Forma doctrinal (ilustrativa — el contrato
de wire normativo, campo a campo, es SSOT de → BOS-ECO-020):

```json
{
  "event_id": "01HZX7Q8K9P2M4N6R8T0V2W4Y6",
  "event_timestamp": "2026-06-10T14:23:05.123456789Z",
  "source_checkpoint": "LSN:16/B374D848",
  "origin_chain": ["tryton_db"],
  "intent": {
    "jsonrpc": "2.0",
    "id": "01HZX7Q8K9P2M4N6R8T0V2W4Y6",
    "method": "rrhh.empleado.sincronizar.v1",
    "params": { "codigo": "EMP-0042", "nombre": "Ana Quispe", "_ctx_id": "ctx-88291-a4f9" }
  }
}
```

Reglas doctrinales: el `intent.id` coincide con el `event_id` (es la clave de
deduplicación del Inbox de biedata); el `method` referencia una ficha biedata versionada
(§7); la "respuesta" no viaja de vuelta por el stream — el ciclo se cierra por WAL (D3):
bKernel observa la escritura resultante de biedata en la BD destino. Por eso la intención
es estructuralmente una Request con `id` (auditable y correlacionable) aunque su canal no
devuelva Response: la confirmación es el propio evento CDC de la escritura ejecutada.

## 11. Doctrina de seguridad del plano RPC

Las cuatro capas (especificación completa: → BOS-biedata-060 §6 y → BOS-biedata-110;
aquí la doctrina que TODO motor del ecosistema replica):

```
Capa 1  Transporte y forma      Content-Type application/json; TLS/mTLS según zona
Capa 2  Sintaxis del protocolo  Request válido spec §4 (si no: -32700 / -32600)
Capa 3  Identidad y autorización JWT Bearer (+ DPoP RFC 9449 para daemons) → BitMask
                                 (si no: -32001 / -32002)
Capa 4  Semántica               validación declarativa de params (si no: -32602)
```

Si cualquier capa falla, la lógica de negocio nunca se ejecuta.

Identidad por tipo de caller:

| Caller | Credencial | Norma |
|---|---|---|
| Usuario (vía UI/cliente) | JWT de Keycloak con BitMask de 64 bits; `_ctx_id` activo | RFC 7519; SBOS-049 |
| Daemon → daemon (p. ej. bos→biedata) | JWT `client_credentials` + **prueba DPoP** (header `DPoP`, JWT que demuestra posesión de la clave privada y liga el token al par de claves — anti-replay) | **RFC 9449** (verificado 2026-06-10) |
| Identidad de carga de trabajo | X.509-SVID (`spiffe://sbos.skull/daemon/biedata`), TTL 1 h, rotación 30 min | SPIFFE |
| Aplicación regulada → ente exterior (D9) | la credencial y el canal que la norma estatal exige a ESA aplicación (p. ej. certificado de SIF para btax); biedata no interviene en ese diálogo | normativa de cada ente; → bd-020 documenta el marco, la app documenta su cumplimiento |

bKernel queda doctrinalmente FUERA de esta matriz como servidor (no autentica callers
porque no tiene callers, D2); como *publicador* se autentica ante Redis con su SVID/ACL —
detalle en → BOS-ECO-020.

## 12. Código y artefactos de referencia

### 12.1 El sobre en Rust (perfil SBOS, serde) — tipos de referencia

Tipos compartidos conceptualmente por biedata (servidor), bKernel (constructor de
intenciones) y cualquier motor Cat. B en Rust. El crate real se define en los documentos
de arquitectura; estas firmas son el contrato estructural que el implementador NO inventa:

```rust
//! sobre JSON-RPC 2.0 — perfil SBOS (BOS-ECO-010 §6)
use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};

pub const JSONRPC_VERSION: &str = "2.0";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcRequest {
    /// MUST ser exactamente "2.0" (spec §4); obligatorio en el perfil SBOS (§6.1)
    pub jsonrpc: String,
    /// String único (UUID/ULID). Nunca Null en peticiones SBOS. Ausente => Notificación.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id: Option<String>,
    /// dominio.recurso.accion.vN | bos.* | common.* | system.* — jamás rpc.* (spec §8)
    pub method: String,
    /// Perfil SBOS: Object by-name (spec §4.2). Debe contener "_ctx_id" en acciones de negocio.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub params: Option<Map<String, Value>>,
    /// Extensión SBOS exclusiva de biedata: directiva de entrega (→ BOS-biedata-060 §4)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub delivery: Option<DeliveryDirective>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum DeliveryFormat { JsonRpc, Transform, Document, Relay }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeliveryDirective {
    pub format: DeliveryFormat,
    #[serde(flatten)]
    pub options: Map<String, Value>,
}

/// Respuesta: result XOR error (spec §5). El enum hace inexpresable el estado ilegal.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum JsonRpcResponse {
    Success { jsonrpc: String, id: Value, result: Value },
    Failure { jsonrpc: String, id: Value, error: JsonRpcError },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcError {
    /// MUST ser entero (spec §5.1). Tabla canónica SBOS: §6.3
    pub code: i64,
    /// una frase concisa (spec §5.1)
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<Value>,
}

pub mod codes {
    pub const PARSE_ERROR: i64 = -32700;
    pub const INVALID_REQUEST: i64 = -32600;
    pub const METHOD_NOT_FOUND: i64 = -32601;
    pub const INVALID_PARAMS: i64 = -32602;
    pub const INTERNAL_ERROR: i64 = -32603;
    pub const SERVER_ERROR: i64 = -32000;
    pub const UNAUTHORIZED: i64 = -32001;
    pub const FORBIDDEN: i64 = -32002;
    pub const RATE_LIMITED: i64 = -32003;
    pub const GONE: i64 = -32004;
    pub const PAYLOAD_TOO_LARGE: i64 = -32005;
}

impl JsonRpcRequest {
    /// Validación del perfil SBOS (capa 2 + reglas §6.1). No valida semántica (capa 4).
    pub fn validate_sbos_profile(&self) -> Result<(), JsonRpcError> {
        if self.jsonrpc != JSONRPC_VERSION {
            return Err(invalid_request("jsonrpc debe ser exactamente \"2.0\""));
        }
        if self.method.starts_with("rpc.") {
            return Err(invalid_request("el prefijo rpc. está reservado (spec §8)"));
        }
        if self.id.is_none() && !self.method.starts_with("log.") {
            return Err(invalid_request(
                "las notificaciones solo se admiten para telemetría/logging (perfil §6.1)",
            ));
        }
        Ok(())
    }
}

fn invalid_request(detail: &str) -> JsonRpcError {
    JsonRpcError { code: codes::INVALID_REQUEST, message: "Invalid Request".into(),
                   data: Some(serde_json::json!({ "detail": detail })) }
}
```

### 12.2 Registro del ecosistema (YAML de referencia)

Inventario gobernado de motores — quién sirve qué, en qué clase de soberanía. El custodio
operativo del registro es el bos (`app_registry`, → BOS-ECO-030); este YAML es su forma
declarativa de referencia:

```yaml
# ecosystem-registry.yml — registro de motores JSON-RPC del SBOS
version: 1
engines:
  - name: tryton
    category: A                   # nativa JSON-RPC
    endpoint: http://tryton.apps.svc:8000/rpc/
    catalog_style: model.*        # posicional, catálogo nativo
    writes_via: biedata           # D1: escritura del ecosistema vía ficha biedata
  - name: biedata
    category: gateway             # Sovereign Data Exchange Engine: nexo exterior + ejecutor interno + aduana de calidad
    endpoint: http://biedata.host:9470/rpc
    catalog_style: dominio.recurso.accion.vN
    ports: { api: 9470, metrics: 9471, health: 9472 }   # SBOS-050 (D5)
  - name: bos
    category: operator
    methods_prefix: bos.
  - name: bkernel
    category: kernel
    serves_rpc: false             # D2 — literal
    emits_intents_to: "bkernel:stream:biedata.*"
    ports: { metrics: 9460, health: 9461 }              # solo lectura
  # NOTA D10: TODA entrada de aplicación en este registro es una VARIABLE en el tiempo,
  # nunca una constante del diseño. Las entradas siguientes son ejemplos ilustrativos.
  - name: app_facturacion_ejemplo   # variable ilustrativa (D9/D10) — hoy puede ser una, mañana otra
    category: regulated-exterior    # autorizada por ley: diálogo API HTTP exterior PROPIO
    exterior_dialogue: own          # obtiene su autorización; biedata no interviene en ese diálogo
    writes: own_database_only       # cero invasión (D10): bKernel escucha su BD por WAL
  - name: orangehrm
    category: C                   # legada — fachada = ficha biedata (perfil §9.3)
    facade: biedata/fichas/rrhh.*
    native_api: REST OAuth2
    cdc_source: mysql-binlog      # doble rol C-11: fuente CDC sí, destino vía biedata
governance:
  reserved_prefixes: [rpc.]       # spec §8
  error_codes_authority: BOS-ECO-010 §6.3
  new_engine_checklist: BOS-ECO-010 §13.2
```

### 12.3 Procedimiento para incorporar un motor nuevo (gobernanza)

1. Clasificarlo (A/B/C/D, §9.1). Si es C, su fachada nace como ficha(s) de biedata.
2. Declarar su catálogo de métodos conforme a §7 y publicar `system.listMethods`.
3. Adoptar la tabla de errores §6.3; registrar códigos propios si los necesita.
4. Registrarse en el registro del ecosistema (§12.2) vía el bos.
5. Si sus datos son fuente CDC, declarar la ficha bKernel correspondiente
   (→ BOS-bKernel-140); sus escrituras de negocio llegan SIEMPRE vía biedata (D1).
6. Superar los criterios de conformidad de §13.

## 13. Criterios de conformidad (DADO / CUANDO / ENTONCES)

**CONF-RPC-01 — Sobre estricto.**
DADO un motor del ecosistema que sirve JSON-RPC, CUANDO recibe una petición con
`jsonrpc` ≠ `"2.0"`, o con `method` iniciando en `rpc.`, o con `result` y `error`
simultáneos en tránsito de respuesta, ENTONCES la rechaza/no la emite, respondiendo
`-32600` con detalle en `error.data`, y el evento queda en su log con `traceparent`.

**CONF-RPC-02 — Endpoint único.**
DADO cualquier motor conforme, CUANDO un cliente invoca `common.server.version` por
`POST /rpc` sin autenticación, ENTONCES recibe HTTP 200 con `result` igual a la versión
del motor; y CUANDO invoca cualquier path de recurso tipo `/api/v1/...`, ENTONCES recibe
HTTP 404 (el endpoint no existe).

**CONF-RPC-03 — Errores canónicos.**
DADO un caller con JWT expirado, CUANDO invoca cualquier método de negocio, ENTONCES la
respuesta es el error `-32001` (tabla §6.3) con HTTP 200 si el rechazo lo emite la capa
de protocolo, o HTTP 401 si lo emite la capa de transporte — nunca un código inventado.

**CONF-RPC-04 — bKernel no sirve.**
DADO el host de bKernel en operación, CUANDO se escanean sus puertos y sockets, ENTONCES
solo existen 9460 y 9461 (solo lectura) y ningún listener adicional (ni TCP ni Unix);
y CUANDO se publica una intención bien formada en `bkernel:stream:biedata.*` desde un
tercero no autorizado, ENTONCES biedata la descarta por fallo de autenticación del
publicador (→ BOS-ECO-020) — bKernel mismo no posee vía alguna de recepción de órdenes.

**CONF-RPC-05 — Escritura única (D1).**
DADO cualquier flujo end-to-end del ecosistema que termina en una escritura de negocio,
CUANDO se audita la escritura en la BD/app destino, ENTONCES su `origin` es `'biedata'`
y existe el registro correlacionado en la auditoría de biedata (`audit_id`) y, si nació
de CDC, el `event_id` correspondiente en su Inbox.

**CONF-RPC-06 — Notificaciones acotadas.**
DADO un motor conforme, CUANDO recibe una petición sin `id` cuyo `method` es una acción
de negocio, ENTONCES no la ejecuta y la registra como violación del perfil (§6.1) —
las acciones de negocio exigen confirmabilidad.

## 14. Relación normativa con el Manual JSON-RPC (partes 1–9)

El Manual es **corpus normativo paralelo** (D4): no se renombra, no se absorbe, y es la
referencia didáctica y de implementación multi-lenguaje del protocolo. Este documento lo
perfila. Ante divergencia entre el Manual (genérico) y este perfil (SBOS), **gana el
perfil** dentro del SBOS:

| Parte | Contenido | Cómo la perfila el SBOS |
|---|---|---|
| 1 Fundamentos | mensaje, convenciones, transporte HTTP | §6 endurece: `jsonrpc` obligatorio, `id` String único, params by-name; §5.2 fija el endpoint |
| 2 Autenticación | login, tokens, headers | §11: Keycloak/JWT+BitMask y DPoP reemplazan los esquemas didácticos |
| 3 CRUD y contexto | acciones base, contexto de ejecución | §7.3; el `_ctx_id` del Context Plane sustituye el contexto libre |
| 4 Cadena de eventos | máquinas de estado, eslabones | doctrina intacta; en el SBOS la cadena inter-app la decide bKernel (§9.4) |
| 5 Arquitectura de servidor | dispatcher, capas, registro de métodos | patrón vigente para motores Cat. B; biedata tiene su propia arquitectura (→ BOS-biedata-050) |
| 6 Errores y producción | tipos de error, reintentos, checklist | §6.3 fija la tabla canónica; los reintentos de daemon van por contrato (→ BOS-ECO-020) |
| 7 Híbrida e integraciones | adaptadores, binarios, SIAT | los adaptadores viven en fichas/cajas de biedata (D1); → BOS-biedata-080 |
| 8 Ecosistema y adopción | categorías A/B/C, Fachada-RPC, gobernanza | §9: la Fachada-RPC se materializa como ficha biedata (corrección D1); gobernanza en §12.3 |
| 9 Orquestación multi-motor | Categoría D, sagas, flujos YAML | §9.4: la orquestación se reparte por soberanía (bKernel decide / biedata ejecuta / bos gobierna) |

---

## 15. Criterios de completitud de este documento

- [x] Doctrina D4 desarrollada sin reinterpretación: formato único, transporte por clase de soberanía, bKernel no sirve (D2), Manual como corpus paralelo.
- [x] Especificación JSON-RPC 2.0 verificada por búsqueda/fetch web el 2026-06-10 (jsonrpc.org, actualización 2013-01-04) y citada con sección exacta en cada requisito (§4, §4.1, §4.2, §5, §5.1, §6, §8).
- [x] Perfil SBOS del sobre definido (id, notificaciones, params by-name, `_ctx_id`, extensión `delivery`, batch acotado) sin contradecir la spec.
- [x] Tabla canónica de errores del ecosistema con rango de la spec respetado (-32768…-32000 reservado).
- [x] Doctrina de nomenclatura unificada (fichas biedata `.vN`, `bos.*`, catálogos nativos, `rpc.*` reservado).
- [x] Categorías A/B/C/D mapeadas al SBOS con la corrección D1 (fachada universal = biedata) y reparto de la orquestación por soberanía.
- [x] Posición de bKernel documentada: intención estructurada compatible Request, ciclo cerrado por WAL (D3); contrato de wire delegado a → BOS-ECO-020 (SSOT respetado).
- [x] Seguridad del plano RPC con normas verificadas (RFC 9449 DPoP — verificado 2026-06-10; RFC 7519; SPIFFE).
- [x] Código de referencia Rust (tipos serde + validación de perfil + códigos) y registro YAML del ecosistema incluidos (regla C.3: el implementador no inventa nada estructural).
- [x] Supersesión del ADR-012 (alcance exacto) documentada como decisión ya validada (C-13/D4), no como conflicto nuevo.
- [x] Seis criterios de conformidad en formato DADO/CUANDO/ENTONCES (ISO/IEC/IEEE 29148:2018).
- [x] Corrección v1.1 aplicada: biedata representado con su identidad completa de corpus N1 (fichas+cajas, tiers, aduana de calidad); lo fiscal acotado a un dominio.
- [x] v1.2: doctrina D9 propagada (mapa §3, soberanía §5.1, categorías §9.1, seguridad §11, registro §12.2): biedata caja cerrada; diálogos exteriores regulados = de cada aplicación autorizada.
- [x] v1.3: doctrina D10 propagada — toda aplicación nombrada (Tryton, OrangeHRM, sistema de facturación) marcada como variable ilustrativa; las apps escriben solo en su propia BD y bKernel las escucha por WAL.
- [ ] Validación del arquitecto (mueve el documento a VALIDADO).

---

*BOS-ECO-010 v1.3 · 2026-06-10 · El nombre del archivo es estable: la versión vive solo en estos metadatos.*
*Changelog — v1.3: D10 (aplicaciones como variables ilustrativas; cero invasión en mapa y registro). v1.2: D9 (biedata caja cerrada, diálogos exteriores regulados por aplicación). v1.1: identidad completa de biedata. v1.0: versión inicial.*
* El contrato bilateral bKernel↔biedata se especifica en → BOS-ECO-020 (Lote 2).*
*El protocolo completo de biedata es SSOT de → BOS-biedata-060. El Manual JSON-RPC 1–9 permanece como corpus normativo paralelo.*
