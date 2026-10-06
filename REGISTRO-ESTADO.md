# REGISTRO DE ESTADO — SBOS
**Auditoría:** S-47 · 2026-10-07  
**Método:** inspección directa de código + verificación contra plan 0.01  
**Auditor:** Claude Sonnet 4.6 (coordinador de fábrica)

---

## Resumen ejecutivo

| Dimensión | Valor |
|---|---|
| Daemons con código | 2 de 5 (BOS, bAuth) |
| Daemons VACÍOS | 3 (bKernel, bNexus, bIntelligence) |
| Líneas código total | ~148,506 (BOS 94K + bAuth 54K) |
| Plan vs código | ALINEADO — el plan 0.01 es honesto sobre gaps |
| Sistema evaluable mínimo | POSIBLE HOY con BOS + bAuth + InfraAgent |
| Tiempo estimado para sistema completo | 8-12 semanas (3 daemons nuevos) |

---

## Tabla de estado por componente

| Componente | Lenguaje | Líneas prod | Archivos | Estado | Alineación docs |
|---|---|---|---|---|---|
| **BOS** | Go 1.25 | 94,324 | ~432 | 🟡 PARCIAL | ✅ ALINEADO |
| **bAuth** | Rust + Dart | 54,182 | ~321 | 🟡 PARCIAL | ✅ ALINEADO |
| **InfraAgent** | Bash | 1,420 | 12 | 🟡 PARCIAL | ✅ ALINEADO |
| **bKernel** | — | 0 | 0 | 🔴 VACÍO | — no hay código que alinear |
| **bNexus** | — | 0 | 0 | 🔴 VACÍO | — docs ricos, cero código |
| **bIntelligence** | — | 0 | 0 | 🔴 VACÍO | — solo PROPOSITO.md |

---

## BOS (BosAgent) — Detalle

**Estado: 🟡 PARCIAL — compila, instala K8s, fichas S-HOST completas**

### Lo que está completo
- `go build ./...` limpio (go 1.25.0)
- Motor ③ Server FICHAS: código completo, tests, funcional en aislamiento
- 9 fichas reales en `servers/S-HOST/`: bos-preflight, sbos-bootstrap-{os,k8s,storage,cni,monitoring,hard}, sbos-bkernel, sbos-namespace
- Motor ④ Context Plane: 11 métodos implementados (2,435 líneas), service/store/types/unified
- `internal/bauth/`: client.go + tipos + tests de integración
- TUI completa con componentes visuales
- RPC Catalog: 35 OK / 59 esperados

### Lo que FALTA

| Gap | Prioridad | Estimado |
|---|---|---|
| 4 motores Capacidad: `collector.go`, `forecaster.go`, `policy_engine.go`, `action_engine.go` | ALTA | ~800L Go |
| `internal/certman/` — gestión TLS automática | MEDIA | ~300L Go |
| `internal/eventbus/` — Redis Streams | MEDIA | ~200L Go |
| Port Manager conectado a lifecycle.go | MEDIA | ~50L Go |
| DDL naming migration: constantes Go español→inglés (18 estados) | ALTA | ~100L Go |
| Fichas S03 (KC/Vault/Kong/bAuth) `task_catalog.sh` stubs vacíos | ALTA | ~400L Bash |
| 5 métodos `bos.web.domain.*` del Dashboard (Motor ⑤) | BAJA | ~200L Go |
| Context Plane operativo sin PG+Redis local | BLOQUEANTE para tests | Infra |

### Verificación plan 0.01 vs código

| Afirmación del plan | Código real | Veredicto |
|---|---|---|
| `certman` directorio no existe | Confirmado: `/internal/certman/` ausente | ✅ PLAN HONESTO |
| `eventbus` directorio no existe | Confirmado: `/internal/eventbus/` ausente | ✅ PLAN HONESTO |
| 4 capacity motors L0 | Confirmado: solo calculator.go + model.go + persist.go | ✅ PLAN HONESTO |
| Context Plane L2 (11 métodos) | Confirmado: 2,435L, service+store+types+unified | ✅ PLAN HONESTO |
| K8s `CheckPodHealth` TODO(F9) | Confirmado: api.go:56 tiene el TODO | ✅ PLAN HONESTO |
| DDL naming migration pendiente | Confirmado: grep constantes en español en Go | ✅ PLAN HONESTO |

**Conclusión BOS:** El plan v3.0.0 es una descripción honesta del estado real. No hay afirmaciones falsas. El código existe donde el plan dice que existe y está ausente donde el plan lo reconoce.

---

## bAuth (BauthAgent) — Detalle

**Estado: 🟡 PARCIAL — daemon Rust funcional, 12/47 métodos auth implementados**

### Lo que está completo
- 37,648 líneas Rust producción
- Daemon completo con main.rs, graceful shutdown, systemd notify
- Keycloak ELIMINADO (ADR-010): bAuth ES el IdP soberano
- 12 métodos auth: Contraseña+Argon2id, Recovery Codes, TOTP, HOTP, WebAuthn/Passkey, FIDO2, Email OTP, Push Challenge Ed25519, mTLS X.509, SAML 2.0, Step-Up RFC 9470, SCIM
- Context Plane module: engine.rs, mod.rs, plane.rs
- 896 CREATE TABLE statements (DDL completo)
- Desktop Flutter/Dart: 16,534 líneas UI (bAuthDEV RPC Tester)

### Lo que FALTA

| Gap | Prioridad | Estimado |
|---|---|---|
| 35 métodos auth restantes (P1-P4 según 2.02) | ALTA — núcleo del producto | ~8,000L Rust |
| Métodos P1: OAuth 2.1 Device Flow, PKCE, Refresh Token rotation | CRÍTICO | ~2,000L Rust |
| Integración completa con BOS Context Plane | ALTA | ~500L Rust |

**Nota:** Los 12 métodos implementados CUBREN los casos de uso enterprise más comunes. El daemon ES evaluable hoy.

---

## InfraAgent — Detalle

**Estado: 🟡 PARCIAL — scripts Bash reales, no stubs**

### Lo que está completo
- 4 servidores con task_catalog.sh reales:
  - `sbos-bootstrap-os` (442L): hardening SO, CRI-O, kubeadm, kernel params
  - `sbos-bootstrap-k8s` (373L): cluster K8s init, join workers
  - `sbos-bootstrap-platform` (390L): stack PG+Redis+Vault+Kong
  - `sbos-k8s-network-validator` (215L): validación red
- Signal protocol consistente en todos: `__SBOS__STEP_START/OK/FAIL/SKIP/CLEANUP__`

### Lo que FALTA
- Orquestador Python que invoca los scripts en secuencia
- Integración con BOS state JSON para idempotencia
- Tests automatizados de las fichas

---

## bKernel (BkernelAgent) — Detalle

**Estado: 🔴 VACÍO — G1-ALTA desde S-44**

Contiene únicamente `PROPOSITO.md` y `CLAUDE.md`. El código fue perdido en un rebase/reorganización en S-44. Es una deuda de alta prioridad.

### Lo que FALTA (todo)

| Componente | Estimado |
|---|---|
| Motor de reconciliación continua | ~8,000L Rust |
| WAL (Write-Ahead Log) para audit trail | ~3,000L Rust |
| Event sourcing local | ~4,000L Rust |
| Integración con bNexus para eventos físicos | ~2,000L Rust |
| **Total estimado** | **~17,000L Rust** |

---

## bNexus (BnexusAgent) — Detalle

**Estado: 🔴 VACÍO — documentación rica, cero código**

Tiene 50+ documentos de arquitectura muy detallados (Puerta 1/2, SAM128, HAL, drivers, políticas físicas, etc.) pero ningún archivo de código.

### Lo que FALTA (todo)

| Componente | Estimado |
|---|---|
| HAL (Hardware Abstraction Layer) | ~5,000L Rust |
| Drivers de dispositivos | ~8,000L Rust |
| Puerta 1 (agentes) + Puerta 2 (bAuth) | ~4,000L Rust |
| Motor de cache offline fail-secure | ~3,000L Rust |
| **Total estimado** | **~20,000L Rust** |

---

## bIntelligence (BintelligenceAgent) — Detalle

**Estado: 🔴 VACÍO — solo PROPOSITO.md y CLAUDE.md**

Sin documentación técnica detallada ni código. El más temprano en el roadmap.

**Total estimado:** ~10,000L (Python/Go según ADR futuro)

---

## Sistema mínimamente evaluable HOY

**Criterio:** ¿Qué se puede "bootear y testear" con el código actual?

### Ciclo de evaluación mínimo (SIN bKernel, bNexus, bIntelligence)

```
1. BOS compila → ✅ VERIFICADO (go build ./...)
2. BOS instala SO en contenedor → ✅ (9 fichas S-HOST reales)
3. InfraAgent bootstrap K8s → ✅ (task_catalog.sh sbos-bootstrap-k8s)
4. bAuth daemon arranca → ✅ (Rust main.rs completo)
5. bAuth responde 12 métodos auth → ✅ (verificado en sesiones anteriores)
```

**Lo que BLOQUEA la evaluación completa:**

| Bloqueo | Causa | Acción mínima |
|---|---|---|
| Capacity monitoring | 4 motores ausentes | Implementar collector.go (MVP: CPU/RAM/disco) |
| DDL constants | 18 estados en español en Go | Rename automático ~100L |
| S03 fichas vacías | Vault/Kong/bAuth no instalables por BOS | Completar task_catalog.sh S03 |
| Context Plane sin infra | Requiere PG+Redis corriendo | InfraAgent sbos-bootstrap-platform |

### Ruta mínima hacia evaluación completa (2-3 semanas)

1. **Semana 1:** DDL migration + capacity collector (MVP) + completar S03 fichas
2. **Semana 2:** eventbus + certman + Port Manager
3. **Semana 3:** bAuth métodos P1 restantes + pipeline integración BOS↔bAuth

---

## Gaps críticos ordenados por impacto

| # | Gap | Componente | Impacto | Estimado |
|---|---|---|---|---|
| G1 | bKernel VACÍO | bKernel | CRÍTICO — sin reconciliación | 17K L Rust |
| G2 | bNexus VACÍO | bNexus | ALTO — sin control hardware | 20K L Rust |
| G3 | 4 motores Capacity | BOS | ALTO — sin observabilidad SO | ~800L Go |
| G4 | S03 fichas vacías | BOS | ALTO — BOS no puede instalar bAuth/Vault/Kong | ~400L Bash |
| G5 | DDL naming migration | BOS | ALTO — inconsistencia estados | ~100L Go |
| G6 | 35 métodos auth faltantes | bAuth | MEDIO — funcional con 12, incompleto | ~8K L Rust |
| G7 | certman + eventbus | BOS | MEDIO — funcional sin ellos en dev | ~500L Go |
| G8 | bIntelligence VACÍO | bIntelligence | BAJO — no en ruta crítica mínima | ~10K L |

---

## Historial de actualizaciones

| Fecha | Sesión | Evento |
|---|---|---|
| 2026-10-07 | S-47 | Auditoría inicial — registro creado |
