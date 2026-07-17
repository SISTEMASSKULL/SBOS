# Anexo A.08 — Flujo End-to-End de Operación del BOS
## La secuencia completa: detección → diagnóstico → reparación → verificación → usuario operativo

**Versión:** 1.0.0 · **Fecha:** 2026-07-17 · **Autor:** bos-developer — SBOS
**Fortalece al motor:** ② SO Observable
**Referencia:** [2.01 — SO Observable](../2.01_MANUAL-SO-OBSERVABLE.md)

---

## 1. El marco ITIL 4 que estructura el flujo

ITIL 4 Major Incident Management define 4 etapas. El BOS las implementa con sus componentes:

| Etapa ITIL 4 | Responsable BOS | Herramienta | Criterio de salida |
|--------------|-----------------|-------------|-------------------|
| Identificación y registro | Watchdog o biaos | `bos.query.system` | Incidente en audit log con ctx_id |
| Investigación y diagnóstico | biaos ReAct + `bos.query.repair` | Sagas de consulta paralelas | Causa raíz con evidencia real |
| Resolución y recuperación | SagaEngine + ICAP + HITL | `repair-ficha.yml` | C-0X verificado, usuario operativo |
| Revisión post-incidente | audit log + metrics | ISO 27001 A.8.15 | traceparent correlacionado |

---

## 2. Caso canónico — "nextcloud no abre" (8-12 minutos)

```
══════════════════════════════════════════════════════════════
ETAPA 0 — DETECCIÓN (t=0:00)
══════════════════════════════════════════════════════════════
Watchdog (tick 30s) → nextcloud probe FAIL → DEGRADADA
→ bos.query.repair → diagnóstico pre-repair
→ audit.Log("WATCHDOG_DETECT", "ficha=nextcloud")

ETAPA 1 — INVESTIGACIÓN PARALELA (t=0:00 → t=0:02)
══════════════════════════════════════════════════════════════
bos.query.system → 5 threads en paralelo:
  Thread 1: Ubuntu (CPU 45%, RAM 62%)
  Thread 2: K8s (nodes Ready)
  Thread 3: stateMgr (nextcloud: DEGRADADA)
  Thread 4: ctxSvc (12 ctx activos)
  Thread 5: healthChecker (nextcloud: FAIL)
→ Agregado en 1.8s

bos.query.repair → 8 threads en paralelo:
  Thread 1: estado actual (DEGRADADA, 8m32s)
  Thread 2: health probe (port 28300 refused)
  Thread 3: drift (no detectado)
  Thread 4: dependencias (postgresql OK, keycloak OK)
  Thread 5: historial repairs (2 previas exitosas)
  Thread 6: pod logs ("OOMKilled at 14:23:12")
  Thread 7: ctx afectados (12)
  Thread 8: política scaler (memory_limit: 4Gi)
→ causa_probable: "OOMKilled — memoria insuficiente (3.9/4.0 GB)"

ETAPA 2 — ICAP + HITL (t=0:02 → t=0:04)
══════════════════════════════════════════
biaos: embedding de diagnosis → coseno en action_catalog.yml
→ Acción sugerida: SCALE_VERTICAL (más memoria) o HPA (más réplicas)
→ HITL: "nextcloud OOMKilled. ¿Escalar memoria a 8Gi? [Y/n]"
→ Operador autoriza

ETAPA 3 — REPARACIÓN (t=0:04 → t=0:08)
══════════════════════════════════════
Saga repair-nextcloud.yml:
  Paso 1: Scale memory → 8Gi (ok, 45s)
  Paso 2: Restart pod (ok, 30s)
  Paso 3: Health probe → port 28300 OK (ok, 5s)
  Paso 4: Verify C-09 (Nextcloud OIDC login OK)

ETAPA 4 — VERIFICACIÓN (t=0:08 → t=0:10)
══════════════════════════════════════
  → nextcloud: INSTALADA ✅
  → 12 ctx_id restaurados ✅
  → Home montado en pods ✅
  → audit trail: traceparent correlacionado en todos los eventos
  → Usuario puede trabajar
```

---

## 3. Los 5 planos que el BOS reconcilia simultáneamente

| Plano | Qué verifica | Herramienta |
|-------|-------------|-------------|
| 1. Host Ubuntu | CPU, RAM, Disco, containerd, kubelet, swap | Watchdog |
| 2. Kubernetes | Nodos Ready, pods Running, CoreDNS, etcd | K8s Core |
| 3. PostgreSQL | pg_isready, conexiones, replicación | Health Checker |
| 4. Vault | initialized + unsealed | Health Checker |
| 5. Redis | PING, memoria, keys | Health Checker |

---

*SKULL · SBOS · BosAgent · Julio 2026*
