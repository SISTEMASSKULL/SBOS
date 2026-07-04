# PLAN-ACCION-DDL.md — Plan de Acción del Dominio Lógico (D1)

**Versión:** 1.0 · **Fecha:** 2026-06-24 · **Autor:** sbos-coordinador
**Alcance:** Solo Dominio Lógico (D1) — lo planificado hasta ahora. 41 tablas + 27 seeds.
**DDL trabajo:** `BauthAgent/db/migrations/DDL_skSBOS_db_test.sql` ← **TRABAJAMOS AQUÍ**  
**DDL producción:** `BauthAgent/db/migrations/DDL_skSBOS_db.sql` ← **NO TOCAR hasta verificar**  

**Flujo:** `DDL_test → VPS → verificar → merge a DDL real`

---

## 0. REGLA DE ORO — DATOS REALES, NO PRUEBAS

**⚠️ Los datos actualmente en la VPS (13.140.128.230) son datos de prueba tipo universidad.**
**NO SIRVEN para producción. NO se migran. NO se usan como referencia.**

Todos los seeds deben construirse desde CERO usando exclusivamente:
- Estándares internacionales verificados al 2026 (NIST, ISO, RFC, IANA)
- Catálogos oficiales (SAP ACTVT, Odoo res.groups, Tryton modules, ISO 4217, IANA TZ)
- Código Rust existente en `BauthAgent/src/bitmask/catalog.rs` (SEED_DOMAINS)
- JSONs del Framework de Autenticación (`Authentication_Framework.json`, `Policies_Authentication_Framework.json`)
- Documentos de planificación de este proyecto (Manual D1, Catálogo de Roles, Seed Plan)

**Cada seed cita su fuente exacta en `BAUTH-SEED-PLAN.md` §7.4. Sin fuente = no se construye.**

---

## 1. ESTADO ACTUAL DEL D1

| Métrica | Valor |
|---------|-------|
| Tablas en DDL nueva | 33 (revisadas + nuevas de dominios D2-D3) |
| Tablas planificadas D1 (no en DDL aún) | 3 (menu_item, menu_context, menu_item_atom) |
| Tablas selección templates (no en DDL aún) | 5 (account_type, gender, marital_status, id_document_type, employment_type) |
| **Total tablas D1** | **41** |
| ENUMs en DDL | 32 |
| ENUMs planificados nuevos | ~10 |
| Seeds creados | 4 |
| Seeds planificados | 23 |

---

## 2. FASES DE EJECUCIÓN

### FASE 1 — AGREGAR TABLAS NUEVAS A DDL (8 tablas · 1h)

#### 1a — Sistema de Menús (3 tablas + 1 ENUM)
| # | Tabla | Schema | Fuente |
|---|-------|--------|--------|
| M01 | `menu_item` | bauth | BAUTH-090-MENU-SYSTEM-SPEC.md §4.1 |
| M02 | `menu_context` | bauth | BAUTH-090-MENU-SYSTEM-SPEC.md §4.2 |
| M03 | `menu_item_atom` | bauth | BAUTH-090-MENU-SYSTEM-SPEC.md §4.3 |

**ENUM:** `menu_type_enum` ('HIERARCHICAL','CONTEXTUAL')

#### 1b — Datos de Selección para Templates (5 tablas + 5 ENUMs)
| # | Tabla | Schema | Fuente |
|---|-------|--------|--------|
| N01 | `account_type` | bauth | SCIM 2.0 RFC 7643 |
| N02 | `gender` | bauth | ISO/IEC 5218 |
| N03 | `marital_status` | bauth | Normativa civil LATAM |
| N04 | `id_document_type` | bauth | Normativa migratoria LATAM |
| N05 | `employment_type` | bauth | OIT |

**ENUMs (5):** account_type_enum, gender_enum, marital_status_enum, id_document_type_enum, employment_type_enum

---

### FASE 2 — CREAR ENUMs FALTANTES (10 ENUMs · 0.5h)

```
menu_type_enum          → HIERARCHICAL, CONTEXTUAL
account_type_enum       → HUMAN, SERVICE, SYSTEM, GUEST
gender_enum             → M, F, NB, NR
marital_status_enum     → SINGLE, MARRIED, DIVORCED, WIDOWED, NR, CIVIL_UNION, SEPARATED
id_document_type_enum   → DNI, PASSPORT, CI, RUT, CURP, NIT, CÉDULA, CARNET_EXTRANJERÍA,
                          LICENCIA_CONDUCIR, PERMISO_RESIDENCIA, REGISTRO_CIVIL, OTRO
employment_type_enum    → FULL_TIME, PART_TIME, CONTRACTOR, INTERN, TEMPORARY, CONSULTANT, FREELANCE
role_type_enum          → TYPE-OPERATIVO, TYPE-SUPERVISOR, TYPE-GERENCIA-MEDIA,
                          TYPE-DIRECCION, TYPE-ADMIN-SISTEMA, TYPE-SERVICIO,
                          TYPE-AUDITORIA, TYPE-COMERCIAL, TYPE-TÉCNICO
```

---

### FASE 3 — CREAR SEEDS (23 seeds · 4h)

En orden de dependencias:

```
TANDA 1 — Vocabulario Base (4 seeds · independientes):
  P01  seed_privilege_domain.sql        (12 dominios D1-D12)
  P02  seed_privilege_verb.sql          (~50 verbos)
  P05  seed_privilege_application.sql   (12 apps)
  P06  seed_privilege_group.sql         (~40 grupos)

TANDA 2 — Átomos y Políticas (2 seeds · dependen de TANDA 1):
  P03  seed_privilege_atom.sql          (~1059 átomos)
  P04  seed_privilege_atom_policy.sql   (~6782 políticas)

TANDA 3 — Catálogos y Menú (8 seeds):
  P10  seed_log_zone.sql                (29 áreas)
  P12  seed_idn_role_template.sql       (~340 roles)
  P17  seed_idn_tier_policy.sql         (4 tiers × 12 dominios)
  M01  seed_menu_context.sql            (~38 entradas: 6 base + 32 ENUMs)
  M02  seed_menu_item.sql               (~50 ítems jerárquicos)
  C01  seed_cal_calendar.sql            (6 calendarios sistema)
  C02  seed_cal_schedule.sql            (2 horarios base)
  C03  seed_cal_holiday.sql             (feriados Bolivia + LATAM)

TANDA 4 — Autenticación + Financiero + Templates (9 seeds):
  P18  seed_ath_method.sql              (41 métodos)
  P19  seed_ath_policy.sql              (~10 políticas)
  P20  seed_ath_config.sql              (~5 configs)
  C04  seed_fin_transaction_type.sql    (~20 tipos)
  N01  seed_account_type.sql            (4 tipos)
  N02  seed_gender.sql                  (4 opciones)
  N03  seed_marital_status.sql          (7 estados)
  N04  seed_id_document_type.sql        (~12 tipos)
  N05  seed_employment_type.sql         (7 tipos)
```

---

### FASE 4 — VERIFICACIÓN VPS (1h)

Cada seed × 3 ejecuciones idempotentes:
- Conteo de registros estable
- UUIDs no nulos
- FKs resueltas
- 0 errores en 2ª y 3ª ejecución

---

## 3. RESUMEN

| Fase | Qué | Cantidad | Horas |
|------|-----|----------|-------|
| F1 | Agregar tablas NUEVAS a DDL | 8 tablas + 6 ENUMs | 1h |
| F2 | ENUMs faltantes | ~10 ENUMs | 0.5h |
| F3 | Crear seeds | 23 seeds en 4 tandas | 4h |
| F4 | Verificación VPS | ×3 ejecuciones | 1h |
| **TOTAL** | | **8 tablas + 10 ENUMs + 23 seeds** | **~6.5h** |

---

## 4. ORDEN DE EJECUCIÓN

```
F1 → F2 → TANDA 1 → TANDA 2 → TANDA 3 → TANDA 4 → F4
```

**No empezar TANDA 2 sin TANDA 1 completa.**  
**Cada TANDA se verifica en VPS antes de pasar a la siguiente.**

---

*Plan generado 2026-06-24. Dominio Lógico (D1) únicamente.*
