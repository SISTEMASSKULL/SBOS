# ADR-039 — RBAC Heredado de Ubuntu y Kubernetes, Sin RBAC Propio

**Estado:** Aceptado  
**Fecha:** 2026-06-17  
**Origen:** F4.4 + incidente nil pointer RBAC en VPS staging (M2.2)  
**Reemplaza:** FileRBAC, roles.json, sistema de roles propio del BOS  

---

## Contexto

El BOS implementó un sistema RBAC propio (`internal/security/rbac_provider.go`, `FileRBAC`, `roles.json`) que requería usuarios, roles y permisos definidos en un archivo JSON. Este sistema fue marcado como eliminado en F4.4 pero el código siguió referenciándolo, causando un nil pointer en staging cuando `bosRBAC` no se inicializaba en modo dev (`BOS_DEV_SKIP_ROOT=1`).

## Decisión

**El BOS no implementa RBAC propio. Toda autorización se hereda de:**

| Capa | Mecanismo | Qué controla |
|------|-----------|-------------|
| **Ubuntu (SO)** | Unix socket `/run/bos/bos.sock` con permisos `0660 root:bosagent` | Solo procesos del grupo `bosagent` pueden invocar RPC |
| **Ubuntu (SO)** | `sudo` / PAM | Acceso a comandos privilegiados del host |
| **Kubernetes** | K8s RBAC (RoleBindings, ClusterRoleBindings) via `kubectl` | Acceso a recursos del cluster (pods, deployments, secrets) |
| **Token compartido** | `/etc/bos/rpc-token` (0600) — simple, opcional | Verificación adicional para métodos destructivos |

**No existe:** roles.json, FileRBAC, RBACProvider interface, asignación usuario→rol.

## Consecuencias

### Positivas
- Sin nil pointer por RBAC no inicializado
- Sin archivo `roles.json` que mantener sincronizado
- La seguridad se apoya en mecanismos probados (Unix permissions, K8s RBAC)
- Menos código que mantener

### Negativas
- Sin control granular a nivel de método RPC (todos los métodos destructivos comparten el mismo token)
- En el futuro, si se necesita RBAC fino, se integrará con bAuth (ya planificado en F14.1)

## Alternativas consideradas

### Alternativa 1: Mantener FileRBAC con inicialización lazy
- Más complejo, otro archivo que mantener, no alineado con ADR-006
- Rechazado: F4.4 ya decidió eliminarlo

### Alternativa 2: Integrar con bAuth desde ahora
- bAuth no está implementado (F14.1 🔴)
- Rechazado: bloquea el desarrollo actual

### Alternativa 3: Sin RBAC, solo Unix socket + token compartido
- ✅ Elegido: mínimo, funcional, seguro para la fase actual

## Referencias
- ADR-006 — Eliminar RBAC propio del BOS
- F4.4 — Eliminar `rbac_provider.go`
- SBOS-050 §P9 — Unix socket como transporte entre daemons
- NIST SP 800-207 — Zero Trust: la autorización debe ser por sesión, no por rol estático

---

*ADR-039 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
