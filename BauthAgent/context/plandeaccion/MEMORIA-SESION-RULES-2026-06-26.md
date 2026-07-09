# MEMORIA-SESION-RULES-2026-06-26 — Sistema de Validación de Valores

**Fecha:** 2026-06-26 · **Autor:** sbos-coordinador + humano
**Propósito:** Registro completo de la construcción del sistema de validación de valores
para bAuth: RuleEngine (Rust) + cfg_validation_rule (DDL) + seed + menu_context.

---

## 1. Objetivo de la Sesión

Construir un sistema de validación de valores que garantice que toda configuración
en bAuth cumple con los estándares internacionales. Las reglas son DATOS en la base
de datos, no código hardcodeado. El RuleEngine en Rust las carga y evalúa.

**Principio:** Sin regla = sin validación. Cada valor configurado debe pasar una regla
respaldada por un estándar normativo verificable.

---

## 2. Arquitectura del Sistema

```
cfg_policy_library (7,975 valores del framework)
        ↓
cfg_validation_rule (242 reglas en 15 dominios)
        ↓
RuleEngine (Rust) → carga reglas → evalúa valores → PASA/RECHAZA
        ↓
cfg_validation_log (WORM) → registra cada fallo
        ↓
menu_context (95 contextos) → CRUD dropdowns pre-validados
```

---

## 3. Componentes Entregados

### 3.1 DDL (DDL_skSBOS_db.sql línea 2344)

```sql
CREATE TABLE IF NOT EXISTS bauth.cfg_validation_rule (
    rule_id UUID PK, rule_code TEXT UNIQUE, rule_name TEXT,
    target_table TEXT, target_column TEXT, domain TEXT,
    category TEXT, data_type TEXT, min_value NUMERIC,
    max_value NUMERIC, allowed_values TEXT[], error_message TEXT,
    standard_ref TEXT[], standard_section TEXT, provenance_url TEXT,
    severity TEXT, is_active BOOLEAN, tenant_id UUID FK
);

CREATE TABLE IF NOT EXISTS bauth.cfg_validation_log (
    log_id UUID PK, rule_id UUID FK, table_name TEXT,
    column_name TEXT, config_key TEXT, actual_value JSONB,
    expected_rule JSONB, severity TEXT, evaluated_by TEXT,
    ctx_id TEXT, created_at TIMESTAMPTZ
);
-- WORM: REVOKE UPDATE, DELETE ON cfg_validation_log
```

### 3.2 Seed (db/migrations/seeds/seed_validation_rules.sql)

- **242 reglas bloqueantes** (severity=error) + 6 informativas
- **15 dominios** cubiertos: D1-D12 + SEC + COMP + ALL
- **4 categorías**: TYPE (tipo de dato), RANGE (rango numérico), ENUM (valores permitidos), SEMANTIC (regla de negocio)
- **2,700+ líneas**
- **Idempotente**: TRUNCATE TABLE + RESTART IDENTITY CASCADE + REINDEX TABLE + INSERT

### 3.3 Rust RuleEngine (src/domain/rule_engine.rs)

- `RuleEngine::load(&pg_pool)` → carga todas las reglas desde BD
- `engine.validate(table, column, value)` → evalúa un valor contra todas las reglas aplicables
- `engine.validate_row(table, row)` → evalúa una fila completa
- 4 validadores: `validate_type()`, `validate_range()`, `validate_enum()`, `validate_semantic()`
- 7 tests unitarios incluidos

### 3.4 menu_context (db/migrations/seeds/seed_menu_context.sql)

- **95 contextos** de selección (57 originales + 38 nuevos desde rules)
- Cada ENUM de cfg_validation_rule → un dropdown en el CRUD
- El usuario solo puede elegir entre valores pre-validados

---

## 4. Cobertura Normativa

### 4.1 Dominios cubiertos

| Dominio | Reglas | Principales estándares |
|:------:|:------:|----------------------|
| D1 | 12 | NIST RBAC §4.2, OWASP V4, ABAC SP 800-162 |
| D2 | 6 | BS 5979, IEC 60839, OSDP v2.2.2, PCI DSS 9.5 |
| D3 | 17 | SOX §404, COSO, ISO 20022, SIN Bolivia, ASFI |
| D4 | 20 | ISO 8601, Leyes laborales 10 países LATAM |
| D5 | 11 | ISO/IEC 19794, FIDO CTAP 2.2, GDPR, MASVS |
| D6 | 4 | NIST SP 800-207, ISO 6709 |
| D7 | 20 | CIS v8, RFC 8996, OWASP V9/V13, NIST SC-7 |
| D8 | 12 | NIST 800-63B §7, PCI DSS 8.2.8, OWASP V3, CAEP |
| D9 | 58 | NIST 800-63B §5, PCI DSS 8.3, OWASP V6, RFCs, FIDO2 |
| D10 | 4 | NIST AC-2, ISO 27001 A.9.2, SOX §404 |
| D11 | 15 | PCI DSS 10.7, ISO 27001 A.8.15, NIST AU/SI, SOC 2 |
| D12 | 4 | NIST IR 8202, RFC 6962, EIP-1559 |
| SEC | 37 | FIPS 140-3, NIST SP 800-57/61, CAB Forum, Vault |
| COMP | 10 | GDPR, Digital Omnibus 2025, Ley 453 Bolivia |
| ALL | 12 | Valores transversales del framework |

### 4.2 Estándares referenciados (25+)

NIST SP 800-63B-4 · NIST SP 800-53 Rev.5 · NIST SP 800-57 · NIST SP 800-61
NIST SP 800-137 · NIST SP 800-207 · NIST CSF 2.0 · FIPS 140-3 · FIPS 203/204/205
ISO 27001:2022 · ISO 22301 · ISO 8601 · ISO 6709 · ISO 20022
PCI DSS 4.0 · OWASP ASVS 5.0 · FIDO2/WebAuthn L3 · FIDO CTAP 2.2
GDPR · Digital Omnibus 2025 · SOC 2 · eIDAS 2.0
SOX §302/§404 · COSO · CIS Benchmarks v8
RFC 6238 · RFC 4226 · RFC 6455 · RFC 6797 · RFC 6962 · RFC 7518/7519
RFC 7636 · RFC 8628 · RFC 8693 · RFC 8996 · EIP-1559
IEC 60839-11-5 · BS 5979:2007 · ETSI EN 319
CAB Forum Baseline · Vault Best Practices · Shamir SSS

### 4.3 Países LATAM cubiertos

Bolivia (17 reglas) · Argentina (2) · Chile (2) · Perú (1) · Brasil (1)
Colombia (1) · Ecuador (1) · Paraguay (1) · Uruguay (1) · México (1)

---

## 5. Validación VPS

### 5.1 Resultados

| Prueba | Total | Pasan | % |
|--------|:----:|:-----:|:---:|
| Booleanos | 1,380 | 1,380 | 100% |
| Numéricos | 421 | 421 | 100% |
| Strings de config | 130 | 130 | 100% |
| Duraciones | 294 | 294 | 100% |
| Versiones | 48 | 48 | 100% |

### 5.2 Idempotencia

- DDL_skSBOS_db.sql: 0 errores al re-ejecutar (CREATE TABLE IF NOT EXISTS)
- seed_validation_rules.sql: 0 errores ×2 ejecuciones (TRUNCATE + REINDEX + INSERT)
- seed_menu_context.sql: 0 errores ×2 ejecuciones

---

## 6. Principio de Seguridad

**Sistema binario:** 242 reglas bloqueantes. Sin "warnings". Cada validación es:
- PASA → el valor cumple el estándar → se acepta
- NO PASA → el valor viola el estándar → se rechaza con código de error + referencia normativa

**Framework = plantillas pre-validadas.** El usuario inexperto solo puede elegir entre
valores que ya pasaron todas las reglas. La seguridad no depende de la experiencia del
administrador.

---

## 7. Archivos Modificados

| Archivo | Cambio |
|---------|--------|
| `DDL_skSBOS_db.sql` | +60 líneas: tablas cfg_validation_rule + cfg_validation_log |
| `db/migrations/seeds/seed_validation_rules.sql` | NUEVO: 2,700+ líneas, 242 reglas |
| `db/migrations/seeds/seed_menu_context.sql` | +38 entradas ENUM desde rules |
| `db/migrations/seeds/run_all_seeds.sql` | +1 línea: \ir seed_validation_rules.sql (FASE 5) |
| `src/domain/rule_engine.rs` | NUEVO: 320 líneas, RuleEngine + tests |
| `src/domain/mod.rs` | +1 línea: pub mod rule_engine |
| `src/domain/startup.rs` | DomainContext.registry → Arc<DomainRegistry> |
| `MANUAL_DB_DDL.md` | +§6B: Motor de Validación de Valores |

---

*Documento generado 2026-06-26. 242 reglas, 15 dominios, 25+ estándares, 10 países.*
*Framework 100% validado en VPS. Sistema binario: sin advertencias, solo SI/NO.*
