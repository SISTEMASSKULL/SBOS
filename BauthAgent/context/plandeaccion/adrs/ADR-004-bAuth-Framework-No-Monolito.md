# ADR-004 — bAuth como Framework Orquestador, No como Engine Monolítico

**Estado:** Aceptado · **Fecha:** 2026-06-20

---

## Contexto

Un sistema de autenticación puede construirse como monolito (un solo proceso que hace todo) o como framework que orquesta motores especializados. bAuth debe sincronizar Keycloak (Java), Tryton (Python), OAuth2-Proxy (Go), y NEXUS (Go) — todos con APIs, protocolos y modelos de datos diferentes.

## Decisión

**bAuth es un framework que implementa el patrón "Director de Orquesta".** No autentica usuarios directamente. En cambio, sincroniza, configura y orquesta 4+ motores especializados:

- **KeycloakEngine**: Admin REST API → realms, roles, users, auth flows, composite roles
- **TrytonEngine**: JSON-RPC → grupos, ir.model.access, ir.rule (5 capas enforcement)
- **OAuth2ProxyEngine**: archivos .cfg + SIGHUP → proxy de autenticación por aplicación
- **BhnexusEngine**: gRPC + WebSocket mTLS → puente físico-digital

Cada motor implementa el trait `AuthEngine` (Rust): `name()`, `covered_domains()`, `sync_role()`, `sync_user()`, `reconcile()`.

## Alternativas

| Alternativa | Problema |
|------------|---------|
| Monolito (todo en Rust) | Keycloak es Java — los SPIs deben ejecutarse en la JVM de KC. Tryton es Python — su API JSON-RPC es la única forma segura de interactuar. |
| Microservicios independientes | Complejidad operativa (N servicios, N CI/CD, N monitoreos). bAuth centraliza la orquestación. |
| bAuth como proxy transparente | Latencia añadida en cada request de autenticación. Solo necesario para ctx_id (Kong PEP). |

## Consecuencias

- 6 reglas del framework documentadas en BAUTH-ARQUITECTURA-FRAMEWORK.md
- Open/Closed: nuevos motores se agregan sin modificar el core (EngineRegistry)
- Degradación graciosa: si un motor falla, los demás siguen operando
- bauth_db es la única fuente de verdad — los motores son réplicas operacionales

## Referencias
- BAUTH-ARQUITECTURA-FRAMEWORK.md v1.0
- BAUTH-CONTRATO-SYMBIOSIS.md v1.0
- GoF Design Patterns: Strategy, Composite, SPI/Plugin
