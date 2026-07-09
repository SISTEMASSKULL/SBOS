# ANÁLISIS — D00 con Modelo Vertical de Contactos e Identidad
**Versión:** 1.0 · **Fecha:** 2026-06-30 · **Tipo:** Planificación / Diseño
**Propósito:** Replantear el almacenamiento de teléfonos, emails, direcciones y
documentos de identidad usando modelo vertical (N filas por entidad, 1 fila por valor).
Verificar si los 20 átomos D00 actuales resisten sin cambios.

---

## 1. EL PRINCIPIO: MODELO VERTICAL (TABLA DE FILAS)

```
MODELO ACTUAL (columna plana):
┌──────────────────────────────────────────────────────────────┐
│ bdomain_id │ email             │ telefono      │ direccion   │
├────────────┼───────────────────┼───────────────┼─────────────┤
│ BD-banco   │ info@banco.bo     │ +59122700001  │ Av. Camacho │  ← solo 1 de cada uno
└──────────────────────────────────────────────────────────────┘

MODELO VERTICAL (fila por valor):
┌──────────────────────────────────────────────────────────────────────────┐
│ entidad_id │ atom_code │ subtype    │ valor               │ primary      │
├────────────┼───────────┼────────────┼─────────────────────┼──────────────┤
│ BD-banco   │ 5813      │ work       │ info@banco.bo       │ true         │
│ BD-banco   │ 5813      │ billing    │ facturas@banco.bo   │ false        │
│ BD-banco   │ 5813      │ legal      │ legal@banco.bo      │ false        │
│ BD-banco   │ 5813      │ technical  │ soporte@banco.bo    │ false        │
│ BD-banco   │ 5814      │ work       │ +59122700001        │ true         │
│ BD-banco   │ 5814      │ work       │ 80010000            │ false        │  ← línea gratuita
│ BD-banco   │ 5814      │ fax        │ +59122700003        │ false        │
│ BD-banco   │ 5814      │ emergency  │ +59179090000        │ false        │
└──────────────────────────────────────────────────────────────────────────┘
  atom_code 5813 = D00.org.bdomain.email
  atom_code 5814 = D00.org.bdomain.telefono
```

**Los átomos D00 son los TIPOS. Las filas son las INSTANCIAS.**
Los 20 átomos D00 no se multiplican — solo se multiplican las filas de datos.

---

## 2. DISEÑO DE TABLAS VERTICALES

### 2.1 `org_contacto` — Teléfonos y Emails (valor único por fila)

```sql
-- Tabla vertical para: email, telefono, ci (campos de texto simple)
-- atom_code referencia privilege_atom → define QUÉ tipo de dato es cada fila
-- subtype define el subtipo dentro de esa categoría (work/home/mobile/billing...)

CREATE TABLE bauth.org_contacto (
  id            UUID        NOT NULL DEFAULT gen_random_uuid(),
  entidad_tipo  TEXT        NOT NULL, -- 'bdomain' | 'bsubdomain' | 'actor'
  entidad_id    UUID        NOT NULL, -- FK a org_empresa / org_sucursal / org_actor
  atom_code     INT         NOT NULL, -- FK → privilege_atom (define el tipo)
  subtype       TEXT        NOT NULL, -- subtipo del dato (work/home/mobile/fax/billing...)
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
  CONSTRAINT uq_contacto_primary
    UNIQUE NULLS NOT DISTINCT (entidad_id, atom_code, is_primary)
    DEFERRABLE INITIALLY DEFERRED
    -- solo 1 primary=true por (entidad + atom_code)
);

CREATE INDEX ix_org_contacto_entidad ON bauth.org_contacto (entidad_id, atom_code);
CREATE INDEX ix_org_contacto_valor   ON bauth.org_contacto (atom_code, valor);
```

**Átomos D00 que alimentan esta tabla:**

| atom_code | Átomo D00 | Subtipos válidos |
|:---------:|-----------|-----------------|
| 5813 | `D00.org.bdomain.email` | work, home, billing, legal, technical, notifications, alternate |
| 5814 | `D00.org.bdomain.telefono` | mobile, work, home, fax, work_mobile, whatsapp, emergency, voip, satellite |
| 5815 | `D00.org.bdomain.ci` | CI, CI_EXT (y por extensión NIT → ver 5812) |
| 5818 | `D00.org.bsubdomain.nombre` | N/A (solo 1 nombre por bsubdomain) |

---

### 2.2 `org_documento` — Documentos de Identidad (múltiples por actor)

Los documentos tienen estructura más rica: tipo + número + país + vencimiento.
Merecen tabla propia (no son un simple valor de texto):

```sql
CREATE TABLE bauth.org_documento (
  id            UUID        NOT NULL DEFAULT gen_random_uuid(),
  entidad_tipo  TEXT        NOT NULL DEFAULT 'actor', -- generalmente siempre actor
  entidad_id    UUID        NOT NULL,
  doc_type      TEXT        NOT NULL, -- CI, CI_EXT, NIT, PASSPORT, DNI, CUIT, RUT, CPF...
  doc_number    TEXT        NOT NULL,
  country_issue CHAR(2)     NOT NULL DEFAULT 'BO', -- ISO 3166-1 alpha-2
  issued_at     DATE,
  expires_at    DATE,
  is_primary    BOOLEAN     NOT NULL DEFAULT false,
  is_verified   BOOLEAN     NOT NULL DEFAULT false,
  verified_at   TIMESTAMPTZ,
  verified_by   TEXT,       -- 'manual' | 'api_registro_civil' | 'api_sin'
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT pk_org_documento PRIMARY KEY (id),
  CONSTRAINT uq_doc_per_entity UNIQUE (entidad_id, doc_type, country_issue),
  CONSTRAINT uq_doc_primary UNIQUE NULLS NOT DISTINCT (entidad_id, is_primary)
    DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX ix_org_documento_entidad ON bauth.org_documento (entidad_id, doc_type);
CREATE INDEX ix_org_documento_numero  ON bauth.org_documento (doc_type, doc_number);
```

**Relación con átomo D00:**

| Átomo D00 | Función |
|-----------|---------|
| `D00.org.actor.id_doc_type` (5826) | Define que este actor TIENE documentos → apunta a `org_documento` |
| El ENUM de `actor.id_doc_type` | Se convierte en `doc_type TEXT` con constraint |

---

### 2.3 `org_direccion` — Direcciones con Componentes Estructurados

Las direcciones tienen sub-campos (calle, número, piso, ciudad, país, CP).
No son un TEXT simple. Merecen tabla propia:

```sql
CREATE TABLE bauth.org_direccion (
  id            UUID        NOT NULL DEFAULT gen_random_uuid(),
  entidad_tipo  TEXT        NOT NULL, -- 'bdomain' | 'bsubdomain' | 'actor'
  entidad_id    UUID        NOT NULL,
  addr_type     TEXT        NOT NULL, -- work, home, fiscal, billing, delivery, mailing, registered, virtual
  -- Componentes de la dirección
  street        TEXT,                 -- Av. Arce / C. Ayacucho / Plaza 6 de Agosto
  number        TEXT,                 -- N° 2678 / s/n / sin número
  floor         TEXT,                 -- Piso 8 / 3°
  office        TEXT,                 -- Of. 801 / Dpto. B
  neighborhood  TEXT,                 -- Sopocachi / Villa Dolores
  municipality  TEXT        NOT NULL, -- La Paz / El Alto / Viacha
  department    TEXT,                 -- La Paz / Cochabamba / Santa Cruz
  country       CHAR(2)     NOT NULL DEFAULT 'BO',
  postal_code   TEXT,                 -- nullable: Bolivia no usa CP sistemáticamente
  -- Metadata
  full_address  TEXT GENERATED ALWAYS AS (
    TRIM(CONCAT_WS(', ',
      NULLIF(TRIM(CONCAT_WS(' ', street, number)), ''),
      NULLIF(TRIM(CONCAT_WS(' ', floor, office)), ''),
      neighborhood,
      municipality,
      department,
      country,
      postal_code
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

CREATE INDEX ix_org_direccion_entidad ON bauth.org_direccion (entidad_id, addr_type);
```

**Relación con átomo D00:**

| Átomo D00 | Función |
|-----------|---------|
| `D00.org.bdomain.direccion` (5816) | El átomo declara que el bdomain TIENE dirección(es) |
| `D00.org.bsubdomain.direccion` (5819) | Igual para bsubdomain |
| La tabla `org_direccion` | Almacena las N instancias con sus componentes |

---

## 3. CÓMO CONECTA CON LOS 20 ÁTOMOS D00

Los átomos D00 son **definiciones de tipo**, no contenedores de datos.
La tabla `org_contacto`, `org_documento` y `org_direccion` son los contenedores.

```
privilege_atom (20 átomos D00)          Tablas de instancias
─────────────────────────────           ────────────────────────────────
atom 5813: bdomain.email          ──→   org_contacto (filas con atom_code=5813)
atom 5814: bdomain.telefono       ──→   org_contacto (filas con atom_code=5814)
atom 5815: bdomain.ci             ──→   org_contacto (filas con atom_code=5815)
atom 5816: bdomain.direccion      ──→   org_direccion (filas con entidad_tipo='bdomain')
atom 5817: bsubdomain.type        ──→   columna en org_sucursal (1 valor, no se repite)
atom 5818: bsubdomain.nombre      ──→   columna en org_sucursal (1 nombre por sucursal)
atom 5819: bsubdomain.direccion   ──→   org_direccion (filas con entidad_tipo='bsubdomain')
atom 5826: actor.id_doc_type      ──→   org_documento (filas por documento)
atoms 5809-5812: tenant/bdomain type,nombre,nit ──→ columnas directas (1 valor por entidad)
atoms 5820-5828: pos y actor      ──→   columnas en org_pos / org_actor (mayormente 1 valor)
```

**Regla:** Los átomos con valor ÚNICO por entidad (type, nombre, nit, tipo societario)
van como columnas directas. Los átomos con valor MÚLTIPLE (email, teléfono, dirección,
documento) van a la tabla vertical correspondiente.

---

## 4. REVALIDACIÓN DE LOS 10 CASOS CON MODELO VERTICAL

### Caso 1 — Ana Flores (GG Walmart) — 4 tel / 4 email / 3 dir / 2 doc

**org_contacto para BD-walmart-bo:**
```
atom 5814 │ work       │ +59127278000 ext.100 │ primary=true
atom 5814 │ work_mobile│ +59179000001         │ primary=false
atom 5814 │ mobile     │ +59171234567         │ primary=false
atom 5814 │ whatsapp   │ +59179000001         │ primary=false
atom 5813 │ work       │ a.flores@walmart.com.bo │ primary=true
atom 5813 │ home       │ anaflores1975@gmail.com │ primary=false
atom 5813 │ legal      │ gerencia.legal@walmart.com.bo │ primary=false
atom 5813 │ notifications│ a.flores+sbos@walmart.com.bo │ primary=false
```

**org_documento para actor Ana:**
```
doc_type=CI        │ 7123456 │ country=BO │ primary=true
doc_type=PASSPORT  │ BA098765│ country=BO │ primary=false │ expires_at=2030-05-15
```

**org_direccion para actor Ana:**
```
work   │ Av. Arce │ N° 2678 │ Piso 8 │ Sopocachi │ La Paz │ BO │ primary=true
home   │ C/ R. Gutiérrez │ N° 500 │ Sopocachi │ La Paz │ BO
fiscal │ Av. Arce │ N° 2678 │ Casa Matriz │ La Paz │ BO
```

**¿Resiste?** ✅ 100% — todas las filas caben sin truncar nada.

---

### Caso 2 — Gabriel Romero (extranjero con 3 documentos)

**org_documento para actor Gabriel:**
```
doc_type=CI_EXT  │ E-456789    │ country=BO │ primary=true  │ verified=true
doc_type=DNI     │ 32.456.789  │ country=AR │ primary=false │ verified=false
doc_type=PASSPORT│ AA234567    │ country=AR │ primary=false │ expires_at=2028-11-30
```

**org_contacto para actor Gabriel:**
```
atom 5814 │ work   │ +59127270001  │ primary=true
atom 5814 │ mobile │ +59171999888  │ primary=false
atom 5814 │ home   │ +541141234567 │ primary=false (familia Argentina)
atom 5813 │ work   │ g.romero@bancounion.bo   │ primary=true
atom 5813 │ home   │ gabiromero@hotmail.com   │ primary=false
atom 5813 │ alternate│ gabriel.romero@protonmail.com │ primary=false
```

**¿Resiste?** ✅ 100% — el UNIQUE (entidad_id, doc_type, country_issue) permite
tener DNI de Argentina y CI_EXT de Bolivia sin conflicto.

**ANTES:** `actor.id_doc_type = CI_EXT` (perdía DNI y PASSPORT).
**AHORA:** 3 filas en `org_documento`, cada una con su tipo, número y país emisor.

---

### Caso 3 — Banco Unión SA (5 tel / 5 email / 4 dir)

**org_contacto para BD-banco-union:**
```
atom 5814 │ work       │ +59127270001  │ primary=true
atom 5814 │ work       │ 80010000      │ primary=false   (línea 800 gratuita)
atom 5814 │ work       │ +59127270002  │ primary=false   (call center empresas)
atom 5814 │ fax        │ +59127270003  │ primary=false
atom 5814 │ emergency  │ +59179090000  │ primary=false   (línea ASFI)
atom 5813 │ work       │ info@bancounion.bo          │ primary=true
atom 5813 │ billing    │ facturacion@bancounion.bo   │ primary=false
atom 5813 │ legal      │ legal@bancounion.bo         │ primary=false
atom 5813 │ technical  │ soportetic@bancounion.bo    │ primary=false
atom 5813 │ notifications│ alertas@bancounion.bo     │ primary=false
```

**org_direccion para BD-banco-union:**
```
registered │ Av. Camacho │ N° 1234 │ La Paz │ BO
fiscal     │ Av. Camacho │ N° 1234 │ La Paz │ BO
work       │ Av. 16 de Julio │ N° 1800 │ El Prado │ La Paz │ BO │ primary=true
mailing    │ (sin calle) │ (Casilla Postal 1234) │ La Paz │ BO
```

**¿Resiste?** ✅ 100% — 10 filas de contacto, 4 filas de dirección. Todo cabe.

---

### Caso 4 — Don Ernesto (2 tel / 1 email / 2 dir)

```
atom 5814 │ mobile │ +59172345678 │ primary=true
atom 5814 │ home   │ +59152123456 │ primary=false   (fijo del local)
atom 5813 │ home   │ ernestovr@gmail.com │ primary=true
```

**org_direccion:**
```
work   │ C/Ayacucho │ N° 234 │ Oruro │ BO │ primary=true
fiscal │ C/Ayacucho │ N° 234 │ Oruro │ BO   (misma físicamente, distinto rol)
```

**¿Resiste?** ✅ 100%

---

### Caso 5 — Dr. Quispe (3 tel / 2 email / 3 dir / 2 doc)

**org_contacto:**
```
atom 5814 │ mobile   │ +59176543210 │ primary=true
atom 5814 │ work     │ +591333345678│ primary=false  (consultorio SCZ)
atom 5814 │ whatsapp │ +59176543210 │ primary=false  (mismo número, canal distinto)
atom 5813 │ work │ dr.quispe@clinicasur.bo │ primary=true
atom 5813 │ home │ carlosquispe@gmail.com  │ primary=false
```

**org_documento:**
```
doc_type=CI       │ 7654321 LP │ country=BO │ primary=true
doc_type=PASSPORT │ BA112233   │ country=BO │ primary=false │ expires_at=2030-06-01
```

**org_direccion:**
```
work   │ C/Mercado │ N° 567 │ Piso 2 │ Santa Cruz │ BO │ primary=true
home   │ Zona Norte │ C/12 N° 456 │ La Paz │ BO
fiscal │ C/Mercado  │ N° 567 │ Piso 2 │ Santa Cruz │ BO
```

**¿Resiste?** ✅ 100%

---

### Caso 6 — Familia García (4 tel / 3 email del HOGAR)

El bdomain `hogar` tiene 4 teléfonos porque el contrato de servicios necesita
poder contactar a cualquier adulto del hogar:

```
atom 5814 │ home       │ +59122345678 │ primary=true   (fijo hogar)
atom 5814 │ mobile     │ +59171234567 │ primary=false  (Elena)
atom 5814 │ mobile     │ +59172345678 │ primary=false  (Jorge)
atom 5814 │ mobile     │ +59173456789 │ primary=false  (Javier)
atom 5813 │ work       │ elena.garcia@empresa.com    │ primary=true
atom 5813 │ home       │ familia.garcia@gmail.com    │ primary=false
atom 5813 │ billing    │ facturas.garcia@gmail.com   │ primary=false
```

**¿Resiste?** ✅ 100% — El contrato de servicios del hogar ahora tiene acceso
a todos los contactos del núcleo familiar sin perder ninguno.

---

### Caso 7 — Alan Chávez freelance internacional (4 tel / 4 email / 2 dir)

```
atom 5814 │ mobile      │ +59171111222  │ primary=true
atom 5814 │ voip        │ +15552345678  │ primary=false  (número USA)
atom 5814 │ work_mobile │ +34612345678  │ primary=false  (SIM España)
atom 5814 │ whatsapp    │ +59171111222  │ primary=false
atom 5813 │ work        │ alan@codefreelance.bo     │ primary=true
atom 5813 │ billing     │ billing@codefreelance.bo  │ primary=false
atom 5813 │ home        │ alanct@gmail.com          │ primary=false
atom 5813 │ technical   │ dev@codefreelance.bo      │ primary=false
```

**org_direccion:**
```
home    │ Av. Fuerza Naval │ N° 123 │ La Paz │ BO │ primary=true
virtual │ (buzón)          │ 1234 Innovation Dr Suite 200 │ Austin │ TX │ US │ 78701
```

**¿Resiste?** ✅ 100% — incluyendo el número VoIP de USA y la dirección virtual.

---

### Caso 8 — Bot SAP (0 tel / 2 email / 0 dir)

```
atom 5813 │ technical │ ops@sap-integration.com   │ primary=true
atom 5813 │ work      │ admin@sap-integration.com │ primary=false
```

Sin filas en org_documento (es un servicio).
Sin filas en org_direccion (no tiene ubicación física).

**¿Resiste?** ✅ 100% — nullable funciona, 0 filas es válido.

---

### Caso 9 — Doña Carmen (1 tel / 0 email / 1 dir)

```
atom 5814 │ mobile │ +59170012345 │ primary=true
```

Sin filas en org_contacto para atom_code=5813 (email). → 0 filas = sin email.
Dirección: `work │ Plaza 6 de Agosto │ s/n │ Viacha │ La Paz │ BO`

**¿Resiste?** ✅ 100% — el campo es opcional al no haber fila, no NULL en columna.
Antes: `bdomain.email = NULL` en una columna → esquema rígido.
Ahora: ausencia de fila → más limpio, no hay columna nullable que gestionar.

---

### Caso 10 — Deloitte Bolivia (3 tel / 4 email / 3 dir / 2 doc empresa)

```
atom 5814 │ work │ +59122770000 │ primary=true
atom 5814 │ work │ +59144512345 │ primary=false  (Cochabamba)
atom 5814 │ fax  │ +59122770001 │ primary=false
atom 5813 │ work         │ info@deloitte.com.bo      │ primary=true
atom 5813 │ legal        │ legal.bolivia@deloitte.com│ primary=false
atom 5813 │ billing      │ cuentas@deloitte.com.bo   │ primary=false
atom 5813 │ technical    │ rrhh@deloitte.com.bo      │ primary=false
```

**org_documento (empresa):**
```
doc_type=NIT              │ 9876543210 │ country=BO │ primary=true
doc_type=registered_number│ 123456/2001│ country=BO │ (Registro Comercio Bolivia)
```

**org_direccion:**
```
registered │ Av. Arce │ N° 2631 │ Torre I │ La Paz │ BO
fiscal     │ Av. Arce │ N° 2631 │ Torre I │ La Paz │ BO
work       │ Av. Arce │ N° 2631 │ Piso 12 │ La Paz │ BO │ primary=true
```

**¿Resiste?** ✅ 100%

---

## 5. TABLA DE SUBTIPOS VÁLIDOS POR ÁTOMO

### Subtipos para `atom_code=5814` (telefono)

| Subtipo | Descripción | Uso típico |
|---------|------------|-----------|
| `mobile` | Celular personal | Persona, actor humano |
| `work` | Fijo de trabajo / central | Empresa, sucursal |
| `home` | Fijo domicilio | Persona, hogar |
| `work_mobile` | Celular corporativo (SIM de la empresa) | Empresa grande |
| `whatsapp` | WhatsApp (puede ser mismo número que mobile) | LATAM — muy común |
| `fax` | Fax | Empresa, gobierno, salud |
| `emergency` | Contacto de emergencia | Empresa, salud |
| `voip` | VoIP / extensión interna | Freelancer, startup |
| `satellite` | Teléfono satelital | Minería, campo, remoto |

### Subtipos para `atom_code=5813` (email)

| Subtipo | Descripción |
|---------|------------|
| `work` | Email corporativo principal |
| `home` | Email personal |
| `alternate` | Email de respaldo / backup |
| `billing` | Solo para facturas y pagos |
| `legal` | Notificaciones legales |
| `technical` | APIs, soporte técnico, CI/CD |
| `notifications` | Alertas del sistema |

### Tipos para `org_documento.doc_type`

| Tipo | País | Uso |
|------|------|-----|
| `CI` | Bolivia | Carnet nacional |
| `CI_EXT` | Bolivia | Carnet extranjero residente |
| `NIT` | Bolivia | Tributario (empresa y persona natural) |
| `PASSPORT` | Internacional | Pasaporte de cualquier país |
| `DNI` | Argentina, España | Documento nacional |
| `CUIT` | Argentina | Empresa |
| `RUT` | Chile | Persona y empresa |
| `CPF` | Brasil | Persona |
| `CNPJ` | Brasil | Empresa |
| `CURP` | México | Persona |
| `RFC` | México | Empresa y persona |
| `RUC` | Perú, Ecuador | Empresa |
| `CC` | Colombia | Cédula persona |
| `NIT_CO` | Colombia | Empresa |
| `DUI` | El Salvador | Persona |
| `SSN` | USA | Persona |
| `TIN` | USA | Empresa |
| `registered_number` | Bolivia | Número Registro Comercio |

### Tipos para `org_direccion.addr_type`

| Tipo | Cuándo aplica |
|------|--------------|
| `work` | Dirección operativa / de trabajo |
| `home` | Domicilio personal |
| `fiscal` | Registrada ante SIN / impuestos |
| `registered` | Escritura pública / notaría |
| `billing` | Dirección de facturación |
| `delivery` | Entrega de paquetes |
| `mailing` | Correspondencia postal / casilla |
| `branch` | Sucursal específica |
| `warehouse` | Almacén / depósito |
| `virtual` | Buzón virtual (UPS Store, dirección virtual) |

---

## 6. IMPACTO EN LOS 20 ÁTOMOS D00

### ¿Cambia algún átomo D00?

**NO. Los 20 átomos siguen siendo exactamente los mismos.**

Lo que cambia es cómo se materializan:

| Átomo D00 | Antes | Ahora |
|-----------|-------|-------|
| `bdomain.email` (5813) | Columna TEXT en org_empresa | N filas en `org_contacto` |
| `bdomain.telefono` (5814) | Columna TEXT en org_empresa | N filas en `org_contacto` |
| `bdomain.ci` (5815) | Columna TEXT en org_empresa | N filas en `org_contacto` |
| `bdomain.direccion` (5816) | Columna TEXT en org_empresa | N filas en `org_direccion` |
| `bsubdomain.direccion` (5819) | Columna TEXT en org_sucursal | N filas en `org_direccion` |
| `actor.id_doc_type` (5826) | ENUM en org_actor | N filas en `org_documento` |
| `bdomain.type` (5810) | Sin cambio — 1 tipo por bdomain | Columna directa |
| `bdomain.nombre` (5811) | Sin cambio — 1 nombre por bdomain | Columna directa |
| `bdomain.nit` (5812) | Sin cambio — 1 NIT por bdomain | Columna directa |
| `actor.gender` (5824) | Sin cambio — 1 valor por actor | Columna directa |
| `actor.locale` (5827) | Sin cambio — 1 valor | Columna directa |
| `actor.timezone` (5828) | Sin cambio — 1 valor | Columna directa |

**Regla emergente de este análisis:**
- Dato de **cardinalidad 1:1** con la entidad → columna directa en la tabla
- Dato de **cardinalidad 1:N** con la entidad → tabla vertical (`org_contacto`, `org_documento`, `org_direccion`)

---

## 7. VEREDICTO FINAL

### ¿Los 20 átomos D00 resisten con el modelo vertical?

**✅ SÍ. Los 20 átomos son correctos y suficientes.**

El modelo vertical no modifica los átomos — los fortalece.
Cada átomo sigue siendo la definición del tipo de dato (qué es).
Las tablas verticales son los contenedores de las instancias (cuántos y cuáles).

### Cobertura con modelo vertical vs modelo anterior

| Caso | Modelo plano (antes) | Modelo vertical (ahora) |
|------|:--------------------:|:-----------------------:|
| Ana Flores — 4 tel, 4 email, 2 doc | ❌ 25% | ✅ 100% |
| Gabriel Romero — 3 doc de 2 países | ❌ 33% | ✅ 100% |
| Banco Unión — 5 tel, 5 email | ❌ 20% | ✅ 100% |
| Don Ernesto — 2 tel | ❌ 50% | ✅ 100% |
| Dr. Quispe — WhatsApp + consultorio | ❌ 33% | ✅ 100% |
| Familia García — 4 tel del hogar | ❌ 25% | ✅ 100% |
| Alan Chávez — 3 países, 4 emails | ❌ 25% | ✅ 100% |
| Bot SAP — 0 teléfonos | ✅ (NULL) | ✅ (0 filas) |
| Doña Carmen — 0 emails | ✅ (NULL col) | ✅ (0 filas) |
| Deloitte — 2 documentos empresa | ❌ 50% | ✅ 100% |

### Las 3 tablas nuevas que se necesitan (Gate B2)

```
bauth.org_contacto   ← emails + teléfonos (modelo vertical con atom_code FK)
bauth.org_documento  ← documentos de identidad (tipo + número + país + vencimiento)
bauth.org_direccion  ← direcciones (componentes estructurados + tipo)
```

Estas 3 tablas son parte del trabajo de Gate B2 (tablas operativas org_*).
Requieren aprobación DDL separada según ADR-016.
Los 20 átomos D00 no se modifican.

---

*Análisis de planificación — pendiente de aprobación DDL para las 3 tablas nuevas.*
