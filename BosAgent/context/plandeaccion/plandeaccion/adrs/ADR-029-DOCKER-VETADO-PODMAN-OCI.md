# ADR-029 — Docker Vetado — Solo Podman/OCI con Firma Ed25519

**Estado:** Aceptado  
**Fecha:** 2026-06-13  
**Origen:** §18 Regla 8 del Master v2.1  
**Relacionado:** ADR-017, ADR-025 (licencias OSI-approved)

---

## Contexto y problema

Docker Desktop tiene licencia propietaria para empresas (viola ADR-025). El Docker daemon corre con privilegios de root de forma estructural y su socket (`/var/run/docker.sock`) montado en un contenedor da control total del host. Además, Docker Inc. ha cambiado su modelo de licenciamiento múltiples veces, creando incertidumbre legal para un sistema soberano.

Podman es daemonless, rootless por defecto, y tiene licencia Apache 2.0. El formato OCI es el estándar abierto de contenedores que K8s usa nativamente (CRI-O, containerd).

## La Decisión

**Solo Podman 5.3.x (ADR-017) y formato OCI para contenedores. Docker está vetado en todos los entornos del SBOS (desarrollo, staging, producción). Las imágenes se firman con Ed25519.**

```
PERMITIDO:
  ✅ Podman 5.3.x (rootless, daemonless)
  ✅ Imágenes OCI (Open Container Initiative)
  ✅ Firma de imágenes: cosign con clave Ed25519
  ✅ Verificación de firma en admission controller (Kyverno)
  ✅ buildah para construir imágenes OCI
  ✅ skopeo para copiar/inspeccionar imágenes
  ✅ CRI-O como container runtime en K8s

VETADO:
  ❌ Docker Engine / Docker Desktop
  ❌ docker-compose (usar fichas SBOS — ADR-027)
  ❌ Imágenes sin firma Ed25519 en producción
  ❌ Imagen con tag `latest` — siempre versión fija (ADR-017)
  ❌ Imágenes descargadas de Docker Hub sin verificación de firma
```

## Proceso de Build y Firma de Imágenes

```bash
# Construir imagen OCI
buildah bud -t sbos/bos:1.0.0 .

# Firmar con Ed25519 (SKULL Release Plane)
cosign sign --key vault://sbos/signing/ed25519 sbos/bos:1.0.0

# Verificar antes de deploy (Kyverno lo hace automáticamente)
cosign verify --key vault://sbos/signing/ed25519.pub sbos/bos:1.0.0
```

La política Kyverno en `servers/S-HOST/kyverno/resources/policies/verify-image-signature.yaml` bloquea pods con imágenes no firmadas.

## Consecuencias

**Positivas:**
- Sin Docker daemon privilegiado corriendo en el host
- Kyverno garantiza que solo imágenes firmadas por SKULL Release Plane entran al cluster
- Cadena de confianza completa: código → imagen → firma → verificación en deploy
- Cumple SLSA Level 2 (provenance + signature)

**Negativas/Riesgos:**
- Algunos tutoriales y herramientas de CI asumen Docker
- Mitigación: GitHub Actions / GitLab CI tienen soporte nativo para Podman

## Normas relacionadas

- ADR-025 (Solo licencias OSI-approved — Docker Desktop la viola)
- ADR-027 (K8s desde el día 1 — CRI-O como runtime)
- SBOS-041-RELEASE-PLANE (Ed25519 + SHA-256 en el release plane)
- SLSA Framework Level 2 (Supply-chain Levels for Software Artifacts)
