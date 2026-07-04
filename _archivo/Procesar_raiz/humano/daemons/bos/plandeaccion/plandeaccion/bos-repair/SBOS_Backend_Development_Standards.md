# SBOS Backend Development Standards
## Guía Normativa de Desarrollo en Go, Rust y gRPC
### Cómo se construye el servidor que provee JSON-RPC
### SKULL · SBOS · v1.0 · Junio 2026

---

> **Propósito**
>
> Este documento define cómo se programa el backend de SBOS.
> Go y Rust son el sistema. gRPC es el protocolo de comunicación interna.
> JSON-RPC es la interfaz que el servidor expone hacia cualquier cliente externo.
>
> Flutter, React, o cualquier otro cliente es un consumidor secundario
> de ese JSON-RPC. No importa qué cliente exista: el servidor es el mismo.
>
> Este documento responde: **¿cómo se escribe el código que hace que SBOS funcione?**

---

## Parte I — La Arquitectura del Servidor

### 1.1 Cómo Está Construido el Backend

El backend de SBOS tiene dos lenguajes con responsabilidades distintas y complementarias:

```
┌─────────────────────────────────────────────────────────────────────┐
│                           SERVIDOR SBOS                             │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  CAPA DE ENTRADA — Kong API Gateway                          │  │
│  │  Recibe JSON-RPC del exterior                                │  │
│  │  Valida JWT + ctx_id                                         │  │
│  │  Traduce a llamada gRPC hacia el servicio Go correspondiente │  │
│  └────────────────────────────┬─────────────────────────────────┘  │
│                               │ gRPC                                │
│  ┌────────────────────────────▼─────────────────────────────────┐  │
│  │  SERVICIOS GO — Lógica de negocio, APIs, coordinación        │  │
│  │                                                               │  │
│  │  bos      → Control plane, ciclo de vida de tenants          │  │
│  │  bAuth    → Evaluación de identidad y BitMask                 │  │
│  │  bCompass → Rutas de IA, workflows, HITL                     │  │
│  │  bSearch  → Búsqueda federada                                │  │
│  │  bhnexus  → Broker de conectividad física                    │  │
│  │                                                               │  │
│  │  Comunican entre sí: gRPC                                    │  │
│  │  Exponen hacia Kong:  gRPC (Kong traduce a JSON-RPC)         │  │
│  └────────────────────────────┬─────────────────────────────────┘  │
│                               │ WAL (pgoutput, <50μs)               │
│  ┌────────────────────────────▼─────────────────────────────────┐  │
│  │  CAPA DE DATOS — Rust — rendimiento máximo, cero GC          │  │
│  │                                                               │  │
│  │  bKernel  → CDC Parser del WAL, Rule Engine, propagación     │  │
│  │  biedata  → Integración con APIs externas (SIAT, bancos)     │  │
│  │                                                               │  │
│  │  PostgreSQL 17 + Patroni                                     │  │
│  │  Redis 7 (Context Registry, Streams, Cache)                  │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Por Qué Go para los Servicios

Go resuelve exactamente los problemas del backend de SBOS:

- **Goroutines:** concurrencia masiva sin overhead de threads OS. bhnexus maneja 10.000 conexiones WebSocket concurrentes con goroutines, no con threads.
- **Compilación rápida:** ciclos de desarrollo cortos para servicios que evolucionan con el negocio.
- **Binarios estáticos:** sin dependencias de runtime. Una imagen OCI mínima.
- **Ecosistema cloud-native:** librerías maduras para Kubernetes, Prometheus, OpenTelemetry, Vault, Keycloak, gRPC.
- **Legibilidad:** código que otros desarrolladores y agentes IA pueden leer y entender sin ambigüedad.

**Go no es la elección correcta cuando:** se necesita latencia de microsegundos, procesamiento de streams a altísimo volumen, o cero pausas de GC. Para eso existe Rust.

### 1.3 Por Qué Rust en el Kernel de Datos

Rust resuelve lo que Go no puede en el nivel del kernel de datos:

- **Sin GC:** el WAL de PostgreSQL emite eventos que deben procesarse en `<50μs`. Un GC pause en ese punto rompe la garantía de consistencia. Rust tiene latencia predecible porque no hay GC.
- **Seguridad de memoria garantizada en compilación:** bKernel maneja datos de múltiples tenants simultáneamente. Un buffer overflow o race condition en ese nivel es un fallo de aislamiento de datos de clientes. El compilador de Rust impide estos errores.
- **Zero-cost abstractions:** código idiomático de alto nivel que produce binarios tan eficientes como C.
- **`unsafe` controlado:** los únicos bloques `unsafe` son aquellos necesarios para FFI o acceso directo a hardware, siempre documentados y revisados.

### 1.4 El Papel de JSON-RPC

JSON-RPC no es un protocolo del backend — es la **interfaz pública del servidor**. El backend está construido en gRPC. Kong es el que recibe JSON-RPC del exterior y lo transforma en gRPC hacia el servicio Go correspondiente.

```
Cliente externo (cualquiera)
        │
        │  POST /api/v1/rpc
        │  Content-Type: application/json
        │  {"jsonrpc":"2.0","method":"pos.venta.CerrarVenta","params":{...}}
        ▼
   Kong API Gateway
        │  Plugin Lua: parsea método JSON-RPC → determina servicio gRPC destino
        │  Valida JWT + ctx_id
        │  Construye request gRPC con metadata SBOS
        ▼
   Go Service (gRPC server)
        │  Procesa en Go
        │  Retorna respuesta gRPC
        ▼
   Kong: convierte respuesta gRPC → JSON-RPC response
        │
        ▼
   Cliente externo recibe JSON-RPC response
```

**El desarrollador Go no sabe ni le importa que el cliente es Flutter, React, Postman o un script Python.** El servicio Go habla gRPC. Punto.

---

## Parte II — Contratos gRPC: La Fuente de Verdad

### 2.1 El Archivo `.proto` Es el Contrato

El `.proto` es el único artefacto que define qué hace un servicio, qué acepta y qué retorna. No el código Go. No la documentación. El `.proto`.

Antes de escribir una sola línea de Go o Rust, se escribe el `.proto`.

### 2.2 Estructura de Directorios Proto

```
proto/
└── sbos/
    ├── common/
    │   └── v1/
    │       ├── context.proto      ← RequestContext — importado por TODOS
    │       ├── money.proto        ← Tipo Money (centavos + moneda ISO 4217)
    │       ├── pagination.proto   ← Cursor-based pagination estándar
    │       └── error.proto        ← ErrorDetail para metadata de errores
    ├── pos/
    │   └── v1/
    │       ├── venta.proto
    │       ├── sesion.proto
    │       └── pago.proto
    ├── facturacion/
    │   └── v1/
    │       ├── sfe.proto
    │       └── contingencia.proto
    ├── inventario/
    │   └── v1/
    │       ├── stock.proto
    │       └── producto.proto
    └── reportes/
        └── v1/
            └── reportes.proto

gen/                    ← NUNCA editar. Generado por protoc + buf.
├── go/
│   └── sbos/
│       ├── common/v1/
│       ├── pos/v1/
│       └── ...
└── rust/               ← Generado por tonic-build (en build.rs de cada crate)
    └── sbos.pos.v1.rs
```

### 2.3 El `RequestContext` — Primer Campo en Todo Mensaje

Este mensaje viaja en **todos** los requests gRPC internos de SBOS. Siempre es el campo número 1. No es opcional.

```protobuf
// proto/sbos/common/v1/context.proto
syntax = "proto3";
package sbos.common.v1;

option go_package = "github.com/skull/sbos/gen/go/common/v1;commonv1";

message RequestContext {
  string ctx_id          = 1;  // Obligatorio siempre
  string tenant_id       = 2;  // Obligatorio siempre
  string correlation_id  = 3;  // UUID del request original (JSON-RPC id)
  string user_id         = 4;  // Obligatorio siempre
  string empresa_id      = 5;
  string sucursal_id     = 6;
  string pos_id          = 7;
  string bitmask         = 8;  // Hex string "0x00000000008C87FF"
}
```

### 2.4 Contrato Completo: Servicio de Ventas POS

Este es un ejemplo real de cómo se escribe un contrato de servicio en SBOS. Sirve de plantilla para cualquier servicio nuevo.

```protobuf
// proto/sbos/pos/v1/venta.proto
syntax = "proto3";
package sbos.pos.v1;

option go_package = "github.com/skull/sbos/gen/go/pos/v1;posv1";

import "google/protobuf/timestamp.proto";
import "sbos/common/v1/context.proto";
import "sbos/common/v1/money.proto";

// ─────────────────────────────────────────────────────────────────────────
// IniciarVenta
// ─────────────────────────────────────────────────────────────────────────

message IniciarVentaRequest {
  sbos.common.v1.RequestContext ctx = 1;  // SIEMPRE campo 1
  string pos_id = 3;                      // Campos de negocio desde 3
}

message IniciarVentaResponse {
  string                     venta_id   = 1;
  string                     estado     = 2;
  google.protobuf.Timestamp  abierta_en = 3;
}

// ─────────────────────────────────────────────────────────────────────────
// RegistrarItem
// ─────────────────────────────────────────────────────────────────────────

message RegistrarItemRequest {
  sbos.common.v1.RequestContext ctx = 1;
  string                        venta_id              = 3;
  string                        producto_id           = 4;
  int32                         cantidad              = 5;
  // Siempre centavos — nunca float
  int64                         precio_unit_centavos  = 6;
  // Campos opcionales después del 10
  optional string               descuento_codigo      = 11;
}

message RegistrarItemResponse {
  string item_id                 = 1;
  int64  subtotal_centavos       = 2;
  int64  total_venta_centavos    = 3;
  string estado_venta            = 4;
}

// ─────────────────────────────────────────────────────────────────────────
// CerrarVenta
// ─────────────────────────────────────────────────────────────────────────

message CerrarVentaRequest {
  sbos.common.v1.RequestContext ctx = 1;
  string                        venta_id              = 3;
  string                        metodo_pago           = 4;
  int64                         monto_pagado_centavos = 5;
}

message CerrarVentaResponse {
  string                    venta_id       = 1;
  string                    numero_ticket  = 2;
  int64                     cambio_centavos = 3;
  google.protobuf.Timestamp cerrada_en     = 4;
}

// ─────────────────────────────────────────────────────────────────────────
// SeguirEstadoEmision — server streaming para operaciones asíncronas
// ─────────────────────────────────────────────────────────────────────────

message SeguirEstadoEmisionRequest {
  sbos.common.v1.RequestContext ctx = 1;
  string                        factura_id = 3;
}

message EstadoEmisionEvento {
  string                    factura_id          = 1;
  string                    estado              = 2;
  // "pendiente_siat" | "emitida" | "rechazada" | "contingencia"
  optional string           codigo_autorizacion = 3;
  optional string           mensaje_error       = 4;
  google.protobuf.Timestamp ts                  = 5;
}

// ─────────────────────────────────────────────────────────────────────────
// Servicio
// ─────────────────────────────────────────────────────────────────────────

service VentaService {
  // Llamadas unarias (request → response)
  rpc IniciarVenta    (IniciarVentaRequest)    returns (IniciarVentaResponse);
  rpc RegistrarItem   (RegistrarItemRequest)   returns (RegistrarItemResponse);
  rpc RemoverItem     (RemoverItemRequest)     returns (RemoverItemResponse);
  rpc CerrarVenta     (CerrarVentaRequest)     returns (CerrarVentaResponse);

  // Server streaming: el servidor envía múltiples eventos
  // Usar para: operaciones largas cuyo resultado llega de forma asíncrona
  rpc SeguirEstadoEmision (SeguirEstadoEmisionRequest)
      returns (stream EstadoEmisionEvento);
}
```

### 2.5 Tipo Money — Nunca Float

```protobuf
// proto/sbos/common/v1/money.proto
syntax = "proto3";
package sbos.common.v1;

// Representa un valor monetario.
// amount_centavos: el monto en la unidad mínima de la moneda (centavos).
// currency: código ISO 4217 ("BOB", "USD", "PEN", etc.)
//
// Ejemplo: BOB 45.50 → { amount_centavos: 4550, currency: "BOB" }
//
// NUNCA usar float o double para dinero.
// Los errores de punto flotante en facturación son errores fiscales.
message Money {
  int64  amount_centavos = 1;
  string currency        = 2;
}
```

### 2.6 Reglas de Compatibilidad del Contrato Protobuf

El contrato `.proto` es sagrado. Cambiarlo mal silencia servicios en producción sin error de compilación.

#### Números de campo: la regla más importante

En Protobuf, **el número de campo identifica el dato en el wire**, no el nombre. Si cambias el número de un campo existente, el receptor deserializa datos incorrectos silenciosamente.

```protobuf
// ✅ CORRECTO — agregar campo con número nuevo
message RegistrarItemRequest {
  sbos.common.v1.RequestContext ctx = 1;
  string venta_id                   = 3;
  string producto_id                = 4;
  int32  cantidad                   = 5;
  int64  precio_unit_centavos       = 6;
  // Nuevo campo en número no usado
  optional string lote_id           = 12;  // ← seguro
}

// ❌ BREAKING — cambiar número de campo existente
message RegistrarItemRequest {
  sbos.common.v1.RequestContext ctx = 1;
  string venta_id                   = 3;
  int64  precio_unit_centavos       = 4;  // ← ERA producto_id=4, ahora precio=4: CORRUPCIÓN
}

// ❌ BREAKING — cambiar tipo de campo
message RegistrarItemRequest {
  sbos.common.v1.RequestContext ctx = 1;
  string venta_id                   = 3;
  string producto_id                = 4;
  int64  cantidad                   = 5;  // ← ERA int32, ahora int64: BREAKING en algunos casos
}

// ✅ CORRECTO — eliminar campo reservando el número
message RegistrarItemRequest {
  sbos.common.v1.RequestContext ctx = 1;
  string venta_id                   = 3;
  string producto_id                = 4;
  int32  cantidad                   = 5;
  int64  precio_unit_centavos       = 6;
  reserved 11;             // Número reservado para siempre
  reserved "descuento_codigo"; // Nombre reservado para siempre
}
```

#### Tabla de cambios — referencia rápida

| Operación | ¿Breaking en wire? | ¿Breaking en código generado? | Acción |
|---|---|---|---|
| Agregar campo opcional | **No** | No | Seguro |
| Agregar método RPC | **No** | No | Seguro |
| Renombrar campo (misma numeración) | **No** | **Sí** | Actualizar código, no nueva versión |
| Eliminar campo + `reserved` | **No** | **Sí** | Actualizar código, no nueva versión |
| Eliminar campo **sin** `reserved` | No ahora, **sí después** | **Sí** | VETADO — siempre usar reserved |
| Cambiar tipo de campo | **Sí** | **Sí** | Requiere versión nueva del package |
| Cambiar número de campo | **Sí** | **Sí** | Requiere versión nueva del package |
| Eliminar método RPC | **Sí** | **Sí** | Requiere versión nueva del package |
| Cambiar `package` | **Sí** | **Sí** | Requiere versión nueva del package |

#### Cuándo crear v2 del package

```
proto/sbos/pos/v1/venta.proto   ← permanece activo (mínimo 60 días tras publicar v2)
proto/sbos/pos/v2/venta.proto   ← nueva versión con cambios breaking
```

En el `buf.yaml` del repositorio, el CI verifica automáticamente que no haya cambios breaking sin bumping de versión:

```yaml
# buf.yaml
version: v2
breaking:
  use:
    - FILE       # Protege clientes binarios gRPC
    - WIRE_JSON  # Protege clientes JSON (Kong gRPC-JSON transcoding)
```

### 2.7 Generación de Código

El código en `gen/` se genera automáticamente en el CI. El desarrollador nunca lo edita.

```bash
# Herramienta: buf (https://buf.build) — estándar actual del ecosistema gRPC

# Lint del proto (verifica convenciones de nomenclatura, campos obligatorios, etc.)
buf lint

# Verificar que no hay cambios breaking respecto a la versión anterior
buf breaking --against .git#branch=main

# Generar código Go y Rust
buf generate
```

```yaml
# buf.gen.yaml
version: v2
plugins:
  - plugin: go
    out: gen/go
    opt: paths=source_relative

  - plugin: go-grpc
    out: gen/go
    opt:
      - paths=source_relative
      - require_unimplemented_servers=true

  # Para Rust se usa tonic-build directamente en build.rs de cada crate
```

---

## Parte III — Implementación gRPC en Go

### 3.1 Estructura de un Servicio Go

Cada servicio Go sigue la misma estructura de capas. No existe una estructura inventada por servicio.

```
src/internal/{servicio}/
│
├── domain/                     ← El núcleo. No importa nada externo.
│   ├── model.go                  Entidades, Value Objects, reglas de negocio
│   ├── repository.go             Interfaces (contratos que la infra implementa)
│   ├── service.go                Domain services (lógica entre agregados)
│   └── errors.go                 Tipos de error de dominio
│
├── application/                ← Orquesta el dominio. Conoce repositorios.
│   ├── commands/
│   │   └── {nombre}_handler.go   Un archivo por command handler
│   └── queries/
│       └── {nombre}_handler.go   Un archivo por query handler
│
├── infrastructure/             ← Implementaciones concretas. No es importada por domain.
│   ├── postgres/
│   │   ├── {entidad}_repo.go     Implementa domain.{Entidad}Repository
│   │   └── queries/
│   │       └── {nombre}.sql      SQL de solo lectura (read models)
│   ├── grpc/
│   │   └── {servicio}_client.go  Cliente gRPC hacia otros servicios
│   └── redis/
│       └── cache.go
│
└── api/
    └── grpc/
        ├── server.go             Configuración del servidor gRPC (interceptors, etc.)
        ├── handler.go            Implementa la interfaz generada por protoc
        └── mapper.go             Convierte entre tipos proto y tipos de dominio
```

**Regla de dependencias — el flujo va en una sola dirección:**

```
api/grpc → application → domain
infrastructure → domain  (implementa las interfaces, no al revés)

domain no importa nada de las otras capas.
application no importa infrastructure.
La inversión de dependencias es por interfaces en domain.
```

### 3.2 El `main.go` de un Servicio Go

El `main.go` es mínimo. Solo conecta piezas. La lógica nunca vive aquí.

```go
// src/cmd/pos-service/main.go

package main

import (
    "context"
    "log/slog"
    "net"
    "os"
    "os/signal"
    "syscall"

    "google.golang.org/grpc"
    posv1 "github.com/skull/sbos/gen/go/pos/v1"
    "github.com/skull/sbos/internal/pos/api/grpc/handler"
    "github.com/skull/sbos/internal/pos/infrastructure/postgres"
    "github.com/skull/sbos/internal/pos/application/commands"
    "github.com/skull/sbos/pkg/vault"
    "github.com/skull/sbos/pkg/otel"
    mw "github.com/skull/sbos/pkg/grpcmiddleware"
)

func main() {
    ctx, cancel := signal.NotifyContext(context.Background(),
        syscall.SIGINT, syscall.SIGTERM)
    defer cancel()

    // 1. Configuración desde Vault (nunca de env vars para secretos)
    cfg := vault.MustLoadConfig("secret/tenants/{realm}/pos-service/db")

    // 2. Inicializar OpenTelemetry
    shutdown := otel.MustInit(ctx, "pos-service")
    defer shutdown()

    // 3. Construir dependencias (dependency injection manual, sin frameworks)
    db := postgres.MustConnect(cfg.DatabaseURL)
    ventaRepo := postgres.NewVentaRepository(db)

    registrarItemHandler := commands.NewRegistrarItemHandler(ventaRepo)
    cerrarVentaHandler   := commands.NewCerrarVentaHandler(ventaRepo)

    h := handler.NewVentaHandler(registrarItemHandler, cerrarVentaHandler)

    // 4. Servidor gRPC con interceptors obligatorios
    srv := grpc.NewServer(
        grpc.ChainUnaryInterceptor(
            mw.RecoveryInterceptor,   // convierte panics en Internal error
            mw.ContextInterceptor,    // extrae SBOSContext del metadata
            mw.AuthInterceptor,       // verifica que ctx_id y tenant_id están presentes
            mw.LoggingInterceptor,    // log estructurado de cada request
            mw.TracingInterceptor,    // span OTel por cada llamada
            mw.MetricsInterceptor,    // Prometheus: duración, códigos de error
        ),
        grpc.ChainStreamInterceptor(
            mw.StreamContextInterceptor,
            mw.StreamLoggingInterceptor,
        ),
    )
    posv1.RegisterVentaServiceServer(srv, h)

    // 5. Escuchar
    lis, err := net.Listen("tcp", ":50051")
    if err != nil {
        slog.Error("no se pudo escuchar", "error", err)
        os.Exit(1)
    }

    slog.Info("pos-service iniciando", "addr", ":50051")

    go func() {
        if err := srv.Serve(lis); err != nil {
            slog.Error("server error", "error", err)
        }
    }()

    <-ctx.Done()
    slog.Info("pos-service deteniendo")
    srv.GracefulStop()
}
```

### 3.3 Los Interceptors (Middleware gRPC) — El Código más Importante

Los interceptors son el código más crítico del servidor gRPC. Se ejecutan en cada llamada antes de que llegue al handler. Son la única forma de garantizar que el contexto SBOS, el logging, la trazabilidad y la autenticación son universales — no dependen de que el desarrollador "recuerde" hacerlo en cada handler.

```go
// pkg/grpcmiddleware/context.go

package grpcmiddleware

import (
    "context"
    "google.golang.org/grpc"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/metadata"
    "google.golang.org/grpc/status"
    "github.com/skull/sbos/pkg/sbosctx"
)

// ContextInterceptor extrae el contexto SBOS del metadata gRPC entrante
// y lo pone en el context.Context de Go para que los handlers lo usen.
//
// Kong inyecta estos valores en el metadata antes de llamar al servicio.
// Cuando un servicio Go llama a otro servicio Go, los propaga manualmente.
func ContextInterceptor(
    ctx context.Context,
    req any,
    info *grpc.UnaryServerInfo,
    handler grpc.UnaryHandler,
) (any, error) {

    md, ok := metadata.FromIncomingContext(ctx)
    if !ok {
        return nil, status.Error(codes.Unauthenticated, "metadata gRPC requerida")
    }

    sbosCtx := sbosctx.SBOSContext{
        CtxID:         first(md, "x-sbos-ctx-id"),
        TenantID:      first(md, "x-sbos-tenant"),
        UserID:        first(md, "x-sbos-user"),
        EmpresaID:     first(md, "x-sbos-empresa"),
        SucursalID:    first(md, "x-sbos-sucursal"),
        PosID:         first(md, "x-sbos-pos"),
        BitMask:       first(md, "x-sbos-bitmask"),
        CorrelationID: first(md, "x-sbos-correlation"),
    }

    if sbosCtx.CtxID == "" || sbosCtx.TenantID == "" {
        return nil, status.Error(codes.Unauthenticated,
            "x-sbos-ctx-id y x-sbos-tenant son obligatorios")
    }

    enrichedCtx := sbosctx.WithContext(ctx, sbosCtx)
    return handler(enrichedCtx, req)
}

func first(md metadata.MD, key string) string {
    vals := md.Get(key)
    if len(vals) == 0 {
        return ""
    }
    return vals[0]
}
```

```go
// pkg/grpcmiddleware/logging.go

package grpcmiddleware

import (
    "context"
    "log/slog"
    "time"

    "google.golang.org/grpc"
    "google.golang.org/grpc/status"
    "github.com/skull/sbos/pkg/sbosctx"
)

// LoggingInterceptor emite un log estructurado por cada llamada gRPC.
// El formato es siempre el mismo: inicio + resultado + duración.
// El ctx_id y tenant_id siempre están presentes en el log.
func LoggingInterceptor(
    ctx context.Context,
    req any,
    info *grpc.UnaryServerInfo,
    handler grpc.UnaryHandler,
) (any, error) {

    start := time.Now()
    sbosCtx := sbosctx.FromContext(ctx)

    slog.DebugContext(ctx, "grpc.request",
        "method",         info.FullMethod,
        "ctx_id",         sbosCtx.CtxID,
        "tenant_id",      sbosCtx.TenantID,
        "correlation_id", sbosCtx.CorrelationID,
    )

    resp, err := handler(ctx, req)

    code := codes.OK
    if err != nil {
        code = status.Code(err)
    }
    duration := time.Since(start)

    level := slog.LevelInfo
    if code != codes.OK {
        level = slog.LevelWarn
        if isServerError(code) {
            level = slog.LevelError
        }
    }

    slog.Log(ctx, level, "grpc.response",
        "method",         info.FullMethod,
        "ctx_id",         sbosCtx.CtxID,
        "tenant_id",      sbosCtx.TenantID,
        "correlation_id", sbosCtx.CorrelationID,
        "grpc_code",      code.String(),
        "duration_ms",    duration.Milliseconds(),
    )

    return resp, err
}

func isServerError(c codes.Code) bool {
    return c == codes.Internal || c == codes.Unavailable || c == codes.DataLoss
}
```

```go
// pkg/grpcmiddleware/recovery.go

package grpcmiddleware

import (
    "context"
    "log/slog"
    "runtime/debug"

    "google.golang.org/grpc"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
)

// RecoveryInterceptor captura panics y los convierte en errores gRPC Internal.
// Sin este interceptor, un panic en un handler tumba el servidor completo.
// DEBE ser el primero en la cadena de interceptors.
func RecoveryInterceptor(
    ctx context.Context,
    req any,
    info *grpc.UnaryServerInfo,
    handler grpc.UnaryHandler,
) (resp any, err error) {

    defer func() {
        if r := recover(); r != nil {
            slog.ErrorContext(ctx, "panic recuperado en handler gRPC",
                "method", info.FullMethod,
                "panic",  r,
                "stack",  string(debug.Stack()),
            )
            err = status.Errorf(codes.Internal,
                "error interno inesperado en %s", info.FullMethod)
        }
    }()

    return handler(ctx, req)
}
```

### 3.4 El Handler gRPC Completo

```go
// internal/pos/api/grpc/handler.go

package grpchandler

import (
    "context"
    "errors"
    "log/slog"

    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
    "google.golang.org/protobuf/types/known/timestamppb"

    posv1 "github.com/skull/sbos/gen/go/pos/v1"
    "github.com/skull/sbos/internal/pos/application/commands"
    "github.com/skull/sbos/internal/pos/application/queries"
    "github.com/skull/sbos/internal/pos/domain"
    "github.com/skull/sbos/pkg/bitmask"
    "github.com/skull/sbos/pkg/sbosctx"
)

// VentaHandler implementa posv1.VentaServiceServer.
// Embebe UnimplementedVentaServiceServer para compatibilidad futura:
// si se agrega un método al .proto sin implementarlo aquí,
// el compilador de Go no falla pero el servidor retorna UNIMPLEMENTED.
type VentaHandler struct {
    posv1.UnimplementedVentaServiceServer

    iniciarVentaCmd  *commands.IniciarVentaHandler
    registrarItemCmd *commands.RegistrarItemHandler
    cerrarVentaCmd   *commands.CerrarVentaHandler
    consultarVentaQry *queries.ConsultarVentaHandler
}

func NewVentaHandler(
    iniciar  *commands.IniciarVentaHandler,
    registrar *commands.RegistrarItemHandler,
    cerrar   *commands.CerrarVentaHandler,
    consultar *queries.ConsultarVentaHandler,
) *VentaHandler {
    return &VentaHandler{
        iniciarVentaCmd:   iniciar,
        registrarItemCmd:  registrar,
        cerrarVentaCmd:    cerrar,
        consultarVentaQry: consultar,
    }
}

func (h *VentaHandler) RegistrarItem(
    ctx context.Context,
    req *posv1.RegistrarItemRequest,
) (*posv1.RegistrarItemResponse, error) {

    sbosCtx := sbosctx.FromContext(ctx)

    // Verificar BitMask antes de cualquier operación
    bm, err := bitmask.Parse(sbosCtx.BitMask)
    if err != nil {
        return nil, status.Errorf(codes.Unauthenticated, "bitmask inválido")
    }
    if !bm.Has(bitmask.BitVentas) {
        slog.WarnContext(ctx, "acceso denegado por bitmask",
            "ctx_id",    sbosCtx.CtxID,
            "operacion", "registrar_item",
            "bitmask",   sbosCtx.BitMask,
        )
        return nil, status.Errorf(codes.PermissionDenied,
            "el usuario no tiene permiso para registrar ventas")
    }

    result, err := h.registrarItemCmd.Handle(ctx, commands.RegistrarItemCmd{
        TenantID:           sbosCtx.TenantID,
        CtxID:              sbosCtx.CtxID,
        VentaID:            req.VentaId,
        ProductoID:         req.ProductoId,
        Cantidad:           int(req.Cantidad),
        PrecioUnitCentavos: req.PrecioUnitCentavos,
        DescuentoCodigo:    req.DescuentoCodigo,
    })
    if err != nil {
        return nil, ventaGRPCError(err, sbosCtx.CtxID)
    }

    return &posv1.RegistrarItemResponse{
        ItemId:             result.ItemID,
        SubtotalCentavos:   result.SubtotalCentavos,
        TotalVentaCentavos: result.TotalVentaCentavos,
        EstadoVenta:        result.EstadoVenta,
    }, nil
}

func (h *VentaHandler) CerrarVenta(
    ctx context.Context,
    req *posv1.CerrarVentaRequest,
) (*posv1.CerrarVentaResponse, error) {

    sbosCtx := sbosctx.FromContext(ctx)

    bm, _ := bitmask.Parse(sbosCtx.BitMask)
    if !bm.Has(bitmask.BitVentas) {
        return nil, status.Errorf(codes.PermissionDenied,
            "el usuario no tiene permiso para cerrar ventas")
    }

    result, err := h.cerrarVentaCmd.Handle(ctx, commands.CerrarVentaCmd{
        TenantID:            sbosCtx.TenantID,
        CtxID:               sbosCtx.CtxID,
        VentaID:             req.VentaId,
        MetodoPago:          req.MetodoPago,
        MontoPagadoCentavos: req.MontoPagadoCentavos,
    })
    if err != nil {
        return nil, ventaGRPCError(err, sbosCtx.CtxID)
    }

    return &posv1.CerrarVentaResponse{
        VentaId:        result.VentaID,
        NumeroTicket:   result.NumeroTicket,
        CambioCentavos: result.CambioCentavos,
        CerradaEn:      timestamppb.New(result.CerradaEn),
    }, nil
}

// ventaGRPCError convierte errores de dominio en status gRPC.
func ventaGRPCError(err error, ctxID string) error {
    var ve *domain.VentaError
    if errors.As(err, &ve) {
        switch ve.Code {
        case domain.ErrVentaNoEncontrada:
            return status.Errorf(codes.NotFound,
                "venta no encontrada [ctx=%s]", ctxID)
        case domain.ErrStockInsuficiente:
            return status.Errorf(codes.FailedPrecondition,
                "stock insuficiente: disponible=%d solicitado=%d [ctx=%s]",
                ve.Disponible, ve.Solicitado, ctxID)
        case domain.ErrVentaYaCerrada:
            return status.Errorf(codes.FailedPrecondition,
                "la venta ya está cerrada [ctx=%s]", ctxID)
        case domain.ErrPagoInsuficiente:
            return status.Errorf(codes.FailedPrecondition,
                "pago insuficiente: falta=%d [ctx=%s]", ve.Faltante, ctxID)
        }
    }
    return status.Errorf(codes.Internal, "error interno [ctx=%s]", ctxID)
}
```

### 3.5 El Command Handler — La Lógica de Negocio

```go
// internal/pos/application/commands/registrar_item.go

package commands

import (
    "context"
    "fmt"

    "github.com/skull/sbos/internal/pos/domain"
)

type RegistrarItemCmd struct {
    TenantID           string
    CtxID              string
    VentaID            string
    ProductoID         string
    Cantidad           int
    PrecioUnitCentavos int64
    DescuentoCodigo    *string
}

type RegistrarItemResult struct {
    ItemID             string
    SubtotalCentavos   int64
    TotalVentaCentavos int64
    EstadoVenta        string
}

// RegistrarItemHandler depende de interfaces, nunca de implementaciones concretas.
type RegistrarItemHandler struct {
    ventaRepo   domain.VentaRepository
    stockSvc    domain.StockChecker
}

func NewRegistrarItemHandler(
    repo domain.VentaRepository,
    stock domain.StockChecker,
) *RegistrarItemHandler {
    return &RegistrarItemHandler{
        ventaRepo: repo,
        stockSvc:  stock,
    }
}

func (h *RegistrarItemHandler) Handle(
    ctx context.Context,
    cmd RegistrarItemCmd,
) (*RegistrarItemResult, error) {

    // 1. Verificar stock
    disponible, err := h.stockSvc.Disponible(ctx, cmd.TenantID, cmd.ProductoID)
    if err != nil {
        return nil, fmt.Errorf("registrar_item.verificar_stock [tenant=%s producto=%s]: %w",
            cmd.TenantID, cmd.ProductoID, err)
    }
    if disponible < cmd.Cantidad {
        return nil, &domain.VentaError{
            Code:       domain.ErrStockInsuficiente,
            Disponible: disponible,
            Solicitado: cmd.Cantidad,
        }
    }

    // 2. Cargar el agregado
    venta, err := h.ventaRepo.GetByID(ctx, cmd.TenantID, cmd.VentaID)
    if err != nil {
        return nil, fmt.Errorf("registrar_item.cargar_venta [venta=%s]: %w",
            cmd.VentaID, err)
    }

    // 3. Ejecutar lógica de dominio
    item, err := venta.AgregarItem(domain.ItemParams{
        ProductoID:         cmd.ProductoID,
        Cantidad:           cmd.Cantidad,
        PrecioUnitCentavos: cmd.PrecioUnitCentavos,
        DescuentoCodigo:    cmd.DescuentoCodigo,
    })
    if err != nil {
        return nil, err
    }

    // 4. Persistir
    if err := h.ventaRepo.Save(ctx, venta); err != nil {
        return nil, fmt.Errorf("registrar_item.save [venta=%s ctx=%s]: %w",
            cmd.VentaID, cmd.CtxID, err)
    }

    return &RegistrarItemResult{
        ItemID:             item.ID,
        SubtotalCentavos:   item.SubtotalCentavos,
        TotalVentaCentavos: venta.TotalCentavos(),
        EstadoVenta:        string(venta.Estado),
    }, nil
}
```

### 3.6 El Repository — Datos con ctx_id

```go
// internal/pos/infrastructure/postgres/venta_repo.go

package postgres

import (
    "context"
    "database/sql"
    "errors"
    "fmt"

    "github.com/skull/sbos/internal/pos/domain"
    "github.com/skull/sbos/pkg/sbosctx"
)

type VentaRepository struct {
    db *sql.DB
}

func (r *VentaRepository) GetByID(
    ctx context.Context,
    tenantID string,
    ventaID string,
) (*domain.Venta, error) {

    sbosCtx := sbosctx.FromContext(ctx)

    // tenant_id siempre en el WHERE — nunca una query sin aislamiento de tenant
    row := r.db.QueryRowContext(ctx, `
        SELECT id, tenant_id, pos_id, user_id, estado, total_centavos, ctx_id
        FROM pos_ventas
        WHERE id = $1 AND tenant_id = $2
    `, ventaID, tenantID)

    var v domain.Venta
    if err := row.Scan(
        &v.ID, &v.TenantID, &v.PosID, &v.UserID,
        &v.Estado, &v.TotalCentavos_, &v.LastCtxID,
    ); err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, &domain.VentaError{Code: domain.ErrVentaNoEncontrada}
        }
        return nil, fmt.Errorf("venta_repo.get_by_id [tenant=%s venta=%s ctx=%s]: %w",
            tenantID, ventaID, sbosCtx.CtxID, err)
    }
    return &v, nil
}

func (r *VentaRepository) Save(
    ctx context.Context,
    venta *domain.Venta,
) error {

    sbosCtx := sbosctx.FromContext(ctx)

    tx, err := r.db.BeginTx(ctx, nil)
    if err != nil {
        return fmt.Errorf("venta_repo.save.begin_tx: %w", err)
    }
    defer tx.Rollback()

    _, err = tx.ExecContext(ctx, `
        INSERT INTO pos_ventas
            (id, tenant_id, pos_id, user_id, estado, total_centavos, ctx_id)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        ON CONFLICT (id) DO UPDATE SET
            estado         = EXCLUDED.estado,
            total_centavos = EXCLUDED.total_centavos,
            ctx_id         = EXCLUDED.ctx_id,
            updated_at     = NOW()
        WHERE pos_ventas.tenant_id = EXCLUDED.tenant_id
    `,
        venta.ID,
        venta.TenantID,
        venta.PosID,
        venta.UserID,
        string(venta.Estado),
        venta.TotalCentavos(),
        sbosCtx.CtxID,
    )
    if err != nil {
        return fmt.Errorf("venta_repo.save.upsert [venta=%s ctx=%s]: %w",
            venta.ID, sbosCtx.CtxID, err)
    }

    return tx.Commit()
}
```

### 3.7 Propagación del Contexto al Llamar a Otro Servicio

```go
// pkg/grpcmiddleware/outgoing.go

package grpcmiddleware

import (
    "context"

    "google.golang.org/grpc/metadata"
    "github.com/skull/sbos/pkg/sbosctx"
)

// OutgoingContext construye el context con metadata SBOS para llamadas gRPC salientes.
// Usar en todo cliente gRPC antes de llamar a otro servicio.
func OutgoingContext(ctx context.Context) context.Context {
    sbosCtx := sbosctx.FromContext(ctx)
    md := metadata.Pairs(
        "x-sbos-ctx-id",       sbosCtx.CtxID,
        "x-sbos-tenant",       sbosCtx.TenantID,
        "x-sbos-user",         sbosCtx.UserID,
        "x-sbos-empresa",      sbosCtx.EmpresaID,
        "x-sbos-sucursal",     sbosCtx.SucursalID,
        "x-sbos-pos",          sbosCtx.PosID,
        "x-sbos-bitmask",      sbosCtx.BitMask,
        "x-sbos-correlation",  sbosCtx.CorrelationID,
    )
    return metadata.NewOutgoingContext(ctx, md)
}

// Uso en infrastructure client:
//
// outCtx := grpcmiddleware.OutgoingContext(ctx)
// resp, err := c.client.ConsultarDisponibilidad(outCtx, req)
```

---

## Parte IV — Implementación en Rust (bKernel y biedata)

### 4.1 Workspace Cargo — La Raíz

```toml
# crates/Cargo.toml  (workspace root)

[workspace]
resolver = "2"
members  = [
    "bkernel",
    "biedata",
    "wal-parser",
    "rule-engine",
    "shared-types",
    "audit",
]

[workspace.dependencies]
tokio       = { version = "1", features = ["full"] }
tonic       = "0.12"
sqlx        = { version = "0.8", features = ["postgres", "runtime-tokio", "uuid", "time"] }
serde       = { version = "1", features = ["derive"] }
serde_json  = "1"
tracing             = "0.1"
tracing-subscriber  = { version = "0.3", features = ["json", "env-filter"] }
opentelemetry       = "0.23"
thiserror   = "2"
anyhow      = "1"
uuid        = { version = "1", features = ["v4", "serde"] }
time        = { version = "0.3", features = ["serde"] }

[workspace.lints.rust]
unsafe_code = "forbid"

[workspace.lints.clippy]
all      = "warn"
pedantic = "warn"
```

### 4.2 Estructura de bKernel (Rust)

```
crates/bkernel/
├── Cargo.toml
├── build.rs                  ← tonic-build: genera código gRPC desde .proto
└── src/
    ├── main.rs
    ├── lib.rs
    │
    ├── wal/
    │   ├── mod.rs
    │   ├── slot.rs           ← Gestión del slot de replicación lógica PostgreSQL
    │   ├── parser.rs         ← Parseo de mensajes pgoutput
    │   └── event.rs          ← Tipo WalEvent
    │
    ├── rules/
    │   ├── mod.rs
    │   ├── engine.rs         ← Evalúa reglas YAML contra cada WalEvent
    │   ├── loader.rs         ← Carga y recarga caliente de .yml
    │   └── types.rs
    │
    ├── propagation/
    │   ├── mod.rs
    │   ├── mdm.rs
    │   ├── fiscal.rs         ← Publica Redis Stream biedata:invoices:BO
    │   ├── context.rs
    │   └── embedding.rs
    │
    ├── dlq/
    │   └── queue.rs          ← Dead Letter Queue con reintentos exponenciales
    │
    ├── metrics.rs
    └── health.rs
```

### 4.3 El `main.rs` de bKernel

```rust
// crates/bkernel/src/main.rs

use tokio::signal;
use tracing::{error, info};

mod wal;
mod rules;
mod propagation;
mod dlq;
mod metrics;
mod health;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .json()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive("bkernel=info".parse()?)
        )
        .init();

    info!(service = "bkernel", version = env!("CARGO_PKG_VERSION"), "iniciando");

    let config = config::load_from_vault().await
        .expect("no se pudo cargar configuración desde Vault");

    let pool = sqlx::PgPool::connect(&config.database_url).await
        .expect("no se pudo conectar a PostgreSQL");

    let redis = redis::Client::open(config.redis_url.clone())
        .expect("no se pudo conectar a Redis");

    let rule_engine = rules::Engine::load_from_dir("/etc/bos/blibs/bkernel/rules/")
        .expect("no se pudo cargar el rule engine");

    let dlq = dlq::Queue::new(pool.clone(), redis.clone());

    let wal_processor = wal::Processor::new(
        pool.clone(),
        rule_engine,
        propagation::Router::new(pool.clone(), redis.clone()),
        dlq,
    );

    let metrics_srv = metrics::Server::start(":9460").await?;
    let health_srv  = health::Server::start(":9461").await?;

    let wal_handle = tokio::spawn(async move {
        if let Err(e) = wal_processor.run().await {
            error!(error = %e, "wal processor falló");
        }
    });

    signal::ctrl_c().await?;
    info!("bkernel: shutdown signal recibido");

    wal_handle.abort();
    metrics_srv.shutdown();
    health_srv.shutdown();

    info!("bkernel: detenido correctamente");
    Ok(())
}
```

### 4.4 El Procesador WAL en Rust

```rust
// crates/bkernel/src/wal/processor.rs

use tracing::{info, warn, error, instrument};
use crate::{rules, propagation, dlq};

pub struct Processor {
    pool:   sqlx::PgPool,
    rules:  rules::Engine,
    router: propagation::Router,
    dlq:    dlq::Queue,
}

impl Processor {
    pub async fn run(&self) -> Result<(), BKernelError> {
        let mut slot = wal::Slot::connect(
            &self.pool,
            "bkernel_slot",
            "pgoutput",
            &["public"],
        ).await?;

        info!("bkernel: escuchando WAL en slot 'bkernel_slot'");

        loop {
            match slot.next_event().await {
                Ok(Some(event)) => {
                    self.process_event(event).await;
                }
                Ok(None) => {
                    slot.confirm_lsn().await?;
                }
                Err(e) => {
                    error!(error = %e, "error leyendo WAL — reintentando en 5s");
                    tokio::time::sleep(Duration::from_secs(5)).await;
                }
            }
        }
    }

    #[instrument(
        name = "bkernel.process_event",
        skip(self, event),
        fields(
            table     = %event.table,
            operation = %event.operation,
            tenant_id = %event.tenant_id,
            ctx_id    = %event.ctx_id.as_deref().unwrap_or("none"),
        )
    )]
    async fn process_event(&self, event: wal::Event) {
        // Antiloop: ignorar escrituras propias de bKernel
        if event.origin.as_deref() == Some("bkernel") ||
           event.origin.as_deref() == Some("biedata") {
            return;
        }

        let actions = self.rules.evaluate(&event);

        if actions.is_empty() {
            return;
        }

        for action in actions {
            if let Err(e) = self.router.execute(&event, &action).await {
                warn!(
                    error       = %e,
                    action_type = %action.action_type,
                    "acción falló — enviando a DLQ"
                );
                let _ = self.dlq.enqueue(&event, &action, &e).await;
            }
        }
    }
}
```

### 4.5 El Rule Engine YAML en Rust

Las reglas son archivos YAML declarativos. No se escribe Rust para agregar una nueva regla — se edita el YAML y bKernel las recarga en caliente.

```yaml
# /etc/bos/blibs/bkernel/rules/facturacion/invoice_siat.yml

id: "invoice_posted_trigger_siat_bo"
description: "Cuando una factura se aprueba en Tryton, dispara biedata para SIAT Bolivia"
enabled: true

condition:
  table:     "account_invoice"
  operation: "UPDATE"
  field:     "state"
  from:      "draft"
  to:        "posted"

actions:
  - type: "redis_stream_publish"
    stream: "biedata:invoices:BO"
    payload_mapping:
      invoice_id:  "$.new.id"
      tenant_id:   "$.tenant_id"
      ctx_id:      "$.ctx_id"
      amount:      "$.new.amount_total"
      currency:    "$.new.currency_id"
      partner_id:  "$.new.partner_id"
```

```rust
// crates/bkernel/src/rules/engine.rs

use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct Rule {
    pub id:          String,
    pub description: String,
    pub enabled:     bool,
    pub condition:   Condition,
    pub actions:     Vec<Action>,
}

#[derive(Debug, Deserialize)]
pub struct Condition {
    pub table:     String,
    pub operation: Operation,
    pub field:     Option<String>,
    pub from:      Option<String>,
    pub to:        Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Action {
    RedisStreamPublish {
        stream:          String,
        payload_mapping: std::collections::HashMap<String, String>,
    },
    DbWrite {
        target_table:  String,
        field_mapping: std::collections::HashMap<String, String>,
    },
    EmbeddingQueue {
        model:      String,
        text_field: String,
    },
    ContextUpdate {
        session_field: String,
    },
}

pub struct Engine {
    rules: Vec<Rule>,
}

impl Engine {
    pub fn load_from_dir(path: &str) -> Result<Self, std::io::Error> {
        let mut rules = Vec::new();
        for entry in std::fs::read_dir(path)? {
            let path = entry?.path();
            if path.extension().map_or(false, |e| e == "yml" || e == "yaml") {
                let content = std::fs::read_to_string(&path)?;
                let rule: Rule = serde_yaml::from_str(&content)
                    .expect(&format!("YAML inválido en {:?}", path));
                if rule.enabled {
                    rules.push(rule);
                }
            }
        }
        Ok(Engine { rules })
    }

    pub fn evaluate(&self, event: &wal::Event) -> Vec<&Action> {
        self.rules
            .iter()
            .filter(|r| r.condition.matches(event))
            .flat_map(|r| r.actions.iter())
            .collect()
    }
}
```

---

## Parte V — Cómo el Servidor Provee JSON-RPC

### 5.1 El Flujo Completo: de JSON-RPC a gRPC y de Vuelta

El desarrollador de servicios Go no configura JSON-RPC directamente. Lo que hace es:

1. Definir el servicio en `.proto`
2. Implementar el handler gRPC en Go
3. Declarar el mapping en la configuración de Kong

Kong hace el resto: recibe JSON-RPC, llama gRPC, convierte la respuesta.

### 5.2 El Mapping Kong: JSON-RPC → gRPC

```yaml
# fichas/pos-service/yaml_engine.yml (extracto)

kong_routes:
  - name: pos-venta-rpc
    method_prefix: "pos"
    upstream: "pos-service.skull-maya.svc.cluster.local:50051"
    method_mapping:
      "pos.venta.IniciarVenta":    "/sbos.pos.v1.VentaService/IniciarVenta"
      "pos.venta.RegistrarItem":   "/sbos.pos.v1.VentaService/RegistrarItem"
      "pos.venta.RemoverItem":     "/sbos.pos.v1.VentaService/RemoverItem"
      "pos.venta.CerrarVenta":     "/sbos.pos.v1.VentaService/CerrarVenta"
      "pos.sesion.IniciarTurno":   "/sbos.pos.v1.SesionService/IniciarTurno"
      "pos.pago.RegistrarPago":    "/sbos.pos.v1.PagoService/RegistrarPago"
```

### 5.3 Cómo Kong Transforma el Request

```
╔══════════════════════════════════════════════════════════════╗
║  REQUEST ENTRANTE (JSON-RPC)                                 ║
╠══════════════════════════════════════════════════════════════╣
║  POST /api/v1/rpc                                            ║
║  Authorization: Bearer {jwt}                                 ║
║  X-SBOS-CtxId: ctx-88291-a4f9                               ║
║                                                              ║
║  {                                                           ║
║    "jsonrpc": "2.0",                                        ║
║    "id":      "uuid-correlation",                           ║
║    "method":  "pos.venta.RegistrarItem",                    ║
║    "params":  {                                              ║
║      "venta_id":             "uuid-venta",                  ║
║      "producto_id":          "uuid-prod",                   ║
║      "cantidad":             2,                             ║
║      "precio_unit_centavos": 4550                           ║
║    }                                                         ║
║  }                                                           ║
╠══════════════════════════════════════════════════════════════╣
║  KONG PROCESA                                                ║
║  1. Valida JWT → extrae tenant, user, bitmask, ctx_id       ║
║  2. Verifica ctx_id en bos Context API (Redis O(1))         ║
║  3. Determina servicio gRPC destino por método JSON-RPC     ║
║  4. Convierte params JSON → mensaje proto RegistrarItemReq  ║
║  5. Construye metadata gRPC con headers SBOS                 ║
╠══════════════════════════════════════════════════════════════╣
║  LLAMADA GRPC SALIENTE (hacia Go service)                   ║
╠══════════════════════════════════════════════════════════════╣
║  grpc://pos-service:50051                                    ║
║  /sbos.pos.v1.VentaService/RegistrarItem                    ║
║                                                              ║
║  Metadata:                                                   ║
║    x-sbos-ctx-id:       ctx-88291-a4f9                      ║
║    x-sbos-tenant:       skull                               ║
║    x-sbos-user:         3397708                             ║
║    x-sbos-empresa:      maya                                ║
║    x-sbos-sucursal:     lapaz                               ║
║    x-sbos-pos:          POS-23                              ║
║    x-sbos-bitmask:      0x00000000000A3F21                  ║
║    x-sbos-correlation:  uuid-correlation                    ║
╠══════════════════════════════════════════════════════════════╣
║  RESPUESTA GRPC → JSON-RPC response                         ║
╠══════════════════════════════════════════════════════════════╣
║  {                                                           ║
║    "jsonrpc": "2.0",                                        ║
║    "id":      "uuid-correlation",                           ║
║    "result":  {                                              ║
║      "item_id":              "uuid-item",                   ║
║      "subtotal_centavos":    9100,                          ║
║      "total_venta_centavos": 18350,                         ║
║      "estado_venta":         "en_proceso"                   ║
║    }                                                         ║
║  }                                                           ║
╚══════════════════════════════════════════════════════════════╝
```

### 5.4 Convención de Nombres de Métodos JSON-RPC

```
{dominio}.{subdominio}.{Accion}

Reglas:
- dominio:    sustantivo en minúscula (pos, facturacion, inventario)
- subdominio: agregado o módulo en minúscula (venta, sesion, stock)
- Accion:     PascalCase imperativo del dominio, no verbos CRUD genéricos

✅ pos.venta.CerrarVenta
✅ facturacion.sfe.EmitirFactura
✅ inventario.stock.AjustarConteo

❌ pos.venta.Create
❌ inventario.stock.Update
❌ facturacion.invoice.Delete
```

---

## Parte VI — Reglas de Programación Críticas

### 6.1 Go — Lo que Siempre y lo que Nunca

```
SIEMPRE:
  ✅ Embeber Unimplemented{X}Server en todo handler gRPC
  ✅ Verificar BitMask en el handler ANTES de ejecutar lógica
  ✅ Wrappear errores: fmt.Errorf("operacion [ctx=%s]: %w", ctxID, err)
  ✅ Usar slog con ctx_id, tenant_id y correlation_id en cada log
  ✅ Propagar metadata SBOS en cada llamada gRPC saliente
  ✅ Incluir ctx_id en toda escritura a BD
  ✅ int64 en centavos para dinero — nunca float
  ✅ Retornar error — nunca ignorar un error retornado
  ✅ Leer secretos de Vault al inicio — nunca de variables de entorno

NUNCA:
  ❌ panic() en producción
  ❌ Llamadas HTTP salientes a APIs externas (solo biedata)
  ❌ Escribir directamente en la BD de otro servicio
  ❌ Goroutines sin mecanismo de control de ciclo de vida
  ❌ Loggear payloads completos en nivel INFO
  ❌ Hardcodear IPs, puertos o strings de conexión
```

### 6.2 Rust — Lo que Siempre y lo que Nunca

```
SIEMPRE:
  ✅ Result<T, E> en todas las funciones
  ✅ Propagar errores con ? operator
  ✅ thiserror para tipos de error en librerías
  ✅ anyhow solo en binarios (main.rs)
  ✅ tracing::instrument en funciones críticas del procesador WAL
  ✅ Fields tracing con ctx_id y tenant_id
  ✅ Antiloop: verificar origin != 'bkernel' antes de procesar

NUNCA:
  ❌ .unwrap() en código de producción
  ❌ .expect() salvo errores de configuración al arranque
  ❌ unsafe sin justificación documentada y aprobación del arquitecto
  ❌ std::thread::sleep en código async
  ❌ Mutex bloqueante en paths críticos del procesador WAL
```

### 6.3 Errores gRPC — La Tabla de Mapping

| Error de dominio | Código gRPC | Código JSON-RPC resultante |
|---|---|---|
| Entidad no encontrada | `codes.NotFound` | -32005 (causa NOT_FOUND) |
| Regla de negocio violada | `codes.FailedPrecondition` | -32005 |
| BitMask insuficiente | `codes.PermissionDenied` | -32001 |
| ctx_id inválido | `codes.Unauthenticated` | -32002 |
| Parámetros inválidos | `codes.InvalidArgument` | -32602 |
| Servicio externo timeout | `codes.Unavailable` | -32004 |
| Error inesperado | `codes.Internal` | -32603 |
| Recurso ya existe | `codes.AlreadyExists` | -32005 (causa EXISTS) |

### 6.4 Testing

```
Tests unitarios — obligatorios para:
  → Command handlers (con repos stub, no BD real)
  → Lógica de dominio (agregados, value objects)
  → Rule Engine (condición y acción)
  → BitMask parser y verificación
  → Mapper proto ↔ dominio

Tests de integración — obligatorios en dominios críticos:
  → Repositories contra PostgreSQL real (testcontainers)
  → Handler gRPC completo (bufconn — in-process listener)
  → Procesador WAL (slot real contra PG en Docker)
  → Saga completa de cierre de venta

Tests de contrato:
  → buf breaking antes de cualquier cambio al .proto
```

```go
// Test de integración con bufconn (sin red real)

func TestRegistrarItem_Integration(t *testing.T) {
    lis := bufconn.Listen(1024 * 1024)
    srv := grpc.NewServer(
        grpc.ChainUnaryInterceptor(
            grpcmiddleware.ContextInterceptor,
            grpcmiddleware.RecoveryInterceptor,
        ),
    )
    posv1.RegisterVentaServiceServer(srv, buildTestHandler(t))
    go srv.Serve(lis)
    defer srv.Stop()

    conn, _ := grpc.DialContext(context.Background(), "bufnet",
        grpc.WithContextDialer(func(ctx context.Context, _ string) (net.Conn, error) {
            return lis.Dial()
        }),
        grpc.WithTransportCredentials(insecure.NewCredentials()),
    )
    client := posv1.NewVentaServiceClient(conn)

    outCtx := metadata.NewOutgoingContext(context.Background(),
        metadata.Pairs(
            "x-sbos-ctx-id",      "ctx-test-001",
            "x-sbos-tenant",      "test-tenant",
            "x-sbos-user",        "user-001",
            "x-sbos-bitmask",     "0x00000000000A3F21",
            "x-sbos-correlation", "corr-001",
        ),
    )

    resp, err := client.RegistrarItem(outCtx, &posv1.RegistrarItemRequest{
        Ctx: &commonv1.RequestContext{
            CtxId:         "ctx-test-001",
            TenantId:      "test-tenant",
            CorrelationId: "corr-001",
            UserId:        "user-001",
        },
        VentaId:            "venta-001",
        ProductoId:         "prod-001",
        Cantidad:           2,
        PrecioUnitCentavos: 4550,
    })

    require.NoError(t, err)
    assert.Equal(t, int64(9100), resp.SubtotalCentavos)
}
```

---

## Apéndice — Checklist Pre-Commit del Desarrollador Backend

**Contrato gRPC:**
- [ ] ¿El `.proto` nuevo o modificado pasó `buf lint`?
- [ ] ¿`buf breaking` no detectó cambios incompatibles sin bumping de versión?
- [ ] ¿Todos los campos monetarios son `int64` en centavos?
- [ ] ¿El `RequestContext ctx = 1` está en todos los request messages?
- [ ] ¿Los campos eliminados tienen `reserved` para el número y el nombre?

**Handler Go:**
- [ ] ¿Se embebe `Unimplemented{X}Server`?
- [ ] ¿Se verifica BitMask antes de ejecutar lógica de negocio?
- [ ] ¿Los errores de dominio están mapeados en `{dominio}GRPCError()`?
- [ ] ¿Las llamadas a otros servicios usan `grpcmiddleware.OutgoingContext(ctx)`?

**Persistencia:**
- [ ] ¿Toda escritura en BD incluye `ctx_id` propagado del context?
- [ ] ¿Toda query tiene `tenant_id` en el WHERE?
- [ ] ¿Los errors del repo están wrapeados con `fmt.Errorf("repo.operacion: %w", err)`?

**Rust:**
- [ ] ¿No hay `.unwrap()` fuera de tests?
- [ ] ¿El procesador WAL verifica `origin != 'bkernel'` antes de procesar?
- [ ] ¿Las funciones críticas tienen `#[instrument]` con ctx_id y tenant_id?

**Tests:**
- [ ] ¿Los command handlers nuevos tienen tests unitarios con repos stub?
- [ ] ¿Los handlers gRPC críticos tienen tests de integración con bufconn?

---

---

## Parte VII — BosAgent: Estándares del Daemon Plano de Control

Esta sección es específica del daemon `bos`. Los estándares de Partes I–VI aplican
al ecosistema SBOS completo. Esta parte define cómo se desarrolla **este** daemon.

### 7.1 Identidad del Módulo

```
Módulo Go:     bos
Directorio:    /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/
Compilador:    Go 1.22+ (CGO_ENABLED=0, binario estático)
Build:         bash staging/build.sh → sbos-bootstrap.zip
Deploy:        scp + bash install.sh → TUI aparece en servidor
```

### 7.2 Árbol de Paquetes — Regla de Organización

Cada directorio es un paquete. Un paquete tiene una responsabilidad.
No se mezclan capas dentro del mismo paquete.

```
cmd/
├── bos/            ← daemon residente (systemd). Solo wire-up y señales OS.
│   └── main.go
└── bosctl/         ← CLI + TUI. Comandos humanos + screens interactivos.
    ├── main.go
    ├── install_ui_impl.go    ← modelo TEA del instalador/dashboard
    └── <comando>.go          ← un archivo por subcomando bosctl

internal/
├── tui/
│   └── ctrl/
│       ├── dash/             ← DashModel, tipos, widgets — sin dependencias externas
│       ├── k8s/              ← 5 screens: ControlPlane, Nodos, Pods, Logs, Red
│       ├── sistema/          ← 6 screens: Metricas, Discos, Servicios, Procesos, Red, Firewall
│       ├── panel/            ← 12 screens: Overview, Fichas, Tenants, Updates, ...
│       ├── render.go         ← compositor: importa dash/, k8s/, sistema/, panel/
│       └── dims_test.go
├── observer/
│   └── system_reader.go      ← lector de datos del sistema (ver §7.4)
├── state/                    ← STATE_MANAGER: .sbos_state.json + fcntl.flock
├── installer/                ← Sagas de instalación con compensación
├── server/
│   ├── ws.go                 ← WebSocket RPC (para bosctl + Core UI)
│   └── jsonrpc.go            ← JSON-RPC 2.0 (para biedata, agentes IA, otros daemons)
└── ...
```

**Regla de dependencia de TUI:**

```
dash/    → no importa nada de k8s/, sistema/, panel/
k8s/     → importa solo dash/
sistema/ → importa solo dash/
panel/   → importa solo dash/
render.go → importa todos los subpaquetes
```

Esto elimina dependencias circulares. El modelo (`DashModel`) vive en `dash/` y
fluye hacia abajo. Nunca al revés.

### 7.3 Interface Dual — Regla de Implementación (ADR-020)

**Cada feature del daemon `bos` DEBE existir en tres lugares antes de considerarse completo:**

```
1. domain/<servicio>.go        ← lógica pura, sin protocolo, sin I/O
2. internal/server/jsonrpc.go  ← handler JSON-RPC 2.0: bos.<modulo>.<operacion>
3. cmd/bosctl/<comando>.go     ← subcomando CLI (vía WebSocket RPC)
```

**Checklist de feature completo:**

| Pregunta | Si NO → tarea pendiente |
|---|---|
| ¿La lógica está en `domain/` sin imports de protocolo? | Extraer a domain/ |
| ¿Existe handler en `server/jsonrpc.go` con método `bos.X.Y`? | Agregar handler JSON-RPC |
| ¿Existe subcomando en `cmd/bosctl/`? | Agregar comando CLI |
| ¿La pantalla TUI correspondiente muestra datos reales? | Conectar observer (§7.4) |

**Un feature sin handler JSON-RPC no existe para biedata ni para agentes IA.**
**Un feature sin pantalla TUI no es verificable en VPS.**

### 7.4 Patrón Observer — Lector de Datos del Sistema

Todo dato real que aparece en el dashboard viene de un `Reader` en `internal/observer/`.
El patrón tiene dos funciones obligatorias:

```go
// Read() es pura — lee el sistema, retorna datos, no tiene side effects.
// Se puede llamar en cualquier momento, incluyendo tests unitarios.
func Read() (MetricasSnap, error)

// Start() corre en background — llama Read() periódicamente y envía
// resultados al canal ch. Se cancela via ctx.
func Start(ctx context.Context, ch chan<- DashTickMsg)
```

**Regla:** `Read()` no debe modificar estado. `Start()` no debe contener lógica de
negocio. La separación permite testear `Read()` sin goroutines y sin timers.

**Conexión al TUI:**

```
observer.Start() → chan DashTickMsg → BubbleTea msg → model.ApplyTick() → renders reales
```

El modelo TEA recibe `DashTickMsg` y reemplaza los datos de `loadMock()`.
`ApplyTick()` es el único punto de entrada de datos reales al modelo.

```go
// En DashModel:
func (m DashModel) ApplyTick(tick DashTickMsg) DashModel {
    m.CPUPct    = tick.CPU
    m.RAMUsedMB = tick.RAM
    m.Uptime    = tick.Uptime
    // ... etc
    return m
}
```

### 7.5 TUI como Criterio de Aceptación

**Ningún átomo del plan se certifica como ✅ si la pantalla TUI correspondiente
no muestra datos reales en el VPS de prueba.**

| Datos del sistema | Pantalla TUI | Átomo relacionado |
|---|---|---|
| CPU, RAM, Uptime | sistema/Metricas | M1.1 |
| Pods K8s | k8s/Pods | M2.1 |
| Estado de fichas | panel/Fichas | M3.1 |
| Logs del daemon | k8s/Logs | M4.1 |

Los mocks (`loadMock()`) son andamio — válidos en desarrollo local.
En VPS, el observer real debe alimentar el modelo.

### 7.6 Definición de Hecho (DoD) — BosAgent

Antes de marcar cualquier átomo como ✅, ejecutar en `BosAgent/src/`:

```bash
# 1. Build sin errores
CGO_ENABLED=0 go build ./...

# 2. Vet limpio
go vet ./...

# 3. Formato correcto (cero diferencias)
gofmt -l . | wc -l | grep "^0$"

# 4. Tests sin race conditions
go test -race -count=3 ./...

# 5. Certificación VPS — la pantalla muestra datos reales
# Conectar al VPS, abrir bosctl setup, navegar a la pantalla del átomo,
# verificar que los datos cambian y son reales (no mock).
```

**Si algún paso falla → el átomo no está completo. Sin excepciones.**

El paso 5 requiere un VPS activo. El VPS puede reiniciarse/reinstalarse sin
restricciones para volver a estado limpio. Un test en VPS tiene más valor
que 100 tests unitarios con mocks.

### 7.7 Convención de Commits

```
[FX.Y] tipo: descripción en imperativo presente

Tipos:
  feat   → nueva funcionalidad
  fix    → corrección de bug
  test   → solo tests
  refact → refactorización sin cambio de comportamiento
  docs   → solo documentación

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

**Ejemplos correctos:**

```
[F11.1] feat: DEPENDENCY_RESOLVER resuelve DAG topológico de fichas
[F1.5]  fix: mutex anti-race en observer, elimina DATA RACE en scheduler
[M1.1]  feat: system_reader.go lee /proc/stat y /proc/meminfo, wira Metricas TUI
```

Un commit = un átomo. No se agrupan átomos de fases distintas.

### 7.8 Estrategia de Tests

```
Tests unitarios (sin tag de build):
  → Lógica de dominio pura
  → system_reader.Read() con datos sintéticos
  → DashModel.ApplyTick() con ticks construidos
  → Parser de configuración TOML
  → Verificar que loadMock() no está presente en la ruta de producción

Tests de integración (//go:build integration):
  → Se ejecutan SOLO en VPS — no en CI local
  → system_reader.Start() con timeout real (5s mínimo)
  → Conexión WebSocket a /run/bos/bos.sock
  → JSON-RPC bos.health.check contra daemon en ejecución
  → Instalación completa en nspawn blindado
```

```go
// Marcar con build tag para excluirlos del ciclo normal:
//go:build integration

package observer_test

import (
    "context"
    "testing"
    "time"
    "bos/internal/observer"
)

func TestSystemReader_Start_Integration(t *testing.T) {
    ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()

    ch := make(chan observer.DashTickMsg, 10)
    go observer.Start(ctx, ch)

    select {
    case tick := <-ch:
        if tick.CPU < 0 || tick.CPU > 100 {
            t.Errorf("CPU fuera de rango: %f", tick.CPU)
        }
    case <-ctx.Done():
        t.Fatal("timeout esperando primer tick del observer")
    }
}
```

### 7.9 Pipeline de Deploy al VPS

```bash
# En máquina de desarrollo:
cd /opt/skull/.../BosAgent/staging
bash build.sh              # genera sbos-bootstrap.zip

# Copiar al VPS y ejecutar:
scp sbos-bootstrap.zip vps-pruebas:/tmp/
ssh vps-pruebas "cd /tmp && unzip -o sbos-bootstrap.zip -d sbos && cd sbos && bash install.sh"
# TUI aparece en la terminal SSH.
# Al completar, el servidor se reinicia y el dashboard aparece en tty1.
```

**Alias SSH permanente para evitar alertas del proveedor:**

```
# ~/.ssh/config
Host vps-pruebas
    HostName 13.140.128.230
    User root
    IdentityFile ~/agente_key
    ServerAliveInterval 30
```

**Reset del VPS para prueba en limpio:**

```bash
# Reinstalar el sistema operativo desde el panel del proveedor VPS.
# Sin restricciones — el VPS es el laboratorio de certificación.
# Un servidor en estado limpio es más valioso que un servidor con historia.
```

### 7.10 Fases de Desarrollo y Pantallas TUI Asociadas

Cada M-fase del MANIFIESTO-DESARROLLO.md conecta datos reales a pantallas TUI.
Las F-fases del REGISTRO-ESTADO.md construyen las capacidades del daemon.

```
F0-F10  → Infraestructura del daemon (sagas, JSON-RPC, reconcile, tests)
F11-F17 → Ficha Engine, Bootstrap capas, multi-tenant, release plane

M1  → /proc → sistema/Metricas (CPU, RAM, uptime)
M2  → kubectl/k8s API → k8s/Nodos, k8s/Pods, k8s/ControlPlane
M3  → STATE_MANAGER → panel/Fichas (18 estados por ficha)
M4  → journalctl → k8s/Logs (streaming de logs en tiempo real)
M5  → release.json → panel/Updates (versiones disponibles)
M6  → alertas reales → panel/Alertas (sin umbral hardcodeado)
M7  → audit trail → panel/AuditLog (ctx_id en cada operación)
```

**Regla de priorización:** los átomos M bloquean la certificación del VPS.
Los átomos F habilitan los átomos M. El orden es: F-bloqueos → M-visibilidad → certificación.

---

*SKULL · SBOS · SBOS Backend Development Standards v1.0 · Junio 2026*
*Foco: Go, Rust, gRPC, y cómo el servidor provee JSON-RPC*
*Parte VII: BosAgent — daemon plano de control, estándares específicos*
