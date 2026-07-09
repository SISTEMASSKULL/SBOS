# PLAN DE RECONSTRUCCIÓN — DDL Profesional bAuth

**Versión:** 6.0.0 · **Fecha:** 2026-06-23 · **Autor:** sbos-coordinador  
**Base de datos destino:** `skSBOS_db` · **Schema de bAuth en producción actual:** `bauth`, `bos_blockchain`, `bos_privilege` → **Schema propuesto:** `bAuth` (único, consolidado dentro de `skSBOS_db`)  
**Estándares:** ISO 27001 · NIST 800-63B-4 · PCI DSS 4.0 · OWASP ASVS 5.0 · RFC 9562 · W3C Trace Context  
**Documentos vinculados:** `BAUTH-IDENTITY-GOVERNANCE-AUDIT-PLATFORM.md` v4.0.0 · `BAUTH-IDENTITY-GOVERNANCE-GAPS.md` v2.0.0 · `BAUTH-IDENTITY-GOVERNANCE-AUDIT-REPORT.md` v1.0.0 · `MANUAL-HOT-DDL-PRODUCCION.md` v1.0.0  
**Audit Score:** PROD 9% → .BAK 39% → PLATAFORMA 100%  
**DDL Construido:** 5 tablas · 7 ENUM types · 196 países seed · 41 monedas seed

---

## 0. Los Tres Estados de la Base de Datos

La reconstrucción opera sobre **tres estados distintos** que representan la evolución
de la base de datos hacia la Identity Governance & Audit Platform.

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    TRANSICIÓN DE ESTADOS                                  │
│                                                                          │
│  ESTADO 1               ESTADO 2               ESTADO 3                  │
│  PRODUCCIÓN             .BAK                   PLATAFORMA                │
│  (bauth_db VPS)         (archivo DDL)          (Identity Governance)     │
│                                                                          │
│  ┌────────────────┐    ┌────────────────┐    ┌──────────────────────┐   │
│  │ 85 tablas      │    │ 103 tablas     │    │ 112+ tablas          │   │
│  │ 0 FKs       ❌ │    │ 113 FKs     ⚠️ │    │ 113+ FKs UUID→UUID✅│   │
│  │ 11 ctx_id   ❌ │──►│ 25 ctx_id   ⚠️ │──►│ 45+ ctx_id         ✅│   │
│  │ 1 hash-chain❌ │    │ 2 hash-chains  │    │ 8+ hash-chains    ✅│   │
│  │ 32 BIGINT PK❌ │    │ 2 BIGINT PK ⚠️ │    │ 0 BIGINT PK       ✅│   │
│  │ 27 TEXT PK  ❌ │    │ ~10 TEXT PK ⚠️ │    │ 0 TEXT PK*        ✅│   │
│  │ 25 UUID PK  ❌ │    │ 48 UUID PK  ⚠️ │    │ 103 UUID PK       ✅│   │
│  │ 0 tablas ITDR❌ │    │ 0 tablas ITDR  │    │ 3 tablas ITDR     ✅│   │
│  │ 3 particiones  │    │ 3 particiones  │    │ 10+ particiones   ✅│   │
│  │                │    │                │    │                      │   │
│  │ Score: ~9%     │    │ Score: ~39%    │    │ Score: 100%         │   │
│  └────────────────┘    └────────────────┘    └──────────────────────┘   │
│                                                                          │
│  *excepto natural keys ISO (CHAR(2)/CHAR(3))                             │
└──────────────────────────────────────────────────────────────────────────┘
```

### 0.1 ESTADO 1 — PRODUCCIÓN (`bauth_db` en VPS · PostgreSQL 18.4)

**Fuente de verdad actual.** Base de datos operativa en el cluster K8s de la VPS
`13.140.128.230`. Es lo que existe HOY y lo que hay que reparar.

| Característica | Valor | Problema |
|---------------|-------|----------|
| **Tablas** | 85 (76 bauth + 7 bos_privilege + 2 bos_blockchain) | Faltan tablas del calendario, notificación, retención |
| **Schemas** | 3: `bauth`, `bos_blockchain`, `bos_privilege` | Deben consolidarse en `bAuth` |
| **Foreign Keys** | **0** | Sin integridad referencial. Los datos pueden tener huérfanos. |
| **ctx_id** | 11 columnas en 85 tablas (13%) | No hay trazabilidad W3C en el 87% de las operaciones |
| **PK Tipo** | 32 BIGINT + 27 TEXT + 25 UUID + 1 CHAR | Predominan tipos no-UUID. Sin estandarización. |
| **Hash-chains** | 1 (`bos_audit_events`) | Solo la tabla de auditoría tiene integridad criptográfica |
| **Particiones** | 3 (audit_events + 2 futuras) | Sin auto-particionamiento |
| **ITDR** | 0 tablas | Sin motor de notificaciones |
| **WORM** | 3 tablas con REVOKE | Insuficiente para cumplimiento PCI DSS |
| **Score** | **~9%** | |

**Datos reales verificados 2026-06-23 vía `kubectl exec` en VPS.**

### 0.2 ESTADO 2 — .BAK (`001_bauth_init.sql.bak`)

**Plano de migración intermedia.** Archivo de 2,288 líneas generado durante la primera
fase de estandarización UUID. Contiene la migración parcial de tipos y las REFERENCES
restauradas pero luego perdidas por `sed`.

| Característica | Valor | Diferencia vs PROD |
|---------------|-------|-------------------|
| **Tablas** | 103 | +18 tablas (nuevas) |
| **Foreign Keys** | 113 | +113 FKs (recuperables) |
| **ctx_id** | 25 columnas | +14 columnas |
| **UUID PKs** | 48 | +23 PKs migradas |
| **BIGINT PKs** | 2 (audit_events, login_attempt) | −30 PKs migradas |
| **TEXT PKs** | ~10 (natural keys ISO) | −17 PKs migradas |
| **Hash-chains** | 2 | +1 (rol_template_history) |
| **Score** | **~39%** | +30 puntos |

**Problema del .bak:** Perdió las REFERENCES por una limpieza con `sed`. Las 113 FKs
están en el archivo pero como texto comentado o eliminado. También tiene 73 ALTER TABLE
sin integrar en CREATE TABLE y un bug de sintaxis en `superuser_contexts`.

### 0.3 ESTADO 3 — PLATAFORMA (Identity Governance & Audit Platform)

**Meta final.** Definida en `BAUTH-IDENTITY-GOVERNANCE-AUDIT-PLATFORM.md` v4.0.0.
Cumple los 12+ estándares internacionales. Es el destino de la reconstrucción.

| Característica | Valor | Estándar que lo requiere |
|---------------|-------|-------------------------|
| **Tablas** | 112+ | Incluye bCalendar (7), ITDR (3), audit_evidence (1), retención (1) |
| **Foreign Keys** | 113+ UUID→UUID | ISO 27001 A.8.15, integridad referencial |
| **ctx_id** | 45+ tablas (≥44%) | SBOS-049 §3, W3C Trace Context |
| **Hash-chains** | 8+ tablas WORM | PCI DSS 4.0 Req 10.3.2 |
| **UUID PKs** | 103 (100%) | RFC 9562 |
| **Particiones** | 10+ tablas | PCI DSS 10.7 |
| **ITDR** | 3 tablas | ISO 27001 A.8.16, NIST 800-53 AU-7 |
| **WORM (REVOKE)** | 8+ tablas | ISO 27001 A.8.15 |
| **GIN indexes** | 8+ | Rendimiento de consultas JSONB |
| **Retention** | `cfg_retention_policy` + función | PCI DSS 10.7.1, GDPR Art.17 |
| **Score** | **100%** | |

### 0.4 Estrategia de Transición

```
PRODUCCIÓN (9%)  ──FASE A──►  .BAK corregido (39%→70%)  ──FASE B──►  PLATAFORMA (100%)
                                                           │
                              ┌────────────────────────────┘
                              │
                 FASE A: Reconstrucción del .bak
                    • Recuperar REFERENCES (5 fases A→E)
                    • Integrar 73 ALTER TABLE en CREATE TABLE
                    • Migrar 2 BIGINT PK a UUID
                    • Corregir bug superuser_contexts
                    • Re-escribir build_ddl.sh

                 FASE B: Identity Governance
                    • Crear 3 tablas ITDR + audit_evidence
                    • Expandir CHECK a 76 event_types
                    • ctx_id en 20+ tablas
                    • Hash-chains en 6+ tablas WORM
                    • Particionar 7+ tablas
                    • Retention policy + partition_maintenance()

                 FASE C: Aplicar a producción
                    • DROP + CREATE en bauth_test
                    • Verificar 0 errores + idempotencia
                    • Migración controlada a bauth_db
```

**Cada FASE tiene tareas específicas en §7 (Plan de Ejecución por Fases).**

### 0.5 DDL Construido — Progreso Real

| # | Schema | Tabla | PK | Cols | Línea DDL | Origen | Seed |
|---|--------|-------|-----|------|-----------|--------|------|
| 001 | bauth | idn_tenant | UUIDv7 | 45 | 623 | bos_tenant | — |
| 002 | bglobal | global_currency | UUIDv7 | 17 | 366 | bos_moneda | 45 monedas |
| 003 | bglobal | global_language | UUIDv7 | 19 | 109 | bos_idioma | 125 idiomas |
| 004 | bglobal | global_country | UUIDv7 | 36 | 273 | bos_pais | 196 países |
| 005 | bglobal | geo_timezone | UUIDv7 | 16 | 473 | bos_timezone | 319 zonas |
| 006 | bauth | idn_tenant_currencies | UUIDv7 | 12 | 882 | bos_tenant_currency | Sin seed |
| 007 | bauth | idn_tenant_languages | UUIDv7 | 11 | 931 | bos_tenant_language | Sin seed |
| 009 | bauth | idn_tenant_verification | UUIDv7 | 11 | 1054 | bos_tenant_verification | Sin seed |
| 010 | bauth | idn_tenant_config | UUIDv7 | 32 | 1145 | bos_tenant_config | Sin seed |

**Reglas aplicadas:**
- PostgreSQL 18.4: lowercase unquoted identifiers, uuidv7() nativo, skip scan indexes
- ENUM types: 22 dominios (tenant_status_enum, language_scope_enum, text_direction_enum, translation_status_enum, etc.)
| 011 | bauth | idn_tenant_domain | UUIDv7 | 23 | 1330 | bos_tenant_domain | Sin seed |
- COMMENT ON: 100% columnas documentadas con estándar normativo
| 012 | bauth | idn_tenant_network | UUIDv7 | 13 | 1478 | bos_tenant_network | Sin seed |
- Semillas idempotentes: TRUNCATE RESTART IDENTITY CASCADE + REINDEX + INSERT
| 013 | bcalendar | cal_fiscal_year | UUIDv7 | 18 | 1538 | bos_tenant_gestion | Sin seed |
| 014 | bauth | idn_calendar_assignment | UUIDv7 | 9 | 1632 | NUEVA | Sin seed |
| 015 | bcalendar | cal_calendar | UUIDv7 | 11 | 1664 | NUEVA | Sin seed |
| 016 | bcalendar | cal_event | UUIDv7 | 15 | 1695 | NUEVA | Sin seed |
| 017 | bcalendar | cal_alarm | UUIDv7 | 11 | 1732 | NUEVA | Sin seed |
| 018 | bcalendar | cal_notification_log | UUIDv7 | 8 | 1763 | NUEVA | WORM |
| 019 | bcalendar | cal_holiday | UUIDv7 | 9 | 1791 | NUEVA | Seed BO |
| 020 | bcalendar | cal_schedule | UUIDv7 | 10 | 1817 | NUEVA | Sin seed |
| 021 | bauth | fis_location | UUIDv7 | 15 | 1863 | bos_sitio_fisico+bos_edificio+bos_piso+bos_area_fisica | Sin seed (closure table) |
- Hot Migration: MANUAL-HOT-DDL-PRODUCCION.md

**Archivos generados:**
| Archivo | Contenido |
|---------|-----------|
| `DDL_skSBOS_db.sql` | DDL limpio con 5 tablas |
| `seeds/seed_global_country.sql` | 196 países (ONU + observadores) |
| `seeds/seed_global_currency.sql` | 41 monedas ISO 4217 |
| `build_ddl.sh` v9 | 3 fases independientes |
| `001_bauth_init_CORREGIDO.sql.bak` | .bak con 26 REFERENCES restauradas |

---

| # | Principio | Descripción |
|---|-----------|-------------|
| P1 | **DDL solo CREATEs** | Sin ALTER TABLE, sin INSERTs, sin valores hardcodeados |
| P2 | **Seeds independientes** | Datos de población en archivos `.sql` separados, idempotentes |
| P3 | **Orden topológico** | Tablas creadas en orden de dependencia (padres antes que hijas) |
| P4 | **Base de datos de prueba** | `bauth_test` — nunca tocar `bauth_db` de producción |
| P5 | **Iteración hasta 0 errores** | DROP + CREATE + SEED → corregir → repetir |
| P6 | **Idempotencia post-implementación** | Segundas ejecuciones = solo NOTICEs, 0 ERRORes |

---

## 1. Estado Actual de la Base de Datos (VPS Producción)

### 1.1 Schemas por Propósito (estado actual en VPS producción)

| Schema | Tablas | Propósito | Acción |
|--------|--------|-----------|--------|
| **bauth** | ~83 | Núcleo de identidad: tenants, usuarios, roles, auth, sesiones, finanzas, seguridad, auditoría, configuración | Renombrar a `bAuth` + aplicar prefijos funcionales |
| **bos_blockchain** | 7 | D12 Blockchain: Merkle anchoring + liquidación Besu QBFT | Consolidar en `bAuth` con prefijo `blk_` |
| **bos_privilege** | 11 | Motor de privilegios: átomos, roles, políticas, verbos, aplicaciones | Consolidar en `bAuth` con prefijo `privilege_` |

### 1.2 Agrupación de Tablas por Propósito (Schema bauth)

| Grupo | Tablas | Propósito |
|-------|--------|-----------|
| **Tenant/Empresa** | tenant, tenant_config, tenant_verification, tenant_domain, tenant_network, tenant_currency, tenant_language, tenant_gestion, empresa, sucursal, pos_logico, pais, ciudad, moneda, idioma, timezone | Jerarquía organizacional y geografía |
| **Roles** | rol_template, rol_template_history, tier_policy, sod_conflict_matrix, rol_closure | Sistema de roles y herencia DAG |
| **Usuarios** | user_template, user_consent, user_role_assignment, recovery_method, recovery_challenge | Identidad digital de actores |
| **Autenticación** | auth_method, auth_policy, auth_config, mfa_enrollments, password_history, biometric_templates, credential_policy, credential_rotation_log, auth_method_enrollment_log, token_delivery_log | Framework de autenticación |
| **Autorización** | permiso_logico, zona_logica, zone_application_map, domain_config, global_config | Control de acceso |
| **Sesiones** | context_sessions, context_switches | Context Plane (SBOS-049) |
| **Finanzas** | financial_limit, financial_decision_matrix, financial_approval, financial_document_operation, financial_role_permission, financial_tipo_transaccion | Dominio financiero (D3) |
| **Físico** | sitio_fisico, edificio, piso, area_fisica, dispositivo_fisico | Dominio físico (D2) |
| **Seguridad** | authenticator_binding, authenticator_revocation, login_attempt, password_screening_log, superuser_contexts, key_inventory, key_recovery_log, key_rotation_log, backup_log, device_registry, vdi_profiles | Seguridad avanzada |
| **Sync** | sync_log, delegation_log | Sincronización KC+Tryton, delegaciones |
| **Framework** | compliance_map, crypto_algorithm, federation_protocol, saga_catalog, saga_step, saga_execution, framework_version | Framework declarativo |
| **Auditoría** | audit_events, access_reviews, ghost_accounts, policy_audit, policy_history, schedule | Auditoría y cumplimiento |


### 1.3 Tablas del Motor de Privilegios (schema actual: `bos_privilege`)

El motor de privilegios (PrivilegeEngine) está actualmente en el schema separado `bos_privilege`. En la reconstrucción, estas tablas se consolidan dentro de `bAuth` conservando el prefijo `privilege_`.

| Tabla | Propósito |
|-------|-----------|
| privilege_domain | 12 dominios de soberania D1-D12 |
| privilege_verb | Vocabulario global de verbos (CRUD) |
| privilege_application | Aplicaciones registradas |
| privilege_group | Grupos funcionales por app |
| privilege_atom | Catalogo de atomos (1059 registros) |
| privilege_policy | Politicas JSONB por atomo (6782 registros) |
| privilege_audit | Auditoria WORM de evaluaciones |
| privilege_role | Roles base por tenant |
| privilege_role_atom | Asignacion rol↔atomo (BitMask relacional) |

### 1.4 Tablas Blockchain D12 (schema actual: `bos_blockchain`)

Las tablas de blockchain están actualmente en el schema separado `bos_blockchain`. En la reconstrucción, se consolidan dentro de `bAuth` conservando el prefijo `blk_`.

| Tabla | Propósito |
|-------|-----------|
| blk_merkle_batch | Lotes Merkle para anclaje |
| blk_merkle_leaf | Hojas del arbol Merkle |
| blk_anchor_log | Historico de anclajes en L2 |
| blk_anchor_reconciliation | Verificacion cross-chain |
| blk_account | Cuentas on-chain (Variante B) |
| blk_settlement | Liquidaciones on-chain |
| blk_reconciliation | Reconciliacion on-chain↔DB |
## 2. Arquitectura de Schemas y Prefijos

### 2.0 Base de Datos y Convención de Nombres

| Elemento | Nombre | Regla |
|----------|--------|-------|
| **Base de datos** | `skSBOS_db` | Nombre canónico del proyecto |
| **Convención schemas** | `b` + `Mayúscula` + `minúsculas` | Ej: `bAuth`, `bGlobal`, `bKernel` |
| **Excepción** | `bos` | El dominio BOS gobierna todo, conserva su nombre |

### 2.1 Principio Rector

> **Cada daemon del SBOS tiene su propio schema con formato `bXxxx`. Las tablas dentro se agrupan por bounded context (DDD) mediante prefijos de 3 letras.**

### 2.2 Schemas del Ecosistema

| Schema | Daemon | Propósito | Prefijos |
|--------|--------|-----------|----------|
| **bAuth** | bAuth | Núcleo de identidad y Context Plane | idn_, ath_, ses_, fin_, aud_, sec_, geo_, cfg_, blk_, privilege_ |
| **bKernel** | bKernel | Data Kernel CDC (futuro) | — |
| **bSearch** | bSearch | Motor de búsqueda (futuro) | — |
| **bNexus** | bhnexus | Nexus Host (futuro) | — |
| **bNotif** | bnotify | Notificaciones (futuro) | — |

### 2.3 Prefijos del Schema bauth — 12 Dominios de Soberanía (D1-D12)

Los 12 dominios de soberanía definidos en `privilege_domain` y el motor BitMask (D1-D12) se
materializan en la DDL como prefijos funcionales. Cada prefijo agrupa las tablas de un dominio.

**Dominios de Soberanía (orden de evaluación BitMask: D8→D9→D1→D3→D2→D10→D4→D6→D7→D5→D12→D11):**

| D# | Dominio | Prefijo | Fast/Policy | Tablas | Significado |
|----|---------|---------|-------------|--------|-------------|
| D1 | Lógico | `log_` | Fast-Path | — | Apps y recursos digitales. Verbo suficiente. |
| D2 | **Físico** | **`fis_`** | Fast-Path | 7 | Zonas y hardware. OSDP Secure Channel AES-128. |
| D3 | Financiero | `fin_` | Policy-Path | 6 | Límites, SoD, dual-approval. |
| D4 | Temporal | `tmp_` | Policy-Path | — | Horarios, turnos, feriados. Encadenado a D1. |
| D5 | Biométrico | `bio_` | External | — | Huella, rostro, iris vía Keycloak. |
| D6 | **Geoespacial** | **`geo_`** | Policy-Path | 2 | Ubicación, viaje imposible (900 km/h). Solo global_country y geo_timezone en bglobal. |
| D7 | Red | `net_` | External | — | CIDR, VPN, mTLS, device posture vía Kong. |
| D8 | Contexto | `ses_` | Pre-BitMask | 2 | ctx_id en Redis. Pre-condición del BitMask. |
| D9 | Credenciales | `cre_` | Pre-BitMask | — | Passwords, MFA, certificados vía Keycloak. |
| D10 | Delegación | `dlg_` | Policy-Path | — | Privilegios temporales. AND reduction. |
| D11 | **Auditoría** | **`aud_`** | Post-hoc | 7 | WORM. No evalúa — solo registra. |
| D12 | **Blockchain** | **`blk_`** | External | 7 | Merkle anchoring + liquidación Besu QBFT. |

**Prefijos transversales (no son dominios de soberanía, aplican a todos):**

| Prefijo | Propósito | Tablas | Significado |
|---------|-----------|--------|-------------|
| **`idn_`** | Identidad | 35 | Identity & Organization — entidades del sistema |
| **`ath_`** | Autenticación | 15 | Authentication — métodos, flujos, políticas |
| **`sec_`** | Seguridad | 9 | Security policies — transversal a todos los dominios |
| **`cfg_`** | Configuración | 4 | Configuration — parámetros del sistema |
| **`privilege_`** | Privilege Engine | 11 | Motor H-RBAC (de `bos_privilege`) |

**Total: 12 prefijos de dominio + 5 transversales = 17 prefijos.**

### 2.4 Schema bos — Motor BOS Independiente

> El daemon `bos` (IAM Installer) usará su propio schema `bos` dentro de `skSBOS_db` para sus tablas de control interno (state, fichas, sagas, logs de bootstrap). Pendiente de definir en el plan DDL de BosAgent.

### 2.5 Tabla de Clasificación — Estado Actual → Estado Propuesto

**Schema actual:** verificado en VPS (producción) — 3 schemas reales: `bauth`, `bos_blockchain`, `bos_privilege`.  
**Schema propuesto:** las tablas se distribuyen entre `bAuth`, `bGlobal` y `bCalendar` según su dominio.  
**Decisiones:**
- `bos_blockchain` y `bos_privilege` se eliminan → sus tablas migran a `bAuth`
- Catálogos ISO de uso global (idiomas, monedas, parámetros) → `bGlobal`
- Toda funcionalidad de calendario, horarios y períodos fiscales → `bCalendar`
- Filas marcadas `(nueva)` no existen en VPS — deben crearse en la reconstrucción DDL

| Schema Actual | Tabla Actual | Schema Propuesto | Tabla Propuesta | Propósito |
|--------------|-------------|-----------------|-----------------|-----------|
| bauth | bos_tenant | bAuth | idn_tenant | Entidad raíz del sistema multi-tenant |
| bauth | bos_tenant_config | bAuth | idn_tenant_config | Configuración regional: locale, timezone, moneda, idiomas soportados |
| bauth | bos_tenant_verification | bauth | idn_tenant_verification | ✅ REPARADO 2026-06-23: UUIDv7 + 2 ENUMs + ctx_id. 5 pasos KYC/IAL. Sin seed. |
| bauth | bos_tenant_domain | bauth | idn_tenant_domain | ✅ REPARADO — 65 cols: NGINX+K8s HPA+DNS+SSL+correo+contactos |
| bauth | bos_tenant_network | bauth | idn_tenant_network | ✅ REPARADO — UUIDv7 + ENUM + ctx_id. CIDR con GIST index. |
| bauth | bos_tenant_currency | bauth | idn_tenant_currencies | ✅ REPARADO 2026-06-23: PK UUIDv7 + FKs a idn_tenant y global_currency + ctx_id. Monedas habilitadas por tenant + tasas de cambio. Sin seed (depende de tenants poblados). |
| bauth | bos_tenant_language | bauth | idn_tenant_languages | ✅ REPARADO 2026-06-23: PK UUIDv7 + FKs a idn_tenant y global_language + ctx_id. Idiomas habilitados por tenant + traducción. Sin seed. |
| bauth | bos_tenant_gestion | bcalendar | cal_fiscal_year | 📋 LIMPIO — Pendiente revisión (BIGSERIAL PK + español) |
| bauth | bos_empresa | bAuth | idn_empresa | Empresa dentro del tenant |
| bauth | bos_sucursal | bAuth | idn_sucursal | Sucursal de la empresa |
| bauth | bos_pos_logico | bAuth | idn_pos | Terminal lógico (POS, caja registradora) |
| bauth | bos_user_template | bAuth | idn_usuario | Identidad digital del usuario (SCIM 2.0) |
| bauth | bos_user_consent | bAuth | idn_user_consent | Consentimientos GDPR del usuario (Art.7) |
| bauth | bos_user_role_assignment | bAuth | idn_user_role | Asignación usuario↔rol con vigencia |
| bauth | bos_rol_template | bAuth | idn_rol | Plantilla de rol (fuente de verdad del sistema) |
| bauth | bos_rol_template_history | bAuth | idn_role_history | Historial WORM SHA-256 de cambios al rol |
| bauth | bos_tier_policy | bAuth | idn_tier | Políticas NIST 800-63B-4 por tier (3NF) |
| bauth | bos_sod_conflict_matrix | bAuth | idn_sod | Matriz de Separación de Deberes (NIST AC-5) |
| bauth | bos_rol_closure | bAuth | idn_role_closure | Closure table DAG de herencia H-RBAC |
| bauth | bos_delegation_log | bAuth | idn_delegation | Delegaciones temporales de roles |
| bauth | bos_recovery_method | bAuth | idn_recovery | Métodos de recuperación de cuenta (NIST §4) |
| bauth | bos_recovery_challenge | bAuth | idn_recovery_challenge | Desafíos de recuperación hasheados (OWASP V2.5) |
| bauth | bos_permiso_logico | bAuth | idn_permiso | Permiso granular: zona lógica × verbo × rol |
| bauth | bos_zona_logica | bAuth | idn_zona | Zona de negocio lógica (ZRB) |
| bauth | bos_zone_application_map | bAuth | idn_zona_app | Mapeo zona lógica ↔ aplicación |
| bauth | bos_domain_config | bAuth | idn_domain_config | Activación/desactivación de dominios por tenant |
| bauth | bos_global_config | bAuth | idn_global_config | Parámetros globales del sistema (NIST CM-6) |
| bauth | bos_framework_version | bAuth | idn_framework_version | Versionado semántico de frameworks SSOT |
| bauth | bos_schedule | bCalendar | cal_schedule | Horarios de trabajo y turnos laborales |
| bauth | bos_gestion_calendario | bCalendar | cal_interval | Calendario de gestión contable por empresa → fusión en cal_interval |
| bauth | bos_vdi_profiles | bAuth | idn_vdi | Perfiles de escritorio virtual persistente |
| bauth | bos_ghost_accounts | bAuth | idn_ghost_account | Detección de cuentas abandonadas (ISACA) |
| bauth | bos_access_reviews | bAuth | idn_access_review | Campañas de recertificación de accesos (SOC 2) |
| bauth | bos_auth_method | bAuth | ath_method | Catálogo de 23 métodos de autenticación |
| bauth | bos_auth_policy | bAuth | ath_policy | Políticas de autenticación por tier (31 activas) |
| bauth | bos_auth_config | bAuth | ath_config | Configuración operativa del motor de autenticación |
| bauth | bos_auth_method_enrollment_log | bAuth | ath_enrollment | Registro de enrolamiento de métodos auth |
| bauth | bos_mfa_enrollments | bAuth | ath_mfa | Dispositivos MFA por usuario (TOTP, FIDO2, Passkey) |
| bauth | bos_password_history | bAuth | ath_password | Historial de contraseñas (últimas 10, NIST screening) |
| bauth | bos_password_screening_log | bAuth | ath_password_screening | Cribado HIBP k-anonymity (NIST §5.1.1) |
| bauth | bos_biometric_templates | bAuth | ath_biometric | Plantillas biométricas hasheadas (RGPD Art.9) |
| bauth | bos_credential_policy | bAuth | ath_credential | Políticas de credenciales (rotación, fortaleza) |
| bauth | bos_credential_rotation_log | bAuth | ath_credential_rotation | Rotación de credenciales por tiempo/evento |
| bauth | bos_token_delivery_log | bAuth | ath_token | Entrega de tokens de autenticación (8 canales) |
| bauth | bos_authenticator_binding | bAuth | ath_binding | Vínculo authenticator↔subscriber (NIST §5.2) |
| bauth | bos_authenticator_revocation | bAuth | ath_revocation | Revocación de authenticators (<30s, NIST §5.2.2) |
| bauth | bos_federation_protocol | bAuth | ath_federacion | Protocolos de federación (OAuth 2.1, SAML, OIDC) |
| bauth | bos_crypto_algorithm | bAuth | ath_cripto | Catálogo de 16 algoritmos criptográficos (FIPS 140-3) |
| bauth | bos_context_sessions | bAuth | ses_session | Sesión del Context Plane 6 capas (SBOS-049 §4) |
| bauth | bos_context_switches | bAuth | ses_session_switch | Historial de cambios de contexto operativo |
| bauth | bos_financial_limit | bAuth | fin_limit | Límites financieros por rol (por operación/día/mes) |
| bauth | bos_financial_decision_matrix | bAuth | fin_matrix | Matriz de decisión de aprobación (3 niveles) |
| bauth | bos_financial_approval | bAuth | fin_approval | Registro de aprobaciones financieras (dual control) |
| bauth | bos_financial_document_operation | bAuth | fin_operation | Operaciones sobre documentos financieros |
| bauth | bos_financial_role_permission | bAuth | fin_permission | Permisos financieros por rol |
| bauth | bos_financial_tipo_transaccion | bAuth | fin_transaction | Tipos de transacción financiera (ISO 20022) |
| bauth | bos_audit_events | bAuth | aud_event | Registro WORM inmutable de eventos (ISO 27001 A.8.15) — particionado por mes |
| bauth | bos_audit_events_2026_07 | bAuth | aud_event_2026_07 | Partición Julio 2026 de aud_event |
| bauth | bos_audit_events_2026_08 | bAuth | aud_event_2026_08 | Partición Agosto 2026 de aud_event |
| bauth | bos_sync_log | bAuth | aud_sync | Registro de sincronización bAuth→KC+Tryton (WORM) |
| bauth | bos_policy_audit | bAuth | aud_policy_audit | Auditoría WORM de cambios de políticas (ISO 27001 A.8.9) |
| bauth | bos_policy_history | bAuth | aud_policy_history | Historial versionado de políticas para rollback |
| bauth | bos_backup_log | bAuth | aud_backup | Registro de backups (ADR-016, SHA-256) |
| bauth | bos_login_attempt | bAuth | aud_login_attempt | Intentos de login exitosos/fallidos (NIST AC-7) — particionado por mes |
| bauth | bos_superuser_contexts | bAuth | aud_superuser | Activaciones break-glass SU (ISO 27001 A.8.2) |
| bauth | bos_key_inventory | bAuth | sec_key | Inventario de llaves criptográficas (NIST SP 800-57) |
| bauth | bos_key_recovery_log | bAuth | sec_key_recovery | Recuperación de llaves (break-glass, 2-of-3) |
| bauth | bos_key_rotation_log | bAuth | sec_key_rotation | Rotación de llaves con ceremonia y testigos |
| bauth | bos_device_registry | bAuth | sec_device | Registro de dispositivos físicos (ISO 27001 A.8.1) |
| bauth | bos_dispositivo_fisico | bAuth | sec_hardware_device | Hardware específico: OSDP, MQTT, ONVIF, Wiegand |
| bauth | bos_sitio_fisico | bAuth | sec_site | Sitio físico geolocalizado (lat/lon) |
| bauth | bos_edificio | bAuth | sec_building | Edificio dentro del sitio físico |
| bauth | bos_piso | bAuth | sec_floor | Piso dentro del edificio |
| bauth | bos_area_fisica | bAuth | sec_area | Área funcional dentro del piso |
| bauth | bos_pais | bGlobal | global_country | Países (ISO 3166-1 + UN M.49 + CLDR, 33 columnas). Catálogo canónico para todo el ecosistema. |
| bauth | bos_ciudad | — | ❌ INNECESARIA | Reemplazada por PostGIS point-in-polygon + API reverse geocoding. Las coordenadas (lat,lon) en las tablas de entidad resuelven ciudad en ~0.1ms sin catálogo manual. |
| bauth | bos_moneda | bglobal | global_currency | ✅ REPARADO 2026-06-23: PK UUIDv7 + 17 cols + 45 monedas seed idempotente |
| bauth | bos_idioma | bglobal | global_language | ✅ REPARADO 2026-06-23: PK UUIDv7 + 19 cols + 125 idiomas + solo es/en activos |
| bauth | bos_timezone | bglobal | geo_timezone | ✅ REPARADO 2026-06-23: PK UUIDv7 + 16 cols + 319 zonas IANA + solo La Paz activa |
| bauth | bos_compliance_map | bAuth | cfg_cumplimiento | Mapeo de 34 controles a estándares internacionales |
| bauth | bos_saga_catalog | bAuth | cfg_saga | Catálogo de 12 sagas de autenticación |
| bauth | bos_saga_step | bAuth | cfg_saga_paso | Pasos individuales de cada saga (acción+compensación) |
| bauth | bos_saga_execution | bAuth | cfg_saga_ejecucion | Registro inmutable de ejecuciones de saga |
| bos_blockchain | blk_merkle_batch | bAuth | blk_merkle_batch | Lotes de eventos para anclaje Merkle en L2 |
| bos_blockchain | blk_merkle_leaf | bAuth | blk_merkle_leaf | Hojas del árbol Merkle (Keccak-256) |
| bos_blockchain | blk_blockchain_anchor_log | bAuth | blk_anchor_log | Histórico de transacciones de anclaje en L2 |
| bos_blockchain | blk_anchor_reconciliation_log | bAuth | blk_anchor_reconciliation | Verificación cross-chain Merkle roots |
| bos_blockchain | blk_onchain_account | bAuth | blk_account | Cuentas on-chain (Variante B Besu QBFT) |
| bos_blockchain | blk_onchain_settlement | bAuth | blk_settlement | Liquidaciones on-chain con dual-approval |
| bos_blockchain | blk_reconciliation_log | bAuth | blk_reconciliation | Reconciliación periódica on-chain ↔ PostgreSQL |
| bos_privilege | privilege_application | bAuth | privilege_app | Aplicaciones registradas en el motor BOS |
| bos_privilege | privilege_domain | bAuth | privilege_domain | Catálogo de 12 dominios de soberanía D1-D12 |
| bos_privilege | privilege_verb | bAuth | privilege_verb | Vocabulario global de verbos (CRUD) |
| bos_privilege | privilege_group | bAuth | privilege_group | Grupos funcionales dentro de cada aplicación |
| bos_privilege | privilege_atom_catalog | bAuth | privilege_atom | Catálogo de átomos (1059 registros, one-hot) |
| bos_privilege | privilege_atom_policy | bAuth | privilege_policy | Políticas JSONB por átomo (6782 registros) |
| bos_privilege | privilege_atom_audit | bAuth | privilege_audit | Auditoría WORM de evaluaciones — particionado por mes |
| bos_privilege | privilege_atom_audit_2026_06 | bAuth | privilege_audit_2026_06 | Partición Junio 2026 |
| bos_privilege | privilege_atom_audit_2026_07 | bAuth | privilege_audit_2026_07 | Partición Julio 2026 |
| bos_privilege | privilege_role | bAuth | privilege_role | Roles base por tenant |
| bos_privilege | privilege_role_atom | bAuth | privilege_role_atom | Asignación rol↔átomo (BitMask relacional) |
| (nueva) | (nueva) | bAuth | privilege_bitmask_cache | Cache Redis-backed de BitMask evaluado por usuario+tenant |
| (nueva) | (nueva) | bAuth | privilege_conflict_audit | Auditoría WORM de conflictos SoD detectados |
| **Schema propuesto: bGlobal** ||||| |
| (nueva) | (nueva) | bGlobal | global_parametro | Parámetros con herencia jerárquica tenant→empresa→sucursal |
| (nueva) | (nueva) | bGlobal | global_message_template | Plantillas de mensajes multi-idioma (ex calendar_template) — usada por bCalendar y bnotify |
| **Schema propuesto: bCalendar** ||||| |
| (nueva) | (nueva) | bCalendar | cal_calendar | Colección de calendarios por tenant: work, fiscal, process, compliance (RFC 4791 VCALENDAR) |
| (nueva) | (nueva) | bCalendar | cal_event | VEVENT master: almacena rrule TEXT, no expande. Serie completa como un registro (RFC 5545) |
| (nueva) | (nueva) | bCalendar | cal_instance | Ocurrencias materializadas ±90 días (Google Hybrid Window). Más allá: expansión dinámica |
| (nueva) | (nueva) | bCalendar | cal_exception | Cancelaciones y modificaciones de instancias individuales (RFC 5545 RECURRENCE-ID + EXDATE) |
| (nueva) | (nueva) | bCalendar | cal_attendee | Participantes con RSVP: ACCEPTED/DECLINED/TENTATIVE/NEEDS-ACTION (RFC 5545 ATTENDEE) |
| (nueva) | (nueva) | bCalendar | cal_holiday | Feriados fijos (Navidad) y móviles (Pascua por fórmula) por país/región/tenant |
| (nueva) | (nueva) | bCalendar | cal_alarm | VALARM: cuándo disparar, canal (EMAIL/SMS/WhatsApp/UI), lead time (RFC 5545 VALARM) |
| (nueva) | (nueva) | bCalendar | cal_notification_log | Registro WORM de cada notificación enviada — solo INSERT, ctx_id obligatorio (ISO 27001 A.8.15) |
| (nueva) | (nueva) | bCalendar | cal_user_prefs | Preferencias de canal de notificación y horario por usuario/tenant |
| (nueva) | (nueva) | bCalendar | cal_audit_log | Log bi-temporal: valid_from/valid_to (tiempo real) + recorded_at (tiempo DB) — ISO SQL:2011 |

---


## 3. Estandarización Técnica

### 3.1 Estandarización de Tipos de Datos — UUID para todas las PKs

**Problema detectado:** La DDL actual usa 4 tipos distintos para primary keys: TEXT (20), UUID (32), BIGSERIAL (27), SERIAL (27). Esta inconsistencia causa:
- JOINs ineficientes (TEXT es más lento que UUID en B-tree)
- IDs predecibles (SERIAL permite enumerar registros)
- Incompatibilidad en FKs (TEXT → BIGSERIAL requiere casteo)
- Sin soporte para replicación multi-nodo (SERIAL colapsa en distributed SQL)

**Estándar PostgreSQL 18+:** UUID v7 (time-ordered) es el tipo recomendado para PKs. Ventajas:
- `gen_random_uuid()` nativo desde PG 13
- UUID v7 ordena temporalmente (bueno para B-tree, evita fragmentación)
- 128-bit fijo (más rápido que TEXT variable)
- No predecible (seguridad)
- Compatible con replicación multi-master

**Regla de estandarización:**

| Tipo de PK | Usar en | Ejemplo |
|-----------|---------|---------|
| **UUID** (gen_random_uuid()) | **TODAS las tablas sin excepción** | tenant, empresa, user, rol, evento, audit_event, login_attempt |
| **CHAR(3)** | Códigos ISO (natural keys) | currency_code, country_code |
| **TEXT** (solo natural keys) | Identificadores únicos no numéricos | locale ('es-BO'), timezone_id ('America/La_Paz') |

**Impacto en la DDL — ejemplos de cambio:**

```sql
-- ANTES (inconsistente)
CREATE TABLE bauth.bos_tenant (
    tenant_id       TEXT        PRIMARY KEY,    -- ❌ TEXT
    ...
);

-- DESPUÉS (estandarizado)
CREATE TABLE bAuth.idn_tenant (
    tenant_id       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),  -- ✅ UUID
    tenant_slug     TEXT        UNIQUE NOT NULL,  -- 'skull', 'acme' (natural key para URLs)
    ...
);

-- ANTES (inconsistente)
CREATE TABLE bauth.bos_empresa (
    empresa_id      TEXT        NOT NULL,        -- ❌ TEXT
    tenant_id       TEXT        NOT NULL,        -- ❌ TEXT FK
    ...
);

-- DESPUÉS (estandarizado)
CREATE TABLE bAuth.idn_company (
    company_id      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),  -- ✅ UUID
    tenant_id       UUID        NOT NULL,        -- ✅ UUID FK
    company_slug    TEXT        UNIQUE NOT NULL,  -- natural key para URLs
    ...
);
```

**Ventajas específicas en PostgreSQL 18+:**
- Índices B-tree sobre UUID v7: inserción ordenada, sin page splits
- `UUID` ocupa 16 bytes fijos vs TEXT que ocupa 36+ bytes
- JOINs UUID↔UUID son ~40% más rápidos que TEXT↔TEXT
- Particionamiento por UUID v7: distribución uniforme entre particiones
- Replicación lógica: UUID no colisiona entre nodos

**Resultado de la conversión (APLICADO al DDL .bak):**

| Tipo PK | Antes | Después |
|---------|-------|---------|
| UUID DEFAULT gen_random_uuid() | 32 | **103** |
| TEXT | 20 | **0** |
| SERIAL | 27 | **0** |
| BIGSERIAL | 27 | **0** |
| CHAR(2)/CHAR(3) (códigos ISO) | 2 | **2** |

**100% de las PKs son UUID. Solo 2 natural keys ISO permanecen como CHAR.**
**Auditoría y logs incluidos: `audit_event`, `login_attempt`, `sync_log` → UUID.**
**Fundamento: PostgreSQL 18+ UUID v7 time-ordered rinde igual que BIGSERIAL con ventajas de seguridad y replicación.**

---


### 3.2 Reglas Inquebrantables de la DDL

| # | Regla | Fundamento |
|---|-------|-----------|
| R1 | **Cero ALTER TABLE** — solo CREATEs | Instalación limpia, sin parches |
| R2 | **Cero INSERTs** — van en seeds separados | DDL puro, datos aparte |
| R3 | **100% UUID** para PKs — DEFAULT gen_random_uuid() | RFC 9562, PostgreSQL 18+ |
| R4 | **REFERENCES intactas** con orden topológico (tsort) | Integridad referencial |
| R5 | **IF NOT EXISTS** en todos los CREATE | Idempotencia |
| R6 | **Nombres en inglés** con prefijos funcionales | Estándar internacional |
| R7 | **ctx_id** en todas las tablas operativas | SBOS-049, W3C Trace Context |

### 3.3 Estándares Internacionales a Verificar

| # | Estándar | Controles |
|---|----------|-----------|
| 1 | ISO 27001:2022 | A.5.15-18, A.8.2, A.8.5, A.8.9, A.8.15, A.8.17 |
| 2 | ISO 24760-2:2025 | §5.3, §5.4, §8.3.1-8.3.7 |
| 3 | NIST 800-63B-4 | §4, §5.1, §5.2, §7 |
| 4 | NIST 800-53 Rev.5 | AC-2, AC-5, AC-6, AC-7, AU-2, AU-3, AU-9, CM-6 |
| 5 | NIST 800-207 ZTA | Continuous Verification |
| 6 | PCI DSS 4.0.1 | Req 8.2-8.4, Req 10.1-10.7 |
| 7 | OWASP ASVS 5.0 | V2.1, V2.5, V3.1-3.3, V4.1-4.2 |
| 8 | SOC 2 Type II | CC6.1, CC6.3, CC6.6, CC7.1, CC9.1 |
| 9 | GDPR/RGPD | Art.7, Art.9, Art.17, Art.32 |
| 10 | ANSI INCITS 359 | §2, §3, §4 (RBAC) |
| 11 | ISO 20022 / FATF 16 | Límites financieros |
| 12 | NIST FIPS 140-3/203/204/205 | Criptografía y PQC |

---


### 3.4 Resumen de la Reorganización de Schemas

| Métrica | Actual | Propuesto |
|---------|--------|-----------|
| Schemas reales | 3 inventados | **2 reales**: bAuth (principal) + bos (BOS independiente) |
| Prefijos | 1 (bos_) | **11** (idn_, ath_, ses_, fin_, fis_, aud_, sec_, geo_, cfg_, blk_, privilege_) |
| Tablas renombradas | — | **85** (cambio de prefijo) |
| Tablas migradas de schema | — | **7** (bos_blockchain → bauth) |
| Legibilidad | `bos_financial_approval` | `fin_approval` |
| Agrupación | Imposible sin examinar | Instantánea por prefijo |

---

### 3.5 Schema `bRates` en bAuth — Control de Acceso a Monedas

**Principio:** bRates (SmartRates, `SBOS_rates_db`) es la fuente de datos de tipos de cambio de 200+ monedas. bAuth gobierna QUIÉN tiene DERECHO a acceder a cuáles de esas monedas.

**Frontera limpia:**

| Responsabilidad | Dueño |
|----------------|-------|
| Colección de tipos de cambio de todas las monedas del mundo | bRates (SBOS_rates_db) |
| Política cambiaria, ajustes diarios, moneda oficial, moneda de cambio, `catalog.RATE()` | bRates (SBOS_rates_db) |
| ¿Qué tenant tiene acceso a bRates? | **bAuth** (skSBOS_db, bRates) |
| ¿Qué monedas puede usar este tenant? | **bAuth** (skSBOS_db, bRates) |
| ¿Qué monedas puede usar esta empresa? (hereda del tenant) | **bAuth** (skSBOS_db, bRates) |
| Auditoría: ¿quién consultó bRates? | **bAuth** (skSBOS_db, bRates) |

#### Tabla 1: `bRates.currency_access` — Control de acceso por tenant/empresa

```sql
CREATE TABLE IF NOT EXISTS bAuth.bRates.currency_access (
    access_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL,
    empresa_id      UUID,                    -- NULL = nivel tenant
    currency_code   CHAR(3) NOT NULL,        -- ISO 4217 (BOB, USD, EUR...)
    can_access      BOOLEAN NOT NULL DEFAULT TRUE,
    granted_by      UUID NOT NULL,
    granted_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at      TIMESTAMPTZ,             -- NULL = acceso vigente
    ctx_id          TEXT NOT NULL,
    UNIQUE (tenant_id, empresa_id, currency_code)
);

CREATE INDEX IF NOT EXISTS idx_bca_tenant ON bAuth.bRates.currency_access(tenant_id, empresa_id);

COMMENT ON TABLE bAuth.bRates.currency_access IS
  'Control de acceso a monedas. bRates tiene 200+ monedas. bAuth define a cuáles
   tiene derecho este tenant/empresa. Sin registro = sin acceso a esa moneda.
   Empresa hereda del tenant (empresa_id=NULL define el conjunto base del tenant).
   Empresa puede tener MENOS monedas que el tenant, nunca MÁS.';
```

#### Tabla 2: `bRates.access_audit` — Auditoría de acceso a bRates

```sql
CREATE TABLE IF NOT EXISTS bAuth.bRates.access_audit (
    audit_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL,
    empresa_id      UUID,
    user_id         UUID NOT NULL,
    currency_code   CHAR(3),                -- moneda consultada (NULL = acceso general)
    action          TEXT NOT NULL,           -- 'RATE_QUERY', 'ACCESS_GRANTED', 'ACCESS_REVOKED'
    rate_value      NUMERIC(20,8),           -- valor retornado (solo para RATE_QUERY)
    rate_date       DATE,                    -- fecha del tipo consultado
    ctx_id          TEXT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_baa_tenant ON bAuth.bRates.access_audit(tenant_id, created_at DESC);

COMMENT ON TABLE bAuth.bRates.access_audit IS
  '[ISO 27001 A.8.15] Auditoría WORM de acceso a bRates.
   Registra quién consultó qué moneda, cuándo, y el valor retornado.
   Permite detectar accesos no autorizados y patrones anómalos.
   Inmutable: solo INSERT.';
```

**Total tablas en schema `bRates`: 2** (control de acceso + auditoría).

**Ejemplo de herencia de acceso:**

```
TENANT SKULL: acceso a {BOB, USD, EUR, BRL, ARS, PEN, CLP, COP} (8 monedas)
  │
  ├── EMPRESA A: hereda las 8 del tenant (no tiene registro propio)
  │
  ├── EMPRESA B: acceso a {BOB, USD, EUR, ARS} (4 monedas — MÁS restrictivo)
  │
  └── EMPRESA C: acceso a {BOB, USD} (2 monedas — trial, acceso mínimo)
```

**bAuth NO almacena:** tipos de cambio, ajustes diarios, políticas cambiarias. Eso es de bRates.


## 4. Investigación y Brechas Arquitectónicas

### 4.1 Herencia Jerárquica de Parámetros (Tenant → Empresa → Sucursal)

**Problema:** No existe mecanismo de herencia de configuración. `bos_tenant_config`, `bos_domain_config`, `bos_global_config` son tablas independientes sin cascada. Una sucursal no puede heredar la configuración de su empresa, ni la empresa de su tenant.

**Estándar de industria (SaaS Multi-tenant):** El patrón canónico es "recursive lookup con NULL = inherit". El valor efectivo se obtiene subiendo la jerarquía hasta el primer valor NO NULL. [IBM Cognos Analytics Hierarchy Node], [StackOverflow #41780816].

**Solución:** Una sola tabla jerárquica que reemplace las 3 actuales:
```sql
bGlobal.global_parametro (
  param_key     TEXT,
  tenant_id     TEXT,    -- NULL = default global
  empresa_id    TEXT,    -- NULL = definido a nivel tenant
  sucursal_id   TEXT,    -- NULL = definido a nivel empresa
  param_value   JSONB,
  UNIQUE (param_key, tenant_id, empresa_id, sucursal_id)
)
```
Resolución con función `bGlobal.resolve_param(key, tenant, empresa, sucursal)`:
```
1. Buscar (key, tenant, empresa, sucursal)    -- sucursal override
2. Si NULL → buscar (key, tenant, empresa, NULL)  -- empresa override
3. Si NULL → buscar (key, tenant, NULL, NULL)    -- tenant default
4. Si NULL → buscar (key, NULL, NULL, NULL)       -- global default
```

### 4.5 Principio Unificado de Herencia Jerárquica — Tenant → Empresa → Sucursal

**Descubrimiento:** Las brechas §3.1 (parámetros), §3.2 (gestión/calendario), y §3.4 (idiomas/monedas) comparten el MISMO patrón de herencia jerárquica. No son tres problemas separados — es UN solo mecanismo que aplica a múltiples dominios.

#### 3.5.1 La Regla de Oro

> **La empresa NUNCA puede tener MÁS que el tenant. Solo puede tener IGUAL o MENOS.**
> **La sucursal NUNCA puede tener MÁS que la empresa. Solo puede tener IGUAL o MENOS.**

```
TENANT (máximo permitido)
  │
  ├── EMPRESA A (hereda todo del tenant, o restringe)
  │   ├── Sucursal A1 (hereda de empresa A, o restringe más)
  │   └── Sucursal A2 (hereda de empresa A)  
  │
  └── EMPRESA B (puede tener MENOS que el tenant)
      └── Sucursal B1 (hereda de empresa B)
```

#### 3.5.2 Aplicación por Dominio

| Dominio | ¿Qué define el tenant? | ¿Qué hereda la empresa? | Ejemplo |
|---------|----------------------|------------------------|---------|
| **Idiomas** | Todos los idiomas disponibles | Subconjunto de idiomas del tenant | Tenant: {es, en, pt, qu, ay}. Empresa A: {es, en}. Empresa B: {es} |
| **Monedas** | Todas las monedas disponibles | Subconjunto de monedas del tenant | Tenant: {BOB, USD, EUR, ARS}. Empresa A: {BOB, USD}. Empresa B (frontera): {BOB, ARS} |
| **Políticas de autenticación** | Todas las políticas disponibles (catálogo BOS) | Subconjunto de políticas suscritas | Tenant: Argon2id, TOTP, FIDO2, Passkey. Empresa Trial: solo Argon2id + TOTP |
| **Métodos MFA** | Todos los métodos disponibles | Subconjunto de métodos habilitados | Tenant: {FIDO2, TOTP, SMS, Passkey}. Empresa A: {FIDO2, TOTP}. Empresa B: {TOTP} |
| **Parámetros de sesión** | Límites máximos absolutos | Límites iguales o más restrictivos | Tenant: max_session=12h. Empresa A: max_session=8h. Empresa B: max_session=12h (hereda) |
| **Gestión fiscal** | Calendario base del tenant | Calendario propio o heredado | Tenant: Ene-Dic. Empresa A (UK): Abr-Mar. Empresa B: hereda Ene-Dic |

#### 3.5.3 Gobernanza

```
┌─────────────────────────────────────────────────────────────┐
│ BOS — Catálogo Global (fuente de verdad)                    │
│                                                             │
│  privilege_policy  ← TODAS las políticas que EXISTEN        │
│  privilege_method  ← TODOS los métodos que EXISTEN          │
│                                                             │
│  El BOS define QUÉ EXISTE en el ecosistema.                 │
│  BOS NO decide quién lo usa — eso es bAuth.                │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│ bAuth — Suscripción y Herencia                              │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Tenant (nivel máximo)                                │    │
│  │   idn_tenant_policy    ← políticas suscritas         │    │
│  │   idn_tenant_method    ← métodos suscritos           │    │
│  │   idn_tenant_language  ← idiomas habilitados         │    │
│  │   idn_tenant_currency  ← monedas habilitadas         │    │
│  └────────────┬────────────────────────────────────────┘    │
│               │ hereda o restringe                           │
│               ▼                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Empresa (subconjunto del tenant)                     │    │
│  │   idn_company_policy    ← políticas heredadas/extra  │    │
│  │   idn_company_method    ← métodos heredados/extra    │    │
│  │   idn_company_language  ← idiomas heredados          │    │
│  │   idn_company_currency  ← monedas heredadas          │    │
│  └────────────┬────────────────────────────────────────┘    │
│               │ hereda o restringe                           │
│               ▼                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Sucursal (subconjunto de la empresa)                 │    │
│  │   idn_branch_policy     ← solo si necesita menos     │    │
│  │   idn_branch_language   ← idiomas extra (frontera)   │    │
│  │   idn_branch_currency   ← monedas extra (frontera)   │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

**Regla de restricción (nunca expansión):**
```sql
-- Al suscribir una empresa a políticas, validar:
SELECT 1 FROM idn_tenant_policy 
WHERE tenant_id = $tenant_id AND policy_id = $policy_id;
-- Si el tenant NO tiene la política → RECHAZAR suscripción de empresa
-- Si el tenant SÍ tiene la política → PERMITIR (empresa hereda o restringe)

-- Al habilitar idiomas en empresa, validar:
SELECT 1 FROM idn_tenant_language
WHERE tenant_id = $tenant_id AND language_code = $lang;
-- Si el tenant NO tiene el idioma → RECHAZAR
```

#### 3.5.4 Tablas necesarias (mínimas, solo suscripciones)

```sql
-- Suscripción de políticas por tenant/empresa (hereda de BOS)
CREATE TABLE bAuth.idn_tenant_policy (
    tenant_id   TEXT NOT NULL,
    policy_id   TEXT NOT NULL,        -- referencia a bAuth.privilege_policy
    enabled     BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (tenant_id, policy_id)
);

-- Suscripción de políticas por empresa (subconjunto del tenant)
CREATE TABLE bAuth.idn_company_policy (
    empresa_id  TEXT NOT NULL,
    policy_id   TEXT NOT NULL,
    enabled     BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (empresa_id, policy_id)
    -- CHECK: policy_id DEBE existir en idn_tenant_policy del tenant padre
);

-- Mismo patrón para métodos, idiomas, monedas...
```

#### 3.5.5 Resumen del principio unificado

| El BOS define | El tenant suscribe | La empresa hereda/restringe | La sucursal afina |
|--------------|-------------------|---------------------------|-------------------|
| QUÉ existe | QUÉ usa este tenant | Qué de eso usa esta empresa | Qué de eso usa esta sucursal |
| Catálogo total | Subconjunto del catálogo | Subconjunto del tenant | Subconjunto de la empresa |
| Ej: 12 políticas | Ej: 8 políticas | Ej: 5 políticas (hereda 5 de 8) | Ej: 5 políticas (hereda todas) |
| Ej: 20 métodos auth | Ej: 6 métodos | Ej: 3 métodos (empresa trial) | Ej: 3 métodos (hereda todos) |

> **Principio:** El nivel superior es el TECHO. El nivel inferior puede ser IGUAL o MÁS RESTRICTIVO, nunca MÁS PERMISIVO.

---

### 4.2 Gestión (Período Fiscal) como Named Interval — Gobernado por BOS + bAuth

**Problema detectado:** El Context Plane actual omite la dimensión temporal "gestión". La gestión NO es solo a nivel empresa — un usuario puede actuar a nivel empresa en 2026 pero necesitar corregir problemas de 2025 en la sucursal norte. La gestión aplica en TODOS los niveles: tenant, empresa, sucursal.

---

### 4.2.1 Lo que 6 ERPs + GTRBAC aportan al SBOS

| Fuente | Patrón extraído | Aplicación directa en SBOS | Tabla/Componente afectado |
|--------|----------------|---------------------------|---------------------------|
| **NetSuite OneWorld** | Una subsidiary = un calendario fiscal independiente. Mapping tables para consolidación cross-calendar. | Cada empresa puede tener su propio año fiscal. La consolidación se hace vía `ctx_id` + `interval_id`. | `bAuth.calendar_interval` (NUEVA) |
| **Acumatica** | "Centralized Period Management": control independiente O compartido por company. | El tenant decide si las empresas comparten gestión o cada una define la suya. | `bAuth.calendar_interval.scope` = TENANT \| EMPRESA \| SUCURSAL |
| **Odoo 18** | Branch hereda lock dates del padre. Branch puede cerrar ANTES que el padre pero no DESPUÉS. | Herencia jerárquica de cierre: sucursal hereda estado de empresa, empresa de tenant. La sucursal puede ser MÁS restrictiva, nunca MÁS permisiva. | `bAuth.calendar_interval.parent_interval` + `status` |
| **D365 Finance** | Una legal entity = un calendario. Consolidación vía entidad separada. | Mismo patrón que NetSuite. Reforzado por el Context Plane. | `ctx_id` ya transporta la entidad |
| **SAP ERP HCM** | "Period of Responsibility" derivado de la posición organizacional + Structural Authorization Profiles. | El Rol define el período de responsabilidad. El Dominio Temporal (D4) evalúa la política GTRBAC. | `bAuth.privilege_policy` (D4 Temporal) |
| **Oracle ORMB** | Períodos controlados por organización, ventanas open/close por período. Back-posting con `publicable_desde`/`publicable_hasta`. | Cada intervalo tiene ventana de publicación. Permite corregir gestiones pasadas sin abrir completamente el período. | `bAuth.calendar_interval.postable_from` / `postable_until` |
| **GTRBAC (IEEE TKDE 2005)** | Periodic expressions sobre calendar hierarchies. Role Enabling ≠ Role Activation. | El Dominio Temporal (D4) habilita/deshabilita roles según `(interval, calendar_expr)`. La sesión activa el rol. | `bAuth.privilege_policy` (D4) + `bAuth.context_sessions` |

---

### 4.2.2 Arquitectura de Gobernanza: Quién controla qué

```
┌─────────────────────────────────────────────────────────────┐
│ BOS (IAM Installer) — Gobierno del Context Plane            │
│                                                             │
│  ctx_id = tenant.empresa.sucursal.pos.user.trace             │
│  El ctx_id transporta el contexto. No se replica en tablas. │
│  BOS crea/destruye ctx_id.                                  │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│ bAuth — Validación + Políticas + Calendario                  │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐                   │
│  │ Dominio Temporal │  │ Dominio Contexto│                   │
│  │ (D4)             │  │ (D8)            │                   │
│  │                  │  │                 │                   │
│  │ Evalúa:          │  │ Evalúa:         │                   │
│  │ ¿El rol está     │  │ ¿El ctx_id      │                   │
│  │  habilitado en   │  │  pertenece al   │                   │
│  │  este intervalo? │  │  intervalo?     │                   │
│  └────────┬────────┘  └────────┬────────┘                   │
│           │                    │                             │
│           └────────┬───────────┘                             │
│                    ▼                                         │
│           calendar_interval (NUEVA)                          │
│           ┌─────────────────────────┐                        │
│           │ FY2026                  │                        │
│           │ ├── Q1-2026             │                        │
│           │ │   ├── Jan-2026        │                        │
│           │ │   ├── Feb-2026        │                        │
│           │ │   └── Mar-2026        │                        │
│           │ ├── Q2-2026             │                        │
│           │ ...                     │                        │
│           └─────────────────────────┘                        │
│                                                             │
│  La gestión = named interval en el calendario.              │
│  El rol tiene políticas D4 que referencian intervalos.      │
│  El ctx_id se evalúa contra el intervalo en D8.             │
└─────────────────────────────────────────────────────────────┘
```

---

### 4.2.3 Tabla NUEVA: `bAuth.calendar_interval`

```sql
-- Reemplaza y unifica: bos_schedule + bos_gestion_calendario
-- Basado en: NetSuite (multi-calendar) + Odoo (herencia cierre) 
--            + Oracle ORMB (ventanas publicación) + GTRBAC (periodic expressions)

CREATE TABLE bAuth.calendar_interval (
    interval_id       TEXT PK,           -- 'FY2026', 'Q1-2026', 'JAN-2026', 'TAX_SEASON'
    tenant_id         TEXT NOT NULL,
    empresa_id        TEXT,             -- NULL = aplica a todo el tenant
    sucursal_id       TEXT,             -- NULL = aplica a toda la empresa
    interval_type     TEXT NOT NULL,    -- FISCAL_YEAR, QUARTER, MONTH, WEEK, CUSTOM
    start_date        DATE NOT NULL,
    end_date          DATE NOT NULL,
    parent_interval   TEXT,             -- FK → calendar_interval.interval_id (jerarquía)
    status            TEXT DEFAULT 'OPEN',  -- OPEN, SOFT_CLOSED, HARD_CLOSED, ARCHIVED
    postable_from     DATE,             -- ventana back-posting (Oracle ORMB)
    postable_until    DATE,             -- cierre de ventana
    closed_by         UUID,
    closed_at         TIMESTAMPTZ,
    previous_interval TEXT,             -- linked list: FY2025 → FY2026 (NetSuite)
    UNIQUE (tenant_id, empresa_id, sucursal_id, interval_id),
    CONSTRAINT chk_interval_status CHECK (status IN ('OPEN','SOFT_CLOSED','HARD_CLOSED','ARCHIVED')),
    CONSTRAINT chk_interval_type CHECK (interval_type IN ('FISCAL_YEAR','QUARTER','MONTH','WEEK','DAY','CUSTOM'))
);

-- La herencia de cierre (Odoo): una sucursal puede cerrar ANTES, nunca DESPUÉS
-- Se implementa con una función: resolve_interval_status(tenant, empresa, sucursal, interval_id)
-- que recorre la jerarquía hacia arriba hasta encontrar el primer status definido.

COMMENT ON TABLE bAuth.calendar_interval IS 
  '[NetSuite OneWorld] [Odoo 18] [Oracle ORMB] [GTRBAC] Named intervals para gestión fiscal multi-nivel. 
   Soporta diferentes calendarios por empresa/sucursal con herencia jerárquica de cierre. 
   Ventanas de back-posting por intervalo. Gobernado por BOS (ctx_id) + bAuth (políticas D4/D8).';
```

---

### 4.2.4 Cómo se resuelve la gestión SIN modificar tablas operativas

La gestión NO es una columna. Es una **política del Dominio Temporal** que se evalúa en runtime:

```
PASO 1: El usuario inicia sesión → bAuth crea ctx_id (BOS)
PASO 2: El ctx_id establece tenant.empresa.sucursal.pos.user
PASO 3: El rol del usuario tiene políticas D4 que referencian calendar_interval
PASO 4: El motor D4 evalúa: ¿el intervalo actual está en la lista de permitidos?
PASO 5: El motor D8 evalúa: ¿el ctx_id pertenece al scope del intervalo?
PASO 6: Si D4 Y D8 aprueban → el rol está habilitado para actuar
```

**Ejemplo concreto:**

```
María (contadora) quiere corregir factura de 2025 en Sucursal Norte.

1. ctx_id = skull.empresa_skull.suc_norte.pos_3.maria.trace_abc
2. Rol "Contador" tiene política D4:
   (intervalo 'FY2025', all.Days, READ_ONLY)     ← gestión pasada
   (intervalo 'FY2026', all.Days, READ_WRITE)     ← gestión actual
3. calendar_interval 'FY2025' está HARD_CLOSED en Empresa SKULL
   pero Sucursal Norte tiene 'FY2025' en SOFT_CLOSED (permite correcciones)
4. Motor D4: intervalo FY2025 + permiso READ_ONLY → OK
5. Motor D8: ctx_id.sucursal = suc_norte ∈ scope del intervalo → OK
6. Resultado: María puede CORREGIR (READ_ONLY), no puede CREAR nuevas facturas en 2025
```

---

### 4.2.5 Lo que hay que construir (resumen)

| # | Componente | Tipo | Basado en | Prioridad |
|---|-----------|------|-----------|-----------|
| 1 | `bAuth.calendar_interval` | Tabla NUEVA | NetSuite + Odoo + Oracle ORMB + GTRBAC | 🔴 Alta |
| 2 | `resolve_interval_status()` | Función SQL | Odoo (herencia cierre) + Acumatica (centralized/shared) | 🔴 Alta |
| 3 | Políticas D4 con periodic expressions | Enriquecer `bAuth.privilege_policy` | GTRBAC §3.2 | 🟡 Media |
| 4 | Evaluación D8: ctx_id ∈ interval | Enriquecer DomainEvaluator | GTRBAC §5 | 🟡 Media |
| 5 | `bAuth.context_sessions.interval_id` | Columna NUEVA (mínima) | SBOS-049 §4 | 🟢 Baja |

**No se modifica ninguna tabla operativa existente.** La gestión se resuelve en la capa de políticas.

### 4.3 Corrección: ctx_id ya transporta el contexto

**Nota corregida:** El `ctx_id` ya codifica `tenant.empresa.sucursal.pos.user.trace` y se propaga vía W3C Trace Context. Agregar columnas redundantes de tenant/empresa/sucursal a cada tabla rompe la arquitectura del Context Plane. Las tablas operativas usan `ctx_id` como único identificador de contexto. La trazabilidad se obtiene resolviendo el `ctx_id`, no replicando columnas.

---

### 4.4 Multi-Lenguaje y Multi-Moneda — Configuración Regional Jerárquica

**Problema detectado:** El DDL actual tiene tablas de idiomas y monedas, pero:
- Solo se configuran a nivel **tenant** (no hay herencia a empresa/sucursal)
- Los valores son datos de referencia (seeds), no están hardcodeados — correcto
- Falta integración con **bRates** (SmartRates) para tipos de cambio

**Lo que YA existe (correcto, no tocar):**

| Tabla | Propósito | Estándar |
|-------|-----------|----------|
| `bos_idioma` → `bglobal.global_language` | ✅ REPARADO — Catálogo de idiomas (125, ISO 639/BCP 47, solo es+en activos) |
| `bos_moneda` → `bglobal.global_currency` | ✅ REPARADO — Catálogo de monedas (45, ISO 4217, UUIDv7 PK) |
| `bos_timezone` → `bglobal.geo_timezone` | ✅ REPARADO — Zonas horarias (319, IANA TZ, solo La Paz activa) |
| `bos_tenant_language` → `bglobal.global_tenant_language` | Idiomas habilitados por tenant | — |
| `bos_tenant_currency` → `bauth.idn_tenant_currencies` | ✅ REPARADO — Monedas habilitadas por tenant + tasas de cambio (FK idn_tenant + global_currency, sin seed) |
| `bos_tenant_config.locale` | Locale por defecto del tenant | IETF BCP 47 |
| `bos_tenant_config.currency_default` | Moneda por defecto del tenant | ISO 4217 |

**Lo que se ELIMINA del plan (manejado por bRates):**

| Concepto eliminado | Motivo |
|-------------------|--------|
| ~~Tabla `bGlobal.exchange_rate`~~ | bRates (`smartrates_db.rates.exchange_rates`) es la fuente de verdad de tipos de cambio |
| ~~`functional_currency` vs `presentation_currencies`~~ | bRates maneja la conversión via `catalog.RATE()`. La moneda funcional es `currency_default` en `tenant_config` |
| ~~`bGlobal.regional_config`~~ | La configuración regional ya existe en `bos_tenant_config` |

### 4.4b Integración con bRates (SmartRates) — Subproyecto SBOS Nivel 3

**bRates es un subproyecto independiente con su propia base de datos `smartrates_db`:**
- 8 schemas: `catalog`, `rates`, `company`, `security`, etc.
- 23+ tablas: `catalog.currencies`, `rates.exchange_rates`, `company.adjustment_global`, `company.adjustment_daily`
- Función nativa: `catalog.RATE(from, to, date)` — extensión C en PostgreSQL, nanosegundos por conversión
- Stack: Laravel 13.7 + PostgreSQL 18.4 + Redis 7 + Flutter 3.x
- Modo dual: standalone (Sanctum) + SBOS acoplado (Keycloak + Kong)

**Modelo de ajustes por tenant/empresa (bRates):**

```
NIVEL 1 — Ajuste GLOBAL del tenant (company.adjustment_global)
  │  Confirmado por: operador SBOS
  │  Alcance: TODAS las empresas del tenant
  │  Si empresa no tiene ajuste propio → hereda este valor
  │
  ▼
NIVEL 2 — Ajuste por EMPRESA (company.adjustment_daily)
  │  Confirmado por: operador de la empresa
  │  Si está configurado → sobrescribe el ajuste global
  │  Si NO está configurado → hereda automáticamente del global
```

**Cómo bAuth consume bRates:**

```
bAuth NO almacena tipos de cambio. bAuth consulta bRates cuando necesita convertir:

1. La tabla bGlobal.global_currency define QUÉ monedas existen (catálogo ISO)
2. La tabla bGlobal.global_tenant_currency define QUÉ monedas usa cada tenant
3. bRates (smartrates_db) define el TIPO DE CAMBIO de cada moneda
4. La función catalog.RATE() convierte en tiempo real
5. bAuth hereda la configuración de monedas: tenant → empresa → sucursal
```

**Flujo de conversión (ejemplo):**

```
Usuario en Sucursal Norte ve precio en USD:
1. ctx_id = skull.empresa_skull.suc_norte.pos_3.user.trace
2. bAuth consulta bGlobal.global_tenant_currency: ¿USD habilitado para este tenant? ✅
3. bAuth llama catalog.RATE('BOB', 'USD', CURRENT_DATE) → 0.1449
4. Precio base Bs. 350 × 0.1449 = $50.72 (solo display, no se modifica el valor base)
5. bAuth registra audit_event: 'RATE_CONSULTED', ctx_id, rate=0.1449, source='smartrates'
```

**Lo que bAuth SÍ necesita (mínimo):**

| Componente | Tipo | Propósito |
|-----------|------|-----------|
| `bGlobal.global_currency` | Tabla (ya existe como `bos_moneda`) | Catálogo ISO 4217 |
| `bGlobal.global_tenant_currency` | Tabla (ya existe) | Monedas habilitadas por tenant |
| `bGlobal.global_tenant_language` | Tabla (ya existe) | Idiomas habilitados por tenant |
| `bAuth.tenant_config.currency_default` | Columna (ya existe) | Moneda funcional del tenant |
| Extensión `smartrates_rate` | Extensión PostgreSQL | `catalog.RATE()` disponible en el cluster |

**Lo que NO necesita bAuth:**
- ❌ No necesita tabla `exchange_rate` propia
- ❌ No necesita `functional_currency` vs `presentation_currencies` (eso lo maneja bRates)
- ❌ No necesita almacenar tipos de cambio (bRates es la fuente de verdad)


## 5. Proyecto Calendario Fiscal Multi-Nivel (cal_)

### 5.0 Diagnóstico: ¿Por qué AHORA?

El calendario debe desarrollarse en esta etapa porque:
1. La DDL está siendo reconstruida — podemos agregar las tablas del calendario limpiamente
2. La estandarización de prefijos está en curso — el calendario usará los prefijos correctos desde el inicio
3. La herencia jerárquica (§3.5) está definida — el calendario la implementa
4. El Context Plane (§3.2) ya gobierna tenant/empresa/sucursal — el calendario hereda ese contexto
5. Sin calendario, la "gestión" es solo teoría — con calendario, es funcional

### 5.1 Lo que el calendario DEBE cubrir

| # | Necesidad | ¿Quién la cubre? | ¿Cómo? |
|---|-----------|-----------------|--------|
| N1 | **Gestión fiscal por tenant/empresa/sucursal** | pgcalendar + bAuth | Tabla `calendar_interval` con tenant_id, empresa_id, sucursal_id. Herencia: sucursal hereda cierre de empresa. |
| N2 | **Períodos mensuales/trimestrales/anuales** | pgcalendar `schedules` | Recurrence type: monthly, quarterly, yearly. Proyección automática de períodos. |
| N3 | **Festivos y días no laborables** | pgcalendar `exceptions` | exception_type='cancelled' para festivos. Un feriado nacional cancela el día laboral en todas las sucursales. |
| N4 | **Cierre de gestión (SOFT/HARD)** | calendar_interval.status | OPEN → SOFT_CLOSED → HARD_CLOSED → ARCHIVED. Heredable. |
| N5 | **Ventanas de back-posting** | calendar_interval + rrule_plpgsql | `postable_from` / `postable_until` por intervalo. rrule.between() para validar. |
| N6 | **Recurrencia infinita con excepciones** | rrule_plpgsql | RFC 5545 completo. FREQ=YEARLY;BYMONTH=1,4,7,10 para trimestres. Excepciones para modificar instancias individuales. |
| N7 | **Visualización multi-sucursal** | FullCalendar Resource Timeline | Vista timeline con una columna por sucursal. Colores por estado de gestión. |
| N8 | **No solapar períodos** | pgcalendar triggers | Trigger `prevent_schedule_overlap` evita que dos gestiones se solapen para la misma empresa. |
| N9 | **Integración con ctx_id** | bAuth Context Plane | Cada evento/schedule/excepción registra el ctx_id que lo creó/modificó. |
| N10 | **API REST sin programar backend** | PostgREST | Auto-genera endpoints desde las tablas PostgreSQL. Swagger automático. |

### 5.2 Las 3 herramientas y cómo se integran

```
┌──────────────────────────────────────────────────────────────────┐
│                    CALENDARIO SBOS — ARQUITECTURA                  │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ FullCalendar (UI)                  MIT · 20K+ ★ GitHub      │ │
│  │                                                             │ │
│  │  • Vista mes/semana/día/timeline                            │ │
│  │  • Resource Timeline: 1 columna por sucursal                │ │
│  │  • Drag & drop: modificar fechas de cierre                  │ │
│  │  • Colores: verde=ABIERTO, amarillo=SOFT, rojo=HARD         │ │
│  │  • RRULE plugin: mostrar recurrencia en UI                  │ │
│  │  • Componente React embeble en Core UI                      │ │
│  └──────────────────────┬──────────────────────────────────────┘ │
│                         │ GET/POST/PATCH /api/calendar            │
│                         ▼                                         │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ PostgREST (API)                   MIT · 10K+ ★ GitHub       │ │
│  │                                                             │ │
│  │  • 0 código backend — lee el schema PostgreSQL               │ │
│  │  • Endpoints auto-generados: /calendar_interval,             │ │
│  │    /calendar_event, /calendar_schedule, /calendar_exception  │ │
│  │  • Filtros: ?tenant_id=eq.xxx&status=eq.OPEN                 │ │
│  │  • JWT auth integrado con bAuth                              │ │
│  │  • Swagger /docs automático                                  │ │
│  └──────────────────────┬──────────────────────────────────────┘ │
│                         │ SQL nativo                              │
│                         ▼                                         │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ PostgreSQL + rrule_plpgsql (Motor)  MIT · PGXN              │ │
│  │                                                             │ │
│  │  Tablas (schema pgcalendar adaptado):                        │ │
│  │  ┌──────────────────────────────────────────────────────┐   │ │
│  │  │ bAuth.calendar_interval                               │   │ │
│  │  │  • Gestión fiscal: FY2026, Q1-2026, Jan-2026          │   │ │
│  │  │  • tenant_id, empresa_id, sucursal_id (herencia)      │   │ │
│  │  │  • status: OPEN/SOFT_CLOSED/HARD_CLOSED/ARCHIVED     │   │ │
│  │  │  • postable_from/until (ventana back-posting)         │   │ │
│  │  │  • parent_interval (jerarquía FY→Q→M)                │   │ │
│  │  ├──────────────────────────────────────────────────────┤   │ │
│  │  │ bAuth.calendar_schedule                               │   │ │
│  │  │  • recurrence_type: DAILY/WEEKLY/MONTHLY/YEARLY       │   │ │
│  │  │  • recurrence_interval, day_of_week, day_of_month     │   │ │
│  │  │  • rrule TEXT (RFC 5545 completo vía rrule_plpgsql)  │   │ │
│  │  │  • start_date, end_date                               │   │ │
│  │  ├──────────────────────────────────────────────────────┤   │ │
│  │  │ bAuth.calendar_exception                              │   │ │
│  │  │  • exception_type: CANCELLED (festivo/cierre)         │   │ │
│  │  │  │                 MODIFIED (cambio de fecha)          │   │ │
│  │  │  • exception_date                                     │   │ │
│  │  │  • modified_start, modified_end (para MODIFIED)       │   │ │
│  │  └──────────────────────────────────────────────────────┘   │ │
│  │                                                             │ │
│  │  Funciones rrule_plpgsql:                                    │ │
│  │  • rrule.between(rrule, start, end) → fechas en rango       │ │
│  │  • rrule.overlaps() → validar no solapamiento               │ │
│  │  • pgcalendar.generate_projections() → expandir recurrencia │ │
│  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

### 5.3 Plan de Personalización (lo que SÍ hay que construir)

| Fase | Tarea | Horas | Entrega |
|------|-------|-------|---------|
| **C1** | Crear 3 tablas en `bAuth`: `calendar_interval`, `calendar_schedule`, `calendar_exception` | 4h | SQL en `001_bauth_init.sql` |
| **C2** | Instalar y configurar rrule_plpgsql en PostgreSQL | 1h | Extensión funcionando |
| **C3** | Implementar triggers: anti-solapamiento, herencia de cierre, generación de períodos | 4h | PL/pgSQL |
| **C4** | Instalar PostgREST y configurar schema `bAuth` | 2h | API REST auto-generada |
| **C5** | Integrar FullCalendar React en Core UI | 6h | Componente visual |
| **C6** | Conectar FullCalendar → PostgREST → PostgreSQL | 3h | CRUD funcional |
| **C7** | Configurar vista Resource Timeline por sucursal | 2h | Multi-sucursal |
| **C8** | Seeds: festivos Bolivia 2025-2030, gestiones base | 2h | Datos de referencia |
| **C9** | Pruebas: herencia cierre, back-posting, multi-sucursal | 3h | Test suite |
| **Total** | | **27h** | Calendario funcional |

### 5.4 Lo que NO construimos (ya existe)

| Componente | Herramienta | Licencia | Lo que nos ahorramos |
|-----------|-----------|----------|---------------------|
| UI de calendario | FullCalendar | MIT | ~200h de desarrollo frontend |
| API REST | PostgREST | MIT | ~80h de desarrollo backend |
| Motor de recurrencia | rrule_plpgsql | MIT | ~60h de algoritmo RFC 5545 |
| Triggers de solapamiento | pgcalendar | PGXN | ~20h de lógica de validación |
| Proyección de fechas | pgcalendar | PGXN | ~30h de generación de ocurrencias |
| **Total ahorrado** | | | **~390h** |

### 5.5 Cómo cubre cada necesidad del SBOS

| Necesidad SBOS | Solución | Precisión |
|---------------|----------|-----------|
| Un contador corrige factura de 2025 en Sucursal Norte | `calendar_interval` con status=SOFT_CLOSED en sucursal, postable_from vigente. rrule.between() valida que la fecha esté en ventana. | ✅ |
| Un cajero solo opera en gestión 2026 | Política D4: `(interval FY2026, L-V 08:00-16:00, enable Cajero)`. rrule_plpgsql evalúa la recurrencia. | ✅ |
| Feriado nacional bloquea operaciones | `calendar_exception` con type=CANCELLED, exception_date=01-01-2026. Aplica a todas las sucursales del tenant. | ✅ |
| Sucursal fronteriza cierra antes que empresa | `calendar_interval` sucursal: HARD_CLOSED. Empresa: SOFT_CLOSED. La sucursal es MÁS restrictiva (Odoo pattern). | ✅ |
| Tenant ofrece año fiscal Abr-Mar a empresa UK | `calendar_interval` con parent_interval=NULL, fechas 2026-04-01 a 2027-03-31. Independiente del calendario base del tenant. | ✅ |
| Mostrar todas las sucursales en pantalla | FullCalendar Resource Timeline: 1 columna por sucursal. Colores por status. | ✅ |

---


### 5.6 Las Tablas del Calendario — 5 Tablas (Diseño Reconsiderado)

**Investigación aplicada:** Google Calendar System Design (2025) + LinkedIn Calendar Interview + AppMaster PostgreSQL Recurring Patterns + RFC 5545 iCalendar.

**Principio clave (Google):** Separar el EVENTO (template) de la INSTANCIA (occurrence). El evento define QUÉ y CUÁNDO se repite. La instancia es UNA ocurrencia concreta en el tiempo. Esto permite:
- Consultar "qué pasa esta semana" sin expandir recurrencias cada vez
- Modificar UNA instancia sin afectar la serie completa
- Free/Busy rápido: consultar instances, no eventos

#### Tabla 1: `bAuth.calendar_event` — El template del evento

```sql
CREATE TABLE bAuth.calendar_event (
    event_id          UUID PK DEFAULT gen_random_uuid(),
    tenant_id         UUID NOT NULL,         -- scope: tenant dueño
    empresa_id        UUID,                  -- NULL = evento del tenant
    sucursal_id       UUID,                  -- NULL = evento de la empresa
    owner_id          UUID,                  -- NULL = organizacional; NOT NULL = personal
    calendar_name     TEXT DEFAULT 'default',-- 'work', 'personal', 'fiscal', 'process'
    event_type        TEXT NOT NULL,         -- MEETING, PROCESS, REMINDER, FISCAL_EVENT
    title             VARCHAR(512) NOT NULL,
    description       TEXT,
    location          VARCHAR(512),
    start_time        TIMESTAMPTZ NOT NULL,  -- primera ocurrencia
    end_time          TIMESTAMPTZ NOT NULL,
    all_day           BOOLEAN DEFAULT FALSE,
    timezone          VARCHAR(50) DEFAULT 'America/La_Paz',
    rrule             TEXT,                  -- RFC 5545: 'FREQ=WEEKLY;BYDAY=MO,WE,FR;COUNT=52'
    status            TEXT DEFAULT 'CONFIRMED',
    visibility        TEXT DEFAULT 'DEFAULT',-- DEFAULT, PUBLIC, PRIVATE
    process_name      TEXT,                  -- solo PROCESS: nombre del proceso a lanzar
    process_params    JSONB,                 -- solo PROCESS: parámetros
    ctx_id            TEXT NOT NULL,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_event_type CHECK (event_type IN ('MEETING','PROCESS','REMINDER','FISCAL_EVENT')),
    CONSTRAINT chk_event_status CHECK (status IN ('CONFIRMED','TENTATIVE','CANCELLED'))
);

CREATE INDEX idx_event_time ON bAuth.calendar_event(tenant_id, start_time, end_time);
CREATE INDEX idx_event_owner ON bAuth.calendar_event(owner_id, tenant_id);
```

#### Tabla 2: `bAuth.calendar_instance` — Ocurrencias materializadas (GOOGLE PATTERN)

```sql
CREATE TABLE bAuth.calendar_instance (
    instance_id       UUID PK DEFAULT gen_random_uuid(),
    event_id          UUID NOT NULL,         -- FK → calendar_event
    tenant_id         UUID NOT NULL,
    original_date     DATE NOT NULL,         -- fecha que le correspondería según RRULE
    start_time        TIMESTAMPTZ NOT NULL,  -- inicio real (puede diferir del template)
    end_time          TIMESTAMPTZ NOT NULL,  -- fin real
    is_exception      BOOLEAN DEFAULT FALSE, -- TRUE = esta instancia fue modificada
    status            TEXT DEFAULT 'CONFIRMED',
    ctx_id            TEXT,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (event_id, original_date)
);

CREATE INDEX idx_instance_time ON bAuth.calendar_instance(tenant_id, start_time, end_time);
CREATE INDEX idx_instance_event ON bAuth.calendar_instance(event_id, original_date);

COMMENT ON TABLE bAuth.calendar_instance IS
  '[Google Calendar] Instancia materializada de un evento recurrente.
   Se pre-expande una ventana de 60-90 días. Fuera de esa ventana se calcula dinámicamente.
   Optimiza queries de "qué pasa esta semana" sin expandir recurrencias cada vez.';
```

**Ventana de expansión (Google Hybrid Window):**
- Al crear/modificar un evento recurrente → expandir 90 días hacia adelante
- Un cron cada noche → expandir el día 91 (mantener siempre 90 días pre-calculados)
- Consultas más allá de 90 días → expansión dinámica con rrule_plpgsql

#### Tabla 3: `bAuth.calendar_exception` — Modificaciones/Cancelaciones

```sql
CREATE TABLE bAuth.calendar_exception (
    exception_id      UUID PK DEFAULT gen_random_uuid(),
    event_id          UUID NOT NULL,         -- FK → calendar_event
    interval_id       TEXT,                  -- FK → calendar_interval (nullable)
    original_date     DATE NOT NULL,
    exception_type    TEXT NOT NULL,         -- CANCELLED, MODIFIED
    modified_start    TIMESTAMPTZ,           -- solo MODIFIED
    modified_end      TIMESTAMPTZ,           -- solo MODIFIED
    reason            TEXT,
    ctx_id            TEXT NOT NULL,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (event_id, interval_id, original_date),
    CONSTRAINT chk_exception_target CHECK (
        (event_id IS NOT NULL AND interval_id IS NULL) OR
        (event_id IS NULL AND interval_id IS NOT NULL)
    ),
    CONSTRAINT chk_exception_type CHECK (exception_type IN ('CANCELLED','MODIFIED'))
);
```

#### Tabla 4: `bAuth.calendar_interval` — Períodos fiscales (sin cambios)

(Misma definición que antes — ver §4.6 original. UUID PK, tenant/empresa/sucursal, rrule, status.)

#### Tabla 5: `bAuth.calendar_attendee` — Participantes de reuniones (Google Calendar)

```sql
CREATE TABLE bAuth.calendar_attendee (
    attendee_id       UUID PK DEFAULT gen_random_uuid(),
    event_id          UUID NOT NULL,         -- FK → calendar_event
    user_id           UUID NOT NULL,
    response_status   TEXT DEFAULT 'PENDING',-- PENDING, ACCEPTED, DECLINED, TENTATIVE
    is_organizer      BOOLEAN DEFAULT FALSE,
    notified_at       TIMESTAMPTZ,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (event_id, user_id)
);
```

### 5.7 Cómo cada tabla cubre las necesidades

| Necesidad | Tabla(s) | Cómo |
|-----------|----------|------|
| "Reunión general SKULL todos los lunes 9AM" | event + instance | event.rrule='FREQ=WEEKLY;BYDAY=MO', instances pre-expandidas 90 días |
| "Cita médica María 15-Jun 14:00" | event | event_type=MEETING, owner_id=UUID_MARIA, rrule=NULL |
| "Cierre contable automático cada 31-Dic 23:00" | event + instance | event_type=PROCESS, process_name='cierre_contable', rrule='FREQ=YEARLY' |
| "Cancelar reunión del 20-Jun" | exception | exception_type=CANCELLED, original_date='2026-06-20' |
| "Mover feriado del lunes al viernes" | exception | exception_type=MODIFIED, modified_start/end ajustados |
| "¿Quién va a la reunión?" | attendee | SELECT con response_status |
| "¿Qué tengo esta semana?" | instance | SELECT WHERE start_time BETWEEN now() AND now()+7days (instantáneo) |
| "Gestión 2026 cierra 31-Dic" | interval | interval_type=FISCAL_YEAR, status=SOFT_CLOSED |
| "¿Está abierta la gestión para publicar?" | interval | SELECT status WHERE interval_id='FY2026' AND CURRENT_DATE BETWEEN postable_from AND postable_until |

### 5.8 Alertas, Notificaciones Multi-Canal y Auditoría (NUEVO)

**Problema detectado por el usuario:** El calendario debe generar alertas: reuniones envían WhatsApp, recordatorios por SMS, mensajes en la UI. La trazabilidad y auditoría deben ser controladas al extremo.

**Investigación aplicada:** [JMAP Calendars IETF 2025] [Twilio WhatsApp Reminder 2024] [AlgoMaster Notification Service 2025] [malnu-backend multi-channel PR].

#### Tabla 6: `bAuth.calendar_reminder` — Programa de alertas por evento

```sql
CREATE TABLE bAuth.calendar_reminder (
    reminder_id       UUID PK DEFAULT gen_random_uuid(),
    event_id          UUID NOT NULL,         -- FK → calendar_event
    user_id           UUID NOT NULL,         -- quién recibe la alerta
    remind_at         TIMESTAMPTZ NOT NULL,  -- cuándo disparar
    offset_minutes    INTEGER NOT NULL,      -- -30 = 30min antes, -1440 = 1 día antes
    channel           TEXT NOT NULL,         -- WHATSAPP, SMS, EMAIL, UI, PUSH
    priority          TEXT DEFAULT 'MEDIUM', -- CRITICAL, HIGH, MEDIUM, LOW
    status            TEXT DEFAULT 'PENDING',-- PENDING, SENT, DELIVERED, FAILED, READ
    retry_count       INTEGER DEFAULT 0,
    max_retries       INTEGER DEFAULT 3,
    sent_at           TIMESTAMPTZ,
    delivered_at      TIMESTAMPTZ,
    read_at           TIMESTAMPTZ,
    error_message     TEXT,
    ctx_id            TEXT NOT NULL,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_reminder_channel CHECK (channel IN ('WHATSAPP','SMS','EMAIL','UI','PUSH')),
    CONSTRAINT chk_reminder_status CHECK (status IN ('PENDING','SENT','DELIVERED','FAILED','READ'))
);

CREATE INDEX idx_reminder_fire ON bAuth.calendar_reminder(remind_at, status) WHERE status = 'PENDING';
CREATE INDEX idx_reminder_user ON bAuth.calendar_reminder(user_id, status);
```

#### Tabla 7: `bAuth.calendar_notification` — Registro de entrega (AUDITORÍA)

```sql
CREATE TABLE bAuth.calendar_notification (
    notification_id   UUID PK DEFAULT gen_random_uuid(),
    reminder_id       UUID,                  -- FK → calendar_reminder
    user_id           UUID NOT NULL,
    channel           TEXT NOT NULL,         -- WHATSAPP, SMS, EMAIL, UI, PUSH
    subject           VARCHAR(512),
    body              TEXT,
    provider          TEXT,                  -- TWILIO, SENDGRID, FCM, WHATSAPP_API
    provider_msg_id   TEXT,                  -- ID externo del proveedor
    provider_response JSONB,                 -- respuesta completa del proveedor
    status            TEXT DEFAULT 'PENDING',
    delivered_at      TIMESTAMPTZ,
    read_at           TIMESTAMPTZ,
    error_message     TEXT,
    ctx_id            TEXT NOT NULL,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_notif_channel CHECK (channel IN ('WHATSAPP','SMS','EMAIL','UI','PUSH'))
);

CREATE INDEX idx_notif_user ON bAuth.calendar_notification(user_id, created_at DESC);
CREATE INDEX idx_notif_reminder ON bAuth.calendar_notification(reminder_id);

COMMENT ON TABLE bAuth.calendar_notification IS
  '[JMAP IETF 2025] [malnu-backend] Registro WORM de cada notificación enviada.
   Trazabilidad completa: qué, a quién, por qué canal, resultado, respuesta del proveedor.';
```

#### Tabla 8: `bAuth.calendar_template` — Plantillas de mensajes por canal

```sql
CREATE TABLE bAuth.calendar_template (
    template_id       UUID PK DEFAULT gen_random_uuid(),
    name              TEXT NOT NULL UNIQUE,   -- 'event_reminder', 'event_cancelled', 'meeting_today'
    channel           TEXT NOT NULL,
    subject           VARCHAR(512),
    body_template     TEXT NOT NULL,          -- '⏰ {event_title} inicia a las {start_time}'
    variables         JSONB,                 -- ['event_title','start_time','location']
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_tpl_channel CHECK (channel IN ('WHATSAPP','SMS','EMAIL','UI','PUSH'))
);
```

#### Tabla 9: `bAuth.calendar_user_prefs` — Preferencias de notificación por usuario

```sql
CREATE TABLE bAuth.calendar_user_prefs (
    pref_id           UUID PK DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL,
    channel           TEXT NOT NULL,
    enabled           BOOLEAN DEFAULT TRUE,
    quiet_start       TIME,                  -- 22:00
    quiet_end         TIME,                  -- 07:00
    frequency         TEXT DEFAULT 'IMMEDIATE', -- IMMEDIATE, DIGEST_DAILY, DIGEST_WEEKLY
    UNIQUE (user_id, channel),
    CONSTRAINT chk_pref_channel CHECK (channel IN ('WHATSAPP','SMS','EMAIL','UI','PUSH'))
);
```

### 5.9 Trazabilidad y Auditoría Extrema

**Principio SFP-08:** Toda decisión basada en estándares internacionales.

| Requisito | Implementación | Estándar |
|-----------|---------------|----------|
| **Quién creó/modificó el evento** | `ctx_id` en TODAS las tablas (event, instance, exception, interval, reminder, notification) | ISO 27001 A.8.15 · W3C Trace Context |
| **Cuándo se envió la notificación** | `calendar_notification.sent_at` + `delivered_at` + `read_at` | JMAP IETF 2025 |
| **Qué respondió el proveedor** | `calendar_notification.provider_response` (JSONB completo) | PCI DSS 4.0 Req 10.3 |
| **Cuántos reintentos** | `calendar_reminder.retry_count` + `max_retries` | At-least-once delivery |
| **Hash-chain de integridad** | `prev_hash` + `entry_hash` en audit_events (ya existe) | PCI DSS 10.3 · ISO 27001 A.8.15 |
| **No se borra, se marca** | `status = 'CANCELLED'` en eventos, excepciones, notificaciones | ISO 24760-2 §8.3.7 |
| **Inmutabilidad de notificaciones** | REVOKE UPDATE/DELETE en calendar_notification (solo INSERT+SELECT) | ISO 27001 A.8.15 |

### 5.10 Flujo de una Alerta (ejemplo completo)

```
1. María crea reunión "Planificación Q1" para el 15-Ene-2026 09:00
   → calendar_event (rrule=NULL, event_type=MEETING)
   → calendar_attendee (invitados: Juan, Pedro)
   → calendar_reminder (offset=-30min, channel=WHATSAPP, user=Juan)
   → calendar_reminder (offset=-30min, channel=WHATSAPP, user=Pedro)
   → calendar_reminder (offset=-1440min, channel=EMAIL, user=María)

2. Cron cada 60 segundos:
   SELECT * FROM calendar_reminder
   WHERE remind_at <= NOW() AND status = 'PENDING'
   FOR UPDATE SKIP LOCKED

3. Para cada reminder:
   → Verificar user_prefs (¿canal habilitado? ¿horario silencio?)
   → Cargar template ('event_reminder', 'WHATSAPP')
   → Rellenar variables: {event_title}, {start_time}, {location}
   → Enviar vía WhatsApp Business API (Twilio)
   → INSERT en calendar_notification (status='SENT', provider_msg_id, provider_response)
   → UPDATE calendar_reminder (status='SENT', sent_at=NOW())

4. Webhook de Twilio confirma delivery:
   → UPDATE calendar_reminder (status='DELIVERED', delivered_at=NOW())

5. Auditoría: cada paso genera un audit_event con ctx_id
```

### 5.11 Resumen Final del Calendario

| Métrica | Valor |
|---------|-------|
| **Tablas totales** | **9** |
| **Tablas de calendario** | 5 (event, instance, exception, interval, attendee) |
| **Tablas de notificación** | 4 (reminder, notification, template, user_prefs) |
| **PKs** | **100% UUID** |
| **Canales de notificación** | 5 (WHATSAPP, SMS, EMAIL, UI, PUSH) |
| **Tipos de evento** | 4 (MEETING, PROCESS, REMINDER, FISCAL_EVENT) |
| **Niveles de visibilidad** | 4 (USER, SUCURSAL, EMPRESA, TENANT) |
| **Auditoría** | ctx_id en TODAS las tablas + calendar_notification WORM + hash-chain |
| **Ficha BOS** | `cal-fiscal` (puerto 28150, común a todas las apps) |
| **Motor recurrencia** | rrule_plpgsql + instances pre-expandidas 90 días |
| **Horas estimadas** | 40h (subió de 27h por notificaciones y auditoría) |


## 6. Diagnóstico y Estado Actual — Junio 23, 2026

> Ver §0 para el detalle completo de los 3 estados (PRODUCCIÓN → .BAK → PLATAFORMA).

### 6.1 Lo que FUNCIONA (no tocar)

| Componente | Estado | Detalle |
|-----------|--------|---------|
| `bauth_db` (VPS producción) | 🟢 85 tablas operativas | Base de datos en producción, funcionando (ESTADO 1, score 9%) |
| `.bak` (diseño DDL) | 🟡 103 tablas, 113 FKs | Plano de migración intermedia (ESTADO 2, score 39%) |
| UUID en PKs | 🟡 48/103 en .bak, 25/85 en prod | Migración parcial — completar a 103 |
| Hash-chains SHA-256 | 🟡 2 cadenas (.bak), 1 (prod) | `bos_audit_events` + `bos_rol_template_history` |
| Tablas WORM (REVOKE) | 🟢 3 tablas en .bak | Ampliar a 8+ |
| Particiones por mes | 🟡 3 tablas | Ampliar a 10+ |
| Seeds extraídos | 🟢 4 archivos | 050_geo.sql, 051_tier_policy.sql, 052_financial.sql, 053_security.sql |
| Identity Governance Platform | 🟢 Documentado | `BAUTH-IDENTITY-GOVERNANCE-AUDIT-PLATFORM.md` v4.0.0 |
| Estándares documentados | 🟢 12 estándares | §3.3 con controles específicos |
| Identity Governance Gaps | 🟢 Analizado | `BAUTH-IDENTITY-GOVERNANCE-GAPS.md` v2.0.0: 24 brechas |
| Audit Report | 🟢 Completado | `BAUTH-IDENTITY-GOVERNANCE-AUDIT-REPORT.md` v1.0.0: Score PROD 9% → .BAK 39% |
| Prefijos y schemas | 🟢 Definidos | §2 con 8 prefijos + bGlobal + bCalendar + bos |
| FASE A completada | 🟢 REFERENCES extraídas | 78 FKs desde git (commit 4db804c2), guardadas en `/tmp/fase_a_references.json` |

### 6.2 Lo que FALTA (priorizado) — ACTUALIZADO con Gaps de Trazabilidad

| # | Problema | Impacto | Solución |
|---|----------|---------|----------|
| 🔴 P1 | REFERENCES eliminadas del .bak | Sin FKs no hay integridad referencial | Restaurar REFERENCES. Usar orden topológico (tsort) al generar DDL con `build_ddl.sh` |
| 🔴 P2 | 80 columnas ALTER TABLE no integradas | CREATE TABLE incompletos | Integrar columnas en sus CREATE TABLE. **Cero ALTER TABLE en la DDL final.** |
| 🔴 P3 | `build_ddl.sh` no funcional | No hay generación automatizada | Re-escribir para: orden topológico + REFERENCES intactas + sin INSERTs + IF NOT EXISTS |
| 🔴 P4 | **24 gaps de Identity Governance & Audit** (GAP-01 a GAP-20) | Incumplimiento ISO 27001, PCI DSS, NIST | Ver `BAUTH-IDENTITY-GOVERNANCE-GAPS.md`. 9 críticos: ctx_id en 20 tablas, 3 tablas gobernanza, 38 identity events, hash-chains |
| 🔴 P5 | CHECK constraint de `audit_events` sin 38 eventos del catálogo | Notificaciones no pueden dispararse por evento específico | Expandir CHECK de 38 a 76 event_types (GAP-05) |
| 🔴 P6 | 20 tablas sin `ctx_id` (solo 25 de 103 lo tienen) | 78 tablas sin trazabilidad W3C | Agregar `ctx_id TEXT NOT NULL` a tablas prioritarias (GAP-01) |
| 🔴 P7 | Faltan 3 tablas de notificación en el DDL | Sin `cfg_notification_policy`, `cfg_domain_channel`, `aud_notification` | Crear las 3 tablas (SQL en BAUTH-TRAZABILIDAD §8.2) (GAP-07) |
| 🟡 P8 | `bauth_test` inconsistente | No se puede probar | Recrear desde cero con el DDL corregido |
| 🟡 P9 | Tablas del calendario + notificación no creadas | Solo en papel | Agregar CREATE TABLEs al .bak |
| 🟡 P10 | Hash-chains faltantes en 6 tablas WORM | `bos_sync_log`, `bos_policy_audit`, `bos_superuser_contexts` sin integridad | Agregar triggers hash-chain (GAP-04) |
| 🟡 P11 | 7 tablas sin particionar | Acumulación sin gestión | Agregar `PARTITION BY RANGE` (GAP-09) |
| 🟡 P12 | Sin política de retención explícita | PCI DSS 10.7.1 incumplido | Crear `cfg_retention_policy` + `audit_partition_maintenance()` (GAP-08) |
| 🟢 P13 | Seeds del calendario + notificación | Festivos Bolivia, gestiones base, 38 políticas | Crear seeds 060-063 con datos de referencia |

### 6.3 Reglas para la DDL final — AMPLIADO

| # | Regla | Fuente |
|---|-------|--------|
| R1 | **Cero ALTER TABLE** (solo CREATEs) | Usuario |
| R2 | **Cero INSERTs** (van en seeds separados) | Usuario |
| R3 | **100% UUID** para PKs | RFC 9562 · PostgreSQL 18+ |
| R4 | **REFERENCES intactas** con orden topológico | Integridad referencial |
| R5 | **IF NOT EXISTS** en todos los CREATE | Idempotencia |
| R6 | **COMMENT ON** con referencias a estándares | ISO/NIST/PCI documentados en header |
| R7 | **Nombres de tabla en inglés** con prefijos funcionales | §2.2 |
| R8 | **ctx_id en TODAS las tablas operativas** | SBOS-049 · W3C Trace Context (GAP-01) |
| R9 | **Hash-chain SHA-256 en TODAS las tablas WORM** | PCI DSS 10.3.2 (GAP-04) |
| R10 | **PARTITION BY RANGE para tablas de alto volumen** | PCI DSS 10.7 (GAP-09) |
| R11 | **REVOKE UPDATE/DELETE en tablas WORM** | ISO 27001 A.8.15 (GAP-04) |

### 6.4 Plan de Restauración de Integridad Referencial — Metodología Profesional

**Principio:** La restauración de REFERENCES no es un `sed` mecánico. Es una verificación
de integridad referencial con criterios normativos. Cada FK debe pasar 5 fases antes de
ser insertada en el DDL final.

**Origen de verdad:** El commit `695ae158` contiene el DDL original con REFERENCES intactas.
El `.bak` actual perdió las REFERENCES por una limpieza destructiva con `sed`.

```
FASE A: RECUPERAR       FASE B: VERIFICAR      FASE C: NORMALIZAR
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ git show OLD     │    │ ¿tabla destino  │    │ ¿tipo coincide? │
│ Extraer 113 FKs  │──►│ existe en .bak? │──►│ UUID ↔ UUID?    │
│ (schema.tabla)   │    │ ¿está en el     │    │ TEXT → UUID?    │
│                  │    │ orden correcto? │    │ SERIAL → UUID?  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
FASE E: INSERTAR               FASE D: REFERENCIAR     ▼
┌─────────────────┐    ┌────────────────────────────────┐
│ Insertar en     │    │ ¿qué estándar requiere esta FK? │
│ CREATE TABLE    │◄───│ ISO 27001 A.8.15?              │
│ con orden       │    │ PCI DSS 10.3?                  │
│ topológico      │    │ NIST AC-2/AC-5/AC-6?           │
│ (tsort)         │    │ Documentar en ANEXO A.         │
└─────────────────┘    └────────────────────────────────┘
```

#### FASE A: Recuperar REFERENCES desde git

**Objetivo:** Extraer el conjunto completo de REFERENCES del DDL original para tener la fuente de verdad.

```bash
cd BauthAgent/db/migrations
# El commit 695ae158 tiene el DDL original con REFERENCES
git show 695ae158:BauthAgent/db/migrations/001_bauth_init.sql > /tmp/ddl_original.sql

# Extraer REFERENCES con su tabla origen (contexto completo)
grep -B3 'REFERENCES' /tmp/ddl_original.sql | grep -E 'CREATE TABLE|REFERENCES' \
  | paste - - | sed 's/CREATE TABLE.*\.\([a-z_]*\).*REFERENCES/\1 → REFERENCES/' \
  | sort -u > /tmp/references_original.txt

wc -l /tmp/references_original.txt  # Debe ser ~113
```

**Resultado esperado:** Archivo `references_original.txt` con 113 entradas.
Cada línea: `tabla_origen → REFERENCES schema.tabla_destino(columna)`.

#### FASE B: Verificar existencia y orden topológico

**Objetivo:** Cada FK debe apuntar a una tabla que EXISTE en el .bak actual y que se crea ANTES que la tabla origen.

```bash
# Para cada REFERENCES extraída, verificar:
while IFS= read -r line; do
  dest=$(echo "$line" | grep -oP 'REFERENCES \K[a-z_]+\.[a-z_]+')
  dest_table="${dest#*.}"  # solo nombre de tabla sin schema
  dest_schema="${dest%.*}" # solo schema

  # Verificar existencia en el .bak
  if ! grep -q "CREATE TABLE.*${dest_table}" 001_bauth_init.sql.bak; then
    echo "❌ NO EXISTE: $line → tabla destino '$dest_table' no encontrada en .bak"
  else
    echo "✅ EXISTE: $line"
  fi
done < /tmp/references_original.txt
```

**Criterio de aceptación:** 0 tablas destino inexistentes. Si alguna tabla se renombró
(ANEXO A: `bauth.bos_audit_events` → `bAuth.aud_event`), la REFERENCES debe actualizarse
al nuevo nombre ANTES de insertarse en el DDL.

#### FASE C: Verificar compatibilidad de tipos (UUID ↔ UUID)

**Objetivo:** Con la estandarización 100% UUID, toda FK debe ser `UUID REFERENCES schema.tabla(UUID_PK)`.
Ninguna FK de tipo TEXT o SERIAL puede apuntar a una PK de tipo UUID.

```bash
# Para cada REFERENCES, verificar el tipo de la columna origen y destino
# Ejemplo de chequeo manual para una FK:
# Origen: bos_audit_events.user_uuid UUID REFERENCES bos_user_template(uuid)
# Destino: bos_user_template.uuid UUID
# → OK: UUID → UUID
#
# Contraejemplo:
# Origen: bos_delegation_log.rol_id TEXT REFERENCES bos_rol_template(id)
# Destino: bos_rol_template.id UUID
# → ❌ ERROR: TEXT → UUID. La columna origen debe migrar a UUID.
```

**Criterio de aceptación:**
- 0 TEXT FK apuntando a UUID PK
- 0 SERIAL FK apuntando a UUID PK
- Las FKs que antes eran TEXT→TEXT deben migrar a UUID→UUID (el .bak ya aplicó esto para PKs)

#### FASE D: Referenciar estándar normativo

**Objetivo:** Cada REFERENCES debe estar justificada por un estándar internacional.
Esto permite auditoría y cumplimiento.

| Estándar | Control | FK Ejemplo |
|----------|---------|-----------|
| ISO 27001 A.8.15 | Logging | `aud_event.user_uuid → idn_usuario.usuario_id` |
| NIST 800-53 AC-2 | Account Management | `idn_user_role.user_uuid → idn_usuario.usuario_id` |
| NIST 800-53 AC-5 | SoD | `idn_sod.role_a → idn_rol.rol_id` |
| NIST 800-53 AC-6 | Least Privilege | `privilege_role_atom.role_id → privilege_role.role_id` |
| PCI DSS 10.3 | Audit Records | `aud_notification.aud_event_id → aud_event.event_id` |
| GDPR Art.32 | Security | `ath_biometric.user_uuid → idn_usuario.usuario_id` |
| SBOS-049 §4 | Context Plane | `ses_session.tenant_id → idn_tenant.tenant_id` |

**Acción:** Cada REFERENCES insertada en el DDL debe tener un `COMMENT ON` documentando
el estándar que la requiere. Ejemplo:

```sql
COMMENT ON CONSTRAINT fk_audit_user ON bAuth.aud_event(user_uuid) IS
  '[ISO 27001 A.8.15] [NIST 800-53 AU-3] Trazabilidad de eventos de seguridad al usuario que los generó.';
```

#### FASE E: Insertar REFERENCES en el DDL con orden topológico

**Objetivo:** Insertar cada REFERENCES en su CREATE TABLE correspondiente, respetando
el orden topológico (tsort) para que PostgreSQL no rechace FKs a tablas aún no creadas.

**Procedimiento:**
1. Para cada CREATE TABLE en el .bak, identificar sus REFERENCES desde `references_original.txt`
2. Mapear el nombre OLD→NEW según ANEXO A (ej: `bauth.bos_user_template` → `bAuth.idn_usuario`)
3. Verificar que la tabla referenciada aparece ANTES en el orden topológico
4. Si no → reordenar las tablas (tsort)
5. Insertar la REFERENCES en la columna correspondiente
6. Agregar COMMENT ON CONSTRAINT con el estándar normativo (FASE D)

**Script de inserción (template para build_ddl.sh):**
```bash
# build_ddl.sh — paso de inserción de REFERENCES
while IFS= read -r line; do
  origin=$(echo "$line" | cut -d' ' -f1)
  fk=$(echo "$line" | grep -oP 'REFERENCES \K.*')
  # Aplicar mapeo OLD→NEW del ANEXO A
  new_fk=$(apply_annex_a_mapping "$fk")
  # Insertar REFERENCES en el CREATE TABLE de $origin
  insert_fk_into_create_table "$origin" "$new_fk"
done < /tmp/references_original.txt
```

### 6.5 Plan de Verificación de Normalización — Ampliado con Identity Governance

**Objetivo:** Verificar que el esquema cumple 1NF, 2NF, 3NF después de restaurar las REFERENCES.
Verificar también los criterios específicos de la Identity Governance & Audit Platform.
Los desvíos previos (7 documentados) deben seguir siendo los mismos.

#### 6.5.1 Verificación 1NF (Forma Normal Atómica)

| # | Verificación | Método | Criterio |
|---|-------------|--------|----------|
| N1 | Toda tabla tiene PK | `grep -c "PRIMARY KEY"` en cada CREATE TABLE = 1 | 103/103 |
| N2 | No hay grupos repetidos | Arrays TEXT[] y JSONB son atómicos en PostgreSQL | ✅ |
| N3 | Cada columna tiene tipo definido | Sin TEXT genérico sin newtype (ej: `currency_code CHAR(3)`) | ✅ |

#### 6.5.2 Verificación 2NF (Dependencia Funcional Completa)

| # | Verificación | Método | Criterio |
|---|-------------|--------|----------|
| N4 | PK compuesta sin dependencias parciales | `privilege_role_atom`: ¿`atom_position` depende solo de `atom_code`? | ✅ Documentado |
| N5 | `bos_rol_closure`: ¿`depth` depende de la PK completa (ancestor, descendant)? | Sí — closure table DAG | ✅ |
| N6 | `bos_context_sessions`: ¿columnas dependen de `ctx_id` completo? | Sí — 6 capas del Context Plane | ✅ |

#### 6.5.3 Verificación 3NF (Sin Dependencias Transitivas)

| # | Verificación | Método | Criterio |
|---|-------------|--------|----------|
| N7 | `tier → loa_required, mfa_required` | `bos_tier_policy` (tabla separada, 3NF) | ✅ |
| N8 | `mask_own_hex → sam128_*` | Columnas cacheadas por PrivilegeEngine — documentado | ✅ |
| N9 | Jerarquía sucursal→empresa→tenant | Desnormalización aceptada por SBOS-049 | ✅ |
| N10 | `sync_status → sync_error` | Columna de diagnóstico — NULL si != ERROR | ✅ |

#### 6.5.4 Verificación Identity Governance (NUEVA)

| # | Verificación | Método | Criterio | Ref Audit |
|---|-------------|--------|----------|-----------|
| N11 | `ctx_id` en tablas operativas | ≥ 45 tablas con `ctx_id TEXT NOT NULL` | `grep -c "ctx_id"` | GAP-01 |
| N12 | Hash-chains en tablas WORM | ≥ 8 tablas con `prev_hash + entry_hash + trigger` | `grep -c "entry_hash"` | GAP-04 |
| N13 | Particiones en tablas de alto volumen | ≥ 10 tablas con `PARTITION BY RANGE` | `grep -c "PARTITION BY"` | GAP-09 |
| N14 | WORM integrity (REVOKE) | ≥ 8 tablas con `REVOKE UPDATE, DELETE` | `grep -c "REVOKE UPDATE"` | GAP-04 |
| N15 | Índices GIN sobre JSONB | ≥ 8 índices `USING GIN (jsonb_path_ops)` | `grep -c "USING GIN"` | GAP-15 |
| N16 | Validación W3C traceparent | `ctx_id` con CHECK formato 55 caracteres | `grep -c "traceparent"` | GAP-A3 |

#### 6.5.5 Verificación de tipos post-UUID

| # | Verificación | Método | Estado Actual |
|---|-------------|--------|---------------|
| N17 | 0 TEXT PKs (excepto natural keys ISO) | `grep -c "TEXT.*PRIMARY KEY"` | ⚠️ Pendiente de verificar en .bak |
| N18 | 0 SERIAL/BIGSERIAL PKs | `grep -c "SERIAL.*PRIMARY KEY"` | ❌ 2 residuales (aud_event, login_attempt) |
| N19 | 103 UUID PKs con `DEFAULT gen_random_uuid()` | `grep -c "UUID.*PRIMARY KEY.*DEFAULT gen_random_uuid()"` | ⚠️ 48/103 verificado |
| N20 | Todas las FKs son UUID → UUID | Sin TEXT FK → UUID PK | ❌ Pendiente (FASE C de §6.4) |

### 6.6 Orden de Ejecución Actualizado — Identity Governance Audit Report

**Origen:** `BAUTH-IDENTITY-GOVERNANCE-AUDIT-REPORT.md` v1.0.0 — Score PROD 9% → .BAK 39%.
**Meta:** 100% → DDL listo para producción en `skSBOS_db`.

| # | Tarea | Fase | Estado | Ref Audit | Bitácora |
|---|-------|------|--------|-----------|----------|
| 1 | Leer PROTOCOLO-COMUNICACION-AGENTE.md | — | ✅ | — | — |
| 2 | **FASE A: Recuperar REFERENCES desde git** | 2.1 | 🟢 COMPLETADO | P1 | Commit `4db804c2` (DDL v2.0, 2288 líneas, 54 tablas). Extraídas 78 FKs con tabla origen, columna, tipo, destino. Guardado en `/tmp/fase_a_references.json`. 61 TEXT (78%), 15 UUID (19%), 2 BIGINT (3%). |
| 3 | **FASE A: Auditar bauth_db producción** | 2.1 | 🟢 COMPLETADO | P1 | VPS `13.140.128.230`. 85 tablas, 0 FKs, 11 ctx_id, 32 BIGINT PK, 27 TEXT PK, 25 UUID PK, 1 hash-chain. Score real: ~9%. |
| 4 | **FASE B: Verificar integridad referencial** (113 FKs → validar tipo UUID↔UUID, existencia tabla destino, orden topológico) | 2.3 | 🟢 COMPLETADO | P1 | 78 FKs verificadas contra 103 tablas del .bak. 17 ✅ tipo compatible, 60 ⚠️ TEXT→UUID (FASE C), 1 ❌ `bauth.bos_verbo` reemplazada por `bos_privilege.bos_verb`. Resultados en `/tmp/fase_b_resultados.json`. |
| 7 | **FASE E: Insertar REFERENCES corregidas con orden topológico** | 2.3 | 🟢 COMPLETADO (plan) | P1 | .bak tiene 82 FKs: 55 ✅ UUID→UUID (67%), 23 ❌ TEXT→UUID en 17 tablas, 4 ❓ otros. Generado plan de corrección: 26 columnas TEXT→UUID, orden tsort de 67 tablas, COMMENT ON CONSTRAINT con estándares FASE D. Plan en `/tmp/fase_e_plan_correccion.json`. La corrección SQL real la ejecuta `build_ddl.sh`. |
| 6 | **Integrar 80 columnas ALTER TABLE → CREATE TABLE** (16 tablas, ver §7.Y) | 2.5 | 🔴 | P2, C6 |
| 8 | **Re-escribir build_ddl.sh v8** (orden topológico + REFERENCES + TEXT→UUID + IF NOT EXISTS) | 2.2 | 🟢 COMPLETADO | P3 | v8 genera `002_bauth_reconstruccion.sql`: 97 tablas, 225 FKs, 26/26 TEXT→UUID corregidas (17 tablas), 10 funciones, 11 triggers, 6469 líneas. Orden tsort (67 tablas, 0 ciclos). Quedan 32 TEXT FKs naturales (CHAR/ISO) y 80 ALTER TABLE por depurar. |
| 8 | **Probar DDL en bauth_test** → DROP + CREATE hasta 0 errores | 2.5 | 🔴 | P4 |
| 9 | **Probar idempotencia** (2ª ejecución = solo NOTICEs, 0 ERRORes) | 2.10 | 🔴 | P4 |
| 10 | **C1: Crear 3 tablas ITDR** (cfg_notification_policy, cfg_domain_channel, aud_notification) | 2.13 | 🔴 | C1 |
| 11 | **C2: Expandir CHECK a 76 event_types** (38 genéricos + 38 dominio-específicos) | 2.11 | 🔴 | C2 |
| 12 | **C3: Agregar ctx_id a 20 tablas** (prioritarias: login_attempt, delegation_log, superuser, keys, backup, device, access_reviews, ghost) | 2.12 | 🔴 | C3 |
| 13 | **C4: Agregar hash-chains a 6 tablas WORM** (sync_log, policy_audit, superuser, atom_audit, authenticator_revocation, login_attempt) | 2.18 | 🔴 | C4 |
| 14 | **C5: Particionar 7 tablas** (sync_log, policy_audit, superuser, key_rotation, access_reviews, ghost, context_switches) | 2.19 | 🔴 | C5 |
| 15 | **C7: Corregir bug PK superuser_contexts** (doble DEFAULT) | 2.16 | 🔴 | C7 |
| 16 | **C8: Migrar SERIAL→UUID en aud_event + login_attempt** | 2.22 | 🔴 | C8 |
| 17 | **C9: Crear cfg_retention_policy + función partition_maintenance** | 2.14 | 🔴 | C9 |
| 18 | **A3: Validación W3C traceparent** (CHECK 55 caracteres) | 2.23 | 🔴 | A3 |
| 19 | **A4: Columnas NIST AC-7 en login_attempt** | 2.24 | 🔴 | A4 |
| 20 | **A5: Crear audit_evidence** (adjuntos PCI DSS 10.3) | 2.15 | 🔴 | A5 |
| 21 | **A7: Crear cfg_event_compliance** (mapeo event→estándar) | 2.25 | 🔴 | A7 |
| 22 | **A6: Testigos criptográficos en key_rotation_log** | 2.26 | 🔴 | A6 |
| 23 | **Columnas de alerta en aud_event** (notification_sent, acknowledged_at, acknowledged_by, escalated_at) | 2.29 | 🟠 | A1 |
| 24 | **Índices GIN adicionales** (policy_audit, atom_audit, compliance_map) | 2.30 | 🟠 | A2 |
| 25 | **audit_partition_maintenance()** — función PL/pgSQL | 2.31 | 🟠 | A8 |
| 26 | **witness + fingerprint en key_rotation_log** | 2.32 | 🟠 | A6 |
| 27 | **Corregir context_sessions PK vs traceparent** | 2.33 | 🟡 | M1 |
| 28 | **ctx_id en login_attempt** | 2.34 | 🟡 | M2 |
| 29 | **ctx_id en recovery_challenge + password_screening** | 2.35 | 🟡 | M3 |
| 30 | **ctx_id + notification_sent en ghost_accounts + access_reviews** | 2.36 | 🟡 | M4 |
| 31 | Ejecutar seeds (035-040 + 060-063) en bauth_test | FASE 3 | 🟡 | — |
| 32 | Verificación final: ≥45 tablas ctx_id, ≥8 hash-chains, ≥10 particiones, 0 ALTER, 100% UUID | FASE 4 | 🟡 | — |
| 33 | Commit DDL + seeds + compliance report | FASE 5 | 🟢 | — |

**Total: 33 pasos · 21 críticos (🔴) · 6 altos (🟠) · 6 medios (🟡) · Score esperado: 39% → 100%**

---

## 7. Plan de Ejecución por Fases

### FASE 1: Análisis y Preparación `[PENDIENTE]`

| # | Tarea | Estado |
|---|-------|--------|
| 1.1 | Confirmar prefijo de tablas con el usuario | 🟢 COMPLETADO |
| 1.2 | Backup de DDL actual | 🟢 COMPLETADO |
| 1.3 | Extraer INSERTs a seeds independientes | 🟢 COMPLETADO |
| 1.4 | Mapear grafo de dependencias FK (orden topológico) | 🟢 COMPLETADO |
| 1.5 | Identificar columnas ALTER TABLE a integrar en CREATE TABLE | 🟢 COMPLETADO |
| 1.6 | Listar todas las tablas con columnas, constraints, índices | 🟢 COMPLETADO |

### 7.X Resultados del Análisis de Dependencias FK

**104 dependencias FK analizadas · 0 ciclos detectados · 67 tablas en orden topológico**

#### Raíces del grafo (Nivel 0 — sin dependencias)

Estas 29 tablas no referencian a ninguna otra. Se crean primero:

`bos_application`, `bos_domain`, `bos_financial_document_operation`, `bos_financial_tipo_transaccion`, `bos_idioma`, `bos_merkle_batch`, `bos_onchain_account`, `bos_pais`, `bos_rol_template`, `bos_role`, `bos_saga_catalog`, `bos_tenant`, `bos_verb`, `bos_zona_logica`, `bos_area_fisica`, `bos_authenticator_binding`, `bos_ciudad`, `bos_edificio`, `bos_empresa`, `bos_moneda`, `bos_piso`, `bos_pos_logico`, `bos_sitio_fisico`, `bos_sucursal`, `bos_tenant_gestion`, `bos_timezone`, `bos_user_template`, `bos_atom_catalog`, `bos_group`

#### Orden topológico completo (67 tablas)

Ver archivo `/tmp/topo_order.txt` en el servidor de desarrollo.

#### Nota sobre self-reference

`bos_rol_template` tiene FK a sí misma (`parent_id → bos_rol_template.id`). PostgreSQL soporta self-referencing FKs en CREATE TABLE — no requiere ALTER.

---

### 7.Y Resultados del Análisis de ALTER TABLE

**80 columnas en 16 tablas** deben integrarse en sus CREATE TABLE originales.

| # | Tabla | Columnas a integrar | Cantidad |
|---|-------|---------------------|----------|
| 1 | `bos_tenant_config` | locale, timezone, currency_default, supported_locales | 4 |
| 2 | `bos_tenant_domain` | active | 1 |
| 3 | `bos_pais` | codice_iso_alfa2, alfa3, num, nombre_es, nombre_en, continente, region, flag_emoji, codigo_telefonico | 9 |
| 4 | `bos_moneda` | codice_num, nombre_es, nombre_en, simbolo, simbolo_int, precision, pais_emisor | 7 |
| 5 | `bos_idioma` | locale, codice_iso_639_1, codice_iso_639_2, nombre_nativo, nombre_es, direccion_texto, flag_emoji | 7 |
| 6 | `bos_timezone` | nombre_es, utc_offset, utc_offset_min, observa_dst, pais, ciudad_principal | 6 |
| 7 | `bos_financial_tipo_transaccion` | categoria, riesgo, requiere_dual_control, requiere_evidencia, notificacion_sin | 5 |
| 8 | `bos_zona_logica` | categoria, ambito, es_critica, requiere_segregacion | 4 |
| 9 | `bos_credential_policy` | nombre, credential_type, min_strength_bits, ttl_max_dias, rota_por_tiempo, rota_post_compromiso, rota_post_evento, requiere_breach_screening, historial_retencion | 9 |
| 10 | `bos_financial_document_operation` | operacion_id, tipo_documento, verbo, afecta_dosificacion, requiere_firma_digital, notifica_sin | 6 |
| 11 | `bos_sod_conflict_matrix` | bit_a, bit_b, risk_level, action, rationale | 5 |
| 12 | `bos_context_sessions` | pre_auth_session_id, session_rotated_at, absolute_timeout_at, idle_timeout_secs | 4 |
| 13 | `bos_user_template` | consecutive_failures, locked_until, lockout_reason, hibp_screened_at | 4 |
| 14 | `bos_access_reviews` | review_cycle_id, cycle_start_date, cycle_end_date | 3 |
| 15 | `bos_mfa_enrollments` | binding_loa, enrollment_authority, revocation_reason, revoked_by | 4 |
| 16 | `bos_delegation_log` | criticality | 1 |

**ALTER TABLE que se CONSERVAN** (no son columnas, son configuraciones de seguridad):
- `bos_audit_events ENABLE ROW LEVEL SECURITY` → se mantiene (es pos-creación)
- `bos_audit_events FORCE ROW LEVEL SECURITY` → se mantiene (es pos-creación)

---

### FASE 2: Reconstrucción DDL (solo CREATEs) `[EN PROGRESO]`

| # | Tarea | Estado |
|---|-------|--------|
| 2.1 | Crear base de datos de prueba `bauth_test` en VPS | 🟢 COMPLETADO |
| 2.1a | **FASE A: Extraer REFERENCES desde git** (78 FKs, commit `4db804c2`) | 🟢 COMPLETADO — Ver `/tmp/fase_a_references.json` |
| 2.1b | **FASE A: Auditar bauth_db producción** (85 tablas, 0 FKs, score 9%) | 🟢 COMPLETADO — Ver §0.1 |
| 2.2 | Script `build_ddl.sh` — generador automatizado desde .bak | 🟢 v6: 94 tablas, 91 creadas, 38 errores |
| 2.3 | Órden topológico con tsort | 🟢 67 tablas ordenadas, 0 ciclos |
| 2.4 | REFERENCES intactas (sin limpieza destructiva) | 🟢 Se conservan las FK originales |
| 2.5 | Depurar errores restantes hasta 0 | 🟡 38 errores por depurar |
| 2.6 | CREATE OR REPLACE FUNCTION | ⚪ NO INICIADO |
| 2.7 | Triggers con DO blocks | ⚪ NO INICIADO |
| 2.8 | COMMENT ON con referencias a estándares | ⚪ NO INICIADO |
| 2.9 | Prefijos (idn_, ath_, ses_, etc.) | ⚪ NO INICIADO |
| 2.10 | Idempotencia (2ª ejecución = 0 errores) | ⚪ NO INICIADO |
| **2.11** | **Expandir CHECK constraint de audit_events a 76 event_types** (GAP-05) | ⚪ NO INICIADO |
| **2.12** | **Agregar ctx_id a 20 tablas prioritarias** (GAP-01) | ⚪ NO INICIADO |
| **2.13** | **Crear 3 tablas de notificación** (GAP-07) | ⚪ NO INICIADO |
| **2.14** | **Crear tabla cfg_retention_policy + función partition_maintenance** (GAP-08) | ⚪ NO INICIADO |
| **2.15** | **Crear tabla audit_evidence** (GAP-14) | ⚪ NO INICIADO |
| **2.16** | **Corregir PK rota en bos_superuser_contexts** (GAP-10) | ⚪ NO INICIADO |
| **2.17** | **Agregar 6 columnas de notificación a audit_events** (GAP-06) | ⚪ NO INICIADO |
| **2.18** | **Agregar hash-chains a 6 tablas WORM sin integridad** (GAP-04) | ⚪ NO INICIADO |
| **2.19** | **Particionar 7 tablas de alto volumen** (GAP-09) | ⚪ NO INICIADO |
| **2.20** | **Robustecer bos_superuser_contexts con 7 columnas** (GAP-11) | ⚪ NO INICIADO |
| **2.21** | **Agregar índices GIN sobre JSONB en tablas de auditoría** (GAP-15) | ⚪ NO INICIADO |
| **2.22** | **Migrar SERIAL/BIGSERIAL a UUID en aud_event y login_attempt** (GAP-C8) | ⚪ NO INICIADO |
| **2.23** | **Agregar validación W3C traceparent en ctx_id** (GAP-A3, 55 caracteres) | ⚪ NO INICIADO |
| **2.24** | **Agregar columnas NIST AC-7 en login_attempt** (GAP-A4: lockout_level, lockout_expires_at, mitigation_applied) | ⚪ NO INICIADO |
| **2.25** | **Crear tabla cfg_event_compliance** (GAP-A7: mapeo event_type→estándar) | ⚪ NO INICIADO |
| **2.26** | **Robustecer key_rotation_log con testigos criptográficos** (GAP-A6: witness_1, witness_2, key_fingerprint_old/new) | ⚪ NO INICIADO |

> 📎 Documento completo de gaps: `BAUTH-IDENTITY-GOVERNANCE-GAPS.md` — 24 brechas contra 12 estándares, 9 críticas.
> 📎 Informe de auditoría: `BAUTH-IDENTITY-GOVERNANCE-AUDIT-REPORT.md` — Score 39% → Meta 100%.

### FASE 2.5: Correcciones de Prioridad ALTA (Post-críticas) `[PENDIENTE]`

Ejecutar después de que las tareas 2.1-2.26 estén completas y el DDL compile sin errores.

| # | Gap Audit | Tarea | Origen | Estado |
|---|----------|-------|--------|--------|
| 2.27 | A3 | Agregar CHECK constraint W3C traceparent (55 chars: `00-{trace}-{parent}-00`) en `ctx_id` de `aud_event` | Audit Report §A3 | ⚪ |
| 2.28 | A5 | Crear tabla `audit_evidence` para adjuntos de evidencia (PCI DSS 10.3) | GAP-14 | ⚪ |
| 2.29 | A1 | Agregar 4 columnas de alerta a `aud_event`: `notification_sent`, `acknowledged_at`, `acknowledged_by`, `escalated_at`, `escalated_to` | GAP-06 | ⚪ |
| 2.30 | A2 | Agregar índices GIN en `bos_policy_audit`, `bos_atom_audit`, `bos_compliance_map` | GAP-15 | ⚪ |
| 2.31 | A8 | Crear función PL/pgSQL `audit_partition_maintenance()` — auto-crea particiones 2 meses adelante | GAP-08 §función | ⚪ |
| 2.32 | A6 | Agregar columnas de ceremonia a `bos_key_rotation_log`: `witness_1`, `witness_2`, `key_fingerprint_old`, `key_fingerprint_new` | Audit Report §A6 | ⚪ |

### FASE 2.6: Correcciones de Prioridad MEDIA (Post-DDL) `[PENDIENTE]`

Ejecutar después de FASE 2.5. Son mejoras de calidad sin impacto estructural.

| # | Gap Audit | Tarea | Origen | Estado |
|---|----------|-------|--------|--------|
| 2.33 | M1 | Corregir `bos_context_sessions`: PK `session_id UUID` + `w3c_traceparent TEXT UNIQUE` (separar identificador interno del W3C) | Audit Report §M1 | ⚪ |
| 2.34 | M2 | Agregar `ctx_id` a `bos_login_attempt` (rompe la cadena de trazabilidad de ataques) | GAP-02 | ⚪ |
| 2.35 | M3 | Agregar `ctx_id` a `bos_recovery_challenge` y `bos_password_screening_log` | GAP-17, GAP-18 | ⚪ |
| 2.36 | M4 | Agregar `ctx_id` + `notification_sent` a `bos_ghost_accounts` y `bos_access_reviews` | GAP-19 | ⚪ |

### Hoja de Ruta Visual de la Corrección

```
FASE 2 (Críticas) ─────────────────────────────────────────────┐
  2.1-2.10: Reconstrucción base (REFERENCES, ALTER, build_ddl)  │
  2.11-2.21: Identity Governance crítico (11 tareas)            │ 39% → 70%
  2.22-2.26: Críticos adicionales del audit report (5 tareas)   │
────────────────────────────────────────────────────────────────┘
FASE 2.5 (Altas) ──────────────────────────────────────────────┐
  2.27-2.32: Mejoras de calidad (6 tareas)                      │ 70% → 90%
────────────────────────────────────────────────────────────────┘
FASE 2.6 (Medias) ─────────────────────────────────────────────┐
  2.33-2.36: Ajustes finos (4 tareas)                           │ 90% → 100%
────────────────────────────────────────────────────────────────┘
                           🎯 DDL LISTO PARA PRODUCCIÓN
```

### FASE 3: Seeds Independientes `[PENDIENTE]`

| # | Tarea | Archivo | Estado |
|---|-------|---------|--------|
| 3.1 | Geografía y monedas | `seeds/035_geografia.sql` | ⚪ NO INICIADO |
| 3.2 | Framework auth | `seeds/036_framework.sql` | ⚪ NO INICIADO |
| 3.3 | Privilegios y átomos | `seeds/037_privilegios.sql` | ⚪ NO INICIADO |
| 3.4 | Seguridad | `seeds/038_seguridad.sql` | ⚪ NO INICIADO |
| 3.5 | Blockchain | `seeds/039_blockchain.sql` | ⚪ NO INICIADO |
| 3.6 | Tenant SKULL | `seeds/040_tenant_skull.sql` | ⚪ NO INICIADO |
| **3.7** | **Políticas de notificación (38 políticas × 5 dominios)** | **`seeds/060_notification_policies.sql`** | ⚪ NO INICIADO |
| **3.8** | **Feriados Bolivia + LATAM 2025-2030** | **`seeds/061_calendar_holidays.sql`** | ⚪ NO INICIADO |
| **3.9** | **Retention policies (12 tablas)** | **`seeds/062_retention_policies.sql`** | ⚪ NO INICIADO |
| **3.10** | **Event compliance mapping (38 eventos × 12 estándares)** | **`seeds/063_event_compliance.sql`** | ⚪ NO INICIADO |

### FASE 4: Pruebas en VPS `bauth_test` `[PENDIENTE]`

| # | Tarea | Criterio de éxito | Estado |
|---|-------|-------------------|--------|
| 4.1 | `DROP DATABASE IF EXISTS bauth_test; CREATE DATABASE bauth_test` | BD creada | ⚪ |
| 4.2 | Ejecutar DDL (112+ tablas) | **0 ERRORES** | ⚪ |
| 4.3 | Ejecutar seeds en orden | **0 ERRORES** | ⚪ |
| 4.4 | Verificar integridad referencial (104+ FKs) | **0 FK violations** | ⚪ |
| 4.5 | Verificar normalización 1NF/2NF/3NF | Cumplimiento confirmado | ⚪ |
| 4.6 | Verificar hash-chains (≥8 cadenas) | `SELECT * FROM bAuth.audit_events WHERE prev_hash IS NULL LIMIT 1` → 1 fila (génesis) | ⚪ |
| 4.7 | Verificar ctx_id en ≥45 tablas | Todas las tablas operativas tienen `ctx_id TEXT NOT NULL` | ⚪ |
| 4.8 | Ejecutar DDL segunda vez (idempotencia) | **0 ERRORES**, solo NOTICEs | ⚪ |
| 4.9 | Ejecutar seeds segunda vez (idempotencia) | **0 ERRORES**, ON CONFLICT | ⚪ |
| 4.10 | Si hay errores → corregir → volver a 4.1 | Iterar hasta 0 errores | ⚪ |

### FASE 5: Cierre `[PENDIENTE]`

| # | Tarea | Estado |
|---|-------|--------|
| 5.1 | Commit de DDL + seeds al repositorio | ⚪ NO INICIADO |
| 5.2 | Documento de cumplimiento normativo final | ⚪ NO INICIADO |
| 5.3 | Migración controlada a `bauth_db` de producción | ⚪ NO INICIADO |

---


## ANEXO A — Tabla de Clasificación OLD→NEW

### A.1 Mapeo Completo OLD → NEW

Cada renombrado incluye: **nombre actual** → **nombre nuevo** + **schema** + **motivo**.

#### Schema: bAuth · Prefijo: idn_ (Identidad) — 28 tablas

| # | Nombre Actual | Nombre Nuevo | Schema | Motivo |
|---|---------------|-------------|--------|--------|
| 1 | `bauth.bos_tenant` | `bauth.idn_tenant` | bauth | ✅ CONSTRUIDO. Entidad raíz multi-tenant. UUIDv7 PK, 45 columnas, 7 ENUMs, 36 COMMENTs, 5 índices skip scan. |
| 2 | `bauth.bos_tenant_config` | `bAuth.idn_tenant_config` | bAuth | Configuración regional del tenant. |
| 3 | `bauth.bos_tenant_verification` | `bAuth.idn_tenant_verification` | bAuth | Verificación KYC del tenant. |
| 4 | `bauth.bos_tenant_domain` | `bAuth.idn_tenant_domain` | bAuth | Dominios FQDN por tenant. |
| 5 | `bauth.bos_tenant_network` | `bAuth.idn_tenant_network` | bAuth | Redes autorizadas por tenant. |
| 6 | `bauth.bos_empresa` | `bAuth.idn_empresa` | bAuth | Empresa dentro del tenant. |
| 7 | `bauth.bos_sucursal` | `bAuth.idn_sucursal` | bAuth | Sucursal de la empresa. |
| 8 | `bauth.bos_pos_logico` | `bAuth.idn_pos` | bAuth | Terminal lógico (POS/caja). |
| 9 | `bauth.bos_user_template` | `bAuth.idn_usuario` | bAuth | Identidad digital del usuario. |
| 10 | `bauth.bos_user_consent` | `bAuth.idn_user_consent` | bAuth | Consentimientos GDPR del usuario. |
| 11 | `bauth.bos_user_role_assignment` | `bAuth.idn_user_role` | bAuth | Asignación usuario↔rol. |
| 12 | `bauth.bos_rol_template` | `bAuth.idn_rol` | bAuth | Plantilla de rol (fuente de verdad). |
| 13 | `bauth.bos_rol_template_history` | `bAuth.idn_role_history` | bAuth | Historial WORM de cambios al rol. |
| 14 | `bauth.bos_tier_policy` | `bAuth.idn_tier` | bAuth | Políticas por tier NIST 800-63B-4. |
| 15 | `bauth.bos_sod_conflict_matrix` | `bAuth.idn_sod` | bAuth | Matriz de Separación de Deberes. |
| 16 | `bauth.bos_rol_closure` | `bAuth.idn_role_closure` | bAuth | Closure table DAG de herencia H-RBAC. |
| 17 | `bauth.bos_delegation_log` | `bAuth.idn_delegation` | bAuth | Delegaciones temporales de roles. |
| 18 | `bauth.bos_recovery_method` | `bAuth.idn_recovery` | bAuth | Métodos de recuperación de cuenta. |
| 19 | `bauth.bos_recovery_challenge` | `bAuth.idn_recovery_challenge` | bAuth | Desafíos de recuperación (hash). |
| 20 | `bauth.bos_permiso_logico` | `bAuth.idn_permiso` | bAuth | Permiso granular: zona × verbo × rol. |
| 21 | `bauth.bos_zona_logica` | `bAuth.idn_zona` | bAuth | Zona de negocio lógica. |
| 22 | `bauth.bos_zone_application_map` | `bAuth.idn_zona_app` | bAuth | Mapeo zona ↔ aplicación. |
| 23 | `bauth.bos_domain_config` | `bAuth.idn_domain_config` | bAuth | Activación de dominios por tenant. |
| 24 | `bauth.bos_global_config` | `bAuth.idn_global_config` | bAuth | Parámetros globales del sistema. |
| 25 | `bauth.bos_framework_version` | `bAuth.idn_framework_version` | bAuth | Versionado semántico de frameworks. |
| 26 | `bauth.bos_vdi_profiles` | `bAuth.idn_vdi` | bAuth | Perfiles de escritorio virtual. |
| 27 | `bauth.bos_ghost_accounts` | `bAuth.idn_ghost_account` | bAuth | Detección de cuentas abandonadas. |
| 28 | `bauth.bos_access_reviews` | `bAuth.idn_access_review` | bAuth | Campañas de recertificación (SOC 2). |

#### Schema: bAuth · Prefijo: ath_ (Autenticación) — 15 tablas

| # | Nombre Actual | Nombre Nuevo | Schema | Motivo |
|---|---------------|-------------|--------|--------|
| 29 | `bauth.bos_auth_method` | `bAuth.ath_method` | bAuth | Catálogo de métodos de autenticación. |
| 30 | `bauth.bos_auth_policy` | `bAuth.ath_policy` | bAuth | Políticas de autenticación por tier. |
| 31 | `bauth.bos_auth_config` | `bAuth.ath_config` | bAuth | Configuración operativa del motor auth. |
| 32 | `bauth.bos_auth_method_enrollment_log` | `bAuth.ath_enrollment` | bAuth | Registro de enrolamiento de métodos. |
| 33 | `bauth.bos_mfa_enrollments` | `bAuth.ath_mfa` | bAuth | Dispositivos MFA del usuario. |
| 34 | `bauth.bos_password_history` | `bAuth.ath_password` | bAuth | Historial de contraseñas (NIST screening). |
| 35 | `bauth.bos_password_screening_log` | `bAuth.ath_password_screening` | bAuth | Cribado HIBP k-anonymity. |
| 36 | `bauth.bos_biometric_templates` | `bAuth.ath_biometric` | bAuth | Plantillas biométricas (RGPD Art.9). |
| 37 | `bauth.bos_credential_policy` | `bAuth.ath_credential` | bAuth | Políticas de credenciales. |
| 38 | `bauth.bos_credential_rotation_log` | `bAuth.ath_credential_rotation` | bAuth | Rotación de credenciales. |
| 39 | `bauth.bos_token_delivery_log` | `bAuth.ath_token` | bAuth | Entrega de tokens de autenticación. |
| 40 | `bauth.bos_authenticator_binding` | `bAuth.ath_binding` | bAuth | Vínculo authenticator↔subscriber (NIST §5.2). |
| 41 | `bauth.bos_authenticator_revocation` | `bAuth.ath_revocation` | bAuth | Revocación de authenticators. |
| 42 | `bauth.bos_federation_protocol` | `bAuth.ath_federacion` | bAuth | Protocolos de federación (OAuth 2.1, SAML, OIDC). |
| 43 | `bauth.bos_crypto_algorithm` | `bAuth.ath_cripto` | bAuth | Catálogo de algoritmos criptográficos (FIPS 140-3). |

#### Schema: bAuth · Prefijo: ses_ (Sesiones) — 2 tablas

| # | Nombre Actual | Nombre Nuevo | Schema | Motivo |
|---|---------------|-------------|--------|--------|
| 44 | `bauth.bos_context_sessions` | `bAuth.ses_session` | bAuth | Sesión del Context Plane 6 capas (SBOS-049). |
| 45 | `bauth.bos_context_switches` | `bAuth.ses_session_switch` | bAuth | Historial de cambios de contexto operativo. |

#### Schema: bAuth · Prefijo: fin_ (Financiero) — 6 tablas

| # | Nombre Actual | Nombre Nuevo | Schema | Motivo |
|---|---------------|-------------|--------|--------|
| 46 | `bauth.bos_financial_limit` | `bAuth.fin_limit` | bAuth | Límites financieros por operación/día/mes. |
| 47 | `bauth.bos_financial_decision_matrix` | `bAuth.fin_matrix` | bAuth | Matriz de decisión de aprobación. |
| 48 | `bauth.bos_financial_approval` | `bAuth.fin_approval` | bAuth | Registro de aprobaciones financieras. |
| 49 | `bauth.bos_financial_document_operation` | `bAuth.fin_operation` | bAuth | Operaciones sobre documentos financieros. |
| 50 | `bauth.bos_financial_role_permission` | `bAuth.fin_permission` | bAuth | Permisos financieros por rol. |
| 51 | `bauth.bos_financial_tipo_transaccion` | `bAuth.fin_transaction` | bAuth | Tipos de transacción financiera (ISO 20022). |

#### Schema: bAuth · Prefijo: aud_ (Auditoría) — 7 tablas

| # | Nombre Actual | Nombre Nuevo | Schema | Motivo |
|---|---------------|-------------|--------|--------|
| 52 | `bauth.bos_audit_events` | `bAuth.aud_event` | bAuth | Registro WORM inmutable (ISO 27001 A.8.15). Particionado por mes. |
| 53 | `bauth.bos_sync_log` | `bAuth.aud_sync` | bAuth | Registro de sincronización bAuth→KC+Tryton. WORM. |
| 54 | `bauth.bos_policy_audit` | `bAuth.aud_policy_audit` | bAuth | Auditoría WORM de cambios de políticas. |
| 55 | `bauth.bos_policy_history` | `bAuth.aud_policy_history` | bAuth | Historial versionado de políticas. |
| 56 | `bauth.bos_backup_log` | `bAuth.aud_backup` | bAuth | Registro de backups (ADR-016). |
| 57 | `bauth.bos_login_attempt` | `bAuth.aud_login_attempt` | bAuth | Intentos de login (NIST AC-7). Particionado por mes. |
| 58 | `bauth.bos_superuser_contexts` | `bAuth.aud_superuser` | bAuth | Activaciones break-glass SU (ISO 27001 A.8.2). |

#### Schema: bAuth · Prefijo: sec_ (Seguridad) — 9 tablas

| # | Nombre Actual | Nombre Nuevo | Schema | Motivo |
|---|---------------|-------------|--------|--------|
| 59 | `bauth.bos_key_inventory` | `bAuth.sec_key` | bAuth | Inventario de llaves criptográficas (NIST SP 800-57). |
| 60 | `bauth.bos_key_recovery_log` | `bAuth.sec_key_recovery` | bAuth | Recuperación de llaves (break-glass). |
| 61 | `bauth.bos_key_rotation_log` | `bAuth.sec_key_rotation` | bAuth | Rotación de llaves criptográficas. |
| 62 | `bauth.bos_device_registry` | `bAuth.sec_device` | bAuth | Registro de dispositivos físicos (ISO 27001 A.8.1). |
| 63 | `bauth.bos_dispositivo_fisico` | `bAuth.sec_hardware_device` | bAuth | Hardware específico: OSDP, MQTT, ONVIF, Wiegand. |
| 64 | `bauth.bos_sitio_fisico` | `bAuth.sec_site` | bAuth | Sitio físico geolocalizado. |
| 65 | `bauth.bos_edificio` | `bAuth.sec_building` | bAuth | Edificio dentro del sitio. |
| 66 | `bauth.bos_piso` | `bAuth.sec_floor` | bAuth | Piso dentro del edificio. |
| 67 | `bauth.bos_area_fisica` | `bAuth.sec_area` | bAuth | Área funcional dentro del piso. |

#### Schema: bAuth · Prefijo: geo_ (Geografía) — 3 tablas

| # | Nombre Actual | Nombre Nuevo | Schema | Motivo |
|---|---------------|-------------|--------|--------|
| 68 | `bauth.bos_pais` | `bglobal.global_country` | bglobal | ✅ CONSTRUIDO. 36 columnas (UUIDv7 PK + ISO 3166-1 + UN M.49 + ITU-T E.164 + IANA TZ + CLDR + Wikidata). names_native JSONB. Seed: 196 países idempotente. |
| 69 | `bauth.bos_ciudad` | `bauth.geo_ciudad` | bauth | Ciudades y divisiones administrativas. Pendiente. |
| 70 | `bauth.bos_timezone` | `bauth.geo_timezone` | bauth | ✅ CONSTRUIDO. Zonas horarias IANA TZ. TEXT natural key (timezone_id), 8 columnas. Pendiente seed. |

#### Schema: bAuth · Prefijo: cfg_ (Configuración) — 4 tablas

| # | Nombre Actual | Nombre Nuevo | Schema | Motivo |
|---|---------------|-------------|--------|--------|
| 71 | `bauth.bos_compliance_map` | `bAuth.cfg_cumplimiento` | bAuth | Mapeo de cumplimiento normativo (34 estándares). |
| 72 | `bauth.bos_saga_catalog` | `bAuth.cfg_saga` | bAuth | Catálogo de sagas de autenticación (12 sagas). |
| 73 | `bauth.bos_saga_step` | `bAuth.cfg_saga_paso` | bAuth | Pasos individuales de cada saga. |
| 74 | `bauth.bos_saga_execution` | `bAuth.cfg_saga_ejecucion` | bAuth | Registro inmutable de ejecuciones de saga. |

#### Schema: bAuth · Prefijo: blk_ (Blockchain D12) — 7 tablas

| # | Nombre Actual | Nombre Nuevo | Schema | Motivo |
|---|---------------|-------------|--------|--------|
| 75 | `bos_blockchain.blk_merkle_batch` | `bAuth.blk_merkle_batch` | bAuth | Lotes de eventos para anclaje Merkle. |
| 76 | `bos_blockchain.blk_merkle_leaf` | `bAuth.blk_merkle_leaf` | bAuth | Hojas del árbol Merkle (Keccak-256). |
| 77 | `bos_blockchain.blk_blockchain_anchor_log` | `bAuth.blk_anchor_log` | bAuth | Histórico de transacciones de anclaje en L2. |
| 78 | `bos_blockchain.blk_anchor_reconciliation_log` | `bAuth.blk_anchor_reconciliation` | bAuth | Verificación cross-chain Merkle roots. |
| 79 | `bos_blockchain.blk_onchain_account` | `bAuth.blk_account` | bAuth | Cuentas on-chain (Variante B). |
| 80 | `bos_blockchain.blk_onchain_settlement` | `bAuth.blk_settlement` | bAuth | Liquidaciones on-chain (Variante B). |
| 81 | `bos_blockchain.blk_reconciliation_log` | `bAuth.blk_reconciliation` | bAuth | Reconciliación on-chain ↔ PostgreSQL. |

#### Schema: bAuth · Prefijo: privilege_ (Motor de Privilegios) — 11 tablas (9 existentes + 2 nuevas)

| # | Nombre Actual | Nombre Nuevo | Schema | Motivo |
|---|---------------|-------------|--------|--------|
| 82 | `bos_privilege.privilege_application` | `bAuth.privilege_app` | bAuth | Aplicaciones registradas en el motor. |
| 83 | `bos_privilege.privilege_domain` | `bAuth.privilege_domain` | bAuth | Catálogo de 12 dominios de soberanía D1-D12. |
| 84 | `bos_privilege.privilege_verb` | `bAuth.privilege_verb` | bAuth | Vocabulario global de verbos (CRUD). |
| 85 | `bos_privilege.privilege_group` | `bAuth.privilege_group` | bAuth | Grupos funcionales por aplicación. |
| 86 | `bos_privilege.privilege_atom_catalog` | `bAuth.privilege_atom` | bAuth | Catálogo de átomos (1059 registros). |
| 87 | `bos_privilege.privilege_atom_policy` | `bAuth.privilege_policy` | bAuth | Políticas por átomo (6782 registros). |
| 88 | `bos_privilege.privilege_atom_audit` | `bAuth.privilege_audit` | bAuth | Auditoría WORM de evaluaciones. Particionado por mes. |
| 89 | `bos_privilege.privilege_role` | `bAuth.privilege_role` | bAuth | Roles base por tenant. |
| 90 | `bos_privilege.privilege_role_atom` | `bAuth.privilege_role_atom` | bAuth | Asignación rol↔átomo (BitMask relacional). |
| 91 | *(nueva)* | `bAuth.privilege_bitmask_cache` | bAuth | Cache de BitMask evaluado por usuario+tenant (TTL 30s). |
| 92 | *(nueva)* | `bAuth.privilege_conflict_audit` | bAuth | Auditoría WORM de conflictos SoD detectados en runtime. |

#### Schema: bGlobal · Prefijo: global_ (Catálogos Globales) — 6 tablas (4 migradas de bauth + 2 nuevas)

| # | Nombre Actual | Nombre Nuevo | Schema | Motivo |
|---|---------------|-------------|--------|--------|
| 93 | `bauth.bos_idioma` | `bglobal.global_language` | bglobal | ✅ CONSTRUIDO. Catálogo BCP 47. TEXT natural key (locale), 9 columnas. Pendiente seed. |
| 94 | `bauth.bos_moneda` | `bglobal.global_currency` | bglobal | ✅ CONSTRUIDO. Catálogo ISO 4217. CHAR(3) natural key, 11 columnas. Seed: 41 monedas. |
| 95 | `bauth.bos_tenant_language` | `bGlobal.global_tenant_language` | bGlobal | Idiomas habilitados por tenant. Referencia global no exclusiva de bAuth. |
| 96 | `bauth.bos_tenant_currency` | `bauth.idn_tenant_currencies` | bauth | ✅ REPARADO. Monedas habilitadas por tenant + tasas. FK a idn_tenant y global_currency. |
| 97 | *(nueva)* | `bGlobal.global_parametro` | bGlobal | Parámetros con herencia jerárquica tenant→empresa→sucursal. Función `resolve_param()`. |
| 98 | *(nueva)* | `bGlobal.global_message_template` | bGlobal | Plantillas de mensajes multi-idioma (ex `calendar_template`). Usada por bCalendar y bnotify. |

#### Schema: bCalendar · Prefijo: cal_ (Calendario) — 13 tablas (3 migradas de bauth + 10 nuevas)

| # | Nombre Actual | Nombre Nuevo | Schema | Motivo |
|---|---------------|-------------|--------|--------|
| 99 | `bauth.bos_tenant_gestion` | `bCalendar.cal_interval` | bCalendar | **Fusión** de `bos_tenant_gestion` + `bos_gestion_calendario` → un solo modelo jerárquico de períodos fiscales. |
| 100 | `bauth.bos_gestion_calendario` | `bCalendar.cal_interval` | bCalendar | **Fusión** — ver fila 99. Datos de empresa se consolidan en cal_interval con empresa_id. |
| 101 | `bauth.bos_schedule` | `bCalendar.cal_schedule` | bCalendar | Horarios de trabajo y turnos. Fuera de bAuth — es configuración operativa transversal (RFC 7953 VAVAILABILITY). |
| 102 | *(nueva)* | `bCalendar.cal_calendar` | bCalendar | Colección de calendarios por tenant: work, fiscal, process, compliance (RFC 4791 VCALENDAR). |
| 103 | *(nueva)* | `bCalendar.cal_event` | bCalendar | VEVENT master. Almacena `rrule TEXT` sin expandir. Toda la serie en un registro (RFC 5545). |
| 104 | *(nueva)* | `bCalendar.cal_instance` | bCalendar | Ocurrencias materializadas ±90 días (Google Hybrid Window). Más allá: expansión dinámica. |
| 105 | *(nueva)* | `bCalendar.cal_exception` | bCalendar | Cancelaciones y modificaciones de instancias individuales (RFC 5545 RECURRENCE-ID + EXDATE). |
| 106 | *(nueva)* | `bCalendar.cal_attendee` | bCalendar | Participantes con RSVP: ACCEPTED/DECLINED/TENTATIVE/NEEDS-ACTION (RFC 5545 ATTENDEE). |
| 107 | *(nueva)* | `bCalendar.cal_holiday` | bCalendar | Feriados fijos (Navidad) y móviles (Pascua por fórmula de Gauss) por país/región/tenant. |
| 108 | *(nueva)* | `bCalendar.cal_alarm` | bCalendar | VALARM: canal (EMAIL/SMS/WhatsApp/UI) y lead time antes del evento (RFC 5545 VALARM). |
| 109 | *(nueva)* | `bCalendar.cal_notification_log` | bCalendar | Registro WORM de cada notificación enviada. Solo INSERT. ctx_id obligatorio (ISO 27001 A.8.15). |
| 110 | *(nueva)* | `bCalendar.cal_user_prefs` | bCalendar | Preferencias de canal de notificación y horario por usuario/tenant. |
| 111 | *(nueva)* | `bCalendar.cal_audit_log` | bCalendar | Log bi-temporal: `valid_from/valid_to` (tiempo real) + `recorded_at` (tiempo DB) — ISO SQL:2011. |

### A.2 Resumen de schemas destino

| Schema | Tablas existentes migradas | Tablas nuevas | Total | Acción DDL |
|--------|---------------------------|---------------|-------|------------|
| **bAuth** | 90 (de bauth + bos_blockchain + bos_privilege) | 2 | 92 | `CREATE SCHEMA bAuth` + CREATE TABLE con nuevo nombre |
| **bGlobal** | 4 (de bauth) | 2 | 6 | `CREATE SCHEMA bGlobal` + CREATE TABLE con nuevo nombre |
| **bCalendar** | 3 (de bauth, 2 fusionan en cal_interval) | 10 | 13 | `CREATE SCHEMA bCalendar` + CREATE TABLE |
| **TOTAL** | **97** | **14** | **111** | |

**Tablas sin cambio de nombre** (solo cambian de schema `bauth` → `bAuth`): todas las de prefijos ath_, ses_, fin_, aud_, sec_, geo_, cfg_.

**Tablas con fusión** (2 tablas existentes → 1 tabla nueva):
- `bauth.bos_tenant_gestion` + `bauth.bos_gestion_calendario` → `bCalendar.cal_interval`

**Tablas que desaparecen** (schemas eliminados, datos migran):
- Todo `bos_blockchain.*` → `bAuth.blk_*`
- Todo `bos_privilege.*` → `bAuth.privilege_*`


## ANEXO B — Tablas SQL del Calendario (bCalendar)

> **Nota sobre notificaciones:** `sbos-notifier` (bnotify) es una ficha del BOS en S06 con su propia
> base de datos `notifier_db`. Los logs de envío, preferencias de canal y plantillas de mensajes
> pertenecen a bnotify. bCalendar solo define el disparador (`cal_alarm`) y llama
> `bnotify.event.schedule` vía JSON-RPC :28200. No inventamos la rueda.

### B.1 Lista de tablas

**Schema:** `bCalendar` (dentro de `skSBOS_db`) — 13 tablas, prefijo `cal_`

| # | Tabla | Origen | Estándar / Caso de uso SBOS | Propósito |
|---|-------|--------|-----------------------------|-----------|
| **— Colección —** |||||
| 1 | `cal_calendar` | nueva | RFC 4791 VCALENDAR | Colección de calendarios por tenant: work, fiscal, process, compliance |
| **— Eventos RFC 5545 —** |||||
| 2 | `cal_event` | ex `calendar_event` | RFC 5545 VEVENT + RRULE | Evento master. Toda la serie en un registro. No se expande aquí. |
| 3 | `cal_instance` | ex `calendar_instance` | Google Hybrid Window | Ocurrencias materializadas ±90 días. Más allá: expansión dinámica. |
| 4 | `cal_exception` | ex `calendar_exception` | RFC 5545 RECURRENCE-ID | Cancelaciones y modificaciones de instancias individuales. |
| 5 | `cal_attendee` | ex `calendar_attendee` | RFC 5545 ATTENDEE | Participantes con RSVP. Roles: CHAIR, REQ-PARTICIPANT, OPT-PARTICIPANT. |
| **— Control temporal D4 (bAuth) —** |||||
| 6 | `cal_interval` | fusión `bos_tenant_gestion` + `bos_gestion_calendario` | NetSuite+Odoo+Oracle ORMB | Períodos fiscales jerárquicos. OPEN→SOFT_CLOSED→HARD_CLOSED→ARCHIVED. |
| 7 | `cal_schedule` | ex `bauth.bos_schedule` | RFC 7953 VAVAILABILITY · D4 POL-D4-SHIFT | Turnos laborales. Días permitidos, hora inicio/fin. bAuth D4 consulta esto. |
| 8 | `cal_holiday` | nueva | ISO 8601 + ISO 3166 · D4 POL-D4-HOLIDAY | Feriados fijos y móviles. bAuth niega acceso en feriados salvo roles emergencia. |
| **— Compliance y vencimientos (Producto A) —** |||||
| 9 | `cal_compliance_deadline` | nueva | ASFI/UIF · D9 rotación credenciales · D10 delegaciones | Vencimientos regulatorios, de credenciales y de accesos temporales. Auto-dispara bnotify. |
| 10 | `cal_review_campaign` | ex `bauth.bos_access_reviews` | ISO 27001 A.9.2.5 · SOC 2 CC6.2 | Campañas de recertificación de accesos. Cada 90 días por rol/empresa. |
| **— Delegaciones temporales D10 —** |||||
| 11 | `cal_delegation_window` | nueva | D10 POL-D10-NOTIFICATION | Ventana de vigencia de delegación. Vinculada a `bAuth.idn_delegation`. Auto-revocación. |
| **— Disparador de notificaciones → bnotify —** |||||
| 12 | `cal_alarm` | ex `calendar_reminder` | RFC 5545 VALARM | Define CUÁNDO disparar. Llama `bnotify.event.schedule` vía JSON-RPC. No almacena logs. |
| **— Auditoría —** |||||
| 13 | `cal_audit_log` | nueva | ISO SQL:2011 bi-temporal | Log bi-temporal: `valid_from/valid_to` (mundo real) + `recorded_at` (DB). |

**Tablas que NO van en bCalendar (pertenecen a `notifier_db` de bnotify):**
- ~~`cal_notification_log`~~ → `notifier_db.delivery_log`
- ~~`cal_user_prefs`~~ → `notifier_db.user_preferences`
- ~~`global_message_template`~~ → `notifier_db.templates` (bGlobal.global_message_template queda solo como referencia de formato)

### B.2 SQL Completo

```sql
-- ============================================================
-- bCalendar — 13 Tablas
-- Schema: bCalendar (dentro de skSBOS_db)
-- Prefijo: cal_
-- Estándares: RFC 5545 (iCalendar), RFC 4791 (CalDAV),
--             RFC 7953 (VAVAILABILITY), ISO SQL:2011 bi-temporal
--             ISO 27001 A.9.2.5, ASFI/UIF Bolivia
--             D4/D9/D10 bAuth Temporal Domain Engine
--
-- Herramientas open-source (licencia MIT/PGXN) — NO reinventamos:
--   • FullCalendar      — UI visual (React, Resource Timeline, RRULE plugin)
--   • PostgREST         — API REST auto-generada desde el schema bCalendar
--   • rrule_plpgsql     — Motor de recurrencia RFC 5545 en PostgreSQL
--   • pgcalendar        — Triggers anti-solapamiento, generación de ocurrencias
--
-- Notificaciones: delegadas a bnotify (notifier_db :28200)
--   bCalendar llama bnotify.event.schedule vía JSON-RPC.
--   Los logs de entrega y preferencias de canal viven en notifier_db.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bCalendar;

-- -------------------------------------------------------
-- 1. CAL_CALENDAR — Colección de calendarios (RFC 4791 VCALENDAR)
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS bCalendar.cal_calendar (
    calendar_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id         UUID NOT NULL,
    empresa_id        UUID,
    name              TEXT NOT NULL,
    type              TEXT NOT NULL,
    description       TEXT,
    color             VARCHAR(7),
    timezone          VARCHAR(64) NOT NULL DEFAULT 'America/La_Paz',
    is_default        BOOLEAN DEFAULT FALSE,
    visibility        TEXT DEFAULT 'PRIVATE',
    ctx_id            TEXT NOT NULL,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (tenant_id, empresa_id, name),
    CONSTRAINT chk_cal_cal_type CHECK (type IN ('WORK','FISCAL','PROCESS','PERSONAL','COMPLIANCE')),
    CONSTRAINT chk_cal_cal_vis  CHECK (visibility IN ('PRIVATE','TENANT','PUBLIC'))
);
CREATE INDEX IF NOT EXISTS idx_cal_calendar_tenant ON bCalendar.cal_calendar(tenant_id, empresa_id);

-- -------------------------------------------------------
-- 2. CAL_EVENT — Evento master con RRULE (RFC 5545 VEVENT)
--    Toda la serie en un registro. NO se expande aquí.
--    "this and following" se modela con parent_event_id.
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS bCalendar.cal_event (
    event_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    calendar_id       UUID NOT NULL,
    tenant_id         UUID NOT NULL,
    empresa_id        UUID,
    sucursal_id       UUID,
    owner_id          UUID NOT NULL,
    uid               TEXT NOT NULL UNIQUE,
    title             VARCHAR(512) NOT NULL,
    description       TEXT,
    location          VARCHAR(512),
    start_time        TIMESTAMPTZ NOT NULL,
    end_time          TIMESTAMPTZ NOT NULL,
    all_day           BOOLEAN DEFAULT FALSE,
    timezone          VARCHAR(64) DEFAULT 'America/La_Paz',
    rrule             TEXT,
    exdates           TEXT[],
    status            TEXT DEFAULT 'CONFIRMED',
    event_type        TEXT NOT NULL,
    process_name      TEXT,
    process_params    JSONB,
    parent_event_id   UUID,
    sequence          INTEGER DEFAULT 0,
    ctx_id            TEXT NOT NULL,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_cal_ev_status CHECK (status IN ('CONFIRMED','TENTATIVE','CANCELLED')),
    CONSTRAINT chk_cal_ev_type   CHECK (event_type IN ('MEETING','PROCESS','REMINDER','FISCAL','COMPLIANCE','HOLIDAY'))
);
CREATE INDEX IF NOT EXISTS idx_cal_event_cal    ON bCalendar.cal_event(calendar_id, start_time);
CREATE INDEX IF NOT EXISTS idx_cal_event_owner  ON bCalendar.cal_event(owner_id, tenant_id);
CREATE INDEX IF NOT EXISTS idx_cal_event_rrule  ON bCalendar.cal_event(tenant_id) WHERE rrule IS NOT NULL;

-- -------------------------------------------------------
-- 3. CAL_INSTANCE — Ocurrencias materializadas
--    Google Hybrid Window: ±90 días pre-expandidos.
--    Consultas más allá del window: expansión dinámica.
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS bCalendar.cal_instance (
    instance_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id          UUID NOT NULL,
    tenant_id         UUID NOT NULL,
    original_date     DATE NOT NULL,
    start_time        TIMESTAMPTZ NOT NULL,
    end_time          TIMESTAMPTZ NOT NULL,
    is_exception      BOOLEAN DEFAULT FALSE,
    status            TEXT DEFAULT 'CONFIRMED',
    ctx_id            TEXT,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (event_id, original_date),
    CONSTRAINT chk_cal_inst_status CHECK (status IN ('CONFIRMED','TENTATIVE','CANCELLED'))
);
CREATE INDEX IF NOT EXISTS idx_cal_inst_time  ON bCalendar.cal_instance(tenant_id, start_time, end_time);
CREATE INDEX IF NOT EXISTS idx_cal_inst_event ON bCalendar.cal_instance(event_id, original_date);

-- -------------------------------------------------------
-- 4. CAL_EXCEPTION — Cancelaciones y modificaciones
--    RFC 5545 RECURRENCE-ID + EXDATE
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS bCalendar.cal_exception (
    exception_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id          UUID,
    interval_id       UUID,
    original_date     DATE NOT NULL,
    exception_type    TEXT NOT NULL,
    modified_start    TIMESTAMPTZ,
    modified_end      TIMESTAMPTZ,
    reason            TEXT,
    ctx_id            TEXT NOT NULL,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (event_id, interval_id, original_date),
    CONSTRAINT chk_cal_exc_target CHECK (
        (event_id IS NOT NULL AND interval_id IS NULL) OR
        (event_id IS NULL AND interval_id IS NOT NULL)
    ),
    CONSTRAINT chk_cal_exc_type CHECK (exception_type IN ('CANCELLED','MODIFIED'))
);

-- -------------------------------------------------------
-- 5. CAL_ATTENDEE — Participantes (RFC 5545 ATTENDEE)
--    PARTSTAT y ROLE según especificación RFC 5545 §3.2.12
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS bCalendar.cal_attendee (
    attendee_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id          UUID NOT NULL,
    user_id           UUID NOT NULL,
    rsvp_status       TEXT DEFAULT 'NEEDS-ACTION',
    role              TEXT DEFAULT 'REQ-PARTICIPANT',
    is_organizer      BOOLEAN DEFAULT FALSE,
    notified_at       TIMESTAMPTZ,
    ctx_id            TEXT,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (event_id, user_id),
    CONSTRAINT chk_cal_att_rsvp CHECK (rsvp_status IN ('NEEDS-ACTION','ACCEPTED','DECLINED','TENTATIVE','DELEGATED')),
    CONSTRAINT chk_cal_att_role CHECK (role IN ('CHAIR','REQ-PARTICIPANT','OPT-PARTICIPANT','NON-PARTICIPANT'))
);

-- -------------------------------------------------------
-- 6. CAL_INTERVAL — Períodos fiscales jerárquicos
--    Fusión de bos_tenant_gestion + bos_gestion_calendario
--    Patrón: NetSuite OneWorld + Odoo 18 + Oracle ORMB
--    Herencia: sucursal hereda empresa, empresa hereda tenant
--    Sucursal puede ser MÁS restrictiva, nunca MÁS permisiva
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS bCalendar.cal_interval (
    interval_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL,
    empresa_id          UUID,
    sucursal_id         UUID,
    interval_type       TEXT NOT NULL,
    name                TEXT NOT NULL,
    start_date          DATE NOT NULL,
    end_date            DATE NOT NULL,
    parent_interval_id  UUID,
    status              TEXT DEFAULT 'OPEN',
    postable_from       DATE,
    postable_until      DATE,
    closed_by           UUID,
    closed_at           TIMESTAMPTZ,
    ctx_id              TEXT NOT NULL,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (tenant_id, empresa_id, sucursal_id, name),
    CONSTRAINT chk_cal_int_status CHECK (status IN ('OPEN','SOFT_CLOSED','HARD_CLOSED','ARCHIVED')),
    CONSTRAINT chk_cal_int_type   CHECK (interval_type IN ('FISCAL_YEAR','SEMESTER','QUARTER','MONTH','FORTNIGHT','WEEK','DAY','CUSTOM')),
    CONSTRAINT chk_cal_int_dates  CHECK (end_date > start_date)
);
CREATE INDEX IF NOT EXISTS idx_cal_int_tenant ON bCalendar.cal_interval(tenant_id, empresa_id, start_date);
CREATE INDEX IF NOT EXISTS idx_cal_int_parent ON bCalendar.cal_interval(parent_interval_id);

-- -------------------------------------------------------
-- 7. CAL_SCHEDULE — Horarios de trabajo
--    RFC 7953 VAVAILABILITY
--    work_days: array ISO 8601 (1=lun, 7=dom)
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS bCalendar.cal_schedule (
    schedule_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id         UUID NOT NULL,
    empresa_id        UUID,
    sucursal_id       UUID,
    name              TEXT NOT NULL,
    timezone          VARCHAR(64) NOT NULL DEFAULT 'America/La_Paz',
    work_days         SMALLINT[] NOT NULL DEFAULT '{1,2,3,4,5}',
    work_start        TIME NOT NULL DEFAULT '08:00',
    work_end          TIME NOT NULL DEFAULT '17:00',
    break_start       TIME,
    break_end         TIME,
    is_default        BOOLEAN DEFAULT FALSE,
    ctx_id            TEXT NOT NULL,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (tenant_id, empresa_id, sucursal_id, name)
);

-- -------------------------------------------------------
-- 8. CAL_HOLIDAY — Feriados fijos y móviles
--    holiday_type FIXED: month+day obligatorios
--    holiday_type MOVABLE: formula (ej: 'easter+1', 'easter-47')
--    tenant_id NULL = aplica a todos los tenants del país
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS bCalendar.cal_holiday (
    holiday_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id         UUID,
    country_code      CHAR(2),
    region_code       TEXT,
    name              TEXT NOT NULL,
    holiday_type      TEXT NOT NULL,
    month             SMALLINT,
    day               SMALLINT,
    formula           TEXT,
    applies_to_year   INTEGER,
    is_non_working    BOOLEAN DEFAULT TRUE,
    ctx_id            TEXT NOT NULL,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_cal_hol_type  CHECK (holiday_type IN ('FIXED','MOVABLE','TENANT_SPECIFIC')),
    CONSTRAINT chk_cal_hol_fixed CHECK (
        holiday_type != 'FIXED' OR (month IS NOT NULL AND day IS NOT NULL)
    ),
    CONSTRAINT chk_cal_hol_month CHECK (month IS NULL OR month BETWEEN 1 AND 12),
    CONSTRAINT chk_cal_hol_day   CHECK (day IS NULL OR day BETWEEN 1 AND 31)
);
CREATE INDEX IF NOT EXISTS idx_cal_hol_country ON bCalendar.cal_holiday(country_code, month, day);
CREATE INDEX IF NOT EXISTS idx_cal_hol_tenant  ON bCalendar.cal_holiday(tenant_id) WHERE tenant_id IS NOT NULL;

-- -------------------------------------------------------
-- 9. CAL_COMPLIANCE_DEADLINE — Vencimientos regulatorios
--    ASFI/UIF Bolivia, D9 rotación de credenciales,
--    D10 expiración de delegaciones temporales
--    Auto-dispara bnotify.event.schedule vía JSON-RPC :28200
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS bCalendar.cal_compliance_deadline (
    deadline_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id             UUID NOT NULL,
    empresa_id            UUID,
    deadline_type         TEXT NOT NULL,
    reference_id          UUID,
    name                  TEXT NOT NULL,
    description           TEXT,
    due_date              DATE NOT NULL,
    due_time              TIME,
    severity              TEXT NOT NULL DEFAULT 'MEDIUM',
    status                TEXT NOT NULL DEFAULT 'PENDING',
    responsible_id        UUID,
    bnotify_schedule_id   TEXT,
    waived_by             UUID,
    waived_at             TIMESTAMPTZ,
    waived_reason         TEXT,
    completed_at          TIMESTAMPTZ,
    ctx_id                TEXT NOT NULL,
    created_at            TIMESTAMPTZ DEFAULT NOW(),
    updated_at            TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_cal_cdl_type   CHECK (deadline_type IN ('REGULATORY','CREDENTIAL_ROTATION','DELEGATION_EXPIRY','AUDIT_REVIEW','CERTIFICATION')),
    CONSTRAINT chk_cal_cdl_sev    CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    CONSTRAINT chk_cal_cdl_status CHECK (status IN ('PENDING','IN_PROGRESS','COMPLETED','OVERDUE','WAIVED'))
);
CREATE INDEX IF NOT EXISTS idx_cal_cdl_tenant ON bCalendar.cal_compliance_deadline(tenant_id, due_date);
CREATE INDEX IF NOT EXISTS idx_cal_cdl_status ON bCalendar.cal_compliance_deadline(status, due_date) WHERE status IN ('PENDING','IN_PROGRESS');

-- -------------------------------------------------------
-- 10. CAL_REVIEW_CAMPAIGN — Campañas de recertificación
--     ISO 27001 A.9.2.5: revisar accesos cada 90 días
--     SOC 2 CC6.2: revisión periódica de privilegios
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS bCalendar.cal_review_campaign (
    campaign_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id             UUID NOT NULL,
    empresa_id            UUID,
    name                  TEXT NOT NULL,
    scope_type            TEXT NOT NULL,
    scope_id              UUID,
    review_period_days    INTEGER NOT NULL DEFAULT 90,
    start_date            DATE NOT NULL,
    end_date              DATE NOT NULL,
    status                TEXT NOT NULL DEFAULT 'SCHEDULED',
    owner_id              UUID NOT NULL,
    reviewer_ids          UUID[],
    completed_reviews     INTEGER DEFAULT 0,
    total_reviews         INTEGER,
    bnotify_schedule_id   TEXT,
    completed_at          TIMESTAMPTZ,
    ctx_id                TEXT NOT NULL,
    created_at            TIMESTAMPTZ DEFAULT NOW(),
    updated_at            TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_cal_rev_scope  CHECK (scope_type IN ('ROLE','USER','DEPARTMENT','TENANT_ALL')),
    CONSTRAINT chk_cal_rev_status CHECK (status IN ('SCHEDULED','ACTIVE','COMPLETED','EXPIRED')),
    CONSTRAINT chk_cal_rev_dates  CHECK (end_date > start_date),
    CONSTRAINT chk_cal_rev_period CHECK (review_period_days BETWEEN 1 AND 365)
);
CREATE INDEX IF NOT EXISTS idx_cal_rev_tenant ON bCalendar.cal_review_campaign(tenant_id, start_date);
CREATE INDEX IF NOT EXISTS idx_cal_rev_active ON bCalendar.cal_review_campaign(status, end_date) WHERE status IN ('SCHEDULED','ACTIVE');

-- -------------------------------------------------------
-- 11. CAL_DELEGATION_WINDOW — Ventana de delegación temporal
--     D10 POL-D10-NOTIFICATION: auto-revocación al vencer
--     FK lógica a bAuth.idn_delegation (delegation_id)
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS bCalendar.cal_delegation_window (
    window_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delegation_id         UUID NOT NULL UNIQUE,
    tenant_id             UUID NOT NULL,
    delegator_id          UUID NOT NULL,
    delegatee_id          UUID NOT NULL,
    role_id               UUID,
    valid_from            TIMESTAMPTZ NOT NULL,
    valid_until           TIMESTAMPTZ NOT NULL,
    auto_revoke           BOOLEAN DEFAULT TRUE,
    revoked_at            TIMESTAMPTZ,
    revoked_by            UUID,
    revoke_reason         TEXT,
    bnotify_schedule_id   TEXT,
    ctx_id                TEXT NOT NULL,
    created_at            TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_cal_dw_dates CHECK (valid_until > valid_from)
);
CREATE INDEX IF NOT EXISTS idx_cal_dw_delegation ON bCalendar.cal_delegation_window(delegation_id);
CREATE INDEX IF NOT EXISTS idx_cal_dw_active     ON bCalendar.cal_delegation_window(valid_until, auto_revoke) WHERE revoked_at IS NULL;

-- -------------------------------------------------------
-- 12. CAL_ALARM — Alarmas VALARM (RFC 5545)
--    trigger_type: cuándo disparar respecto al evento
--    template_id: FK a bGlobal.global_message_template
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS bCalendar.cal_alarm (
    alarm_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id          UUID NOT NULL,
    user_id           UUID,
    trigger_type      TEXT NOT NULL,
    trigger_minutes   INTEGER NOT NULL,
    channel           TEXT NOT NULL,
    repeat_count      INTEGER DEFAULT 0,
    repeat_interval   INTEGER DEFAULT 0,
    template_id       UUID,
    is_active         BOOLEAN DEFAULT TRUE,
    ctx_id            TEXT,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_cal_alm_trigger  CHECK (trigger_type IN ('BEFORE_START','AFTER_START','BEFORE_END','AFTER_END')),
    CONSTRAINT chk_cal_alm_channel  CHECK (channel IN ('WHATSAPP','SMS','EMAIL','UI','PUSH'))
);
CREATE INDEX IF NOT EXISTS idx_cal_alarm_event ON bCalendar.cal_alarm(event_id);

-- -------------------------------------------------------
-- 13. CAL_AUDIT_LOG — Log bi-temporal (ISO SQL:2011)
--     valid_from/valid_to : cuándo fue verdad en el mundo
--     recorded_at         : cuándo se registró en la BD
--     Ambas dimensiones permiten reconstruir el estado
--     de cualquier entidad en cualquier punto en el tiempo.
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS bCalendar.cal_audit_log (
    audit_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name        TEXT NOT NULL,
    record_id         UUID NOT NULL,
    operation         TEXT NOT NULL,
    actor_id          UUID NOT NULL,
    tenant_id         UUID NOT NULL,
    valid_from        TIMESTAMPTZ NOT NULL,
    valid_to          TIMESTAMPTZ,
    recorded_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    old_values        JSONB,
    new_values        JSONB,
    change_reason     TEXT,
    ctx_id            TEXT NOT NULL,
    CONSTRAINT chk_cal_audit_op CHECK (operation IN ('INSERT','UPDATE','DELETE'))
) PARTITION BY RANGE (recorded_at);

CREATE TABLE IF NOT EXISTS bCalendar.cal_audit_log_2026_07
    PARTITION OF bCalendar.cal_audit_log
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS bCalendar.cal_audit_log_2026_08
    PARTITION OF bCalendar.cal_audit_log
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

CREATE INDEX IF NOT EXISTS idx_cal_audit_record ON bCalendar.cal_audit_log(table_name, record_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_cal_audit_actor  ON bCalendar.cal_audit_log(actor_id, recorded_at DESC);
```

---

*Documento actualizado al 2026-06-22. ANNEXO B — 13 tablas bCalendar completas y alineadas con ANNEXO A.*

*Próximo paso: ejecutar 002_bauth_reconstruccion.sql en VPS + instalar rrule_plpgsql + configurar PostgREST sobre schema bCalendar.*

---

## ANNEXO C — Stack de Colaboración SBOS: Calendario + Notificaciones + Chat

> **Estado:** PROPUESTA — 2026-06-23
> **Decisión:** Usar aplicaciones open-source maduras como fichas BOS, gobernadas por Keycloak/bAuth.
> Sin DDL custom para calendario/notificaciones/chat. Solo construir la lógica de negocio
> fiscal y de compliance que ninguna herramienta genérica cubre (7 tablas custom).

### C.1 Principio

No construir lo que ya existe. El stack de colaboración empresarial está resuelto
por herramientas open-source maduras. El SBOS las despliega como fichas BOS y las
gobierna con Keycloak/bAuth como capa de identidad unificada.

### C.2 Stack Completo — 5 componentes

```
┌─────────────────────────────────────────────────────────────────────┐
│                  Keycloak 26.6.2 + bAuth (S03)                       │
│                  Identidad unificada · OIDC · JWT                     │
│                  BitMask · ctx_id · Reconciliation Loop              │
└──────┬──────────┬──────────┬──────────┬──────────────────────────────┘
       │ OIDC     │ OIDC     │ OIDC     │ SMTP AUTH (SASL vía Dovecot)
       ▼          ▼          ▼          ▼
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────────────────┐
│ Cal.com  │ │  Novu    │ │Mattermost│ │  Dovecot + Postfix +         │
│ S06:9060 │ │S06:28200 │ │ S06:9064 │ │  Roundcube (S06)             │
│          │ │          │ │          │ │                              │
│ AGPLv3   │ │ MIT      │ │ MIT/AGPL │ │  :25 :465 :587 :143 :993    │
│ PostgreS │ │ PostgreS │ │ PostgreS │ │  PostgreSQL                  │
│ OIDC ✅  │ │ OIDC ✅  │ │ OIDC ✅  │ │  OAuth2 vía Dovecot ✅       │
└────┬─────┘ └────┬─────┘ └────┬─────┘ └──────────────────────────────┘
     │            │            │
     │ Webhook    │ Webhook    │ Webhook
     └────────────┼────────────┘
                  │
     Cal.com ──► Novu ──► Email (Postfix) / SMS (Twilio) / WhatsApp / Push / In-App
     Mattermost ──► Novu ──► Push / In-App / Email
```

| # | Componente | Rol | Licencia | PostgreSQL | OIDC/Keycloak | Self-hosted | Costo |
|---|-----------|-----|----------|------------|---------------|-------------|-------|
| 1 | **Cal.com** | Calendario profesional | AGPLv3 | ✅ Nativo | ✅ NextAuth OIDC | ✅ Docker | $0 |
| 2 | **Novu** | Motor de notificaciones | MIT | ✅ (FerretDB→PG) | ✅ JWT/OAuth | ✅ Docker | $0 |
| 3 | **Mattermost** | Chat empresarial | MIT/AGPL | ✅ Nativo | ✅ OIDC | ✅ Docker | $0 |
| 4 | **Dovecot+Postfix+Roundcube** | Correo electrónico | Varias | ✅ (pgsql:) | ✅ OAuth2 | ✅ systemd | $0 |
| 5 | **Keycloak + bAuth** | Identidad y gobernanza | Apache 2.0 | ✅ bauth_db | — | ✅ systemd | $0 |

### C.3 Calendario → Cal.com

**Cal.com** — 30K+ estrellas, alternativa open-source a Calendly.

- **PostgreSQL** nativo vía Prisma ORM. Se conecta al cluster S01.
- **OIDC genérico** vía NextAuth.js. Se configura contra Keycloak: `/.well-known/openid-configuration`.
- **Multi-tenant:** Teams y Organizations. Cada tenant SBOS = una Organization en Cal.com.
- **Notificaciones:** SMTP para email (→ Postfix), webhooks para eventos (→ Novu).
- **UI profesional:** vista mes/semana/día, booking pages, disponibilidad, Google/Outlook sync.
- **Deploy:** Docker compose, un comando. Ficha BOS `calcom` en S06.

```yaml
# Configuración OIDC contra Keycloak (variables de entorno Cal.com)
CALCOM_AUTH_OIDC_ENABLED=true
CALCOM_AUTH_OIDC_ISSUER=https://auth.sbos.local/realms/tenant-{id}
CALCOM_AUTH_OIDC_CLIENT_ID=calcom
CALCOM_AUTH_OIDC_CLIENT_SECRET={{ vault:calcom/oidc-client-secret }}
```

### C.4 Notificaciones → Novu (Self-Hosted)

**Novu** — 37K+ estrellas, motor de notificaciones multi-canal.

- **6 canales:** Email, SMS, WhatsApp, Push, In-App, Chat (Slack/Teams/Telegram/Discord).
- **Self-hosted:** Docker compose. MIT license. Sin costo de plataforma.
- **PostgreSQL** vía FerretDB 2.0 (protocolo MongoDB → almacenamiento PostgreSQL en S01).
- **Workflow engine:** delays, digest, reintentos con backoff exponencial.
- **transactionId** en cada trigger → enganche directo al `ctx_id` del SBOS-049.
- **Únicos costos externos:** WhatsApp Business API (Meta, por mensaje) y SMS (Twilio, opcional).

```
Cal.com webhook ──► Novu workflow ──┬── Email ──► Postfix ──► Dovecot ──► Roundcube
  "reunion_fiscal_30min"            ├── WhatsApp ──► Meta API
                                    ├── SMS ──► Twilio
                                    ├── Push ──► FCM/APNS
                                    └── In-App ──► Novu Notification Center
```

### C.5 Chat → Mattermost

**Mattermost** — chat empresarial open-source, alternativa a Slack.

- **Go** (mismo stack que bAuth y bos). **PostgreSQL** nativo.
- **OIDC** probado con Keycloak. Login unificado para todos los empleados.
- **Apps nativas:** Windows, Mac, Linux, iOS, Android. Sincronización en tiempo real.
- **Webhooks entrantes:** Cal.com puede postear "nueva reunión" a un canal. Novu puede notificar menciones.
- **Canales públicos/privados:** separación de comunicaciones oficiales (auditables) de internas.
- **Compliance:** export de mensajes a JSON/CSV, data retention policies, eDiscovery (edición Enterprise).
- **Deploy:** Docker compose. Ficha BOS `mattermost` en S06.

```yaml
# Configuración OIDC contra Keycloak (config.json Mattermost)
"GitLabSettings": {
    "Enable": false
},
"OpenIdSettings": {
    "Enable": true,
    "ButtonText": "Login con Keycloak",
    "DiscoveryEndpoint": "https://auth.sbos.local/realms/tenant-{id}/.well-known/openid-configuration",
    "ClientId": "mattermost",
    "ClientSecret": "{{ vault:mattermost/oidc-client-secret }}"
}
```

### C.6 Correo → Dovecot + Postfix + Roundcube

El stack de correo ya definido y operativo en el SBOS. Cal.com y Novu lo usan como
transporte SMTP saliente. Roundcube es el webmail para los usuarios. Sin cambios.

### C.7 Gobernanza — bAuth como capa única de identidad

Los 4 componentes (Cal.com, Novu, Mattermost, Dovecot) comparten el mismo usuario
Keycloak. El empleado usa **una sola cuenta** para todo:

```
Empleado ──► Keycloak ──► mismo JWT ──┬── Cal.com (calendario)
                                      ├── Mattermost (chat)
                                      ├── Roundcube (correo)
                                      └── Novu (preferencias de notificación)
```

**bAuth gobierna:**
- **Creación de usuario:** alta en Keycloak → automáticamente accede a los 4 sistemas.
- **Baja/suspensión:** deshabilitar en Keycloak → los 4 sistemas rechazan el acceso.
- **Políticas D4/D5/SoD:** Keycloak las fuerza en el JWT → cada sistema las respeta.
- **Reconciliation loop 60s:** garantiza consistencia entre bauth_db y Keycloak.

### C.8 Lo que NO se construye

| Componente | Herramienta | Lo que ahorra |
|-----------|-----------|--------------|
| UI de calendario | Cal.com | ~200h frontend |
| Motor de booking/recurrencia | Cal.com | ~100h backend |
| Motor de notificaciones multi-canal | Novu | ~150h |
| UI de chat + apps nativas | Mattermost | ~300h |
| API REST de calendario/chat/notif | PostgREST + APIs nativas | ~80h |
| **Total ahorrado** | | **~830h** |

### C.9 Lo que SÍ se construye (7 tablas custom en bAuth)

Solo la lógica fiscal y de compliance que ninguna herramienta genérica cubre:

| # | Tabla | Propósito |
|---|-------|-----------|
| 1 | `bCalendar.cal_interval` | Períodos fiscales jerárquicos OPEN→SOFT_CLOSED→HARD_CLOSED |
| 2 | `bCalendar.cal_schedule` | Turnos laborales para bAuth D4 |
| 3 | `bCalendar.cal_holiday` | Feriados (poblada por seed, D4 la consulta) |
| 4 | `bCalendar.cal_compliance_deadline` | Vencimientos ASFI/UIF + D9 rotación |
| 5 | `bCalendar.cal_review_campaign` | ISO 27001 recertificación cada 90 días |
| 6 | `bCalendar.cal_delegation_window` | D10 auto-revocación de delegaciones |
| 7 | `bCalendar.cal_audit_log` | Auditoría bi-temporal ISO SQL:2011 |

### C.10 Fichas BOS a crear

| Ficha | Servidor | Puertos | Componente |
|-------|---------|---------|------------|
| `calcom` | S06 | :9060 | Cal.com — calendario profesional |
| `novu` | S06 | :28200-:28205 | Novu — motor de notificaciones (reemplaza stub Python) |
| `mattermost` | S06 | :9064-:9065 | Mattermost — chat empresarial |
| `ferretdb` | S06 | :27017 (interno) | FerretDB 2.0 — backend PostgreSQL para Novu |
| `nager-date` | S06 | :9063 | Nager.Date — API de feriados LATAM (sidecar) |

### C.11 Secretos en Vault

| Secreto | Consumidor | Ruta |
|---------|-----------|------|
| `calcom/oidc-client-secret` | Cal.com | `secret/bauth/collab/calcom` |
| `novu/jwt-secret` | Novu | `secret/bauth/collab/novu` |
| `mattermost/oidc-client-secret` | Mattermost | `secret/bauth/collab/mattermost` |
| `bauth/reader-password` | Postfix, Cal.com, Mattermost | `secret/bauth/db/reader` |

### C.12 Clientes Keycloak a crear

| Client ID | Para | Protocolo | Flow |
|-----------|-----|-----------|------|
| `calcom` | Cal.com | OIDC | Authorization Code + PKCE |
| `novu` | Novu | OIDC | Authorization Code |
| `mattermost` | Mattermost | OIDC | Authorization Code |
| `dovecot` | Dovecot (ya existe) | OAuth2 | Bearer token validation |

---

*Propuesta generada 2026-06-23. Pendiente de aprobación del humano para ejecución.*
*Stack verificado: todos los componentes son open-source, self-hosted, con PostgreSQL nativo y compatibles con OIDC/Keycloak.*
