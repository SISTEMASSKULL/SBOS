# SBOS-030-BOUNDED-CONTEXTS
## Bounded Contexts, Modelo de Mensajería y Casos de Uso — Estándar HUMAN-DOC
### SKULL · SBOS · v1.0 · Abril 2026

---

## 1. Propósito

Mapa formal de dominios DDD que resuelve 3 problemas: propiedad de datos ambigua (qué app posee cada entidad), canal de mensajería incorrecto (5 canales con garantías distintas), acoplamiento sin nombre (relaciones DDD formales).

## 2. Los 9 Bounded Contexts

### BC-01 — Financiero-Contable
**App:** Tryton ERP. **Posee:** cuenta contable, factura, orden compra/venta, producto/servicio, período fiscal. **Consume:** empleado (BC-02 vía bKernel), cliente (BC-03 vía bKernel), JWT (BC-04). **Emite:** tryton.invoice.confirmed, tryton.payment.done, tryton.purchase.confirmed, tryton.period.closed. **Relaciones:** Customer-Supplier con BC-02 y BC-03, Conformist con BC-04.

### BC-02 — RRHH
**App:** OrangeHRM. **Posee:** empleado, estructura organizacional, contrato trabajo, vacaciones, evaluación. **Emite:** orangehrm.employee.created/terminated/updated, orangehrm.leave.approved. **Relaciones:** Partnership con BC-04 (empleado↔usuario vinculados por email).

### BC-03 — Ventas y CRM
**Apps:** Saleor + EspoCRM. **Posee:** cliente, oportunidad, cotización, catálogo venta, campaña. **Emite:** espocrm.customer.created, saleor.order.placed/paid. **Relaciones:** Customer-Supplier con BC-01.

### BC-04 — Identidad
**Apps:** Keycloak + bauth. **Posee:** usuario sistema, rol/permisos, sesión, realm, política auth. **Emite:** keycloak.user.created/disabled, keycloak.session.started, keycloak.role.assigned. **Relaciones:** Shared Kernel (JWT) con todos los BCs. ACL vía IAM Installer.

### BC-05 — Comunicaciones
**Apps:** Postfix, Dovecot, Roundcube, Mattermost, Centrifugo. **Posee:** buzón email, canal mensajería, notificación real-time. **Consume:** orangehrm.employee.created → crear buzón, keycloak.user.disabled → deshabilitar. **Relaciones:** Conformist con BC-04 (SSO).

### BC-06 — Reportes e Inteligencia
**Apps:** Superset, Airflow, OpenMetadata. **Posee:** dashboards, pipelines datos, catálogo metadatos, linaje datos. **Relaciones:** Conformist con todos (solo lee, nunca modifica). Único BC con acceso a réplica lectura PostgreSQL.

### BC-07 — IA Soberana
**Apps:** aiserver (Ollama + bCompass + bSearch). **Posee:** modelo LLM desplegado, índice vectorial Qdrant, sugerencia IA. **Consume:** Redis Stream ai:embed_queue desde bKernel. **Relaciones:** ACL vía bSearch/Embedding Worker (datos → embeddings sin modificar origen).

### BC-08 — Integración Exterior
**App:** biedata. **Posee:** caja integración, mensaje externo, transformación. **Relaciones:** ACL puro con exterior (traduce CFDI/SIAT/bancos al modelo interno).

### BC-09 — Plataforma
**Apps:** IAM Installer, K8s, bKernel (infra), Release Server. **Posee:** ficha instalada, salud cluster, config infra, artefacto firmado. **Relaciones:** Shared Kernel de infraestructura (todos dependen de BC-09, BC-09 no depende de nadie).

## 3. Mapa de Relaciones DDD

```
BC-09 PLATAFORMA (Shared Kernel infra → todos)
  │
  ├── BC-04 IDENTIDAD (Shared Kernel JWT → todos)
  │     ├── Partnership con BC-02 (RRHH)
  │     └── Conformist desde BC-01, BC-03, BC-05, BC-06
  │
  ├── BC-02 RRHH ──Customer-Supplier──► BC-01 FINANCIERO
  ├── BC-03 VENTAS ─Customer-Supplier──► BC-01 FINANCIERO
  │
  ├── BC-07 IA ←── ACL ←── todos los BCs (embeddings)
  └── BC-08 INTEGRACIÓN ←── ACL ←── exterior (SIAT, bancos, SAT)
```

| Tipo DDD | Significado | Ejemplo SBOS |
|---|---|---|
| Customer-Supplier | Proveedor produce, cliente consume, sin modificar | BC-02→BC-01: empleados para nómina |
| Shared Kernel | Subconjunto compartido sin duplicar | JWT de KC = identidad de todo el sistema |
| Conformist | Acepta modelo ajeno sin modificar | BC-01 acepta JWT sin reimplementar auth |
| Anti-Corruption Layer | Traduce modelo externo → interno | biedata: CFDI→Tryton; bSearch: datos→embeddings |
| Partnership | Co-evolucionan coordinados | BC-02 y BC-04: empleado=usuario, vínculo por email |

## 4. Tabla de Decisión de Canal de Mensajería

| Caso de uso | Canal | Garantía | Latencia |
|---|---|---|---|
| App escribe en PG → sync otra app | WAL + bKernel | At-least-once | < 500ms P99 |
| Nuevo documento → indexar bSearch | Redis Stream bkernel:index_queue | At-least-once | < 1s |
| Nuevo dato → vectorizar Qdrant | Redis Stream ai:embed_queue | At-least-once | < 2s |
| Notificación real-time usuario | Centrifugo WebSocket | Best-effort | < 100ms |
| Workflow multi-paso con aprobación | bCompass route | Exactly-once + compensación | Variable (HITL) |
| Evento seguridad | Wazuh agent | Best-effort + SIEM | < 5s |
| Sync roles KC | IAM Installer API call | Exactly-once (transaccional) | < 2s |
| Integración sistema externo | biedata caja | At-least-once + validación | Variable |
| Alerta operacional | Alertmanager → PagerDuty/Slack | At-least-once | < 30s |

**Regla rápida:** ¿Es dato interno entre apps? → bKernel WAL. ¿Es notificación al usuario? → Centrifugo. ¿Es dato desde/hacia exterior? → biedata. ¿Es workflow con aprobación? → bCompass.

## 5. Casos de Uso del Sistema (Sagas con Compensación)

### CU-01 — Instalar ficha nueva
9 pasos: release_fetcher → dependency_resolver → ficha_validator → vault_provisioner → keycloak_sync → k8s_deployer → bkernel_configurator → health_evaluator → event_emitter. Compensación por paso (vault: eliminar secretos, KC: eliminar cliente, K8s: delete manifests).

### CU-02 — Actualizar ficha existente
Rollout canary: 10% → monitor 15min → 50% → 100%. Compensación: revert < 30s a versión anterior si métricas degradadas.

### CU-03 — Reparar ficha degradada
drift_detector → reconciler → kubectl rollout restart → health check (60s). Si no recovery → escala a CU-04.

### CU-04 — Rollback a versión anterior
release_fetcher (versión anterior) → k8s_deployer (< 30s) → keycloak_sync (revert roles) → bkernel_configurator (reglas anteriores) → event ficha.rollback.

### CU-05 — Expandir cluster con servidor nuevo
Bootstrap OS → K8s join → labels/taints → CU-01 por cada ficha del perfil → event server.added.

## 6. Fuentes de Verdad por Entidad

| Entidad | Fuente | BC |
|---|---|---|
| Usuario (credenciales) | Keycloak | BC-04 |
| Empleado | OrangeHRM | BC-02 |
| Cliente/Prospecto | EspoCRM | BC-03 |
| Cuenta contable | Tryton | BC-01 |
| Factura | Tryton | BC-01 |
| Producto (catálogo financiero) | Tryton | BC-01 |
| Pedido e-commerce | Saleor | BC-03 |
| Email corporativo | Postfix/Dovecot | BC-05 |
| Dashboard reportes | Superset | BC-06 |
| Embedding vectorial | Qdrant | BC-07 |
| Ficha instalada | IAM Installer | BC-09 |
| Secreto/credencial | Vault | BC-09 |

---

## §7 — ENRIQUECIMIENTO V5: Bounded Contexts Expandidos, Módulos IAM y Sagas Detalladas

### V5-1: Bounded Contexts con Servidores, Eventos y Entidades Detalladas (desde SBOS-022 v1.0)

#### BC-01 — Dominio Financiero-Contable

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

#### BC-02 — Dominio de RRHH

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

#### BC-03 — Dominio de Ventas y CRM

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

#### BC-04 — Dominio de Identidad

**Servidor lógico:** `identityserver`
**Aplicaciones propietarias:** Keycloak, SBOS Auth Enforce (bauth)

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
- **Anti-Corruption Layer:** El IAM Installer actúa como ACL entre Keycloak y el mundo exterior — traduce el modelo de roles del negocio al modelo interno de Keycloak sin exponer las tablas internas de Keycloak.

---

#### BC-05 — Dominio de Comunicaciones

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
- Con BC-09 (Plataforma): **Customer-Supplier** — BC-09 activa los buzones vía el IAM Installer.

---

#### BC-06 — Dominio de Reportes e Inteligencia

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

#### BC-07 — Dominio de IA Soberana

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
- Con BC-09 (Plataforma): **Customer-Supplier** — BC-09 suministra el canal de eventos; BC-07 lo consume para mantener los índices actualizados.
- Con todos los contextos productores: **Anti-Corruption Layer** via SBOS Data RAG — los datos externos se transforman a embeddings sin modificar el modelo de datos de origen.

---

#### BC-08 — Dominio de Integración Exterior

**Servidor lógico:** `appserver` (proceso daemon SBOS Data Integration)
**Aplicación propietaria:** SBOS Data Integration (biedata)

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

#### BC-09 — Dominio de Plataforma

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

### V5-2: Mapa de Relaciones DDD Expandido (desde SBOS-022 v1.0)

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
   │  Keycloak · bauth   │  │  Mail · Mattermost│  │  Superset · Airflow │
   │  (Shared Kernel JWT)│  │  Centrifugo      │  │  OpenMetadata       │
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
   │  aiserver · Qdrant   │    │  biedata              │
   │  SBOS Data RAG       │    │  (ACL con exterior)   │
   └──────────────────────┘    └──────────────────────┘
```

### Tipos de relación DDD usados en el SBOS

| Tipo | Descripción | Ejemplo en SBOS |
|---|---|---|
| **Customer-Supplier** | El proveedor produce datos que el cliente consume. El cliente no puede modificar los datos del proveedor. | BC-02 (RRHH) → BC-01 (Financiero): OrangeHRM produce empleados, Tryton los consume |
| **Shared Kernel** | Dos o más contextos comparten un subconjunto de modelo sin duplicarlo. | El JWT de Keycloak es el Shared Kernel de identidad de todo el sistema |
| **Conformist** | Un contexto acepta el modelo de otro sin modificarlo. | BC-01 acepta el JWT de Keycloak sin intentar reimplementar autenticación |
| **Anti-Corruption Layer** | Un contexto traduce activamente el modelo externo al modelo interno para proteger su integridad. | biedata traduce CFDIs mexicanos al modelo Tryton; SBOS Data RAG traduce datos a embeddings |
| **Partnership** | Dos contextos co-evolucionan coordinadamente. | BC-02 (RRHH) y BC-04 (Identidad): el empleado y el usuario KC son el mismo humano, coordinado por email |

---

### V5-3: Tabla de Decisión de Canal de Mensajería Expandida (desde SBOS-022 v1.0)

| Caso de uso | Canal correcto | Garantía | Latencia típica | Referencia |
|---|---|---|---|---|
| App escribe dato en PostgreSQL → sync a otra app | WAL + bKernel | At-least-once | < 500ms (P99) | SBOS-010 |
| Nuevo documento → indexar en bSearch | Redis Stream `bkernel:index_queue` | At-least-once | < 1s | SBOS-013 |
| Nuevo dato → vectorizar en Qdrant | Redis Stream `ai:embed_queue` | At-least-once | < 2s | SBOS-015 |
| Notificación en tiempo real al usuario (toast, badge) | Centrifugo WebSocket | Best-effort | < 100ms | SBOS-012 |
| Workflow de negocio multi-paso con aprobación humana | bCompass route | Exactly-once con compensación | Variable (humano en el loop) | SBOS-014 |
| Búsqueda asíncrona de alto volumen | RabbitMQ | At-least-once | Variable | SBOS-003 |
| Evento de seguridad (login fallido, drift detectado) | Wazuh agent directo | Best-effort + persistencia SIEM | < 5s | SBOS-003 |
| Sincronización de roles y permisos en Keycloak | IAM Installer API call directo | Exactly-once (transaccional) | < 2s | SBOS-005 |
| Integración con sistema externo (SAT, banco, ERP legacy) | biedata caja | At-least-once + validación | Variable (externo) | SBOS-011 |
| Alerta operacional (disco lleno, pod caído) | Alertmanager → PagerDuty/Slack | At-least-once | < 30s | SBOS-024 |

### Regla de decisión rápida

```
¿El dato nace en PostgreSQL?
  → Sí → bKernel WAL es el canal natural

¿Necesitas que un humano apruebe algo en el medio?
  → Sí → bCompass route con approval_gate

¿Es una notificación visual instantánea al usuario?
  → Sí → Centrifugo WebSocket

¿Viene de fuera del sistema (sistema externo)?
  → Sí → biedata caja

¿Es un workflow de alto volumen sin intervención humana?
  → Sí → RabbitMQ

¿Es un evento de seguridad que debe persistir en SIEM?
  → Sí → Wazuh agent directo
```

---

### V5-4: Módulos del IAM Installer — Dominio vs Orquestación (desde SBOS-022 v1.0)

Los 15 módulos Python del IAM Installer se dividen en dos capas de responsabilidad:

#### Módulos de Dominio
Contienen las reglas de qué es válido y qué no. No llaman a servicios externos. Puros y testeables sin infraestructura.

| Módulo | Responsabilidad de dominio |
|---|---|
| `ficha_validator` | Qué hace una ficha válida. Las reglas del schema, los campos obligatorios, las licencias aceptables. |
| `role_calculator` | Cómo se calculan los permisos `bos_perm_base`, `bos_perm_ui`, `bos_perm_vdi` a partir de los atributos de un rol. |
| `dependency_resolver` | Cómo se resuelve el grafo de dependencias entre fichas. Qué es un ciclo de dependencia y por qué es inválido. |
| `drift_detector` | Qué constituye un drift entre el estado deseado (la ficha) y el estado real del sistema. |
| `health_evaluator` | Cómo se interpreta un resultado de health check y cuándo una ficha está sana vs degradada. |
| `signature_verifier` | Qué es una firma Ed25519 válida para un artefacto del sistema. |

#### Módulos de Orquestación
Coordinan flujos entre dominios. Llaman a servicios externos (Keycloak API, kubectl, PostgreSQL). Testeables con mocks.

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

#### La separación en la práctica

Cuando se agrega lógica nueva al IAM Installer, la pregunta es:

- **¿Esta lógica dice qué es correcto?** → Va en un módulo de dominio. No importa Keycloak, no importa kubectl. Solo valida, calcula, decide.
- **¿Esta lógica hace que las cosas sucedan?** → Va en un módulo de orquestación. Llama APIs, escribe en PostgreSQL, despliega pods.

---

### V5-5: Sagas Detalladas con Pre-condiciones, Post-condiciones y Compensaciones (desde SBOS-022 v1.0)

#### CU-01 — Instalar una ficha nueva

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

#### CU-02 — Actualizar una ficha existente

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
4. `health_evaluator` monitorea métricas durante 15 minutos
5. Si métricas OK: `rollout_controller` avanza al 50%, luego al 100%
6. `keycloak_sync` aplica los cambios de roles/atributos de la nueva versión
7. `bkernel_configurator` recarga las reglas actualizadas
8. `event_emitter` emite `installer.ficha.updated`

**Estrategia de compensación:**
- Si métricas degradadas en cualquier porcentaje → `rollout_controller` revierte al 100% de la versión anterior en < 30 segundos

#### CU-03 — Reparar una ficha degradada

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

#### CU-04 — Rollback de una ficha a la versión anterior

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

#### CU-05 — Expandir el cluster con un servidor nuevo

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

### V5-6: Fuentes de Verdad por Entidad de Negocio (desde SBOS-022 v1.0)

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

## §8 — ENRIQUECIMIENTO V7: Reconceptualización de Dominios y Alineación con BitmaskBundle v3

### V7-1: Los 9 Dominios de Autenticación (desde V7 Dominios)

El SBOS reconoce 9 dominios de autenticación según estándares internacionales (NIST SP 800-63, ISO/IEC 27001:2022, ISO/IEC 24760, IEEE 802.1X, FIDO2). Los 9 bounded contexts del SBOS se asignan a estos dominios:

| Dominio de Autenticación | Estándar principal | BCs relacionados | Evaluador | Estado en SBOS |
|---|---|---|---|---|
| **Lógico** | NIST SP 800-63B, ISO/IEC 24760 | BC-04 (Identidad), BC-01/02/03 (Apps) | Keycloak + LogicalDomainMask | Parcial — solo Tryton |
| **Físico** | ISO/IEC 27001 A.7, NIST SP 800-116 | BC-09 (Plataforma) — endpoints | banexus + PhysicalDomainMask | Implementado |
| **Financiero** | PCI-DSS, ISO 27001 A.5.3, NIST AC-5 | BC-01 (Financiero) | Tryton Button Rules + FinancialDomainMask | Sin máscara propia en bAuth |
| **De red** | IEEE 802.1X, RFC 2865 | BC-09 (Plataforma) — infraestructura | Infraestructura de red | Implícito |
| **De aplicación** | OAuth 2.0, OIDC, ISO/IEC 29146 | BC-04, BC-01/02/03 | trytond-auth-keycloak (solo Tryton) | Parcial |
| **Biométrico** | ISO/IEC 30107, FIDO2 | BC-04 (Identidad), BC-09 (Físico) | N/A — no implementado | Futuro |
| **Federado** | NIST SP 800-63C, eIDAS | BC-04 (Identidad) — JWT | Keycloak JWT | Implementado |
| **Organizacional** | ISO 27001 A.6, NIST PS | BC-02 (RRHH), BC-04 | RolTemplate | Parcial |
| **Normativo** | RGPD, SOX, PCI-DSS | Todos los BCs | bauth_db + Wazuh | Parcial (audit log) |

### V7-2: BitmaskBundle v3 — Alineación con Bounded Contexts (desde V7 Dominios)

La reconceptualización V7 transforma el modelo de permisos de tecnología-concreta a dominio-abstracto. Cada bounded context se alinea con un registro del `BitmaskBundle v3`:

```go
// BitmaskBundle v3 — modelo reconceptualizado por dominios abstractos
// SKULL · SBOS · bAuth · Abril 2026
type BitmaskBundle struct {
    // DOMINIO FÍSICO — Zonas físicas, actuadores, hardware
    // Evaluado por: banexus
    // BC relacionado: BC-09 (Plataforma — endpoints físicos)
    PhysicalDomainMask uint64 `json:"bos_physical_mask"`

    // DOMINIO LÓGICO — Zonas de negocio (no aplicaciones)
    // Evaluado por: LogicalDomainEvaluator (por construir)
    // BC relacionado: BC-04 + BC-01/02/03 (aplicaciones)
    // El evaluador resuelve zona → aplicaciones vía zone_application_map
    LogicalDomainMask uint64 `json:"bos_logical_mask"`

    // DOMINIO FINANCIERO — Límites, aprobaciones, SoD financiero
    // Evaluado por: FinancialDomainEvaluator (por diseñar)
    // BC relacionado: BC-01 (Financiero-Contable)
    FinancialDomainMask uint64 `json:"bos_financial_mask,omitempty"`
}
```

### V7-3: Mapa de Bits Lógicos — Zonas de Negocio vs BCs (desde V7 Dominios)

La `LogicalDomainMask` NO codifica aplicaciones (Tryton, Saleor, OrangeHRM). Codifica **zonas de negocio** que se resuelven a aplicaciones en cada BC:

```
LogicalDomainMask bit assignments:

Zona CONTABILIDAD (BC-01 Financiero-Contable):
  Bit 0:  CONTABILIDAD_READ    — leer registros contables (Tryton + Superset + Paperless)
  Bit 1:  CONTABILIDAD_WRITE   — crear/editar registros contables (Tryton)
  Bit 2:  CONTABILIDAD_APPROVE — aprobar asientos/pagos (SoD: no puede tener WRITE simultáneo)
  Bit 3:  CONTABILIDAD_AUDIT   — acceso a logs de auditoría contable

Zona RRHH (BC-02 RRHH):
  Bit 4:  RRHH_READ            — leer datos de empleados (OrangeHRM + Tryton Payroll)
  Bit 5:  RRHH_WRITE           — modificar datos de empleados
  Bit 6:  RRHH_APPROVE         — aprobar vacaciones, solicitudes
  Bit 7:  RRHH_AUDIT           — acceso a logs de RRHH

Zona VENTAS (BC-03 Ventas y CRM):
  Bit 8:  VENTAS_READ          — leer pedidos/clientes (Saleor + EspoCRM + Tryton)
  Bit 9:  VENTAS_WRITE         — crear/modificar pedidos y clientes
  Bit 10: VENTAS_APPROVE       — aprobar descuentos especiales o créditos
  Bit 11: VENTAS_AUDIT         — acceso a reportes de ventas

Zona SOPORTE:
  Bit 12: SOPORTE_READ         — leer tickets (Zammad)
  Bit 13: SOPORTE_WRITE        — crear/responder tickets
  Bit 14: SOPORTE_CONFIGURE    — configurar Zammad (colas, SLAs)

Zona ADMINISTRACION (BC-04 Identidad + BC-09 Plataforma):
  Bit 20: ADMIN_SYSTEM         — administración de sistema (bAuth, Keycloak)
  Bit 21: ADMIN_USERS          — gestión de usuarios y roles
  Bit 22: ADMIN_AUDIT          — acceso completo a todos los logs

Bits 23–62: RESERVADOS para zonas adicionales
Bit 63:     SUPERZONE — solo AssumeTenantContext
```

### V7-4: Mapa de Bits Financieros — BC-01 (desde V7 Dominios)

```
FinancialDomainMask bit assignments (BC-01 Financiero-Contable):

Control de caja (BC-01):
  Bit 0:  CAJA_APERTURA        — abrir caja (SoD: no puede tener CAJA_AUDITORIA)
  Bit 1:  CAJA_CIERRE          — cerrar caja
  Bit 2:  CAJA_ARQUEO          — realizar arqueo
  Bit 3:  CAJA_AUDITORIA       — auditar caja (SoD: no puede tener CAJA_APERTURA)

Aprobaciones de pago (BC-01):
  Bit 4:  PAGO_CREATE          — crear órdenes de pago (SoD: no puede tener PAGO_APPROVE)
  Bit 5:  PAGO_APPROVE_L1      — aprobar pagos hasta límite L1
  Bit 6:  PAGO_APPROVE_L2      — aprobar pagos hasta límite L2
  Bit 7:  PAGO_AUDIT           — auditar pagos

Nómina (BC-01 + BC-02):
  Bit 8:  NOMINA_INPUT         — ingresar datos de nómina (SoD: no puede tener NOMINA_APPROVE)
  Bit 9:  NOMINA_APPROVE       — aprobar nómina
  Bit 10: NOMINA_AUDIT         — auditar nómina

Compras (BC-01):
  Bit 11: COMPRA_SOLICITUD     — solicitar compra (SoD: no puede tener COMPRA_APROBACION)
  Bit 12: COMPRA_APROBACION    — aprobar compra
  Bit 13: COMPRA_RECEPCION     — recibir mercadería

Bits 14–63: RESERVADOS
```

### V7-5: Verbos Universales por BC (desde V7 Dominios)

Cada bounded context aplica los verbos universales en su dominio:

```
Verbo universal    BC donde aplica       Ejemplo
────────────────────────────────────────────────────────────────────
READ               BC-01, BC-02, BC-03   Leer facturas, empleados, clientes
WRITE              BC-01, BC-02, BC-03   Crear asientos, modificar empleados
DELETE             BC-01, BC-03          Eliminar facturas, pedidos (requiere justificación)
APPROVE            BC-01 (Financiero)    Aprobar pagos (SoD obligatorio respecto a WRITE)
EXECUTE            BC-09 (Plataforma)    Activar relé, desplegar ficha
CONFIGURE          BC-04, BC-09          Cambiar políticas de auth, configurar K8s
AUDIT              BC-06 (Reportes)      Acceso de solo lectura a logs y registros
```

### V7-6: zone_application_map.yaml — Resolución Zona → BCs (desde V7 Dominios)

El mapa `zona → aplicaciones` es el mecanismo de desacoplamiento entre los bounded contexts y los permisos. Cada zona de negocio agrupa aplicaciones de múltiples BCs:

```yaml
# zone_application_map.yaml — fuente de verdad del LogicalDomainEvaluator
# Resuelve: Zona de negocio → Aplicaciones concretas en cada BC
zones:
  ZONE_CONTABILIDAD:
    bc_primary: BC-01
    bc_secondary: [BC-06, BC-07]
    applications:
      - tryton: [modules: [account, account_invoice, account_payment]]
      - superset: [dashboards: [contabilidad_*]]
      - paperless: [tags: [factura, comprobante, fiscal]]
      - qdrant: [collections: [realm_*_contracts, realm_*_invoices]]
    required_verb_for_access: READ

  ZONE_RRHH:
    bc_primary: BC-02
    bc_secondary: [BC-01, BC-04]
    applications:
      - orangehrm: [all_modules: true]
      - tryton: [modules: [payroll, leave]]
      - paperless: [tags: [contrato, personal]]
      - keycloak: [user_lookup: true]
    required_verb_for_access: READ

  ZONE_VENTAS:
    bc_primary: BC-03
    bc_secondary: [BC-01]
    applications:
      - saleor: [all_modules: true]
      - espocrm: [all_modules: true]
      - tryton: [modules: [sale, invoice]]
    required_verb_for_access: READ

  ZONE_SOPORTE:
    bc_primary: BC-03
    bc_secondary: [BC-07]
    applications:
      - zammad: [all_modules: true]
    required_verb_for_access: READ

  ZONE_ADMINISTRACION:
    bc_primary: BC-04
    bc_secondary: [BC-09, BC-06]
    applications:
      - keycloak: [admin: true]
      - iam_installer: [all: true]
      - grafana: [dashboards: [admin_*, infra_*]]
    required_verb_for_access: READ
```

### V7-7: LogicalDomainEvaluator — El Evaluador que Falta (desde V7 Dominios)

La pieza de infraestructura más crítica que falta en el diseño actual es el **LogicalDomainEvaluator**, un Policy Decision Point (PDP) que unifica la evaluación de permisos para todos los BCs:

```go
// LogicalDomainEvaluator — el componente que falta
// Implementa el Policy Decision Point para el dominio lógico
// Da servicio a BC-01, BC-02, BC-03, BC-05, BC-06, BC-07
type LogicalDomainEvaluator interface {
    // CanAccessZone — ¿puede este portador de JWT operar en esta zona con este verbo?
    CanAccessZone(jwt *BosJWT, zone BusinessZone, verb UniversalVerb) (bool, error)

    // GetZoneApplications — ¿qué aplicaciones implementan esta zona?
    // Usado por las apps para saber a qué módulos dar acceso
    GetZoneApplications(zone BusinessZone) ([]ApplicationEndpoint, error)

    // GetActiveZones — ¿en qué zonas puede operar este usuario?
    // Usado por el frontend para construir el menú de navegación
    GetActiveZones(jwt *BosJWT) ([]BusinessZone, error)
}
```

**Evaluadores por BC:**

| BC | Evaluador actual | Evaluador futuro | Estado |
|---|---|---|---|
| BC-01 (Financiero) | trytond-auth-keycloak + Button Rules | LogicalDomainEvaluator + FinancialDomainEvaluator | Parcial |
| BC-02 (RRHH) | Ninguno (OrangeHRM evalúa internamente) | LogicalDomainEvaluator | Gap |
| BC-03 (Ventas) | Ninguno (Saleor/EspoCRM evalúan internamente) | LogicalDomainEvaluator | Gap |
| BC-04 (Identidad) | Keycloak | Keycloak + LogicalDomainEvaluator (SSO) | OK |
| BC-05 (Comms) | Keycloak SSO | Keycloak SSO + LogicalDomainEvaluator | OK |
| BC-06 (Reportes) | Superset auth local + KC SSO | LogicalDomainEvaluator (solo READ/AUDIT) | Parcial |
| BC-07 (IA) | bCompass + bSearch | LogicalDomainEvaluator (ACL) | Parcial |
| BC-08 (Integración) | biedata | biedata (ACL propio, no necesita evaluador) | OK |
| BC-09 (Plataforma) | IAM Installer | IAM Installer (Shared Kernel infra) | OK |

### V7-8: Conflict Matrix entre BCs (desde V7 Dominios)

La Conflict Matrix reemplaza el XOR del modelo anterior. Los conflictos SoD se expresan en términos de bits de dominio y cruzan BCs:

```go
var DefaultSoDConflicts = []SoDConflict{
    // BC-01 Financiero — caja
    {BitA: CAJA_APERTURA, BitB: CAJA_AUDITORIA, Mask: "financial",
     Description: "Quien opera la caja no puede auditarla", Severity: "critical"},

    // BC-01 Financiero — pagos
    {BitA: PAGO_CREATE, BitB: PAGO_APPROVE_L1, Mask: "financial",
     Description: "Quien crea órdenes de pago no puede aprobarlas", Severity: "critical"},

    // BC-01 → BC-03: Contabilidad vs Ventas
    {BitA: CONTABILIDAD_WRITE, BitB: VENTAS_APPROVE, Mask: "logical",
     Description: "Riesgo de conflicto: contabilidad y aprobación de ventas", Severity: "warning"},

    // BC-01 → BC-02: Contabilidad vs RRHH (nómina)
    {BitA: CONTABILIDAD_WRITE, BitB: NOMINA_APPROVE, Mask: "financial",
     Description: "Riesgo de conflicto: quien edita contabilidad no debiera aprobar nómina", Severity: "warning"},

    // BC-01 Financiero — nómina
    {BitA: NOMINA_INPUT, BitB: NOMINA_APPROVE, Mask: "financial",
     Description: "Segregación de nómina: principio de 4 ojos", Severity: "critical"},

    // BC-01 Financiero — compras
    {BitA: COMPRA_SOLICITUD, BitB: COMPRA_APROBACION, Mask: "financial",
     Description: "Quien solicita no puede aprobar sus propias compras", Severity: "critical"},
}
```

### V7-9: AssumeTenantContext y el Superusuario entre BCs (desde V7 Dominios)

El `AssumeTenantContext` permite al superusuario (SISTEMASSKULL) operar en cualquier BC con todos los bits activos. Es una capacidad del BitmaskBundle, no un rol:

```go
// AssumeTenantContext activa SUPERZONE (Bit 63) en los tres DomainMasks
// El JWT se emite con expiry obligatorio (máximo 8 horas)
// Todos los accesos quedan registrados en audit_events

// Máscara maestra que activa todos los bits del dominio
func AssumeTenantContext(bundle *BitmaskBundle) {
    bundle.PhysicalDomainMask = ^uint64(0)  // Todas las zonas físicas
    bundle.LogicalDomainMask  = ^uint64(0)  // Todas las zonas lógicas
    bundle.FinancialDomainMask = ^uint64(0) // Todas las zonas financieras
}
```

La aplicación del `AssumeTenantContext` en un BC específico:
- **BC-09 (Plataforma):** Despliegue y configuración de infraestructura
- **BC-04 (Identidad):** Gestión de realms, roles y políticas
- **BC-01 (Financiero):** Sólo bajo registro de auditoría y con expiración
- **BC-07 (IA):** Acceso a todas las colecciones Qdrant

### V7-10: Plan de Migración — Alineación BC → BitmaskBundle v3 (desde V7 Dominios)

| Fase | Versión SBOS | Acción | BCs afectados |
|---|---|---|---|
| **Fase 0** | Pre-v0.9 | Separar VDI y ERP en máscaras independientes | BC-04, BC-09 |
| **Fase 1** | v0.9 Beta | Renombrar `VDIMask→PhysicalDomainMask`, `ERPMask→LogicalDomainMask` | BC-04, BC-09 |
| **Fase 2** | v0.9 GA | Reconceptualizar bits de aplicaciones → zonas de negocio. Construir `zone_application_map.yaml` | BC-01, BC-02, BC-03, BC-04 |
| **Fase 3** | v1.0 | Implementar `LogicalDomainEvaluator`. Migrar Saleor, EspoCRM, Zammad, OrangeHRM, Superset, Paperless | BC-01, BC-02, BC-03, BC-06, BC-07 |
| **Fase 4** | v1.0 | Añadir `FinancialDomainMask`. Migrar controles de Tryton Button Rules → bAuth | BC-01 |
| **Fase 5** | v1.5 | Verbos universales. Deprecar `PERM_VIEW`, `SESSION_VALID` | Todos los BCs |
| **Fase 6** | v2.0 | Evaluar dominio Operacional (workflows, delegaciones temporales) | BC-01, cross-BC |

---

## §9 — ENRIQUECIMIENTO Smart* (V8)

### V8-1: SBOS CMS — Checkout y 5 Flujos de Negocio (desde BOSCMS-C-04-CHECKOUT-5-FLUJOS.md v2.0)

El checkout de SBOS CMS extiende el modelo de bounded contexts al incorporar un nuevo flujo de negocio entre BC-03 (Ventas), BC-01 (Financiero-Contable), y el nuevo subsistema de pagos:

**Los 5 flujos de checkout detectados automáticamente:**
| Flujo | Tipo de ítem | Entrega | Acción en Tryton | BCs involucrados |
|---|---|---|---|---|
| Flujo 1 | Producto físico | Envío a domicilio | Customer Shipment | BC-03 (Saleor) → BC-01 (Tryton) |
| Flujo 2 | Servicio (inventario inverso) | Cita | Account Move directo | BC-03 (Medusa CMS) → BC-01 (Tryton) |
| Flujo 3 | Servicio + insumos (híbrido) | Cita | Account Move + Kardex descuento | BC-03 (Medusa CMS) → BC-01 (Tryton + Kardex) |
| Flujo 4 | Producto físico | Recogida en tienda (BOPIS) | Internal Shipment BOPIS | BC-03 (Medusa CMS) → BC-01 (Tryton) |
| Flujo 5 | Producto de proveedor externo (MSI) | Pedido a proveedor | Purchase Order | BC-03 (Medusa CMS) → BC-01 (Tryton) + BC-08 (biedata) |

**Arquitectura de capas del checkout:**
1. **Medusa CMS** (instancia SBOSCMS) — gestiona carrito, crea pedido
2. **bpay / Medusa Payment Hub** (instancia bpay separada) — procesa pagos
3. **bKernel** — detecta INSERT via WAL, propaga a Tryton según flujo
4. **Tryton** — ERP, recibe instrucción post-pago para shipment/invoice/move

**Reglas estrictas (correcciones SBOS-COR-001 v3.0):**
- ÚNICA llamada de dinero: `POST /v1/smartpay/intents` a bpay
- El checkout NO llama a SmartTax/bTax directamente
- El checkout NO procesa pagos directamente
- El ctx_id es OBLIGATORIO en el header `X-SBOS-CtxId` (PASO 0)
- ctx_id como PRIMER campo en orderMetadata

**Mapeo a bounded contexts existentes:**
| Componente | BC | Relación |
|---|---|---|
| Medusa CMS (carrito+pedidos) | BC-03 Ventas | Propietario del pedido |
| bpay Payment Hub | Nuevo sub-BC de BC-03 | Orquesta pagos (ACL con pasarelas) |
| Tryton shipments/invoices | BC-01 Financiero | Customer-Supplier desde BC-03 |
| bKernel WAL | BC-09 Plataforma | Mediador de eventos |
| bTax | BC-01 Financiero | NO es llamado desde checkout |

### V8-2: SBOS CMS — Inventario Inverso y Nuevo Tipo de Dominio (desde BOSCMS-011-INVENTARIO-INVERSO.md)

El Inventario Inverso de Servicios (IIS) introduce un nuevo concepto de dominio que cruza BC-03 (Ventas) y BC-01 (Financiero-Contable):

**Los 3 tipos de inventario en SBOS CMS:**
| Tipo | Comportamiento en Kardex | Ejemplo | BC propietario |
|---|---|---|---|
| `physical` | Ingreso sube saldo, egreso lo baja. Saldo puede ser > 0 | Shampoo, repuesto de auto | BC-01 (Tryton) |
| `inverse` | Ingreso y egreso simultáneos. Saldo siempre = 0 | Corte de cabello, consulta | BC-03 (Medusa CMS) |
| `hybrid` | El servicio = inverse, los insumos = physical | Tinte (servicio + productos) | BC-03 + BC-01 |

**El problema de dominio que resuelve el IIS:**
En el inventario tradicional (BC-01), los servicios intangibles no pueden modelarse porque no tienen "stock acumulable". El IIS resuelve esto mediante:
- **Inventario Inverso:** el "stock" son turnos, no productos. Cada servicio vendido descuenta 1 del cupo del día.
- **Cola Inteligente:** estimación de duración por el proveedor al iniciar cada turno, propagada en tiempo real a todos los clientes en espera vía Centrifugo.

**Integración con el ecosistema SBOS:**
| Sistema | Rol en el IIS |
|---|---|
| **Centrifugo** (BC-05 Comms) | Notificaciones push en tiempo real: hora estimada actualizada, turno listo, retraso |
| **SmartReport** (BC-06) | Reportes de ocupación por recurso, tiempo promedio real vs. estimado, no-shows, ingresos |
| **SmartTax** (BC-01) | Factura automática al marcar turno como completado |
| **bKernel** (BC-09) | Detecta `queue_entries.status='completed'` → registra en historial → actualiza métricas |
| **Panel Flutter** (BC-03) | Vista del proveedor: cola del día, botones Iniciar/Estimar/Actualizar/Finalizar |

**Modelo de datos del IIS:**
```sql
-- Capacidad diaria (Inventario Inverso)
bookings.daily_capacity (resource_id, date, capacity, sold, completed)
-- Turno en la cola (Cola Inteligente)
bookings.queue_entries (id, resource_id, service_id, customer_id, queue_position,
  status, estimated_duration_min, estimated_start, started_at, finished_at)
-- Historial de estimaciones
bookings.estimation_history (resource_id, service_id, estimated_min, actual_min, ratio)
```

**Métodos de valuación por ítem** (no por empresa ni almacén):
`weighted_average` | `fifo` | `lifo` | `specific_id`

### V8-3: SBOS SmartPay — Dominio de Pagos y Reglas de Negocio (desde SBOS-PAY-002-DOMINIO.md v1.1)

SmartPay (bpay) introduce el BC de pagos como un sub-dominio dentro de BC-03 (Ventas) con su propio modelo de dominio y 23 reglas de negocio:

**Entidades del dominio de pagos:**
| Entidad | Descripción | Persistencia |
|---|---|---|
| `PaymentTransaction` | Intento de cobro o pago. Estados: Pending→Processing→Succeeded\|Partial\|Failed\|Refunded | `bpay.payment_transaction` |
| `PaymentMethod` | Enum: qr_interbancario, visa, mastercard, cash, customer_credit, bank_transfer, payment_in_kind, account_offset | Código |
| `Advance` | Pago sin documento de venta asociado. `sbos_origin_form='advance'` | `bpay.advances` |
| `Retention` | Descuento impositivo legal boliviano (IUE 12.5% + IT 3% = 15.5%) | `bpay.retentions` |
| `EgressOrder` | Orden preaprobada para egreso. Sin orden no hay egreso (RN-015) | `bpay.egress_orders` |
| `BarterTransaction` | Trueque o compensación de cuentas. `provider_id='payment_in_kind'` o `'account_offset'` | `bpay.barter_transactions` |

**Reglas de negocio críticas para el mapeo de BCs:**
| RN | Regla | BCs involucrados |
|---|---|---|
| RN-001 | Cajón de dinero solo se abre cuando todos los métodos están Succeeded | BC-03 (POS), BC-09 (hardware) |
| RN-002 | Factura solo se genera cuando suma pagos ≥ amount | BC-01 (Tryton facturación) |
| RN-003 | Toda transacción debe tener ctx_id | BC-04 (Identidad), BC-09 (Context Plane) |
| RN-010 | Solo BOB en v1.0 | BC-01 (moneda funcional) |
| RN-012 | Pago multimodal: si un método falla, los confirmados no se revierten | BC-03 (checkout), BC-01 (contabilidad) |
| RN-015 | Egreso requiere orden preaprobada upstream | BC-01 (Tryton aprobaciones) |
| RN-021 | No operar cola de pagos sin apertura de turno | BC-09 (POS lifecycle) |
| RN-022 | Cierre de turno requiere doble autenticación (cajero + supervisor) | BC-04 (Keycloak Step-Up) |

**Flujo de pago multimodal (N:1):**
Una sola deuda puede liquidarse combinando múltiples métodos de pago simultáneamente (ej: saldo a favor 30% + QR 30% + efectivo 40%). Genera N `payment_transaction` vinculados al mismo `foreign_id`. bKernel propaga a Tryton solo cuando `SUM(amount_paid) >= amount` original (RN-011).

**Retenciones impositivas bolivianas (F-011):**
| Tipo | Porcentaje | Aplica a | Formulario SIN |
|---|---|---|---|
| IUE servicios | 12.5% | Servicios sin factura | F-570 |
| IUE bienes | 5% | Bienes sin factura | F-570 |
| IT | 3% | Todas las compras sin factura | F-410 |

**Grossing Up:** El comprador puede elevar el monto bruto para que el proveedor reciba el neto acordado. Fórmula: `Bruto = Neto / (1 - % retención total)`. Requiere aprobación del Administrador Financiero (RN-023).

**Trueque (F-013):** bpay soporta dos modalidades de trueque — `payment_in_kind` (pago en especie física) y `account_offset` (compensación de cuentas recíprocas). Ambas requieren: valoración a Fair Market Value con biometría del supervisor (RN-016), facturación doble compra+venta vía Tryton/SIAT (RN-017). El componente en efectivo ≥ 50,000 BOB está sujeto a bancarización; el trueque puro no (RN-018).

**Relación entre bpay y los bounded contexts:**
| BC | Relación con bpay | Detalle |
|---|---|---|
| BC-01 Financiero | Customer-Supplier | bpay produce PaymentTransaction, Tryton consume para contabilidad |
| BC-03 Ventas | Shared Kernel | bpay es sub-dominio de Ventas, comparten el pedido como kernel |
| BC-04 Identidad | Conformist | bpay acepta JWT de Keycloak para autorización |
| BC-09 Plataforma | Customer-Supplier | bKernel propaga eventos bpay → Tryton |

---

## ENRIQUECIMIENTO SBOS (Primera Versión)

### SBOS-022-010-1: CQRS Implicito del bKernel (desde SBOS-022-CQRS-Sagas.md)

El bKernel implementa CQRS implicito sin que las aplicaciones lo sepan. Las apps solo hacen escrituras SQL normales en sus BDs. El bKernel observa esas escrituras via WAL y produce modelos de lectura optimizados de forma asincrona.

**Arquitectura:**
```
Lado escritura: App (Tryton/OrangeHRM) -> SQL -> PostgreSQL WAL (log inmutable)
                                       bKernel CDC Engine lee WAL via pgoutput
                                       Rule Engine (YAML) evalua reglas
                                       Writer Pool escribe destinos
Lado lectura:  Tablas proyeccion en bkerneldb actualizadas por bKernel
               Apps leen via SQL directo (misma BD, sin overhead de red)
```

**Terminologia CQRS en SBOS:**

| Termino CQRS | Equivalente SBOS |
|---|---|
| Comando | SQL INSERT/UPDATE/DELETE de una app |
| Event Log | WAL PostgreSQL (wal_level=logical) |
| Event | Fila WAL decodificada por pgoutput |
| Proyector | bKernel Rule Engine + Writer Pool |
| Proyeccion / Read Model | Tabla materializada en bkernel_db |
| Consistencia eventual | Lag WAL bKernel (SLO: <500ms P99) |

**Principio de no invasion:** las apps no saben que su WAL es observado, que sus escrituras producen proyecciones, ni que existen modelos de lectura derivados. Anadir o modificar proyecciones solo requiere modificar reglas YAML en `/etc/bos/blibs/bkernel/rules/` -- sin tocar codigo de apps.

### SBOS-022-010-2: Garantias de Consistencia Eventual (desde SBOS-022-CQRS-Sagas.md)

**At-least-once delivery:** cada evento WAL se procesa al menos una vez. La idempotencia usa `bkernel_db.processed_events`:

```sql
CREATE TABLE bkernel_db.processed_events (
  event_id UUID PRIMARY KEY, processed_at TIMESTAMPTZ NOT NULL,
  source_lsn PG_LSN NOT NULL, source_app TEXT NOT NULL,
  rule_name TEXT NOT NULL, destination TEXT NOT NULL
);
-- Writer Pool verifica: IF EXISTS (SELECT 1 WHERE event_id=$1) THEN SKIP
```

**SLO de consistencia eventual (lag WAL):**

| Percentil | SLO | Cuando se viola |
|:---------:|:---:|-----------------|
| P50 | < 50ms | Nunca en condiciones normales |
| P95 | < 200ms | Solo bajo carga alta sostenida |
| P99 | < 500ms | Solo en burst extremo |
| P99.9 | < 2s | Solo en restart de bKernel |

**Cuando NO usar consistencia eventual** (leer de BD origen, no de proyeccion): confirmar factura en Tryton, verificar saldo antes de aprobar pago, crear empleado en OrangeHRM. Usar proyeccion para: busqueda en Core UI, dashboard de facturas abiertas, datos de reporting.

### SBOS-022-010-3: Proyecciones Materializadas (desde SBOS-022-CQRS-Sagas.md)

**dashboard_invoices_open (BC-01):** Facturas abiertas con datos de cliente desnormalizados. Evita JOINs complejos de Tryton. Regla YAML con trigger en `tryton_db.account_invoice` (INSERT/UPDATE/DELETE donde state IN draft,validated,posted), mapea invoice_id, customer_name (LOOKUP party_party), amount_total, due_date. DELETE si state=cancelled.

**active_employees_with_roles (BC-02):** Empleados activos con roles Keycloak desnormalizados. Trigger multi-fuente: `orangehrm_db.hs_hr_employee` + `keycloak_db.user_role_mapping`. Condicion: emp_work_status='Active'. Usa CROSSREF para vincular emp_number con keycloak user_id. ARRAY_AGG de roles.

**product_catalog_availability (BC-03):** Catalogo con disponibilidad de stock. Trigger en `saleor_db.product_product` + `tryton_db.stock_quantity`. Calcula stock_status (in_stock/out_of_stock) con CASE.

### SBOS-022-010-4: Patrones Saga Cross-Bounded-Context (desde SBOS-022-CQRS-Sagas.md)

El bKernel actua como orquestador de Sagas via su Rule Engine. Cada paso es una regla YAML. Si falla, el Rule Engine dispara la regla de compensacion.

**Tablas de estado en bkernel_db:**
```sql
CREATE TABLE bkernel_db.saga_state (
  saga_id UUID PK, saga_name TEXT, trigger_event TEXT,
  trigger_entity_id INT, current_step INT, total_steps INT,
  status TEXT DEFAULT 'in_progress', -- in_progress|completed|compensating|failed
  started_at TIMESTAMPTZ, completed_at TIMESTAMPTZ, error_details JSONB
);
CREATE TABLE bkernel_db.saga_step_log (
  id BIGSERIAL PK, saga_id UUID FK, step_number INT,
  step_name TEXT, status TEXT, -- pending|completed|compensated|failed
  executed_at TIMESTAMPTZ, compensation_executed_at TIMESTAMPTZ, details JSONB
);
```

**Saga de Employee Onboarding (5 pasos cruzando 3 BCs):**
1. `create_keycloak_user` (BC-04) -- POST /admin/realms/.../users. Compensacion: DELETE user
2. `assign_keycloak_roles` (BC-04) -- Segun departamento. Depende de [1]. Compensacion: revocar roles
3. `create_mailbox_and_channel` (BC-05) -- Postfix buzón + Mattermost. Paralelo con step 4
4. `create_tryton_party` (BC-01) -- party.party para nomina. Paralelo con step 3
5. `link_keycloak_id_in_orangehrm` (BC-02) -- UPDATE hs_hr_employee. Depende de [2,3,4]

Timeout global: 10 min. Fallo detecta por: HTTP 4xx/5xx (API), SQL exception, timeout paso (default 30s). Al fallar: registra en saga_step_log, actualiza saga_state.status='compensating', ejecuta compensaciones en orden inverso, emite evento on_saga_failed.

**Saga Invoice-CRM (3 pasos):**
1. `update_espocrm_opportunity` -- Cambia stage a "Closed Won"
2. `send_invoice_email` -- Envia factura por email. NO compensable (email ya enviado)
3. `update_invoice_projection` -- Actualiza dashboard_invoices_open

### SBOS-022-010-5: Plan de Migracion de Version Mayor de PostgreSQL (desde SBOS-022-PGMIG-MigrationPlan-v1_0.md)

**Riesgo unico SBOS:** los slots de replicacion logica (`pgoutput`) NO son migrados por `pg_upgrade`. Despues de una migracion, los slots desaparecen y el EventBus queda silenciosamente inoperativo.

**Version actual:** PG 17. Proxima migracion: PG 17 -> 18. Version minima soportada: PG 15. Actualizaciones menores via Patroni sin ventana.

**Proceso de migracion en 4 pasos:**

**Paso 1 -- Validacion en staging (4-8h, DBA + Arquitecto):** Instalar PG nueva, ejecutar `pg_upgrade --link --check`, luego sin --check. CRITICO: recrear slots (`pg_create_logical_replication_slot('bkernel_tryton', 'pgoutput')` para cada slot en bkernel.toml). Reiniciar bKernel, verificar lag < 500ms. Criterio GO: lag sostenido <500ms + tests integracion pasan + cero errores slots.

**Paso 2 -- Backup pre-migracion:** `pgbackrest --stanza=sbos --type=full backup` desde S14. Verificar con `pgbackrest info`.

**Paso 3 -- pg_upgrade produccion (ventana 30-90min):** Notificar cliente 48h antes. Detener apps (kubectl scale 0), daemons, PostgreSQL. Ejecutar pg_upgrade --link. Iniciar PG 18. Actualizar Patroni.

**Paso 4 -- Recrear slots y verificar:** Recrear TODOS los slots. Iniciar daemons y apps. Verificar lag < 500ms. Verificar `count(*) FROM pg_replication_slots` = mismo numero pre-migracion. Ejecutar `sbos-restore-validate.sh`. GO: 7/7 checks pasan, cero errores.

**Politica de versiones:** PG 15 minima. Actualizaciones patch automaticas via Patroni. Versiones mayores requieren este proceso completo + RFC en SBOS-025. SKULL soporta version actual e inmediatamente anterior.

---

## Trazabilidad V8

| Sección | Fuente |
|---|---|
| §1-6 (V6 completo) | BOS_V6_SBOS-030-BOUNDED-CONTEXTS.md |
| §7 V5-1 a V5-6 | SBOS-022-BoundedContexts-v1_0.md (602 líneas) |
| §8 V7-1 a V7-10 | BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md |
| §9 V8-1 a V8-3 | SBOS CMS (BOSCMS-C-04-CHECKOUT-5-FLUJOS.md v2.0, BOSCMS-011-INVENTARIO-INVERSO.md), SBOS SmartPay (SBOS-PAY-002-DOMINIO.md v1.1) |
| §10 SBOS-022-010-1 a SBOS-022-010-4 | SBOS-022-CQRS-Sagas.md | CQRS formal del bKernel, garantias consistencia eventual, 3 proyecciones materializadas, patron Saga cross-BC (onboarding empleado 5 pasos, invoice-crm 3 pasos) |
| §10 SBOS-022-010-5 | SBOS-022-PGMIG-MigrationPlan-v1_0.md | Plan migracion PG mayor (riesgo slots WAL, 4 pasos con go/no-go, comandos bash, politica versiones) |

---

## Fuentas de Enriquecimiento V8

| Fuente | Tipo | Contenido aportado |
|---|---|---|
| BOS_V6_SBOS-030-BOUNDED-CONTEXTS.md | V6 (canonico) | Contenido base completo preservado |
| SBOS-022-BoundedContexts-v1_0.md | V5 | BCs expandidos con eventos/entidades, relaciones DDD expandidas, modulos IAM dominio vs orquestacion, sagas detalladas con compensaciones |
| BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md | V7 | 9 dominios autenticacion, BitmaskBundle v3, mapa bits logicos/financieros, verbos universales, zone_application_map, LogicalDomainEvaluator, Conflict Matrix, AssumeTenantContext |
| SBOS CMS / SBOS SmartPay | Smart* (V8) | Checkout 5 flujos, inventario inverso (IIS), dominio de pagos SmartPay con 23 reglas de negocio |
| SBOS-022-CQRS-Sagas.md | SBOS (V8) | CQRS formal, proyecciones materializadas, patron Saga cross-BC con compensaciones, bKernel como orquestador |
| SBOS-022-PGMIG-MigrationPlan-v1_0.md | SBOS (V8) | Plan migracion PostgreSQL mayor, riesgo slots WAL, 4 pasos con go/no-go, comandos bash detallados |

---

_SKULL · SBOS · SBOS-030-BOUNDED-CONTEXTS · HUMAN-DOC V8 ENRIQUECIDO · Mayo 2026_
