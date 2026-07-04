# MANIFIESTO DE DESARROLLO — BOS DAEMON
## SBOS Infrastructure Provisioning & Lifecycle Orchestrator

**Fecha:** 2026-06-12  
**VPS de staging:** `root@13.140.128.230` — clave `~/agente_key`  
**Estado del proyecto al iniciar este manifiesto:**  
- TUI completa: 23 pantallas en subpaquetes k8s/ sistema/ panel/  
- Flujo instalador → dashboard → shutdown/reboot funcional  
- Deploy pipeline: build.sh + install.sh → bos-console.service  
- Daemon bos: state machine 18 estados, JSON-RPC 15 métodos, observer de fichas  
- **Brecha principal: todas las pantallas del ctrl panel muestran datos mock**

---

## LOS DOS PILARES DEL DESARROLLO

```
PILAR 1 — EL TUI ES EL VISOR DE LA SOLUCIÓN
  Cada pantalla del ctrl panel muestra el estado real del servidor.
  Si el dashboard está vivo y correcto, el SBOS está correcto.
  El TUI no es decoración: es el instrumento de verificación.

PILAR 2 — EL VPS ES EL LABORATORIO DE CERTIFICACIÓN
  Toda función se certifica en el servidor real, no en tests simulados.
  El VPS puede reinstalarse en cualquier momento para comenzar en limpio.
  Cada fase del REGISTRO-ESTADO se certifica única y exclusivamente
  mediante pruebas reales en el VPS.
```

**Relación con REGISTRO-ESTADO.md:**
Este manifiesto define LAS FASES M1-M7 que conectan el daemon con el TUI.
El REGISTRO-ESTADO define LOS ÁTOMOS F11-F17 que construyen el daemon.
Ambos son necesarios. Un átomo del REGISTRO solo se marca ✅ cuando
la prueba real en el VPS pasa Y la pantalla correspondiente del TUI lo muestra.

---

## PRINCIPIOS RECTORES

> **El TUI es el criterio de aceptación de cada fase.**
> Una funcionalidad no existe hasta que se ve en pantalla con datos reales.
> Las pruebas son reales: syscalls, procesos reales, K8s real, sin stubs.

Cada feature tiene cuatro partes obligatorias:

```
1. DAEMON  — implementar la funcionalidad real en el daemon bos
2. WIRE    — conectar daemon → TUI vía WebSocket tick messages
3. PRUEBA  — verificar en el VPS con prueba adversarial real
4. CERTIF  — marcar el átomo ✅ en REGISTRO-ESTADO + pantalla TUI muestra datos reales
```

Si el TUI sigue mostrando datos mock después de una fase, la fase no está completa.
Si el átomo está ✅ pero el TUI no lo muestra, hay un bug de integración pendiente.

---

## EL VPS COMO LABORATORIO

### Características del entorno
```
Servidor:  13.140.128.230 (Ubuntu Server)
Acceso:    ssh -i ~/agente_key root@13.140.128.230
Estado:    Limpio — sin K8s, sin bos instalado
Reset:     Se puede reinstalar en cualquier momento para prueba en limpio
Objetivo:  Llegar a un servidor perfecto y completamente funcional
```

### Protocolo de reset
El VPS puede y debe resetearse cuantas veces sea necesario.
Un reset es una victoria, no una derrota — significa que encontramos
un error antes de que llegara a producción.

```bash
# Reset completo — comienza desde cero
# (reinstalar el OS desde el panel del proveedor si es necesario)
# Luego desplegar:
bash build.sh
scp staging/sbos-bootstrap.zip root@13.140.128.230:/tmp/
ssh root@13.140.128.230 "cd /tmp && unzip -o sbos-bootstrap.zip -d sbos && cd sbos && bash install.sh"
```

### Ciclo de desarrollo en el VPS
```
Código nuevo
     ↓
bash build.sh  (compila + empaqueta)
     ↓
scp + deploy al VPS
     ↓
Prueba adversarial específica de la fase
     ↓
¿TUI muestra datos correctos?
  NO → corregir código → volver a build
  SÍ → marcar átomo ✅ en REGISTRO-ESTADO → siguiente átomo
```

### Criterio de "servidor perfecto"
El VPS está certificado cuando:
1. `bosctl setup` → wizard → instalación completa sin errores
2. Reboot → dashboard aparece automáticamente en consola
3. Todas las 23 pantallas del ctrl panel muestran datos reales del servidor
4. Apagar desde el dashboard → servidor se apaga
5. Encender → dashboard aparece solo
6. `bosctl bootstrap verify --full` → 14/14 criterios ✓ (F17.9)

---

## ESTADO ACTUAL — LO QUE YA EXISTE Y FUNCIONA

| Componente | Estado | Notas |
|-----------|--------|-------|
| TUI — 23 pantallas ctrl panel | ✅ Completo | k8s/ sistema/ panel/ — datos mock |
| TUI — Wizard instalación (4 pasos) | ✅ Completo | Datos mock, no ejecuta nada real aún |
| TUI — ScreenInstalling con progreso | ✅ Completo | Animado, conectado a WS, falta datos reales |
| TUI — ScreenBoot / ScreenDashboard | ✅ Completo | |
| TUI — Shutdown/Reboot real | ✅ Completo | sudo systemctl poweroff/reboot |
| bos-console.service (auto-arranque) | ✅ Completo | Restart=always en tty1 |
| install.sh + build.sh | ✅ Completo | Deploy desde cero en un comando |
| State machine 18 estados | ✅ Completo | internal/state/manager.go |
| JSON-RPC 15+ métodos | ✅ Completo | bos.ficha.*, bos.bootstrap.*, bos.ctx.* |
| Observer de fichas | ✅ Completo | Reacciona a estados del state manager |
| 66 test files | ✅ Completo | Race-free, build verde |
| **Observer de sistema real** | ❌ Falta | /proc, systemd, K8s API → TUI |
| **Bootstrap K8s real** | ❌ Falta | k3s + fichas críticas ejecutadas de verdad |
| **Datos reales en ctrl panel** | ❌ Falta | Todas las 23 pantallas usan mock |
| **Reconciler activo** | ❌ Falta | Detecta drift pero no repara en producción |

---

## ARQUITECTURA DE DATOS: DAEMON → TUI

El canal de datos entre el daemon y el TUI es el Unix socket `/run/bos/bos.sock`.
El flujo es:

```
Sistema real                  Daemon bos                    TUI (bosctl setup)
─────────────                 ──────────                    ──────────────────
/proc/stat         →  observer.SystemReader    →  WebSocket tick  →  DashModel.CPU
K8s API            →  observer.K8sReader       →  WebSocket tick  →  DashModel.Nodes
systemd D-Bus      →  observer.SystemdReader   →  WebSocket tick  →  DashModel.Services
state.json         →  state.Manager            →  WebSocket tick  →  DashModel.Jobs
health.checker     →  health.Checker           →  WebSocket tick  →  DashModel.Alerts
journal            →  journal.Tail             →  WebSocket tick  →  DashModel.Logs
```

**Tipo de mensaje WebSocket** (ya existe en internal/wslib/):
```go
// Msg de actualización de métricas — el daemon lo emite cada N segundos
type DashboardTickMsg struct {
    CPU      CPUSnapshot
    Mem      MemSnapshot
    Nodes    []NodeSnapshot
    Pods     []PodSnapshot
    Services []ServiceSnapshot
    Jobs     []JobSnapshot
    Alerts   []AlertSnapshot
    Logs     []LogLine
}
```

El `DashModel` del TUI (ctrl/dash/model.go) se actualiza con estos valores.
`loadMock()` se desactiva cuando el daemon está conectado.

---

## FASES DE DESARROLLO

### M1 — Observer de Sistema Operativo Real
**Objetivo:** Las 6 pantallas del grupo Sistema OS muestran datos reales del servidor.  
**Pantallas que se activan:** Métricas, Procesos, Systemd, Red, Disco, Kernel

#### M1.1 — Lector de /proc (CPU, RAM, Swap, I/O)
```
Implementar: internal/observer/system_reader.go
  - /proc/stat                → CPUInfo (cores, uso%, iowait, steal)
  - /proc/meminfo             → MemInfo (total, used, free, swap)
  - /proc/diskstats           → I/O read/write bytes/s
  - Intervalo: 2 segundos

Emitir: WebSocket msg tipo "system.metrics"
TUI: DashModel.CPU, DashModel.Mem ← valores reales

Prueba real:
  stress-ng --cpu 4 &
  → pantalla Métricas debe mostrar CPU elevado
  kill %1
  → CPU vuelve a basal en < 5s
```

#### M1.2 — Lector de Procesos
```
Implementar: internal/observer/process_reader.go
  - /proc/<pid>/stat + /proc/<pid>/cmdline → OSProcess
  - Top 20 por CPU%, filtrable por nombre
  - Intervalo: 3 segundos

Prueba real:
  sleep 999 &
  → aparece en pantalla Procesos
  kill %1
  → desaparece en < 6s
```

#### M1.3 — Lector de Systemd
```
Implementar: internal/observer/systemd_reader.go
  - exec: systemctl list-units --type=service --output=json
  - Service{name, active, sub, description}
  - Intervalo: 5 segundos

Prueba real:
  systemctl stop cron
  → aparece "cron.service  INACTIVE" en pantalla Systemd
  systemctl start cron
  → vuelve a ACTIVE en < 10s
```

#### M1.4 — Lector de Red y Discos
```
Implementar: internal/observer/net_reader.go + disk_reader.go
  - /proc/net/dev → NetworkInterface (TX/RX bytes/s)
  - /proc/net/tcp + /proc/net/tcp6 → TCPConn activas
  - lsblk -J → StorageDisk (modelo, tamaño, tipo)
  - df -h → uso% por punto de montaje
  - Intervalo: 5 segundos

Prueba real:
  curl http://ifconfig.me (genera tráfico)
  → pantalla Red muestra TX/RX elevado en la interfaz correcta
```

#### M1.5 — Lector de Kernel
```
Implementar: internal/observer/kernel_reader.go
  - uname -r → versión kernel
  - /proc/modules → KernelModule[] activos
  - lsmod → módulos cargados
  - /sys/kernel/security/lsm → LSM activos

Prueba real: datos estáticos — verificar que muestra versión real del kernel
```

---

### M2 — Bootstrap K8s Real
**Objetivo:** El wizard ejecuta realmente k3s, Calico y las fichas críticas.  
**Pantallas que se activan:** ScreenInstalling (barra de progreso real), ScreenInstallDone

#### M2.1 — Validación del wizard
```
Implementar: cmd/bosctl/ — validación real de los campos P1-P4
  - P1: hostname resolvible, FQDN válido
  - P2: contraseña mínimo 12 chars, confirmación coincide
  - P3: rangos IP CIDR válidos, sin solapamiento con interfaces actuales
  - P4: resumen con opción de corregir

Prueba real: introducir IP inválida → error en tiempo real sin salir del wizard
```

#### M2.2 — Capa 0: preparación del host
```
Implementar: internal/bootstrap/layer0.go (mejora del existente)
  - Deshabilitar swap: swapoff -a, comentar /etc/fstab
  - Configurar sysctl: ip_forward, bridge-nf-call-iptables
  - Instalar containerd
  - Crear usuario bosagent con permisos correctos
  - Verificación: cada paso reporta OK/FAIL al TUI vía WS

Prueba real: ejecutar en VPS limpio → todos los checks OK
```

#### M2.3 — Capa 1: k3s + Calico
```
Implementar: internal/bootstrap/layer1_k8s.go
  - Descargar e instalar k3s v1.32 (ADR-017)
  - Aplicar Calico operator v3.32.0
  - Esperar nodos Ready (kubectl wait)
  - Cada paso emite progreso al TUI

Prueba real:
  kubectl get nodes
  → debe mostrar el nodo Ready
  → pantalla K8s Control Plane muestra nodo real
```

#### M2.4 — Fichas críticas (Capas 2-4)
```
Orden de instalación (según SBOS-019):
  postgresql (100) → redis (110) → vault (130) → keycloak (140) → kong (160)

Cada ficha:
  - Lee manifest.yml del staging/core/servers/
  - Ejecuta task_catalog.sh en orden topológico
  - Reporta cada paso al TUI (nombre tarea + porcentaje)
  - Registra estado en .sbos_state.json
  - Verifica health después de instalar

Prueba real:
  kubectl get pods -A
  → ver postgresql-0, redis-0, keycloak-0, vault-0, kong corriendo
  → pantalla Jobs muestra todas las fichas en estado INSTALADA
```

---

### M3 — Observer K8s Real
**Objetivo:** Las 5 pantallas del grupo K8s muestran datos reales del cluster.  
**Pantallas que se activan:** ControlPlane, Workloads, Autoscaling, Network, Storage

#### M3.1 — Cliente K8s del daemon
```
Implementar: internal/k8s/ (mejora del existente)
  - Usa kubeconfig en /var/lib/bos/.kube/config
  - ServiceAccount bos-daemon con ClusterRole mínimo:
      get/list/watch: nodes, pods, deployments, services,
                      ingresses, pv, pvc, hpa, networkpolicies
  - Intervalo: 10 segundos

Prueba real:
  kubectl create deployment nginx --image=nginx --replicas=3
  → pantalla Workloads muestra nginx con 3 pods Running
  kubectl delete deployment nginx
  → desaparece en < 15s
```

#### M3.2 — Control Plane real
```
Implementar: internal/observer/k8s_cp_reader.go
  - kubectl get componentstatuses → etcd, controller-manager, scheduler
  - kubectl get nodes -o json → CPComp[] con CPU/RAM usados
  - Calico: kubectl get nodes -o jsonpath (CalicoNodeStatus)
  - Linkerd: kubectl get pods -n linkerd

Prueba real:
  pantalla ControlPlane debe mostrar:
    ✔ etcd OK  ✔ controller-manager OK  ✔ scheduler OK
    nodo con CPU/RAM real (no 0%)
```

#### M3.3 — Autoscaling, Network, Storage reales
```
Implementar: internal/observer/k8s_as_reader.go
                              k8s_net_reader.go
                              k8s_sto_reader.go
  - HPA: kubectl get hpa -A -o json
  - Services/Ingress: kubectl get svc,ing -A -o json
  - PV/PVC: kubectl get pv,pvc -A -o json
  - StorageClass: kubectl get storageclass -o json

Prueba real:
  kubectl apply -f hpa.yaml
  → pantalla Autoscaling muestra el HPA con réplicas actuales/máx
```

---

### M4 — Panel de Operaciones Real
**Objetivo:** Las 12 pantallas del grupo Panel muestran datos reales de operaciones.

#### M4.1 — Jobs: fichas en tiempo real
```
Implementar: state.Manager → WS → DashModel.Jobs
  - Leer .sbos_state.json cada 3 segundos
  - InstallJob por cada ficha: nombre, estado, porcentaje, tiempo
  - Estados: INSTALANDO (spinner), INSTALADA (✔), ERROR (✗), REPARANDO (↻)

Prueba real:
  bosctl install redis-extra
  → pantalla Jobs muestra redis-extra con barra de progreso en tiempo real
```

#### M4.2 — Alertas: health checker real
```
Implementar: internal/health/checker.go → WS → DashModel.Alerts
  Reglas de alerta reales:
  - PodCrashLoop: restarts > 5 en últimos 10 min
  - NodeHighCPU: CPU > 85% por > 2 min
  - HPAAtMax: replicas == maxReplicas por > 5 min
  - DiskHigh: uso > 85%
  - EtcdDBLarge: etcd DB > 6 GB
  - FichaError: cualquier ficha en ERROR_FISICO o ERROR_LOGICO
  - ServiceDown: ficha INSTALADA pero pod no Running

Prueba real:
  dd if=/dev/zero of=/tmp/bigfile bs=1M count=1000 (llena disco)
  → alerta DiskHigh aparece en pantalla Alertas con severity WARNING
  rm /tmp/bigfile
  → alerta se resuelve en < 30s
```

#### M4.3 — Logs: journal real
```
Implementar: internal/observer/journal_reader.go
  - journalctl -f --output=json --unit=bos.service
  - journalctl -f --output=json --unit=k3s.service
  - journalctl -f --output=json -p err (errores del sistema)
  - LogEntry{ts, level, service, msg}
  - Buffer: últimas 500 líneas

Prueba real:
  systemctl restart bos
  → pantalla Logs muestra las líneas de reinicio en tiempo real
```

#### M4.4 — Usuarios y Seguridad reales
```
Implementar: internal/observer/identity_reader.go
  - Keycloak Admin API → usuarios activos del realm sbos
  - /etc/passwd + last → UserSession[] con IP, tiempo
  - UFW: ufw status verbose → UFWRule[]
  - openssl verify → Certificate[] con fecha expiración
  
Prueba real:
  ufw deny 9999/tcp
  → pantalla Seguridad muestra la nueva regla UFW
```

#### M4.5 — Backups reales
```
Implementar: internal/observer/backup_reader.go
  - pgBackRest info --output=json → BackupJob[] con LastRun, Size
  - Redis BGSAVE + INFO persistence → último RDB snapshot
  - etcdctl snapshot status → tamaño, hash

Prueba real:
  pgbackrest --stanza=main backup
  → pantalla Backups muestra el job en RUNNING, luego OK con tamaño real
```

---

### M5 — Reconciler y Reparación Automática
**Objetivo:** BOS detecta drift y lo corrige sin intervención humana.

#### M5.1 — Detección de drift
```
Implementar: internal/reconcile/scheduler.go (ya existe — activar)
  Chequeos cada 60 segundos:
  - Ficha INSTALADA con pod no Running → DEGRADADA
  - Ficha INSTALADA con config distinta al manifest → ERROR_LOGICO
  - Ficha INSTALADA con nueva versión disponible → ACTUALIZACION_DISPONIBLE
  - Nodo con RAM > 90% por 5 min → alerta + sugerir scale

Prueba real:
  kubectl delete pod postgresql-0 --force
  → state machine detecta: INSTALADA → DEGRADADA en < 60s
  → pantalla Alertas muestra alerta, Jobs muestra reparación iniciada
  → K8s recrea el pod (ReplicaSet), state machine → INSTALADA de nuevo
```

#### M5.2 — Auto-reparación
```
Implementar: internal/repair/repair_manager.go (ya existe — activar)
  - DEGRADADA → ejecuta bos.ficha.repair saga
  - ERROR_LOGICO → ejecuta repair específico (config drift)
  - ERROR_FISICO → alerta HITL (no auto-repara hardware)
  - Timeout: 10 min → ERROR_NO_CORREGIBLE → alerta crítica en dashboard

Prueba real:
  systemctl stop postgresql  (simula caída)
  → BOS detecta DEGRADADA, ejecuta repair, reinicia servicio
  → Todo en pantalla Jobs + Alertas sin intervención manual
```

---

### M6 — Release Plane y Actualizaciones
**Objetivo:** BOS puede actualizarse a sí mismo y actualizar fichas de forma segura.

#### M6.1 — Cliente Release Plane
```
Implementar: internal/release/ (ya existe — completar)
  - Pull-only desde SKULL Release Server
  - Verificar firma Ed25519 de cada release
  - Canal: canary → early → stable (configurable en bos.toml)

Prueba real:
  publicar versión nueva en release server
  → pantalla Config muestra "Actualización disponible: v2.0.1"
  → ACTUALIZACION_DISPONIBLE en state machine
```

#### M6.2 — Actualización de fichas con rollback
```
Implementar: saga ACTUALIZAR con compensación completa
  - Backup del pod actual antes de actualizar
  - Actualizar imagen en manifest
  - Verificar health post-actualización
  - Si falla: rollback automático a versión anterior

Prueba real:
  bosctl upgrade postgresql
  → pantalla Jobs muestra saga ACTUALIZANDO con pasos en tiempo real
  → si falla: ROLLBACK visible en pantalla, versión anterior restaurada
```

---

### M7 — Multi-Tenant
**Objetivo:** El servidor puede alojar múltiples tenants aislados.

#### M7.1 — Alta de tenant
```
Implementar: bos.ctx.create saga real
  - Crear realm en Keycloak (Admin API)
  - Crear namespace en K8s
  - Crear base de datos dedicada (PostgreSQL)
  - Crear path en Vault (secrets del tenant)
  - Registrar en .sbos_state.json

Prueba real:
  bosctl tenant new --name acme --plan basic
  → kubectl get namespaces muestra: sbos-acme
  → Keycloak Admin muestra: realm acme creado
```

#### M7.2 — Vista del dashboard por tenant
```
Implementar: DashModel.TenantFilter string
  Todas las vistas K8s filtran por namespace del tenant activo
  Pantalla Config muestra: tenants activos, plan, uso de recursos

Prueba real:
  bosctl ctx switch acme
  → pantalla Workloads solo muestra pods del namespace sbos-acme
```

---

## PROTOCOLO DE PRUEBAS REALES

### Regla absoluta
**No existe prueba válida sin servidor real.** Los datos mock son solo para desarrollo
de pantallas. Desde M1 en adelante, todas las pruebas se ejecutan en el VPS
`root@13.140.128.230` (o el servidor de staging vigente).

### Entorno de pruebas
```bash
# Verificar que el entorno está limpio antes de cada fase
bash build.sh
scp staging/sbos-bootstrap.zip root@13.140.128.230:/tmp/
ssh root@13.140.128.230 "cd /tmp && unzip -o sbos-bootstrap.zip -d sbos && cd sbos && bash install.sh"
```

### DoD por fase (Definition of Done)
Cada fase M_X.Y está completa cuando:

```
1. go build ./...              — build verde
2. go vet ./...                — sin advertencias
3. gofmt -l . | wc -l → 0     — formato limpio
4. go test -race -count=10 ./... — tests pasan, sin race conditions
5. PANTALLA REAL               — la pantalla correspondiente en el dashboard
                                  muestra datos reales del servidor, no mock
6. PRUEBA ADVERSARIAL          — el escenario de prueba específico de la fase
                                  (ej: kill process → aparece en logs en < 5s)
```

### Tests reales vs tests de unidad
```
Tests de unidad (go test):
  — Lógica pura: state machine, saga compensación, parsing de /proc
  — Sin llamadas reales al OS o K8s
  — Deben pasar siempre, en cualquier máquina

Tests de integración (en servidor real):
  — Todo lo que involucre syscalls, procesos, K8s API, systemd
  — Se marcan con: //go:build integration
  — Se ejecutan: go test -tags integration -run TestXxx ./...
  — Solo en el VPS de staging
  — No corren en CI (aún)
```

---

## CONVENCIONES DE CÓDIGO

### Estructura de un observer reader
```go
// internal/observer/<nombre>_reader.go
package observer

type SystemReader struct {
    interval time.Duration
}

// Read lee el estado actual del sistema y retorna los datos.
// Función pura: no modifica estado, no tiene efectos secundarios.
func (r *SystemReader) Read() (CPUInfo, error) {
    // leer /proc/stat, calcular, retornar
}

// Start inicia el loop en background, emitiendo ticks por el canal.
func (r *SystemReader) Start(ctx context.Context, ch chan<- CPUInfo) {
    go func() {
        for {
            select {
            case <-ctx.Done(): return
            case <-time.After(r.interval):
                data, err := r.Read()
                if err == nil { ch <- data }
            }
        }
    }()
}
```

### Conexión reader → DashModel
```go
// En la goroutine del daemon que mantiene la conexión WS con bosctl:
func (s *Server) streamDashboard(conn *wslib.Conn) {
    cpuCh := make(chan CPUInfo, 1)
    s.cpuReader.Start(ctx, cpuCh)

    for {
        select {
        case cpu := <-cpuCh:
            conn.Send(DashTickMsg{CPU: cpu})
        // ...otros canales
        }
    }
}
```

### Desactivar mock cuando el daemon está conectado
```go
// internal/tui/ctrl/dash/model.go
func (dm *DashModel) ApplyTick(msg DashTickMsg) {
    if msg.CPU.Cores != nil {
        dm.CPU = msg.CPU    // datos reales reemplazan mock
    }
    // ...
}
```

---

## ORDEN DE EJECUCIÓN RECOMENDADO

### Semana 1 — Foundation + primeros datos reales en TUI
```
F0.6.S   Crear usuario bos en staging (deuda seguridad)        [VPS]
F11.1    Auditar Ficha Engine vs contrato SBOS-019              [código]
M1.1     Observer /proc → CPU/RAM reales → TUI Métricas        [código + VPS]
M1.3     Observer systemd → TUI Systemd                        [código + VPS]
M1.2     Observer /proc/<pid> → TUI Procesos                   [código + VPS]
```

### Semana 2 — Ficha Engine real + OS completo
```
F11.2    DEPENDENCY_RESOLVER (grafo Kahn + DAG)                [código]
F11.3    yaml_engine executor 5 fases + señales → TUI          [código + VPS]
M1.4     Observer red + disco → TUI Red/Disco                  [código + VPS]
M1.5     Observer kernel → TUI Kernel                          [código + VPS]
M2.1     Validación real del wizard (formularios)              [código + VPS]
```

### Semana 3 — Bootstrap K8s real
```
F11.4    18 estados consistentes en toda la superficie         [código]
M2.2     Bootstrap Capa 0: host prep real (swap, sysctl, containerd)  [VPS]
M2.3     k3s v1.32 + Calico 3.32.0 instalados en VPS          [VPS]
F12.1    Ficha postgresql HA + WAL slot                        [VPS]
F12.2    Ficha redis DB0/1/2 + AOF                             [VPS]
```

### Semana 4 — Fichas críticas + K8s en TUI
```
F12.3    Ficha vault: init + unseal                            [VPS]
F12.4    Vault PKI: CA interna + AppRole                       [VPS]
F13.1    Ficha keycloak: realm + health                        [VPS]
F13.3    Ficha kong: database.reachable                        [VPS]
M2.4     TUI: Jobs muestra fichas INSTALADA reales             [VPS]
M3.1     Observer K8s API → TUI Workloads                      [VPS]
M3.2     Observer CP → TUI ControlPlane                        [VPS]
M3.3     Observer AS/Net/Sto → TUI K8s restantes               [VPS]
```

### Semana 5+ — Panel operaciones vivo + daemons + VDI
```
F14.1-F14.6   Daemons soberanos como stubs de contrato         [código + VPS]
M4.1-M4.5     12 pantallas Panel con datos reales              [VPS]
M5.1-M5.2     Reconciler + auto-reparación activos             [VPS]
F15-F16        Fichas aplicación + VDI Layer                   [VPS]
F17            Estándares internacionales + certificación final [VPS]
```

**Regla:** No comenzar la semana siguiente hasta que:
  a) Los átomos de la semana anterior estén ✅ en REGISTRO-ESTADO
  b) Las pantallas TUI correspondientes muestren datos reales en el VPS

---

## TABLA MAESTRA: PANTALLA ↔ FASE M ↔ ÁTOMO F (REGISTRO-ESTADO)

Cada pantalla del TUI tiene una fase M que la activa y un átomo F del
REGISTRO-ESTADO que debe estar ✅ antes de que la prueba real sea posible.

| Pantalla ctrl panel | Fase M | Átomo F requerido | Fuente de datos real |
|--------------------|--------|-------------------|----------------------|
| Métricas OS        | M1.1   | — (solo OS)       | /proc/stat, /proc/meminfo |
| Procesos           | M1.2   | — (solo OS)       | /proc/\<pid\>/stat, cmdline |
| Systemd            | M1.3   | — (solo OS)       | systemctl list-units |
| Red OS             | M1.4   | — (solo OS)       | /proc/net/dev, ss -tuln |
| Disco OS           | M1.4   | — (solo OS)       | df, lsblk |
| Kernel             | M1.5   | — (solo OS)       | uname, /proc/modules |
| Monitoreo          | M1+M3  | — / F12.8         | Sparklines CPU/RAM/Red/Pods |
| ScreenInstalling   | M2     | F11.3, F12.1-F12.5| yaml_engine señales → TUI |
| Control Plane K8s  | M3.2   | F12.8, F13.7      | kubectl get nodes, cs |
| Workloads          | M3.1   | F12.8             | kubectl get pods -A |
| Autoscaling        | M3.3   | F12.8             | kubectl get hpa, vpa -A |
| Network K8s        | M3.3   | F13.7             | kubectl get svc, ing -A |
| Storage K8s        | M3.3   | F12.8             | kubectl get pv, pvc -A |
| Jobs               | M4.1   | F11.3, F11.4      | state.json fichas activas |
| Alertas            | M4.2   | F11.6             | health.Checker reglas |
| Logs               | M4.3   | F12.8             | journalctl -f bos+k3s |
| Usuarios / PAM     | M4.4   | F13.7             | Keycloak API + /etc/passwd |
| Seguridad          | M4.4   | F12.8             | ufw status, openssl |
| Backups            | M4.5   | F12.6             | pgbackrest info, redis INFO |
| Overview           | M3+M4  | F13.7             | Composición de todos |
| Net OS             | M1.4   | — (solo OS)       | /proc/net/dev, ss |
| Storage OS         | M1.4   | — (solo OS)       | lsblk, df, iostat |
| Config             | M6.1   | F6.12 (catálogo)  | bos.toml + release plane |

### Lectura de la tabla
- **Fase M** = cuándo se implementa la conexión daemon→TUI
- **Átomo F requerido** = qué debe estar ✅ en REGISTRO-ESTADO para que la prueba real sea posible
- `— (solo OS)` = no requiere K8s ni fichas; se puede probar desde la Semana 1

---

## CERTIFICACIÓN DE UN ÁTOMO F EN REGISTRO-ESTADO

Un átomo del REGISTRO-ESTADO pasa de 🔴 a ✅ cuando:

```
1. El código compila sin errores             go build ./...
2. Tests unitarios pasan con -race           go test -race -count=10 ./...
3. Se despliega en el VPS                   bash build.sh && scp + install
4. La prueba adversarial de la fase pasa    (definida en cada átomo)
5. La pantalla TUI correspondiente          muestra los datos reales
   muestra datos reales del VPS             (no mock)
6. El commit se registra en REGISTRO-ESTADO con hash y fecha
```

**Si el VPS falla o hay que resetearlo durante una prueba:**
El reset es parte del protocolo. Se reinstala, se redespliega, se prueba de nuevo.
El código que no sobrevive un reset limpio no es código certificado.

---

*MANIFIESTO-DESARROLLO.md v2.0 · BOS-REPAIR · SKULL · SBOS · Junio 2026*  
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
