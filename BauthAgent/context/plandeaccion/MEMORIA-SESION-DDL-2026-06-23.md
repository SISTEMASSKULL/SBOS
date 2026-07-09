# MEMORIA-SESION-DDL-2026-06-23 — Construcción DDL skSBOS_db

**Fecha:** 2026-06-23 · **Autor:** sbos-coordinador + humano
**Propósito:** Registro detallado de todas las decisiones, correcciones y artefactos generados
durante la sesión de construcción del DDL para la Identity Governance & Audit Platform.

---

## 1. Objetivo de la Sesión

Construir desde cero el DDL para `skSBOS_db` (base de datos canónica del proyecto SBOS)
aplicando todas las reglas definidas en `PLAN-RECONSTRUCCION-DDL.md` v6.0.0 y los
estándares internacionales documentados en `BAUTH-IDENTITY-GOVERNANCE-AUDIT-PLATFORM.md`.

---

## 2. Documentos Utilizados

| Documento | Versión | Rol |
|-----------|---------|-----|
| `PLAN-RECONSTRUCCION-DDL.md` | v6.0.0 | Plan maestro con reglas, estados y ANEXO A |
| `BAUTH-IDENTITY-GOVERNANCE-AUDIT-PLATFORM.md` | v4.0.0 | Plataforma IAM con 5 pilares |
| `BAUTH-IDENTITY-GOVERNANCE-GAPS.md` | v2.0.0 | 24 brechas contra 12 estándares |
| `BAUTH-IDENTITY-GOVERNANCE-AUDIT-REPORT.md` | v1.0.0 | Auditoría DDL (score 39%) |
| `MANUAL-HOT-DDL-PRODUCCION.md` | v1.0.0 | Guía de migración en caliente |
| `001_bauth_init_20260622_1621.sql` | backup | Backup original del .bak (Jun 22) |

---

## 3. Reglas Aplicadas

### 3.1 Del Plan de Reconstrucción (§6.3)

| # | Regla | Aplicación |
|---|-------|-----------|
| R1 | Cero ALTER TABLE (solo CREATEs) | Todo el DDL usa CREATE TABLE IF NOT EXISTS |
| R2 | Cero INSERTs (van en seeds) | Datos en `db/seeds/` |
| R3 | 100% UUID para PKs | uuidv7() nativo de PostgreSQL 18.4 |
| R4 | REFERENCES intactas con orden topológico | Nivel 0 → Nivel 1 → Nivel 2 |
| R5 | IF NOT EXISTS en todos los CREATE | Idempotencia verificada (3 ejecuciones) |
| R6 | Nombres de tabla en inglés con prefijos funcionales | `idn_`, `geo_`, `global_`, `cal_` |
| R7 | COMMENT ON con referencias a estándares | ISO, NIST, PCI, GDPR en cada columna |
| R8 | ctx_id en TODAS las tablas operativas | Pendiente para tablas Nivel 1+ |
| R9 | Hash-chain SHA-256 en tablas WORM | Pendiente |
| R10 | PARTITION BY RANGE para alto volumen | Pendiente |
| R11 | REVOKE UPDATE/DELETE en tablas WORM | Pendiente |

### 3.2 PostgreSQL 18.4 Best Practices

| Práctica | Aplicación |
|----------|-----------|
| Lowercase unquoted identifiers | `bauth`, `bglobal`, `bcalendar` (no `"bAuth"`) |
| uuidv7() nativo | `DEFAULT uuidv7()` en todas las PKs (no `gen_random_uuid()`) |
| Skip scan indexes | Índices multi-columna con leading column de baja cardinalidad |
| ENUM types | 7 dominios controlados (sin CHECK IN hardcodeados) |
| JSONB para variaciones | `name JSONB` con estructura `{"es":{...},"en":{...}}` |
| TRUNCATE RESTART IDENTITY | Idempotencia en seeds (no ON CONFLICT) |
| DEFERRABLE FK | Para seeds que insertan en orden inverso a dependencias |

---

## 4. Tablas Construidas

### 4.1 Resumen

| # | Schema | Tabla | PK | Columnas | Origen | Estado |
|---|--------|-------|-----|----------|--------|--------|
| 001 | bauth | idn_tenant | UUIDv7 | 45 | bos_tenant | ✅ |
| 002 | bglobal | global_currency | CHAR(3) | 14 | bos_moneda | ✅ |
| 003 | bglobal | global_language | TEXT | 9 | bos_idioma | ✅ |
| 004 | bglobal | global_country | UUIDv7 | 36 | bos_pais | ✅ |
| 005 | bauth | geo_timezone | TEXT | 8 | bos_timezone | ✅ |

### 4.2 idn_tenant (001)

- **PK:** `tenant_id UUID PRIMARY KEY DEFAULT uuidv7()`
- **Natural key:** `tenant_slug TEXT UNIQUE NOT NULL` (para URLs)
- **7 ENUM types:** tenant_status_enum, tenant_type_enum, isolation_level_enum, subscription_status_enum, plan_tier_enum, provisioning_status_enum, audit_level_enum
- **Ciclo de vida:** 7 estados + soft-delete + grace period 30 días
- **Seguridad:** rate_limit_rps, allowed_ip_ranges, mfa_required, password_policy, session_ttl_max
- **Compliance:** data_retention_days (Ley 2492 Bolivia: 2555 días = 7 años), terms_accepted_at (GDPR Art.7)
- **45 COMMENT ON** documentando cada columna con estándar normativo
- **5 índices skip scan:** status, tenant_type, country, created_at, slug

### 4.3 global_currency (002)

- **PK:** `currency_code CHAR(3)` — natural key ISO 4217
- **FK:** `country_id UUID REFERENCES bglobal.global_country(country_id)` + `issuer_country CHAR(2)`
- **ISO 4217 completo:** currency_code, iso_numeric, decimal_places, minor_unit_name, introduced_at, withdrawn_at
- **JSONB name:** `{"es":{"singular":"Boliviano","plural":"Bolivianos"},"en":{"singular":"Bolivian Boliviano","plural":"Bolivian Bolivianos"}}`
- **143 monedas** en seed combinado con países

### 4.4 global_language (003)

- **PK:** `locale TEXT` — natural key BCP 47
- **ISO 639:** iso_639_1 (CHAR 2), iso_639_2 (CHAR 3), iso_639_3 (CHAR 3)
- **JSONB name:** `{"es":"Español","en":"Spanish","native":"Español"}`
- **direction:** ltr / rtl
- **Pendiente seed** (~120 idiomas)

### 4.5 global_country (004)

- **PK:** `country_id UUID PRIMARY KEY DEFAULT uuidv7()`
- **Natural key:** `iso_alpha2 CHAR(2) UNIQUE NOT NULL`
- **33 columnas:** ISO 3166-1/2/3 + UN M.49 + ITU-T E.164 + IANA TZ + ICAO + CLDR + Wikidata
- **JSONB name_native:** nombres en 80+ locales
- **JSONB demonym_native:** gentilicios multi-lenguaje
- **POINT capital_coords:** coordenadas de la capital
- **196 países** en seed (ONU + observadores)
- **Índices:** continent, region, languages (GIN), timezones (GIN), currency, active

### 4.6 geo_timezone (005)

- **PK:** `timezone_id TEXT` — natural key IANA
- **JSONB name:** `{"es":"Bolivia (La Paz)","en":"Bolivia Time"}`
- **Corregido a inglés:** name, observes_dst, country_code, principal_city, is_active

---

## 5. ENUM Types Creados

```sql
tenant_status_enum       (PENDING_VERIFICATION, ACTIVE, SUSPENDED, MAINTENANCE, SOFT_DELETED, TERMINATED, PURGED)
tenant_type_enum         (STANDARD, REGULATED, HIGH_SENSITIVITY)
isolation_level_enum     (ROW_LEVEL, SCHEMA_PER_TENANT, DB_PER_TENANT)
subscription_status_enum (TRIAL, ACTIVE, PAST_DUE, CANCELLED)
plan_tier_enum           (BASIC, PRO, ENTERPRISE)
provisioning_status_enum (PENDING, INFRA_PROVISIONING, SCHEMA_CREATED, IDP_CONFIGURED, COMPLETED, FAILED)
audit_level_enum         (basic, full)
```

Todos creados con `CREATE TYPE ... AS ENUM (...);` con bloque `DO $$ ... EXCEPTION WHEN duplicate_object THEN NULL; END $$;` para idempotencia.

---

## 6. Archivos Generados

| Archivo | Ruta | Contenido |
|---------|------|-----------|
| `DDL_skSBOS_db.sql` | `BauthAgent/db/migrations/` | DDL limpio con 5 tablas + 7 ENUMs + schemas |
| `seed_global_country.sql` | `BauthAgent/db/migrations/seeds/` | 196 países + 143 monedas (combinado) |
| `seed_global_country.sql` | `BauthAgent/db/seeds/` | Copia idéntica |
| `seed_global_currency.sql` | `BauthAgent/db/seeds/` | 143 monedas (standalone, obsoleto) |
| `001_bauth_pendientes.sql` | `BauthAgent/db/migrations/` | 98 tablas por procesar del .bak original |
| `MEMORIA-SESION-DDL-2026-06-23.md` | `plandeaccion/bauth/` | Este documento |

---

## 7. Decisiones de Diseño

| # | Decisión | Fundamento |
|---|---------|-----------|
| D1 | lowercase unquoted identifiers | PostgreSQL standard. `"bAuth"` con comillas es anti-patrón |
| D2 | uuidv7() en vez de gen_random_uuid() | PG18 nativo, time-ordered, mejor para B-tree |
| D3 | JSONB para campos multi-lenguaje | Un solo campo vs 4 columnas TEXT. Extensible a N idiomas |
| D4 | ENUM types en vez de CHECK IN | Type-safe, reutilizable, almacenado como integer |
| D5 | TRUNCATE RESTART IDENTITY en seeds | Idempotencia real (no ON CONFLICT) |
| D6 | Seed combinado países+monedas | Un solo archivo, orden controlado, FK resuelta con subquery |
| D7 | DEFERRABLE INITIALLY DEFERRED para FK | Permite insertar en orden inverso dentro de transacción |
| D8 | Índices skip scan (low cardinality leading) | PG18 usa multi-columna sin filtrar por leading column |

---

## 8. Correcciones de Errores

| Error | Causa | Solución |
|-------|-------|---------|
| DEFAULT `*` en UUID | Wildcard no es UUID válido | `DEFAULT NULL` |
| NOT NULL DEFAULT NULL | Contradicción lógica | `DEFAULT NULL` (sin NOT NULL) |
| TEXT PK en bos_rol_template | Nunca migrada a UUID | `UUID PRIMARY KEY DEFAULT uuidv7()` |
| Trailing commas en CHECK | Sintaxis heredada del .bak | Corrección manual |
| `iso_numeric` NULL en seed | Zambia typo ZB→ZM, Kosovo sin código | 894 y 900 asignados |
| `Pa'anga` rompe string SQL | Comilla simple sin escapar | `Pa''anga` (doble comilla) |
| `country_id` sin tipo ni coma | Columna incompleta | Agregado `UUID REFERENCES` |
| VARCHAR(n) en vez de TEXT | PostgreSQL no optimiza VARCHAR | `TEXT` en todas partes |
| Herramientas automáticas corrompen .bak | Regex masivo sin verificación | **Solo ediciones manuales verificadas** |

---

## 9. Lecciones Aprendidas

1. **No usar regex/sed masivos** — rompen el archivo. Editar manualmente y probar cada cambio.
2. **PostgreSQL fold a lowercase** — no luchar con comillas. `bauth` no `"bAuth"`.
3. **JSONB para variaciones** — un solo campo reemplaza N columnas de nombres en diferentes idiomas/plurales.
4. **ENUM types para valores fijos** — eliminan CHECK constraints hardcodeados y son reutilizables.
5. **Seed en orden correcto** — TRUNCATE dependientes primero, INSERT en orden de dependencias.
6. **Probar en VPS cada cambio** — el DROP DATABASE con FORCE es necesario cuando hay conexiones activas.
7. **El backup del Jun 22 es la fuente de verdad** — trabajar desde `001_bauth_pendientes.sql`, eliminar tablas procesadas.

---

## 10. Próximos Pasos (Pendiente)

| # | Tarea | Prioridad |
|---|-------|-----------|
| 1 | Crear seed para `global_language` (~120 idiomas) | Alta |
| 2 | Procesar `idn_tenant_config` (Nivel 1, FK → idn_tenant) | Alta |
| 3 | Procesar `idn_empresa`, `idn_sucursal`, `idn_pos` (jerarquía) | Alta |
| 4 | Agregar `ctx_id` a tablas Nivel 1+ | Media |
| 5 | Crear tabla `audit_event` (WORM + hash-chain) | Media |
| 6 | Completar seeds de timezone e idiomas | Media |
| 7 | Probar DDL completo en `bauth_db` producción (con hot migration) | Baja |

---

## 11. Comandos Útiles

```bash
# Probar DDL en VPS
cat DDL_skSBOS_db.sql | sshpass -p '...' ssh root@VPS \
  'K=/etc/kubernetes/admin.conf; kubectl --kubeconfig=$K exec -i -n sbos-data postgresql-0 -- psql -U postgres -d bauth_test'

# Probar seed
sshpass -p '...' scp seed.sql root@VPS:/tmp/ && \
ssh root@VPS 'kubectl cp /tmp/seed.sql sbos-data/postgresql-0:/tmp/ && \
  kubectl exec -n sbos-data postgresql-0 -- psql -U postgres -d bauth_test -f /tmp/seed.sql'

# Drop forzado
kubectl exec -n sbos-data postgresql-0 -- psql -U postgres -c "DROP DATABASE bauth_test WITH (FORCE)"

# Ver columnas de una tabla
kubectl exec -n sbos-data postgresql-0 -- psql -U postgres -d bauth_test -c \
  "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='global_currency' ORDER BY ordinal_position"
```

---

*Documento generado 2026-06-23. Registra ~12 horas de trabajo. 5 tablas construidas, 7 ENUMs, 196 países, 143 monedas, 0 errores en VPS.*
