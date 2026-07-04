# Manual de Acoplamiento al SBOS
## Para IA y Equipos que Desarrollan Subproyectos
### SKULL · SBOS · v2.0 · Mayo 2026

---

## Instrucción de Lectura para la IA

Este documento debe leerse completo antes de conceptualizar cualquier subproyecto asociado al SBOS. No es opcional. Contiene los axiomas del ecosistema — las realidades técnicas que no son negociables y sobre las que todo subproyecto debe construirse. Un subproyecto que ignore cualquiera de estas realidades no es un subproyecto de SBOS: es un sistema externo incompatible.

---

## Parte I — Qué es SBOS

### 1. La definición precisa

SBOS es un **Sistema Operativo Empresarial Distribuido y Soberano** que actúa como plano de control unificado sobre tres dominios simultáneos — lógico, físico y financiero — capaz de operar sobre cualquier cantidad de nodos geográficamente distribuidos, manteniendo contexto, trazabilidad e identidad consistentes en cada punto.

Esta definición no es una analogía. Es técnicamente verificable componente por componente en su versión v1.0 GA (Sep 2026).

### 2. La inversión conceptual que lo define

Los sistemas empresariales existentes (SAP, Oracle, Microsoft 365, Odoo) son **aplicaciones que corren sobre un sistema operativo**.

SBOS es el **sistema operativo sobre el que corren las aplicaciones de negocio**.

```
Modelo convencional:
  Hardware → Linux/Windows → SAP/ERP/M365 → Negocio

Modelo SBOS:
  Hardware → Linux/Kubernetes → SBOS → Aplicaciones (Tryton, Saleor, OrangeHRM...)
                                 ↑
                          El OS empresarial
```

Tryton es una aplicación. EspoCRM es una aplicación. SmartTax es una aplicación. SBOS es la capa que las orquesta, les da identidad y contexto, las conecta entre sí mediante el WAL, controla el hardware físico que las rodea, y mantiene trazabilidad de todo lo que ocurre dentro de ellas.

SBOS cumple las cinco funciones canónicas de un sistema operativo, sobre recursos empresariales en lugar de recursos de cómputo:

| Función canónica SO | Linux | SBOS |
|---|---|---|
| Abstrae el hardware | CPU, RAM, disco, red | Chapas, cajones POS, cámaras, lectores biométricos |
| Gestiona recursos | Asigna memoria y CPU a procesos | Asigna namespaces, BDs, secretos y capacidades a tenants y usuarios |
| Controla procesos | Arranca, detiene, reinicia procesos | Arranca, detiene, repara fichas (unidades atómicas de servicio) |
| Gestiona identidad y permisos | usuarios, grupos, permisos de archivo | bAuth + Keycloak: quién puede hacer qué, dónde, cuándo, con qué límite |
| Tiene un kernel | Linux kernel — gestiona interrupciones y hardware | bKernel — escucha el WAL, propaga cambios, mantiene coherencia de datos |

Estándar de referencia: **ISA-95 / IEC 62264** (Enterprise-Control System Integration). SBOS implementa los Niveles 3-4 de este estándar de forma nativa y soberana.

### 3. Los tres dominios que SBOS unifica simultáneamente

Cada solicitud de acceso se evalúa en tres dimensiones al mismo tiempo. El resultado de esa evaluación es un **BitMask de 64 bits** que define con exactitud qué puede hacer ese usuario, en ese contexto, en ese momento.

**Dominio Lógico** — capacidades digitales:
- Qué aplicaciones puede usar (Tryton, OrangeHRM, Saleor, el subproyecto)
- Desde qué red y con qué nivel de aseguramiento (LoA 1, 2 o 3)
- Qué operaciones puede ejecutar dentro de cada app

**Dominio Físico** — capacidades sobre el mundo real:
- Qué puertas y zonas puede abrir (chapas vía Par Nexus Soberano)
- Qué actuadores puede activar (cajón POS, torniquetes, alarmas)
- Todo en **~15ms** desde que presenta la credencial

**Dominio Financiero** — capacidades transaccionales:
- Límites de monto por operación, por día, por mes
- Separación de funciones: quien crea no puede aprobar (SoD)
- Doble firma para operaciones que superan umbrales definidos

### 4. Lo que SBOS no es

| Lo que podría parecer | La realidad |
|---|---|
| Un ERP | Es la capa que orquesta el ERP (Tryton) junto con todo lo demás |
| Un sistema de autenticación | Keycloak es la autenticación. SBOS orquesta Keycloak |
| Una plataforma cloud | Es soberano: corre en el hardware del cliente. Ningún dato sale |
| Un gestor de contenedores | Kubernetes es el runtime. SBOS es la capa de intención sobre K8s |
| Un framework de integración | La integración es nativa por WAL — no es MuleSoft ni n8n |
| Un RTOS o PLC | Opera en ISA-95 Niveles 3-4 (empresarial), no en control de planta |

---

## Parte II — El Plano de Contexto Distribuido (SBOS-049)

### 5. El problema que resuelve el Context Plane

Ubuntu sabe qué máquina existe. Kubernetes sabe qué pod corre. Keycloak sabe quién es el usuario. **SBOS sabe qué significa todo eso junto.**

Sin el Context Plane, cada componente ve una fracción del estado real. Con el Context Plane, cualquier servicio del stack sabe en todo momento: para qué tenant opera, en qué empresa, en qué sucursal, en qué POS, con qué usuario, en qué nodo físico. Eso transforma logs en auditorías, errores en incidentes rastreables, y autorizaciones en decisiones con contexto empresarial completo.

### 6. Los dos identificadores de contexto

**dctx_id — Device Context ID (pre-autenticación):**
Cuando un dispositivo Fedora arranca y banexus se activa, el bos crea automáticamente un `dctx_id`. Este identificador registra toda la actividad del dispositivo antes de que el usuario se autentique — navegación, apps abiertas, intentos de acceso. El usuario no sabe que existe ni necesita interactuar con él.

**ctx_id — Context Session ID (post-autenticación):**
Cuando el usuario se autentica con Keycloak, bAuth evalúa los tres dominios y calcula el BitMask. El bos entonces eleva el `dctx_id` a `ctx_id` mediante el evento `context.promoted`, vinculando retroactivamente toda la historia pre-autenticación al usuario identificado. El ctx_id propaga contexto empresarial completo a través de todos los servicios.

### 7. Estructura del ctx_id

```json
{
  "ctx_id": "ctx-88291-a4f9",

  "tenant":    "skull",
  "empresa":   "maya",
  "sucursal":  "lapaz",
  "pos_logico": "POS-23",

  "user_id":     "3397708",
  "session_kc":  "kc-sess-7fab12",

  "pod":       "pos-api-77fa",
  "namespace": "skull-maya",
  "node":      "node-02",
  "cluster":   "cluster-bolivia",
  "vps":       "vps-lapaz-01",
  "geo":       "La Paz, Bolivia",

  "created_at": "2026-05-20T14:32:00Z",
  "expires_at": "2026-05-20T22:32:00Z"
}
```

### 8. El ciclo completo de sesión

```
T+0    Dispositivo Fedora arranca
         banexus se activa (systemd --user)
         bos crea dctx_id → registra dispositivo
         Usuario sin autenticar — actividad registrada sin identidad

T+N    Usuario presenta credencial (QR / NFC / huella / contraseña)
         banexus intercepta via udev ANTES que el OS
         Evento viaja por WebSocket mTLS → bhnexus → bAuth (Unix socket)

T+N+5ms bAuth evalúa los 3 dominios simultáneamente:
          Lógico: apps permitidas, red autorizada, LoA requerido
          Físico: zonas autorizadas, horario laboral, hardware habilitado
          Financiero: límites de monto, SoD, doble firma
          Resultado: BitMask de 64 bits

T+N+8ms bos recibe el BitMask → crea Context Session → genera ctx_id
         Emite evento: context.promoted
         dctx_id → vinculado a ctx_id (historia pre-auth accesible)
         ctx_id almacenado: Redis (O(1) lookup) + bkernel_db (audit trail)

T+N+15ms Capacidades activadas:
          Chapa de la zona: OPEN_RELAY emitido por bhnexus
          Apps habilitadas: JWT con BitMask inyectado
          Cajón POS: banexus activa actuador serial/GPIO

T+operación Cada acción del usuario:
              ctx_id propagado como OTel Baggage W3C en todos los requests
              bKernel registra en audit_events con ctx_id como hilo conductor
              Trazabilidad: quién, qué, dónde, cuándo, sobre qué contexto

T+fin      Usuario cierra sesión / fin de turno
             bos invalida ctx_id → Redis TTL a cero
             BitMask a cero: chapas bloqueadas, apps bloqueadas, cajón bloqueado
             context_sessions preservada en bkernel_db para auditoría perpetua
```

### 9. Propagación del ctx_id (OTel Baggage + W3C)

El ctx_id viaja en el header W3C Baggage en cada request HTTP/WebSocket dentro del stack:

```
baggage: tenant.id=skull, empresa.id=maya, sucursal.id=lapaz,
         pos.id=POS-23, user.id=3397708, ctx.id=ctx-88291-a4f9
```

El OpenTelemetry Collector tiene un **Baggage Processor** que inyecta automáticamente estos valores como atributos en todos los spans, logs y métricas. El subproyecto recibe el ctx_id sin tener que hacer nada especial — está en el header de cada request que llega.

Kong extrae el ctx_id del baggage, llama a la bos Context API para verificarlo, e inyecta el contexto completo como headers internos (`X-SBOS-Tenant`, `X-SBOS-Empresa`, `X-SBOS-User`, `X-SBOS-CtxId`) en todos los requests al subproyecto.

### 10. El árbol de contextos de un usuario

Un usuario puede tener múltiples contextos autorizados. Puede cambiar entre ellos sin reautenticarse:

```
usuario 3397708
├── skull/maya/lapaz/pos23    ← contexto activo actual
├── skull/maya/lapaz/pos24
├── skull/maya/santacruz/pos2
├── skull/inka/lapaz/pos7
└── skull/admin/global
```

El context switching genera un nuevo ctx_id (el anterior queda como `status='switched'` en el audit trail, nunca se elimina).

### 11. Quién gestiona el Context Plane

El **bos IAM Installer** es el dueño del Context Plane (ADR-011). Es el único componente con visión completa del árbol organizacional (tenant → empresas → sucursales → POS) desde el seed file. Expone la Context API en `:9443`:

```
POST   /api/v1/context/create                   → crea ctx_id al login
POST   /api/v1/context/switch                   → context switching
DELETE /api/v1/context/{ctx_id}                 → logout
GET    /api/v1/context/{ctx_id}                 → lookup (Kong plugin)
GET    /api/v1/context/tenant/{tenant}          → contextos activos
POST   /api/v1/context/tenant/{tenant}/invalidate-all  → suspensión tenant
```

Los demás daemons son **consumidores** del contexto, no gestores:
- **bKernel** → persiste en `context_sessions` y en `audit_events`
- **bAuth** → verifica coherencia ctx activo vs BitMask
- **Kong** → extrae, verifica e inyecta el ctx_id en cada request
- **bCompass** → enruta workflows conociendo el tenant/empresa/sucursal
- **bSearch** → indexa con `tenant_ctx` para aislamiento multi-tenant
- **biedata** → adjunta ctx_id a operaciones fiscales para auditoría externa
- **bhnexus/banexus** → valida acceso físico según el POS/sucursal activo
- **Centrifugo** → notifica cambios de contexto al frontend en tiempo real

---

## Parte III — Los 8 Daemons Soberanos en Profundidad

Los daemons son procesos `systemd` que corren en el host Ubuntu fuera de Kubernetes, con acceso directo al WAL de PostgreSQL. **HTTP entre daemons está vetado** (ADR-012). Toda comunicación entre daemons usa WebSocket o Unix socket.

### 12. bos — SBOS IAM Installer (Go)
**Propósito:** Control Plane soberano del sistema. Es el systemd del SBOS empresarial.

**Qué hace:**
- Instala, actualiza, repara y elimina fichas resolviendo el DAG de dependencias
- Gestiona el ciclo de vida completo de tenants: alta (saga de 7 pasos con compensación), modificación, suspensión y eliminación
- En el alta de tenant: crea realm Keycloak + namespace K8s + BDs PostgreSQL + paths Vault + service accounts
- Es el dueño del Context Plane: crea ctx_id al login, invalida al logout, destruye todos al suspender el tenant
- Reconcilia el estado declarado vs el estado real cada 15 minutos
- Expone la API REST + WebSocket para Core UI y bosctl

**Puertos:** `:9440` (API REST), `:9441` (WebSocket streaming), `:9442` (métricas), `:9443` (Context API)

**Comandos bosctl principales:**
```bash
bosctl deploy <seed.yml>              # Alta de tenant
bosctl product install ai --tenant=X # Agregar producto
bosctl tenant suspend X               # Suspender tenant
bosctl context list --tenant=X        # ctx_id activos
bosctl context invalidate ctx-88291   # Forzar logout
bosctl ficha repair postgresql        # Reparar ficha
```

**Lo que el subproyecto necesita saber:** Se despliega como ficha que bos instala. El subproyecto declara sus dependencias en `depends_on` y bos garantiza el orden topológico.

---

### 13. bkernel — SBOS Data Kernel (Rust)
**Propósito:** El kernel del plano de datos. Escucha el WAL de PostgreSQL y propaga cambios entre apps. No modifica ninguna app (cero invasión).

**Qué hace:**
- Escucha el WAL via slot de replicación lógica con latencia `<50μs` (socket Unix)
- Evalúa cada cambio contra reglas declarativas YAML (`/etc/bos/blibs/bkernel/rules/`)
- Propaga cambios entre apps (ej: nuevo empleado en OrangeHRM → sincroniza en Tryton, Postfix, Rocket.Chat)
- Mantiene `audit_events` con ctx_id como hilo conductor de toda la trazabilidad del sistema
- Persiste `context_sessions` para el Context Plane
- Publica en Redis Streams cuando un trigger fiscal dispara biedata (ej: `biedata:invoices:BO`)
- Escribe en BDs de otras apps con `origin='bkernel'` (antiloop: ignora sus propias escrituras)
- Opera el Master Data Management (MDM): `party.party` de Tryton es la fuente de verdad de personas/empresas

**Arquitectura interna:**
```
WAL Stream (slot PG)
    ↓
CDC Parser (Rust — parseo de pgoutput)
    ↓
Rule Engine (evalúa rules/*.yml)
    ├── MDM Rules → sincroniza entidades entre BDs
    ├── Fiscal Trigger Rules → publica Redis Stream biedata:*
    ├── Context Rules → actualiza context_sessions
    └── Embedding Rules → encola ai:embed_queue para vectorización
    ↓
Dead Letter Queue (DLQ) → reintentos exponenciales + alerta
```

**Puertos:** `:9460` (métricas), `:9461` (healthcheck). Unix Socket: `/run/bos/bkernel-mcp.sock` (solo bCompass)

**Lo que el subproyecto necesita saber:** Todo lo que el subproyecto escribe en PostgreSQL llega a bKernel. No hay que hacer nada especial. Las escrituras de bKernel al subproyecto llegan con `origin='bkernel'` — no las re-emitas como eventos nuevos.

---

### 14. biedata — SBOS Data Integration (Rust)
**Propósito:** Aduana soberana de datos. Todo dato que entra desde el exterior o sale hacia el exterior pasa por biedata. Es el **único daemon autorizado a realizar conexiones HTTP salientes al exterior**.

**Qué hace:**
- **EXPORT:** Recibe triggers de bKernel via Redis Stream → ejecuta caja de exportación → entrega a API exterior (SIAT Bolivia, AFIP Argentina, SAT México, DIAN Colombia) via POST mTLS → escribe código de autorización en `biedata_db` → bKernel detecta esa escritura y actualiza la BD de origen (ej: `tryton_db.account_invoice` con el número de autorización fiscal)
- **IMPORT:** Detecta archivos en carpetas watcheadas via inotify → ejecuta caja de importación → calamine lee Excel/CSV sin GC pauses → UPSERT en la BD destino con `origin='biedata'` → bKernel propaga al resto del stack
- Cada caja implementa 6 fases: VALIDATE → AUTHENTICATE → EXTRACT → TRANSFORM → LOAD → AUDIT

**Flujo fiscal completo (ejemplo SmartTax → SIAT):**
```
① SmartTax aprueba factura en Tryton
② PostgreSQL WAL: UPDATE account_invoice SET state='posted'
③ bKernel detecta → evalúa invoice_tributaria_trigger.yml
④ bKernel publica en Redis Stream: biedata:invoices:BO
⑤ biedata consume el stream → ejecuta caja boxes/export/facturas_siat/
   VALIDATE: verifica credenciales en Vault
   AUTHENTICATE: carga certificado digital mTLS del SIAT desde Vault
   EXTRACT: SELECT factura + cliente de PostgreSQL
   TRANSFORM: construye XML firmado según XSD oficial del SIAT
   LOAD: POST mTLS al endpoint del SIAT
   AUDIT: registra código de autorización en biedata_db
⑥ bKernel detecta escritura en biedata_db → actualiza tryton_db con código fiscal
⑦ SmartTax muestra factura autorizada con número oficial
```

**Activación:** No por API REST. Solo por eventos: Redis Stream (publicado por bKernel), file_watch (inotify), cron, o `bosctl biedata run <caja>`.

**Puertos:** `:9470` (métricas), `:9471` (healthcheck). Sin API REST pública.

**Lo que el subproyecto necesita saber:** Si necesita integración con sistemas externos (APIs gubernamentales, bancos, proveedores), declara una caja biedata. No llama a la API externa directamente.

---

### 15. bauth — SBOS Auth Enforce (Go)
**Propósito:** Plano de identidad. Evalúa los tres dominios simultáneamente y emite el BitMask de 64 bits que define qué puede hacer cada usuario.

**Qué hace:**
- Evalúa las 3 dimensiones por cada solicitud de acceso:
  - **Dominio Lógico:** apps permitidas, red autorizada, nivel de aseguramiento LoA requerido
  - **Dominio Físico:** zonas autorizadas, horario laboral, hardware habilitado
  - **Dominio Financiero:** límites transaccionales, SoD, si requiere doble firma
- Calcula el **BitMask de 64 bits** resultante
- Sincroniza RolTemplates entre Keycloak y Tryton (single source of truth para privilegios)
- Cache de BitMask en Redis (hit en ~5ms, miss va a KC Admin API)
- Se comunica con bhnexus para autenticación física: bhnexus llama a bauth via Unix socket `/run/bos/bauth.sock` en cache miss (~5ms, timeout 1s, retry 3x)
- Responde al Par Nexus en tiempo total <15ms (incluye chapa + actuadores)

**Estructura del BitMask (64 bits):**
```
Bits 0-9:   ERPMask       (permisos en Tryton: ventas, compras, contabilidad...)
Bits 10-19: VDIMask       (zonas físicas, hardware habilitado)
Bits 20-29: AppsMask      (CRM, RRHH, e-commerce, chat...)
Bits 30-39: FinancialMask (límites, SoD, doble firma)
Bits 40-63: Reserved      (expansión futura)
```

**Puertos:** `:9450` (API REST — solo bhnexus y Kong la consultan), `:9451` (métricas). Unix Socket: `/run/bos/bauth.sock` (bhnexus), `/run/bos/bauth-mcp.sock` (bCompass)

**Lo que el subproyecto necesita saber:** No implementa autorización propia. Lee el BitMask del JWT para saber qué puede hacer el usuario. Si el usuario intenta una operación fuera de su BitMask, la rechaza con 403.

---

### 16. bcompass — SBOS AI Tools (Go)
**Propósito:** Route Engine de inteligencia soberana. Implementa el principio HITL (Human-In-The-Loop) para decisiones de alto impacto.

**Principio fundamental:**
```
DATOS → bCompass OBSERVA → ANALIZA → ORIENTA → HUMANO DECIDE → SISTEMA EJECUTA
```
Nunca autónomo en decisiones de alto impacto.

**Los 4 tipos de rutas:**

| Tipo | Qué hace | Ejemplo |
|---|---|---|
| **analyst** | Observa datos históricos → análisis estadístico → sugerencias `pending` → admin aprueba/rechaza en Core UI | Detectar reglas bKernel inactivas >90 días |
| **agent** | Agente conversacional con Ollama local + RAG del stack | Empleado pregunta sus vacaciones disponibles → responde con datos reales de OrangeHRM |
| **flow** | Workflow de automatización: queries + LLM + Approval Gates + notificaciones + archivos | Reporte de ventas mensual automático en Excel enviado a gerencia |
| **report** | Reportes periódicos automáticos en Excel/PDF | Estado semanal de integraciones biedata |

**Niveles de governance:**
```
Governance 1 → Sin Approval Gate → ejecuta directo
               Ej: generar reporte, responder pregunta
Governance 2 → Approval Gate — rol CONFIG
               Ej: sugerir desactivar una regla bKernel
Governance 3 → Approval Gate — rol OWNER (Ivan Villanueva / Juan Pérez)
               Ej: cambio de configuración del stack, impacto financiero alto
```

**Fronteras inviolables:**
- Solo lectura sobre el stack (SELECT — nunca UPDATE/DELETE en apps)
- Solo escribe en `bcompass_db` (sugerencias, conversaciones, auditoría)
- LLM es local (Ollama) — los datos nunca salen del servidor
- Agent solo accede datos del usuario que pregunta (`own_user_only`)

**Puertos:** `:9480` (API REST — propuestas HITL, Core UI), `:9481` (métricas). MCP Unix sockets: consume `/run/bos/bkernel-mcp.sock`, `/run/bos/bauth-mcp.sock`, `/run/bos/bsearch-mcp.sock`

**Lo que el subproyecto necesita saber:** Si el subproyecto necesita IA (análisis, agente conversacional, automatización con LLM), declara una ruta bCompass. No llama a Ollama directamente. No implementa su propio agente.

---

### 17. bsearch — SBOS Data RAG (Go)
**Propósito:** Búsqueda federada soberana. Combina Typesense (full-text) con Qdrant (semántico). Incluye Schema Discoverer para entender automáticamente nuevas estructuras de datos.

**Qué hace:**
- Indexa datos del WAL (via bKernel Redis Stream) en Typesense (full-text) y Qdrant (vectores semánticos)
- Schema Discoverer: cuando se instala una nueva app, analiza sus tablas con `qwen3-coder:30b` (Ollama local) y genera patrones de búsqueda automáticamente con status DRAFT → admin aprueba → ACTIVE
- Search Learning Engine: aprende sinónimos, abreviaciones del negocio y errores en datos almacenados (no confunde con errores del usuario al teclear)
- Colecciones Qdrant aisladas por realm (multi-tenant: datos de tenant A nunca visibles en búsquedas de tenant B)

**Puertos:** `:9490` (API REST — búsqueda federada), `:9492` (métricas). Unix Socket: `/run/bos/bsearch-mcp.sock` (bCompass)

**Lo que el subproyecto necesita saber:** Si expone datos buscables al usuario, los declara en el patrón de búsqueda (`patterns/<app>/`) y bSearch los indexa automáticamente desde el WAL.

---

### 18. bhnexus + banexus — Par Nexus Soberano (Go)
**Propósito:** bhnexus y banexus son una **unidad compuesta** — no dos daemons separados. Juntos forman el Sovereign Connectivity Broker que conecta el mundo físico con el SBOS.

**bhnexus** (host Ubuntu — Sovereign Connectivity Broker):
- Acepta conexiones WebSocket mTLS de todos los banexus (hasta 10.000 concurrentes) en `:9444`
- Cache de BitMask en memoria: si la credencial ya fue evaluada, responde sin consultar bAuth (~5ms)
- En cache miss: consulta bAuth via Unix socket `/run/bos/bauth.sock` (~5ms adicionales)
- Emite `actuator_commands` hacia banexus: `OPEN_RELAY`, `DENY_RELAY`, `CAPTURE_FRAME`
- Registra el estado físico (dispositivos activos, chapas, cámaras) para el Context Plane

**banexus** (nodo Fedora — Edge Sentinel):
- Corre como `systemd --user` en cada endpoint Fedora VDI del cliente
- **Sin puertos TCP entrantes** — es cliente puro
- Intercepta hardware via `udev + libusb` **ANTES** de que el OS lo procese: QR, NFC, huella, tarjeta
- Conecta de forma saliente a bhnexus en `:9444` (WebSocket mTLS monogámico — solo se conecta a su bhnexus)
- Actúa sobre actuadores locales tras recibir `actuator_commands`: relé (cajón POS, chapa), pantalla, impresora

**Topología invariable:**
```
banexus (Fedora) ──WSS/mTLS saliente──► bhnexus :9444 (Ubuntu)
                                              │
                                   Unix socket /run/bos/bauth.sock
                                              │
                                           bAuth (evaluación BitMask)

VETADO:
  ✗ banexus → bAuth directamente
  ✗ banexus → Keycloak directamente
  ✗ dispositivo físico → bhnexus directamente (debe pasar por banexus)
  ✗ bhnexus → HTTP externo
```

**Puertos bhnexus:** `:9444` (WSS/mTLS — único canal con banexus), `:9445` (métricas). banexus: sin puertos TCP.

**Lo que el subproyecto necesita saber:** Si necesita control físico (abrir chapas, activar actuadores, capturar video), habla con bhnexus vía WebSocket en `:9444`. No se comunica con banexus directamente.

---

## Parte IV — Aplicaciones de Gobernanza e Imprescindibles

Estas aplicaciones son la columna vertebral operativa del SBOS. Sin ellas el sistema no funciona. Todo subproyecto depende de ellas aunque no interactúe con ellas explícitamente.

### 19. Keycloak 26.x — El único IdP (S03 identityserver)
**Licencia:** Apache 2.0 | **BD:** PostgreSQL dedicada `keycloak_db`

Keycloak es el único proveedor de identidad del SBOS. Sin excepciones. Es el Principio 1.

**Qué provee:**
- SSO via OIDC/OAuth 2.0/SAML 2.0 para las 110+ apps del stack
- Multi-tenancy por realm: cada cliente tiene su realm aislado
- 16 métodos de autenticación configurados (contraseña, OTP, passkey, WebAuthn, QR, NFC, biométrico vía SPI custom)
- 5 SPIs custom desarrollados por SKULL: `BosRolTemplateSPI`, `FinancialDomainSPI`, `PhysicalDomainSPI`, `LogicalDomainSPI`, `TemporalContextSPI`
- JWT con BitMask y ctx_id inyectados por bAuth en el flujo de autenticación
- `FAPI 2.0 + DPoP` para operaciones financieras de alto valor
- Passkeys (KC 26.4+) para autenticación sin contraseña

**Principio técnico:** Keycloak verifica la prueba criptográfica de identidad. Lo que está antes — hardware, sensor, PIN, dedo — es responsabilidad del dispositivo. KC nunca toca lectores físicos.

**Lo que el subproyecto debe hacer:** Registrarse como `client` OIDC en el realm del tenant. Delegar autenticación a KC. Validar el JWT con la clave pública del realm. Leer `bos_domains` del JWT para autorización.

---

### 20. Kong OSS 3.9.x LTS — API Gateway (S02 gatewayserver)
**Licencia:** Apache 2.0 | **BD:** PostgreSQL `kong_db` | **ADR:** ADR-010

Kong es el punto de entrada único para todo el tráfico de usuarios y APIs del SBOS. Todo servicio expuesto externamente pasa por Kong.

**Qué provee:**
- JWT validation, rate limiting, CORS, ACL, OIDC, IP restriction, bot detection
- Rate limiting por tipo: estándar (100 req/min), partner (500), interno (1000), anónimo (20)
- Plugin Lua SBOS-Context: extrae ctx_id del baggage, verifica contra bos Context API, inyecta headers internos
- Enrutamiento por subdominio: `erp.sksistemas.com` → Tryton, `tax.sksistemas.com` → SmartTax, etc.
- OAuth2-Proxy para apps sin OIDC nativo (PgAdmin, FreePBX, Zabbix, Portainer)

**Versión fija:** 3.9.x LTS (hasta 2027). No actualizar más allá sin aprobación ARB. Las versiones ≥3.10 dejaron de publicar imágenes OCI gratuitas (ver ADR-010).

**Lo que el subproyecto debe hacer:** Declarar su ruta Kong en el `yaml_engine.yml` de la ficha. Kong la registra automáticamente al instalar la ficha. El subproyecto recibe el JWT y los headers X-SBOS-* en cada request.

---

### 21. HashiCorp Vault — Gestión de Secretos (S02 gatewayserver)
**Licencia:** BSL 1.1 (excepción aceptada: uso propio libre) | **BD:** PostgreSQL `vault_db`

Vault es la fuente de verdad de todos los secretos del stack después del bootstrap. Ninguna contraseña, token ni certificado existe en texto claro en ningún lugar del sistema.

**Qué provee:**
- Secrets dinámicos con TTL corto para conexiones de BD (cada pod recibe credenciales que expiran)
- PKI Engine: emite y renueva certificados TLS internos
- AppRole: autenticación para pods y daemons sin credenciales de usuario
- Paths por tenant: `secret/tenants/{realm}/` — cada tenant tiene su propio espacio aislado

**Lo que el subproyecto debe hacer:** Declarar en `manifest.yml` los paths de Vault que necesita. bos provisiona el acceso AppRole automáticamente al instalar la ficha. El subproyecto lee sus secretos de Vault en el arranque, nunca de variables de entorno.

---

### 22. PostgreSQL 17 + Patroni HA — La única BD relacional (S01 dataserver)
**Licencia:** PostgreSQL License | **Clustering:** Patroni 3 nodos, failover <30s

PostgreSQL es la única BD relacional del SBOS (ADR-005). Es obligatoria porque el bus de eventos (WAL) es su Write-Ahead Log.

**Qué provee:**
- Motor ACID para todas las apps del stack
- WAL como bus de eventos nativo (pgoutput, replicación lógica)
- Patroni HA 3 nodos: failover automático en <30s
- PgBouncer: connection pooling (reduces overhead en 110+ apps)
- pgBackRest: PITR backup desde réplica sin impacto al primario
- SymmetricDS: CDC bidireccional PG↔MySQL para 3 apps legacy (OrangeHRM, FreePBX, Easy!Appointments)

**Bases de datos predefinidas (creadas en Ficha 05 de instalación):**
`keycloak_db`, `kong_db`, `grafana_db`, `bkernel_db`, `bcompass_db`, `bauth_db`, `biedata_db`, `bsearch_db`, `tryton_db`, `vault_db`

**Lo que el subproyecto debe hacer:** Su BD se llama `{nombre_app}_db` por convención. Se crea automáticamente en el alta del tenant. Nunca accede directamente a la BD de otra app.

---

### 23. Redis 7 — Cache, Sesiones y Streams (S01 dataserver)
**Licencia:** BSD 3

Redis opera en tres roles simultáneos en SBOS:
- **DB0:** Cache general y sesiones
- **DB1:** Context Registry (ctx_id activos, TTL sincronizado con KC)
- **DB2:** Pub/Sub y Streams (biedata:invoices:*, ai:embed_queue, bcompass:agent_requests)

**Lo que el subproyecto debe hacer:** Si usa Redis, declara su DB en manifest.yml. No usa las DB0/DB1/DB2 reservadas salvo que sea un daemon soberano.

---

### 24. NGINX + ModSecurity + Certbot (S02 gatewayserver)
**Licencia:** BSD 2 / Apache 2.0

NGINX es el punto de entrada físico de todo el tráfico externo. MetalLB le asigna la IP virtual. Redirige todo HTTP→HTTPS y pasa a Kong.

ModSecurity con OWASP CRS bloquea SQLi, XSS, CSRF, path traversal antes de que lleguen a Kong o a cualquier app.

Certbot renueva automáticamente los certificados TLS cada 90 días sin downtime.

**Lo que el subproyecto debe hacer:** Nada. NGINX y Kong manejan TLS termination y WAF automáticamente. El subproyecto recibe requests ya verificadas con HTTPS.

---

### 25. Linkerd 2 — Service Mesh mTLS (S03 identityserver)
**Licencia:** Apache 2.0

Linkerd inyecta un sidecar proxy en cada pod. Sin configuración adicional del subproyecto, todas las comunicaciones entre pods dentro del cluster son mTLS automático. Nadie en la red interna puede interceptar tráfico entre pods.

**Puertos del sidecar** (en todos los pods): `:4143` (inbound), `:4140` (outbound), `:4191` (admin). Estos puertos no pueden ser bloqueados por NetworkPolicy en namespaces con Linkerd.

**Lo que el subproyecto debe hacer:** Nada. El namespace del subproyecto tiene la etiqueta `linkerd.io/inject: enabled` aplicada por bos al crear el tenant. mTLS es automático.

---

### 26. Calico CNI + NetworkPolicy Default-Deny (S02 gatewayserver)
**Licencia:** Apache 2.0

Calico implementa la red de pods de Kubernetes con el principio **deny-all por defecto** (NSA/CISA Kubernetes Hardening Guide v1.2). Todo pod del stack está aislado de todos los demás por defecto. Solo el tráfico explícitamente autorizado en NetworkPolicy puede circular.

NetworkPolicies base que el subproyecto hereda:
- `default-deny-all` en su namespace
- `allow-kong-ingress` — Kong puede enviar tráfico al subproyecto
- `allow-postgres-egress` — el subproyecto puede conectar a PostgreSQL
- `allow-redis-egress` — puede conectar a Redis
- `allow-prometheus-scrape` — Prometheus puede raspar `/metrics`
- `allow-linkerd-sidecar` — Linkerd sidecar puede funcionar

---

### 27. Prometheus + Grafana + Loki + Tempo (S12 monitorserver)
**Licencia:** Apache 2.0

El stack LGTM (Loki + Grafana + Tempo + Mimir) provee observabilidad completa. OTel Collector recibe traces, métricas y logs de todos los pods y daemons con el ctx_id como label de correlación.

**Lo que el subproyecto debe hacer:**
- Exponer `/metrics` en el puerto T=2 de su bloque (formato Prometheus)
- Emitir logs estructurados en JSON con `ctx_id` como campo obligatorio
- Incluir un dashboard Grafana mínimo en `resources/dashboard.json`
- OTel SDK configurado para enviar spans al OTel Collector en `:4317` (gRPC) o `:4318` (HTTP)

---

### 28. Kyverno — Admission Control (S03 identityserver)
**Licencia:** Apache 2.0

Kyverno valida que todo pod del cluster cumpla las políticas de seguridad antes de ser admitido. Las políticas son declarativas YAML.

**Políticas activas que afectan al subproyecto:**
- Ningún pod expone `hostPort` en BDs (5432, 6379, 3306) — sin excepciones
- Ningún NodePort fuera del rango 31000-31999
- Ningún pod en producción usa puertos T=8 (debug)
- Todos los pods tienen `readinessProbe` y `livenessProbe` declarados
- Imágenes deben estar firmadas con Ed25519 del Release Plane SKULL

---

### 29. GitLab CE + Bareos + pgBackRest + Velero (S14 opsserver)
**Licencias:** MIT / AGPL v3

**GitLab CE:** Repositorio de código, CI/CD pipelines, container registry para imágenes OCI. Todo código del subproyecto vive aquí. Las imágenes se construyen en el CI y se firman con Ed25519 antes de llegar al cluster.

**Bareos:** Backup de archivos del sistema y de Nextcloud. El subproyecto no configura Bareos — está cubierto automáticamente.

**pgBackRest:** PITR de PostgreSQL desde la réplica. Todas las BDs del stack (incluyendo la del subproyecto) están cubiertas automáticamente. Recovery Point Objective (RPO): <1h.

**Velero:** Backup de manifiestos K8s y PVCs. Si el cluster debe restaurarse, Velero reconstruye todos los namespaces y ConfigMaps. El subproyecto no configura Velero.

---

### 30. Wazuh — SIEM/XDR (S03 identityserver)
**Licencia:** GPL v2

Wazuh corre como DaemonSet en todos los nodos del cluster y como agente en el host Ubuntu. Detecta intrusiones, anomalías de comportamiento, cambios en configuración y vulnerabilidades. Los eventos de seguridad de todos los pods, incluyendo los del subproyecto, son centralizados en Wazuh automáticamente.

**Lo que el subproyecto debe hacer:** Nada. Wazuh es transparente para el subproyecto.

---

## Parte V — Las Reglas que el Subproyecto No Puede Cambiar

### 31. Principios inquebrantables

| Regla | Lo que significa para el subproyecto |
|---|---|
| **Keycloak es el único IdP** | No implementes login propio. No uses Auth0, Firebase ni auth nativa. Todo va a Keycloak |
| **PostgreSQL es la única BD relacional** | Tu BD es PostgreSQL. MySQL solo como excepción explícita documentada con SymmetricDS |
| **Licencias OSI-approved únicamente** | MIT, Apache 2.0, GPL, LGPL, MPL, BSD, AGPL, ISC. BSL, Sustainable Use y Commons Clause están vetadas |
| **Los datos del cliente nunca salen de su infraestructura** | No llames a APIs externas directamente para enviar datos del cliente. Usa caja biedata |
| **Kubernetes desde el día 1** | No existe modo sin K8s. El subproyecto se empaqueta como ficha SBOS |
| **Secrets vía Vault** | Ninguna contraseña ni token en texto claro. Vault con TTL corto |
| **Cero invasión** | No modifiques el código ni las BDs de otras apps del stack |
| **Docker vetado** | Solo Podman/OCI. Imágenes OCI estándar firmadas con Ed25519 |
| **HTTP entre daemons vetado** | Comunicación daemon↔daemon y daemon↔Smart* solo por WebSocket o Unix socket |
| **biedata es el único con salida exterior** | Ningún otro daemon puede conectarse a APIs externas |

---

## Parte VI — Cómo se Integra Técnicamente un Subproyecto

### 32. La Ficha SBOS — unidad atómica de despliegue

Todo subproyecto se despliega como una Ficha SBOS:

```
mi-subproyecto/
  manifest.yml        ← identidad, dependencias, feature flags, puertos, BD
  yaml_engine.yml     ← qué hace K8s con el subproyecto (declarativo puro)
  task_catalog.sh     ← tareas operativas bash: instalar, reparar, migrar
  resources/
    config.yaml       ← ConfigMaps K8s
    dashboard.json    ← Dashboard Grafana mínimo
    netpolicies/      ← NetworkPolicies adicionales del subproyecto
```

**manifest.yml mínimo:**
```yaml
identity:
  id: "mi-subproyecto"
  version: "1.0.0"
  description: "Descripción del subproyecto"
  criticality: false   # o true si es imprescindible
  license: "MIT"

workload:
  type: kubernetes
  namespace: "sbos-{tenant}"
  server: "S06"   # servidor lógico al que pertenece

depends_on:
  - postgresql
  - keycloak
  - kong

ports:
  http:    28190   # del rango SKULL Custom 28100-28999
  https:   28191
  metrics: 28192
  health:  28193

database:
  name: "misubproyecto_db"
  engine: postgresql

keycloak:
  client_id: "mi-subproyecto"
  realm: "{tenant}"
  grant_type: authorization_code

vault:
  paths:
    - "secret/tenants/{realm}/mi-subproyecto/db"
    - "secret/tenants/{realm}/mi-subproyecto/api-key"

feature_flags:
  status: "beta"   # experimental | beta | ga
```

### 33. Lo que el subproyecto recibe automáticamente

| Capacidad | Cómo llega | Lo que el subproyecto hace |
|---|---|---|
| **Autenticación SSO** | Keycloak + OAuth2-Proxy (si no tiene OIDC nativo) | Configura el client_id en KC — listo |
| **ctx_id en cada request** | Kong inyecta X-SBOS-CtxId como header | Lee el header, lo adjunta a todos sus logs y operaciones |
| **BitMask y dominios** | JWT de Keycloak con claim `bos_domains` | Lee `bos_domains` del JWT para autorización |
| **Trazabilidad automática** | bKernel escucha el WAL y registra en audit_events | Solo escribe en su BD con normalidad |
| **Propagación de datos** | bKernel sincroniza entidades entre apps | Declara reglas de sincronización en YAML |
| **Búsqueda** | bSearch indexa desde el WAL | Declara entidades buscables en el patrón de búsqueda |
| **mTLS automático** | Linkerd sidecar inyectado en el namespace | Nada — es transparente |
| **Observabilidad** | Prometheus + Grafana + Loki + Tempo | Expone `/metrics` y emite logs JSON con ctx_id |
| **Secrets seguros** | Vault + K8s Secrets integration | Declara paths de Vault en manifest.yml |
| **Respaldo** | pgBackRest cubre toda la BD PostgreSQL | Su BD está cubierta automáticamente |
| **Seguridad de red** | Calico NetworkPolicy default-deny | Declara las NetworkPolicies adicionales en resources/ |

### 34. El JWT que llega al subproyecto

```json
{
  "sub": "3397708",
  "realm_access": { "roles": ["vendedor", "cajero"] },
  "bos_domains": {
    "logical": {
      "apps": ["saleor", "mi-subproyecto"],
      "network_authorized": true,
      "loa": 2
    },
    "physical": {
      "zones": ["ZONE-VENTAS"],
      "hardware": ["cajon-pos-01"]
    },
    "financial": {
      "max_transaction": 5000,
      "sod_profile": "vendedor-sin-aprobacion",
      "requires_dual_approval_above": 1000
    }
  },
  "bitmask": "0x00000000000A3F21",
  "ctx_id": "ctx-88291-a4f9",
  "tenant": "acme-srlt"
}
```

### 35. Los headers que Kong inyecta en cada request

```
X-SBOS-CtxId:     ctx-88291-a4f9
X-SBOS-Tenant:    acme-srlt
X-SBOS-Empresa:   maya
X-SBOS-Sucursal:  lapaz
X-SBOS-User:      3397708
X-SBOS-BitMask:   0x00000000000A3F21
```

El subproyecto no necesita analizar el baggage OTel directamente. Kong ya hizo el trabajo y lo entregó como headers HTTP estándar.

---

## Parte VII — Checklist de Acoplamiento

### 36. Lista de verificación antes de diseñar

Un subproyecto está correctamente conceptualizado cuando puede responder SÍ a todas estas preguntas:

**Identidad:**
- [ ] ¿Delega autenticación a Keycloak? No tiene login propio.
- [ ] ¿Consume el BitMask del JWT para autorización en lugar de implementar roles propios?
- [ ] ¿Lee el ctx_id del header X-SBOS-CtxId y lo adjunta a todos sus logs y audit records?

**Datos:**
- [ ] ¿Usa PostgreSQL como BD principal?
- [ ] ¿Sus entidades son buscables vía bSearch (declaradas en el patrón de búsqueda)?
- [ ] ¿Si necesita datos externos, los solicita vía caja biedata?
- [ ] ¿Cuando recibe escrituras de bKernel (`origin='bkernel'`), no las re-emite?
- [ ] ¿Secrets en Vault? ¿Ninguna credencial en texto claro?

**Comunicación:**
- [ ] ¿Se comunica con los daemons vía WebSocket o Unix socket? ¿No usa HTTP entre daemons?
- [ ] ¿Expone `/metrics` en el puerto T=2 de su bloque para Prometheus?
- [ ] ¿Expone `/health` o `/ready` en el puerto T=3 para K8s probes?

**Despliegue:**
- [ ] ¿Empaquetado como ficha SBOS con manifest.yml + yaml_engine.yml?
- [ ] ¿Puertos en el rango SKULL Custom 28100-28999 (si es app propia SKULL)?
- [ ] ¿Imagen OCI firmada con Ed25519? ¿No es imagen Docker específica?
- [ ] ¿Dependencias con licencia OSI-approved?

**Operación:**
- [ ] ¿Logs en JSON con `ctx_id` como campo estructurado obligatorio?
- [ ] ¿Dashboard Grafana mínimo en `resources/dashboard.json`?
- [ ] ¿BD nombrada `{app}_db` por convención?

---

## Parte VIII — Documentos del Corpus para Profundizar

### 37. Lectura obligatoria antes de diseñar

| Prioridad | Documento | Qué responde |
|---|---|---|
| 1 | **SBOS-001-VISION §2** | Qué es SBOS técnicamente. Los tres dominios. La inversión conceptual. ISA-95 |
| 2 | **SBOS-002-ARCH** | Las 5 capas. Los 8 daemons. El WAL como bus. Bounded Contexts |
| 3 | **SBOS-004-RULES** | Los 15 principios inquebrantables + 9 reglas de soberanía |
| 4 | **SBOS-049-CONTEXT-PLANE** | Qué es el ctx_id. Flujo completo de sesión. OTel Baggage. Tabla context_sessions |
| 5 | **SBOS-019-FICHAS** | Cómo se estructura una ficha. manifest.yml, yaml_engine.yml, task_catalog.sh |
| 6 | **SBOS-050-PORT-CATALOG §5, §12, §13** | Puertos prohibidos. Cómo derivar ClusterIP. Rango 28100-28999 |
| 7 | **SBOS-048-ADR-CATALOG ADR-012** | Por qué HTTP entre daemons está vetado |
| 8 | **SBOS-024-DAEMON-BIEDATA** | Cómo funciona biedata. Las 6 fases de una caja. Flujo fiscal completo |
| 9 | **SBOS-030-BOUNDED-CONTEXTS** | A qué BC pertenece el subproyecto. Cómo se integra via bKernel |
| 10 | **SBOS-043-DATABASE-CATALOG** | Cómo se nombran las BDs. Qué tablas ya existen en el stack |
| 11 | **SBOS-027-DAEMON-BCOMPASS** | Cómo declarar rutas IA. Los 4 tipos. Governance 1/2/3 |
| 12 | **SBOS-021-DAEMON-BAUTH** | La Tabla Maestra BitMask 64-bit. Los 3 dominios en detalle |

---

## Trazabilidad

| Sección | Fuente | Notas |
|---|---|---|
| §1-4 Qué es SBOS | SBOS-001-VISION v2.0 §2 | Definición técnica, inversión conceptual, tres dominios, "lo que no es" |
| §5-11 Context Plane | SBOS-049-CONTEXT-PLANE v3.0 §1-§12 | dctx_id, ctx_id, context.promoted, flujo completo, estructura JSON, propagación OTel Baggage, árbol de contextos, API del bos |
| §12 bos | SBOS-018-DAEMON-BOS §1-§3, §18.1 | Puertos, saga alta tenant, comandos bosctl |
| §13 bkernel | SBOS-023-DAEMON-BKERNEL §3-§7 | WAL, Rule Engine, MDM, DLQ, antiloop |
| §14 biedata | SBOS-024-DAEMON-BIEDATA §3-§6, SBOS-044 | 6 fases, flujo fiscal SIAT, import Excel, Redis Stream trigger |
| §15 bauth | SBOS-021-DAEMON-BAUTH §1, §8 | 3 dominios, BitMask 64-bit, Unix socket bhnexus |
| §16 bcompass | SBOS-027-DAEMON-BCOMPASS §2-§5, §12 | 4 tipos de ruta, governance 1/2/3, fronteras inviolables |
| §17 bsearch | SBOS-026-DAEMON-BSEARCH §5-§11 | Schema Discoverer, Search Learning Engine, Qdrant multi-tenant |
| §18 bhnexus+banexus | SBOS-039-DAEMON-NEXUS §3-§6, SBOS-NEXUS-CONCEPTUALIZACION-v3_0 | Par Nexus Soberano, topología invariable, flujo <50ms |
| §19 Keycloak | SBOS-029-KEYCLOAK §1-§4, SBOS-004-RULES S5 | SPIs custom, FAPI 2.0, principio técnico |
| §20 Kong | SBOS-005-STACK §S02, SBOS-048 ADR-010 | 3.9.x LTS, plugins activos, rate limiting por tipo |
| §21 Vault | SBOS-005-STACK §S02, SBOS-035-INSTALL-ROUTINE Ficha 08 | BSL excepción, secrets dinámicos TTL, AppRole |
| §22 PostgreSQL | SBOS-005-STACK §S01, SBOS-048 ADR-005 | Patroni HA, WAL bus, BDs predefinidas |
| §23 Redis | SBOS-005-STACK §S01 | DB0/DB1/DB2, Context Registry, Streams |
| §24-30 Apps gobernanza | SBOS-005-STACK, SBOS-007-DEPLOY §11 | NGINX, Linkerd, Calico, Prometheus/Grafana, Kyverno, GitLab/Bareos, Wazuh |
| §31 Principios | SBOS-004-RULES §1-§2 | P1-P15, S1-S9 |
| §32-35 Integración técnica | SBOS-019-FICHAS §2-§4, SBOS-049 §5.4 | Ficha SBOS, JWT real, headers Kong |
| §36 Checklist | Síntesis corpus | Verificación de acoplamiento |
| §37 Lecturas | SBOS-000-INDEX §4 | Rutas de lectura priorizadas |

---

_SKULL · SBOS · SBOS-MANUAL-ACOPLAMIENTO · HUMAN-DOC v2.0 · Mayo 2026_
_Reemplaza: v1.0 (Mayo 2026)_
_Cambios v2.0: Partes II y III completamente nuevas: Context Plane en profundidad (SBOS-049 completo: dctx_id/ctx_id/context.promoted, ciclo de sesión con timestamps, estructura JSON, propagación OTel Baggage, árbol de contextos, API del bos); 8 daemons documentados en profundidad con propósito exacto, arquitectura interna, puertos, fronteras y lo que el subproyecto necesita saber; Parte IV apps de gobernanza imprescindibles expandida: Keycloak SPIs custom, Kong 3.9.x LTS con plugins, Vault bootstrap problem, PostgreSQL BDs predefinidas, Redis DB0/DB1/DB2, Linkerd mTLS, Calico default-deny, stack LGTM, Kyverno políticas activas, GitLab/Bareos/pgBackRest/Velero, Wazuh; JWT con estructura real completa; headers Kong documentados; checklist expandido_
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
