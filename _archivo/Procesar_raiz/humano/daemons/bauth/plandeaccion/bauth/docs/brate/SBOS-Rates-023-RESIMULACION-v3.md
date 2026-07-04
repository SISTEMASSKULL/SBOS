# RE-SIMULACIÓN INTERNA v3.0 — DEFINITIVA
## SBOS SmartRates · Modelo de dos niveles: Global SBOS + Por Empresa

**Fecha:** 2026-05-23  
**Basado en:** Decisión definitiva del humano + SBOS-Rates-022-AJUSTES-GLOBAL-EMPRESA.md  
**Estado:** ✅ 15/15 escenarios sin ninguna ambigüedad  

---

## EL PRINCIPIO QUE LO GOBIERNA TODO

```
╔══════════════════════════════════════════════════════════════════╗
║  RATES (cotizaciones)  →  SIEMPRE GLOBALES  →  rates.*          ║
║                            iguales para todos, sin excepción     ║
╠══════════════════════════════════════════════════════════════════╣
║  AJUSTE GLOBAL SBOS  →  nivel tenant  →  company.adjustment_global ║
║                         confirma: smartrates.global_operator     ║
║                         es el piso: todas las empresas heredan   ║
╠══════════════════════════════════════════════════════════════════╣
║  AJUSTE POR EMPRESA  →  nivel empresa  →  company.adjustment_daily ║
║                         confirma: smartrates.operator de la empresa║
║                         sobrescribe el global si existe           ║
║                         si no existe → hereda el global           ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## ESCENARIO 1 — Lunes normal, todo confirma a tiempo ✅

```
06:00 → fawazahmed0 sync → rates.exchange_rates (200+ monedas, global)
06:30 → BCB sync → oficial 6.86/6.96 + referencial 8.83/9.15 (global)
07:00 → DailySyncUsdtP2pJob → XUT/BOB 9.82/10.08 + XUC/BOB 9.78/10.02 (global)

07:30 → Jorge Villanueva (smartrates.global_operator) abre SmartRatesUI
        Ve en su pantalla de "Ajuste Global SBOS":
          Referencia P2P:    USDT 10.08  |  Spread vs oficial: 45.9%
          Referencial BCB:   VRD 8.83 / VRV 9.15
          Ajuste de ayer:    +0.50
          
        Jorge decide: el mercado se estabilizó, mantiene +0.50.
        
        POST /api/v1/sbos/adjustment/global/confirm
          {tenant:"skull", currency_code:"BOB", adjustment_value:0.50}
          
        company.adjustment_global:
          confirmed=true, confirmed_by=jorge-uuid, value=0.50, is_provisional=false

08:47 → María López (Maya S.R.L., smartrates.operator) abre la app
        Pantalla AdjustmentScreen muestra:
          Ajuste global SBOS: +0.50 (confirmado por Jorge a las 07:30)
          Ajuste de tu empresa ayer: +0.65
          Referencia P2P en vivo: USDT 10.08 ← SSE tiempo real
          
        María decide aplicar su propio ajuste: +0.65 (su empresa trabaja con un diferencial mayor)
        
        POST /api/v1/company/adjustment/confirm
          {company_id:"maya-uuid", currency_code:"BOB", adjustment_value:0.65}
          
        company.adjustment_daily:
          overrides_global=true, confirmed=true, confirmed_by=maria-uuid, value=0.65

09:00 → Luis Flores abre la app de Cóndor Import (use_black_rate='disabled')
        Cóndor Import no configura ajuste propio.
        
        AdjustmentResolver.resolve(condor-uuid, 'BOB', '2026-05-25'):
          ① empresa propia: no existe
          ② global SBOS: EXISTS → value=0.50
          → Retorna: {value:0.50, source:'global', level:'sbos'}
          
        Pero la política 'disabled' hace que Cóndor Import ignore el ajuste.
        Para ellos solo existe la cotización oficial del BCB.

10:00 → SmartTax de Maya S.R.L. calcula impuesto de factura en USD:
        GET /api/v1/rates/today  (JWT de Maya S.R.L.)
        Respuesta:
          cotizaciones_globales.oficial_bcb.mid = 6.91
          ajuste_efectivo.value = 0.65   (empresa propia)
          ajuste_efectivo.source = 'company'
          ajuste_efectivo.level = 'empresa'
          ajuste_efectivo.global_value = 0.50  (referencia informativa)
          black_rate.buy = 7.51   (6.86 + 0.65)
          black_rate.sell = 7.61  (6.96 + 0.65)
```

**Resultado:** ✅ Dos niveles funcionando perfectamente en paralelo.

---

## ESCENARIO 2 — Empresa hereda el global sin hacer nada ✅

```
Brisas S.R.L. (use_black_rate='reference') no tiene operador disponible hoy.
No confirma ningún ajuste propio.

GET /api/v1/rates/today  (JWT de Brisas S.R.L.)

AdjustmentResolver.resolve('brisas-uuid', 'BOB', '2026-05-25'):
  ① empresa propia: NO existe
  ② global SBOS: EXISTS → value=0.50 (confirmado por Jorge a las 07:30)
  → Retorna: {value:0.50, source:'global', level:'sbos', confirmed:true}

Respuesta:
  ajuste_efectivo.value = 0.50
  ajuste_efectivo.source = 'global'
  ajuste_efectivo.level = 'sbos'
  ajuste_efectivo.comment = "Usando ajuste global del SBOS. Tu empresa no ha configurado el suyo."
  
SmartRatesUI de Brisas muestra:
  Banner azul (no alarmante): "Usando ajuste global SBOS: +0.50 (sin ajuste propio de la empresa)"
  
NO se genera ninguna alerta. El sistema tiene un valor válido.
Brisas S.R.L. opera normalmente con el ajuste global.
```

**Resultado:** ✅ Herencia automática sin fricción.

---

## ESCENARIO 3 — SBOS global no confirmó, empresa tampoco ✅

```
Empresa Nueva S.R.L. (primera semana de operación, sin ajuste histórico).
SBOS global tampoco confirmó hoy.

Son las 14:00.

AdjustmentResolver.resolve('nueva-uuid', 'BOB', '2026-05-25'):
  ① empresa propia hoy: NO existe
  ② global SBOS hoy: NO existe
  ③ global SBOS ayer (fallback): EXISTS → value=0.48 (del día anterior)
  → Retorna: {value:0.48, source:'global_fallback', level:'sbos_ayer', is_provisional:true}

SmartRatesUI muestra:
  Banner ámbar: "⚠️ Sin ajuste confirmado hoy. Usando ajuste global del día anterior: +0.48"
  
AdjustmentReminderJob a las 12:00 ya notificó al global_operator:
  "El ajuste global SBOS no ha sido confirmado hoy."
  
A las 17:00 si sigue sin confirmarse:
  AdjustmentTimeoutJob crea adjustment_global provisional:
    confirmed=false, confirmed_by=UUID_SYSTEM, is_provisional=true, value=0.48
  
  Todas las empresas sin ajuste propio heredan este provisional.
  Banner ámbar en todas las apps sin ajuste propio.
```

**Resultado:** ✅ El sistema nunca queda sin un valor de ajuste.

---

## ESCENARIO 4 — Multi-empresa, tres políticas distintas ✅

```
SBOS global confirmó: +0.50
Maya S.R.L.     → confirma su propio: +0.65   (use_black_rate='national')
Cóndor Import   → no confirma nada             (use_black_rate='disabled')
Brisas S.R.L.   → no confirma nada             (use_black_rate='reference')

GET /rates/today (Maya):
  ajuste = 0.65 (empresa)    |  black_rate buy=7.51 sell=7.61
  aplica a: USD y XUT y XUC (política national)

GET /rates/today (Cóndor):
  ajuste = 0.50 (hereda global)
  BUT: política 'disabled' → no usa black rate en ningún cálculo
  cotización efectiva = siempre oficial BCB 6.86/6.96

GET /rates/today (Brisas):
  ajuste = 0.50 (hereda global)
  política 'reference' → muestra black_rate como referencia informativa
  black_rate mostrado: buy=7.36 sell=7.46   (6.86 + 0.50)
  NO usa el black rate en cálculos, solo lo muestra
  
GET /rates/today (sin auth, público):
  cotizaciones_globales = {oficial, referencial, USDT P2P, USDC P2P}
  ajuste_efectivo = null
  black_rate = null
```

**Resultado:** ✅ Cada empresa ve el mundo según su política y su ajuste.

---

## ESCENARIO 5 — Timeout 17:00: ahora con dos niveles ✅

```
17:00 → AdjustmentTimeoutJob dispara y ejecuta DOS verificaciones:

VERIFICACIÓN 1 — Ajuste global SBOS:
  ¿Existe adjustment_global para hoy? → NO
  → Busca el del día anterior: +0.49
  → Crea adjustment_global provisional:
     confirmed=false, confirmed_by=UUID_SYSTEM, is_provisional=true, value=0.49
     notes='PROVISIONAL-TIMEOUT-GLOBAL: valor del día anterior. Confirmar antes de las 20:00.'
  
VERIFICACIÓN 2 — Ajustes de empresa:
  Para cada empresa con política 'national' o 'reference':
    ¿Tiene adjustment_daily propio hoy con overrides_global=true? → NO
    → NO crea nada (la empresa ya heredará el provisional global)
    → SÍ registra en el log que esta empresa usará el global provisional
    
  ¿Alguna empresa tiene su propio ajuste pero como provisional?
    → Si yes: emite notificación específica solo a esa empresa
    
RESULTADO:
  El provisional global cubre a todas las empresas sin ajuste propio.
  Solo se crea UN registro provisional global, no N registros por empresa.
  El modelo de herencia elimina la explosión de registros provisionales.

NOTIFICACIONES emitidas por Reverb:
  Al global_operator: "⚠️ Se aplicó ajuste provisional global +0.49 (valor de ayer)"
  A operadores de empresas con política national/reference SIN ajuste propio:
    "ℹ️ Tu empresa usa el ajuste provisional global +0.49. Puedes confirmar el tuyo hasta las 20:00."
```

**Resultado:** ✅ Elegante. Un provisional global cubre todo el ecosistema.

---

## ESCENARIO 6 — Pantalla del operador de empresa ✅

```
María López (Maya S.R.L.) abre AdjustmentScreen:

┌──────────────────────────────────────────────────────────────────────────┐
│  AJUSTE DEL DÍA — Maya S.R.L. — Lunes 25/05/2026                       │
├──────────────────────────────────────────────────────────────────────────┤
│  Ajuste global SBOS hoy:   +0.50  ✅ (confirmado por Jorge · 07:30)     │
│  ─────────────────────────────────────────────────────────────────────── │
│  Cotizaciones globales:                                                  │
│    Oficial BCB:    C: 6.86   V: 6.96   Mid: 6.91                        │
│    Referencial:    C: 8.83   V: 9.15                                     │
│    🔵 USDT P2P:   C: 9.82   V: 10.08  ← actualización en vivo (SSE)    │
│    Spread oficial/USDT: 45.9%  (histórico: 25%)                         │
│  ─────────────────────────────────────────────────────────────────────── │
│  AJUSTE DE TU EMPRESA (sobrescribe el global):                           │
│  Ayer usaste: +0.65                                                      │
│                                                                          │
│  Si no confirmas tu ajuste, usarás el global: +0.50                     │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐      │
│  │  Ajuste de Maya S.R.L. hoy:  [ +0.65 ]  BOB  ← editable       │      │
│  └────────────────────────────────────────────────────────────────┘      │
│  Resultado: C: 7.51   V: 7.61   Spread: 0.10                            │
│                                                                          │
│  Nota: _________________________________                                 │
│                                                                          │
│  [Usar ajuste global (+0.50)]    [✓ Confirmar mi ajuste (+0.65)]        │
└──────────────────────────────────────────────────────────────────────────┘
```

**Botón "Usar ajuste global":** si la empresa decide no tener ajuste propio, lo elimina y hereda.
**Botón "Confirmar mi ajuste":** guarda su propio valor, sobrescribiendo el global.

**Resultado:** ✅ UX clara con las dos opciones explícitas.

---

## ESCENARIO 7 — Pantalla del global_operator ✅

```
Jorge Villanueva (smartrates.global_operator) abre su pantalla:

┌──────────────────────────────────────────────────────────────────────────┐
│  AJUSTE GLOBAL SBOS — Tenant: SKULL — Lunes 25/05/2026                  │
├──────────────────────────────────────────────────────────────────────────┤
│  Este ajuste aplica a TODAS las empresas que no tienen ajuste propio.    │
│  Actualmente sin ajuste propio: Cóndor Import, Brisas S.R.L.            │
│  Con ajuste propio: Maya S.R.L. (+0.65 - pendiente de confirmar)         │
│  ─────────────────────────────────────────────────────────────────────── │
│  Mercado de referencia:                                                  │
│    🔵 USDT/BOB ahora:   C: 9.82   V: 10.08  ← SSE                       │
│    Referencial BCB:     C: 8.83   V: 9.15                               │
│    Spread vs oficial:   45.9%  ⚠️ sobre promedio histórico (25%)        │
│  ─────────────────────────────────────────────────────────────────────── │
│  Ajuste global de ayer: +0.50                                            │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐      │
│  │  Ajuste global SBOS hoy:  [ +0.50 ]  BOB  ← editable          │      │
│  └────────────────────────────────────────────────────────────────┘      │
│  Con este ajuste:  C: 7.36   V: 7.46   Spread: 0.10                    │
│                                                                          │
│  📋 Empresas que heredarán este ajuste: Cóndor Import, Brisas S.R.L.    │
│                                                                          │
│  [✓ Confirmar ajuste global]                                            │
└──────────────────────────────────────────────────────────────────────────┘
```

**Resultado:** ✅ El global_operator tiene visibilidad de qué empresas dependen de su confirmación.

---

## ESCENARIO 8 — Política 'national' + USDT · Mismo modelo ✅

```
Maya S.R.L.: use_black_rate='national', ajuste empresa=+0.65
Cliente paga con USDT (XUT).

AdjustmentResolver.resolve('maya-uuid', 'XUT', '2026-05-25'):
  ① empresa propia XUT: existe → value=0.15 (Maya configuró diferencial especial para USDT)
  → Retorna: {value:0.15, source:'company', coin:'XUT'}

P2P base: 9.82/10.08
Con ajuste empresa para USDT:
  black_usdt_buy  = 9.82 + 0.15 = 9.97
  black_usdt_sell = 10.08 + 0.15 + spread(0.10) = 10.33

Si Maya NO hubiera configurado ajuste propio para XUT:
  → Hereda global XUT: si existe el global_operator lo configuró
  → Si no hay global XUT: usa P2P directo de CriptoYa (adjustment_value=0)
  
En todos los casos:
  GET /rates/today (JWT Maya) retorna:
    black_rate     → USD: buy 7.51 / sell 7.61 (ajuste empresa +0.65)
    black_usdt     → XUT: buy 9.97 / sell 10.33 (ajuste empresa +0.15)
    black_usdc     → XUC: usando global o P2P según configuración
    applies_to     → ['USD','XUT','XUC'] (política national)
```

**Resultado:** ✅ Stablecoins siguen el mismo modelo de dos niveles.

---

## ESCENARIO 9 — catalog.RATE() con ajuste de empresa ✅

```sql
-- La función catalog.RATE() usa SIEMPRE las cotizaciones globales
-- NO aplica ajustes de empresa — eso es responsabilidad del caller

-- En JasperReports de Maya S.R.L.:
SELECT
    p.precio_bob,
    -- Para reportes fiscales → usar tasa oficial siempre
    catalog.RATE('25/05/2026', 'BOB', 'USD', p.precio_bob, 2) AS precio_usd_oficial,
    
    -- Para reportes operativos → el ajuste lo aplica la query, no RATE()
    catalog.RATE('25/05/2026', 'BOB', 'USD', p.precio_bob, 2) *
        (1 + (SELECT adjustment_value FROM company.adjustment_daily
              WHERE company_id='maya-uuid' AND rate_date='2026-05-25'
              AND overrides_global=true LIMIT 1) / 6.91
        ) AS precio_usd_black_rate
FROM inventario.productos p;

-- catalog.RATE() es pura matemática de mercado global
-- El ajuste de empresa es responsabilidad del sistema que consume la función
```

**Resultado:** ✅ `catalog.RATE()` mantiene su rol limpio. No mezcla políticas de empresa.

---

## ESCENARIO 10 — Ticker: público vs empresa vs global_operator ✅

```
Sin auth (público, web, pantallas informativas):
  <smartrates-ticker>
  Muestra: oficial BCB + referencial BCB + USDT P2P + USDC P2P
  NO muestra ningún black rate de empresa
  
Con auth (operador de Maya S.R.L.) + show-company-rate="true":
  <smartrates-ticker show-company-rate="true" api-key="...">
  Muestra: todo lo anterior
    + 🏢 Maya S.R.L.: C:7.51 V:7.61 (propio +0.65)   ← dorado
    
Con auth (global_operator de SBOS) + show-global="true":
  <smartrates-ticker show-global="true" api-key="...">
  Muestra: todo lo anterior
    + 🌐 SBOS Global: C:7.36 V:7.46 (+0.50)   ← plateado
    + Badge: "2 empresas heredando este ajuste"
```

**Resultado:** ✅ Tres modos de visualización claros y consistentes.

---

## RESUMEN FINAL — TODOS LOS ESCENARIOS

| # | Escenario | v1.0 | v2.0 | v3.0 |
|---|---|---|---|---|
| 1 | Sincronización diaria | ✅ | ✅ | ✅ |
| 2 | Empresa hereda global | ⚠️ | ✅ parcial | ✅ completo |
| 3 | SBOS y empresa sin confirmar | ⚠️ | ✅ | ✅ con fallback |
| 4 | Multi-empresa tres políticas | ⚠️ | ✅ | ✅ |
| 5 | Timeout 17:00 dos niveles | ⚠️ | ✅ | ✅ UN provisional global |
| 6 | Pantalla operador empresa | ✅ | ✅ + P2P | ✅ + botón global |
| 7 | Pantalla global_operator | ❌ no existía | ❌ no existía | ✅ nuevo |
| 8 | national + USDT/USDC | ⚠️ | ✅ | ✅ mismo modelo |
| 9 | catalog.RATE() rol limpio | ✅ | ✅ | ✅ no mezcla empresa |
| 10 | Ticker tres modos | ⚠️ | ✅ | ✅ público/empresa/global |
| 11 | JasperReports masivo | ✅ | ✅ | ✅ |
| 12 | Backfill nocturno | ✅ | ✅ | ✅ |
| 13 | Fawazahmed0 falla | ✅ | ✅ | ✅ |
| 14 | SBOS acoplado + ctx_id | ✅ | ✅ | ✅ |
| 15 | Standalone sin SBOS | ✅ | ✅ | ✅ |

**15/15 escenarios: ✅ sin ninguna ambigüedad**

---

## DOCUMENTOS ACTUALIZADOS EN ESTA VERSIÓN

| Doc | Qué cambió |
|---|---|
| SBOS-Rates-002-DOMINIO | +RN-031..035, modelo dos niveles |
| SBOS-Rates-007-DATOS | +adjustment_global, +stablecoin_adjustment_global, UUID_SYSTEM |
| SBOS-Rates-008-SEGURIDAD | +rol smartrates.global_operator |
| SBOS-Rates-013-FRONTEND-FLUTTER | Pantalla global_operator nueva, AdjustmentScreen con botón "Usar global" |
| SBOS-Rates-022-AJUSTES-GLOBAL-EMPRESA | **Nuevo** — documento definitivo del modelo |
| SBOS-Rates-023-RESIMULACION-v3 | **Nuevo** — este documento |

---
_SKULL · SBOS · SmartRates · SBOS-Rates-023-RESIMULACION-v3 · 2026-05-23_  
_15/15 escenarios resueltos · Proyecto 100% listo para Fase 1 del desarrollo_
