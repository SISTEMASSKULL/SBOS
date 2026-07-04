# GESTIÓN DE RIESGOS OPERATIVOS — BOS-REPAIR
## Registro de átomos de alto riesgo y protocolo de aprobación

**Proyecto:** BosAgent / SBOS · SKULL  
**Versión:** 1.0 · Junio 2026  
**Propósito:** Que el agente y el operador compartan el mismo criterio sobre cuándo parar y pedir confirmación explícita. No es burocracia — es que algunos átomos tienen consecuencias irreversibles en producción.

---

## Clasificación de riesgo

Cada átomo del plan tiene un nivel de riesgo operativo asignado. El nivel determina si el agente puede ejecutar autónomamente o debe presentar un plan de cambio al operador antes de tocar código.

| Nivel | Símbolo | Significado | Acción del agente |
|---|---|---|---|
| Bajo | 🟢 | Sin impacto en producción. Reversión trivial con `git revert`. | Ejecutar directamente |
| Medio | 🟡 | Afecta código activo pero es reversible con feature flag. | Ejecutar con feature flag desactivado en prod |
| Alto | 🔴 | Riesgo de regresión o comportamiento inesperado en prod. | Presentar diff al operador antes de ejecutar |
| Crítico | ⛔ | Impacto potencial irreversible: pérdida de datos, cluster inaccesible, daemon caído. | **Gate de aprobación obligatorio** |

---

## Inventario de átomos por nivel de riesgo

### ⛔ CRÍTICOS — Gate de aprobación obligatorio

El agente presenta exactamente qué archivos va a modificar, las líneas específicas que cambian, y el plan de reversión. Espera confirmación escrita antes de ejecutar.

---

#### F1.5 — Mutex Observer/Reconciler

**¿Por qué crítico?** Es el loop de control central del daemon. Un patrón de sincronización incorrecto puede:
- Silenciar la race sin resolverla (pasar los tests pero fallar en producción bajo carga)
- Introducir un deadlock si el lock se toma dos veces en la misma goroutine
- Empeorar el problema si el mutex no es el mismo objeto compartido entre Observer y Scheduler

**Lo que el agente debe presentar antes de ejecutar:**

```
PLAN DE CAMBIO — F1.5

Archivo a crear: internal/observer/observer.go
Patrón elegido: *sync.Mutex inyectado (shared pointer) desde cmd/bos/main.go
Motivo del patrón: Go Wiki recomienda Mutex para proteger estado compartido (no canal).
                   El mutex DEBE ser un puntero compartido entre Observer y Scheduler
                   porque son dos structs distintas. Un mutex por struct no resuelve la race.

Archivo a modificar: internal/reconcile/scheduler.go
Cambio exacto: agregar campo repairMu *sync.Mutex + inyectarlo en NewScheduler()

Archivo a modificar: cmd/bos/main.go
Cambio exacto: repairMu := &sync.Mutex{} → pasar a observer.New() y reconcile.NewScheduler()

Plan de reversión:
  git revert HEAD  (un solo commit — SFP-04)
  BOS_OBSERVER_V2=false → daemon usa código legado sin interrupción

Feature flag: BOS_OBSERVER_V2=true activa el nuevo observer
Test de verificación: go test -race -count=100 ./internal/observer/ -run TestObserver_NoParallelRepair
Criterio de éxito: 100/100 sin DATA RACE

¿Aprueba? [sí/no]
```

---

#### F4.4 — Eliminar `rbac_provider.go`

**¿Por qué crítico?** Si hay un caller de `bosRBAC` que el agente no identifica en el análisis estático, el daemon arranca con una interfaz con nil subyacente y panea al primer request que requiere autorización. El daemon cae en producción.

**Lo que el agente debe presentar antes de ejecutar:**

```
PLAN DE CAMBIO — F4.4

Archivo a archivar: internal/security/rbac_provider.go → _legacy/
Callers actuales encontrados: [listar resultado de grep -rn "bosRBAC\|FileRBAC\|RBACProvider" .]
Callers migrados a ADR-006: [listar cada uno con el cambio exacto]
Callers sin migrar aún: [si hay alguno → BLOQUEANTE, no ejecutar]

Verificación pre-eliminación:
  grep -rn "bosRBAC\|FileRBAC\|rbac_provider" . --include="*.go" | grep -v "_legacy"
  (debe retornar vacío antes de archivar el archivo)

Plan de reversión:
  cp _legacy/FECHA_F4.4_rbac_provider.go internal/security/rbac_provider.go
  git revert HEAD

¿Aprueba? [sí/no]
```

---

#### F9.2+ — Operaciones sobre el cluster Kubernetes real

**¿Por qué crítico?** `Scale`, `Cordon`, `Drain`, `Evict` operan sobre el cluster real. Un `Drain` en un nodo con pods de producción sin PodDisruptionBudget puede causar downtime inmediato.

**Lo que el agente debe presentar antes de ejecutar cualquier operación K8s:**

```
PLAN DE CAMBIO — F9.x (operación K8s)

Operación: [Scale/Cordon/Drain/Evict]
Objetivo: [namespace/deployment/node]
Entorno: [DEV / STAGING / PROD]
Pods afectados: [resultado de kubectl get pods -n <ns>]
PodDisruptionBudgets presentes: [resultado de kubectl get pdb -n <ns>]
Usuarios activos en el nodo: [resultado de bosctl rpc bos.query.node]
Tiempo estimado de impacto: [segundos/minutos]

Compensación automática configurada: [sí (saga cordon→drain→op→uncordon) / no]

Plan de reversión:
  [kubectl uncordon <node> / kubectl scale --replicas=N / etc.]

¿Aprueba? [sí/no]
```

---

#### F9.7 — ClusterRole `bosagent`

**¿Por qué crítico?** Un ClusterRole demasiado permisivo es un vector de ataque permanente. Un ClusterRole demasiado restrictivo rompe las operaciones del daemon. Ambos errores son difíciles de detectar sin auditoría explícita.

**Verificación obligatoria antes de aplicar:**

```bash
# Antes de kubectl apply -f manifests/rbac/bosagent-clusterrole.yaml

# 1. Verificar que NO tiene permisos peligrosos:
kubectl auth can-i delete nodes --as=system:serviceaccount:sbos-system:bosagent
# debe retornar: no

kubectl auth can-i get secrets --as=system:serviceaccount:sbos-system:bosagent
# debe retornar: no

kubectl auth can-i delete namespaces --as=system:serviceaccount:sbos-system:bosagent
# debe retornar: no

# 2. Verificar que SÍ tiene los permisos necesarios:
kubectl auth can-i scale deployments --as=system:serviceaccount:sbos-system:bosagent -n sbos-fichas
# debe retornar: yes

kubectl auth can-i create pods/eviction --as=system:serviceaccount:sbos-system:bosagent
# debe retornar: yes
```

---

### 🔴 ALTOS — Presentar diff, ejecutar con feature flag

Estos átomos modifican código activo pero el impacto en producción está controlado por feature flags.

| Átomo | Riesgo específico | Mitigación |
|---|---|---|
| F1.1-F1.4 | Imports incorrectos rompen build | `go build ./...` después de cada movimiento |
| F2.3 | Comportamiento gorilla vs wslib puede diferir | Test `TestConnectWS_ReconectaTrasError` obligatorio |
| F3.6 | TEA incorrecto congela el TUI | `bosctl install --demo --dry-run` antes del commit |
| F5.3 | DDL aplicado en bkernel_db real | Ejecutar solo en staging primero, verificar con `\dt` |
| F6.1 | Auth rota = todos los métodos destructivos inaccesibles | Test en staging antes de merge a main |
| F8.7 | Chaos test puede dejar el daemon en estado inconsistente | Solo en staging, con backup del estado previo |

---

### 🟡 MEDIOS — Ejecutar con feature flag desactivado

| Átomo | Motivo |
|---|---|
| F0.5 (CI/CD) | Solo agrega archivos nuevos, pipeline puede fallar en CI sin afectar código |
| F0.6 (entornos) | El runner falla silenciosamente si la configuración es incorrecta |
| F3.1-F3.5 (TUI styles/model) | Import circular si el orden es incorrecto — build roto |
| F5.1-F5.2 (context types/service) | Sin DDL aplicado, los tests de integración fallan |
| F10.1-F10.3 (biaos gateway/icap) | Sin API key del LLM, los tests de integración fallan |

---

### 🟢 BAJOS — Ejecutar directamente

| Átomos | Motivo |
|---|---|
| F0.1-F0.4 | Solo crean archivos nuevos (`doc.go`, `_legacy/`, `paths.go`) |
| F7.1-F7.8 | Solo documentación — godoc y runbooks |
| F10.2 (migrar ai/ → biaos/) | Rename de paquete — build verifica automáticamente |

---

## Protocolo de gate de aprobación

Cuando el agente llega a un átomo ⛔ CRÍTICO:

**Paso 1 — Análisis pre-ejecución**

```bash
# El agente ejecuta esto y presenta el output al operador:
echo "=== ANÁLISIS PRE-EJECUCIÓN — [ÁTOMO] ==="
echo "Archivos afectados:"
git diff --name-only HEAD  # cambios actuales
echo ""
echo "Callers del código a modificar/eliminar:"
grep -rn "[SÍMBOLO_A_BUSCAR]" . --include="*.go" | grep -v "_legacy" | grep -v "_test"
echo ""
echo "Estado del build actual:"
go build ./... && echo "✅ LIMPIO" || echo "🔴 ROTO"
echo ""
echo "Tests actuales:"
go test -race -count=3 ./... 2>&1 | grep -E "ok|FAIL|DATA RACE"
```

**Paso 2 — Presentar el plan**

El agente presenta el bloque "PLAN DE CAMBIO" correspondiente al átomo (ver sección anterior) y espera.

**Paso 3 — Esperar respuesta**

El agente no ejecuta ninguna modificación hasta recibir una de estas respuestas:
- `"sí"` / `"aprobado"` / `"adelante"` → procede
- `"no"` / `"espera"` / `"revisar"` → documenta en SESION-LOG y cierra el átomo como "PENDIENTE APROBACIÓN"

**Paso 4 — Documentar en SESION-LOG**

```markdown
### Gate de aprobación — [ÁTOMO]
- Aprobado por: [nombre] / [autónomo]
- Fecha: YYYY-MM-DD HH:MM
- Plan presentado: [sí]
- Decisión: aprobado / rechazado / pospuesto
- Condiciones: [si hay condiciones especiales]
```

---

## Backup obligatorio antes de operaciones destructivas K8s

Antes de cualquier F9.x que toque el cluster real:

```bash
# Backup del estado del daemon
cp /etc/bos/.sbos_state.json /etc/bos/.sbos_state.json.backup-$(date +%Y%m%d-%H%M)

# Backup del estado de K8s para los namespaces afectados
kubectl get all -n sbos-fichas -o yaml > /tmp/k8s-backup-$(date +%Y%m%d-%H%M).yaml

echo "Backups creados:"
ls -la /etc/bos/.sbos_state.json.backup-* | tail -3
ls -la /tmp/k8s-backup-*.yaml | tail -3
```

---

*GESTION-RIESGOS-OPERATIVOS.md v1.0 · BOS-REPAIR · SKULL · SBOS · 08 de Junio 2026*  
*Complementa PROTOCOLO-SESION-AGENTE.md §2.3 (gate de aprobación)*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
