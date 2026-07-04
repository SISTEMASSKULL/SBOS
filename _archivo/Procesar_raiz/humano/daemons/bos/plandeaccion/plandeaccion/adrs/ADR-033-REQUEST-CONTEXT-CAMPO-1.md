# ADR-033 — RequestContext Campo 1 Obligatorio en Todos los Mensajes gRPC

**Estado:** Aceptado  
**Fecha:** 2026-06-13  
**Origen:** §12.2 del Master v2.1  
**Relacionado:** ADR-032 (Protobuf fuente de verdad), ADR-031 (tenant server-side), §5 Context Plane

---

## Contexto y problema

En un sistema distribuido con trazabilidad obligatoria (ISO 27001 A.8.15), cada llamada entre servicios debe llevar el contexto completo: quién hace la llamada, en qué tenant, con qué sesión, con qué bitmask de permisos. Sin esto, los logs de un servicio son islas — no se pueden correlacionar entre sí ni con los eventos de bKernel.

## La Decisión

**El mensaje `RequestContext` es SIEMPRE el campo número 1 en todos los mensajes de request gRPC del ecosistema SBOS. Sin excepción.**

```protobuf
// Definición canónica — compartida por todos los servicios
message RequestContext {
  string ctx_id          = 1;  // Obligatorio siempre
  string tenant_id       = 2;  // Obligatorio siempre
  string correlation_id  = 3;  // Generado por el llamador (UUID v4)
  string user_id         = 4;  // Obligatorio siempre
  string empresa_id      = 5;  // Puede ser vacío (contexto tenant-level)
  string sucursal_id     = 6;  // Puede ser vacío
  string pos_id          = 7;  // Puede ser vacío
  int64  bitmask         = 8;  // BitMask 64-bit del usuario
}

// TODA request gRPC debe tener este patrón:
message MiServicioRequest {
  RequestContext ctx = 1;  // ← SIEMPRE campo 1
  // ... campos del servicio
}
```

## Por qué Campo Número 1

En Protobuf Wire Format, el número de campo determina la posición en el buffer binario. El campo 1 se serializa primero y puede extraerse sin deserializar el mensaje completo. Los interceptores gRPC (ADR-036) pueden leer el `RequestContext` eficientemente sin parsear el payload completo.

## Validación en el Interceptor de Contexto

```go
// En el interceptor de contexto (segundo en la cadena — ADR-036):
func contextInterceptor(ctx context.Context, req interface{}, ...) {
    // Extraer RequestContext del campo 1 via reflection
    rc := extractRequestContext(req)
    if rc.CtxId == "" || rc.TenantId == "" {
        return nil, status.Error(codes.InvalidArgument, "ctx_id y tenant_id son obligatorios")
    }
    // Propagar via OTel Baggage (P5 del Master)
    ctx = baggage.NewContext(ctx, buildBaggage(rc))
    return handler(ctx, req)
}
```

## Consecuencias

**Positivas:**
- Trazabilidad completa en toda llamada inter-servicio
- Los interceptores pueden auditar sin código adicional en cada handler
- OTel Collector propaga `ctx_id` automáticamente a todos los spans
- Cumple ISO 27001 A.8.15 (logging) y A.8.16 (monitoreo)

**Negativas/Riesgos:**
- Requiere disciplina en todos los servicios nuevos
- Mitigación: buf lint tiene una regla custom que verifica `RequestContext ctx = 1` en todos los request messages

## Normas relacionadas

- ADR-032 (Protobuf fuente de verdad — el patrón se define en el .proto)
- ADR-037 (Observabilidad semántica — ctx_id en logs)
- §5 Context Plane — ctx_id inmutable (P3 del Master)
- ISO/IEC 27001:2022 A.8.15 (Logging)
- W3C Trace Context Level 1 (propagación via OTel Baggage)
