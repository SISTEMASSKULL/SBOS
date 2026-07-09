# BAUTH-CATALOGO-PRODUCTOS-VENDIBLES — Portfolio Comercial SBOS

**Versión:** 1.0.0 · **Fecha:** 2026-06-22 · **Clasificación:** CONFIDENCIAL  
**Propósito:** Documentar cómo funciona cada producto desde la perspectiva del cliente.

---

## Visión General

```
┌──────────────────────────────────────────────────────────────────┐
│                    SBOS — LÍNEA DE PRODUCTOS                       │
│                                                                    │
│  Producto A        Producto B       Producto C      Producto D     │
│  Compliance        Billetera        IAM             Trust Layer    │
│  -in-a-Box         White-Label      Soberano                       │
│       │                 │                │               │         │
│  "No quiero que    "Quiero lanzar  "Necesito       "Necesito      │
│   la ASFI me        mi propia       controlar       probar que     │
│   multe"            billetera"      quién accede    esto no fue    │
│                                     a qué"          alterado"      │
│       │                 │                │               │         │
│  Mercado:           Mercado:         Mercado:        Mercado:      │
│  Bancos, Fintech    Fintech,         Empresas,       Legal, Gov,   │
│  Cooperativas       Cooperativas     Retail, Salud   Universidades │
│                                                                    │
│  ─────────────────────────────────────────────────────────────── │
│                        PRODUCTO E                                  │
│                     IdP Rentado (IdP-as-a-Service)                  │
│  "Quiero que mis usuarios hagan login con su sistema,             │
│   no quiero construir autenticación desde cero"                    │
│  Mercado: Startups, SaaS, E-commerce, Clínicas                     │
└──────────────────────────────────────────────────────────────────┘
```

---

## PRODUCTO A — Compliance-in-a-Box

### ¿Para quién es?

Bancos, cooperativas, financieras y casas de cambio que necesitan cumplir
con regulaciones ASFI/UIF sin construir su propio sistema de compliance.

### El problema del cliente

```
ASFI exige:
  ✅ Límites por transacción (no más de $X por operación)
  ✅ Doble aprobación para montos altos
  ✅ Separación de funciones (el que crea no aprueba)
  ✅ Trazabilidad de cada decisión de autorización
  ✅ Auditoría inmutable de todos los accesos

Construir esto internamente: $100K-$500K + $50K/año en auditoría
```

### Cómo funciona

```
          App del Banco                          SBOS Compliance-in-a-Box
          ─────────────                          ────────────────────────
          
  Cajero hace clic en                          POST /api/v1/compliance/authorize
  "Transferir $15,000"                         {usuario, monto, tipo_operacion}
          │                                           │
          │                                   ┌───────┴────────┐
          │                                   │ D3 Financiero   │
          │                                   │ ¿$15,000 >      │
          │                                   │  límite $10K?   │
          │                                   │ → SÍ → DENEGAR  │
          │                                   └───────┬────────┘
          │                                           │
          │                                   ┌───────┴────────┐
          │                                   │ D11 Auditoría   │
          │                                   │ Registrar       │
          │                                   │ decisión WORM   │
          │                                   └───────┬────────┘
          │                                           │
          │                                   ┌───────┴────────┐
          │                                   │ D12 Blockchain  │
          │                                   │ Anclar hash en  │
          │                                   │ Arbitrum One    │
          │                                   └───────┬────────┘
          │                                           │
          ◄────── {autorizado: false,                │
                    razon: "Monto excede              │
                    límite ($10,000)",                │
                    evidencia: "0xabcd..."}           │
```

### Qué recibe el cliente

| Entregable | Descripción |
|-----------|------------|
| **API endpoint** | `POST /api/v1/{banco}/compliance/authorize` |
| **API key** | Autenticación por tenant, rotación 90 días |
| **Dashboard** | Transacciones bloqueadas, aprobaciones pendientes, alertas SoD |
| **Reporte regulatorio** | Exportable con ancla blockchain como evidencia de no-alteración |
| **Evidencia blockchain** | Cada decisión anclada en Arbitrum One, verificable públicamente |

### Planes

| Plan | TX/mes | Usuarios | SLA | Precio |
|------|--------|---------|-----|--------|
| **Gratuito** | 100 | 1 | Best effort | $0 |
| **Pro** | 10,000 | 10 | 99.9% | $500/mes |
| **Enterprise** | Ilimitado | Ilimitado | 99.99% | $2,000/mes |

---

## PRODUCTO B — Billetera White-Label

### ¿Para quién es?

Fintechs, cooperativas de ahorro y comercios que quieren lanzar su propia
billetera digital con su marca, sin construir el motor de cuentas ni la
infraestructura blockchain.

### El problema del cliente

```
Lanzar una billetera digital requiere:
  ❌ Motor de cuentas con double-entry contable
  ❌ Integración con blockchain
  ❌ KYC/AML compliance
  ❌ Seguridad de claves privadas (HSM)
  ❌ Integración con rieles de pago (QR BCB, ACP)
  ❌ $200K-$1M en desarrollo + 12-18 meses

Con Billetera White-Label:
  ✅ Todo listo en 2 semanas
  ✅ Con la marca del cliente
  ✅ $0 upfront + revenue share
```

### Cómo funciona (el cliente no ve esto)

```
┌─────────────────────────────────────────────────────────────┐
│              INFRAESTRUCTURA COMPARTIDA SBOS                  │
│                                                              │
│  Tenant: banco-union          Tenant: cooperativa-san-pedro  │
│  ┌────────────────────┐       ┌────────────────────────┐     │
│  │ Cuentas on-chain   │       │ Cuentas on-chain       │     │
│  │ bos_onchain_account│       │ bos_onchain_account    │     │
│  │ (aisladas)         │       │ (aisladas)             │     │
│  └────────────────────┘       └────────────────────────┘     │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │         MOTOR COMPARTIDO (multi-tenant)               │    │
│  │  • Liquidaciones (bos_onchain_settlement)            │    │
│  │  • Red Besu QBFT (4 validadores, 2s bloques)         │    │
│  │  • Custodia HSM (clave NUNCA sale)                   │    │
│  │  • KYC (D9 Credenciales)                             │    │
│  │  • MFA (D5 Biométrico)                               │    │
│  │  • Reconciliación on-chain↔PostgreSQL cada 15min     │    │
│  └──────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Custodia gestionada — el usuario NUNCA ve su clave

```
Usuario quiere transferir $500
  │
  ├── 1. Abre la app del Banco Unión
  ├── 2. Ingresa monto + destinatario
  ├── 3. bAuth evalúa:
  │       D3: ¿$500 ≤ límite? → SÍ
  │       D5: ¿MFA verificado? → Solicitar TOTP
  │       D10: ¿No hay conflicto SoD? → SÍ
  ├── 4. biedata construye la transacción
  ├── 5. Vault firma DENTRO del HSM (clave nunca sale)
  ├── 6. Transacción enviada a Besu QBFT
  └── 7. Confirmación en 2 segundos

El usuario nunca vio, tocó, ni supo que existía una clave privada.
```

### Modelos de negocio

| Modelo | Cómo funciona | Ejemplo |
|--------|-------------|---------|
| **Revenue Share** | 2% del volumen procesado | $500K/mes → $10K/mes para SBOS |
| **Licencia Base** | $2,000/mes + 0.5% del volumen | Predecible para ambas partes |

---

## PRODUCTO C — IAM Soberano

### ¿Para quién es?

Empresas medianas/grandes (retail, salud, logística, gobierno) que necesitan
control de acceso avanzado pero no quieren construir un sistema de identidad.

### El problema del cliente

```
Una cadena de supermercados tiene:
  • 50 sucursales
  • 2,000 empleados
  • 15 roles diferentes (cajero, supervisor, gerente, bodega, auditor...)
  • Necesitan que:
    - Cajero: solo cobre, no vea inventario
    - Supervisor: apruebe descuentos > 20%, no modifique nómina
    - Gerente: vea reportes financieros, no modifique precios
    - Auditor: vea todo, no modifique nada
    - Bodega: gestione stock, no vea ventas

  Solución típica: Active Directory + grupos + GPOs = $200K + 1 año
  Con IAM Soberano: $5/usuario/mes, listo en 1 semana
```

### Cómo funciona el alta de un empleado

```
RRHH contrata a María como Cajera Sucursal Centro
  │
  ├── 1. Admin entra al portal IAM del supermercado
  ├── 2. Crea usuario: maria.garcia@supermercado.com
  ├── 3. Selecciona RolTemplate: "ROL-CAJERO"
  ├── 4. El sistema automáticamente:
  │       ✅ Crea el usuario en Keycloak (realm aislado)
  │       ✅ Asigna el Rol BitMask del Cajero:
  │          - D1: POS.cobrar.nuevo ✅
  │          - D1: POS.cobrar.ver ✅
  │          - D1: Inventario.ver ❌ (NO tiene este bit)
  │          - D1: Nómina.editar ❌ (NO tiene este bit)
  │          - D3: límite $2,000 por transacción
  │          - D4: horario 08:00-18:00
  │          - D10: no puede delegar
  │       ✅ Envía email de bienvenida
  │       ✅ María configura MFA (TOTP en su teléfono)
  │
  └── 5. María ya puede iniciar sesión y cobrar

  Tiempo total: 3 minutos. Sin tocar Active Directory.
```

### Qué incluye

| Componente | Descripción |
|-----------|------------|
| 11 dominios | D1-D11 completos con BitMask Dual v3.0 |
| Keycloak realm | Aislado, 15 métodos de autenticación |
| Panel de admin | Crear/editar/desactivar usuarios y roles |
| MFA | TOTP, FIDO2, Passkey (configurable por rol) |
| Auditoría | Registro WORM de cada acceso y cambio |
| Cumplimiento | ISO 27001, NIST 800-63B, PCI DSS |

### Planes

| Plan | Usuarios mín | Precio/usuario/mes | SLA |
|------|-------------|-------------------|-----|
| **Starter** | 50 | $5 | 99.5% |
| **Business** | 500 | $3 | 99.9% |
| **Enterprise** | 5,000+ | Personalizado | 99.99% |

### Ejemplo de costo

```
Supermercado con 300 empleados, Plan Business:
  300 usuarios × $3/usuario/mes = $900/mes
  Incluye: 11 dominios, MFA, auditoría, panel de admin, soporte

vs. construir internamente:
  $200,000 desarrollo + $50,000/año mantenimiento
  = 18 años de IAM Soberano
```

---

## PRODUCTO D — Trust Layer

### ¿Para quién es?

Cualquier organización que necesite **demostrar que un documento o registro
no fue alterado**, sin revelar su contenido.

- **Firmas de auditoría:** probar que el informe no cambió después de emitirse
- **Estudios jurídicos:** probar que un contrato existía en cierta fecha
- **Gobierno:** transparencia verificable de actos administrativos
- **Universidades:** certificados de título inalterables
- **Cadena de suministro:** trazabilidad de cada paso sin exponer datos sensibles

### Cómo funciona

```
┌─────────────────────────────────────────────────────────────┐
│  CLIENTE                                SBOS TRUST LAYER     │
│                                                              │
│  Documento original                                         │
│  (NUNCA sale del                                              │
│   cliente)                                                   │
│       │                                                      │
│       │ SHA3-256(documento)                                   │
│       ▼                                                      │
│  hash = "a1b2c3d4..."                                        │
│       │                                                      │
│       │ POST /api/v1/trust/anchor                             │
│       │ {hash: "a1b2c3d4..."}                                │
│       ▼                                                      │
│       │               ┌──────────────────────┐               │
│       │               │ Lote de 1000 hashes   │               │
│       │               │ → Merkle Tree         │               │
│       │               │ → Merkle Root         │               │
│       │               │ → Anclar en Arbitrum  │               │
│       │               └──────────────────────┘               │
│       │                                                      │
│       ◄────── {merkle_root: "0xdef...",                      │
│                 merkle_proof: [...],                          │
│                 block_number: 12345678,                       │
│                 anchored_at: "2026-06-22T15:30:00Z"}         │
│                                                              │
│  Guarda el proof                                             │
│  (32 bytes)                                                  │
│       │                                                      │
│       │ 6 meses después...                                    │
│       │                                                      │
│       │ "Necesito probar que este                             │
│       │  documento no fue alterado"                           │
│       │                                                      │
│       │ GET /api/v1/trust/verify/0xdef...                    │
│       │                                                      │
│       ◄────── {verified: true,                                │
│                 block: 12345678,                              │
│                 anchored_at: "2026-06-22T15:30:00Z",         │
│                 verifiable_at: "https://arbiscan.io/..."}    │
│                                                              │
│  ✅ Probado. El hash existía                                  │
│  en el bloque 12345678.                                       │
│  El documento NO fue alterado.                                │
└─────────────────────────────────────────────────────────────┘
```

### Lo que el cliente integra en su app

```javascript
// Solo 3 funciones — 20 líneas de código

// 1. Anclar un hash
import { TrustClient } from '@sbos/trust';
const trust = new TrustClient({ apiKey: 'su-api-key' });
const receipt = await trust.anchor(documento); // solo el hash viaja

// 2. Verificar un anclaje (sin API key — es público)
const verified = await trust.verify(receipt.merkle_root);
// → true si el hash existe en Arbitrum One

// 3. Verificar offline (sin internet — solo con el proof)
const verified = trust.verifyOffline(hash, receipt.merkle_proof, receipt.merkle_root);
```

### Planes

| Plan | Hashes/mes | Verificación | Precio |
|------|-----------|-------------|--------|
| **Free** | 100 | Pública | $0 |
| **Pro** | 100,000 | Pública | $100/mes |
| **Enterprise** | Ilimitado | Pública + API | $1,000/mes |

---

## PRODUCTO E — IdP Rentado (IdP-as-a-Service)

### ¿Para quién es?

Startups, SaaS, e-commerce, clínicas, y cualquier empresa que necesite que
sus usuarios hagan login pero **no quieren construir autenticación desde cero**.

### El problema del cliente

```
Un e-commerce necesita:
  ❌ Registro de usuarios con email verification
  ❌ Login con password (hash seguro, Argon2id)
  ❌ "Iniciar sesión con Google"
  ❌ Recuperación de contraseña
  ❌ MFA para administradores
  ❌ Que no se filtren contraseñas (HIBP screening)
  ❌ Que un auditor no encuentre passwords en texto plano

Construir todo esto bien: $50K-$100K + 3-6 meses
Con IdP Rentado: 15 líneas de OIDC, listo en 1 hora
```

### Cómo funciona

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                   │
│   App del Cliente                  auth.sbos.skull.bo/sucliente   │
│   ──────────────                   ─────────────────────────────  │
│                                                                   │
│   Usuario entra a                                                  │
│   https://tienda.com                                               │
│        │                                                          │
│        │ 1. Click "Iniciar sesión"                                 │
│        ▼                                                          │
│   Redirige a ─────────────────────→ Login page                    │
│                                      ┌──────────────────────┐     │
│                                      │   🏪 Tienda.com      │     │
│                                      │   ───────────────    │     │
│                                      │   Email: ________    │     │
│                                      │   Password: ______    │     │
│                                      │   [Iniciar sesión]   │     │
│                                      │   ── o ──           │     │
│                                      │   [Google] [Microsoft]│    │
│                                      └──────────────────────┘     │
│                                                                   │
│   Usuario se autentica                                            │
│   (password + TOTP si tiene MFA)                                  │
│                                      │                            │
│        │                             │ bAuth evalúa:              │
│        │                             │ ✅ Password correcto       │
│        │                             │ ✅ No está en HIBP         │
│        │                             │ ✅ MFA verificado          │
│        │                             │ ✅ Risk score < 25         │
│        │                             │ ✅ Emitir JWT              │
│                                      │                            │
│        ◄────── redirect con ?code= ──┘                            │
│                                                                   │
│   Backend intercambia code por JWT:                               │
│   POST /token → {access_token, id_token, refresh_token}          │
│                                                                   │
│   El id_token contiene:                                           │
│   {                                                               │
│     "sub": "user-123",                                            │
│     "email": "cliente@gmail.com",                                 │
│     "bos_rol_bitmask": "ewEEAAAAKAWA...",                         │
│     "bos_tenant_id": "tienda-uuid"                                │
│   }                                                               │
│                                                                   │
│   ✅ Backend valida el JWT con la clave pública                    │
│   ✅ Usuario autenticado — mostrar dashboard                      │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### Integración — 15 líneas de código

```javascript
// Backend del cliente (Node.js)
import { Issuer } from 'openid-client';

// 1. Descubrir configuración automáticamente
const sbos = await Issuer.discover(
  'https://auth.sbos.skull.bo/mi-tienda/.well-known/openid-configuration'
);

// 2. Crear cliente OIDC
const client = new sbos.Client({
  client_id: 'mi-tienda-app',
  client_secret: process.env.SBOS_CLIENT_SECRET,
  redirect_uris: ['https://tienda.com/callback'],
});

// 3. Login: redirigir
app.get('/login', (req, res) => {
  res.redirect(client.authorizationUrl({
    scope: 'openid profile email',
    code_challenge_method: 'S256',
  }));
});

// 4. Callback: recibir token
app.get('/callback', async (req, res) => {
  const tokens = await client.callback('https://tienda.com/callback',
    client.callbackParams(req), { code_verifier: req.session.cv });
  const userInfo = await client.userinfo(tokens);
  
  // userInfo = { sub, email, bos_rol_bitmask, bos_tenant_id }
  req.session.user = userInfo;
  res.redirect('/dashboard');
});
```

### Qué NO tiene que hacer el cliente

| Tarea | ¿Tiene que hacerla el cliente? | Quién la hace |
|-------|-------------------------------|--------------|
| Registrar usuarios | ❌ | bAuth (formulario + email verification) |
| Hashear contraseñas (Argon2id) | ❌ | bAuth |
| "Login con Google" | ❌ | bAuth configura el IdP |
| Recuperar contraseña | ❌ | bAuth (email automático) |
| MFA (TOTP/Passkey) | ❌ | bAuth (el usuario lo activa) |
| Bloquear passwords brechados (HIBP) | ❌ | bAuth (k-anonymity screening) |
| Rate limiting (anti brute-force) | ❌ | bAuth + Kong |
| Session management | ❌ | bAuth (JWT con refresh rotation) |
| Auditoría de logins | ❌ | bAuth (D11 WORM) |
| Cumplir ISO 27001/NIST/PCI | ❌ | bAuth (certificaciones incluidas) |

### Planes

| Plan | MAU | Login social | MFA | SAML | Branding | API admin | SLA | Precio |
|------|-----|-------------|-----|------|---------|-----------|-----|--------|
| **Free** | 100 | Google, MS | ❌ | ❌ | ❌ | ❌ | Best effort | $0 |
| **Pro** | 10,000 | Google, MS | ✅ | ❌ | ✅ | ✅ | 99.9% | $500/mes |
| **Enterprise** | Ilimitado | Todos | ✅ | ✅ | ✅ | ✅ | 99.99% | $2K+/mes |

---

## Comparativa Rápida

```
¿Qué necesita el cliente?              → Producto adecuado

"La ASFI me va a multar"              → A. Compliance-in-a-Box
"Quiero lanzar mi billetera"          → B. Billetera White-Label
"Quiero controlar quién accede a qué" → C. IAM Soberano
"Necesito probar que esto no cambió"  → D. Trust Layer
"Quiero login en mi app sin codedarlo"→ E. IdP Rentado
```

---

## Método de Entrega

Todos los productos se entregan como **API + Portal Web + SDK**:

| Canal | Descripción |
|-------|------------|
| **API JSON-RPC** | `bauth.product.*` — integración programática |
| **API REST** | `https://api.sbos.skull.bo/v1/{tenant}/` — REST estándar |
| **Portal Admin** | `https://admin.sbos.skull.bo` — autogestión del cliente |
| **Sandbox** | `https://sandbox.sbos.skull.bo` — pruebas gratuitas |

---

## Sandbox — Probar gratis

1. Entrar a `https://sandbox.sbos.skull.bo`
2. Registrarse (sin KYC, 30 segundos)
3. Acceder a todos los productos en modo prueba:
   - API keys sandbox
   - Datos sintéticos
   - Blockchain en testnet (Arbitrum Sepolia)
   - Red Besu QBFT devnet (1 validador)
4. Límites: 100 tx/día, 1 tenant, sin SLA
5. Auto-destrucción tras 30 días de inactividad
