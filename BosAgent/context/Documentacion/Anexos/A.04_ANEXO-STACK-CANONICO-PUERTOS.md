# Anexo A.04 — Stack Canónico y Puertos (SBOS-050)
## Versiones obligatorias (ADR-017) y catálogo base de puertos del stack Alpha

**Versión:** 1.0.0 · **Fecha:** 2026-07-17 · **Autor:** bos-developer — SBOS
**Fortalece al motor:** ① IAM Installer
**Referencia:** [1.01 — IAM Installer](../1.01_MANUAL-IAM-INSTALLER.md)

---

## 1. Stack Canónico (ADR-017)

| Componente | Versión |
|-----------|---------|
| Ubuntu Server | 26.04 LTS |
| PostgreSQL | 18.4 |
| Redis | 8.6.2 |
| Keycloak | 26.6.2 |
| Vault | 2.0.1 |
| Kong | 3.9.x LTS |
| Kubernetes (kubeadm) | v1.32.x |
| Calico CNI | 3.32.0 |
| Go | 1.26+ |
| Rust | 1.85+ |

## 2. Puertos base del stack Alpha

| Puerto | Propietario | Acceso |
|:------:|-------------|--------|
| 22 | SSH | Externo (UFW) |
| 443 | Kong / nginx (S16) | Externo |
| 9443 | BOS Context API | Interno (Kong→BOS) |
| 6443 | K8s API Server | Interno |
| 5432 | PostgreSQL (ClusterIP :8100) | Interno |
| 6379 | Redis (ClusterIP :8120) | Interno |
| 8080 | Keycloak (ClusterIP :8200) | Interno |
| 8200 | Vault (ClusterIP :8300) | Interno |
| 9090 | BOS Prometheus | localhost |

Catálogo completo: SBOS-050-PORT-CATALOG.md (108 apps, 15 servidores).

---

*SKULL · SBOS · BosAgent · Julio 2026*
