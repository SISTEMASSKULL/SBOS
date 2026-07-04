# ADR-040 — Mínimo Viable Progresivo: Patrón de Instalación de Fichas

**Estado:** Aceptado  
**Fecha:** 2026-06-17  
**Origen:** SBOS-BOOTSTRAP-MANUAL.md v3.2 + incidente M2.2 (k3s vs kubeadm)  
**Resuelve:** El problema del huevo y la gallina en la instalación del stack SBOS  

---

## Contexto

El stack SBOS tiene dependencias circulares: Vault necesita PostgreSQL como backend, PostgreSQL necesita Vault para secretos en producción. K8s necesita Calico, Calico necesita NetworkPolicies, NetworkPolicies necesitan K8s. La instalación secuencial ingenua falla porque cada ficha exige que sus dependencias estén completas antes de empezar.

## Decisión

**Cada ficha se instala en modo mínimo viable primero, y se especializa en sucesivas pasadas hasta alcanzar su configuración completa.** Este es el patrón documentado en SBOS-BOOTSTRAP-MANUAL.md §"El problema del huevo y la gallina".

### Las 6 Capas del Bootstrap

```
CAPA 0 — S-HOST (OS)
  sbos-bootstrap-os: kernel modules, sysctl, /data/, herramientas base
  bos-preflight: paquetes SO, usuario bosagent, certificado TLS

CAPA 1 — S-HOST (K8s mínimo viable)
  sbos-bootstrap-k8s: kubeadm/k3s + containerd + Calico básico
  sbos-bootstrap-cni: Calico CNI operativo
  sbos-bootstrap-storage: StorageClass, PVs

CAPA 2 — S01 (Datos — primera pasada mínima)
  postgresql: PG 18.4 con credenciales bootstrap (sin Vault)
  redis: Redis 8.6.2 con AOF
  minio: object storage mínimo

CAPA 3 — S02-S03 (Identidad y Gateway — primera pasada)
  vault: init + unseal + PKI + AppRole
  keycloak: realm + 5 SPIs
  kong: API Gateway básico
  nginx, certbot, oauth2-proxy

CAPA 4 — S06 (Notificaciones)
  sbos-notifier: push MFA + notificaciones

CAPA 5 — S-HOST (Hardening — segunda pasada)
  sbos-bootstrap-hard: CIS hardening, UFW, Kyverno
  postgresql (segunda pasada): migrar a credenciales Vault
  redis (segunda pasada): ACLs desde Vault
```

### Principio de Pasadas

```
Pasada 1: MÍNIMO VIABLE (cada ficha funciona con defaults bootstrap)
  └─ PG: credenciales bootstrap en texto (desarrollo)
  └─ Vault: init con Shamir, sin secretos de otras fichas aún
  └─ KC: realm creado, sin Vault para credenciales

Pasada 2: ROBUSTECER (segunda pasada sobre las mismas fichas)
  └─ PG: credenciales migradas a Vault → ficha_repair()
  └─ Vault: paths para cada ficha → ficha_update()
  └─ KC: credenciales en Vault → ficha_repair()

Pasada N: CERTIFICAR (sucesivas pasadas hasta estado deseado)
  └─ ficha_repair() es idempotente: detecta el estado actual y converge
```

## Consecuencias

### Positivas
- Rompe el ciclo huevo-gallina: cada ficha se instala con lo que hay disponible
- Idempotencia: `ficha_repair()` converge al estado deseado sin importar el estado inicial
- k3s vs kubeadm: staging usa k3s (mínimo viable), producción usará kubeadm. Mismo task_catalog.sh con detección de entorno

### Negativas
- Las fichas deben soportar múltiples modos (bootstrap vs producción)
- Mayor complejidad en task_catalog.sh: detectar estado actual y decidir qué aplicar

## Regla de Implementación

**Toda ficha DEBE:**
1. Tener un modo "mínimo viable" que funcione sin dependencias externas completas
2. `ficha_repair()` DEBE detectar el estado actual y converger al estado deseado
3. Las credenciales bootstrap son TEMPORALES — la segunda pasada las reemplaza por Vault

**Ninguna ficha debe:**
- Exigir que Vault esté operativo para instalarse
- Fallar si su dependencia existe pero en modo mínimo (no completo)

## Referencias
- SBOS-BOOTSTRAP-MANUAL.md v3.2 — Rutina de bootstrap, 6 capas progresivas
- ADR-021 — Máquina de 18 estados de ficha
- SOV-08 — Sin ficha → crear ficha nueva
- M2.2 — Incidente k3s vs kubeadm, task_catalog.sh exit 127

---

*ADR-040 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
