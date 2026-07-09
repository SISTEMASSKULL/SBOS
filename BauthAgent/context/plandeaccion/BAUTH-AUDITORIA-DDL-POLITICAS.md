# BAUTH-AUDITORIA-DDL-POLITICAS.md — Solapamientos y Duplicaciones
## Análisis estructural de políticas, configuraciones y framework · 2026-06-30

**Propósito:** Identificar y documentar solapamientos entre tablas, conceptos mezclados,
y código muerto en el DDL de bAuth. Base para una futura limpieza del schema.

---

## HALLAZGO 1 (🔴 CRÍTICO): Tres sistemas de configuración compitiendo

| Tabla | Schema | Propósito declarado | ¿Usada en runtime? |
|-------|--------|-------------------|:---:|
| `ath_config` | bauth | Config por tier (SU, SYS, BIZ_N3..) — token, session, rate, audit, recovery, lockout | ❌ Sin handler activo |
| `ath_config_d1..d12` | bauth | Config por dominio D1-D12 — token_ttl, door_relay_ms, password_min_length, etc. | ❌ Sin handler activo |
| `global_config` | bglobal | Config global key-value — cualquier parámetro del sistema | ✅ `load_global_config()` en `db.rs` |

**Problema:** Si un admin quiere cambiar `session_ttl_max`, podría estar en las 3 tablas. No hay reglas de precedencia documentadas. Solo `bglobal.global_config` es consultada por el código Rust.

**Recomendación:** Unificar en `bglobal.global_config`. Marcar `ath_config` y `ath_config_d*` como solo-lectura histórica o eliminarlas.

---

## HALLAZGO 2 (🔴 CRÍTICO): Tres conceptos de "política" mezclados

| Tabla | Tipo real | Registros | ¿Evaluada en runtime? |
|-------|-----------|:---:|:---:|
| `privilege_atom_policy` | **Capa A — XACML 3.0** | 6,782 | ✅ `bauth.policy.evaluate`, `bauth.access.evaluate` |
| `ath_policy_d1..d12` | **Capa B — Reglas operativas** | ~4-12/dominio | ✅ `bauth.policy.domain.evaluate` |
| `cfg_policy_library` | **Biblioteca de referencia** | 9,142 | ❌ Solo `bauth.policy.library.search` |
| `ath_policy` | **Legacy — sin uso** | ~0 | ❌ Sin handler activo |
| `ath_credential_policy` | **Ciclo de vida credenciales** | ~8 | ✅ `domain/validate.rs` (validación passwords) |

**Problema:** La palabra "política" significa 5 cosas distintas. No hay documentación clara que explique qué tabla se consulta para qué propósito.

**Recomendación:** Renombrar en la documentación:
- `privilege_atom_policy` → "Políticas XACML por Átomo (Capa A)"
- `ath_policy_d*` → "Reglas Operativas por Dominio (Capa B)"
- `cfg_policy_library` → "Biblioteca Normativa de Referencia"
- `ath_policy` → marcar como `[DEPRECADO]`
- `ath_credential_policy` → "Políticas de Ciclo de Vida de Credenciales"

---

## HALLAZGO 3 (🟠 ALTO): Tablas legacy sin handler activo

| Tabla | Schema | Motivo |
|-------|--------|--------|
| `ath_policy` | bauth | Reemplazada por `ath_policy_d*`. Sin registros. Sin handler. |
| `bos_permiso_logico` | bauth | Schema antiguo. Reemplazado por `privilege_role_atom`. Sin handler. |

**Recomendación:** Agregar `COMMENT ON TABLE ... IS '[DEPRECADO]'` y planificar eliminación.

---

## HALLAZGO 4 (🟠 ALTO): `ath_credential_policy` vs `ath_policy_d9`

Ambas almacenan configuración de credenciales pero con formatos incompatibles:

| Aspecto | `ath_credential_policy` | `ath_policy_d9` |
|---------|------------------------|-----------------|
| Formato | Columnas fijas SQL | JSONB flexible |
| Qué cubre | PASSWORD, TOTP, WEBAUTHN, X509, OAUTH_SECRET, API_KEY, ENCRYPTION_KEY, SIGNING_KEY | password, mfa, recovery, lockout, rotation, phishing_resistance, step_up, m2m_credentials, ciba, token_binding, auth_flow |
| Solapamiento | PASSWORD → min_length, max_age_days, history_count | password → password_min_length, hibp_enabled, lockout_levels, rotation_days |

**Recomendación:** Migrar `ath_credential_policy` a `ath_policy_d9` con formato JSONB unificado.

---

## HALLAZGO 5 (🟡 MEDIO): Referencias legacy en código

| Archivo | Línea | Texto | Debería decir |
|---------|:---:|-------|---------------|
| `domain/policy/parser.rs` | 4 | `bos_atom_policy` | `privilege_atom_policy` |
| `domain/policy/rule.rs` | 5 | `bos_atom_policy` | `privilege_atom_policy` |
| `domain/policy/rule.rs` | 46 | `bos_atom_policy` | `privilege_atom_policy` |

La tabla `bos_atom_policy` NO existe en el DDL actual. La tabla real es `bauth.privilege_atom_policy`.

---

## HALLAZGO 6 (🟡 MEDIO): `cfg_policy_library` alimenta seeds pero no es runtime

Los 9,142 registros de `cfg_policy_library` son la **fuente de datos** para generar seeds de `ath_policy_d*`, `ath_config_d*`, e `idn_role_d*`. Pero **NO se consultan durante la evaluación de acceso.**

El flujo real es:
```
cfg_policy_library (9,142 normas, solo referencia)
  │
  └── seeds SQL leen cfg_policy_library
       │
       └── pueblan ath_policy_d* (políticas operativas)
            │
            └── ÚNICAS tablas consultadas en runtime por bauth.policy.domain.evaluate
```

Esto está bien diseñado — separa referencia de operación. Pero no está documentado.

---

## HALLAZGO 7 (🟡 MEDIO): `privilege_domain` vs `idn_tenant_domain` — sin solapamiento real

| Tabla | Propósito |
|-------|-----------|
| `privilege_domain` | Catálogo de 12 dominios D1-D12. Metadatos: `domain_slug`, `domain_name`, `requires_policy`, `evaluation_order` |
| `idn_tenant_domain` | Configuración de dominio DNS/SSL/NGINX/K8s para un tenant. 17 columnas fijas + 10 JSONB |

**No hay duplicación.** Nombres similares pero propósitos completamente distintos. `privilege_domain` es el catálogo de dominios de control. `idn_tenant_domain` es la configuración de infraestructura del tenant.

---

## CORRECCIONES RECOMENDADAS (plan de acción)

### Fase 1 — Documentar (inmediato)
- [ ] Agregar `COMMENT ON TABLE` en DDL marcando tablas legacy como `[DEPRECADO]`
- [ ] Corregir referencias `bos_atom_policy` → `privilege_atom_policy` en comentarios Rust
- [ ] Documentar la separación Capa A / Capa B / Biblioteca en MANUAL_DB_DDL.md

### Fase 2 — Unificar (siguiente sprint)
- [ ] Migrar `ath_credential_policy` → `ath_policy_d9` (formato JSONB unificado)
- [ ] Definir reglas de precedencia para configuración: `bglobal.global_config` manda sobre `ath_config_d*`
- [ ] Eliminar `ath_policy` (tabla legacy sin registros ni handlers)

### Fase 3 — Limpiar (planificado)
- [ ] Eliminar `ath_config` y migrar valores útiles a `bglobal.global_config`
- [ ] Eliminar `bos_permiso_logico` y migrar datos históricos a `privilege_role_atom`
- [ ] Renombrar `privilege_atom_policy` → `ath_policy_xacml` para consistencia con `ath_policy_d*`

---

## DIAGRAMA CORRECTO DE FLUJO DE POLÍTICAS

```
                  cfg_policy_library (9,142 normas)
                  SOLO REFERENCIA - NO RUNTIME
                  ┌─────────────────────────┐
                  │ NIST, ISO, PCI, FIDO2,  │
                  │ OAuth, SOC2, GDPR, ...  │
                  └───────────┬─────────────┘
                              │ alimenta seeds SQL
                              ▼
         ┌────────────────────────────────────────────┐
         │        SEEDS SQL (build time)              │
         │  leen cfg_policy_library → generan:        │
         │  • ath_policy_d1..d12  (reglas operativas) │
         │  • ath_config_d1..d12  (configs dominio)   │
         │  • idn_role_d1..d12    (templates rol)     │
         └──────────────┬─────────────────────────────┘
                        │ pueblan tablas operativas
                        ▼
    ┌───────────────────────────────────────────────────────┐
    │               RUNTIME (evaluación)                    │
    │                                                       │
    │  CAPA A — XACML 3.0             CAPA B — Operativa   │
    │  privilege_atom_policy           ath_policy_d1..d12   │
    │  (6,782 políticas)              (~100 políticas)      │
    │  ↓                               ↓                    │
    │  bauth.policy.evaluate           bauth.policy.domain  │
    │  + bauth.access.evaluate           .evaluate          │
    │                                                       │
    │  Ambas capas convergen en:                            │
    │  PolicyEngine::evaluate(rules, context) → verdict     │
    └───────────────────────────────────────────────────────┘
```

---

*BAUTH-AUDITORIA-DDL-POLITICAS.md v1.0 · 2026-06-30*
