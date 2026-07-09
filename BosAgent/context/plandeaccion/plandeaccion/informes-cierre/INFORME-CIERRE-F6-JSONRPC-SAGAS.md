# INFORME DE CIERRE — FASE 6: JSON-RPC Robusto + 6 Sagas de Consulta
## BOS-REPAIR · SKULL · SBOS · 2026-06-10

**Agente:** Claude Fable 5
**Operador:** skull
**Átomos:** F6.1–F6.11 (11/11 ✅)
**Commits:** 1353aba → 4175aff (12 commits, uno por átomo + endurecimiento de tests)
**Base normativa:** BOS-REPAIR-04, BOS-REPAIR-12, Manual JSON-RPC Partes 1-9

---

## Resumen ejecutivo

La Fase 6 convierte el servidor JSON-RPC del bos de un dispatcher básico a un
plano de invocación robusto: autenticación en métodos destructivos, timeouts
por categoría, batch paralelo, saneamiento de información sensible, validación
TTL del Context Plane, y las 6 sagas de consulta multi-fuente que son
prerequisito directo de biaos (F10) y del watchdog con pre-diagnóstico.

## Qué se construyó

### Bloque 1 — Robustez del protocolo (F6.1–F6.5)

| Átomo | Entregable | Commit |
|---|---|---|
| F6.1 | `internal/server/auth.go` — `Authorization: Basic base64(user:id:token)` (manual §3), set `destructiveMethods` deny-by-default, token compartido opcional `/etc/bos/rpc-token` (comparación tiempo constante), RBAC `CanExecute`. Sin token → **-32600**; RBAC niega → -32005. `bosctl rpc` envía credenciales desde `BOS_RPC_TOKEN`/archivo. | 1353aba |
| F6.2 | `internal/server/timeout.go` — categorías lectura 5s / escritura 30s / saga 600s; `runWithTimeout` en dispatcher → **-32006 ErrTimeout**; clasificación deny-by-default a lectura (la más restrictiva). | 9a6a301 |
| F6.3 | `dispatchBatch` — goroutine por solicitud del batch, escritura por índice (sin memoria compartida), orden preservado, notificaciones omitidas (spec §6). | 44ddd2b |
| F6.4 | `fichaPublica` DTO — `bos.state.read` ya no expone los SHA-256 internos de reconciliación (anti-fingerprinting). | ee4dfbb |
| F6.5 | `ErrContextExpired = -32001` (mandato del plan; `ErrFichaNotFound` reubicado a **-32010**). `ctx.get`/`ctx.switch` rechazan sesiones con TTL vencido (ISO 27001 A.9.4.2). | 66f26b3 |

### Bloque 2 — Sagas de consulta (F6.6–F6.11)

Paquete nuevo **`internal/query/`**: motor `Run()` paralelo (goroutine por
fuente, deadline interno 4s, degradación elegante `{"error": …}` por clave,
`timestamp` + `duration_ms` siempre), semáforo VERDE/AMARILLO/ROJO con fuentes
críticas, fuente Ubuntu real (/proc + statfs, sin exec salvo systemctl) y
fuentes kubectl que degradan sin cluster.

| Saga | Fuentes paralelas | Commit |
|---|---|---|
| `bos.query.system` | ubuntu + kubernetes + fichas + context_plane + certificación C-01..C-08 + semáforo | b65bfd9 |
| `bos.query.repair` | estado + diagnóstico (causa probable de los 18 estados ADR-021 + logs pod) + impacto (dependientes del manifest + ctx activos) + recomendación | e60a7e0 |
| `bos.query.vdi` | nextcloud + guacamole + fedora-logico + context_plane_vdi + semaforo_vdi | c00ba6d |
| `bos.query.tenant` | identidad + infraestructura + contexto (todas las sesiones del tenant, aislamiento verificado) | 239d6c7 |
| `bos.query.node` | k8s + ubuntu + pods del nodo + impacto_si_se_drena (críticas reales, advertencia single-node) | 91ef889 |
| `bos.query.context` | distribución de estados + anomalías (sin BitMask, expirados no invalidados) + TTLs restantes | 1c9cc09 |

## Decisiones técnicas no obvias

1. **Reasignación -32001:** el plan manda `ContextExpired = -32001` pero ese
   código era `ErrFichaNotFound`. Se reubicó FichaNotFound a -32010. Riesgo
   bajo: no hay clientes externos integrados aún (biedata llega post-F10).
2. **Token compartido en Fase A:** sin bAuth operativo, la validación real es
   archivo `/etc/bos/rpc-token` (si existe) + RBAC + Unix socket 0660. La
   validación criptográfica delega a Fase B (BauthRBAC). Documentado en auth.go.
3. **`ListAllByTenant` nuevo en `context.Service`:** `ListByTenant` filtra solo
   activas vigentes (operativo); el diagnóstico de F6.11 necesita también las
   terminales para la distribución de estados y anomalías.
4. **Fuentes K8s/Keycloak/audit degradan:** el patrón BOS-REPAIR-04 contempla
   `{"error": …}` por fuente. Las claves quedan en el contrato y F7/F9
   conectarán los subsistemas reales sin cambiar la API.
5. **Tests de tiempo endurecidos (4175aff):** dos fallos intermitentes únicos
   bajo `-race` + suite multi-paquete. El SLO se valida ahora con
   `duration_ms` del motor (lo que el deadline garantiza) y el paralelismo del
   batch con señal/ruido 3×200ms vs serie 600ms (umbral 450ms).

## DoD verificado al cierre

```
go build ./...                         ✅
go vet ./...                           ✅
gofmt (sin _legacy)                    ✅ 0 archivos
go test -race -count=2 ./...           ✅ 16 paquetes, 0 FAIL
Sagas registradas (rpcRegistry)        ✅ 6/6 + system.listMethods las publica
Señal de retoma F6                     ✅ bos.query.system en jsonrpc.go
internal/query/query_test.go           ✅ existe (BOS-REPAIR-12 §6.3)
```

## Deuda explícita trasladada (no errores — conexiones futuras)

- `bosctl query <tipo>` (CLI dedicada) — BOS-REPAIR-04 la lista como F6.13 de
  su numeración; las sagas ya son invocables vía `bosctl rpc bos.query.*`.
  Candidata a F7/F9 junto con `cmd/bosctl/README.md`.
- Watchdog pre-diagnóstico (F6.14 de BOS-REPAIR-04) — requiere refactor del
  watchdog para inyectar el query service; planificado con F9 (scaler).
- Fuentes Keycloak/Nextcloud/audit en sagas — degradan documentadamente hasta
  F7 (audit reader) y F9 (clientes).

## Estado del plan

**54/89 átomos** (F0–F6 completas). Próxima fase recomendada: **F7**
(documentación/runbooks, paralela) o **F8** (tests y cobertura — T8.5 ya
parcialmente cubierto por los tests de F6).

---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*
*Co-Autor (IA): Claude Fable 5 — Anthropic*
