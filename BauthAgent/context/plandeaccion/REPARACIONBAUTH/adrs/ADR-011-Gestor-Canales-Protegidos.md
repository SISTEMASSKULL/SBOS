# ADR-011 — Centralización del Transporte en un Gestor de Canales Protegidos

**Estado:** Aceptado · **Fecha:** 2026-07-11 · **Autor:** bauth-developer
**Relacionado:** ADR-020 (Interface Dual — el entrante ya centralizado) · SBOS-050 (puertos)
**Contrato:** PLT-17 (A.43) · **Manual:** 2.12 (Canales Protegidos)

---

## Contexto

El control de las puertas de comunicación de bAuth está **disperso** (verificado por grep,
2026-07-11): HTTP saliente (`reqwest`) en 10+ archivos, TLS/cifrado en 10+, gRPC (`tonic`) en 3,
y **ningún módulo único de transporte** (`src/transport/` no existe). Cada módulo que necesita
comunicarse abre su propia conexión con su propia configuración de cifrado, verificación del par
y timeouts.

NIST SP 800-63B define **«authenticated protected channel»** (canal cifrado con criptografía
aprobada donde el iniciador autenticó al receptor) y **exige** que TODO el proceso de
autenticación ocurra sobre él, con mTLS entre *verifier* y *CSP*. Con el control disperso, es
**imposible garantizar de forma auditable** que todos los canales cumplen ese requisito — un solo
cliente mal configurado es un incumplimiento silencioso.

## Decisión

**Centralizar el gobierno de TODO canal de comunicación (entrante y saliente) en un subsistema
único: el Gestor de Canales Protegidos (`src/transport/`).** Ningún módulo de bAuth abre una
conexión por su cuenta: **solicita un canal al gestor**, que lo establece ya protegido según la
política declarativa del canal (cifrado aprobado, mTLS donde la norma lo exige, verificación del
par, red, resiliencia, observabilidad) o lo **rechaza** (fail-closed).

El nombre deriva del término normativo (NIST 800-63B «authenticated protected channel»), no de
criterio de diseño.

## Alternativas consideradas

| Alternativa | Rechazo |
|-------------|---------|
| **Seguir disperso** (cada módulo su TLS) | Incumple NIST 800-63B de forma inverificable; un fallo silencioso rompe «protected channel». |
| **Service mesh + SPIFFE/SPIRE (sidecar)** | Asume K8s/pods; bAuth es systemd soberano (SBOS). El sidecar rompería la soberanía y la superficie mínima. Se adopta la IDEA (mTLS/observabilidad centralizados) sin el sidecar. |
| **Biblioteca compartida de cliente HTTP** | Resuelve el saliente HTTP pero no unifica gRPC/socket ni el entrante ni la auditoría de canal — media solución. |

## Consecuencias

**Positivas:**
- «Authenticated protected channel» (NIST 800-63B) se vuelve **verificable en un punto** — auditable ante NIST/FAPI.
- mTLS uniforme (RFC 8705) donde la norma lo exige (verifier↔CSP, bóveda, cliente confidencial).
- Cifrado aprobado (TLS 1.3 / FIPS 140-3) garantizado en cada canal, no por convención.
- Habilita mTLS-bound tokens (AM-11), SPIFFE (PLT-08) y la política D7-Red desde un solo lugar.
- Observabilidad y auditoría de canal (apertura/cierre/fallo) — hoy imposible.

**Negativas / costes:**
- Refactor: los 20+ puntos que hoy abren conexiones deben migrar a solicitar canal al gestor (progresivo, sin romper).
- Un punto único es también un punto crítico — debe ser robusto y fail-closed.

**Riesgos mitigados:**
- Migración progresiva: el gestor coexiste con los clientes actuales; se migran canal por canal con evidencia.
- Soberanía preservada: es un plano interno del daemon, no un sidecar externo.

## Referencias
- NIST SP 800-63B (authenticated protected channel) · NIST 800-63C · RFC 8446 (TLS 1.3) · RFC 8705 (OAuth mTLS) · RFC 5280 (X.509) · NIST 800-207 (PEP) · FIPS 140-3
- Manual 2.12 (Canales Protegidos) · A.11 (SBOS-054) · A.16 (protocolos) · A.43 §PLT-17 · ADR-020 (Interface Dual)

*ADR-011 · bAuth Identity Core v3.0 · 2026-07-11*
