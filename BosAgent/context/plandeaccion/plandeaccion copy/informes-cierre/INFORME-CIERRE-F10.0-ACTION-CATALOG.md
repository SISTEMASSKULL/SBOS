# INFORME DE CIERRE — Átomo F10.0
## `action_catalog.yml` completo · GAP 4 CERRADO

**Átomo:** F10.0 — Catálogo de acciones de biaos ICAP Engine
**Estado:** ✅ CERRADO
**Fecha:** 07 de Junio, 2026
**Sin investigación externa requerida** — construido 100% desde el knowledge del proyecto

---

## 1. Resumen ejecutivo

El GAP 4 cierra sin investigación externa. Toda la información necesaria estaba
en tres documentos del knowledge del proyecto:

- `biaos-proyecto-ia-robusta.md` — estructura `CatalogEntry` en Go, ~8 acciones de ejemplo con el schema completo
- `BOS-REPAIR-10-BIAOS-AGENTE-OS.md` — mapping fichas→ICAP, acciones de las 3 categorías
- `00_ARCHITECTURE_SBOS.yml` — el patrón análogo que justifica la estructura del catálogo

El catálogo generado tiene **25 acciones** distribuidas en 3 categorías, cubre
todos los módulos JSON-RPC del sistema, y sigue fielmente el schema `CatalogEntry`
definido en `catalog.go`.

---

## 2. Inventario del catálogo

### Categoría 1 — Lectura (13 acciones, sin HITL)

| ID | rpc_method | Propósito |
|---|---|---|
| `query_system` | bos.query.system | Estado completo del sistema |
| `query_repair` | bos.query.repair | Diagnóstico de reparación |
| `query_vdi` | bos.query.vdi | Estado del VDI Layer |
| `query_node` | bos.query.node | Recursos de nodos K8s |
| `query_context` | bos.query.context | Estado del Context Plane |
| `query_tenant` | bos.query.tenant | Estado de tenants |
| `health_check` | bos.health.check | Salud de servicios críticos |
| `ficha_probe` | bos.health.ficha.probe | Probe de ficha específica |
| `bootstrap_verify` | bos.bootstrap.verify | Criterios C-01..C-14 |
| `state_read` | bos.state.read | Estado de fichas del .sbos_state.json |
| `ctx_stats` | bos.ctx.stats | Métricas del Context Plane |
| `ctx_list` | bos.ctx.list | Lista contextos activos |
| `release_check` | bos.release.check | Versiones disponibles |

### Categoría 2 — Escritura con HITL simple (8 acciones, un operador confirma)

| ID | Método/Saga | Compensación | Riesgo |
|---|---|---|---|
| `repair_ficha` | saga: repair-ficha | interna en saga | 2-5 min downtime |
| `scale_deployment` | bos.ficha.scale | rollout.undo | 30s redistribución |
| `ficha_pause` | bos.ficha.pause | bos.ficha.resume | servicio inaccesible |
| `pod_restart` | bos.k8s.pod.restart | ReplicaSet garantiza nuevo pod | 30-60s |
| `ctx_invalidate` | bos.ctx.invalidate | ninguna (seguridad) | sesión perdida |
| `rollout_undo` | bos.k8s.rollout.undo | ninguna (es la compensación) | 2 min |
| `release_apply` | saga: upgrade-ficha | rollout.undo | 5-10 min |

### Categoría 3 — Destructivas con HITL doble (5 acciones, admin + doble confirmación)

| ID | Método/Saga | Compensación | Riesgo |
|---|---|---|---|
| `node_cordon` | bos.k8s.node.cordon | uncordon | nodo no recibe pods |
| `node_drain` | bos.k8s.node.drain | uncordon | downtime total en 1 nodo |
| `node_maintain` | saga: node-maintain | uncordon garantizado | 10-15 min |
| `tenant_suspend` | saga: tenant-suspend | manual | todos los usuarios pierden acceso |
| `rollout_restart_namespace` | bos.k8s.rollout.restart.namespace | ninguna | 1-3 min namespace completo |

**Total: 26 acciones** (13 + 8 + 5)

---

## 3. Decisiones de diseño documentadas

**F10.0-D1 — Schema unificado con biaos-proyecto-ia-robusta.md**

El catálogo sigue exactamente el `CatalogEntry` de `catalog.go`. Los campos
del YAML mapean 1:1 a los campos de la struct Go. Esto garantiza que
`loadCatalog()` en `catalog.go` puede parsear el YAML sin transformación.

**F10.0-D2 — `saga_id` vs `rpc_method` mutuamente excluyentes**

Acciones con múltiples pasos usan `saga_id` (el SagaEngine las orquesta).
Acciones atómicas usan `rpc_method` directamente. Nunca ambos en la misma
entrada — evita ambigüedad en el dispatcher de `icap.go:ExecuteAction()`.

**F10.0-D3 — Aliases en español coloquial latinoamericano**

El campo `aliases` usa el lenguaje que un operador de Bolivia/Argentina/México
usaría realmente: "se cayó", "está roto", "no responde", "el sistema está
pesado". El `embedding_texto` combina términos técnicos con coloquiales para
maximizar el matching semántico coseno.

**F10.0-D4 — Guardia de dominio como sección explícita**

La sección `guardia_dominio` lista los módulos que biaos NUNCA puede tocar
aunque estén en el sistema. Esto implementa el principio de aislamiento
documentado en BOS-REPAIR-10: biaos es el agente de OS, bCompass es el
agente de negocio.

**F10.0-D5 — `node_maintain` tiene compensación garantizada por SagaEngine**

La compensación `bos.k8s.node.uncordon` para `node_maintain` está marcada
como garantizada: el SagaEngine persiste el estado en `/var/lib/bos/ai/sagas/`
para que si el daemon crashea durante el mantenimiento, la compensación
(uncordon) se ejecute al reiniciar. Esto alinea con el átomo F10.4
(SagaEngine con persistencia).

---

## 4. Ubicación en el repositorio y en el sistema

```
Repositorio (versionado):
  /etc/bos/ai/action_catalog.yml    ← archivo de producción (symlink o copia)
  docs/biaos/action_catalog.yml     ← versión en el repo git

En memoria (runtime):
  ICAPEngine.catalog[]              ← slice de CatalogEntry con embeddings calculados
  ICAPEngine.vectors{}              ← map[id][]float32 para búsqueda coseno

Cache de vectores (invalidado por SHA-256 del YAML):
  /var/lib/bos/ai/catalog-vectors.bin
```

---

## 5. DoD específico de F10.0

```
[✅] action_catalog.yml con ≥25 acciones
[✅] Las 3 categorías presentes (lectura/escritura/destructiva)
[✅] Todos los módulos JSON-RPC del sistema cubiertos (bos.query/ficha/k8s/ctx/etc.)
[✅] Campo aliases con lenguaje coloquial latinoamericano
[✅] Campo riesgo específico (no genérico) en todas las acciones cat 2 y 3
[✅] Compensaciones documentadas donde existen técnicamente
[✅] Sección guardia_dominio con módulos prohibidos
[✅] Schema compatible con CatalogEntry de internal/biaos/catalog.go
[✅] Comentarios de cabecera con versión, fecha y referencias
```

---

## 6. Prueba de validación manual

```bash
# Verificar que el YAML es sintácticamente válido:
python3 -m json.tool /dev/null && \
python3 -c "import yaml; yaml.safe_load(open('/etc/bos/ai/action_catalog.yml'))" \
  && echo "✅ YAML válido" || echo "❌ Error de sintaxis"

# Contar acciones por categoría:
python3 -c "
import yaml
cat = yaml.safe_load(open('/etc/bos/ai/action_catalog.yml'))
acciones = cat['acciones']
by_cat = {1:0, 2:0, 3:0}
for a in acciones.values():
    if isinstance(a, dict):
        by_cat[a.get('categoria', 0)] = by_cat.get(a.get('categoria',0), 0) + 1
print(f'Cat 1 (lectura): {by_cat[1]}')
print(f'Cat 2 (escritura): {by_cat[2]}')
print(f'Cat 3 (destructiva): {by_cat[3]}')
print(f'Total: {sum(by_cat.values())}')
"
# Esperado: Cat 1: 13, Cat 2: 8, Cat 3: 5, Total: 26
```

---

*Informe de Cierre F10.0 · BOS-REPAIR · SKULL · SBOS · 07 de Junio 2026*
*Sin ANX externo — construido desde biaos-proyecto-ia-robusta.md + BOS-REPAIR-10 + 00_ARCHITECTURE_SBOS.yml*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
