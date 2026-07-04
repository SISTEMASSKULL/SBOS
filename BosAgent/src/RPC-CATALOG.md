# RPC-CATALOG — BOS JSON-RPC 2.0 (M4.1)

**Generado:** 2026-06-29  
**Daemon:** `bos.service` en VPS `13.140.128.230`  
**Socket:** `/run/bos/bos.sock` (Vía 2 raw — JSON + `\n`, Vía 1 WebSocket)  
**Métodos auditados:** 59  
**Resultado:** ✅ 33 OK · ⚠️ 26 EXPECTED · ❌ 0 FAIL

**Protocolo Vía 2 (daemons ↔ bos):**
- Enviar: `{"jsonrpc":"2.0","method":"...","params":{...},"id":N}\n`
- Recibir: respuesta JSON terminada en `\n`
- Auth destructivos: campo `"_token"` o header Bearer en Vía 1

---

## Módulo HEALTH / STATE

| Método | Estado | ms P50 | Notas |
|--------|--------|--------|-------|
| `bos.health.check` | ✅ OK | 2ms | `fichas_ok`, `fichas_total`, `healthy` |
| `bos.health.check {"ficha_id":"..."}` | ✅ OK | 1ms | health por ficha individual |
| `bos.state.read` | ✅ OK | 2ms | lee `.sbos_state.json` |

---

## Módulo FICHA

| Método | Estado | ms P50 | Notas |
|--------|--------|--------|-------|
| `bos.ficha.list` | ✅ OK | 2ms | 29 fichas detectadas en `/etc/bos/blibs/servers` |
| `bos.ficha.rescan` | ✅ OK | 1ms | re-escanea directorio de fichas |
| `bos.ficha.status {"ficha_id":"..."}` | ✅ OK | 2ms | estado de una ficha individual |
| `bos.ficha.describe {"ficha_id":"..."}` | ✅ OK | 1ms | manifiesto completo de la ficha |
| `bos.ficha.plan {"ficha_id":"..."}` | ✅ OK | 0ms | plan de instalación sin ejecutar |
| `bos.ficha.diff {"ficha_id":"..."}` | ✅ OK | 0ms | diff entre versión instalada y disponible |
| `bos.ficha.validate {"ficha_id":"..."}` | ✅ OK | 0ms | valida manifiesto sin instalar |
| `bos.ficha.logs {"ficha_id":"..."}` | ✅ OK | 0ms | logs recientes de la ficha |
| `bos.ficha.probe {"ficha_id":"..."}` | ✅ OK | 159ms | dry-run de instalación (verifica deps) |
| `bos.ficha.scale {"ficha_id":"...","replicas":N}` | ⚠️ INTERNAL | 1ms | acceso K8s scaling no disponible aún (F9) |
| `bos.ficha.pause {"ficha_id":"..."}` | ✅ OK | 1ms | pausa ficha (estado PAUSADA) |
| `bos.ficha.resume {"ficha_id":"..."}` | ✅ OK | 0ms | reanuda ficha pausada |
| `bos.ficha.install {"ficha_id":"..."}` | ⚠️ AUTH | 0ms | **requiere `_token`** |
| `bos.ficha.update {"ficha_id":"..."}` | ⚠️ AUTH | 0ms | **requiere `_token`** |
| `bos.ficha.repair {"ficha_id":"..."}` | ⚠️ AUTH | 0ms | **requiere `_token`** |
| `bos.ficha.remove {"ficha_id":"..."}` | ⚠️ AUTH | 0ms | **requiere `_token`** |

---

## Módulo BOOTSTRAP

| Método | Estado | ms P50 | Notas |
|--------|--------|--------|-------|
| `bos.bootstrap.status` | ✅ OK | 1ms | fase actual del bootstrap |
| `bos.bootstrap.verify` | ✅ OK | 1505ms | 8/8 C-01..C-08 certificados ✅ |
| `bos.bootstrap.start {"mode":"..."}` | ⚠️ AUTH | — | **requiere `_token`** |
| `bos.bootstrap.resume` | ⚠️ AUTH | — | **requiere `_token`** |
| `bos.bootstrap.pg_auxiliar_status` | ✅ OK | 1ms | estado PG auxiliar para multi-BD |
| `bos.bootstrap.pg_auxiliar_start` | ⚠️ AUTH | — | **requiere `_token`** |
| `bos.bootstrap.pg_auxiliar_sync` | ⚠️ AUTH | — | **requiere `_token`** |
| `bos.bootstrap.pg_auxiliar_cleanup` | ⚠️ AUTH | 0ms | **requiere `_token`** |

---

## Módulo SAGA

| Método | Estado | ms P50 | Notas |
|--------|--------|--------|-------|
| `bos.saga.execute {"ficha_id":"...","command":"..."}` | ⚠️ AUTH | — | **requiere `_token`** |

---

## Módulo CTX (Context Plane — SBOS-049)

| Método | Estado | ms P50 | Notas |
|--------|--------|--------|-------|
| `bos.ctx.auto_migrate` | ✅ OK | 5ms | DDL idempotente en `sbos_db` |
| `bos.ctx.device.register {hostname, tenant_id, node_k8s, ip}` | ✅ OK | 15ms | crea `dctx_id`, persiste en PG |
| `bos.ctx.list {"tenant_id":"..."}` | ✅ OK | 4ms | sesiones activas del tenant |
| `bos.ctx.get {"ctx_id":"..."}` | ✅ OK | 4ms | lookup Redis O(1) → PG fallback |
| `bos.ctx.validate {"traceparent":"..."}` | ✅ OK | 4ms | valida W3C traceparent |
| `bos.ctx.create {tenant_id, empresa_id, user_id}` | ✅ OK | 1ms | crea SessionContext directa (sin promote) |
| `bos.ctx.promote {dctx_id, empresa_id, sucursal_id, pos_logico, user_id, bitmask, loa}` | ⚠️ LÓGICO | 7ms | error si `dctx_id` no existe (correcto) |
| `bos.ctx.switch {ctx_id, empresa_id, sucursal_id, pos_logico}` | ⚠️ LÓGICO | 8ms | error si `ctx_id` no existe (correcto) |
| `bos.ctx.invalidate {"ctx_id":"..."}` | ⚠️ AUTH | 1ms | **requiere `_token`** |
| `bos.ctx.tenant.suspend {"tenant_id":"..."}` | ⚠️ AUTH | 0ms | **requiere `_token`** |

**Nota M3.2:** ctx_id lookup Redis P50 = <1ms (medido dentro del pod), P99 < 4ms.

---

## Módulo RELEASE

| Método | Estado | ms P50 | Notas |
|--------|--------|--------|-------|
| `bos.release.check` | ✅ OK | 0ms | verifica canal de release |
| `bos.release.list` | ⚠️ INTERNAL | 0ms | `ReleaseServerURL` no configurada en staging |

---

## Módulo K8S

| Método | Estado | ms P50 | Notas |
|--------|--------|--------|-------|
| `bos.k8s.node.list` | ✅ OK | 113ms | lista nodos K8s reales vía kubectl |
| `bos.k8s.rollout.status {namespace, deployment}` | ⚠️ INTERNAL | 117ms | deployment "postgresql" → nombre real en K8s varía |
| `bos.k8s.node.cordon {"node":"..."}` | ⚠️ AUTH | 0ms | **requiere `_token`** |
| `bos.k8s.node.uncordon {"node":"..."}` | ⚠️ AUTH | 0ms | **requiere `_token`** |
| `bos.k8s.node.drain {"node":"..."}` | ⚠️ AUTH | — | **requiere `_token`** |
| `bos.k8s.pod.evict {namespace, pod}` | ⚠️ AUTH | 0ms | **requiere `_token`** |
| `bos.k8s.pod.restart {namespace, pod}` | ⚠️ AUTH | 0ms | **requiere `_token`** |
| `bos.k8s.scale {namespace, deployment, replicas}` | ⚠️ AUTH | 0ms | **requiere `_token`** |
| `bos.k8s.rollout.undo {namespace, deployment}` | ⚠️ AUTH | 0ms | **requiere `_token`** |
| `bos.k8s.resources.set {namespace, deployment, cpu, memory}` | ⚠️ AUTH | 0ms | **requiere `_token`** |

---

## Módulo QUERY (multi-fuente paralela)

| Método | Estado | ms P50 | Notas |
|--------|--------|--------|-------|
| `bos.query.system` | ✅ OK | 1648ms | Ubuntu + K8s + fichas + ctx + certif. (< 4s SLO) |
| `bos.query.system {"tenant_id":"..."}` | ✅ OK | 1448ms | ídem filtrado por tenant |
| `bos.query.tenant {"tenant_id":"..."}` | ✅ OK | 2ms | snapshot completo del tenant |
| `bos.query.node {"node":"..."}` | ✅ OK | 203ms | diagnóstico K8s del nodo |
| `bos.query.context {"tenant_id":"..."}` | ✅ OK | 2ms | estados, anomalías, TTLs de ctx |
| `bos.query.vdi {"tenant_id":"..."}` | ✅ OK | 4ms | VDI Layer con semáforo |
| `bos.query.repair {ficha_id, tenant_id}` | ✅ OK | 83ms | pre-diagnóstico para repair |

---

## Módulo CAPACITY

| Método | Estado | ms P50 | Notas |
|--------|--------|--------|-------|
| `bos.capacity.check {"op_type":"..."}` | ⚠️ PARAMS | 0ms | `op_type` es requerido |
| `bos.capacity.status` | ⚠️ INTERNAL | 0ms | `capacity.yaml` no disponible (wizard P3B pendiente) |

---

## Módulo MAINTENANCE

| Método | Estado | ms P50 | Notas |
|--------|--------|--------|-------|
| `bos.maintenance.status` | ✅ OK | 1ms | modo mantenimiento activo/inactivo |
| `bos.maintenance.start {"reason":"..."}` | ⚠️ AUTH | — | **requiere `_token`** |
| `bos.maintenance.cancel` | ⚠️ AUTH | 0ms | **requiere `_token`** |

---

## Módulo AI (biaos)

| Método | Estado | ms P50 | Notas |
|--------|--------|--------|-------|
| `bos.ai.catalog` | ⚠️ INTERNAL | 0ms | agente `biaos` no disponible en staging |
| `bos.ai.ask {"question":"..."}` | ⚠️ INTERNAL | 0ms | agente `biaos` no disponible en staging |
| `bos.ai.run {"task":"..."}` | ⚠️ AUTH | 1ms | **requiere `_token`** |
| `bos.ai.confirm {task_id, confirmed}` | ⚠️ AUTH | 2ms | **requiere `_token`** |

---

## Leyenda

| Símbolo | Significado |
|---------|-------------|
| ✅ OK | Responde con `result` válido |
| ⚠️ AUTH | Requiere `_token` en el request (método destructivo) |
| ⚠️ INTERNAL | Servicio externo no disponible en staging (biaos, release server, capacity.yaml) |
| ⚠️ LÓGICO | Error de lógica esperado (entidad no existe, dctx_id ficticio) |
| ⚠️ PARAMS | Parámetros requeridos faltantes |
| ❌ FAIL | Error inesperado (ninguno en este audit) |

---

## Métodos pendientes (no implementados)

Los siguientes métodos del catálogo ADR-019 aún no están en el dispatcher:

| Método | Razón |
|--------|-------|
| `bos.ctx.device.get` | No expuesto como RPC (solo interno via GetDevice) |
| `bos.ficha.rollback` | No implementado en F9 |
| `bos.tenant.create` | Saga de tenant (M2.4 en progreso) |
| `bos.tenant.list` | No implementado |
| `bos.tenant.suspend` | No implementado (existe `bos.ctx.tenant.suspend`) |
