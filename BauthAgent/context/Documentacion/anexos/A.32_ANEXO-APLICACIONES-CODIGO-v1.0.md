# Anexo A.32 — El catálogo de aplicaciones y su integración: estado real
## Documento de respaldo de sustentación (tipo D+B)

**Versión:** 1.0.0 · **Fecha:** 2026-07-11 · **Respalda a:** MANUAL-APLICACIONES (1.10) · A.05 (átomos por app)
**Verificación de código:** `DDLs/seeds/` (`privilege_application`) + el mapa zona→app — leída 2026-07-11
**Normas:** ABAC 800-162 · el modelo de dominio-como-app (A.05)

## 1. El estado real — catálogo de apps sembrado
`privilege_application` con **16 registros** (seeds). Cada plano de control D2–D12 es una app
(pacs, fin, cal… — A.05); D1 son las apps reales de negocio. La zona de negocio (abstracta) se
mapea a la app que la implementa (zona→app, no al revés — A.01 §B6).

## 2. Lo que FALTA — específico
| # | Brecha | Prioridad |
|---|---|:---:|
| AP1 | **Integración real de apps de negocio** — bajo ADR-010, la integración de aplicaciones del ecosistema pasa por biedata (aduana de datos); verificar qué apps están integradas de verdad vs catalogadas | P2 |
| AP2 | El mapa `zone_application_map` materializado (A.01 §B6 lo referencia) | P2 |
| AP3 | Los 5808 átomos D1 (apps reales, seed generativo bauth_06) vs los sembrados | P2 |

## 3. Verificación de completitud
Catálogo de apps ✅ (16 en seed) · integración real ⏳ (AP1) · el enforcement es nativo (BitMask, no el motor externo eliminado — ADR-010).

**Industria:** [NIST 800-162 ABAC](https://csrc.nist.gov/pubs/sp/800/162/upd2/final)

| Ver. | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-11 | Aplicaciones: catálogo `privilege_application` (16 en seed), modelo dominio-como-app y zona→app; brechas AP1 integración real vía biedata, AP2 zone_application_map, AP3 átomos D1 generativos. |
