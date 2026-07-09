# INSTRUCCIONES DE EJECUCIÓN — Átomo F7.8
## Runbooks Operacionales (3 archivos)
## Para: Agente ejecutor (Claude Code / desarrollador)

**Átomo:** F7.8 — Runbooks operacionales (cierra GAP 3)
**Requiere previo:** F0.6 ✅ (repositorio existe con estructura docs/)
**Duración estimada:** 10 minutos (solo copiar y hacer commit)
**Riesgo:** Ninguno — solo agrega archivos nuevos de documentación

---

## CONTEXTO

Los 3 runbooks fueron generados íntegramente desde el knowledge del proyecto.
No requieren investigación adicional ni decisiones del agente.
Esta es la tarea más simple del plan: copiar 5 archivos y hacer commit.

---

## PASO 1 — Crear estructura y copiar archivos

```bash
# En VPS DEV (144.91.76.130):
ssh skull@144.91.76.130
cd <ruta_del_repositorio>

# Crear directorio:
mkdir -p docs/runbooks

# Copiar los 5 archivos (desde los outputs generados):
# RB-01:
cp /ruta/outputs/docs/runbooks/RB-01-FICHA-DEGRADADA.md       docs/runbooks/
# RB-02:
cp /ruta/outputs/docs/runbooks/RB-02-DATA-RACE-DETECTADA.md   docs/runbooks/
# RB-03:
cp /ruta/outputs/docs/runbooks/RB-03-CONTEXT-PLANE-DOWN.md    docs/runbooks/
# Índice:
cp /ruta/outputs/docs/runbooks/INDEX.md                        docs/runbooks/
# Log de incidentes:
cp /ruta/outputs/docs/runbooks/INCIDENTES-LOG.md               docs/runbooks/
```

**Verificar:**
```bash
ls docs/runbooks/
# debe mostrar 5 archivos:
# INCIDENTES-LOG.md  INDEX.md  RB-01-FICHA-DEGRADADA.md
# RB-02-DATA-RACE-DETECTADA.md  RB-03-CONTEXT-PLANE-DOWN.md

wc -l docs/runbooks/*.md
# RB-01 debe tener ~130 líneas
# RB-02 debe tener ~130 líneas
# RB-03 debe tener ~140 líneas
```

---

## PASO 2 — Verificar contenido crítico

```bash
# RB-01 tiene la advertencia pre-F1.5:
grep "F1.5" docs/runbooks/RB-01-FICHA-DEGRADADA.md && echo "✅ advertencia F1.5 presente"

# RB-02 tiene la solución temporal:
grep "watchdog_auto_repair" docs/runbooks/RB-02-DATA-RACE-DETECTADA.md && echo "✅ solución temporal presente"

# RB-03 distingue F5.x implementado vs pendiente:
grep "F5.x pendiente" docs/runbooks/RB-03-CONTEXT-PLANE-DOWN.md && echo "✅ caso F5.x presente"

# INDEX.md tiene los 3 runbooks:
grep -c "RB-0" docs/runbooks/INDEX.md | grep "^3$" && echo "✅ 3 runbooks en índice"
```

---

## PASO 3 — Commit y push

```bash
git add docs/runbooks/

git status
# debe mostrar solo los 5 archivos nuevos en docs/runbooks/

git commit -m "[F7.8] docs: 3 runbooks operacionales + índice + log de incidentes

GAP 3 del BOS-REPAIR-PLAN-MAESTRO-v3 cerrado.

Runbooks:
  docs/runbooks/RB-01-FICHA-DEGRADADA.md      — 5 casos (OOM, disco, deps, saga, estado)
  docs/runbooks/RB-02-DATA-RACE-DETECTADA.md  — P6/P14 + solución temporal y permanente F1.5
  docs/runbooks/RB-03-CONTEXT-PLANE-DOWN.md   — 4 casos (Redis/PG/código/TTL)

Infraestructura:
  docs/runbooks/INDEX.md         — tabla de runbooks + 5 candidatos futuros
  docs/runbooks/INCIDENTES-LOG.md — registro histórico ISO 27001 A.8.15

Generados desde: BOS-REPAIR-00..13 + internal/repair/repair_manager.go
Sin investigación externa requerida.
Informe de Cierre: INFORME-CIERRE-F7.8-RUNBOOKS.md"

git push origin main
```

---

## PASO 4 — Verificar pipeline CI

```
GitHub Actions → último run → debe mostrar:
  ✅ Build & Lint
  ✅ Race Detection
  ✅ Pipeline Status
  (los archivos .md no afectan los tests de Go)
```

---

## CRITERIO DE ÉXITO

```bash
ls docs/runbooks/ | wc -l | grep "^5$" && echo "✅ F7.8 COMPLETO"
```

---

*Instrucciones F7.8 · BOS-REPAIR · SKULL · SBOS · 07 de Junio 2026*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
