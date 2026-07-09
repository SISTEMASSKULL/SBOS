# ADR-031 — Tenant ID Siempre Server-Side — Nunca del Cliente

**Estado:** Aceptado  
**Fecha:** 2026-06-13  
**Origen:** §18 Regla 11 del Master v2.1  
**Relacionado:** ADR-024 (PostgreSQL aislamiento), ADR-023 (Keycloak único IdP), §5 Context Plane

---

## Contexto y problema

En sistemas multi-tenant ingenuos, el `tenant_id` viaja en el request del cliente (URL, header, body). Un atacante puede cambiar el valor y acceder a datos de otro tenant. Esta vulnerabilidad, conocida como IDOR (Insecure Direct Object Reference), es una de las más frecuentes en aplicaciones multi-tenant y aparece en OWASP Top 10 (A01:2021 — Broken Access Control).

## La Decisión

**El `tenant_id` se extrae SIEMPRE de los claims del JWT emitido por Keycloak. Nunca del request del cliente (URL, header, body, query parameter).**

```
CORRECTO — tenant_id del JWT (server-side):
  ✅ claims := jwtValidator.ValidateAndExtract(authHeader)
  ✅ tenantID := claims.TenantID   // del token KC
  ✅ ctx = ctx.WithTenantID(tenantID)

VETADO — tenant_id del cliente:
  ❌ tenantID := r.Header.Get("X-Tenant-ID")
  ❌ tenantID := r.URL.Query().Get("tenant")
  ❌ var req struct { TenantID string `json:"tenant_id"` }
  ❌ tenantID := r.PathValue("tenant")  // si el usuario controla la URL
```

## Excepción Documentada: Kong Domain Resolver

Kong extrae el tenant del subdominio DNS (`{tenant}.sbos.app`) y lo inyecta como header `X-SBOS-Tenant` **solo para el login inicial** (antes de que el usuario tenga JWT). Este header es **confiable** porque:
1. Solo Kong lo puede inyectar (nginx no hace routing por subdominio)
2. Kong lo deriva del DNS, no del body del request
3. Es temporal: se usa solo para seleccionar el realm de Keycloak en el que autenticarse

Una vez el usuario tiene JWT, el `tenant_id` viene exclusivamente del claim del token.

## Aplicación en el Context Plane

```go
// En el gRPC interceptor de autenticación (ADR-036):
func authInterceptor(ctx context.Context, req interface{}, ...) {
    token := extractBearerToken(ctx)
    claims, err := jwtValidator.Validate(token)
    // tenant_id SIEMPRE del claim del token
    ctx = context.WithValue(ctx, keyTenantID, claims.TenantID)
    ctx = context.WithValue(ctx, keyCtxID, claims.CtxID)
    return handler(ctx, req)
}
```

## Consecuencias

**Positivas:**
- Elimina clase completa de vulnerabilidades IDOR multi-tenant
- Cumple OWASP A01:2021, ISO 27001 A.8.2 (privileged access)
- El tenant_id en el RequestContext (ADR-033) siempre es de confianza

**Negativas/Riesgos:**
- Todo request requiere JWT válido (sin acceso anónimo a endpoints autenticados)
- Mitigación: los endpoints anónimos solo acceden al dctx_id (no tenant_id) — definido en §5 Context Plane

## Normas relacionadas

- ADR-033 (RequestContext campo 1 en todos los gRPC)
- OWASP A01:2021 (Broken Access Control)
- NIST SP 800-207 Tenet 3 (acceso por sesión, mínimo privilegio)
- §5 Context Plane — dctx_id para visitantes anónimos
