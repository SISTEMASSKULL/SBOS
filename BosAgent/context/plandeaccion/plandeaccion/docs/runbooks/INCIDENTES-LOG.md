# INCIDENTES-LOG — SBOS · SKULL
## Registro histórico de incidentes resueltos con runbooks

**Referencia normativa:** ISO 27001:2022 A.8.15 — Logging de actividades
**Propósito:** Trazabilidad post-incidente. Cada entrada es un registro
permanente — nunca eliminar entradas, solo agregar nuevas.

---

## Cómo registrar un incidente

Agregar ARRIBA del anterior (más reciente primero):

```markdown
## YYYY-MM-DD HH:MM — [RB-XX] Título descriptivo

**Componente:** <ficha_id o módulo>
**Tenant afectado:** skull / test / todos
**Causa confirmada:** descripción técnica de la causa raíz
**Diagnóstico:** qué comandos revelaron la causa
**Tiempo de resolución:** N minutos (desde detección hasta verificación final)
**Usuarios afectados:** N (0 si sin impacto en usuarios)
**Solución aplicada:** pasos exactos que resolvieron el problema
**Runbook seguido:** RB-XX — ¿aplicó completo? ¿qué paso no aplicó?
**Acción preventiva:** [átomo del plan que resuelve la causa raíz, o "ninguna"]
**Audit log traceparent:** [si disponible]
```

---

## Historial

*(vacío — se completará con el primer incidente real)*

---

*INCIDENTES-LOG.md v1.0 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
