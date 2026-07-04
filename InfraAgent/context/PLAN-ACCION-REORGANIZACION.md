# Plan de Acción — Reorganización Integral de la Fábrica SBOS
**Fecha:** 2026-07-02
**Autor:** Bibliotecario SBOS + humano
**Estado:** PENDIENTE DE APROBACIÓN

## Documentos base de este plan

| Documento | Qué aporta |
|-----------|-----------|
| `ESTRUCTURA-DIRECTORIOS.md` | Árbol canónico de carpetas objetivo |
| `SKDATA-MEMORIA-AGENTES.md` | DDL rediseñado para la BD |
| `AUDITORIA-CODIGO-PYTHON.md` | 5 bugs + stubs + diagnóstico SKDATA |
| `AUDITORIA-TMUX-FABRICA.md` | Problemas del script + 4 preguntas abiertas |
| `PLAN-REESTRUCTURACION-FABRICA.md` | Fases A-E del plan de mejora |

---

## FASE 0 — BACKUP INMEDIATO
**Responsable:** Humano + Bibliotecario
**Bloquea:** Todo lo demás. No se mueve nada sin backup verificado.

### Por qué excluimos `target/` y `.venv/`

| Directorio | Tamaño | Razón de exclusión |
|-----------|-------:|-------------------|
| `BauthAgent/target/` | 9.9G | Artefactos de compilación Rust — se regeneran con `cargo build` |
| `BkernelAgent/target/` | ~600M | Ídem |
| `compositor-agent/.venv/` | ~200M | Virtual env Python — se regenera con `pip install` |
| `bibliotecario-agent/.venv/` | ~100M | Ídem |

Sin excluirlos: ~14G de backup. Excluyéndolos: ~3.5G. Misma seguridad.

### Comando de backup

```bash
FECHA=$(date +%Y%m%d_%H%M%S)
DEST="/opt/backups/skull-backup-${FECHA}"
mkdir -p "$DEST"

rsync -av --progress \
  --exclude='target/' \
  --exclude='.venv/' \
  --exclude='__pycache__/' \
  --exclude='*.pyc' \
  --exclude='node_modules/' \
  /opt/skull/ "$DEST/"

echo "Backup en: $DEST"
du -sh "$DEST"
```

### Verificación del backup

```bash
# Verificar que los archivos críticos llegaron
ls "$DEST/orquestador/proyectos/fabrica/scripts/tmux-fabrica.sh"
ls "$DEST/orquestador/proyectos/desarrollo/sbos/BauthAgent/src/"
ls "$DEST/orquestador/proyectos/fabrica/compositor-agent/orquesta/coordinador/servidor.py"
echo "✅ Archivos críticos presentes"
```

### Recuperación ante pérdida

```bash
# Si algo se rompe durante la reorganización:
rsync -av "$DEST/<ruta-perdida>" "/opt/skull/<ruta-perdida>"
```

---

## FASE 1 — DECISIONES PREVIAS (sin tocar código)
**Responsable:** Humano
**Bloquea:** Fases 4, 5 y 6. No se actualiza ningún CLAUDE.md ni el script tmux sin estas decisiones.
**No requiere computadora.** Son preguntas de diseño.

### Pregunta 1 — ¿`bos-t` (Testeador) y `bos-r` (Revisor) son roles definitivos?

**Contexto:** Aparecieron en `tmux-fabrica.sh` sin documentación. Son los slots 0 y 1 del grid visible.
- **Si SÍ:** Crear CLAUDE.md para cada uno, asignarles directorio propio, definir responsabilidades formales.
- **Si NO:** Reemplazarlos por los agentes del CLAUDE.md original (`sbos-coord`, `operador`).

Rewemplazar por los agentes del claude original fueron agentes improvisados

### Pregunta 2 — ¿`biblio` mantiene la coordinación del grafo de tareas?

**Contexto:** El `coordinador` desapareció del grid. Sus responsabilidades se fusionaron en el prompt de `biblio`. Pero el CLAUDE.md del Bibliotecario dice explícitamente que NO coordina — solo custodia documentación.
- **Si `biblio` coordina:** Actualizar el CLAUDE.md del Bibliotecario para reflejarlo.
- **Si se separan:** Agregar un agente `coordinador` de vuelta al grid (como estaba en `tmuxant.sh`).

Tambien se lo retiro por qu no funcionaba la fabrica solo eres un estrobo pero ahora supongo que funcionara de forma adecuada

### Pregunta 3 — ¿Los 6 daemons ocultos nuevos tienen trabajo real ahora?

**Contexto:** `bpay`, `btax`, `brate`, `bcms` están en el grid pero sin CLAUDE.md, sin directorio verificado, con prompts de 2 líneas.
- **Si tienen trabajo:** Crear sus directorios, CLAUDE.md y documentación básica.
- **Si no tienen trabajo aún:** Sacarlos del grid hasta que haya algo concreto que hacer.

No tienen trabajo real ahroa pert tmux tiene el mecanismo para poder very esconder los panes a necesidad

### Pregunta 4 — ¿`tmux2.sh` se archiva o se fusiona?

**Contexto:** Existe `tmux2.sh` (927 líneas) con el mismo grid. No está claro su rol.
- Archivar en `scripts/_archivo/tmux2.sh` si es un experimento.
- Fusionar si tiene funcionalidad que falta en `tmux-fabrica.sh`.

los otros scripts no sirven son errors solo es oficial el `tmux-fabrica.sh`.

---

## FASE 2 — DDL DE SKDATA (requiere aprobación explícita)
**Responsable:** Humano aprueba DDL → Bibliotecario aplica
**Bloquea:** Fase 7 (hooks SessionStart/Stop)

### Schemas a crear (todos nuevos — no tocan `trazas.*`)

```sql
-- NUEVO: memoria de agentes entre sesiones
CREATE SCHEMA IF NOT EXISTS memoria;

-- NUEVO: registro permanente de agentes de la fábrica
CREATE SCHEMA IF NOT EXISTS fabrica;
```

El DDL completo está en `SKDATA-MEMORIA-AGENTES.md`. Requiere aprobación explícita antes de ejecutar.

### Correcciones técnicas en schemas existentes

```sql
-- UUIDv7 en lugar de uuid_generate_v4() en toda PK
-- TIMESTAMPTZ en lugar de TIMESTAMP WITHOUT TIME ZONE
-- Índices faltantes en trazas.tarea_coordinada
```

---

## FASE 3 — REORGANIZACIÓN DE DIRECTORIOS (manual, proyecto por proyecto)
**Responsable:** Humano
**Herramienta:** Terminal + explorador de archivos
**Principio:** Nunca borrar — mover a `_archivo/` primero, borrar después de verificar.

### Orden sugerido (de menor a mayor riesgo)

```
1. fabrica/              ← 102M, sin compilados, seguro empezar aquí
2. InfraAgent/           ← ya reorganizado parcialmente
3. BosAgent/             ← 173M sin target/, código activo
4. BkernelAgent/         ← 628M con target/, mover con cuidado
5. BauthAgent/           ← 4.2M de src/ (target/ ya excluido del trabajo)
```

### Estructura objetivo (ver ESTRUCTURA-DIRECTORIOS.md PROPUESTA FINAL)

Puntos clave de la nueva estructura:
- DDL central en `SBOS/DDLs/` — fuera de cada daemon
- `SBOS/config/` para parámetros VPS, rutas canónicas, versiones del stack
- Cada daemon con `context/docs/`, `context/revisiones/`, `context/_archivo/`
- `fabrica/context-fabrica/` como único lugar de doctrina de la fábrica

### Qué limpiar durante la reorganización

| Carpeta/archivo | Acción |
|-----------------|--------|
| `BosAgent copy/` | Revisar → mover contenido único a `BosAgent/` → eliminar copia |
| `plandeaccion copy/` | Ídem |
| `context/ia_backup/` | Comparar con `context/ia/` → conservar solo diferencias |
| `Procesar/` (raíz sbos) | Verificar si difiere de `context/sbos/Procesar/` → decidir cuál es canónico |
| `sbos/out/` | Verificar si es output generado → si sí, se puede limpiar |

---

## FASE 4 — CLAUDE.md DE AGENTES (actualizar identidades)
**Responsable:** Bibliotecario
**Requiere:** Decisiones de Fase 1 aprobadas

### Regla de los CLAUDE.md corregidos

Cada CLAUDE.md de agente debe tener máximo 30 líneas:
- 3 líneas: quién soy, qué hago, dónde está mi código
- 5 líneas: cómo leer mi estado en SKDATA al iniciar
- 5 líneas: reglas absolutas de mi rol
- Sin historia, sin doctrina extensa, sin contexto que ya está en SKDATA

### Agentes a actualizar (en orden de prioridad)

| Agente | CLAUDE.md actual | Problema |
|--------|-----------------|---------|
| `biblio` (InfraAgent) | 216 líneas | Rol mezclado con coordinador — requiere decisión Fase 1 |
| `bos-t` | No existe | Crear si se confirma como rol definitivo |
| `bos-r` | No existe | Crear si se confirma como rol definitivo |
| `bauth` (BauthAgent) | Extenso | Reducir a punteros + SKDATA hook |
| `bos` (BosAgent) | Extenso | Reducir a punteros + SKDATA hook |
| `bkernel` | Extenso | Reducir a punteros + SKDATA hook |

---

## FASE 5 — CORRECCIONES DE CÓDIGO PYTHON
**Responsable:** Bibliotecario
**Requiere:** Backup (Fase 0) completado

### Bug 1 — `get_graph` roto (1 línea, no requiere aprobación)

```python
# ARCHIVO: compositor-agent/orquesta/coordinador/rpc_handlers.py
# LÍNEA: función get_graph

# ANTES (roto con metadata NULL):
duracion_estimada=t.get('metadata', {}).get('duracion_minutos', 10),

# DESPUÉS (correcto):
duracion_estimada=(t.get('metadata') or {}).get('duracion_minutos', 10),
```

### Bug 2 — Tareas duplicadas en `declare_task` (lógica, no requiere aprobación)

Agregar verificación de existencia antes del INSERT en `db_coordinacion.py`.

### Bug 3 — Degradación silenciosa (diseño — requiere decisión de estilo)

Cambiar el patrón `if not verificar_conexion(): return` por logging explícito que diferencie:
- "BD no disponible" → log ERROR + continúa
- "Schema no existe" → log CRITICAL + alerta

### Bug 4 — Generadores stubs (trabajo nuevo, no corrección)

`gen_db.py`, `gen_migration.py`, `gen_tests.py` son esqueletos. Su implementación real es trabajo de desarrollo, no de corrección de bugs.

---

## FASE 6 — ACTUALIZACIÓN DEL SCRIPT TMUX
**Responsable:** Bibliotecario
**Requiere:** Decisiones de Fase 1 aprobadas

### Cambios pendientes de decisión

- Ajustar prompts de identidad de `biblio` según decisión Fase 1 pregunta 2
- Agregar/quitar agentes según decisiones Fase 1 preguntas 1 y 3
- Unificar uso de `agente_enviar` en Sección 9 (también para panes visibles)
- Archivar o fusionar `tmux2.sh` según decisión Fase 1 pregunta 4

### Cambios que NO requieren decisión (aplicar en cualquier momento)

```bash
# Sección 9 — unificar con agente_enviar para todos los panes
# Reemplazar:
tmux send-keys -t "$(get_pid_by_agente bos-t)" "..." C-m
# Por:
agente_enviar "$(get_pid_by_agente bos-t)" "..."
```

---

## FASE 7 — HOOKS SessionStart/Stop
**Responsable:** Bibliotecario
**Requiere:** Fases 2, 4 y 5 completadas

Una vez que SKDATA tiene los schemas nuevos, el código no tiene degradación silenciosa, y los CLAUDE.md son punteros, activar los hooks:

```json
// fabrica/.claude/settings.json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "psql 'postgresql://root@localhost:5402/SKDATA' -t -A -c \"SELECT donde_quede || chr(10) || 'Falta: ' || que_falta FROM memoria.bitacora_agente WHERE agente_id = '$(hostname)-$(basename $PWD)'\" 2>/dev/null || echo 'Sin estado previo.'"
      }]
    }]
  }
}
```

---

## Secuencia de ejecución — resumen visual

```
AHORA MISMO
    │
    ▼
[FASE 0] BACKUP ──────────────────────────────────────────── BLOQUEANTE
    │  rsync -av --exclude=target/ --exclude=.venv/ /opt/skull/ /opt/backups/skull-backup-FECHA/
    │  Verificar archivos críticos
    │
    ▼
[FASE 1] DECISIONES HUMANAS ──────────────────────────────── SIN COMPUTADORA
    │  4 preguntas de diseño — respuestas definen las fases siguientes
    │
    ▼
[FASES 2, 3, 4] EN PARALELO ──────────────────────────────── CON CUIDADO
    │
    ├── [FASE 2] DDL SKDATA ← requiere aprobación DDL del humano
    │       Nuevos schemas: memoria + fabrica
    │
    ├── [FASE 3] REORGANIZACIÓN CARPETAS ← manual, proyecto por proyecto
    │       Orden: fabrica → InfraAgent → BosAgent → BkernelAgent → BauthAgent
    │
    └── [FASE 4] CLAUDE.md AGENTES ← después de Fase 1
            Reducir a 30 líneas máximo
    │
    ▼
[FASE 5] CORRECCIONES PYTHON ─────────────────────────────── DESPUÉS DE BACKUP
    │  BUG-001 (1 línea) + BUG-002 (declare_task) + degradación silenciosa
    │
    ▼
[FASE 6] SCRIPT TMUX ─────────────────────────────────────── DESPUÉS DE FASE 1
    │  Actualizar según decisiones + unificar agente_enviar
    │
    ▼
[FASE 7] HOOKS SessionStart/Stop ─────────────────────────── AL FINAL
    │  Solo cuando Fases 2 + 4 + 5 estén completas
    │
    ▼
SESIÓN DE PRUEBA FRESCA
    Verificar que un agente arranca y lee su estado en < 30 segundos
```

---

## Registro de estado

| Fase | Estado | Fecha | Notas |
|------|--------|-------|-------|
| 0 — Backup | PENDIENTE | | |
| 1 — Decisiones | PENDIENTE | | 4 preguntas abiertas |
| 2 — DDL SKDATA | ✅ COMPLETADO | 2026-07-02 | 13 tablas nuevas, 20 índices, 12 agentes + 8 términos. pgvector pendiente sysadmin. |
| 3 — Reorganización carpetas | ✅ COMPLETADO | 2026-07-02 | BosAgent copy, bnotify, cache, out, informes sueltos, ia_backup → _archivo/. Procesar/ raíz fusionada al canónico. Scripts tmux2/tmuxant/swap-click archivados. |
| 4 — CLAUDE.md agentes | PENDIENTE | | Requiere Fase 1 |
| 5 — Correcciones Python | PENDIENTE | | Bug-001 listo para aplicar |
| 6 — Script tmux | PENDIENTE | | Requiere Fase 1 |
| 7 — Hooks SessionStart/Stop | PENDIENTE | | Requiere Fases 2+4+5 |
