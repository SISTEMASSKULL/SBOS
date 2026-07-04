# ADR-037 — Observabilidad Semántica — ctx_id Obligatorio en Logs, Trazas y Métricas

**Estado:** Aceptado  
**Fecha:** 2026-06-13  
**Origen:** §13 Observabilidad Semántica del Master v2.1  
**Relacionado:** ADR-033 (RequestContext), ADR-036 (interceptores), ADR-017 (stack canónico OTel)

---

## Contexto y problema

"Observabilidad" sin contexto de negocio es monitoreo de infraestructura: saber que la CPU está al 80% no dice nada sobre qué tenant tiene un problema o qué operación de negocio está fallando. El SBOS requiere "observabilidad semántica": cada métrica, log y traza debe tener el contexto empresarial (`ctx_id`, `tenant_id`, `correlation_id`) para ser útil.

## La Decisión

**Todo log, traza (span) y métrica en el SBOS lleva los cuatro campos semánticos obligatorios: `ctx_id`, `tenant_id`, `correlation_id`, `method`. El OTel Collector es el único agregador — sin sidecars propietarios.**

### Los Cuatro Campos Semánticos Obligatorios

```go
// CAMPOS OBLIGATORIOS en todo log estructurado:
log.Info().
    Str("ctx_id", rc.CtxId).           // 1. Obligatorio siempre
    Str("tenant_id", rc.TenantId).      // 2. Obligatorio siempre
    Str("correlation_id", rc.CorrelationId). // 3. Obligatorio siempre
    Str("method", info.FullMethod).     // 4. Obligatorio siempre
    Dur("latency", elapsed).
    Msg("request completado")

// VETADO:
log.Printf("request completado")  // sin campos semánticos
```

### Stack de Observabilidad

| Señal | Herramienta | Destino | Retención |
|-------|------------|---------|-----------|
| **Logs** | zerolog (Go) / tracing::info! (Rust) | Loki vía OTel Collector | 90 días |
| **Trazas** | OTel SDK (Go/Rust) | Tempo vía OTel Collector | 30 días |
| **Métricas** | Prometheus client | Prometheus vía /metrics | 15 días |
| **Dashboards** | Grafana OSS | Prometheus + Loki + Tempo | — |

### Niveles de Log Semánticos

| Nivel | Cuándo usarlo |
|-------|--------------|
| `ERROR` | Error de servidor (código 5xx): bug, panic recuperado, error de BD |
| `WARN` | Violación de permisos, tenant suspendido, degradación elegante |
| `INFO` | Request completado exitosamente, estado de ficha cambiado |
| `DEBUG` | Solo en desarrollo — nunca en producción |

**Formato:** JSON siempre. Nunca texto libre. Los campos son indexables en Loki.

### OTel Collector — Único Agregador

```yaml
# otel-collector.yaml (ficha servers/S06/otel-collector/)
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  attributes:
    actions:
      - key: sbos.ctx_id
        action: upsert  # propagado desde OTel Baggage
      - key: sbos.tenant_id
        action: upsert

exporters:
  loki:  # logs
  tempo: # traces
  prometheus: # metrics
```

El Collector recibe de todos los daemons y exporta a Loki/Tempo/Prometheus. Ningún daemon tiene un sidecar propietario.

### Dashboard Mínimo por Ficha

Cada ficha tiene `resources/dashboard.json` (§16 obligatorio) con:
- Panel `<nombre>_up` (stat) — 0=DOWN, 1=UP
- Panel latencia P50/P95/P99 (timeseries)
- Panel tasa de errores (timeseries)
- Panel requests/segundo (timeseries)

## Consecuencias

**Positivas:**
- `ctx_id` permite reconstruir el recorrido completo de una operación entre servicios
- Grafana puede filtrar por tenant para operaciones de soporte: "muéstrame solo los errores de tenant X"
- Cumple ISO 27001 A.8.15 (Logging) y A.8.16 (Monitoreo de actividades)

**Negativas/Riesgos:**
- El volumen de logs estructurados es mayor que texto libre
- Mitigación: Loki no indexa el contenido, solo las etiquetas (`ctx_id`, `tenant_id`) — el costo de indexación es bajo

## Normas relacionadas

- ADR-033 (RequestContext — los campos semánticos vienen del campo 1)
- ADR-036 (interceptores — el Logging interceptor implementa este ADR)
- §16 Ficha SBOS — dashboard.json obligatorio
- ISO/IEC 27001:2022 A.8.15 + A.8.16
- W3C Trace Context Level 1 (ctx_id en OTel Baggage)
