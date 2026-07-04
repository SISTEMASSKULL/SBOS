# BOS-biedata-003 — PROTOCOLO DE SESIÓN (particularidades biedata)

## 0. Metadatos
| **Documento** | BOS-biedata-003 · **Versión** 1.0 · **Estado** VIGENTE—REDACTADO · **Fecha** 2026-06-10 |
|---|---|
| **Serie** | BOS-biedata — instancia de → ECO-003 (el maestro MANDA; aquí solo lo específico) |

## 1. Apertura — adiciones a ECO-003 §2
- A5': cargar bd-007 además de ECO-007.
- A6': si la tarea toca protocolo/fichas: leer ANTES DAEMON-BIEDATA-01/02/08 íntegros;
  resiliencia: 06; cajas/import-export: SBOS_biedata_FUNCIONALIDADES (rescate V8) + 03.
- A8': gates — ninguna tarea G1+ sin ECO-020 VALIDADO; ninguna de tiers sin bd-060 REDACTADO.

## 2. Ejecución — reglas específicas
- Toda escritura de negocio del código lleva `origin='biedata'` (F3); test obligatorio.
- `biedata_db` solo auditoría/operación (F2): si una tarea propone guardar negocio ahí,
  es conflicto — detener y registrar.
- Validación SIEMPRE antes del pipeline (F8): ninguna ruta de código alcanza
  task_catalog.sh sin validation.yml en verde; test de rechazo con BD intacta.
- Dual-user PG: `biedata_rw` solo tablas autorizadas; `biedata_ro` para outbound (F4).
- Cero HTTP saliente a diálogos regulados (D9): el linter de dependencias del CI marca
  clientes HTTP no declarados en el doc de arquitectura.

## 3. Cierre — adiciones a ECO-003 §4
- C2': actualizar bd-004 con evidencia. C4': entrada en bd-005 (+ referencia S-NNN global).

## Criterios de completitud
- [x] Solo particularidades; el maestro manda. · [ ] Validación.

---
*bd-003 v1.0 · maestro: → ECO-003*
