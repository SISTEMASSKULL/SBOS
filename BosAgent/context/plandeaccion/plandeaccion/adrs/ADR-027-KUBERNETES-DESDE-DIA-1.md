# ADR-027 — Kubernetes Desde el Día 1 — Sin Modo Standalone

**Estado:** Aceptado  
**Fecha:** 2026-06-13  
**Origen:** §18 Regla 5 del Master v2.1  
**Relacionado:** ADR-017, ADR-022, SBOS-007-DEPLOY

---

## Contexto y problema

Algunos proyectos comienzan con un modo "simple" o "standalone" (sin K8s) para facilitar el desarrollo inicial, con la intención de migrar "después". Esta decisión invariablemente produce una bifurcación del código que jamás se reconcilia: el modo standalone se convierte en deuda técnica permanente.

El SBOS es un sistema operativo empresarial. No tiene sentido el concepto de "modo sin K8s" igual que Linux no tiene un "modo sin kernel". K8s es parte de la infraestructura base, no un opcional.

## La Decisión

**No existe modo standalone ni modo de desarrollo sin Kubernetes. Todo componente del SBOS se empaqueta, prueba y ejecuta como ficha SBOS desde la primera línea de código.**

```
PERMITIDO:
  ✅ k3s v1.32+ en una sola máquina para desarrollo (single-node)
  ✅ k3s en nspawn blindado para pruebas del Operador
  ✅ minikube en pipelines CI (solo para tests de fichas)
  ✅ k3s multi-nodo en staging y producción

VETADO:
  ❌ Modo "standalone" sin K8s
  ❌ Ejecutar daemons directamente sin ficha (excepto bos y daemons soberanos en host)
  ❌ docker-compose como alternativa a fichas
  ❌ "Después migramos a K8s" — no existe ese después
```

## Excepción Documentada: Daemons Soberanos en Host

Los 8 daemons soberanos (bos, bAuth, bKernel, biedata, bSearch, bhnexus, banexus, bNotify) corren como `systemd` en el HOST Ubuntu 26.04 fuera de K8s. Esto NO viola este ADR: son componentes del plano de control soberano, no fichas instalables. Las aplicaciones de negocio (Tryton, Kong, Keycloak, Vault, etc.) son fichas K8s.

## Consecuencias

**Positivas:**
- No hay "deuda de migración" futura
- NetworkPolicies, mTLS Linkerd, Kyverno aplicados desde el primer deploy
- El DAG de fichas del bos funciona desde el inicio
- CI/CD valida fichas K8s desde el primer commit

**Negativas/Riesgos:**
- La curva de aprendizaje inicial es mayor (k3s vs docker-compose)
- Mitigación: k3s single-node hace el setup trivial (1 comando). SBOS-BOOTSTRAP-MANUAL.md cubre esto.

## Normas relacionadas

- SBOS-007-DEPLOY (topología de despliegue)
- ADR-029 (Podman/OCI — sin Docker)
- SBOS-BOOTSTRAP-MANUAL.md (6 capas progresivas)
