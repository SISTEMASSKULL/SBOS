# ADR-023 — Keycloak como Único Proveedor de Identidad

**Estado:** Aceptado  
**Fecha:** 2026-06-13  
**Origen:** §18 Reglas Inquebrantables — Regla 1 del Master v2.1  
**Relacionado:** ADR-006 (RBAC delegado), ADR-021 (18 estados ficha), DAEMON-BAUTH

---

## Contexto y problema

El SBOS necesita un único sistema de gestión de identidades para:
- Autenticar usuarios en todos los tenants
- Emitir tokens JWT con claims estandarizados (incluyendo `bitmask`)
- Gestionar el ciclo de vida de realms por tenant
- Soportar los 4 niveles de LoA (RFC 9470 Step-Up)
- Ejecutar los 5 SPIs custom de bAuth

Sin un único IdP, la autenticación se fragmenta: cada aplicación tendría su propia lógica de login, lo que rompe el BitMask 64-bit centralizado y hace imposible el Context Plane unificado.

## La Decisión

**Keycloak 26.6.2 (ADR-017) es el único proveedor de identidad del SBOS. Sin excepciones.**

```
PERMITIDO:
  ✅ Keycloak 26.6.2 (versión canónica ADR-017)
  ✅ Realm por tenant (aislamiento)
  ✅ 5 SPIs custom de bAuth (Java 17)
  ✅ OIDC / OAuth2 / WebAuthn / Passkey
  ✅ FAPI 2.0 + DPoP para operaciones financieras

VETADO:
  ❌ Auth0, Okta, Firebase Authentication
  ❌ Implementación propia de login (JWT propio)
  ❌ LDAP directo sin pasar por Keycloak
  ❌ Cualquier segundo IdP en paralelo
```

## Consecuencias

**Positivas:**
- BitMask 64-bit centralizado en un solo lugar (bAuth evalúa claims del token KC)
- Un solo punto de revocación de sesiones
- Context Plane posible: `context.promoted` solo ocurre cuando KC emite el JWT
- Cumple NIST SP 800-207 (Policy Administrator único)

**Negativas/Riesgos:**
- Keycloak es una dependencia crítica: si KC cae, nadie se autentica
- Mitigación: Keycloak HA (mínimo 2 nodos), health check en bos, ficha KC con 18 estados

## Reglas de aplicación

1. Ningún daemon ni ficha implementa su propia lógica de autenticación
2. Toda ficha que requiera autenticación de usuarios usa OIDC contra el realm de su tenant
3. bAuth es el único intermediario entre KC y las aplicaciones — nunca acceso directo a la Admin API de KC desde daemons
4. El bos gestiona los realms vía bAuth (ADR-022: sin intervención manual)

## Normas relacionadas

- SBOS-021-DAEMON-BAUTH (doctrina completa)
- ISO/IEC 27001:2022 A.9.2 (gestión de identidades)
- NIST SP 800-63B (niveles de aseguramiento LoA)
- FAPI 2.0 (operaciones financieras de alto valor)
