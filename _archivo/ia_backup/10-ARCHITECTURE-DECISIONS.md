# Decisiones de Arquitectura

**Generado por:** Compositor S-29 (reprocesamiento SBOS)
**Fecha:** 2026-05-18
**Proyecto:** SBOS
**Fuentes:** SBOS-006-ADR (v6), SBOS-BAUTH-DECISIONES-ARQUITECTURA-v1_0 (bauth), SBOS-048-ADR-CATALOG (v6)
**Jerarquia aplicada:** bauth > v6 > v5 > humano

## ADRs del proyecto SBOS

| ID | Titulo | Estado |
|---|---|---|
| ADR-001 | WAL de PostgreSQL como EventBus nativo | Aceptada |
| ADR-002 | Daemons soberanos como systemd fuera de K8s | Aceptada |
| ADR-003 | IAM Installer como daemon residente, no script | Aceptada |
| ADR-004 | Keycloak como unico proveedor de identidad | Aceptada |
| ADR-005 | PostgreSQL como unica BD relacional | Aceptada |
| ADR-006 | Veto de n8n -- bCompass como reemplazo | Aceptada |
| ADR-007 | Firma Ed25519 de artefactos del Release Plane | Aceptada |
| ADR-008 | Fichas como unidad atomica de despliegue | Aceptada |
| ADR-009 | Rust para CPU-bound, Go para I/O-bound | Aceptada |
| ADR-010 | Estrategia API Gateway -- Mantener Kong OSS 3.9.x LTS | Aceptada |

## Decisiones bAuth (bauth v5.0 -- PRECEDENCIA MAXIMA)

| # | Decision | Detalle |
|---|---|---|
| BAUTH-01 | bAuth es el sistema de identidad | Keycloak y Tryton son brazos. SBOS consulta bAuth, no KC |
| BAUTH-02 | Version Keycloak canonica: 26.6.1 | CVE-2026-4366 + CVE-2026-4633 corregidos |
| BAUTH-03 | BitmaskBundle 3xuint64, no SAM-128 monolítico | PhysicalDomainMask + LogicalDomainMask + FinancialDomainMask |
| BAUTH-04 | AND NOT para herencia, no XOR ni NAND | XOR eleva privilegios involuntarios. NAND puede dar ALL_PERMISSIONS |
| BAUTH-05 | SoD via Conflict Matrix | Evaluada ANTES de guardar RolTemplate. Estandar ISACA/ISO 27001 |
| BAUTH-06 | Jurisdiccion en deploy.yml, NO en RolTemplate | Correccion J1 del Plan Consolidado |
| BAUTH-07 | Compensacion: Opcion B (sin rollback KC) | Si Tryton falla, KC queda correcto, Tryton se reintenta |
| BAUTH-08 | Una instancia bAuth por host, multi-realm | Namespacing por tenant_id en PostgreSQL y Redis |
| BAUTH-09 | Socket solo para bhnexus | Nunca saltar bhnexus. Otros daemons consultan via REST |
| BAUTH-10 | Redis recomendado en prod, in-memory en dev | Trade-off durabilidad vs complejidad |
| BAUTH-11 | Reconcile loop cada 60s, configurable por realm | Minimo global 30s para evitar sobrecarga multi-tenant |
| BAUTH-12 | WORM enforcement con RULES, no triggers | BIGSERIAL + RLS Rules NO UPDATE/DELETE |
| BAUTH-13 | Cliente SMTP en realm KC, no en bAuth | Separacion de responsabilidades |
| BAUTH-14 | Break-glass obligatorio | Segundo sbos-admin registrado. Alerta CRITICAL al usarlo |
| BAUTH-15 | Una clave HMAC por tenant en Vault | Rotacion cada 90 dias. No clave por usuario |

## Proceso ARB (Architecture Review Board)

- CTO (obligatorio) + Arquitecto Lead (obligatorio) + 1 representante tecnico de dominio (rotativo)
- Quorum: 3 miembros
- RFC como GitHub Issue con label architecture-decision
- 5 dias habiles para comentarios
- Decision en reunion mensual ARB

## Cuando se requiere ADR
- Afecta principios inquebrantables (Keycloak, PostgreSQL, licencias)
- Modifica protocolo WAL o slots de replicacion
- Introduce dependencias en daemons soberanos
- Cambia canal de distribucion
- Impacta dataserver o identityserver
