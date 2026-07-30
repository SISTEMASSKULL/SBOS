# Análisis — El ctx_id con identidades variables

## La estructura no cambia. Lo que cambia es el significado de cada segmento.

**Versión:** 1.0
**Fecha:** 2026-07-15

---

## 1. El problema

Antes del motor de identidad, el ctx_id era claro:

```
externo/interno . tenant . empresa . sucursal . pos . actor . traceparent
```

Pero ahora una entidad puede ser un producto en un almacén, un vehículo en una flota,
un servidor en un datacenter. Ninguno de estos tiene "empresa", "sucursal" o "pos" en
el sentido tradicional. ¿Cómo se forma el ctx_id para un farol en un estante?

---

## 2. La estructura no cambia — 6 segmentos, siempre

El ctx_id tiene 6 segmentos fijos. Lo que cambia es el **significado** de los segmentos
3, 4, y 5. El segmento 1 (prefijo interno/externo) y el 2 (tenant) son estables. El 6
(traceparent) es W3C.

```
ctx_id = prefijo . tenant . NIVEL_3 . NIVEL_4 . NIVEL_5 . actor . traceparent
         ──────   ──────   ───────   ───────   ───────   ─────   ──────────
         interno/  tenant   bdomain   bsubdom    pos      actor    W3C
         externo   _id      _id       _id        _id      _id
```

Los niveles 3, 4, 5 SIEMPRE son los mismos niveles de `idn_entidad`. Sus slugs vienen de
`idn_entidad.slug`. Lo que cambia es el `tipo` de entidad en cada nivel, que determina
el significado semántico.

---

## 3. El ctx_id se forma con slugs, no con conceptos de negocio

```
EMPLEADO (Juan Pérez):
  interno.skull.skull-corp.norte.caja-01.jperez.00-trace...
          └──────┘ └───────┘ └───┘ └────┘ └────┘
          tenant    bdomain   bsub   pos    actor
          (interno) (empresa) (suc) (caja) (HUMAN)

PRODUCTO (Farol DEPO):
  externo.t-depo.bd-catalogo.bs-region.pos-estante.act-farol.00-trace...
          └────┘ └──────────┘ └────────┘ └─────────┘ └───────┘
          tenant bdomain      bsubdomain pos         actor
          (ext)  (catalogo)   (region)   (estante)   (autoparte)

VEHÍCULO (Camión Volvo):
  externo.t-flota.bd-patio.bs-central.pos-est-01.act-camion.00-trace...
          └────┘ └──────┘ └────────┘ └────────┘ └────────┘
          tenant bdomain  bsubdomain pos        actor
          (ext)  (empresa)(patio)    (estacion) (vehiculo)

SERVIDOR (HP ProLiant):
  interno.skull.bd-datacenter.bs-sala.rack-01.servidor-001.00-trace...
          └───┘ └───────────┘ └─────┘ └─────┘ └──────────┘
          tenant bdomain       bsub    pos     actor
          (int)  (datacenter)  (sala)  (rack)  (servidor)

PACIENTE (Juan internado):
  interno.skull.bd-hospital.bs-piso3.habitacion-302.jperez.00-trace...
          └───┘ └─────────┘ └──────┘ └────────────┘ └────┘
          tenant bdomain     bsub     pos            actor
          (int)  (hospital)  (piso)   (habitacion)   (HUMAN)
```

**Los 5 niveles del árbol D00 SON los segmentos del ctx_id.** El `slug` de cada entidad
en `idn_entidad` forma el segmento. El `tipo` de cada entidad le da significado. Pero
la estructura de 6 segmentos es invariable.

---

## 4. No todas las entidades tienen los 6 segmentos

Un tenant no tiene ctx_id. Es la raíz. Está EN el ctx_id, no TIENE ctx_id.
Un bdomain no tiene ctx_id propio. Está dentro del ctx_id del actor que opera sobre él.

**Solo los ACTORES tienen ctx_id completo.** Son los que operan, los que inician sesión,
los que ejecutan acciones. Un producto no inicia sesión. Un estante no se autentica.

```
¿Quién tiene ctx_id?
  ✅ Juan Pérez (actor, HUMAN)      → ctx_id completo de 6 segmentos
  ✅ SAP-BOT (actor, SERVICE)        → ctx_id de 6 segmentos
  ✅ Servidor HP (actor, servidor)   → ctx_id de 6 segmentos (M2M)
  ❌ SKULL-CORP (bdomain, empresa)   → no tiene ctx_id. Está en el segmento 3 del ctx_id de Juan.
  ❌ Norte (bsubdomain, sucursal)    → no tiene ctx_id. Está en el segmento 4.
  ❌ CAJA-01 (pos, caja)             → no tiene ctx_id. Está en el segmento 5.
  ❌ Farol DEPO (actor, autoparte)   → no tiene ctx_id. Es un producto, no un operador.
```

**El ctx_id es para QUIEN OPERA, no para lo que existe.** Las entidades que no son
operadores (productos, estantes, marcas, modelos) no tienen ctx_id. Son referenciadas
por actores que SÍ tienen ctx_id.

---

## 5. La secuencia SIEMPRE existe, pero no para todas las entidades

```
Para un EMPLEADO (Juan Pérez):
  ctx_id = interno.skull.skull-corp.norte.caja-01.jperez.00-...
           ✅      ✅    ✅          ✅     ✅       ✅

Para un PRODUCTO (Farol DEPO):
  ctx_id = NO TIENE. Es una entidad referenciada, no un operador.
  Cuando la Tiendita lo vende:
    ctx_id de la Tiendita = externo.t-tiendita.bd-inventario.bs-local.pos-mostrador.act-vendedor.00-...

Para un VEHÍCULO (Camión Volvo):
  ctx_id = NO TIENE (a menos que tenga telemetría M2M).
  Si tiene GPS/telemetría:
    ctx_id = externo.t-flota.bd-patio.bs-central.pos-est-01.act-camion.00-...
    (el camión es actor tipo=vehiculo con autenticación M2M)

Para un SERVIDOR:
  ctx_id = interno.skull.bd-datacenter.bs-sala.rack-01.servidor-001.00-...
  (el servidor es actor tipo=servidor con autenticación M2M)
```

---

## 6. Lo que NO cambió

1. **6 segmentos, siempre.** Prefijo + tenant + bdomain + bsubdomain + pos + actor + traceparent.
2. **El prefijo interno/externo** viene de `idn_tenant.is_internal`. BOS lo incrusta al crear la sesión.
3. **Solo los ACTORES tienen ctx_id.** Las entidades de niveles superiores (tenant, bdomain, bsubdomain, pos) están DENTRO del ctx_id del actor.
4. **La estructura es estable.** Lo que es variable es el `tipo` de entidad en cada nivel, que determina el significado semántico del segmento.

**Lo que SÍ cambió con el motor de identidad:** el abanico de `tipo` posibles en cada nivel
se expandió de ~6 a ~40. Pero la estructura del ctx_id no se tocó. Los slugs siguen siendo
slugs. Los niveles siguen siendo niveles. La diversidad está en los valores, no en la forma.
