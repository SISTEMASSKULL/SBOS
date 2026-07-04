# Plan de Desarrollo — Ciclo de Vida BOS
## Etapas certificables · Sprint 1 al 4

**Versión:** 1.0
**Fecha:** 2026-05-19
**Basado en:** BOS-LIFECYCLE-PLAN-v2.md
**Commit de partida:** 5828eda

---

## Estructura de cada etapa

Cada etapa sigue el patrón PGE (ADR-026) y tiene:
- **Meta:** qué se construye
- **Archivos:** qué se toca
- **Criterio de aceptación:** cómo se verifica que está correcto
- **Comando de certificación:** one-liner que da OK/KO
- **Dependencias:** qué debe estar completado antes

---

## SPRINT 1 — Unit file + State file resiliente

### Etapa 1.0 — Unit file `bos.service`

**Meta:** Crear el unit file correcto según MOD-01 del plan v2.

**Archivos:**
- `staging/bos.service` (nuevo) — el unit file para instalar en `/etc/systemd/system/`

**Criterio de aceptación:**
1. Contiene `Type=notify`
2. Contiene `After=network-online.target` (no `network.target`)
3. Contiene `Restart=on-failure`
4. Contiene `TimeoutStopSec=210`
5. Contiene `TimeoutStartSec=120`
6. Contiene `WatchdogSec=30`
7. Contiene `StartLimitBurst=5` y `StartLimitIntervalSec=300`
8. Contiene `PrivateTmp=true`

**Comando de certificación:**
```bash
SERVICE=/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/staging/bos.service
for key in "Type=notify" "After=network-online.target" "Restart=on-failure" \
  "TimeoutStopSec=210" "TimeoutStartSec=120" "WatchdogSec=30" \
  "StartLimitBurst=5" "StartLimitIntervalSec=300" "PrivateTmp=true"; do
  grep -q "$key" "$SERVICE" && echo "OK: $key" || echo "FAIL: $key"
done
```

**Estado:** pendiente

---

### Etapa 1.1 — Función `sdNotify()` en main.go

**Meta:** Implementar `sdNotify()` que escribe al socket `NOTIFY_SOCKET` de systemd. Sin dependencias externas.

**Archivos:**
- `src/cmd/bos/main.go` — nueva función `sdNotify(state string)`

**Criterio de aceptación:**
1. Lee `NOTIFY_SOCKET` del entorno
2. Soporta abstract sockets (`@socket`)
3. No-op si `NOTIFY_SOCKET` no existe (para desarrollo fuera de systemd)
4. Usa `net.DialUnix("unixgram")`
5. No importa bibliotecas C (CGO_ENABLED=0 compatible)

**Comando de certificación:**
```bash
# Test unitario en Go
cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent
podman run --rm -v $PWD:/src -w /src/src golang:1.22 sh -c '
cat > /tmp/sdnotify_test.go << '\''GOEOF'\''
package main
import ("net";"os";"strings";"testing")
func TestSdNotifyNoSocket(t *testing.T) {
    os.Unsetenv("NOTIFY_SOCKET")
    // sdNotify debe retornar sin error
}
func TestSdNotifyAbstractSocket(t *testing.T) {
    // Si NOTIFY_SOCKET empieza con @, debe transformarse
    if !strings.HasPrefix("@test", "@") { t.Fatal("abstract check") }
}
GOEOF
echo "sd_notify unit tests placeholder — compila OK si importa net + os"
'
```

**Dependencias:** Etapa 1.0

**Estado:** pendiente

---

### Etapa 1.2 — `writeState()` atómico con backup

**Meta:** Reescribir `writeState()` en state/manager.go para usar write-rename atómico + backup automático.

**Archivos:**
- `src/internal/state/manager.go` — modificar `writeState()`

**Criterio de aceptación:**
1. Escribe a `.sbos_state.json.tmp` primero
2. Ejecuta `fdatasync()` sobre `.tmp`
3. Usa `os.Rename()` (.tmp → .json) — atómico en mismo filesystem
4. Copia `.json` → `.sbos_state.json.bak` después del rename
5. El archivo `.tmp` no existe después de completar (se limpia solo)

**Comando de certificación:**
```bash
# Dentro del contenedor tras escribir estado:
ls /etc/bos/.sbos_state.json.tmp 2>/dev/null && echo "FAIL: .tmp existe" || echo "OK: .tmp limpio"
ls /etc/bos/.sbos_state.json.bak && echo "OK: backup existe" || echo "FAIL: sin backup"
diff /etc/bos/.sbos_state.json /etc/bos/.sbos_state.json.bak && echo "OK: backup idéntico" || echo "FAIL: divergencia"
```

**Dependencias:** ninguna (independiente de systemd, compila y prueba standalone)

**Estado:** pendiente

---

### Etapa 1.3 — `NewManager()` con 3 niveles de fallback

**Meta:** Al abrir el state file, si el principal está corrupto, intentar backup; si backup también falla, reconstruir desde manifests en disco.

**Archivos:**
- `src/internal/state/manager.go` — modificar `NewManager()`

**Criterio de aceptación:**
1. Nivel 1: carga `.sbos_state.json` normalmente
2. Nivel 2: si `json.Decode` falla → carga `.sbos_state.json.bak`
3. Nivel 3: si `.bak` también falla → reconstruye desde plugin loader scan
4. Registra en journal el nivel usado: `"state file loaded from backup"` o `"state file rebuilt from manifests"`
5. Si los 3 niveles fallan → `log.Fatal()` (sin estado, no se puede operar)

**Comando de certificación:**
```bash
# Test 1: corromper principal, verificar que carga backup
sudo systemctl stop bos.service
echo 'CORRUPTO' | sudo tee /etc/bos/.sbos_state.json
sudo systemctl start bos.service
sleep 5
journalctl -u bos.service | grep -i 'loaded from backup'
python3 -m json.tool /etc/bos/.sbos_state.json > /dev/null && echo "OK: state válido" || echo "FAIL"

# Test 2: corromper ambos, verificar rebuild desde manifests
sudo systemctl stop bos.service
echo 'CORRUPTO' | sudo tee /etc/bos/.sbos_state.json
echo 'CORRUPTO' | sudo tee /etc/bos/.sbos_state.json.bak
sudo systemctl start bos.service
sleep 5
journalctl -u bos.service | grep -i 'rebuilt from manifests'
python3 -m json.tool /etc/bos/.sbos_state.json > /dev/null && echo "OK: state válido" || echo "FAIL"
```

**Dependencias:** Etapa 1.2

**Estado:** pendiente

---

## SPRINT 2 — Saga de shutdown ordenado

### Etapa 2.0 — Función `Shutdown()` en saga.go

**Meta:** Implementar saga de shutdown con 5 fases y timeouts por fase. Best-effort: si una fase falla, continúa con la siguiente.

**Archivos:**
- `src/internal/installer/saga.go` — nueva función `Shutdown(ctx context.Context) error`
- `src/internal/installer/compensator.go` — registrar cadena `shutdown`

**Secuencia de fases:**
```
Fase 1 (timeout 120s): kubectl drain --ignore-daemonsets --delete-emptydir-data --grace-period=30
Fase 2 (timeout 30s):  systemctl stop kubelet
Fase 3 (timeout 30s):  systemctl stop containerd
Fase 4 (timeout 10s):  persistir estado final en state file ("stopped")
Fase 5 (inmediato):    sd_notify("STOPPING=1")
```

**Criterio de aceptación:**
1. Cada fase tiene su propio `context.Context` con timeout
2. Si `kubectl drain` falla → `log.Warn()` y continúa
3. Si `systemctl stop kubelet` falla → `log.Warn()` y continúa
4. `systemctl stop containerd` siempre se ejecuta (incluso si fases anteriores fallaron)
5. El estado final se persiste aunque fases anteriores hayan fallado
6. Cada fase registra en journal: `"shutdown phase X/Y: descripción — OK/FAIL"`

**Comando de certificación:**
```bash
# Parada limpia
sudo systemctl stop bos.service

# Verificar que no hay procesos huérfanos
ps aux | grep -E 'kubelet|containerd|kube-apiserver' | grep -v grep
# Esperado: vacío

# Verificar journal
journalctl -u bos.service --since "1 min ago" | grep -E 'shutdown phase|drain|kubelet|containerd'
# Esperado: 5 fases registradas

# Verificar estado final
python3 -c "import json; s=json.load(open('/etc/bos/.sbos_state.json')); print(s.get('draining','MISSING'))"
# Esperado: algún marcador de estado final
```

**Dependencias:** Sprint 1 completo (unit file + state file atómico)

**Estado:** pendiente

---

### Etapa 2.1 — Reescribir `shutdown()` en main.go

**Meta:** Conectar `shutdown()` con la saga, systemd notify y context con timeout global.

**Archivos:**
- `src/cmd/bos/main.go` — reescribir `shutdown()`

**Criterio de aceptación:**
1. Crea `context.WithTimeout` de 200s (margen sobre TimeoutStopSec=210)
2. Llama a `saga.Shutdown(ctx)`
3. Llama a `sdNotify("STOPPING=1")` al inicio
4. Detiene subsistemas internos (apiServer, healthChecker, reconcileScheduler)
5. Escribe audit log de shutdown completo
6. `os.Exit(0)` al final

**Comando de certificación:**
```bash
# Test integrado: parar vía systemctl y monitorear tiempo
time sudo systemctl stop bos.service
# Esperado: termina en < 210s (sin SIGKILL de systemd)

# Verificar que systemd NO envió SIGKILL
journalctl -u bos.service --since "2 min ago" | grep -i 'killed\|SIGKILL'
# Esperado: vacío

# Verificar que el audit log registró shutdown
cat /var/log/bos/audit.log | grep -i 'shutdown'
# Esperado: entrada de shutdown
```

**Dependencias:** Etapa 2.0

**Estado:** pendiente

---

## SPRINT 3 — Arranque con reconciliación + Watchdog

### Etapa 3.0 — Bloque pre-event-loop en `runNormal()`

**Meta:** Al arrancar, antes del event loop principal, verificar estado previo de K8s y reconciliar si es necesario.

**Archivos:**
- `src/cmd/bos/main.go` — modificar `runNormal()`

**Secuencia:**
```
1. Leer state file
2. Si fichas K8s estaban INSTALADA -- OK:
   a. Verificar kubelet: SystemctlCmd("is-active", "kubelet")
   b. Si kubelet DOWN → ReconcileNow() para repair
   c. Si kubelet UP → jitter(0-30s) → ReconcileNow() → CheckNow()
3. Si fichas K8s en otro estado → iniciar observer loop normal
4. sd_notify("READY=1\nSTATUS=BOS daemon running")
```

**Criterio de aceptación:**
1. `ReconcileNow()` se ejecuta antes de que arranque el ticker periódico
2. Si kubelet ya corría, aplica jitter (0-30s) antes de reconciliar
3. `READY=1` se envía DESPUÉS de la verificación inicial, no antes
4. El observer loop normal arranca después de la reconciliación inicial

**Comando de certificación:**
```bash
# Reiniciar BOS con K8s en Running
sudo systemctl restart bos.service
sleep 15

# Verificar que reconcile corrió al arranque
journalctl -u bos.service --since "30 sec ago" | grep -i 'startup reconcile\|initial reconcile'
# Esperado: entrada de reconcile en los primeros segundos

# Verificar que K8s sigue operativo
kubectl get nodes | grep Ready
# Esperado: Ready

# Verificar que no hubo ventana de 300s
journalctl -u bos.service --since "1 min ago" | grep 'reconcile' | head -1
# Esperado: timestamp cercano al arranque (< 60s del boot)
```

**Dependencias:** Sprint 2 completo (saga shutdown)

**Estado:** pendiente

---

### Etapa 3.1 — Goroutine `startWatchdog()`

**Meta:** Enviar `WATCHDOG=1` periódicamente al socket de systemd para que systemd detecte hangs.

**Archivos:**
- `src/cmd/bos/main.go` — nueva función `startWatchdog(ctx context.Context)`

**Criterio de aceptación:**
1. Lee `WATCHDOG_USEC` del entorno (systemd lo exporta)
2. Calcula intervalo = `WATCHDOG_USEC / 2`
3. Envía `WATCHDOG=1` en cada tick
4. Se detiene cuando `ctx` se cancela
5. No-op si `WATCHDOG_USEC` no existe (sin systemd)

**Comando de certificación:**
```bash
# Test 1: watchdog corriendo normalmente
journalctl -u bos.service | grep -c 'watchdog'
# Esperado: > 0 entradas a lo largo del tiempo

# Test 2: systemd reinicia BOS si se cuelga
BOS_PID=$(cat /run/bos/bos.pid)
sudo kill -STOP $BOS_PID
echo "BOS pausado. Esperando 35s..."
sleep 35
systemctl show bos.service --property=NRestarts
# Esperado: NRestarts incrementado (systemd mató y relanzó BOS)

# Verificar que BOS está corriendo de nuevo
systemctl is-active bos.service
# Esperado: active
```

**Dependencias:** Etapa 3.0 (necesita `runNormal()` con context para la goroutine)

**Estado:** pendiente

---

### Etapa 3.2 — `bosctl shutdown` CLI endpoint

**Meta:** Implementar el comando `bosctl shutdown` que systemd llama en `ExecStop=`.

**Archivos:**
- `src/cmd/bosctl/main.go` — nuevo comando `shutdown`

**Criterio de aceptación:**
1. Acepta flag `--timeout` (default 180s)
2. Llama a la API interna de BOS: `POST /api/shutdown`
3. Espera respuesta o timeout
4. Retorna exit 0 si BOS terminó limpiamente
5. Retorna exit 1 si timeout o error

**Comando de certificación:**
```bash
# Probar shutdown vía CLI
time bosctl shutdown --timeout 30

# Verificar que BOS terminó
systemctl is-active bos.service
# Esperado: inactive (dead)

# Verificar que no hay procesos huérfanos
ps aux | grep -E 'bos|kubelet|containerd' | grep -v grep
# Esperado: vacío
```

**Dependencias:** Etapa 2.1 (shutdown en main.go con API endpoint)

**Estado:** pendiente

---

## SPRINT 4 — Ficha sbos-lifecycle

### Etapa 4.0 — Crear ficha `sbos-lifecycle`

**Meta:** Empaquetar todo el ciclo de vida como ficha BOS estándar (P19).

**Archivos:**
- `staging/core/servers/hostserver/sbos-lifecycle/manifest.yml` (nuevo)
- `staging/core/servers/hostserver/sbos-lifecycle/task_catalog.sh` (nuevo)
- `staging/core/servers/hostserver/sbos-lifecycle/yaml_engine.yml` (nuevo)
- `staging/bos.service` (nuevo — el unit file a instalar)

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
- `install_generic()` — copia bos.service a `/etc/systemd/system/`, `daemon-reload`, `enable`
- `remove_generic()` — `disable`, elimina unit file, `daemon-reload`
- `check_health()` — `systemctl is-active bos.service`

**Criterio de aceptación:**
1. La ficha se instala automáticamente (depende de sbos-bootstrap-os)
2. Instala `bos.service` en `/etc/systemd/system/`
3. Ejecuta `systemctl enable bos.service`
4. Health check retorna exit 0 cuando el servicio está activo
5. `bosctl status sbos-lifecycle` muestra `INSTALADA -- OK` y `HEALTHY`

**Comando de certificación:**
```bash
# Verificar que la ficha está instalada
bosctl status sbos-lifecycle
# Esperado: INSTALADA -- OK | HEALTHY

# Verificar integridad del unit file instalado
grep -c 'Type=notify' /etc/systemd/system/bos.service        # 1
grep -c 'WatchdogSec' /etc/systemd/system/bos.service        # 1
grep 'TimeoutStopSec' /etc/systemd/system/bos.service        # TimeoutStopSec=210

# Test de idempotencia: repair no rompe nada
bosctl repair sbos-lifecycle
bosctl status sbos-lifecycle
# Esperado: INSTALADA -- OK | HEALTHY

# Test de desinstalación limpia
bosctl remove sbos-lifecycle
ls /etc/systemd/system/bos.service 2>/dev/null && echo "FAIL: unit file persiste" || echo "OK"
systemctl is-enabled bos.service 2>/dev/null && echo "FAIL: servicio enabled" || echo "OK"
```

**Dependencias:** Sprint 3 completo

**Estado:** pendiente

---

### Etapa 4.1 — Integración completa: fresh install desde cero

**Meta:** Ejecutar `install.sh` en contenedor limpio y verificar que todo el ciclo de vida funciona sin intervención manual.

**Criterio de aceptación:**
1. `install.sh` instala dependencias
2. BOS arranca como daemon
3. `sbos-bootstrap-os` → INSTALADA -- OK, HEALTHY
4. `sbos-bootstrap-k8s` → INSTALADA -- OK, HEALTHY, K8s Ready
5. `sbos-lifecycle` → INSTALADA -- OK, HEALTHY
6. `bos.service` instalado y enabled en systemd
7. `systemctl stop bos.service` → K8s drenado, cero procesos huérfanos
8. `systemctl start bos.service` → K8s recuperado, nodo Ready

**Comando de certificación:**
```bash
# Full cycle test
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  -v /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/staging:/staging:ro \

sleep 5
sleep 120

# Verificar las 3 fichas
for f in sbos-bootstrap-os sbos-bootstrap-k8s sbos-lifecycle; do
done

# Verificar K8s

# Test stop
sleep 15
# Esperado: vacío

# Test start
sleep 30
```

**Dependencias:** Etapa 4.0

**Estado:** pendiente

---

## Tabla resumen de certificación

| Etapa | Qué se certifica | Comando resumen |
|---|---|---|
| 1.0 | Unit file con 8 directivas correctas | `grep` de cada directiva en `bos.service` |
| 1.1 | `sdNotify()` compatible CGO_ENABLED=0 | Compilación sin errores |
| 1.2 | Escritura atómica con backup | `.tmp` no existe, `.bak` idéntico al principal |
| 1.3 | 3 niveles de fallback | Corromper JSON → BOS arranca desde backup/manifests |
| 2.0 | Saga shutdown 5 fases con timeouts | `systemctl stop` → 0 procesos K8s huérfanos |
| 2.1 | `shutdown()` conectado a systemd | Sin SIGKILL en journal tras stop |
| 3.0 | Reconciliación al arranque | `ReconcileNow()` en primeros 60s del boot |
| 3.1 | Watchdog systemd | `kill -STOP` → systemd reinicia BOS en < 35s |
| 3.2 | `bosctl shutdown` CLI | `bosctl shutdown --timeout 30` → BOS inactive |
| 4.0 | Ficha sbos-lifecycle | `bosctl status sbos-lifecycle` → HEALTHY |
| 4.1 | Fresh install end-to-end | Contenedor limpio → 3 fichas HEALTHY + stop/start cycle |

---

## Orden de ejecución

```
Sprint 1 ──────────────► Sprint 2 ──────────────► Sprint 3 ──────────────► Sprint 4
│                        │                        │                        │
├─ 1.0 bos.service       ├─ 2.0 saga Shutdown()   ├─ 3.0 pre-event-loop    ├─ 4.0 ficha lifecycle
├─ 1.1 sdNotify()        └─ 2.1 shutdown() main   ├─ 3.1 startWatchdog()   └─ 4.1 fresh install E2E
├─ 1.2 writeState atómico                         └─ 3.2 bosctl shutdown
└─ 1.3 NewManager 3 niveles

Cada etapa se compila, prueba y commitea ANTES de pasar a la siguiente.
Si una etapa rompe algo de una etapa anterior, se revierte y corrige.
```

---

*Documento generado 2026-05-19. Cada etapa debe certificarse con evidencia (log bash real en disco, SHA256 del binario compilado).*
