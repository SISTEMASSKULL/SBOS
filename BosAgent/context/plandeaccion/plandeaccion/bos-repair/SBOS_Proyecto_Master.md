# SBOS — Smart Business Operating System
## Arquitectura de Referencia Empresarial
### Documento Maestro de Proyecto

**Versión:** 2.1  
**Estado:** Documento Normativo Activo — Brújula del Proyecto  
**Fecha:** 2026-06-12  
**Clasificación:** Interno · Confidencial  
**Estándar de referencia:** HUMAN-DOC · SKULL · SBOS  

### Stack Canónico (ADR-017 — Versiones Obligatorias)

| Componente | Versión Canónica | Componente | Versión Canónica |
|-----------|-----------------|-----------|-----------------|
| Ubuntu Server | 26.04 LTS | Go | 1.26+ |
| PostgreSQL | **18.4** | Rust | **1.85+** |
| Redis | **8.6.2** | Keycloak | **26.6.2** |
| Kubernetes (k3s) | v1.32+ | Vault | 2.0.1 |
| Calico CNI | 3.32.0 | Kong | 3.9.x LTS |
| Podman | 5.3.x | Linkerd | latest stable |

> **Regla ADR-017:** Ningún agente puede usar versiones sin verificar. Verificar → documentar versión exacta → usar. El Bibliotecario rechaza componentes con versión no verificada.

---

## Índice

1. [Definición y Naturaleza del Sistema](#1-definición-y-naturaleza-del-sistema)
2. [Principios Arquitectónicos y Base Normativa](#2-principios-arquitectónicos-y-base-normativa)
3. [El bos — Sistema Operativo Empresarial Soberano](#3-el-bos--sistema-operativo-empresarial-soberano)
4. [Modelo Jerárquico Empresarial](#4-modelo-jerárquico-empresarial)
5. [Context Plane — Plano de Contexto Distribuido](#5-context-plane--plano-de-contexto-distribuido)
6. [Identity Plane — Identidad y Autorización](#6-identity-plane--identidad-y-autorización)
7. [Data Plane — Persistencia y Eventos](#7-data-plane--persistencia-y-eventos)
8. [Web Platform — Sitios por Tenant, Empresa y Sucursal](#8-web-platform--sitios-por-tenant-empresa-y-sucursal)
9. [Storage Plane — Gestión de Recursos](#9-storage-plane--gestión-de-recursos)
10. [Los Ocho Daemons Soberanos](#10-los-ocho-daemons-soberanos)
11. [Backend Services — Go y Rust](#11-backend-services--go-y-rust)
12. [Contratos gRPC y API Pública JSON-RPC](#12-contratos-grpc-y-api-pública-json-rpc)
13. [Observabilidad Semántica](#13-observabilidad-semántica)
14. [Seguridad y Cumplimiento Normativo](#14-seguridad-y-cumplimiento-normativo)
15. [Escalamiento Vertical y Horizontal](#15-escalamiento-vertical-y-horizontal)
16. [La Ficha SBOS — Unidad Atómica de Despliegue](#16-la-ficha-sbos--unidad-atómica-de-despliegue)
17. [Estándares de Desarrollo Backend](#17-estándares-de-desarrollo-backend)
18. [Reglas Inquebrantables del Ecosistema](#18-reglas-inquebrantables-del-ecosistema)
19. [Roadmap de Implementación](#19-roadmap-de-implementación)
20. [Glosario Técnico](#20-glosario-técnico)
21. [Referencias Normativas](#21-referencias-normativas)

---

## 1. Definición y Naturaleza del Sistema

### 1.1 ¿Qué es SBOS?

SBOS (Smart Business Operating System) es un **Sistema Operativo Empresarial Distribuido y Soberano** que actúa como plano de control unificado sobre tres dominios simultáneos —lógico, físico y financiero— capaz de operar sobre cualquier cantidad de nodos geográficamente distribuidos, manteniendo contexto, trazabilidad e identidad consistentes en cada punto.

Esta definición es técnicamente verificable componente por componente en su versión v1.0 GA (Sep 2026).

> **La inversión conceptual fundamental:**
>
> Los sistemas empresariales existentes (SAP, Oracle, Microsoft 365, Odoo) son **aplicaciones que corren sobre un sistema operativo**.
>
> SBOS es el **sistema operativo sobre el que corren las aplicaciones de negocio**.

```
Modelo convencional:
  Hardware → Linux/Windows → SAP/ERP/M365 → Negocio

Modelo SBOS:
  Hardware → Ubuntu/Kubernetes → SBOS → Aplicaciones (Tryton, Saleor, OrangeHRM...)
                                  ↑
                           El OS empresarial
```

Tryton es una aplicación. EspoCRM es una aplicación. SmartTax es una aplicación. SBOS es la capa que las orquesta, les da identidad y contexto, las conecta entre sí mediante el WAL, controla el hardware físico que las rodea, y mantiene trazabilidad de todo lo que ocurre dentro de ellas.

### 1.2 Las Cinco Funciones Canónicas de un Sistema Operativo

SBOS cumple las cinco funciones canónicas de un sistema operativo aplicadas sobre recursos empresariales en lugar de recursos de cómputo:

| Función canónica de un SO | Linux | SBOS |
|---|---|---|
| **Abstrae el hardware** | CPU, RAM, disco, red | Chapas, cajones POS, cámaras, lectores biométricos, torniquetes |
| **Gestiona recursos** | Asigna memoria y CPU a procesos | Asigna namespaces, BDs, secretos y capacidades a tenants y usuarios |
| **Controla procesos** | Arranca, detiene, reinicia procesos | Arranca, detiene, repara fichas (unidades atómicas de servicio) |
| **Gestiona identidad y permisos** | Usuarios, grupos, permisos de archivo | bAuth + Keycloak: quién puede hacer qué, dónde, cuándo, con qué límite |
| **Tiene un kernel** | Linux kernel — gestiona interrupciones y hardware | bKernel — escucha el WAL, propaga cambios, mantiene coherencia de datos |

**Estándar de referencia:** ISA-95 / IEC 62264 (Enterprise-Control System Integration). SBOS implementa los Niveles 3 y 4 de este estándar de forma nativa y soberana.

### 1.3 Lo que SBOS no es

| Podría parecer | La realidad |
|---|---|
| Un ERP | Es la capa que orquesta el ERP (Tryton) junto con todo lo demás |
| Un sistema de autenticación | Keycloak es la autenticación. SBOS orquesta Keycloak |
| Una plataforma cloud | Es soberano: corre en el hardware del cliente. Ningún dato sale |
| Un gestor de contenedores | Kubernetes es el runtime. SBOS es la capa de intención sobre K8s |
| Un framework de integración | La integración es nativa por WAL — no es MuleSoft ni n8n |
| Un RTOS o PLC | Opera en ISA-95 Niveles 3-4 (empresarial), no en control de planta |

### 1.4 Los Tres Dominios Simultáneos

Cada solicitud de acceso se evalúa en tres dimensiones simultáneamente. El resultado es un **BitMask de 64 bits** que define con exactitud qué puede hacer ese usuario, en ese contexto, en ese momento.

**Dominio Lógico** — capacidades digitales:
- Qué aplicaciones puede usar (Tryton, OrangeHRM, Saleor, subproyectos)
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

### 1.5 Casos de Uso Primarios

- ERP multi-empresa y multi-sucursal (Tryton 8)
- Facturación electrónica Bolivia SFE/SIAT — validada contra SIN
- Punto de venta (POS) distribuido con control de hardware físico
- Sitios web institucionales por tenant, empresa y sucursal
- Ecommerce conectado en tiempo real al inventario del ERP
- Búsqueda semántica federada sobre datos de negocio (pgvector/Qdrant)
- Control de acceso físico (chapas, zonas, actuadores) integrado con identidad
- Agentes de IA soberanos coordinados vía HTTP/JSON-RPC

---

## 2. Principios Arquitectónicos y Base Normativa

### 2.1 Principios Técnicos Fundamentales

**P1 — El contexto es responsabilidad del bos.**
El bos IAM Installer es el único componente con visión completa del árbol organizacional (tenant → empresa → sucursal → POS) y del ciclo de vida del tenant. Es el natural dueño del Context Plane. Alineado con NIST SP 800-207 (Policy Administrator).

**P2 — El contexto no vive en los pods.**
Kubernetes mueve pods; el contexto empresarial debe sobrevivir esos movimientos. El ctx_id persiste en Redis y en bkernel_db, no en el estado efímero de un pod.

**P3 — ctx_id inmutable una vez creado.**
Un ctx_id creado no muta. Si el usuario cambia de contexto, se crea un nuevo ctx_id. El anterior queda como `status='switched'` en el audit trail — nunca se elimina. Alineado con ISO/IEC 27001:2022 A.8.15.

**P4 — Context Switch genera nueva sesión.**
El cambio de contexto operativo es una nueva sesión de auditoría. La trazabilidad es limpia por empresa y por POS.

**P5 — Propagación via OTel Baggage + W3C Trace Context.**
El ctx_id viaja en el header W3C Baggage estándar. Cero código adicional en las aplicaciones. Alineado con W3C Trace Context Level 1 y CNCF OpenTelemetry.

**P6 — Aislamiento estricto por tenant.**
Ningún ctx_id de tenant A puede acceder a datos de tenant B. Ninguna query existe sin `tenant_id` en el WHERE. Alineado con ISO/IEC 27001:2022 A.8.3.

**P7 — Degradación elegante.**
Si Redis no está disponible, el bos sirve el Context Registry desde bkernel_db con mayor latencia. El sistema degrada — no falla.

**P8 — Audit trail inmutable.**
La tabla `context_sessions` nunca se elimina. Solo se marca como `invalidated`. Es evidencia forense. Alineado con ISO/IEC 27001:2022 A.8.15.

**P9 — Infraestructura compartida, contexto aislado.**
Un PostgreSQL, un Keycloak, un Redis, un Kong. El aislamiento es contextual, no físico. Miles de empresas sobre la misma infraestructura.

**P10 — API-first. El `.proto` es la fuente de verdad.**
Antes de escribir Go o Rust, se escribe el `.proto`. El backend no sabe ni le importa qué cliente existe.

### 2.2 Base Normativa Internacional

| Estándar | Organismo | Aplicación en SBOS |
|---|---|---|
| **ISO/IEC 27001:2022** | ISO/IEC | Sistema de gestión de seguridad. Controles A.8.15 (logging) y A.8.16 (monitoreo) implementados vía audit_events + ctx_id |
| **ISO/IEC 27017:2015** | ISO/IEC | Controles de seguridad para servicios en la nube. Aislamiento de tenants, gestión de activos compartidos |
| **ISO/IEC 27018:2019** | ISO/IEC | Protección de datos personales en nube. Cifrado en tránsito y en reposo, consentimiento de datos |
| **NIST SP 800-207** | NIST | Zero Trust Architecture. PE/PA/PEP mapeados a bAuth/bos/Kong. Tenet 3: acceso por sesión, mínimo privilegio |
| **NIST SP 800-53 Rev.5** | NIST | Controles de seguridad: AC (control de acceso), AU (auditoría), IA (identificación), SC (comunicaciones) |
| **W3C Trace Context Level 1** | W3C | Estándar de propagación de trazas distribuidas. Headers `traceparent` y `tracestate`. Implementado vía OTel Baggage |
| **OpenTelemetry** | CNCF | Proyecto graduado CNCF. SDK de instrumentación universal. Baggage Processor para propagación de ctx_id |
| **ISA-95 / IEC 62264** | ISA/IEC | Enterprise-Control System Integration. SBOS implementa Niveles 3-4 |
| **FAPI 2.0 + DPoP** | OpenID Foundation | Financial-grade API. Para operaciones financieras de alto valor en Keycloak |

### 2.3 Mapeo NIST SP 800-207 → SBOS

El estándar Zero Trust define tres componentes obligatorios. SBOS los implementa de forma nativa:

| Componente NIST 800-207 | Equivalente en SBOS | Implementación |
|---|---|---|
| **Policy Engine (PE)** | bAuth | Evalúa BitMask, RolTemplate, ctx activo. Dominio lógico + físico + financiero |
| **Policy Administrator (PA)** | bos IAM Installer | Provisiona y destruye contextos de tenant. Dueño del Context Plane |
| **Policy Enforcement Point (PEP)** | Kong API Gateway | Plugin SBOS-Context: extrae ctx_id, verifica contra bos Context API, inyecta headers |

> *"Grant per-session access to follow least-privilege, ensuring privileges are time-bound."*
> — NIST SP 800-207, Tenet 3

---

## 3. El bos — Sistema Operativo Empresarial Soberano

### 3.1 Propósito

El **bos (IAM Installer)** es el Control Plane soberano del sistema. Es el `systemd` del SBOS empresarial: instala, actualiza, repara y elimina fichas; gestiona el ciclo de vida completo de tenants; y es el dueño del Context Plane.

Corre como daemon `systemd` en el host Ubuntu, fuera de Kubernetes, con acceso privilegiado directo a todos los planos del sistema.

### 3.2 Posición en el Stack

```
Ubuntu Linux (host)
    │
    ├── systemd
    │     └── bos.service  ← AQUÍ corre el bos
    │
    └── Kubernetes
          └── Namespaces (creados y gestionados por bos)
                └── Pods (fichas instaladas por bos)
```

El bos actúa **sobre** Ubuntu y **sobre** Kubernetes. No está dentro de Kubernetes. Es el soberano que lo gestiona.

### 3.3 Responsabilidades

**Ciclo de vida de tenants — Saga de 7 pasos con compensación:**

```
bosctl deploy <seed.yml>
      │
      ├── Paso 1: Crear Realm en Keycloak + SPIs custom
      ├── Paso 2: Crear Namespace en Kubernetes con labels
      ├── Paso 3: Provisionar bases de datos en PostgreSQL
      ├── Paso 4: Crear paths de secretos en Vault (AppRole)
      ├── Paso 5: Inicializar Context Registry en Redis
      ├── Paso 6: Crear context_sessions en bkernel_db
      └── Paso 7: Instalar fichas del tenant en orden topológico
```

Cada paso tiene su compensación. Si el Paso 4 falla, los Pasos 1-3 se revierten automáticamente.

**Context Plane — Dueño y operador:**
- Crea el `dctx_id` cuando un dispositivo se registra (pre-autenticación)
- Crea el `ctx_id` cuando un usuario se autentica (post-autenticación)
- Emite el evento `context.promoted` que vincula dctx_id → ctx_id
- Invalida todos los ctx_id activos al suspender un tenant
- Expone la Context API en `:9443`

**Reconciliación:** Cada 15 minutos verifica estado declarado vs. estado real del sistema.

**Instalación de fichas:** Resuelve el DAG de dependencias entre fichas y las instala en orden topológico garantizado.

### 3.4 Context API del bos

El bos expone los siguientes endpoints en `https://0.0.0.0:9443`:

| Método | Endpoint | Acción |
|---|---|---|
| `POST` | `/api/v1/context/create` | Crea ctx_id al login del usuario |
| `POST` | `/api/v1/context/switch` | Context switching sin reautenticación |
| `DELETE` | `/api/v1/context/{ctx_id}` | Invalida ctx_id (logout) |
| `GET` | `/api/v1/context/{ctx_id}` | Lookup O(1) — usado por Kong plugin |
| `GET` | `/api/v1/context/tenant/{tenant}` | Lista ctx_id activos del tenant |
| `POST` | `/api/v1/context/tenant/{tenant}/invalidate-all` | Suspensión de tenant |

### 3.5 Comandos bosctl

```bash
# Ciclo de vida de tenants
bosctl deploy <seed.yml>              # Alta de tenant (saga 7 pasos)
bosctl product install ai --tenant=X  # Agregar producto a tenant existente
bosctl tenant suspend X               # Suspender tenant (invalida todos los ctx_id)
bosctl tenant remove X                # Eliminar tenant completo
bosctl ficha repair postgresql        # Reparar ficha

# Context Plane
bosctl context list --tenant=skull           # ctx_id activos
bosctl context inspect ctx-88291-a4f9        # Detalle completo de una sesión
bosctl context invalidate ctx-88291-a4f9     # Forzar logout de un usuario
bosctl context history --user=3397708 --days=7  # Historial de sesiones
```

### 3.6 Puertos del bos

| Puerto | Protocolo | Uso |
|---|---|---|
| `:9440` | HTTPS REST | API principal (fichas, tenants, reconciliación) |
| `:9441` | WebSocket | Streaming en tiempo real para Core UI y bosctl |
| `:9442` | HTTP | Métricas Prometheus |
| `:9443` | HTTPS REST | Context API exclusiva |

---

## 4. Modelo Jerárquico Empresarial

### 4.1 Jerarquía

```
Tenant
 └── Company (Empresa)
      └── Branch (Sucursal)
           └── Service (Servicio)
                └── Resource (Recurso)
```

| Nivel | Definición | Ejemplos reales |
|---|---|---|
| **Tenant** | Dominio administrativo soberano. Políticas, seguridad, cuotas, gobierno | `bo`, `pe`, `co`, `ar` |
| **Company** | Entidad empresarial: empresa, organización, institución | `empresaa`, `clinicab`, `retailc` |
| **Branch** | Unidad operativa: sucursal, agencia, almacén, tienda | `lpz`, `scz`, `cbba`, `oru` |
| **Service** | Capacidad funcional expuesta | `website`, `erp`, `pos`, `api`, `ecommerce` |
| **Resource** | Activo administrado por SBOS | documentos, imágenes, datasets, apps |

### 4.2 Context ID (CTX)

El Context ID es la unidad universal de aislamiento en SBOS. Todo recurso, log, request, registro de base de datos y operación de storage está asociado a un CTX.

**Formato legible:**
```
{tenant}.{empresa}.{sucursal}.{servicio}
bo.empresaa.lpz.website
bo.clinicab.scz.pos
```

**Representación interna (inmutable):**
```
ctx_93af7812
```

### 4.3 Árbol de Contextos por Usuario

Un usuario puede tener múltiples contextos autorizados y cambiar entre ellos sin reautenticarse:

```
usuario 3397708 (Juan García)
├── skull/maya/lapaz/pos23    ← contexto activo
├── skull/maya/lapaz/pos24
├── skull/maya/santacruz/pos2
├── skull/inka/lapaz/pos7
└── skull/admin/global
```

Cada cambio de contexto genera un nuevo `ctx_id`. El anterior queda preservado en el audit trail como `status='switched'`.

### 4.4 Dominios por Servicio

```
pos.*          → Punto de venta, turno, caja, pagos
facturacion.*  → SFE/SIAT Bolivia, emisión, contingencia
inventario.*   → Stock, productos, movimientos
website.*      → Motor web institucional por tenant/empresa/sucursal
ecommerce.*    → Carrito, checkout, integración ERP
crm.*          → Clientes, oportunidades, seguimiento
reportes.*     → Analítica, dashboards, exportaciones
```

---

## 5. Context Plane — Plano de Contexto Distribuido

### 5.1 El Problema que Resuelve

```
Ubuntu sabe qué máquina existe.
Kubernetes sabe qué pod corre.
Keycloak sabe quién es el usuario.
SBOS sabe qué significa todo eso junto.
```

Sin el Context Plane, cada componente ve una fracción del estado real. Con él, cualquier servicio del stack sabe en todo momento: para qué tenant opera, en qué empresa, en qué sucursal, en qué POS, con qué usuario, en qué nodo físico.

Eso transforma **logs en auditorías**, **errores en incidentes rastreables**, y **autorizaciones en decisiones con contexto empresarial completo**.

### 5.2 Filosofía de Capas

```
Ubuntu (Hardware Abstraction Layer)
    ↓  aporta: IP, hostname, MAC, nodo físico, filesystem

Kubernetes (Distributed Execution Engine)
    ↓  aporta: pod, namespace, labels, deployment, cluster

Keycloak (Identity Provider)
    ↓  aporta: usuario, roles, claims, sesión, permisos

bos IAM Installer (Sovereign Control Plane)
    ↓  aporta: provisionamiento, ciclo de vida tenant,
              inicialización/destrucción de Context Sessions,
              Context Registry — RESPONSABLE DEL CONTEXT PLANE

SBOS Context Plane (capa transversal activada por bos)
    ↓  aporta: tenant, empresa, sucursal, POS, ctx_id,
              trazabilidad, auditoría, correlación, semántica

Aplicaciones / Fichas / POS / ERP / Servicios
```

| Capa | Entiende | NO entiende |
|---|---|---|
| Ubuntu | Máquinas, procesos, red | Tenants, empresas, POS |
| Kubernetes | Pods, namespaces, labels | Qué empresa representa un pod |
| Keycloak | Usuarios, roles, sesiones | Dónde opera el usuario ahora mismo |
| **bos IAM Installer** | **Ciclo de vida completo: infraestructura + contexto** | Scheduling, networking, container orchestration |
| **SBOS Context Plane** | **Semántica empresarial distribuida en tiempo real** | Aprovisionamiento inicial (ese es el bos) |

### 5.3 Los Dos Identificadores de Contexto

**`dctx_id` — Device Context ID (pre-autenticación):**

Cuando un dispositivo Fedora arranca y banexus se activa, el bos crea automáticamente un `dctx_id`. Este identificador registra toda la actividad del dispositivo antes de que el usuario se autentique. El usuario no sabe que existe.

```json
{
  "dctx_id": "dctx-device-991",
  "device_id": "DEVICE-991",
  "hostname": "caja-lpz-23",
  "ip": "10.0.0.55",
  "mac": "00:1A:2B:3C:4D:5E",
  "nodo_k8s": "node-02",
  "tenant": "skull",
  "status": "pre-auth",
  "bitmask": "0x0000000000000000",
  "usuario": null
}
```

**`ctx_id` — Context Session ID (post-autenticación):**

Cuando el usuario se autentica, bAuth evalúa los tres dominios y calcula el BitMask. El bos eleva el `dctx_id` a `ctx_id` mediante el evento `context.promoted`, vinculando retroactivamente toda la historia pre-autenticación al usuario identificado.

```json
{
  "ctx_id": "ctx-88291-a4f9",

  "tenant":     "skull",
  "empresa":    "maya",
  "sucursal":   "lapaz",
  "pos_logico": "POS-23",

  "user_id":    "3397708",
  "session_kc": "kc-sess-7fab12",

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

### 5.4 Ciclo de Vida Completo de una Sesión

```
T+0     Dispositivo Fedora arranca
         banexus se activa (systemd --user)
         bos crea dctx_id → registra dispositivo
         Estado: pre-auth | bitmask: 0x00 | usuario: null
         El dispositivo puede usar apps locales (YouTube, LibreOffice)
         NO puede: chapas, cajón POS, Tryton, Saleor

T+N     Usuario presenta credencial (QR / NFC / huella / contraseña)
         banexus intercepta via udev ANTES que el OS vea el input
         Evento: WebSocket mTLS → bhnexus → bAuth (Unix socket)

T+N+5ms bAuth evalúa los 3 dominios simultáneamente:
          Lógico:     apps permitidas, red autorizada, LoA requerido
          Físico:     zonas autorizadas, horario laboral, hardware habilitado
          Financiero: límites de monto, SoD, si requiere doble firma
          Resultado: BitMask de 64 bits

T+N+8ms bos recibe el BitMask → crea Context Session → genera ctx_id
         Emite evento: context.promoted
         dctx_id vinculado a ctx_id (historia pre-auth accesible)
         ctx_id almacenado: Redis (O(1) lookup) + bkernel_db (audit trail)

T+N+15ms Capacidades activadas:
          Chapa zona ventas: OPEN_RELAY emitido por bhnexus
          Apps habilitadas: JWT con BitMask inyectado
          Cajón POS: banexus activa actuador serial/GPIO

T+op    Cada acción del usuario:
         ctx_id propagado como OTel Baggage W3C en todos los requests
         bKernel registra en audit_events con ctx_id como hilo conductor

T+fin   Usuario cierra sesión / fin de turno / timeout KC
         bos invalida ctx_id → Redis TTL a cero
         BitMask a cero: chapas bloqueadas, apps bloqueadas, cajón bloqueado
         Dispositivo vuelve a estado pre-auth
         context_sessions preservada en bkernel_db para auditoría perpetua
```

### 5.5 El Evento context.promoted

El momento en que el `dctx_id` anónimo se convierte en `ctx_id` autenticado es el evento **`context.promoted`**. Crítico para trazabilidad forense:

```json
{
  "event": "context.promoted",
  "timestamp": "2026-05-20T14:32:00.847Z",

  "dctx_id_anterior": "dctx-device-991",
  "ctx_id_nuevo":     "ctx-88291-a4f9",

  "usuario":       "3397708",
  "metodo_auth":   "NFC_MIFARE_DESFIRE",
  "loa_alcanzado": 2,
  "bitmask":       "0x00000000008C87FF",

  "actividad_pre_auth_preservada": true,
  "duracion_pre_auth_segundos":    22605
}
```

Permite responder: *"¿Qué hizo este dispositivo antes de que alguien se autenticara?"* — dato crítico para investigaciones de seguridad y auditorías ISO 27001.

### 5.6 Propagación via OTel Baggage + W3C Trace Context

La propagación del contexto sigue el estándar **OpenTelemetry Baggage + W3C Trace Context**. Kong inyecta dos headers complementarios en cada request saliente:

```
traceparent: 00-{trace_id_32hex}-{parent_id_16hex}-01   ← W3C Trace Context
baggage: ctx.id=ctx-88291-a4f9,tenant.id=skull,empresa.id=maya,
         sucursal.id=lapaz,pos.id=POS-23,user.id=3397708
```

El **OTel Collector** (con Baggage Processor activo) extrae automáticamente `tenant.id`, `empresa.id`, `pos.id` y `ctx.id` como atributos en todos los spans y logs — sin modificar el código de las aplicaciones. **Cero invasión** sobre el plano de observabilidad.

| Canal | Mecanismo de propagación |
|---|---|
| APIs REST (Kong) | Header `baggage` + `traceparent` (W3C) |
| WAL → bKernel | Campo `ctx_id` en el evento CDC |
| WebSocket (Centrifugo) | Metadato del canal de sesión |
| Logs (Loki) | Atributo `ctx_id` vía OTel Baggage Processor |
| Auditoría (bkernel_db.audit_events) | Columna `ctx_id` en cada registro |
| bCompass workflows | Atributo de contexto de la ruta |
| bSearch | Campo `tenant_ctx` en el documento indexado |
| biedata (SIAT/bancos) | ctx_id adjunto a toda operación fiscal |

### 5.7 Context Registry Distribuido

| Componente | Almacenamiento | Propósito |
|---|---|---|
| ctx_id → datos completos | Redis DB1 (TTL = sesión KC) | Lookup O(1) en tiempo real por Kong |
| Árbol de contextos del usuario | bkernel_db.context_sessions | Historial, auditoría, time-travel |
| Historial de context switches | bkernel_db.context_sessions | Trazabilidad ISO 27001 A.8.15 |

**Flujo de lookup en cada request:**

```
Request llega a Kong → baggage: ctx.id=ctx-88291-a4f9
    ↓
Kong Plugin SBOS-Context extrae ctx_id
    ↓
Redis GET ctx:skull:ctx-88291-a4f9    (lookup O(1))
    ↓
¿Encontrado y TTL > 0?
  SÍ → adjunta contexto completo como headers internos
  NO → HTTP 401 + evento context.invalid emitido vía bKernel
```

### 5.8 Modelo de Datos — context_sessions

```sql
CREATE TABLE context_sessions (
    ctx_id          VARCHAR(64)  PRIMARY KEY,
    user_id         VARCHAR(128) NOT NULL,
    kc_session_id   VARCHAR(128) NOT NULL,

    tenant          VARCHAR(64)  NOT NULL,
    empresa         VARCHAR(64),
    sucursal        VARCHAR(64),
    pos_logico      VARCHAR(64),
    device_id       VARCHAR(128),

    pod             VARCHAR(128),
    namespace       VARCHAR(64),
    node            VARCHAR(64),
    cluster         VARCHAR(64),
    vps             VARCHAR(64),
    geo             VARCHAR(128),

    traceparent     VARCHAR(128),   -- W3C traceparent al momento de creación

    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ  NOT NULL,
    switched_at     TIMESTAMPTZ,
    invalidated_at  TIMESTAMPTZ,
    status          VARCHAR(20)  NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','switched','expired','invalid'))

) PARTITION BY RANGE (created_at);

CREATE INDEX idx_ctx_sessions_user    ON context_sessions (user_id, status);
CREATE INDEX idx_ctx_sessions_tenant  ON context_sessions (tenant, empresa, status);
CREATE INDEX idx_ctx_sessions_active  ON context_sessions (expires_at) WHERE status = 'active';
```

### 5.9 Time Travel Observability

bkernel_db.context_sessions + audit_events permiten reconstruir el estado completo del sistema en cualquier instante pasado — cumplimiento ISO 27001:2022 A.8.15:

```sql
-- ¿Qué contextos estaban activos el 20 de mayo a las 14:47?
SELECT ctx_id, user_id, tenant, empresa, sucursal, pos_logico, pod, node
FROM context_sessions
WHERE tenant = 'skull'
  AND status = 'active'
  AND created_at <= '2026-05-20T14:47:00Z'
  AND (expires_at > '2026-05-20T14:47:00Z' OR switched_at > '2026-05-20T14:47:00Z')
ORDER BY created_at;
```

---

## 6. Identity Plane — Identidad y Autorización

### 6.1 Keycloak — El Único IdP

Keycloak 26.x es el único proveedor de identidad del SBOS. Sin excepciones. Es el Principio 1 del ecosistema.

**Modelo de multi-tenancy:** una única instancia Keycloak con un **realm por tenant** de nivel superior.

```
Keycloak Instance (única)
 └── Realm: SBOS (admin)
      └── Realm: tenant-bo
           └── Client: empresaa
           └── Client: clinicab
      └── Realm: tenant-pe
           └── Client: ...
```

**Capacidades:**
- SSO via OIDC/OAuth 2.0/SAML 2.0 para todas las apps del stack
- 16 métodos de autenticación: contraseña, OTP, passkey, WebAuthn, QR, NFC, biométrico
- Multi-factor authentication (MFA) obligatorio para roles administrativos
- FAPI 2.0 + DPoP para operaciones financieras de alto valor
- Passkeys (KC 26.4+) para autenticación sin contraseña
- Federación de identidades: LDAP / Active Directory

**5 SPIs custom desarrollados por SKULL:**
- `BosRolTemplateSPI` — sincronización de roles con bAuth
- `FinancialDomainSPI` — evaluación de dominio financiero en el flujo de auth
- `PhysicalDomainSPI` — evaluación de dominio físico
- `LogicalDomainSPI` — evaluación de dominio lógico
- `TemporalContextSPI` — contexto temporal (horarios, turnos)

### 6.2 El JWT que Llega a Cada Servicio

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
  "ctx_id":  "ctx-88291-a4f9",
  "tenant":  "skull"
}
```

### 6.3 BitMask de 64 Bits

El BitMask es el resultado de la evaluación simultánea de los tres dominios. Permite verificar permisos en O(1) sin consultar base de datos en cada request.

```
Bits  0-9:   ERPMask       (permisos Tryton: ventas, compras, contabilidad...)
Bits 10-19:  VDIMask       (zonas físicas, hardware habilitado)
Bits 20-29:  AppsMask      (CRM, RRHH, ecommerce, chat...)
Bits 30-39:  FinancialMask (límites, SoD, doble firma)
Bits 40-63:  Reserved      (expansión futura)
```

**Ejemplo real — cajero de turno, sucursal La Paz:**

```
Bit 10: SESSION_VALID    = 1  → sesión activa y verificada
Bit 11: SHELL_UNLOCK     = 1  → Fedora desbloqueado
Bit 12: APP_TRYTON       = 1  → puede abrir ERP
Bit 14: APP_SALEOR       = 1  → puede operar ventas
Bit 15: DRAWER_OPEN      = 1  → puede abrir cajón POS (relé físico)
Bit 16: DOOR_ZONE_A      = 1  → puede abrir chapas Zona Ventas
Bit 17: DOOR_ZONE_B      = 0  → NO puede entrar al almacén
Bit 18: DOOR_ZONE_C      = 0  → NO puede entrar a zona restringida
Bit 21: NETWORK_EXTERNAL = 1  → puede navegar internet
Bit 23: ADMIN_PANEL      = 0  → NO es administrador
```

### 6.4 Headers que Kong Inyecta en Cada Request

```
X-SBOS-CtxId:     ctx-88291-a4f9
X-SBOS-Tenant:    skull
X-SBOS-Empresa:   maya
X-SBOS-Sucursal:  lapaz
X-SBOS-User:      3397708
X-SBOS-BitMask:   0x00000000000A3F21
```

Las aplicaciones no analizan el Baggage OTel directamente. Kong ya hizo el trabajo y lo entrega como headers HTTP estándar.

---

## 7. Data Plane — Persistencia y Eventos

### 7.1 PostgreSQL 18.4 — La Única Base de Datos Relacional

PostgreSQL 18.4 con Patroni HA es la única BD relacional del SBOS (ADR-024). Es obligatoria porque el bus de eventos del sistema **es su Write-Ahead Log (WAL)**.

**Alta disponibilidad:** Patroni 3 nodos, failover automático en <30s. Versión canónica: **18.4** (ADR-017).

**Bases de datos predefinidas** (creadas en el alta de cada tenant):

| Base de datos | Propietario | Contenido |
|---|---|---|
| `keycloak_db` | Keycloak | Realms, usuarios, roles, sesiones |
| `kong_db` | Kong | Rutas, plugins, consumers |
| `bkernel_db` | bKernel | audit_events, context_sessions, DLQ |
| `bauth_db` | bAuth | RolTemplates, BitMask cache, dominios |
| `bcompass_db` | bCompass | Rutas IA, sugerencias HITL, conversaciones |
| `biedata_db` | biedata | Operaciones fiscales, códigos de autorización |
| `bsearch_db` | bSearch | Esquemas de búsqueda, colecciones |
| `tryton_db` | Tryton ERP | Toda la operación empresarial |
| `vault_db` | Vault | Estado del gestor de secretos |
| `{app}_db` | Fichas propias | Una BD por ficha instalada |

**Regla absoluta de aislamiento:**

```sql
-- ✅ SIEMPRE: tenant_id en el WHERE
SELECT * FROM pos_ventas WHERE id = $1 AND tenant_id = $2;

-- ❌ VETADO: query sin aislamiento de tenant
SELECT * FROM pos_ventas WHERE id = $1;
```

**Extensiones habilitadas:**
- `pg_logical` — replicación lógica para el WAL/CDC
- `pgvector` — búsqueda semántica vectorial
- `pg_partman` — particionado automático de tablas históricas
- `pgcrypto` — cifrado a nivel de campo

### 7.2 Redis 8.6.2 — Cache, Contexto y Streams

Redis opera en tres roles simultáneos, en bases de datos lógicas separadas. Versión canónica: **8.6.2** (ADR-017).

| DB | Rol | Contenido |
|---|---|---|
| **DB0** | Cache general y sesiones | Caché de catálogos, sesiones de usuario |
| **DB1** | Context Registry | `ctx_id` activos con TTL = sesión KC |
| **DB2** | Pub/Sub y Streams | `biedata:invoices:*`, `ai:embed_queue`, `bcompass:agent_requests` |

### 7.3 Vector Database — pgvector + Qdrant (Concepto Futuro — Fase 4)

> **Estado:** Planeado para Fase 4 (Semanas 29-36). No activo en v1.0. La búsqueda actual de bSearch es PostgreSQL 18+ nativo (GIN, tsvector, pg_trgm).

La búsqueda semántica vectorial de SBOS se implementará en dos capas complementarias:

**pgvector (PostgreSQL):** Extensión de vectores integrada en PostgreSQL 18.4. Tipo `HALFVEC` para eficiencia de memoria. Hash-particionado por `tenant_id`. Índices HNSW para búsqueda aproximada eficiente. Es el punto de partida de la búsqueda vectorial en bSearch.

**Qdrant:** Backend de vectores externo para cuando los índices HNSW de pgvector superen la RAM disponible (umbral: >80% de RAM en índices). Colecciones aisladas por realm (tenant). Migración programática sin downtime cuando se supera el umbral. Ver §15.5 para criterios de migración.

### 7.4 El WAL como Bus de Eventos Nativo

El WAL de PostgreSQL es el bus de eventos del SBOS. No hay broker externo (no Kafka, no RabbitMQ). La integración entre aplicaciones ocurre de forma natural cuando bKernel detecta cambios en el WAL y ejecuta las reglas YAML correspondientes.

```
PostgreSQL (wal_level=logical)
    │
    └── Slot de replicación lógica (pgoutput)
         │
         └── bKernel (Rust, <50μs latencia)
              │
              ├── Rule Engine (YAML declarativo)
              │    ├── MDM Rules → sincroniza entidades entre BDs
              │    ├── Fiscal Rules → publica Redis Stream biedata:*
              │    ├── Context Rules → actualiza context_sessions
              │    └── Embedding Rules → encola ai:embed_queue
              │
              └── Dead Letter Queue (DLQ) → reintentos exponenciales
```

---

## 8. Web Platform — Sitios por Tenant, Empresa y Sucursal

### 8.1 Principio Fundamental

> **Los sitios web son proyecciones de datos empresariales. No son sistemas independientes.**

Los sitios web en SBOS exponen información institucional, catálogos, ecommerce e información del ERP de forma segura. Cada sitio es una vista del contexto empresarial de su CTX. El inventario nunca se duplica: todo stock proviene del ERP en tiempo real.

### 8.2 Jerarquía de Dominios Web

Cada nivel del modelo jerárquico tiene su propio subdominio, aislado por CTX:

**Nivel Empresa:**
```
www.empresaa.com          → CTX: bo.empresaa.global.website
api.empresaa.com          → CTX: bo.empresaa.global.api
erp.empresaa.com          → CTX: bo.empresaa.global.erp
```

**Nivel Sucursal:**
```
lpz.empresaa.com          → CTX: bo.empresaa.lpz.website
scz.empresaa.com          → CTX: bo.empresaa.scz.website
cbba.empresaa.com         → CTX: bo.empresaa.cbba.website
```

**Nivel Servicio dentro de Sucursal:**
```
info.lpz.empresaa.com     → CTX: bo.empresaa.lpz.info
ventas.lpz.empresaa.com   → CTX: bo.empresaa.lpz.ventas
api.lpz.empresaa.com      → CTX: bo.empresaa.lpz.api
tienda.lpz.empresaa.com   → CTX: bo.empresaa.lpz.ecommerce
```

### 8.3 Routing Table — Domain Resolver

```yaml
# Kong Domain Resolver — entrada por dominio → CTX
domain: info.lpz.empresaa.com
  tenant_id:  bo
  company_id: empresaa
  branch_id:  lpz
  service_id: info
  ctx_id:     ctx_93af7812

domain: tienda.scz.clinicab.com
  tenant_id:  bo
  company_id: clinicab
  branch_id:  scz
  service_id: ecommerce
  ctx_id:     ctx_f7b2c901
```

Cada dominio se vincula a un CTX. El CTX determina qué datos, qué configuración y qué recursos se sirven.

### 8.4 Website Engine — Un Cluster para Todos

Un único Website Engine cluster sirve a **todas** las organizaciones de todos los tenants. No se deploya un pod por empresa ni por sucursal.

```
Internet
    │
DNS → Load Balancer → NGINX Ingress
    │
Kong API Gateway
    │ (extrae ctx_id por dominio)
Domain Resolver + CTX Resolver
    │
Website Engine Cluster (pods escalables)
    ├── Pod
    ├── Pod
    └── Pod  ← sirve miles de dominios simultáneamente
         │
    ERP APIs (Tryton) ← datos en tiempo real
```

### 8.5 Recursos por Nivel

**Nivel Empresa:**
- Logo corporativo, colores, tipografía, brand guide
- Documentos corporativos, presentaciones institucionales

**Nivel Sucursal:**
- Banners locales, promociones de la sucursal
- Fotografías locales, información de contacto
- Horarios, mapa de ubicación

**Nivel Servicio/Ecommerce:**
- Catálogo de productos (sincronizado desde ERP en tiempo real)
- Precios por lista (segmentación por sucursal)
- Stock disponible (directo desde inventario ERP, nunca duplicado)
- Carrito, checkout, integración con pasarelas de pago

### 8.6 Recursos — Resource Manager

El Resource Manager es el servicio central para todos los activos digitales. La metadata en PostgreSQL es la fuente de verdad; el archivo en MinIO es solo el storage.

```yaml
resource_id:    "uuid-v4"
tenant_id:      "bo"
company_id:     "empresaa"
branch_id:      "lpz"
resource_type:  "Image"          # Image | Video | Document | Theme | Dataset...
version:        "3"
checksum:       "sha256:..."
storage_uri:    "bo/empresaa/lpz/website/images/banner-verano.webp"
created_at:     "2026-06-12T10:00:00Z"
updated_at:     "2026-06-12T14:00:00Z"
```

---

## 9. Storage Plane — Gestión de Recursos

### 9.1 Principio

> **Los archivos NO son la fuente de verdad. Los metadatos son la fuente de verdad.**

Los archivos son bytes almacenados en object storage. El sistema los gestiona a través de metadatos en PostgreSQL. El `storage_uri` es un puntero, no la verdad.

### 9.2 Backend S3-Compatible

MinIO en modo distribuido es el backend recomendado. Características clave:

- Compatibilidad total con la API de Amazon S3
- Erasure coding: tolera hasta N/2 fallos de disco simultáneos
- Alta disponibilidad nativa en Kubernetes via MinIO Operator
- Versionado y lifecycle policies
- Cifrado en tránsito (TLS) y en reposo (SSE-S3 / SSE-KMS)
- Sin vendor lock-in: migración a AWS S3 / GCS sin cambio de código

### 9.3 Organización Lógica del Storage

```
{tenant}/
 └── {empresa}/
      └── {sucursal}/
           └── {servicio}/
                └── {tipo_recurso}/
                     └── {resource_id}.{ext}
```

**Ejemplo:**
```
bo/empresaa/lpz/website/images/banner-verano-2026.webp
bo/empresaa/lpz/erp/documents/factura-001234.pdf
bo/clinicab/scz/pos/receipts/ticket-v2026-09871.pdf
```

Esta estructura es un namespace lógico. No corresponde necesariamente a la estructura física en disco.

---

## 10. Los Ocho Daemons Soberanos

Los daemons son procesos `systemd` que corren en el host Ubuntu, fuera de Kubernetes, con acceso privilegiado. **HTTP entre daemons está vetado** (SBOS-050 P9). Toda comunicación daemon↔daemon usa WebSocket mTLS o Unix socket (`/run/bos/<daemon>.sock`). Stack: **Go 1.26+** (bos, bAuth, bCompass, bSearch, bhnexus/banexus) · **Rust 1.85+** (bKernel, biedata).

### 10.1 bos — SBOS IAM Installer (Go)

**Propósito:** Control Plane soberano. El `systemd` del SBOS empresarial.
**Responsabilidades:** Instalar/reparar/eliminar fichas. Alta/suspensión/eliminación de tenants. Dueño del Context Plane. Reconciliación cada 15 minutos.
**Puertos:** `:9440` API REST · `:9441` WebSocket · `:9442` Métricas · `:9443` Context API

### 10.2 bKernel — SBOS Data Kernel (Rust)

**Propósito:** El kernel del plano de datos. Escucha el WAL y propaga cambios entre apps. Cero invasión.
**Responsabilidades:** CDC Parser del WAL (<50μs latencia). Rule Engine YAML. MDM entre apps. Persiste audit_events y context_sessions. Publica en Redis Streams para biedata.
**Arquitectura interna:**
```
WAL Stream (slot PG, pgoutput)
    ↓
CDC Parser (Rust — latencia <50μs, sin GC)
    ↓
Rule Engine (evalúa rules/*.yml en caliente)
    ├── MDM Rules → sincroniza entidades entre BDs
    ├── Fiscal Trigger Rules → publica biedata:invoices:BO
    ├── Context Rules → actualiza context_sessions
    └── Embedding Rules → encola ai:embed_queue
    ↓
DLQ → reintentos exponenciales + alerta Prometheus
```
**Puertos:** `:9460` Métricas · `:9461` Healthcheck · `/run/bos/bkernel-mcp.sock` (bCompass)

### 10.3 biedata — SBOS Data Integration (Rust)

**Propósito:** Aduana soberana de datos. **Único daemon autorizado a realizar conexiones HTTP salientes al exterior.**
**Responsabilidades:** Exportar a APIs externas (SIAT Bolivia, AFIP Argentina, SAT México, bancos). Importar archivos Excel/CSV via inotify + calamine. Cada integración implementa 6 fases: VALIDATE → AUTHENTICATE → EXTRACT → TRANSFORM → LOAD → AUDIT.
**Activación:** Solo por eventos (Redis Stream de bKernel, file_watch, cron, bosctl). No tiene API REST pública.
**Puertos:** `:9470` Métricas · `:9471` Healthcheck

**Flujo fiscal completo SIAT Bolivia:**
```
① Tryton aprueba factura → state='posted'
② WAL: UPDATE account_invoice SET state='posted'
③ bKernel detecta → evalúa invoice_tributaria_trigger.yml
④ bKernel publica → Redis Stream: biedata:invoices:BO
⑤ biedata ejecuta caja boxes/export/facturas_siat/
   VALIDATE: credenciales en Vault
   AUTHENTICATE: certificado digital mTLS SIAT (desde Vault)
   EXTRACT: SELECT factura + cliente de PostgreSQL
   TRANSFORM: XML firmado según XSD oficial del SIN
   LOAD: POST mTLS al endpoint del SIAT
   AUDIT: registra código de autorización en biedata_db
⑥ bKernel detecta escritura biedata_db → actualiza tryton_db
⑦ Tryton muestra factura autorizada con número oficial
```

### 10.4 bAuth — SBOS Auth Enforce (Go)

**Propósito:** Plano de identidad. Evalúa los tres dominios y emite el BitMask de 64 bits.
**Responsabilidades:** Evaluar dominio lógico + físico + financiero por cada solicitud. Calcular BitMask. Sincronizar RolTemplates KC ↔ Tryton. Cache de BitMask en Redis (~5ms hit, ~15ms miss).
**Puertos:** `:9450` API REST · `:9451` Métricas · `/run/bos/bauth.sock` (bhnexus) · `/run/bos/bauth-mcp.sock` (bCompass)

### 10.5 bCompass — SBOS AI Tools (Go)

**Propósito:** Route Engine de inteligencia soberana. Implementa HITL (Human-In-The-Loop) para decisiones de alto impacto.

**Principio fundamental:**
```
DATOS → bCompass OBSERVA → ANALIZA → ORIENTA → HUMANO DECIDE → SISTEMA EJECUTA
```
Nunca autónomo en decisiones de alto impacto.

**Cuatro tipos de rutas:**

| Tipo | Propósito | Ejemplo |
|---|---|---|
| `analyst` | Análisis estadístico → sugerencias pendientes de aprobación | Detectar reglas bKernel inactivas >90 días |
| `agent` | Agente conversacional con Ollama local + RAG | Empleado consulta vacaciones disponibles |
| `flow` | Workflow: queries + LLM + Approval Gates + notificaciones | Reporte mensual de ventas en Excel a gerencia |
| `report` | Reportes periódicos automáticos | Estado semanal de integraciones biedata |

**Governance levels:**

```
Governance 1 → Sin Approval Gate → ejecuta directo
               Ejemplo: generar reporte, responder pregunta
Governance 2 → Approval Gate — rol CONFIG
               Ejemplo: sugerir desactivar una regla bKernel
Governance 3 → Approval Gate — rol OWNER
               Ejemplo: cambio de configuración del stack, impacto financiero alto
```

**Fronteras inviolables:** Solo lectura sobre el stack (SELECT). LLM es local (Ollama) — ningún dato sale del servidor. Agent solo accede datos del usuario que pregunta (`own_user_only`).

**Puertos:** `:9480` API REST · `:9481` Métricas · MCP Unix sockets: consume de bKernel, bAuth, bSearch

### 10.6 bSearch — SBOS Motor de Búsqueda Soberano (Go)

**Propósito:** Motor de búsqueda soberano. Usa exclusivamente **PostgreSQL 18+ nativo** (GIN, tsvector, pg_trgm). Sin dependencias externas de búsqueda (no Typesense, no Elasticsearch). Solo WebSocket `wss://` — sin API REST.
**Responsabilidades:** Indexar datos del WAL vía Redis Stream `bkernel:index_queue`. Búsqueda full-text con GIN, tsvector y pg_trgm. Schema Discoverer (analiza nuevas apps automáticamente). Search Learning Engine (aprende sinónimos del negocio). Colecciones aisladas por tenant.
**Vector search (Fase 4 futura):** pgvector como primer paso, Qdrant cuando pgvector supere umbral RAM. Ver §7.3.
**Puertos:** `:9493` WebSocket (wss://) · `:9491` Métricas · `/run/bos/bsearch-mcp.sock` (bCompass)

### 10.7 bhnexus + banexus — Par Nexus Soberano (Go)

Son una **unidad compuesta** — no dos daemons separados. Juntos forman el Sovereign Connectivity Broker.

**bhnexus** (host Ubuntu):
- Acepta conexiones WebSocket mTLS de todos los banexus (hasta 10.000 concurrentes) en `:9444`
- Cache de BitMask en memoria: responde sin consultar bAuth en cache hit (~5ms)
- Cache miss: consulta bAuth via `/run/bos/bauth.sock` (~15ms total)
- Emite `actuator_commands` hacia banexus: `OPEN_RELAY`, `DENY_RELAY`, `CAPTURE_FRAME`

**banexus** (nodo Fedora — Edge Sentinel):
- Corre como `systemd --user` en cada endpoint Fedora del cliente
- **Sin puertos TCP entrantes** — es cliente puro
- Intercepta hardware via `udev + libusb` **ANTES** de que el OS procese el input
- Conecta de forma saliente a bhnexus en `:9444` (WebSocket mTLS monogámico)
- Actúa sobre actuadores locales: relé (cajón POS, chapa), pantalla, impresora

**Topología invariable:**
```
banexus (Fedora) ──WSS/mTLS saliente──► bhnexus :9444 (Ubuntu)
                                              │
                                   /run/bos/bauth.sock
                                              │
                                        bAuth (BitMask)

VETADO:
  ✗ banexus → bAuth directamente
  ✗ banexus → Keycloak directamente
  ✗ dispositivo físico → bhnexus directamente
  ✗ bhnexus → HTTP externo
```

**Puertos bhnexus:** `:9444` WSS/mTLS · `:9445` Métricas. banexus: sin puertos TCP.

---

## 11. Backend Services — Go y Rust

### 11.1 Arquitectura del Servidor

```
Kong API Gateway
    │ recibe JSON-RPC del exterior
    │ valida JWT + ctx_id
    │ traduce a gRPC hacia servicio Go
    │
    ↓ gRPC (HTTP/2 + Protobuf)

Servicios Go (lógica de negocio, APIs, coordinación)
    ├── bos-service
    ├── bauth-service
    ├── pos-service
    ├── facturacion-service
    ├── inventario-service
    └── website-service
    │
    ↓ WAL (pgoutput, <50μs)

Capa Rust (rendimiento máximo, cero GC)
    ├── bKernel → CDC Parser, Rule Engine, propagación
    └── biedata → Integración SIAT, bancos, APIs externas
```

### 11.2 Por Qué Go para los Servicios

| Capacidad | Relevancia para SBOS |
|---|---|
| Goroutines | bhnexus maneja 10.000+ conexiones WebSocket sin threads del OS |
| Binarios estáticos | Imágenes OCI mínimas, sin runtime externo |
| Compilación rápida | Ciclos de desarrollo cortos en la fábrica de agentes |
| Ecosistema cloud-native | Kubernetes, Prometheus, OTel, Vault, gRPC — librerías maduras |
| Legibilidad | Código interpretable por agentes IA de la fábrica |

### 11.3 Por Qué Rust en el Kernel de Datos

| Capacidad | Relevancia para SBOS |
|---|---|
| Sin GC | El WAL requiere procesamiento en <50μs. Un GC pause rompe esa garantía |
| Seguridad de memoria | bKernel maneja datos de múltiples tenants: buffer overflow = fuga entre clientes |
| Zero-cost abstractions | Código de alto nivel que produce binarios eficientes como C |
| `unsafe` controlado | Solo para FFI, siempre documentado y aprobado |

### 11.4 Estructura de un Servicio Go (Capas DDD)

```
src/internal/{servicio}/
├── domain/          ← Núcleo. No importa nada externo.
│   ├── model.go       Entidades, Value Objects, reglas de negocio
│   ├── repository.go  Interfaces — contratos que la infra implementa
│   ├── service.go     Domain services entre agregados
│   └── errors.go      Tipos de error de dominio
├── application/     ← Orquesta el dominio. Conoce repositorios.
│   ├── commands/      Un archivo por command handler
│   └── queries/       Un archivo por query handler
├── infrastructure/  ← Implementaciones concretas
│   ├── postgres/      Implementa interfaces de domain
│   ├── grpc/          Clientes gRPC hacia otros servicios
│   └── redis/
└── api/grpc/
    ├── server.go      Configuración gRPC + interceptors
    ├── handler.go     Implementa la interfaz generada por protoc
    └── mapper.go      Convierte tipos proto ↔ tipos de dominio
```

**Regla de dependencias — flujo unidireccional:**
```
api/grpc → application → domain
infrastructure → domain (implementa interfaces, nunca al revés)
domain NO importa nada de las otras capas
```

---

## 12. Contratos gRPC y API Pública JSON-RPC

### 12.1 El `.proto` es la Fuente de Verdad

> **Antes de escribir una sola línea de Go o Rust, se escribe el `.proto`.**

El archivo `.proto` es el único artefacto que define qué hace un servicio, qué acepta y qué retorna. No el código. No la documentación.

### 12.2 El RequestContext — Obligatorio en Todo Request

```protobuf
message RequestContext {
  string ctx_id          = 1;  // Obligatorio siempre
  string tenant_id       = 2;  // Obligatorio siempre
  string correlation_id  = 3;  // UUID del request original
  string user_id         = 4;  // Obligatorio siempre
  string empresa_id      = 5;
  string sucursal_id     = 6;
  string pos_id          = 7;
  string bitmask         = 8;  // "0x00000000008C87FF"
}
```

El `RequestContext ctx = 1` es siempre el **campo número 1** en todos los messages de request. Sin excepción.

### 12.3 Tipo Money — Nunca Float

```protobuf
// BOB 45.50 → { amount_centavos: 4550, currency: "BOB" }
// Los errores de punto flotante en facturación son errores fiscales.
message Money {
  int64  amount_centavos = 1;
  string currency        = 2;  // ISO 4217: "BOB", "USD", "PEN"
}
```

### 12.4 Convención de Nombres JSON-RPC

```
{dominio}.{subdominio}.{Accion}

✅ pos.venta.CerrarVenta
✅ facturacion.sfe.EmitirFactura
✅ inventario.stock.AjustarConteo

❌ pos.venta.Create
❌ inventario.stock.Update
```

### 12.5 Flujo JSON-RPC → gRPC → Respuesta

```
POST /api/v1/rpc
{"jsonrpc":"2.0","method":"pos.venta.CerrarVenta","params":{...}}
    │
Kong API Gateway
    ├── Valida JWT → extrae tenant, user, bitmask, ctx_id
    ├── Verifica ctx_id en bos Context API (Redis O(1))
    ├── Determina servicio gRPC destino
    └── Construye request gRPC con metadata SBOS
    │
Go Service (gRPC server)
    └── Procesa → retorna gRPC response
    │
Kong convierte gRPC → JSON-RPC response
    │
{"jsonrpc":"2.0","result":{...}}
```

### 12.6 Mapeo de Errores gRPC → JSON-RPC

| Error de dominio | Código gRPC | JSON-RPC |
|---|---|---|
| Entidad no encontrada | `NotFound` | -32005 |
| Regla de negocio violada | `FailedPrecondition` | -32005 |
| BitMask insuficiente | `PermissionDenied` | -32001 |
| ctx_id inválido | `Unauthenticated` | -32002 |
| Parámetros inválidos | `InvalidArgument` | -32602 |
| Servicio externo timeout | `Unavailable` | -32004 |
| Error inesperado | `Internal` | -32603 |

---

## 13. Observabilidad Semántica

### 13.1 El Problema sin Contexto vs. con Contexto

**Sin Context Plane**, Kubernetes reporta:
```
pod/pos-api-77fa   CrashLoopBackOff   node-02
```

**Con Context Plane**, el OTel Baggage Processor enriquece ese mismo evento hasta:
```
El POS 23 ("Caja Norte") de la sucursal La Paz
del tenant skull / empresa maya,
operado por el usuario 3397708 (Juan García),
perdió conectividad a las 14:47 UTC
durante el procesamiento de la venta #V-2026-00891.
Pod: pos-api-77fa | Node: node-02 | VPS: vps-lapaz-01
trace_id: ctx-88291-a4f9-1716220847391-f3a1
```

Esa es la diferencia entre monitoreo y **observabilidad semántica**.

### 13.2 Stack de Observabilidad

| Herramienta | Rol | Versión |
|---|---|---|
| **OpenTelemetry SDK** | Instrumentación de Go y Rust. Exporta spans, métricas, logs | SDK v1.x |
| **OTel Collector** | Recibe telemetría, aplica Baggage Processor, enruta a backends | v0.100+ |
| **Prometheus** | Recolección de métricas TSDB, alertas | v3.x |
| **Grafana** | Dashboards, correlación métricas/logs/trazas | v11+ |
| **Grafana Loki** | Agregación y consulta de logs estructurados | v3.x |
| **Grafana Tempo** | Trazas distribuidas. Correlaciona con Loki y Prometheus | v2.x |

### 13.3 Los Tres Pilares con ctx_id

**Métricas (Prometheus):** Duración de requests gRPC por método y tenant. Throughput por tenant. Tasa de error por servicio. Latencia del WAL pipeline. Tamaño de la DLQ.

**Logs (Loki):** Cada log lleva `ctx_id`, `tenant_id`, `correlation_id` y `method` como campos estructurados obligatorios. Errores de servidor en `ERROR`. Violaciones de permisos en `WARN`. Formato JSON siempre.

**Trazas (Tempo):** Span por cada llamada gRPC, propagando `correlation_id` como trace root. Trazas end-to-end desde el request JSON-RPC hasta la respuesta, cruzando Kong → Go Service → PostgreSQL.

### 13.4 Que el Sistema Puede Responder en Todo Momento

El objetivo arquitectónico concreto del Context Plane + observabilidad:

```
¿Quién?        → usuario 3397708 (Juan García)
¿Desde dónde?  → POS 23 ("Caja Norte"), La Paz
¿Qué tenant?   → skull
¿Qué empresa?  → maya
¿Qué pod?      → pos-api-77fa
¿Qué nodo?     → node-02
¿Qué VPS?      → vps-lapaz-01
¿Qué región?   → Bolivia / La Paz
¿Cuándo?       → 2026-05-20T14:47:33.291Z
¿Sobre qué?    → Venta #V-2026-00891 (ERP Tryton)
¿Con qué rol?  → sales (BitMask 0x000A3F21)
¿Evidencia?    → audit_events row #8812991 (ISO 27001 A.8.15)
```

### 13.5 Alertas Críticas

| Alerta | Umbral | Severidad |
|---|---|---|
| Latencia WAL bKernel P99 | > 100ms | CRITICAL |
| Tasa de error gRPC | > 1% en 5 minutos | WARNING |
| DLQ size | > 100 eventos | WARNING |
| Redis memory | > 80% | WARNING |
| PostgreSQL replication lag | > 1 segundo | CRITICAL |
| Keycloak login failures | > 50/min por tenant | CRITICAL |
| ctx_id lookup failures | > 10/min | WARNING |

---

## 14. Seguridad y Cumplimiento Normativo

### 14.1 Controles Implementados

| Control | Implementación técnica | Estándar |
|---|---|---|
| **MFA** | Obligatorio para roles administrativos en Keycloak | ISO 27001 A.8.5 |
| **RBAC** | Jerárquico Tenant → Company → Branch → Service → Operación | NIST SP 800-53 AC-2 |
| **mTLS** | Linkerd sidecar inyectado en todos los pods. Transparente para apps | NIST SP 800-207 |
| **Cifrado en tránsito** | TLS 1.3 en Kong. mTLS en Linkerd. mTLS en bhnexus↔banexus | ISO 27017 |
| **Cifrado en reposo** | PostgreSQL pgcrypto. MinIO SSE-S3. Vault KMS | ISO 27018 |
| **Auditoría** | audit_events con ctx_id inmutable. Nunca se elimina | ISO 27001 A.8.15 |
| **Trazabilidad** | correlation_id propagado en todo el stack vía OTel Baggage | ISO 27001 A.8.16 |
| **Secretos** | HashiCorp Vault. Secrets dinámicos con TTL corto. AppRole por ficha | NIST SP 800-53 IA-5 |
| **WAF** | ModSecurity + OWASP CRS en NGINX. Bloquea SQLi, XSS, CSRF | ISO 27001 A.8.8 |
| **Admission Control** | Kyverno: políticas declarativas YAML sobre todo pod del cluster | NIST SP 800-53 CM-6 |
| **SIEM/XDR** | Wazuh como DaemonSet en todos los nodos | ISO 27001 A.8.16 |

### 14.2 Aislamiento de Tenants — Capas

| Capa | Mecanismo |
|---|---|
| **Red** | Calico NetworkPolicy default-deny en cada namespace |
| **Autenticación** | Realm Keycloak aislado por tenant |
| **Autorización** | JWT + BitMask + ctx_id verification en Kong |
| **Datos** | `tenant_id` obligatorio en toda query SQL |
| **Storage** | Namespaces lógicos en MinIO por CTX |
| **Logs/Trazas** | `tenant_id` label en todos los eventos de observabilidad |
| **Secrets** | Paths Vault aislados: `secret/tenants/{realm}/` |

### 14.3 Políticas Kyverno Activas

- Ningún pod expone `hostPort` en puertos de BD (5432, 6379)
- Ningún NodePort fuera del rango 31000-31999
- Todos los pods tienen `readinessProbe` y `livenessProbe` declarados
- Imágenes firmadas con Ed25519 del Release Plane SKULL
- Ningún pod en producción usa puertos de debug (T=8)

### 14.4 Principio Zero Trust Aplicado

> Ningún componente confía implícitamente en ningún otro, independientemente de su posición en la red.

Cada request lleva JWT + ctx_id. Kong verifica ambos. bAuth verifica el BitMask. El ctx_id se valida en Redis en O(1). La trazabilidad es completa desde el primer byte.

---

## 15. Escalamiento Vertical y Horizontal

### 15.1 Principio de Escalamiento

La arquitectura de SBOS está diseñada para escalar en ambas dimensiones **sin rediseño arquitectónico** en ningún punto. El aislamiento contextual —no físico— es lo que hace posible escalar la infraestructura compartida independientemente de la cantidad de tenants.

### 15.2 Escalamiento Vertical

Incremento de recursos por nodo: CPU, RAM, almacenamiento NVMe. No requiere cambios en la aplicación ni en la configuración. Los componentes con mayor demanda de recursos en escala vertical son PostgreSQL (más RAM para shared_buffers) y los índices HNSW de pgvector.

### 15.3 Escalamiento Horizontal

| Componente | Mecanismo | Sin redesign |
|---|---|---|
| **Servicios Go** | HPA por CPU/RPS. Stateless — escalan a cualquier cantidad de pods | ✅ |
| **Website Engine** | HPA. Un cluster sirve N dominios — escalar pods no agrega complejidad | ✅ |
| **Kong** | Horizontal con DB PostgreSQL compartida. Configuración sincronizada | ✅ |
| **Keycloak** | StatefulSet con Pod Anti-Affinity entre zonas de disponibilidad | ✅ |
| **Redis** | Redis Cluster mode: N masters + N replicas | ✅ |
| **MinIO** | Más nodos + más drives. Erasure coding se recalibra automáticamente | ✅ |
| **PostgreSQL** | Patroni: N nodos lectores para queries de solo lectura | ✅ |
| **bKernel (Rust)** | Escala vertical (más CPU/RAM por proceso). 1 instancia por cluster | ✅ |

### 15.4 Ejemplo HPA — pos-service

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: pos-service-hpa
  namespace: skull-maya
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: pos-service
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Pods
      pods:
        metric:
          name: grpc_requests_per_second
        target:
          type: AverageValue
          averageValue: 500
```

### 15.5 Umbrales de Migración — Vector DB

| Condición | Acción |
|---|---|
| RAM de índices HNSW pgvector < 60% disponible | Continuar con pgvector |
| RAM de índices HNSW pgvector 60-80% disponible | Planificar migración a Qdrant |
| RAM de índices HNSW pgvector > 80% disponible | Migrar colecciones a Qdrant sin downtime |

### 15.6 Alta Disponibilidad — Checklist de Producción

- [ ] PostgreSQL 18.4 con Patroni HA — mínimo 3 nodos, failover <30s
- [ ] Redis 8.6.2 Cluster — mínimo 3 masters + 3 replicas
- [ ] MinIO distribuido — mínimo 4 nodos, erasure coding N/2
- [ ] Keycloak StatefulSet con Pod Anti-Affinity entre AZs
- [ ] Kubernetes multinodo con pods distribuidos entre nodos y AZs
- [ ] pgBackRest PITR desde réplica (RPO <1h)
- [ ] Velero backup de manifiestos K8s y PVCs
- [ ] Bareos backup de sistema de archivos
- [ ] Replicación geográfica para DR

---

## 16. La Ficha SBOS — Unidad Atómica de Despliegue

### 16.1 Definición

Todo subproyecto, aplicación o servicio se despliega como una **Ficha SBOS**. Es la unidad atómica de gestión: el bos la instala, la repara, la actualiza y la elimina como una unidad. El bos resuelve el DAG de dependencias entre fichas y garantiza el orden topológico de instalación.

### 16.2 Estructura de una Ficha

```
mi-ficha/
├── manifest.yml        ← identidad, dependencias, feature flags, puertos, BD
├── yaml_engine.yml     ← declaración K8s (Deployment, Service, ConfigMap, etc.)
├── task_catalog.sh     ← tareas operativas bash: install, repair, migrate, backup
└── resources/
    ├── config.yaml       ConfigMaps K8s
    ├── dashboard.json    Dashboard Grafana mínimo (obligatorio)
    └── netpolicies/      NetworkPolicies adicionales de la ficha
```

### 16.3 manifest.yml Mínimo

```yaml
identity:
  id: "mi-ficha"
  version: "1.0.0"
  description: "Descripción técnica de la ficha"
  criticality: false       # true si el stack no puede operar sin ella
  license: "MIT"           # OSI-approved obligatorio

workload:
  type: kubernetes
  namespace: "sbos-{tenant}"
  server: "S06"

depends_on:
  - postgresql
  - keycloak
  - kong

ports:
  http:    28190    # rango SKULL Custom 28100-28999
  https:   28191
  metrics: 28192    # expone /metrics para Prometheus (obligatorio)
  health:  28193    # expone /health y /ready para K8s probes (obligatorio)

database:
  name: "mificha_db"
  engine: postgresql

keycloak:
  client_id: "mi-ficha"
  realm: "{tenant}"
  grant_type: authorization_code

vault:
  paths:
    - "secret/tenants/{realm}/mi-ficha/db"
    - "secret/tenants/{realm}/mi-ficha/api-key"

feature_flags:
  status: "beta"    # experimental | beta | ga
```

### 16.4 Lo que la Ficha Recibe Automáticamente

| Capacidad | Cómo llega | Lo que la ficha hace |
|---|---|---|
| Autenticación SSO | Keycloak + OAuth2-Proxy | Configura client_id — listo |
| ctx_id en cada request | Kong inyecta X-SBOS-CtxId | Lee el header, lo adjunta a todos sus logs |
| BitMask y dominios | JWT claim `bos_domains` | Lee bos_domains para autorización |
| Trazabilidad automática | bKernel escucha el WAL | Solo escribe en su BD con normalidad |
| mTLS automático | Linkerd sidecar inyectado | Transparente — nada que configurar |
| Observabilidad | Prometheus + Grafana + Loki + Tempo | Expone `/metrics`, emite logs JSON con ctx_id |
| Secrets seguros | Vault AppRole | Lee secretos de Vault al arranque |
| Respaldo | pgBackRest + Velero | Su BD y sus PVCs están cubiertos automáticamente |
| WAF | ModSecurity en NGINX | Sus endpoints están protegidos automáticamente |

---

## 17. Estándares de Desarrollo Backend

### 17.1 Reglas de Oro — Go

**SIEMPRE:**
- Embeber `Unimplemented{X}Server` en todo handler gRPC
- Verificar BitMask antes de ejecutar lógica de negocio
- Wrapear errores: `fmt.Errorf("operacion [ctx=%s]: %w", ctxID, err)`
- Usar `slog` estructurado con `ctx_id`, `tenant_id` y `correlation_id` en cada log
- Propagar metadata SBOS en cada llamada gRPC saliente vía `grpcmiddleware.OutgoingContext(ctx)`
- Incluir `ctx_id` en toda escritura a base de datos
- `int64` en centavos para dinero — nunca `float` ni `float64`
- Leer secretos de Vault al inicio — nunca de variables de entorno

**NUNCA:**
- `panic()` en código de producción (existe el RecoveryInterceptor)
- Llamadas HTTP directas a APIs externas (solo biedata tiene ese privilegio)
- Escribir directamente en la base de datos de otra ficha
- Goroutines sin mecanismo de control de ciclo de vida
- Loggear payloads completos en nivel INFO
- Hardcodear IPs, puertos o strings de conexión

### 17.2 Reglas de Oro — Rust

**SIEMPRE:**
- `Result<T, E>` en todas las funciones
- Propagar errores con `?` operator
- `thiserror` para tipos de error en librerías
- `anyhow` solo en binarios (`main.rs`)
- `tracing::instrument` en funciones críticas del procesador WAL
- Fields de tracing con `ctx_id` y `tenant_id` en cada span
- Verificar `origin != 'bkernel'` antes de procesar cualquier evento (antiloop)

**NUNCA:**
- `.unwrap()` en código de producción
- `.expect()` salvo errores de configuración al arranque (con mensaje descriptivo)
- `unsafe` sin justificación documentada y aprobación del arquitecto
- `std::thread::sleep` en código async
- `Mutex` bloqueante en paths críticos del procesador WAL

### 17.3 Interceptors gRPC — El Código más Importante

Los interceptors se ejecutan en cada llamada antes de que llegue al handler. Son la única garantía de que el contexto SBOS, el logging, la trazabilidad y la autenticación son universales:

```go
grpc.NewServer(
    grpc.ChainUnaryInterceptor(
        mw.RecoveryInterceptor,   // convierte panics en Internal error — PRIMERO
        mw.ContextInterceptor,    // extrae SBOSContext del metadata gRPC
        mw.AuthInterceptor,       // verifica ctx_id y tenant_id presentes
        mw.LoggingInterceptor,    // slog estructurado con ctx_id + tenant_id
        mw.TracingInterceptor,    // span OTel por cada llamada
        mw.MetricsInterceptor,    // Prometheus: duración, códigos de error
    ),
)
```

### 17.4 Checklist Pre-Commit

**Contrato gRPC:**
- [ ] ¿El `.proto` pasó `buf lint`?
- [ ] ¿`buf breaking` no detectó cambios incompatibles sin versioning?
- [ ] ¿Todos los campos monetarios son `int64` en centavos?
- [ ] ¿`RequestContext ctx = 1` está en todos los request messages?
- [ ] ¿Los campos eliminados tienen `reserved` para número y nombre?

**Handler Go:**
- [ ] ¿Se embebe `Unimplemented{X}Server`?
- [ ] ¿Se verifica BitMask antes de ejecutar lógica?
- [ ] ¿Los errores de dominio están mapeados en `{dominio}GRPCError()`?
- [ ] ¿Las llamadas a otros servicios usan `grpcmiddleware.OutgoingContext(ctx)`?

**Persistencia:**
- [ ] ¿Toda escritura en BD incluye `ctx_id` propagado del context?
- [ ] ¿Toda query tiene `tenant_id` en el WHERE?
- [ ] ¿Los errors del repo están wrapeados con `fmt.Errorf`?

**Rust:**
- [ ] ¿No hay `.unwrap()` fuera de tests?
- [ ] ¿El procesador WAL verifica `origin != 'bkernel'`?
- [ ] ¿Las funciones críticas tienen `#[instrument]` con ctx_id y tenant_id?

---

## 18. Reglas Inquebrantables del Ecosistema

Estas reglas son axiomas. Un subproyecto o ficha que ignore cualquiera de ellas no es un componente de SBOS: es un sistema externo incompatible.

| Regla | Lo que significa |
|---|---|
| **Keycloak es el único IdP** | No implementes login propio. No uses Auth0, Firebase ni auth nativa. Sin excepciones |
| **PostgreSQL es la única BD relacional** | Tu BD es PostgreSQL. MySQL solo como excepción explícita con SymmetricDS |
| **Solo licencias OSI-approved** | MIT, Apache 2.0, GPL, LGPL, MPL, BSD, AGPL, ISC. BSL, Commons Clause y Sustainable Use están vetadas |
| **Datos del cliente no salen** | No llames a APIs externas enviando datos del cliente directamente. Usa caja biedata |
| **Kubernetes desde el día 1** | No existe modo sin K8s. Todo se empaqueta como ficha SBOS |
| **Secrets vía Vault** | Ninguna contraseña, token ni certificado en texto claro en ningún lugar |
| **Cero invasión** | No modifiques el código ni las BDs de otras fichas del stack |
| **Docker vetado** | Solo Podman/OCI. Imágenes firmadas con Ed25519 |
| **HTTP entre daemons vetado** | Comunicación daemon↔daemon solo por WebSocket mTLS o Unix socket |
| **biedata es el único con salida exterior** | Ningún otro daemon ni ficha puede conectarse directamente a APIs externas |
| **Tenant ID siempre server-side** | Nunca derivar el tenant_id del cliente. Siempre de los claims JWT del servidor |
| **ctx_id inmutable** | Un ctx_id creado no se modifica. Context switch = nuevo ctx_id |

---

## 19. Roadmap de Implementación

### Fase 0 — Infraestructura Base (Semanas 1-4)

**Objetivo:** Cluster Kubernetes operativo con todos los servicios de plataforma.

- [ ] Kubernetes cluster multinodo HA (mínimo 3 control plane + N workers)
- [ ] Calico CNI con NetworkPolicy default-deny
- [ ] Linkerd service mesh (mTLS automático)
- [ ] NGINX Ingress + ModSecurity + Certbot
- [ ] Kong API Gateway 3.9.x LTS
- [ ] PostgreSQL 18.4 + Patroni HA (3 nodos)
- [ ] Redis 8.6.2 Cluster mode
- [ ] HashiCorp Vault con AppRole
- [ ] Stack observabilidad: Prometheus + Grafana + Loki + Tempo + OTel Collector
- [ ] Kyverno con políticas de seguridad base
- [ ] Wazuh DaemonSet
- [ ] GitLab CE + CI/CD pipeline (buf lint, buf breaking, tests)
- [ ] pgBackRest + Velero

### Fase 1 — bos y Control Plane (Semanas 5-10)

**Objetivo:** bos operativo, capaz de desplegar tenants y gestionar el Context Plane.

- [ ] Keycloak 26.6.2 con realm SBOS y 5 SPIs custom
- [ ] bos IAM Installer — API REST + WebSocket + Context API
- [ ] bosctl — CLI completa (deploy, tenant, context, ficha)
- [ ] bAuth — evaluación de tres dominios + BitMask
- [ ] bKernel — CDC Parser + Rule Engine básico + DLQ
- [ ] Context Registry en Redis (DB1)
- [ ] Tabla context_sessions en bkernel_db + audit_events
- [ ] Evento context.promoted operativo
- [ ] Kong Plugin SBOS-Context (Lua)
- [ ] Primer tenant desplegado vía `bosctl deploy seed.yml`

### Fase 2 — Dominio Empresarial (Semanas 11-20)

**Objetivo:** ERP operativo, POS funcional, facturación electrónica Bolivia.

- [ ] Tryton 8 multi-company integrado como ficha
- [ ] pos-service (pos.venta.*, pos.sesion.*, pos.pago.*)
- [ ] inventario-service con stock en tiempo real
- [ ] biedata — caja de exportación SIAT Bolivia (SFE)
- [ ] Módulo de facturación electrónica Tryton
- [ ] bhnexus + banexus — Par Nexus Soberano (primer POS físico)
- [ ] Tests de integración end-to-end (factura emitida → autorización SIAT → Tryton actualizado)

### Fase 3 — Web Platform (Semanas 21-28)

**Objetivo:** Sitios web funcionales por tenant, empresa y sucursal.

- [ ] Resource Manager + MinIO integration
- [ ] Website Engine — Domain Resolver + CTX Resolver
- [ ] Routing table por dominio en Kong
- [ ] Primeros sitios institucionales (nivel empresa y sucursal)
- [ ] Ecommerce básico con inventario ERP en tiempo real
- [ ] CDN / cache de assets por CTX

### Fase 4 — IA y Búsqueda Semántica (Semanas 29-36)

**Objetivo:** bSearch y bCompass operativos.

- [ ] pgvector pipeline (WAL → embeddings → índices HNSW)
- [ ] Qdrant colecciones aisladas por realm
- [ ] bSearch — Schema Discoverer + Search Learning Engine
- [ ] bCompass — rutas analyst, agent, flow, report
- [ ] Ollama local (LLM soberano, datos sin salir del servidor)
- [ ] Primer agente conversacional operativo

### Fase 5 — Escala y Certificación (Semanas 37-48)

**Objetivo:** El sistema soporta producción a escala real y está auditado.

- [ ] Load testing: 1.000 tenants simulados, 10.000 ctx_id concurrentes
- [ ] Chaos engineering: failover PostgreSQL, failover Redis, pod crashes
- [ ] Security audit externo (penetration testing)
- [ ] DR drill — failover geográfico real
- [ ] Auditoría ISO 27001 — evidencia de audit_events
- [ ] Onboarding primeros tenants de producción
- [ ] Documentación operacional completa (runbooks, playbooks)

---

## 20. Glosario Técnico

| Término | Definición |
|---|---|
| **bos** | SBOS IAM Installer. Control Plane soberano. El `systemd` del sistema operativo empresarial. Dueño del Context Plane |
| **bKernel** | SBOS Data Kernel (Rust). Consume el WAL de PostgreSQL (<50μs) y ejecuta el Rule Engine YAML |
| **biedata** | SBOS Data Integration (Rust). Único daemon autorizado a conectar con APIs externas |
| **bAuth** | SBOS Auth Enforce (Go). Evalúa los tres dominios y emite el BitMask de 64 bits |
| **bCompass** | SBOS AI Tools (Go). Route Engine de inteligencia soberana con HITL |
| **bSearch** | SBOS Motor de Búsqueda Soberano (Go). PostgreSQL 18+ nativo (GIN, tsvector, pg_trgm). WebSocket wss:// exclusivo. pgvector/Qdrant como vector search futuro (Fase 4) |
| **bhnexus + banexus** | Par Nexus Soberano. Broker de conectividad física entre mundo real y SBOS |
| **BitMask** | Entero de 64 bits donde cada bit representa un permiso granular. Calculado por bAuth en cada autenticación |
| **ctx_id** | Context Session ID. Identificador único e inmutable de una sesión empresarial activa |
| **dctx_id** | Device Context ID. Identificador de dispositivo pre-autenticación |
| **context.promoted** | Evento que eleva un dctx_id anónimo a ctx_id autenticado al momento del login |
| **Context Switch** | Cambio de contexto operativo sin reautenticación. Genera nuevo ctx_id |
| **CTX** | Identificador compuesto tenant.empresa.sucursal.servicio |
| **CDC** | Change Data Capture. Captura de cambios en tiempo real desde el WAL de PostgreSQL |
| **WAL** | Write-Ahead Log de PostgreSQL. Bus de eventos nativo del SBOS |
| **DLQ** | Dead Letter Queue. Cola de eventos fallidos con reintentos exponenciales |
| **Ficha SBOS** | Unidad atómica de despliegue: manifest.yml + yaml_engine.yml + task_catalog.sh |
| **Par Nexus Soberano** | bhnexus + banexus como unidad. Controla hardware físico en tiempo real |
| **Daemon Soberano** | Proceso systemd en host Ubuntu (fuera de Kubernetes) con acceso privilegiado |
| **SFE/SIAT** | Sistema de Facturación Electrónica de Bolivia. API del SIN (Servicio de Impuestos Nacionales) |
| **HITL** | Human-In-The-Loop. Punto de intervención humana obligatoria en flujos de IA |
| **OTel Baggage** | Mecanismo W3C/CNCF para propagar ctx_id entre servicios sin código adicional |
| **RequestContext** | Mensaje Protobuf que viaja en todos los requests gRPC con identidad y contexto |
| **HNSW** | Hierarchical Navigable Small World. Algoritmo de índice para búsqueda vectorial aproximada |
| **HALFVEC** | Tipo de vector de media precisión en pgvector. Más eficiente en memoria que VECTOR |
| **buf** | Herramienta de gestión de archivos .proto (lint, breaking changes, generación de código) |
| **Patroni** | Solución de HA para PostgreSQL con failover automático |
| **mTLS** | Mutual TLS. Autenticación bidireccional mediante certificados en ambos extremos |
| **LoA** | Level of Assurance. Nivel de aseguramiento de la autenticación (1=contraseña, 2=MFA, 3=biométrico+hardware) |
| **SoD** | Separation of Duties. Quien crea una operación no puede aprobarla |
| **ISA-95** | Estándar IEC 62264. Enterprise-Control System Integration. Niveles 0-4 |

---

## 21. Referencias Normativas

### Documentos del Corpus SBOS

| Documento | Contenido |
|---|---|
| `SBOS-001-VISION` | Qué es SBOS técnicamente. Los tres dominios. La inversión conceptual. ISA-95 |
| `SBOS-002-ARCH` | Las 5 capas. Los 8 daemons. El WAL como bus. Bounded Contexts |
| `SBOS-004-RULES` | Los 15 principios inquebrantables + 9 reglas de soberanía |
| `SBOS-018-DAEMON-BOS` | bos en profundidad. Saga de alta de tenant. Comandos bosctl |
| `SBOS-019-FICHAS` | Estructura de ficha. manifest.yml, yaml_engine.yml, task_catalog.sh |
| `SBOS-021-DAEMON-BAUTH` | Tabla Maestra BitMask 64-bit. Los 3 dominios en detalle |
| `SBOS-023-DAEMON-BKERNEL` | WAL, Rule Engine, MDM, DLQ, antiloop, bkernel_db schema |
| `SBOS-024-DAEMON-BIEDATA` | Las 6 fases de una caja. Flujo fiscal SIAT completo |
| `SBOS-026-DAEMON-BSEARCH` | Schema Discoverer, Search Learning Engine, Qdrant multi-tenant |
| `SBOS-027-DAEMON-BCOMPASS` | 4 tipos de ruta. Governance 1/2/3. Fronteras inviolables |
| `SBOS-029-KEYCLOAK` | SPIs custom, FAPI 2.0, configuración multi-realm |
| `SBOS-030-BOUNDED-CONTEXTS` | Bounded contexts y su integración vía bKernel |
| `SBOS-039-DAEMON-NEXUS` | Par Nexus Soberano. Topología invariable. Flujo <15ms |
| `SBOS-049-CONTEXT-PLANE` | Context Plane completo. dctx_id/ctx_id/context.promoted. OTel Baggage. DDL context_sessions |
| `SBOS-MANUAL-ACOPLAMIENTO` | Axiomas del ecosistema. Los 8 daemons. Integración de subproyectos. Checklist |
| `SBOS_Backend_Development_Standards` | Estándares Go, Rust, gRPC. Interceptors. Checklist pre-commit |

### Estándares Internacionales

| Referencia | Organismo | URL |
|---|---|---|
| ISO/IEC 27001:2022 | ISO/IEC | https://www.iso.org/standard/82875.html |
| ISO/IEC 27017:2015 | ISO/IEC | https://www.iso.org/standard/43757.html |
| ISO/IEC 27018:2019 | ISO/IEC | https://www.iso.org/standard/76559.html |
| NIST SP 800-207 (Zero Trust) | NIST | https://doi.org/10.6028/NIST.SP.800-207 |
| NIST SP 800-53 Rev.5 | NIST | https://doi.org/10.6028/NIST.SP.800-53r5 |
| W3C Trace Context Level 1 | W3C | https://www.w3.org/TR/trace-context/ |
| OpenTelemetry Baggage API Spec | CNCF | https://opentelemetry.io/docs/specs/otel/baggage/ |
| ISA-95 / IEC 62264 | ISA/IEC | https://www.isa.org/standards-publications/isa-standards/isa-95 |
| FAPI 2.0 Security Profile | OpenID | https://openid.net/specs/fapi-security-profile-2_0.html |
| Kubernetes Multi-Tenancy | CNCF | https://kubernetes.io/docs/concepts/security/multi-tenancy/ |
| Kubernetes Hardening Guide v1.2 | NSA/CISA | https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF |

---

*SBOS · Smart Business Operating System · Documento Maestro de Proyecto v2.0*  
*SKULL · HUMAN-DOC · Junio 2026*  
*Fuentes: SBOS-049-CONTEXT-PLANE v3.0 · SBOS-MANUAL-ACOPLAMIENTO v2.0 · SBOS_Backend_Development_Standards v1.0 · SBOS_Arquitectura_Cloud_Native_Multitenant v1.0 · SBOS_Web_Resource_Architecture_v2.0 · Investigación externa verificada*
