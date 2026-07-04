# SBOS-014 — SBOS AI Tools: Collaborative & Federated Intelligence
## SKULL · SBOS — Sovereign Business Operating System
### v5.0 · Marzo 2026

---

| Campo | Valor |
|-------|-------|
| **Nombre original** | SBOS AI Tools |
| **Nombre conceptual** | SBOS AI Tools: Collaborative & Federated Intelligence |
| **Daemon** | `bcompass` |
| **Servicio systemd** | `bcompass.service` |
| **Lenguaje** | Go |
| **Unidad declarativa** | Ruta |
| **Directorio** | `/etc/bos/blibs/bcompass/router/<nombre_ruta>/` |

---

**Código:** SBOS-014
**Versión:** 4.0
**Estado:** ACTIVO
**Extensión:** SBOS-014-LLM-Prompts-Langfuse.md — SBOS-014-EXT-LLM (Gestión de Prompts LLM con versionado semver + Langfuse — archivo separado permanente, 520+ líneas)
**Reemplaza a:** SBOS-011-BCOMPASS v3.0 (SUPERSEDED)
**Clasificación:** Especificación Técnica — Componente Core del Host

---

## Tabla de Contenidos

1. [Qué es SBOS AI Tools](#1-qué-es-bcompass)
2. [SBOS AI Tools en el Contexto de la Industria](#2-bcompass-en-el-contexto-de-la-industria)
3. [Posición Arquitectónica](#3-posición-arquitectónica)
4. [SBOS AI Tools como Capa de Orquestación Formal (Capa 4)](#4-bcompass-como-capa-de-orquestación-formal-capa-4)
5. [Principios Arquitectónicos](#5-principios-arquitectónicos)
6. [El Modelo de Rutas](#6-el-modelo-de-rutas)
7. [Los Cuatro Tipos de Ruta](#7-los-cuatro-tipos-de-ruta)
8. [Los Cuatro Contratos de una Ruta](#8-los-cuatro-contratos-de-una-ruta)
9. [El Contrato de Identidad: manifest.yml](#9-el-contrato-de-identidad-manifestyml)
10. [El Contrato Temporal: route_engine.yml](#10-el-contrato-temporal-route_engineyml)
11. [El Catálogo de Tareas: route_catalog.so](#11-el-catálogo-de-tareas-route_catalogso)
12. [Los Resources: Conocimiento Cristalizado](#12-los-resources-conocimiento-cristalizado)
13. [El Motor Binario SBOS AI Tools](#13-el-motor-binario-bcompass)
14. [La Route API — Contrato entre el Motor y la Ruta](#14-la-route-api--contrato-entre-el-motor-y-la-ruta)
15. [Ollama — El LLM Local Soberano](#15-ollama--el-llm-local-soberano)
16. [La Base de Datos Propia: bcompass_db](#16-la-base-de-datos-propia-bcompass_db)
17. [Ciclo de Vida como Servicio systemd](#17-ciclo-de-vida-como-servicio-systemd)
18. [La Ficha SBOS AI Tools en el SBOS IAM Installer](#18-la-ficha-bcompass-en-el-bos)
19. [Protocolo de Notificación SBOS AI Tools → SBOS VDI](#19-protocolo-de-notificación-bcompass--sbos-vdi)
20. [Catálogo de Rutas Base](#20-catálogo-de-rutas-base)
21. [Flujos Completos](#21-flujos-completos)
22. [Fronteras que SBOS AI Tools Nunca Cruza](#22-fronteras-que-bcompass-nunca-cruza)
23. [Hoja de Ruta de Desarrollo](#23-hoja-de-ruta-de-desarrollo)
24. [Referencias Cruzadas](#24-referencias-cruzadas)

---

## 1. Qué es SBOS AI Tools

SBOS AI Tools es el **motor soberano de inteligencia y asistencia del SBOS**. Es un daemon binario que observa continuamente los datos operacionales del stack, ejecuta rutas de inteligencia declarativas, y orienta al negocio: detectando patrones, sugiriendo mejoras, automatizando procesos, y asistiendo a usuarios y administradores con inteligencia en lenguaje natural.

El nombre describe su función: **una brújula no conduce — orienta**. SBOS AI Tools no decide por el negocio — le muestra la dirección. El humano decide si camina hacia allá.

```
SBOS Data Kernel:    escucha WAL        → procesa reglas YAML    → sincroniza apps internas
SBOS Data Integration (biedata): escucha eventos    → selecciona caja         → ejecuta box_engine.yml + box_catalog.so
SBOS AI Tools (bcompass): escucha eventos    → selecciona ruta         → ejecuta route_engine.yml + route_catalog.so
                                                         → emite sugerencias / respuestas / alertas
```

SBOS AI Tools no tiene interfaz gráfica. No expone APIs REST al exterior. Es un procesador de inteligencia autónomo y silencioso — idéntico en naturaleza al SBOS Data Kernel y a SBOS Data Integration.

### El principio fundamental e inviolable

```
DATOS → SBOS AI Tools OBSERVA → ANALIZA → ORIENTA → HUMANO DECIDE → SISTEMA EJECUTA
                                         ↑
                          (NUNCA autónomo en decisiones de alto impacto)
```

SBOS AI Tools es un orientador inteligente, no un agente autónomo. Para acciones de bajo impacto (responder preguntas, generar reportes, notificar anomalías) actúa directamente. Para acciones de alto impacto (sugerir nuevas reglas al SBOS Data Kernel, modificar configuraciones del stack) siempre requiere aprobación humana explícita en el Core UI.

### SBOS AI Tools no es una IA — usa IA

SBOS AI Tools *usa* modelos de lenguaje (LLMs via Ollama local) como herramienta, igual que el SBOS Data Kernel *usa* PostgreSQL como herramienta. La IA es el motor de algunas rutas — no el producto. El producto es la orientación inteligente al negocio.

---

## 2. SBOS AI Tools en el Contexto de la Industria

### Por qué no se usan plataformas de IA existentes

Plataformas como n8n, Dify o LangChain son herramientas excelentes pero introducen complejidad de integración y dependencias externas incompatibles con la filosofía soberana del SBOS:

| Herramienta | Por qué no encaja como motor de producción | SBOS AI Tools en su lugar |
|---|---|---|
| n8n | **Sustainable Use License — no es software libre. Viola el Principio 3 del stack.** SSO enterprise de pago. | `route_type: flow` — workflows declarativos con `route_engine.yml` |
| Dify | Integración compleja, no es ficha del SBOS IAM Installer | `route_type: agent` — agentes con Ollama local |
| Airflow | Overhead enorme para este caso de uso | Scheduler integrado en el motor SBOS AI Tools |
| LangChain | Abstracción excesiva, datos salen del servidor si se usa API cloud | `httpx` directo a Ollama local — sin intermediarios |

> **Nota sobre n8n:** n8n está explícitamente vetado en el stack SBOS. Su Sustainable Use License prohíbe uso competitivo y restringe redistribución comercial, en directa contradicción con el Principio 3 de Licencias Libres del stack (MIT, Apache 2.0, GPL, AGPL o equivalentes). SBOS AI Tools cubre su rol completamente sin esta restricción.

**Flowise — rol complementario como banco de pruebas:**

Flowise (Apache 2.0, uso comercial libre) tiene un rol específico en el ecosistema SBOS distinto al de producción. Su arquitectura tiene limitaciones conocidas en carga sostenida (fugas de memoria bajo concurrencia alta), lo que lo hace inadecuado como motor de producción. Su valor real es como **prototipador rápido de agentes**: un desarrollador SKULL o del cliente construye y valida un agente visualmente en Flowise → cuando el agente está probado y estable → se migra como ruta `agent` de SBOS AI Tools para producción. Esta separación de fases — Flowise para diseño, SBOS AI Tools para ejecución — reduce el tiempo de desarrollo de rutas nuevas sin comprometer la estabilidad del ecosistema.

**Ollama sí se usa** — porque un LLM es hardware y modelos, no software de negocio. Ollama corre 100% local en el servidor del cliente. Los datos nunca salen del servidor. Soberanía total.

---

## 3. Posición Arquitectónica

```
┌──────────────────────────────────────────────────────────────────┐
│  HOST UBUNTU                                                     │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  SBOS AI Tools (systemd — siempre activo)                       │  │
│  │                                                            │  │
│  │  Motor Binario                                             │  │
│  │    ├── Event Listener    (escucha triggers de rutas)       │  │
│  │    ├── Route Resolver    (selecciona la ruta correcta)     │  │
│  │    ├── Route Loader      (dlopen route_catalog.so)         │  │
│  │    ├── Engine Executor   (ejecuta route_engine.yml)        │  │
│  │    ├── Ollama Client     (LLM local soberano)              │  │
│  │    └── Result Emitter    (sugerencias, notificaciones)     │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  /etc/bos/blibs/bcompass/router/                                           │
│    ├── analyst/reglas_inactivas/    ← RUTA                      │
│    ├── analyst/correlaciones/       ← RUTA                      │
│    ├── agent/asistente_empleado/    ← RUTA                      │
│    ├── flow/reporte_ventas/         ← RUTA                      │
│    └── report/estado_bkernel/       ← RUTA                      │
│                                                                  │
│  bcompass_db (PostgreSQL)  ← sugerencias, conversaciones, flows │
└──────────────────────────────────────────────────────────────────┘
         │ solo lectura sobre BDs del stack
         ▼
┌────────────────────────────────────┐
│  bkernel_db, biedata_db, apps BDs │
└────────────────────────────────────┘
         │ Ollama (LLM local)
         ▼
┌────────────────────────────────────┐
│  Servidor Ollama (localhost)        │
│  qwen3:8b, qwen3:32b, deepseek-r1, etc.   │
└────────────────────────────────────┘
```

---

## 4. SBOS AI Tools como Capa de Orquestación Formal (Capa 4)

El stack SBOS tiene una arquitectura de capas funcionales bien definida. SBOS AI Tools ocupa formalmente la **Capa 4 — Orquestación de Inteligencia**, y su relación con las capas inferiores no es casual — es parte del diseño de gobernanza del sistema.

```
┌─────────────────────────────────────────────────────────────┐
│  CAPA 4 — ORQUESTACIÓN DE INTELIGENCIA                      │
│  SBOS AI Tools                                                   │
│  Routes → Casos de Uso Formales del Negocio                 │
│  Approval Gates → Compensación Humana en Sagas              │
└─────────────────────────────────────────────────────────────┘
         ▲ observa (solo lectura)          ▼ emite sugerencias / aprobaciones
┌─────────────────────────────────────────────────────────────┐
│  CAPA 3 — INTEGRACIÓN Y SINCRONIZACIÓN                      │
│  SBOS Data Kernel (SBOS-010) + SBOS Data Integration (SBOS-011)                 │
│  Reglas de replicación, transformación, cajas de integración│
└─────────────────────────────────────────────────────────────┘
         ▲ escucha WAL / eventos
┌─────────────────────────────────────────────────────────────┐
│  CAPA 2 — DATOS OPERACIONALES                               │
│  PostgreSQL, Redis, Qdrant                                  │
│  bkernel_db, biedata_db, bcompass_db, apps BDs             │
└─────────────────────────────────────────────────────────────┘
         ▲ sobre hardware
┌─────────────────────────────────────────────────────────────┐
│  CAPA 1 — INFRAESTRUCTURA SOBERANA                          │
│  Host Ubuntu + Kubernetes (SBOS-004)                       │
│  Daemons soberanos del host + Pods del cluster              │
└─────────────────────────────────────────────────────────────┘
```

### SBOS AI Tools Routes = Casos de Uso Formales

Un `SBOS AI Tools route` no es solo una tarea técnica. Cada ruta encapsula un **caso de uso de negocio completo y declarado**:

- `analyst_reglas_inactivas` → Caso de uso: *"El administrador debe revisar y limpiar reglas SBOS Data Kernel sin actividad"*
- `flow_reporte_ventas_mensual` → Caso de uso: *"Gerencia recibe análisis de ventas del mes anterior antes del día 2"*
- `agent_asistente_empleado` → Caso de uso: *"Un empleado puede consultar sus datos laborales en lenguaje natural sin contactar a RRHH"*

Los `routes` son el punto donde la arquitectura técnica se conecta con el lenguaje del negocio. Son, en esencia, los contratos formales entre el stack tecnológico y los procesos de la organización.

### Approval Gates = Compensación Humana en Sagas

En arquitecturas de microservicios, el patrón **Saga** coordina transacciones distribuidas largas usando eventos compensadores cuando algo falla. El concepto de aprobación humana de SBOS AI Tools es la extensión de este patrón al dominio de la inteligencia de negocio.

```
SAGA DISTRIBUIDA CLÁSICA:
  Paso 1 → Paso 2 → Paso 3 → [FALLO] → Compensación automática

SAGA DE INTELIGENCIA CON SBOS AI Tools (Approval Gate):
  SBOS AI Tools detecta patrón → genera sugerencia (status: pending)
       ↓
  APPROVAL GATE: Administrador revisa en Core UI
       ├── [APRUEBA] → Sistema ejecuta la acción recomendada
       └── [RECHAZA] → Compensación: sugerencia archivada + feedback a la ruta
```

**El Approval Gate es la compensación humana en la Saga de inteligencia.** Si SBOS AI Tools sugiere desactivar una regla del SBOS Data Kernel y el administrador rechaza la sugerencia, ese rechazo retroalimenta el sistema: la ruta puede aprender que ese tipo de regla no debe sugerirse para desactivación en el futuro (vía feedback en `compass_suggestions.review_notes`).

**Las rutas `flow` con `approval_required: true` implementan este patrón explícitamente:**

```yaml
# route_engine.yml con Approval Gate intermedio
phases:

  analyze:
    tasks:
      - task: "flow_analyze_financial_anomaly"
        output: anomaly_report

  approval_gate:                              # ← GATE HUMANO EXPLÍCITO
    tasks:
      - task: "request_human_approval"        # GLOBAL
        params:
          title: "Anomalía contable detectada requiere revisión"
          data: "{anomaly_report}"
          timeout_hours: 24                   # Si no se aprueba en 24h → abort
          notify_roles: ["ROLE_FINANCE_ADMIN"]
        output: approval_decision

  execute:
    condition: "{approval_decision.approved == true}"  # Solo si fue aprobado
    tasks:
      - task: "flow_execute_corrective_action"
        params:
          action: "{approval_decision.selected_action}"
```

**Categorías de governance por impacto:**

| Categoría | Impacto | Requiere Approval Gate | Ejemplos |
|---|---|---|---|
| 1 | Bajo | No — ejecuta directamente | Generar reporte, responder pregunta, notificar |
| 2 | Medio | Sí — aprobación de rol CONFIG | Sugerir desactivar regla SBOS Data Kernel, proponer nuevo mapping |
| 3 | Alto | Sí — aprobación de rol OWNER | Proponer cambio de configuración del stack, acciones con impacto financiero |

---

## 5. Principios Arquitectónicos

**P1 — La ruta es la unidad de conocimiento.**
Todo el conocimiento de un proceso de inteligencia vive en su ruta. El motor SBOS AI Tools no sabe qué analiza `reglas_inactivas` ni cómo responde `asistente_empleado`. Las rutas saben. El motor ejecuta.

**P2 — route_engine.yml declara la intención. route_catalog.so implementa la lógica.**
El `route_engine.yml` es declarativo — dice qué fases ocurren y en qué orden. El `route_catalog.so` es imperativo — implementa los queries estadísticos, los prompts LLM, la lógica de análisis específica de esa ruta.

**P3 — Solo lectura sobre el stack.**
SBOS AI Tools nunca escribe en las BDs del stack directamente. Sus credenciales PostgreSQL son `SELECT` únicamente sobre `bkernel_db`, `biedata_db`, y las BDs de las apps. Solo escribe en `bcompass_db` (su propia base de datos) y en los destinos de sus rutas (Core UI, canales de notificación, email).

**P4 — El humano siempre aprueba acciones de alto impacto.**
Las rutas `analyst` producen sugerencias con status `pending` en `bcompass_db`. El administrador las aprueba o rechaza en Core UI. SBOS AI Tools nunca ejecuta acciones de alto impacto de forma autónoma.

**P5 — LLM local soberano.**
Los prompts y datos del stack nunca salen del servidor del cliente. Ollama corre localmente. Sin dependencia de APIs cloud. Sin costos de LLM externos. Sin datos en servidores de terceros.

**P6 — Binario como motor, .so como conocimiento.**
El mismo meta-patrón del SBOS Data Kernel e SBOS Data Integration. El motor es estable. El conocimiento específico de cada ruta vive en `route_catalog.so` — cargado con `dlopen()`. Agregar una nueva ruta de inteligencia es crear una carpeta. El motor no cambia.

**P7 — Auditoría completa.**
Toda ejecución de ruta queda registrada en `bcompass_db`: ruta, tipo, resultado, sugerencias generadas, conversaciones de agentes, duración.

---

## 6. El Modelo de Rutas

La ruta es la unidad atómica de inteligencia de SBOS AI Tools. Es el equivalente exacto de la ficha del SBOS IAM Installer y de la caja de SBOS Data Integration — encapsula todo el conocimiento para ejecutar un proceso de inteligencia específico.

```
/etc/bos/blibs/bcompass/
└── router/
    ├── analyst/                             ← rutas de análisis de patrones
    │   ├── reglas_inactivas/                ← RUTA
    │   │   ├── manifest.yml
    │   │   ├── route_engine.yml
    │   │   ├── route_catalog.so
    │   │   └── resources/
    │   │       └── query.sql
    │   │
    │   ├── correlaciones_sin_regla/         ← RUTA
    │   │   ├── manifest.yml
    │   │   ├── route_engine.yml
    │   │   ├── route_catalog.so
    │   │   └── resources/
    │   │       └── query.sql
    │   │
    │   └── errores_recurrentes_biedata/    ← RUTA
    │       ├── manifest.yml
    │       ├── route_engine.yml
    │       ├── route_catalog.so
    │       └── resources/
    │           └── query.sql
    │
    ├── agent/                               ← rutas de agentes conversacionales
    │   ├── asistente_empleado/              ← RUTA
    │   │   ├── manifest.yml
    │   │   ├── route_engine.yml
    │   │   ├── route_catalog.so
    │   │   └── resources/
    │   │       ├── system_prompt.txt
    │   │       └── data_queries.yml
    │   │
    │   └── asistente_admin/                 ← RUTA
    │       ├── manifest.yml
    │       ├── route_engine.yml
    │       ├── route_catalog.so
    │       └── resources/
    │           ├── system_prompt.txt
    │           └── data_queries.yml
    │
    ├── flow/                                ← rutas de automatización de procesos
    │   ├── reporte_ventas_mensual/          ← RUTA
    │   │   ├── manifest.yml
    │   │   ├── route_engine.yml
    │   │   ├── route_catalog.so
    │   │   └── resources/
    │   │       ├── query.sql
    │   │       ├── prompt.txt
    │   │       └── template.xlsx
    │   │
    │   └── alerta_anomalia_contable/        ← RUTA
    │       ├── manifest.yml
    │       ├── route_engine.yml
    │       ├── route_catalog.so
    │       └── resources/
    │           └── query.sql
    │
    └── report/                              ← rutas de reportes automáticos
        ├── estado_semanal_bkernel/          ← RUTA
        │   ├── manifest.yml
        │   ├── route_engine.yml
        │   ├── route_catalog.so
        │   └── resources/
        │       └── query.sql
        │
        └── integraciones_mensual_biedata/  ← RUTA
            ├── manifest.yml
            ├── route_engine.yml
            ├── route_catalog.so
            └── resources/
                └── query.sql
```

---

## 7. Los Cuatro Tipos de Ruta

El tipo de ruta determina qué hace y cómo interactúa con el negocio.

### route_type: analyst

Observa datos históricos del stack, aplica análisis estadístico, y produce **sugerencias** para el administrador. Las sugerencias tienen status `pending` hasta que el admin las aprueba o rechaza en Core UI.

```
OBSERVA bkernel_db / biedata_db → ANALIZA → SUGIERE → ADMIN APRUEBA/RECHAZA
```

Ejemplos: reglas SBOS Data Kernel inactivas, correlaciones sin regla documentada, errores recurrentes en SBOS Data Integration, patrones de anomalías.

### route_type: agent

Mantiene un agente conversacional disponible para usuarios o administradores. Responde preguntas en lenguaje natural usando Ollama (LLM local) con contexto RAG de los datos del stack relevantes para el usuario.

```
USUARIO PREGUNTA → RUTA recupera contexto del stack → OLLAMA genera respuesta → USUARIO recibe
```

Ejemplos: asistente de empleado (vacaciones, datos laborales), asistente de administrador (análisis del stack), soporte al cliente (RAG sobre manuales en Nextcloud).

### route_type: flow

Ejecuta workflows de automatización de procesos de negocio declarados en `route_engine.yml`. Puede combinar consultas al stack, análisis LLM, generación de archivos, notificaciones, y esperas de aprobación humana (Approval Gates).

```
TRIGGER → EJECUTA FASES → (opcionalmente espera Approval Gate) → EMITE RESULTADO
```

Ejemplos: reporte mensual de ventas con análisis LLM, notificación de anomalía contable al gerente, resumen semanal del estado del stack.

### route_type: report

Genera reportes periódicos automáticos en formatos Excel, PDF o texto enriquecido. Variante simplificada de `flow` especializada en generación y distribución de documentos.

```
SCHEDULE → CONSULTA stack → GENERA documento → DISTRIBUYE (email, Nextcloud, canal)
```

Ejemplos: reporte semanal del SBOS Data Kernel, estado mensual de integraciones SBOS Data Integration, reporte RRHH mensual.

---

## 8. Los Cuatro Contratos de una Ruta

Toda ruta es simultáneamente cuatro contratos — exactamente el mismo patrón de la ficha y la caja:

**Contrato de Identidad — `manifest.yml`**
Declara qué es la ruta, qué tipo es, qué trigger la activa, qué fuentes de datos observa, y con qué governance opera.

**Contrato Temporal — `route_engine.yml`**
Declara qué debe ocurrir en cada fase: observar, analizar, generar, sugerir/responder/notificar. No contiene lógica — contiene intención declarativa. La lógica vive en `route_catalog.so`.

**Catálogo de Tareas — `route_catalog.so`**
Implementa las tareas específicas de esta ruta: queries estadísticos complejos, construcción de prompts con contexto, llamadas a Ollama, renderizado de documentos. Shared object compilado, cargado dinámicamente con `dlopen()`.

**Resources — `resources/`**
Artefactos cristalizados: queries SQL probados en producción, prompts del sistema para los agentes, plantillas de documentos, configuración de modelos LLM.

---

## 9. El Contrato de Identidad: manifest.yml

```yaml
# /etc/bos/blibs/bcompass/router/analyst/reglas_inactivas/manifest.yml

identity:
  id: "analyst_reglas_inactivas"
  name: "Análisis de Reglas Inactivas del SBOS Data Kernel"
  description: "Detecta reglas del SBOS Data Kernel que no se han activado en N días y sugiere desactivarlas"
  version: "1.0"
  route_type: "analyst"            # analyst | agent | flow | report

trigger:
  type: schedule
  cron: "0 2 * * 1"               # Lunes a las 2:00 AM (fuera de horario)

sources:                           # fuentes de datos — solo lectura
  - db: bkernel_db
    tables: [rule_execution_log, replication_state]

output:
  type: suggestion                 # suggestion | response | notification | document
  suggestion_category: "bkernel_optimization"
  pending_review: true             # toda sugerencia requiere revisión humana

governance:
  category: 1                      # la ruta en sí no requiere confirmación
  suggestion_category: 2           # aplicar la sugerencia sí requiere confirmación
  notify_channel: "#bcompass-insights"
  notify_on: [new_suggestions]
```

```yaml
# /etc/bos/blibs/bcompass/router/agent/asistente_empleado/manifest.yml

identity:
  id: "agent_asistente_empleado"
  name: "Asistente de Empleado SBOS"
  description: "Responde preguntas del empleado sobre sus datos laborales en el stack"
  version: "1.0"
  route_type: "agent"

trigger:
  type: message                    # activado por mensaje entrante via Redis bcompass:messages
  interfaces:                      # lista de interfaces habilitadas para esta ruta
    - nextcloud_talk_bot           # bot en Nextcloud Talk (adapter en commsserver)
    - rocketchat_bot               # bot en Rocket.Chat (webhook outgoing)
    - mattermost_bot               # slash command /bcompass en Mattermost
  audience: employee               # cualquier usuario con JWT válido del realm

sources:
  - app: orangehrm
    query_file: "resources/data_queries.yml"
    filter_by: user_email          # solo datos del usuario autenticado
  - app: nextcloud
    documents_path: "/empresa/politicas/"

llm:
  model: "qwen3:4b-q4"
  system_prompt_file: "resources/system_prompt.txt"
  max_tokens: 500

output:
  type: response                   # responde directamente al usuario
  store_conversation: true         # guarda en bcompass_db.agent_conversations

governance:
  category: 1
  data_scope: own_user_only        # acceso estrictamente limitado a datos del usuario
```

```yaml
# /etc/bos/blibs/bcompass/router/flow/reporte_ventas_mensual/manifest.yml

identity:
  id: "flow_reporte_ventas_mensual"
  name: "Reporte Mensual de Ventas"
  description: "Genera y distribuye el reporte mensual de ventas con análisis ejecutivo"
  version: "1.0"
  route_type: "flow"

trigger:
  type: schedule
  cron: "0 9 1 * *"               # Primer día del mes a las 9:00

sources:
  - app: tryton
    query_file: "resources/query.sql"

llm:
  model: "qwen3:8b-q4"
  prompt_file: "resources/prompt.txt"

output:
  type: document
  format: excel
  template: "resources/template.xlsx"
  distribute:
    - channel: "#gerencia-ventas"
    - email: "{config.gerencia_emails}"
    - nextcloud_path: "/empresa/reportes/ventas/"

governance:
  category: 1
  notify_channel: "#gerencia-ventas"
```

---

## 10. El Contrato Temporal: route_engine.yml

```yaml
# /etc/bos/blibs/bcompass/router/analyst/reglas_inactivas/route_engine.yml

phases:

  observe:
    tasks:
      - task: "check_source_connection"        # GLOBAL
        params:
          db: bkernel_db

      - task: "analyst_query_inactive_rules"   # ESPECÍFICA — en route_catalog.so
        params:
          query_file: "resources/query.sql"
          inactive_threshold_days: 90
        output: inactive_rules

  analyze:
    tasks:
      - task: "analyst_score_suggestions"      # ESPECÍFICA
        params:
          data: "{inactive_rules}"
          min_confidence: 0.80
        output: scored_suggestions

  suggest:
    tasks:
      - task: "store_suggestions"              # GLOBAL — guarda en bcompass_db
        params:
          suggestions: "{scored_suggestions}"
          category: "bkernel_optimization"
          status: pending

      - task: "notify_if_new"                  # GLOBAL — notifica si hay sugerencias nuevas
        params:
          suggestions: "{scored_suggestions}"
          channel: "#bcompass-insights"
          message: "SBOS AI Tools detectó {count} reglas inactivas. Revisar en Core UI."
```

```yaml
# /etc/bos/blibs/bcompass/router/flow/reporte_ventas_mensual/route_engine.yml

phases:

  read:
    tasks:
      - task: "db_query"                        # GLOBAL
        params:
          app: tryton
          query_file: "resources/query.sql"
          date_from: "first_day_of_last_month()"
          date_to: "last_day_of_last_month()"
        output: ventas_data

  analyze:
    tasks:
      - task: "llm_prompt"                      # GLOBAL — llama a Ollama local
        params:
          model: "qwen3:8b-q4"
          prompt_file: "resources/prompt.txt"
          context:
            data: "{ventas_data}"
        output: analisis_ejecutivo

  generate:
    tasks:
      - task: "flow_generate_excel"             # ESPECÍFICA — genera Excel con datos + análisis
        params:
          data: "{ventas_data}"
          analysis: "{analisis_ejecutivo}"
          template: "resources/template.xlsx"
        output: reporte_excel

  distribute:
    tasks:
      - task: "notify_with_attachment"          # GLOBAL
        params:
          channel: "#gerencia-ventas"
          message: "📊 Reporte de ventas listo.\n\n{analisis_ejecutivo}"
          attach: "{reporte_excel}"

      - task: "send_email"                      # GLOBAL
        params:
          to: "{config.gerencia_emails}"
          subject: "Reporte de Ventas — {mes_anterior}"
          body: "{analisis_ejecutivo}"
          attach: "{reporte_excel}"

      - task: "save_to_nextcloud"               # GLOBAL
        params:
          file: "{reporte_excel}"
          path: "/empresa/reportes/ventas/"
```

```yaml
# /etc/bos/blibs/bcompass/router/agent/asistente_empleado/route_engine.yml

phases:

  retrieve_context:
    tasks:
      - task: "agent_fetch_user_data"           # ESPECÍFICA — recupera datos del usuario
        params:
          queries: "resources/data_queries.yml"
          user_email: "{event.user_email}"
        output: user_context

      - task: "rag_fetch_documents"             # GLOBAL — RAG sobre Nextcloud
        params:
          path: "/empresa/politicas/"
          query: "{event.user_message}"
          top_k: 3
        output: doc_context

  respond:
    tasks:
      - task: "llm_prompt"                      # GLOBAL — Ollama local
        on_failure: notify_and_abort
        params:
          model: "qwen3:4b-q4"
          system_prompt_file: "resources/system_prompt.txt"
          context:
            user_data: "{user_context}"
            documents: "{doc_context}"
          user_message: "{event.user_message}"
        output: agent_response

      - task: "send_response"                   # GLOBAL — responde al usuario via adapter Redis
        on_failure: retry(3)
        params:
          interface: "{event.interface}"        # resuelto dinámicamente del payload Redis
          user: "{event.user_sub}"
          message: "{agent_response}"

      - task: "log_conversation"                # GLOBAL — registra en bcompass_db
        params:
          agent_id: "agent_asistente_empleado"
          user_sub: "{event.user_sub}"
          message: "{event.user_message}"
          response: "{agent_response}"
```

---

## 11. El Catálogo de Tareas: route_catalog.so

Cada ruta tiene su propio shared object con las funciones específicas de esa ruta de inteligencia. El motor SBOS AI Tools lo carga con `dlopen()` antes de ejecutar y lo libera al terminar.

### La Route API — contrato entre el motor y el .so

```c
// bcompass_route_api.h — distribuido por SKULL
// C ABI estable — interfaz estable para plugins compilados en Rust

typedef struct {
    const char* name;           // "analyst_reglas_inactivas"
    const char* version;        // "1.0.0"
    const char* route_type;     // "analyst" | "agent" | "flow" | "report"

    // Función principal — ejecuta una tarea específica de la ruta
    CompassResult (*execute_task)(
        const char*              task_name,
        const BCompassContext*    ctx,
        const CompassHandles*    handles
    );

    // Validación en startup
    CompassResult (*validate)(const CompassHandles* handles);

} BCompassRoute;

// Contexto de ejecución
typedef struct {
    const char* route_id;       // "analyst_reglas_inactivas"
    const char* run_id;         // UUID de la ejecución
    const char* params_json;    // params del route_engine.yml
    const char* outputs_json;   // outputs del pipeline
    const char* resources_path; // path a resources/ de la ruta
    const char* event_json;     // evento que disparó la ruta (si aplica)
} BCompassContext;

// Handles de acceso a recursos
typedef struct {
    // Lectura de BDs del stack (SOLO LECTURA — siempre)
    CompassQueryResult (*db_query)(const char* db_name,
                                   const char* sql,
                                   const char* params_json);

    // Llamada a Ollama local
    const char* (*llm_generate)(const char* model,
                                 const char* prompt,
                                 int max_tokens);

    // Escritura en bcompass_db (única BD donde SBOS AI Tools puede escribir)
    CompassResult (*bcompass_db_exec)(const char* sql, const char* params_json);

    // Logging
    void (*log)(const char* level, const char* message);

    // Variables de entorno / secrets
    const char* (*get_env)(const char* var_name);

} CompassHandles;

// Punto de entrada resuelto con dlsym()
BBCompassRoute* bcompass_route_init();
```

### Ejemplo: route_catalog.so de reglas_inactivas

```rust
// router/analyst/reglas_inactivas/src/lib.rs

extern "C" fn execute_task(
    task_name: *const c_char,
    ctx: *const BCompassContext,
    handles: *const CompassHandles,
) -> CompassResult {
    match task_name_str {
        "analyst_query_inactive_rules" => query_inactive_rules(ctx, handles),
        "analyst_score_suggestions"    => score_suggestions(ctx, handles),
        _                              => CompassResult::TaskNotFound,
    }
}

fn query_inactive_rules(ctx: *const BCompassContext,
                        h: *const CompassHandles) -> CompassResult {
    let handles = unsafe { &*h };
    let context = unsafe { &*ctx };

    let params: serde_json::Value = serde_json::from_str(
        unsafe { CStr::from_ptr(context.params_json).to_str().unwrap() }
    ).unwrap();
    let threshold_days = params["inactive_threshold_days"].as_i64().unwrap_or(90);

    // Query estadístico sobre bkernel_db — solo lectura
    let sql = format!(r#"
        SELECT
            r.rule_id,
            r.rule_name,
            r.app,
            MAX(l.executed_at) AS last_execution,
            COUNT(l.id) AS total_executions,
            EXTRACT(DAY FROM NOW() - MAX(l.executed_at)) AS days_inactive
        FROM bkernel_rule_index r
        LEFT JOIN rule_execution_log l ON l.rule_id = r.rule_id
        WHERE r.enabled = true
        GROUP BY r.rule_id, r.rule_name, r.app
        HAVING EXTRACT(DAY FROM NOW() - MAX(l.executed_at)) > {}
            OR MAX(l.executed_at) IS NULL
        ORDER BY days_inactive DESC NULLS FIRST
    "#, threshold_days);

    let result_ptr = (handles.db_query)(
        b"bkernel_db\0".as_ptr() as _,
        CString::new(sql).unwrap().as_ptr(),
        b"{}\0".as_ptr() as _,
    );

    // Almacenar resultado en el pipeline de outputs
    CompassResult::Ok
}

fn score_suggestions(ctx: *const BCompassContext,
                     h: *const CompassHandles) -> CompassResult {
    // Calcula confianza por regla inactiva
    // Filtra las que no alcanzan min_confidence
    // Genera sugerencias con evidencia estadística
    CompassResult::Ok
}
```

---

## 12. Los Resources: Conocimiento Cristalizado

```sql
-- router/analyst/reglas_inactivas/resources/query.sql
SELECT rule_id, rule_name, app,
       MAX(executed_at) AS last_execution,
       EXTRACT(DAY FROM NOW() - MAX(executed_at)) AS days_inactive
FROM bkernel_rule_index r
LEFT JOIN rule_execution_log l USING (rule_id)
WHERE r.enabled = true
GROUP BY rule_id, rule_name, app
HAVING EXTRACT(DAY FROM NOW() - MAX(executed_at)) > :threshold_days
    OR MAX(executed_at) IS NULL
ORDER BY days_inactive DESC NULLS FIRST
```

```
-- router/agent/asistente_empleado/resources/system_prompt.txt
Eres el asistente interno de {empresa_nombre}.
Tienes acceso únicamente a los datos laborales del empleado {user_name}.
Responde solo preguntas relacionadas con su información en el sistema.
No inventas datos. Si no tienes la información, lo dices claramente.
No accedes ni mencionas datos de otros empleados.
Idioma: español. Tono: amable y profesional.
```

```yaml
# router/agent/asistente_empleado/resources/data_queries.yml

vacaciones_disponibles: |
  SELECT leave_balance, leave_type
  FROM hs_hr_leave_entitlement
  WHERE emp_number = (SELECT emp_number FROM hs_hr_employee
                      WHERE emp_work_email = :user_email)

datos_personales: |
  SELECT emp_firstname, emp_lastname, department_id,
         job_title_id, joined_date, emp_status
  FROM hs_hr_employee
  WHERE emp_work_email = :user_email
```

```
-- router/flow/reporte_ventas_mensual/resources/prompt.txt
Analiza estos datos de ventas del mes {mes_anterior} y proporciona:
1. Los 3 clientes con mayor volumen de compra
2. Tendencia respecto al mes anterior si hay datos disponibles
3. Una observación estratégica ejecutiva breve

Datos: {ventas_data}

Responde en español, tono ejecutivo, máximo 150 palabras.
No incluyas tablas — solo texto narrativo.
```

---

## 13. El Motor Binario SBOS AI Tools

### Estructura de una Ruta

```
/etc/bos/blibs/bcompass/router/<nombre_ruta>/
├── manifest.yml          ← identidad, tipo (analyst/agent/flow/report)
├── route_engine.yml      ← flujo declarativo
├── route_catalog.so      ← lógica compilada (C ABI)
└── resources/
    └── prompts/          ← prompts versionados (Langfuse)
```

Agregar capacidad de inteligencia = crear carpeta en `/etc/bos/blibs/bcompass/router/`.
El motor bcompass no cambia.

### Estructura del motor

```
SBOS AI Tools (binario)
├── Event Listener      — schedule, message, manual, event
│   ├── Scheduler       — cron jobs nativos (POSIX cron expression)
│   ├── Message Broker  — suscripción Redis Pub/Sub para mensajes entrantes
│   │   └── Canal Redis: bcompass:messages (publicado por bots/adapters del commsserver)
│   ├── Manual Trigger  — SIGUSR2 desde Core UI con payload JSON
│   └── Event Trigger   — suscripción Redis Stream bkernel:events para eventos del stack
├── Route Resolver      — selecciona ruta en /etc/bos/blibs/bcompass/router/
├── Route Loader        — carga manifest.yml, route_engine.yml, route_catalog.so (dlopen)
├── Engine Executor     — ejecuta fases de route_engine.yml en orden
│   ├── Task Dispatcher — distingue tarea GLOBAL (motor) vs ESPECÍFICA (route_catalog.so)
│   ├── Context Manager — pipeline de outputs entre tareas
│   ├── Approval Gate   — pausa la Saga y espera decisión humana (timeout configurable)
│   └── Error Handler   — on_failure por tarea: abort | continue | retry(n) | notify
├── Ollama Client       — HTTP a Ollama local (localhost:11434)
├── RAG Engine          — indexación y búsqueda semántica en documentos Nextcloud
├── Result Emitter      — sugerencias en bcompass_db, notificaciones, respuestas
│   └── SBOS VDI Notifier  — emite eventos a SBOS VDI para notificaciones en escritorio soberano
└── Hot-Reload (SIGUSR1)— recarga rutas nuevas o actualizadas sin reiniciar
```

### El mecanismo del Event Listener `type: message`

SBOS AI Tools §1 establece que el daemon "no expone APIs REST al exterior". Esto es correcto — SBOS AI Tools nunca recibe conexiones entrantes directas. El mecanismo de mensajes funciona vía **Redis Pub/Sub** en el canal `bcompass:messages`:

```
Usuario → [Nextcloud Talk / Rocket.Chat / Mattermost / email]
               ↓
          Bot Adapter (proceso ligero en commsserver)
               ↓ PUBLISH bcompass:messages {route_id, user_sub, realm, message}
          Redis (dataserver)
               ↓ SUBSCRIBE
          SBOS AI Tools Event Listener
               ↓
          Route Resolver → selecciona ruta agent
               ↓
          Engine Executor → retrieve → respond → send_response
               ↓ respuesta de vuelta al bot via Redis o API del commsserver
          Usuario recibe respuesta
```

El **Bot Adapter** es un proceso ligero (Python, ~100 líneas) que vive en el commsserver y actúa como puente entre la interfaz de mensajería y el canal Redis de SBOS AI Tools. Hay un adapter por interfaz soportada:

| Interfaz | Adapter | Trigger |
|---|---|---|
| Nextcloud Talk | `bcompass-nextcloud-bot` | Mención del bot en canal o mensaje directo |
| Rocket.Chat | `bcompass-rocketchat-bot` | Webhook outgoing + suscripción Redis |
| Mattermost | `bcompass-mattermost-bot` | Slash command `/bcompass` o mención |
| Core UI | `bcompass-coreui-ws` | WebSocket via Centrifugo — sin bot externo |
| Email | `bcompass-email-responder` | Roundcube/Postfix pipe a script que publica en Redis |

El `manifest.yml` de una ruta `agent` declara la interfaz. El motor no sabe qué adapter publicó el mensaje — solo consume el JSON normalizado del canal Redis:

```json
{
  "route_id": "agent_asistente_empleado",
  "user_sub": "maria.garcia@empresa.com",
  "realm": "empresa_abc",
  "interface": "nextcloud_talk",
  "message": "¿Cuántos días de vacaciones me quedan?",
  "conversation_id": "uuid-opcional-para-multi-turn"
}
```

### Catálogo global del motor — tareas universales

```
Tareas de datos:
  db_query              — consulta SQL en cualquier BD del stack (solo lectura)
  rag_fetch_documents   — recupera documentos relevantes de Nextcloud (RAG sobre archivos)
  qdrant_search         — búsqueda semántica vectorial en Qdrant por colección/realm
                          (disponible cuando aiserver tiene Qdrant instalado; degraded mode
                          si Qdrant no está disponible — ruta continúa sin contexto vectorial)

Tareas de IA:
  llm_prompt            — genera texto con Ollama local (modelo configurable por ruta)

Tareas de gestión de sugerencias:
  store_suggestions     — guarda sugerencias en bcompass_db con status=pending
  notify_if_new         — notifica si hay sugerencias nuevas

Tareas de orquestación:
  request_human_approval — pausa la Saga y registra Approval Gate en bcompass_db
                           Notifica a roles habilitados en Core UI y opcionalmente via SBOS VDI
                           Timeout configurable; expirado → abort por defecto

Tareas de distribución:
  notify_with_attachment — notifica con archivo adjunto en canal (Rocket.Chat, Mattermost)
  send_email            — envía email con o sin adjunto vía commsserver
  save_to_nextcloud     — guarda documento en Nextcloud
  send_response         — responde a usuario en la interfaz configurada (via Redis o adapter)
  emit_vdi_notification — emite evento al canal Redis sbos:vdi:notifications para SBOS VDI

Tareas de persistencia:
  log_conversation      — registra conversación de agente en bcompass_db
  check_source_connection — verifica conexión a BD origen
```

### Comportamiento `on_failure` por tarea

| Valor | Comportamiento |
|---|---|
| `abort` | Detiene la ruta. Registra error en `route_executions.status = failed`. Notifica si `notify_on: [failure]` en manifest. |
| `continue` | Ignora el error de esa tarea. El pipeline continúa con el output anterior o `null`. |
| `retry(n)` | Reintenta N veces con backoff exponencial (1s, 2s, 4s). Si agota reintentos, se comporta como `abort`. |
| `notify_and_abort` | Como `abort` pero garantiza notificación al canal admin aunque `notify_on` no lo incluya. |

```yaml
# Ejemplo de on_failure en route_engine.yml
phases:

  retrieve_context:
    tasks:
      - task: "qdrant_search"
        on_failure: continue          # Si Qdrant no está disponible, continúa sin RAG vectorial
        params:
          collection: "realm_{realm_id}_policies"
          query: "{event.user_message}"
          top_k: 5
        output: vector_context

      - task: "rag_fetch_documents"
        on_failure: continue          # Si Nextcloud no responde, continúa sin docs
        params:
          path: "/empresa/politicas/"
          query: "{event.user_message}"
          top_k: 3
        output: doc_context

  respond:
    tasks:
      - task: "llm_prompt"
        on_failure: notify_and_abort  # Si Ollama falla, no responde con basura — aborta
        params:
          model: "qwen3:8b-q4"
          system_prompt_file: "resources/system_prompt.txt"
          context:
            vector_docs: "{retrieve_context.vector_context}"
            nextcloud_docs: "{retrieve_context.doc_context}"
          user_message: "{event.user_message}"
        output: agent_response

      - task: "send_response"
        on_failure: retry(3)          # Reintenta si el adapter de mensajería falla transitoriamente
        params:
          interface: "{event.interface}"
          user: "{event.user_sub}"
          message: "{agent_response}"
```

---

## 13b. Stack Tecnológico del Daemon bcompass

### Justificación técnica de Go para orquestación LLM

El SBOS AI Tools es un orquestador de agentes LLM. Su workload es fundamentalmente I/O-bound: múltiples llamadas HTTP a Ollama (inferencia LLM), consultas de solo lectura a PostgreSQL, y lecturas de Redis. El cuello de botella no es CPU sino la latencia de respuesta de los modelos (100ms – 30s por llamada).

**Por qué Go es ideal para orquestación de LLMs:**
- **Goroutines como agentes:** cada ruta `analyst/agent/flow/monitor` corre en su goroutine con costo de 2–4 KB. Una ruta que llama a 5 modelos LLM en paralelo crea 5 goroutines, no 5 OS threads.
- **Assembled.com (plataforma LLM en producción):** documenta que Go permite paralelizar búsquedas en múltiples backends LLM con canales, reduciendo la latencia total a la del backend más lento con timeouts configurables.
- **ByteDance/Eino:** framework de orquestación LLM en Go usado en producción para pipelines multi-agente con streaming automático y checkpoints para human-in-the-loop.

**Go vs Python para orquestación LLM:** Python (LangChain, LlamaIndex) domina el ecosistema de prototipado LLM. Sin embargo, para un daemon de producción embebido en un sistema soberano, Go tiene ventajas operativas críticas: binario estático sin virtualenv, arranque en < 50ms vs 1–3s de Python, y manejo de concurrencia sin el GIL. bcompass no necesita entrenar modelos ni manipular tensores — solo orquestar llamadas HTTP: exactamente el punto fuerte de Go.

**Por qué no Rust para bcompass:** el workload de bcompass es I/O-bound puro (espera de respuestas HTTP de Ollama). La ausencia de GC que hace a Rust indispensable en bkernel no aporta ventaja aquí — Go maneja esta concurrencia I/O de forma más idiomática con goroutines y channels, y con menor tiempo de desarrollo.

### Stack de dependencias

| Componente | Herramienta / Módulo | Propósito |
|---|---|---|
| **Lenguaje** | Go 1.22+ | Daemon principal |
| **HTTP client LLM** | net/http stdlib + retries | Llamadas a Ollama (OpenAI compat API) |
| **HTTP client Streaming** | github.com/sashabaranov/go-openai | Streaming de respuestas LLM |
| **PostgreSQL client** | github.com/jackc/pgx/v5 | Queries readonly a BDs del stack |
| **Redis client** | github.com/redis/go-redis/v9 | Pub/Sub y streams para triggers |
| **YAML routes** | gopkg.in/yaml.v3 | Parsing de route_engine.yml |
| **Hot-reload .so** | plugin stdlib (Go plugins) | Carga de route_catalog.so |
| **Config** | github.com/BurntSushi/toml | Lectura de bcompass.toml |
| **Logging** | github.com/rs/zerolog | Logging estructurado JSON |
| **Métricas** | github.com/prometheus/client_golang | Exportación de métricas |
| **Context/timeout** | context stdlib | Cancelación de rutas LLM largas |
| **Signal handling** | os/signal + SIGUSR1/SIGUSR2 | Hot-reload y triggers manuales |
| **Testing** | go test + testify + httptest | Mocks de Ollama y PostgreSQL |
| **Linting** | golangci-lint | Calidad de código en CI |
| **Build** | `go build -ldflags='-s -w'` | Binario estático sin símbolos de debug |

---


## 14. La Route API — Contrato entre el Motor y la Ruta

Ver §11. El C ABI garantiza que las rutas compiladas como plugins `.so` sean compatibles con el motor Rust de bcompass sin importar cuándo se compilaron — el mismo principio de estabilidad binaria del SBOS Data Kernel y de SBOS Data Integration. Un solo contrato estable para todo el ecosistema SKULL.

---

## 15. Ollama — El LLM Local Soberano

Ollama es el único componente externo de SBOS AI Tools. Es el runtime de LLMs que corre 100% localmente.

```
DATOS DEL CLIENTE → Ollama (en el servidor del cliente) → RESPUESTA
                         ↑
                Los datos NUNCA salen del servidor
                Sin OpenAI, sin Anthropic, sin Google
                Sin costos de API de LLM externos
                Funciona offline
```

### Por qué Qwen3 es el modelo principal del stack SBOS

El stack SBOS opera primariamente en mercados iberoamericanos (Bolivia, Perú, México, Argentina, España, Brasil). La selección de modelos responde a tres criterios obligatorios: (1) rendimiento real documentado en español y portugués, (2) licencia libre (MIT o Apache 2.0), y (3) eficiencia en CPU sin GPU para los Perfiles A y B del hardware del cliente.

**Qwen3 supera a Llama 3.2 en español en benchmarks comparativos 2025-2026:**

| Benchmark | Qwen3-8B | Llama 3.2-8B | Ventaja Qwen3 |
|---|---|---|---|
| MGSM (matemáticas multilingüe) | 87.4% | 72.1% | +21.2% |
| XQuAD-es (comprensión lectora español) | 91.2% | 81.3% | +12.2% |
| FLORES-200 (traducción es↔en) | 38.4 BLEU | 31.7 BLEU | +21.1% |
| C-Eval (razonamiento — adaptado español) | 84.6% | 71.2% | +18.8% |
| Instrucción en español (humano eval) | 4.31/5 | 3.67/5 | +17.4% |

*Llama 3.2 fue entrenado con énfasis en inglés. Su corpus multilingüe es significativamente menor que el de Qwen3, que incluye entrenamiento extenso en español, portugués, y lenguas latinoamericanas. Esta diferencia es estructural — no se corrige con fine-tuning ligero.*

La familia Qwen3 tiene licencia **Apache 2.0**, lo que cumple el Principio 3 del stack. DeepSeek-R1 (distilaciones sobre arquitectura Qwen) tiene licencia **MIT**. Llama 3.3 tiene su propia licencia Llama 3.3 (restrictiva en redistribución) y solo se recomienda para el Perfil C con GPU.

### Modelos aprobados y recomendados para SBOS

| Modelo | RAM Q4 | Uso en SBOS AI Tools | Perfil mínimo | Licencia |
|---|---|---|---|---|
| `qwen3:4b-q4` | ~3 GB | Agentes de empleados — respuestas rápidas, consultas simples | A | Apache 2.0 |
| `qwen3:8b-q4` | ~6 GB | Agentes admin, análisis en flows, reportes — equilibrio calidad/velocidad | A | Apache 2.0 |
| `deepseek-r1:32b-distill-qwen-q4` | ~20 GB | Rutas analyst — razonamiento explícito paso a paso para sugerencias de alta confianza | B | MIT |
| `qwen3:32b-q4` | ~20 GB | Agentes complejos, análisis de contratos, consultas tributarias Bolivia | B | Apache 2.0 |
| `qwen3:30b-a3b-q4` | ~8 GB activos | Perfil B con eficiencia MoE — activa solo 3B parámetros de 30B totales | B | Apache 2.0 |
| `llama3.3:70b-q4` | ~35 GB VRAM | Solo con GPU — máxima calidad multilingüe en producción concurrente | C | Llama 3.3 |

> **Nota:** `deepseek-r1:32b-distill-qwen` es una destilación de DeepSeek-R1 sobre arquitectura Qwen, disponible en Ollama con licencia MIT. Su característica de razonamiento Chain-of-Thought explícito lo hace ideal para rutas `analyst` donde la trazabilidad de la sugerencia es crítica.

### Asignación por tipo de ruta

| Tipo de ruta | Modelo por defecto | Justificación |
|---|---|---|
| `agent` empleados | `qwen3:4b-q4` | Respuestas cortas, latencia < 3s, mínimo RAM |
| `agent` admin | `qwen3:8b-q4` | Análisis del stack, respuestas complejas |
| `analyst` | `deepseek-r1:32b-distill-qwen-q4` | Razonamiento explícito paso a paso — sugerencias auditables |
| `flow` reportes | `qwen3:8b-q4` | Generación de texto ejecutivo fluido |
| `report` | `qwen3:4b-q4` | Resúmenes periódicos, baja complejidad |

La ficha SBOS AI Tools en el SBOS IAM Installer detecta la RAM disponible durante la instalación y configura automáticamente el modelo apropiado según el perfil de hardware del aiserver.

---

## 16. La Base de Datos Propia: bcompass_db

SBOS AI Tools solo escribe en su propia base de datos. Nunca escribe en las BDs del stack.

```sql
-- Sugerencias del Analyst
CREATE TABLE compass_suggestions (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id          TEXT NOT NULL,
  suggestion_type   TEXT NOT NULL,
  title             TEXT NOT NULL,
  description       TEXT NOT NULL,
  evidence          JSONB NOT NULL,
  proposed_action   TEXT,
  confidence        NUMERIC(4,2),
  status            TEXT DEFAULT 'pending', -- 'pending'|'approved'|'rejected'|'applied'
  created_at        TIMESTAMPTZ DEFAULT now(),
  reviewed_by       TEXT,
  reviewed_at       TIMESTAMPTZ,
  review_notes      TEXT
);

-- Approval Gates de rutas flow
CREATE TABLE approval_gates (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id          UUID REFERENCES route_executions(run_id),
  route_id        TEXT NOT NULL,
  gate_title      TEXT NOT NULL,
  gate_data       JSONB NOT NULL,
  status          TEXT DEFAULT 'pending',  -- 'pending'|'approved'|'rejected'|'expired'
  notify_roles    TEXT[],
  timeout_hours   INTEGER DEFAULT 24,
  created_at      TIMESTAMPTZ DEFAULT now(),
  decided_by      TEXT,
  decided_at      TIMESTAMPTZ,
  selected_action TEXT
);

-- Ejecuciones de rutas
CREATE TABLE route_executions (
  run_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id      TEXT NOT NULL,
  route_type    TEXT NOT NULL,   -- 'analyst'|'agent'|'flow'|'report'
  started_at    TIMESTAMPTZ NOT NULL,
  finished_at   TIMESTAMPTZ,
  status        TEXT NOT NULL,   -- 'running'|'success'|'failed'|'waiting_approval'
  triggered_by  TEXT,
  operator_sub  TEXT
);

CREATE TABLE route_step_log (
  id        SERIAL PRIMARY KEY,
  run_id    UUID REFERENCES route_executions(run_id),
  phase     TEXT NOT NULL,
  task      TEXT NOT NULL,
  status    TEXT NOT NULL,
  result    JSONB,
  error     TEXT,
  duration_ms INTEGER
);

-- Conversaciones de agentes
CREATE TABLE agent_conversations (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id      TEXT NOT NULL,
  user_sub      TEXT NOT NULL,
  user_message  TEXT NOT NULL,
  agent_reply   TEXT NOT NULL,
  context_used  JSONB,
  model_used    TEXT,
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- Documentos generados por flows y reports
CREATE TABLE generated_documents (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id        UUID REFERENCES route_executions(run_id),
  document_name TEXT,
  document_path TEXT,
  distributed_to JSONB,
  generated_at  TIMESTAMPTZ DEFAULT now()
);

-- Notificaciones emitidas al SBOS VDI
CREATE TABLE vdi_notifications_log (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id        UUID REFERENCES route_executions(run_id),
  event_type    TEXT NOT NULL,
  target_roles  TEXT[],
  payload       JSONB NOT NULL,
  emitted_at    TIMESTAMPTZ DEFAULT now(),
  acknowledged  BOOLEAN DEFAULT false
);
```

---

## 17. Ciclo de Vida como Servicio systemd

```ini
# /etc/systemd/system/bcompass.service
[Unit]
Description=SBOS AI Tools — Sovereign Business Intelligence Engine (SBOS)
After=network.target postgresql.service ollama.service
Wants=ollama.service

[Service]
Type=notify
ExecStart=/usr/local/bin/bcompass --config /etc/bos/blibs/bcompass/bcompass.toml
ExecReload=/bin/kill -USR1 $MAINPID
Restart=always
RestartSec=5
User=bcompass-readonly      # PostgreSQL SELECT únicamente en BDs del stack
WatchdogSec=120
NotifyAccess=main

[Install]
WantedBy=multi-user.target
```

```
$ systemctl status bcompass
● bcompass.service - SBOS AI Tools Sovereign Business Intelligence Engine (SBOS)
   Active: active (running) since 2026-03-07 08:00:00

$ journalctl -u bcompass -f
Mar 10 02:00:00 bcompass: INFO  route.start   route=analyst_reglas_inactivas trigger=schedule
Mar 10 02:00:03 bcompass: INFO  phase.done    phase=observe records=847_rules duration_ms=1230
Mar 10 02:00:04 bcompass: INFO  phase.done    phase=analyze suggestions=3 confidence_min=0.87
Mar 10 02:00:04 bcompass: INFO  route.done    route=analyst_reglas_inactivas suggestions=3 status=pending
Mar 10 02:00:04 bcompass: INFO  vdi.notify    event=new_suggestions target_roles=[CONFIG_SYSTEM] channel=sbos:vdi:notifications
Mar 10 10:23:15 bcompass: INFO  route.start   route=agent_asistente_empleado trigger=message user=maria.garcia
Mar 10 10:23:17 bcompass: INFO  phase.done    phase=respond model=qwen3:4b-q4 duration_ms=1823
Mar 10 10:23:17 bcompass: INFO  route.done    route=agent_asistente_empleado status=success
```

---

## 18. La Ficha SBOS AI Tools en el SBOS IAM Installer

```
servers/
└── aiserver/
    └── bcompass/
        ├── manifest.yml
        ├── yaml_engine.yml
        ├── task_catalog.sh
        └── resources/
            ├── bcompass.service         ← systemd unit file
            ├── sql/
            │   └── schema.sql           ← bcompass_db schema
            ├── config/
            │   └── bcompass.toml        ← configuración base
            └── router/                  ← rutas base distribuidas con el stack
                ├── analyst/
                │   ├── reglas_inactivas/
                │   ├── correlaciones_sin_regla/
                │   └── errores_recurrentes_biedata/
                ├── agent/
                │   ├── asistente_empleado/
                │   └── asistente_admin/
                ├── flow/
                │   └── reporte_ventas_mensual/
                └── report/
                    ├── estado_semanal_bkernel/
                    └── integraciones_mensual_biedata/
```

---

## 19. Protocolo de Notificación SBOS AI Tools → SBOS VDI

SBOS AI Tools puede emitir notificaciones directamente al escritorio soberano SBOS VDI (SBOS-012) para que los administradores y operadores reciban alertas, aprobaciones pendientes, y estado de rutas sin salir de su entorno de trabajo.

### Arquitectura del protocolo

La comunicación es **unidireccional desde SBOS AI Tools hacia SBOS VDI**, mediada por Redis. SBOS AI Tools nunca expone APIs ni se conecta directamente al escritorio. El SBOS VDI escucha activamente el canal Redis.

```
SBOS AI Tools Result Emitter
       ↓ PUBLISH sbos:vdi:notifications
Redis (dataserver)
       ↓ SUBSCRIBE (bcompass-vdi-bridge, proceso en commsserver o SBOS VDI)
SBOS VDI Notification Daemon (KDE Plasma — proceso local en escritorio)
       ↓
KDE Plasma System Tray / KNotification
       ↓
Administrador ve notificación en su escritorio
```

### Evento emitido por SBOS AI Tools

Cuando SBOS AI Tools ejecuta la tarea global `emit_vdi_notification`, publica en el canal Redis `sbos:vdi:notifications` el siguiente payload JSON:

```json
{
  "event_id": "uuid-v4",
  "event_type": "new_suggestions",
  "severity": "info",
  "source": {
    "daemon": "bcompass",
    "route_id": "analyst_reglas_inactivas",
    "run_id": "uuid-ejecución"
  },
  "target": {
    "roles": ["CONFIG_SYSTEM"],
    "realm": "empresa_abc"
  },
  "payload": {
    "title": "SBOS AI Tools: 3 sugerencias nuevas",
    "body": "Se detectaron 3 reglas SBOS Data Kernel inactivas. Revisar en Core UI.",
    "action_url": "sbos://compass/suggestions/pending",
    "count": 3,
    "category": "bkernel_optimization"
  },
  "emitted_at": "2026-03-10T02:00:04Z"
}
```

**Tipos de evento y su severidad:**

| `event_type` | Severidad | Cuándo se emite |
|---|---|---|
| `new_suggestions` | `info` | ruta analyst produce sugerencias con status=pending |
| `approval_required` | `warning` | ruta flow llega a un Approval Gate |
| `route_failed` | `error` | ruta falla con `notify_and_abort` |
| `agent_error` | `warning` | agente no puede responder (Ollama falló) |
| `flow_completed` | `info` | ruta flow completa exitosamente (configurable — off por defecto) |

### Cómo llega la notificación al escritorio SBOS VDI

El **bcompass-vdi-bridge** es un proceso ligero (Python, ~80 líneas) que corre en el commsserver o directamente en el host del SBOS VDI. Se suscribe al canal Redis `sbos:vdi:notifications` y convierte los eventos en notificaciones del escritorio KDE:

```python
# bcompass-vdi-bridge — fragmento ilustrativo
import redis, subprocess, json

r = redis.Redis(host='dataserver', port=6379)
pubsub = r.pubsub()
pubsub.subscribe('sbos:vdi:notifications')

for message in pubsub.listen():
    if message['type'] != 'message':
        continue
    event = json.loads(message['data'])

    # Filtrar por rol del usuario autenticado en esta sesión KDE
    if current_user_role not in event['target']['roles']:
        continue

    # Emitir notificación KDE nativa
    subprocess.run([
        'notify-send',
        '--urgency', urgency_map[event['severity']],
        '--icon', 'bcompass-icon',
        '--app-name', 'SBOS AI Tools',
        event['payload']['title'],
        event['payload']['body']
    ])

    # Si tiene action_url → registrar para click handler (sbos:// deeplink)
    if 'action_url' in event['payload']:
        register_deeplink_action(event['event_id'], event['payload']['action_url'])
```

### Qué puede hacer el administrador desde el escritorio

Cuando la notificación llega al escritorio KDE del administrador:

**1. Ver la notificación en el System Tray**
El ícono del SBOS AI Tools en la bandeja del sistema muestra un badge con el número de notificaciones pendientes. El administrador puede ver el detalle sin abrir el Core UI.

**2. Hacer click → acción directa vía protocolo `sbos://`**
Cada notificación tiene un `action_url` con el protocolo `sbos://` (SBOS-012 §23). El administrador hace click y el Core UI se abre directamente en la vista relevante:

| Tipo de notificación | action_url | Resultado |
|---|---|---|
| `new_suggestions` | `sbos://compass/suggestions/pending` | Core UI abre vista de sugerencias pendientes |
| `approval_required` | `sbos://compass/approvals/{gate_id}` | Core UI abre el Approval Gate específico |
| `route_failed` | `sbos://compass/runs/{run_id}/log` | Core UI abre el log de la ejecución fallida |

**3. Aprobar o rechazar desde Core UI**
Una vez en Core UI, el administrador puede:
- Ver la evidencia completa de la sugerencia o Approval Gate
- Aprobar la acción recomendada (ejecuta la Saga o aplica la sugerencia)
- Rechazar con notas (retroalimenta la ruta via `review_notes` en `compass_suggestions`)
- Delegar la decisión a otro rol habilitado

**4. Silenciar notificaciones por tipo**
El administrador puede configurar en Core UI qué tipos de eventos generan notificaciones en el escritorio, sin afectar el registro en `bcompass_db`.

### Ciclo completo de notificación

```
02:00 AM — analyst_reglas_inactivas ejecuta automáticamente
  → 3 sugerencias generadas con status=pending
  → SBOS AI Tools emite evento new_suggestions al canal Redis sbos:vdi:notifications
  → bcompass-vdi-bridge recibe el evento
  → KDE Plasma muestra: "SBOS AI Tools: 3 sugerencias nuevas"
                         "Reglas SBOS Data Kernel inactivas detectadas. Revisar."

08:15 AM — Administrador llega a su escritorio SBOS VDI
  → Ve notificación en bandeja del sistema
  → Hace click → sbos://compass/suggestions/pending
  → Core UI abre vista de sugerencias
  → Revisa evidencia de las 3 reglas inactivas
  → Aprueba 2, rechaza 1 (con nota: "esta regla se activa en temporada alta")
  → Las 2 aprobadas → sistema crea YAML de desactivación → SIGHUP al SBOS Data Kernel
  → La rechazada → status=rejected, review_notes registrado para retroalimentación
```

---

## 20. Catálogo de Rutas Base

### Rutas Analyst

| Ruta | Observa | Produce |
|---|---|---|
| `analyst_reglas_inactivas` | bkernel_db.rule_execution_log | Sugerencia: desactivar reglas sin uso |
| `analyst_correlaciones_sin_regla` | bkernel_db.sync_log | Sugerencia: crear regla para correlación detectada |
| `analyst_errores_recurrentes_biedata` | biedata_db.box_row_errors | Sugerencia: revisar mapping de la caja con errores |
| `analyst_conflictos_recurrentes` | bkernel_db.conflict_log | Sugerencia: revisar política de resolución |

### Rutas Agent

| Ruta | Audiencia | Interfaces | Modelo |
|---|---|---|---|
| `agent_asistente_empleado` | Todos los empleados | Nextcloud Talk, Rocket.Chat, Mattermost | `qwen3:4b-q4` |
| `agent_asistente_admin` | Rol CONFIG_SYSTEM | Core UI (WebSocket via Centrifugo) | `qwen3:8b-q4` |
| `agent_soporte_cliente` | Público | Email responder (Roundcube pipe) | `qwen3:4b-q4` |

### Rutas Flow

| Ruta | Trigger | Produce |
|---|---|---|
| `flow_reporte_ventas_mensual` | 1° de mes 09:00 | Excel + análisis LLM → email + Nextcloud |
| `flow_alerta_anomalia_contable` | Evento SBOS Data Kernel | Notificación urgente a gerencia + Approval Gate |
| `flow_resumen_semanal_stack` | Lunes 08:00 | Resumen estado del stack → canal admin |

### Rutas Report

| Ruta | Trigger | Produce |
|---|---|---|
| `report_estado_semanal_bkernel` | Lunes 07:00 | Reporte texto → #admin-ops |
| `report_integraciones_mensual` | 1° de mes 07:30 | Excel SBOS Data Integration → #bcompass-ops |
| `report_actividad_agentes` | Lunes 07:30 | Resumen conversaciones → #admin-ops |

---

## 21. Flujos Completos

### Flujo A: Analyst detecta correlación sin regla

```
Lunes 2:00 AM — ruta analyst_correlaciones_sin_regla ejecuta automáticamente

1. observe: query en bkernel_db
   → detecta que en el 89% de los casos donde Tryton modifica product_template,
     EspoCRM recibe una actualización manual dentro de 2 horas (312 eventos / 90 días)

2. analyze: score_suggestions
   → confianza: 0.89 (supera umbral 0.80)
   → genera sugerencia con evidencia completa

3. suggest: store_suggestions
   → bcompass_db.compass_suggestions con status='pending'
   → emit_vdi_notification → sbos:vdi:notifications
   → notifica en #bcompass-insights:
     "SBOS AI Tools detectó correlación no documentada: tryton.product → espocrm.
      Ver sugerencia en Core UI."

08:15 AM — Admin ve notificación en escritorio SBOS VDI
  → Click → sbos://compass/suggestions/pending
  → Core UI abre vista de sugerencias
  → Admin ve: [PENDING] Correlación detectada: tryton.product_template → espocrm.products
              Evidencia: 312 eventos / 90 días / confianza 89%
              Acción propuesta: [YAML de nueva regla adjunto]
              [APROBAR] [RECHAZAR]

Admin aprueba → crea el archivo YAML de regla en /etc/bos/blibs/bkernel/rules/ → SIGHUP al SBOS Data Kernel
```

### Flujo B: Agente responde a empleado

```
María García escribe en Nextcloud Talk al bot SBOS AI Tools:
"¿Cuántos días de vacaciones me quedan?"

1. retrieve_context:
   → route_catalog.so consulta OrangeHRM con email de María (solo sus datos)
   → rag_fetch_documents: busca en /empresa/politicas/ documentos relevantes
   → contexto: {vacaciones_disponibles: 8.5 días, politica_vacaciones: ...}

2. respond:
   → llm_prompt con system_prompt + contexto + pregunta de María
   → Ollama (qwen3:4b-q4) genera:
     "Hola María, tienes 8.5 días de vacaciones disponibles.
      Según la política de la empresa, puedes solicitar hasta 15 días consecutivos..."
   → send_response: respuesta en Nextcloud Talk

3. log_conversation: registrado en bcompass_db

Tiempo total: ~2 segundos. LLM corrió 100% en el servidor — sin nube.
```

### Flujo C: Reporte mensual automático con análisis ejecutivo

```
1° de marzo a las 9:00 (automático):

1. read:    consulta ventas de febrero en Tryton (solo lectura)
2. analyze: llm_prompt → Ollama (qwen3:8b-q4) genera análisis ejecutivo de 150 palabras
3. generate: Excel con datos + análisis → reporte_ventas_febrero_2026.xlsx
4. distribute:
   → notifica en #gerencia-ventas con análisis adjunto
   → email a gerencia_emails con Excel
   → guarda en Nextcloud /empresa/reportes/ventas/

Gerencia recibe el reporte antes de llegar a la oficina.
Nadie lo generó manualmente.
```

### Flujo D: Flow con Approval Gate (Saga de inteligencia)

```
Trigger: SBOS Data Kernel detecta anomalía contable → emite evento en bkernel:events

flow_alerta_anomalia_contable ejecuta:

1. analyze: consulta bkernel_db, calcula magnitud de la anomalía
   → anomalía: diferencia no reconciliada > 15.000 BOB en cuenta 5110

2. approval_gate: request_human_approval
   → status: pending en bcompass_db.approval_gates
   → emit_vdi_notification → sbos:vdi:notifications (severity: warning)
   → Admin ve en escritorio: "Anomalía contable requiere revisión urgente"
   → Click → sbos://compass/approvals/{gate_id}
   → Core UI muestra:
     Anomalía: cuenta 5110 / diferencia: 15.230 BOB / origen: Tryton
     Acciones disponibles:
       [A] Notificar a auditoría y suspender conciliación automática
       [B] Marcar como revisado manualmente (ya conocido)
       [C] Escalar a gerencia financiera

3. Admin selecciona [A] (dentro del timeout de 24h)
   → approval_decision.approved = true, selected_action = "A"

4. execute: (condición aprobada)
   → flow_execute_corrective_action
   → notifica a auditoría con reporte completo
   → suspende conciliación automática de esa cuenta
   → registra en bcompass_db

Si el Admin no responde en 24h → timeout → abort → notificación escalada automáticamente
```

---

## 22. Fronteras que SBOS AI Tools Nunca Cruza

**D1 — Nunca escribe en BDs del stack.**
Credenciales PostgreSQL `SELECT` únicamente en todas las BDs del stack. Solo escribe en `bcompass_db`.

**D2 — Las rutas analyst nunca ejecutan sus propias sugerencias.**
Las sugerencias tienen status `pending` hasta que el administrador las aprueba en Core UI. SBOS AI Tools nunca toca archivos de reglas del SBOS Data Kernel directamente.

**D3 — Los agentes nunca acceden a datos de otros usuarios.**
El contexto RAG de un agente está filtrado por `user_sub`. Un empleado nunca puede ver datos de otro empleado a través del agente.

**D4 — Ollama nunca envía datos al exterior.**
Los modelos corren localmente. Los prompts, el contexto del stack, y las conversaciones nunca salen del servidor.

**D5 — Nunca carga un .so sin firma criptográfica.**
El SBOS IAM Installer firma cada `route_catalog.so`. SBOS AI Tools verifica la firma antes de `dlopen()`.

**D6 — Nunca actúa sobre sugerencias con confianza inferior al 80%.**
Las rutas analyst filtran sugerencias por `min_confidence: 0.80` declarado en `route_engine.yml`. Sugerencias de baja confianza se descartan silenciosamente o se registran como informativas sin acción propuesta.

**D7 — Las notificaciones al SBOS VDI son eventos de información, no comandos.**
SBOS AI Tools publica eventos — nunca ejecuta acciones en el escritorio del administrador. El protocolo `sbos://` es interpretado por el escritorio, no por SBOS AI Tools.

---

## 23. Hoja de Ruta de Desarrollo

**Fase 1 — Core del Motor + Analyst (Meses 7-9)**
Requiere que bkernel_db tenga mínimo 3 meses de datos operacionales para análisis estadístico significativo. Motor binario SBOS AI Tools. Route Loader con dlopen. Engine Executor. Rutas analyst: reglas_inactivas, correlaciones_sin_regla, errores_recurrentes_biedata. Schema bcompass_db. Servicio systemd. UI de revisión de sugerencias en Core UI.

**Fase 2 — Flow y Report (Meses 10-11)**
Integración con Ollama (llm_prompt global). Rutas flow: reporte_ventas_mensual, resumen_semanal_stack. Rutas report: estado_semanal_bkernel, integraciones_mensual_biedata. Tareas globales: send_email, save_to_nextcloud, notify_with_attachment. Approval Gates (Sagas de inteligencia). Protocolo de notificación SBOS AI Tools → SBOS VDI.

**Fase 3 — Agent (Meses 12-14)**
RAG Engine sobre documentos Nextcloud. Rutas agent: asistente_empleado, asistente_admin, soporte_cliente. Integración con Nextcloud Talk bot. Instalación y configuración de Ollama como parte de la ficha. Filtrado de acceso por user_sub.

**Fase 4 — Madurez (Meses 15-16)**
Dashboard Grafana: sugerencias aprobadas/rechazadas, conversaciones por agente, flows ejecutados. Modelos Qwen3 recomendados según hardware del cliente. Rutas analyst avanzadas: análisis de rendimiento del SBOS Data Kernel, detección de drift de configuración. Integración Qdrant para búsqueda semántica vectorial en rutas agent.

---

## 24. Referencias Cruzadas

| Documento | Relación |
|---|---|
| SBOS-002 — Arquitectura General | Capa 4 de la arquitectura global |
| SBOS-003 — Catálogo Stack Tecnológico | Ollama, Redis, PostgreSQL, Qdrant |
| SBOS-005 — SBOS IAM Installer | Ficha de instalación de SBOS AI Tools |
| SBOS-010 — SBOS Data Kernel | Fuente de datos `bkernel_db` — solo lectura |
| SBOS-011 — SBOS Data Integration | Fuente de datos `biedata_db` — solo lectura |
| SBOS-012 — SBOS VDI | Receptor de notificaciones; protocolo `sbos://compass/` |
| SBOS-015 — aiserver | Servidor que ejecuta Ollama y Qdrant |
| SBOS-016 — Mapa de Servidores | SBOS AI Tools corre en aiserver (S15) |

---

*SKULL · SBOS · SBOS-014-BCOMPASS · v5.0 · Marzo 2026*
*Reemplaza: SBOS-011-BCOMPASS v3.0 — SUPERSEDED*
-e 
---

## Contrato LLM, Aprendizaje Federado y Agentes por Manifiesto

> **Integrado desde SBOS-014-001 en v5.0.**


```
Usuario solicita análisis (via Core UI o API)
  │
  ▼
Route Engine lee route_engine.yml de la ruta solicitada
  │
  ▼
FASE 1: CONTEXT ASSEMBLY
  ├── Consulta bkernel vía Redis: datos relevantes del negocio
  ├── Consulta bsearch: documentos relacionados (RAG)
  ├── Consulta Qdrant: embeddings similares (memoria semántica)
  └── Arma el contexto con max_tokens respetado

FASE 2: PROMPT CONSTRUCTION
  ├── Lee prompt template de Langfuse (versionado)
  ├── Inyecta variables: {context}, {user_query}, {constraints}
  ├── Aplica system prompt del manifiesto de la ruta
  └── Genera el prompt final (logged en Langfuse con trace_id)

FASE 3: LLM INFERENCE
  ├── Envía al modelo via Ollama API (localhost:11434)
  ├── Modelo: según route_engine.yml (default: qwen3:8b)
  ├── Temperature, max_tokens, top_p del manifiesto
  ├── Timeout: 120 segundos (configurable)
  └── SI FALLA → fallback (ver §4)

FASE 4: RESPONSE VALIDATION
  ├── Parsear respuesta del modelo
  ├── Validar contra schema esperado (si la ruta define uno)
  ├── Verificar: ¿la respuesta referencia datos reales? (anti-alucinación)
  │   └── Cross-check con datos del contexto
  ├── SI VÁLIDA → formatear y entregar
  └── SI INVÁLIDA → retry con prompt refinado (max 2 retries)

FASE 5: AUDIT & LEARN
  ├── Log en Langfuse: prompt, response, latency, tokens, trace_id
  ├── Si el usuario da feedback → almacenar para fine-tuning futuro
  └── Métricas: bcompass_inference_duration_seconds, bcompass_inference_total
```

### 1.2 Formato del route_engine.yml

```yaml
route:
  id: "INVENTORY-ALERT-001"
  name: "Alerta de Stock Mínimo"
  type: "analytical"           # analytical | research | conversational | report
  enabled: true

  context:
    sources:
      - type: "bkernel_redis"
        channel: "bkernel:events:tryton"
        filter: "stock.move"
      - type: "bsearch_rag"
        index: "inventory"
        query: "productos con stock bajo"
      - type: "sql"
        database: "tryton_db"
        query: "SELECT name, quantity FROM stock_move WHERE quantity < reorder_point"
    max_context_tokens: 4000

  prompt:
    langfuse_name: "inventory_alert_v3"
    system: "Eres un analista de inventario. Genera propuestas de compra basadas en datos reales. No inventes datos. Si no tienes información suficiente, dilo explícitamente."
    temperature: 0.3
    max_tokens: 2000
    model: "qwen3:8b"

  validation:
    require_data_reference: true    # respuesta debe citar datos del contexto
    output_schema: "json"           # json | text | markdown
    json_schema:
      type: "object"
      properties:
        alerts: { type: "array" }
        purchase_proposals: { type: "array" }
        confidence: { type: "number" }

  human_approval:
    required: true                  # propuestas requieren aprobación humana
    approval_role: "sbos-operator"
    auto_expire_hours: 24

  error_handling:
    max_retries: 2
    fallback_model: "qwen3:1.5b"   # modelo más pequeño si el principal falla
    on_failure: "notify_admin"
```

---

## 2. Aprendizaje Federado (Privacy-Preserving)

### 2.1 Principio

El SBOS NUNCA envía datos crudos del cliente fuera de la infraestructura. El aprendizaje federado permite mejorar modelos compartiendo solo optimizaciones matemáticas (gradientes), no datos.

### 2.2 Flujo

```
CLIENTE A (SBOS instalación)          SKULL Release Plane
  │                                     │
  ├── Fine-tune local con datos         │
  │   del cliente (Ollama)              │
  │                                     │
  ├── Extraer gradientes del            │
  │   fine-tune (diferencias de pesos)  │
  │                                     │
  ├── Anonimizar: eliminar cualquier    │
  │   dato que pueda identificar al     │
  │   cliente (differential privacy)    │
  │                                     │
  ├── Enviar gradientes anónimos ──────►│ Agregar gradientes
  │   (NO datos, NO prompts)            │ de múltiples clientes
  │                                     │
  │                                     ├── Federated averaging
  │                                     │   (promediar gradientes)
  │                                     │
  │◄── Recibir modelo mejorado ────────│ Distribuir modelo
  │   (via Release Plane normal)        │ actualizado
  │                                     │
  └── Desplegar modelo mejorado         │
      en Ollama local                   │
```

### 2.3 Configuración

```yaml
# En bcompass.toml
[federated_learning]
enabled = false                    # desactivado por defecto
opt_in_required = true             # requiere consentimiento explícito del cliente
gradient_upload_schedule = "weekly" # weekly | monthly | manual
differential_privacy_epsilon = 1.0 # nivel de ruido para privacidad
min_local_samples = 1000           # mínimo de muestras antes de contribuir
```

---

## 3. Agentes de Investigación por Manifiestos

### 3.1 Concepto

Un agente es una ruta de tipo "research" que ejecuta múltiples pasos de recolección, estructuración y síntesis de información. Está regulado por un manifiesto que define sus límites.

### 3.2 Formato del manifiesto de agente

```yaml
agent:
  id: "RESEARCH-MARKET-001"
  name: "Investigación de Precios de Mercado"
  type: "research"
  max_steps: 10
  max_duration_minutes: 30
  max_tokens_total: 50000

  boundaries:
    data_sources: ["tryton", "saleor", "bsearch"]
    forbidden_sources: ["keycloak", "vault", "system_config"]
    forbidden_actions: ["write", "delete", "modify"]
    read_only: true

  steps:
    - step: 1
      action: "query"
      source: "tryton"
      query: "SELECT category, AVG(list_price) FROM product_product GROUP BY category"
      store_as: "avg_prices"

    - step: 2
      action: "query"
      source: "saleor"
      query: "SELECT product_name, sale_price FROM order_line WHERE date > :last_month"
      store_as: "recent_sales"

    - step: 3
      action: "analyze"
      model: "qwen3:8b"
      prompt: "Compara los precios promedio de catálogo ({avg_prices}) con los precios reales de venta ({recent_sales}). Identifica productos con margen inferior al 15%."
      store_as: "margin_analysis"

    - step: 4
      action: "report"
      format: "markdown"
      template: "resources/market_report_template.md"
      data: ["avg_prices", "recent_sales", "margin_analysis"]

  output:
    type: "report"
    deliver_to: "core_ui"
    notify: "sbos-operator"
    requires_human_review: true
```

---

## 4. Fallback sin GPU

```
Jerarquía de modelos (bcompass intenta en orden):
  1. Modelo principal: qwen3:8b (requiere ~6GB VRAM)
  2. Modelo reducido: qwen3:1.5b (requiere ~2GB VRAM)
  3. Modelo CPU-only: phi-3-mini (3.8B, funciona en CPU)
  4. Sin modelo: respuesta basada solo en datos estructurados (sin LLM)

Detección automática:
  bcompass al iniciar consulta Ollama: GET /api/tags
  Si modelo principal no disponible → degradar al siguiente
  Log: "Model qwen3:8b not available, falling back to qwen3:1.5b"
  Métrica: bcompass_model_fallback_total{from="qwen3:8b",to="qwen3:1.5b"}
```

---

## 5. Registro de Cambios

### v1.0 — Marzo 2026

Contrato ruta→LLM→respuesta con 5 fases, aprendizaje federado privacy-preserving, agentes de investigación por manifiestos con boundaries, y jerarquía de fallback sin GPU.

---

*SKULL · SBOS · SBOS-014-001 · Anexo 001 · v1.0 · Marzo 2026*
