# ADR-035 — Arquitectura Hexagonal Obligatoria en Todos los Daemons

**Estado:** Aceptado  
**Fecha:** 2026-06-13  
**Origen:** §11 Backend Services + §17 Estándares de Desarrollo del Master v2.1  
**Relacionado:** ADR-032 (Protobuf), ADR-036 (interceptores gRPC), SBOS_Backend_Development_Standards.md

---

## Contexto y problema

Sin una arquitectura definida, los handlers gRPC y las queries SQL terminan mezclados en el mismo archivo. El negocio queda acoplado al transporte (gRPC) y a la persistencia (PostgreSQL). Esto hace imposible testear la lógica de negocio sin levantar una BD, y hace imposible cambiar el transporte sin reescribir el negocio.

## La Decisión

**Todos los daemons Go y Rust del SBOS implementan arquitectura hexagonal (Ports and Adapters). El dominio nunca depende de la infraestructura.**

```
ESTRUCTURA OBLIGATORIA POR DAEMON:

domain/
  ├── model.go           Entidades, Value Objects, reglas de negocio
  ├── service.go         Use cases (lógica pura, sin I/O)
  └── repository.go      Interfaces (puertos) — solo definición, sin implementación

application/
  ├── command/           CQRS — comandos (escritura)
  └── query/             CQRS — consultas (lectura)

infrastructure/
  ├── postgres/          Implementa repository.go sobre PostgreSQL
  ├── redis/             Cache y pub/sub
  └── grpc/              Adapta llamadas gRPC → domain/service.go

server/
  ├── jsonrpc.go         Handler JSON-RPC 2.0 (ADR-019/020)
  └── grpc.go            Handler gRPC (ADR-032)
```

## Regla de Dependencias — Flujo Unidireccional

```
infrastructure → application → domain
server         → application → domain

domain NO depende de nada
application NO depende de infrastructure
```

```go
// ✅ CORRECTO — domain no conoce PostgreSQL
package domain

type FacturaRepository interface {
    Save(ctx context.Context, f Factura) error
    FindByID(ctx context.Context, id uuid.UUID) (*Factura, error)
}

// ✅ CORRECTO — infrastructure implementa el puerto
package infrastructure/postgres

type facturaRepo struct { db *pgxpool.Pool }

func (r *facturaRepo) Save(ctx context.Context, f domain.Factura) error {
    // SQL aquí — el dominio nunca lo ve
}

// ❌ VETADO — lógica de negocio en el handler gRPC
func (s *server) EmitirFactura(ctx context.Context, req *pb.EmitirFacturaRequest) (*pb.FacturaResponse, error) {
    // No calcular IVA aquí — eso va en domain/service.go
    iva := req.Subtotal * 0.13  // ❌ lógica de negocio en el handler
}
```

## Testing por Capa

| Capa | Tipo de test | Necesita BD | Necesita red |
|------|-------------|-------------|--------------|
| domain | Unit test | ❌ No | ❌ No |
| application | Unit test con mocks | ❌ No | ❌ No |
| infrastructure | Integration test | ✅ Sí | ❌ No |
| server | E2E test | ✅ Sí | ✅ Sí |

Los tests de dominio deben ser los más numerosos y los más rápidos. Un cambio en PostgreSQL no puede romper un test de dominio.

## Consecuencias

**Positivas:**
- Lógica de negocio testeable sin infraestructura
- Transport swap: cambiar de gRPC a JSON-RPC no requiere cambiar el dominio
- BD swap: pasar de PostgreSQL a otra BD requiere solo cambiar `infrastructure/postgres/`
- Clear ownership: cada capa tiene responsabilidad única (SRP)

**Negativas/Riesgos:**
- Más archivos, más estructura inicial
- Mitigación: plantilla de scaffold en `tools/scaffold/` generada por `bosctl daemon scaffold <nombre>`

## Normas relacionadas

- SBOS_Backend_Development_Standards.md §Arquitectura
- ADR-032 (Protobuf — la capa `server/grpc.go` adapta el proto al domain)
- ADR-036 (interceptores — actúan en la capa `server/`, nunca en `domain/`)
- Ports and Adapters pattern (Alistair Cockburn, 2005)
