# SBOS-006-FICHA
## Especificación Técnica: Sistema de Fichas

### SKULL · SBOS — Sovereign Business Operating System
### v4.0 · Marzo 2026

---

## Tabla de Contenidos

1. [Fundamento Conceptual](#1-fundamento-conceptual)
2. [Posición en el Ecosistema Cloud-Native](#2-posición-en-el-ecosistema-cloud-native)
3. [Definición Canónica](#3-definición-canónica)
4. [Los Tres Contratos de una Ficha](#4-los-tres-contratos-de-una-ficha)
5. [Los Tres Tipos de Fichas](#5-los-tres-tipos-de-fichas)
6. [Los Cinco Estados del Ciclo de Vida](#6-los-cinco-estados-del-ciclo-de-vida)
7. [El Orden de Ejecución de las Fichas](#7-el-orden-de-ejecución-de-las-fichas)
8. [Estructura Física](#8-estructura-física)
9. [La Jerarquía de Conocimiento Operacional](#9-la-jerarquía-de-conocimiento-operacional)
10. [Estructura de Servidores Lógicos](#10-estructura-de-servidores-lógicos)
11. [El Contrato de Identidad: manifest.yml](#11-el-contrato-de-identidad-manifestyml)
12. [El Contrato Temporal: yaml_engine.yml](#12-el-contrato-temporal-yaml_engineyml)
13. [El Catálogo de Tareas: task_catalog.sh](#13-el-catálogo-de-tareas-task_catalogsh)
14. [Los Resources: Conocimiento de Producción Cristalizado](#14-los-resources-conocimiento-de-producción-cristalizado)
15. [El Loop de Reconciliación](#15-el-loop-de-reconciliación)
16. [Gobernanza y Control Dual](#16-gobernanza-y-control-dual)
17. [Versionado y Migración de Fichas](#17-versionado-y-migración-de-fichas)
18. [Extensibilidad: La Propiedad Más Importante](#18-extensibilidad-la-propiedad-más-importante)
19. [Registro de Cambios](#19-registro-de-cambios)

---

## 1. Fundamento Conceptual

### El problema que resuelve

Los sistemas de instalación de software empresarial han evolucionado en tres generaciones:

**Primera generación — Scripts monolíticos.** Todo el conocimiento operacional en un único archivo Bash. Funciona para 3 apps. Con 10 apps el archivo tiene 500 líneas. Con 30 apps es imposible de mantener. El conocimiento sobre *cómo funciona PostgreSQL* vive mezclado con el conocimiento sobre *cómo funciona el sistema de instalación*. Cuando el técnico que lo escribió se va, el sistema se vuelve opaco.

**Segunda generación — Stacks declarativos.** Docker Compose, Helm charts, Ansible playbooks. Mejor separación, pero el conocimiento de *Day 1* (instalación) es lo único que está bien cubierto. Las operaciones de *Day 2* — reparar, actualizar, diagnosticar, integrar con el ecosistema — siguen siendo runbooks manuales o scripts ad-hoc.

**Tercera generación — Conocimiento operacional codificado.** La industria convergió en este modelo bajo distintos nombres: el **Operator Pattern** de Kubernetes (CoreOS, 2016), los **Cloud Native Application Bundles** / CNAB de Microsoft y Docker (2018), el concepto de **Golden Paths** del Platform Engineering (Spotify, Netflix), y los **Runbooks automatizados** del SRE. Todos comparten la misma intuición: *el conocimiento experto sobre cómo operar una aplicación debe vivir junto a la aplicación misma, codificado de forma que una máquina pueda ejecutarlo.*

Una **ficha SBOS** es la implementación soberana de este principio para el stack empresarial boliviano e iberoamericano. No depende de ningún proveedor externo. Corre en hardware propio. Y preserva el conocimiento operacional acumulado de producción real.

### La analogía precisa

En el mundo del Operator Pattern de Kubernetes, la idea original fue tomar el conocimiento que un ingeniero tiene dentro de un script o runbook — conocimiento de dominio específico — y escribir software que pueda hacer eso automáticamente.

Una ficha SBOS es exactamente eso, pero más compacta y más soberana: en lugar de un controlador Go corriendo en el cluster, es una carpeta con contratos declarativos que el IAM Installer ejecuta. El resultado práctico es el mismo: el sistema no solo corre la aplicación, sino que la entiende y la gestiona durante todo su ciclo de vida.

---

## 2. Posición en el Ecosistema Cloud-Native

Es útil entender dónde se ubica la ficha SBOS en relación a los estándares de la industria:

| Estándar / Patrón | Qué resuelve bien | Qué le falta |
|---|---|---|
| **Helm Chart** | Packaging y templating de manifests K8s | Cubre Day 1. Las operaciones Day 2 (backup, repair, integración con SSO) quedan fuera del chart |
| **Kubernetes Operator** | Ciclo de vida completo con reconciliación continua | Requiere escribir un controlador en Go o Python. Complejidad muy alta para cada app |
| **CNAB / Porter** | Bundle autocontenido multi-herramienta (Helm + Terraform + scripts) | Orientado a distribución cloud-agnostic. No define semántica de estados ni governance |
| **Ansible Role** | Automatización idempotente de configuración | No tiene concepto nativo de dependencias entre apps ni de estados del ciclo de vida |
| **Platform Engineering Golden Path** | Templates + self-service para developers | Define el *qué*, no el *cómo operar en producción* |
| **Ficha SBOS** | Todo el ciclo de vida (Day 1 + Day 2) + integración ecosistema + governance + conocimiento de producción | Específico para SBOS. No es cloud-agnostic intencionalmente |

La ficha SBOS toma lo mejor de cada patrón:
- Del **Operator Pattern**: la filosofía de codificar conocimiento operacional y el loop de reconciliación.
- Del **CNAB**: el bundle autocontenido con todo lo necesario para instalar y operar.
- Del **Golden Path**: la idea de que el camino correcto debe ser el más fácil y debe estar completamente documentado.
- De la experiencia de producción real: el conocimiento concreto que solo se obtiene operando el sistema en producción.

---

## 3. Definición Canónica

> **Una ficha SBOS es la unidad de despliegue atómica del Sovereign Business Operating System.**
>
> Es un contrato autocontenido que encapsula todo el conocimiento necesario para que el IAM Installer lleve una aplicación desde el estado `NO INSTALADA` hasta `INSTALADA — OK`, y la mantenga operativa durante toda su vida útil — sin que el Core sepa qué aplicación es.

La ficha no es un contenedor. No es un script. No es un manifiesto Kubernetes. Es el **conocimiento operacional completo** de una aplicación, expresado en un lenguaje que una máquina puede ejecutar y un humano puede auditar.

**La propiedad más importante:** el IAM Installer Core no sabe que PostgreSQL existe. PostgreSQL no sabe cómo funciona el Core. Esta ignorancia mutua es el diseño — no un accidente. Es lo que hace al sistema extensible sin límite teórico. Agregar la aplicación número 97 al SBOS es crear una carpeta. Nada más cambia en el sistema.

---

## 4. Los Tres Contratos de una Ficha

Toda ficha es simultáneamente tres contratos:

### Contrato con el Sistema — `manifest.yml`

Declara la identidad de la app, sus requisitos de recursos, sus dependencias con otras fichas, y bajo qué régimen de gobernanza opera. Es la fuente de verdad que el `DEPENDENCY_RESOLVER` lee para construir el grafo de instalación, y que el `HEALTH_CHECKER` lee para saber cómo verificar que la app está viva.

Este contrato responde: *¿Qué soy? ¿Qué necesito para existir? ¿Con qué governance opero?*

### Contrato con el Tiempo — `yaml_engine.yml`

Declara qué debe ocurrir en cada momento del ciclo de vida de la aplicación: instalación inicial, actualización, reparación, desinstalación. No contiene lógica Bash — contiene **intención declarativa**. La lógica vive en los catálogos de tareas.

Este contrato responde: *¿Qué debe ocurrir cuando me instalan, me actualizan, me reparan, me desinstalan?*

### Contrato con el Ecosistema — `resources/`

Contiene los datos que integran la aplicación con el resto del stack: el cliente OIDC para Keycloak, las rutas para Kong, la política de secretos para Vault, el schema SQL inicial, la configuración probada en producción. Estos no son archivos de ejemplo — son **conocimiento operacional cristalizado** que hace que la aplicación esté lista para usarse desde el primer minuto, no solo "arrancada".

Este contrato responde: *¿Cómo me integro con el ecosistema completo del SBOS?*

---

## 5. Los Tres Tipos de Fichas

Los tipos no son categorías arbitrarias. Reflejan el **momento del ciclo de vida del sistema** en que cada ficha opera y la plataforma de ejecución que requiere.

### Tipo 1 — Ficha de Sistema

**Cuándo corre:** antes de que Kubernetes exista, o para mantener la infraestructura base del nodo.

**Ejemplos canónicos:** `sbos-bootstrap-os`, `sbos-bootstrap-k8s`, `sbos-bootstrap-platform`, `sbos-bootstrap-hardening` — estas fichas construyen la plataforma sobre la que correrán todas las demás. El bootstrap original se dividió en etapas para permitir que fichas de aplicación (PostgreSQL, Vault) se intercalen en la secuencia según dependencias técnicas (ver SBOS-031-INSTALL-ROUTINE).

**Características:**
- `workload.type: bash` — se ejecuta directamente en el host Linux, no como contenedor K8s
- El IAM Installer las revisa en cada arranque y aplica cambios pendientes automáticamente
- No aparecen en el menú del Core UI — son infraestructura invisible
- Pueden surgir nuevas Fichas de Sistema para cualquier tarea de mantenimiento del host no prevista en el bootstrap original: actualizar el kernel, instalar librerías del sistema, rotar certificados TLS del cluster

### Tipo 2 — Ficha de Aplicación

**Cuándo corre:** con Kubernetes disponible y operativo.

**Ejemplos:** PostgreSQL, Keycloak, Redis, Kong, Nextcloud, OrangeHRM, Traccar.

**Características:**
- `workload.type: kubernetes` — se despliega vía `sbos_k8s_core()`
- Instalable por CLI (`bosctl install <ficha>`) o por Core UI cuando exista
- Tiene **dependencias dinámicas** — el `DEPENDENCY_RESOLVER` calcula automáticamente la cadena completa antes de instalar
- Algunas son esenciales para el stack (PostgreSQL, Keycloak, Redis); otras son opcionales según las necesidades del cliente
- Las fichas se agrupan en **Productos** (SBOS-032-PRODUCTS): un producto es un manifiesto que define qué fichas instalar y qué configuraciones inyectar en fichas existentes para entregar una solución completa

### Tipo 3 — Ficha Opcional Pura

**Cuándo corre:** en cualquier momento, sin impacto en el stack base.

**Ejemplos:** LibreOffice, configuraciones de carpetas corporativas, herramientas de productividad.

**Características:**
- No tiene dependencias críticas — no bloquea ni es bloqueada por otras fichas
- `criticality: false` en el manifest
- No son aplicaciones desarrolladas por el equipo SKULL — son configuraciones empaquetadas sobre software existente

---

## 6. Los Cinco Estados del Ciclo de Vida

| Estado | Condición | Acciones disponibles en Core UI |
|---|---|---|
| `BLOQUEADA` | Dependencias no satisfechas | Ver requisitos faltantes · Instalar prerequisitos en cadena |
| `NO INSTALADA` | Dependencias satisfechas | Instalar |
| `INSTALADA — OK` | Pod Running + health checks pasando | Verificar · Reparar · Actualizar · Desinstalar |
| `INSTALADA — ALERTA` | Pod en CrashLoopBackOff o health failing | Reparar · Ver logs · Diagnóstico |
| `ACTUALIZACIÓN DISPONIBLE` | Drift detectado en `resources/` o nueva versión en manifest | Actualizar · Omitir esta versión · Ver diff |

**Nota sobre `BLOQUEADA`:** este estado protege la integridad del sistema. No es posible instalar Roundcube si PostgreSQL está en estado `NO INSTALADA`. El sistema no asume — verifica. El administrador puede instalar los prerequisitos en cadena con un solo clic.

**Nota sobre `ACTUALIZACIÓN DISPONIBLE`:** el `RECONCILE_SCHEDULER` detecta drift comparando hashes SHA-256 de los archivos en `resources/` contra los hashes registrados en el estado. Si un archivo de configuración fue modificado manualmente en el cluster, el sistema lo reporta como drift y ofrece ver el diff exacto antes de decidir qué hacer.

---

## 7. El Orden de Ejecución de las Fichas

Esta es una de las propiedades más importantes del sistema y merece su propia sección. La pregunta es: cuando el administrador instala el stack completo, ¿cómo sabe el `DEPENDENCY_RESOLVER` en qué orden ejecutar 96 fichas?

La respuesta es que existen **dos mecanismos que trabajan juntos**, y uno tiene prioridad absoluta sobre el otro.

### Mecanismo 1 — `execution_order`: preferencia global

Cada ficha declara un número entero `execution_order` en su manifest. Un número menor significa que se ejecuta antes. Este número es la preferencia del diseñador de la ficha cuando no hay otras restricciones.

```yaml
# Ejemplos de execution_order por servidor lógico
hostserver/sbos-bootstrap:       order: 0    # Siempre primero — absoluto
hostserver/sbos-k8s-upgrader:    order: 1
hostserver/sbos-cert-rotation:   order: 2
hostserver/sbos-compliance-check: order: 3
hostserver/sbos-node-hardening:  order: 4
dataserver/postgresql:           order: 100
dataserver/redis:                order: 110
identityserver/vault:            order: 120
identityserver/keycloak:         order: 130
gatewayserver/kong:              order: 140
commsserver/mailserver:          order: 200
commsserver/postfixadmin:        order: 210
commsserver/roundcube:           order: 220
aiserver/ollama:                 order: 900  # Opcional — al final
aiserver/open-webui:             order: 910
```

### Mecanismo 2 — `depends_on`: restricción absoluta

El campo `depends_on` en `requirements` declara qué fichas deben estar en estado `INSTALADA — OK` antes de que esta ficha pueda comenzar. **Este mecanismo tiene prioridad total sobre `execution_order`.** No importa qué número tenga — si una dependencia no está satisfecha, la ficha no arranca.

```yaml
requirements:
  depends_on:
    - type: "ficha"
      target: "sbos-bootstrap"
      state: "installed"
    - type: "ficha"
      target: "vault"
      state: "installed"
```

### Cómo trabajan juntos

El `DEPENDENCY_RESOLVER` construye un grafo dirigido acíclico (DAG) con todas las fichas:

```
PASO 1 — Lee todos los manifest.yml del catálogo
PASO 2 — Construye el grafo: cada depends_on es un arco dirigido
PASO 3 — Calcula el orden topológico del grafo (algoritmo Kahn)
PASO 4 — Dentro de fichas sin dependencia entre sí, usa execution_order
          para determinar cuál va primero
PASO 5 — Entrega al IAM Installer la lista ordenada de fichas a instalar
```

Resultado visual del grafo simplificado:

```
sbos-bootstrap (0)
  │
  ├──▶ postgresql (100) ──▶ vault (120) ──▶ keycloak (130) ──▶ kong (140)
  │                                                               │
  │                                                               ▼
  ├──▶ redis (110) ─────────────────────────────────────▶ roundcube (220)
  │                                                       postfixadmin (210)
  │                                                       cypht (230)
  │
  └──▶ [fichas sin depends_on explícito se ordenan solo por execution_order]
```

### El caso especial del hostserver

Las fichas del hostserver son el único caso donde `depends_on` no existe. La razón es simple: cuando `sbos-bootstrap` corre, Kubernetes no existe todavía — no hay cluster que verifique dependencias. El orden del hostserver se determina **exclusivamente** por `execution_order` y es una secuencia rígida que el IAM Installer respeta sin excepción:

```
0 → sbos-bootstrap        (construye Ubuntu + K8s desde cero)
1 → sbos-k8s-upgrader     (solo activo si hay upgrade pendiente)
2 → sbos-cert-rotation    (verifica y rota certificados)
3 → sbos-compliance-check (verifica CIS Benchmark)
4 → sbos-node-hardening   (solo activo al agregar un nodo nuevo)
```

`sbos-bootstrap` con `execution_order: 0` es el único número reservado en todo el sistema. El IAM Installer lo trata como una constante — nunca puede haber una ficha con orden 0 que no sea `sbos-bootstrap`.

### Resumen: cuándo usar cada mecanismo

| Situación | Mecanismo correcto |
|---|---|
| Ficha del hostserver (workload.type: bash) | Solo `execution_order` |
| Ficha que requiere que otra esté instalada primero | `depends_on` (obligatorio) |
| Dos fichas sin relación entre sí | `execution_order` define cuál va antes |
| Ficha opcional (`criticality: false`) | `execution_order` alto (800+) — al final |

---

## 8. Estructura Física

```
servers/<servidor_logico>/<nombre_app>/     ← LA FICHA (raíz)
  │
  ├── manifest.yml                          ← Contrato de identidad y gobernanza
  ├── yaml_engine.yml                       ← Fases declarativas del ciclo de vida
  ├── task_catalog.sh                       ← Funciones Bash ESPECÍFICAS de esta app
  │
  ├── <app>.k8s.yml                         ← Manifest Kubernetes nativo (StatefulSet/Deployment)
  ├── <app>.network                         ← NetworkPolicy K8s — con quién puede hablar
  ├── <app>.volume                          ← Definición del PersistentVolumeClaim
  ├── <app>.container                       ← Referencia Quadlet/Podman (modo emergencia)
  │
  └── resources/                            ← Conocimiento operacional cristalizado
        ├── sql/                            ← Scripts SQL: schema, seed, migrations
        ├── config/                         ← Archivos de configuración probados en producción
        ├── keycloak/                       ← Client OIDC + realm roles + mappers
        ├── kong/                           ← Rutas + plugins + rate limiting
        ├── vault/                          ← Políticas de secretos
        ├── migrations/                     ← Scripts de migración entre versiones
        └── data/                           ← Datos iniciales de negocio (si aplica)
```

### Regla de oro sobre `resources/`

Los archivos en `resources/` no son ejemplos ni documentación. Son los **artefactos de integración exactos** que se aplican durante el `post_install`. Cada archivo representa conocimiento que costó tiempo y errores obtener en producción. Cuando el técnico que hizo la instalación original ya no está, `resources/` habla por él.

---

## 9. La Jerarquía de Conocimiento Operacional

El conocimiento en el sistema SBOS está distribuido en cuatro niveles. Esta jerarquía es lo que diferencia una ficha de un simple script:

```
NIVEL 1 — UNIVERSAL (Core del IAM Installer)
  00_TASK_CATALOG_SBOS.sh
  └─ wait_pod_ready()
  └─ create_k8s_namespace()
  └─ check_node_resources()
  └─ sbos_k8s_core()              ← ÚNICO punto de kubectl apply en todo el sistema
  └─ take_backup_snapshot()
  └─ rollout_restart()
  [Funciones que no mencionan ninguna app concreta]

NIVEL 2 — ESPECÍFICO (task_catalog.sh de cada ficha)
  postgresql/task_catalog.sh
  └─ _task_pg_create_k8s_secrets()
  └─ _task_pg_configure_databases()
  roundcube/task_catalog.sh
  └─ _task_configure_roundcube_ssl()
  └─ _task_configure_roundcube_redis()
  mailserver/task_catalog.sh
  └─ _task_generate_dkim_for_domain()
  └─ _task_fix_vmail_permissions()
  [Funciones que sí mencionan la app — NUNCA van al catálogo global]

NIVEL 3 — DECLARATIVO (yaml_engine.yml de cada ficha)
  [Qué tareas, en qué orden, con qué parámetros]
  [No contiene lógica — contiene intención]

NIVEL 4 — ESTADO (resources/ de cada ficha)
  [Artefactos de integración: SQL, configs, policies]
  [Conocimiento de producción cristalizado en archivos]
```

**La regla crítica:** si una función Bash menciona el nombre de una aplicación concreta (`postgresql`, `keycloak`, `roundcube`, `vault`) → va en el `task_catalog.sh` **individual** de esa ficha. Nunca en el catálogo global del Core. Violar esta regla acopla el Core a aplicaciones específicas y destruye la extensibilidad.

---

## 10. Estructura de Servidores Lógicos

Las fichas viven dentro de carpetas de **servidores lógicos**. Estos servidores son las unidades de escalamiento horizontal: cuando el cliente necesita más capacidad, se replica el nodo físico correspondiente y el servidor lógico crece.

```
servers/
  ├── hostserver/                   ← El nodo físico mismo
  │     └── sbos-bootstrap/         ← Ficha Tipo 1: prepara Ubuntu + K8s
  │
  ├── dataserver/                   ← Almacenamiento y datos
  │     ├── postgresql/             ← Motor SQL principal (PG 18)
  │     ├── redis/                  ← Caché y sesiones
  │     └── minio/                  ← Object storage S3-compatible
  │
  ├── identityserver/               ← Identidad y acceso
  │     └── keycloak/               ← SSO, OIDC, RBAC
  │
  ├── gatewayserver/                ← API Gateway y proxy
  │     ├── kong/
  │     └── oauth2-proxy/
  │
  ├── commsserver/                  ← Comunicaciones
  │     ├── mailserver/             ← SMTP/IMAP (Postfix + Dovecot)
  │     ├── postfixadmin/
  │     ├── roundcube/
  │     └── cypht/
  │
  ├── securityserver/               ← Seguridad y secretos
  │     ├── vault/
  │     └── wazuh/
  │
  └── ... (hasta 14 servidores lógicos)
```

---

## 11. El Contrato de Identidad: `manifest.yml`

```yaml
identity:
  id: "postgresql"
  name: "PostgreSQL 18"
  description: "Motor de base de datos relacional principal del SBOS"
  version: "18.2"
  server: "dataserver"
  namespace: "sbos-data"
  category: "database"
  icon: "🐘"
  criticality: true                 # false = ficha opcional pura

workload:
  type: "kubernetes"                # "kubernetes" | "bash"
  state: "prod"                     # "prod" | "beta" | "experimental"

order:
  # El orden de ejecución se determina por DOS mecanismos que trabajan juntos:
  #
  # 1. execution_order: número entero global. El DEPENDENCY_RESOLVER ordena
  #    todas las fichas de mayor a menor prioridad (menor número = antes).
  #    Solo se usa cuando NO hay depends_on — es el orden de preferencia
  #    si todas las dependencias estuvieran satisfechas simultáneamente.
  #
  # 2. depends_on (en requirements): define dependencias explícitas.
  #    El DEPENDENCY_RESOLVER NUNCA ejecuta esta ficha antes de que
  #    sus dependencias estén en estado "installed". Este mecanismo
  #    tiene prioridad absoluta sobre execution_order.
  #
  # Para fichas del hostserver (workload.type: bash):
  #    execution_order es el único mecanismo — no tienen depends_on
  #    porque corren antes de que K8s exista para verificarlos.
  execution_order: 100              # dataserver arranca después del hostserver (0-9)

parameters:
  PG_VERSION: "18"
  PG_MAX_CONNECTIONS: "500"
  PG_SHARED_BUFFERS: "256MB"

requirements:
  ram_mb: 1024
  cpu_cores: 1
  disk_gb: 500
  depends_on:
    - type: "ficha"
      target: "sbos-bootstrap"
      state: "installed"
    - type: "ficha"
      target: "vault"
      state: "installed"

deployment:
  namespace: "sbos-data"
  node_selector: "tipo=dataserver"
  k8s_manifest: "postgresql.k8s.yml"
  workload_type: "StatefulSet"
  network_policy: "postgresql.network"
  volume: "postgresql.volume"

governance:
  category: 3                       # 1=libre · 2=confirmación · 3=dual-control
  data_owner: "cliente"
  backup_required: true
  backup_schedule: "0 2 * * *"

health:
  check_command: "pg_isready -U postgres"
  check_via: "kubectl_exec"
  pod_selector: "app=postgresql"
  interval_seconds: 30
  failure_threshold: 3

integrations:
  provides_to:
    - "postfixadmin"
    - "roundcube"
    - "cypht"
    - "keycloak"
  oauth2_ready: false

bsearch_config:
  enabled: false                    # PostgreSQL no expone entidades de negocio propias
  # Las entidades de negocio de cada base de datos se configuran en las
  # fichas que las poseen (postfixadmin, roundcube, etc.), no en postgresql.
  # Ver ejemplo funcional en fichas de aplicación de negocio.
```

> **Nota sobre `bsearch_config`:** el bloque `bsearch_config` es nuevo en v4.0. Es requerido por bSearch (SBOS-013) para saber qué entidades indexar de cada aplicación. Ver la especificación completa del bloque y un ejemplo funcional a continuación.

### Especificación del bloque `bsearch_config`

El bloque `bsearch_config` le indica al daemon bSearch qué entidades de la aplicación son indexables para búsqueda global. Este bloque es parte del contrato de identidad y debe estar presente en **toda ficha de aplicación** (Tipo 2) que exponga entidades de negocio buscables.

```yaml
bsearch_config:
  enabled: true                     # true | false
  priority: high                    # high | medium | low
                                    # Determina la frecuencia de re-indexación:
                                    # high = cada 5 min · medium = cada 30 min · low = cada 2h
  schema_discoverer: auto           # auto | manual
                                    # auto: bSearch lee el schema de PostgreSQL directamente
                                    # manual: el diseñador de la ficha define las entidades explícitamente

  index_entities:
    - entity: invoice
      table: account_invoice
      primary_field: number
      display_fields: [number, party, amount_total]
      search_fields: [number, party, description]   # Campos indexados para búsqueda full-text
      url_template: "/accounting/invoice/{id}"       # URL para abrir el registro desde los resultados
      permission_check: "ficha"                      # ficha | open
                                                     # ficha: solo usuarios con acceso a esta ficha
                                                     # open: cualquier usuario autenticado

    - entity: partner
      table: res_partner
      primary_field: name
      display_fields: [name, email, phone, vat]
      search_fields: [name, email, vat, ref]
      url_template: "/contacts/partner/{id}"
      permission_check: "ficha"
```

### Ejemplo funcional completo — Ficha de facturación

```yaml
# manifest.yml de una ficha de aplicación de negocio con bsearch_config completo
identity:
  id: "accounting"
  name: "Contabilidad"
  version: "1.0"
  criticality: true

bsearch_config:
  enabled: true
  priority: high
  schema_discoverer: auto
  index_entities:
    - entity: invoice
      table: account_invoice
      primary_field: number
      display_fields: [number, party, amount_total]
      search_fields: [number, party, description]
      url_template: "/accounting/invoice/{id}"
      permission_check: "ficha"

    - entity: journal_entry
      table: account_move
      primary_field: name
      display_fields: [name, date, amount_total, state]
      search_fields: [name, ref, narration]
      url_template: "/accounting/entry/{id}"
      permission_check: "ficha"
```

### Niveles de Governance

| Categoría | Nombre | Requiere | Ejemplo de operación |
|---|---|---|---|
| 1 | Libre | Solo autenticación | Ver logs, verificar health |
| 2 | Confirmación | Escribir texto de confirmación | Reparar, reiniciar |
| 3 | Dual-Control | Dos administradores autorizados | Desinstalar, restaurar backup, borrar datos |

---

## 12. El Contrato Temporal: `yaml_engine.yml`

Las fases declarativas definen la intención de cada momento del ciclo de vida. **No contienen lógica Bash**. Las tareas cuyo nombre existe en `00_ARCHITECTURE_SBOS.yml` son **globales** (del Core). Las demás se buscan en el `task_catalog.sh` individual de la ficha.

```yaml
phases:

  pre_install:
    tasks:
      - task: "check_node_resources"            # GLOBAL
        params:
          ram_mb_required: 1024
          disk_gb_required: 500

      - task: "create_k8s_namespace"            # GLOBAL
        params:
          namespace: "sbos-data"

      - task: "pg_create_k8s_secrets"           # ESPECÍFICA — en task_catalog.sh
        params:
          namespace: "sbos-data"
          secret_path: "secret/sbos/postgresql"

  post_install:
    tasks:
      - task: "wait_pod_ready"                  # GLOBAL
        params:
          namespace: "sbos-data"
          pod_selector: "app=postgresql"
          timeout_seconds: 120

      - task: "pg_configure_databases"          # ESPECÍFICA
        params:
          databases:
            - name: "postfixadmin_db"
              owner_secret: "secret/sbos/postfixadmin/db"
            - name: "roundcube_db"
              owner_secret: "secret/sbos/roundcube/db"
            - name: "keycloak_db"
              owner_secret: "secret/sbos/keycloak/db"

  update:
    tasks:
      - task: "reconcile_file"                  # GLOBAL
        update_strategy: "hot"
        drift_check: true
        params:
          source: "resources/config/postgresql.conf"

  repair:
    diagnosis_first: true                       # SIEMPRE diagnosticar antes de actuar
    tasks:
      - task: "pg_diagnose_connections"         # ESPECÍFICA
        on_failure: "continue"

      - task: "rollout_restart"                 # GLOBAL
        params:
          namespace: "sbos-data"
          resource: "StatefulSet/postgresql"
        on_failure: "abort"

      - task: "wait_pod_ready"                  # GLOBAL
        params:
          namespace: "sbos-data"
          pod_selector: "app=postgresql"

  uninstall:
    require_confirmation: "DESINSTALAR-POSTGRESQL"
    governance_category: 3
    tasks:
      - task: "take_backup_snapshot"            # GLOBAL
        params:
          backup_name: "pre-uninstall-postgresql"
          storage: "minio"

      - task: "pg_drop_application_databases"   # ESPECÍFICA
        params:
          skip_system_dbs: true
```

### La regla `diagnosis_first: true`

Esta bandera en la fase `repair` es obligatoria para fichas con `criticality: true`. Garantiza que el sistema **nunca intenta reparar antes de entender qué está roto**. Las tareas de diagnóstico usan `on_failure: "continue"` — un diagnóstico fallido no aborta. Las acciones correctivas usan `on_failure: "abort"` — una reparación fallida sí detiene todo.

---

## 13. El Catálogo de Tareas: `task_catalog.sh`

Cada ficha tiene su propio archivo de funciones Bash **específicas** de esa aplicación. El Core las carga en memoria antes de ejecutar la ficha y las libera al terminar — esto previene colisiones de nombres entre fichas.

```bash
#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# task_catalog.sh — Catálogo de tareas específicas de PostgreSQL
#
# POSICIÓN EN LA ARQUITECTURA:
#   00_YAML_ENGINE_SBOS.sh carga este archivo antes de ejecutar
#   cualquier fase de la ficha postgresql. Las funciones aquí
#   definidas son invisibles para otras fichas y para el Core global.
#
# REGLA DE ORO:
#   Si la función menciona "postgresql", "pg", o cualquier nombre
#   concreto de esta app → pertenece AQUÍ, nunca en
#   00_TASK_CATALOG_SBOS.sh
#
# VERSIÓN: 1.0 · Marzo 2026
# ══════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────
# _task_pg_create_k8s_secrets()
#
# PROPÓSITO:
#   Genera un password aleatorio y lo almacena en Vault y como
#   K8s Secret. Garantiza que PostgreSQL nunca arranque con
#   credenciales por defecto.
#
# LO LLAMAN:
#   - 00_YAML_ENGINE_SBOS.sh durante la fase pre_install
#
# PARÁMETROS:
#   $1 params (JSON/YAML str) — namespace y secret_path
#
# RETORNA:
#   0 — secret creado o ya existía (idempotente)
#   1 — error de Vault o kubectl
#
# IDEMPOTENCIA:
#   Verifica existencia del K8s Secret antes de crear.
#   Si existe, emite SKIP.
# ─────────────────────────────────────────────────────────────────────
_task_pg_create_k8s_secrets() {
    local params="$1"
    local namespace
    local secret_path

    namespace=$(echo "$params" | yq eval '.namespace' -)
    secret_path=$(echo "$params" | yq eval '.secret_path' -)

    echo "__SBOS__STEP_START__ Creando secrets de PostgreSQL en: $namespace"

    # Idempotencia
    if kubectl get secret pg-master-credentials -n "$namespace" &>/dev/null; then
        echo "__SBOS__STEP_SKIP__ Secret pg-master-credentials ya existe"
        return 0
    fi

    local password
    password=$(openssl rand -base64 32)

    # Vault primero — fuente de verdad
    if ! vault kv put "${secret_path}/master" password="$password" username="postgres"; then
        echo "__SBOS__STEP_ERROR__ CAUSA: Vault no disponible SOLUCIÓN: sbos verify vault"
        return 1
    fi

    # K8s Secret referenciando Vault
    kubectl create secret generic pg-master-credentials \
        --from-literal=password="$password" \
        --from-literal=username="postgres" \
        -n "$namespace" --dry-run=client -o yaml | kubectl apply -f -

    echo "__SBOS__STEP_OK__ Secrets de PostgreSQL creados correctamente"
    return 0
}
export -f _task_pg_create_k8s_secrets
```

### Validación obligatoria antes de entrega

Toda ficha debe pasar `validate_sp02.py` con exit 0 antes de ser entregada al pipeline de release. Este validador verifica que el `task_catalog.sh` cumple los estándares de calidad definidos en SBOS-018:

- Todas las funciones tienen el bloque SBOS-DOC completo (PROPÓSITO, LO LLAMAN, PARÁMETROS, RETORNA, IDEMPOTENCIA)
- Todas las funciones terminan con `export -f` (Principio P6)
- Ninguna función usa el nombre de otra aplicación distinta a la propia
- Todas las funciones emiten señales `__SBOS__STEP_*` apropiadas
- No hay llamadas directas a `kubectl apply` (Principio P1)

El validador no es una herramienta de uso manual — es un paso obligatorio del `make release` (SBOS-005 §13). Una ficha que no pasa `validate_sp02.py` no puede ser publicada.

---

## 14. Los Resources: Conocimiento de Producción Cristalizado

El directorio `resources/` no contiene archivos de ejemplo. Contiene el **estado exacto y probado en producción** de todos los artefactos de integración que la aplicación necesita.

### Qué va en cada subdirectorio

**`resources/sql/`** — Scripts SQL idempotentes: `schema.sql` con `CREATE TABLE IF NOT EXISTS`, `seed.sql` con datos iniciales de configuración, `migrations/vX.Y.Z.sql` para migraciones entre versiones.

**`resources/config/`** — Archivos de configuración con valores probados en producción. Incluyen comentarios SBOS-DOC que explican por qué cada parámetro tiene ese valor y qué ocurre si se cambia incorrectamente.

**`resources/keycloak/`** — Definición del Client OIDC: scopes, redirect URIs, mappers de claims, roles del realm. Se importan automáticamente en el `post_install`. El administrador nunca configura manualmente la integración SSO.

**`resources/kong/`** — Definición de rutas y plugins: upstream, service, route, rate-limiting, authentication plugin. La app queda expuesta correctamente en el API Gateway sin intervención manual.

**`resources/vault/`** — Políticas de secretos: qué paths puede leer y escribir esta app en Vault, con el principio de mínimo privilegio aplicado.

### El principio del conocimiento preservado

Cada problema que costó tiempo resolver en producción debe cristalizarse en `resources/` para que nunca se pierda:

| Conocimiento doloroso | Cómo se preserva |
|---|---|
| Redis en Roundcube requiere formato exacto `'host:port:db:pass'` en array PHP | `resources/config/config.inc.php` con comentario que explica el formato y por qué el alternativo falla silenciosamente |
| Dovecot necesita UID 5000:5000 y cola Postfix UID 105:107 | Documentado en `_task_fix_vmail_permissions()` con bloque SBOS-DOC completo |
| Los certificados SSL deben existir ANTES del primer arranque del mailserver | Orden explícito en `yaml_engine.yml` — `generate_ssl_certs` siempre antes de `sbos_k8s_core()` |
| DKIM debe generarse por dominio, no globalmente | `manifest.yml` campo `domains[]` + loop en `task_catalog.sh` |
| PostfixAdmin expone solo en `127.0.0.1` — acceso público vía OAuth2-Proxy | `manifest.yml` campo `oauth2_ready: true` + comentario en `<app>.k8s.yml` |
| PostgreSQL 18 crea las BDs de otras apps en su `post_install` | Scripts en `resources/sql/seed-<app>-database.sql` por cada app dependiente |
| Cypht se construye desde `php:8.3-apache` — no es imagen pre-built | `resources/scripts/build-cypht.sh` documentado con cada paso justificado |

---

## 15. El Loop de Reconciliación

Las fichas no son de ejecución única. El `RECONCILE_SCHEDULER` del Core verifica periódicamente que el estado actual del cluster coincide con el estado declarado en la ficha.

```
RECONCILE_SCHEDULER (loop — intervalo configurable por ficha)
  │
  ▼
Para cada ficha INSTALADA_OK o INSTALADA_ALERTA:
  │
  ├── HEALTH_CHECKER.check(ficha)
  │     └── kubectl exec → health.check_command del manifest.yml
  │
  ├── PLUGIN_LOADER.compute_hashes(ficha.resources/)
  │     └── SHA-256 de cada archivo en resources/
  │
  ├── Comparar con hashes en .sbos_state.json
  │
  ├── ¿Diferencias de hash?
  │     ├── SÍ → ACTUALIZACIÓN_DISPONIBLE + notifica al Core UI
  │     └── NO → no-op
  │
  └── ¿Health degraded o error?
        ├── SÍ → INSTALADA_ALERTA
        │         Intenta repair si auto_repair: true en manifest
        └── NO → sin acción
```

La diferencia clave con los Kubernetes Operators clásicos es que en SBOS **el administrador tiene control total**. El sistema detecta y reporta el drift — no lo corrige automáticamente sin confirmación humana. Esto es intencional para entornos empresariales donde la gobernanza requiere trazabilidad de cada cambio.

---

## 16. Gobernanza y Control Dual

Las fichas con `governance.category: 3` requieren que **dos administradores autorizados** aprueben cualquier operación destructiva. Esta semántica está codificada en el `yaml_engine.yml` — no es solo una restricción de interfaz:

```yaml
uninstall:
  require_confirmation: "DESINSTALAR-POSTGRESQL"
  governance_category: 3
  dual_control:
    required: true
    timeout_minutes: 60             # La segunda aprobación expira en 60 minutos
    audit_log: true                 # Registrado en Vault audit log
```

Esta característica no existe en Helm ni en los Kubernetes Operators estándar. Es una contribución original del stack empresarial soberano: donde la trazabilidad y el control son requisitos legales y operacionales, no opcionales.

---

## 17. Versionado y Migración de Fichas

> **Esta sección es nueva en v4.0.** Establece el modelo de versionado semántico para fichas y el proceso de migración entre versiones en producción.

### 17.1 El Problema que el Versionado Resuelve

Una ficha que lleva 18 meses en producción ha acumulado conocimiento: el `task_catalog.sh` tiene funciones refinadas, el `yaml_engine.yml` tiene correcciones de casos borde, los `resources/` tienen configuraciones optimizadas. Cuando llega el momento de actualizar la ficha, el sistema necesita saber qué tipo de cambio es: ¿puedo aplicarlo en caliente? ¿Necesita una migración? ¿Es incompatible con el estado actual del cluster?

El mismo problema que Helm Charts y los Kubernetes Operators resolvieron para sus ecosistemas — con semver como vocabulario estándar — existe para las fichas SBOS.

### 17.2 Esquema de Versión Semántica

Las fichas usan **versión semántica MAJOR.MINOR.PATCH** con la siguiente semántica específica para el contexto del sistema de fichas:

| Componente | Cuándo incrementa | Ejemplo |
|---|---|---|
| **PATCH** | Correcciones que no cambian el comportamiento observable: fix de idempotencia, mejora de mensaje de error, ajuste de timeout, comentarios SBOS-DOC | `1.2.3` → `1.2.4` |
| **MINOR** | Cambios backwards-compatible: nueva tarea en `yaml_engine.yml`, nuevo campo opcional en `manifest.yml`, nueva entidad en `bsearch_config`, nuevo archivo en `resources/` | `1.2.3` → `1.3.0` |
| **MAJOR** | **Breaking changes**: modificación del schema de `manifest.yml` que invalida fichas existentes, cambio en el nombre de una tarea referenciada externamente, migración de datos destructiva, cambio en `execution_order` que altera el DAG de dependencias del cluster | `1.2.3` → `2.0.0` |

### 17.3 Qué Constituye un Breaking Change (MAJOR)

Un cambio es MAJOR si cualquiera de las siguientes condiciones se cumple:

| Condición | Razón |
|---|---|
| Se elimina un campo de `manifest.yml` que otras fichas referencian en `depends_on` | Rompe el grafo de dependencias del DEPENDENCY_RESOLVER |
| Se renombra el `identity.id` de la ficha | Todas las fichas que la tienen en `depends_on.target` quedan rotas |
| Se cambia `workload.type` de `kubernetes` a `bash` o viceversa | El IAM Installer usa rutas de ejecución distintas para cada tipo |
| Una migración SQL en `resources/sql/migrations/` no es reversible | El rollback de la ficha no es posible sin pérdida de datos |
| Se cambia la semántica de un campo de `governance.category` | Las aprobaciones en vuelo pueden quedar en estado inválido |

### 17.4 Proceso de Migración entre Versiones en Producción

```
Ficha en producción: postgresql v1.4.2
Nueva versión disponible: postgresql v2.0.0 (MAJOR)
  │
  ▼
RELEASE_MANAGER descarga v2.0.0 y la marca como ACTUALIZACION_DISPONIBLE
  │
  ▼
Core UI muestra alerta: "Actualización MAJOR disponible — requiere revisión"
  │
  ▼
Administrador selecciona: [Ver diff] → Core UI muestra:
  ├── Cambios en manifest.yml (campos añadidos, modificados, eliminados)
  ├── Nuevas tareas en yaml_engine.yml
  └── Migraciones SQL en resources/sql/migrations/v2.0.0.sql
  │
  ▼
Administrador selecciona: [Aplicar actualización MAJOR]
  │
  ▼
IAM Installer ejecuta secuencia de migración MAJOR:
  ├── take_backup_snapshot (obligatorio para MAJOR — no configurable)
  ├── Ejecuta resources/sql/migrations/v2.0.0.sql
  ├── Aplica nuevo k8s manifest si hay cambios
  ├── Ejecuta post_update tasks del yaml_engine.yml
  └── health_check → si pasa → set_INSTALADA_OK con v2.0.0
                   → si falla → rollback: restaura backup + versión anterior
```

### 17.5 Compatibilidad con Versiones Anteriores

El IAM Installer puede ejecutar una ficha de versión MAJOR anterior a la actual del catálogo si el administrador lo requiere explícitamente. Esto es útil para clientes que necesitan estabilizar antes de migrar.

**Regla:** la compatibilidad hacia atrás solo se garantiza para N-1 versiones MAJOR. Una ficha de versión MAJOR N-2 o anterior puede no ser compatible con la versión actual del Core y emitirá una advertencia al ser cargada por FICHA_LINTER.

```yaml
# En manifest.yml — campo opcional para declarar compatibilidad mínima
compatibility:
  min_iam_installer_version: "4.0.0"   # No funciona con IAM Installer < 4.0
  min_ficha_api_version: "2"           # Requiere Ficha API v2 del Core
```

### 17.6 Fichas Bloqueadas por Versión

Si una ficha MAJOR actualizada rompe la compatibilidad con una ficha que la tiene como dependencia, el DEPENDENCY_RESOLVER detecta el conflicto y bloquea la actualización:

```
DEPENDENCY_RESOLVER detecta conflicto:
  postgresql v2.0.0 requiere: keycloak v3.0+
  keycloak instalada: v2.8.1

Core UI muestra:
  ⚠ No se puede actualizar postgresql a v2.0.0
  Razón: keycloak v2.8.1 no cumple la dependencia postgresql v2.0.0 → keycloak v3.0+
  Acción sugerida: [Actualizar keycloak primero] [Ver plan de migración completo]
```

---

## 18. Extensibilidad: La Propiedad Más Importante

En el instalador anterior, agregar una nueva aplicación significaba modificar tres archivos globales. Con 30 aplicaciones esos archivos tenían cientos de líneas. El sistema crecía acoplado.

Con fichas SBOS:

1. Crear carpeta: `servers/<servidor>/nueva-app/`
2. Escribir los contratos: `manifest.yml`, `yaml_engine.yml`, `task_catalog.sh`, `<app>.k8s.yml`, `resources/`
3. El IAM Installer la descubre automáticamente al escanear `servers/`
4. Aparece en el Core UI como disponible
5. El `DEPENDENCY_RESOLVER` integra la nueva ficha en el grafo automáticamente

**El Core no cambia. El sistema no cambia. Solo existe una carpeta nueva.**

Esta propiedad — que los patrones de Platform Engineering llaman *self-service extensibility* y que el Operator Pattern llama *extensión sin modificar el núcleo* — es lo que diferencia un instalador de un **sistema operativo empresarial soberano**.

---

## 19. Registro de Cambios

### v4.0 — Marzo 2026 (este documento)

**Secciones nuevas:**

**§11 — Campo `bsearch_config` en manifest.yml:** especificación completa del bloque `bsearch_config` que el daemon bSearch (SBOS-013) requiere para indexar entidades de cada aplicación. Campos: `enabled`, `priority` (high/medium/low), `schema_discoverer` (auto/manual), `index_entities` con `entity`, `table`, `primary_field`, `display_fields`, `search_fields`, `url_template`, `permission_check`. Ejemplo funcional completo para una ficha de facturación.

**§13 — Validación obligatoria con validate_sp02.py:** referencia explícita al validador automático de SBOS-018. Toda ficha debe pasar `validate_sp02.py` con exit 0 antes de ser entregada al pipeline. Lista de verificaciones del validador. Referencia a SBOS-005 §13 donde el validador es paso obligatorio del `make release`.

**§17 — Versionado y Migración de Fichas:** sección completamente nueva. Esquema semántico MAJOR.MINOR.PATCH adaptado al contexto de fichas. Definición precisa de qué constituye un breaking change. Proceso de migración MAJOR en producción con backup obligatorio, diff visual, y rollback automático. Compatibilidad con versiones anteriores (N-1 MAJOR). Detección de conflictos de dependencia por versión en DEPENDENCY_RESOLVER. Inspirado en el modelo de versionado de Helm Charts y Kubernetes Operators, adaptado a la semántica de estados y governance del sistema de fichas.

**Modificaciones en v4.0:**

- §11 manifest.yml: bloque `bsearch_config` añadido. Campo `compatibility.min_iam_installer_version` documentado.
- §17 es nueva — la sección de Extensibilidad pasa de §17 a §18.

### v3.0 — Marzo 2026

**Secciones nuevas en v3.0:** §1 Fundamento Conceptual con las tres generaciones de instaladores y la genealogía del diseño en el ecosistema cloud-native — §2 Posición en el Ecosistema con tabla comparativa Helm / Operator / CNAB / Ansible / Golden Path — §4 Los Tres Contratos como marco conceptual unificador — §8 Jerarquía de Conocimiento Operacional con los cuatro niveles y la regla crítica de qué va en el Core vs en la ficha — §13 Resources expandido con el principio del conocimiento preservado y tabla de ejemplos de producción real — §14 Loop de Reconciliación con diagrama completo — §15 Gobernanza y Control Dual con el YAML de dual_control.

**Modificaciones a secciones existentes en v3.0:** Los Tres Tipos expandidos con la justificación de que reflejan el momento del ciclo de vida del sistema, no categorías arbitrarias. Los Cinco Estados añaden notas sobre el comportamiento de `BLOQUEADA` y la detección de drift en `ACTUALIZACIÓN DISPONIBLE`. El `manifest.yml` añade campos `integrations.provides_to`, `integrations.oauth2_ready`, `governance.backup_schedule`. El `yaml_engine.yml` añade la explicación de `diagnosis_first` con la lógica de `on_failure`. El `task_catalog.sh` incluye el bloque SBOS-DOC completo.

---

*SKULL · SBOS · SBOS-006-FICHA · v4.0 · Marzo 2026*

> **Referencias:** Kubernetes Operator Pattern — CoreOS / Red Hat (2016) · CNCF Operator Whitepaper (2021) · Cloud Native Application Bundles / CNAB Specification — Microsoft, Docker, HashiCorp (2018) · Porter CNAB implementation — Microsoft · Platform Engineering Golden Paths — Spotify, Netflix · Google Cloud Platform Engineering reference · CNCF TAG App Delivery · Helm Chart versioning and migration — Helm Project · Kubernetes Operator versioning — OperatorHub · Semantic Versioning 2.0.0 — semver.org
