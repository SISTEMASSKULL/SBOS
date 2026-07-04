# BOS-ECO-004 — REGISTRO DE ESTADO GLOBAL (legible por máquina)

## 0. Metadatos del documento

| Campo | Valor |
|---|---|
| **Documento** | BOS-ECO-004-REGISTRO-DE-ESTADO |
| **Versión** | 1.0 |
| **Estado** | VIGENTE — documento vivo, actualizar en CADA cierre de sesión (ECO-003 §4 C2) |
| **Serie** | BOS-ECO (formato maestro; bK-004 y bd-004 registran el detalle por serie) |
| **Relación con ECO-001** | ECO-001 es la memoria HUMANA (narrativa, hitos, conflictos); este es el estado MÁQUINA (YAML canónico). Ante divergencia: se reconcilian en la misma sesión; la fuente de verdad del *estado* es ESTE documento |
| **Normas aplicables** | ISO/IEC/IEEE 15289:2019 cl. 7 (tipo *record*) |
| **Audiencia** | Agentes (parseo directo) y humanos |
| **Custodio** | Toda sesión que cierre |
| **Fecha** | 2026-06-10 |

---

## 1. Máquinas de estado canónicas

```
Documento: PENDIENTE → EN-REDACCION → REDACTADO → VALIDADO        (solo el arquitecto → VALIDADO)
Módulo:    ESPECIFICADO → EN-DESARROLLO → IMPLEMENTADO → VERIFICADO
Tarea:     PENDIENTE → EN-CURSO → HECHA(+evidencia) → VERIFICADA
Conflicto: PROPUESTO → VALIDADO | RECHAZADO
Sesión:    ABIERTA → CERRADA | ABANDONADA(motivo)
```

## 2. Estado global (YAML canónico)

```yaml
sbos_program_state:
  schema_version: 1
  updated: "2026-06-10"
  updated_by_session: "S-007"
  doctrine: { frozen: [D1,D2,D3,D4,D5,D6,D7,D8,D9,D10], amendments: [R7] }
  structure: { series: 3, documents_total: 65, lots: "1,1-G,2..9" }
  phase: { documental: "Lote 1 + 1-G entregados (REDACTADO)", development: "G0 NO INICIADO" }
  series:
    BOS-ECO:
      docs_total: 12
      validated: 0
      redacted: [ "000:v1.4", "001:v1.4", "002:v1.0", "003:v1.0", "004:v1.0",
                  "005:v1.0", "006:v1.0", "007:v1.0", "008:v1.0", "010:v1.3" ]
      pending: [ "020", "030" ]
    BOS-bKernel:
      docs_total: 28
      redacted: [ "002:v1.0", "003:v1.0", "004:v1.0", "005:v1.0", "006:v1.0",
                  "007:v1.0", "190:v1.0" ]
      pending: [ "000","001","010","020","030","040","050","060","070","080","090",
                 "100","110","120","130","140","150","160","170","180","200" ]
    BOS-biedata:
      docs_total: 25
      redacted: [ "002:v1.0", "003:v1.0", "004:v1.0", "005:v1.0", "006:v1.0",
                  "007:v1.0", "160:v1.0" ]
      pending: [ "000","001","010","020","030","040","050","060","070","080","090",
                 "100","110","120","130","140","150","170" ]
  development_modules:
    G0: NO_INICIADO
    G1: NO_INICIADO
    G2: NO_INICIADO
    G3: NO_INICIADO
    G4: NO_INICIADO
    G5: NO_INICIADO
  open_conflicts: []          # C-17 VALIDADO (D9); Q-01..Q-05 RESPONDIDAS (D10)
  next_actions:
    - "Validación del arquitecto: Lote 1 + Lote 1-G"
    - "Lote 2: ECO-020 (contrato bK<->bd) y ECO-030 (acoplamiento al bos)"
```

## 3. Reglas de actualización

1. Solo se edita el bloque YAML §2 (y la fecha/sesión). El formato no se altera sin enmienda.
2. Toda transición de estado lleva su evidencia en el plan atómico correspondiente
   (bK-190/bd-160/ECO-008) y su narrativa en ECO-001/ECO-005.
3. Los registros por serie (bK-004, bd-004) detallan módulos y tareas; este global solo
   consolida. Ante divergencia global↔serie: gana el de la serie y se reconcilia aquí.

## 4. Criterios de completitud

- [x] Máquinas de estado canónicas únicas para documento/módulo/tarea/conflicto/sesión.
- [x] YAML parseable con el estado real al día de hoy.
- [ ] Actualizado en el cierre de cada sesión (obligación permanente).
- [ ] Validación del arquitecto.

---
*BOS-ECO-004 v1.0 · 2026-06-10 · Detalle por serie: → bK-004 · → bd-004. Narrativa humana: → ECO-001.*
