# RE-SIMULACIÓN INTERNA v2.0
## SBOS SmartRates — Todos los escenarios resueltos

**Fecha:** 2026-05-23  
**Simulador:** Compositor ORQUESTA (Claude Sonnet 4.6)  
**Basado en:** Decisiones del humano · 020-DECISIONES-CONSOLIDADAS.md  
**Estado:** ✅ 12/12 escenarios sin ambigüedades  

---

## PRINCIPIO RECTOR (grabado en piedra)

```
Datos de mercado  →  GLOBALES   →  rates.*       → iguales para todo el tenant
Ajustes           →  POR EMPRESA → company.*     → cada empresa configura los suyos
```

---

## ESCENARIO 1 — Sincronización diaria · Sin cambios · ✅

El flujo de sincronización no cambió. La única diferencia es que todo aterriza en `smartrates_db` (schema único), no en dos BDs separadas.

```
06:00 → DailySyncFawazahmedJob
  UPSERT → smartrates_db.rates.exchange_rates (200+ monedas)

06:30 → DailySyncBcbJob  
  UPSERT → smartrates_db.rates.exchange_rates (BCB oficial)
  INSERT → smartrates_db.validation.bcb_cotizaciones (referencial VRD/VRV)
  [ANTES era smartrates_validation_db — ahora es schema en la misma BD]

07:30 → BcbCrossValidationJob
  JOIN entre rates y validation — mismo DB, sin cross-DB query ✅

08:00 → DailySyncUsdtP2pJob (cada hora)
  UPSERT → smartrates_db.rates.stablecoin_rates (XUT/BOB y XUC/BOB)
  [XUT = USDT, XUC = USDC — convención X-prefix]
```

---

## ESCENARIO 2 — Operador confirma ajuste · Pantalla mejorada · ✅

**Nuevo comportamiento:** La pantalla de ajuste muestra el USDT P2P en tiempo real como referencia, porque son la misma referencia semánticamente.

```
08:47 → María López abre SmartRatesUI
  
  Sistema detecta primer acceso del día → emite adjustment.required
  
  AdjustmentScreen carga:
  ┌──────────────────────────────────────────────────────────────────────────┐
  │  Confirmación de ajuste — Lunes 25/05/2026                              │
  ├──────────────────────────────────────────────────────────────────────────┤
  │  Cotizaciones globales hoy (mismas para todos):                         │
  │  Oficial BCB:      C: 6.86   V: 6.96   Mid: 6.91                       │
  │  Referencial BCB:  C: 8.83   V: 9.15                                   │
  │                                                                         │
  │  ── Mercado P2P ahora (referencia en tiempo real · SSE) ──              │
  │  🔵 USDT/BOB:      C: 9.82   V: 10.08                                  │
  │  📊 Spread vs oficial: 45.9%  ← histórico: 25%                         │
  │  💡 Ajuste sugerido P2P: +3.17  (10.08 - 6.91)                         │
  │                                                                         │
  │  Ajuste de TU empresa hoy:                                              │
  │  ┌──────────────────────────────────────────────────────────────┐       │
  │  │  +[ 0.50 ] BOB   ← editable por el operador                 │       │
  │  └──────────────────────────────────────────────────────────────┘       │
  │  Día anterior: +0.50 │ Resultado empresa: C:7.36  V:7.56               │
  │                                                                         │
  │           [Cancelar]           [✓ Confirmar]                           │
  └──────────────────────────────────────────────────────────────────────────┘

María ingresa +0.50, confirma.

POST /api/v1/company/adjustment/confirm
  Body: {company_id:"maya-uuid", currency_code:"BOB", 
         rate_date:"2026-05-25", adjustment_value:0.50}
         
company.adjustment_daily:
  confirmed=true, confirmed_by=3397708 (María), confirmed_at=08:47:23
  adjustment_value=0.50

Calculados para la empresa Maya S.R.L.:
  rate_black_buy  = 6.86 + 0.50 = 7.36
  rate_black_sell = 6.96 + 0.50 + spread(0.10) = 7.56
  
Reverb: adjustment.confirmed → SmartRatesUI muestra los rates de empresa actualizados
```

**Resultado:** ✅ Flujo completo. La pantalla es richer: muestra el contexto P2P que el operador usa como referencia.

---

## ESCENARIO 3 — JasperReports con catalog.RATE() · Sin cambios · ✅

La función C sigue igual. La diferencia es que ahora todo está en `smartrates_db`, sin cross-DB queries.

```sql
-- En tryton_db (mismo cluster PG18):
CREATE EXTENSION smartrates_rate;

SELECT
    p.nombre,
    p.precio_bob,
    catalog.RATE('25/05/2026', 'BOB', 'USD', p.precio_bob, 2) AS precio_usd,
    catalog.RATE('25/05/2026', 'BOB', 'XUT', p.precio_bob, 2) AS precio_usdt,
    -- XUT = USDT — la función sabe buscar en rates.stablecoin_rates
    catalog.RATE('25/05/2026', 'BOB', 'EUR', p.precio_bob, 2) AS precio_eur
FROM inventario.productos p
WHERE p.activo = true;
-- 50.000 filas · IMMUTABLE · constant folding → ~47ms ✅
```

---

## ESCENARIO 4 — Fawazahmed0 falla · Sin cambios · ✅

Circuit breaker y fallback a Frankfurter — no cambia nada de la lógica.

---

## ESCENARIO 5 — Multi-empresa: tres empresas, mismo servicio · RESUELTO ✅

**El escenario que antes fallaba. Ahora completamente claro.**

```
El SBOS tiene: Maya S.R.L., Cóndor Import S.A., Brisas S.R.L.

GET /api/v1/rates/today
→ Retorna cotizaciones GLOBALES, iguales para las tres empresas:
  {
    "oficial_bcb":   {"buy":"6.86","sell":"6.96","mid":"6.91"},
    "referencial":   {"buy":"8.83","sell":"9.15"},
    "usdt_p2p":      {"buy":"9.82","sell":"10.08","coin":"XUT"},
    "usdc_p2p":      {"buy":"9.78","sell":"10.02","coin":"XUC"},
    "rates": [{"USD/BOB":6.91},{"EUR/BOB":11.28},...],
    "company_adjustment": null   ← null porque no hay auth
  }

GET /api/v1/rates/today   (JWT de María de Maya S.R.L. via Kong)
→ Same datos globales + ajuste de la empresa del JWT:
  {
    ...cotizaciones globales...
    "company_adjustment": {
      "company_id": "maya-uuid",
      "company_name": "Maya S.R.L.",
      "adjustment_value": 0.50,
      "black_buy": "7.36",
      "black_sell": "7.56",
      "policy": "national",
      "confirmed_by": "María López",
      "confirmed_at": "08:47:23"
    }
  }

GET /api/v1/rates/today   (JWT de operador de Cóndor Import)
→ Same datos globales + ajuste de Cóndor Import:
  {
    ...cotizaciones globales...
    "company_adjustment": {
      "company_name": "Cóndor Import S.A.",
      "adjustment_value": 0.00,
      "policy": "disabled"
    }
  }

El API sabe a qué empresa pertenece el request:
  Modo SBOS:       X-SBOS-Empresa header inyectado por Kong
  Modo standalone: company_id en el JWT de Sanctum, o parámetro ?company_id=
```

**Resultado:** ✅ Totalmente claro. Datos globales + capa de ajuste por empresa.

---

## ESCENARIO 6 — Dos operadores, misma empresa, distintas sucursales · RESUELTO ✅

```
Carlos Mamani (La Paz) confirma ajuste a las 08:30: +0.45
  company.adjustment_daily: company_id=brisas-uuid, rate_date=2026-05-25,
                             adjustment_value=0.45, confirmed_by=carlos-uuid

Luis Flores (Santa Cruz) abre la app a las 09:15.
  GET /api/v1/company/adjustment/status
  Respuesta: {confirmed: TRUE, confirmed_by: "Carlos Mamani", confirmed_at: "08:30:15"}
  
  La app Flutter detecta que ya está confirmado.
  NO emite adjustment.required.
  Luis ve en el dashboard: "Ajuste confirmado por Carlos Mamani a las 08:30"
  
  El ajuste aplica para TODA Brisas S.R.L. — La Paz Y Santa Cruz usan +0.45
  X-SBOS-Sucursal del header no afecta al ajuste.
```

**Resultado:** ✅ Un ajuste por empresa, compartido por todas las sucursales.

---

## ESCENARIO 7 — Política 'national' + pago en USDT · RESUELTO ✅

```
Maya S.R.L.: use_black_rate='national', ajuste confirmado=+0.50
Cliente boliviano paga con USDT.

¿Qué cotización aplica?

RESPUESTA: El mismo black rate de la empresa.
  USDT (XUT) sigue la misma política que USD cuando use_black_rate='national'.
  Los bancos bolivianos ya usan el dólar paralelo oficial para USDT.
  
  rate_black_buy_usdt  = oficial_bcb_buy  + adjustment = 6.86 + 0.50 = 7.36
  rate_black_sell_usdt = oficial_bcb_sell + adjustment + spread = 7.56
  
  [Equivalente: 1 USDT → 7.36/7.56 BOB según la política de Maya S.R.L.]
  [El P2P dice 9.82/10.08 — la empresa decide libremente si usa eso o el black rate]

Endpoint para SmartTax (que calcula el impuesto):
  GET /api/v1/rates/today  (JWT de Maya S.R.L.)
  → Recibe:
    "oficial_bcb": {"buy":"6.86","sell":"6.96"},
    "usdt_p2p":    {"buy":"9.82","sell":"10.08","coin":"XUT"},
    "company_adjustment": {
      "policy": "national",
      "adjustment_value": 0.50,
      "black_buy": "7.36",
      "black_sell": "7.56",
      "applies_to": ["USD","XUT","XUC"]   ← la política aplica a USD y stablecoins
    }
    
SmartTax recibe ambos valores y aplica la política de la empresa.
```

**Resultado:** ✅ USDT sigue la política `national` de la empresa. El campo `applies_to` indica explícitamente a qué activos aplica el black rate.

---

## ESCENARIO 8 — Timeout 17:00 sin confirmación · RESUELTO ✅

```
Viernes 23/05/2026. El operador no confirmó el ajuste del día. Son las 17:01.

AdjustmentTimeoutJob dispara:

  1. Lee adjustment de ayer: adjustment_value=0.50
  
  2. Crea registro PROVISIONAL en company.adjustment_daily:
     company_id      = maya-uuid
     currency_code   = 'BOB'
     rate_date       = 2026-05-23
     confirmed       = false                    ← PROVISIONAL
     confirmed_by    = '00000000-0000-7777-0000-000000000000'  ← UUID_SYSTEM
     confirmed_at    = 2026-05-23 17:00:00+00  ← timestamp del job
     adjustment_value = 0.50                    ← valor de ayer
     notes           = 'PROVISIONAL-TIMEOUT: ajuste del día anterior aplicado 
                        automáticamente a las 17:00. El operador puede sobrescribir 
                        hasta las 20:00.'
                        
  3. confirmed_by = UUID_SYSTEM → NO es NULL → RN-003 satisfecha ✅
     El registro es distinguible de un ajuste humano por:
       - confirmed = false
       - confirmed_by = UUID_SYSTEM conocido
       - notes contiene 'PROVISIONAL-TIMEOUT'
       
  4. Reverb emite: adjustment.provisional → SmartRatesUI muestra banner ámbar:
     "⚠️ Ajuste provisional aplicado (valor de ayer +0.50) — confirmar antes de las 20:00"
     
  5. Si el operador confirma después de las 17:00:
     → El registro provisional se sobrescribe con confirmed=true y confirmed_by=humano
     
  6. Si nadie confirma antes de las 20:00:
     → AdjustmentLockJob a las 20:00 cambia: confirmed=true, confirmed_by=UUID_SYSTEM
     → El provisional queda como definitivo del día
     → Emite: adjustment.locked → UI muestra badge rojo "Ajuste bloqueado - provisional"
```

**Resultado:** ✅ Sin NULL. Sin violación de RN-010. Con trazabilidad completa.

---

## ESCENARIO 9 — Ticker con y sin autenticación · RESUELTO ✅

```
Caso A: Ticker en pantalla pública (sin auth)
  <smartrates-ticker currencies="USD,XUT,EUR">
  
  Muestra: 
    🇧🇴 USD/BOB oficial 6.96 BCB  │  📊 Ref.BCB 9.15  │  🔵 USDT 10.08 P2P  │  🇪🇺 EUR/BOB 11.28
    [datos globales — sin black rate de empresa]

Caso B: Ticker en formulario de Tryton (usuario de Maya S.R.L. autenticado)
  <smartrates-ticker currencies="USD,XUT,EUR" show-company-rate="true" api-key="...">
  
  Muestra:
    🇧🇴 USD/BOB oficial 6.96  │  📊 Ref.BCB 9.15  │  🔵 USDT 10.08 P2P
    │  🏢 Maya S.R.L.: C:7.36 V:7.56 (+0.50 ajuste)  ← en dorado
    │  🇪🇺 EUR/BOB 11.28  │ ...

El black rate de empresa aparece en dorado, diferenciado visualmente.
El widget sabe a qué empresa pertenece por el api-key.
```

**Resultado:** ✅ El Ticker es flexible: público (global) o autenticado (global + empresa).

---

## ESCENARIO 10 — catalog.RATE() con stablecoins XUT/XUC · RESUELTO ✅

```sql
-- Conversión: 1000 BOB a USDT (usa el P2P de CriptoYa como base)
SELECT catalog.RATE('25/05/2026', 'BOB', 'XUT', 1000, 2);
-- Internamente busca en rates.stablecoin_rates donde coin_code='XUT', fiat_code='BOB'
-- rate_mid = (9.82 + 10.08) / 2 = 9.95
-- 1000 / 9.95 = 100.50 USDT
-- Resultado: 100.50

-- Conversión inversa: 100 USDT a BOB
SELECT catalog.RATE('25/05/2026', 'XUT', 'BOB', 100, 2);
-- 100 × 9.95 = 995.00 BOB (usa el mid del P2P)
-- Resultado: 995.00

-- La función C detecta XUT/XUC y busca en la tabla correcta automáticamente
-- SPI query cambia según el prefijo X:
--   X-codes → rates.stablecoin_rates
--   Fiat    → rates.exchange_rates
```

**Resultado:** ✅ catalog.RATE() soporta nativamente XUT y XUC.

---

## ESCENARIO 11 — Backfill nocturno · Sin cambios materiales · ✅

El backfill sigue siendo 3 fases. La única diferencia: los datos del BCB histórico van al schema `validation` e `historical` dentro de `smartrates_db`, no a una BD separada.

---

## ESCENARIO 12 — Instalación de la extensión C · Simplificada · ✅

```sql
-- Antes: extensión necesitaba acceso a dos BDs
-- Ahora: todo en smartrates_db, un solo SPI context

-- En smartrates_db:
CREATE EXTENSION smartrates_rate;

-- En tryton_db (mismo cluster):
CREATE EXTENSION smartrates_rate;
-- La extensión busca en smartrates_db.rates.* y smartrates_db.rates.stablecoin_rates
-- Todo en el mismo cluster → SPI shared memory → nanosegundos ✅
```

---

## RESUMEN FINAL DE LA RE-SIMULACIÓN

| Escenario | v1.0 | v2.0 |
|---|---|---|
| 1 — Sincronización diaria | ✅ | ✅ |
| 2 — Confirmación ajuste (pantalla) | ✅ | ✅ mejorado con referencia P2P |
| 3 — JasperReports catalog.RATE() | ✅ | ✅ + soporte XUT/XUC |
| 4 — Fawazahmed0 falla | ✅ | ✅ |
| 5 — Multi-empresa | ⚠️ BLOQUEADO | ✅ global + ajuste por empresa |
| 6 — Dos sucursales, mismo ajuste | ⚠️ BLOQUEADO | ✅ ajuste es por empresa |
| 7 — Política national + USDT | ⚠️ BLOQUEADO | ✅ mismo black rate que USD |
| 8 — Timeout 17:00 sin confirmación | ⚠️ BLOQUEADO | ✅ UUID_SYSTEM + confirmed=false |
| 9 — Ticker público vs autenticado | ⚠️ BLOQUEADO | ✅ dos modos definidos |
| 10 — catalog.RATE() con XUT/XUC | 🔍 incompleto | ✅ stablecoin_rates separado |
| 11 — Backfill nocturno | ✅ | ✅ |
| 12 — Extensión C, una sola BD | 🔍 incompleto | ✅ simplificado |

**12/12 escenarios: ✅ sin ambigüedades**

---

## CAMBIOS APLICADOS A LOS DOCUMENTOS

| Cambio | Documentos afectados |
|---|---|
| `UST`→`XUT`, `USC`→`XUC` (convención X-prefix) | 007, 011, 015, 016, 017, 018, 019 |
| `is_crypto`→`is_stablecoin` | 007, 016 |
| `smartrates_validation_db`→ schema `validation` en `smartrates_db` | 007, 014, 016 |
| Nueva tabla `company.stablecoin_adjustment` | 007 |
| `UUID_SYSTEM = '00000000-0000-7777-0000-000000000000'` en seeds | 007, 019 |
| Nuevas RN-026 a RN-030 | 002 |
| Pantalla `AdjustmentScreen` con referencia USDT P2P en tiempo real | 013 |
| Ticker: modo público vs modo empresa | 017 |
| Principio arquitectónico: global vs por-empresa | 002, 000 |
| Documento 020-DECISIONES-CONSOLIDADAS.md (nuevo) | 020 |

---
_SKULL · SBOS · SmartRates · Re-Simulación Interna v2.0 · 2026-05-23_  
_12/12 escenarios resueltos · Proyecto listo para iniciar Fase 1_
