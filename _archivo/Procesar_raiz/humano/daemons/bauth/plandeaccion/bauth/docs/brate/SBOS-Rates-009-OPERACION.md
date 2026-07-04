# Operación y Calidad de Servicio — SBOS SmartRates

---

## SLA y objetivos de servicio

| Métrica | Objetivo | Crítico |
|---|---|---|
| Disponibilidad mensual | 99.5% (≤ 3.6 horas inactividad/mes) | < 99.0% = incidente |
| RTO (Recovery Time Objective) | 2 horas | > 4 horas = escalada |
| RPO (Recovery Point Objective) | 24 horas | > 48 horas = escalada |
| Latencia p95 endpoints cacheados | < 200ms | > 1.000ms = alerta |
| Latencia p95 endpoints DB | < 500ms | > 2.000ms = alerta |
| Latencia p95 conversión batch 100 | < 1.000ms | > 5.000ms = alerta |
| Disponibilidad cotización del día | 100% antes de las 07:00 | No disponible a las 07:00 = página de guardia |
| Tasa de error 5xx | < 0.1% | > 1% = alerta |

---

## SRE Golden Signals

SmartRates expone `/metrics` en formato Prometheus. El stack LGTM del SBOS (Prometheus + Grafana + Loki + Tempo) los recolecta automáticamente.

### Latency

```prometheus
# Histograma de latencia por endpoint
smartrates_http_request_duration_seconds{method, endpoint, status}

# Latencia de fuentes externas
smartrates_sync_source_duration_seconds{source}

# Latencia de catalog.RATE() (medida desde el trigger PG)
smartrates_rate_function_duration_nanoseconds{currency_pair}
```

### Traffic

```prometheus
# Requests por segundo por endpoint
smartrates_http_requests_total{method, endpoint, status}

# Conversiones ejecutadas por tipo
smartrates_conversions_total{type}  # single|multi|batch|historical

# Cotizaciones descargadas por fuente
smartrates_rates_synced_total{source, currency}
```

### Errors

```prometheus
# Errores por tipo de error SR-XXX
smartrates_errors_total{error_code, endpoint}

# Fallos de sincronización por fuente
smartrates_sync_failures_total{source}

# Estado del circuit breaker por fuente
smartrates_circuit_breaker_state{source}  # 0=CLOSED, 1=OPEN, 2=HALF_OPEN
```

### Saturation

```prometheus
# Cache hit rate Redis
smartrates_cache_hit_rate{cache_key_prefix}

# Cola de Horizon (jobs pendientes)
smartrates_horizon_queue_size{queue}

# Conexiones activas a PostgreSQL
smartrates_db_connections_active

# Uso de memoria del proceso PHP
smartrates_php_memory_usage_bytes
```

### Métricas de negocio adicionales

```prometheus
# Cotizaciones disponibles en el día actual (debería ser ~200)
smartrates_rates_available_today{source}

# Días cubiertos en el backfill por fase
smartrates_backfill_progress_days{phase}

# Diferencia BCB vs fawazahmed0 para BOB/USD
smartrates_bcb_validation_difference_bob_usd

# Ajustes confirmados / no confirmados del día
smartrates_daily_adjustment_confirmed{company_id}
```

---

## Scheduler — horario de ejecución

### Jobs diarios

| Job | Hora Bolivia (BOT = UTC-4) | Días | Fuente | Descripción |
|---|---|---|---|---|
| `DailySyncFawazahmedJob` | 06:00 | Todos (L-D) | fawazahmed0 | Descarga 200+ monedas del día |
| `DailySyncBcbJob` | 06:30 | Lunes a viernes | BCB Bolivia | Descarga Excel de compra/venta BOB |
| `DailySyncFrankfurterJob` | 07:00 | Días hábiles | Frankfurter | Respaldo 32 monedas BCE |
| `BcbCrossValidationJob` | 07:30 | Lunes a viernes | — | Valida BCB vs fawazahmed0 para BOB/USD |
| `WeekendCarriedForwardJob` | 06:05 | Sábado y domingo | — | Crea registros `carried_forward` para el fin de semana |
| `AdjustmentReminderJob` | 12:00 | Lunes a viernes | — | Notifica si el ajuste del día aún no fue confirmado |
| `AdjustmentTimeoutJob` | 17:00 | Lunes a viernes | — | Aplica ajuste provisional si no fue confirmado |
| `HealthCheckJob` | Cada 15 min | Todos | Todas | Verifica conectividad con todas las fuentes |

### Jobs mensuales

| Job | Hora | Día | Descripción |
|---|---|---|---|
| `MonthlySyncImfJob` | 08:00 | Día 5 | Descarga datos mensuales FMI del mes anterior |
| `MonthlyPartitionCreateJob` | 00:01 | Día 1 | Crea la partición del mes siguiente en tablas particionadas |

### Backfill nocturno

| Job | Ventana | Límite | Descripción |
|---|---|---|---|
| `BackfillJob` (fase activa) | 01:00-04:00 | 100 req/noche (fawazahmed0), 50 req/noche (BCB) | Solo corre si hay fases pendientes. Se autodetiene a las 04:00 |

---

## Reglas de manejo de fechas especiales

### Lunes

```
① Descargar sábado anterior
② Descargar domingo anterior
③ Descargar lunes actual
④ Para BCB: crear carried_forward del sábado y domingo usando el dato del viernes
```

### Día post-feriado

```
① Detectar cuántos días hábiles se saltaron
② Descargar cada día desde el último hábil hasta hoy
③ Para los días del feriado: crear carried_forward del último dato disponible
```

### fines de semana (sábado y domingo)

```
fawazahmed0: SÍ opera en fin de semana → almacenar como 'official_daily'
BCB Bolivia: NO publica en fin de semana → crear 'carried_forward' del viernes
FMI: NO aplica (datos mensuales)
```

---

## Circuit Breaker por fuente

Implementación del patrón Circuit Breaker (Resiliency4j conceptualmente, implementado en Laravel):

```
CLOSED (normal)
  ↓ después de 3 fallos consecutivos en < 2 minutos
OPEN (bloqueado)
  ↓ después de 10 minutos de espera
HALF_OPEN (probando)
  ↓ si el próximo request tiene éxito → CLOSED
  ↓ si falla → OPEN (reinicia el temporizador)
```

**Comportamiento por fuente:**
- `fawazahmed0` OPEN → activa `frankfurter` automáticamente
- `frankfurter` OPEN → usa el último dato disponible con `carried_forward`
- `bcb_bolivia` OPEN → solo afecta a la validación, no a las cotizaciones operativas
- `imf_sdmx` OPEN → solo afecta al sync mensual; el sistema sigue funcionando sin él

---

## Política de cache Redis

| Dato | TTL | Estrategia | Clave Redis |
|---|---|---|---|
| Cotizaciones del día (`/rates/today`) | 5 minutos | Cache-aside. Se invalida al completar un sync exitoso | `smartrates:rates:today:{tenant}` |
| Cotizaciones por fecha | 24 horas | Cache-aside. Dato histórico — no cambia | `smartrates:rates:{date}:{tenant}` |
| Catálogo de monedas | Sin TTL (hasta restart) | Warm en startup | `smartrates:catalog:currencies` |
| Catálogo de países | Sin TTL (hasta restart) | Warm en startup | `smartrates:catalog:countries` |
| Conversión simple | 5 minutos | Cache-aside | `smartrates:convert:{from}:{to}:{amount}:{date}` |
| Estado de fuentes (circuit breaker) | Sin TTL (estado en BD) | Write-through | `smartrates:circuit:{source}` |
| Configuración de empresa | 10 minutos | Cache-aside. Se invalida al actualizar | `smartrates:company:{company_id}:config` |

**Invalidación:** El evento `SyncCompleted` invalida automáticamente `smartrates:rates:today:*` para todos los tenants.

---

## Backups

### PostgreSQL — estrategia por entorno

#### Modo standalone (desarrollo)
```bash
# Backup manual antes de operaciones destructivas
docker exec smartrates_db pg_dump -U smartrates smartrates_db > backup_$(date +%Y%m%d).sql
```

#### Modo SBOS producción
El cluster Patroni HA del SBOS gestiona los backups automáticamente:
- **WAL archiving continuo** → `s3://sbos-backups/smartrates/wal/`
- **Base backup diaria** a las 03:00 Bolivia → `s3://sbos-backups/smartrates/base/`
- **Retención:** 90 días de WAL + 30 base backups
- **Prueba de restauración:** mensual (automatizada)
- **PITR (Point-in-Time Recovery):** disponible hasta el minuto para el RPO de 24 horas

### Redis — estrategia

- **AOF (Append Only File):** habilitado en producción — persistencia de todas las operaciones
- **RDB snapshot:** cada 6 horas como seguro adicional
- **Política de eviction:** `allkeys-lru` — Redis puede evictar cualquier key si hay presión de memoria
- **Nota:** Redis es cache — si se pierde, el sistema lo reconstruye automáticamente al primer request. No es fuente de verdad.

---

## Docker Compose — servicios por modo

### Servicios siempre presentes (todos los modos)

```yaml
services:
  app:        # SmartRatesAPI — Laravel 13
  reverb:     # WebSockets — Laravel Reverb
  horizon:    # Queue workers — Laravel Horizon
```

### Solo en DB_MODE=local (desarrollo)

```yaml
  db_smartrates:      # PostgreSQL 18 — smartrates_db
  db_validation:      # PostgreSQL 18 — smartrates_db (schema validation)
  redis:              # Redis 7
  frankfurter:        # BCE respaldo — auto-alojado
```

### Solo en AUTH_DRIVER=keycloak + KEYCLOAK_MODE=local

```yaml
  keycloak:           # Keycloak 24 — SSO local para desarrollo
  keycloak_db:        # PostgreSQL para Keycloak
```

### Scripts de operación

| Script | Propósito |
|---|---|
| `./dev.sh` | Levanta stack completo: Sanctum + DB local + todas las fuentes |
| `./dev-keycloak.sh` | Igual que `dev.sh` + Keycloak local para probar modo SBOS |
| `./deploy.sh` | Build, push al registry, deploy a K8s con health check |
| `./artisan-in-docker.sh` | Ejecuta comandos artisan dentro del contenedor |

---

## Runbooks operativos

### Runbook 1 — fawazahmed0 no sincronizó

**Síntoma:** `GET /sync/sources` muestra `fawazahmed0.state = OPEN`  
**Impacto:** Las cotizaciones del día son del día anterior (`carried_forward`)  
**Pasos:**
1. Verificar conectividad: `curl https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.min.json`
2. Verificar el URL de respaldo: `curl https://latest.currency-api.pages.dev/v1/currencies/usd.min.json`
3. Si ambos fallan, esperar recuperación automática (circuit breaker reintenta cada 10 minutos)
4. Si el problema persiste > 2 horas: `POST /sync/trigger?source=frankfurter` para sincronizar con BCE
5. Registrar el incidente en el log de operaciones

### Runbook 2 — BCB no descargó

**Síntoma:** `sync.sync_log` no tiene registro exitoso de `bcb_bolivia` para hoy  
**Impacto:** Solo afecta a la validación cruzada — las cotizaciones operativas siguen funcionando  
**Pasos:**
1. Verificar si es día hábil en Bolivia (puede ser feriado no registrado en el sistema)
2. Ir manualmente a `www.bcb.gob.bo` y verificar si hay Excel disponible para hoy
3. Si hay Excel: descargar manualmente e importar via `POST /sync/trigger?source=bcb_manual`
4. Si no hay Excel (BCB no publicó): registrar en el log y el sistema continuará con `carried_forward`

### Runbook 3 — El operador no confirmó el ajuste del día

**Síntoma:** `GET /company/adjustment/status` retorna `confirmed: false` después de las 17:00  
**Impacto:** El sistema aplicó automáticamente el ajuste del día anterior como provisional  
**Pasos:**
1. Contactar al operador para confirmar si el ajuste del día anterior sigue siendo válido
2. Si el operador confirma que el provisional es correcto: registrar en el log, sin acción adicional
3. Si necesitan cambiar el valor: el operador debe confirmar el ajuste del día con el valor correcto (sobrescribe el provisional)

### Runbook 4 — Base de datos no disponible

**Síntoma:** `GET /ready` retorna `{"status":"degraded","details":{"database":"unavailable"}}`  
**Impacto crítico:** El sistema no puede servir cotizaciones — degradación total  
**Pasos (modo SBOS Patroni):**
1. Verificar el estado del cluster: `kubectl get pods -n {tenant}-smartrates`
2. Si hay failover en curso: esperar hasta 2 minutos (Patroni gestiona automáticamente)
3. Si el primario no levanta: escalar a DBA del SBOS
4. Mientras dure la interrupción: el Ticker y los endpoints cacheados siguen sirviendo desde Redis

### Runbook 5 — Rotar API key del FMI

**Frecuencia recomendada:** Anual  
**Pasos:**
1. Ir a `https://portal.api.imf.org/portal/api/external/sdmx/3.0` → "My Profile" → "Regenerate Key"
2. **En modo standalone:** actualizar `.env.local` con la nueva key → reiniciar el contenedor `app`
3. **En modo SBOS:** actualizar en Vault: `vault kv put secret/tenants/{realm}/smartrates/imf-api-key value={nueva_key}` → el pod recarga automáticamente los secrets en el próximo ciclo

---

## Purga de datos históricos

### Política de retención por tabla

| Tabla | Retención | Mecanismo de purga |
|---|---|---|
| `rates.exchange_rates` | 10 años mínimo | `DROP PARTITION y{año}` — instantáneo |
| `sync.sync_log` | 2 años | `DROP PARTITION q{año}{trimestre}` |
| `security.audit_log` | 90 días (3 meses) | `DROP PARTITION q{año}{trimestre}` |
| `validation.bcb_cotizaciones` | 5 años | DELETE por `rate_date < NOW() - INTERVAL '5 years'` |
| `broadcast.messages` | 30 días | DELETE por `active_until < NOW() - INTERVAL '30 days'` |

### Job de mantenimiento

`MonthlyMaintenanceJob` — corre el día 1 de cada mes a las 02:00:
1. Crea la partición del mes siguiente en todas las tablas particionadas
2. Identifica particiones elegibles para purga según la política
3. Genera un reporte de espacio liberado
4. Ejecuta `VACUUM ANALYZE` en las tablas más activas

---

## Monitoreo de la disponibilidad del dato del día

**Alerta crítica:** Si a las 07:00 hora Bolivia el endpoint `/api/v1/rates/today` retorna menos del 80% de las monedas activas configuradas, se genera una alerta CRITICAL y se despierta a la persona de guardia.

**Verificación mínima de integridad:**
- BOB debe estar disponible con dato del día (no `carried_forward`)
- USD/EUR/BRL/ARS/PEN deben estar disponibles (monedas LATAM prioritarias)
- Si alguna falta: el sistema intenta resinc inmediato de esa fuente

---
_SKULL · SBOS · SmartRates · 009-OPERACION · v1.0 · 2026-05-23_
