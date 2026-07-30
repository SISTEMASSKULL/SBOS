# A.55 — Catálogo Automotriz: Secciones, Subsistemas y Posiciones
## Tipo A+C — Estructura jerárquica del automóvil para catalogación de autopartes

**Versión:** 1.0.0
**Fecha:** 2026-07-15
**Tipo de anexo:** A (traslado de SSOT) + C (justificación de decisión técnica)
**Respalda a:** [1.06 D00 Identidad v2.1.0 §4, §12](../1.06_MANUAL-D00-IDENTIDAD-v2.0.md) · [A.54 Catálogo de Autopartes](A.54_ANEXO-CATALOGO-AUTOPARTES-REFERENCIAS-v1.0.md)
**Normas base:** ISO 3833 (Vehicle types, terms and definitions) · UN/ECE WP.29 (vehicle regulations)

---

## §1 Propósito

Este anexo define la estructura jerárquica de un automóvil para catalogación de autopartes:
secciones principales, subsistemas dentro de cada sección, y posiciones específicas donde
se instala cada parte. Esto permite que fabricantes independientes cataloguen sus productos
con precisión quirúrgica y que los buscadores encuentren exactamente la pieza correcta.

**Cómo citarlo:** `A.55 §N`

---

## §2 La jerarquía del automóvil

```
MODELO DE AUTO (Toyota Carina 97)
  │
  ├── SECCIÓN: Motor
  │     ├── SUBSISTEMA: Admisión
  │     │     ├── POSICIÓN: filtro_aire → [DEPO: FA-CAR-001], [MANN: C-1234]
  │     │     └── POSICIÓN: multiple_admision
  │     ├── SUBSISTEMA: Inyección/Combustible
  │     │     ├── POSICIÓN: bomba_combustible → [DEPO: BC-CAR-001], [BOSCH: FP-5678]
  │     │     ├── POSICIÓN: inyectores → [DEPO: INY-CAR-001..004]
  │     │     └── POSICIÓN: filtro_combustible → [DEPO: FC-CAR-001], [MANN: WK-842]
  │     ├── SUBSISTEMA: Distribución
  │     │     ├── POSICIÓN: correa_distribucion → [GATES: T-987]
  │     │     └── POSICIÓN: tensor_correa
  │     └── SUBSISTEMA: Refrigeración
  │           ├── POSICIÓN: radiador
  │           ├── POSICIÓN: bomba_agua → [DEPO: BA-CAR-001], [GATES: WP-456]
  │           └── POSICIÓN: termostato
  │
  ├── SECCIÓN: Transmisión
  │     ├── SUBSISTEMA: Embrague
  │     │     ├── POSICIÓN: disco_embrague → [LUK: 623-ABC]
  │     │     └── POSICIÓN: collarín
  │     └── SUBSISTEMA: Caja de Cambios
  │           └── POSICIÓN: aceite_transmision → [CASTROL: ATF-DIII]
  │
  ├── SECCIÓN: Frenos
  │     ├── SUBSISTEMA: Delanteros
  │     │     ├── POSICIÓN: pastilla_del_izq → [DEPO: 212-FREN-001], [TRW: TRW-FCAR-001]
  │     │     ├── POSICIÓN: pastilla_del_der → [DEPO: 212-FREN-001]
  │     │     └── POSICIÓN: disco_freno_del → [BREMBO: BD-CAR-001]
  │     └── SUBSISTEMA: Traseros
  │           ├── POSICIÓN: pastilla_tras_izq → [DEPO: 212-FREN-002]
  │           └── POSICIÓN: pastilla_tras_der → [DEPO: 212-FREN-002]
  │
  ├── SECCIÓN: Suspensión y Dirección
  │     ├── SUBSISTEMA: Delantera
  │     │     ├── POSICIÓN: amortiguador_del → [MONROE: M-CAR-001], [KYB: K-CAR-001]
  │     │     └── POSICIÓN: rotula_direccion
  │     └── SUBSISTEMA: Trasera
  │           └── POSICIÓN: amortiguador_tras
  │
  ├── SECCIÓN: Eléctrico
  │     ├── SUBSISTEMA: Encendido
  │     │     ├── POSICIÓN: bujias → [BOSCH: FR-7DC], [NGK: BKR5E]
  │     │     └── POSICIÓN: cables_bujias → [BOSCH: CB-CAR-001]
  │     ├── SUBSISTEMA: Batería y Carga
  │     │     ├── POSICIÓN: bateria → [VARTA: V-BLUE-DIN55]
  │     │     └── POSICIÓN: alternador → [DEPO: ALT-CAR-001], [BOSCH: AL-4567]
  │     └── SUBSISTEMA: Iluminación
  │           ├── POSICIÓN: farol_del_der → [DEPO: 212-1112-L], [BOSCH: B-9876-L]
  │           ├── POSICIÓN: farol_del_izq → [DEPO: 212-1111-L]
  │           ├── POSICIÓN: luz_trasera_der → [DEPO: 212-2222-L]
  │           ├── POSICIÓN: luz_trasera_izq → [DEPO: 212-2221-L]
  │           ├── POSICIÓN: intermitente_del → [OSRAM: O-CAR-INT-D]
  │           └── POSICIÓN: luz_freno → [OSRAM: O-CAR-FRENO]
  │
  ├── SECCIÓN: Carrocería
  │     ├── SUBSISTEMA: Exterior
  │     │     ├── POSICIÓN: guardabarros_del_der → [DEPO: GB-CAR-001]
  │     │     ├── POSICIÓN: capo → [MAGNA: CAP-CAR-001]
  │     │     └── POSICIÓN: paragolpes_del → [MAGNA: PG-CAR-001]
  │     └── SUBSISTEMA: Interior
  │           ├── POSICIÓN: tablero
  │           └── POSICIÓN: asiento_conductor
  │
  └── SECCIÓN: Escape
        ├── POSICIÓN: multiple_escape
        ├── POSICIÓN: catalizador → [WALKER: CAT-CAR-001]
        └── POSICIÓN: silenciador → [WALKER: SIL-CAR-001]
```

---

## §3 El catálogo multi-fabricante

Cada POSICIÓN acepta N fabricantes. La misma pastilla de freno delantera para Carina 97
es fabricada por DEPO, TRW y BREMBO. El mismo farol por DEPO y BOSCH. Las bujías por
BOSCH y NGK. El administrador de flota elige por precio, calidad o disponibilidad.

```
BUSCADOR: "pastillas de freno delanteras para Toyota Carina 97"

  → SECCIÓN: Frenos → SUBSISTEMA: Delanteros → POSICIÓN: pastilla_del
  → DEPO 212-FREN-001   $45 (ANDINA: 20u, ORIENTE: 12u)
  → TRW TRW-FCAR-001     $52 (ANDINA: 8u)
  → BREMBO BD-CAR-001    $68 (ANDINA: 5u)

  Mismo producto. 3 fabricantes. 3 precios. Todos compatibles con Carina 97.
```

---

## §4 Compatibilidad cruzada entre modelos

Un mismo código de parte puede ser compatible con múltiples modelos. La pastilla DEPO
212-FREN-001 es compatible con Carina 92-97 Y Corolla 93-97. El farol 212-1112-L es
compatible con Carina, Corolla, Sentra y Civic.

```
PARTE: Pastilla DEPO 212-FREN-001
  ├── TOYOTA Carina   (1992-1997) → Frenos → Delanteros → pastilla_del
  ├── TOYOTA Corolla  (1993-1997) → Frenos → Delanteros → pastilla_del
  └── TOYOTA Starlet  (1994-1996) → Frenos → Delanteros → pastilla_del

PARTE: Bujía BOSCH FR-7DC
  ├── TOYOTA Carina   1.8L (1992-1997) → Eléctrico → Encendido → bujias
  ├── TOYOTA Corolla  1.6L (1993-1997) → Eléctrico → Encendido → bujias
  ├── NISSAN Sentra   1.6L (1995-1999) → Eléctrico → Encendido → bujias
  └── HONDA Civic     1.5L (1992-1995) → Eléctrico → Encendido → bujias
```

---

## §5 Cómo se modela en `idn_identity_entity`

```
t-toyota (tenant)
  └── CATÁLOGO TOYOTA (bdomain, catalogo)
        └── MODELO: Carina 92-97 (actor, modelo_auto)
              │  origen.marca: Toyota
              │  origen.modelo: Carina
              │  origen.año_inicio: 1992
              │  origen.año_fin: 1997
              │  origen.generacion: T190
              │
              ├── SECCIÓN: Frenos Carina (actor, seccion)
              │     └── SUBSISTEMA: Delanteros Carina (actor, subsistema)
              │           ├── POSICIÓN: pastilla_del (actor, posicion)
              │           │     └── compatible con: DEPO 212-FREN-001
              │           │                      TRW TRW-FCAR-001
              │           │                      BREMBO BD-CAR-001
              │           └── POSICIÓN: disco_freno_del
              │
              ├── SECCIÓN: Eléctrico Carina (actor, seccion)
              │     └── SUBSISTEMA: Iluminación Carina (actor, subsistema)
              │           ├── POSICIÓN: farol_del_der
              │           │     └── compatible con: DEPO 212-1112-L, BOSCH B-9876-L
              │           ├── POSICIÓN: farol_del_izq
              │           └── POSICIÓN: luz_trasera_der
              │
              └── SECCIÓN: Eléctrico Carina (actor, seccion)
                    └── SUBSISTEMA: Encendido Carina (actor, subsistema)
                          └── POSICIÓN: bujias
                                └── compatible con: BOSCH FR-7DC, NGK BKR5E
```

---

## §6 Fabricantes por sección

### 6.1 Faroles e Iluminación

| Fabricante | Sede | Tipo | Modelos compatibles |
|---|---|---|---|
| **DEPO** | Taiwán | OEM/Aftermarket | Toyota, Nissan, Honda, Mazda |
| **BOSCH** | Alemania | Premium OEM | Toyota, VW, BMW, Mercedes |
| **HELLA** | Alemania | Premium OEM | Toyota, VW, Audi, Porsche |
| **TYC** | Taiwán | Aftermarket | Toyota, Honda, Hyundai, Kia |
| **VALEO** | Francia | OEM | Toyota, Renault, Peugeot, Citroën |
| **STANLEY** | Japón | OEM original Toyota | Toyota, Honda, Subaru |

### 6.2 Pastillas de Freno

| Fabricante | Sede | Tipo | Modelos compatibles |
|---|---|---|---|
| **DEPO** | Taiwán | OEM/Aftermarket | Toyota, Nissan, Honda |
| **TRW** | Alemania/USA | OEM Premium | Toyota, VW, BMW, Ford, GM |
| **BREMBO** | Italia | Premium/Performance | Toyota, Ferrari, Porsche, BMW |
| **TEXTAR** | Alemania | OEM Europeo | BMW, Mercedes, VW, Audi |
| **AKEBONO** | Japón | OEM original Toyota | Toyota, Honda, Subaru, Mazda |
| **FERODO** | Reino Unido | Aftermarket | Universal |
| **BOSCH** | Alemania | Premium | Toyota, VW, Mercedes, Ford |

### 6.3 Bujías

| Fabricante | Sede | Tipo | Modelos compatibles |
|---|---|---|---|
| **NGK** | Japón | #1 mundial, OEM Toyota | Toyota, Honda, Nissan, Subaru |
| **DENSO** | Japón | OEM original Toyota | Toyota, Lexus, Honda, Suzuki |
| **BOSCH** | Alemania | Premium | Toyota, VW, BMW, Mercedes |
| **CHAMPION** | USA | Aftermarket | Universal |

### 6.4 Amortiguadores

| Fabricante | Sede | Tipo | Modelos compatibles |
|---|---|---|---|
| **KYB** | Japón | OEM Toyota/Honda/Nissan | Toyota, Honda, Nissan, Subaru, Mazda |
| **MONROE** | USA | Aftermarket líder | Universal |
| **SACHS** | Alemania (ZF) | OEM Europa | BMW, Mercedes, VW, Audi |
| **BILSTEIN** | Alemania | Premium/Performance | BMW, Mercedes, Porsche, VW |
| **KONI** | Países Bajos | Performance | Europeos, Japoneses deportivos |
| **GABRIEL** | USA | Aftermarket | Universal |
| **TOKICO** | Japón (Hitachi) | OEM Japón | Toyota, Honda, Nissan, Mitsubishi |

### 6.5 Filtros (Aire, Aceite, Combustible, Habitáculo)

| Fabricante | Sede | Tipo | Modelos compatibles |
|---|---|---|---|
| **MANN+HUMMEL** | Alemania | OEM líder mundial | Toyota, VW, BMW, Mercedes, Ford, GM |
| **MAHLE** | Alemania | OEM Europa | BMW, Mercedes, VW, Audi, Porsche |
| **BOSCH** | Alemania | Premium | Toyota, VW, Mercedes, Ford |
| **DENSO** | Japón | OEM original Toyota | Toyota, Lexus, Honda, Suzuki |
| **FRAM** | USA | Aftermarket | Universal |
| **WIX** | USA | Aftermarket/Heavy Duty | Universal, camiones, maquinaria |
| **K&N** | USA | Performance reutilizable | Universal |

### 6.6 Baterías

| Fabricante | Sede | Tipo | Modelos compatibles |
|---|---|---|---|
| **VARTA** | Alemania | Premium OEM Europa | BMW, Mercedes, VW, Audi |
| **BOSCH** | Alemania | Premium | Toyota, VW, Mercedes, Ford |
| **EXIDE** | USA | Aftermarket líder | Universal |
| **YUASA** | Japón | OEM original Toyota | Toyota, Honda, Nissan, Subaru |
| **AC DELCO** | USA | OEM GM | General Motors, Chevrolet, Cadillac |
| **OPTIMA** | USA | Premium AGM | Universal alto rendimiento |
| **ENERGIZER** | USA | Aftermarket | Universal |

### 6.7 Tabla completa de fabricantes por sección (30 fabricantes)

| Sección | Fabricantes |
|---|---|
| **Faroles e Iluminación** | DEPO, BOSCH, HELLA, TYC, VALEO, STANLEY (6) |
| **Pastillas de Freno** | DEPO, TRW, BREMBO, TEXTAR, AKEBONO, FERODO, BOSCH (7) |
| **Bujías** | NGK, DENSO, BOSCH, CHAMPION (4) |
| **Amortiguadores** | KYB, MONROE, SACHS, BILSTEIN, KONI, GABRIEL, TOKICO (7) |
| **Filtros** | MANN+HUMMEL, MAHLE, BOSCH, DENSO, FRAM, WIX, K&N (7) |
| **Baterías** | VARTA, BOSCH, EXIDE, YUASA, AC DELCO, OPTIMA, ENERGIZER (7) |
| **Motor** (bombas, correas) | GATES, CASTROL |
| **Escape** | WALKER, TENNECO, BOSAL |
| **Carrocería** | MAGNA, PLASTIC OMNIUM |

Cada fabricante opera en su propio tenant. Solo referencia las posiciones del catálogo
de Toyota. No sabe de los otros fabricantes. La tienda busca por modelo + sección +
posición y obtiene todos los fabricantes compatibles.

---

## §7 Catálogo completo — Toyota Carina 97 (precios y stock regional)

Precios en USD. Stock: ANDINA (La Paz, Cochabamba, Oruro) / ORIENTE (Santa Cruz, Beni, Pando).

### 7.1 Faroles e Iluminación

| Posición | Fabricante | Código | ANDINA | ORIENTE |
|---|---|---|---|---|
| farol_del_der | DEPO | 212-1112-L | 45u · $85 | 20u · $90 |
| farol_del_der | BOSCH | B-9876-L | 30u · $95 | 15u · $98 |
| farol_del_der | HELLA | H-CAR-FD | 12u · $120 | 8u · $125 |
| farol_del_der | TYC | TY-CAR-FD | 60u · $55 | 35u · $58 |
| farol_del_izq | DEPO | 212-1111-L | 30u · $85 | 18u · $88 |
| farol_del_izq | BOSCH | B-9875-L | 25u · $95 | 12u · $98 |
| luz_trasera_der | DEPO | 212-2222-L | 20u · $45 | 10u · $48 |
| luz_trasera_der | TYC | TY-CAR-TD | 40u · $30 | 25u · $32 |
| luz_trasera_izq | DEPO | 212-2221-L | 20u · $45 | 10u · $48 |
| intermitente_del | OSRAM | O-CAR-INT-D | 80u · $12 | 50u · $12 |

### 7.2 Pastillas de Freno

| Posición | Fabricante | Código | ANDINA | ORIENTE |
|---|---|---|---|---|
| pastilla_del | DEPO | 212-FREN-001 | 50u · $45 | 25u · $48 |
| pastilla_del | TRW | TRW-FCAR-001 | 30u · $52 | 15u · $55 |
| pastilla_del | BREMBO | BD-CAR-001 | 15u · $68 | 8u · $72 |
| pastilla_del | TEXTAR | TX-CAR-001 | 20u · $48 | 10u · $50 |
| pastilla_del | AKEBONO | AK-CAR-001 | 40u · $42 | 20u · $45 |
| pastilla_del | FERODO | FER-CAR-001 | 60u · $35 | 30u · $38 |
| pastilla_tras | DEPO | 212-FREN-002 | 35u · $38 | 20u · $40 |
| pastilla_tras | AKEBONO | AK-CAR-002 | 25u · $36 | 15u · $38 |
| disco_freno_del | BREMBO | BD-CAR-D001 | 10u · $95 | 5u · $98 |
| disco_freno_del | TRW | TRW-FCAR-D01 | 20u · $78 | 12u · $80 |

### 7.3 Bujías

| Posición | Fabricante | Código | ANDINA | ORIENTE |
|---|---|---|---|---|
| bujia (x4) | NGK | BKR5E | 200u · $18 | 120u · $18 |
| bujia (x4) | DENSO | K16R-U | 150u · $16 | 100u · $16 |
| bujia (x4) | BOSCH | FR-7DC | 100u · $20 | 60u · $20 |
| bujia (x4) | CHAMPION | RC12YC | 250u · $12 | 150u · $12 |

### 7.4 Amortiguadores

| Posición | Fabricante | Código | ANDINA | ORIENTE |
|---|---|---|---|---|
| amortiguador_del | KYB | KYB-CAR-D001 | 25u · $95 | 15u · $98 |
| amortiguador_del | MONROE | MON-CAR-D001 | 40u · $72 | 20u · $75 |
| amortiguador_del | SACHS | SAC-CAR-D001 | 15u · $110 | 8u · $115 |
| amortiguador_del | BILSTEIN | BIL-CAR-D001 | 10u · $145 | 5u · $150 |
| amortiguador_tras | KYB | KYB-CAR-T001 | 20u · $85 | 12u · $88 |
| amortiguador_tras | MONROE | MON-CAR-T001 | 35u · $65 | 20u · $68 |
| amortiguador_tras | GABRIEL | GAB-CAR-T001 | 50u · $55 | 30u · $58 |

### 7.5 Filtros

| Posición | Fabricante | Código | ANDINA | ORIENTE |
|---|---|---|---|---|
| filtro_aceite | MANN | W-610/80 | 120u · $15 | 80u · $16 |
| filtro_aceite | MAHLE | OC-295 | 90u · $14 | 60u · $15 |
| filtro_aceite | BOSCH | F-0264-070 | 70u · $18 | 45u · $20 |
| filtro_aceite | DENSO | DEN-CAR-001 | 100u · $12 | 70u · $12 |
| filtro_aceite | FRAM | PH-3593A | 200u · $8 | 150u · $9 |
| filtro_aire | MANN | C-2365 | 90u · $22 | 60u · $24 |
| filtro_aire | MAHLE | LX-872 | 70u · $20 | 50u · $22 |
| filtro_aire | K&N | 33-2036 | 30u · $55 | 20u · $58 |
| filtro_combustible | MANN | WK-842 | 80u · $18 | 55u · $20 |
| filtro_combustible | BOSCH | F-0264-020 | 60u · $22 | 40u · $24 |
| filtro_habitaculo | MANN | CUK-26005 | 60u · $25 | 40u · $28 |

### 7.6 Baterías

| Posición | Fabricante | Código | ANDINA | ORIENTE |
|---|---|---|---|---|
| bateria | VARTA | V-BLUE-DIN55 | 30u · $120 | 20u · $125 |
| bateria | BOSCH | S4-055 | 25u · $115 | 15u · $120 |
| bateria | YUASA | YBX-3055 | 40u · $105 | 25u · $108 |
| bateria | EXIDE | EX-CAR-055 | 50u · $95 | 30u · $98 |

### 7.7 Total del catálogo Carina 97

| Sección | Posiciones | Fabricantes | Productos | Precio range |
|---|---|---|---|---|
| Iluminación | 5 | DEPO, BOSCH, HELLA, TYC, OSRAM | 10 | $12 - $125 |
| Frenos | 3 | DEPO, TRW, BREMBO, TEXTAR, AKEBONO, FERODO | 10 | $35 - $98 |
| Bujías | 1 | NGK, DENSO, BOSCH, CHAMPION | 4 | $12 - $20 |
| Amortiguadores | 2 | KYB, MONROE, SACHS, BILSTEIN, GABRIEL | 7 | $55 - $150 |
| Filtros | 4 | MANN, MAHLE, BOSCH, DENSO, FRAM, K&N | 11 | $8 - $58 |
| Baterías | 1 | VARTA, BOSCH, YUASA, EXIDE | 4 | $95 - $125 |
| **TOTAL** | **16** | **21 fabricantes** | **46 productos** | **$8 - $150** |

---

## §8 Compatibilidad cruzada entre marcas

Muchas partes son compatibles con múltiples modelos de auto, incluso de diferentes marcas.
Esto es posible porque los fabricantes de autopartes estandarizan dimensiones y conectores.

### 8.1 Partes compatibles con Toyota Carina 97 Y otros modelos

| Parte | Código | Compatible con |
|---|---|---|
| Farol DEPO | 212-1112-L | Toyota Carina 92-97, Toyota Corolla 93-97, Nissan Sentra 95-99, Honda Civic 92-95 |
| Pastilla DEPO | 212-FREN-001 | Toyota Carina 92-97, Toyota Corolla 93-97, Toyota Starlet 94-96, Daihatsu Charade 93-98 |
| Bujía NGK | BKR5E | Toyota Carina, Corolla, Starlet; Honda Civic, Accord; Nissan Sentra, Primera; Mazda 323, 626 |
| Filtro aceite MANN | W-610/80 | Toyota Carina, Corolla, Celica, MR2; Lexus ES300; Geo Prizm |
| Amortiguador KYB | KYB-CAR-D001 | Toyota Carina 92-97, Toyota Corolla 93-97, Toyota Celica 94-99 |
| Batería VARTA | V-BLUE-DIN55 | Universal DIN55 — 200+ modelos de 15 marcas |

### 8.2 El efecto red

```
Bujía NGK BKR5E:

  TOYOTA:  Carina 92-97, Corolla 93-97, Starlet 94-96, Celica 94-99
  HONDA:   Civic 92-95, Accord 94-97, CR-V 97-99
  NISSAN:  Sentra 95-99, Primera 96-99, Almera 95-98
  MAZDA:   323 94-98, 626 93-97, MX-5 94-99
  MITSUBISHI: Lancer 93-96, Galant 94-98
  DAIHATSU: Charade 93-98, Applause 94-97

Una sola bujía. 6 marcas de auto. 19 modelos. NGK la fabrica UNA VEZ.
Los 19 catálogos de las 6 marcas la referencian. La tienda que vende para
Carina automáticamente también vende para Civic, Sentra y 323.

Sin saberlo. Sin configurarlo. Porque NGK declaró la compatibilidad y los
sistemas de los autos la heredan.
```

---

## §9 Cómo escala esto

- 30 fabricantes × 8 secciones × 40+ posiciones = **~1,200 productos** solo para Carina 97
- 19 modelos de auto × 1,200 productos = **~22,800 referencias** en un ecosistema de 6 marcas
- Agregar Nissan (5 modelos), Honda (4), Mazda (3) → **~50,000 referencias**
- Todo en 2 tablas (`idn_identity_entity` + `idn_identity_attribute`). Sin tablas pivote. Sin DDL.

Cada nuevo fabricante solo necesita INSERT. Cada nuevo modelo solo necesita INSERT.
El grafo de compatibilidad crece solo. La tienda busca por cualquier modelo y obtiene
todas las partes de todos los fabricantes.

---

## §10 Preservación de la historia en autopartes

Cada parte tiene su propio ciclo de vida. Se fabrica, se vende, se instala, se reemplaza.
La historia completa se preserva. Nada se borra.

### 10.1 Farol DEPO 212-1112-L — 12 años de historia

```
2012-03-10  FABRICACIÓN
  ┌─ origen: ACTIVO
      fabricante: DEPO Taiwan · lote: L2012-0310-045 · cantidad: 500u
      norma: ECE R112 · material: policarbonato + ABS

2012-04-15  IMPORTACIÓN A BOLIVIA
  ┌─ comercial: ACTIVO
      importador: DEPO Bolivia SA · lote: IMP-2012-0415
      precio_importacion: $42/u · arancel: 10%

2012-05-01  DISTRIBUCIÓN A ANDINA
  ┌─ comercial: stock ANDINA +45u · precio_venta: $85
  └─ comercial: stock ORIENTE +20u · precio_venta: $90

2013-02-20  VENTA #1 — UNIDAD SERIE DEPO-2012-034
  ├─ comercial: vendido a Taller Mecánico "El Rápido" · $85
  │   instalado en Toyota Carina 97 de María Gómez (placa ABC-1234)
  ├─ propiedad: María Gómez → ACTIVO
  └─ stock ANDINA: 45u → 44u

2015-09-01  VENTA DEL AUTO — María vende el Carina a Pedro Flores
  ├─ propiedad: María Gómez (2013-2015) → ARCHIVADO (historia preservada)
  └─ propiedad: Pedro Flores → ACTIVO
      el farol sigue instalado en el auto. Mismo farol, nuevo dueño.

2018-01-10  REEMPLAZO POR CHOQUE
  ├─ propiedad: Pedro Flores → ARCHIVADO (farol dañado en choque, reemplazado)
  └─ operativo: estado → DADO_DE_BAJA · causa: choque · fecha: 2018-01-10
      El farol original DEPO fue retirado. Se instaló un farol BOSCH B-9876-L.

2018-01-12  NUEVO FAROL INSTALADO
  ┌─ Farol BOSCH B-9876-L · vendido por Tiendita Barrio · $95
  └─ propiedad: Pedro Flores → ACTIVO

2020-03-20  ROBO DEL AUTO
  ├─ propiedad: Pedro Flores → ARCHIVADO
  └─ siniestrado: ACTIVO · tipo: robo · denuncia: DEN-2020-0320
      El auto fue robado con el farol BOSCH instalado.
      Seguro cubre. Auto no recuperado.

RESUMEN DEL FAROL DEPO 212-1112-L:
  2012: fabricado en Taiwán (500u)
  2012-2024: 12 años en catálogo
  44u vendidas a talleres y tiendas (ARCHIVADO)
  1u instalada en Carina de María (2013-2015, ARCHIVADO)
  1u dañada en choque (2018, DADO_DE_BAJA)
  Todas las unidades tienen trazabilidad completa.
```

### 10.2 Pastilla TRW TRW-FCAR-001 — múltiples instalaciones

```
2014-06-01  FABRICACIÓN (lote L2014-0601, 2,000u)
2014-08-15  IMPORTACIÓN a Bolivia (1,000u para ANDINA, 500u para ORIENTE)
2015-01-10  Venta #1: Taller "Frenos Bolivia" instala en Carina de taxi (placa TAX-456)
2016-03-20  Venta #2: Tiendita Barrio vende a Pedro para su Carina (placa ABC-1234)
2017-11-05  Venta #3: Concesionario Toyota instala en Corolla 95 (placa COR-789)
2019-06-15  Lote L2014-0601 AGOTADO. Nuevo lote L2019-0615 (1,500u)
2020-01-10  Taxi TAX-456: pastilla reemplazada a los 80,000 km → ARCHIVADO
            Nueva pastilla TRW instalada (del lote L2019-0615)
2022-03-15  Auto ABC-1234 (Pedro): pastilla desgastada → reemplazada → ARCHIVADO

HISTORIAL DE LA PASTILLA TRW TRW-FCAR-001:
  - 2 lotes fabricados (2014: 2,000u, 2019: 1,500u)
  - 3,500 unidades con trazabilidad individual
  - Cada instalación registrada (auto, dueño, fecha, kilometraje)
  - Cada reemplazo ARCHIVADO con motivo
  - 12 años de historia. NADA borrado.
```

### 10.3 Bujía NGK BKR5E — el producto más longevo

```
2008-03-01  CATALOGADO para Toyota Carina 92-97
2010-06-15  CATALOGADO para Honda Civic 92-95 (compatibilidad agregada por NGK Japón)
2012-01-20  CATALOGADO para Nissan Sentra 95-99
2015-09-01  CATALOGADO para Mazda 323 94-98
2018-03-10  CATALOGADO para Mitsubishi Lancer 93-96
2020-01-01  Total acumulado: 6 marcas, 19 modelos, 200+ unidades vendidas en Bolivia
2024-06-01  NGK Japón anuncia NUEVO MODELO BKR6E (evolución). BKR5E sigue en catálogo.

HISTORIAL DE LA BUJÍA NGK BKR5E:
  2008-2024: 16 años en catálogo
  6 marcas de auto, 19 modelos
  4 expansiones de compatibilidad (cada una ARCHIVADA con fecha y origen)
  El producto original NUNCA se elimina. La nueva versión se agrega.
```

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-15 | Primera edición. 8 secciones, 20 subsistemas, 40+ posiciones. Multi-fabricante. Compatibilidad cruzada entre modelos. |
