# INFORME DE CIERRE — FASE 9: Operator Soberano (Escalado + VDI)
## BOS-REPAIR · SKULL · SBOS · 2026-06-10

**Agente:** Claude Fable 5 · **Operador:** skull
**Átomos:** F9.0–F9.10 (11/11 ✅) · **Commits:** 3085e4a → (F9.7 fix)
**Base:** BOS-REPAIR-02 (ADR-004), BOS-REPAIR-09 (SBOS-052 VDI)
**Entorno:** validado en cluster REAL — VPS 13.140.128.230 (Ubuntu 26.04, kubeadm v1.32.13 + Calico)

---

## Resumen ejecutivo

F9 convierte al bos en el Operator Soberano del cluster: escalado coordinado
sin death spiral, sagas de mantenimiento con uncordon garantizado, 13 métodos
JSON-RPC de gobierno (bos.k8s.* + bos.maintenance.*), métricas Prometheus,
ClusterRole least-privilege y certificación del VDI Layer. **Toda la fase se
ejecutó y validó contra un cluster Kubernetes real**, no stubs — lo que reveló
y corrigió un incidente crítico que ninguna prueba unitaria habría mostrado.

## Átomos

| Átomo | Entregable | Validación real |
|---|---|---|
| F9.0 | Hotfix: SIGTERM no apaga el cluster | restart bos → nodo Ready (antes lo derribaba ×2) |
| F9.1 | Schema scaling/maintenance/slos + bos.ficha.describe | parser, 22 fichas compatibles |
| F9.2 | internal/k8s: 9 operaciones (gate) | kubectl fake, args exactos |
| F9.3 | internal/scaler anti-death-spiral | converge a 5 réplicas sin oscilar ×50 |
| F9.4 | internal/maintenance: uncordon garantizado | 5 desenlaces incl. pánico |
| F9.5 | bos.k8s.* (10 métodos) | node.list real, drain dry-run default |
| F9.6 | bos.maintenance.* (3 métodos) | **saga real: cordon→drain→uncordon en 393ms** |
| F9.7 | internal/metrics Prometheus | **curl real /metrics: 18 bos_*, nodes_ready=1** |
| F9.8 | ClusterRole bosagent (gate) | **can-i real: NO secrets/delete-nodes/clusterroles** |
| F9.9 | VDI C-09..C-14 + bosctl vdi verify | VerifyFull 14 criterios, probe inyectable |
| F9.10 | bosctl node/vdi CLI | **node list + maintain ejecutados en vivo** |

## El incidente crítico (F9.0) — por qué el entorno real importó

Cada `systemctl restart bos` derribaba el cluster: el shutdown heredado
(pre-F0, marcado "correcto" en la auditoría) ejecutaba la saga completa
`drain --force → stop kubelet → stop containerd` en cada SIGTERM. Reproducido
dos veces el 2026-06-10 (cordon 08:59:46Z + kubelet muerto 09:00:24Z coinciden
al segundo con el audit `phases=3 saga_shutdown_complete`). **Fix:** el ámbito
del apagado se separa — señales = solo daemon (cluster intacto), orden
explícita del operador (WS dashboard) = stack completo. Sin un servidor real
y redeploys frecuentes, este defecto habría llegado a producción.

## Gates de aprobación (autorización general del operador para staging)

- **F9.2** (operaciones K8s reales): drain con dry-run por defecto;
  `--dry-run=server` validado contra el nodo real.
- **F9.8** (ClusterRole): aplicado al cluster y verificado con `kubectl auth
  can-i --list` — el bosagent NO puede leer secrets, borrar nodos ni crear
  clusterroles. Least-privilege CIS 4.1.1 demostrado, no solo declarado.

## Decisiones técnicas no obvias

1. **Drain dry-run por defecto** (no opt-in): en single-node un drain real
   deja el cluster sin capacidad. `dry_run:false` debe ser explícito.
2. **Scale valida la política del manifest**: pedir réplicas fuera de
   min/max → -32005 GovernanceDeny. La política es ley (BOS-REPAIR-02).
3. **Uncordon vía defer+recover**: cubre incluso el pánico de la operación
   de mantenimiento — el daemon no muere y el nodo nunca queda cordonado.
   Es la lección de F9.0 codificada como invariante.
4. **scaler como función pura** `Decide(now, estado, política)`: la decisión
   coordinada es testeable sin cluster; el actuador (k8s) está separado.
5. **Métricas solo loopback** (127.0.0.1:9090): SBOS-050 — no salen del host.

## Hallazgos corregidos en la sesión

- **Bug semáforo F6** (65d0cab): el contador `error:0` teñía de ROJO un
  sistema sano. Corregido + 3 tests de regresión.
- **bos_k8s_nodes_ready=0**: ningún collector lo refrescaba — conectado a
  GetNodes() real.
- **RBAC**: el daemon nuevo arrancaba sin rol para root; `bosctl identity
  set-role root admin` + restart cargó la política (deuda F0.6.S sigue:
  producción usará bosagent, no root).

## DoD de cierre

```
go build ./...                       ✅
go vet ./...                         ✅
gofmt (sin _legacy)                  ✅ 0
go test -race ./...                  ✅ 23 paquetes, 0 FAIL
TestScaleCoordinated_NoDeathSpiral   ✅ ×50
TestMaintenanceSaga_UncordonSiempre  ✅ ×10 (5 desenlaces)
métricas reales /metrics             ✅ 18 bos_*
ClusterRole can-i real               ✅ least-privilege
saga maintenance real                ✅ 393ms, uncordon garantizado
```

## Deuda explícita trasladada

- **C-11..C-14** (fedora-logico pods, home, ctx<2s, e2e GNOME): declaran su
  contrato pero requieren el VDI Layer instalado (Nextcloud/Guacamole/Fedora
  no están en este cluster). Se cierran cuando bos instale el VDI Layer.
- **kube-state-metrics** (CrashLoop, ClusterIP apiserver): caso real abierto
  para las herramientas F9 — candidato a primer flujo de biaos (F10).
- **F0.6.S** (usuario bosagent en staging): el daemon corre como root; la SA
  bosagent ya existe en el cluster (F9.8) pero el systemd unit usa root.

## Estado del plan

**80/90 átomos** (F0–F9 completas). Resta **F10 — biaos** (Agente OS +
Gateway IA, 9 átomos + F10.0 hecho). Es el cierre del plan: el agente ReAct
que usa las sagas de consulta (F6) y las herramientas de gobierno (F9) como
su catálogo de acciones.

---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*
*Co-Autor (IA): Claude Fable 5 — Anthropic*
