# Anexo A.06 — Patrón Kubernetes Operator y el BOS
## Cómo el BOS implementa el Operator Pattern del CNCF: CRD, Controller, Reconcile Loop

**Versión:** 1.0.0 · **Fecha:** 2026-07-17 · **Autor:** bos-developer — SBOS
**Fortalece al motor:** ③ Server FICHAS
**Referencia:** [3.01 — Server FICHAS](../3.01_MANUAL-SERVER-FICHAS.md) · ADR-004

---

## 1. El Operator Pattern (CNCF)

Un Operator encapsula conocimiento operacional en un controlador que **continuamente reconcilia
la configuración deseada con el estado real observado**. El loop es level-based (orientado a
estado), no edge-based (orientado a eventos): re-evalúa el estado completo del sistema, no
reacciona al cambio específico.

### 1.1 Componentes del Operator

| Componente | Kubernetes nativo | BOS |
|-----------|-------------------|-----|
| Custom Resource (CRD) | `kind: PostgresCluster` | `manifest.yml` de cada ficha |
| Controller | Go controller-runtime | `observer/loop.go` + `reconcile/scheduler.go` |
| Reconcile Loop | `Reconcile(ctx, req)` | `ReconcileNow()` cada 15min |
| Spec (deseado) | `.spec` del CR | `manifest.yml` entero |
| Status (real) | `.status` del CR | `bos.ficha_state` (18 estados) |
| Events | K8s Events API | `bos.ficha_event` (append-only inmutable) |

---

## 2. Level-based vs Edge-based

El BOS es **level-based**: cuando ocurre un evento, no reacciona al cambio específico sino que
re-evalúa el estado completo. Esto es más robusto: un evento perdido no rompe el sistema —
la siguiente reconciliación lo corrige.

```
Edge-based (frágil):
  "PostgreSQL pasó de 2 a 3 réplicas" → escalar

Level-based (robusto):
  "¿Cuántas réplicas dice manifest.yml? 3. ¿Cuántas hay en K8s? 2. → escalar a 3"
```

---

## 3. Buenas prácticas que el BOS implementa

| Práctica | Implementación en BOS |
|----------|----------------------|
| **Idempotencia** | `ficha_repair()` converge al estado deseado sin importar estado inicial |
| **Level-triggered** | observer compara manifest.yml vs K8s real cada vez |
| **Finalizers** | saga de 7 pasos con compensación inversa |
| **Child resources** | `depends_on` en manifest.yml → DAG topológico (Kahn) |
| **Drift correction** | `drift.go` SHA-256 por archivo |
| **Jittered timers** | reconcile scheduler deterministic, no timers uniformes |
| **Spec/Status** | manifest.yml (spec) vs `bos.ficha_state` (status) |

---

## 4. Death spiral de HPA + VPA (y cómo el BOS lo evita)

HPA y VPA son incompatibles sobre las mismas métricas. El BOS **reconcilia réplicas y
dimensionamiento como una decisión coordinada única** con histéresis y contexto:

```go
// internal/scaler/scaler.go — anti-death-spiral
func (s *Scaler) Scale(ctx context.Context, ficha string) error {
    // 1. Lee métricas actuales (CPU, RAM, conexiones)
    // 2. Decide réplicas Y dimensionamiento EN UN SOLO PASO
    // 3. Aplica con histéresis: no escala si el cambio es < 10%
    // 4. Registra en bos.cap_snapshot para proyección futura
}
```

---

## 5. Referencias

- [CNCF Operator White Paper](https://www.cncf.io/reports/operator-white-paper/)
- [controller-runtime](https://github.com/kubernetes-sigs/controller-runtime) — CNCF project
- [Kubernetes Operator Multi-Resource Reconciliation (2026)](https://www.golinuxcloud.com/multi-resource-reconciliation/)
- [Avoid Operator Reconcile Loop Explosions (2026)](https://www.golinuxcloud.com/avoid-kubernetes-operator-reconcile-loop-explosions/)

---

*SKULL · SBOS · BosAgent · Julio 2026*
