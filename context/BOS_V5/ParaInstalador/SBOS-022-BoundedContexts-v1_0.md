# SBOS-022 — Bounded Contexts y Modelo de Mensajería
## Arquitectura de dominios, fuentes de verdad y canales del SBOS

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-022
**Versión:** 1.0
**Estado:** ACTIVO — Complementos en archivos separados
**Extensiones/Complementos:**
  - SBOS-022-CQRS-Sagas.md (CQRS Formal y Patrones Saga — archivo separado permanente)
  - SBOS-022-PGMIG-MigrationPlan-v1_0.md (Plan Migración PostgreSQL Mayor — complemento disponible en archivo separado)
**Documento nuevo** — no reemplaza a ningún documento anterior
**Clasificación:** Especificación Técnica — Arquitectura de Dominios

---

## 1. Por qué este documento existe

El SBOS integra más de veinte aplicaciones de código abierto sobre una infraestructura Kubernetes soberana. Sin un mapa formal de dominios, cada integración nueva introduce ambigüedad: ¿quién es la fuente de verdad del empleado — OrangeHRM o Keycloak? ¿Qué canal uso para notificar a un usuario en tiempo real? ¿Dónde vive el concepto de "orden de compra" — en Tryton o en Saleor?

Este documento responde esas preguntas de forma definitiva usando los conceptos de Domain-Driven Design (DDD) para trazar los límites entre dominios del sistema. No es documentación de arquitectura de alto nivel — eso está en SBOS-002. Es el contrato formal que cada contribuidor consulta antes de escribir una integración nueva.

### Los tres problemas que resuelve

**Problema 1 — Propiedad de datos ambigua.** Sin un mapa de bounded contexts, dos aplicaciones pueden creer que son la fuente de verdad del mismo dato y producir inconsistencias. Este documento define explícitamente qué aplicación posee cada entidad de negocio.

**Problema 2 — Canal de mensajería incorrecto.** El SBOS tiene cinco canales de mensajería distintos, cada uno con garantías diferentes. Usar el canal equivocado puede perder eventos, duplicar notificaciones o crear cuellos de botella. La tabla de decisión de §4 es la respuesta estándar a "¿qué canal uso?".

**Problema 3 — Acoplamiento de servicios sin nombre.** Cuando dos servicios se integran sin nombrar su relación, cualquier cambio en uno puede romper el otro silenciosamente. Este documento nombra las relaciones entre dominios usando terminología DDD estándar.

---

## 2. Los bounded contexts del sistema

Un bounded context es un límite explícito dentro del cual un modelo de dominio particular es válido y consistente. Fuera de ese límite, el mismo concepto puede tener un significado diferente.

---

### BC-01 — Dominio Financiero-Contable

**Servidor lógico:** `dataserver` (appserver para la interfaz)
**Aplicación propietaria:** Tryton ERP

**Entidades de negocio que posee (fuente de verdad):**
- Cuenta contable, asiento contable, libro mayor
- Factura, nota de crédito, nota de débito
- Orden de compra, orden de venta
- Producto / servicio (catálogo financiero)
- Período fiscal, presupuesto

**Entidades que consume de otros contextos (solo lectura):**
- Empleado → desde BC-02 (RRHH) via bKernel
- Cliente / Proveedor → desde BC-03 (Ventas/CRM) via bKernel
- Usuario autenticado → desde BC-04 (Identidad) via JWT

**Eventos que emite al bus:**
- `tryton.invoice.confirmed` — factura confirmada
- `tryton.payment.done` — pago procesado
- `tryton.purchase.created` — orden de compra creada
- `tryton.purchase.confirmed` — orden de compra aprobada
- `tryton.period.closed` — período fiscal cerrado

**Eventos que consume del bus:**
- `orangehrm.employee.created` → crear empleado en nómina
- `espocrm.customer.created` → crear tercero en Tryton
- `keycloak.user.disabled` → suspender acceso del usuario en Tryton

**Relación con otros contextos:**
- Con BC-02 (RRHH): **Customer-Supplier** — BC-02 suministra datos de empleados, BC-01 los consume para nómina. BC-01 no puede modificar empleados.
- Con BC-03 (Ventas): **Customer-Supplier** — BC-03 suministra clientes y oportunidades, BC-01 las consume para facturación.
- Con BC-04 (Identidad): **Conformist** — BC-01 acepta el modelo de identidad de Keycloak sin modificarlo.

---

### BC-02 — Dominio de RRHH

**Servidor lógico:** `appserver`
**Aplicación propietaria:** OrangeHRM

**Entidades de negocio que posee (fuente de verdad):**
- Empleado (persona contratada por la organización)
- Estructura organizacional (departamentos, cargos, jerarquía)
- Contrato de trabajo, período de prueba
- Vacaciones, licencias, ausencias
- Evaluación de desempeño

**Entidades que consume de otros contextos (solo lectura):**
- Usuario autenticado → desde BC-04 (Identidad) via JWT
- Cuenta bancaria del empleado → desde BC-01 (Financiero) via bKernel

**Eventos que emite al bus:**
- `orangehrm.employee.created` — empleado nuevo contratado
- `orangehrm.employee.terminated` — empleado dado de baja
- `orangehrm.employee.updated` — datos del empleado modificados
- `orangehrm.leave.approved` — licencia aprobada

**Eventos que consume del bus:**
- `keycloak.user.created` → vincular usuario KC con empleado (por email)

**Relación con otros contextos:**
- Con BC-04 (Identidad): **Partnership** — comparten el concepto de "persona de la organización". OrangeHRM es la fuente de verdad del empleado; Keycloak es la fuente de verdad del usuario. El vínculo es el email.

---

### BC-03 — Dominio de Ventas y CRM

**Servidor lógico:** `appserver`
**Aplicaciones propietarias:** Saleor (e-commerce / catálogo), EspoCRM (relaciones con clientes)

**Entidades de negocio que posee (fuente de verdad):**
- Cliente (persona u organización que compra)
- Oportunidad de venta, pipeline de ventas
- Cotización, propuesta comercial
- Catálogo de productos para venta (precio de venta)
- Campaña de marketing

**Entidades que consume de otros contextos (solo lectura):**
- Producto / catálogo financiero → desde BC-01 (Financiero) via bKernel
- Usuario autenticado → desde BC-04 (Identidad) via JWT

**Eventos que emite al bus:**
- `espocrm.customer.created` — cliente nuevo registrado
- `saleor.order.placed` — pedido realizado en el e-commerce
- `saleor.order.paid` — pedido pagado

**Eventos que consume del bus:**
- `tryton.invoice.confirmed` → actualizar estado de oportunidad en EspoCRM

**Relación con otros contextos:**
- Con BC-01 (Financiero): **Customer-Supplier** — BC-03 suministra clientes y pedidos, BC-01 los convierte en facturas y asientos.

---

### BC-04 — Dominio de Identidad

**Servidor lógico:** `identityserver`
**Aplicaciones propietarias:** Keycloak, SBOS Auth Enforce

**Entidades de negocio que posee (fuente de verdad):**
- Usuario del sistema (credenciales, atributos de acceso)
- Rol de negocio y sus permisos (`bos_perm_base`, `bos_perm_ui`, `bos_perm_vdi`)
- Sesión de usuario, token de acceso
- Realm, cliente OIDC
- Política de autenticación contextual

**Entidades que consume de otros contextos (solo lectura):**
- Empleado → desde BC-02 (RRHH) via bKernel (para vincular usuario con empleado)

**Eventos que emite al bus:**
- `keycloak.user.created` — usuario nuevo creado en Keycloak
- `keycloak.user.disabled` — usuario deshabilitado
- `keycloak.session.started` — sesión de login iniciada
- `keycloak.role.assigned` — rol asignado a usuario

**Eventos que consume del bus:**
- `orangehrm.employee.terminated` → deshabilitar usuario en Keycloak

**Relación con otros contextos:**
- Con todos los demás contextos: **Shared Kernel** para el JWT. Todos los bounded contexts aceptan el JWT de Keycloak como prueba de identidad sin modificaciones. El JWT es el kernel compartido de identidad del sistema.

**Anti-Corruption Layer:** El IAM Installer actúa como ACL entre Keycloak y el mundo exterior — traduce el modelo de roles del negocio al modelo interno de Keycloak sin exponer las tablas internas de Keycloak.

---

### BC-05 — Dominio de Comunicaciones

**Servidor lógico:** `mailserver`, `appserver` (Mattermost)
**Aplicaciones propietarias:** Postfix, Dovecot, Roundcube, Mattermost, Centrifugo

**Entidades de negocio que posee (fuente de verdad):**
- Buzón de correo electrónico
- Canal de mensajería interna (Mattermost)
- Notificación en tiempo real (Centrifugo WebSocket)
- Historial de conversaciones

**Entidades que consume de otros contextos (solo lectura):**
- Usuario autenticado → desde BC-04 (Identidad) via JWT
- Empleado → desde BC-02 (RRHH) via bKernel (para crear buzón al contratar)

**Eventos que emite al bus:**
- `mattermost.message.sent` — mensaje enviado en canal de equipo

**Eventos que consume del bus:**
- `orangehrm.employee.created` → crear buzón Postfix + canal Mattermost
- `keycloak.user.disabled` → deshabilitar buzón y acceso a Mattermost
- `bcompass.notification.push` → enviar notificación en tiempo real via Centrifugo

**Relación con otros contextos:**
- Con BC-04 (Identidad): **Conformist** — Mattermost y Roundcube usan SSO de Keycloak sin modificaciones.
- Con BC-08 (Plataforma): **Customer-Supplier** — BC-08 activa los buzones vía el IAM Installer.

---

### BC-06 — Dominio de Reportes e Inteligencia

**Servidor lógico:** `reportserver`
**Aplicaciones propietarias:** Apache Superset, Apache Airflow, OpenMetadata

**Entidades de negocio que posee (fuente de verdad):**
- Dashboard y reporte publicado
- Pipeline de datos y su programación
- Catálogo de metadatos de datos
- Linaje de datos

**Entidades que consume de otros contextos (solo lectura):**
- Todos los datos de negocio → desde todos los bounded contexts via réplica de lectura de PostgreSQL
- Usuario autenticado → desde BC-04 (Identidad) via JWT (SSO)

**Eventos que emite al bus:**
- `airflow.pipeline.completed` — pipeline de datos finalizado
- `airflow.pipeline.failed` — pipeline fallido (activa alerta)

**Eventos que consume del bus:**
- `tryton.period.closed` → disparar pipeline de cierre contable
- `orangehrm.employee.created` → actualizar catálogo de metadatos

**Relación con otros contextos:**
- Con todos los contextos productores: **Conformist** — BC-06 solo lee datos, nunca los modifica.
- Es el único bounded context con acceso a la réplica de lectura de PostgreSQL directamente.

---

### BC-07 — Dominio de IA Soberana

**Servidor lógico:** `aiserver`
**Aplicaciones propietarias:** aiserver (Ollama + SBOS AI Tools como orquestador, SBOS Data RAG)

**Entidades de negocio que posee (fuente de verdad):**
- Modelo de lenguaje desplegado y su versión activa
- Índice vectorial Qdrant (embeddings del conocimiento organizacional)
- Sugerencia de IA generada
- Resultado de búsqueda semántica

**Entidades que consume de otros contextos (solo lectura):**
- Documentos, registros y datos → desde todos los bounded contexts via Redis Stream `ai:embed_queue`
- Usuario autenticado → desde BC-04 (Identidad) via JWT

**Eventos que emite al bus:**
- `ai.suggestion.generated` — sugerencia de IA lista para el usuario
- `ai.search.completed` — resultado de búsqueda semántica listo

**Eventos que consume del bus:**
- `bkernel.document.indexed` → vectorizar documento en Qdrant

**Relación con otros contextos:**
- Con BC-08 (Plataforma): **Customer-Supplier** — BC-08 suministra el canal de eventos; BC-07 lo consume para mantener los índices actualizados.
- Con todos los contextos productores: **Anti-Corruption Layer** via SBOS Data RAG — los datos externos se transforman a embeddings sin modificar el modelo de datos de origen.

---

### BC-08 — Dominio de Integración Exterior

**Servidor lógico:** `appserver` (proceso daemon SBOS Data Integration)
**Aplicación propietaria:** SBOS Data Integration

**Entidades de negocio que posee (fuente de verdad):**
- Caja de integración (conector con un sistema externo)
- Mensaje externo recibido y su estado de procesamiento
- Transformación aplicada al mensaje

**Entidades que consume de otros contextos (solo lectura):**
- Esquemas de datos destino → desde BC-01, BC-02, BC-03 (para hacer el mapping)

**Eventos que emite al bus:**
- `biedata.document.received` — documento externo recibido y validado
- `biedata.document.rejected` — documento externo rechazado por validación

**Relación con otros contextos:**
- Con todos los contextos destino: **Anti-Corruption Layer** puro. SBOS Data Integration traduce el modelo externo (SAT, AFIP, DIAN, bancos) al modelo interno del SBOS sin que los contextos destino conozcan el formato externo.

---

### BC-09 — Dominio de Plataforma

**Servidor lógico:** `adminserver`, `monitorserver`, todos los servidores
**Aplicaciones propietarias:** IAM Installer, Kubernetes, bKernel (infraestructura), Release Server

**Entidades de negocio que posee (fuente de verdad):**
- Ficha instalada y su versión activa
- Estado de salud del cluster
- Configuración de infraestructura
- Artefacto de despliegue firmado

**Entidades que consume de otros contextos (solo lectura):**
- Ninguna — BC-09 es la base sobre la que corren todos los demás contextos.

**Eventos que emite al bus:**
- `installer.ficha.installed` — ficha instalada exitosamente
- `installer.ficha.rollback` — rollback de ficha ejecutado
- `bkernel.wal.lag` — lag de replicación del bKernel (métrica)

**Relación con todos los otros contextos:**
- **Shared Kernel** de infraestructura. Todos los bounded contexts dependen del Dominio de Plataforma para existir. BC-09 no depende de ningún otro bounded context.

---

## 3. Mapa de relaciones entre bounded contexts

```
                    ┌─────────────────────────────────────┐
                    │  BC-09 — PLATAFORMA                 │
                    │  IAM Installer · K8s · bKernel       │
                    │  (Shared Kernel de infraestructura) │
                    └──────────────┬──────────────────────┘
                                   │ suministra infraestructura a todos
              ┌────────────────────┼────────────────────┐
              │                    │                    │
   ┌──────────▼──────────┐  ┌──────▼──────────┐  ┌─────▼───────────────┐
   │  BC-04 — IDENTIDAD  │  │  BC-05 — COMMS  │  │  BC-06 — REPORTES   │
   │  Keycloak · RolFrwk │  │  Mail · Matterms│  │  Superset · Airflow  │
   │  (Shared Kernel JWT)│  │  Centrifugo     │  │  OpenMetadata        │
   └──────────┬──────────┘  └──────┬──────────┘  └──────────────────────┘
              │ JWT a todos         │ SSO desde BC-04
              │
   ┌──────────▼──────────┐  ┌─────────────────────┐
   │  BC-02 — RRHH        │  │  BC-03 — VENTAS/CRM  │
   │  OrangeHRM           │  │  Saleor · EspoCRM    │
   └──────────┬──────────┘  └──────────┬──────────┘
              │ empleados               │ clientes / pedidos
              │ Customer-Supplier       │ Customer-Supplier
              ▼                         ▼
   ┌────────────────────────────────────────────────┐
   │  BC-01 — FINANCIERO-CONTABLE                    │
   │  Tryton ERP                                     │
   │  (Fuente de verdad del dinero)                  │
   └────────────────────────────────────────────────┘
              │
              │ datos de negocio → embeddings
              ▼
   ┌──────────────────────┐    ┌──────────────────────┐
   │  BC-07 — IA SOBERANA │    │  BC-08 — INTEGRACIÓN │
   │  aiserver · Qdrant   │    │  SBOS Data Integration            │
   │  SBOS Data RAG             │    │  (ACL con exterior)   │
   └──────────────────────┘    └──────────────────────┘
```

### Tipos de relación DDD usados en el SBOS

| Tipo | Descripción | Ejemplo en SBOS |
|---|---|---|
| **Customer-Supplier** | El proveedor produce datos que el cliente consume. El cliente no puede modificar los datos del proveedor. | BC-02 (RRHH) → BC-01 (Financiero): OrangeHRM produce empleados, Tryton los consume |
| **Shared Kernel** | Dos o más contextos comparten un subconjunto de modelo sin duplicarlo. | El JWT de Keycloak es el Shared Kernel de identidad de todo el sistema |
| **Conformist** | Un contexto acepta el modelo de otro sin modificarlo. | BC-01 acepta el JWT de Keycloak sin intentar reimplementar autenticación |
| **Anti-Corruption Layer** | Un contexto traduce activamente el modelo externo al modelo interno para proteger su integridad. | SBOS Data Integration traduce CFDIs mexicanos al modelo Tryton; SBOS Data RAG traduce datos a embeddings |
| **Partnership** | Dos contextos co-evolucionan coordinadamente. | BC-02 (RRHH) y BC-04 (Identidad): el empleado y el usuario KC son el mismo humano, coordinado por email |

---

## 4. La tabla de decisión de canal de mensajería

Esta tabla responde la pregunta más frecuente de cualquier desarrollador que integra dos componentes del SBOS: **¿qué canal uso?**

| Caso de uso | Canal correcto | Garantía | Latencia típica | Referencia |
|---|---|---|---|---|
| App escribe dato en PostgreSQL → sync a otra app | WAL + bKernel | At-least-once | < 500ms (P99) | SBOS-010 |
| Nuevo documento → indexar en SBOS Data RAG | Redis Stream `bkernel:index_queue` | At-least-once | < 1s | SBOS-013 |
| Nuevo dato → vectorizar en Qdrant | Redis Stream `ai:embed_queue` | At-least-once | < 2s | SBOS-015 |
| Notificación en tiempo real al usuario (toast, badge) | Centrifugo WebSocket | Best-effort | < 100ms | SBOS-012 |
| Workflow de negocio multi-paso con aprobación humana | SBOS AI Tools route | Exactly-once con compensación | Variable (humano en el loop) | SBOS-014 |
| Búsqueda asíncrona de alto volumen | RabbitMQ | At-least-once | Variable | SBOS-003 |
| Evento de seguridad (login fallido, drift detectado) | Wazuh agent directo | Best-effort + persistencia SIEM | < 5s | SBOS-003 |
| Sincronización de roles y permisos en Keycloak | IAM Installer API call directo | Exactly-once (transaccional) | < 2s | SBOS-005 |
| Integración con sistema externo (SAT, banco, ERP legacy) | SBOS Data Integration caja | At-least-once + validación | Variable (externo) | SBOS-011 |
| Alerta operacional (disco lleno, pod caído) | Alertmanager → PagerDuty/Slack | At-least-once | < 30s | SBOS-024 |

### Regla de decisión rápida

```
¿El dato nace en PostgreSQL?
  → Sí → bKernel WAL es el canal natural

¿Necesitas que un humano apruebe algo en el medio?
  → Sí → SBOS AI Tools route con approval_gate

¿Es una notificación visual instantánea al usuario?
  → Sí → Centrifugo WebSocket

¿Viene de fuera del sistema (sistema externo)?
  → Sí → SBOS Data Integration caja

¿Es un workflow de alto volumen sin intervención humana?
  → Sí → RabbitMQ

¿Es un evento de seguridad que debe persistir en SIEM?
  → Sí → Wazuh agent directo
```

---

## 5. Módulos del IAM Installer: dominio vs orquestación

Los 15 módulos Python del IAM Installer (documentados en SBOS-005) se dividen en dos capas de responsabilidad distintas. Esta separación es la diferencia entre código que contiene reglas de negocio y código que coordina flujos.

### 5.1 Módulos de Dominio

Contienen las reglas de qué es válido y qué no. No llaman a servicios externos. Son puros y testeables sin infraestructura.

| Módulo | Responsabilidad de dominio |
|---|---|
| `ficha_validator` | Qué hace una ficha válida. Las reglas del schema, los campos obligatorios, las licencias aceptables. |
| `role_calculator` | Cómo se calculan los permisos `bos_perm_base`, `bos_perm_ui`, `bos_perm_vdi` a partir de los atributos de un rol. |
| `dependency_resolver` | Cómo se resuelve el grafo de dependencias entre fichas. Qué es un ciclo de dependencia y por qué es inválido. |
| `drift_detector` | Qué constituye un drift entre el estado deseado (la ficha) y el estado real del sistema. |
| `health_evaluator` | Cómo se interpreta un resultado de health check y cuándo una ficha está sana vs degradada. |
| `signature_verifier` | Qué es una firma Ed25519 válida para un artefacto del sistema. |

### 5.2 Módulos de Orquestación

Coordinan flujos entre dominios. Llaman a servicios externos (Keycloak API, kubectl, PostgreSQL). Son testeables con mocks.

| Módulo | Responsabilidad de orquestación |
|---|---|
| `keycloak_sync` | Coordina la creación de realms, clientes y roles en Keycloak según las fichas instaladas. |
| `k8s_deployer` | Coordina el despliegue de pods en Kubernetes. Traduce la ficha a objetos K8s. |
| `vault_provisioner` | Coordina la creación de secretos en Vault y su montaje en los pods. |
| `bkernel_configurator` | Coordina la carga de reglas YAML en el bKernel al instalar una ficha nueva. |
| `rollout_controller` | Coordina el rollout canary: avance, halt y rollback según los criterios definidos en SBOS-024. |
| `reconciler` | Coordina la reconciliación periódica entre el estado deseado y el estado real. |
| `installer_saga` | Coordina la Saga de instalación completa: ejecuta los módulos de orquestación en orden y maneja compensaciones. |
| `release_fetcher` | Coordina la descarga y verificación de artefactos desde el Release Server. |
| `event_emitter` | Coordina la emisión de eventos al bus (bKernel, Redis) después de cada operación del Installer. |

### 5.3 La separación en la práctica

Cuando se agrega lógica nueva al IAM Installer, la pregunta es:

- **¿Esta lógica dice qué es correcto?** → Va en un módulo de dominio. No importa Keycloak, no importa kubectl. Solo valida, calcula, decide.
- **¿Esta lógica hace que las cosas sucedan?** → Va en un módulo de orquestación. Llama APIs, escribe en PostgreSQL, despliega pods.

Esta separación garantiza que las reglas de negocio sean testeables sin levantar infraestructura y que los módulos de orquestación sean sustituibles si cambia una herramienta del stack.

---

## 6. Catálogo de casos de uso del sistema

Los casos de uso del SBOS son las operaciones formales que el IAM Installer puede ejecutar. Cada uno es una Saga de orquestación con compensaciones definidas.

---

### CU-01 — Instalar una ficha nueva

**Pre-condiciones:**
- La ficha existe en el catálogo del Release Server con firma Ed25519 válida
- Todas las fichas de las que depende están instaladas y sanas
- Hay recursos K8s disponibles en el servidor lógico destino

**Post-condiciones:**
- El pod de la ficha está Running en K8s
- El health check de la ficha responde 200
- El cliente OIDC de la ficha existe en Keycloak
- Los roles de la ficha existen en Keycloak con los atributos correctos
- Las reglas bKernel de la ficha están activas
- El evento `installer.ficha.installed` fue emitido al bus

**Flujo normal:**
1. `release_fetcher` descarga el artefacto y verifica la firma
2. `dependency_resolver` verifica que las dependencias están satisfechas
3. `ficha_validator` valida el schema completo de la ficha
4. `vault_provisioner` crea los secretos necesarios en Vault
5. `keycloak_sync` crea el cliente OIDC y los roles en Keycloak
6. `k8s_deployer` aplica los manifests en el namespace correcto
7. `bkernel_configurator` carga las reglas de la ficha en el bKernel
8. `health_evaluator` espera el health check (timeout: 120s)
9. `event_emitter` emite `installer.ficha.installed`

**Estrategia de compensación si falla un paso:**

| Paso que falla | Compensación |
|---|---|
| vault_provisioner | Eliminar secretos creados parcialmente |
| keycloak_sync | Eliminar cliente OIDC y roles creados |
| k8s_deployer | `kubectl delete` de los manifests aplicados |
| bkernel_configurator | Descargar las reglas del bKernel |
| health_evaluator (timeout) | Ejecutar compensación completa + marcar ficha como DEGRADED |

---

### CU-02 — Actualizar una ficha existente

**Pre-condiciones:**
- La versión nueva de la ficha es semánticamente mayor a la instalada
- La ficha está en estado HEALTHY antes de la actualización

**Post-condiciones:**
- El pod corre la versión nueva de la imagen
- El health check de la nueva versión responde 200
- Los cambios de schema de Keycloak (roles nuevos, atributos modificados) están aplicados

**Flujo normal:**
1. `release_fetcher` descarga la versión nueva
2. `ficha_validator` valida la nueva versión
3. `rollout_controller` inicia rollout canary: 10% del tráfico a la nueva versión
4. `health_evaluator` monitorea métricas durante 15 minutos (criterios en SBOS-024 §4)
5. Si métricas OK: `rollout_controller` avanza al 50%, luego al 100%
6. `keycloak_sync` aplica los cambios de roles/atributos de la nueva versión
7. `bkernel_configurator` recarga las reglas actualizadas
8. `event_emitter` emite `installer.ficha.updated`

**Estrategia de compensación:**
- Si métricas degradadas en cualquier porcentaje → `rollout_controller` revierte al 100% de la versión anterior en < 30 segundos

---

### CU-03 — Reparar una ficha degradada

**Pre-condiciones:**
- La ficha está en estado DEGRADED (health check fallando)
- El pod existe pero no responde correctamente

**Post-condiciones:**
- El pod está Running y el health check responde 200
- La causa del degraded está registrada en el log del Installer

**Flujo normal:**
1. `drift_detector` analiza la diferencia entre estado deseado y estado real
2. Si es drift de configuración: `reconciler` aplica el estado deseado
3. Si es fallo del pod: `k8s_deployer` hace `kubectl rollout restart`
4. `health_evaluator` verifica recovery (timeout: 60s)
5. Si no hay recovery: escala a CU-04 (Rollback)

---

### CU-04 — Rollback de una ficha a la versión anterior

**Pre-condiciones:**
- Existe una versión anterior de la ficha en el historial del Release Server
- La ficha está en estado DEGRADED o se activó un halt de rollout

**Post-condiciones:**
- El pod corre la versión anterior
- Los cambios de Keycloak de la versión nueva fueron revertidos
- El evento `installer.ficha.rollback` fue emitido

**Flujo normal:**
1. `release_fetcher` descarga la versión anterior del Release Server
2. `k8s_deployer` aplica la imagen anterior (tiempo objetivo: < 30s)
3. `keycloak_sync` revierte los cambios de roles de la versión fallida
4. `bkernel_configurator` recarga las reglas de la versión anterior
5. `health_evaluator` confirma que el health check pasa
6. `event_emitter` emite `installer.ficha.rollback` con causa documentada

---

### CU-05 — Expandir el cluster con un servidor nuevo

**Pre-condiciones:**
- El servidor nuevo tiene el OS base instalado (Ubuntu 22.04 LTS)
- El servidor nuevo está en la red privada del cluster
- El tipo de servidor (appserver, dataserver, etc.) está definido

**Post-condiciones:**
- El servidor es un nodo K8s activo en el cluster
- Las fichas correspondientes al tipo de servidor están instaladas
- El servidor aparece en el monitoreo de Prometheus/Grafana

**Flujo normal:**
1. `installer_saga` ejecuta la secuencia de bootstrapping del servidor
2. Instala los prerrequisitos del SO (containerd, kubeadm)
3. Une el nodo al cluster K8s existente
4. Aplica los labels y taints correspondientes al tipo de servidor
5. Ejecuta CU-01 para cada ficha del perfil del servidor
6. `event_emitter` emite `installer.server.added`

---

## 7. Fuentes de verdad por entidad de negocio

Referencia rápida para cualquier duda sobre dónde vive un dato:

| Entidad de negocio | Fuente de verdad | Bounded Context | Cómo accederla |
|---|---|---|---|
| Usuario del sistema (credenciales) | Keycloak | BC-04 — Identidad | JWT / Keycloak Admin API |
| Empleado (persona contratada) | OrangeHRM | BC-02 — RRHH | OrangeHRM API / bKernel event |
| Cliente / Prospecto | EspoCRM | BC-03 — Ventas | EspoCRM API / bKernel event |
| Cuenta contable | Tryton | BC-01 — Financiero | Tryton XML-RPC / bKernel event |
| Factura | Tryton | BC-01 — Financiero | Tryton XML-RPC / bKernel event |
| Orden de compra | Tryton | BC-01 — Financiero | Tryton XML-RPC |
| Orden de venta / Pedido e-commerce | Saleor | BC-03 — Ventas | Saleor GraphQL |
| Producto (catálogo financiero) | Tryton | BC-01 — Financiero | Tryton XML-RPC |
| Mensaje de chat interno | Mattermost | BC-05 — Comunicaciones | Mattermost API |
| Email corporativo | Postfix / Dovecot | BC-05 — Comunicaciones | IMAP/SMTP |
| Dashboard de reportes | Apache Superset | BC-06 — Reportes | Superset API |
| Embedding vectorial | Qdrant | BC-07 — IA Soberana | Qdrant REST API |
| Ficha instalada | IAM Installer | BC-09 — Plataforma | Installer API / make status |
| Secreto / credencial de servicio | HashiCorp Vault | BC-09 — Plataforma | Vault API (lease dinámico) |
| Certificado TLS | cert-manager | BC-09 — Plataforma | K8s Secret (auto-renovado) |

---

## 8. Registro de cambios

| Versión | Fecha | Autor | Descripción |
|---|---|---|---|
| 1.0 | Marzo 2026 | SKULL Team | Documento inicial — bounded contexts, tabla de mensajería, módulos IAM, catálogo de casos de uso |

---

*SKULL · SBOS · SBOS-022-BOUNDED-CONTEXTS · v1.0 · Marzo 2026*
