# PROPOSITO — SBOS Bootstrap K8s

**Ficha:** `sbos-bootstrap-k8s` - **Servidor:** S00-hostserver - **Version:** 1.0
**Criticidad:** True - **Namespace:** sbos-installer - **Tipo:** Deployment
**Orden de instalacion:** 5

## Que es
kubeadm init + Calico CNI + CRI-O runtime

## Dependencias
sbos-bootstrap-os

## Bitacora
- Consolidada al catalogo canonico servers/ (doctrina servers/servers.yml). Manifest: manifest.yml.
- Cambios en esta ficha -> consulta al humano (recurso compartido, ORQUESTA-051).
