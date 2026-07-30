---
name: bauth-ddl
description: >
  La base de datos de bAuth: DDL V2 de SBOS_db, sus 12 secciones (S1-S12), 190+ tablas,
  inventario de diseño A.65.02 (T-NNN con nombre y propósito), convenciones de diseño,
  y la definición canónica de dominios/bloques (D00-D15 + D98 + D99 via A.65.03.01).
  Úsala cuando vayas a consultar, modificar o verificar el esquema de la base de datos
  de bAuth, trabajar con seeds/migrations, o entender la estructura de almacenamiento
  de identidades, roles, políticas, sesiones o auditoría.
---

# Skill — bAuth: DDL y Base de Datos

**Fuente de verdad del schema:** `SBOS_db_V2_DDL.sql` + `SBOS_db_V2_DDL_MANUAL.md`  
**Versión DDL:** 2.7.0 · 2026-07-28  
**Motor:** PostgreSQL 18.4 · UUIDv7 (RFC 9562) · `gen_ulid()` para orden de inserción

---

## 1 · Archivos canónicos del DDL

| Archivo | Ruta absoluta | Rol |
|---------|--------------|-----|
| DDL completo | `/opt/skull/orquestador/proyectos/SBOS/DDLs/SBOS_db_V2_DDL.sql` | Esquema SQL ejecutable — fuente de verdad estructural |
| Manual del DDL | `/opt/skull/orquestador/proyectos/SBOS/DDLs/SBOS_db_V2_DDL_MANUAL.md` | La intención detrás de cada decisión — **leer junto al DDL** |
| Inventario de diseño | `context/Documentacion/anexos/A.65.02_ANEXO-NUEVA-DDL-v1.0.md` | Inventario canónico de tablas V2 — T-NNN con nombre definitivo + propósito (v1.6, 2026-07-28) |
| Dominios y bloques | `context/Documentacion/anexos/A.65.03.01_FORMALIZACION-DOMINIOS-BLOQUES-CANONICOS-v1.0.md` | 134 bloques · 18 dominios — SSOT normativo de bloques |

**Regla:** nunca consultar el DDL sin leer también el manual. El DDL define la estructura; el manual define la intención y los invariantes que los constraints protegen. A.65.02 es el inventario de diseño que explica el PARA QUÉ de cada tabla.

---

## 2 · Bases de datos

| Entorno | Nombre BD | Notas |
|---------|-----------|-------|
| VPS pruebas | `SBOSDB` | PostgreSQL 18.4 en la VPS de pruebas — donde se verifica todo |
| Producción | `SBOS_db` | Nombre canónico (igual que el archivo DDL) |
| Fábrica (meta) | `SKDATA` (puerto 5402) | **DISTINTO** — es la BD de la fábrica para tracking de agentes; NO es la BD de bAuth |

> **Importante:** `SKDATA` es para la bitácora de agentes (fábrica). `SBOSDB` / `SBOS_db` es la BD operativa de bAuth (identidades, roles, sesiones, auditoría).

---

## 3 · Estructura del DDL — 12 Secciones (S1-S12)

| Sección | Schema | Contenido | LEVELS |
|---------|--------|-----------|--------|
| **S1** | `bglobal` | Configuración global del sistema — cryptography, geo, settings | 0–2 |
| **S2** | `btenant` | Tenants y sub-tenants — multi-tenancy raíz | 2–3 |
| **S3** | `bcalendar` | Calendarios, horarios, feriados — integración bCalendar | 1–3 |
| **S4** | `bauth.roles_*` | Roles y DAG de herencia — PrivilegeEngine | 1–6 |
| **S5** | `bauth.version_*` | Versionado universal — temporal constraints PG18 | 1–5 |
| **S6** | `bauth.policy_*` | Árbol de políticas — PolicyEngine / AtomLang | 1–6 |
| **S7** | `bauth.idn_*` | Identidad D00 — árbol organizacional, usuarios, atributos | 1–7 |
| **S8** | `bauth.priv_*` | Privilegios — átomos, BitMask Dual, DomainRegistry | 1–8 |
| **S9** | `bauth.session_*` | Sesiones, Context Plane, tokens, ctx_id | 1–7 |
| **S10** | `bauth.audit_*` | Auditoría WORM — events, IGA, trazabilidad | 1–8 |
| **S11** | `bauth.risk_*` | Riesgo e ITDR — anomalías, scoring, alertas | 1–6 |
| **S12** | `bauth.pam_*` | PAM — acceso privilegiado, check-out de credenciales | 1–6 |

**190+ tablas** numeradas T-001 → T-194+. LEVELS indican orden de dependencia (0 = sin FK externos, 11 = máximo anidamiento).

---

## 4 · Convenciones del DDL

### Símbolos del manual

| Símbolo | Significado |
|---------|-------------|
| 🔑 | Primary Key |
| 🔗 | Foreign Key |
| 🔒 | WORM (Write Once Read Many) — prohibido UPDATE/DELETE por RSP |
| 📦 | Tabla particionada |
| 🌱 | Tabla con datos seed (datos iniciales obligatorios) |
| ⚡ | Trigger asociado |
| 🔄 | Tabla replicada |

### Reglas de diseño obligatorias (del DDL manual)

- **UUIDv7** (RFC 9562) como PK en todas las tablas de entidad — orden temporal sin clock externo.
- **`gen_ulid()`** para IDs de inserción ordenada en tablas de alta escritura.
- **`DEFAULT now()`** en `created_at`; `updated_at` manejado por trigger `set_updated_at`.
- **Row Security Policy (RSP)** en todas las tablas de datos sensibles — aislamiento multi-tenant.
- **WORM en tablas de auditoría** — `bauth.audit_*` son append-only por RSP; ningún UPDATE/DELETE posible.
- **`bit_slot` inmutable** — una vez asignado a un átomo, nunca se reasigna aunque el átomo sea deprecado (preserva coherencia histórica del audit log).

---

## 5 · Dominios y Bloques de bAuth (A.65.03.01)

**Documento:** `context/Documentacion/anexos/A.65.03.01_FORMALIZACION-DOMINIOS-BLOQUES-CANONICOS-v1.0.md`  
**SSOT de bloques:** `bauth.idn_roles_template` en SBOSDB (verificado 2026-07-28)  
**Total:** 134 bloques · 18 dominios · depth=2 en el árbol de roles

| Dominio | Código | Bloques | Propósito |
|---------|--------|---------|-----------|
| D00 · Identidad Organizacional | `d00` | 9 | Árbol org (tenant→bdomain→pos→actor), atributos |
| D01 · Control de Acceso Lógico | `d01` | 9 | Permisos clásicos de aplicación |
| D02 · Control de Acceso Físico | `d02` | 8 | Acceso físico, zonas, puertas |
| D03 · Controles Financieros | `d03` | 9 | Límites, aprobaciones, montos |
| D04 · Acceso Temporal | `d04` | 6 | Horarios, ventanas, restricciones de tiempo |
| D05 · Autenticación Biométrica | `d05` | 7 | Biometría, liveness, matching |
| D06 · Acceso Geoespacial | `d06` | 6 | Zona GPS, geofencing |
| D07 · Seguridad de Red | `d07` | 8 | IP, subnet, protocolo, VPN |
| D08 · Contexto / Sesión | `d08` | 7 | ctx_id, estado sesión, device posture |
| D09 · Gestión de Credenciales | `d09` | 10 | Ciclo vida credenciales, rotación, revocación |
| D10 · Delegación e Impersonación | `d10` | 7 | Actuar en nombre de otro, proxy |
| D11 · Auditoría y Cumplimiento | `d11` | 7 | Registro WORM, IGA, conformidad |
| D12 · Anclaje Blockchain | `d12` | 7 | ECDSA en Besu, registro inmutable |
| D13 · Firma Digital Externa | `d13` | 8 | ADSIB RSA-SHA256, Ley 164 Bolivia |
| D14 · Gestión de Acceso Privilegiado | `d14` | 7 | PAM, checkout credenciales críticas |
| D15 · Identidad No Humana (NHI) | `d15` | 8 | M2M, service accounts, API keys |
| D98 · Registro Estructural | `d98` | 4 | Metadatos de estructura interna |
| D99 · Administración Global | `d99` | 7 | bglobal, criptografía de atributos, versionado normas |

**Estado actual de todos los bloques: ⬜** — existen a depth=2 en la BD, sin átomos poblados.  
El trabajo pendiente es poblar los átomos (depth≥3), no crear los bloques.

---

## 6 · Inventario de diseño DDL (A.65.02)

**Documento:** `context/Documentacion/anexos/A.65.02_ANEXO-NUEVA-DDL-v1.0.md` (v1.6 · 2026-07-28)  
**Estado:** DISEÑO PARCIAL — 9 secciones con tablas definidas · 4 secciones pendientes (USUARIOS · AUTENTICACIÓN · FIRMA DIGITAL · FEDERACIÓN/OIDC)

A.65.02 es el inventario limpio del rediseño completo del DDL. Cada entrada incluye código T-NNN, nombre canónico definitivo y propósito. **Es el "para qué" de cada tabla**; el DDL SQL es el "cómo".

| Sección | Estado | Tablas | Notas clave |
|---------|--------|--------|-------------|
| GLOBAL | ✅ | T-001..T-004, T-059..T-061, T-114 | Schema `bglobal` — catálogos compartidos |
| TENANT | ✅ | T-005..T-013 | Schema `btenant` — multi-tenancy raíz |
| ROLES | ✅ | T-040..T-042, T-063, T-161b, T-162, T-163, T-194, T-B02L | T-162 = árbol de políticas (QUÉ PUEDE); T-170 = grants por usuario (no por rol) |
| VERSIONADO | ✅ | T-152..T-155 | `WITHOUT OVERLAPS` PG18 para temporal |
| IDENTIDAD | ✅ | T-156..T-168, T-186..T-190 | `atom_position` vive en T-162, no en T-170 |
| CALENDARIO | ✅ | T-012, T-014..T-019, T-124..T-125 | Integración bcalendar |
| USUARIOS | ⏳ pendiente | — | Diseño en progreso |
| AUTENTICACIÓN | ⏳ pendiente | — | Diseño en progreso |
| SESIÓN | ✅ | T-181, T-191..T-193 | Context Plane + ctx_id |
| PRIVILEGIOS | ✅ | T-170, T-170b, T-171..T-176, T-179 | T-170 = grants por usuario; SoD solo en T-174/T-175 |
| AUDITORÍA | ✅ | T-177..T-178 | WORM append-only |
| FIRMA DIGITAL | ⏳ pendiente | — | ADSIB RSA-SHA256, Ley 164 |
| FEDERACIÓN/OIDC | ⏳ pendiente | — | IdP externo |
| RIESGO/ITDR | ✅ | T-180 | Scoring de anomalías |
| PAM | ✅ | T-182, T-182b, T-183..T-185, T-189 | Check-out de credenciales críticas |

**Decisiones arquitectónicas clave en A.65.02 (no inferir del DDL SQL):**
- `atom_position` está en **T-162** (árbol de políticas — QUÉ PUEDE), NO en T-170.
- **T-170** (`bauth.privilege_atom_grant`) es grants por usuario, NO por rol.
- **SoD** es validación pura en T-174/T-175 — no es una tabla de asignación.
- Schema `bglobal` para catálogos compartidos entre todos los tenants.
- Schema `bauth` para tablas propias de bAuth.

---

## 7 · Tablas clave para bAuth

```sql
-- Bloques de dominios (SSOT de blocks)
bauth.idn_roles_template       -- 134 bloques · depth=2 · SSOT de qué bloques existen

-- Árbol organizacional
bauth.idn_tenant               -- Tenants
bauth.idn_bdomain              -- Business domains dentro del tenant
bauth.idn_identity             -- Identidades (personas, M2M)

-- Roles y privilegios
bauth.roles_template           -- RolTemplate v6.0 — 14 bloques JSONB
bauth.priv_atom                -- Catálogo de átomos (~6,000 definidos)
bauth.priv_bitmask             -- BitMask Dual por identidad/dominio

-- Sesiones
bauth.session_ctx              -- Context Plane — ctx_id activos
bauth.session_token            -- Tokens JWT emitidos

-- Auditoría (WORM)
bauth.audit_event              -- Log WORM de todos los eventos de identidad
```

---

## 8 · Cómo trabajar con el DDL

```bash
# Verificar conexión a SBOSDB (VPS pruebas)
psql "postgresql://<user>@<vps-host>:5432/SBOSDB" -c "\dt bauth.*" | head -20

# Ver estructura de una tabla
psql "postgresql://<user>@<vps-host>:5432/SBOSDB" -c "\d bauth.idn_roles_template"

# Contar bloques por dominio
psql "postgresql://<user>@<vps-host>:5432/SBOSDB" -c \
  "SELECT split_part(clave,'.',1) AS dominio, count(*) AS bloques
   FROM bauth.idn_roles_template WHERE tipo='bloque' GROUP BY 1 ORDER BY 1;"
```

**Antes de proponer cualquier cambio al DDL:**
1. Leer el manual (`SBOS_db_V2_DDL_MANUAL.md`) para entender el invariante que cada constraint protege.
2. Verificar que el cambio no rompe ningún RSP existente.
3. Verificar que el `bit_slot` de ningún átomo activo o histórico sea reasignado.
4. Escalar al humano si el cambio afecta tablas WORM o PKs existentes.
