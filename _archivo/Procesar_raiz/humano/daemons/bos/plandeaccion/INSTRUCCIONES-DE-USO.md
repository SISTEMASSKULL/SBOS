# INSTRUCCIONES DE USO — Proyecto BOS-REPAIR
## Cómo usar todos los artefactos generados en esta sesión

**Proyecto:** BosAgent / SBOS · SKULL  
**Fecha:** 08 de Junio 2026  
**Evaluación de partida del daemon bos:** 3.5 / 10  
**Objetivo:** 10 / 10 mediante 85 átomos en 11 fases

---

## Los dos paquetes entregados

### Paquete 1 — `BOS-REPAIR-COMPLETO.tar.gz`
Estructura de carpetas lista para copiar directamente al servidor.
Mantiene la jerarquía exacta de dónde va cada archivo.

### Paquete 2 — `BOS-REPAIR-KNOWLEDGE-PLANO.tar.gz`
Todos los archivos sueltos en un solo nivel.
Diseñado para subir directamente al knowledge de un proyecto Claude.

---

## Paso 1 — Subir archivos al knowledge del proyecto Claude

Subir **todos** los archivos del paquete plano al knowledge del proyecto:

```
PROTOCOLO-SESION-AGENTE.md
SESION-LOG.md
GESTION-RIESGOS-OPERATIVOS.md
EVALUACION-AGENTE-IA-BOS-REPAIR.md
BOS-REPAIR-DASHBOARD.sh
BOS-REPAIR-VERIFICAR-CONTINUIDAD.sh
EJECUCION-F0.0-SNAPSHOT.md
EJECUCION-F1.5-INSTRUCCIONES-AGENTE.md
EJECUCION-F3.1-F3.5-INSTRUCCIONES-AGENTE.md
EJECUCION-F5.1-F5.3-INSTRUCCIONES-AGENTE.md
EJECUCION-F9.1-F9.3-INSTRUCCIONES-AGENTE.md
EJECUCION-F10.1-F10.3-INSTRUCCIONES-AGENTE.md
SKILL-BOS-REPAIR.md
SKILL-rutas-y-archivos.md
SKILL-dod-y-politicas.md
apertura-sesion.sh
cierre-sesion.sh
```

---

## Paso 2 — Instalar scripts operativos en el servidor VPS DEV

Los documentos del plan ya están en el repositorio. Solo se necesita
copiar los scripts al directorio `scripts/` del código fuente para que
`bash scripts/X.sh` funcione desde `$CODE_SRC`.

```bash
ssh skull@144.91.76.130

PLAN_DIR="/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/daemons/bos/plandeaccion/plandeaccion"
CODE_SRC="/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src"

mkdir -p "$CODE_SRC/scripts"

# Scripts operativos (fuente: scripts-operativos/ y skill/scripts/)
cp "$PLAN_DIR/../scripts-operativos/BOS-REPAIR-DASHBOARD.sh"              "$CODE_SRC/scripts/"
cp "$PLAN_DIR/../scripts-operativos/BOS-REPAIR-VERIFICAR-CONTINUIDAD.sh"  "$CODE_SRC/scripts/"
cp "$PLAN_DIR/../skill/scripts/apertura-sesion.sh"                         "$CODE_SRC/scripts/"
cp "$PLAN_DIR/../skill/scripts/cierre-sesion.sh"                           "$CODE_SRC/scripts/"
chmod +x "$CODE_SRC/scripts/"*.sh

echo "✅ Scripts operativos instalados"
```

---

## Paso 3 — Primera sesión del agente (orden obligatorio)

```
1. Explorar BosAgent/ raíz — leer TODOS los archivos encontrados
   ls -la /opt/skull/.../BosAgent/
   → Registrar inventario en SESION-LOG.md

2. Ejecutar F0.0 — Snapshot pre-reparación (OBLIGATORIO antes de tocar código)
   → plandeaccion/skill/references/EJECUCION-F0.0-SNAPSHOT.md

3. Verificar continuidad
   bash scripts/BOS-REPAIR-VERIFICAR-CONTINUIDAD.sh  ← debe retornar exit 0

4. Ver el dashboard
   bash scripts/BOS-REPAIR-DASHBOARD.sh

5. Ejecutar F0.1 (primer átomo real)
   → BOS-REPAIR-PLAN-MAESTRO-v3.md §FASE-0 §Átomo F0.1
```

---

## Paso 4 — Flujo de cada sesión posterior

```
APERTURA:   bash scripts/apertura-sesion.sh
EJECUCIÓN:  seguir EJECUCION-FX.Y o §FASE-X del Plan Maestro
CIERRE:     bash scripts/cierre-sesion.sh FX.Y completo|progreso|bloqueado
            + actualizar REGISTRO-ESTADO.md y SESION-LOG.md
```

---

## Tabla de referencia rápida

| Pregunta | Documento |
|---|---|
| ¿Qué átomo ejecutar ahora? | `plandeaccion/plandeaccion/REGISTRO-ESTADO.md` |
| ¿Cómo ejecutar un átomo? | `plandeaccion/plandeaccion/instrucciones-agente/EJECUCION-FX.Y-*.md` |
| ¿Plan completo de 85 átomos? | `plandeaccion/plandeaccion/BOS-REPAIR-PLAN-MAESTRO-v3.md` |
| ¿Qué hacer ANTES de tocar código? | `plandeaccion/skill/references/EJECUCION-F0.0-SNAPSHOT.md` |
| ¿Cómo abrir/cerrar sesión? | `plandeaccion/plandeaccion/PROTOCOLO-SESION-AGENTE.md` |
| ¿Qué átomos necesitan aprobación? | `plandeaccion/plandeaccion/GESTION-RIESGOS-OPERATIVOS.md` |
| ¿Dónde están los archivos? | `plandeaccion/skill/references/rutas-y-archivos.md` |
| ¿Cuál es el DoD universal? | `plandeaccion/skill/references/dod-y-politicas.md` |
| ¿Progreso en tiempo real? | `bash scripts/BOS-REPAIR-DASHBOARD.sh` (desde `$CODE_SRC`) |
| ¿Repo en estado consistente? | `bash scripts/BOS-REPAIR-VERIFICAR-CONTINUIDAD.sh` (desde `$CODE_SRC`) |
| ¿Qué pasó en la sesión anterior? | `plandeaccion/plandeaccion/SESION-LOG.md` |

---

*INSTRUCCIONES-DE-USO.md · BOS-REPAIR · SKULL · SBOS · 08 de Junio 2026*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
