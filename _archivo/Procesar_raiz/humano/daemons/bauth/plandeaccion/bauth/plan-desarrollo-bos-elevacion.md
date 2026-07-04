# Plan de Desarrollo — Elevación de BOS a Sistema Operativo de Negocios
**Versión:** 1.0  
**Fecha:** 2026-05-20  
**Punto de partida:** Sprints 1-4 certificados (BosAgent ciclo de vida E2E)  
**Meta:** BOS = Ubuntu + Kubernetes + BOS, unificado bajo `bosctl`  
**Documento base:** BOS-OS-ELEVATION-PLAN-v3.md  
**Estándares:** ISO/IEC 25010:2023 · IEC 62443-4-1:2018/2024 · NIST SP 800-190 · CIS Kubernetes Benchmark v1.9+

---

## Visión resumida

BOS no administra Ubuntu y Kubernetes. BOS **es** Ubuntu + Kubernetes + capacidades propias, presentados como un único Sistema Operativo de Negocios bajo la interfaz `bosctl`.

La elevación cubre **7 dominios** (D1-D7) agrupados en **5 fases de construcción** con certificación al final de cada fase.

---

## Fases de construcción — Resumen

| Fase | Dominios | Fichas nuevas | Archivos Go nuevos | Comandos bosctl nuevos | Duración estimada |
|---|---|---|---|---|---|
| Fase A — Seguridad | D6 | 2 | 5 | 2 | 3-4 sesiones |
| Fase B — Reparación + Paquetes | D1, D2 | 2 | 9 | 5 | 4-6 sesiones |
| Fase C — Observabilidad | D3 | 3 | 3 | 4 | 3-4 sesiones |
| Fase D — Catálogo + IA | D5, D4 | 2 | 7 | 6 | 4-5 sesiones |
| Fase E — ISO Installer | D7 | 1 | 0 (Bash+Python) | make | 5-7 sesiones |

**Total estimado:** ~25 sesiones de construcción

---

## Fase A — Seguridad Unificada (D6)

**Valor central:** Seguridad en 3 capas — Ubuntu hardening, Kubernetes RBAC, bosctl RBAC — verificable con `bosctl security scan`.

### A.1 — Ficha sbos-bootstrap-hardening

| Archivo | Propósito |
|---|---|
| `staging/core/servers/hostserver/sbos-bootstrap-hardening/task_catalog.sh` | 7 tasks: ubuntu-hardening, kubelet-hardening, apiserver-hardening, cni-health, k8s-rbac-baseline, bosctl-rbac, verify-all |
| `staging/core/servers/hostserver/sbos-bootstrap-hardening/manifest.yml` | Ficha host, order 16, dependencia sbos-bootstrap-k8s, auto_install true |
| `staging/core/servers/hostserver/sbos-bootstrap-hardening/yaml_engine.yml` | Versiones fijadas, paths, checks específicos |

**Tasks del task_catalog.sh:**

```
Task 1: ubuntu-hardening
  - chmod 700 /var/lib/etcd (CIS §1.1.11)
  - chmod 700 /etc/bos/secrets
  - Verificar /etc/bos/rbac/ existe

Task 2: kubelet-hardening
  - /var/lib/kubelet/config.yaml:
    anonymousAuth: false, authorization.mode: Webhook
    protectKernelDefaults: true, readOnlyPort: 0

Task 3: k8s-apiserver-hardening
  - Verificar --anonymous-auth=false en kube-apiserver
  - Verificar --audit-log-path configurado

Task 4: cni-health
  - Verificar CNI pods Running (kindnet)
  - Verificar nftables FORWARD rules

Task 5: k8s-rbac-baseline
  - Aplicar ClusterRole + RoleBinding mínimo
  - Validar con kubectl auth can-i

Task 6: bosctl-rbac
  - Crear /etc/bos/rbac/roles.json con 3 roles
  - Asignar usuario skull → admin

Task 7: verify-all
  - Validar que todos los checks anteriores pasan
  - Emitir __SBOS__STEP_OK__ por cada verificación
```

### A.2 — Ficha sbos-security

| Archivo | Propósito |
|---|---|
| `staging/core/servers/hostserver/sbos-security/task_catalog.sh` | Security scan programático: ejecuta CIS checks y emite reporte |
| `staging/core/servers/hostserver/sbos-security/manifest.yml` | Ficha host, order 17, dependencia sbos-bootstrap-hardening |
| `staging/core/servers/hostserver/sbos-security/yaml_engine.yml` | Catálogo de checks CIS, thresholds |

### A.3 — Paquete Go `internal/security`

| Archivo | Responsabilidad |
|---|---|
| `src/internal/security/rbac_provider.go` | **Interfaz** `RBACProvider`: `CanExecute(user, cmd) error`, `GetRole(user) string`. Define el contrato sin acoplarse a implementación. |
| `src/internal/security/file_rbac.go` | **Implementación Fase A:** carga/guarda `/etc/bos/rbac/roles.json`. Implementa `RBACProvider`. Certificable sin dependencias externas. |
| `src/internal/security/scanner.go` | `SecurityScanner` orquesta CIS checks Ubuntu + K8s + bosctl |
| `src/internal/security/ubuntu_checks.go` | Checks: permisos etcd, permisos secrets, kernel defaults |
| `src/internal/security/k8s_checks.go` | Checks: kubelet flags, apiserver anonymous-auth, CNI health, RBAC baseline |
| `src/internal/security/cis_benchmarks.go` | Referencias CIS: IDs, descripciones, severidades |

#### Puerta abierta a BauthAgent — integración futura vía WebSocket

El RBAC de la Fase A usa un archivo JSON local. Cuando BauthAgent esté certificado,
se reemplaza por `BauthRBAC` — misma interfaz, transporte WebSocket:

```
┌──────────────────────────────────────────────────────────────────┐
│                     RBACProvider (interfaz)                      │
│                     CanExecute(user, cmd)                        │
│                     GetRole(user)                                │
└────────────────────────────┬─────────────────────────────────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
┌─────────┴─────────┐  ┌────┴──────────┐
│    FileRBAC       │  │  BauthRBAC    │
│    (Fase A)       │  │  (Futuro)     │
│                   │  │               │
│ lee roles.json    │  │ WebSocket →   │
│ 3 roles fijos     │  │ BauthAgent    │
│ static config     │  │ JWT + RBAC    │
└───────────────────┘  └───────────────┘
     AHORA               CUANDO BAUTH LISTO
```

**Contrato Go:**

```go
// rbac_provider.go
type RBACProvider interface {
    CanExecute(user string, cmd string) error
    GetRole(user string) string
}
```

**BauthRBAC futuro:** implementa la misma interfaz, internamente abre WebSocket a BauthAgent
y consulta autorización por ese canal — igual que el resto de demonios BOS.
Nunca HTTP. Nunca expuesto al exterior.

**Migración sin tocar clientes:** el daemon principal instancia el provider según config
y el resto del código (`bosctl`, `bos main`, `server/api.go`) solo ve la interfaz.

### A.4 — Comandos bosctl nuevos

```
bosctl security scan           → Ejecuta scanner completo, emite reporte formateado
bosctl security audit          → Muestra audit log (/var/log/bos/audit.log)
bosctl --user <rol> <comando>  → Ejecuta comando con RBAC de bosctl
```

### A.5 — Certificación Fase A

```bash
# 1. Instalar fichas de seguridad
bosctl install sbos-bootstrap-hardening
bosctl install sbos-security

# 2. Verificar estados
bosctl status sbos-bootstrap-hardening  # INSTALADA--OK HEALTHY
bosctl status sbos-security             # INSTALADA--OK HEALTHY

# 3. Security scan 100%
bosctl security scan | grep "100%"

# 4. RBAC enforcement
bosctl --user readonly repair --target=os 2>&1 | grep "insufficient permissions"

# 5. K8s RBAC baseline
kubectl auth can-i delete pods --as=system:serviceaccount:default:default | grep "^no$"

# 6. Evidencia en disco
test -f /etc/bos/rbac/roles.json
cat /var/log/bos/audit.log | grep "SECURITY_SCAN"
```

---

## Fase B — Reparación Unificada + Package Manager (D1 + D2)

**Valor central:** `bosctl repair --target=all` repara Ubuntu+K8s+BOS en un solo comando. `bosctl install <pkg>` instala vía apt, pip o helm y genera ficha automáticamente.

### B.1 — D1 Reparación Unificada

Archivos Go:

| Archivo | Responsabilidad |
|---|---|
| `src/internal/repair/os_repair.go` | Fase 1 Ubuntu: apt --fix-broken, dpkg --audit, systemctl restart |
| `src/internal/repair/k8s_node_repair.go` | Fase 2 K8s: kubectl cordon→drain→restart kubelet→uncordon |
| `src/internal/repair/repair_manager.go` | Orquesta Fase 1→2→3→4, timeout por fase, audit log |
| `src/internal/repair/health_verifier.go` | Fase 4 post-repair: verifica Ubuntu+K8s+BOS sanos |
| `src/cmd/bosctl/repair.go` | CLI: parsea --target, --dry-run, --timeout |

Ficha:

| Archivo | Propósito |
|---|---|
| `staging/core/servers/hostserver/sbos-repair/task_catalog.sh` | 4 fases de repair con __SBOS__ signals |
| `staging/core/servers/hostserver/sbos-repair/manifest.yml` | Order 18, dependencia sbos-security |
| `staging/core/servers/hostserver/sbos-repair/yaml_engine.yml` | Timeouts por fase, thresholds, dry-run mode |

Secuencia `bosctl repair --target=all`:
```
FASE 1 — Ubuntu: dpkg --audit → apt --fix-broken → verificar containerd/kubelet/systemd
FASE 2 — K8s: kubectl get nodes → cordon/drain NotReady → restart kubelet → uncordon
FASE 3 — BOS: reconciliar state file → repair saga por ficha degradada
FASE 4 — Verificación: dpkg clean → all nodes Ready → all pods Running → all fichas HEALTHY
```

### B.2 — D2 Package Manager Unificado

Archivos Go:

| Archivo | Responsabilidad |
|---|---|
| `src/internal/packages/apt_adapter.go` | Envuelve apt install/remove/purge |
| `src/internal/packages/pip_adapter.go` | Envuelve pip3 install/uninstall |
| `src/internal/packages/helm_adapter.go` | Envuelve helm install/upgrade/rollback/uninstall |
| `src/internal/packages/package_manager.go` | Detecta backend según prefijo/flag, delega, registra en state file |
| `src/internal/packages/ficha_generator.go` | Post-install: genera manifest.yml con health_check automático |

Ficha:

| Archivo | Propósito |
|---|---|
| `staging/core/servers/hostserver/sbos-package-manager/task_catalog.sh` | Backend dispatcher con __SBOS__ signals |
| `staging/core/servers/hostserver/sbos-package-manager/manifest.yml` | Order 19, dependencia sbos-repair |
| `staging/core/servers/hostserver/sbos-package-manager/yaml_engine.yml` | Backend registry, version pinned |

Comandos nuevos:
```
bosctl install <pkg> [--backend=apt|pip|helm]  → Instala + genera ficha
bosctl remove <pkg>                             → Desinstala + limpia ficha
bosctl upgrade <pkg> [--to=<version>]           → Actualiza + versiona
```

### B.3 — Certificación Fase B

```bash
# D1 — Repair multi-capa
bosctl repair --target=all
journalctl -u bos | grep "repair-all phases=4 ubuntu=OK k8s=OK bos=OK"
bosctl repair --target=os --dry-run | grep "Would run"

# D2 — Package manager unificado
bosctl install curl
bosctl status sbos-app-curl          # INSTALADA--OK HEALTHY
bosctl remove curl
bosctl status sbos-app-curl          # DESINSTALADA / no existe

# Evidencia
ls /opt/bos/bin/bosctl               # CLI con comandos repair, install, remove, upgrade
test -f /etc/bos/blibs/servers/hostserver/sbos-repair/task_catalog.sh
test -f /etc/bos/blibs/servers/hostserver/sbos-package-manager/task_catalog.sh
```

---

## Fase C — Observabilidad Unificada (D3)

**Valor central:** BOS incorpora métricas de Ubuntu (/proc, journald) y Kubernetes (cAdvisor, kube-state-metrics) en `bosctl top` y `bosctl health`.

### C.1 — Fichas de observabilidad

| Ficha | Tipo | Dependencia | Propósito |
|---|---|---|---|
| `sbos-app-kube-state-metrics` | Contenedor (DaemonSet) | sbos-bootstrap-k8s | Métricas de objetos K8s via kube-state-metrics |
| `sbos-app-node-exporter` | Contenedor (DaemonSet) | sbos-bootstrap-k8s | Métricas de nodo via Prometheus node_exporter |
| `sbos-container-watchdog` | Host | sbos-lifecycle | Watchdog unificado Ubuntu+K8s+BOS cada 30s |

### C.2 — Watchdog Unificado

Ciclo de 30s:
```
UBUNTU:  df -h → disk>85% alerta + cleanup
         free -m → mem>90% alerta
         systemctl is-active containerd kubelet
K8S:     kubectl get nodes → NotReady → repair
         pods CrashLoop → kubectl rollout restart
BOS:     health_check de cada ficha → ficha DEGRADED → repair saga
```

Archivos Go:

| Archivo | Responsabilidad |
|---|---|
| `src/internal/watchdog/unified_watchdog.go` | Loop de 30s: Ubuntu + K8s + BOS checks |
| `src/internal/observability/top.go` | `bosctl top`: vista unificada CPU/mem/disk + pods + fichas |
| `src/internal/observability/health_report.go` | `bosctl health`: reporte estructurado de salud del sistema |

Comandos nuevos:
```
bosctl top                  → Vista unificada métricas Ubuntu+K8s+fichas
bosctl health               → Reporte de salud completo del Business OS
bosctl logs <pod|servicio>  → Logs unificados (journald + kubectl logs)
bosctl logs --follow        → Stream en vivo
```

### C.3 — Certificación Fase C

```bash
# Instalar fichas de observabilidad
bosctl install sbos-app-kube-state-metrics
bosctl install sbos-app-node-exporter

# Vista unificada
bosctl top | grep -E "CPU|MEM|DISK|fichas|pods"
bosctl health | grep -E "Ubuntu|K8s|fichas"

# Watchdog activo
journalctl -u bos | grep "watchdog cycle="

# Logs unificados
bosctl logs bos.service | head
bosctl logs coredns --namespace=kube-system
```

---

## Fase D — Catálogo de Apps + Agente IA (D5 + D4)

**Valor central:** Un catálogo unificado de todo lo que corre en el Business OS (`bosctl app list`), con rollback inteligente, más un agente IA que responde con contexto de las 3 capas.

### D.1 — D5 Catálogo de Aplicaciones

Archivos Go:

| Archivo | Responsabilidad |
|---|---|
| `src/internal/catalog/catalog.go` | Índice unificado: categoriza fichas (SO Base, Orquestación, Observabilidad, Apps, IA) |
| `src/internal/catalog/versioning.go` | Snapshots del state file antes de cada cambio |
| `src/internal/catalog/rollback.go` | Rollback según backend: apt reinstall, helm rollback, pip install==version |

Comandos nuevos:
```
bosctl app list               → Catálogo categorizado con estados y versiones
bosctl app history <ficha>    → Historial de versiones con timestamps
bosctl app rollback <ficha> [--to=<version>]  → Rollback inteligente
```

### D.2 — D4 Agente IA

Archivos Go:

| Archivo | Responsabilidad |
|---|---|
| `src/internal/ai/context_builder.go` | Agrega contexto: Ubuntu (journald 100 líneas, df, free) + K8s (kubectl get all, events 50) + BOS (state file) |
| `src/internal/ai/claude_client.go` | Cliente HTTP a Anthropic API con timeout 30s, dry-run por defecto |
| `src/internal/ai/response_parser.go` | Extrae comandos bosctl propuestos, filtra patrones peligrosos |
| `src/cmd/bosctl/ask.go` | CLI: ask, diagnose, explain, plan |

Seguridad del agente IA:
```
- ANTHROPIC_API_KEY en /etc/bos/secrets/ai.key (0600, owner bos)
- Nunca en journal ni audit log (grep automatizado)
- Timeout 30s — no bloquea el daemon
- dry-run por defecto (--execute para aplicar)
- Lista negra de patrones peligrosos: kubectl delete --all, rm -rf /, etc.
- Audit log: ai_query=tipo tokens=N result=OK (sin contenido de query ni respuesta)
```

Comandos nuevos:
```
bosctl ask "<pregunta>"       → LLM con contexto Ubuntu+K8s+BOS
bosctl diagnose               → Diagnóstico autónomo sin pregunta
bosctl explain <ficha>        → Explicación de estado de una ficha
bosctl plan "<objetivo>"      → Plan de acción propuesto por IA
```

### D.3 — Certificación Fase D

```bash
# D5 — Catálogo
bosctl app list | grep -E "SO Base|Orquestación|Observabilidad|Negocio|IA"
bosctl app rollback nginx --to=1.24.0
bosctl status sbos-app-nginx | grep "1.24.0"

# D4 — IA
export ANTHROPIC_API_KEY="sk-ant-..."
bosctl ask "¿está el Business OS saludable?"
bosctl diagnose
journalctl -u bos | grep -i "sk-ant" && echo "FAIL: key expuesta" || echo "OK: key segura"

# Evidencia de dry-run
bosctl ask "¿qué está fallando?" 2>&1 | grep "dry-run"
```

---

## Fase E — BOS Installer ISO (D7)

**Valor central:** BOS se instala como un sistema operativo real desde un ISO bootable, con pantallas branded, completamente desatendido.

### E.1 — Componentes del Installer

| Componente | Tecnología | Propósito |
|---|---|---|
| `installer/user-data.yaml` | Ubuntu Autoinstall | YAML de instalación desatendida |
| `installer/meta-data` | Cloud-init | Archivo vacío requerido |
| `installer/grub.cfg` | GRUB 2 | Bootloader con splash branded |
| `installer/grub.theme` | GRUB theme | Colores, logo, tipografía BOS |
| `installer/bos-bootstrap.sh` | Bash | Ejecutado en late-commands (chroot) |
| `installer/bos-installer-ui` | Python + rich | TUI de progreso en tiempo real |
| `installer/bos-installer-ui.service` | Systemd unit | Auto-start de la UI en primer boot |
| `installer/splash.png` | PNG | Pantalla de bienvenida GRUB |
| `installer/progress-screens/` | PNG x4 | Pantallas de cada fase |
| `Makefile` | GNU Make | `make bos-installer-offline`, `make bos-installer-online` |

### E.2 — Secuencia de instalación

```
FASE 0 — GRUB boot
  Pantalla branded BOS → autoboot 10s
FASE 1 — Ubuntu Autoinstall (subiquity)
  Particionado LVM, usuario bos-admin, paquetes base
FASE 2 — Late-commands (chroot)
  containerd + kubelet + kubeadm + kubectl
  Binarios BOS: bos + bosctl
  Fichas: copia completa a /etc/bos/blibs/servers/
  bos.service → enable
FASE 3 — Primer boot con BOS daemon
  TUI de progreso leyendo state file en tiempo real
  Auto-install topológico de fichas
FASE 4 — Instalación completa
  Pantalla final → reinicio → bosctl status
```

### E.3 — Certificación Fase E

```bash
# 1. Construir ISO
make bos-installer-offline VERSION=1.0.0
sha256sum -c dist/bos-installer-1.0.0-amd64.iso.sha256

# 2. Boot en VM
qemu-system-x86_64 -m 4096 -smp 2 \
  -cdrom dist/bos-installer-1.0.0-amd64.iso \
  -hda /tmp/bos-test.img -boot d

# 3. Verificar post-instalación
ssh bos-admin@<IP-VM> "bosctl status"
# Esperado: todas las fichas INSTALADA--OK HEALTHY

ssh bos-admin@<IP-VM> "kubectl get nodes"
# Esperado: Ready

# 4. Verificar modo offline
# Desconectar red → bootear ISO → instalación completa sin errores

# 5. Verificar pantallas branded
ssh bos-admin@<IP-VM> "journalctl -u bos-installer-ui"
# Esperado: secuencia completa de pantallas

# 6. Re-instalación
# Bootear ISO sobre instalación existente → instalación limpia sin residuos
```

---

## Matriz de dependencias entre fases

```
Fase A (Seguridad)
  └── depende de: Sprints 1-4 (sbos-bootstrap-os, sbos-bootstrap-k8s, sbos-lifecycle)

Fase B (Repair + Package Manager)
  ├── D1 Repair depende de: Fase A (necesita hardening para repair seguro)
  └── D2 Package Manager depende de: Fase A (necesita RBAC para bosctl install)

Fase C (Observabilidad)
  └── depende de: Fase B (usa repair saga en watchdog, necesita package manager para instalar métricas)

Fase D (Catálogo + IA)
  ├── D5 Catálogo depende de: Fase B + C (necesita fichas instaladas para catalogar, métricas para health)
  └── D4 IA depende de: Fase C (necesita métricas + logs para contexto del LLM)

Fase E (Installer ISO)
  └── depende de: Fases A-D completas (empaqueta el sistema completo)
```

---

## PGE — Asignación de modelos por fase

Siguiendo ADR-025 (Claude piensa, DeepSeek construye) y ADR-026 (PGE obligatorio):

| Fase | Planner | Generator | Evaluator | MAX_ITER |
|---|---|---|---|---|
| A — Seguridad | Claude Opus | DeepSeek V4-Pro | Claude Sonnet | 3 |
| B — Repair + Paquetes | Claude Opus | DeepSeek V4-Pro | Claude Sonnet | 5 |
| C — Observabilidad | Claude Opus | DeepSeek V4-Pro | Claude Sonnet | 3 |
| D — Catálogo + IA | Claude Opus | DeepSeek V4-Pro | Claude Sonnet | 5 |
| E — Installer ISO | Claude Opus | DeepSeek V4-Pro | Claude Sonnet | 3 |

---

## Trazabilidad a estándares — por fase

| Fase | ISO/IEC 25010 | IEC 62443 | CIS K8s | NIST SP 800-190 |
|---|---|---|---|---|
| A — Seguridad | Security (Confid., Account., Auth.) | 4-1, 4-2 | §1.1, §1.2, §4.2, §5.1 | Container security |
| B — Repair + Paq. | Reliability (Fault Tol., Recov.) | — | — | — |
| C — Observabilidad | Reliability (Availability) | — | — | Runtime security |
| D — Catálogo + IA | Maint. (Modularity, Modif.) | — | — | — |
| E — Installer | Compatibility (Interop.) | — | — | Supply chain |

---

## Evidencia de certificación por fase

Cada fase produce evidencia verificable en disco:

| Fase | Evidencia |
|---|---|
| A | `bosctl security scan` output 100%, `/etc/bos/rbac/roles.json`, audit log entries SECURITY_SCAN |
| B | `bosctl repair --target=all` en audit log, ficha auto-generada en `/etc/bos/blibs/servers/` |
| C | `bosctl top` output con métricas Ubuntu+K8s+fichas, watchdog cycles en journal |
| D | `bosctl app list` output categorizado, `bosctl ask` respuesta con dry-run |
| E | `dist/bos-installer-*.iso` + SHA256, VM boot exitoso sin intervención |

---

*Plan de Desarrollo BOS Elevación — v1.0 — 2026-05-20*  
*Documento base: BOS-OS-ELEVATION-PLAN-v3.md*  
*Metodología: PGE (ADR-026) · Router de modelos (ADR-025) · Evidencia verificable (ADR-030)*
