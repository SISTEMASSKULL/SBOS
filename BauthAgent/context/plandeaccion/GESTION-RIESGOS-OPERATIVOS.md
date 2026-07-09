# GESTIÓN DE RIESGOS OPERATIVOS — bAuth
## Matriz de riesgos, mitigaciones y contingencias

**Versión:** 1.0 · **Fecha:** 2026-06-19

---

| ID | Riesgo | Prob | Impacto | Nivel | Mitigación |
|----|--------|------|---------|-------|------------|
| R-01 | Go toolchain no instalado | Alta | Bloqueante | 🔴 | Instalar Go 1.22+ en B0 |
| R-02 | Keycloak no accesible | Baja | Bloqueante | 🟡 | KC ya operativo en VPS |
| R-03 | Tryton no accesible | Baja | Bloqueante | 🟡 | Tryton ya desplegado en VPS |
| R-04 | SPIs Java no compilan | Media | Retraso | 🟠 | Java 17 + Maven pre-requisito |
| R-05 | Conflict Matrix incompleta | Media | Retraso | 🟡 | 20+ conflictos predefinidos en spec |
| R-06 | Cache Redis no reduce latencia | Baja | Degradación | 🟡 | Cache TTL 30s → < 1ms P50 |
| R-07 | Reconcile loop sobrecarga KC | Media | Degradación | 🟡 | Loop cada 60s con backoff |
| R-08 | Unix socket permisos incorrectos | Media | Bloqueante | 🟠 | Verificar 0660 grupo bosagent |

---
*GESTION-RIESGOS-OPERATIVOS v1.0 · 2026-06-19*
