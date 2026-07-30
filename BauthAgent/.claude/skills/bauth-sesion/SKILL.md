---
name: bauth-sesion
description: >
  Protocolo de inicio de sesión del agente bAuth. Recupera el contexto de la sesión
  anterior desde SKDATA, muestra el estado real de los 7 motores y el plan de acción
  activo. Invocar al inicio de cada sesión con /bauth-sesion antes de cualquier trabajo.
disable-model-invocation: true
---

# Skill — bAuth: Arranque de Sesión

**Regla:** leer el estado real antes de asumir nada. SKDATA y el código son la única verdad.

## PASO 1 — Recuperar contexto anterior (SKDATA)

> **Dos bases de datos distintas:**
> - **SKDATA** (puerto 5402, host local): BD meta de la **fábrica** — bitácora de agentes, sesiones, tracking de tareas. Aquí vive `memoria.bitacora_agente`.
> - **SBOSDB** (VPS de pruebas): BD **operativa de bAuth** — identidades, roles, sesiones, auditoría. Schema: `SBOS_db` en producción. Ver skill `bauth-ddl` para detalles.

```bash
psql "postgresql://root@localhost:5402/SKDATA" -t -A -c \
  "SELECT donde_quede || chr(10) || 'Falta: ' || que_falta || chr(10) || 'Siguiente: ' || proxima_accion
   FROM memoria.bitacora_agente
   WHERE agente_id = 'bauth'
   ORDER BY actualizado_en DESC LIMIT 1" 2>/dev/null \
  || echo "Sin bitácora previa — sesión nueva"
```

## PASO 2 — Estado real de los 7 motores

Leer la portada de cada motor ANTES de tocar su código:

```bash
cat context/Documentacion/MOTORES/MOTORES-INDEX.md
```

| Motor | Frontera de código | Estado actual |
|-------|-------------------|:---:|
| BitMask | `src/bitmask/` | ✅ robusto |
| Métodos | `src/domain/auth_methods/` | 🔄 9/18 |
| Políticas (PDP) | `src/policy/` *(a crear)* | 🔄 fail-open → URGENTE |
| Canales | `src/transport/` *(a crear)* | ⬜ PLT-17 |
| Criptográfico | `src/crypto/` *(a crear)* | ⬜ CORE-11 |
| Firma | `src/domain/signature/` | 🔄 interno ✅ / ADSIB ⬜ |
| Auditoría | `src/audit/` | 🔄 esqueleto |

**Orden de convergencia (ADR-013):**
1. Políticas → fail-closed (`None ⇒ denegado`)
2. Criptográfico + Canales → extraer lo disperso
3. Métodos → completar 9 → 18
4. Firma ADSIB + Auditoría → cablear emisor

## PASO 3 — Plan de acción activo

```bash
ls context/plandeaccion/REPARACIONBAUTH/ 2>/dev/null | head -20
# Abrir el documento de plan más reciente si hay uno activo
```

## PASO 4 — Reportar al humano

En ≤ 8 líneas: dónde quedé · motor actual · gap P1 más urgente · qué hago esta sesión.

## PASO 5 — Actualizar bitácora al cierre

Al terminar la sesión (o cada ~30 min de trabajo):

```sql
INSERT INTO memoria.bitacora_agente
  (agente_id, proyecto, donde_quede, que_falta, proxima_accion,
   git_branch, git_ultimo_commit)
VALUES
  ('bauth', 'sbos', '<avance concreto>', '<pendiente concreto>',
   '<siguiente acción>', '<branch>', '<sha corto>')
ON CONFLICT (agente_id) DO UPDATE
  SET donde_quede     = EXCLUDED.donde_quede,
      que_falta       = EXCLUDED.que_falta,
      proxima_accion  = EXCLUDED.proxima_accion,
      git_ultimo_commit = EXCLUDED.git_ultimo_commit,
      actualizado_en  = now();
```

## Prohibiciones permanentes (C12 + ORQUESTA-051)

- **Sin evidencia AA-1 = rechazo automático.** Usar `scripts/verificar_afirmacion.sh`.
- No tocar código de otros daemons.
- No afirmar que algo compila sin ejecutar `cargo check` y mostrar la salida.
- Español siempre.
