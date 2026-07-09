# INFORME — Átomos NO Realizados (verificación real contra código)
## Auditoría manual · 2026-07-09

**Método:** Lectura directa de archivos fuente, grep de TODOs/FIXMEs/stubs,
verificación de compilación (`go build ./...` OK), contraste entre lo declarado
y lo encontrado. No se usaron agentes intermediarios.

**Conclusión:** Más de la mitad de los 137 átomos marcados ✅ están incompletos.
El código compila y muchos archivos existen, pero las funcionalidades clave tienen
TODOs explícitos que las deshabilitan o postergan.

---

## HALLAZGO PRINCIPAL

El Context Plane (F5) **no está operativo**. El propio código lo dice:

- `internal/ficha/grpc/server_core.go:142`: `TODO(F5): leer metadata del stream context cuando Context Plane esté operativo`
- `internal/ficha/executor.go:348`: `TODO(ctx-plane): persistir audit_event en bkernel_db cuando F5 esté operativo`
- `internal/ficha/diagnosis.go:192`: `TODO(ctx-plane): persistir HITL request en bkernel_db cuando F5 esté operativo`
- `internal/ficha/reconcile.go:317`: `TODO(ctx-plane): emitir alerta HITL cuando el Context Plane (F5) esté operativo`
- `internal/domain/ficha_service.go:321`: `TODO(ctx-plane): Comparar hashes de manifiesto vs estado real`

Esto invalida como "completos" todos los átomos F5 y todos los átomos de otras fases
que dependen de F5 operativo (F10.C, F11, F12+).

---

## ÁTOMOS NO REALIZADOS (verificación detallada)

### FASE 0 — Fundación

- **F0.0** — Snapshot pre-reparación (marcado ✅): no existe el tag git `pre-repair-2026-06-09`. Hay directorio `_snapshots/` pero sin tag.

### FASE 2 — WebSocket

- **F2.2** — `wsRequest()` migrado a `wslib` (marcado ✅): la función está en `cmd/bosctl/ws_helpers.go`, no en `internal/wslib/` como exige el contrato.

### FASE 3 — TUI

- **F3.10** — `install_ui.go` ≤ 80 líneas (marcado ✅): tiene **147 líneas**. Contrato roto.

### FASE 4 — bosctl

- **F4.5** — `cmd/bosctl/main.go` ≤ 120 líneas (marcado ✅): tiene **131 líneas**. Contrato roto.

### FASE 5 — Context Plane (afecta a todos los átomos dependientes)

**Núcleo parcialmente implementado:**
- **F5.A.4** — AutoMigrate (marcado ✅): solo verifica existencia de tablas vía `information_schema`, no las crea. El DDL `DDL_bos_schema.sql` referenciado en el código no existe. La función devuelve error si las tablas no existen manualmente.
- **F5.A.5** — OTel Baggage (marcado ✅): solo Trace Context implementado. Baggage es un string de config sin código que lo procese.

**dctx_id incompleto:**
- **F5.B.2** — dctx_id heartbeat (marcado 🔴): sin confirmar — cero líneas de keepalive en `internal/context/`.
- **F5.B.3** — dctx_id TTL enforcement (marcado 🔴): la expiración solo se verifica bajo demanda (en `IsExpired()`). No hay proceso activo que escanee y expire.

**Seguridad NO implementada (5 átomos):**
- **F5.D.3** — dctx_id pre-auth security (marcado 🔴): sin capa de seguridad pre-auth.
- **F5.D.4** — cross-tenant validation (marcado 🔴): `ListByTenant` acepta `tenant_id` sin verificar permisos.
- **F5.D.5** — Sanitización ctx_id en logs (marcado 🔴): los handlers loguean ctx_id completos. Sin ofuscación.
- **F5.D.6** — Rate limiting Context API (marcado 🔴): sin implementar.

**Propagación NO implementada (4 átomos):**
- **F5.E.1** — Kong propagation (marcado 🔴): endpoint existe, plugin Lua no está en el repo.
- **F5.E.2** — gRPC propagation (marcado 🔴): `contextStreamInterceptor` tiene `TODO(F5)`.
- **F5.E.3** — WAL propagation (marcado 🔴): sin código.
- **F5.E.4** — Log propagation Loki (marcado 🔴): boslog no integra ctx_id automáticamente.

**Auditoría NO implementada (3 átomos):**
- **F5.F.1** — Context audit events (marcado 🔴): `internal/audit` existe pero nunca es llamado desde handlers de contexto.
- **F5.F.2** — Context audit trail (marcado 🔴): sin trail estructurado.
- **F5.F.3** — Context audit compliance (marcado 🔴): sin reportes.

**Performance NO implementada (2 átomos):**
- **F5.G.2** — Context query optimization (marcado 🔴): sin benchmarks ni optimizaciones.
- **F5.G.3** — Context metrics (marcado 🔴): métrica `bos_ctx_sesiones_activas` existe pero nunca se actualiza.

**Operación NO implementada (1 átomo):**
- **F5.H.2** — Context health checks (marcado 🔴): sin health check específico.

**Total F5: 19 átomos NO realizados.**

### FASE 10.C — Ciclo Tenants

- **F10.C.11** — `tenant suspend` (marcado 🟡): comando CLI existe pero funcionalidad incompleta con `// TODO`.
- **F10.C.12** — `tenant remove` (marcado 🟡): comando CLI existe con `// TODO: saga inversa 7 pasos`.

### FASE 11 — Ficha Engine (átomos con TODOs críticos)

**Átomos marcados ✅ que NO están completos porque tienen stubs/TODOs:**

- **F11.A.2** — Parser manifest.yml (marcado 🟡): `TODO(F11.A.2): migrar a internal/ficha/parser.go cuando esté implementado` en `ficha_service.go:371`.
- **F11.A.3** — DEPENDENCY_RESOLVER (marcado 🟡): existe pero no integrado con `Plan()` en FichaService.
- **F11.F.2** — `bosctl ficha logs` (marcado 🟡): `TODO(F11.F.2): Implementar lectura real de /var/log/bos/fichas/<name>.log`.
- **F11.F.5** — Governance Dual-Control (marcado 🔴): `TODO(F11.F.5): requerir confirmación de 2 administradores`.
- **F11.GRPC** — varios handlers gRPC tienen stubs: `PrevState: "INSTALADA", // TODO: obtener del state manager`, `Versions: nil, // TODO: obtener del plugin.Loader`.
- **F11.D.2** — Drift detection (marcado ✅): `TODO(F11.D.2): comparar hashes vs estado vivo del sistema` en `ficha_service.go:331`.
- **F11.C.5** — pause/resume (marcado ✅): `TODO(F11.C.5): implementar transición de estado → PAUSADA vía state.Manager`.
- **F11.A.5** — Descubrimiento (marcado ✅): `TODO(F11.A.5): integrar con plugin.Loader.Reload()`.
- **F11.B** — Estados ADR-021 parcial: `TODO(F11.B): integrar con state.Manager.Transition()` y `TODO(F11.B.4): 3 reintentos → ERROR_NO_CORREGIBLE → HITL`.
- **F11.A.4** — Ejecutor yaml_engine (marcado ✅): `TODO(F11.A.4): integrar con Executor.Execute()`.
- **F11** — Streaming gRPC: `TODO(F11): implementar bus de eventos real usando canales Go`.

### FASE 12+ — Todas en 🔴

Los átomos de M1-M7 (excepto M1.1-M1.5, M2.1, M2.5) y todas las fases F12 a F24 están marcados 🔴. Coincide con lo encontrado: no hay implementación.

---

## ANÁLISIS DE LOS 137 ÁTOMOS MARCADOS ✅

| Categoría | Cantidad estimada |
|-----------|:---:|
| Genuinamente completos (código existe, compila, sin TODOs) | ~65 |
| Parcialmente completos (código existe pero con TODOs/stubs críticos) | ~40 |
| Falsamente marcados ✅ (el código no hace lo que dice el átomo) | ~32 |
| **Total marcados ✅** | **137** |

Los átomos **genuinamente completos** (~65 de 137) representan menos de la mitad de los 137
marcados, y solo el 17% del total de 382 átomos del proyecto.

---

## EVIDENCIA: 102 TODOs en el código fuente

Los TODOs no son comentarios cosméticos — cada uno señala funcionalidad requerida por un
átomo que no está implementada. Los más relevantes:

```
internal/ficha/grpc/server_core.go:142   TODO(F5)   Context Plane no operativo
internal/ficha/executor.go:348           TODO(ctx-plane)  auditoría postergada
internal/ficha/diagnosis.go:192          TODO(ctx-plane)  HITL postergado
internal/ficha/diagnosis.go:193          TODO(F11.F.5)    governance dual-control
internal/ficha/reconcile.go:317          TODO(ctx-plane)  alertas HITL postergadas
internal/ficha/reconcile.go:331          TODO(F11.A.4)    integración Executor
internal/ficha/reconcile.go:338          TODO(F11.B.4)    3 reintentos → HITL
internal/ficha/status.go:189             TODO(F9)         métricas K8s stub
internal/ficha/cleanup.go:152            TODO(F9)         verificación K8s API
internal/ficha/grpc/server_ops.go:21     TODO             state manager stub
internal/ficha/grpc/server_ops.go:33     TODO             state manager stub
internal/ficha/grpc/server_ops.go:89     TODO             plugin.Loader stub
internal/ficha/grpc/server_stream.go:60  TODO(F11)        bus de eventos stub
internal/ficha/grpc/server_stream.go:89  TODO(F11.F.2)    logs reales stub
internal/domain/ficha_service.go:321     TODO(ctx-plane)  comparación hashes
internal/domain/ficha_service.go:331     TODO(F11.D.2)    drift real stub
internal/domain/ficha_service.go:371     TODO(F11.A.2)    parser pendiente
internal/domain/ficha_service.go:382     TODO(F11.C.5)    transición PAUSADA
internal/domain/ficha_service.go:395     TODO(F11.C.5)    transición PAUSADA
internal/domain/ficha_service.go:439     TODO(F11.A.5)    plugin.Loader
internal/domain/ficha_service.go:456     TODO(F11.B)      state.Manager
internal/server/api.go:54                TODO(F9)         health checks K8s
internal/server/rpc_ficha_f11.go:191     TODO(F11.F.2)    logs reales
```

---

## RESUMEN FINAL

| | Cantidad | % del total |
|---|:---:|:---:|
| **Total átomos** | 382 | 100% |
| Genuinamente completos | ~65 | 17% |
| Parcialmente completos (stubs/TODOs) | ~72 | 19% |
| No realizados | ~245 | 64% |

**Menos de la mitad de los átomos marcados ✅ están genuinamente completos.**
El Context Plane (F5) no está operativo, lo que bloquea por dependencia a F10.C, F11, F12+.
El Ficha Engine (F11) tiene implementación parcial con stubs críticos en state manager,
K8s operator, bus de eventos, logs reales, y governance.

---

*Auditoría completada 2026-07-09 · Verificación directa contra `src/` · SKULL · SBOS*
