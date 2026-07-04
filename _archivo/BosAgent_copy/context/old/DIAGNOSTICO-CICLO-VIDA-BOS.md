# Diagnóstico del ciclo de vida systemd del daemon BOS

Fecha: 2026-05-19
Repositorio: BosAgent
Commit base: 5828eda (sbos-bootstrap-os y sbos-bootstrap-k8s certificados HEALTHY)

## Objetivo

Implementar el ciclo de vida completo del daemon BOS como servicio systemd de primera clase en Ubuntu.

Arquitectura de capas:
```
Ubuntu → BOS (daemon) → Kubernetes → Aplicaciones
```

BOS es el supervisor de la capa K8s, por lo tanto debe:

1. **Systemd unit** para BOS (`bos.service`)
2. **Shutdown ordenado** de K8s al parar el servicio
3. **Arranque y recuperación automática** al reiniciar Ubuntu
4. **Ficha `sbos-lifecycle`** que empaquete todo como ficha BOS (P19)

---

## 1. Diagnóstico del estado actual

Revisión exhaustiva de ~3,500 líneas de Go en los 7 archivos del daemon.

### 1.1 MAIN / ENTRYPOINT

**Archivo:** `src/cmd/bos/main.go` (1121 líneas)

| Función | Líneas | Propósito |
|---|---|---|
| `main()` | 61-118 | Parse flags, zerolog, root check, bootstrap env, autoBootstrap(), dispatch |
| `loadBootstrapEnv()` | 122-166 | Carga bos-bootstrap.env desde 6 rutas posibles |
| `autoBootstrap()` | 172-384 | Directorios, self-deploy, configs, cgroup, root password, nftables, PID file |
| `runNormal()` | 450-581 | Inicializa subsistemas, signal handling, event loop |
| `runConfigPending()` | 922-986 | Modo staged: API read-only + POST /api/install/config |
| `shutdown()` | 988-994 | Detiene API, health checker, reconcile scheduler, escribe audit log |
| `initializeFichaStates()` | 631-659 | Registra fichas en state manager con estados iniciales |
| `runObserverLoop()` | 663-782 | Goroutine: observa estados, auto-install, auto-repair |
| `findNextAutoInstall()` | 788-826 | Algoritmo topológico para siguiente ficha |
| `configureSystemdDelegate()` | 1038-1045 | Crea drop-in systemd con Delegate=yes |

**Lo que YA existe:**

- Manejo de señales OS: `signal.Notify(sigCh, SIGINT, SIGTERM, SIGHUP)` (líneas 537-538, 553-580)
- Graceful shutdown parcial: `shutdown()` llama `apiServer.Shutdown()`, `healthChecker.Stop()`, `reconcileScheduler.Stop()` (línea 988)
- PID file: `/run/bos/bos.pid` (línea 278)
- Arranque normal vs config-pending
- `SystemctlCmd()` helper existe (línea 605) pero no se usa en ningún flujo de shutdown

**Lo que FALTA (B1):**

- `shutdown()` no detiene kubelet ni containerd. Solo detiene subsistemas internos de BOS. Al parar BOS, kubelet/containerd quedan huérfanos
- No hay saga de shutdown que ejecute drenado ordenado de K8s
- `shutdown()` no escribe estado "stopped" explícito que systemd pueda leer
- No hay `context.Context` con timeout global en shutdown — las llamadas son síncronas sin deadline
- No se usa `SystemctlCmd()` para detener servicios del sistema

---

### 1.2 RECONCILE SCHEDULER

**Archivo:** `src/internal/reconcile/scheduler.go` (232 líneas)

| Función | Líneas | Propósito |
|---|---|---|
| `NewScheduler()` | 48-58 | Constructor: stateMgr, installer, interval, serversPath, autoRepair |
| `Run()` | 61-80 | Bucle periódico con ticker; escucha `stopCh` |
| `Stop()` | 83-90 | Cierra canal de parada |
| `ReconcileNow()` | 93-95 | Wrapper público para `reconcile()` |
| `reconcile()` | 106-189 | Lee estado, computa hashes SHA-256, compara, detecta drift, auto-repair |
| `ComputeHashes()` | 193-209 | Hash de manifest.yml, task_catalog.sh, yaml_engine.yml |
| `sha256File()` | 211-223 | Hash de un archivo individual |
| `DriftSummary()` | 226-231 | Reporte legible |

**Lo que YA existe:**

- Compara hashes de manifests en disco vs state file (principio R16: docs-first)
- Si detecta divergencia → `ACTUALIZACION_DISPONIBLE` → `installer.Repair()` en goroutine
- Si health_status es DEGRADED o estado es INSTALADA -- ALERTA → repair
- Actualiza stored hashes después de cada ciclo (nuevo baseline)

**Lo que FALTA (B2):**

- **No se ejecuta al arranque.** No hay `ReconcileNow()` en `runNormal()` antes del event loop. Si BOS se reinicia, pasan hasta 300 segundos antes de detectar drift
- No reconcilia el estado de subprocesos del sistema (kubelet, containerd)
- `Stop()` cierra el canal pero no cancela una `reconcile()` en curso — no hay `context.Context` compartido

---

### 1.3 STATE MANAGER

**Archivo:** `src/internal/state/manager.go` (364 líneas)

| Función | Líneas | Propósito |
|---|---|---|
| `NewManager()` | 121-143 | Abre/crea state file, flock(LOCK_EX), init si vacío |
| `initEmpty()` | 145-155 | Inicializa estado vacío con version, hostname, mapas |
| `Read()` | 158-171 | Seek(0) + JSON Decode con mutex |
| `Transition()` | 175-210 | Valida transición, actualiza timestamps, escribe |
| `RegisterHashes()` | 213-232 | Almacena hashes SHA-256 |
| `SetHealth()` | 235-254 | Actualiza health_status |
| `SetBlocked()` | 265-284 | Bypass de validación, escribe directo |
| `Register()` | 290-318 | Registro inicial (no valida transiciones) |
| `Unblock()` | 321-331 | BLOQUEADA → NO_INSTALADA |
| `writeState()` | 344-357 | Seek(0) + Truncate(0) + Encode + Sync (fsync inmediato) |
| `Close()` | 360-363 | Unlock + Close |

**Lo que YA existe:**

- `Read()` carga el state file de disco (línea 167)
- Persiste cambios inmediatamente con `fsync()` (línea 356)
- Maneja "state file no existe": `os.O_RDWR|os.O_CREATE` + `initEmpty()`
- File locking exclusivo: `syscall.Flock(fd, LOCK_EX)`
- Máquina de estados completa: 5 canónicos + 5 transicionales con `ValidTransitions`

**Lo que FALTA (B3):**

- **State file corrupto (JSON mal formado) → `log.Fatal()`.** No hay fallback a rebuild desde manifests en disco
- **No hay backup.** No se mantiene `.sbos_state.json.bak`. Si el disco se llena durante `writeState()`, el archivo queda vacío
- **No hay migración de schema.** El campo `Version` existe pero nunca se valida contra la versión del código
- `readLocked()` no valida que el archivo tenga contenido. Si está vacío (crash durante truncate), `Decode()` devuelve `io.EOF`

---

### 1.4 HEALTH CHECKER

**Archivo:** `src/internal/health/checker.go` (307 líneas)

| Función | Líneas | Propósito |
|---|---|---|
| `NewChecker()` | 83-93 | Constructor con execRunner real |
| `Run()` | 109-130 | Bucle: `checkAll()` inmediato, luego cada tick |
| `Stop()` | 133-140 | Cierra canal de parada |
| `CheckNow()` | 143-145 | Wrapper público |
| `checkAll()` | 147-169 | Itera fichas, salta BLOQUEADA, ejecuta checkOne(), persiste |
| `checkOne()` | 222-267 | Ejecuta check_command, clasifica HEALTHY/DEGRADED/DOWN/UNKNOWN |
| `probeConfig()` | 171-220 | Lee manifest.yml, extrae health section |
| `Classify()` | 270-281 | Clasifica desde señales raw |
| `Summary()` | 284-299 | Reporte legible |
| `ResetCounters()` | 302-306 | Resetea contador de fallos consecutivos |

**Lo que YA existe:**

- `checkAll()` se ejecuta al arrancar (línea 119 dentro de `Run()`)
- Persiste resultados vía `SetHealth()`
- Clasificación con umbral configurable (default: 3 fallos consecutivos = DOWN)
- Salta fichas BLOQUEADA

**Lo que FALTA (B5):**

- **No alimenta directamente al reconcile scheduler.** `checkAll()` solo persiste vía `SetHealth()`. El scheduler lee esos estados en su próximo ciclo (hasta 300s después). No hay canal de eventos
- **No verifica subprocesos del sistema** (kubelet, containerd). Solo verifica fichas vía check_command
- **No hay watchdog de systemd.** No escribe al socket `NOTIFY_SOCKET` para `WATCHDOG=1`

---

### 1.5 SAGA ORCHESTRATOR

**Archivos:**
- `src/internal/installer/saga.go` (326 líneas)
- `src/internal/installer/compensator.go` (135 líneas)

**Sagas implementadas:**

| Comando | Función | Compensación |
|---|---|---|
| install | `Install()` | uninstall |
| update | `Update()` | restore_backup |
| repair | `Repair()` | rollback_repair |
| remove | `Remove()` | — |
| probe | `Probe()` (dry-run) | — |
| status | `Status()` | — |

**Lo que YA existe:**

- Protocolo de señales Bash (`__SBOS__STEP_START__`, etc.) para observabilidad step-level
- Compensación automática en fallo (P6, P12)
- Observer pattern para eventos en tiempo real (WebSocket)
- Timeout configurable por comando

**Lo que FALTA (B4):**

- **No existe saga `shutdown`.** No hay comando que ejecute drenado de K8s + parada de kubelet/containerd
- **No hay pre-shutdown drain de fichas.** Al recibir SIGTERM, idealmente BOS debería: (a) marcar fichas como "draining", (b) ejecutar remove en fichas tipo 3 (opcionales), (c) detener kubelet, (d) detener containerd, (e) escribir estado final
- Compensación no se ejecuta en shutdown — `shutdown()` en main.go no invoca al compensator

---

### 1.6 PLUGIN LOADER

**Archivo:** `src/internal/plugin/loader.go` (326 líneas)

| Función | Líneas | Propósito |
|---|---|---|
| `NewLoader()` | 44-49 | Constructor |
| `Scan()` | 54-123 | Escanea `/etc/bos/blibs/servers/`, detecta fichas |
| `loadFicha()` | 125-167 | Carga manifest, hashea archivos |
| `parseManifest()` | 169-267 | Parser state-machine de manifest.yml |
| `Reload()` | 270-274 | Re-scan (triggered por SIGHUP) |
| `Get()` | 277-282 | Búsqueda por ID |
| `List()` | 285-295 | Lista todas las fichas |
| `Count()` | 298-302 | Número de fichas |
| `Hashes()` | 305-311 | Retorna mapa de hashes |

**Lo que YA existe:**

- Escanea `/etc/bos/blibs/servers/` recursivamente
- Alimenta al state manager vía `initializeFichaStates()` (main.go:509)
- Hash SHA-256 de todos los archivos de la ficha
- Recarga en caliente vía SIGHUP (main.go:559)
- Detección de dependencias desde manifest.yml

**Lo que FALTA (B6):**

- **No detecta fichas eliminadas del disco.** Si se borra un directorio de ficha, el loader no la remueve del state manager
- **No valida schema del manifest.yml** (campos requeridos, tipos)
- No emite eventos al WebSocket hub cuando descubre nuevas fichas

---

## 2. Resumen de brechas

| # | Brecha | Severidad | Impacto |
|---|---|---|---|
| B1 | shutdown() no detiene kubelet/containerd | CRÍTICA | Servicios huérfanos al parar BOS |
| B2 | No hay ReconcileNow() al arranque | CRÍTICA | Ventana de 300s sin detección de drift post-reboot |
| B3 | State file corrupto → Fatal sin rebuild | ALTA | Crash durante escritura deja daemon inarrancable |
| B4 | No existe saga shutdown | ALTA | Sin drenado ordenado de K8s antes de terminar |
| B5 | Sin watchdog de systemd | MEDIA | systemd no detecta hangs de BOS |
| B6 | Plugin loader no detecta fichas eliminadas | BAJA | Entradas stale en state file |

---

## 3. Plan de implementación por capas

```
Capa 0: systemd unit file        ← contrato con el SO
Capa 1: shutdown ordenado        ← B1 + B4 (saga shutdown)
Capa 2: arranque con reconcil.   ← B2 (ReconcileNow al inicio)
Capa 3: state file resiliente    ← B3 (backup + rebuild)
Capa 4: watchdog systemd         ← B5 (notify socket)
Capa 5: ficha sbos-lifecycle     ← empaqueta todo como ficha BOS (P19)
```

### Capa 0 — systemd unit file para BOS

Crear `/etc/systemd/system/bos.service` con:

```ini
[Unit]
Description=SBOS IAM Daemon
After=network.target

[Service]
Type=notify
ExecStart=/opt/bos/bin/bos --config /etc/bos/bos.toml
ExecStop=/opt/bos/bin/bosctl shutdown
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
NotifyAccess=all
WatchdogSec=30

[Install]
WantedBy=multi-user.target
```

**Decisiones de diseño:**

- `Type=notify` → BOS debe llamar `sd_notify("READY=1")` al completar arranque
- `WatchdogSec=30` → BOS debe llamar `sd_notify("WATCHDOG=1")` cada 15s (mitad del intervalo)
- `ExecStop=bosctl shutdown` → delega el shutdown ordenado al CLI, que llama a la API interna de BOS
- `Restart=always` → systemd relanza BOS si crashea, incluso si terminó con exit 0

### Capa 1 — Shutdown ordenado (saga shutdown)

Modificar `shutdown()` en `main.go:988`:

```
Al recibir SIGTERM (systemd stop bos.service):
  1. Marcar estado cluster como "draining" en state file
  2. Ejecutar saga shutdown:
     a. kubectl drain --ignore-daemonsets --delete-emptydir-data (timeout 60s)
     b. systemctl stop kubelet (vía SystemctlCmd helper)
     c. systemctl stop containerd
  3. Persistir estado final: todas las fichas a estado "stopped"
  4. Detener subsistemas internos (API, health checker, reconcile scheduler)
  5. sd_notify("STOPPING=1")
  6. os.Exit(0)
```

**Archivos a modificar:**

| Archivo | Cambio |
|---|---|
| `src/cmd/bos/main.go` | Reescribir `shutdown()` con las 6 fases |
| `src/internal/installer/saga.go` | Agregar `Shutdown()` saga command |
| `src/internal/installer/compensator.go` | Agregar chain `shutdown` |

**Nuevo comando saga:**

```go
// En saga.go
func (o *Orchestrator) Shutdown() error {
    // Implementa la secuencia: drain → stop kubelet → stop containerd
}
```

### Capa 2 — Arranque con reconciliación inmediata

Modificar `runNormal()` en `main.go:450`:

```
Antes del event loop principal:
  1. Leer state file → st.Read()
  2. Si fichas K8s están INSTALADA -- OK:
     a. Verificar kubelet corriendo: SystemctlCmd("is-active", "kubelet")
     b. Si kubelet NO corre → ReconcileNow() + repair del cluster
     c. Si kubelet corre → ejecutar CheckNow() para verificar pods
  3. Si hay divergencia entre estado esperado y real → repair asíncrono
  4. sd_notify("READY=1\nSTATUS=BOS daemon running")
```

**Archivos a modificar:**

| Archivo | Cambio |
|---|---|
| `src/cmd/bos/main.go` | Insertar bloque pre-event-loop en `runNormal()` |

### Capa 3 — State file resiliente

Modificar `manager.go`:

```
En NewManager():
  1. Si state file existe pero Read() falla:
     a. Intentar cargar .sbos_state.json.bak
     b. Si .bak también falla → rebuild desde plugin loader
  2. Rebuild: Scan() de plugins → Register() de cada ficha → writeState()

En writeState():
  1. Escribir a .sbos_state.json.tmp
  2. fsync(.tmp)
  3. rename(.tmp → .sbos_state.json)  // atómico
  4. cp .sbos_state.json → .sbos_state.json.bak
```

**Archivos a modificar:**

| Archivo | Cambio |
|---|---|
| `src/internal/state/manager.go` | `NewManager()` con fallback a backup, `writeState()` con write-rename |

### Capa 4 — Watchdog systemd

```
En main.go:
  1. Detectar NOTIFY_SOCKET del entorno (systemd lo exporta)
  2. Función sd_notify(state string) que escribe al socket Unix
  3. Al iniciar runNormal(): sd_notify("READY=1\nSTATUS=BOS daemon running")
  4. Goroutine separada: cada WatchdogSec/2 segundos → sd_notify("WATCHDOG=1")
  5. En shutdown(): sd_notify("STOPPING=1")
```

**Implementación simplificada (sin dependencia libsystemd):**

```go
func sdNotify(state string) error {
    socketPath := os.Getenv("NOTIFY_SOCKET")
    if socketPath == "" {
        return nil // no systemd, no-op
    }
    addr := &net.UnixAddr{Name: socketPath, Net: "unixgram"}
    conn, err := net.DialUnix("unixgram", nil, addr)
    if err != nil {
        return err
    }
    defer conn.Close()
    _, err = conn.Write([]byte(state))
    return err
}
```

**Archivos a modificar:**

| Archivo | Cambio |
|---|---|
| `src/cmd/bos/main.go` | Agregar `sdNotify()`, goroutine watchdog, llamadas en startup/shutdown |

### Capa 5 — Ficha `sbos-lifecycle`

Crear ficha BOS estándar siguiendo P19:

```
staging/core/servers/hostserver/sbos-lifecycle/
  manifest.yml       ← metadata, dependencia de sbos-bootstrap-os
  task_catalog.sh    ← instalar bos.service, systemctl enable
  yaml_engine.yml    ← timeouts y configuración
```

**manifest.yml:**

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
```

**task_catalog.sh:**

```bash
# Funciones del catálogo de tareas
install_generic() {
    # 1. Copiar bos.service a /etc/systemd/system/
    # 2. systemctl daemon-reload
    # 3. systemctl enable bos.service
    # 4. systemctl start bos.service (BOS ya está corriendo, esto es para el próximo boot)
}
```

---

## 4. Comandos de verificación por capa

### Capa 0: systemd unit

```bash
# Verificar que el unit file existe
cat /etc/systemd/system/bos.service

# Recargar systemd y arrancar
sudo systemctl daemon-reload
sudo systemctl enable bos.service
sudo systemctl start bos.service

# Verificar estado
systemctl status bos.service
# Debe mostrar: Active: active (running)

# Ver logs en journal
journalctl -u bos.service -f
```

### Capa 1: shutdown ordenado

```bash
# Parar BOS vía systemd
sudo systemctl stop bos.service

# Verificar que NO queden procesos K8s huérfanos
ps aux | grep -E 'kubelet|containerd|kube-apiserver|etcd'
# Debe retornar vacío

# Verificar que BOS escribió estado final
cat /etc/bos/.sbos_state.json | python3 -m json.tool | grep -E 'state|draining'
```

### Capa 2: arranque con reconciliación

```bash
# Arrancar de nuevo
sudo systemctl start bos.service

# Esperar reconciliación inicial
sleep 15

# Verificar que K8s vuelve automáticamente
kubectl get nodes
# Debe mostrar: Ready

kubectl get pods -A
# Todos los pods del plano de control: Running

# Verificar que el reconcile scheduler corrió al arranque
journalctl -u bos.service | grep -i 'reconcile\|drift'
```

### Capa 3: state file resiliente

```bash
# Simular corrupción del state file
echo "corrupt_data" > /etc/bos/.sbos_state.json

# Reiniciar BOS
sudo systemctl restart bos.service

# Verificar que se reconstruyó
cat /etc/bos/.sbos_state.json | python3 -m json.tool
# Debe ser JSON válido con estructura completa

# Verificar que existe backup
ls -la /etc/bos/.sbos_state.json.bak
# Debe existir

# Verificar que no hubo Fatal
journalctl -u bos.service | grep -i 'rebuild\|recover\|fatal'
```

### Capa 4: watchdog

```bash
# Verificar que BOS responde al watchdog
sudo journalctl -u bos.service | grep -i watchdog

# Verificar que systemd no mató BOS por watchdog timeout
sudo journalctl -u bos.service | grep -i 'watchdog timeout\|hardware watchdog'
# No debe haber entradas

# Forzar un hang de BOS para probar watchdog (solo en staging)
# kill -STOP $(cat /run/bos/bos.pid)
# Esperar WatchdogSec (30s)
# systemctl status bos.service
# Debe mostrar que systemd lo mató y relanzó
```

### Capa 5: ficha sbos-lifecycle

```bash
# Verificar estado de la ficha
bosctl status sbos-lifecycle
# Debe mostrar: INSTALADA -- OK, HEALTHY

# Verificar health check
bosctl health sbos-lifecycle
# Debe mostrar: HEALTHY (systemctl is-active bos.service → exit 0)

# Verificar que el unit file fue instalado por la ficha
cat /etc/systemd/system/bos.service | head -20
```

---

## 5. Orden de implementación y dependencias

```
Capa 0 ──► Capa 1 ──► Capa 2 ──► Capa 3 ──► Capa 4 ──► Capa 5
   │          │          │          │          │          │
   │          │          │          │          │          └── ficha BOS que empaqueta todo
   │          │          │          │          └── requiere notify socket de systemd
   │          │          │          └── requiere state manager modificado
   │          │          └── requiere saga shutdown para repair post-reboot
   │          └── requiere saga shutdown implementada
   └── sin dependencias, es solo un archivo .service
```

Las capas 0 y 1 son las de mayor impacto y deben implementarse primero.
La capa 5 es la formalización como ficha BOS y depende de todas las anteriores.

---

## 6. Archivos del repositorio referenciados

| Archivo | Líneas | Rol |
|---|---|---|
| `src/cmd/bos/main.go` | 1121 | Entrypoint, signal handling, shutdown, observer loop |
| `src/internal/reconcile/scheduler.go` | 232 | Reconciliación periódica, detección de drift |
| `src/internal/state/manager.go` | 364 | Máquina de estados, persistencia en disco |
| `src/internal/health/checker.go` | 307 | Health checks de fichas |
| `src/internal/installer/saga.go` | 326 | Saga orchestrator (install/update/repair/remove) |
| `src/internal/installer/compensator.go` | 135 | Compensación en fallo de saga |
| `src/internal/plugin/loader.go` | 326 | Carga de fichas desde disco |
| `src/internal/config/config.go` | 303 | Configuración desde bos.toml + bos-install.toml |
| `src/internal/server/api.go` | ~200 | API REST |
| `src/internal/server/ws.go` | ~150 | WebSocket hub |
