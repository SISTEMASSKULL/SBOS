# BAUTH-CADENAS-JERARQUIA — Dependencias Completas de Roles por Sector CAEB
## Anexo al Catálogo de Roles Empresariales · v1.2 · 2026-06-21 · SKULL

> **Propósito:** este anexo documenta la jerarquía completa de dependencias para cada
> uno de los 21 sectores CAEB del SIN. Cada rol de negocio (N0–N5) tiene una posición
> definida en el DAG de herencia de privilegios. Ningún rol existe aislado.
>
> **Base normativa:** NIST RBAC §4.2 (Hierarchical RBAC, DAG) · NIST AC-5 (SoD) ·
> bAuth PrivilegeEngine — BitMask Dual: las operaciones de herencia (OR/AND) operan
> sobre **posiciones de bit en el Rol BitMask** (one-hot encoding), NUNCA sobre
> códigos de átomo (label encoding). Ver `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md` §5.
>
> **Documentos relacionados:**
> - `BAUTH-CATALOGO-ROLES-EMPRESARIALES.md` v2.1 — Catálogo con §6 actualizado (BitMask Dual)
> - `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md` — BitMask Dual + DDL bos_privilege
> - `SBOS-MANUAL-BAUTH-COMPONENT-ROLES.md` v1.7 — bAuth orquesta, no es un motor más
> - `SBOS-BAUTH-EVALUACION-INTEGRAL-v2.2.md` — Evaluación integral del proyecto bAuth
>
> **Convención de lectura:** `Padre ← Hijo` significa que el Padre **hereda** los
> privilegios del Hijo. La flecha apunta en dirección de la herencia (junior → senior).

---

## Índice de Sectores

| # | Sector CAEB | División | Página |
|---|------------|----------|--------|
| A | Agricultura, Ganadería, Pesca | 01–03 | §A |
| B | Minería e Hidrocarburos | 05–09 | §B |
| C | Industria Manufacturera | 10–33 | §C |
| D | Electricidad, Gas, Vapor | 35 | §D |
| E | Agua, Desechos | 36–39 | §E |
| F | Construcción | 41–43 | §F |
| G | Comercio (Compra/Venta) | 45–47 | §G |
| H | Transporte y Almacenamiento | 49–53 | §H |
| I | Alojamiento y Comidas | 55–56 | §I |
| J | Información y Comunicaciones | 58–63 | §J |
| K | Financieras y Seguros | 64–66 | §K |
| L | Inmobiliarias | 68 | §L |
| M | Profesionales, Científicas, Técnicas | 69–75 | §M |
| N | Servicios Administrativos | 77–82 | §N |
| O | Administración Pública | 84 | §O |
| P | Enseñanza / Educación | 85 | §P |
| Q | Salud y Asistencia Social | 86–88 | §Q |
| R | Arte, Entretenimiento, Deporte | 90–93 | §R |
| S | Otras Actividades de Servicios | 94–96 | §S |
| T | Hogares como Empleadores | 97–98 | §T |
| U | Organizaciones Extraterritoriales | 99 | §U |

---

## §A — Agricultura, Ganadería, Silvicultura y Pesca

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Admin de Estancia / Hacienda ─── ROL-ADMIN-ESTANCIA
              │
              ├── N4: — (sin gerencia media definida en este sector)
              │
              ├── N3: Capataz / Encargado de Campo ─── ROL-CAPATAZ
              │     ├── N1: Peón Rural / Jornalero ─── ROL-PEON-RURAL
              │     │     └── N0: Comprador Mayorista / Acopiador ─── ROL-EXT-COMPRADOR-AGRO
              │     ├── N1: Tractorista ─── ROL-TRACTORISTA
              │     └── N1: Encargado de Riego ─── ROL-ENCARGADO-RIEGO
              │           └── N0: Consumidor Final Agro ─── ROL-EXT-CONSUMIDOR-AGRO
              │
              ├── N2: Veterinario de Campo ─── ROL-VETERINARIO
              │     └── N0: Técnico Veterinario Visitante ─── ROL-EXT-VETERINARIO-VISITANTE
              │
              └── N0: Proveedor de Insumos Agrícolas ─── ROL-EXT-PROVEEDOR-AGRO
                    N0: Exportador Agroindustrial ─── ROL-EXT-EXPORTADOR-AGRO
                    N0: Productor Asociado ─── ROL-EXT-PRODUCTOR-AGRO
```

| Arista | Padre (hereda de...) | Hijo (...hereda a) | Tipo |
|--------|---------------------|-------------------|------|
| A01 | ROL-ADMIN-ESTANCIA | ROL-CAPATAZ | N5←N3 |
| A02 | ROL-ADMIN-ESTANCIA | ROL-VETERINARIO | N5←N2 |
| A03 | ROL-CAPATAZ | ROL-PEON-RURAL | N3←N1 |
| A04 | ROL-CAPATAZ | ROL-TRACTORISTA | N3←N1 |
| A05 | ROL-CAPATAZ | ROL-ENCARGADO-RIEGO | N3←N1 |
| A06 | ROL-PEON-RURAL | ROL-EXT-COMPRADOR-AGRO | N1←N0 |
| A07 | ROL-ENCARGADO-RIEGO | ROL-EXT-CONSUMIDOR-AGRO | N1←N0 |
| A08 | ROL-VETERINARIO | ROL-EXT-VETERINARIO-VISITANTE | N2←N0 |

---

## §B — Explotación de Minas y Canteras

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Gerente de Operación Minera ─── ROL-GERENTE-GENERAL
              │
              ├── N4: Jefe de Producción ─── ROL-JEFE-PRODUCCION
              │     ├── N3: Supervisor de Planta ─── ROL-SUPERVISOR-PLANTA
              │     │     ├── N1: Operario de Producción ─── ROL-OPERARIO-PRODUCCION
              │     │     └── N1: Operario de Embalaje ─── ROL-OPERARIO-EMBALAJE
              │     │
              │     ├── N2: Técnico de Mantenimiento ─── ROL-TECNICO-MANTENIMIENTO
              │     ├── N2: Control de Calidad ─── ROL-CONTROL-CALIDAD
              │     └── N2: Seguridad e Higiene ─── ROL-SEGURIDAD-HIGIENE
              │
              ├── N2: Ingeniero de Planta ─── ROL-INGENIERO-PLANTA
              │
              └── N0: Comprador de Minerales ─── ROL-EXT-COMPRADOR-MINERO
                    N0: Inversionista Minero ─── ROL-EXT-INVERSIONISTA-MINERO
                    N0: Comunidad ─── ROL-EXT-COMUNIDAD-MINERA
                    N0: Contratista Minero ─── ROL-EXT-CONTRATISTA-MINERO
                    N0: Comprador de Oro ─── ROL-EXT-COMPRADOR-ORO
```

| Arista | Padre (hereda de...) | Hijo (...hereda a) | Tipo |
|--------|---------------------|-------------------|------|
| B01 | ROL-GERENTE-GENERAL | ROL-JEFE-PRODUCCION | N5←N4 |
| B02 | ROL-GERENTE-GENERAL | ROL-INGENIERO-PLANTA | N5←N2 |
| B03 | ROL-JEFE-PRODUCCION | ROL-SUPERVISOR-PLANTA | N4←N3 |
| B04 | ROL-JEFE-PRODUCCION | ROL-TECNICO-MANTENIMIENTO | N4←N2 |
| B05 | ROL-JEFE-PRODUCCION | ROL-CONTROL-CALIDAD | N4←N2 |
| B06 | ROL-JEFE-PRODUCCION | ROL-SEGURIDAD-HIGIENE | N4←N2 |
| B07 | ROL-SUPERVISOR-PLANTA | ROL-OPERARIO-PRODUCCION | N3←N1 |
| B08 | ROL-SUPERVISOR-PLANTA | ROL-OPERARIO-EMBALAJE | N3←N1 |

---

## §C — Industria Manufacturera

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Gerente General ─── ROL-GERENTE-GENERAL
              │
              ├── N4: Jefe de Producción ─── ROL-JEFE-PRODUCCION
              │     ├── N3: Supervisor de Planta ─── ROL-SUPERVISOR-PLANTA
              │     │     ├── N1: Operario de Producción ─── ROL-OPERARIO-PRODUCCION
              │     │     ├── N1: Operario de Embalaje ─── ROL-OPERARIO-EMBALAJE
              │     │     └── N1: Operario de Carga ─── ROL-ESTIBADOR
              │     │           └── N0: Cliente Minorista Industrial ─── ROL-EXT-CLIENTE-MINORISTA-IND
              │     │
              │     ├── N2: Técnico de Mantenimiento ─── ROL-TECNICO-MANTENIMIENTO
              │     ├── N2: Control de Calidad ─── ROL-CONTROL-CALIDAD
              │     │     └── N0: Inspector de Calidad ─── ROL-EXT-INSPECTOR-CALIDAD
              │     ├── N2: Seguridad e Higiene ─── ROL-SEGURIDAD-HIGIENE
              │     └── N2: Planificador de Producción ─── ROL-PLANIFICADOR-PRODUCCION
              │
              ├── N4: Jefe de Logística ─── ROL-JEFE-LOGISTICA
              │     ├── N1: Despachador / Chofer ─── ROL-DESPACHADOR-CHOFER
              │     └── N0: Cliente Mayorista Industrial ─── ROL-EXT-CLIENTE-MAYORISTA-IND
              │           N0: Cliente de Exportación ─── ROL-EXT-CLIENTE-EXPORT-IND
              │
              ├── N4: Jefe de Compras ─── ROL-JEFE-COMPRAS
              │     └── N0: Proveedor de Materia Prima ─── ROL-EXT-PROVEEDOR-MP
              │           N0: Proveedor de Maquinaria ─── ROL-EXT-PROVEEDOR-MAQUINARIA
              │           N0: Maquilador ─── ROL-EXT-MAQUILADOR
              │
              ├── N4: Jefe de Inventarios ─── ROL-JEFE-INVENTARIOS
              │     ├── N3: Supervisor de Almacenes ─── ROL-SUPERVISOR-ALMACENES
              │     │     ├── N1: Encargado de Almacén MP ─── ROL-ENCARGADO-ALMACEN-MP
              │     │     └── N1: Encargado de Almacén PT ─── ROL-ENCARGADO-ALMACEN-PT
              │     └── N2: Planificador de Demanda ─── ROL-PLANIFICADOR-DEMANDA
              │
              └── N2: Ingeniero de Planta ─── ROL-INGENIERO-PLANTA
                    └── N0: Diseñador Industrial Externo ─── ROL-EXT-DISENADOR-IND
```

| Arista | Padre | Hijo | Tipo |
|--------|-------|------|------|
| C01 | ROL-GERENTE-GENERAL | ROL-JEFE-PRODUCCION | N5←N4 |
| C02 | ROL-GERENTE-GENERAL | ROL-JEFE-LOGISTICA | N5←N4 |
| C03 | ROL-GERENTE-GENERAL | ROL-JEFE-COMPRAS | N5←N4 |
| C04 | ROL-GERENTE-GENERAL | ROL-JEFE-INVENTARIOS | N5←N4 |
| C05 | ROL-GERENTE-GENERAL | ROL-INGENIERO-PLANTA | N5←N2 |
| C06 | ROL-JEFE-PRODUCCION | ROL-SUPERVISOR-PLANTA | N4←N3 |
| C07 | ROL-SUPERVISOR-PLANTA | ROL-OPERARIO-PRODUCCION | N3←N1 |
| C08 | ROL-OPERARIO-PRODUCCION | ROL-EXT-CLIENTE-MINORISTA-IND | N1←N0 |
| C09 | ROL-JEFE-LOGISTICA | ROL-DESPACHADOR-CHOFER | N4←N1 |
| C10 | ROL-DESPACHADOR-CHOFER | ROL-EXT-CLIENTE-MAYORISTA-IND | N1←N0 |
| C11 | ROL-JEFE-COMPRAS | ROL-EXT-PROVEEDOR-MP | N4←N0 |
| C12 | ROL-JEFE-INVENTARIOS | ROL-SUPERVISOR-ALMACENES | N4←N3 |
| C13 | ROL-SUPERVISOR-ALMACENES | ROL-ENCARGADO-ALMACEN-MP | N3←N1 |
| C14 | ROL-SUPERVISOR-ALMACENES | ROL-ENCARGADO-ALMACEN-PT | N3←N1 |
| C15 | ROL-INGENIERO-PLANTA | ROL-EXT-DISENADOR-IND | N2←N0 |

---

## §D — Suministro de Electricidad, Gas, Vapor

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Gerente General ─── ROL-GERENTE-GENERAL
              │
              ├── N4: Jefe de IT ─── ROL-JEFE-IT
              │     ├── N2: SysAdmin ─── ROL-SYSADMIN
              │     │     └── N0: Usuario Residencial ─── ROL-EXT-USUARIO-RESIDENCIAL
              │     └── N0: Usuario Industrial ─── ROL-EXT-USUARIO-INDUSTRIAL
              │
              ├── N2: Técnico de Mantenimiento ─── ROL-TECNICO-MANTENIMIENTO
              │     └── N0: Generador Independiente ─── ROL-EXT-GENERADOR-INDEP
              │
              ├── N2: Planificador de Producción ─── ROL-PLANIFICADOR-PRODUCCION
              │
              └── N0: Usuario de Alumbrado Público ─── ROL-EXT-USUARIO-ALUMBRADO
                    N0: Solicitante de Nueva Conexión ─── ROL-EXT-SOLICITANTE-CONEXION
```

| Arista | Padre (hereda de...) | Hijo (...hereda a) | Tipo |
|--------|---------------------|-------------------|------|
| D01 | ROL-GERENTE-GENERAL | ROL-JEFE-IT | N5←N4 |
| D02 | ROL-JEFE-IT | ROL-SYSADMIN | N4←N2 |
| D03 | ROL-SYSADMIN | ROL-EXT-USUARIO-RESIDENCIAL | N2←N0 |
| D04 | ROL-JEFE-IT | ROL-EXT-USUARIO-INDUSTRIAL | N4←N0 |
| D05 | ROL-GERENTE-GENERAL | ROL-TECNICO-MANTENIMIENTO | N5←N2 |
| D06 | ROL-TECNICO-MANTENIMIENTO | ROL-EXT-GENERADOR-INDEP | N2←N0 |
| D07 | ROL-GERENTE-GENERAL | ROL-PLANIFICADOR-PRODUCCION | N5←N2 |


---

## §E — Agua, Alcantarillado, Gestión de Desechos

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Gerente General ─── ROL-GERENTE-GENERAL
              │
              ├── N2: SysAdmin ─── ROL-SYSADMIN
              │     ├── N0: Usuario Residencial de Agua ─── ROL-EXT-USUARIO-AGUA
              │     └── N0: Usuario Industrial de Agua ─── ROL-EXT-USUARIO-AGUA-IND
              │
              ├── N0: Generador de Residuos ─── ROL-EXT-GENERADOR-RESIDUOS
              │
              └── N0: Solicitante de Licencia Ambiental ─── ROL-EXT-SOLICITANTE-AMBIENTAL
```

| Arista | Padre (hereda de...) | Hijo (...hereda a) | Tipo |
|--------|---------------------|-------------------|------|
| E01 | ROL-GERENTE-GENERAL | ROL-SYSADMIN | N5←N2 |
| E02 | ROL-SYSADMIN | ROL-EXT-USUARIO-AGUA | N2←N0 |
| E03 | ROL-SYSADMIN | ROL-EXT-USUARIO-AGUA-IND | N2←N0 |
| E04 | ROL-GERENTE-GENERAL | ROL-EXT-GENERADOR-RESIDUOS | N5←N0 |
| E05 | ROL-GERENTE-GENERAL | ROL-EXT-SOLICITANTE-AMBIENTAL | N5←N0 |


---

## §F — Construcción

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Gerente General ─── ROL-GERENTE-GENERAL
              │
              ├── N4: Jefe de Producción ─── ROL-JEFE-PRODUCCION  [genérico: jefe de obra]
              │     │
              │     ├── N3: Maestro de Obra ─── ROL-MAESTRO-OBRA
              │     │     ├── N1: Albañil ─── ROL-ALBANIL
              │     │     │     └── N0: Propietario de la Obra ─── ROL-EXT-PROPIETARIO-OBRA
              │     │     ├── N1: Peón de Obra ─── ROL-PEON-OBRA
              │     │     ├── N2: Electricista ─── ROL-ELECTRICISTA
              │     │     │     └── N0: Inversionista de Obra ─── ROL-EXT-INVERSIONISTA-OBRA
              │     │     └── N2: Plomero ─── ROL-PLOMERO
              │     │
              │     ├── N2: Ingeniero Civil ─── ROL-INGENIERO-CIVIL
              │     │     └── N0: Fiscalizador de Obra ─── ROL-EXT-FISCALIZADOR-OBRA
              │     │           N0: Arquitecto Externo ─── ROL-EXT-PROYECTISTA
              │     │
              │     ├── N0: Proveedor de Materiales ─── ROL-EXT-PROVEEDOR-MATERIALES
              │     └── N0: Comprador de Inmueble ─── ROL-EXT-COMPRADOR-INMUEBLE
              │
              └── N2: Contador ─── ROL-CONTADOR
```

| Arista | Padre (hereda de...) | Hijo (...hereda a) | Tipo |
|--------|---------------------|-------------------|------|
| F01 | ROL-GERENTE-GENERAL | ROL-JEFE-PRODUCCION | N5←N4 |
| F02 | ROL-JEFE-PRODUCCION | ROL-MAESTRO-OBRA | N4←N3 |
| F03 | ROL-MAESTRO-OBRA | ROL-ALBANIL | N3←N1 |
| F04 | ROL-ALBANIL | ROL-EXT-PROPIETARIO-OBRA | N1←N0 |
| F05 | ROL-MAESTRO-OBRA | ROL-PEON-OBRA | N3←N1 |
| F06 | ROL-MAESTRO-OBRA | ROL-ELECTRICISTA | N3←N2 |
| F07 | ROL-MAESTRO-OBRA | ROL-PLOMERO | N3←N2 |
| F08 | ROL-GERENTE-GENERAL | ROL-INGENIERO-CIVIL | N5←N2 |
| F09 | ROL-INGENIERO-CIVIL | ROL-EXT-FISCALIZADOR-OBRA | N2←N0 |
| F10 | ROL-GERENTE-GENERAL | ROL-CONTADOR | N5←N2 |


---

## §G — Comercio al por Mayor y Menor (Compra/Venta)

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Gerente General ─── ROL-GERENTE-GENERAL
              │
              ├── N4: Jefe de Local ─── ROL-JEFE-LOCAL
              │     │
              │     ├── N3: Supervisor de Tienda ─── ROL-SUPERVISOR-TIENDA
              │     │     ├── N1: Cajero ─── ROL-CAJERO
              │     │     │     └── N0: Cliente Minorista ─── ROL-EXT-CLIENTE-MINORISTA
              │     │     │           N0: Cliente Fidelizado ─── ROL-EXT-CLIENTE-FIDELIZADO
              │     │     │           N0: Cliente Ocasional ─── ROL-EXT-CLIENTE-OCASIONAL
              │     │     │           N0: Cliente E-commerce ─── ROL-EXT-CLIENTE-ECOMMERCE
              │     │     ├── N1: Vendedor de Piso ─── ROL-VENDEDOR
              │     │     │     ├── N0: Cliente de Tienda Especializada ─── ROL-EXT-CLIENTE-TIENDA
              │     │     │     └── [Vendedores por rubro: ROL-VENDEDOR-ELECTRO, ROL-VENDEDOR-TECNOLOGIA,
              │     │     │          ROL-VENDEDOR-MODA, ROL-VENDEDOR-MUEBLES, ROL-VENDEDOR-REPUESTOS,
              │     │     │          ROL-VENDEDOR-JUGUETES, ROL-FERRETERO, ROL-LIBRERO, ROL-JOYERO]
              │     │     ├── N1: Reponedor ─── ROL-REPONEDOR
              │     │     ├── N1: Promotor ─── ROL-PROMOTOR
              │     │     └── N1: Cajero de Autoservicio ─── ROL-CAJERO-AUTOSERVICIO
              │     │           └── N0: Cliente de Supermercado ─── ROL-EXT-CLIENTE-SUPERMERCADO
              │     │
              │     ├── N2: Encargado de Inventario ─── ROL-ENCARGADO-INVENTARIO
              │     │     ├── N1: Encargado de Depósito ─── ROL-ENCARGADO-DEPOSITO
              │     │     │     ├── N1: Encargado de Frutas y Verduras ─── ROL-ENCARGADO-FRUTAS-VERDURAS
              │     │     │     ├── N1: Carnicero ─── ROL-CARNICERO
              │     │     │     ├── N1: Panadero ─── ROL-PANADERO
              │     │     │     ├── N1: Encargado de Lácteos ─── ROL-ENCARGADO-LACTEOS
              │     │     │     └── N1: Encargado de Limpieza ─── ROL-ENCARGADO-LIMPIEZA
              │     │     ├── N1: Fletero / Repartidor ─── ROL-FLETERO
              │     │     │     └── N0: Cliente de Delivery ─── ROL-EXT-CLIENTE-DELIVERY
              │     │     └── N0: Proveedor Nacional ─── ROL-EXT-PROVEEDOR-NACIONAL
              │     │           N0: Proveedor Internacional ─── ROL-EXT-PROVEEDOR-IMPORTADOR
              │     │           N0: Artesano ─── ROL-EXT-ARTESANO
              │     │
              │     ├── N3: Supervisor de Facturación ─── ROL-SUPERVISOR-FACT-COBRANZA
              │     │     ├── N1: Encargado de Facturación ─── ROL-ENCARGADO-FACTURACION
              │     │     │     └── N0: Cliente Mayorista ─── ROL-EXT-CLIENTE-MAYORISTA
              │     │     │           N0: Cliente Corporativo ─── ROL-EXT-CLIENTE-CORPORATIVO
              │     │     │           N0: Cliente Institucional ─── ROL-EXT-CLIENTE-INSTITUCIONAL
              │     │     ├── N1: Operador de Facturación POS ─── ROL-OPERADOR-FACT-POS
              │     │     ├── N1: Operador de Facturación Móvil ─── ROL-OPERADOR-FACT-MOVIL
              │     │     ├── N2: Encargado de CxC ─── ROL-ENCARGADO-CXC
              │     │     │     ├── N1: Cobrador ─── ROL-COBRADOR
              │     │     │     └── N2: Analista de Crédito ─── ROL-ANALISTA-CREDITO-COBRANZA
              │     │     ├── N1: Encargado de Notas de Crédito ─── ROL-ENCARGADO-NOTAS-CREDITO
              │     │     ├── N1: Conciliador de Facturación ─── ROL-CONCILIADOR-FACTURACION
              │     │     ├── N1: Operador de Facturación Recurrente ─── ROL-OPERADOR-FACT-RECURRENTE
              │     │     ├── N2: Encargado de Reportes de IVA ─── ROL-ENCARGADO-REPORTES-IVA
              │     │     └── N2: Encargado de Retenciones/Percepciones ─── ROL-ENCARGADO-RETENCIONES-PERCEPCIONES
              │     │
              │     ├── N4: Jefe de Contabilidad ─── ROL-JEFE-CONTABILIDAD
              │     │     ├── N2: Contador ─── ROL-CONTADOR
              │     │     │     ├── N1: Asistente Contable ─── ROL-ASISTENTE-CONTABLE
              │     │     │     ├── N2: Contador de Costos ─── ROL-CONTADOR-COSTOS
              │     │     │     ├── N2: Contador Impositivo ─── ROL-CONTADOR-IMPOSITIVO
              │     │     │     │     ├── N2: Encargado de Impuestos Diferidos ─── ROL-ENCARGADO-IMPUESTOS-DIFERIDOS
              │     │     │     │     └── N2: Encargado de Retenciones/Percepciones ─── ROL-ENCARGADO-RETENCIONES-PERCEPCIONES
              │     │     │     └── N2: Encargado de Cierre Mensual/Anual ─── ROL-ENCARGADO-CIERRE
              │     │     ├── N2: Analista de Cuentas por Pagar ─── ROL-ANALISTA-CXP
              │     │     ├── N2: Analista de Cuentas por Cobrar ─── ROL-ANALISTA-CXC-CONTABLE
              │     │     ├── N2: Conciliador Bancario ─── ROL-CONCILIADOR-BANCARIO
              │     │     ├── N2: Encargado de Activos Fijos ─── ROL-ENCARGADO-ACTIVOS-FIJOS
              │     │     ├── N2: Encargado de Presupuesto ─── ROL-ENCARGADO-PRESUPUESTO
              │     │     ├── N2: Tesorero ─── ROL-TESORERO-PAGOS
              │     │     │     └── N1: Asistente de Tesorería ─── ROL-ASISTENTE-TESORERIA
              │     │     ├── N1: Encargado de Nómina ─── ROL-ENCARGADO-NOMINA
              │     │     ├── N2: Revisor de Estados Financieros ─── ROL-REVISOR-ESTADOS-FINANCIEROS
              │     │     ├── N2: Analista de Control Interno ─── ROL-ANALISTA-CONTROL-INTERNO
              │     │     └── N2: Auditor Externo Contable ─── ROL-AUDITOR-EXTERNO-CONTABLE
              │     │
              │     ├── N4: Jefe de Inventarios ─── ROL-JEFE-INVENTARIOS
              │     │     ├── N3: Supervisor de Almacenes ─── ROL-SUPERVISOR-ALMACENES
              │     │     │     ├── N1: Encargado de Depósito ─── ROL-ENCARGADO-DEPOSITO
              │     │     │     │     ├── N1: Encargado de Frutas y Verduras ─── ROL-ENCARGADO-FRUTAS-VERDURAS
              │     │     │     │     ├── N1: Carnicero ─── ROL-CARNICERO
              │     │     │     │     ├── N1: Panadero ─── ROL-PANADERO
              │     │     │     │     ├── N1: Encargado de Lácteos ─── ROL-ENCARGADO-LACTEOS
              │     │     │     │     └── N1: Encargado de Limpieza ─── ROL-ENCARGADO-LIMPIEZA
              │     │     │     ├── N1: Encargado de Recepción de Mercadería ─── ROL-RECEPTOR-MERCADERIA
              │     │     │     │     └── N0: Proveedor Nacional ─── ROL-EXT-PROVEEDOR-NACIONAL
              │     │     │     │           N0: Proveedor Internacional ─── ROL-EXT-PROVEEDOR-IMPORTADOR
              │     │     │     ├── N1: Encargado de Despacho ─── ROL-ENCARGADO-DESPACHO
              │     │     │     │     └── N1: Fletero / Repartidor ─── ROL-FLETERO
              │     │     │     │           └── N0: Cliente de Delivery ─── ROL-EXT-CLIENTE-DELIVERY
              │     │     │     ├── N1: Encargado de Caducidades y Lotes ─── ROL-ENCARGADO-CADUCIDADES
              │     │     │     ├── N1: Operador de Código de Barras / RFID ─── ROL-OPERADOR-BARRAS-RFID
              │     │     │     ├── N1: Encargado de Devoluciones ─── ROL-ENCARGADO-DEVOLUCIONES
              │     │     │     ├── N1: Operador de WMS ─── ROL-OPERADOR-WMS
              │     │     │     ├── N2: Encargado de Cadena de Frío ─── ROL-ENCARGADO-CADENA-FRIO
              │     │     │     ├── N1: Encargado de Almacén MP ─── ROL-ENCARGADO-ALMACEN-MP
              │     │     │     └── N1: Encargado de Almacén PT ─── ROL-ENCARGADO-ALMACEN-PT
              │     │     ├── N2: Analista de Control de Mermas ─── ROL-ANALISTA-MERMAS
              │     │     ├── N2: Auditor de Inventario ─── ROL-AUDITOR-INVENTARIO
              │     │     └── N2: Planificador de Demanda ─── ROL-PLANIFICADOR-DEMANDA
              │     │
              │     └── N0: Proveedor de Servicios al Comercio ─── ROL-EXT-PROVEEDOR-SERV-COMERCIO
              │           N0: Artesano ─── ROL-EXT-ARTESANO
              │
              ├── N4: Jefe de Facturación y Crédito ─── ROL-JEFE-FACTURACION-CREDITO
              │     └── [hereda de ROL-SUPERVISOR-FACT-COBRANZA y toda su cadena]
              │
              ├── N4: Jefe de RRHH ─── ROL-JEFE-RRHH
              │     └── N2: Analista de RRHH ─── ROL-ANALISTA-RRHH
              │
              └── N1: Atención al Cliente ─── ROL-ATENCION-CLIENTE
```

| Arista | Padre | Hijo | Tipo |
|--------|-------|------|------|
| G01 | ROL-GERENTE-GENERAL | ROL-JEFE-LOCAL | N5←N4 |
| G02 | ROL-JEFE-LOCAL | ROL-SUPERVISOR-TIENDA | N4←N3 |
| G03 | ROL-SUPERVISOR-TIENDA | ROL-CAJERO | N3←N1 |
| G04 | ROL-CAJERO | ROL-EXT-CLIENTE-MINORISTA | N1←N0 |
| G05 | ROL-SUPERVISOR-TIENDA | ROL-VENDEDOR | N3←N1 |
| G06 | ROL-VENDEDOR | ROL-EXT-CLIENTE-TIENDA | N1←N0 |
| G07 | ROL-JEFE-LOCAL | ROL-JEFE-INVENTARIOS | N4←N4 |
| G08 | ROL-JEFE-INVENTARIOS | ROL-SUPERVISOR-ALMACENES | N4←N3 |
| G09 | ROL-SUPERVISOR-ALMACENES | ROL-ENCARGADO-DEPOSITO | N3←N1 |
| G10 | ROL-SUPERVISOR-ALMACENES | ROL-RECEPTOR-MERCADERIA | N3←N1 |
| G11 | ROL-RECEPTOR-MERCADERIA | ROL-EXT-PROVEEDOR-NACIONAL | N1←N0 |
| G12 | ROL-SUPERVISOR-ALMACENES | ROL-ENCARGADO-DESPACHO | N3←N1 |
| G13 | ROL-ENCARGADO-DESPACHO | ROL-FLETERO | N1←N1 |
| G14 | ROL-FLETERO | ROL-EXT-CLIENTE-DELIVERY | N1←N0 |
| G15 | ROL-JEFE-LOCAL | ROL-SUPERVISOR-FACT-COBRANZA | N4←N3 |
| G16 | ROL-SUPERVISOR-FACT-COBRANZA | ROL-ENCARGADO-FACTURACION | N3←N1 |
| G17 | ROL-ENCARGADO-FACTURACION | ROL-EXT-CLIENTE-MAYORISTA | N1←N0 |
| G18 | ROL-JEFE-LOCAL | ROL-JEFE-CONTABILIDAD | N4←N4 |
| G19 | ROL-JEFE-CONTABILIDAD | ROL-CONTADOR | N4←N2 |
| G20 | ROL-CONTADOR | ROL-ASISTENTE-CONTABLE | N2←N1 |
| G21 | ROL-CONTADOR | ROL-CONTADOR-COSTOS | N2←N2 |
| G22 | ROL-CONTADOR | ROL-CONTADOR-IMPOSITIVO | N2←N2 |
| G23 | ROL-JEFE-CONTABILIDAD | ROL-ANALISTA-CXP | N4←N2 |
| G24 | ROL-JEFE-CONTABILIDAD | ROL-ANALISTA-CXC-CONTABLE | N4←N2 |
| G25 | ROL-JEFE-CONTABILIDAD | ROL-CONCILIADOR-BANCARIO | N4←N2 |
| G26 | ROL-JEFE-CONTABILIDAD | ROL-ENCARGADO-ACTIVOS-FIJOS | N4←N2 |
| G27 | ROL-JEFE-CONTABILIDAD | ROL-ENCARGADO-PRESUPUESTO | N4←N2 |
| G28 | ROL-JEFE-CONTABILIDAD | ROL-TESORERO-PAGOS | N4←N2 |
| G29 | ROL-TESORERO-PAGOS | ROL-ASISTENTE-TESORERIA | N2←N1 |
| G30 | ROL-JEFE-CONTABILIDAD | ROL-ENCARGADO-NOMINA | N4←N1 |
| G31 | ROL-JEFE-CONTABILIDAD | ROL-REVISOR-ESTADOS-FINANCIEROS | N4←N2 |
| G32 | ROL-JEFE-CONTABILIDAD | ROL-ANALISTA-CONTROL-INTERNO | N4←N2 |
| G33 | ROL-JEFE-CONTABILIDAD | ROL-AUDITOR-EXTERNO-CONTABLE | N4←N2 |
| G34 | ROL-JEFE-CONTABILIDAD | ROL-ENCARGADO-CIERRE | N4←N2 |
| G35 | ROL-GERENTE-GENERAL | ROL-JEFE-FACTURACION-CREDITO | N5←N4 |
| G36 | ROL-GERENTE-GENERAL | ROL-JEFE-RRHH | N5←N4 |
| G37 | ROL-SUPERVISOR-FACT-COBRANZA | ROL-OPERADOR-FACT-RECURRENTE | N3←N1 |
| G38 | ROL-SUPERVISOR-FACT-COBRANZA | ROL-ENCARGADO-REPORTES-IVA | N3←N2 |
| G39 | ROL-SUPERVISOR-FACT-COBRANZA | ROL-ENCARGADO-RETENCIONES-PERCEPCIONES | N3←N2 |
| G40 | ROL-JEFE-INVENTARIOS | ROL-ANALISTA-MERMAS | N4←N2 |
| G41 | ROL-JEFE-INVENTARIOS | ROL-AUDITOR-INVENTARIO | N4←N2 |
| G42 | ROL-JEFE-INVENTARIOS | ROL-PLANIFICADOR-DEMANDA | N4←N2 |

---

## §H — Transporte y Almacenamiento

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Gerente General ─── ROL-GERENTE-GENERAL
              │
              ├── N4: Jefe de Logística ─── ROL-JEFE-LOGISTICA
              │     │
              │     ├── N3: Despachador de Flota ─── ROL-DESPACHADOR-FLOTA
              │     │     ├── N1: Chofer de Camión ─── ROL-CHOFER-CAMION
              │     │     │     └── N0: Remitente de Carga ─── ROL-EXT-REMITENTE-CARGA
              │     │     │           N0: Consignatario ─── ROL-EXT-CONSIGNATARIO
              │     │     ├── N1: Chofer de Taxi ─── ROL-CHOFER-TAXI
              │     │     │     └── N0: Pasajero Bus ─── ROL-EXT-PASAJERO-BUS
              │     │     ├── N1: Operador de Grúa ─── ROL-OPERADOR-GRUA
              │     │     └── N1: Auxiliar de Carga ─── ROL-AUXILIAR-CARGA
              │     │
              │     ├── N2: Coordinador de Distribución ─── ROL-COORD-DISTRIBUCION
              │     │     └── N0: Cliente de Courier ─── ROL-EXT-CLIENTE-COURIER
              │     │
              │     └── N1: Playero ─── ROL-PLAYERO
              │
              └── N0: Pasajero Aéreo ─── ROL-EXT-PASAJERO-AEREO
                    N0: Cliente de Almacenaje ─── ROL-EXT-CLIENTE-ALMACENAJE
                    N0: Agencia de Viajes ─── ROL-EXT-AGENCIA-VIAJES
```

| Arista | Padre (hereda de...) | Hijo (...hereda a) | Tipo |
|--------|---------------------|-------------------|------|
| H01 | ROL-GERENTE-GENERAL | ROL-JEFE-LOGISTICA | N5←N4 |
| H02 | ROL-JEFE-LOGISTICA | ROL-DESPACHADOR-FLOTA | N4←N3 |
| H03 | ROL-DESPACHADOR-FLOTA | ROL-CHOFER-CAMION | N3←N1 |
| H04 | ROL-CHOFER-CAMION | ROL-EXT-REMITENTE-CARGA | N1←N0 |
| H05 | ROL-DESPACHADOR-FLOTA | ROL-CHOFER-TAXI | N3←N1 |
| H06 | ROL-CHOFER-TAXI | ROL-EXT-PASAJERO-BUS | N1←N0 |
| H07 | ROL-JEFE-LOGISTICA | ROL-COORD-DISTRIBUCION | N4←N2 |
| H08 | ROL-COORD-DISTRIBUCION | ROL-EXT-CLIENTE-COURIER | N2←N0 |


---

## §I — Actividades de Alojamiento y Servicio de Comidas

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Gerente de Hotel ─── ROL-GERENTE-HOTEL
              │
              ├── N4: Chef / Jefe de Cocina ─── ROL-CHEF
              │     ├── N1: Cocinero ─── ROL-COCINERO
              │     └── N1: Bartender ─── ROL-BARTENDER
              │           └── N0: Comensal ─── ROL-EXT-COMENSAL
              │
              ├── N3: — (supervisor de turno no definido; usa ROL-SUPERVISOR-TIENDA genérico)
              │     ├── N1: Recepcionista de Hotel ─── ROL-RECEPCION-HOTEL
              │     │     └── N0: Huésped ─── ROL-EXT-HUESPED
              │     ├── N1: Mucama ─── ROL-MUCAMA
              │     └── N1: Mesero ─── ROL-MESERO
              │           └── N0: Cliente de Eventos ─── ROL-EXT-CLIENTE-EVENTOS
              │
              ├── N1: Lavandero ─── ROL-LAVANDERO
              │
              └── N0: Cliente de Delivery ─── ROL-EXT-CLIENTE-DELIVERY
                    N0: Cliente de Catering ─── ROL-EXT-CLIENTE-CATERING
                    N0: Huésped Temporal ─── ROL-EXT-HUESPED-TEMPORAL
```

| Arista | Padre (hereda de...) | Hijo (...hereda a) | Tipo |
|--------|---------------------|-------------------|------|
| I01 | ROL-GERENTE-HOTEL | ROL-CHEF | N5←N4 |
| I02 | ROL-CHEF | ROL-COCINERO | N4←N1 |
| I03 | ROL-CHEF | ROL-BARTENDER | N4←N1 |
| I04 | ROL-BARTENDER | ROL-EXT-COMENSAL | N1←N0 |
| I05 | ROL-GERENTE-HOTEL | ROL-RECEPCION-HOTEL | N5←N1 |
| I06 | ROL-RECEPCION-HOTEL | ROL-EXT-HUESPED | N1←N0 |
| I07 | ROL-GERENTE-HOTEL | ROL-MESERO | N5←N1 |
| I08 | ROL-MESERO | ROL-EXT-CLIENTE-EVENTOS | N1←N0 |


---

## §J — Información y Comunicaciones

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Gerente General ─── ROL-GERENTE-GENERAL
              │
              ├── N4: Jefe de IT ─── ROL-JEFE-IT
              │     ├── N2: SysAdmin ─── ROL-SYSADMIN
              │     │     └── N0: Suscriptor de Telecom ─── ROL-EXT-SUSCRIPTOR-TELECOM
              │     │           N0: Cliente de Cloud ─── ROL-EXT-CLIENTE-CLOUD
              │     ├── N2: Desarrollador ─── ROL-DESARROLLADOR
              │     │     └── N0: Cliente SaaS ─── ROL-EXT-CLIENTE-SAAS
              │     ├── N2: Especialista en Ciberseguridad ─── ROL-CIBERSEGURIDAD
              │     ├── N2: Diseñador UX/UI ─── ROL-DISENADOR-UX
              │     └── N2: Soporte Técnico ─── ROL-SOPORTE-TECNICO
              │           └── N0: Usuario de Plataforma ─── ROL-EXT-USUARIO-PLATAFORMA
              │
              ├── N4: Project Manager IT ─── ROL-PM-IT
              │
              ├── N2: Analista de Datos ─── ROL-ANALISTA-DATOS
              │
              └── N0: Anunciante ─── ROL-EXT-ANUNCIANTE
                    N0: Suscriptor de Medios ─── ROL-EXT-SUSCRIPTOR-MEDIOS
```

| Arista | Padre (hereda de...) | Hijo (...hereda a) | Tipo |
|--------|---------------------|-------------------|------|
| J01 | ROL-GERENTE-GENERAL | ROL-JEFE-IT | N5←N4 |
| J02 | ROL-JEFE-IT | ROL-SYSADMIN | N4←N2 |
| J03 | ROL-SYSADMIN | ROL-EXT-SUSCRIPTOR-TELECOM | N2←N0 |
| J04 | ROL-JEFE-IT | ROL-DESARROLLADOR | N4←N2 |
| J05 | ROL-DESARROLLADOR | ROL-EXT-CLIENTE-SAAS | N2←N0 |
| J06 | ROL-JEFE-IT | ROL-SOPORTE-TECNICO | N4←N2 |
| J07 | ROL-SOPORTE-TECNICO | ROL-EXT-USUARIO-PLATAFORMA | N2←N0 |
| J08 | ROL-GERENTE-GENERAL | ROL-ANALISTA-DATOS | N5←N2 |


---

## §K — Actividades Financieras y de Seguros

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Gerente de Sucursal Bancaria ─── ROL-GERENTE-BANCO
              │
              ├── N4: — (sin gerencia media específica)
              │
              ├── N3: Supervisor de Sucursal Bancaria ─── ROL-SUPERVISOR-BANCO
              │     ├── N1: Cajero Bancario ─── ROL-CAJERO-BANCO
              │     │     └── N0: Cuentahabiente ─── ROL-EXT-CUENTAHABIENTE
              │     │           N0: Beneficiario de Remesas ─── ROL-EXT-BENEFICIARIO-REMESAS
              │     │           N0: Cliente de Casa de Cambio ─── ROL-EXT-CLIENTE-CAMBIO
              │     ├── N1: Ejecutivo de Cuenta ─── ROL-EJECUTIVO-CUENTA
              │     │     └── N0: Ahorrista ─── ROL-EXT-AHORRISTA
              │     └── N1: Oficial de Créditos ─── ROL-OFICIAL-CREDITOS
              │           └── N0: Deudor ─── ROL-EXT-DEUDOR
              │                 N0: Solicitante de Crédito ─── ROL-EXT-SOLICITANTE-CREDITO
              │
              ├── N2: Analista de Riesgos ─── ROL-ANALISTA-RIESGOS
              ├── N2: Oficial de Cumplimiento ─── ROL-OFICIAL-CUMPLIMIENTO
              ├── N2: Tesorero ─── ROL-TESORERO
              ├── N2: Contador ─── ROL-CONTADOR
              ├── N2: Auditor Interno ─── ROL-AUDITOR-INTERNO
              │
              └── N0: Asegurado ─── ROL-EXT-ASEGURADO
                    N0: Beneficiario de Seguro ─── ROL-EXT-BENEFICIARIO-SEGURO
```

| Arista | Padre (hereda de...) | Hijo (...hereda a) | Tipo |
|--------|---------------------|-------------------|------|
| K01 | ROL-GERENTE-BANCO | ROL-SUPERVISOR-BANCO | N5←N3 |
| K02 | ROL-SUPERVISOR-BANCO | ROL-CAJERO-BANCO | N3←N1 |
| K03 | ROL-CAJERO-BANCO | ROL-EXT-CUENTAHABIENTE | N1←N0 |
| K04 | ROL-SUPERVISOR-BANCO | ROL-EJECUTIVO-CUENTA | N3←N1 |
| K05 | ROL-EJECUTIVO-CUENTA | ROL-EXT-AHORRISTA | N1←N0 |
| K06 | ROL-SUPERVISOR-BANCO | ROL-OFICIAL-CREDITOS | N3←N1 |
| K07 | ROL-OFICIAL-CREDITOS | ROL-EXT-DEUDOR | N1←N0 |
| K08 | ROL-GERENTE-BANCO | ROL-ANALISTA-RIESGOS | N5←N2 |
| K09 | ROL-GERENTE-BANCO | ROL-OFICIAL-CUMPLIMIENTO | N5←N2 |
| K10 | ROL-GERENTE-BANCO | ROL-CONTADOR | N5←N2 |


---

## §L — Actividades Inmobiliarias

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Gerente General ─── ROL-GERENTE-GENERAL
              │
              ├── N1: Administrativo ─── ROL-ADMINISTRATIVO
              │     └── N0: Inquilino ─── ROL-EXT-INQUILINO
              │           N0: Comprador de Inmueble ─── ROL-EXT-COMPRADOR-INMUEBLE-L
              │
              ├── N0: Propietario Vendedor ─── ROL-EXT-PROPIETARIO-VENDEDOR
              │       N0: Inversionista Inmobiliario ─── ROL-EXT-INVERSIONISTA-INMOB
              │
              └── N0: Tasador ─── ROL-EXT-TASADOR
```

| Arista | Padre (hereda de...) | Hijo (...hereda a) | Tipo |
|--------|---------------------|-------------------|------|
| L01 | ROL-GERENTE-GENERAL | ROL-ADMINISTRATIVO | N5←N1 |
| L02 | ROL-ADMINISTRATIVO | ROL-EXT-INQUILINO | N1←N0 |
| L03 | ROL-ADMINISTRATIVO | ROL-EXT-COMPRADOR-INMUEBLE-L | N1←N0 |


---

## §M — Actividades Profesionales, Científicas y Técnicas

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Gerente General ─── ROL-GERENTE-GENERAL
              │
              ├── N2: Contador ─── ROL-CONTADOR
              │     ├── N1: Asistente Contable ─── ROL-ASISTENTE-CONTABLE
              │     └── N0: Cliente de Contabilidad ─── ROL-EXT-CLIENTE-CONTABLE
              │
              ├── N2: Ingeniero Civil ─── ROL-INGENIERO-CIVIL
              │     └── N0: Cliente de Arquitectura ─── ROL-EXT-CLIENTE-ARQUITECTO
              │
              ├── N0: Cliente de Servicios Jurídicos ─── ROL-EXT-CLIENTE-ABOGADO
              │       N0: Cliente de Consultoría ─── ROL-EXT-CLIENTE-CONSULTORIA
              │       N0: Dueño de Mascota ─── ROL-EXT-DUENO-MASCOTA
              │       N0: Cliente de Publicidad ─── ROL-EXT-CLIENTE-PUBLICIDAD
              │       N0: Cliente de I+D ─── ROL-EXT-CLIENTE-ID
              │
              └── N2: Analista de Datos ─── ROL-ANALISTA-DATOS
```

| Arista | Padre (hereda de...) | Hijo (...hereda a) | Tipo |
|--------|---------------------|-------------------|------|
| M01 | ROL-GERENTE-GENERAL | ROL-CONTADOR | N5←N2 |
| M02 | ROL-CONTADOR | ROL-ASISTENTE-CONTABLE | N2←N1 |
| M03 | ROL-ASISTENTE-CONTABLE | ROL-EXT-CLIENTE-CONTABLE | N1←N0 |
| M04 | ROL-GERENTE-GENERAL | ROL-INGENIERO-CIVIL | N5←N2 |
| M05 | ROL-INGENIERO-CIVIL | ROL-EXT-CLIENTE-ARQUITECTO | N2←N0 |
| M06 | ROL-GERENTE-GENERAL | ROL-ANALISTA-DATOS | N5←N2 |


---

## §N — Actividades de Servicios Administrativos y de Apoyo

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Gerente General ─── ROL-GERENTE-GENERAL
              │
              ├── N4: Jefe de RRHH ─── ROL-JEFE-RRHH
              │     └── N2: Analista de RRHH ─── ROL-ANALISTA-RRHH
              │           └── N0: Postulante de Empleo ─── ROL-EXT-POSTULANTE-EMPLEO
              │
              ├── N3: Jefe de Seguridad ─── ROL-JEFE-SEGURIDAD
              │     ├── N1: Portero ─── ROL-PORTERO
              │     │     └── N0: Cliente de Seguridad Privada ─── ROL-EXT-CLIENTE-SEGURIDAD
              │     ├── N1: Operador de CCTV ─── ROL-OPERADOR-CCTV
              │     └── N1: Sereno ─── ROL-SERENO
              │
              ├── N1: Encargado de Limpieza ─── ROL-ENCARGADO-LIMPIEZA
              │     └── N0: Cliente de Limpieza ─── ROL-EXT-CLIENTE-LIMPIEZA
              │
              └── N0: Viajero ─── ROL-EXT-VIAJERO
                    N0: Cliente de Alquiler de Equipos ─── ROL-EXT-CLIENTE-ALQUILER
                    N0: Expositor de Feria ─── ROL-EXT-EXPOSITOR-FERIA
                    N0: Cliente de Call Center ─── ROL-EXT-CLIENTE-CALLCENTER
```

| Arista | Padre (hereda de...) | Hijo (...hereda a) | Tipo |
|--------|---------------------|-------------------|------|
| N01 | ROL-GERENTE-GENERAL | ROL-JEFE-RRHH | N5←N4 |
| N02 | ROL-JEFE-RRHH | ROL-ANALISTA-RRHH | N4←N2 |
| N03 | ROL-ANALISTA-RRHH | ROL-EXT-POSTULANTE-EMPLEO | N2←N0 |
| N04 | ROL-GERENTE-GENERAL | ROL-JEFE-SEGURIDAD | N5←N3 |
| N05 | ROL-JEFE-SEGURIDAD | ROL-PORTERO | N3←N1 |
| N06 | ROL-PORTERO | ROL-EXT-CLIENTE-SEGURIDAD | N1←N0 |
| N07 | ROL-GERENTE-GENERAL | ROL-ENCARGADO-LIMPIEZA | N5←N1 |
| N08 | ROL-ENCARGADO-LIMPIEZA | ROL-EXT-CLIENTE-LIMPIEZA | N1←N0 |


---

## §O — Administración Pública y Defensa

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Director / Máxima Autoridad ─── ROL-GERENTE-GENERAL
              │
              ├── N4: Jefe de RRHH ─── ROL-JEFE-RRHH
              ├── N4: Jefe de IT ─── ROL-JEFE-IT
              │     └── N2: SysAdmin ─── ROL-SYSADMIN
              │
              ├── N2: Contador ─── ROL-CONTADOR
              │     ├── N2: Contador Tributario ─── ROL-CONTADOR-TRIBUTARIO
              │     └── N2: Encargado de Presupuesto ─── ROL-ENCARGADO-PRESUPUESTO
              │
              ├── N1: Administrativo ─── ROL-ADMINISTRATIVO
              │     ├── N0: Ciudadano ─── ROL-EXT-CIUDADANO
              │     │       N0: Elector ─── ROL-EXT-ELECTOR
              │     │       N0: Administrado ─── ROL-EXT-ADMINISTRADO
              │     └── N0: Beneficiario Social ─── ROL-EXT-BENEFICIARIO-SOCIAL
              │
              ├── N1: Portero ─── ROL-PORTERO
              │     └── N0: Postulante a Licitación ─── ROL-EXT-POSTULANTE-LICITACION
              │
              └── N0: Conscripto ─── ROL-EXT-CONSCRIPTO
```

| Arista | Padre (hereda de...) | Hijo (...hereda a) | Tipo |
|--------|---------------------|-------------------|------|
| O01 | ROL-GERENTE-GENERAL | ROL-JEFE-RRHH | N5←N4 |
| O02 | ROL-GERENTE-GENERAL | ROL-JEFE-IT | N5←N4 |
| O03 | ROL-JEFE-IT | ROL-SYSADMIN | N4←N2 |
| O04 | ROL-GERENTE-GENERAL | ROL-CONTADOR | N5←N2 |
| O05 | ROL-CONTADOR | ROL-CONTADOR-TRIBUTARIO | N2←N2 |
| O06 | ROL-GERENTE-GENERAL | ROL-ADMINISTRATIVO | N5←N1 |
| O07 | ROL-ADMINISTRATIVO | ROL-EXT-CIUDADANO | N1←N0 |
| O08 | ROL-GERENTE-GENERAL | ROL-PORTERO | N5←N1 |
| O09 | ROL-PORTERO | ROL-EXT-POSTULANTE-LICITACION | N1←N0 |


---

## §P — Enseñanza / Educación

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Director de Colegio ─── ROL-DIRECTOR-COLEGIO
              │
              ├── N4: — (sin gerencia media; director asume ese rol)
              │
              ├── N2: Contador ─── ROL-CONTADOR
              │     └── N1: Asistente Contable ─── ROL-ASISTENTE-CONTABLE
              │
              ├── N1: Secretario Académico ─── ROL-SECRETARIO-ACADEMICO
              │     │
              │     └── Profesional: Docente ─── ROL-DOCENTE
              │           │
              │           ├── N1: Auxiliar Docente ─── ROL-AUXILIAR-DOCENTE
              │           │     └── N0: Alumno Universitario ─── ROL-EXT-ALUMNO-UNIVERSITARIO
              │           │           N0: Alumno de Postgrado ─── ROL-EXT-ALUMNO-POSTGRADO
              │           │           N0: Alumno Técnico ─── ROL-EXT-ALUMNO-TECNICO
              │           │
              │           ├── N0: Padre / Tutor ─── ROL-EXT-TUTOR-EDUCATIVO
              │           │     ├── N0: Alumno de Primaria ─── ROL-EXT-ALUMNO-PRIMARIA
              │           │     ├── N0: Alumno de Secundaria ─── ROL-EXT-ALUMNO-SECUNDARIA
              │           │     └── N0: Alumno Inicial ─── ROL-EXT-ALUMNO-INICIAL
              │           │
              │           ├── N0: Postulante ─── ROL-EXT-POSTULANTE-EDUCATIVO
              │           └── N0: Egresado ─── ROL-EXT-EGRESADO
              │
              └── N1: Portero / Conserje Escolar ─── ROL-CONSERJE-ESCUELA
                    N1: Bibliotecario ─── ROL-BIBLIOTECARIO
```

| Arista | Padre | Hijo | Tipo |
|--------|-------|------|------|
| P01 | ROL-DIRECTOR-COLEGIO | ROL-CONTADOR | N5←N2 |
| P02 | ROL-DIRECTOR-COLEGIO | ROL-SECRETARIO-ACADEMICO | N5←N1 |
| P03 | ROL-SECRETARIO-ACADEMICO | ROL-DOCENTE | N1←Prof |
| P04 | ROL-DOCENTE | ROL-AUXILIAR-DOCENTE | Prof←N1 |
| P05 | ROL-AUXILIAR-DOCENTE | ROL-EXT-ALUMNO-UNIVERSITARIO | N1←N0 |
| P06 | ROL-DOCENTE | ROL-EXT-TUTOR-EDUCATIVO | Prof←N0 |
| P07 | ROL-EXT-TUTOR-EDUCATIVO | ROL-EXT-ALUMNO-PRIMARIA | N0←N0 |
| P08 | ROL-EXT-TUTOR-EDUCATIVO | ROL-EXT-ALUMNO-SECUNDARIA | N0←N0 |
| P09 | ROL-EXT-TUTOR-EDUCATIVO | ROL-EXT-ALUMNO-INICIAL | N0←N0 |

---

## §Q — Salud Humana y Asistencia Social

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Director de Clínica ─── ROL-DIRECTOR-COLEGIO  [genérico N5]
              │
              ├── N4: Administrador de Clínica ─── ROL-ADMIN-CLINICA
              │     │
              │     ├── Profesional: Médico General ─── ROL-MEDICO-GENERAL
              │     │     │
              │     │     ├── Profesional: Enfermero ─── ROL-ENFERMERO
              │     │     │     ├── N1: Auxiliar de Enfermería ─── ROL-AUXILIAR-ENFERMERIA
              │     │     │     │     └── N0: Paciente Ambulatorio ─── ROL-EXT-PACIENTE-AMBULATORIO
              │     │     │     │           N0: Paciente de Emergencia ─── ROL-EXT-PACIENTE-EMERGENCIA
              │     │     │     └── N0: Paciente Hospitalizado ─── ROL-EXT-PACIENTE-HOSPITALIZADO
              │     │     │           N0: Paciente de Cirugía ─── ROL-EXT-PACIENTE-CIRUGIA
              │     │     │
              │     │     ├── N2: Paramédico ─── ROL-PARAMEDICO
              │     │     │
              │     │     └── N0: Asegurado de Salud ─── ROL-EXT-ASEGURADO-SALUD
              │     │           N0: Familiar de Paciente ─── ROL-EXT-FAMILIAR-PACIENTE
              │     │           N0: Donante ─── ROL-EXT-DONANTE
              │     │
              │     ├── N3: Jefe de Farmacia ─── ROL-JEFE-FARMACIA
              │     │     └── Profesional: Farmacéutico ─── ROL-FARMACEUTICO
              │     │           └── N0: Cliente de Farmacia ─── ROL-EXT-CLIENTE-FARMACIA-Q
              │     │
              │     ├── N1: Recepcionista de Consultorio ─── ROL-RECEPCION-CLINICA
              │     │
              │     └── N2: Contador ─── ROL-CONTADOR
              │
              └── N0: Paciente de Laboratorio ─── ROL-EXT-PACIENTE-LABORATORIO
                    N0: Beneficiario de Asistencia Social ─── ROL-EXT-BENEFICIARIO-ASISTENCIA
```

| Arista | Padre | Hijo | Tipo |
|--------|-------|------|------|
| Q01 | ROL-DIRECTOR-COLEGIO | ROL-ADMIN-CLINICA | N5←N4 |
| Q02 | ROL-ADMIN-CLINICA | ROL-MEDICO-GENERAL | N4←Prof |
| Q03 | ROL-MEDICO-GENERAL | ROL-ENFERMERO | Prof←Prof |
| Q04 | ROL-ENFERMERO | ROL-AUXILIAR-ENFERMERIA | Prof←N1 |
| Q05 | ROL-AUXILIAR-ENFERMERIA | ROL-EXT-PACIENTE-AMBULATORIO | N1←N0 |
| Q06 | ROL-ENFERMERO | ROL-EXT-PACIENTE-HOSPITALIZADO | Prof←N0 |
| Q07 | ROL-ADMIN-CLINICA | ROL-JEFE-FARMACIA | N4←N3 |
| Q08 | ROL-JEFE-FARMACIA | ROL-FARMACEUTICO | N3←Prof |
| Q09 | ROL-FARMACEUTICO | ROL-EXT-CLIENTE-FARMACIA-Q | Prof←N0 |

---

## §R — Actividades Artísticas, de Entretenimiento y Recreativas

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Gerente General ─── ROL-GERENTE-GENERAL
              │
              ├── N1: Administrativo ─── ROL-ADMINISTRATIVO
              │     └── N0: Espectador ─── ROL-EXT-ESPECTADOR
              │           N0: Visitante de Museo ─── ROL-EXT-VISITANTE-MUSEO
              │
              ├── N0: Deportista ─── ROL-EXT-DEPORTISTA
              │       N0: Socio de Club ─── ROL-EXT-SOCIO-CLUB
              │       N0: Cliente de Gimnasio ─── ROL-EXT-CLIENTE-GIMNASIO
              │
              └── N0: Jugador de Juegos de Azar ─── ROL-EXT-JUGADOR-AZAR
```

| Arista | Padre (hereda de...) | Hijo (...hereda a) | Tipo |
|--------|---------------------|-------------------|------|
| R01 | ROL-GERENTE-GENERAL | ROL-ADMINISTRATIVO | N5←N1 |
| R02 | ROL-ADMINISTRATIVO | ROL-EXT-ESPECTADOR | N1←N0 |
| R03 | ROL-ADMINISTRATIVO | ROL-EXT-VISITANTE-MUSEO | N1←N0 |


---

## §S — Otras Actividades de Servicios

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Gerente General ─── ROL-GERENTE-GENERAL
              │
              ├── N1: Administrativo ─── ROL-ADMINISTRATIVO
              │
              ├── N0: Cliente de Peluquería ─── ROL-EXT-CLIENTE-PELUQUERIA
              │       N0: Cliente de Lavandería ─── ROL-EXT-CLIENTE-LAVANDERIA
              │       N0: Cliente de Funeraria ─── ROL-EXT-CLIENTE-FUNERARIA
              │       N0: Cliente de Reparación ─── ROL-EXT-CLIENTE-REPARACION
              │
              ├── N0: Feligrés ─── ROL-EXT-FELIGRES
              │       N0: Afiliado Sindical ─── ROL-EXT-AFILIADO-SINDICAL
              │
              └── N0: Miembro de Asociación Empresarial ─── ROL-EXT-MIEMBRO-ASOCIACION
```

| Arista | Padre (hereda de...) | Hijo (...hereda a) | Tipo |
|--------|---------------------|-------------------|------|
| S01 | ROL-GERENTE-GENERAL | ROL-ADMINISTRATIVO | N5←N1 |


---

## §T — Actividades de los Hogares como Empleadores

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N0: Empleador Doméstico ─── ROL-EXT-EMPLEADOR-DOMESTICO
              │
              └── N0: Trabajador del Hogar ─── ROL-EXT-TRABAJADOR-HOGAR

[Nota: sector mínimo. Sin jerarquía N5–N1. El empleador es el cliente directo
 del Admin Tenant; el trabajador del hogar hereda al empleador.]
```

| Arista | Padre (hereda de...) | Hijo (...hereda a) | Tipo |
|--------|---------------------|-------------------|------|
| T01 | ROL-EXT-EMPLEADOR-DOMESTICO | ROL-EXT-TRABAJADOR-HOGAR | N0←N0 |


---

## §U — Actividades de Organizaciones y Órganos Extraterritoriales

```
S016 (Admin Tenant)
  └── S017 (Admin Sucursal)
        └── N5: Director ─── ROL-GERENTE-GENERAL
              │
              ├── N1: Administrativo ─── ROL-ADMINISTRATIVO
              │
              └── N0: Diplomático ─── ROL-EXT-DIPLOMATICO
                    N0: Beneficiario de Cooperación ─── ROL-EXT-BENEFICIARIO-COOPERACION
                    N0: Solicitante de Visa ─── ROL-EXT-SOLICITANTE-VISA
```

| Arista | Padre (hereda de...) | Hijo (...hereda a) | Tipo |
|--------|---------------------|-------------------|------|
| U01 | ROL-GERENTE-GENERAL | ROL-ADMINISTRATIVO | N5←N1 |
| U02 | ROL-ADMINISTRATIVO | ROL-EXT-DIPLOMATICO | N1←N0 |
| U03 | ROL-ADMINISTRATIVO | ROL-EXT-BENEFICIARIO-COOPERACION | N1←N0 |
| U04 | ROL-ADMINISTRATIVO | ROL-EXT-SOLICITANTE-VISA | N1←N0 |


---

## Tabla Transversal — Visitantes y Contratistas (todos los sectores)

Los roles E140–E146 son transversales: aplican a cualquier sector CAEB. Su jerarquía
depende del contexto donde se usen:

```
S017 (Admin Sucursal) ─── [cualquier sector]
  │
  ├── N1: Portero / Recepcionista ─── (ROL-PORTERO o ROL-RECEPCIONISTA)
  │     │
  │     ├── N0: Visitante General ─── ROL-EXT-VISITANTE
  │     ├── N0: Visitante Proveedor ─── ROL-EXT-VISITANTE-PROVEEDOR
  │     ├── N0: Visitante Auditor ─── ROL-EXT-VISITANTE-AUDITOR
  │     └── N0: Visitante VIP ─── ROL-EXT-VISITANTE-VIP
  │
  └── N0: Técnico de Servicio ─── ROL-EXT-TECNICO-SERVICIO
        N0: Contratista de Obra Menor ─── ROL-EXT-CONTRATISTA-OBRA
        N0: Técnico Instalador ─── ROL-EXT-TECNICO-INSTALADOR
```

| Arista | Padre | Hijo | Tipo |
|--------|-------|------|------|
| V01 | ROL-PORTERO | ROL-EXT-VISITANTE | N1←N0 |
| V02 | ROL-PORTERO | ROL-EXT-VISITANTE-PROVEEDOR | N1←N0 |
| V03 | ROL-PORTERO | ROL-EXT-VISITANTE-AUDITOR | N1←N0 |
| V04 | ROL-PORTERO | ROL-EXT-VISITANTE-VIP | N1←N0 |

---

## Resumen de Aristas Totales

| Sector | Aristas documentadas | Roles en la cadena |
|--------|---------------------|-------------------|
| A — Agricultura | 8 | 12 |
| B — Minería | 8 | 13 |
| C — Industria | 15 | 24 |
| D — Electricidad | 7 | 9 |
| E — Agua | 5 | 7 |
| F — Construcción | 10 | 14 |
| **G — Comercio** | **42** | **78** |
| H — Transporte | 8 | 17 |
| I — Hotelería | 8 | 14 |
| J — Información | 8 | 16 |
| K — Financieras | 10 | 19 |
| L — Inmobiliarias | 3 | 8 |
| M — Profesionales | 6 | 11 |
| N — Servicios Admin | 8 | 16 |
| O — Admin Pública | 9 | 18 |
| **P — Educación** | **9** | **19** |
| **Q — Salud** | **9** | **19** |
| R — Arte | 3 | 8 |
| S — Otros Servicios | 1 | 11 |
| T — Hogares | 1 | 2 |
| U — Extraterritoriales | 4 | 7 |
| VIS — Visitantes | 4 | 7 |
| **TOTAL** | **186** | **~342** |

---

*BAUTH-CADENAS-JERARQUIA v1.1 · 2026-06-19 · SKULL · Anexo al Catálogo de Roles Empresariales v2.0 · 42 nuevos roles integrados (facturación, contabilidad, inventarios) · NIST RBAC §4.2 DAG*
