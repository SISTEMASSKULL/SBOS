# Revisión de Consistencia — Manuales ↔ Código · Vistazo integral del catálogo
## Barrido sistemático 2026-07-10 · corpus de 33 documentos vs `src/`

**Autor:** bauth-developer · **Fecha:** 2026-07-10
**Método:** extracción automática de toda referencia `src/*.rs` en los 33 manuales → verificación de
existencia en disco · grep de claims obsoletos (KC/Tryton vivos, Python/Apprise, conteos) · lectura
de contexto de cada hallazgo antes de corregir (para no "corregir" menciones ya históricas).
**Regla aplicada:** correcciones **documentales** solamente — el código está **congelado** por orden
del humano hasta terminar la documentación de la reparación.

---

## 1. Estado del catálogo tras el vistazo

| Métrica | Valor |
|---------|:-----:|
| Manuales publicados ✅ | **32** (todas las fases del ciclo cerrado cubiertas) |
| Carta rectora | 0.00 (IAM Enterprise) |
| Planificados detectados en este vistazo ➕ | **2** (1.12 · 9.2) |
| Archivos en disco | 33 (cuadra: 32 + rector) |

### 1.1 Manuales que FALTABAN — análisis de cobertura

Criterio: ¿hay sustrato de código relevante sin manual dueño?

| Candidato evaluado | Sustrato | Veredicto |
|--------------------|----------|-----------|
| **CLI y Pruebas Externas** | 3 binarios de prueba + protocolo Testeador sin contrato escrito | ✅ **ESCRITO** → [7.04](../../Documentacion/7.04_MANUAL-CLI-PRUEBAS-EXTERNAS-v1.0.md) (pedido del humano) |
| **Multi-tenancy e IDaaS** | `bauth.tenant.*` (6 métodos) + `bauth.idp.*` (12 métodos: branding/billing/residency/isolation) — menciones dispersas en D00/Directrices, sin manual dueño | ➕ **añadido como 1.12 Planificado** |
| **Referencia de API** | ~115 métodos `bauth.*` en ~20 namespaces — solo resumidos en 9.01 §5 | ➕ **añadido como 9.2 Planificado** |
| Sagas / flujos de autenticación | Motor `saga/` + `bauth.saga.*` | Cubierto: 2.01 Autenticación (22 menciones) — no falta |
| Motor Vault / PKI | `engine/vault_engine.rs` | Cubierto: 2.04 Firma Digital — no falta |
| Reconcile / drift | `sync/mod.rs` | Cubierto: 6.01 §10 — no falta |
| SDK multi-lenguaje | `src/sdk` | Cubierto: 9.01 §8 — no falta |
| Instalación / fichas de despliegue | — | Fuera de alcance: producto de **bos** (`servers/`, skill sbos-fichas) |

---

## 2. Inconsistencias manuales↔código — detectadas y CORREGIDAS (documental)

| # | Hallazgo | Realidad verificada | Corrección aplicada |
|---|----------|---------------------|---------------------|
| I1 | 6.01 citaba `src/audit/siem.rs` (Wazuh) como código operativo | **No existe** `audit/siem.rs` ni mención wazuh/syslog en `src/` (grep vacío) — es DISEÑO | 6.01 §8.3 reencuadrado a diseño (apunta a 5.01), §15 fila madurez matizada, §16 referencia retirada |
| I2 | 2.01 §4.2 y 2.02 §3 citaban `src/domain/password_policy.rs` | El módulo real es el **directorio** `src/domain/password/` | Ambas citas corregidas al nombre real |
| I3 | 1.10 cabecera listaba `keycloak_engine` como código vigente | Eliminado (ADR-010) | Cabecera corregida (vault_engine · caep_client; KC tachado) |
| I4 | 1.10 §3.3 tabla de limpieza desactualizada | SPIs Java: **eliminadas** (src/spi no existe) · config KC: **eliminada** · constantes TRYTON_*: producción renombrada `ERP_*`, queda **1 referencia en test** (`logical.rs:191`) | Las 3 filas actualizadas al estado real, con la referencia exacta del remanente |
| I5 | INDICE §alcance listaba "SPIs Java, SDKs" como entregables de PRODUCTO | SPIs eliminadas | Línea corregida (tachado + puntero a 9.01 §10) |

### 2.1 Verificadas y SANAS (no requirieron corrección)

| Verificación | Resultado |
|--------------|-----------|
| 5.01 §7 y tabla P2: `siem.rs` / Wazuh | ✅ correcto — ya está encuadrado como **Diseño/pendiente P2**, no como código |
| 2.02 "47 métodos" | ✅ correcto — son los 47 métodos de autenticación de la industria (taxonomía), NO los "47 handlers" del CLAUDE.md (otro dato) |
| 4.01 menciones "Python 3.14/Apprise" | ✅ correcto — son citas correctivas ("describían…"), no claims vivos |
| Enlaces del INDICE | ✅ 32/32 filas resuelven a archivo existente |

---

## 3. Inconsistencias que QUEDAN — requieren decisión o código (congeladas)

| # | Hallazgo | Por qué no se corrigió ya | Ruta |
|---|----------|---------------------------|------|
| Q1 | `CLAUDE.md` raíz de BauthAgent dice **"47 handlers JSON-RPC"** — el código registra **~115 métodos** (120 register, 115 únicos) | CLAUDE.md es doctrina del daemon → el agente no la edita unilateralmente | **HITL** (ya anotado en 9.01 §11) |
| Q2 | `bos_verify.rs` (cabecera) declara **Arbitrum One** como red online; el corpus declara **Besu** soberano | Decisión de doctrina de red canónica (además tocaría código) | **HITL** (anotado en 7.04 §6/C4) |
| Q3 | ~~`logical.rs:191` — 1 referencia `TRYTON_*` en test~~ ✅ **RESUELTO 2026-07-11**: `test_all_d1_slugs_defined` corregido a `ERP_CONTABILIDAD_NUEVO` — `cargo test` compila y pasa (366 ok, incluidos los 8 tests CAEP antes bloqueados) | — | hecho |
| Q4 | CLAUDE.md raíz aún menciona "Java 21 (5 SPIs)" como stack | Doctrina → HITL (el Cargo.toml ya fue corregido antes de la orden de congelar) | **HITL** |
| Q5 | `idp.isolation` (idp_external.rs) responde `"model": "realm_por_tenant"` + `"keycloak_version": "26.6.2"` + 3 realms KC — la API describe la arquitectura ELIMINADA por ADR-010 | Código congelado | Al retomar código (P1 — detectado al escribir 1.12 §8/V1) |
| Q6 | **Dos discoveries divergentes**: `bauth.idp.discovery` emite endpoints estilo KC (`/protocol/openid-connect/*`) mientras `bauth.oidc.discovery` emite la superficie nativa | Código congelado | Al retomar código: unificar en un solo emisor de verdad (1.12 §8/V2) |
| Q7 | Columnas `idn_tenant.realm_kc` / `realm_kc_ext` en el DDL canónico — modelo KC residual | Migración DDL (schema `bauth` gobernable) → al reabrir código | 1.12 §8/V3 · P3 |
| Q8 | **Sin Row-Level Security** en tablas tenant-scoped (verificado: 0 `ROW LEVEL SECURITY` en migrations) — el aislamiento pool depende solo del `WHERE tenant_id` de cada handler | Migración DDL → al reabrir código | 1.12 §3/B3 · **P2 de seguridad** |
| Q9 | ~~**7 métodos huérfanos** de `role_lifecycle.rs`~~ ✅ **RESUELTO 2026-07-11** (código reabierto — gaps de rol): bucle `all_role_lifecycle_handlers` registrado en main.rs. Evidencia: cargo check Finished · **366 tests ok, 0 failed**. `domain_remaining.rs` sigue sin registro (naturaleza por confirmar) | — | hecho (9.02 §14) |
| Q10 | **Colisión de registro**: `bauth.token.validate` se registra DOS veces (inline vía `token_validate.rs` y por lote vía `kong_oauth::all_kong_handlers`) — el segundo pisa al primero en silencio; dueño único sin decidir | Código congelado | Al retomar código (9.02 §17/R3 · P2) |
| Q11 | **Cifra de superficie**: CLAUDE.md dice «47 handlers»; conteos sucesivos: ~115 (grep laxo) → ~141 (sin `token_protocols`) → **≈151 vigente** (114 inline + 37 por lote, incluye los 7 del ciclo de vida montados 2026-07-11) | 9.01/9.02 corregidos; CLAUDE.md → HITL (amplía Q1) | 9.02 §2 |

---

## 4. Estado del código al momento del congelamiento (para la retoma)

Trabajo de código realizado ANTES de la orden de congelar (el humano pidió el cliente CAEP y luego
ordenó parar; el cierre mínimo evitó dejar el árbol roto):

| Pieza | Estado | Evidencia |
|-------|--------|-----------|
| Cliente gRPC CAEP (`domain/caep.rs` + `engine/caep_client.rs` + `sync/mod.rs` recableado + `main.rs` + `Cargo.toml` tonic/prost sin tonic-build) | ✅ Implementado | `cargo check` → **`Finished dev profile` · exit 0** |
| Tests unitarios del CAEP (8: event_id determinista, textos de alambre, roundtrip protobuf, stub, NoDisponible) | ⚠️ Escritos, **no ejecutables** todavía | Bloqueados por Q3 (error ajeno en `logical.rs:191`) |
| Comentario falso `notify.rs` (Python/Apprise) | ✅ Corregido antes | `cargo check` exit 0 |
| Fix parcial constantes test TRYTON_→ERP_ (`logical.rs:124-128`, 10 de 11) | ✅ Aplicado antes de la orden | queda Q3 |

**Nada más de código se toca hasta que el humano dé por terminada la documentación de la reparación.**

## 5. Pendientes documentales que siguen (orden sugerido)

1. ~~Escribir **1.12 Multi-tenancy e IDaaS**~~ ✅ 2026-07-10 (destapó Q5-Q8) · ~~escribir **9.2 Referencia de API**~~ ✅ 2026-07-11 (destapó Q9-Q11 + corrigió cifra a ≈141 y el «sin motor SCIM» de 1.12 — el servidor SCIM real existe).
2. ~~Responder los contratos **C-BNOTIFY-001..004**~~ ✅ 2026-07-11 — los 4 respondidos y movidos a 💬 EN DIÁLOGO (001: acepta, transmisor ya implementado · 002: acepta 2/3, faseo ≤65s→<5s para el SLA · 003: acepta con condiciones O1 Vault PKI + G4 gateway · 004: acepta con G3 claims externos + G4). Campos de bNotify intactos (verificado). Queda en bNotify mover a ACORDADO — y responder los C-BAUTH-001..004 que siguen 📝.
3. Q1/Q2/Q4 → elevar al humano (HITL) cuando corresponda.
4. Empaquetar la suite de humo de 7.04 §9 (`scripts/suite_humo.sh`) — **cuando se reabra el código**.

---

*REVISION-CONSISTENCIA-MANUALES-2026-07-10 · REPARACIONBAUTH · barrido completo del corpus (33 docs)*
