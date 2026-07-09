# ADR-010 — Deprecación de Tryton como Motor de Autorización

**Estado:** ACEPTADO · **Fecha:** 2026-06-28 · **Autor:** agente-bauth
**Reemplaza:** ADR-008 (Simbiosis bAuth-KC-Tryton) · **Impacto:** B13 completo, B10-B11 simplificados

---

## Decisión

**Tryton ERP deja de ser un motor de autorización en SBOS.** Las 5 capas de enforcement
que antes delegábamos a Tryton (`ir.model.access`, `ir.rule`, `ir.model.button`,
`ir.model.field`, `ir.action.groups`) ahora las resuelve bAuth directamente con su
propio motor de políticas.

La simbiosis **trilateral** bAuth↔Keycloak↔Tryton pasa a ser **bilateral** bAuth↔Keycloak.
Keycloak sigue siendo el motor de identidad (OIDC, SAML, WebAuthn). La autorización
es 100% bAuth.

---

## Razones

### 1. bAuth implementa un superconjunto de las capacidades de Tryton

| Capa Tryton | Reemplazo en bAuth | Archivo |
|------------|-------------------|---------|
| `ir.model.access` (CRUD por modelo) | `ath_policy_d1` — rule types: `scope`, `max_records`, `record_filter`, `field_restriction`, `data_classification` | `ath_converter.rs` |
| `ir.rule` (SQL por zona) | `ath_policy_d1` — `record_filter`, `field_restriction` | `ath_converter.rs` |
| `ir.model.button` (control de botones) | `ath_policy_d3` — `dual_approval`, `approval_chain`, `sod` | `ath_converter.rs` |
| `ir.model.field` (restricción de campos) | `ath_policy_d1` — `field_restriction` | `ath_converter.rs` |
| `ir.action.groups` (menús visibles) | `ath_policy_d1` — `data_classification` | `ath_converter.rs` |

### 2. bAuth es objetivamente superior

| Dimensión | Tryton (deprecado) | bAuth (actual) |
|-----------|-------------------|----------------|
| Motor | Python interpretado, SQL por registro | Rust nativo, operaciones bitwise |
| Latencia | ~5-50ms por decisión | <0.5ns FastPath, <5ms PolicyPath |
| Dominios | 1 (lógico-negocio) | 12 (D1-D12) |
| Tipos de regla | 5 fijos | 62 data-driven, extensibles |
| Resolución de conflictos | No existe | XACML 3.0 deny-overrides + detector automático |
| Simulación | No existe | PolicySimulator dry-run |
| Auditoría | Log Python genérico | WORM inmutable ISO 27001 A.8.9 |
| Zero Trust | No | NIST SP 800-207, ctx_id obligatorio |
| Hot reload | Reinicio requerido | SIGHUP, rollback automático |

### 3. Tryton nunca se implementó en bAuth

- `src/engine/tryton_engine.rs` **no existe** — el directorio `engine/` solo contiene `mod.rs`
- Los 22 átomos de B13 en REGISTRO-ESTADO.md están marcados 📄 (diseño), nunca pasaron a código
- El trait `AuthEngine` se definió pero sin implementación Tryton
- `tryton_user_id` en `idn_user_template` es una columna legacy sin código que la use
- `tryton_action_visibility` es una tabla de bAuth, no de Tryton

### 4. Simplifica la arquitectura

```
ANTES (3 motores):                   AHORA (2 motores):
┌────────┐                            ┌────────┐
│ bAuth  │──► Keycloak (identidad)    │ bAuth  │──► Keycloak (identidad)
│        │──► Tryton   (autorización) │        │──► bAuth   (autorización — 12 dominios propios)
│        │──► Vault    (firma)        │        │──► Vault   (firma)
└────────┘                            └────────┘
```

---

## Consecuencias

### Lo que se depreca

| Elemento | Acción |
|----------|--------|
| B13 — TrytonEngine (22 átomos) | Marcado 📄 DEPRECADO en REGISTRO-ESTADO.md |
| `tryton_user_id` en `idn_user_template` | Columna legacy — mantener para compatibilidad, no usar |
| `tryton_status` en `bos_sync_log` | Columna legacy — mantener, no actualizar |
| `tryton_action_visibility` | Tabla de bAuth para visibilidad contextual — renombrar o clarificar |
| ADR-008 (Simbiosis trilateral) | Reemplazado por este ADR-010 |
| Referencias a Tryton en 67 documentos | Este ADR es la fuente de verdad. Los documentos heredan. |

### Lo que se simplifica

| Gate | Antes | Ahora |
|------|-------|-------|
| B10 — RolTemplate | Sync a KC + Tryton | Sync solo a Keycloak |
| B11 — UserTemplate | Provisioning en KC + Tryton | Provisioning solo en Keycloak |
| B12 — KeycloakEngine | 1 de 2 motores | Único motor externo |
| B13 — TrytonEngine | 22 átomos planeados | DEPRECADO |

### Lo que NO cambia

- Keycloak sigue siendo el motor de identidad (OIDC, SAML, WebAuthn, MFA)
- Vault sigue siendo el motor de firma digital (Ed25519)
- Besu/Arbitrum siguen siendo el motor de anclaje blockchain (D12)
- La arquitectura de engines con trait `AuthEngine` se mantiene — simplemente tiene 1 implementación menos

---

## Referencias

- `ath_converter.rs` — 62 rule types que reemplazan las 5 capas Tryton
- `evaluate.rs` — Motor XACML 3.0 que evalúa políticas sin delegar a ERP externo
- `policy_admin.rs` — CRUD, conflictos, simulación, auditoría, hot reload (capacidades que Tryton no tiene)
- `REGISTRO-ESTADO.md` §B13 — marcado DEPRECADO
- `BAUTH-CONTRATO-SYMBIOSIS.md` — actualizado a arquitectura bilateral

---

*ADR-010 · bAuth Identity Core v3.0 · 2026-06-28*
