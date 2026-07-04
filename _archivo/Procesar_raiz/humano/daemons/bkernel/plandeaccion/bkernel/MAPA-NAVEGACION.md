# MAPA DE NAVEGACIÓN — Plan de Desarrollo bKernel
## Guía de lectura y ejecución para el agente

**Ruta de este documento:**
`context/sbos/Procesar/humano/daemons/bkernel/plandeaccion/bkernel/MAPA-NAVEGACION.md`

**Ruta del código fuente del proyecto:**
`/opt/skull/orquestador/proyectos/desarrollo/sbos/BkernelAgent/src/`

**Fecha:** 2026-06-19 · SKULL · SBOS

---

## Regla fundamental antes de leer cualquier otro documento

```
ANTES DE EJECUTAR CUALQUIER ÁTOMO:
  1. Leer este MAPA-NAVEGACION.md completo (una sola vez)
  2. Leer BKERNEL-PLAN-MAESTRO-v1.md §PARTE II (políticas globales)
  3. Verificar que el Gate previo está ✅ en el REGISTRO-ESTADO.md
  4. Leer las instrucciones específicas del átomo (instrucciones-agente/)
  5. Ejecutar
  6. Completar la entrada en LOG-DE-SESIONES.md antes de marcar ✅ en REGISTRO-ESTADO.md
```

---

## Dónde está cada cosa

### Árbol de directorios

```
plandeaccion/bkernel/
│
├── MAPA-NAVEGACION.md                ← ESTE ARCHIVO — leer primero siempre
├── REGISTRO-ESTADO.md                ← estado actual de cada átomo (actualizar en cada cierre)
├── BKERNEL-PLAN-MAESTRO-v1.md        ← EL PLAN — documento de referencia principal
├── PROTOCOLO-SESION-AGENTE.md       ← cómo el agente abre, ejecuta y cierra sesiones
├── LOG-DE-SESIONES.md                ← bitácora cronológica de sesiones
├── INSTRUCCIONES-DE-USO.md           ← instrucciones prácticas para cada gate
├── SKILL-AGENTE-PROGRAMADOR.md       ← definición de la skill para Claude Code
├── GESTION-RIESGOS-OPERATIVOS.md     ← matriz de riesgos y contingencias
├── action_catalog.yml                ← catálogo de acciones biaos para bkernel
│
├── adrs/                             ← ADRs específicos de bkernel
├── docs/runbooks/                    ← procedimientos operacionales en producción
├── instrucciones-agente/             ← LEER ANTES de ejecutar cada átomo
├── informes-cierre/                  ← COMPLETAR DESPUÉS de ejecutar cada átomo
├── json-rpc/                         ← especificación JSON-RPC bkernel.*
├── anexos/                           ← material de investigación preservado
└── sbos-specs/                       ← copias locales de specs SBOS relevantes
```

---

## Navegación por intención

| Quiero… | Ruta |
|---|---|
| Empezar a desarrollar YA | 1. MAPA-NAVEGACION → 2. REGISTRO-ESTADO (primer 🔴) → 3. BKERNEL-PLAN-MAESTRO (leer átomo) → 4. Ejecutar |
| Entender qué es bkernel | `context/.../daemons/bkernel/SBOS_bkernel_VISION.md` + `README.md` |
| Entender la arquitectura | `context/.../daemons/bkernel/SBOS_bkernel_ARQUITECTURA.md` |
| Ver el modelo de datos | `context/.../daemons/bkernel/SBOS_bkernel_DATOS.md` + `BibliotecaSBOS/src/001_bkernel_db.sql` |
| Entender el contrato con biedata | ECO-020 (NUNCA aquí — SSOT) |
| Ver los puertos asignados | `BOS_V8/BOS_V8_SBOS-050-PORT-CATALOG.md` |
| Crear una ficha de ejemplo | BKERNEL-PLAN-MAESTRO G2.E5.T1 + bK-140 |
| Saber qué NO hace bkernel | SBOS_bkernel_VISION.md §Fronteras (F-01 a F-11) |
| Depurar un error de CDC | `docs/runbooks/` + `json-rpc/` |
| Retomar una sesión interrumpida | REGISTRO-ESTADO.md → primer 🟡 o ⚠️ |

---

## Ciclo de vida de un átomo

```
1. SELECCIÓN
   └→ REGISTRO-ESTADO.md: primer 🔴 del gate activo
   
2. PREPARACIÓN
   └→ BKERNEL-PLAN-MAESTRO: leer sección del átomo
   └→ instrucciones-agente/: si existe, leer instrucciones específicas
   └→ Verificar dependencias ✅
   
3. EJECUCIÓN
   └→ Implementar el entregable
   └→ Verificar el criterio MEDIBLE
   └→ git commit con mensaje descriptivo
   
4. CIERRE
   └→ REGISTRO-ESTADO.md: actualizar fila (✅ + commit SHA + notas)
   └→ LOG-DE-SESIONES.md: entrada de sesión
   └→ Si aplica: actualizar documento canónico (bK-XXX)
```

---

## Documentos canónicos (fuente de verdad)

| Documento | Contenido | Ruta |
|-----------|-----------|------|
| SBOS_bkernel_VISION.md | Propósito, fronteras F-01..F-11 | `context/.../daemons/bkernel/` |
| SBOS_bkernel_ARQUITECTURA.md | Stack Rust, módulos, loop principal, backpressure | `context/.../daemons/bkernel/` |
| SBOS_bkernel_DOMINIO.md | BkernelEvent, source.yml, entity_crossref | `context/.../daemons/bkernel/` |
| SBOS_bkernel_FUNCIONALIDADES.md | CDC, fichas, fanout, loop prevention, DLQ, SLOs | `context/.../daemons/bkernel/` |
| SBOS_bkernel_DATOS.md | Esquema bkernel_db (8 tablas) | `context/.../daemons/bkernel/` |
| SBOS_bkernel_INTEGRACIONES.md | Redis Streams, consumidores (bSearch, biedata) | `context/.../daemons/bkernel/` |
| SBOS_bkernel_SEGURIDAD.md | Cero superficie, Vault, anti-loop | `context/.../daemons/bkernel/` |
| SBOS_bkernel_OPERACION.md | Instalación, healthcheck, métricas | `context/.../daemons/bkernel/` |
| SBOS_bkernel_GLOSARIO.md | Términos: CDC, WAL, LSN, pgoutput, BkernelEvent | `context/.../daemons/bkernel/` |
| 001_bkernel_db.sql | DDL operativo completo (8 tablas) | `context/sbos/BibliotecaSBOS/src/` |
| BOS_V8_SBOS-023-DAEMON-BKERNEL.md | Documento V8 canónico | `context/sbos/Procesar/humano/BOS_V8/` |
| BOS_V8_SBOS-049-CONTEXT-PLANE.md | Context Plane spec | `context/sbos/Procesar/humano/BOS_V8/` |
| BOS_V8_SBOS-050-PORT-CATALOG.md | Política de puertos | `context/sbos/Procesar/humano/BOS_V8/` |

---

## Jerarquía documental (en caso de conflicto)

1. **`BKERNEL-PLAN-MAESTRO-v1.md`** — manda sobre el plan de desarrollo
2. **`REGISTRO-ESTADO.md`** — manda sobre el estado de los átomos
3. **Documentos canónicos V8** (`SBOS_bkernel_*.md`) — mandan sobre arquitectura/dominio/funcionalidades
4. **ECO-020** — manda sobre el contrato bKernel↔biedata
5. **ADRs** — mandan sobre decisiones técnicas específicas
6. **Este MAPA-NAVEGACION.md** — manda sobre la estructura del plan de acción

---

## Reglas para el agente

1. **Nunca ejecutar un átomo sin verificar que sus dependencias están ✅**
2. **Nunca marcar ✅ sin commit + evidencia en REGISTRO-ESTADO**
3. **Nunca modificar código sin leer el documento canónico asociado (SSOT)**
4. **Siempre actualizar REGISTRO-ESTADO.md en cada cierre de sesión**
5. **Siempre registrar entrada en LOG-DE-SESIONES.md**
6. **Si un átomo requiere decisión arquitectónica → nuevo ADR en `adrs/`**

---
*MAPA-NAVEGACION v1.0 · 2026-06-19 · SKULL*
