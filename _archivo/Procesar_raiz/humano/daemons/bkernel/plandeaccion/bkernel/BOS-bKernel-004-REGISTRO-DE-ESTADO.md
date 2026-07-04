# BOS-bKernel-004 — REGISTRO DE ESTADO DE LA SERIE Y SUS MÓDULOS

## 0. Metadatos
| Campo | Valor |
|---|---|
| **Documento** | BOS-bKernel-004 · **Versión** 1.0 · **Estado** VIGENTE—vivo (actualizar en cada cierre) · **Fecha** 2026-06-10 |
| **Serie** | BOS-bKernel — formato y máquinas de estado: → ECO-004 §1 (mandan) |

## 1. Estado (YAML canónico de la serie)
```yaml
bkernel_state:
  schema_version: 1
  updated: "2026-06-10"
  updated_by_session: "S-007"
  docs:
    redacted: ["002:v1.0","003:v1.0","004:v1.0","005:v1.0","006:v1.0","007:v1.0","190:v1.0"]
    pending:  ["000","001","010","020","030","040","050","060","070","080","090",
               "100","110","120","130","140","150","160","170","180","200"]
  modules:                # ESPECIFICADO -> EN-DESARROLLO -> IMPLEMENTADO -> VERIFICADO
    esqueleto_ci:   { fase: G0, estado: NO_INICIADO }
    mod_cdc:        { fase: G1, estado: NO_INICIADO }
    outbox_streams: { fase: G1, estado: NO_INICIADO }
    anti_loop:      { fase: G1, estado: NO_INICIADO }
    dest_registry:  { fase: G2, estado: NO_INICIADO }
    cesql_engine:   { fase: G2, estado: NO_INICIADO }
    mod_graph_age:  { fase: G3, estado: NO_INICIADO }
    mod_enricher:   { fase: G3, estado: NO_INICIADO }
    ddl_guardian_v2:{ fase: G4, estado: NO_INICIADO }
    mod_lineage:    { fase: G4, estado: NO_INICIADO }
    coordinator:    { fase: G5, estado: NO_INICIADO }
  tareas: {}              # se puebla desde bK-190 al iniciar G0.E2: id -> {estado, evidencia}
  next: "esperar validación H0/gates; primera tarea de código: bK-G0.E2.T1"
```

## 2. Reglas
1. Solo se edita el YAML; evidencia obligatoria por transición (comando+salida o ruta de artefacto).
2. Divergencia con ECO-004: gana este registro; reconciliar en la misma sesión.

## Criterios de completitud
- [x] YAML parseable con módulos G0–G5 reales del plan. · [ ] Mantenimiento por sesión · [ ] Validación.

---
*bK-004 v1.0 · maestro: → ECO-004*
