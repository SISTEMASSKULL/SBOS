# BAUTH-PRODUCTOS-COMERCIALES-B33 — Catálogo de Productos D12

**Versión:** 1.0.0 · **Fecha:** 2026-06-22 · **Autor:** sbos-coordinador  
**Propósito:** Documentar los 4 productos comerciales construidos sobre D12 Blockchain.

---

## Visión General

Los 4 productos monetizan las capacidades del SBOS en diferentes mercados:

```
┌─────────────────────────────────────────────────────────────┐
│                 SBOS D12 — LÍNEA DE PRODUCTOS                │
├────────────┬────────────────┬───────────────┬───────────────┤
│ Producto A │ Producto B     │ Producto C    │ Producto D    │
│ Compliance │ Billetera      │ IAM Soberano  │ Trust Layer   │
│ -in-a-Box  │ White-Label    │               │               │
├────────────┼────────────────┼───────────────┼───────────────┤
│ Mercado:   │ Mercado:       │ Mercado:      │ Mercado:      │
│ Financiero │ Fintech        │ Empresarial   │ Legal/Tech    │
├────────────┼────────────────┼───────────────┼───────────────┤
│ $500-$2K/m │ 2% revenue     │ $5/user/m     │ $100-$1K/m    │
└────────────┴────────────────┴───────────────┴───────────────┘
```

---

## Producto A — Compliance-in-a-Box

### ¿Qué es?

Una **API de autorización financiera multi-tenant** que permite a bancos,
financieras y cooperativas cumplir con regulaciones de compliance sin
construir su propia infraestructura.

### ¿Qué problema resuelve?

Toda institución financiera en Bolivia debe cumplir con:
- **ASFI:** límites por transacción, doble aprobación, separación de funciones
- **UIF:** reporte de operaciones sospechosas
- **ISO 27001:** trazabilidad de cada decisión de autorización
- **PCI DSS:** controles de acceso a datos de tarjetas

Implementar esto internamente cuesta $100K-$500K en desarrollo + $50K/año en auditoría.
**Compliance-in-a-Box lo entrega como API por $500-$2,000/mes.**

### ¿Cómo funciona?

```json
// POST /api/v1/compliance/authorize
{
  "usuario": "cajero-001",
  "monto": 15000.00,
  "tipo_operacion": "transferencia",
  "tenant_id": "banco-union"
}

// Respuesta
{
  "autorizado": false,
  "requiere_doble_aprobacion": false,
  "razon": "Monto excede límite por transacción ($10,000)",
  "anclaje_blockchain": {
    "tx_hash": "0xabcd...",
    "block": 12345678,
    "verificable_en": "https://arbiscan.io/tx/0xabcd..."
  }
}
```

### Dominios que evalúa

| Dominio | Qué verifica |
|---------|-------------|
| **D3** Financiero | Límites por rol, SoD, dual-approval |
| **D11** Auditoría | Registro WORM de cada decisión |
| **D12-A** Blockchain | Anclaje Merkle verificable (Arbitrum One) |

### Planes y precios

| Plan | Transacciones/mes | Usuarios | SLA | Precio |
|------|------------------|---------|-----|--------|
| **Free** | 100 | 1 | Best effort | $0 |
| **Pro** | 10,000 | 10 | 99.9% | $500/mes |
| **Enterprise** | Ilimitado | Ilimitado | 99.99% | $2,000/mes |

### Evidencia de cumplimiento

Cada transacción autorizada (o denegada) genera:
1. Registro en `bauth_audit_events` (WORM, ISO 27001 A.8.15)
2. Hash SHA3-256 incluido en lote Merkle
3. Anclaje en Arbitrum One cada 1 hora
4. Verificación pública en `bos-verify` sin necesidad de login

---

## Producto B — Billetera White-Label

### ¿Qué es?

Una **billetera on-chain con marca personalizable** que permite a fintechs,
cooperativas y comercios lanzar su propia billetera digital sin desarrollar
el motor de cuentas, la seguridad ni la infraestructura blockchain.

### ¿Qué problema resuelve?

Crear una billetera digital desde cero requiere:
- Motor de cuentas con double-entry contable
- Integración con blockchain (Besu QBFT)
- KYC/AML compliance
- Seguridad de claves (HSM)
- Integración con rieles de pago (QR BCB, ACP)

**Billetera White-Label entrega todo esto con la marca del cliente.**

### ¿Cómo funciona?

```
Cliente (Banco Unión)
  │
  ├── Frontend: https://billetera.banco-union.bo
  │     (Logo, colores, UX del Banco Unión)
  │
  └── Motor compartido SBOS (infraestructura multi-tenant)
       ├── Cuentas on-chain (bos_onchain_account)
       ├── Liquidaciones (bos_onchain_settlement)
       ├── KYC (D9 Credenciales)
       ├── MFA (D5 Biométrico)
       └── Custodia gestionada (HSM — el usuario NUNCA ve su clave)
```

### Custodia gestionada

**El usuario NUNCA ve su clave privada.** Es el principio de diseño más importante:

1. Alta: bAuth genera par ECDSA secp256k1 en HSM
2. Clave privada: NUNCA sale del HSM
3. Autorización: usuario solicita tx → D3 Policy-Path → biedata construye → Vault firma dentro del HSM
4. MFA: montos > $1,000 requieren TOTP; > $10,000 requieren FIDO2 + dual-approval
5. Recuperación: break-glass por Admin Seguridad (2-of-3 Shamir en Vault)

### Modelos de negocio

| Modelo | Descripción | Ejemplo |
|--------|------------|---------|
| **Revenue Share** | 2% del volumen procesado | $1M/mes volumen → $20K/mes para SBOS |
| **Licencia Base** | $2,000/mes + 0.5% del volumen | Predecible para el cliente, recurrente para SBOS |

### Integración a rieles de pago (Bolivia)

| Riel | Estado | Descripción |
|------|--------|------------|
| **QR BCB** | Planeado | Generar/procesar QR según estándar del Banco Central de Bolivia |
| **Switch ACP** | Planeado | Integrar con Administradora de Cámaras de Pago para liquidación interbancaria |
| **Banco corresponsal** | Planeado | Conexión a banco para liquidación fiat ↔ on-chain |

---

## Producto C — IAM Soberano

### ¿Qué es?

El **empaquetado de los 11 dominios de identidad del SBOS como servicio
gestionado** para empresas que necesitan control de acceso avanzado sin
construir su propio sistema de identidad.

### ¿Qué incluye?

| Componente | Descripción |
|-----------|------------|
| **11 dominios** | D1-D11 completos con BitMask Dual v3.0 |
| **Keycloak realm** | Aislado por tenant, con 15 métodos de autenticación |
| **Tryton-PDP** | Policy Decision Point dedicado |
| **Vault namespace** | Secretos, PKI, claves de cifrado del tenant |
| **Panel de administración** | Gestión de usuarios, roles, políticas |
| **Cumplimiento** | ISO 27001, NIST 800-63B, PCI DSS 4.0.1 |

### ¿Qué problema resuelve?

Las empresas medianas/grandes necesitan:
- Control de acceso basado en roles (RBAC)
- Separación de funciones (SoD)
- MFA para operaciones sensibles
- Auditoría de cada acceso
- Cumplimiento normativo

Construir esto internamente cuesta **$200K-$1M** en desarrollo + licencias.
**IAM Soberano lo entrega como servicio por $5/usuario/mes.**

### Planes

| Plan | Usuarios mín | Precio/usuario/mes | SLA |
|------|-------------|-------------------|-----|
| **Starter** | 50 | $5 | 99.5% |
| **Business** | 500 | $3 | 99.9% |
| **Enterprise** | 5,000+ | Personalizado | 99.99% |

---

## Producto D — Trust Layer

### ¿Qué es?

Un **SDK de anclaje verificable** que permite a cualquier organización
anclar hashes de sus registros en blockchain para demostrar que no han
sido alterados, sin exponer los datos originales.

### ¿Qué problema resuelve?

- **Empresas de auditoría:** necesitan demostrar que sus informes no fueron alterados
- **Firmas legales:** necesitan probar que un contrato existía en cierta fecha
- **Gobierno:** necesita transparencia verificable de actos administrativos
- **Universidades:** necesitan certificados de título inalterables

### ¿Cómo funciona?

```
Cliente                                     SBOS Trust Layer
  │                                               │
  │  1. hash = SHA3-256(documento)                │
  │  2. POST /api/v1/trust/anchor {hash}          │
  │                                               │
  │                                  ┌────────────┤
  │                                  │ Lote de    │
  │                                  │ 1000 hash  │
  │                                  │ → Merkle   │
  │                                  │ tree       │
  │                                  └────────────┤
  │                                               │
  │  3. Recibe: {merkle_root, proof}              │
  │                                               │
  │  4. Verificar en cualquier momento:           │
  │     GET /api/v1/trust/verify/{merkle_root}    │
  │     → {verified: true, block: 12345}          │
```

**El cliente NUNCA envía datos — solo hashes.**

### SDK multi-lenguaje

| Lenguaje | Paquete | Instalación |
|----------|---------|------------|
| **Rust** | `bos-trust` | `cargo add bos-trust` |
| **JavaScript** | `@sbos/trust` | `npm install @sbos/trust` |
| **Python** | `bos-trust` | `pip install bos-trust` |

### Planes

| Plan | Hashes/mes | Precio |
|------|-----------|--------|
| **Free** | 100 | $0 |
| **Pro** | 100,000 | $100/mes |
| **Enterprise** | Ilimitado | $1,000/mes |

---

## Infraestructura Compartida

### Sandbox gratuito

`https://sandbox.sbos.skull.bo`

- Registro instantáneo (sin KYC)
- Acceso a los 4 productos en modo prueba
- Datos sintéticos
- Anclaje en Arbitrum Sepolia (testnet)
- Red Besu QBFT de 1 validador (devnet)
- Límites: 100 tx/día, 1 tenant, sin SLA
- Auto-destrucción tras 30 días de inactividad

### Pricing & Billing Engine

```
Factura mensual = Σ(precio base + excedentes)

Ejemplo Cliente Pro (Producto A):
  Base:                              $500.00
  12,000 tx (2,000 extra × $0.01):  $ 20.00
  Total:                             $520.00/mes

Ejemplo Cliente Revenue Share (Producto B):
  Volumen procesado: $500,000
  2% revenue share:  $10,000/mes
```

---

## Métricas comerciales (proyección)

| Producto | Clientes est. año 1 | Ingreso est./mes | Ingreso est./año |
|----------|-------------------|------------------|------------------|
| A — Compliance | 5 (3 Pro + 2 Ent) | $5,500 | $66,000 |
| B — Billetera | 2 (revenue share) | $10,000 | $120,000 |
| C — IAM | 3 (1 Start + 2 Bus) | $3,250 | $39,000 |
| D — Trust | 10 (8 Free + 2 Pro) | $200 | $2,400 |
| **Total** | **20** | **$18,950/mes** | **$227,400/año** |

---

## Handlers JSON-RPC

| Método | Producto | Descripción |
|--------|---------|------------|
| `bauth.product.compliance` | A | Endpoint de autorización financiera |
| `bauth.product.iam` | C | Estado del servicio IAM Soberano |
| `bauth.product.trust` | D | Verificación pública de anclajes |
| `bauth.product.pricing` | — | Catálogo de planes y precios |
