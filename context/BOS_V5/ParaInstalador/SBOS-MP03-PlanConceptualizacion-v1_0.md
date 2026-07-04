# SBOS-MP03 — Plan Maestro de Conceptualización Completa
## De Documentación Parcial a Especificación Lista para Código

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

**Propósito:** Este plan mapea TODAS las tareas necesarias para que la documentación del SBOS sea lo suficientemente completa y precisa para que un desarrollador (o un agente de IA) genere código sin hacer preguntas. Cuando este plan esté completado al 100%, cada daemon, cada módulo, cada flujo y cada contrato estará especificado al nivel de "lee esto y codifica".

**Principio rector:** No se genera una sola línea de código hasta que la conceptualización esté completa. La documentación ES el producto — el código es su materialización.

---

## 1. Diagnóstico: Estado Actual por Componente

### Escala de madurez conceptual

```
█████ NIVEL 5 — Listo para código
  Arquitectura, módulos, APIs, contratos, flujos, errores, 
  edge cases y ejemplos YAML especificados. Un dev codifica sin preguntar.

████░ NIVEL 4 — Casi listo
  Arquitectura y módulos claros. Faltan contratos de API detallados,
  manejo de errores o edge cases en algunos flujos.

███░░ NIVEL 3 — Estructura definida
  Se sabe qué hace y cómo se organiza. Faltan especificaciones
  internas de módulos, contratos entre componentes, o flujos completos.

██░░░ NIVEL 2 — Concepto claro
  Se entiende el propósito y la posición en la arquitectura.
  Falta especificación técnica interna.

█░░░░ NIVEL 1 — Mencionado
  Existe en el índice pero sin documento propio o con
  especificación superficial.
```

### Mapa de madurez actual

```
DAEMON / COMPONENTE                  DOCUMENTO     NIVEL  LÍNEAS  GAPS CRÍTICOS
─────────────────────────────────────────────────────────────────────────────────
SBOS IAM Installer (bos)             SBOS-005      ████░  1564    API REST del daemon,
                                     SBOS-031               protocolo bosctl↔daemon,
                                     SBOS-032               manejo de errores por módulo,
                                     SBOS-033               especificación interna de módulos,
                                     SBOS-034               Sagas de instalación detalladas,
                                                            formato .sbos_state.json,
                                                            protocolo de señales __SBOS__

SBOS Data Kernel (bkernel)           SBOS-010      ████░  1272    Catálogo completo de reglas WAL,
                                     SBOS-010-WAL           contrato regla↔acción YAML,
                                                            manejo de conflictos y DLQ,
                                                            protocolo bkernel↔Tryton (API/SQL),
                                                            Redis como bus de colas (detalle)

SBOS Data Integration (biedata)      SBOS-011      ███░░  1001    Ciclo de vida completo de una Caja,
                                     SBOS-011-TRIB          Box Engine detallado (fases),
                                                            retry/circuit breaker/DLQ,
                                                            protocolo con externos (SIAT/AFIP/SAT),
                                                            auditoría de intercambio (log format)

SBOS AI Tools (bcompass)             SBOS-014      ████░  1653    Contrato ruta→LLM→respuesta,
                                     SBOS-014-LLM           aprendizaje federado (gradientes),
                                                            agentes de investigación (manifiestos),
                                                            analytics de inventario (stock→compra),
                                                            fallback sin GPU

SBOS Data RAG (bsearch)             SBOS-013      ███░░  1237    Motor de indexación detallado,
                                                            Levenshtein/fuzzy/sinónimos/teclado,
                                                            smart routing a formularios,
                                                            protocolo de reindexación,
                                                            metadatos de trazabilidad (DB+tabla)

SBOS Auth Enforce (bauth)           SBOS-008      ███░░  1525    3 dominios (lógico/físico/financiero),
                                     SBOS-009               BitMask completa (formato, bits),
                                     SBOS-019               plugin rolframework_sync en KC,
                                     SBOS-020               QR/NFC/RFID/biométrico (presentation),
                                     SBOS-MP01              drift detection + auto-corrección,
                                                            delegación temporal con vigencia

SBOS Nexus Host (bhnexus)           SBOS-012      ██░░░  ——      COMPENDIO aporta: WebSocket mgmt,
                                                            BitMask packaging, mTLS, auth cache,
                                                            hardware bridge (OSDP/MQTT/ONVIF),
                                                            device fichas, multi-dest actuators.
                                                            Falta: documento propio completo,
                                                            protocolo detallado con bauth,
                                                            formato de BitMask (qué bit = qué)

SBOS Nexus Agent (banexus)          (ninguno)      ██░░░  ——      COMPENDIO aporta: input hooking
                                                            USB/serial, shell sentinel
                                                            (freeze→consult→release), actuator
                                                            control, ephemeral cache, monogamic net.
                                                            Falta: documento propio, protocolo
                                                            con bhnexus, integración Fedora/systemd

Core UI (Flutter)                    SBOS-007      ███░░   832    19 endpoints pero sin schemas
                                     SBOS-018-API           completos de response, estados de UI,
                                                            flujo de errores, navegación

Centrifugo (SP-07)                   (ninguno)      █░░░░  ——      Una sola mención en SBOS-002.
                                                            Bus WebSocket sin especificación.
                                                            Canales, auth, protocolo por daemon

SKULL Release Plane (SP-16)          SBOS-005 §12  ██░░░  (embeb) Protocolo Ed25519 parcial,
                                                            estructura release server,
                                                            formato catálogo, canales detalle

Ficha (sistema de fichas)            SBOS-006      ████░   941    Falta ficha de referencia completa
                                                            (manifest+yaml_engine+task_catalog
                                                            con TODOS los campos posibles)
```

> **Nota sobre reevaluación:** El compendio conceptual proporcionado por el arquitecto eleva a SBOS Nexus Host y SBOS Nexus Agent de NIVEL 1 a NIVEL 2 — ya tienen definición funcional clara (qué hacen, qué no hacen, flujo soberano completo). También enriquece significativamente a bauth (3 dominios de soberanía, presentación física) y bcompass (aprendizaje federado, agentes por manifiesto). Estos conceptos deben integrarse en los documentos formales durante las etapas correspondientes.

Ficha (sistema de fichas)            SBOS-006      ████░   941    Falta manifest.yml ejemplo
                                                            completo con TODOS los campos,
                                                            yaml_engine.yml de referencia

Sistema de Release                   SBOS-005 §12  ██░░░  (embeb) Protocolo Ed25519 parcial,
(SKULL Release Plane, SP-16)                                falta: estructura del release
                                                            server, formato del catálogo,
                                                            canales en detalle
```

---

## 2. Etapas de Trabajo

### ETAPA 1 — Completar el IAM Installer (bos)
**Estimación: 3-4 sesiones**

El IAM Installer es el daemon más documentado (1564 líneas + 4 docs complementarios), pero tiene gaps que impedirían codificar sin preguntas.

| # | Tarea | Qué falta | Entregable |
|---|-------|-----------|------------|
| 1.1 | **API REST completa del daemon `bos`** | Los 19 endpoints del Core UI (SBOS-007) están desde la perspectiva del frontend. Falta la especificación desde la perspectiva del daemon: request validation, códigos de error específicos, rate limiting, autenticación de bosctl vs Core UI, responses de error estructurados | Sección nueva en SBOS-005 o documento SBOS-005-API |
| 1.2 | **Protocolo bosctl ↔ daemon** | bosctl es un CLI que habla con el daemon por socket/REST. No está especificado: ¿Unix socket? ¿HTTP localhost? ¿Autenticación? ¿Formato de output? ¿Exit codes? | Sección nueva en SBOS-005 |
| 1.3 | **Especificación interna de cada módulo de Dominio** | Los 6 módulos tienen descripción de responsabilidad (1 párrafo cada uno) pero no tienen: firma de funciones, estructuras de datos internas, reglas de transición de estado, manejo de errores | Sección expandida en SBOS-005 o doc SBOS-005-MODULES |
| 1.4 | **Especificación de las Sagas de instalación** | Se menciona que INSTALL_RUNNER usa Sagas con compensación, pero no hay: definición de cada Saga (install, update, repair, uninstall), pasos de cada Saga, acciones de compensación por paso, timeouts, condiciones de abort | Sección nueva en SBOS-005 |
| 1.5 | **Formato del .sbos_state.json** | Se menciona como el archivo central de estado, pero no hay schema completo: ¿qué campos? ¿qué estructura? ¿cómo se versionan los cambios? ¿locks? | Sección nueva en SBOS-005 o SBOS-006 |
| 1.6 | **Protocolo de señales __SBOS__** | Se mencionan señales que los task_catalog.sh emiten. Falta: catálogo completo de señales, formato, qué hace el daemon con cada una, señales de error vs progreso vs metadata | Sección expandida en SBOS-005 o SBOS-006 |
| 1.7 | **Ficha de referencia completa** | SBOS-006 explica el sistema de fichas pero no hay un ejemplo completo end-to-end de una ficha real (manifest.yml + yaml_engine.yml + task_catalog.sh) con todos los campos posibles | SBOS-006 expandido o doc SBOS-006-REFERENCE |
| 1.8 | **Actualizar SBOS-MP02** | El MP02 muestra prioridades 3-9 como pendientes cuando ya están completadas | SBOS-MP02 actualizado |

### ETAPA 2 — Completar SBOS Data Kernel (bkernel)
**Estimación: 2 sesiones**

| # | Tarea | Qué falta | Entregable |
|---|-------|-----------|------------|
| 2.1 | **Catálogo completo de reglas WAL** | Hay 12 referencias a reglas pero no un catálogo exhaustivo con: nombre de regla, tabla fuente, evento que la dispara, condición, acción, app destino | Sección expandida en SBOS-010 |
| 2.2 | **Contrato regla ↔ acción** | ¿Cómo se define una regla? ¿YAML? ¿Qué campos? ¿Cómo se testea? ¿Cómo se depura? | SBOS-010 expandido |
| 2.3 | **Manejo de conflictos y DLQ** | ¿Qué pasa cuando una acción falla? ¿Retry? ¿Dead Letter Queue? ¿Notificación? ¿Replay desde WAL? Parcialmente cubierto en SBOS-010-WAL pero necesita consolidación | SBOS-010 expandido + integrar SBOS-010-WAL |
| 2.4 | **Protocolo bkernel ↔ otras apps** | ¿Cómo escribe bkernel en Tryton? ¿API REST? ¿SQL directo? ¿Qué pasa si Tryton está caído? | SBOS-010 expandido |

### ETAPA 3 — Completar SBOS Auth Enforce (bauth)
**Estimación: 2-3 sesiones**

> El compendio define a bauth como "Unified Identity & Permissions Orchestrator (The Sovereign Gatekeeper)" con 3 dominios de soberanía (lógico, físico, financiero), presentación física (QR/NFC/RFID/biométrico), y drift detection. Esto debe integrarse formalmente.

| # | Tarea | Qué falta | Entregable |
|---|-------|-----------|------------|
| 3.1 | **Integrar los 3 dominios de soberanía** | El compendio define: Lógico (redes, dispositivos, LoA), Físico (zonas de acceso, horarios, hardware de proximidad), Financiero (límites transaccionales, SoD). Esto no está en SBOS-008 actual | SBOS-008 v2.0 |
| 3.2 | **Especificación completa de BitMask** | ¿Cuántos bits? ¿Qué significa cada bit? ¿Formato de empaquetado? El compendio menciona Bit1=Unlock_Shell, Bit5=Open_Drawer — necesita catálogo completo | SBOS-008 v2.0 |
| 3.3 | **Plugin rolframework_sync para Keycloak** | El compendio dice que bauth interviene en el flujo de KC validando requiredMethods antes de emitir token. Esto cruza con SBOS-019 (SPIs). Necesita especificación Java del plugin | SBOS-019 expandido |
| 3.4 | **Presentation Layer físico** | QR dinámicos, NFC/RFID, biométricos. ¿Cómo se generan? ¿Cómo se validan? ¿Qué librerías? ¿Protocolo con bhnexus? | SBOS-008 v2.0 |
| 3.5 | **Integrar SBOS-MP01 PARTE A** | Ciclo de vida del realm (Alta/Modificación/Suspensión/Baja) | SBOS-008 v2.0 |
| 3.6 | **Drift detection y auto-corrección** | ¿Cada cuánto verifica? ¿Qué compara? ¿Cómo corrige? ¿Log de correcciones? | SBOS-008 v2.0 |
| 3.7 | **Delegación temporal con vigencia** | validity_period, caducidad automática, herencia de privilegios | SBOS-008 v2.0 |

### ETAPA 4 — Completar SBOS Data Integration (biedata)
**Estimación: 2 sesiones**

| # | Tarea | Qué falta | Entregable |
|---|-------|-----------|------------|
| 4.1 | **Ciclo de vida completo de una Caja** | ¿Cómo se crea una caja? ¿Cómo se testea? ¿Cómo se despliega? ¿Cómo se monitorea? Falta el flujo end-to-end desde declaración hasta producción | SBOS-011 expandido |
| 4.2 | **Protocolo de comunicación con sistemas externos** | Para SIAT, AFIP, SAT: ¿timeouts? ¿reintentos? ¿circuito breaker? ¿qué pasa si el servicio externo cambia su API? | SBOS-011 expandido |
| 4.3 | **Box Engine en detalle** | Se menciona como motor declarativo pero no hay: fases del engine, cómo interpreta box_engine.yml, qué señales emite, manejo de errores por fase | SBOS-011 expandido |

### ETAPA 5 — Completar SBOS AI Tools (bcompass) y SBOS Data RAG (bsearch)
**Estimación: 2 sesiones**

| # | Tarea | Qué falta | Entregable |
|---|-------|-----------|------------|
| 5.1 | **Contrato ruta → LLM → respuesta** | ¿Cómo se pasa el prompt al modelo? ¿Cómo se parsea la respuesta? ¿Qué pasa si el modelo alucina? ¿Fallback? | SBOS-014 expandido |
| 5.2 | **Gestión de contexto y memoria** | ¿Cómo se gestiona el contexto entre invocaciones? ¿Qdrant? ¿Redis? ¿Qué se persiste y qué se descarta? | SBOS-014 expandido |
| 5.3 | **Motor de indexación de bSearch** | ¿Cómo se indexa cada app? ¿Incremental o full? ¿Frecuencia? ¿Qué pasa si una app no tiene datos nuevos? | SBOS-013 expandido |
| 5.4 | **Protocolo de reindexación** | ¿Cuándo se re-indexa? ¿Evento WAL? ¿Cron? ¿Manual? ¿Qué pasa durante la reindexación con las búsquedas activas? | SBOS-013 expandido |

### ETAPA 6 — Crear especificaciones faltantes (Nexus, Centrifugo, Release Plane)
**Estimación: 3-4 sesiones**

> El compendio aporta definiciones funcionales robustas para bhnexus y banexus que elevan su nivel de NIVEL 1 a NIVEL 2. Falta convertir estas definiciones en especificaciones técnicas formales con módulos, protocolos y contratos.

| # | Tarea | Qué falta | Entregable |
|---|-------|-----------|------------|
| 6.1 | **SBOS Nexus Host (bhnexus) — documento completo** | El compendio define: WebSocket connections, BitMask packaging, mTLS, auth cache, hardware bridge (OSDP/MQTT/ONVIF), device fichas en /etc/, multi-dest BitMask (shell+actuators OPEN_RELAY). Falta convertir en spec formal: módulos internos, protocolo con bauth (request/response), formato BitMask (catálogo de bits), protocolo con banexus (WebSocket frames), protocolo con hardware (OSDP/MQTT translation), gestión de device fichas, health monitoring de agentes conectados | **SBOS-035-NEXUS-HOST v1.0** (nuevo) |
| 6.2 | **SBOS Nexus Agent (banexus) — documento completo** | El compendio define: USB/serial input hooking, shell sentinel (freeze→consult→release), actuator control (relés), encrypted ephemeral policy cache, monogamic network. Falta: integración systemd --user en Fedora, protocolo WebSocket con bhnexus (frames, reconexión, heartbeat), formato de la policy cache local, interceptación de shell (mecanismo técnico: PAM? polkit? seccomp?), protocolo de input hooking (udev rules? libusb?), self-integrity verification | **SBOS-036-NEXUS-AGENT v1.0** (nuevo, o sección en SBOS-035) |
| 6.3 | **Flujo Soberano completo** | El compendio define el flujo QR→banexus→bhnexus→bauth→BitMask→acción. Esto es el caso de uso estrella que cruza 3 daemons. Debe documentarse como flujo end-to-end con diagramas, tiempos, errores, y compensaciones | Sección en SBOS-035 o doc SBOS-035-FLOW |
| 6.4 | **Centrifugo (SP-07)** | Bus WebSocket del stack. Necesita: arquitectura, canales por daemon, autenticación JWT, protocolo de suscripción, escalabilidad, relación con bhnexus (¿es el mismo canal? ¿separado?) | **SBOS-037-CENTRIFUGO v1.0** (nuevo) |
| 6.5 | **SKULL Release Plane (SP-16)** | Parcialmente en SBOS-005 §12. Necesita: arquitectura del release server, formato del catálogo, protocolo Ed25519 completo, canales (canary/early/stable), proceso de firma, estructura de un release, upgrade paths | **SBOS-038-RELEASE-PLANE v1.0** (nuevo) |

### ETAPA 7 — Core UI y contratos transversales
**Estimación: 1-2 sesiones**

| # | Tarea | Qué falta | Entregable |
|---|-------|-----------|------------|
| 7.1 | **Core UI: schemas de response completos** | 19 endpoints documentados pero varios sin response schema completo. Falta: todos los campos de response, estados de error, paginación, filtros | SBOS-007 expandido |
| 7.2 | **Core UI: estados de UI y flujos de pantalla** | ¿Qué pantallas existen? ¿Cómo se navega entre ellas? ¿Qué ve el admin cuando una ficha falla? Wireframes textuales o flujos de navegación | SBOS-007 expandido |
| 7.3 | **Contrato WebSocket completo** | Eventos WebSocket parcialmente documentados. Falta: catálogo completo de eventos, formato, reconexión, backpressure | SBOS-007 expandido |
| 7.4 | **Integrar SBOS-018-API en SBOS-007** | El versionado de API REST está en documento separado. Debe consolidarse | SBOS-007 v5.0 |

### ETAPA 8 — Cierre y verificación cruzada
**Estimación: 1 sesión**

| # | Tarea | Qué falta | Entregable |
|---|-------|-----------|------------|
| 8.1 | **Actualizar SBOS-000-INDEX** | Agregar nuevos documentos (035-038), actualizar niveles de madurez, agregar rutas de lectura | SBOS-000 v6.0 |
| 8.2 | **Actualizar SBOS-017 Roadmap** | Reflejar que la Fase A ahora incluye conceptualización completa antes de código. Ajustar fechas si es necesario | SBOS-017 v3.0 |
| 8.3 | **Verificación cruzada de consistencia** | Revisar que los contratos entre daemons son bidireccionales: si bkernel dice "escribo en Tryton por API REST", ¿Tryton tiene esa API documentada? | Reporte de verificación |
| 8.4 | **Auditoría final de madurez** | Todos los componentes deben estar en NIVEL 5. Si alguno está por debajo, identificar qué falta | SBOS-AUDIT v2.0 |

---

## 3. Orden de Ejecución Recomendado

```
ETAPA 1 ─── IAM Installer (bos) ─────────────── 3-4 sesiones
  │          El más documentado. Cerrar gaps para que sea
  │          la referencia de calidad para los demás daemons.
  │
  ▼
ETAPA 2 ─── SBOS Data Kernel (bkernel) ──────── 2 sesiones
  │          Segundo daemon más documentado. Motor central
  │          del sistema — todos los demás dependen de él.
  │
  ▼
ETAPA 3 ─── SBOS Auth Enforce (bauth) ──────── 2 sesiones
  │          Gobierno de identidad. Keycloak es el Principio 1
  │          del stack — sin bauth no hay seguridad.
  │
  ▼
ETAPA 4 ─── SBOS Data Integration (biedata) ── 2 sesiones
  │          Integración con el mundo exterior.
  │          Depende de bkernel para eventos WAL.
  │
  ▼
ETAPA 5 ─── SBOS AI Tools + SBOS Data RAG ──── 2 sesiones
  │          Inteligencia y búsqueda. Dependen de bkernel
  │          y de la infraestructura IA (aiserver).
  │
  ▼
ETAPA 6 ─── Nexus Host + Agent + Centrifugo ── 2-3 sesiones
  │          + Release Plane
  │          Los componentes sin documento propio.
  │
  ▼
ETAPA 7 ─── Core UI + contratos transversales ─ 1-2 sesiones
  │          El frontend que consume todos los daemons.
  │
  ▼
ETAPA 8 ─── Cierre y verificación cruzada ───── 1 sesión
             Auditoría final. Todo en NIVEL 5.
```

**Total estimado: 15-18 sesiones de trabajo.**

---

## 4. Criterio de "Listo para Código"

Un componente está listo para código cuando un desarrollador que NUNCA ha trabajado en el proyecto puede:

1. Leer el documento y entender qué hace el componente sin preguntar
2. Identificar todos los módulos/clases que necesita crear
3. Conocer las firmas de las funciones públicas
4. Saber qué estructuras de datos usa internamente
5. Entender todos los flujos (happy path Y error paths)
6. Conocer los contratos con otros componentes (APIs, eventos, archivos)
7. Saber qué tests escribir (porque los edge cases están documentados)
8. Implementar sin tomar decisiones de diseño — todas ya están tomadas

Si en algún punto el desarrollador tiene que inventar algo que no está en el documento, **la documentación no está lista**.

---

## 5. Registro de Cambios

### v1.0 — Marzo 2026

Documento nuevo. Plan maestro de conceptualización que mapea las 8 etapas de trabajo necesarias para llevar toda la documentación del SBOS a NIVEL 5 (listo para código).

---

*SKULL · SBOS · SBOS-MP03-PlanConceptualizacion · v1.0 · Marzo 2026*
*Clasificación: GESTIÓN DE PROYECTO — Planificación de Conceptualización*
