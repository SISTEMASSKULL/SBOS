# InfraAgent
**Proyecto:** SBOS — Sovereign Business Operating System
**Árbol:** 26a83fa0-d71c-476b-b52c-4cb14bdd2929
**Nodo SKDATA:** infra-agent
**Perfil:** dominio
**Materializado:** 2026-05-12
**Materializador:** Compositor — Fase C

## Ownership del código

El código de infraestructura tiene dos ubicaciones con contenido distinto:

| Directorio | Contenido | Estado |
|---|---|---|
| `InfraAgent/src/servers/` | 11 fichas de componentes infra (vault, postgresql, redis, minio, linkerd, kyverno, sbos-bootstrap-*, sbos-k8s-*) | 4/13 implementadas |
| `BosAgent/staging/core/servers/` | 4 servidores de despliegue (dataserver, gatewayserver, identityserver, monitorserver) | Staging scripts |

**No se creó symlink** `InfraAgent/src/servers/ → ../BosAgent/staging/core/servers/`
porque los directorios contienen datasets distintos. Ver GAP-005 en el Tomo I de
mejoras continuas. La consolidación requiere migración formal, no symlink.
