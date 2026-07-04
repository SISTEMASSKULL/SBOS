# GAPS-HITL.md — Decisiones Técnicas Resueltas

**Documento de decisiones de arquitectura para la FASE 20.**
**Versión:** 2.0 (RESUELTO) · **Fecha:** 2026-06-17

---

## Resumen ejecutivo

Las 7 preguntas pendientes eran de naturaleza técnica, no de criterio humano.
Se resolvieron leyendo la documentación completa del proyecto (BOS-REPAIR, BOS_V8,
SBOS-053, Dev_Control_Certification_Method) y aplicando estándares internacionales
de la industria (Go contract patterns 2025, Event Sourcing Snapshot, CQRS, CIS,
ISO 27001, WCAG, NSA/CISA K8s Hardening).

---

## H-1 — Orden de implementación FASE 20 vs M1-M6

**Decisión: Opción B — Intercalar Bloques A+B entre M1.5 y M2.1**

**Fundamento documental:**

1. SBOS-053 §12 (Checklist de Cumplimiento): "Toda ficha nueva pasa el caso **DC-01** (instalable sin TUI) antes de mergear." Esto establece DTC-01 como PRECONDICIÓN de merge, no como verificación post-implementación.

2. REGISTRO-ESTADO.md: M2.4 requiere `bosctl deploy seed-skull.yml` en <30s. Si DTC-01 no está verificado, el deploy no puede certificarse como "funciona sin TUI".

3. Dev_Control_Certification_Method §4: Gates 0-1 DEBEN ser bloqueantes antes de avanzar.

**Orden resultante:**
```
M1.3 → M1.4 → M1.5  (daemon foundation)
   ↓
F20.A.1 → F20.A.2   (contracts/ + SAGA_SNAPSHOT — arquitectura base)
   ↓
M2.1 → M2.5          (primer tenant real — requiere DTC-01 verificado)
   ↓
F20.A.3 → F20.A.7    (resto de verificación DTC)
   ↓
F20.B → F20.E        (pruebas DC + certificación + refuerzo)
   ↓
F20.C → F20.D        (modo híbrido + métricas — menor prioridad)
```

---

## H-2 — Gates 2 y 4 como bloqueantes

**Decisión: Opción B — Gate 2 automatizado bloqueante desde F20.D.1, Gate 4 advisory hasta post-M6**

**Fundamento documental:**

1. Dev_Control_Certification_Method §4 Gate 2: "Quién verifica: revisión de código por al menos un par." Esto es inherentemente humano. Pero el mismo documento en §6 define métricas AUTOMATIZABLES: complejidad ciclomática, líneas por función, duplicación.

2. ADR-015 (Protocolo de Desarrollo en Dos Fases): Estamos en **Fase A** — Supervisión y Preparación. El código no se ejecuta en producción. Las Gates deben ser proporcionales a la fase: automatizadas ahora, humanas en Fase B.

3. Industry standard (golangci-lint 2025): `gocyclo` min=15, `funlen`=100 líneas, `dupl`<3%. Estos son automatizables y bloqueantes. La revisión de diseño Beck+SOLID requiere par humano.

**Aplicación:**
- Gate 0 (build) + Gate 1 (tests): **BLOQUEANTE** — ya activo
- Gate 2 automatizado (lint, complejidad, duplicación): **BLOQUEANTE** desde F20.D.1
- Gate 2 humano (revisión Beck+SOLID): **ADVISORY** hasta Fase B (ADR-015)
- Gate 4 (ADR): **ADVISORY** — requerido para nuevas interfaces/paquetes, no bloquea

---

## H-3 — Alcance del modo híbrido

**Decisión: Opción C — Seed parcial, wizard pregunta solo los campos faltantes**

**Fundamento documental:**

1. SBOS-053 §3.3 (texto exacto): "Si un `seed.yml` parcial o completo ya existe, la TUI lo carga y muestra sus valores como defaults en el formulario. El usuario puede revisarlos, modificarlos y confirmar — o simplemente confirmar sin cambiar nada."

2. SBOS-053 DC-09 (caso de prueba): "Ejecutar `bosctl setup --seed seed.yml` con un `seed.yml` parcialmente relleno. El wizard presenta los valores del archivo como defaults; los campos vacíos quedan editables."

3. Principio YAGNI (Dev_Control_Certification_Method §2.4): No crear restricciones artificiales. Si el seed puede ser parcial, el wizard debe soportarlo.

**Aplicación:**
- `bosctl setup --seed seed.yml` carga cualquier subconjunto de campos
- Campos con valor en seed → pre-rellenados (editables)
- Campos sin valor en seed → vacíos (requeridos si son mandatory)
- El usuario puede modificar cualquier campo y confirmar
- `bosctl deploy seed.yml` para modo completamente desatendido

---

## H-4 — Umbrales de métricas: ¿hard o advisory?

**Decisión: Opción B — Baseline actual + no regresión en PRs nuevos**

**Fundamento documental:**

1. Dev_Control_Certification_Method §6: "Las métricas son indicadores, no objetivos. Un número fuera de rango es una señal para investigar, no una condena automática."

2. §7 Alarma Amarilla: "Evaluar y decidir conscientemente." No dice "bloquear".

3. Industry standard (Go 2025): Los proyectos establecen un baseline de métricas actuales y rechazan PRs que empeoran los indicadores. Esto permite mejora progresiva sin bloquear el desarrollo.

4. Principio de Diseño Simple (Beck, Regla 1): "Pasa todos los tests" es la prioridad. Las métricas son Regla 4 (YAGNI/Mínima cantidad) — importantes pero subsidiarias.

**Aplicación:**
- Calcular baseline actual: cobertura actual %, complejidad máxima actual, duplicación actual %
- PRs nuevos: no pueden empeorar ninguna métrica (cobertura no puede bajar, complejidad no puede subir)
- Umbrales aspiracionales documentados como objetivo a largo plazo
- Mejora progresiva: cada PR que toca un archivo debería dejarlo con ≤ complejidad anterior

---

## H-5 — ¿FASE 20 modifica el orden de M1-M6?

**Decisión: No modifica el orden M1→M6. FASE 20 es TRANSVERSAL.**

**Fundamento documental:**

1. REGISTRO-ESTADO.md (Sistema Dual): "FASE M (M1–M6) = orden de ejecución. FASE 0–19 = granularidad de implementación." Y ahora "FASE 20 = verificación transversal."

2. SBOS-053 §1 (Alegoría): "El BOS es el paciente. La TUI es el monitor." La FASE 20 verifica que esta alegoría se cumpla — es una capa de verificación que atraviesa todas las fases M.

3. Concepción-BOS-Y-FASES-M.md: M1→M6 es una "escalera de certificación". FASE 20 no es un escalón nuevo — es la barandilla que verifica que cada escalón es sólido.

**Aplicación:**
- M1.3→M1.5: completar el daemon foundation (prioridad máxima)
- F20.A.1 se ejecuta en paralelo con M1.4 (necesita el daemon corriendo para verificar contracts/)
- F20.A.2→A.7: post-M1.5 (necesitan DDL + socket para SAGA_SNAPSHOT)
- F20.B: post-M2.4 (necesitan tenant real para DC-01..10)
- F20.C: post-M2 (necesitan seed.yml funcionando)
- F20.D: continuo (métricas y CI mejoran progresivamente)
- F20.E: post-F20.A (refuerzo de DTC ya implementados)

---

## H-6 — Ubicación de `contracts/events/`

**Decisión: `internal/contracts/events/` dentro del módulo `bos`**

**Fundamento documental:**

1. SBOS-053 §10 (Estructura de Carpetas): Recomienda `contracts/events/` separado de `bos/` y `tui/`. Pero ambos (cmd/bosctl/ e internal/tui/) están en el mismo módulo Go `bos`.

2. Go contract pattern 2025 (industry): Cuando todos los consumidores están en el mismo módulo, `internal/` es la ubicación correcta. `pkg/` solo si otros módulos/repos importan los tipos.

3. ADR-020 (Interface Dual): Todo daemon expone JSON-RPC 2.0 + WebSocket sobre el mismo Unix socket. Los tipos de eventos son parte de ese contrato.

4. Principio YAGNI: No crear un módulo Go separado hasta que otro daemon (bkernel, bauth) necesite importar estos tipos. Cuando eso ocurra, extraer a `pkg/contracts/events/` con su propio go.mod.

**Aplicación:**
```
BosAgent/src/
├── internal/
│   └── contracts/
│       └── events/
│           ├── doc.go              // Package events — tipos compartidos bos↔tui
│           ├── seed_params.go      // SeedParams struct (≡ seed.yml schema)
│           └── saga_event.go       // SagaEvent + SagaSnapshot structs
├── cmd/
│   ├── bos/        → import bos/internal/contracts/events
│   └── bosctl/     → import bos/internal/contracts/events
└── internal/
    └── tui/        → import bos/internal/contracts/events
```

Regla de import: `cmd/bos/` NUNCA importa `internal/tui/`. `internal/tui/` solo importa `internal/contracts/events/`. Verificable con `go list -deps`.

---

## H-7 — Prioridad para las próximas sesiones

**Decisión: Seguir el orden de FASE M (REGISTRO-ESTADO), intercalando F20.A donde aplique**

**Fundamento documental:**

1. REGISTRO-ESTADO.md: "el siguiente átomo es siempre el primer 🔴 de FASE M (leyendo de arriba hacia abajo)."

2. M1.3 está 🟡 — es el átomo activo. Completarlo antes de abrir otro.

3. SBOS-053 DTC-01: sin daemon corriendo no hay nada que desacoplar.

**Orden para las próximas 5 sesiones:**

| Sesión | Átomo(s) | Qué se hace |
|--------|----------|------------|
| **Próxima** | M1.3 | Completar: systemd enable para arranque automático al boot en VPS |
| **+1** | M1.4 | Context API REST :9443 — 6 endpoints (CRÍTICO para Kong) |
| **+2** | M1.5 + F20.A.1 | DDL auto-apply + crear `internal/contracts/events/` |
| **+3** | M2.1 | Ficha Engine: parser + DEPENDENCY_RESOLVER + ejecutor |
| **+4** | M2.2 + F20.A.2 | Stack Alpha en VPS + SAGA_SNAPSHOT |

---

## Referencias cruzadas

| Decisión | Documentos fuente | Estándares |
|----------|------------------|------------|
| H-1 (orden) | REGISTRO-ESTADO §Sistema Dual, SBOS-053 §12 | Dev_Control_Certification §4 Gates |
| H-2 (gates) | ADR-015 Fase A/B, Dev_Control_Certification §4 §6 | golangci-lint 2025 best practices |
| H-3 (híbrido) | SBOS-053 §3.3, DC-09 | WCAG (keyboard-only wizard) |
| H-4 (métricas) | Dev_Control_Certification §6 §7, Beck Regla 1 | Go baseline + no-regression pattern |
| H-5 (orden M) | REGISTRO-ESTADO §FASE M, Concepción-BOS | CIS, ISO 27001 (audit trail) |
| H-6 (contracts/) | SBOS-053 §10, ADR-020 | Go contract package pattern 2025 |
| H-7 (prioridad) | REGISTRO-ESTADO regla de ejecución | NSA/CISA K8s Hardening (security-first) |

---

*GAPS-HITL.md v2.0 (RESUELTO) · BOS-REPAIR · SKULL · SBOS · Junio 2026*
*Todas las decisiones fueron tomadas con base en la documentación del proyecto y estándares internacionales.*
*No se requiere intervención HITL para continuar.*
