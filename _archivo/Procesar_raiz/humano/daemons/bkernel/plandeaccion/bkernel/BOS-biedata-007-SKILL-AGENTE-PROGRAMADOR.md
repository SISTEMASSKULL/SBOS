# BOS-biedata-007 — SKILL ESPECÍFICO DEL PROGRAMADOR biedata

## 0. Metadatos
| **Documento** | BOS-biedata-007 · **Versión** 1.0 · **Estado** VIGENTE—REDACTADO · **Fecha** 2026-06-10 |
|---|---|
| **Serie** | BOS-biedata — se carga JUNTO a → ECO-007 (maestro, manda) |

## SKILL — específico biedata (añadir al maestro)

### Naturaleza del binario
Motor genérico de ejecución e intercambio de datos. UN endpoint de servicio:
`POST /rpc` en :9470 (JSON-RPC 2.0 exclusivo, perfil ECO-010 §6 con extensión `delivery`).
:9471 métricas, :9472 healthcheck enriquecido. Recarga de fichas por SIGUSR1 sin reinicio.
Caja cerrada (D9): consumo y emisión de DATOS; cero diálogo API exterior regulado.

### Módulos (SSOT: bd-050; del corpus v3.0)
servidor HTTP (axum+tokio) · router de métodos (`method_rpc`→ficha versionada `.vN`;
alias sin sufijo → tier del contrato del tenant) · validation engine (validation.yml →
-32602 con detalle campo/regla/mensaje) · pipeline engine (pasos del manifest, merge_into
context/result, on_error abort|log_and_continue) · delivery engine (json-rpc | transform
| document | relay) · fichas system (`biedata.describe`, `biedata.describe.method`,
`biedata.health`, `dry_run`) · inbox consumer (XREADGROUP, `_inbox UNIQUE(event_id)`,
XACK) · idempotencia (`_idempotency_key`, TTL, conflicto=bug del caller) · saga engine
(compensaciones declarativas, idempotentes) · circuit breaker por BD destino · cajas
WASM (6 fases: prepare/read/transform/validate/write|deliver/finalize; calamine;
cuarentena; skip_row por fila).

### Reglas de código específicas
- Las 4 capas del protocolo en orden estricto (Content-Type → sintaxis → authz/BitMask →
  validation.yml); si una falla, el pipeline NO se ejecuta. Tabla de errores: ECO-010 §6.3.
- `origin='biedata'` en TODA escritura de negocio (F3) — assert en la capa de acceso a datos.
- Dual-user PG: `biedata_rw` (tablas autorizadas) / `biedata_ro` (outbound SELECT-only, F4).
- Pipeline enriquece en memoria; sin escrituras intermedias parciales (F12) — la
  persistencia ocurre en el paso que el manifest declara.
- biedata_db: solo operations/auditoría/_inbox/idempotency/sagas/tenant_contracts (F2).
- Respuesta SIEMPRE consistente (result XOR error, estructura de bd-060 §8); HTTP 200
  para errores de negocio.
- Métricas con dimensiones method/tier/tenant/resultado (catálogo bd-130); ctx_id en
  TODO log JSON y span; sampling 100% en operaciones marcadas críticas por la ficha.
- Tests por ficha: happy / rechazo de aduana (BD intacta) / idempotencia / compensación.

### Fixtures (D10)
Fichas y cajas de ejemplo bajo `fichas/test/`; apps reales solo como nombre ilustrativo.

## Criterios de completitud
- [x] Específicos: endpoint único, módulos v3.0, 4 capas, F2/F3/F4/F8/F12, cajas, fixtures. · [ ] Validación.

---
*bd-007 v1.0 · maestro: → ECO-007*
