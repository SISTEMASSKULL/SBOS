# BAUTH-SEED-PLAN.md — Plan de Seeds del Ecosistema bAuth

**Versión:** 1.0 · **Fecha:** 2026-06-24 · **Autor:** sbos-coordinador
**Propósito:** Catálogo centralizado de todos los seeds requeridos por las tablas del D1 y
sus dominios asociados. Cada entrada indica: tabla, origen de datos, si ya existe información
aprovechable, y prioridad.

---

## 1. SEEDS YA CREADOS (DDL nueva)

| # | Seed | Tabla | Registros | Origen de datos | Estado |
|---|------|-------|-----------|-----------------|--------|
| S01 | `seed_global_language.sql` | bglobal.global_language | 125 idiomas | IANA Subtag Registry + Ethnologue + CLDR 46 | ✅ VPS verificado |
| S02 | `seed_global_currency.sql` | bglobal.global_currency | 45 monedas | ISO 4217 (SIX Interbank) + bancos centrales | ✅ VPS verificado |
| S03 | `seed_global_country.sql` | bglobal.global_country | 196 países | ISO 3166-1 + UN M.49 + REST Countries API | ✅ VPS verificado (combinado con monedas) |
| S04 | `seed_geo_timezone.sql` | bglobal.geo_timezone | 319 zonas IANA | IANA TZ Database (zone.tab + iso3166.tab) | ✅ VPS verificado |

---

## 2. SEEDS PLANIFICADOS — MOTOR DE PRIVILEGIOS (privilege_)

| # | Tabla | Registros estimados | Origen de datos | Información disponible | Prioridad |
|---|-------|--------------------|----------------|----------------------|-----------|
| P01 | `privilege_domain` | 12 | `bauth/src/bitmask/catalog.rs` — SEED_DOMAINS: (1,Lógico) a (12,Blockchain) | ✅ Ya en código Rust — extraer a SQL | **ALTA** |
| P02 | `privilege_verb` | ~50 | **Investigación §2.1 del Manual D1:** SAP ACTVT (31) + Odoo (4) + Dynamics (8) + ServiceNow (5) + NetSuite (4) + Tryton actions | ✅ Catálogo consolidado documentado — falta extraer a SQL | **ALTA** |
| P03 | `privilege_atom` | ~1059 | **COMBINATORIA:** apps × grupos × dominios × verbos. Cada átomo = la unidad mínima de permiso en el motor BitMask. Ej: [app=Tryton, group=account, domain=D3_Financiero, verb=create] → "Crear factura en Tryton". Se construye desde el cruce de P05 (apps) × P06 (grupos) × P01 (dominios) × P02 (verbos). Solo combinaciones VÁLIDAS (no toda app tiene todo dominio ni todo grupo tiene todo verbo). | ❌ Construir desde cero. Máximo teórico: 12 apps × 40 grupos × 12 dominios × 4 verbos = 23,040. Válidos reales: ~1059. Fuente: combinación manual validada contra catálogo de roles y sentido común de negocio. | **CRÍTICA** |
| P04 | `privilege_atom_policy` | ~6782 | **RELACIÓN LÓGICA:** cada átomo tiene 1+N políticas que definen CÓMO se evalúa. La política es el contrato que el motor BitMask ejecuta. Ej: átomo "Crear factura" → políticas: {requires_dual_approval:true, max_amount:50000, SoD_check:"creador≠aprobador", requires_evidence:true, notifies_sin:true}. Se construye desde Policies_Authentication_Framework.json + Authentication_Framework.json + reglas de negocio por dominio (D1-D12). | ❌ Construir desde cero. ~6782 políticas = cada átomo puede tener múltiples políticas. Las políticas definen condiciones, restricciones, scope, step-up requirements, y SoD rules. | **CRÍTICA** |

### 9.0 — Estructura de un átomo y sus políticas (ejemplo)

```
privilege_atom (P03):
  atom_code: 1059
  app_code: 1 (Tryton)
  group_code: 1 (account)
  domain_code: 3 (D3 Financiero)
  verb_code: 1 (create)
  atom_name: "Crear factura en Tryton"
  atom_slug: "tryton.account.factura.create"
  atom_position: 3  (posición en el BitMask para Fast-Path)

privilege_atom_policy (P04) — 1+N políticas para el átomo 1059:
  Política 1: { "type":"SoD", "rule":"creator_neq_approver", "domain":"D3" }
  Política 2: { "type":"FinancialLimit", "max_amount":50000, "period":"daily", "currency":"BOB" }
  Política 3: { "type":"DualApproval", "required":true, "min_approvers":2, "amount_threshold":10000 }
  Política 4: { "type":"Evidence", "required":true, "doc_types":["FACTURA","CONTRATO"] }
  Política 5: { "type":"SINNotification", "required":true, "sin_wsdl":"produccion" }
  Política 6: { "type":"Audit", "level":"full", "retention_days":2555, "hash_chain":true }
```
| P05 | `privilege_application` | 12 | **Inventario real de 31 fichas BosAgent `servers/`. 12 son aplicaciones que requieren gobernanza de permisos:** Tryton, Keycloak, Kong, Vault, Cal.com, Mattermost, Novu, Grafana, Prometheus, Besu-QBFT, MinIO, PostgreSQL. **Las 19 restantes son infraestructura (sin permisos de usuario).** | ✅ Inventariadas desde `BosAgent/src/servers/*/manifest.yml` (31 fichas, 12 apps). Proceso de gobierno documentado en §7.5 | **ALTA** |

### 7.5 — Gobierno de Aplicaciones: Registro y Desinstalación

**Proceso vinculado al ciclo de vida de fichas BOS:**

```
bosctl ficha install {app}
  │
  ├── 1. BOS ejecuta task_catalog.sh
  ├── 2. Al finalizar install → INSERT INTO privilege_application
  │      (app_code, app_name, app_slug, tenant_id, active=true, registered_at=NOW())
  └── 3. La aplicación queda GOBERNADA por bAuth

bosctl ficha uninstall {app}
  │
  ├── 1. BOS verifica dependencias (otras fichas que dependen de esta)
  ├── 2. bAuth verifica: ¿hay usuarios con permisos activos en esta app?
  │      SELECT count(*) FROM log_permission WHERE zone_id IN
  │        (SELECT zone_id FROM log_zone WHERE tenant_id=$1)
  │        AND is_active=true;
  │
  ├── 3. SI hay usuarios activos → ❌ BLOQUEAR desinstalación
  │      "No se puede desinstalar {app}: {N} usuarios tienen permisos activos.
  │       Reasigne o revoque los permisos antes de continuar."
  │
  ├── 4. SI no hay usuarios activos PERO hay historial de movimiento:
  │      SELECT count(*) FROM audit_event WHERE app_code=$1
  │        AND created_at > NOW() - INTERVAL '90 days';
  │      → ⚠️ NOTIFICAR: "La aplicación {app} será desinstalada en 30 días.
  │         {N} eventos de auditoría registrados en los últimos 90 días.
  │         Los registros históricos se preservarán."
  │      → Programar desinstalación diferida (30 días)
  │
  └── 5. SI no hay usuarios Y no hay movimiento en 90 días:
        → ✅ DELETE FROM privilege_application WHERE app_code=$1
        → BOS procede con la desinstalación
```

**Registro de estado BOS (.sbos_state.json):**
```json
{
  "fichas": {
    "tryton": {
      "status": "INSTALLED",
      "governance": {
        "app_code": 1,
        "registered_in_bauth": true,
        "registered_at": "2026-06-24T...",
        "users_with_access": 15,
        "last_activity": "2026-06-24T..."
      }
    }
  }
}
```
| P06 | `privilege_group` | ~30 | Grupos funcionales por aplicación. Patrón Odoo/Tryton: User + Manager por app. Apps complejas (Tryton) tienen ~10 grupos | ✅ Investigación completada en Manual D1 §2.1b — 10 apps × ~3 grupos | MEDIA |
| P07 | `privilege_role` | — | Roles del motor (se crean en runtime al asignar RolTemplate) | N/A — no requiere seed | — |
| P08 | `privilege_role_atom` | — | Mapeo rol↔átomo (runtime) | N/A — no requiere seed | — |
| P09 | `privilege_atom_audit` | — | WORM — solo INSERTs runtime | N/A — no requiere seed | — |

---

## 3. SEEDS PLANIFICADOS — CATÁLOGO DE ROLES (log_ + idn_)

| # | Tabla | Registros estimados | Origen de datos | Información disponible | Prioridad |
|---|-------|--------------------|----------------|----------------------|-----------|
| P10 | `log_zone` | 29 | Áreas organizacionales definidas en BAUTH-CATALOGO-ROLES-EMPRESARIALES.md §9: 29 áreas (AREA-DIR a AREA-SOST) con roles exclusivos y compartidos. Relación 1:N Área→Roles. | ✅ 29 áreas documentadas con códigos, niveles, roles exclusivos/compartidos, y tabla de activación por tamaño de empresa | **ALTA** |
| P11 | `log_permission` | — | Datos por tenant (runtime) | N/A — no requiere seed | — |
| P12 | `idn_role_template` | 66 | 66 plantillas base del catálogo de roles empresariales v2.1 | ✅ Plantillas definidas en `BAUTH-CATALOGO-ROLES-EMPRESARIALES.md` — falta serializar a JSONB | **ALTA** |
| P13 | `idn_role_closure` | — | Calculado por trigger al insertar rol | N/A — no requiere seed | — |
| P14 | `idn_role_template_history` | — | WORM — solo INSERTs runtime | N/A — no requiere seed | — |
| P15 | `idn_user_template` | — | Datos por usuario (runtime) | N/A — no requiere seed | — |
| P16 | `idn_user_template_history` | — | WORM — solo INSERTs runtime | N/A — no requiere seed | — |
| P17 | `idn_tier_policy` | 4 | **3 fuentes combinadas:** (1) NIST SP 800-63B-4 AAL1-3, (2) Manual D1 §8.7 clasificación por dominio D1-D12 y nivel de responsabilidad (SU→Visitante), (3) `Authentication_Framework.json` + `Policies_Authentication_Framework.json` — políticas concretas por tier (token TTL, session timeout, métodos requeridos, factores). Clasificación obligatoria por dominio de soberanía. | ✅ 3 fuentes documentadas. Falta consolidar en SQL con columna `domain_classification JSONB` que mapee cada tier a los 12 dominios | **ALTA** |

### 8.0 — Diferenciación: METHOD vs POLICY vs CONFIG

Los 2 JSONs del Framework de Autenticación contienen 3 tipos de datos MEZCLADOS.
Hay que separarlos al construir los seeds:

| Tabla | Tipo | Definición | Qué extraer de los JSONs |
|-------|------|-----------|------------------------|
| **`ath_method`** | **METHOD** | QUÉ método de autenticación usar. Ej: Password, TOTP, WebAuthn, Passkey | `Authentication_Framework.json`: modalidades biométricas (fingerprint, facial, iris...). `Policies_Authentication_Framework.json`: `webauthn_fido2.authenticator_policies` (platform vs roaming) |
| **`ath_policy`** | **POLICY** | QUÉ reglas aplicar al método. Ej: AAL requerido, complejidad de password, MFA obligatorio | `Authentication_Framework.json`: `sanctumEnhanced.security` (key rotation, token security). `Policies_Authentication_Framework.json`: `zero_trust.access_policies.verification.factors`, `conditional_access`, `password_policies`, `multi_factor_authentication` |
| **`ath_config`** | **CONFIG** | VALORES concretos de configuración. Ej: token_ttl=3600, session_ttl=28800, rate_limit=100 | `Authentication_Framework.json`: `sanctumEnhanced.tokenManagement.security.adaptiveInterval` (intervalos). `idn_tenant_config` defaults (token_ttl_seconds, session_ttl_max, rate_limit_rps) |

### 8.1 — Detalle de fuentes para P17 (idn_tier_policy)

**Fuente 1 — NIST SP 800-63B-4 (2024):** Define AAL1, AAL2, AAL3.
**Fuente 2 — Manual D1 §8.7:** Mapea cada tier a nivel de responsabilidad (SU, N1, N2-N5, M2M).
**Fuente 3 — Policies_Authentication_Framework.json v4.0:** Define políticas concretas:
  - `modern_authentication_policies.webauthn_fido2` → requisitos por tipo de autenticador (platform vs roaming)
  - `security_privacy_policies.zero_trust.access_policies.verification.factors` → identity, device, network, data
  - `multi_factor_authentication` → políticas MFA por nivel de riesgo
  - `conditional_access` → step-up triggers y duración
  - `password_policies` → complejidad, rotación, HIBP screening
  - `session_management` → TTL, reauthentication, concurrent sessions

**Clasificación OBLIGATORIA por dominio (D1-D12):**
Cada tier debe especificar qué dominios aplican y con qué intensidad:

| Tier | D1 Lógico | D2 Físico | D3 Financiero | D4 Temporal | D9 Credenciales | D11 Auditoría |
|------|-----------|-----------|---------------|-------------|-----------------|---------------|
| TIER_SU | Ilimitado | Ilimitado | Ilimitado | 24/7 | AAL3 | full |
| TIER_N1 | Admin | Admin | View | 24/7 | AAL3 | full |
| TIER_N2_N5 | Rol | Rol | Limitado | Horario | AAL2 | basic |
| TIER_M2M | API | No | No | 24/7 | mTLS | full |

---

## 4. SEEDS PLANIFICADOS — AUTENTICACIÓN (ath_ + cre_)

| # | Tabla | Registros estimados | Origen de datos | Información disponible | Prioridad |
|---|-------|--------------------|----------------|----------------------|-----------|
| P18 | `ath_method` | 26 + 15 bio | **METHOD — QUÉ método usar.** Lista canónica en Manual D1 §8.1 (WebAuthn/FIDO2), §8.2 (26 métodos), §8.6 (15 biométricos). Cada método con: nombre, tipo, herramienta que lo implementa, LoA mínimo, estándar vigente al 2026. Los JSONs referencian métodos pero no los definen — la fuente de verdad es el Manual. | ✅ 26 métodos + 15 biométricos documentados en Manual D1. Verificar vigencia de cada estándar al 2026 (§8.1). | **ALTA** |
| P19 | `ath_policy` | ~10 | **POLICY — QUÉ reglas:** `Authentication_Framework.json` §sanctumEnhanced.security (key rotation, adaptive interval) + `Policies_Authentication_Framework.json` §zero_trust, §mfa, §conditional_access, §password_policies, §session_management. Clasificar por dominio D1-D12 y tier (SU/N1/N2-N5/M2M). Ver §8.0. | ✅ Ambos JSONs analizados (602KB + 104KB). Secciones identificadas. Falta mapear a DDL con `domain_classification JSONB`. | ALTA |
| P20 | `ath_config` | ~5 | **CONFIG — VALORES concretos:** `Authentication_Framework.json` §sanctumEnhanced.tokenManagement (intervalos, adaptiveInterval) + `idn_tenant_config` column defaults (token_ttl_seconds=3600, session_ttl_max=28800, rate_limit_rps=100). Ver §8.0. | ✅ Fuentes identificadas. Extraer valores default de columnas DDL. | MEDIA |
| P21 | `cre_credential_policy` | — | Datos por tenant/rol (runtime) | N/A — no requiere seed | — |
| P22 | `cre_credential_rotation_log` | — | WORM — solo INSERTs runtime | N/A — no requiere seed | — |
| P23 | `cre_password_history` | — | WORM — solo INSERTs runtime | N/A — no requiere seed | — |
| P24 | `cre_mfa_enrollments` | — | Datos por usuario (runtime) | N/A — no requiere seed | — |
| P25 | `cre_biometric_templates` | — | Datos por usuario (runtime) | N/A — no requiere seed | — |

---

## 5. SEEDS PLANIFICADOS — CALENDARIO (bcalendar)

| # | Tabla | Registros estimados | Origen de datos | Información disponible | Prioridad |
|---|-------|--------------------|----------------|----------------------|-----------|
| C01 | `cal_calendar` | 6 | **6 calendarios del sistema por tenant.** Fuente: Manual D1 §3 + BAUTH-CALENDAR-SUBSYSTEM.md. Tipos: WORK, FISCAL, PROCESS, COMPLIANCE, HOLIDAY, MAINTENANCE. Se crean automáticamente al registrar un tenant. | ✅ Tipos definidos en RFC 4791 (VCALENDAR). Nombres y colores en Manual D1. | MEDIA |
| C02 | `cal_schedule` | 2 | **2 horarios base.** Fuente: Leyes laborales Bolivia (Ley General del Trabajo): jornada 8h (08:00-12:00, 14:00-18:00) lun-vie. Turnos: 06:00-14:00, 14:00-22:00, 22:00-06:00. RFC 7953 (VAVAILABILITY). | ✅ Ley General del Trabajo Bolivia + RFC 7953. Horario oficina y turnos rotativos estándar. | MEDIA |
| C03 | `cal_holiday` | ~15 | **Feriados oficiales Bolivia + principales LATAM.** Fuente: Decreto Supremo Bolivia (feriados nacionales 2026) + calendario oficial del Ministerio de Trabajo. Feriados fijos: 1-ene, 1-may, 6-ago, 25-dic. Feriados móviles: Carnaval, Pascua, Corpus Christi. LATAM: Argentina, Chile, Perú, Brasil, Paraguay (principales). | ✅ Decreto Supremo Bolivia vigente. Feriados LATAM de calendarios oficiales. Fórmula de Gauss para Pascua. | MEDIA |

## 6. SEEDS PLANIFICADOS — FINANCIERO (fin_)

| # | Tabla | Registros estimados | Origen de datos | Información disponible | Prioridad |
|---|-------|--------------------|----------------|----------------------|-----------|
| C04 | `fin_transaction_type` | ~20 | **Catálogo estándar de tipos de transacción.** Fuente: ISO 20022 (financial messaging) + SIN Bolivia RND 102100000011 (facturación electrónica). Tipos base: VENTAS, COMPRAS, PAGOS, COBROS, NÓMINA, INVENTARIO, TRIBUTARIO, BANCARIO, ACTIVOS_FIJOS, IMPORTACIÓN, EXPORTACIÓN. | ✅ 11 categorías definidas en `fin_transaction_category_enum`. ~20 tipos con código, nombre, riesgo, controles. | ALTA |

## 7. SEEDS PLANIFICADOS — SISTEMA DE MENÚS (menu_)

| # | Tabla | Registros estimados | Origen de datos | Información disponible | Prioridad |
|---|-------|--------------------|----------------|----------------------|-----------|
| M01 | `menu_context` | ~30 | **REGLA: cada ENUM type creado en DDL = 1 entrada en menu_context.** Contextos base (6) + ENUMs del sistema (~24). Fuente: `BAUTH-090-MENU-SYSTEM-SPEC.md` §4.2 + todos los ENUMs definidos en DDL. | ✅ 6 contextos base definidos. Falta agregar entradas por cada ENUM: fin_transaction_category, fis_location_type, domain_type, menu_type, calendar_type, alarm_channel, etc. | MEDIA |
| M02 | `menu_item` | ~50 | Menú jerárquico base SBOS: Finanzas, Administración, Usuarios, Roles, Reportes, Configuración, Auditoría. Fuente: `BAUTH-090-MENU-SYSTEM-SPEC.md` §3.1 | ✅ Estructura jerárquica definida. ~50 ítems con atoms asociados. | MEDIA |

## 8. SEEDS PLANIFICADOS — DATOS DE SELECCIÓN (Templates)

| # | Tabla | Registros estimados | Origen de datos | Información disponible | Prioridad |
|---|-------|--------------------|----------------|----------------------|-----------|
| N01 | `account_type` | 4 | SCIM 2.0 RFC 7643 §4.1: HUMAN, SERVICE, SYSTEM, GUEST | ✅ 4 tipos estándar. | BAJA |
| N02 | `gender` | 4 | ISO/IEC 5218 + RGPD: M, F, NB, NR + nombres localizados | ✅ 4 opciones estándar. | BAJA |
| N03 | `marital_status` | 7 | Normativa civil: SINGLE, MARRIED, DIVORCED, WIDOWED, NR, CIVIL_UNION, SEPARATED | ✅ 7 estados civiles estándar LATAM. | BAJA |
| N04 | `id_document_type` | ~12 | Normativa migratoria por país: DNI, PASSPORT, CI, RUT, CURP, NIT, CÉDULA, CARNET_EXTRANJERÍA, LICENCIA_CONDUCIR, PERMISO_RESIDENCIA, REGISTRO_CIVIL, OTRO | ✅ ~12 tipos estándar LATAM. | BAJA |
| N05 | `employment_type` | 7 | OIT + legislación laboral: FULL_TIME, PART_TIME, CONTRACTOR, INTERN, TEMPORARY, CONSULTANT, FREELANCE | ✅ 7 tipos estándar. | BAJA |

## 9. SEEDS PLANIFICADOS — TRAZABILIDAD (aud_ + ses_ + dlg_)

| # | Tabla | Registros estimados | Origen de datos | Información disponible | Prioridad |
|---|-------|--------------------|----------------|----------------------|-----------|
| P26 | `aud_event` | — | WORM particionado — solo INSERTs runtime | N/A — no requiere seed | — |
| P27 | `aud_access_reviews` | — | Datos por tenant (runtime) | N/A — no requiere seed | — |
| P28 | `aud_ghost_accounts` | — | Datos por tenant (runtime) | N/A — no requiere seed | — |
| P29 | `aud_superuser_contexts` | — | WORM — solo INSERTs runtime | N/A — no requiere seed | — |
| P30 | `ses_context` | — | Datos por sesión (runtime) | N/A — no requiere seed | — |
| P31 | `ses_context_switches` | — | Datos por sesión (runtime) | N/A — no requiere seed | — |
| P32 | `ses_sync_log` | — | WORM — solo INSERTs runtime | N/A — no requiere seed | — |
| P33 | `dlg_delegation_log` | — | WORM — solo INSERTs runtime | N/A — no requiere seed | — |

---

## 6. RESUMEN

| Estado | Cantidad | Descripción |
|--------|----------|-------------|
| ✅ **Ya creados** | 4 | global_language, global_currency, global_country, geo_timezone |
| ✅ **Info disponible — listo para extraer a SQL** | 6 | privilege_domain, privilege_verb, log_zone, idn_role_template, idn_tier_policy, ath_method |
| 🔴 **Debe construirse desde cero (producción)** | 2 | privilege_atom (1059), privilege_atom_policy (6782) — datos VPS son de prueba, no sirven |
| ⚠️ **Info parcial — requiere investigación adicional** | 4 | privilege_application, privilege_group, ath_policy, ath_config |
| ❌ **No aplica seed (runtime/WORM)** | 19 | El resto son datos por tenant/usuario/sesión o WORM |
| **TOTAL seeds a crear** | **12** | 4 ya creados + 6 listos + 2 desde cero |

---

## 7. METODOLOGÍA DE PROCESAMIENTO DE SEEDS

### 7.0 — Orden de dependencias (QUÉ construir primero)

Los seeds tienen dependencias entre sí. No se puede construir P03 sin antes tener P01, P02, P05, P06.

```
FASE SEED-0 — Catálogos Globales (sin dependencias)
  S01 ✅ global_language → S02 ✅ global_currency → S03 ✅ global_country → S04 ✅ geo_timezone

FASE SEED-1 — Vocabulario Base (sin dependencias entre sí, orden sugerido)
  P01 ⏳ privilege_domain (12 dominios) ────┐
  P02 ⏳ privilege_verb (~50 verbos) ───────┤
  P05 ⏳ privilege_application (12 apps) ───┤ Estos 4 son INDEPENDIENTES entre sí
  P06 ⏳ privilege_group (~40 grupos) ──────┘

FASE SEED-2 — Átomos y Políticas (DEPENDEN de SEED-1 completo)
  P03 ⏳ privilege_atom = P01 × P02 × P05 × P06 → ~1059 combinaciones válidas
  P04 ⏳ privilege_atom_policy = P03 + reglas de negocio → ~6782 políticas

FASE SEED-3 — Catálogo de Roles (DEPENDE de SEED-0 + SEED-1)
  P10 ⏳ log_zone (29 áreas) ─── usa global_language, global_country
  P12 ⏳ idn_role_template (~340 roles) ─── usa P01, P02, P05, P06, P10
  P17 ⏳ idn_tier_policy (4 tiers × 12 dominios)

FASE SEED-4 — Autenticación (DEPENDE de SEED-0 + SEED-1)
  P18 ⏳ ath_method (26 métodos + 15 biométricos)
  P19 ⏳ ath_policy (~10 políticas) ─── usa P01, P17
  P20 ⏳ ath_config (~5 configuraciones)

FASE SEED-5 — Calendario y Financiero (DEPENDEN de SEED-0)
  ⏳ cal_calendar (6 calendarios sistema)
  ⏳ cal_schedule (2 horarios base)
  ⏳ cal_holiday (feriados Bolivia + LATAM)
  ⏳ fin_transaction_type (~20 tipos)
```

**Regla de oro:** No construir P03 sin tener P01+P02+P05+P06 listos. No construir P04 sin tener P03 listo.

### 7.1 — Reglas de procesamiento

| # | Regla | Descripción |
|---|-------|-------------|
| R1 | **Un seed por tabla** | Archivo: `seed_{nombre_tabla}.sql` en `db/migrations/seeds/` |
| R2 | **Idempotencia obligatoria** | `TRUNCATE ... RESTART IDENTITY CASCADE` + `REINDEX` + `INSERT`. Ejecutable N veces con resultado idéntico |
| R3 | **Datos completos, no muestras** | Si el catálogo tiene 50 verbos, el seed tiene 50 INSERTs. No 10 de muestra |
| R4 | **UUIDv7 en todas las PKs** | `DEFAULT uuidv7()` — el seed no hardcodea UUIDs, los genera PostgreSQL 18 |
| R5 | **FKs resueltas con subquery** | `(SELECT type_id FROM fin_transaction_type WHERE code='FAC_EMITIR')` — no hardcodear UUIDs de otras tablas |
| R6 | **Verificación VPS × 3** | Ejecutar 3 veces en VPS. Las 3 deben producir exactamente el mismo resultado |
| R7 | **Orden topológico** | Seeds con dependencias (FKs) se ejecutan en orden: primero los catálogos raíz, luego los dependientes |
| R8 | **Sin datos de prueba** | Los datos VPS de universidad se descartan. Seeds construidos desde estándares y catálogos oficiales |
| R9 | **Verificar vigencia de estándares al 2026** | Cada seed debe citar el estándar, su versión, y confirmar que está vigente. Estándares deprecados o reemplazados deben identificarse. Ver §8.1 |
| R10 | **Clasificar por dominio de soberanía (D1-D12)** | Políticas y configuraciones deben llevar `domain_classification JSONB` indicando a qué dominios aplican y con qué intensidad |

### 7.2 — Orden de ejecución de seeds

``````

### 7.3 — Formato estándar de archivo seed

```sql
-- seed_{nombre_tabla}.sql — {N} registros
-- IDEMPOTENCIA: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: {estándar internacional o catálogo de referencia}
-- PostgreSQL 18.4: uuidv7(), skip scan indexes
-- ═══════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE {schema}.{tabla} RESTART IDENTITY CASCADE;
REINDEX TABLE {schema}.{tabla};

INSERT INTO {schema}.{tabla} (col1, col2, ...) VALUES
  ('valor1', 'valor2', ...),
  ('valor1', 'valor2', ...);

-- ═══════════════════════════════════════════════════════════
-- VERIFICACIÓN
-- ═══════════════════════════════════════════════════════════
-- SELECT count(*) AS total FROM {schema}.{tabla};
-- SELECT * FROM {schema}.{tabla} ORDER BY {pk};
```

### 7.4 — FUENTES DE DATOS POR SEED (Referencias exactas para ejecución)

Cada seed tiene una fuente de datos precisa. Al ejecutar el plan de acción, se extrae
de esta ubicación exacta. No se inventan datos. No se usan datos de prueba VPS.

| # | Seed | Fuente exacta | Archivo | Línea / § | Método de extracción |
|---|------|--------------|---------|-----------|---------------------|
| S01 | `seed_global_language.sql` | IANA Language Subtag Registry + CLDR 46 | `db/migrations/seeds/seed_global_language.sql` | — | ✅ Ya creado |
| S02 | `seed_global_currency.sql` | ISO 4217 (SIX Interbank) | `db/seeds/seed_global_currency.sql` | — | ✅ Ya creado |
| S03 | `seed_global_country.sql` | ISO 3166-1 + UN M.49 + REST Countries | `db/migrations/seeds/seed_global_country.sql` | — | ✅ Ya creado |
| S04 | `seed_geo_timezone.sql` | IANA TZ Database (zone.tab) | `db/migrations/seeds/seed_geo_timezone.sql` | — | ✅ Ya creado |
| P01 | `seed_privilege_domain.sql` | **Código Rust bauth** `SEED_DOMAINS` | `BauthAgent/src/bitmask/catalog.rs` | Líneas 153-166 | Copiar array Rust → SQL INSERTs. 12 dominios con código, nombre, fast_path, descripción |
| P02 | `seed_privilege_verb.sql` | **Manual D1 §2.1** Catálogo Unificado de Verbos | `plandeaccion/bauth/BAUTH-D1-MANUAL-COMPLETO.md` | §2.1 Fuentes 1-6 + Conclusión | 50 verbos: 4 CRUD + 27 SAP ACTVT + 15 extendidos + 4 ejecución |
| P05 | `seed_privilege_application.sql` | **BosAgent fichas** `servers/*/manifest.yml` | `BosAgent/src/servers/{S01,S02,S03,S06,S12}/*/manifest.yml` | Campo `identity.id` en cada ficha | 31 fichas → filtrar 12 apps (excluir infraestructura). Extraer id, name, description |
| P06 | `seed_privilege_group.sql` | **Manual D1 §2.1b** Grupos Funcionales | `plandeaccion/bauth/BAUTH-D1-MANUAL-COMPLETO.md` | §2.1b tabla de aplicaciones | 12 apps × ~3.5 grupos. Fuente: Odoo res.groups + Tryton modules |
| P10 | `seed_log_zone.sql` | **Catálogo Roles §9** Áreas Organizacionales | `plandeaccion/bauth/BAUTH-CATALOGO-ROLES-EMPRESARIALES.md` | §9.0 (29 áreas) + §9.4 (activación) | 29 áreas con código, nombre, nivel, roles. Extraer tabla Markdown → SQL |
| P12 | `seed_idn_role_template.sql` | **Catálogo Roles §2-7** Planta Organizacional | `plandeaccion/bauth/BAUTH-CATALOGO-ROLES-EMPRESARIALES.md` | §7.0-A a §7.7 (~200 roles) + §2 (48 roles) | Serializar cada rol a JSONB con 16 bloques. Columna Plantilla marca progreso |
| P17 | `seed_idn_tier_policy.sql` | **3 fuentes:** NIST 800-63B-4 + Manual D1 §8.7 + Policies_Authentication_Framework.json | `BAUTH-D1-MANUAL-COMPLETO.md` §8.7 + `Policies_Authentication_Framework.json` | 4 tiers × 12 dominios. Clasificación por dominio OBLIGATORIA |
| P18 | `seed_ath_method.sql` | **Manual D1 §8.1-8.2-8.6** — lista canónica de métodos | `BAUTH-D1-MANUAL-COMPLETO.md` §8.2 (26 métodos) + §8.6 (15 biométricos) | 41 métodos totales. Los JSONs referencian pero NO definen métodos |
| P19 | `seed_ath_policy.sql` | **2 JSONs** — políticas por método. Ver §8.0 METHOD vs POLICY vs CONFIG | `Authentication_Framework.json` + `Policies_Authentication_Framework.json` | §sanctumEnhanced + §zero_trust + §mfa + §conditional_access + §password + §session | Clasificar por dominio D1-D12 y tier |
| P20 | `seed_ath_config.sql` | **idn_tenant_config defaults** + **Auth Framework intervals** | `DDL_skSBOS_db.sql` + `Authentication_Framework.json` | token_ttl=3600, session_ttl=28800, rate_limit=100, key_rotation=4h | Extraer defaults de columnas DDL |

**Nota:** Las fuentes marcadas con ruta relativa están dentro de:
`/opt/skull/orquestador/proyectos/desarrollo/sbos/` para código y DDL,
`/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/daemons/bauth/plandeaccion/bauth/` para documentos de planificación.

## 8. VERIFICACIÓN DE ESTÁNDARES — Vigencia al 2026

Cada seed debe citar el estándar que respalda sus datos, verificar la versión vigente,
y confirmar que no ha sido deprecado o reemplazado.

### 8.1 — Estándares aplicables por seed

| Seed | Estándar primario | Versión vigente (2026) | Estado | Verificación |
|------|-------------------|----------------------|--------|-------------|
| S01 | BCP 47 / RFC 5646 + ISO 639-3:2007 | RFC 5646 (2010), ISO 639-3 actualizado por SIL | ✅ Vigente | IANA Subtag Registry activo |
| S02 | ISO 4217:2015 | ISO 4217 actualizado por SIX Interbank | ✅ Vigente | 3 actualizaciones/año |
| S03 | ISO 3166-1:2020 + UN M.49 | ISO 3166-1 última actualización 2022 | ✅ Vigente | Cambios raros (Sudán del Sur 2011) |
| S04 | IANA TZ Database | 2024b (última release) | ✅ Vigente | Actualizaciones trimestrales por DST |
| P01 | ANSI INCITS 359-2004 (RBAC) | Reafirmado 2020, sin cambios | ✅ Vigente | NIST RBAC Nivel 3 complementa |
| P02 | SAP ACTVT estándar interno + Odoo ORM | SAP S/4HANA 2024, Odoo 18 | ✅ Vigente | Ambos en producción activa |
| P17 | **NIST SP 800-63B-4 (2024)** | **Rev.4 — Diciembre 2024** | ✅ Vigente | ⚠️ Rev.4 introdujo: passkeys como AAL2, deprecación SMS, sin rotación forzada de passwords |
| P17 | NIST SP 800-53 Rev.5 | Rev.5 (2020) + actualizaciones hasta 2024 | ✅ Vigente | AC-2, AC-5, AC-6, AU-2 |
| P18 | FIDO2 / WebAuthn Level 2 | W3C Recommendation (2023) | ✅ Vigente | Passkeys agregados 2022-2023 |
| P19 | RFC 6749 (OAuth 2.0) → OAuth 2.1 | OAuth 2.1 draft final (2025) | ⚠️ Migrar a 2.1 | ROPC e Implicit grant ELIMINADOS. PKCE obligatorio |
| P19 | RFC 8628 (Device Auth) | 2019 | ✅ Vigente | CIBA complementa |
| P19 | RFC 9470 (Step-Up) | 2023 | ✅ Vigente | Implementado en Keycloak 26.6 |

### 8.2 — Estándares que requieren ACCIÓN

| Estándar | Problema | Acción requerida |
|----------|---------|-----------------|
| **OAuth 2.0 → 2.1** | ROPC e Implicit grant eliminados en 2.1. SBOS debe migrar | Actualizar `ath_policy` para usar solo Authorization Code + PKCE |
| **SMS OTP** | NIST 800-63B-4 lo depreca explícitamente (SIM swapping, SS7) | Quitar SMS como canal en `ath_method`. Migrar a TOTP app |
| **Password rotation** | NIST 800-63B-4: "SHALL NOT require periodic password changes" | Actualizar `cre_credential_policy` — rotación solo si hay evidencia de compromiso |
| **NIST IR 8202** (Blockchain Identity) | En desarrollo. Puede convertirse en SP oficial | Monitorear. `blk_anchor` preparado para cumplir |

---

### 7.5 — Próximas acciones (en orden)

1. **P01 — `privilege_domain`:** Extraer SEED_DOMAINS de `bauth/src/bitmask/catalog.rs` → SQL. 12 registros. Fuente: código Rust existente (única fuente válida).
2. **P02 — `privilege_verb`:** Consolidar ~50 verbos del catálogo unificado §2.1 → SQL. Fuente: SAP ACTVT + Odoo + Dynamics + ServiceNow + NetSuite.
3. **P05 — `privilege_application`:** 10 aplicaciones base SBOS → SQL. Fuente: Manual D1 §2.1b.
4. **P06 — `privilege_group`:** ~30 grupos funcionales → SQL. Fuente: Odoo/Tryton group patterns + Manual D1 §2.1b.
5. **P03 — `privilege_atom`:** 1059 átomos desde cero → SQL. Fuente: 368 roles × 12 dominios × 4 verbos × 10 apps × 30 grupos. Los datos VPS se descartan.
6. **P04 — `privilege_atom_policy`:** 6782 políticas desde cero → SQL. Fuente: Policies_Authentication_Framework.json v4.0 + reglas de negocio D1-D12.

---

*Documento generado 2026-06-24. Se actualiza conforme se crean seeds.*
