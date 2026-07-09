# ADR-036 — Cadena de Interceptores gRPC — Orden Canónico

**Estado:** Aceptado  
**Fecha:** 2026-06-13  
**Origen:** §17.3 del Master v2.1  
**Relacionado:** ADR-033 (RequestContext), ADR-035 (arquitectura hexagonal), ADR-037 (observabilidad)

---

## Contexto y problema

Los interceptores gRPC (equivalentes a middleware HTTP) deben ejecutarse en un orden específico. Si el interceptor de autenticación corre antes que el de recovery, un panic antes del auth deja el sistema sin recuperación. Si el interceptor de logging corre antes que el de contexto, los logs no tendrán `ctx_id`.

## La Decisión

**Todos los servidores gRPC del SBOS implementan la cadena de interceptores en este orden exacto:**

```
Recovery → Context → Auth → Logging → Tracing → Metrics
```

```go
// IMPLEMENTACIÓN CANÓNICA — aplicar en todos los servidores gRPC
grpc.NewServer(
    grpc.ChainUnaryInterceptor(
        recoveryInterceptor,   // 1. Recovery PRIMERO — captura panics antes que todo
        contextInterceptor,    // 2. Context — extrae RequestContext, propaga ctx_id
        authInterceptor,       // 3. Auth — valida JWT, verifica BitMask
        loggingInterceptor,    // 4. Logging — tiene ctx_id del paso 2
        tracingInterceptor,    // 5. Tracing — OTel span con ctx_id del paso 2
        metricsInterceptor,    // 6. Metrics — incrementa contadores Prometheus
    ),
    grpc.ChainStreamInterceptor(
        // Mismo orden para streams
        streamRecoveryInterceptor,
        streamContextInterceptor,
        streamAuthInterceptor,
        streamLoggingInterceptor,
        streamTracingInterceptor,
        streamMetricsInterceptor,
    ),
)
```

## Por qué Este Orden

| # | Interceptor | Razón de su posición |
|---|-------------|---------------------|
| 1 | **Recovery** | Si cualquier interceptor posterior hace panic, Recovery lo captura. Debe ser el más externo. |
| 2 | **Context** | Extrae `RequestContext` del campo 1 del mensaje (ADR-033). Todos los interceptores posteriores necesitan `ctx_id`. |
| 3 | **Auth** | Valida JWT y BitMask. Necesita `ctx_id` del paso 2 para el audit log. Rechaza antes de tocar lógica de negocio. |
| 4 | **Logging** | Registra inicio/fin de la llamada con `ctx_id`, `tenant_id`, `method`. Necesita auth completado para saber si fue autorizado. |
| 5 | **Tracing** | Crea OTel span. Necesita `ctx_id` para el baggage. Después del logging para que los spans no incluyan el overhead del log. |
| 6 | **Metrics** | Incrementa contadores Prometheus. Va último: mide el tiempo real de la llamada incluyendo todos los interceptores. |

## Implementación de Recovery

```go
func recoveryInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (resp interface{}, err error) {
    defer func() {
        if r := recover(); r != nil {
            log.Error().Interface("panic", r).Str("method", info.FullMethod).
                Bytes("stack", debug.Stack()).Msg("panic recuperado en handler gRPC")
            err = status.Errorf(codes.Internal, "error interno del servidor")
        }
    }()
    return handler(ctx, req)
}
```

## Consecuencias

**Positivas:**
- Panics nunca crashean el servidor (Recovery primero)
- Todos los logs tienen `ctx_id` y `tenant_id` (Context antes de Logging)
- El auth siempre ocurre antes de la lógica de negocio
- Los spans OTel son precisos (Tracing después de Auth — no mide el tiempo de validación del token como "tiempo de negocio")

**Negativas/Riesgos:**
- El orden incorrecto rompe trazabilidad o seguridad silenciosamente
- Mitigación: template de servidor en `tools/scaffold/` implementa la cadena correcta. Tests verifican el orden.

## Normas relacionadas

- ADR-033 (RequestContext campo 1 — Context interceptor lo extrae)
- ADR-037 (Observabilidad — Logging y Tracing interceptors)
- gRPC-go ChainUnaryInterceptor documentation
- SBOS_Backend_Development_Standards.md §gRPC §Interceptores
