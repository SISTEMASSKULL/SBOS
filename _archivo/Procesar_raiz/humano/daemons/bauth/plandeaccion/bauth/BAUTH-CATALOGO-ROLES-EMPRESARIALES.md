# BAUTH-CATALOGO-ROLES-EMPRESARIALES — Catálogo Integral de Roles y Actores del Sistema
## Plantillas base para acelerar el registro de nuevas empresas en bAuth
### v2.1 · 2026-06-21 · SKULL

> **⚠️ ACTUALIZACIÓN v2.1 (Junio 2026):** La sección §6 ha sido reescrita completamente con el **modelo BitMask Dual** (BitMask Átomo 64-bit para identificación + Rol BitMask N-bit para combinación). El modelo anterior de "2 capas con OR directo sobre un solo u64" producía escalamiento silencioso de privilegios y ha sido descartado.
>
> **Documentos fuente del modelo corregido:** `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md`, `SBOS-MANUAL-BAUTH-COMPONENT-ROLES.md` v1.7, `SBOS-MANUAL-BAUTH-D12-BLOCKCHAIN-WALLET-CONTROL.md` v2.1.
> **Evaluación integral del proyecto:** `SBOS-BAUTH-EVALUACION-INTEGRAL-v2.2.md`.

---

## 1. Propósito

Este catálogo define **todos los actores que participan en el sistema empresarial** — tanto internos (empleados, personal) como externos (clientes, alumnos, pacientes, proveedores, ciudadanos) — organizados por sector económico según la **CAEB (Clasificación de Actividades Económicas de Bolivia)** del SIN.

### Premisa ISO 9001:2015

**Todo ente que recibe un producto o servicio del sistema es un CLIENTE del sistema.** Bajo este principio de gestión de calidad:

- Un **alumno** es cliente del centro educativo
- Un **paciente** es cliente del hospital
- Un **comprador** es cliente del comercio
- Un **ciudadano** es cliente de la administración pública
- Un **feligrés** es cliente de la organización religiosa

**Todos estos actores externos necesitan identidad digital en bAuth** — para recibir facturas electrónicas, firmar documentos, acceder a portales, autorizar operaciones, y ejercer sus derechos como titulares de datos personales.

Cada rol se traduce a una **plantilla de RolTemplate predefinida** en bAuth, permitiendo que una nueva empresa pueda registrarse y tener todos sus roles operativos en **menos de 10 minutos** — sin necesidad de definir cada rol desde cero.

> **Fuentes:** ISO 9001:2015 §3.2.4 (definición de cliente) · SIN Bolivia — CAEB 21 secciones · U.S. News 100 Best Jobs 2026 · OIT Estadísticas de empleo LATAM 2024 · INE Bolivia Encuesta de Hogares 2024 · Censo Bolivia 2024 · Cámaras de Comercio · Observatorios Laborales LATAM

---

## 2. ROLES SISTÉMICOS SBOS — Jerarquía de Administración y Bootstrap

> **Rol sistémico:** identidad que opera sobre la plataforma misma. Son los cimientos sobre los que se construye todo el ecosistema: módulos, tenants, datos, identidades de negocio.
>
> **Base normativa:** esta sección se fundamenta en estándares internacionales, no en criterios arbitrarios:
> - **NIST RBAC Model** (4 niveles): Flat → Hierarchical → Constrained → Symmetrical. SBOS implementa Nivel 3 (Constrained RBAC) con Separation of Duties (SoD) estático y dinámico.
> - **ISO 27001:2022 §A.8.2** — Privileged Access Rights: aprobación formal, least privilege, inventario vivo, revisión trimestral, MFA obligatorio en todo rol privilegiado.
> - **NIST SP 800-53 Rev.5** — AC-2 (Account Management), AC-5 (Separation of Duties), AC-6 (Least Privilege). Todo rol sistémico tiene dueño, propósito definido, y alcance acotado.
> - **NIST SP 800-63-4** — Digital Identity Models: IAL2/AAL2/FAL2 para roles humanos privilegiados; autenticación criptográfica (mTLS) para roles M2M.
> - **PAM (Privileged Access Management):** cuentas separadas admin/diarias, Just-in-Time (JIT) para SU, break-glass con aprobación post-evento, session recording en roles SU/N1.

### 2.0 Jerarquía Sistémica — Modelo de Alcance Decreciente

La jerarquía sigue el principio de **delegación controlada**: cada nivel recibe un subconjunto de la autoridad del nivel superior. El Superusuario tiene alcance global; el bootstrap solo sobre su propio daemon. Entre niveles se aplica **NIST AC-5 SoD**: quien crea un admin no puede ser ese admin.

| Nivel | Nombre | Alcance | Quién lo asigna | SoD (NIST AC-5) | Ref. RBAC |
|-------|--------|---------|----------------|------------------|-----------|
| **SU** | Superusuario | Todo el ecosistema SBOS | Bootstrap inicial | Único activo. Break-glass con aprobación post-evento. | Nivel 3 (Constrained) |
| **N1** | Plataforma | Todos los módulos, tenants, datos | Superusuario | SoD estático: Admin Proyecto ≠ Admin Seguridad ≠ Admin Infra | Nivel 3 (Constrained) |
| **N2** | Módulo / Daemon | Un daemon o subsistema completo | Admin Plataforma (S002) | SoD estático: Admin de Módulo ≠ Admin de Datos ≠ Admin de Vault | Nivel 2 (Hierarchical) |
| **N3** | Tenant / Sucursal | Una empresa u organización | Admin bAuth (S006) | Admin Tenant ≠ Admin Seguridad Tenant ≠ Admin Facturación Tenant | Nivel 2 (Hierarchical) |
| **N4** | Bootstrap / Interno | Su propio daemon o servicio | Bootstrap automático (bosctl setup) | Identidades M2M. Sin acceso humano directo. mTLS obligatorio. | Nivel 1 (Flat) |

---

### 2.1 SUPERUSUARIO SBOS (SU) · ISO 27001 A.8.2 · PAM Break-Glass

El Superusuario es el **primer rol creado durante el bootstrap** del SBOS. Tiene permisos
totales sobre todos los módulos, tenants, datos y configuraciones. Equivale a `root` en
el sistema operativo. **Solo existe uno activo por ecosistema** (NIST AC-5 SoD: no puede
existir un segundo SU concurrente).

**Controles PAM aplicables (ISO 27001 A.8.2):**
- Autenticación MFA obligatoria (AAL2 mínimo, NIST 800-63-4)
- Just-in-Time (JIT): el acceso SU se activa solo por tiempo limitado y con propósito definido
- Break-glass: en emergencia se puede activar sin aprobación previa, pero con auditoría post-evento obligatoria en ≤24h
- Session recording: cada sesión SU se graba y se almacena en logs inmutables
- No tiene cuenta "diaria" separada — la cuenta SU solo se usa para tareas SU

**Uso exclusivo para:**
- Bootstrap inicial del sistema
- Crear los Administradores de Plataforma (S002–S005)
- Recuperación de desastres (DR)
- Mantenimiento mayor que requiera alcance global

| # | Rol | Código bAuth | Descripción | Alcance | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|---------|------|--------|----------|-----------|
| S001 | **Superusuario SBOS** | `ROL-SYS-SUPERUSUARIO` | Máximo permiso global. Crea administradores de plataforma. Uso exclusivo para bootstrap, DR, y mantenimiento mayor. Una sola identidad activa por ecosistema. Auditoría obligatoria de cada uso. | Global | Sistema | Definido | — | ⏳ |

---

### 2.2 PLATAFORMA — Administradores Globales (N1)

Son los roles que gestionan la plataforma SBOS como un todo. Los crea el Superusuario
durante el bootstrap. Cada uno tiene un dominio de responsabilidad específico pero
todos operan a nivel global.

| # | Rol | Código bAuth | Descripción | Alcance | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|---------|------|--------|----------|
| S002 | **Administrador del Proyecto SBOS** | `ROL-SYS-ADMIN-PROYECTO` | Dueño del ciclo de vida de la plataforma: versiones, despliegues, módulos, fichas. Aprueba altas de tenants, crea administradores de módulo. | Global | Sistema | Definido | — | ⏳ |
| S003 | **Administrador de Seguridad SBOS** | `ROL-SYS-ADMIN-SEGURIDAD` | Dueño de las políticas de seguridad globales: autenticación, autorización, cifrado, auditoría. Configura PrivilegeEngine H-RBAC, LoA, Step-Up, políticas de contraseñas. Responsable del ISMS (ISO 27001). | Global | Sistema | Definido | — | ⏳ |
| S004 | **Administrador de Infraestructura SBOS** | `ROL-SYS-ADMIN-INFRA` | Dueño de la infraestructura física y lógica: servidores, redes, K8s, storage, CI/CD. Gestiona los 16 servidores lógicos, MetalLB, Calico, Kong, Linkerd. | Global | Sistema | Definido | — | ⏳ |
| S005 | **Administrador de Monitoreo / SRE** | `ROL-SYS-ADMIN-SRE` | Dueño de la observabilidad: Prometheus, Grafana, Loki, Alloy. Define SLOs, SLIs, error budgets, alertas. Respuesta a incidentes mayores. | Global | Sistema | Definido | — | ⏳ |

---

### 2.3 MÓDULO — Administradores de Daemon y Datos (N2)

Cada daemon soberano del SBOS tiene su propio Administrador de Módulo. Este rol gestiona
la configuración, operación y ciclo de vida de ese módulo específico. Lo crea el
Administrador del Proyecto.

| # | Rol | Código bAuth | Descripción | Alcance | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|---------|------|--------|----------|
| S006 | **Administrador de bAuth (Identidad)** | `ROL-SYS-ADMIN-BAUTH` | Dueño del sistema de identidad. Gestiona realms, roles, políticas H-RBAC, BitMask 64-bit, sincronización Keycloak+Tryton, SPIs Java. Crea administradores de tenant. | Módulo bAuth | Sistema | Definido | — | ⏳ |
| S007 | **Administrador de bKernel (Datos)** | `ROL-SYS-ADMIN-BKERNEL` | Dueño del CDC y Fanout Engine. Gestiona slots WAL, replicación PostgreSQL, Redis Streams, reglas de transformación de eventos. | Módulo bKernel | Sistema | Definido | — | ⏳ |
| S008 | **Administrador de biedata (Integración)** | `ROL-SYS-ADMIN-BIEDATA` | Dueño del orquestador JSON-RPC 2.0. Gestiona fichas declarativas, sagas, catálogo de tareas, validación de manifiestos. | Módulo biedata | Sistema | Definido | — | ⏳ |
| S009 | **Administrador de bSearch (Búsqueda)** | `ROL-SYS-ADMIN-BSEARCH` | Dueño del motor de búsqueda. Gestiona índices PostgreSQL GIN/tsvector, Redis Streams de indexación, WebSocket wss://, políticas de búsqueda federada. | Módulo bSearch | Sistema | Definido | — | ⏳ |
| S010 | **Administrador de NEXUS (Conectividad)** | `ROL-SYS-ADMIN-NEXUS` | Dueño de bhnexus y banexus. Gestiona hardware bridges (OSDP/MQTT/ONVIF/Wiegand), WebSocket mTLS, auth cache, interceptación USB/shell en edge. | Módulo NEXUS | Sistema | Definido | — | ⏳ |
| S011 | **Administrador de BOS (IAM Installer)** | `ROL-SYS-ADMIN-BOS` | Dueño del plano de control. Gestiona el daemon bos, el repositorio bos-install, las 112+ fichas, sagas de install/update/repair, Context Plane (ctx_id), Release Plane. | Módulo BOS | Sistema | Definido | — | ⏳ |
| S012 | **Administrador de Datos (DBA)** | `ROL-SYS-ADMIN-DATOS` | Dueño de todas las bases de datos del ecosistema. Gestiona PostgreSQL 18.4, Redis 8.6.2, backups (pgBackRest), restauración, migraciones de esquema, catálogo de bases de datos (SBOS-043). | Módulo Datos | Sistema | Definido | — | ⏳ |
| S013 | **Administrador de Vault (Secretos)** | `ROL-SYS-ADMIN-VAULT` | Dueño de Vault 2.0.1. Gestiona secret engines, políticas de acceso, leases dinámicos, sidecar injection en K8s, rotación de secretos. | Módulo Vault | Sistema | Definido | — | ⏳ |
| S014 | **Administrador de Kong (API Gateway)** | `ROL-SYS-ADMIN-KONG` | Dueño del API Gateway. Gestiona rutas, servicios, plugins (OIDC, rate-limiting, mTLS), consumers, certificados TLS. Único punto de entrada externo. | Módulo Kong | Sistema | Definido | — | ⏳ |
| S015 | **Administrador de Keycloak (SSO)** | `ROL-SYS-ADMIN-KEYCLOAK` | Dueño de Keycloak 26.6.2. Gestiona realms, clients, identity providers, auth flows, temas, SPIs. Sincronización con Tryton vía bAuth. | Módulo Keycloak | Sistema | Definido | — | ⏳ |

---

### 2.4 TENANT — Administradores de Empresa y Sucursal (N3)

Son los roles que gestionan una organización concreta dentro del SBOS. Los crea el
Administrador de bAuth cuando se da de alta un nuevo tenant. Son el puente entre
la plataforma y los roles de negocio (secciones 3 y 4 de este catálogo).

| # | Rol | Código bAuth | Descripción | Alcance | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|---------|------|--------|----------|
| S016 | **Administrador de Tenant / Empresa** | `ROL-SYS-ADMIN-TENANT` | Máxima autoridad dentro de un tenant. Gestiona sucursales, asigna administradores de sucursal, configura políticas de seguridad del tenant, aprueba altas de usuarios locales. Un tenant = una empresa/organización con su propio realm Keycloak, namespace K8s, BD y secretos en Vault. | Tenant | Sistema | Definido | — | ⏳ |
| S017 | **Administrador de Sucursal** | `ROL-SYS-ADMIN-SUCURSAL` | Gestiona una sucursal dentro del tenant. Administra personal local, permisos de acceso físico, configuración de POS lógicos, facturación electrónica de la sucursal. | Sucursal | Sistema | Definido | — | ⏳ |
| S018 | **Administrador de Seguridad de Tenant** | `ROL-SYS-ADMIN-SEG-TENANT` | Responsable de seguridad dentro del tenant: políticas de acceso, roles de negocio, bitácoras, cumplimiento fiscal (SIN, UIF, ASFI). Reporta al Admin de Seguridad SBOS en temas globales. | Tenant | Sistema | Definido | — | ⏳ |
| S019 | **Administrador de Facturación de Tenant** | `ROL-SYS-ADMIN-FACT-TENANT` | Dueño del sistema de facturación electrónica del tenant. Gestiona dosificación SIN, puntos de emisión, catálogo de productos/servicios, reportes RC-IVA, cierres fiscales. | Tenant | Sistema | Definido | — | ⏳ |

---

### 2.5 BOOTSTRAP — Roles Internos de Daemons y Servicios (N4)

Son los roles que los propios daemons y servicios del SBOS necesitan para funcionar.
No los usa ningún humano directamente — son identidades de sistema para autenticación
máquina-a-máquina (M2M), service accounts y procesos automatizados. Los crea el
bootstrap automáticamente durante `bosctl setup`.

#### 2.5.1 BOS — IAM Installer (5 roles internos)

| # | Rol | Código bAuth | Descripción | Alcance | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|---------|------|--------|----------|
| S020 | **bos-agent (Daemon)** | `ROL-SYS-BOS-AGENT` | Identidad del daemon bos.service (systemd). Ejecuta sagas, monitorea estados de ficha, reconcilia drift. Service account M2M. | BOS | Sistema | Definido | — | ⏳ |
| S021 | **bosctl-operador** | `ROL-SYS-BOSCTL-OPERADOR` | Operador humano que ejecuta bosctl. Acceso vía Unix socket /run/bos/bos.sock. Ejecuta install, update, repair, status de fichas. | BOS | Sistema | Definido | — | ⏳ |
| S022 | **bos-state-manager** | `ROL-SYS-BOS-STATE` | Proceso interno que lee/escribe .sbos_state.json. Único con permiso de escritura sobre el estado centralizado (fcntl.flock). | BOS | Sistema | Definido | — | ⏳ |
| S023 | **bos-dependency-resolver** | `ROL-SYS-BOS-DEPS` | Proceso interno que calcula el DAG topológico de dependencias entre fichas. Resuelve orden de instalación. | BOS | Sistema | Definido | — | ⏳ |
| S024 | **bos-health-checker** | `ROL-SYS-BOS-HEALTH` | Proceso interno que ejecuta health checks sobre pods, servicios, endpoints. Detecta degradación y dispara reparación. | BOS | Sistema | Definido | — | ⏳ |

#### 2.5.2 bAuth — Sistema de Identidad (3 roles internos)

| # | Rol | Código bAuth | Descripción | Alcance | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|---------|------|--------|----------|
| S025 | **bauth-daemon** | `ROL-SYS-BAUTH-DAEMON` | Identidad del daemon bauth.service. Ejecuta PrivilegeEngine, sync loop KC+Tryton (60s), resuelve decisiones de autorización PAP/PIP/PDP/PEP. | bAuth | Sistema | Definido | — | ⏳ |
| S026 | **bauth-reconcile** | `ROL-SYS-BAUTH-RECONCILE` | Proceso interno de reconciliación. Compara estado deseado vs real de roles, permisos, políticas. Corrige drift automático. | bAuth | Sistema | Definido | — | ⏳ |
| S027 | **bauth-spi-engine** | `ROL-SYS-BAUTH-SPI` | Motor de SPIs Java. Carga, valida y ejecuta los 5 Service Provider Interfaces: autenticación, autorización, identidad, auditoría, notificación. | bAuth | Sistema | Definido | — | ⏳ |

#### 2.5.3 bKernel — Data Kernel (3 roles internos)

| # | Rol | Código bAuth | Descripción | Alcance | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|---------|------|--------|----------|
| S028 | **bkernel-daemon** | `ROL-SYS-BKERNEL-DAEMON` | Identidad del daemon bkernel.service. Escucha WAL pgoutput, normaliza eventos CDC, publica en Redis Streams. Loop prevention vía pg_replication_origin. | bKernel | Sistema | Definido | — | ⏳ |
| S029 | **bkernel-fanout** | `ROL-SYS-BKERNEL-FANOUT` | Proceso interno del Fanout Engine. Enruta eventos a los streams Redis correctos según reglas de transformación. | bKernel | Sistema | Definido | — | ⏳ |
| S030 | **bkernel-rule-engine** | `ROL-SYS-BKERNEL-RULES` | Proceso interno del Rule Engine. Evalúa condiciones, filtra eventos, aplica transformaciones antes de publicar. | bKernel | Sistema | Definido | — | ⏳ |

#### 2.5.4 biedata — Data Gateway (3 roles internos)

| # | Rol | Código bAuth | Descripción | Alcance | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|---------|------|--------|----------|
| S031 | **biedata-daemon** | `ROL-SYS-BIEDATA-DAEMON` | Identidad del daemon biedata.service. Sirve JSON-RPC 2.0 en puerto :9470. Orquesta lecturas/escrituras entre apps del ecosistema. | biedata | Sistema | Definido | — | ⏳ |
| S032 | **biedata-saga-engine** | `ROL-SYS-BIEDATA-SAGA` | Proceso interno de orquestación de sagas. Ejecuta pasos con compensación explícita, timeouts por operación. | biedata | Sistema | Definido | — | ⏳ |
| S033 | **biedata-ficha-loader** | `ROL-SYS-BIEDATA-FICHA` | Proceso interno que carga, valida y registra fichas declarativas (manifest + validation + task_catalog). | biedata | Sistema | Definido | — | ⏳ |

#### 2.5.5 bSearch — Motor de Búsqueda (2 roles internos)

| # | Rol | Código bAuth | Descripción | Alcance | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|---------|------|--------|----------|
| S034 | **bsearch-daemon** | `ROL-SYS-BSEARCH-DAEMON` | Identidad del daemon bsearch.service. Sirve WebSocket wss:// en puerto :9493. Consume Redis Stream bkernel:index_queue. | bSearch | Sistema | Definido | — | ⏳ |
| S035 | **bsearch-indexer** | `ROL-SYS-BSEARCH-INDEXER` | Proceso interno de indexación. Mantiene índices GIN/tsvector en PostgreSQL, procesa cola de indexación, optimiza particiones. | bSearch | Sistema | Definido | — | ⏳ |

#### 2.5.6 NEXUS — Conectividad (3 roles internos)

| # | Rol | Código bAuth | Descripción | Alcance | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|---------|------|--------|----------|
| S036 | **bhnexus-daemon** | `ROL-SYS-BHNEXUS-DAEMON` | Identidad del daemon bhnexus.service. Proxy de Hardware Universal. WebSocket mTLS (10K+ conexiones). Auth Cache in-memory (TTL 30s). | NEXUS Host | Sistema | Definido | — | ⏳ |
| S037 | **banexus-daemon** | `ROL-SYS-BANEXUS-DAEMON` | Identidad del daemon banexus.service (--user). Centinela Edge en Fedora VDI. Interceptor USB/shell (udev+PAM+polkit). Policy Cache Efímero (AES-256-GCM). | NEXUS Edge | Sistema | Definido | — | ⏳ |
| S038 | **nexus-bridge** | `ROL-SYS-NEXUS-BRIDGE` | Proceso interno de Hardware Bridge. Traduce protocolos físicos (OSDP, MQTT, ONVIF, Wiegand) a eventos del ecosistema. | NEXUS | Sistema | Definido | — | ⏳ |

#### 2.5.7 Infraestructura — Servicios de Plataforma (6 roles internos)

| # | Rol | Código bAuth | Descripción | Alcance | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|---------|------|--------|----------|
| S039 | **postgresql-admin** | `ROL-SYS-POSTGRES-ADMIN` | Service account de administración de PostgreSQL 18.4. Gestiona bases de datos, roles, replicación, WAL, backups. | Infra | Sistema | Definido | — | ⏳ |
| S040 | **redis-admin** | `ROL-SYS-REDIS-ADMIN` | Service account de administración de Redis 8.6.2. Gestiona streams, cachés, persistencia RDB/AOF, réplicas. | Infra | Sistema | Definido | — | ⏳ |
| S041 | **keycloak-admin** | `ROL-SYS-KEYCLOAK-ADMIN` | Service account de administración de Keycloak 26.6.2. Crea realms, clients, roles, identity providers durante bootstrap de tenants. | Infra | Sistema | Definido | — | ⏳ |
| S042 | **vault-admin** | `ROL-SYS-VAULT-ADMIN` | Service account de administración de Vault 2.0.1. Gestiona secret engines, políticas, tokens, leases. | Infra | Sistema | Definido | — | ⏳ |
| S043 | **kong-admin** | `ROL-SYS-KONG-ADMIN` | Service account de administración de Kong 3.9.x LTS. Gestiona rutas, servicios, consumers, certificados, plugins. | Infra | Sistema | Definido | — | ⏳ |
| S044 | **k8s-cluster-admin** | `ROL-SYS-K8S-ADMIN` | Service account de administración del cluster Kubernetes (k3s). Gestiona namespaces, RBAC, CRDs, NetworkPolicies, operators. | Infra | Sistema | Definido | — | ⏳ |

#### 2.5.8 Context Plane — Trazabilidad (2 roles internos)

| # | Rol | Código bAuth | Descripción | Alcance | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|---------|------|--------|----------|
| S045 | **ctx-orchestrator** | `ROL-SYS-CTX-ORCHESTRATOR` | Servicio interno del Context Plane (SBOS-049). Crea, propaga y destruye ctx_id. Distribuye traceparent vía OpenTelemetry Baggage + W3C Trace Context. | Context Plane | Sistema | Definido | — | ⏳ |
| S046 | **ctx-validator** | `ROL-SYS-CTX-VALIDATOR` | Servicio interno que valida ctx_id en cada request. Verifica tenant, empresa, sucursal, pos_logico, user_id, traceparent. Rechaza requests sin ctx_id válido (ISO 27001 A.8.15). | Context Plane | Sistema | Definido | — | ⏳ |

#### 2.5.9 Observabilidad — Monitoreo (2 roles internos)

| # | Rol | Código bAuth | Descripción | Alcance | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|---------|------|--------|----------|
| S047 | **prometheus-collector** | `ROL-SYS-PROMETHEUS` | Service account de Prometheus. Recolecta métricas de todos los daemons, pods, nodos. Alimenta dashboards Grafana y alertas. | Observabilidad | Sistema | Definido | — | ⏳ |
| S048 | **loki-collector** | `ROL-SYS-LOKI` | Service account de Loki + Alloy. Recolecta, agrega y almacena logs centralizados de todos los daemons y servicios. | Observabilidad | Sistema | Definido | — | ⏳ |

---

### 2.6 Resumen — Roles Sistémicos

| Jerarquía | Cantidad | Códigos | RBAC | ISO 27001 | Autenticación |
|-----------|----------|---------|------|-----------|---------------|
| SU — Superusuario | 1 | `S001` | Constrained | A.8.2 PAM Break-Glass | MFA + JIT + Session Recording |
| N1 — Plataforma | 4 | `S002–S005` | Constrained (SoD) | A.8.2 + A.5.15–18 | MFA + cuenta admin separada |
| N2 — Módulo / Daemon | 10 | `S006–S015` | Hierarchical | A.8.2 Privileged Access | MFA + scope por módulo |
| N3 — Tenant / Sucursal | 4 | `S016–S019` | Hierarchical | A.8.2 scoped to tenant | MFA recomendado |
| N4 — Bootstrap / Internos | 29 | `S020–S048` | Flat (M2M) | A.8.2 service accounts | mTLS + short-lived tokens |
| **TOTAL SISTÉMICOS** | **48** | **S001–S048** | — | — | — |

> **Nota:** Todos los roles sistémicos se entregan en estado `Definido`. Son la base
> de la plataforma y deben ser los primeros en implementarse en bAuth. El cumplimiento
> de los controles ISO 27001 A.8.2 y NIST SP 800-53 AC-2/5/6 es **obligatorio** antes
> de activar cualquier rol de negocio.

---

## 3. ACTORES INTERNOS — Personal y Empleados por Sector (174 roles)

> **Rol interno:** persona que presta el servicio dentro de la organización. Es el "proveedor" del servicio en la cadena de calidad ISO 9001. Tiene relación laboral, credenciales de acceso, permisos sobre recursos del sistema.

### 3.1
| # | Rol | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|------|--------|----------|
| 1 | **Cajero** | `ROL-CAJERO` | Cobro en punto de venta, cierre de caja, arqueo | Operativo | Definido | — |
| 2 | **Vendedor de Piso** | `ROL-VENDEDOR` | Atención al cliente, ventas, reposición | Operativo | Definido | — |
| 3 | **Supervisor de Tienda** | `ROL-SUPERVISOR-TIENDA` | Supervisión de turnos, arqueos, apertura/cierre | Supervisión | Definido | — |
| 4 | **Encargado de Depósito** | `ROL-ENCARGADO-DEPOSITO` | Recepción de mercadería, inventario, despacho | Operativo | Definido | — |
| 5 | **Reponedor** | `ROL-REPONEDOR` | Reposición de góndolas, control de stock visible | Operativo | — | — |
| 6 | **Atención al Cliente** | `ROL-ATENCION-CLIENTE` | Devoluciones, consultas, servicio post-venta | Operativo | — | — |
| 7 | **Jefe de Local** | `ROL-JEFE-LOCAL` | Gestión completa de sucursal, personal, resultados | Gerencia Media | Definido | — |
| 8 | **Promotor / Impulsadora** | `ROL-PROMOTOR` | Degustaciones, promociones en punto de venta | Operativo | — | — |
| 9 | **Fletero / Repartidor** | `ROL-FLETERO` | Entrega de pedidos a domicilio | Operativo | — | — |
| 10 | **Encargado de Caja Central** | `ROL-ENCARGADO-CAJA` | Arqueo general, gestión de efectivo, depósitos bancarios | Supervisión | — | — |
| 101 | **Encargado de Facturación** | `ROL-ENCARGADO-FACTURACION` | Emisión de facturas electrónicas SIN, control de dosificación, reportes fiscales | Operativo | Definido | — |
| 102 | **Vendedor Mayorista** | `ROL-VENDEDOR-MAYORISTA` | Ventas B2B, negociación de volumen, cotizaciones, créditos | Operativo | — | — |
| 103 | **Comprador / Jefe de Compras** | `ROL-COMPRADOR` | Negociación con proveedores, órdenes de compra, control de calidad | Supervisión | Definido | — |
| 104 | **Encargado de Inventario** | `ROL-ENCARGADO-INVENTARIO` | Control de stock, inventario cíclico, mermas, valorización | Técnico | — | — |
| 105 | **Cajero de Autoservicio** | `ROL-CAJERO-AUTOSERVICIO` | Cobro en supermercado, manejo de cinta transportadora, pesaje | Operativo | — | — |
| 106 | **Encargado de Frutas y Verduras** | `ROL-ENCARGADO-FRUTAS-VERDURAS` | Reposición de perecederos, control de frescura, mermas | Operativo | — | — |
| 107 | **Encargado de Carnicería** | `ROL-CARNICERO` | Corte de carnes, pesaje, refrigeración, normas sanitarias | Operativo | — | — |
| 108 | **Encargado de Panadería / Pastelería** | `ROL-PANADERO` | Producción de pan, pastelería, control de hornos | Operativo | — | — |
| 109 | **Encargado de Lácteos y Embutidos** | `ROL-ENCARGADO-LACTEOS` | Control de cadena de frío, fechas de vencimiento, reposición | Operativo | — | — |
| 110 | **Encargado de Limpieza / Artículos de Limpieza** | `ROL-ENCARGADO-LIMPIEZA` | Reposición de productos de limpieza, control de químicos | Operativo | — | — |
| 111 | **Encargado de Electrodomésticos** | `ROL-VENDEDOR-ELECTRO` | Venta de electrodomésticos, demostración, garantías | Operativo | — | — |
| 112 | **Encargado de Tecnología / Celulares** | `ROL-VENDEDOR-TECNOLOGIA` | Venta de celulares, accesorios, activación de líneas | Operativo | — | — |
| 113 | **Encargado de Farmacia / Perfumería** | `ROL-ENCARGADO-FARMACIA` | Venta de medicamentos OTC, perfumería, cosméticos | Operativo | — | — |
| 114 | **Encargado de Ferretería** | `ROL-FERRETERO` | Venta de materiales de construcción, ferretería, herramientas | Operativo | — | — |
| 115 | **Encargado de Librería / Papelería** | `ROL-LIBRERO` | Venta de útiles escolares, oficina, impresiones | Operativo | — | — |
| 116 | **Encargado de Tienda de Ropa / Moda** | `ROL-VENDEDOR-MODA` | Venta de ropa, calzado, accesorios, probador | Operativo | — | — |
| 117 | **Encargado de Mueblería / Decoración** | `ROL-VENDEDOR-MUEBLES` | Venta de muebles, decoración, armado, delivery | Operativo | — | — |
| 118 | **Encargado de Repuestos / Autopartes** | `ROL-VENDEDOR-REPUESTOS` | Venta de repuestos, lubricantes, accesorios automotrices | Operativo | — | — |
| 119 | **Encargado de Joyería / Relojería** | `ROL-JOYERO` | Venta de joyas, relojes, metales preciosos, seguridad | Operativo | — | — |
| 120 | **Encargado de Juguetería** | `ROL-VENDEDOR-JUGUETES` | Venta de juguetes, juegos, artículos infantiles | Operativo | — | — |

### 3.1-B
**Fuente:** SIN Bolivia — RND N° 102100000020, CAEB (Clasificador de Actividades Económicas de Bolivia), Anexos I y II

| # | Rol | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|------|--------|----------|
| 121 | **Responsable de Facturación Electrónica** | `ROL-FACTURADOR-ELECTRONICO` | Emisión, anulación, control de dosificación SIN, reportes RC-IVA | Operativo | Definido | — |
| 122 | **Encargado de Dosificación** | `ROL-DOSIFICADOR` | Solicitud y control de dosificación de facturas ante el SIN | Operativo | — | — |
| 123 | **Contador Tributario** | `ROL-CONTADOR-TRIBUTARIO` | Declaraciones juradas IVA/IT/IUE/RC-IVA, libros de compra y venta | Técnico | Definido | — |
| 124 | **Revisor Fiscal / Auditor Tributario** | `ROL-REVISOR-FISCAL` | Revisión de cumplimiento fiscal, auditoría de facturación, reportes SIN | Técnico | — | — |
| 125 | **Encargado de NIT / Registro de Contribuyentes** | `ROL-ENCARGADO-NIT` | Altas, bajas, modificaciones en el padrón de contribuyentes SIN | Técnico | — | — |
| 126 | **Encargado de Retenciones** | `ROL-ENCARGADO-RETENCIONES` | Retenciones RC-IVA, IT, IUE, emisión de comprobantes de retención | Técnico | — | — |
| 127 | **Operador de Facturación en Línea** | `ROL-OPERADOR-FACTURACION-ONLINE` | Emisión de facturas en el portal SIF (Sistema de Facturación) del SIN | Operativo | — | — |
| 128 | **Encargado de Archivo Fiscal** | `ROL-ARCHIVO-FISCAL` | Conservación de documentos fiscales (8 años), digitalización, índice | Operativo | — | — |
| 129 | **Encargado de Exportaciones / NITEX** | `ROL-ENCARGADO-EXPORTACIONES` | Facturación de exportación, certificados de origen, SENAVEX | Técnico | — | — |
| 130 | **Encargado de Importaciones** | `ROL-ENCARGADO-IMPORTACIONES` | DUI, valoración aduanera, facturación de importación, agencia despachante | Técnico | — | — |
| 131 | **Encargado de Notas Fiscales** | `ROL-NOTAS-FISCALES` | Emisión de notas de crédito/débito, ajustes fiscales, anulaciones | Operativo | — | — |
| 132 | **Encargado de Impuestos Municipales** | `ROL-IMPUESTOS-MUNICIPALES` | Declaraciones de patentes, inmuebles, publicidad municipal | Técnico | — | — |

### 3.1-C
> **Sistema crítico para la operación diaria.** Estos roles gestionan el ciclo completo de facturación→cobro→conciliación. Complementan los roles fiscales de 2.1-B.

| # | Rol | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|------|--------|----------|
| 133 | **Operador de Facturación POS** | `ROL-OPERADOR-FACT-POS` | Emisión de facturas en punto de venta físico, manejo de impresora fiscal, lectores QR SIN | Operativo | — | — |
| 134 | **Operador de Facturación Móvil / Delivery** | `ROL-OPERADOR-FACT-MOVIL` | Emisión de facturas desde app móvil para entregas a domicilio, geolocalización fiscal | Operativo | — | — |
| 135 | **Encargado de Cuentas Corrientes (CxC)** | `ROL-ENCARGADO-CXC` | Gestión de cuentas por cobrar, antigüedad de saldos, conciliación de pagos, proyección de flujo | Técnico | — | — |
| 136 | **Cobrador / Gestor de Cobranza** | `ROL-COBRADOR` | Cobro a clientes morosos, planes de pago, registro de compromisos, reporte de incobrables | Operativo | — | — |
| 137 | **Analista de Crédito y Cobranza** | `ROL-ANALISTA-CREDITO-COBRANZA` | Análisis de riesgo crediticio de clientes, scoring, límites de crédito, políticas de cobranza | Técnico | — | — |
| 138 | **Encargado de Notas de Crédito/Débito** | `ROL-ENCARGADO-NOTAS-CREDITO` | Emisión y control de NC/ND, ajustes por devoluciones, descuentos, anulaciones con trazabilidad SIN | Operativo | — | — |
| 139 | **Encargado de Reportes de IVA** | `ROL-ENCARGADO-REPORTES-IVA` | Generación de libros IVA compras/ventas, reportes RC-IVA, cruce con declaraciones juradas SIN | Técnico | — | — |
| 140 | **Conciliador de Facturación** | `ROL-CONCILIADOR-FACTURACION` | Cruce diario facturas emitidas vs recibidas, detección de duplicados, diferencias, facturas no informadas | Técnico | — | — |
| 141 | **Operador de Facturación Recurrente** | `ROL-OPERADOR-FACT-RECURRENTE` | Gestión de suscripciones, débitos automáticos, facturación periódica, renovación de contratos | Operativo | — | — |
| 142 | **Encargado de Retenciones y Percepciones** | `ROL-ENCARGADO-RETENCIONES-PERCEPCIONES` | Cálculo y emisión de comprobantes de retención IVA/IT/IUE, percepciones aduaneras, regímenes especiales | Técnico | — | — |
| 143 | **Supervisor de Facturación y Cobranza** | `ROL-SUPERVISOR-FACT-COBRANZA` | Supervisión del equipo de facturación+cobranza, métricas de recaudación, morosidad, cumplimiento fiscal | Supervisión | — | — |
| 144 | **Jefe de Facturación y Crédito** | `ROL-JEFE-FACTURACION-CREDITO` | Dueño del ciclo order-to-cash. Políticas de crédito, precios, descuentos, relación con SIN y auditoría | Gerencia Media | — | — |

### 3.2
| # | Rol | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|------|--------|----------|
| 11 | **Portero / Guardia de Seguridad** | `ROL-PORTERO` | Control de acceso, registro de visitantes, rondas | Operativo | Definido | — |
| 12 | **Supervisor de Seguridad** | `ROL-SUPERVISOR-SEGURIDAD` | Coordinación de guardias, reportes de incidentes | Supervisión | — | — |
| 13 | **Operador de CCTV** | `ROL-OPERADOR-CCTV` | Monitoreo de cámaras, grabación, reportes | Operativo | — | — |
| 14 | **Recepcionista** | `ROL-RECEPCIONISTA` | Recepción de visitas, llamadas, correspondencia | Operativo | Definido | — |
| 15 | **Sereno / Vigilante Nocturno** | `ROL-SERENO` | Rondas nocturnas, control perimetral | Operativo | — | — |
| 16 | **Jefe de Seguridad** | `ROL-JEFE-SEGURIDAD` | Políticas de seguridad, gestión de personal, emergencias | Gerencia Media | Definido | — |
| 17 | **Controlador de Acceso Vehicular** | `ROL-CONTROL-VEHICULAR` | Registro de vehículos, pesaje, autorización de salida | Operativo | — | — |
| 18 | **Supervisor de Piso / Floor Walker** | `ROL-FLOOR-WALKER` | Supervisión de área de ventas, prevención de pérdidas | Supervisión | — | — |

### 3.3
| # | Rol | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|------|--------|----------|
| 19 | **Cajero Bancario** | `ROL-CAJERO-BANCO` | Transacciones, depósitos, retiros, verificación de identidad | Operativo | Definido | — |
| 20 | **Ejecutivo de Cuenta** | `ROL-EJECUTIVO-CUENTA` | Apertura de cuentas, venta de productos financieros | Operativo | — | — |
| 21 | **Oficial de Créditos** | `ROL-OFICIAL-CREDITOS` | Evaluación crediticia, análisis de riesgo, aprobación | Operativo | — | — |
| 22 | **Supervisor de Sucursal Bancaria** | `ROL-SUPERVISOR-BANCO` | Supervisión de operaciones, bóveda, cumplimiento | Supervisión | — | — |
| 23 | **Analista de Riesgos** | `ROL-ANALISTA-RIESGOS` | Análisis de cartera, scoring, reportes regulatorios | Técnico | — | — |
| 24 | **Oficial de Cumplimiento** | `ROL-OFICIAL-CUMPLIMIENTO` | Prevención lavado de dinero, KYC, reportes UIF | Técnico | Definido | — |
| 25 | **Tesorero** | `ROL-TESORERO` | Gestión de flujo de caja, inversiones, conciliación | Gerencia Media | — | — |
| 26 | **Contador General** | `ROL-CONTADOR` | Registros contables, impuestos, balances, cierre fiscal | Técnico | Definido | — |
| 27 | **Auditor Interno** | `ROL-AUDITOR-INTERNO` | Auditoría de procesos, cumplimiento normativo, SOX | Técnico | — | — |
| 28 | **Gerente de Sucursal Bancaria** | `ROL-GERENTE-BANCO` | Gestión integral de sucursal, P&L, recursos humanos | Gerencia | — | — |

### 3.4
| # | Rol | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|------|--------|----------|
| 29 | **Operario de Producción** | `ROL-OPERARIO-PRODUCCION` | Línea de producción, maquinaria, control de calidad básico | Operativo | Definido | — |
| 30 | **Supervisor de Planta** | `ROL-SUPERVISOR-PLANTA` | Supervisión de turnos, calidad, seguridad industrial | Supervisión | Definido | — |
| 31 | **Jefe de Producción** | `ROL-JEFE-PRODUCCION` | Planificación de producción, indicadores, mejora continua | Gerencia Media | — | — |
| 32 | **Técnico de Mantenimiento** | `ROL-TECNICO-MANTENIMIENTO` | Mantenimiento preventivo y correctivo de maquinaria | Técnico | — | — |
| 33 | **Control de Calidad** | `ROL-CONTROL-CALIDAD` | Inspección de producto, muestreo, normas ISO | Técnico | — | — |
| 34 | **Despachador / Chofer** | `ROL-DESPACHADOR-CHOFER` | Despacho de mercadería, ruta de entregas, documentación | Operativo | — | — |
| 35 | **Jefe de Almacén / Depósito** | `ROL-JEFE-ALMACEN` | Gestión de inventarios, FIFO/LIFO, stock crítico | Supervisión | — | — |
| 36 | **Operario de Embalaje** | `ROL-OPERARIO-EMBALAJE` | Embalaje, etiquetado, paletizado | Operativo | — | — |
| 37 | **Ingeniero de Planta** | `ROL-INGENIERO-PLANTA` | Diseño de procesos, optimización, automatización | Técnico | — | — |
| 38 | **Encargado de Seguridad e Higiene** | `ROL-SEGURIDAD-HIGIENE` | Normas OSHA, EPP, capacitación, accidentes | Técnico | — | — |
| 39 | **Operario de Carga / Estibador** | `ROL-ESTIBADOR` | Carga y descarga de camiones, manejo de montacargas | Operativo | — | — |
| 40 | **Planificador de Producción** | `ROL-PLANIFICADOR-PRODUCCION` | MRP, programación de órdenes, capacidad | Técnico | — | — |

### 3.4-B
> **Sistema crítico para el control de existencias y la trazabilidad de mercadería.** Estos roles gestionan el ciclo completo del inventario: recepción → almacenamiento → control → despacho → auditoría.

| # | Rol | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|------|--------|----------|
| 161 | **Jefe de Inventarios** | `ROL-JEFE-INVENTARIOS` | Dueño del control de existencias. Define políticas de inventario, stock mínimo/máximo, método de valorización, indicadores de rotación. | Gerencia Media | — | — |
| 162 | **Analista de Control de Mermas** | `ROL-ANALISTA-MERMAS` | Identificación, registro y análisis de mermas (caducidad, rotura, hurto, extravío). Propone acciones correctivas. | Técnico | — | — |
| 163 | **Encargado de Recepción de Mercadería** | `ROL-RECEPTOR-MERCADERIA` | Recepción física de mercadería, verificación contra orden de compra y factura, control de calidad visual, ingreso al sistema | Operativo | — | — |
| 164 | **Encargado de Despacho** | `ROL-ENCARGADO-DESPACHO` | Preparación de pedidos, picking, packing, verificación contra orden de venta, guía de remisión, carga de transporte | Operativo | — | — |
| 165 | **Auditor de Inventario** | `ROL-AUDITOR-INVENTARIO` | Ejecuta inventarios cíclicos y generales, compara físico vs sistema, investiga diferencias, reporta a contabilidad | Técnico | — | — |
| 166 | **Planificador de Demanda** | `ROL-PLANIFICADOR-DEMANDA` | Pronóstico de demanda, punto de reorden, cantidad económica de pedido (EOQ), colaboración con compras y ventas | Técnico | — | — |
| 167 | **Encargado de Caducidades y Lotes** | `ROL-ENCARGADO-CADUCIDADES` | Control de fechas de vencimiento por lote, FIFO/FEFO, alertas de próxima caducidad, gestión de bajas sanitarias | Operativo | — | — |
| 168 | **Operador de Código de Barras / RFID** | `ROL-OPERADOR-BARRAS-RFID` | Operación de lectores de código de barras/RFID, impresión de etiquetas, asociación lote/producto/ubicación en WMS | Operativo | — | — |
| 169 | **Encargado de Devoluciones** | `ROL-ENCARGADO-DEVOLUCIONES` | Recepción de devoluciones de clientes, verificación de estado, NC, reingreso a stock o baja, trazabilidad del motivo | Operativo | — | — |
| 170 | **Operador de WMS (Warehouse Management)** | `ROL-OPERADOR-WMS` | Operación del sistema de gestión de almacenes: ubicaciones, slots, picking paths, optimización de espacio, integración ERP | Operativo | — | — |
| 171 | **Encargado de Almacén Refrigerado / Cadena de Frío** | `ROL-ENCARGADO-CADENA-FRIO` | Monitoreo de temperatura/humedad, registro de trazabilidad, alarmas, mantenimiento de equipos de frío, normas SENASAG | Técnico | — | — |
| 172 | **Encargado de Almacén de Materias Primas** | `ROL-ENCARGADO-ALMACEN-MP` | Control de stock de materias primas e insumos para producción, coordinación con compras y planificación, punto de reorden | Operativo | — | — |
| 173 | **Encargado de Almacén de Producto Terminado** | `ROL-ENCARGADO-ALMACEN-PT` | Control de stock de producto terminado, trazabilidad lote→cliente, coordinación con despacho y ventas | Operativo | — | — |
| 174 | **Supervisor de Almacenes** | `ROL-SUPERVISOR-ALMACENES` | Supervisión de todos los almacenes, indicadores de gestión (rotación, precisión, mermas), personal, seguridad patrimonial | Supervisión | — | — |

### 3.5
| # | Rol | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|------|--------|----------|
| 41 | **Médico General** | `ROL-MEDICO-GENERAL` | Consulta externa, diagnóstico, recetas | Profesional | Definido | — |
| 42 | **Enfermero/a** | `ROL-ENFERMERO` | Atención al paciente, administración de medicamentos | Profesional | Definido | — |
| 43 | **Farmacéutico / Químico Farmacéutico** | `ROL-FARMACEUTICO` | Dispensación de medicamentos, control de recetas | Profesional | — | — |
| 44 | **Recepcionista de Consultorio** | `ROL-RECEPCION-CLINICA` | Agenda de turnos, registro de pacientes, cobro | Operativo | — | — |
| 45 | **Auxiliar de Enfermería** | `ROL-AUXILIAR-ENFERMERIA` | Apoyo a enfermería, higiene de pacientes, signos vitales | Operativo | — | — |
| 46 | **Administrador de Clínica** | `ROL-ADMIN-CLINICA` | Gestión de personal, proveedores, facturación | Gerencia Media | — | — |
| 47 | **Jefe de Farmacia** | `ROL-JEFE-FARMACIA` | Gestión de stock, caducidades, compras, fiscalización | Supervisión | — | — |
| 48 | **Paramédico / Técnico en Emergencias** | `ROL-PARAMEDICO` | Atención pre-hospitalaria, ambulancia, triage | Técnico | — | — |

### 3.6
| # | Rol | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|------|--------|----------|
| 49 | **Recepcionista de Hotel** | `ROL-RECEPCION-HOTEL` | Check-in/out, reservas, facturación | Operativo | — | — |
| 50 | **Mucama / Camarera** | `ROL-MUCAMA` | Limpieza de habitaciones, reposición de amenities | Operativo | — | — |
| 51 | **Cocinero** | `ROL-COCINERO` | Preparación de alimentos, mise en place | Operativo | — | — |
| 52 | **Mesero / Camarero** | `ROL-MESERO` | Servicio de mesa, toma de pedidos, cobro | Operativo | — | — |
| 53 | **Bartender / Barman** | `ROL-BARTENDER` | Preparación de bebidas, control de barra | Operativo | — | — |
| 54 | **Chef / Jefe de Cocina** | `ROL-CHEF` | Dirección de cocina, menú, costos, personal | Gerencia Media | — | — |
| 55 | **Gerente de Hotel** | `ROL-GERENTE-HOTEL` | Gestión integral, revenue management, calidad | Gerencia | — | — |
| 56 | **Lavandero / Lencería** | `ROL-LAVANDERO` | Lavado, planchado, control de inventario de ropa blanca | Operativo | — | — |

### 3.7
| # | Rol | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|------|--------|----------|
| 57 | **Administrativo / Secretario** | `ROL-ADMINISTRATIVO` | Tareas de oficina, archivo, correspondencia | Operativo | Definido | — |
| 58 | **Recepcionista Administrativo** | `ROL-RECEPCION-ADMIN` | Central telefónica, visitas, correspondencia | Operativo | — | — |
| 59 | **Asistente de Gerencia** | `ROL-ASISTENTE-GERENCIA` | Agenda, reuniones, viajes, informes | Operativo | — | — |
| 60 | **Jefe de Recursos Humanos** | `ROL-JEFE-RRHH` | Contratación, nómina, capacitación, clima laboral | Gerencia Media | Definido | — |
| 61 | **Analista de RRHH** | `ROL-ANALISTA-RRHH` | Reclutamiento, selección, evaluación de desempeño | Técnico | — | — |
| 62 | **Contador / Contable** | `ROL-CONTADOR` | Registros, impuestos, balances, cierres | Técnico | Definido | — |
| 63 | **Asistente Contable** | `ROL-ASISTENTE-CONTABLE` | Facturación, conciliaciones, archivo impositivo | Operativo | — | — |
| 64 | **Jefe de Compras** | `ROL-JEFE-COMPRAS` | Proveedores, licitaciones, órdenes de compra | Supervisión | — | — |
| 65 | **Gerente General / Director** | `ROL-GERENTE-GENERAL` | Dirección estratégica, decisiones ejecutivas | Dirección | Definido | — |
| 66 | **Mensajero / Cadete** | `ROL-MENSAJERO` | Trámites bancarios, entregas, diligencias | Operativo | — | — |

### 3.7-B
> **Sistema crítico para el cierre fiscal y la gestión financiera.** Estos roles operan el ciclo contable completo: registro → mayorización → estados financieros → auditoría. Sin ellos no hay cumplimiento ante SIN, ASFI ni contabilidad gerencial.

| # | Rol | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|------|--------|----------|
| 145 | **Jefe de Contabilidad** | `ROL-JEFE-CONTABILIDAD` | Dueño del ciclo contable. Supervisa registros, cierres mensuales/anuales, estados financieros. Responde ante auditoría y SIN. | Gerencia Media | — | — |
| 146 | **Contador de Costos** | `ROL-CONTADOR-COSTOS` | Cálculo de costos de producción, FIFO/LIFO/PMP, valorización de inventario, margen por producto | Técnico | — | — |
| 147 | **Analista de Cuentas por Pagar (CxP)** | `ROL-ANALISTA-CXP` | Registro de facturas de proveedores, programación de pagos, conciliación con tesorería, retenciones | Técnico | — | — |
| 148 | **Analista de Cuentas por Cobrar (CxC)** | `ROL-ANALISTA-CXC-CONTABLE` | Registro contable de cobros, anticipos, NC/ND, conciliación extractos vs saldos contables | Técnico | — | — |
| 149 | **Encargado de Conciliaciones Bancarias** | `ROL-CONCILIADOR-BANCARIO` | Cruce diario/semanal de extractos bancarios vs registros contables, detección de partidas no conciliadas | Técnico | — | — |
| 150 | **Encargado de Activos Fijos** | `ROL-ENCARGADO-ACTIVOS-FIJOS` | Registro, depreciación, revalorización, bajas, inventario físico de activos fijos. Cálculo de vida útil | Técnico | — | — |
| 151 | **Encargado de Nómina / Sueldos** | `ROL-ENCARGADO-NOMINA` | Cálculo de planillas, descuentos AFP/IVA, retenciones RC-IVA, emisión de comprobantes de pago, planillas SIN | Técnico | — | — |
| 152 | **Tesorero / Encargado de Tesorería** | `ROL-TESORERO-PAGOS` | Gestión de caja chica, fondo fijo, emisión de cheques, transferencias, control de vencimientos | Técnico | — | — |
| 153 | **Asistente de Tesorería** | `ROL-ASISTENTE-TESORERIA` | Apoyo en pagos, archivo de comprobantes, arqueos de caja chica, registro de gastos menores | Operativo | — | — |
| 154 | **Encargado de Presupuesto** | `ROL-ENCARGADO-PRESUPUESTO` | Elaboración y control presupuestario, desvíos, proyecciones, reportes gerenciales por centro de costo | Técnico | — | — |
| 155 | **Revisor de Estados Financieros** | `ROL-REVISOR-ESTADOS-FINANCIEROS` | Revisión de balances, estado de resultados, flujo de efectivo, notas a los EEFF antes de publicación o auditoría | Técnico | — | — |
| 156 | **Contador Impositivo** | `ROL-CONTADOR-IMPOSITIVO` | Especialista en impuestos: IVA, IT, IUE, RC-IVA, IPBI, regímenes especiales. Presentación de DDJJ ante SIN. | Técnico | — | — |
| 157 | **Encargado de Impuestos Diferidos** | `ROL-ENCARGADO-IMPUESTOS-DIFERIDOS` | Cálculo de impuestos diferidos (NIC 12), diferencias temporarias, activos/pasivos por impuesto diferido | Técnico | — | — |
| 158 | **Analista de Control Interno** | `ROL-ANALISTA-CONTROL-INTERNO` | Diseño y prueba de controles SOX/COSO, matrices de riesgo, cumplimiento normativo contable | Técnico | — | — |
| 159 | **Encargado de Cierre Mensual/Anual** | `ROL-ENCARGADO-CIERRE` | Coordinación del cierre contable: provisiones, ajustes, reversiones, consolidación, reporting a holding | Técnico | — | — |
| 160 | **Auditor Externo / Revisor Fiscal** | `ROL-AUDITOR-EXTERNO-CONTABLE` | Auditoría externa de estados financieros, dictamen, revisión de cumplimiento NIIF/NCIF, informe a accionistas | Técnico | — | — |

### 3.8
| # | Rol | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|------|--------|----------|
| 67 | **Chofer de Camión** | `ROL-CHOFER-CAMION` | Transporte de carga, documentación, ruta | Operativo | Definido | — |
| 68 | **Chofer de Taxi / Radio Taxi** | `ROL-CHOFER-TAXI` | Transporte de pasajeros, cobro, ruta | Operativo | — | — |
| 69 | **Despachador de Flota** | `ROL-DESPACHADOR-FLOTA` | Asignación de vehículos, control de rutas, GPS | Supervisión | — | — |
| 70 | **Jefe de Logística** | `ROL-JEFE-LOGISTICA` | Cadena de suministro, transporte, almacenes | Gerencia Media | — | — |
| 71 | **Operador de Grúa / Montacargas** | `ROL-OPERADOR-GRUA` | Manejo de equipos de izaje, carga pesada | Operativo | — | — |
| 72 | **Encargado de Patio / Playero** | `ROL-PLAYERO` | Control de patio de maniobras, estacionamiento | Operativo | — | — |
| 73 | **Coordinador de Distribución** | `ROL-COORD-DISTRIBUCION` | Planificación de entregas, optimización de rutas | Técnico | — | — |
| 74 | **Auxiliar de Carga / Descarga** | `ROL-AUXILIAR-CARGA` | Carga y descarga manual, clasificación | Operativo | — | — |

### 3.9
| # | Rol | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|------|--------|----------|
| 75 | **Soporte Técnico / Help Desk** | `ROL-SOPORTE-TECNICO` | Atención de tickets, instalación de equipos, redes | Técnico | — | — |
| 76 | **Desarrollador / Programador** | `ROL-DESARROLLADOR` | Desarrollo de software, testing, documentación | Técnico | — | — |
| 77 | **Administrador de Sistemas / SysAdmin** | `ROL-SYSADMIN` | Servidores, redes, backups, monitoreo | Técnico | — | — |
| 78 | **Jefe de IT / IT Manager** | `ROL-JEFE-IT` | Gestión de infraestructura, equipo, presupuesto | Gerencia Media | — | — |
| 79 | **Analista de Datos** | `ROL-ANALISTA-DATOS` | Reportes, dashboards, BI, SQL | Técnico | — | — |
| 80 | **Especialista en Ciberseguridad** | `ROL-CIBERSEGURIDAD` | Pentesting, monitoreo, respuesta a incidentes | Técnico | — | — |
| 81 | **Project Manager IT** | `ROL-PM-IT` | Gestión de proyectos, metodología ágil, stakeholders | Gerencia Media | — | — |
| 82 | **Diseñador UX/UI** | `ROL-DISENADOR-UX` | Diseño de interfaces, experiencia de usuario, prototipado | Técnico | — | — |

### 3.10
| # | Rol | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|------|--------|----------|
| 83 | **Maestro de Obra** | `ROL-MAESTRO-OBRA` | Dirección de cuadrilla, lectura de planos, avance | Supervisión | — | — |
| 84 | **Albañil / Oficial** | `ROL-ALBANIL` | Construcción, revoque, colocación de ladrillos | Operativo | — | — |
| 85 | **Peón / Ayudante de Obra** | `ROL-PEON-OBRA` | Carga de materiales, mezcla, limpieza | Operativo | — | — |
| 86 | **Ingeniero Civil / Arquitecto** | `ROL-INGENIERO-CIVIL` | Diseño estructural, cálculo, dirección de obra | Profesional | — | — |
| 87 | **Electricista** | `ROL-ELECTRICISTA` | Instalación eléctrica, tableros, cableado | Técnico | — | — |
| 88 | **Plomero / Gasista** | `ROL-PLOMERO` | Instalación sanitaria, gas, reparaciones | Técnico | — | — |

### 3.11
| # | Rol | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|------|--------|----------|
| 89 | **Docente / Profesor** | `ROL-DOCENTE` | Enseñanza, planificación, evaluación | Profesional | Definido | — |
| 90 | **Director de Escuela / Colegio** | `ROL-DIRECTOR-COLEGIO` | Dirección académica, administrativa, comunidad | Gerencia | Definido | — |
| 91 | **Auxiliar Docente** | `ROL-AUXILIAR-DOCENTE` | Apoyo en aula, material didáctico | Operativo | — | — |
| 92 | **Secretario Académico** | `ROL-SECRETARIO-ACADEMICO` | Registro de notas, matrículas, certificados | Operativo | — | — |
| 93 | **Portero / Conserje Escolar** | `ROL-CONSERJE-ESCUELA` | Mantenimiento, seguridad, apertura/cierre | Operativo | — | — |
| 94 | **Bibliotecario** | `ROL-BIBLIOTECARIO` | Gestión de colección, préstamos, catalogación | Operativo | — | — |

### 3.12
| # | Rol | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-----|-------------|-------------|------|--------|----------|
| 95 | **Peón Rural / Jornalero** | `ROL-PEON-RURAL` | Labores de campo, siembra, cosecha | Operativo | — | — |
| 96 | **Capataz / Encargado de Campo** | `ROL-CAPATAZ` | Supervisión de cuadrilla, planificación de tareas | Supervisión | — | — |
| 97 | **Tractorista** | `ROL-TRACTORISTA` | Manejo de maquinaria agrícola | Operativo | — | — |
| 98 | **Veterinario de Campo** | `ROL-VETERINARIO` | Sanidad animal, vacunación, control de enfermedades | Profesional | — | — |
| 99 | **Administrador de Estancia / Hacienda** | `ROL-ADMIN-ESTANCIA` | Gestión integral, personal, producción, finanzas | Gerencia Media | — | — |
| 100 | **Encargado de Riego** | `ROL-ENCARGADO-RIEGO` | Sistema de riego, canales, programación | Operativo | — | — |

---

## 4. ACTORES EXTERNOS POR SECTOR CAEB SIN — Clientes del Sistema (ISO 9001)

> **Rol externo:** persona o entidad que **recibe** el producto o servicio de la organización. Es el "cliente" según ISO 9001:2015 §3.2.4. No tiene relación laboral con la empresa, pero **sí necesita identidad digital en bAuth** para: recibir facturas electrónicas SIN, firmar contratos, acceder a portales de autogestión, autorizar operaciones, ejercer derechos ARCO (acceso, rectificación, cancelación, oposición) sobre sus datos personales.
>
> **Fuente de la clasificación sectorial:** SIN Bolivia — CAEB (Clasificación de Actividades Económicas de Bolivia) basado en CIIU Rev.4, 21 secciones A–U. RND N° 102100000020.

### 4.0
| Sección CAEB | Sector | Actores externos clave |
|-------------|--------|------------------------|
| **A** | Agricultura, Ganadería, Pesca | Comprador mayorista, Acopiador, Proveedor de insumos |
| **B** | Minería e Hidrocarburos | Comprador de minerales, Inversionista, Comunidad |
| **C** | Industria Manufacturera | Cliente mayorista, Cliente minorista, Proveedor MP |
| **D** | Electricidad, Gas, Vapor | Usuario residencial, Usuario industrial |
| **E** | Agua, Desechos | Usuario residencial, Generador de residuos |
| **F** | Construcción | Propietario, Inversionista, Fiscalizador |
| **G** | **Comercio (Compra/Venta)** | **Cliente minorista, Cliente mayorista, Consumidor final** |
| **H** | Transporte y Almacenamiento | Pasajero, Remitente, Consignatario |
| **I** | Alojamiento y Comidas | Huésped, Comensal, Cliente de eventos |
| **J** | Información y Comunicaciones | Suscriptor, Usuario SaaS, Anunciante |
| **K** | Financieras y Seguros | Cuentahabiente, Asegurado, Inversionista, Deudor |
| **L** | Inmobiliarias | Inquilino, Comprador, Propietario vendedor |
| **M** | Profesionales, Científicas, Técnicas | Cliente de servicios, Consultante, Dueño de mascota |
| **N** | Servicios Administrativos | Cliente de agencia, Viajero, Postulante |
| **O** | Administración Pública | Ciudadano, Beneficiario, Administrado |
| **P** | **Enseñanza / Educación** | **Alumno, Padre/Tutor, Egresado, Postulante** |
| **Q** | **Salud y Asistencia Social** | **Paciente, Asegurado, Familiar, Donante** |
| **R** | Arte, Entretenimiento, Deporte | Espectador, Visitante, Deportista, Socio |
| **S** | Otras Actividades de Servicios | Cliente peluquería, Feligrés, Afiliado sindical |
| **T** | Hogares como Empleadores | Empleador doméstico, Trabajador del hogar |
| **U** | Organizaciones Extraterritoriales | Diplomático, Beneficiario cooperación |

---

### 4.A — SECTOR A: Agricultura, Ganadería, Silvicultura y Pesca (6 actores externos)
> **CAEB Sección A · Divisiones 01–03** · 22% del empleo boliviano · Facturación electrónica obligatoria para exportadores y agroindustria.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E001 | **Comprador Mayorista / Acopiador** | `ROL-EXT-COMPRADOR-AGRO` | Compra volumen a productores para distribución, emite factura electrónica SIN | Cliente | — | — | ⏳ |
| E002 | **Comprador Minorista / Consumidor Final** | `ROL-EXT-CONSUMIDOR-AGRO` | Compra en mercados, ferias, tiendas agropecuarias | Cliente | — | — | ⏳ |
| E003 | **Proveedor de Insumos Agrícolas** | `ROL-EXT-PROVEEDOR-AGRO` | Vende semillas, fertilizantes, agroquímicos al productor | Proveedor | — | — | ⏳ |
| E004 | **Exportador Agroindustrial** | `ROL-EXT-EXPORTADOR-AGRO` | Exporta commodities (soya, quinua, café, carne), NITEX, SENASAG | Cliente | — | — | ⏳ |
| E005 | **Productor / Agricultor Asociado** | `ROL-EXT-PRODUCTOR-AGRO` | Miembro de cooperativa o asociación de productores | Afiliado | — | — | ⏳ |
| E006 | **Técnico Veterinario Externo** | `ROL-EXT-VETERINARIO-VISITANTE` | Veterinario que visita la estancia sin relación de dependencia | Proveedor | — | — | ⏳ |

### 4.B — SECTOR B: Explotación de Minas y Canteras (5 actores externos)
> **CAEB Sección B · Divisiones 05–09** · Sector estratégico Bolivia · Facturación electrónica SIN obligatoria.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E007 | **Comprador de Minerales / Commodities** | `ROL-EXT-COMPRADOR-MINERO` | Fundición, trading, compra de concentrados | Cliente | — | — | ⏳ |
| E008 | **Inversionista Minero** | `ROL-EXT-INVERSIONISTA-MINERO` | Accionista, financista de operación minera | Cliente | — | — | ⏳ |
| E009 | **Comunidad / Junta Vecinal** | `ROL-EXT-COMUNIDAD-MINERA` | Representante de comunidad aledaña a la operación (consulta previa) | Actor Social | — | — | ⏳ |
| E010 | **Contratista Minero** | `ROL-EXT-CONTRATISTA-MINERO` | Empresa contratista que opera en el yacimiento | Proveedor | — | — | ⏳ |
| E011 | **Comprador de Oro / Joyería** | `ROL-EXT-COMPRADOR-ORO` | Compra oro para joyería o inversión, factura electrónica SIN | Cliente | — | — | ⏳ |

### 4.C — SECTOR C: Industria Manufacturera (8 actores externos)
> **CAEB Sección C · Divisiones 10–33** · 12% del empleo · Facturación electrónica obligatoria para toda la cadena.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E012 | **Cliente Mayorista / Distribuidor** | `ROL-EXT-CLIENTE-MAYORISTA-IND` | Compra al fabricante para distribuir a minoristas | Cliente | — | — | ⏳ |
| E013 | **Cliente Minorista / Consumidor Final** | `ROL-EXT-CLIENTE-MINORISTA-IND` | Compra producto terminado para consumo personal o doméstico | Cliente | Definido | — | ⏳ |
| E014 | **Proveedor de Materia Prima** | `ROL-EXT-PROVEEDOR-MP` | Suministra insumos, materia prima, componentes al fabricante | Proveedor | — | — | ⏳ |
| E015 | **Proveedor de Maquinaria y Equipo** | `ROL-EXT-PROVEEDOR-MAQUINARIA` | Vende, instala y mantiene maquinaria industrial | Proveedor | — | — | ⏳ |
| E016 | **Maquilador / Subcontratista** | `ROL-EXT-MAQUILADOR` | Terceriza parte del proceso productivo para el fabricante | Proveedor | — | — | ⏳ |
| E017 | **Cliente de Exportación** | `ROL-EXT-CLIENTE-EXPORT-IND` | Comprador en el exterior, factura de exportación SIN | Cliente | — | — | ⏳ |
| E018 | **Inspector de Calidad / Certificador** | `ROL-EXT-INSPECTOR-CALIDAD` | Auditor externo ISO, certificación de producto (IBNORCA) | Proveedor | — | — | ⏳ |
| E019 | **Diseñador Industrial Externo** | `ROL-EXT-DISENADOR-IND` | Diseña productos, empaques, moldes bajo contrato | Proveedor | — | — | ⏳ |

### 4.D — SECTOR D: Suministro de Electricidad, Gas, Vapor (5 actores externos)
> **CAEB Sección D · División 35** · Servicios básicos · Facturación electrónica obligatoria SIN.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E020 | **Usuario Residencial / Domiciliario** | `ROL-EXT-USUARIO-RESIDENCIAL` | Consumidor de electricidad o gas en hogar, factura SIN | Cliente | Definido | — | ⏳ |
| E021 | **Usuario Industrial / Comercial** | `ROL-EXT-USUARIO-INDUSTRIAL` | Consumidor de energía en planta, fábrica o comercio | Cliente | — | — | ⏳ |
| E022 | **Usuario de Alumbrado Público** | `ROL-EXT-USUARIO-ALUMBRADO` | Municipio o gobernación como cliente de alumbrado público | Cliente | — | — | ⏳ |
| E023 | **Generador Independiente / Autoproductor** | `ROL-EXT-GENERADOR-INDEP` | Genera energía solar/eólica y vende excedente a la red | Proveedor | — | — | ⏳ |
| E024 | **Solicitante de Nueva Conexión** | `ROL-EXT-SOLICITANTE-CONEXION` | Persona o empresa que solicita conexión nueva al servicio | Cliente | — | — | ⏳ |

### 4.E — SECTOR E: Agua, Alcantarillado, Desechos (4 actores externos)
> **CAEB Sección E · Divisiones 36–39** · Servicios básicos · Facturación electrónica obligatoria SIN.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E025 | **Usuario Residencial de Agua Potable** | `ROL-EXT-USUARIO-AGUA` | Consumidor de agua potable y alcantarillado en hogar | Cliente | — | — | ⏳ |
| E026 | **Usuario Industrial de Agua** | `ROL-EXT-USUARIO-AGUA-IND` | Fábrica o agroindustria con consumo intensivo de agua | Cliente | — | — | ⏳ |
| E027 | **Generador de Residuos / Desechos** | `ROL-EXT-GENERADOR-RESIDUOS` | Empresa que genera residuos y contrata gestión de desechos | Cliente | — | — | ⏳ |
| E028 | **Solicitante de Licencia Ambiental** | `ROL-EXT-SOLICITANTE-AMBIENTAL` | Empresa que tramita licencia ambiental, ficha ambiental | Cliente | — | — | ⏳ |

### 4.F — SECTOR F: Construcción (6 actores externos)
> **CAEB Sección F · Divisiones 41–43** · 8% del empleo · Facturación electrónica SIN para contratos de obra.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E029 | **Propietario / Dueño de la Obra** | `ROL-EXT-PROPIETARIO-OBRA` | Contrata la construcción, paga la factura electrónica SIN | Cliente | — | — | ⏳ |
| E030 | **Inversionista / Desarrollador Inmobiliario** | `ROL-EXT-INVERSIONISTA-OBRA` | Financia el proyecto, recibe facturas de avance de obra | Cliente | — | — | ⏳ |
| E031 | **Fiscalizador de Obra** | `ROL-EXT-FISCALIZADOR-OBRA` | Supervisa calidad, avance, normas técnicas (externo a la constructora) | Proveedor | — | — | ⏳ |
| E032 | **Proveedor de Materiales de Construcción** | `ROL-EXT-PROVEEDOR-MATERIALES` | Ferretería, cementera, acerera que suministra a la obra | Proveedor | — | — | ⏳ |
| E033 | **Comprador de Inmueble en Construcción** | `ROL-EXT-COMPRADOR-INMUEBLE` | Compra departamento/casa en plano o en construcción | Cliente | — | — | ⏳ |
| E034 | **Arquitecto / Proyectista Externo** | `ROL-EXT-PROYECTISTA` | Diseña planos bajo contrato, sin relación de dependencia | Proveedor | — | — | ⏳ |

### 4.G — SECTOR G: COMERCIO AL POR MAYOR Y MENOR · COMPRA/VENTA (16 actores externos)
> **CAEB Sección G · Divisiones 45–47** · 🔥 **28% del empleo boliviano — el sector más grande.** · Facturación electrónica SIN obligatoria para todo comercio formal. Esta sección cubre el caso de uso más importante: la relación comprador-vendedor en todas sus variantes.

#### 3.G.1 — Clientes de Comercio Minorista (B2C)

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E035 | **Cliente Minorista / Consumidor Final** | `ROL-EXT-CLIENTE-MINORISTA` | Persona natural que compra para consumo personal o doméstico. Recibe factura electrónica SIN. Es el cliente más numeroso del sistema. | Cliente | Definido | — | ⏳ |
| E036 | **Cliente Recurrente / Fidelizado** | `ROL-EXT-CLIENTE-FIDELIZADO` | Cliente con historial de compras, membresía, puntos, descuentos personalizados | Cliente | — | — | ⏳ |
| E037 | **Cliente Ocasional / Sin Registro** | `ROL-EXT-CLIENTE-OCASIONAL` | Comprador de paso, no requiere identidad completa pero sí factura SIN | Cliente | — | — | ⏳ |
| E038 | **Cliente de Autoservicio / Supermercado** | `ROL-EXT-CLIENTE-SUPERMERCADO` | Compra en autoservicio, uso de carrito, pesaje, caja | Cliente | — | — | ⏳ |
| E039 | **Cliente de Tienda Especializada** | `ROL-EXT-CLIENTE-TIENDA` | Compra en tienda por rubro: ferretería, farmacia, moda, electro, librería | Cliente | — | — | ⏳ |
| E040 | **Cliente de E-commerce / Tienda Virtual** | `ROL-EXT-CLIENTE-ECOMMERCE` | Compra en línea, pago digital, delivery, factura electrónica en portal SIN | Cliente | — | — | ⏳ |

#### 3.G.2 — Clientes de Comercio Mayorista (B2B)

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E041 | **Cliente Mayorista / Revendedor** | `ROL-EXT-CLIENTE-MAYORISTA` | Empresa que compra al por mayor para revender. Negociación de volumen, crédito comercial, factura SIN crédito fiscal. | Cliente | Definido | — | ⏳ |
| E042 | **Cliente Corporativo / B2B** | `ROL-EXT-CLIENTE-CORPORATIVO` | Empresa que compra insumos, suministros o servicios para su operación (no para revender). Contratos marco, órdenes de compra. | Cliente | Definido | — | ⏳ |
| E043 | **Cliente Institucional / Estado** | `ROL-EXT-CLIENTE-INSTITUCIONAL` | Entidad pública que compra mediante licitación, contratación directa, SICOES | Cliente | — | — | ⏳ |
| E044 | **Cliente de Distribuidora** | `ROL-EXT-CLIENTE-DISTRIBUIDORA` | Negocio minorista que se abastece en distribuidora mayorista | Cliente | — | — | ⏳ |

#### 3.G.3 — Proveedores del Comercio

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E045 | **Proveedor Nacional** | `ROL-EXT-PROVEEDOR-NACIONAL` | Empresa o fabricante nacional que suministra productos al comercio, emite factura SIN | Proveedor | Definido | — | ⏳ |
| E046 | **Proveedor Internacional / Importador** | `ROL-EXT-PROVEEDOR-IMPORTADOR` | Proveedor del exterior, DUI, factura de importación, agencia despachante | Proveedor | — | — | ⏳ |
| E047 | **Proveedor de Servicios al Comercio** | `ROL-EXT-PROVEEDOR-SERV-COMERCIO` | Servicios de limpieza, seguridad, mantenimiento, software para el local comercial | Proveedor | — | — | ⏳ |
| E048 | **Artesano / Productor Local** | `ROL-EXT-ARTESANO` | Productor artesanal que vende a través del comercio minorista | Proveedor | — | — | ⏳ |

#### 3.G.4 — Vehículos Automotores (CAEB G45)

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E049 | **Comprador de Vehículo** | `ROL-EXT-COMPRADOR-VEHICULO` | Compra vehículo nuevo o usado, factura SIN, registro en Diprove | Cliente | Definido | — | ⏳ |
| E050 | **Cliente de Taller Mecánico** | `ROL-EXT-CLIENTE-TALLER` | Dueño de vehículo que contrata reparación o mantenimiento, factura SIN | Cliente | — | — | ⏳ |

### 4.H — SECTOR H: Transporte y Almacenamiento (7 actores externos)
> **CAEB Sección H · Divisiones 49–53** · 7% del empleo · Facturación electrónica SIN para servicios de transporte.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E051 | **Pasajero de Transporte Interdepartamental** | `ROL-EXT-PASAJERO-BUS` | Viajero en flota, boleto con factura SIN | Cliente | — | — | ⏳ |
| E052 | **Pasajero de Transporte Aéreo** | `ROL-EXT-PASAJERO-AEREO` | Pasajero de vuelo nacional o internacional, factura SIN | Cliente | Definido | — | ⏳ |
| E053 | **Remitente de Carga** | `ROL-EXT-REMITENTE-CARGA` | Persona o empresa que envía carga, emite conocimiento de embarque | Cliente | — | — | ⏳ |
| E054 | **Consignatario / Destinatario de Carga** | `ROL-EXT-CONSIGNATARIO` | Persona o empresa que recibe la carga en destino | Cliente | — | — | ⏳ |
| E055 | **Cliente de Courier / Mensajería** | `ROL-EXT-CLIENTE-COURIER` | Envía o recibe paquetes, documentos, factura SIN | Cliente | — | — | ⏳ |
| E056 | **Cliente de Almacenaje / Depósito Fiscal** | `ROL-EXT-CLIENTE-ALMACENAJE` | Empresa que contrata almacenamiento, inventario gestionado | Cliente | — | — | ⏳ |
| E057 | **Agencia de Viajes / Tour Operador** | `ROL-EXT-AGENCIA-VIAJES` | Intermediario que vende pasajes, factura SIN, comisionista | Cliente | — | — | ⏳ |

### 4.I — SECTOR I: Alojamiento y Servicio de Comidas (6 actores externos)
> **CAEB Sección I · Divisiones 55–56** · Turismo creciente · Facturación electrónica SIN.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E058 | **Huésped / Pasajero de Hotel** | `ROL-EXT-HUESPED` | Se registra en hotel con CI/pasaporte, recibe factura SIN, consume servicios | Cliente | Definido | — | ⏳ |
| E059 | **Comensal / Cliente de Restaurante** | `ROL-EXT-COMENSAL` | Consume alimentos y bebidas, recibe factura SIN | Cliente | — | — | ⏳ |
| E060 | **Cliente de Eventos / Banquetes** | `ROL-EXT-CLIENTE-EVENTOS` | Contrata salón, catering, decoración para evento social o corporativo | Cliente | — | — | ⏳ |
| E061 | **Cliente de Delivery de Comida** | `ROL-EXT-CLIENTE-DELIVERY` | Pide comida a domicilio por app o teléfono, factura SIN | Cliente | — | — | ⏳ |
| E062 | **Cliente de Servicio de Catering** | `ROL-EXT-CLIENTE-CATERING` | Empresa o particular que contrata servicio de comida para oficinas/eventos | Cliente | — | — | ⏳ |
| E063 | **Huésped de Alojamiento Temporal / Airbnb** | `ROL-EXT-HUESPED-TEMPORAL` | Alquila departamento/casa por plataforma digital | Cliente | — | — | ⏳ |

### 4.J — SECTOR J: Información y Comunicaciones (6 actores externos)
> **CAEB Sección J · Divisiones 58–63** · Facturación electrónica SIN · Software, telecom, medios.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E064 | **Suscriptor de Telecomunicaciones** | `ROL-EXT-SUSCRIPTOR-TELECOM` | Usuario de internet, TV cable, telefonía, factura SIN mensual | Cliente | Definido | — | ⏳ |
| E065 | **Cliente de Software / SaaS** | `ROL-EXT-CLIENTE-SAAS` | Empresa o persona que contrata software como servicio, factura SIN | Cliente | — | — | ⏳ |
| E066 | **Lector / Suscriptor de Medios** | `ROL-EXT-SUSCRIPTOR-MEDIOS` | Suscriptor de periódico, revista, plataforma de noticias | Cliente | — | — | ⏳ |
| E067 | **Anunciante / Cliente Publicitario** | `ROL-EXT-ANUNCIANTE` | Empresa que contrata publicidad en medios, factura SIN | Cliente | — | — | ⏳ |
| E068 | **Cliente de Servicios Cloud / Datacenter** | `ROL-EXT-CLIENTE-CLOUD` | Empresa que contrata hosting, cloud, servidores, factura SIN | Cliente | — | — | ⏳ |
| E069 | **Usuario de Plataforma Digital** | `ROL-EXT-USUARIO-PLATAFORMA` | Usuario registrado en plataforma/app con cuenta digital verificada | Cliente | — | — | ⏳ |

### 4.K — SECTOR K: Actividades Financieras y de Seguros (8 actores externos)
> **CAEB Sección K · Divisiones 64–66** · Regulado por ASFI · Facturación electrónica SIN.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E070 | **Cuentahabiente / Cliente Bancario** | `ROL-EXT-CUENTAHABIENTE` | Persona o empresa con cuenta en el banco, KYC completo | Cliente | Definido | — | ⏳ |
| E071 | **Asegurado / Titular de Póliza** | `ROL-EXT-ASEGURADO` | Contrata seguro (vida, auto, salud, incendio), recibe factura SIN | Cliente | Definido | — | ⏳ |
| E072 | **Beneficiario de Seguro** | `ROL-EXT-BENEFICIARIO-SEGURO` | Persona designada para recibir indemnización del seguro | Cliente | — | — | ⏳ |
| E073 | **Inversionista / Ahorrista** | `ROL-EXT-AHORRISTA` | Persona con DPF, fondo de inversión, valores, recibe factura SIN | Cliente | — | — | ⏳ |
| E074 | **Deudor / Prestatario** | `ROL-EXT-DEUDOR` | Persona o empresa con crédito bancario, firmante de pagaré | Cliente | — | — | ⏳ |
| E075 | **Beneficiario de Remesas** | `ROL-EXT-BENEFICIARIO-REMESAS` | Recibe giro o remesa del exterior, ventanilla de banco | Cliente | — | — | ⏳ |
| E076 | **Solicitante de Crédito** | `ROL-EXT-SOLICITANTE-CREDITO` | Persona o empresa que solicita crédito, sujeto a evaluación | Cliente | — | — | ⏳ |
| E077 | **Cliente de Casa de Cambio** | `ROL-EXT-CLIENTE-CAMBIO` | Compra/venta de divisas, factura SIN | Cliente | — | — | ⏳ |

### 4.L — SECTOR L: Actividades Inmobiliarias (5 actores externos)
> **CAEB Sección L · División 68** · Facturación electrónica SIN para alquileres y ventas.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E078 | **Inquilino / Arrendatario** | `ROL-EXT-INQUILINO` | Alquila inmueble para vivienda o comercio, recibe factura SIN mensual | Cliente | Definido | — | ⏳ |
| E079 | **Comprador de Inmueble** | `ROL-EXT-COMPRADOR-INMUEBLE-L` | Compra casa, departamento, terreno, firma minuta, factura SIN | Cliente | — | — | ⏳ |
| E080 | **Propietario Vendedor / Arrendador** | `ROL-EXT-PROPIETARIO-VENDEDOR` | Dueño que vende o alquila su inmueble a través de inmobiliaria | Proveedor | — | — | ⏳ |
| E081 | **Inversionista Inmobiliario** | `ROL-EXT-INVERSIONISTA-INMOB` | Invierte en proyectos inmobiliarios, recibe facturas de rendimiento | Cliente | — | — | ⏳ |
| E082 | **Tasador / Perito Inmobiliario** | `ROL-EXT-TASADOR` | Valúa inmuebles para compra/venta, crédito hipotecario | Proveedor | — | — | ⏳ |

### 4.M — SECTOR M: Actividades Profesionales, Científicas y Técnicas (7 actores externos)
> **CAEB Sección M · Divisiones 69–75** · Servicios profesionales · Facturación electrónica SIN.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E083 | **Cliente de Servicios Jurídicos** | `ROL-EXT-CLIENTE-ABOGADO` | Contrata abogado para juicio, asesoría, contrato, factura SIN | Cliente | Definido | — | ⏳ |
| E084 | **Cliente de Contabilidad / Auditoría** | `ROL-EXT-CLIENTE-CONTABLE` | Empresa que contrata contador o auditor externo, factura SIN | Cliente | — | — | ⏳ |
| E085 | **Cliente de Arquitectura / Ingeniería** | `ROL-EXT-CLIENTE-ARQUITECTO` | Contrata diseño, cálculo estructural, supervisión de obra | Cliente | — | — | ⏳ |
| E086 | **Cliente de Consultoría** | `ROL-EXT-CLIENTE-CONSULTORIA` | Empresa que contrata consultor en gestión, TI, RRHH, marketing | Cliente | — | — | ⏳ |
| E087 | **Dueño de Mascota / Paciente Veterinario** | `ROL-EXT-DUENO-MASCOTA` | Lleva su mascota a consulta veterinaria, recibe factura SIN | Cliente | — | — | ⏳ |
| E088 | **Cliente de Publicidad / Marketing** | `ROL-EXT-CLIENTE-PUBLICIDAD` | Contrata agencia de publicidad, diseño gráfico, campañas | Cliente | — | — | ⏳ |
| E089 | **Cliente de Investigación y Desarrollo** | `ROL-EXT-CLIENTE-ID` | Contrata servicios de I+D, laboratorio, ensayos técnicos | Cliente | — | — | ⏳ |

### 4.N — SECTOR N: Actividades de Servicios Administrativos y de Apoyo (7 actores externos)
> **CAEB Sección N · Divisiones 77–82** · Servicios de apoyo empresarial · Facturación electrónica SIN.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E090 | **Cliente de Agencia de Empleo / Postulante** | `ROL-EXT-POSTULANTE-EMPLEO` | Busca trabajo a través de agencia, presenta CV, entrevistas | Cliente | — | — | ⏳ |
| E091 | **Viajero / Cliente de Agencia de Viajes** | `ROL-EXT-VIAJERO` | Compra paquetes turísticos, boletos, reservas, factura SIN | Cliente | — | — | ⏳ |
| E092 | **Cliente de Seguridad Privada** | `ROL-EXT-CLIENTE-SEGURIDAD` | Empresa o particular que contrata vigilancia, monitoreo, CCTV | Cliente | — | — | ⏳ |
| E093 | **Cliente de Limpieza / Mantenimiento** | `ROL-EXT-CLIENTE-LIMPIEZA` | Contrata servicio de limpieza de oficinas, edificios, áreas comunes | Cliente | — | — | ⏳ |
| E094 | **Cliente de Alquiler de Equipos** | `ROL-EXT-CLIENTE-ALQUILER` | Alquila maquinaria, vehículos sin chofer, equipos para eventos | Cliente | — | — | ⏳ |
| E095 | **Organizador de Feria / Expositor** | `ROL-EXT-EXPOSITOR-FERIA` | Empresa que contrata stand en feria, factura SIN | Cliente | — | — | ⏳ |
| E096 | **Cliente de Call Center / Telemarketing** | `ROL-EXT-CLIENTE-CALLCENTER` | Empresa que contrata servicio de atención telefónica externalizada | Cliente | — | — | ⏳ |

### 4.O — SECTOR O: Administración Pública y Defensa (6 actores externos)
> **CAEB Sección O · División 84** · Relación Estado-Ciudadano · Facturación electrónica SIN.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E097 | **Ciudadano / Contribuyente** | `ROL-EXT-CIUDADANO` | Persona que realiza trámites, paga impuestos, recibe servicios del Estado. Identidad digital obligatoria para SIN, SEGIP, SERECI. | Cliente | Definido | — | ⏳ |
| E098 | **Beneficiario de Programa Social** | `ROL-EXT-BENEFICIARIO-SOCIAL` | Recibe bono, subsidio, transferencia condicionada del Estado | Cliente | — | — | ⏳ |
| E099 | **Postulante a Licitación Pública** | `ROL-EXT-POSTULANTE-LICITACION` | Empresa que participa en licitación estatal, SICOES, factura SIN | Proveedor | — | — | ⏳ |
| E100 | **Administrado / Solicitante de Trámite** | `ROL-EXT-ADMINISTRADO` | Persona que solicita licencia, permiso, certificado ante entidad pública | Cliente | — | — | ⏳ |
| E101 | **Elector / Ciudadano Habilitado** | `ROL-EXT-ELECTOR` | Ciudadano registrado en padrón electoral, vota en elecciones | Cliente | — | — | ⏳ |
| E102 | **Recluta / Conscripto** | `ROL-EXT-CONSCRIPTO` | Ciudadano que cumple servicio militar obligatorio | Cliente | — | — | ⏳ |

### 4.P — SECTOR P: ENSEÑANZA / EDUCACIÓN (9 actores externos)
> **CAEB Sección P · División 85** · 🔥 **Sector clave para facturación electrónica SIN.** · Colegios, universidades, institutos técnicos, academias.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E103 | **Alumno de Educación Inicial / Preescolar** | `ROL-EXT-ALUMNO-INICIAL` | Niño/a en jardín infantil o prekínder. Representado por padre/tutor. | Cliente | — | — | ⏳ |
| E104 | **Alumno de Educación Primaria** | `ROL-EXT-ALUMNO-PRIMARIA` | Estudiante de 1° a 6° de primaria. Representado por padre/tutor. Factura SIN a nombre del tutor. | Cliente | — | — | ⏳ |
| E105 | **Alumno de Educación Secundaria** | `ROL-EXT-ALUMNO-SECUNDARIA` | Estudiante de 1° a 6° de secundaria. Factura SIN. | Cliente | — | — | ⏳ |
| E106 | **Alumno Universitario** | `ROL-EXT-ALUMNO-UNIVERSITARIO` | Estudiante de pregrado en universidad pública o privada. Matrícula, factura SIN, título. | Cliente | Definido | — | ⏳ |
| E107 | **Alumno de Postgrado** | `ROL-EXT-ALUMNO-POSTGRADO` | Estudiante de maestría, doctorado, especialidad. Factura SIN. | Cliente | — | — | ⏳ |
| E108 | **Alumno de Instituto Técnico / Oficios** | `ROL-EXT-ALUMNO-TECNICO` | Estudiante de carrera técnica, oficio, capacitación laboral | Cliente | — | — | ⏳ |
| E109 | **Padre / Madre de Familia / Tutor Legal** | `ROL-EXT-TUTOR-EDUCATIVO` | Representante legal del alumno menor de edad. Firma contratos, recibe factura SIN, autoriza actividades. Es el cliente contractual. | Cliente | Definido | — | ⏳ |
| E110 | **Postulante / Aspirante** | `ROL-EXT-POSTULANTE-EDUCATIVO` | Persona que rinde examen de admisión o solicita ingreso a la institución | Cliente | — | — | ⏳ |
| E111 | **Egresado / Alumni** | `ROL-EXT-EGRESADO` | Ex-alumno graduado. Solicita certificados, título, participa en red de alumni | Cliente | — | — | ⏳ |

### 4.Q — SECTOR Q: SALUD HUMANA Y ASISTENCIA SOCIAL (10 actores externos)
> **CAEB Sección Q · Divisiones 86–88** · 🔥 **Sector clave para facturación electrónica SIN.** · Hospitales, clínicas, consultorios, laboratorios, asilos, guarderías.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E112 | **Paciente Ambulatorio** | `ROL-EXT-PACIENTE-AMBULATORIO` | Recibe consulta externa, retira receta, paga factura SIN. No requiere internación. | Cliente | Definido | — | ⏳ |
| E113 | **Paciente Hospitalizado / Internado** | `ROL-EXT-PACIENTE-HOSPITALIZADO` | Internado en hospital o clínica, recibe factura SIN, historia clínica | Cliente | Definido | — | ⏳ |
| E114 | **Paciente de Emergencia** | `ROL-EXT-PACIENTE-EMERGENCIA` | Ingresa por urgencias, atención inmediata, puede ingresar sin identificación | Cliente | — | — | ⏳ |
| E115 | **Paciente de Cirugía Programada** | `ROL-EXT-PACIENTE-CIRUGIA` | Cirugía electiva, consentimiento informado, factura SIN, presupuesto | Cliente | — | — | ⏳ |
| E116 | **Asegurado / Titular de Seguro de Salud** | `ROL-EXT-ASEGURADO-SALUD` | Titular de seguro médico (SUS, CNS, seguro privado). Factura SIN a la aseguradora. | Cliente | Definido | — | ⏳ |
| E117 | **Familiar / Acompañante de Paciente** | `ROL-EXT-FAMILIAR-PACIENTE` | Representante del paciente, firma consentimientos, recibe partes médicos | Cliente | — | — | ⏳ |
| E118 | **Donante de Sangre / Órganos** | `ROL-EXT-DONANTE` | Persona que dona sangre, plaquetas, órganos. Registro obligatorio. | Cliente | — | — | ⏳ |
| E119 | **Beneficiario de Asistencia Social** | `ROL-EXT-BENEFICIARIO-ASISTENCIA` | Adulto mayor en asilo, niño en guardería, persona con discapacidad en centro de atención | Cliente | — | — | ⏳ |
| E120 | **Cliente de Farmacia (Comprador de Medicamentos)** | `ROL-EXT-CLIENTE-FARMACIA-Q` | Compra medicamentos con receta, factura SIN para descargo de IVA | Cliente | Definido | — | ⏳ |
| E121 | **Paciente de Laboratorio Clínico** | `ROL-EXT-PACIENTE-LABORATORIO` | Se realiza análisis clínicos, recibe resultados, factura SIN | Cliente | — | — | ⏳ |

### 4.R — SECTOR R: Arte, Entretenimiento y Recreación (6 actores externos)
> **CAEB Sección R · Divisiones 90–93** · Facturación electrónica SIN para eventos y espectáculos.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E122 | **Espectador / Asistente a Evento** | `ROL-EXT-ESPECTADOR` | Compra entrada para concierto, teatro, cine, fútbol, factura SIN | Cliente | — | — | ⏳ |
| E123 | **Visitante de Museo / Biblioteca** | `ROL-EXT-VISITANTE-MUSEO` | Ingresa a museo, biblioteca, archivo, sitio histórico | Cliente | — | — | ⏳ |
| E124 | **Deportista / Jugador** | `ROL-EXT-DEPORTISTA` | Miembro de club deportivo, compite, entrena | Cliente | — | — | ⏳ |
| E125 | **Socio de Club / Miembro** | `ROL-EXT-SOCIO-CLUB` | Socio de club deportivo, social, recreativo. Paga membresía, factura SIN. | Cliente | — | — | ⏳ |
| E126 | **Cliente de Gimnasio** | `ROL-EXT-CLIENTE-GIMNASIO` | Miembro de gimnasio, paga mensualidad, factura SIN | Cliente | — | — | ⏳ |
| E127 | **Jugador de Juegos de Azar / Apuestas** | `ROL-EXT-JUGADOR-AZAR` | Participa en lotería, casino, apuestas deportivas reguladas | Cliente | — | — | ⏳ |

### 4.S — SECTOR S: Otras Actividades de Servicios (7 actores externos)
> **CAEB Sección S · Divisiones 94–96** · Servicios personales, asociaciones, reparaciones.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E128 | **Cliente de Peluquería / Salón de Belleza** | `ROL-EXT-CLIENTE-PELUQUERIA` | Cortes, tintes, tratamientos capilares, factura SIN | Cliente | — | — | ⏳ |
| E129 | **Cliente de Lavandería / Tintorería** | `ROL-EXT-CLIENTE-LAVANDERIA` | Lava, plancha, limpia prendas, factura SIN | Cliente | — | — | ⏳ |
| E130 | **Feligrés / Miembro de Asociación Religiosa** | `ROL-EXT-FELIGRES` | Miembro de iglesia, templo o congregación religiosa | Cliente | — | — | ⏳ |
| E131 | **Afiliado Sindical / Gremial** | `ROL-EXT-AFILIADO-SINDICAL` | Trabajador afiliado a sindicato o asociación gremial | Cliente | — | — | ⏳ |
| E132 | **Cliente de Servicios Funerarios** | `ROL-EXT-CLIENTE-FUNERARIA` | Familiar del difunto, contrata velatorio, cremación, factura SIN | Cliente | — | — | ⏳ |
| E133 | **Cliente de Reparación de Efectos Personales** | `ROL-EXT-CLIENTE-REPARACION` | Reparación de celular, computadora, electrodoméstico, calzado | Cliente | — | — | ⏳ |
| E134 | **Miembro de Asociación Empresarial** | `ROL-EXT-MIEMBRO-ASOCIACION` | Empresa afiliada a cámara de comercio, industria, federación | Cliente | — | — | ⏳ |

### 4.T — SECTOR T: Hogares como Empleadores (2 actores externos)
> **CAEB Sección T · Divisiones 97–98** · Trabajo doméstico · Facturación SIN para aportes AFP.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E135 | **Empleador Doméstico** | `ROL-EXT-EMPLEADOR-DOMESTICO` | Persona que contrata trabajador del hogar, paga AFP, factura SIN | Cliente | Definido | — | ⏳ |
| E136 | **Trabajador del Hogar** | `ROL-EXT-TRABAJADOR-HOGAR` | Trabajadora doméstica registrada, recibe salario, aporta AFP | Proveedor | — | — | ⏳ |

### 4.U — SECTOR U: Organizaciones Extraterritoriales (3 actores externos)
> **CAEB Sección U · División 99** · Embajadas, consulados, organismos internacionales.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E137 | **Diplomático / Funcionario Internacional** | `ROL-EXT-DIPLOMATICO` | Personal acreditado de embajada, consulado u organismo internacional | Cliente | — | — | ⏳ |
| E138 | **Beneficiario de Cooperación Internacional** | `ROL-EXT-BENEFICIARIO-COOPERACION` | Persona o comunidad que recibe ayuda de organismo internacional (ONU, BM, OEA) | Cliente | — | — | ⏳ |
| E139 | **Solicitante de Visa / Servicio Consular** | `ROL-EXT-SOLICITANTE-VISA` | Ciudadano que tramita visa, pasaporte, documento consular | Cliente | — | — | ⏳ |

---

### Resumen de Actores Externos por Sector CAEB

| Sección CAEB | Sector | Cantidad | Actores clave |
|-------------|--------|----------|---------------|
| A | Agricultura y Ganadería | 6 | Comprador agro, Acopiador, Exportador |
| B | Minería | 5 | Comprador minerales, Inversionista, Comunidad |
| C | Industria Manufacturera | 8 | Cliente mayorista/minorista industrial, Proveedor MP, Maquilador |
| D | Electricidad, Gas | 5 | Usuario residencial/industrial, Generador independiente |
| E | Agua, Desechos | 4 | Usuario agua, Generador residuos |
| F | Construcción | 6 | Propietario obra, Inversionista, Fiscalizador |
| **G** | **Comercio (Compra/Venta)** | **16** | **Cliente minorista, Cliente mayorista, Cliente corporativo, Cliente e-commerce, Proveedor, Artesano** |
| H | Transporte y Almacenamiento | 7 | Pasajero, Remitente, Consignatario |
| I | Alojamiento y Comidas | 6 | Huésped, Comensal, Cliente eventos, Cliente delivery |
| J | Información y Comunicaciones | 6 | Suscriptor, Cliente SaaS, Anunciante |
| K | Financieras y Seguros | 8 | Cuentahabiente, Asegurado, Inversionista, Deudor |
| L | Inmobiliarias | 5 | Inquilino, Comprador inmueble, Tasador |
| M | Profesionales, Científicas, Técnicas | 7 | Cliente abogado, Cliente contable, Dueño mascota |
| N | Servicios Administrativos | 7 | Postulante empleo, Viajero, Cliente seguridad |
| O | Administración Pública | 6 | Ciudadano, Beneficiario social, Elector |
| **P** | **Enseñanza / Educación** | **9** | **Alumno (6 niveles), Padre/Tutor, Postulante, Egresado** |
| **Q** | **Salud y Asistencia Social** | **10** | **Paciente (4 tipos), Asegurado, Familiar, Donante, Cliente farmacia** |
| R | Arte, Entretenimiento, Deporte | 6 | Espectador, Deportista, Socio club, Cliente gimnasio |
| S | Otras Actividades de Servicios | 7 | Cliente peluquería, Feligrés, Afiliado sindical |
| T | Hogares como Empleadores | 2 | Empleador doméstico, Trabajador del hogar |
| U | Organizaciones Extraterritoriales | 3 | Diplomático, Beneficiario cooperación |
| **TOTAL** | **21 sectores CAEB** | **139** | — |
| VIS | **Visitantes (Transversal)** | **4** | **Visitante General, Proveedor, Auditor, VIP** |
| CTR | **Contratistas Externos (Transversal)** | **3** | **Técnico Servicio, Contratista Obra, Instalador** |
| **TOTAL** | **+ Transversales** | **146** | **Actores externos completos** |

---

## 5. Jerarquía Organizacional Genérica (Actualizada — incluye Actores Externos)

Todos los roles se clasifican en 7 niveles para facilitar la herencia H-RBAC:

| Nivel | Código | Descripción | Ejemplos |
|-------|--------|-------------|----------|
| **SU — Superusuario** | `TIER-SUPERUSUARIO` | Máximo permiso global. Bootstrap, DR, mantenimiento mayor. Uno solo activo. | Superusuario SBOS |
| **SYS — Sistema** | `TIER-SISTEMA` | Administración de plataforma, módulos, tenants, bootstrap. Sin relación laboral con ningún tenant. | Admin Proyecto, Admin bAuth, Admin Tenant, bos-agent |
| **N0 — Externo** | `TIER-EXTERNO` | Actor que recibe el servicio (ISO 9001 "cliente"). Identidad verificable, autorización limitada y temporal. | Cliente, Paciente, Alumno, Ciudadano, Visitante |
| **N1 — Operativo** | `TIER-OPERATIVO` | Ejecución directa, sin personal a cargo | Cajero, Vendedor, Operario, Peón |
| **N2 — Técnico** | `TIER-TECNICO` | Conocimiento especializado, sin personal a cargo | Contador, Analista, Enfermero, SysAdmin |
| **N3 — Supervisión** | `TIER-SUPERVISOR` | Supervisa equipos pequeños (1-10 personas) | Supervisor de Tienda, Jefe de Turno |
| **N4 — Gerencia Media** | `TIER-GERENCIA-MEDIA` | Gestiona departamentos, presupuesto, estrategia | Jefe de RRHH, Gerente de Sucursal |
| **N5 — Dirección** | `TIER-DIRECCION` | Dirección estratégica de la organización | Gerente General, Director, CEO |

### 5.1 El Caso Especial del VISITANTE — Actor Transversal

**Todo visitante es un cliente del sistema de control de acceso.** Aplica a cualquier
organización, de cualquier sector CAEB — una fábrica, un hospital, un colegio, una
oficina pública. El visitante:

- Recibe una **identidad temporal** al registrarse en recepción
- Obtiene **autorización limitada** (zonas permitidas, horario, acompañante)
- Genera **trazabilidad** (quién entró, a qué hora, a quién visitó, cuándo salió)
- Puede recibir una **credencial temporal** (badge de visita, QR de acceso)
- Es un **cliente** del sistema de seguridad/recepción de la organización

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E140 | **Visitante General** | `ROL-EXT-VISITANTE` | Persona que ingresa temporalmente a las instalaciones. Se registra en recepción, recibe credencial temporal, queda registrado en bitácora. Aplica a TODOS los sectores CAEB. | Cliente | Definido | — | ⏳ |
| E141 | **Visitante Proveedor / Contratista** | `ROL-EXT-VISITANTE-PROVEEDOR` | Proveedor o contratista que visita para entregar materiales, cotizar, mantener equipos | Cliente | Definido | — | ⏳ |
| E142 | **Visitante Auditor / Inspector** | `ROL-EXT-VISITANTE-AUDITOR` | Auditor externo, inspector regulatorio, certificador que visita para evaluación | Cliente | — | — | ⏳ |
| E143 | **Visitante VIP / Invitado Especial** | `ROL-EXT-VISITANTE-VIP` | Invitado institucional con acceso a zonas ejecutivas, escoltado por anfitrión | Cliente | — | — | ⏳ |

### 5.2 El Contratista / Técnico Externo — Autorización en Doble Dominio

**Un plomero, electricista, gasista o técnico externo necesita autorización en DOS dominios
simultáneos,** y ambos deben ser gestionados por bAuth:

| Dominio | Qué autoriza | Cómo lo gestiona bAuth |
|---------|-------------|----------------------|
| **Dominio Físico** | Acceso a las instalaciones (zonas, horario, escolta) | `ROL-EXT-VISITANTE-PROVEEDOR` — credencial temporal, bitácora de ingreso/salida |
| **Dominio Financiero** | Emitir factura SIN, recibir pago, ser dado de alta como proveedor | `ROL-EXT-PROVEEDOR-SERV-COMERCIO` — factura electrónica, orden de servicio |

**Sin el dominio físico**, el plomero no puede entrar. **Sin el dominio financiero**, no puede
cobrar. Ambos son necesarios y bAuth debe orquestarlos como una sola identidad con
múltiples autorizaciones.

| # | Actor Externo | Código bAuth | Descripción | Tipo | Estado | Vitácora | Plantilla |
|---|-------------|-------------|-------------|------|--------|----------|
| E144 | **Técnico de Servicio / Contratista de Mantenimiento** | `ROL-EXT-TECNICO-SERVICIO` | Plomero, electricista, gasista, técnico HVAC, cerrajero que acude a las instalaciones a reparar/mantener. Requiere autorización física (acceso) + financiera (factura SIN). | Proveedor | Definido | — | ⏳ |
| E145 | **Contratista de Obra Menor** | `ROL-EXT-CONTRATISTA-OBRA` | Albañil, pintor, jardinero que ejecuta trabajos temporales en las instalaciones | Proveedor | — | — | ⏳ |
| E146 | **Técnico Instalador** | `ROL-EXT-TECNICO-INSTALADOR` | Instala equipos, cableado, sensores, cámaras en las instalaciones del cliente | Proveedor | — | — | ⏳ |

---

## 6. DEPENDENCIAS Y HERENCIA DE PRIVILEGIOS — Motor BitMask Dual

> **Principio NIST RBAC:** toda jerarquía de roles es un **grafo acíclico dirigido (DAG)**. Una arista `r₁ → r₂` significa que r₁ es **junior** a r₂, y r₂ **hereda** todos los privilegios de r₁.
>
> **⚠️ CORRECCIÓN ARQUITECTURAL (Junio 2026):** Este documento aplicaba OR/AND bitwise directamente sobre un solo u64 con códigos de átomo. Ese modelo produce **escalamiento silencioso de privilegios** (`1 OR 2 = 3 → "eliminar" sin que nadie lo otorgara`). El modelo ha sido reemplazado por el **BitMask Dual** definido en `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md`.
>
> **Base normativa:**
> - **NIST RBAC Model §4.2** — Role Hierarchies as Partial Orders (DAG). La herencia es reflexiva, transitiva y antisimétrica. El grafo DEBE ser acíclico.
> - **bAuth PrivilegeEngine** — BitMask Dual: dos estructuras separadas con propósitos distintos. La herencia opera como OR bitwise sobre el Rol BitMask (one-hot encoding), NUNCA sobre el BitMask Átomo (label encoding).
> - **Closure Table Pattern (SQL)** — precomputa todas las relaciones ancestro→descendiente. Una sola consulta JOIN resuelve la pertenencia jerárquica sin recursión. Usado por AWS IAM, Google Zanzibar, Cerbos.
>
> **Documentos fuente del modelo corregido:**
> - `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md` §4-6 — BitMask Átomo (64 bits) + Rol BitMask (N bits)
> - `SBOS-MANUAL-BAUTH-COMPONENT-ROLES.md` v1.7 — bAuth administra el BitMask, no KC ni Tryton-PDP
> - `SBOS-MANUAL-BAUTH-D12-BLOCKCHAIN-WALLET-CONTROL.md` v2.1 — D12 dominio blockchain + 3 capas
> - `SBOS-BAUTH-EVALUACION-INTEGRAL-v2.2.md` — Evaluación integral del proyecto bAuth

---

### 6.0 Conceptos Clave del Motor BitMask Dual

#### 6.0.1 Dos estructuras separadas — el error que se corrigió

El modelo anterior usaba un solo u64 donde el código del átomo (1=nuevo, 2=editar, 3=eliminar) se combinaba con OR/AND. Esto producía **falsos permisos**: `1 OR 2 = 3` → el código 3 es "eliminar", un permiso que nadie otorgó.

**Raíz del error:** confundir dos propósitos en la misma estructura.

| Propósito | Pregunta que responde | Estructura | Codificación | Se combina con bitwise? |
|-----------|----------------------|------------|-------------|------------------------|
| **Identificar** un átomo | ¿Qué acción es esta? | **BitMask Átomo** (64 bits) | Label encoding | ❌ NUNCA — solo igualdad y AND con máscara fija |
| **Combinar** átomos entre roles | ¿Quién tiene qué? | **Rol BitMask** (N bits) | One-hot encoding | ✅ OR / AND / XOR / AND NOT |

#### 6.0.2 BitMask Átomo (64 bits) — identifica, no combina

Es un número de 64 bits que identifica un átomo específico de forma compacta. Es análogo a una dirección IPv4: no es una bandera de "sí/no", es una dirección estructurada en campos que juntos apuntan a una acción única en el catálogo global.

```
┌─────────────────────────────────────────────────────────────────┐
│                    BitMask Átomo (64 bits)                      │
│                                                                  │
│  Dominio Contextual (32 bits)     Dominio Lógico (32 bits)      │
│  [8 res][4 dom][9 app][11 grupo] [6 res][2 pol][24 átomo]      │
└─────────────────────────────────────────────────────────────────┘

Dominio Contextual — identifica DÓNDE vive el átomo:
  bits 0-7:   Reservado (extensión futura)
  bits 8-11:  Dominio de soberanía (4 bits → 16 valores, D1–D12)
  bits 12-20: Aplicación (9 bits → 512 aplicaciones)
  bits 21-31: Grupo funcional (11 bits → 2,048 grupos por app)

Dominio Lógico — identifica QUÉ hace el átomo:
  bits 0-5:   Reservado (extensión futura)
  bits 6-7:   Estado de política (00=no aplica, 01=pendiente, 10=aprobado, 11=rechazado)
  bits 8-31:  Código del verbo (24 bits → 16,777,216 átomos por grupo)

Vocabulario de verbos (fijo y global):
  nuevo=1, editar=2, eliminar=3, ver=4
```

**Operaciones válidas sobre el BitMask Átomo:**
- Comparación de igualdad: `átomo_solicitado == átomo_del_botón`
- AND con máscara fija para extraer campos (dominio, app, grupo, verbo, política)
- **NUNCA** OR entre dos BitMask Átomo — produce identificadores de otros átomos

#### 6.0.3 Rol BitMask (N bits) — combina, no identifica

Para combinar roles se usa una estructura separada: el **Rol BitMask**. Cada átomo del catálogo ocupa una posición de bit fija e independiente (one-hot encoding). Un rol se representa marcando con `1` las posiciones de los átomos que otorga.

```
Catálogo (posiciones fijas, orden inamovible):

Bit  0: Tryton.Plan de Cuentas.nuevo
Bit  1: Tryton.Plan de Cuentas.editar
Bit  2: Tryton.Plan de Cuentas.eliminar
Bit  3: Tryton.Comprobantes.nuevo
Bit  4: Tryton.Comprobantes.editar
Bit  5: Tryton.Comprobantes.eliminar

Rol Contador Senior   (átomos 0,1,3,4): 0b011011 → posiciones 0,1,3,4 = 1
Rol Auxiliar Contable (átomos 1,5):      0b100010 → posiciones 1,5 = 1
```

**Operaciones válidas sobre el Rol BitMask:**

| Operación | Objetivo | Cuándo usarla |
|-----------|----------|---------------|
| **OR** | Ampliar — unión de roles | Usuario cubre varios roles simultáneamente |
| **AND** | Reducir al mínimo común | Delegación: el senior opera como el junior |
| **AND NOT** | Quitar un átomo específico | Suspender capacidad puntual (ej. FINANCIAL_APPROVE durante auditoría) |
| **XOR** | Delta entre dos estados | Auditar qué cambió en una reasignación |

**El resultado es idéntico al de la teoría de conjuntos — y es bitwise de verdad**, sin riesgo de escalamiento de privilegios porque cada átomo tiene su propio bit independiente.

#### 6.0.4 Relación entre las dos estructuras

```
Tabla 1: bos_atom_catalog (fuente de verdad)
  Cada fila = un átomo con su BitMask Átomo de 64 bits (label encoding)
  atom_position = posición ordinal fija en el catálogo global

Tabla 2: bos_role_atom (Rol BitMask en forma relacional)
  Cada fila = (role_id, atom_position, allowed=true)
  La posición es el índice del bit en el vector one-hot del rol
```

#### 6.0.5 Conceptos de herencia

| Concepto | Definición | Operación |
|----------|-----------|-----------|
| **Máscara Propia** | Átomos asignados directamente a un rol | Definido en `bos_role_atom` |
| **Máscara Efectiva** | Átomos propios + todos los heredados de roles junior | `mask_eff(rol) = mask_own(rol) \| mask_eff(junior₁) \| mask_eff(junior₂) \| ...` |
| **Herencia Transitiva** | Si A→B y B→C, entonces A→C | El OR se propaga recursivamente por el DAG |
| **Vista (Check)** | ¿Tiene el rol este átomo? | `(rol_bitmask >> atom_position) & 1 != 0` |
| **Anti-ciclo** | Un rol NO puede heredar de sí mismo | Detección antes de `AddEdge(r₁→r₂)` |
| **SoD** | Roles en conflicto no pueden asignarse al mismo usuario | Static SoD: prohibido. Dynamic SoD: prohibido en misma sesión |

---

### 6.1 Árbol de Dependencias — Jerarquía Completa SBOS (DAG)

Siguiendo el modelo NIST Figure 3, la jerarquía SBOS forma un DAG con 5 niveles
donde el permiso fluye desde las hojas (N4 Bootstrap) hasta la raíz (SU).

```
                          SU (Superusuario)
                           |
            +--------------+--------------+
            |              |              |
          N1-PLATAFORMA    |              |
            |              |              |
     +------+------+      |              |
     |      |      |      |              |
   S002   S003   S004   S005            |
   (Proy) (Seg)  (Infra) (SRE)          |
     |                              (bypass directo SU→N2
     |                               para DR/emergencia)
     +------+-------+-------+-------+-------+-------+-------+------+
            |       |       |       |       |       |       |      |
     N2:   S006    S007    S008    S009    S010    S011    S012   S013-S015
          (bAuth) (bKernel)(biedata)(bSearch)(NEXUS) (BOS)   (DBA) (Vault,Kong,KC)
            |
     +------+-------+-------+-------+
     |      |       |       |       |
 N3: S016  S017    S018    S019    ← Admin Tenant/Sucursal (uno por empresa)
     |      |       |       |
     +------+-------+-------+  (cada N3 administra roles N0–N5 de su tenant)

 N4:  S020–S048  ← Bootstrap. Roles M2M. Sin dependencias entre sí.
                   Cada uno es hoja terminal. mTLS obligatorio.
                   Solo heredan hacia arriba (junior→senior).
                   No reciben herencia de nadie (son hojas).
```

**Reglas de herencia:**
1. **Reflexiva:** todo rol se hereda a sí mismo (mask_eff ⊇ mask_own)
2. **Transitiva:** si S020→S011→S002→S001, entonces S001 hereda de S020
3. **Antisimétrica:** si A hereda de B y B hereda de A, entonces A=B (no puede haber ciclos)
4. **Aditiva:** la máscara efectiva es la unión (OR) de todas las máscaras en el camino
5. **Sin atajos ilegales:** SU no puede saltarse la cadena de herencia excepto en break-glass

---

### 6.2 Tabla de Dependencias — Relación Padre→Hijo

Cada rol senior (padre) hereda de sus roles junior (hijos). Esta tabla es la
fuente de verdad para construir el closure table y calcular máscaras efectivas.

| # | Rol Senior (hereda de...) | Roles Junior (...hereda a) | Nivel | Tipo de Herencia |
|---|--------------------------|---------------------------|-------|-----------------|
| D01 | **SU (S001)** | S002, S003, S004, S005 | SU→N1 | Herencia total + break-glass directo a N2 |
| D02 | **Admin Proyecto (S002)** | S006–S015 (todos los admin de módulo) | N1→N2 | Herencia total. Crea y destruye módulos. |
| D03 | **Admin Seguridad (S003)** | S006 (bAuth), S018 (Seg Tenant) | N1→N2/N3 | Solo módulos de seguridad e identidad |
| D04 | **Admin Infra (S004)** | S012–S015 (DBA, Vault, Kong, KC), S039–S044 (infra services) | N1→N2/N4 | Solo infraestructura y plataforma |
| D05 | **Admin SRE (S005)** | S047–S048 (observabilidad) | N1→N4 | Solo monitoreo y logs |
| D06 | **Admin bAuth (S006)** | S016 (Admin Tenant), S025–S027 (bauth internals) | N2→N3/N4 | Crea tenants; gestiona motor de identidad |
| D07 | **Admin bKernel (S007)** | S028–S030 (bkernel internals) | N2→N4 | Solo su propio daemon |
| D08 | **Admin biedata (S008)** | S031–S033 (biedata internals) | N2→N4 | Solo su propio daemon |
| D09 | **Admin bSearch (S009)** | S034–S035 (bsearch internals) | N2→N4 | Solo su propio daemon |
| D10 | **Admin NEXUS (S010)** | S036–S038 (nexus internals) | N2→N4 | Solo su propio daemon |
| D11 | **Admin BOS (S011)** | S020–S024 (bos internals) | N2→N4 | Solo su propio daemon |
| D12 | **Admin Datos/DBA (S012)** | S039–S040 (postgres, redis) | N2→N4 | Solo bases de datos |
| D13 | **Admin Vault (S013)** | S042 (vault-admin) | N2→N4 | Solo secretos |
| D14 | **Admin Kong (S014)** | S043 (kong-admin) | N2→N4 | Solo API Gateway |
| D15 | **Admin Keycloak (S015)** | S041 (keycloak-admin) | N2→N4 | Solo SSO |
| D16 | **Admin Tenant (S016)** | S017 (Sucursal), S018 (Seg Tenant), S019 (Fact Tenant) | N3→N3 | Gestiona sucursales y seguridad local |
| D17 | **Admin Sucursal (S017)** | Roles de negocio N0–N5 dentro de su sucursal | N3→N0–N5 | Administra personal y clientes locales |
| D18 | **Admin Seguridad Tenant (S018)** | Roles de seguridad N1–N3 del tenant | N3→N1–N3 | Cumplimiento fiscal y regulatorio |
| D19 | **Admin Facturación Tenant (S019)** | Operadores de facturación SIN del tenant | N3→N1 | Dosificación, emisión, reportes |

> **Nota:** Los roles N4 Bootstrap (S020–S048) son **hojas terminales** del DAG. No tienen
> dependencias entre sí. Cada uno hereda hacia arriba a su admin de módulo (N2). Unos pocos
> (S039–S044, S047–S048) también heredan hacia N1 (Infra/SRE).

---

### 6.3 Mapeo BitMask Dual — Ejemplo de Propagación

bAuth implementa el **BitMask Dual**: BitMask Átomo (64 bits) para identificar, Rol BitMask (N bits) para combinar. La herencia propaga bits del Rol BitMask mediante OR.

**Ejemplo concreto — Cadena de herencia para `bos-agent`:**

```
N4: bos-agent (S020)          
    Rol BitMask propio: posiciones 0,1 = 1  (leer estado, escribir estado)
    
    BitMask Átomo de "leer estado":   0x00000000_00000001  (D1, BOS, state, ver=4)
    BitMask Átomo de "escribir estado": 0x00000000_00000002  (D1, BOS, state, editar=2)
                                     ↓ OR (sobre Rol BitMask, no sobre BitMask Átomo)
N2: Admin BOS (S011)              
    Rol BitMask propio: posiciones 2-15 = 1 (gestionar fichas, sagas, ctx)
    Rol BitMask efectivo = propio | efectivo(S020)
                         = {2..15} ∪ {0,1}
                         = {0..15}
                                     ↓ OR
N1: Admin Proyecto (S002)         
    Rol BitMask propio: posiciones 16-23 = 1 (crear módulos, tenants)
    Rol BitMask efectivo = propio | efectivo(S011)
                         = {16..23} ∪ {0..15}
                         = {0..23}
                                     ↓ OR
SU: Superusuario (S001)           
    Rol BitMask propio: todas las posiciones (acceso total)
    Rol BitMask efectivo = propio | efectivo(S002) | efectivo(S003) | ...
                         = TODAS las posiciones del catálogo
```

**Operación de verificación (check de permiso):**
```c
// ¿Puede Admin BOS (S011) instalar una ficha?
// atom_position = 5 (corresponde a "bos.ficha.install" en el catálogo)

uint64_t *rol_bitmask = rol_bitmask_eff[S011];  
// El Rol BitMask es un array de bits (N posiciones).
// La posición 5 del Admin BOS es 1 porque la heredó de bos-agent.

bool authorized = bit_test(rol_bitmask, 5);  // TRUE
```

> **⚠️ Importante:** El check NO opera sobre el BitMask Átomo (64 bits). Opera sobre el Rol BitMask (vector de N bits) donde cada posición es un bit independiente. Operar sobre el BitMask Átomo directamente reintroduce el error de escalamiento.

---

### 6.4 Closure Table — Resolución Eficiente de Herencia

Para evitar recorrer el DAG en cada verificación, bAuth implementa el patrón
**Closure Table** (usado por AWS IAM, Google Zanzibar, Cerbos). Se precomputan
todos los pares (ancestro, descendiente) en una tabla SQL.

**Esquema:**
```sql
CREATE TABLE rol_closure (
    ancestro_id   VARCHAR(32) NOT NULL,   -- ej: 'ROL-SYS-SUPERUSUARIO'
    descendiente_id VARCHAR(32) NOT NULL, -- ej: 'ROL-SYS-BOS-AGENT'
    profundidad   INT NOT NULL,          -- 0 = mismo rol, 1 = hijo directo, 2 = nieto...
    PRIMARY KEY (ancestro_id, descendiente_id)
);

-- Índice para resolver "¿hereda el rol X del rol Y?"
CREATE INDEX idx_closure_desc ON rol_closure(descendiente_id);
```

**Poblar al crear un rol (ej: Admin BOS → bos-agent):**
```sql
-- Paso 1: Self-reference (profundidad 0)
INSERT INTO rol_closure VALUES ('ROL-SYS-BOS-AGENT', 'ROL-SYS-BOS-AGENT', 0);

-- Paso 2: Hijo directo (profundidad 1)
INSERT INTO rol_closure VALUES ('ROL-SYS-ADMIN-BOS', 'ROL-SYS-BOS-AGENT', 1);

-- Paso 3: Cierre transitivo — Admin BOS hereda todo lo que bos-agent ya heredaba
INSERT INTO rol_closure (ancestro_id, descendiente_id, profundidad)
SELECT 'ROL-SYS-ADMIN-BOS', rc.descendiente_id, rc.profundidad + 1
FROM rol_closure rc
WHERE rc.ancestro_id = 'ROL-SYS-BOS-AGENT';
```

**Consulta de permiso efectivo (una sola query, sin recursión):**
```sql
-- ¿El rol 'ROL-SYS-ADMIN-BOS' tiene el átomo en posición 5?
-- Basta verificar si él o CUALQUIERA de sus descendientes lo tiene.

SELECT 1
FROM rol_closure rc
JOIN bos_privilege.bos_role_atom ra ON ra.role_id = rc.descendiente_id
WHERE rc.ancestro_id = 'ROL-SYS-ADMIN-BOS'   -- ancestro = el rol que queremos verificar
  AND ra.atom_position = 5                    -- posición del átomo en el Rol BitMask
  AND ra.allowed = TRUE
LIMIT 1;
-- Si devuelve fila → autorizado. Si no → denegado.
```

---

### 6.5 Propagación de Permisos hacia Roles de Negocio (N0–N5)

Los roles sistémicos (SU, N1–N4) son la columna vertebral. Los roles de negocio
(N0 Externo, N1 Operativo... N5 Dirección) cuelgan del **Admin de Tenant (S016)**
y **Admin de Sucursal (S017)** según este esquema:

```
S016 (Admin Tenant)
  ├── S017 (Admin Sucursal Matriz)
  │   ├── Gerente General (N5)
  │   │   ├── Jefe de Local (N4)
  │   │   │   ├── Supervisor de Tienda (N3)
  │   │   │   │   ├── Cajero (N1)
  │   │   │   │   └── Vendedor (N1)
  │   │   │   └── Encargado de Depósito (N1)
  │   │   └── Contador (N2)
  │   ├── Cliente Minorista (N0)
  │   └── Visitante General (N0)
  └── S017 (Admin Sucursal Norte)
      └── (misma estructura por sucursal)
```

**Regla de propagación:**
- El Rol BitMask del junior se propaga por OR hacia arriba dentro del tenant
- Un Cajero (N1) tiene bits en posiciones de caja, venta, arqueo
- Su Supervisor (N3) hereda esas posiciones + las propias de supervisión
- El Gerente General (N5) hereda TODAS las posiciones de negocio del tenant
- El Admin Tenant (S016) hereda todo el tenant
- **El dominio de cada átomo está en su BitMask Átomo (Dominio Contextual, bits 8-11), no en el Rol BitMask.** La evaluación de dominio (D1, D2, D3...) ocurre en el paso de política, después de la verificación de Rol BitMask

---

### 6.6 Jerarquía de Roles de Negocio — Cadena N0→N5 dentro del Tenant

**Todos los roles tienen una posición en la jerarquía.** Ningún rol existe aislado.
Dentro de cada tenant, los roles de negocio forman una cadena de herencia que va
desde el actor externo (N0) hasta la dirección (N5), pasando por el Admin Tenant (S016).

**Cadena canónica de herencia de negocio (aplica a cualquier sector CAEB):**

```
S016 (Admin Tenant) ─── dueño del tenant completo
  │
  └── S017 (Admin Sucursal) ─── un S017 por sucursal
        │
        ├── N5 DIRECCIÓN ─── Gerente General, Director
        │     │
        │     └── N4 GERENCIA MEDIA ─── Jefe Local, Jefe RRHH, Jefe Logística
        │           │
        │           ├── N3 SUPERVISIÓN ─── Supervisor Tienda, Supervisor Planta
        │           │     │
        │           │     └── N1 OPERATIVO ─── Cajero, Vendedor, Operario
        │           │           │
        │           │           └── N0 EXTERNO ─── Cliente Minorista, Visitante
        │           │
        │           └── N2 TÉCNICO ─── Contador, Analista, SysAdmin
        │                 │
        │                 └── N1 OPERATIVO ─── Asistente Contable, Soporte
        │                       │
        │                       └── N0 EXTERNO ─── Cliente de Consultoría
        │
        └── N0 EXTERNO (directo) ─── Paciente, Alumno, Ciudadano
              (roles externos que interactúan directamente con la sucursal,
               sin cadena de empleados intermedios)
```

**Reglas de herencia de negocio:**

| Regla | Descripción | Fundamento |
|-------|-------------|-----------|
| **R1 — Ascendente** | Los permisos fluyen de N0 hacia arriba: N5 hereda todo lo de N4, que hereda todo lo de N3... hasta N0 | NIST RBAC §4.2: `r_junior → r_senior` |
| **R2 — Transitiva por cadena** | Si Cajero(N1)→Supervisor(N3)→Jefe Local(N4)→Gerente(N5), entonces Gerente hereda posiciones del Cajero | NIST DAG transitividad |
| **R3 — Sin salto de rama** | Un Contador (rama N2→N1) NO hereda de un Vendedor (rama N3→N1). Solo hereda de su propia cadena. | NIST Limited Hierarchy (tree) |
| **R4 — Externa→Interna** | N0 (cliente) es el extremo junior. Todos los roles internos heredan sus posiciones. | ISO 9001: el cliente es el origen de la cadena de valor |
| **R5 — Operación sobre Rol BitMask** | Las operaciones de herencia (OR, AND) operan sobre el Rol BitMask (posiciones de bit). El dominio del átomo se verifica en el paso de política, no en la herencia. | Manual Privilegios §5-6 |
| **R6 — SoD intra-tenant** | Roles en conflicto no pueden asignarse al mismo usuario. Ej: Cajero y Auditor en la misma sucursal = prohibido | NIST AC-5 Static SoD |

---

### 6.7 Tabla de Dependencias de Negocio por Sector

Cada sector CAEB tiene su propia cadena de herencia. A continuación las cadenas
más representativas:

#### Comercio Minorista (CAEB G47)

```
S017 (Admin Sucursal)
  └── Gerente General (N5) ─── ROL-GERENTE-GENERAL
        └── Jefe de Local (N4) ─── ROL-JEFE-LOCAL
              ├── Supervisor de Tienda (N3) ─── ROL-SUPERVISOR-TIENDA
              │     ├── Cajero (N1) ─── ROL-CAJERO
              │     ├── Vendedor de Piso (N1) ─── ROL-VENDEDOR
              │     └── Reponedor (N1) ─── ROL-REPONEDOR
              │           └── Cliente Minorista (N0) ─── ROL-EXT-CLIENTE-MINORISTA
              ├── Encargado de Depósito (N1) ─── ROL-ENCARGADO-DEPOSITO
              │     └── Proveedor Nacional (N0) ─── ROL-EXT-PROVEEDOR-NACIONAL
              └── Encargado de Facturación (N1) ─── ROL-ENCARGADO-FACTURACION
                    └── Cliente Mayorista (N0) ─── ROL-EXT-CLIENTE-MAYORISTA
```

#### Salud (CAEB Q86)

```
S017 (Admin Sucursal)
  └── Director de Clínica (N5)
        └── Administrador de Clínica (N4) ─── ROL-ADMIN-CLINICA
              ├── Médico General (Profesional) ─── ROL-MEDICO-GENERAL
              │     ├── Enfermero/a (Profesional) ─── ROL-ENFERMERO
              │     │     └── Auxiliar de Enfermería (N1) ─── ROL-AUXILIAR-ENFERMERIA
              │     └── Paramédico (N2) ─── ROL-PARAMEDICO
              │           └── Paciente Ambulatorio (N0) ─── ROL-EXT-PACIENTE-AMBULATORIO
              ├── Jefe de Farmacia (N3) ─── ROL-JEFE-FARMACIA
              │     └── Farmacéutico (Profesional) ─── ROL-FARMACEUTICO
              │           └── Cliente de Farmacia (N0) ─── ROL-EXT-CLIENTE-FARMACIA-Q
              └── Recepcionista de Consultorio (N1) ─── ROL-RECEPCION-CLINICA
                    └── Paciente Hospitalizado (N0) ─── ROL-EXT-PACIENTE-HOSPITALIZADO
```

#### Educación (CAEB P85)

```
S017 (Admin Sucursal)
  └── Director de Colegio (N5) ─── ROL-DIRECTOR-COLEGIO
        └── Secretario Académico (N1) ─── ROL-SECRETARIO-ACADEMICO
              └── Docente (Profesional) ─── ROL-DOCENTE
                    ├── Auxiliar Docente (N1) ─── ROL-AUXILIAR-DOCENTE
                    │     └── Alumno Universitario (N0) ─── ROL-EXT-ALUMNO-UNIVERSITARIO
                    └── Padre / Tutor (N0) ─── ROL-EXT-TUTOR-EDUCATIVO
                          └── Alumno Primaria/Secundaria (N0) ─── ROL-EXT-ALUMNO-PRIMARIA
```

> **Nota:** Las cadenas completas para los 21 sectores CAEB están disponibles en el
> anexo `BAUTH-CADENAS-JERARQUIA.md`. Aquí se documentan los patrones; el anexo contiene
> la tabla completa de dependencias para los 278 roles de negocio.

---

## 7. POLÍTICAS MÍNIMAS DE REGISTRO DE ROLES

> **Base normativa:**
> - **NIST RBAC Core Model §2** — define los cuatro componentes mínimos: users, roles, permissions, sessions. Un rol debe tener al menos: identificador único, conjunto de permisos asignados, y posición en la jerarquía.
> - **ISO/IEC 24760-2:2025** — Identity Management Reference Architecture. Especifica atributos obligatorios de identidad, ciclo de vida, política de atributos, y requisitos funcionales para registros de identidad.
> - **ANSI INCITS 359-2004** — RBAC Standard. Formaliza la estructura de rol: nombre, descripción, permisos base, restricciones SSD/DSD.
> - **oneM2M TS 0001** — Role Token Schema: roleID, roleName, roleType, issuer, startTime, expiryTime, tokenValue, holder, appCategory, extensions.
> - **bAuth PrivilegeEngine** — extiende NIST RBAC con BitMask 64-bit de 2 capas, LoA (Level of Assurance 1–4), Step-Up (RFC 9470), y sincronización KC+Tryton.

---

### 7.1 Atributos Mínimos Obligatorios de un Rol (RolTemplate)

Todo rol registrado en bAuth DEBE tener los siguientes atributos. Los marcados con
🟢 son obligatorios; los 🟡 son recomendados; los 🔵 son automáticos (generados por el sistema).

| # | Atributo | Obl. | Estándar | Descripción | Ejemplo |
|---|----------|------|---------|-------------|---------|
| A01 | `role_id` | 🟢 | NIST Core RBAC, ISO 24760-2 | Identificador único del rol en el ecosistema. Inmutable. | `ROL-CAJERO` |
| A02 | `role_name` | 🟢 | ISO 24760-2 §4.2 | Nombre legible en español. | `Cajero` |
| A03 | `role_type` | 🟢 | oneM2M TS 0001 | Tipo: `SYS` (sistémico), `BIZ` (negocio), `EXT` (externo), `M2M` (máquina) | `BIZ` |
| A04 | `tier` | 🟢 | NIST Hierarchical RBAC | Nivel jerárquico: SU, SYS, N0–N5 | `N1` |
| A05 | `parent_role_ids` | 🟢 | NIST DAG §4.2 | Lista de role_id de los roles junior de los que hereda. Mínimo 1. | `[ROL-SUPERVISOR-TIENDA]` |
| A06 | `mask_own` | 🟢 | bAuth BitMask | Máscara propia de 64 bits (hex). Capa 1 [31:0] = sistema, Capa 2 [63:32] = negocio. | `0x00000000_0000003F` |
| A07 | `description` | 🟢 | ISO 24760-2 §5.1 | Propósito del rol: qué hace, para quién, en qué contexto. Máximo 300 caracteres. | `Cobro en punto de venta, cierre de caja, arqueo` |
| A08 | `objective` | 🟡 | ISO 24760-2 §5.1 | Objetivo de negocio que cumple el rol dentro de la organización. | `Garantizar la correcta facturación y recaudación en punto de venta` |
| A09 | `issuer` | 🟢 | oneM2M TS 0001 | Role ID de la entidad que crea este rol. | `ROL-SYS-ADMIN-BAUTH` |
| A10 | `owner_tenant` | 🟢 | ISO 24760-2 §6 | Tenant al que pertenece el rol. `*` para roles sistémicos globales. | `tenant-001` |
| A11 | `start_time` | 🟢 | oneM2M TS 0001, NIST AC-2 | Fecha/hora de activación del rol. UTC ISO 8601. | `2026-06-19T00:00:00Z` |
| A12 | `expiry_time` | 🟡 | oneM2M TS 0001, NIST AC-2 | Fecha/hora de expiración. `null` = permanente. Roles temporales DEBEN tener expiración. | `null` |
| A13 | `loa_required` | 🟢 | NIST 800-63-4, bAuth LoA | Level of Assurance mínimo para activar este rol (1–4). N0=1, N1=2, N2=3, SYS=4. | `2` |
| A14 | `mfa_required` | 🟢 | ISO 27001 A.8.2, NIST 800-63B | Si requiere autenticación multi-factor. Obligatorio para SU, SYS, N3+. | `false` |
| A15 | `step_up_enabled` | 🟡 | RFC 9470, bAuth Step-Up | Si el rol permite elevación temporal de LoA para operaciones sensibles. | `false` |
| A16 | `sod_group` | 🟡 | NIST AC-5 Static SoD | Grupo de separación de deberes. Roles en el mismo grupo no pueden asignarse al mismo usuario. | `CAJA` |
| A17 | `max_sessions` | 🟡 | NIST Core RBAC §3 | Número máximo de sesiones simultáneas con este rol activo. | `1` |
| A18 | `session_timeout` | 🟡 | NIST AC-2(3) | Tiempo máximo de sesión en segundos antes de requerir re-autenticación. | `28800` |
| A19 | `audit_level` | 🟢 | ISO 27001 A.8.15 | Nivel de auditoría: `none`, `basic` (login/logout), `full` (cada operación). | `basic` |
| A20 | `template_id` | 🟡 | bAuth RolTemplate | Plantilla de la que se clonó este rol. `null` si fue creado desde cero. | `TEMPLATE-CAJERO` |
| A21 | `extensions` | 🔵 | oneM2M TS 0001 | Metadatos extensibles específicos de la aplicación (JSON). | `{"sector_caeb":"G47"}` |
| A22 | `created_at` | 🔵 | ISO 24760-2 | Timestamp de creación. Automático. | `2026-06-19T14:30:00Z` |
| A23 | `updated_at` | 🔵 | ISO 24760-2 | Timestamp de última modificación. Automático. | `2026-06-19T14:30:00Z` |
| A24 | `version` | 🔵 | bAuth | Número de versión del RolTemplate. Incrementa en cada modificación. | `1` |

---

### 7.2 Política de Estructuración de Claves por Rol — Longitud, Complejidad y Tokenización

Esta política define la estructura de credenciales para cada nivel de rol en el SBOS.
Se fundamenta en **NIST SP 800-63B Rev. 4 (2024)** y asigna requisitos diferenciados
según la criticidad del rol y su AAL (Authenticator Assurance Level).

> **Principio NIST 800-63B Rev. 4:** la longitud de la contraseña es el factor
> determinante de seguridad, no la complejidad. Las reglas de composición
> (mayúscula + número + símbolo) están **oficialmente deprecadas** por NIST.
> La rotación periódica sin evidencia de compromiso **reduce** la seguridad.
> El cribado contra listas de contraseñas filtradas es **obligatorio**.

---

#### 7.2.1 Matriz de Políticas de Clave por Tier

| Tier | AAL | Longitud Mínima | Longitud Recomendada | Cribado | Hash | Rotación | MFA | Tipo de Token |
|------|-----|----------------|---------------------|---------|------|----------|-----|--------------|
| **SU** | 3 | 20 caracteres | 32+ caracteres | Obligatorio + breached + contexto | Argon2id (t=5, m=128MB, p=2) | Solo post-evento o compromiso | FIDO2/WebAuthn hardware + JIT | JWT firmado (ES256) · TTL 5 min |
| **SYS N1–N3** | 2/3 | 15 caracteres | 24+ caracteres | Obligatorio + breached + contexto | Argon2id (t=3, m=64MB, p=2) | 180 días + compromiso | TOTP o FIDO2 | JWT firmado (ES256) · TTL 15 min + refresh token rotativo |
| **BIZ N4–N5** | 2 | 12 caracteres | 20+ caracteres | Obligatorio + breached | Argon2id (t=3, m=64MB, p=2) | Solo por compromiso | TOTP o FIDO2 | JWT firmado (ES256) · TTL 30 min + refresh token rotativo |
| **BIZ N2–N3** | 2 | 12 caracteres | 16+ caracteres | Obligatorio + breached | Argon2id (t=3, m=64MB, p=2) | Solo por compromiso | TOTP opcional | JWT firmado (ES256) · TTL 60 min + refresh token |
| **BIZ N1** | 1/2 | 10 caracteres | 15+ caracteres | Obligatorio + comunes | Argon2id (t=2, m=32MB, p=1) | Solo por compromiso | TOTP opcional | JWT firmado (ES256) · TTL 60 min |
| **EXT N0** | 1 | 8 caracteres | 12+ caracteres | Obligatorio + comunes | Argon2id (t=2, m=32MB, p=1) | Solo por compromiso | Opcional (Passkey/WebAuthn) | JWT firmado (ES256) · TTL 24h |
| **M2M N4** | N/A | N/A (sin contraseña) | N/A | N/A | N/A | Certificado 24h automático | mTLS obligatorio | Client Credentials JWT (ES384) · TTL ≤ 60 min · sin refresh token |
| **Visitante** | 1 | N/A (sin contraseña) | N/A | N/A | N/A | Expira al check-out | QR/Badge temporal | Token de visita efímero · TTL = duración de la visita |

> **Nota sobre Argon2id:** NIST 800-63B y OWASP recomiendan Argon2id como algoritmo de
> hashing de contraseñas por su resistencia a ataques side-channel y GPU. Los parámetros
> (t=time cost, m=memory, p=parallelism) se ajustan según la criticidad del rol.

---

#### 7.2.2 Política de Tokens OAuth 2.0 / JWT por Tier

Cada rol recibe tokens de acceso con parámetros específicos según su nivel.
La emisión y validación de tokens se centraliza en **Keycloak 26.6.2** como
Authorization Server, con **Kong 3.9.x** como API Gateway para validación
en cada request.

| Parámetro | SU | SYS | BIZ N3–N5 | BIZ N1–N2 | EXT N0 | M2M |
|----------|----|-----|-----------|-----------|--------|-----|
| **Access Token TTL** | 5 min | 15 min | 30 min | 60 min | 24 h | 15–60 min |
| **Refresh Token TTL** | No aplica (JIT) | 4 h (rotativo) | 8 h (rotativo) | 30 días (rotativo) | 90 días | No aplica |
| **Refresh Token Rotation** | N/A | Sí (cada uso) | Sí (cada uso) | Sí (cada uso) | No (revocación manual) | N/A |
| **Algoritmo de firma** | ES256 | ES256 | ES256 | ES256 | ES256 | ES384 |
| **Token Binding** | mTLS (RFC 8705) | DPoP (RFC 9449) | DPoP recomendado | Opcional | No | mTLS (RFC 8705) |
| **Sender-Constrained** | Obligatorio | Obligatorio | Recomendado | Opcional | No | Obligatorio |
| **PKCE** | N/A (cliente confidencial) | Obligatorio | Obligatorio | Obligatorio | Obligatorio | N/A (client credentials) |
| **Scopes** | `bos:* bAuth:*` | Módulo específico | Tenant específico | Sucursal específica | `profile factura` | Servicio específico |
| **Audience (`aud`)** | `bos bAuth` | Daemon específico | `tenant-{id}` | `tenant-{id}` | `bAuth` | Daemon destino |
| **Revocación** | Inmediata (RFC 7009) | Inmediata | Inmediata | Inmediata | Batch cada 1 h | Inmediata |

---

#### 7.2.3 Integración con el Ecosistema de Identidad SBOS

##### Keycloak 26.6.2 — Authorization Server y Políticas de Contraseña

Keycloak es el **proveedor de identidad central** del SBOS. Cada tenant tiene
su propio **realm** con políticas de contraseña específicas. bAuth orquesta la
sincronización entre Keycloak y Tryton.

| Realm | Política de Contraseña | Algoritmo | Iteraciones | Usuarios |
|-------|----------------------|-----------|------------|----------|
| `sbos-system` (SU+N1+N2+N4) | `length(15) and notUsername(1) and hashAlgorithm(argon2)` | Argon2id | t=5, m=128MB | Roles sistémicos |
| `tenant-{id}` (BIZ N1–N5) | `length(12) and notUsername(1) and hashAlgorithm(argon2)` | Argon2id | t=3, m=64MB | Empleados del tenant |
| `tenant-{id}-ext` (EXT N0) | `length(8) and notUsername(1) and hashAlgorithm(argon2)` | Argon2id | t=2, m=32MB | Clientes externos |

**Configuración de políticas en Keycloak (por realm):**
```bash
# Realm sbos-system
kcadm.sh update realms/sbos-system -s 'passwordPolicy="
  length(15) and
  notUsername(1) and
  notEmail(1) and
  hashAlgorithm(argon2) and
  hashIterations(5) and
  forceExpiredPasswordChange(365) and
  maxPasswordAge(365)
"'

# Realm tenant (ejemplo: empresa Acme)
kcadm.sh update realms/tenant-acme -s 'passwordPolicy="
  length(12) and
  notUsername(1) and
  hashAlgorithm(argon2) and
  hashIterations(3) and
  forceExpiredPasswordChange(0)
"'
```

> **Nota:** Siguiendo NIST SP 800-63B Rev. 4, **no se imponen reglas de complejidad**
> (sin `upperCase`, `lowerCase`, `digits`, `specialChars` obligatorios). La seguridad
> proviene de la longitud, el cribado contra filtraciones, y Argon2id.

##### Vault 2.0.1 — Secretos, Rotación y Credenciales Dinámicas

Vault es el **almacén central de secretos** y el motor de rotación de credenciales
para roles M2M, service accounts de infraestructura, y clientes OAuth.

| Secreto | Motor Vault | Política de Rotación | Consumidores |
|---------|-----------|---------------------|-------------|
| Certificados M2M (N4) | PKI Secrets Engine | TTL 24 h · Rotación automática · CRL activa | bos-agent, bauth-daemon, bkernel-daemon, etc. |
| Client Secrets OAuth (N4) | KV v2 + Policies | TTL 90 días · Rotación con dual-credential (zero-downtime) | biedata-daemon, bsearch-daemon |
| Claves API Kong (N2) | KV v2 | TTL 180 días · Rotación manual con aprobación | Admin Kong (S014) |
| Contraseñas DB (PostgreSQL 18.4) | Database Secrets Engine | TTL 30 días · Rotación dinámica · Sin downtime | postgresql-admin (S039) |
| Contraseñas Redis (8.6.2) | KV v2 + ACLs | TTL 180 días | redis-admin (S040) |
| Claves de cifrado AES-256-GCM | Transit Secrets Engine | TTL 90 días · Rotación con re-wrap automático | banexus, ctx-orchestrator |
| Credenciales de emergencia (SU break-glass) | KV v2 + Sentinel Policies | Sin TTL fijo · Requiere 2-of-3 unseal para acceso · 24 h max session | Superusuario (S001) |

**Ejemplo de política Vault para M2M:**
```hcl
# Política Vault para el motor PKI — certificados de daemons
path "pki/issue/daemon-*" {
  capabilities = ["create", "update"]
  required_parameters = ["common_name"]
  max_ttl = "24h"
}
```

##### Kong 3.9.x — API Gateway y Validación de Tokens

Kong es el **punto único de entrada externo** al SBOS (SBOS-050 P9). Valida
todo token JWT/OAuth 2.0 antes de enrutar al daemon destino.

| Plugin Kong | Función | Configuración |
|------------|---------|--------------|
| **OIDC (OpenID Connect)** | Valida JWT contra Keycloak · Extrae claims · Inyecta headers `X-User-Id`, `X-Role-Id`, `X-Tenant-Id` | `introspection_endpoint: /realms/{realm}/protocol/openid-connect/token/introspect` |
| **Rate Limiting** | Limita requests por rol y endpoint · Protege contra abuso | SU: ilimitado · SYS: 1000 req/s · BIZ: 100 req/s · EXT: 10 req/s · Visitante: 1 req/s |
| **mTLS** | Autenticación mutua TLS para clientes M2M y NEXUS | Obligatorio para M2M · Certificados emitidos por Vault PKI |
| **CORS** | Restringe orígenes permitidos | Solo dominios `.sbos.skull.bo` y `localhost` en desarrollo |
| **Audit Log** | Registra todo request autenticado con ctx_id | Formato JSON · Enviado a Loki vía Alloy |

**Pipeline de autenticación en Kong:**
```
Request → Kong (rate limit) → OIDC Plugin (validar JWT con Keycloak)
       → Extraer claims (sub, role, tenant, ctx_id)
       → Inyectar headers (X-User-Id, X-Role-Id, X-Tenant-Id, X-Ctx-Id)
       → mTLS (si aplica)
       → Enrutar al daemon destino (bos, biedata, bSearch, etc.)
```

##### Tryton — Sincronización de Identidad de Negocio

Tryton es el **ERP del SBOS** y fuente de verdad para empleados, clientes,
proveedores y estructura organizacional. bAuth sincroniza estas entidades
con Keycloak cada 60 segundos (reconcile loop).

| Entidad Tryton | Se sincroniza con | Frecuencia | Dirección |
|---------------|-------------------|-----------|----------|
| `res.users` (empleados) | Keycloak users en `tenant-{id}` | 60 s | Tryton → Keycloak |
| `res.partner` (clientes/proveedores) | Keycloak users en `tenant-{id}-ext` | 60 s | Tryton → Keycloak |
| `res.company` (empresa) | Realm `tenant-{id}` en Keycloak | On-create | bAuth → Keycloak Admin API |
| `res.branch` (sucursal) | Group en Keycloak | On-create | bAuth → Keycloak Admin API |
| `res.department` (departamento) | Group en Keycloak | On-create | bAuth → Keycloak Admin API |
| `account.tax` (config fiscal) | No se sincroniza (solo en Tryton) | N/A | N/A |

**Flujo de sincronización:**
```
Tryton (ERP)
  │
  │  res.users / res.partner / res.company / res.branch
  │
  ▼
bAuth (Reconcile Loop · 60 s)
  │
  │  Admin API (service account: ROL-SYS-KEYCLOAK-ADMIN)
  │
  ▼
Keycloak (SSO)
  │
  │  JWT emitido
  │
  ▼
Kong (API Gateway) → Validación → Daemon destino
```

---

#### 7.2.4 Cribado de Contraseñas (Password Screening)

Toda contraseña nueva o modificada DEBE ser validada contra:

| Lista | Fuente | Frecuencia de actualización | Implementación |
|-------|--------|---------------------------|---------------|
| **Have I Been Pwned (HIBP)** | `api.pwnedpasswords.com` (k-anonymity) | Diaria | Vault Password Policy + bAuth pre-check |
| **Top 100K comunes** | SecLists, rockyou | Semanal | Archivo plano en Vault |
| **Términos de contexto** | Nombre de usuario, empresa, sucursal, tenant | En tiempo real | bAuth validation engine |
| **Contraseñas previas del usuario** | Historial interno bAuth | Últimas 10 contraseñas | bAuth password history |

**Regla NIST 800-63B §5.1.1.2:** si una contraseña aparece en CUALQUIER lista
de filtraciones conocidas, DEBE ser rechazada, sin importar su longitud o entropía.

---

#### 7.2.5 Reglas No Negociables (Actualizadas)

| # | Regla | Fundamento | Aplica a |
|---|-------|-----------|---------|
| L1 | **Sin SMS OTP.** Usar TOTP, FIDO2 o Passkey. | NIST 800-63B §5.1: SMS deprecado | Todos |
| L2 | **Longitud > complejidad.** Sin reglas de composición obligatorias. | NIST 800-63B Rev. 4 §5.1.1.2 | Humanos |
| L3 | **Sin rotación sin evidencia de compromiso.** | NIST 800-63B Rev. 4 §5.1.1.2 | Humanos |
| L4 | **Cribado obligatorio contra filtraciones.** | NIST 800-63B Rev. 4 §5.1.1.2 | Todos |
| L5 | **M2M solo criptografía asimétrica (mTLS).** Prohibido shared secrets. | NHIMG, NIST 800-63-4 | M2M |
| L6 | **TTL máximo de token M2M: 60 min.** Sin refresh token. | OAuth 2.0 Best Practices, MITRE | M2M |
| L7 | **Refresh tokens rotativos.** Un solo uso, revocación del anterior. | OAuth 2.0 Security BCP (RFC 6819) | Humanos SYS/BIZ |
| L8 | **Token binding (mTLS o DPoP) para SYS y SU.** | RFC 8705, RFC 9449 | SU, SYS |
| L9 | **PKCE obligatorio para clientes públicos.** | OAuth 2.0 PKCE (RFC 7636) | BIZ, EXT |
| L10 | **Step-Up (RFC 9470) para elevar LoA temporalmente.** | RFC 9470, bAuth Step-Up Engine | BIZ N1–N3 |
| L11 | **Argon2id como algoritmo de hashing.** Sin SHA1, sin MD5, sin bcrypt para nuevos roles. | OWASP ASVS 2.4.3, NIST 800-63B | Todos los humanos |
| L12 | **Session recording obligatorio para SU.** | ISO 27001 A.8.15, PAM | SU |

---

### 7.3 Ciclo de Vida del Rol

Todo rol transita por un ciclo de vida definido. Las transiciones están controladas
por el `issuer` del rol y auditadas según `audit_level`.

```
                 ┌──────────┐
                 │ DEFINIDO │  ← Rol documentado en catálogo
                 └────┬─────┘
                      │ desarrollar()
                 ┌────▼──────┐
                 │DESARROLLADO│  ← RolTemplate implementado en código
                 └────┬──────┘
                      │ revisar()
                 ┌────▼──┐
                 │REVISADO│  ← Verificado por revisor (SoD: revisor ≠ desarrollador)
                 └────┬──┘
                      │ autorizar()
                 ┌────▼────┐
                 │AUTORIZADO│  ← Aprobado por autorizador (SoD: autorizador ≠ revisor)
                 └────┬────┘
                      │ publicar()
                 ┌────▼───┐
                 │PUBLICADO│  ← En producción. Asignable a usuarios.
                 └────┬───┘
                      │
              ┌───────┼──────────┐
              │       │          │
         modificar()  │     deprecar()
              │       │          │
         ┌────▼───┐   │     ┌────▼────┐
         │DEFINIDO │   │     │DEPRECADO│ ← Ya no se asigna. Los existentes siguen.
         │(nueva   │   │     └────┬────┘
         │versión) │   │          │
         └─────────┘   │     retirar()
                       │          │
                  ┌────▼──────────▼──┐
                  │   RETIRADO       │ ← Eliminado del sistema.
                  │   (histórico)    │    Solo queda en logs de auditoría.
                  └──────────────────┘
```

**Transiciones y responsables (SoD):**

| Transición | Quién la ejecuta | Quién NO puede ejecutarla | Estándar |
|-----------|-----------------|--------------------------|---------|
| `definir()` → DEFINIDO | Admin de Módulo (N2) | — | NIST AC-2 |
| `desarrollar()` → DESARROLLADO | Desarrollador (N2 Técnico) | El mismo que revisa | NIST AC-5 SoD |
| `revisar()` → REVISADO | Revisor designado | El desarrollador | NIST AC-5 Static SoD |
| `autorizar()` → AUTORIZADO | Admin de Seguridad (N1) o Admin Proyecto | El revisor | ISO 27001 A.8.2 |
| `publicar()` → PUBLICADO | Admin de Módulo (N2) | — | ISO 27001 A.8.2 |
| `modificar()` → vuelve a DEFINIDO | Admin de Módulo (N2) | — | NIST AC-2 |
| `deprecar()` → DEPRECADO | Admin de Módulo (N2) | — | NIST AC-2 |
| `retirar()` → RETIRADO | Admin Proyecto (N1) | Admin de Módulo (SoD) | NIST AC-5, ISO 27001 A.8.2 |

---

### 7.4 Verificación Pre-Registro — Checklist Obligatorio

Antes de registrar un nuevo rol en bAuth, el `issuer` debe verificar:

| # | Verificación | Conforme si... | Estándar |
|---|-------------|---------------|---------|
| V01 | **Unicidad** | No existe otro rol con el mismo `role_id` ni con idéntica combinación `(role_name, owner_tenant)` | NIST Core RBAC |
| V02 | **Posición en DAG** | El rol tiene al menos un `parent_role_id` definido (excepto SU) | NIST Hierarchical RBAC |
| V03 | **No-ciclo** | La inserción de las aristas `parent_role_ids → nuevo_rol` no crea ciclos en el DAG | NIST DAG anti-ciclo |
| V04 | **Máscara coherente** | `mask_own` no incluye bits que los `parent_role_ids` no tengan ya en su `mask_eff` (no puede otorgar más permisos que sus padres) | bAuth PrivilegeEngine |
| V05 | **SoD** | El `sod_group` no entra en conflicto con otros roles del mismo usuario (Static SoD check) | NIST AC-5 |
| V06 | **LoA apropiado** | El `loa_required` es ≥ al máximo LoA de sus roles junior | NIST 800-63-4 |
| V07 | **Expiración** | Si `expiry_time ≠ null`, debe ser > `start_time` y ≤ 365 días (roles temporales) | NIST AC-2(2) |
| V08 | **Documentación** | `description` y `objective` están en español, son legibles, y describen claramente el propósito del rol | ISO 24760-2 §5.1 |
| V09 | **Aprobación** | El `issuer` tiene autoridad para crear roles en el `owner_tenant` especificado | ISO 27001 A.8.2 |

---

## 8. Plantillas Predefinidas para bAuth

De los 368 roles (48 sistémicos + 174 internos + 146 externos), se definen **66 plantillas base** que cubren el 85% de los casos de uso iniciales. Las demás se obtienen por clonación y ajuste.

### 8.1 Plantillas de Roles Sistémicos (9 plantillas — incluidas en bAuth por defecto)

| # | Código Plantilla | Roles que cubre | Estado | Vitácora | Plantilla |
|---|-----------------|-------------------|--------|----------|
| 1 | `TEMPLATE-SYS-SUPERUSUARIO` | Superusuario SBOS (S001) — PAM break-glass, JIT, MFA, session recording | Definido | — |
| 2 | `TEMPLATE-SYS-PLATAFORMA` | Admin Proyecto, Admin Seguridad, Admin Infra, Admin SRE (S002–S005) | Definido | — |
| 3 | `TEMPLATE-SYS-MODULO` | Admin bAuth, bKernel, biedata, bSearch, NEXUS, BOS, Datos, Vault, Kong, Keycloak (S006–S015) | Definido | — |
| 4 | `TEMPLATE-SYS-TENANT` | Admin Tenant, Admin Sucursal, Admin Seguridad Tenant, Admin Facturación Tenant (S016–S019) | Definido | — |
| 5 | `TEMPLATE-SYS-BOOTSTRAP-DAEMON` | bos-agent, bauth-daemon, bkernel-daemon, biedata-daemon, bsearch-daemon, bhnexus-daemon, banexus-daemon (S020, S025, S028, S031, S034, S036, S037) | Definido | — |
| 6 | `TEMPLATE-SYS-BOOTSTRAP-ENGINE` | bos-state-manager, bos-deps, bos-health, bauth-reconcile, bauth-spi, bkernel-fanout, bkernel-rules, biedata-saga, biedata-ficha, bsearch-indexer, nexus-bridge, ctx-orchestrator, ctx-validator (S022–S024, S026–S027, S029–S030, S032–S033, S035, S038, S045–S046) | Definido | — |
| 7 | `TEMPLATE-SYS-INFRA-SERVICE` | postgresql-admin, redis-admin, keycloak-admin, vault-admin, kong-admin, k8s-cluster-admin (S039–S044) | Definido | — |
| 8 | `TEMPLATE-SYS-OBSERVABILIDAD` | prometheus-collector, loki-collector (S047–S048) | Definido | — |
| 9 | `TEMPLATE-SYS-M2M` | Todos los roles N4 Bootstrap — identidades máquina-a-máquina con mTLS | Definido | — |

### 8.2 34 Plantillas de Actores Internos (incluidas en bAuth por defecto)

| # | Código Plantilla | Roles que cubre | Estado | Vitácora | Plantilla |
|---|-----------------|-----------------|--------|----------|
| 1 | `TEMPLATE-OPERARIO` | Cajero, Vendedor, Reponedor, Promotor, Operario, Peón | — | — |
| 2 | `TEMPLATE-SUPERVISOR` | Supervisor Tienda, Supervisor Planta, Supervisor Almacenes, Supervisor Facturación-Cobranza, Capataz, Jefe Turno | — | — |
| 3 | `TEMPLATE-GERENTE` | Gerente General, Gerente Sucursal, Jefe Local, Jefe Facturación y Crédito, Jefe Inventarios | — | — |
| 4 | `TEMPLATE-CONTABLE` | Contador General, Asistente Contable, Jefe de Contabilidad, Contador de Costos, Analista CxP, Analista CxC Contable, Conciliador Bancario, Encargado de Activos Fijos, Encargado de Presupuesto, Encargado de Cierre Mensual/Anual | — | — |
| 5 | `TEMPLATE-RRHH` | Jefe RRHH, Analista RRHH, Asistente RRHH, Encargado de Nómina/Sueldos | — | — |
| 6 | `TEMPLATE-SEGURIDAD` | Portero, Guardia, Sereno, Operador CCTV | — | — |
| 7 | `TEMPLATE-RECEPCION` | Recepcionista, Secretario, Administrativo | — | — |
| 8 | `TEMPLATE-CHOFER` | Chofer Camión, Chofer Taxi, Fletero, Repartidor | — | — |
| 9 | `TEMPLATE-ALMACEN` | Encargado Depósito, Jefe Almacén, Recepción de Mercadería, Encargado de Despacho, Encargado de Caducidades, Operador de Código de Barras/RFID, Encargado de Devoluciones, Operador de WMS, Encargado de Cadena de Frío, Encargado de Almacén MP, Encargado de Almacén PT | — | — |
| 10 | `TEMPLATE-BANCO` | Cajero Banco, Ejecutivo Cuenta, Oficial Créditos | — | — |
| 11 | `TEMPLATE-SALUD` | Médico, Enfermero, Farmacéutico, Auxiliar | — | — |
| 12 | `TEMPLATE-HOTEL` | Recepcionista Hotel, Mucama, Mesero, Cocinero | — | — |
| 13 | `TEMPLATE-CONSTRUCCION` | Maestro Obra, Albañil, Electricista, Plomero | — | — |
| 14 | `TEMPLATE-IT` | Soporte Técnico, Desarrollador, SysAdmin | — | — |
| 15 | `TEMPLATE-DIRECTOR` | Gerente General, Director Colegio, Director Clínica | — | — |
| 16 | `TEMPLATE-AUDITOR` | Auditor Interno, Oficial Cumplimiento, Control Calidad, Revisor de Estados Financieros, Analista de Control Interno, Auditor Externo Contable | — | — |
| 17 | `TEMPLATE-PRODUCCION` | Operario Producción, Jefe Producción, Planificador | — | — |
| 18 | `TEMPLATE-LOGISTICA` | Despachador, Jefe Logística, Coordinador Distribución | — | — |
| 19 | `TEMPLATE-MANTENIMIENTO` | Técnico Mantenimiento, Electricista, Plomero | — | — |
| 20 | `TEMPLATE-VENTAS` | Vendedor Piso, Ejecutivo Cuenta, Promotor | — | — |
| 21 | `TEMPLATE-COMPRAS` | Jefe Compras, Analista Compras, Proveedores | — | — |
| 22 | `TEMPLATE-DOCENTE` | Docente, Auxiliar Docente, Bibliotecario | — | — |
| 23 | `TEMPLATE-RURAL` | Peón Rural, Tractorista, Capataz, Veterinario | — | — |
| 24 | `TEMPLATE-ADMIN-SISTEMA` | SysAdmin, DBA, DevOps, Ciberseguridad | — | — |
| 25 | `TEMPLATE-CAJERO` | Cajero, Cajero Banco, Encargado Caja | — | — |
| 26 | **`TEMPLATE-FACTURACION`** | Facturador Electrónico, Dosificador, Operador SIF, Notas Fiscales, Operador Facturación POS, Operador Facturación Móvil/Delivery, Encargado de Notas de Crédito/Débito, Conciliador de Facturación, Operador de Facturación Recurrente | — | — |
| 27 | **`TEMPLATE-TRIBUTARIO`** | Contador Tributario, Revisor Fiscal, Retenciones, Archivo Fiscal, Contador Impositivo, Encargado de Impuestos Diferidos, Encargado de Reportes de IVA, Encargado de Retenciones y Percepciones | — | — |
| 28 | **`TEMPLATE-COMERCIO-EXTERIOR`** | Exportaciones (NITEX), Importaciones (DUI), Agencia Despachante | — | — |
| 29 | **`TEMPLATE-COMERCIO-MINORISTA`** | Vendedor por rubro: ferretería, farmacia, moda, electro, librería, carnicero | — | — |
| 30 | **`TEMPLATE-COMERCIO-MAYORISTA`** | Vendedor Mayorista, Comprador, Encargado Inventario, Logística | — | — |
| 31 | **`TEMPLATE-COBRANZA`** | Cobrador / Gestor de Cobranza, Analista de Crédito y Cobranza, Encargado de Cuentas Corrientes (CxC), Supervisor de Facturación y Cobranza, Jefe de Facturación y Crédito | — | — |
| 32 | **`TEMPLATE-TESORERIA`** | Tesorero / Encargado de Tesorería, Asistente de Tesorería | — | — |
| 33 | **`TEMPLATE-INVENTARIOS`** | Jefe de Inventarios, Analista de Control de Mermas, Auditor de Inventario, Planificador de Demanda | — | — |
| 34 | **`TEMPLATE-CONTADOR-IMPOSITIVO`** | Contador Impositivo, Encargado de Impuestos Diferidos, Encargado de Retenciones y Percepciones, Encargado de Reportes de IVA | — | — |

### 8.3 23 Plantillas de Actores Externos (clientes del sistema ISO 9001)

| # | Código Plantilla | Actores que cubre | Estado | Vitácora | Plantilla |
|---|-----------------|-------------------|--------|----------|
| 35 | **`TEMPLATE-CLIENTE-MINORISTA`** | Cliente Minorista, Cliente Fidelizado, Cliente Ocasional, Cliente Supermercado, Cliente Tienda, Cliente E-commerce | — | — |
| 36 | **`TEMPLATE-CLIENTE-MAYORISTA`** | Cliente Mayorista, Cliente Corporativo B2B, Cliente Institucional, Cliente Distribuidora | — | — |
| 37 | **`TEMPLATE-PROVEEDOR`** | Proveedor Nacional, Proveedor Internacional, Proveedor MP, Proveedor Maquinaria, Proveedor Servicios | — | — |
| 38 | **`TEMPLATE-ALUMNO`** | Alumno Inicial, Primaria, Secundaria, Universitario, Postgrado, Técnico | — | — |
| 39 | **`TEMPLATE-TUTOR-EDUCATIVO`** | Padre de Familia, Tutor Legal — representante de alumno menor | — | — |
| 40 | **`TEMPLATE-PACIENTE`** | Paciente Ambulatorio, Hospitalizado, Emergencia, Cirugía, Laboratorio | — | — |
| 41 | **`TEMPLATE-ASEGURADO-SALUD`** | Asegurado SUS/CNS/Seguro Privado, Familiar de Paciente | — | — |
| 42 | **`TEMPLATE-CIUDADANO`** | Ciudadano, Contribuyente, Administrado, Elector, Beneficiario Social | — | — |
| 43 | **`TEMPLATE-VISITANTE`** | Visitante General, Proveedor, Auditor, VIP — acceso temporal a instalaciones | — | — |
| 44 | **`TEMPLATE-HUESPED`** | Huésped Hotel, Huésped Temporal, Comensal, Cliente Eventos, Cliente Delivery | — | — |
| 45 | **`TEMPLATE-PASAJERO`** | Pasajero Bus, Pasajero Aéreo, Remitente Carga, Consignatario, Cliente Courier | — | — |
| 46 | **`TEMPLATE-CUENTAHABIENTE`** | Cuentahabiente, Ahorrista, Deudor, Solicitante Crédito, Cliente Cambio | — | — |
| 47 | **`TEMPLATE-ASEGURADO`** | Asegurado, Beneficiario Seguro, Asegurado Salud | — | — |
| 48 | **`TEMPLATE-USUARIO-SERVICIOS`** | Usuario Residencial (agua/luz/gas), Usuario Industrial, Suscriptor Telecom | — | — |
| 49 | **`TEMPLATE-CLIENTE-PROFESIONAL`** | Cliente Abogado, Cliente Contable, Cliente Arquitecto, Cliente Consultoría | — | — |
| 50 | **`TEMPLATE-INQUILINO`** | Inquilino, Comprador Inmueble, Propietario Vendedor | — | — |
| 51 | **`TEMPLATE-CLIENTE-ENTRETENIMIENTO`** | Espectador, Visitante Museo, Deportista, Socio Club, Cliente Gimnasio | — | — |
| 52 | **`TEMPLATE-CLIENTE-SERVICIOS`** | Cliente Peluquería, Lavandería, Funeraria, Reparación | — | — |
| 53 | **`TEMPLATE-ACTOR-SOCIAL`** | Feligrés, Afiliado Sindical, Miembro Asociación, Comunidad Minera | — | — |
| 54 | **`TEMPLATE-COMERCIO-EXTERIOR`** | Exportador, Importador, Cliente Exportación, Diplomático | — | — |
| 55 | **`TEMPLATE-CONTRATISTA`** | Técnico Servicio (plomero, electricista, gasista), Contratista Obra, Instalador | — | — |
| 56 | **`TEMPLATE-DOBLE-DOMINIO`** | Actores que requieren autorización física + financiera simultánea: contratistas, técnicos externos, proveedores con acceso a instalaciones | — | — |
| 57 | **`TEMPLATE-EXTERNO-GENERICO`** | Rol externo no clasificado — se personaliza por clonación y ajuste | — | — |

---

## 9. Notas específicas Bolivia / LATAM

### 9.1 Sectores con mayor empleo en Bolivia (INE 2024)

| Sector | % Empleo | Roles predominantes en bAuth |
|--------|----------|------------------------------|
| Comercio minorista | 28% | Cajero, Vendedor, Reponedor |
| Agricultura | 22% | Peón Rural, Tractorista, Capataz |
| Manufactura | 12% | Operario, Técnico Mantenimiento |
| Construcción | 8% | Albañil, Maestro Obra, Peón |
| Transporte | 7% | Chofer, Despachador, Playero |
| Servicios | 23% | Seguridad, Limpieza, Administrativo |

### 9.2 Particularidades LATAM

- **Impulsadoras/Promotoras:** rol muy común en supermercados de LATAM, poco frecuente en Europa/EEUU
- **Sereno/Vigilante:** más común que "Security Guard" por la cultura de vigilancia privada
- **Cadete/Mensajero:** aún vigente en Bolivia para trámites bancarios presenciales
- **Trabajador por Cuenta Propia:** 68% de la fuerza laboral boliviana — muchos usarían bAuth como única identidad digital

### 9.3 Principio ISO 9001:2015 — Todo Actor Externo es Cliente del Sistema

La norma ISO 9001:2015 (§3.2.4) define **cliente** como: *"organización o persona que recibe un producto o servicio."* Bajo este principio:

| Si la organización es... | Su cliente es... | Rol en bAuth |
|--------------------------|------------------|-------------|
| Un comercio | El comprador | `ROL-EXT-CLIENTE-MINORISTA` / `ROL-EXT-CLIENTE-MAYORISTA` |
| Un colegio / universidad | El alumno y su tutor | `ROL-EXT-ALUMNO-*` / `ROL-EXT-TUTOR-EDUCATIVO` |
| Un hospital / clínica | El paciente | `ROL-EXT-PACIENTE-*` |
| Una fábrica | El comprador mayorista | `ROL-EXT-CLIENTE-MAYORISTA-IND` |
| Un hotel | El huésped | `ROL-EXT-HUESPED` |
| Un banco | El cuentahabiente | `ROL-EXT-CUENTAHABIENTE` |
| Una alcaldía / ministerio | El ciudadano | `ROL-EXT-CIUDADANO` |
| Cualquier organización | El visitante | `ROL-EXT-VISITANTE` |

**Un alumno es un cliente.** **Un paciente es un cliente.** **Un visitante es un cliente.**
Todos necesitan identidad, autorización y trazabilidad en el sistema de autenticación.

---

## 7. PLANTA ORGANIZACIONAL JERÁRQUICA COMPLETA

> **Propósito:** Catálogo exhaustivo de todos los cargos de una organización tipo, desde Presidente hasta Portero. Organizado en jerarquía descendente de 7 niveles. Cada cargo es una plantilla RolTemplate que se clona al registrar una nueva empresa.

### 7.0 — Niveles Jerárquicos

| Nivel | Nombre | Descripción | Cantidad |
|-------|--------|-------------|----------|
| **N0** | Gobierno Corporativo | Accionistas, Junta Directiva, Comités | ~12 |
| **N1** | Alta Dirección | CEO, VP, Directores Generales | ~15 |
| **N2** | Dirección de Área | Directores funcionales (Finanzas, RRHH, IT, Comercial...) | ~25 |
| **N3** | Gerencia | Gerentes de departamento | ~40 |
| **N4** | Jefatura / Supervisión | Jefes de área, Supervisores de turno | ~35 |
| **N5** | Staff de Apoyo | Secretarias, Asistentes, Analistas senior | ~20 |
| **N6** | Personal Operativo | Vendedores, Cajeros, Contadores, Técnicos | ~55 |
| **N7** | Servicios Generales | Choferes, Porteros, Mensajeros, Limpieza, Vigilancia | ~15 |
| **TOTAL** | | | **~217 roles organizacionales** |

---

### 7.0-A — N0: Gobierno Corporativo

> **Estándares:** OECD G20/OECD Principles of Corporate Governance 2023 · Ley de Sociedades Comerciales · Código de Gobierno Corporativo · SOX §301-407

| # | Cargo | Código bAuth | Órgano | Plantilla |
|---|-------|-------------|--------|-----------|
| G001 | **Accionista Mayoritario** | `ROL-ORG-ACC-MAYOR` | Asamblea de Accionistas | ⏳ |
| G002 | **Accionista Minoritario** | `ROL-ORG-ACC-MINOR` | Asamblea de Accionistas | ⏳ |
| G003 | **Accionista Institucional** | `ROL-ORG-ACC-INST` | Asamblea de Accionistas | ⏳ |
| G004 | **Presidente del Directorio (Chairman)** | `ROL-ORG-CHAIRMAN` | Directorio | ⏳ |
| G005 | **Vicepresidente del Directorio** | `ROL-ORG-VICE-CHAIR` | Directorio | ⏳ |
| G006 | **Director Independiente** | `ROL-ORG-DIR-INDEP` | Directorio | ⏳ |
| G007 | **Director Ejecutivo** | `ROL-ORG-DIR-EJEC` | Directorio | ⏳ |
| G008 | **Director Suplente** | `ROL-ORG-DIR-SUPL` | Directorio | ⏳ |
| G009 | **Miembro del Comité de Auditoría** | `ROL-ORG-COM-AUDIT` | Comité | ⏳ |
| G010 | **Miembro del Comité de Riesgos** | `ROL-ORG-COM-RIESGO` | Comité | ⏳ |
| G011 | **Miembro del Comité de Remuneraciones** | `ROL-ORG-COM-REMUN` | Comité | ⏳ |
| G012 | **Miembro del Comité de Ética** | `ROL-ORG-COM-ETICA` | Comité | ⏳ |
| G013 | **Síndico / Fiscalizador** | `ROL-ORG-SINDICO` | Fiscalización | ⏳ |
| G014 | **Auditor Externo** | `ROL-EXT-AUDITOR` | Externo | ⏳ |
| G015 | **Asesor Legal del Directorio** | `ROL-ORG-ASESOR-DIR` | Directorio | ⏳ |

---

### 7.1 — N1: Alta Dirección

| # | Cargo | Código bAuth | Reporta a | Plantilla |
|---|-------|-------------|-----------|-----------|
| D001 | **Presidente Ejecutivo (CEO)** | `ROL-ORG-CEO` | Directorio | ⏳ |
| D002 | **Vicepresidente Ejecutivo (EVP)** | `ROL-ORG-EVP` | CEO | ⏳ |
| D003 | **Vicepresidente de Operaciones (COO)** | `ROL-ORG-COO` | CEO | ⏳ |
| D004 | **Vicepresidente de Finanzas (CFO)** | `ROL-ORG-CFO` | CEO | ⏳ |
| D005 | **Vicepresidente Comercial (CCO)** | `ROL-ORG-CCO` | CEO | ⏳ |
| D006 | **Vicepresidente de Tecnología (CTO)** | `ROL-ORG-CTO` | CEO | ⏳ |
| D007 | **Vicepresidente de RRHH (CHRO)** | `ROL-ORG-CHRO` | CEO | ⏳ |
| D008 | **Vicepresidente Legal (CLO)** | `ROL-ORG-CLO` | CEO | ⏳ |
| D009 | **Vicepresidente de Marketing (CMO)** | `ROL-ORG-CMO` | CEO | ⏳ |
| D010 | **Secretario General** | `ROL-ORG-SEC-GENERAL` | CEO | ⏳ |
| D011 | **Director de Cumplimiento (CCO)** | `ROL-ORG-COMPLIANCE` | Directorio | ⏳ |
| D012 | **Director de Auditoría Interna** | `ROL-ORG-AUDIT-INT` | Directorio | ⏳ |
| D013 | **Director de Estrategia (CSO)** | `ROL-ORG-CSO` | CEO | ⏳ |
| D014 | **Director de Innovación (CIO)** | `ROL-ORG-CIO-INNOV` | CEO | ⏳ |
| D015 | **Director de Sostenibilidad** | `ROL-ORG-SOSTENIB` | CEO | ⏳ |

### 7.2 — N2: Dirección de Área

| # | Cargo | Código bAuth | Área | Plantilla |
|---|-------|-------------|------|-----------|
| D020 | **Director Financiero** | `ROL-ORG-DIR-FIN` | Finanzas | ⏳ |
| D021 | **Director de Contabilidad** | `ROL-ORG-DIR-CONT` | Contabilidad | ⏳ |
| D022 | **Director de Tesorería** | `ROL-ORG-DIR-TESO` | Tesorería | ⏳ |
| D023 | **Director Comercial** | `ROL-ORG-DIR-COML` | Comercial | ⏳ |
| D024 | **Director de Ventas** | `ROL-ORG-DIR-VENT` | Ventas | ⏳ |
| D025 | **Director de Operaciones** | `ROL-ORG-DIR-OPER` | Operaciones | ⏳ |
| D026 | **Director de Logística** | `ROL-ORG-DIR-LOG` | Logística | ⏳ |
| D027 | **Director de IT** | `ROL-ORG-DIR-IT` | Tecnología | ⏳ |
| D028 | **Director de Infraestructura** | `ROL-ORG-DIR-INFRA` | Infraestructura | ⏳ |
| D029 | **Director de RRHH** | `ROL-ORG-DIR-RRHH` | Recursos Humanos | ⏳ |
| D030 | **Director de Marketing** | `ROL-ORG-DIR-MKT` | Marketing | ⏳ |
| D031 | **Director Legal** | `ROL-ORG-DIR-LEGAL` | Legal | ⏳ |
| D032 | **Director de Compras** | `ROL-ORG-DIR-COMP` | Compras | ⏳ |
| D033 | **Director de Calidad** | `ROL-ORG-DIR-CAL` | Calidad | ⏳ |
| D034 | **Director de Proyectos (PMO)** | `ROL-ORG-DIR-PMO` | PMO | ⏳ |
| D035 | **Director de Seguridad Patrimonial** | `ROL-ORG-DIR-SEG` | Seguridad Física | ⏳ |
| D036 | **Director de Seguridad Informática (CISO)** | `ROL-ORG-CISO` | Ciberseguridad | ⏳ |

### 7.3 — N3: Gerencia

| # | Cargo | Código bAuth | Departamento | Plantilla |
|---|-------|-------------|-------------|-----------|
| G001 | **Gerente Financiero** | `ROL-ORG-GER-FIN` | Finanzas | ⏳ |
| G002 | **Gerente de Contabilidad** | `ROL-ORG-GER-CONT` | Contabilidad | ⏳ |
| G003 | **Gerente de Tesorería** | `ROL-ORG-GER-TESO` | Tesorería | ⏳ |
| G004 | **Gerente de Ventas Regional** | `ROL-ORG-GER-VENT` | Ventas | ⏳ |
| G005 | **Gerente de Ventas Corporativas** | `ROL-ORG-GER-VENT-CORP` | Ventas | ⏳ |
| G006 | **Gerente de Post-Venta** | `ROL-ORG-GER-POSTVENTA` | Servicio al Cliente | ⏳ |
| G007 | **Gerente de Operaciones** | `ROL-ORG-GER-OPER` | Operaciones | ⏳ |
| G008 | **Gerente de Logística y Distribución** | `ROL-ORG-GER-LOG` | Logística | ⏳ |
| G009 | **Gerente de Almacén** | `ROL-ORG-GER-ALM` | Almacén | ⏳ |
| G010 | **Gerente de TI** | `ROL-ORG-GER-IT` | Tecnología | ⏳ |
| G011 | **Gerente de Desarrollo de Software** | `ROL-ORG-GER-DEV` | Desarrollo | ⏳ |
| G012 | **Gerente de Base de Datos** | `ROL-ORG-GER-DBA` | Datos | ⏳ |
| G013 | **Gerente de Redes y Comunicaciones** | `ROL-ORG-GER-REDES` | Redes | ⏳ |
| G014 | **Gerente de RRHH** | `ROL-ORG-GER-RRHH` | Recursos Humanos | ⏳ |
| G015 | **Gerente de Selección y Reclutamiento** | `ROL-ORG-GER-SELEC` | Selección | ⏳ |
| G016 | **Gerente de Capacitación** | `ROL-ORG-GER-CAP` | Capacitación | ⏳ |
| G017 | **Gerente de Nómina y Compensaciones** | `ROL-ORG-GER-NOM` | Nómina | ⏳ |
| G018 | **Gerente de Marketing Digital** | `ROL-ORG-GER-MKT` | Marketing | ⏳ |
| G019 | **Gerente de Publicidad** | `ROL-ORG-GER-PUB` | Publicidad | ⏳ |
| G020 | **Gerente de Compras** | `ROL-ORG-GER-COMP` | Compras | ⏳ |
| G021 | **Gerente de Proveedores** | `ROL-ORG-GER-PROV` | Proveeduría | ⏳ |
| G022 | **Gerente de Importaciones** | `ROL-ORG-GER-IMP` | Comercio Exterior | ⏳ |
| G023 | **Gerente de Exportaciones** | `ROL-ORG-GER-EXP` | Comercio Exterior | ⏳ |
| G024 | **Gerente de Producción** | `ROL-ORG-GER-PROD` | Producción | ⏳ |
| G025 | **Gerente de Mantenimiento** | `ROL-ORG-GER-MANT` | Mantenimiento | ⏳ |
| G026 | **Gerente de Calidad** | `ROL-ORG-GER-CAL` | Calidad | ⏳ |
| G027 | **Gerente Legal Corporativo** | `ROL-ORG-GER-LEGAL` | Legal | ⏳ |
| G028 | **Gerente de Sucursal** | `ROL-ORG-GER-SUC` | Sucursal | ⏳ |
| G029 | **Gerente de Franquicias** | `ROL-ORG-GER-FRANQ` | Expansión | ⏳ |

### 7.4 — N4: Jefatura / Supervisión

| # | Cargo | Código bAuth | Área | Plantilla |
|---|-------|-------------|------|-----------|
| J001 | **Jefe de Contabilidad** | `ROL-ORG-JEF-CONT` | Contabilidad | ⏳ |
| J002 | **Jefe de Cuentas por Pagar** | `ROL-ORG-JEF-CXP` | Finanzas | ⏳ |
| J003 | **Jefe de Cuentas por Cobrar** | `ROL-ORG-JEF-CXC` | Finanzas | ⏳ |
| J004 | **Jefe de Facturación** | `ROL-ORG-JEF-FACT` | Facturación | ⏳ |
| J005 | **Jefe de Ventas** | `ROL-ORG-JEF-VENT` | Ventas | ⏳ |
| J006 | **Supervisor de Ventas** | `ROL-ORG-SUP-VENT` | Ventas | ⏳ |
| J007 | **Jefe de Cajas** | `ROL-ORG-JEF-CAJAS` | Cajas | ⏳ |
| J008 | **Supervisor de Cajas** | `ROL-ORG-SUP-CAJAS` | Cajas | ⏳ |
| J009 | **Jefe de Almacén** | `ROL-ORG-JEF-ALM` | Almacén | ⏳ |
| J010 | **Jefe de Logística** | `ROL-ORG-JEF-LOG` | Logística | ⏳ |
| J011 | **Jefe de Despacho** | `ROL-ORG-JEF-DESP` | Despacho | ⏳ |
| J012 | **Jefe de Flota** | `ROL-ORG-JEF-FLOTA` | Transporte | ⏳ |
| J013 | **Jefe de Sistemas** | `ROL-ORG-JEF-SIST` | IT | ⏳ |
| J014 | **Jefe de Soporte Técnico** | `ROL-ORG-JEF-SOPORTE` | IT | ⏳ |
| J015 | **Jefe de Seguridad Informática** | `ROL-ORG-JEF-SEC-INFO` | Seguridad IT | ⏳ |
| J016 | **Jefe de Personal** | `ROL-ORG-JEF-PERS` | RRHH | ⏳ |
| J017 | **Jefe de Planilla** | `ROL-ORG-JEF-PLANILLA` | RRHH | ⏳ |
| J018 | **Jefe de Marketing** | `ROL-ORG-JEF-MKT` | Marketing | ⏳ |
| J019 | **Jefe de Compras** | `ROL-ORG-JEF-COMP` | Compras | ⏳ |
| J020 | **Jefe de Producción** | `ROL-ORG-JEF-PROD` | Producción | ⏳ |
| J021 | **Jefe de Calidad** | `ROL-ORG-JEF-CAL` | Calidad | ⏳ |
| J022 | **Jefe de Seguridad Patrimonial** | `ROL-ORG-JEF-SEG` | Seguridad | ⏳ |
| J023 | **Supervisor de Planta** | `ROL-ORG-SUP-PLANTA` | Producción | ⏳ |
| J024 | **Supervisor de Turno** | `ROL-ORG-SUP-TURNO` | Operaciones | ⏳ |

### 7.5 — N5: Staff de Apoyo

| # | Cargo | Código bAuth | Área | Plantilla |
|---|-------|-------------|------|-----------|
| A001 | **Secretaria de Gerencia** | `ROL-ORG-SEC-GER` | Administración | ⏳ |
| A002 | **Secretaria de Dirección** | `ROL-ORG-SEC-DIR` | Dirección | ⏳ |
| A003 | **Asistente Administrativo** | `ROL-ORG-ASIST-ADM` | Administración | ⏳ |
| A004 | **Asistente Contable** | `ROL-ORG-ASIST-CONT` | Contabilidad | ⏳ |
| A005 | **Asistente de RRHH** | `ROL-ORG-ASIST-RRHH` | RRHH | ⏳ |
| A006 | **Asistente de Compras** | `ROL-ORG-ASIST-COMP` | Compras | ⏳ |
| A007 | **Asistente de Ventas** | `ROL-ORG-ASIST-VENT` | Ventas | ⏳ |
| A008 | **Asistente de Marketing** | `ROL-ORG-ASIST-MKT` | Marketing | ⏳ |
| A009 | **Analista Financiero Senior** | `ROL-ORG-ANALIST-FIN` | Finanzas | ⏳ |
| A010 | **Analista de Datos** | `ROL-ORG-ANALIST-DATOS` | IT | ⏳ |
| A011 | **Recepcionista** | `ROL-ORG-RECEP` | Administración | ⏳ |
| A012 | **Telefonista / Call Center** | `ROL-ORG-TELEF` | Atención al Cliente | ⏳ |
| A013 | **Auxiliar de Oficina** | `ROL-ORG-AUX-OFI` | Administración | ⏳ |
| A014 | **Auxiliar de Archivo** | `ROL-ORG-AUX-ARCH` | Archivo | ⏳ |
| A015 | **Community Manager** | `ROL-ORG-COMM-MGR` | Marketing | ⏳ |

### 7.6 — N6: Personal Operativo

| # | Cargo | Código bAuth | Área | Plantilla |
|---|-------|-------------|------|-----------|
| O001 | **Vendedor Senior** | `ROL-ORG-VEND-SENIOR` | Ventas | ⏳ |
| O002 | **Vendedor Junior** | `ROL-ORG-VEND-JUNIOR` | Ventas | ⏳ |
| O003 | **Cajero Principal** | `ROL-ORG-CAJ-PRIN` | Cajas | ⏳ |
| O004 | **Cajero** | `ROL-ORG-CAJ` | Cajas | ⏳ |
| O005 | **Contador Senior** | `ROL-ORG-CONT-SENIOR` | Contabilidad | ⏳ |
| O006 | **Contador Junior** | `ROL-ORG-CONT-JUNIOR` | Contabilidad | ⏳ |
| O007 | **Auxiliar Contable** | `ROL-ORG-AUX-CONT` | Contabilidad | ⏳ |
| O008 | **Tesorero** | `ROL-ORG-TESORERO` | Tesorería | ⏳ |
| O009 | **Encargado de Cobranzas** | `ROL-ORG-COBRANZAS` | Cobranzas | ⏳ |
| O010 | **Encargado de Facturación** | `ROL-ORG-FACTURADOR` | Facturación | ⏳ |
| O011 | **Encargado de Nómina** | `ROL-ORG-NOMINISTA` | RRHH | ⏳ |
| O012 | **Reclutador** | `ROL-ORG-RECLUTADOR` | RRHH | ⏳ |
| O013 | **Capacitador** | `ROL-ORG-CAPACITADOR` | RRHH | ⏳ |
| O014 | **Encargado de Almacén** | `ROL-ORG-ALMACENERO` | Almacén | ⏳ |
| O015 | **Encargado de Inventario** | `ROL-ORG-INVENTARISTA` | Inventario | ⏳ |
| O016 | **Despachador** | `ROL-ORG-DESPACHADOR` | Despacho | ⏳ |
| O017 | **Encargado de Logística** | `ROL-ORG-LOGISTICO` | Logística | ⏳ |
| O018 | **Técnico de Sistemas** | `ROL-ORG-TEC-SIST` | IT | ⏳ |
| O019 | **Técnico de Soporte N1** | `ROL-ORG-SOPORTE-N1` | IT | ⏳ |
| O020 | **Técnico de Soporte N2** | `ROL-ORG-SOPORTE-N2` | IT | ⏳ |
| O021 | **Programador Junior** | `ROL-ORG-DEV-JUNIOR` | Desarrollo | ⏳ |
| O022 | **Programador Senior** | `ROL-ORG-DEV-SENIOR` | Desarrollo | ⏳ |
| O023 | **Diseñador Gráfico** | `ROL-ORG-DISENADOR` | Marketing | ⏳ |
| O024 | **Fotógrafo / Camarógrafo** | `ROL-ORG-FOTOGRAFO` | Marketing | ⏳ |
| O025 | **Operario de Producción** | `ROL-ORG-OPERARIO` | Producción | ⏳ |
| O026 | **Operario de Máquina** | `ROL-ORG-MAQUINISTA` | Producción | ⏳ |
| O027 | **Técnico de Control de Calidad** | `ROL-ORG-TEC-CAL` | Calidad | ⏳ |
| O028 | **Técnico de Mantenimiento** | `ROL-ORG-TEC-MANT` | Mantenimiento | ⏳ |
| O029 | **Electricista** | `ROL-ORG-ELECTRICISTA` | Mantenimiento | ⏳ |
| O030 | **Plomero** | `ROL-ORG-PLOMERO` | Mantenimiento | ⏳ |
| O031 | **Encargado de Compras** | `ROL-ORG-COMPRADOR` | Compras | ⏳ |
| O032 | **Encargado de Importaciones** | `ROL-ORG-IMPORTADOR` | Comercio Exterior | ⏳ |
| O033 | **Encargado de Exportaciones** | `ROL-ORG-EXPORTADOR` | Comercio Exterior | ⏳ |
| O034 | **Abogado Junior** | `ROL-ORG-ABOGADO-JR` | Legal | ⏳ |
| O035 | **Abogado Senior** | `ROL-ORG-ABOGADO-SR` | Legal | ⏳ |
| O036 | **Enfermero/a Ocupacional** | `ROL-ORG-ENFERMERO` | Salud Ocupacional | ⏳ |

### 7.7 — N7: Servicios Generales

| # | Cargo | Código bAuth | Área | Plantilla |
|---|-------|-------------|------|-----------|
| S001 | **Chofer Ejecutivo** | `ROL-ORG-CHOFER-EJEC` | Transporte | ⏳ |
| S002 | **Chofer de Reparto** | `ROL-ORG-CHOFER-REP` | Logística | ⏳ |
| S003 | **Chofer de Planta** | `ROL-ORG-CHOFER-PLANTA` | Transporte | ⏳ |
| S004 | **Portero / Conserje** | `ROL-ORG-PORTERO` | Servicios Generales | ⏳ |
| S005 | **Vigilante / Guardia de Seguridad** | `ROL-ORG-VIGILANTE` | Seguridad | ⏳ |
| S006 | **Mensajero Interno** | `ROL-ORG-MENSAJERO` | Administración | ⏳ |
| S007 | **Mensajero Externo / Courier** | `ROL-ORG-COURIER` | Administración | ⏳ |
| S008 | **Personal de Limpieza** | `ROL-ORG-LIMPIEZA` | Servicios Generales | ⏳ |
| S009 | **Jardinero** | `ROL-ORG-JARDINERO` | Servicios Generales | ⏳ |
| S010 | **Encargado de Estacionamiento** | `ROL-ORG-ESTACION` | Servicios Generales | ⏳ |
| S011 | **Cocinero / Cafetería** | `ROL-ORG-COCINERO` | Servicios Generales | ⏳ |
| S012 | **Cadete / Office Boy** | `ROL-ORG-CADETE` | Administración | ⏳ |
| S013 | **Ascensorista** | `ROL-ORG-ASCENSORISTA` | Servicios Generales | ⏳ |

### 7.8 — Resumen General del Catálogo

| Jerarquía | Nivel | Cantidad |
|-----------|-------|----------|
| Roles Sistémicos (SU, N1-N4) | §2 | 48 |
| Alta Dirección (CEO, VP) | N1 | 12 |
| Dirección de Área | N2 | 17 |
| Gerencia | N3 | 29 |
| Jefatura / Supervisión | N4 | 24 |
| Staff de Apoyo | N5 | 15 |
| Personal Operativo | N6 | 36 |
| Servicios Generales | N7 | 13 |
| Actores Externos (Clientes, Proveedores) | §5-6 | ~146 |
| **TOTAL CATÁLOGO** | | **~340 roles** |

---

---

## 8. ESCALABILIDAD DEL CATÁLOGO — De la Tienda de Barrio a la Corporación

> **Principio:** El mismo código de rol funciona en cualquier tamaño de organización.
> Lo que cambia es CUÁLES roles se activan y con QUÉ overrides.

### 8.1 — Tamaños Organizacionales

| Tamaño | Empleados | Estructura | Facturación anual |
|--------|-----------|------------|-------------------|
| **Corporación** | 500+ | N0-N7 completo | >$50MM |
| **Gran Empresa** | 200-500 | N1-N7 (sin N0) | $10MM-$50MM |
| **Empresa Mediana** | 50-200 | N2-N6 | $1MM-$10MM |
| **Pequeña Empresa (PYME)** | 10-50 | Dueño + N3/N4 + N6 | $100K-$1MM |
| **Microempresa** | 3-10 | Dueño + N6 | <$100K |
| **Tienda de Barrio / Unipersonal** | 1-3 | Dueño + 1 ayudante | <$30K |

### 8.2 — Roles mínimos por tamaño

#### CORPORACIÓN (500+ empleados) — 150+ roles activos

```
N0: Accionistas, Directorio (5), Comités (4), Síndico, Auditor Externo
N1: CEO, COO, CFO, CTO, CHRO, CLO, CMO, CSO, Compliance, Auditoría Interna
N2: Directores de Área (los 17)
N3: Gerentes de Departamento (todos)
N4: Jefes y Supervisores (todos)
N5: Staff de Apoyo (todos)
N6: Personal Operativo (por área)
N7: Servicios Generales (todos)
```

#### GRAN EMPRESA (200-500 empleados) — ~80 roles activos

```
N1: CEO, COO, CFO, CTO, CHRO, CLO
N2: Directores de Área (10-12 principales)
N3: Gerentes de Departamento (15-20)
N4: Jefes y Supervisores (10-15)
N5: Staff de Apoyo (8-10)
N6: Personal Operativo (por área)
N7: Servicios Generales (básicos)
```

#### EMPRESA MEDIANA (50-200 empleados) — ~35 roles activos

```
N2: Director Financiero, Director Comercial, Director de Operaciones
N3: Gerente de Ventas, Gerente de RRHH, Gerente de IT, Gerente de Producción
N4: Jefe de Contabilidad, Jefe de Ventas, Supervisor de Planta
N5: Secretaria de Gerencia, Asistente Contable, Recepcionista
N6: Vendedores (3-5), Cajeros (2-3), Contador, Técnico de Sistemas,
    Encargado de Almacén, Encargado de Facturación, Operarios (5-10)
N7: Chofer, Portero, Personal de Limpieza
```

#### PEQUEÑA EMPRESA / PYME (10-50 empleados) — ~15 roles activos

```
Dueño/Gerente General (ROL-ORG-GER-SUC con override: scope=GLOBAL)
  ├── Contador (ROL-ORG-CONT-SENIOR)
  ├── Vendedor Senior + 2 Vendedores Junior
  ├── Cajero (ROL-ORG-CAJ)
  ├── Encargado de Almacén (ROL-ORG-ALMACENERO)
  ├── Encargado de Facturación (ROL-ORG-FACTURADOR)
  ├── Técnico de Sistemas (ROL-ORG-TEC-SIST)
  └── Personal de Limpieza (ROL-ORG-LIMPIEZA)
```

| # | Cargo | Código | Override típico PYME |
|---|-------|--------|----------------------|
| P01 | **Dueño / Gerente General** | `ROL-ORG-GER-SUC` | scope=GLOBAL, approval_limit=$10K |
| P02 | **Contador** | `ROL-ORG-CONT-SENIOR` | scope=COMPANY |
| P03 | **Vendedor Senior** | `ROL-ORG-VEND-SENIOR` | scope=BRANCH, max_discount=15% |
| P04 | **Vendedor Junior** | `ROL-ORG-VEND-JUNIOR` | scope=BRANCH, max_discount=5% |
| P05 | **Cajero** | `ROL-ORG-CAJ` | scope=BRANCH, max_cash=$2K |
| P06 | **Encargado de Almacén** | `ROL-ORG-ALMACENERO` | scope=BRANCH |
| P07 | **Encargado de Facturación** | `ROL-ORG-FACTURADOR` | scope=COMPANY |
| P08 | **Técnico de Sistemas** | `ROL-ORG-TEC-SIST` | scope=COMPANY |
| P09 | **Personal de Limpieza** | `ROL-ORG-LIMPIEZA` | scope=BRANCH |

#### MICROEMPRESA (3-10 empleados) — ~5 roles activos

| # | Cargo | Código | Notas |
|---|-------|--------|-------|
| M01 | **Dueño / Administrador** | `ROL-ORG-GER-SUC` | Hace todo: ventas, compras, caja, contabilidad |
| M02 | **Vendedor / Cajero** | `ROL-ORG-VEND-JUNIOR` | Override: can_access_caja=true |
| M03 | **Ayudante General** | `ROL-ORG-AUX-OFI` | Override: can_access_almacen=true |
| M04 | **Chofer de Reparto** | `ROL-ORG-CHOFER-REP` | Si aplica |
| M05 | **Contador Externo** | `ROL-EXT-CONTADOR` | Externo, acceso limitado a contabilidad |

#### TIENDA DE BARRIO / UNIPERSONAL (1-3 empleados) — ~3 roles activos

| # | Cargo | Código | Notas |
|---|-------|--------|-------|
| T01 | **Dueño / Único empleado** | `ROL-ORG-GER-SUC` | Override: all_permissions=true, scope=GLOBAL |
| T02 | **Ayudante / Familiar** | `ROL-ORG-VEND-JUNIOR` | Override: max_discount=0%, max_cash=$500 |
| T03 | **Contador Externo (opcional)** | `ROL-EXT-CONTADOR` | Solo facturación y declaraciones SIN |

### 8.3 — Tabla de Activación por Tamaño

| Sección del Catálogo | Corp | Gran | Med | PYME | Micro | Tienda |
|---------------------|------|------|-----|------|-------|--------|
| **N0 Gobierno Corp** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **N1 Alta Dirección** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **N2 Direc. Área** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **N3 Gerencia** | ✅ | ✅ | ✅ | ✅¹ | ❌ | ❌ |
| **N4 Jefatura** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **N5 Staff Apoyo** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **N6 Operativo** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅² |
| **N7 Serv. Grales** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Roles Sistémicos** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅³ |

¹ Solo Dueño/Gerente General con scope=GLOBAL
² Dueño + 1-2 ayudantes
³ Solo roles de tenant admin, sin roles de plataforma

---

*Documento actualizado 2026-06-24. ~355 roles en 8 niveles + 6 tamaños organizacionales.
Escalable desde Tienda de Barrio (3 roles) hasta Corporación (150+ roles).
El mismo código de rol sirve para todos los tamaños. Solo cambia qué se activa.*

---
*BAUTH-CATALOGO-ROLES-EMPRESARIALES v2.0 · 2026-06-19 · SKULL · 368 roles (48 sistémicos + 174 internos + 146 externos) · 21 sectores CAEB SIN · 66 plantillas · NIST RBAC Nivel 3 · ISO 27001:2022 A.8.2 · ISO 9001:2015 · Anexo: BAUTH-CADENAS-JERARQUIA.md*

---

## 9. ÁREAS ORGANIZACIONALES — Relación 1:N con Roles

> **Concepto:** Un Área es una unidad funcional de la organización. Cada área agrupa roles
> que comparten propósito, presupuesto y supervisión. El mismo rol (Secretaria, Chofer,
> Mensajero) puede existir en MÚLTIPLES áreas. Relación 1:N → Área : Roles.

### 9.0 — Tabla de Áreas Organizacionales

| Código | Área | Descripción | Nivel |
|--------|------|-------------|-------|
| `AREA-DIR` | **Dirección General** | CEO, EVP, Secretaria de Dirección, Chofer Ejecutivo, Asesor Legal | N1 |
| `AREA-FIN` | **Gerencia Financiera** | CFO, Director Financiero, Gerente Financiero, Contador Senior, Contador Junior, Tesorero, Auxiliar Contable, Secretaria, Mensajero, Chofer | N2 |
| `AREA-CONT` | **Contabilidad** | Jefe de Contabilidad, Contador Senior, Contador Junior, Auxiliar Contable, Encargado de Facturación, Secretaria | N3 |
| `AREA-TESO` | **Tesorería** | Director de Tesorería, Tesorero, Encargado de Cobranzas, Auxiliar Contable, Secretaria | N3 |
| `AREA-COM` | **Dirección Comercial** | CCO, Director Comercial, Gerente de Ventas, Vendedor Senior, Vendedor Junior, Secretaria, Chofer | N2 |
| `AREA-VENT` | **Ventas** | Gerente de Ventas Regional, Jefe de Ventas, Supervisor de Ventas, Vendedor Senior (x3), Vendedor Junior (x5), Asistente de Ventas, Secretaria, Chofer de Reparto, Mensajero | N3 |
| `AREA-POST` | **Post-Venta / Servicio al Cliente** | Gerente de Post-Venta, Telefonista, Community Manager, Técnico de Soporte N1, Secretaria | N3 |
| `AREA-MKT` | **Marketing** | CMO, Director de Marketing, Gerente de Marketing Digital, Gerente de Publicidad, Jefe de Marketing, Diseñador Gráfico, Fotógrafo, Community Manager, Analista de Datos, Secretaria | N2 |
| `AREA-OPER` | **Operaciones** | COO, Director de Operaciones, Gerente de Operaciones, Jefe de Logística, Jefe de Despacho, Supervisor de Turno, Secretaria, Mensajero | N2 |
| `AREA-LOG` | **Logística y Distribución** | Director de Logística, Gerente de Logística, Jefe de Almacén, Jefe de Despacho, Encargado de Almacén, Despachador, Chofer de Reparto (x3), Cadete | N3 |
| `AREA-ALM` | **Almacén** | Jefe de Almacén, Encargado de Almacén, Encargado de Inventario, Despachador, Auxiliar de Oficina | N4 |
| `AREA-IT` | **Tecnología de la Información** | CTO, Director de IT, Director de Infraestructura, Gerente de TI, Jefe de Sistemas, Jefe de Soporte Técnico, Programador Senior, Técnico de Sistemas, Técnico de Soporte N2, Analista de Datos, Secretaria | N2 |
| `AREA-DEV` | **Desarrollo de Software** | Gerente de Desarrollo, Programador Senior (x3), Programador Junior (x2), Analista de Datos | N3 |
| `AREA-SEC-INFO` | **Seguridad Informática** | CISO, Gerente de Redes, Jefe de Seguridad Informática, Técnico de Sistemas | N3 |
| `AREA-RRHH` | **Recursos Humanos** | CHRO, Director de RRHH, Gerente de RRHH, Jefe de Personal, Reclutador, Capacitador, Encargado de Nómina, Asistente de RRHH, Secretaria, Chofer | N2 |
| `AREA-SELEC` | **Selección y Reclutamiento** | Gerente de Selección, Reclutador, Asistente de RRHH, Secretaria | N3 |
| `AREA-NOM` | **Nómina y Compensaciones** | Gerente de Nómina, Jefe de Planilla, Encargado de Nómina, Auxiliar Contable | N3 |
| `AREA-LEGAL` | **Dirección Legal** | CLO, Director Legal, Gerente Legal Corporativo, Abogado Senior, Abogado Junior, Asistente, Secretaria, Mensajero, Chofer | N2 |
| `AREA-COMP` | **Compras y Proveeduría** | Director de Compras, Gerente de Compras, Gerente de Proveedores, Jefe de Compras, Encargado de Compras, Asistente de Compras, Secretaria | N2 |
| `AREA-IMP` | **Importaciones** | Gerente de Importaciones, Encargado de Importaciones, Asistente, Mensajero | N3 |
| `AREA-EXP` | **Exportaciones** | Gerente de Exportaciones, Encargado de Exportaciones, Asistente | N3 |
| `AREA-PROD` | **Producción** | Gerente de Producción, Jefe de Producción, Supervisor de Planta, Supervisor de Turno (x2), Operario de Producción (x10), Operario de Máquina (x3), Técnico de Control de Calidad, Secretaria | N2 |
| `AREA-CAL` | **Control de Calidad** | Director de Calidad, Gerente de Calidad, Jefe de Calidad, Técnico de Control de Calidad (x2) | N3 |
| `AREA-MANT` | **Mantenimiento** | Gerente de Mantenimiento, Técnico de Mantenimiento (x2), Electricista, Plomero | N3 |
| `AREA-SEG` | **Seguridad Patrimonial** | Director de Seguridad Patrimonial, Jefe de Seguridad, Vigilante / Guardia (x4), Portero, Encargado de Estacionamiento | N2 |
| `AREA-ADM` | **Administración General** | Secretario General, Secretaria de Dirección, Recepcionista, Telefonista, Auxiliar de Oficina, Auxiliar de Archivo, Cadete, Mensajero Interno | N2 |
| `AREA-SERV` | **Servicios Generales** | Personal de Limpieza (x3), Jardinero, Encargado de Estacionamiento, Cocinero / Cafetería, Ascensorista, Portero | N4 |
| `AREA-TRANS` | **Transporte** | Jefe de Flota, Chofer Ejecutivo, Chofer de Reparto (x3), Chofer de Planta, Mensajero Externo / Courier | N3 |
| `AREA-HEALTH` | **Salud Ocupacional** | Enfermero/a Ocupacional, Asistente | N3 |
| `AREA-PMO` | **Oficina de Proyectos** | Director de Proyectos, Gerente (por proyecto) | N2 |
| `AREA-SOST` | **Sostenibilidad y RSE** | Director de Sostenibilidad, Asistente | N2 |

### 9.1 — Relación 1:N — Área → Roles

```
AREA-FIN (Gerencia Financiera)
  ├── Exclusivos: CFO, Director Financiero, Gerente Financiero, Contador, Tesorero
  └── Compartidos: Secretaria, Mensajero, Chofer, Auxiliar de Oficina

AREA-RRHH (Recursos Humanos)
  ├── Exclusivos: CHRO, Director de RRHH, Gerente de RRHH, Reclutador, Capacitador
  └── Compartidos: Secretaria, Chofer, Mensajero, Auxiliar de Oficina
```

### 9.2 — Roles Compartidos entre Áreas

| Rol Compartido | Áreas donde puede existir |
|---------------|--------------------------|
| **Secretaria** | AREA-DIR, AREA-FIN, AREA-CONT, AREA-COM, AREA-VENT, AREA-MKT, AREA-OPER, AREA-IT, AREA-RRHH, AREA-LEGAL, AREA-COMP, AREA-PROD, AREA-ADM |
| **Chofer** | AREA-DIR, AREA-FIN, AREA-COM, AREA-RRHH, AREA-LEGAL, AREA-TRANS |
| **Mensajero** | AREA-FIN, AREA-COM, AREA-VENT, AREA-OPER, AREA-LEGAL, AREA-IMP, AREA-ADM |
| **Auxiliar de Oficina** | AREA-FIN, AREA-ALM, AREA-ADM |
| **Cadete** | AREA-ADM, AREA-LOG |
| **Analista de Datos** | AREA-MKT, AREA-IT, AREA-DEV |
| **Técnico de Sistemas** | AREA-IT, AREA-SEC-INFO |

### 9.3 — Seed para `log_zone` (29 áreas)

Cada área organizacional es un registro en `log_zone`. Área 1:N Roles vía `log_permission`.

### 9.4 — Activación de Áreas por Tamaño

| Área | Corp | Gran | Med | PYME | Micro | Tienda |
|------|------|------|-----|------|-------|--------|
| AREA-DIR | ✅ | ✅ | ✅ | ✅* | ✅* | ✅* |
| AREA-FIN | ✅ | ✅ | ✅ | ✅* | ❌ | ❌ |
| AREA-CONT | ✅ | ✅ | ✅ | ✅* | ❌ | ❌ |
| AREA-COM | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| AREA-VENT | ✅ | ✅ | ✅ | ✅ | ✅* | ❌ |
| AREA-MKT | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| AREA-OPER | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| AREA-LOG | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| AREA-ALM | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| AREA-IT | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| AREA-RRHH | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| AREA-LEGAL | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| AREA-COMP | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| AREA-PROD | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| AREA-SEG | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| AREA-ADM | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| AREA-SERV | ✅ | ✅ | ✅ | ✅ | ✅ | ✅* |
| AREA-TRANS | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |

* Dueño concentra múltiples funciones en este tamaño.

