# SBOS-007
## Especificación Técnica: Core UI — Frontend del IAM Installer

### SKULL · SBOS — Sovereign Business Operating System
### v4.0 · Marzo 2026

---

**Código:** SBOS-007
**Versión:** 4.0
**Estado:** ACTIVO
**Complemento:** SBOS-018-API-Versioning-v1_0.md §A (Versionado API REST /api/v{N}/ y sunset policy — integrado — ver SBOS-018 v2.0)
**Clasificación:** Especificación Técnica — Frontend del IAM Installer

---

## Tabla de Contenidos

1. [Posición en el ecosistema — Frontend del IAM Installer](#1-posición-en-el-ecosistema--frontend-del-iam-installer)
2. [El Core UI como PAP dSBOS Auth Enforce](#2-el-core-ui-como-pap-del-rolframework)
3. [Fundamento Conceptual](#3-fundamento-conceptual)
4. [Definición y Rol](#4-definición-y-rol)
5. [Relación Core ↔ Core UI](#5-relación-core--core-ui)
6. [Las 5 Vistas Principales](#6-las-5-vistas-principales)
7. [Arquitectura Flutter: Estado y Comunicación](#7-arquitectura-flutter-estado-y-comunicación)
8. [Multi-Dispositivo: Un Codebase, Tres Experiencias](#8-multi-dispositivo-un-codebase-tres-experiencias)
9. [Estrategia Offline](#9-estrategia-offline)
10. [Seguridad por Capas](#10-seguridad-por-capas)
11. [Contrato de API Core UI ↔ Core (SP-01)](#11-contrato-de-api-core-ui--core-sp-01)
12. [Stack Técnico](#12-stack-técnico)
13. [Relación con el Ecosistema de Patrones](#13-relación-con-el-ecosistema-de-patrones)
14. [Registro de Cambios v4.0](#14-registro-de-cambios-v40)

---

## 1. Posición en el ecosistema — Frontend del IAM Installer

El Core UI es el **frontend del IAM Installer** (SBOS-005). Vive en el namespace `sbos-installer` junto al IAM Installer y las fichas de gestión del plano de control. En la nueva numeración SBOS, el Core UI ocupa el número **007** — contiguo al IAM Installer (SBOS-005) y a las Fichas (SBOS-006) — porque los tres forman la daemons soberanos del plano de control: el motor de instalación, el catálogo de fichas, y la interfaz de administración.

| Documento | Relación |
|---|---|
| SBOS-005 — IAM Installer | El Core UI es el frontend del IAM Installer — todas las operaciones sobre fichas se invocan desde aquí |
| SBOS-006 — Fichas | El administrador descubre, instala y gestiona fichas desde el Core UI |
| SBOS-008 — Gobierno de Identidad | El Core UI es el PAP (Policy Administration Point) dSBOS Auth Enforce |
| SBOS-022 — Bounded Contexts | SBOS-022 incluye el contrato de API que este documento especifica |

---

## 2. El Core UI como PAP dSBOS Auth Enforce

El Core UI no es únicamente la interfaz de gestión de fichas. Es también el **Policy Administration Point (PAP)** dSBOS Auth Enforce — el único lugar donde un administrador autorizado puede crear, editar, o desactivar RolTemplates y UserTemplates.

Esta responsabilidad está definida en el patrón PAP/PIP/PDP/PEP del SBOS (ver SBOS-008 para la descripción completa dSBOS Auth Enforce):

| Punto | Función | Implementación en SBOS |
|---|---|---|
| **PAP — Policy Administration Point** | Donde se administran las políticas de identidad | **Core UI** — formulario de RolTemplate y UserTemplate |
| PIP — Policy Information Point | Donde viven los datos de las políticas | PostgreSQL → tabla `bos_rol_template` |
| PDP — Policy Decision Point | Quien decide si se permite el acceso | Keycloak + Tryton |
| PEP — Policy Enforcement Point | Quien bloquea o permite la operación | Tryton (5 capas) + OAuth2-Proxy |

### Vistas de administración de identidad

El Core UI expone dos vistas adicionales (integradas en la Vista 1 — Catálogo, en la sección "Identidad") para la gestión de identidad:

**Vista de RolTemplates:**
- Lista de todos los RolTemplates del realm activo con su `sync_status` (PENDING / SYNCED / ERROR / DRIFT)
- Formulario de creación y edición de RolTemplate con todos los campos del esquema declarativo
- Visualización de la jerarquía de roles (padre → hijo con herencia AND NOT)
- Indicador de sincronización: Keycloak ✓ / Tryton ✓ / DRIFT ⚠ / ERROR ✗
- Botón "Forzar re-sincronización" — disponible cuando `sync_status = DRIFT`
- Historial de cambios del RolTemplate con timestamps y operador

**Vista de UserTemplates:**
- Lista de todos los UserTemplates con su estado de provisioning
- Formulario de asignación de rol a usuario: busca usuario → selecciona RolTemplate → confirma
- Vista del flujo de onboarding: Core UI → Keycloak → Tryton → SBOS VDI (estado de cada paso)
- Acciones rápidas: activar / desactivar / extender vigencia / delegar temporalmente

### Restricciones de acceso a las vistas de identidad

Solo los usuarios con rol `sbos-admin` pueden acceder a las vistas de administración de identidad. Los usuarios con rol `sbos-operator` pueden ver el estado de sincronización pero no editar RolTemplates. Los usuarios con rol `sbos-viewer` no ven estas vistas.

---

## 3. Fundamento Conceptual

### El problema que el Core UI resuelve

Gestionar un stack empresarial Kubernetes sin una interfaz unificada significa vivir entre múltiples consolas: la consola de kubectl, el dashboard de Kubernetes, la interfaz de Keycloak, el panel de Prometheus, los logs de Grafana, el portal de Vault. Cada herramienta tiene su propio modelo mental, su propia autenticación, su propia curva de aprendizaje. El administrador pasa más tiempo buscando información entre herramientas que tomando decisiones.

La industria respondió a este problema con el concepto de **Internal Developer Portal** — una capa UX unificada sobre toda la infraestructura. La idea de un portal interno de desarrolladores es proveer una única experiencia de usuario para todo el software e infraestructura: desde gestionar despliegues hasta alertas de seguridad, graficar dependencias, y todo lo que se pueda imaginar.

El portal no es la plataforma en sí — la plataforma es la colección de servicios, pipelines y políticas que se han construido. El portal es el cockpit. Consolida todas las herramientas, documentación y servicios dispersos en una experiencia de desarrollador única y cohesiva.

El Core UI es el cockpit soberano del SBOS. No es un dashboard genérico de Kubernetes — es una interfaz diseñada específicamente para gestionar fichas SBOS: descubrirlas, instalarlas, mantenerlas, repararlas, y entender sus dependencias, todo desde un único lugar y sin saltar entre consolas.

### La diferencia con los dashboards genéricos

Herramientas como Rancher, Lens o el Kubernetes Dashboard exponen los recursos crudos del cluster: pods, deployments, services, namespaces. El administrador debe conocer Kubernetes para operar. A través de la interfaz, los administradores pueden desplegar aplicaciones usando Helm charts, YAML, o el catálogo de apps; gestionar rolling updates, rollbacks y estrategias de despliegue visualmente; monitorear logs de pods, acceder a terminales shell, y escalar deployments con unos pocos clics.

El Core UI va un nivel de abstracción más arriba: el administrador no ve pods ni deployments — ve **fichas**. Ve PostgreSQL en estado `INSTALADA — OK`. Ve Roundcube en estado `BLOQUEADA` porque PostgreSQL no está instalada aún. Ve el grafo de dependencias completo antes de instalar cualquier cosa. La complejidad de Kubernetes queda encapsulada detrás del modelo de fichas.

---

## 4. Definición y Rol

El Core UI es el frontend del IAM Installer. Desarrollado en Flutter, desplegado como contenedor K8s en el namespace `sbos-installer`. Accesible desde navegador web, dispositivos móviles (Android/iOS), tablets y aplicaciones de escritorio (Windows/Linux/macOS) desde un único codebase.

**El Core UI no ejecuta operaciones.** Las solicita al Core vía API REST y presenta los resultados. Esta separación no es cosmética — garantiza que el sistema funcione correctamente incluso si el Core UI está caído. Un administrador con acceso SSH puede operar el sistema completo vía CLI: `sbos install postgresql`, `sbos repair mailserver`, `sbos status`. El Core UI es la interfaz preferida, no la única.

**El Core UI no mantiene estado propio.** Todo el estado vive en `.sbos_state.json` en el Core. El Core UI lo lee, lo presenta, y envía instrucciones para cambiarlo. Si el Core UI se reinicia, recupera el estado exacto del sistema en el siguiente request.

---

## 5. Relación Core ↔ Core UI

```
Administrador en Core UI
  │
  │  "Instalar PostgreSQL"
  ▼
Core UI
  │  POST /api/fichas/postgresql/install
  ▼
Backend Python (FastAPI)
  │  FICHA_LINTER valida la ficha
  │  DEPENDENCY_RESOLVER verifica dependencias
  │  INSTALL_RUNNER orquesta la ejecución
  ▼
Core Bash (SP-01)
  │  00_MASTER_INSTALL_SBOS.sh install postgresql
  │  YAML Engine ejecuta yaml_engine.yml de postgresql
  │  sbos_k8s_core() aplica postgresql.k8s.yml
  ▼
Kubernetes Cluster
  │  StatefulSet postgresql arranca
  │  post_install registra en Keycloak + Kong + Vault
  ▼
Core emite señales por stdout
  │  __SBOS__STEP_OK__ Namespace sbos-data creado
  │  __SBOS__STEP_OK__ PVC postgresql-data creado (500GB)
  │  __SBOS__STEP_OK__ Pod postgresql Running
  │  __SBOS__DONE__OK__
  ▼
PROGRESS_EMITTER convierte señales en eventos JSON
  │  WebSocket → Core UI
  ▼
Core UI renderiza progreso en tiempo real
  │  [✓] Paso  1/12  Crear namespace sbos-data           0.1s
  │  [✓] Paso  2/12  Crear PVC 500GB                     0.3s
  │  [⟳] Paso  7/12  Esperar pod Ready...               (15s)
  ▼
STATE_MANAGER actualiza .sbos_state.json
  │  postgresql → INSTALADA_OK
  ▼
Core UI refleja nuevo estado
  │  PostgreSQL 18  ●  INSTALADA — OK
  │  Roundcube      ○  NO INSTALADA  [Instalar]  ← desbloqueada
```

---

## 6. Las 5 Vistas Principales

### Vista 1 — Catálogo de Fichas

La vista central del sistema. Implementa el concepto de Software Catalog de la industria pero adaptado al modelo de fichas SBOS: una página de servicio bien configurada muestra ownership, dependencias, documentación, estado de build, salud del despliegue, incidentes activos — todo lo necesario para entender y operar el servicio desde una única URL. En el Core UI, esa URL es la ficha.

**Organización:** las fichas se navegan por servidor lógico (`dataserver`, `identityserver`, `commsserver`, etc.) y por estado. La búsqueda instantánea filtra por nombre, categoría, o estado.

**Información por ficha:**
- Estado con semaforización: `INSTALADA — OK` (verde) / `INSTALADA — ALERTA` (ámbar) / `BLOQUEADA` (gris) / `ACTUALIZACIÓN DISPONIBLE` (azul)
- Icono + nombre + versión + descripción
- Recursos consumidos (CPU, RAM, disco) vs disponibles en el nodo
- Dependencias satisfechas / pendientes
- Último health check: timestamp + resultado
- Acciones disponibles según estado: Instalar / Verificar / Reparar / Actualizar / Desinstalar

**Grafo de dependencias interactivo:** antes de instalar cualquier ficha, el administrador puede ver el grafo completo — qué fichas instala en qué orden, cuántos recursos consume la cadena completa, cuánto tiempo estima el sistema que tomará. Este grafo es generado en tiempo real por `DEPENDENCY_RESOLVER` y `MENU_ENGINE`.

**Probe / Dry-run:** cada ficha tiene un botón "Verificar antes de instalar" que ejecuta `sbos probe <ficha>` y muestra exactamente qué haría cada fase sin desplegar nada.

**Sección "Identidad" (integrada en el Catálogo):** acceso a las vistas de RolTemplates y UserTemplates descritas en §2. Solo visible para usuarios con rol `sbos-admin` o `sbos-operator`.

---

### Vista 2 — Progreso de Operaciones

Se activa cuando el administrador confirma una operación. Ocupa el espacio completo de la vista y no permite navegación hasta que la operación termina o el administrador la cancela explícitamente.

**Lo que muestra:**
```
Instalando PostgreSQL 18
─────────────────────────────────────────────────────
[✓]  1/12  Verificar recursos del nodo              0.1s
[✓]  2/12  Crear namespace sbos-data                0.2s
[✓]  3/12  Crear secret pg-master-credentials       0.3s
[✓]  4/12  Registrar política en Vault              1.2s
[✓]  5/12  Crear PVC postgresql-data (500GB)        0.4s
[✓]  6/12  Aplicar NetworkPolicy                    0.2s
[✓]  7/12  Aplicar StatefulSet postgresql           0.8s
[⟳]  8/12  Esperar pod Ready...                     (23s)
 9/12  Configurar bases de datos
10/12  Registrar bases de datos de apps dependientes
11/12  Verificar health check
12/12  Actualizar estado del sistema
─────────────────────────────────────────────────────
Estimado: ~4 minutos
```

**Reconexión y replay:** si el administrador pierde la conexión, al reconectarse ve exactamente el mismo estado — `PROGRESS_EMITTER` retransmite todos los eventos perdidos desde el `.jsonl`. Una operación de 45 minutos no pierde ningún paso aunque el navegador se cierre en el minuto 20.

**Errores accionables:** cuando un paso falla, la vista no muestra solo el error — muestra la CAUSA exacta y la SOLUCIÓN exacta, con el comando CLI que el administrador puede copiar y ejecutar si prefiere resolver manualmente.

---

### Vista 3 — Dashboard de Salud del Sistema

Vista de estado global del BOS. Diseñada para responder en 3 segundos la pregunta: *¿está todo bien?*

**Semaforización global:** un indicador de color único representa el estado de salud agregado del sistema.
- Verde: todas las fichas instaladas en estado OK
- Ámbar: una o más fichas en ALERTA o con drift detectado
- Rojo: una o más fichas críticas en ERROR

**Métricas del cluster:** CPU, RAM y disco por nodo, vía Prometheus. El `GROWTH_DETECTOR` resalta en ámbar cualquier nodo que supere el 80% de uso sostenido.

**Fichas en ALERTA:** lista priorizada de fichas que requieren atención, con acceso directo a "Reparar" o "Ver logs" sin salir de la vista.

**Estado de sincronización de identidad:** panel adicional que muestra el estado dSBOS Auth Enforce — cuántos RolTemplates en SYNCED / DRIFT / ERROR — con alerta visual si algún rol está en drift. Enlaza directamente a la Vista de RolTemplates del Catálogo.

**Alertas push:** incidentes críticos (pod en CrashLoopBackOff, nodo no responde, health check fallando 3 veces consecutivas) generan notificaciones push al dispositivo móvil del administrador. El administrador recibe la alerta a las 2am y puede actuar desde el móvil sin necesidad de acceder al desktop.

---

### Vista 4 — Crecimiento Horizontal

Asistente guiado para agregar nodos al cluster. `GROWTH_DETECTOR` monitorea métricas Prometheus y sugiere expansión cuando un nodo supera el umbral configurado de manera sostenida.

**El flujo de expansión tiene exactamente 3 parámetros:**
1. IP del nuevo nodo
2. Contraseña SSH de acceso
3. Rol del nodo (servidor lógico: `dataserver`, `identityserver`, etc.)

El Core ejecuta automáticamente: kubeadm join, configuración de node selector, verificación de comunicación inter-nodo, y notificación de disponibilidad. El nuevo nodo aparece en el catálogo como disponible para recibir fichas.

**Monitoreo post-expansión:** la vista muestra el estado del nuevo nodo en tiempo real durante las primeras horas — métricas, pods migrados, health checks.

---

### Vista 5 — Auditoría

Historial completo de operaciones. Cada acción sobre el sistema queda registrada: quién la ejecutó, cuándo, qué resultado tuvo, cuánto tardó.

**Filtros:** por ficha, por tipo de operación, por administrador, por rango de fechas, por resultado (OK / ERROR).

**Exportación:** los logs son exportables en formato JSON para integración con sistemas de auditoría externos.

**Trazabilidad de governance:** las operaciones que requieren dual-control (governance category 3) muestran ambas aprobaciones — quién solicitó y quién autorizó — con timestamps exactos.

---

## 7. Arquitectura Flutter: Estado y Comunicación

### Por qué Flutter para una herramienta de administración

Una de las mayores fortalezas de Flutter es su capacidad de entregar una UI consistente en múltiples plataformas. A diferencia de los frameworks cross-platform tradicionales que dependen de componentes UI nativos, Flutter usa su propio motor de renderizado basado en widgets, asegurando que la aplicación se vea y se comporte igual en Android, iOS y web.

Para el Core UI esto es crítico: el administrador que gestiona el sistema desde el desktop y el que responde una alerta crítica desde el móvil a las 2am ven exactamente la misma información, con la misma consistencia visual, desde un único codebase mantenible.

### Gestión de estado: BLoC + Riverpod

BLoC es una elección perfecta cuando la lógica de negocio es sofisticada y se necesita control estricto sobre cómo ocurren las transiciones de estado. Está ampliamente adoptado en aplicaciones enterprise y de producción. El flujo claro y predecible Event → BLoC → State promueve una arquitectura limpia y es altamente testeable.

El Core UI usa una arquitectura híbrida deliberada:

**BLoC** para las operaciones sobre fichas — instalar, reparar, actualizar, desinstalar — y para las operaciones sobre RolTemplates y UserTemplates. Estas son las operaciones de mayor riesgo del sistema: requieren control estricto sobre las transiciones de estado, trazabilidad completa de eventos, y capacidad de testear cada transición de forma aislada. El flujo Event → BLoC → State hace que cada operación sea predecible y auditable.

**Riverpod** para el estado global del catálogo, el dashboard, y el estado de sincronización dSBOS Auth Enforce. Los providers de Riverpod son declaraciones globales e inmutables, sin dependencia de BuildContext. No más ansiedad por el contexto. El estado del catálogo de fichas — qué fichas existen, cuál es su estado, qué dependencias tienen — es un estado global que múltiples vistas leen simultáneamente. Riverpod es la herramienta correcta para este caso.

### Comunicación en tiempo real: WebSocket + StreamBuilder

Si se tiene una fuente de datos que emite múltiples valores a lo largo del tiempo — como actualizaciones en tiempo real desde una base de datos o una conexión WebSocket — StreamBuilder es la herramienta indicada. Escucha un Stream y reconstruye su UI cada vez que llega un nuevo valor, proveyendo una interfaz responsiva y dinámica.

El progreso de cada operación llega por WebSocket como un Stream de eventos JSON. El `StreamBuilder` de Flutter reconstruye exactamente los pasos afectados cuando llega un nuevo evento — sin redesplegar toda la vista de progreso.

### Arquitectura Feature-First

En 2025, la arquitectura Feature-First es ampliamente adoptada para aplicaciones Flutter modulares. Las features se organizan en carpetas independientes que contienen su propia lógica, modelos y vistas.

```
lib/
  ├── features/
  │     ├── catalog/          ← Catálogo de fichas
  │     │     ├── blocs/
  │     │     ├── models/
  │     │     └── views/
  │     ├── identity/         ← RolTemplates y UserTemplates (PAP)
  │     │     ├── blocs/
  │     │     ├── models/
  │     │     └── views/
  │     ├── operations/       ← Progreso de operaciones
  │     ├── dashboard/        ← Salud del sistema
  │     ├── growth/           ← Crecimiento horizontal
  │     └── audit/            ← Auditoría
  ├── core/
  │     ├── api/              ← Cliente REST FastAPI
  │     ├── websocket/        ← Cliente WebSocket
  │     ├── auth/             ← Keycloak OIDC
  │     └── state/            ← Providers globales Riverpod
  └── main.dart
```

---

## 8. Multi-Dispositivo: Un Codebase, Tres Experiencias

El mismo codebase Flutter se adapta a tres factores de forma con comportamientos distintos, no solo tamaños distintos.

| Factor de forma | Uso principal | Experiencia específica |
|---|---|---|
| **Móvil** (Android/iOS) | Emergencias nocturnas, alertas en campo | Vista compacta de fichas en ALERTA. Acciones rápidas: Reparar / Ver logs / Llamar al equipo. Push notifications para incidentes críticos. Biometría para autenticar sin escribir contraseñas a las 2am |
| **Tablet** | Gestión operativa en reuniones, campo | Dos paneles: catálogo a la izquierda, detalle de ficha a la derecha. Navegación por gestos. Orientación landscape optimizada |
| **Desktop / Web** | Administración completa | Dashboard extendido con métricas de cluster. Logs en tiempo real con scroll infinito. Vista de grafo de dependencias de pantalla completa. Gestión de cluster y crecimiento horizontal. Gestión de RolTemplates y UserTemplates |

### Detección del factor de forma

El Core UI detecta el factor de forma en runtime y adapta el layout sin recargar:

```dart
// En cualquier widget
if (ScreenFactor.isMobile(context)) {
  return FichaCompactView(ficha: ficha);
} else if (ScreenFactor.isTablet(context)) {
  return FichaDualPanelView(ficha: ficha);
} else {
  return FichaDesktopView(ficha: ficha, showMetrics: true);
}
```

### Las notificaciones push como canal de operación

El administrador no necesita tener el Core UI abierto para ser alertado. `PROGRESS_EMITTER` del backend puede emitir notificaciones push (Firebase Cloud Messaging en Android/iOS, notificaciones de sistema en desktop) para incidentes críticos: pod en CrashLoopBackOff, health check fallando consecutivamente, nodo no responde.

La notificación lleva directamente a la vista de la ficha afectada con las acciones disponibles — sin navegar desde la pantalla de inicio.

---

## 9. Estrategia Offline

El Core UI es una herramienta de administración de infraestructura — por definición, no puede operar si no hay conectividad con el Core. Sin embargo, hay dos escenarios de conectividad parcial que requieren comportamiento específico:

### Escenario 1: Pérdida de conexión durante una operación activa

`PROGRESS_EMITTER` persiste todos los eventos en `.jsonl`. Cuando el Core UI reconecta, solicita el replay desde el último evento recibido. El administrador ve el estado completo de la operación — incluyendo todo lo que ocurrió mientras estuvo desconectado — sin pérdida de información.

### Escenario 2: Core UI sin conexión al Core (navegación sin red)

El Core UI muestra el último estado conocido del catálogo (del último request exitoso) con un indicador claro de "estado desconectado" y timestamp de la última actualización. No permite ejecutar operaciones en este estado — solo navegar el catálogo en modo lectura de caché.

```
⚠️  Sin conexión con el IAM Installer
    Último estado: hace 3 minutos
    [Reconectar]   [Ver estado en caché]
```

---

## 10. Seguridad por Capas

La seguridad del Core UI es inseparable de la seguridad del stack completo del SBOS. No hay capa de autenticación propia — todo se delega a los componentes de seguridad del stack.

### Capa 1: Autenticación — Keycloak OIDC + MFA

Todo acceso al Core UI requiere autenticación via Keycloak OIDC. El administrador inicia sesión una vez y el token JWT se usa para todas las llamadas REST y la suscripción WebSocket. MFA obligatorio para todos los roles.

En dispositivos móviles, la biometría (huella dactilar, Face ID) puede autenticar sin re-ingresar credenciales, pero solo después de la autenticación inicial con MFA — no la reemplaza.

### Capa 2: Autorización — RBAC con tres roles

| Rol | Puede ver | Puede ejecutar | Puede aprobar governance 3 | Puede editar RolTemplates |
|---|---|---|---|---|
| `sbos-viewer` | Todo el catálogo, dashboard, auditoría | Nada | No | No |
| `sbos-operator` | Todo + estado de sincronización de identidad | Instalar, reparar, actualizar | No | No |
| `sbos-admin` | Todo | Todo incluyendo desinstalar | Sí (primera aprobación) | Sí |

Las operaciones con `governance.category: 3` en el manifest de la ficha requieren la aprobación de dos administradores con rol `sbos-admin` distintos, con una ventana de 60 minutos entre la primera y la segunda aprobación.

### Capa 3: Confirmaciones adicionales para operaciones destructivas

Antes de ejecutar cualquier operación con `governance.category >= 2`, el Core UI presenta una pantalla de confirmación con:
- Descripción exacta de lo que va a ocurrir
- Lista de recursos que serán afectados
- Campo de texto para escribir el string de confirmación (`DESINSTALAR-POSTGRESQL`)
- En governance 3: notificación al segundo administrador requerido con link de aprobación

### Capa 4: Auditoría completa

Toda acción — incluyendo las vistas que se navegan y los botones que se presionan pero se cancelan — queda registrada en el audit log de Vault con: identidad del administrador (JWT claim), timestamp, IP de origen, acción, ficha afectada, resultado.

---

## 11. Contrato de API Core UI ↔ Core (SP-01)

Esta sección especifica el contrato formal entre el frontend Flutter y el backend FastAPI. Sin este contrato, el frontend y el backend no pueden desarrollarse en paralelo. El contrato sigue el estándar OpenAPI 3.0 — el esquema completo vive en `/etc/sbos/openapi.yaml` en el Core; esta sección documenta los endpoints críticos con su esquema de request/response.

### 11.1 Autenticación

Todos los endpoints REST y la suscripción WebSocket requieren el header:
```
Authorization: Bearer <JWT firmado por Keycloak>
```

El JWT debe tener:
- `realm_access.roles` conteniendo al menos uno de: `sbos-viewer`, `sbos-operator`, `sbos-admin`
- `exp` no expirado
- `iss` coincidente con el Keycloak del realm `sbos-installer`

Respuesta ante JWT inválido o ausente: `HTTP 401 Unauthorized`
```json
{ "error": "unauthorized", "message": "Valid Keycloak JWT required" }
```

### 11.2 Endpoints REST — Gestión de Fichas

#### `GET /api/fichas`
Lista todas las fichas del catálogo con su estado actual.

**Response 200:**
```json
{
  "fichas": [
    {
      "id": "postgresql",
      "name": "PostgreSQL",
      "version": "18.0",
      "server": "dataserver",
      "status": "INSTALADA_OK",
      "health": {
        "last_check": "2026-03-07T10:15:00Z",
        "result": "ok",
        "details": "All pods running"
      },
      "resources": {
        "cpu_millicores": 500,
        "ram_mb": 2048,
        "disk_gb": 500
      },
      "dependencies": {
        "satisfied": ["namespace-sbos-data"],
        "pending": []
      },
      "governance_category": 2,
      "actions_available": ["verify", "repair", "update", "uninstall"]
    }
  ],
  "cluster_health": "OK",
  "state_updated_at": "2026-03-07T10:15:24Z"
}
```

#### `GET /api/fichas/{ficha_id}`
Detalle completo de una ficha incluyendo logs recientes.

#### `POST /api/fichas/{ficha_id}/probe`
Ejecuta dry-run de instalación. No despliega nada.

**Response 200:**
```json
{
  "probe_id": "uuid",
  "ficha_id": "postgresql",
  "would_execute": [
    { "step": 1, "description": "Crear namespace sbos-data", "estimated_ms": 100 },
    { "step": 2, "description": "Crear PVC 500GB", "estimated_ms": 300 }
  ],
  "estimated_total_ms": 240000,
  "dependencies_ok": true,
  "resources_available": true
}
```

#### `POST /api/fichas/{ficha_id}/install`
Inicia instalación. Requiere rol `sbos-operator` o superior.

**Request:**
```json
{ "confirmed": true }
```

**Response 202 Accepted:**
```json
{
  "operation_id": "uuid",
  "ficha_id": "postgresql",
  "type": "install",
  "websocket_url": "/ws/operations/uuid",
  "started_at": "2026-03-07T10:15:00Z"
}
```

#### `POST /api/fichas/{ficha_id}/repair`
Inicia reparación. Requiere rol `sbos-operator` o superior.

#### `POST /api/fichas/{ficha_id}/update`
Inicia actualización a la última versión disponible. Requiere rol `sbos-operator` o superior.

#### `POST /api/fichas/{ficha_id}/uninstall`
Inicia desinstalación. Requiere rol `sbos-admin`. Si `governance_category = 3`, requiere aprobación dual (ver §11.5).

**Request:**
```json
{
  "confirmed": true,
  "confirmation_string": "DESINSTALAR-POSTGRESQL"
}
```

### 11.3 Endpoints REST — Dashboard y Cluster

#### `GET /api/dashboard`
Estado global del sistema: métricas del cluster, fichas en alerta, estado dSBOS Auth Enforce.

**Response 200:**
```json
{
  "cluster_health": "ALERTA",
  "nodes": [
    {
      "name": "node-01",
      "role": "dataserver",
      "cpu_percent": 85,
      "ram_percent": 62,
      "disk_percent": 45,
      "status": "Ready"
    }
  ],
  "fichas_alert": [
    {
      "id": "mailserver",
      "status": "ALERTA",
      "reason": "Health check failed 2/3 times"
    }
  ],
  "rolframework": {
    "total_roltemplates": 15,
    "synced": 14,
    "drift": 1,
    "error": 0
  }
}
```

#### `POST /api/cluster/nodes`
Agrega un nuevo nodo al cluster. Requiere rol `sbos-admin`.

**Request:**
```json
{
  "ip": "192.168.1.101",
  "ssh_password": "...",
  "role": "dataserver"
}
```

### 11.4 Endpoints REST — Identidad (SBOS Auth Enforce PAP)

#### `GET /api/identity/roltemplates`
Lista todos los RolTemplates del realm con su estado de sincronización. Requiere rol `sbos-operator` o superior.

**Response 200:**
```json
{
  "roltemplates": [
    {
      "id": "RGV_001",
      "name": "Gerente de Ventas Regional",
      "parent_id": "DGV_001",
      "sync_status": "SYNCED",
      "keycloak_synced": true,
      "tryton_synced": true,
      "last_sync": "2026-03-07T09:00:00Z",
      "privilege_mask": "0111110111"
    }
  ]
}
```

#### `GET /api/identity/roltemplates/{rol_id}`
Detalle completo de un RolTemplate incluyendo historial de cambios.

#### `POST /api/identity/roltemplates`
Crea un nuevo RolTemplate. Requiere rol `sbos-admin`.

#### `PUT /api/identity/roltemplates/{rol_id}`
Actualiza un RolTemplate existente. Inicia re-sincronización automática. Requiere rol `sbos-admin`.

#### `POST /api/identity/roltemplates/{rol_id}/force-sync`
Fuerza re-sincronización de un RolTemplate con DRIFT. Requiere rol `sbos-admin`.

**Response 202:**
```json
{
  "sync_job_id": "uuid",
  "rol_id": "RGV_001",
  "status": "queued",
  "estimated_seconds": 5
}
```

#### `GET /api/identity/usertemplates`
Lista todos los UserTemplates activos. Requiere rol `sbos-operator` o superior.

#### `POST /api/identity/usertemplates`
Asigna un RolTemplate a un usuario (crea UserTemplate). Requiere rol `sbos-admin`.

### 11.5 Endpoints REST — Governance y Auditoría

#### `GET /api/audit`
Historial de operaciones con filtros. Parámetros de query: `ficha_id`, `type`, `admin_sub`, `from`, `to`, `result`, `limit`, `offset`.

#### `GET /api/operations/{operation_id}`
Estado actual de una operación (para reconexión y replay).

**Response 200:**
```json
{
  "operation_id": "uuid",
  "ficha_id": "postgresql",
  "type": "install",
  "status": "running",
  "steps_completed": 7,
  "steps_total": 12,
  "started_at": "2026-03-07T10:15:00Z",
  "log_replay_from": 0
}
```

#### `POST /api/governance/approve/{operation_id}`
Segunda aprobación de una operación governance_category 3. Requiere rol `sbos-admin` distinto al que inició la operación.

### 11.6 Eventos WebSocket

La URL del WebSocket se obtiene en la respuesta de cada endpoint de operación (`websocket_url`). La conexión requiere el mismo JWT Bearer en el header de upgrade.

#### Evento: progreso de instalación/reparación/actualización

```json
{
  "event": "step_progress",
  "operation_id": "uuid",
  "step": 8,
  "total_steps": 12,
  "description": "Esperar pod Ready...",
  "status": "running",
  "elapsed_ms": 23000,
  "timestamp": "2026-03-07T10:15:23Z"
}
```

#### Evento: paso completado

```json
{
  "event": "step_done",
  "operation_id": "uuid",
  "step": 8,
  "description": "Pod postgresql Running",
  "duration_ms": 28400,
  "timestamp": "2026-03-07T10:15:28Z"
}
```

#### Evento: paso fallido

```json
{
  "event": "step_error",
  "operation_id": "uuid",
  "step": 8,
  "description": "Esperar pod Ready",
  "error": {
    "code": "POD_TIMEOUT",
    "message": "Pod no entró en estado Running en 5 minutos",
    "cause": "Recursos insuficientes en el nodo — RAM disponible: 512MB, requerida: 2048MB",
    "solution": "Liberar RAM o agregar un nodo con sbos cluster add-node",
    "cli_command": "kubectl describe pod postgresql-0 -n sbos-data"
  },
  "timestamp": "2026-03-07T10:20:00Z"
}
```

#### Evento: operación completada

```json
{
  "event": "operation_done",
  "operation_id": "uuid",
  "ficha_id": "postgresql",
  "type": "install",
  "result": "success",
  "total_duration_ms": 240000,
  "timestamp": "2026-03-07T10:19:00Z"
}
```

#### Evento: cambio de estado de ficha

```json
{
  "event": "ficha_state_changed",
  "ficha_id": "postgresql",
  "old_status": "INSTALANDO",
  "new_status": "INSTALADA_OK",
  "timestamp": "2026-03-07T10:19:00Z"
}
```

#### Evento: alerta del sistema

```json
{
  "event": "system_alert",
  "severity": "critical",
  "type": "pod_crash_loop",
  "ficha_id": "mailserver",
  "message": "Pod mailserver-0 en CrashLoopBackOff — 3 reinicios en 10 minutos",
  "actions": ["repair", "view_logs"],
  "timestamp": "2026-03-07T02:15:00Z"
}
```

#### Evento: cambio de estado de RolTemplate (sincronización)

```json
{
  "event": "roltemplate_sync_status",
  "rol_id": "RGV_001",
  "old_status": "SYNCED",
  "new_status": "DRIFT",
  "drift_details": "Composite Role en KC tiene permisos extra: SALES_CONFIGURE",
  "timestamp": "2026-03-07T11:00:00Z"
}
```

### 11.7 Códigos de error y su significado operacional

| Código HTTP | Error code | Significado | Acción del usuario |
|---|---|---|---|
| 400 | `validation_error` | El manifest o los parámetros son inválidos | Revisar los campos marcados en el error |
| 401 | `unauthorized` | JWT ausente, expirado o inválido | Re-autenticarse con Keycloak |
| 403 | `forbidden` | Rol insuficiente para la operación | Contactar a un `sbos-admin` |
| 404 | `ficha_not_found` | La ficha no existe en el catálogo | Verificar el ID de la ficha |
| 409 | `operation_in_progress` | Ya hay una operación activa sobre esa ficha | Esperar a que termine la operación actual |
| 409 | `dependency_not_satisfied` | Una dependencia requerida no está instalada | Instalar primero la dependencia indicada |
| 409 | `governance_pending` | Operación governance 3 esperando segunda aprobación | El segundo `sbos-admin` debe aprobar en los próximos 60 min |
| 422 | `confirmation_mismatch` | El string de confirmación no coincide | Escribir exactamente el string indicado |
| 500 | `core_error` | Error interno del Core Bash | Revisar logs: `journalctl -u sbos-core -n 100` |
| 503 | `kubernetes_unavailable` | El cluster K8s no responde | Verificar estado del cluster |

---

## 12. Stack Técnico

| Componente | Tecnología | Justificación |
|---|---|---|
| Framework UI | Flutter (Dart) | Único codebase para web, móvil, desktop. Motor de renderizado propio: UI consistente en todos los dispositivos |
| Estado — operaciones e identidad | BLoC (flutter_bloc) | Flujo Event → BLoC → State para operaciones de alto riesgo. Testeable, predecible, auditable |
| Estado — catálogo global | Riverpod | Providers globales sin dependencia de BuildContext. Ideal para estado compartido entre vistas |
| Comunicación REST | HTTP + FastAPI | Operaciones síncronas (instalar, reparar, listar fichas, gestionar RolTemplates) |
| Comunicación tiempo real | WebSocket | Progreso de operaciones en tiempo real. StreamBuilder para reconstrucción reactiva de UI |
| Autenticación | Keycloak OIDC (JWT) | SSO del stack. MFA. RBAC integrado con roles SBOS |
| Especificación de API | OpenAPI 3.0 | Contrato formal frontend/backend que permite desarrollo en paralelo |
| Notificaciones push | FCM (móvil) / sistema (desktop) | Alertas críticas sin tener el Core UI abierto |
| Métricas del cluster | Prometheus (via backend) | CPU, RAM, disco por nodo en el dashboard de salud |
| Despliegue | Contenedor K8s, namespace `sbos-installer` | La ficha del Core UI es gestionada por el propio IAM Installer |

### Nota sobre el despliegue del Core UI como ficha

El Core UI se despliega como una **ficha SBOS** en el namespace `sbos-installer`. Esto significa que el propio sistema que gestiona todas las fichas es a su vez gestionado como una ficha. El IAM Installer mantiene el Core UI vivo, lo actualiza cuando hay drift detectado en su `resources/`, y lo repara si falla. La única excepción: el Core UI no puede desinstalarse a sí mismo — esta operación está bloqueada por el YAML Engine.

---

## 13. Relación con el Ecosistema de Patrones

El Core UI no es un dashboard de Kubernetes genérico ni un Internal Developer Portal de propósito general. Es una interfaz diseñada específicamente para el modelo de fichas SBOS.

| Herramienta / Patrón | Lo que adopta el Core UI | Lo que no adopta |
|---|---|---|
| **Backstage (Spotify)** | Software catalog como fuente de verdad central. Single pane of glass para todo el stack. Navegación por ownership y dependencias | No es multi-tenant. No requiere plugins externos. No expone APIs para otros equipos |
| **Rancher UI** | App catalog con estados visuales. Gestión de cluster desde una interfaz. RBAC centralizado | No gestiona múltiples clusters. No expone recursos crudos de K8s al administrador |
| **ArgoCD UI** | Visualización del grafo de dependencias entre apps. Estado de sincronización (drift) | No es GitOps — el catálogo no está en Git sino en `servers/` |
| **Lens / K8s Dashboard** | Vista de logs en tiempo real. Terminal shell en pods | No expone pods/deployments directamente — abstrae al nivel de fichas |

**La contribución original:** la combinación de catálogo de fichas + grafo de dependencias interactivo + progreso en tiempo real con replay + dual-control de governance codificado en la UI + vistas de administración de identidad (PAP dSBOS Auth Enforce) + multi-dispositivo desde un único codebase Flutter + contrato de API OpenAPI 3.0 formal no existe en ninguna herramienta de gestión de Kubernetes de la industria. Es el cockpit soberano del SBOS.

---

## 14. Registro de Cambios v4.0

**Renumeración:** el documento pasa de SBOS-010-UI v3.0 a SBOS-007 v4.0. El Core UI ocupa el número 007 — contiguo al IAM Installer (SBOS-005) y a las Fichas (SBOS-006) — porque los tres forman la daemons soberanos del plano de control.

**Secciones nuevas en v4.0:**

§1 "Posición en el ecosistema" — documenta la posición del Core UI en la nueva numeración SBOS con tabla de relaciones.

§2 "El Core UI como PAP dSBOS Auth Enforce" — documenta la responsabilidad del Core UI como Policy Administration Point del sistema de identidad. Incluye las vistas de RolTemplates y UserTemplates, y las restricciones de acceso por rol. Esta responsabilidad no estaba documentada en v3.0.

§11 "Contrato de API Core UI ↔ Core (SP-01)" — contrato formal completo entre el frontend y el backend: todos los endpoints REST con método, path, parámetros y esquema de respuesta; todos los eventos WebSocket con sus payloads exactos; esquema de autenticación JWT; tabla de códigos de error. Desarrollado siguiendo el estándar OpenAPI 3.0.

**Modificaciones a secciones existentes:**

§6 Vista 1 — Catálogo: se agrega la "Sección de Identidad" integrada en el catálogo para acceso a las vistas de administración de identidad.

§6 Vista 3 — Dashboard: se agrega el "Panel de estado de sincronización de identidad" que muestra el estado dSBOS Auth Enforce con conteo de SYNCED/DRIFT/ERROR.

§7 Arquitectura Flutter: BLoC ampliado para incluir las operaciones sobre RolTemplates y UserTemplates.

§8 Multi-Dispositivo: Desktop añade "Gestión de RolTemplates y UserTemplates" a su lista de capacidades específicas.

§10 Seguridad — tabla de roles: se agrega columna "Puede editar RolTemplates" para documentar las restricciones de acceso al PAP.

§12 Stack Técnico: se agrega OpenAPI 3.0 como componente de especificación de API.

**Actualizaciones de referencias de numeración:** todas las referencias a números de documentos anteriores actualizadas a la nueva numeración SBOS.

---

*SKULL · SBOS · SBOS-007 · Core UI · v4.0 · Marzo 2026*

> **Referencias:** Backstage Internal Developer Portal — Spotify (2016) → CNCF Incubating (2022) · Rancher Kubernetes Management Platform — SUSE · Flutter State Management: BLoC, Riverpod, Provider — Flutter Community (2025) · Flutter WebSockets + StreamBuilder — Flutter documentation · Feature-First Architecture — Flutter community (2025) · Platform Engineering Golden Paths — Spotify, Netflix · ArgoCD App visualization — Argo Project (CNCF graduated) · OpenAPI Specification 3.0 — OpenAPI Initiative (Linux Foundation)
