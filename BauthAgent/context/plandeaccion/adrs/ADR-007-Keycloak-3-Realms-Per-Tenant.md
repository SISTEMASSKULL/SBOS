# ADR-007 — Keycloak: 3 Realms por Tenant — Aislamiento Total

**Estado:** Aceptado · **Fecha:** 2026-06-20

---

## Contexto

Keycloak puede operar en dos modelos multi-tenant:
1. **Un realm con grupos por tenant**: todos los usuarios en el mismo realm, separados por grupos y roles.
2. **Un realm por tenant**: cada empresa/organización tiene su propio realm aislado.

El SBOS maneja 3 categorías de usuarios con requisitos de seguridad muy diferentes: roles sistémicos (SU, SYS), empleados de empresas (BIZ), y clientes externos (EXT).

## Decisión

**3 realms por tenant con políticas de seguridad diferenciadas:**

| Realm | Usuarios | Password Policy | Token TTL | AAL |
|-------|----------|----------------|-----------|-----|
| `sbos-system` | SU, SYS_N1-N2, SYS_N4 (M2M) | `length(15)_argon2id_t5_m128` | 5-15 min | AAL2-3 |
| `tenant-{id}` | BIZ_N1-N5 (empleados) | `length(12)_argon2id_t3_m64` | 30-60 min | AAL1-2 |
| `tenant-{id}-ext` | EXT_N0 (clientes) | `length(8)_argon2id_t2_m32` | 24h | AAL1 |

## Alternativas

| Alternativa | Problema |
|------------|---------|
| 1 realm multi-tenant con grupos | Fuga de políticas: no se pueden aplicar políticas de contraseña diferentes por grupo en KC. Un cliente externo (AAL1) y un admin (AAL3) en el mismo realm comparten políticas. |
| 1 realm por tenant (sin sbos-system) | Roles sistémicos mezclados con roles de negocio. SU de SBOS en el mismo realm que empleados de ACME — inaceptable. |
| 1 realm por tipo de usuario (3 totales) | Todos los tenants comparten realm de clientes. Aislamiento insuficiente entre empresas. |

## Consecuencias

- Aislamiento total: un cliente de ACME no puede autenticarse contra el realm de EMPRESA-X
- Políticas de contraseña y token TTL específicas por categoría de usuario
- bAuth gestiona realms via Keycloak Admin REST API (B12)
- Cada tenant tiene 2 realms (tenant-{id} + tenant-{id}-ext) creados durante el alta (Saga Tenant B19.T14)

## Referencias
- Keycloak 26.6.2 Server Administration Guide
- BAUTH-CONTRATO-SYMBIOSIS.md v1.0
- BOS_V8 §4 (Keycloak Architecture)
