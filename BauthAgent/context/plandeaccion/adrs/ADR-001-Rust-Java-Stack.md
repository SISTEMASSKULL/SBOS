# ADR-001 — Elección del Stack Tecnológico: Rust 1.85+ + Java 21

**Estado:** Propuesto · **Fecha:** 2026-06-20 · **Autor:** sbos-coordinador

---

## Contexto

bAuth es el daemon de identidad del SBOS. Necesita:
1. Alta concurrencia para sync loop (60s reconcile con KC+Tryton)
2. Comunicación con Keycloak vía Admin REST API (HTTP)
3. Comunicación con Tryton vía JSON-RPC (TCP)
4. Implementar 5 SPIs Java para Keycloak (Authenticator, Condition, Validator)
5. Binario estático para distribución en bootstrap (sin runtime dependencies)

## Decisión

**Rust 1.85+ (tokio, MUSL, LTO) para el daemon core + Java 21 para los 5 SPIs de Keycloak.**

- **Rust:** daemon principal (bauth.service), CLI (bauthctl), servidor JSON-RPC, engine registry, PrivilegeEngine, sync loop, cache Redis
- **Java 21:** 5 SPIs de Keycloak (RolTemporalAuthenticator, RolGeoAuthenticator, RolRoleValidityAuthenticator, RolUserConfiguredCondition, RolStepUpCondition)

## Alternativas Consideradas

| Alternativa | Pros | Contras | Rechazo |
|------------|------|--------|---------|
| **Go 1.22+** (100% Go) | Stack único, GC rápido, compilación cruzada | SPIs Keycloak requieren Java — puente gRPC/FFI añade complejidad y latencia | Go para I/O-bound; Rust elegido por zero-cost abstractions y seguridad de memoria |
| **Python 3.14** | Rápido prototipado, bibliotecas | GIL limita concurrencia, sin binario estático nativo, rendimiento 10x menor que Rust en crypto | Descartado para producción |
| **100% Java 21** | Integración nativa con KC SPIs | Consumo memoria (JVM), binario no estático, startup lento | Java solo para SPIs — el core Rust aprovecha MUSL+LTO para <15MB binario estático |

## Consecuencias

**Positivas:**
- Binario Rust MUSL estático < 15MB, sin dependencias runtime
- Zero-cost abstractions: evaluación BitMask en < 0.5ns
- Seguridad de memoria sin GC (ownership model)
- Java 21 para SPIs = integración nativa con KC sin puentes ni serialización adicional

**Negativas:**
- Dos lenguajes = dos toolchains, dos pipelines CI
- Equipo necesita competencia en Rust + Java
- Comunicación entre Rust y SPIs vía KC Admin REST API (no directa)

**Riesgos mitigados:**
- Curva de aprendizaje Rust: mitigada con documentación exhaustiva y patrones establecidos (tokio, serde, tonic)
- Divergencia Rust/Java: mitigada con contratos de API documentados (JSON Schema, gRPC proto)

## Referencias
- [Rust Programming Language](https://www.rust-lang.org/)
- [Tokio — Async Runtime](https://tokio.rs/)
- [Keycloak SPI Reference](https://www.keycloak.org/docs/latest/server_development/)
- [MUSL libc](https://musl.libc.org/)
