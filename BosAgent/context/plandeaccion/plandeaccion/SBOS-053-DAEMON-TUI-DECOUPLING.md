# SBOS-053-DAEMON-TUI-DECOUPLING.md — Principio de Desacoplamiento entre el Sistema Operativo (BOS) y su Representación Visual (TUI)

**Documento vivo de arquitectura. Rige el diseño de todo daemon SBOS y de toda TUI que lo observe.**

**Versión:** 1.2.0 · **Fecha:** 2026-06-17 · **Autor:** sbos-coordinador + bos-developer
**Alineado con:** DATOS-TUI-INSTALACION.md v1.0 · SBOS-049-CONTEXT-PLANE · SBOS-050-PORT-CATALOG · SBOS-051-TENANT-SPEC v2.0
**Estándares:** systemd.io (PID 1 / journald / socket activation) · Debian Policy (debconf frontend/backend) ·
NIST SP 800-207 (Zero Trust) · ISO/IEC 27001:2022 A.8.15 (audit logging) · OpenTelemetry · WCAG 2.4.11

---

## Tabla de Contenidos

1. [La Alegoría Rectora](#1-la-alegoría-rectora)
2. [El Principio: Headless-First, UI-as-Observer](#2-el-principio-headless-first-ui-as-observer)
3. [La TUI como Canal de Entrada de Datos (no solo observador)](#3-la-tui-como-canal-de-entrada-de-datos-no-solo-observador)
4. [Precedentes de la Industria](#4-precedentes-de-la-industria)
5. [Las Tres Entidades y su Frontera](#5-las-tres-entidades-y-su-frontera)
6. [Reglas de Arquitectura (Normativas)](#6-reglas-de-arquitectura-normativas)
7. [Protocolo de Comunicación BOS ↔ TUI](#7-protocolo-de-comunicación-bos--tui)
8. [Modelo de Estado: Dónde Vive la Verdad](#8-modelo-de-estado-dónde-vive-la-verdad)
9. [Casos de Prueba de Desacoplamiento](#9-casos-de-prueba-de-desacoplamiento)
10. [Estructura de Carpetas y Componentes](#10-estructura-de-carpetas-y-componentes)
11. [Anti-Patrones Prohibidos](#11-anti-patrones-prohibidos)
12. [Checklist de Cumplimiento](#12-checklist-de-cumplimiento)
13. [Referencias y Normas](#13-referencias-y-normas)

---

## 1. La Alegoría Rectora

> **El BOS es el paciente. La TUI es el monitor de signos vitales.**
> **Y también es la forma de ingresar las órdenes médicas — pero las órdenes existen aunque el monitor esté apagado.**

Un monitor de hospital no genera el pulso, la respiración ni la actividad eléctrica del corazón: **los detecta y los representa**. Si la enfermera apaga el monitor para moverlo a otra sala, el paciente no deja de respirar. Si lo vuelve a encender cinco minutos después, el monitor no necesita "reanudar" nada — simplemente vuelve a mostrar el estado real, que nunca dejó de existir.

Pero el monitor moderno también tiene un teclado: el médico puede introducir la frecuencia del goteo, la dosis de un medicamento, el nombre del paciente. Esos datos **se transfieren al sistema hospitalario central** — no viven en el monitor. Si el monitor se cae, el expediente no desaparece. Y si el médico no está presente para escribir los datos en el teclado, puede haberlos enviado por adelantado en papel (la receta, la hoja de indicaciones) y el sistema hospitalario los procesa igual.

**Eso es exactamente lo que ocurre en SBOS:**

| Propiedad del monitor hospitalario | Propiedad equivalente exigida a la TUI |
|---|---|
| No genera el signo vital, lo lee de un sensor | La TUI no ejecuta lógica de negocio, lee eventos del daemon |
| Apagarlo no afecta al paciente | Cerrar la TUI no detiene ni pausa al BOS |
| Encenderlo no "reinicia" al paciente | Abrir la TUI no relanza la instalación ni el daemon |
| Pueden conectarse varios monitores al mismo paciente | Pueden conectarse 0, 1 o N TUIs al mismo daemon sin afectar su comportamiento |
| El sensor sigue grabando aunque nadie mire la pantalla | El daemon sigue emitiendo y persistiendo eventos aunque ninguna TUI esté escuchando |
| El médico introduce datos por el teclado del monitor, pero esos datos pasan al expediente central | La TUI recolecta parámetros del tenant durante la instalación, pero los entrega al daemon — no los retiene |
| Si el médico no usa el teclado, puede mandar las indicaciones por escrito por adelantado | Si no hay TUI, los mismos parámetros pueden entrar por `seed.yml` o `.env` |
| Reconectar un monitor trae el expediente actualizado, no el estado de la última vez que estuvo encendido | Reconectar la TUI carga el snapshot actual del daemon, no el estado previo de la sesión cerrada |

Esta alegoría **no es decorativa**: cada regla normativa de la sección 6 es una traducción literal de una de estas filas.

---

## 2. El Principio: Headless-First, UI-as-Observer

**Headless-first** significa que todo daemon, ficha o saga de BOS debe poder instalarse, ejecutarse, repararse y completarse **sin que exista ninguna interfaz visual presente**, usando únicamente la CLI (`bosctl`) o un archivo declarativo (`seed.yml`). La TUI es, por definición, un *cliente opcional y reemplazable* de esa misma capacidad — nunca su único punto de entrada.

**UI-as-observer** significa que la única función legítima de la TUI es **suscribirse** a una fuente de verdad externa (eventos del daemon, logs en disco, estado en `bkernel_db`) y traducirla a una representación humana — paneles, spinners, colores, barras de progreso. La TUI nunca posee estado que el daemon no tenga también, y nunca es el lugar donde se decide "qué pasa después" en una saga de instalación.

Esto ya está parcialmente implícito en `DATOS-TUI-INSTALACION.md` (el modo declarativo `bosctl deploy seed.yml` "sin interacción", los eventos `__SBOS__STEP_START__/OK/FAIL` vía WebSocket, el log como "tail -f del archivo"). Este documento eleva esas decisiones puntuales a **regla de arquitectura de primer nivel**, obligatoria para toda ficha, daemon y pantalla futura del wizard.

---

## 3. La TUI como Canal de Entrada de Datos (no solo observador)

Esta sección es crítica para evitar malentendidos de diseño. El principio de desacoplamiento **no significa que la TUI sea un cliente de solo lectura absoluto**. La TUI cumple dos roles distintos y ambos deben entenderse con precisión.

### 3.1 Los dos roles de la TUI

**Rol A — Observador (observabilidad):** La TUI se suscribe al canal de eventos del daemon y representa visualmente su estado: progreso de instalación, logs en tiempo real, health checks, alertas. Este rol aplica en cualquier momento — durante la instalación, después de ella, en cualquier reconexión futura.

**Rol B — Recolector de parámetros (input de instalación):** Durante el proceso de instalación asistida, la TUI actúa como formulario inteligente: recolecta datos del tenant (nombre de organización, dominio, configuración de red, credenciales iniciales, selección de fichas a instalar, etc.) y los entrega al daemon para que la saga pueda ejecutarse. Este rol es **temporal y pre-saga**: termina en el momento en que el usuario confirma y el daemon recibe los parámetros. A partir de ese punto, la TUI regresa exclusivamente al Rol A.

```
FASE DE CONFIGURACIÓN                    FASE DE EJECUCIÓN
(antes de iniciar la saga)               (saga en curso)
─────────────────────────                ─────────────────────────
TUI recolecta parámetros                 TUI solo observa
     │                                        │
     │ envía seed_params al daemon             │ recibe eventos
     ▼                                        ▼
  daemon los persiste                      daemon ejecuta
  en bkernel_db / seed.yml                 la saga
  y lanza la saga
```

### 3.2 Por qué este rol de input NO viola el desacoplamiento

El desacoplamiento no prohíbe que la TUI envíe datos al daemon — prohíbe que la TUI **ejecute** lógica de saga o **retenga** estado que el daemon no tenga. La diferencia es fundamental:

| Lo que la TUI SÍ puede hacer (Rol B) | Lo que la TUI NUNCA puede hacer |
|---|---|
| Recolectar el nombre del tenant, dominio, SMTP, selección de fichas | Decidir qué paso ejecutar o en qué orden |
| Enviar los parámetros completos al daemon como payload único | Guardar los parámetros solo en su memoria sin enviárselos al daemon |
| Mostrar un resumen de lo que se va a instalar antes de confirmar | Ejecutar ella misma algún paso de la instalación |
| Permitir que el usuario corrija un parámetro antes de confirmar | Modificar parámetros después de que la saga ya inició |

La TUI es el **formulario de la receta médica**, no el farmacéutico. La receta se entrega; después de eso, la TUI no tiene más control sobre qué sucede con los medicamentos.

### 3.3 La equivalencia declarativa: todo lo que la TUI pregunta, el `.env` o `seed.yml` puede responder

Este punto es la consecuencia más importante del desacoplamiento para el proceso de instalación:

**Cualquier parámetro que la TUI recolecta de forma interactiva debe poder ser provisto también mediante un archivo declarativo (`seed.yml`) o variables de entorno (`.env`), sin ninguna diferencia en el resultado.**

Esto tiene tres implicaciones directas:

1. **El `seed.yml` es el contrato de parámetros.** El wizard de la TUI es la representación visual de ese mismo contrato — no define su propio esquema de datos. Si se agrega un nuevo parámetro al proceso de instalación, se agrega primero al esquema de `seed.yml`, y la TUI lo incorpora como nuevo campo de formulario.

2. **La TUI puede operar en modo "pre-relleno".** Si un `seed.yml` parcial o completo ya existe (ej. generado por una automatización CI/CD), la TUI lo carga y muestra sus valores como defaults en el formulario. El usuario puede revisarlos, modificarlos y confirmar — o simplemente confirmar sin cambiar nada. Esto es el **modo híbrido** (regla DTC-09).

3. **Una instalación completamente desatendida (CI/CD, scripting, reprovisioning) no necesita que nadie abra la TUI jamás.** El mismo daemon acepta `bosctl deploy seed.yml` por CLI y produce exactamente el mismo resultado que el wizard asistido.

```
TRES FORMAS DE PROVEER LOS PARÁMETROS — MISMO DAEMON, MISMO RESULTADO

 Modo asistido        Modo híbrido           Modo declarativo
 (TUI interactiva)    (TUI + seed.yml)        (CLI pura)
 ─────────────────    ─────────────────────    ─────────────────
 bosctl setup         bosctl setup             bosctl deploy
   └─ wizard vacío      └─ wizard pre-rellenado   seed.yml
      formulario           con valores del yml      (sin TUI)
      el usuario           el usuario revisa
      completa cada        y confirma
      campo
          │                    │                     │
          └────────────────────┴─────────────────────┘
                               │
                    daemon recibe seed_params
                    persiste en bkernel_db
                    lanza la saga idéntica
```

### 3.4 Cuándo conectarse con la TUI: en cualquier momento

La TUI puede conectarse al daemon en tres momentos distintos, y en todos ellos su comportamiento debe ser correcto y coherente:

| Momento de conexión | Qué ve la TUI | Comportamiento esperado |
|---|---|---|
| **Antes de la instalación** | El daemon está idle, no hay saga activa | TUI presenta el wizard de configuración (Rol B: recolección de parámetros) |
| **Durante la instalación** | Una saga está en curso (paso N/7) | TUI recibe el `SAGA_SNAPSHOT` actual y muestra el progreso desde el punto real, sin reiniciar nada |
| **Después de la instalación** | La saga terminó (completada o fallida) | TUI muestra el estado final, logs históricos, y entra en modo de observabilidad continua del sistema en producción |

La TUI nunca pregunta "¿en qué estado estás?" y asume que el estado es cero. Siempre lee el estado real del daemon.

---

## 4. Precedentes de la Industria

No se inventa nada nuevo: este principio tiene 20+ años de precedente directo en los sistemas que SBOS ya usa como base (Ubuntu, Kubernetes, systemd). Tres ejemplos exactos:

### 4.1 Debian/Ubuntu — `debconf` (frontend/backend de configuración)

El instalador de Debian (y por herencia, Ubuntu) separa explícitamente la pregunta de la representación. Debconf provee una interfaz consistente para configurar paquetes permitiendo elegir entre varios frontends de usuario, y soporta preconfigurar paquetes antes de instalarlos, de modo que instalaciones grandes pidan toda la información necesaria por adelantado y luego hagan el trabajo mientras el usuario hace otra cosa. El frontend (`newt`, texto plano, gráfico) es completamente intercambiable y desechable; el frontend newt es un paquete mínimo usado por el instalador de Debian, mientras que el frontend de texto plano es una alternativa igualmente válida. Ningún frontend contiene la lógica de instalación — esa vive en los paquetes `udeb` que corren independientemente.

**Equivalencia directa en SBOS:** `cdebconf` → `bos` (daemon de fichas). Frontend newt/texto → TUI Bubble Tea de BOS.

### 4.2 systemd — daemon, journal y socket activation

systemd formaliza la idea de "servicio" precisamente como ausencia de interfaz: históricamente, lo que systemd llama "service" se llamaba daemon — cualquier programa que corre como proceso de fondo, sin terminal ni interfaz de usuario. El registro de actividad vive en una capa propia, no en quien lo observa: los mensajes de los servicios son capturados y procesados por systemd-journald, incluyendo syslog y todo lo que se escribe a stdout/stderr. Y el arranque de servicios es asíncrono respecto a cualquier observador: con socket activation, systemd abre los sockets incluso antes de que el servicio que los manejará haya arrancado, y los servicios activados por socket pueden iniciarse en paralelo aunque sean interdependientes — una conexión a un socket de un daemon que aún no ha arrancado simplemente espera.

**Equivalencia directa en SBOS:** `journald` → Redis Streams / log en disco de cada ficha. `journalctl -f` → la TUI en modo "Log". `systemd-journal-gatewayd` (exposición del journal por HTTP a cualquier cliente) → el WebSocket de `ScreenInstalling`.

### 4.3 Kubernetes — control plane y reconciliation loop

Aunque no es objeto de búsqueda nueva en este documento, ya forma parte del stack base de SBOS: el *reconciliation loop* de cualquier controller (y el patrón Stakater MTO que cita `SBOS-051 §6.4`) actúa contra el estado declarado en `etcd`, completamente indiferente a si `kubectl get pods -w` está abierto en alguna terminal. Apagar todos los `kubectl` del mundo no detiene un solo Pod.

### 4.4 Go — Contracts Package y DTO/Domain Split (2025)

El ecosistema Go en 2025 ha establecido un patrón claro para desacoplar servicios que comparten tipos: el **contracts package** independiente. Este patrón es directamente aplicable a la separación `bos/ ↔ tui/` que SBOS requiere.

**Principios del patrón contracts en Go (2025):**

| Principio | Aplicación en SBOS |
|-----------|-------------------|
| **Contracts package sin imports de negocio** | `internal/contracts/events/` no importa nada de `bos/` ni de `tui/` — solo stdlib. Verificable con `go list -deps`. |
| **DTO/Domain split estricto** | `SeedParams` y `SagaEvent` son structs planos (DTOs) — nunca contienen lógica de dominio, métodos de DB, ni referencias a implementaciones concretas. |
| **Interfaces definidas donde se USAN** | La interfaz `EventPublisher` se define en `bos/internal/eventbus/` (el productor). La interfaz `EventSubscriber` se define en `tui/internal/client/` (el consumidor). Ambas usan los mismos DTOs de `contracts/events/`. |
| **Zero coupling verification** | CI ejecuta `go list -f '{{.Deps}}' ./cmd/bos/ \| grep tui` — debe producir CERO matches. |
| **Versionado semántico de eventos** | Cada `SagaEvent` incluye campo `Version` explícito. Consumidores hacen branch por versión, no por presencia de campos. |

**Referencia de industria:** El patrón ginmill (2025) — modular route composition framework para Go/Gin — ejemplifica este enfoque: las features definen rutas + contratos de interfaz, la aplicación implementa la interfaz e inyecta dependencias reales. La librería nunca importa código de negocio.

### 4.5 CQRS — Command Validation en el Daemon (no en la UI)

El patrón CQRS (Command Query Responsibility Segregation) establece que los **comandos** (acciones que modifican estado) son validados por el *aggregate root* en el dominio — nunca por la capa de presentación. Esto es la base de la regla DTC-07.

**Aplicación en SBOS:**

```
TUI envía comando          Daemon recibe y decide
─────────────────          ─────────────────────
"reintentar paso 3"   →    ¿Es válido en el estado actual?
                           ¿El paso 3 existe?
                           ¿Está en estado FAIL?
                           ¿No hay compensación en curso?
                                │
                           ┌────┴────┐
                           │ SÍ      │ NO
                           ▼         ▼
                      ejecuta    rechaza con
                      comando    código error
```

**Principios CQRS aplicados:**
- La TUI **nunca** decide si un comando es válido — solo lo envía
- El daemon valida contra el estado real en `bkernel_db` (no contra lo que la TUI cree)
- Errores de validación retornan códigos explícitos (nunca "silently ignored")
- La TUI puede DESHABILITAR botones basada en el snapshot de estado, pero la validación final siempre es del daemon

**Referencia:** MS Design Patterns in .NET (Packt 2025), Capítulos 6-7: CQRS + Event Sourcing.

### 4.6 Event Sourcing Snapshot — Reconexión sin Replay Completo

El patrón Event Sourcing Snapshot resuelve el problema de reconexión tardía (DTC-06, DTC-13): un observador que se conecta tarde no necesita reproducir TODA la historia de eventos — carga el último snapshot y solo reproduce los eventos posteriores.

**Aplicación en SBOS (SAGA_SNAPSHOT):**

```
TUI se conecta tarde (saga ya en paso 5/7)
                │
                ▼
    1. TUI solicita SAGA_SNAPSHOT
    2. Daemon consulta bkernel_db.saga_state
    3. Daemon retorna:
       {
         "saga_id": "deploy-skull-prod-20260617",
         "current_step": 5,
         "steps_completed": [1,2,3,4],
         "steps_failed": [],
         "active_compensations": [],
         "ctx_id": "trace-w3c-..."
       }
    4. TUI renderiza: paso 5/7, checkmarks en 1-4
    5. TUI se suscribe a eventos incrementales desde step 5
```

**Propiedades del snapshot:**
- Inmutable una vez emitido (no se recalcula)
- Contiene el estado COMPLETO actual (no incremental)
- Incluye `ctx_id` para trazabilidad W3C
- Se genera desde `bkernel_db` (fuente de verdad), no desde memoria del daemon

**Referencia:** EventSourcing.NetCore (Oskar Dudycz, 2025), "Microservices Design Patterns in .NET" Capítulo 7.

### 4.7 CI/CD — Quality Gates Automatizados (golangci-lint 2025)

Los proyectos Go modernos en 2025 implementan **multi-gate pipelines** que verifican automáticamente la calidad del código antes del merge. Este patrón es la base de los átomos F20.D.

**Configuración de referencia para SBOS (`.golangci.yml`):**

```yaml
linters:
  enable:
    - gocyclo       # complejidad ciclomática
    - funlen        # longitud de funciones
    - dupl          # duplicación de código
    - errcheck      # errores no verificados
    - gosec         # seguridad
    - staticcheck   # bugs potenciales

linters-settings:
  gocyclo:
    min-complexity: 15    # umbral estándar industria Go
  funlen:
    lines: 100            # máximo por función
    statements: 50
  dupl:
    threshold: 100        # tokens mínimos para reportar clon

issues:
  max-issues-per-linter: 0
  max-same-issues: 0
```

**Gates en CI (secuenciales):**

| Gate | Herramienta | Qué verifica | Bloqueante |
|------|------------|-------------|------------|
| **G0** | `go build ./...` + `go vet ./...` | Compilación limpia, zero warnings | ✅ SIEMPRE |
| **G1** | `go test -race -count=1 ./...` | Tests pasan, zero data races | ✅ SIEMPRE |
| **G2-auto** | `golangci-lint run` | Complejidad ≤15, función ≤100L, duplicación <3% | ✅ Desde F20.D.1 |
| **G2-human** | Code review (Beck + SOLID) | Diseño verificado por par | 🟡 Advisory hasta Fase B |
| **G4** | ADR check | Nuevo paquete/interfaz → ADR requerido | 🟡 Advisory |

**Referencias:** go-openai (51 linters, 4-gate pipeline), langchaingo (8 linters, cyclomatic≤12), incus-os (revive, pragmatic thresholds).

---

## 5. Las Tres Entidades y su Frontera

```
┌─────────────────────────────────────────────────────────────────┐
│  ENTIDAD 1: EL DAEMON (bos / bkernel / bauth / ...)              │
│  ─────────────────────────────────────────────────────          │
│  - Ejecuta la saga de instalación (deploy.go, 7 pasos)          │
│  - Decide compensación/rollback                                 │
│  - Corre como proceso/Pod independiente (systemd unit o K8s)    │
│  - NO sabe si hay una TUI conectada, ni le importa              │
│  - Persiste su propio estado (bkernel_db) y emite eventos       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │  (2) FRONTERA DE COMUNICACIÓN
                              │  Unix socket / WebSocket / Redis Streams
                              │  — solo lectura para el cliente —
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  ENTIDAD 2: EL CANAL DE EVENTOS (bus de observabilidad)         │
│  ─────────────────────────────────────────────────────          │
│  - Redis Streams (mismo patrón que bnotify, SBOS-NOTIFY-MANUAL) │
│  - Log en disco por ficha (FICHA_LOG)                            │
│  - Tabla audit_events en bkernel_db (ISO 27001 A.8.15)          │
│  - Es PUBLISH/SUBSCRIBE, no REQUEST/RESPONSE exclusivo           │
│  - Acepta 0, 1 o N suscriptores sin que el daemon lo note        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │  (3) SUSCRIPCIÓN (opcional, reemplazable)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  ENTIDAD 3: LA TUI (Bubble Tea wizard / dashboard)               │
│  ─────────────────────────────────────────────────────          │
│  ROL A — OBSERVADOR (siempre activo cuando conectada):          │
│  - Traduce eventos a paneles, spinners, colores, checkmarks     │
│  - Lee logs desde disco (tail), nunca los almacena en memoria   │
│  - Puede cerrarse y reabrirse sin afectar al daemon             │
│  ROL B — RECOLECTOR DE PARÁMETROS (solo antes de la saga):     │
│  - Presenta formulario de configuración del tenant              │
│  - Recolecta: nombre org., dominio, fichas, SMTP, red, etc.    │
│  - Entrega los parámetros al daemon como payload único          │
│  - Al confirmar, el Rol B termina y solo queda el Rol A         │
│  SIEMPRE:                                                        │
│  - NO ejecuta pasos de saga, NO decide reintentos               │
│  - NO posee estado que el daemon no tenga ya                    │
│  - Reemplazable por: bosctl status (CLI), curl al WebSocket,    │
│    un dashboard web, o ningún cliente en absoluto               │
│  - Sus preguntas de formulario son EQUIVALENTES a seed.yml      │
└─────────────────────────────────────────────────────────────────┘
```

La frontera (2) es la única superficie de contacto permitida entre Entidad 1 y Entidad 3. Tiene **dos direcciones legítimas**:

- **daemon → TUI:** eventos de progreso, logs, snapshots de estado (Rol A, observabilidad).
- **TUI → daemon:** parámetros de configuración pre-saga (`seed_params`) y comandos de control (reintentar, abortar) — ambos validados y ejecutados por el daemon, nunca por la TUI.

**Nunca debe existir una llamada directa de la TUI a una función del daemon que ejecute un paso de instalación**; toda acción de la TUI se traduce en un mensaje enviado por el mismo canal, que el daemon interpreta y ejecuta por su cuenta.

---

## 6. Reglas de Arquitectura (Normativas)

Estas reglas son **obligatorias** para cualquier ficha, daemon o pantalla nueva. Se numeran `DTC` (Daemon-TUI-Coupling) para referencia cruzada desde ADRs futuros.

| # | Regla | Verificable por |
|---|-------|-----------------|
| **DTC-01** | Toda ficha (`bosctl ficha install <x>`) debe ser 100% ejecutable por CLI/SSH sin que exista ninguna TUI corriendo. | Ejecutar la ficha en una sesión SSH sin `bosctl setup` activo; debe completar igual. |
| **DTC-02** | El daemon nunca debe bloquearse esperando una respuesta de la TUI salvo en gates HITL explícitos (ej. `tenant remove`, §F10.C.12 de DATOS-TUI-INSTALACION). | Code review: ningún `select{}` o `channel.Recv()` del daemon depende de un cliente TUI fuera de los gates HITL documentados. |
| **DTC-03** | Todo estado de saga (paso actual, éxito/fallo, compensaciones aplicadas) se persiste en `bkernel_db` o en un CR de Kubernetes — nunca solo en memoria del proceso de la TUI. | Matar la TUI a mitad de instalación; reabrirla debe mostrar el estado correcto leído de la BD, no un estado recalculado. |
| **DTC-04** | El canal de eventos es *publish/subscribe* de un solo productor (el daemon) y N consumidores. Ninguna TUI puede ser productor de eventos de progreso. | Inspección del esquema Redis Streams: solo el daemon tiene permiso de `XADD` en el stream de progreso; las TUIs solo `XREAD`. |
| **DTC-05** | Cerrar todas las TUIs conectadas a una instalación en curso no debe pausar, cancelar ni alterar la ejecución de la saga. | Test E2E: cerrar la TUI en el paso 3/7, esperar, reconectar — debe mostrar 7/7 completado si el daemon ya terminó. |
| **DTC-06** | Reconectar una TUI después de un cierre nunca "reinicia" el proceso observado; debe hacer un *resync* leyendo el estado actual, igual que `journalctl` no reinicia el journal al abrirse. | El primer mensaje tras reconexión debe ser un snapshot de estado completo, no un evento incremental vacío. |
| **DTC-07** | Las acciones que el usuario dispara desde la TUI (reintentar, abortar, saltar) se envían como **comandos** al canal; el daemon decide si son válidas en el estado actual. La TUI no valida transición de estados por su cuenta. | El daemon debe rechazar comandos fuera de orden (ej. "reintentar" en un paso ya completado) con un código de error, no la TUI silenciosamente ignorarlos. |
| **DTC-08** | Todo log de ficha (`FICHA_LOG`) vive en disco/objeto persistente, no en buffer de memoria de la TUI. La TUI solo hace `tail`. | El log debe sobrevivir y ser legible vía `bosctl ficha logs <ficha>` aunque la TUI nunca se haya abierto. |
| **DTC-09** | El modo declarativo (`bosctl deploy seed.yml`) y el modo asistido (wizard) ejecutan exactamente el mismo código de saga subyacente — la TUI no es un camino de ejecución alterno, solo un *front-fill* de los mismos parámetros. | Mismo `seed.yml` debe producir resultado idéntico vía wizard pre-rellenado (modo híbrido) o vía CLI pura. |
| **DTC-10** | Ningún secreto (passwords, tokens Vault) transita exclusivamente por la TUI. La TUI puede solicitarlos para mostrarlos enmascarados en confirmación, pero el daemon los obtiene de Vault directamente, no los recibe reenviados desde la TUI en texto plano por un canal distinto al ya cifrado. | Inspección de `seed.yml` / payloads WebSocket: secretos nunca aparecen en logs ni en el cuerpo del evento de progreso. |
| **DTC-11** | Todo parámetro que la TUI recolecta en modo asistido debe tener un campo equivalente en el esquema de `seed.yml`. No puede existir un parámetro de instalación que solo sea accesible por TUI y no por declaración. | Verificar que `bosctl deploy seed.yml` con todos los campos del wizard produce el mismo resultado que el wizard completo. |
| **DTC-12** | Los parámetros entregados por la TUI al daemon (pre-saga) se persisten inmediatamente en `bkernel_db` y/o se materializan en un `seed.yml` generado — antes de lanzar la saga. Si la TUI se cierra después de confirmar y antes de que la saga termine, los parámetros no se pierden. | Cerrar la TUI justo después de confirmar los parámetros; el daemon debe completar la saga con los parámetros correctos, sin necesidad de reconectar la TUI. |
| **DTC-13** | La TUI en modo de observabilidad (Rol A) puede conectarse en cualquier momento — antes, durante o después de la instalación — y siempre debe presentar el estado real del daemon, nunca un estado vacío ni un estado desactualizado de una sesión anterior. | Conectar la TUI a un daemon que ya completó una instalación hace 24h; debe mostrar el estado final correcto, no una pantalla de bienvenida vacía. |

---

## 7. Protocolo de Comunicación BOS ↔ TUI

### 7.1 Capas de transporte permitidas (alineado con SBOS-050 P9: "sin HTTP entre daemons")

| Capa | Transporte | Dirección | Propósito |
|------|-----------|-----------|-----------|
| **Parámetros pre-saga** | Unix socket / gRPC local | TUI → daemon | `seed_params`: nombre de tenant, dominio, fichas seleccionadas, configuración de red, etc. El daemon los persiste antes de lanzar la saga. Equivalente al `seed.yml` en modo declarativo. |
| Comandos de control | Unix socket / gRPC local | TUI → daemon | Iniciar saga, reintentar, abortar (siempre validado por el daemon, regla DTC-07) |
| Eventos de progreso | WebSocket (sobre el mismo daemon, no HTTP entre daemons) | daemon → TUI (broadcast) | `__SBOS__STEP_START__/OK/FAIL`, ya definido en DATOS-TUI-INSTALACION §3.6 |
| Eventos persistentes / multi-tenant | Redis Streams | daemon → bus → cualquier consumidor (TUI, bnotify, auditoría) | Mismo patrón que `sbos-notifier`: el daemon nunca llama directo a un canal externo, publica al bus |
| Estado consultable | Lectura directa a `bkernel_db` o `kubectl get` sobre CRs | TUI → BD (solo lectura) | Resync al reconectar (regla DTC-06) |
| Logs | Archivo en disco / PVC | TUI → archivo (tail -f) | Igual que `journalctl -f`, nunca buffer en memoria de la TUI |

### 7.2 Formato mínimo de un evento de progreso

```json
{
  "ctx_id": "uuid-trace-context-w3c",
  "saga_id": "deploy-skull-prod-20260617",
  "step": 3,
  "step_total": 7,
  "ficha": "redis",
  "event": "__SBOS__STEP_OK__",
  "timestamp": "2026-06-17T14:32:01Z",
  "detail": "RD-01..06 pruebas pasadas"
}
```

`ctx_id` es obligatorio (SBOS-049 §9, OpenTelemetry W3C Trace Context) — permite que **cualquier** observador, incluida una TUI que se conecta tarde, reconstruya la traza completa de la saga sin haber estado presente desde el inicio.

### 7.3 Snapshot de resync (regla DTC-06)

Al conectarse, antes de recibir eventos incrementales, toda TUI debe recibir un mensaje `__SBOS__SAGA_SNAPSHOT__` con el estado completo actual (paso actual, pasos completados, errores activos). Esto es lo que distingue a una TUI "monitor de signos vitales" de un cliente que asume que el paciente "empezó a existir" cuando ella se conectó.

---

## 8. Modelo de Estado: Dónde Vive la Verdad

```
                     ┌─────────────────────────┐
                     │   bkernel_db (Postgres)  │
                     │   — fuente de verdad —    │
                     │   tabla: saga_state       │
                     │   tabla: audit_events     │
                     └────────────┬─────────────┘
                                  │ escribe
                                  │
                     ┌────────────▼─────────────┐
                     │   daemon bos/bkernel      │
                     │   (único escritor)         │
                     └────────────┬─────────────┘
                                  │ publica eventos (no escribe estado)
                                  ▼
                     ┌───────────────────────────┐
                     │ Redis Streams / WebSocket   │
                     │ (canal efímero, replay      │
                     │  limitado, no es la verdad) │
                     └────────────┬───────────────┘
                                  │ N suscriptores, 0 o más
                  ┌───────────────┼───────────────┐
                  ▼               ▼               ▼
              TUI #1          TUI #2          bnotify
           (wizard local)   (dashboard      (alerta externa
                              remoto)         vía Apprise)
```

Principio derivado: **el canal de eventos puede perder mensajes (es efímero); la base de datos no.** Si una TUI se desconecta y pierde eventos en tránsito, su mecanismo de recuperación nunca es "pedirle al daemon que reenvíe lo que se perdió" — es leer el snapshot actual de `bkernel_db`, que es exactamente lo que hace un monitor hospitalario cuando se reconecta: no pregunta "qué pasó en el minuto que estuve desconectado", lee el signo vital actual.

---

## 9. Casos de Prueba de Desacoplamiento

Estos casos deben formar parte de la suite de pruebas de cualquier ficha o daemon nuevo, como extensión de las pruebas NS-xx/PG-xx/RD-xx ya definidas en `DATOS-TUI-INSTALACION.md §4`.

| Caso | Pasos | Resultado esperado |
|------|-------|---------------------|
| **DC-01 — Instalación sin TUI** | Ejecutar `bosctl deploy seed.yml` por SSH puro, sin abrir `bosctl setup` en ningún momento. | Saga completa 7/7, health gates H-01 a H-10 verdes, sin error por "falta de interfaz". |
| **DC-02 — Cierre a mitad de saga** | Iniciar wizard, llegar a `ScreenInstalling` paso 3/7, matar el proceso de la TUI (`kill -9`). | El daemon continúa y termina los 7 pasos. Verificable vía `bosctl ficha status` o logs en disco. |
| **DC-03 — Reconexión tardía** | Repetir DC-02; 5 minutos después, abrir una nueva instancia de la TUI apuntando al mismo `saga_id`. | La TUI muestra el snapshot correcto (completado o en el paso que realmente esté), no "0/7" ni un reinicio. |
| **DC-04 — Múltiples observadores** | Con una saga en curso, conectar 2 TUIs simultáneas (ej. dos sesiones SSH distintas) al mismo `saga_id`. | Ambas muestran el mismo progreso en tiempo real; ninguna afecta a la otra ni al daemon. |
| **DC-05 — Comando inválido fuera de orden** | Desde una TUI reconectada tarde (saga ya en 7/7), enviar comando "reintentar paso 3". | El daemon rechaza el comando con error explícito (regla DTC-07); no se reinicia ni se corrompe el estado. |
| **DC-06 — Secreto no transita por TUI** | Inspeccionar el payload completo de WebSocket durante una instalación con Vault habilitado. | Ningún token, contraseña generada o credencial Shamir aparece en claro en el canal de eventos. |
| **DC-07 — Parámetros persisten tras cierre de TUI** | Completar el wizard (Rol B), confirmar los parámetros, y cerrar la TUI inmediatamente antes de que la saga inicie su paso 1. | El daemon lanza la saga con los parámetros correctos y la completa sin error. Los parámetros están en `bkernel_db`. |
| **DC-08 — Equivalencia wizard / seed.yml** | Instalar el mismo tenant dos veces: una con el wizard completo, otra con `bosctl deploy seed.yml` usando el `seed.yml` generado por el primer wizard. | Ambas instalaciones producen configuraciones idénticas (mismos health checks, mismos CRs, misma estructura en `bkernel_db`). |
| **DC-09 — Modo híbrido (seed.yml + wizard)** | Ejecutar `bosctl setup --seed seed.yml` con un `seed.yml` parcialmente relleno. | El wizard presenta los valores del archivo como defaults; los campos vacíos quedan editables. El usuario solo completa los campos faltantes. |
| **DC-10 — Conexión post-instalación (observabilidad continua)** | Conectar la TUI a un daemon cuya instalación terminó hace 24 horas. | La TUI muestra el estado final de la saga, los logs históricos y entra en modo de observabilidad del sistema en producción. No presenta pantalla de bienvenida vacía ni ofrece relanzar la instalación. |

---

## 10. Estructura de Carpetas y Componentes

Mapeo sugerido para mantener la frontera física en el código, no solo en la documentación:

```
bos/                                # el "paciente" — nunca importa nada de tui/
├── cmd/bos-daemon/                 # entrypoint del daemon, corre como systemd unit / K8s Pod
├── internal/saga/                  # deploy.go — lógica de los 7 pasos, compensación
├── internal/fichas/                # task_catalog.sh equivalentes en Go, cada ficha autocontenida
├── internal/eventbus/              # publica a Redis Streams + WebSocket, NUNCA importa paquetes de tui/
├── internal/state/                 # lee/escribe bkernel_db (saga_state, audit_events, seed_params)
├── internal/seed/                  # parser de seed.yml y .env — el contrato de parámetros de instalación
└── internal/hitl/                  # gates de confirmación humana (tenant remove, etc.)

tui/                                 # el "monitor" — puede importar tipos de eventos de bos/, nunca lógica
├── cmd/bosctl-tui/                 # entrypoint de la TUI Bubble Tea (bosctl setup)
├── internal/screens/               # ScreenWelcome..ScreenDone, solo renderizado + Tab/Enter/Esc
│   ├── wizard/                     # pantallas de Rol B: formularios de configuración pre-saga
│   └── observe/                    # pantallas de Rol A: progreso, logs, health checks, dashboard
├── internal/client/                # cliente WebSocket/gRPC: lectura de eventos + envío de seed_params y comandos
└── internal/render/                # tokens Abyss (Slate+Cyan), spinners, checkmarks — cero lógica de negocio

contracts/                           # paquete compartido, tipos puros (sin lógica)
└── events/                         # struct SagaEvent, SagaSnapshot, Command, SeedParams — el "idioma común"
    ├── seed_params.go              # schema compartido: los mismos campos que seed.yml, tipados
    └── saga_event.go               # eventos de progreso, snapshots, comandos de control
```

Regla de import: `bos/` jamás importa nada de `tui/`. `tui/` solo importa `contracts/events` (los tipos de mensaje), nunca paquetes internos de `bos/`. Esta restricción a nivel de compilador es la garantía más fuerte posible de que el acoplamiento no puede reintroducirse por accidente en un PR futuro.

El paquete `contracts/events/seed_params.go` es la fuente de verdad del esquema de parámetros de instalación. Tanto el parser de `seed.yml` en `bos/internal/seed/` como los formularios del wizard en `tui/internal/screens/wizard/` deben derivar sus estructuras de ese tipo compartido. Esto garantiza que nunca exista un campo de formulario sin equivalente declarativo, ni viceversa.

---

## 11. Anti-Patrones Prohibidos

| Anti-patrón | Por qué rompe la alegoría | Síntoma típico |
|---|---|---|
| La TUI llama directamente a una función Go del daemon (mismo binario, sin canal) | El "monitor" se vuelve parte del "corazón"; matar la TUI mata la ejecución | `tui.InstallFicha()` en vez de enviar comando por socket |
| El estado de la saga vive solo en un `struct` en memoria de la TUI | Reconectar pierde todo; no hay paciente fuera del monitor | Reabrir el wizard muestra "0/7" aunque el daemon ya terminó |
| El daemon espera `<-tuiConfirmChan` para continuar un paso no-HITL | El paciente deja de respirar si el monitor se desconecta | Instalación "congelada" si se cierra la terminal SSH |
| Los eventos de progreso solo se emiten por WebSocket, nunca se persisten | Imposible auditar (ISO 27001 A.8.15) ni hacer resync | `audit_events` vacío después de una instalación exitosa |
| Una sola TUI puede "tomar control exclusivo" del canal (lock) | Viola DTC-04 y DC-04; un monitor no le quita el sensor a otro | Segunda TUI recibe error "saga en uso" en vez de solo observar |
| Secretos generados por el daemon se envían a la TUI para que ella los reenvíe a Vault | Viola DTC-10; la TUI se vuelve custodio de secretos | Contraseña visible en payload de WebSocket o en logs de la TUI |
| Existe un parámetro de instalación que solo puede introducirse por la TUI y no por `seed.yml` | Viola DTC-11; el sistema no puede instalarse de forma desatendida | `bosctl deploy seed.yml` falla porque le falta un parámetro que "solo pregunta el wizard" |
| Los parámetros entregados por la TUI no se persisten antes de lanzar la saga | Viola DTC-12; cerrar la TUI justo después de confirmar = perder la configuración | El daemon lanza la saga con parámetros vacíos o de una sesión anterior |
| La TUI muestra una pantalla vacía o de "bienvenida" cuando se conecta a un daemon con una instalación ya completada | Viola DTC-13; el monitor no sabe que el paciente ya está vivo | Conectarse tras 24h muestra ScreenWelcome en vez del estado real del sistema |
| El wizard de la TUI define su propio esquema de campos independiente del `seed.yml` | Viola DTC-11; los dos caminos divergen silenciosamente con el tiempo | Un campo nuevo en el wizard no funciona en modo declarativo porque nadie lo agregó al parser de `seed.yml` |

---

## 12. Checklist de Cumplimiento

- [ ] Toda ficha nueva pasa el caso **DC-01** (instalable sin TUI) antes de mergear.
- [ ] El daemon (`bos`) no importa ningún paquete del módulo `tui/` (verificable con `go list -deps`).
- [ ] Todo evento de progreso incluye `ctx_id` (W3C Trace Context, SBOS-049 §9).
- [ ] El estado de cada saga se escribe en `bkernel_db` antes o al mismo tiempo que se emite el evento correspondiente (nunca solo en el canal efímero).
- [ ] Existe un mensaje `__SBOS__SAGA_SNAPSHOT__` implementado para reconexión (regla DTC-06).
- [ ] El canal de eventos soporta N suscriptores concurrentes sin lock exclusivo (caso DC-04).
- [ ] Ningún secreto aparece en el payload de eventos de progreso (caso DC-06).
- [ ] Los comandos enviados desde la TUI (reintentar/abortar/saltar) son validados por el daemon, no solo habilitados/deshabilitados en la UI (regla DTC-07).
- [ ] La estructura de carpetas separa `bos/`, `tui/` y `contracts/` según §10.
- [ ] El modo declarativo (`seed.yml`) y el modo asistido (wizard) comparten el mismo código de saga (regla DTC-09).
- [ ] Todo parámetro del wizard tiene un campo equivalente en `contracts/events/seed_params.go` y por ende en `seed.yml` (regla DTC-11).
- [ ] Los parámetros entregados por la TUI se persisten en `bkernel_db` antes de lanzar la saga (regla DTC-12). Verificable con DC-07.
- [ ] La TUI al conectarse a un daemon post-instalación muestra el estado real del sistema, no una pantalla vacía (regla DTC-13). Verificable con DC-10.
- [ ] El modo híbrido (`bosctl setup --seed seed.yml`) funciona: el wizard carga los defaults del archivo y solo pide los campos faltantes (caso DC-09).

---

## 13. Referencias y Normas

| Estándar / Proyecto | Qué aporta a este documento |
|---|---|
| **systemd.io** — PID 1, journald, socket activation | Modelo de daemon sin interfaz, log persistente independiente del lector, arranque asíncrono respecto a observadores |
| **Debian Policy / debconf(7)** | Separación formal frontend/backend de un instalador real, frontends intercambiables (newt, texto, gráfico) |
| **NIST SP 800-207** (Zero Trust Architecture) | El daemon como Policy Enforcement Point independiente de quién lo observe |
| **ISO/IEC 27001:2022 A.8.15** | Exige registro de auditoría persistente — refuerza que el log no puede vivir solo en memoria de la TUI |
| **OpenTelemetry / W3C Trace Context** | `ctx_id` como mecanismo de reconstrucción de traza para observadores que se conectan tarde |
| **WCAG 2.4.11** (Focus Visible) | Sigue rigiendo el *cómo* se ve la TUI (ya cubierto en DATOS-TUI-INSTALACION §1.1); no se duplica aquí |
| **Go Contract Package Pattern (2025)** | Paquete `contracts/events/` sin imports de negocio, DTO/domain split, zero coupling verificable con `go list -deps`. Fuente: ginmill pattern, Go microservices decoupling best practices |
| **CQRS (Command Query Responsibility Segregation)** | Commands validados por el aggregate root (daemon), no por la UI. TUI envía, daemon decide. Fuente: MS Design Patterns in .NET (Packt 2025), Cap 6-7 |
| **Event Sourcing Snapshot** | SAGA_SNAPSHOT: cargar último snapshot + replay eventos posteriores. Evita replay completo. Fuente: EventSourcing.NetCore (Oskar Dudycz, 2025) |
| **golangci-lint Quality Gates (2025)** | `gocyclo` min=15, `funlen`=100L, `dupl`<3%. Multi-gate pipeline secuencial. Fuente: go-openai, langchaingo, incus-os |
| **Baseline Metrics Pattern** | Baseline actual + no regresión en PRs nuevos. Umbrales aspiracionales a largo plazo. Fuente: Dev_Control_Certification_Method §6-7 |

---

## Referencias Internas

- **DATOS-TUI-INSTALACION.md v1.0** — pantallas, fichas, comandos y estándares de UX que este documento complementa con la regla de desacoplamiento
- **SBOS-049-CONTEXT-PLANE.md** — origen de `ctx_id` y propagación de contexto
- **SBOS-050-PORT-CATALOG.md** — regla "sin HTTP entre daemons" (P9), base de §6.1
- **SBOS-051-TENANT-SPEC.md** — patrón Stakater MTO (CR + Operator) citado en §3.3
- **SBOS-NOTIFY-MANUAL.md (bnotify)** — patrón pub/sub vía Redis Streams reutilizado en §6.1 y §7

---

*SBOS-053-DAEMON-TUI-DECOUPLING.md v1.2 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
*v1.2: Se incorporan §4.4 (Go Contracts Package 2025), §4.5 (CQRS Command Validation),*
*§4.6 (Event Sourcing Snapshot para SAGA_SNAPSHOT), §4.7 (golangci-lint Quality Gates).*
*Actualizadas referencias externas con fuentes de industria verificadas.*
*Este documento debe actualizarse cada vez que se agregue un nuevo canal de comunicación,*
*un nuevo tipo de evento, o se identifique un nuevo anti-patrón de acoplamiento.*
