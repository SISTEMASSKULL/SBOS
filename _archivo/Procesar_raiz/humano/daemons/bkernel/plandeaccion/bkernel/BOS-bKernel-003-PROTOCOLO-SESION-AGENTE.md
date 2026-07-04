# BOS-bKernel-003 — PROTOCOLO DE SESIÓN (particularidades bKernel)

## 0. Metadatos
| Campo | Valor |
|---|---|
| **Documento** | BOS-bKernel-003 · **Versión** 1.0 · **Estado** VIGENTE—REDACTADO · **Fecha** 2026-06-10 |
| **Serie** | BOS-bKernel — instancia de → ECO-003 (el protocolo maestro MANDA; aquí solo lo específico) |

## 1. Apertura — adiciones a ECO-003 §2
- A5': cargar bK-007 además de ECO-007.
- A6': si la tarea toca CDC: leer ANTES los satélites completos (02-WAL-FUNDAMENTOS,
  03-CDC-HERRAMIENTAS) y POSTGRESQL-WAL-*; si toca DDL Guardian: BKERNEL-DDL-GUARDIAN íntegro.
- A8': verificar estado de gates: ninguna tarea G1+ sin ECO-020 VALIDADO.

## 2. Ejecución — reglas específicas
- Jamás abrir sockets/puertos de entrada (D2). Revisión obligatoria del diff: ningún
  `bind`/`listen` fuera de 9460/9461 readonly.
- Toda escritura del daemon va a `sbos_kernel_db.bkernel` (estado operacional) — NUNCA a
  BDs de negocio (F-05/F-08); las intenciones van al stream.
- Test de eco (anti-loop F-06) obligatorio en toda tarea que toque cdc/outbox.
- Checkpoints: toda tarea de listener prueba kill -9 + reanudación sin pérdida/duplicado.

## 3. Cierre — adiciones a ECO-003 §4
- C2': actualizar bK-004 (módulos/tareas) con evidencia (comando+salida).
- C4': entrada en bK-005 además de ECO-005 (referencia cruzada S-NNN).

## Criterios de completitud
- [x] Solo particularidades; el maestro manda. · [ ] Validación del arquitecto.

---
*bK-003 v1.0 · maestro: → ECO-003*
