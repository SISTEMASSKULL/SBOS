# BAUTH D00 — Prueba de Escritorio v3.0: Pos, Actor, Rol — Separación Conceptual
**Versión:** 3.0 · **Fecha:** 2026-07-07 · **Autor:** bauth-developer
**Propósito:** Corregir la confusión Pos/Actor/Rol. Mostrar el modelo con ejemplos reales
complejos y abundancia de propiedades en idn_atributo.

---

## 1. El problema que el usuario identificó — y tiene razón

En los ejemplos anteriores se escribió:

```
[Pos]  Estación Enfermería E3-04    (tipo: TERMINAL)
  └─ [Actor]  Dr. Mamani
```

Esto SE PARECE a:
```
[Rol]  Médico de UCI
  └─ [Usuario]  Dr. Mamani inscrito en ese rol
```

El usuario tiene razón: los nombres de Pos sonaban a roles funcionales,
y Actor-bajo-Pos parecía Usuario-inscrito-en-Rol.

---

## 2. Aclaración definitiva — Tres capas distintas

```
┌─────────────────────────────────────────────────────────────────────┐
│  CAPA 1 — ORG TREE (D00)   "¿Dónde existe la entidad?"             │
│                                                                     │
│  Pos    = punto físico o virtual de INTERACCIÓN                     │
│           (una máquina, un terminal, una puerta, un API endpoint)   │
│           Ejemplos CORRECTOS: PC-Caja-01, Lector-RFID-Entrada,     │
│                               Socket-Unix-bAuth, Terminal-03       │
│           Ejemplos INCORRECTOS: "Cajero", "Control Calidad"         │
│                                 (esos son roles, no dispositivos)   │
│                                                                     │
│  Actor  = la ENTIDAD que existe en la organización                  │
│           (tipo: HUMAN, SERVICE, DEVICE, BOT, FEDERATED, AI_AGENT) │
│           Su "tipo" NO es su rol — es su naturaleza ontológica      │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│  CAPA 2 — ROLE SYSTEM (D1-D12, BitMask)   "¿Qué puede hacer?"      │
│                                                                     │
│  Rol   = función/permisos del actor                                 │
│          (CAJERO, MÉDICO, ADMIN, SUPERVISOR, AUDITOR)               │
│          Vive en privilege_role_atom + BitMask 64-bit               │
│          NO pertenece al árbol org (D00)                            │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│  CAPA 3 — ctx_id (sesión viva)   "¿Quién, dónde, con qué rol?"     │
│                                                                     │
│  ctx_id = UUIDv7                                                    │
│    + átomo IDENTIDAD: D00.org.tenant.X                              │
│    + átomo IDENTIDAD: D00.org.bDomain.Y                             │
│    + átomo IDENTIDAD: D00.org.bSubDomain.Z                          │
│    + átomo IDENTIDAD: D00.org.pos.POS_USADO       ← dispositivo    │
│    + átomo IDENTIDAD: D1.org.rol.CAJERO           ← rol (D1, no D0)│
│    + estado sesión: trust_level, loa, risk_score                    │
└─────────────────────────────────────────────────────────────────────┘
```

**La separación es exacta:**
- Pos en D00 = el dispositivo físico o virtual (donde ocurre la interacción)
- Rol en D1 = la función/permisos (lo que puede hacer el actor)
- ctx_id los combina en runtime — ninguno reemplaza al otro

---

## 3. La relación Actor ↔ Pos es M:N, no 1:1

El árbol D00 declara EXISTENCIA, no asignación permanente.

```
bSubDomain: Plataforma de Cajas (Sucursal Miraflores)
  │
  ├── Pos: PC-Caja-01    (dispositivo registrado aquí)
  ├── Pos: PC-Caja-02    (dispositivo registrado aquí)
  ├── Pos: PC-Caja-03    (dispositivo registrado aquí)
  │
  ├── Actor: López María  (persona registrada en esta unidad)
  └── Actor: García Juan  (persona registrada en esta unidad)

  En el turno mañana:
    ctx_id López: tenant.banco.sucursal.PC-Caja-01.CAJERO
    ctx_id García: tenant.banco.sucursal.PC-Caja-02.CAJERO

  En el turno tarde:
    ctx_id López: tenant.banco.sucursal.PC-Caja-02.CAJERO  ← misma persona, otro dispositivo
    ctx_id García: tenant.banco.sucursal.PC-Caja-03.CAJERO

  El supervisor puede usar cualquier PC para supervisar:
    ctx_id Supervisor: tenant.banco.sucursal.PC-Caja-01.SUPERVISOR_CAJAS
```

**Excepción — dispositivos fijos (DEVICE, SERVICE):**
Para dispositivos IoT y servicios daemon, el Actor SÍ está ligado 1:1 a un Pos
porque el dispositivo nunca se mueve y su endpoint es fijo.

```
  Pos: Lector-RFID-Entrada   ←→   Actor: Lector-RFID-001  (DEVICE)
  Pos: Socket-Unix-bAuth      ←→   Actor: bauth-daemon      (SERVICE)
```

---

## 4. Propiedades de Pos — El Pos también tiene sus propias propiedades

Un Pos no es solo un nombre. Tiene propiedades en idn_atributo igual que cualquier entidad.

**Propiedades de un PC-Caja-01:**
```
categoría         | attr_key             | attr_subtype      | valor
dispositivo       | modelo               | —                 | HP EliteDesk 800 G9
dispositivo       | serial               | —                 | MXL2340001
dispositivo       | sistema_operativo    | —                 | Windows 11 Enterprise
dispositivo       | mac_address          | eth0              | AA:BB:CC:DD:EE:01
dispositivo       | red_ip               | —                 | 10.10.1.21
dispositivo       | certificado          | mtls              | SHA256:pc-caja01-cert...
dispositivo       | software_caja        | version           | RetailPOS v4.2
dispositivo       | pci_compliant        | —                 | true
dispositivo       | ultimo_scan_av       | —                 | 2026-07-06T23:00:00Z
ubicacion         | piso                 | —                 | 1
ubicacion         | sector               | —                 | Plataforma Comercial
profesional       | turno_activo         | —                 | Lunes-Sábado 08:00-20:00
```

**Propiedades de una Puerta-RFID-Entrada:**
```
categoría         | attr_key             | attr_subtype      | valor
dispositivo       | modelo               | —                 | HID Global iCLASS SE R40
dispositivo       | serial               | —                 | HID-2024-005678
dispositivo       | protocolo            | —                 | OSDP v2.2
dispositivo       | firmware             | —                 | v3.1.2
dispositivo       | wiegand             | formato           | 26-bit
dispositivo       | certificado_mtls     | —                 | SHA256:rfid-door...
dispositivo       | modo_acceso          | —                 | RFID + PIN
dispositivo       | nivel_seguridad      | —                 | NIST SP 800-116 MEDIUM
ubicacion         | puerta_numero        | —                 | P-001
ubicacion         | zona_acceso          | —                 | Zona Restringida A
```

---

## 5. Prueba de escritorio — Empresa multinacional (árbol completo correcto)

### INCA Global Holdings — 4 países, 3 líneas de negocio

```
═══════════════════════════════════════════════════════════
TENANT: INCA Global Holdings
═══════════════════════════════════════════════════════════
propiedades del tenant:
  documento  | tributario     | NIT_BO       | 12345678
  documento  | tributario     | tax_id_us    | 12-3456789 (EIN)
  contacto   | email          | billing      | billing@inca.com
  contacto   | email          | legal        | legal@inca.com
  contacto   | telefono       | holding      | +59122000000
  ubicacion  | direccion      | sede_global  | Av. Arce 2345, La Paz, Bolivia
  suscripcion| plan           | —            | enterprise_global
  suscripcion| max_bdomains   | —            | 500
  facturacion| modalidad      | —            | holding_centralizado
  facturacion| nit_facturador | —            | 12345678
  tecnologia | dominio_url    | corp         | inca-global.com
  personal   | timezone_def   | —            | America/La_Paz
  personal   | locale_def     | —            | es-BO

───────────────────────────────────────────────────────────
  BDOMAIN: INCA Bolivia S.R.L.            (tipo: EMPRESA)
───────────────────────────────────────────────────────────
  propiedades:
    documento  | tributario     | NIT          | 87654321
    documento  | matricula      | registro_com | MCo-45678-LPZ
    documento  | certificacion  | ISO_9001     | IBNORCA-2024-VIGENTE
    documento  | certificacion  | ISO_22000    | IBNORCA-2024-VIGENTE (alimentaria)
    documento  | licencia_func  | alcaldia     | LF-EA-2024-001234
    documento  | licencia_func  | medioamb     | LA-2024-LIDEMA-456
    contacto   | email          | principal    | info@inca-bolivia.bo
    contacto   | email          | billing      | facturacion@inca-bolivia.bo
    contacto   | email          | legal        | legal@inca-bolivia.bo
    contacto   | email          | rrhh         | rrhh@inca-bolivia.bo
    contacto   | email          | calidad      | calidad@inca-bolivia.bo
    contacto   | telefono       | central      | +59122100000
    contacto   | telefono       | ventas       | +59122100001
    contacto   | telefono       | soporte      | +59122100002
    contacto   | telefono       | emergencia   | +59178100003 (24h)
    contacto   | red_social     | linkedin     | linkedin.com/company/inca-bolivia
    contacto   | red_social     | facebook     | facebook.com/incabolivia
    contacto   | red_social     | whatsapp_biz | +59170000001
    contacto   | red_social     | instagram    | @inca_bolivia_oficial
    ubicacion  | direccion      | fiscal       | Av. Arce 2345, Sopocachi, La Paz
    ubicacion  | direccion      | operativa    | Zona Industrial, Calle 8 No.567, El Alto
    ubicacion  | direccion      | deposito     | Parque Industrial, Av. 6 No.123, La Paz
    ubicacion  | coordenadas    | fiscal_gps   | -16.5100,-68.1200
    ubicacion  | coordenadas    | planta_gps   | -16.5215,-68.1789
    profesional| sector_CAEB    | —            | C-1089
    profesional| giro           | —            | Producción y distribución alimentos
    profesional| num_empleados  | —            | 450
    profesional| capital        | BOB          | 15000000
    financiero | cuenta         | BNB_BOB      | 1000234567
    financiero | cuenta         | BNB_USD      | 2000234567
    financiero | cuenta         | BSO_BOB      | 3000234567
    financiero | linea_credito  | BNB          | 500000
    tecnologia | erp            | sistema      | Tryton 7.4
    tecnologia | erp            | url          | erp.inca-bolivia.bo
    tecnologia | dominio_url    | web          | inca-bolivia.bo
    facturacion| modalidad      | —            | propio (NIT propio, no usa el del tenant)
    facturacion| autorizacion   | SIN_SFV      | 2024-emision-001

  ═══════════════════════════════════════════
  BSUBDOMAIN SET: Líneas de Negocio Bolivia
  ═══════════════════════════════════════════
  (SET puro — sin Pos ni Actores propios)

    ══════════════════════════════════════
    BSUBDOMAIN SET: Producción
    ══════════════════════════════════════
    propiedades del set:
      profesional| director       | uuid         | UUID-Ing-Rodriguez
      profesional| presupuesto    | BOB          | 8500000
      profesional| turno_sistema  | —            | 3 turnos 24h

      ──────────────────────────────────
      BSUBDOMAIN: Planta El Alto       (tipo: PLANTA)
      ──────────────────────────────────
      propiedades:
        ubicacion  | direccion      | —            | Zona Industrial, Calle 8, El Alto
        ubicacion  | coordenadas    | gps          | -16.5215,-68.1789
        profesional| capacidad      | unid_dia     | 12000
        profesional| num_empleados  | —            | 180
        documento  | habilitacion   | SENASAG      | HA-2024-0089
        documento  | habilitacion   | IBNORCA      | IB-2024-0234
        contacto   | telefono       | planta       | +59222000001
        contacto   | email          | planta       | planta-elalto@inca-bolivia.bo
        dispositivo| scada          | sistema      | Siemens SIMATIC S7-1500
        dispositivo| red_planta     | protocolo    | Profinet

      ← Pos en Planta El Alto:
        Pos: PC-LineaA-01        (tipo: TERMINAL) ← terminal de control línea A
        Pos: PC-LineaB-01        (tipo: TERMINAL) ← terminal de control línea B
        Pos: PC-Calidad-01       (tipo: TERMINAL) ← terminal del área de calidad
        Pos: Scanner-Entrada-01  (tipo: LECTOR)   ← lector de badges entrada
        Pos: Cam-Planta-01       (tipo: SENSOR)   ← cámara IP área producción
        Pos: PLC-LineaA          (tipo: ACTUADOR) ← controlador PLC línea A

      ← Actores HUMAN en Planta El Alto:
        Actor: Flores Juan        (tipo: HUMAN) ← operario línea A
        Actor: Choque Pedro       (tipo: HUMAN) ← operario línea B
        Actor: Mamani Ing. Rosa   (tipo: HUMAN) ← jefa de calidad
        Actor: Quispe Supervisor  (tipo: HUMAN) ← supervisor de turno
      
      ← Actores DEVICE en Planta El Alto:
        Actor: PLC-SiemensA-001   (tipo: DEVICE) ← identidad del PLC línea A
        Actor: Cam-IP-001         (tipo: DEVICE) ← identidad de la cámara

      ctx_id ejemplos en sesión:
        Flores turno mañana → tenant.inca-bo.planta-elalto.PC-LineaA-01.OPERARIO_LINEA
        Mamani inspeccion   → tenant.inca-bo.planta-elalto.PC-Calidad-01.JEFE_CALIDAD
        Flores mismo día    → tenant.inca-bo.planta-elalto.PC-LineaB-01.OPERARIO_LINEA
                               (mismo actor, diferente Pos, mismo rol)

      propiedades de Actor Flores Juan:
        personal   | primer_nombre  | —            | Juan
        personal   | segundo_nombre | —            | Carlos
        personal   | apell_paterno  | —            | Flores
        personal   | apell_materno  | —            | Quispe
        personal   | birth_date     | —            | 1988-04-20
        personal   | genero         | —            | M
        personal   | estado_civil   | —            | Casado
        personal   | tipo_sangre    | —            | O+
        personal   | locale         | —            | es-BO
        personal   | timezone       | —            | America/La_Paz
        documento  | id_nacional    | CI           | 7123456 PA
        documento  | carnet_afp     | Futuro       | FB-2009-234567
        documento  | carnet_seguro  | CNS          | CNS-2009-876543
        documento  | licencia_cond  | categoria_B  | LC-2015-456789
        contacto   | telefono       | mobile       | +59175000001
        contacto   | telefono       | home         | +59122890001
        contacto   | email          | personal     | jflores@gmail.com
        contacto   | mensajeria     | whatsapp     | +59175000001
        profesional| codigo_empleado| —            | INCA-0234
        profesional| cargo          | —            | Operario de Producción B
        profesional| area           | —            | Línea A — Empaquetado
        profesional| turno          | asignado     | Mañana 06:00-14:00
        profesional| fecha_ingreso  | —            | 2015-03-01
        profesional| nivel_salarial | —            | M2
        profesional| tipo_contrato  | —            | indefinido
        profesional| certificacion  | manip_alim   | SENASAG-2025-VIGENTE
        profesional| habilidad      | maquinaria   | Selladora Bosch BPS-200
        profesional| habilidad      | maquinaria   | Etiquetadora Videojet 1580
        profesional| evaluacion     | 2025         | 92/100
        ubicacion  | direccion      | home         | Villa Dolores, Calle 5 No.23, El Alto
        financiero | cuenta         | BNB_BOB      | 5000111222 (cuenta sueldo)

    ══════════════════════════════════════
    BSUBDOMAIN SET: Comercial
    ══════════════════════════════════════
    propiedades del set:
      profesional| director       | uuid         | UUID-Lic-Torres
      profesional| objetivo_venta | BOB_anual    | 12000000

      ──────────────────────────────────
      BSUBDOMAIN: Tienda La Paz Centro  (tipo: sucursal)
      ──────────────────────────────────
      propiedades:
        ubicacion  | direccion      | tienda       | Av. Camacho 1234, piso 1, La Paz
        ubicacion  | coordenadas    | gps          | -16.4970,-68.1338
        profesional| horario        | lunes        | 09:00-21:00
        profesional| horario        | martes       | 09:00-21:00
        profesional| horario        | miercoles    | 09:00-21:00
        profesional| horario        | jueves       | 09:00-21:00
        profesional| horario        | viernes      | 09:00-22:00
        profesional| horario        | sabado       | 09:00-22:00
        profesional| horario        | domingo      | 10:00-18:00
        profesional| horario        | feriado      | 10:00-15:00
        profesional| metodo_pago    | efectivo     | true
        profesional| metodo_pago    | qr_simple    | true
        profesional| metodo_pago    | tarj_debito  | true
        profesional| metodo_pago    | tarj_credito | Visa/MC/AmEx
        profesional| metodo_pago    | transferencia| true
        profesional| metodo_pago    | cuotas       | hasta_24
        contacto   | telefono       | tienda       | +59122001234
        contacto   | email          | tienda       | lpz-centro@inca-bolivia.bo
        profesional| encargado      | uuid         | UUID-Garcia-Encargado
        profesional| num_cajas      | —            | 4
        profesional| m2             | —            | 320

      ← Pos en Tienda La Paz Centro:
        Pos: PC-Caja-01    (tipo: TERMINAL)     propiedades → modelo HP, IP 10.1.1.21
        Pos: PC-Caja-02    (tipo: TERMINAL)     propiedades → modelo HP, IP 10.1.1.22
        Pos: PC-Caja-03    (tipo: TERMINAL)     propiedades → modelo HP, IP 10.1.1.23
        Pos: PC-Caja-04    (tipo: TERMINAL)     propiedades → modelo HP, IP 10.1.1.24
        Pos: Puerta-Entrada (tipo: PUERTA)      propiedades → lector NFC, OSDP v2
        Pos: Cam-Interior-01 (tipo: SENSOR)     propiedades → Hikvision DS-2CD2043
        Pos: Cam-Interior-02 (tipo: SENSOR)     propiedades → Hikvision DS-2CD2043
        Pos: Kiosko-Info-01  (tipo: KIOSKO)     propiedades → pantalla táctil 32"

      ← Actores HUMAN en Tienda La Paz Centro:
        Actor: López María    (tipo: HUMAN) ← cajera turno mañana
        Actor: García Juan    (tipo: HUMAN) ← cajero turno tarde
        Actor: Torres Ana     (tipo: HUMAN) ← encargada de tienda
        Actor: Quispe Carlos  (tipo: HUMAN) ← vendedor piso

      ← Actores DEVICE en Tienda La Paz Centro:
        Actor: Cam-IP-Interior-01 (tipo: DEVICE)
        Actor: Cam-IP-Interior-02 (tipo: DEVICE)

      ctx_id ejemplos:
        García turno tarde  → tenant.inca-bo.lpz-centro.PC-Caja-02.CAJERO
        Torres supervisando → tenant.inca-bo.lpz-centro.PC-Caja-01.ENCARGADO_TIENDA
        Torres mismo día    → tenant.inca-bo.lpz-centro.PC-Caja-03.ENCARGADO_TIENDA
                               (misma persona, diferente Pos, mismo rol)

      ──────────────────────────────────
      BSUBDOMAIN: Canal E-Commerce     (tipo: SERVICIO)
      ──────────────────────────────────
      propiedades:
        tecnologia | url_base       | produccion   | tienda.inca-bolivia.bo
        tecnologia | url_base       | staging      | staging.inca-bolivia.bo
        tecnologia | certificado    | ssl_prod     | SHA256:tienda-ssl...
        tecnologia | gateway_pago   | principal    | Fiserv LatAm
        tecnologia | gateway_pago   | backup       | Multicaja Bolivia
        tecnologia | plataforma     | —            | WooCommerce 8.2

      ← Pos: Endpoint-API-Tienda  (tipo: PUNTO_VIRTUAL)
        propiedades:
          tecnologia | socket_path  | —            | /run/bos/ecommerce.sock
          tecnologia | rate_limit   | rps          | 500
          tecnologia | auth_method  | —            | JWT + mTLS

      ← Actor: ecommerce-daemon   (tipo: SERVICE)  ← ligado 1:1 al Pos

    ══════════════════════════════════════
    BSUBDOMAIN SET: Administración
    ══════════════════════════════════════

      BSUBDOMAIN SET: Finanzas
        BSUBDOMAIN: Contabilidad      (tipo: DEPARTAMENTO)
          Pos: PC-Contab-01  PC-Contab-02
          Actor: CPA-Torres  Actor: Asist-Mamani

        BSUBDOMAIN: Tesorería         (tipo: DEPARTAMENTO)
          Pos: PC-Tesorer-01
          Actor: Tesorera-Quispe

      BSUBDOMAIN SET: Recursos Humanos
        BSUBDOMAIN: Nómina            (tipo: DEPARTAMENTO)
          Pos: PC-Nomina-01
          Actor: Analista-Nomina-001

        BSUBDOMAIN: Reclutamiento     (tipo: DEPARTAMENTO)
          Pos: PC-Reclut-01
          Actor: Reclutadora-López

  ═══════════════════════════════════════════════════════
  BDOMAIN: INCA Peru S.A.C.                (tipo: EMPRESA)
  ═══════════════════════════════════════════════════════
  propiedades:
    documento  | tributario     | RUC_PE       | 20987654321
    documento  | tributario     | SUNAT        | activo
    contacto   | email          | principal    | info@inca-peru.pe
    contacto   | telefono       | central      | +51145600000
    ubicacion  | direccion      | fiscal       | Av. Javier Prado 1234, Lima
    personal   | timezone_local | —            | America/Lima
    personal   | locale_local   | —            | es-PE

  BSUBDOMAIN SET: Operaciones Peru
    BSUBDOMAIN: Planta Lima           (tipo: PLANTA)
    BSUBDOMAIN: Almacén Callao        (tipo: AREA)

  BSUBDOMAIN SET: Ventas Peru
    BSUBDOMAIN: Tienda Miraflores     (tipo: sucursal)
    BSUBDOMAIN: Canal Online PE       (tipo: SERVICIO)
```

---

## 6. Prueba de escritorio — Tienda de barrio (ultra simple)

```
TENANT: Rosa López (persona natural, is_internal=false)
propiedades:
  personal   | primer_nombre  | —            | Rosa
  personal   | apell_paterno  | —            | López
  personal   | apell_materno  | —            | Mamani
  personal   | birth_date     | —            | 1968-11-05
  personal   | genero         | —            | F
  personal   | estado_civil   | —            | Viuda
  documento  | id_nacional    | CI           | 5432109 LP
  documento  | tributario     | NIT          | 5432109
  contacto   | telefono       | mobile       | +59170000001
  contacto   | mensajeria     | whatsapp     | +59170000001
  ubicacion  | direccion      | home         | Calle Yungas 234, La Ceja, El Alto
  suscripcion| plan           | —            | basic
  facturacion| nit_facturador | —            | 5432109  ← ella misma factura

  BDOMAIN: Tienda Doña Rosa          (tipo: EMPRESA)
  propiedades:
    documento  | tributario     | NIT          | 5432109 (persona natural = mismo NIT)
    documento  | licencia_func  | alcaldia     | LF-EA-2023-00456
    profesional| sector_CAEB    | —            | G-4711
    profesional| giro           | —            | Venta al por menor abarrotes
    profesional| horario        | lunes        | 07:00-21:00
    profesional| horario        | sabado       | 07:00-21:00
    profesional| horario        | domingo      | 08:00-13:00
    profesional| metodo_pago    | efectivo     | true
    profesional| metodo_pago    | qr_simple    | true
    contacto   | telefono       | tienda       | +59170000001
    ubicacion  | direccion      | tienda       | Calle Yungas 234, La Ceja, El Alto
    ubicacion  | coordenadas    | gps          | -16.5100,-68.1550
    financiero | cuenta         | BNB_BOB      | 5000234567

    BSUBDOMAIN: Local Único           (tipo: sucursal)
    propiedades:
      profesional| m2             | —            | 25
      ubicacion  | piso           | —            | planta baja

      Pos: Mostrador-01  (tipo: CAJA)     ← el mostrador físico con caja registradora
      propiedades del Pos:
        dispositivo| modelo       | —            | Casio SE-G1 (caja registradora)
        dispositivo| serial       | —            | CG1-2024-001
        dispositivo| qr_scanner   | —            | integrado

      Pos: Cam-Exterior-01  (tipo: SENSOR)
      propiedades:
        dispositivo| modelo       | —            | TP-Link Tapo C200
        dispositivo| resolucion   | —            | 1080p

      Actores HUMAN:
        Actor: Rosa López  (tipo: HUMAN)   ← ella misma atiende
        propiedades: (las mismas del tenant — persona natural)

      Actores DEVICE:
        Actor: Cam-IP-001  (tipo: DEVICE)  ← ligado a Cam-Exterior-01

      ctx_id:
        Rosa atiende → tenant.tienda-rosa.local-unico.Mostrador-01.PROPIETARIA
```

---

## 7. Prueba de escritorio — Familia extendida con muchas dependencias

```
TENANT: Familia Quispe-Mamani
propiedades:
  personal   | apellido_familia   | —        | Quispe-Mamani
  personal   | timezone_familiar  | —        | America/La_Paz
  suscripcion| plan               | —        | hogar_plus
  facturacion| nit_facturador     | uuid_ref | → bDomain Don Pedro (quien paga)

  BDOMAIN: Don Pedro Quispe       (tipo: PERSONA) ← patriarca
  propiedades:
    personal   | primer_nombre  | —            | Pedro
    personal   | segundo_nombre | —            | Ignacio
    personal   | apell_paterno  | —            | Quispe
    personal   | apell_materno  | —            | Tapia
    personal   | birth_date     | —            | 1965-03-15
    personal   | genero         | —            | M
    personal   | estado_civil   | —            | Casado
    personal   | nombre_conyuge | ref_uuid     | UUID-Carmen
    personal   | tipo_sangre    | —            | O+
    personal   | locale         | —            | es-BO
    personal   | timezone       | —            | America/La_Paz
    documento  | id_nacional    | CI           | 3456789 LP
    documento  | tributario     | NIT          | 3456789
    documento  | pasaporte      | ICAO         | BOL-P-1234567
    documento  | lic_conducir   | B            | LC-2010-123456
    documento  | lic_conducir   | A            | LC-2018-789012 (moto)
    contacto   | telefono       | mobile_1     | +59172100001
    contacto   | telefono       | mobile_2     | +59172100002 (número trabajo)
    contacto   | telefono       | office       | +59122300001
    contacto   | email          | personal     | pedro@gmail.com
    contacto   | email          | profesional  | pquispe@constructora.bo
    contacto   | email          | docencia     | pquispe@docente.umsa.bo
    contacto   | mensajeria     | whatsapp     | +59172100001
    contacto   | mensajeria     | telegram     | @pedroqui
    contacto   | red_social     | linkedin     | linkedin.com/in/pquispe
    profesional| titulo         | licenciatura | Ing. Civil — UMSA — 1990
    profesional| titulo         | maestria     | M.Sc. Proyectos — UMSA — 1998
    profesional| titulo         | doctorado    | Ph.D. Estructuras — UPC España — 2005
    profesional| colegio        | CIB          | CIB-4567
    profesional| experiencia    | años         | 28
    profesional| certificacion  | PMP          | PMP-234567 vence 2027
    profesional| certificacion  | ISO_9001_aud | IRCA-A12345 vence 2026
    profesional| idioma         | nativo       | es-BO (C2)
    profesional| idioma         | 2do          | en-US (B2)
    profesional| idioma         | 3ro          | pt-BR (A2)
    profesional| publicacion    | doi_1        | 10.1234/estructura.2020.001
    profesional| publicacion    | doi_2        | 10.1234/sismo.2022.003
    financiero | cuenta         | BNB_BOB      | 1234567890
    financiero | cuenta         | BSO_USD      | 9876543210
    financiero | cuenta         | BNB_BOB_2    | 1111222333 (cuenta ahorro)
    ubicacion  | direccion      | home         | Calle Colombia 450, Sopocachi, La Paz
    ubicacion  | coordenadas    | home_gps     | -16.5020,-68.1160
    ubicacion  | direccion      | oficina      | Calle Loayza 567, La Paz

    BSUBDOMAIN SET: Vida Profesional Pedro
      BSUBDOMAIN: Constructora Quispe    (tipo: ACTIVIDAD)
      propiedades:
        documento  | tributario   | NIT      | 3456789 (NIT personal = empresa unipersonal)
        profesional| giro         | —        | Construcción civil, consultoría
        contacto   | email        | empresa  | pquispe@constructora.bo
        contacto   | telefono     | empresa  | +59122300001
        ubicacion  | oficina      | —        | Calle Loayza 567 Of.302, La Paz
      Pos: PC-Oficina-01  (tipo: TERMINAL)
      Actor: Pedro (HUMAN) ctx_id → PROPIETARIO_CONSTRUCTORA

      BSUBDOMAIN: Cátedra UMSA          (tipo: ACTIVIDAD)
      propiedades:
        profesional| numero_materias | —    | 2
        profesional| categoria       | —    | Titular A
        educacion  | materia_1       | —    | Resistencia de Materiales
        educacion  | materia_2       | —    | Diseño Estructural
        profesional| orcid           | —    | 0000-0002-1234-5678
      Pos: PC-UMSA-Docente  (tipo: PUNTO_VIRTUAL)
      Actor: Pedro (HUMAN) ctx_id → DOCENTE_UMSA

    BSUBDOMAIN: Casa Principal Sopocachi (tipo: AREA)
    propiedades:
      ubicacion  | direccion      | —        | Calle Colombia 450, Sopocachi, La Paz
      ubicacion  | coordenadas    | gps      | -16.5020,-68.1160
      profesional| m2             | —        | 280
      profesional| pisos          | —        | 2
    Pos: Puerta-Principal-01  (tipo: PUERTA)   propiedades: lector biométrico Suprema
    Pos: Cam-Exterior-01      (tipo: SENSOR)   propiedades: Hikvision 4MP
    Pos: Panel-Alarma-01      (tipo: ACTUADOR) propiedades: Paradox EVO192
    Pos: PC-Estudio           (tipo: TERMINAL) propiedades: MacBook Pro M3
    Actores DEVICE:
      Actor: Cam-Ext-001  (tipo: DEVICE)
      Actor: Alarma-Paradox-001 (tipo: DEVICE)

  BDOMAIN: Doña Carmen Mamani de Quispe (tipo: PERSONA)
  propiedades:
    personal   | primer_nombre  | —        | Carmen
    personal   | apell_paterno  | —        | Mamani
    personal   | apell_materno  | —        | Cruz
    personal   | apell_casada   | —        | de Quispe  ← apellido legal de casada
    personal   | nombre_legal   | —        | Carmen Mamani de Quispe
    personal   | birth_date     | —        | 1967-08-12
    personal   | genero         | —        | F
    personal   | estado_civil   | —        | Casada
    personal   | tipo_sangre    | —        | A+
    documento  | id_nacional    | CI       | 4567890 OR
    documento  | tributario     | NIT      | 4567890
    contacto   | telefono       | mobile   | +59173000001
    contacto   | mensajeria     | whatsapp | +59173000001
    contacto   | email          | personal | carmen@gmail.com
    profesional| ocupacion      | —        | Artesana / Comerciante
    profesional| especialidad   | —        | Tejidos andinos tradicionales
    profesional| certificacion  | FECOBA   | artesana-certificada-2023

    BSUBDOMAIN SET: Actividades Carmen
      BSUBDOMAIN: Tienda Artesanías     (tipo: ACTIVIDAD)
      propiedades:
        ubicacion  | mercado      | —        | Mercado Artesanal Sagárnaga
        profesional| puesto_num   | —        | 234-B
        profesional| horario      | semana   | Mar-Dom 09:00-18:00
        profesional| metodo_pago  | efectivo | true
        profesional| metodo_pago  | qr       | true
        contacto   | telefono     | puesto   | +59173000001
      Pos: Mostrador-Artesanias  (tipo: CAJA)
      Actor: Carmen (HUMAN) ctx_id → PROPIETARIA_ARTESANIAS

  BDOMAIN: Hijo Carlos Quispe M.       (tipo: PERSONA)
  propiedades:
    personal   | primer_nombre  | —        | Carlos
    personal   | apell_paterno  | —        | Quispe
    personal   | apell_materno  | —        | Mamani
    personal   | birth_date     | —        | 2000-09-10
    personal   | genero         | —        | M
    personal   | estado_civil   | —        | Soltero
    documento  | id_nacional    | CI       | 9123456 LP
    contacto   | telefono       | mobile   | +59174000001
    contacto   | email          | est      | cquispe@est.umsa.bo
    contacto   | email          | personal | carlos@gmail.com
    educacion  | matricula      | UMSA     | 2021-INF-0234
    educacion  | semestre       | —        | 8vo
    educacion  | carrera        | —        | Ingeniería Informática
    profesional| part_time      | —        | Repartidor Rappi
    profesional| cod_repartidor | rappi    | RAPPI-R-2023-456

    BSUBDOMAIN SET: Actividades Carlos
      BSUBDOMAIN: Estudios UMSA         (tipo: ACTIVIDAD)
        Pos: Portal-UMSA  (tipo: PUNTO_VIRTUAL)
        Actor: Carlos (HUMAN) ctx_id → ESTUDIANTE

      BSUBDOMAIN: Trabajo Rappi         (tipo: ACTIVIDAD)
        Pos: App-Rappi    (tipo: PUNTO_VIRTUAL)
        Actor: carlos.rappi (tipo: FEDERATED) ← identidad viene de Rappi IdP
        propiedades del actor federado:
          tecnologia | idp_externo    | —      | rappi.com.bo
          tecnologia | idp_subject    | —      | RAPPI-R-2023-456
          tecnologia | scope_fed      | —      | delivery:accept delivery:complete

  BDOMAIN: Hija Ana Quispe M.          (tipo: PERSONA) ← menor de edad
  propiedades:
    personal   | primer_nombre  | —        | Ana
    personal   | birth_date     | —        | 2009-07-22
    personal   | es_menor       | —        | true (hasta 2027-07-22)
    personal   | tutor_legal    | padre    | UUID-Pedro-Quispe
    personal   | tutor_legal    | madre    | UUID-Carmen-Mamani
    documento  | id_nacional    | CI_menor | 9876012 LP

    BSUBDOMAIN: Estudios Colegio       (tipo: ACTIVIDAD)
      Pos: Portal-Colegio  (tipo: PUNTO_VIRTUAL)
      Actor: ana@colegio.bo (tipo: HUMAN) ← acceso controlado por tutor_legal

  BDOMAIN: Casa Familiar Sopocachi     (tipo: HOGAR)
  propiedades:
    ubicacion  | direccion      | —        | Calle Colombia 450, Sopocachi, La Paz
    profesional| m2             | —        | 280
    financiero | avaluo         | BOB      | 1200000
    documento  | folio_real     | DDRR     | LP-04-321456
    tecnologia | red_hogar      | ssid     | Quispe-Hogar-5G
    tecnologia | smart_home     | hub      | Google Home

    BSUBDOMAIN SET: Planta Baja
      BSUBDOMAIN: Sala de Estar         (tipo: SALA)
        Pos: Smart-TV-Sala   (tipo: TERMINAL)    → Actor: TV-Samsung-001 (DEVICE)
        Pos: Cam-Sala-01     (tipo: SENSOR)      → Actor: Cam-IP-Sala-001 (DEVICE)

      BSUBDOMAIN: Cocina                (tipo: SALA)
        Pos: Refrigerador-Smart  (tipo: ACTUADOR) → Actor: LG-Smart-Fridge-001 (DEVICE)

    BSUBDOMAIN SET: Planta Alta
      BSUBDOMAIN: Dormitorio Pedro      (tipo: SALA)
        Pos: MacBook-Pedro   (tipo: TERMINAL)
        Actor: Pedro (HUMAN) ctx_id → PROPIETARIO_HOGAR

      BSUBDOMAIN: Dormitorio Carlos     (tipo: SALA)
        Pos: PC-Gaming-Carlos  (tipo: TERMINAL)
        Actor: Carlos (HUMAN)

      BSUBDOMAIN: Dormitorio Ana        (tipo: SALA)
        Pos: Tablet-Ana    (tipo: TERMINAL)
        Actor: Ana (HUMAN) ← acceso supervisado (menor)
```

---

## 8. Prueba de escritorio — Hospital con roles médicos vs Pos

Demuestra la separación Pos/Actor/Rol más claramente.

```
TENANT: Sistema de Salud Regional

  BDOMAIN: Hospital Los Olivos          (tipo: INSTITUCIÓN)
  propiedades:
    documento  | tributario     | NIT          | 45678901
    documento  | habilitacion   | SNIS         | HSR-2024-001 (Sist. Nac. Inf. Salud)
    documento  | certificacion  | ISO_9001     | IBNORCA-2024
    contacto   | email          | urgencias    | urgencias@hosp-olivos.bo
    contacto   | telefono       | urgencias    | +59122999000 (24h)
    contacto   | telefono       | central      | +59122100000
    profesional| num_camas      | —            | 180
    profesional| num_quirofanos | —            | 6

    BSUBDOMAIN SET: Área Médica

      BSUBDOMAIN SET: Urgencias y UCI
        BSUBDOMAIN: Urgencias Adultos    (tipo: DEPARTAMENTO)
        propiedades:
          profesional| jefe_servicio  | uuid   | UUID-Dr-Vargas
          profesional| camas          | —      | 20
          profesional| nivel_urgencia | —      | NIVEL_III (alta complejidad)

          ← Pos (dispositivos físicos en Urgencias):
            Pos: Terminal-Triaje-01    (tipo: TERMINAL)  ← PC de clasificación
            Pos: Terminal-Medico-U01   (tipo: TERMINAL)  ← PC médico cama 1
            Pos: Terminal-Medico-U02   (tipo: TERMINAL)  ← PC médico cama 2
            Pos: Monitor-Cama-U01      (tipo: SENSOR)    ← monitor paciente cama 1
            Pos: Monitor-Cama-U02      (tipo: SENSOR)    ← monitor paciente cama 2
            Pos: Dispensador-Med-U01   (tipo: ACTUADOR)  ← dispensador automático meds
            Pos: Puerta-Acceso-UCI     (tipo: PUERTA)    ← acceso restringido

          ← Actores HUMAN en Urgencias (NO son Pos, son personas):
            Actor: Dr. Vargas          (tipo: HUMAN) ← jefe urgencias
            Actor: Dr. Mamani          (tipo: HUMAN) ← médico de guardia
            Actor: Enf. López          (tipo: HUMAN) ← enfermera
            Actor: Enf. Torres         (tipo: HUMAN) ← enfermera auxiliar
            Actor: Aux. Quispe         (tipo: HUMAN) ← auxiliar de enfermería

          ← Actores SERVICE:
            Actor: HIS-Urgencias       (tipo: SERVICE) ← sistema hospitalario

          ctx_id en sesión real (separación Pos/Actor/Rol):
            Dr.Vargas anamnesis →  hosp.urgencias.Terminal-Medico-U01.MEDICO_URGENCIAS
            Dr.Mamani igual turno→ hosp.urgencias.Terminal-Medico-U02.MEDICO_URGENCIAS
            Enf.López triaje →     hosp.urgencias.Terminal-Triaje-01.ENFERMERA_TRIAJE
            Dr.Vargas supervisando→ hosp.urgencias.Terminal-Medico-U02.JEFE_SERVICIO
              ← mismo actor (Vargas), diferente Pos, diferente rol en este contexto

        BSUBDOMAIN: UCI Adultos          (tipo: UNIDAD)
        propiedades:
          profesional| camas_uci     | —      | 8
          profesional| ratio         | —      | 1 enfermera : 2 pacientes
          documento  | certificacion | JCI    | Joint Commission Internacional 2024

          ← Pos UCI:
            Pos: Terminal-UCI-Medico-01  (tipo: TERMINAL)
            Pos: Terminal-UCI-Medico-02  (tipo: TERMINAL)
            Pos: Terminal-UCI-Enf-01     (tipo: TERMINAL) ← estación enfermería
            Pos: Monitor-UCI-01 al 08    (tipo: SENSOR)   ← monitores cardiacos
            Pos: Ventilador-UCI-01       (tipo: ACTUADOR) ← ventilador mecánico
            Pos: Puerta-UCI              (tipo: PUERTA)   ← acceso muy restringido

          ← Actores HUMAN UCI:
            Actor: Dr. Paredes           (tipo: HUMAN) ← intensivista
            Actor: Enf. Especialista Cruz(tipo: HUMAN) ← enfermera UCI
            Actor: Residente Flores      (tipo: HUMAN) ← médico residente

          ← Actores DEVICE UCI:
            Actor: Monitor-Philips-UCI-01 (tipo: DEVICE)
            Actor: Ventilador-Draeger-01  (tipo: DEVICE)

          propiedades del Dr. Paredes (intensivista):
            personal   | primer_nombre  | —    | Roberto
            personal   | apell_paterno  | —    | Paredes
            personal   | birth_date     | —    | 1975-08-20
            documento  | id_nacional    | CI   | 4321567 CB
            profesional| matricula      | CMB  | CMB-2001-4521
            profesional| especialidad   | —    | Medicina Intensiva
            profesional| subespecialidad| —    | ECMO y soporte vital avanzado
            profesional| titulo         | doctorado | Ph.D. Medicina Crítica — UB 2008
            documento  | certificacion  | FCCS | FCCS vigente 2027
            documento  | certificacion  | ACLS | ACLS vigente 2026
            documento  | certificacion  | PALS | PALS vigente 2026
            contacto   | telefono       | oncall | +59178500001
            medico     | tipo_sangre    | —    | A+
            medico     | num_seguro_med | —    | CMB-2001-4521
            personal   | locale         | —    | es-BO

          ctx_id sesión Dr. Paredes:
            Visita UCI mañana →  hosp.uci.Terminal-UCI-Medico-01.MEDICO_INTENSIVISTA
            Interconsulta tarde→ hosp.urgencias.Terminal-Medico-U01.MEDICO_INTENSIVISTA
              ← el ROL es el mismo, el POS cambia según dónde esté físicamente

      BSUBDOMAIN SET: Área Quirúrgica
        BSUBDOMAIN: Quirófano 1          (tipo: SALA)
          Pos: Terminal-Quirofano-01 (tipo: TERMINAL) ← PC anestesia/registro
          Pos: Bisturi-Electrico-01  (tipo: ACTUADOR) ← electrobisturí con ID
          Pos: Monitor-Anestesia-01  (tipo: SENSOR)   ← monitor anestesia
          Actores: Dr-Cirujano, Dr-Anestesiologo, Enf-Instrumentista

    BSUBDOMAIN SET: Área Administrativa
      BSUBDOMAIN: Facturación            (tipo: DEPARTAMENTO)
        Pos: PC-Facturacion-01  PC-Facturacion-02
        Actor: Facturista-001   Actor: Facturista-002
        ctx_id → hosp.facturacion.PC-Facturacion-01.FACTURISTA_SALUD
```

---

## 9. El nombre del Pos — Regla definitiva

Un Pos CORRECTO siempre suena a DISPOSITIVO o PUNTO:

```
CORRECTOS (suenan a dispositivos):
  PC-Caja-01, Terminal-Triaje-01, Lector-RFID-Entrada,
  Puerta-Principal, Cam-Interior-01, Monitor-UCI-03,
  Socket-Unix-bAuth, Endpoint-API-v2, Kiosko-Info-01,
  ATM-0045, PLC-LineaA, Tablet-Recepcion-01

INCORRECTOS (suenan a roles o funciones):
  "Cajero", "Control Calidad", "Atención al Cliente",
  "Médico de Guardia", "Estación Enfermería"
  (estos son ROLES que van en D1/BitMask, no en Pos)
```

Los nombres de los roles del actor (CAJERO, MÉDICO, SUPERVISOR) viven en
`privilege_role_atom` y se asignan vía BitMask. NO aparecen en el árbol D00.

---

## 10. Resumen — Reglas validadas por las pruebas

| Concepto | Definición | Dónde vive |
|---|---|---|
| **Pos** | Dispositivo físico o virtual donde ocurre la interacción | D00 org tree (g4) |
| **Actor** | Entidad (persona, servicio, dispositivo, bot) | D00 org tree (g5) · bSubDomain |
| **Rol** | Función y permisos del actor | D1-D12 BitMask — FUERA del org tree |
| **ctx_id** | Combina tenant+bDomain+bSubDomain+Pos+Rol en runtime | ses_context + Redis |

**Actor no está bajo Pos de forma permanente:**
- HUMAN: registrado en bSubDomain, usa diferentes Pos según sesión (M:N)
- DEVICE / SERVICE: ligado 1:1 a su Pos (el dispositivo no se mueve)
- ctx_id captura la combinación (Pos usado, Actor, Rol) en el momento de la sesión

**bSubDomain SET:**
- Contenedor puro (sin Pos ni Actores propios)
- Puede anidar otros SETs (sin límite de profundidad)
- Resuelve jerarquías complejas sin nuevos niveles en el modelo base

**Tenant con propiedades:**
- No es solo un nombre: tiene NIT, plan, facturación, locale/timezone por defecto
- `facturacion.nit_facturador` → habilita facturación por terceros
- bDomains hijos pueden heredar la identidad fiscal del tenant cuando no tienen NIT propio

---

*Documento de planificación HITL — sin ejecución en VPS.*
*Requiere aprobación antes de modificar DDL o seeds.*
