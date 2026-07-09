# CONCEPCIÓN DEL BOS Y ESTRATEGIA DE FASES M
## Documento Normativo de Orientación — Leer al inicio de cada sesión

**Versión:** 1.0  
**Fecha:** 2026-06-13  
**Estado:** Normativo Activo — Brújula de Desarrollo  
**Clasificación:** Interno · Agente bos-developer  
**Propósito:** Evitar la mala concepción del BOS. Este documento define qué es el BOS, por qué
las Fases M están planificadas como están, y cuál es el rol de la TUI en la estrategia de certificación.

> **Regla de uso:** Si en algún momento el agente duda sobre por qué está haciendo algo,
> debe leer este documento antes de continuar. La desviación del BOS conceptualizado aquí
> es el error más costoso del proyecto.

---

## 1. Qué ES el BOS — La Concepción Correcta

### 1.1 La Analogía Fundamental

```
Linux kernel   →  gestiona hardware de cómputo (CPU, RAM, disco, red)
bos (BOS)      →  gestiona recursos empresariales (tenants, fichas, contexto, capacidad)
```

**El BOS es el `systemd` del sistema operativo empresarial SBOS.**

No es un instalador. No es una herramienta que se ejecuta y termina. Es un **daemon soberano
permanente** que corre en el host Ubuntu, fuera de Kubernetes, con acceso privilegiado a todos
los planos del sistema, las 24 horas del día, los 7 días de la semana.

### 1.2 Lo que el BOS NO es

| Podría parecer | La realidad |
|---|---|
| Un instalador con TUI | La TUI es solo la interfaz. El BOS es el motor que corre detrás |
| Una herramienta de monitoreo /proc | /proc es una de 30+ fuentes del Motor de Observación — datos secundarios |
| Un CLI que ejecuta comandos | `bosctl` es la interfaz humana. El daemon es el actor real |
| Un proceso que termina al instalar | El BOS corre SIEMPRE. Es el Policy Administrator permanente del sistema |
| Un gestor de Kubernetes | Kubernetes es el runtime. El BOS es el soberano que lo gestiona |

### 1.3 Posición Real en el Stack

```
Ubuntu Linux (host)
    │
    └── systemd
          └── bos.service  ← EL BOS VIVE AQUÍ, SIEMPRE
                │
                │  gestiona ↓ (NO está adentro de ellos)
                ├── Kubernetes cluster
                │     └── Namespaces (creados por bos)
                │           └── Pods / fichas (instaladas por bos)
                ├── PostgreSQL 18.4 (provisiona BDs de tenants)
                ├── Keycloak 26.6.2 (crea realms, configura SPIs)
                ├── Vault 2.0.1 (crea paths de secretos AppRole)
                └── Redis 8.6.2 DB1 (el Context Registry — es su propiedad)
```

El BOS NO está adentro de K8s. Es el soberano que **gestiona** K8s.

---

## 2. Las 5 Responsabilidades Permanentes del BOS

Estas responsabilidades no son tareas de instalación. Son funciones que el BOS cumple
continuamente mientras está corriendo. Un BOS que no las cumple no es un BOS — es un binario.

### R1 — Context Plane (CRÍTICA 24/7)

El BOS es el **único dueño del Context Plane**. Cada request que llega a Kong termina validando
el `ctx_id` contra la Context API del BOS en `:9443`. Si el BOS no responde, ningún usuario
del SBOS puede operar.

**Ciclo de vida de un usuario:**

```
T+0     Dispositivo Fedora arranca
         BOS crea dctx_id → pre-auth, bitmask=0x0000000000000000
         El dispositivo NO puede: chapas, cajón POS, Tryton, aplicaciones de negocio

T+N     Usuario presenta credencial (NFC, huella, contraseña, QR)
         banexus intercepta via udev
         Evento: WebSocket mTLS → bhnexus → bAuth → BOS

T+N+8ms BOS recibe BitMask calculado por bAuth (3 dominios: lógico, físico, financiero)
         Crea Context Session → genera ctx_id
         ctx_id → Redis DB1 (lookup O(1) para Kong)
         ctx_id → bkernel_db.context_sessions (audit trail perpetuo)
         Emite evento: context.promoted (dctx_id → ctx_id)

T+N+15ms Capacidades activadas:
          Chapas: OPEN_RELAY emitido por bhnexus
          Apps: JWT con BitMask inyectado
          Cajón POS: actuador activado por banexus

T+op    Cada request del usuario:
         Kong → GET https://bos:9443/api/v1/context/{ctx_id}
         Redis O(1) → retorna contexto completo
         Kong inyecta headers X-SBOS-* en el request interno

T+fin   Logout / timeout KC
         BOS invalida ctx_id → Redis TTL=0 → bitmask=0x00
         Chapa bloqueada, apps bloqueadas, cajón bloqueado
         context_sessions preservada en bkernel_db para auditoría perpetua
```

**Los 6 endpoints de la Context API — Kong los llama en CADA request de TODOS los usuarios:**

| Método | Endpoint | Propósito |
|--------|----------|-----------|
| POST | `/api/v1/context/create` | Login → genera ctx_id |
| POST | `/api/v1/context/switch` | Cambio de contexto sin reautenticación |
| DELETE | `/api/v1/context/{ctx_id}` | Logout → invalida ctx_id |
| GET | `/api/v1/context/{ctx_id}` | Lookup O(1) — llamado en CADA request |
| GET | `/api/v1/context/tenant/{tenant}` | Lista ctx_id activos del tenant |
| POST | `/api/v1/context/tenant/{tenant}/invalidate-all` | Suspensión de tenant |

> **Sin M1.4 (Context API :9443) activa, ningún servicio del SBOS puede autenticar
> a ningún usuario. Es la pieza más crítica del BOS.**

### R2 — Ciclo de Vida de Tenants (Saga con compensación)

`bosctl deploy seed.yml` ejecuta una saga de 7 pasos. Si el paso N falla, los pasos 1 a N-1
se revierten automáticamente. No hay estado inconsistente.

```
Paso 1: Crear Realm en Keycloak + instalar 5 SPIs custom
Paso 2: Crear Namespace en Kubernetes con labels de tenant
Paso 3: Provisionar 9+ BDs en PostgreSQL (keycloak_db, bkernel_db, tryton_db, ...)
Paso 4: Crear paths de secretos en Vault (AppRole por ficha)
Paso 5: Inicializar Context Registry en Redis DB1
Paso 6: Crear tablas context_sessions y audit_events en bkernel_db
Paso 7: Instalar fichas del tenant en orden topológico (DAG)
```

**SLO:** Alta de tenant en < 30 segundos P50, < 90 segundos P99 (SBOS-PERF-001).

### R3 — Ficha Engine (DAG resolver + 18 estados)

El BOS resuelve el grafo de dependencias entre fichas y garantiza el orden topológico
de instalación. `postgresql` antes de `keycloak`. `keycloak` antes de `kong`. Cada ficha
transita por hasta 18 estados (PENDIENTE → INSTALANDO → INSTALADA → DEGRADADA → REPARANDO...).
El BOS monitorea constantemente y actúa según el estado de cada ficha.

**SLO:** Instalación de ficha simple en < 60 segundos P50, < 180 segundos P99 (SBOS-PERF-001).

### R4 — Reconciliación (loop cada 15 minutos)

El BOS compara el estado **declarado** (manifest.yml de cada ficha) contra el estado **real**
del sistema (kubectl, ps, Redis, PostgreSQL). Detecta drift y repara autónomamente.
Cada discrepancia queda registrada en `audit_events` con `ctx_id` — evidencia ISO 27001 A.8.15.

### R5 — Autómata de Capacidad (loop cada 60 segundos, 4 motores)

El BOS no solo instala. Garantiza que el sistema nunca se degrada por falta de capacidad
no anticipada. Cuatro motores corren en paralelo cada 60 segundos:

```
Motor Observación  → recolecta 30+ métricas: ctx_id activos, Redis %, PG conexiones,
                      bKernel WAL lag, Kong RPS, bAuth cache miss, MinIO %, K8s nodos

Motor Proyección   → regresión lineal sobre las últimas N observaciones
                      horizontes: 7 días (urgente), 30 días (planificación), 90 días (estratégico)
                      intervalo de confianza: alta/media/baja varianza

Motor Políticas    → evalúa políticas YAML declarativas en /etc/sbos/cap-policies/
                      4 niveles de governance:
                        autonomous      → BOS actúa solo (reversible, bajo riesgo)
                        recommend       → BOS presenta opciones al admin, humano decide
                        block_and_alert → BOS bloquea admisión + alerta
                        emergency       → BOS bloquea + actúa agresivamente + alerta

Motor Acción       → ejecuta lo que el Motor de Políticas ordena:
                      HPA override (escalar Kong, Go services)
                      PgBouncer pool resize
                      Control de admisión 6 niveles (granular → grueso)
                      Alertas graduadas: INFO / ADVISORY / WARNING / ACTION_REQUIRED / CRITICAL / EMERGENCY
```

---

## 3. La Arquitectura de Comunicación del BOS

```
/run/bos/bos.sock
(permisos 0660, grupo bosagent)
(UN solo socket — DOS vías simultáneas)
    │
    ├── Vía 1: WebSocket RPC
    │     Consumidores: bosctl CLI + Core UI Flutter
    │     Propósito: administración humana, comandos interactivos
    │
    └── Vía 2: JSON-RPC 2.0
          Consumidores: biedata, bkernel, bauth, bsearch, agentes IA
          Propósito: invocación programática, sagas, automatización
```

**Puertos TCP expuestos por el BOS:**

| Puerto | Protocolo | Uso | Criticidad |
|--------|-----------|-----|-----------|
| `:9440` | HTTPS REST | API principal (fichas, tenants, reconciliación) | Alta |
| `:9441` | WebSocket | Streaming en tiempo real para Core UI y bosctl | Alta |
| `:9442` | HTTP | Métricas Prometheus | Media |
| `:9443` | HTTPS REST | **Context API EXCLUSIVA — Kong la llama en CADA request** | **CRÍTICA** |

---

## 4. El BOS Vivo — 8 Criterios de Certificación Mínima

Un BOS está "vivo" cuando cumple TODOS estos criterios SIMULTÁNEAMENTE.
Un BOS que cumple solo algunos criterios es un BOS parcial — no está certificado.

| # | Criterio | Comando de verificación | SLO |
|---|----------|------------------------|-----|
| 1 | Daemon activo | `systemctl status bos` → active (Running) | — |
| 2 | Socket presente y funcional | `ls -la /run/bos/bos.sock` → 0660, propietario bosagent | — |
| 3 | Context API responde | `curl -k https://localhost:9443/health` → HTTP 200 | — |
| 4 | Puede crear dctx_id | `bos.ctx.device.register` → retorna dctx_id | < 2 segundos |
| 5 | ctx_id lookup ultrarrápido | k6 contra Redis DB1: GET ctx_id | P50 < 1ms · P99 < 5ms |
| 6 | context.promoted funcional | Login real → dctx_id → ctx_id → audit_events ✓ | < 40ms P99 |
| 7 | Loop de reconciliación activo | `audit_events` registra runs cada 15 min | — |
| 8 | 4 motores de capacidad corriendo | `cap_db.capacity_snapshots` se escribe cada 60s | — |

---

## 5. El Rol de la TUI — No es Decoración, es el Instrumento de Certificación

### 5.1 Por Qué Existe la TUI

La TUI (Terminal User Interface) de la CLI `bosctl` no es una pantalla bonita. Es el
**instrumento de medición y certificación del BOS**. Cumple tres funciones inseparables:

**Función 1 — Dar vida visible al BOS**

El BOS es un daemon que corre en background. Sin una interfaz, su funcionamiento es invisible.
La TUI hace visible en tiempo real lo que el BOS está haciendo: cuántos ctx_id están activos,
qué tenants tiene, cómo está Redis, qué fichas instaló, qué alertas de capacidad emitió.
Un BOS sin TUI funciona, pero nadie puede verificarlo. Un BOS con TUI funcional es un BOS
que puede demostrarse ante un auditor.

**Función 2 — Medir rendimiento real contra los SLOs**

Los SLOs de SBOS-PERF-001 son concretos:

```
ctx_id lookup:    P50 < 1ms · P99 < 5ms
JSON-RPC end-to-end: P50 < 30ms · P99 < 150ms
tenant deploy:    P50 < 30s · P99 < 90s
ficha install:    P50 < 60s · P99 < 180s
```

La TUI muestra estas métricas en tiempo real, tomadas del daemon real. Si la pantalla muestra
`ctx_id: 2ms P99`, ese dato viene del BOS real interrogando Redis real. No es un mock.
No es /proc. Es la medición del sistema vivo.

**Función 3 — Evidencia para la certificación**

Las certificaciones FAPI 2.0 (OpenID Foundation) e ISO 27001:2022 (SBOS-CERT-001)
requieren evidencia técnica:
- `audit_events` con `ctx_id` en todos los eventos → A.8.15 (logging)
- Context sessions preservadas → A.8.15 (audit trail inmutable)
- Métricas de latencia medidas → SLO verificables
- Controles de admisión demostrados → A.8.8 (gestión de vulnerabilidades)

La TUI es la interfaz que hace visible y demostrable esa evidencia técnica.

### 5.2 La Relación Correcta entre BOS y TUI

```
BOS (daemon, el actor)
    │
    │  produce métricas reales, gestiona ctx_id reales,
    │  instala fichas reales, aplica políticas reales
    │
    ▼
TUI (instrumento, el observador)
    │
    │  muestra métricas del BOS real
    │  mide latencias del BOS real
    │  certifica que el BOS cumple los SLOs
    │  produce evidencia para auditores
    │
    ▼
CERTIFICACIÓN (el resultado)
    FAPI 2.0 · ISO 27001:2022 · SLOs verificados
```

**La TUI sin BOS funcional = pantalla vacía con números de /proc.**
**El BOS sin TUI = daemon invisible, incertificable.**
**Los dos juntos = BOS certificado y demostrable.**

### 5.3 Lo que la TUI debe mostrar cuando el BOS esté completamente vivo

**Dashboard principal (ScreenDashboard):**
- ctx_id activos totales y por tenant (del BOS real, vía Redis DB1)
- Redis DB1 % ocupación (del Motor de Observación real)
- JSON-RPC P99 latencia (del daemon real)
- WAL lag P99 (de Prometheus real)
- Kong RPS (de Prometheus real)
- Alertas de capacidad pendientes (de `cap_db.capacity_alerts`)
- Estado de los 4 motores del Autómata de Capacidad

**NO muestra:** CPU del host (/proc), RAM del host (/proc) como métricas primarias.
Esas son métricas secundarias. Las métricas primarias son las del ecosistema SBOS.

---

## 6. Las Fases M — La Escalera hacia el BOS Certificado

Las Fases M del REGISTRO-ESTADO no son fases arbitrarias. Cada fase M lleva al BOS
un escalón más cerca de los 8 criterios de certificación. La escalera es estricta:
cada peldaño depende del anterior.

### Escalera de Certificación

```
CERTIFICADO (FAPI 2.0 + ISO 27001 + SLOs verificados)
    │
    M6 — SLOs medidos con k6 real · Evidencia técnica ISO 27001 · FAPI test suite
    │
    M5 — 4 motores de capacidad corriendo · cap_db con datos reales · bosctl capacity watch
    │
    M4 — JSON-RPC certificado · Dashboard muestra métricas del ecosistema (no /proc)
    │
    M3 — ctx_id lookup P99 < 5ms verificado · context.promoted end-to-end < 40ms P99
    │
    M2 — Primer tenant real desplegado en < 30s · Ficha Engine operativo · Stack Alpha
    │
    M1 — BOS daemon vivo: socket creado · Context API :9443 activa · DDL aplicado
    │
    (base) bos.service arranca como bosagent, no root
```

### Mapa de Fases M vs Documentos Normativos

| Fase M | Átomos | Documento normativo de referencia |
|--------|--------|-----------------------------------|
| M1 | M1.2 → M1.5 | ADR-001, SBOS-050, SBOS_Proyecto_Master §3 |
| M2 | M2.1 → M2.5 | SBOS_Proyecto_Master §16 (Fichas), SBOS-PERF-001 §2.2 |
| M3 | M3.1 → M3.4 | SBOS-PERF-001 §2.2 (SLOs ctx_id), SBOS_Proyecto_Master §5 |
| M4 | M4.1 → M4.4 | SBOS-PERF-001 §2.2 + SBOS-PERF-002 §4 (SLOs JSON-RPC) |
| M5 | M5.1 → M5.5 | **SBOS-BOS-CAP-001** (4 motores + cap_db completo) |
| M6 | M6.1 → M6.5 | **SBOS-PERF-001** (benchmarks) + **SBOS-CERT-001** (FAPI + ISO 27001) + **SBOS-PERF-002** (bench_db) |

### El DoD Real de "BOS Vivo" (DoD del Proyecto Completo)

```bash
# Criterios M1 (daemon funcional)
systemctl is-active bos                                      # active
ls /run/bos/bos.sock                                         # existe
curl -k -s https://localhost:9443/health | jq .status        # "ok"

# Criterios M2 (tenant real)
bosctl deploy seed-skull.yml --measure-time                  # < 30s
bosctl bootstrap verify --full                               # C-01..C-08 verdes
bosctl tenant list | grep skull                              # tenant presente

# Criterios M3 (ctx_id real)
bosctl context list --tenant=skull | grep "ctx-"             # ctx_id activos
k6 run scenarios/ctx_lookup.js --env P99_THRESHOLD_MS=5      # pasa

# Criterios M4 (JSON-RPC real)
k6 run scenarios/jsonrpc_load.js --env TENANTS=5             # P99 < 150ms

# Criterios M5 (autómata activo)
psql cap_db -c "SELECT COUNT(*) FROM capacity_snapshots \
  WHERE ts > NOW() - INTERVAL '2 minutes'"                   # >= 1

# Criterios M6 (certificación)
# Ver SBOS-PERF-001 §5.2 — todos los escenarios k6 con evidencia reproducible
# Ver SBOS-CERT-001 §3.4 — FAPI test suite apuntando a staging
```

---

## 7. Orientación para el Agente — Reglas de Trabajo

### Regla 1 — El daemon primero, la pantalla después

Antes de mejorar cualquier pantalla de la TUI, verificar que el BOS cumple los criterios
de su Fase M actual. Una pantalla que muestra datos del daemon real tiene valor.
Una pantalla que muestra mocks o /proc mientras el daemon no funciona es deuda técnica.

### Regla 2 — Las métricas primarias son del ecosistema, no del host

La TUI del dashboard no es un `htop` glorificado. Las métricas que importan son:
- ctx_id activos (del BOS, de Redis)
- WAL lag P99 (de Prometheus, de bKernel)
- Redis DB1 % (del Motor de Observación)
- JSON-RPC P99 (del daemon, no del SO)

/proc/stat (CPU del host) y /proc/meminfo (RAM del host) son métricas **secundarias**.
Útiles para el panel de recursos del instalador. NO son las métricas de certificación del BOS.

### Regla 3 — Cada átomo M debe dejar al BOS más vivo

Al completar un átomo M, responder: ¿qué criterio de los 8 avanzó?
Si un átomo no avanza ningún criterio de certificación del BOS, revisar si está en el lugar
correcto en la secuencia o si es trabajo de UI que debe diferirse.

### Regla 4 — La TUI y el daemon son un dúo inseparable

Cuando se implementa un feature del daemon (ej: Context API), también se implementa
su representación en la TUI (ej: contador de ctx_id activos en el dashboard).
No se separan. Un daemon sin visibilidad en la TUI es un daemon incertificable.

### Regla 5 — Los SLOs son el criterio de verdad

Cuando la TUI muestra una métrica, la pregunta es: ¿está dentro del SLO de SBOS-PERF-001?
- ctx_id lookup: P99 < 5ms → ¿la TUI lo muestra verde o rojo?
- tenant deploy: P50 < 30s → ¿bosctl lo midió y lo mostró?
- ficha install: P50 < 60s → ¿el progreso en pantalla refleja el tiempo real?

---

## 8. Resumen Ejecutivo — Una Frase por Concepto

| Concepto | Una frase |
|----------|-----------|
| **Qué es el BOS** | El systemd del sistema operativo empresarial SBOS — daemon soberano permanente |
| **Dónde vive** | En el host Ubuntu, fuera de Kubernetes, como `bos.service` bajo `systemd` |
| **Qué gestiona** | K8s, PostgreSQL, Keycloak, Vault, Redis DB1 — no está dentro de ellos, los gobierna |
| **Su función más crítica** | Context API :9443 — Kong la llama en cada request de cada usuario |
| **Cómo se comunica** | Unix socket `/run/bos/bos.sock` — WebSocket RPC (humanos) + JSON-RPC 2.0 (daemons) |
| **Cuándo está "vivo"** | Cuando cumple los 8 criterios de certificación simultáneamente |
| **Para qué sirve la TUI** | Para hacer visible, medible y certificable el funcionamiento del BOS real |
| **Qué son las Fases M** | La escalera desde "binario que compila" hasta "BOS certificado con SLOs verificados" |
| **Cuál es la meta final** | FAPI 2.0 + ISO 27001:2022 + SLOs SBOS-PERF-001 verificados con k6 real en VPS real |

---

*SBOS · BOS-REPAIR · CONCEPCION-BOS-Y-FASES-M v1.0 · 2026-06-13 · SKULL*  
*Documento generado a partir de la lectura completa de SBOS_Proyecto_Master.md v2.1*  
*y los documentos normativos SBOS-PERF-001, SBOS-BOS-CAP-001, SBOS-CERT-001, SBOS-PERF-002*  
*Propósito: que el agente bos-developer nunca pierda el norte sobre qué es el BOS*  
*y por qué cada átomo de las Fases M tiene sentido en la escalera hacia la certificación.*
