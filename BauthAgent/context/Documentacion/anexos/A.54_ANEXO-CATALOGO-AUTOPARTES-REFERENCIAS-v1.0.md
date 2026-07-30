# A.54 — Catálogo de Autopartes y Referencias Cross-Tenant
## Tipo B+C — Patrón N-to-N, multi-tenant, visibilidad y trazabilidad en referencias entre entidades

**Versión:** 1.0.0
**Fecha:** 2026-07-15
**Tipo de anexo:** B (respaldo industria) + C (justificación de decisión técnica)
**Respalda a:** [1.06 D00 Identidad v2.1.0 §12](../1.06_MANUAL-D00-IDENTIDAD-v2.0.md) — N-to-N, multi-tenant, visibilidad
**Fuentes absorbidas:** `ANALISIS-CATALOGO-AUTOPARTES-v1.0.md` · `ANALISIS-CTX-ID-IDENTIDAD-VARIABLE-v1.0.md`
**Normas base:** ISO 9001:2015 §3.2.4-3.2.6

---

## §1 Propósito

Demostrar que el sistema de identidad puede ligar entidades de diferentes tenants sin que
los dueños se conozcan entre sí, usando referencias N-to-N con visibilidad controlada.

**Cómo citarlo:** `A.54 §N`

---

## §2 El patrón N-to-N

Un farol DEPO 212-1112-L es compatible con 4 sistemas de iluminación (Toyota Carina,
Toyota Corolla, Nissan Sentra, Honda Civic). BOSCH fabrica el mismo farol (B-9876-L)
para los mismos sistemas. TRW fabrica pastillas de freno para Carina y Corolla.

Cada relación es una fila en `idn_identity_attribute` con `attr_key = 'compatible.sistema_id'`.
N-to-N resuelto sin tablas pivote.

---

## §3 Visibilidad cross-tenant

| Visibilidad | El dueño del código puede ver quién lo usa? | El referenciador puede ver a otros? |
|---|---|---|
| **PRIVADA** (default) | No | No |
| **COMPARTIDA** | Sí | Sí |
| **PUBLICA** | Sí | Sí |

`value_data` JSONB almacena: `origen_tenant`, `visibilidad`, `referenciado_por`, `fecha_referencia`.

---

## §4 Distribución autorizada y custodia

**Caso A — Fabricante → Distribuidores:** María fabrica mantequilla. Solo Frila X, Y, Z
están autorizados a venderla. El buscador muestra dónde comprar.

**Caso B — Custodia transferida:** Juan deja sus chocolates en Puntos de Entrega. Al
entregarlos, el producto pasa a ser propiedad del punto de entrega. Ya no es de Juan.
Si hay devolución, regresa a Juan. El punto cobra % de comisión.

---

## §5 El ctx_id no cambia

Estructura fija de 6 segmentos: `prefijo . tenant . bdomain . bsubdomain . pos . actor . traceparent`.
Los valores vienen de `idn_identity_entity.slug`. La diversidad está en los ~40 tipos, no en la forma.
Solo los ACTORES tienen ctx_id.

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-15 | Primera edición. Absorbe ANALISIS-CATALOGO-AUTOPARTES y ANALISIS-CTX-ID-IDENTIDAD-VARIABLE. |
