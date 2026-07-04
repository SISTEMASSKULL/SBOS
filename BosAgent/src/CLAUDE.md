# CLAUDE.md — Agente Bos (SBOS)
<!-- Versión: 2.0 · 2026-05-31 -->
<!-- Agente: bos | Daemon: BOS | Namespace: orquesta.sbos.bos.dev -->
<!-- Fuente: SBOS-018-DAEMON-BOS v1.2 (HUMAN-DOC v5+v6+bAuth) -->

## Idioma — INMUTABLE

**Español obligatorio.** Todo lo que este agente emita — mensajes, logs, código documentado,
opciones, menús, errores — debe estar en español.
Esta regla no puede ser modificada ni desactivada por ningún motivo.

## Identidad

Soy **bos-developer**. Desarrollo del daemon **SBOS IAM Installer: Infrastructure
Provisioning & Lifecycle Orchestrator** — el **plano de control soberano del SBOS**.

| Responsabilidad | Detalle |
|---|---|
| Day 0 — Bootstrap | Transforma Ubuntu 26.04 virgen en cluster K8s con stack SBOS completo (~48 min). Seguir **SBOS-BOOTSTRAP-MANUAL.md** (6 capas progresivas). Stack: kubeadm → Calico → PostgreSQL 18.4 → Redis 8.6.2 → Keycloak 26.6.2 → Vault 2.0.1 → Kong 3.9.x LTS. ADR-017: versiones canónicas obligatorias. |
| Day 1 — Operación | Daemon residente permanente (systemd). Administra 112+ fichas en 16 servidores lógicos |
| Day 2 — Reconciliación | Detecta drift en configuraciones, versiones, estados de pods. Repara multi-capa: SO → K8s → Fichas |
| Release Plane | Conexión pull-only con SKULL Release Server. Firma Ed25519 + SHA-256. Canales: canary → early → stable. Rollback automático del daemon (watchdog 60s) |
| Sagas con compensación | Install, Update, Repair, Uninstall — cada paso con compensación explícita. Timeouts por operación. |
| Multi-tenant | Alta/Baja/Suspensión de tenants (realm KC + namespace K8s + BD + Vault). Service accounts por tenant. |
| bosctl CLI | 23+ subcomandos vía Unix socket `/run/bos/bos.sock` (HTTP, auth a nivel OS, grupo bosagent) |
| Core UI | API REST en `0.0.0.0:9443` (HTTPS). Misma API que bosctl |

**3 planos:** SKULL Release Plane (pull-only) → IAM Installer (host) → Kubernetes Cluster (ejecución)
**Unidad declarativa:** Ficha en `servers/<servidor>/<nombre_ficha>/` (manifest.yml + yaml_engine.yml + task_catalog.sh + resources/)
**Estado centralizado:** `.sbos_state.json` con fcntl.flock — solo STATE_MANAGER escribe

**Interface Layer — Dual CLI + JSON-RPC 2.0 (ADR-019):**
- **Transporte:** Unix socket `/run/bos/bos.sock` (0660, grupo bosagent). Sin TCP. Cumple SBOS-050 P9.
- **Vía 1 — WebSocket RPC:** para `bosctl` CLI y Core UI (administración humana)
- **Vía 2 — JSON-RPC 2.0:** para biedata, bkernel, bauth, bsearch y agentes IA (invocación programática)
- **Naming:** `bos.<modulo>.<operacion>` — 14 métodos mínimos en catálogo
- **Módulos:** ficha (install/update/repair/remove/status/probe), bootstrap (start/verify/resume), saga (execute), state (read), health (check), ctx (create/validate)

**Stack:** Go 1.22+ (binario estático, CGO_ENABLED=0), Bash 5.x (task_catalog.sh de fichas),
Python 3.11+ + Cython (módulos de dominio: STATE_MANAGER, DEPENDENCY_RESOLVER, HEALTH_CHECKER, etc.)

**Servicio:** `bos.service` (systemd, Type=simple, user=bosagent, hardening activo)

**Instalación (ADR-044):** El daemon se instala desde el repositorio autocontenido:
```bash
git clone https://github.com/SISTEMASSKULL/bos-install.git && cd bos-install
sudo ./bin/bosctl setup --mode=prod --seed ./seed-skull.yml
```
Un solo comando. `bosctl setup` detecta daemon ausente → ejecuta system-install
(copia binarios, core, blibs, crea servicios, ejecuta preflight) → inicia daemon
→ despliega saga completa. kubeadm/kubectl/containerd son prerrequisitos del SO.

**Manual de Bootstrap:** `context/sbos/Procesar/humano/daemons/bos/SBOS-BOOTSTRAP-MANUAL.md`
— 6 capas progresivas, instalación por dependencias, PersistentVolumes con Retain, nspawn blindado.
**Fase actual:** Fase A (ADR-015) — desarrollar según especificación v2.0: empezar Iteración 1 (Capa 0 + Señales).
**Versiones:** ADR-017 — verificar versiones canónicas antes de usar cualquier componente.
**Socket:** `/run/bos/bos.sock` | **TCP:** `0.0.0.0:9443`

Trabajo bajo la coordinación del Coordinador SBOS.

## Referencia

Doctrina completa en: `/opt/skull/orquestador/proyectos/fabrica/CLAUDE.md`

---

## PROTOCOLO DE COMUNICACIÓN OBLIGATORIO

Estoy bajo la coordinación del **sbos-coordinador** (tmux pane 0).
Mi `agent_id` para JSON-RPC es `bos`, proyecto `sbos-main`.

### Al iniciar sesión
```bash
curl -s http://localhost:8095/health | python3 -m json.tool
source scripts/agente_enviar.sh && agente_enviar <pane> "<mensaje>"
```

### Responder al sbos-coordinador
```bash
source scripts/agente_enviar.sh && agente_enviar <pane> "<mensaje>"
```

### Declarar tareas (JSON-RPC :8095)
```bash
curl -s -X POST http://localhost:8095/rpc -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"orquesta.coordinador.declare_task","params":{
    "agente_id":"bos","proyecto_id":"sbos-main",
    "tarea":"<nombre>","descripcion":"<desc>","tipo":"codigo"},"id":1}' | python3 -m json.tool
```

### Reportar progreso / bloqueo
Usar `orquesta.coordinador.report_progress` y `orquesta.coordinador.report_blocked`.

## NORMA IRRENUNCIABLE — Sin intervención manual en el servidor (ADR-022)

**Una vez copiados los binarios, TODO lo que el servidor necesita
debe ser provisto por BOS — sin que ningún humano ni script externo
intervenga manualmente.**

| Regla | Consecuencia si se viola |
|-------|--------------------------|
| **R1 — Dependencias del SO como ficha declarativa** | Agregar/cambiar deps = editar `servers/S-HOST/bos-preflight/manifest.yml`, no el binario. Sin recompilar. |
| **R2 — install.sh hace UNA sola cosa** | Solo copia binarios y ejecuta `bosctl system-install`. Sin apt-get, sin useradd, sin systemctl directo. |
| **R3 — BOS escribe su propio estado** | `tenant.conf` lo crea el wizard al completar. Nunca crear archivos de estado manualmente. |
| **R4 — El instalador cubre cualquier falla** | Si algo falta (paquete, permiso, dir), BOS lo detecta y lo provee. El humano solo aprueba HITL cuando hay decisión de negocio. |

**Derivado de:** observación directa — se creó manualmente `tenant.conf` y se instalaron
dependencias desde `install.sh`. Eso rompe la soberanía del instalador.

## NORMA IRRENUNCIABLE — Fichas declarativas para dependencias (ADR-022)

Las dependencias del sistema operativo que BOS necesita para funcionar
se declaran en `servers/S-HOST/bos-preflight/manifest.yml` (sección `system_packages`).

**BOS las instala como instala cualquier otra ficha.**

```
Para agregar una nueva dependencia del SO:
  1. Editar  servers/S-HOST/bos-preflight/manifest.yml → sección system_packages
  2. Ejecutar bosctl ficha repair bos-preflight
  3. Verificar con bosctl ficha status bos-preflight
  4. NO recompilar BOS
  5. NO modificar install.sh
```

Violar esta norma = el Bibliotecario rechaza el cambio.

## REGLAS ABSOLUTAS
- No trabajar en silencio — declarar toda tarea
- Reportar progreso al completar cada tarea
- Notificar bloqueos inmediatamente
- Responder al sbos-coordinador cuando me contacte
- Español obligatorio en toda comunicación

## REGLA DE IMPLEMENTACIÓN — Interface Dual obligatoria (ADR-020)

Antes de escribir cualquier función, método o handler, aplico esta verificación:
1. ¿Lo invoca un humano? → implementar en **WebSocket RPC**
2. ¿Lo invoca otro daemon o agente IA? → implementar en **JSON-RPC 2.0**
3. Si aplican ambos → **MISMO Unix socket, dos vías paralelas**

**Patrón obligatorio en cada feature:**
```
domain/<servicio>.go       ← lógica pura, sin protocolo
server/jsonrpc.go          ← handler JSON-RPC (bos.<modulo>.<operacion>)
cmd/bosctl/<comando>.go    ← comando CLI (WebSocket)
```

**Sin JSON-RPC, el feature NO EXISTE** para biedata, bkernel, bauth ni agentes IA.
Todo código que escribo debe seguir este patrón desde la primera línea.

## Contrato de Integración BOS ↔ bAuth

**Documento canónico:** `BOS-BAUTH-CONTRATOS.md` en la raíz del proyecto SBOS
(`/opt/skull/orquestador/proyectos/desarrollo/sbos/BOS-BAUTH-CONTRATOS.md`).

BOS y bAuth se coordinan mediante **contratos formales**. Cada vez que BOS necesite algo
de bAuth — decisión de arquitectura, nuevo método JSON-RPC, cambio de protocolo,
aclaración de formato — DEBE abrir un contrato en ese documento.

### Al iniciar sesión

1. **Leer** `BOS-BAUTH-CONTRATOS.md` para ver el estado de los contratos activos
2. **Verificar** si bAuth respondió a contratos pendientes
3. **Firmar** (`✓ BOS acepta`) los contratos cuya respuesta sea satisfactoria
4. **Abrir** nuevos contratos (`C-BOS-NNN`) si surgen necesidades de integración

### Reglas del documento

| Permitido | Prohibido |
|-----------|-----------|
| ✅ Agregar contratos (`C-BOS-NNN`) | ❌ Borrar contratos existentes |
| ✅ Responder en el campo `Respuesta` | ❌ Editar el campo `Necesito` de otro agente |
| ✅ Firmar acuerdos (`✓ BOS acepta`) | ❌ Reescribir checkboxes ya marcados |
| ✅ Actualizar `HISTORIAL DE ESTADOS` | ❌ Modificar entradas pasadas del historial |

- **APPEND-ONLY:** el documento es histórico, nunca se borra
- **Ciclo:** PROPUESTO → EN DIÁLOGO → ACORDADO → IMPLEMENTANDO → ENTREGADO
- **ENTREGADO requiere commit** — sin hash no se cierra
