# BAUTH-ESTADO-DESARROLLO.md — ¿Qué Falta Para Terminar bAuth?

**Versión:** 1.0 · **Fecha:** 2026-06-25
**Propósito:** Análisis realista de lo completado y lo pendiente. Sin adornos.

---

## 1. LO QUE YA ESTÁ COMPLETO (NO SE TOCA MÁS)

| Capa | Estado | Detalle |
|------|:---:|------|
| **DDL** | ✅ | 177 tablas, 0 errores, organizado por dominio |
| **Seeds** | ✅ | 55+ seeds idempotentes ×3 verificados |
| **Documentación DDL** | ✅ | 747 COMMENT ON COLUMN con [ISO/NIST/RFC] |
| **Inventario** | ✅ | v7.0 con líneas de código y propósito por tabla |
| **Visión** | ✅ | SBOS-CONTEXT-PLANE-VISION.md unificado |
| **Template Rol** | ✅ | v6.0 — 14 secciones, ~300 atributos |
| **Template Usuario** | ✅ | v6.0 — 15 secciones, ~460 atributos |
| **CRUD Roles+Usuarios** | ✅ | v3.0 — Árbol jerárquico + Popups + Sync |
| **Ecosistema auth** | ✅ | 12 apps documentadas con su rol |
| **Validadores** | ✅ | 45 métodos mapeados a su validador |
| **Emisores tokens** | ✅ | Keycloak = JWT, bAuth = contexto |
| **Binario Rust** | ✅ | B0: compila, tests pasan, binario MUSL < 3MB |
| **Framework traits** | ✅ | B1: AuthEngine, DomainEvaluator, EngineRegistry |
| **Rutina reparación** | ✅ | v2.0 — 7 pasos + 14 reglas + checklist 25 pts |

---

## 2. LO QUE FALTA — POR PRIORIDAD

### 2.1 🔴 BLOQUEANTE — Sin esto bAuth no funciona

| # | Átomo | Bloque | Qué hace | Estado |
|---|-------|--------|---------|:---:|
| 1 | **Sync Engine KC+Tryton** | B1.T05, B41 | Reconcile loop 60s. Lee `sync_status=PENDING` → traduce RolTemplate a objetos nativos KC (Composite Role, Auth Flow) + Tryton (ir.model.access, ir.rule). Registra en sync_log. | 🔴 |
| 2 | **PrivilegeEngine — evaluate_all()** | B1.T06 | DomainRegistry con 12 evaluadores. Orden D8→D9→D1→D3→D2→D10→D4→D6→D7→D5→D12→D11. Cortocircuito en primer DENY. <5ms P99. | 🔴 |
| 3 | **JSON-RPC handlers** | B40 | 21 handlers: bauth.role.*, bauth.user.*, bauth.context.*, bauth.policy.*, bauth.sync.* | 🔴 |
| 4 | **Rol BitMask engine** | B1.T07-T09, T14-T18 | ComputeRolBitMask, MergeRoles, InheritFromParent, FastPathCheck, Serializer | 🟡 |
| 5 | **Policy Engine** | B1.T19 | PolicyChainResolver: evalúa políticas JSONB de `privilege_atom_policy` + `ath_policy_d*` | 🔴 |

### 2.2 🟠 ALTO — Funcionalidad core de dominios

| # | Átomo | Qué hace | Estado |
|---|-------|---------|:---:|
| 6 | **D1 LogicalEvaluator** | B3.T03-T04 | Fast-Path: verbo suficiente, <0.5ns | 🟡 |
| 7 | **D2 PhysicalEvaluator** | B2.T04-T05 | Fast-Path: acceso físico | 🟡 |
| 8 | **D3 FinancialEvaluator** | — | Policy-Path: límites, SoD, dual approval | 🔴 |
| 9 | **D4 TemporalEvaluator** | — | Policy-Path: horario, feriados, horas extra | 🔴 |
| 10 | **D6 GeoEvaluator** | — | External-Path: geo-fence (PostGIS), velocity | 🔴 |
| 11 | **D7 NetworkEvaluator** | — | External-Path: device trust, ZTNA | 🔴 |
| 12 | **D8 ContextEvaluator** | — | Pre-BitMask: ctx_id válido, sesión activa | 🔴 |
| 13 | **D9 CredentialEvaluator** | — | Pre-BitMask: credenciales verificadas, LoA | 🔴 |

### 2.3 🟡 MEDIO — Completitud y robustez

| # | Átomo | Qué hace | Estado |
|---|-------|---------|:---:|
| 14 | **Reconcile loop** | B41 | Detección de drift KC+Tryton, auto-reconciliación | 🔴 |
| 15 | **Seed data loader** | B38 | Carga inicial desde seeds a BD en bootstrap | 🔴 |
| 16 | **SoD Conflict Matrix** | B1.T16, B38 | Validación pre-merge de roles | 🔴 |
| 17 | **Risk Scoring** | B37 | Evaluación continua de riesgo de sesión | 🔴 |
| 18 | **HIBP Screening** | B36 | Cribado k-anonymity de passwords | 🔴 |
| 19 | **PCI DSS 8.5.1** | B42 | No revelar factor fallido en auth | 🔴 |

### 2.4 ⚪ BAJO — Futuro / Nice-to-have

| # | Átomo | Qué hace | Estado |
|---|-------|---------|:---:|
| 20 | **Post-Quantum Crypto** | B39 | Wrappers para CRYSTALS-Kyber/Dilithium | 🔴 |
| 21 | **IdP-as-a-Service** | B34 | bAuth como proveedor de auth externo | 🔴 |
| 22 | **Productos D12** | B33 | Productos comerciales blockchain | 🔴 |
| 23 | **Disaster Recovery** | B32 | DR, key management, incident response | 🔴 |
| 24 | **Threat Model** | B31 | Modelado de amenazas, security testing | 🔴 |

---

## 3. ¿HAY BLOQUEANTES?

**No hay bloqueantes de infraestructura.** La DDL está completa. Los seeds están completos. La documentación está completa.

**Los bloqueantes son de código Rust:**
1. El Sync Engine que traduce RolTemplate → KC + Tryton (B1, B41)
2. El PrivilegeEngine que evalúa 12 dominios (B1.T06)
3. Los JSON-RPC handlers que exponen la API (B40)
4. Los evaluadores de dominio D3-D9 (varios bloques)

**Sin estos 4 componentes, bAuth no puede:**
- Sincronizar un rol con Keycloak y Tryton
- Evaluar si un usuario puede ejecutar una operación
- Exponer una API para que otros daemons consulten

---

## 4. ORDEN DE DESARROLLO RECOMENDADO

```
SEMANA 1-2: PrivilegeEngine (B1.T06-T18)
  → BitMask engine, FastPathCheck, DomainRegistry, PolicyChainResolver
  → Sin esto, nada más funciona.

SEMANA 3-4: Evaluadores de dominio (B2-B3, D3-D9)
  → LogicalEvaluator, PhysicalEvaluator, FinancialEvaluator...
  → Cada evaluador = 2-4h de código Rust.

SEMANA 5-6: Sync Engine (B1.T05, B41)
  → KC Admin API, Tryton XML-RPC, reconcile loop 60s
  → Registro en sync_log, drift detection.

SEMANA 7-8: JSON-RPC API (B40)
  → 14 métodos mínimos: bauth.role.*, bauth.user.*, bauth.context.*
  → Interface Dual: WebSocket RPC + JSON-RPC 2.0 sobre mismo socket.

SEMANA 9-10: Integración + Tests
  → Integración con VPS (PostgreSQL 18.4, Keycloak 26.x)
  → k6 load tests, SLO verification
```

---

## 5. MÉTRICAS REALES

| Indicador | Valor |
|-----------|:---:|
| Átomos totales en registro | ~273 ✅ código / 452 📄 diseño |
| Átomos bloqueantes para MVP | 5 (Sync, PrivilegeEngine, JSON-RPC, BitMask, Policy) |
| Átomos para completitud | 14 adicionales (D3-D9 evaluadores, reconcile, SoD) |
| Átomos futuro | 8 (PQC, IdP, productos, DR, threat model) |
| **Tiempo estimado para MVP** | **8-10 semanas (2 desarrolladores)** |
| **Tiempo estimado para v1.0** | **14-16 semanas** |

---

*Documento generado 2026-06-25. DDL y seeds COMPLETOS. El camino es código Rust.*
*Sin bloqueantes de infraestructura. Sin dependencias externas pendientes.*
*El registro de estado (REGISTRO-ESTADO.md) refleja diseño completado — ahora toca implementar.*
