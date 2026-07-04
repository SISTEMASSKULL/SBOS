# SBOS-005-INSTALLER
## Especificación Técnica: SBOS IAM Installer — Infrastructure Provisioning & Lifecycle Orchestrator

### SKULL · SBOS — Sovereign Business Operating System
### v7.0 · Marzo 2026 — Integración de especificación interna

---

| Campo | Valor |
|-------|-------|
| **Nombre original** | IAM Installer |
| **Nombre conceptual** | SBOS IAM Installer: Infrastructure Provisioning & Lifecycle Orchestrator |
| **Daemon** | `bos` |
| **Servicio systemd** | `bos.service` |
| **Lenguaje** | Go (binario soberano — Bash=0 autónomo) |
| **Unidad declarativa** | Ficha |
| **Directorio** | `/etc/bos/blibs/servers/<nombre_ficha>/` |
| **Archivos en la unidad** | `manifest.yml`, `task_catalog.sh`, `yaml_engine.yml`, `resources/` |

> **Decisión de arquitectura (v6.0):** El `task_catalog.sh` de cada ficha es y permanecerá **Bash (.sh)**. No migrará a binario compilado.
> **Fundamento operativo:** Las fichas generan errores de configuración en producción que requieren agregar, eliminar o modificar tareas **en el acto**. Un binario compilado (.so) exigiría recompilar, redistribuir y re-registrar para cada corrección — un proceso lento e incompatible con las necesidades operativas de reparación inmediata. Bash permite editar, guardar y que el instalador absorba los cambios en el siguiente ciclo sin downtime.
> **El daemon principal (`bos`)** sí es binario Go compilado — es él quien consume, ejecuta y desacopla los task_catalog.sh de las fichas. La frontera es clara: **binario soberano consume scripts declarativos de fichas**.

---

## Tabla de Contenidos

1. [Definición Ejecutiva — ¿Qué es el SBOS IAM Installer?](#1-definición-ejecutiva--qué-es-el-sbos-iam-installer)
2. [Propósito y Posición en el Ecosistema](#2-propósito-y-posición-en-el-ecosistema)
3. [Qué es el IAM Installer — Especificación Técnica](#3-qué-es-el-iam-installer--especificación-técnica)
4. [La Arquitectura de Tres Planos](#4-la-arquitectura-de-tres-planos)
5. [Capas de Responsabilidad de los Módulos Python](#5-capas-de-responsabilidad-de-los-módulos-python)
6. [Los 4 Archivos Maestros Bash](#6-los-4-archivos-maestros-bash)
7. [Los 16 Módulos Python con Asignación a Capa](#7-los-16-módulos-python-con-asignación-a-capa)
8. [Protocolo de Señales](#8-protocolo-de-señales)
9. [El SKULL Release Plane — Distribución Soberana](#9-el-skull-release-plane--distribución-soberana)
10. [Seguridad del Canal de Distribución (Ed25519)](#10-seguridad-del-canal-de-distribución-ed25519)
11. [Estrategia de Rollout Canary/Early/Stable con Criterios de Halt](#11-estrategia-de-rollout-canaryearlystable-con-criterios-de-halt)
12. [Rollback Automático del Daemon](#12-rollback-automático-del-daemon)
13. [Modo Degradado — Operación Offline](#13-modo-degradado--operación-offline)
14. [Pipeline CI/CD con Validador como Paso Obligatorio](#14-pipeline-cicd-con-validador-como-paso-obligatorio)
15. [El IAM Installer como Daemon Residente](#15-el-iam-installer-como-daemon-residente)
16. [El Ciclo de Vida Completo](#16-el-ciclo-de-vida-completo)
    - [16.1 Primera instalación](#161-primera-instalación-desde-ubuntu-virgen)
    - [16.2 Operación normal](#162-operación-normal-sistema-ya-instalado)
17. [El Ciclo Absorber → Ejecutar → Liberar](#17-el-ciclo-absorber--ejecutar--liberar)
18. [Las 4 Acciones sobre una Ficha](#18-las-4-acciones-sobre-una-ficha)
19. [El Loop de Reconciliación Continua](#19-el-loop-de-reconciliación-continua)
20. [Observación Integral de Salud — SO → Kubernetes → Fichas](#20-observación-integral-de-salud--so--kubernetes--fichas)
21. [Operaciones Destructivas y Governance Dual-Control](#21-operaciones-destructivas-y-governance-dual-control)
22. [La Frontera Binario ↔ Script: Por qué task_catalog.sh es Bash](#22-la-frontera-binario--script-por-qué-task_catalogsh-es-bash)
23. [Posicionamiento frente al Ecosistema de la Industria](#23-posicionamiento-frente-al-ecosistema-de-la-industria)
24. [Los 15 Principios de Arquitectura](#24-los-15-principios-de-arquitectura)
25. [Relación con el Ecosistema de Patrones](#25-relación-con-el-ecosistema-de-patrones)
26. [Registro de Cambios](#26-registro-de-cambios)

---

## 1. Definición Ejecutiva — ¿Qué es el SBOS IAM Installer?

> **Esta sección es nueva en v6.0.** Proporciona una definición de alto nivel orientada a stakeholders, directores de IT y como contexto estratégico para un agente de IA que desarrolle la aplicación. Las secciones técnicas detalladas para implementación siguen a partir de §2.

### ¿Qué es?

Es el **motor de aprovisionamiento y gestión del ciclo de vida de la infraestructura soberana**. Su función es transformar un servidor virgen (Ubuntu) en un entorno de alta disponibilidad mediante el despliegue inmutable de Kubernetes y el stack de aplicaciones SBOS. Actúa como el orquestador de base que garantiza la integridad del sistema **desde el nivel de kernel hasta la capa de aplicación**.

Este proceso fundacional es **crítico y primordial**: si el IAM Installer no ejecuta el bootstrap, Kubernetes no existe, las fichas no se levantan, y el SBOS no cobra vida. No hay sistema operativo de negocios sin este primer acto de aprovisionamiento.

Pero el IAM Installer no se detiene después de la instalación inicial. Se convierte en un **daemon residente permanente** que observa, administra y repara la salud del sistema en tres niveles: sistema operativo, Kubernetes y aplicaciones (fichas). La lógica es directa: si el sistema operativo no está saludable, Kubernetes no puede operar; si Kubernetes falla, las fichas no pueden existir. Por lo tanto, el IAM Installer es observador, administrador y reparador de toda la cadena — desde la instalación del sistema operativo, a través de las aplicaciones, hasta su constante revisión y control de salud.

Implementa el principio que la industria ha convergido como solución para sistemas distribuidos: el **control plane con reconciliación continua** — un loop permanente que compara el estado deseado contra el estado actual y actúa para cerrar la brecha. Este es el mismo principio detrás de Kubernetes mismo, de ArgoCD, de los Kubernetes Operators, y de plataformas de orquestación de infraestructura como Terraform y Crossplane. La diferencia crítica es la **soberanía**: no requiere conectividad a registros externos, no depende de servicios cloud, y los datos de cada cliente nunca abandonan su infraestructura.

Adicionalmente, no gestiona una sola instalación — **gestiona una flota de instalaciones** a través del SKULL Release Plane, manteniendo la cadena de confianza criptográfica (Ed25519 + SHA-256) desde el laboratorio de desarrollo hasta cada servidor de producción de cada cliente.

### Lo que puede hacer

**Aprovisionamiento Inmutable y Atómico:** Ejecuta despliegues por pasos sucesivos donde cada etapa debe validarse antes de continuar. Si una fase falla, el sistema ejecuta transacciones compensatorias (patrón Saga) que garantizan un estado consistente — nunca quedan instalaciones corruptas o incompletas. Este es el enfoque estándar de la industria para orquestación de infraestructura compleja, donde el aprovisionamiento debe ser declarativo, versionado y reproducible.

**Gestión del Ciclo de Vida (Lifecycle Management):** Una vez instalado, no permanece inactivo; gestiona de forma integral la salud de las aplicaciones (instala, actualiza, repara y desinstala) asegurando que el entorno operativo se mantenga siempre en el estado deseado. La industria denomina esto **Day 2 Operations** — donde el verdadero valor de un orquestador se mide en la robustez de sus operaciones post-instalación.

**Monitoreo y Auto-curación (Self-Healing):** Observa activamente los procesos y servicios del stack completo — sistema operativo, Kubernetes y fichas. Ante una caída o fallo de un proceso, el orquestador actúa automáticamente para restaurar el servicio, garantizando la continuidad del negocio sin intervención humana. Como daemon systemd que vive **por encima de Kubernetes** (no dentro de él), puede diagnosticar, reparar o reconstruir Kubernetes desde cero si éste falla.

**Verificación de Integridad Soberana:** Antes de "plantar" cualquier componente, el IAM Installer verifica las firmas y la integridad de los paquetes para asegurar que el software no ha sido alterado por fuentes externas, manteniendo la **cadena de custodia del software**. Esta verificación no es un evento puntual de instalación — es constante en cada revisión, cada actualización y cada control de salud, alineada con el framework SLSA (Supply-chain Levels for Software Artifacts).

**Rollback y Recuperación de Estado:** En procesos de actualización, mantiene la capacidad de revertir el sistema a una versión anterior estable en caso de anomalías, asegurando que el sistema operativo y las aplicaciones mantengan su operatividad. El periodo de estabilización de 60 segundos con 5 criterios de verificación y rollback automático sigue el patrón watchdog + versión en custodia (Mender, HashiCorp agent pattern).

### Lo que NO puede hacer

**Auto-eliminación:** Por seguridad y persistencia de la infraestructura, el sistema no puede ejecutar procesos de desinstalación sobre sí mismo para evitar sabotajes o errores fatales de administración. Si el control plane se elimina, el servidor queda sin guardián.

**Operaciones Destructivas sin Supervisión Humana:** Las operaciones de alto riesgo — desinstalación de aplicaciones, reparaciones invasivas que puedan afectar a otros contenedores y hacer caer el sistema — requieren **confirmación humana explícita** (governance dual-control). El IAM Installer diagnostica, reporta y espera aprobación del administrador antes de ejecutar cualquier acción destructiva. Esta es la práctica estándar de la industria: ArgoCD requiere sincronización manual en producción, Spacelift implementa approval policies para operaciones destructivas, y Kubernetes RBAC separa quién puede ejecutar `delete` de quién puede ejecutar `create`.

**Alteración de Lógica de Negocio:** Su jurisdicción termina en la operatividad del proceso; no modifica los datos contenidos dentro de las bases de datos que gestiona el Data Kernel. El IAM Installer gestiona el ciclo de vida del contenedor que aloja PostgreSQL, pero nunca toca los datos dentro de PostgreSQL.

### ¿Qué ganamos con esta definición?

1. **Terminología "Orchestrator":** Posiciona al IAM Installer al nivel de herramientas como Terraform, ArgoCD, Crossplane y los Kubernetes Operators — pero con el valor añadido de ser específico para SBOS y completamente soberano.

2. **Misión Crítica:** Al resaltar el Self-Healing y la Integridad, cualquier director de IT entenderá que este módulo es el que garantiza que el servidor no se "caiga". El loop de reconciliación continua, el auto-repair, el rollback automático y el monitoreo integral (SO → K8s → Fichas) conforman un sistema que detecta y corrige problemas antes de que el usuario los perciba.

3. **Soberanía — la cadena de custodia del software:** La cadena de confianza criptográfica (Ed25519 + SHA-256 + SLSA), el modelo pull-only, la operación offline completa y la ausencia total de dependencias cloud refuerzan que **tú controlas cada bit que se instala**.

---

## 2. Propósito y Posición en el Ecosistema

### El problema que el IAM Installer resuelve

Todo sistema de gestión de aplicaciones a escala enfrenta el mismo desafío fundamental: existe una brecha entre el **estado deseado** — lo que el administrador quiere que corra — y el **estado actual** — lo que realmente está corriendo en el cluster. Esa brecha, el *drift*, no es una condición excepcional. Es el estado natural de los sistemas distribuidos. Los pods fallan, los nodos se reinician, los archivos de configuración se modifican manualmente, las versiones quedan desactualizadas.

La industria convergió en una solución: el **control plane con reconciliación continua**. Un controlador es un loop que observa el estado del cluster y realiza cambios para acercar el estado actual al estado deseado. Este es el principio detrás de Kubernetes mismo, de ArgoCD, y de los Kubernetes Operators.

El IAM Installer es la implementación soberana de este principio para el SBOS. Pero hay una dimensión adicional que los sistemas de gestión convencionales no abordan: el IAM Installer no gestiona una sola instalación. **Gestiona una flota de instalaciones** — todos los clientes SKULL que corren SBOS en sus propios servidores. El estado deseado no es solo lo que el administrador local quiere. Es también lo que SKULL ha declarado como la versión oficial del sistema.

Esta dimensión de flota convierte al IAM Installer en algo más que un control plane local. Es el extremo cliente de una arquitectura de distribución soberana que conecta el laboratorio de desarrollo de SKULL con cada servidor de producción de cada cliente — sin que ningún dato del cliente salga de su infraestructura.

### El bootstrap como acto fundacional

A diferencia de los orquestadores convencionales que asumen una infraestructura preexistente, el IAM Installer comienza desde cero: toma un servidor Ubuntu virgen y lo transforma en un cluster Kubernetes con todo el stack SBOS instalado. Este proceso de bootstrap es **crítico y primordial** — si no se ejecuta, Kubernetes no existe, las fichas no se levantan, y el SBOS no cobra vida.

El bootstrap no es un bloque monolítico — es una secuencia de fichas que se intercalan con fichas de aplicación según dependencias técnicas reales: primero el SO se prepara, luego K8s se inicializa, luego se configuran namespaces y StorageClass, y luego las fichas de aplicación (PostgreSQL, Vault, Keycloak) se despliegan como contenedores K8s en el orden que el grafo DAG dicta. La especificación completa de esta secuencia está en SBOS-031-INSTALL-ROUTINE.

El mismo daemon que ejecuta el bootstrap es el que después mantiene la reconciliación continua — no hay código especial para "primera instalación". Todo es una ficha, y el daemon solo sabe: leer fichas, resolver dependencias, ejecutar en orden, ser idempotente.

### Tres niveles de operación: Ficha, Producto, Deploy

El IAM Installer opera en tres niveles de abstracción:

**Nivel 1 — Ficha:** La unidad atómica. PostgreSQL, Keycloak, Roundcube. Se instala igual siempre. `bosctl install <ficha>`

**Nivel 2 — Producto:** Un manifiesto que agrupa fichas + configuraciones para una solución completa. Define qué necesita de fichas existentes (evalúa si la configuración es suficiente y amplía si falta) y qué fichas nuevas instala. `bosctl product install <producto>`. Especificación en SBOS-032-PRODUCTS.

**Nivel 3 — Deploy:** Un manifiesto que agrupa productos + datos del cliente (nombre de empresa, NIT, dominio, admin inicial, cultura institucional). Es lo que el técnico SKULL usa para instalar un servidor completo de punta a punta. `bosctl deploy <archivo.yml>`. Especificación en SBOS-033-DEPLOY.

### Por qué un daemon, no un script

La decisión de implementar el IAM Installer como un daemon residente — y no como un script Bash de larga duración — es una consecuencia directa de sus responsabilidades. Un script Bash es la herramienta correcta para instaladores de una pasada, orquestación de comandos, setup inicial, scripts de mantenimiento acotados. Sus limitaciones son concretas para el rol de control plane: manejo pobre de errores en lógica de larga duración, ausencia de concurrencia real, imposibilidad de mantener estado persistente entre ciclos, y la incapacidad práctica de exponer una API REST o emitir eventos vía WebSocket.

La arquitectura resuelve esto con una separación de responsabilidades precisa: **Bash hace lo que Bash hace bien** — ejecutar tareas del sistema operativo, llamar a `kubectl`, correr scripts de aplicación — y **Go + Python hacen lo que hacen bien** — ser el daemon residente, orquestar, mantener estado, emitir eventos, exponer APIs. Los 4 archivos maestros `00_*.sh` y el Backend Python de 16 módulos son exactamente esta división, y esa frontera es invariable.

### La genealogía del diseño

**Kubernetes Controller Pattern (CoreOS, 2016)** — Los controladores de Kubernetes son loops de control que rastrean recursos y los llevan al estado deseado de forma continua. El IAM Installer adopta este patrón: observa el estado de las fichas, compara con el estado declarado en sus contratos, y actúa para reconciliar diferencias.

**GitOps / ArgoCD App-of-Apps Pattern** — El patrón App-of-Apps gestiona múltiples aplicaciones hijas desde una aplicación padre, aportando orden y observabilidad. El catálogo de fichas en `servers/` es la implementación soberana: el IAM Installer es la "app padre" que gestiona todas las fichas como "apps hijas".

**Backstage / Internal Developer Portal (Spotify → CNCF 2022)** — Un único cockpit desde el que el administrador ve y gestiona todo el stack, con el catálogo de fichas como fuente de verdad central. El Core UI del SBOS implementa este patrón de forma soberana.

**Kubernetes Operator Pattern** — El rol del Operator es reconciliar el estado actual de la aplicación con el estado deseado. Cada ficha SBOS es un mini-operador declarativo. El IAM Installer es el motor que los ejecuta.

**Elastic Agent / Datadog Agent Fleet Management** — La gestión centralizada de agentes distribuidos en múltiples hosts, con auto-actualización, reporte de estado, y distribución de configuración desde un plano central. El SKULL Release Plane adopta este modelo para la distribución soberana del SBOS.

**Infrastructure Lifecycle Management (HashiCorp, 2024)** — El enfoque de gestionar infraestructura a lo largo de su ciclo de vida completo: provisionar, validar, desplegar, monitorear, optimizar y retirar. El IAM Installer implementa este concepto como sistema soberano integral, pero abarcando desde el Day 0 (aprovisionamiento del SO) hasta el Day 2+ (operaciones continuas) sin requerir herramientas externas ni conectividad cloud.

La diferencia crítica con todos estos patrones es la **soberanía**: el IAM Installer no requiere conectividad a registros externos, no depende de servicios cloud, mantiene control humano explícito sobre cada operación destructiva, y los datos de cada cliente nunca abandonan su infraestructura.

---

## 2b. Stack Tecnológico del Daemon bos

### Justificación técnica de la arquitectura Go + Python + Bash

El SBOS IAM Installer es el daemon orquestador soberano del SBOS. Su naturaleza es fundamentalmente híbrida: necesita la velocidad y el control de un binario nativo (Go), la flexibilidad de un lenguaje dinámico para la lógica declarativa de fichas (Python), y acceso directo al sistema operativo para operaciones atómicas de instalación (Bash). Esta combinación no es una deuda técnica — es una decisión de ingeniería deliberada donde cada lenguaje hace lo que mejor sabe hacer.

**Por qué Go para el daemon principal:**
- Binario estático sin dependencias: se copia y ejecuta en cualquier servidor Ubuntu sin instalación previa.
- Arranque inmediato: sin JVM, sin VM, sin intérprete. El daemon arranca en < 100ms.
- Concurrencia nativa para gestionar múltiples fichas en paralelo durante la instalación.
- `net/http` nativo para comunicación con el Release Server y el Core UI.

**Por qué Python para los módulos de fichas:**
- Las fichas son lógica declarativa que evoluciona con cada cliente. Python permite modificarlas sin recompilar el daemon.
- Ecosistema de librerías para parsing de configuración, validación YAML/TOML, y scripting de instaladores.
- Los `task_catalog.sh` son scripts Bash de cada ficha, editables en producción sin recompilación.

**Por qué Bash para operaciones OS:**
- Operaciones atómicas de instalación: `cp`, `mv`, `chmod`, `systemctl` con semántica POSIX garantizada.
- Rollback de binarios: `cp /opt/bos/iam-installer.prev` vía shell script con manejo de errores nativo del OS.
- Sin capa de abstracción entre el daemon y el sistema de archivos del host.

### Stack de dependencias

| Componente | Herramienta / Versión | Propósito |
|---|---|---|
| **Lenguaje principal** | Go 1.22+ | Binario daemon, servidor HTTP, orquestación |
| **Módulos de fichas** | Python 3.11+ + Cython | Lógica declarativa compilable |
| **Scripts OS** | Bash 5.x | Operaciones atómicas del sistema |
| **Gestor de paquetes Go** | go modules (go.mod) | Dependencias del daemon |
| **Gestor de paquetes Python** | pip + pyproject.toml | Dependencias de módulos |
| **Build system** | Makefile + go build | Compilación cruzada amd64/arm64 |
| **Runtime HTTP** | net/http stdlib | API con Core UI y Release Server |
| **Config parsing** | github.com/BurntSushi/toml | Lectura de bos.toml |
| **Logging** | github.com/rs/zerolog | Logging estructurado JSON |
| **Testing Go** | go test + testify | Unit tests del daemon |
| **Testing Python** | pytest | Tests de módulos de fichas |
| **CI/CD** | GitHub Actions + golangci-lint | Lint, tests, build release |

---


## 3. Qué es el IAM Installer

El IAM Installer es el **control plane soberano del SBOS**. Es simultáneamente el instalador inicial, el daemon de vigilancia permanente, el motor de reconciliación del cluster, y el agente de actualización que mantiene a todos los clientes SKULL en el estado de versión correcto.

Técnicamente es un daemon que opera en dos capas:

**Como servicio systemd en el host:** vive en Ubuntu por encima de Kubernetes, se levanta con el sistema operativo, y permanece activo permanentemente. **No es un contenedor Kubernetes** — es el guardián del sistema operativo y no puede depender de lo que él mismo vigila. Si Kubernetes falla, el IAM Installer debe poder diagnosticarlo, repararlo, o reconstruirlo desde cero.

**Como agente de flota del SKULL Release Plane:** se conecta periódicamente al servidor de distribución de SKULL para verificar si hay nuevas versiones del sistema — tanto del propio IAM Installer como de las fichas del catálogo. Descarga, verifica integridad criptográfica, y aplica actualizaciones según la política configurada. Si el Release Plane no está disponible, opera en modo degradado sin interrumpir el control plane local.

**Lo que el IAM Installer hace permanentemente:**
- Mantiene el estado deseado declarado en las fichas alineado con el estado actual del cluster
- Detecta drift en configuraciones, versiones y estados de pods
- Responde a instrucciones del administrador vía Core UI
- Descubre fichas nuevas agregadas a `servers/` sin reiniciarse
- Gestiona el crecimiento horizontal del cluster
- Se conecta al SKULL Release Plane para recibir actualizaciones oficiales
- Aplica actualizaciones de fichas y del propio daemon según política configurada
- Revierte automáticamente a la versión anterior si una actualización del daemon falla su periodo de estabilización

**Lo que el IAM Installer no hace:**
- No toma decisiones destructivas sin confirmación humana explícita
- No modifica el código de las fichas — solo las ejecuta
- No mantiene estado propio fuera de `.sbos_state.json`
- No llama a `kubectl` directamente excepto a través de `sbos_k8s_core()`
- No envía datos del cliente al SKULL Release Plane — solo recibe actualizaciones
- No acepta conexiones entrantes desde el SKULL Release Plane — toda comunicación es pull

---

## 4. La Arquitectura de Tres Planos

El SBOS opera con tres planos claramente separados. Esta separación es la clave de la soberanía: los datos del cliente nunca suben al plano SKULL; las actualizaciones de SKULL bajan al plano cliente en forma de binarios y fichas, no de acceso remoto.

```
┌──────────────────────────────────────────────────────────────────────────┐
│  PLANO 1 — SKULL RELEASE PLANE (infraestructura SKULL)                   │
│                                                                           │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │  SKULL Release Server                                            │    │
│  │                                                                  │    │
│  │  /api/v1/releases/latest      ← versión actual · changelog      │    │
│  │  /api/v1/fichas/catalog       ← catálogo oficial de fichas      │    │
│  │  /api/v1/rollout/wave/<canal> ← canal del cliente (canary/…)    │    │
│  │  /dist/iam-installer-<arch>   ← binario compilado (Go)          │    │
│  │  /dist/fichas/<id>/<ver>/     ← fichas empaquetadas             │    │
│  │  /dist/checksums.sha256       ← hashes SHA-256                  │    │
│  │  /dist/checksums.sha256.sig   ← firma Ed25519 de los hashes     │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────┐   │
│  │  Entorno Dev     │  │  Pipeline CI/CD  │  │  SKULL Admin UI      │   │
│  │  Windows + WSL   │  │  Compilación     │  │  Fleet Dashboard     │   │
│  │  (ingenieros     │  │  Tests           │  │  Estado · Rollout    │   │
│  │   SKULL)         │  │  Firma binarios  │  │  Control de onda     │   │
│  └──────────────────┘  └──────────────────┘  └──────────────────────┘   │
└──────────────────────────────────┬───────────────────────────────────────┘
                                   │  HTTPS · Solo descarga (pull-only)
                                   │  Sin acceso remoto al cliente
                                   ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  PLANO 2 — IAM INSTALLER (host Ubuntu del cliente)                       │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │  IAM INSTALLER DAEMON (systemd — siempre activo)                   │  │
│  │                                                                     │  │
│  │  ┌─────────────┐  ┌──────────────────┐  ┌──────────────────────┐  │  │
│  │  │ Core SP-01  │  │  Backend Python  │  │  Core UI             │  │  │
│  │  │ 4 archivos  │  │  16 módulos      │  │  Flutter             │  │  │
│  │  │ maestros    │  │  Orquestación    │  │  Pod K8s             │  │  │
│  │  │ 00_*.sh     │  │  Estado · API    │  │  Admin local         │  │  │
│  │  └──────┬──────┘  └───────┬──────────┘  └──────────┬───────────┘  │  │
│  │         └────────────────┴──────────────────────────┘              │  │
│  └──────────────────────────────┬──────────────────────────────────────┘  │
│                                  │                                         │
│  .sbos_state.json (estado local) │  servers/ (fichas del catálogo)         │
│  /opt/bos/ (binario activo)      │  /opt/bos/iam-installer.prev (rollback) │
└──────────────────────────────────┼─────────────────────────────────────────┘
                                   │
┌─────────────────────────────────▼──────────────────────────────────────────┐
│  PLANO 3 — KUBERNETES CLUSTER (plano de ejecución del cliente)              │
│                                                                              │
│  servers/dataserver/postgresql/    → StatefulSet: postgresql                 │
│  servers/identityserver/keycloak/  → Deployment: keycloak                    │
│  servers/commsserver/mailserver/   → StatefulSet: mailserver                 │
│  servers/.../                      → ...                                     │
└──────────────────────────────────────────────────────────────────────────────┘
```

**La frontera de soberanía es absoluta:** el tráfico entre el Plano 1 y el Plano 2 es exclusivamente de descarga — binarios y fichas van hacia el cliente, nunca al revés. El SKULL Release Plane no tiene acceso SSH, no tiene acceso a la API de Kubernetes del cliente, y no recibe ningún dato operacional. La única señal que el IAM Installer envía al exterior es una petición HTTP GET con su versión actual y su canal de rollout asignado.

---

## 5. Capas de Responsabilidad de los Módulos Python

> **Esta sección es nueva en v5.0.** Organiza explícitamente los 16 módulos Python en dos capas de responsabilidad. Esta separación resuelve la brecha de la Capa 4 (Orquestación como Sagas con compensación) al hacer visible qué módulos contienen reglas de negocio del sistema y qué módulos coordinan flujos sin contener lógica propia.

### El principio de separación

La arquitectura de software empresarial distingue dos tipos de componentes con responsabilidades radicalmente distintas:

**Módulos de Dominio** — Contienen las reglas de negocio del sistema. Saben qué es válido, qué estado es correcto, qué constituye un error o un conflicto. Son el corazón del sistema. Su lógica es invariante respecto al flujo de orquestación: no importa quién los llame ni en qué orden, las reglas que implementan son siempre las mismas.

**Módulos de Orquestación** — Coordinan flujos entre los módulos de dominio. No contienen lógica de negocio propia — su conocimiento es de tipo *procedimental*: qué llama a qué, en qué orden, cómo se manejan los fallos entre pasos. Son la implementación del patrón **Saga**: una secuencia de operaciones locales donde cada paso tiene una transacción compensatoria que se ejecuta si el flujo falla.

Esta separación es la que permite que el sistema tenga **rollback con semántica correcta**: cuando una Saga de instalación falla en el paso 7, los pasos de compensación se ejecutan en orden inverso usando la lógica de dominio de cada módulo respectivo — sin que el orquestador necesite saber qué significa "desinstalar PostgreSQL".

### Asignación de módulos a capas

#### Capa de Dominio — Módulos que contienen reglas de negocio

| Módulo | Capa | Justificación |
|---|---|---|
| `STATE_MANAGER.py` | **Dominio** | Es el árbitro del estado del sistema. Sabe qué transiciones son válidas (`NO_INSTALADA → INSTALADA_OK`), detecta estados inconsistentes, y aplica la regla de escritura única. Ningún módulo de orquestación puede determinar si un estado es válido sin consultarlo. |
| `DEPENDENCY_RESOLVER.py` | **Dominio** | Contiene las reglas de qué puede instalarse antes de qué. El grafo DAG de dependencias es lógica de negocio pura — no es procedural. Un orquestador no puede saber si una ficha está desbloqueada sin que DEPENDENCY_RESOLVER lo evalúe. |
| `HEALTH_CHECKER.py` | **Dominio** | Sabe qué significa que una aplicación "está sana". Los criterios de health (`ok / degraded / error / pending`) son reglas de dominio. Un orquestador no puede determinar el estado de salud de una ficha por sí mismo. |
| `FICHA_LINTER.py` | **Dominio** | Sabe qué constituye un contrato SBOS válido. Las reglas de validación (campos obligatorios, formatos, restricciones) son lógica de negocio sobre la estructura de las fichas. |
| `FICHA_PROBE.py` | **Dominio** | Implementa el dry-run de una ficha: sabe qué verificar y cómo interpretar los resultados. El criterio de "qué haría esta ficha" es conocimiento de dominio sobre el ciclo de vida de las fichas. |
| `GROWTH_DETECTOR.py` | **Dominio** | Sabe qué umbrales de saturación son significativos y cuándo sugerir expansión horizontal. Los criterios de saturación son reglas de negocio operacional, no procedurales. |

#### Capa de Orquestación — Módulos que coordinan flujos sin lógica de negocio propia

| Módulo | Capa | Justificación |
|---|---|---|
| `INSTALL_RUNNER.py` | **Orquestación** | Coordina el ciclo completo install / update / repair / uninstall. Su conocimiento es procedimental: llama a DEPENDENCY_RESOLVER para verificar prerequisitos, a PROCESS_MANAGER para ejecutar, a STATE_MANAGER para registrar resultados. No sabe qué hace PostgreSQL — solo sabe cómo ejecutar una Saga de instalación. |
| `RECONCILE_SCHEDULER.py` | **Orquestación** | Coordina el loop periódico: llama a HEALTH_CHECKER y PLUGIN_LOADER, compara resultados, delega en STATE_MANAGER para actualizar estados. El scheduler no contiene reglas — es pura coordinación temporal. |
| `YAML_ENGINE.py` | **Orquestación** | Interpreta el `yaml_engine.yml` y coordina la secuencia de fases. Delega la ejecución real a PROCESS_MANAGER y la interpretación de señales al protocolo de señales. No contiene lógica de qué significa cada fase — solo sabe ejecutarlas en orden. |
| `RELEASE_MANAGER.py` | **Orquestación** | Coordina el protocolo de actualización con el SKULL Release Plane: verifica versiones, descarga, verifica firma Ed25519, instala, gestiona el watchdog de estabilización. Delega la lógica de estados a STATE_MANAGER y la ejecución de procesos a PROCESS_MANAGER. |
| `PLUGIN_LOADER.py` | **Orquestación** | Coordina el descubrimiento de fichas en `servers/` y el cálculo de hashes SHA-256. Delega la actualización de estado a STATE_MANAGER. No contiene reglas sobre qué fichas son válidas — eso es de FICHA_LINTER. |
| `INFRA_CONFIGURATOR.py` | **Orquestación** | Coordina el proceso de unión de nuevos nodos al cluster. Orquesta los pasos de `kubeadm join`, configuración de node selectors, y notificación. No contiene las reglas de cuándo un nodo es válido — coordina el proceso de incorporación. |
| `MENU_ENGINE.py` | **Orquestación** | Genera el catálogo de fichas para el Core UI consultando STATE_MANAGER, DEPENDENCY_RESOLVER y HEALTH_CHECKER. Es un agregador de información para la presentación — no toma decisiones de dominio. |
| `PROCESS_MANAGER.py` | **Orquestación** | Es el único módulo que llama `subprocess`. Coordina la ejecución de procesos externos y la emisión de eventos línea a línea. No contiene reglas sobre qué procesos ejecutar ni qué resultados son válidos. |
| `PROGRESS_EMITTER.py` | **Orquestación** | Coordina la transmisión de eventos por WebSocket y la persistencia en `.jsonl` para replay. No contiene lógica sobre qué eventos son significativos — solo los transmite y preserva. |
| `LOGGER.py` | **Orquestación** | Coordina el logging centralizado y el puente CLI hacia Bash. Infraestructura pura sin lógica de dominio. |

### La Saga del IAM Installer

Usando la terminología estándar de la industria (Argo Workflows, Temporal.io, Saga Pattern), las operaciones del IAM Installer son **Sagas orquestadas**: secuencias de transacciones locales donde cada paso tiene una transacción compensatoria definida.

| Saga | Pasos locales | Compensación ante fallo |
|---|---|---|
| `install` | pre_install → deploy → post_install → health_check → set_INSTALADA_OK | Ejecuta `uninstall_compensate`: revierte recursos K8s creados, elimina secrets, restaura estado anterior |
| `update` | backup → drift_apply → health_check → set_INSTALADA_OK | Restaura backup, revierte manifiesto a versión anterior, set_INSTALADA_OK con versión anterior |
| `repair` | diagnose → compensate_actions → health_check | Notifica sin compensación destructiva — diagnosis_first garantiza que no se actúa a ciegas |
| `daemon_update` | preserve_prev → install_new → stabilize (60s) | Rollback automático: cp .prev → restart → notifica |

El módulo `INSTALL_RUNNER` es el **orquestador de Sagas**: coordina la secuencia y delega la compensación. Los módulos de dominio son las **transacciones locales**: cada uno implementa su parte con semántica correcta sin conocer el flujo completo.

---

## 6. Los 4 Archivos Maestros Bash

El Core es el cerebro ejecutor del IAM Installer. Son 4 archivos maestros que toman una ficha y la ejecutan según sus instrucciones declarativas. **El Core no sabe qué aplicaciones existen** — solo sabe leer el contrato de una ficha y ejecutarlo. Esta ignorancia deliberada es la propiedad que hace al sistema extensible sin límite teórico.

### `00_MASTER_INSTALL_SBOS.sh` — Punto de Entrada

Recibe `comando + ficha_id + [version]`. Valida argumentos, localiza la ficha en `servers/`, absorbe su `task_catalog.sh`, ejecuta la acción, y libera las funciones al terminar.

**Comandos:** `install | update | repair | remove | status | probe | lint`

El comando `probe` ejecuta un dry-run completo sin desplegar nada — muestra exactamente qué haría cada fase. El comando `lint` valida que la ficha cumple el contrato SBOS antes de cualquier ejecución.

### `00_TASK_CATALOG_SBOS.sh` — Biblioteca de Funciones Genéricas

Biblioteca de funciones Bash globales cargada en memoria con `source` al arrancar. **Nunca nombra ninguna aplicación concreta** (Principio P3). Toda función que mencione una app específica va en el `task_catalog.sh` individual de esa ficha.

| Grupo | Funciones | Propósito |
|---|---|---|
| 1 · Validaciones | `check_root_user` · `check_system_requirements` · `check_k8s_cluster_ready` · `check_node_resources` | Verificar condiciones del sistema antes de actuar |
| 2 · K8s Genéricas | `create_k8s_namespace` · `create_pvc` · `delete_pvc` · `apply_network_policy` · `create_k8s_secret` · `apply_configmap` · `copy_file_to_pod` · `exec_command_in_pod` · `delete_k8s_manifest` | Crear y gestionar recursos K8s sin conocer la app |
| 3 · Esperas | `wait_pod_ready` · `wait_pod_healthy` · `verify_pod_running` · `verify_service_responds` · `verify_port_in_pod` · `wait_http_endpoint_ready` | Verificar que despliegues completaron correctamente |
| 4 · Filesystem | `create_directories` · `apply_permissions` · `backup_directory` · `restore_directory` | Operaciones en el host (Fichas de Sistema Tipo 1) |
| 5 · Ciclo de Vida | `rollout_restart` · `scale_deployment` · `take_backup_snapshot` · `restore_backup_snapshot` | Gestión del ciclo de vida de recursos K8s |

### `00_YAML_ENGINE_SBOS.sh` — El Intérprete Declarativo

El motor de ejecución. Lee el `yaml_engine.yml` de cada ficha con `yq` y ejecuta el flujo declarativo completo. Implementa tres principios de arquitectura críticos:

**P1 — Punto único de kubectl:** `sbos_k8s_core()` es el **único punto en todo el sistema** que llama a `kubectl apply`. Ningún otro módulo, ninguna función de ninguna ficha llama a kubectl para desplegar. Todo despliegue pasa por validación, logging y registro de estado.

**P7 — Ciclo Absorber/Ejecutar/Liberar:** antes de ejecutar cualquier ficha, el YAML Engine carga su `task_catalog.sh` en memoria. Al terminar, hace `unset -f` de todas las funciones específicas de esa ficha. El Core queda limpio — sin contaminación entre fichas.

**P14 — diagnosis_first en repair:** cuando una ficha declara `diagnosis_first: true` en su fase `repair`, el YAML Engine ejecuta todas las tareas de diagnóstico y construye un reporte completo antes de ejecutar cualquier acción correctiva. El sistema nunca repara a ciegas.

### `00_ARCHITECTURE_SBOS.yml` — Registro Declarativo Global

Fuente de verdad del Core. Mapea `nombre_tarea → función_bash` para todas las tareas globales. Es el árbitro de la frontera entre lo que es global (pertenece al Core) y lo que es específico (pertenece al `task_catalog.sh` de cada ficha). Si una tarea no está registrada aquí, el YAML Engine la busca en el catálogo individual de la ficha; si tampoco está ahí, emite un error con el mensaje exacto de corrección.

---

## 7. Los 16 Módulos Python con Asignación a Capa

El backend es el sistema nervioso del IAM Installer. Orquesta la ejecución, mantiene el estado, emite progreso en tiempo real, expone la API REST que consume el Core UI, y gestiona el protocolo de actualización con el SKULL Release Plane.

| Módulo | Capa | Responsabilidad única | Escribe a |
|---|---|---|---|
| `LOGGER.py` | Orquestación | Logging centralizado con niveles. Puente CLI hacia Bash | Archivos de log + stdout |
| `PROCESS_MANAGER.py` | Orquestación | **Único** módulo que llama `subprocess`. Emite eventos línea a línea sin acumular stdout | WebSocket vía PROGRESS_EMITTER |
| `STATE_MANAGER.py` | **Dominio** | **Única** escritura en `.sbos_state.json`. Usa `fcntl.flock` para concurrencia. Árbitro de transiciones de estado válidas | `.sbos_state.json` |
| `PROGRESS_EMITTER.py` | Orquestación | WebSocket + `.jsonl` para progreso en tiempo real. Buffer para replay al reconectar | WebSocket + `.jsonl` |
| `INSTALL_RUNNER.py` | Orquestación | Orquesta el ciclo completo como Saga: install / update / repair / uninstall con compensación | STATE_MANAGER |
| `PLUGIN_LOADER.py` | Orquestación | Escanea `servers/` para descubrir fichas. Calcula hashes SHA-256 de `resources/` para detección de drift | STATE_MANAGER |
| `DEPENDENCY_RESOLVER.py` | **Dominio** | Construye el grafo DAG de dependencias. Calcula orden topológico. Determina si una ficha está desbloqueada | STATE_MANAGER |
| `HEALTH_CHECKER.py` | **Dominio** | Ejecuta el `health.check_command` de cada ficha. Define y aplica los criterios de clasificación: `ok / degraded / error / pending` | STATE_MANAGER |
| `RECONCILE_SCHEDULER.py` | Orquestación | Loop periódico: compara hashes SHA-256 del estado actual vs declarado. Coordina HEALTH_CHECKER y PLUGIN_LOADER | STATE_MANAGER |
| `YAML_ENGINE.py` | Orquestación | Wrapper Python sobre el motor Bash. Parsea señales `__SBOS__STEP_*` y las convierte en eventos JSON | PROGRESS_EMITTER |
| `MENU_ENGINE.py` | Orquestación | Agrega información de STATE_MANAGER, DEPENDENCY_RESOLVER y HEALTH_CHECKER para el Core UI | API REST |
| `GROWTH_DETECTOR.py` | **Dominio** | Monitorea métricas Prometheus. Evalúa criterios de saturación. Determina cuándo sugerir expansión | Core UI vía WebSocket |
| `INFRA_CONFIGURATOR.py` | Orquestación | Coordina `kubeadm join` para nodos nuevos. Configura node selectors. Notifica disponibilidad | STATE_MANAGER |
| `FICHA_LINTER.py` | **Dominio** | Valida que una ficha cumple el contrato SBOS completo. Contiene las reglas de validación | Reporte de errores a Core UI |
| `FICHA_PROBE.py` | **Dominio** | Dry-run completo: determina qué haría cada fase de la ficha y evalúa viabilidad | Reporte a Core UI |
| `RELEASE_MANAGER.py` | Orquestación | Coordina el protocolo completo con el SKULL Release Plane. Verifica firma Ed25519, descarga binarios y fichas, gestiona rollback automático, opera en modo degradado | STATE_MANAGER + filesystem |

**Principio de responsabilidad única estricto:** `STATE_MANAGER` es el único que escribe en `.sbos_state.json`. `PROCESS_MANAGER` es el único que llama `subprocess`. `RELEASE_MANAGER` es el único que realiza peticiones HTTP al SKULL Release Plane. Cualquier módulo que necesite ejecutar un comando externo lo hace a través de `PROCESS_MANAGER`. Cualquier módulo que necesite leer o escribir el estado lo hace a través de `STATE_MANAGER`.

---

## 8. Protocolo de Señales

El Core Bash emite señales estructuradas por stdout. El módulo `YAML_ENGINE.py` las parsea línea a línea — nunca acumula stdout (Principio P5) — y las convierte en eventos JSON. `PROGRESS_EMITTER` los transmite al Core UI vía WebSocket y los persiste en `.jsonl` para replay.

### Las señales del protocolo

```bash
__SBOS__STEP_START__    Verificando recursos del nodo
__SBOS__STEP_OK__       Recursos verificados (RAM: 8GB / 4GB requeridos)
__SBOS__STEP_ERROR__    CAUSA: libseccomp2 < 2.5.0
                        SOLUCIÓN: apt-get install --only-upgrade libseccomp2
__SBOS__STEP_SKIP__     Namespace sbos-data ya existe — no se recrea
__SBOS__STEP_PROGRESS__ 17/30 Instalando CRI-O v1.34...
__SBOS__DONE__OK__
__SBOS__DONE__ERROR__
```

### Lo que ve el administrador en el Core UI

```
[✓] Paso  1/30  Actualizar sistema Ubuntu                2.3s
[✓] Paso  2/30  Configurar hostname único                0.1s
[✓] Paso  3/30  Instalar dependencias del sistema        45.2s
[↷] Paso  4/30  Configurar kernel parameters             SKIP (ya configurado)
[⟳] Paso 17/30  Instalar CRI-O v1.34                    (corriendo... 12s)
[✗] Paso 17/30  Instalar CRI-O v1.34                    ERROR
                CAUSA:    libseccomp2 < 2.5.0
                SOLUCIÓN: apt-get install --only-upgrade libseccomp2
                COMANDO:  bosctl repair sbos-bootstrap
```

### Replay al reconectar

Si el administrador cierra el navegador durante una operación, al reconectarse el Core UI solicita el replay desde el último evento recibido. `PROGRESS_EMITTER` lee el `.jsonl` y retransmite todos los eventos perdidos en orden — el administrador ve exactamente qué ocurrió mientras estuvo desconectado, sin perder ningún paso de una operación de 45 minutos.

---

## 9. El SKULL Release Plane — Distribución Soberana

### 9.1 Propósito

El SKULL Release Plane es la infraestructura de SKULL responsable de compilar, firmar y distribuir todas las versiones del IAM Installer y del catálogo de fichas a todos los clientes activos. Es el mecanismo por el cual SKULL mantiene la flota de instalaciones SBOS en el estado de versión correcto sin necesitar acceso directo a ningún servidor cliente.

Este modelo resuelve el problema central de cualquier producto de software distribuido soberano: ¿cómo actualizas cientos de instalaciones en servidores que no controlas, sin comprometer la soberanía de los datos del cliente?

La respuesta de SBOS es el mismo modelo que usan los sistemas más robustos de la industria: el cliente siempre tira (pull), nunca el proveedor empuja (push). El IAM Installer verifica periódicamente si hay actualizaciones disponibles, las descarga si corresponde, y las aplica según política. SKULL nunca inicia una conexión hacia el cliente.

### 9.2 El Flujo de Desarrollo a Producción

```
SKULL — LABORATORIO DE DESARROLLO
─────────────────────────────────────────────────────────────
Ingeniero SKULL desarrolla en Windows
  │
  ▼
WSL Ubuntu (entorno de compilación)
  ├── editar código Go (iam-installer daemon)
  ├── editar módulos Python (16 módulos backend)
  ├── editar archivos maestros Bash (00_*.sh)
  └── editar fichas en servers/

make build
  │
  ├── compila iam-installer → binario Go (amd64 / arm64)
  ├── empaqueta fichas modificadas
  ├── genera checksums SHA-256
  └── firma checksums con clave Ed25519 (clave privada en vault sellado SKULL)

make release VERSION=X.Y.Z
  │
  ▼
Pipeline CI/CD
  ├── tests de integración
  ├── validate_sp01.py  [OBLIGATORIO — exit ≠ 0 detiene el pipeline]
  ├── validate_sp02.py  [OBLIGATORIO — exit ≠ 0 detiene el pipeline]
  ├── generación de manifest de release
  ├── asignación de canal de rollout (canary / early / stable)
  └── publicación en SKULL Release Server

SKULL Release Server
  ├── /api/v1/releases/latest              → {"version": "X.Y.Z", "changelog": "..."}
  ├── /api/v1/fichas/catalog               → catálogo de fichas con versiones
  ├── /api/v1/rollout/wave/<canal>         → versión disponible para este canal
  ├── /dist/iam-installer-amd64            → binario compilado
  ├── /dist/iam-installer-arm64            → binario compilado (arquitectura ARM)
  ├── /dist/fichas/<id>/<ver>.tar.gz       → ficha empaquetada
  ├── /dist/checksums.sha256               → hashes SHA-256 de todos los artefactos
  └── /dist/checksums.sha256.sig           → firma Ed25519 del archivo de hashes
```

### 9.3 Lo que el SKULL Release Server Distribuye

| Artefacto | Descripción | Verificación |
|---|---|---|
| `iam-installer-<arch>` | Binario compilado del daemon. Sin dependencias en el servidor cliente. | SHA-256 + firma Ed25519 |
| `fichas/<id>/<ver>.tar.gz` | Ficha empaquetada: manifest.yml + yaml_engine.yml + task_catalog.sh + resources/ | SHA-256 |
| `releases/latest` | JSON con versión actual, changelog, canal de rollout asignado | Firmado |
| `fichas/catalog` | JSON con el catálogo completo de fichas disponibles, versiones, y dependencias | SHA-256 |
| `checksums.sha256` | Hashes SHA-256 de todos los artefactos del release | Firmado Ed25519 |
| `checksums.sha256.sig` | Firma criptográfica del archivo de hashes — protege contra sustitución del servidor | Ed25519 con clave privada SKULL |

---

## 10. Seguridad del Canal de Distribución (Ed25519)

### 10.1 El Modelo de Firma

El canal de distribución del SBOS usa firma criptográfica **Ed25519** (RFC 8032) como mecanismo principal de verificación de integridad y autenticidad. Ed25519 fue seleccionado sobre alternativas como RSA-2048 o ECDSA por tres propiedades concretas: claves más cortas (32 bytes vs 256 bytes en RSA), verificación más rápida en hardware de bajo perfil, y resistencia a ataques de timing side-channel por diseño del algoritmo.

### 10.2 La Cadena de Confianza

```
SKULL genera par de claves Ed25519
  ├── Clave privada → Vault sellado SKULL (acceso por quórum: N de M firmantes)
  └── Clave pública → compilada en el binario del IAM Installer

En cada release:
  make release
    ├── genera checksums.sha256 (hash de cada artefacto)
    └── firma checksums.sha256 con clave privada → checksums.sha256.sig

En cada instalación / actualización:
  IAM Installer descarga checksums.sha256 y checksums.sha256.sig
    ├── verifica checksums.sha256.sig con clave pública compilada
    │     └── SI FALLA: ABORT — no se descarga ningún binario
    └── descarga binario iam-installer-<arch>
          └── verifica hash SHA-256 contra checksums.sha256
                └── SI FALLA: ABORT — binario descartado, no se instala
```

### 10.3 Protección Contra Compromiso del Servidor de Distribución

El vector de ataque que la cadena de confianza protege es el siguiente: un atacante que compromete el servidor de distribución y sustituye el binario por uno malicioso. Sin firma criptográfica, el IAM Installer no puede distinguir el binario legítimo del binario comprometido aunque verifique el hash SHA-256 — porque el atacante también puede sustituir el archivo de hashes.

La firma Ed25519 cierra este vector: el atacante necesitaría también comprometer la clave privada en el Vault sellado de SKULL, que está protegida por quórum. Comprometer el servidor de distribución no es suficiente.

### 10.4 Rotación de Claves

La clave privada Ed25519 se rota con el siguiente proceso:
1. SKULL genera un nuevo par de claves Ed25519
2. La nueva clave pública se distribuye en una versión del IAM Installer firmada con la clave **antigua** — la cadena de confianza se mantiene durante la transición
3. Una vez que la flota completa está en la versión con la nueva clave pública compilada, la clave privada antigua se revoca en el Vault

---

## 11. Estrategia de Rollout Canary/Early/Stable con Criterios de Halt

### 11.1 Los Tres Canales

El rollout del SBOS divide la flota de clientes en tres canales con propósitos distintos:

| Canal | Población | Propósito | Secuencia temporal |
|---|---|---|---|
| `canary` | 1-3 clientes voluntarios de alta confianza | Validación en producción real. Detecta problemas que no aparecen en tests de integración | Semana 1 del release |
| `early` | ~20% de la flota activa | Validación a escala. Detecta problemas de compatibilidad con distintas configuraciones de hardware y red | Semanas 2-3 |
| `stable` | Resto de la flota | Distribución general una vez validado por canary y early | Semana 4 en adelante |

### 11.2 El Flujo de Avance de Rollout

```
make release VERSION=X.Y.Z
  │
  ▼
Pipeline CI/CD (§13) — validate_sp01.py y validate_sp02.py obligatorios
  │
  ▼
Release disponible en Release Server
  │
  ▼
Canal CANARY recibe la versión
  │
  ├── Monitoreo activo: 72 horas de observación
  │
  ├── ¿Criterios de halt disparados? (ver §10.3)
  │     ├── SÍ → HALT inmediato (ver §10.4)
  │     └── NO → continúa
  │
  ▼
Canal EARLY recibe la versión
  │
  ├── Monitoreo activo: 7 días
  │
  ├── ¿Criterios de halt disparados?
  │     ├── SÍ → HALT
  │     └── NO → continúa
  │
  ▼
Canal STABLE recibe la versión
```

### 11.3 Criterios Formales de Halt del Rollout

> **Esta tabla es nueva en v5.0.** Define con precisión cuándo el rollout se detiene, eliminando la ambigüedad de criterios implícitos.

| Evento | Criterio | Acción | Comunicación |
|---|---|---|---|
| **Incidente P0** | 1 cliente con sistema inutilizable (Core UI inaccesible + bosctl no responde + control plane caído) | **HALT inmediato** del rollout hacia todos los canales siguientes | Comunicación activa a **toda la flota** (canary + early + stable pendiente) antes de continuar cualquier avance |
| **Incidentes P1** | 2 incidentes P1 (degradación funcional significativa — sistema operable pero con fallos en funciones críticas) en menos de 4 horas en el mismo canal | **HALT** del canal afectado + hold de canales siguientes | Revisión obligatoria del equipo de ingeniería antes de continuar. El Fleet Dashboard bloquea el avance hasta recibir aprobación explícita |
| **Degradación de latencia** | Latencia de API REST del IAM Installer > 50% sobre baseline sostenida más de 15 minutos | **HOLD** — el rollout no avanza al siguiente canal | El Fleet Dashboard lo reporta como alerta. El equipo evalúa y decide explícitamente continuar o rollback |
| **Error rate** | Error rate > 1% en cualquier endpoint crítico (`/health`, `/fichas`, `/state`) durante más de 10 minutos | **HOLD** | Mismo proceso que degradación de latencia |

**Nota:** los criterios de HALT son condiciones de parada no negociables. Los criterios de HOLD son condiciones que requieren decisión humana explícita para continuar — no se resuelven automáticamente.

### 11.4 El Proceso de HALT

```
Criterio de HALT disparado en canal CANARY
  │
  ▼
SKULL Fleet Dashboard bloquea automáticamente el avance a EARLY y STABLE
  │
  ▼
Notificación activa a todos los administradores del canal canary afectado
  │
  ▼
Equipo SKULL ingeniería: análisis del incidente
  │
  ├── ¿Corrección disponible en < 24h?
  │     ├── SÍ → hotfix → nuevo pipeline CI/CD → nuevo release → reinicia rollout
  │     └── NO → rollback de flota completa a versión anterior estable
  │
  ▼
Comunicación de status a toda la flota afectada antes de cualquier acción
```

### 11.5 Control desde el Fleet Dashboard

El SKULL Admin Fleet Dashboard es el panel de control del rollout. Sus invariantes de privacidad son absolutas: el Fleet Dashboard no tiene acceso a datos operacionales de los clientes — solo conoce la versión instalada, el canal asignado, y el estado de estabilización del daemon (OK/FALLO).

Operaciones disponibles desde el Fleet Dashboard:
- Promover un cliente de `canary` a `early` manualmente
- Pausar el rollout de un canal específico
- Ejecutar rollback de flota completa a versión anterior
- Aprobar la continuación del rollout después de un HOLD

---

## 12. Rollback Automático del Daemon

### 12.1 El Problema

El ciclo de actualización del daemon (`RELEASE_MANAGER` descarga nuevo binario → `systemctl restart bos`) tiene un riesgo concreto: el nuevo binario puede tener un defecto que no fue detectado en los tests de integración y que solo se manifiesta en el entorno específico del cliente — una versión del kernel del host, una configuración de red particular, un estado del cluster inesperado. Si el daemon arranca con el nuevo binario y falla inmediatamente, `Restart=always` lo reiniciará con el mismo binario roto indefinidamente, dejando al cliente sin control plane hasta que intervenga un humano.

La solución es el patrón **watchdog + versión en custodia**: el nuevo binario tiene un periodo de estabilización para demostrarse operativo; si falla en ese periodo, el sistema revierte automáticamente al binario anterior.

### 12.2 El Proceso de Actualización con Rollback

```
RELEASE_MANAGER — nueva versión verificada y lista para instalar
  │
  ▼
1. PRESERVAR — guardar versión actual como respaldo

   cp /opt/bos/iam-installer → /opt/bos/iam-installer.prev
   STATE_MANAGER: BOS_PREV_VERSION = "<version_actual>"

  │
  ▼
2. INSTALAR — nuevo binario en posición activa

   mv /tmp/bos-build/iam-installer-<arch> → /opt/bos/iam-installer
   STATE_MANAGER: BOS_PENDING_STABILIZATION = true

  │
  ▼
3. REINICIAR con periodo de estabilización

   systemctl restart bos
     │
     └── ExecStartPost: bosctl health --wait-stable=60 --on-fail=rollback
           │
           ├── ¿Daemon alcanza estado STABLE en 60 segundos?
           │     │
           │     ├── SÍ →  STATE_MANAGER: BOS_PENDING_STABILIZATION = false
           │     │          log: "Actualización a vX.Y.Z estabilizada correctamente"
           │     │          /opt/bos/iam-installer.prev se conserva 7 días
           │     │
           │     └── NO → ROLLBACK AUTOMÁTICO (§11.3)
```

### 12.3 El Proceso de Rollback

```
ROLLBACK AUTOMÁTICO disparado por bosctl health
  │
  ▼
log nivel CRITICAL: "Fallo de estabilización vX.Y.Z — iniciando rollback a vA.B.C"
  │
  ▼
¿/opt/bos/iam-installer.prev existe?
  │
  ├── SÍ → cp /opt/bos/iam-installer.prev → /opt/bos/iam-installer
  │         systemctl restart bos
  │         STATE_MANAGER: BOS_VERSION = "<version_anterior>"
  │         STATE_MANAGER: BOS_PENDING_STABILIZATION = false
  │         STATE_MANAGER: BOS_ROLLBACK_OCURRIDO = true
  │         PROGRESS_EMITTER: notifica al Core UI con alerta CRITICAL
  │                           "Rollback automático completado — en vA.B.C"
  │         RELEASE_MANAGER: marca vX.Y.Z como ROLLBACK_REQUIRED en config local
  │                           (no volverá a intentar instalar esta versión
  │                            hasta recibir instrucción explícita del admin)
  │
  └── NO  → estado de emergencia — sin binario de respaldo disponible
             bosctl emite alerta CRITICAL por todos los canales disponibles
             (Core UI + log + journal) con instrucciones de recuperación manual:
             "Ejecute: sudo instalo bos para reinstalar desde Release Server"
```

### 12.4 Criterios de Estabilización

El daemon alcanza el estado `STABLE` cuando cumple todos los siguientes criterios dentro del periodo de 60 segundos:

| Criterio | Verificación |
|---|---|
| Proceso activo | `systemctl is-active bos` retorna `active` |
| API REST respondiendo | `GET localhost:<port>/health` retorna HTTP 200 |
| STATE_MANAGER operativo | `.sbos_state.json` accesible y parseable |
| RECONCILE_SCHEDULER iniciado | Al menos un ciclo de reconciliación completado sin error |
| Sin crash loops | El proceso no ha reiniciado más de una vez en el periodo de observación |

Si cualquiera de estos criterios no se cumple en 60 segundos, se dispara el rollback. El umbral de 60 segundos es configurable en `/etc/bos/bos.toml` bajo `daemon.stabilization_timeout_seconds`.

---

## 13. Modo Degradado — Operación Offline

### 13.1 Principio

El IAM Installer es un sistema soberano. Su función central — gestionar el cluster Kubernetes del cliente — no debe depender de la disponibilidad del SKULL Release Server. Si el cliente no tiene acceso a internet, si el Release Server tiene mantenimiento planificado, o si hay una interrupción de conectividad, el IAM Installer continúa operando con plena capacidad de control plane local.

**La conectividad al SKULL Release Plane es opcional para la operación. Es requerida solo para recibir actualizaciones.**

### 13.2 Comportamiento por Módulo en Modo Degradado

| Módulo | Comportamiento con Release Server DISPONIBLE | Comportamiento con Release Server NO DISPONIBLE |
|---|---|---|
| `RELEASE_MANAGER` | Verifica versiones cada N horas, descarga y aplica según política | Reintenta con backoff exponencial (5min → 30min → 2h → 6h). Notifica al admin en Core UI: "Sin contacto con SKULL Release Server desde hace Xh" |
| `RECONCILE_SCHEDULER` | Operación normal | **Sin cambio — opera igual** |
| `HEALTH_CHECKER` | Operación normal | **Sin cambio — opera igual** |
| `INSTALL_RUNNER` | Operación normal | **Sin cambio** — instala, repara, actualiza fichas con las versiones disponibles localmente |
| `PLUGIN_LOADER` | Detecta fichas locales + fichas descargadas del Release Server | Detecta solo fichas locales disponibles en `servers/` |
| `GROWTH_DETECTOR` | Operación normal | **Sin cambio — opera igual** |
| API REST / WebSocket | Operación normal | **Sin cambio — opera igual** |
| Core UI | Operación normal | Muestra banner de advertencia: Release Server sin contacto. Todas las demás funciones operan. |

### 13.3 Lo que el administrador ve en Core UI

```
┌─────────────────────────────────────────────────────────────────┐
│  ⚠  SKULL Release Server sin contacto desde hace 4h             │
│     Las actualizaciones de versión no están disponibles.         │
│     El control plane local opera con normalidad.                 │
│     Último contacto: 2026-03-09 08:32 UTC                        │
│     [Reintentar ahora]                                           │
└─────────────────────────────────────────────────────────────────┘

[Sistema operando normalmente]

✓ postgresql      INSTALADA_OK
✓ keycloak        INSTALADA_OK
✓ mailserver      INSTALADA_OK
⚠ monitoring      INSTALADA_ALERTA  → [Reparar]
```

### 13.4 Límite Operacional del Modo Degradado

El único límite del modo degradado es que no es posible instalar fichas que aún no han sido descargadas del Release Server. Si el administrador intenta instalar una ficha nueva que no está disponible localmente, el Core UI muestra:

```
Esta ficha requiere descarga desde el SKULL Release Server.
El sistema está operando en modo offline.
Acciones disponibles: [Reintentar conexión] [Cancelar]
```

Para todas las fichas ya presentes en `servers/`, las 4 acciones (install, update, repair, remove) están completamente disponibles sin restricción.

---

## 14. Pipeline CI/CD con Validador como Paso Obligatorio

> **Esta sección es actualizada en v5.0.** `validate_sp01.py` y `validate_sp02.py` se integran como pasos obligatorios del pipeline — no son herramientas de uso manual. El pipeline no puede publicar una versión si cualquiera de los validadores sale con código distinto de 0.

### 14.1 El Flujo Completo del Pipeline

```
make release VERSION=X.Y.Z
  │
  ▼
[1] Compilación
  ├── go build → iam-installer-amd64
  └── go build → iam-installer-arm64

  │
  ▼
[2] Tests de integración
  ├── test suite completa contra cluster K8s de staging
  └── SI FALLA → pipeline ABORT (no continúa)

  │
  ▼
[3] validate_sp01.py  ← OBLIGATORIO — valida el contrato del Core (SP-01)
  ├── Verifica que los 4 archivos maestros Bash cumplen las restricciones de arquitectura
  ├── Verifica P1: sbos_k8s_core es el único punto de kubectl apply
  ├── Verifica P3: 00_TASK_CATALOG_SBOS.sh no menciona apps concretas
  ├── Verifica P6: todas las funciones del catálogo terminan con export -f
  └── exit 0 → continúa | exit ≠ 0 → ABORT (pipeline no publica ningún artefacto)

  │
  ▼
[4] validate_sp02.py  ← OBLIGATORIO — valida el catálogo de fichas (SP-02)
  ├── Verifica que cada ficha en servers/ tiene manifest.yml válido
  ├── Verifica que yaml_engine.yml referencia solo tareas registradas
  ├── Verifica que task_catalog.sh tiene export -f en todas las funciones
  ├── Verifica que resources/ contiene los artefactos declarados en manifest
  └── exit 0 → continúa | exit ≠ 0 → ABORT

  │
  ▼
[5] Generación de artefactos firmados
  ├── genera checksums.sha256 de todos los binarios y fichas
  └── firma checksums.sha256 con clave Ed25519 → checksums.sha256.sig

  │
  ▼
[6] Asignación de canal de rollout
  └── canary / early / stable según política vigente

  │
  ▼
[7] Publicación en SKULL Release Server
  └── SOLO si todos los pasos anteriores completaron con exit 0
```

### 14.2 Por qué los validadores son pasos obligatorios y no herramientas manuales

La diferencia no es cosmética. Un validador manual puede ser omitido por error o bajo presión de tiempo. Un validador integrado en el pipeline como paso obligatorio no puede ser omitido — el pipeline falla y no publica si el validador falla.

`validate_sp01.py` protege la invariante de arquitectura del Core. `validate_sp02.py` protege el contrato de las fichas. Ambos son la última línea de defensa antes de que una versión llegue a producción. Sin ellos, es posible publicar una versión con violaciones de los principios P que solo se manifiestan en producción.

---

## 15. El IAM Installer como Daemon Residente

### 15.1 El Script de Bootstrap: `instalo bos`

```bash
#!/usr/bin/env bash
# instalo bos — Bootstrap del IAM Installer
# Descargado y ejecutado con:
# curl -fsSL https://releases.skull.io/install.sh | sudo bash

set -euo pipefail

# ¿Ya existe una instalación?
  │
  ├── SÍ → modo actualización forzada
  └── NO → instalación completa desde cero

Detecta arquitectura del sistema (amd64 / arm64)

GET https://releases.skull.io/dist/checksums.sha256
GET https://releases.skull.io/dist/checksums.sha256.sig
GET https://releases.skull.io/dist/iam-installer-<arch>

Verificación Ed25519 + SHA-256

Crea usuario de servicio: bosagent (sin shell)
Instala binario en /opt/bos/iam-installer
Instala configuración en /etc/bos/bos.toml
Instala y habilita bos.service (systemd)
systemctl start bos

El IAM Installer entra en operación permanente
```

### 15.2 El Servicio systemd

```ini
# /etc/systemd/system/bos.service

[Unit]
Description=SBOS IAM Installer — Sovereign Control Plane
Documentation=https://skull.io/sbos/docs
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/bos/bos
ExecStartPost=/opt/bos/bosctl health --wait-stable=60 --on-fail=rollback
Restart=always
RestartSec=5
User=bosagent
Group=bosagent
WorkingDirectory=/opt/bos
Environment=BOS_ENV=production
Environment=BOS_CONFIG=/etc/bos/bos.toml
Environment=BOS_RELEASE_SERVER=https://releases.skull.io
StandardOutput=journal
StandardError=journal
SyslogIdentifier=bos

# Hardening del proceso
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/opt/bos /etc/bos /var/log/bos
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

Propiedades críticas:
- `Restart=always` — el IAM Installer nunca queda caído; si el proceso termina por cualquier causa, systemd lo reinicia en 5 segundos
- `ExecStartPost` — después de cada arranque, `bosctl health` verifica que el daemon alcanza el estado `stable` en 60 segundos; si no lo logra, dispara el proceso de rollback automático (§11)
- `After=network-online.target` — garantiza que la red esté completamente disponible antes de iniciar
- `User=bosagent` — el daemon corre bajo un usuario de servicio sin shell, principio de mínimos privilegios
- `NoNewPrivileges=true` + `ProtectSystem=strict` — hardening del proceso del daemon

### 15.3 Estructura de Archivos en el Servidor

```
/opt/bos/
  ├── iam-installer          ← binario activo del daemon (pre-compilado, sin fuentes)
  ├── iam-installer.prev     ← binario de la versión anterior (custodia para rollback)
  └── bosctl                 ← CLI de administración

/etc/bos/
  ├── bos.toml               ← configuración del daemon
  ├── .sbos_state.json       ← estado persistente (fuente de verdad local)
  ├── *.jsonl                ← eventos de operaciones para replay
  └── blibs/
      ├── servers/           ← fichas del catálogo (descargadas del Release Server)
      │   └── <servidor>/
      │       └── <nombre_ficha>/
      │           ├── manifest.yml
      │           ├── yaml_engine.yml
      │           ├── task_catalog.sh
      │           └── resources/
      ├── bkernel/rules/     ← reglas del SBOS Data Kernel
      ├── biedata/boxes/     ← cajas de SBOS Data Integration
      ├── bcompass/router/   ← rutas de SBOS AI Tools
      ├── bsearch/patterns/  ← patrones de SBOS Data RAG
      ├── bauth/auths/       ← fichas auth de SBOS Auth Enforce
      ├── bhnexus/rights/    ← fichas rights de SBOS Nexus Host
      └── banexus/           ← configuración del agente cliente

/var/log/bos/
  └── iam-installer.log      ← logs del daemon (rotación automática por journald)

/etc/systemd/system/
  └── bos.service      ← definición del servicio
```

### 15.4 El CLI `bosctl`

#### Comandos de estado y diagnóstico

```bash
bosctl status                    # estado del daemon y resumen de todas las fichas
bosctl health                    # salud detallada del sistema y del cluster
bosctl logs [--follow]           # logs del daemon en tiempo real
bosctl version                   # versión instalada y versión disponible en Release Server
bosctl fichas                    # lista fichas instaladas con estado
bosctl probe <ficha>             # dry-run completo de una ficha sin desplegar
bosctl lint <ficha>              # valida el contrato SBOS de una ficha
bosctl offline-status            # muestra estado del sistema en modo degradado
```

#### Comandos de ciclo de vida de fichas

```bash
bosctl install <ficha>           # instala una ficha específica (resuelve dependencias)
bosctl install --all             # ejecuta el grafo completo (primera instalación)
bosctl update <ficha>            # aplica actualización de una ficha
bosctl repair <ficha>            # diagnostica y repara una ficha
bosctl remove <ficha>            # desinstala con governance dual-control
```

#### Comandos de productos y despliegue

```bash
bosctl product list              # lista productos disponibles en products/
bosctl product install <producto> # instala un producto completo (evalúa, amplía, instala)
bosctl product status <producto>  # estado de todas las fichas de un producto
bosctl product verify <producto>  # re-ejecuta verificaciones del producto
bosctl deploy <archivo.yml>      # despliegue completo desde seed file del cliente
bosctl deploy status             # estado del despliegue activo
```

#### Comandos del daemon

```bash
bosctl update-daemon             # fuerza verificación y aplicación de actualización del daemon
bosctl rollback                  # revierte al binario anterior manualmente
bosctl restart                   # reinicia el daemon
```

**Principio de equivalencia CLI ↔ Core UI:** todo lo que `bosctl` puede hacer, el Core UI podrá hacer cuando exista. El Core UI llama a la misma API REST del daemon. No hay operaciones exclusivas de ninguno de los dos — la única diferencia es la interfaz (terminal vs navegador).

---

## 16. El Ciclo de Vida Completo

### 16.1 Primera instalación (desde Ubuntu virgen)

En la primera instalación, el daemon `bos` detecta que no hay cluster K8s y ejecuta automáticamente el grafo completo de fichas base. No hay código especial para "primera instalación" — el daemon lee fichas, resuelve dependencias, y ejecuta en orden. La primera ficha (`sbos-bootstrap-os`) no tiene dependencias; cada ficha posterior depende de la anterior.

```
curl -sSL https://get.sbos.io/installer | sudo bash [-s -- --deploy=cliente.yml]
  │
  ▼
daemon bos instalado como systemd — arranca automáticamente
  │
  ▼
PLUGIN_LOADER escanea servers/ → carga catálogo de fichas
DEPENDENCY_RESOLVER construye grafo DAG
  │
  ├── ¿Primera vez (no hay K8s)?
  │     SÍ → ejecuta el grafo completo en orden topológico:
  │
  │     sbos-bootstrap-os (bash)      → SO preparado
  │     sbos-bootstrap-k8s (bash)     → K8s operativo + Calico + MetalLB
  │     sbos-bootstrap-platform (bash) → namespaces + StorageClass + RBAC
  │     sbos-k8s-network-validator (k8s) → certifica red funcional
  │     postgresql (k8s)              → base de datos del stack
  │     redis (k8s)                   → caché y sesiones
  │     minio (k8s)                   → object storage
  │     vault (k8s)                   → secretos y PKI
  │     keycloak (k8s)                → identidad y OAuth2
  │     nginx (k8s)                   → reverse proxy
  │     kong (k8s)                    → API Gateway
  │     linkerd (k8s)                 → mTLS entre pods
  │     kyverno (k8s)                 → admission policies
  │     prometheus (k8s)              → monitoreo
  │     grafana (k8s)                 → dashboards
  │     sbos-bootstrap-hardening (bash) → verificación CIS final
  │
  │     Si se proporcionó --deploy=cliente.yml:
  │       → continúa con los productos del deploy (mail, erp, etc.)
  │
  │     ══════ SISTEMA BASE COMPLETO ══════
  │
  └── ¿Ya hay K8s? → modo normal (ver §16.2)
```

La especificación detallada de cada ficha de la primera instalación (dependencias, tareas, tiempos, validación técnica) está en SBOS-031-INSTALL-ROUTINE.

### 16.2 Operación normal (sistema ya instalado)

```
Sistema operativo arranca
  │
  ▼
systemd levanta bos (IAM Installer — servicio always-active)
  │
  ▼
RELEASE_MANAGER verifica versión con SKULL Release Plane
  │
  ├── ¿Release Server disponible?
  │     ├── SÍ → verifica versión según canal de rollout asignado
  │     │         aplica según política (notify / auto) → §12 si hay actualización
  │     └── NO → modo degradado (§13): continúa sin actualización, avisa al admin
  │
  ▼
FICHA_LINTER valida todas las fichas en servers/
  │
  ▼
PLUGIN_LOADER escanea servers/ → carga catálogo de fichas
  │
  ▼
DEPENDENCY_RESOLVER construye grafo de dependencias
  │
  ▼
HEALTH_CHECKER verifica estado de fichas instaladas
  │
  ├── ¿Fichas en ALERTA? ──SÍ──▶ intenta repair automático (si auto_repair: true)
  │                               si falla → notifica al admin con CAUSA + SOLUCIÓN
  │
  ▼
En espera permanente (loops independientes):
  ├── RELEASE_MANAGER loop    → verifica actualizaciones SKULL cada N horas
  ├── RECONCILE_SCHEDULER     → drift check de fichas cada N minutos
  ├── PLUGIN_LOADER watch     → detecta fichas nuevas en servers/
  ├── HEALTH_CHECKER loop     → monitoreo de salud continuo
  ├── GROWTH_DETECTOR loop    → saturación de nodos
  └── API REST / WebSocket    → instrucciones del Core UI y bosctl
```

---

## 17. El Ciclo Absorber → Ejecutar → Liberar

```
┌─────────────────────────────────────────────────────────────────┐
│  1. ABSORBER                                                    │
│                                                                 │
│  FICHA_LINTER valida el contrato de la ficha                   │
│  FICHA_PROBE ejecuta dry-run si fue solicitado                 │
│  Core localiza: servers/<servidor>/<ficha>/                    │
│  source task_catalog.sh → _task_<app>_*() en memoria           │
│  DEPENDENCY_RESOLVER verifica dependencias satisfechas         │
└──────────────────────────────┬──────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│  2. EJECUTAR                                                    │
│                                                                 │
│  YAML Engine lee yaml_engine.yml fase a fase:                  │
│                                                                 │
│  pre_install:                                                   │
│    ├── Tareas globales: en 00_ARCHITECTURE_SBOS.yml            │
│    └── Tareas específicas: en task_catalog.sh de la ficha      │
│    SI FALLA → ABORT total (no continúa al install)             │
│    SI ABORT → compensación: INSTALL_RUNNER ejecuta Saga inversa│
│                                                                 │
│  install: (solo si workload.type == "kubernetes")              │
│    └── sbos_k8s_core("apply", manifest, namespace)            │
│        [ÚNICO punto de kubectl apply en todo el sistema]       │
│                                                                 │
│  post_install:                                                  │
│    ├── Integración con Keycloak, Kong, Vault                   │
│    ├── Importación de resources/sql/, resources/config/        │
│    └── Verificación de health checks                           │
│                                                                 │
│  STATE_MANAGER.set_ficha_state(id, "INSTALADA_OK")            │
│  DEPENDENCY_RESOLVER.recalculate()                             │
│    └── desbloquea fichas dependientes                          │
└──────────────────────────────┬──────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│  3. LIBERAR                                                     │
│                                                                 │
│  unset -f _task_<app>_*()  → funciones específicas eliminadas  │
│  Core queda limpio para la siguiente operación                  │
│  No hay contaminación de funciones entre fichas                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 18. Las 4 Acciones sobre una Ficha

| Acción | Propósito | Pre-condición | Señal de éxito |
|---|---|---|---|
| `install` | Instalación completa desde estado cero | Dependencias en `INSTALADA_OK` | `__DONE__OK__` |
| `update` | Aplica solo el delta detectado (drift_check) | Ficha en `ACTUALIZACION_DISPONIBLE` | `__DONE__OK__` |
| `repair` | Diagnostica primero → repara después | `diagnosis_first: true` en fichas críticas | `__DONE__OK__` |
| `remove` | Desinstalación con backup previo | Confirmación explícita + governance check | `__DONE__OK__` |

### La acción `repair` en detalle

La reparación nunca es ciega. El YAML Engine ejecuta primero todas las tareas de diagnóstico, construye un reporte del estado actual, y solo entonces ejecuta las acciones correctivas. Las tareas de diagnóstico usan `on_failure: "continue"` — un diagnóstico fallido no aborta el proceso. Las acciones correctivas usan `on_failure: "abort"` — una reparación fallida sí detiene todo.

### La acción `update` y el drift_check

`RECONCILE_SCHEDULER` detecta drift comparando hashes SHA-256 de los archivos en `resources/` contra los hashes en `.sbos_state.json`. Cuando `RELEASE_MANAGER` descarga una nueva versión de una ficha, la marca como `ACTUALIZACION_DISPONIBLE`. El administrador puede en el Core UI: actualizar ahora, omitir esta versión, o investigar el diff exacto entre estado declarado y estado actual antes de decidir.

---

## 19. El Loop de Reconciliación Continua

```
RECONCILE_SCHEDULER (loop — intervalo configurable por ficha)
  │
  ▼
Para cada ficha en estado INSTALADA_OK o INSTALADA_ALERTA:
  │
  ├── HEALTH_CHECKER.check(ficha)
  │     ├── kubectl exec → health.check_command del manifest.yml
  │     └── Clasifica: ok / degraded / error / pending
  │
  ├── PLUGIN_LOADER.compute_hashes(ficha.resources/)
  │     └── SHA-256 de cada archivo en resources/
  │
  ├── Comparar con hashes en .sbos_state.json
  │
  ├── ¿Diferencias de hash?
  │     ├── SÍ → STATE_MANAGER: ACTUALIZACION_DISPONIBLE
  │     │         PROGRESS_EMITTER: notifica al Core UI
  │     └── NO → no-op
  │
  └── ¿Health degraded o error?
        ├── SÍ → STATE_MANAGER: INSTALADA_ALERTA
        │         Intenta repair si auto_repair: true en manifest
        └── NO → sin acción
```

**La diferencia con ArgoCD:** ArgoCD sincroniza automáticamente por defecto. El IAM Installer **reporta y espera confirmación humana** para cambios en producción. El administrador siempre decide cuándo aplicar un update. La excepción son las Fichas de Sistema Tipo 1, que el IAM Installer aplica automáticamente en cada arranque.

---

## 20. Observación Integral de Salud — SO → Kubernetes → Fichas

> **Esta sección es nueva en v6.0.** Formaliza la responsabilidad del IAM Installer como observador, administrador y reparador de la salud de toda la cadena operativa.

### 20.1 El principio

El IAM Installer no solo vigila las aplicaciones (fichas). Observa y administra la salud de toda la cadena operativa: sistema operativo → Kubernetes → fichas. Esta jurisdicción integral es una consecuencia lógica de su posición arquitectónica: si el sistema operativo no está saludable, Kubernetes no puede operar. Si Kubernetes falla, las fichas no pueden existir. El IAM Installer vive como servicio systemd por encima de Kubernetes — es el único componente que puede diagnosticar, reparar y reconstruir cada nivel de la pila.

### 20.2 Niveles de observación

```
NIVEL 1 — SISTEMA OPERATIVO (Ubuntu)
  │
  ├── Estado del kernel y servicios systemd críticos
  ├── Espacio en disco, memoria, CPU del host
  ├── Estado de networking del host
  ├── Estado de CRI-O / container runtime
  └── Actualizaciones de seguridad pendientes del OS
  │
  ▼
NIVEL 2 — KUBERNETES
  │
  ├── Estado del API Server, etcd, controller-manager, scheduler
  ├── Estado de los nodos (Ready / NotReady / SchedulingDisabled)
  ├── Certificados del cluster (expiración, rotación)
  ├── Estado de networking del cluster (CNI, CoreDNS)
  └── Capacidad de recursos (CPU/RAM/Storage requests vs limits)
  │
  ▼
NIVEL 3 — FICHAS (Aplicaciones)
  │
  ├── health.check_command de cada ficha (ok / degraded / error / pending)
  ├── Drift de configuración (hashes SHA-256 actual vs declarado)
  ├── Estado de dependencias entre fichas (grafo DAG)
  ├── Versiones instaladas vs versiones disponibles
  └── Integración con servicios compartidos (Keycloak, Kong, Vault)
```

### 20.3 Comportamiento ante fallos en cada nivel

| Nivel | Fallo detectado | Acción del IAM Installer |
|---|---|---|
| **SO** | Servicio systemd crítico caído | Intenta reinicio. Si falla, notifica al admin con CAUSA + SOLUCIÓN |
| **SO** | Espacio en disco < umbral | Alerta en Core UI + intento de cleanup de recursos temporales |
| **SO** | CRI-O no responde | Diagnóstico + intento de repair del container runtime |
| **K8s** | API Server no responde | Diagnóstico del cluster. Si es recuperable, intenta reparación. Si no, reporta con instrucciones de reconstrucción |
| **K8s** | Nodo en NotReady | Identifica causa (kubelet, networking, recursos). Intenta repair automático si es safe |
| **K8s** | Certificados próximos a expirar | Alerta proactiva + ejecución de rotación si está configurado |
| **Fichas** | health_check → degraded | Intenta repair si `auto_repair: true` en manifest |
| **Fichas** | health_check → error | Notifica con diagnóstico completo. Espera confirmación humana para repair invasivo |
| **Fichas** | Drift detectado | Marca `ACTUALIZACION_DISPONIBLE`. Admin decide cuándo aplicar |

### 20.4 ¿Por qué el IAM Installer y no Kubernetes?

Kubernetes tiene self-healing a nivel de pods: si un pod muere, el Deployment lo reinicia. Pero Kubernetes NO puede:

- Repararse a sí mismo si etcd se corrompe o el API Server falla
- Diagnosticar problemas del sistema operativo que le afectan (disco, red, kernel)
- Reconciliar configuraciones de aplicaciones que van más allá del manifiesto K8s (integraciones con Keycloak, reglas en Kong, secrets en Vault)
- Gestionar el ciclo de vida completo de una ficha (pre_install → install → post_install → health con dependencias entre fichas)

El IAM Installer llena exactamente esa brecha: es el guardián que vigila todo lo que Kubernetes no puede vigilar sobre sí mismo ni sobre el entorno que lo sustenta.

---

## 21. Operaciones Destructivas y Governance Dual-Control

> **Esta sección es nueva en v6.0.** Formaliza la clasificación de operaciones destructivas y el protocolo de governance.

### 21.1 Definición de operación destructiva

Una operación destructiva es cualquier acción que pueda:

1. **Desinstalar una aplicación** — eliminar pods, PVCs, secrets, ConfigMaps, NetworkPolicies de una ficha
2. **Ejecutar reparaciones invasivas** — acciones que afecten a otros contenedores, modifiquen recursos compartidos, o puedan hacer caer servicios dependientes
3. **Modificar el estado del cluster Kubernetes** — escalar a cero, drenar nodos, eliminar namespaces

### 21.2 Protocolo de governance dual-control

```
Administrador solicita operación destructiva (remove / repair invasivo)
  │
  ▼
Core UI muestra diagnóstico completo:
  ├── Qué se va a eliminar / modificar (lista explícita de recursos)
  ├── Qué servicios pueden verse afectados (dependencias del grafo DAG)
  ├── Estado actual de la ficha y de sus dependientes
  └── Recomendación: proceder / esperar / alternativa menos destructiva
  │
  ▼
¿Ficha con criticality: true?
  │
  ├── SÍ → Paso obligatorio: diagnosis_first: true
  │         El sistema diagnostica completamente ANTES de cualquier acción
  │         Reporte presentado al administrador
  │         Segunda confirmación requerida después de ver el diagnóstico
  │
  └── NO → Confirmación simple + governance check
  │
  ▼
¿Operación es remove?
  │
  ├── SÍ → Backup obligatorio previo (take_backup_snapshot)
  │         Backup verificado antes de proceder
  │
  └── NO (repair) → Si auto_repair: false, espera confirmación
  │
  ▼
Ejecución con Saga compensatoria
  ├── Cada paso tiene su transacción inversa definida
  ├── Si falla un paso → compensación en orden inverso
  └── STATE_MANAGER registra todo el proceso para auditoría
```

### 21.3 La auto-eliminación como invariante de seguridad

El IAM Installer no puede desinstalarse a sí mismo. Esta restricción no es una limitación técnica — es una invariante de seguridad deliberada. Si el control plane pudiera ejecutar su propia desinstalación, un error administrativo eliminaría el guardián del servidor, un ataque de escalamiento de privilegios podría eliminar silenciosamente la supervisión, o una secuencia de compensación incorrecta podría incluir la auto-eliminación como paso.

---

## 22. La Frontera Binario ↔ Script: Por qué task_catalog.sh es Bash

> **Esta sección es nueva en v6.0.** Documenta la decisión de arquitectura sobre por qué los catálogos de tareas de las fichas permanecen en Bash y no migran a binario compilado.

### 22.1 La decisión

El `task_catalog.sh` de cada ficha es y permanecerá **Bash (.sh)**. El daemon principal (`bos`) es y permanecerá **binario Go compilado**. Esta frontera es invariable y no es una deuda técnica — es una decisión de ingeniería deliberada.

### 22.2 Fundamento operativo

Las aplicaciones del stack generan errores de configuración en producción con frecuencia. Las causas son diversas: cambios en dependencias externas, actualizaciones de versiones de las apps, configuraciones específicas por cliente, integraciones con servicios que cambian su API, y estados del cluster que no se anticiparon en desarrollo.

Cuando un error de configuración ocurre, el administrador o el equipo de soporte necesita **agregar, eliminar o modificar tareas en el acto** para que el instalador pueda gestionar la situación y levantar el servicio de manera profesional. Esto significa:

**Con Bash (.sh) — el flujo de corrección:**
```
1. Editar task_catalog.sh  (nano/vim — 30 segundos)
2. Guardar
3. El daemon absorbe los cambios en el siguiente ciclo (source task_catalog.sh)
4. Servicio reparado
```

**Con binario compilado (.so) — el flujo de corrección:**
```
1. Editar código fuente Go/Rust
2. Compilar el binario (.so) en entorno de desarrollo
3. Transferir el binario al servidor de producción
4. Registrar el nuevo binario en el sistema
5. Reiniciar o recargar el daemon
6. Verificar que la firma criptográfica es válida
7. Servicio reparado
```

La diferencia es evidente: un proceso de 30 segundos versus un proceso de varios minutos que requiere acceso al entorno de compilación. En una emergencia de producción, esta diferencia determina si el servicio se restaura en minutos o en horas.

### 22.3 La frontera arquitectónica

```
┌──────────────────────────────────────────────────────────────────┐
│  BINARIO GO COMPILADO (daemon bos)                               │
│                                                                   │
│  ├── Arranque del daemon                                         │
│  ├── API REST / WebSocket                                        │
│  ├── Loop de reconciliación                                      │
│  ├── Comunicación con SKULL Release Plane                        │
│  ├── Verificación Ed25519 / SHA-256                              │
│  ├── Gestión de estado (.sbos_state.json)                        │
│  └── Orquestación de módulos Python                              │
│                                                                   │
│  CONSUME ──▶ EJECUTA ──▶ DESACOPLA                               │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  BASH SCRIPTS (fichas — task_catalog.sh)                    │  │
│  │                                                             │  │
│  │  ├── Funciones específicas por aplicación                   │  │
│  │  │   _task_postgresql_create_database()                     │  │
│  │  │   _task_keycloak_import_realm()                          │  │
│  │  │   _task_mailserver_configure_dkim()                      │  │
│  │  │                                                          │  │
│  │  ├── Editables en producción sin compilar                   │  │
│  │  ├── Absorbidos por source en cada ejecución                │  │
│  │  ├── Liberados por unset -f al terminar (P7)                │  │
│  │  └── Validados por validate_sp02.py antes de release        │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

### 22.4 Implicaciones para el agente de IA que desarrolle la aplicación

Un agente de IA que desarrolle el IAM Installer debe respetar esta frontera:

1. **El daemon `bos`** se desarrolla en Go. Se compila como binario estático. Se firma con Ed25519. Se distribuye via SKULL Release Plane.
2. **Los `task_catalog.sh` de las fichas** se desarrollan en Bash. Se validan con `validate_sp02.py`. Se distribuyen como archivos de texto plano dentro del paquete de cada ficha.
3. **El daemon nunca modifica un task_catalog.sh** — solo lo absorbe (source), ejecuta sus funciones, y las libera (unset -f).
4. **Un task_catalog.sh nunca llama directamente a kubectl** — eso lo hace `sbos_k8s_core()` en el Core (P1).
5. **Las funciones de un task_catalog.sh siempre terminan con `export -f`** (P6) para estar disponibles en subshells.

### 22.5 Roadmap: Bash → Go para el Core, Bash permanente para fichas

El roadmap de migración Bash → Go aplica **solo al Core del daemon** (los 4 archivos maestros `00_*.sh`), no a los task_catalog.sh de las fichas. El criterio de completitud es: `grep -r "#!/bin/bash" /opt/bos/` retorna 0 — lo cual se refiere a los scripts del Core, no a los de las fichas que viven en `/etc/bos/blibs/servers/`.

---

## 23. Posicionamiento frente al Ecosistema de la Industria

> **Esta sección es nueva en v6.0.**

| Capacidad | Terraform | ArgoCD | K8s Operators | Crossplane | SBOS IAM Installer |
|---|---|---|---|---|---|
| Aprovisionamiento Day 0 (SO + K8s) | ❌ | ❌ | ❌ | ❌ | ✅ |
| Aprovisionamiento Day 1 (Apps) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Reconciliación continua Day 2 | ❌ (plan/apply) | ✅ | ✅ | ✅ | ✅ |
| Self-healing SO + K8s + Apps | ❌ | ❌ | Parcial (apps) | ❌ | ✅ |
| Cadena de custodia criptográfica | Parcial | Parcial | ❌ | ❌ | ✅ (Ed25519 + SLSA) |
| Gestión de flota distribuida | ❌ | ❌ | ❌ | ❌ | ✅ (SKULL Release Plane) |
| Operación offline completa | ❌ | ❌ | ✅ | ❌ | ✅ |
| Governance dual-control | ❌ | ✅ (sync manual) | ❌ | ❌ | ✅ (diagnosis_first + backup) |
| Rollback automático del daemon | ❌ | ❌ | ❌ | ❌ | ✅ (watchdog + custodia) |
| Sagas con compensación | ❌ | ❌ | ❌ | ❌ | ✅ (INSTALL_RUNNER) |
| Soberanía total sin cloud | ❌ | ❌ | Parcial | ❌ | ✅ |
| Fichas editables en producción | N/A | N/A | ❌ (requiere rebuild) | ❌ | ✅ (task_catalog.sh) |

**La contribución original del SBOS:** ningún sistema del mercado combina en una única pieza de software: governance dual-control + soberanía total + distribución pull-only con firma Ed25519 + rollout escalonado con criterios de halt + rollback automático + operación offline + Sagas con compensación + separación dominio/orquestación + fichas editables en producción sin recompilación + observación integral SO → K8s → Fichas. Esta combinación es la respuesta al stack empresarial soberano iberoamericano y no existe como patrón estándar en la industria.

---

## 24. Los 15 Principios de Arquitectura

Los principios P son restricciones de arquitectura que se aplican a todo el código del Core y de las fichas. No son sugerencias — son invariantes. Cada principio tiene una consecuencia concreta si se viola.

| # | Principio | Restricción | Consecuencia de violación |
|---|---|---|---|
| P1 | Punto único de kubectl | Solo `sbos_k8s_core()` llama `kubectl apply` | El STATE_MANAGER pierde trazabilidad de despliegues |
| P2 | Declarativo sobre imperativo | Las fases van en `yaml_engine.yml`, no en scripts ad-hoc | El sistema no puede reproducir ni auditar la instalación |
| P3 | Funciones globales agnósticas | `00_TASK_CATALOG_SBOS.sh` nunca menciona apps concretas | El Core se acopla a apps específicas y pierde extensibilidad |
| P4 | Idempotencia obligatoria | Toda función `_task_*()` verifica si ya está aplicada antes de actuar | Reinstalaciones y repairs producen estados inconsistentes |
| P5 | Streaming de señales | `PROCESS_MANAGER` parsea stdout línea a línea, nunca acumula | Operaciones largas bloquean el UI hasta terminar |
| P6 | Export obligatorio | Toda función en `task_catalog.sh` termina con `export -f` | Las funciones no están disponibles en subshells del YAML Engine |
| P7 | Absorber/Ejecutar/Liberar | Las funciones específicas se cargan y liberan por ficha | Funciones de distintas fichas colisionan en memoria |
| P8 | Estado centralizado | Solo `STATE_MANAGER` escribe `.sbos_state.json` | Condiciones de carrera y estado corrupto |
| P9 | Dry-run antes de apply | `kubectl apply` siempre con `--dry-run=client` en validación | Manifests inválidos aplicados producen errores difíciles de revertir |
| P10 | Secrets vía Vault | Ningún secret se hardcodea en archivos de la ficha | Credenciales expuestas en el repositorio |
| P11 | NetworkPolicy por ficha | Toda ficha de aplicación tiene su `<app>.network` | Apps que pueden hablar con cualquier pod del cluster |
| P12 | Backup antes de repair | `take_backup_snapshot` antes de repair en `criticality: true` | Datos perdidos en reparaciones fallidas |
| P13 | Logging vía LOGGER | Todo output de diagnóstico usa `LOGGER.py`, no `print()` | Logs inconsistentes, sin nivel, sin trazabilidad |
| P14 | Diagnosis antes de repair | `diagnosis_first: true` en fichas críticas antes de acciones correctivas | Reparaciones que empeoran el estado del sistema |
| P15 | Pull-only para actualizaciones | El IAM Installer nunca acepta conexiones entrantes del SKULL Release Plane. Toda comunicación es iniciada por el cliente (GET). | Pérdida de la soberanía del cliente. Sin excepciones operacionales. |

---

## 25. Relación con el Ecosistema de Patrones

El IAM Installer no es una reimplementación de ArgoCD ni de un Kubernetes Operator. Es un control plane diseñado para el caso de uso específico del SBOS soberano, con la dimensión adicional de gestión de flota distribuida.

| Patrón | Lo que adopta el IAM Installer | Lo que no adopta |
|---|---|---|
| **Kubernetes Controller** | Loop de reconciliación continua. Comparación desired/actual state | No requiere CRDs ni extensión de la API de K8s |
| **GitOps / ArgoCD** | `servers/` como fuente de verdad declarativa. Detección de drift. App-of-Apps como catálogo | No sincroniza automáticamente en producción — confirmación humana |
| **Operator Pattern** | Conocimiento operacional codificado en cada ficha. Ciclo de vida completo Day 1 + Day 2 | No escribe controladores en Go — usa contratos declarativos + Bash |
| **Backstage / IDP** | Catálogo de aplicaciones como fuente de verdad. Single pane of glass para todo el stack | No es multi-tenant ni requiere infraestructura de portal externa |
| **SRE Runbooks** | Runbooks automatizados en `task_catalog.sh`. CAUSA + SOLUCIÓN accionable en cada error | No son runbooks manuales — son código ejecutable con SBOS-DOC |
| **Elastic Agent Fleet / Datadog Fleet** | Distribución centralizada de actualizaciones a agentes en múltiples hosts. Rollout por fases. Verificación de integridad. Política configurable | No transmite datos del cliente al servidor central — solo recibe actualizaciones (pull-only) |
| **HashiCorp Agent pattern** | Binario único sin dependencias. Distribución por HTTPS. Verificación SHA-256. Instalación con un comando | No usa Consul catalog ni Vault agent injection |
| **Kubernetes kubelet** | Agente residente en el nodo. Auto-actualización con rollback. Reconciliación permanente del estado | No depende de API Server de K8s — es el control plane mismo, no un agente de nodo |
| **Mender / OTA update systems** | Rollback automático tras fallo de estabilización. Periodo de watchdog post-actualización. Custodia de versión anterior | No usa partición A/B del filesystem — opera en nivel de proceso, no de sistema de archivos |
| **Saga Pattern (Temporal.io / Argo Workflows)** | Sagas orquestadas con transacciones compensatorias. Separación dominio/orquestación. Vocabulario estándar de compensación | No usa un motor de workflows externo — el orquestador de Sagas es INSTALL_RUNNER.py, soberano y sin dependencias externas |
| **Infrastructure Lifecycle Management (HashiCorp)** | Ciclo completo: provisionar, validar, desplegar, monitorear, optimizar, retirar. Infraestructura como código. Drift detection + auto-remediation | No requiere conectividad cloud. Abarca Day 0 (SO + K8s bootstrap) que HashiCorp no cubre. No depende de Terraform ni HCP |
| **Crossplane (CNCF)** | Reconciliación GitOps para infraestructura. Kubernetes-native. Control plane declarativo | No opera offline. No incluye self-healing del SO. No tiene governance dual-control para destructivas. No gestiona flota distribuida soberana |

**La contribución original de SBOS:** ningún sistema del mercado combina en una única pieza de software: governance dual-control con confirmación humana para operaciones destructivas + soberanía total sin dependencias cloud + distribución pull-only con firma criptográfica Ed25519 a flota distribuida + rollout escalonado por canales con criterios formales de halt + rollback automático del daemon + operación offline completa del control plane local + conocimiento operacional codificado en fichas + Sagas con compensación en la orquestación de instalación + separación explícita dominio/orquestación + extensibilidad sin modificar el Core. Esta combinación es la respuesta al stack empresarial soberano iberoamericano y no existe como patrón estándar en la industria.

---

## 26. Registro de Cambios

### v6.0 — Marzo 2026 (este documento)

**Cambio de nombre conceptual:** De "Application & Process Orchestrator" a **"Infrastructure Provisioning & Lifecycle Orchestrator"** para reflejar con precisión el alcance completo, incluyendo el bootstrap del SO y Kubernetes como acto fundacional.

**Decisión de arquitectura — task_catalog.sh permanece en Bash:** Se elimina la discrepancia documentada en v5.0 que sugería migrar los task_catalog de fichas a binario compilado (.so). La decisión es definitiva: los task_catalog.sh de fichas permanecen en Bash por razones operativas (corrección inmediata en producción sin recompilación). Solo el Core del daemon migra de Bash a Go.

**Nuevas secciones:**

**§1 — Definición Ejecutiva:** Sección de alto nivel para stakeholders no técnicos y para contexto de un agente de IA que desarrolle la aplicación. Incluye: definición conceptual como "motor de aprovisionamiento y gestión del ciclo de vida", capacidades (aprovisionamiento, lifecycle management, self-healing, verificación de integridad, rollback), restricciones (auto-eliminación, operaciones destructivas, lógica de negocio), y justificación estratégica. Enriquecido con investigación: HashiCorp ILM, Chainguard reconciliation principles, SLSA framework.

**§20 — Observación Integral de Salud (SO → K8s → Fichas):** Formaliza la responsabilidad como observador, administrador y reparador de los tres niveles de la cadena operativa. Incluye: diagrama de niveles, tabla de comportamiento ante fallos, justificación vs Kubernetes.

**§21 — Operaciones Destructivas y Governance Dual-Control:** Clasificación formal de operaciones destructivas (desinstalación, reparaciones invasivas, modificaciones del cluster). Protocolo de governance con diagnosis_first, backup obligatorio, y confirmación humana. Invariante de auto-eliminación.

**§22 — La Frontera Binario ↔ Script:** Documenta la decisión de que task_catalog.sh permanece en Bash. Incluye: fundamento operativo con comparación de flujos de corrección (30 segundos vs minutos), diagrama de la frontera arquitectónica binario/script, e implicaciones para un agente de IA desarrollador.

**§23 — Posicionamiento frente a la Industria:** Tabla comparativa formal vs Terraform, ArgoCD, K8s Operators, Crossplane. Declaración de contribución original del SBOS.

**Correcciones en v6.0:**

- Tabla de metadatos: `task_catalog.go` corregido a `task_catalog.sh`
- §2b: "task_catalog.so módulos Python compilados (Cython)" corregido a "task_catalog.sh scripts Bash editables en producción"
- §15.3: Estructura de archivos corregida de `task_catalog.so` a `task_catalog.sh`
- Eliminada la nota de discrepancia ⚠️ que sugería migrar a .so — reemplazada por decisión de arquitectura fundamentada
- Roadmap Bash→Go clarificado: aplica solo al Core, no a las fichas

**Actualizaciones en v6.0:**

- §2: Añadida subsección "El bootstrap como acto fundacional" — reconoce el aprovisionamiento Day 0 como proceso crítico y primordial. Documenta la división del bootstrap monolítico en fichas separadas que se intercalan con fichas de aplicación.
- §2: Añadida subsección "Tres niveles de operación: Ficha, Producto, Deploy" — define la jerarquía de abstracción del instalador con referencias a SBOS-032-PRODUCTS y SBOS-033-DEPLOY.
- §2: Añadida referencia a Infrastructure Lifecycle Management (HashiCorp) en la genealogía del diseño.
- §15.4: CLI `bosctl` ampliado con comandos de ciclo de vida (`install`, `update`, `repair`, `remove`), comandos de productos (`product install/status/verify`), y comando de despliegue (`deploy`). Añadido principio de equivalencia CLI ↔ Core UI.
- §16: Ciclo de Vida Completo reescrito en dos subsecciones: §16.1 Primera instalación (desde Ubuntu virgen) con el grafo completo de 16 fichas, y §16.2 Operación normal (sistema ya instalado) con los loops de reconciliación.
- §25: Tabla de patrones ampliada con Infrastructure Lifecycle Management (HashiCorp) y Crossplane (CNCF).

### v5.0 — Marzo 2026 (este documento)

**Nuevas secciones:**

**§4 — Capas de Responsabilidad de los Módulos Python:** clasificación explícita de los 16 módulos en Capa de Dominio vs Capa de Orquestación con justificación por módulo. Introducción del vocabulario Saga (Temporal.io, Argo Workflows): transacciones locales, transacciones compensatorias, orquestador de Sagas. Tabla de Sagas del IAM Installer con pasos y compensaciones. Esta sección resuelve la brecha de la Capa 4 del modelo enterprise.

**§10.3 — Criterios Formales de Halt del Rollout:** tabla explícita con 4 criterios (P0, P1×2, latencia, error rate), definición precisa de HALT vs HOLD, y el proceso de comunicación a la flota. Elimina la ambigüedad de criterios implícitos de la v4.1.

**§13 — Pipeline CI/CD con Validador como Paso Obligatorio:** `validate_sp01.py` y `validate_sp02.py` integrados como pasos obligatorios del `make release`. El pipeline no publica si cualquier validador retorna exit ≠ 0. Flujo completo de 7 pasos documentado.

**Correcciones y actualizaciones en v5.0:**

- §6: Tabla de módulos actualizada con columna "Capa" y descripción de INSTALL_RUNNER como orquestador de Sagas.
- §20: Tabla de patrones añade Saga Pattern (Temporal.io / Argo Workflows) con su diferenciación.
- Numeración del documento actualizada por inserción de §4 y reorganización de secciones.

### v4.1 — Marzo 2026

**Brechas de producción cubiertas:**

**§5 (v4.1) — Seguridad del Canal de Distribución:** especificación completa del modelo de firma criptográfica Ed25519. Cadena de confianza: firma sobre archivo de checksums → checksums verifican binarios. Clave privada en vault sellado con acceso por quórum. Clave pública compilada en el binario del instalador. Proceso de rotación de claves.

**§6 (v4.1) — Estrategia de Rollout por Fases:** definición de tres canales de rollout (`canary`, `early`, `stable`) con su población, propósito, y secuencia temporal. SKULL Admin Fleet Dashboard con control de ondas.

**§8 (v4.1) — Rollback Automático del Daemon:** patrón watchdog + versión en custodia. Criterios de estabilización (5 criterios). Proceso de rollback automático y manual. `ExecStartPost` en la unidad systemd.

**§9 (v4.1) — Modo Degradado:** principio de independencia del control plane local. Tabla de comportamiento por módulo. Banner de advertencia en Core UI.

### v4.0 — Marzo 2026

Reescritura estructural: arquitectura de distribución soberana a flota de clientes establecida como columna vertebral. Nuevas secciones: Arquitectura de Tres Planos, SKULL Release Plane, IAM Installer como Daemon Residente. Módulo `RELEASE_MANAGER.py` añadido. Principio P15 (pull-only) añadido.

---

### Roadmap: Bash → Binario Soberano Go (solo Core)

El Core del IAM Installer (los 4 archivos maestros `00_*.sh`) migra de Bash+Python a un único binario Go compilado. Los `task_catalog.sh` de las fichas **NO migran** — permanecen en Bash por decisión de arquitectura (§22).
Comandos OS atómicos (`kubectl`, `systemctl`) se invocan desde Go via
`exec.Command()` con verificación explícita — nunca scripts multi-línea autónomos.
Criterio de completitud: `grep -r "#!/bin/bash" /opt/bos/` retorna 0 (excluye `/etc/bos/blibs/servers/` donde viven los task_catalog.sh de fichas).

---

*SKULL · SBOS · SBOS-005-INSTALLER · v7.0 · Marzo 2026 — Integración de especificación interna*

> **Referencias:** Kubernetes Controller Pattern — CoreOS/Red Hat (2016) · CNCF Controller documentation · ArgoCD App-of-Apps Pattern — Argo Project (CNCF graduated) · GitOps principles — WeaveWorks · Kubernetes Operator Pattern — Red Hat/OperatorHub · Backstage Internal Developer Portal — Spotify (2016) → CNCF Incubating (2022) · SRE Runbook automation — Google SRE Book · Platform Engineering Golden Paths — Spotify, Netflix · Elastic Agent Fleet Management — Elastic · Datadog Agent Fleet — Datadog · Kubernetes kubelet architecture — CNCF · HashiCorp agent distribution model — HashiCorp · systemd service hardening — freedesktop.org · Ed25519 signature scheme — RFC 8032 · Mender OTA update system — Northern.tech · Sigstore/cosign artifact signing — CNCF · Software supply chain security — SLSA framework (Google) · Saga Pattern — Hector Garcia-Molina, Kenneth Salem (1987) · Temporal.io Saga implementation · Argo Workflows compensating transactions · Infrastructure Lifecycle Management — HashiCorp (2024) · Crossplane — CNCF (2024) · Chainguard Reconciliation Principles · Spacelift Approval Policies · Sovereign Infrastructure — rack2cloud (2025) · Firefly Infrastructure Orchestration (2025)

---

## 27. Especificación Interna del Daemon — Nivel de Código

> **Integrado desde SBOS-005-001 en v7.0.** Este contenido estaba en un anexo separado y ha sido fusionado en el documento base para mantener la autocontención.


### 1.1 Schema completo

```json
{
  "$schema": "sbos-state-v1",
  "version": "1.0",
  "updated_at": "2026-03-14T10:30:00Z",

  "system": {
    "installer_version": "0.9.3",
    "installer_channel": "canary",
    "os": "Ubuntu 24.04 LTS",
    "arch": "amd64",
    "hostname": "sbos-prod-01",
    "kubernetes_version": "1.31.2",
    "cluster_id": "uuid",
    "bootstrap_completed_at": "2026-03-14T09:00:00Z",
    "last_health_check": "2026-03-14T10:29:00Z",
    "last_reconcile": "2026-03-14T10:25:00Z"
  },

  "fichas": {
    "postgresql": {
      "status": "INSTALADA_OK",
      "version": "18.0",
      "server": "dataserver",
      "installed_at": "2026-03-14T09:12:00Z",
      "updated_at": "2026-03-14T09:12:00Z",
      "health": {
        "result": "ok",
        "last_check": "2026-03-14T10:29:00Z",
        "consecutive_failures": 0,
        "details": "All pods running, replication OK"
      },
      "hashes": {
        "manifest": "sha256:abc123...",
        "yaml_engine": "sha256:def456...",
        "task_catalog": "sha256:ghi789...",
        "resources": "sha256:jkl012..."
      },
      "execution_order": 100,
      "depends_on": ["sbos-bootstrap-platform"],
      "governance_category": 2
    },
    "keycloak": {
      "status": "INSTALADA_OK",
      "version": "26.1",
      "server": "identityserver",
      "installed_at": "2026-03-14T09:20:00Z",
      "updated_at": "2026-03-14T09:20:00Z",
      "health": { "result": "ok", "last_check": "2026-03-14T10:29:00Z", "consecutive_failures": 0 },
      "hashes": { "manifest": "sha256:...", "yaml_engine": "sha256:...", "task_catalog": "sha256:...", "resources": "sha256:..." },
      "execution_order": 130,
      "depends_on": ["postgresql", "vault"],
      "governance_category": 3
    },
    "mailserver": {
      "status": "NO_INSTALADA",
      "version": null,
      "server": "commsserver",
      "installed_at": null,
      "health": null,
      "hashes": null,
      "execution_order": 200,
      "depends_on": ["postgresql", "keycloak"],
      "governance_category": 1
    }
  },

  "products": {
    "bootstrap": {
      "status": "INSTALADO",
      "version": "1.0",
      "installed_at": "2026-03-14T09:48:00Z",
      "fichas": ["sbos-bootstrap-os", "sbos-bootstrap-k8s", "sbos-bootstrap-platform", "sbos-k8s-network-validator", "postgresql", "redis", "minio", "vault", "keycloak", "nginx", "kong", "linkerd", "kyverno", "prometheus", "grafana", "sbos-bootstrap-hardening"]
    },
    "mail": {
      "status": "NO_INSTALADO",
      "version": null,
      "installed_at": null,
      "fichas": []
    }
  },

  "deploy": {
    "deploy_id": "uuid",
    "seed_file": "/etc/bos/deploy/skull-empresa.deploy.yml",
    "tenant_name": "SKULL S.R.L.",
    "domain": "skull.io",
    "started_at": "2026-03-14T09:00:00Z",
    "completed_at": "2026-03-14T10:07:00Z",
    "products_requested": ["bootstrap", "mail", "erp"],
    "products_completed": ["bootstrap"],
    "products_pending": ["mail", "erp"]
  },

  "operations": {
    "active": null,
    "history": [
      {
        "operation_id": "uuid",
        "type": "install",
        "ficha_id": "postgresql",
        "status": "success",
        "started_at": "2026-03-14T09:12:00Z",
        "completed_at": "2026-03-14T09:14:30Z",
        "duration_ms": 150000,
        "admin_sub": "admin@skull.io",
        "steps_total": 12,
        "steps_completed": 12,
        "compensation_executed": false
      }
    ]
  },

  "release": {
    "current_version": "0.9.3",
    "prev_version": "0.9.2",
    "channel": "canary",
    "last_check": "2026-03-14T08:00:00Z",
    "next_check": "2026-03-14T14:00:00Z",
    "pending_stabilization": false,
    "stabilization_deadline": null
  }
}
```

### 1.2 Transiciones de estado válidas

`STATE_MANAGER` rechaza cualquier transición que no esté en esta tabla:

```
NO_INSTALADA     → INSTALANDO        (INSTALL_RUNNER inicia install)
INSTALANDO       → INSTALADA_OK      (INSTALL_RUNNER: todos los pasos OK)
INSTALANDO       → NO_INSTALADA      (INSTALL_RUNNER: compensación ejecutada)
INSTALADA_OK     → ACTUALIZANDO      (INSTALL_RUNNER inicia update)
INSTALADA_OK     → REPARANDO         (INSTALL_RUNNER inicia repair)
INSTALADA_OK     → DESINSTALANDO     (INSTALL_RUNNER inicia uninstall)
INSTALADA_OK     → ALERTA            (HEALTH_CHECKER: health check falla)
ALERTA           → INSTALADA_OK      (HEALTH_CHECKER: health check pasa)
ALERTA           → REPARANDO         (INSTALL_RUNNER inicia repair)
ACTUALIZANDO     → INSTALADA_OK      (INSTALL_RUNNER: update completo)
ACTUALIZANDO     → ALERTA            (INSTALL_RUNNER: update falló, rollback no posible)
ACTUALIZANDO     → INSTALADA_OK      (INSTALL_RUNNER: update falló, rollback exitoso → versión anterior)
REPARANDO        → INSTALADA_OK      (INSTALL_RUNNER: repair exitoso)
REPARANDO        → ALERTA            (INSTALL_RUNNER: repair falló)
DESINSTALANDO    → NO_INSTALADA      (INSTALL_RUNNER: uninstall completo)
DESINSTALANDO    → INSTALADA_OK      (INSTALL_RUNNER: uninstall falló, compensación restauró)
BLOQUEADA        → NO_INSTALADA      (DEPENDENCY_RESOLVER: dependencias ahora satisfechas)
NO_INSTALADA     → BLOQUEADA         (DEPENDENCY_RESOLVER: dependencias ya no satisfechas)
```

Cualquier transición fuera de esta tabla es un **bug**. `STATE_MANAGER` la rechaza, logea un error crítico, y emite un evento `system_alert` con severidad `critical`.

### 1.3 Concurrencia y locks

```
STATE_MANAGER usa fcntl.flock(LOCK_EX) en .sbos_state.json
  │
  ├── Lock adquirido → lee, muta, escribe, libera
  ├── Lock no disponible (otro módulo escribiendo) → espera hasta 5 segundos
  └── Timeout → error "state_lock_timeout", la operación falla
  
Solo UNA operación puede estar activa a la vez (operations.active != null).
Si un módulo intenta iniciar una operación mientras hay una activa,
STATE_MANAGER rechaza con "operation_in_progress".
```

---

## 2. Protocolo `bosctl` ↔ Daemon

### 2.1 Mecanismo de comunicación

`bosctl` se comunica con el daemon `bos` mediante **HTTP sobre Unix socket**.

```
Socket: /run/bos/bos.sock
Protocolo: HTTP/1.1 sobre Unix domain socket
Autenticación: El socket tiene permisos 0660, grupo bosagent.
               Solo root y usuarios del grupo bosagent pueden conectar.
               No se necesita JWT (la autenticación es a nivel de OS).
```

Esto es diferente del Core UI, que se conecta por TCP con JWT de Keycloak. `bosctl` es local y privilegiado — no necesita autenticación de red.

### 2.2 Endpoints internos (solo bosctl, no expuestos por TCP)

Estos endpoints solo son accesibles por Unix socket, no por la API REST TCP que consume el Core UI:

```
GET  /internal/state              → dump completo de .sbos_state.json
GET  /internal/state/fichas       → solo la sección fichas
GET  /internal/state/products     → solo la sección products
GET  /internal/config             → configuración actual de bos.toml
POST /internal/reconcile          → forzar reconciliación inmediata
POST /internal/health-check       → forzar health check de todas las fichas
GET  /internal/logs/{ficha_id}    → últimas N líneas de log de una ficha
GET  /internal/version            → versión del daemon + uptime + estado
```

### 2.3 Comandos de bosctl y su mapeo a endpoints

```bash
# ─── Fichas ───
bosctl status                    → GET /api/dashboard
bosctl fichas                    → GET /api/fichas
bosctl ficha <id>                → GET /api/fichas/{id}
bosctl install <id>              → POST /api/fichas/{id}/install {"confirmed":true}
bosctl install <id> --dry-run    → POST /api/fichas/{id}/probe
bosctl repair <id>               → POST /api/fichas/{id}/repair {"confirmed":true}
bosctl update <id>               → POST /api/fichas/{id}/update {"confirmed":true}
bosctl uninstall <id>            → POST /api/fichas/{id}/uninstall (requiere --confirm=DESINSTALAR-<ID>)
bosctl logs <id>                 → GET /internal/logs/{id}

# ─── Productos ───
bosctl product list              → GET /api/products
bosctl product install <nombre>  → POST /api/products/{nombre}/install
bosctl product status <nombre>   → GET /api/products/{nombre}
bosctl product verify <nombre>   → POST /api/products/{nombre}/verify

# ─── Deploy ───
bosctl deploy <archivo.yml>      → POST /api/deploy {"seed_file":"<path>"}
bosctl deploy status             → GET /api/deploy/status

# ─── Sistema ───
bosctl health                    → GET /api/health
bosctl health --wait-stable=60   → GET /api/health (polling cada 5s hasta stable o timeout)
bosctl version                   → GET /internal/version
bosctl state                     → GET /internal/state
bosctl reconcile                 → POST /internal/reconcile
bosctl config                    → GET /internal/config
```

### 2.4 Formato de output del CLI

```bash
# bosctl status (tabla compacta)
SBOS IAM Installer v0.9.3 · canary · uptime 6h 32m
Cluster: sbos-prod-01 · K8s 1.31.2 · 1 nodo · OK

FICHAS (22 instaladas / 3 en alerta / 96 totales)
────────────────────────────────────────────────────
ID               VERSIÓN  ESTADO        HEALTH  SERVER
postgresql       18.0     INSTALADA_OK  ok      dataserver
keycloak         26.1     INSTALADA_OK  ok      identityserver
mailserver       3.2.1    ALERTA        error   commsserver

# bosctl install postgresql (progreso en tiempo real)
[bos] Instalando postgresql v18.0...
[✓] 1/12  Verificar dependencias                    0.1s
[✓] 2/12  Crear namespace sbos-data                 0.2s
[⟳] 3/12  Crear PVC 500GB...                        (12s)
[✓] 3/12  PVC creado y bound                        14.3s
...
[✓] 12/12 Health check: todos los pods running      2.1s

═══ postgresql instalado en 2m 30s ═══
```

### 2.5 Exit codes

```
0   → operación exitosa
1   → error genérico
2   → error de validación (parámetros incorrectos)
3   → ficha no encontrada
4   → operación rechazada (ya hay una activa)
5   → dependencias no satisfechas
6   → daemon no disponible (socket no existe o no responde)
7   → timeout (operación no completó en tiempo esperado)
8   → error de gobernanza (requiere aprobación dual)
10  → error interno del daemon
```

---

## 3. Sagas de Instalación con Compensación

Cada operación del `INSTALL_RUNNER` es una **Saga**: una secuencia de pasos donde cada paso tiene una acción de compensación que se ejecuta si un paso posterior falla. Esto garantiza que el sistema nunca quede en un estado inconsistente.

### 3.1 Saga: Install

```
Paso 1: DEPENDENCY_RESOLVER.verify_all_satisfied(ficha_id)
  Compensación: (ninguna — es una lectura)
  Falla → ABORT (no se ejecuta nada)

Paso 2: STATE_MANAGER.transition(ficha_id, INSTALANDO)
  Compensación: STATE_MANAGER.transition(ficha_id, NO_INSTALADA)

Paso 3: YAML_ENGINE.execute_phase("pre_install", ficha_id)
  Compensación: (las pre_install deben ser idempotentes y no destructivas)

Paso 4: YAML_ENGINE.execute_phase("install", ficha_id)
  Compensación: YAML_ENGINE.execute_phase("uninstall", ficha_id)
  (si la ficha no tiene fase uninstall, ejecuta cleanup genérico:
   delete namespace, delete PVCs, delete secrets)

Paso 5: YAML_ENGINE.execute_phase("post_install", ficha_id)
  Compensación: (las post_install son verificaciones, no crean recursos)

Paso 6: HEALTH_CHECKER.verify(ficha_id)
  Compensación: (es una lectura)
  Falla → la ficha queda en ALERTA (no se compensa — los recursos existen pero no están sanos)

Paso 7: STATE_MANAGER.transition(ficha_id, INSTALADA_OK)
  (solo si paso 6 fue OK)
  STATE_MANAGER.register_hashes(ficha_id, PLUGIN_LOADER.compute_hashes(ficha_id))

SI FALLA EN PASO 4:
  → Ejecutar compensación del paso 4 (uninstall/cleanup)
  → Ejecutar compensación del paso 2 (volver a NO_INSTALADA)
  → Emitir evento "operation_done" con result="failed"
  → Emitir evento "step_error" con CAUSA + SOLUCIÓN
```

### 3.2 Saga: Update

```
Paso 1: STATE_MANAGER.transition(ficha_id, ACTUALIZANDO)
  Compensación: STATE_MANAGER.transition(ficha_id, INSTALADA_OK) [versión anterior]

Paso 2: PLUGIN_LOADER.backup_current_resources(ficha_id)
  → Copia resources/ actual a resources.prev/
  Compensación: PLUGIN_LOADER.restore_resources(ficha_id)

Paso 3: YAML_ENGINE.execute_phase("update", ficha_id)
  Compensación: YAML_ENGINE.execute_phase("rollback", ficha_id)
  (si no hay fase rollback, restaurar resources.prev + re-ejecutar install)

Paso 4: HEALTH_CHECKER.verify(ficha_id)
  Falla → ejecutar compensación del paso 3 (rollback)

Paso 5: STATE_MANAGER.transition(ficha_id, INSTALADA_OK)
  STATE_MANAGER.register_hashes(ficha_id, PLUGIN_LOADER.compute_hashes(ficha_id))
```

### 3.3 Saga: Repair

```
Paso 1: STATE_MANAGER.transition(ficha_id, REPARANDO)
  Compensación: STATE_MANAGER.transition(ficha_id, ALERTA)

Paso 2: SI ficha.repair.diagnosis_first == true:
         YAML_ENGINE.execute_phase("repair.diagnosis", ficha_id)
         → Genera reporte de diagnóstico
         → NO ejecuta acciones correctivas todavía

Paso 3: YAML_ENGINE.execute_phase("repair", ficha_id)
  Compensación: (ninguna — repair es "best effort")

Paso 4: HEALTH_CHECKER.verify(ficha_id)
  OK → STATE_MANAGER.transition(ficha_id, INSTALADA_OK)
  FAIL → STATE_MANAGER.transition(ficha_id, ALERTA) + notificar admin
```

### 3.4 Saga: Uninstall

```
Paso 0: GOVERNANCE check
  SI governance_category == 3:
    → Requiere aprobación dual (segundo admin diferente)
    → STATE_MANAGER.set_pending_governance(operation_id, awaiting_approval)
    → ABORT hasta que llegue la segunda aprobación (timeout: 60 minutos)

Paso 1: STATE_MANAGER.transition(ficha_id, DESINSTALANDO)
  Compensación: STATE_MANAGER.transition(ficha_id, INSTALADA_OK)

Paso 2: DEPENDENCY_RESOLVER.verify_no_dependents(ficha_id)
  → Verificar que ninguna otra ficha INSTALADA dependa de esta
  Falla → ABORT con lista de fichas dependientes

Paso 3: YAML_ENGINE.execute_phase("uninstall", ficha_id)
  → Si no tiene fase uninstall: cleanup genérico (delete namespace, PVCs, secrets)
  Compensación: YAML_ENGINE.execute_phase("install", ficha_id) [reinstalar]

Paso 4: STATE_MANAGER.transition(ficha_id, NO_INSTALADA)
  STATE_MANAGER.clear_hashes(ficha_id)
```

### 3.5 Timeouts por Saga

```
install:    30 minutos (fichas grandes como postgresql pueden tardar)
update:     15 minutos
repair:     10 minutos
uninstall:  10 minutos
deploy:     120 minutos (puede instalar múltiples productos)

Si el timeout se alcanza:
  → Ejecutar compensación desde el último paso completado hacia atrás
  → Emitir evento "operation_timeout"
  → STATE_MANAGER registra el timeout en el historial
```

---

## 4. Especificación Interna de Cada Módulo de Dominio

### 4.1 STATE_MANAGER

```
Responsabilidad: Árbitro exclusivo del estado persistente.

Datos que gestiona:
  .sbos_state.json (schema en §1)

Funciones públicas:
  get_state() → StateSnapshot
  get_ficha_status(ficha_id) → FichaStatus
  transition(ficha_id, new_status) → Result<void, TransitionError>
  register_hashes(ficha_id, hashes) → void
  clear_hashes(ficha_id) → void
  set_operation_active(operation) → Result<void, OperationInProgressError>
  complete_operation(operation_id, result) → void
  register_product(product_id, product_state) → void
  register_deploy(deploy_state) → void
  get_operations_history(filters) → Vec<Operation>

Reglas internas:
  - Toda escritura usa fcntl.flock(LOCK_EX) con timeout 5s
  - Toda transición se valida contra la tabla de §1.2
  - Toda mutación incrementa updated_at
  - Toda mutación emite un evento via SIGNAL_BUS
  - Solo UNA operación activa a la vez
  
Errores que puede emitir:
  TransitionError { from, to, reason: "invalid_transition" }
  StateLockTimeout { waited_ms: 5000 }
  OperationInProgressError { active_operation_id }
```

### 4.2 DEPENDENCY_RESOLVER

```
Responsabilidad: Grafo DAG de dependencias entre fichas.

Datos que consume:
  Todos los manifest.yml de fichas cargadas por PLUGIN_LOADER
  Estado actual de cada ficha via STATE_MANAGER

Funciones públicas:
  build_graph(fichas: Vec<FichaManifest>) → DAG
  topological_sort(dag: DAG) → Vec<FichaId>
  is_unblocked(ficha_id) → bool
  get_blocked_by(ficha_id) → Vec<FichaId>
  verify_all_satisfied(ficha_id) → Result<void, DependencyError>
  verify_no_dependents(ficha_id) → Result<void, DependentError>
  get_install_order(ficha_ids: Vec<FichaId>) → Vec<FichaId>

Algoritmo:
  1. Lee depends_on de cada manifest.yml
  2. Construye grafo dirigido (ficha → dependencia)
  3. Detecta ciclos → error fatal si encuentra uno
  4. Calcula orden topológico (Kahn's algorithm)
  5. Dentro del mismo nivel topológico, ordena por execution_order

Errores que puede emitir:
  DependencyError { ficha_id, missing: Vec<FichaId> }
  DependentError { ficha_id, dependents: Vec<FichaId> }
  CyclicDependencyError { cycle: Vec<FichaId> }
```

### 4.3 HEALTH_CHECKER

```
Responsabilidad: Evaluador de salud de fichas instaladas.

Datos que consume:
  health.check_command de cada manifest.yml
  Métricas de Prometheus (para fichas con health.prometheus_query)

Funciones públicas:
  check(ficha_id) → HealthResult { result: ok|degraded|error|pending, details: String }
  check_all() → Vec<(FichaId, HealthResult)>
  verify(ficha_id) → bool  (usado por Sagas: true si ok, false si error)

Criterios de clasificación:
  ok        → check_command exit 0 Y pods Running Y probes passing
  degraded  → check_command exit 0 PERO pods con restarts > 3 en última hora
  error     → check_command exit != 0 O pods CrashLoopBackOff O probes failing
  pending   → ficha en estado transitorio (INSTALANDO, ACTUALIZANDO, etc.)

Reglas:
  - Si consecutive_failures >= 3 → STATE_MANAGER.transition(ficha_id, ALERTA)
  - Si ficha en ALERTA y check pasa → STATE_MANAGER.transition(ficha_id, INSTALADA_OK)
  - Si ficha tiene auto_repair: true Y check falla:
    → INSTALL_RUNNER.repair(ficha_id) automáticamente (max 1 intento por ciclo)
```

### 4.4 FICHA_LINTER

```
Responsabilidad: Validar que una ficha cumple el contrato SBOS.

Datos que consume:
  Archivos de la ficha: manifest.yml, yaml_engine.yml, task_catalog.sh, resources/

Funciones públicas:
  lint(ficha_path) → LintResult { valid: bool, errors: Vec<LintError>, warnings: Vec<LintWarning> }
  lint_all(servers_path) → Vec<(FichaId, LintResult)>

Reglas de validación (obligatorias — lint falla si no cumple):
  manifest.yml:
    - Campos requeridos: name, version, server, execution_order, workload
    - workload.type ∈ {bash, kubernetes}
    - Si workload.type == kubernetes: workload.namespace requerido
    - governance_category ∈ {1, 2, 3}
    - health.check_command presente y no vacío
  
  yaml_engine.yml:
    - Al menos una fase: install
    - Toda tarea referenciada debe existir en task_catalog.sh O en 00_TASK_CATALOG_SBOS.sh
    - Si tiene fase repair: diagnosis_first debe ser bool
  
  task_catalog.sh:
    - Toda función termina con export -f (Principio P6)
    - No contiene referencias a apps concretas si es task_catalog global
    - Usa señales __SBOS__STEP_* para comunicar progreso
  
  resources/:
    - Todos los archivos declarados en manifest.yml existen
    - Checksums SHA-256 calculables

Warnings (no bloquean pero se reportan):
  - Ficha sin fase repair (recomendada)
  - Ficha sin fase update (recomendada para governance 2+)
  - execution_order duplicado con otra ficha del mismo server
```

### 4.5 FICHA_PROBE

```
Responsabilidad: Dry-run completo — predecir qué haría una operación sin ejecutarla.

Funciones públicas:
  probe_install(ficha_id) → ProbeResult
  probe_update(ficha_id) → ProbeResult
  probe_uninstall(ficha_id) → ProbeResult

ProbeResult:
  {
    ficha_id: string,
    operation: "install" | "update" | "uninstall",
    feasible: bool,
    blockers: Vec<String>,     // razones por las que no se puede ejecutar
    would_execute: Vec<Step>,  // lista de pasos que se ejecutarían
    estimated_duration_ms: u64,
    resources_required: { cpu_millicores, ram_mb, disk_gb },
    resources_available: { cpu_millicores, ram_mb, disk_gb },
    dependencies_satisfied: bool
  }

Mecanismo:
  1. Lee yaml_engine.yml de la ficha
  2. Recorre cada fase sin ejecutar los comandos
  3. Evalúa las condiciones de cada tarea
  4. Consulta recursos disponibles en el cluster (kubectl top nodes)
  5. Consulta DEPENDENCY_RESOLVER para dependencias
  6. Genera el reporte
```

### 4.6 GROWTH_DETECTOR

```
Responsabilidad: Detectar cuándo el cluster necesita más recursos.

Datos que consume:
  Métricas de Prometheus vía HTTP API
  Umbrales configurados en bos.toml

Funciones públicas:
  evaluate() → GrowthReport
  get_saturation() → ClusterSaturation

Umbrales (configurables en bos.toml):
  growth.cpu_threshold_percent: 80     # sugerir expansión cuando CPU > 80%
  growth.ram_threshold_percent: 85     # sugerir expansión cuando RAM > 85%
  growth.disk_threshold_percent: 75    # sugerir expansión cuando disco > 75%
  growth.evaluation_window_minutes: 30 # evaluar sobre los últimos 30 min

GrowthReport:
  {
    evaluation_at: datetime,
    saturated: bool,
    metrics: { cpu_percent, ram_percent, disk_percent },
    recommendation: "none" | "add_node" | "increase_resources",
    suggested_action: string,  // "Agregar nodo con al menos 4 vCPU y 8GB RAM"
    fichas_heaviest: Vec<{ ficha_id, cpu_percent, ram_mb }>
  }
```

---

## 5. Catálogo Completo de Señales `__SBOS__`

Las señales son la interfaz entre los scripts Bash (task_catalog.sh) y el daemon Go/Python. Se emiten por stdout y el `YAML_ENGINE` las parsea línea a línea.

### 5.1 Señales de progreso

```bash
__SBOS__STEP_START__    <descripción libre>
__SBOS__STEP_OK__       <descripción libre>
__SBOS__STEP_ERROR__    CAUSA: <texto>
                        SOLUCIÓN: <texto>
                        COMANDO: <comando CLI sugerido>
__SBOS__STEP_SKIP__     <razón por la que se saltó>
__SBOS__STEP_PROGRESS__ <N>/<TOTAL> <descripción>
```

### 5.2 Señales de finalización

```bash
__SBOS__DONE__OK__                     # fase completó exitosamente
__SBOS__DONE__ERROR__                  # fase falló
__SBOS__DONE__ERROR__COMPENSABLE__     # fase falló pero se puede compensar
__SBOS__DONE__ERROR__FATAL__           # fase falló, NO se puede compensar, requiere intervención manual
```

### 5.3 Señales de metadata

```bash
__SBOS__META__VERSION__     <versión de la app instalada>
__SBOS__META__PORT__        <puerto en el que escucha>
__SBOS__META__NAMESPACE__   <namespace K8s>
__SBOS__META__POD__         <nombre del pod>
__SBOS__META__PVC__         <nombre del PVC creado>
__SBOS__META__SECRET__      <nombre del secret creado>
__SBOS__META__CONFIG__      <nombre del ConfigMap creado>
```

El `YAML_ENGINE` captura estas señales de metadata y las pasa a `STATE_MANAGER` para registrar qué recursos creó cada ficha — esto permite al cleanup genérico saber qué eliminar en caso de compensación.

### 5.4 Reglas del protocolo

1. Toda línea que NO empiece con `__SBOS__` se trata como log informativo y se pasa a `PROGRESS_EMITTER` como evento `log_line`
2. `__SBOS__STEP_ERROR__` es multilinea: las líneas siguientes hasta la próxima señal `__SBOS__` pertenecen al error
3. Las señales se emiten a stdout. stderr se captura como log de diagnóstico pero NO se parsea como señal
4. El daemon NUNCA espera más de 30 minutos por una señal (timeout configurable en bos.toml)

---

## 6. Ficha de Referencia Completa

Esta es una ficha real con TODOS los campos posibles del contrato SBOS:

### 6.1 manifest.yml (todos los campos)

```yaml
# /etc/bos/blibs/servers/dataserver/postgresql/manifest.yml
name: "postgresql"
version: "18.0"
description: "Motor de persistencia principal del SBOS"
server: "dataserver"

execution_order: 100
governance_category: 2    # 1=normal, 2=requiere confirmación, 3=requiere aprobación dual

workload:
  type: "kubernetes"       # "bash" | "kubernetes"
  namespace: "sbos-data"
  workload_type: "StatefulSet"  # StatefulSet | Deployment | DaemonSet | Job
  replicas: 1

requirements:
  depends_on:
    - type: "ficha"
      target: "sbos-bootstrap-platform"
      state: "installed"
  resources:
    cpu: "500m"
    memory: "2Gi"
    storage: "50Gi"

health:
  check_command: "pg_isready -h localhost -p 5432"
  check_interval_seconds: 60
  consecutive_failures_threshold: 3
  auto_repair: false
  prometheus_query: "pg_up == 1"

criticality: true          # false = ficha opcional, no bloquea nada
auto_update: false          # true = RELEASE_MANAGER aplica updates sin confirmación
tags: ["database", "core", "stateful"]
```

### 6.2 yaml_engine.yml (todas las fases)

```yaml
# /etc/bos/blibs/servers/dataserver/postgresql/yaml_engine.yml
phases:

  pre_install:
    tasks:
      - task: "validate_namespace_exists"
        params:
          namespace: "sbos-data"
      - task: "validate_storageclass_default"
      - task: "validate_resources_available"
        params:
          cpu: "500m"
          memory: "2Gi"

  install:
    tasks:
      - task: "pg_create_namespace"
      - task: "pg_create_secrets"
      - task: "pg_create_configmap"
      - task: "pg_deploy_statefulset"
      - task: "wait_pod_ready"
        params:
          namespace: "sbos-data"
          pod_selector: "app=postgresql"
          timeout_seconds: 300
      - task: "pg_init_databases"
        params:
          databases: ["keycloak_db", "tryton_db", "kong_db", "grafana_db"]
      - task: "pg_configure_patroni"
      - task: "pg_configure_pgbouncer"
      - task: "pg_configure_wal_archiving"

  post_install:
    tasks:
      - task: "wait_pod_healthy"
        params:
          namespace: "sbos-data"
          pod_selector: "app=postgresql"
      - task: "verify_service_responds"
        params:
          service: "postgresql.sbos-data.svc"
          port: 5432
      - task: "pg_verify_replication"

  repair:
    diagnosis_first: true
    tasks:
      - task: "pg_diagnose_cluster"
        on_failure: "continue"
      - task: "pg_diagnose_replication"
        on_failure: "continue"
      - task: "pg_repair_patroni"
        on_failure: "abort"
      - task: "pg_repair_pgbouncer"
        on_failure: "continue"

  update:
    tasks:
      - task: "pg_backup_pre_update"
      - task: "pg_rolling_update"
        update_strategy: "rolling"
      - task: "pg_verify_post_update"
    rollback:
      tasks:
        - task: "pg_restore_from_backup"

  uninstall:
    tasks:
      - task: "pg_backup_final"
      - task: "pg_delete_statefulset"
      - task: "pg_delete_pvcs"
        confirm: true
      - task: "pg_delete_secrets"
      - task: "pg_delete_namespace"
```

### 6.3 task_catalog.sh (estructura)

```bash
#!/usr/bin/env bash
# /etc/bos/blibs/servers/dataserver/postgresql/task_catalog.sh
# Tareas ESPECÍFICAS de PostgreSQL — solo este archivo las conoce

pg_create_namespace() {
    __SBOS__STEP_START__    Crear namespace sbos-data
    kubectl create namespace sbos-data --dry-run=client -o yaml | kubectl apply -f -
    __SBOS__STEP_OK__       Namespace sbos-data listo
    __SBOS__META__NAMESPACE__   sbos-data
}
export -f pg_create_namespace

pg_create_secrets() {
    __SBOS__STEP_START__    Generar credenciales PostgreSQL
    local pg_pass
    pg_pass=$(openssl rand -base64 32)
    kubectl create secret generic postgresql-credentials \
        --namespace=sbos-data \
        --from-literal=POSTGRES_PASSWORD="$pg_pass" \
        --dry-run=client -o yaml | kubectl apply -f -
    __SBOS__STEP_OK__       Credenciales almacenadas en secret postgresql-credentials
    __SBOS__META__SECRET__  postgresql-credentials
}
export -f pg_create_secrets

pg_deploy_statefulset() {
    __SBOS__STEP_START__    Desplegar StatefulSet PostgreSQL
    sbos_k8s_core "apply" "resources/postgresql-statefulset.yaml"
    __SBOS__STEP_OK__       StatefulSet postgresql desplegado
    __SBOS__META__POD__     postgresql-0
}
export -f pg_deploy_statefulset

pg_init_databases() {
    local databases=("$@")
    __SBOS__STEP_START__    Crear bases de datos iniciales
    for db in "${databases[@]}"; do
        kubectl exec -n sbos-data postgresql-0 -- \
            psql -U postgres -c "CREATE DATABASE ${db} WITH OWNER postgres;" 2>/dev/null || true
        echo "  → Base de datos ${db} lista"
    done
    __SBOS__STEP_OK__       ${#databases[@]} bases de datos creadas
}
export -f pg_init_databases

# ... (más funciones, cada una con export -f)
```

---

## 7. Endpoints de Productos y Deploy

Estos endpoints complementan los de SBOS-007 §11 para cubrir las operaciones de Nivel 2 (Productos) y Nivel 3 (Deploy):

### 7.1 Productos

```
GET  /api/products
  → Lista todos los productos disponibles en products/ con su estado

GET  /api/products/{product_id}
  → Detalle de un producto: fichas participantes, requirements, estado de cada ficha

POST /api/products/{product_id}/install
  Request: { "confirmed": true, "params": { "DOMAIN": "skull.io", ... } }
  Response 202: { "operation_id": "uuid", "websocket_url": "/ws/operations/uuid" }

POST /api/products/{product_id}/verify
  → Re-ejecuta las verificaciones del producto sin instalar nada
  Response 200: { "checks": [{ "name": "smtp_send", "result": "pass" }, ...] }
```

### 7.2 Deploy

```
POST /api/deploy
  Request: { "seed_file": "/path/to/deploy.yml" }
  → Valida el seed file, genera llaves, inicia la secuencia de productos
  Response 202: { "deploy_id": "uuid", "websocket_url": "/ws/deploy/uuid" }

GET  /api/deploy/status
  → Estado del deploy activo (si hay uno)
  Response 200: {
    "deploy_id": "uuid",
    "tenant_name": "SKULL S.R.L.",
    "products_total": 3,
    "products_completed": 1,
    "current_product": "mail",
    "current_ficha": "mailserver",
    "progress_percent": 45,
    "started_at": "...",
    "estimated_remaining_minutes": 32
  }
```

---

## 8. Configuración del Daemon (bos.toml)

```toml
# /etc/bos/bos.toml

[daemon]
listen_socket = "/run/bos/bos.sock"       # Unix socket para bosctl
listen_tcp = "0.0.0.0:9443"               # TCP para Core UI (HTTPS)
tls_cert = "/etc/bos/tls/server.crt"
tls_key = "/etc/bos/tls/server.key"
log_level = "info"                         # debug | info | warn | error
log_file = "/var/log/bos/bos.log"

[state]
state_file = "/etc/bos/.sbos_state.json"
lock_timeout_seconds = 5
events_dir = "/etc/bos/"                   # directorio para .jsonl

[health]
check_interval_seconds = 60
consecutive_failures_threshold = 3

[reconcile]
interval_seconds = 300                     # cada 5 minutos
drift_check = true

[release]
server_url = "https://releases.skull.io"
check_interval_hours = 6
channel = "canary"                         # canary | early | stable
stabilization_window_seconds = 300         # 5 minutos de observación post-update
ed25519_public_key = "base64:..."

[growth]
cpu_threshold_percent = 80
ram_threshold_percent = 85
disk_threshold_percent = 75
evaluation_window_minutes = 30

[sagas]
install_timeout_minutes = 30
update_timeout_minutes = 15
repair_timeout_minutes = 10
uninstall_timeout_minutes = 10
deploy_timeout_minutes = 120

[ficha_defaults]
servers_path = "/etc/bos/blibs/servers"
products_path = "/etc/bos/products"
```

---

## 9. Registro de Cambios

### v1.0 — Marzo 2026

Documento nuevo. Especificación técnica interna del daemon `bos` que cubre: schema completo de `.sbos_state.json` con transiciones de estado, protocolo bosctl↔daemon vía Unix socket, 4 Sagas de instalación con compensación, especificación de 6 módulos de dominio con funciones públicas y reglas, catálogo completo de señales `__SBOS__`, ficha de referencia con todos los campos posibles (manifest.yml + yaml_engine.yml + task_catalog.sh), endpoints de Productos y Deploy, y formato de bos.toml.

---

*SKULL · SBOS · SBOS-005-001 · Anexo 001 · v1.0 · Marzo 2026*
*Complementa: SBOS-005-INSTALLER-v5_0.md · SBOS-006-FICHA-v4_0.md · SBOS-007-COREUI-v4_0.md*
