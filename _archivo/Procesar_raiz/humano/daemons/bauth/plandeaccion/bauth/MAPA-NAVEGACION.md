# MAPA DE NAVEGACIÓN — Plan de Desarrollo bAuth
## Guía de lectura y ejecución para el agente

**Ruta:** `context/sbos/Procesar/humano/daemons/bauth/plandeaccion/bauth/MAPA-NAVEGACION.md`
**Código fuente:** `/opt/skull/orquestador/proyectos/desarrollo/sbos/BauthAgent/src/`
**Fecha:** 2026-06-19 · SKULL · SBOS

---

> ⚠️ **CORRECCIÓN BITMASK — JUNIO 2026:** Las referencias al modelo BitMask (SAM-128, "2 capas", "BitmaskBundle", "7×64 bits") en este documento corresponden al diseño anterior. El modelo actual es el **BitMask Dual**: BitMask Átomo 64-bit (label encoding) + Rol BitMask N-bit (one-hot encoding). Para desarrollo, usar: `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md`, `SBOS-MANUAL-BAUTH-COMPONENT-ROLES.md` v1.7, `SBOS-MANUAL-BAUTH-D12-BLOCKCHAIN-WALLET-CONTROL.md` v2.1.

---

## Regla fundamental

```
ANTES DE EJECUTAR CUALQUIER ÁTOMO:
  1. Leer este MAPA-NAVEGACION.md completo
  2. Leer BAUTH-PLAN-MAESTRO-v1.md §PARTE II (políticas globales)
  3. Verificar que el Gate previo está ✅ en REGISTRO-ESTADO.md
  4. Leer las instrucciones específicas del átomo (instrucciones-agente/)
  5. Ejecutar
  6. Completar entrada en LOG-DE-SESIONES.md antes de marcar ✅
```

---

## Árbol de directorios

```
plandeaccion/bauth/
├── MAPA-NAVEGACION.md              ← ESTE ARCHIVO — leer primero
├── REGISTRO-ESTADO.md              ← estado actual de cada átomo (38 átomos, 5 gates)
├── BAUTH-PLAN-MAESTRO-v1.md        ← EL PLAN — 5 partes, 38 átomos, 8 criterios
├── PROTOCOLO-SESION-AGENTE.md     ← apertura/ejecución/cierre
├── LOG-DE-SESIONES.md              ← bitácora cronológica
├── INSTRUCCIONES-DE-USO.md         ← comandos por gate
├── SKILL-AGENTE-PROGRAMADOR.md     ← skill bauth-dev
├── GESTION-RIESGOS-OPERATIVOS.md   ← matriz de riesgos
├── action_catalog.yml              ← catálogo de acciones biaos
│
├── adrs/                           ← ADRs específicos de bauth
├── docs/runbooks/                  ← procedimientos operacionales
├── instrucciones-agente/           ← LEER ANTES de cada átomo
├── informes-cierre/                ← COMPLETAR DESPUÉS de cada átomo
├── json-rpc/                       ← especificación JSON-RPC bauth.*
├── anexos/                         ← material de investigación
└── sbos-specs/                     ← copias locales de specs SBOS
```

---

## Navegación por intención

| Quiero… | Ruta |
|---|---|
| Empezar a desarrollar | 1. MAPA-NAVEGACION → 2. REGISTRO-ESTADO (primer 🔴) → 3. PLAN-MAESTRO → 4. Ejecutar |
| Entender qué es bAuth | `SBOS-BAUTH-CONCEPTUALIZACION-v5_0.md` (1670 líneas) |
| Entender el SAM-128 | `SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md` |
| Ver los contratos | `SBOS-ROLTEMPLATE-v5_0.md` + `SBOS-USERTEMPLATE-v5_0.md` |
| Entender la arquitectura | `SBOS-BAUTH-DECISIONES-ARQUITECTURA-v1_0.md` (1257 líneas) |
| Ver los puertos asignados | `BOS_V8/BOS_V8_SBOS-050-PORT-CATALOG.md` |
| Retomar sesión interrumpida | REGISTRO-ESTADO.md → primer 🟡 o ⚠️ |

---

## Jerarquía documental (en caso de conflicto)

1. **BAUTH-PLAN-MAESTRO-v1.md** — manda sobre el plan de desarrollo
2. **REGISTRO-ESTADO.md** — manda sobre el estado de los átomos
3. **SBOS-BAUTH-CONCEPTUALIZACION-v5_0.md** — manda sobre la definición del daemon
4. **SBOS-BAUTH-DECISIONES-ARQUITECTURA-v1_0.md** — manda sobre decisiones técnicas
5. **ADRs** — mandan sobre decisiones específicas
6. **Este MAPA-NAVEGACION.md** — manda sobre la estructura del plan

---
*MAPA-NAVEGACION v1.0 · 2026-06-19 · SKULL*
