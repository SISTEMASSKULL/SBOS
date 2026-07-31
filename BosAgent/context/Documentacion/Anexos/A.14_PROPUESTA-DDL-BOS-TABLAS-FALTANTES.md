# Anexo A.14 — DDL BOS: Schema `bos` completo (18 tablas · 7 grupos)
## Estado de implementación + correcciones de naming aplicadas

**Versión:** 6.0.0
**Fecha:** 2026-07-31
**Autor:** bos-developer — SBOS
**Estado:** ✅ COMMITEADO — commits `762a7ad` (T-403..5) + `1d2e7c2` (T-408..10) + correcciones naming
**Archivo DDL:** `DDLs/bos_01__control_plane.sql`
**Referencia:** `1.01_MANUAL-IAM-INSTALLER.md §3.7` · `3.01_MANUAL-SERVER-FICHAS.md`
· `2.02_MANUAL-SO-OBSERVABLE-CAPACIDAD.md` · `A.12_ANEXO-PORT-MANAGER-KARDEX.md`

**Cambios v6.0.0 (respecto v5.0.0):**
- T-408..10 añadidas al DDL: Port Manager, Release Plane (×2), Watchdog, Sagas generales
- **Correcciones de naming** — todos los nombres de tablas y columnas ahora en inglés:
  - `bos.cap_tenant_politica` → `bos.cap_tenant_policy` · `politica_id` → `policy_id`
  - 18 estados máquina fichas: PENDIENTE→PENDING, DEGRADADA→DEGRADED, etc.
  - `fichas_healthy/degraded/error/total` → `units_healthy/degraded/error/total`
  - 12 columnas de `prt_port_assignment`: español → inglés (`estado`→`status`, `asignado_en`→`assigned_at`, etc.)
  - `puerto` → `port`, `tipo_puerto` → `port_type`, `tipo_t` → `port_role`
  - CHECK values de status: `'asignado'`→`'assigned'`, `'liberado'`→`'released'`, etc.

**Resumen de seed obligatorio:**
```
Orden de inserción en el seed de creación de SBOS_db:
  1. bauth.idn_tenant            → tenant raíz (UUID fijo, superadmin de tenants)
  2. bauth.idn_identity_entity   → empresa master  (entity_1_id de ctx_context_session)
  3. bauth.idn_identity_entity   → sucursal master (entity_2_id opcional)
  4. bos.cap_tenant_policy       → política de capacidad del tenant raíz (defaults globales)
```

---

## 1. Principio de clasificación

El schema `bos` organiza sus tablas en **grupos funcionales** identificados por un
prefijo de 3 letras que corresponde al motor BOS que las posee:

```
bos.<GROUP>_<ENTITY>_<object>
     ──┬──   ──┬──   ──┬──
       │       │       └── tipo de registro: state, event, snapshot, policy, manifest…
       │       └── la cosa concreta: context, device, ficha, bootstrap, port, release…
       └── grupo 3 letras = motor dueño

     CTX  Motor ④ Context Plane         (8 tablas — ya existentes, referencia)
     FCH  Motor ③ Server FICHAS          (2 tablas)
     INS  Motor ① IAM Installer          (2 tablas: bootstrap + sagas)
     CAP  Motor ② SO Observable/Cap.    (2 tablas)
     PRT  Port Manager (RFC 6335)        (1 tabla)
     REL  Release Plane                  (2 tablas)
     WDG  Motor ② SO Observable/Watch.  (1 tabla)
```

**Regla:** inglés para todos los identificadores SQL (tablas, columnas, constraints,
índices, valores CHECK). Español solo en comentarios y COMMENT ON.

---

## 2. Grupo CTX — Motor ④ Context Plane · 8 tablas ✅ COMPLETO

**Prefijo:** `bos.ctx_*` · **Propietario:** `bos.ctx.*` (JSON-RPC)

| Tabla | T# | WORM | Propósito |
|---|:---:|:---:|---|
| `bos.ctx_registered_device` | T-395 | — | Dispositivos pre-auth (dctx_id, BitMask=0, TTL 8h) |
| `bos.ctx_context_session` | T-396 | — | Sesiones post-auth (ctx_id, BitMask>0, TTL 12h) |
| `bos.ctx_context_audit` | T-397 | 🔒 | Auditoría WORM de toda operación del Context Plane |
| `bos.ctx_context_switch_log` | T-398 | 🔒 | Historial WORM de cambios de contexto sin reautenticación |
| `bos.ctx_context_policy` | T-399 | — | Políticas TTL/seguridad por tenant |
| `bos.ctx_device_heartbeat` | T-400 | — | Heartbeats de dispositivos (alta escritura, 24h retención) |
| `bos.ctx_context_transfer` | T-401 | 🔒 | Transferencia de contexto entre dispositivos |
| `bos.ctx_context_emergency` | T-402 | 🔒 | Break-glass (control dual, TTL 2h, revisión 24h) |

> Todas las columnas están en inglés. Estado de la máquina de sesiones:
> `'PENDING','ACTIVE','SUSPENDED','BLOCKED','INVALIDATED','EXPIRED','ARCHIVED'`

---

## 3. Grupo FCH — Motor ③ Server FICHAS · 2 tablas ✅ COMMITEADO

**Prefijo:** `bos.fch_*` · **Propietario:** `bos.ficha.*` (JSON-RPC)

| Tabla | T# | WORM | Propósito |
|---|:---:|:---:|---|
| `bos.fch_ficha_state` | T-403 | — | Estado actual fichas (máquina 18 estados, sin tenant_id) |
| `bos.fch_ficha_event` | T-404 | 🔒 | Historial WORM de eventos de fichas |

### Máquina de 18 estados (ADR-021) — valores en inglés

| Estado | Significado |
|---|---|
| `PENDING` | Registrada, sin iniciar instalación |
| `READY` | Lista para instalar (preflight OK) |
| `INSTALLING` | Instalación en curso |
| `INSTALLED` | Instalada y operativa |
| `UPDATE_AVAILABLE` | Nueva versión disponible |
| `UPDATE_APPROVED` | Actualización aprobada (HITL) |
| `UPDATING` | Actualización en curso |
| `DEGRADED` | Funcional con degradación detectada |
| `PHYSICAL_ERROR` | Error en el nivel de infraestructura física |
| `LOGICAL_ERROR` | Error en la configuración/lógica |
| `REPAIRING` | Reparación automática en curso |
| `UNRECOVERABLE` | No recuperable automáticamente (HITL) |
| `INSTALL_FAILED` | Fallo en instalación |
| `UPDATE_FAILED` | Fallo en actualización |
| `ROLLBACK` | Revirtiendo a versión anterior |
| `CLEANUP` | Limpieza de recursos en curso |
| `PAUSED` | Pausada por operador |
| `UNINSTALLED` | Desinstalada completamente |

**Principio:** las fichas son componentes de plataforma compartidos. Sin `tenant_id`.
El `tenant_id` en `fch_ficha_event` indica quién disparó el evento, no el dueño.

**Decisiones HITL — cerradas:**

| # | Estado | Decisión |
|:---:|:---:|---|
| Q1 | ✅ | Las fichas no tienen `tenant_id`. Son plataforma, no instancias por tenant |

---

## 4. Grupo INS — Motor ① IAM Installer · 2 tablas ✅ COMMITEADO

**Prefijo:** `bos.ins_*` · **Propietario:** `bos.bootstrap.*` / `bos.installer.*` (JSON-RPC)

| Tabla | T# | WORM | Propósito |
|---|:---:|:---:|---|
| `bos.ins_bootstrap_event` | T-405 | 🔒 | Bootstrap progresivo 6 capas. Capas 0-2: tenant raíz |
| `bos.ins_saga_execution` | T-412 | — | Tracking mutable de sagas (install/update/repair/remove/tenant) |

**Diseño `ins_bootstrap_event`:** `tenant_id NOT NULL` siempre. El tenant raíz
(seed #1) gobierna las capas 0-2. `bootstrap_run_id` agrupa todos los eventos
de un mismo intento end-to-end.

**Diseño `ins_saga_execution`:** mutable (state cambia RUNNING→COMPLETED/FAILED).
No WORM por diseño — el estado en curso necesita actualizarse. `compensated_steps`
registra los pasos revertidos en orden inverso.

**Decisiones HITL — cerradas:**

| # | Estado | Decisión |
|:---:|:---:|---|
| Q3 | ✅ | `tenant_id NOT NULL`. Capas 0-2 usan tenant raíz (seed garantizado) |

---

## 5. Grupo CAP — Motor ② SO Observable / Capacidad · 2 tablas ✅ COMMITEADO

**Prefijo:** `bos.cap_*` · **Propietario:** `bos.capacity.*` (JSON-RPC)

| Tabla | T# | WORM | Propósito |
|---|:---:|:---:|---|
| `bos.cap_sistema_snapshot` | T-406 | — | 30+ métricas cada 60s (particionado mensual) |
| `bos.cap_tenant_policy` | T-407 | — | Políticas por tenant (fallback = fila del tenant raíz) |

**Correcciones v6.0.0:**
- `bos.cap_tenant_politica` → `bos.cap_tenant_policy`
- `politica_id` → `policy_id`
- `fichas_healthy/degraded/error/total` → `units_healthy/degraded/error/total`

**Diseño `cap_sistema_snapshot`:** `PARTITION BY RANGE (captured_at)` mensual.
`units_*` = contadores de fichas por estado. Purga: cron `DROP TABLE` sobre
particiones con rango terminado hace más de 90 días (instantáneo, sin contención).

**Diseño `cap_tenant_policy`:** `UNIQUE(tenant_id)`. El Motor M5.3 usa la fila
del tenant raíz como fallback global para tenants sin política configurada.
`policy_mode`: `autonomous|recommend|block_and_alert|emergency`.

**Decisiones HITL — cerradas:**

| # | Estado | Decisión |
|:---:|:---:|---|
| Q5 | ✅ | Particionado mensual + cron DROP (complementarios) |
| Q6 | ✅ | Columna `scope` con CHECK (`'GLOBAL'`,`'TENANT'`) |
| Q7 | ✅ | Fallback = fila del tenant raíz. `tenant_id NOT NULL` se mantiene |
| Q8 | ✅ | `entity_1_id UUID NOT NULL FK` se mantiene. Empresa master en seed |

---

## 6. Grupo PRT — Port Manager · 1 tabla ✅ COMMITEADO

**Prefijo:** `bos.prt_*` · **Propietario:** `bos.portman.*` (JSON-RPC)
**Referencia:** `A.12_ANEXO-PORT-MANAGER-KARDEX.md` · RFC 6335 BCP 165 · ISO 27001 A.8.20

| Tabla | T# | WORM | Propósito |
|---|:---:|:---:|---|
| `bos.prt_port_assignment` | T-408 | — | Kardex de puertos. Inmutabilidad lógica (RFC 6335 §8) |

### Columnas (v6.0.0 — todas en inglés)

| Columna | Tipo | Descripción |
|---|---|---|
| `port_id` | UUID PK | UUIDv7 |
| `service_name` | TEXT | RFC 6335 §5.1: `sbos-<ficha>-<role>`, 1-15 chars |
| `port` | INTEGER | Número de puerto 1024-49151 |
| `transport` | TEXT | `TCP\|UDP\|SCTP\|DCCP` |
| `assigned_by` | TEXT | `"bos.ficha.install"` (RFC 6335 field 3) |
| `ficha_id` | TEXT | Contact ficha (RFC 6335 field 4) |
| `description` | TEXT | Descripción (RFC 6335 field 5) |
| `doc_reference` | TEXT | Referencia documental (RFC 6335 field 6) |
| `port_type` | TEXT | `containerPort\|ClusterIP\|NodePort\|hostPort\|daemonPort` |
| `logical_server` | TEXT | `S00..S16, S-HOST` |
| `namespace` | TEXT | Namespace K8s. NULL para host/daemon |
| `container_port` | INTEGER | Puerto canónico del contenedor |
| `port_role` | SMALLINT | 0=HTTP, 1=HTTPS, 2=metrics, 3=health, 4=admin, 5=grpc, 6=WS |
| `cluster_ip` | TEXT | IP del K8s Service |
| `external_ip` | TEXT | IP externa (MetalLB VIP, WireGuard) |
| `dns_name` | TEXT | FQDN del servicio |
| `asset_type` | TEXT | `ficha\|daemon\|logical_server\|k8s_node\|k8s_service\|kong_route` |
| `asset_id` | TEXT | ID del activo |
| `asset_owner` | TEXT | Responsable (tenant, sistema) |
| `labels` | JSONB | Metadatos operativos |
| `subdomain` | TEXT | FQDN externo del subdominio |
| `kong_route` | TEXT | Ruta Kong: `/auth → 8200` |
| `status` | TEXT | `assigned\|released\|revoked\|conflict` |
| `assigned_at` | TIMESTAMPTZ | Fecha de asignación |
| `released_at` | TIMESTAMPTZ | Fecha de liberación (NOT NULL cuando `status=released`) |
| `last_validated_at` | TIMESTAMPTZ | Última validación por `portman.validate` |
| `notes` | TEXT | Observaciones libres |
| `ctx_id` | TEXT | Trazabilidad SBOS-049 |

**Inmutabilidad lógica:** las filas nunca se borran (RFC 6335 §8 "De-Assignment").
Solo cambian de estado: `assigned → released → revoked`.
`check_prt_pa_release_state` garantiza que `released_at IS NOT NULL` cuando `status='released'`.

---

## 7. Grupo REL — Release Plane · 2 tablas ✅ COMMITEADO

**Prefijo:** `bos.rel_*` · **Propietario:** subsistema Release Plane (`run_normal.go` #10)
**Referencia:** SBOS-RELEASE-001 · ISO 27001 A.8.32 · NIST CM-3 · ITIL 4 Change Enablement

| Tabla | T# | WORM | Propósito |
|---|:---:|:---:|---|
| `bos.rel_release_manifest` | T-409 | — | Catálogo de releases por canal (canary→early→stable) |
| `bos.rel_release_event` | T-410 | 🔒 | Historial de actualizaciones y rollbacks |

**`rel_release_manifest`:** No WORM (el canal puede cambiar: canary→stable). Contiene
`artifact_sha256` (64 hex chars) y `signature_ed25519` verificados antes de instalar.
`is_rollback_target`: el watchdog puede usar este manifest para rollback de 60s.

**`rel_release_event` (WORM):** `operation IN ('INSTALL','UPDATE','ROLLBACK')`.
`triggered_by IN ('scheduler','watchdog','human')`. El watchdog registra tanto el
intento fallido (result='FAIL') como el rollback subsecuente en eventos separados.

---

## 8. Grupo WDG — Motor ② SO Observable / Watchdog · 1 tabla ✅ COMMITEADO

**Prefijo:** `bos.wdg_*` · **Propietario:** subsistema Watchdog Unificado (`run_normal.go` #9)
**Referencia:** ISO 27001 A.8.16 · NIST AU-2, AU-12 · ITIL 4 Incident Management

| Tabla | T# | WORM | Propósito |
|---|:---:|:---:|---|
| `bos.wdg_watchdog_event` | T-411 | 🔒 | Watchdog 3 capas: host, k8s_cluster, bos_fichas |

**3 capas de verificación (cada 30s):**
- `ubuntu_host`: disco > 80%, RAM > 85%, load avg, swap
- `k8s_cluster`: nodos `NotReady`, pods `CrashLoop`/`OOMKilled`, PVCs pendientes
- `bos_fichas`: fichas en `DEGRADED`/`PHYSICAL_ERROR`/`LOGICAL_ERROR`, health checks fallidos

`action_taken`: `auto_repair|hitl_escalated|daemon_restart|rollback|none`.
`resolved_at NULL` = evento aún activo. Eventos `CRITICAL` sin `resolved_at` son HITL.

---

## 9. Resumen consolidado

### 9.1 Cuadro completo — 18 tablas en 7 grupos

```
schema bos — 18 tablas · 7 grupos · 8 tablas WORM
──────────────────────────────────────────────────────────────────────────
GRUPO CTX — Motor ④ Context Plane                          8 tablas ✅
──────────────────────────────────────────────────────────────────────────
  bos.ctx_registered_device    T-395  — Dispositivos pre-auth
  bos.ctx_context_session      T-396  — Sesiones post-auth
  bos.ctx_context_audit        T-397  — Auditoría WORM 🔒
  bos.ctx_context_switch_log   T-398  — Context switch WORM 🔒
  bos.ctx_context_policy       T-399  — Políticas TTL/seguridad por tenant
  bos.ctx_device_heartbeat     T-400  — Heartbeats (24h retención)
  bos.ctx_context_transfer     T-401  — Transferencias WORM 🔒
  bos.ctx_context_emergency    T-402  — Break-glass WORM 🔒

GRUPO FCH — Motor ③ Server FICHAS                          2 tablas ✅
──────────────────────────────────────────────────────────────────────────
  bos.fch_ficha_state          T-403  — Estado actual 18 estados
  bos.fch_ficha_event          T-404  — Historial WORM 🔒

GRUPO INS — Motor ① IAM Installer                          2 tablas ✅
──────────────────────────────────────────────────────────────────────────
  bos.ins_bootstrap_event      T-405  — Bootstrap 6 capas WORM 🔒
  bos.ins_saga_execution       T-412 — Sagas generales (mutable)

GRUPO CAP — Motor ② SO Observable / Capacidad             2 tablas ✅
──────────────────────────────────────────────────────────────────────────
  bos.cap_sistema_snapshot     T-406  — 30+ métricas cada 60s (particionado)
  bos.cap_tenant_policy        T-407  — Políticas por tenant (← v6: renombrada)

GRUPO PRT — Port Manager (RFC 6335 BCP 165)               1 tabla  ✅
──────────────────────────────────────────────────────────────────────────
  bos.prt_port_assignment      T-408  — Kardex de puertos (lógicamente inmutable)

GRUPO REL — Release Plane (SBOS-RELEASE-001)              2 tablas ✅
──────────────────────────────────────────────────────────────────────────
  bos.rel_release_manifest     T-409  — Catálogo releases por canal
  bos.rel_release_event        T-410  — Actualizaciones/rollbacks WORM 🔒

GRUPO WDG — Motor ② SO Observable / Watchdog              1 tabla  ✅
──────────────────────────────────────────────────────────────────────────
  bos.wdg_watchdog_event       T-411  — Watchdog 3 capas WORM 🔒
──────────────────────────────────────────────────────────────────────────
```

### 9.2 Correcciones de naming v6.0.0

| Elemento | Antes (español) | Ahora (inglés) |
|---|---|---|
| Tabla | `bos.cap_tenant_politica` | `bos.cap_tenant_policy` |
| Columna | `politica_id` | `policy_id` |
| Estado ficha | `PENDIENTE` | `PENDING` |
| Estado ficha | `LISTA` | `READY` |
| Estado ficha | `INSTALANDO` | `INSTALLING` |
| Estado ficha | `INSTALADA` | `INSTALLED` |
| Estado ficha | `ACTUALIZACION_DISPONIBLE` | `UPDATE_AVAILABLE` |
| Estado ficha | `ACTUALIZACION_APROBADA` | `UPDATE_APPROVED` |
| Estado ficha | `ACTUALIZANDO` | `UPDATING` |
| Estado ficha | `DEGRADADA` | `DEGRADED` |
| Estado ficha | `ERROR_FISICO` | `PHYSICAL_ERROR` |
| Estado ficha | `ERROR_LOGICO` | `LOGICAL_ERROR` |
| Estado ficha | `REPARANDO` | `REPAIRING` |
| Estado ficha | `ERROR_NO_CORREGIBLE` | `UNRECOVERABLE` |
| Estado ficha | `FALLA_INSTALACION` | `INSTALL_FAILED` |
| Estado ficha | `FALLA_ACTUALIZACION` | `UPDATE_FAILED` |
| Estado ficha | `LIMPIEZA` | `CLEANUP` |
| Estado ficha | `PAUSADA` | `PAUSED` |
| Estado ficha | `DESINSTALADA` | `UNINSTALLED` |
| Columna snapshot | `fichas_healthy` | `units_healthy` |
| Columna snapshot | `fichas_degraded` | `units_degraded` |
| Columna snapshot | `fichas_error` | `units_error` |
| Columna snapshot | `fichas_total` | `units_total` |
| Columna port | `puerto` | `port` |
| Columna port | `asignado_por` | `assigned_by` |
| Columna port | `descripcion` | `description` |
| Columna port | `referencia_doc` | `doc_reference` |
| Columna port | `tipo_puerto` | `port_type` |
| Columna port | `servidor_logico` | `logical_server` |
| Columna port | `subdominio` | `subdomain` |
| Columna port | `ruta_kong` | `kong_route` |
| Columna port | `tipo_t` | `port_role` |
| Columna port | `estado` | `status` |
| Columna port | `asignado_en` | `assigned_at` |
| Columna port | `liberado_en` | `released_at` |
| Columna port | `ultima_validacion` | `last_validated_at` |
| Columna port | `notas` | `notes` |
| CHECK value | `'asignado'` | `'assigned'` |
| CHECK value | `'liberado'` | `'released'` |
| CHECK value | `'revocado'` | `'revoked'` |
| CHECK value | `'en_conflicto'` | `'conflict'` |

### 9.3 FKs inter-schema y dentro de bos

```
FKs a bauth (cross-schema):
  bos.* → bauth.idn_tenant(tenant_id)
  bos.* → bauth.idn_identity_entity(entity_id)     ← actor_id, installed_by, updated_by
  bos.rel_release_event → bauth.idn_identity_entity (actor_id)

FKs intra-bos:
  ctx_device_heartbeat  → ctx_registered_device
  ctx_context_session   → ctx_registered_device
  ctx_context_audit     → ctx_context_session (nullable)
  ctx_context_switch_log→ ctx_context_session (old + new)
  ctx_context_transfer  → ctx_registered_device (from + to)
  ctx_context_emergency → ctx_context_session (resulting_ctx_id, nullable)
  fch_ficha_event       → fch_ficha_state
  rel_release_event     → rel_release_manifest
```

### 9.4 Impacto en Go — código a actualizar

El renaming de los 18 estados afecta `internal/ficha/` y `internal/state/types.go`.
Los valores de `FichaState` en Go deben coincidir con los CHECK del DDL.

| Constante Go (antes) | Constante Go (propuesta) |
|---|---|
| `"PENDIENTE"` | `"PENDING"` |
| `"DEGRADADA"` | `"DEGRADED"` |
| `"REPARANDO"` | `"REPAIRING"` |
| ... | ... (ver tabla 9.2 completa) |

> **Nota:** este cambio afecta también `.sbos_state.json` y los logs existentes.
> Recomendado: migración en un commit único `refactor(state): 18-state machine EN`.

---

## 10. Registro de decisiones HITL — todas cerradas

| # | Afecta | Estado | Fecha |
|:---:|---|:---:|---|
| Q1 | `fch_ficha_state` — ¿tenant_id? | ✅ CERRADA | 2026-07-31 |
| Q3 | `ins_bootstrap_event` — ¿tenant_id NULL en capas 0-2? | ✅ CERRADA | 2026-07-31 |
| Q5 | `cap_sistema_snapshot` — ¿retención por job o partición? | ✅ CERRADA | 2026-07-31 |
| Q6 | `cap_sistema_snapshot` — ¿columna `scope`? | ✅ CERRADA | 2026-07-31 |
| Q7 | `cap_tenant_policy` — ¿defaults globales? | ✅ CERRADA | 2026-07-31 |
| Q8 | `ctx_context_session` — ¿`entity_1_id` UUID vs TEXT? | ✅ CERRADA | 2026-07-31 |

**Q1:** fichas son plataforma compartida, no instancias por tenant. Sin `tenant_id`.
**Q3:** `tenant_id NOT NULL` siempre. Capas 0-2 usan el tenant raíz (seed garantizado).
**Q5:** AMBAS — particionado mensual + cron `DROP TABLE` para particiones > 90 días.
**Q6:** columna `scope TEXT CHECK ('GLOBAL','TENANT')` con constraint de coherencia.
**Q7:** fila del tenant raíz como fallback global. Motor M5.3 hace lookup cascada.
**Q8:** `entity_1_id UUID NOT NULL FK` se mantiene. Empresa master siempre existe (seed).

---

*SKULL · SBOS · BosAgent — DDL BOS v6.0.0 · 2026-07-31 · ✅ 18 tablas · 7 grupos · NAMING 100% INGLÉS*
