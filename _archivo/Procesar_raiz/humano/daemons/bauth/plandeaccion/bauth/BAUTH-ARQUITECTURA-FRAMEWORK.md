# BAUTH-ARQUITECTURA-FRAMEWORK — bAuth como Framework de Autenticación
## El patrón Framework ↔ Engine · Validado contra patrones de la industria
### v1.0 · 2026-06-19 · SKULL · BitMask Dual Jun 2026

---

> ⚠️ **CORRECCIÓN BITMASK — JUNIO 2026:** Las referencias al modelo BitMask (SAM-128, "2 capas", "BitmaskBundle") en este documento corresponden al diseño anterior. El modelo actual es el **BitMask Dual**: `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md`. Para desarrollo, consultar los manuales actualizados.

## 1. El Concepto

> **bAuth NO es un motor de autenticación. bAuth es el FRAMEWORK que ORQUESTA**
> **múltiples motores de autenticación especializados.**
>
> Como un director de orquesta no toca ningún instrumento pero hace que todos suenen
> en armonía, bAuth no autentica usuarios directamente — sincroniza, configura y
> orquesta los motores que sí lo hacen.

```
┌─────────────────────────────────────────────────────────────────┐
│                         bAuth (Framework)                        │
│                    "El Director de Orquesta"                     │
│                                                                  │
│  EngineRegistry:                                                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │ Keycloak │ │  Tryton  │ │OAuth2-Pxy│ │ bhnexus  │  ...más   │
│  │  Engine  │ │  Engine  │ │  Engine  │ │  Engine  │           │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘           │
│       │            │            │            │                   │
│       ▼            ▼            ▼            ▼                   │
│  OAuth2/OIDC   Reglas de    HTTP Gateway  Acceso Físico         │
│  SAML/WebAuthn negocio 5    JWT validate  OSDP/QR/NFC           │
│  15 métodos    capas        Rate limiting Hardware              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Validación contra Patrones de la Industria

### 2.1 Composite Provider Selection (Helidon Security)

**Fuente:** [Helidon Security](https://helidon.io/docs/latest/apidocs/io.helidon.security/io/helidon/security/package-summary.html)

Oracle Helidon implementa exactamente este patrón:
- **`Security` & `SecurityContext`** como orquestador principal
- **`NamedProvider<T extends SecurityProvider>`** envuelve cada IdP
- **Política COMPOSITE** para seleccionar entre múltiples proveedores

```yaml
# Helidon — el equivalente de bAuth:
security:
  provider-policy:
    type: "COMPOSITE"       # ← bAuth EngineRegistry
    authentication:
      - name: "keycloak"     # ← KeycloakEngine
      - name: "tryton"       # ← TrytonEngine
      - name: "oauth2-proxy" # ← OAuth2ProxyEngine
```

**Convergencia con bAuth:** Helidon confirma que el patrón de "orquestador + proveedores múltiples" es el estándar de la industria para sistemas de identidad empresariales.

### 2.2 Pluggable Authentication SPI (Apache Doris)

**Fuente:** [Apache Doris Pluggable Auth](https://doris.incubator.apache.org/zh-CN/docs/4.x/key-features/pluggable-auth)

Apache Doris separa identidad de política con dos interfaces SPI independientes:
- **`Authenticator`** — interfaz para backends de autenticación (LDAP, OIDC, JWT, custom)
- **`CatalogAccessController`** — interfaz para autorización (RBAC, Apache Ranger)
- **Modo Chain** — múltiples authenticators en secuencia, fallback automático

```java
// Apache Doris — equivalente a AuthEngine trait de bAuth:
public interface Authenticator {
    boolean authenticate(String user, String password);
    String getName();
}
```

**Convergencia con bAuth:** El trait `AuthEngine` de bAuth sigue exactamente este patrón: cada motor implementa una interfaz común, y el framework itera sobre ellos.

### 2.3 Federation Broker & Identity Orchestration (Duende IdentityServer)

**Fuente:** [Duende Software](https://duendesoftware.com/use-case-federation-broker-identity-orchestration)

Duende IdentityServer (.NET) es el equivalente comercial más cercano a bAuth:
- **Federation Gateway** — punto central entre múltiples IdPs upstream
- **Protocol Bridging** — convierte cualquier token entrante en un OIDC token consistente
- **Token Normalization** — claims de diferentes IdPs → formato unificado
- **Tenant-specific orchestration** — lógica de negocio por tenant

```
Duende (bAuth) ←→ Azure AD (KC) ←→ LDAP (Tryton) ←→ SaaS (OAuth2-Proxy)
```

**Convergencia con bAuth:** bAuth es el Federation Gateway del SBOS. Normaliza BitmaskBundle en claims JWT independientemente del motor que autenticó al usuario.

### 2.4 Identity Control Plane (ArXiv 2504.17759)

**Fuente:** [Identity Control Plane Paper](https://ar5iv.labs.arxiv.org/html/2504.17759)

Paper académico de 2025 que propone exactamente la arquitectura de bAuth:
- **Unified Identity Plane** — integra identidad humana, de workload y de automatización
- **SPIFFE + OIDC/SAML** — múltiples fuentes de identidad unificadas
- **ABAC Policy Engines** — OPA, Cedar como backends de política
- **Real-time enforcement + Post-action audit**

**Convergencia con bAuth:** bAuth es el Identity Control Plane del SBOS. Los motores (KC, Tryton, OAuth2-Proxy, bhnexus) son las fuentes de identidad. El DomainEvaluator es el ABAC engine.

---

## 3. Los 5 Patrones que bAuth Implementa

| # | Patrón | Fuente Industria | Implementación en bAuth |
|---|--------|-----------------|------------------------|
| 1 | **Strategy Pattern** | GoF Design Patterns | `trait AuthEngine` — cada motor implementa `sync_role()`, `sync_user()`, `reconcile()` |
| 2 | **Composite Provider** | Helidon Security | `EngineRegistry` — itera sobre todos los motores registrados |
| 3 | **SPI / Plugin Discovery** | Apache Doris, Java SPI | `register_engine(Box<dyn AuthEngine>)` — nuevo motor = 1 llamada |
| 4 | **Federation Gateway** | Duende IdentityServer | bAuth normaliza tokens de KC, Tryton, OAuth2-Proxy → JWT con BitmaskBundle |
| 5 | **Identity Control Plane** | ArXiv 2504.17759 | bAuth orquesta identidad humana (KC), de negocio (Tryton), de red (OAuth2-Proxy), física (bhnexus) |

---

## 4. Los Motores de Autenticación (Engines)

Cada motor implementa `AuthEngine` y declara qué dominios cubre:

| Motor | Cubre | Tipo | Protocolo | Estado |
|-------|-------|------|-----------|--------|
| **KeycloakEngine** | Logical, Biometric, Temporal | IdP | REST Admin API | 🔴 B12 |
| **TrytonEngine** | Logical, Financial | ERP | XML-RPC | 🔴 B13 |
| **OAuth2ProxyEngine** | Network, Logical | Gateway | Config file + SIGHUP | 🔴 B14 |
| **BhnexusEngine** | Physical | Puente Físico | Unix socket RPC | 🔴 B15 |
| *(futuro)* BiometricEngine | Biometric | Biométrico | gRPC | 🔮 |
| *(futuro)* PQCEngine | Network | Post-Quantum | REST | 🔮 |

---

## 5. Reglas del Framework

| # | Regla |
|---|-------|
| R1 | Ningún motor se consulta directamente — todo pasa por bAuth |
| R2 | Agregar un motor NO modifica los existentes (Open/Closed) |
| R3 | Cada motor declara `covered_domains()` — bAuth sabe qué motor cubre qué |
| R4 | Si un dominio no está cubierto → se agrega un motor que lo cubra |
| R5 | bAuth normaliza la salida de todos los motores → JWT con BitmaskBundle |
| R6 | El orden de los motores NO importa — son independientes |

---
*BAUTH-ARQUITECTURA-FRAMEWORK v1.0 · 2026-06-19 · SKULL*
