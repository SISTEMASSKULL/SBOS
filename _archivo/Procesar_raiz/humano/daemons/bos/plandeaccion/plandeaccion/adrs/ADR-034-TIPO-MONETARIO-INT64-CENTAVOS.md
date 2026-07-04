# ADR-034 — Tipo Monetario: int64 Centavos, Nunca float

**Estado:** Aceptado  
**Fecha:** 2026-06-13  
**Origen:** §17.1 Reglas de Oro Go del Master v2.1  
**Relacionado:** ADR-032 (Protobuf fuente de verdad), §11 Backend Services

---

## Contexto y problema

Los tipos `float64` y `float32` no pueden representar exactamente la mayoría de los valores decimales. El valor `0.1 + 0.2` en IEEE 754 es `0.30000000000000004`. En operaciones financieras, estos errores de redondeo acumulados pueden resultar en discrepancias en balances, en descuadres en reportes fiscales, y en errores en facturas electrónicas validadas contra el SIN (SIAT Bolivia).

## La Decisión

**Todo valor monetario en el ecosistema SBOS se representa como `int64` en centavos (o la unidad mínima de la moneda) + `string` para el código de moneda ISO 4217. Nunca `float`, `float32` ni `float64`.**

```protobuf
// ✅ CORRECTO en .proto
message Monto {
  int64  centavos  = 1;  // 100 = 1.00 BOB / 1.00 USD / etc.
  string moneda    = 2;  // "BOB", "USD", "PEN" — ISO 4217
}

// Ejemplos:
// 1.50 BOB → {centavos: 150, moneda: "BOB"}
// 100.00 USD → {centavos: 10000, moneda: "USD"}
// 0.01 USD → {centavos: 1, moneda: "USD"}
```

```go
// ✅ CORRECTO en Go
type Monto struct {
    Centavos int64  `json:"centavos"`
    Moneda   string `json:"moneda"` // ISO 4217
}

func (m Monto) String() string {
    return fmt.Sprintf("%.2f %s", float64(m.Centavos)/100.0, m.Moneda)
}

// ❌ VETADO
type Precio struct {
    Valor   float64 `json:"valor"`   // ← nunca
    Moneda  string  `json:"moneda"`
}
```

## Reglas de Conversión

| Operación | Implementación |
|-----------|---------------|
| Suma | `resultado.Centavos = a.Centavos + b.Centavos` |
| Resta | `resultado.Centavos = a.Centavos - b.Centavos` |
| Multiplicar por factor | `resultado.Centavos = a.Centavos * factor` (integer) |
| IVA (13%) | `iva.Centavos = (neto.Centavos * 13 + 99) / 100` (redondeo hacia arriba) |
| Display | Solo al mostrar al usuario: `fmt.Sprintf("%.2f", float64(centavos)/100.0)` |
| Monedas distintas | Conversión prohibida sin tipo de cambio explícito y `correlation_id` |

## Base de Datos

```sql
-- ✅ CORRECTO en PostgreSQL
CREATE TABLE lineas_factura (
    id          UUID PRIMARY KEY,
    tenant_id   UUID NOT NULL,
    monto_centavos BIGINT NOT NULL,   -- nunca DECIMAL(10,2) para valores calculados
    moneda      CHAR(3) NOT NULL,     -- ISO 4217
    ...
);

-- ❌ VETADO
monto DECIMAL(10,2)  -- puede tener errores en operaciones
monto FLOAT          -- definitivamente no
```

## Consecuencias

**Positivas:**
- Cero errores de punto flotante en operaciones financieras
- Los balances cuadran exactamente (crítico para SIAT Bolivia)
- Las facturas electrónicas son reproducibles: el mismo input produce el mismo output exactamente
- Cumple IEC 60559 (para sistemas que lo requieran)

**Negativas/Riesgos:**
- Requiere convertir a centavos al recibir datos de sistemas externos que usan decimales
- Mitigación: función `parseMonto(s string) (Monto, error)` en paquete `sbos/money` — convierte una sola vez en la frontera del sistema

## Normas relacionadas

- ADR-032 (Protobuf fuente de verdad — `Monto` se define en `proto/sbos/common/v1/money.proto`)
- SBOS-044-FISCAL-CONTABLE-LATAM (cumplimiento SIAT Bolivia)
- IEEE 754 (por qué float no sirve para dinero)
