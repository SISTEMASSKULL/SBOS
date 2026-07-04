# BOS-biedata-004 — REGISTRO DE ESTADO DE LA SERIE Y SUS MÓDULOS

## 0. Metadatos
| **Documento** | BOS-biedata-004 · **Versión** 1.0 · **Estado** VIGENTE—vivo · **Fecha** 2026-06-10 |
|---|---|
| **Serie** | BOS-biedata — formato/máquinas de estado: → ECO-004 §1 (mandan) |

## 1. Estado (YAML canónico de la serie)
```yaml
biedata_state:
  schema_version: 1
  updated: "2026-06-10"
  updated_by_session: "S-007"
  docs:
    redacted: ["002:v1.0","003:v1.0","004:v1.0","005:v1.0","006:v1.0","007:v1.0","160:v1.0"]
    pending:  ["000","001","010","020","030","040","050","060","070","080","090",
               "100","110","120","130","140","150","170"]
  modules:
    esqueleto_rpc_ci:   { fase: G0, estado: NO_INICIADO }   # servidor /rpc mínimo
    biedata_db_core:    { fase: G0, estado: NO_INICIADO }   # operations + _inbox
    inbox_consumer:     { fase: G1, estado: NO_INICIADO }
    ejecutor_minimo:    { fase: G1, estado: NO_INICIADO }
    router_validation:  { fase: G2, estado: NO_INICIADO }
    pipeline_fichas:    { fase: G2, estado: NO_INICIADO }
    delivery_engine:    { fase: G2, estado: NO_INICIADO }
    tiers_contratos:    { fase: G2, estado: NO_INICIADO }
    ctx_id:             { fase: G3, estado: NO_INICIADO }
    idempotencia_saga:  { fase: G4, estado: NO_INICIADO }
    circuit_breaker:    { fase: G4, estado: NO_INICIADO }
    observabilidad:     { fase: G4, estado: NO_INICIADO }
    cajas_wasm:         { fase: G4, estado: NO_INICIADO }   # import/export por datos
    hardening:          { fase: G5, estado: NO_INICIADO }
  tareas: {}     # se puebla desde bd-160: id -> {estado, evidencia}
  next: "primera tarea de código: bd-G0.E3.T1 (tras gates)"
```

## 2. Reglas
Como ECO-004 §3: solo YAML; evidencia por transición; ante divergencia gana este registro.

## Criterios de completitud
- [x] YAML parseable con los módulos reales G0–G5. · [ ] Mantenimiento por sesión · [ ] Validación.

---
*bd-004 v1.0 · maestro: → ECO-004*
