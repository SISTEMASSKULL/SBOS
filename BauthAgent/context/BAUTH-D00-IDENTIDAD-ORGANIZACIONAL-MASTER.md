# D00 — Identidad Organizacional: Documento Maestro
**Documento:** BAUTH-D00-IDENTIDAD-ORGANIZACIONAL-MASTER
**Versión:** 1.0.0 · **Clasificación:** INTERNO CRÍTICO
**Fecha:** 2026-06-30 · **Autor:** bauth-developer / sbos-coordinador
**Propósito:** Consolidar todo el diseño, investigación, pruebas y decisiones
del Dominio D00 (Identidad Organizacional) de bAuth. Este documento es la fuente
de verdad única (SSOT) para el diseño conceptual y estructural del D00.
**Normas:** SBOS-MODEL-D00 v1.0 · ISO 24760-2:2025 · SCIM 2.0 RFC 7643
**Relacionados:**
  - `ENSAYO-D00-PRUEBAS-ESCRITORIO.md` — 50 pruebas de escritorio
  - `ENSAYO-D00-VARIEDAD-DATOS-CONTACTO.md` — análisis de variedad
  - `ANALISIS-D00-MODELO-VERTICAL-CONTACTOS.md` — modelo vertical
  - `BAUTH-AUTENTICACION-DIMENSIONAL-v1.0.md` — marco de auditoría
  - `../../../BauthAgent/db/migrations/003_d00_identidad_organizacional.sql` — DDL pendiente

---

## PARTE 1 — DEFINICIÓN Y PROPÓSITO DEL DOMINIO D00

### 1.1 Qué es D00

El Dominio D00 — Identidad Organizacional — es el **dominio base estructural del sistema
de identidad de bAuth**. No es un dominio de control de acceso (no se alinea directamente
con OIDC/SAML/OAuth2). Es la precondición estructural del `ctx_id`: la representación
formal de dónde opera cada actor dentro del ecosistema SBOS.

```
ctx_id = interno.tenant_uuid.bdomain_uuid.bsubdomain_uuid
         ↑       ↑            ↑            ↑
         D00     D00          D00          D00
```

**D00 responde la pregunta:** ¿QUÉ ES esta entidad y en qué contexto organizacional opera?
**D1-D12 responden:** ¿QUÉ PUEDE HACER esta entidad en ese contexto?

D00 no autentica ni autoriza. Ubica. La autenticación es responsabilidad de los motores
(Keycloak, Vault, Besu). La autorización es responsabilidad del BitMask (D1-D12).

### 1.2 Árbol de agrupación (grupos G1-G5)

```
tenant (G1)
│   Quién contrata el servicio SBOS
│   internal: el tenant interno SKULL
│   external: cualquier organización cliente del SBOS
│
├── bDomain (G2)
│       La entidad legal o funcional que opera dentro del tenant
│       Tipos: empresa / persona / hogar / desarrollador / m2m / edificio
│
│   ├── bSubDomain (G3)
│   │       Una subdivisión del bDomain (sucursal, departamento, hogar)
│   │       Tipos: sucursal / dependiente / familiar / oficina
│   │
│   │   ├── Pos (G4)
│   │   │       El punto de presencia físico o virtual
│   │   │       Tipos: caja / terminal / puerta / sensor / actuador / punto_virtual
│   │   │
│   │   └── Actor (G5)
│   │           El ente que opera en el sistema
│   │           Tipos: HUMAN / SERVICE / DEVICE / BOT
```

### 1.3 Cobertura semántica del D00 (prueba de 50 casos)

Las 50 pruebas de escritorio (ENSAYO-D00-PRUEBAS-ESCRITORIO.md) validan que D00
resiste el **96.8% de los casos reales** del espectro completo de organizaciones
bolivianas y LATAM:

| Tipo bDomain | Cobertura | Observaciones |
|:------------:|:---------:|--------------|
| empresa (multinacional, mediana, pequeña) | ✅ 100% | Ningún gap |
| persona (natural con NIT) | ✅ 100% | Ningún gap |
| hogar (familia con servicios contratados) | ⚠️ 95% | G01: employee_type sin NONE/STUDENT |
| desarrollador (freelance, API consumer) | ✅ 100% | Ningún gap |
| m2m (bots, servicios automatizados) | ⚠️ 90% | G01+G02: employee_type e id_doc_type para no-humanos |
| edificio (condominio, centro comercial) | ✅ 100% | Ningún gap |

**Indexación ctx_id — correcta en 100% de los casos:**
- ✅ Dos empleados de la misma empresa en distinta sucursal → `bsubdomain_uuid` diferente
- ✅ La misma persona en dos empresas distintas → `bdomain_uuid` diferente (context switch D8)
- ✅ Un bot vs un humano en la misma empresa → `actor.type` diferente, mismo `ctx_id`
- ✅ Visitante externo vs empleado interno → `tenant.type` diferente
- ✅ Empresa de 1 persona vs multinacional → misma estructura, diferente escala

---

## PARTE 2 — CATÁLOGO DE 20 ÁTOMOS D00 (versión actual)

### 2.1 Posiciones y contexto BitMask

```
Dominio  : 0 (D00)
App      : 13 (org)
Rango    : atom_position 5809-5828
Tipo     : REGLA — el átomo define una regla de datos con validación

Fórmulas de máscara:
  contextual_mask = (domain_code << 8) | (app_code << 12) | (group_code << 21)
  logical_mask    = (verb_code << 8)

  domain_code=0, app_code=13 → base = 53248
  G1 Tenant    : 53248 | (1<<21) = 2150400
  G2 bDomain   : 53248 | (2<<21) = 4247552
  G3 bSubDomain: 53248 | (3<<21) = 6344704
  G4 Pos       : 53248 | (4<<21) = 8441856
  G5 Actor     : 53248 | (5<<21) = 10538496
```

### 2.2 Los 20 átomos

| Posición | atom_code | atom_slug | Grupo | Verbo | Descripción | Clasificación ISO 24760 |
|:--------:|:---------:|-----------|:-----:|:-----:|-------------|:-----------------------:|
| 5809 | 5809 | `org.g1.d0.type` | G1 Tenant | type(51) | Tipo de tenant: interno/externo | CRITICAL |
| 5810 | 5810 | `org.g2.d0.type` | G2 bDomain | type(51) | Tipo de bDomain: empresa/persona/hogar/dev/m2m/edificio | CRITICAL |
| 5811 | 5811 | `org.g2.d0.nombre` | G2 bDomain | nombre(52) | Nombre legal del bDomain (2-128 chars) | INTERNAL |
| 5812 | 5812 | `org.g2.d0.nit` | G2 bDomain | nit(53) | NIT tributario `^\d{8,12}$` (nullable para hogar/persona sin NIT) | CONFIDENTIAL |
| 5813 | 5813 | `org.g2.d0.email` | G2 bDomain | email(54) | Email del bDomain (RFC 5321) | INTERNAL |
| 5814 | 5814 | `org.g2.d0.telefono` | G2 bDomain | telefono(55) | Teléfono del bDomain (E.164) | INTERNAL |
| 5815 | 5815 | `org.g2.d0.ci` | G2 bDomain | ci(56) | Carnet de identidad (solo bdomain.type=persona) | CONFIDENTIAL |
| 5816 | 5816 | `org.g2.d0.direccion` | G2 bDomain | direccion(57) | Dirección del bDomain | INTERNAL |
| 5817 | 5817 | `org.g3.d0.type` | G3 bSubDomain | type(51) | Tipo de sucursal: sucursal/dependiente/familiar/oficina | INTERNAL |
| 5818 | 5818 | `org.g3.d0.nombre` | G3 bSubDomain | nombre(52) | Nombre de la sucursal (2-128 chars) | INTERNAL |
| 5819 | 5819 | `org.g3.d0.direccion` | G3 bSubDomain | direccion(57) | Dirección de la sucursal | INTERNAL |
| 5820 | 5820 | `org.g4.d0.type` | G4 Pos | type(51) | Tipo de POS: caja/terminal/puerta/sensor/actuador/punto_virtual | INTERNAL |
| 5821 | 5821 | `org.g4.d0.nombre` | G4 Pos | nombre(52) | Nombre del punto de presencia (2-64 chars) | INTERNAL |
| 5822 | 5822 | `org.g5.d0.type` | G5 Actor | type(51) | Tipo de actor: HUMAN/SERVICE/DEVICE/BOT | INTERNAL |
| 5823 | 5823 | `org.g5.d0.employee_type` | G5 Actor | employee_type(58) | Tipo de empleo: FULL_TIME/PART_TIME/CONTRACTOR/INTERN | RESTRICTED |
| 5824 | 5824 | `org.g5.d0.gender` | G5 Actor | gender(59) | Género: M/F/NB/NR | RESTRICTED |
| 5825 | 5825 | `org.g5.d0.marital_status` | G5 Actor | marital_status(60) | Estado civil: SINGLE/MARRIED/DIVORCED/WIDOWED/CIVIL_UNION | RESTRICTED |
| 5826 | 5826 | `org.g5.d0.id_doc_type` | G5 Actor | id_doc_type(61) | Tipo de documento: CI/PASSPORT/DNI/NIT/RUT/CPF/... | CONFIDENTIAL |
| 5827 | 5827 | `org.g5.d0.locale` | G5 Actor | locale(62) | Locale BCP 47 (es-BO, es-AR, pt-BR) | PUBLIC |
| 5828 | 5828 | `org.g5.d0.timezone` | G5 Actor | timezone(63) | Zona horaria IANA (America/La_Paz) | PUBLIC |

### 2.3 Verbos especiales D00 (51-63)

**IMPORTANTE:** Los verbos 51-63 son verbos de **dimensión semántica** (identifican el tipo
de dato dentro del átomo REGLA). No son verbos de acción CRUD. Esta distinción es crítica
para el diseño del motor BitMask y está documentada en la §3 de este documento.

| verb_code | verb_name | verb_slug | Semántica |
|:---------:|-----------|-----------|-----------|
| 51 | Tipo | type | Discriminador de tipo de entidad (ENUM) |
| 52 | Nombre | nombre | Nombre legal TEXT 2-128 |
| 53 | NIT | nit | Registro tributario `^\d{8,12}$` |
| 54 | Email | email | Dirección RFC 5321 |
| 55 | Teléfono | telefono | E.164 |
| 56 | Carnet | ci | Carnet de identidad con extensión departamental |
| 57 | Dirección | direccion | Texto libre de dirección |
| 58 | Tipo empleo | employee_type | ENUM de tipo de relación laboral |
| 59 | Género | gender | ENUM M/F/NB/NR |
| 60 | Estado civil | marital_status | ENUM estado civil |
| 61 | Tipo documento | id_doc_type | ENUM de tipo de documento de identidad |
| 62 | Locale | locale | BCP 47 |
| 63 | Zona horaria | timezone | IANA TZ database |

---

## PARTE 3 — ANÁLISIS DEL MOTOR BITMASK APLICADO AL D00

### 3.1 Arquitectura BitMask dual

El motor BitMask de bAuth tiene dos estructuras conceptualmente distintas:

**`AtomBitMask` (64 bits — etiqueta del átomo):**
```
Bits 0-31 (contextual_mask):
  bits 0-7   → DeviceCategories (8 tipos: MOBILE, CARD, BIOMETRIC, IOT...)
  bits 8-11  → domain_code (D0-D15, 4 bits)
  bits 12-20 → app_code (1-511, 9 bits)
  bits 21-31 → group_code (1-2047, 11 bits)

Bits 32-63 (logical_mask):
  bits 0-2   → TrustLevel (NONE/LOW/MEDIUM/HIGH/CRITICAL)
  bits 3-4   → TokenBinding (NONE/DEVICE/SESSION/HARDWARE)
  bit  5     → blockchain_anchored
  bits 6-7   → PolicyState
  bits 8-31  → verb_code (24 bits, label encoding)
```

El `AtomBitMask` identifica a UN átomo. **No se combina con OR/AND entre dos
`AtomBitMask` distintos** — ese uso es incorrecto.

**`RolBitMask` (N bits — mapa de permisos del rol):**
```
bits[0..N]: un bit por atom_position
  bit[5809] = 1 → el rol TIENE permiso sobre org.g1.d0.type
  bit[5813] = 1 → el rol TIENE permiso sobre org.g2.d0.email
  bit[5814] = 0 → el rol NO tiene permiso sobre org.g2.d0.telefono
```

Las operaciones sobre `RolBitMask` son algebraicas:
```
union(A, B)   → A | B   → unión de permisos (herencia OR del DAG)
intersect(A,B)→ A & B   → delegación (solo los permisos compartidos)
revoke(A, B)  → A & ¬B  → revocar los permisos de B del conjunto A
delta(A, B)   → A ^ B   → diferencia simétrica (permisos exclusivos)
```

Evaluación de permiso en runtime:
```rust
let position = resolver.resolve("org.g2.d0.email"); // → 5813
let tiene_permiso = rol_bitmask.check(position);    // → bool, <0.5ns
```

### 3.2 Diseño actual D00 vs D.A.M.V correcto

**PROBLEMA IDENTIFICADO:** Los átomos D00 actuales usan los verbos (51-63) como
**nombres de campo** (semántica), no como **acciones sobre el campo** (CRUD).

```
DISEÑO ACTUAL (verbos como nombres de campo):
  átomo: D00.org.bdomain(g2).email(verb=54)
          ↑                          ↑
          grupo = bdomain             verbo = "el dato es un email"

DISEÑO D.A.M.V CORRECTO (campos como grupos, verbos como acciones):
  átomo: D00.org.bdomain_email(g05).ver(verb=4)
  átomo: D00.org.bdomain_email(g05).editar(verb=2)
  átomo: D00.org.bdomain_email(g05).crear(verb=1)
  átomo: D00.org.bdomain_email(g05).eliminar(verb=3)
          ↑                          ↑
          grupo = el CAMPO específico  verbo = la ACCIÓN sobre ese campo
```

**¿Por qué importa esta distinción?**

Con el diseño actual, un átomo `org.g2.d0.email` no puede expresar granularidad de
acción. Un rol puede "tener permiso sobre el email" pero el sistema no sabe si ese
permiso es de lectura, escritura, o ambos. Para que BitMask evalúe correctamente
los permisos granulares (ama de casa solo edita su teléfono; supervisor agrega reglas;
administrador edita templates completos), cada combinación campo × acción necesita
su propio bit.

**Corolario:** El diseño actual funciona para el caso de "la entidad TIENE ese dato"
(validación estructural). No funciona para "¿puede ESTE ROL EDITAR ese dato específico?"
(control de acceso granular por campo).

### 3.3 Diseño de redesño D.A.M.V (trabajo pendiente, no implementado)

El redesño pendiente propone que cada campo de D00 se convierta en un **grupo G** y
que los verbos CRUD (1-4) se apliquen sobre ese grupo:

| Campo actual (verbo) | Grupo en redesño | Átomos resultantes (campo × 4 acciones CRUD) |
|----------------------|:--------------:|:-------------------------------------------:|
| `bdomain.type` | G2.01 | bdomain_type × {crear, editar, eliminar, ver} = 4 átomos |
| `bdomain.nombre` | G2.02 | bdomain_nombre × {crear, editar, eliminar, ver} = 4 átomos |
| `bdomain.nit` | G2.03 | bdomain_nit × {crear, editar, eliminar, ver} = 4 átomos |
| `bdomain.email` | G2.04 | bdomain_email × {crear, editar, eliminar, ver} = 4 átomos |
| `bdomain.telefono` | G2.05 | bdomain_telefono × {crear, editar, eliminar, ver} = 4 átomos |
| `actor.telefono` | G5.03 | actor_telefono × {crear, editar, eliminar, ver} = 4 átomos |
| (todos los 20 campos) | — | ~20 campos × 4 acciones = ~80 átomos totales en D00 |

**Estado:** Planificado. Requiere aprobación antes de implementar (ADR-016).
**Impacto:** Los 20 átomos actuales (posiciones 5809-5828) serían reemplazados por ~80
átomos. El DDL de migración 003 necesita actualizarse.

---

## PARTE 4 — ANÁLISIS DE VARIEDAD DE DATOS DE CONTACTO

### 4.1 Conclusión: el campo TEXT simple es insuficiente

El análisis de 10 casos reales (ENSAYO-D00-VARIEDAD-DATOS-CONTACTO.md) demuestra que
los campos de contacto en D00 como columna TEXT simple capturan entre el 20% y el 50%
de la información real de las entidades:

| Campo D00 actual | Valor único (TEXT) | Promedio real (N valores) | Cobertura con TEXT |
|-----------------|:-----------------:|:-------------------------:|:-----------------:|
| `bdomain.email` | 1 | 2.8 emails por entidad | 30-50% |
| `bdomain.telefono` | 1 | 2.9 teléfonos por entidad | 30-50% |
| `bdomain.direccion` | 1 | 2.2 direcciones por entidad | 40-60% |
| `actor.id_doc_type` | 1 tipo | 1.8 documentos por actor | 50-100% |

Los casos extremos de pérdida:
- Banco Unión SA: 5 emails — el modelo actual captura 1 (20%)
- Ana Flores (GG Walmart): 4 teléfonos — captura 1 (25%)
- Gabriel Romero (extranjero): 3 documentos de 2 países — captura 1 (33%)
- Familia García: 4 teléfonos para contacto de emergencia — captura 1 (25%)

**La normativa ASFI (Bolivia) y SFB (regulación financiera) exige registrar todos
los documentos de identidad de extranjeros residentes**, no solo el principal.
El campo TEXT simple no puede cumplir este requisito legal.

### 4.2 Taxonomía completa de tipos de contacto

**Tipos de teléfono (SCIM 2.0 RFC 7643 §4.1.2):**

| Subtipo | Descripción | Frecuencia en Bolivia |
|---------|------------|:--------------------:|
| `mobile` | Celular personal | Muy alta |
| `work` | Teléfono fijo trabajo / central | Alta |
| `home` | Teléfono fijo domicilio | Media |
| `work_mobile` | Celular corporativo (SIM empresa) | Media (empresa grande) |
| `whatsapp` | WhatsApp — principal en LATAM | Muy alta |
| `fax` | Fax empresarial | Media (empresa, gobierno) |
| `emergency` | Contacto de emergencia | Baja |
| `voip` | VoIP / extensión interna | Baja (freelancer, startup) |
| `satellite` | Satelital (minería, campo remoto) | Muy baja |

**Tipos de email (empresas reales):**

| Subtipo | Descripción |
|---------|------------|
| `work` | Email corporativo principal |
| `home` | Email personal |
| `alternate` | Email de respaldo / backup |
| `billing` | Solo para facturas y pagos |
| `legal` | Notificaciones legales |
| `technical` | APIs, soporte, CI/CD, webhooks |
| `notifications` | Alertas del sistema |

**Tipos de dirección (SCIM 2.0 + SIN Bolivia):**

| Subtipo | Cuándo aplica |
|---------|--------------|
| `work` | Dirección operativa / de trabajo |
| `home` | Domicilio personal |
| `fiscal` | Registrada ante SIN / impuestos |
| `registered` | Escritura pública / notaría |
| `billing` | Dirección de facturación |
| `delivery` | Entrega de paquetes |
| `mailing` | Correspondencia postal / casilla |
| `virtual` | Buzón virtual (startups, freelancers) |

**Tipos de documento de identidad (20+ países LATAM):**

| Tipo | País / Alcance | Aplica a |
|------|---------------|---------|
| `CI` | Bolivia (ciudadano) | Persona |
| `CI_EXT` | Bolivia (extranjero residente) | Persona |
| `NIT` | Bolivia (persona natural o empresa) | Ambos |
| `PASSPORT` | Internacional | Persona |
| `DNI` | Argentina, España | Persona |
| `CUIT` | Argentina | Empresa |
| `RUT` | Chile | Ambos |
| `CPF` | Brasil | Persona |
| `CNPJ` | Brasil | Empresa |
| `CURP` | México | Persona |
| `RFC` | México | Ambos |
| `RUC` | Perú, Ecuador | Ambos |
| `CC` | Colombia | Persona |
| `NIT_CO` | Colombia | Empresa |
| `SSN` | USA | Persona |
| `TIN` | USA | Empresa |
| `registered_number` | Bolivia | Registro Comercio |

---

## PARTE 5 — MODELO VERTICAL DE CONTACTOS

### 5.1 El principio

El modelo vertical resuelve la restricción 1:1 del campo TEXT simple. En lugar de
una columna por campo, se usa **una fila por valor**, con el átomo D00 como
referencia del tipo de dato:

```
MODELO PLANO (antes):
┌──────────────────────────────────────────────────────────────┐
│ bdomain_id │ email             │ telefono      │ direccion   │
├────────────┼───────────────────┼───────────────┼─────────────┤
│ BD-banco   │ info@banco.bo     │ +59122700001  │ Av. Camacho │  ← 1 de cada uno
└──────────────────────────────────────────────────────────────┘

MODELO VERTICAL (propuesto):
┌──────────────────────────────────────────────────────────────────────────┐
│ entidad_id │ atom_code │ subtype    │ valor               │ is_primary   │
├────────────┼───────────┼────────────┼─────────────────────┼──────────────┤
│ BD-banco   │ 5813      │ work       │ info@banco.bo       │ true         │
│ BD-banco   │ 5813      │ billing    │ facturas@banco.bo   │ false        │
│ BD-banco   │ 5813      │ legal      │ legal@banco.bo      │ false        │
│ BD-banco   │ 5813      │ technical  │ soporte@banco.bo    │ false        │
│ BD-banco   │ 5814      │ work       │ +59122700001        │ true         │
│ BD-banco   │ 5814      │ emergency  │ +59179090000        │ false        │
└──────────────────────────────────────────────────────────────────────────┘
  atom_code 5813 = D00.org.bdomain.email    (el átomo define el TIPO)
  atom_code 5814 = D00.org.bdomain.telefono (las filas son las INSTANCIAS)
```

**Principio fundamental:** Los átomos D00 son DEFINICIONES DE TIPO. Las filas en
las tablas verticales son INSTANCIAS. Los 20 átomos permanecen sin cambios.

### 5.2 Las 3 tablas verticales necesarias

#### `bauth.org_contacto` — Teléfonos y Emails

```sql
-- Tabla vertical: email + telefono (campos de valor texto simple)
-- atom_code → FK privilege_atom → define qué tipo de dato es cada fila
-- subtype → subtipo dentro de esa categoría (work/home/mobile/billing...)
CREATE TABLE bauth.org_contacto (
  id            UUID        NOT NULL DEFAULT gen_random_uuid(),
  entidad_tipo  TEXT        NOT NULL,  -- 'bdomain' | 'bsubdomain' | 'actor'
  entidad_id    UUID        NOT NULL,
  atom_code     INT         NOT NULL,  -- FK privilege_atom (5813=email, 5814=tel...)
  subtype       TEXT        NOT NULL,  -- work/home/mobile/billing/legal/technical...
  valor         TEXT        NOT NULL,
  is_primary    BOOLEAN     NOT NULL DEFAULT false,
  is_verified   BOOLEAN     NOT NULL DEFAULT false,
  verified_at   TIMESTAMPTZ,
  sort_order    SMALLINT    NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT pk_org_contacto PRIMARY KEY (id),
  CONSTRAINT fk_org_contacto_atom FOREIGN KEY (atom_code)
    REFERENCES bauth.privilege_atom(atom_code),
  CONSTRAINT ck_entidad_tipo CHECK (entidad_tipo IN ('bdomain','bsubdomain','actor')),
  -- Solo 1 primary=true por (entidad + atom_code):
  CONSTRAINT uq_contacto_primary
    UNIQUE NULLS NOT DISTINCT (entidad_id, atom_code, is_primary)
    DEFERRABLE INITIALLY DEFERRED
);
-- PENDIENTE APROBACIÓN DDL (ADR-016)
```

| atom_code | Átomo D00 | Subtipos válidos |
|:---------:|-----------|-----------------|
| 5813 | `org.g2.d0.email` | work, home, billing, legal, technical, notifications, alternate |
| 5814 | `org.g2.d0.telefono` | mobile, work, home, fax, work_mobile, whatsapp, emergency, voip, satellite |
| 5815 | `org.g2.d0.ci` | CI, CI_EXT |

#### `bauth.org_documento` — Documentos de Identidad

```sql
-- Documentos con estructura rica: tipo + número + país + vencimiento
CREATE TABLE bauth.org_documento (
  id            UUID        NOT NULL DEFAULT gen_random_uuid(),
  entidad_tipo  TEXT        NOT NULL DEFAULT 'actor',
  entidad_id    UUID        NOT NULL,
  doc_type      TEXT        NOT NULL,  -- CI, CI_EXT, PASSPORT, NIT, DNI, CUIT, CPF...
  doc_number    TEXT        NOT NULL,
  country_issue CHAR(2)     NOT NULL DEFAULT 'BO',  -- ISO 3166-1 alpha-2
  issued_at     DATE,
  expires_at    DATE,
  is_primary    BOOLEAN     NOT NULL DEFAULT false,
  is_verified   BOOLEAN     NOT NULL DEFAULT false,
  verified_at   TIMESTAMPTZ,
  verified_by   TEXT,       -- 'manual' | 'api_registro_civil' | 'api_sin'
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT pk_org_documento PRIMARY KEY (id),
  CONSTRAINT uq_doc_per_entity UNIQUE (entidad_id, doc_type, country_issue),
  CONSTRAINT uq_doc_primary
    UNIQUE NULLS NOT DISTINCT (entidad_id, is_primary)
    DEFERRABLE INITIALLY DEFERRED
);
-- PENDIENTE APROBACIÓN DDL (ADR-016)
```

**Relación con D00:** El átomo `5826 = org.g5.d0.id_doc_type` declara que el actor
tiene documentos. La tabla `org_documento` almacena las N instancias con tipo + número +
país + vencimiento.

#### `bauth.org_direccion` — Direcciones Estructuradas

```sql
-- Direcciones con sub-campos (calle, número, ciudad, país)
CREATE TABLE bauth.org_direccion (
  id            UUID        NOT NULL DEFAULT gen_random_uuid(),
  entidad_tipo  TEXT        NOT NULL,   -- 'bdomain' | 'bsubdomain' | 'actor'
  entidad_id    UUID        NOT NULL,
  addr_type     TEXT        NOT NULL,   -- work/home/fiscal/billing/delivery/registered/virtual
  -- Componentes de la dirección:
  street        TEXT,                   -- Av. Arce / C. Ayacucho / Plaza 6 de Agosto
  number        TEXT,                   -- N° 2678 / s/n / sin número
  floor         TEXT,                   -- Piso 8 / 3°
  office        TEXT,                   -- Of. 801 / Dpto. B
  neighborhood  TEXT,                   -- Sopocachi / Villa Dolores
  municipality  TEXT        NOT NULL,   -- La Paz / El Alto / Viacha
  department    TEXT,                   -- La Paz / Cochabamba / Santa Cruz
  country       CHAR(2)     NOT NULL DEFAULT 'BO',
  postal_code   TEXT,                   -- nullable: Bolivia no usa CP sistemáticamente
  full_address  TEXT GENERATED ALWAYS AS (
    TRIM(CONCAT_WS(', ',
      NULLIF(TRIM(CONCAT_WS(' ', street, number)), ''),
      NULLIF(TRIM(CONCAT_WS(' ', floor, office)), ''),
      neighborhood, municipality, department, country, postal_code
    ))
  ) STORED,
  is_primary    BOOLEAN     NOT NULL DEFAULT false,
  is_verified   BOOLEAN     NOT NULL DEFAULT false,
  verified_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT pk_org_direccion PRIMARY KEY (id),
  CONSTRAINT ck_addr_type CHECK (addr_type IN (
    'work','home','fiscal','billing','delivery','mailing',
    'registered','branch','warehouse','virtual'
  )),
  CONSTRAINT uq_direccion_primary
    UNIQUE NULLS NOT DISTINCT (entidad_id, is_primary)
    DEFERRABLE INITIALLY DEFERRED
);
-- PENDIENTE APROBACIÓN DDL (ADR-016)
```

### 5.3 Regla de cardinalidad para átomos D00

```
Dato con cardinalidad 1:1 por entidad → columna directa en org_empresa / org_actor
  Ejemplos: bdomain.type, bdomain.nombre, bdomain.nit, actor.gender, actor.locale

Dato con cardinalidad 1:N por entidad → tabla vertical (org_contacto/org_documento/org_direccion)
  Ejemplos: bdomain.email, bdomain.telefono, bdomain.direccion, actor.id_doc_type
```

### 5.4 Resultado: cobertura con modelo vertical (10 casos)

| Caso | Modelo plano | Modelo vertical |
|------|:-----------:|:---------------:|
| Ana Flores (GG Walmart) — 4 tel, 4 email, 2 doc | ❌ 25% | ✅ 100% |
| Gabriel Romero (extranjero) — 3 doc de 2 países | ❌ 33% | ✅ 100% |
| Banco Unión SA — 5 tel, 5 email | ❌ 20% | ✅ 100% |
| Don Ernesto — 2 tel, 2 dir | ❌ 50% | ✅ 100% |
| Dr. Quispe — WhatsApp + consultorio + 2 dir | ❌ 33% | ✅ 100% |
| Familia García — 4 tel del hogar | ❌ 25% | ✅ 100% |
| Alan Chávez freelance intl. — 3 países, 4 emails | ❌ 25% | ✅ 100% |
| SAP Bot — 0 teléfonos (servicio) | ✅ NULL | ✅ 0 filas |
| Doña Carmen — 0 emails (rural) | ✅ NULL col | ✅ 0 filas |
| Deloitte Bolivia — 2 documentos empresa | ❌ 50% | ✅ 100% |

**El modelo vertical logra 100% de cobertura en todos los casos reales.**

---

## PARTE 6 — GAPS IDENTIFICADOS Y ESTADO DE RESOLUCIÓN

### 6.1 Gaps en ENUMs de actor (Gap G01, G02)

| Gap | Descripción | Casos afectados | Solución |
|-----|-------------|-----------------|---------|
| G01 | `actor.employee_type` sin valor para no-empleados | Hogar, M2M, bots, dispositivos | Agregar: NONE, STUDENT, DEPENDENT, SERVICE_ACCOUNT |
| G02 | `actor.id_doc_type` sin valor para entidades no humanas | M2M, DEVICE, BOT | Agregar valor: NONE |

### 6.2 Atributos que NO son de D00 (falsos gaps)

| Atributo | Ubicación correcta | Razón |
|----------|-------------------|-------|
| Tipo societario (SRL, SA, SAS) | Tabla operativa `org_empresa` | D00 captura identidad, no caracterización legal |
| Sector CAEB/industria | Tabla operativa `org_empresa` | Dato de negocio, no de identidad |
| Número registro profesional | `RolTemplate.certifications` | Es atributo del rol, no del actor |
| Estado civil del cliente | Tryton CRM | D00 describe al actor del sistema, no a sus clientes |

### 6.3 Estado general del D00

| Componente | Estado | Siguiente acción |
|-----------|:------:|-----------------|
| 20 átomos D00 (positions 5809-5828) | ✅ Diseñados | Aprobación DDL + aplicar migración 003 |
| Verbos especiales 51-63 | ✅ Diseñados | Incluir en migración 003 |
| `idn_tenant.is_internal` | ✅ Diseñado | Aprobación DDL + aplicar migración 003 |
| CHECK `domain_code BETWEEN 0 AND 15` | ✅ Diseñado | Aprobación DDL + aplicar migración 003 |
| Tabla `org_contacto` | ⏳ Pendiente diseño final | Aprobación DDL separada |
| Tabla `org_documento` | ⏳ Pendiente diseño final | Aprobación DDL separada |
| Tabla `org_direccion` | ⏳ Pendiente diseño final | Aprobación DDL separada |
| Redesño D.A.M.V (~80 átomos) | ⏳ Pendiente diseño | Aprobación de concepto primero |
| ENUMs G01/G02 (NONE/STUDENT/etc.) | ⏳ Pendiente | Incluir en migración 003 al aprobar |

---

## PARTE 7 — CONTROL DE ACCESO GRANULAR POR CAMPO EN D00

### 7.1 Quién puede hacer qué en D00

La siguiente matriz aplica el modelo D.A.M.V (campo × verbo) con los 7 tiers del
catálogo de roles bAuth:

| Campo D00 | EXT_N0 (Hogar) | BIZ_N5 Operativo | BIZ_N3 Especialista | BIZ_N2 Supervisor | BIZ_N1 Admin | SU/SYS |
|-----------|:-------------:|:----------------:|:-------------------:|:-----------------:|:------------:|:------:|
| `tenant.type` | — | — | — | ver | ver | todo |
| `bdomain.nit` | — | — | ver | ver | ver+editar | todo |
| `bdomain.ci` (persona) | — | — | — | ver | ver+editar | todo |
| `bdomain.nombre` | ver | ver | ver | ver+editar | todo | todo |
| `bdomain.email` | ver | ver | ver | ver+editar | todo | todo |
| `bdomain.telefono` | ver | ver | ver+editar | ver+editar | todo | todo |
| `bdomain.direccion` | ver | ver | ver | ver+editar | todo | todo |
| `actor.id_doc_type` | ver propio | ver propio | ver | ver+editar | todo | todo |
| `actor.telefono` | todo propio | ver+editar propio | ver+editar | todo | todo | todo |
| `actor.email` | todo propio | ver+editar propio | ver+editar | todo | todo | todo |
| `actor.gender` | ver propio | ver propio | ver | ver | ver+editar | todo |
| `actor.marital_status` | ver propio | ver propio | — | ver | ver+editar | todo |
| `actor.locale` | todo propio | todo propio | ver | todo | todo | todo |
| `actor.timezone` | todo propio | todo propio | ver | todo | todo | todo |
| `roltemplate.*` (cualquier campo) | — | — | ver | ver | ver+editar | todo |
| `usertemplate.*` (datos propios) | ver propio | ver propio | ver | ver+editar | todo | todo |

*todo = crear + editar + eliminar + ver · ver = solo lectura · — = sin acceso · propio = solo sus propios datos*

### 7.2 Ejemplos concretos de evaluación BitMask

```
Escenario 1: Elena (EXT_N0, hogar) quiere editar su propio teléfono
  position = resolve("D00.actor_telefono.editar")  → bit [5830] (en redesño)
  result = elena_rol_bitmask.check(5830)            → true (tiene el bit)
  audit_event: Permitido · actor=elena · campo=actor.telefono · acción=editar

Escenario 2: Elena quiere editar el NIT del bdomain
  position = resolve("D00.bdomain_nit.editar")     → bit [5814] (en redesño)
  result = elena_rol_bitmask.check(5814)            → false (no tiene el bit)
  audit_event: Denegado · actor=elena · campo=bdomain.nit · acción=editar

Escenario 3: Admin BIZ_N1 quiere ver el NIT
  position = resolve("D00.bdomain_nit.ver")         → bit [5815] (en redesño)
  result = admin_rol_bitmask.check(5815)             → true
  audit_event: Permitido · actor=admin · campo=bdomain.nit · acción=ver
```

Cada evaluación — permitida o denegada — es inmutable en el audit_event. Esto es
la base de la Autenticación Dimensional (ver `BAUTH-AUTENTICACION-DIMENSIONAL-v1.0.md`).

---

## PARTE 8 — ESTADO DE LA MIGRACIÓN DDL

### 8.1 Migración 003 (estado: DISEÑADA, PENDIENTE APROBACIÓN)

**Archivo:** `BauthAgent/db/migrations/003_d00_identidad_organizacional.sql`

La migración está diseñada en 8 pasos idempotentes:
1. ADD COLUMN `idn_tenant.is_internal BOOLEAN`
2. DROP + ADD CONSTRAINT `ck_domain_code` para permitir `domain_code=0`
3. INSERT D00 en `privilege_domain`
4. INSERT app `org` (app_code=13) en `privilege_application`
5. INSERT 5 grupos G1-G5 en `privilege_group`
6. INSERT verbos 51-63 en `privilege_verb`
7. INSERT 20 átomos (positions 5809-5828) en `privilege_atom`
8. INSERT tenant externo de ejemplo (DEPO srl)

**Condición de seguridad:** NO usa TRUNCATE. Todos los pasos usan `INSERT ... ON CONFLICT DO NOTHING`.
Es seguro ejecutar múltiples veces.

### 8.2 Riesgo de seeds existentes

Los seeds existentes (`seed_privilege_domain.sql`, `seed_privilege_verb.sql`,
`seed_privilege_atom.sql`) usan `TRUNCATE CASCADE`. Si se re-ejecutan DESPUÉS de
la migración 003, borrarán los datos de D00.

**Solución pendiente (requiere aprobación separada):**
- Agregar D00 en `seed_privilege_domain.sql`
- Agregar verbos 51-63 en `seed_privilege_verb.sql`
- Agregar cláusula `OR (verb_code BETWEEN 51 AND 63 AND domain_code = 0)` en el WHERE de `seed_privilege_atom.sql`

### 8.3 Tablas verticales (estado: DISEÑADAS, PENDIENTE APROBACIÓN DDL SEPARADA)

Las 3 tablas (`org_contacto`, `org_documento`, `org_direccion`) son parte del
trabajo del Gate B2 (tablas operativas org_*). Requieren migración separada según ADR-016.

---

## PARTE 9 — REFERENCIA RÁPIDA

### 9.1 Fórmula ctx_id con D00

```
ctx_id = interno.{tenant_id}.{bdomain_id}.{bsubdomain_id}

interno       → idn_tenant.is_internal (boolean, "interno" si true, "false" si false)
tenant_id     → idn_tenant.tenant_id (UUIDv7)
bdomain_id    → org_empresa.uuid o idn_tenant_domain.uuid (según bdomain.type)
bsubdomain_id → org_sucursal.uuid o org_pos_logico.uuid (según nivel)

Ejemplo:
  ctx_id = "false.T-walmart-bo.BD-walmart-bo.BS-norte-el-alto"
             ↑      ↑             ↑             ↑
             externo tenant_uuid  bdomain_uuid  bsubdomain_uuid
```

### 9.2 Verificar los 20 átomos en BD

```sql
-- Confirmar que los 20 átomos de D00 están cargados:
SELECT atom_position, atom_slug, atom_name
FROM bauth.privilege_atom
WHERE domain_code = 0
ORDER BY atom_position;
-- Debe retornar 20 filas (5809-5828)

-- Confirmar que D00 está en privilege_domain:
SELECT domain_code, domain_name FROM bauth.privilege_domain ORDER BY domain_code;
-- Debe incluir D00 en la primera fila

-- Verificar verbos 51-63:
SELECT verb_code, verb_name FROM bauth.privilege_verb WHERE verb_code >= 51 ORDER BY verb_code;
-- Debe retornar 13 filas
```

---

*Documento maestro de planificación y diseño — no requiere aprobación DDL por sí mismo.*
*La migración 003_d00_identidad_organizacional.sql SÍ requiere aprobación explícita (ADR-016).*
*Las 3 tablas verticales org_contacto/org_documento/org_direccion requieren aprobación DDL separada.*
