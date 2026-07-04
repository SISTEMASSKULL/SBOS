# BOS-ECO-002 — MAPA DE NAVEGACIÓN GLOBAL

## 0. Metadatos del documento

| Campo | Valor |
|---|---|
| **Documento** | BOS-ECO-002-MAPA-DE-NAVEGACION |
| **Versión** | 1.0 |
| **Estado** | VIGENTE — REDACTADO |
| **Fase asociada** | Transversal — Lote 1-G (gobierno operativo, enmienda R7) |
| **Serie** | BOS-ECO |
| **Fuentes que absorbe** | Rutas de lectura de ECO-000 §8 (que ahora referencian aquí) |
| **Prerequisitos de lectura** | ECO-000 §1–§5 |
| **Normas aplicables** | ISO/IEC/IEEE 15289:2019 cl. 7 (tipo *description*); ISO/IEC/IEEE 26514:2022 (orientación de información para usuarios) |
| **Audiencia** | Ambas — primera parada de TODO lector después de ECO-000 |
| **Custodio** | Agente documental |
| **Fecha** | 2026-06-10 |

---

## 1. Para qué sirve este mapa

Responde en segundos: **¿dónde está lo que busco y en qué orden lo leo?** Cada serie tiene
su propio mapa local (→ bK-002, → bd-002); este es el mapa global del programa.

## 2. El territorio: 3 series, 65 documentos

```
BOS-ECO (12) ── gobierno + doctrina + contratos
│  000 Guía global          001 Memoria global       002 ESTE MAPA
│  003 Protocolo de sesión  004 Registro de estado   005 Log de sesiones
│  006 Instrucciones de uso 007 Skill del programador 008 Plan maestro atómico
│  010 Doctrina JSON-RPC    020 Contrato bK↔bd (L2)  030 Acoplamiento al bos (L2)
│
BOS-bKernel (28) ── el kernel del plano de datos
│  000-007 gobierno de la serie (espejo del juego ECO, instanciado para bKernel)
│  010 Visión · 020 Normas · 030 Requisitos · 040 ADRs · 050 Arquitectura
│  060 CDC · 070 Enricher+Grafo · 080 CESQL · 090 Intenciones · 100 DDL Guardian
│  110 Lineage · 120 Cluster · 130 Datos · 140 Fichas · 150 Integraciones
│  160 Seguridad · 170 Operación · 180 Instalación · 190 PLAN ATÓMICO · 200 Glosario
│
BOS-biedata (25) ── el motor soberano de intercambio de datos
   000-007 gobierno de la serie (espejo del juego ECO, instanciado para biedata)
   010 Visión · 020 Normas · 030 Requisitos · 040 ADRs · 050 Arquitectura
   060 Protocolo RPC · 070 Fichas+Pipeline · 080 Cajas WASM · 090 Flujos
   100 Datos · 110 Seguridad · 120 Resiliencia · 130 Observabilidad
   140 Operación · 150 Instalación · 160 PLAN ATÓMICO · 170 Glosario
```

## 3. Navegación por intención ("quiero…")

| Quiero… | Ruta |
|---|---|
| Retomar el trabajo (soy un agente nuevo en sesión nueva) | ECO-003 §2 (protocolo de apertura) → ECO-004 (estado) → ECO-005 (última sesión) |
| Saber el estado exacto del proyecto | ECO-004 (máquina) + ECO-001 (humano) |
| Entender QUÉ es el sistema | ECO-000 §2 → bK-010 → bd-010 |
| Entender la doctrina (D1–D10) | ECO-000 §5 — único hogar |
| Implementar un módulo de bKernel | ECO-007 + bK-007 (skills) → bK-190 (tarea atómica) → doc SSOT del módulo |
| Implementar un módulo de biedata | ECO-007 + bd-007 → bd-160 (tarea atómica) → doc SSOT del módulo |
| Saber qué tarea sigue | ECO-008 §4 (tablero de etapas) → plan atómico de la serie (bK-190 / bd-160) |
| Consultar el protocolo de mensajes | ECO-010 (doctrina) → bd-060 (protocolo completo de biedata) |
| Consultar el contrato bK↔bd | ECO-020 (Lote 2 — único hogar) |
| Saber cómo instala/administra el bos | ECO-030 (Lote 2) |
| Resolver una contradicción del knowledge histórico | ECO-000 §9 (jerarquía + supersesiones) → ECO-001 §7 (conflictos vivos) |
| Registrar un conflicto nuevo | ECO-003 §5 (procedimiento) → ECO-001 §7 |
| Cerrar mi sesión de trabajo | ECO-003 §4 (protocolo de cierre) → actualizar ECO-004/005 (+ los de la serie tocada) |

## 4. Navegación por concepto (índice "¿dónde vive X?")

| Concepto | Hogar SSOT |
|---|---|
| Doctrina D1–D10 | ECO-000 §5 |
| Estados y máquina de estados documental/módulos | ECO-004 §2 |
| Intención estructurada (formato de wire) | ECO-020 (doctrina en ECO-010 §10) |
| Sobre JSON-RPC, errores canónicos, nomenclatura | ECO-010 §6–§8 |
| Cero invasión, CDC multi-motor | bK-010 / bK-060 |
| Fichas bKernel (4 archivos) / reglas CESQL | bK-140 / bK-080 |
| Fichas biedata (3 archivos) / pipeline / tiers | bd-070 / bd-060 |
| Cajas WASM, import/export, file-watch | bd-080 |
| Inbox/idempotencia/saga/circuit breaker de biedata | bd-120 (modelo de datos en bd-100) |
| `context_sessions`, ctx_id, Context Plane | ECO-030 + bK-130 |
| SLOs con puntos de medición | bK-170 / bd-140 |
| Puertos (norma) | SBOS-050 (externo) — resumen en ECO-000 §4 |
| Glosarios | bK-200 / bd-170 |

## 5. Navegación del knowledge histórico (solo como fuente)

Jerarquía N1–N6+REF: ECO-000 §9. Antes de usar CUALQUIER dato histórico: tabla de
supersesiones (ECO-000 §9) y conflictos vivos (ECO-001 §7). Regla: el histórico se cita,
jamás gobierna.

## 6. Criterios de completitud de este documento

- [x] Mapa de las 3 series con los 65 documentos post-enmienda R7 (conteo reconciliado INC-01).
- [x] Navegación por intención (13 entradas) y por concepto (14 entradas) sin duplicar contenido SSOT.
- [ ] Actualización al cerrar cada lote (rutas nuevas) — obligación del protocolo de cierre (ECO-003 §4).
- [ ] Validación del arquitecto.

---
*BOS-ECO-002 v1.0 · 2026-06-10 · Los mapas locales: → BOS-bKernel-002 · → BOS-biedata-002.*
