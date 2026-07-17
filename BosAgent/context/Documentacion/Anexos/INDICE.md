# Índice de Anexos — BOS Control Plane Soberano
## Documentos de respaldo, comparaciones y especificaciones detalladas

**Versión:** 1.0.0
**Mantenido por:** bos-developer
**Última actualización:** 2026-07-17

---

## Anexos disponibles

| N° | Anexo | Referencia | Estado |
|:--:|-------|------------|:------:|
| A.01 | [Estado del Arte — Planos de Control en la Industria (2026)](A.01_ANEXO-INDUSTRIA-CONTROL-PLANES.md) | 0.00 §3 | ✅ |
| A.02 | [Estructura del Servidor de Producción SBOS](A.02_ANEXO-ESTRUCTURA-SERVIDOR-PRODUCCION.md) | 0.00 · 1.01 | ✅ |
| A.03 | [Plataforma Web Multi-Tenant con Nginx](A.03_ANEXO-PLATAFORMA-WEB-MULTI-TENANT-NGINX.md) | 1.01 · FASE 18 | ✅ |
| A.04 | Stack Canónico y Puertos (SBOS-050) | 1.01 §10 | ⬜ |
| A.05 | Anatomía Canónica de Ficha (SBOS-019 + servers.yml) | 3.01 | ⬜ |

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
