# BAUTH-DDL-DOMINIO-FINANCIERO.md — Dominio Financiero (D3)

**Versión:** 1.0 · **Fecha:** 2026-06-23 · **Autor:** sbos-coordinador
**Schema:** `bauth` (prefijo `fin_`) · **Dominio bAuth:** D3 — Financiero
**Tablas heredadas:** `bos_financial_tipo_transaccion`, `bos_financial_limit`, `bos_financial_decision_matrix`, `bos_financial_approval`, `bos_financial_document_operation`, `bos_financial_role_permission`
**Referencias:** `BAUTH-DDL-DOMINIO-FISICO.md` · `PLAN-RECONSTRUCCION-DDL.md`

---

## 1. VISIÓN DEL DOMINIO

El Dominio Financiero (D3) del SBOS controla **todo lo que involucra dinero**: límites de transacción,
separación de deberes (SoD), aprobación dual, documentos fiscales, y conciliación.

**No es un sistema contable tradicional — es el guardián financiero del motor de identidad.**
bauth decide SI una operación financiera puede ejecutarse, bajo QUÉ condiciones (límite, SoD,
aprobación dual), y deja TRAZA inmutable (WORM + hash-chain SHA-256).

```
┌──────────────────────────────────────────────────────────────────┐
│                 DOMINIO FINANCIERO — D3                          │
│                                                                  │
│  bauth (Policy-Path)            bRates (ejecución)               │
│  ┌────────────────────┐        ┌────────────────────┐           │
│  │ ¿Monto ≤ límite?   │───────▶│ Ejecutar débito     │           │
│  │ fin_limit           │        │ ¿SoD? → requiere    │           │
│  │ ¿SoD violado?      │        │   segunda firma     │           │
│  │ fin_decision_matrix │        │ ¿Dual approval? →   │           │
│  │ ¿Aprobación dual?   │        │   esperar 2º par    │           │
│  │ fin_approval        │        │ Registrar auditoría │           │
│  │ ¿Documento fiscal?  │        │   WORM + hash-chain │           │
│  │ fin_document_op     │        └────────────────────┘           │
│  └────────────────────┘                                          │
│                                                                  │
│  Principios:                                                     │
│  - Double-entry: cada débito tiene su crédito                    │
│  - SoD estático + dinámico: quién crea ≠ quién aprueba           │
│  - Dual approval: operaciones > límite requieren 2 firmas        │
│  - Hash-chain SHA-256: cada transacción encadenada (WORM)        │
└──────────────────────────────────────────────────────────────────┘
```

---

## 2. ESTÁNDARES INTERNACIONALES

### 2.1 — Contabilidad y Finanzas

| Estándar | Título | Aplicación en SBOS |
|----------|--------|-------------------|
| **IFRS / NIC 1** | Presentation of Financial Statements | Estructura de cuentas, clasificación |
| **IFRS 15 / NIC 18** | Revenue Recognition | Reconocimiento de ingresos |
| **ISO 20022** | Financial messaging | Estructura de transacciones, códigos |
| **Double-Entry** (Luca Pacioli, 1494) | Partida doble | Débito = Crédito en cada transacción |

### 2.2 — Control y Seguridad

| Estándar | Título | Aplicación en SBOS |
|----------|--------|-------------------|
| **NIST 800-53 AC-5** | Separation of Duties | SoD estático + dinámico |
| **PCI DSS 4.0 Req 7** | Access Control | Restricción de acceso a datos de pago |
| **ISO 27001:2022 A.8.2** | Privileged Access | Control de acceso privilegiado a funciones financieras |
| **SIN RND 102100000011** | Facturación Electrónica Bolivia | Documentos fiscales, CUFD, CUIS, CAFC |

### 2.3 — Auditoría e Integridad

| Estándar | Aplicación en SBOS |
|----------|-------------------|
| **Hash-chain SHA-256** (PCI DSS 10.3.2) | Cada registro financiero encadenado criptográficamente |
| **WORM** (Write Once Read Many) | REVOKE UPDATE/DELETE en tablas de auditoría |
| **Bi-temporal** (ISO SQL:2011) | `valid_from/valid_to` (mundo real) + `recorded_at` (DB) |
| **SBOS-049** | ctx_id obligatorio en cada operación financiera |

---

## 3. TABLAS DEL DOMINIO FINANCIERO — Diseño Final

**Principio:** JSONB para configuraciones variables + Jerarquía para cadenas de aprobación de N niveles.
Cero columnas hardcodeadas que limiten el crecimiento.

### 3.1 — Mapa de tablas

| # | Tabla | Línea | Origen | Propósito |
|---|-------|-------|--------|-----------|
| 028 | `fin_transaction_type` | 2108 | bos_financial_tipo_transaccion | Catálogo con `controls JSONB` extensible |
| 029 | `fin_limit` | 2136 | bos_financial_limit | Límites con `limits_config JSONB` (períodos ilimitados) |
| 030 | `fin_approval_chain` | 2164 | bos_financial_decision_matrix | **Cadena jerárquica de N niveles** (reemplaza 3 hardcodeados) |
| 030b | `fin_approval_level` | 2183 | NUEVA | Nivel individual dentro de una cadena |
| 031 | `fin_approval` | 2201 | bos_financial_approval | Hash-chain SHA-256 + current_level |
| 032 | `fin_document_operation` | 2225 | bos_financial_document_operation | Hash-chain + operation_data JSONB |
| 033 | `fin_role_permission` | 2243 | bos_financial_role_permission | `permissions JSONB` sin booleanos hardcodeados |

### 3.2 — Flexibilidad JSONB

| Tabla | Columna JSONB | Ejemplo | Nuevo valor sin ALTER TABLE |
|-------|--------------|---------|---------------------------|
| fin_transaction_type | `controls` | `{"requires_dual_control":true}` | Agregar `"requires_video_verification":true` |
| fin_limit | `limits_config` | `{"daily":50000,"monthly":1000000}` | Agregar `"quarterly":3000000` |
| fin_limit | `accumulators` | `{"daily":12500,"last_reset_daily":"2026-06-23"}` | Agregar `"quarterly":450000` |
| fin_role_permission | `permissions` | `{"can_initiate":true,"can_approve":false}` | Agregar `"can_override_limit":true` |

### 3.3 — Cadena de aprobación jerárquica (N niveles)

```
fin_approval_chain: "Aprobación de Facturas — Bolivia"
│
├── fin_approval_level: level_order=1, role=Supervisor, max=50,000
├── fin_approval_level: level_order=2, role=Gerente, max=200,000
├── fin_approval_level: level_order=3, role=Director, max=1,000,000
├── fin_approval_level: level_order=4, role=VP Finanzas, max=10,000,000
└── fin_approval_level: level_order=5, role=Comité Ejecutivo, max=NULL (sin límite)
```

Agregar nivel 6 no requiere ALTER TABLE, solo INSERT en `fin_approval_level`.

---

## 4. DISEÑO DE TABLAS

### 4.1 — fin_transaction_type

```sql
CREATE TABLE bauth.fin_transaction_type (
    type_id          UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID NOT NULL REFERENCES idn_tenant(tenant_id),
    code             TEXT NOT NULL,
    name             TEXT NOT NULL,
    description      TEXT,
    affects_balance  BOOLEAN NOT NULL DEFAULT true,
    requires_approval BOOLEAN NOT NULL DEFAULT false,
    is_active        BOOLEAN DEFAULT true,
    ctx_id           TEXT NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, code)
);
```

### 4.2 — fin_limit

```sql
CREATE TABLE bauth.fin_limit (
    limit_id         UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID NOT NULL REFERENCES idn_tenant(tenant_id),
    role_id          UUID,
    user_id          UUID,
    transaction_type_id UUID NOT NULL REFERENCES fin_transaction_type(type_id),
    amount_limit     DECIMAL(18,4) NOT NULL,
    currency_code    CHAR(3) NOT NULL DEFAULT 'BOB',
    period           TEXT NOT NULL DEFAULT 'DAILY',
    is_active        BOOLEAN DEFAULT true,
    ctx_id           TEXT NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 4.3 — fin_decision_matrix

```sql
CREATE TABLE bauth.fin_decision_matrix (
    decision_id      UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID NOT NULL REFERENCES idn_tenant(tenant_id),
    transaction_type_id UUID NOT NULL REFERENCES fin_transaction_type(type_id),
    min_amount       DECIMAL(18,4),
    max_amount       DECIMAL(18,4),
    requires_sod     BOOLEAN DEFAULT true,
    requires_dual_approval BOOLEAN DEFAULT false,
    requires_document BOOLEAN DEFAULT false,
    approval_threshold DECIMAL(18,4),
    ctx_id           TEXT NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, transaction_type_id, min_amount, max_amount)
);
```

### 4.4 — fin_approval

```sql
CREATE TABLE bauth.fin_approval (
    approval_id      UUID PRIMARY KEY DEFAULT uuidv7(),
    transaction_id   UUID NOT NULL,
    approved_by      UUID NOT NULL,
    approval_level   INTEGER NOT NULL DEFAULT 1,
    decision         TEXT NOT NULL DEFAULT 'PENDING',
    comments         TEXT,
    approved_at      TIMESTAMPTZ,
    prev_hash        TEXT,
    entry_hash       TEXT NOT NULL,
    ctx_id           TEXT NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 4.5 — fin_document_operation

```sql
CREATE TABLE bauth.fin_document_operation (
    operation_id     UUID PRIMARY KEY DEFAULT uuidv7(),
    document_id      UUID NOT NULL,
    operation_type   TEXT NOT NULL,
    executed_by      UUID NOT NULL,
    operation_data   JSONB DEFAULT '{}',
    prev_hash        TEXT,
    entry_hash       TEXT NOT NULL,
    ctx_id           TEXT NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

## 5. PLAN DE IMPLEMENTACIÓN

| Fase | Qué | Horas |
|------|-----|-------|
| **F0** | Limpiar 6 tablas del DDL antiguo | 0.5h |
| **F1** | ENUM types financieros + COMMENT ON | 0.5h |
| **F2** | 6 tablas en DDL nuevo con UUIDv7, inglés, FKs | 2h |
| **F3** | VPS: prueba de idempotencia | 0.5h |
| **Total** | | **3.5h** |

---

*Documento generado 2026-06-23. Basado en double-entry accounting (Pacioli 1494), ISO 20022, NIST 800-53 AC-5, PCI DSS 4.0, SIN Bolivia RND 102100000011.*
