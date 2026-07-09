# Plan de Backfill Histórico — SBOS SmartRates

---

## Objetivo

Poblar la base de datos con cotizaciones históricas desde 1990 sin interrumpir la operación diaria, sin bloquear las fuentes externas, y sin depender de intervención humana una vez iniciado el proceso.

**Al completarse el backfill, SmartRates tendrá:**
- Bolivia (BOB): historial diario desde 2022, mensual desde 1940
- 179 países FMI: historial mensual desde 1980-2000 según el país
- BCB histórico (referencia): datos mensuales 1990-2015 directamente del BCB

---

## Las tres fases

### Fase 1 — fawazahmed0: datos diarios 2022 hasta hoy

**Fuente:** fawazahmed0 / cdn.jsdelivr.net  
**Cobertura:** 200+ monedas, frecuencia diaria  
**Fecha desde:** 2022-01-01  
**Fecha hasta:** ayer (hoy ya se descargó por el job diario)  
**Requests necesarios:** ~1.600 (4 años × 365 días, uno por día)  
**Requests por noche:** 100 máximo  
**Pausa entre requests:** 30 segundos  
**Noches estimadas:** ~16 noches automáticas  
**Ventana de ejecución:** 01:00 - 04:00 (máximo 3 horas por noche)  

**URL por fecha:**
```
https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@{YYYY-MM-DD}/v1/currencies/usd.min.json
```

**Qué datos carga:**
- Un request por día = todas las monedas de ese día (200+)
- UPSERT masivo: si ya existe el dato, lo ignora (ON CONFLICT DO NOTHING)
- `type_code='official_daily'`, `quality='high'`, `source_code='fawazahmed0'`

---

### Fase 2 — FMI SDMX: datos mensuales 2016-2021

**Fuente:** FMI SDMX API 3.0  
**Cobertura:** 179 países miembro FMI  
**Fecha desde:** 2016-01 (desde donde fawazahmed0 no tiene cobertura completa diaria)  
**Fecha hasta:** 2021-12  
**Requests necesarios:** 12-48 en total (estrategia de batching múltiple países por request)  
**Pausa entre requests:** 30 segundos  
**Noches estimadas:** 1 sola noche (todos los requests caben en la ventana nocturna)  

**Estrategia de batching (clave para eficiencia):**
```
Un solo request puede obtener múltiples países y todo un año:

URL: https://api.imf.org/external/sdmx/3.0/data/dataflow/IMF.STA/ER/%2B/{KEY}
     ?c%5BTIME_PERIOD%5D=ge%3A{AÑO}-01%2Ble%3A{AÑO}-12

KEY: BOL+BRA+ARG+MEX+PER+PRY+CHL+URY+VEN+ECU+COL+PAN+CRI+GTM+HND+SLV+NIC+CUB+HTI+DOM+JAM+TTO.XDC_USD.PA_RT.M

→ 22 países LATAM × 12 meses = 264 registros en UN solo request
→ 6 años ÷ 1 año por request = 6 requests para LATAM completo
→ Similar para G7, Europa, Asia, África
→ Total: ~48 requests para cubrir 179 países 2016-2021
```

**Qué datos carga:**
- `type_code='official_monthly'`, `quality='medium'`, `source_code='imf_sdmx'`
- `rate_date` = primer día hábil del mes (para compatibilidad con series diarias)
- El resto de los días del mes se interpolan o se marcan como `carried_forward` desde el dato mensual

**Autenticación:**
```
Header: Ocp-Apim-Subscription-Key: c2800287220f4bc18e147ad8dba321ab
```

---

### Fase 3 — BCB histórico: referencia 1990-2015

**Fuente:** BCB Bolivia (portal web)  
**Cobertura:** BOB principalmente + monedas disponibles en el BCB histórico  
**Fecha desde:** 1990-01 (primer registro disponible en el BCB)  
**Fecha hasta:** 2015-12 (desde 2016 cubierto por FMI en Fase 2)  
**Requests necesarios:** ~312 (26 años × 12 meses = archivos Excel mensuales)  
**Requests por noche:** 50 máximo (BCB es más restrictivo)  
**Pausa entre requests:** 60 segundos  
**Noches estimadas:** ~7 noches automáticas  

**URL por mes:**
```
https://www.bcb.gob.bo/librerias/indicadores/otras/otras_imprimir2XLS.php?qdd=1&qmm={m}&qaa={a}
```
(siempre descarga el día 1 del mes para obtener el dato mensual referencial)

**Qué datos carga:**
- Base de datos: `smartrates_db (schema validation)`, schema: `historical`
- Tabla: `historical.bcb_rates`
- `type_code='historical_ref'`, `quality='low'`
- Son datos de referencia — NO se mezclan con los datos operativos de `smartrates_db`

---

## Tabla de control: sync.backfill_progress

```sql
CREATE TABLE sync.backfill_progress (
    phase               SMALLINT        NOT NULL, -- 1, 2, 3
    current_date        DATE            NOT NULL, -- última fecha procesada
    target_date_from    DATE            NOT NULL, -- objetivo inicio
    target_date_to      DATE            NOT NULL, -- objetivo fin
    requests_tonight    INTEGER         NOT NULL DEFAULT 0,
    requests_total      INTEGER         NOT NULL DEFAULT 0,
    status              VARCHAR(20)     NOT NULL DEFAULT 'pending', -- pending|active|paused|completed|error
    last_run_at         TIMESTAMPTZ     NOT NULL DEFAULT '1900-01-01',
    error_message       TEXT            NOT NULL DEFAULT '',
    notes               TEXT            NOT NULL DEFAULT '',
    PRIMARY KEY (phase)
);

-- Registros iniciales (se crean al instalar SmartRates)
INSERT INTO sync.backfill_progress VALUES
    (1, '2022-01-01', '2022-01-01', CURRENT_DATE - 1, 0, 0, 'pending', ...),
    (2, '2016-01-01', '2016-01-01', '2021-12-31',     0, 0, 'pending', ...),
    (3, '1990-01-01', '1990-01-01', '2015-12-31',     0, 0, 'pending', ...);
```

---

## Algoritmo del BackfillJob

```
BackfillJob — corre a las 01:00, ventana 01:00-04:00

1. Determinar la fase activa:
   SELECT * FROM sync.backfill_progress
   WHERE status = 'active'
   ORDER BY phase ASC LIMIT 1;

   Si no hay fase 'active', tomar la primera 'pending'.
   Si todas están 'completed': el job termina y no vuelve a correr.

2. Verificar que estamos en la ventana nocturna:
   Si hora actual > 04:00: detenerse, actualizar last_run_at.

3. Determinar cuántos requests se pueden hacer esta noche:
   limite = {100 para fase 1, 100 para fase 2, 50 para fase 3}
   requests_hechos_esta_noche = 0

4. Bucle principal:
   MIENTRAS requests_hechos_esta_noche < limite Y hora < 04:00:

     a. Calcular la próxima fecha/lote a procesar
        (para fase 1: siguiente fecha diaria desde current_date)
        (para fase 2: siguiente año/grupo de países)
        (para fase 3: siguiente mes desde current_date)

     b. Hacer el request a la fuente correspondiente
        → Si falla: reintentar con backoff (máx 3 intentos)
        → Si sigue fallando: marcar error, salir del bucle

     c. UPSERT de los datos descargados (ON CONFLICT DO NOTHING para no sobrescribir)

     d. Actualizar backfill_progress.current_date
     e. requests_hechos_esta_noche++
     f. Dormir {30 o 60} segundos (pausa anti-bloqueo)

5. Actualizar:
   backfill_progress.requests_tonight = requests_hechos_esta_noche
   backfill_progress.requests_total   += requests_hechos_esta_noche
   backfill_progress.last_run_at      = NOW()

6. Si current_date >= target_date_to:
   backfill_progress.status = 'completed'
   → Activar la siguiente fase (si existe)
   → Emitir evento WebSocket: BackfillPhaseCompleted
```

---

## Cronograma estimado de ejecución

| Semana | Fase | Actividad | Estado esperado |
|---|---|---|---|
| Semana 1, noches 1-7 | Fase 1 | fawazahmed0 2022 → 2023 (700 días) | 700/1.600 días procesados |
| Semana 2, noches 8-16 | Fase 1 | fawazahmed0 2023 → hoy | Fase 1 completada |
| Semana 3, noche 17 | Fase 2 | FMI 2016-2021 completo | Fase 2 completada en 1 noche |
| Semana 3-4, noches 18-24 | Fase 3 | BCB histórico 1990-2015 | Fase 3 completada |
| **Total: 3-4 semanas** | | | **Historial completo disponible** |

---

## Gestión manual del backfill

```http
# Ver estado actual de todas las fases
GET /api/v1/sync/backfill
Authorization: Bearer {token_admin}

# Respuesta ejemplo:
{
  "phases": [
    {"phase": 1, "status": "active", "progress": "2023-07-15", "target": "2026-05-22",
     "pct_complete": 45, "nights_remaining": 9},
    {"phase": 2, "status": "pending", "progress": "2016-01-01", "target": "2021-12-31"},
    {"phase": 3, "status": "pending", "progress": "1990-01-01", "target": "2015-12-31"}
  ]
}

# Pausar el backfill (ej: si se necesita todo el ancho de banda nocturno)
POST /api/v1/sync/backfill
{"action": "pause", "phase": 1}

# Reanudar
POST /api/v1/sync/backfill
{"action": "resume", "phase": 1}

# Saltar a una fecha específica (si hay datos corruptos en un rango)
POST /api/v1/sync/backfill
{"action": "set_date", "phase": 1, "date": "2023-01-01"}
```

---

## Calidad de datos por fase

| Fase | Fuente | `quality` | `type_code` | Cobertura temporal |
|---|---|---|---|---|
| 1 | fawazahmed0 | `high` | `official_daily` | Diaria desde 2022 |
| 2 | FMI SDMX | `medium` | `official_monthly` | Mensual 2016-2021 |
| 3 | BCB Bolivia | `low` | `historical_ref` | Mensual referencia 1990-2015 |
| Sync diario | fawazahmed0 | `high` | `official_daily` | Desde el día de instalación |
| Fin de semana | Calculado | `medium` | `carried_forward` | Automático |

---

## Importancia del historial para Bolivia

El historial de tipos de cambio BOB desde 1990 es un dato **único y estratégico** por las siguientes razones:

**Historia económica boliviana que justifica el historial completo:**

- **1990-2003:** El BOB se devaluó gradualmente desde ~2.87 hasta ~8.0 por dólar, recuperándose luego hasta los ~6.9 actuales. Este período incluye la hiperinflación residual y la estabilización del Boliviano.

- **2003-2023:** Estabilidad inusual — el BCB mantuvo el BOB/USD en el rango 6.86-6.96 durante 20 años. Período de referencia para análisis de contratos de largo plazo.

- **2023-2025:** Tensión cambiaria — escasez de divisas, diferencial creciente entre tipo oficial y mercado alternativo, restricciones del BCB para operaciones en USD.

- **Diciembre 2025:** El BCB introduce el "valor referencial del dólar" basado en operaciones reales del sistema financiero. Inicio de la transición hacia mayor flexibilidad cambiaria.

Ningún proveedor global de APIs de tipos de cambio tiene este historial completo y verificado del BOB. **SmartRates es la única fuente que lo tendrá.**

---
_SKULL · SBOS · SmartRates · 012-BACKFILL-HISTORICO · v1.0 · 2026-05-23_
