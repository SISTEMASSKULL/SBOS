# Anexo A.33 — Motor de Versionado: estado de implementación
## Documento de respaldo de sustentación (tipo D)

**Versión:** 4.0.0 · **Fecha:** 2026-07-28 · **Respalda a:** 1.13_MANUAL-MOTOR-VERSIONADO-v1.0.md · A.27 (WORM compartido)
**Verificación de código:** F2-DDL VPS 2026-07-24 · F3-Rust completado 2026-07-25 · B03 cerrado 2026-07-25 · Motor completo 2026-07-28
**Normas:** SQL:2011 § WITHOUT OVERLAPS · NIST AU-9 · ISO 27001 A.8.15 · Ley 843 (retención 10 años)

---

## 1. Estado actual — F2-DDL + F3-Rust completos · B03 CERRADO · Motor 9-pasos COMPLETO

El motor pasó de **L1 (0 código)** a **F2-DDL completado** en VPS el 2026-07-24.

### 1.1 ENUMs creados en schema `bauth`

| ENUM | Valores |
|---|---|
| `bauth.ver_semver_change_enum` | `MAJOR`, `MINOR`, `PATCH` |
| `bauth.ver_channel_enum` | `API`, `CLI`, `BOOTSTRAP`, `RECONCILE` |
| `bauth.ver_proposal_status_enum` | `PENDING`, `APPROVED`, `REJECTED`, `EXPIRED` |
| `bauth.ver_compaction_enum` | `KEEP_ALL`, `KEEP_ANCHORS`, `KEEP_LAST_N` |

### 1.2 Columnas del motor agregadas a T-041 (`idn_roles_rol_hierarchical`)

| Columna | Tipo | Propósito |
|---|---|---|
| `sys_since` | `TIMESTAMPTZ NOT NULL DEFAULT now()` | Inicio del período activo actual |
| `change_channel` | `bauth.ver_channel_enum NOT NULL DEFAULT 'BOOTSTRAP'` | Canal que originó el cambio |
| `change_reason` | `TEXT` | Justificación (obligatorio en MAJOR vía T-153) |
| `security_impact` | `risk_level_enum` | Impacto en postura de seguridad |
| `approved_by` | `UUID → idn_identity_entity` | Aprobador del cambio (dual control) |
| `approved_at` | `TIMESTAMPTZ` | Timestamp de aprobación |

**Nota:** `version_number` + trigger `trg_irrh_version_bump` ya existían (B01 completado en sesión anterior).

### 1.3 Tablas creadas

| Tabla | Alias | Propósito |
|---|---|---|
| `bauth.idn_roles_ver_b01_audit_log` | T-152 | WORM historia de versiones cerradas de T-041 (B01 §audit) |
| `bauth.idn_roles_ver_b03_approval_queue` | T-153 | Cola quórum N-de-M cambios MAJOR (B03 §approval_workflow) |
| `bauth.idn_roles_ver_b01_retention_policy` | T-154 | Política retención legal por entidad C1 (B01 §gobernanza) |
| `bauth.idn_roles_ver_contract_revision_log` | T-155 | Changelog estructural del contrato RolTemplate (Plano A) |

### 1.4 Extensión PostgreSQL

`CREATE EXTENSION IF NOT EXISTS btree_gist;` — requerida por el constraint `UNIQUE (entity_id, sys_period WITHOUT OVERLAPS)` en T-152 (PG18 SQL:2011 §temporal). Instalada en SBOSDB v1.8.

---

## 2. La ruta de materialización (F2–F5)

| Fase | Entregable | Estado |
|---|---|:---:|
| **F2 — DDL** | 4 ENUMs + 6 cols T-041 + T-152..T-155 + btree_gist | ✅ **COMPLETO** (2026-07-24) |
| **F3 — Rust base** | `src/domain/versioning/` (5 módulos) + `src/db/versioning.rs` + `src/db/approval.rs` + handlers B03 (5 métodos) + loop reconcile integrado | ✅ **COMPLETO** (2026-07-25) |
| **F3 — Motor completo** | `semver.rs` + `blocks.rs` + `classify.rs` + `policy.rs` + `db/version_store.rs` + 5 handlers `bauth.version.*` + config TOML | ✅ **COMPLETO** (2026-07-28) |
| **F4 — Retención** | Job de purga/compactación (`sync/retention.rs`): KEEP_ALL/KEEP_ANCHORS/KEEP_LAST_N + estado retención | ✅ **COMPLETO** (2026-07-28) |
| F5 — Extensión | Resto de entidades C1 (T-162, idn_user_template, privilege_*) | ⬜ Pendiente (depende F4 ✅) |

---

## 3. Brechas activas

| # | Brecha | Severidad | Depende de |
|---|---|:---:|---|
| VM1 | WORM genérico `fn_worm_hash_chain` (`bauth_44`) sin aplicar en VPS — afecta sync_log, ath_login_attempt, aud_event y otras tablas (A.27) | P1 | — |
| VM4 | F5 extensión a otras entidades C1 (T-162, idn_user_template, privilege_*) | P2 | F4 ✅ |

**Nota VM1:** T-152 ya tiene su trigger propio `trg_irvb01al_worm` → `fn_irvb01al_worm_hash()` activo en VPS. La deuda `bauth_44` es para las otras 10 tablas WORM del sistema (sync_log, aud_event, etc.), no para el motor de versionado.

**B03 CERRADO:** T-153 DDL corregido (enum CANCELLED + constraints chk_irvb03aq_resolved/dual_ctrl); Rust alineado. 5 métodos JSON-RPC operativos.

---

## 4. Detalle técnico — T-152 (`idn_roles_ver_b01_audit_log`)

La tabla usa la extensión PG18 `WITHOUT OVERLAPS` para garantizar no-solapamiento de períodos temporales por entidad:

```sql
CONSTRAINT uq_irvb01al_temporal UNIQUE (entity_id, sys_period WITHOUT OVERLAPS)
```

Esto crea una exclusión GiST internamente. `btree_gist` v1.8 provee el operador de clase para UUID en GiST — sin esta extensión el constraint falla con `ERROR: data type uuid has no default operator class for access method "gist"`.

Checks de integridad activos:
- Período siempre cerrado (`NOT upper_inf(sys_period)`)
- `version_number >= 0`
- MAJOR requiere `change_reason` no nulo
- MAJOR requiere `is_anchor = true`
- Anchor requiere `snapshot` no nulo
- Aprobación coherente (`approved_by IS NULL OR approved_at IS NOT NULL`)

---

## 5. Historial

| Ver. | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-11 | Motor L1 confirmado: 0 implementación. Ruta F2–F5 definida. Bloqueado por bauth_44. |
| 2.0.0 | 2026-07-24 | F2-DDL completo: 4 ENUMs + 6 cols T-041 + T-152..T-155 + btree_gist aplicados en VPS. DDL sincronizado. VM1 (trigger WORM) pendiente de bauth_44. F3 Rust desbloqueado. |
| 3.0.0 | 2026-07-25 | F3-Rust base: `src/domain/versioning/` (5 módulos), `src/db/versioning.rs`, `src/db/approval.rs`, 5 handlers B03. T-153 DDL corregido en VPS: enum añade CANCELLED, constraints actualizados. B03 CERRADO. Loop reconcile integra `expirar_sla_vencidos()`. |
| 4.0.0 | 2026-07-28 | Motor completo. `semver.rs` (parse/bump/validate fail-closed) + `blocks.rs` (mapa campo→bloque desde `config/blocks_map.toml`) + `classify.rs` (diff JSON → bump_minimo) + `policy.rs` (B3 override por rol) + `db/version_store.rs` (transición atómica 9-pasos: MINOR/PATCH directo, MAJOR → T-153) + 5 handlers `bauth.version.*` (propose/as_of/by_standard/rollback/retention_status) + `sync/retention.rs` F4 (KEEP_ALL/KEEP_ANCHORS/KEEP_LAST_N). 57 tests unitarios ✅ · 0 errores `cargo check`. |
