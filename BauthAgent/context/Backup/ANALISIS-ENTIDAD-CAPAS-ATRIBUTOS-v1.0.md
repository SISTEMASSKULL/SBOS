# Análisis — La Entidad como Acumulador de Capas de Atributos

## Un auto pasa por fábrica → concesionario → dueño → servicio técnico → desguace. Es el mismo auto. Cada etapa le agrega atributos.

**Versión:** 1.0
**Fecha:** 2026-07-14

---

## 1. El principio

Una entidad en `idn_entidad` NO pertenece a un solo dominio. **Atraviesa dominios** a lo
largo de su ciclo de vida. Cada dominio le **agrega capas de atributos**. La entidad es
una. Sus atributos son capas acumuladas. Su estado actual es la suma de todas las capas
activas.

```
                    ┌─────────────────────────────────────────────────────────┐
                    │               idn_entidad (entidad_id = auto-001)         │
                    │                                                         │
                    │  nivel: actor   tipo: vehiculo   nombre: Toyota Carina   │
                    │                                                         │
                    └──────────────────────┬──────────────────────────────────┘
                                           │
            ┌──────────────────────────────┼──────────────────────────────┐
            │                              │                              │
            ▼                              ▼                              ▼
    ┌───────────────┐            ┌───────────────┐            ┌───────────────┐
    │ CAPA FÁBRICA  │            │ CAPA CONCES.   │            │ CAPA DUEÑO     │
    │ (dominio:     │            │ (dominio:      │            │ (dominio:      │
    │  manufactura) │            │  comercio)     │            │  registro)     │
    ├───────────────┤            ├───────────────┤            ├───────────────┤
    │ marca: Toyota │            │ color: rojo    │            │ placa: ABC-1234│
    │ modelo:Carina │            │ precio: $15K   │            │ dueño: J.Pérez │
    │ año: 1997     │            │ garantía: 3a   │            │ seguro: SegSA  │
    │ motor: 1.8L   │            │ stock_lote: 4  │            │ registro:1997  │
    │ chasis: XYZ   │            │                │            │ km_inicial: 0  │
    └───────────────┘            └───────────────┘            └───────────────┘
                                                                  │
                                          ┌───────────────────────┤
                                          ▼                       ▼
                                  ┌───────────────┐       ┌───────────────┐
                                  │ CAPA SERVICIO │       │ CAPA DESGUACE │
                                  │ (dominio:     │       │ (dominio:     │
                                  │  taller)      │       │  reciclaje)   │
                                  ├───────────────┤       ├───────────────┤
                                  │ aceite: 2020   │       │ estado: BAJA  │
                                  │ frenos: 2021   │       │ partes_recicl:│
                                  │ choque: 2022   │       │ motor, chasis │
                                  │ km_actual:250K │       │ fecha_baja:   │
                                  └───────────────┘       │ 2025          │
                                                          └───────────────┘
```

**Es el mismo auto.** Mismo `entidad_id`. Lo que cambia son las capas de atributos que
cada dominio le agrega.

---

## 2. Cómo se implementa

Cada atributo en `idn_atributo` registra qué dominio lo agregó:

```sql
ALTER TABLE bauth.idn_atributo ADD COLUMN dominio_origen TEXT;
-- 'manufactura', 'comercio', 'registro', 'taller', 'reciclaje'
-- El dominio_origen identifica qué sector/capa agregó este atributo
```

### 2.1 La fábrica crea el ente base

```
bauth.entidad.create(NULL, 'actor', 'vehiculo', 'Toyota Carina 97')
→ entidad_id: auto-001

bauth.entidad.atributo.set(auto-001, 'marca', NULL, 'Toyota', dominio='manufactura')
bauth.entidad.atributo.set(auto-001, 'modelo', NULL, 'Carina', dominio='manufactura')
bauth.entidad.atributo.set(auto-001, 'anio', NULL, '1997', dominio='manufactura')
bauth.entidad.atributo.set(auto-001, 'motor', NULL, '1.8L', dominio='manufactura')
bauth.entidad.atributo.set(auto-001, 'chasis', NULL, 'XYZ-1997-001', dominio='manufactura')
```

### 2.2 El concesionario agrega capa comercial

```
bauth.entidad.atributo.set(auto-001, 'color', NULL, 'rojo', dominio='comercio')
bauth.entidad.atributo.set(auto-001, 'precio', NULL, '15000', dominio='comercio')
bauth.entidad.atributo.set(auto-001, 'garantia_anios', NULL, '3', dominio='comercio')
```

### 2.3 El dueño agrega capa de registro

```
bauth.entidad.atributo.set(auto-001, 'placa', NULL, 'ABC-1234', dominio='registro')
bauth.entidad.atributo.set(auto-001, 'duenio', NULL, 'act-jperez', dominio='registro')
bauth.entidad.atributo.set(auto-001, 'seguro', NULL, 'Seguros SA', dominio='registro')
```

### 2.4 El taller agrega capa de mantenimiento

```
bauth.entidad.atributo.set(auto-001, 'ultimo_aceite', NULL, '2020-06-15', dominio='taller')
bauth.entidad.atributo.set(auto-001, 'ultimo_frenos', NULL, '2021-03-10', dominio='taller')
bauth.entidad.atributo.set(auto-001, 'km_actual', NULL, '250000', dominio='taller')
```

### 2.5 El desguace cierra el ciclo

```
bauth.entidad.atributo.set(auto-001, 'estado', NULL, 'DADO_DE_BAJA', dominio='reciclaje')
bauth.entidad.atributo.set(auto-001, 'partes_recicladas', NULL, 'motor, chasis', dominio='reciclaje')
```

---

## 3. Consultas por dominio

```
# ¿Qué atributos tiene este auto del dominio comercio?
bauth.entidad.atributo.list(auto-001, dominio='comercio')
→ [{ color: rojo }, { precio: 15000 }, { garantia_anios: 3 }]

# ¿Qué vehículos están en taller ahora?
bauth.entidad.atributo.search('ultimo_aceite', NULL, '*', dominio='taller')
→ [{ auto-001, 2020-06-15 }, ...]

# ¿Qué atributos totales tiene el auto? (todas las capas)
bauth.entidad.atributo.list(auto-001)
→ 14 atributos de 5 dominios distintos
```

---

## 4. Lo mismo para cualquier entidad

```
LAPTOP DELL (actor, tipo=producto)
  ┌─ manufactura: marca=Dell, modelo=XPS 15, serial=LAP-001
  ┌─ comercio:    precio=1200, moneda=USD, garantia=2a
  ┌─ inventario:  ubicacion=Almacén/Depósito-A/Estante-01, stock=15
  ┌─ venta:       cliente=Juan Pérez, fecha_venta=2024-03-10, precio_final=1150
  ┌─ soporte:     ticket=#4521, estado=REPARADA, fecha_entrega=2024-03-25

JUAN PÉREZ (actor, tipo=HUMAN)
  ┌─ civil:       nombre=Juan Pérez, CI=1234567 LP, nacimiento=1985-06-15
  ┌─ rrhh:        employee_code=VEN-001, cargo=Vendedor, fecha_ingreso=2020-03-15
  ┌─ autenticacion: username=jperez, MFA=TOTP, estado=ACTIVO
  ┌─ cliente:     customer_since=2021-01-10, credit_limit=5000
  ┌─ paciente:    historia=HC-2024-001, alergias=penicilina (si está internado)

EDIFICIO TORRE (bdomain, tipo=edificio)
  ┌─ construccion: direccion=Av. Principal, pisos=5, material=hormigón
  ┌─ inmobiliario: propietario=SKULL-CORP, valor_catastral=500K, uso=oficinas
  ┌─ mantenimiento: ultimo_ascensor=2024-01, ultimo_incendios=2024-06
  ┌─ iot:           sensor_temp_301=activo, puerta_301=OSDP, hvac_301=operativo
```

---

## 5. Esto reemplaza la clasificación por sectores

No necesitamos 23 códigos D00-IXX ni 6 tipos de ciclo de vida. Necesitamos **dominios
de origen** en `idn_atributo`. Cada dominio es una capa que agrega atributos. La entidad
es una. Sus atributos son las capas acumuladas. Su estado es la suma de todas las capas
activas.

El catálogo de dominios de origen es el que definimos en D93: `manufactura`, `comercio`,
`registro`, `taller`, `reciclaje`, `civil`, `rrhh`, `autenticacion`, `cliente`,
`paciente`, `construccion`, `inmobiliario`, `iot`, etc.

Agregar un nuevo dominio es agregarlo a D93. Sin tocar el DDL.

---

## 6. El caso Juan Pérez — 8 dominios, una sola entidad, 45 años de vida

```
idn_entidad (entidad_id = act-jperez)
  nivel: actor   tipo: HUMAN   nombre: Juan Pérez
  └── El mismo Juan desde que nace hasta que muere. 45 años de atributos acumulados.

═══════════════════════════════════════════════════════════════════
1985 ── CAPA CIVIL (dominio: registro_civil)
        Juan nace. El registro civil le da existencia legal.
        
        🏷️ nombre / given_name     → Juan
        🏷️ nombre / family_name    → Pérez
        🏷️ nombre / second_family  → Gómez (materno)
        🏷️ birth_date              → 1985-06-15
        🏷️ gender                  → M
        🏷️ nationality             → BOL
        🏷️ lugar_nacimiento        → La Paz, Bolivia
        
        Estos atributos NUNCA cambian. Son la capa base.
        Estado: VIVO

═══════════════════════════════════════════════════════════════════
1991 ── CAPA EDUCACIÓN (dominio: educacion)
        Juan entra a la escuela primaria.
        
        🏷️ matricula / primaria    → ESC-1991-001
        🏷️ colegio / nombre        → Escuela Fiscal #3
        🏷️ nivel_educativo         → primaria

1997 ── (mismo dominio, nueva capa)
        Juan entra a secundaria.
        
        🏷️ matricula / secundaria  → COL-1997-045
        🏷️ colegio / nombre        → Colegio Nacional Bolívar

2003 ── (mismo dominio, nueva capa)
        Juan entra a la universidad.
        
        🏷️ matricula /universidad  → UNI-2003-112
        🏷️ universidad / nombre    → UMSA
        🏷️ carrera                 → Administración de Empresas
        🏷️ titulo / grado          → Licenciatura (2008)

═══════════════════════════════════════════════════════════════════
2004 ── CAPA IDENTIFICACIÓN (dominio: identificacion)
        Juan saca su cédula de identidad.
        
        🏷️ id_nacional / CI        → 1234567 LP
        🏷️ emitido_por             → SEGIP
        🏷️ fecha_emision           → 2004-03-10
        🏷️ fecha_vencimiento       → 2014-03-10

2014 ── Renovación de CI.
        🏷️ id_nacional / CI        → 1234567 LP (mismo número)
        🏷️ fecha_emision           → 2014-02-20
        🏷️ fecha_vencimiento       → 2024-02-20

═══════════════════════════════════════════════════════════════════
2010 ── CAPA LABORAL (dominio: rrhh)
        SKULL-CORP contrata a Juan como vendedor junior.
        
        🏷️ employee_code           → VEN-2010-003
        🏷️ job_title               → Vendedor Junior
        🏷️ department              → Ventas
        🏷️ hire_date               → 2010-06-01
        🏷️ employment_type         → FULL_TIME
        🏷️ salary                  → 4500
        🏷️ manager_uuid            → act-mgomez (María Gómez)
        🏷️ office_location         → Norte, CAJA-01
        
        Estado laboral: ACTIVO

2015 ── Promoción.
        🏷️ job_title               → Vendedor Senior  (cambia)
        🏷️ salary                  → 7000             (cambia)

═══════════════════════════════════════════════════════════════════
2010 ── CAPA AUTENTICACIÓN (dominio: autenticacion)
        Al entrar a SKULL, Juan recibe acceso al sistema.
        
        🏷️ username                → jperez
        🏷️ password_hash           → (Argon2id)
        🏷️ MFA / metodo            → TOTP
        🏷️ MFA / enrolado          → 2010-06-02
        🏷️ account_status          → ACTIVE
        
        Estado de autenticación: ACTIVE

═══════════════════════════════════════════════════════════════════
2011 ── CAPA CLIENTE (dominio: cliente)
        Juan se registra en la tienda interna de SKULL.
        
        🏷️ customer_since          → 2011-01-10
        🏷️ credit_limit            → 5000
        🏷️ payment_method          → descuento_nomina
        🏷️ categoria_cliente       → empleado

═══════════════════════════════════════════════════════════════════
2012 ── CAPA FAMILIAR (dominio: civil)
        Juan se casa.
        
        🏷️ marital_status          → MARRIED
        🏷️ conyuge_nombre          → Laura Flores
        🏷️ conyuge_CI              → 2345678 CB
        🏷️ fecha_matrimonio        → 2012-11-20

2014 ── Nace su primer hijo.
        🏷️ dependiente / nombre    → Mateo Pérez Flores
        🏷️ dependiente / parentesco→ hijo
        🏷️ dependiente / CI       → 3456789 LP
        
        Juan agrega a su esposa e hijo como beneficiarios
        de su seguro de salud (dominio: rrhh → beneficios).

═══════════════════════════════════════════════════════════════════
2018 ── CAPA SALUD (dominio: salud)
        Juan se interna por apendicitis.
        
        🏷️ historia_clinica        → HC-2018-0456
        🏷️ diagnostico             → apendicitis aguda
        🏷️ fecha_ingreso           → 2018-08-12
        🏷️ fecha_alta              → 2018-08-15
        🏷️ medico_tratante         → Dr. Ramírez
        🏷️ alergias                → penicilina
        🏷️ grupo_sanguineo         → O+
        
        Mientras está internado, Juan es PACIENTE.
        Sigue siendo empleado, cliente, esposo, padre.
        Solo se agrega una capa más. Estado de salud: ALTA.

═══════════════════════════════════════════════════════════════════
2020 ── CAPA PROVEEDOR (dominio: proveedor)
        Juan abre un negocio paralelo de consultoría.
        
        🏷️ categoria_proveedor     → consultoria
        🏷️ servicios               → ventas, capacitacion
        🏷️ factura_a               → SKULL-CORP (su empleador también es su cliente)

═══════════════════════════════════════════════════════════════════
2026 ── DESPIDO
        SKULL-CORP despide a Juan por reestructuración.
        
        ✕ CAPA LABORAL:    estado → TERMINATED. termination_date: 2026-07-14.
        ✕ CAPA AUTENTICACIÓN: account_status → REVOKED.
        
        ✓ CAPA CIVIL:      Juan sigue siendo Juan. CI vigente.
        ✓ CAPA CLIENTE:    Juan sigue siendo cliente de la tienda (si quiere).
        ✓ CAPA PROVEEDOR:  Juan sigue facturando como consultor.
        ✓ CAPA FAMILIAR:   Juan sigue casado, con hijos.
        ✓ CAPA SALUD:      Su historia clínica permanece.

════════════════════════════════════════════════════════════════════
2030 ── FALLECIMIENTO
        Juan fallece a los 45 años.
        
        ✕ CAPA CIVIL:     estado → FALLECIDO. fecha_defuncion: 2030-01-10.
        ✕ CAPA CLIENTE:   credit_limit → 0. estado → INACTIVO.
        ✕ CAPA PROVEEDOR: estado → INACTIVO.
        
        ✓ Los registros se conservan. Retención legal 10 años (Ley 843 Bolivia).
        ✓ La entidad act-jperez NUNCA se elimina de idn_entidad.
```

### 6.1 Resumen visual

```
1985 ────────────────────────────────────────────────────────── 2030
│                                                                 │
│ ██████████████████████████████████████████████████████████████  │
│ CAPA CIVIL: VIVO ─────────────────────────────── FALLECIDO      │
│                                                                 │
│          ██████████████████████████                              │
│          CAPA EDUCACIÓN: 1991-2008                               │
│                                                                 │
│               ████████████████████████████████                   │
│               CAPA LABORAL: ACTIVO ──── TERMINADO               │
│                                                                 │
│               ████████████████████████████████                   │
│               CAPA AUTENTICACIÓN: ACTIVE ── REVOKED             │
│                                                                 │
│                 ██████████████████████████████████████           │
│                 CAPA CLIENTE: ACTIVO ─────────────────           │
│                                                                 │
│                         ██████████████████                       │
│                         CAPA PROVEEDOR: 2020-2030                │
│                                                                 │
│                               ████                               │
│                               CAPA SALUD: 2018 (internación)     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 La consulta que muestra todas las capas

```
bauth.entidad.atributo.list(act-jperez)
→ 42 atributos de 8 dominios distintos acumulados en 45 años de vida
→ Mismo entidad_id desde 1985 hasta 2030
→ Cada atributo tiene su dominio_origen registrado

bauth.entidad.atributo.list(act-jperez, dominio='rrhh')
→ Solo los 7 atributos laborales (employee_code, job_title, salary...)

bauth.entidad.atributo.list(act-jperez, dominio='autenticacion')
→ Solo los 5 atributos de acceso (username, password_hash, MFA...)
```

**Es el mismo Juan. 45 años. 8 dominios. Una entidad. Las capas van y vienen.**
