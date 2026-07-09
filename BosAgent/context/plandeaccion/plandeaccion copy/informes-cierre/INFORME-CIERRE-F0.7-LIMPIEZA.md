# INFORME DE CIERRE — Átomo F0.7
## Limpieza pre-reparación: archivar residuos a `_legacy/`

**Fecha:** 2026-06-09  
**Estado:** ✅ COMPLETO  
**Commit BosAgent/src:** pendiente (ver sección de commits)  
**Commit context/sbos:** pendiente  
**Ejecutado por:** Claude Sonnet 4.6 — Anthropic (Co-Autor)  

---

## Resumen ejecutivo

Se archivaron 7 paquetes/archivos con código residual no documentado a `_legacy/`.
Los originales permanecen en `internal/` (build verde). Las copias son referencia
de lógica **únicamente** — el agente implementador construirá desde cero usando
los `doc.go` de cada nuevo paquete como contrato irrenunciable.

**Motivación:** Sin esta limpieza, al llegar a F9/F10, el agente encontraría código
sin documentación ADR-003, sin modularización correcta, que podría "refactorizar"
en lugar de construir nuevo. Esto reproduciría los mismos problemas que BOS-REPAIR
intenta corregir.

---

## ⛔ Advertencia central

**El código en `_legacy/2026-06-09_F0.7_*/` es SOLO referencia de lógica.**  
No se copia. No se refactoriza. No se importa desde Go.  
Cada directorio tiene un `LEEME-ADVERTENCIA.md` con las reglas completas.

---

## Inventario de archivos archivados

### 1. `_legacy/2026-06-09_F0.7_ai/`
**Origen:** `internal/ai/` (3 archivos)  
**Fase que elimina original:** F10.2  
**Nuevo paquete:** `internal/biaos/`

| Archivo | Lógica a entender (no copiar) |
|---|---|
| `client.go` | Circuit breaker 3-tiers: Anthropic → Ollama → OpenAI |
| `model_router.go` | Selección de modelo según tipo de tarea |
| `context_builder.go` | Construcción de system prompt + historial + herramientas |

**Por qué se archivó:** Usa `net/http` directamente (viola SBOS-050 P9). Sin ctx_id.
Sin integración al action_catalog. Sin Unix socket.

---

### 2. `_legacy/2026-06-09_F0.7_observability/`
**Origen:** `internal/observability/` (2 archivos)  
**Fase que elimina original:** F9.6  
**Nuevo paquete:** `internal/metrics/`

| Archivo | Lógica a entender (no copiar) |
|---|---|
| `health_report.go` | Estructura HealthReport por capas (Ubuntu → K8s → BOS) |
| `top.go` | Muestreo de CPU/memoria de pods |

**Por qué se archivó:** No sigue el patrón Prometheus (expone structs propios).
No tiene doc.go ADR-003. Mezcla responsabilidades de reporte y recolección.

---

### 3. `_legacy/2026-06-09_F0.7_repair/`
**Origen:** `internal/repair/` (4 archivos)  
**Fase que elimina original:** F9.3-F9.4  
**Nuevo paquete:** `internal/scaler/` + `internal/maintenance/`

| Archivo | Lógica a entender (no copiar) |
|---|---|
| `repair_manager.go` | Flujo multi-fase: detección → diagnóstico → reparación → verificación |
| `os_repair.go` | Estrategias de reparación SO: apt, systemctl, network |
| `k8s_node_repair.go` | Cordon/drain/uncordon de nodos |
| `health_verifier.go` | Criterios de verificación post-reparación |

**Por qué se archivó:** Sin doc.go ADR-003. Mezcla scaler con maintenance.
Sin sagas compensadas (si el repair falla a mitad, no hay rollback).
Sin mutex — race condition P6/P14 documentada en `internal/observer/doc.go`.

---

### 4. `_legacy/2026-06-09_F0.7_server_api.go`
**Origen:** `internal/server/api.go`  
**Fase que elimina original:** F2 (unificación WebSocket)  
**Nuevo paquete:** `internal/server/ws.go` extendido

**Lógica a entender:** Handlers REST existentes. Al migrar a F2, estos handlers
se convierten a WebSocket RPC. La firma del handler cambia pero la lógica de
negocio subyacente puede preservarse.

**Por qué se archivó:** Expone HTTP REST (viola SBOS-050 P9). Sin ctx_id.
Sin autenticación en métodos destructivos.

---

### 5. `_legacy/2026-06-09_F0.7_server_bootstrap.go`
**Origen:** `internal/server/bootstrap.go`  
**Fase que elimina original:** F1.2  
**Nuevo paquete:** `internal/bootstrap/`

**Lógica a entender:** Handlers del servidor para operaciones de bootstrap.
La lógica de orquestación de capas puede ser referencia para `internal/bootstrap/setup.go`.

**Por qué se archivó:** Mezclado en la capa servidor. Sin separación
domain/transport. Sin timeout por criterio (C-01..C-08).

---

### 6. `_legacy/2026-06-09_F0.7_security_rbac_provider.go`
**Origen:** `internal/security/rbac_provider.go`  
**Fase que elimina original:** F4.4 (ADR-006 — bAuth asume RBAC)  
**Nuevo paquete:** bAuth (daemon externo)

**Lógica a entender:** Roles canónicos: admin/operator/readonly. Los 3 roles
serán replicados en bAuth con BitMask 64-bit (SBOS-021-DAEMON-BAUTH).

**Por qué se archivó:** BOS no debe gestionar RBAC (ADR-006). Esta responsabilidad
pertenece a bAuth. Mantenerlo aquí duplica lógica y genera divergencia.

---

### 7. `_legacy/2026-06-09_F0.7_security_identity_provider.go`
**Origen:** `internal/security/identity_provider.go`  
**Fase que elimina original:** F4.4  
**Nuevo paquete:** bAuth (daemon externo)

**Lógica a entender:** Interface IdentityProvider. El nuevo contrato será el
Unix socket `/run/bos/bauth.sock` con JSON-RPC 2.0 (ADR-019, ADR-020).

**Por qué se archivó:** Misma razón que rbac_provider.go — responsabilidad de bAuth.

---

## Estado post-cierre

### Build
```
go build ./...  →  ✅ OK (originales siguen presentes)
go vet ./...    →  ✅ OK
```

### Estructura _legacy/ resultante
```
_legacy/
├── README.md                                    ← índice actualizado con F0.7
├── 2026-06-09_F0.7_ai/
│   ├── LEEME-ADVERTENCIA.md                    ← ⛔ Solo referencia de lógica
│   ├── client.go
│   ├── model_router.go
│   └── context_builder.go
├── 2026-06-09_F0.7_observability/
│   ├── LEEME-ADVERTENCIA.md
│   ├── health_report.go
│   └── top.go
├── 2026-06-09_F0.7_repair/
│   ├── LEEME-ADVERTENCIA.md
│   ├── repair_manager.go
│   ├── os_repair.go
│   ├── k8s_node_repair.go
│   └── health_verifier.go
├── 2026-06-09_F0.7_server_api.go
├── 2026-06-09_F0.7_server_bootstrap.go
├── 2026-06-09_F0.7_security_rbac_provider.go
└── 2026-06-09_F0.7_security_identity_provider.go
```

---

## Documentos actualizados en este cierre

| Documento | Qué se actualizó |
|---|---|
| `_legacy/README.md` | Índice de F0.7 con 7 entradas + regla de oro |
| `REGISTRO-ESTADO.md` | F0.7 ✅, total F0: 8 átomos, total: 5/87 |
| `BOS-REPAIR-PLAN-MAESTRO-v3.md` | Átomo F0.7 añadido + registro de estado actualizado |
| `instrucciones-agente/EJECUCION-F9.1-F9.3` | Sección ⛔ _legacy/ con referencias a repair/ y observability/ |
| `instrucciones-agente/EJECUCION-F10.1-F10.3` | Sección ⛔ _legacy/ con referencias a ai/ |

---

## Próximos pasos

Con F0.7 cerrado, la Fase 0 tiene 4 átomos completados (F0.0, F0.1, F0.2, F0.7).
Los 4 restantes son:

| Átomo | Descripción | Requiere |
|---|---|---|
| F0.3 | `internal/tui/` subpaquetes + POLICY.md | F0.1 ✅ |
| F0.4 | `internal/paths/paths.go` | F0.1 ✅ |
| F0.5 | Pipeline CI/CD | Ver EJECUCION-F0.5 |
| F0.6 | Entornos DEV/STAGING/PROD | Ver EJECUCION-F0.6 |

**Siguiente átomo recomendado:** F0.3 (subpaquetes TUI) — sin dependencias externas.

---

*INFORME-CIERRE-F0.7-LIMPIEZA.md v1.0 · BOS-REPAIR · 2026-06-09*  
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
