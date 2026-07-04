# ADR-005 — bosctl como Capa de Abstracción Soberana
## El operador no ve Ubuntu ni Kubernetes — solo ve el bos

**Estado:** Aceptado  
**Fecha:** Junio 2026  
**Autores:** Equipo SKULL — SBOS Architecture  
**Supersede:** N/A — extiende ADR-001 (bosctl reemplaza sudo)  
**Relacionado:** ADR-001, ADR-002, ADR-004, SBOS-018, SBOS-052  
**Referenciado en:** PLAN_ACCION_BOSAGENT.md — Fase 4 (nueva tarea F4.6), Fase 9

---

## El problema que este ADR resuelve

Actualmente la documentación del SBOS mezcla dos lenguajes:

```bash
# Lenguaje K8s (no debería aparecer en SBOS):
kubectl get pods -n sbos-skull -l app=nextcloud
kubectl get pods -n sbos-skull -l app=fedora-logico
kubectl describe node node-01
kubectl scale deployment fedora-logico --replicas=4

# Lenguaje SBOS (lo que debería existir):
bosctl get pods --tenant=skull --ficha=nextcloud
bosctl get pods --tenant=skull --ficha=fedora-logico
bosctl node status node-01
bosctl vdi pool scale --tenant=skull --replicas=4
```

El operador del SBOS no debería necesitar saber que existe Kubernetes. Así como el usuario de Ubuntu no sabe que existe el scheduler del kernel, el operador del SBOS no debería saber que existe kubectl.

---

## Marco conceptual: Platform Engineering e IDP

La industria tiene un nombre formal para esto: **Internal Developer Platform (IDP)** con abstracción completa de Kubernetes. La investigación de 2025-2026 documenta el patrón:

Las plataformas IDP permiten que los desarrolladores accedan a interfaces estandarizadas que codifican mejores prácticas y hacen cumplir consistencia operacional en todos los despliegues. El resultado es mejora de foco, ciclos de desarrollo más rápidos y menos errores de configuración. Los equipos de platform engineering no están eliminando Kubernetes del flujo — simplemente lo están ocultando detrás de mejor tooling.

El objetivo fundamental de un IDP es abstraer la complejidad de la infraestructura mientras se mantiene la flexibilidad, permitiendo a los equipos enfocarse en su trabajo en lugar de luchar con comandos kubectl, errores de sintaxis YAML o detalles de configuración del cluster.

Para el SBOS, esto es aún más importante que en un IDP corporativo convencional. El operador del SBOS es personal administrativo de una empresa —un cajero, un supervisor, un técnico de TI de una PYME— que no tiene formación en Kubernetes y no debería necesitarla.

---

## Decisión: tres mecanismos de abstracción

El bos implementa la abstracción de infraestructura en tres niveles complementarios:

```
NIVEL 1 — bosctl get/describe/logs: vocabulario SBOS sobre recursos K8s
NIVEL 2 — Recursos nativos SBOS (Fichas): CRDs que reemplazan Pods/Deployments
NIVEL 3 — JSON-RPC: API programática que cualquier daemon o script usa en lugar de kubectl
```

Los tres niveles son necesarios y se complementan:
- Un operador humano usa NIVEL 1 (CLI)
- Un script o daemon usa NIVEL 3 (JSON-RPC)
- El bos usa NIVEL 2 internamente para gestionar el estado declarativo

---

## NIVEL 1 — Vocabulario SBOS en bosctl

### El principio de mapping

Cada comando kubectl que el operador pudiera necesitar tiene un equivalente bosctl con vocabulario de dominio SBOS. El mapping es deliberado y completo — no debe haber ninguna razón operacional para usar kubectl directamente.

```
VOCABULARIO K8S          VOCABULARIO SBOS          SIGNIFICADO SBOS
─────────────────────────────────────────────────────────────────────
kubectl get pods         bosctl get pods           Ver estado de fichas
kubectl get nodes        bosctl node list          Ver nodos del cluster
kubectl describe pod     bosctl describe           Detalle de una ficha
kubectl logs             bosctl logs               Logs de una ficha
kubectl scale            bosctl scale / vdi pool   Escalar una ficha
kubectl exec             bosctl exec               Ejecutar en ficha (admin)
kubectl apply            bosctl ficha install      Instalar/actualizar ficha
kubectl delete           bosctl ficha remove       Remover ficha
kubectl get events       bosctl events             Eventos del sistema
kubectl top              bosctl top                Recursos en uso
kubectl cordon           bosctl node cordon        Aislar nodo
kubectl drain            bosctl node drain         Vaciar nodo
kubectl rollout          bosctl rollout            Gestión de rollouts
```

### Comandos nuevos a implementar en bosctl

#### bosctl get — el comando más usado

```bash
# Ver todas las fichas de todos los tenants
bosctl get pods

# Ver fichas de un tenant específico
bosctl get pods --tenant=skull

# Ver una ficha específica
bosctl get pods --tenant=skull --ficha=nextcloud

# Ver fichas por estado
bosctl get pods --state=DEGRADADA
bosctl get pods --state=INSTALADA

# Formato de salida
bosctl get pods --output=json
bosctl get pods --output=table   # default — legible para humanos

# Salida esperada (tabla):
# FICHA              TENANT    ESTADO      RÉPLICAS  HEALTH    UPTIME
# postgresql         skull     INSTALADA   1/1       OK        5d 12h
# redis              skull     INSTALADA   1/1       OK        5d 12h
# nextcloud          skull     INSTALADA   2/2       OK        3d 08h
# fedora-logico      skull     INSTALADA   3/3       OK        3d 08h
# guacamole          skull     INSTALADA   1/1       OK        3d 08h
# keycloak           skull     DEGRADADA   0/1       FAIL      0m 32s ← alerta
```

#### bosctl describe — detalle de una ficha

```bash
bosctl describe nextcloud --tenant=skull

# Salida:
# ═══════════════════════════════════════════════════════
# Ficha:        nextcloud
# Tenant:       skull
# Versión:      30.x
# Estado:       INSTALADA
# Réplicas:     2/2 Running
# Uptime:       3d 08h 14m
# ═══════════════════════════════════════════════════════
# Context:
#   dctx_id activos en pods: 3
#   Home montado:            2/2 pods
#
# Recursos:
#   CPU:    0.4/2.0 cores (20%)
#   Mem:    1.2/4.0 GB   (30%)
#   Disco:  128/500 GB   (26%)
#
# Dependencias:
#   ✓ postgresql    INSTALADA
#   ✓ keycloak      INSTALADA
#   ✓ kong          INSTALADA
#   ✓ vault         INSTALADA
#
# Últimas reparaciones:
#   2026-06-05 14:32  reparación automática (watchdog)  OK  8m02s
#
# Logs recientes: bosctl logs nextcloud --tail=20
# ═══════════════════════════════════════════════════════
```

#### bosctl logs — logs de una ficha

```bash
# Últimas 50 líneas
bosctl logs nextcloud --tenant=skull

# Stream en tiempo real
bosctl logs nextcloud --tenant=skull --follow

# Filtrar por nivel
bosctl logs nextcloud --tenant=skull --level=error

# Con ctx_id para correlación (SBOS-049)
bosctl logs nextcloud --tenant=skull --ctx-id=ctx-88291-a4f9
```

#### bosctl node — gestión de nodos

```bash
# Ver estado de todos los nodos
bosctl node list

# Salida:
# NODO      ESTADO    CPU    MEM    DISCO  FICHAS  SESIONES
# node-01   Ready     45%    62%    28%    8       12

# Estado detallado de un nodo
bosctl node status node-01

# Operaciones de mantenimiento (ADR-004)
bosctl node cordon node-01        # aislar para mantenimiento
bosctl node drain node-01         # vaciar antes de mantenimiento
bosctl node uncordon node-01      # liberar post-mantenimiento

# Mantenimiento completo (saga automatizada)
bosctl node maintain node-01 --op=k8s-patch
```

#### bosctl events — eventos del sistema

```bash
# Eventos recientes de todo el sistema
bosctl events

# Eventos de una ficha específica
bosctl events --ficha=nextcloud --tenant=skull

# Salida:
# TIEMPO    FICHA       TIPO       MENSAJE
# 2m ago    nextcloud   Normal     Pod fedora-logico-2 added to pool
# 5m ago    redis       Warning    Memory usage > 80% threshold
# 8m ago    postgresql  Normal     Repair saga completed OK (8m02s)
```

#### bosctl scale — escalado con vocabulario SBOS

```bash
# Escalar una ficha
bosctl scale nextcloud --tenant=skull --replicas=3

# Escalar el pool VDI
bosctl vdi pool scale --tenant=skull --min=4 --max=20

# Ver política de escalado actual
bosctl scale policy --ficha=nextcloud --tenant=skull
```

#### bosctl rollout — gestión de actualizaciones

```bash
# Estado de un rollout en curso
bosctl rollout status nextcloud --tenant=skull

# Historial de rollouts
bosctl rollout history nextcloud --tenant=skull

# Rollback al estado anterior
bosctl rollout undo nextcloud --tenant=skull

# Actualizar a nueva versión
bosctl rollout start nextcloud --version=31.x --tenant=skull
```

---

## NIVEL 2 — Recursos nativos SBOS (Fichas como CRDs)

### El concepto

Un CRD extiende la API de Kubernetes con nuevos tipos de recursos, permitiendo a los desarrolladores representar cualquier concepto de dominio como un objeto de primera clase dentro del cluster. El Operator monitorea continuamente los Custom Resources, interpretando cambios en el spec y ajustando el sistema subyacente para que el status observado coincida con la configuración deseada.

Para el SBOS, las **Fichas** son los Custom Resources. El `manifest.yml` es el `spec`. El estado en `state.Manager` es el `status`. El bos es el controller que reconcilia spec vs status.

### CRD: SBOSFicha

```yaml
# CRD que define el tipo "SBOSFicha" en Kubernetes
# El bos registra este CRD al arrancar el cluster
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: fichas.sbos.skull.io
  annotations:
    sbos.io/adr: "ADR-005"
    sbos.io/managed-by: "bos"
spec:
  group: sbos.skull.io
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                id:
                  type: string     # "nextcloud", "postgresql", etc.
                version:
                  type: string     # "30.x"
                tenant:
                  type: string     # "skull"
                replicas:
                  type: integer
                autoInstall:
                  type: boolean
                dependencies:
                  type: array
                  items:
                    type: string
            status:
              type: object
              properties:
                state:
                  type: string     # INSTALADA, DEGRADADA, etc.
                health:
                  type: string     # OK, FAIL, WARN
                replicasReady:
                  type: integer
                lastRepair:
                  type: string
                ctxIds:
                  type: integer    # dctx_id activos en pods de esta ficha
  scope: Namespaced
  names:
    plural: fichas
    singular: ficha
    kind: SBOSFicha
    shortNames:
      - sf
```

### Instancia: ficha nextcloud

```yaml
# Lo que el bos crea automáticamente al instalar nextcloud
apiVersion: sbos.skull.io/v1
kind: SBOSFicha
metadata:
  name: nextcloud
  namespace: sbos-skull
  labels:
    sbos.io/tenant: skull
    sbos.io/tier: vdi
  annotations:
    sbos.io/installed-at: "2026-06-04T10:00:00Z"
    sbos.io/managed-by: bos
spec:
  id: nextcloud
  version: "30.x"
  tenant: skull
  replicas: 2
  autoInstall: true
  dependencies:
    - postgresql
    - keycloak
    - kong
    - vault

status:                          # bos actualiza este campo continuamente
  state: INSTALADA
  health: OK
  replicasReady: 2
  lastRepair: "2026-06-05T14:32:00Z"
  ctxIds: 3                      # 3 pods con dctx_id activo
```

### La consecuencia: bosctl usa los CRDs, no los pods

Una vez que existen los CRDs `SBOSFicha`, el comando:

```bash
bosctl get pods --tenant=skull
```

No hace `kubectl get pods -n sbos-skull` directamente. Hace:

```bash
kubectl get fichas -n sbos-skull
# o via JSON-RPC:
bosctl rpc bos.ficha.list --tenant=skull
```

El operador ve **Fichas** — no Pods, no Deployments, no ReplicaSets. Kubernetes sigue haciendo todo el trabajo por debajo, pero el operador interactúa con la abstracción soberana.

---

## NIVEL 3 — JSON-RPC: API programática soberana

El JSON-RPC del bos es el equivalente de la API de Kubernetes, pero con vocabulario SBOS. Cualquier daemon, script, o integración que necesite operar sobre la infraestructura usa JSON-RPC en lugar de kubectl.

```
En el ecosistema K8s convencional:
  Scripts → kubectl → K8s API Server → K8s controllers → Pods

En el SBOS:
  Scripts → bosctl rpc / biedata / bkernel → bos JSON-RPC → bos Operator → K8s (internamente)
```

### Por qué esto es correcto arquitecturalmente

Los Operators presentan otra capa de abstracción para el usuario. Usando el patrón Operator, es posible abstraer cualquier caso de uso donde el conocimiento operacional para crear, configurar y mantener aplicaciones complejas pueda automatizarse.

El bos es ese Operator. El JSON-RPC es su interfaz de control. kubectl es un detalle de implementación interno que el operador nunca debería ver.

---

## Implementación: qué hay que construir

### F4.6 — nueva tarea en Fase 4 del plan

```
Crear cmd/bosctl/get.go:
  bosctl get pods [--tenant=X] [--ficha=X] [--state=X] [--output=table|json]
  bosctl describe <ficha> [--tenant=X]
  bosctl events [--ficha=X] [--tenant=X] [--since=1h]
  bosctl logs <ficha> [--tenant=X] [--follow] [--level=X] [--ctx-id=X]

Crear cmd/bosctl/node.go:
  bosctl node list
  bosctl node status <node>
  bosctl node cordon <node>
  bosctl node uncordon <node>
  bosctl node drain <node>
  bosctl node maintain <node> --op=X

Crear cmd/bosctl/rollout.go:
  bosctl rollout status <ficha> [--tenant=X]
  bosctl rollout history <ficha> [--tenant=X]
  bosctl rollout undo <ficha> [--tenant=X]
  bosctl rollout start <ficha> --version=X [--tenant=X]

Crear cmd/bosctl/scale.go: (ya parcialmente definido en Fase 9)
  bosctl scale <ficha> [--tenant=X] --replicas=N
  bosctl scale policy [--ficha=X] [--tenant=X]
```

### Nuevos métodos JSON-RPC requeridos

```go
// En internal/server/jsonrpc.go, agregar al rpcRegistry:

// bos.ficha.* — extensiones
"bos.ficha.events":       (*Server).rpcFichaEvents
"bos.ficha.rollout.status": (*Server).rpcFichaRolloutStatus
"bos.ficha.rollout.history": (*Server).rpcFichaRolloutHistory
"bos.ficha.rollout.undo": (*Server).rpcFichaRolloutUndo

// bos.node.* — nuevo módulo
"bos.node.list":          (*Server).rpcNodeList
"bos.node.status":        (*Server).rpcNodeStatus
"bos.node.cordon":        (*Server).rpcNodeCordon
"bos.node.uncordon":      (*Server).rpcNodeUncordon
"bos.node.drain":         (*Server).rpcNodeDrain

// bos.cluster.* — nuevo módulo
"bos.cluster.events":     (*Server).rpcClusterEvents
"bos.cluster.top":        (*Server).rpcClusterTop
```

### Registro de CRDs en el arranque del bos

```go
// En internal/bootstrap/setup.go, durante autoBootstrap():
// Registrar los CRDs de SBOS en el API server de K8s

func RegisterSBOSCRDs(k8sCore *k8s.Core) error {
    crds := []string{
        "fichas.sbos.skull.io",    // SBOSFicha
        "contexts.sbos.skull.io",  // SBOSContext (para el Context Plane)
        "nodes.sbos.skull.io",     // SBOSNode (abstracción de nodo)
    }
    for _, crd := range crds {
        if err := k8sCore.ApplyCRD(crd); err != nil {
            return fmt.Errorf("bootstrap: registrar CRD %s: %w", crd, err)
        }
    }
    return nil
}
```

---

## La regla del operador SBOS

**Ningún documento de operación del SBOS debe requerir que el operador conozca kubectl.**

Cuando en documentación interna aparezca un comando kubectl, debe reemplazarse por su equivalente bosctl. Si el equivalente no existe, debe crearse y agregarse como tarea en el plan de acción.

### Tabla de reemplazos para actualizar documentación

| kubectl (antes) | bosctl (después) |
|---|---|
| `kubectl get pods -n sbos-{t} -l app=nextcloud` | `bosctl get pods --tenant={t} --ficha=nextcloud` |
| `kubectl get pods -n sbos-{t} -l app=fedora-logico` | `bosctl get pods --tenant={t} --ficha=fedora-logico` |
| `kubectl describe pod X -n sbos-{t}` | `bosctl describe X --tenant={t}` |
| `kubectl logs X -n sbos-{t} --follow` | `bosctl logs X --tenant={t} --follow` |
| `kubectl scale deployment X --replicas=N` | `bosctl scale X --replicas=N --tenant={t}` |
| `kubectl exec X -- cmd` | `bosctl exec X -- cmd --tenant={t}` |
| `kubectl get nodes` | `bosctl node list` |
| `kubectl cordon node-01` | `bosctl node cordon node-01` |
| `kubectl drain node-01` | `bosctl node drain node-01` |
| `kubectl rollout undo deployment/X` | `bosctl rollout undo X --tenant={t}` |
| `kubectl top pods -n sbos-{t}` | `bosctl top --tenant={t}` |
| `kubectl get events -n sbos-{t}` | `bosctl events --tenant={t}` |

---

## Lo que NO cambia

- **kubectl sigue existiendo** — el bos lo usa internamente en `internal/k8s/core.go`
- **Los administradores avanzados pueden usar kubectl** — pero no es necesario para operar el SBOS
- **K8s sigue haciendo todo el trabajo** — el bos es una capa de abstracción, no un reemplazo
- **Los manifiestos YAML de K8s siguen existiendo** — gestionados por el bos, no por el operador

Esta es exactamente la misma relación que tiene Ubuntu con el kernel de Linux: el usuario no necesita hablar directamente con el kernel, pero el kernel sigue haciendo todo el trabajo real.

---

## Consecuencias

### Positivas
1. El operador del SBOS necesita aprender solo un vocabulario: el de bosctl
2. La documentación operacional del SBOS es consistente — no mezcla kubectl y bosctl
3. El bos tiene visibilidad completa de todas las operaciones — ninguna operación bypasea el audit log
4. Los CRDs de SBOS permiten que `kubectl get fichas` funcione para los administradores avanzados que sí conocen K8s
5. El JSON-RPC como API programática permite que biedata, bkernel y bsearch operen sin saber K8s

### Trade-offs aceptados
1. Hay que implementar los comandos bosctl que no existen — trabajo adicional en Fase 4 y 9
2. El bos se convierte en un punto de paso obligatorio — si el bos está caído, no se puede operar el cluster via bosctl (pero kubectl sigue funcionando como fallback de emergencia)
3. Mantener el mapping kubectl → bosctl actualizado requiere disciplina cuando K8s agrega nuevas capacidades

### Regla de excepción documentada
```
El uso directo de kubectl está permitido SOLO en:
  1. Emergencias donde el bos no está disponible
  2. Diagnóstico de problemas del propio bos
  3. Operaciones de bootstrap antes de que el bos esté activo (Fase 0-1)

En todos los casos de excepción, registrar en /var/log/bos/audit.log:
  audit.Log("KUBECTL_DIRECT", "user=root", "cmd="+cmd, "reason="+reason)
```

---

## Changelog

| Fecha | Versión | Cambio |
|---|---|---|
| Junio 2026 | 1.0 | Versión inicial — abstracción soberana bosctl sobre K8s y Ubuntu |

---

*ADR-005 — BosAgent/SBOS — Junio 2026*  
*Extiende: ADR-001 (bosctl reemplaza sudo)*  
*Referencia: PLAN_ACCION_BOSAGENT.md — nueva tarea F4.6 en Fase 4*  
*Referencia: ADR-004 (Operator Soberano — los comandos del Operator se exponen via bosctl)*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
