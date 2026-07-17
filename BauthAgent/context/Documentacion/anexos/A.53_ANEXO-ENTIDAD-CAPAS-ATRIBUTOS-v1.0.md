# A.53 — La Entidad como Acumulador de Capas de Atributos
## Tipo C — Justificación del modelo de dominios como capas acumulativas durante el ciclo de vida

**Versión:** 1.0.0
**Fecha:** 2026-07-15
**Tipo de anexo:** C (justificación de decisión técnica)
**Respalda a:** [1.06 D00 Identidad v2.1.0 §2, §12](../1.06_MANUAL-D00-IDENTIDAD-v2.0.md) — catálogo universal, capas de atributos
**Fuentes absorbidas:** `ANALISIS-ENTIDAD-CAPAS-ATRIBUTOS-v1.0.md`
**Normas base:** ISO 24760-2:2025 · ISO 9001:2015

---

## §1 Propósito

Demostrar con ejemplos concretos que una entidad atraviesa múltiples dominios durante su
ciclo de vida, acumulando capas de atributos. La entidad es UNA. Sus atributos son capas
que se agregan y se quitan. La historia se preserva. Nada se borra.

**Cómo citarlo:** `A.53 §N`

---

## §2 Toyota Carina 97 — 5 dominios, 28 años

```
1997 ─ FÁBRICA (origen)
       marca: Toyota, modelo: Carina, año: 1997, motor: 1.8L, chasis: XYZ

1997 ─ CONCESIONARIO (comercial)
       color: rojo, precio: $15K, garantía: 3 años

2010 ─ María Gómez (propiedad)
       placa: ABC-1234, dueña: María Gómez, seguro: SegSA

2015 ─ Pedro Flores (propiedad)    ← capa anterior ARCHIVADA, historia preservada
2018 ─ Marcos Rojas (propiedad)    ← capa anterior ARCHIVADA
2020 ─ ROBO (siniestrado)          ← denuncia policial, seguro activado
2021 ─ DESGUACE (desactivado)      ← partes_recicladas: motor, chasis

5 dueños. 1 robo. 1 siniestro. 28 años. Mismo entidad_id. Historia completa.
```

## §3 Juan Pérez — 8 dominios, 45 años (bitácora completa)

```
1985-06-15  NACIMIENTO
  ┌─ civil: ACTIVO
  │   given_name: Juan · family_name: Pérez · second_family: Gómez
  │   birth_date: 1985-06-15 · gender: M · nationality: BOL

1991-02-10  PRIMARIA
  ┌─ educativo: ACTIVO
  │   nivel: primaria · institucion: Escuela Fiscal #3 · matricula: ESC-1991-001

1997-02-05  SECUNDARIA
  ├─ educativo: primaria → ARCHIVADO (historia preservada)
  └─ educativo: ACTIVO
        nivel: secundaria · institucion: Colegio Nacional Bolívar · matricula: COL-1997-045

2003-03-01  UNIVERSIDAD
  ├─ educativo: secundaria → ARCHIVADO
  └─ educativo: ACTIVO
        nivel: universidad · institucion: UMSA · carrera: Administración
        matricula: UNI-2003-112 · titulo: Licenciatura (2008)

2004-03-10  CÉDULA DE IDENTIDAD
  ┌─ civil: CI 1234567 LP emitido por SEGIP. Vence 2014-03-10.

2010-06-01  PRIMER EMPLEO — SKULL-CORP
  ├─ laboral: ACTIVO
  │   empresa: SKULL-CORP · cargo: Vendedor Junior · employee_code: VEN-2010-003
  │   sucursal: Norte · pos: CAJA-01 · salary: $4,500
  ├─ autenticacion: ACTIVO
  │   sistema: SKULL-CORP · username: jperez@skull.com · MFA: TOTP

2011-01-10  CLIENTE TIENDA INTERNA
  ┌─ cliente: ACTIVO · customer_since: 2011-01-10 · credit_limit: $5,000

2012-11-20  MATRIMONIO
  ┌─ familiar: ACTIVO · marital_status: MARRIED · conyuge: Laura Flores

2014-05-10  NACIMIENTO HIJO
  ┌─ familiar: dependiente Mateo Pérez Flores · parentesco: hijo

2014-02-20  RENOVACIÓN CI
  ├─ civil: CI 1234567 LP emitido 2004 → ARCHIVADO
  └─ civil: CI 1234567 LP emitido 2014. Vence 2024-02-20.

2015-03-15  CAMBIO DE EMPLEO — TECNOLOGÍA AVANZADA
  ├─ laboral: SKULL-CORP → ARCHIVADO (5 años, 3 aumentos: $4500→$5200→$5800)
  ├─ autenticacion: SKULL-CORP → REVOCADO
  ├─ laboral: ACTIVO
  │   empresa: TECNOLOGÍA AVANZADA SA · cargo: Vendedor Senior
  │   employee_code: TEC-2015-017 · salary: $7,000
  └─ autenticacion: ACTIVO
        sistema: TECNOLOGÍA AVANZADA · username: juan.perez@tecav.com · MFA: TOTP

2017-11-03  NACIMIENTO HIJA
  ┌─ familiar: dependiente Sofía Pérez Flores · parentesco: hija

2018-08-12  INTERNACIÓN — APENDICITIS
  ├─ salud: Hospital La Paz · Dr. Ramírez · apendicectomía · alta 2018-08-15
  └─ salud: alergia penicilina descubierta. Grupo sanguíneo O+.

2019-03-20  ACCIDENTE LABORAL
  └─ salud: Clínica Norte · fractura tobillo · Dra. López · fisioterapia 6 meses

2020-01-10  DESPIDO — TECNOLOGÍA AVANZADA
  ├─ laboral: TECNOLOGÍA AVANZADA → ARCHIVADO (5 años, 2 aumentos: $7000→$7500→$8200)
  ├─ autenticacion: TECNOLOGÍA AVANZADA → REVOCADO
  └─ proveedor: ACTIVO
        JUANPÉREZ CONSULTORÍAS · NIT: 1234567014 · servicios: capacitación, asesoría
        clientes: SKULL-CORP ($500/mes), TECNOLOGÍA AVANZADA SA ($300/mes)

2020-02-15  NUEVO EMPLEO — COMERCIAL BOLIVIA
  ├─ laboral: ACTIVO
  │   empresa: COMERCIAL BOLIVIA SA · cargo: Jefe de Ventas
  │   employee_code: COM-2020-009 · salary: $9,000 · equipo: 4 vendedores
  └─ autenticacion: ACTIVO
        sistema: COMERCIAL BOLIVIA · username: jperez@comercialbo.com · MFA: TOTP+WebAuthn

2020-06-01  PRODUCTOR — PASTELITOS
  └─ productor: ACTIVO
        producto: pastelitos artesanales · cliente: TECNOLOGÍA AVANZADA (servicio de té)
        ingresos: $200/mes adicionales

2023-06-30  CIERRE DE COMERCIAL BOLIVIA
  ├─ laboral: COMERCIAL BOLIVIA → ARCHIVADO (3 años, $9000)
  └─ autenticacion: COMERCIAL BOLIVIA → REVOCADO

2023-07-01  DESEMPLEADO — CUENTA PROPIA
  ├─ laboral: DESEMPLEADO (sin employer activo)
  ├─ proveedor: ACTIVO (consultoría sigue)
  ├─ productor: ACTIVO (pastelitos siguen)
  ├─ cliente: ACTIVO (sigue comprando en tiendas)
  └─ autenticacion: ACTIVO (cuenta personal jperez@gmail.com)

2026-07-14  HOY — 8 dominios, 41 años
  ┌─ civil: ACTIVO (41 años)
  ├─ familiar: ACTIVO (casado, 2 hijos)
  ├─ cliente: ACTIVO (13 años)
  ├─ proveedor: ACTIVO (6 años)
  ├─ productor: ACTIVO (4 años)
  ├─ fiscal: ACTIVO (NIT persona natural)
  ├─ propietario: ACTIVO (casa propia desde 2015, auto Toyota Carina)
  └─ salud: historial preservado (2 hospitalizaciones, 3 consultas, 5 vacunas)

  ARCHIVADO (historia completa preservada):
  ├─ laboral: 3 empleos en 13 años (SKULL-CORP, TEC AVANZADA, COMERCIAL BOLIVIA)
  ├─ autenticacion: 3 cuentas corporativas revocadas
  ├─ educativo: primaria, secundaria, universidad
  └─ civil: CI 2004, pasaporte 2018-2028

2030-01-10  FALLECIMIENTO
  └─ civil: estado → FALLECIDO · fecha_defunción: 2030-01-10 · causa: infarto
     Todos los dominios activos → ARCHIVADOS
     Retención legal: 10 años (Ley 843 Bolivia) → purga en 2040
     45 años de historia. 8 dominios. +60 atributos. NADA se borra.
```

## §4 María Gómez — 5 dominios, dueña del Toyota Carina

```
1978-03-22  NACIMIENTO
  ┌─ civil: María Gómez Flores · CI: 2345678 CB · La Paz

1995-02-10  EMPLEO — SKULL-CORP
  ┌─ laboral: ACTIVO · cargo: Cajera · employee_code: CAJ-1995-012

2000-06-01  PROMOCIÓN A SUPERVISORA
  └─ laboral: cargo → Supervisora de Cajas · salary: $3,500

2010-05-15  COMPRA DEL TOYOTA CARINA 97
  ┌─ propietario: ACTIVO
      bien: Toyota Carina 97 · placa: ABC-1234 · valor: $8,500
      vendedor: CONCESIONARIO TOYOTA · financiamiento: 36 cuotas

2015-09-01  VENTA DEL AUTO A PEDRO FLORES
  ├─ propietario: María Gómez (2010-2015) → ARCHIVADO
  └─ propietario: Pedro Flores → ACTIVO

2020-03-01  JUBILACIÓN
  ├─ laboral: SKULL-CORP (25 años) → ARCHIVADO
  └─ autenticacion: SKULL-CORP → REVOCADO
  └─ cliente: ACTIVO (sigue comprando)
  └─ salud: ACTIVO (chequeos regulares)

2026-07-14  HOY — 68 años
  ┌─ civil: ACTIVO · CI vigente · viuda (esposo falleció 2018)
  ├─ cliente: ACTIVO · tarjeta de descuento jubilados
  ├─ salud: ACTIVO · hipertensión controlada · Dr. Martínez
  ├─ propietario: casa propia · La Paz
  └─ historial preservado: 25 años laboral, dueña del Carina 5 años
```

## §5 DEPO Bolivia — 6 dominios simultáneos

```
DEPO es simultáneamente: cliente + proveedor + productor + empleador + propietario + financiero.
6 dominios activos. Una entidad. Sin duplicación.
```

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-15 | Primera edición. Absorbe ANALISIS-ENTIDAD-CAPAS-ATRIBUTOS-v1.0.md. |
