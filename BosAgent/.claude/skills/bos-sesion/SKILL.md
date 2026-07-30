---
name: bos-sesion
description: >
  Protocolo de inicio de sesión del agente bos-developer. Recupera el contexto
  de la sesión anterior desde SKDATA, muestra el estado real de los 6 motores
  y confirma el plan de trabajo. Invocar al inicio de cada sesión con /bos-sesion.
disable-model-invocation: true
---

# Skill — BOS: Arranque de Sesión

**Regla:** leer el estado real antes de asumir nada. SKDATA y el código son la única verdad.

## PASO 1 — Recuperar contexto anterior (SKDATA)

> **Dos bases de datos distintas:**
> - **SKDATA** (puerto 5402, host local): BD meta de la **fábrica** — bitácora de agentes, sesiones, tracking. Aquí vive `memoria.bitacora_agente`.
> - **SBOSDB** (VPS de pruebas): BD **operativa** del stack SBOS — no es la bitácora del agente.

```bash
psql "postgresql://root@localhost:5402/SKDATA" -t -A -c \
  "SELECT donde_quede || chr(10) || 'Falta: ' || que_falta || chr(10) || 'Siguiente: ' || proxima_accion
   FROM memoria.bitacora_agente
   WHERE agente_id = 'bos'
   ORDER BY actualizado_en DESC LIMIT 1" 2>/dev/null \
  || echo "Sin bitácora previa — sesión nueva"
```

## PASO 2 — Estado real de los 6 motores

Leer el índice maestro antes de tocar cualquier código:

```bash
cat context/Documentacion/INDICE.md
```

| Motor | Paquetes Go principales | Estado referencial |
|-------|------------------------|-------------------|
| ① IAM Installer | `internal/installer/`, `internal/bootstrap/` | manuales 1.01–1.05 |
| ② SO Observable | `internal/observer/`, `internal/health/`, `internal/reconcile/` | manuales 2.01–2.04 |
| ③ Server FICHAS | `internal/ficha/`, `internal/plugin/`, `internal/scaler/` | manuales 3.01–3.08 |
| ④ Context Plane | `internal/context/` | manuales 4.01–4.05 |
| ⑤ Dashboard | `internal/server/` | manuales 5.01–5.04 |
| ⑥ Banco de Pruebas | (vivo — sin código propio) | manual 6.01 |

**Orden de prioridad de motores:** ver `0.00_MANUAL-DIRECTRICES-BOS-CONTROL-PLANE.md` → carta rectora.

## PASO 3 — Consultar grafo del código (MCP)

Antes de leer archivos, orientarse con las herramientas MCP:

```python
# Estado real del código del motor en el que se va a trabajar
get_architecture(project="bos", aspects=["overview", "entry_points"])

# Buscar contexto semántico del área de trabajo
search_code(query="motor en el que voy a trabajar hoy", path="/opt/skull/orquestador/proyectos/SBOS/BosAgent")
```

Ver protocolo completo: `/bos-herramientas`

## PASO 4 — Reportar al humano

En ≤ 8 líneas: dónde quedé · motor actual · gap más urgente · qué hago esta sesión.

## PASO 5 — Actualizar bitácora al cierre

Al terminar la sesión (o cada ~30 min de trabajo):

```sql
INSERT INTO memoria.bitacora_agente
  (agente_id, proyecto, donde_quede, que_falta, proxima_accion,
   git_branch, git_ultimo_commit)
VALUES
  ('bos', 'sbos', '<avance concreto>', '<pendiente concreto>',
   '<siguiente acción>', '<branch>', '<sha corto>')
ON CONFLICT (agente_id) DO UPDATE
  SET donde_quede       = EXCLUDED.donde_quede,
      que_falta         = EXCLUDED.que_falta,
      proxima_accion    = EXCLUDED.proxima_accion,
      git_ultimo_commit = EXCLUDED.git_ultimo_commit,
      actualizado_en    = now();
```

## Prohibiciones permanentes

- **Sin evidencia AA-1 = rechazo automático.** Toda afirmación verificable necesita evidencia firmada.
- No tocar código de otros daemons (ORQUESTA-045).
- No afirmar que algo compila sin ejecutar `go build ./...` y mostrar la salida.
- No afirmar que los tests pasan sin ejecutar `go test -race ./...` y mostrar la salida.
- Español siempre.
