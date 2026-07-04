# BOS-biedata-002 — MAPA DE NAVEGACIÓN DE LA SERIE

## 0. Metadatos
| Campo | Valor |
|---|---|
| **Documento** | BOS-biedata-002-MAPA-DE-NAVEGACION · **Versión** 1.0 · **Estado** VIGENTE—REDACTADO · **Fecha** 2026-06-10 |
| **Serie** | BOS-biedata — instancia del mapa maestro → ECO-002 |
| **Prerequisitos** | ECO-000 · ECO-002 |

## 1. El daemon en una línea
biedata = SBOS Data Gateway: Sovereign Data Exchange Engine — caja cerrada (D9) que
solo actualiza BDs por consumo y emisión de datos; nexo de intercambio de DATOS con el
exterior, ejecutor universal interno (D1) y aduana de calidad; motor recursivo de fichas
con tiers por tenant; "el RPC siempre hace algo".

## 2. Mapa de la serie (25 documentos)
```
GOBIERNO   000 guía · 001 memoria · 002 ESTE MAPA · 003 protocolo sesión ·
           004 registro estado · 005 log sesiones · 006 instrucciones · 007 skill
QUÉ ES     010 visión (Tres Responsabilidades, F1–F12) · 020 normas · 030 requisitos · 040 ADRs
CÓMO ES    050 arquitectura (módulos Rust, biedata.toml, 9470/9471/9472)
MOTOR      060 protocolo RPC (mensaje+delivery, único endpoint, 4 capas, tiers/contratos)
           → 070 fichas+pipeline (3 archivos, merge de contexto, fichas system/describe/dry_run)
           → 080 cajas WASM (import/export 6 fases, file-watch, cuarentena, legacy)
           → 090 flujos canónicos (ciclo WAL completo, rechazo de aduana, recursivo)
BASE       100 modelo de datos (biedata_db: operations, _inbox, idempotency, sagas, contratos)
DEFENSA    110 seguridad (5 capas + 4 del protocolo, Vault, BOLA) · 120 resiliencia
           (idempotencia/saga/breaker) · 130 observabilidad (:9471, ctx_id, OTel)
OPERAR     140 SLO/runbooks · 150 instalación (bos, SIGUSR1) · 160 PLAN ATÓMICO · 170 glosario
```

## 3. Navegación por intención
| Quiero… | Ruta |
|---|---|
| Implementar (sesión de código) | ECO-003 → bd-007 skill → bd-160 tarea → SSOT de la tarea |
| Crear una ficha nueva | 070 (los 3 archivos) + 060 (nomenclatura .vN y validación) |
| Crear una caja de import/export | 080 (6 fases) + 100 (auditoría) |
| Entender una llamada de punta a punta | 090 §1 (flujo completo con rechazo y reintento) |
| Versionado/tiers/contratos de tenant | 060 (SSOT; gobierno en 040) |
| El contrato con bKernel (Inbox/streams) | → ECO-020 (NUNCA aquí) |
| Por qué cada decisión | 040 (Inbox Pattern, RPC exclusivo, fichas vs cajas, tiers) |

## 4. Fuentes históricas (solo fuente; jerarquía ECO-000 §9)
N1: DAEMON-BIEDATA-00..08 v3.0 (corpus canónico) · N6: SBOS_biedata_* V8 (rescate de
capacidades de intercambio exterior F-001..F-007 y ADRs, contra v3.0) · supersesiones
específicas: identidad/API/unidad declarativa/emisor fiscal (ECO-000 §9, D9/D10).

## Criterios de completitud
- [x] Mapa de los 25 docs, navegación por intención, fuentes. · [ ] Actualización por lote · [ ] Validación.

---
*bd-002 v1.0 · maestro: → ECO-002*
