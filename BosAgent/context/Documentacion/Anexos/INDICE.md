# Índice de Anexos — BOS Control Plane Soberano
## Documentos de respaldo, comparaciones y especificaciones detalladas

**Versión:** 1.2.0
**Mantenido por:** bos-developer
**Última actualización:** 2026-08-01

---

## Anexos disponibles

| N° | Anexo | Referencia | Estado |
|:--:|-------|------------|:------:|
| A.01 | [Estado del Arte — Planos de Control en la Industria (2026)](A.01_ANEXO-INDUSTRIA-CONTROL-PLANES.md) | 0.00 §3 | ✅ |
| A.02 | [Estructura del Servidor de Producción SBOS](A.02_ANEXO-ESTRUCTURA-SERVIDOR-PRODUCCION.md) | 0.00 · 1.01 | ✅ |
| A.03 | [Plataforma Web Multi-Tenant con Nginx](A.03_ANEXO-PLATAFORMA-WEB-MULTI-TENANT-NGINX.md) | 1.01 · FASE 18 | ✅ |
| A.04 | Stack Canónico y Puertos (SBOS-050) | 1.01 §10 | ⬜ |
| A.05 | Anatomía Canónica de Ficha (SBOS-019 + servers.yml) | 3.01 | ⬜ |
| A.06 | [Kubernetes Operator Pattern en BOS](A.06_ANEXO-KUBERNETES-OPERATOR-PATTERN.md) | 3.01 §2 | ✅ |
| A.07 | [Vault PKI y Gestión de Secretos](A.07_ANEXO-VAULT-PKI-SECRETS.md) | 1.01 · 1.04 | ✅ |
| A.08 | [Flujo End-to-End de Operación BOS](A.08_ANEXO-FLUJO-END-TO-END.md) | 2.01 | ✅ |
| A.09 | [Normas y Estándares Internacionales](A.09_ANEXO-NORMAS-ESTANDARES-INTERNACIONALES.md) | 1.05 | ✅ |
| A.10 | [Observabilidad BOS](A.10_ANEXO-OBSERVABILIDAD-BOS.md) | 2.03 | ✅ |
| A.11 | [Cadena de Instalación Completa](A.11_ANEXO-CADENA-INSTALACION.md) | 1.01 §4 · 1.02 | ✅ |
| A.12 | [Port Manager Kardex](A.12_ANEXO-PORT-MANAGER-KARDEX.md) | 3.08 | ✅ |
| A.13 | [VPS Prueba — Arquitectura K8s](A.13_ANEXO-VPS-PRUEBA-KUBERNETES-ARQUITECTURA.md) | — | ✅ |
| A.14 | [Propuesta DDL — 5 Tablas Faltantes del Schema bos](A.14_PROPUESTA-DDL-BOS-TABLAS-FALTANTES.md) | 1.01 §3.7 · 3.01 · 2.02 | 🔴 HITL |
| A.15 | [Network Security Manager — Firewall · Certificados · Puertos · IPS · Zero Trust](A.15_ANEXO-NETWORK-SECURITY-MANAGER.md) | 3.08 · 1.04 · 1.05 | ✅ |
| A.16 | [Zero Trust — Implementación](A.16_ANEXO-ZERO-TRUST-IMPLEMENTACION.md) | 1.05 · SBOS-050 | ✅ |
| A.17 | [FAPI2 — Certificación](A.17_ANEXO-FAPI2-CERTIFICACION.md) | 1.04 | ✅ |
| A.18 | [Gestión de Vulnerabilidades — Rol de bos (ISO 27001 A.8.8)](A.18_ANEXO-GESTION-VULNERABILIDADES-BOS.md) | ISO 27001 A.8.8 · T-BACKLOG-009 bAuth | ✅ |

---

## Relación con los manuales

```
0.00 DIRECTRICES
  ├── A.01 ← comparación con la industria (Terraform, Crossplane, ArgoCD...)
  └── A.02 ← estructura del servidor de producción

1.01 Bootstrap y Stack Alpha
  ├── A.02 ← servidores lógicos, backups, puertos
  ├── A.03 ← plataforma web multi-tenant con nginx
  └── A.04 ← catálogo de puertos SBOS-050 (pendiente)

3.01 Máquina de 18 Estados
  └── A.05 ← anatomía canónica de ficha (pendiente)
```

---

*SKULL · SBOS · BosAgent · Julio 2026*
