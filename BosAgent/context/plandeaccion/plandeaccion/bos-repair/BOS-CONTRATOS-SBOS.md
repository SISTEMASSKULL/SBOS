# BOS — Contratos Arquitectónicos con el Ecosistema SBOS
## Especificación Funcional y Estado de Implementación

**Versión:** 1.0  
**Fecha:** 2026-06-12  
**Estado:** Normativo — Activo  
**Referencia maestra:** `SBOS_Proyecto_Master.md` v2.1  
**Código fuente:** `BosAgent/src/`  
**Clasificación:** Interno · Confidencial

---

## Propósito de este Documento

El BOS (IAM Installer) que desarrollamos **no es solo un instalador**.
Es el **Control Plane soberano** de todo el ecosistema SBOS.

El resto de los daemons soberanos (bAuth, bKernel, biedata, bSearch, bhnexus)
y las aplicaciones (Kong, Keycloak, Tryton, SmartTax) **dependen del BOS**
para existir, operar y comunicarse. Sin BOS correctamente implementado,
ningún otro componente puede funcionar.

Este documento formaliza los **contratos que el BOS debe cumplir** para que
el SBOS_Proyecto_Master.md pueda materializarse. Cada contrato define:
- Qué requiere el ecosistema
- Qué está implementado hoy
- Qué falta implementar
- El criterio de aceptación verificable

---

## La Posición del BOS en el Stack

```
Ubuntu Linux (host)
    │
    ├── systemd
    │     ├── bos.service          ← AQUÍ corre el BOS (este proyecto)
    │     ├── bkernel.service      ← necesita que BOS le provisione PostgreSQL
    │     ├── biedata.service      ← necesita que BOS le provisione Redis + PG
    │     ├── bauth.service        ← necesita que BOS le provisione Keycloak
    │     └── bsearch.service      ← necesita que BOS le provisione PG + Redis
    │
    └── Kubernetes (k3s)
          └── Namespaces — creados y gestionados por BOS
                └── Pods (fichas: PostgreSQL, Redis, Keycloak, Kong, etc.)
```

**BOS actúa SOBRE Ubuntu y SOBRE Kubernetes. No es un pod. Es el soberano.**

El BOS tiene tres fases de vida:

| Fase | Nombre | Qué hace |
|------|--------|----------|
| **Day 0** | Bootstrap | Transforma Ubuntu virgen en cluster K8s + stack SBOS (~48 min) |
| **Day 1** | Operación | Daemon permanente. Administra 112+ fichas, sirve Context API |
| **Day 2** | Reconciliación | Detecta drift, repara multi-capa (SO → K8s → Fichas) cada 15 min |

---

## Los Siete Contratos del BOS

### Contrato C-1 — Context Plane (Propietario Exclusivo)

**Qué requiere el Proyecto Master (§3, §5):**

El BOS es el **único dueño del Context Plane**. Ningún otro daemon puede crear,
modificar ni destruir contextos. Es el Policy Administrator del NIST SP 800-207.

```
Responsabilidades del Context Plane:
  1. Crear dctx_id cuando un dispositivo banexus se registra (pre-autenticación)
  2. Promover dctx_id → ctx_id cuando el usuario se autentica (context.promoted)
  3. Servir Context API O(1) para que Kong valide ctx_id en cada request
  4. Invalidar todos los ctx_id de un tenant al suspenderlo
  5. Preservar context_sessions para auditoría ISO 27001 A.8.15 (nunca eliminar)
```

**Estado de implementación:**

| Capacidad | Archivo | Estado |
|-----------|---------|--------|
| `dctx_id` — RegisterDevice | `internal/context/service.go:47` | ✅ Implementado |
| `ctx_id` — Promote (context.promoted) | `internal/context/service.go:70` | ✅ Implementado |
| Context Switch (nuevo ctx_id) | `internal/context/service.go:97` | ✅ Implementado |
| Invalidate por ctx_id | `internal/context/service.go:122` | ✅ Implementado |
| InvalidateAll por tenant | `internal/context/service.go:138` | ✅ Implementado |
| PGRedisStore (PG + Redis DB1) | `internal/context/store.go:64` | ✅ Implementado |
| JSON-RPC — bos.ctx.* (10 métodos) | `internal/server/jsonrpc.go:209` | ✅ Implementado |
| bosctl ctx list/get/invalidate | `cmd/bosctl/context.go` | ✅ Implementado |
| context_sessions DDL (tabla PG) | — | ⚠️ Pendiente migración SQL |
| Evento context.promoted → bKernel | — | 🔴 No implementado |
| TTL Redis sincronizado con KC | `internal/context/store.go` | ⚠️ Parcial |

**Interfaz expuesta (Context API REST para Kong — §3.4):**

```
POST   /api/v1/context/create
POST   /api/v1/context/switch
DELETE /api/v1/context/{ctx_id}
GET    /api/v1/context/{ctx_id}         ← lookup O(1) — crítico para Kong
GET    /api/v1/context/tenant/{tenant}
POST   /api/v1/context/tenant/{tenant}/invalidate-all
```

> **Estado REST:** Los métodos JSON-RPC sobre Unix socket están completos.
> La Context API REST HTTP (para Kong y clientes externos) requiere exponer
> estos endpoints vía el servidor HTTPS en `:9443`.
> **Prioridad: ALTA** — Kong no puede validar ctx_id sin esta API.

**Criterio de aceptación C-1:**
```bash
# El Kong plugin puede validar un ctx_id activo en <5ms
curl -s https://bos-host:9443/api/v1/context/ctx-88291-a4f9
# Retorna: {"ctx_id":"ctx-88291-a4f9","tenant":"skull","empresa":"maya",...}

# bAuth puede crear contexto vía JSON-RPC (Unix socket)
echo '{"jsonrpc":"2.0","method":"bos.ctx.create","params":{...},"id":1}' \
  | nc -U /run/bos/bos.sock
```

---

### Contrato C-2 — Ciclo de Vida de Tenants (Saga 7 Pasos)

**Qué requiere el Proyecto Master (§3.3):**

```
bosctl deploy <seed.yml>  →  Saga de 7 pasos con compensación:
  Paso 1: Crear Realm en Keycloak + SPIs custom
  Paso 2: Crear Namespace en Kubernetes con labels
  Paso 3: Provisionar bases de datos en PostgreSQL (ver §7.1)
  Paso 4: Crear paths de secretos en Vault (AppRole)
  Paso 5: Inicializar Context Registry en Redis DB1
  Paso 6: Crear context_sessions en bkernel_db
  Paso 7: Instalar fichas del tenant en orden topológico
```

Cada paso tiene compensación explícita. Si el Paso 4 falla,
los Pasos 1-3 se revierten automáticamente.

**Estado de implementación:**

| Capacidad | Estado | Notas |
|-----------|--------|-------|
| `bosctl tenant` — estructura base | ✅ Existe | `cmd/bosctl/identity.go` |
| Saga engine con compensación | ✅ Existe | `internal/installer/saga.go` |
| `bosctl deploy <seed.yml>` | 🔴 No implementado | Necesita saga 7 pasos |
| Paso 1: Realm Keycloak | 🔴 No implementado | Requiere Keycloak operativo |
| Paso 2: Namespace K8s | ⚠️ Parcial | `internal/k8s/` existe |
| Paso 3: BDs PostgreSQL | 🔴 No implementado | Requiere PG operativo |
| Paso 4: Paths Vault | 🔴 No implementado | Requiere Vault operativo |
| Paso 5: Context Registry Redis | ⚠️ Parcial | PGRedisStore implementado |
| Paso 6: context_sessions | ⚠️ Parcial | Requiere migración SQL |
| Paso 7: Fichas DAG | ✅ Existe | `internal/installer/`, `internal/state/` |
| `bosctl tenant suspend X` | ✅ Via JSON-RPC | `bos.ctx.tenant.suspend` |
| `bosctl tenant remove X` | 🔴 No implementado | Necesita saga inversa |

**Criterio de aceptación C-2:**
```bash
# Flujo completo: alta de tenant
bosctl deploy seed-skull.yml
# Resultado: realm KC creado, namespace K8s, BDs, secretos Vault,
#            context registry, context_sessions, fichas instaladas

# Flujo: suspensión (invalida todos los ctx_id activos)
bosctl tenant suspend skull
```

---

### Contrato C-3 — Gestión de Fichas (DAG Topológico + 18 Estados)

**Qué requiere el Proyecto Master (§16):**

El BOS instala, repara, actualiza y elimina fichas en **orden topológico garantizado**.
Cada ficha transita por hasta **18 estados** (PENDIENTE → INSTALADA → ... → DESINSTALADA).
El BOS monitorea constantemente y actúa según el estado.

```
Ficha SBOS = manifest.yml + yaml_engine.yml + task_catalog.sh + resources/
```

**Estado de implementación:**

| Capacidad | Archivo | Estado |
|-----------|---------|--------|
| 18 estados de ficha | `internal/state/manager.go` | ✅ Implementado |
| Saga install con compensación | `internal/installer/saga.go:161` | ✅ Implementado |
| Saga update | `internal/installer/saga.go:168` | ✅ Implementado |
| Saga repair | `internal/installer/saga.go:179` | ✅ Implementado |
| Saga remove | `internal/installer/saga.go:186` | ✅ Implementado |
| Saga probe (dry-run) | `internal/installer/saga.go:193` | ✅ Implementado |
| JSON-RPC bos.ficha.* (8 métodos) | `internal/server/jsonrpc.go:189` | ✅ Implementado |
| DAG topológico de dependencias | `internal/catalog/` | ⚠️ Verificar |
| `bosctl ficha repair <nombre>` | `cmd/bosctl/repair.go` | ✅ Implementado |
| `bosctl install <ficha>` | `cmd/bosctl/main.go:32` | ✅ Implementado |
| Fichas declarativas en `servers/` | `servers/` | ✅ Estructura existe |
| bos-preflight ficha (dependencias SO) | `servers/S-HOST/bos-preflight/` | ✅ Implementado |
| 112+ fichas completas | `servers/` | 🔴 Pendiente — solo bos-preflight |

**Criterio de aceptación C-3:**
```bash
# Las fichas críticas se instalan en orden correcto
bosctl install postgresql
bosctl install redis
bosctl install keycloak  # Solo después de postgresql
bosctl ficha status postgresql
# Retorna: INSTALADA v18.4
```

---

### Contrato C-4 — Interface Dual (ADR-019/020)

**Qué requiere el Proyecto Master + ADR-019/020:**

El BOS expone **todas sus operaciones** por dos vías paralelas sobre el mismo
Unix socket. HTTP entre daemons está vetado (SBOS-050 P9).

```
┌─────────────────────────────────────────────────────────────┐
│  Vía 1: WebSocket RPC  →  bosctl CLI, Core UI, humanos     │
│  Vía 2: JSON-RPC 2.0   →  biedata, bAuth, bSearch, IA      │
│                                                              │
│  Transporte: /run/bos/bos.sock (0660, grupo bos)            │
│  NUNCA HTTP/TCP — cumple SBOS-050 P9                        │
└─────────────────────────────────────────────────────────────┘
```

**Estado de implementación:**

| Capacidad | Archivo | Estado |
|-----------|---------|--------|
| Unix socket `/run/bos/bos.sock` | `internal/server/ws.go` | ✅ Implementado |
| WebSocket RPC (Vía 1) | `internal/server/ws.go` | ✅ Implementado |
| JSON-RPC 2.0 (Vía 2) | `internal/server/jsonrpc.go` | ✅ Implementado |
| 50+ métodos JSON-RPC | `internal/server/jsonrpc.go:186` | ✅ Implementado |
| bos.ficha.* | — | ✅ 8 métodos |
| bos.bootstrap.* | — | ✅ 6 métodos |
| bos.ctx.* | — | ✅ 10 métodos |
| bos.k8s.* | — | ✅ 10 métodos |
| bos.query.* | — | ✅ 6 métodos |
| bos.ai.*, bos.release.* | — | ✅ Implementados |
| bos.tenant.* (saga alta/baja) | — | 🔴 Pendiente |
| bos.ctx.device.register | — | ✅ Implementado |
| bos.ctx.promote | — | ✅ Implementado |

**Criterio de aceptación C-4:**
```bash
# Daemon-to-daemon (JSON-RPC sobre Unix socket)
echo '{"jsonrpc":"2.0","method":"bos.health.check","params":{},"id":1}' \
  | nc -U /run/bos/bos.sock
# {"jsonrpc":"2.0","result":{"status":"healthy"},"id":1}

# bosctl (WebSocket sobre Unix socket)
bosctl health
# OK — bos.service activo
```

---

### Contrato C-5 — Context API HTTPS (:9443) para Kong

**Qué requiere el Proyecto Master (§3.4, §6.4):**

Kong API Gateway necesita validar el `ctx_id` de **cada request** que pasa por él.
Para ello, el Kong Plugin SBOS-Context llama a la Context API del BOS en `:9443`.
Esta es la ruta crítica de **cada operación del sistema**.

```
Request de usuario llega a Kong
    │
Kong Plugin extrae ctx_id del header baggage
    │
GET https://bos-host:9443/api/v1/context/{ctx_id}   ← BOS debe responder <5ms
    │
¿ctx_id válido y TTL > 0?
  SÍ → adjunta tenant, empresa, sucursal, bitmask como headers X-SBOS-*
  NO → HTTP 401
```

**Estado de implementación:**

| Endpoint | Estado | Notas |
|----------|--------|-------|
| `GET /api/v1/context/{ctx_id}` | 🔴 No expuesto vía HTTPS | Solo JSON-RPC Unix socket |
| `POST /api/v1/context/create` | 🔴 No expuesto vía HTTPS | Solo JSON-RPC Unix socket |
| `POST /api/v1/context/switch` | 🔴 No expuesto vía HTTPS | Solo JSON-RPC Unix socket |
| `DELETE /api/v1/context/{ctx_id}` | 🔴 No expuesto vía HTTPS | Solo JSON-RPC Unix socket |
| `GET /api/v1/context/tenant/{t}` | 🔴 No expuesto vía HTTPS | Solo JSON-RPC Unix socket |
| Servidor HTTPS en :9443 | ⚠️ Parcial | Core UI API existe, no Context API |

> **Brecha crítica:** La lógica del Context Plane está implementada pero solo
> accesible vía Unix socket (JSON-RPC). Kong necesita HTTPS REST. Se requiere
> exponer los endpoints REST del Context Plane en el servidor :9443.

**Criterio de aceptación C-5:**
```bash
# Kong plugin puede validar ctx_id activo
curl -k https://127.0.0.1:9443/api/v1/context/ctx-88291-a4f9
# {"ctx_id":"ctx-88291-a4f9","tenant":"skull","ttl_s":28440,"bitmask":"0x00000000008C87FF"}

# Kong plugin recibe 404 para ctx_id inválido o expirado
curl -k https://127.0.0.1:9443/api/v1/context/ctx-invalido
# HTTP 404
```

### ANEXO C-5.A — Decisión de implementación (2026-06-17)

**Evaluación de seguridad previa a la implementación:**

Se investigaron tres patrones usados en la industria (Envoy ext_authz, Kong OIDC, NIST SP 800-228):

| Opción | Descripción | Riesgo | Adoptada |
|--------|------------|--------|----------|
| A — HTTP REST | Kong llama al BOS por HTTPS | Exposición TCP en el host | ✅ **Sí, con restricciones** |
| B — hostPath mount | Socket Unix compartido vía volumen K8s | CIS 1.1.17 — compartir filesystem host↔pod | ❌ |
| C — Solo JWT | Kong confía solo en el JWT | BOS no puede invalidar ctx_id sin revocar JWT | ❌ |

**Justificación de la Opción A:**
- El BOS es el Policy Administrator (NIST SP 800-207) — único dueño del Context Plane
- Kong no puede confiar solo en el JWT porque el BOS puede invalidar ctx_id en cualquier momento (suspensión de tenant, switch de sesión, evento de seguridad)
- No comparten filesystem (Kong en K8s, BOS en host) — el socket Unix no es accesible sin hostPath

**Restricciones de seguridad aplicadas:**
1. **Solo GET** `/api/v1/context/{ctx_id}` — Kong solo necesita validar, no escribir
2. **Sin POST/PUT/DELETE** — escritura sigue solo en Unix socket JSON-RPC
3. **Sin listado de tenants** — no se expone `GET /api/v1/context/tenant/{t}`
4. **Bind existente** — el puerto `:9443` ya está bindeado por el servidor; no se abre puerto nuevo
5. **Mismo handler HTTP** — se registra en el `http.ServeMux` existente junto a `/ws` y `/rpc`

**Implementación:** `internal/server/api.go:ListenAndServe()` — handler `handleContextLookup` que llama a `s.bosCtxSvc.Get(ctxID)`.

---

### Contrato C-6 — bosctl CLI Completa (23+ Comandos)

**Qué requiere el Proyecto Master (§3.5):**

```bash
# Ciclo de vida de tenants
bosctl deploy <seed.yml>
bosctl product install ai --tenant=X
bosctl tenant suspend X
bosctl tenant remove X
bosctl ficha repair postgresql

# Context Plane
bosctl context list --tenant=skull
bosctl context inspect ctx-88291-a4f9
bosctl context invalidate ctx-88291-a4f9
bosctl context history --user=3397708 --days=7

# Bootstrap
bosctl setup          ← wizard TUI (instalador)
bosctl system-install ← post-install inicial
bosctl bootstrap verify
```

**Estado de implementación:**

| Comando | Archivo | Estado |
|---------|---------|--------|
| `bosctl setup` (TUI wizard) | `cmd/bosctl/install_ui.go` | ✅ Implementado + Probado |
| `bosctl system-install` | `cmd/bosctl/system_install.go` | ✅ Implementado |
| `bosctl install` | `cmd/bosctl/main.go` | ✅ Implementado |
| `bosctl repair` | `cmd/bosctl/repair.go` | ✅ Implementado |
| `bosctl health` | `cmd/bosctl/main.go` | ✅ Implementado |
| `bosctl status` | `cmd/bosctl/main.go` | ✅ Implementado |
| `bosctl top` | `cmd/bosctl/top.go` | ✅ Implementado |
| `bosctl logs` | `cmd/bosctl/logs.go` | ✅ Implementado |
| `bosctl ctx` | `cmd/bosctl/context.go` | ✅ Implementado |
| `bosctl query` | `cmd/bosctl/query.go` | ✅ Implementado |
| `bosctl node` | `cmd/bosctl/daemon_commands.go` | ✅ Implementado |
| `bosctl ai ask` | `cmd/bosctl/ai.go` | ✅ Implementado |
| `bosctl bootstrap` | `cmd/bosctl/bootstrap.go` | ✅ Implementado |
| `bosctl release` | `cmd/bosctl/release.go` | ✅ Implementado |
| `bosctl vdi` | `cmd/bosctl/vdi.go` | ✅ Implementado |
| `bosctl identity` | `cmd/bosctl/identity.go` | ✅ Implementado |
| `bosctl deploy <seed.yml>` | — | 🔴 No implementado |
| `bosctl tenant suspend/remove` | — | 🔴 No implementado |
| `bosctl context history` | — | ⚠️ Parcial |
| `bosctl product install` | — | 🔴 No implementado |

**Criterio de aceptación C-6:**
```bash
bosctl deploy seed-skull.yml   # Alta de tenant completo
bosctl ctx list --tenant=skull # Lista ctx_id activos
bosctl tenant suspend skull    # Invalida todos los ctx_id
```

---

### Contrato C-7 — Reconciliación Day 2 (cada 15 min)

**Qué requiere el Proyecto Master (§3.3):**

El BOS verifica cada 15 minutos el **estado declarado vs. estado real** del sistema.
Detecta drift en configuraciones, versiones, estados de pods.
Repara multi-capa: SO → K8s → Fichas.

**Estado de implementación:**

| Capacidad | Archivo | Estado |
|-----------|---------|--------|
| Scheduler reconciliación | `internal/reconcile/scheduler.go:64` | ✅ Implementado |
| `ReconcileNow()` | `internal/reconcile/scheduler.go:122` | ✅ Implementado |
| Detección de drift | `internal/reconcile/scheduler.go:135` | ✅ Implementado |
| `ComputeHashes` para drift | `internal/reconcile/scheduler.go:230` | ✅ Implementado |
| `DriftSummary` | `internal/reconcile/scheduler.go:263` | ✅ Implementado |
| Intervalo 15 min configurable | `internal/reconcile/scheduler.go:64` | ✅ Implementado |
| Auto-repair en drift | `internal/reconcile/scheduler.go:64` | ✅ Implementado |
| JSON-RPC bos.query.repair | `internal/server/query_handlers.go` | ✅ Implementado |
| Reparación multi-capa SO | `internal/repair/` | ⚠️ Verificar alcance |
| Watchdog + auto-restart daemon | `internal/watchdog/` | ✅ Implementado |

**Criterio de aceptación C-7:**
```bash
# Reconciliación detecta y repara drift
bosctl query repair --ficha=postgresql
# Retorna: estado, drift detectado, acción tomada

# Watchdog mantiene el daemon activo
systemctl status bos.service  # Debe estar activo > 24h
```

---

## Mapa de Dependencias: ¿Qué necesitan los otros daemons del BOS?

| Daemon | Lo que necesita del BOS antes de arrancar |
|--------|------------------------------------------|
| **bAuth** | Keycloak 26.6.2 instalado (ficha). Unix socket `/run/bos/bauth.sock` creado. Puerto `:9450` reservado |
| **bKernel** | PostgreSQL 18.4 instalado (ficha). Redis 8.6.2 instalado (ficha). Puerto `:9460` reservado |
| **biedata** | Redis 8.6.2 instalado. PostgreSQL 18.4 instalado. Puerto `:9470` reservado |
| **bSearch** | PostgreSQL 18.4 instalado (índice busqueda_universal). Redis Stream `bkernel:index_queue` funcional. Puerto `:9493` reservado |
| **bhnexus** | bAuth operativo. Unix socket `/run/bos/bauth.sock` funcional. Puerto `:9444` reservado |
| **Kong** | BOS Context API en `:9443` respondiendo. Keycloak operativo. Vault operativo |
| **Aplicaciones** | Tenant provisionado (saga 7 pasos). Fichas instaladas. ctx_id válidos disponibles |

---

## Estado Global — Semáforo de Contratos

| Contrato | Descripción | Estado | Prioridad |
|----------|-------------|--------|-----------|
| **C-1** | Context Plane (dueño) | ✅ 80% | Alta |
| **C-2** | Ciclo de vida tenants | 🔴 20% | Alta |
| **C-3** | Gestión de fichas + 18 estados | ✅ 75% | Alta |
| **C-4** | Interface Dual (JSON-RPC) | ✅ 90% | Completado |
| **C-5** | Context API HTTPS (:9443) | 🔴 30% | **Crítica** |
| **C-6** | bosctl CLI | ✅ 70% | Media |
| **C-7** | Reconciliación Day 2 | ✅ 80% | Media |

---

## Brecha Inmediata — Bloqueante de la Instalación en Curso

El `bos.service` falla al arrancar porque `autoBootstrap()` en
`internal/bootstrap/setup.go` busca scripts legados que ya no existen
en la arquitectura nueva (fichas declarativas).

```
Error actual:
fatal: dependencia crítica ausente: /opt/bos/core/00_MASTER_INSTALL_SBOS.sh
```

**Corrección requerida:**
Hacer el chequeo de scripts legados no-fatal. El daemon debe iniciar,
crear el socket, y esperar en modo `runConfigPending()` para que el
wizard TUI pueda conectarse.

**Archivo a modificar:** `internal/bootstrap/setup.go:169-181`
**Cambio:** `return fmt.Errorf(...)` → `log.Warn().Msg(...)` para los scripts legados.

---

## Orden de Implementación Recomendado

```
AHORA (desbloqueante):
  ① Corregir setup.go — hacer no-fatal el chequeo de scripts legados
     → bos.service arranca → socket creado → TUI conecta

CORTO PLAZO (completar C-1 y C-5):
  ② Exponer Context API REST en :9443
     → Kong puede validar ctx_id → flujo de auth completo

  ③ DDL context_sessions + migración SQL automática al arrancar
     → Persistencia real del Context Plane en PostgreSQL

MEDIANO PLAZO (C-2 y C-6):
  ④ Saga `bosctl deploy <seed.yml>` — 7 pasos con compensación
     → Primer tenant de producción posible

  ⑤ bosctl tenant suspend/remove
     → Ciclo de vida completo

LARGO PLAZO (fichas completas — C-3):
  ⑥ 112+ fichas declarativas en servers/
     → Stack SBOS completo instalable con un comando
```

---

## Criterio de "BOS Listo para el Ecosistema"

El BOS cumple los contratos del SBOS_Proyecto_Master.md cuando:

```
[ ] bos.service arranca sin errores en Ubuntu 26.04 virgen
[ ] /run/bos/bos.sock creado, permisos 0660, grupo bos
[ ] bosctl setup TUI completa el wizard y ejecuta la instalación
[ ] Stack Day 0 instalado: PG18.4, Redis8.6.2, KC26.6.2, Vault2.0, Kong3.9
[ ] GET :9443/api/v1/context/{ctx_id} responde en <5ms
[ ] context.promoted emitido al autenticar un usuario
[ ] bosctl deploy seed.yml alta un tenant en <10 min
[ ] Reconciliación detecta un pod caído y lo repara sin intervención humana
[ ] 0 secretos hardcodeados — todo en Vault
[ ] audit_events con ctx_id en cada operación
```

---

*BOS-CONTRATOS-SBOS.md v1.0 · SKULL · SBOS · Junio 2026*  
*Referencia: SBOS_Proyecto_Master.md v2.1 · BosAgent/src/ · ADR-019, ADR-020, ADR-022 · SBOS-050 P9*
