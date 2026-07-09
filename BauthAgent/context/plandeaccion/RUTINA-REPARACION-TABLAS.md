# RUTINA-REPARACION-TABLAS.md — Protocolo de Reparación de DDL

**Versión:** 2.0 · **Fecha:** 2026-06-24
**Propósito:** Protocolo estandarizado para reparar cualquier tabla del DDL — 6 pasos obligatorios.
Incluye mandato explícito de investigación de estándares, normas internacionales y prácticas
de la industria de autenticación.

---

## Comando del humano

```
revisar {nombre_tabla} --seed    → tabla con seed (catálogo)
revisar {nombre_tabla}           → tabla operativa (sin seed)
```

---

## Paso 0 — Clasificar el dominio y alcance de la tabla

**ANTES de investigar estándares, determinar:**

| Pregunta | Objetivo |
|----------|------|
| ¿A qué dominio pertenece? (D1–D12, USER, ORG, SEC, GLOBAL) | Ubicar la tabla en el ecosistema correcto |
| ¿Qué problema de negocio resuelve? | No es una tabla por ser tabla — tiene un propósito en el Context Plane |
| ¿Es catálogo (seed) u operativa (runtime)? | Determina si lleva `--seed` |
| ¿Qué otras tablas dependen de ella? | FK relationships, orden de migración |
| ¿Ya existe en el DDL antiguo? (`001_bauth_pendientes.sql`) | Si existe → migrar. Si no → crear desde cero |
| ¿Ya fue migrada al DDL test? | Si ya está → no duplicar. Verificar con `grep -c "CREATE TABLE.*{tabla}" DDL_skSBOS_db_test.sql` |
| ¿Está en el inventario maestro? | Buscar código T-XXX en `BAUTH-INVENTARIO-TABLAS-DECISION.md`. Verificar que el switch esté en ✅ MIGRAR o 🆕 CREAR |
| ¿Qué tablas REFERENCIA esta tabla? (FKs salientes) | Las tablas referenciadas DEBEN existir antes. Si no existen → migrarlas primero |
| ¿Qué tablas la REFERENCIAN a ella? (FKs entrantes) | Las tablas que la referencian DEBEN migrarse después. Planificar orden |
| ¿Tiene dependencias circulares? | Si tabla A → B y B → A → requiere migración atómica o deferred FK |

**Orden topológico obligatorio:** Las tablas se migran en orden de dependencias.
No se puede migrar una tabla si sus FK references no existen todavía.

---

## Paso 1 — Investigar estándares, normas y prácticas de la industria

**⚠️ ESTE PASO ES OBLIGATORIO. NO SALTAR. NO ABREVIAR.**

El error más costoso que hemos cometido fue diseñar estructuras sin investigar cómo la industria
resuelve el mismo problema. Las secciones del template v2.0 eran esqueletos vacíos porque no
investigamos cómo Okta, Auth0, Keycloak, Entra ID, SailPoint, OPA o CyberArk estructuran
sus políticas, roles y configuraciones.

### 1.1 — Investigación de estándares internacionales

Para CADA tabla, identificar y documentar:

| Fuente | Qué buscar | Dónde |
|--------|-----------|------|
| **NIST** | SP 800-63B-4 (autenticación), SP 800-53 (controles de acceso), SP 800-207 (Zero Trust), SP 800-57 (criptografía) | `nvlpubs.nist.gov` |
| **ISO** | 27001:2022 (A.5.15–A.8.15 controles IAM), 24760 (identidad), 30107-3 (biométricos) | `iso.org` |
| **IETF/RFC** | RFC 9470 (Step-Up), RFC 9562 (UUIDv7), RFC 5545 (iCalendar), RFC 6238 (TOTP), RFC 6749/7636 (OAuth 2.1) | `rfc-editor.org` |
| **FIDO/W3C** | WebAuthn Level 3, FIDO2, Passkeys | `fidoalliance.org`, `w3.org` |
| **OWASP** | ASVS V2 (autenticación), V2.1 (passwords), V2.5 (recovery) | `owasp.org` |
| **PCI DSS** | 4.0.1 Req.7 (acceso), Req.8 (identidad), Req.10 (auditoría) | `pcisecuritystandards.org` |
| **OpenID** | CAEP 1.0 (Sept 2025), SSF 1.0, RISC 1.0 | `openid.net` |
| **IANA** | Subtag Registry (idiomas), TZ Database (timezones) | `iana.org` |

**Entregable:** Lista de estándares aplicables con número de documento, sección específica, año de vigencia.

### 1.2 — Investigación de la industria: ¿cómo lo hacen los sistemas reales?

Para CADA tabla, buscar y documentar cómo lo implementan al menos **3** de estos sistemas:

| Sistema | Tipo | Qué analizar |
|---------|------|-------------|
| **Okta / Auth0 FGA** | IAM Cloud | Modelo de relaciones Zanzibar, type definitions, conditions, roles as relations |
| **Keycloak** | IAM Open Source | Composite roles, authorization services, 9 policy types, realm management |
| **Microsoft Entra ID** | IAM Enterprise | Custom role definitions, allowedResourceActions, administrative units, PIM |
| **SailPoint IIQ** | IGA Enterprise | Role mining, policies, certifications, SoD enforcement, access reviews |
| **CyberArk** | PAM | Privileged access, just-in-time, session isolation, break-glass |
| **OPA/Rego** | Policy-as-Code | Rego rules, input/output JSON, default-deny, field-level filtering |
| **Odoo / Tryton** | ERP | ir.model.access, ir.rule, res.groups, button rules, record rules |
| **Google BeyondCorp** | Zero Trust | Device trust tiers, location trust tiers, access levels |
| **Kong** | API Gateway | Plugins, consumers, ACL, rate limiting, session management |

**Entregable:** Para cada sistema analizado, documentar:
- ¿Cómo modelan este tipo de dato? (tablas, JSON, claims)
- ¿Qué campos usan? (nombre, tipo, restricciones)
- ¿Qué relaciones tienen con otras entidades?
- ¿Qué valores por defecto o catálogos pre-definidos incluyen?

### 1.3 — Validación cruzada contra el template v6.0

Antes de finalizar el diseño de la tabla, verificar:

| Verificación | Pregunta |
|-------------|------|
| ¿Los campos que estoy definiendo aparecen en alguna sección del template v6.0? | Si no aparecen, ¿son realmente necesarios? |
| ¿Los campos del template v6.0 tienen su correspondiente columna en esta tabla? | Si faltan, la tabla está incompleta |
| ¿El nivel de profundidad de esta tabla es comparable a lo que hace la industria? | Si Okta tiene 20 atributos por método auth y yo tengo 5, algo falta |

### 1.4 — Documentar la investigación

**Todo hallazgo debe quedar documentado en el COMMENT ON de la tabla o en el manual correspondiente.**

No se acepta "investigué y está bien". Se requiere evidencia:
- Fuente consultada (URL, sección, fecha)
- Qué se encontró
- Cómo se aplicó al diseño de la tabla

---

## Paso 2 — Corregir/crear tabla en DDL

### 2.1 — Estructura de la tabla

- PK UUIDv7 (nunca TEXT, CHAR, INTEGER, SERIAL)
- Clave natural como UNIQUE NOT NULL (no PK)
- Columnas en inglés, sin mezclar español
- ENUM types para valores controlados (nunca CHECK IN hardcodeado)
- Si hay demasiados valores → tabla de opciones separada, no ENUMs gigantes
- `ctx_id` en tablas Nivel 1+
- `created_at` / `updated_at` en toda tabla
- `COMMENT ON` en cada columna con referencia al estándar [ej: `[NIST 800-63B-4 §5.1]`]
- `domain_classification` en tablas que aplican a múltiples dominios
- Índices skip scan + GIN sobre JSONB
- Si la tabla ya existe en DDL antiguo → normalizar: `bos_` → `bauth.`, TEXT PK → UUIDv7, español → inglés
- Si la tabla es nueva → diseñar CREATE TABLE completo con todas las columnas identificadas en Paso 1

### 2.2 — Foreign Keys: verificar existencia de tablas referenciadas

**⚠️ CRÍTICO: Cada FK debe apuntar a una tabla que YA EXISTE en el DDL test.**

Si la tabla referenciada no ha sido migrada todavía, hay dos opciones:

| Opción | Cuándo usarla | Cómo |
|--------|--------------|------|
| **A — Migrar la dependencia primero** | La tabla referenciada es del mismo lote de trabajo | Migrar la tabla padre ANTES que la tabla hija |
| **B — Deferred FK** | Hay dependencia circular o la tabla padre está en otro lote | Crear la FK como `DEFERRABLE INITIALLY DEFERRED`, migrar la tabla padre después, validar con `SET CONSTRAINTS` |

**Antes de crear cada FK, verificar:**
```sql
-- ¿Existe la tabla referenciada?
SELECT 1 FROM information_schema.tables 
WHERE table_schema = 'bauth' AND table_name = '{tabla_referenciada}';

-- ¿La columna referenciada es PK o UNIQUE?
SELECT column_name FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_schema = 'bauth' AND tc.table_name = '{tabla_referenciada}'
AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE');
```

### 2.3 — Índices: diseñar para el patrón de consulta

| Tipo de índice | Cuándo usarlo | Ejemplo |
|---------------|--------------|------|
| **B-tree estándar** | Búsquedas por igualdad, rangos, ORDER BY | `CREATE INDEX ON tabla(tenant_id, created_at)` |
| **UNIQUE** | Restricción de unicidad + índice | `CREATE UNIQUE INDEX ON tabla(tenant_id, code)` |
| **GIN sobre JSONB** | Búsquedas dentro de documentos JSONB | `CREATE INDEX ON tabla USING GIN (config jsonb_path_ops)` |
| **Parcial (WHERE)** | Índice solo para un subconjunto frecuente | `CREATE INDEX ON tabla(status) WHERE status = 'ACTIVE'` |
| **Skip scan** (PG 18+) | Para combinaciones donde el primer campo tiene pocos valores distintos | Habilitado por defecto en PostgreSQL 18 |

### 2.4 — JSONB: documentar estructura esperada

**⚠️ Todo campo JSONB debe tener su estructura documentada en el COMMENT ON.**

```sql
COMMENT ON COLUMN bauth.tabla.config IS
  '[JSONB] Estructura esperada: {
    "$schema": "bos_v1",
    "priority": 50,
    "action": "allow|deny|step_up",
    "evaluate": {"logic": "and|or", "conditions": [...]},
    "params": {...}
  }. Validar con CHECK constraint si la estructura es mandatoria.';
```

Si la estructura JSONB es mandatoria, agregar CHECK:
```sql
CONSTRAINT chk_config_valid CHECK (
    config ? '$schema'
    AND config ? 'action'
    AND (config ->> 'action') IN ('allow','deny','step_up','pending_approval')
)
```

---

## Paso 3 — Generar seed (si --seed)

### 3.1 — Campos con colección de valores: investigar y poblar en menú

**⚠️ APLICA A TODO CAMPO QUE REPRESENTE UNA SELECCIÓN ENTRE VALORES CONOCIDOS.**

No importa si el campo está restringido por ENUM o es TEXT libre. Si el campo representa
una elección entre opciones (estado civil, tipo de documento, género, tipo de empleo,
tipo de cuenta, parentesco, nivel educativo, etc.), el seed del menú DEBE contener
todas las variantes documentadas.

**Metodología:**

| Paso | Acción | Ejemplo (estado civil) |
|------|--------|------------------------|
| 1. Identificar | Detectar campos que representan selección entre valores conocidos | `marital_status` en `idn_user_template` |
| 2. Investigar | Buscar estándares, normativas y sistemas reales que definan el catálogo | ISO/IEC 5218, normativa civil LATAM, SCIM 2.0 RFC 7643 |
| 3. Consolidar | Unificar todas las variantes encontradas en una lista completa | SINGLE, MARRIED, DIVORCED, WIDOWED, NR, CIVIL_UNION, SEPARATED, DOMESTIC_PARTNER |
| 4. Documentar | Registrar fuente, estándar y justificación de cada valor | `seed_menu_context.sql` → `context_key='marital_status'` |
| 5. Poblar | INSERT en `seed_menu_context.sql` con todos los valores | 8 registros con `entity_type='marital_status'` |

**Fuentes de investigación para colecciones comunes:**

| Campo | Estándar / Fuente | Sistema de referencia |
|-------|-------------------|----------------------|
| `gender` | ISO/IEC 5218 | SCIM 2.0 RFC 7643 §4.1.2 |
| `marital_status` | Normativa civil LATAM | Odoo HR, SAP HR |
| `id_document_type` | Normativa migratoria por país | ICAO Doc 9303, DNI, PASSPORT |
| `employment_type` | OIT / Legislación laboral | Odoo HR, Workday |
| `account_type` | SCIM 2.0 RFC 7643 §4.1 | Okta, Auth0 |
| `education_level` | ISCED 2011 (UNESCO) | SAP HR, LinkedIn |
| `blood_type` | ISBT 128 / OMS | FHIR HL7 |
| `relationship_type` | Normativa civil | Odoo HR, SAP HR |

**Regla de oro:** Si la UI va a mostrar un dropdown, el menú ya debe tener todas las opciones.
El desarrollador de frontend no investiga — consume del menú.

### 3.2 — Seed estándar

- Archivo: `db/migrations/seeds/seed_{nombre_tabla}.sql`
- Idempotente: TRUNCATE RESTART IDENTITY CASCADE + REINDEX + INSERT
- Nombres de columnas en inglés
- JSONB para campos multi-lenguaje
- **Datos reales, no de prueba.** Construir desde estándares y catálogos oficiales
- Sin hardcodear UUIDs — usar subqueries: `(SELECT tenant_id FROM idn_tenant WHERE tenant_slug='skull')`
- Cada seed cita su fuente de datos en el encabezado

---

## Paso 4 — Probar en VPS

- `DROP DATABASE IF EXISTS bauth_test WITH (FORCE)` + `CREATE DATABASE`
- Ejecutar DDL → verificar 0 errores
- Ejecutar seed 3 veces → verificar mismo resultado
- Verificar: total, active, unique, null_ids, FK integrity

**Conexión VPS:**
```bash
sshpass -p '12345678ubuntu' ssh root@13.140.128.230
export KUBECONFIG=/etc/bos/.kube/config
kubectl exec -n sbos-data postgresql-0 -- psql -U postgres -d bauth_ok_test
```

---

## Paso 6 — Post-migración: documentar, inventariar y commit

### 6.1 — Actualizar el inventario maestro

- Marcar la tabla como **✅ COMPLETADA** en `BAUTH-INVENTARIO-TABLAS-DECISION.md`
- Si la tabla se migró del DDL antiguo → eliminar de `001_bauth_pendientes.sql` (mover a `_limpiado/`)
- Si la tabla es nueva → cambiar switch de 🆕 CREAR a ✅ COMPLETADA

### 6.2 — Actualizar el manual del dominio

Cada dominio tiene su manual. La tabla migrada debe documentarse allí:

| Dominio | Manual |
|---------|--------|
| D1 Lógico | `BAUTH-D1-MANUAL-COMPLETO.md` |
| D2 Físico | `BAUTH-DDL-DOMINIO-FISICO.md` |
| D3 Financiero | `BAUTH-DDL-DOMINIO-FINANCIERO.md` |
| D4–D12 | Crear manual si no existe |

Qué agregar al manual:
- Nombre de la tabla y su propósito en el Context Plane
- Lista de columnas con su justificación (estándar + template v6.0)
- Relaciones con otras tablas (FKs, dependencias)
- Seed poblado y fuente de los datos
- Ejemplo de consulta típica

### 6.3 — Verificar cobertura del template v6.0

Ejecutar esta verificación ANTES de declarar la tabla como terminada:

```
¿Cada columna de esta tabla es necesaria para alguna sección del template v6.0?
¿Cada campo de la sección correspondiente del template v6.0 tiene su columna en esta tabla?
```

Si la respuesta es NO a cualquiera → volver al Paso 1.

### 6.4 — Git commit

```bash
git add DDL_skSBOS_db_test.sql
git add db/migrations/seeds/seed_{tabla}.sql
git add plandeaccion/bauth/{manual}.md
git add plandeaccion/bauth/BAUTH-INVENTARIO-TABLAS-DECISION.md
git commit -m "[DDL] {tabla} — {dominio} {tipo} {estándar}"
# Ej: "[DDL] ath_policy_d9 — D9 Credenciales · políticas NIST 800-63B-4"
```

### 6.5 — Actualizar registro de estado

- Marcar el átomo correspondiente en `REGISTRO-ESTADO.md` (bAuth o BOS según corresponda)
- Anotar commit hash en la columna Commit

---

## CHECKLIST DE VERIFICACIÓN FINAL

Antes de declarar una tabla como COMPLETADA, verificar TODO esto:

| # | Verificación | ¿Pasó? |
|---|-------------|:---:|
| 1 | ¿Se investigaron los estándares internacionales aplicables? (Paso 1.1) | ☐ |
| 2 | ¿Se investigó cómo lo implementan al menos 3 sistemas reales? (Paso 1.2) | ☐ |
| 3 | ¿Se validó contra el template v6.0? (Paso 1.3) | ☐ |
| 4 | ¿La investigación está documentada con fuentes? (Paso 1.4) | ☐ |
| 5 | ¿PK es UUIDv7? | ☐ |
| 6 | ¿Clave natural es UNIQUE NOT NULL (no PK)? | ☐ |
| 7 | ¿Todas las columnas están en inglés? | ☐ |
| 8 | ¿Columnas con valores controlados usan ENUM type? | ☐ |
| 9 | ¿Tiene `ctx_id` si es Nivel 1+? | ☐ |
| 10 | ¿Tiene `created_at` y `updated_at`? | ☐ |
| 11 | ¿Cada columna tiene COMMENT ON con [estándar]? | ☐ |
| 12 | ¿FKs referencian tablas que YA existen en el DDL test? (Paso 2.2) | ☐ |
| 13 | ¿Índices diseñados para el patrón de consulta? (Paso 2.3) | ☐ |
| 14 | ¿Columnas JSONB tienen estructura documentada? (Paso 2.4) | ☐ |
| 15 | ¿Seed es idempotente (TRUNCATE + REINDEX + INSERT)? (Paso 3) | ☐ |
| 16 | ¿Seed usa datos reales desde estándares, no datos de prueba VPS? (Paso 3) | ☐ |
| 17 | ¿FKs en seed usan subqueries, no UUIDs hardcodeados? (Paso 3) | ☐ |
| 18 | ¿Campos con colección de valores tienen entrada en `seed_menu_context.sql`? (Paso 3.1) | ☐ |
| 19 | ¿ENUMs nuevos/modificados tienen entrada en `seed_menu_context.sql`? (R9) | ☐ |
| 20 | ¿Pasó 3 ejecuciones idempotentes en VPS con 0 errores? (Paso 4) | ☐ |
| 21 | ¿Inventario maestro actualizado? (Paso 6.1) | ☐ |
| 22 | ¿Manual del dominio actualizado? (Paso 6.2) | ☐ |
| 23 | ¿Cobertura del template v6.0 verificada? (Paso 6.3) | ☐ |
| 24 | ¿Git commit con mensaje estructurado? (Paso 6.4) | ☐ |
| 25 | ¿Registro de estado actualizado? (Paso 6.5) | ☐ |

---

## Reglas absolutas

| # | Regla | Consecuencia si se viola |
|---|-------|--------------------------|
| R1 | No hardcodear valores en tablas → ENUM types | Schema drift, valores inconsistentes |
| R2 | Posibilidades muy amplias → tabla de opciones + FK (no ENUMs largos) | ENUMs de 50+ valores son inmantenibles |
| R3 | Cero mezcla español/inglés en columnas | Inconsistencia, rechazo en revisión |
| R4 | Cero ALTER TABLE en DDL (hot migration solo en producción) | DDL de prueba debe ser CREATE OR REPLACE |
| R5 | Cero INSERTs en DDL (van en seeds) | Separación DDL/datos |
| R6 | **Paso 1 NO es opcional** — investigar estándares + industria siempre | Terminamos con esqueletos vacíos como pasó con las secciones del template v2.0 |
| R7 | **Validar contra el template v6.0** — cada campo debe tener propósito en el Context Plane | Tablas sin propósito = lastre |
| R8 | **Documentar la investigación** — fuentes, hallazgos, decisiones | Sin evidencia, el diseño es opinión no ingeniería |
| R9 | **ENUM + menú siempre juntos** — cada ENUM creado o modificado DEBE actualizar `seed_menu_context.sql`. El ENUM restringe los valores en la base de datos; el menú facilita la selección en la UI. Ambos deben reflejar exactamente los mismos valores. Si se agrega un valor al ENUM, se agrega al menú. Si se depreca un valor del ENUM, se depreca en el menú. | ENUM y menú desincronizados → la UI muestra opciones que la BD rechaza, o la BD acepta valores que la UI no ofrece |
| R10 | **Campos con colección de valores → investigar + seed en menú** — todo campo que represente una selección entre valores conocidos (estado civil, tipo de documento, género, tipo de empleo, tipo de cuenta, etc.) DEBE: (1) investigar sus variaciones según estándares y normativas internacionales, (2) poblarse en `seed_menu_context.sql` con todas las opciones documentadas. Esto aplica TANTO si el campo está restringido por ENUM como si es TEXT libre. El propósito es que la UI siempre tenga el catálogo completo de opciones estándar para ofrecer al usuario, sin que el desarrollador tenga que investigar por su cuenta. | Sin menú poblado → cada desarrollador de UI inventa sus propias listas, incompletas y sin estándares. Se pierde contexto. |
| R11 | **FK en orden topológico** — ninguna FK puede apuntar a una tabla que no existe todavía en el DDL test. Si la dependencia no está lista → migrar la tabla padre primero o usar DEFERRABLE. | FK rota → el DDL no compila en PostgreSQL |
| R12 | **Sin duplicados entre schemas** — verificar que la tabla no existe ya en otro schema (`bauth`, `bglobal`, `bcalendar`, `bos`, `bos_privilege`, `bos_blockchain`). Si existía en DDL antiguo bajo schema distinto → unificar en el schema correcto. | Tablas duplicadas → datos inconsistentes, FK huérfanas |
| R13 | **JSONB con estructura documentada y validada** — todo campo JSONB debe tener (1) COMMENT ON describiendo la estructura esperada, (2) CHECK constraint si la estructura es mandatoria, (3) índice GIN para búsquedas. | JSONB sin documentar → nadie sabe qué campos acepta, los seeds insertan basura |
| R14 | **Post-migración completa** — después de cada tabla: actualizar inventario, actualizar manual del dominio, verificar cobertura del template, git commit, actualizar registro de estado. Sin estos 5 pasos la tabla no está terminada aunque compile en VPS. | Tabla sin post-migración → el inventario se desactualiza, los manuales quedan incompletos, el equipo pierde trazabilidad |

---

## Fuentes de consulta obligatorias por dominio

| Dominio | Estándares primarios | Sistemas de referencia |
|---------|---------------------|----------------------|
| **D1 — Lógico** | NIST 800-53 AC-3/5/6, ANSI INCITS 359, RFC 9470, XACML 3.0, CAEP 1.0 | Okta FGA, Keycloak AuthZ, Entra ID Roles, OPA/Rego |
| **D2 — Físico** | IEC 60839-11-5, OSDP v2.2.3, NIST 800-116, ISO 27001 A.7 | Lenel, Genetec, Honeywell PACS |
| **D3 — Financiero** | PCI DSS 4.0.1, SOX §404, COSO 2023, ISO 20022, NIST AC-5 | SAP GRC, Oracle Financials, Odoo Accounting |
| **D4 — Temporal** | RFC 5545, GTRBAC, ISO 8601 | Google Calendar API, Cal.com, Cronofy |
| **D5 — Biométrico** | ISO 30107-3, ISO 19794, NIST 800-63B-4 §5.2.3, GDPR Art.9 | Apple Face ID, Windows Hello, YubiKey Bio |
| **D6 — Geoespacial** | NIST PE-3, BeyondCorp, OGC GeoFence, ISO 19115 | Google Maps API, Mapbox, ArcGIS |
| **D7 — Red** | NIST 800-207 ZTA, CISA ZTMM v2, IEEE 802.1X, CAEP device-compliance | Zscaler, Cloudflare ZTNA, Cisco ISE |
| **D8 — Contexto** | SBOS-049, W3C Trace Context, NIST 800-63B-4 §7, CAEP session-revoked | OpenTelemetry, Grafana, Datadog APM |
| **D9 — Credenciales** | NIST 800-63B-4, FIDO2 L3, OAuth 2.1, OWASP ASVS V2, RFC 9470 | Okta MFA, Auth0 Passkeys, Keycloak WebAuthn |
| **D10 — Delegación** | NIST AC-5, ANSI INCITS 359-2004 DSD, ISO 27001 A.8.2 | CyberArk PAM, Okta Access Requests, SailPoint |
| **D11 — Auditoría** | ISO 27001 A.8.15, PCI DSS 10.3.2, NIST AU-2/AU-3, SOX §404 | Splunk, Wazuh, Elastic Security |
| **D12 — Blockchain** | NIST IR 8202, W3C DID Core, EIP-725/735, ERC-1484 | Hyperledger Besu, Arbitrum, Ethereum |

---

**Why:** El humano definió este protocolo para estandarizar la reparación del DDL. Cada tabla sigue
exactamente los mismos 7 pasos (0 al 6). El Paso 1 se reforzó después del incidente con las secciones
del template v2.0, que quedaron como esqueletos vacíos por falta de investigación de la industria.

**How to apply:** Cuando el humano diga "revisar {tabla} --seed", ejecutar los 7 pasos en orden.
Sin saltar ninguno. Sin hacer de más. Sin preguntar — solo ejecutar y reportar.
Al finalizar, completar el checklist de 25 verificaciones. Si alguna falla, la tabla no está terminada.

[[tablas-cumplen-normas-internacionales]] [[uuidv7-pk-obligatorio-toda-tabla]]
