# SBOS-002-ARCH
## Arquitectura General del Sistema

### SKULL · SBOS — Sovereign Business Operating System
### v5.0 · Actualización de Coherencia Arquitectónica · Marzo 2026

---

## Tabla de Contenidos

1. [SBOS como Sistema Operativo](#sbos)
2. [La Analogía del Kernel — Por Qué es Precisa](#2-la-analogía-del-kernel--por-qué-es-precisa)
3. [Decisión Arquitectónica Fundacional — WAL como Event Bus Nativo](#3-decisión-arquitectónica-fundacional--wal-como-event-bus-nativo)
4. [Los 8 Daemons Soberanos del Host y Edge](#4-la-los daemons soberanos-de-daemons-soberanos-del-host)
5. [Diagrama de Arquitectura Completa](#5-diagrama-de-arquitectura-completa)
6. [Las Cinco Capas del SBOS](#sbos)
7. [Los Bounded Contexts del Sistema](#7-los-bounded-contexts-del-sistema)
8. [Flujo de Datos — El bKernel como Intermediario](#8-flujo-de-datos--el-bkernel-como-intermediario)
9. [Flujo de Integración Exterior — biedata](#9-flujo-de-integración-exterior--biedata)
10. [Flujo de Inteligencia — bCompass](#10-flujo-de-inteligencia--bcompass)
11. [Flujo de Control — El IAM Installer como Vigilante](#11-flujo-de-control--el-iam-installer-como-vigilante)
12. [Flujo de Identidad — Keycloak como Gobierno](#12-flujo-de-identidad--keycloak-como-gobierno)
13. [Flujo de Instalación — De Ubuntu Limpio a Stack Completo](#13-flujo-de-instalación--de-ubuntu-limpio-a-stack-completo)
14. [Relación entre los 6 Pilares](#14-relación-entre-los-6-pilares)
15. [Los Dos Dominios Primarios: Core vs bKernel](#15-los-dos-dominios-primarios-core-vs-bkernel)
16. [Fronteras que No se Cruzan](#16-fronteras-que-no-se-cruzan)
17. [Registro de Cambios v4.0](#17-registro-de-cambios-respecto-a-v30)

---

## 1. SBOS como Sistema Operativo

En un sistema operativo convencional, el kernel gestiona hardware, procesos y memoria. Las aplicaciones corren encima sin conocer los detalles del hardware. El kernel es el intermediario invisible.

SBOS aplica este principio al negocio. El bKernel gestiona datos entre aplicaciones. Las aplicaciones del BOS corren encima sin conocerse entre sí. El bKernel es el intermediario invisible que consolida todo a través de PostgreSQL.

```
Sistema Operativo Convencional          SBOS (Sistema Operativo Empresarial)
─────────────────────────────          ──────────────────────────────────────
Hardware                                PostgreSQL (lenguaje universal — WAL)
Kernel (Linux)                          bKernel (daemon de consolidación)
Procesos / Aplicaciones                 Fichas del BOS (110+ aplicaciones)
Shell / Interfaz                        SBOS VDI + Core UI
Gestión de identidad del SO             Keycloak (gobierno central)
Instalador del SO                       IAM Installer (construye su propia plataforma)
Init system (systemd)                   IAM Installer como servicio systemd
Package manager (apt)                   Sistema de fichas SBOS
Subsistema de E/S                       biedata (integración con el exterior)
Procesador de señales del SO            bCompass (inteligencia y orquestación)
```

La diferencia con otros "sistemas operativos empresariales" del mercado (SAP, Oracle, Microsoft 365) es que esos sistemas son el kernel Y las aplicaciones. El SBOS es solo el kernel — las aplicaciones son open source, intercambiables, y el cliente puede reemplazar cualquiera de ellas. El sistema operativo permanece.

---

## 2. La Analogía del Kernel — Por Qué es Precisa

La analogía no es metafórica. Hay tres correspondencias técnicas directas:

**Correspondencia 1 — bKernel e interrupciones del hardware**

En Linux, el kernel no interroga al hardware continuamente. El hardware genera una interrupción y el kernel reacciona. El bKernel hace lo mismo: no interroga a las apps continuamente. PostgreSQL genera un evento en el WAL y el bKernel reacciona. El mecanismo es arquitectónicamente idéntico: reactividad basada en eventos, no polling.

**Correspondencia 2 — Sistema de fichas y package manager**

`apt install postgresql` descarga un paquete, resuelve dependencias, ejecuta scripts pre/post-install, registra el estado en su base de datos, y el servicio queda activo. El sistema de fichas SBOS hace exactamente lo mismo con cada aplicación del stack — el concepto es el mismo, el dominio es diferente (apps empresariales en lugar de paquetes del SO).

**Correspondencia 3 — IAM Installer e init system**

`systemd` es el proceso PID 1. Arranca antes que todo, vigila servicios, los reinicia si fallan, gestiona dependencias entre ellos. El IAM Installer tiene exactamente ese rol para el stack SBOS: es el primer proceso con intención, arranca antes que cualquier app, vigila todo el stack permanentemente.

---

## 3. Decisión Arquitectónica Fundacional — WAL como Event Bus Nativo

Esta decisión es una contribución original del SBOS a la arquitectura de sistemas empresariales y debe entenderse antes de leer cualquier otro componente del sistema.

### La decisión

**El SBOS no usa Kafka, RabbitMQ, Redis Streams como bus principal, n8n, ni ningún middleware de mensajería externo para la comunicación entre sus daemons soberanos. El Write-Ahead Log (WAL) de PostgreSQL es el bus de eventos nativo del sistema.**

### El problema que resuelve

Todo sistema que necesita sincronizar datos entre múltiples aplicaciones enfrenta la misma pregunta: ¿cómo sé que algo cambió en la app A para actuar en la app B? Las respuestas convencionales son:

- **Polling:** cada N segundos, consultar si hubo cambios. Introduce latencia, sobrecarga de red, y falsos negativos.
- **Webhooks:** la app A notifica a quien corresponda. Requiere modificar el código de la app A — viola el principio de cero invasión.
- **Message broker externo (Kafka, RabbitMQ):** la app A publica en el broker, los consumidores suscriben. Requiere que la app A publique — de nuevo, viola cero invasión. Además agrega una pieza de infraestructura nueva con su propia complejidad operacional.
- **WAL de PostgreSQL:** cuando cualquier app escribe en su base de datos PostgreSQL, el WAL registra esa escritura. Un consumidor externo puede leer ese WAL sin que la app sepa que alguien lo está escuchando. Cero invasión. Cero latencia de polling. Cero infraestructura adicional.

### Por qué el WAL es la elección correcta para el SBOS

| Propiedad | Kafka | RabbitMQ | PostgreSQL WAL |
|---|---|---|---|
| **Cero invasión a las apps** | No — la app debe publicar | No — la app debe publicar | Sí — la app solo escribe en su BD |
| **Ordering estricto de eventos** | Por partición | No garantizado | Sí — por LSN (Log Sequence Number) |
| **Durabilidad sin configuración extra** | Sí (replicación) | Opcional | Sí — el WAL ya es durable por diseño |
| **Infraestructura adicional** | Zookeeper/KRaft + brokers | Nodes + VHosts + Exchanges | Nada — PostgreSQL ya está |
| **Event sourcing nativo** | Sí | No | Sí — el WAL es por definición un log de eventos |
| **Compatibilidad con Change Data Capture** | Via Debezium | No | Nativa — `pg_recvlogical`, `pgoutput` |
| **Acceso desde el host sin red K8s** | No | No | Sí — socket Unix local |

### Las consecuencias arquitectónicas

1. **Los daemons soberanos comparten un bus común sin coordinación entre ellos.** bKernel, biedata y bCompass todos escuchan el WAL. No se conocen entre sí. Cada uno decide de forma independiente qué eventos le interesan.

2. **La adición de un nuevo daemon nunca requiere modificar ninguna app.** Un nuevo daemon hipotético (un auditor externo, un sistema de compliance) puede conectarse al WAL y observar todo el stack sin tocar nada.

3. **El orden causal de los eventos es garantizado por el LSN.** No hay race conditions posibles por reordenamiento de mensajes.

4. **El sistema de mensajería falla solo si PostgreSQL falla** — y PostgreSQL ya tiene HA con Patroni de 3 nodos porque es el único SPOF real del sistema.

5. **n8n, Zapier, Make, y cualquier herramienta de "workflow automation" externa están explícitamente excluidos del stack** porque su modelo requiere que las apps publiquen eventos — viola cero invasión — y porque introducen dependencias de licencia que pueden violar el Principio P3 (licencias libres).

---

## 4. Los 8 Daemons Soberanos del Host y Edge

Junto al IAM Installer, el SBOS tiene siete daemons adicionales que corren como servicios `systemd` en el host Ubuntu — fuera de Kubernetes. La distinción es arquitectónicamente crítica:

```
══════════════════════════════════════════════════════════════════
  HOST UBUNTU — SERVICIOS SYSTEMD (fuera de K8s)
══════════════════════════════════════════════════════════════════
  [systemd]
    ├── iam-installer.service   PLANO DE CONTROL
    │     Instala, vigila, repara, actualiza el stack
    │     Escucha: filesystem servers/ + estado .sbos_state.json
    │
    ├── bkernel.service         PLANO DE DATOS
    │     Consolida datos entre apps internas del stack
    │     Escucha: PostgreSQL WAL via pg_recvlogical (slot: bkernel_slot)
    │
    ├── biedata.service        PLANO DE INTEGRACIÓN
    │     Conecta el stack con sistemas externos
    │     Escucha: PostgreSQL WAL (slot: biedata_slot) + triggers declarados
    │
    └── bcompass.service        PLANO DE INTELIGENCIA
          Genera inteligencia y orquesta workflows declarativos
          Escucha: PostgreSQL WAL (slot: bcompass_slot) + schedules

══════════════════════════════════════════════════════════════════
  KUBERNETES CLUSTER — PODS (dentro de K8s)
══════════════════════════════════════════════════════════════════
  sbos-data:      postgresql (Patroni HA) · redis · minio
  sbos-identity:  keycloak · vault · oauth2-proxy
  sbos-installer: core-ui (Flutter)
  sbos-gateway:   kong · nginx · certbot
  sbos-erp:       tryton · rabbitmq
  sbos-apps:      orangehrm · saleor · espocrm · zammad · nextcloud ...
  sbos-search:    meilisearch · elasticsearch
  sbos-ai:        ollama · qdrant · open-webui · langfuse
  sbos-monitor:   prometheus · grafana · loki · alertmanager
  ... (110+ aplicaciones distribuidas en 15 servidores lógicos)
══════════════════════════════════════════════════════════════════
```

**Por qué los daemons corren en el host y no como pods:**
Los daemons soberanos systemd necesitan acceso al WAL de PostgreSQL a través del socket Unix local (`/var/run/postgresql/.s.PGSQL.5432`). Un pod K8s accedería a PostgreSQL a través de la red del cluster — añadiendo latencia de red en la ruta más crítica del sistema. El acceso local por socket Unix es un orden de magnitud más rápido que TCP, y es determinista: no depende del estado de la red del cluster.

Adicionalmente, el IAM Installer no puede ser un pod K8s porque debe estar activo incluso cuando K8s está caído — es el responsable de repararlo.

---

## 5. Diagrama de Arquitectura Completa

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  SERVIDOR DEL CLIENTE (hardware propio / VPS dedicado)                       │
│  Ubuntu Server 24.04 LTS                                                     │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │  CAPA DE USUARIO (acceso humano)                              [K8s]  │    │
│  │                                                                       │    │
│  │  ┌─────────────────────────────┐  ┌──────────────────────────────┐  │    │
│  │  │  Core UI (Flutter)          │  │  SBOS VDI (Fedora KDE / Kasm)   │  │    │
│  │  │  pod: sbos-installer        │  │  pod: sbos-vdi               │  │    │
│  │  │  Admin: instala fichas,     │  │  Usuario final: escritorio   │  │    │
│  │  │  monitorea, aprueba         │  │  corporativo booteable USB   │  │    │
│  │  └─────────────────────────────┘  └──────────────────────────────┘  │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │  CAPA DE GOBIERNO (identidad · acceso · comportamiento)       [K8s]  │    │
│  │                                                                       │    │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────────────┐   │    │
│  │  │  Keycloak     │  │  Vault        │  │  Kong API Gateway     │   │    │
│  │  │  OIDC · MFA   │  │  Secrets TTL  │  │  Rate limit · Auth    │   │    │
│  │  │  RolFramework │  │  Rotación 90d │  │  NetworkPolicy ZT     │   │    │
│  │  └───────────────┘  └───────────────┘  └───────────────────────┘   │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │  CAPA DE APLICACIONES (lógica de negocio)                     [K8s]  │    │
│  │                                                                       │    │
│  │  erpserver:  Tryton (hub MDM) · RabbitMQ                             │    │
│  │  appsserver: OrangeHRM · Saleor · EspoCRM · Zammad · Nextcloud ...   │    │
│  │  commsserver: Postfix · Dovecot · Rocket.Chat · Mattermost ...       │    │
│  │  docserver:  Paperless-NGX · DocuSeal · Kimios · Tesseract ...       │    │
│  │  reportserver: Tryton-reports · Superset · Airflow · JasperSoft ...  │    │
│  │  searchserver: Meilisearch · Elasticsearch                            │    │
│  │  geoserver: Traccar · Fleetbase · Xibo · Novo SGA                    │    │
│  │  aiserver:  Ollama · Qdrant · Open WebUI · Langfuse · Emb.Worker     │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │  CAPA DE DATOS (persistencia y eventos)                       [K8s]  │    │
│  │                                                                       │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │  PostgreSQL (Patroni HA — 3 nodos)                          │    │    │
│  │  │                                                             │    │    │
│  │  │  BD por app: tryton_db · orangehrm_db · saleor_db ...       │    │    │
│  │  │                                                             │    │    │
│  │  │  WAL ──────────────────────────────────────────────────►   │    │    │
│  │  │       bkernel_slot · biedata_slot · bcompass_slot          │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  │  Redis · MinIO                                                        │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │  CAPA DE DAEMONS SOBERANOS (host Ubuntu — fuera de K8s)  [systemd]  │    │
│  │                                                                       │    │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │    │
│  │  │  bkernel         │  │  biedata        │  │  bcompass        │  │    │
│  │  │  .service        │  │  .service        │  │  .service        │  │    │
│  │  │                  │  │                  │  │                  │  │    │
│  │  │  WAL Listener    │  │  WAL Listener    │  │  WAL Listener    │  │    │
│  │  │  Rule Engine     │  │  Box Engine      │  │  Route Engine    │  │    │
│  │  │  Task Catalog    │  │  Box Catalog     │  │  Route Catalog   │  │    │
│  │  │  Writer Pool     │  │  Adapters        │  │  Ollama Client   │  │    │
│  │  │                  │  │                  │  │                  │  │    │
│  │  │  → Tryton hub    │  │  → SIN/AFIP/SAT  │  │  → Sugerencias  │  │    │
│  │  │  → Apps internas │  │  → APIs externas │  │  → Agentes NLU  │  │    │
│  │  │  → Auditoria     │  │  → Excel/CSV     │  │  → Reportes     │  │    │
│  │  └──────────────────┘  └──────────────────┘  └──────────────────┘  │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │  CAPA DE INFRAESTRUCTURA (plataforma de ejecución)                   │    │
│  │                                                                       │    │
│  │  ┌──────────────────────────────┐  ┌────────────────────────────┐  │    │
│  │  │  IAM Installer  [systemd]    │  │  Kubernetes Cluster [K8s]  │  │    │
│  │  │                              │  │                            │  │    │
│  │  │  Core SP-01 (Bash)           │  │  CRI-O · Calico            │  │    │
│  │  │  Backend Python x15          │◄─►│  MetalLB · Kyverno         │  │    │
│  │  │  (Core UI es pod K8s ↑)      │  │  NetworkPolicy zero-trust  │  │    │
│  │  │                              │  │  etcd encriptado AES-256   │  │    │
│  │  └──────────────────────────────┘  └────────────────────────────┘  │    │
│  │                                                                       │    │
│  │  hostserver/: sbos-bootstrap · sbos-k8s-upgrader                     │    │
│  │               sbos-cert-rotation · sbos-compliance-check             │    │
│  │               sbos-node-hardening  [todos: workload.type: bash]      │    │
│  │                                                                       │    │
│  │                    Ubuntu Server 24.04 LTS                            │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────┘

Leyenda:
  [K8s]     = componente que corre como pod en el cluster Kubernetes
  [systemd] = componente que corre como servicio systemd en el host Ubuntu
              (fuera de Kubernetes — acceso directo al socket Unix de PostgreSQL)
```

---

## 6. Las Cinco Capas del SBOS

El diagrama revela cinco capas con responsabilidades claramente separadas. Esta separación no es cosmética — cada capa tiene una única razón para cambiar:

| Capa | Responsabilidad única | Cambia cuando... |
|---|---|---|
| **Usuario** | Interfaz humana | La experiencia del usuario cambia |
| **Gobierno** | Identidad y permisos | Las políticas de acceso cambian |
| **Aplicaciones** | Lógica de negocio | Una aplicación nueva se agrega o actualiza |
| **Datos** | Persistencia y eventos WAL | PostgreSQL o el esquema de datos cambia |
| **Daemons Soberanos** | Sincronización, integración, inteligencia | Las reglas de negocio entre daemons cambian |
| **Infraestructura** | Plataforma de ejecución | La tecnología de base cambia (K8s, Ubuntu) |

### Por qué esta separación es la correcta

El modelo alternativo — el que usa SAP o Microsoft Dynamics — integra las capas de gobierno, aplicación y datos en un único monolito. El resultado es que cambiar cualquier cosa requiere tocar el monolito completo. Agregar un módulo nuevo requiere certificación con el proveedor. Integrar una app de terceros requiere un conector pagado.

En el SBOS, agregar la app número 97 al stack es crear una carpeta de ficha. La capa de gobierno (Keycloak) la absorbe via OIDC estándar. La capa de datos (PostgreSQL) la persiste. El bKernel la escucha vía WAL. La infraestructura (K8s) la ejecuta. Ninguna capa necesita saber que llegó la app 97.

---

## 7. Los Bounded Contexts del Sistema

Un **Bounded Context** (término de Domain-Driven Design, Eric Evans 2003) es un dominio de negocio con su propia fuente de verdad, su propio lenguaje ubícuo, y contratos de integración bien definidos con los demás contextos. El SBOS tiene cuatro bounded contexts principales.

En la terminología DDD, la relación entre los bounded contexts del SBOS es de tipo **Customer-Supplier**: el bKernel es el integrador que actúa como supplier de datos consolidados para todos los contextos, con cada app actuando como customer. No hay Shared Kernel (ninguna base de datos es compartida) ni relación de tipo Conformist (las apps no adaptan su modelo al del bKernel — el bKernel adapta el suyo a cada app).

| Bounded Context | Servidor lógico | Fuente de Verdad | Entidad central | Contrato con otros contextos |
|---|---|---|---|---|
| **Negocio Central** | erpserver | Tryton | `party.party` (personas/empresas) | Publica via WAL → bKernel consume y propaga |
| **Capital Humano** | appsserver (RRHH) | OrangeHRM | `hs_hr_employee` | Publica via WAL → bKernel crea `party` en Tryton |
| **Relación con Clientes** | appsserver (CRM/eComm) | EspoCRM + Saleor | `contacts`, `orders` | Publica via WAL → bKernel sincroniza con Tryton |
| **Comunicaciones** | commsserver | Postfix + Rocket.Chat | `mailbox`, `channel` | Recibe provisioning de Keycloak via bKernel |
| **Identidad y Acceso** | identityserver | Keycloak | `user`, `realm`, `role` | Provee JWT a todos → RolFramework via bKernel |
| **Conocimiento y Docs** | docserver + vdiserver | Paperless + Nextcloud | `document`, `file` | Consume identidad de Keycloak |
| **Inteligencia** | aiserver | Qdrant (vectores) | `embedding`, `query` | Consume eventos de todos via bCompass |
| **Observabilidad** | monitorserver | Prometheus + Loki | `metric`, `log` | Consume de todos (scraping) — no publica |

### Reglas de comunicación entre bounded contexts

Estas reglas son invariantes arquitectónicas — no convenciones:

1. **Ningún bounded context lee directamente la base de datos de otro.** Toda lectura cruzada pasa por el bKernel o por la API pública de la app.
2. **El bKernel es el único actor autorizado a escribir en las bases de datos de las apps** cuando el propósito es sincronización de datos de negocio.
3. **Keycloak es el único actor autorizado a provisionar identidades.** Ningún daemon soberano crea usuarios en Keycloak directamente — solicita la creación via la API de KC.
4. **biedata es el único actor autorizado a enviar datos fuera del servidor del cliente.** Ninguna app del stack tiene permisos de red hacia el exterior excepto a través de biedata.
5. **bCompass es el único actor autorizado a invocar Ollama.** Ninguna app del stack llama directamente al LLM local — toda inferencia pasa por bCompass para garantizar trazabilidad y control de costos computacionales.

### El Context Map del SBOS

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  [Negocio Central]     ◄──────── bKernel ────────► [Capital Humano] │
│   Tryton (hub MDM)     ◄──────── (WAL CDC) ───────► OrangeHRM       │
│                        ◄──────────────────────────► EspoCRM/Saleor  │
│                                   │                                  │
│                                   │ bCompass                         │
│                                   ▼                                  │
│                       [Inteligencia]                                 │
│                        Qdrant + Ollama                               │
│                                   │                                  │
│                          biedata │                                  │
│                                   ▼                                  │
│                       [Exterior]                                     │
│                        SIN · AFIP · SAT · APIs externas              │
│                                                                      │
│  [Identidad]  ──JWT──► todas las apps y daemons                      │
│   Keycloak                                                           │
│                                                                      │
│  [Observabilidad]  ◄── scraping ── todos los contextos              │
│   Prometheus + Loki                                                  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 8. Flujo de Datos — El bKernel como Intermediario

Las aplicaciones del BOS no se conocen entre sí. El bKernel es el único actor que mueve datos entre ellas. Este principio — que los ingenieros de sistemas llaman **loose coupling** o desacoplamiento — es lo que hace al sistema resiliente: si OrangeHRM falla, Tryton sigue funcionando; cuando OrangeHRM se recupera, el bKernel sincroniza los eventos que se perdieron.

**Flujo directo — OrangeHRM → Tryton:**
```
Usuario registra empleado en OrangeHRM
  ↓
OrangeHRM escribe en su BD PostgreSQL (tabla hs_hr_employee)
  ↓
PostgreSQL genera evento en el WAL (slot: bkernel_slot)
  ↓
bKernel detecta: "INSERT en hs_hr_employee de OrangeHRM"
  ↓
bKernel evalúa Rule Engine: regla OHRM-001 "employee_to_tryton"
  ↓
bKernel ejecuta Task Catalog: UPSERT en Tryton.party_party
  ↓
Tryton tiene el empleado — sin que OrangeHRM sepa que Tryton existe
  ↓
(Forward-chaining) bKernel propaga vía reglas:
  → CROSS-001: crea usuario en Keycloak
  → CROSS-002: suscribe a canales en Rocket.Chat
  → CROSS-003: registra costo laboral en Tryton
  → CROSS-004: agenda inducción en Easy!Appointments
  → Notificación en Mattermost a jefatura directa
```

**Flujo inverso — Tryton → Saleor:**
```
Contador registra proveedor en Tryton
  ↓
Tryton escribe en su BD PostgreSQL
  ↓
PostgreSQL genera evento WAL
  ↓
bKernel detecta: "nuevo proveedor en Tryton"
  ↓
bKernel ejecuta regla: "proveedor → crear vendor en Saleor"
  ↓
Saleor tiene el proveedor sincronizado
```

**El principio de cero invasión en detalle:**

El bKernel nunca ejecuta `ALTER TABLE` en ninguna base de datos. Nunca agrega columnas, triggers, ni views en las bases de datos de las aplicaciones. Nunca modifica el código fuente de ninguna app. Opera exclusivamente leyendo el WAL (lectura) y escribiendo en tablas existentes via las APIs públicas de las apps o via escritura directa en PostgreSQL (escritura controlada).

---

## 9. Flujo de Integración Exterior — biedata

biedata conecta el stack SBOS con sistemas externos al servidor del cliente. Es el único daemon autorizado a enviar o recibir datos fuera del perímetro del servidor.

**Flujo de exportación — Factura electrónica al SIN Bolivia:**
```
Tryton registra factura confirmada
  ↓
PostgreSQL genera evento WAL (slot: biedata_slot)
  ↓
biedata detecta: "estado factura → CONFIRMED en Tryton"
  ↓
biedata evalúa Box Engine: ¿hay Caja para este evento?
  ↓
Caja: siat-bolivia-factura-electronica/
  Box Engine ejecuta fase por fase:
    → Fase validate: verifica campos obligatorios SIN
    → Fase transform: genera XML SIAT v3.0
    → Fase transmit: POST a API SIN con certificado digital
    → Fase confirm: registra CUFD/CUIS en bos_biedata_results
    → Fase notify: publica en cola Redis → bCompass notifica al contador
  ↓
Factura registrada en el SIN. Tryton actualizado con número de autorización.
```

**Flujo de importación — Carga masiva desde Excel:**
```
Contador sube archivo Excel de empleados al Core UI
  ↓
Core UI publica evento en Redis: biedata:import_queue
  ↓
biedata consume el evento
  ↓
Caja: excel-rrhh-import/
  → Fase parse: lee .xlsx con openpyxl
  → Fase validate: verifica campos obligatorios OrangeHRM
  → Fase transform: mapea columnas Excel → campos OrangeHRM
  → Fase write: INSERT en hs_hr_employee (escritura directa PostgreSQL)
  → bKernel detecta los INSERT → propaga a Tryton/Keycloak automáticamente
  ↓
50 empleados importados. Propagación automática al stack completo.
```

biedata opera con **Cajas declarativas**: unidades YAML + binario compilado que especifican cómo conectar el stack con un sistema externo. Agregar soporte para un nuevo sistema externo = crear la carpeta de la Caja. El daemon biedata no cambia. La especificación completa de biedata está en SBOS-011.

---

## 10. Flujo de Inteligencia — bCompass

bCompass observa el stack continuamente y ejecuta Rutas declarativas de cuatro tipos: analyst (sugiere al admin), agent (responde en lenguaje natural), flow (automatiza workflows con aprobación humana), y report (genera documentos periódicos).

**Flujo analyst — Detección de anomalía:**
```
bCompass detecta via WAL: patrón inusual en ventas_diarias_tryton
  ↓
Ruta: analyst/kpi_ventas_anomalia
  → Route Engine fase observe: consulta bkernel_db + tryton_db
  → Route Engine fase analyze: compara con histórico (30 días)
  → LLM (Ollama qwen3:8b): genera explicación en lenguaje natural
  → Route Engine fase suggest: crea suggestion en bcompass_db
    { status: pending, category: sales_anomaly, priority: high }
  ↓
Core UI muestra alerta al administrador:
  "Ventas de la sucursal Norte 43% por debajo del promedio histórico.
   Posibles causas: [análisis generado]. ¿Aprobar investigación?"
  [Aprobar] [Descartar] [Ver detalle]
```

**Flujo agent — Consulta de empleado:**
```
Empleado en SBOS VDI escribe: "¿Cuántos días de vacaciones me quedan?"
  ↓
SBOS VDI publica en Centrifugo: { realm: acme, user_id: maria.garcia, query: "..." }
  ↓
bCompass consume: ruta agent/empleado_asistente
  → Recupera contexto: JOIN bkernel_db + orangehrm_db WHERE user_id = maria.garcia
  → Construye prompt: "Datos del empleado: [contexto]. Pregunta: [query]"
  → Ollama genera respuesta: "Te quedan 8 días hábiles de vacaciones..."
  ↓
Respuesta entregada al empleado en el chat del SBOS VDI.
  Datos nunca salieron del servidor.
```

La especificación completa de bCompass está en SBOS-014.

---

## 11. Flujo de Control — El IAM Installer como Vigilante

```
Ubuntu Server 24.04 LTS — instalación mínima
  ↓
Técnico ejecuta: curl -sSL https://get.sbos.io/installer | sudo bash
  ↓
IAM Installer instalado como servicio systemd
  ↓
Sistema arranca → systemd levanta IAM Installer (siempre, en cada arranque)
  ↓
¿Hay cluster K8s?
  │
  NO ──► Ejecuta Ficha Bootstrap (SP-02)
  │        Ubuntu hardening + K8s + Calico + MetalLB + Kyverno
  │        Namespaces + ResourceQuotas + Encriptación etcd
  │        Core UI desplegado en sbos-installer
  │        kube-bench CIS Level 1 — todos PASS
  │        ↓
  │      Cluster K8s operativo (~50 minutos)
  │
  SÍ ──► Verifica Ficha Bootstrap: ¿hay cambios pendientes?
           SÍ ──► Aplica cambios (nuevo hardening, upgrade K8s, etc.)
           NO ──► Continúa al loop de vigilancia
  ↓
LOOP DE VIGILANCIA PERMANENTE (cada 30 segundos)
  │
  ├── Para cada ficha en estado INSTALADA — OK:
  │     Ejecuta health check → ¿estado correcto?
  │       NO ──► Ejecuta fase repair
  │                diagnosis_first: true (si criticality: true)
  │                Si repair falla → alerta al administrador
  │
  ├── ¿Hay fichas en ACTUALIZACIÓN_DISPONIBLE?
  │     SÍ ──► Notifica al administrador en Core UI
  │             Administrador aprueba → IAM Installer actualiza
  │
  └── ¿Hay fichas PENDIENTE_INSTALACIÓN?
        SÍ ──► Resuelve dependencias (DEPENDENCY_RESOLVER)
                Ejecuta instalación en orden correcto
```

---

## 12. Flujo de Identidad — Keycloak como Gobierno

Keycloak implementa tres funciones de gobierno simultáneas: identidad (quién eres), acceso (qué puedes hacer), y comportamiento (cómo puedes trabajar).

**Función 1 — Gobierno de identidad:**
```
Empleado nuevo creado en OrangeHRM
  ↓
bKernel detecta INSERT en hs_hr_employee
  ↓
bKernel ejecuta regla CROSS-001: crea usuario en Keycloak via REST API
  realm: acme_empresa → usuario: maria.garcia → rol: cajero
  ↓
Keycloak asigna el RolTemplate del rol "cajero" al usuario
  ↓
RolTemplate define: apps accesibles, límites de privilegios, políticas VDI
  ↓
Empleado puede iniciar sesión en todas las apps del stack con una credencial
```

**Función 2 — Gobierno de acceso (JWT como fuente de verdad):**
```
Empleado inicia sesión → Keycloak emite JWT:
  {
    "sub": "maria.garcia",
    "realm": "acme_empresa",
    "bos_roles": ["cajero"],
    "bos_privileges": 0b0001010011,
    "bos_apps": ["tryton", "saleor", "zammad"],
    "bos_vdi_profile": "cajero-suc-norte-caja3"
  }

Cada app del stack valida el JWT de Keycloak.
Ninguna app verifica permisos internamente — confían en el JWT.
Tryton enforcea 5 capas adicionales basadas en grupos que mapean al RolTemplate.
```

**Función 3 — Gobierno de comportamiento:**
```
RolTemplate del cajero define:
  vdi_policy:
    youtube_allowed: false
    whatsapp_web_allowed: false
    nextcloud_personal: true

Keycloak comunica estas políticas al SBOS VDI via bos_vdi_profile en el JWT.
SBOS VDI aplica NetworkPolicy de K8s: bloquea youtube.com y web.whatsapp.com
  para este usuario específico.

Si el cajero mejora su desempeño → admin cambia su RolTemplate
  → próximo login → JWT tiene nuevas políticas → NetworkPolicy se actualiza
  → youtube.com accesible.

Esto es gobierno de comportamiento: no solo autenticación.
```

---

## 13. Flujo de Instalación — De Ubuntu Limpio a Stack Completo

```
T+00:00  Ubuntu Server 24.04 LTS — instalación mínima
           ↓ (único comando del técnico SKULL)
T+00:02  IAM Installer como servicio systemd
           ↓ (automático)
T+00:48  Kubernetes cluster operativo · Core UI disponible en navegador
           ↓ (administrador del cliente toma el control)
T+01:00  Administrador instala fichas desde el catálogo del Core UI

ORDEN DE INSTALACIÓN (execution_order + depends_on):

  hostserver/   [automático, gestionado por IAM Installer]
    sbos-bootstrap (0) → ya ejecutado durante el arranque

  Fase 1 — Infraestructura de datos:
    postgresql (100) → redis (110) → minio (120)

  Fase 2 — Seguridad y gobierno:
    vault (130) → keycloak (140) → oauth2-proxy (150)

  Fase 3 — Gateway:
    kong (160) → nginx (170) → certbot (180)

  Fase 4 — Comunicaciones base:
    mailserver (200) → postfixadmin (210) → roundcube (220)

  Fase 5 — ERP y negocio:
    rabbitmq (300) → tryton (310)

  Fase 6 — Daemons soberanos [fichas Tipo 1 — systemd del host]:
    bkernel (350) → biedata (360) → bcompass (370)

  Fase 7+ — Aplicaciones de negocio (según cliente):
    orangehrm, saleor, espocrm, zammad, nextcloud...

  Fase final — Opcional:
    aiserver: ollama (900) → qdrant (910) → open-webui (920)
              embedding-worker (930) → langfuse (940)
```

---

## 14. Relación entre los 6 Pilares

| Pilar | Depende de | Le sirve a | Si falla... |
|---|---|---|---|
| **PostgreSQL** | Ubuntu/K8s | Todos los demás pilares y daemons | Stack completo degradado |
| **Keycloak** | PostgreSQL, Vault | Todas las apps, SBOS VDI, Core UI, bKernel | Nadie puede autenticarse |
| **bKernel** | PostgreSQL (WAL) | Todas las apps vía Tryton + bSearch | Apps siguen funcionando, sin sincronización |
| **Tryton** | PostgreSQL, bKernel | Hub central del bKernel | bKernel pierde destino principal |
| **IAM Installer** | Ubuntu (systemd) | Todo el BOS — instala, vigila, repara | Stack sigue corriendo, sin gestión automática |
| **SBOS VDI** | Keycloak, Kasm | Usuarios finales en endpoints | Usuarios acceden por navegador web (fallback) |
| **biedata** | PostgreSQL (WAL), bKernel | Stack ↔ Exterior | Integraciones externas pausadas, stack interno intacto |
| **bCompass** | PostgreSQL (WAL), aiserver | Administradores y usuarios finales | Inteligencia pausada, stack operacional intacto |

**La columna "Si falla" revela la resiliencia del diseño:** la mayoría de los componentes tienen un modo degradado. PostgreSQL es el único Single Point of Failure real — sin él, el stack se detiene. Esto es intencional y consistente con el diseño: PostgreSQL con Patroni tiene HA de 3 nodos precisamente porque es el único SPOF del sistema.

---

## 15. Los Dos Dominios Primarios: Core vs bKernel

El SBOS tiene dos cerebros que operan en dominios completamente separados:

| Aspecto | Core (SP-01) — IAM Installer | bKernel |
|---|---|---|
| **Qué es** | Motor Bash/Python del instalador | Daemon binario soberano (SKULL) |
| **Dónde vive** | Servicio systemd en el host | Servicio systemd en el host |
| **Qué escucha** | Filesystem (`servers/`), estado (`.sbos_state.json`) | PostgreSQL WAL (slot: bkernel_slot) |
| **Qué gobierna** | Infraestructura: contenedores, K8s, fichas, salud | Datos: consolidación y sincronización entre apps |
| **Patrón** | Absorber → Ejecutar → Liberar | Escuchar → Detectar → Actuar |
| **Modelo** | GitOps (declarativo, reconciliación) | Event-driven (reactivo, tiempo real) |
| **Principio** | El Core nunca crece para soportar apps nuevas | El bKernel nunca invade apps ni sus BDs |
| **Extensión** | Agregar una ficha a `servers/` | Agregar una regla YAML al bKernel |

Ambos siguen el mismo meta-principio: **escuchar y actuar sin invadir**. El Core escucha el filesystem. El bKernel escucha el WAL. Ninguno de los dos requiere que las aplicaciones lo conozcan.

biedata y bCompass comparten el mismo patrón event-driven del bKernel — la diferencia está en el dominio: integración con el exterior (biedata) e inteligencia y orquestación (bCompass).

---

## 16. Fronteras que No se Cruzan

Estas son las restricciones arquitectónicas absolutas del SBOS. No son convenciones — son invariantes del sistema. Violarlas destruye una propiedad fundamental de la arquitectura.

**Frontera 1 — `sbos_k8s_core()` es el único `kubectl apply`**

Ningún módulo, script, ficha, ni proceso externo ejecuta `kubectl apply` directamente. Toda operación sobre el cluster K8s pasa por `sbos_k8s_core()`. Esto garantiza trazabilidad completa de cada cambio en el cluster.

**Frontera 2 — El bKernel no modifica esquemas de BD**

El bKernel nunca ejecuta `ALTER TABLE`, `CREATE TABLE`, `DROP TABLE`, ni ninguna operación DDL en las bases de datos de las aplicaciones. Solo opera con DML (INSERT, UPDATE, DELETE) sobre tablas existentes, usando las estructuras que las propias apps crean.

**Frontera 3 — Las fichas no se llaman entre sí**

Una ficha no sabe que otra ficha existe. La comunicación entre apps pasa por el bKernel (datos) y por Keycloak (identidad), nunca directamente entre fichas. Las dependencias declaradas en `depends_on` son dependencias de instalación, no de runtime.

**Frontera 4 — El IAM Installer no es un pod K8s**

El IAM Installer vive como servicio systemd en el host, fuera del cluster K8s. No puede depender de lo que él mismo instala y vigila. Si K8s cae, el IAM Installer sigue activo para diagnosticar y reparar.

**Frontera 5 — El hostserver no instala software de negocio**

Las fichas del hostserver (sbos-bootstrap, sbos-k8s-upgrader, sbos-cert-rotation, sbos-compliance-check, sbos-node-hardening) solo instalan y mantienen Ubuntu + Kubernetes. Ningún software de negocio pertenece al hostserver.

**Frontera 6 — biedata es el único actor con acceso a la red exterior**

Ninguna app del stack tiene permisos de NetworkPolicy para conectarse a IPs o dominios externos. biedata es el único punto de salida autorizado del sistema. Esto garantiza que ningún dato pueda escapar del servidor sin pasar por un contrato declarativo revisable (la Caja).

**Frontera 7 — bCompass es el único actor que invoca el LLM local**

Ninguna app del stack llama directamente a Ollama. Toda inferencia del LLM pasa por bCompass. Esto garantiza trazabilidad de todos los usos del modelo, control de costos computacionales, y coherencia del contexto RAG.

**Frontera 8 — Los daemons soberanos no se llaman entre sí directamente**

bKernel, biedata y bCompass no tienen interfaces de comunicación directa entre ellos. Se comunican exclusivamente a través del WAL y de colas Redis específicas. Esta restricción garantiza que cualquiera de los tres pueda fallar sin afectar a los demás.

---

## 17. Registro de Cambios respecto a v3.0

**Secciones nuevas en v4.0:**
- §3 Decisión Arquitectónica Fundacional — WAL como Event Bus Nativo: tabla comparativa WAL vs Kafka vs RabbitMQ, justificación de la decisión, las 5 consecuencias arquitectónicas incluyendo el veto explícito a n8n y similares
- §4 Los 8 Daemons Soberanos del Host y Edge: diagrama ASCII con distinción visual `[systemd]` vs `[K8s]`, justificación técnica del acceso por socket Unix vs red del cluster
- §7 Los Bounded Contexts del Sistema: tabla de 8 bounded contexts con servidor lógico, fuente de verdad, entidad central y contratos; terminología DDD (Customer-Supplier, ausencia de Shared Kernel); Context Map ASCII; 5 reglas de comunicación entre contextos
- §9 Flujo de Integración Exterior — biedata: flujo de exportación al SIN Bolivia y flujo de importación desde Excel con pasos detallados
- §10 Flujo de Inteligencia — bCompass: flujo analyst (anomalía de ventas) y flujo agent (consulta de empleado) con pasos detallados

**Actualizaciones en v4.0:**
- §1 Tabla analogía SO convencional vs SBOS: agregadas filas biedata (subsistema E/S) y bCompass (procesador de señales)
- §5 Diagrama de Arquitectura Completa: reemplazado completamente — incluye los tres daemons soberanos, distinción visual `[systemd]` / `[K8s]` en cada componente, slots WAL por daemon (bkernel_slot, biedata_slot, bcompass_slot), aiserver completo con Embedding Worker
- §6 Las Cinco Capas: renombrada "Kernel de Datos" a "Daemons Soberanos" para reflejar la los daemons soberanos
- §13 Flujo de Instalación: agregada Fase 6 — instalación de los tres daemons soberanos como fichas Tipo 1; aiserver completo con embedding-worker y langfuse
- §14 Relación entre Pilares: agregadas filas biedata y bCompass con sus dependencias y análisis de resiliencia
- §16 Fronteras: agregadas tres fronteras nuevas — Frontera 6 (biedata único actor exterior), Frontera 7 (bCompass único invocador de LLM), Frontera 8 (daemons no se llaman entre sí)
- Todas las referencias a números de documentos actualizadas a numeración SBOS-000 a SBOS-024

---

*SKULL · SBOS · SBOS-002-ARCH · v5.0 · Actualización de Coherencia Arquitectónica · Marzo 2026*
