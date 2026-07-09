# Rutas y Archivos del Sistema BOS-REPAIR

## Variables de ruta base (usar en todos los comandos)

```bash
PLAN_DIR="/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/daemons/bos/plandeaccion/plandeaccion"
SBOS_DOCS="/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/BOS_V8"
SBOS_SPECS="$PLAN_DIR/sbos-specs"
CODE_ROOT="/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent"
CODE_SRC="$CODE_ROOT/src"
```

## RUTA 1 — plandeaccion/ — Mapa completo de documentos

```
$PLAN_DIR/
├── MAPA-NAVEGACION.md                    ← leer primero en cada primera sesión
├── REGISTRO-ESTADO.md                    ← estado de 85 átomos — actualizar en cada cierre
├── SESION-LOG.md                         ← log cronológico de sesiones
├── PROTOCOLO-SESION-AGENTE.md            ← protocolo completo apertura/ejecución/cierre
├── GESTION-RIESGOS-OPERATIVOS.md         ← gates de aprobación y clasificación de riesgo
├── BOS-REPAIR-PLAN-MAESTRO-v3.md         ← EL PLAN — 85 átomos, 11 fases, políticas SFP
├── BOS-REPAIR-EVALUACION-PLAN-MAESTRO.md ← diagnóstico 3.5/10 → 10/10
├── EVALUACION-AGENTE-IA-BOS-REPAIR.md   ← evaluación capacidades del agente IA
├── action_catalog.yml                    ← 26 acciones biaos (F10.0 ✅)
│
├── bos-repair/                           ← 14 documentos de investigación + ADRs
│   ├── BOS-REPAIR-INDEX.md              ← índice de todos los documentos BOS-REPAIR
│   ├── BOS-REPAIR-00-AUDITORIA-TECNICA.md
│   ├── BOS-REPAIR-01 .. BOS-REPAIR-13  ← ADRs, specs, plan, sagas, flujo E2E
│   └── (ver BOS-REPAIR-INDEX.md para detalle completo)
│
├── sbos-specs/                           ← copias locales de specs SBOS para el plan
│   ├── SBOS-049-CONTEXT-PLANE.md        ← Context Plane (copia de BOS_V8)
│   ├── SBOS-052-VDI-SPEC.md             ← VDI Layer spec
│   ├── SBOS-MANUAL-ACOPLAMIENTO.md      ← contratos entre daemons
│   ├── biaos-arquitectura.md
│   └── biaos-proyecto-ia-robusta.md
│
├── instrucciones-agente/                 ← LEER ANTES DE EJECUTAR CADA ÁTOMO
│   ├── EJECUCION-F0.5-INSTRUCCIONES-AGENTE.md   ← CI/CD pipeline
│   ├── EJECUCION-F0.6-INSTRUCCIONES-AGENTE.md   ← Entornos + runner staging
│   ├── EJECUCION-F1.5-INSTRUCCIONES-AGENTE.md   ← Mutex observer/reconciler ⛔ CRÍTICO
│   ├── EJECUCION-F3.1-F3.5-INSTRUCCIONES-AGENTE.md ← Partir install_ui.go
│   ├── EJECUCION-F5.1-F5.3-INSTRUCCIONES-AGENTE.md ← Context Plane
│   ├── EJECUCION-F7.8-INSTRUCCIONES-AGENTE.md   ← Runbooks operacionales
│   ├── EJECUCION-F9.1-F9.3-INSTRUCCIONES-AGENTE.md ← Operator Soberano
│   └── EJECUCION-F10.1-F10.3-INSTRUCCIONES-AGENTE.md ← Gateway LLM + biaos
│
├── informes-cierre/                      ← completar después de cada átomo ✅
│   ├── INFORME-CIERRE-F0.5-CI-CD.md
│   ├── INFORME-CIERRE-F0.6-ENTORNOS.md
│   ├── INFORME-CIERRE-F7.8-RUNBOOKS.md
│   └── INFORME-CIERRE-F10.0-ACTION-CATALOG.md
│
├── docs/
│   └── runbooks/
│       ├── INDEX.md
│       ├── INCIDENTES-LOG.md
│       ├── RB-01-FICHA-DEGRADADA.md
│       ├── RB-02-DATA-RACE-DETECTADA.md
│       └── RB-03-CONTEXT-PLANE-DOWN.md
│
├── json-rpc/                             ← manual completo del protocolo
│   ├── JSON-RPC-RESUMEN-EJECUTIVO.md    ← leer este primero
│   ├── JSON-RPC-01-fundamentos.md
│   ├── JSON-RPC-02-autenticacion.md
│   ├── JSON-RPC-03-crud-contexto.md
│   ├── JSON-RPC-04-cadena-eventos.md
│   ├── JSON-RPC-05-arquitectura-servidor.md
│   ├── JSON-RPC-06-errores-produccion.md
│   ├── JSON-RPC-07-arquitectura-hibrida-integraciones.md
│   ├── JSON-RPC-08-ecosistema-y-estrategia-de-adopcion.md
│   └── JSON-RPC-09-orquestacion-multi-motor.md
│
└── anexos/
    ├── ANEXOS-INDEX.md                  ← índice de 27 anexos
    ├── ANX-022-gap1-pipeline-cicd/      ← ci.yml, validate.sh
    ├── ANX-023-gap2-entornos/           ← ENVIRONMENTS.md, staging-runner-setup.sh
    └── ANX-026-biaos-scripts/           ← scripts biaos (pendiente rediseño)
```

## RUTA 2 — BOS_V8/ — Documentación técnica de referencia

```
$SBOS_DOCS/
Contiene la documentación técnica completa del proyecto SBOS.
Archivos con prefijo BOS_V8_SBOS-NNN-*.md — NO tienen subdirectorios.
Consultar cuando se necesite contexto técnico profundo sobre:
- Arquitectura del sistema SBOS completo (BOS_V8_SBOS-002-ARCH.md)
- Especificaciones de bkernel, bAuth, Kong, Keycloak, etc.
- Context Plane → BOS_V8_SBOS-049-CONTEXT-PLANE.md  (o copia en $SBOS_SPECS/)
- VDI Layer    → BOS_V8_SBOS-025-VDI.md

NO se modifica. Es referencia de solo lectura.

NOTA: Los siguientes archivos NO están en BOS_V8 — usar las rutas correctas:
- Contratos entre daemons  → $SBOS_SPECS/SBOS-MANUAL-ACOPLAMIENTO.md
- Context Plane (copia)    → $SBOS_SPECS/SBOS-049-CONTEXT-PLANE.md
- VDI Spec (copia)         → $SBOS_SPECS/SBOS-052-VDI-SPEC.md
- DAG de fichas            → $CODE_SRC/core/00_ARCHITECTURE_SBOS.yml
- Script instalación       → $CODE_SRC/core/00_MASTER_INSTALL_SBOS.sh
- YAML engine              → $CODE_SRC/core/00_YAML_ENGINE_SBOS.sh
```

## RUTA 3 — BosAgent/ — Código fuente

```
$CODE_ROOT/                              ← EXPLORAR al inicio de la primera sesión
├── [archivos raíz — generados por el agente anterior]
│   Hacer: ls -la $CODE_ROOT/
│   Leer los archivos encontrados — pueden contener:
│   - README del proyecto
│   - Notas de diseño o decisiones tomadas
│   - Configuraciones del entorno
│   - Scripts de utilidad
│   - Documentación local del agente anterior
│   Registrar el inventario en SESION-LOG.md (sesión inicial)
│
└── src/                                 ← DIRECTORIO DE TRABAJO GO
    ├── go.mod          (module bos · Go 1.25.0)
    ├── go.sum
    │
    ├── cmd/                             ← 40% del código — AQUÍ están los problemas
    │   ├── bos/main.go         (1,417 líneas)
    │   └── bosctl/
    │       ├── install_ui.go   (4,834 líneas — monolito P1)
    │       ├── main.go         (639 líneas)
    │       ├── bootstrap.go    (648 líneas)
    │       └── [resto archivos OK]
    │
    ├── internal/                        ← 60% del código — bien estructurado
    │   ├── state/manager.go            (✅ 18 estados — NO tocar)
    │   ├── server/jsonrpc.go           (extender en F6)
    │   ├── reconcile/scheduler.go      (⚠️ race P6/P14 — resolver en F1.5)
    │   ├── security/rbac_provider.go   (eliminar en F4.4 por ADR-006)
    │   └── [resto correctos — modelo de referencia]
    │
    ├── _legacy/                        ← crear en F0.1 — memoria del proyecto
    ├── .github/workflows/ci.yml        ← crear en F0.5
    ├── scripts/
    │   ├── validate.sh                 ← crear en F0.5
    │   ├── BOS-REPAIR-DASHBOARD.sh     ← copiar desde plandeaccion/
    │   └── BOS-REPAIR-VERIFICAR-CONTINUIDAD.sh ← copiar desde plandeaccion/
    └── docs/
        ├── ENVIRONMENTS.md             ← crear en F0.6
        └── runbooks/                   ← crear en F7.8
```

## Tabla de decisión: ¿dónde busco esto?

| Necesito saber... | Buscar en... |
|---|---|
| Qué átomo ejecutar ahora | `$PLAN_DIR/REGISTRO-ESTADO.md` |
| Cómo ejecutar un átomo específico | `$PLAN_DIR/instrucciones-agente/EJECUCION-FX.Y-*.md` |
| Descripción completa de un átomo | `$PLAN_DIR/BOS-REPAIR-PLAN-MAESTRO-v3.md §FASE-X` |
| Por qué se tomó una decisión de diseño | `$PLAN_DIR/bos-repair/BOS-REPAIR-*-ADR*.md` |
| Cómo funciona el JSON-RPC | `$PLAN_DIR/json-rpc/JSON-RPC-RESUMEN-EJECUTIVO.md` |
| DDL del Context Plane | `$PLAN_DIR/instrucciones-agente/EJECUCION-F5.1-F5.3-*.md` |
| Runbook de un incidente | `$PLAN_DIR/docs/runbooks/INDEX.md` |
| Comportamiento esperado del daemon | `$SBOS_DOCS/` (BOS_V8) |
| Contratos entre daemons | `$SBOS_SPECS/SBOS-MANUAL-ACOPLAMIENTO.md` |
| Código actual de un archivo | `$CODE_SRC/cmd/` o `$CODE_SRC/internal/` |
| Contexto del proyecto completo | `$CODE_ROOT/` raíz — archivos del agente anterior |
| Scripts de instalación del sistema | `$CODE_SRC/core/00_MASTER_INSTALL_SBOS.sh` |

*rutas-y-archivos.md v1.0 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
