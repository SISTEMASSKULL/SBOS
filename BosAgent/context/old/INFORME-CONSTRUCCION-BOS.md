# Informe de Construcción — BOS IAM Installer
## SBOS · bos-agent · Daemon Soberano · v0.1.0 · 2026-05-18

---

## 1. BOS es un Sistema Operativo — No es una metáfora, es arquitectura

**SBOS es un sistema operativo empresarial.** La analogía con un SO convencional no es una metáfora — es **técnicamente precisa**, validada por tres correspondencias directas documentadas en SBOS-002-ARCH.

### La analogía del SO — tabla canónica (SBOS-002-ARCH §1)

| SO Convencional | SBOS | Correspondencia técnica |
|---|---|---|
| **Hardware** | **PostgreSQL (WAL)** | El WAL es el bus de eventos del sistema — como las interrupciones del hardware |
| **Kernel (Linux)** | **bKernel** (daemon de consolidación) | Reacciona a eventos del WAL como Linux reacciona a IRQs — sin polling |
| **Init system (systemd)** | **IAM Installer (`bos.service`)** | PID 1 del plano empresarial — arranca antes que todo, vigila todo |
| **Package manager (apt)** | **Sistema de fichas SBOS** | `apt install` ≡ `bosctl install` — dependencias, scripts, estado |
| **Procesos / Aplicaciones** | **Fichas del BOS** (118 apps en 20 servidores) | Cada ficha es un proceso del SO empresarial |
| **Shell / Interfaz** | **SBOS VDI + Core UI** | La shell que ve el usuario humano |
| **Gestión de identidad** | **Keycloak** (gobierno central) | /etc/passwd + PAM del SO empresarial |
| **Subsistema de E/S** | **biedata** (aduana soberana) | Entrada/Salida de datos hacia el exterior |
| **Procesador de señales** | **bCompass** (inteligencia) | Orquestación de rutas de IA y análisis |

### Las tres correspondencias técnicas directas (SBOS-002-ARCH v5 §2)

**Correspondencia 1 — bKernel e interrupciones del hardware:**
En Linux, el kernel no interroga al hardware continuamente. El hardware genera una interrupción y el kernel reacciona. El bKernel hace lo mismo: no interroga a las apps. PostgreSQL genera un evento en el WAL y el bKernel reacciona. **El mecanismo es arquitectónicamente idéntico: reactividad basada en eventos, no polling.**

**Correspondencia 2 — Sistema de fichas y package manager:**
`apt install postgresql` descarga un paquete, resuelve dependencias, ejecuta scripts pre/post-install, registra el estado en su base de datos, y el servicio queda activo. El sistema de fichas SBOS hace exactamente lo mismo con cada aplicación del stack — **el concepto es el mismo, el dominio es diferente** (apps empresariales en lugar de paquetes del SO).

**Correspondencia 3 — IAM Installer e init system:**
`systemd` es el proceso PID 1. Arranca antes que todo, vigila servicios, los reinicia si fallan, gestiona dependencias entre ellos. **El IAM Installer tiene exactamente ese rol para el stack SBOS**: es el primer proceso con intención, arranca antes que cualquier app, vigila todo el stack permanentemente.

### BOS y bKernel — el sistema operativo y su kernel

En esta arquitectura, **bKernel es el kernel del sistema operativo SBOS** y **BOS es el sistema operativo mismo**:

- **bKernel** es al dominio de los DATOS lo que BOS es al dominio de la INFRAESTRUCTURA (SBOS-023-DAEMON-BKERNEL §2). Escucha el WAL de PostgreSQL, detecta cambios en cualquier app del stack, aplica reglas YAML declarativas, y produce escrituras idempotentes — sin que las apps sean modificadas. Es el corazón de datos del SBOS: CDC Real-Time, MDM Hub, Rule Engine Declarativo, Event Bus Implícito (CQRS), Auditoría Global, Indexación Federada.

- **BOS** gestiona el ciclo de vida completo del sistema: lo instala desde cero (~48 min desde Ubuntu virgen), lo mantiene vivo permanentemente (6 loops 24/7), y puede ser apagado y reiniciado como cualquier sistema operativo — para liberar memoria, reestructurar servicios, o aplicar actualizaciones mayores.

### Nada funciona sin BOS

**ADR-001 — BOS como capa de sistema operativo** (2026-05-15):
> BOS corre como root y actúa como capa de sistema operativo. Es el único proceso privilegiado que ejecuta comandos de sistema. El operador humano interactúa con el sistema exclusivamente a través de `bosctl` o Core UI — nunca mediante `sudo` directamente.

> **Punto único de fallo:** Si BOS no arranca, no hay forma privilegiada de administrar el sistema. Mitigación: watchdog con rollback automático al binario anterior.

**SBOS-IAM-Style identity-book:**
> Si SBOS es el sistema operativo de la empresa, el IAM Installer es su proceso de arranque permanente.

**SBOS-001-VISION:**
> SBOS NO es suite de software. SBOS NO es instalador de apps. SBOS NO es producto cloud. **SBOS SÍ es sistema operativo empresarial.** SBOS SÍ es control plane soberano con vigilancia y reparación.

### BOS es reiniciable como un SO — shutdown y boot en cascada

Como cualquier sistema operativo, BOS puede ser apagado y reiniciado para:
- **Liberar memoria** — reciclar goroutines, limpiar cachés internas, reiniciar conexiones
- **Reestructurar** — aplicar cambios de configuración que requieren reinicio del daemon
- **Actualizar** — `bosctl update-daemon` fuerza verificación de nueva versión, `bosctl rollback` revierte al binario anterior

**El shutdown es en cascada — como apagar un SO real.** Cuando BOS se detiene, la secuencia es: BOS → Kubernetes → Ubuntu. No existe "Kubernetes sin BOS" — BOS es el init system del plano empresarial, y su parada desencadena la parada ordenada de todo el stack. Es equivalente a `shutdown -h now` en un SO convencional: todo se detiene de forma controlada, no queda nada corriendo.

**El boot es automático — como el POST→bootloader→kernel→init.** Cuando Ubuntu arranca, systemd levanta Kubernetes y BOS en secuencia automática:
1. Ubuntu boot → systemd multi-user.target
2. CRI-O + kubelet arrancan → cluster K8s se inicializa
3. `bos.service` arranca (`After=network-online.target`, `WantedBy=multi-user.target`)
4. `ExecStartPost` verifica 5 criterios de estabilización en 60 segundos
5. Si la verificación falla → rollback automático a `bos.prev`
6. BOS retoma el control: verifica el estado de cada ficha, reconcilia, reanuda los 6 loops

El ciclo de reinicio es seguro porque:
- `.sbos_state.json` persiste en disco — el estado sobrevive al reinicio
- `Restart=always` garantiza que systemd re-levanta BOS en 5 segundos si el proceso muere
- `ExecStartPost` con health check + rollback automático protege contra binarios corruptos
- El binario anterior se conserva 7 días (`bos.prev`)

**Pero mientras BOS está detenido, nada en SBOS funciona.** No hay instalación de fichas, no hay health checks, no hay reconciliación, no hay detección de drift, no hay respuesta a `bosctl`, no hay Core UI. Kubernetes y Ubuntu también están detenidos — el shutdown es total. Es exactamente igual a cuando un kernel de Linux se detiene: el sistema entero deja de funcionar hasta el próximo boot.

### Ficha técnica

| Campo | Valor |
|---|---|
| Nombre conceptual | SBOS IAM Installer: Infrastructure Provisioning & Lifecycle Orchestrator |
| Naturaleza | **Sistema operativo empresarial** — no un script, no un instalador |
| Paradigma | **OS-on-OS**: BOS es a Ubuntu lo que Ubuntu es al hardware |
| Kernel del SO | **bKernel** — CDC WAL, Rule Engine, Event Bus, MDM Hub |
| Init system | **bos.service** — PID 1 del plano empresarial |
| Package manager | **Sistema de fichas** — `bosctl install` ≡ `apt install` |
| Shell | **SBOS VDI + Core UI** — la interfaz del usuario |
| Daemon | `bos` (binario Go estático, CGO_ENABLED=0, arranque <100ms) |
| Servicio systemd | `bos.service` (Type=simple, Restart=always, Delegate=yes) |
| CLI | `bosctl` (binario Go, Unix socket `/run/bos/bos.sock`) |
| TCP | `0.0.0.0:9443` (HTTPS para Core UI) |
| Config | `/etc/bos/bos.toml` |
| Estado persistente | `/etc/bos/.sbos_state.json` (solo STATE_MANAGER escribe, fcntl flock) |
| Unidad atómica | **Ficha** — `manifest.yml` + `task_catalog.sh` + `yaml_engine.yml` + `resources/` |
| Lenguaje daemon | Go 1.22+ |
| Scripts OS | Bash 5.x |
| Módulos de dominio | Python 3.11+ + Cython |

### Qué hace BOS como sistema operativo

- **Day 0 — Bootstrap:** Transforma Ubuntu virgen en cluster K8s con 118 fichas en 20 servidores lógicos (~48 min). Es el equivalente a bootear un SO por primera vez.
- **Day 1+ — Operación permanente:** 6 loops 24/7 que observan, administran y reparan la salud del sistema en tres niveles: SO → K8s → Fichas
- **Control plane de soberanía:** Gestión de flota de instalaciones cliente vía SKULL Release Plane con cadena de confianza Ed25519 + SHA-256
- **Ciclo de vida de aplicaciones:** Instala, actualiza, repara y desinstala fichas con patrón Saga y compensación — equivalente a `apt install/update/repair/remove`
- **Gestión multitenant:** Alta, modificación, suspensión (2 modalidades) y baja definitiva de tenants (empresas cliente)

### Lo que hace permanentemente (24/7, como cualquier SO)

| Loop | Intervalo | Función |
|---|---|---|
| HEALTH_CHECKER | Cada 30s | Pollea cada ficha, clasifica en 5 estados canónicos, dispara repair si `auto_repair=true` |
| RECONCILE_SCHEDULER | Cada 300s | Compara estado declarado vs actual, detecta drift por SHA-256 |
| RELEASE_MANAGER | Cada N horas | Pull-only al SKULL Release Plane, verifica firma Ed25519 |
| PLUGIN_LOADER | Continuo (inotify) | Descubre fichas nuevas en `servers/` sin reiniciar el daemon |
| GROWTH_DETECTOR | Cada 30 min | Evalúa saturación CPU>80%, RAM>85%, disco>75%, recomienda escalar |
| API REST + WebSocket | Permanente | Responde a `bosctl` y Core UI, emite eventos en tiempo real |

### Gestión de crecimiento horizontal — GROWTH_DETECTOR + INFRA_CONFIGURATOR

BOS —como sistema operativo— no solo mantiene el estado actual, sino que **planifica y ejecuta el crecimiento** cuando el sistema se satura.

**GROWTH_DETECTOR** (loop cada 30 min) evalúa la saturación de recursos del cluster:

| Métrica | Umbral | Acción |
|---|---|---|
| CPU | >80% sostenido 10 min | Recomendar `add_node` o `increase_resources` |
| RAM | >85% sostenido 10 min | Recomendar `add_node` |
| Disco | >75% | Recomendar expansión o `add_node` |

Cuando GROWTH_DETECTOR determina que se necesita un nuevo nodo, **INFRA_CONFIGURATOR** ejecuta el procedimiento de 9 pasos con solo 3 parámetros desde Core UI:

```
Parámetros: IP del VPS + contraseña SSH root + tipo de servidor lógico

INFRA_CONFIGURATOR.py:
  1. Conectar al nuevo VPS vía SSH
  2. Aplicar hardening Ubuntu (idéntico al bootstrap)
  3. Instalar CRI-O + kubeadm + kubelet en versiones idénticas al cluster
  4. Generar token kubeadm join fresco (válido 24h)
  5. Ejecutar kubeadm join
  6. kubectl label node <nodo> tipo=<servidor-lógico>
  7. Verificar nodo en estado Ready
  8. K8s schedula pods automáticamente según nodeSelector
  9. Notificar al administrador: nodo disponible
```

Nada requiere modificar ninguna ficha, configuración de aplicación, ni DNS. TopologySpreadConstraints asegura distribución uniforme de réplicas entre nodos.

### Supervisión de daemons y servicios

BOS supervisa **todos los daemons del ecosistema SBOS** a través de HEALTH_CHECKER. Cada daemon —bKernel, bAuth, bSearch, biedata, bCompass, bhnexus, banexus— es monitorizado como cualquier ficha del sistema: health check cada 30s, clasificación de estado, repair automático si `auto_repair=true`. Específicamente, BOS supervisa el comportamiento de **bAuth en sus tareas de autenticación**: verifica que Keycloak esté respondiendo, que los service accounts de bAuth estén operativos, y que la cadena OIDC/JWT funcione — si algún eslabón falla, BOS lo detecta y dispara repair.

### Lo que NO hace

- No toma decisiones destructivas sin confirmación humana (governance dual-control)
- No modifica código de fichas — solo las ejecuta
- No mantiene estado fuera de `.sbos_state.json` (Principio P8)
- No llama a `kubectl` excepto vía `sbos_k8s_core()` (Principio P1)
- No envía datos del cliente al SKULL Release Plane (pull-only, Principio P15)
- No puede auto-eliminarse (invariante de seguridad)
- No modifica datos dentro de las bases de datos (jurisdicción del bKernel)

---

## 2. El Concepto de Ficha — Unidad Atómica Declarativa

La **ficha** es la unidad atómica de despliegue del ecosistema SBOS. Cada aplicación, base de datos o componente del sistema es una ficha. No hay "instalación especial" ni "bootstrap privilegiado" — el mismo motor que instala PostgreSQL instala K8s. La diferencia está en el `workload.type` (bash en host vs contenedor en K8s).

### Estructura canónica de una ficha

```
/etc/bos/blibs/servers/<servidor>/<nombre_ficha>/
├── manifest.yml        # Declaración: nombre, versión, servidor, execution_order,
│                       #   depends_on, recursos, health check, criticality
├── yaml_engine.yml     # Fases: pre_install → install → post_install → repair → update → uninstall
├── task_catalog.sh     # Funciones Bash con señales __SBOS__STEP_*__, export -f obligatorio (P6)
└── resources/          # K8s manifests, configs, secrets, templates
```

### Los 3 tipos de ficha

| Tipo | workload.type | Cuándo se ejecuta | Ejemplos |
|---|---|---|---|
| 1 — Sistema | bash | Antes de K8s o en mantenimiento del host | sbos-bootstrap-os, sbos-bootstrap-k8s |
| 2 — Aplicación | kubernetes | Con K8s operativo | postgresql, keycloak, redis, kong |
| 3 — Opcional Pura | kubernetes | En cualquier momento (`criticality: false`) | LibreOffice, configs |

**Tipo 1 (Sistema):** Scripts Bash que corren directamente en el host. El IAM Installer los verifica en cada boot. No aparecen en menús de Core UI.

**Tipo 2 (Aplicación):** Desplegadas vía `sbos_k8s_core()`. Instalables por CLI o Core UI. Tienen dependencias dinámicas — el DEPENDENCY_RESOLVER computa la cadena completa automáticamente.

**Tipo 3 (Opcional Pura):** Sin dependencias críticas. `criticality: false`. No bloquean ni son bloqueadas por otras fichas.

### Los 3 niveles de operación

| Nivel | Qué es | Comando | Especificación |
|---|---|---|---|
| **Ficha** | Unidad atómica (postgresql, keycloak, roundcube) | `bosctl install <ficha>` | SBOS-006 |
| **Producto** | Manifiesto que agrupa fichas + configuraciones | `bosctl product install <producto>` | SBOS-032 |
| **Deploy** | Productos + datos del cliente (seed file) | `bosctl deploy <archivo.yml>` | SBOS-033 |

---

## 3. Sistema de Estados de Ficha

### Los 5 estados canónicos (SBOS-019-FICHAS §5)

| Estado | Condición | Acciones disponibles |
|---|---|---|
| **BLOQUEADA** | Dependencias no satisfechas | Ver requisitos, instalar cadena de dependencias |
| **NO_INSTALADA** | Dependencias satisfechas, lista para instalar | Instalar |
| **INSTALADA -- OK** | Pod Running + health OK | Verificar, Repair, Update, Uninstall |
| **INSTALADA -- ALERTA** | CrashLoopBackOff o health fallando | Repair, Ver logs, Diagnosticar |
| **ACTUALIZACION_DISPONIBLE** | Drift en resources/ o nueva versión disponible | Update, Skip version, Ver diff |

### Los 5 estados transicionales internos

`INSTALANDO`, `ACTUALIZANDO`, `REPARANDO`, `DESINSTALANDO`, `ERROR`

Los estados transicionales no son visibles externamente. Siempre desembocan en un estado canónico.

### Tabla completa de transiciones válidas

```
NO_INSTALADA     → INSTALANDO
INSTALANDO       → INSTALADA_OK | NO_INSTALADA (compensación)
INSTALADA_OK     → ACTUALIZANDO | REPARANDO | DESINSTALANDO | ALERTA
ALERTA           → INSTALADA_OK | REPARANDO
ACTUALIZANDO     → INSTALADA_OK | ALERTA
REPARANDO        → INSTALADA_OK | ALERTA
DESINSTALANDO    → NO_INSTALADA | INSTALADA_OK (compensación restauró)
BLOQUEADA        ↔ NO_INSTALADA
ERROR            → REPARANDO | NO_INSTALADA
```

Cualquier transición fuera de esta tabla → STATE_MANAGER rechaza con error crítico.

### La transición clave: BLOQUEADA ↔ NO_INSTALADA

Esta transición bidireccional es el mecanismo que gobierna la instalación bajo demanda:

- **BLOQUEADA → NO_INSTALADA:** El DEPENDENCY_RESOLVER detecta que todas las dependencias están en `INSTALADA_OK`. Desbloquea la ficha. Ahora está disponible para instalar.
- **NO_INSTALADA → BLOQUEADA:** Una dependencia fue desinstalada. La ficha vuelve a bloquearse para proteger la integridad del sistema.

**El sistema no asume — verifica.** No es posible instalar Roundcube si PostgreSQL está en `NO_INSTALADA`. El administrador puede instalar prerrequisitos en cadena con un solo comando (`bosctl install` con `--deps`).

### Cómo un cambio de estado dispara la instalación

El Saga Install (7 pasos, `internal/installer/saga.go`):

1. `DEPENDENCY_RESOLVER.verify_all_satisfied` — ABORT si falla
2. `STATE_MANAGER.transition → INSTALANDO` — compensación: volver a NO_INSTALADA
3. `YAML_ENGINE pre_install`
4. `YAML_ENGINE install` — compensación: YAML_ENGINE uninstall
5. `YAML_ENGINE post_install`
6. `HEALTH_CHECKER.verify` — fallo → ALERTA
7. `STATE_MANAGER → INSTALADA_OK + register_hashes`

### El DEPENDENCY_RESOLVER — algoritmo

1. Lee todos los `manifest.yml` del catálogo
2. Construye grafo dirigido: cada `depends_on` es una arista
3. Detecta ciclos (error fatal si existen)
4. Orden topológico de Kahn
5. Dentro del mismo nivel, ordena por `execution_order`
6. Entrega lista ordenada al IAM Installer

### Dos mecanismos de orden

| Mecanismo | Campo | Prioridad |
|---|---|---|
| execution_order | Preferencia global (menor = antes). `sbos-bootstrap` reserva order 0 | Baja |
| depends_on | Restricción absoluta. Declara qué fichas deben estar en `INSTALADA_OK` | **Total** — siempre prevalece |

---

## 4. Bootstrap vs Instalación bajo Demanda — El Sistema de Productos

La distinción entre qué se instala automáticamente y qué se instala bajo demanda opera a nivel de **Producto** (no de ficha individual).

### El producto bootstrap — `auto_install: true`

El producto `bootstrap` es el **único** con `auto_install: true`. El daemon `bos` lo ejecuta automáticamente al detectar que no hay cluster K8s. No tiene `requirements` porque es el primero — no hay nada preexistente.

### Catálogo de 8 productos

| Producto | Categoría | Fichas | Requisitos | Tiempo | Opcional | auto_install |
|---|---|---|---|---|---|---|
| **bootstrap** | platform | 16 | (ninguno) | ~48 min | No | **true** |
| mail | communication | 4 | PG + KC + Kong + Vault | ~12 min | No | false |
| erp | business | 2 | PG + KC + Kong | ~8 min | No | false |
| documents | business | 5 | PG + KC + Kong + MinIO | ~10 min | No | false |
| monitoring | operations | 4 | PG + KC | ~8 min | No | false |
| vdi | platform | 4 | PG + KC + Kong + MinIO | ~15 min | No | false |
| ai | intelligence | 6 | PG + Kong | ~12 min | **Sí** | false |
| devops | operations | 3 | PG + KC + Kong + MinIO | ~15 min | No | false |

### Flujo de procesamiento de un producto on-demand

```
bosctl product install mail
  │
  ▼
1. LEER manifiesto products/mail.product.yml
  │
  ▼
2. EVALUAR requirements (para cada ficha):
     postgresql → STATE_MANAGER: ¿INSTALADA_OK?
       SÍ → Verificar necesidades (BDs, usuarios) → CREAR lo faltante, SKIP lo existente
       NO → ERROR: "postgresql no instalada. Ejecute: bosctl product install bootstrap"
  │
  ▼
3. INSTALAR fichas nuevas:
     Para cada ficha en fichas[]:
       ¿Ya INSTALADA_OK? → SKIP (idempotente)
       ¿BLOQUEADA?       → ERROR con dependencias faltantes
       ¿NO_INSTALADA?    → INSTALAR con parámetros del producto
  │
  ▼
4. VERIFICAR producto → HEALTH_CHECKER
  │
  ▼
5. REGISTRAR producto en .sbos_state.json
```

### Deploy vía seed file

```yaml
# cliente.deploy.yml
products:
  - bootstrap         # OBLIGATORIO — siempre primero
  - mail              # Correo corporativo
  - erp               # ERP y contabilidad
  # - documents       # Gestión documental (comentado = no instalado)
  # - vdi             # Escritorios virtuales
  # - ai              # Inteligencia artificial
```

```bash
bosctl deploy cliente.deploy.yml
# [bos] Producto 1/3: bootstrap → 16 fichas → 48m
# [bos] Producto 2/3: mail → 4 fichas → 12m
# [bos] Producto 3/3: erp → 2 fichas → 8m
# [DEPLOY COMPLETO]: Productos: bootstrap, mail, erp | Fichas: 22 | Tiempo: 67m 27s
```

---

## 5. Servidores Lógicos — 20 Dominios de Despliegue

Las fichas se organizan en servidores lógicos, cada uno con su namespace K8s:

| # | Servidor | Namespace | Fichas | Ejemplos |
|---|---|---|---|---|
| S-HOST | hostserver | sbos-installer | 11 | bootstrap-os, bootstrap-k8s, nginx-web, linkerd, kyverno |
| S01 | dataserver | sbos-data | 13 | postgresql, redis, minio, vault, mysql, citus, pgbackrest |
| S02 | gatewayserver | sbos-gateway | 4 | kong, nginx, certbot, modsecurity |
| S03 | identityserver | sbos-identity | 5 | keycloak, oauth2-proxy, wazuh-manager, openvas |
| S04 | erpserver | sbos-erp | 2 | tryton, rabbitmq-erp |
| S05 | devserver | sbos-apps | 7 | smarttax, smartreport, smartrates, smartpay |
| S06 | appsserver | sbos-apps | 16 | gnuhealth, saleor, orangehrm, openproject, zammad |
| S07 | reportserver | sbos-apps | 6 | jaspersoft, superset, airflow, openmetadata |
| S08 | docserver | sbos-docs | 7 | paperless-ngx, tesseract, solr, docuseal |
| S09 | searchserver | sbos-search | 2 | elasticsearch, rabbitmq-search |
| S10 | commsserver | sbos-comms | 12 | postfix, roundcube, rocketchat, mattermost, freepbx |
| S11 | vdiserver | sbos-vdi | 3 | fedora-kde, nextcloud, onlyoffice |
| S12 | monitorserver | sbos-monitor | 4 | grafana, prometheus, alertmanager, alloy |
| S13 | geoserver | sbos-geo | 5 | traccar, fleetbase, xibo, novosga |
| S14 | opsserver | sbos-ops | 8 | gitlab, k6, trivy, bareos, velero, searxng |
| S15 | aiserver | sbos-ai | 7 | ollama, open-webui, qdrant, langfuse, flowise |

**Evidencia en disco:** 118 `manifest.yml` + 114 `task_catalog.sh` en 20 directorios bajo `BosAgent/staging/core/servers/`. 18/18 fichas certificadas HEALTHY en sbos-k8s (S-23).

---

## 6. Arquitectura de Componentes — Las Tres Partes del BOS

El BOS tiene tres partes conceptuales: el **Instalador** (que ejecuta las operaciones sobre el SO), la **BOS API** (el plano de control que gobierna), y el **Core UI** (la interfaz humana del administrador).

| Parte | Qué es | Rol |
|---|---|---|
| **Instalador** | `install.sh` + Core SP-01 (4 scripts Bash, 2,033 líneas) | Ejecuta operaciones reales sobre el SO y K8s. Es el "ejecutor" — recibe órdenes del daemon y las materializa. |
| **BOS API** | Daemon `bos` (Go) + `bosctl` CLI (Go) + API REST/WebSocket | Plano de control. Recibe comandos del administrador (vía bosctl o Core UI), gobierna los 6 loops permanentes, expone API REST en `:9443` y WebSocket para eventos en tiempo real. |
| **Core UI** | Flutter/Dart (web + desktop) | Interfaz gráfica del administrador. Consume la BOS API. Muestra dashboard, estado de fichas, logs de operaciones, y permite ejecutar todas las acciones disponibles en bosctl. |

**Principio de equivalencia (SBOS-018 §3):** Todo lo que `bosctl` puede hacer, Core UI podrá hacer — misma API REST, mismos permisos, mismos logs de auditoría.

### Implementación — C1 a C4

Las tres partes se implementan en 4 componentes técnicos:

| # | Componente | Lenguaje | Tipo | Estado | Parte |
|---|---|---|---|---|---|
| C1 | **bos** — daemon binario | Go 1.22+ | systemd service (Restart=always) | 75% | BOS API |
| C2 | **bosctl** — CLI administrativa | Go 1.22+ | binario CLI | 50% | BOS API |
| C3 | **Core SP-01** — scripts maestros Bash | Bash 5.x | scripts OS | 95% | Instalador |
| C4 | **Core UI** — interfaz administrativa | Dart/Flutter | web + desktop | 0% (bloqueado) | Core UI |

### C1 — bos daemon (Go)

```
bos (binario Go estático, systemd)
├── cmd/bos/main.go          # 1,017 líneas — entrypoint, flags, señales OS, 2 modos
├── internal/
│   ├── server/              # HTTP :9443 + WebSocket
│   │   ├── api.go           # 506 líneas — REST: /health, /status, /fichas, /api/dashboard
│   │   └── ws.go            # 181 líneas — WebSocket hub para Core UI (eventos en tiempo real)
│   ├── installer/           # Saga orchestrator
│   │   ├── saga.go          # 325 líneas — Install/Update/Repair/Uninstall con señales
│   │   └── compensator.go   # 134 líneas — Rollback compensation chain
│   ├── state/               # STATE_MANAGER (único escritor, P8)
│   │   └── manager.go       # 361 líneas — fcntl flock, 10 estados, transiciones atómicas
│   ├── k8s/                 # sbos_k8s_core() — único kubectl apply (P1)
│   │   └── core.go          # 220 líneas — Wrapper kubectl con --dry-run previo
│   ├── health/              # HEALTH_CHECKER (cada 30s, loop permanente)
│   │   └── checker.go       # 274 líneas — Pollea, clasifica, dispara repair
│   ├── reconcile/           # RECONCILE_SCHEDULER (cada 300s, loop permanente)
│   │   └── scheduler.go     # 231 líneas — Compara estado declarado vs actual
│   ├── release/             # RELEASE_MANAGER (pull-only, loop permanente)
│   │   └── manager.go       # 234 líneas — HTTP GET al SKULL Release Plane
│   ├── plugin/              # PLUGIN_LOADER (inotify, loop permanente)
│   │   └── loader.go        # 322 líneas — Escanea servers/, hashes SHA-256
│   └── config/
│       └── config.go        # 302 líneas — bos.toml parsing (BurntSushi/toml)
├── go.mod / go.sum / Makefile
└── Tests: 1,839 líneas (config_test, health_test, reconcile_test, state_test)
```

**Métrica real (2026-05-18):** 4,553 líneas Go producción + 1,839 líneas tests = 6,392 líneas totales en 22 archivos.

### C2 — bosctl CLI (Go)

```
bosctl/
├── cmd/bosctl/main.go       # 446 líneas — subcomandos vía Unix socket
├── internal/client/         # Cliente HTTP al socket /run/bos/bos.sock
└── internal/output/         # Formateo: tabla, JSON, YAML
```

**Implementados (6/15+):** status, install, health, logs, reload, help.
**Faltantes:** update, repair, remove, probe, lint, version, fichas, product, tenant, deploy, update-daemon, rollback.

### C3 — Core SP-01 (Bash)

```
/opt/bos/core/
├── 00_MASTER_INSTALL_SBOS.sh    # 513 líneas — Entry point: comando + ficha_id
├── 00_TASK_CATALOG_SBOS.sh      # 677 líneas — Funciones genéricas (nunca nombra apps, P3)
├── 00_YAML_ENGINE_SBOS.sh       # 491 líneas — Intérprete declarativo vía yq
├── 00_CLEANUP_SBOS.sh           # 268 líneas — Limpieza post-operación
└── 00_ARCHITECTURE_SBOS.yml     # Mapeo nombre_tarea → función_bash
```

El Core **no sabe qué aplicaciones existen** — solo lee contratos de fichas y los ejecuta. Modo de operación: **Absorber → Ejecutar → Liberar** (P7).

### C4 — Core UI (Flutter)

```
core_ui/
├── lib/
│   ├── main.dart / app.dart
│   ├── screens/  (dashboard, fichas_list, ficha_detail, operations_log, settings)
│   ├── services/ (api_client → :9443, ws_client → WebSocket eventos)
│   ├── models/   (ficha, operation)
│   └── widgets/  (health_card, progress_bar)
├── pubspec.yaml / test/
```

**Estado: 0%** — Bloqueado por SBOS IAM Style (bstyle) y VDI Server.

---

## 7. Los 8 Daemons Soberanos — Gobernados por BOS

**BOS gobierna todos los daemons del ecosistema SBOS.** Todos los daemons trabajan sobre BOS — BOS es el init system que los instala, los supervisa, y los mantiene vivos. Sin BOS, ningún daemon funciona.

Los 8 daemons corren como servicios systemd **fuera de K8s**, con acceso directo a PostgreSQL vía socket Unix:

| Daemon | Servicio | Lenguaje | Rol en el ecosistema |
|---|---|---|---|
| **bos** | bos.service | Go | **Init system del SO empresarial.** Instala, vigila, repara y gobierna a todos los demás daemons. |
| **bKernel** | bkernel.service | Rust | **Kernel de datos.** Habla el idioma universal de las aplicaciones del SBOS a través del WAL de PostgreSQL. Administra la coordinación y comunicación entre todas las aplicaciones mediante los datos gobernados por PostgreSQL + Patroni. CDC, MDM Hub, Rule Engine, Event Bus. |
| **biedata** | biedata.service | Rust | **Aduana soberana.** Todo dato que entra o sale del SBOS pasa por aquí. Escritura coordinada antiloop WAL. |
| **bCompass** | bcompass.service | Go | **Orquestador de inteligencia.** Rutas de IA, invocación de LLMs, workflows de análisis. |
| **bSearch** | bsearch.service | Go | **Sistema de búsquedas inteligentes del SBOS.** Indexación federada vía WAL, búsqueda Meilisearch + SQL. |
| **bAuth** | bauth.service | Go | **Sistema de autenticación del SBOS.** BitMask 64-bit, 3 dominios, PAP/PIP/PDP/PEP. Gobierna identidad y privilegios. |
| **bhnexus** | bhnexus.service | Go | **Broker de conectividad externa (host).** WebSocket mTLS, proxy de hardware universal. Comunica al BOS con el exterior. |
| **banexus** | banexus.service | Go | **Centinela de conectividad externa (edge).** Corre en Fedora VDI. Interceptor USB/shell. Comunica al BOS con dispositivos cliente. |

**bNexus (bhnexus + banexus)** es el sistema de comunicación del BOS con el mundo exterior: bhnexus en el host Ubuntu como broker de hardware, banexus en el cliente Fedora como centinela de dispositivos.

**bStyle** (no es un daemon systemd) es el módulo de gobernanza de branding e identidad visual y gráfica del SBOS — 30 documentos de especificación v3.3.3, 0% implementado. Gobierna cómo se ve y se presenta el sistema operativo empresarial.

### Posición en el host

```
HOST UBUNTU (systemd — fuera de K8s)
├── bos.service         → Plano de control: instala, vigila, repara
├── bkernel.service     → Plano de datos (WAL slot: bkernel_slot)
├── biedata.service     → Plano de integración (WAL slot: biedata_slot)
├── bcompass.service    → Plano de inteligencia (WAL slot: bcompass_slot)
├── bsearch.service     → Plano de búsqueda
├── bauth.service       → Plano de identidad (BitMask 64-bit)
├── bhnexus.service     → Plano de conectividad (broker hardware, WebSocket mTLS)

CLIENTE FEDORA (systemd --user)
└── banexus.service     → Plano edge (interceptor USB/shell, centinela)
```

**¿Por qué fuera de K8s?** Acceso directo al WAL de PostgreSQL vía socket Unix con latencia <50µs. K8s no puede garantizar este nivel de acoplamiento con el sistema de archivos del host.

---

## 8. El Sistema Operativo en Operación — Capas, Kernel y Planos

La arquitectura de SBOS como sistema operativo se materializa en 6 capas, 3 niveles de observación permanente, y 3 planos de soberanía — todo orquestado por BOS con bKernel como kernel de datos.

### El kernel del SO: bKernel — corazón de datos

Así como el kernel de Linux gestiona procesos, memoria e interrupciones de hardware, **bKernel es el kernel del sistema operativo SBOS** (SBOS-023-DAEMON-BKERNEL §2, SBOS-002-ARCH §2):

| Función del kernel Linux | Equivalente en bKernel |
|---|---|
| Interrupciones de hardware (IRQ) | Eventos del WAL de PostgreSQL — reacciona sin polling |
| Planificador de procesos | Rule Engine — reglas YAML declarativas que disparan escrituras |
| Gestión de memoria | MDM Hub — consolidación de datos maestros entre aplicaciones |
| Sistema de archivos | Writer Pool — escrituras idempotentes con DLQ |
| Llamadas al sistema (syscalls) | CDC Real-Time — captura cambios en cualquier app del stack |
| Auditoría del kernel | Auditoría Global — trazabilidad completa de datos |

**6 capacidades del bKernel:**
1. **CDC Real-Time:** Escucha el WAL de PostgreSQL — reacciona a cambios sin modificar las apps
2. **MDM Hub:** Consolida entidades maestras (personas, productos, organizaciones) entre aplicaciones
3. **Rule Engine Declarativo:** Reglas YAML — condición → acción — sin código imperativo
4. **Event Bus Implícito (CQRS):** El WAL es el bus de eventos — las apps escriben, bKernel propaga
5. **Auditoría Global:** Toda mutación de datos queda registrada con trazabilidad
6. **Indexación Federada:** Alimenta a bSearch con cambios en tiempo real vía Redis Stream

**bKernel está fuera de K8s por diseño (ADR-006):** acceso directo al WAL de PostgreSQL vía socket Unix con latencia <50µs. K8s no puede garantizar este nivel de acoplamiento con el sistema de archivos del host.

### Las 6 capas del sistema (SBOS-002-ARCH §3)

```
┌── CAPA DE USUARIO (K8s)          — Core UI Flutter, SBOS VDI Fedora KDE
├── CAPA DE GOBIERNO (K8s)         — Keycloak, Vault, Kong API Gateway
├── CAPA DE APLICACIONES (K8s)     — 16 servidores lógicos, 118 fichas
├── CAPA DE DATOS (K8s)            — PostgreSQL Patroni HA, Redis, MinIO
├── CAPA DAEMONS SOBERANOS (host)  — 8 daemons systemd (BOS + bKernel + 6 más)
└── CAPA DE INFRAESTRUCTURA (host) — Ubuntu, CRI-O, Calico, systemd
```

### Los 3 niveles de observación permanente del SO

BOS —como sistema operativo— observa y actúa en tres niveles simultáneamente. Esto es lo que lo distingue de cualquier orquestador:

| Nivel | Qué observa | Acción ante fallo |
|---|---|---|
| **SO** | kernel Linux, systemd, disco, RAM, CPU, CRI-O, actualizaciones | Reinicio/diagnóstico/cleanup/alerta |
| **K8s** | API Server, etcd, nodos, certificados, CNI, CoreDNS | Diagnóstico/repair/alerta rotación |
| **Fichas** | health.check_command, drift SHA-256, dependencias, versiones | repair si auto_repair / notifica si requiere humano |

**¿Por qué BOS y no solo K8s?** K8s reinicia pods pero no puede: repararse a sí mismo, diagnosticar problemas del SO, reconciliar integraciones Keycloak/Kong/Vault, ni gestionar el ciclo completo de fichas con dependencias, versionado y compensación. BOS sí.

### Los 3 planos arquitectónicos de soberanía

```
PLANO 1 — SKULL RELEASE PLANE (infraestructura SKULL)
  Release Server: /api/v1/releases/latest, /dist/iam-installer-<arch>,
  /dist/checksums.sha256, /dist/checksums.sha256.sig (Ed25519)
        │  HTTPS · Solo descarga (pull-only) · Soberanía absoluta
        ▼
PLANO 2 — IAM INSTALLER (host Ubuntu del cliente) ← EL SISTEMA OPERATIVO
  bos.service (systemd) + bKernel + Core SP-01 (Bash) + Módulos Python + Core UI
  .sbos_state.json · servers/ · /opt/bos/ · iam-installer.prev
        │  kubectl apply vía sbos_k8s_core() · Único punto de escritura en K8s
        ▼
PLANO 3 — KUBERNETES CLUSTER (plano de ejecución)
  14 namespaces · 118 apps como pods · 20 servidores lógicos
```

**Frontera de soberanía absoluta:** tráfico entre Plano 1 y Plano 2 es exclusivamente de descarga. SKULL no tiene acceso SSH al cliente, no accede a la API K8s del cliente, no recibe datos operacionales. El Plano 2 (BOS + bKernel) ES el sistema operativo — todo ocurre dentro de esa frontera.

---

## 9. La Cadena de Construcción Completa — Del Ubuntu Virgen al VDI Server

### Fase 0: BOS se instala a sí mismo

```bash
curl -sSL https://get.skbos.io/installer | sudo bash
```

`install.sh` (523 líneas) en dos modos:
- `--container`: Contenedor privileged + systemd para greenfield testing
- `--host <IP>`: Bare metal con verificación de prerrequisitos

El daemon queda instalado como `bos.service` con `Restart=always`. Desde este punto, BOS nunca se detiene.

### Fase 1: Bootstrap — 16 fichas (~48 min)

El daemon detecta que no hay cluster K8s y ejecuta el producto `bootstrap` (único con `auto_install: true`):

```
sbos-bootstrap-os (order: 0, bash, T+0:02)
  └──▶ sbos-bootstrap-k8s (1, bash, T+0:07)
         └──▶ sbos-bootstrap-platform (2, bash, T+0:15)
                ├──▶ network-validator (3, k8s, T+0:20)
                │      ├──▶ postgresql (100, StatefulSet, T+0:21)
                │      │      ├──▶ vault (120, T+0:27) ──▶ keycloak (130, T+0:30) ──▶ kong (145, T+0:34)
                │      │      └──▶ grafana (210, T+0:44)
                │      ├──▶ redis (110, T+0:24)
                │      └──▶ minio (115, T+0:24)
                ├──▶ nginx (140, T+0:34)
                ├──▶ linkerd (150, T+0:40)
                ├──▶ kyverno (155, T+0:40)
                └──▶ prometheus (200, T+0:44) ──▶ grafana (210)
                
Todo converge → sbos-bootstrap-hardening (300, bash, T+0:48)
═══════════════════════════════════════
  SISTEMA BASE COMPLETO · kube-bench CIS Level 1: 42/42 PASS
```

### Fase 2: Daemons soberanos

Los 8 daemons systemd se levantan en el host. BOS ya está corriendo. Los otros 7 (bkernel, biedata, bcompass, bsearch, bauth, bhnexus, banexus) se instalan como fichas tipo bash o via systemd.

### Fase 3: Apps de negocio (on-demand)

```bash
bosctl product install erp        # Tryton + RabbitMQ (~8 min)
bosctl product install mail       # Postfix + Roundcube + RocketChat (~12 min)
bosctl product install documents  # Paperless + OnlyOffice (~10 min)
bosctl product install ai         # Ollama + Qdrant + Flowise (~12 min)
```

O vía deploy seed file: `bosctl deploy cliente.deploy.yml`

### Fase 4: VDI Server — El hito de validación final

**VDI Server (S11, 3 fichas: fedora-kde + nextcloud + onlyoffice) es el Ciclo 8 del plan de completitud.** Es el penúltimo hito antes de Core UI (Ciclo 9).

### Lo que VDI prueba

Cuando VDI Fedora KDE está operativo con un usuario autenticado, demuestra que **toda la cadena funciona**:

| Lo que prueba | Componentes involucrados |
|---|---|
| BOS existe como daemon y controla el cluster | `bos.service`, K8s API operativa |
| SO host está sano | Ubuntu, CRI-O, systemd, kernel |
| K8s cluster está operativo | API Server, Calico CNI, MetalLB, Linkerd mTLS |
| PostgreSQL + Vault + Keycloak funcionan | Bootstrap fichas 05, 08, 09 |
| Los 8 daemons soberanos operan | bkernel, biedata, bcompass, bsearch, bauth, bhnexus/banexus |
| bAuth gobierna privilegios | BitMask Engine 64-bit, 3 dominios, Redis cache |
| Keycloak autentica usuarios | Realm SBOS, OIDC, JWT, PAM module |
| Red corporativa funciona | iptables owner, Squid proxy, External ACL |
| NFS entrega homes | NFS4 exports, cuotas, autofs |
| Recursos se controlan por app | cgroups v2, systemd scopes |
| **El ciclo SO → K8s → Daemons → Apps → Usuario funciona** | **Toda la cadena** |

VDI es el punto donde el "Sistema Operativo Empresarial Consciente" se vuelve tangible. Sin VDI, SBOS es infraestructura que existe pero nadie usa. Con VDI, todo el recorrido queda probado.

---

## 10. Estado Real de Construcción

### Resumen global: ~65%

| Componente | Estado | Líneas | Archivos | Compila |
|---|---|---|---|---|
| C1 — bos daemon | 75% | 4,553 Go + 1,839 tests | 22 .go | Sí (golang:1.22) |
| C2 — bosctl CLI | 50% | 446 Go | 1 .go | Sí |
| C3 — Core SP-01 | 95% | 2,033 Bash | 5 .sh + 1 .yml | N/A |
| C4 — Core UI | 0% | 0 | 0 | No iniciado |
| Staging — fichas | 100% | 118 manifests + 114 task_catalogs | 20 servidores | 18/18 HEALTHY |
| **Total** | **~65%** | **8,425 líneas** | **~260 archivos** | — |

### Detalle por paquete Go

| Package | Archivo | Líneas | Estado | Gap |
|---|---|---|---|---|
| cmd/bos | main.go | 1,017 | Completo | — |
| internal/config | config.go | 302 | Completo | — |
| internal/state | manager.go | 361 | Completo | — |
| internal/server | api.go | 506 | Completo | — |
| internal/server | ws.go | 181 | Completo | — |
| internal/installer | saga.go | 325 | Completo | — |
| internal/installer | compensator.go | 134 | Completo | — |
| internal/k8s | core.go | 220 | Completo | — |
| internal/plugin | loader.go | 322 | Completo | — |
| internal/health | checker.go | 274 | Parcial | No ejecuta probes reales |
| internal/reconcile | scheduler.go | 231 | Parcial | No compara SHA-256 real |
| internal/release | manager.go | 234 | Parcial | Falta verificación Ed25519 |
| cmd/bosctl | main.go | 446 | Parcial | 6/15+ comandos |

---

## 11. Motores Internos

### 11.1 STATE_MANAGER (`internal/state/manager.go`, 361 líneas)

Único escritor de `.sbos_state.json` (Principio P8). Bloqueo exclusivo vía `fcntl(F_WRLCK)` con timeout de 5 segundos. Implementa 10 estados (5 canónicos + 5 transicionales), validación de transiciones atómicas, registro de hashes SHA-256, y descubrimiento inicial de fichas vía `Register()`.

### 11.2 Saga Orchestrator (`internal/installer/saga.go`, 325 líneas)

Ejecuta operaciones delegando a `00_MASTER_INSTALL_SBOS.sh` y parseando el protocolo de señales `__SBOS__STEP_*__`. Compensación automática al fallar cualquier paso.

| Saga | Pasos | Timeout | Compensación |
|---|---|---|---|
| Install | 7 | 30 min | Uninstall completo |
| Update | 5 | 15 min | Rollback a versión anterior |
| Repair | 4 | 10 min | Vuelta a ALERTA |
| Uninstall | 4 | 10 min | Reinstalación completa |

### 11.3 Protocolo de señales `__SBOS__`

| Señal | Significado |
|---|---|
| `__SBOS__STEP_START__` | Inicio de paso |
| `__SBOS__STEP_OK__` | Paso exitoso |
| `__SBOS__STEP_FAIL__` | Fallo → dispara compensación |
| `__SBOS__STEP_SKIP__` | Saltado (idempotencia) |
| `__SBOS__STEP_PROGRESS__` | Progreso N/TOTAL |
| `__SBOS__DONE__OK__` | Saga completada |
| `__SBOS__DONE__ERROR_COMPENSABLE__` | Fallo con compensación automática |
| `__SBOS__DONE__ERROR_FATAL__` | Requiere intervención humana |
| `__SBOS__META__{NAMESPACE,POD,PVC,SECRET,CONFIG}__` | Metadata de recursos creados |

### 11.4 HEALTH_CHECKER (`internal/health/checker.go`, 274 líneas)

Loop cada 30s. Ejecuta `health.check_command` de cada ficha. Clasifica: ok, degraded, error, pending. Si `consecutive_failures >= 3` → ALERTA. Si `auto_repair: true` → dispara repair.

### 11.5 RECONCILE_SCHEDULER (`internal/reconcile/scheduler.go`, 231 líneas)

Loop cada 300s. Compara `.sbos_state.json` vs cluster K8s real. Gap: no compara SHA-256 de resources/.

### 11.6 RELEASE_MANAGER + PLUGIN_LOADER

**RELEASE_MANAGER** (234 líneas): Pull-only HTTP GET al SKULL Release Plane. Canales canary/early/stable. Rollback automático del daemon si falla health check post-update.

**PLUGIN_LOADER** (322 líneas): Escaneo continuo de `servers/`. Descubre fichas nuevas sin reiniciar. Verifica SHA-256.

---

## 12. Servicio systemd — Restart=always

```ini
[Unit]
Description=BOS — Sovereign Business OS (IAM Installer)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/bos/bin/bos --config /etc/bos/bos.toml
ExecStartPost=/opt/bos/bin/bosctl health --wait-stable=60 --on-fail=rollback
Restart=always
RestartSec=5
User=root
Group=root
Delegate=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**Propiedades de daemon UNIX:**
- `Restart=always` — nunca queda caído, systemd lo re-levanta en 5s
- `ExecStartPost` — verifica estabilización en 60s: 5 criterios → rollback si falla
- `Delegate=yes` — BOS gestiona cgroups de sus procesos hijos (K8s, contenedores)
- Binario estático Go — sin dependencias de runtime, arranque <100ms
- Rollback automático: `bos.prev` conservado 7 días

---

## 13. CI Gates y Criterios de Aceptación

| # | Criterio | Estado | Evidencia |
|---|---|---|---|
| 1 | Bootstrap: `bos.service` arranca + `bosctl install` 3× sin error | No verificado | Sin ciclo Operador formal |
| 2 | Health check: HEALTH_CHECKER reporta 10+ fichas | No verificado | Checker no ejecuta probes reales |
| 3 | Saga install: ficha instalada con compensación | No verificado | Código existe, sin prueba formal |
| 4 | Saga repair: diagnosis_first → repair → verificación | No verificado | Sin prueba formal |
| 5 | CI gates Go: gofmt, golangci-lint, go test -race >=80% | Parcial | 4 test files (1,839 líneas), sin CI |
| 6 | CI gates Bash: shellcheck 0 issues | No verificado | Scripts existen, sin shellcheck |
| 7 | CI gates Flutter: flutter analyze clean, flutter test >=70% | No aplica | C4 no iniciado |
| 8 | 14 principios SP-01: validate_sp01.py EXIT 0 | No verificado | Sin validación automatizada |

---

## 14. Gaps y Riesgos

| # | Gap | Componente | Severidad | Bloqueante |
|---|---|---|---|---|
| G1 | Sin ejecución de tests unitarios con CI | C1 | CRÍTICO | Sí |
| G2 | Health checker no ejecuta probes reales | C1 | ALTO | Sí |
| G3 | Reconcile no detecta drift por hash | C1 | ALTO | Sí |
| G4 | bosctl faltan 10+ comandos | C2 | ALTO | Sí |
| G5 | Sin DEPENDENCY_RESOLVER (DAG, Kahn) | C1 | ALTO | Sí |
| G6 | Sin verificación Ed25519 en Release Manager | C1 | MEDIO | No |
| G7 | SBOS IAM Style sin implementar | bstyle | CRÍTICO | Sí — bloquea C4 |
| G8 | Core UI Flutter no existe | C4 | MEDIO | No hasta resolver G7 |

---

## 15. Lo que distingue a BOS de la industria

| Capacidad | Terraform | ArgoCD | K8s Operators | Crossplane | **BOS** |
|---|---|---|---|---|---|
| Day 0 (SO+K8s) | No | No | No | No | **Sí** |
| Day 1 (Apps) | Sí | Sí | Sí | Sí | **Sí** |
| Reconciliación Day 2 | No | Sí | Sí | Sí | **Sí** |
| Self-healing SO+K8s+Apps | No | No | Parcial | No | **Sí** |
| Cadena custodia Ed25519 | Parcial | Parcial | No | No | **Sí** |
| Gestión flota clientes | No | No | No | No | **Sí** |
| Offline completo | No | No | Sí | No | **Sí** |
| Governance dual-control | No | Sí | No | No | **Sí** |
| Rollback auto daemon | No | No | No | No | **Sí** |
| Sagas con compensación | No | No | No | No | **Sí** |
| Soberanía total (pull-only) | No | No | Parcial | No | **Sí** |
| Fichas editables en producción | N/A | N/A | No | No | **Sí** |
| Sistema de estados (10 estados) | No | No | No | No | **Sí** |
| Bootstrap→on-demand vía estado | No | No | No | No | **Sí** |

---

## 16. SBOS IAM Style (bstyle) — Gobernador de Identidad Visual

Parte del alcance extendido del BOS. No es un Smart Module — es un **Gobernador de Core**, al mismo nivel arquitectónico que Keycloak.

| Campo | Valor |
|---|---|
| Marca interna | `bstyle` |
| Categoría | Gobernador de Core |
| Protocolo | WebSocket |
| Color de capa | Sky `#0EA5E9` |
| Estado | 100% especificado (v3.3.3, 30 docs), 0% implementado |

**Arquitectura:** brand-worker (orquestador Python reactivo a eventos WAL), brand-api (WebSocket server), brand-engine (motor generador SVG/PNG, 79 destinos, 12 composiciones), brand-db (schema PostgreSQL 9 tablas).

---

## 17. Plan de Completitud

### Ciclos BOS (1-3) — Alcance directo

**Ciclo 1 — Daemon Go (75% → 95%)**
- Tests unitarios con CI (ya existen 4 archivos, 1,839 líneas)
- Health checker con ejecución de probes reales
- Reconcile scheduler con SHA-256 drift detection
- DEPENDENCY_RESOLVER (DAG, algoritmo de Kahn)

**Ciclo 2 — bosctl CLI (50% → 100%)**
- Comandos: update, repair, remove, probe, lint
- Comandos: version, fichas, product, tenant, deploy

**Ciclo 3 — Bash engine + CI gates (95% → 100%)**
- Shellcheck 0 issues + validate_sp01.py + validate_sp02.py
- CI gates Go: gofmt, golangci-lint, go test -race >=80%

### Ciclos ecosistema (4-9)

```
C1 (daemon Go) → C2 (bosctl CLI) → C3 (Bash polish)
                                        │
                                        ▼
                                 C4 (SBOS IAM Style)
                                        │
                                        ▼
                                 C5 (Keycloak + Tryton + OrangeHRM)
                                        │
                                        ▼
                                 C6 (bKernel) → C7 (BauthAgent)
                                        │
                                        ▼
                                 C8 (VDI Server)  ← Hito de validación
                                        │
                                        ▼
                                 C9 (Core UI + Brand Composer)
```

**Cada ciclo posterior depende de que el anterior esté completo.** VDI Server (Ciclo 8) es el punto donde se valida la cadena completa SO → K8s → Daemons → Apps → Usuario final. Core UI (Ciclo 9) es la interfaz administrativa que consume tanto BOS como VDI.

---

## 18. Historial de Sesiones

| Sesión | Fecha | Resumen |
|---|---|---|
| S-22 | 2026-05-14 | 9 fichas corregidas (3 patrones + image + probe) |
| S-23 | 2026-05-14 | Certificación BOS — 18/18 fichas HEALTHY en sbos-k8s |
| S-24 | 2026-05-15 | 101 fichas corregidas (112/112 patrones correctos) |
| S-25 | 2026-05-15 | Planificación con SBOS IAM Style integrado |

---

## 19. Próximos pasos — Certificación Operador

El nodo `bos-agent` está en SKDATA como `en-construccion`. Para declararlo operativo se requiere el ciclo del Operador:

1. Ejecutar `install.sh --container` y verificar que BOS arranca sin error
2. Verificar health de las 16 fichas bootstrap con `bosctl status`
3. Probar idempotencia: `bosctl install <ficha>` 3 veces consecutivas
4. Probar repair: `bosctl repair <ficha>` con diagnosis_first
5. Probar cambio de estado: BLOQUEADA → NO_INSTALADA → INSTALADA_OK → ALERTA → REPARANDO → INSTALADA_OK
6. Registrar evidencia bash en `trazas/test-bos-[timestamp].log`
7. Actualizar SKDATA: `arboles.nodo` estado → `operativo`

---

*Compilado de: INFORME-BOS-2026-05-15.md + plan-bos-agent.md + SBOS-018-DAEMON-BOS.md + SBOS-019-FICHAS.md + SBOS-006-FICHA.md + SBOS-035-INSTALL-ROUTINE.md + SBOS-036-PRODUCTS.md + SBOS-037-DEPLOY-SEED.md + SBOS-002-ARCH.md + SBOS-005-STACK.md + SBOS-007-DEPLOY.md + SBOS-025-VDI.md + SBOS-049-FICHAS-BOS.md + INVENTARIO-FICHAS.md + ADR-001-bos-como-capa-so.md*
*2026-05-18 · SKULL · SBOS*
