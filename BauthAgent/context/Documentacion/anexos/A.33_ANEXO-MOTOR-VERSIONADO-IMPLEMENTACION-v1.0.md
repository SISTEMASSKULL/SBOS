# Anexo A.33 — El Motor de Versionado Universal: estado de implementación (L1)
## Documento de respaldo de sustentación (tipo D)

**Versión:** 1.0.0 · **Fecha:** 2026-07-11 · **Respalda a:** MANUAL-MOTOR-VERSIONADO (1.13) · A.27 (WORM compartido)
**Verificación de código:** búsqueda `ver_history`/`ver_proposal`/`versioning` en `DDLs/` y `src/` — leída 2026-07-11
**Normas:** SQL:2011 · las de 1.13 §4

## 1. El estado real — L1 (diseñado, sin código)
El manual 1.13 declara honestamente el motor en **L1**. Verificación: **0 implementación** —
no existen `ver_history`, `ver_proposal`, `ver_retention_schedule` en el DDL, ni
`src/domain/versioning/` en el código. Es el estado correcto declarado: especificación completa,
materialización pendiente (fases F2–F5).

## 2. La ruta de materialización (F2–F5 de 1.13 §15)
| Fase | Entregable | Depende de |
|---|---|---|
| F2 | `bauth_45` (núcleo) + `bauth_46` (ver_history con WITHOUT OVERLAPS PG18) | **`bauth_44` WORM aplicado** (A.27-AU2) — el motor reutiliza `fn_worm_hash_chain` |
| F3 | `src/domain/versioning/` + handlers `bauth.version.*` | F2 |
| F4 | Retención (job) | F3 |
| F5 | Extensión a todas las entidades C1 | F4 |

## 3. Lo que FALTA — todo (es L1) — con la dependencia crítica
| # | Brecha | Prioridad |
|---|---|:---:|
| VM1 | **F2 sustrato** — bloqueado por `bauth_44` sin aplicar (A.27-AU2) | P1 (tras AU2) |
| VM2 | F3 motor Rust | P1 |
| VM3 | F4 retención | P2 |
| VM4 | F5 extensión | P2 |

## 4. Verificación de completitud
Motor 📐 L1 (especificado, 0 código) — coherente con 1.13. Este anexo es el que se irá
actualizando conforme F2–F5 avancen (verificación de implementación contra la especificación).

| Ver. | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-11 | Motor de Versionado: L1 confirmado (0 implementación: ni ver_history en DDL ni versioning/ en código — estado correcto declarado por 1.13). Ruta F2–F5 con la dependencia crítica: F2 bloqueado por bauth_44 WORM sin aplicar (A.27-AU2). Anexo vivo para verificar la implementación futura. |
