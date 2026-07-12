# Anexo A.22 — El aislamiento multi-tenant: sin RLS, solo el `WHERE tenant_id` del código
## Documento de respaldo de sustentación: el estado crudo del aislamiento y la brecha P2 de seguridad

**Tipo:** ANEXO — respaldo de sustentación (tipo **D** verificación de código + **B** industria)
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Respalda a:** MANUAL-MULTITENANCY-IDAAS (1.12 §3) · MANUAL-SEGURIDAD-DATOS (2.10) · MANUAL-SEGURIDAD (2.09)
**Verificación de código:** `DDLs/` (búsqueda RLS) + `src/db/` + 29 archivos con `tenant_id` — leída 2026-07-11
**Normas base:** NIST SP 800-53 AC-4 (aislamiento) · SC-4 · defensa en profundidad · PostgreSQL Row-Level Security

---

## 1. Propósito

Dar el estado crudo del aislamiento entre tenants: sobre qué se apoya HOY y qué falta. **Cómo
citarlo:** `A.22 §3` (la brecha).

## 2. El estado crudo — verificado

| Verificación | Evidencia | Resultado |
|---|---|---|
| Políticas RLS en el DDL | `grep -rn 'ROW LEVEL SECURITY\|CREATE POLICY' DDLs/` | **0** — no hay Row-Level Security en ninguna tabla |
| Filtro por tenant en código | `tenant_id` en **29 archivos** `src/` | El aislamiento vive en el `WHERE tenant_id = $1` de cada handler |

**Traducción cruda:** el aislamiento multi-tenant de bAuth depende **exclusivamente de que cada
consulta de cada handler recuerde filtrar por `tenant_id`**. No hay ninguna red de seguridad en
la base de datos. Un solo handler que olvide el `WHERE tenant_id` — o un bug que lo omita en una
rama — expone datos de un tenant a otro, y la BD no lo impediría.

## 3. ⚠️ La brecha P2 de seguridad (confirma Q8 del informe de consistencia)

| Aspecto | Estado |
|---|---|
| Modelo declarado (1.12) | Aislamiento por tenant en el pool de datos |
| Modelo real | **Solo aplicación** — `WHERE tenant_id` manual, sin defensa en profundidad |
| Lo que exige la industria | **RLS como segunda capa**: aunque el código falle, PostgreSQL niega filas de otro tenant. Es el patrón estándar de multi-tenancy pool-model (una BD, filas mezcladas, RLS por `current_setting('app.tenant_id')`) |
| Norma | NIST AC-4/SC-4 · defensa en profundidad (2.09): la seguridad no descansa en una sola capa |

**Resolución recomendada (P2 de seguridad, ya anotada en el corpus como Q8):** activar RLS en
las tablas tenant-scoped — `ALTER TABLE … ENABLE ROW LEVEL SECURITY` + `CREATE POLICY … USING
(tenant_id = current_setting('app.current_tenant')::uuid)`, y que el pool fije el `tenant_id`
de sesión tras autenticar. El `WHERE` del código sigue (rendimiento), la RLS respalda
(seguridad). Cambio en `DDLs/` → HITL.

## 4. Lo que FALTA — específico

| # | Brecha | Exigencia | Prioridad |
|---|---|---|:---:|
| **M1** | **RLS ausente** — 0 policies (§3) | Defensa en profundidad (AC-4/SC-4) | **P2 seguridad** |
| M2 | Columnas `realm_kc`/`realm_kc_ext` residuales en `idn_tenant` (modelo del motor externo eliminado — Q7) | Limpieza post-ADR-010 | P3 |
| M3 | Verificar que los 29 archivos con `tenant_id` filtran SIEMPRE (auditoría de cobertura del WHERE) | Ningún handler sin filtro | P2 (mientras no haya RLS, es la única defensa) |

## 5. Verificación de completitud

| Verificación | Resultado |
|---|---|
| RLS en BD | ❌ 0 policies — hallazgo P2 |
| Filtro en código | ✅ presente (29 archivos) pero **única capa** |
| Coherencia con 1.12/Q8 | ✅ confirma el hallazgo del corpus con evidencia de grep |

## 6. Referencias e historial

**Del código:** `DDLs/` · `src/db/` · 29 archivos con `tenant_id`. **Del proyecto:** 1.12 §3 · 2.09 · 2.10.
**Industria:** [PostgreSQL RLS](https://www.postgresql.org/docs/current/ddl-rowsecurity.html) · [multi-tenancy pool vs silo](https://aws.amazon.com/blogs/database/multi-tenant-data-isolation-with-postgresql-row-level-security/) · NIST AC-4.

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Anexo inicial (tipo D+B): el estado crudo del aislamiento — **0 políticas RLS en todo el DDL** (verificado por grep), el aislamiento depende exclusivamente del `WHERE tenant_id` de 29 archivos de handlers (única capa, sin red de seguridad en BD). Brecha P2 de seguridad (confirma Q8): activar RLS como defensa en profundidad. Brechas M2 (columnas realm residuales Q7) y M3 (auditar la cobertura del WHERE mientras no haya RLS). |
