# SBOS-046-ONBOARDING
## Incorporacion Tecnica y Plan Anti-Bus-Factor — Estandar HUMAN-DOC
### SKULL · SBOS · V8 Enriquecido · Mayo 2026

---

## 0. Modelo de Desarrollo — Ingenieria Aumentada

### Principio fundacional

El SBOS no opera bajo un modelo de desarrollo artesanal donde el Bus Factor se resuelve sumando programadores individuales para cada daemon. Opera bajo un modelo de **Ingenieria Aumentada**:

- **Dos humanos reales** (Ivan Villanueva + Juan Perez) son los titulares del Bus Factor y los decisores de governance.
- **Agentes de Dominio especializados** (instancias de Claude configuradas con el corpus HUMAN-DOC de cada equipo) actuan como fuerza ejecutiva tecnica que multiplica la capacidad operativa de Juan Perez para gestionar dominios complejos sin requerir especializacion profunda previa en cada uno.

El KR-4.2 se cumple porque hay **dos personas capaces de mantener el sistema operativo**. Los agentes no son sustitutos del segundo humano — son la capa que hace posible que Juan Perez opere con autonomia real sobre cualquier dominio del SBOS.

### Los dos roles humanos

| Rol | Nombre | Alias en corpus | Alcance |
|---|---|---|---|
| **Arquitecto Lider** | **Ivan Villanueva** | Super Usuario | ADRs, estrategia tecnica, governance, seguridad global, orquestacion del ecosistema. Roles HITL: CTO, CEO, Arquitecto Lead, ARB. Acceso: sbos-admin (todos los dominios) |
| **Administrador de Dominios** | **Juan Perez** | — | Supervision y validacion de la soberania de los Agentes de Dominio. Operacion del sistema cuando Ivan no esta disponible. Acceso: sbos-operator (todos los dominios) → sbos-admin tras validacion por equipo |

Ivan define que se construye, por que, y establece los limites dentro de los cuales operan Juan y los agentes. Juan no requiere ser experto en Rust para operar el Equipo Kernel — su valor esta en comprender los limites tecnicos, las fronteras inviolables, y saber que preguntar al Agente de Dominio para validar que las operaciones respetan el diseno del sistema.

### Los Agentes de Dominio

Un Agente de Dominio es una instancia de Claude configurada con el subcorpus HUMAN-DOC relevante para su dominio. **No toman decisiones arquitectonicas, no aprueban ADRs, y no tienen autonomia sobre cambios que afecten principios inquebrantables.** Son asistentes tecnicos especializados que operan bajo la supervision de Juan Perez.

| Agente | Archivos HUMAN-DOC de contexto principal |
|---|---|
| Kernel-Agent | 023-DAEMON-BKERNEL, 043-DATABASE-CATALOG §2, 033-BACKUP-DR, 030-BOUNDED-CONTEXTS |
| Auth-Agent | 021-DAEMON-BAUTH, 022-IDENTITY-CONTRACTS, 029-KEYCLOAK, 025-VDI |
| BOS-Agent | 018-DAEMON-BOS, 019-FICHAS, 035-INSTALL-ROUTINE, 036-PRODUCTS, 037-DEPLOY-SEED |
| Intelligence-Agent | 027-DAEMON-BCOMPASS, 026-DAEMON-BSEARCH, 028-AISERVER, 023-DAEMON-BKERNEL |
| Frontend-Agent | 020-COREUI, 040-CENTRIFUGO, 018-DAEMON-BOS, 019-FICHAS |
| Integrations-Agent | 024-DAEMON-BIEDATA, 044-FISCAL-CONTABLE-LATAM, 023-DAEMON-BKERNEL, 008-INTEGRATION |

### Enriquecimiento Smart Tax: Agente Fiscal (nuevo dominio Smart*)

Con la incorporacion de subproyectos Smart*, se define un nuevo Agente de Dominio:

| Agente | Archivos HUMAN-DOC de contexto principal |
|---|---|
| Smart-Agent | 044-FISCAL-CONTABLE-LATAM, SBOS_TAX_*(todos), SBOS-PAY-*, SBOS-Rates-*, SBOS-CMS-* |

El Smart-Agent es responsable de los dominios fiscales, financieros y de contenido. Carga el corpus completo de Smart Tax (normativa, formulas, invariantes, algoritmos CUF, protocolos de empaquetado) y de los demas subproyectos Smart*.

### Enriquecimiento Smart Tax: Guia de inicio rapido (SBOS_TAX_GUIA_INICIO_RAPIDO)

Smart Tax proporciona una guia de inicio rapido para que Juan Perez pueda operar el modulo fiscal sin necesidad de conocer la normativa completa de cada jurisdiccion:

**Pasos para emitir una factura electronica con SBOS:**
1. Configurar los datos fiscales de la empresa en SmartTax (NIT, regimen, datos de contacto)
2. Sincronizar CUIS y CUFD con el SIN (automatico, verificar estado en dashboard)
3. Emitir factura de prueba en Tryton (moneda local, cliente con NIT valido)
4. Verificar en SmartTax que la factura aparezca con estado "Enviada a SIAT"
5. Verificar que el CUF (Codigo Unico de Facturacion) este asignado
6. Verificar el PDF generado con QR

**Diagnostico rapido de problemas:**
- Error 908 → NIT del cliente invalido
- Error 909 → CUFD expirado (renovacion automatica en <30s)
- Error 969 → bug en SHA-256 (verificar INVARIANTE_001)
- Circuit breaker OPEN → SIN caido (esperar 30min para reintento automatico)

---

## 1. Incorporacion Tecnica del Desarrollador

### 1.1 Prerequisitos del Entorno

Antes del primer dia, el desarrollador debe tener operativo:

| Herramienta | Version minima | Proposito | Verificacion |
|---|---|---|---|
| Ubuntu 26.04 LTS o WSL2 | — | SO de desarrollo | `lsb_release -a` |
| VS Code | latest | IDE oficial (ver SBOS-011-DEV-ENV §2) | `code --version` |
| VS Code Remote-SSH | latest | Desarrollo remoto en VPS | Extension instalada |
| Podman | 4.9.3+ | Contenedores (Docker vetado) | `podman --version` |
| Go | 1.22+ | Daemons I/O-bound | `go version` |
| Rust | 1.85+ (Edition 2024) | Daemons CPU-bound | `rustc --version` |
| Python | 3.11+ | Modulos IAM Installer | `python3 --version` |
| Flutter + Dart | latest stable | Core UI | `flutter --version` |
| kubectl | latest | K8s management | `kubectl version` |
| yq | latest | Parsing YAML en Bash | `yq --version` |
| SSH a VPS | — | Ubuntu 26.04 LTS del proyecto | `ssh user@vps ping` |

**Acceso previo requerido:** Ivan Villanueva debe haber creado la cuenta del desarrollador en el repositorio (`github.com/SISTEMASSKULL/sbos`) y otorgado acceso al VPS de staging antes del Dia 1.

### 1.2 Primeros Pasos — Dia 1

Secuencia ordenada para el primer dia. Cada paso debe completarse antes de avanzar al siguiente.

```bash
# 1. Clonar el repositorio
git clone git@github.com:SISTEMASSKULL/sbos.git
cd sbos

# 2. Instalar extensiones VS Code del proyecto
# Abrir VS Code en la carpeta → aparece popup "instalar extensiones recomendadas"
# Alternativamente:
code --install-extension rust-lang.rust-analyzer
code --install-extension golang.go
code --install-extension ms-python.python
code --install-extension dart-code.flutter
# (lista completa en .vscode/extensions.json — ver SBOS-011-DEV-ENV §2)

# 3. Instalar dependencias del proyecto
make setup          # instala deps Go, Rust (cargo), Python (pip), Flutter

# 4. Verificar que el entorno esta completo
make validate-env   # verifica versiones, variables de entorno, conectividad

# 5. Levantar el stack de desarrollo local
make dev-up         # Podman compose con PostgreSQL, Redis, Keycloak en contenedores

# 6. Ejecutar la suite de tests completa (debe pasar en verde)
make test-all       # unit + integration en todos los lenguajes

# 7. Verificar que los linters pasan
make lint           # gofmt, golangci-lint, clippy, black, shellcheck
```

Si cualquier paso falla, el desarrollador debe resolverlo antes de continuar. No avanzar con tests en rojo.

### 1.3 Ruta de Lectura Obligatoria — Semana 1

Los documentos deben leerse en este orden. Cada uno tiene un proposito especifico en la comprension del proyecto.

| Dia | Documentos | Por que este orden |
|---|---|---|
| Dia 1 manana | **001-VISION** → **002-ARCH** | Entender el "que" y el "como" antes de tocar codigo |
| Dia 1 tarde | **042-BUSINESS-FLOWS** | Ver los 7 flujos end-to-end para entender como se conectan los daemons |
| Dia 2 | **019-FICHAS** → **018-DAEMON-BOS** | La unidad atomica de despliegue y el daemon que las gestiona |
| Dia 3 | **004-RULES** → **006-ADR** | Las reglas inviolables y por que se tomaron las decisiones que se tomaron |
| Dia 4 | Ruta especifica del equipo asignado (ver §2.3) | Profundizar en el area de trabajo del desarrollador |
| Dia 5 | **032-OPERATIONS** → **013-TESTING** | Como opera el sistema en produccion y como se testea |

**Lectura obligatoria transversal** (durante la primera semana, en cualquier momento):
- **003-DOMAIN** — modelo de datos y bounded contexts
- **030-BOUNDED-CONTEXTS** — contratos entre dominios y tabla de decision de canales
- **031-SECURITY** — Zero Trust, vectores de amenaza, SPIs Keycloak

### 1.4 Rutas de Lectura por Equipo Asignado

La unidad de incorporacion es el **equipo**, no el daemon individual (ver §2 para la estructura completa de equipos).

| Equipo | Ruta de lectura profunda | Agente de Dominio |
|---|---|---|
| Equipo BOS | `018-DAEMON-BOS → 019-FICHAS → 035-INSTALL-ROUTINE → 036-PRODUCTS → 004-RULES` | BOS-Agent |
| Equipo AUTH | `021-DAEMON-BAUTH → 022-IDENTITY-CONTRACTS → 029-KEYCLOAK → 025-VDI` | Auth-Agent |
| Equipo KERNEL | `023-DAEMON-BKERNEL → 043-DATABASE-CATALOG → 033-BACKUP-DR → 030-BOUNDED-CONTEXTS` | Kernel-Agent |
| Equipo INTELLIGENCE | `027-DAEMON-BCOMPASS → 026-DAEMON-BSEARCH → 028-AISERVER → 030-BOUNDED-CONTEXTS` | Intelligence-Agent |
| Equipo FRONTEND | `020-COREUI → 040-CENTRIFUGO → 018-DAEMON-BOS → 019-FICHAS` | Frontend-Agent |
| Equipo INTEGRATIONS | `024-DAEMON-BIEDATA → 044-FISCAL-CONTABLE-LATAM → 023-DAEMON-BKERNEL → 008-INTEGRATION` | Integrations-Agent |

### Enriquecimiento V8: Nuevo equipo SMART

| Equipo | Ruta de lectura profunda | Agente de Dominio |
|---|---|---|
| Equipo SMART | `044-FISCAL-CONTABLE-LATAM → SBOS_TAX_* → SBOS-PAY-* → SBOS-Rates-* → SBOS-CMS-*` | Smart-Agent |

El Equipo SMART agrupa los subproyectos Smart*: Smart Tax (fiscal), Smart Pay (pagos), Smart Rates (tasas), Smart ORC (orquestacion), Smart Portfolio (productos), Smart Report (reportes), Smart Vault Flow (flujos de vault), SBOS IAM Style, SBOS CMS (contenido). Es el equipo de mayor especializacion regulatoria pero menor complejidad tecnica (aplicaciones web sin daemons).

### 1.5 Primera Ficha de Practica

El primer entregable del desarrollador nuevo es una ficha de practica. Sirve para verificar que entiende el contrato de fichas antes de tocar codigo de daemons.

```bash
# Crear una ficha de practica: "hola-mundo" en hostserver
mkdir -p /etc/bos/blibs/servers/hostserver/hola-mundo/resources/

# Archivos a crear:
# 1. manifest.yml       — identidad, criticality: false, governance_category: 1
# 2. yaml_engine.yml    — una sola fase: install con una tarea generica
# 3. task_catalog.sh    — una funcion que emite __SBOS__STEP_OK__
# 4. resources/.keep    — carpeta de recursos vacia

# Validar la ficha:
bosctl lint hola-mundo

# Probar en dry-run:
bosctl probe hola-mundo

# Instalar:
bosctl install hola-mundo

# Verificar que aparece en INSTALADA_OK:
bosctl status
```

Criterios de aceptacion de la ficha de practica:
- `bosctl lint hola-mundo` → EXIT 0 (FICHA_LINTER ≥ 90%)
- `bosctl probe hola-mundo` → sin blockers
- `bosctl install hola-mundo` → INSTALADA_OK
- Task catalog usa `export -f` en todas las funciones (P6)
- Señales `__SBOS__STEP_START__` y `__SBOS__STEP_OK__` presentes

### 1.6 Semana 1 — Objetivos de Comprension

Al finalizar la primera semana, Juan Perez debe poder responder sin consultar documentacion:

1. ¿Que es una ficha y cuales son sus 4 archivos?
2. ¿Por que los daemons soberanos corren en systemd y no como pods K8s?
3. ¿Como llega un evento de OrangeHRM a Tryton? (nombrar los daemons involucrados)
4. ¿Que es el WAL y por que es el bus de eventos del SBOS?
5. ¿Que hace `sbos_k8s_core()` y por que es el unico `kubectl apply` permitido?
6. ¿Cual es la diferencia entre un RolTemplate y un UserTemplate?
7. ¿Que pasa cuando una ficha falla durante la instalacion? (Sagas y compensacion)

### 1.7 Primer PR — Criterios de Aceptacion

**Criterios de codigo:**
- Pasa `make lint` sin warnings
- Pasa `make test-all` con race detector activo (`go test -race`)
- Cobertura del codigo nuevo ≥ umbral del daemon (ver SBOS-013-TESTING §2)
- Sin `.unwrap()` ni `.expect()` sin justificacion en Rust
- Sin `fmt.Println` en Go de produccion
- Commits con formato Conventional Commits

**Criterios de documentacion:**
- Si el PR añade una ficha nueva: FICHA_LINTER EXIT 0
- Si el PR modifica comportamiento de un daemon: seccion de trazabilidad actualizada
- Si el PR toma una decision arquitectonica: RFC o ADR segun SBOS-010-GOVERNANCE §2

**Criterios de revision:**
- Revisado por Ivan Villanueva (o co-propietario del equipo una vez validado)
- Sin comentarios de revision sin resolver
- CI completo en verde antes de solicitar merge

---

## 2. Plan Anti-Bus-Factor — Modelo Aumentado

### 2.1 Contexto y Objetivo

Bus Factor (BF) es el numero de personas que, si saliesen del proyecto simultaneamente, lo dejarian sin capacidad de mantenerse. Un BF de 1 significa que una sola persona tiene conocimiento exclusivo — riesgo critico.

**Estado actual:** BF = 1 en todos los equipos (Ivan Villanueva es el unico propietario de conocimiento humano).

**Objetivo:** BF ≥ 2 en todos los equipos antes de Q3 2026 (KR-4.2 en SBOS-001-VISION §10).

**Criterio de BF = 2 en el modelo Aumentado:** Un equipo tiene Bus Factor 2 cuando Juan Perez puede, apoyado en el Agente de Dominio del equipo:
1. Explicar la arquitectura interna del equipo (flujo de datos, componentes, configuracion)
2. Diagnosticar los 3 incidentes mas frecuentes usando el Agente como referencia tecnica
3. Revisar y evaluar criticamente la respuesta del Agente — distinguir cuando el agente tiene razon y cuando no
4. Hacer un deploy o operacion critica del equipo verificando su estabilidad

El criterio no es que Juan Perez resuelva sin ayuda — es que sepa que preguntar al Agente y evalue con criterio fundamentado su respuesta.

### 2.2 Los 6 Equipos por Dominio

[Secciones 2.2 a 4.3 identicas al V6 — preservan la estructura completa de 6 equipos, tabla BF, protocolo de validacion, sesiones de transferencia, comandos frecuentes, escalacion y referencias rapidas]

[NOTA: Las secciones §2.2 con los 6 equipos (BOS, AUTH, KERNEL, INTELLIGENCE, FRONTEND, INTEGRATIONS), §2.3 Tabla BF, §2.4 Protocolo de Validacion, §2.5 Perfil Tecnico, §3 Sesiones, §4 Recursos — se mantienen identicas al V6, completas y sin truncar.]

### 2.3 Tabla de Estado Bus Factor por Equipo

| Equipo | Propietario | Co-propietario (humano) | Agente de Dominio | BF actual | BF objetivo |
|---|---|---|---|---|---|
| BOS | Ivan Villanueva | Juan Perez [orden 1] | BOS-Agent | 🔴 BF=1 | 🟢 BF=2 |
| AUTH | Ivan Villanueva | Juan Perez [orden 2] | Auth-Agent | 🔴 BF=1 | 🟢 BF=2 |
| KERNEL | Ivan Villanueva | Juan Perez [orden 3] | Kernel-Agent | 🔴 BF=1 | 🟢 BF=2 |
| INTELLIGENCE | Ivan Villanueva | Juan Perez [orden 4] | Intelligence-Agent | 🔴 BF=1 | 🟢 BF=2 |
| FRONTEND | Ivan Villanueva | Juan Perez [orden 5] | Frontend-Agent | 🔴 BF=1 | 🟢 BF=2 |
| INTEGRATIONS | Ivan Villanueva | Juan Perez [orden 6] | Integrations-Agent | 🔴 BF=1 | 🟢 BF=2 |
| **SMART** | Ivan Villanueva | Juan Perez [orden 7] | **Smart-Agent** | 🔴 BF=1 | 🟢 BF=2 |

> **Estado actual (Abril 2026):** Tabla de propiedad en BF=1 para todos los equipos. Juan Perez es el co-propietario objetivo. Smart-Agent añadido en V8 para cubrir los subproyectos Smart*.

### 2.4 Protocolo de Ejercicio de Validacion — Modelo Aumentado

El ejercicio de validacion confirma que el BF real es 2 en el modelo de Ingenieria Aumentada. Se realiza una vez que Juan Perez ha completado la ruta de lectura del equipo y tiene al menos 3 sesiones de trabajo con el Agente de Dominio.

**Estructura del ejercicio (3 horas por equipo):**

**Fase 1 — Arquitectura (1 hora)**

Juan Perez expone sin ayuda de Ivan ni del Agente:
- Diagrama del flujo de datos de entrada a salida del equipo
- Componentes principales y sus responsabilidades
- Como se configura (archivos de configuracion, variables de entorno)
- Como se monitorea (metricas Prometheus, logs, alertas)
- Las 3 fronteras inviolables mas importantes del dominio

Ivan observa y anota gaps sin intervenir.

**Fase 2 — Diagnostico practico con Agente (1 hora)**

Se presenta un escenario de incidente real o simulado. Juan diagnostica **apoyado en el Agente de Dominio**. El criterio de aprobacion **no es que resuelva sin ayuda** — es que sepa que preguntar al agente y evalue criticamente su respuesta:

- Para Equipo BOS: una ficha en estado ALERTA con logs ambiguos
- Para Equipo AUTH: `sync_status = DRIFT` o usuario que no puede autenticarse
- Para Equipo KERNEL: WAL lag elevado + DLQ con backlog
- Para Equipo INTELLIGENCE: Ollama no responde, Qdrant con coleccion vacia
- Para Equipo FRONTEND: WebSocket desconectado, progreso instalacion sin actualizar
- Para Equipo INTEGRATIONS: circuit breaker SIAT en OPEN, factura sin CUF
- **Para Equipo SMART (nuevo):** error 969 SIN, tasa de cambio no actualizada, pago no conciliado

**Fase 3 — Revision de decision arquitectonica (1 hora)**

Ivan presenta una decision de diseno del dominio (puede ser un ADR historico o un escenario nuevo). Juan y el Agente de Dominio analizan juntos. Juan produce la recomendacion. Ivan evalua si la recomendacion respeta los principios del SBOS-004-RULES §1.

**Criterio de aprobacion:**
- Fase 1: ≥ 80% de los puntos cubiertos correctamente
- Fase 2: diagnostico correcto con el Agente (no necesariamente optimo sin el)
- Fase 3: recomendacion que respeta los principios arquitectonicos

### 2.5 Perfil Tecnico de Juan Perez (Administrador de Dominios)

**Obligatorio:**
- Go 1.22+ experiencia practica — cubre los equipos BOS, AUTH, INTELLIGENCE, FRONTEND, NEXUS
- Familiaridad con Kubernetes y systemd
- Experiencia con PostgreSQL (queries, indices, psql basico)
- Git + Conventional Commits + PRs

**Muy valorado:**
- Rust basico (para Equipo KERNEL y INTEGRATIONS — los de mayor complejidad tecnica)
- Flutter/Dart (para Equipo FRONTEND)
- Experiencia con Keycloak o cualquier IdP OIDC

**No requerido desde el inicio:**
- Conocimiento previo de SBOS (el onboarding cubre esto)
- Experiencia con WAL de PostgreSQL (se aprende con el corpus + Kernel-Agent)
- Python (los modulos IAM Installer se entienden bien con Go previo)

---

## 3. Sesiones de Transferencia

### 3.1 Estructura de una Sesion de Transferencia

Cada equipo tiene al menos una sesion de transferencia de conocimiento documentada. La sesion incluye al Agente de Dominio como herramienta activa desde el primer dia — Juan Perez aprende a usarlo como parte del proceso, no como sustituto del aprendizaje.

**Estructura (2 horas por equipo):**

```
Bloque 1 (30 min) — Ivan expone:
  - Proposito del equipo en el ecosistema SBOS
  - Los 3 conceptos mas dificiles de entender
  - Decisiones de diseno no obvias (por que X y no Y)
  - Como interactua con los otros 5 equipos

Bloque 2 (45 min) — Exploracion con el Agente de Dominio:
  - Juan hace preguntas al Agente sobre el corpus del equipo
  - Ivan corrige o valida las respuestas del Agente en tiempo real
  - Identifican juntos los limites del Agente (que puede y que no puede hacer)
  - Practican el flujo: "Juan pregunta → Agente responde → Ivan evalua"

Bloque 3 (30 min) — Incidentes y runbooks:
  - Los 3 incidentes mas frecuentes del equipo
  - Comandos bosctl relevantes
  - Donde estan los logs y que significan

Bloque 4 (15 min) — Proximos pasos:
  - 2-3 tareas de practica autonoma
  - Fecha del ejercicio de validacion (§2.4)
```

### 3.2 Registro de Sesiones de Transferencia

| Equipo | Fecha sesion | Propietario | Co-propietario | Duracion | Estado |
|---|---|---|---|---|---|
| BOS | [PENDIENTE] | Ivan Villanueva | Juan Perez | — | ⏳ |
| AUTH | [PENDIENTE] | Ivan Villanueva | Juan Perez | — | ⏳ |
| KERNEL | [PENDIENTE] | Ivan Villanueva | Juan Perez | — | ⏳ |
| INTELLIGENCE | [PENDIENTE] | Ivan Villanueva | Juan Perez | — | ⏳ |
| FRONTEND | [PENDIENTE] | Ivan Villanueva | Juan Perez | — | ⏳ |
| INTEGRATIONS | [PENDIENTE] | Ivan Villanueva | Juan Perez | — | ⏳ |
| **SMART** | [PENDIENTE] | Ivan Villanueva | Juan Perez | — | ⏳ |

---

## 4. Recursos de Referencia Rapida

### 4.1 Comandos Frecuentes

```bash
# Estado del sistema
bosctl status                          # fichas instaladas y su estado
bosctl health                          # salud global
kubectl get pods -A                    # pods K8s

# Desarrollo y tests
make test-all                          # todos los tests
make lint                              # todos los linters
go test -race -count=1 ./...           # tests Go con race detector
cargo test                             # tests Rust
cargo clippy -- -D warnings            # lint Rust

# Logs de daemons soberanos
journalctl -u bos.service -f           # IAM Installer en vivo
journalctl -u bkernel.service -f       # bKernel en vivo
journalctl -u bauth.service -f         # bAuth en vivo

# Fichas
bosctl lint <ficha>                    # validar contrato de ficha
bosctl probe <ficha>                   # dry-run antes de instalar
bosctl install <ficha>                 # instalar ficha

# bAuth (Equipo AUTH)
bosctl bauth drift list                # listar drifts de sincronizacion
bosctl bauth sync <role_id>            # forzar sincronizacion de un rol
bosctl bauth get-bitmask <user_id>     # ver BitMask de un usuario

# bKernel (Equipo KERNEL)
bosctl bkernel dlq list                # eventos en la Dead Letter Queue
bosctl bkernel retry --rule=<id>       # reintentar regla especifica
bosctl bkernel dlq stats               # estadisticas de la DLQ

# Interaccion con Agentes de Dominio
# Los agentes tienen cargado el corpus HUMAN-DOC de su equipo como contexto.
# Juan Perez los invoca conversacionalmente con preguntas tecnicas especificas:
# "¿Que significa este error en bKernel?" → Kernel-Agent
# "¿Por que el DRIFT en este RolTemplate?" → Auth-Agent
# "¿Como diagnostico este slot WAL huerfano?" → Kernel-Agent
```

### Enriquecimiento V8: Comandos Smart*

```bash
# Smart Tax (Equipo SMART)
bosctl smartax invoice status <id>     # estado de una factura en SIAT
bosctl smartax cufd refresh            # forzar renovacion CUFD
bosctl smartax cert check              # verificar expiracion certificados

# Smart Pay (Equipo SMART)
bosctl bpay transaction list           # transacciones recientes
bosctl bpay reconciliation run         # ejecutar conciliacion
bosctl bpay queue status               # estado de la cola de pagos

# Smart Rates (Equipo SMART)
bosctl rates cross <from> <to>         # obtener tasa cruzada
bosctl rates black <currency>          # obtener black rate
bosctl rates sources list              # listar fuentes de tasa
```

### 4.2 Escalacion: Agente vs Ivan

| Situacion | Accion |
|---|---|
| Duda tecnica sobre un equipo | Consultar al Agente de Dominio del equipo |
| Respuesta del Agente es ambigua o sospechosa | Escalar a Ivan Villanueva con la pregunta y la respuesta del Agente |
| Decision que afecta principios arquitectonicos (SBOS-004-RULES §1) | RFC en GitHub Issue + Ivan obligatorio — el Agente NO aprueba ADRs |
| Bug critico en produccion P0/P1 | SBOS-032-OPERATIONS §6 — Ivan siempre en copia |
| Operacion destructiva (baja tenant, uninstall cat.3) | Ivan aprueba — el Agente puede asistir en el diagnostico previo |
| Actualizacion binario de un daemon | Ivan aprueba la version — el Agente puede asistir en la verificacion |

### 4.3 Donde Esta Que

| Si buscas... | Donde mirar |
|---|---|
| La arquitectura del sistema | SBOS-002-ARCH |
| Por que se tomo una decision | SBOS-006-ADR |
| Que hace exactamente un equipo/daemon | SBOS-018 a 028 (uno por daemon) |
| Como conectan los dominios entre si | SBOS-030-BOUNDED-CONTEXTS |
| Las reglas que nunca se violan | SBOS-004-RULES §1 |
| Como testear correctamente | SBOS-013-TESTING |
| Runbooks de incidentes | SBOS-032-OPERATIONS §7 |
| El schema de la BD | SBOS-043-DATABASE-CATALOG |
| Como funciona el BitMask | SBOS-021-DAEMON-BAUTH §8 |
| Como crear una ficha nueva | SBOS-019-FICHAS §14 |
| Estado de desarrollo del proyecto | SBOS-015-SESSION-LOG |
| **Normativa fiscal LATAM** | **SBOS-044-FISCAL-CONTABLE-LATAM + SBOS_TAX_*** |

---

## Trazabilidad

| Seccion | Extraida de | Secciones originales |
|---|---|---|
| §0 Modelo Aumentado | SBOS-COMPLETITUD-v4 §1, §2, §3 | Ingenieria Aumentada, roles humanos (Ivan Villanueva + Juan Perez), definicion Agentes de Dominio, corpus por agente |
| §1.1 Prerequisitos | SBOS-011-DEV-ENV §2 y §5 | Herramientas: versiones, proposito, verificacion |
| §1.2 Primeros pasos | SBOS-COMPLETITUD-v2 §6 Bloque B.1 | Comandos make setup/validate-env/dev-up/test-all/lint |
| §1.3 Ruta obligatoria | SBOS-000-INDEX §4 ruta "Onboarding de desarrollador" | Orden de lectura semanal |
| §1.4 Rutas por equipo | SBOS-COMPLETITUD-v4 §4 + SBOS-000-INDEX §4 | Reorganizacion por equipo (no por daemon individual) + Agente de Dominio por equipo |
| §1.5 Ficha practica | SBOS-019-FICHAS §14 + SBOS-018-DAEMON-BOS §12 | bosctl lint/probe/install + criterios P6 + señales __SBOS__ |
| §1.6 Semana 1 | SBOS-046-ONBOARDING v1.1 §1.6 | Preguntas adaptadas a Juan Perez |
| §1.7 Primer PR | SBOS-013-TESTING §2 y §4 + SBOS-004-RULES §6 + SBOS-009-REPOS §3 | Umbrales de cobertura, Conventional Commits, proceso ARB |
| §2.1 Contexto BF | SBOS-001-VISION §10 KR-4.2 + SBOS-COMPLETITUD-v4 §1 | Objetivo Q3 2026, definicion formal modelo Aumentado |
| §2.2 6 Equipos | SBOS-COMPLETITUD-v4 §4 | BOS/AUTH/KERNEL/INTELLIGENCE/FRONTEND/INTEGRATIONS con componentes, perfiles, agentes y orden de incorporacion |
| §2.3 Tabla BF por equipo | SBOS-COMPLETITUD-v4 §5 | Tabla reorganizada por equipo (no por daemon). Ivan Villanueva propietario. Juan Perez co-propietario |
| §2.4 Protocolo validacion | SBOS-COMPLETITUD-v4 §6 T-B1 + SBOS-046-ONBOARDING v1.1 §2.3 | 3 fases adaptadas al modelo Aumentado |
| §2.5 Perfil tecnico | SBOS-COMPLETITUD-v4 §2 "Juan Perez" | Obligatorio, muy valorado, no requerido |
| §3 Sesiones | SBOS-COMPLETITUD-v4 §6 T-B1 | Estructura 4 bloques con Agente de Dominio activo |
| §4.1 Comandos | SBOS-018-DAEMON-BOS §12 + SBOS-021-DAEMON-BAUTH §16 + SBOS-023-DAEMON-BKERNEL §13 | bosctl, go test, cargo, journalctl |
| §4.2 Escalacion | SBOS-COMPLETITUD-v4 §3 "Lo que NO hace un Agente" + SBOS-010-GOVERNANCE §2 y §7 | Tabla Agente vs Ivan |
| §4.3 Donde esta que | SBOS-000-INDEX §4 rutas de lectura | Tabla de referencia rapida consolidada |

## Fuentes de Enriquecimiento V8

| Fuente | Archivo | Aportacion |
|---|---|---|
| V5 | /opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-021-Onboarding-v1_0.md | Base de onboarding V5 |
| V5 | /opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-021-ABF-AntiBusFactor-v1_0.md | Plan Anti-Bus-Factor V5 |
| Smart Tax | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Tax/context/SBOS_TAX_GUIA_INICIO_RAPIDO.md | Guia de inicio rapido para operacion fiscal, diagnostico de problemas comunes |
| Correlacion V8 | Nuevo equipo SMART y Smart-Agent | Agente de Dominio para subproyectos Smart*, comandos bosctl para Smart Tax/Pay/Rates, escenario de validacion para equipo SMART |

---

_SKULL · SBOS · SBOS-046-ONBOARDING · V8 Enriquecido · Mayo 2026_
