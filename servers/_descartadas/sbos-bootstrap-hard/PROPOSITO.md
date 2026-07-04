# PROPOSITO — sbos-bootstrap-hard

**Ficha:** `sbos-bootstrap-hard` - **Servidor:** S00-hostserver - **Version:** 1.0.0
**Criticidad:** True - **Namespace:** - - **Tipo:** bash
**Orden de instalacion:** 250

## Que es
CIS Hardening Bootstrap — UFW deny-all, Calico default-deny enforcement, Kyverno enforce mode, CIS Ubuntu 26.04 + K8s Benchmarks.

## Dependencias
sbos-bootstrap-cni, sbos-bootstrap-k8s, sbos-bootstrap-monitoring, prometheus, grafana

## Bitacora
- Consolidada al catalogo canonico servers/ (doctrina servers/servers.yml). Manifest: manifest.yml.
- Cambios en esta ficha -> consulta al humano (recurso compartido, ORQUESTA-051).
