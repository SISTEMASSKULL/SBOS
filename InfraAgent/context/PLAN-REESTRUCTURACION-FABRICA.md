# PLAN DE REESTRUCTURACIÓN — Fábrica ORQUESTA
**Fecha de creación:** 2026-07-01
**Autor:** sbos-coordinador + humano
**Estado:** BORRADOR — pendiente de revisión y aprobación

---

## 1. Diagnóstico — Por qué el estado actual es insostenible

### 1.1 El problema central: media sesión perdida en contexto

Cuando un agente arranca hoy, debe leer:
- `CLAUDE.md` raíz SBOS (312+ líneas de doctrina general)
- `CLAUDE.md` del agente específico (50-216 líneas)
- `PROYECTO-ESTADO.md` (397+ líneas)
- `REGISTRO-ESTADO.md` del daemon (1116 líneas en bauth, llegó a 2254)
- Docs de doctrina ORQUESTA relevantes (50+ documentos)
- Documentación de su daemon específico

**Resultado:** el agente invierte 40-60% de su ventana de contexto en reconstruir
dónde estaba antes de escribir una sola línea de código. El trabajo útil se contrae.

### 1.2 Problemas de estructura detectados

| Problema | Evidencia |
|---|---|
| `Procesar/` duplicado | Existe en `/sbos/Procesar/` Y en `/sbos/context/sbos/Procesar/` — árboles distintos |
| `REGISTRO-ESTADO.md` en 5 lugares | bauth aparece en 4 rutas distintas — cuál es el vigente es ambiguo |
| Docs de cada daemon en 4+ ubicaciones | bauth: `BauthAgent/`, `BauthAgent/src/`, `context/sbos/.../bauth/`, `Procesar/.../bauth/` |
| `BosAgent copy/` y `plandeaccion copy/` | Directorios copiados literalmente, nunca limpiados |
| 15 CLAUDE.md distintos | Incluyendo `BosAgent/CLAUDE.md` y `BosAgent/src/CLAUDE.md` para el mismo proyecto |
| 549 archivos `.md` fuera de lugares canónicos | Sin forma de saber cuáles están vigentes |
| `context/` y `context-fabrica/` en fabrica | Dos carpetas de contexto para la misma fábrica |

### 1.3 Infraestructura existente no aprovechada

El proyecto ya tiene todo lo necesario para resolver el problema — solo falta usarlo:

| Recurso existente | Dónde | Usado para |
|---|---|---|
| SKDATA (PostgreSQL :5402) | `localhost:5402` | Coordinación de tareas — NO para memoria de agente |
| Esquema `perfiles` | SKDATA | Vacío o subutilizado |
| Esquema `conocimiento` | SKDATA | No utilizado |
| 17 agentes en `.claude/agents/` | `fabrica/.claude/agents/` | Definidos pero sin hooks de estado |
| 5 skills en `.claude/skills/` | `fabrica/.claude/skills/` | Protocolos sin carga automática de contexto |
| `.claude/settings.local.json` | `fabrica/.claude/` | Sin hooks SessionStart/Stop configurados |

---

## 2. Objetivos del plan

1. **Un agente arranca en menos de 30 segundos** sabiendo exactamente dónde quedó,
   sin leer más de 20 líneas de contexto histórico.
2. **Un solo lugar por daemon** para toda su documentación — sin ambigüedad.
3. **Memoria persistente por agente** entre sesiones, almacenada en SKDATA.
4. **Introspección del esquema real** disponible bajo demanda — sin leer MANUAL_DB_DDL.md.
5. **CLAUDE.md cortos** — punteros, no enciclopedias.

---

## 3. Fases de implementación

### FASE A — Memoria persistente en SKDATA
**Prioridad: CRÍTICA | Responsable: sbos-coordinador | Requiere código: SÍ**

Crear tabla `perfiles.bitacora_agente` en SKDATA. Una fila por agente que se
sobrescribe al cerrar sesión. Al abrir sesión, el agente lee solo esa fila.

**DDL:**
```sql
CREATE TABLE IF NOT EXISTS perfiles.bitacora_agente (
    agente_id        TEXT        PRIMARY KEY,
    actualizado_en   TIMESTAMPTZ DEFAULT now(),
    donde_quede      TEXT        NOT NULL,  -- archivo + función + tarea en curso
    que_falta        TEXT        NOT NULL,  -- próximo paso concreto
    archivos_activos TEXT[]      DEFAULT '{}',  -- solo los archivos que estoy tocando
    decisiones_hoy   TEXT        DEFAULT '',    -- decisiones tomadas en esta sesión
    bloqueos         TEXT        DEFAULT ''     -- qué me impide avanzar (vacío si ninguno)
);
```

**Hook SessionStart** en `fabrica/.claude/settings.json`:
```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "psql 'postgresql://root@localhost:5402/SKDATA' -t -A -c \"SELECT '=== ESTADO ANTERIOR ===' || chr(10) || 'Dónde quedé: ' || donde_quede || chr(10) || 'Qué falta: ' || que_falta || chr(10) || 'Archivos activos: ' || array_to_string(archivos_activos, ', ') FROM perfiles.bitacora_agente WHERE agente_id = current_setting('app.agente_id', true)\" 2>/dev/null || echo 'Sin estado previo registrado.'"
      }]
    }]
  }
}
```

**Protocolo de cierre para cada agente** — al finalizar sesión, ejecutar:
```bash
psql 'postgresql://root@localhost:5402/SKDATA' -c "
  INSERT INTO perfiles.bitacora_agente
    (agente_id, donde_quede, que_falta, archivos_activos, decisiones_hoy)
  VALUES
    ('<agente>', '<dónde quedé>', '<qué falta>', ARRAY['<archivo1>','<archivo2>'], '<decisiones>')
  ON CONFLICT (agente_id) DO UPDATE SET
    donde_quede      = EXCLUDED.donde_quede,
    que_falta        = EXCLUDED.que_falta,
    archivos_activos = EXCLUDED.archivos_activos,
    decisiones_hoy   = EXCLUDED.decisiones_hoy,
    actualizado_en   = now();"
```

**Verificación de Fase A completada:**
- [ ] Tabla creada y verificada en SKDATA
- [ ] Hook SessionStart configurado en `fabrica/.claude/settings.json`
- [ ] Al menos un agente (bauth-developer) ha escrito y leído su estado exitosamente
- [ ] El arranque de sesión toma menos de 30 segundos

---

### FASE B — postgres-mcp para introspección de esquema
**Prioridad: ALTA | Responsable: sbos-coordinador | Requiere instalación: SÍ**

Instalar `crystaldba/postgres-mcp` conectado al esquema real de bAuth.
Elimina la necesidad de leer `MANUAL_DB_DDL.md` (179 tablas) al inicio de sesión.

**Usuario de solo lectura (ya debe existir o crear):**
```sql
CREATE USER mcp_readonly WITH PASSWORD '...';
GRANT CONNECT ON DATABASE bauth TO mcp_readonly;
GRANT USAGE ON SCHEMA public TO mcp_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO mcp_readonly;
```

**Instalación:**
```bash
cd /opt/projects-ia/_sistema   # o la ruta que se decida
git clone https://github.com/crystaldba/postgres-mcp
cd postgres-mcp
# seguir README para instalación exacta
```

**Registro en MCP de Claude Code** — en `fabrica/.claude/settings.json`:
```json
{
  "mcpServers": {
    "bauth-schema": {
      "command": "postgres-mcp",
      "args": ["postgresql://mcp_readonly:<pass>@localhost:<puerto>/bauth"]
    }
  }
}
```

**Verificación de Fase B completada:**
- [ ] `mcp_readonly` creado con permisos verificados (solo SELECT)
- [ ] postgres-mcp instalado y arrancando sin errores
- [ ] Aparece en la lista de servidores MCP de Claude Code
- [ ] Un agente puede preguntar "¿qué columnas tiene idn_user?" sin leer MANUAL_DB_DDL.md

---

### FASE C — Índice de fragmentos de docs en SKDATA
**Prioridad: MEDIA | Responsable: sbos-coordinador | Requiere código: SÍ**

En lugar de guild (v0.1.0, 1 star), usar el esquema `conocimiento` que ya existe
en SKDATA para indexar fragmentos de documentación relevante con full-text search
nativo de PostgreSQL. Mismo resultado, infraestructura bajo control.

**DDL:**
```sql
CREATE TABLE IF NOT EXISTS conocimiento.fragmento_doc (
    id            BIGSERIAL   PRIMARY KEY,
    proyecto      TEXT        NOT NULL,  -- 'bauth', 'bkernel', 'bos', etc.
    categoria     TEXT        NOT NULL,  -- 'decision', 'regla', 'estado', 'diseño'
    titulo        TEXT        NOT NULL,
    contenido     TEXT        NOT NULL,
    fuente        TEXT        NOT NULL,  -- ruta del archivo origen
    vigente       BOOLEAN     DEFAULT true,
    creado_en     TIMESTAMPTZ DEFAULT now(),
    ts            TSVECTOR    GENERATED ALWAYS AS (to_tsvector('spanish', titulo || ' ' || contenido)) STORED
);

CREATE INDEX ON conocimiento.fragmento_doc USING GIN (ts);
```

**Uso por agente:**
```bash
# En lugar de leer REGISTRO-ESTADO.md completo, buscar:
psql SKDATA -c "SELECT titulo, contenido FROM conocimiento.fragmento_doc
  WHERE proyecto='bauth' AND ts @@ plainto_tsquery('spanish', 'cierre de sesión ctx_id')
  AND vigente = true LIMIT 5;"
```

**Verificación de Fase C completada:**
- [ ] Tabla creada en SKDATA
- [ ] Al menos 20 fragmentos de bauth indexados (decisiones clave + estado actual)
- [ ] Un agente localiza información en menos de 5 segundos sin leer el doc completo

---

### FASE D — CLAUDE.md reducidos a punteros
**Prioridad: MEDIA | Responsable: humano (reorganización manual) + sbos-coordinador**

Cada `CLAUDE.md` de agente pasa a tener máximo 30 líneas:
- 3 líneas: quién soy y qué hago
- 2 líneas: dónde está mi código
- 1 línea: leer bitácora de SKDATA al arrancar
- 5 líneas: reglas absolutas (no más)
- Sin historia, sin doctrina, sin contexto que ya está en SKDATA

La doctrina completa y los ADRs siguen en `context-fabrica/doctrina/` — disponibles
bajo demanda, no cargados automáticamente en cada sesión.

**Verificación de Fase D completada:**
- [ ] CLAUDE.md de bauth-developer: máximo 30 líneas
- [ ] CLAUDE.md de bkernel-developer: máximo 30 líneas
- [ ] CLAUDE.md de bos-developer: máximo 30 líneas
- [ ] CLAUDE.md de sbos-coordinador: máximo 30 líneas
- [ ] Ningún CLAUDE.md carga automáticamente REGISTRO-ESTADO.md completo

---

### FASE E — Reorganización de archivos (manual, proyecto por proyecto)
**Prioridad: BAJA-URGENTE | Responsable: humano | Sin código**

El humano reorganiza manualmente cada daemon siguiendo la estructura del plan
`PLAN-IMPLEMENTACION-AGENTES-IA.md`. El sbos-coordinador verifica después.

**Estructura objetivo por daemon:**
```
<DaemonAgent>/
├── src/                          ← código (no cambia)
├── context/
│   ├── general/
│   │   ├── ESTADO.md             ← 1 sola fuente de verdad (reemplaza REGISTRO-ESTADO.md)
│   │   ├── ADR/                  ← decisiones de arquitectura
│   │   └── _archivo/             ← bloques cerrados, solo consulta
│   └── agentes/
│       └── dev/BITACORA.md       ← state de sesión (complementa SKDATA)
└── CLAUDE.md                     ← máximo 30 líneas (Fase D)
```

**Eliminar antes de migrar:**
- [ ] `BosAgent copy/` — investigar qué contiene y si tiene trabajo único
- [ ] `plandeaccion copy/` — ídem
- [ ] `context/ia_backup/` — verificar si difiere de `context/ia/`
- [ ] `Procesar/` raíz vs `context/sbos/Procesar/` — decidir cuál es canónico y eliminar el otro

**Orden de migración sugerido:**
1. bauth (caso más crítico por REGISTRO-ESTADO.md de 1116 líneas)
2. bos
3. bkernel
4. Resto en orden de actividad

---

## 4. Lo que NO se implementa y por qué

| Herramienta | Decisión | Razón |
|---|---|---|
| **amux** | Descartado | El proyecto ya tiene tmux grid + OrquestaCoreSBOS :8095 + SKDATA. amux duplicaría sin agregar valor. |
| **guild** | Descartado como herramienta | v0.1.0, 1 star. La necesidad que resuelve se cubre con SKDATA + FTS nativo (Fase C). |

---

## 5. Registro de estado

| Fase | Estado | Fecha inicio | Fecha fin | Notas |
|---|---|---|---|---|
| A — Memoria SKDATA + hooks | PENDIENTE | | | |
| B — postgres-mcp | PENDIENTE | | | |
| C — Índice fragmentos conocimiento | PENDIENTE | | | |
| D — CLAUDE.md reducidos | PENDIENTE | | | |
| E — Reorganización manual | PENDIENTE | | | |

---

## 6. Criterio de éxito global

Un agente recién iniciado sobre bauth:
1. Lee su bitácora de SKDATA — **5 segundos**
2. Sabe exactamente en qué archivo y función estaba trabajando
3. Puede consultar el esquema real de BD sin leer MANUAL_DB_DDL.md
4. Tiene acceso a fragmentos de docs bajo demanda vía SKDATA FTS
5. Su CLAUDE.md no excede 30 líneas
6. El trabajo útil empieza en el **primer minuto** de sesión

---
*Documento vivo — actualizar registro de estado a medida que se completan fases*
