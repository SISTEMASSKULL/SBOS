# ADR-041 — Verificación Post-Instalación No Bloqueante en PASADA 1

**Estado:** Aceptado
**Fecha:** 2026-06-18
**Origen:** 3 bloqueos recurrentes en vault_init, crear_realm_tenant (keycloak), wait_ready (kong)
**Resuelve:** Las verificaciones que dependen de herramientas ausentes o tiempos de startup
             no deben bloquear la instalación mínima viable

---

## Contexto

En el bootstrap PASADA 1 (ADR-040), 3 pasos de verificación fallaban sistemáticamente:

| Paso | Ficha | Causa |
|------|-------|-------|
| `vault_init` | vault | `kubectl exec` tarda ~8s después de `phase=Running` en ser funcional |
| `crear_realm_tenant` | keycloak | `curl` no existe en la imagen `quay.io/keycloak/keycloak:26.6.2` |
| `wait_ready` | kong | Sin readiness probe, `kubectl wait --for=condition=Ready` nunca se cumple |

Los pods estaban Running y funcionales, pero los pasos de verificación los marcaban como fallidos.

## Decisión

**En PASADA 1, los pasos de verificación post-instalación NO son bloqueantes.**
Si fallan, la ficha se instala igual y el reconcile loop (`ficha_repair` cada 5 min)
converge cuando las condiciones estén dadas.

| Paso | Antes (bloqueante) | Ahora (ADR-041) |
|------|-------------------|-----------------|
| `vault_init` | `return 1` si vault no responde | `STEP_SKIP` + log "ficha_repair pendiente" |
| `crear_realm_tenant` | `return 1` si no hay token | `STEP_SKIP` + log "realm pendiente PASADA 2" |
| `wait_ready` (kong) | `return 1` si timeout | `sleep 15` + `kong health` + `STEP_SKIP` si no healthy |

## Principio

> **El operador Kubernetes no espera a que el pod esté Ready. Lo crea y un reconcile loop**
> **separado verifica el estado después. La instalación es asíncrona por naturaleza.**
>
> **PASADA 1 = desplegar el pod. PASADA 2 (ficha_repair) = verificar y converger.**

## Consecuencias

### Positivas
- Las 3 fichas completan su instalación en PASADA 1 sin bloqueos
- El reconcile loop (cada 5 min) llama `ficha_repair` que converge al estado deseado
- No se requieren herramientas externas (curl) en los contenedores

### Negativas
- El estado post-instalación puede ser `DEGRADADA` hasta que `ficha_repair` converja
- Requiere que `ficha_repair` sea idempotente y detecte el estado real

## Referencias
- ADR-040 — Mínimo viable progresivo (2 pasadas)
- Kubernetes Operator Pattern — reconcile loop, declarative state
- SBOS-BOOTSTRAP-MANUAL.md — 6 capas progresivas

---

*ADR-041 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
