# Tipos de Identidad y Dominios de Identidad — Motor de Identidad

## El mismo patrón del RolTemplate: entidad base + capas de dominio

**Versión:** 1.0
**Fecha:** 2026-07-14

---

## 1. El patrón

```
ROL TEMPLATE                              MOTOR DE IDENTIDAD
────────────                              ──────────────────

Entidad: rol (idn_role_template)          Entidad: ente (idn_entidad)
  │                                         │
  ├── Dominios = planos de control          ├── Dominios = capas de atributos
  │   D1: qué puede acceder                  │   civil: quién es
  │   D3: cuánto puede mover                 │   laboral: dónde trabaja
  │   D4: cuándo puede operar                │   autenticacion: cómo accede
  │   D6: desde dónde puede                  │   comercial: qué compra/vende
  │   D00: qué atributos gobierna            │   salud: qué condiciones tiene
  │                                          │
  ├── Las capas se agregan/quitan            ├── Las capas se agregan/quitan
  ├── El rol no muere, se desactiva          ├── El ente no muere, se desactiva
  └── Cada capa = átomos en privilege_atom   └── Cada capa = atributos en idn_atributo
```

**Es el mismo paradigma.** Cambia lo que se almacena (átomos vs atributos) y quién lo
evalúa (BitMask vs Motor de Identidad). Pero la estructura es idéntica.

---

## 2. Los 8 tipos base de identidad (lo que algo ES)

Un `tipo` en `idn_entidad` define la naturaleza fundamental del ente. Es inmutable.
No cambia durante el ciclo de vida. Es el equivalente al `account_type` en el UserTemplate.

| Tipo | Qué es | Ejemplos | ¿Tiene capa civil? | ¿Tiene capa laboral? |
|---|---|---|---|---|
| **PERSONA** | Ser humano | Juan Pérez, María Gómez | Sí (nombre, CI, nacimiento) | Sí (employee_code, cargo) |
| **ORGANIZACION** | Entidad legal colectiva | SKULL SRL, DEPO SA | Sí (NIT, razón social, registro) | No (no es empleado) |
| **DISPOSITIVO** | Máquina con electrónica | Servidor HP, Sensor IoT, Cámara | No (tiene serial, no CI) | No |
| **SERVICIO** | Proceso automatizado | SAP-BOT, Agente-Monitoreo | No | No |
| **VEHICULO** | Medio de transporte motorizado | Camión Volvo, Camioneta Toyota | No (tiene placa, no CI) | No |
| **INMUEBLE** | Bien raíz | Edificio Torre, Casa-Juan | No (tiene dirección, no CI) | No |
| **PRODUCTO** | Bien de consumo/venta | Laptop Dell, Cereal Maíz | No (tiene SKU, no CI) | No |
| **ANIMAL** | Ser vivo no humano | Vaca, Perro guardián | Sí (registro, chip) | No |

**Cada tipo define qué dominios de capa son válidos para ese ente.** Una PERSONA puede
tener capa laboral. Un DISPOSITIVO no. Un VEHICULO puede tener capa de flota. Un PRODUCTO
puede tener capa de inventario. Esto es gobernado por D93.

---

## 3. Los 37 dominios de identidad (las capas que se agregan/quitan)

Un `dominio_origen` en `idn_atributo` identifica qué capa agregó cada atributo. Los
dominios son independientes entre sí. Se agregan y se quitan durante el ciclo de vida.
Son el equivalente a los planos de control D1-D13 en el RolTemplate, y a los **BP Roles**
de SAP S/4HANA o los **Partner Types** de Odoo.

### 3.1 Lo que la industria ya resolvió: el Partner Unificado

Tanto SAP como Odoo usan un modelo donde UNA entidad puede tener MÚLTIPLES roles
simultáneamente. No se duplica. No se crean registros separados.

| Sistema | Objeto unificado | Cómo maneja múltiples roles |
|---|---|---|
| **SAP S/4HANA** | Business Partner (BP) | BP Roles: Customer, Supplier, Prospect, Employee, Contact Person. Un BP puede tener TODOS a la vez. |
| **Odoo** | res.partner | Contact Type + Tags. is_customer + is_vendor. Un partner puede ser cliente y proveedor. |
| **ISO 9001:2015** | Interested Party (§3.2.3) | Customer (§3.2.4), Provider (§3.2.5), External Provider (§3.2.6). Una organización puede ser las tres. |

### 3.2 Dominios para PERSONA (16)

| Código | Dominio | Qué significa | Atributos clave | Compatible con |
|---|---|---|---|---|
| D00-ID01 | **civil** | Existencia legal. Base inmutable. | nombre, CI, birth_date, nationality, gender, estado_civil, dependientes[] | — (siempre activo) |
| D00-ID02 | **familiar** | Relaciones de parentesco. | marital_status, conyuge, dependientes[], regimen_patrimonial | civil |
| D00-ID03 | **educativo** | Formación académica. | matricula, carrera, titulo, institucion, fechas | civil |
| D00-ID04 | **laboral** | Relación de trabajo dependiente. | employee_code, cargo, salary, empresa, sucursal, fechas | civil, autenticacion |
| D00-ID05 | **autenticacion** | Acceso a sistemas. | username, MFA, account_status, sistema, fechas | civil, laboral |
| D00-ID06 | **cliente** | Compra productos/servicios. | customer_since, credit_limit, payment_method, categoria | civil |
| D00-ID07 | **proveedor** | Vende productos/servicios. | categoria_proveedor, servicios[], factura_a, NIT | civil, fiscal |
| D00-ID08 | **productor** | Fabrica/elabora bienes. | tipo_producto, volumen, certificacion_sanitaria | civil, proveedor, fiscal |
| D00-ID09 | **independiente** | Dueño de negocio propio. | razon_social, NIT, fecha_apertura, rubro | civil, fiscal, proveedor |
| D00-ID10 | **propietario** | Dueño de activos. | bien, escritura, valor, fecha_adquisicion | civil |
| D00-ID11 | **inquilino** | Alquila un inmueble. | direccion, canon, propietario, fechas | civil |
| D00-ID12 | **paciente** | Recibe atención médica. | historia_clinica, diagnostico, medico, hospital, fechas | civil |
| D00-ID13 | **fiscal** | Obligaciones tributarias. | NIT, regimen, obligaciones, ultima_declaracion | civil, laboral, proveedor |
| D00-ID14 | **financiero** | Productos bancarios. | banco, tipo_producto, saldo, fechas | civil, laboral |
| D00-ID15 | **viajero** | Desplazamientos. | destino, motivo, fechas, documento_viaje | civil |
| D00-ID16 | **asegurado** | Cobertura de seguros. | aseguradora, poliza, cobertura, vigencia | civil, propiedad |

### 3.3 Dominios para ORGANIZACION (13)

| Código | Dominio | Qué significa | Atributos clave |
|---|---|---|---|
| D00-ID17 | **civil** | Constitución legal. | razon_social, NIT, fecha_constitucion, tipo_societario |
| D00-ID18 | **cliente** | Compra insumos/productos. | customer_since, credit_limit, payment_terms |
| D00-ID19 | **proveedor** | Vende productos/servicios. | categoria, servicios[], condiciones_pago |
| D00-ID20 | **productor** | Fabrica bienes. | tipo_industria, capacidad, certificaciones |
| D00-ID21 | **empleador** | Contrata personal. | n_empleados, convenio, sindicato |
| D00-ID22 | **fiscal** | Obligaciones tributarias. | NIT, regimen, obligaciones, ultima_declaracion |
| D00-ID23 | **propietario** | Dueña de activos. | bien, escritura, valor, fecha_adquisicion |
| D00-ID24 | **inquilino** | Alquila inmuebles. | direccion, canon, propietario, fechas |
| D00-ID25 | **importador** | Trae bienes del exterior. | pais_origen, regimen_aduana, agente_despachante |
| D00-ID26 | **exportador** | Envía bienes al exterior. | pais_destino, regimen_exportacion, certificado_origen |
| D00-ID27 | **franquiciado** | Opera bajo marca de otro. | franquiciante, contrato, regalias, territorio |
| D00-ID28 | **franquiciante** | Otorga franquicias. | franquiciados[], modelo_negocio, manual_operativo |
| D00-ID29 | **financiero** | Productos bancarios. | banco, tipo_producto, saldo, condiciones |

### 3.4 Dominios para COSAS (8)

| Código | Dominio | Qué significa | Atributos clave |
|---|---|---|---|
| D00-ID30 | **origen** | Fabricación/creación. Atributos de nacimiento. | marca, modelo, serial, fecha_fabricacion |
| D00-ID31 | **comercial** | En venta. | precio, color, garantia, stock, vendedor |
| D00-ID32 | **propiedad** | Dueño actual. | dueño, placa, escritura, fecha_adquisicion, valor |
| D00-ID33 | **alquilado** | En leasing/renta. | arrendador, canon, contrato, vigencia |
| D00-ID34 | **operativo** | En uso/mantenimiento. | ultimo_mantenimiento, km_actual, estado, responsable |
| D00-ID35 | **asegurado** | Cobertura de seguro. | aseguradora, poliza, cobertura, vigencia |
| D00-ID36 | **siniestrado** | Dañado/robado. | fecha_siniestro, tipo, denuncia, recuperado_por |
| D00-ID37 | **desactivado** | Fuera de servicio. | fecha_baja, motivo, partes_recicladas |

### 3.5 Ejemplo: DEPO Bolivia — 6 dominios simultáneos

```
DEPO BOLIVIA (bdomain, ORGANIZACION)

  civil:        razon_social: DEPO Bolivia SA, NIT: 98765432109876 (2005)
  cliente:      compra repuestos de Toyota Japón (importador)
  proveedor:    vende repuestos a talleres mecánicos
  productor:    FÁBRICA PROPIA (desde 2018) — fabrica repuestos
  empleador:    30 empleados
  propietario:  dueña del edificio de la fábrica y local comercial
  financiero:   crédito empresarial en Banco Nacional

DEPO es cliente + proveedor + productor + empleador + propietario.
6 dominios activos. Una entidad. Sin duplicación.
```

### 3.6 Ejemplo: Juan Pérez en su momento más complejo (2019)

```
JUAN PÉREZ (actor, PERSONA)

  civil:        VIVO. CI: 1234567 LP. Casado con Laura. 2 hijos.
  laboral:      EMPLEADO en TECNOLOGÍA AVANZADA SA (Vendedor Senior, $7500)
  autenticacion: login: juan.perez@tecav.com (ACTIVE)
  cliente:      compra en la tienda interna de TECNOLOGÍA AVANZADA
  proveedor:    JUANPÉREZ CONSULTORÍAS factura a SKULL-CORP ($500/mes)
  productor:    produce pastelitos → vende a TECNOLOGÍA AVANZADA (servicio de té)
  propietario:  dueño de su casa (Calle Las Flores #45) y su auto (Toyota Carina 97)
  fiscal:       NIT persona natural 1234567014. Declara IVA trimestral.

Juan es EMPLEADO de TECNOLOGÍA y al mismo tiempo PROVEEDOR de TECNOLOGÍA.
Es legal. SAP y Odoo lo permiten. ISO 9001 lo contempla.
8 dominios activos simultáneos. Una entidad. Cero duplicación.
```

---

## 4. Cómo se ve en la práctica

### 4.1 Juan Pérez (PERSONA) — 45 años, 8 dominios, 60+ atributos

Cada dominio no es una lista plana de atributos. Es una **bitácora temporal** con
múltiples instancias, cada una con fechas, estados, y contexto. Juan no "tiene un
trabajo" — ha tenido 3 trabajos en 15 años. No "vive en una dirección" — ha vivido
en 4 direcciones. No "tiene una CI" — ha tenido 3 documentos de identidad.

```
idn_entidad (act-jperez, tipo=PERSONA)

┌─ DOMINIO: civil ─────────────────────────────────────────────┐
│                                                               │
│  nombre / given_name     → Juan                               │
│  nombre / family_name    → Pérez                              │
│  nombre / second_family  → Gómez (materno)                    │
│  birth_date              → 1985-06-15                         │
│  gender                  → M                                  │
│  nationality             → BOL                                │
│                                                               │
│  estado_civil:                                                │
│    SOLTERO      → 1985-06-15 a 2012-11-19                     │
│    CASADO        → 2012-11-20 a hoy (cónyuge: Laura Flores)   │
│                                                               │
│  documentos_identidad:                                        │
│    CI 1234567 LP    → emitido 2004-03-10, vence 2014-03-10    │
│    CI 1234567 LP    → emitido 2014-02-20, vence 2024-02-20    │
│    Pasaporte B7654321 → emitido 2018-06-01, vence 2028-06-01 │
│                                                               │
│  dependientes:                                                │
│    Mateo Pérez Flores → nacido 2014-05-10, parentesco: hijo   │
│    Sofía Pérez Flores → nacida 2017-11-03, parentesco: hija   │
│                                                               │
│  defunción:                                                   │
│    fecha: 2030-01-10, causa: infarto, certificado: DEF-2030-…│
└───────────────────────────────────────────────────────────────┘

┌─ DOMINIO: laboral ───────────────────────────────────────────┐
│                                                               │
│  empleo #1 (SKULL-CORP, 2010-2015):                           │
│    cargo: Vendedor Junior                                     │
│    employee_code: VEN-2010-003                                │
│    sucursal: Norte                                            │
│    salary: 4500 → 5200 (2012) → 5800 (2014)                   │
│    manager: María Gómez                                       │
│    motivo_salida: renuncia (mejor oferta)                      │
│                                                               │
│  empleo #2 (TECNOLOGÍA AVANZADA SA, 2015-2020):               │
│    cargo: Vendedor Senior                                     │
│    employee_code: TEC-2015-017                                │
│    sucursal: Central                                          │
│    salary: 7000 → 7500 (2017) → 8200 (2019)                   │
│    logros: "Top Seller 2017", "Mejor Vendedor Regional 2019"  │
│    motivo_salida: reestructuración (despido)                   │
│                                                               │
│  empleo #3 (COMERCIAL BOLIVIA SA, 2020-2023):                 │
│    cargo: Jefe de Ventas                                      │
│    employee_code: COM-2020-009                                │
│    sucursal: Sur                                              │
│    salary: 9000                                               │
│    equipo: 4 vendedores a cargo                               │
│    motivo_salida: cierre de la empresa                        │
│                                                               │
│  empleo actual: DESEMPLEADO (desde 2023)                      │
│    subsidio: 3000/mes (6 meses)                               │
│                                                               │
│  consultoría paralela:                                         │
│    JUANPÉREZ CONSULTORÍAS (2020-2030)                          │
│    clientes: SKULL-CORP, TECNOLOGÍA SA, varios                │
│    servicios: capacitación en ventas, asesoría comercial       │
└───────────────────────────────────────────────────────────────┘

┌─ DOMINIO: autenticacion ─────────────────────────────────────┐
│                                                               │
│  cuenta #1 (SKULL-CORP, 2010-2015):                           │
│    username: jperez@skull.com                                 │
│    MFA: TOTP (enrolado 2010-06-02)                            │
│    estado: REVOCADO (2015-03-15, motivo: renuncia)            │
│                                                               │
│  cuenta #2 (TECNOLOGÍA AVANZADA, 2015-2020):                  │
│    username: juan.perez@tecav.com                             │
│    MFA: TOTP (enrolado 2015-04-01)                            │
│    estado: REVOCADO (2020-01-10, motivo: despido)             │
│                                                               │
│  cuenta #3 (COMERCIAL BOLIVIA SA, 2020-2023):                 │
│    username: jperez@comercialbo.com                           │
│    MFA: TOTP + WebAuthn (enrolado 2020-02-15)                 │
│    estado: REVOCADO (2023-06-30, motivo: cierre empresa)      │
│                                                               │
│  cuenta personal (siempre activa):                             │
│    email: jperez@gmail.com                                    │
│    MFA: TOTP + Recovery Codes                                 │
│    estado: ACTIVE                                             │
└───────────────────────────────────────────────────────────────┘

┌─ DOMINIO: salud ─────────────────────────────────────────────┐
│                                                               │
│  hospitalización #1 (Hospital La Paz, 2018-08-12 al 15):     │
│    motivo: apendicitis aguda                                  │
│    médico: Dr. Ramírez                                        │
│    procedimiento: apendicectomía                              │
│    alta: 2018-08-15, sin complicaciones                       │
│                                                               │
│  hospitalización #2 (Clínica Norte, 2019-03-20 al 22):        │
│    motivo: fractura de tobillo (accidente laboral)            │
│    médico: Dra. López                                         │
│    tratamiento: inmovilización + fisioterapia 6 meses         │
│                                                               │
│  consultas externas:                                          │
│    2016-05-10: Dr. Martínez (dermatólogo) — revisión lunar    │
│    2020-11-05: Dra. Flores (cardiólogo) — chequeo preventivo  │
│    2022-09-15: Dr. Rojas (oftalmólogo) — lentes nuevos        │
│                                                               │
│  vacunas:                                                     │
│    COVID-19 (3 dosis: 2021-03, 2021-06, 2022-01)             │
│    Influenza (anual: 2020, 2021, 2022, 2023, 2024)            │
│    Fiebre Amarilla (2019)                                     │
│                                                               │
│  condiciones crónicas:                                        │
│    alergia: penicilina (descubierta en 2018)                  │
│    grupo sanguíneo: O+                                         │
└───────────────────────────────────────────────────────────────┘

┌─ DOMINIO: ubicacion ─────────────────────────────────────────┐
│                                                               │
│  dirección #1 (casa padres, 1985-2010):                       │
│    Calle Los Pinos #12, La Paz                                │
│    tipo: familiar, estado: inactivo                            │
│                                                               │
│  dirección #2 (departamento alquilado, 2010-2015):             │
│    Av. Comercio #456, Depto 3B, La Paz                        │
│    tipo: alquiler, canon: $300/mes                            │
│    coordenadas: -16.4950, -68.1200                            │
│                                                               │
│  dirección #3 (casa propia, 2015-2030):                       │
│    Calle Las Flores #45, La Paz                               │
│    tipo: propia, escritura: ESC-2015-001                      │
│    coordenadas: -16.5000, -68.1193                            │
│    valor_catastral: $85,000                                   │
│                                                               │
│  viajes internacionales:                                       │
│    2018-07: Buenos Aires, Argentina (turismo, 7 días)         │
│    2019-12: Lima, Perú (congreso ventas, 4 días)              │
│    2022-03: São Paulo, Brasil (capacitación, 5 días)          │
└───────────────────────────────────────────────────────────────┘
```

### 4.2 Esto es lo que `idn_atributo` necesita soportar

Cada atributo no es un valor puntual. Es una **entrada temporal** con:
- `valid_from` / `valid_until` — rango de vigencia
- `estado` — ACTIVE, INACTIVE, ARCHIVED
- `contexto` — información adicional (empresa, hospital, motivo)
- Múltiples instancias del mismo `attr_key` para la misma entidad

```
idn_atributo para act-jperez, dominio=laboral, attr_key=empleo:

  { desde: 2010-06-01, hasta: 2015-03-15, empresa: SKULL-CORP,
    cargo: Vendedor Junior, salary: 4500, estado: ARCHIVADO }

  { desde: 2015-04-01, hasta: 2020-01-10, empresa: TECNOLOGÍA AVANZADA,
    cargo: Vendedor Senior, salary: 7000, estado: ARCHIVADO }

  { desde: 2020-02-15, hasta: 2023-06-30, empresa: COMERCIAL BOLIVIA SA,
    cargo: Jefe de Ventas, salary: 9000, estado: ARCHIVADO }
```

### 4.2 Servidor HP ProLiant (DISPOSITIVO)

```
idn_entidad (act-servidor-001, tipo=DISPOSITIVO)

  operativo    → marca: HP, modelo: DL380 Gen11, serial: HPP-SRV-001
  autenticacion→ ip: 10.0.0.50, cert: sk-server-001, M2M: API_KEY
  ubicacion    → datacenter: Torre-Central, rack: RACK-A-01, sala: Sala-Servidores
  propiedad    → adquirido: 2024-01-15, valor: $15,000, propietario: SKULL-CORP

  4 dominios activos. 10 atributos. Una entidad.
```

### 4.3 Camión Volvo (VEHICULO)

```
idn_entidad (act-camion-001, tipo=VEHICULO)

  operativo    → marca: Volvo, modelo: FH 540, año: 2024
  propiedad    → placa: ABC-1234, dueño: SKULL-CORP, seguro: SegSA
  fiscal       → avalúo: $80,000, impuesto_anual: $1,200
  ubicacion    → estacionamiento: Patio-Central, gps: -16.5001,-68.1194
  comercial    → leasing: Banco X, cuota_mensual: $2,500, vencimiento: 2028

  5 dominios activos. 14 atributos. Una entidad.
```

---

## 5. Los dominios son conjuntos (USERSET en D94)

Cada dominio es un USERSET. Una entidad pertenece al conjunto mientras tiene la capa activa:

```
Juan Pérez ∈ USERSET(civil)           ← siempre
Juan Pérez ∈ USERSET(autenticacion)   ← mientras tiene login activo
Juan Pérez ∈ USERSET(laboral)         ← mientras está empleado
Juan Pérez ∈ USERSET(salud)           ← mientras está internado
Juan Pérez ∉ USERSET(comercial)       ← nunca fue cliente (no aplica)

Servidor HP ∈ USERSET(operativo)      ← siempre
Servidor HP ∈ USERSET(autenticacion)  ← siempre (M2M)
Servidor HP ∉ USERSET(laboral)        ← un dispositivo no es empleado
```

D93 gobierna qué tipos de ente pueden pertenecer a cada USERSET:
- `PERSONA` → [civil, laboral, autenticacion, comercial, educativo, salud, fiscal, ubicacion]
- `DISPOSITIVO` → [operativo, autenticacion, ubicacion, propiedad]
- `VEHICULO` → [operativo, propiedad, fiscal, ubicacion, comercial]
- `PRODUCTO` → [operativo, comercial, ubicacion]
- `INMUEBLE` → [propiedad, fiscal, ubicacion, operativo]

---

## 6. Los tres tipos de atributos en el ciclo de vida

### 6.1 Atributos de nacimiento (inmutables)

Los que la entidad recibe al ser creada. Vienen de su "fábrica" u origen. **Nunca cambian.**
Son la identidad base del ente.

| Tipo de ente | Atributos de nacimiento |
|---|---|
| PERSONA | given_name, family_name, birth_date, gender, lugar_nacimiento |
| ORGANIZACION | razon_social, fecha_constitucion, tipo_societario, pais_origen |
| VEHICULO | marca, modelo, año, motor, chasis, vin |
| DISPOSITIVO | marca, modelo, serial, fecha_fabricacion |
| PRODUCTO | marca, modelo, SKU, lote, fecha_produccion |

### 6.2 Atributos de capa (se agregan/quitan, historia preservada)

Cada dominio agrega atributos cuando la entidad entra en él. Al salir, los atributos
cambian de estado a ARCHIVADO pero **no se eliminan**. La historia completa se preserva.

```
Juan Pérez — dominio laboral:
  SKULL-CORP (2010-2015, ARCHIVADO)
  TECNOLOGÍA AVANZADA (2015-2020, ARCHIVADO)
  COMERCIAL BOLIVIA (2020-2023, ARCHIVADO)
  JUANPÉREZ CONSULTORÍAS (2020-2030, ACTIVO)

Toyota Carina 97 — dominio propiedad:
  CONCESIONARIO (1997-2010, ARCHIVADO)
  María Gómez (2010-2015, ARCHIVADO)
  Pedro Flores (2015-2018, ARCHIVADO)
  Marcos Rojas (2018-2020, ARCHIVADO)
  ROBO → SINIESTRADO (2020-2021, ARCHIVADO)
  DESGUACE (2021, DADO_DE_BAJA)
```

### 6.3 La historia solo muere con la entidad

Cuando la entidad alcanza su estado terminal (PERSONA → FALLECIDO, VEHICULO → DADO_DE_BAJA,
PRODUCTO → DESCATALOGADO), todo el historial acumulado queda cerrado. **Nunca se borra.**
La entidad pasa a estado ARCHIVED. Sus atributos permanecen para consulta histórica,
auditoría y retención legal.

```
Toyota Carina 97:
  NACE: fábrica (1997) → 5 dueños, 1 robo, 1 siniestro, 28 años
  MUERE: desguace (2025)
  ARCHIVADO: historial completo preservado. 0 atributos activos. 40+ históricos.

Juan Pérez:
  NACE: registro civil (1985) → 8 dominios, 60+ atributos
  MUERE: fallecimiento (2030)
  ARCHIVADO: historial preservado 10 años (Ley 843 Bolivia).
```

---

## 7. Jerarquía completa — 6 niveles vs 5 del RolTemplate

```
NIVEL  ROL TEMPLATE                    MOTOR DE IDENTIDAD
─────  ────────────                    ──────────────────

  1    Dominio (D1, D3, D6...)         Dominio de Identidad (D00)
       │                                 │
  2    Bloque (B4, B6, B7...)          Tipo de Entidad
       │                                 PERSONA | ORGANIZACION | DISPOSITIVO
       │                                 | VEHICULO | INMUEBLE | PRODUCTO
       │                                 | SERVICIO | ANIMAL
       │                                 │
  3    PolicySet / Política            Dominio de Capa
       (zona, aplicación, capa B7)       civil | laboral | autenticacion
                                         | comercial | salud | educativo
                                         | propiedad | operativo | fiscal
                                         | ubicacion
       │                                 │
  4    Regla                           Política de Validación
       (Target+Condition→Effect)         ¿Qué atributos son requeridos?
                                         ¿Qué formato deben tener?
                                         ¿Qué valores son válidos?
       │                                 │
  5    Atributo (prop/op/valor)        Regla de Validación
                                         REGEX, IN, NOT_IN, BETWEEN...
                                         validate | verify | format
                                         │
  6    (no existe en RolTemplate)      Instancia Temporal del Atributo
                                         ─────────────────────────────
                                         valid_from / valid_until
                                         estado: ACTIVO | ARCHIVADO
                                         valor + display_format
                                         ─────────────────────────────
                                         (múltiples instancias por entidad)
```

**El motor de identidad tiene 6 niveles.** El nivel extra (6) es la **Instancia Temporal**
porque en identidad un atributo no es un valor puntual — es una entrada con vigencia.
Juan no "tiene un empleo", tiene 4 empleos en 15 años. Cada uno con fechas, estado y
datos propios. La historia se acumula. Nada se borra.

Los niveles 2 y 3 son específicos de identidad y no tienen equivalente directo en el
RolTemplate:
- **Tipo de Entidad** (nivel 2) — define qué ES. Inmutable. Gobierna qué dominios de capa son válidos.
- **Dominio de Capa** (nivel 3) — define en qué contexto opera. Se agrega/quita. Equivalente funcional al Bloque, pero más rico.

---

## 8. Resumen

| Concepto | RolTemplate | Motor de Identidad |
|---|---|---|
| **Niveles** | 5 | **6** |
| **Entidad base** | `idn_role_template` | `idn_entidad` |
| **Tipos** | tier (SU, SYS, BIZ_N1...) | tipo (PERSONA, DISPOSITIVO, VEHICULO...) |
| **Dominios/capas** | planos de control D1-D13 | dominios de atributos (civil, laboral, autenticacion...) |
| **Lo que aporta cada capa** | átomos (privilege_atom) | atributos (idn_atributo) |
| **Atributos de nacimiento** | — | inmutables, vienen de fábrica/origen |
| **Atributos de capa** | se agregan/quitan, el rol no muere | se agregan/quitan, estado → ARCHIVADO, historia preservada |
| **Muerte de la entidad** | el rol se desactiva (ARCHIVED) | la entidad llega a estado terminal, historial cerrado, nunca borrado |
| **Instancia temporal** | no existe | cada atributo tiene valid_from/valid_until + múltiples instancias |
| **Conjuntos** | D98 SET (conjuntos de roles) | D94 USERSET (conjuntos de entidades) |
| **Catálogo** | D97 normas, D96 métodos | D93 tipos válidos + dominios permitidos |
| **Evaluación** | BitMask (UserBitMask[pos]==1) | Motor de Identidad (validate/verify/format) |

**Mismo patrón. Mismo lenguaje. Distinto propósito. Un nivel más de profundidad.**
