# Modelo de Ajustes: Global SBOS + Empresa — SBOS SmartRates
## Decisión definitiva · Modelo de dos niveles · Herencia automática

**Fecha:** 2026-05-23  
**Origen:** Respuesta definitiva del humano post-simulación  
**Impacto:** Afecta company.*, adjustment_daily, stablecoin_adjustment, API y Flutter  

---

## EL MODELO DEFINITIVO DE DOS NIVELES

```
NIVEL 1 — Ajuste GLOBAL del SBOS (nivel tenant)
  ┌──────────────────────────────────────────────────────────────┐
  │  Confirmado por: operador autorizado del SBOS (no de empresa)│
  │  Alcance: válido para TODAS las empresas del tenant          │
  │  Si empresa no tiene ajuste propio → hereda ESTE valor       │
  │  Tabla: company.adjustment_global (NUEVA)                    │
  │  Ejemplo: SBOS confirma ajuste global +0.50                  │
  └──────────────────────────────────────────────────────────────┘
                              ↓  hereda si no hay propio
NIVEL 2 — Ajuste POR EMPRESA (sobrescribe el global si existe)
  ┌──────────────────────────────────────────────────────────────┐
  │  Confirmado por: operador de la empresa específica           │
  │  Alcance: solo para esa empresa                              │
  │  Si está configurado → sobrescribe el ajuste global          │
  │  Si NO está configurado → hereda automáticamente del global  │
  │  Tabla: company.adjustment_daily (existente, ajustada)       │
  │  Ejemplo: Maya S.R.L. configura su propio ajuste +0.65       │
  └──────────────────────────────────────────────────────────────┘
```

### Casos de operación diaria

**Caso A — Empresa con ajuste propio:**
```
SBOS global confirma: +0.50
Maya S.R.L. confirma: +0.65 (su propia realidad operativa)
→ Maya S.R.L. usa: +0.65  (sobrescribe)
→ Cóndor Import (sin ajuste propio) usa: +0.50 (hereda global)
→ Brisas S.R.L. (sin ajuste propio) usa: +0.50 (hereda global)
```

**Caso B — Nadie confirma nada:**
```
SBOS global NO confirmó
Ninguna empresa confirmó
→ AdjustmentTimeoutJob a las 17:00:
   Aplica ajuste global del día anterior como provisional global
   Todas las empresas heredan ese provisional
```

**Caso C — SBOS global confirma, empresa no:**
```
SBOS global confirma: +0.50 a las 08:00
Cóndor Import no tiene operador — no confirma nada
→ Cóndor Import hereda automáticamente: +0.50 sin intervención
→ No se genera alerta para Cóndor Import (tiene un valor válido)
```

**Caso D — Empresa confirma, SBOS global no:**
```
Maya S.R.L. confirma: +0.65 a las 08:47
SBOS global no ha confirmado aún
→ Maya S.R.L. usa su propio: +0.65 ✅
→ Otras empresas usan el provisional del día anterior hasta que el global se confirme
```

---

## NUEVA TABLA: company.adjustment_global

```sql
-- El ajuste global del SBOS — nivel tenant
-- Confirmado por un operador con rol smartrates.global_operator
CREATE TABLE company.adjustment_global (
    id               UUID          NOT NULL DEFAULT uuidv7(),
    tenant_id        VARCHAR(50)   NOT NULL DEFAULT '',
    currency_code    CHAR(3)       NOT NULL DEFAULT '',
    rate_date        DATE          NOT NULL,
    confirmed        BOOLEAN       NOT NULL DEFAULT false,
    confirmed_by     UUID          NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000',
    confirmed_at     TIMESTAMPTZ   NOT NULL DEFAULT '1900-01-01 00:00:00+00',
    adjustment_value NUMERIC(20,8) NOT NULL DEFAULT 0.00000000,
    notes            TEXT          NOT NULL DEFAULT '',
    is_provisional   BOOLEAN       NOT NULL DEFAULT false,
    CONSTRAINT pk_adjustment_global  PRIMARY KEY (id),
    CONSTRAINT uq_adjustment_global  UNIQUE (tenant_id, currency_code, rate_date)
);
-- is_provisional=true → fue creado por AdjustmentTimeoutJob (UUID_SYSTEM)
-- is_provisional=false → confirmado por un humano con rol global_operator
```

---

## TABLA ACTUALIZADA: company.adjustment_daily

```sql
-- Ajuste de empresa — nivel empresa (sobrescribe el global si existe)
CREATE TABLE company.adjustment_daily (
    id               UUID          NOT NULL DEFAULT uuidv7(),
    company_id       UUID          NOT NULL REFERENCES company.companies(id),
    currency_code    CHAR(3)       NOT NULL DEFAULT '',
    rate_date        DATE          NOT NULL,
    confirmed        BOOLEAN       NOT NULL DEFAULT false,
    confirmed_by     UUID          NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000',
    confirmed_at     TIMESTAMPTZ   NOT NULL DEFAULT '1900-01-01 00:00:00+00',
    adjustment_value NUMERIC(20,8) NOT NULL DEFAULT 0.00000000,
    notes            TEXT          NOT NULL DEFAULT '',
    is_provisional   BOOLEAN       NOT NULL DEFAULT false,
    -- Nuevo campo: indica si este ajuste sobrescribe el global o lo hereda
    overrides_global BOOLEAN       NOT NULL DEFAULT true,
    -- true = la empresa configuró su propio valor
    -- false = solo existe por herencia del global (registro de trazabilidad)
    CONSTRAINT pk_adjustment_daily  PRIMARY KEY (id),
    CONSTRAINT uq_adjustment_daily  UNIQUE (company_id, currency_code, rate_date)
);
```

---

## TABLA ACTUALIZADA: company.stablecoin_adjustment

```sql
-- Ajuste de stablecoin (XUT/XUC) — mismo modelo de dos niveles
-- Nivel global: company.stablecoin_adjustment_global (espejo del modelo anterior)
-- Nivel empresa: company.stablecoin_adjustment (ya definida)
-- Si empresa no tiene → hereda del global
-- Si global no tiene → usa el P2P de CriptoYa directamente (adjustment_value=0)

CREATE TABLE company.stablecoin_adjustment_global (
    id               UUID          NOT NULL DEFAULT uuidv7(),
    tenant_id        VARCHAR(50)   NOT NULL DEFAULT '',
    coin_code        CHAR(3)       NOT NULL DEFAULT '',  -- XUT o XUC
    fiat_code        CHAR(3)       NOT NULL DEFAULT '',  -- BOB
    rate_date        DATE          NOT NULL,
    confirmed        BOOLEAN       NOT NULL DEFAULT false,
    confirmed_by     UUID          NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000',
    confirmed_at     TIMESTAMPTZ   NOT NULL DEFAULT '1900-01-01 00:00:00+00',
    adjustment_value NUMERIC(20,8) NOT NULL DEFAULT 0.00000000,
    notes            TEXT          NOT NULL DEFAULT '',
    is_provisional   BOOLEAN       NOT NULL DEFAULT false,
    CONSTRAINT pk_sc_adj_global PRIMARY KEY (id),
    CONSTRAINT uq_sc_adj_global UNIQUE (tenant_id, coin_code, fiat_code, rate_date)
);
```

---

## NUEVOS ROLES

```
smartrates.global_operator  → confirma el ajuste global del SBOS (nivel tenant)
smartrates.admin            → todo, incluyendo configurar qué empresas usan ajuste propio
smartrates.operator         → confirma ajuste de SU empresa (sobrescribe el global)
smartrates.readonly         → solo lectura
smartrates.api              → service account
```

---

## LÓGICA DE RESOLUCIÓN DEL AJUSTE (AdjustmentResolver)

```php
// app/Services/AdjustmentResolver.php

class AdjustmentResolver
{
    /**
     * Retorna el ajuste efectivo para una empresa en una fecha.
     * Lógica: empresa propia → global SBOS → provisional día anterior → 0
     */
    public function resolve(string $companyId, string $currencyCode, string $date): AdjustmentResult
    {
        // 1. ¿Tiene la empresa su propio ajuste para hoy?
        $company = AdjustmentDaily::where([
            'company_id'    => $companyId,
            'currency_code' => $currencyCode,
            'rate_date'     => $date,
            'overrides_global' => true,
        ])->first();

        if ($company) {
            return new AdjustmentResult(
                value:    $company->adjustment_value,
                source:   'company',
                level:    'empresa',
                confirmed: $company->confirmed,
                is_provisional: $company->is_provisional,
            );
        }

        // 2. ¿Hay ajuste global del SBOS para hoy?
        $tenantId = $this->getTenantId();
        $global = AdjustmentGlobal::where([
            'tenant_id'     => $tenantId,
            'currency_code' => $currencyCode,
            'rate_date'     => $date,
        ])->first();

        if ($global) {
            return new AdjustmentResult(
                value:    $global->adjustment_value,
                source:   'global',
                level:    'sbos',
                confirmed: $global->confirmed,
                is_provisional: $global->is_provisional,
            );
        }

        // 3. Fallback: ajuste global del día anterior
        $yesterday = AdjustmentGlobal::where([
            'tenant_id'     => $tenantId,
            'currency_code' => $currencyCode,
        ])->where('rate_date', '<', $date)
          ->orderByDesc('rate_date')
          ->first();

        if ($yesterday) {
            return new AdjustmentResult(
                value:    $yesterday->adjustment_value,
                source:   'global_fallback',
                level:    'sbos_ayer',
                confirmed: false,
                is_provisional: true,
            );
        }

        // 4. Sin datos: ajuste cero
        return new AdjustmentResult(
            value:    0.00,
            source:   'none',
            level:    'default',
            confirmed: false,
            is_provisional: false,
        );
    }
}
```

---

## ENDPOINT ACTUALIZADO: GET /rates/today

```json
{
  "date": "2026-05-25",
  "cotizaciones_globales": {
    "oficial_bcb":   {"buy": "6.86", "sell": "6.96", "mid": "6.91"},
    "referencial":   {"buy": "8.83", "sell": "9.15"},
    "usdt_p2p":      {"buy": "9.82", "sell": "10.08", "coin": "XUT"},
    "usdc_p2p":      {"buy": "9.78", "sell": "10.02", "coin": "XUC"}
  },
  "ajuste_efectivo": {
    "value": 0.65,
    "source": "company",
    "level": "empresa",
    "company": "Maya S.R.L.",
    "confirmed_by": "María López",
    "confirmed_at": "08:47:23",
    "is_provisional": false,
    "overrides_global": true,
    "global_value": 0.50,
    "comment": "Esta empresa usa su propio ajuste (+0.65) en lugar del global (+0.50)"
  },
  "black_rate": {
    "buy":  "7.51",
    "sell": "7.61",
    "spread": "0.10"
  }
}
```

Sin autenticación (datos públicos):
```json
{
  "date": "2026-05-25",
  "cotizaciones_globales": { ... },
  "ajuste_efectivo": null,
  "black_rate": null
}
```

---

## FLUJO COMPLETO DEL DÍA — con dos niveles

```
07:00 → Operador global del SBOS (smartrates.global_operator) confirma ajuste global:
        +0.50 para BOB  →  AdjustmentGlobal: tenant=skull, confirmed=true, value=0.50

08:47 → María López (Maya S.R.L., smartrates.operator) confirma ajuste de empresa:
        +0.65 para BOB  →  AdjustmentDaily: company_id=maya, overrides_global=true, value=0.65

09:00 → Cóndor Import (sin operador activo, use_black_rate='disabled')
        AdjustmentResolver → no hay ajuste de empresa → no hay global de hoy → 
        retorna global=0.50 pero la política 'disabled' hace que no lo aplique de todas formas

12:00 → AdjustmentReminderJob verifica:
        ¿Empresas con política 'national' o 'reference' sin ajuste propio Y sin global confirmado?
        → Notifica SOLO a las que no tienen ningún valor disponible aún
        → Maya S.R.L.: tiene propio → no notifica ✅
        → Brisas S.R.L.: tiene global (+0.50) → no notifica ✅

17:00 → AdjustmentTimeoutJob:
        ¿Hay ajuste GLOBAL confirmado para hoy? → SÍ (+0.50) → no hace nada
        ¿Hay empresas con política 'national' SIN ajuste propio Y sin global? → ninguna
        → No crea provisionales → el sistema está cubierto ✅

Si a las 17:00 NO hubiera ajuste global:
        → Crea AdjustmentGlobal provisional con UUID_SYSTEM, is_provisional=true
        → value = ajuste global del día anterior
        → Todas las empresas sin ajuste propio heredan ese provisional
```

---

## NUEVAS REGLAS DE NEGOCIO (RN-031 a RN-035)

**RN-031:** El ajuste global del SBOS lo confirma un usuario con rol `smartrates.global_operator`. Es el nivel base para todo el tenant.

**RN-032:** Si una empresa tiene `overrides_global=true` en su `adjustment_daily`, ese valor se usa para esa empresa, ignorando el global.

**RN-033:** Si una empresa NO tiene ajuste propio confirmado para el día, hereda automáticamente el ajuste global del SBOS sin ninguna acción requerida.

**RN-034:** El `AdjustmentResolver` resuelve siempre en este orden: empresa propia → global SBOS → global del día anterior → 0. Nunca falla — siempre retorna un valor.

**RN-035:** El `AdjustmentReminderJob` solo notifica a empresas con política `national` o `reference` que no tienen ningún valor disponible (ni propio ni heredado del global). Una empresa que hereda el global NO recibe notificación.

---
_SKULL · SBOS · SmartRates · SBOS-Rates-022-AJUSTES-GLOBAL-EMPRESA · v1.0 · 2026-05-23_
