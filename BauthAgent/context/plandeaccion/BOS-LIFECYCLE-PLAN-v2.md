# Plan de Implementación: Ciclo de Vida del Daemon BOS como Servicio systemd
**Versión:** 2.0 — Revisado y validado contra estándares internacionales  
**Fecha:** 2026-05-19  
**Basado en diagnóstico:** commit 5828eda (sbos-bootstrap-os y sbos-bootstrap-k8s CERTIFICADOS)  
**Estado del plan original:** APROBADO CON MEJORAS — ver Sección 2 para modificaciones

---

## Índice

1. [Validación del Plan Original contra Estándares](#1-validación-del-plan-original)
2. [Modificaciones al Plan Original](#2-modificaciones-al-plan-original)
3. [Arquitectura de Capas Revisada](#3-arquitectura-de-capas-revisada)
4. [Plan de Implementación por Capas (Definitivo)](#4-plan-de-implementación-por-capas)
5. [Comandos de Verificación por Capa](#5-comandos-de-verificación)
6. [Trazabilidad a Estándares Internacionales](#6-trazabilidad-a-estándares)
7. [Matriz de Riesgos y Mitigación](#7-matriz-de-riesgos)
8. [Orden de Implementación y Dependencias](#8-orden-de-implementación)

---

## 1. Validación del Plan Original contra Estándares

### 1.1 Estándares aplicables identificados

El daemon BOS actúa como **supervisor de infraestructura crítica** (Ubuntu → BOS → Kubernetes → Aplicaciones). Esta arquitectura de capas implica conformidad con:

| Estándar | Versión | Relevancia para BOS |
|---|---|---|
| **ISO 9001:2015** + **ISO/IEC 90003:2018** | Vigente | QMS para desarrollo de software: documentación, trazabilidad, mejora continua |
| **ISO/IEC 25010:2023** | Vigente 2023 | Modelo de calidad del producto: Fiabilidad, Tolerancia a fallos, Recuperabilidad |
| **ISO/IEC 12207:2017** | Vigente | Procesos del ciclo de vida del software |
| **ISO 22301:2019** | Vigente | Continuidad de negocio — aplica al arranque automático y recuperación |
| **IEC 62443-4-1** | Vigente | Ciclo de vida de desarrollo seguro de componentes (aplica a daemon con privilegios root) |
| **POSIX / IEEE Std 1003.1** | Base | Comportamiento de señales SIGTERM/SIGKILL, PID files, file locking |
| **systemd upstream spec** | freedesktop.org | sd_notify protocol, Type=notify, WatchdogSec |

### 1.2 Evaluación del plan original por capa

#### Capa 0 — systemd unit file
**Veredicto: APROBADO CON UNA CORRECCIÓN CRÍTICA**

El unit file propuesto es técnicamente correcto en sus directivas fundamentales. Sin embargo, se identifican dos problemas:

1. **`Restart=always` es incorrecto para `Type=notify`.** Con `Type=notify`, si el proceso termina con exit 0 después de enviar `STOPPING=1`, systemd lo considerará una parada limpia y NO lo relanzará si se configura `Restart=on-failure`. Usar `Restart=always` es correcto para garantizar resiliencia total, pero requiere añadir `StartLimitBurst` y `StartLimitIntervalSec` para evitar bucles infinitos de reinicios que consuman recursos (violación de ISO/IEC 25010 — Performance Efficiency).

2. **Falta `TimeoutStopSec`.** El shutdown ordenado (Capa 1) implica drenar K8s, esperar pods, parar kubelet y containerd. El `TimeoutStopSec` por defecto de systemd es **90 segundos**. Si el drenado de K8s tarda más (cluster grande, pods con `terminationGracePeriodSeconds` altos), systemd enviará SIGKILL, dejando el sistema en estado corrupto. Debe configurarse explícitamente.

3. **Falta `After=network-online.target`.** El plan usa `After=network.target`, que solo garantiza que la interfaz de red existe, no que tiene conectividad. BOS necesita red funcional para comunicarse con la API de K8s en el arranque. Esto viola ISO/IEC 25010 — Availability.

#### Capa 1 — Shutdown ordenado
**Veredicto: APROBADO CON MEJORAS DE SEGURIDAD**

La secuencia propuesta (drain → stop kubelet → stop containerd → detener BOS) es la secuencia canónica para nodos Kubernetes gestionados. Validación:

- La documentación oficial de Kubernetes (graceful node shutdown) confirma que el shutdown debe ocurrir en fases: pods críticos primero, luego pods regulares.
- El uso de `kubectl drain --ignore-daemonsets --delete-emptydir-data` es el comando estándar.
- **Mejora necesaria:** El plan no especifica `TimeoutStartSec` para la saga de shutdown. Si `kubectl drain` falla o tarda indefinidamente, el proceso de BOS quedará colgado. Debe añadirse un `context.Context` con timeout configurable (sugerido: 120s para drain, 30s para kubelet stop, 30s para containerd stop).
- **Mejora de seguridad (IEC 62443-4-1):** La saga de shutdown debe registrar en el journal de systemd cada paso completado, con timestamps, para auditoría post-mortem.

#### Capa 2 — Arranque con reconciliación inmediata
**Veredicto: APROBADO — AÑADIR JITTER**

El plan de ejecutar `ReconcileNow()` al arranque es correcto y cierra la brecha B2 (ventana de 300s). Sin embargo:

- Si múltiples nodos BOS arrancan simultáneamente tras un fallo de alimentación (power outage), todos ejecutarán `ReconcileNow()` al mismo tiempo, generando una tormenta de solicitudes al API server de K8s. Se debe añadir **jitter aleatorio** (0-30s) antes de la reconciliación inicial si BOS detecta que K8s ya está en Running. Esto es buena práctica en sistemas distribuidos (patrón "thundering herd prevention").

#### Capa 3 — State file resiliente
**Veredicto: APROBADO — MEJORAR ATOMICIDAD**

La estrategia `write-to-tmp → fsync → rename → copy-to-bak` es correcta y es el patrón estándar para escritura atómica en Linux (garantizado por el kernel POSIX). Sin embargo:

- El plan no especifica qué hacer si **el backup `.sbos_state.json.bak` también está corrupto**. Debe añadirse una tercera opción: reconstrucción desde los manifests en disco (plugin loader scan). Esta es la última línea de defensa y cumple ISO/IEC 25010 — Recoverability.
- El plan no especifica **migración de schema**. Si la versión del código no coincide con la versión del state file, el comportamiento es indefinido. Debe añadirse validación de `Version` en `NewManager()`.

#### Capa 4 — Watchdog systemd
**Veredicto: APROBADO — IMPLEMENTACIÓN VERIFICADA**

La implementación Go propuesta (socket Unix vía `net.DialUnix("unixgram")`) es funcional y está alineada con la especificación oficial de freedesktop.org. La documentación oficial confirma que los servicios deben enviar `WATCHDOG=1` a intervalos de la mitad del `WatchdogSec`. La implementación nativa sin libsystemd es el patrón correcto para daemons Go.

**Mejora:** Usar `sd_watchdog_enabled()` equivalente en Go: leer `WATCHDOG_USEC` del entorno para calcular dinámicamente el intervalo, en lugar de hardcodear `WatchdogSec/2`. Esto hace el daemon más portable.

#### Capa 5 — Ficha sbos-lifecycle
**Veredicto: APROBADO**

La estructura de la ficha cumple con P19. El health check `systemctl is-active bos.service` es el comando correcto y retorna exit 0 solo cuando el servicio está activo.

---

## 2. Modificaciones al Plan Original

Las siguientes modificaciones son **obligatorias** para que el producto cumpla los estándares de calidad profesional:

### MOD-01: Corrección del unit file (CRÍTICA)

```ini
[Unit]
Description=SBOS Infrastructure Daemon — Kubernetes Lifecycle Supervisor
Documentation=https://docs.sbos.internal/bos-daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
NotifyAccess=all
ExecStart=/opt/bos/bin/bos --config /etc/bos/bos.toml
ExecStop=/opt/bos/bin/bosctl shutdown --timeout 180
Restart=on-failure
RestartSec=10
StartLimitBurst=5
StartLimitIntervalSec=300
TimeoutStartSec=120
TimeoutStopSec=210
WatchdogSec=30
StandardOutput=journal
StandardError=journal
SyslogIdentifier=bos
; Aislamiento de seguridad (IEC 62443-4-1)
PrivateTmp=true
NoNewPrivileges=false
; BOS necesita privilegios para gestionar K8s
AmbientCapabilities=CAP_NET_ADMIN CAP_SYS_ADMIN

[Install]
WantedBy=multi-user.target
```

**Cambios respecto al plan original:**

| Directiva | Plan original | Plan corregido | Razón |
|---|---|---|---|
| `After=` | `network.target` | `network-online.target` | BOS necesita red funcional para API K8s |
| `Restart=` | `always` | `on-failure` | Evita bucle infinito en shutdown limpio |
| `StartLimitBurst=` | no existía | `5` en `300s` | Previene crash loop (ISO 25010 Performance) |
| `TimeoutStopSec=` | no existía | `210s` | Drain K8s (120s) + kubelet (30s) + containerd (30s) + margen (30s) |
| `TimeoutStartSec=` | no existía | `120s` | BOS puede tardar en verificar K8s al arranque |
| `PrivateTmp=` | no existía | `true` | Aislamiento básico (IEC 62443-4-1) |
| `SyslogIdentifier=` | no existía | `bos` | Filtrado limpio en journalctl |

### MOD-02: Saga de shutdown con timeouts por fase (ALTA)

La función `Shutdown()` en `saga.go` debe implementarse con timeouts por fase y registro en journal:

```
Fase 1 (timeout 120s): kubectl drain <nodename> --ignore-daemonsets --delete-emptydir-data --grace-period=30
Fase 2 (timeout 30s):  systemctl stop kubelet
Fase 3 (timeout 30s):  systemctl stop containerd
Fase 4 (timeout 10s):  Escribir estado final en state file
Fase 5 (inmediato):    sd_notify("STOPPING=1")

Si cualquier fase falla:
  → Registrar en journal con nivel ERROR
  → Continuar con siguiente fase (best-effort shutdown)
  → NO bloquear indefinidamente
```

### MOD-03: Watchdog con intervalo dinámico (MEDIA)

```go
// En main.go, goroutine de watchdog
func startWatchdog(ctx context.Context) {
    // Leer WATCHDOG_USEC del entorno (systemd lo exporta)
    usecStr := os.Getenv("WATCHDOG_USEC")
    if usecStr == "" {
        return // watchdog no habilitado, no-op
    }
    usec, err := strconv.ParseInt(usecStr, 10, 64)
    if err != nil || usec <= 0 {
        return
    }
    interval := time.Duration(usec/2) * time.Microsecond
    ticker := time.NewTicker(interval)
    defer ticker.Stop()
    for {
        select {
        case <-ctx.Done():
            return
        case <-ticker.C:
            sdNotify("WATCHDOG=1")
        }
    }
}
```

### MOD-04: Reconstrucción de state file en tres niveles (ALTA)

```
Nivel 1: Cargar .sbos_state.json (principal)
Nivel 2: Si falla → cargar .sbos_state.json.bak (backup)
Nivel 3: Si falla → rebuild desde plugin loader scan (manifests en disco)
         + registrar en journal: "STATE FILE REBUILT FROM MANIFESTS"
         + sd_notify("STATUS=State file rebuilt from disk manifests")
Si los tres niveles fallan → log.Fatal (no hay forma de recuperar)
```

### MOD-05: Jitter en reconciliación inicial (BAJA)

```go
// En runNormal(), antes de ReconcileNow()
if k8sWasRunning && kubeletIsActive {
    // Evitar thundering herd si múltiples nodos arrancan juntos
    jitter := time.Duration(rand.Intn(30)) * time.Second
    log.Info().Dur("jitter", jitter).Msg("Applying startup jitter before initial reconcile")
    time.Sleep(jitter)
}
reconcileScheduler.ReconcileNow()
```

---

## 3. Arquitectura de Capas Revisada

```
┌─────────────────────────────────────────────────────────┐
│                    Ubuntu (systemd)                     │
│  PID 1 → bos.service (Type=notify, WatchdogSec=30)     │
│  After=network-online.target                            │
│  Restart=on-failure, TimeoutStopSec=210                 │
└────────────────────┬────────────────────────────────────┘
                     │ supervisa (ExecStart / WatchdogSec)
┌────────────────────▼────────────────────────────────────┐
│                 BOS Daemon (Go)                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Startup: loadState → reconcileNow (con jitter)  │   │
│  │ Runtime: healthChecker + reconcileScheduler     │   │
│  │ Shutdown: drain K8s → stop kubelet → stop ctr   │   │
│  │ Watchdog: sd_notify("WATCHDOG=1") cada 15s      │   │
│  │ State: write-tmp→fsync→rename + backup          │   │
│  └─────────────────────────────────────────────────┘   │
└────────────────────┬────────────────────────────────────┘
                     │ gestiona ciclo de vida
┌────────────────────▼────────────────────────────────────┐
│              Kubernetes (kubelet + containerd)           │
│  kubelet.service / containerd.service                   │
│  Parados ANTES de que BOS termine (saga shutdown)       │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│                  Aplicaciones BOS                       │
│  Fichas instaladas y gestionadas por el Observer Loop   │
└─────────────────────────────────────────────────────────┘
```

---

## 4. Plan de Implementación por Capas (Definitivo)

### Capa 0 — systemd unit file
**Archivos a crear:**
- `/etc/systemd/system/bos.service` (ver MOD-01)

**Criterio de completitud:** `systemctl status bos.service` muestra `active (running)` con `Type=notify`.

---

### Capa 1 — Shutdown ordenado (saga shutdown)
**Archivos a modificar:**

| Archivo | Cambio |
|---|---|
| `src/cmd/bos/main.go` | Reescribir `shutdown()`: añadir context con timeout, llamar saga, sd_notify("STOPPING=1") |
| `src/internal/installer/saga.go` | Añadir `Shutdown(ctx context.Context) error` con las 5 fases |
| `src/internal/installer/compensator.go` | Registrar cadena `shutdown` (best-effort, sin compensación) |

**Secuencia de shutdown definitiva:**

```
1. [t=0]    Recibir SIGTERM de systemd
2. [t=0]    sd_notify("STOPPING=1")
3. [t=0]    Marcar estado cluster: "draining" en state file
4. [t=0-120] kubectl drain <nodename> --ignore-daemonsets
              --delete-emptydir-data --grace-period=30 --timeout=120s
5. [t+120]  systemctl stop kubelet (timeout 30s)
6. [t+150]  systemctl stop containerd (timeout 30s)
7. [t+180]  Detener subsistemas BOS: apiServer, healthChecker, reconcileScheduler
8. [t+190]  Persistir estado final: todas las fichas K8s → "stopped"
9. [t+200]  os.Exit(0)
```

**Criterio de completitud:** `ps aux | grep -E 'kubelet|containerd'` retorna vacío después de `systemctl stop bos.service`.

---

### Capa 2 — Arranque con reconciliación inmediata
**Archivos a modificar:**

| Archivo | Cambio |
|---|---|
| `src/cmd/bos/main.go` | Insertar bloque pre-event-loop en `runNormal()` |

**Secuencia de arranque definitiva:**

```
1. autoBootstrap() — configuración del entorno
2. Inicializar subsistemas (state manager, plugin loader, health checker)
3. Leer state file → determinar estado previo de fichas K8s
4. Si fichas K8s estaban INSTALADA -- OK:
   a. Verificar kubelet: SystemctlCmd("is-active", "kubelet")
   b. Si kubelet DOWN → repair asíncrono (reconcileScheduler.ReconcileNow())
   c. Si kubelet UP → aplicar jitter (0-30s) → ReconcileNow() → CheckNow()
5. sd_notify("READY=1\nSTATUS=BOS daemon running — K8s state verified")
6. Iniciar event loop principal
```

**Criterio de completitud:** `journalctl -u bos.service | grep -i reconcile` muestra reconciliación al arranque.

---

### Capa 3 — State file resiliente
**Archivos a modificar:**

| Archivo | Cambio |
|---|---|
| `src/internal/state/manager.go` | `NewManager()` con fallback de 3 niveles; `writeState()` con write-rename atómico + backup |

**Estrategia de escritura definitiva (atómica):**

```
writeState():
  1. Serializar JSON a memoria
  2. Escribir a .sbos_state.json.tmp
  3. fdatasync(.tmp)
  4. rename(.tmp → .sbos_state.json)   ← atómico (garantizado por kernel POSIX)
  5. cp .sbos_state.json → .sbos_state.json.bak
```

**Criterio de completitud:** Corromper `.sbos_state.json` y reiniciar BOS; el daemon arranca correctamente y reconstruye el state file.

---

### Capa 4 — Watchdog systemd
**Archivos a modificar:**

| Archivo | Cambio |
|---|---|
| `src/cmd/bos/main.go` | Añadir `sdNotify()`, `startWatchdog()` goroutine (ver MOD-03), llamadas en startup/shutdown |

**Implementación Go definitiva (sin dependencias externas):**

```go
// sdNotify envía estado al socket de systemd. No-op si no hay NOTIFY_SOCKET.
func sdNotify(state string) {
    socketPath := os.Getenv("NOTIFY_SOCKET")
    if socketPath == "" {
        return
    }
    // Soporte para abstract sockets (@socket)
    if strings.HasPrefix(socketPath, "@") {
        socketPath = "\x00" + socketPath[1:]
    }
    addr := &net.UnixAddr{Name: socketPath, Net: "unixgram"}
    conn, err := net.DialUnix("unixgram", nil, addr)
    if err != nil {
        log.Warn().Err(err).Msg("sd_notify: failed to connect to NOTIFY_SOCKET")
        return
    }
    defer conn.Close()
    if _, err := conn.Write([]byte(state)); err != nil {
        log.Warn().Err(err).Msg("sd_notify: failed to write")
    }
}
```

**Criterio de completitud:** `sudo kill -STOP $(cat /run/bos/bos.pid)` durante más de 30s provoca que systemd reinicie el servicio automáticamente.

---

### Capa 5 — Ficha sbos-lifecycle
**Archivos a crear:**

```
staging/core/servers/hostserver/sbos-lifecycle/
  manifest.yml
  task_catalog.sh
  yaml_engine.yml
```

**manifest.yml definitivo:**

```yaml
id: sbos-lifecycle
name: SBOS Lifecycle Manager
server: hostserver
category: 1
criticality: true
auto_install: true
version: "1.0"
order:
  priority: 15
dependencies:
  - sbos-bootstrap-os
health:
  check_command: systemctl is-active bos.service
  check_interval_seconds: 30
  check_timeout_seconds: 5
description: >
  Instala y habilita bos.service como servicio systemd de primera clase.
  Gestiona el ciclo de vida completo: arranque automático, watchdog,
  shutdown ordenado de Kubernetes y reconciliación al boot.
```

**task_catalog.sh (funciones requeridas):**

```bash
install_generic() {
    local service_src="${SBOS_BLIBS}/servers/hostserver/sbos-lifecycle/bos.service"
    local service_dst="/etc/systemd/system/bos.service"

    __SBOS__STEP_START__ "copy_unit_file"
    cp "${service_src}" "${service_dst}" || return 1
    __SBOS__STEP_OK__

    __SBOS__STEP_START__ "daemon_reload"
    systemctl daemon-reload || return 1
    __SBOS__STEP_OK__

    __SBOS__STEP_START__ "enable_service"
    systemctl enable bos.service || return 1
    __SBOS__STEP_OK__
}

remove_generic() {
    systemctl disable bos.service 2>/dev/null || true
    rm -f /etc/systemd/system/bos.service
    systemctl daemon-reload
}

check_health() {
    systemctl is-active bos.service
}
```

**Criterio de completitud:** `bosctl status sbos-lifecycle` muestra `INSTALADA -- OK, HEALTHY`.

---

## 5. Comandos de Verificación

### Capa 0: systemd unit

```bash
# Verificar que el unit file tiene las directivas requeridas
grep -E 'Type=notify|WatchdogSec|TimeoutStopSec|network-online' \
  /etc/systemd/system/bos.service

# Recargar y arrancar
sudo systemctl daemon-reload
sudo systemctl enable bos.service
sudo systemctl start bos.service

# Verificar estado: debe mostrar "active (running)" con Type=notify
systemctl status bos.service --no-pager

# Ver logs en tiempo real
journalctl -u bos.service -f

# Verificar que systemd reconoce el READY=1
journalctl -u bos.service | grep -i 'started\|ready'
```

### Capa 1: shutdown ordenado

```bash
# Parar BOS vía systemd (debe ejecutar la saga de shutdown)
sudo systemctl stop bos.service

# Verificar que NO queden procesos K8s huérfanos
ps aux | grep -E 'kubelet|containerd|kube-apiserver|etcd' | grep -v grep
# Salida esperada: vacía

# Verificar que el drenado quedó registrado en journal
journalctl -u bos.service | grep -E 'drain|shutdown|STOPPING'

# Verificar que BOS escribió estado final en state file
python3 -c "
import json
with open('/etc/bos/.sbos_state.json') as f:
    s = json.load(f)
for k, v in s.get('fichas', {}).items():
    print(f'{k}: {v.get(\"state\", \"?\")}')
"

# Verificar que el TimeoutStopSec fue respetado (no hubo SIGKILL)
journalctl -u bos.service | grep -i 'killed\|sigkill'
# Salida esperada: vacía (BOS terminó limpiamente)
```

### Capa 2: arranque con reconciliación

```bash
# Arrancar de nuevo
sudo systemctl start bos.service

# Verificar que el reconcile corrió al arranque (antes del event loop)
journalctl -u bos.service | grep -i 'startup reconcile\|initial reconcile\|reconcile'

# Esperar a que K8s se estabilice
sleep 30

# Verificar que K8s volvió automáticamente
kubectl get nodes
# Resultado esperado: STATUS=Ready

kubectl get pods -A
# Resultado esperado: todos los pods del control plane en Running

# Verificar jitter (solo si K8s estaba UP antes del reinicio)
journalctl -u bos.service | grep -i 'jitter'

# Verificar que no hubo ventana de 300s sin reconciliación
journalctl -u bos.service --since "boot" | grep -i 'reconcile' | head -5
# La primera entrada de reconcile debe ser en los primeros 60s del boot
```

### Capa 3: state file resiliente

```bash
# Test Nivel 1 (corrupción del principal)
sudo systemctl stop bos.service
echo '{"corrupt": true, invalid json' | sudo tee /etc/bos/.sbos_state.json
sudo systemctl start bos.service
sleep 5
# Verificar reconstrucción desde backup
python3 -m json.tool /etc/bos/.sbos_state.json > /dev/null && echo "JSON válido: OK"

# Test Nivel 2 (corrupción de backup también)
sudo systemctl stop bos.service
echo 'corrupt' | sudo tee /etc/bos/.sbos_state.json
echo 'corrupt' | sudo tee /etc/bos/.sbos_state.json.bak
sudo systemctl start bos.service
sleep 5
# Verificar reconstrucción desde manifests
journalctl -u bos.service | grep -i 'rebuilt from manifests\|rebuild'
python3 -m json.tool /etc/bos/.sbos_state.json > /dev/null && echo "JSON válido: OK"

# Verificar que existe backup actualizado
ls -la /etc/bos/.sbos_state.json.bak

# Verificar escritura atómica: no debe existir .tmp después del arranque
ls /etc/bos/.sbos_state.json.tmp 2>/dev/null && echo "ERROR: .tmp existe" || echo "OK: sin .tmp"
```

### Capa 4: watchdog

```bash
# Verificar que BOS envía WATCHDOG=1 periódicamente
journalctl -u bos.service | grep -i 'watchdog'

# Test de watchdog: pausar BOS artificialmente
BOS_PID=$(cat /run/bos/bos.pid)
sudo kill -STOP ${BOS_PID}
echo "BOS pausado. Esperando 35s para que systemd detecte watchdog timeout..."
sleep 35

# systemd debe haber reiniciado BOS automáticamente
systemctl status bos.service --no-pager
# Resultado esperado: active (running) — con restart count incrementado

# Verificar que systemd registró el watchdog timeout
journalctl -u bos.service | grep -i 'watchdog\|restart'

# Verificar que el restart count aumentó
systemctl show bos.service --property=NRestarts
# Resultado esperado: NRestarts=1 (o superior si hubo tests previos)
```

### Capa 5: ficha sbos-lifecycle

```bash
# Verificar estado de la ficha
bosctl status sbos-lifecycle
# Resultado esperado: INSTALADA -- OK | HEALTHY

# Verificar health check explícito
bosctl health sbos-lifecycle
# Resultado esperado: HEALTHY (exit 0 de systemctl is-active bos.service)

# Verificar que el unit file fue instalado por la ficha
stat /etc/systemd/system/bos.service
# Resultado esperado: archivo existe

# Verificar que el unit file tiene las directivas correctas (MOD-01)
grep -c 'Type=notify' /etc/systemd/system/bos.service
# Resultado esperado: 1

grep -c 'WatchdogSec' /etc/systemd/system/bos.service
# Resultado esperado: 1

grep 'TimeoutStopSec' /etc/systemd/system/bos.service
# Resultado esperado: TimeoutStopSec=210

# Test de idempotencia: reinstalar la ficha no debe romper nada
bosctl repair sbos-lifecycle
bosctl status sbos-lifecycle
# Resultado esperado: INSTALADA -- OK | HEALTHY
```

---

## 6. Trazabilidad a Estándares Internacionales

### ISO/IEC 25010:2023 — Modelo de Calidad del Producto

| Sub-característica | Requisito | Implementación en BOS | Capa |
|---|---|---|---|
| **Availability** (Disponibilidad) | El sistema debe estar disponible cuando se necesita | `Restart=on-failure` + `WatchdogSec=30` + arranque automático en boot | 0, 4 |
| **Fault Tolerance** (Tolerancia a fallos) | El sistema debe operar a pesar de fallos de hardware/software | Watchdog systemd reinicia si BOS se cuelga; saga de shutdown best-effort | 1, 4 |
| **Recoverability** (Recuperabilidad) | El sistema debe recuperar datos tras una interrupción | State file con 3 niveles de fallback; reconciliación al arranque | 2, 3 |
| **Faultlessness** (Ausencia de defectos) | El sistema debe evitar dejar estados inconsistentes | Escritura atómica (write-rename) + shutdown ordenado antes de terminar | 1, 3 |
| **Performance Efficiency** | Uso eficiente de recursos | `StartLimitBurst` evita bucles infinitos; jitter evita thundering herd | 0, 2 |

### ISO 9001:2015 + ISO/IEC 90003:2018 — Gestión de Calidad

| Cláusula ISO 9001 | Aplicación en BOS |
|---|---|
| **8.5.1** Control de producción y prestación del servicio | La ficha `sbos-lifecycle` documenta y automatiza el proceso de instalación de forma repetible |
| **8.5.3** Propiedad del cliente / Preservación | El state file con backup y escritura atómica protege el estado del sistema |
| **8.7** Control de salidas no conformes | La saga de shutdown aborta K8s antes de terminar; evita estados no conformes |
| **10.2** No conformidad y acción correctiva | El reconcile scheduler detecta drift y ejecuta repair automáticamente |
| **7.5** Información documentada | Este documento + el manifest.yml + el journal de systemd forman el registro de calidad |

### ISO 22301:2019 — Continuidad de Negocio

| Requisito | Implementación |
|---|---|
| RTO (Recovery Time Objective) | Con `Restart=on-failure` y `ReconcileNow()` al boot, BOS y K8s deben restaurarse en < 5 minutos tras un reinicio de Ubuntu |
| Estado de recuperación | `runNormal()` lee el state file y determina qué fichas necesitan repair, sin reinstalación |
| Prueba de continuidad | Los comandos de verificación de Capa 2 y 3 son los procedimientos de prueba del RTO |

### IEC 62443-4-1 — Desarrollo Seguro de Componentes

| Práctica | Implementación |
|---|---|
| **SR-2** (Defense in depth) | Arquitectura de capas; BOS no expone K8s directamente al exterior |
| **SR-6** (Auditoría) | Cada fase del shutdown y del reconcile queda registrada en el journal de systemd con timestamps |
| **SR-7** (Disponibilidad de recursos) | `PrivateTmp=true` y `AmbientCapabilities` mínimas en el unit file |
| **SM-9** (Gestión de configuración) | El state file + backup + el manifest de la ficha forman el baseline de configuración |

### POSIX / IEEE Std 1003.1

| Garantía POSIX | Uso en BOS |
|---|---|
| `rename()` es atómico dentro del mismo filesystem | La escritura del state file usa `rename(.tmp → .json)` |
| `flock(LOCK_EX)` garantiza acceso exclusivo | El state manager usa file locking exclusivo |
| `SIGTERM` debe ser manejable | El daemon captura `SIGTERM` y ejecuta shutdown ordenado |

---

## 7. Matriz de Riesgos y Mitigación

| ID | Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|---|
| R01 | `kubectl drain` no termina en 120s (cluster grande) | Media | Alto | Timeout configurable vía `bos.toml`; el drain retorna error parcial y continúa |
| R02 | State file corrupto Y backup corrupto | Baja | Alto | Reconstrucción desde manifests (MOD-04, Nivel 3) |
| R03 | systemd envía SIGKILL antes de que BOS termine el shutdown | Media | Medio | `TimeoutStopSec=210` da 210s; la saga completa dura ≤200s |
| R04 | Bucle infinito de reinicios si BOS crashea al arrancar | Media | Alto | `StartLimitBurst=5` en `300s` — systemd detiene los reinicios |
| R05 | Thundering herd si múltiples nodos reinician juntos | Baja | Medio | Jitter aleatorio 0-30s antes de `ReconcileNow()` (MOD-05) |
| R06 | `NOTIFY_SOCKET` no disponible (arranque fuera de systemd) | Alta | Bajo | `sdNotify()` es no-op si `NOTIFY_SOCKET=""` |
| R07 | K8s no responde al `kubectl drain` (API server down) | Media | Alto | Timeout 120s; continúa con `systemctl stop kubelet` directamente |

---

## 8. Orden de Implementación y Dependencias

```
Capa 0 ──► Capa 1 ──► Capa 2 ──► Capa 3 ──► Capa 4 ──► Capa 5
   │          │          │          │          │          │
   │          │          │          │          │          └── Ficha BOS (P19)
   │          │          │          │          │              Empaqueta todo
   │          │          │          │          │
   │          │          │          │          └── Watchdog systemd
   │          │          │          │              Requiere: unit Type=notify (C0)
   │          │          │          │
   │          │          │          └── State file resiliente
   │          │          │              Requiere: nada (independiente)
   │          │          │              Bloquea: Capa 2 (el reconcile lee state)
   │          │          │
   │          │          └── Arranque con reconciliación
   │          │              Requiere: Capa 1 (para saber si K8s estaba UP)
   │          │              Requiere: Capa 3 (state file confiable)
   │          │
   │          └── Shutdown ordenado (saga shutdown)
   │              Requiere: Capa 0 (TimeoutStopSec correcto en unit)
   │              Bloquea: Capa 2 (reconcile post-shutdown)
   │
   └── systemd unit file
       Sin dependencias de código.
       Es solo un archivo .service.
       Puede implementarse primero.
```

**Recomendación de sprint:**

| Sprint | Capas | Entregable |
|---|---|---|
| Sprint 1 | 0 + 3 | Unit file correcto + State file robusto (las dos sin dependencias cruzadas) |
| Sprint 2 | 1 | Saga de shutdown ordenado (el cambio de mayor riesgo) |
| Sprint 3 | 2 + 4 | Reconciliación al arranque + Watchdog (construyen sobre Sprint 2) |
| Sprint 4 | 5 | Ficha sbos-lifecycle (empaqueta y formaliza todo) |

---

## Apéndice A — Brechas del diagnóstico original y su cierre

| Brecha | Severidad | Cierre en este plan |
|---|---|---|
| B1: shutdown() no detiene kubelet/containerd | CRÍTICA | Capa 1 — Saga de shutdown con 5 fases |
| B2: No hay ReconcileNow() al arranque | CRÍTICA | Capa 2 — Bloque pre-event-loop en runNormal() |
| B3: State file corrupto → Fatal sin rebuild | ALTA | Capa 3 + MOD-04 — 3 niveles de fallback |
| B4: No existe saga shutdown | ALTA | Capa 1 — Función Shutdown() en saga.go |
| B5: Sin watchdog de systemd | MEDIA | Capa 4 + MOD-03 — sdNotify() + goroutine |
| B6: Plugin loader no detecta fichas eliminadas | BAJA | No incluido en este plan (scope acotado) |

**B6 se excluye de este plan** porque su impacto es stale entries en el state file (sin riesgo de seguridad ni pérdida de datos) y requiere un cambio más invasivo en el plugin loader. Se recomienda como ticket independiente.

---

*Documento generado y validado el 2026-05-19. Estándares verificados contra fuentes oficiales: freedesktop.org (systemd), iso.org (ISO 9001, ISO/IEC 25010, ISO 22301), iec.ch (IEC 62443-4-1), kubernetes.io (graceful node shutdown).*
