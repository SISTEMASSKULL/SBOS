# BOS-biedata-160 — PLAN DE IMPLEMENTACIÓN ATÓMICO (nivel micro)

## 0. Metadatos
| Campo | Valor |
|---|---|
| **Documento** | BOS-biedata-160-PLAN-DE-IMPLEMENTACION-ATOMICO · **Versión** 1.0 · **Estado** VIGENTE—REDACTADO, vivo (estado en bd-004) · **Fecha** 2026-06-10 |
| **Fase asociada** | G0–G5 (tablero y gates: → ECO-008) |
| **Fuentes que absorbe** | corpus DAEMON-BIEDATA-00..08 v3.0 (módulos, fronteras F1–F12, fichas system, resiliencia) · rescate V8 SBOS_biedata_FUNCIONALIDADES F-001..F-007 (cajas import/export, file-watch, migración legacy) reencuadrado por D9/D10 |
| **Documentos que supersede** | El alcance "PLAN-Y-GLOSARIO" de bd-160: el glosario se separa a → bd-170 (enmienda R7) |
| **Normas** | ISO/IEC/IEEE 12207:2017 §6.3.1; 15289:2019 cl.10 |

Regla de atomicidad y formato: → ECO-008 §1. Avance por criterio cumplido; evidencia en bd-004.

---

## G0.E3 — Esqueleto del daemon y servidor RPC mínimo

| ID | Tarea atómica | Entregable | Criterio MEDIBLE | Dep. | SSOT |
|---|---|---|---|---|---|
| bd-G0.E3.T1 | Workspace Cargo + módulos stub | repo `biedata/` edition 2024, perfil LTO | `cargo build` y `clippy -D warnings` limpios | — | bd-050 |
| bd-G0.E3.T2 | Build MUSL + budget | target musl | estático; < 15 MB (gate CI) | T1 | C-08 |
| bd-G0.E3.T3 | Servidor HTTP `POST /rpc` (axum) | endpoint único; 404 en cualquier otro path | `common.server.version` responde result; `GET /rpc` y `/api/*` → rechazo correcto (CONF-RPC-02) | T1 | bd-060, ECO-010 §8 |
| bd-G0.E3.T4 | Sobre JSON-RPC perfil SBOS | tipos serde + `validate_sbos_profile` | golden-files de ECO-010 §6 (válidos/ inválidos) 100% | T3 | ECO-010 §12.1 |
| bd-G0.E3.T5 | Errores canónicos | enum/códigos -32700..-32005 | cada capa devuelve SU código exacto (tabla ECO-010 §6.3); HTTP 200 en errores de negocio | T4 | ECO-010, bd-060 §7 |
| bd-G0.E3.T6 | biedata.toml + carga tipada | config ejemplo + validación al boot | config inválida → fallo explícito; test | T1 | bd-050 |
| bd-G0.E3.T7 | :9471 métricas / :9472 health | exporters readonly | curl OK; health enriquecido con estado de pools | T3 | bd-130, D5 |
| bd-G0.E3.T8 | systemd + SIGUSR1 stub | unit Type=notify; handler USR1 (reload fichas stub) | USR1 no interrumpe requests en vuelo (test concurrente) | T3 | bd-150 |
| bd-G0.E3.T9 | CI | build musl+fmt+clippy+test+budget+linter de clientes HTTP no declarados (D9) | verde | T2 | ECO-007/bd-003 |

## G0.E4(bd) — biedata_db núcleo

| ID | Tarea | Entregable | Criterio | Dep. | SSOT |
|---|---|---|---|---|---|
| bd-G0.E4.T1 | Migraciones: `operations` (auditoría) + `_inbox UNIQUE(event_id)` | DDL ejecutable | up/down limpios PG17; UNIQUE verificado por test de duplicado | E3.T1 | bd-100 |
| bd-G0.E4.T2 | Dual-user `biedata_rw`/`biedata_ro` + Vault | roles con GRANTs mínimos | `biedata_ro` no puede escribir (test); rotación en caliente | T1 | bd-110 (F4/F9) |
| bd-G0.E4.T3 | Registro de operación | toda request → fila en operations (method, ctx_id, resultado, duration_ms; jamás payload de negocio) | request de prueba genera registro completo; payload ausente (F2/F6) | T1,E3.T3 | bd-100 |

## G1 — Contrato bilateral (lado biedata; requiere ECO-020 VALIDADO)

| ID | Tarea | Entregable | Criterio | Dep. | SSOT |
|---|---|---|---|---|---|
| bd-G1.E3.T1 | Consumer group Redis Streams | XREADGROUP `biedata-consumers`, BLOCK, manejo de pending | consume del stream del contrato; reconexión automática (test caída Redis) | G0 gate | ECO-020 |
| bd-G1.E3.T2 | Dedup Inbox | inserción `_inbox` por event_id antes de ejecutar | duplicado consumido 2 veces ejecuta 1 (test 20 iteraciones); XACK solo tras commit | T1 | ECO-020, bd-100 |
| bd-G1.E3.T3 | Mapeo intención→ficha | `intent.method` → ficha versionada; -32601 si no existe | intención válida ejecuta; method inexistente queda en operations con error y NACK según contrato | T2 | ECO-020, bd-060 |
| bd-G1.E4.T1 | Ficha inbound mínima + task_catalog.sh | 3 archivos de ejemplo; escritura `origin='biedata'` | fila visible en BD destino fixture con origin correcto; re-ejecución idempotente (UPSERT) | T3 | bd-070 |
| bd-G1.E4.T2 | E2E con bKernel (staging) | suite conjunta | **H1** (definición ECO-008 §2) 10/10 | T1–T4, bK-G1 | ECO-008 |

## G2 — Motor de procesamiento

| ID | Tarea | Entregable | Criterio | Dep. | SSOT |
|---|---|---|---|---|---|
| bd-G2.E3.T1 | Router de métodos completo | resolución `dominio.recurso.accion.vN`; alias→tier del contrato del tenant | alias resuelve según tenant_contracts; tier no contratado → -32002 | G1 | bd-060 |
| bd-G2.E3.T2 | Validation engine | parser validation.yml (types, required, enum, exists_in, min/max, formatos) | suite de reglas del corpus 100%; rechazo con campo/regla/mensaje EXACTOS; BD intacta (F8) | T1 | bd-070 |
| bd-G2.E4.T1 | Pipeline engine | pasos del manifest, input mapping, merge_into context/result, on_error | ficha 5 pasos del corpus reproducida; abort en paso 3 no deja escrituras parciales (F12) | T2 | bd-070 |
| bd-G2.E4.T2 | Delivery engine | 4 modos (json-rpc/transform/document/relay) según `delivery` del caller (F11) | cada modo con test; formato no declarado en manifest → rechazo | T1 | bd-060 §4 |
| bd-G2.E5.T1 | Fichas system | `biedata.describe`, `describe.method`, `dry_run` | describe lista fichas reales desde disco; dry_run NO escribe (verificado) | T2 | bd-070, BIEDATA-08 |
| bd-G2.E5.T2 | Recarga SIGUSR1 real | carga de ficha nueva sin reinicio | ficha añadida en disco + USR1 → method disponible; requests en vuelo intactas | T1 | bd-070 |
| bd-G2.E6.T1 | Tiers/contratos | tabla tenant_contracts + resolución + límites | `bosctl biedata contract set/show` operativo; límite diario excedido → -32003 | T1 | bd-060, BIEDATA-04 §4 |

## G3 — Contexto

| ID | Tarea | Criterio | SSOT |
|---|---|---|---|
| bd-G3.E3.T1 | `_ctx_id` obligatorio + verificación en Registry (Redis DB1) + headers X-SBOS-* | sin ctx_id → -32602; ctx_id inválido → -32001; presente en log JSON y span | bd-110/130, SBOS-049 |

## G4 — Resiliencia, observabilidad y cajas

| ID | Tarea | Criterio | SSOT |
|---|---|---|---|
| bd-G4.E3.T1 | Idempotencia `_idempotency_key` | replay → respuesta cacheada sin re-ejecutar; key reusada con params distintos → conflicto detectado | bd-120 |
| bd-G4.E3.T2 | Saga engine | compensaciones declaradas en manifest, idempotentes; fallo en paso 4/5 compensa 3 (test); estado persistido | bd-120 |
| bd-G4.E4.T1 | Circuit breaker por BD destino | abre al umbral del manifest; half-open recupera; -32000 con retry-after | bd-120 |
| bd-G4.E4.T2 | Catálogo de métricas + alertas + dashboard | métricas method/tier/tenant/pipeline/idempotencia/breaker visibles; alerts.yml carga | bd-130 |
| bd-G4.E5.T1 | Box engine WASM + caja import ejemplo (6 fases) | archivo fixture → UPSERT origin='biedata'; fila inválida = skip_row; corrupto → cuarentena | bd-080 |
| bd-G4.E5.T2 | Caja export de DATOS ejemplo | SELECT-only (F4) → archivo/entrega de datos; jamás diálogo regulado (D9) | bd-080 |
| — | gate | **H4** con suite de caos (caídas Redis/PG/destino) | ECO-008 |

## G5 — Hardening

| ID | Tarea | Criterio | SSOT |
|---|---|---|---|
| bd-G5.E2.T1 | Límites (max_body, timeouts por ficha) + rate | -32005/-32003 correctos bajo carga | bd-060 §9 |
| bd-G5.E2.T2 | Fuzzing del endpoint + revisión 4 capas | cero pánico del proceso en 1M casos | bd-110 |

## Criterios de completitud del documento
- [x] G0–G2 a nivel tarea atómica completa; G3–G5 a nivel tarea con criterio clave (micro-detalle al VALIDARSE sus SSOT — gates ECO-008 §3).
- [x] Derivado del corpus v3.0 + rescate V8 reencuadrado por D9/D10 (cajas = intercambio de DATOS).
- [x] Glosario separado a bd-170 (enmienda R7 registrada).
- [ ] Paridad con ECO-008 y bd-004. · [ ] Validación del arquitecto.

---
*bd-160 v1.0 · tablero/gates: → ECO-008 · estado: → bd-004 · glosario: → bd-170*
