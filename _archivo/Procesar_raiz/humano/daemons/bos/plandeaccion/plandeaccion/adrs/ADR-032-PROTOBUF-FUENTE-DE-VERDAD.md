# ADR-032 — API-First: Protobuf como Fuente de Verdad

**Estado:** Aceptado  
**Fecha:** 2026-06-13  
**Origen:** §10 P10 + §12 del Master v2.1  
**Relacionado:** ADR-033 (RequestContext), ADR-034 (tipo monetario), §12 Contratos gRPC

---

## Contexto y problema

Si se escribe el código Go/Rust primero y luego se "exporta" como contrato, las interfaces evolucionan sin disciplina: los campos se agregan de forma ad-hoc, los tipos cambian sin notificación, y dos servicios que "compilan" pueden ser incompatibles en producción. Los sistemas distribuidos requieren contratos formales que sean la fuente de verdad, no el código que los implementa.

## La Decisión

**El archivo `.proto` es la fuente de verdad de cada servicio. Se escribe ANTES que el código Go o Rust. El código se genera a partir del `.proto`, nunca al revés.**

```
PROCESO OBLIGATORIO:

  1. Diseñar el contrato → escribir archivo .proto
  2. Ejecutar buf lint && buf breaking (no debe haber violaciones)
  3. Generar código → buf generate
  4. Implementar el servicio en Go/Rust contra el código generado
  5. Commit incluye TANTO el .proto COMO el código generado

VETADO:
  ❌ Escribir el handler Go primero y "después documentar"
  ❌ Modificar el .proto sin ejecutar buf breaking
  ❌ Campos eliminados o renombrados sin versión mayor
  ❌ Generar código manualmente sin buf
```

## Estructura de Contratos

```
proto/
  sbos/
    bos/v1/
      context.proto         ← Context API
      ficha.proto           ← Ficha lifecycle
      tenant.proto          ← Tenant lifecycle
    bauth/v1/
      auth.proto            ← Autenticación
      privilege.proto       ← BitMask evaluación
    bkernel/v1/
      cdc.proto             ← CDC events
    biedata/v1/
      fiscal.proto          ← Facturación SIAT
    bsearch/v1/
      search.proto          ← Búsqueda semántica
```

## Reglas de Compatibilidad (buf breaking)

| Operación | Permitido | Vetado |
|-----------|-----------|--------|
| Agregar campo | ✅ — es retrocompatible | |
| Eliminar campo | | ❌ — rompe clientes existentes |
| Renombrar campo | | ❌ — mismo efecto que eliminar |
| Cambiar tipo de campo | | ❌ — rompe serialización |
| Cambiar número de campo | | ❌ — rompe todo |
| Agregar servicio nuevo | ✅ | |
| Eliminar método de servicio | | ❌ — versión mayor requerida |

## Configuración buf.yaml

```yaml
version: v2
modules:
  - path: proto
lint:
  use:
    - STANDARD
    - COMMENTS    # Todos los campos documentados
breaking:
  use:
    - FILE
  against:
    - main~1:./proto   # compara contra HEAD-1
```

`buf lint` y `buf breaking` son gates obligatorios en CI. Un PR que rompe compatibilidad no puede mergearse.

## Consecuencias

**Positivas:**
- Los contratos son verificables y versionables como código
- `buf breaking` garantiza no romper clientes en producción
- El código generado es siempre consistente con el contrato
- Documentación del API es el `.proto` mismo (buf docs)

**Negativas/Riesgos:**
- Curva de aprendizaje inicial con buf toolchain
- Mitigación: `buf.gen.yaml` y `buf.yaml` estandarizados en todos los repos

## Normas relacionadas

- ADR-033 (RequestContext campo 1 obligatorio)
- ADR-034 (tipo monetario en .proto: int64 centavos)
- §12.1 del Master — proto como fuente de verdad
- SBOS_Backend_Development_Standards.md — §gRPC
