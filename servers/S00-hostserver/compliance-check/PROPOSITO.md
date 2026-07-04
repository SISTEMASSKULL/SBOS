# PROPOSITO — Compliance Check

**Ficha:** `compliance-check` - **Servidor:** S00-hostserver - **Version:** 1.0
**Criticidad:** False - **Namespace:** sbos-installer - **Tipo:** Deployment
**Orden de instalacion:** 330

## Que es
Weekly kube-bench CIS + Trivy CVEs

## Dependencias
kyverno

## Bitacora
- Consolidada al catalogo canonico servers/ (doctrina servers/servers.yml). Manifest: manifest.yml.
- Cambios en esta ficha -> consulta al humano (recurso compartido, ORQUESTA-051).
