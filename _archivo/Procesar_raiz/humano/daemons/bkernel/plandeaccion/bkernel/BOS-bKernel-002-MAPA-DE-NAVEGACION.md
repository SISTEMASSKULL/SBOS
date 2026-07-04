# BOS-bKernel-002 — MAPA DE NAVEGACIÓN DE LA SERIE

## 0. Metadatos
| Campo | Valor |
|---|---|
| **Documento** | BOS-bKernel-002-MAPA-DE-NAVEGACION · **Versión** 1.0 · **Estado** VIGENTE—REDACTADO · **Fecha** 2026-06-10 |
| **Serie** | BOS-bKernel — instancia del mapa maestro → ECO-002 |
| **Prerequisitos** | ECO-000 · ECO-002 |
| **Audiencia/Custodio** | Ambas / agente documental |

## 1. El daemon en una línea
bKernel = SBOS Data Kernel: escucha TODAS las BDs del stack por CDC (D10), enriquece,
decide (CESQL+grafo) y estructura intenciones que biedata ejecuta (D1/D2/D3).

## 2. Mapa de la serie (28 documentos)
```
GOBIERNO   000 guía · 001 memoria · 002 ESTE MAPA · 003 protocolo sesión ·
           004 registro estado · 005 log sesiones · 006 instrucciones · 007 skill
QUÉ ES     010 visión/fronteras (F-01..F-11) · 020 normas · 030 requisitos F-XXX · 040 ADRs
CÓMO ES    050 arquitectura (módulos Rust, bkernel.toml, 9460/9461)
PIPELINE   060 CDC multi-motor → 070 enricher+grafo(AGE) → 080 routing CESQL →
           090 intenciones+orquestación (Outbox, sagas COMO DECISOR, task_catalog.sh)
PROTECCIÓN 100 DDL Guardian · 110 lineage+observabilidad · 120 cluster (>25 fuentes)
BASE       130 modelo de datos (sbos_kernel_db.bkernel) · 140 fichas (4 archivos)
BORDE      150 integraciones (bSearch, streams) · 160 seguridad (superficie 0)
OPERAR     170 SLO/runbooks · 180 instalación (por el bos) · 190 PLAN ATÓMICO · 200 glosario
```

## 3. Navegación por intención
| Quiero… | Ruta |
|---|---|
| Implementar (sesión de código) | ECO-003 apertura → bK-007 skill → bK-190 tarea → docs SSOT de la tarea |
| Entender el flujo de un evento | 060 → 070 → 080 → 090 (en ese orden) |
| Crear/editar una ficha | 140 (los 4 archivos) + 080 (reglas CESQL) |
| El contrato con biedata | → ECO-020 (NUNCA aquí — SSOT) |
| Saber qué escucha y qué jamás hace | 010 (fronteras literales) |
| Datos/DDL | 130 · DDL Guardian: 100 |
| Por qué cada decisión | 040 (ADRs) + supersesiones ECO-000 §9 |

## 4. Fuentes históricas de la serie (solo fuente, jerarquía ECO-000 §9)
N1: 01-MASTER-v4_0(+04) · N2: 05-PROPUESTA, ARQ-PROYECTADA · N3: satélites 02/03,
DDL-GUARDIAN, contratos bSearch D1–D3 · N5: CANONICA/HUMAN-DOC · N6: serie V8 · F: WAL docs.

## Criterios de completitud
- [x] Mapa de los 28 docs, navegación por intención, fuentes con jerarquía. 
- [ ] Actualización por lote · [ ] Validación del arquitecto.

---
*bK-002 v1.0 · maestro: → ECO-002*
