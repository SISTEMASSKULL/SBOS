# MAPA DE NAVEGACIÓN — Plan de Acción BOS-REPAIR
## Guía de lectura y ejecución para el agente

**Ruta de este documento:**
`/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/daemons/bos/plandeaccion/plandeaccion/MAPA-NAVEGACION.md`

**Ruta del código fuente del proyecto:**
`/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/`

**Fecha:** Junio 2026 · SKULL · SBOS

---

## Regla fundamental antes de leer cualquier otro documento

```
ANTES DE EJECUTAR CUALQUIER ÁTOMO:
  1. Leer este MAPA-NAVEGACION.md completo (una sola vez)
  2. Leer BOS-REPAIR-PLAN-MAESTRO-v3.md §PARTE II (políticas globales)
  3. Verificar que la Fase previa está ✅ en el REGISTRO-ESTADO.md
  4. Leer las instrucciones específicas del átomo (instrucciones-agente/)
  5. Ejecutar
  6. Completar el Informe de Cierre antes de marcar ✅
```

---

## Dónde está cada cosa

### Árbol de directorios

```
plandeaccion/
│
├── MAPA-NAVEGACION.md              ← ESTE ARCHIVO — leer primero siempre
├── REGISTRO-ESTADO.md              ← estado actual de cada átomo (actualizar en cada cierre)
│
├── BOS-REPAIR-PLAN-MAESTRO-v3.md        ← EL PLAN — documento de referencia principal
├── BOS-REPAIR-EVALUACION-PLAN-MAESTRO.md ← evaluación 3.5/10 → 10/10, contexto del por qué
├── EVALUACION-AGENTE-IA-BOS-REPAIR.md   ← evaluación capacidades del agente IA
├── action_catalog.yml                    ← catálogo de acciones biaos (26 acciones)
│
├── bos-repair/                           ← 14 documentos: ADRs, specs, plan, sagas
│   └── BOS-REPAIR-INDEX.md              ← leer primero para entender los 14 docs
│
├── sbos-specs/                           ← copias locales de specs SBOS
│   ├── SBOS-049-CONTEXT-PLANE.md
│   ├── SBOS-052-VDI-SPEC.md
│   ├── SBOS-MANUAL-ACOPLAMIENTO.md
│   └── biaos-arquitectura.md / biaos-proyecto-ia-robusta.md
│
├── instrucciones-agente/                 ← LEER ANTES DE EJECUTAR CADA ÁTOMO
│   ├── EJECUCION-F0.5-INSTRUCCIONES-AGENTE.md  ← Pipeline CI/CD
│   ├── EJECUCION-F0.6-INSTRUCCIONES-AGENTE.md  ← Entornos + runner
│   ├── EJECUCION-F1.5-INSTRUCCIONES-AGENTE.md  ← Mutex observer/reconciler ⛔ CRÍTICO
│   ├── EJECUCION-F3.1-F3.5-INSTRUCCIONES-AGENTE.md ← Partir install_ui.go
│   ├── EJECUCION-F5.1-F5.3-INSTRUCCIONES-AGENTE.md ← Context Plane
│   ├── EJECUCION-F7.8-INSTRUCCIONES-AGENTE.md  ← Runbooks
│   ├── EJECUCION-F9.1-F9.3-INSTRUCCIONES-AGENTE.md ← Operator Soberano
│   └── EJECUCION-F10.1-F10.3-INSTRUCCIONES-AGENTE.md ← Gateway LLM + biaos
│
├── informes-cierre/                ← COMPLETAR DESPUÉS DE EJECUTAR CADA ÁTOMO
│   ├── INFORME-CIERRE-F0.5-CI-CD.md
│   ├── INFORME-CIERRE-F0.6-ENTORNOS.md
│   ├── INFORME-CIERRE-F7.8-RUNBOOKS.md
│   └── INFORME-CIERRE-F10.0-ACTION-CATALOG.md
│
├── docs/
│   └── runbooks/                   ← procedimientos operacionales en producción
│       ├── INDEX.md
│       ├── INCIDENTES-LOG.md
│       ├── RB-01-FICHA-DEGRADADA.md
│       ├── RB-02-DATA-RACE-DETECTADA.md
│       └── RB-03-CONTEXT-PLANE-DOWN.md
│
├── json-rpc/                       ← manual completo del protocolo
│   ├── JSON-RPC-RESUMEN-EJECUTIVO.md   ← leer este primero
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
└── anexos/                         ← material de investigación preservado
    ├── ANEXOS-INDEX.md             ← índice maestro de 27 anexos
    ├── ANX-022-gap1-pipeline-cicd/ ← ci.yml, validate.sh, branch-protection
    ├── ANX-023-gap2-entornos/      ← ENVIRONMENTS.md, staging-runner-setup.sh
    └── ANX-026-biaos-scripts/      ← ⚠️ scripts motor biaos (pendiente rediseño)
```
---

# ACTUALIZACIÓN DEL MAPA · Junio 2026 — fases F11-F17 y documentos nuevos

## Documentos agregados al árbol

```
plandeaccion/
├── REGISTRO-ESTADO.md                  ← v2.0 — 162 átomos (89✅/73🔴) F0-F17
├── BOS-REPAIR-PLAN-MAESTRO-v3.md       ← v4.0 — incluye PARTE V (F11-F17)
├── BOS-REPAIR-CUESTIONARIO-01.md       ← respuestas del operador (decisiones)
├── GESTION-RIESGOS-OPERATIVOS.md       ← v2 — gates F11.5/F12.3/F13.2/F14.2/F16.12/F17.1
└── bos-repair/
    ├── BOS-REPAIR-14-SBOS-CLIENT-SPEC.md      ← sbos-client: WS, monorepo, 3 modos
    ├── BOS-REPAIR-15-ESTANDARES-INTERNACIONALES.md ← CIS/NIST/SLSA/ISO → F17
    └── BOS-REPAIR-16-ADR007-DAEMONS-STUB.md   ← stubs de contrato → F14
```

## Flujos de decisión nuevos

```
"Voy a ejecutar un átomo F11.x (Ficha Engine)"
  → REGISTRO-ESTADO §F11 → SBOS-019-FICHAS (contrato) + ADR-021 (18 estados)
  → el modelo de 5 estados del doc contextual está REEMPLAZADO (F12.11→F11.4)

"Necesito el contrato de un stub (bauth/bhnexus/banexus/bkernel)"
  → bos-repair/BOS-REPAIR-16-ADR007 §3 → documento canónico citado por sección

"Voy a trabajar en el sbos-client o el ISO"
  → BOS-REPAIR-14-SBOS-CLIENT-SPEC + SBOS-052 §4 y §8
  → el instalador lleva los datos del tenant y se descarga desde el sbos
    o desde el escritorio del pod (Cuestionario B1/B4)

"Voy a tocar permisos/roles/governance"
  → SBOS-BAUTH-DECISIONES (socket+framing) → SBOS-ROLTEMPLATE v5.0 §B9
  → SBOS-BITMASK-SAM128 §2.2 (BitmaskBundle v3 · AND NOT · superusuario 0x0)

"Voy a entrar al staging"
  → PRIMERO: skill sbos-staging-security-monitor + GESTION-RIESGOS §staging
  → prioridad: F10.10 y F0.6.S en la misma ventana SSH
```

## Regla de oro actualizada (Cuestionario-01)

Ante cualquier duda: knowledge → código legacy/_snapshots/ → BosAgent/ raíz
→ recién entonces escalar. Las respuestas que están en la documentación NO
se escalan al operador.
---

## Cómo navegar según la tarea

### → Quiero saber en qué átomo trabajar ahora

```
1. Abrir REGISTRO-ESTADO.md
2. Buscar el primer átomo con estado 🟡 EN PROGRESO (retomar)
   o el primer átomo con estado 🔴 NO INICIADA cuya fase previa es ✅
3. Leer instrucciones-agente/EJECUCION-<FASE>-INSTRUCCIONES-AGENTE.md
```

### → Quiero entender el plan completo

```
Leer en este orden:
  1. BOS-REPAIR-EVALUACION-PLAN-MAESTRO.md — qué está roto y por qué (10 min)
  2. BOS-REPAIR-PLAN-MAESTRO-v3.md
     §PARTE I   — diagnóstico documental y 4 gaps
     §PARTE II  — políticas SFP-01..06 y DoD universal
     §PARTE III — arquitectura actual vs objetivo
     §PARTE IV  — las 11 fases con sus átomos
```

### → Quiero ejecutar un átomo específico

```
Para CUALQUIER átomo:
  1. Leer BOS-REPAIR-PLAN-MAESTRO-v3.md §FASE-X (descripción del átomo)
  2. Si existe instrucciones-agente/EJECUCION-FX.Y*.md → leer y seguir
  3. Si NO existe instrucciones del agente → seguir los pasos del plan maestro
  4. Ejecutar en: /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/
  5. Completar Informe de Cierre en informes-cierre/
  6. Actualizar REGISTRO-ESTADO.md
```

### → Quiero implementar un método JSON-RPC del daemon bos

```
  1. json-rpc/JSON-RPC-RESUMEN-EJECUTIVO.md  — panorama completo (15 min)
  2. json-rpc/JSON-RPC-05-arquitectura-servidor.md  — dispatcher y registro
  3. json-rpc/JSON-RPC-02-autenticacion.md  — si el método requiere auth
  4. json-rpc/JSON-RPC-06-errores-produccion.md  — manejo de errores
  5. json-rpc/JSON-RPC-09-orquestacion-multi-motor.md  — si es una saga
  Código de referencia existente: BosAgent/src/internal/server/jsonrpc.go
```

### → Hay un incidente en producción

```
  1. docs/runbooks/INDEX.md  — identificar qué runbook aplica
  2. RB-01: ficha DEGRADADA
     RB-02: DATA RACE en logs
     RB-03: Context Plane Down
  3. Registrar en docs/runbooks/INCIDENTES-LOG.md al resolver
```

### → Quiero entender las acciones de biaos

```
  1. action_catalog.yml  — las 26 acciones en 3 categorías
  2. informes-cierre/INFORME-CIERRE-F10.0-ACTION-CATALOG.md  — decisiones de diseño
  3. BOS-REPAIR-PLAN-MAESTRO-v3.md §FASE-10  — implementación de biaos
  Nota ⚠️: anexos/ANX-026-biaos-scripts/ tiene scripts pendientes de rediseño
```

---

## Relación con el código fuente del proyecto

```
plandeaccion/                              BosAgent/src/ (código fuente real)
─────────────────────────────────────────────────────────────────────────────
BOS-REPAIR-PLAN-MAESTRO-v3.md §F1.5   →   internal/observer/observer.go  (CREAR)
BOS-REPAIR-PLAN-MAESTRO-v3.md §F3.x   →   internal/tui/                  (CREAR)
BOS-REPAIR-PLAN-MAESTRO-v3.md §F4.4   →   internal/security/rbac_provider.go (ELIMINAR)
BOS-REPAIR-PLAN-MAESTRO-v3.md §F5.x   →   internal/context/              (CREAR)
BOS-REPAIR-PLAN-MAESTRO-v3.md §F6.x   →   internal/server/jsonrpc.go     (EXTENDER)
BOS-REPAIR-PLAN-MAESTRO-v3.md §F9.x   →   internal/k8s/core.go           (EXTENDER)
BOS-REPAIR-PLAN-MAESTRO-v3.md §F10.x  →   internal/biaos/                (CREAR)
action_catalog.yml                     →   /etc/bos/ai/action_catalog.yml (DESPLEGAR)
anexos/ANX-022/ci.yml                  →   .github/workflows/ci.yml       (CREAR)
anexos/ANX-022/validate.sh             →   scripts/validate.sh            (CREAR)
anexos/ANX-023/ENVIRONMENTS.md         →   docs/ENVIRONMENTS.md           (CREAR)
anexos/ANX-023/staging-runner-setup.sh →   docs/staging-runner-setup.sh   (CREAR)
docs/runbooks/                         →   docs/runbooks/                 (CREAR)
```

---

## Convenciones de estado en REGISTRO-ESTADO.md

```
🔴 NO INICIADA    — átomo pendiente, no se ha tocado
🟡 EN PROGRESO    — trabajo iniciado, no completado (señal de retoma activa)
✅ COMPLETA       — DoD universal + DoD específico + Informe de Cierre escritos
⚠️ BLOQUEADA      — depende de un átomo previo que no está ✅
```

---

## Reglas de trabajo obligatorias (del Plan Maestro §PARTE II)

```
SFP-01  Nunca borrar código — archivar en BosAgent/src/_legacy/ con fecha y fase
SFP-02  El código nuevo compila y pasa go test -race ANTES de tocar el original
SFP-03  Feature flags de migración: BOS_OBSERVER_V2=true activa el nuevo código
SFP-04  Un átomo = un commit: [F1.5] fix: agregar mutex anti-race en internal/observer/
SFP-05  go build ./... debe pasar VERDE en cada commit — si rompe: git revert
SFP-06  _legacy/README.md es la memoria del proyecto — actualizar en cada extracción

DoD-Universal (antes de marcar cualquier átomo ✅):
  go build ./...          ✅
  go vet ./...            ✅
  gofmt -l . = vacío      ✅
  go test -race -count=10 ./...  ✅  ← el más importante
  Godoc presente en código nuevo ✅
  Informe de Cierre escrito      ✅
```

---

## Próximos átomos a ejecutar (al inicio del plan)

```
F0.1 → F0.2 → F0.3 → F0.4 → F0.5 → F0.6 → [Fase 1 comienza]
         ↓
F0.5: instrucciones en instrucciones-agente/EJECUCION-F0.5-INSTRUCCIONES-AGENTE.md
F0.6: instrucciones en instrucciones-agente/EJECUCION-F0.6-INSTRUCCIONES-AGENTE.md
F7.8: instrucciones en instrucciones-agente/EJECUCION-F7.8-INSTRUCCIONES-AGENTE.md
F0.1..F0.4: seguir directamente BOS-REPAIR-PLAN-MAESTRO-v3.md §FASE-0
```

---

*MAPA-NAVEGACION.md v1.0 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
