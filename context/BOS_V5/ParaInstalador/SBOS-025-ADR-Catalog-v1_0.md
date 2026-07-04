# SBOS-025 — Catálogo de Decisiones Arquitectónicas (ADR)
## Architecture Decision Records formales del proyecto SBOS

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-025
**Versión:** 1.0
**Estado:** ACTIVO
**Extensión:** SBOS-025-ARB-Proceso.md — SBOS-025-EXT-ARB (Proceso Formal ARB: template RFC, composición del board, criterios de quórum — complemento disponible en archivo separado)
**Documento nuevo** — no reemplaza a ningún documento anterior
**Clasificación:** Gobierno Arquitectónico — Registro de Decisiones
**Complementa:** SBOS-002 (Arquitectura), SBOS-003 (Stack), SBOS-005 (IAM Installer), SBOS-010 (bKernel)

---

## Índice de Decisiones

| ID | Título | Fecha | Estado |
|----|--------|-------|--------|
| [ADR-001](#adr-001) | WAL de PostgreSQL como EventBus nativo del sistema | 2026-01 | ✅ Aceptada |
| [ADR-002](#adr-002) | Daemons soberanos como procesos systemd fuera de Kubernetes | 2026-01 | ✅ Aceptada |
| [ADR-003](#adr-003) | IAM Installer como daemon residente — no como script Bash | 2026-01 | ✅ Aceptada |
| [ADR-004](#adr-004) | Keycloak como único proveedor de identidad del stack | 2025-09 | ✅ Aceptada |
| [ADR-005](#adr-005) | PostgreSQL como única base de datos relacional del SBOS | 2025-09 | ✅ Aceptada |
| [ADR-006](#adr-006) | Veto de n8n — SBOS AI Tools como reemplazo soberano | 2025-11 | ✅ Aceptada |
| [ADR-007](#adr-007) | Firma Ed25519 de todos los artefactos del Release Plane | 2026-01 | ✅ Aceptada |
| [ADR-008](#adr-008) | Arquitectura de fichas como unidad atómica de despliegue | 2025-09 | ✅ Aceptada |
| [ADR-009](#adr-009) | Rust para daemons CPU-bound, Go para daemons I/O-bound | 2026-03 | ✅ Aceptada |

---

## Proceso para nuevas decisiones

Una nueva decisión arquitectónica debe formalizarse como ADR cuando:

- Afecta uno de los Tres Principios Inquebrantables (Keycloak, PostgreSQL, licencias libres).
- Modifica el protocolo WAL o los slots de replicación lógica.
- Introduce nuevas dependencias en los daemons soberanos (nuevas crates Rust).
- Cambia el canal de distribución Ed25519 / Release Plane.
- Impacta S01 (dataserver) o S03 (identityserver).

**Proceso:**
1. Abrir un RFC como GitHub Issue con label `architecture-decision`.
2. 5 días hábiles para comentarios del equipo.
3. Discutir y decidir en la reunión mensual del ARB (Architecture Review Board).

> **Para el proceso formal completo del ARB** (template RFC, composición del board, criterios de quórum, proceso de 5 días de revisión), ver **SBOS-025-EXT-ARB** (SBOS-025-ARB-Proceso.md).
4. Si se aprueba: el Arquitecto Lead formaliza el RFC como ADR en este catálogo en 48 horas.

---

## ADR-001

### WAL de PostgreSQL como EventBus nativo del sistema

**Fecha:** Enero 2026
**Estado:** ✅ Aceptada
**Autores:** Arquitecto Lead, CTO

#### Contexto

El SBOS integra más de 110 aplicaciones open source sobre una infraestructura compartida de PostgreSQL. Para que los datos fluyan entre estas aplicaciones (por ejemplo, que un empleado creado en OrangeHRM aparezca automáticamente en Tryton y en Keycloak), se necesita un mecanismo de propagación de cambios.

El sistema tiene un requerimiento no negociable: **ninguna aplicación del stack puede ser modificada**. Instalar un agente, agregar un webhook, o modificar el código de Tryton o OrangeHRM para que "publiquen" sus cambios es inaceptable — viola la propiedad de cero invasión que hace al sistema sustituible y mantenible.

#### Decisión

El WAL (Write-Ahead Log) de PostgreSQL con replicación lógica (`pgoutput`) es el bus de eventos principal del SBOS. El bKernel se suscribe al WAL via slots de replicación lógica para cada base de datos del stack y actúa sobre los cambios que detecta.

No se usa Kafka, RabbitMQ, Redis Streams ni ningún middleware de mensajería externo como bus principal.

#### Alternativas rechazadas

| Alternativa | Razón del rechazo |
|-------------|------------------|
| **Apache Kafka + Debezium** | Debezium requiere que las apps publiquen o usa connectors que modifican el comportamiento de PostgreSQL. Además introduce Kafka con Zookeeper/KRaft — infraestructura adicional con complejidad operacional significativa que viola el principio de stack mínimo. |
| **MuleSoft / Boomi (iPaaS)** | Son SaaS — los datos del cliente salen de su servidor. Viola el principio de soberanía del sistema. Además requieren modificar las apps para publicar eventos. |
| **Redis Streams como bus principal** | Redis Streams requiere un productor que publique explícitamente. Las aplicaciones del stack no publican en Redis — no hablan "Redis natively". Requeriría modificar cada app. |
| **RabbitMQ** | Mismo problema que Redis Streams: las apps deben publicar activamente. No hay orden causal garantizado de eventos. |
| **Polling periódico** | Introduce latencia mínima de N segundos entre cambio y propagación. Sobrecarga de queries de verificación. Falsos negativos. Incompatible con el SLO de lag < 500ms del bKernel. |

#### Consecuencias positivas

- **Cero invasión:** ninguna app del stack fue modificada. Tryton, OrangeHRM, Saleor no saben que el bKernel existe.
- **Ordering causal garantizado:** el LSN (Log Sequence Number) del WAL es un ordenamiento causal estricto — no hay race conditions por reordenamiento de mensajes.
- **Sin infraestructura adicional:** el "bus" ya existe en PostgreSQL, que es un componente obligatorio del stack. Cero costo operacional adicional.
- **Extensibilidad sin fricción:** un nuevo daemon que quiera observar el sistema solo necesita crear un slot de replicación — sin coordinación con otras apps.
- **Event sourcing nativo:** el WAL es por definición un log inmutable de eventos. La reconstrucción de estado desde un LSN dado es una propiedad nativa.

#### Consecuencias negativas / trade-offs

- **Dependencia única en PostgreSQL:** el bus de eventos falla si PostgreSQL falla. Mitigado con Patroni HA y el SLO de disponibilidad 99.99%.
- **Complejidad de los slots de replicación:** los slots son recursos persistentes que deben gestionarse explícitamente. Un restore de PostgreSQL no migra los slots — deben recrearse. Ver SBOS-026 RK-012.
- **Límite `max_slot_wal_keep_size`:** si el bKernel está detenido mucho tiempo, el slot puede invalidarse. Mitigado con alerta en Alertmanager (SBOS-026 §7).
- **Solo funciona con PostgreSQL:** esta decisión hace que PostgreSQL sea verdaderamente no sustituible como motor de base de datos del stack. Ver ADR-005.

**Documentos relacionados:** SBOS-002 §3, SBOS-010 §1, SBOS-010 §10

---

## ADR-002

### Daemons soberanos como procesos systemd fuera de Kubernetes

**Fecha:** Enero 2026
**Estado:** ✅ Aceptada
**Autores:** Arquitecto Lead, Rust Team

#### Contexto

Los daemons soberanos del host necesitan acceso de baja latencia a PostgreSQL. El bKernel en particular lee el WAL via replicación lógica — requiere el rol de replicación de PostgreSQL y una conexión con latencia determinista.

La infraestructura de ejecución de aplicaciones del SBOS es Kubernetes. La pregunta es: ¿deben estos daemons correr como pods K8s o como servicios systemd en el host?

#### Decisión

Los daemons del host corren como servicios `systemd` directamente en el host Ubuntu, fuera del cluster Kubernetes.

```
/etc/systemd/system/bkernel.service
/etc/systemd/system/biedata.service
/etc/systemd/system/bcompass.service
```

#### Alternativas rechazadas

| Alternativa | Razón del rechazo |
|-------------|------------------|
| **DaemonSet K8s (pod en cada nodo)** | El bKernel necesita acceso al socket Unix de PostgreSQL (`/var/run/postgresql/.s.PGSQL.5432`) para latencia < 100ms. Un DaemonSet en K8s agrega una capa de red (CNI) con latencia variable inaceptable para sincronización en tiempo real. |
| **Pod K8s con hostNetwork: true** | Aunque reduce la latencia de red, complica el modelo de seguridad (el pod tiene acceso a la red del host) y requiere privilegios elevados que violan el principio de mínimo privilegio. |
| **Sidecar container junto a PostgreSQL** | PostgreSQL corre en K8s. Un sidecar junto a PostgreSQL para el bKernel mezcla responsabilidades y hace el ciclo de vida del bKernel dependiente del ciclo de vida del pod de PostgreSQL — que tiene sus propias razones para reiniciarse. |

#### Consecuencias positivas

- **Latencia determinista al WAL:** el bKernel accede a PostgreSQL via socket Unix local. Latencia medida consistentemente < 100ms.
- **Independencia del ciclo de vida de K8s:** si K8s falla, los daemons soberanos siguen corriendo y procesando el WAL. El sistema de datos no se detiene aunque el cluster esté reiniciando.
- **Sin overhead de red para SBOS Data Integration:** SBOS Data Integration necesita acceso a la red del host para integraciones externas (APIs tributarias). En el host, accede directamente sin NAT ni NetworkPolicies de CNI.
- **Sin superficie de ataque adicional:** los daemons no tienen puertos abiertos ni APIs REST. No están expuestos al plano de red de K8s.

#### Consecuencias negativas / trade-offs

- **Punto ciego en observabilidad:** los daemons no son pods K8s, por lo que Prometheus no puede hacer scraping directo. Requieren un OTEL Collector como servicio systemd intermediario. Ver SBOS-027.
- **Gestión de binarios fuera del ciclo de fichas:** los daemons se actualizan via el SKULL Release Plane como binarios, no como imágenes Docker. Requieren un proceso de actualización diferente al de las fichas K8s.
- **Sin horizontal scaling nativo:** los daemons son instancias únicas. El scaling vertical (más CPU/RAM en el host) es la única opción. Mitigado con el Thread Pool Adaptativo del bKernel.

**Documentos relacionados:** SBOS-016 §3, SBOS-010 §3, SBOS-011, SBOS-014

---

## ADR-003

### IAM Installer como daemon residente — no como script Bash

**Fecha:** Enero 2026
**Estado:** ✅ Aceptada
**Autores:** CTO, Arquitecto Lead

#### Contexto

El SBOS necesita un componente que gestione el ciclo de vida de todas las fichas del stack: instalación inicial, actualizaciones, detección de drift, rollback automático, y gestión de la flota de clientes. La pregunta de diseño fundamental es: ¿este componente es un script que se ejecuta cuando se necesita, o es un proceso que siempre está corriendo?

#### Decisión

El IAM Installer es un daemon residente que corre permanentemente como servicio systemd en el host. No es un script de una pasada. Está implementado en dos capas: archivos maestros Bash para operaciones del sistema operativo y 16 módulos Python para orquestación, estado persistente, API REST y WebSocket.

#### Alternativas rechazadas

| Alternativa | Razón del rechazo |
|-------------|------------------|
| **Script Bash de larga duración** | Un script Bash tiene manejo pobre de errores en lógica compleja, no puede mantener estado persistente entre ciclos, no puede exponer una API REST ni emitir eventos WebSocket para el Core UI, y no soporta concurrencia real para gestionar múltiples fichas en paralelo. |
| **Script cron periódico** | Un cron job no puede reaccionar en tiempo real a cambios de estado. Si un pod falla a los 2 minutos de la ejecución del cron, el sistema tarda hasta N-2 minutos en detectarlo y actuar. El IAM Installer detecta y reacciona en segundos. |
| **ArgoCD + Helm como control plane** | ArgoCD es un control plane excelente para K8s puro, pero el SBOS tiene daemons soberanos fuera de K8s y un modelo de distribución propio (SKULL Release Plane). ArgoCD no puede gestionar servicios systemd del host ni implementar el protocolo de actualización con firma Ed25519. |
| **Ansible / Puppet / Chef** | Herramientas de configuración, no de control plane continuo. No tienen el modelo de reconciliación continua ni la API WebSocket que el Core UI necesita para feedback en tiempo real. |

#### Consecuencias positivas

- **Reconciliación continua:** el IAM Installer detecta drift entre el estado declarado en las fichas y el estado real del cluster en cada ciclo (cada 15 minutos) y actúa para corregirlo.
- **Rollback en < 30 segundos:** el watchdog de estabilización del IAM Installer puede revertir un despliegue fallido automáticamente sin intervención humana.
- **API REST + WebSocket para el Core UI:** el Core UI recibe feedback en tiempo real del proceso de instalación via WebSocket, sin polling.
- **Gestión de flota:** el IAM Installer se conecta al SKULL Release Plane para recibir actualizaciones de fichas y del propio daemon, habilitando la gestión de múltiples instalaciones de clientes desde un punto central.

#### Consecuencias negativas / trade-offs

- **Complejidad de bootstrapping:** el IAM Installer debe ser instalado antes de poder instalar el resto del stack. Si el IAM Installer falla, el sistema no puede instalarse ni repararse solo. Mitigado con el modo degradado offline.
- **Dos lenguajes de implementación:** Bash (4 archivos maestros) + Python (16 módulos). Requiere que los contribuidores conozcan ambos. La separación es rígida: Bash para OS, Python para orquestación.
- **Estado persistente en archivo JSON:** `.sbos_state.json` es el árbitro del estado. Si este archivo se corrompe, el IAM Installer pierde la vista del sistema. Mitigado con snapshots periódicos.

**Documentos relacionados:** SBOS-005 §1, SBOS-005 §2, SBOS-005 §4

---

## ADR-004

### Keycloak como único proveedor de identidad del stack

**Fecha:** Septiembre 2025
**Estado:** ✅ Aceptada
**Autores:** CTO, Identity Team

#### Contexto

El SBOS instala y opera más de 110 aplicaciones para múltiples empresas clientes (tenants). Cada empresa tiene sus usuarios, roles y permisos. Sin un sistema centralizado de identidad, cada aplicación gestionaría su propia autenticación — imposible de administrar, imposible de auditar, imposible de revocar accesos ante una baja de empleado.

#### Decisión

Keycloak es el único proveedor de identidad del stack SBOS. Toda autenticación y autorización de usuarios y servicios pasa por Keycloak. No se instala ningún otro IdP ni sistema de autenticación propio en ninguna aplicación del stack. Este es el **Principio 1 del SBOS** — no admite excepciones.

#### Alternativas rechazadas

| Alternativa | Razón del rechazo |
|-------------|------------------|
| **Auth0 / Okta (SaaS)** | Son servicios SaaS — los tokens de identidad de los clientes del cliente pasan por servidores de terceros. Viola el principio de soberanía del sistema. |
| **LDAP directo** | LDAP no soporta OIDC moderno. Las aplicaciones del stack (Tryton, OrangeHRM, Saleor) esperan OIDC/JWT. Integrar LDAP requeriría un intermediario de todas formas. |
| **Authentik** | Alternativa comparable a Keycloak en funcionalidad. Evaluada como opción secundaria. Rechazada porque Keycloak tiene el ecosistema de SPIs más maduro, mayor adopción en entornos enterprise, y soporte de RHEL/Red Hat que da respaldo comercial si se necesita. |
| **Autenticación nativa por app** | Cada app gestionando sus propios usuarios haría imposible la revocación inmediata de accesos (baja de empleado debe propagarse instantáneamente), el H-RBAC unificado, y la auditoría centralizada de accesos. |

#### Consecuencias positivas

- **Revocación inmediata:** deshabilitar un usuario en Keycloak revoca su acceso a todas las aplicaciones del stack. El JWT expira en 5 minutos — en ese tiempo máximo todas las sesiones activas del usuario quedan inválidas.
- **H-RBAC unificado:** un único modelo de roles (calculado por el role_calculator con los atributos del realm) aplica consistentemente a todas las aplicaciones.
- **Multi-tenancy limpio:** cada empresa cliente tiene su propio realm en Keycloak. El aislamiento de identidad entre tenants es garantizado por la arquitectura de Keycloak, no por código custom.
- **SPIs extensibles:** los 5 SPIs custom (incluyendo SkbosBehavioralScoreAuthenticator) permiten políticas de autenticación específicas sin modificar Keycloak.

#### Consecuencias negativas / trade-offs

- **SPOF de identidad:** si Keycloak está caído, ningún usuario puede autenticarse. Mitigado con el SLO de disponibilidad 99.99% y el SLA de RTO 30 minutos. Las sesiones activas siguen funcionando hasta que el JWT expira (5 minutos).
- **Curva de aprendizaje:** Keycloak es un sistema complejo. La gestión de realms, flows de autenticación, y SPIs requiere capacitación específica. Mitigado con SBOS-021 (onboarding) y SBOS-019/020 (documentación de SPIs).

**Documentos relacionados:** SBOS-019 (Auth Methods), SBOS-020 (Data Responses), SBOS-008 (Rol Framework), SBOS-009 (Identity Contracts)

---

## ADR-005

### PostgreSQL como única base de datos relacional del SBOS

**Fecha:** Septiembre 2025
**Estado:** ✅ Aceptada
**Autores:** Arquitecto Lead, CTO

#### Contexto

El stack SBOS incluye más de 110 aplicaciones. Algunas de estas aplicaciones tienen soporte nativo para múltiples bases de datos (MySQL, MariaDB, SQLite, PostgreSQL). La pregunta es: ¿se instala la base de datos que cada app prefiere, o se estandariza en una sola?

La decisión sobre el EventBus (ADR-001) creó una restricción técnica: el bus de eventos del sistema es el WAL de PostgreSQL. Esta restricción hace que la estandarización en PostgreSQL sea obligatoria, no solo conveniente.

#### Decisión

PostgreSQL es la única base de datos relacional del SBOS. Toda aplicación del stack que requiera base de datos relacional usa PostgreSQL. No se instala MySQL, MariaDB, SQLite en modo producción, ni ninguna otra base de datos relacional. Este es el **Principio 2 del SBOS**.

> **Nota:** MySQL 8 aparece en SBOS-003 como componente del S01 dataserver para compatibilidad con aplicaciones que tienen soporte limitado de PostgreSQL. Su uso es secundario y acotado, no es la base de datos principal del stack.

#### Alternativas rechazadas

| Alternativa | Razón del rechazo |
|-------------|------------------|
| **MySQL / MariaDB como principal** | MySQL no soporta replicación lógica `pgoutput`. El bKernel no puede escuchar el binlog de MySQL con el mismo mecanismo. Usar MySQL como principal requeriría un sistema de CDC completamente diferente — viola ADR-001. |
| **Una BD por app (cada app su preferida)** | Fragmenta las conexiones del pool. Requiere que el bKernel soporte múltiples protocolos de CDC. Aumenta el área de superficie de backup y restore. Imposible de gestionar con el sistema de fichas unificado. |
| **Bases de datos distribuidas (CockroachDB, Vitess)** | Complejidad operacional desproporcionada para la escala objetivo del SBOS (PYMES). El modelo de replicación lógica WAL no funciona igual en bases de datos distribuidas. |

#### Consecuencias positivas

- **Un solo servidor de datos (S01 dataserver):** toda la persistencia relacional del stack está en un lugar — simplifica backup, restore, monitoreo y seguridad.
- **PgBouncer como pool unificado:** todas las apps del stack se conectan via PgBouncer. Un solo pool para 110+ apps.
- **Extensiones unificadas:** TimescaleDB, pgvector, pg_partman están disponibles para todas las apps sin configuración adicional por app.
- **El bKernel funciona en toda la flota:** el mismo binario del bKernel funciona con cualquier instalación de SBOS porque todas usan PostgreSQL con la misma configuración de replicación lógica.

#### Consecuencias negativas / trade-offs

- **PostgreSQL es no sustituible:** esta decisión, junto con ADR-001, hace que PostgreSQL sea el único componente del stack que no puede ser reemplazado por otro equivalente. Es la dependencia más crítica del sistema.
- **Configuración adicional para apps que prefieren MySQL:** algunas apps del stack requieren configuración específica para funcionar bien con PostgreSQL. El equipo de fichas debe resolver estos casos.

**Documentos relacionados:** SBOS-002 §3, SBOS-010 §4, SBOS-016 §1 (S01 dataserver)

---

## ADR-006

### Veto de n8n — SBOS AI Tools como reemplazo soberano

**Fecha:** Noviembre 2025
**Estado:** ✅ Aceptada
**Autores:** CTO, Arquitecto Lead

#### Contexto

El SBOS necesita un motor de automatización de workflows y orquestación de inteligencia. Las rutas de SBOS AI Tools (agent, flow, analyst, report) requieren un motor que pueda encadenar pasos, condicionales, y llamadas a servicios externos e internos.

n8n fue la candidata natural: popular, open source en apariencia, con conectores para decenas de servicios, interfaz visual para construir workflows, y soporte de self-hosting.

#### Decisión

n8n está **vetada** del stack SBOS. No puede incluirse como ficha ni como herramienta de orquestación. En su lugar, se desarrolla **SBOS AI Tools** como daemon soberano de orquestación en Rust, con licencia MIT de SKULL, parte de la conjunto de 8 daemons soberanos del SBOS.

#### Razón del veto

n8n usa la **Sustainable Use License** — una licencia que no es OSI-certified como software libre y que incluye restricciones comerciales específicas para uso en servicios gestionados y como parte de productos comerciales. Esta licencia viola el **Principio 3 del SBOS** (solo licencias libres: MIT, Apache 2.0, GPL, AGPL o equivalentes sin restricciones comerciales).

El SBOS es un producto comercial que se instala en los servidores de sus clientes. Incluir n8n en el stack crea una ambigüedad legal sobre si el uso de n8n por parte de los clientes de SKULL está cubierto por la licencia de n8n. La decisión es eliminar la ambigüedad rechazando la herramienta.

#### Alternativas rechazadas

| Alternativa | Razón del rechazo |
|-------------|------------------|
| **n8n Community Edition** | Sustainable Use License — viola Principio 3. Rechazada. |
| **Apache Airflow** | Excelente para ETL y pipelines de datos, pero no diseñado para orquestación de workflows de negocio en tiempo real. Requiere DAGs Python, no rutas declarativas. Además tiene overhead operacional significativo (S07 reportserver ya lo usa para ETL — no duplicar en roles de negocio). |
| **Temporal.io** | MIT license, excelente motor de workflows. Evaluado positivamente pero requiere servidor adicional y workers — infraestructura que no existe en el stack. SBOS AI Tools es un daemon del host que no necesita infraestructura adicional. |
| **Prefect / Dagster** | Orientados a data engineering, no a workflows de negocio con LLM. BSL/Apache con modelos freemium que generan dependencia en sus plataformas cloud. |

#### Consecuencias positivas

- **Licencia MIT sin restricciones:** SBOS AI Tools es propiedad de SKULL con licencia MIT. Los clientes pueden usar SBOS comercialmente sin restricciones de licencia sobre el motor de orquestación.
- **Integración nativa con el WAL:** SBOS AI Tools, como daemon del host, puede leer el WAL de PostgreSQL directamente via el mismo mecanismo que el bKernel. Los workflows de SBOS AI Tools pueden reaccionar a eventos del WAL en tiempo real.
- **LLM soberano:** SBOS AI Tools usa Ollama local como LLM. Las rutas agent/analyst no envían datos del cliente a APIs externas.
- **Sin superficie de ataque:** SBOS AI Tools no tiene puerto ni API REST expuesta — idéntica postura de seguridad al bKernel.

#### Consecuencias negativas / trade-offs

- **Desarrollo interno:** SBOS AI Tools debe desarrollarse y mantenerse por SKULL. No hay una comunidad open source detrás. El equipo asume la responsabilidad completa.
- **Sin interfaz visual de workflows:** n8n tenía un editor visual drag-and-drop. SBOS AI Tools usa rutas YAML declarativas — más potentes pero con mayor curva de aprendizaje.

**Documentos relacionados:** SBOS-003 §2, SBOS-003 §8, SBOS-014

---

## ADR-007

### Firma Ed25519 de todos los artefactos del Release Plane

**Fecha:** Enero 2026
**Estado:** ✅ Aceptada
**Autores:** CTO, Arquitecto Lead

#### Contexto

El SBOS opera un modelo de distribución soberana: el SKULL Release Plane distribuye binarios y fichas hacia los servidores de los clientes. Este modelo tiene una vulnerabilidad inherente: si el Release Server es comprometido, un atacante podría distribuir fichas maliciosas a todos los clientes de SKULL.

#### Decisión

Todo artefacto distribuido por el SKULL Release Plane (binarios del IAM Installer, fichas, reglas YAML del bKernel, rutas .so del SBOS AI Tools) está firmado con Ed25519. El IAM Installer verifica la firma antes de instalar cualquier artefacto. Si la verificación falla, la instalación es abortada.

#### Alternativas rechazadas

| Alternativa | Razón del rechazo |
|-------------|------------------|
| **Solo HTTPS para el canal de distribución** | TLS protege el canal pero no el contenido. Un atacante con acceso al servidor web del Release Plane puede reemplazar artefactos sin necesitar comprometer el canal TLS. |
| **SHA-256 checksums sin firma** | Los checksums verifican integridad pero no autenticidad. Un atacante puede reemplazar un artefacto Y su checksum correspondiente. La firma Ed25519 garantiza que solo quien tiene la clave privada puede generar una firma válida. |
| **RSA-2048 / RSA-4096** | Ed25519 es más eficiente, genera firmas más pequeñas, y tiene mejor resistencia a ataques de canal lateral. Es el estándar moderno para firma de código. |
| **Firma via PKI con CA interna** | Más complejo de operar (gestión de CAs, revocación de certificados). Ed25519 con par de claves simple es suficiente para el modelo de distribución de SBOS y más fácil de rotar si la clave es comprometida. |

#### Consecuencias positivas

- **Protección ante compromiso del Release Server:** aunque un atacante tenga acceso al servidor de distribución, no puede generar firmas válidas sin la clave privada Ed25519 (que no está en el servidor web).
- **Verificación en cada instalación:** el IAM Installer verifica la firma antes de ejecutar cualquier artefacto descargado — incluso en instalaciones offline desde caché local.
- **Auditabilidad:** el par de claves Ed25519 puede rotarse si hay sospecha de compromiso. Todas las instalaciones que intenten usar artefactos firmados con la clave antigua fallarán automáticamente.

#### Consecuencias negativas / trade-offs

- **Gestión segura de la clave privada:** la clave privada Ed25519 es el activo más crítico del Release Plane. Su compromiso comprometería la cadena de confianza de todas las instalaciones de clientes. Requiere almacenamiento en HSM o secret manager fuera del servidor web.
- **Build pipeline más complejo:** cada artefacto debe ser firmado en el pipeline CI/CD antes de publicarse. Añade un paso al proceso de release.

**Documentos relacionados:** SBOS-005 §9, SBOS-023 (Vector 4 — Compromiso del canal de distribución)

---

## ADR-008

### Arquitectura de fichas como unidad atómica de despliegue soberano

**Fecha:** Septiembre 2025
**Estado:** ✅ Aceptada
**Autores:** Arquitecto Lead, CTO

#### Contexto

El SBOS debe instalar, configurar, actualizar y mantener más de 110 aplicaciones en los servidores de múltiples clientes. Cada aplicación tiene sus propios requerimientos de configuración, dependencias, secretos, y ciclo de actualización. ¿Cuál es la unidad mínima de gestión que permite automatizar esto de forma confiable?

#### Decisión

La **ficha** es la unidad atómica del SBOS. Cada aplicación del stack está encapsulada en una ficha: un contrato formal compuesto por `manifest.yml` + `yaml_engine.yml` + `resources/`. El IAM Installer solo conoce aplicaciones a través de sus fichas — si una aplicación no tiene ficha, el sistema no la conoce. Si la ficha cambia, el IAM Installer reconcilia. Si la ficha tiene un error, el FICHA_LINTER lo detecta antes de que llegue al Release Plane.

#### Alternativas rechazadas

| Alternativa | Razón del rechazo |
|-------------|------------------|
| **Helm Charts** | Helm Charts son excelentes para K8s puro, pero el SBOS tiene componentes fuera de K8s (daemons soberanos, configuración del host). Una ficha SBOS puede gestionar tanto recursos K8s como configuración del SO del host — Helm no puede. |
| **Scripts de instalación por app** | Scripts son imperativos — difíciles de reconciliar, imposibles de hacer idempotentes de forma confiable. Una ficha es declarativa: describe el estado deseado, el IAM Installer decide cómo alcanzarlo. |
| **ArgoCD ApplicationSets** | Excelente para flotas K8s puras. No puede gestionar servicios systemd, no tiene el modelo de distribución del Release Plane, no tiene el drift detection integrado con el modelo de realms de Keycloak. |
| **Ansible Playbooks** | Ansible es procedimental. El modelo de reconciliación continua del IAM Installer requiere un motor declarativo. Ansible no tiene el modelo de estado persistente (`.sbos_state.json`) ni el WebSocket para el Core UI. |

#### Consecuencias positivas

- **Catálogo dinámico:** el IAM Installer descubre fichas nuevas en `servers/` sin reiniciarse — una nueva app se agrega creando su ficha en el directorio correcto.
- **Reconciliación automática:** el drift entre estado declarado y estado real se detecta y corrige en cada ciclo del IAM Installer.
- **Distribución soberana:** las fichas viajan por el SKULL Release Plane firmadas con Ed25519. Los clientes reciben actualizaciones de aplicaciones como nuevas versiones de fichas.
- **Rollback uniforme:** cualquier ficha puede revertirse a su versión anterior con `make rollback FICHA=<nombre>` en < 30 segundos.
- **FICHA_LINTER como guardián:** el validador de fichas (módulo de dominio del IAM Installer) rechaza fichas con errores antes de que lleguen al Release Plane.

#### Consecuencias negativas / trade-offs

- **Curva de aprendizaje para nuevas apps:** agregar una nueva aplicación al stack requiere escribir su ficha en el formato correcto. El FICHA_LINTER ayuda pero la estructura inicial requiere entender el modelo.
- **Formato propietario:** el formato de ficha SBOS no es estándar de la industria. Los contribuidores externos necesitan aprender el formato específico.

**Documentos relacionados:** SBOS-005 §17, SBOS-006 (Sistema de Fichas), SBOS-018 (Estándares)

---

## ADR-009

### Rust para daemons CPU-bound, Go para daemons I/O-bound

**Código:** ADR-009
**Fecha:** 2026-03
**Estado:** ✅ Aceptada
**Autores:** Rust Team Lead, Go Team Lead, Arquitecto Lead
**Documentos relacionados:** SBOS-018 §10–§15, SBOS-010 (bkernel), SBOS-011 (biedata)

#### Contexto

El SBOS tiene ocho daemons soberanos con perfiles de carga de trabajo fundamentalmente diferentes. La decisión de lenguaje para cada daemon debe equilibrar: latencia determinista vs velocidad de desarrollo, control de memoria vs productividad del desarrollador, y ecosistema de librerías específico para cada workload.

#### Decisión

**Rust** para los daemons con requisitos de latencia determinista y sin GC:
- `bkernel` (SBOS Data Kernel): CDC del WAL de PostgreSQL — procesa millones de eventos/día, SLO de latencia < 500ms P99. Una pausa de GC de 50ms durante una transacción grande es inaceptable.
- `biedata` (SBOS Data Integration): ETL transaccional — importaciones Excel de 50K+ filas como transacciones atómicas. Sin GC garantiza que no hay pausas entre extracción y escritura.

**Go** para los daemons I/O-bound con alta concurrencia de red:
- `bcompass` (SBOS AI Tools): orquestación LLM — goroutines por agente (2–4 KB vs 2 MB de thread OS).
- `bsearch` (SBOS Data RAG): Redis Streams consumer groups — fan-out/fan-in nativo con channels.
- `bauth` (SBOS Auth Enforce): HTTP (Keycloak) + XML-RPC (Tryton) + WebSocket (SBOS VDI) — tres protocolos con el mismo scheduler.
- `bhnexus` + `banexus` (SBOS Nexus): 10.000+ conexiones WebSocket concurrentes, probado en producción.

**Go + Python + Bash** para `bos` (SBOS IAM Installer): naturaleza híbrida que requiere los tres paradigmas.

#### Alternativas consideradas

| Alternativa | Por qué se descartó |
|---|---|
| **Rust para todos los daemons** | Tiempo de desarrollo 30–40% mayor para daemons I/O-bound. El borrow checker no aporta beneficio en workloads de espera de red. bcompass requiere iteración rápida en rutas LLM. |
| **Go para todos los daemons** | GC de Go introduce pausas de 0.5–50ms no deterministas. Inaceptable para bkernel (SLO WAL < 500ms P99) y para biedata (ETL transaccional sin interrupción). |
| **Python para orquestación** | Sin el GIL como limitación, Python es adecuado para prototipado. Para producción, arranque 1–3s vs < 50ms de Go, sin binario estático, dependencia de virtualenv. |
| **Java/JVM para CDC** | Debezium (Java) es el referente de CDC, pero su JVM introduce overhead de memoria y pausas GC de JVM que el bkernel Rust evita. chgcap-rs (Rust) es la alternativa explícita por esta razón. |

#### Consecuencias positivas

- **Latencia determinista en CDC:** bkernel Rust procesa eventos WAL sin pausas GC — el SLO de < 500ms P99 es alcanzable con garantía.
- **ETL transaccional seguro:** biedata Rust garantiza atomicidad en importaciones sin interferencia del runtime.
- **Concurrencia eficiente en I/O:** los daemons Go manejan miles de conexiones concurrentes con costo de 2–4 KB por goroutine vs 2 MB de thread OS.
- **Desarrollo iterativo rápido:** los daemons Go (que evolucionan más rápido — nuevas rutas LLM, nuevos patrones de búsqueda) tienen curva de aprendizaje menor.

#### Consecuencias negativas / trade-offs

- **Polyglot stack:** el equipo necesita dominar Rust Y Go, además de Python y Bash. El Bus Factor mínimo para bkernel/biedata (Rust + CDC) es el riesgo más alto — ver SBOS-021-ABF.
- **Borrow checker como barrera:** un desarrollador nuevo en Rust necesita 2–4 semanas de ramp-up antes de ser productivo en bkernel/biedata.
- **Go plugin system:** el sistema de plugins `.so` de Go tiene inestabilidad entre versiones. Solución: fijar versión de Go en CI y mantener interfaz mínima en plugin API.

**Documentos relacionados:** SBOS-018 §10–§15 (stacks completos), SBOS-021-ABF (riesgo de Bus Factor en Rust), SBOS-010 (bkernel Rust), SBOS-011 (biedata Rust)

---

## Registro de cambios

| Versión | Fecha | Autor | Descripción |
|---------|-------|-------|-------------|
| 1.0 | Marzo 2026 | SKULL Team | Documento inicial — ADR-001 a ADR-008, proceso ARB |
| 1.1 | Marzo 2026 | SKULL Team | ADR-009 añadido: Rust vs Go — decisión de lenguaje por daemon |

---

*SKULL · SBOS · SBOS-025-ADR-CATALOG · v1.0 · Marzo 2026*
*Complementa: SBOS-002 (Arquitectura), SBOS-003 (Stack), SBOS-005 (IAM Installer), SBOS-010 (bKernel)*
