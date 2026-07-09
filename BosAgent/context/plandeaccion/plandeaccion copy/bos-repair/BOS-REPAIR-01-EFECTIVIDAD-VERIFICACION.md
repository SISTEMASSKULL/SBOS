# SBOS — Efectividad del Código y Verificación de Reparaciones
## Cómo medir que el bos hace su trabajo correctamente
## Estándar HUMAN-DOC · SKULL · SBOS · v1.0 · Junio 2026

**Referencia en plan de acción:** PLAN_ACCION_BOSAGENT.md — Fases 6, 8, 9  
**ADRs aplicables:** ADR-002 (roles bos), ADR-003 (documentación), ADR-004 (Operator Soberano)  
**Documentos base:** SBOS-052-VDI-SPEC, SBOS-049-CONTEXT-PLANE, SBOS-MANUAL-ACOPLAMIENTO

---

## Por qué este documento existe

El bos no solo instala fichas — es el responsable permanente del ciclo de vida completo de todo lo que corre en el servidor. Eso incluye:

- **Salud y reparación** de los 22 componentes del stack (fichas)
- **Escalado coordinado** de pods según demanda real de tenants
- **Mantenimiento** del nodo Ubuntu + cluster Kubernetes
- **Contexto soberano** para cada usuario en su terminal (VDI Layer)
- **Disponibilidad del escritorio Fedora** (físico o lógico) con home en Nextcloud

Sin un método de medición claro, no hay forma de saber si el bos está cumpliendo su responsabilidad o si una reparación terminó correctamente. Este documento define exactamente qué medir, cómo medirlo, y cuál es el criterio de éxito para cada capa del sistema.

---

## Índice

1. [El modelo de efectividad](#1-el-modelo-de-efectividad)
2. [Capa 1 — Infraestructura base: Ubuntu + Kubernetes](#2-capa-1--infraestructura-base-ubuntu--kubernetes)
3. [Capa 2 — Stack SBOS: las 22 fichas](#3-capa-2--stack-sbos-las-22-fichas)
4. [Capa 3 — Context Plane: dctx_id y ctx_id](#4-capa-3--context-plane-dctx_id-y-ctx_id)
5. [Capa 4 — VDI Layer: terminal de trabajo del usuario](#5-capa-4--vdi-layer-terminal-de-trabajo-del-usuario)
6. [Capa 5 — Experiencia del usuario end-to-end](#6-capa-5--experiencia-del-usuario-end-to-end)
7. [Sagas de reparación: criterios de completitud por fase](#7-sagas-de-reparación-criterios-de-completitud-por-fase)
8. [Métricas SLI/SLO por componente](#8-métricas-slislo-por-componente)
9. [Comandos de verificación operacional](#9-comandos-de-verificación-operacional)
10. [Dashboard de efectividad](#10-dashboard-de-efectividad)
11. [Registro de verificaciones periódicas](#11-registro-de-verificaciones-periódicas)

---

## 1. El modelo de efectividad

El bos trabaja en **5 capas** interdependientes. Cada capa depende de que la capa inferior esté saludable. La efectividad total del sistema solo puede medirse de afuera hacia adentro — desde la experiencia del usuario hasta la infraestructura base.

```
┌──────────────────────────────────────────────────────────┐
│  CAPA 5 — Experiencia end-to-end del usuario             │
│  ¿El usuario puede trabajar sin fricción?                 │
├──────────────────────────────────────────────────────────┤
│  CAPA 4 — VDI Layer (SBOS-052)                           │
│  ¿El escritorio Fedora está disponible con home montado? │
├──────────────────────────────────────────────────────────┤
│  CAPA 3 — Context Plane (SBOS-049)                       │
│  ¿El dctx_id y ctx_id son correctos para este usuario?   │
├──────────────────────────────────────────────────────────┤
│  CAPA 2 — Stack SBOS: 22 fichas                          │
│  ¿Todos los servicios del stack están INSTALADA/HEALTHY? │
├──────────────────────────────────────────────────────────┤
│  CAPA 1 — Infraestructura base: Ubuntu + Kubernetes      │
│  ¿El sistema operativo y el cluster están operativos?    │
└──────────────────────────────────────────────────────────┘
       ↑ si esta capa falla, todo lo de arriba falla
```

### Principio fundamental

Una reparación está **realmente completa** cuando la Capa 5 es verificable positivamente — no cuando el comando de reparación retorna exit 0. Un pod puede estar en estado "Running" en K8s y aun así el usuario no puede trabajar porque el Context Plane no emitió el dctx_id correcto.

---

## 2. Capa 1 — Infraestructura base: Ubuntu + Kubernetes

### Qué mide el bos

El `UnifiedWatchdog` (30s) y el `Scheduler` de reconcile (300s) verifican continuamente:

```
Ubuntu:
  ✓ CPU utilización < umbral configurado (WatchdogCPUThresholdPct)
  ✓ Memoria disponible > umbral (WatchdogMemoryThresholdPct)
  ✓ Disco disponible > umbral (WatchdogDiskThresholdPct)
  ✓ containerd.service activo (systemctl is-active)
  ✓ kubelet.service activo (systemctl is-active)
  ✓ Swap desactivado (cat /proc/swaps — solo encabezado)

Kubernetes:
  ✓ Todos los nodos en estado Ready (bosctl node list)
  ✓ Sin nodos en SchedulingDisabled no planeado
  ✓ Pods críticos Running: kube-system, calico-system, linkerd
  ✓ CoreDNS resolviendo (nslookup kubernetes.default)
  ✓ etcd respondiendo (si es accesible)
```

### Criterios de completitud de reparación — Capa 1

**La reparación de Capa 1 está completa cuando:**

| Verificación | Comando bos | Criterio de éxito |
|---|---|---|
| Ubuntu OS healthy | `bosctl rpc bos.health.check` | `healthy: true` en campo `ubuntu` |
| K8s nodos Ready | `bosctl rpc bos.k8s.node.status` | Todos los nodos `status: Ready` |
| Servicios systemd | `bosctl rpc bos.health.check` | `systemd_services: {containerd: active, kubelet: active}` |
| Disco disponible | `bosctl rpc bos.health.check` | `disk_available_pct > threshold` |
| Sin pods crashlooping | `bosctl rpc bos.k8s.pods.anomalies` | `crashlooping: []` (lista vacía) |

**Señal de que la reparación NO está completa:**
```bash
bosctl rpc bos.health.check | grep -i "false\|fail\|error\|notready"
# Si retorna algo: la Capa 1 tiene problemas no resueltos
```

### Métricas Prometheus — Capa 1

```
bos_watchdog_ubuntu_healthy{node}          Gauge 0/1
bos_watchdog_k8s_nodes_ready{cluster}     Gauge (count)
bos_watchdog_k8s_nodes_total{cluster}     Gauge (count)
bos_watchdog_disk_usage_pct{node,mount}   Gauge 0-100
bos_watchdog_memory_usage_pct{node}       Gauge 0-100
bos_watchdog_cpu_usage_pct{node}          Gauge 0-100
bos_repair_ubuntu_sagas_total{outcome}    Counter
bos_repair_k8s_sagas_total{outcome}       Counter
```

**SLO Capa 1:**
```
Ubuntu disponible:    99.9% del tiempo (≤ 8.7h downtime/año)
K8s nodos Ready:      100% de los nodos declarados en bos.toml
Disco disponible:     > 20% libre en todo momento
```

---

## 3. Capa 2 — Stack SBOS: las 22 fichas

### La máquina de estados y lo que significa "reparado"

Cada ficha tiene un estado en la máquina de 18 transiciones (ADR-021). Una ficha está verdaderamente reparada solo cuando alcanza el estado `INSTALADA` — no cuando el script de reparación terminó, sino cuando el health probe confirma que el servicio responde correctamente.

```
Estados intermedios durante reparación (NO son "completado"):
  REPARANDO    ← saga en ejecución
  INSTALANDO   ← reinstalación en curso

Estado final de reparación exitosa:
  INSTALADA    ← health probe pasó, servicio respondiendo

Estado de fallo de reparación:
  DEGRADADA    ← reparación falló, volvió al estado anterior
  FALLA_INSTALACION ← reparación destruyó el estado anterior (grave)
```

### Criterios de completitud por ficha crítica

El bos ya tiene los 8 criterios de certificación C-01..C-08. Los extendemos con los criterios del VDI Layer:

#### Criterios C-01 a C-08 (bootstrap base — ya implementados)

| Criterio | Ficha | Verificación real |
|---|---|---|
| C-01 | sbos-bootstrap-os | `/etc/sysctl.d/99-sbos-k8s.conf` existe + `/data/` existe |
| C-02 | sbos-bootstrap-k8s | `bosctl rpc bos.health.check` responde + `kubeconfig` presente |
| C-03 | sbos-bootstrap-cni | Pods calico-node Running + `bosctl rpc bos.ficha.probe '{"ficha_id":"sbos-bootstrap-cni"}' ` responde |
| C-04 | postgresql | `pg_isready` acepta conexiones + WAL slot `bkernel_slot` existe |
| C-05 | redis | `redis-cli ping` retorna `PONG` en DB0, DB1, DB2 |
| C-06 | vault | `vault status` → `initialized: true, sealed: false` |
| C-07 | keycloak | `GET /health/ready` → UP + realm `{tenant}` existe |
| C-08 | kong | `GET :8001/status` → `database.reachable: true` |

#### Criterios C-09 a C-14 (VDI Layer — nuevos)

| Criterio | Ficha | Verificación real |
|---|---|---|
| C-09 | nextcloud | `GET /status.php` → `{"installed":true}` + Nextcloud DB en PG accesible |
| C-10 | guacamole | `GET /guacamole/api/languages` responde 200 + client OIDC en KC |
| C-11 | fedora-logico | Min 2 pods Running + sbos-client registrado con bhnexus (dctx_id activo) |
| C-12 | nextcloud-home | Home del usuario montado en pod Fedora (`ls ~/Documentos` → vacío o con archivos) |
| C-13 | context-plane | `bos.ctx.device.register` retorna dctx_id válido en < 2s |
| C-14 | vdi-e2e | Login web en `vdi.{tenant}.sksistemas.com` → escritorio GNOME visible en < 10s |

### Verificación automática de todas las capas

```bash
# Verificación completa C-01..C-14
bosctl bootstrap verify --full

# Salida esperada cuando TODO está bien:
# ✓ [C-01] sbos-bootstrap-os HEALTHY
# ✓ [C-02] sbos-bootstrap-k8s HEALTHY
# ...
# ✓ [C-09] nextcloud HEALTHY (installed, DB reachable)
# ✓ [C-10] guacamole HEALTHY (API 200, OIDC client registered)
# ✓ [C-11] fedora-logico HEALTHY (2/2 pods Running, dctx_id active)
# ✓ [C-12] nextcloud-home HEALTHY (home mounted in pod)
# ✓ [C-13] context-plane HEALTHY (dctx_id in 1.2s)
# ✓ [C-14] vdi-e2e HEALTHY (GNOME in 8.3s)
# 
# 14/14 criterios cumplidos
# CERTIFICACIÓN COMPLETA: APROBADA ✓
```

### La reparación de una ficha está completa cuando

```
CONDICIÓN NECESARIA (pero no suficiente):
  ficha.State == "INSTALADA" en bos.state.read

CONDICIÓN SUFICIENTE (lo que realmente importa):
  La probe de la ficha pasa:
    bosctl rpc bos.ficha.probe '{"ficha_id":"<id>"}' → {healthy: true}

  Y el criterio C-0X correspondiente pasa:
    bosctl bootstrap verify → C-0X: ✓
```

### Métricas Prometheus — Capa 2

```
# Estado de fichas
bos_ficha_state{ficha,state}              Gauge 0/1
bos_ficha_healthy{ficha}                  Gauge 0/1
bos_ficha_last_repair_duration_seconds{ficha}  Gauge
bos_ficha_repair_total{ficha,outcome}     Counter

# Ciclo de vida
bos_ficha_installs_total{ficha,outcome}   Counter
bos_ficha_upgrades_total{ficha,outcome}   Counter
bos_ficha_drift_detected_total{ficha}     Counter
```

**SLO Capa 2:**
```
Fichas críticas disponibles:  99.5% (postgresql, redis, vault, keycloak, kong)
Fichas VDI disponibles:       99.0% (nextcloud, guacamole, fedora-logico)
MTTR de reparación:           < 10 minutos para fichas críticas
MTTR de reparación VDI:       < 5 minutos (impacta directamente al usuario)
```

---

## 4. Capa 3 — Context Plane: dctx_id y ctx_id

### Por qué es una capa independiente

El Context Plane (SBOS-049) es el "pasaporte" del usuario en el sistema. Sin el ctx_id correcto, el usuario puede estar en Fedora con K8s funcionando perfectamente pero no poder hacer nada porque:
- Las apps no saben para qué tenant/empresa/sucursal operar
- El BitMask es 0x0 (sin privilegios)
- Los logs no tienen contexto empresarial (falla auditoría ISO 27001)

### Los dos flujos de contexto según SBOS-052

**Flujo 1 — Fedora Físico (hardware real):**
```
Terminal arranca
      ↓ sbos-client.service inicia
      ↓ sbos-client contacta bhnexus via mTLS
      ↓ bhnexus notifica al bos: nuevo dispositivo
      ↓ bos crea dctx_id (hardware_type: "physical")
      ↓ dctx_id tiene: hostname, IP, MAC, tenant, K8s node
      ↓ Usuario presenta credencial (NFC/QR/password) en GNOME login
      ↓ PAM Keycloak autentica → JWT con bos_contexts
      ↓ bos promueve dctx_id → ctx_id
      ↓ ctx_id tiene: tenant + empresa + sucursal + POS + BitMask
      ↓ sbos-client aplica BitMask: políticas dconf, acceso a apps
```

**Flujo 2 — Fedora Lógico (pod K8s via Guacamole):**
```
Usuario abre navegador → vdi.{tenant}.sksistemas.com
      ↓ Kong redirige a Keycloak OIDC
      ↓ Keycloak autentica → JWT
      ↓ Guacamole mapea usuario → pod Fedora disponible
      ↓ Pod Fedora: sbos-client contacta bhnexus
      ↓ bos crea dctx_id (hardware_type: "logical_pod")
      ↓ bos promueve a ctx_id con datos del JWT
      ↓ Usuario ve escritorio GNOME en el navegador
      ↓ Home Nextcloud montado automáticamente
```

### Criterios de completitud — Capa 3

**El Context Plane está funcionando correctamente cuando:**

| Verificación | Cómo medirla | Criterio de éxito |
|---|---|---|
| dctx_id creado en tiempo | `bosctl rpc bos.ctx.device.register '{"tenant_id":"t","hostname":"h"}'` | Responde en < 2s con dctx_id válido |
| ctx_id promovido tras auth | Inspeccionar log de sesión post-login | `context.promoted` event en audit_log |
| BitMask > 0 tras promote | `bosctl rpc bos.ctx.get '{"ctx_id":"ctx-..."}'` | `bitmask > "0x0"` |
| Contexto enriquecido | Verificar campos en ctx_id | tenant, empresa, sucursal, pos_logico todos presentes |
| TTL correcto | `bosctl rpc bos.ctx.get` | `expires_at` entre ctxTTLMin y ctxTTLMax |
| Invalidación funciona | `bosctl rpc bos.ctx.invalidate '{"ctx_id":"ctx-..."}'` | Contexto no válido en siguiente bos.ctx.get |
| dctx_id en pod Fedora | `bosctl vdi health --tenant=skull` | Todos los pods tienen dctx_id activo |

### Señal de que el Context Plane está ROTO

```bash
# Si esto retorna bitmask "0x0" para un usuario autenticado:
bosctl rpc bos.ctx.get '{"ctx_id":"ctx-..."}' | grep bitmask
# → "bitmask": "0x0"
# PROBLEMA: el usuario está autenticado pero sin privilegios
# CAUSA POSIBLE: bAuth no respondió durante el promote
# REPARACIÓN: bosctl rpc bos.ctx.promote --force '{"dctx_id":"dctx-...",...}'

# Si esto retorna status SUSPENDIDO inesperadamente:
bosctl rpc bos.ctx.get '{"ctx_id":"ctx-..."}' | grep status
# → "status": "SUSPENDIDO"
# PROBLEMA: idle timeout alcanzado o admin suspendió el tenant
# REPARACIÓN: bosctl context reactivate '{"ctx_id":"ctx-..."}'
```

### Métricas Prometheus — Capa 3

```
bos_ctx_active_total{tenant,hardware_type}       Gauge
bos_ctx_promote_duration_seconds{tenant}         Histogram (p50, p95, p99)
bos_ctx_promote_total{tenant,outcome}            Counter
bos_ctx_state{ctx_id,state}                      Gauge 0/1
bos_ctx_bitmask_zero_total{tenant}               Counter ← sesiones sin privilegios
bos_ctx_ttl_violations_total{tenant}             Counter ← ISO 27001 A.9.4.2
bos_ctx_invalidations_total{tenant,reason}       Counter
```

**SLO Capa 3:**
```
Latencia de creación de dctx_id:  p99 < 2s
Latencia de promote a ctx_id:     p99 < 3s (incluye validación KC)
Disponibilidad del Context Plane:  99.9%
ctx_id con bitmask=0x0 post-auth:  0% (cualquier caso es un bug)
```

---

## 5. Capa 4 — VDI Layer: terminal de trabajo del usuario

### Los 6 componentes del VDI Layer y su interdependencia

```
sbos-fedora.iso / sbos-client (Fedora Físico)
      ↓ o ↓
Pod Fedora Lógico (escritorio GNOME en K8s)
      ↓ accede via
Apache Guacamole (gateway VDI HTML5)
      ↓ autentica via
Keycloak (SSO OIDC)
      ↓ monta home via
Nextcloud (almacenamiento soberano)
      ↓ gobernado por
Context Plane → bos → Keycloak
```

Un fallo en cualquier componente hace que el usuario no pueda trabajar, aunque K8s y las fichas del stack estén perfectamente saludables.

### Verificación end-to-end del VDI Layer

El bos ejecuta esta verificación via `bosctl vdi verify --tenant={tenant}`:

```
PASO 1 — Verificar componentes K8s del VDI
  bosctl get pods --tenant={tenant} --ficha=nextcloud → Running
  bosctl get pods --tenant={tenant} --ficha=guacamole → Running
  bosctl get pods --tenant={tenant} --ficha=fedora-logico → Running (≥2)
  bosctl scale policy --ficha=fedora-logico --tenant={tenant} | grep min=2
  CRITERIO: todos Running → ✓

PASO 2 — Verificar Nextcloud
  GET https://files.{tenant}.sksistemas.com/status.php
  CRITERIO: {"installed":true,"maintenance":false} → ✓

PASO 3 — Verificar Guacamole
  GET https://vdi.{tenant}.sksistemas.com/guacamole/api/languages
  CRITERIO: HTTP 200 con lista de idiomas → ✓

PASO 4 — Verificar Context Plane en pod Fedora
  bosctl exec fedora-logico --tenant={tenant} --
    curl -s http://bos-api/rpc -d '{"method":"bos.ctx.device.register",...}'
  CRITERIO: retorna dctx_id en < 2s → ✓

PASO 5 — Verificar home Nextcloud montado
  bosctl exec fedora-logico --tenant={tenant} --
    ls /home/sbos-user/Documentos
  CRITERIO: comando exitoso (directorio accesible) → ✓

PASO 6 — Verificar acceso web end-to-end
  Simular GET https://vdi.{tenant}.sksistemas.com
  Verificar redirección a Keycloak → HTTP 302 con location=keycloak
  CRITERIO: HTTP 302 con Location header → ✓

RESULTADO:
  6/6 pasos OK → VDI Layer operativo ✓
  < 6 pasos OK → VDI Layer degradado — ver paso fallido para diagnóstico
```

### Criterios de completitud de reparación — Capa 4

**La reparación del VDI Layer está completa cuando:**

```bash
bosctl vdi verify --tenant={tenant}
# Salida esperada:
# ✓ PASO 1 — Componentes K8s Running (nextcloud, guacamole, fedora-logico ×3)
# ✓ PASO 2 — Nextcloud accesible (installed: true)
# ✓ PASO 3 — Guacamole API respondiendo (200 OK)
# ✓ PASO 4 — Context Plane en pod (dctx_id en 1.4s)
# ✓ PASO 5 — Home Nextcloud montado (directorio accesible)
# ✓ PASO 6 — Acceso web end-to-end (redirección KC correcta)
#
# 6/6 verificaciones OK
# VDI Layer operativo para tenant {tenant} ✓
```

**No está completa si cualquiera de estos estados persiste:**
```
✗ PASO 1: pod fedora-logico en CrashLoopBackOff
  → verificar logs del pod: bosctl logs fedora-logico --tenant={tenant}
  → causa probable: sbos-client no puede contactar bhnexus

✗ PASO 2: Nextcloud retorna maintenance:true
  → Nextcloud en modo mantenimiento post-reparación
  → bosctl rpc bos.saga.execute '{"ficha_id":"nextcloud","command":"repair"}'

✗ PASO 4: dctx_id tarda > 5s o no retorna
  → Context Plane degradado → ver Capa 3

✗ PASO 5: /home/sbos-user/Documentos no accesible
  → PVC nextcloud-data no montado en el pod
  → verificar PVC: bosctl describe nextcloud --tenant={tenant} | grep -i pvc
```

### Métricas Prometheus — Capa 4

```
bos_vdi_pods_running{tenant}                Gauge (count de pods Running)
bos_vdi_sessions_active{tenant}             Gauge
bos_vdi_session_login_duration_seconds      Histogram (p50,p95,p99)
bos_vdi_home_mount_success{tenant,pod}      Gauge 0/1
bos_vdi_nextcloud_available{tenant}         Gauge 0/1
bos_vdi_guacamole_available{tenant}         Gauge 0/1
bos_vdi_e2e_verify_duration_seconds{tenant} Gauge
bos_vdi_pool_scale_events{tenant,direction} Counter
```

**SLO Capa 4:**
```
Disponibilidad del VDI:          99.0%
Tiempo de login Fedora Lógico:   p95 < 10s (GNOME visible desde clic)
Home Nextcloud montado:          100% de sesiones activas
Pods Fedora disponibles:         min 2 en todo momento
Escalado automático:             pod nuevo disponible en < 3 min cuando pool agotado
```

---

## 6. Capa 5 — Experiencia del usuario end-to-end

### La prueba definitiva

Una reparación está **verdaderamente completa** cuando un usuario real puede completar este flujo sin fricción:

```
FLUJO DE VERIFICACIÓN END-TO-END (ejecutar post-reparación)

1. Usuario abre navegador en cualquier dispositivo
   → navega a vdi.skull.sksistemas.com
   → ve página de login Keycloak (NO una página de error)
   ✓ CRITERIO: Keycloak login visible en < 3s

2. Usuario se autentica (credenciales de prueba: test@skull.com / testpass)
   → Keycloak autentica
   → Guacamole asigna pod Fedora
   → GNOME se renderiza en el navegador
   ✓ CRITERIO: Escritorio Fedora visible en < 10s post-auth

3. bos verifica contexto del usuario
   → dctx_id promovido a ctx_id
   → ctx_id.bitmask > 0x0
   → tenant, empresa, sucursal presentes en ctx_id
   ✓ CRITERIO: bosctl rpc bos.ctx.get retorna ctx completo en < 2s

4. Usuario abre LibreOffice Writer desde el escritorio
   → Crea un documento de prueba: "verificacion-reparacion-{timestamp}.odt"
   → Guarda el documento (Ctrl+S)
   ✓ CRITERIO: archivo aparece en Nextcloud web en < 5s

5. Usuario cierra sesión (logout desde GNOME)
   → Sesión Guacamole termina
   → Pod vuelve al pool
   → ctx_id transicionado a INVALIDADO
   ✓ CRITERIO: bosctl rpc bos.ctx.get retorna status: INVALIDADO

6. Usuario vuelve a entrar desde el mismo navegador
   → Ve el documento guardado en Nextcloud
   ✓ CRITERIO: "verificacion-reparacion-{timestamp}.odt" presente

RESULTADO FINAL:
  6/6 pasos OK → Sistema completamente funcional para el usuario ✓
  Cualquier fallo → identificar en qué capa está el problema
```

### Comando de verificación automatizada end-to-end

```bash
bosctl vdi test-user --tenant=skull \
  --user=test@skull.com \
  --password=testpass \
  --save-artifact=true
```

Salida esperada:
```
SBOS VDI End-to-End Test — tenant: skull
──────────────────────────────────────────
✓ [1/6] Keycloak login page visible (1.2s)
✓ [2/6] GNOME escritorio visible (7.8s)
✓ [3/6] ctx_id promovido (bitmask: 0x00FF)
✓ [4/6] Archivo guardado en Nextcloud (3.1s)
✓ [5/6] Sesión cerrada, ctx INVALIDADO
✓ [6/6] Archivo persiste en nueva sesión

Duración total: 28.4s
RESULTADO: ✓ Sistema completamente operativo
```

---

## 7. Sagas de reparación: criterios de completitud por fase

El bos ejecuta reparaciones en **sagas** con múltiples pasos. Cada paso tiene su criterio de éxito. La saga no está completa hasta que TODOS los pasos pasan.

### Saga de reparación estándar (cualquier ficha)

```
FASE 1 — Pre-repair checks
  Verificar que la ficha está en estado DEGRADADA o INSTALANDO_FALLIDO
  Verificar que no hay otra saga del mismo tipo en curso (mutex)
  Registrar en audit log: REPAIR_START, ficha=X, trigger=Y
  ✓ CRITERIO: mutex adquirido, estado válido para reparar

FASE 2 — Ejecución del script de reparación
  Ejecutar: 00_MASTER_INSTALL_SBOS.sh repair <ficha_id>
  El script recibe: manifest.yml + task_catalog.sh + yaml_engine.yml
  Cada paso del script emite eventos WebSocket: step_start, step_ok, step_fail
  ✓ CRITERIO: script termina con exit code 0

FASE 3 — Health probe post-reparación
  Ejecutar: bosctl rpc bos.ficha.probe '{"ficha_id":"<id>"}'
  La probe verifica el endpoint específico de la ficha (definido en manifest.yml)
  ✓ CRITERIO: probe retorna {healthy: true}

FASE 4 — Verificación del criterio de certificación correspondiente
  Ejecutar el check específico del criterio C-0X de la ficha
  ✓ CRITERIO: C-0X retorna OK

FASE 5 — Actualización de estado
  stateMgr.Transition(fichaID, StateInstalada)
  Registrar en audit log: REPAIR_OK, ficha=X, duration=Y
  ✓ CRITERIO: ficha.State == INSTALADA en bos.state.read

FASE 6 — Registro de hashes (drift baseline)
  stateMgr.RegisterHashes(fichaID, currentHashes)
  ✓ CRITERIO: nuevos hashes SHA-256 almacenados sin error

RESULTADO FINAL:
  Todas las fases OK → saga completada, ficha INSTALADA ✓
  Cualquier fase falla → compensación: estado → DEGRADADA, alerta emitida
```

### Saga de reparación VDI (Nextcloud / Guacamole / Fedora Lógico)

Tiene fases adicionales específicas para el VDI Layer:

```
FASES 1-6: igual que la saga estándar
+
FASE 7 — Verificar Context Plane en el pod reparado
  bosctl exec <pod> -- bosctl rpc bos.ctx.device.register ...
  ✓ CRITERIO: dctx_id retornado en < 2s

FASE 8 — Verificar home Nextcloud en el pod
  bosctl exec <pod> -- ls ~/Documentos
  ✓ CRITERIO: directorio accesible sin error

FASE 9 — Verificar Guacamole puede conectar al pod
  bosctl rpc bos.vdi.probe '{"pod":"<pod>","tenant":"<tenant>"}'
  ✓ CRITERIO: VNC interno respondiendo

FASE 10 — Verificar ruta Kong para el tenant
  curl -sI https://vdi.{tenant}.sksistemas.com
  ✓ CRITERIO: HTTP 302 redirect a Keycloak (no 502/503)
```

### Saga de mantenimiento de nodo (ADR-004)

```
FASE 1 — Pre-checks (ITIL 4: Change Enablement)
  Verificar capacidad del cluster para absorber el drain
  Ejecutar pre_maintenance_checks de cada ficha afectada
  ✓ CRITERIO: cluster tiene capacidad, todos los pre-checks pasan

FASE 2 — Cordon del nodo
  bosctl node cordon <node>
  ✓ CRITERIO: node.spec.unschedulable = true en bosctl node status

FASE 3 — Drain del nodo
  bosctl node drain <node> --ignore-daemonsets --delete-emptydir-data
  ✓ CRITERIO: 0 pods non-DaemonSet en el nodo; todos redistribuidos

FASE 4 — Operación de mantenimiento
  Según tipo: apt upgrade, K8s patch, hardware swap
  ✓ CRITERIO: operación específica completa sin errores

FASE 5 — Post-checks del nodo
  bosctl node status <node> --wait=Ready --timeout=300s
  ✓ CRITERIO: nodo Ready en < 300s post-mantenimiento

FASE 6 — Uncordon
  bosctl node uncordon <node>
  ✓ CRITERIO: node.spec.unschedulable = false

FASE 7 — Verificación post-mantenimiento
  bosctl bootstrap verify --full
  ✓ CRITERIO: C-01 a C-14 todos OK

COMPENSACIÓN SI CUALQUIER FASE FALLA DESPUÉS DE FASE 2:
  SIEMPRE ejecutar bosctl node uncordon <node>
  Un nodo cordoned sin uncordon reduce capacidad del cluster permanentemente
  Registrar MAINTENANCE_FAILED en audit log con la fase que falló
```

---

## 8. Métricas SLI/SLO por componente

### Tabla completa de SLIs y SLOs

Los SLIs (Service Level Indicators) son las métricas que se miden. Los SLOs (Service Level Objectives) son los umbrales que el bos debe mantener.

| Componente | SLI | SLO | Métrica Prometheus |
|---|---|---|---|
| **Ubuntu** | % tiempo en healthy | 99.9% | `bos_watchdog_ubuntu_healthy` |
| **Kubernetes** | % nodos Ready | 100% | `bos_watchdog_k8s_nodes_ready / _total` |
| **postgresql** | Disponibilidad pg_isready | 99.95% | `bos_ficha_healthy{ficha="postgresql"}` |
| **redis** | Disponibilidad PONG | 99.95% | `bos_ficha_healthy{ficha="redis"}` |
| **vault** | unsealed + accessible | 99.9% | `bos_ficha_healthy{ficha="vault"}` |
| **keycloak** | /health/ready UP | 99.5% | `bos_ficha_healthy{ficha="keycloak"}` |
| **kong** | Admin API reachable | 99.9% | `bos_ficha_healthy{ficha="kong"}` |
| **nextcloud** | installed:true | 99.0% | `bos_vdi_nextcloud_available` |
| **guacamole** | API 200 OK | 99.0% | `bos_vdi_guacamole_available` |
| **fedora-logico** | ≥2 pods Running | 99.0% | `bos_vdi_pods_running >= 2` |
| **Context Plane** | dctx_id latencia | p99 < 2s | `bos_ctx_promote_duration_seconds` |
| **VDI e2e** | Login → GNOME visible | p95 < 10s | `bos_vdi_session_login_duration_seconds` |
| **Home montado** | % sesiones con home | 100% | `bos_vdi_home_mount_success` |
| **MTTR fichas críticas** | Tiempo de reparación | < 10 min | `bos_repair_duration_seconds` |
| **MTTR VDI** | Tiempo de reparación | < 5 min | `bos_repair_duration_seconds{ficha=~"next.*|guac.*|fedora.*"}` |
| **Reparaciones paralelas** | Repairs simultáneos | 0 | `bos_repair_parallel_prevented_total` incrementa si > 0 ocurrencias |

### Error budgets (Google SRE)

Para SLOs de 30 días:

| Componente | SLO | Budget mensual (downtime permitido) |
|---|---|---|
| postgresql | 99.95% | 21.6 minutos/mes |
| keycloak | 99.5% | 3.6 horas/mes |
| VDI disponible | 99.0% | 7.2 horas/mes |
| Context Plane | 99.9% | 43.8 minutos/mes |

Cuando el bos detecta que se está acercando al error budget (via Prometheus + alertas), debe ser más conservador con operaciones de mantenimiento que puedan causar downtime.

---

## 9. Comandos de verificación operacional

### Verificación rápida (< 30 segundos) — post cualquier operación

```bash
# Estado de todas las fichas
bosctl rpc bos.state.read | jq '.fichas | to_entries[] | 
  select(.value.state != "INSTALADA") | {ficha: .key, state: .value.state}'

# Si retorna vacío: todas las fichas INSTALADA ✓
# Si retorna algo: fichas con problema detectado

# Health general
bosctl rpc bos.health.check | jq '{healthy, fichas_ok, fichas_alerta}'
```

### Verificación estándar (< 2 minutos) — post reparación de ficha

```bash
# 1. Probe de la ficha reparada
bosctl rpc bos.ficha.probe '{"ficha_id":"<id>"}'

# 2. Criterio de certificación correspondiente
bosctl bootstrap verify  # muestra solo los C-0X fallidos

# 3. Context Plane si la ficha afecta al VDI
bosctl rpc bos.ctx.device.register '{"tenant_id":"skull","hostname":"test-verify"}'
```

### Verificación completa (< 10 minutos) — post mantenimiento de nodo o reparación mayor

```bash
# Certificación completa C-01..C-14
bosctl bootstrap verify --full

# VDI Layer end-to-end
bosctl vdi verify --tenant=skull

# Métricas de SLO actuales
bosctl rpc bos.state.read | jq '.fichas | [to_entries[] | 
  {ficha: .key, state: .value.state, health: .value.health_status}]'
```

### Verificación de usuario real (< 30 minutos) — certificación operacional

```bash
# Test end-to-end con usuario real (requiere credenciales de prueba)
bosctl vdi test-user --tenant=skull \
  --user=test@skull.com \
  --password=testpass \
  --save-artifact=true \
  --output=json | jq '.steps[] | {paso: .id, ok: .passed, duracion: .duration}'
```

### Monitoreo continuo — post cualquier cambio en producción

```bash
# Ver el audit log de reparaciones recientes
bosctl rpc bos.state.read | jq '.updated_at'
tail -f /var/log/bos/audit.log | grep "REPAIR\|SCALE\|MAINTENANCE"

# Ver métricas de Prometheus en Grafana
# URL: https://skull.sksistemas.com/monitor/d/bos-effectiveness
```

---

## 10. Dashboard de efectividad

El bos debe exponer un dashboard Grafana específico de efectividad. Su URL canónica es:

```
https://{tenant}.sksistemas.com/monitor/d/bos-effectiveness
```

### Paneles obligatorios del dashboard

```
ROW 1 — Estado general (actualización cada 30s)
  Panel 1: Semáforo general — Verde/Amarillo/Rojo
           Rojo si: alguna ficha crítica DEGRADADA o ningún pod Fedora disponible
           Amarillo si: alguna ficha no crítica DEGRADADA o pool VDI < min
           Verde si: todas las fichas INSTALADA y VDI operativo

  Panel 2: Fichas INSTALADA / total (gauge)
           22/22 es el estado óptimo

  Panel 3: Pods Fedora Lógico activos (gauge con min=2 line)
           Por tenant, comparado con el mínimo configurado

  Panel 4: ctx_id activos por tenant (gauge)
           Indicador de carga real de usuarios

ROW 2 — SLOs en tiempo real
  Panel 5: Disponibilidad postgresql (últimas 24h, 7d, 30d)
  Panel 6: Disponibilidad VDI (últimas 24h, 7d, 30d)
  Panel 7: Latencia Context Plane p50/p95/p99 (últimas 24h)
  Panel 8: MTTR reparaciones (promedio últimas 10 reparaciones)

ROW 3 — Reparaciones y mantenimiento
  Panel 9: Timeline de reparaciones (últimas 24h)
           Cada barra = una saga, color = resultado
  Panel 10: Drift detections (últimas 24h)
            Cuántas veces SHA-256 divergió del baseline
  Panel 11: Operaciones de escalado (réplicas, timeline)
  Panel 12: Operaciones de mantenimiento de nodo

ROW 4 — VDI Layer detail
  Panel 13: Sessions login duration heatmap (últimas 24h)
  Panel 14: Home Nextcloud mount success rate
  Panel 15: Pool utilization (sesiones activas / max)
  Panel 16: ISO status (última versión disponible, fecha)
```

### Alert rules obligatorias

```yaml
# alert.rules.yml para Prometheus Alertmanager

groups:
  - name: bos-effectividad
    rules:
      # Alerta crítica: ficha crítica degradada
      - alert: FichaCriticaDegradada
        expr: bos_ficha_healthy{ficha=~"postgresql|redis|vault|keycloak|kong"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Ficha crítica {{ $labels.ficha }} degradada por > 2 minutos"
          runbook: "bosctl rpc bos.ficha.repair '{\"ficha_id\":\"{{ $labels.ficha }}\"}'"

      # Alerta warning: VDI sin pods disponibles
      - alert: VDISinPodsDisponibles
        expr: bos_vdi_pods_running < 2
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Pool VDI del tenant {{ $labels.tenant }} por debajo del mínimo"
          runbook: "bosctl vdi pool scale --tenant={{ $labels.tenant }} --min=2"

      # Alerta warning: Context Plane lento
      - alert: ContextPlaneLento
        expr: histogram_quantile(0.99, bos_ctx_promote_duration_seconds_bucket) > 3
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Context Plane: promote p99 > 3s en tenant {{ $labels.tenant }}"

      # Alerta crítica: SLO postgresql en riesgo
      - alert: SLOPostgresqlEnRiesgo
        expr: (1 - avg_over_time(bos_ficha_healthy{ficha="postgresql"}[30d])) > 0.0005
        labels:
          severity: critical
        annotations:
          summary: "PostgreSQL en riesgo de violar SLO 99.95% del mes"

      # Alerta info: reparación paralela prevenida
      - alert: ReparacionParalelaPrevenida
        expr: increase(bos_repair_parallel_prevented_total[5m]) > 0
        labels:
          severity: info
        annotations:
          summary: "Reparación paralela prevenida (P6/P14 fix funcionando)"
```

---

## 11. Registro de verificaciones periódicas

### Cadencia recomendada

| Verificación | Frecuencia | Responsable | Comando |
|---|---|---|---|
| Health rápido | Automático cada 30s | bos watchdog | interno |
| Drift detection | Automático cada 300s | bos reconcile | interno |
| Verificación estándar | Post cada reparación | bos + audit log | `bosctl bootstrap verify` |
| VDI verify | Diaria (07:00 AM) | bos scheduled | `bosctl vdi verify --all-tenants` |
| Verificación completa C-01..C-14 | Semanal | Operador | `bosctl bootstrap verify --full` |
| Test end-to-end usuario | Semanal | Operador | `bosctl vdi test-user` |
| Revisión de SLOs | Mensual | Admin | Dashboard Grafana |
| Revisión de ClusterRole bosagent | Semestral | Admin | `bosctl rpc bos.security.rbac.get '{"role":"bosagent"}' ` |

### Plantilla de registro de reparación (para audit trail ISO 27001)

```
═══════════════════════════════════════════════════════════════
REGISTRO DE REPARACIÓN SBOS
═══════════════════════════════════════════════════════════════
Fecha/Hora:       2026-06-07 14:32:00 UTC
Operador:         admin@skull.sksistemas.com
Ficha afectada:   postgresql
Trigger:          watchdog (salud DEGRADADA detectada a las 14:28:00)
Causa raíz:       Pod postgresql-0 terminado por OOMKilled (memoria insuficiente)

FASES COMPLETADAS:
  ✓ FASE 1 — Pre-repair checks (0:00 - 0:02)
  ✓ FASE 2 — Script reparación (0:02 - 0:08) exit code 0
  ✓ FASE 3 — Health probe (0:08 - 0:09) healthy: true
  ✓ FASE 4 — Criterio C-04 (0:09 - 0:10) pg_isready OK + WAL slot OK
  ✓ FASE 5 — Estado INSTALADA (0:10)
  ✓ FASE 6 — Hashes actualizados (0:10)

VERIFICACIÓN POST-REPARACIÓN:
  bosctl bootstrap verify → C-04: ✓ (14:42:00)
  bosctl vdi verify → PASO 1 ✓, PASO 5 ✓ (home Nextcloud OK)
  bosctl rpc bos.ctx.device.register → dctx_id en 1.3s ✓

DURACIÓN TOTAL: 10 minutos 02 segundos
RESULTADO: REPARACIÓN COMPLETADA EXITOSAMENTE ✓

ACCIÓN PREVENTIVA:
  Memory limit de postgresql aumentado de 2Gi → 4Gi en manifest.yml
  bosctl rpc bos.ficha.policy.set '{"ficha_id":"postgresql","memory_limit":"4Gi"}'
═══════════════════════════════════════════════════════════════
```

---

## Referencias normativas

| Estándar | Aplicación en este documento |
|---|---|
| Google SRE Book — SLIs y SLOs | Modelo de SLI/SLO/error budget por componente |
| ITIL 4 — Incident Management | Las 4 fases de reparación: identificación, diagnóstico, resolución, revisión |
| ISO/IEC 27001:2022 A.8.15 | Registro de cada reparación en audit log con contexto completo |
| NIST SP 800-207 | Verificación de Context Plane como Policy Administrator |
| SBOS-052-VDI-SPEC | Criterios C-09..C-14 del VDI Layer |
| SBOS-049-CONTEXT-PLANE | Flujos dctx_id → ctx_id para Fedora Físico y Lógico |
| ADR-002 | Roles del bos que ejecutan cada capa de verificación |
| ADR-004 | Sagas de mantenimiento de nodo con compensación |

---

_SKULL · SBOS · SBOS-EFECTIVIDAD-REPARACION · HUMAN-DOC v1.0 · Junio 2026_  
_Referencia: PLAN_ACCION_BOSAGENT.md — Fases 6, 8, 9_  
_Referencia: ADR-002, ADR-003, ADR-004_
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
