# Anexo A.35 — El Calendario D4 ↔ bcalendar: estado real del control temporal
## Documento de respaldo de sustentación (tipo D+B)

**Versión:** 1.0.0 · **Fecha:** 2026-07-11 · **Respalda a:** MANUAL-CALENDARIO-D4 (2.07) · A.21 (D4 en el pipeline) · A.01 §B2 (vigencia)
**Verificación de código:** `temporal.rs` (104) + `calendar_alarm.rs` (179) + `DDLs` bcalendar — leída 2026-07-11
**Normas:** GTRBAC · RFC 5545 (iCalendar) · ISO 8601

## 1. El estado real — D4 con integración bcalendar
| Capacidad | Estado |
|---|---|
| Evaluador D4 temporal | ✅ `temporal.rs` (104) — horarios, vigencia |
| Alarmas de calendario | ✅ `calendar_alarm.rs` (179) |
| Contrato con bcalendar | ✅ `bcalendar_00__referencia.sql` + seeds `cal_calendar`/`cal_schedule` |

**Veredicto:** D4 tiene evaluador real + integración con el daemon de calendario (bcalendar) —
más completo que otros dominios external. Coherente con A.21 (D4 medio, 104 líneas).

## 2. Lo que FALTA — específico
| # | Brecha | Exigencia | Prioridad |
|---|---|---|:---:|
| CA1 | **D4 sin átomos propios — encadenado a D1** (1.01 §5.2); verificar que el PolicyChainResolver cablea el horario a los átomos de login | 1.01 §5.2 | P2 |
| CA2 | Consolidar los 3 tiempos dispersos (B2/B4/B8 del rol → cross-refs D4, A.01 §17.3) | GTRBAC | P2 |
| CA3 | RFC 5545 completo (recurrencias, excepciones) en el schedule | RFC 5545 | P3 |

## 3. Verificación de completitud
D4 evaluador + bcalendar ✅ · encadenamiento a D1 por verificar (CA1) · consolidación temporal pendiente (CA2, A.01 §17.3).

**Industria:** [RFC 5545 iCalendar](https://datatracker.ietf.org/doc/html/rfc5545) · GTRBAC

| Ver. | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-11 | Calendario D4: evaluador real (temporal.rs + calendar_alarm.rs) + integración bcalendar (contrato + seeds); brechas CA1 encadenamiento a D1, CA2 consolidación de los 3 tiempos, CA3 RFC 5545 completo. |
