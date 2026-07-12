# Anexo A.36 — El menú contextual (bglobal.menu_context): la regla de oro ENUM↔menu auditada
## Documento de respaldo de sustentación (tipo D)

**Versión:** 1.0.0 · **Fecha:** 2026-07-11 · **Respalda a:** MANUAL-MENU-CONTEXTUAL (2.08) · A.01 §B1 (ENUMs del rol)
**Verificación de código:** `DDLs` (`menu_context` = 41 menciones; seeds bglobal = 7) — leída 2026-07-11
**Normas:** la regla de oro del sistema (cada ENUM → 1 entrada en menu_context)

## 1. El estado real — regla parcialmente materializada
`bglobal.menu_context` es el registro central de valores de selección (la UI lee dropdowns de
aquí, no del código). **Regla de oro:** cada ENUM declarado en un DDL → exactamente una entrada
en `menu_context`. Estado: **41 menciones en DDL, 7 entradas en seeds bglobal**.

## 2. Lo que FALTA — específico
| # | Brecha | Exigencia | Prioridad |
|---|---|---|:---:|
| ME1 | **Auditar la regla de oro** — que TODOS los ENUMs del esquema tengan su entrada en menu_context (los de A.01: role_status, role_type, role_validity_type, semver_change_type; y los futuros del motor 1.13: version_channel) | Regla de oro (2.08) | P2 |
| ME2 | Cobertura por tenant (cada tenant su copia — la tabla es tenant-scoped) | Multi-tenancy | P2 |

## 3. Verificación de completitud
menu_context existe y poblado parcial ✅ · auditoría de completitud ENUM↔entrada pendiente (ME1). La regla se cumplió en las resoluciones recientes (role_status, role_validity_type — A.01 §B1).

| Ver. | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-11 | Menú contextual: bglobal.menu_context (41 menciones DDL, 7 seeds) y la regla de oro ENUM↔entrada; brechas ME1 auditar cobertura de todos los ENUMs (incluidos los del motor 1.13), ME2 por tenant. |
