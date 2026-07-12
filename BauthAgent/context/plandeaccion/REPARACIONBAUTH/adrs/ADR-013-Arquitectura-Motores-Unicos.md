# ADR-013 — Arquitectura de Motores Únicos (modularización de bAuth)

**Estado:** Aceptado · **Fecha:** 2026-07-11 · **Autor:** bauth-developer
**Relacionado:** ADR-004 (framework no monolito) · ADR-009 (BitMask Dual) · ADR-011 (Gestor de Canales) · ADR-012 (Módulo Criptográfico)
**Generaliza:** ADR-011 y ADR-012 no son decisiones sueltas — son **instancias** de este principio.

---

## Contexto

bAuth tiene **capacidades transversales** (autenticar, autorizar, cifrar, transportar, calcular
privilegios) que hoy están, en distinto grado, **dispersas** por el código: la criptografía en 34+
archivos (ADR-012), el transporte en 20+ (ADR-011), y los evaluadores de política repartidos entre
`src/bitmask/registry.rs` y `src/domain/*.rs` con un **fail-open** (verificado, A.21). Cuando algo
falla o cambia una regla, hay que tocar **muchos puntos** — frágil, inauditable, difícil de probar.

El humano fijó el principio rector de la reparación: **si algo falla, o cambian las políticas o los
métodos, debe arreglarse en UN solo punto.** Eso exige modularizar bAuth **por motores**.

## Decisión

**Toda capacidad transversal de bAuth se modela como UN motor único.** Un motor cumple, sin
excepción, el mismo patrón:

1. **Un trait** — el contrato uniforme de la capacidad (`AuthMethod`, `DomainEvaluator`, …).
2. **Un registro** — el punto único donde se registran las implementaciones y se despacha
   (`MethodRegistry`, `DomainRegistry`, …). bAuth **acude al registro**, no a la implementación.
3. **Una frontera** — un módulo propio (`src/<motor>/`) que contiene TODA la capacidad. Nada de esa
   capacidad vive fuera de su frontera.
4. **Fail-closed** — ante lo desconocido o el error, el motor **niega/aborta**, nunca concede.
5. **Punto único de cambio** — modificar la capacidad = tocar **un** motor; el resto del sistema no
   se entera (habla con el trait, no con la implementación).

**Regla dura:** si una lógica de una capacidad vive fuera de su motor (una primitiva cripto suelta,
un evaluador de política en un handler, un cliente HTTP ad-hoc), es un **defecto a reparar**.

## El catálogo de motores núcleo (estado verificado 2026-07-11)

| Motor | Capacidad | Contrato (trait + registro) | Frontera | Estado |
|-------|-----------|------------------------------|----------|:------:|
| **BitMask** | privilegios (RBAC/DAG) | motor algebraico + closure | `src/bitmask/` | ✅ uno solo, robusto (2.640 líneas) |
| **Métodos** | autenticación (los 47) | `AuthMethod` + `MethodRegistry` | `src/domain/auth_methods/` | 🔄 uno; 9/18 métodos (A.44) |
| **Políticas (PDP)** | autorización / decisión | `DomainEvaluator` + `DomainRegistry` + `PolicyEngine` | ⚠️ **partido** (`bitmask/registry.rs` + `domain/policy*.rs`) | 🔄 fragmentado + **fail-open** (BA3/A.21) |
| **Canales (RPC)** | transporte entrante/saliente | (fachada del gestor) | `src/transport/` (no existe) | ⬜ PLT-17 (ADR-011) |
| **Criptográfico** | cifrado / firma de primitivas | `ModuloCriptografico` | `src/crypto/` (no existe) | ⬜ CORE-11 (ADR-012) |
| **Firma** | firma legal de documentos | doble motor (interno/externo) | `src/domain/signature*` | 🔄 interno Ed25519 ✅; externo ADSIB ⬜ (A.08) |
| **Auditoría** | emisión de eventos WORM | emisor único | `src/audit/` | 🔄 esqueleto; sin cablear (BA11/A.27) |

## Qué merece ser un motor — el criterio (industria + normas)

Investigación 2026 (NIST 800-162 ABAC · NIST 800-63B · OASIS XACML 3.0 · Zero Trust · Ping / MS Entra
Verified ID). **Regla: un motor por CAPACIDAD (verbo), no por tipo de dato ni de dispositivo.**
*Autenticar, autorizar, cifrar, transportar, firmar, auditar, calcular privilegios* son verbos → son
motores. Una **chapa**, una **huella** o una **ubicación** no son verbos → **no** son motores. Los
tipos y dispositivos se modelan un nivel más abajo, sin multiplicar motores:

| Concepto | Qué es | Dónde vive |
|---|---|---|
| **Familia** (dentro de un motor) | especialización de una capacidad | **Motor de Métodos** → familias: *software* (pwd/TOTP/WebAuthn) · *hardware-físico* (smart card/NFC/PIV/biometría, **adquiridos por el edge**) · *federación* (SAML/OIDC) · *descentralizada* (DID/VC) |
| **Dominio** (evaluador) | una dimensión de decisión | **Motor de Políticas** → los 12 dominios: lógico, físico, **geoespacial (D7)**, financiero, **blockchain (D12)**, contexto… |
| **PIP** (fuente de atributos) | provee datos al PDP, **no decide** | **ubicación/geo**, riesgo, device posture, HR/directorio → alimentan el Motor de Políticas |

**Las tres dudas resueltas con este criterio:**
- **Métodos de hardware (chapas, lectores, face):** *no* un motor aparte. La distinción industria
  hardware/software está en la **adquisición/middleware**, no en la verificación. El **edge** (proxy de
  hardware) adquiere la prueba física; el **Motor de Métodos único** la verifica como una **familia
  hardware** bajo el mismo `AuthMethod`. Se especializa sin romper el punto único.
- **Geoespacial:** *no* un motor de autenticación. La ubicación es un **atributo de entorno** (ABAC):
  un **evaluador de dominio (D7) + un PIP** dentro del Motor de Políticas, para decisiones adaptativas
  (risk-based). No prueba identidad; **condiciona** el acceso.
- **Blockchain:** dos roles, ninguno un motor nuevo: (a) **dominio D12** del Motor de Políticas
  (anclaje/notarización — `blockchain.rs`/`merkle.rs`, ADR-D12); (b) **familia descentralizada (DID/VC)**
  del Motor de Métodos (A.44 categoría F). La industria trata las Verifiable Credentials como parte del
  IAM, no como motor separado.

**Conclusión:** la estructura robusta **no crece en número de motores** — crece en **familias**,
**dominios** y **PIP** dentro de los 7 motores de capacidad. Eso es lo que la mantiene sólida.

## Alternativas consideradas

| Alternativa | Rechazo |
|-------------|---------|
| **Seguir con lógica dispersa** | Cambiar una regla toca N puntos; inauditable; fail-open silencioso. Es el problema, no la solución. |
| **Un único mega-motor monolítico** | Viola ADR-004 (no monolito) y DOC-SBOS-001 N3 (módulos ≤ 200 líneas). Cada capacidad es su **propia** frontera, no una masa. |
| **Microservicios por capacidad** | bAuth es un daemon soberano systemd (SBOS); partirlo rompe la soberanía y la latencia. Los motores son **módulos internos**, no procesos. |

## Consecuencias

**Positivas:**
- **Un punto de cambio por capacidad:** cambian los métodos → se toca el motor de métodos; cambian
  las políticas → el motor de políticas. El resto del sistema no se modifica.
- **Auditable y testeable:** cada motor se prueba contra su trait de forma aislada (fail-closed verificable).
- **Estructura profesional:** bAuth queda como un IAM sólido — motores con fronteras claras, como
  los productos de referencia del sector (PrivilegeEngine, PolicyEngine, AuthN engine).
- **Convergencia de la reparación:** ADR-011 (Canales) y ADR-012 (Cripto) dejan de ser piezas
  sueltas — son motores de este catálogo; el plan de reparación es «completar el catálogo».

**Negativas / costes:**
- Refactor progresivo: consolidar el motor de políticas (unir las dos mitades + fail-closed),
  extraer `src/crypto/` y `src/transport/`. Se hace motor por motor, con evidencia, sin romper.

## Plan de convergencia (orden)
1. **Políticas:** fail-closed (BA3 — `None ⇒ denegado`, 1 línea + test) → luego unificar la frontera.
2. **Cripto** (`src/crypto/`, CORE-11) y **Canales** (`src/transport/`, PLT-17): extraer lo disperso.
3. **Métodos:** completar 9 → 18 (A.44).
4. **Firma externa** (ADSIB) y **Auditoría** (cablear el emisor).

## Referencias
- ADR-004 (framework no monolito) · ADR-009 (BitMask) · ADR-011 (Canales) · ADR-012 (Cripto)
- Patrones: Strategy + Registry · Bounded Context (DDD) · Secure-by-default / fail-closed (OWASP, NIST 800-207 PDP/PEP) · OASIS XACML 3.0
- A.44 (motor de métodos) · A.43 (mapa IAM Enterprise) · A.41 §11 / A.42 (contratos BA) · DOC-SBOS-001 N3 (modularización)

*ADR-013 · bAuth Identity Core v3.0 · 2026-07-11*
