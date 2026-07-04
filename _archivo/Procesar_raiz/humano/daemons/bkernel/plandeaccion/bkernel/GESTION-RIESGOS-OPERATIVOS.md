# GESTIÓN DE RIESGOS OPERATIVOS — bKernel
## Matriz de riesgos, mitigaciones y contingencias

**Versión:** 1.0 · **Fecha:** 2026-06-19

---

## Matriz de riesgos

| ID | Riesgo | Probabilidad | Impacto | Nivel | Mitigación | Contingencia |
|----|--------|-------------|---------|-------|------------|--------------|
| R-01 | Rust toolchain no disponible en el entorno de desarrollo | Alta | Bloqueante | 🔴 CRÍTICO | Instalar rustup + cargo + musl target al iniciar G0 | Documentar instalación en INSTRUCCIONES-DE-USO.md |
| R-02 | Slot de replicación WAL no configurable en PostgreSQL de la VPS | Media | Bloqueante | 🟠 ALTO | Verificar `wal_level=logical` en postgresql.conf durante G0 | Crear ficha separada solo para habilitar WAL |
| R-03 | El scaffold Rust existente (edition 2021) requiere refactorización significativa | Alta | Retraso | 🟠 ALTO | Evaluar en G0.E2.T1: decidir entre refactorizar o reescribir | Si refactorizar > 4h, reescribir desde cero con edition 2024 |
| R-04 | bkernel-common acoplado al daemon — rompe al actualizar dependencias | Media | Retraso | 🟡 MEDIO | Mantener bkernel-common como crate separado con tests propios | Si se rompe, merge bkernel-common dentro de BkernelAgent/ |
| R-05 | Redis no accesible desde el daemon (NetworkPolicy) | Media | Bloqueante | 🟠 ALTO | Verificar conectividad Redis en ficha_pre_install (FICHA.T2) | NetworkPolicy específica para bkernel→Redis |
| R-06 | PostgreSQL 18 pgoutput incompatible con la crate tokio-postgres 0.7 | Baja | Bloqueante | 🟡 MEDIO | Verificar compatibilidad en G1.E1.T1 contra PG18 real | Usar pgwire-replication como alternativa |
| R-07 | Binario MUSL > 15MB (gate CI) | Media | Retraso | 🟡 MEDIO | Monitorear tamaño desde G0.E2.T2; LTO + strip symbols | Optimizar dependencias; eliminar crates no esenciales |
| R-08 | Vault Agent sidecar no configurado en el cluster K8s | Alta | Retraso | 🟠 ALTO | En G0.E4.T2, implementar fallback a env var para desarrollo | Documentar claramente que prod REQUIERE Vault sidecar |
| R-09 | Apache AGE no disponible en PostgreSQL 18 | Media | Retraso | 🟡 MEDIO | Verificar disponibilidad durante G3.E1.T1 | Postergar G3 a fase 2; usar JSONB para grafos simples |
| R-10 | CDC lag > 5s bajo carga (viola SLO) | Baja | Degradación | 🟡 MEDIO | Benchmarks en G1.E1.T2 con carga simulada | Aumentar capacity del bounded channel; escalar Workers |

---

## Plan de contingencia por Gate

### G0 — Esqueleto y CI
- **Si Rust no compila:** volver a `rustup default stable` + `cargo clean` + verificar Cargo.toml
- **Si MUSL falla:** usar GNU target temporalmente; abrir issue para MUSL
- **Si el scaffold es insalvable:** reescribir desde `cargo init` con edition 2024

### G1 — CDC
- **Si pgoutput no funciona:** verificar `wal_level=logical` + `pg_hba.conf` + permisos del slot
- **Si Redis no publica:** verificar NetworkPolicy + ClusterIP + auth token

### G2 — Pipeline
- **Si CESQL parser es muy complejo:** reducir subset inicial a AND + comparaciones básicas
- **Si task_catalog.sh falla:** verificar contrato de env vars + exit codes con biedata

### G3 — Contexto
- **Si AGE no está disponible:** usar JSONB + índices GIN para consultas de grafo simples
- **Si Context Plane rompe:** las tablas son idempotentes (IF NOT EXISTS)

### G4 — Protección
- **Si event triggers fallan:** verificar permisos de superuser en PostgreSQL
- **Si OpenLineage collector no responde:** fire-and-forget no bloquea el pipeline

---

## Escalamiento

| Nivel | Condición | Acción |
|-------|-----------|--------|
| 🟢 Normal | Átomo completado sin incidencias | Continuar al siguiente |
| 🟡 Atención | Átomo requiere más tiempo del estimado | Registrar en LOG-DE-SESIONES.md; ajustar estimación |
| 🟠 Alerta | Átomo bloqueado por dependencia externa | Marcar ⚠️ BLOQUEADA en REGISTRO-ESTADO; notificar al sbos-coordinador |
| 🔴 Crítico | Gate completo en riesgo | Convocar revisión de arquitectura; evaluar replanificación |

---
*GESTION-RIESGOS-OPERATIVOS v1.0 · 2026-06-19*
