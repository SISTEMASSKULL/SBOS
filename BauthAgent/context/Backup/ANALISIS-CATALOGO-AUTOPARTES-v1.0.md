# Análisis — Catálogo de Autopartes con el Sistema de Identidad

## Cómo ligar autos, sistemas y repuestos sin que las empresas se conozcan entre sí

**Versión:** 1.0
**Fecha:** 2026-07-15

---

## 1. El problema

Tres empresas independientes, cada una aporta datos que no conoce de las otras:

- **TOYOTA** fabrica autos. Sabe de modelos, sistemas y códigos OEM. No sabe quién fabrica repuestos.
- **DEPO** fabrica repuestos OEM. Sabe de partes y a qué sistema pertenecen. No sabe qué autos usan ese sistema.
- **TIENDA DE REPUESTOS** quiere buscar: "Toyota Carina 92" → listar todos los faroles compatibles.

La pregunta: ¿puede el sistema de identidad lograr que la tienda haga esa búsqueda?

**Sí. Porque las entidades se vinculan a través de referencias compartidas en `idn_atributo`.
Nadie necesita conocer a todos. Solo necesitan referenciar el mismo sistema.**

---

## 2. Las entidades

```
idn_entidad
═══════════

t-toyota (tenant, ORGANIZACION)
  │
  └── bd-toyota-corp (bdomain, ORGANIZACION)
        │  civil.razon_social: Toyota Motor Corporation
        │  civil.pais: Japón
        │
        ├── bd-toyota-bolivia (bdomain, ORGANIZACION)
        │     civil.pais: Bolivia
        │     └── REGIÓN ANDINA (bsubdomain, region)
        │           └── REGIÓN ORIENTE (bsubdomain, region)
        │
        └── CATÁLOGO TOYOTA (bdomain, catalogo)
              │
              ├── MODELO: Carina (actor, modelo_auto)
              │     │  origen.marca: Toyota
              │     │  origen.modelo: Carina
              │     │  origen.año: 1992-1997
              │     │  origen.generacion: T190
              │     │
              │     ├── SISTEMA: Eléctrico Carina (actor, sistema)
              │     │     sistema.codigo: TOY-ELEC-CARINA
              │     │     sistema.tipo: electrico
              │     │     └── REF: Toyota Motor Corp (el fabricante del auto
              │     │           es quien define los sistemas)
              │     │
              │     ├── SISTEMA: Carrocería Carina (actor, sistema)
              │     │     sistema.codigo: TOY-CARR-CARINA
              │     │     sistema.tipo: carroceria
              │     │
              │     ├── SISTEMA: Iluminación Carina (actor, sistema)
              │     │     sistema.codigo: TOY-ILUM-CARINA
              │     │     sistema.tipo: iluminacion
              │     │
              │     ├── SISTEMA: Frenos Carina (actor, sistema)
              │     │     sistema.codigo: TOY-FREN-CARINA
              │     │
              │     └── SISTEMA: Motor Carina (actor, sistema)
              │           sistema.codigo: TOY-MOT-CARINA
              │
              ├── MODELO: Corolla (actor, modelo_auto)
              │     │  origen.marca: Toyota
              │     │  origen.modelo: Corolla
              │     │  origen.año: 1993-1997
              │     │
              │     ├── SISTEMA: Eléctrico Corolla (actor, sistema)
              │     │     sistema.codigo: TOY-ELEC-COROLLA
              │     │
              │     └── SISTEMA: Iluminación Corolla (actor, sistema)
              │           sistema.codigo: TOY-ILUM-COROLLA
              │
              └── MODELO: Hilux (actor, modelo_auto)
                    ├── SISTEMA: Eléctrico Hilux (actor, sistema)
                    └── SISTEMA: Frenos Hilux (actor, sistema)
```

---

## 3. DEPO fabrica repuestos — los liga a SISTEMAS, no a autos

DEPO no sabe qué autos usan el sistema "TOY-ILUM-CARINA". Solo sabe que su farol
212-1112-L es compatible con ese sistema. La referencia es el SISTEMA, no el auto.

```
t-depo (tenant, ORGANIZACION)
  │
  └── bd-depo-bolivia (bdomain, ORGANIZACION)
        │  civil.razon_social: DEPO Bolivia SA
        │  productor.tipo: autopartes
        │  productor.calidad: OEM
        │
        └── CATÁLOGO DEPO (bdomain, catalogo)
              │
              └── PARTE: Farol Delantero Derecho DEPO (actor, autoparte)
                    │  origen.marca: DEPO
                    │  origen.codigo: 212-1112-L
                    │  origen.tipo: farol
                    │  origen.posicion: delantero_derecho
                    │  ─── COMPATIBILIDAD N-to-N ───
                    │  compatible.sistema_id: TOY-ILUM-CARINA
                    │  compatible.sistema_id: TOY-ILUM-COROLLA   ← mismo farol,
                    │  compatible.sistema_id: NIS-ILUM-SENTRA    ← compatible con
                    │  compatible.sistema_id: HON-ILUM-CIVIC     ← varios modelos
                    │  compatible.tipo_conexion: enchufe original
                    │  compatible.voltaje: 12V
                    │
                    ├── DISTRIBUCIÓN REGIONAL ──
                    │  distribucion.region: ANDINA
                    │  distribucion.stock: 45
                    │  distribucion.precio: $85
                    │
                    └── distribucion.region: ORIENTE
                          distribucion.stock: 20
                          distribucion.precio: $90

              └── PARTE: Farol Delantero Derecho BOSCH (actor, autoparte)
                    │  origen.marca: BOSCH
                    │  origen.codigo: B-9876-L
                    │  origen.tipo: farol
                    │  ─── MISMO farol, OTRO fabricante ───
                    │  compatible.sistema_id: TOY-ILUM-CARINA
                    │  compatible.sistema_id: TOY-ILUM-COROLLA
                    │  └── BOSCH también fabrica este farol.
                    │      Compite con DEPO. Mismas compatibilidades.
                    │
                    └── distribucion.region: ANDINA
                          distribucion.stock: 30
                          distribucion.precio: $95

              └── PARTE: Farol Delantero Izquierdo DEPO (actor, autoparte)
                    origen.codigo: 212-1111-L
                    compatible.sistema_id: TOY-ILUM-CARINA
                    compatible.sistema_id: NIS-ILUM-SENTRA

              └── PARTE: Luz Trasera DEPO (actor, autoparte)
                    origen.codigo: 212-2222-L
                    compatible.sistema_id: TOY-ILUM-CARINA

              └── PARTE: Pastilla de Freno DEPO (actor, autoparte)
                    origen.codigo: 212-FREN-001
                    compatible.sistema_id: TOY-FREN-CARINA
                    compatible.sistema_id: TOY-FREN-COROLLA

              └── PARTE: Pastilla de Freno TRW (actor, autoparte)
                    origen.codigo: TRW-FCAR-001
                    compatible.sistema_id: TOY-FREN-CARINA
                    └── TRW también fabrica pastillas para Carina.
                        Compite con DEPO.
```

---

## 4. La consulta mágica — la tienda busca "Toyota Carina 92, faroles"

La tienda no sabe de DEPO. No sabe de sistemas. Solo sabe que quiere faroles para un
Toyota Carina 92. El sistema recorre las referencias:

```
PASO 1: Buscar el modelo "Toyota Carina"
  SELECT entidad_id FROM idn_entidad
  WHERE tipo = 'modelo_auto'
    AND nombre ILIKE '%toyota%carina%'

  → modelo_carina

PASO 2: Buscar el sistema de iluminación de ese modelo
  SELECT a2.entidad_id AS sistema_id
  FROM idn_entidad e
  JOIN idn_atributo a1 ON e.id = a1.entidad_id
  JOIN idn_entidad e2 ON e.parent_id = e2.parent_id  -- mismo catálogo
  WHERE e.id = 'modelo_carina'
    AND e2.tipo = 'sistema'
    AND e2.nombre ILIKE '%iluminacion%'

  → TOY-ILUM-CARINA

PASO 3: Buscar todas las autopartes compatibles con ese sistema (N-to-N)
  SELECT e.nombre,
         a_marca.value_text AS marca,
         a_cod.value_text AS codigo,
         a_region.value_text AS region,
         a_stock.value_text AS stock,
         a_precio.value_text AS precio
  FROM idn_entidad e
  JOIN idn_atributo a_compat ON e.id = a_compat.entidad_id
    AND a_compat.attr_key = 'sistema_id'
  JOIN idn_atributo a_marca ON e.id = a_marca.entidad_id
    AND a_marca.attr_key = 'marca'
  JOIN idn_atributo a_cod ON e.id = a_cod.entidad_id
    AND a_cod.attr_key = 'codigo'
  JOIN idn_atributo a_region ON e.id = a_region.entidad_id
    AND a_region.attr_key = 'region'
  JOIN idn_atributo a_stock ON e.id = a_stock.entidad_id
    AND a_stock.attr_key = 'stock'
  JOIN idn_atributo a_precio ON e.id = a_precio.entidad_id
    AND a_precio.attr_key = 'precio'
  WHERE e.tipo = 'autoparte'
    AND a_compat.value_text = 'TOY-ILUM-CARINA'
    AND a_region.value_text = 'ANDINA'
  ORDER BY a_precio.value_text::numeric

  → DEPO    212-1112-L   Farol Del. Der.    ANDINA  45u  $85
  → DEPO    212-1111-L   Farol Del. Izq.    ANDINA  30u  $85
  → BOSCH   B-9876-L     Farol Del. Der.    ANDINA  30u  $95   ← mismo farol, otro fabricante
  → DEPO    212-2222-L   Luz Trasera        ANDINA  12u  $65

  El mismo farol, múltiples fabricantes. Mismo sistema, múltiples modelos de auto.
  N-to-N resuelto con múltiples filas en idn_atributo.
```

---

## 5. Por qué funciona sin que las empresas se conozcan

```
TOYOTA                          DEPO                          TIENDA
──────                          ────                          ──────

Define:                         Fabrica:                      Busca:
  modelo_auto                     autoparte                     "Toyota Carina 92"
  └── sistema (iluminación)       └── compatible.sistema_id     → faroles compatibles
                                    = TOY-ILUM-CARINA

NUNCA menciona a DEPO.           NUNCA menciona a Toyota.      NUNCA menciona a DEPO
Solo define QUE sistemas          Solo dice QUE sistema          ni a Toyota.
tiene cada auto.                 es compatible con su parte.    Solo busca por modelo.

                    ┌──────────────────────────┐
                    │   EL SISTEMA ES EL PUNTO  │
                    │   DE ENCUENTRO ANÓNIMO    │
                    │                          │
                    │   TOY-ILUM-CARINA         │
                    │   ┌──────────┐            │
                    │   │ Toyota lo│            │
                    │   │ DEFINE   │            │
                    │   └────┬─────┘            │
                    │        │                  │
                    │        ▼                  │
                    │   ┌──────────┐            │
                    │   │ DEPO lo  │            │
                    │   │ REFERENCIA│           │
                    │   └────┬─────┘            │
                    │        │                  │
                    │        ▼                  │
                    │   ┌──────────┐            │
                    │   │ Tienda   │            │
                    │   │ CONSULTA │            │
                    │   └──────────┘            │
                    └──────────────────────────┘
```

**Nadie conoce a nadie. Todos referencian el mismo sistema.** El sistema es la entidad
compartida que actúa como punto de encuentro. Es el mismo principio que una foreign key
en SQL, pero con entidades del sistema de identidad.

---

## 6. Esto escala a cualquier combinación

```
AUTOS → SISTEMAS → PARTES → REGIONES

Toyota Carina 92
  ├── TOY-ELEC-CARINA    →  DEPO: alternador, motor arranque, fusibles
  │                          BOSCH: bujías, cables
  │                          VARTA: batería
  ├── TOY-ILUM-CARINA    →  DEPO: faroles, luces traseras
  │                          OSRAM: lámparas LED
  ├── TOY-FREN-CARINA    →  DEPO: pastillas, discos
  │                          TRW: bomba de freno
  ├── TOY-CARR-CARINA    →  DEPO: guardabarros, capó
  │                          MAGNA: paragolpes
  └── TOY-MOT-CARINA     →  DEPO: filtros, bomba de agua
                             GATES: correas

Toyota Corolla 93
  ├── TOY-ELEC-COROLLA   →  DEPO: alternador (otro modelo)
  │                          BOSCH: bujías (mismas que Carina — ¡compatibilidad cruzada!)
  └── TOY-ILUM-COROLLA   →  DEPO: faroles (código diferente, no compatible con Carina)
```

**Cada fabricante agrega sus partes al sistema que le corresponde.** La tienda busca por
modelo de auto y obtiene todas las partes de todos los fabricantes. Sin que los fabricantes
sepan de la existencia de los otros.

---

## 7. Privacidad y trazabilidad — quién usa los códigos de quién

### 7.1 El problema

La Tiendita de Barrio usa los códigos de Toyota y DEPO en su inventario. Pero:

- Toyota y DEPO **no deben saber** que la Tiendita los usa (privacidad por defecto).
- La Tiendita **sí debe saber** qué códigos son propios y cuáles son referenciados.
- Si la Tiendita **quiere ser visible** (ej: "Toyota, decile a tus clientes que yo vendo tus repuestos"), puede activarlo.
- **Auditoría**: saber quién está usando los códigos de quién, y poder cobrar un porcentaje.

### 7.2 La solución: visibilidad + origen + auditoría en `idn_atributo`

Cuando la Tiendita referencia un sistema de Toyota, el atributo `compatible.sistema_id`
incluye metadatos de **visibilidad** y **origen**:

```sql
-- La Tiendita agrega un farol a su inventario, referenciando el sistema de Toyota
INSERT INTO idn_atributo (entidad_id, dominio, attr_key, type, value_text, value_data)
VALUES (
  'farol-tiendita-001',         -- entidad propia de la Tiendita
  'compatible',                  -- dominio
  'sistema_id',                  -- attr_key
  'referencia',                  -- type
  'TOY-ILUM-CARINA',            -- value_text: el sistema de Toyota
  '{
     "origen_tenant": "t-toyota",
     "origen_entidad": "TOY-ILUM-CARINA",
     "visibilidad": "privada",       -- PRIVADA | COMPARTIDA | PUBLICA
     "referenciado_por": "t-tiendita-barrio",
     "fecha_referencia": "2024-03-15",
     "proposito": "inventario"
   }'::jsonb
);
```

### 7.3 Los tres niveles de visibilidad

| Visibilidad | Toyota puede ver la Tiendita? | La Tiendita puede ver a otros? | Uso |
|---|---|---|---|
| **PRIVADA** (default) | No. No sabe que la Tiendita usa su código. | No. No ve quién más usa el mismo código. | Uso interno, investigación de mercado |
| **COMPARTIDA** | Sí. Toyota ve: "Tiendita Barrio vende faroles para Carina 92". | Sí. Ve quién más vende lo mismo. | La Tiendita quiere que Toyota la recomiende a sus clientes |
| **PUBLICA** | Sí. Cualquiera puede ver. | Sí. Todos ven a todos. | Marketplace abierto |

### 7.4 Consultas de trazabilidad

```sql
-- ¿Qué códigos de Toyota estoy usando en mi inventario?
SELECT a.value_text AS sistema_toyota, e.nombre AS mi_producto,
       a.value_data->>'visibilidad' AS visibilidad
FROM idn_atributo a
JOIN idn_entidad e ON a.entidad_id = e.id
WHERE a.attr_key = 'sistema_id'
  AND a.value_data->>'origen_tenant' = 't-toyota'
  AND a.value_data->>'referenciado_por' = 't-tiendita-barrio';

-- ¿Quién está usando MIS códigos? (si soy DEPO y quiero auditar)
SELECT a.value_data->>'referenciado_por' AS quien,
       e.nombre AS producto,
       COUNT(*) AS referencias
FROM idn_atributo a
JOIN idn_entidad e ON a.entidad_id = e.id
WHERE a.attr_key = 'sistema_id'
  AND a.value_data->>'origen_tenant' = 't-depo'
  AND a.value_data->>'visibilidad' IN ('COMPARTIDA', 'PUBLICA')
GROUP BY a.value_data->>'referenciado_por', e.nombre;

-- ¿Qué tiendas venden repuestos para el Carina 92? (visibilidad COMPARTIDA o PUBLICA)
SELECT DISTINCT a.value_data->>'referenciado_por' AS tienda,
       e.nombre AS producto,
       a.value_text AS sistema
FROM idn_atributo a
JOIN idn_entidad e ON a.entidad_id = e.id
WHERE a.value_text = 'TOY-ILUM-CARINA'
  AND a.value_data->>'visibilidad' IN ('COMPARTIDA', 'PUBLICA');
```

### 7.5 El modelo de negocio

```
TOYOTA (dueño del código)
  │
  │  Define TOY-ILUM-CARINA como sistema
  │  No sabe quién lo referencia (visibilidad PRIVADA por defecto)
  │
  ├── DEPO (fabricante OEM)
  │     │  Fabrica farol 212-1112-L
  │     │  Referencia: TOY-ILUM-CARINA (PRIVADA)
  │     │  DEPO no sabe que la Tiendita también lo usa
  │     │
  │     └── Si DEPO quiere visibilidad: cambia a COMPARTIDA
  │           → Toyota puede ver: "DEPO fabrica para mi sistema"
  │
  └── TIENDITA DE BARRIO (revendedor)
        │  Vende faroles en su inventario
        │  Referencia: TOY-ILUM-CARINA (PRIVADA)
        │  La Tiendita sabe que usa códigos de Toyota
        │  Toyota NO sabe que la Tiendita existe
        │
        └── Si la Tiendita quiere que Toyota la recomiende:
              cambia a COMPARTIDA
              → Toyota ve: "Tiendita Barrio vende repuestos para Carina 92"
              → Toyota puede recomendar: "Compre en Tiendita Barrio"
              → La Tiendita paga un % a Toyota por la referencia
```

**Por defecto, nadie sabe que existes. Solo vos sabés qué códigos estás usando.**
**Si querés ser visible, activás COMPARTIDA. Si querés auditoría de quién usa tus códigos,**
**consultás las referencias con visibilidad COMPARTIDA o PUBLICA.**

---

## 8. Multi-tenancy y Context Plane — dónde quedaron el tenant y el ctx_id

Todo lo anterior funciona **dentro del marco de aislamiento multi-tenant**. Cada entidad,
cada atributo, cada búsqueda está escopada por `tenant_id`. El ctx_id transporta el
contexto del tenant en cada request. Sin esto, el sistema de identidad sería una base
de datos global sin controles de acceso.

### 8.1 Cada tenant es una isla

```
t-toyota                    t-depo                      t-tiendita-barrio
─────────                   ──────                      ─────────────────

• Define modelos             • Fabrica partes             • Vende repuestos
• Define sistemas            • Referencia sistemas        • Referencia sistemas
• Sus entidades solo          de Toyota                    de Toyota y DEPO
  las ve Toyota              • Sus entidades solo          • Sus entidades solo
                               las ve DEPO                  las ve la Tiendita

CADA TENANT TIENE SU PROPIO ÁRBOL D00:
  t-toyota → bd-toyota-corp → CATÁLOGO TOYOTA → Modelos → Sistemas
  t-depo   → bd-depo-bolivia → CATÁLOGO DEPO   → Partes
  t-tiendita → bd-tiendita   → INVENTARIO      → Partes (referenciadas)
```

### 8.2 El ctx_id transporta el tenant en cada request

```
ctx_id = interno.t-toyota.bd-toyota-corp.catalogo.modelo_carina.act-admin.00-...

TODA consulta se filtra por tenant_id del ctx_id:

  -- Toyota consulta SUS sistemas (nunca ve los de DEPO)
  SELECT * FROM idn_entidad WHERE tenant_id = 't-toyota';

  -- DEPO consulta SUS partes (nunca ve las de la Tiendita)
  SELECT * FROM idn_entidad WHERE tenant_id = 't-depo';

  -- La Tiendita consulta SU inventario
  SELECT * FROM idn_entidad WHERE tenant_id = 't-tiendita-barrio';
```

### 8.3 Referencias cross-tenant: el atributo `origen_tenant`

Cuando la Tiendita referencia un sistema de Toyota, necesita saber que ese sistema NO es
suyo. El `value_data` del atributo registra el tenant de origen:

```sql
-- La Tiendita guarda: "mi farol es compatible con TOY-ILUM-CARINA"
INSERT INTO idn_atributo (entidad_id, dominio, attr_key, type, value_text, value_data)
VALUES (
  'farol-tiendita-001',
  'compatible', 'sistema_id', 'referencia',
  'TOY-ILUM-CARINA',              -- el ID del sistema (del tenant de Toyota)
  '{
     "origen_tenant": "t-toyota",  -- ← el sistema pertenece a Toyota
     "origen_entidad": "TOY-ILUM-CARINA",
     "visibilidad": "privada",
     "referenciado_por": "t-tiendita-barrio"
   }'::jsonb
);

-- La Tiendita puede ver SUS referencias, incluso las que apuntan a otros tenants:
SELECT * FROM idn_atributo
WHERE value_data->>'referenciado_por' = 't-tiendita-barrio';

-- Pero Toyota NO PUEDE ver las referencias de la Tiendita (visibilidad PRIVADA):
-- La consulta de Toyota solo ve sus propias entidades. Las referencias
-- de otros tenants a sus sistemas son invisibles por defecto.
```

### 8.4 El buscador une tenants respetando visibilidad

```
"Busco faroles para Toyota Carina 92"

PASO 1 — Dentro del tenant de Toyota:
  SELECT sistema_id FROM t-toyota WHERE modelo = 'Carina'
  → TOY-ILUM-CARINA  (Toyota define esto, es público dentro de su tenant)

PASO 2 — Búsqueda cross-tenant (respeta visibilidad):
  SELECT entidad_id, value_data->>'referenciado_por' AS tienda
  FROM idn_atributo
  WHERE attr_key = 'sistema_id'
    AND value_text = 'TOY-ILUM-CARINA'
    AND value_data->>'visibilidad' IN ('COMPARTIDA', 'PUBLICA')
    -- Solo ve referencias que eligieron ser visibles.
    -- PRIVADAS no aparecen.

PASO 3 — Para cada tienda visible, buscar sus datos (stock, precio, ubicación):
  SELECT e.nombre, a_stock.value_text, a_precio.value_text, a_ubic.value_text
  FROM idn_entidad e
  JOIN idn_atributo a_stock ON ...
  WHERE e.id = <tienda_id>
    AND e.tenant_id = <tenant_de_la_tienda>;
```

### 8.5 Lo que cada tenant puede y no puede hacer

| Acción | Tenant dueño | Tenant referenciador | Tenant buscador |
|---|---|---|---|
| **Ver sus propias entidades** | ✅ Siempre | ✅ Siempre | ✅ Siempre |
| **Ver entidades de otro tenant** | ❌ | Solo si el otro marca COMPARTIDA/PUBLICA | Solo si visibilidad lo permite |
| **Modificar entidades de otro tenant** | ❌ Nunca | ❌ Nunca | ❌ Nunca |
| **Referenciar entidad de otro tenant** | — | ✅ (crea atributo con origen_tenant) | — |
| **Saber quién referencia sus entidades** | Solo visibilidad COMPARTIDA/PUBLICA | — | — |

**El ctx_id garantiza que cada tenant solo ve lo suyo. Las referencias cross-tenant**
**son posibles pero controladas por visibilidad. Por defecto, nadie sabe que existes.**

---

## 9. Resumen — el sistema de identidad puede hacerlo porque...

1. **Entidades referencian entidades** — `compatible.sistema_id = 'TOY-ILUM-CARINA'` es un atributo cuyo valor es otra entidad del sistema. Es una FK semántica en EAV.

2. **Niveles de jerarquía reutilizables** — El catálogo de Toyota y el catálogo de DEPO son `bdomain` separados bajo tenants distintos. No se tocan. Pero sus `actor` (sistemas, partes) se referencian por `entidad_id`.

3. **Búsqueda por grafo** — 3 pasos: modelo → sistemas del modelo → partes compatibles con cada sistema → filtradas por región. Tres JOINs. Con los índices correctos, <10ms.

4. **Extensible sin DDL** — Un nuevo fabricante (BOSCH, VARTA, MAGNA) solo necesita crear entidades `autoparte` con `compatible.sistema_id`. No hay que modificar nada del catálogo de Toyota ni de DEPO.

5. **Visibilidad y trazabilidad** — `value_data` JSONB almacena `origen_tenant`, `visibilidad` y `referenciado_por`. PRIVADA por defecto. COMPARTIDA para ser visible al dueño del código. Auditoría de quién usa qué.

---

## 10. Distribución autorizada y custodia de inventario

El catálogo de autopartes mostró cómo referenciar entidades entre sí (códigos, sistemas).
Ahora necesitamos dos patrones nuevos: **distribución autorizada** y **transferencia de
custodia**. Son el equivalente comercial de lo que los autos hacen con compatibilidad
técnica.

### 10.1 Caso A: Fabricante → Distribuidores autorizados → Cliente busca dónde comprar

**María fabrica mantequilla.** Solo vende al por mayor a distribuidores autorizados.
Ella hace publicidad. La gente busca "Mantequilla María". El sistema debe decirles
dónde comprarla.

```
MARÍA (productor)
  │
  └── Mantequilla María (actor, tipo=producto)
        │  origen.marca: María
        │  origen.producto: Mantequilla
        │  origen.presentacion: 500g
        │
        │  ─── DISTRIBUCIÓN AUTORIZADA ───
        │
        ├── distribuido_por: Frila X (actor, tipo=distribuidor)
        │     │  distribuidor.tipo: autorizado
        │     │  distribuidor.contrato: CON-2024-001
        │     │  distribuidor.comision: 15%
        │     │  └── ubicado_en: Calle Comercio #100, La Paz
        │     │
        ├── distribuido_por: Frila Y (actor, tipo=distribuidor)
        │     │  distribuidor.tipo: autorizado
        │     │  └── ubicado_en: Av. Central #45, Cochabamba
        │     │
        └── distribuido_por: Frila Z (actor, tipo=distribuidor)
              │  distribuidor.tipo: autorizado
              └── ubicado_en: Calle Mercado #10, Santa Cruz

CONSULTA: "¿Dónde compro Mantequilla María?"
  → Frila X (La Paz, Calle Comercio #100)
  → Frila Y (Cochabamba, Av. Central #45)
  → Frila Z (Santa Cruz, Calle Mercado #10)

María SETEA quién puede vender su producto.
Solo los distribuidores autorizados aparecen en la búsqueda.

**N-to-N:** Un mismo producto puede ser distribuido por MÚLTIPLES distribuidores.
Un mismo distribuidor puede vender MÚLTIPLES productos. María no está atada a un solo
distribuidor. Frila X no está atada a una sola productora.
```

### 10.4 El patrón N-to-N en el sistema de identidad

Cada relación es una fila en `idn_atributo`. Para modelar N-to-N, se agregan MÚLTIPLES
filas con el mismo `attr_key`. Es la ventaja del EAV sobre las columnas fijas.

```
PARTE: Farol DEPO 212-1112-L
  ├── compatible.sistema_id: TOY-ILUM-CARINA    ← fila 1
  ├── compatible.sistema_id: TOY-ILUM-COROLLA   ← fila 2
  ├── compatible.sistema_id: NIS-ILUM-SENTRA    ← fila 3
  └── compatible.sistema_id: HON-ILUM-CIVIC     ← fila 4

PARTE: Farol BOSCH B-9876-L
  ├── compatible.sistema_id: TOY-ILUM-CARINA    ← MISMO sistema, OTRO fabricante
  └── compatible.sistema_id: TOY-ILUM-COROLLA

PRODUCTO: Mantequilla María
  ├── distribuido_por: Frila X    ← fila 1
  ├── distribuido_por: Frila Y    ← fila 2
  └── distribuido_por: Frila Z    ← fila 3

PRODUCTO: Chocolate Juan
  ├── custodiado_por: Punto Norte     ← fila 1 (5 unidades)
  └── custodiado_por: Punto Centro    ← fila 2 (3 unidades)

PUNTO DE ENTREGA: Punto Norte
  ├── custodia_de: Chocolate Juan      ← mismo punto, múltiples productores
  ├── custodia_de: Mantequilla María
  └── custodia_de: Farol DEPO
```

**Si es 1, será 1. Si crece a N, solo se agregan filas. La puerta siempre está abierta.**
```

### 10.2 Caso B: Vendedor sin tienda → Puntos de entrega → Custodia transferida

**Juan vende productos pero no tiene tienda física.** Se inscribe en una red de puntos
de entrega. Cuando un cliente compra, Juan deja el producto en el punto más cercano.
El producto **pasa a formar parte del inventario del punto de entrega**. Ya no es de
Juan. Si hay devolución, regresa a Juan.

```
JUAN (productor sin tienda)
  │
  └── Chocolate Artesanal (actor, tipo=producto)
        │  origen.marca: Juan
        │  origen.producto: Chocolate Artesanal
        │  origen.lote: LOTE-2024-0715
        │
        │  ─── TRANSFERENCIA DE CUSTODIA ───
        │
        ├── ENTREGADO A: Punto Entrega Norte (actor, tipo=custodio)
        │     │  custodia.estado: EN_CUSTODIA
        │     │  custodia.fecha_entrega: 2024-07-15 10:00
        │     │  custodia.propietario_original: act-juan
        │     │  custodia.propietario_actual: Punto Entrega Norte
        │     │  custodia.comision: 10%
        │     │  custodia.stock: 5 unidades
        │     │  └── ubicado_en: Zona Norte, Calle 5 #123
        │     │
        ├── ENTREGADO A: Punto Entrega Centro (actor, tipo=custodio)
        │     │  custodia.estado: EN_CUSTODIA
        │     │  custodia.fecha_entrega: 2024-07-15 11:30
        │     │  custodia.propietario_actual: Punto Entrega Centro
        │     │  custodia.stock: 3 unidades
        │     └── ubicado_en: Zona Central, Av. Principal #500
        │
        └── VENDIDO A: Cliente María Gómez
              │  venta.fecha: 2024-07-15 14:00
              │  venta.punto_entrega: Punto Entrega Norte
              │  venta.precio: $12
              │  venta.comision_punto_entrega: $1.20 (10%)
              │
              └── custodia.estado: ENTREGADO_A_CLIENTE
                    custodia.stock: 4 unidades (de 5, queda 1)

SI HAY DEVOLUCIÓN:
  └── DEVUELTO POR: María Gómez
        devolucion.fecha: 2024-07-16
        devolucion.motivo: "No era el sabor que esperaba"
        custodia.estado: DEVUELTO_A_PRODUCTOR
        └── El producto regresa a Juan. Ya no está en custodia del punto de entrega.
```

### 10.3 Los nuevos dominios de identidad que esto requiere

| Dominio | Tipo de ente | Qué significa |
|---|---|---|
| **productor** | PERSONA, ORGANIZACION | Fabrica/elabora el producto |
| **distribuidor** | ORGANIZACION, PERSONA | Vende productos de un productor (autorizado) |
| **custodio** | ORGANIZACION, PERSONA | Recibe productos en custodia. Se vuelve propietario temporal. |
| **punto_entrega** | ORGANIZACION, PERSONA | Lugar físico donde el cliente recoge |
| **comprador** | PERSONA, ORGANIZACION | Cliente final |

### 10.5 La diferencia clave entre distribuidor y custodio

| | Distribuidor Autorizado | Custodio (Punto de Entrega) |
|---|---|---|
| **Quién pone el precio** | El distribuidor (compra al productor, revende) | El productor (el custodio cobra comisión fija) |
| **Propiedad del producto** | Del distribuidor (lo compró) | Se transfiere al custodio al recibirlo |
| **Quién responde por devoluciones** | El distribuidor | El productor (el producto devuelto regresa a él) |
| **Quién define la relación** | El productor autoriza | El productor y el custodio acuerdan |
| **Visibilidad al cliente** | "Compre en Frila X" | "Recoja en Punto Entrega Norte" |

### 10.6 La consulta que une todo

```
"Busco Mantequilla María, ¿dónde la compro?"

SELECT e.nombre AS producto,
       a_dist.value_text AS distribuidor,
       a_ubic.value_text AS direccion,
       a_precio.value_text AS precio,
       'DISTRIBUIDOR AUTORIZADO' AS tipo_venta
FROM idn_entidad e
JOIN idn_atributo a_dist ON e.id = a_dist.entidad_id
  AND a_dist.attr_key = 'distribuido_por'
JOIN idn_entidad e_dist ON a_dist.value_text = e_dist.id
JOIN idn_atributo a_ubic ON e_dist.id = a_ubic.entidad_id
  AND a_ubic.attr_key = 'direccion'
JOIN idn_atributo a_precio ON e_dist.id = a_precio.entidad_id
  AND a_precio.attr_key = 'precio_venta'
WHERE e.nombre ILIKE '%mantequilla%maria%'
  AND a_dist.value_data->>'tipo' = 'autorizado'

UNION ALL

SELECT e.nombre AS producto,
       a_cust.value_text AS punto_entrega,
       a_ubic.value_text AS direccion,
       a_precio.value_text AS precio,
       'PUNTO DE ENTREGA' AS tipo_venta
FROM idn_entidad e
JOIN idn_atributo a_cust ON e.id = a_cust.entidad_id
  AND a_cust.attr_key = 'custodia'
  AND a_cust.value_data->>'estado' = 'EN_CUSTODIA'
JOIN idn_entidad e_cust ON a_cust.value_text = e_cust.id
JOIN idn_atributo a_ubic ON e_cust.id = a_ubic.entidad_id
JOIN idn_atributo a_precio ON e.id = a_precio.entidad_id
WHERE e.nombre ILIKE '%chocolate%artesanal%'
  AND a_cust.value_data->>'visibilidad' = 'PUBLICA';
```
