# ENSAYO — D00 Variedad de Datos de Contacto e Identidad
**Versión:** 1.0 · **Fecha:** 2026-06-30 · **Tipo:** Planificación / Diseño
**Propósito:** Verificar si los átomos D00 pueden contener la variedad real de
teléfonos, emails, direcciones y documentos de identidad que tienen personas y
empresas en el mundo real. Se prueba la multiplicidad (1 vs N valores por tipo)
y la tipificación (el "tipo" dentro de cada categoría de dato).
**Complementa:** ENSAYO-D00-PRUEBAS-ESCRITORIO.md

---

## PREGUNTA CENTRAL

El modelo D00 actual define estos campos como TEXT simple:

```
bdomain.email     → TEXT RFC 5321     ← ¿solo 1 email?
bdomain.telefono  → TEXT E.164        ← ¿solo 1 teléfono?
bdomain.direccion → TEXT              ← ¿solo 1 dirección?
actor.id_doc_type → ENUM (tipo doc)   ← ¿solo 1 documento?
```

¿Es eso suficiente? ¿O la realidad exige N valores, cada uno con su propio tipo?

---

## PARTE 1 — TAXONOMÍA REAL DE DATOS DE CONTACTO

### 1.1 Tipos de teléfono (fuente: SCIM 2.0 RFC 7643 §4.1.2)

| Tipo | Descripción | Ejemplo | Formato |
|------|------------|---------|---------|
| `mobile` | Celular personal | +591 71234567 | E.164 |
| `work` | Teléfono fijo trabajo | +591 2 220-0001 | E.164 |
| `home` | Teléfono fijo domicilio | +591 4 456-7890 | E.164 |
| `fax` | Fax empresarial | +591 2 220-0002 | E.164 |
| `work_mobile` | Celular corporativo (SIM empresa) | +591 79000001 | E.164 |
| `whatsapp` | WhatsApp (puede diferir del mobile) | +591 71234567 | E.164 |
| `emergency` | Contacto de emergencia (no del actor) | +591 72345678 | E.164 |
| `satellite` | Teléfono satelital (minería, campo) | +8816123456 | E.164 |
| `voip` | VoIP / extensión interna | ext. 215 | extensión |

**Multiplicidad observada en empresas reales:**
- Persona ejecutiva: mobile + work + work_mobile + whatsapp → 4 números
- Empresa mediana: work (recepción) + work (ventas) + fax + mobile (gerente) → 4 números
- Persona natural simple: solo mobile (WhatsApp) → 1 número

### 1.2 Tipos de email (fuente: SCIM 2.0 RFC 7643, empresas Fortune 500)

| Tipo | Descripción | Ejemplo |
|------|------------|---------|
| `work` | Email corporativo principal | jorge.saavedra@bancounion.bo |
| `home` | Email personal | jorge.personal@gmail.com |
| `alternate` | Email de respaldo (backup) | jsaavedra@hotmail.com |
| `billing` | Email exclusivo para facturas | facturacion@bancounion.bo |
| `notifications` | Email para alertas del sistema | alertas@bancounion.bo |
| `technical` | Email técnico (APIs, soporte) | api@bancounion.bo |
| `legal` | Email para comunicaciones legales | legal@bancounion.bo |
| `noreply` | Dirección de envío de sistema (no M2M) | noreply@sbos.bo |

**Multiplicidad observada:**
- Persona trabajadora: work + home + alternate → 3 emails
- Empresa grande: work + billing + legal + technical + notifications → 5 emails
- Persona sin trabajo formal: solo home (gmail/hotmail) → 1 email
- Desarrollador freelance: work + billing (PayPal linked) + home → 3 emails

### 1.3 Tipos de dirección (fuente: SCIM 2.0 RFC 7643, USPS, Bolivia SIN)

| Tipo | Descripción | Obligatorio para |
|------|------------|-----------------|
| `work` | Dirección de oficina/trabajo | Empresa, profesional |
| `home` | Domicilio personal | Persona, hogar |
| `fiscal` | Dirección registrada en SIN/impuestos | Cualquier entidad con NIT |
| `billing` | Dirección de facturación (puede ser PO Box) | Empresa, persona |
| `delivery` | Dirección de entrega de paquetes | Comercio, persona |
| `mailing` | Dirección de correspondencia postal | Empresa, persona |
| `registered` | Domicilio legal registrado (notaría) | Empresa |
| `branch` | Sucursal específica | Empresa multi-sucursal |
| `warehouse` | Almacén / depósito | Empresa comercial |
| `virtual` | Dirección virtual / buzón (ej. UPS Store) | Freelancer, startup |

**Estructura de una dirección real (Bolivia):**
```
{
  type: "fiscal",
  street: "Av. Arce",
  number: "N° 2678",
  floor: "Piso 8",
  office: "Of. 801",
  neighborhood: "Sopocachi",
  municipality: "La Paz",
  department: "La Paz",
  country: "BO",
  postal_code: null,      ← Bolivia no usa CP postal sistemáticamente
  primary: true,
  verified: true          ← verificada con padrón municipal
}
```

**Estructura internacional (Argentina):**
```
{
  type: "home",
  street: "Av. Corrientes",
  number: "1234",
  floor: "3°",
  office: "B",
  neighborhood: "San Nicolás",
  municipality: "Buenos Aires",
  state: "CABA",
  country: "AR",
  postal_code: "C1043",
  primary: true,
  verified: false
}
```

### 1.4 Tipos de documento de identidad

| Tipo | País / Alcance | Formato típico | Persona / Empresa |
|------|---------------|---------------|:-----------------:|
| `CI` | Bolivia (ciudadano) | 1234567 CB | Persona |
| `CI_EXT` | Bolivia (extranjero residente) | E-123456 | Persona |
| `NIT` | Bolivia (persona natural o empresa) | 12345678 (8-9 dígitos) | Ambos |
| `PASSPORT` | Internacional | AA123456 | Persona |
| `DNI` | Argentina, España | 12.345.678 / 12345678X | Persona |
| `CUIT` | Argentina (empresa) | 30-12345678-9 | Empresa |
| `RUT` | Chile (persona y empresa) | 12.345.678-9 | Ambos |
| `CPF` | Brasil (persona) | 123.456.789-00 | Persona |
| `CNPJ` | Brasil (empresa) | 12.345.678/0001-90 | Empresa |
| `CURP` | México (persona) | AAAA123456HAAAAA01 | Persona |
| `RFC` | México (empresa y persona) | AAAA123456ABC | Ambos |
| `RUC` | Ecuador, Perú | 1234567890001 | Ambos |
| `CC` | Colombia (cédula) | 123456789 | Persona |
| `NIT_CO` | Colombia (empresa) | 900.123.456-7 | Empresa |
| `CE` | Colombia (extranjero) | 123456 | Persona |
| `DUI` | El Salvador | 12345678-9 | Persona |
| `DPI` | Guatemala | 1234567890101 | Persona |
| `TIN` | USA (Tax ID) | 12-3456789 | Empresa |
| `SSN` | USA (persona) | 123-45-6789 | Persona |
| `NIE` | España (extranjero) | X1234567Z | Persona |
| `EU_ID` | Unión Europea (varios) | variado | Persona |

---

## PARTE 2 — CASOS REALES CON VARIEDAD MÁXIMA

### CASO 1 — Ejecutiva multinacional en Bolivia (máxima complejidad)

```
Nombre  : Ana Flores Terrazas
Cargo   : Gerente General Walmart Bolivia SA
Origen  : Boliviana con MBA en USA, regresó al país
```

**Teléfonos (4 números, 4 tipos distintos):**

| # | Tipo | Número | Notas |
|---|------|--------|-------|
| 1 | `work` | +591 2 277-8000 ext. 100 | Central Walmart La Paz |
| 2 | `work_mobile` | +591 79000001 | SIM corporativa Tigo |
| 3 | `mobile` | +591 71234567 | Celular personal (privado) |
| 4 | `whatsapp` | +591 79000001 | WhatsApp del celular corporativo |

**Emails (4 emails, 4 tipos distintos):**

| # | Tipo | Dirección |
|---|------|-----------|
| 1 | `work` | a.flores@walmart.com.bo |
| 2 | `home` | anaflores1975@gmail.com |
| 3 | `legal` | gerencia.legal@walmart.com.bo |
| 4 | `notifications` | a.flores+sbos@walmart.com.bo |

**Direcciones (3 direcciones, 3 tipos):**

| # | Tipo | Contenido |
|---|------|-----------|
| 1 | `work` | Av. Arce N° 2678, Piso 8, Sopocachi, La Paz, BO — primary:true |
| 2 | `home` | C/ Rosendo Gutiérrez N° 500, Sopocachi, La Paz, BO |
| 3 | `fiscal` | Av. Arce N° 2678, Casa Matriz, La Paz, BO (domicilio SIN) |

**Documentos de identidad (2 documentos, 2 tipos):**

| # | Tipo | Número | Emisor |
|---|------|--------|--------|
| 1 | `CI` | 7123456 LP | Registro Civil Bolivia (principal) |
| 2 | `PASSPORT` | BA098765 | Bolivia — usó para estudio en USA |

---

**¿Resiste D00 con su modelo actual?**

```
bdomain.email    = "a.flores@walmart.com.bo"   ← solo 1 de 4
bdomain.telefono = "+59127278000"              ← solo 1 de 4
bdomain.direccion = "Av. Arce N° 2678..."     ← solo 1 de 3
actor.id_doc_type = CI                          ← el TIPO sí, pero sin el número secundario
```

**RESULTADO: ❌ INSUFICIENTE** para este caso. El modelo pierde 3 teléfonos,
3 emails, 2 direcciones, y el pasaporte como documento secundario.

---

### CASO 2 — Extranjero residente en Bolivia (caso de doble identidad)

```
Nombre  : Ing. Gabriel Romero Vásquez
Cargo   : Gerente TI Banco Unión SA
Origen  : Argentino con residencia permanente en Bolivia
```

**Documentos de identidad (3 documentos, 3 países):**

| # | Tipo | Número | País | Estado |
|---|------|--------|------|--------|
| 1 | `CI_EXT` | E-456789 | Bolivia | Carnet extranjero (principal en BO) |
| 2 | `DNI` | 32.456.789 | Argentina | DNI argentino vigente |
| 3 | `PASSPORT` | AA234567 | Argentina | Pasaporte para viajes |

**Teléfonos (3 números, 3 contextos):**

| # | Tipo | Número | Contexto |
|---|------|--------|---------|
| 1 | `work` | +591 2 270-0001 | Banco Unión sede |
| 2 | `mobile` | +591 71999888 | Celular boliviano (principal) |
| 3 | `home` | +54 11 4123-4567 | Celular argentino (familia en BA) |

**Emails (3 emails):**

| # | Tipo | Dirección |
|---|------|-----------|
| 1 | `work` | g.romero@bancounion.bo |
| 2 | `home` | gabiromero@hotmail.com |
| 3 | `alternate` | gabriel.romero@protonmail.com |

**Direcciones (2 países, 2 tipos):**

| # | Tipo | Dirección |
|---|------|-----------|
| 1 | `home` | C/ Landaeta N° 890, Miraflores, La Paz, BO — primary:true |
| 2 | `mailing` | Av. Santa Fe 2345, Piso 4, CABA, AR C1123 — (familia en Argentina) |

---

**¿Resiste D00?**

El campo `actor.id_doc_type` es un ENUM de UN SOLO VALOR. Gabriel tiene 3
documentos de 2 países. El modelo actual solo puede registrar 1.

**RESULTADO: ❌ CRÍTICO** — En organismos regulados (banco, notaría, salud),
el sistema DEBE registrar todos los documentos del usuario, no solo el principal.
La ASFI (Bolivia) y el SFB (regulación financiera) exigen registrar CI_EXT + pasaporte
para extranjeros residentes.

---

### CASO 3 — Empresa grande multicontacto (Banco Unión SA)

```
Entidad : Banco Unión SA
bdomain.type = empresa
```

**Teléfonos (5 números, roles distintos):**

| # | Tipo | Número | Propósito |
|---|------|--------|-----------|
| 1 | `work` | +591 2 270-0001 | Central telefónica principal |
| 2 | `work` | 800-10-0000 | Línea gratuita 24h (atención cliente) |
| 3 | `work` | +591 2 270-0002 | Call center empresas |
| 4 | `fax` | +591 2 270-0003 | Fax institucional |
| 5 | `emergency` | +591 79090000 | Línea de emergencia ASFI |

**Emails (5 emails, todos corporativos, todos distintos):**

| # | Tipo | Dirección |
|---|------|-----------|
| 1 | `work` | info@bancounion.bo |
| 2 | `billing` | facturacion@bancounion.bo |
| 3 | `legal` | legal@bancounion.bo |
| 4 | `technical` | soportetic@bancounion.bo |
| 5 | `notifications` | alertas@bancounion.bo |

**Direcciones (4 direcciones):**

| # | Tipo | Dirección |
|---|------|-----------|
| 1 | `registered` | Av. Camacho N° 1234, La Paz (escritura de constitución) |
| 2 | `fiscal` | Av. Camacho N° 1234, La Paz (domicilio SIN — NIT 1000234567) |
| 3 | `work` | Av. 16 de Julio N° 1800, El Prado, La Paz (sede operativa) |
| 4 | `mailing` | Casilla de Correos 1234, La Paz (correspondencia formal) |

**Documentos (empresa):**

| # | Tipo | Número | Propósito |
|---|------|--------|-----------|
| 1 | `NIT` | 1000234567 | Registro SIN Bolivia (principal) |
| 2 | `NIT` | 1000234568 | NIT para Cochabamba (registro regional) |
| 3 | `TIN` | N/A | No aplica — empresa nacional |

---

**¿Resiste D00?**

Con el campo `bdomain.email` como TEXT simple → solo puede almacenar 1 de 5 emails.
Con `bdomain.telefono` como TEXT simple → solo puede almacenar 1 de 5 teléfonos.

**RESULTADO: ❌ CLARAMENTE INSUFICIENTE** para empresas de más de 20 empleados.

---

### CASO 4 — Persona natural simple (comerciante pequeño Bolivia)

```
Nombre  : Don Ernesto Vásquez Rojas
Negocio : Ferretería El Martillo, Oruro
```

**Teléfonos (2 números — muy común en Bolivia):**

| # | Tipo | Número | Uso real |
|---|------|--------|---------|
| 1 | `mobile` | +591 72345678 | Celular principal (WhatsApp pedidos) |
| 2 | `home` | +591 52 123456 | Teléfono fijo del local comercial |

**Emails (1 email — caso simple):**

| # | Tipo | Dirección |
|---|------|-----------|
| 1 | `home` | ernestovr@gmail.com |

**Direcciones (2 en una misma dirección física):**

| # | Tipo | Dirección |
|---|------|-----------|
| 1 | `work` | Calle Ayacucho N° 234, Oruro (el local) |
| 2 | `fiscal` | Calle Ayacucho N° 234, Oruro (mismo lugar, pero rol fiscal) |

**Documentos (2 — muy común en Bolivia):**

| # | Tipo | Número |
|---|------|--------|
| 1 | `CI` | 4567890 OR | Carnet de identidad |
| 2 | `NIT` | 45678901 | NIT de persona natural comerciante |

**Observación:** Don Ernesto tiene la misma dirección física como `work` y `fiscal`
pero el sistema necesita ambos roles porque el SIN los trata distinto en
fiscalizaciones (domicilio comercial vs domicilio fiscal registrado).

---

**¿Resiste D00?**

Para este caso simple: casi sí — tiene 2 teléfonos (D00 solo guarda 1), 1 email
(D00 lo maneja bien), 2 versiones de la misma dirección (D00 solo guarda 1 texto).

**RESULTADO: ⚠️ PARCIALMENTE SUFICIENTE** — pierde el fijo del local y la distinción
work vs fiscal en la dirección.

---

### CASO 5 — Médico independiente con práctica dual (Bolivia + Argentina)

```
Nombre  : Dr. Carlos Quispe Mamani
Situación: Médico boliviano que atiende en Santa Cruz y viaja a Argentina
```

**Documentos (3 — caso real de profesional LATAM):**

| # | Tipo | Número | País emisor | Vigencia |
|---|------|--------|------------|---------|
| 1 | `CI` | 7654321 LP | Bolivia | Permanente |
| 2 | `PASSPORT` | BA112233 | Bolivia | Vence 2030 |
| 3 | `DNI` | N/A | Argentina | No tiene (no es residente) |

**Teléfonos (3 — práctica médica real):**

| # | Tipo | Número | Uso |
|---|------|--------|-----|
| 1 | `mobile` | +591 76543210 | Celular Bolivia (principal) |
| 2 | `whatsapp` | +591 76543210 | Mismo número, pero WhatsApp |
| 3 | `work` | +591 3 333-4567 | Consultorio Santa Cruz |

**Nota:** En Bolivia, el WhatsApp suele ser el canal de comunicación principal
para citas médicas. Muchos médicos tienen el mismo número en `mobile` y `whatsapp`
pero los clientes los buscan por distintos canales, por eso el sistema necesita
distinguirlos.

**Emails (2):**

| # | Tipo | Dirección |
|---|------|-----------|
| 1 | `work` | dr.quispe@clinicasur.bo |
| 2 | `home` | carlosquispe@gmail.com |

**Direcciones (3):**

| # | Tipo | Dirección |
|---|------|-----------|
| 1 | `work` | C/Mercado 567, Piso 2, Santa Cruz de la Sierra, BO |
| 2 | `home` | Zona Norte, C/12 N° 456, La Paz, BO |
| 3 | `fiscal` | C/Mercado 567, Piso 2, Santa Cruz (registrado SIN) |

---

**¿Resiste D00?**

Pierde el teléfono de WhatsApp (el más usado para citas), la dirección domiciliar
en La Paz, y no hay campo para `CI` versus `PASSPORT` simultáneamente.

**RESULTADO: ❌ INSUFICIENTE** para profesionales de salud con práctica dual.

---

### CASO 6 — Hogar familiar con acceso multi-miembro

```
Familia : García Condori — La Paz
Titular : Elena García de Condori
Miembros: Elena + Jorge (esposo) + Javier (hijo 18) + Sofía (hija 15)
```

**Teléfonos del HOGAR (todos son relevantes):**

| # | Tipo | Número | Dueño |
|---|------|--------|-------|
| 1 | `home` | +591 2 234-5678 | Fijo del hogar |
| 2 | `mobile` | +591 71234567 | Elena (titular) |
| 3 | `mobile` | +591 72345678 | Jorge (cónyuge) |
| 4 | `mobile` | +591 73456789 | Javier (hijo mayor) |

**Observación:** Para un plan de servicios del hogar (internet, TV, seguridad),
el operador necesita poder contactar a CUALQUIER miembro adulto del hogar.
Registrar solo el teléfono del titular es insuficiente para soporte técnico.

**Emails del HOGAR:**

| # | Tipo | Dirección |
|---|------|-----------|
| 1 | `work` | elena.garcia@empresa.com | (email titular) |
| 2 | `home` | familia.garcia@gmail.com | (email compartido del hogar) |
| 3 | `billing` | facturas.garcia@gmail.com | (para facturas de servicios) |

**Dirección del HOGAR:**

| # | Tipo | Dirección |
|---|------|-----------|
| 1 | `home` | Zona Norte, C/ 12 N° 456, La Paz — primary:true |
| 2 | `mailing` | Casilla Postal 4567, La Paz (para correspondencia oficial) |

---

**¿Resiste D00?**

Un hogar tiene múltiples teléfonos de contacto, múltiples emails, y puede tener
dirección de correspondencia distinta al domicilio.

**RESULTADO: ❌ INSUFICIENTE** — el campo `bdomain.telefono` solo puede guardar 1
de los 4 teléfonos del hogar. Para un servicio de emergencia domiciliar, perder
3 de los 4 contactos es inaceptable.

---

### CASO 7 — Desarrollador freelance internacional

```
Nombre  : Alan Chávez Torrez
Tipo    : Desarrollador freelance (bdomain.type = desarrollador)
Opera   : Bolivia, clientes USA y España
```

**Teléfonos (4, con propósitos muy distintos):**

| # | Tipo | Número | Para qué |
|---|------|--------|---------|
| 1 | `mobile` | +591 71111222 | Bolivia — uso diario |
| 2 | `voip` | +1 555 234-5678 | Número USA (Google Voice) para clientes US |
| 3 | `work_mobile` | +34 612 345 678 | SIM española para cliente Madrid |
| 4 | `whatsapp` | +591 71111222 | WhatsApp Bolivia (coordinación) |

**Emails (4 — todos activos simultáneamente):**

| # | Tipo | Dirección | Uso |
|---|------|-----------|-----|
| 1 | `work` | alan@codefreelance.bo | Presentación profesional general |
| 2 | `billing` | billing@codefreelance.bo | Invoices, Payoneer, PayPal |
| 3 | `home` | alanct@gmail.com | Registro plataformas (GitHub, etc.) |
| 4 | `technical` | dev@codefreelance.bo | Acceso APIs, webhooks, CI/CD |

**Direcciones (2 tipos):**

| # | Tipo | Dirección |
|---|------|-----------|
| 1 | `home` | Av. Fuerza Naval N° 123, La Paz, BO — domicilio real |
| 2 | `virtual` | 1234 Innovation Dr, Suite 200, Austin TX 78701, USA — buzón virtual para clientes US |

**Documentos (2):**

| # | Tipo | Número |
|---|------|--------|
| 1 | `CI` | 5678901 LP | Bolivia |
| 2 | `NIT` | 56789012 | NIT Bolivia para facturas a clientes locales |

---

**¿Resiste D00?**

Un desarrollador freelance internacional tiene 4 teléfonos de 3 países, 4 emails
con roles distintos, y 2 tipos de dirección (física y virtual).

**RESULTADO: ❌ INSUFICIENTE** — el modelo pierde información crítica para
facturación multi-país y soporte a clientes en distintas zonas horarias.

---

### CASO 8 — Servicio M2M (bot SAP) — el caso más simple

```
Entidad : SAP Integration Bot
bdomain.type = m2m
actor.type = SERVICE
```

**Teléfonos:** ❌ No tiene. Un bot no tiene teléfono.
**Emails:**

| # | Tipo | Dirección | Propósito |
|---|------|-----------|-----------|
| 1 | `technical` | ops@sap-integration.com | Para alertas del sistema |
| 2 | `work` | admin@sap-integration.com | Contacto del responsable humano |

**Direcciones:** ❌ Ninguna dirección física. El bot es un servicio.
**Documentos:** ❌ Sin documentos. El bot se identifica con client_secret + mTLS.

---

**¿Resiste D00?**

Para entidades M2M, la mayoría de campos de contacto NO APLICAN. Solo el email
técnico es relevante. El modelo necesita poder marcar campos como NULL/N-A para
entidades no humanas.

**RESULTADO: ✅ SUFICIENTE** siempre que los campos sean opcionales (nullable).
El modelo D00 actual ya los tiene como TEXT (nullable implícito). Solo necesita
validación que para `actor.type = SERVICE`, los campos de contacto son opcionales.

---

### CASO 9 — Empresa pequeña con NIT de 8 dígitos (Bolivia rural)

```
Nombre  : Doña Carmen Quispe de Mamani
Negocio : Tienda de abarrotes "El Sol" — Viacha, La Paz
Registro: NIT 8 dígitos (persona natural comerciante)
```

**Teléfonos (1 — caso extremo mínimo):**

| # | Tipo | Número |
|---|------|--------|
| 1 | `mobile` | +591 70012345 |

**Nota:** Solo celular, sin fijo. En zonas rurales de Bolivia, muchas personas
solo tienen WhatsApp en el celular. No tienen email (analfabetismo digital).

**Emails (0 — caso sin email):**

No tiene. La comunicación es 100% telefónica / presencial.

**Dirección (1):**

| # | Tipo | Dirección |
|---|------|-----------|
| 1 | `work` | Plaza 6 de Agosto s/n, Viacha, La Paz, BO |

(No tiene número de puerta, no tiene código postal.)

**Documentos (2):**

| # | Tipo | Número |
|---|------|--------|
| 1 | `CI` | 9012345 LP |
| 2 | `NIT` | 90123456 |

---

**¿Resiste D00?**

Este es el caso MÍNIMO: 1 teléfono, 0 emails, 1 dirección sin estructura formal.
El modelo D00 con TEXT para dirección maneja esto correctamente — "Plaza 6 de Agosto
s/n" es un TEXT perfectamente válido aunque no tenga código postal.

**RESULTADO: ✅ SUFICIENTE** para el caso mínimo.
**GAP IMPORTANTE:** El sistema debe aceptar que `bdomain.email` sea NULL — no toda
entidad en Bolivia tiene email. Para obligar email → se excluyen miles de pequeños
comerciantes que son igualmente clientes legítimos del SBOS.

---

### CASO 10 — Empresa multinacional con subsidiaria local (Deloitte Bolivia)

```
Empresa : Deloitte Bolivia Ltda
Matriz  : Deloitte Touche Tohmatsu Limited (DTTL), UK
```

**Teléfonos (3):**

| # | Tipo | Número |
|---|------|--------|
| 1 | `work` | +591 2 277-0000 | Sede La Paz |
| 2 | `work` | +591 4 451-2345 | Oficina Cochabamba |
| 3 | `fax` | +591 2 277-0001 | Fax institucional |

**Emails (4):**

| # | Tipo | Dirección |
|---|------|-----------|
| 1 | `work` | info@deloitte.com.bo |
| 2 | `legal` | legal.bolivia@deloitte.com |
| 3 | `billing` | cuentas@deloitte.com.bo |
| 4 | `technical` | rrhh@deloitte.com.bo |

**Direcciones (3):**

| # | Tipo | Dirección |
|---|------|-----------|
| 1 | `registered` | Av. Arce N° 2631, Torre I, Piso 12, La Paz (escritura) |
| 2 | `fiscal` | Av. Arce N° 2631, Torre I, La Paz (SIN, NIT 9876543210) |
| 3 | `work` | Av. Arce N° 2631, Torre I, Piso 12, La Paz (operaciones) |

**Documentos (2):**

| # | Tipo | Número |
|---|------|--------|
| 1 | `NIT` | 9876543210 | Bolivia |
| 2 | `registered_number` | 123456/2001 | Registro de Comercio Bolivia |

---

## PARTE 3 — ANÁLISIS DE GAPS: ¿QUÉ FALLA EN EL MODELO ACTUAL?

### Gap crítico: UN VALOR por campo, la realidad exige N valores

El modelo D00 actual define:
```
bdomain.email     → TEXT (1 valor)
bdomain.telefono  → TEXT (1 valor)
bdomain.direccion → TEXT (1 valor)
actor.id_doc_type → ENUM (1 tipo, sin el número)
```

La realidad exige:
```
emails[]    → array de {type, value, primary, verified}
phones[]    → array de {type, value, primary, verified}
addresses[] → array de {type, street, number, city, state, country, postal, primary, verified}
id_docs[]   → array de {type, number, country_issue, expiry, primary}
```

### Resumen de multiplicidad por caso

| Caso | Teléfonos | Emails | Direcciones | Documentos |
|------|:---------:|:------:|:-----------:|:----------:|
| Ana Flores (GG Walmart) | 4 | 4 | 3 | 2 |
| Gabriel Romero (extranjero) | 3 | 3 | 2 | **3** |
| Banco Unión (empresa grande) | **5** | **5** | 4 | 2 |
| Don Ernesto (comerciante pequeño) | 2 | 1 | 2 | 2 |
| Dr. Quispe (médico dual) | 3 | 2 | 3 | 2 |
| Familia García (hogar) | 4 | 3 | 2 | 1 |
| Alan Chávez (freelance intl.) | **4** | **4** | 2 | 2 |
| SAP Bot (m2m) | 0 | 2 | 0 | 0 |
| Doña Carmen (rural mínimo) | 1 | **0** | 1 | 2 |
| Deloitte Bolivia | 3 | 4 | 3 | 2 |
| **Promedio** | **2.9** | **2.8** | **2.2** | **1.8** |

**Conclusión estadística:** El campo de datos de contacto tiene en promedio 2-3 valores por tipo.
Un modelo con 1 solo valor captura entre el 30% y 50% de la información real.

---

## PARTE 4 — SOLUCIÓN PROPUESTA (SOLO ANÁLISIS, SIN IMPLEMENTAR)

### Opción A — JSONB arrays en la tabla `org_empresa` / `org_persona` (RECOMENDADA)

Los campos de contacto no van como átomos D00 separados sino como JSONB estructurado
en las tablas operativas `org_empresa`, `org_sucursal`, y `org_actor`:

```sql
-- En org_empresa (o en una tabla org_contacto normalizada):
emails    JSONB,  -- [{type, value, primary, verified}]
phones    JSONB,  -- [{type, value, primary, verified}]
addresses JSONB,  -- [{type, components..., primary, verified}]
id_docs   JSONB   -- [{type, number, country, expiry, primary}]
```

**Ventajas:**
- Ilimitados valores por tipo
- Tipificación completa (work, home, mobile, fax…)
- Marcadores primary/verified por cada valor
- No requiere nuevos átomos D00 — los átomos ya existen (`bdomain.email`,
  `bdomain.telefono`, etc.), solo cambia cómo se ALMACENA el valor del átomo

**El átomo D00 sigue siendo el NOMBRE (la clave); el JSONB es el contenido**

### Opción B — Tablas relacionales normalizadas

```sql
CREATE TABLE org_contacto (
  id          UUID PK,
  entidad_id  UUID FK (puede ser bdomain_id, bsubdomain_id, actor_id),
  entidad_tipo TEXT, -- 'empresa', 'sucursal', 'actor'
  contact_type TEXT, -- 'email', 'phone', 'address'
  value_type   TEXT, -- 'work', 'home', 'mobile', 'fiscal'...
  value        TEXT,
  is_primary   BOOLEAN,
  is_verified  BOOLEAN,
  verified_at  TIMESTAMPTZ
);
```

**Ventajas:** Máxima flexibilidad, consultas SQL directas por tipo.
**Desventajas:** JOIN adicional en cada consulta. Más complejo.

### Opción C — SCIM 2.0 nativo (RFC 7643)

Adoptar el formato SCIM 2.0 exactamente como está definido en el RFC, que ya
resuelve exactamente este problema con arrays tipificados. Es el estándar
internacional para exactamente esta variedad de datos de contacto.

```json
{
  "emails": [{"value": "work@co.bo", "type": "work", "primary": true}],
  "phoneNumbers": [{"value": "+59171234567", "type": "mobile", "primary": true}],
  "addresses": [{"type": "work", "streetAddress": "Av. Arce 2678", "primary": true}]
}
```

---

## PARTE 5 — VEREDICTO FINAL

### ¿El modelo D00 actual RESISTE la variedad real de datos de contacto?

**NO en la forma actual.**

Los átomos D00 como TEXT simple (`bdomain.email`, `bdomain.telefono`) son suficientes
para el **caso mínimo** (1 persona, 1 email, 1 celular, 1 dirección), pero fallan
en todos los casos empresariales y en cualquier persona con vida real compleja.

### Lo que SÍ funciona sin cambios

| Aspecto | Estado |
|---------|:------:|
| Estructura de átomos (nombre → valor) | ✅ Correcta |
| ctx_id (interno.tenant.bdomain.bsubdomain) | ✅ No cambia |
| Tipos de bDomain (empresa/persona/hogar/m2m/edificio) | ✅ Correctos |
| Grupos D00 (g1 tenant, g2 bdomain, g3 bsubdomain, g4 pos, g5 actor) | ✅ Correctos |
| 20 átomos de D00 en posiciones 5809-5828 | ✅ Correctos |
| BitMask dual (contextual + logical) | ✅ No afectado |
| Tipos de actor (HUMAN/SERVICE/DEVICE/BOT) | ✅ Correctos |
| Atributos actor (gender, marital_status, locale, timezone) | ✅ Correctos |

### Lo que NECESITA ser extendido

| Aspecto | Cambio requerido |
|---------|-----------------|
| `bdomain.email` → 1 valor | → JSONB array con tipos (work/home/billing/technical) |
| `bdomain.telefono` → 1 valor | → JSONB array con tipos (mobile/work/fax/whatsapp) |
| `bdomain.direccion` → 1 texto plano | → JSONB array con tipos + componentes estructurados |
| `actor.id_doc_type` → 1 ENUM | → JSONB array de documentos con tipo + número + país |
| Email obligatorio | → Debe ser nullable (caso Doña Carmen: 0 emails) |

### Estas extensiones NO cambian los átomos D00

Los 20 átomos D00 ya definidos siguen siendo válidos. Lo que cambia es el
**contenido del valor** del átomo: en vez de TEXT simple, el valor es un
**JSONB array estructurado**. El átomo es la llave; el JSONB es el contenido rico.

Este cambio es en las **tablas operativas** (`org_empresa`, `org_actor`) y en los
seeds, no en `privilege_atom`. Por eso no requiere nueva migración D00 — requiere
diseño de las tablas `org_*` que aún no existen en la BD actual.

---

*Ensayo de planificación — no requiere aprobación DDL para el análisis.*
*Las tablas org_* mencionadas no existen aún y forman parte del trabajo B2 (Gate B2).*
