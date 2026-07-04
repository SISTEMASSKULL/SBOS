# PLAN-BAUTHDEV — Plataforma de Desarrollo e Integración bAuth

**Versión:** 3.0.0 · **Fecha:** 2026-06-28 · **Autor:** bos-developer
**Proyecto:** bAuthDEV — Plataforma para que desarrolladores integren bAuth como proveedor de autenticación vía JSON-RPC 2.0
**Stack:** Flutter 3.44+ + Material 3 · Dart ≥3.12
**Plataformas:** Windows, Linux, macOS (desktop)
**Inspiración:** Postman (testeo) + Stripe Dashboard (experiencia dev) + BuildBear (playground blockchain) + Documentación interactiva
**Carpeta:** `BauthAgent/src/rpc-tester/`

---

## 0. PROPÓSITO — El puente entre el desarrollador y bAuth

### 0.1 La arquitectura real: dos mundos separados

```
┌──────────────────────────────────────────────────────────────────────┐
│  🌍 APLICACIÓN DEL DESARROLLADOR         🌍 SERVIDOR BAUTH (SBOS)    │
│  (su código, su frontend,                (nuestra infraestructura,   │
│   su negocio, su base de datos)           nuestro motor de auth)      │
│                                                                       │
│  ┌─────────────────────────┐           ┌──────────────────────────┐  │
│  │  App del desarrollador   │           │  bAuth — Identity Control │  │
│  │  ─────────────────────  │  JSON-RPC │  Plane                    │  │
│  │                          │           │                          │  │
│  │  👤 Usuario hace click  │◄─────────►│  🔒 Evalúa acceso        │  │
│  │    en "Emitir Factura"  │  "¿Puede  │  • BitMask Dual <0.5ns   │  │
│  │                          │   este    │  • 12 dominios D1-D12    │  │
│  │  ⏳ Espera...            │  usuario  │  • PolicyChain           │  │
│  │                          │  ejecutar │  • Conflict Matrix SoD   │  │
│  │  ✅ SI bAuth dice SÍ →  │  este     │  • DAG herencia           │  │
│  │     ejecuta el proceso   │  átomo?"  │                          │  │
│  │                          │           │  ← {"verdict": "allow"}   │  │
│  │  ❌ SI bAuth dice NO →  │           │     o                     │  │
│  │     muestra error        │           │  ← {"verdict": "deny"}    │  │
│  └─────────────────────────┘           └──────────────────────────┘  │
│                                                                       │
│  EL LOGIN TAMBIÉN OCURRE EN BAUTH:                                    │
│  ┌─────────────────────────┐           ┌──────────────────────────┐  │
│  │  Pantalla de login       │           │  bAuth recibe            │  │
│  │  del desarrollador       │  JSON-RPC │  credenciales, las       │  │
│  │                          │◄─────────►│  enruta a Keycloak/      │  │
│  │  Usuario: [........]     │           │  Vault, valida MFA,      │  │
│  │  Password: [........]    │           │  aplica políticas,        │  │
│  │                          │           │  emite JWT Ed25519        │  │
│  │  ← Recibe JWT para la   │           │                          │  │
│  │    sesión del usuario    │           │                          │  │
│  └─────────────────────────┘           └──────────────────────────┘  │
│                                                                       │
│  🏢 CUANDO SE DESPLIEGA EN UNA EMPRESA:                               │
│  • El sistema ES del desarrollador (él lo construyó, él lo vende)    │
│  • La autenticación LA HACE bAuth (nuestro servidor)                  │
│  • CADA CLICK en un botón SE VALIDA EN BAUTH (no en la app)           │
│  • El desarrollador NUNCA ve una contraseña                           │
│  • El desarrollador NUNCA almacena un token — bAuth lo emite y rota   │
│  • El desarrollador SOLO pregunta: "¿puede este usuario hacer esto?"  │
└──────────────────────────────────────────────────────────────────────┘
```

### 0.2 El modelo de negocio: De desarrollador a distribuidor de bAuth

**El desarrollador no solo integra bAuth — se convierte en vendedor de autenticación.**
bAuthDEV lo acompaña en dos fases:

```
╔══════════════════════════════════════════════════════════════════════╗
║  FASE 1 — TRIAL GRATUITO (bAuthDEV + tenant de prueba)              ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  🆓 Sin costo. El desarrollador descarga bAuthDEV y recibe:         ║
║                                                                      ║
║  ┌──────────────────────────────────────────────────────────────┐   ║
║  │  TENANT DE PRUEBA (limitado)                                  │   ║
║  │  ─────────────────────────────────────────────────────────── │   ║
║  │  • 3 roles máximo                                             │   ║
║  │  • 50 usuarios máximo                                          │   ║
║  │  • 3 dominios activos (D1, D3, D9)                            │   ║
║  │  • 1 empresa, 1 sucursal                                      │   ║
║  │  • Sin blockchain D12, sin firma ADSIB                         │   ║
║  │  • Tokens con marca "TRIAL" (no válidos en producción)        │   ║
║  │                                                                │   ║
║  │  OBJETIVO: Que el desarrollador aprenda, pruebe y confíe      │   ║
║  └──────────────────────────────────────────────────────────────┘   ║
║                                                                      ║
║  El desarrollador:                                                   ║
║  • Explora el catálogo de métodos                                    ║
║  • Personaliza sus primeros 3 roles basados en plantillas            ║
║  • Crea hasta 50 usuarios de prueba                                  ║
║  • Prueba tokens, login, evaluación de acceso                        ║
║  • Copia snippets y arma su integración                              ║
║  • NO puede salir a producción con este tenant                       ║
╚══════════════════════════════════════════════════════════════════════╝
                              │
                              │  "Mi app funciona. Necesito un plan."
                              ▼
╔══════════════════════════════════════════════════════════════════════╗
║  FASE 2 — CONTRATA PLAN (tenant de producción)                      ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  💰 El desarrollador contrata BASIC, PRO o ENTERPRISE               ║
║                                                                      ║
║  ┌──────────────────────────────────────────────────────────────┐   ║
║  │  TENANT DE PRODUCCIÓN (su propio espacio)                     │   ║
║  │  ─────────────────────────────────────────────────────────── │   ║
║  │                                                                │   ║
║  │  🏢 EMPRESAS (sus clientes)                                    │   ║
║  │  ├── Comercializadora del Valle S.A.                           │   ║
║  │  │   ├── 📍 Sucursal Central (La Paz)                         │   ║
║  │  │   ├── 📍 Sucursal Norte (El Alto)                          │   ║
║  │  │   └── 📍 Sucursal Sur (Oruro)                              │   ║
║  │  │                                                              │   ║
║  │  ├── Distribuidora Andina S.R.L.                               │   ║
║  │  │   ├── 📍 Sucursal Única (Cochabamba)                       │   ║
║  │  │                                                              │   ║
║  │  └── [➕ Agregar empresa]                                       │   ║
║  │                                                                │   ║
║  │  🔑 ROLES (personalizados por el desarrollador)                │   ║
║  │  ├── CAJERO_MI_APP (basado en CAJERO)                          │   ║
║  │  ├── SUPERVISOR_MI_APP (basado en SUPERVISOR)                  │   ║
║  │  └── [➕ Nuevo rol desde plantilla]                             │   ║
║  │                                                                │   ║
║  │  👤 USUARIOS (los empleados de sus empresas cliente)            │   ║
║  │  ├── juan.perez@comercializadora.com → CAJERO_MI_APP          │   ║
║  │  ├── maria.lopez@comercializadora.com → SUPERVISOR_MI_APP     │   ║
║  │  └── [➕ Agregar usuario]                                       │   ║
║  │                                                                │   ║
║  │  ⚙ CONTROL DE ctx_id (Context Plane SBOS-049)                  │   ║
║  │  • Cada sucursal tiene su propio contexto operativo            │   ║
║  │  • El desarrollador decide TTL, alcance y trazabilidad         │   ║
║  └──────────────────────────────────────────────────────────────┘   ║
║                                                                      ║
║  ┌──────────────────────────────────────────────────────────────┐   ║
║  │  PLANES DISPONIBLES                                            │   ║
║  │  ─────────────────────────────────────────────────────────── │   ║
║  │  Recurso          │ BASIC     │ PRO       │ ENTERPRISE       │   ║
║  │  ─────────────────┼───────────┼───────────┼─────────────────│   ║
║  │  Roles             │ 5         │ 25        │ Ilimitado        │   ║
║  │  Usuarios          │ 100       │ 1,000     │ 50,000+          │   ║
║  │  Empresas          │ 1         │ 10        │ Ilimitado        │   ║
║  │  Sucursales        │ 3         │ 50        │ Ilimitado        │   ║
║  │  Dominios          │ 3         │ 8         │ 12               │   ║
║  │  Blockchain D12    │ ❌        │ ✅         │ ✅               │   ║
║  │  Firma ADSIB       │ ❌        │ ❌        │ ✅               │   ║
║  │  Soporte           │ Comunidad │ Email     │ Dedicado         │   ║
║  │  Precio (mes)      │ $49       │ $199      │ A consultar      │   ║
║  └──────────────────────────────────────────────────────────────┘   ║
╚══════════════════════════════════════════════════════════════════════╝
```

### 0.3 El desarrollador como distribuidor de bAuth

```
┌──────────────────────────────────────────────────────────────────────┐
│                                                                       │
│   🏢 COMERCIALIZADORA DEL VALLE S.A. (empresa cliente)               │
│   │  El dueño compró el sistema de punto de venta al desarrollador  │
│   │  El dueño NO sabe qué es bAuth. Solo sabe que:                   │
│   │  • Sus empleados inician sesión con password + huella           │
│   │  • Cada empleado ve solo lo que debe ver                        │
│   │  • Nadie puede emitir facturas por más de $5,000 sin aprobación │
│   │  • El sistema nunca se cae                                       │
│   └───────────────────────────────────────────────────────────────── │
│                                                                       │
│   👨‍💻 DESARROLLADOR (dueño de la app)                                  │
│   │  Vendió su sistema a 12 empresas.                                │
│   │  Desde bAuthDEV administra:                                       │
│   │  • 12 empresas, 47 sucursales                                    │
│   │  • 18 roles personalizados                                       │
│   │  • 847 usuarios                                                   │
│   │  • 234,567 evaluaciones de acceso al mes                         │
│   │  TODO con una sola herramienta: bAuthDEV                         │
│   └───────────────────────────────────────────────────────────────── │
│                                                                       │
│   🛡️ SBOS (nosotros)                                                   │
│   │  Proveemos el motor de autenticación.                             │
│   │  • Servidores en VPS                                              │
│   │  • 12 dominios, BitMask, JWT, firma digital                      │
│   │  • Auditoría ISO 27001                                            │
│   │  • El desarrollador paga según el plan que contrata              │
│   │  • El desarrollador le cobra a sus empresas cliente              │
│   │  • Nosotros no atendemos a los usuarios finales                   │
│   └───────────────────────────────────────────────────────────────── │
└──────────────────────────────────────────────────────────────────────┘
```

### 0.4 Lo que el desarrollador ve en bAuthDEV (su tenant)

**El desarrollador NO accede a todo bAuth.** Tiene su propio tenant con
límites según su plan contratado. bAuthDEV es SU panel de administración
para SUS empresas, SUS sucursales, SUS roles, SUS usuarios.

| Sección de bAuthDEV | ¿Qué ve? | ¿Qué NO ve? |
|---------------------|----------|-------------|
| **Dashboard** | Métricas de SU tenant: usuarios activos, sesiones, evaluaciones | Métricas globales, otros tenants |
| **Empresas** | Sus empresas cliente, sucursales | Empresas de otros desarrolladores |
| **Roles** | Sus roles personalizados (hasta N según plan) | Roles de otros devs, catálogo global completo |
| **Usuarios** | Sus usuarios (empleados de sus clientes) | Usuarios de otros tenants |
| **Tokens** | JWT emitidos para SUS usuarios | Tokens de otros tenants |
| **ctx_id** | Contextos de SUS sucursales | Contextos de otros tenants |
| **Catálogo RPC** | Métodos JSON-RPC disponibles + snippets | Métodos administrativos del sistema |
| **Labs** | Token Lab, Blockchain Lab, Firma Lab | — |

### 0.5 ¿Quién lo usa?

| Fase | Usuario | Para qué |
|------|---------|----------|
| **TRIAL** | Desarrollador evaluando bAuth | Conecta bAuthDEV al daemon, explora métodos, personaliza 3 roles, crea 50 usuarios de prueba, copia snippets, prueba que su app funciona con bAuth |
| **TRIAL** | Empresa evaluando SBOS | Crea un tenant de prueba, arma roles para su negocio, verifica que bAuth cubre sus necesidades antes de contratar |
| **PRODUCCIÓN** | Desarrollador con plan activo | Administra SUS empresas cliente, SUS sucursales, SUS roles, SUS usuarios. Controla ctx_id por sucursal. Emite tokens de producción. |
| **PRODUCCIÓN** | Desarrollador-vendedor | Onboardea nuevas empresas cliente, crea sucursales, asigna roles a empleados, monitorea uso, factura a sus clientes |
| **PRODUCCIÓN** | Desarrollador frontend/mobile | Prueba login, recibe JWT de producción, integra WebAuthn/Passkey, QR, NFC para los empleados de sus empresas cliente |

**Nota:** Cada desarrollador ve SOLO su tenant — sus empresas, sus sucursales, sus roles, sus usuarios.
No tiene acceso al sistema completo ni a los tenants de otros desarrolladores.
Los límites dependen del plan contratado (BASIC/PRO/ENTERPRISE).

---

## 1. INVESTIGACIÓN DE MERCADO — Lo que existe y lo que NO

### 1.1 Herramientas REST (NO sirven para JSON-RPC nativo)

| Herramienta | Tipo | JSON-RPC nativo | Problema para bAuth |
|-------------|------|:---:|---------------------|
| **Postman** | Electron, REST-first | ❌ | Obliga a escribir JSON-RPC a mano en body. Sin WebSocket nativo. |
| **Insomnia** | Electron, REST+GraphQL+gRPC | ❌ | Soporta WebSocket pero sin autocompletado JSON-RPC. Sin catálogo de métodos. |
| **Hoppscotch** | Web PWA, multi-protocolo | ❌ | Lo mismo — body crudo, sin estructura JSON-RPC. |
| **Bruno** | Desktop, Git-native | ❌ | Colecciones en archivos `.bru`. Sin soporte JSON-RPC. |
| **Yaak** | Tauri+Rust, minimalista | ❌ | Del creador original de Insomnia. Ligero pero sin JSON-RPC. |

**Conclusión:** **Ninguna herramienta importante soporta JSON-RPC 2.0 como protocolo nativo.** Todas lo tratan como "REST con body JSON manual". No hay autocompletado de `method`, `params`, `id`, ni validación de respuesta.

### 1.2 Herramientas JSON-RPC (existentes pero limitadas)

| Herramienta | Tipo | Plataforma | Catálogo métodos | WebSocket |
|-------------|------|------------|:---:|:---:|
| **mcp-tester** | CLI Rust | Terminal | ✅ tools/list | ✅ |
| **Jaysonic** | CLI Node.js | Terminal | ✅ | ✅ |
| **KraiNode** | Web, blockchain RPC | Navegador | ❌ (manual) | ❌ HTTP |
| **BuildBear Playground** | Web, Ethereum RPC | Navegador | ✅ eth_* methods | ❌ HTTP |
| **Tatum Postman Workspace** | Colección Postman pre-armada | Postman | ✅ (60+ blockchains) | ❌ |

**Conclusión:** Las herramientas JSON-RPC existentes son **CLI (terminal) o web**. Ninguna es **desktop nativa con GUI**. Ninguna tiene **catálogo de métodos integrado con documentación en español**. Ninguna está diseñada para **desarrolladores integrando un sistema de identidad completo**.

### 1.3 Oportunidad

**bAuthDEV sería la PRIMERA herramienta desktop nativa del mercado que:**
- Trata JSON-RPC 2.0 como protocolo de primera clase (no como "REST con body raro")
- Incluye un catálogo completo de métodos con documentación, ejemplos y snippets
- Soporta WebSocket como transporte principal (no HTTP)
- Está diseñada específicamente para desarrolladores integrando autenticación
- Incluye testing de tokens JWT, firma digital Ed25519/RSA, blockchain anchors, Merkle proofs

### 1.4 ESTUDIO DE MERCADO — Autenticación como Servicio (AaaS)

#### Panorama competitivo 2026 — Precios reales

| Competidor | Tipo | Free Tier | Entry Paid | Enterprise | Open Source | Self-Host |
|-----------|------|-----------|------------|------------|:---:|:---:|
| **Auth0 (Okta)** | SaaS | 25K MAU | $35/mo (500 MAU) | Custom ($1,500+) | ❌ | ❌ |
| **Firebase Auth (Google)** | SaaS | 50K MAU | $250/mo (100K MAU) | $4,800/mo (1M MAU) | ❌ | ❌ |
| **Clerk** | SaaS | 50K MAU | $25/mo (Pro) | ~$5,500/mo (1M MAU) | ❌ | ❌ |
| **SuperTokens** | SaaS + Self | 5K MAU (managed) | $0 (self-host) | $0 + infra propia | ✅ | ✅ |
| **Okta Workforce** | SaaS | Sin free tier | $2-6/user/mo | $6-17/user/mo | ❌ | ❌ |
| **Keycloak** | Self-host | Ilimitado | $0 | $0 + infra propia | ✅ | ✅ |
| **Kinde** | SaaS | 7,500 MAU | $49/mo | Custom | ❌ | ❌ |
| **WorkOS** | SaaS | Sin free tier | $99/mo | Custom | ❌ | ❌ |
| **Stytch** | SaaS | 5K MAU | $0.02/MAU | Custom | ❌ | ❌ |
| **bAuth (SBOS)** | Desktop + Self | 50 usuarios trial | **$49/mo (BASIC)** | **$199/mo (PRO)** | ✅ | ✅ |

#### Comparativa de features — Lo que NADIE más tiene

| Capacidad | Auth0 | Clerk | Firebase | SuperTokens | Keycloak | **bAuth** |
|-----------|:---:|:---:|:---:|:---:|:---:|:---:|
| **Passkeys / WebAuthn** | ✅ | ✅ | Parcial | ✅ | ✅ | ✅ (FIDO2, NFC, QR) |
| **MFA** | ✅ (OTP,Duo) | ✅ | ✅ (SMS,OTP) | ✅ | ✅ | ✅ (**18 métodos**) |
| **SAML / Enterprise SSO** | ✅ ($11/mo extra) | ✅ (Business) | ❌ | ✅ (paid) | ✅ | ✅ |
| **Multi-tenant (B2B)** | ✅ (5 orgs free) | ✅ ($1/org/mo) | ❌ | ✅ | Parcial | ✅ (**empresas+sucursales**) |
| **RBAC granular** | ✅ (RBAC básico) | ❌ | ❌ | ✅ | ✅ (roles) | ✅ (**12 dominios D1-D12**) |
| **4 variantes de token** | ❌ Solo RS256 | ❌ Solo JWT | ❌ Solo JWT | ❌ Solo JWT | ❌ Solo RS256 | ✅ **(Liviano, +Mask, +Blockchain, RS256)** |
| **Token liviano Ed25519** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **1.1 KB, 40× más rápido que RSA** |
| **Token offline/contingencia** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **RolBitMask cookie, FastPath <0.5ns** |
| **Soporte Legacy RS256** | ✅ (default) | ❌ (solo ES256) | ❌ (solo RS256) | ❌ | ✅ (default) | ✅ **Bajo demanda, compatible enterprise** |
| **Firma digital** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **(Ed25519 Vault + RSA ADSIB)** |
| **Firma fiscal LATAM** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **(ADSIB Bolivia, Ley 164)** |
| **Blockchain anchoring** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **(Besu QBFT, Merkle proofs)** |
| **Cumplimiento ISO 27001** | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ (20 controles) |
| **ctx_id / W3C Trace Context** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **(SBOS-049, OpenTelemetry)** |
| **Open Source** | ❌ | ❌ | ❌ | ✅ Apache 2.0 | ✅ Apache 2.0 | ✅ |
| **Self-hosted** | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ **Ubuntu 26.04** |
| **JSON-RPC 2.0 nativo** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **47+ métodos** |
| **Desktop dev tool** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **(bAuthDEV, Flutter)** |
| **Dev → distribuidor** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **(único en el mercado)** |

#### PUNTOS FUERTES DE VALOR — Detalle de cada diferenciador irremplazable

##### 1. CUATRO VARIANTES DE TOKEN — Un token para cada mercado

Ningún competidor ofrece más de un tipo de token. bAuth ofrece 4, cada una diseñada
para un segmento de mercado distinto:

```
┌──────────────────────────────────────────────────────────────────────┐
│  VARIANTE         │ TAMAÑO  │ VELOCIDAD │ MERCADO                   │
│  ─────────────────┼─────────┼───────────┼────────────────────────── │
│  1. LIVIANO       │ 1.1 KB  │ 50 µs     │ Apps conectadas           │
│     Ed25519 puro  │         │           │ PDP server-side            │
│                   │         │           │                           │
│  2. +ROLBITMASK   │ +968 B  │ <0.5 ns   │ POS, kioskos, NFC,        │
│     Cookie offline│ (cookie)│ local     │ sucursales remotas sin    │
│                   │         │           │ conexión al PDP           │
│                   │         │           │                           │
│  3. +BLOCKCHAIN   │ +hash   │ 50 µs     │ Auditoría externa,        │
│     Merkle Proof  │ Keccak  │ +anclaje  │ compliance ISO 27001,     │
│                   │         │           │ verificable sin issuer    │
│                   │         │           │                           │
│  4. RS256 LEGACY  │ ~2 KB   │ 2,000 µs  │ Empresas con infra        │
│     Compatibilidad│         │           │ legacy que no soportan    │
│                   │         │           │ Ed25519 (Java 8, .NET 4) │
└──────────────────────────────────────────────────────────────────────┘
```

**Por qué esto es irremplazable:**
- Auth0/Clerk/Firebase SOLO ofrecen RS256 o ES256. Sin offline, sin blockchain.
- Una empresa puede empezar con la variante 1 (liviano), agregar la 2 cuando abre sucursales,
  activar la 3 cuando necesita auditoría certificada, y mantener la 4 para sistemas legacy.
- **El mismo motor, la misma API, 4 modos de operación.** Sin migrar, sin recompilar.

##### 2. SOPORTE LEGACY RS256 — Donde NADIE llega

**Este es uno de los puntos más fuertes porque casi ningún competidor lo ofrece
como opción secundaria.**

| Competidor | RS256 | Problema |
|-----------|:---:|----------|
| **Auth0** | ✅ (default) | Pero sin las otras 3 variantes. Sin offline, sin blockchain. |
| **Clerk** | ❌ | Solo ES256 (ECDSA P-256). No compatible con sistemas legacy. |
| **Firebase** | ✅ (default) | Pero vendor lock-in Google. Sin self-hosted. |
| **SuperTokens** | ❌ | Solo Ed25519. Rompe con Java 8, .NET Framework, Python 3.6. |
| **Keycloak** | ✅ (default) | Pesado (Java), complejo de mantener. Sin variantes livianas. |
| **bAuth** | ✅ (opcional) | **Ed25519 default + RS256 bajo demanda.** Cubre moderno Y legacy. |

**Caso real:** Un banco boliviano tiene sucursales con Windows Server 2012 + .NET 4.5.
No soporta Ed25519. Con Auth0 pagaría $1,500/mes solo por RS256. Con bAuth:
activa `engines.keycloak.legacy_rsa = true` y listo. **Mismo tenant, mismo precio.**

##### 3. FIRMA DIGITAL ADSIB — Exclusividad fiscal boliviana

**Ningún proveedor global de IAM ofrece firma digital para facturación electrónica
boliviana.** Esto no es una feature — es un requisito legal. Las 400,000+ empresas
bolivianas obligadas a facturar electrónicamente NO TIENEN alternativa que integre
autenticación + firma fiscal en un solo producto.

```
┌──────────────────────────────────────────────────────────────────────┐
│  DOBLE MOTOR DE FIRMAS — ÚNICO EN EL MERCADO                         │
│                                                                       │
│  MOTOR INTERNO (Ed25519, Vault PKI)                                  │
│  • Tokens JWT, logs de auditoría, contratos inter-tenant             │
│  • FIPS 186-5, RFC 8032                                              │
│  • CA propia, certificados M2M TTL 24h                               │
│                                                                       │
│  MOTOR EXTERNO (RSA-SHA256, ADSIB Bolivia)                           │
│  • Facturación electrónica SIN (RND 102100000011)                    │
│  • Cumplimiento Ley 164                                               │
│  • Jerarquía: ATT → ADSIB → Signatario                               │
│  • Validación CRL automática                                          │
│                                                                       │
│  ⚠️ NINGÚN competidor ofrece ESTO. Las empresas bolivianas no tienen  │
│     otra opción que cumpla autenticación + firma fiscal en uno.      │
└──────────────────────────────────────────────────────────────────────┘
```

##### 4. MODELO DEV → DISTRIBUIDOR — El desarrollador como canal de ventas

**Ningún competidor tiene este modelo.** Todos venden directamente al usuario final.
bAuth convierte al desarrollador en revendedor:

| Modelo tradicional (Auth0/Clerk/Firebase) | Modelo bAuth |
|-------------------------------------------|--------------|
| El desarrollador integra la API | El desarrollador integra la API |
| La empresa contrata directamente al proveedor | La empresa contrata AL DESARROLLADOR |
| El proveedor cobra a la empresa | **El desarrollador cobra a la empresa** |
| El proveedor gestiona todo | **El desarrollador gestiona sus empresas desde bAuthDEV** |
| 1 cliente = 1 tenant | **1 desarrollador = 1 tenant con N empresas y M sucursales** |

**El desarrollador compite con nosotros, es nuestro vendedor.** Cada empresa que él
onboardea paga su plan. Nosotros cobramos al desarrollador según el plan que contrata.
Él le cobra a sus clientes lo que quiera.

##### 5. OFFLINE CON RolBitMask — Contingencia sin conexión al PDP

**Ningún competidor ofrece modo offline real.** Cuando una sucursal en una zona rural
de Bolivia pierde internet, Auth0/Clerk/Firebase dejan de funcionar. bAuth sigue operando:

- El token incluye el RolBitMask como cookie (968 chars)
- FastPath local evalúa en <0.5ns sin consultar al PDP
- TTL de 30s sincronizado con Redis cache
- Cuando vuelve la conexión, los eventos pendientes se reconcilian

**Mercado:** POS en provincias, kioskos NFC, lectores de puerta, IoT industrial, minería.

#### Análisis FODA detallado

```
FORTALEZAS (INTERNO)                  OPORTUNIDADES (EXTERNO)
─────────────────────────────────     ─────────────────────────────────
• 4 variantes de token — NADIE más    • 400K+ empresas obligadas a
  ofrece esto                          facturación electrónica en Bolivia
• RS256 legacy — cubre Windows        • 0 competidores locales en Bolivia
  Server 2012, Java 8, .NET 4.x       • Crecimiento fintech LATAM 15% anual
• Firma ADSIB — requisito legal       • Postman eliminó plan free-team
  que NADIE más cumple                  (marzo 2026) → devs buscan
• Modelo dev→reseller — el             alternativas
  desarrollador es nuestro vendedor   • Auth0/Okta precios suben 20-40%
• Offline RolBitMask — funciona        anual → mercado busca open source
  sin internet (zonas rurales)        • Leyes de identidad digital en LATAM
• 18 métodos de autenticación —        (similar a Ley 164 Bolivia)
  más que cualquier competidor        • ISO 27001 exigido por reguladores
• 12 dominios de control granular      corporativos y gobierno
• Open source + self-hosted —
  sin vendor lock-in

DEBILIDADES (INTERNO)                 AMENAZAS (EXTERNO)
─────────────────────────────────     ─────────────────────────────────
• Marca nueva, 0 reconocimiento       • Auth0/Okta presupuestos de
  fuera de Bolivia                      marketing masivos ($50M+ anual)
• Comunidad pequeña (inicio)          • Firebase Auth "gratis" = efecto
• Documentación solo en español         lock-in Google Cloud Platform
  limita entrada a mercado global     • Clerk crece rápido en mercado
• Sin SOC2 Tipo II (requiere           React/Next.js (no es nuestro target)
  auditoría externa $50K+)            • Keycloak es gratis y conocido
• Equipo pequeño vs gigantes          • Competidores pueden agregar
  (Auth0 tiene 2,500+ empleados)        funcionalidades similares en 2-3 años
• Dependencia de infraestructura
  propia (VPS)
```

#### Estrategia de posicionamiento por mercado

```
┌──────────────────────────────────────────────────────────────────────┐
│  FASE 1 — BOLIVIA (2026-2027)                                        │
│  ─────────────────────────────────────────────────────────────────  │
│  NICHO:    Facturación electrónica SIN + autenticación               │
│  MENSAJE:  "El ÚNICO proveedor de auth con firma digital para        │
│            facturación boliviana. Open source. Sin vendor lock-in."  │
│  CANAL:    Desarrolladores de software factories en La Paz,          │
│            Cochabamba, Santa Cruz.                                   │
│  META:     50 desarrolladores activos, 200 empresas onboardeadas.    │
│                                                                       │
│  FASE 2 — LATAM (2027-2028)                                          │
│  ─────────────────────────────────────────────────────────────────  │
│  EXPANSIÓN: Perú (SUNAT), Chile (SII), Colombia (DIAN), Argentina    │
│  MENSAJE:  "Autenticación + firma fiscal para cada país LATAM."     │
│  CANAL:    Fintechs, govtech, ERP providers regionales.              │
│  META:     500 desarrolladores, 5,000 empresas en 5 países.          │
│                                                                       │
│  FASE 3 — GLOBAL (2028+)                                             │
│  ─────────────────────────────────────────────────────────────────  │
│  MENSAJE:  "El IAM open source más completo: 4 variantes de token,   │
│            12 dominios, blockchain, firma digital, offline."        │
│  CANAL:    Developers en GitHub, HackerNews, conferencias.           │
│  META:     Competir con Auth0/Clerk en características, ganar en     │
│            precio y libertad (open source + self-hosted).            │
└──────────────────────────────────────────────────────────────────────┘
```

#### Datos de mercado — Fuentes y proyecciones

| Métrica | Valor | Fuente |
|---------|-------|--------|
| Mercado global IAM 2026 | ~$22.5B USD | Gartner, MarketsAndMarkets |
| CAGR IAM 2026-2032 | 13.2% anual | Straits Research |
| Mercado AaaS 2026 | ~$5.8B USD | TrendVault Research |
| Mercado IAM LATAM 2026 | ~$1.2B USD (creciendo 15%) | Barnes Reports |
| Penetración IDaaS en Bolivia | < 5% | Estimación propia |
| Competidores locales en Bolivia | 0 | Investigación directa |
| Empresas con facturación electrónica obligatoria | 400,000+ | SIN Bolivia (RND 102100000011) |
| Desarrolladores activos Bolivia | ~15,000 | Encuesta StackOverflow + GitHub |
| Costo promedio construir auth propio | $180K-$450K (20-38 meses) | BAUTH-VISION.md + estudios industria |
| Costo integrar bAuth | $0 (open source) + 8h | BAUTH-VISION.md |
| Precio promedio Auth0 para 500 MAU | $35/mo (Essentials) | auth0.com/pricing |
| Precio promedio Clerk para 50K MAU | $25/mo (Pro) | clerk.com/pricing |
| Precio bAuth BASIC (producción) | $49/mo (100 usuarios, 3 dominios) | Propuesto |

---

## 2. ARQUITECTURA DE LA APLICACIÓN

### 2.1 Layout principal — 4 paneles con editores de código

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🛠️ bAuthDEV  │  🟢 SSH root@13.140.128.230:22  │  uptime 12d  [⚙ Entorno] │
├──────────┬──────────────────────┬────────────────────────────────────────────┤
│          │                      │                                           │
│ EXPLORADOR    │  EDITOR DE CÓDIGO     │  VISOR DE RESPUESTA                  │
│ DE MÉTODOS    │  JSON-RPC Request     │  JSON Response                       │
│ (catálogo)    │  (resaltado, auto-    │  (resaltado, colapsable,             │
│               │   completado)         │   formateado)                        │
│          │                      │                                           │
│ 🔍 Buscar    │  ┌────────────────┐   │  ┌──────────────────────────────────┐ │
│ ─────────    │  │ {               │   │  │ {                                 │ │
│              │  │   "jsonrpc": "2.│   │  │   "jsonrpc": "2.0",              │ │
│ 📁 Auth      │  │     0",         │   │  │   "result": {                     │ │
│ ├─ access    │  │   "method": "ba│   │  │     "verdict": "allow",           │ │
│ │  .evaluate│  │     uth.access. │   │  │     "fastpath": true,             │ │
│ │  .issue   │  │     evaluate",  │   │  │     "domain_results": {           │ │
│ │  .validate│  │   "params": {   │   │  │       "D1": "PERMITIDO",          │ │
│ ├─ context   │  │     "atom_slug"│   │  │       "D3": "PERMITIDO",          │ │
│ │  .evaluate│  │       : "tryton │   │  │       ...                         │ │
│ ├─ token     │  │       .sale_pos│   │  │     },                            │ │
│ │  .issue   │  │       .write", │   │  │     "latency_ns": 0.3              │ │
│ │  .validate│  │     "user_uuid"│   │  │   },                               │ │
│ │  .jwks    │  │       : "019f  │   │  │   "id": 1                          │ │
│ │            │  │        ..."    │   │  │ }                                  │ │
│ │            │  │   },          │   │  └──────────────────────────────────┘ │
│ │            │  │   "id": 1     │   │                                        │
│ │            │  │ }             │   │  Lenguaje: [JSON ▼]  [📋 Copiar]      │
│ │            │  └────────────────┘   │  [🗜 Formatear]  [📤 Exportar]       │
│ │            │                       │                                        │
│ │            │  [▶ ENVIAR] [📦 LOTE] │  ┌─── SNIPPETS ─────────────────────┐ │
│ │            │  [🔤 Formatear JSON]  │  │ Lenguaje: [Go ▼]                  │ │
│ │            │                       │  │ ┌──────────────────────────────┐  │ │
│ │            │                       │  │ │ // Go                         │  │ │
│ │            │                       │  │ │ params := map[string]interf..│  │ │
│ │            │                       │  │ │ result, _ := rpc.Call(       │  │ │
│ │            │                       │  │ │   "bauth.access.evaluate",   │  │ │
│ │            │                       │  │ │   params)                    │  │ │
│ │            │                       │  │ └──────────────────────────────┘  │ │
│ │            │                       │  │ [📋 Copiar] [🔄 Rotar lenguaje]   │ │
│ │            │                       │  └──────────────────────────────────┘ │
├──────────┴──────────────────────┴────────────────────────────────────────────┤
│  ┌─ 🖥 TERMINAL SSH — root@vmi3346550:~# ──────────────────────────────────┐ │
│  │  root@vmi3346550:~# echo '{"jsonrpc":"2.0","method":"bauth.health.check",│ │
│  │  "id":1}' | nc -U /tmp/bauth/bauth.sock -w 3 | python3 -m json.tool     │ │
│  │  {                                                                        │ │
│  │      "jsonrpc": "2.0",                                                    │ │
│  │      "result": { "status": "operativo", "version": "3.0.0" },            │ │
│  │      "id": 1                                                              │ │
│  │  }                                                                        │ │
│  │  root@vmi3346550:~# █                                                     │ │
│  └──────────────────────────────────────────────────────────────────────────┘ │
│  [⚡ QUICKSTART] [🧪 AUTOFILL ▼] [💾 GUARDAR SESIÓN] [📤 EXPORTAR .SH]       │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Los 4 paneles:**
1. **Explorador** (izquierda): catálogo de 47+ métodos, selección = pre-llena el editor
2. **Editor de código** (centro): editor JSON con resaltado de sintaxis, autocompletado bAuth, formateo
3. **Visor de respuesta + Snippets** (derecha): JSON formateado y colapsable + snippets multi-lenguaje
4. **Terminal SSH** (inferior): conexión real al servidor para comandos directos

### 2.1.1 Editor de código — Características

Basado en **duskmoon_code_engine** (v1.6.0, Abril 2026) — CodeMirror 6 en Dart puro.
Elegido sobre flutter_monaco porque soporta Linux (Monaco usa WebView, no compatible).

| Característica | Implementación |
|----------------|---------------|
| **Resaltado de sintaxis JSON** | `jsonLanguageSupport()` — claves, strings, números, booleanos, null en colores distintos |
| **Autocompletado bAuth** | Sugerencias de métodos (`bauth.token.issue`), parámetros, UUIDs de usuarios |
| **Formateo JSON** | `[Ctrl+Shift+F]` o botón — indentado 2 espacios, ordenado |
| **Validación en vivo** | JSON mal formado → subrayado rojo con mensaje de error |
| **Números de línea** | Columna izquierda con números de línea |
| **Bracket matching** | Resalta paréntesis/llaves/corchetes emparejados |
| **Plegado de código** | Colapsar/expandir objetos JSON anidados |
| **Búsqueda y reemplazo** | `[Ctrl+F]` buscar, `[Ctrl+H]` reemplazar |
| **Tema oscuro** | Tema `vs-dark` o personalizado SBOS (#0A0E13 background) |
| **Multi-cursor** | `[Ctrl+Click]` para editar en múltiples posiciones |

### 2.1.2 Lenguajes soportados en snippets

| Lenguaje | Extensión | Uso |
|----------|-----------|-----|
| **JSON** | `.json` | Requests y respuestas RPC |
| **Go** | `.go` | Snippet `rpc.Call("bauth...", params)` |
| **Rust** | `.rs` | Snippet `rpc.call("bauth...", params)?` |
| **Python** | `.py` | Snippet `rpc.call("bauth...", params)` |
| **JavaScript** | `.js` | Snippet `await rpc.call("bauth...", params)` |
| **PHP** | `.php` | Snippet `$rpc->call("bauth...", $params)` |
| **Dart** | `.dart` | Snippet `rpc.call("bauth...", params)` |
| **cURL / Shell** | `.sh` | Snippet `echo '...' \| nc -U /tmp/bauth/bauth.sock` |
| **YAML** | `.yml` | Configuraciones, colecciones exportadas |
| **Markdown** | `.md` | Documentación de métodos |

### 2.2 Navegación y secciones

| Sección | Propósito |
|---------|-----------|
| **Conexión** | Configurar endpoint (host:puerto o Unix socket), probar conexión, health check |
| **Explorador** | Catálogo completo de 47+ métodos organizados por categoría con documentación |
| **Editor** | Construir requests JSON-RPC con autocompletado, params builder y snippets |
| **Historial** | Todas las requests enviadas con respuesta, timestamp, duración, capacidad de re-ejecutar |
| **Colecciones** | Guardar requests organizadas en carpetas, exportar/importar JSON |

### 2.3 Herramientas integradas (paneles laterales en respuesta)

| Herramienta | Qué hace |
|-------------|----------|
| **Token Decoder** | Decodifica JWT (header + payload + firma), verifica firma Ed25519, muestra claims |
| **Merkle Verifier** | Verifica integridad de evento: leaf hash → calcula raíz → compara con blockchain |
| **Firma Verifier** | Verifica firma digital Ed25519 o RSA-SHA256 contra documento y clave pública |
| **Snippet Generator** | Genera código en Go, Rust, Python, JS, Dart, cURL con los params del request actual |

---

## 2.5 VENTANA DE COMANDOS — El acelerador de aprendizaje (tipo VFP 9)

### 2.5.0 Inspiración: Visual FoxPro 9 + Terminal segura transparente

Visual FoxPro 9 tenía una **ventana de comandos** donde el desarrollador escribía
comandos, presionaba Enter, y veía el resultado inmediatamente. **El desarrollador
nunca sabía si el comando se ejecutaba localmente o en un servidor remoto.** La
conexión era transparente.

**bAuthDEV aplica este principio con seguridad reforzada.** El desarrollador NO
tiene acceso a una terminal Linux real. No hay bash. No hay `rm -rf`. No hay
acceso al sistema operativo del servidor. Lo que ve es un **entorno de ejecución
seguro y limitado** donde solo se ejecutan comandos JSON-RPC contra el daemon bAuth.
La conexión SSH es transparente — el desarrollador solo sabe que "funciona".

```
┌──────────────────────────────────────────────────────────────────────────┐
│  🛠️ bAuthDEV  │  🟢 Conectado a bAuth v3.0.0  │  uptime: 12d 4h        │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  [PANEL SUPERIOR: CATALOGO │ CINTA DE BLOQUES — igual que antes]         │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  ┌─ 🧭 CONSOLA SEGURA DE COMANDOS RPC ─────────────────────────────────┐ │
│  │                                                                      │ │
│  │  ▸ Comando RPC listo. Escribe un metodo o seleccionalo del catalogo. │ │
│  │  ─────────────────────────────────────────────────────────────── │ │
│  │                                                                      │ │
│  │  [metodo RPC o palabra clave]        [▶ EJECUTAR]                    │ │
│  │                                                                      │ │
│  │  ⓘ Solo se ejecutan comandos JSON-RPC contra el daemon bAuth.        │ │
│  │    No hay acceso al sistema operativo del servidor.                  │ │
│  │    La conexion es cifrada y transparente.                            │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
│  [⚡ QUICKSTART] [🧪 AUTOFILL ▼] [📋 HISTORIAL] [💾 GUARDAR SESION]      │
└──────────────────────────────────────────────────────────────────────────┘
```

### 2.5.1 Arquitectura de seguridad — Sandbox por diseño

**El desarrollador NUNCA tiene acceso al sistema operativo del servidor.**
La conexión SSH es transparente, gestionada internamente por bAuthDEV, y
limitada a ejecutar ÚNICAMENTE comandos JSON-RPC validados.

```
┌──────────────────────────────────────────────────────────────────────┐
│  QUE VE EL DESARROLLADOR           QUE PASA REALMENTE                │
│  ─────────────────────────         ─────────────────────────         │
│                                                                      │
│  ▸ token.issue user:cajero         bAuthDEV valida el comando.       │
│     [+Mask]                         Traduce a JSON-RPC.               │
│                                     Abre tunel SSH (interno).         │
│  ← JWT emitido, 1.1 KB            Envia a /tmp/bauth/bauth.sock     │
│                                     Cierra el tunel.                  │
│                                     Muestra el resultado.             │
│                                                                      │
│  El desarrollador NO ve:            El desarrollador NO PUEDE:        │
│  • Que hay SSH debajo              • Ejecutar bash, rm, systemctl    │
│  • La IP del servidor              • Acceder al filesystem           │
│  • El socket Unix                  • Ver otros tenants               │
│  • La clave SSH                    • Modificar configuracion         │
│  • El usuario root                 • Instalar software               │
│                                    • Ver logs del sistema             │
└──────────────────────────────────────────────────────────────────────┘
```

### 2.5.2 Capas de seguridad

| Capa | Proteccion |
|------|-----------|
| **1. Validacion de comando** | Solo se ejecutan metodos del catalogo bAuth (47+ metodos). Cualquier otra cosa se rechaza. |
| **2. Tunel SSH interno** | bAuthDEV maneja la conexion SSH. El desarrollador NO tiene las credenciales. |
| **3. Usuario SSH limitado** | Usuario `bauthdev` (NO root). Solo tiene permiso de lectura/ejecucion sobre el socket Unix. |
| **4. Sin shell** | El usuario `bauthdev` tiene `/bin/false` como shell. No puede ejecutar bash, sh, ni comandos del sistema. |
| **5. Comandos pre-aprobados** | Solo se permite: `nc -U /tmp/bauth/bauth.sock` con JSON-RPC valido. Nada mas. |
| **6. Rate limiting** | Maximo 100 comandos por minuto por desarrollador. Previene abuso. |
| **7. Auditoria** | Cada comando ejecutado se registra con: timestamp, metodo, parametros, resultado. |

### 2.5.3 Configuracion del usuario SSH limitado en el servidor

```bash
# En el servidor VPS — usuario dedicado para bAuthDEV (sin shell, sin privilegios)
useradd -M -s /bin/false bauthdev
usermod -aG bosagent bauthdev    # Solo acceso al socket del grupo bosagent
mkdir -p /home/bauthdev/.ssh
# Solo se permite ejecutar nc contra el socket de bAuth
echo 'command="nc -U /tmp/bauth/bauth.sock -w 5",no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding ssh-rsa AAAAB3...' > /home/bauthdev/.ssh/authorized_keys
chmod 600 /home/bauthdev/.ssh/authorized_keys
chown -R bauthdev:bosagent /home/bauthdev/.ssh
```

### 2.5.4 Comandos permitidos vs prohibidos

```
PERMITIDOS (unica operacion valida)     PROHIBIDOS (rechazados antes de enviar)
────────────────────────────────────    ──────────────────────────────────────
bauth.token.issue                       rm -rf /
bauth.token.validate                    systemctl stop bauth
bauth.access.evaluate                   cat /etc/passwd
bauth.context.evaluate                  curl http://malicioso.com/...
bauth.role.template.list                nc -l -p 9999
bauth.health.check                      bash, sh, zsh, python, perl
... (47+ metodos del catalogo)          cualquier comando que no este en
                                        el catalogo de metodos bAuth
```

### 2.5.5 Mensajes de seguridad visibles para el desarrollador

```
INTENTO DE COMANDO NO PERMITIDO:
▸ rm -rf /tmp/*
← ⛔ COMANDO RECHAZADO — Solo se permiten metodos JSON-RPC del catalogo bAuth.
   Escribe 'help' para ver los comandos disponibles.

INTENTO DE ACCESO AL SISTEMA:
▸ systemctl status bauth
← ⛔ COMANDO RECHAZADO — No tienes acceso al sistema operativo del servidor.
   Para ver el estado del daemon, escribe: health.check
```

### 2.5.6 La consola segura como ayuda contextual

Cuando el desarrollador escribe `help` o presiona `?`:

```
▸ help
──────────────────────────────────────────────────────────────────────
COMANDOS DISPONIBLES (47+ metodos JSON-RPC 2.0)

AUTENTICACION Y TOKENS:
  token.issue [user] [+Mask] [+Blockchain] [RS256]  — Emitir JWT
  token.validate [jwt]                                — Validar JWT
  token.jwks                                          — Clave publica Ed25519

ACCESO:
  access.evaluate [usuario] [atomo]     — Evaluar si un usuario puede ejecutar un atomo
  context.evaluate [ctx_id] [atomo]     — Evaluar los 12 dominios completos

DOMINIOS:
  domain.logical [atomo]                — D1 Logico
  domain.physical [atomo]               — D2 Fisico
  domain.financial [atomo] [monto]     — D3 Financiero
  ... (12 dominios)

ROLES Y USUARIOS:
  role.template.list [tier]            — Listar plantillas
  role.compute.mask [role_id]          — Calcular RolBitMask
  sod.check [atomos]                   — Verificar Conflict Matrix
  user.list [tenant]                   — Listar usuarios
  ... (8 metodos)

SINCRONIZACION, FIRMA, BLOCKCHAIN:
  sync.status [tenant]                 — Estado de sincronizacion KC+Tryton
  sign.internal [documento]           — Firma digital Ed25519/ADSIB
  blockchain.panel                     — Panel D12 (Besu QBFT)

SISTEMA:
  health.check                         — Estado del daemon
  help [metodo]                        — Ayuda detallada de un metodo
  history                              — Historial de comandos ejecutados

💡 TIP: Escribe el nombre parcial de un metodo y presiona TAB para autocompletar.
💡 TIP: Selecciona un metodo del catalogo (izquierda) para auto-llenar parametros.
──────────────────────────────────────────────────────────────────────

```

### 2.5.6 Resumen: Por qué SSH real + terminal incrustada

```
┌──────────────────────────────────────────────────────────────────────┐
│  APRENDIZAJE TRADICIONAL              BAUTHDEV SSH TERMINAL           │
│  ─────────────────────────            ──────────────────────          │
│                                                                      │
│  1. Leer documentación (2h)          1. Abrir bAuthDEV                │
│  2. Buscar ejemplos (30min)          2. Conectar SSH (5 seg)          │
│  3. Configurar Postman (1h)          3. QUICKSTART automático (3 min) │
│  4. Escribir JSON a mano (30min)     4. AUTOFILL → modificar (10 min) │
│  5. Enviar primer request (15min)    5. MODO LIBRE (30 min)           │
│  6. Ver error, corregir JSON (30min) 6. Exportar script .sh (1 min)   │
│  7. Repetir para cada método                                         │
│                                                                      │
│  TOTAL: ~5 horas                      TOTAL: ~45 minutos              │
│  OUTPUT: Entendimiento teórico        OUTPUT: Script listo para CI/CD │
└──────────────────────────────────────────────────────────────────────┘
```

**El principio:** El desarrollador aprende haciendo en el entorno REAL. Cada comando
que ejecuta en la terminal de bAuthDEV es el MISMO comando que usará en producción.
No hay traducción, no hay "así se hace en el playground pero en producción es distinto".
Cuando termina la sesión, exporta su historial como `.sh` y lo integra directamente.

### 3.1 Cómo funciona: Click -> Codigo -> Ejecutar

**El catalogo NO es una lista estatica. Es un generador de codigo vivo.**
Click en cualquier metodo -> el editor se auto-completa con un request JSON-RPC
listo para ejecutar, usando datos reales del usuario activo.

```
PASO 1 - El desarrollador navega el catalogo (panel izquierdo)
  |  Ve los 47+ metodos organizados por categoria
  |
  v
PASO 2 - Click en un metodo (ej: bauth.token.issue)
  |  El editor de codigo se auto-completa INSTANTANEAMENTE con:
  |  * Metodo seleccionado
  |  * User UUID del usuario activo (test_cajero)
  |  * Parametros por defecto con valores reales
  |  * Checkboxes de contexto reflejados (+Mask, +Blockchain, RS256)
  |
  v
PASO 3 - El desarrollador modifica o ejecuta directo
  |  Presiona [ENVIAR] o Ctrl+Enter
  |
  v
PASO 4 - Respuesta instantanea
  |  JSON colapsable + snippets en 8 lenguajes + comando guardado en memoria
```

### 3.2 El catalogo con checkboxes de contexto

Cada metodo muestra checkboxes que controlan el contexto sin tocar el JSON:

```
TOKENS
  bauth.token.issue        * MAS USADO - Emite JWT Ed25519
    [+Mask] [+Blockchain] [RS256 Legacy]  [PROBAR]
  bauth.token.validate     Valida JWT y devuelve claims
    [PROBAR CON ULTIMO JWT EMITIDO]
  bauth.token.jwks         Clave publica Ed25519 para verificacion

ACCESO
  bauth.access.evaluate    * MAS USADO - Evalua usuario vs atomo
    [Evaluar 12 dominios] [Solo FastPath D1]  [PROBAR]
  bauth.context.evaluate   Evalua 12 dominios completos para ctx_id

DOMINIOS
  bauth.domain.logical     D1 (apps, modulos, verbos)
  bauth.domain.physical    D2 (edificios, pisos, zonas)
  bauth.domain.financial   D3 (limites, SoD, aprobaciones)
  bauth.domain.temporal    D4 (horarios, turnos)
  bauth.domain.biometric   D5 (LoA, Step-Up)
  bauth.domain.geospatial  D6 (paises, geo-fences)
  bauth.domain.network     D7 (CIDR, ZTNA)
  bauth.domain.audit       D11 (WORM, revisiones)
  bauth.blockchain.panel   D12 (Besu QBFT, Merkle)

ROLES Y USUARIOS
  bauth.role.template.list / get / role.list / compute.mask
  bauth.inheritance.compute / check / sod.check
  bauth.template.validate    260+ reglas hardening
  bauth.merge.templates / user.list / tenant.list

POLITICAS - SINCRONIZACION - FIRMA - COMERCIAL
  bauth.policy.evaluate / sync.reconcile / sync.status
  bauth.sign.internal        Ed25519 + ADSIB
  bauth.commercial / idp.external / saga.execute / health.check
```

### 3.3 Sistema de AYUDA contextual (tecla `?`)

Al presionar `?` sobre cualquier metodo:

```
AYUDA: bauth.token.issue
  Emite un token JWT Ed25519. Liviano (~1.1 KB), solo identidad.
  Permisos se evaluan server-side. 4 variantes disponibles.

  PARAMETROS:
    user_uuid      string   REQUERIDO - UUIDv7 del usuario
    include_mask   bool     Incluir RolBitMask en respuesta
    anchor         bool     Anclar en Besu QBFT (Merkle proof)
    algorithm      string   "Ed25519" (default) o "RS256" (legacy)

  RESPUESTA:
    { algorithm, jwt_size_chars, jwt, token_sha256,
      merkle_leaf_keccak256, rolbitmask? }

  EJEMPLO CON DATOS REALES:
    echo '{"jsonrpc":"2.0","method":"bauth.token.issue",...}' \
      | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -m json.tool

  [USAR ESTE COMANDO] [COPIAR]
  RFC 8032 (Ed25519) | RFC 7519 (JWT) | FIPS 186-5
```

### 3.4 Cinta de ejecucion — El patron "Calculator Tape" (tipo Warp Terminal Blocks)

**Inspiracion:** Las calculadoras con impresora tienen una **cinta de papel** donde cada
operacion queda registrada con su resultado. La cinta se acumula, se puede revisar,
arrancar un pedazo y reutilizarlo. Warp Terminal modernizo este concepto con "Blocks":
cada comando + su output es un bloque persistente, navegable y re-ejecutable.

**bAuthDEV aplica este patron a JSON-RPC.** Cada request ejecutado se convierte en
un bloque inmutable en la cinta: el comando arriba, el resultado abajo. La cinta
crece hacia abajo. Nada se pierde. Todo se puede recuperar.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  🛠️ bAuthDEV  │  🟢 SSH root@13.140.128.230  │  👤 test_cajero [8 atomos]  │
├──────────┬────────────────────────────────────────────────────────────────────┤
│          │                                                                    │
│ CATALOGO │  ┌─ 🧮 CINTA DE EJECUCION (Calculator Tape) ────────────────────┐ │
│ METODOS  │  │                                                                │ │
│          │  │  ┌── BLOQUE #1 — 14:32:05 ─────────────────────────────────┐  │ │
│ 🔍 buscar│  │  │                                                           │  │ │
│ ──────── │  │  │  ▸ COMANDO:                                               │  │ │
│          │  │  │  {                                                        │  │ │
│ TOKENS   │  │  │    "method": "bauth.token.issue",                         │  │ │
│  ├─ issue│  │  │    "params": {                                            │  │ │
│  │  [*]  │  │  │      "user_uuid": "019f06db-62a9-73ab-a85a-f5d12f20233d",│  │ │
│  ├─ vali│  │  │      "include_mask": true                                  │  │ │
│  │      │  │  │    }                                                       │  │ │
│  ├─ jwks│  │  │  }                                                          │  │ │
│          │  │  │                                                           │  │ │
│ ACCESO   │  │  │  ─── RESULTADO ────────────────────────────────────────── │  │ │
│  ├─ acce│  │  │  {                                                          │  │ │
│  │  [*] │  │  │    "algorithm": "EdDSA",                                    │  │ │
│  │      │  │  │    "jwt_size_chars": 1112,                                  │  │ │
│  ├─ cont│  │  │    "jwt": "eyJhbGciOiJFZDI1NTE5...",                        │  │ │
│  │      │  │  │    "rolbitmask": { "active_count": 8 }                      │  │ │
│          │  │  │  }                                                          │  │ │
│ DOMINIOS │  │  │  ⏱ 3.2ms │ 📏 1,112 chars │ 🔐 Ed25519 │ 🟢 OK            │  │ │
│  ├─ logi│  │  │                                                           │  │ │
│  │  ... │  │  │  [▶ RE-EJECUTAR] [✏ EDITAR] [📋 COPIAR] [⭐ GUARDAR]    │  │ │
│          │  │  └──────────────────────────────────────────────────────────┘  │ │
│ ROLES    │  │                                                                │ │
│  ├─ temp│  │  ┌── BLOQUE #2 — 14:32:28 ─────────────────────────────────┐  │ │
│  │  ... │  │  │                                                           │  │ │
│          │  │  │  ▸ COMANDO:                                               │  │ │
│ SINCRON.│  │  │  {                                                        │  │ │
│  ├─ reco│  │  │    "method": "bauth.access.evaluate",                      │  │ │
│  │  ... │  │  │    "params": {                                            │  │ │
│          │  │  │      "atom_slug": "tryton.g1.d1.nuevo",                  │  │ │
│ FIRMA    │  │  │      "user_uuid": "019f06db-62a9-73ab-a85a-f5d12f20233d" │  │ │
│  ├─ inte│  │  │    }                                                       │  │ │
│  │  ... │  │  │  }                                                          │  │ │
│          │  │  │                                                           │  │ │
│          │  │  │  ─── RESULTADO ────────────────────────────────────────── │  │ │
│          │  │  │  {                                                          │  │ │
│          │  │  │    "verdict": "allow",                                      │  │ │
│          │  │  │    "fastpath": true,                                        │  │ │
│          │  │  │    "domain_results": { "D1": "PERMITIDO" }                 │  │ │
│          │  │  │  }                                                          │  │ │
│          │  │  │  ⏱ 0.3ns │ 🧬 FastPath │ 🟢 PERMITIDO                     │  │ │
│          │  │  │                                                           │  │ │
│          │  │  │  [▶ RE-EJECUTAR] [✏ EDITAR] [📋 COPIAR] [⭐ GUARDAR]    │  │ │
│          │  │  └──────────────────────────────────────────────────────────┘  │ │
│          │  │                                                                │ │
│          │  │  ┌── BLOQUE #3 — 14:32:45 ─────────────────────────────────┐  │ │
│          │  │  │  (comando en progreso...)                                 │  │ │
│          │  │  └──────────────────────────────────────────────────────────┘  │ │
│          │  │                                                                │ │
│          │  │  ─── BLOQUES ANTERIORES (colapsados) ──────────────────────── │ │
│          │  │  Sesion 26 Jun · 23 bloques · 3⭐ · 2🔴  ─── [▼ EXPANDIR]    │ │
│          │  │  Sesion 25 Jun · 45 bloques · 5⭐ · 0🔴  ─── [▼ EXPANDIR]    │ │
│          │  │                                                                │ │
│          │  │  [🧹 LIMPIAR CINTA] [📤 EXPORTAR .SH] [🔍 BUSCAR EN CINTA]  │ │
│          │  └────────────────────────────────────────────────────────────────┘ │
│          │                                                                    │
│          │  ┌─ ✏ EDITOR FLOTANTE (aparece al hacer click en [EDITAR]) ──────┐ │
│          │  │  {                                                               │ │
│          │  │    "method": "bauth.access.evaluate",  ← metodo del bloque #2  │ │
│          │  │    "params": {                                                  │ │
│          │  │      "atom_slug": "tryton.g1.d1.nuevo",                         │ │
│          │  │      "user_uuid": "019f06db-..."  ← podes modificar y re-enviar│ │
│          │  │    }                                                             │ │
│          │  │  }                                                               │ │
│          │  │  [▶ ENVIAR MODIFICADO]  [✕ CERRAR]                             │ │
│          │  └─────────────────────────────────────────────────────────────────┘ │
├──────────┴────────────────────────────────────────────────────────────────────┤
│  ┌─ 🖥 TERMINAL SSH — root@vmi3346550:~# ───────────────────────────────────┐ │
│  │  (la misma terminal SSH real, ejecuta comandos directamente en el server)  │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 3.4.1 Como funciona la cinta

Basado en el modelo de **Bloques de Warp Terminal** (2025) — bloques inmutables,
renderizado virtualizado, historial persistente:

```
1. El desarrollador selecciona un metodo del catalogo
   -> El editor flotante se abre con el request pre-llenado

2. Modifica parametros si quiere (o no) y presiona [ENVIAR]
   -> El request se ejecuta contra el daemon

3. Un NUEVO BLOQUE aparece en la cinta:
   ┌── BLOQUE #N — timestamp ────────────┐
   │  COMANDO (JSON colapsable)           │
   │  ─── RESULTADO ───────────────────── │
   │  { respuesta JSON formateada }       │
   │  metricas + estado                   │
   │  [RE-EJECUTAR] [EDITAR] [COPIAR] [*]│
   └──────────────────────────────────────┘

4. La cinta hace scroll automatico al nuevo bloque

5. Cada bloque es INMUTABLE — el resultado no cambia
   Si el dev quiere modificar el comando, click en [EDITAR]
   -> El editor flotante carga el comando del bloque
   -> Lo modifica -> [ENVIAR] -> NUEVO bloque (no modifica el anterior)
```

### 3.4.2 Acciones sobre cada bloque

| Accion | Atajo | Que hace |
|--------|-------|----------|
| **Re-ejecutar** | Click en [▶] | Vuelve a enviar el mismo comando. Crea un NUEVO bloque abajo. |
| **Editar** | Click en [✏] | Abre el editor flotante con el comando del bloque. Modifica y envia. |
| **Copiar comando** | Click en [📋] | Copia el JSON del comando al portapapeles. |
| **Copiar resultado** | Click en resultado | Copia el JSON de la respuesta. |
| **Guardar favorito** | Click en [⭐] | Marca el bloque como favorito para acceso rapido. |
| **Exportar .sh** | Click en [📤] | Genera el comando equivalente en bash (`echo '...' \| nc -U ...`). |
| **Colapsar/Expandir** | Click en la barra | Colapsa el bloque para mostrar solo metodo + estado. |
| **Eliminar** | Click en [✕] | Oculta el bloque de la cinta (se puede recuperar de la papelera). |

### 3.4.3 Renderizado virtualizado — performance con miles de bloques

Basado en el **SumTree de Warp** (O(log n) viewport lookups):

- Solo los bloques visibles en el viewport se renderizan
- Bloques colapsados ocupan 1 linea (metodo + estado + timestamp)
- La cinta puede tener 10,000+ bloques sin degradacion
- Sesiones anteriores se cargan bajo demanda ([▼ EXPANDIR])

### 3.4.4 Comparacion: Terminal tradicional vs Cinta de bloques

```
TERMINAL TRADICIONAL                CINTA DE BLOQUES (bAuthDEV)
─────────────────────                ──────────────────────────
Output continuo, scroll infinito     Bloques delimitados, navegables
Comando se pierde al hacer scroll   Cada bloque tiene su comando Y resultado
No podes "recuperar" un comando     Click en [EDITAR] -> cargado en editor
  sin usar ↑ (history de bash)
Dificil compartir un resultado      Cada bloque se exporta individual
Dificil ver metricas                Cada bloque muestra latencia, estado
Todo en la terminal SSH             La cinta es VISUAL, la terminal SSH
                                      es un panel separado abajo
```

### 3.4.5 Integracion con la terminal SSH

La terminal SSH sigue estando en el panel inferior. Cumple un proposito diferente:

| Cinta de bloques | Terminal SSH |
|------------------|--------------|
| Ejecucion visual de JSON-RPC | Ejecucion de comandos Linux reales |
| Cada bloque tiene metadata | Output crudo de bash |
| Se exporta como .sh con formato | Se exporta como sesion de terminal |
| Para aprender y prototipar | Para depurar y operar el servidor |
| Click en catalogo -> bloque nuevo | Escribir comandos manualmente |

---

## 4. FLUJOS DE PRUEBA PRE-DISEÑADOS

### 4.1 Flujo #1 — "Mi primer GetContext()"

El desarrollador sigue un wizard de 6 pasos que replica la experiencia `bos.GetContext()`:

```
PASO 1: Conectar al daemon
  → bauth.health.check → ✅ bAuth v3.0.0

PASO 2: Autenticar usuario (simulado)
  → bauth.token.issue {user_uuid: "019abcd..."} → JWT emitido

PASO 3: Validar el token
  → bauth.token.validate {jwt: "eyJ..."} → ✅ Válido, claims decodificados

PASO 4: Evaluar acceso a un átomo (D1 Lógico)
  → bauth.access.evaluate {atom_slug: "tryton.sale_pos.write", user_uuid: "..."}
  ← {"verdict": "allow", "fastpath": true, "latency_ns": 0.3}

PASO 5: Evaluar contexto completo (12 dominios)
  → bauth.context.evaluate {ctx_id: "...", atom_slug: "sistema.sesion.activa"}
  ← {12 dominios evaluados, verdict: "allow", evaluated_domains: [...]}

PASO 6: Tu primer snippet
  → Se genera código en Go listo para producción:
    ctx, err := rpc.Call("bauth.context.evaluate", params)
```

### 4.2 Flujo #2 — "Token + Blockchain + Merkle Proof"

```
PASO 1: Emitir token con anclaje blockchain
  → bauth.token.issue {user_uuid: "...", include_mask: true, anchor: true}
  ← {jwt, token_sha256, merkle_leaf_keccak256, merkle_root, tx_hash}

PASO 2: Verificar token emitido
  → bauth.token.validate {jwt: "eyJ..."}
  ← {valid: true, claims: {...}, token_sha256: "..."}

PASO 3: Verificar Merkle Proof (auditoría externa)
  → El desarrollador pega el merkle_leaf + merkle_root en el Merkle Verifier
  ← ✅ El token fue anclado en Besu QBFT, bloque #1,234,567

PASO 4: Código de verificación (offline)
  → Snippet Go: verifyMerkleProof(leaf, proof, root) → true
```

### 4.3 Flujo #3 — "Firma Digital — Interna y SIN Bolivia"

```
PASO 1: Firmar documento con motor interno (Ed25519)
  → bauth.sign.internal {payload: "documento de prueba", key_id: "..."}
  ← {signature: "0x...", algorithm: "Ed25519", public_key: "..."}

PASO 2: Verificar firma generada
  → Panel Firma Verifier: cargar documento + firma + clave pública
  ← ✅ Firma válida (Ed25519, FIPS 186-5)

PASO 3: Firmar con motor externo (RSA-SHA256, ADSIB)
  → Configurar en bauth.toml → bauth.sign.internal con engine=adsib
  ← {signature: "0x...", algorithm: "RSA-SHA256", certificate_chain: [...]}

PASO 4: Snippet para verificación en app externa
  → Código Go/Rust para verificar firma ADSIB con certificado de la jerarquía Bolivia
```

### 4.4 Flujo #4 — "Roles, SoD y Herencia"

```
PASO 1: Crear RolTemplate base
  → bauth.role.template.list {tier: "BIZ_N1"} → 45 roles
  → Explorar estructura JSONB de un rol existente

PASO 2: Verificar Conflictos de Separación (SoD)
  → El desarrollador selecciona dos átomos incompatibles
  → bauth.sod.check {atom_positions: [427, 891]}
  ← {conflict: true, severity: "ALTO", rule: "Creador ≠ Aprobador"}

PASO 3: Calcular herencia entre roles
  → bauth.inheritance.compute {role_id: "ROL-GERENTE"}
  ← {inherited_atoms: 156, effective_mask_size: 4}

PASO 4: Validar hardening del template
  → bauth.template.validate {template: {...}}
  ← {valid: true, warnings: [...], rules_checked: 260}
```

---

## 4.5 LABORATORIOS — Más allá del testeo: Experimentación guiada

Mientras los flujos guiados son lineales (paso 1→2→3), los **laboratorios** son
entornos abiertos donde el desarrollador experimenta libremente con datos reales
de la base de datos ya poblada.

### 4.5.1 🎨 LAB — Creador de Plantillas (Roles y Usuarios)

**El desarrollador NO crea roles desde cero.** bAuth ya tiene 368 roles en 7 tiers
con políticas, verbos, átomos y métodos pre-configurados. El desarrollador **parte de
una plantilla base** (ej: CAJERO) y la personaliza para su aplicación. Los usuarios
que cree serán los usuarios finales de su sistema.

```
┌──────────────────────────────────────────────────────────────────┐
│  🎨 CREADOR DE PLANTILLAS — Personaliza tu Rol                   │
│  ─────────────────────────────────────────────────────────────── │
│                                                                  │
│  PASO 1: Elegir plantilla base                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Plantillas disponibles (368):                               │ │
│  │  🔍 Buscar: [caj___________________]                         │ │
│  │                                                              │ │
│  │  ☑ CAJERO (BIZ_N1) — 12 apps, Límite $2,000, Lun-Vie 8-18  │ │
│  │    D1: Tryton(sale_pos, account_invoice, party)              │ │
│  │    D3: FAC_EMITIR($2K), COBRO_RECIBIR($5K), CIERRE_CAJA     │ │
│  │    D4: Lun-Vie 8-18 │ D9: PASSWORD+TOTP │ 14 políticas      │ │
│  │                                                              │ │
│  │  [USAR CAJERO COMO BASE]  [VER DETALLE COMPLETO]            │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  PASO 2: Personalizar cada dominio (solo lo que necesita cambiar)│
│  ┌─── D1 LÓGICO — Basado en CAJERO ─────────────────────────┐   │
│  │  🏢 Zonas: AREA-CAJA (heredado)                           │   │
│  │  📦 Apps: Tryton                                          │   │
│  │     ☑ sale_pos (READ, WRITE, EXEC) ← heredado             │   │
│  │     ☐ account_invoice (READ) ← lo desmarco, no lo necesita│   │
│  │     ☑ party (READ) ← heredado                             │   │
│  │     [➕ Agregar app de mi sistema: mi_pos.consultar]      │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌─── D3 FINANCIERO — Basado en CAJERO ─────────────────────┐   │
│  │  FAC_EMITIR: $2,000/día → [$5,000] ← actualizo el límite │   │
│  │  COBRO_RECIBIR: $5,000 → sin cambios                      │   │
│  │  CIERRE_CAJA: ☑ heredado                                  │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌─── D4 TEMPORAL — Basado en CAJERO ───────────────────────┐   │
│  │  Lun-Vie 8-18 → [Lun-Dom 6-22] ← amplío cobertura        │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌─── D9 CREDENCIALES — Basado en CAJERO ───────────────────┐   │
│  │  ☑ PASSWORD (heredado)  ☑ TOTP (heredado)                │   │
│  │  ☑ WEBAUTHN_PWDLESS ← agrego, necesito phishing-resistant│   │
│  │  Flujo: standard_login → agrego paso 3: WEBAUTHN          │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  PASO 3: Guardar y crear usuarios de prueba                      │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Nuevo Rol: CAJERO_MI_APP (basado en CAJERO, BIZ_N1)       │ │
│  │  Cambios: D1 +mi_pos, D3 $2K→$5K, D4 Lun-Dom 6-22,        │ │
│  │           D9 +WEBAUTHN                                       │ │
│  │                                                              │ │
│  │  Usuarios de prueba:                                         │ │
│  │  👤 juan.perez → CAJERO_MI_APP                              │ │
│  │  👤 maria.lopez → CAJERO_MI_APP                             │ │
│  │  👤 admin.sistema → CAJERO_MI_APP + SUPERVISOR              │ │
│  │                                                              │ │
│  │  [🧪 PROBAR AUTENTICACIÓN]  [💾 GUARDAR PLANTILLA]         │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  PASO 4: Probar end-to-end                                       │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  1. [EMITIR TOKEN] para maria.lopez                         │ │
│  │     ← JWT Ed25519 válido, claims: {sub, tenant, loa, ...}  │ │
│  │                                                              │ │
│  │  2. [EVALUAR ACCESO] maria.lopez → mi_pos.consultar        │ │
│  │     ← {"verdict": "allow", "fastpath": true, "latency": 0.3}│ │
│  │                                                              │ │
│  │  3. [EVALUAR ACCESO] maria.lopez → factura_emitir($6,000)  │ │
│  │     ← {"verdict": "deny", "reason": "Excede límite diario"} │ │
│  │     (el límite es $5,000, y ella quiso $6,000)              │ │
│  │                                                              │ │
│  │  ✅ La validación ocurrió en el servidor bAuth.              │ │
│  │  ✅ Mi app solo llamó rpc.Call("bauth.access.evaluate", p)  │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  PASO 5: Copiar código de integración                            │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  // ESTO es todo lo que necesitas en tu app:                 │ │
│  │                                                              │ │
│  │  // Go                                                        │ │
│  │  params := map[string]interface{}{                            │ │
│  │      "atom_slug": "mi_pos.consultar",                        │ │
│  │      "user_uuid": userUUID,                                   │ │
│  │  }                                                            │ │
│  │  result, _ := rpc.Call("bauth.access.evaluate", params)      │ │
│  │  if result["verdict"] == "allow" { ... }                      │ │
│  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

**Principio fundamental:**
- Las plantillas base (CAJERO, SUPERVISOR, etc.) viven en bAuth
- El desarrollador las personaliza, no las reconstruye
- Los usuarios que crea son los usuarios finales de su aplicación
- Cada click en su app se valida en bAuth, no en la app
- El login de su app autentica contra bAuth, bAuth provee el JWT de sesión
- Su app solo pregunta: "¿puede este usuario ejecutar este átomo?"
- bAuth responde: "SÍ/NO" con todos los dominios evaluados
- **El desarrollador está limitado por su plan (BASIC: 5 roles, 100 usuarios, 3 dominios)**

### 4.5.2 🔐 LAB — Token Lab (Las 4 variantes del token bAuth)

El desarrollador experimenta con **todas las variantes del token** usando los
5 usuarios de prueba que YA existen en la VPS. Cada variante está diseñada para
un mercado distinto. **Todas funcionan hoy contra `13.140.128.230:9450`.**

#### Usuarios de prueba disponibles (YA poblados en la VPS)

| Usuario | UUID | Rol | Átomos activos | Tier |
|---------|------|-----|:---:|:---:|
| `test_superadmin` | `019f06db-62a6-77b1-b581-4c37e3aeee9f` | supervisor | **42** | SU |
| `test_gerente` | `019f06db-62a9-729c-89ea-1a2fcc714c12` | gerente | **42** | BIZ_N1 |
| `test_contador` | `019f06db-62a9-7323-90a3-1c8b2880408f` | contador | **22** | BIZ_N4 |
| `test_cajero` | `019f06db-62a9-73ab-a85a-f5d12f20233d` | cajero | **8** | BIZ_N5 |
| `test_cliente` | `019f06db-62a9-7551-b33c-12583be0ed1f` | sin rol | **0** | — |

#### Variante 1 — Token Liviano (Identidad pura, ~1.1 KB)

**Mercado:** Apps conectadas. El PDP evalúa server-side. El token lleva solo identidad.

```
┌─── VARIANTE 1: TOKEN LIVIANO (include_mask: false) ──────────┐
│                                                                │
│  Usuario: [test_cajero ▼]                                      │
│  Parámetros:  include_mask: false (default)                    │
│                                                                │
│  [EMITIR TOKEN]                                                │
│  ← {                                                           │
│      "algorithm": "EdDSA",                                     │
│      "jwt_size_chars": 1112,                                   │
│      "jwt": "eyJhbGciOiJFZDI1NTE5IiwidHlwIjoiSldUIn0...",     │
│      "merkle_leaf_keccak256": "0xa1b2...c3d4",                 │
│      "token_sha256": "0xe5f6...a7b8"                            │
│    }                                                            │
│                                                                │
│  [DECODIFICAR JWT]                                             │
│  ┌─── HEADER ──────────────────────────────────────────────┐  │
│  │ {"alg": "EdDSA", "typ": "JWT"}                           │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌─── PAYLOAD ─────────────────────────────────────────────┐  │
│  │ "sub": "019f06db-62a9-73ab-a85a-f5d12f20233d"           │  │
│  │ "iss": "bauth.sbos.bo"                                   │  │
│  │ "ctx_id": "ctx-019f06db-..."                             │  │
│  │ "tenant_id": "019f06db-..."                              │  │
│  │ "loa": 2                                                 │  │
│  │ "acr": "sbos_aal2"                                       │  │
│  │ "iat": 1719442200, "exp": 1719471000, "nbf": 1719442200  │  │
│  │ "jti": "01abc-def456-ghi789"                             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  ❌ NO contiene: roles, permisos, bitmasks, átomos              │
│  ✅ Tamaño: ~1.1 KB │ Firma: Ed25519 (64 bytes)               │
│  ✅ Velocidad de firma: ~50 µs                                 │
└────────────────────────────────────────────────────────────────┘
```

#### Variante 2 — Token + RolBitMask Cookie (Offline/Contingencia)

**Mercado:** POS en sucursal remota, kioskos, lectores NFC. Necesitan FastPath
local <0.5ns sin consultar al PDP.

```
┌─── VARIANTE 2: TOKEN + ROLBITMASK (include_mask: true) ───────┐
│                                                                │
│  Usuario: [test_gerente ▼]                                     │
│  Parámetros:  include_mask: ☑ true                             │
│                                                                │
│  [EMITIR TOKEN]                                                │
│  ← {                                                           │
│      "jwt": "eyJhbGciOiJFZDI1NTE5IiwidHlwIjoiSldUIn0...",     │
│      "rolbitmask": {                                            │
│        "active_count": 42,                                      │
│        "base64": "eyJuYW1lIjoiSm9obiBEb2UiLC...",  ← 968 chars │
│        "active_positions": [1,5,12,27,89,156,427,891,...]     │
│      }                                                          │
│    }                                                            │
│                                                                │
│  ┌─── ROLBITMASK ──────────────────────────────────────────┐  │
│  │  Formato:    One-hot, 91 palabras u64, 5,808 bits        │  │
│  │  Transporte: Cookie bAuth_mask (NO va en el JWT)         │  │
│  │  TTL:        30s (sincronizado con Redis cache)          │  │
│  │  Uso:        FastPath local <0.5ns sin consultar PDP     │  │
│  │                                                           │  │
│  │  Active positions (42):                                    │  │
│  │  ┌────┬────────┬──────────────────────────────────────┐  │  │
│  │  │  # │ Pos    │ Átomo                                 │  │  │
│  │  │  1 │      1 │ tryton.g1.d1.nuevo                    │  │  │
│  │  │  2 │      5 │ tryton.g1.d1.editar                   │  │  │
│  │  │  3 │     12 │ tryton.g1.d1.eliminar                 │  │  │
│  │  │ ...│    ... │ ...                                    │  │  │
│  │  │ 42 │    891 │ fin.factura.emitir                     │  │  │
│  │  └────┴────────┴──────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  💡 Diferencia: sin mask → 1,112 chars                           │
│                 con mask → 2,080 chars (+968 solo en respuesta) │
│                 El JWT sigue pesando 1.1 KB en ambos casos      │
└────────────────────────────────────────────────────────────────┘
```

#### Variante 3 — Token + Anclaje Blockchain D12 (Merkle Proof)

**Mercado:** Auditoría externa, compliance ISO 27001, verificación sin confiar en el issuer.

```
┌─── VARIANTE 3: TOKEN + BLOCKCHAIN (anchor: true) ──────────────┐
│                                                                │
│  Usuario: [test_superadmin ▼]                                  │
│  Parámetros:  anchor: ☑ true                                   │
│                                                                │
│  [EMITIR TOKEN]                                                │
│  ← {                                                           │
│      "jwt": "eyJhbGciOiJFZDI1NTE5IiwidHlwIjoiSldUIn0...",     │
│      "token_sha256": "0xe5f6...a7b8",                           │
│      "merkle_leaf_keccak256": "0xa1b2...c3d4",                  │
│      "merkle_root": "0x8f3a...b21c",                            │
│      "tx_hash": "0x7d3f...",                                    │
│      "block_number": 1234567,                                   │
│      "network": "besu-qbft"                                     │
│    }                                                            │
│                                                                │
│  ┌─── CADENA DE ANCLAJE ───────────────────────────────────┐  │
│  │                                                          │  │
│  │  JWT (1.1 KB)                                            │  │
│  │    │                                                     │  │
│  │    ▼ SHA-256                                             │  │
│  │  token_sha256: 0xe5f6...a7b8                             │  │
│  │    │                                                     │  │
│  │    ▼ Keccak-256 (post-cuántico resistente)               │  │
│  │  merkle_leaf: 0xa1b2...c3d4                              │  │
│  │    │                                                     │  │
│  │    ▼ Merkle Tree (batch de 200 eventos)                  │  │
│  │  merkle_root: 0x8f3a...b21c                              │  │
│  │    │                                                     │  │
│  │    ▼ Transacción Besu QBFT                                │  │
│  │  tx_hash: 0x7d3f... │ Bloque: #1,234,567                 │  │
│  │                                                          │  │
│  │  🔒 Bloque confirmado: 15,432 validaciones               │  │
│  │  🔒 Gas usado: 21,000 │ Precio: 12 Gwei                  │  │
│  │  🔒 Red: Besu QBFT (4 validadores, permissioned)         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌─── VERIFICACIÓN DE INTEGRIDAD ──────────────────────────┐  │
│  │  [VERIFICAR MERKLE PROOF]                                  │  │
│  │                                                            │  │
│  │  1. Calcular SHA-256 del JWT                              │  │
│  │     → 0xe5f6...a7b8                                        │  │
│  │  2. Calcular Keccak-256 del SHA-256                        │  │
│  │     → 0xa1b2...c3d4                                        │  │
│  │  3. Reconstruir raíz con Merkle proof (4 hashes hermanos) │  │
│  │     → 0x8f3a...b21c                                        │  │
│  │  4. Comparar con raíz en blockchain                        │  │
│  │     → 0x8f3a...b21c ✅ COINCIDEN                           │  │
│  │                                                            │  │
│  │  ✅ VERIFICADO — El token no fue alterado                  │  │
│  │  ✅ El evento existe y está anclado en el bloque #1,234,567│  │
│  │  ✅ Verificable SIN acceso al daemon bAuth                 │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  [EXPORTAR MERKLE PROOF para auditoría] → archivo JSON         │
└────────────────────────────────────────────────────────────────┘
```

#### Variante 4 — Token RS256 Legacy (Compatibilidad Enterprise)

**Mercado:** Empresas con infraestructura legacy que no soportan Ed25519.

```
┌─── VARIANTE 4: RS256 LEGACY (algorithm: RS256) ────────────────┐
│                                                                │
│  Usuario: [test_contador ▼]                                    │
│  Parámetros:  algorithm: RS256                                  │
│                                                                │
│  [EMITIR TOKEN]                                                │
│  ← {                                                           │
│      "algorithm": "RS256",                                      │
│      "jwt_size_chars": 2048,                                    │
│      "jwt": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."          │
│    }                                                            │
│                                                                │
│  💡 Solo disponible si configurado en bauth.toml:               │
│     engines.keycloak.legacy_rsa = true                          │
└────────────────────────────────────────────────────────────────┘
```

#### Comparativa de las 4 variantes

```
┌──────────────────────────────────────────────────────────────────┐
│              │ Variante 1  │ Variante 2  │ Variante 3 │ Var. 4  │
│              │ LIVIANO     │ +MASK       │ +BLOCKCHAIN│ LEGACY  │
│  ────────────┼─────────────┼─────────────┼────────────┼─────────│
│  Algoritmo   │ Ed25519     │ Ed25519     │ Ed25519    │ RS256   │
│  Tamaño JWT  │ 1.1 KB      │ 1.1 KB      │ 1.1 KB     │ ~2 KB   │
│  Tamaño resp │ 1.1 KB      │ 2.1 KB      │ 1.5 KB     │ ~2 KB   │
│  Velocidad   │ 50 µs       │ 50 µs       │ 50 µs      │ 2,000 µs│
│  Offline     │ ❌          │ ✅          │ ❌         │ ❌      │
│  Blockchain  │ ❌          │ ❌          │ ✅         │ ❌      │
│  Verificable │ Con JWKS    │ Con JWKS    │ Sin issuer │ Con JWKS│
│  sin issuer  │             │             │            │         │
│  Mercado     │ Apps        │ POS/Kioskos │ Compliance │ Legacy  │
│              │ conectadas  │ NFC/Offline │ Auditoría  │ Enterp. │
└──────────────────────────────────────────────────────────────────┘
```

#### Snippets de código para cada variante

```go
// Variante 1: Token liviano (app conectada)
params := map[string]interface{}{
    "user_uuid": userUUID,
    // include_mask: false por defecto
}
result, _ := rpc.Call("bauth.token.issue", params)
jwt := result["jwt"].(string)

// Variante 2: Token + RolBitMask (offline/contingencia)
params := map[string]interface{}{
    "user_uuid":    userUUID,
    "include_mask": true,
}
result, _ := rpc.Call("bauth.token.issue", params)
jwt := result["jwt"].(string)
maskBase64 := result["rolbitmask"]["base64"].(string)

// Variante 3: Token + Blockchain (auditoría)
params := map[string]interface{}{
    "user_uuid": userUUID,
    "anchor":    true,
}
result, _ := rpc.Call("bauth.token.issue", params)
merkleLeaf := result["merkle_leaf_keccak256"].(string)
txHash := result["tx_hash"].(string)

// Variante 4: RS256 (legacy enterprise)
// Requiere: engines.keycloak.legacy_rsa = true en bauth.toml
params := map[string]interface{}{
    "user_uuid":  userUUID,
    "algorithm":  "RS256",
}
result, _ := rpc.Call("bauth.token.issue", params)
```

#### Flujo completo: Token → Validación → Autorización

Este flujo se puede ejecutar completo en bAuthDEV con un solo botón:

```
1. [EMITIR TOKEN] para test_cajero
   ← JWT Ed25519 emitido, 8 átomos activos

2. [VALIDAR TOKEN]
   ← valid: true, subject: 019f06db-..., issuer: bauth.sbos.bo

3. [EVALUAR ACCESO] test_cajero → tryton.g1.d1.nuevo (átomo 1)
   ← PERMITIDO — átomo 1 presente en RolBitMask (posición 1)

4. [EVALUAR ACCESO] test_cajero → tryton.g1.d3.nuevo (átomo 43)
   ← DENEGADO — átomo 43 ausente del RolBitMask

5. [VER JWKS] — Clave pública para verificar el JWT externamente
   ← {"keys": [{"kty": "OKP", "crv": "Ed25519", "alg": "EdDSA", "use": "sig", ...}]}
```

#### CUÁNDO usar cada variante — Guía para el desarrollador

Esta es la decisión MÁS IMPORTANTE que el desarrollador debe entender:

```
┌──────────────────────────────────────────────────────────────────────┐
│  ¿NECESITAS QUE TU APP FUNCIONE SIN CONEXIÓN AL SERVIDOR BAUTH?     │
│                                                                      │
│  ┌───── NO ─────────────────────────────────────────────────────┐   │
│  │  Usa el token LIVIANO (include_mask: false, default)         │   │
│  │  • JWT de 1.1 KB                                             │   │
│  │  • Cada click en tu app consulta al servidor bAuth           │   │
│  │  • El servidor evalúa los 12 dominios y retorna SÍ/NO        │   │
│  │  • Ideal para: apps web, apps móviles con internet,          │   │
│  │    sistemas corporativos con conexión permanente             │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌───── SÍ ─────────────────────────────────────────────────────┐   │
│  │  Usa el token + MASK (include_mask: true)                    │   │
│  │  • JWT de 1.1 KB + RolBitMask de 968 chars (cookie aparte)  │   │
│  │  • Cuando el servidor NO responde, tu app valida LOCALMENTE  │   │
│  │    usando la cookie bAuth_mask (operación <0.5ns)            │   │
│  │  • Cuando el servidor vuelve, tus eventos se reconcilian     │   │
│  │  • Ideal para: POS en sucursales remotas, kioskos NFC,       │   │
│  │    lectores de puerta, apps offline-first, IoT, minería      │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ⚠️ SIN MASK = sin contingencia. Si el servidor no responde,        │
│     tu app NO PUEDE validar permisos. El usuario queda bloqueado.   │
│                                                                      │
│  ⚠️ CON MASK = contingencia activa. La cookie dura 30 segundos.     │
│     Debes renovarla antes de que expire si el usuario sigue activo.  │
└──────────────────────────────────────────────────────────────────────┘
```

#### Patrón de Fallback — El código que el desarrollador integra en su app

Este es el patrón completo que bAuthDEV enseña. El desarrollador copia este
código a su proyecto y tiene contingencia offline funcionando:

```
FUNCIÓN verificarPermiso(atomSlug, userUuid):

  // ── INTENTO 1: MODO NORMAL (servidor) ──────────────────────
  TRY:
      respuesta = rpc.Call("bauth.access.evaluate", {
          atom_slug: atomSlug,
          user_uuid: userUuid
      })
      return respuesta.veredicto  // "PERMITIDO" o "DENEGADO"

  CATCH (timeout, connection_refused, server_error):

      // ── INTENTO 2: MODO CONTINGENCIA (cookie local) ─────────
      TRY:
          base64 = leerCookie("bAuth_mask")  // 968 chars
          bytes = base64Decode(base64)
          pos = catalogoAtomos.obtenerPosicion(atomSlug)

          // FastPath local: 3 líneas, <0.5ns
          byte = bytes[pos / 8]
          bit = (byte >> (pos % 8)) & 1
          return bit == 1 ? "PERMITIDO" : "DENEGADO"

      CATCH (sin_cookie, cookie_expirada):
          // Sin cookie → DENEGAR por seguridad
          return "DENEGADO"
```

**Implementación de referencia en cada lenguaje:**

```go
// Go — FastPath local para modo contingencia
func VerificarPermisoLocal(rolBitmaskBase64 string, atomPosition int) (bool, error) {
    bytes, err := base64.RawURLEncoding.DecodeString(rolBitmaskBase64)
    if err != nil { return false, err }
    if atomPosition/8 >= len(bytes) { return false, nil }
    return (bytes[atomPosition/8] >> (atomPosition % 8)) & 1 == 1, nil
}

func VerificarPermiso(rpc *JsonRpcClient, atomSlug, userUuid, maskBase64 string, atomPosition int) bool {
    // Intento 1: servidor
    resp, err := rpc.Call("bauth.access.evaluate", map[string]interface{}{
        "atom_slug": atomSlug, "user_uuid": userUuid,
    })
    if err == nil {
        return resp["veredicto"].(string) == "PERMITIDO"
    }
    // Intento 2: cookie local
    ok, _ := VerificarPermisoLocal(maskBase64, atomPosition)
    return ok
}
```

```python
# Python — FastPath local para modo contingencia
import base64

def verificar_permiso_local(rolbitmask_base64: str, atom_position: int) -> bool:
    mask = base64.urlsafe_b64decode(rolbitmask_base64 + "==")
    if atom_position // 8 >= len(mask):
        return False
    return (mask[atom_position // 8] >> (atom_position % 8)) & 1 == 1

def verificar_permiso(rpc, atom_slug, user_uuid, mask_base64, atom_position):
    # Intento 1: servidor
    try:
        resp = rpc.call("bauth.access.evaluate", {
            "atom_slug": atom_slug, "user_uuid": user_uuid
        })
        return resp["veredicto"] == "PERMITIDO"
    except (TimeoutError, ConnectionError):
        pass
    # Intento 2: cookie local
    return verificar_permiso_local(mask_base64, atom_position)
```

```javascript
// JavaScript — FastPath local para modo contingencia
function verificarPermisoLocal(rolBitmaskBase64, atomPosition) {
    const bytes = Uint8Array.from(atob(rolBitmaskBase64), c => c.charCodeAt(0));
    if (Math.floor(atomPosition / 8) >= bytes.length) return false;
    return (bytes[Math.floor(atomPosition / 8)] >> (atomPosition % 8)) & 1 === 1;
}

async function verificarPermiso(rpc, atomSlug, userUuid, maskBase64, atomPosition) {
    // Intento 1: servidor
    try {
        const resp = await rpc.call("bauth.access.evaluate", {
            atom_slug: atomSlug, user_uuid: userUuid
        });
        return resp.veredicto === "PERMITIDO";
    } catch (e) {
        // Intento 2: cookie local
        return verificarPermisoLocal(maskBase64, atomPosition);
    }
}
```

```rust
// Rust — FastPath local para modo contingencia
pub fn verificar_permiso_local(mask_base64: &str, atom_position: usize) -> bool {
    use base64::Engine;
    let bytes = base64::engine::general_purpose::URL_SAFE_NO_PAD
        .decode(mask_base64).unwrap_or_default();
    if atom_position / 8 >= bytes.len() { return false; }
    (bytes[atom_position / 8] >> (atom_position % 8)) & 1 == 1
}

pub async fn verificar_permiso(
    rpc: &JsonRpcClient, atom_slug: &str, user_uuid: &str,
    mask_base64: &str, atom_position: usize,
) -> bool {
    // Intento 1: servidor
    match rpc.call("bauth.access.evaluate", serde_json::json!({
        "atom_slug": atom_slug, "user_uuid": user_uuid
    })).await {
        Ok(resp) => resp["veredicto"].as_str() == Some("PERMITIDO"),
        Err(_) => verificar_permiso_local(mask_base64, atom_position),
    }
}
```

#### Resumen: Lo que el desarrollador DEBE entender

| Concepto | Explicación |
|----------|-------------|
| **include_mask: false** | Token liviano. Sin contingencia. Cada click → servidor. App con internet. |
| **include_mask: true** | Token + cookie. Con contingencia. Si servidor no responde → valida local. |
| **Cookie bAuth_mask** | RolBitMask en base64 (968 chars). NO es JWT. Es el vector de bits. |
| **FastPath local** | `(bytes[pos/8] >> (pos%8)) & 1`. 3 líneas. <0.5ns. Igual que el servidor. |
| **TTL de la cookie** | 30 segundos. Renovar antes de que expire. Sincronizado con Redis. |
| **¿Quién decide?** | **La app del desarrollador.** Intenta servidor → si falla → cookie local. |
| **Seguridad** | La cookie SOLO da permisos que el usuario YA tenía. No puede escalar. |
| **Reconciliación** | Cuando vuelve la conexión, los eventos offline se envían al PDP para auditoría. |

### 4.5.3 ⛓ LAB — Blockchain Lab (Anclaje y Verificación)

```
┌──────────────────────────────────────────────────────────────────┐
│  ⛓ BLOCKCHAIN LAB — Besu QBFT + Merkle Proofs                    │
│  ─────────────────────────────────────────────────────────────── │
│                                                                  │
│  ┌─── ANCLAJE DE EVENTOS ───────────────────────────────────┐   │
│  │  [ANCLAR EVENTO] event_id: evt_01Jabc...                  │   │
│  │  ← Lote #0042 creado (156 eventos pendientes)             │   │
│  │  ← Merkle Root: 0x8f3a...b21c                             │   │
│  │  [FORZAR ANCLAJE AHORA]                                    │   │
│  │  ← tx_hash: 0x7d3f... │ Bloque: #1,234,567 │ Gas: 21,000 │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─── VERIFICACIÓN DE INTEGRIDAD ───────────────────────────┐   │
│  │  Evento ID: [...]                                          │   │
│  │  [CALCULAR HASH] → SHA-256(evento)                         │   │
│  │  [CALCULAR MERKLE] → Keccak-256(leaf)                      │   │
│  │  [RECONSTRUIR RAÍZ] → usando Merkle proof (4 hashes)      │   │
│  │  [COMPARAR CON BLOCKCHAIN]                                  │   │
│  │  ← ✅ INTEGRIDAD CONFIRMADA                                │   │
│  │  El evento existe, no fue alterado y está anclado en el     │   │
│  │  bloque #1,234,567 de la red Besu QBFT del SBOS.           │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─── EXPORTAR PRUEBA PARA AUDITORÍA ──────────────────────┐   │
│  │  [EXPORTAR MERKLE PROOF] → archivo JSON                   │   │
│  │  {event_id, leaf, proof: [...], root, tx_hash, block}     │   │
│  │  Esta prueba es verificable SIN acceso al daemon bAuth.   │   │
│  └──────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

### 4.5.4 ✍️ LAB — Firma Digital Lab (Doble Motor)

```
┌──────────────────────────────────────────────────────────────────┐
│  ✍️ FIRMA DIGITAL LAB — Motor Interno + Motor Externo            │
│  ─────────────────────────────────────────────────────────────── │
│                                                                  │
│  ┌─── MOTOR INTERNO: Ed25519 (Vault PKI) ───────────────────┐   │
│  │  Documento: [CARGAR ARCHIVO] o [ESCRIBIR TEXTO]           │   │
│  │  Algoritmo: Ed25519 │ CA: Vault PKI Interna               │   │
│  │  [FIRMAR] → signature: 0x... (64 bytes)                   │   │
│  │  [VERIFICAR] → ✅ Válida                                   │   │
│  │  Uso: sagas, JWT M2M, eventos CDC, logs auditoría         │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─── MOTOR EXTERNO: RSA-SHA256 (ADSIB Bolivia) ────────────┐   │
│  │  Documento: [CARGAR FACTURA XML]                           │   │
│  │  Algoritmo: RSA 2048 + SHA-256 │ CA: ADSIB (ATT→ADSIB)   │   │
│  │  [FIRMAR] → signature: 0x... (256 bytes)                  │   │
│  │  [VERIFICAR CONTRA ADSIB] → ✅ Válida + CRL OK            │   │
│  │  Cumplimiento: Ley 164 Bolivia, SIN RND 102100000011      │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─── COMPARATIVA ──────────────────────────────────────────┐   │
│  │                  │ INTERNO          │ EXTERNO              │   │
│  │  Algoritmo       │ Ed25519          │ RSA-SHA256           │   │
│  │  CA              │ Vault PKI (propia)│ ADSIB (Bolivia)     │   │
│  │  Tamaño firma    │ 64 bytes         │ 256 bytes            │   │
│  │  Velocidad       │ ~50 µs           │ ~2,000 µs            │   │
│  │  Validez jurídica│ Interna SBOS     │ Nacional (Ley 164)   │   │
│  │  Uso principal   │ Tokens, logs     │ Facturación SIN      │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─── CÓDIGO DE INTEGRACIÓN ───────────────────────────────┐   │
│  │  Go:      sig, _ := rpc.Call("bauth.sign.internal", p)  │   │
│  │  Rust:    let sig = rpc.call("bauth.sign.internal", p)? │   │
│  │  Python:  sig = rpc.call("bauth.sign.internal", params) │   │
│  │  JS:      const sig = await rpc.call("bauth.sign...",p) │   │
│  └──────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

Basado en el análisis de Postman, Insomnia, Bruno, Yaak, Hoppscotch y herramientas blockchain RPC:

### 5.1 Funcionalidades heredadas de los mejores

| Funcionalidad | Inspiración | Implementación en bAuthDEV |
|---------------|-------------|---------------------------|
| **Colecciones** | Postman/Bruno | Guardar requests en carpetas, exportar/importar JSON, compartir vía Git |
| **Entornos** | Postman/Insomnia | Variables `{{host}}`, `{{port}}`, `{{tenant_id}}` con conjuntos predefinidos |
| **Historial** | Insomnia | Últimas 500 requests con posibilidad de re-ejecutar, duplicar, guardar |
| **Snippets** | Postman (codegen) | Generar código en Go, Rust, Python, JS, Dart, cURL |
| **Lotes** | Postman Collection Runner | Enviar múltiples requests JSON-RPC en batch (spec §6) |
| **Variables** | Postman (scopes) | `{{$guid}}`, `{{$timestamp}}`, `{{$randomInt}}` en params |

### 5.2 Funcionalidades ÚNICAS de bAuthDEV

| Funcionalidad | Descripción |
|---------------|-------------|
| **Catálogo vivo de métodos** | Lee los métodos directamente del daemon vía introspection. Siempre actualizado. |
| **Autocompletado JSON-RPC** | Al escribir `bauth.`, autocompleta método. Al escribir params, sugiere campos. |
| **Token Decoder integrado** | Decodifica JWT (header+payload+firma) con colores, verifica Ed25519, muestra expiración |
| **Merkle Proof Verifier** | Verifica que un evento no fue alterado: leaf → root → blockchain tx_hash |
| **Digital Signature Verifier** | Verifica firmas Ed25519 y RSA-SHA256 contra documentos cargados |
| **Params Builder** | En lugar de escribir JSON a mano, formulario dinámico que genera el JSON |
| **Flujos guiados (Wizards)** | "Probar GetContext", "Token + Blockchain", "Firma Digital", "Roles y SoD" |
| **Documentación en español** | Cada método documentado en español con ejemplos reales del DDL |
| **Simulador de contexto** | Simular diferentes ctx_id (con/sin permisos, diferentes ubicaciones) |
| **Exportar a cURL + nc** | Además de snippets de código, exportar comando directo para terminal |
| **Modo "Dif"** | Comparar dos respuestas JSON-RPC lado a lado (útil para debugging de regresiones) |

---

## 6. PLAN DE DESARROLLO — 5 FASES

### FASE 0 — ESQUELETO Y CONEXIÓN (3-4 días)

| # | Tarea |
|---|-------|
| 0.1 | `flutter create` + pubspec.yaml con 7 dependencias |
| 0.2 | **Editor de código JSON**: widget `CodeEditorWidget` con `jsonLanguageSupport()`, tema oscuro, números de línea, autocompletado bAuth |
| 0.3 | **Visor de respuesta JSON**: mismo editor en modo solo-lectura, JSON formateado y colapsable |
| 0.4 | **Consola segura de comandos**: widget `SecureRpcConsole` — solo ejecuta metodos JSON-RPC validados |
| 0.5 | Conexion SSH interna transparente — `dartssh2` con usuario limitado `bauthdev` (sin shell, sin root) |
| 0.6 | Layout: Explorador | Cinta de bloques (comando+resultado) | Consola segura inferior |
| 0.7 | `RpcClient` — WebSocket JSON-RPC 2.0 (conexión directa :9450) |
| 0.8 | Splitters redimensionables entre paneles (arrastrar bordes) |
| 0.9 | Persistencia: host SSH, tema, historial de requests en `shared_preferences` |

**DoD:** Editor JSON funcional con resaltado de sintaxis. Terminal SSH responde a comandos.
Health check OK tanto por WebSocket como por `nc -U /tmp/bauth/bauth.sock`.

### FASE 1 — CATÁLOGO DE MÉTODOS Y EDITOR (3-4 días)

| # | Tarea |
|---|-------|
| 1.1 | `MethodCatalog` — 47 métodos con nombre, descripción, params, ejemplo |
| 1.2 | Explorador: TreeView con categorías expandibles y buscador |
| 1.3 | Editor: autocompletado de método, sugerencias de params |
| 1.4 | Selector de método → carga params template → pre-llena el editor |
| 1.5 | Documentación inline: descripción en español, tipos de params, valores esperados |

**DoD:** Navegar el catálogo, seleccionar `bauth.access.evaluate`, ver params pre-llenados, enviar.

### FASE 2 — SNIPPETS, RESPUESTA AVANZADA Y HERRAMIENTAS (4-5 días)

| # | Tarea |
|---|-------|
| 2.1 | **Snippet Generator**: Go, Rust, Python, JS, Dart, cURL |
| 2.2 | Visor JSON con colapsado/expansión, resaltado de sintaxis, copia de paths |
| 2.3 | **Token Decoder**: decodificar JWT, verificar firma Ed25519, mostrar claims |
| 2.4 | **Merkle Verifier**: verificar leaf → root → tx_hash |
| 2.5 | **Firma Verifier**: verificar Ed25519 + RSA-SHA256 contra documento |

**DoD:** Snippets funcionales en 6 lenguajes. Token decoder funcional. Merkle verifier funcional.

### FASE 3 — FLUJOS GUIADOS, HISTORIAL, COLECCIONES (4-5 días)

| # | Tarea |
|---|-------|
| 3.1 | 4 Wizards: "Mi primer GetContext", "Token + Blockchain", "Firma Digital", "Roles y SoD" |
| 3.2 | **Historial**: últimas 500 requests, filtro por método/fecha, re-ejecutar, duplicar |
| 3.3 | **Colecciones**: guardar requests en carpetas, exportar/importar JSON |
| 3.4 | **Entornos**: variables `{{host}}`, `{{port}}`, `{{tenant_id}}` con conjuntos predefinidos |
| 3.5 | Batch requests: enviar array JSON-RPC y ver resultados individuales |

**DoD:** Completar wizard de GetContext, guardar request en colección, exportar colección JSON.

### FASE 4 — POLISH, EXPORTACIÓN, BUILD RELEASE (3-4 días)

| # | Tarea |
|---|-------|
| 4.1 | Modo "Dif": comparar dos respuestas lado a lado |
| 4.2 | Notificaciones JSON-RPC (sin `id`): probar envío y recepción |
| 4.3 | Exportar colección completa + historial |
| 4.4 | Tema oscuro profesional (mismo de bAuth Desktop) |
| 4.5 | `flutter build linux/windows/macos --release` |
| 4.6 | `.deb`, `.rpm`, `.AppImage`, `.msi`, `.dmg` |

**DoD:** Build release para 3 plataformas. Exportar colección. Modo dif funcional.

---

## 7. DEPENDENCIAS TÉCNICAS

```yaml
dependencies:
  flutter:
    sdk: flutter
  # ── EDITOR DE CÓDIGO ────────────────────────────
  duskmoon_code_engine: ^1.6.0   # Editor multi-lenguaje (CodeMirror 6 en Dart puro)
                                  # Soporta: JSON, Go, Rust, Python, JS, PHP, Dart, YAML, Bash, MD
  # ── CONEXIÓN ────────────────────────────────────
  web_socket_channel: ^2.4.0     # Transporte WebSocket (JSON-RPC directo :9450)
  dartssh2: ^2.0.0               # Cliente SSH (interno, transparente, el dev no lo ve)
  # ── UTILIDADES ──────────────────────────────────
  provider: ^6.1.0               # State management
  window_manager: ^0.3.0         # Ventana desktop
  shared_preferences: ^2.3.0     # Persistencia (host SSH, tema, historial)
```

**7 dependencias.** `duskmoon_code_engine` es el corazón: editor Monaco-grade en Dart puro
sin WebView. Soporta los 10 lenguajes que necesitamos. Linux, Windows, macOS.
Binario objetivo < 25 MB.

---

## 8. MÉTRICAS DE ÉXITO

| Métrica | Objetivo |
|---------|:---:|
| Tiempo desde "descargar" hasta "primer GetContext exitoso" | < 5 minutos |
| Tiempo hasta entender todos los métodos disponibles | < 1 hora |
| Binario Linux | < 15 MB |
| Requests pre-armados (wizards) | 4 flujos completos |
| Lenguajes con snippets | 6 (Go, Rust, Python, JS, Dart, cURL) |
| Satisfacción desarrollador | "No necesito leer el DDL para empezar" |

---

## 9. REFERENCIAS

| Fuente | Qué aportó al diseño |
|--------|---------------------|
| **Postman** | Colecciones, entornos, variables scoped, snippets, runner |
| **Insomnia** | WebSocket nativo, diseño de 3 paneles, Git sync |
| **Bruno** | Colecciones como archivos JSON en Git, offline-first |
| **Yaak** | Minimalismo, Tauri+Rust, lección de no forzar cloud |
| **KraiNode / BuildBear** | JSON-RPC nativo, catálogo de métodos, playground |
| **mcp-tester / Jaysonic** | Pruebas batch, notificaciones, validación de schema |
| **BAUTH-VISION.md** | `bos.GetContext()`, 3 productos, 12 dominios, token 4-capas |
| **BAUTH-CRUD-ROLES-USUARIOS.md** | Flujos de prueba reales con datos del DDL |
| **PLAN-DESKTOP-BAUTH.md** | Stack técnico, tema visual, estructura de proyecto |

---

*PLAN-BAUTHDEV-RPC-TESTER v1.0 · 2026-06-27 · SKULL · SBOS*
*Basado en: investigación de 15 herramientas API/RPC · BAUTH-VISION.md · 47 handlers JSON-RPC · Postman + Insomnia + Bruno + Yaak + KraiNode*
