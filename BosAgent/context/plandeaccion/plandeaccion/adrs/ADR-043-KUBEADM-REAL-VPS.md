# ADR-043 — kubeadm Real en VPS Staging (No k3s)

**Estado:** Aceptado
**Fecha:** 2026-06-18
**Origen:** Corrección de decisión errónea de usar k3s en staging
**Reemplaza:** Instalación manual de k3s del 2026-06-17

---

## Contexto

El 2026-06-17 se instaló k3s manualmente en la VPS de staging (13.140.128.230)
como atajo para tener Kubernetes rápido. Esto fue un error:

1. k3s usa flannel como CNI, no Calico
2. Las fichas `sbos-bootstrap-k8s` y `sbos-bootstrap-cni` están diseñadas para kubeadm + Calico
3. Se creó una falsa dicotomía entre "staging con k3s" y "producción con kubeadm"
4. Los task_catalog.sh tuvieron que adaptarse artificialmente (PVC local-path, sin Calico)

## Decisión

**La VPS de staging usa kubeadm + Calico real, igual que producción.**
k3s estaba planificado para contenedores de prueba (nspawn), no para la VPS.
La VPS tiene recursos suficientes (11GB RAM, 6 cores, 383GB disco).

| Componente | Antes (erróneo) | Ahora (correcto) |
|-----------|-----------------|-----------------|
| Kubernetes | k3s v1.32.3 (manual) | kubeadm v1.32.13 |
| CNI | flannel (k3s default) | Calico 3.32.0 |
| Container runtime | containerd (k3s bundled) | containerd 2.2.4 |
| Instalación | `curl -sfL https://get.k3s.io | sh` | Ficha `sbos-bootstrap-k8s` |

## Consecuencias

### Positivas
- Staging = producción en miniatura. Lo que funciona en VPS, funciona en producción
- Las fichas `sbos-bootstrap-k8s` y `sbos-bootstrap-cni` se usan sin modificaciones artificiales
- Calico NetworkPolicy funciona realmente (deny-all, allowlist)
- Los task_catalog.sh de PG/Redis/Vault/KC/Kong no necesitan adaptaciones k3s

### Negativas
- Se pierde el stack instalado sobre k3s (hay que reinstalar sobre kubeadm)
- kubeadm consume más recursos que k3s (~2GB extra de RAM)
- El bootstrap inicial es más lento (kubeadm init + Calico ~5min vs k3s ~30s)

## Lecciones aprendidas

1. **No tomar atajos en staging.** Si producción usa X, staging también.
2. **Las fichas son la fuente de verdad.** Si una ficha no funciona, se corrige la ficha, no se cambia la infraestructura.
3. **SOV-07:** Toda tarea manual en staging DEBE convertirse en ficha. k3s se instaló manualmente → debió ser `sbos-bootstrap-k8s`.

## Referencias
- SBOS-BOOTSTRAP-MANUAL.md — 6 capas progresivas (kubeadm + Calico en Capa 1)
- ADR-040 — Mínimo viable progresivo
- SOV-07 — Sin tareas manuales en staging

---

*ADR-043 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
